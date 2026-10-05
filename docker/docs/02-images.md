# 2-dars: Image'lar

Maqsad: image ichki tuzilishini (layer, OverlayFS, manifest, digest) tushunish va shu bilim asosida tez quriladigan, kichik, non-root, takrorlanuvchi image yozish. 1-darsda tayyor image'larni ishga tushirdingiz, bu darsda o'z ilovangizni (Node.js va Go) qadoqlaysiz, skanerlaysiz va registry'ga push qilasiz. 4-darsdagi Compose `build`, 5-darsdagi Swarm va keyingi CI/CD moduli shu yerda qurilgan image'larni ishlatadi.

Taxminiy vaqt: 4 kun (siz uchun). `Dockerfile` ni ko'rgansiz, diqqatni quyidagilarga qarating: cache qanday invalidatsiya bo'lishi va layer tartibi, o'chirilgan fayl nima uchun image'da qolishi, `CMD` va `ENTRYPOINT` ning o'zaro ta'siri, shell form va signal muammosi, multi-stage, tag va digest farqi, build paytidagi secret'lar.

## Laboratoriya

Ish mashinasidagi Docker Engine. Build BuildKit orqali ketadi (Docker 23.0 dan default), `docker build` bu `docker buildx build` ning qisqa shakli. Sizda containerd image store yoqilgan (`docker info` da `driver-type: io.containerd.snapshotter.v1`), bu ko'p platformali image'ni lokal saqlash imkonini beradi.

```
docker buildx version
docker buildx ls
```

Kerak bo'ladi: Docker Hub yoki GitHub akkaunti (GHCR uchun `write:packages` huquqli personal access token). Token faqat `docker login --password-stdin` ga beriladi, faylga yozilmaydi va commit qilinmaydi. Trivy skaneri konteyner sifatida ishlatiladi, ish mashinasiga o'rnatilmaydi.

Shu darsdagi image'larni `lesson02/` prefiksi bilan nomlang (`lesson02/node-app:1.0`), tozalash oson bo'ladi:

```
docker image ls 'lesson02/*'
docker image rm $(docker image ls -q 'lesson02/*')
docker buildx du            # build cache usage
docker builder prune        # removes unused build cache (all projects)
```

Registry'ga push qilingan test image'larni ham dars oxirida o'chiring yoki private qoldiring.

---

## 1. Image tuzilishi

Image bu o'zgarmas (immutable) fayl tizimi layer'lari ro'yxati va konfiguratsiya (env, `CMD`, user, portlar). Konteyner shu image ustiga bitta yoziladigan layer qo'shilgan jarayon.

### Layer va OverlayFS

Fayl tizimini o'zgartiradigan har instruksiya (`RUN`, `COPY`, `ADD`) yangi layer yaratadi: oldingi holatga nisbatan farq (tar arxiv). Layer mazmunining SHA-256 hash'i uning identifikatori (content-addressable), shuning uchun bir xil layer diskda va registry'da bir marta saqlanadi va image'lar orasida bo'lishiladi.

Ishga tushirishda OverlayFS layer'larni bitta daraxtga birlashtiradi:

| Qism | Roli |
|------|------|
| `lowerdir` | image layer'lari, faqat o'qish |
| `upperdir` | konteynerning yoziladigan layer'i |
| `merged` | konteyner ko'radigan `/` |

- **Copy-on-write**: pastki layer'dagi faylni o'zgartirganda u avval to'liq `upperdir` ga nusxalanadi. Katta faylni (masalan, baza fayli) konteyner layer'ida o'zgartirish sekin, buning uchun volume (3-dars).
- **Whiteout**: faylni o'chirish pastki layer'dan o'chirmaydi, `upperdir` ga "yo'q" belgisi qo'yadi.

Konteyner ichida `head -1 /proc/mounts` shu `lowerdir`/`upperdir` yo'llarini ko'rsatadi.

