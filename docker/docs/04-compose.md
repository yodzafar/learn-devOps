# 4-dars: Docker Compose

Maqsad: bir necha konteynerli muhitni bitta deklarativ faylda tavsiflash va bitta buyruq bilan ko'tarish. 3-dars oxirida ikki konteynerni `up.sh` skripti bilan qo'lda yig'dingiz: tarmoq, volume, healthcheck, limit, tartib. Compose shu ishni `compose.yaml` ga ko'chiradi va holatni fayl bilan solishtirib faqat o'zgarganini qayta yaratadi. Bu darsda to'liq stack quriladi: ilova, Postgres, Redis va nginx reverse proxy. 5-darsda shu faylning o'zi Swarm stack sifatida deploy qilinadi, Kubernetes manifestlaridagi ko'p tushuncha ham shu yerdan tanish bo'ladi.

Taxminiy vaqt: 3 kun (siz uchun). `docker compose up` ni ishlatgansiz, diqqatni quyidagilarga qarating: project nomi va resurs nomlari qayerdan kelishi, `depends_on` ning shartlari, `.env` (interpolation) bilan `env_file` (konteyner env) farqi, override fayllarning birlashish qoidalari, `down` va `down -v` farqi, `up` qachon konteynerni qayta yaratishi, reverse proxy ortida DNS va IP o'zgarishi.

## Laboratoriya

Ish mashinasidagi Docker Engine va Compose CLI plugin'i:

```
docker compose version
```

