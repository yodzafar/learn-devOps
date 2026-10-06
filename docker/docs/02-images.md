# 2-dars: Image'lar

Maqsad: image ichida nima borligini (layer, config, manifest, digest), layer'lar konteynerda qanday bitta fayl tizimiga birlashishini (OverlayFS) va image nima uchun bitta protsessor arxitekturasiga bog'liqligini noldan tushunish, keyin shu bilim asosida tez quriladigan, kichik, non-root, takrorlanuvchi image yozish. 1-darsda tayyor image'larni ishga tushirdingiz, bu darsda o'z ilovangizni (Node.js va Go) qadoqlaysiz, skanerlaysiz va registry'ga push qilasiz. 4-darsdagi Compose `build`, 5-darsdagi Swarm va keyingi CI/CD moduli shu yerda qurilgan image'larni ishlatadi.

Taxminiy vaqt: 6 kun (siz uchun). 1-kun: 1–3 bo'limlar va A guruh. 2-kun: 4–5 bo'limlar, ilovani yozish, 5–7-vazifalar. 3-kun: 6–7 bo'limlar, 8–10-vazifalar. 4-kun: "Birga bajaramiz" va C guruh (11–15). 5-kun: 8–9 bo'limlar va D guruh. 6-kun: E guruh, tozalash, README. Diqqatni mexanizmga qarating: cache qanday invalidatsiya bo'ladi, o'chirilgan fayl nima uchun image'da qoladi, `CMD` va `ENTRYPOINT` qanday qo'shiladi, shell form signalni qayerda yo'qotadi, tag va digest farqi, Mac'da qurilgan image Zorin'da nima uchun ishlamasligi mumkin.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Digest, ID, hajm va vaqtlar sizda boshqa bo'ladi, darsda ular `<...>` bilan belgilangan. Nazariya misollari ataylab vazifalardagidan boshqa holatda (kichik Python va C image'lari), vazifadagi Node va Go ilovasiga o'zingiz moslaysiz.

## Laboratoriya

Uchta joy ishlatiladi:

| Joy | Nima bajariladi |
|-----|-----------------|
| Host (Zorin yoki macOS) | barcha `docker build`, `run`, `push`, `buildx` buyruqlari, `make check`, `git` |
| `lab` VM ichidagi Docker | faqat 2-bo'lim: layer'larning diskdagi ko'rinishi (`/var/lib/docker`). Bu yerda build qilinmaydi |
| Registry (GHCR yoki Docker Hub) | 19-vazifa: push va digest bo'yicha pull |

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Siz qurgan image `linux/amd64`. Engine host kernel'ida, `/var/lib/docker` host'da bor (ixtiyoriy kuzatish mumkin, `sudo` bilan faqat o'qish). `arm64` image'ni ishlatish yoki `RUN` qilish uchun QEMU emulyatsiyasi alohida yoqiladi (8-bo'lim). Login tokeni credential helper bo'lmasa `~/.docker/config.json` da base64 ko'rinishida yotadi. `docker scout` yo'q. |
| macOS (uy) | Siz qurgan image `linux/arm64`. Engine Docker Desktop'ning yashirin Linux VM'ida, `/var/lib/docker` Mac'da ko'rinmaydi. `amd64` emulyatsiyasi Docker Desktop bilan birga keladi. Login tokeni macOS keychain'da saqlanadi. `docker scout` Desktop bilan birga o'rnatilgan. |

Eng muhim farq birinchisi: bir mashinada qurib push qilingan bitta arxitekturali image ikkinchisida `exec format error` beradi yoki emulyatsiyada sekin ishlaydi. Shuning uchun lokal image'lar har mashinada qaytadan quriladi (Dockerfile git orqali ko'chadi, image emas), registry'ga esa ko'p platformali image push qilinadi (3 va 8-bo'limlar).

Tekshiruv (ikkala host'da):

```
docker version --format '{{.Server.Os}}/{{.Server.Arch}}'   # linux/amd64 or linux/arm64
docker buildx version
docker info --format '{{.Driver}} {{.DriverStatus}}'
```

Oxirgi buyruq image store turini aytadi: `overlayfs` va `io.containerd.snapshotter.v1` bo'lsa containerd image store yoqilgan (ko'p platformali image'ni lokal saqlay oladi), `overlay2` bo'lsa klassik store (8-bo'limda nima o'zgarishi aytilgan). Build BuildKit orqali ketadi (Engine 23.0 dan default), `docker build` bu `docker buildx build` ning qisqa shakli.

**`lab` VM'dagi Docker.** `network` modulining 1-darsida o'rnatilgan. Ikkinchi mashinada yoki toza VM'da tiklash:

```
multipass shell lab
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker ubuntu     # then exit and enter the VM again
docker info --format '{{.Driver}}'
```

VM kichik (2 CPU, 2G RAM, 10G disk), shuning uchun unda faqat `alpine` tortiladi va dars oxirida o'chiriladi.

**hadolint** (`make check` Dockerfile'larni shu bilan tekshiradi). hadolint bu Dockerfile linter'i: faylni qurmasdan o'qib, ma'lum xatolar bo'yicha `DL<raqam>` kodli ogohlantirish beradi.

- Zorin: https://github.com/hadolint/hadolint/releases sahifasidan Linux `x86_64` binary'sini yuklab, `~/.local/bin/hadolint` ga qo'ying va `chmod +x` qiling (`sudo` kerak emas, fayl nomini sahifadan oling).
- macOS: `brew install hadolint` (`arm64`).
- Tekshiruv: `hadolint --version`.

**Registry akkaunti**: Docker Hub yoki GitHub (GHCR uchun `write:packages` huquqli personal access token). Token faqat `docker login --password-stdin` ga beriladi, faylga yozilmaydi, commit qilinmaydi. Login har mashinada alohida: credential mashinalar orasida ko'chmaydi.

**Nomlash va tozalash.** Shu darsdagi image'lar `lesson02/` prefiksi bilan nomlanadi (`lesson02/node-app:1.0`), faqat shular o'chiriladi:

```
docker image ls 'lesson02/*'
docker image rm $(docker image ls -q 'lesson02/*')
docker buildx du            # build cache usage
docker builder prune        # removes unused build cache (of all projects on this machine)
```

`docker system prune` va `docker image prune -a` ishlatilmaydi: ikkala mashinada boshqa loyihalarning image'lari bor. Trivy skaneri konteyner sifatida ishlatiladi, host'ga o'rnatilmaydi.

---

## 1. Image ichida nima bor

### Uch qism: layer, config, manifest

1-darsda image "konteynerning boshlang'ich fayl tizimi" deb ta'riflangan edi. Aniqrog'i image uch turdagi obyektdan iborat:

| Obyekt | Nima | Format |
|--------|------|--------|
| Layer | fayl tizimining bitta o'zgarishlar to'plami: qo'shilgan, o'zgargan, o'chirilgan fayllar | tar arxiv (odatda gzip bilan siqilgan) |
| Config | image qanday ishga tushishi: env, `Cmd`, `Entrypoint`, user, ish papkasi, arxitektura, layer'lar tartibi | JSON |
| Manifest | "bu image shu config va shu layer'lardan iborat" degan ro'yxat | JSON |

Layer'lar tartibli va faqat o'qiladi (read-only): birinchisi base (masalan Alpine fayllari), har keyingisi oldingisiga nisbatan farq. Image hech qachon o'zgarmaydi (immutable), "o'zgartirish" bu yangi layer qo'shilgan yangi image. Konteyner esa shu image ustiga bitta yoziladigan layer qo'shilgan jarayon (2-bo'lim).

### Mexanizm: content addressing

Har obyektning nomi uning mazmunidan hisoblangan SHA-256 hash, bu **digest** deyiladi (`sha256:` va 64 ta hex belgi). Buni content addressing (mazmun bo'yicha manzillash) deyishadi. Zanjir: manifest ichida config va har layer digest'i yozilgan, manifestning o'z digest'i esa butun image'ning identifikatori. Bitta baytni o'zgartirsangiz layer digest'i, demak manifest digest'i ham o'zgaradi. Natijalari:

- bir xil layer diskda va registry'da bir marta saqlanadi, image'lar uni bo'lishadi;
- `pull` va `push` faqat yetishmayotgan layer'larni uzatadi;
- digest bo'yicha olingan image aynan o'sha baytlar ekani tekshiriladi.

`package-lock.json` dagi `integrity` maydoni xuddi shu g'oya: paket nomi va versiyasi emas, mazmunining hash'i ishonchli.

### Misol: layer'lar va ularni yaratgan instruksiyalar

```
$ docker pull alpine:3.22
$ docker history alpine:3.22
IMAGE       CREATED    CREATED BY                                      SIZE      COMMENT
<id>        <vaqt>     CMD ["/bin/sh"]                                 0B        buildkit.dockerfile.v0
<missing>   <vaqt>     ADD alpine-minirootfs-<ver>-<arch>.tar.gz / …   <hajm>    buildkit.dockerfile.v0
```

Ro'yxat teskari tartibda: pastdagi qator birinchi bajarilgan. `CREATED BY` layer'ni yaratgan Dockerfile instruksiyasi. `ADD ...` qatori fayl qo'shgan, hajmi noldan katta: bu haqiqiy layer. `CMD` qatori `0B`: u faqat config'ni o'zgartirgan, fayl tizimiga tegmagan. `<missing>` xato emas: oraliq qadamning alohida image ID'si lokal saqlanmaganini bildiradi.

```
$ docker image inspect -f '{{json .RootFS.Layers}}' alpine:3.22
["sha256:<digest>"]
$ docker image inspect -f '{{.Os}}/{{.Architecture}}  cmd={{json .Config.Cmd}}  user={{json .Config.User}}' alpine:3.22
linux/arm64  cmd=["/bin/sh"]  user=""
```

Birinchi buyruq haqiqiy layer'lar ro'yxati (bitta, `history` dagi `0B` qatorlar bu yerda yo'q). Ikkinchisi config'dan uch maydon: platforma (Zorin'da `linux/amd64`), default buyruq, foydalanuvchi (`""` root degani). Image store turiga qarab `docker image ls` dagi `IMAGE ID` config yoki manifest digest'ining boshi bo'ladi, shuning uchun ikki mashinada ID'ni solishtirmang, digest'ni solishtiring (3-bo'lim).

### Real ishda qachon kerak

- "Image nega 1 GB?" degan savolga `docker history` javob beradi: qaysi instruksiya qancha qo'shgan.
- Deploy sekin bo'lsa: layer'lar bo'lishilgani uchun base bir xil image'lar tez tortiladi, har safar butunlay o'zgaradigan katta layer esa sekin.
- Xavfsizlik tekshiruvida: config'da `User` bo'sh bo'lsa image root sifatida ishlaydi.

### Nima uchun shunday

Layer'lar ikki muammoni yechadi: takroriy saqlash (yuzta image bitta Debian base'ni bo'lishadi) va tezkor build (o'zgarmagan qadam qayta bajarilmaydi, 5-bo'lim). Format Open Container Initiative (OCI, 2015-yilda tashkil topgan) tomonidan standartlashtirilgan: Docker, containerd, Podman va Kubernetes bir xil image'ni tushunadi. Muqobili VM image'i (bitta katta disk fayli): u bo'lishilmaydi va har o'zgarishda to'liq ko'chiriladi.

## 2. Union filesystem: layer'lar qanday bitta daraxtga aylanadi

### OverlayFS

Union filesystem bu bir necha papkani ustma-ust qo'yib bitta papka kabi ko'rsatadigan fayl tizimi. Linux kernel'idagi amalga oshirilishi **OverlayFS**, Docker uni ishlatadi. Konteyner ishga tushganda kernel `overlay` turidagi mount yaratadi (mount: fayl tizimini daraxtdagi papkaga ulash, `linux` 1-dars):

| Qism | Roli |
|------|------|
| `lowerdir` | image layer'lari, faqat o'qish, bir nechta papka `:` bilan ajratilgan |
| `upperdir` | shu konteynerning yoziladigan layer'i |
| `workdir` | OverlayFS'ning o'z ichki ish papkasi |
| `merged` | natija: konteyner ko'radigan `/` |

O'qish: fayl yuqoridan pastga qidiriladi, birinchi topilgani ko'rinadi. Yozish ikki qoidaga bo'ysunadi:

- **Copy-on-write**: pastki layer'dagi faylni o'zgartirganda u avval to'liq `upperdir` ga nusxalanadi, keyin o'zgartiriladi. Katta faylni (masalan baza fayli) konteyner layer'ida o'zgartirish sekin, buning uchun volume bor (3-dars).
- **Whiteout**: faylni o'chirish pastki layer'ga tegmaydi, `upperdir` ga "bu fayl yo'q" belgisi qo'yiladi.

### Misol: konteyner ichidan va tashqaridan

Konteyner ichidan (ikkala host'da ishlaydi):

```
$ docker run --rm alpine:3.22 head -1 /proc/mounts
overlay / overlay rw,relatime,lowerdir=<yo'llar>,upperdir=<yo'l>,workdir=<yo'l> 0 0
```

Maydonlar: qurilma nomi (`overlay`), mount nuqtasi (`/`), fayl tizimi turi, keyin parametrlar. `lowerdir`, `upperdir` yo'llari Engine ishlayotgan Linux'ning yo'llari, konteyner ichida ular mavjud emas.

O'sha papkalarni tashqaridan ko'rish uchun `lab` VM (Mac'da yagona yo'l, Zorin'da host'da ham bo'ladi):

```
ubuntu@lab:~$ docker run -d --name l02-ov alpine:3.22 sleep 600
ubuntu@lab:~$ docker exec l02-ov sh -c 'echo hi > /new.txt; rm /etc/motd'
ubuntu@lab:~$ docker diff l02-ov
A /new.txt
C /etc
D /etc/motd
ubuntu@lab:~$ UP=$(docker inspect -f '{{.GraphDriver.Data.UpperDir}}' l02-ov)
ubuntu@lab:~$ sudo ls -l $UP $UP/etc
<UpperDir>:
drwxr-xr-x <n> root root <hajm> <sana> etc
-rw-r--r-- 1 root root 3 <sana> new.txt
<UpperDir>/etc:
c--------- <n> root root 0, 0 <sana> motd
ubuntu@lab:~$ docker rm -f l02-ov
```

`docker diff` konteyner layer'ining image'ga nisbatan farqi: `A` qo'shilgan, `C` o'zgargan, `D` o'chirilgan. `UpperDir` da aynan shu uch narsa yotadi: yangi `new.txt` oddiy fayl, `etc` papkasi (ichida o'zgarish bor), `motd` esa `c` turidagi `0, 0` raqamli qurilma fayli. Bu whiteout: fayl image layer'ida joyida turibdi, ustiga "yo'q" belgisi qo'yilgan. Agar `docker info` da driver `overlayfs` bo'lsa (containerd store), papkalar `/var/lib/containerd` ostida va `GraphDriver` maydoni boshqacha bo'lishi mumkin, u holda yo'llarni `/proc/mounts` qatoridan oling.

**Tuzoq: keyingi layer'da o'chirish hajmni kamaytirmaydi.** `RUN curl -O <url>/big.tar.gz` va keyingi qatorda `RUN rm big.tar.gz` yozilsa fayl birinchi layer'da qoladi, ikkinchi layer'da faqat whiteout bor. Yuklash, ishlatish va o'chirish bitta `RUN` ichida bo'lishi kerak. Xuddi shu sabab bilan `COPY` qilingan secret keyin o'chirilsa ham layer'dan o'qib olinadi.

### Real ishda qachon kerak

- Konteyner "ichida nimadir o'zgargan" deb gumon qilinsa `docker diff` ko'rsatadi.
- Disk to'lganda: konteyner layer'iga yozilayotgan log yoki vaqtinchalik fayllar `/var/lib/docker` ni to'ldiradi, konteyner o'chganda yo'qoladi.
- Image hajmini kamaytirishda: o'chirish emas, layer'ga tushirmaslik kerak.

### Nima uchun shunday

Muqobili har konteynerga image'ning to'liq nusxasini berish: yuzta konteyner yuz barobar disk va sekin start. OverlayFS bilan konteyner start'i bitta mount, bitta image'dan olingan konteynerlar `lowerdir` ni bo'lishadi va faqat o'z `upperdir` iga ega. Narxi: copy-on-write birinchi yozuvda sekin va o'chirish joy bo'shatmaydi. Docker avval AUFS va devicemapper ishlatgan, OverlayFS kernel'ning o'zida (3.18 dan) bo'lgani uchun standartga aylandi.

## 3. Nom, tag, digest va platforma

### Nomning qismlari

```
ghcr.io / yodzafar / node-app : 1.4.2 @ sha256:9f2c...
registry  namespace  repository  tag     digest
```

Registry bu image'larni saqlaydigan va HTTP orqali beradigan server (npm registry'ning image'lar uchun o'xshashi). Registry yozilmasa `docker.io` (Docker Hub), namespace yozilmasa `library` (rasmiy image'lar): `nginx` bu `docker.io/library/nginx:latest`.

- **Tag** o'zgaruvchan ko'rsatkich, git'dagi branch kabi: `python:3.13-slim` bugun va bir oydan keyin boshqa image bo'lishi mumkin. `latest` shunchaki tag yozilmagandagi default nom, "eng yangi" degan kafolati yo'q.
- **Digest** manifest hash'i, o'zgarmas, git'dagi commit SHA kabi. `FROM python:3.13-slim@sha256:<digest>` har doim aynan bir image.

`package.json` dagi `^1.4.0` va `package-lock.json` dagi aniq versiya va `integrity` orasidagi farq aynan shu: tag qulay, digest takrorlanuvchi.

### Platforma va image index

Image ichidagi binary'lar ma'lum protsessor arxitekturasi uchun kompilyatsiya qilingan (`linux` 1-dars: `x86_64`/`amd64` va `aarch64`/`arm64`). Bitta manifest bitta platformani (`os/arch`) tasvirlaydi. Ko'p platformali image'da tag manifestga emas, **image index** ga (Docker atamasida manifest list) ishora qiladi: bu "qaysi platforma uchun qaysi manifest" ro'yxati. `docker pull` Engine platformasiga mos manifestni o'zi tanlaydi, shuning uchun bir xil `alpine:3.22` nomi Zorin'da `amd64`, Mac'da `arm64` baytlarni beradi.

```
$ docker buildx imagetools inspect alpine:3.22
Name:      docker.io/library/alpine:3.22
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:<index-digest>

Manifests:
  Name:        docker.io/library/alpine:3.22@sha256:<digest-1>
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64

  Name:        docker.io/library/alpine:3.22@sha256:<digest-2>
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64/v8
  ...
```

Bu buyruq hech narsa tortmaydi, registry'dan faqat manifestni o'qiydi. Yuqori qism: `MediaType` da `image.index` so'zi bu index ekanini aytadi, `Digest` index'ning digest'i (ikkala mashinada bir xil). `Manifests` ostida har platforma uchun alohida manifest va alohida digest. `Platform: unknown/unknown` qatorlari ham chiqishi mumkin: ular image emas, build haqidagi attestation (kim va nimadan qurgani) ma'lumoti.

Digest bo'yicha pull qilinganda index digest'i berilsa platforma yana avtomatik tanlanadi, platforma manifestining digest'i berilsa aynan o'sha arxitektura keladi.

### Misol: begona arxitektura

```
$ docker run --rm alpine:3.22 uname -m
aarch64                                  # x86_64 on Zorin
$ docker run --rm --platform linux/amd64 alpine:3.22 uname -m
x86_64                                   # on macOS: runs under emulation
```

`--platform` boshqa arxitektura manifestini tanlaydi. Mac'da Docker Desktop emulyatsiyasi tufayli ishlaydi (sekinroq). Zorin'da `--platform linux/arm64` emulyatsiya yoqilmagan bo'lsa `exec format error` bilan tugaydi: kernel begona arxitektura binary'sini ishga tushira olmaydi. Sinovdan keyin begona platforma image'ini o'chiring (`docker image rm`), aks holda keyingi `docker run alpine:3.22` ogohlantirish berishi mumkin.

### Real ishda qachon kerak

- Mac'da qurib `amd64` serverga deploy qilish: eng ko'p uchraydigan `exec format error` manbai.
- Production Dockerfile'da base'ni digest bilan qotirish, deploy'da tag emas digest ishlatish.
- "Kecha ishlagan build bugun buzildi": tag ostidagi image almashgan, `imagetools inspect` digest'ni ko'rsatadi.

### Nima uchun shunday

Tag odam uchun (o'qiladi, yangilanadi), digest mashina uchun (aniq, tekshiriladi). Ikkalasi kerak: faqat digest bo'lsa xavfsizlik yangilanishlarini olish qiyin, faqat tag bo'lsa takrorlanuvchanlik yo'q. Image index esa bitta nom ostida bir necha arxitekturani berish uchun kiritilgan: usiz `myapp:1.0-amd64`, `myapp:1.0-arm64` kabi alohida tag'lar va har joyda shartli tanlash kerak bo'lar edi.

## 4. Dockerfile va build context

### Dockerfile nima

`Dockerfile` image'ni qurish retsepti: yuqoridan pastga bajariladigan instruksiyalar ro'yxati. `docker build` uni o'qiydi, har instruksiyani vaqtinchalik konteynerda bajaradi va natijani layer yoki config o'zgarishi sifatida yozadi.

| Instruksiya | Vazifasi | Layer |
|-------------|----------|-------|
| `FROM image[:tag] [AS name]` | base image, yangi stage boshlaydi | yo'q |
| `RUN cmd` | build paytida buyruq bajaradi | ha |
| `COPY [--chown=u:g] [--from=stage] src dst` | context yoki boshqa stage'dan nusxalash | ha |
| `ADD` | `COPY` + URL va tar ochish. Odatda `COPY` ishlatiladi | ha |
| `WORKDIR /app` | joriy papka (yo'q bo'lsa yaratadi) | yo'q |
| `ENV K=v` | build va runtime'da environment o'zgaruvchisi | yo'q |
| `ARG K[=default]` | faqat build paytidagi o'zgaruvchi (`--build-arg`) | yo'q |
| `USER uid[:gid]` | keyingi `RUN` va runtime foydalanuvchisi | yo'q |
| `EXPOSE 3000` | hujjat: qaysi port tinglanadi. Portni ochmaydi | yo'q |
| `CMD`, `ENTRYPOINT` | konteyner start buyrug'i (6-bo'lim) | yo'q |
| `HEALTHCHECK` | sog'liq tekshiruvi (3-darsda) | yo'q |
| `LABEL k=v` | metadata (`org.opencontainers.image.source` va boshqalar) | yo'q |
| `VOLUME`, `STOPSIGNAL`, `SHELL` | anonim volume e'loni, stop signali, shell form uchun shell | yo'q |

Kichik misol (statik fayllarni beradigan Python image'i):

```
# syntax=docker/dockerfile:1
FROM python:3.13-slim
WORKDIR /srv
COPY public/ ./public/
EXPOSE 8000
CMD ["python", "-m", "http.server", "8000", "--directory", "public"]
```

Birinchi qator Dockerfile frontend'ining oxirgi barqaror 1.x versiyasini tanlaydi (`RUN --mount` kabi imkoniyatlar uchun). `ARG` va `ENV` farqi: `ARG` runtime'da yo'q, `ENV` image config'ida qoladi. `FROM` dan oldingi `ARG` faqat `FROM` qatorida ko'rinadi, stage ichida kerak bo'lsa qayta e'lon qilinadi.

**Tuzoq: `ARG` va `ENV` secret uchun emas.** `--build-arg` qiymati `docker history` da, `ENV` esa config'da ko'rinadi. To'g'ri usul secret mount (8-bo'lim).

### Build context va .dockerignore

`docker build -t lesson02/static:1.0 .` oxiridagi nuqta **build context**: builder'ga yuboriladigan papka. `COPY` faqat shu ichidan o'qiy oladi, `COPY ../x` ishlamaydi. Fayl boshqa joyda bo'lsa `-f path/Dockerfile`, bitta stage'gacha qurish uchun `--target name`.

Context ildizidagi `.dockerignore` fayllarni context'dan chiqaradi. Sintaksisi `.gitignore` ga o'xshash, vazifasi `.npmignore` bilan bir xil: "paketga nima kirmasin". Python loyihasi uchun:

```
.git
.venv
__pycache__
.env*
*.log
```

Usiz uch muammo: `COPY . .` bo'lganda katta papkalar (`.git`, dependency papkasi) builder'ga yuboriladi (sekin); `COPY . .` host'dagi dependency papkasini image ichidagisining ustiga yozadi (Mac'da o'rnatilgan native binary Linux image'ida ishlamaydi); `.env` va kalitlar image'ga tushib registry'ga ketadi. Context hajmi build logida ko'rinadi:

```
$ docker build --progress=plain -t lesson02/static:1.0 . 2>&1 | grep 'transferring context'
#<n> transferring context: <hajm> done
```

### Real ishda qachon kerak

Har yangi servis uchun: Dockerfile bilan birga `.dockerignore` yoziladi. CI'da "build uzoq vaqt context yuklaydi" shikoyatining sababi odatda `COPY . .` va `.dockerignore` yo'qligi: `.git` yoki dependency papkasi yuborilmoqda.

### Nima uchun shunday

Retsept fayl bo'lgani uchun image qanday qurilgani git'da turadi va istalgan mashinada takrorlanadi. Muqobili konteynerga kirib qo'lda sozlab `docker commit` qilish: natijani hech kim qayta qura olmaydi. Context cheklovi xavfsizlik va takrorlanuvchanlik uchun: build faqat aniq berilgan papkani ko'radi, mashinangizning qolgan qismini emas.

## 5. Build cache va layer tartibi

### Mexanizm

BuildKit (Docker'ning build dvigateli) har instruksiya uchun "kirishlar o'zgarganmi" deb tekshiradi, o'zgarmagan bo'lsa oldingi natijani cache'dan oladi:

- `RUN`: buyruq matni va oldingi layer. Buyruq tashqaridan nima yuklashi (masalan `apt-get update` natijasi) hisobga olinmaydi.
- `COPY`, `ADD`: nusxalanayotgan fayllarning mazmuni (checksum). Vaqt belgisi hisobga olinmaydi.
- Bitta instruksiya cache'dan chiqsa (miss), **undan keyingi hammasi** qayta bajariladi.

Qoida: kam o'zgaradigan narsa yuqorida, tez-tez o'zgaradigan pastda. Dependency ro'yxati manba koddan oldin nusxalanadi:

```
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

Kod o'zgarganda faqat oxirgi `COPY` qayta bajariladi, `pip install` cache'dan keladi:

```
 => CACHED [2/4] COPY requirements.txt ./
 => CACHED [3/4] RUN pip install --no-cache-dir -r requirements.txt
 => [4/4] COPY . .
```

`CACHED` so'zi qadam bajarilmaganini bildiradi, `[3/4]` qadam raqami. `COPY . .` birinchi turganida bitta harf o'zgarishi barcha dependency'larni qayta o'rnatadi. Node'da `node_modules` ni har commit'da qayta o'rnatmaslik uchun CI'da lock fayl bo'yicha cache qilinishi bilan bir xil g'oya.

Qo'shimcha vositalar:

- **Cache mount**: `RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt`. Paket menejeri cache'i layer'ga kirmaydi, lekin build'lar orasida saqlanadi. npm uchun `/root/.npm`, Go uchun `/go/pkg/mod` va `/root/.cache/go-build`.
- `docker build --no-cache`, `--pull` (base image'ni qayta tekshirish), `--progress=plain` (to'liq log).
- `docker build --check`: build qilmasdan Dockerfile'ni tekshiradi.

**Tuzoq: `apt-get update` alohida `RUN` da.** U cache'da qoladi, keyingi `RUN apt-get install` eskirgan indeks bilan ishlaydi. Har doim birga: `RUN apt-get update && apt-get install -y --no-install-recommends <pkg> && rm -rf /var/lib/apt/lists/*`.

### Real ishda qachon kerak

CI vaqtini qisqartirishda birinchi qaraladigan joy: build logida qaysi qadamdan boshlab `CACHED` yo'qolgan. Cache har mashinada alohida: Zorin'da iliq cache Mac'da yo'q, birinchi build ikkalasida to'liq ketadi.

### Nima uchun shunday

Layer oldingi layer ustiga qurilgani uchun cache zanjir bo'lib ishlaydi: o'rtadagi halqa o'zgarsa undan keyingilarning kirishi ham o'zgargan hisoblanadi. `RUN` natijasini tekshirmaslik ataylab: builder buyruq internetdan nima olishini oldindan bila olmaydi, shuning uchun faqat matnga qaraydi.

## 6. CMD va ENTRYPOINT

### Qanday qo'shiladi

| | `ENTRYPOINT` | `CMD` |
|---|--------------|-------|
| Roli | bajariladigan dastur | default argumentlar (yoki `ENTRYPOINT` yo'q bo'lsa butun buyruq) |
| `docker run IMAGE args` | saqlanadi, `args` unga qo'shiladi | `args` bilan almashtiriladi |
| Almashtirish | `--entrypoint` | `run` oxiridagi argumentlar |

Yakuniy buyruq: `ENTRYPOINT + CMD`. Misol: `ENTRYPOINT ["echo", "hello"]` va `CMD ["world"]` bilan `alpine:3.22` ustida qurilgan `lesson02/echo` image'i:

```
$ docker run --rm lesson02/echo
hello world
$ docker run --rm lesson02/echo devops
hello devops
$ docker run --rm --entrypoint ls lesson02/echo /
bin
dev
etc
...
```

Birinchisida ikkalasi qo'shildi, ikkinchisida `devops` faqat `CMD` ni almashtirdi, uchinchisida `--entrypoint` dasturni, oxiridagi `/` esa `CMD` ni almashtirdi. Stage ichida oxirgi `CMD` va oxirgi `ENTRYPOINT` amal qiladi.

### Exec form va shell form

| Shakl | Yozilishi | Nima ishga tushadi |
|-------|-----------|--------------------|
| exec | `CMD ["python", "app.py"]` | to'g'ridan-to'g'ri `python` |
| shell | `CMD python app.py` | `/bin/sh -c "python app.py"` |

Exec form JSON massiv: qo'shtirnoq faqat `"`, o'zgaruvchilar (`$PORT`) kengaytirilmaydi, chunki shell yo'q. Shell form'da PID 1 (konteynerdagi birinchi jarayon, 1-dars; signallar `linux` 9-dars) shell bo'ladi, ilova uning bolasi. `docker stop` `SIGTERM` ni faqat PID 1 ga yuboradi, `sh` uni bolaga uzatmaydi: 1-darsdagi 10 sekundlik kutish va exit 137. Ayrim shell'lar bitta oddiy buyruqda o'zini ilovaga almashtiradi, shuning uchun natija base image'ga bog'liq va unga tayanib bo'lmaydi: `docker top` bilan tekshiriladi. Xuddi shu muammo paket menejeri orqali startda (`npm start`): PID 1 `npm`, ilova uning bolasi. Qoida: `ENTRYPOINT` va `CMD` exec form'da, ilova to'g'ridan-to'g'ri chaqiriladi.

Start oldidan tayyorgarlik kerak bo'lsa (config generatsiya, migratsiya) entrypoint skripti yoziladi va oxirida `exec "$@"` bilan o'zini ilovaga almashtiradi, shunda ilova PID 1 bo'ladi.

**Tuzoq: `ENTRYPOINT` shell form'da bo'lsa `CMD` va `docker run` argumentlari e'tiborsiz qoladi.**

### Real ishda qachon kerak

Deploy paytida eski konteynerlar 10 sekunddan to'xtasa va so'rovlar uzilsa, sabab deyarli har doim shu. Kubernetes ham xuddi shunday `SIGTERM` yuboradi.

### Nima uchun shunday

Ikki instruksiya ikki xil image uchun: "dastur kabi" image (`ENTRYPOINT` qat'iy, foydalanuvchi faqat argument beradi) va "muhit kabi" image (faqat `CMD`, istalgan buyruq bilan almashtiriladi). Shell form qulaylik uchun qolgan (o'zgaruvchi, `&&`), narxi signal va PID 1.

## 7. Multi-stage build, base image, non-root

### Multi-stage

Build uchun kompilyator, dev dependency'lar va manba kod kerak, runtime uchun yo'q. Multi-stage: bitta Dockerfile'da bir necha `FROM`, yakuniy image faqat oxirgi stage'dan iborat, oldingilaridan kerakli fayllar `COPY --from` bilan olinadi. `devDependencies` va `dependencies` farqining image darajasidagi shakli: build asboblari natijaga kirmaydi.

```
FROM alpine:3.22 AS build
RUN apk add --no-cache build-base
COPY hello.c .
RUN gcc -static -o /hello hello.c

FROM scratch
COPY --from=build /hello /hello
ENTRYPOINT ["/hello"]
```

Birinchi stage'da kompilyator bor (yuzlab MB), ikkinchisida faqat bitta statik binary. Statik binary tizim kutubxonalariga (libc) bog'liq emas, shuning uchun bo'sh base'da ishlaydi; Go'da buni `CGO_ENABLED=0` beradi. `--target build` oraliq stage'ni alohida quradi. BuildKit yakuniy stage bog'liq bo'lmagan stage'larni qurmaydi.

### Base image tanlash

| Base | Ichida | Qachon |
|------|--------|--------|
| `debian`, `ubuntu` | to'liq distributiv, glibc, apt | build stage, debug |
| `*-slim` | glibc, minimal paketlar | native modul bor Node/Python ilovalari |
| `*-alpine` | musl libc, busybox, apk. Juda kichik | ko'p hollarda yaxshi default |
| distroless (`gcr.io/distroless/...`) | faqat runtime va CA sertifikatlar, shell ham paket menejeri ham yo'q | production runtime |
| `scratch` | bo'sh | statik binary (Go, Rust) |

Kichik image: tez pull, kam zaiflik, kichik hujum yuzasi. Tanlangan base ikkala arxitektura uchun borligini `imagetools inspect` bilan tekshiring (bu jadvaldagilar bor).

**Tuzoq: alpine bu musl.** glibc uchun qurilgan binary (ayrim npm native modullari, Python wheel'lari) musl'da ishlamaydi yoki manbadan kompilyatsiya qilinadi. Muammo chiqsa `-slim` ga o'ting.

**Tuzoq: distroless va scratch'da shell yo'q.** `docker exec ... sh` ham, shell form `CMD` ham ishlamaydi. `scratch` da CA sertifikatlar va timezone ma'lumotlari ham yo'q. Distroless'ning `:debug` tag'i busybox shell bilan keladi.

### Non-root user

Default foydalanuvchi root, va 1-darsda ko'rilganidek konteyner root'i host'ning UID 0 i. Ilovadagi zaiflik hujumchiga shu huquqni beradi. Runtime stage'da (alpine):

```
RUN addgroup -S app && adduser -S -G app app
COPY --chown=app:app --from=build /out/ ./
USER app
```

Rasmiy `node` image'larida tayyor `node` (UID 1000), distroless'da `:nonroot` tag'i (UID 65532) bor, `scratch` da raqam bilan (`USER 65532:65532`). `USER` dan keyingi `RUN` ham shu foydalanuvchi nomidan ishlaydi, paket o'rnatish undan oldin bo'lishi kerak.

### Real ishda qachon kerak

Har production image'da uchalasi birga. Kubernetes klasterlari ko'pincha root image'ni umuman qabul qilmaydi.

### Nima uchun shunday

Multi-stage'dan oldin ikki Dockerfile va oraliq skript yozilar edi (build image'dan faylni chiqarib, runtime image'ga solish). Bitta faylda bir necha stage shu naqshni standartlashtirdi. Root default bo'lib qolgani tarixiy (qulaylik), shuning uchun non-root har safar qo'lda yoziladi.

## 8. BuildKit va buildx: secret, ko'p platformali build

BuildKit stage'larni parallel quradi, keraksizlarini o'tkazib yuboradi, cache va secret mount'larni beradi. `buildx` uning CLI plugin'i.

### Build secret

Qiymat faqat bitta `RUN` vaqtida fayl sifatida ko'rinadi (default `/run/secrets/<id>`), layer'ga va history'ga tushmaydi:

```
RUN --mount=type=secret,id=pipconf,target=/etc/pip.conf pip install -r requirements.txt
```
```
docker build --secret id=pipconf,src=$HOME/.config/pip/pip.conf -t lesson02/py:1.0 .
```

### Ko'p platformali build

`docker buildx build --platform linux/amd64,linux/arm64 -t <nom> .` har platforma uchun alohida image qurib, ustiga image index yozadi (3-bo'lim). Ikki shart:

- **Saqlash joyi.** Lokal saqlash uchun containerd image store kerak (Laboratoriya'dagi tekshiruv). Klassik store'da (`overlay2`) natijani `--push` bilan to'g'ridan-to'g'ri registry'ga yuborish va `docker buildx create --name l02 --driver docker-container --use` bilan alohida builder yaratish kerak (oxirida `docker buildx rm l02`).
- **Begona arxitektura uchun `RUN`.** Uni bajarish emulyatsiya (QEMU) talab qiladi. Docker Desktop'da tayyor. Zorin'da hujjatdagi usul: `docker run --privileged --rm tonistiigi/binfmt --install arm64` (kernel'ga emulyator ro'yxatga olinadi, reboot'gacha amal qiladi). Bu darsda majburiy emas.

Cross-compile qila oladigan tillarda emulyatsiyasiz yo'l bor: build stage o'z platformasida ishlaydi va maqsad arxitekturaga kompilyatsiya qiladi. BuildKit avtomatik beradigan argumentlar: `BUILDPLATFORM` (build ketayotgan mashina), `TARGETPLATFORM`, `TARGETOS`, `TARGETARCH` (maqsad). `FROM --platform=$BUILDPLATFORM <image> AS build` stage'ni mahalliy arxitekturada ushlab turadi, stage ichida `ARG TARGETOS TARGETARCH` e'lon qilinib kompilyatorga uzatiladi.

### Real ishda qachon kerak

Jamoada Mac va `amd64` serverlar aralash bo'lsa (sizning ikki mashinangiz kabi) har push ko'p platformali bo'lishi kerak. Private paket registry'si tokeni build'ga faqat secret mount orqali beriladi.

### Nima uchun shunday

Eski builder har qadamni ketma-ket bajarar va secret uchun yo'l bermas edi, odamlar tokenni `ARG` bilan berib image'da qoldirar edi. BuildKit build'ni bog'liqliklar grafi sifatida ko'radi, shundan parallellik, stage'ni tashlab ketish va mount'lar kelib chiqadi. Emulyatsiya universal, lekin sekin (har instruksiya tarjima qilinadi), cross-compile tez, lekin til qo'llashi kerak.

## 9. Skanerlash va registry

### Zaiflik skaneri

Skaner image ichidagi OS paketlari va til dependency'larini ma'lum zaifliklar bazasi (CVE: ochiq ro'yxatga olingan zaiflik identifikatori) bilan solishtiradi, `npm audit` ning butun image uchun shakli. Trivy konteyner sifatida:

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:<version> image --severity HIGH,CRITICAL lesson02/py:1.0
```

`<version>` ni Trivy releases sahifasidan oling. Socket mount skanerga Engine'dagi lokal image'ni o'qish imkonini beradi (ikkala host'da shu yo'l). `--exit-code 1` topilma bo'lsa nol bo'lmagan kod qaytaradi (CI uchun), `--ignore-unfixed` tuzatishi chiqmagan CVE'larni yashiradi. Socket orqali o'qilmasa: `docker save -o app.tar IMAGE`, keyin faylni konteynerga mount qilib `trivy image --input`. Docker Scout (`docker scout cves IMAGE`) Docker'ning o'z skaneri: Desktop'da bor, Zorin'dagi Engine'da alohida plugin (ixtiyoriy).

Natija vaqt o'tishi bilan o'zgaradi: bugun toza image ertaga yangi CVE tufayli zaif. Base image muntazam yangilanib qayta build qilinadi.

### Push va credential

```
echo "$TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
docker tag lesson02/py:1.0 ghcr.io/<github-user>/py:1.0
docker push ghcr.io/<github-user>/py:1.0
docker logout ghcr.io
```

`docker tag` nusxa emas, o'sha image'ga yangi nom. Docker Hub uchun registry qismi yozilmaydi (`<user>/py:1.0`). Push faqat registry'da yo'q layer'larni yuboradi. GHCR'da yangi package default private; `LABEL org.opencontainers.image.source=https://github.com/<user>/<repo>` uni repozitoriyga bog'laydi.

Login qayerda saqlanadi: `~/.docker/config.json`. Mac'da faylda faqat `"credsStore"` nomi bor, token keychain'da. Zorin'da credential helper sozlanmagan bo'lsa `auths` ostida `user:token` base64 ko'rinishida (shifrlanmagan) yotadi. Shuning uchun: minimal huquqli, muddati cheklangan token, ishdan keyin `docker logout`, fayl hech qachon commit qilinmaydi.

Tag strategiyasi: har build o'zgarmas tag oladi (semver `1.4.2` yoki git commit SHA), deploy shu tag yoki digest bo'yicha. Mavjud tag qayta yozilmaydi.

### Real ishda qachon kerak

CI pipeline'ning oxirgi uch qadami aynan shu: build, scan, push. Rollback "oldingi tag'ni deploy qil" degani, tag qayta yozilgan bo'lsa qaytadigan nuqta yo'q.

### Nima uchun shunday

Registry image'ni build mashinasidan ajratadi: bir joyda quriladi, ko'p joyda ishlaydi, o'rtada content addressing butunlikni kafolatlaydi. Skaner build'dan alohida, chunki zaifliklar bazasi image'dan mustaqil yangilanadi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Layer | fayl tizimining oldingi holatga nisbatan farqi, tar arxiv, faqat o'qiladi |
| Config | image'ning ishga tushish sozlamalari (env, cmd, user, arxitektura) yozilgan JSON |
| Manifest | bitta platforma uchun config va layer digest'lari ro'yxati |
| Image index (manifest list) | har platforma uchun manifestga ishora qiluvchi ro'yxat |
| Digest | obyekt mazmunining SHA-256 hash'i, o'zgarmas identifikator |
| Content addressing | obyektni nomi bilan emas, mazmunining hash'i bilan manzillash |
| Tag | manifest yoki index'ga qo'yilgan o'zgaruvchan nom |
| Registry | image'larni saqlaydigan va tarqatadigan server (Docker Hub, GHCR) |
| Platforma | `os/arch` juftligi: `linux/amd64`, `linux/arm64` |
| OCI | image va runtime formatlarini standartlashtirgan tashkilot (Open Container Initiative) |
| OverlayFS | bir necha papkani ustma-ust bitta daraxt qilib ko'rsatadigan kernel fayl tizimi |
| Copy-on-write | pastki layer'dagi fayl o'zgartirilganda avval yuqori layer'ga nusxalanishi |
| Whiteout | pastki layer'dagi fayl o'chirilganini bildiruvchi belgi |
| Build context | `docker build` builder'ga yuboradigan papka |
| `.dockerignore` | context'dan chiqariladigan fayllar ro'yxati |
| BuildKit / buildx | Docker'ning build dvigateli va uning CLI plugin'i |
| Cache mount | build'lar orasida saqlanadigan, layer'ga kirmaydigan papka |
| Stage | Dockerfile'ning bitta `FROM` dan boshlanadigan qismi |
| Exec form / shell form | buyruqning JSON massiv yoki oddiy satr shaklida yozilishi |
| Distroless | shell va paket menejerisiz, faqat runtime'dan iborat base image |
| `scratch` | bo'sh base image |
| QEMU / binfmt | begona arxitektura binary'sini emulyatsiya qiluvchi dastur va uni kernel'ga ulash mexanizmi |
| Cross-compile | bir arxitekturada turib boshqasi uchun binary kompilyatsiya qilish |
| CVE | ochiq ro'yxatga olingan zaiflik identifikatori |
| Credential helper | registry parolini tizim kalit omborida saqlaydigan yordamchi dastur |
| hadolint | Dockerfile linter'i, `make check` ishlatadi |

## Tuzoqlar

- `FROM <image>:latest` yoki tag'siz base: build bugun ishlaydi, ertaga major versiya o'zgarib buziladi. Aniq versiya, production'da digest bilan.
- `COPY . .` dependency o'rnatishdan oldin: har kod o'zgarishida to'liq o'rnatish.
- `.dockerignore` yo'q: `.env`, `.git`, SSH kalitlari image'ga tushadi va registry'ga ketadi.
- Secret'ni `ARG`, `ENV` yoki `COPY` bilan berib keyin o'chirish: history va layer'lardan o'qib olinadi. Push qilingan bo'lsa secret almashtiriladi (rotate).
- Shell form `CMD` yoki paket menejeri orqali start: `SIGTERM` ilovaga yetmasligi mumkin.
- Root sifatida ishlaydigan ilova: konteynerdan chiqish zaifligi darhol host root'iga aylanadi.
- Dev dependency'lar va build asboblari runtime image'da: hajm va CVE soni bir necha barobar.
- Bitta tag'ni (`:prod`, `:latest`) qayta-qayta yozish: qaysi kod ishlayotganini bilib bo'lmaydi.
- Mac'da qurilgan bitta arxitekturali image'ni `amd64` serverga (yoki Zorin'ga) yuborish: `exec format error`. Push'dan keyin `imagetools inspect` bilan platformalarni tekshiring.
- Ikki mashinada `IMAGE ID` ni solishtirish: image store turi va arxitektura farq qiladi. Registry'dagi digest solishtiriladi.
- `docker image prune -a`, `docker system prune`: boshqa loyihalarning image'larini ham o'chiradi.
- `~/.docker/config.json` ni dotfiles repo'siga qo'shish: Zorin'da ichida token bo'lishi mumkin.
- Skanerni bir marta ishlatib unutish: CVE bazasi har kuni yangilanadi.

## Manbalar

- https://docs.docker.com/reference/dockerfile/ – Dockerfile reference (majburiy)
- https://docs.docker.com/build/building/best-practices/ – Dockerfile best practices
- https://docs.docker.com/build/cache/ – build cache va invalidatsiya qoidalari
- https://docs.docker.com/build/building/multi-stage/ – multi-stage build
- https://docs.docker.com/build/building/secrets/ – build secret'lar
- https://docs.docker.com/build/building/multi-platform/ – ko'p platformali build, QEMU, cross-compile
- https://docs.docker.com/engine/storage/drivers/overlayfs-driver/ – OverlayFS qanday ishlaydi
- https://docs.docker.com/reference/cli/docker/login/ – `docker login` va credential store
- https://github.com/opencontainers/image-spec – OCI image spetsifikatsiyasi (manifest, index, layer)
- https://github.com/hadolint/hadolint – hadolint, qoidalar ro'yxati va releases
- https://github.com/GoogleContainerTools/distroless – distroless image'lar va tag'lari
- https://trivy.dev/ – Trivy hujjatlari; https://github.com/aquasecurity/trivy/releases – versiyalar
- https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry – GHCR bilan ishlash
- https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md – Node.js image best practices

## Birga bajaramiz

Bitta kichik C dasturini image'ga aylantiramiz va yo'lda layer, cache, context, multi-stage, `ENTRYPOINT`/`CMD`, non-root va arxitekturani ko'ramiz. C tanlangani sababi: kompilyator og'ir, natija bitta kichik fayl, farq yaqqol ko'rinadi. Hammasi host'da, repo'dan tashqaridagi `~/l02-walk` papkasida (shunda `make check` unga tegmaydi).

1. Papka va dastur. `hello.c` argumentni va kernel aytgan arxitekturani chiqaradi:

```
$ mkdir ~/l02-walk && cd ~/l02-walk
$ cat hello.c
#include <stdio.h>
#include <sys/utsname.h>
int main(int argc, char **argv) {
    struct utsname u;
    uname(&u);
    printf("hello %s from %s\n", argc > 1 ? argv[1] : "world", u.machine);
    return 0;
}
```

2. Birinchi, sodda Dockerfile (bitta stage) va build:

```
$ cat Dockerfile
FROM alpine:3.22
RUN apk add --no-cache build-base
COPY hello.c .
RUN gcc -static -o /hello hello.c
ENTRYPOINT ["/hello"]
CMD ["world"]
$ docker build -t lesson02/hello:fat .
$ docker run --rm lesson02/hello:fat
hello world from aarch64
$ docker image ls lesson02/hello
REPOSITORY       TAG   IMAGE ID   CREATED    SIZE
lesson02/hello   fat   <id>       <vaqt>     <yuzlab MB>
```

Zorin'da oxirgi so'z `x86_64`. Dastur bir necha o'n kilobayt, image esa yuzlab megabayt.

3. Hajm qayerdan kelganini `history` aytadi:

```
$ docker history --format '{{.Size}}\t{{.CreatedBy}}' lesson02/hello:fat
0B        CMD ["world"]
0B        ENTRYPOINT ["/hello"]
<kB>      RUN /bin/sh -c gcc -static -o /hello hello.c # buildkit
<bayt>    COPY hello.c . # buildkit
<~MB>     RUN /bin/sh -c apk add --no-cache build-base # buildkit
<MB>      ADD alpine-minirootfs-<ver>-<arch>.tar.gz / # buildkit
```

Deyarli butun hajm `apk add` layer'ida: kompilyator runtime'da kerak emas, lekin image'da turibdi. `CMD` va `ENTRYPOINT` `0B` (faqat config).

4. Cache. `hello.c` dagi `hello` so'zini `salom` ga o'zgartirib qayta build qiling:

```
$ docker build -t lesson02/hello:fat .
 => CACHED [2/4] RUN apk add --no-cache build-base
 => [3/4] COPY hello.c .
 => [4/4] RUN gcc -static -o /hello hello.c
```

`apk add` kirishi o'zgarmadi (matn va base bir xil), cache'dan keldi. `COPY` kirishi (fayl mazmuni) o'zgardi, u va undan keyingi `RUN` qayta bajarildi. Agar `COPY` `apk add` dan oldin turganida kompilyator ham har safar qayta o'rnatilar edi.

5. Context. Papkaga keraksiz katta fayl qo'shamiz va Dockerfile'dagi `COPY hello.c .` ni vaqtincha `COPY . .` ga almashtiramiz (ko'p loyihalarda aynan shunday yoziladi):

```
$ dd if=/dev/zero of=junk.bin bs=1M count=100
$ docker build --progress=plain -t lesson02/hello:fat . 2>&1 | grep 'transferring context'
#<n> transferring context: <~100MB> done
$ echo 'junk.bin' > .dockerignore
$ docker build --progress=plain -t lesson02/hello:fat . 2>&1 | grep 'transferring context'
#<n> transferring context: <bir necha yuz bayt> done
```

Birinchi build'da `junk.bin` builder'ga yuborildi va `COPY . .` uni image layer'iga ham soldi (`docker history` da `COPY` qatori 100 MB ga o'sadi). `.dockerignore` dan keyin fayl context'da yo'q: yuborilmaydi ham, image'ga tushmaydi ham. Eslatma: BuildKit context'ni to'liq emas, `COPY` so'ragan qismini yuboradi, shuning uchun `COPY hello.c .` bilan `junk.bin` umuman yuborilmas edi. Aniq fayl nomlari bilan `COPY` va `.dockerignore` bir-birini to'ldiradi. Tajribadan keyin `COPY hello.c .` ni qaytaring va `rm junk.bin`.

6. Multi-stage. Dockerfile'ni 7-bo'limdagi ikki stage'li shaklga keltiring (`AS build`, `FROM scratch`, `COPY --from=build`), oxiriga `USER 65532:65532`, `ENTRYPOINT ["/hello"]`, `CMD ["world"]` qo'shing:

```
$ docker build -t lesson02/hello:1.0 .
$ docker image ls lesson02/hello
REPOSITORY       TAG   IMAGE ID   CREATED   SIZE
lesson02/hello   1.0   <id>       <vaqt>    <o'nlab kB>
lesson02/hello   fat   <id>       <vaqt>    <yuzlab MB>
$ docker image inspect -f '{{.Os}}/{{.Architecture}} user={{.Config.User}} layers={{len .RootFS.Layers}}' lesson02/hello:1.0
linux/arm64 user=65532:65532 layers=1
```

Yakuniy image bitta layer: faqat binary. Kompilyator `build` stage'ida qoldi va yakuniy image'ga kirmadi. `user` bo'sh emas, demak root emas. Platforma siz qurgan mashinaniki.

7. `ENTRYPOINT` va `CMD`:

```
$ docker run --rm lesson02/hello:1.0
hello world from aarch64
$ docker run --rm lesson02/hello:1.0 devops
hello devops from aarch64
$ docker run --rm lesson02/hello:1.0 sh
hello sh from aarch64
```

Uchinchi qator muhim: `sh` shell sifatida ishga tushmadi, u `/hello` ga argument bo'lib ketdi (va `scratch` da shell baribir yo'q). `ENTRYPOINT` qat'iy, `run` oxiridagi so'zlar faqat `CMD` ni almashtiradi.

8. Tozalash: `docker image rm lesson02/hello:fat lesson02/hello:1.0`, keyin `rm -r ~/l02-walk`.

Ko'rganingiz: layer va config farqi `history` da (1-bo'lim), context va `.dockerignore` (4-bo'lim), cache zanjiri (5-bo'lim), `ENTRYPOINT + CMD` (6-bo'lim), multi-stage, `scratch` va non-root (7-bo'lim), image arxitekturasi mashinaga bog'liqligi (3-bo'lim).

---

## Vazifalar

Barchasini host'da `docker/02-images/` da bajaring (`make new m=docker n=02 name=images`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Ilovalar `node-app/` va `go-app/` ichki papkalarida, har birida o'z `Dockerfile` va `.dockerignore` bilan. Hajm, vaqt va digest'larni yozganda qaysi mashinada o'lchanganini (`amd64` yoki `arm64`) ko'rsating: ikkinchi mashinada image'lar qaytadan quriladi va raqamlar farq qiladi.

Ilovalar (o'zingiz yozasiz, har biri 30–50 qator): TypeScript'dagi HTTP server (kamida bitta runtime dependency va `tsc` build bilan) va Go'dagi HTTP server (faqat standart kutubxona). Ikkalasi: `GET /` matn qaytaradi, `GET /healthz` `200`, port `PORT` env'dan, `SIGTERM` da "shutting down" deb log yozib toza to'xtaydi.

`make check` hadolint'ni `Dockerfile.*` nomli fayllarda ham ishlatadi. Ataylab yomon yozilgan fayllarda (naive, vaqtinchalik variantlar) ogohlantirishlarni README'ga yozing, keyin tegishli instruksiya ustiga `# hadolint ignore=<DL-kodlar>` kommentini qo'ying. Yakuniy ikki Dockerfile'da bunday komment bo'lmasin.

### A. Image anatomiyasi

1. **Layers and history.** `nginx:1.28-alpine` uchun `docker history` va `docker image inspect -f '{{json .RootFS.Layers}}'` ni ko'ring. Nechta layer bor, qaysi instruksiyalar layer yaratgan, qaysilari hajmi 0? `alpine:3.22` layer'i nginx image'ining layer'lari orasida bormi va bu disk sarfi uchun nimani anglatadi? Yo'nalish: 1-bo'lim, "Misol: layer'lar va ularni yaratgan instruksiyalar".

2. **Overlay mounts.** `alpine:3.22` konteynerida `head -1 /proc/mounts` ni chiqaring, `lowerdir`, `upperdir` qismlarini ajrating. Ikkita konteynerni bitta image'dan ishga tushirib solishtiring: nimasi bir xil, nimasi farq qiladi? Konteynerda `/etc/hostname` dan boshqa biror faylni o'zgartirib `docker diff` bilan copy-on-write natijasini ko'rsating. Host'da bajarsa bo'ladi; ixtiyoriy: `lab` VM'da takrorlab `upperdir` ichini `sudo ls` bilan ko'ring. Yo'nalish: 2-bo'lim, "Misol: konteyner ichidan va tashqaridan".

3. **Tag vs digest.** `docker buildx imagetools inspect node:24-alpine` natijasidan image index digest'i va `linux/amd64` manifest digest'ini toping (Mac'da qo'shimcha `linux/arm64` nikini ham). `docker pull node:24-alpine@sha256:<digest>` bilan torting va `docker image inspect` da qaysi arxitektura kelganini ko'ring. Tag va digest bo'yicha pull farqi, qaysi biri production `FROM` uchun to'g'ri ekanini izohlang. Yo'nalish: 3-bo'lim, "Platforma va image index".

4. **Deleted file stays.** Dockerfile yozing: `alpine:3.22` ustida bitta `RUN` da `dd` bilan 50 MB fayl yarating, keyingi `RUN` da o'chiring. Image hajmi va `docker history` ni ko'rsating. Keyin ikkalasini bitta `RUN` ga birlashtirib qayta o'lchang va farqni izohlang. Yo'nalish: 2-bo'lim, "Tuzoq: keyingi layer'da o'chirish hajmni kamaytirmaydi".

### B. Node.js ilovasi

5. **Naive Dockerfile.** `node-app/Dockerfile.naive` yozing: `node:24` base, `COPY . .`, `npm install`, `npm run build`, shell form `CMD npm start`. Build qilib (`lesson02/node-app:naive`) hajmini, build vaqtini va `docker run` da kim nomidan ishlayotganini (`docker exec <c> id`) yozing. Bu fayldagi kamida 5 ta muammoni sanang. Yo'nalish: 4–7 bo'limlar va "Tuzoqlar".

6. **Cache ordering.** Naive variantda manba koddagi bitta qatorni o'zgartirib qayta build qiling, qaysi qadamlar `CACHED` bo'lganini yozing. Keyin dependency manifestlarini alohida nusxalaydigan tartibga o'tkazing va tajribani takrorlang. Ikki holatdagi vaqtni jadvalga yozing va invalidatsiya zanjirini izohlang. Yo'nalish: 5-bo'lim, "Mexanizm".

7. **dockerignore.** `.dockerignore` siz `--progress=plain` bilan build qilib `transferring context` hajmini yozing. Papkaga soxta `.env` (ichida `SECRET=test`) qo'ying, `COPY . .` dan keyin image ichida u borligini ko'rsating. `.dockerignore` yozib ikkala o'lchovni takrorlang. Soxta `.env` commit qilinmaydi. Yo'nalish: 4-bo'lim, "Build context va .dockerignore".

8. **Multi-stage Node.** Yakuniy `node-app/Dockerfile`: build stage (`npm ci`, `tsc`), runtime stage (`node:24-alpine` yoki distroless, faqat production dependency'lar va kompilyatsiya natijasi), `npm` cache mount, non-root user, exec form. `lesson02/node-app:1.0` hajmini naive bilan solishtiring. `docker run --rm lesson02/node-app:1.0 ls node_modules/.bin` orqali dev dependency'lar yo'qligini ko'rsating (distroless bo'lsa boshqa usul toping). Yo'nalish: 7-bo'lim, "Multi-stage" va "Non-root user"; 5-bo'lim, "Cache mount".

9. **Signals and exec form.** `lesson02/node-app:1.0` va `:naive` ni ishga tushirib `time docker stop` qiling. Vaqt, exit code va "shutting down" logi chiqqan-chiqmaganini solishtiring. Har ikki holatda `docker top` bilan PID 1 kim ekanini ko'rsating. Yo'nalish: 6-bo'lim, "Exec form va shell form".

10. **Non-root check.** Yakuniy image'da `id`, `/` ga fayl yozish urinishi va ilova papkasiga yozish urinishini tekshiring. Konteynerni `--read-only` bilan ishga tushiring: ilova ishlaydimi? Ishlamasa xatoni o'qing va `--tmpfs` bilan tuzating. Yo'nalish: 7-bo'lim, "Non-root user".

### C. Go ilovasi

11. **Multi-stage Go.** `go-app/Dockerfile`: `golang:1.26-alpine` build stage (`go mod download` alohida layer, cache mount'lar), `CGO_ENABLED=0`, runtime sifatida distroless static nonroot. Hajmni yozing. Build stage'ni `--target` bilan alohida qurib uning hajmi bilan solishtiring. Yo'nalish: 7-bo'lim, "Multi-stage"; 5-bo'lim, "Cache mount".

12. **scratch vs distroless.** Xuddi shu binary'ni `FROM scratch` bilan ham quring. Ilovaga `GET /out` handler qo'shing: u `https://example.com` ga so'rov yuborib status kodini qaytarsin. Ikkala image'da sinang, scratch'dagi xatoni yozing va sababini toping. `scratch` da qaysi foydalanuvchi nomidan ishlayapti? Yo'nalish: 7-bo'lim, "Base image tanlash" va uning tuzoqlari.

13. **Build args and labels.** `ARG VERSION` ni `-ldflags "-X main.version=$VERSION"` orqali binary'ga kiriting, `GET /` uni qaytarsin. `org.opencontainers.image.source`, `.version`, `.revision` label'larini qo'shing. `docker build --build-arg VERSION=1.2.3` qilib `docker image inspect -f '{{json .Config.Labels}}'` va `curl` bilan tekshiring. `docker history` da `VERSION` qiymati ko'rinadimi? Yo'nalish: 4-bo'lim, "Dockerfile nima" (`ARG` va `ENV` farqi).

14. **CMD and ENTRYPOINT.** Go ilovasiga `--port` flag'i qo'shing. `ENTRYPOINT ["/app"]` va `CMD ["--port", "8080"]` bilan quring. Tekshiring va izohlang: `docker run IMAGE`, `docker run IMAGE --port 9090`, `docker run --entrypoint /app IMAGE --help`. Keyin `ENTRYPOINT` ni shell form'ga o'zgartirib (alpine base'li vaqtinchalik variantda) `docker run IMAGE --port 9090` nima qilishini ko'rsating. Yo'nalish: 6-bo'lim, "Qanday qo'shiladi".

15. **Multi-platform build.** `--platform=$BUILDPLATFORM`, `TARGETOS`, `TARGETARCH` yordamida `linux/amd64,linux/arm64` uchun bitta buyruq bilan quring. Build logida `RUN` qaysi platformada bajarilganini ko'rsating. Nima uchun bu yerda QEMU kerak bo'lmadi va Node ilovasida (native modul bo'lsa) nima uchun kerak bo'lar edi? Mashinangizdagi image store natijani lokal saqlay oladimi, tekshirib yozing; saqlay olmasa 8-bo'limdagi ikkinchi yo'ldan foydalaning. Yo'nalish: 8-bo'lim, "Ko'p platformali build".

### D. Xavfsizlik va registry

16. **Leaked secret.** Vaqtinchalik Dockerfile'da soxta token'ni uch usulda bering: `ARG`, `ENV`, va `COPY` qilib keyingi `RUN` da o'chirish. Har birini `docker history --no-trunc`, `docker image inspect` yoki `docker save` qilib tar ichidan qidirib toping. Keyin `RUN --mount=type=secret` bilan qayta yozib, tokenni hech biridan topib bo'lmasligini ko'rsating. Yo'nalish: 8-bo'lim, "Build secret"; 2-bo'limdagi tuzoq.

17. **Dockerfile lint.** Uchala Dockerfile uchun (naive ham) `docker build --check` ni ishlating. Ogohlantirishlarni yozing va yakuniy ikki faylda hammasini tuzating. Qo'shimcha: `hadolint` nima topganini solishtiring. Yo'nalish: 5-bo'lim, "Qo'shimcha vositalar"; Laboratoriya, "hadolint".

18. **Vulnerability scan.** Trivy'ni konteyner sifatida ishlatib `lesson02/node-app:naive`, `lesson02/node-app:1.0` va `lesson02/go-app` ni `HIGH,CRITICAL` bo'yicha skanerlang. Natijani jadvalga yozing (image, base, hajm, HIGH, CRITICAL). Topilmalar OS paketlaridami yoki til dependency'laridami? Bittasini tuzatish yo'lini (base yangilash, paket versiyasi) toping va qo'llang. Yo'nalish: 9-bo'lim, "Zaiflik skaneri".

19. **Push to registry.** GHCR yoki Docker Hub'ga `--password-stdin` bilan login qiling, ikkala yakuniy image'ni semver tag va git SHA tag bilan push qiling. Ikkinchi push'da qaysi layer'lar `Layer already exists` bo'lganini yozing. `docker buildx imagetools inspect` bilan registry'dagi digest va platformalarni ko'rsating. Lokal image'ni o'chirib digest bo'yicha pull qilib ishga tushiring. `~/.docker/config.json` da nima saqlanganini (qiymatni README'ga yozmasdan) tasvirlang va bu shu mashinada (Zorin yoki macOS) nima uchun shunday ekanini yozing, keyin `docker logout`. Yo'nalish: 9-bo'lim, "Push va credential".

### E. Yakuniy

20. **Image checklist.** O'z image'laringiz uchun 10–12 banddan iborat tekshiruv ro'yxatini `CHECKLIST.md` ga yozing (pinned base, layer tartibi, `.dockerignore`, non-root, exec form, secret yo'q, skaner, label, tag strategiyasi va hokazo) va ikkala yakuniy image'ni shu ro'yxat bo'yicha baholang: har bandda qaysi buyruq bilan tekshirganingiz ko'rsatilsin. Yo'nalish: butun dars, "Tuzoqlar".

21. **Cleanup.** `lesson02/*` image'larini, test konteynerlarini va build cache'ni tozalang (`docker buildx du` oldin va keyin). Registry'dagi test image'larni o'chiring yoki private ekanini tekshiring. `docker image prune` va `docker image prune -a` farqini izohlang va nima uchun bu mashinada `-a` ni ehtiyotsiz ishlatmaslik kerakligini yozing. `lab` VM'da ishlagan bo'lsangiz u yerdagi `alpine` image va `l02-` konteynerlarini ham o'chiring. Yo'nalish: Laboratoriya, "Nomlash va tozalash".

### Topshirish

Tayyor bo'lgach:
1. `docker/02-images/README.md` da 21 ta vazifaning har biri `## N. Title` sarlavhasi ostida; papkada `node-app/` (`Dockerfile`, `Dockerfile.naive`, `.dockerignore`, manba kod), `go-app/` (`Dockerfile`, `.dockerignore`, manba kod) va `CHECKLIST.md`.
2. `make check` toza (host'da, hadolint o'rnatilgan holda).
3. `docker build --check` ikkala yakuniy Dockerfile uchun ogohlantirishsiz.
4. Papkada token, `.env`, `app.tar` kabi fayllar yo'q (`git status` bilan tekshiring).
5. Lokal `lesson02/*` image'lar va test konteynerlar o'chirilgan, `docker logout` qilingan (login qilgan har mashinada), qo'shimcha builder yaratgan bo'lsangiz `docker buildx rm` qilingan.
6. Menga xabar bering, Dockerfile'lar va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Layer, config va manifest nima? Nima uchun ikki image bitta layer'ni bo'lisha oladi?
- Keyingi `RUN` da o'chirilgan fayl nima uchun image hajmini kamaytirmaydi? Whiteout nima?
- Tag va digest farqi nima? `latest` nimani kafolatlaydi?
- Bir xil `alpine:3.22` nomi Zorin'da va Mac'da nima uchun boshqa baytlarni beradi? Image index nima qiladi?
- Mac'da qurilgan image `amd64` serverda nima uchun ishlamaydi va ikki yechimi (emulyatsiya, cross-compile) qanday farq qiladi?
- Dependency manifestini `COPY . .` dan oldin nusxalash nima beradi? Cache qachon invalidatsiya bo'ladi?
- `CMD` va `ENTRYPOINT` birga qanday ishlaydi? `docker run IMAGE arg` har biriga qanday ta'sir qiladi?
- Shell form `CMD` da `docker stop` nima uchun 10 sekund kutishi mumkin?
- Multi-stage build qaysi ikki muammoni yechadi?
- alpine, slim, distroless, scratch: har birini qachon tanlaysiz va har birining narxi nima?
- `ARG` orqali berilgan token nima uchun xavfsiz emas va to'g'ri usul qanday?
- `docker login` tokeni Zorin'da va Mac'da qayerda saqlanadi?
- Bugun skanerdan toza o'tgan image bir oydan keyin nima uchun zaif bo'lishi mumkin?