**Tuzoq: keyingi layer'da o'chirish hajmni kamaytirmaydi.** `RUN curl -O big.tar.gz` va keyingi qatorda `RUN rm big.tar.gz` yozilsa fayl birinchi layer'da qoladi, image kichraymaydi. Yuklash, ishlatish va o'chirish bitta `RUN` ichida bo'lishi kerak. Xuddi shu sabab bilan bir marta `COPY` qilingan secret keyin o'chirilsa ham layer'dan o'qib olinadi.

### Nom, registry, tag, digest

```
ghcr.io / yodzafar / node-app : 1.4.2 @ sha256:9f2c...
registry  namespace  repository  tag     digest
```

- Registry yozilmasa `docker.io`, namespace yozilmasa `library` (rasmiy image'lar): `nginx` bu `docker.io/library/nginx:latest`.
- **Tag** o'zgaruvchan ko'rsatkich: `node:24-alpine` bugun va bir oydan keyin boshqa image bo'lishi mumkin. `latest` shunchaki tag ko'rsatilmagandagi default nom, "eng yangi" degan kafolati yo'q.
- **Digest** manifest mazmunining hash'i, o'zgarmas. `FROM node:24-alpine@sha256:...` har doim aynan bir image.
- Ko'p platformali image'da tag **image index** ga ishora qiladi, u har platforma (`linux/amd64`, `linux/arm64`) uchun alohida manifestga yo'naltiradi. `docker pull` sizning platformangizni tanlaydi.

Asosiy buyruqlar: `docker image ls`, `docker pull`, `docker tag SRC DST` (yangi nom, nusxa emas), `docker image inspect`, `docker history IMAGE` (layer'lar va ularni yaratgan instruksiyalar), `docker image rm`, `docker buildx imagetools inspect IMAGE` (registry'dagi manifest va platformalar).

## 2. Dockerfile

`Dockerfile` image'ni qurish retsepti. Build **context** (odatda `.`) builder'ga yuboriladigan fayllar to'plami, `COPY` faqat shu ichidan o'qiy oladi.

```
docker build -t lesson02/app:1.0 .
docker build -t lesson02/app:1.0 -f docker/Dockerfile --target build .
```

| Instruksiya | Vazifasi | Layer |
|-------------|----------|-------|
| `FROM image[:tag] [AS name]` | base image, yangi stage boshlaydi | yo'q |
| `RUN cmd` | build paytida buyruq bajaradi | ha |
| `COPY [--chown=u:g] [--from=stage] src dst` | context yoki boshqa stage'dan nusxalash | ha |
| `ADD` | `COPY` + URL va tar ochish. Odatda `COPY` ishlatiladi | ha |
| `WORKDIR /app` | joriy papka (yo'q bo'lsa yaratadi) | yo'q |
| `ENV K=v` | build va runtime'da env | yo'q |
| `ARG K[=default]` | faqat build paytidagi o'zgaruvchi (`--build-arg`) | yo'q |
| `USER uid[:gid]` | keyingi `RUN` va runtime foydalanuvchisi | yo'q |
| `EXPOSE 3000` | hujjat: qaysi port tinglanadi. Portni ochmaydi | yo'q |
| `CMD`, `ENTRYPOINT` | konteyner start buyrug'i (4-bo'lim) | yo'q |
| `HEALTHCHECK` | sog'liq tekshiruvi (3-dars) | yo'q |
| `LABEL k=v` | metadata (`org.opencontainers.image.source` va boshqalar) | yo'q |
| `VOLUME`, `STOPSIGNAL`, `SHELL` | anonim volume e'loni, stop signali, shell form uchun shell | yo'q |

Birinchi qatorda `# syntax=docker/dockerfile:1` yozish Dockerfile frontend'ining oxirgi barqaror 1.x versiyasini ishlatadi (`RUN --mount` kabi imkoniyatlar uchun).

`ARG` va `ENV` farqi: `ARG` runtime'da yo'q, `ENV` image'da qoladi. `FROM` dan oldingi `ARG` faqat `FROM` qatorida ko'rinadi, stage ichida kerak bo'lsa qayta e'lon qilinadi.

**Tuzoq: `ARG` va `ENV` secret uchun emas.** `--build-arg TOKEN=...` qiymati `docker history` da ko'rinadi, `ENV` esa image konfiguratsiyasida qoladi. Build paytidagi secret uchun secret mount ishlatiladi (6-bo'lim).