Sizda Compose v5.5. `docker compose` (bo'sh joy bilan) Go'da yozilgan CLI plugin, odatda "Compose v2" deb ataladi; v2 dan keyingi major reliz v5 deb raqamlangan. Eski Python'dagi `docker-compose` (defis bilan, v1) qo'llab-quvvatlanmaydi, uni o'rnatmang.

Har vazifa guruhi `docker/04-compose/` ichidagi o'z papkasida yoki bitta `stack/` papkasida bajariladi. Fayl boshida `name: l4-stack` kabi project nomi bering: barcha resurslar shu prefiks bilan yaratiladi va boshqa loyihalarga tegmaydi. Hostda 6379 va 5432 portlar boshqa loyihalar bilan band bo'lishi mumkin, bu darsda baza va Redis portlari publish qilinmaydi.

Tozalash:

```
docker compose down -v --remove-orphans     # containers, networks, named volumes of THIS project
docker compose down --rmi local             # also images built by this project
docker compose ls -a                        # no l4-* projects left
```

`.env` va secret fayllari commit qilinmaydi; o'rniga qiymatsiz `.env.example` commit qilinadi.

---

## 1. Compose modeli

Compose uch narsadan iborat: **fayl** (`compose.yaml`), **project** (shu fayldan yaratilgan resurslar to'plami) va **buyruqlar** (`docker compose ...`).

- Fayl nomi: `compose.yaml` (afzal), `compose.yml`, eski `docker-compose.yaml`/`.yml` ham o'qiladi.
- Fayl boshidagi `version: "3.8"` eskirgan, e'tiborsiz qoldiriladi (ogohlantirish bilan). Yozmang.
- Project nomi: `name:` kaliti, yoki `-p`, yoki `COMPOSE_PROJECT_NAME`, aks holda papka nomi.

| Resurs | Nomi |
|--------|------|
| konteyner | `<project>-<service>-<n>` (`l4-stack-app-1`) |
| tarmoq | `<project>_default` |
| volume | `<project>_<volume>` |

**Tuzoq: bir xil nomli ikki papka bitta project.** `~/a/app` va `~/b/app` dan `up` qilinsa ikkalasi `app` project'i bo'lib, bir-birining konteynerlarini "orphan" deb ko'radi yoki qayta yaratadi. `name:` ni aniq yozing.

### Fayl tuzilishi

```
name: demo
services:
  web:
    image: nginx:1.28-alpine
    ports:
      - "127.0.0.1:8080:80"
    networks: [front]
    volumes:
      - ./conf.d:/etc/nginx/conf.d:ro
networks:
  front:
volumes:
  data:
```

Yuqori darajadagi kalitlar: `name`, `services`, `networks`, `volumes`, `secrets`, `configs`, `include` (boshqa compose faylni qo'shish).

Tarmoq e'lon qilinmasa barcha servislar `<project>_default` user-defined bridge'iga ulanadi va bir-birini **servis nomi** bilan topadi (3-darsdagi embedded DNS). Shuning uchun ilovada baza manzili `db:5432`.

### Servis kalitlari

| Kalit | `docker run` dagi mos keladigani |
|-------|----------------------------------|
| `image`, `build` | image nomi yoki Dockerfile'dan qurish |
| `command`, `entrypoint` | `CMD` va `ENTRYPOINT` ni almashtirish |
| `environment`, `env_file` | `-e`, `--env-file` |
| `ports` | `-p`. `expose` faqat hujjat |
| `volumes` | `-v` / `--mount` (named volume yuqori `volumes:` da e'lon qilinadi) |
| `networks` | `--network`, `aliases` bilan |
| `restart` | `--restart` |
| `healthcheck` | `--health-*` (`test`, `interval`, `timeout`, `retries`, `start_period`) |
| `deploy.resources.limits` | `--cpus`, `--memory` |
| `user`, `read_only`, `tmpfs`, `init`, `cap_drop` | xavfsizlik flag'lari |
| `stop_grace_period` | `--stop-timeout` |
| `depends_on`, `profiles`, `secrets`, `develop` | faqat Compose'da (quyida) |

**Tuzoq: YAML tiplari.** Portlarni har doim qo'shtirnoqda yozing (`"8080:80"`): qo'shtirnoqsiz `xx:yy` ko'rinishidagi qiymat YAML'da son deb o'qilishi mumkin. `environment` dagi `true`, `yes`, `no` kabi qiymatlar ham qo'shtirnoqda bo'lsin. Compose qiymatlarida `$` interpolation belgisi, shell o'zgaruvchisi kerak bo'lsa `$$` yoziladi.

## 2. Ishga tushish tartibi: depends_on va healthcheck

`depends_on` ning qisqa shakli (`depends_on: [db]`) faqat **konteyner start bo'lishini** kutadi, baza ulanish qabul qilishga tayyorligini emas. Uzun shakl shartni belgilaydi:

```
services:
  app:
    depends_on:
      db:
        condition: service_healthy
        restart: true
      migrate:
        condition: service_completed_successfully
  db:
    image: postgres:17-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
```

| `condition` | Kutadi |
|-------------|--------|
| `service_started` | konteyner start bo'lgan (default) |
| `service_healthy` | healthcheck `healthy` bo'lgan. Servisda healthcheck bo'lishi shart |
| `service_completed_successfully` | konteyner exit 0 bilan tugagan (migratsiya, seed kabi bir martalik ishlar) |

`restart: true`: bog'liqlik qayta ishga tushirilsa shu servis ham qayta ishga tushadi. `required: false`: bog'liqlik yo'q bo'lsa (masalan profile yoqilmagan) faqat ogohlantiradi.

`test` shakllari: `["CMD", "prog", "arg"]` (exec), `["CMD-SHELL", "..."]` (shell orqali), `["NONE"]` (image'dagi healthcheck'ni o'chirish).

**Tuzoq: `depends_on` faqat start paytida ishlaydi.** Baza ish vaqtida qayta ishga tushsa ilova buni o'zi ko'tarishi kerak: ulanishni qayta urinish (retry) ilova kodining vazifasi. `depends_on` qulaylik, chidamlilik emas.

## 3. Konfiguratsiya: env, interpolation, secrets

Ikki alohida mexanizm bor va ular tez-tez chalkashtiriladi:

| | Interpolation | Konteyner environment'i |
|---|---------------|-------------------------|
| Nima | compose **faylining o'zida** `${VAR}` ni almashtirish | konteyner ichidagi env o'zgaruvchilar |
| Manba | shell env, keyin project papkasidagi `.env` | `environment:` va `env_file:` |
| Qachon | fayl o'qilganda, hostda | konteyner yaratilganda |

`.env` dagi qiymat konteynerga avtomatik tushmaydi: faqat faylda `${VAR}` sifatida ishlatilsa yoki `env_file: .env` yozilsa.

Interpolation sintaksisi:

| Yozuv | Ma'nosi |
|-------|---------|
| `${TAG}` | qiymat, yo'q bo'lsa bo'sh satr va ogohlantirish |
| `${TAG:-1.0}` | yo'q yoki bo'sh bo'lsa default |
| `${TAG:?message}` | yo'q yoki bo'sh bo'lsa xato bilan to'xtaydi |

Ustuvorlik: interpolation'da shell env `.env` dan ustun. Konteynerda `environment:` qiymati `env_file:` dagidan, u esa image'dagi `ENV` dan ustun. Boshqa fayl: `docker compose --env-file prod.env up`.

Eng foydali diagnostika buyrug'i: `docker compose config`. U barcha fayllarni birlashtirib, o'zgaruvchilarni almashtirib, yakuniy YAML'ni chiqaradi (`--services`, `--volumes`, `--images` ham bor). "Nima uchun bu qiymat ketdi" savoliga javob shu yerda.

### Secrets

`environment` dagi parol `docker inspect` va `docker compose config` da ochiq ko'rinadi. Compose'da secret fayl sifatida beriladi va konteynerda `/run/secrets/<name>` ga ulanadi:

```
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
secrets:
  db_password:
    file: ./secrets/db_password.txt
```

Rasmiy image'larning ko'pi `*_FILE` o'zgaruvchilarini tushunadi. O'z ilovangizda faylni o'qishni o'zingiz yozasiz. Yolg'iz Compose'da bu shunchaki bind mount (shifrlanmaydi), lekin parol env'dan chiqadi va xuddi shu fayl 5-darsda Swarm secret'lari bilan o'zgarishsiz ishlaydi.

## 4. Profiles va override

### Profiles

`profiles` berilgan servis faqat shu profile yoqilganda ishga tushadi. Profile'siz servislar har doim.

```
services:
  adminer:
    image: adminer:5
    profiles: [debug]
```
```
docker compose --profile debug up -d      # or COMPOSE_PROFILES=debug
```

Ishlatilishi: debug asboblari, bir martalik seed, ixtiyoriy monitoring.

### Bir necha fayl

`-f` berilmasa Compose `compose.yaml` ni va, agar bo'lsa, `compose.override.yaml` ni avtomatik birlashtiradi. Odatiy sxema: `compose.yaml` umumiy asos, `compose.override.yaml` lokal dev (bind mount, debug port), `compose.prod.yaml` production sozlamalari:

```
docker compose up -d                                         # base + override
docker compose -f compose.yaml -f compose.prod.yaml up -d    # base + prod, override ignored
```

Birlashish qoidalari (keyingi fayl oldingisining ustiga):

| Tip | Qoida | Misol |
|-----|-------|-------|
| skalyar | almashtiriladi | `image`, `restart` |
| mapping | kalit bo'yicha birlashadi | `environment`, `labels` |
| ro'yxat | qo'shiladi | `ports`, `expose`, `dns` |
| `command`, `entrypoint`, `healthcheck.test` | to'liq almashtiriladi | |

**Tuzoq: `ports` qo'shiladi, almashtirilmaydi.** Asosda `"8080:80"`, override'da `"9090:80"` bo'lsa ikkala port ham ochiladi. To'liq almashtirish uchun override'da `!override` YAML tegi ishlatiladi (`ports: !override [...]`). Natijani har doim `docker compose config` bilan tekshiring.

## 5. Build va buyruqlar

```
services:
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
      target: runtime
      args:
        VERSION: ${VERSION:-dev}
    image: ghcr.io/<user>/l4-app:${VERSION:-dev}
```

`build` va `image` birga bo'lsa qurilgan image shu nom bilan teglanadi. `docker compose build`, `docker compose up -d --build`, `docker compose push`.

**Tuzoq: `up` image'ni o'zi qayta qurmaydi.** Image mavjud bo'lsa kod o'zgargani bilan `docker compose up -d` eski image'ni ishlatadi. `--build` yozing.

| Buyruq | Vazifa |
|--------|--------|
| `up -d` | yaratadi yoki holatni faylga keltiradi. `--wait` barcha servislar `healthy` bo'lguncha kutadi |
| `ps`, `ps -a` | project konteynerlari, holat va health |
| `logs -f --tail 50 [svc]` | loglar, servis nomi prefiksi bilan |
| `exec svc cmd` | ishlayotgan konteynerda buyruq. Pipe bilan ishlatganda `-T` |
| `run --rm svc cmd` | bir martalik yangi konteyner (`ports` publish qilinmaydi, `depends_on` ko'tariladi) |
| `stop`, `start`, `restart` | konteynerlarni o'chirmasdan |
| `down` | konteyner va tarmoqlarni o'chiradi. Volume'lar qoladi |
| `down -v` | named va anonim volume'larni ham o'chiradi |
| `config`, `top`, `images`, `ls` | diagnostika |
| `up -d --scale app=3` | servisni bir necha nusxada |

`up` idempotent: fayl va holat mos bo'lsa hech narsa qilmaydi, servis konfiguratsiyasi yoki image o'zgargan bo'lsa faqat o'sha konteynerni **qayta yaratadi** (yangi konteyner, yangi IP, yoziladigan layer yo'qoladi). `restart` esa konfiguratsiyani qayta o'qimaydi: `.env` yoki compose fayl o'zgarishi uchun `up -d` kerak.

**Tuzoq: `down -v` bazani o'chiradi.** `down` va `down -v` orasidagi farq bitta flag, natijasi qaytarilmaydi. Production'da `-v` ni odat qilmang.

### compose watch

Dev sikli uchun: fayl o'zgarishini kuzatib konteynerni yangilaydi (bind mount'ga muqobil, `build` li servislar uchun).

```
services:
  app:
    build: ./app
    develop:
      watch:
        - action: sync
          path: ./app/src
          target: /app/src
        - action: rebuild
          path: ./app/package.json
```

| `action` | Nima qiladi |
|----------|-------------|
| `sync` | faylni ishlayotgan konteynerga nusxalaydi (ilovaning o'zida hot reload bo'lishi kerak) |
| `sync+restart` | nusxalaydi va konteynerni restart qiladi (config fayllar uchun) |
| `rebuild` | image'ni qayta quradi va konteynerni almashtiradi (dependency o'zgarganda) |

Ishga tushirish: `docker compose watch` yoki `docker compose up --watch`.

## 6. Reverse proxy bilan stack

Maqsadli arxitektura:

```
host:8080 -> nginx (front, back) -> app (back) -> postgres (back), redis (back)
```

- Faqat nginx port publish qiladi. `app`, `db`, `redis` tashqaridan ko'rinmaydi.
- nginx `app` ni servis nomi bilan topadi:

```
upstream app_upstream { server app:3000; }
server {
  listen 80;
  location / {
    proxy_pass http://app_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

- Ma'lumot: Postgres named volume'da; Redis kesh bo'lsa volume shart emas.
- `--scale app=3` ishlashi uchun `app` da `container_name` va host port bo'lmasligi kerak: bitta host portga uch konteyner ulana olmaydi. Servis nomi DNS'da barcha nusxalarning IP'lariga yechiladi.

**Tuzoq: nginx nomni faqat start (yoki reload) paytida yechadi.** `app` qayta yaratilsa yoki scale qilinsa IP'lar o'zgaradi, nginx eski IP'ga yuborishda davom etadi: `502 Bad Gateway` yoki yangi nusxalar trafik olmaydi. Yechim: `docker compose exec nginx nginx -s reload`, yoki `depends_on` da `restart: true`. Dinamik muhitda buni o'zi kuzatadigan proxy (Traefik, Caddy) yoki orkestratorning service discovery'si ishlatiladi (5-dars).

## Tuzoqlar

- `down -v` bilan baza volume'ini o'chirish.
- `depends_on: [db]` ni "baza tayyor" deb o'ylash. Shartsiz shakl faqat startni kutadi.
- `.env` ni commit qilish, yoki `.env` dagi qiymat konteynerga o'zi tushadi deb o'ylash.
- `image: postgres` (tag'siz): `pull` dan keyin major versiya o'zgaradi va eski data papkasi bilan baza ko'tarilmaydi.
- `ports: "5432:5432"` bazani `0.0.0.0` ga ochadi. Kerak bo'lsa `127.0.0.1:` bilan, kerak bo'lmasa umuman yozmang.
- Dev uchun yozilgan faylni (bind mount, debug port, `build`) o'zgarishsiz production'ga olib chiqish.
- Kod o'zgargandan keyin `up -d` ni `--build` siz ishlatish, yoki `.env` o'zgargandan keyin `restart` qilish.
- `container_name` berish: scale ishlamaydi, ikki project to'qnashadi.
- Limit va log rotatsiyasi yo'q: bitta servis hostni to'ldiradi (1-dars). Compose'da `logging.options` (`max-size`, `max-file`) va `deploy.resources.limits` yozing.
- Compose bitta hostni boshqaradi: host o'lsa hamma narsa o'ladi, rolling update yo'q. Bu chegaradan keyin orkestrator kerak.

## Manbalar

- https://docs.docker.com/compose/ – Compose hujjatlari
- https://docs.docker.com/reference/compose-file/ – Compose file reference (majburiy: services, networks, volumes)
- https://docs.docker.com/compose/how-tos/startup-order/ – ishga tushish tartibi, `depends_on` shartlari
- https://docs.docker.com/compose/how-tos/environment-variables/ – env, `.env`, ustuvorlik, interpolation
- https://docs.docker.com/compose/how-tos/multiple-compose-files/ – merge, override, `include`, `extends`
- https://docs.docker.com/compose/how-tos/profiles/ – profiles
- https://docs.docker.com/compose/how-tos/use-secrets/ – Compose'da secrets
- https://docs.docker.com/compose/how-tos/file-watch/ – `compose watch`
- https://github.com/compose-spec/compose-spec – Compose spetsifikatsiyasi
- https://nginx.org/en/docs/http/ngx_http_proxy_module.html – nginx `proxy_pass` va header'lar

---

## Vazifalar

Barchasini `docker/04-compose/` da bajaring (`make new m=docker n=04 name=compose`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. `compose.yaml`, override fayllar, nginx config, `.env.example` va ilova kodi shu papkada (`stack/` ichida) saqlanadi.

Ilova: 2-darsdagi Node yoki Go ilovangizni kengaytiring. `GET /` Redis'dagi hisoblagichni bittaga oshirib qiymatini va konteyner hostname'ini qaytaradi; `GET /visits` Postgres jadvalidagi yozuvlar sonini qaytaradi (har `/` so'rovi bitta qator qo'shadi); `GET /healthz` jarayon tirikligini bildiradi. Ulanish manzillari va parol env yoki fayldan o'qiladi. Start paytida jadval yo'q bo'lsa yaratiladi, ulanish xatosida ilova yiqilmay qayta urinadi.

### A. Asoslar

1. **First compose file.** Bitta `nginx:1.28-alpine` servisli `compose.yaml` yozing (`name:` bilan, port `127.0.0.1` da). `up -d` dan keyin `docker compose ps`, `docker ps`, `docker network ls`, `docker inspect` orqali konteyner, tarmoq nomlari va Compose qo'ygan label'larni (`com.docker.compose.*`) yozing. Compose konteyner qaysi project'ga tegishli ekanini qayerdan biladi?

2. **Idempotent up.** `up -d` ni ikkinchi marta ishlating: nima chiqdi? Keyin faylda portni o'zgartirib yana `up -d`: konteyner ID'si va IP o'zgardimi? `docker compose restart` shu o'zgarishni qo'llaydimi? `up`, `restart`, `up --force-recreate` farqini jadvalga yozing.

3. **Project name collision.** Bir xil nomli ikki papkada (`/tmp` ostida, masalan `a/demo` va `b/demo`) `name:` siz, har xil servis nomli compose fayl yarating va ikkalasini `up -d` qiling. Ikkinchi `up` dagi ogohlantirishni yozing va `docker compose ls` bilan izohlang. `name:` qo'shib tuzating, keyin ikkalasini `down` qiling.

4. **Service DNS.** Faylga ikkinchi servis (`alpine:3.22`, `sleep infinity`) qo'shing. Undan `wget -qO- http://<nginx-service-name>` va `nslookup` ni ishlating. Publish qilingan host porti bilan murojaat qilsangiz nima bo'ladi va nima uchun?

### B. Stack

5. **App and Postgres.** `app` (o'z `Dockerfile` ingizdan `build`) va `db` (`postgres:17-alpine`, named volume) servislarini yozing. `depends_on` ning qisqa shakli bilan `up` qiling va `app` loglaridagi ulanish xatolarini (yoki retry'larni) ko'rsating. Baza porti publish qilinmasin; `docker compose exec db psql` bilan jadvalni tekshiring.

6. **Healthy dependency.** `db` ga `pg_isready` healthcheck, `app` ga `condition: service_healthy` qo'shing. `down` va `up -d` dan keyin `docker compose ps` da tartibni va `app` loglari endi toza ekanini ko'rsating. Healthcheck'ni ataylab buzing (noto'g'ri user yoki mavjud bo'lmagan buyruq): `up` nima deydi va qancha kutadi?

7. **Redis and migrate job.** `redis:8-alpine` ni healthcheck (`redis-cli ping`) bilan qo'shing. Jadval yaratishni ilovadan alohida bir martalik `migrate` servisiga chiqaring (`psql` bilan SQL fayl) va `app` uni `service_completed_successfully` bilan kutsin. `docker compose ps -a` da `migrate` holati qanday? Migratsiya exit 1 bilan tugasa `app` nima bo'ladi?

8. **nginx reverse proxy.** nginx servisini qo'shing: o'zingiz yozgan config (`:ro` bind mount), `app` ga `proxy_pass`, faqat nginx port publish qiladi (`127.0.0.1:8080`). Ikki tarmoq yarating: nginx ikkalasida, qolganlar faqat ichkisida. `curl` bilan `/` va `/visits` ni tekshiring; `app` loglarida mijoz IP'si qanday ko'rinadi va `X-Forwarded-For` nima beradi?

9. **Persistence check.** Bir necha so'rov yuboring, keyin `docker compose down` va `up -d`: `/visits` soni saqlandimi, Redis hisoblagichi-chi? Nima uchun? Keyin `down -v` va `up -d` qilib yana tekshiring. Redis ma'lumotini saqlash kerak bo'lsa nima qo'shilishi kerak?

### C. Konfiguratsiya

10. **Interpolation and .env.** Image tag'lari, host porti va baza nomini `${VAR:-default}` ga chiqaring, majburiy bittasini `${VAR:?...}` qiling. `.env` va `.env.example` yarating. `docker compose config` chiqishini uch holatda solishtiring: `.env` bilan, `.env` siz, shell'da `VAR=... docker compose config`. Ustuvorlik tartibini yozing.

11. **env_file vs .env.** `.env` ga `FOO=1` yozing va `app` da hech qayerda ishlatmang: `docker compose exec app env | grep FOO` nima beradi? Keyin `env_file` orqali, so'ng `environment:` da boshqa qiymat bilan bering. Har holatda natijani yozing va ikki mexanizm farqini o'z so'zingiz bilan tushuntiring.

12. **Secrets.** Postgres parolini `environment` dan Compose secret'ga ko'chiring (`POSTGRES_PASSWORD_FILE`), ilovangiz ham parolni `/run/secrets/...` dan o'qisin. `docker compose config` va `docker inspect` da parol endi ko'rinmasligini, konteyner ichida fayl ruxsatlari va egasini ko'rsating. Secret fayli `.gitignore` da ekanini tekshiring.

13. **Profiles.** `debug` profile'iga bazani ko'rish uchun asbob servisini (`adminer` yoki `psql` li `alpine`) va `seed` profile'iga test ma'lumot yozadigan bir martalik servisni qo'shing. `up -d`, `--profile debug up -d`, `docker compose run --rm seed` holatlarida qaysi servislar ishga tushganini yozing.

14. **Override files.** Dev sozlamalarini (`build`, manba kodi bind mount yoki `watch`, debug port) `compose.override.yaml` ga, production sozlamalarini (`image:` registry'dan, `restart: unless-stopped`, resurs limitlari, log rotatsiyasi, `read_only`) `compose.prod.yaml` ga ajrating. Ikkala kombinatsiya uchun `docker compose config` ni solishtiring. `ports` ni ikkala faylda yozib "qo'shiladi" tuzog'ini ko'rsating va `!override` bilan tuzating.

### D. Ish jarayoni

15. **Compose watch.** `app` uchun `develop.watch` yozing: manba kodi `sync` (yoki `sync+restart`), dependency manifesti `rebuild`. `docker compose watch` ni ishga tushirib ikkala turdagi faylni o'zgartiring va logda nima sodir bo'lganini yozing. Bind mount yondashuvidan farqi va afzalligi nimada?

16. **Stale upstream.** `docker compose up -d --force-recreate app` qiling va darhol `curl` bilan nginx orqali so'rov yuboring. Nima bo'ldi? `app` ning eski va yangi IP'sini solishtiring, nginx error logini o'qing. Kamida ikki yechimni sinab ko'ring va qaysi birini tanlaganingizni asoslang.

17. **Scale.** `docker compose up -d --scale app=3` qiling (to'sqinlik qilsa nimani olib tashlash kerakligini toping). nginx orqali 10 ta so'rov yuborib javobdagi hostname'larni sanang. Trafik barcha nusxalarga ketyaptimi? Ketmayotgan bo'lsa nima uchun va nima qilish kerak? `nslookup app` (boshqa konteynerdan) nima qaytaradi?

18. **Logs and failure.** `docker compose logs -f --tail 20` ni ochiq qoldirib, boshqa terminalda `docker compose kill db` qiling. `app` va nginx qanday javob berdi (`/`, `/visits`, `/healthz`)? `docker compose start db` dan keyin ilova o'zi tiklandimi? `restart: unless-stopped` va `depends_on.restart: true` bu ssenariyda nimani o'zgartiradi?

### E. Yakuniy

19. **Production-like stack.** Yakuniy holat: to'rt servis (nginx, app, db, redis) va migrate; barchasida healthcheck, limit, restart policy, log rotatsiyasi; non-root va `read_only` mumkin bo'lgan joyda; secret'lar fayldan; pinned image tag'lar; faqat nginx publish qilingan. `docker compose -f compose.yaml -f compose.prod.yaml up -d --wait` exit 0 bilan tugasin. `Makefile` yoki `README` da `up`, `down`, `logs`, `psql`, `backup` (3-darsdagi `pg_dump` usuli) buyruqlarini hujjatlashtiring.

20. **Cleanup.** `docker compose down -v --remove-orphans --rmi local` qiling, `docker compose ls -a`, `docker ps -a`, `docker volume ls`, `docker network ls` da shu darsdan hech narsa qolmaganini va boshqa loyiha resurslari joyida ekanini ko'rsating. 3-vazifadagi `/tmp` papkalarini ham o'chiring.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. `docker compose config -q` (asosiy va prod kombinatsiyasi uchun) xatosiz.
3. `.env`, secret fayllari va dump'lar commit qilinmagan, `.env.example` bor.
4. Project resurslari tozalangan (`docker compose ls -a` bo'sh yoki unda `l4-` yo'q).
5. Menga xabar bering, compose fayllar, nginx config va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Compose project nima va uning nomi qayerdan olinadi? Nom to'qnashsa nima bo'ladi?
- Servislar bir-birini qanday topadi? Nima uchun ichki aloqa uchun `ports` kerak emas?
- `depends_on: [db]` va `condition: service_healthy` farqi nima? Nima uchun ilovada baribir retry kerak?
- `.env` fayli va `env_file:` kaliti qaysi ikki xil ishni bajaradi?
- `docker compose config` qachon kerak bo'ladi?
- Override fayllar qanday birlashadi? `ports` bilan qanday tuzoq bor?
- `up -d`, `restart`, `up -d --build` har biri nimani yangilaydi va nimani yangilamaydi?
- `down` va `down -v` farqi nima?
- `app` qayta yaratilganda nginx nima uchun 502 berishi mumkin?
- Compose qaysi muammolarni yecha olmaydi (keyingi dars uchun)?