### .dockerignore

Context ildizidagi `.dockerignore` (`.gitignore` ga o'xshash sintaksis) ko'rsatilgan fayllarni context'dan chiqaradi. Usiz: `node_modules` va `.git` har build'da builder'ga yuboriladi (sekin), `COPY . .` hostdagi `node_modules` ni image ichidagisining ustiga yozadi (boshqa platforma binary'lari), `.env` va kalitlar image'ga tushadi.

```
node_modules
.git
.env*
dist
*.log
Dockerfile
.dockerignore
```

## 3. Build cache va layer tartibi

BuildKit har instruksiya uchun "kirishlar o'zgarganmi" deb tekshiradi:

- `RUN`: buyruq matni va oldingi layer. Buyruq tashqarida nima yuklashi (masalan `apt-get update` natijasi) hisobga olinmaydi.
- `COPY`, `ADD`: nusxalanayotgan fayllarning mazmuni (checksum). Vaqt belgisi hisobga olinmaydi.
- Bitta instruksiya cache'dan chiqsa (miss), **undan keyingi hammasi** qayta bajariladi.

Qoida: kam o'zgaradigan narsa yuqorida, tez-tez o'zgaradigan pastda. Dependency manifestlari manba koddan oldin nusxalanadi:

```
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
```

Shunda manba kodi o'zgarganda `npm ci` cache'dan olinadi. `COPY . .` birinchi turganida har bir harf o'zgarishi barcha dependency'larni qayta o'rnatadi.

Qo'shimcha vositalar:

- **Cache mount**: `RUN --mount=type=cache,target=/root/.npm npm ci`. Paket menejeri cache'i layer'ga kirmaydi, lekin build'lar orasida saqlanadi. Go uchun `/go/pkg/mod` va `/root/.cache/go-build`.
- `docker build --no-cache`, `--pull` (base image'ni qayta tekshirish), `--progress=plain` (to'liq log).
- `docker build --check`: build qilmasdan Dockerfile'ni lint qiladi.

**Tuzoq: `apt-get update` alohida `RUN` da.** U cache'da qoladi, keyingi `RUN apt-get install` eskirgan indeks bilan ishlaydi va "package not found" beradi. Har doim birga: `RUN apt-get update && apt-get install -y --no-install-recommends pkg && rm -rf /var/lib/apt/lists/*`.

## 4. CMD va ENTRYPOINT

| | `ENTRYPOINT` | `CMD` |
|---|--------------|-------|
| Roli | bajariladigan dastur | default argumentlar (yoki `ENTRYPOINT` yo'q bo'lsa butun buyruq) |
| `docker run IMAGE args` | saqlanadi, `args` unga qo'shiladi | `args` bilan almashtiriladi |
| Almashtirish | `--entrypoint` | `run` oxiridagi argumentlar |

Yakuniy buyruq: `ENTRYPOINT + CMD`. Namuna: `ENTRYPOINT ["/app"]` va `CMD ["--port", "8080"]`, shunda `docker run IMAGE --port 9090` faqat argumentni almashtiradi. Stage ichida oxirgi `CMD` va oxirgi `ENTRYPOINT` amal qiladi.

### Exec form va shell form

| Shakl | Yozilishi | PID 1 |
|-------|-----------|-------|
| exec | `CMD ["node", "server.js"]` | `node` |
| shell | `CMD node server.js` | `/bin/sh -c "node server.js"` |

Exec form JSON massiv: qo'shtirnoq faqat `"`, o'zgaruvchilar (`$PORT`) kengaytirilmaydi, chunki shell yo'q. Shell form'da PID 1 bu `sh`, u `SIGTERM` ni ilovaga uzatmaydi: 1-darsdagi 10 sekundlik `stop` va exit 137. Xuddi shu muammo `CMD ["npm", "start"]` da: PID 1 `npm`, `node` uning bolasi. Qoida: `ENTRYPOINT` va `CMD` har doim exec form'da, ilova to'g'ridan-to'g'ri chaqiriladi.

Start oldidan tayyorgarlik kerak bo'lsa (config generatsiya, migratsiya) entrypoint skripti yoziladi va u oxirida `exec "$@"` bilan o'zini ilovaga almashtiradi, shunda ilova PID 1 bo'ladi.

**Tuzoq: `ENTRYPOINT` shell form'da bo'lsa `CMD` va `docker run` argumentlari butunlay e'tiborsiz qoladi.**

## 5. Multi-stage build va kichik image

Build uchun kompilyator, dev dependency'lar, manba kodi kerak, runtime uchun yo'q. Multi-stage: bitta `Dockerfile` da bir necha `FROM`, yakuniy image faqat oxirgi stage'dan iborat, oldingilaridan kerakli fayllar `COPY --from` bilan olinadi.

```
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

`CGO_ENABLED=0` statik binary beradi (libc ga bog'liq emas), shuning uchun bo'sh yoki deyarli bo'sh base'da ishlaydi. Node'da sxema: `deps`/`build` stage'da `npm ci` va TypeScript kompilyatsiya, runtime stage'da faqat `npm ci --omit=dev` natijasi va `dist/`.

`--target build` bilan oraliq stage'ni alohida qurish mumkin (test yoki debug uchun). BuildKit yakuniy stage bog'liq bo'lmagan stage'larni umuman qurmaydi.

### Base image tanlash

| Base | Ichida | Qachon |
|------|--------|--------|
| `debian`, `ubuntu` | to'liq distributiv, glibc, apt | build stage, debug |
| `*-slim` (`node:24-slim`) | glibc, minimal paketlar | native modul bor Node/Python ilovalari |
| `*-alpine` | musl libc, busybox, apk. Juda kichik | ko'p hollarda yaxshi default |
| distroless (`gcr.io/distroless/...`) | faqat runtime va CA sertifikatlar. Shell ham, paket menejeri ham yo'q | production runtime |
| `scratch` | bo'sh | statik binary (Go, Rust) |

Kichik image: tez pull va deploy, kam zaiflik (CVE), kichik hujum yuzasi.

**Tuzoq: alpine bu musl.** glibc uchun qurilgan binary (ayrim npm native modullari, Python wheel'lari) musl'da ishlamaydi yoki manbadan kompilyatsiya qilinadi. DNS resolver xatti-harakati ham glibc'dan farq qiladi. Muammo chiqsa `-slim` ga o'ting.

**Tuzoq: distroless va scratch'da shell yo'q.** `docker exec ... sh` ishlamaydi, shell form `CMD`/`HEALTHCHECK` ham. `scratch` da CA sertifikatlar va timezone ma'lumotlari ham yo'q, HTTPS so'rovlar xato beradi (distroless `static` da ular bor). Distroless'ning `:debug` tag'i busybox shell bilan keladi.

### Non-root user

Default foydalanuvchi root. Ilovadagi zaiflik (RCE) hujumchiga konteyner ichida root beradi, bu esa 1-darsda ko'rganingizdek hostning UID 0 i. Runtime stage'da:

```
RUN addgroup -S app && adduser -S -G app app
COPY --chown=app:app --from=build /app/dist ./dist
USER app
```

Rasmiy `node` image'larida tayyor `node` (UID 1000) foydalanuvchisi, distroless'da `:nonroot` tag'i (UID 65532) bor. `USER` dan keyingi `RUN` ham shu foydalanuvchi nomidan ishlaydi, paket o'rnatish undan oldin bo'lishi kerak. Ilova yozadigan papkalar shu foydalanuvchiga tegishli bo'lsin.

## 6. BuildKit, buildx, secret'lar

BuildKit: stage'larni parallel quradi, keraksizlarini o'tkazib yuboradi, cache va secret mount'larni beradi. `buildx` uning CLI'si.

**Build secret**: qiymat faqat bitta `RUN` vaqtida fayl sifatida ko'rinadi, layer'ga va history'ga tushmaydi:

```
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```
```
docker build --secret id=npmrc,src=$HOME/.npmrc -t lesson02/app:1.0 .
```

**Ko'p platformali build**: `docker buildx build --platform linux/amd64,linux/arm64 ...`. Boshqa arxitektura uchun `RUN` bajarish emulyatsiya (QEMU) talab qiladi. Go kabi cross-compile qila oladigan tillarda emulyatsiyasiz yo'l bor: build stage o'z platformasida ishlaydi va maqsad arxitekturaga kompilyatsiya qiladi:

```
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build ...
```

`BUILDPLATFORM`, `TARGETOS`, `TARGETARCH` BuildKit avtomatik beradigan argumentlar.

## 7. Skanerlash va registry

### Zaiflik skaneri

Skaner image ichidagi OS paketlari va til dependency'larini (lock fayllar, binary metadata) ma'lum CVE bazasi bilan solishtiradi. Trivy (ochiq kodli) konteyner sifatida:

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:<version> image --severity HIGH,CRITICAL lesson02/node-app:1.0
```

`<version>` ni Trivy releases sahifasidan oling. `--exit-code 1` topilma bo'lsa nol bo'lmagan kod qaytaradi (CI'da build'ni to'xtatish uchun), `--ignore-unfixed` tuzatishi chiqmagan CVE'larni yashiradi. Lokal image socket orqali o'qilmasa: `docker save -o app.tar IMAGE` va `trivy image --input app.tar`.

Docker Scout (`docker scout cves IMAGE`, `docker scout quickview`) Docker'ning o'z skaneri. U alohida CLI plugin, sizning Engine o'rnatmangizda yo'q (`docker scout` "unknown command" beradi). O'rnatish ixtiyoriy: https://docs.docker.com/scout/install/.

Skaner natijasi vaqt o'tishi bilan o'zgaradi: bugun toza image ertaga yangi CVE tufayli zaif bo'ladi. Shuning uchun base image'ni muntazam yangilab qayta build qilish kerak.

### Push

```
echo "$TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
docker tag lesson02/node-app:1.0 ghcr.io/<github-user>/node-app:1.0
docker push ghcr.io/<github-user>/node-app:1.0
docker logout ghcr.io
```

Docker Hub uchun registry qismi yozilmaydi: `docker login -u <user>`, nom `<user>/node-app:1.0`. Push faqat registry'da yo'q layer'larni yuboradi. GHCR'da yangi package default private; `LABEL org.opencontainers.image.source=https://github.com/<user>/<repo>` uni repozitoriyga bog'laydi.

Tag strategiyasi: har build o'zgarmas tag oladi (semver `1.4.2` yoki git commit SHA), deploy shu tag yoki digest bo'yicha. Mavjud tag'ni qayta yozmang.

**Tuzoq: `docker login` tokenni `~/.docker/config.json` ga base64 ko'rinishida (shifrlanmagan) yozadi**, credential helper sozlanmagan bo'lsa. Minimal huquqli, muddati cheklangan token ishlating va ishdan keyin `docker logout` qiling.

## Tuzoqlar

- `FROM node:latest` yoki tag'siz base: build bugun ishlaydi, ertaga major versiya o'zgarib buziladi. Aniq versiya, production'da digest bilan.
- `COPY . .` dependency o'rnatishdan oldin: har kod o'zgarishida to'liq `npm ci`. CI vaqtining asosiy yeyuvchisi.
- `.dockerignore` yo'q: `.env`, `.git`, SSH kalitlari image'ga tushadi va registry'ga ketadi.
- Secret'ni `ARG`, `ENV` yoki `COPY` bilan berib keyin o'chirish: `docker history` va layer'lardan o'qib olinadi. Push qilingan bo'lsa secret'ni almashtirish (rotate) kerak.
- Shell form `CMD` yoki `npm start`: `SIGTERM` ilovaga yetmaydi, graceful shutdown ishlamaydi.
- Root sifatida ishlaydigan ilova: konteynerdan chiqish (escape) zaifligi darhol host root'iga aylanadi.
- Dev dependency'lar va build asboblari runtime image'da: hajm va CVE soni bir necha barobar.
- Bitta tag'ni (`:prod`, `:latest`) qayta-qayta yozish: qaysi kod ishlayotganini bilib bo'lmaydi, rollback qilishga nuqta yo'q.
- Build'ni faqat o'z arxitekturangizda tekshirish: server arm64 bo'lsa `exec format error`.
- Skanerni bir marta ishlatib unutish: CVE bazasi har kuni yangilanadi.

## Manbalar

- https://docs.docker.com/reference/dockerfile/ – Dockerfile reference (majburiy)
- https://docs.docker.com/build/building/best-practices/ – Dockerfile best practices
- https://docs.docker.com/build/cache/ – build cache va invalidatsiya qoidalari
- https://docs.docker.com/build/building/multi-stage/ – multi-stage build
- https://docs.docker.com/build/building/secrets/ – build secret'lar
- https://docs.docker.com/build/building/multi-platform/ – ko'p platformali build
- https://docs.docker.com/engine/storage/drivers/overlayfs-driver/ – OverlayFS qanday ishlaydi
- https://github.com/opencontainers/image-spec – OCI image spetsifikatsiyasi (manifest, index, layer)
- https://github.com/GoogleContainerTools/distroless – distroless image'lar ro'yxati va tag'lari
- https://trivy.dev/ – Trivy hujjatlari; https://github.com/aquasecurity/trivy/releases – versiyalar
- https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry – GHCR bilan ishlash
- https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md – Node.js image best practices

---

## Vazifalar

Barchasini `docker/02-images/` da bajaring (`make new m=docker n=02 name=images`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Ilovalar `node-app/` va `go-app/` ichki papkalarida, har birida o'z `Dockerfile` va `.dockerignore` bilan.

Ilovalar (o'zingiz yozasiz, har biri 30–50 qator): TypeScript'dagi HTTP server (kamida bitta runtime dependency va `tsc` build bilan) va Go'dagi HTTP server (faqat standart kutubxona). Ikkalasi: `GET /` matn qaytaradi, `GET /healthz` `200`, port `PORT` env'dan, `SIGTERM` da "shutting down" deb log yozib toza to'xtaydi.

### A. Image anatomiyasi

1. **Layers and history.** `nginx:1.28-alpine` uchun `docker history` va `docker image inspect -f '{{json .RootFS.Layers}}'` ni ko'ring. Nechta layer bor, qaysi instruksiyalar layer yaratgan, qaysilari hajmi 0? `alpine:3.22` layer'i nginx image'ining layer'lari orasida bormi va bu disk sarfi uchun nimani anglatadi?

2. **Overlay mounts.** `alpine:3.22` konteynerida `head -1 /proc/mounts` ni chiqaring, `lowerdir`, `upperdir` qismlarini ajrating. Ikkita konteynerni bitta image'dan ishga tushirib solishtiring: nimasi bir xil, nimasi farq qiladi? Konteynerda `/etc/hostname` dan boshqa biror faylni o'zgartirib `docker diff` bilan copy-on-write natijasini ko'rsating.

3. **Tag vs digest.** `docker buildx imagetools inspect node:24-alpine` natijasidan image index digest'i va `linux/amd64` manifest digest'ini toping. `docker pull node:24-alpine@sha256:<digest>` bilan torting. Tag va digest bo'yicha pull farqi, qaysi biri production `FROM` uchun to'g'ri ekanini izohlang.

4. **Deleted file stays.** Dockerfile yozing: `alpine:3.22` ustida bitta `RUN` da `dd` bilan 50 MB fayl yarating, keyingi `RUN` da o'chiring. Image hajmi va `docker history` ni ko'rsating. Keyin ikkalasini bitta `RUN` ga birlashtirib qayta o'lchang va farqni izohlang.

### B. Node.js ilovasi

5. **Naive Dockerfile.** `node-app/Dockerfile.naive` yozing: `node:24` base, `COPY . .`, `npm install`, `npm run build`, shell form `CMD npm start`. Build qilib (`lesson02/node-app:naive`) hajmini, build vaqtini va `docker run` da kim nomidan ishlayotganini (`docker exec <c> id`) yozing. Bu fayldagi kamida 5 ta muammoni sanang.

6. **Cache ordering.** Naive variantda manba koddagi bitta qatorni o'zgartirib qayta build qiling, qaysi qadamlar `CACHED` bo'lganini yozing. Keyin dependency manifestlarini alohida nusxalaydigan tartibga o'tkazing va tajribani takrorlang. Ikki holatdagi vaqtni jadvalga yozing va invalidatsiya zanjirini izohlang.

7. **dockerignore.** `.dockerignore` siz `--progress=plain` bilan build qilib `transferring context` hajmini yozing. Papkaga soxta `.env` (ichida `SECRET=test`) qo'ying, `COPY . .` dan keyin image ichida u borligini ko'rsating. `.dockerignore` yozib ikkala o'lchovni takrorlang.

8. **Multi-stage Node.** Yakuniy `node-app/Dockerfile`: build stage (`npm ci`, `tsc`), runtime stage (`node:24-alpine` yoki distroless, faqat production dependency'lar va kompilyatsiya natijasi), `npm` cache mount, non-root user, exec form. `lesson02/node-app:1.0` hajmini naive bilan solishtiring. `docker run --rm lesson02/node-app:1.0 ls node_modules/.bin` orqali dev dependency'lar yo'qligini ko'rsating (distroless bo'lsa boshqa usul toping).

9. **Signals and exec form.** `lesson02/node-app:1.0` va `:naive` ni ishga tushirib `time docker stop` qiling. Vaqt, exit code va "shutting down" logi chiqqan-chiqmaganini solishtiring. Har ikki holatda `docker top` bilan PID 1 kim ekanini ko'rsating.

10. **Non-root check.** Yakuniy image'da `id`, `/` ga fayl yozish urinishi va ilova papkasiga yozish urinishini tekshiring. Konteynerni `--read-only` bilan ishga tushiring: ilova ishlaydimi? Ishlamasa xatoni o'qing va `--tmpfs` bilan tuzating.

### C. Go ilovasi

11. **Multi-stage Go.** `go-app/Dockerfile`: `golang:1.26-alpine` build stage (`go mod download` alohida layer, cache mount'lar), `CGO_ENABLED=0`, runtime sifatida distroless static nonroot. Hajmni yozing. Build stage'ni `--target` bilan alohida qurib uning hajmi bilan solishtiring.

12. **scratch vs distroless.** Xuddi shu binary'ni `FROM scratch` bilan ham quring. Ilovaga `GET /out` handler qo'shing: u `https://example.com` ga so'rov yuborib status kodini qaytarsin. Ikkala image'da sinang, scratch'dagi xatoni yozing va sababini toping. `scratch` da qaysi foydalanuvchi nomidan ishlayapti?

13. **Build args and labels.** `ARG VERSION` ni `-ldflags "-X main.version=$VERSION"` orqali binary'ga kiriting, `GET /` uni qaytarsin. `org.opencontainers.image.source`, `.version`, `.revision` label'larini qo'shing. `docker build --build-arg VERSION=1.2.3` qilib `docker image inspect -f '{{json .Config.Labels}}'` va `curl` bilan tekshiring. `docker history` da `VERSION` qiymati ko'rinadimi?

14. **CMD and ENTRYPOINT.** Go ilovasiga `--port` flag'i qo'shing. `ENTRYPOINT ["/app"]` va `CMD ["--port", "8080"]` bilan quring. Tekshiring va izohlang: `docker run IMAGE`, `docker run IMAGE --port 9090`, `docker run --entrypoint /app IMAGE --help`. Keyin `ENTRYPOINT` ni shell form'ga o'zgartirib (alpine base'li vaqtinchalik variantda) `docker run IMAGE --port 9090` nima qilishini ko'rsating.

15. **Multi-platform build.** `--platform=$BUILDPLATFORM`, `TARGETOS`, `TARGETARCH` yordamida `linux/amd64,linux/arm64` uchun bitta buyruq bilan quring. Build logida `RUN` qaysi platformada bajarilganini ko'rsating. Nima uchun bu yerda QEMU kerak bo'lmadi va Node ilovasida (native modul bo'lsa) nima uchun kerak bo'lar edi?

### D. Xavfsizlik va registry

16. **Leaked secret.** Vaqtinchalik Dockerfile'da soxta token'ni uch usulda bering: `ARG`, `ENV`, va `COPY` qilib keyingi `RUN` da o'chirish. Har birini `docker history --no-trunc`, `docker image inspect` yoki `docker save` qilib tar ichidan qidirib toping. Keyin `RUN --mount=type=secret` bilan qayta yozib, tokenni hech biridan topib bo'lmasligini ko'rsating.

17. **Dockerfile lint.** Uchala Dockerfile uchun (naive ham) `docker build --check` ni ishlating. Ogohlantirishlarni yozing va yakuniy ikki faylda hammasini tuzating.

18. **Vulnerability scan.** Trivy'ni konteyner sifatida ishlatib `lesson02/node-app:naive`, `lesson02/node-app:1.0` va `lesson02/go-app` ni `HIGH,CRITICAL` bo'yicha skanerlang. Natijani jadvalga yozing (image, base, hajm, HIGH, CRITICAL). Topilmalar OS paketlaridami yoki til dependency'laridami? Bittasini tuzatish yo'lini (base yangilash, paket versiyasi) toping va qo'llang.

19. **Push to registry.** GHCR yoki Docker Hub'ga `--password-stdin` bilan login qiling, ikkala yakuniy image'ni semver tag va git SHA tag bilan push qiling. Ikkinchi push'da qaysi layer'lar `Layer already exists` bo'lganini yozing. `docker buildx imagetools inspect` bilan registry'dagi digest va platformalarni ko'rsating. Lokal image'ni o'chirib digest bo'yicha pull qilib ishga tushiring. `~/.docker/config.json` da nima saqlanganini (qiymatni README'ga yozmasdan) tasvirlang, keyin `docker logout`.

### E. Yakuniy

20. **Image checklist.** O'z image'laringiz uchun 10–12 banddan iborat tekshiruv ro'yxatini `CHECKLIST.md` ga yozing (pinned base, layer tartibi, `.dockerignore`, non-root, exec form, secret yo'q, skaner, label, tag strategiyasi va hokazo) va ikkala yakuniy image'ni shu ro'yxat bo'yicha baholang: har bandda qaysi buyruq bilan tekshirganingiz ko'rsatilsin.

21. **Cleanup.** `lesson02/*` image'larini, test konteynerlarini va build cache'ni tozalang (`docker buildx du` oldin va keyin). Registry'dagi test image'larni o'chiring yoki private ekanini tekshiring. `docker image prune` va `docker image prune -a` farqini izohlang va nima uchun bu mashinada `-a` ni ehtiyotsiz ishlatmaslik kerakligini yozing.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. `docker build --check` ikkala yakuniy Dockerfile uchun ogohlantirishsiz.
3. Papkada token, `.env`, `app.tar` kabi fayllar yo'q (`git status` bilan tekshiring).
4. Lokal `lesson02/*` image'lar va test konteynerlar o'chirilgan, `docker logout` qilingan.
5. Menga xabar bering, Dockerfile'lar va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Layer nima va nima uchun ikki image bitta layer'ni bo'lisha oladi?
- Keyingi `RUN` da o'chirilgan fayl nima uchun image hajmini kamaytirmaydi?
- Tag va digest farqi nima? `latest` nimani kafolatlaydi?
- `COPY package*.json` ni `COPY . .` dan oldin qo'yish nima beradi? Cache qachon invalidatsiya bo'ladi?
- `CMD` va `ENTRYPOINT` birga qanday ishlaydi? `docker run IMAGE arg` har biriga qanday ta'sir qiladi?
- Shell form `CMD` da `docker stop` nima uchun 10 sekund kutadi?
- Multi-stage build qaysi ikki muammoni yechadi?
- alpine, slim, distroless, scratch: har birini qachon tanlaysiz va har birining narxi nima?
- `ARG` orqali berilgan token nima uchun xavfsiz emas va to'g'ri usul qanday?
- Bugun skanerdan toza o'tgan image bir oydan keyin nima uchun zaif bo'lishi mumkin?
