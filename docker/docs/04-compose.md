# 4-dars: Docker Compose

Maqsad: bir necha konteynerli muhitni bitta deklarativ faylda tavsiflash va bitta buyruq bilan ko'tarishni noldan tushunish. 3-dars oxirida ikki konteynerni skript bilan qo'lda yig'dingiz: tarmoq, volume, healthcheck, limit, tartib. Compose yangi obyekt kiritmaydi: bu o'sha konteyner, tarmoq va volume'lar, faqat `docker run` flag'lari o'rniga `compose.yaml` faylida e'lon qilingan. Compose faylni hozirgi holat bilan solishtiradi va faqat farq qilgan qismini qayta yaratadi. Bu darsda to'liq stack quriladi: ilova, Postgres, Redis va nginx reverse proxy. 5-darsda shu faylning o'zi Swarm stack sifatida deploy qilinadi, Kubernetes manifestlaridagi ko'p tushuncha (servis nomi bilan DNS, health tekshiruvi, secret fayl sifatida) ham shu yerdan keladi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh, ikkinchi kun 3-bo'lim, "Birga bajaramiz" va B guruh (ilovani kengaytirish shu kunga tushadi), uchinchi kun 4–5 bo'limlar va C guruh, to'rtinchi kun 6–7 bo'limlar va D guruh, beshinchi kun E guruh va README. E'tibor mexanizmga: project nomi va resurs nomlari qayerdan kelishi, `up` qachon konteynerni qayta yaratishi, `depends_on` shartlari, compose faylini interpolation qilish bilan konteyner environment'i farqi, fayllarning birlashish qoidalari, `down` va `down -v` farqi, reverse proxy ortida IP o'zgarishi.

Qanday o'qish kerak: har bo'limdagi fragmentni vaqtinchalik papkada (`~/l4-scratch`) o'zingiz yozib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi ID, IP, vaqt va versiyalar farq qiladi, bunday joylar `<...>` bilan belgilangan. `up` chiqishining sarlavha qatori va ustunlar kengligi Compose versiyasiga qarab biroz farq qilishi mumkin, holat so'zlari (`Created`, `Started`, `Healthy`, `Recreated`, `Running`) bir xil.

## Laboratoriya

Bu darsda hamma narsa host'da bajariladi: `docker compose` buyruqlari, `curl`, `make check`. `lab` VM kerak emas. Uchta "joy":

| Joy | Nima uchun |
|-----|------------|
| Host (Zorin yoki macOS) | `compose.yaml` yozish, `docker compose ...`, `curl http://localhost:<port>`, `git`, `make` |
| Konteyner (`docker compose exec <servis> sh`) | servis ichidan DNS, env, `/run/secrets` ni ko'rish |
| Vaqtinchalik papka (`~/l4-scratch`, `/tmp/...`) | nazariya fragmentlari va 3-vazifa, commit qilinmaydi |

Compose borligini tekshiring:

```
$ docker compose version
Docker Compose version v<versiya>
```

`docker compose` (bo'sh joy bilan) Docker CLI'ning Go'da yozilgan plugin'i, odatda "Compose v2" deyiladi (v2 dan keyingi major reliz v5 deb raqamlangan, buyruqlar o'sha). Eski Python'dagi `docker-compose` (defis bilan, v1) qo'llab-quvvatlanmaydi, o'rnatmang.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Compose qayerdan | Docker'ning rasmiy apt repo'sidan `sudo apt install docker-compose-plugin` (`amd64`) | Docker Desktop tarkibida keladi (`arm64`), alohida o'rnatilmaydi |
| `yamllint` (`make check` uchun) | `sudo apt install yamllint` | `brew install yamllint` |
| Publish qilingan port | `localhost:<port>` | `localhost:<port>`, bir xil |
| Konteyner IP'si host'dan | ochiladi (bridge host'da) | ochilmaydi, Engine yashirin Linux VM ichida. IP'ni faqat `docker inspect` da ko'rasiz, murojaat faqat publish qilingan port yoki `docker compose exec` orqali |
| Bind mount | to'g'ridan-to'g'ri host fayl tizimi, egasi host UID'i | fayl almashish qatlami orqali: faqat ulashilgan yo'llar (uy papkasi, `/tmp`), fayl egasi konteynerda boshqacha ko'rinishi mumkin (12-vazifada qaysi mashinada ekanini yozing) |
| Build qilingan image | `linux/amd64` | `linux/arm64` |

- **Izolyatsiya**: har compose faylda `name: l4-...` yozing. Barcha resurslar shu prefiks bilan yaratiladi. Tozalash faqat shu project uchun: `docker compose down -v --remove-orphans`. `docker system prune`, `docker volume prune -a`, `docker rm -f $(docker ps -aq)` ishlatilmaydi, mashinada boshqa loyihalar bor.
- **Portlar**: host'da 5432 va 6379 band bo'lishi mumkin, bu darsda baza va Redis portlari publish qilinmaydi. 8080 band bo'lsa boshqa port tanlang (10-vazifada u o'zgaruvchiga chiqadi).
- **Secret'lar**: `.env` va secret fayllari commit qilinmaydi (`make secrets` rad etadi). Commit qilinadigani qiymatsiz `.env.example`.
- **Ikkinchi mashinada tiklash**: compose fayllar, nginx config va ilova kodi git orqali keladi. Kelmaydigani: build qilingan image (arxitektura boshqa, `docker compose build` bilan qayta quring), volume'dagi ma'lumot (baza bo'sh boshlanadi, bu normal), `.env` va secret fayllari (`.env.example` dan qo'lda qayta yarating). 2-darsdagi ilova `docker/02-images/` da, shu darsda uni kengaytirasiz.
- Barcha image'lar (`nginx`, `postgres`, `redis`, `httpd`, `mariadb`, `wordpress`, `alpine`, `busybox`) `amd64` va `arm64` uchun mavjud.

---

## 1. Compose modeli: fayl, project, servis

### Bu nima

Compose uch narsadan iborat. **Fayl** (`compose.yaml`): kerakli holatning tavsifi. **Servis**: fayldagi bitta konteyner turi (image, portlar, env, volume'lar), undan bir yoki bir necha konteyner yaratiladi. **Project**: bitta fayldan yaratilgan barcha resurslar (konteynerlar, tarmoqlar, volume'lar) to'plami, nomi bilan ajratiladi. `docker compose` buyruqlari har doim bitta project ichida ishlaydi. Fayl deklarativ: "nima bo'lishi kerak" yoziladi, "qanday buyruqlar bilan" emas. `package.json` bilan o'xshashlik shu yerda haqiqiy: siz bog'liqliklar ro'yxatini yozasiz, `npm install` hozirgi `node_modules` ni unga moslaydi.

### Fayl tuzilishi

Fayl nomi `compose.yaml` (afzal), `compose.yml`, eski `docker-compose.yaml` ham o'qiladi. Eski qo'llanmalardagi `version: "3.8"` qatori eskirgan: Compose uni e'tiborsiz qoldiradi va ogohlantiradi, yozmang.

```
name: l4-demo
services:
  site:
    image: httpd:2.4-alpine
    ports:
      - "127.0.0.1:8081:80"
  docs:
    image: httpd:2.4-alpine
volumes:
  cache:
```

Yuqori darajadagi kalitlar: `name`, `services`, `networks`, `volumes`, `secrets`, `configs`, `include` (boshqa compose faylni qo'shish). Servis kalitlari 1–3 darslardagi `docker run` flag'larining o'zi:

| Kalit | `docker run` dagi mos keladigani |
|-------|----------------------------------|
| `image`, `build` | image nomi yoki Dockerfile'dan qurish (2-dars) |
| `command`, `entrypoint` | `CMD` va `ENTRYPOINT` ni almashtirish (2-dars) |
| `environment`, `env_file` | `-e`, `--env-file` |
| `ports` | `-p` (3-dars). `expose` faqat hujjat |
| `volumes` | `-v` / `--mount` (named volume yuqoridagi `volumes:` da e'lon qilinadi) |
| `networks` | `--network`, `aliases` bilan |
| `restart` | `--restart` (1-dars) |
| `healthcheck` | `--health-*` (3-dars) |
| `deploy.resources.limits` | `--cpus`, `--memory` (1-dars) |
| `user`, `read_only`, `tmpfs`, `init`, `cap_drop` | xavfsizlik flag'lari |
| `stop_grace_period` | `--stop-timeout` |
| `logging` | `--log-driver`, `--log-opt` |
| `depends_on`, `profiles`, `secrets`, `develop` | faqat Compose'da (3–6 bo'limlar) |

### Mexanizm: nomlar va label'lar

Project nomi shu tartibda aniqlanadi: `-p` flag'i, `COMPOSE_PROJECT_NAME` o'zgaruvchisi, fayldagi `name:`, aks holda fayl turgan papka nomi. Nomda faqat kichik harf, raqam, `-` va `_` bo'ladi. Resurs nomlari undan yasaladi:

| Resurs | Nomi | Misolda |
|--------|------|---------|
| konteyner | `<project>-<service>-<n>` | `l4-demo-site-1` |
| tarmoq | `<project>_<network>` | `l4-demo_default` |
| volume | `<project>_<volume>` | `l4-demo_cache` |

Compose o'z holatini hech qayerda alohida saqlamaydi. U yaratgan har resursga label (3-darsdagi kalit-qiymat belgi) qo'yadi, masalan `com.docker.compose.project` va `com.docker.compose.service`, va har buyruqda Docker'dan "shu project label'i bor resurslar" ni so'raydi. Shuning uchun `docker compose ps` faqat o'z project'ini ko'rsatadi, `docker ps` esa hammasini.

**Tuzoq: bir xil nomli ikki papka bitta project.** `~/a/app` va `~/b/app` dan `name:` siz `up` qilinsa ikkalasi `app` project'i bo'ladi va Compose birining konteynerlarini ikkinchisining "orphan" i (faylda yo'q, lekin project label'i bor konteyner) deb ko'radi. `name:` ni har doim aniq yozing.

### Mexanizm: default tarmoq va servis nomi bilan DNS

Faylda `networks:` yozilmasa Compose `<project>_default` nomli user-defined bridge tarmoq yaratadi va barcha servislarni unga ulaydi. 3-darsda ko'rganingizdek, user-defined bridge'da Docker'ning ichki DNS serveri (`127.0.0.11`) konteyner nomlarini IP'ga yechadi. Compose har konteynerga servis nomini tarmoq alias'i qilib beradi, shuning uchun `docs` servisiga boshqa servisdan `http://docs` deb murojaat qilinadi. Ichki aloqa konteyner portiga boradi (`80`), `ports:` bunga kerak emas: `ports:` faqat host'dan kirish uchun.

### Misol

```
$ docker compose up -d
 ✔ Network l4-demo_default   Created
 ✔ Volume "l4-demo_cache"    Created
 ✔ Container l4-demo-docs-1  Started
 ✔ Container l4-demo-site-1  Started
$ docker compose ps
NAME             IMAGE              COMMAND              SERVICE   CREATED          STATUS          PORTS
l4-demo-docs-1   httpd:2.4-alpine   "httpd-foreground"   docs      <N> seconds ago  Up <N> seconds  80/tcp
l4-demo-site-1   httpd:2.4-alpine   "httpd-foreground"   site      <N> seconds ago  Up <N> seconds  127.0.0.1:8081->80/tcp
$ docker compose exec site wget -qO- http://docs
<html><body><h1>It works!</h1></body></html>
$ docker compose exec site cat /etc/resolv.conf
nameserver 127.0.0.11
<...>
```

`up` chiqishi: har qator bitta resurs va uning holati; avval tarmoq va volume, keyin konteynerlar. `ps` ustunlari: `NAME` yasalgan konteyner nomi, `SERVICE` fayldagi servis nomi, `STATUS` 1-darsdagi holat (healthcheck bo'lsa qavsda `healthy`), `PORTS` da `docs` uchun faqat `80/tcp` (image e'lon qilgan port, publish yo'q), `site` uchun `127.0.0.1:8081->80/tcp` (host'ning loopback'idagi 8081 konteynerning 80 portiga). `exec site wget ... http://docs` `site` konteyneri ichidan `docs` ga servis nomi bilan yetdi, garchi `docs` hech narsa publish qilmagan bo'lsa ham. `resolv.conf` dagi `127.0.0.11` Docker'ning ichki DNS'i. Tozalash: `docker compose down -v`.

**Tuzoq: YAML tiplari.** Portlarni har doim qo'shtirnoqda yozing (`"8081:80"`): qo'shtirnoqsiz `xx:yy` qiymatni YAML son deb o'qishi mumkin. `environment` dagi `true`, `yes`, `no` ham qo'shtirnoqda bo'lsin. Compose qiymatlarida `$` interpolation belgisi (4-bo'lim), konteyner ichidagi shell o'zgaruvchisi kerak bo'lsa `$$` yoziladi.

### Real ishda qachon kerak

- Loyihaga yangi kelgan odam `git clone` va `docker compose up -d` bilan baza, kesh va ilovani bir xil versiyalarda oladi: "menda ishlaydi" muammosining lokal yechimi.
- CI'da integratsion testlar uchun baza va boshqa bog'liqliklarni ko'tarish.
- Bitta serverdagi kichik production (bitta host yetarli bo'lganda).

### Nima uchun shunday

`docker run` buyruqlari imperativ: tartibni, flag'larni va tozalashni siz eslab turasiz, 3-darsdagi `up.sh` shuning uchun uzun edi. Deklarativ faylni esa review qilish, git'da diff ko'rish va qayta-qayta qo'llash mumkin. Compose 2013-yilda Fig nomli alohida asbob sifatida paydo bo'lgan, Docker uni sotib olib `docker-compose` (Python) qilgan, keyin Go'da qayta yozib CLI plugin'iga aylantirgan. Fayl formati hozir ochiq Compose Specification bilan belgilanadi, shuning uchun `version:` kerak emas. Holatni label'larda saqlash qarori tufayli alohida holat fayli yo'q va buzilib qoladigan narsa kam; muqobili (Terraform'dagi state fayl) IaC modulida.

## 2. `up` qanday ishlaydi: holatni faylga keltirish

### Bu nima

`docker compose up` "ishga tushir" emas, "holatni faylga mos qil" degani. Bu jarayon **reconcile** (kerakli va haqiqiy holatni solishtirib farqni yo'qotish) deyiladi va Kubernetes ham xuddi shu g'oyada ishlaydi.

### Mexanizm

Compose har konteynerni yaratganda servis konfiguratsiyasining hash'ini `com.docker.compose.config-hash` label'iga yozadi. Keyingi `up` da har servis uchun:

| Holat | `up` nima qiladi | Chiqishda |
|-------|------------------|-----------|
| konteyner yo'q | yaratadi va start qiladi | `Created`, `Started` |
| bor, hash va image bir xil, ishlayapti | hech narsa | `Running` |
| bor, to'xtagan | start qiladi | `Started` |
| hash yoki image o'zgargan | eski konteynerni to'xtatib o'chiradi, yangisini yaratadi | `Recreated`, `Started` |
| konteyner bor, servis fayldan o'chirilgan | ogohlantiradi (orphan), `--remove-orphans` bilan o'chiradi | |

Qayta yaratilgan konteyner yangi konteyner: ID yangi, yoziladigan layer (2-dars) yo'qoladi. Saqlanadigani: named volume'lar (ular konteynerga emas, project'ga tegishli) va tarmoq. Boshqa servislarga tegilmaydi.

### Misol

1-bo'limdagi faylda `site` ga `environment: {MODE: "debug"}` qo'shib, qayta `up`:

```
$ docker compose up -d
 ✔ Container l4-demo-docs-1  Running
 ✔ Container l4-demo-site-1  Started
```

`docs` ning hash'i o'zgarmagan, shuning uchun `Running` (tegilmadi). `site` ning konfiguratsiyasi o'zgardi: uning qatori terminalda joyida yangilanib `Recreate`, `Recreated`, `Starting` holatlaridan o'tadi va `Started` da to'xtaydi (chiqish faylga yoki pipe'ga yo'naltirilsa oraliq holatlar alohida qatorlar bo'lib chiqadi). `docs` hech qachon `Recreated` bo'lmaydi: farq shunda. O'zgarishsiz uchinchi `up` ikkala qatorda `Running` chiqaradi: buyruq idempotent (necha marta ishlatilsa ham natija bir xil).

### To'xtatish va o'chirish

| Buyruq | Konteyner | Tarmoq | Named volume |
|--------|-----------|--------|--------------|
| `docker compose stop` | to'xtaydi, qoladi | qoladi | qoladi |
| `docker compose down` | o'chadi | o'chadi | **qoladi** |
| `docker compose down -v` | o'chadi | o'chadi | **o'chadi** (anonim volume'lar ham) |

`restart` konteynerni to'xtatib o'sha konteynerni qayta start qiladi, compose faylni va `.env` ni qayta o'qimaydi. `--rmi local` qo'shilsa `down` Compose o'zi nomlagan (`image:` bilan nom berilmagan) build image'larini ham o'chiradi.

**Tuzoq: `down -v` bazani o'chiradi.** `down` va `down -v` orasidagi farq bitta flag, natijasi qaytarilmaydi. Production'da `-v` ni odat qilmang.

### Real ishda qachon kerak

- Deploy: yangi image tag'ini faylga (yoki `.env` ga) yozib `up -d` qilinadi, faqat o'sha servis almashadi, baza ishlab turaveradi.
- "O'zgartirdim, lekin qo'llanmadi" holati: deyarli har doim `restart` ishlatilgan, `up -d` emas.

### Nima uchun shunday

Konteyner konfiguratsiyasining ko'p qismi (env, portlar, mount'lar) yaratilgandan keyin o'zgartirilmaydi (1-dars), shuning uchun "yangilash" faqat "o'chirib qayta yaratish" bo'lishi mumkin. Bu konteynerni bir martalik narsa deb qarashga majbur qiladi: ma'lumot volume'da, konfiguratsiya faylda, konteynerning o'zida saqlanadigan hech narsa yo'q. Muqobili, ishlab turgan mashinani qo'lda o'zgartirib borish (konfiguratsiya "drift" i), Ansible modulida ko'riladigan muammo.

## 3. Ishga tushish tartibi: `depends_on` va healthcheck

### Bu nima

Servislar bir-biriga bog'liq: ilova bazasiz ishlamaydi. `depends_on` Compose'ga tartibni aytadi: avval bog'liqlik, keyin unga muhtoj servis (`down` da teskari tartib).

### Mexanizm: "start bo'ldi" va "tayyor" bir narsa emas

Qisqa shakl (`depends_on: [store]`) faqat bog'liqlik **konteyneri start bo'lishini** kutadi. Lekin jarayon start bo'lishi bilan ulanish qabul qilishi orasida vaqt o'tadi: baza fayllarini tekshiradi, birinchi ishga tushishda ma'lumot papkasini yaratadi. Bu frontend'dan ma'lum poyga: E2E test dev server "listening" demasidan oldin boshlansa `ECONNREFUSED` bilan yiqiladi, shuning uchun `wait-on` kabi asbob ishlatiladi. Compose'da shu kutishni healthcheck (3-dars: Docker konteyner ichida vaqti-vaqti bilan ishlatadigan tekshiruv buyrug'i, exit 0 bo'lsa `healthy`) va `depends_on` ning uzun shakli bajaradi:

```
services:
  report:
    image: busybox:1.37
    command: ["wget", "-qO-", "http://store"]
    depends_on:
      store:
        condition: service_healthy
      prepare:
        condition: service_completed_successfully
  prepare:
    image: busybox:1.37
    command: ["sh", "-c", "echo preparing; sleep 2"]
  store:
    image: httpd:2.4-alpine
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://127.0.0.1/"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
```

| `condition` | Kutadi |
|-------------|--------|
| `service_started` | konteyner start bo'lgan (qisqa shakl shu) |
| `service_healthy` | healthcheck `healthy` bo'lgan. Bog'liqlikda healthcheck bo'lishi shart |
| `service_completed_successfully` | konteyner exit 0 bilan tugagan (bir martalik ishlar: migratsiya, seed) |

Healthcheck maydonlari: `test` buyruq, `interval` tekshiruvlar orasi, `timeout` bitta tekshiruvga berilgan vaqt, `retries` ketma-ket nechta muvaffaqiyatsizlikdan keyin `unhealthy`, `start_period` boshlang'ich imtiyoz davri (bu davrdagi muvaffaqiyatsizlik sanalmaydi). `test` shakllari: `["CMD", "prog", "arg"]` (exec, shell'siz), `["CMD-SHELL", "..."]` (shell orqali, o'zgaruvchi kerak bo'lsa `$$VAR`), `["NONE"]` (image'dagi healthcheck'ni o'chirish). Tekshiruv buyrug'i image ichida bo'lishi kerak.

Qo'shimcha kalitlar: `restart: true` (bog'liqlik qayta ishga tushirilsa yoki qayta yaratilsa shu servis ham qayta ishga tushadi), `required: false` (bog'liqlik yo'q bo'lsa, masalan profile yoqilmagan, faqat ogohlantiradi).

### Misol

Yuqoridagi fragment boshiga `name: l4-order` qo'shilgan fayl bilan:

```
$ docker compose up -d
 ✔ Container l4-order-prepare-1  Exited
 ✔ Container l4-order-store-1    Healthy
 ✔ Container l4-order-report-1   Started
$ docker compose ps -a --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'
SERVICE   STATE     STATUS
prepare   exited    Exited (0) <N> seconds ago
report    exited    Exited (0) <N> seconds ago
store     running   Up <N> seconds (healthy)
```

`prepare` uchun `Exited` bu yerda xato emas: bir martalik ish tugadi va Compose uning kodi 0 ekanini tekshirdi. `store` uchun `Healthy`: Compose healthcheck birinchi marta muvaffaqiyatli o'tguncha kutdi. Shundan keyingina `report` start bo'ldi. `ps -a` da `report` ham `Exited (0)`: u bitta so'rov yuborib tugadi (`docker compose logs report` da HTML). Bog'liqlik `unhealthy` bo'lsa yoki bir martalik ish noldan farqli kod bilan tugasa, `up` muhtoj servisni start qilmaydi va xato bilan tugaydi (6 va 7-vazifalarda aynan nima deyishini ko'rasiz).

**Tuzoq: `depends_on` faqat `up` paytida ishlaydi.** Baza ish vaqtida qayta ishga tushsa, ilova buni o'zi ko'tarishi kerak: ulanishni qayta urinish (retry) ilova kodining vazifasi. `depends_on` qulaylik, chidamlilik emas.

### Real ishda qachon kerak

- Migratsiya (baza sxemasini o'zgartiradigan bir martalik skript) ilovadan oldin tugashi shart bo'lganda.
- CI'da: `docker compose up -d --wait` barcha servislar `healthy` bo'lguncha kutadi, shundan keyin testlar boshlanadi; biror servis sog'lom bo'lmasa noldan farqli kod qaytaradi.

### Nima uchun shunday

Docker "tayyor" nimaligini bila olmaydi: har dasturda u boshqa (port ochildi, migratsiya tugadi, kesh isidi). Shuning uchun tayyorlik ta'rifi sizdan so'raladi (healthcheck), Compose esa faqat natijasini kutadi. Muqobili ilova entrypoint'idagi `wait-for-it.sh` kabi skriptlar edi: ular har image'ga qo'shilishi kerak va faqat port ochilganini biladi. Orkestratorlar boshqa yo'lni tanlagan: tartibni umuman kafolatlamaydi, har servis bog'liqligi yo'q bo'lsa qayta urinishi kerak (5-dars). Shuning uchun retry'ni hozirdan ilovaga yozish to'g'ri odat.

## 4. Konfiguratsiya: interpolation, konteyner environment'i, secrets

### Bu nima: ikki alohida mexanizm

Environment o'zgaruvchisi (env) bu jarayonga ishga tushganda beriladigan `KEY=value` juftligi, Node'da `process.env` orqali o'qiladi. Compose'da "o'zgaruvchi" so'zi ikki xil ishni bildiradi va ular tez-tez chalkashtiriladi:

| | Interpolation | Konteyner environment'i |
|---|---------------|-------------------------|
| Nima | compose **faylining matnidagi** `${VAR}` ni qiymatga almashtirish | konteyner ichidagi jarayon ko'radigan env |
| Kim o'qiydi | Compose, host'da, fayl o'qilganda | ilova, konteyner ichida |
| Manba | shell muhiti, keyin project papkasidagi `.env` | `environment:` va `env_file:` kalitlari |

`dotenv` bilan farq muhim: Node'da `.env` to'g'ridan-to'g'ri `process.env` ga yuklanadi. Compose'da esa `.env` avvalo faylni to'ldirish uchun; undagi qiymat konteynerga faqat siz uni `${VAR}` sifatida `environment:` da ishlatsangiz yoki `env_file:` da ko'rsatsangiz tushadi.

### Mexanizm: tartib

1. Compose shell muhitini va project papkasidagi (`compose.yaml` yonidagi) `.env` faylini o'qiydi. Bir xil nom ikkalasida bo'lsa **shell ustun**. Boshqa fayl: `docker compose --env-file <fayl> ...`.
2. Fayl matnidagi `${...}` lar almashtiriladi. Natija: o'zgaruvchisiz tayyor model.
3. Konteyner yaratilganda uning env'i yig'iladi, ustuvorlik yuqoridan pastga: `docker compose run -e`, `environment:`, `env_file:` dagi fayllar, image'dagi `ENV` (2-dars).

| Yozuv | Ma'nosi |
|-------|---------|
| `${TAG}` | qiymat; yo'q bo'lsa bo'sh satr va ogohlantirish |
| `${TAG:-2.4}` | yo'q yoki bo'sh bo'lsa default |
| `${TAG:?message}` | yo'q yoki bo'sh bo'lsa xato bilan to'xtaydi |

### Misol: `docker compose config`

`docker compose config` barcha fayllarni birlashtirib, o'zgaruvchilarni almashtirib, yakuniy modelni chiqaradi, hech narsa ishga tushirmaydi. "Nima uchun bu qiymat ketdi" savolining javobi shu yerda.

```
$ cat compose.yaml
name: l4-vars
services:
  site:
    image: httpd:${HTTPD_TAG:-2.4-alpine}
    environment:
      GREETING: ${GREETING}
$ docker compose config
WARN[0000] The "GREETING" variable is not set. Defaulting to a blank string.
name: l4-vars
services:
  site:
    environment:
      GREETING: ""
    image: httpd:2.4-alpine
    networks:
      default: null
networks:
  default:
    name: l4-vars_default
$ GREETING=salom docker compose config | grep GREETING
      GREETING: salom
```

Birinchi chiqishda: `WARN` qatori `${GREETING}` uchun qiymat topilmaganini aytadi; `image` da default ishladi; kalitlar alifbo tartibida qayta yozilgan; siz yozmagan `networks.default` ko'rinib turibdi (1-bo'limdagi yashirin tarmoq). Ikkinchi buyruqda qiymat shell'dan keldi. Foydali flag'lar: `-q` (faqat tekshiradi, xato bo'lmasa jim), `--services`, `--volumes`, `--images`.

**Tuzoq: `config` secret'larni ochiq chiqaradi.** `environment:` ga interpolation bilan tushgan parol `config` chiqishida va `docker inspect` da ochiq matn. Chiqishni issue yoki chat'ga ko'chirishdan oldin o'qing.

### `.env` va `.env.example`

`.env` da mashinaga xos va maxfiy qiymatlar turadi, shuning uchun commit qilinmaydi. Repo'ga `.env.example` qo'yiladi: o'sha kalitlar, qiymatsiz yoki xavfsiz default bilan. Yangi mashinada `cp .env.example .env` qilib to'ldiriladi. Bu Node loyihalaridagi odatning o'zi.

### Secrets

Parolni env orqali berishning kamchiligi: u `docker inspect` da, `config` da, ko'pincha xato hisobotlari va loglarda ko'rinadi. Compose'da secret fayl sifatida beriladi va konteynerda `/run/secrets/<nom>` da paydo bo'ladi:

```
services:
  worker:
    image: busybox:1.37
    command: ["sh", "-c", "wc -c < /run/secrets/api_token"]
    secrets: [api_token]
secrets:
  api_token:
    file: ./secrets/api_token.txt
```

Yuqoridagi `secrets:` secret'ni e'lon qiladi (manbasi host'dagi fayl), servisdagi `secrets:` uni shu servisga beradi; bermagan servis ko'rmaydi. Yolg'iz Compose'da bu faqat o'qish uchun bind mount (shifrlanmaydi, fayl egasi va ruxsatlari host'dagi fayldan keladi), lekin parol env'dan chiqadi va xuddi shu yozuv 5-darsda Swarm secret'lari bilan ishlaydi. Rasmiy image'larning ko'pi `<VAR>_FILE` ko'rinishidagi o'zgaruvchini tushunadi: qiymat o'rniga fayl yo'li beriladi va image uni o'zi o'qiydi. O'z ilovangizda faylni o'qishni siz yozasiz.

### Real ishda qachon kerak

- Bitta fayl, bir necha muhit: image tag'i, port, domen `.env` dan, fayl o'zgarmaydi.
- `${VAR:?...}`: majburiy qiymat unutilganda bo'sh parol bilan jimgina ishga tushish o'rniga darhol xato.
- Deploy'dan oldin `docker compose config -q` sintaksis va o'zgaruvchilarni tekshiradi.

### Nima uchun shunday

Konfiguratsiyani koddan va image'dan ajratish (bitta image, har muhitda boshqa env) "twelve-factor app" tamoyilidan keladi: image bir marta quriladi va dev, staging, production'da o'zgarishsiz ishlaydi. Interpolation va konteyner env'i ataylab ajratilgan: `.env` dagi hamma narsa har konteynerga tushganda edi, baza paroli nginx konteynerida ham ko'rinardi. Secret'lar fayl bo'lishi sababi: fayl ruxsat bilan cheklanadi va faqat kerakli servisga ulanadi, env esa jarayonning barcha bola jarayonlariga meros bo'ladi.

## 5. Profiles va bir necha fayl

### Profiles

`profiles` berilgan servis faqat shu profile yoqilganda ishga tushadi; profile'siz servislar har doim. Bu ixtiyoriy servislar uchun: debug asboblari, bir martalik seed, monitoring.

```
services:
  site:
    image: httpd:2.4-alpine
  bench:
    image: busybox:1.37
    command: ["sh", "-c", "time wget -qO /dev/null http://site"]
    profiles: [tools]
```

```
$ docker compose up -d                     # site only
$ docker compose --profile tools up -d     # site and bench (or COMPOSE_PROFILES=tools)
$ docker compose run --rm bench            # naming the service enables its profile
```

Mexanizm: Compose modelni yuklaganda yoqilmagan profile'dagi servislarni modeldan chiqarib tashlaydi, go'yo ular faylda yo'q. Buyruqda servis nomi aniq yozilsa (`run bench`), uning profile'i o'zi yoqiladi. `docker compose config --profiles` fayldagi profile'lar ro'yxatini beradi.

### Bir necha fayl va birlashish

`-f` berilmasa Compose `compose.yaml` ni va, agar bo'lsa, `compose.override.yaml` ni avtomatik birlashtiradi. Odatiy sxema: `compose.yaml` umumiy asos, `compose.override.yaml` lokal dev (bind mount, debug port), `compose.prod.yaml` production sozlamalari.

```
docker compose up -d                                         # base + override
docker compose -f compose.yaml -f compose.prod.yaml up -d    # base + prod, override ignored
```

`-f` berilgan zahoti avtomatik qoida o'chadi: faqat sanalgan fayllar, chapdan o'ngga. Keyingi fayl oldingisining ustiga yoziladi, `tsconfig.json` dagi `extends` ga o'xshash, lekin qoidalar tipga bog'liq:

| Tip | Qoida | Misol |
|-----|-------|-------|
| skalyar | almashtiriladi | `image`, `restart` |
| mapping | kalit bo'yicha birlashadi | `environment`, `labels` |
| ro'yxat | qo'shiladi | `ports`, `expose`, `dns` |
| `command`, `entrypoint`, `healthcheck.test` | to'liq almashtiriladi | |

Misol: asosda `site` da `environment: {MODE: "prod", REGION: "eu"}`, override'da `environment: {MODE: "dev"}` va `image: httpd:2.4`. Natija (`docker compose config`): `MODE: dev` (kalit almashdi), `REGION: eu` (qoldi), `image: httpd:2.4` (skalyar almashdi).

**Tuzoq: ro'yxatlar qo'shiladi, almashtirilmaydi.** Asosdagi va override'dagi `ports` yozuvlari ikkalasi ham kuchda qoladi. To'liq almashtirish uchun override'da YAML tegi ishlatiladi: `!override` (qiymatni to'liq almashtiradi) yoki `!reset` (kalitni olib tashlaydi). Natijani har doim `docker compose config` bilan tekshiring. `-f` li buyruqlarda (`ps`, `logs`, `down`) o'sha `-f` larni takrorlang yoki `COMPOSE_FILE` o'zgaruvchisiga yozing.

### Real ishda qachon kerak

- Dev'da manba kodi bind mount va debug port, production'da registry'dagi tayyor image, limit va log rotatsiyasi: bitta asos, ikki qo'shimcha.
- `adminer` kabi asbob kerak bo'lgandagina yoqiladi, doim ishlab turmaydi.

### Nima uchun shunday

Muqobili har muhit uchun to'liq alohida fayl: ular vaqt o'tishi bilan farqlanib ketadi va dev'da ishlagan narsa production'da boshqacha bo'ladi. Asos va kichik qo'shimchalar farqni ko'rinadigan qiladi. Ro'yxatlarning qo'shilishi env va label'lar uchun qulay, portlar uchun kutilmagan; `!override` shu noqulaylikka keyinroq qo'shilgan javob. Kubernetes'da shu muammoni Kustomize va Helm yechadi.

## 6. Build, kundalik buyruqlar va watch

### Build

```
services:
  api:
    build:
      context: ./api
      target: runtime
      args:
        VERSION: ${VERSION:-dev}
    image: ghcr.io/<user>/l4-api:${VERSION:-dev}
```

`build` 2-darsdagi `docker build` ning o'zi: `context` build papkasi, `dockerfile` (default `Dockerfile`), `target` multi-stage bosqichi, `args` build argumentlari. `image:` ham bo'lsa qurilgan image shu nom bilan teglanadi, bo'lmasa `<project>-<service>` deb nomlanadi. Buyruqlar: `docker compose build`, `docker compose up -d --build`, `docker compose push`.

**Tuzoq: `up` image'ni o'zi qayta qurmaydi.** Image mavjud bo'lsa, kod o'zgargani bilan `up -d` eski image'ni ishlatadi. `--build` yozing.

### Buyruqlar project ichida ishlaydi

Barcha buyruqlar konteyner nomi emas, **servis nomi** bilan ishlaydi va faqat joriy project'ni ko'radi (joriy papkadagi fayl yoki `-p <nom>`).

| Buyruq | Vazifa |
|--------|--------|
| `up -d` | holatni faylga keltiradi (2-bo'lim). `--wait` hamma servis `healthy` bo'lguncha kutadi |
| `ps`, `ps -a` | project konteynerlari, holat va health (`-a` tugaganlarini ham) |
| `logs -f --tail 50 [svc]` | loglar, har qator `<servis>-<n>  \|` prefiksi bilan |
| `exec svc cmd` | ishlayotgan konteynerda buyruq. Pipe bilan ishlatganda `-T` (TTY'siz) |
| `run --rm svc cmd` | bir martalik yangi konteyner (`ports` publish qilinmaydi, `depends_on` ko'tariladi) |
| `stop`, `start`, `restart`, `kill` | konteynerlarni o'chirmasdan |
| `down`, `down -v` | o'chirish (2-bo'lim) |
| `config`, `top`, `images` | diagnostika |
| `ls`, `ls -a` | mashinadagi barcha project'lar (`-a` to'xtaganlarini ham) |
| `up -d --scale svc=3` | servisni bir necha nusxada |

```
$ docker compose ls
NAME      STATUS       CONFIG FILES
l4-demo   running(2)   <yo'l>/compose.yaml
$ docker compose logs --tail 1
docs-1  | <IP> - - [<sana>] "GET / HTTP/1.1" 200 45
```

`ls` da `STATUS` qavsidagi son ishlayotgan konteynerlar soni, `CONFIG FILES` project qaysi fayldan yaratilgani (label'dan olinadi). `logs` da prefiks qaysi servis va qaysi nusxa yozganini ko'rsatadi, qolgani konteynerning stdout'i (1-dars): bu yerda httpd'ning access log qatori, `<IP>` so'rov yuborgan konteynerning manzili.

Limit va log rotatsiyasi ham servis kalitlari:

```
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 256M
    logging:
      options:
        max-size: "10m"
        max-file: "3"
```

### compose watch

Dev sikli uchun: Compose host'dagi fayllarni kuzatadi va o'zgarishga qarab konteynerni yangilaydi (`build` li servislar uchun, bind mount'ga muqobil).

```
services:
  api:
    build: ./api
    develop:
      watch:
        - action: sync
          path: ./api/src
          target: /app/src
        - action: rebuild
          path: ./api/go.mod
```

| `action` | Nima qiladi |
|----------|-------------|
| `sync` | faylni ishlayotgan konteynerga nusxalaydi (ilovaning o'zida hot reload bo'lishi kerak) |
| `sync+restart` | nusxalaydi va konteynerni restart qiladi (config fayllar uchun) |
| `rebuild` | image'ni qayta quradi va konteynerni almashtiradi (dependency o'zgarganda) |

Ishga tushirish: `docker compose watch` yoki `docker compose up --watch`.

### Real ishda qachon kerak

- `exec` va `logs` kundalik debug; `run --rm` migratsiya va bir martalik skriptlar uchun.
- `watch` macOS'da ayniqsa foydali: bind mount fayl almashish qatlamidan o'tadi va `node_modules` kabi katta daraxtlarda sekin, `sync` esa faqat o'zgargan faylni nusxalaydi.

### Nima uchun shunday

Buyruqlar servis nomi bilan ishlashi konteyner nomi va ID'sini eslab yurishdan qutqaradi: konteyner qayta yaratilganda ID o'zgaradi, servis nomi esa o'zgarmaydi. `watch` bind mount muammolariga javob: bind mount host'dagi `node_modules` ni konteynerdagisining ustiga yopadi (arxitektura boshqa bo'lsa native modullar buziladi) va host UID'i bilan konteyner UID'i to'qnashadi (3-dars). `sync` image ichidagi fayllarga tegmaydi, faqat ko'rsatilgan yo'lni yangilaydi.

## 7. Reverse proxy ortidagi stack

### Bu nima

**Reverse proxy** mijoz va ilova orasida turadigan server: mijoz faqat proxy bilan gaplashadi, proxy so'rovni ichkaridagi servisga (**upstream**) uzatadi va javobni qaytaradi. Vite yoki webpack dev serveridagi `proxy` sozlamasi (`/api` ni backend'ga yo'naltirish) aynan shuning kichik ko'rinishi. Production'da proxy TLS'ni tugatadi, statik fayllarni beradi, bir necha nusxa orasida yukni taqsimlaydi va ichki servislarni tashqaridan yashiradi.

Maqsadli arxitektura:

```
host:8080 -> nginx (front, back) -> app (back) -> postgres (back), redis (back)
```

### Mexanizm

- **Faqat proxy port publish qiladi.** Qolgan servislar bir-birini servis nomi bilan topadi (1-bo'lim) va host'dan ko'rinmaydi.
- **Ikki tarmoq.** Servisda `networks: [front, back]` yozilsa u ikkalasiga ulanadi; faqat `back` dagi servisga `front` dan yetib bo'lmaydi. Yuqori `networks:` da tarmoqqa `internal: true` berilsa undan tashqi dunyoga chiqish ham yopiladi.
- **Uzatish.** nginx'da `location` bloki yo'lni upstream'ga bog'laydi. Ilova endi mijozni emas, proxy'ni ko'radi: TCP ulanish proxy konteyneridan keladi. Asl manzilni proxy header'da uzatadi:

```
location /reports/ {
  proxy_pass http://backend:9000;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

`proxy_pass` so'rovni `backend` nomli servisning 9000 portiga yuboradi (nom Docker DNS orqali yechiladi), `Host` asl domen nomini saqlaydi, `X-Forwarded-For` ga mijoz IP'si qo'shiladi. nginx config ichidagi `$host` nginx o'zgaruvchisi, Compose interpolation'iga aloqasi yo'q, chunki u compose faylida emas, alohida faylda turadi.

- **Nusxalar.** `--scale` ishlashi uchun servisda `container_name` va host porti bo'lmasligi kerak: bitta nom va bitta host portiga ikki konteyner sig'maydi. Servis nomi DNS'da barcha nusxalarning IP'lariga yechiladi.

**Tuzoq: nginx nomni config yuklanganda yechadi.** nginx upstream nomini start (yoki config qayta o'qilgan) paytda bir marta IP'ga aylantiradi va o'sha IP'ni ishlataveradi. Upstream konteyner qayta yaratilsa (2-bo'lim: yangi konteyner, IP o'zgarishi mumkin) yoki scale qilinsa, nginx eski ro'yxat bilan qoladi: `502 Bad Gateway` yoki yangi nusxalar trafik olmaydi. Yechim yo'nalishlari: proxy'ni config'ni qayta o'qishga majburlash, bog'liqlik almashganda proxy'ni ham qayta ishga tushirish (3-bo'limdagi `depends_on` kalitlari), yoki Docker'ni o'zi kuzatadigan proxy (Traefik, Caddy). 16 va 17-vazifalarda sinaysiz.

### Real ishda qachon kerak

- Bitta domen ortida bir necha servis (`/` frontend, `/api` backend).
- Ilovani yangilaganda mijozlar manzili o'zgarmaydi, almashadigani faqat upstream.

### Nima uchun shunday

Ilovalarni to'g'ridan-to'g'ri internetga ochish har birida TLS, limit va loglashni takrorlashni talab qiladi; proxy bularni bir joyga yig'adi. Bazani publish qilmaslik hujum yuzasini kamaytiradi: tarmoqdan yetib bo'lmaydigan portni buzib bo'lmaydi. Compose'ning chegarasi ham shu yerda ko'rinadi: u bitta host'ni boshqaradi, host o'lsa hammasi o'ladi, uzilishsiz yangilash (rolling update) yo'q va proxy upstream o'zgarishini o'zi bilmaydi. Bu muammolarni orkestrator yechadi (5-dars).

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Compose fayl | kerakli servislar, tarmoqlar va volume'larni tavsiflovchi YAML (`compose.yaml`) |
| Servis | fayldagi bitta konteyner turi, undan bir yoki bir necha konteyner yaratiladi |
| Project | bitta compose fayldan yaratilgan resurslar to'plami, nomi resurslarga prefiks bo'ladi |
| Deklarativ | "qanday qilish" emas, "nima bo'lishi kerak" yoziladigan uslub |
| Reconcile | kerakli va haqiqiy holatni solishtirib farqni yo'qotish |
| Idempotent | necha marta bajarilsa ham natijasi bir xil amal |
| Orphan | project label'i bor, lekin faylda servisi yo'q konteyner |
| Default tarmoq | `networks:` yozilmaganda yaratiladigan `<project>_default` bridge |
| Healthcheck | konteyner ichida davriy ishlaydigan, tayyorlikni bildiruvchi buyruq |
| `depends_on` | servisning ishga tushish tartibi va shartini belgilovchi kalit |
| Interpolation | compose fayl matnidagi `${VAR}` ni host'dagi qiymatga almashtirish |
| `.env` | project papkasidagi, interpolation uchun o'qiladigan `KEY=value` fayl |
| `env_file` | ichidagi juftliklarni konteyner env'iga qo'shadigan servis kaliti |
| Secret | konteynerga `/run/secrets/<nom>` fayli sifatida beriladigan maxfiy qiymat |
| Profile | servisni faqat so'ralganda yoqadigan belgi |
| Override fayl | asos fayl ustiga birlashtiriladigan qo'shimcha compose fayl |
| Build context | `docker build` ga yuboriladigan papka |
| Watch | host'dagi fayl o'zgarishini konteynerga `sync` yoki `rebuild` bilan yetkazish |
| Reverse proxy | mijoz so'rovini ichki servisga uzatadigan oraliq server |
| Upstream | proxy so'rov yuboradigan ichki servis |
| `X-Forwarded-For` | proxy asl mijoz IP'sini yozadigan HTTP header |

## Tuzoqlar

- `down -v` bilan baza volume'ini o'chirish.
- `depends_on: [db]` ni "baza tayyor" deb o'ylash. Shartsiz shakl faqat startni kutadi.
- `.env` ni commit qilish, yoki `.env` dagi qiymat konteynerga o'zi tushadi deb o'ylash.
- `name:` yozmaslik: project nomi papka nomidan olinadi va boshqa loyiha bilan to'qnashadi.
- `image: postgres` (tag'siz): `pull` dan keyin major versiya o'zgaradi va eski ma'lumot papkasi bilan baza ko'tarilmaydi.
- `ports: "5432:5432"` bazani `0.0.0.0` ga, ya'ni tarmoqdagi hammaga ochadi. Kerak bo'lsa `127.0.0.1:` bilan, kerak bo'lmasa umuman yozmang.
- Dev uchun yozilgan faylni (bind mount, debug port, `build`) o'zgarishsiz production'ga olib chiqish.
- Kod o'zgargandan keyin `up -d` ni `--build` siz ishlatish, yoki `.env` o'zgargandan keyin `restart` qilish.
- `-f` bilan ko'tarilgan project'ni `-f` siz `down` qilish: Compose boshqa modelni ko'radi.
- `container_name` berish: scale ishlamaydi, ikki project to'qnashadi.
- Limit va log rotatsiyasi yo'q: bitta servis host'ni to'ldiradi (1-dars).
- macOS'da konteyner IP'siga host'dan `curl` qilish: ishlamaydi, publish qilingan port yoki `docker compose exec` ishlating.
- macOS'da ulashilmagan yo'ldan bind mount qilish: project'ni uy papkasida saqlang.

## Manbalar

- https://docs.docker.com/compose/ – Compose hujjatlari
- https://docs.docker.com/reference/compose-file/ – Compose file reference (majburiy: services, networks, volumes)
- https://docs.docker.com/compose/how-tos/startup-order/ – ishga tushish tartibi, `depends_on` shartlari
- https://docs.docker.com/compose/how-tos/environment-variables/ – env, `.env`, ustuvorlik, interpolation
- https://docs.docker.com/compose/how-tos/multiple-compose-files/ – merge, override, `include`, `extends`
- https://docs.docker.com/compose/how-tos/profiles/ – profiles
- https://docs.docker.com/compose/how-tos/use-secrets/ – Compose'da secrets
- https://docs.docker.com/compose/how-tos/file-watch/ – `compose watch`
- https://compose-spec.io/ – Compose Specification
- https://github.com/compose-spec/compose-spec – spetsifikatsiya matni
- https://nginx.org/en/docs/http/ngx_http_proxy_module.html – nginx `proxy_pass` va header'lar

## Birga bajaramiz

Vazifalardagidan boshqa stack'ni boshidan oxirigacha ko'taramiz: WordPress (PHP'da yozilgan sayt dvigateli, tayyor image) va uning bazasi MariaDB. Hamma narsa host'da, repo'dan tashqaridagi `~/l4-walk` papkasida, hech narsa commit qilinmaydi.

1. Papka, `.env` va fayl:

```
$ mkdir ~/l4-walk && cd ~/l4-walk
$ printf 'DB_PASSWORD=lab-only-pass\nWEB_PORT=8081\n' > .env
$ cat compose.yaml
name: l4-walk
services:
  web:
    image: wordpress:6
    ports:
      - "127.0.0.1:${WEB_PORT:-8081}:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wp
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      WORDPRESS_DB_NAME: wp
    depends_on:
      db:
        condition: service_healthy
  db:
    image: mariadb:11.4
    environment:
      MARIADB_DATABASE: wp
      MARIADB_USER: wp
      MARIADB_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      MARIADB_RANDOM_ROOT_PASSWORD: "1"
    volumes:
      - dbdata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 20s
volumes:
  dbdata:
```

`WORDPRESS_DB_HOST: db` servis nomi, IP emas. Baza porti publish qilinmagan. Parol faylda yo'q, `.env` dan interpolation bilan keladi va unutilsa `:?` xato beradi. `healthcheck.sh` MariaDB rasmiy image'i ichidagi tayyor tekshiruv skripti.

2. Ishga tushirmasdan modelni ko'ring:

```
$ docker compose config --services
db
web
$ docker compose config | grep -A5 'ports:'
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 80
        published: "8081"
        protocol: tcp
```

Qisqa `"127.0.0.1:8081:80"` yozuvi uzun shaklga yoyilgan: `target` konteyner porti, `published` host porti (`.env` dagi `WEB_PORT`). `docker compose config | grep PASSWORD` parolni ochiq ko'rsatadi: 4-bo'limdagi tuzoq.

3. Ko'taring:

```
$ docker compose up -d
 ✔ Network l4-walk_default   Created
 ✔ Volume "l4-walk_dbdata"   Created
 ✔ Container l4-walk-db-1    Healthy
 ✔ Container l4-walk-web-1   Started
```

Buyruq bir necha soniya `db` qatorida kutib turadi (`Waiting`): MariaDB birinchi marta ma'lumot papkasini yaratyapti. `Healthy` bo'lgachgina `web` start bo'ldi.

4. Nomlar, DNS va javob:

```
$ docker compose ps --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}'
NAME            SERVICE   STATUS
l4-walk-db-1    db        Up <N> seconds (healthy)
l4-walk-web-1   web       Up <N> seconds
$ docker compose exec web getent hosts db
<IP>      db
$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/
302
```

`getent hosts` nomni tizim resolver'i orqali yechadi: `db` Docker DNS'dan IP oldi. `302` WordPress'ning o'rnatish sahifasiga yo'naltirishi: u bazaga ulana oldi (ulanmaganida `500` bo'lardi).

5. Bitta servisni o'zgartiring: `.env` da `WEB_PORT=8082` qilib, qayta `up`:

```
$ docker compose up -d
 ✔ Container l4-walk-db-1    Healthy
 ✔ Container l4-walk-web-1   Started
$ docker compose ps --format 'table {{.Service}}\t{{.Ports}}'
SERVICE   PORTS
db        3306/tcp
web       127.0.0.1:8082->80/tcp
```

`web` ning modeli o'zgardi, u qayta yaratildi (chiqishda oraliq `Recreated` holati ko'rinadi); `db` ga tegilmadi, faqat sog'lomligi qayta tekshirildi. `docker compose restart web` portni o'zgartirmagan bo'lardi.

6. Bazaga belgi qo'ying va `down` ni sinang:

```
$ docker compose exec db mariadb -uwp -plab-only-pass wp -e 'CREATE TABLE marker (id INT); SHOW TABLES;'
+--------------+
| Tables_in_wp |
+--------------+
| marker       |
<...>
$ docker compose down
 ✔ Container l4-walk-web-1  Removed
 ✔ Container l4-walk-db-1   Removed
 ✔ Network l4-walk_default  Removed
$ docker volume ls --filter name=l4-walk
DRIVER    VOLUME NAME
local     l4-walk_dbdata
```

`down` teskari tartibda o'chirdi (avval `web`, keyin `db`), tarmoq ham ketdi, volume qoldi. `docker compose up -d` dan keyin o'sha `SHOW TABLES` yana `marker` ni ko'rsatadi: ma'lumot konteynerda emas, volume'da.

7. Tozalash va tekshirish:

```
$ docker compose down -v
 ✔ Container l4-walk-web-1  Removed
 ✔ Container l4-walk-db-1   Removed
 ✔ Volume l4-walk_dbdata    Removed
 ✔ Network l4-walk_default  Removed
$ docker compose ls -a
NAME      STATUS       CONFIG FILES
$ cd ~ && rm -r ~/l4-walk
```

`ls -a` da `l4-walk` yo'q (boshqa loyihalaringiz bo'lsa ular qoladi). Image'lar katta, kerak bo'lmasa `docker image rm wordpress:6 mariadb:11.4`.

Shu 7 qadamda ko'rganingiz: fayl, project nomi va yasalgan resurs nomlari (1-bo'lim), `config` bilan yakuniy model va `.env` interpolation'i (4-bo'lim), `service_healthy` kutishi (3-bo'lim), servis nomi bilan DNS (1-bo'lim), o'zgargan servisninggina qayta yaratilishi va `down` bilan `down -v` farqi (2-bo'lim), project ichidagi `ps`, `exec`, `ls` (6-bo'lim).

---

## Vazifalar

Ish papkasi: `docker/04-compose/` (`make new m=docker n=04 name=compose` bilan host'da yarating). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. `compose.yaml`, override fayllar, nginx config, `.env.example` va ilova kodi shu papkada (`stack/` ichida) saqlanadi va commit qilinadi; `.env` va secret fayllari commit qilinmaydi. Hamma buyruq host'da, ikkala mashinada bir xil; mashinaga bog'liq natijada (IP, fayl egasi, arxitektura) qaysi mashinada olinganini yozing. Har compose faylda `l4-` bilan boshlanadigan `name:` bo'lsin.

Ilova: 2-darsdagi Node yoki Go ilovangizni kengaytiring. `GET /` Redis'dagi hisoblagichni bittaga oshirib qiymatini va konteyner hostname'ini qaytaradi; `GET /visits` Postgres jadvalidagi yozuvlar sonini qaytaradi (har `/` so'rovi bitta qator qo'shadi); `GET /healthz` jarayon tirikligini bildiradi. Ulanish manzillari va parol env yoki fayldan o'qiladi. Start paytida jadval yo'q bo'lsa yaratiladi, ulanish xatosida ilova yiqilmay qayta urinadi.

### A. Asoslar

1. **First compose file.** Bitta `nginx:1.28-alpine` servisli `compose.yaml` yozing (`name:` bilan, port `127.0.0.1` da). `up -d` dan keyin `docker compose ps`, `docker ps`, `docker network ls`, `docker inspect` orqali konteyner, tarmoq nomlari va Compose qo'ygan label'larni (`com.docker.compose.*`) yozing. Compose konteyner qaysi project'ga tegishli ekanini qayerdan biladi? Yo'nalish: 1-bo'lim, "Mexanizm: nomlar va label'lar".

2. **Idempotent up.** `up -d` ni ikkinchi marta ishlating: nima chiqdi? Keyin faylda portni o'zgartirib yana `up -d`: konteyner ID'si va IP o'zgardimi? `docker compose restart` shu o'zgarishni qo'llaydimi? `up`, `restart`, `up --force-recreate` farqini jadvalga yozing. Yo'nalish: 2-bo'lim, "Mexanizm".

3. **Project name collision.** Bir xil nomli ikki papkada (`/tmp` ostida, masalan `a/demo` va `b/demo`) `name:` siz, har xil servis nomli compose fayl yarating va ikkalasini `up -d` qiling. Ikkinchi `up` dagi ogohlantirishni yozing va `docker compose ls` bilan izohlang. `name:` qo'shib tuzating, keyin ikkalasini `down` qiling. Yo'nalish: 1-bo'lim, "Tuzoq: bir xil nomli ikki papka bitta project".

4. **Service DNS.** Faylga ikkinchi servis (`alpine:3.22`, `sleep infinity`) qo'shing. Undan `wget -qO- http://<nginx-service-name>` va `nslookup` ni ishlating. Publish qilingan host porti bilan murojaat qilsangiz nima bo'ladi va nima uchun? Yo'nalish: 1-bo'lim, "Mexanizm: default tarmoq va servis nomi bilan DNS".

### B. Stack

5. **App and Postgres.** `app` (o'z `Dockerfile` ingizdan `build`) va `db` (`postgres:17-alpine`, named volume) servislarini yozing. `depends_on` ning qisqa shakli bilan `up` qiling va `app` loglaridagi ulanish xatolarini (yoki retry'larni) ko'rsating. Baza porti publish qilinmasin; `docker compose exec db psql` bilan jadvalni tekshiring. Yo'nalish: 3-bo'lim, "Mexanizm" va 6-bo'lim, "Build".

6. **Healthy dependency.** `db` ga `pg_isready` healthcheck, `app` ga `condition: service_healthy` qo'shing. `down` va `up -d` dan keyin `docker compose ps` da tartibni va `app` loglari endi toza ekanini ko'rsating. Healthcheck'ni ataylab buzing (noto'g'ri user yoki mavjud bo'lmagan buyruq): `up` nima deydi va qancha kutadi? Kutish vaqtini healthcheck maydonlaridan hisoblab tushuntiring. Yo'nalish: 3-bo'lim, healthcheck maydonlari.

7. **Redis and migrate job.** `redis:8-alpine` ni healthcheck (`redis-cli ping`) bilan qo'shing. Jadval yaratishni ilovadan alohida bir martalik `migrate` servisiga chiqaring (`psql` bilan SQL fayl) va `app` uni `service_completed_successfully` bilan kutsin. `docker compose ps -a` da `migrate` holati qanday? Migratsiya exit 1 bilan tugasa `app` nima bo'ladi? Yo'nalish: 3-bo'lim, `condition` jadvali va "Misol".

8. **nginx reverse proxy.** nginx servisini qo'shing: o'zingiz yozgan config (`:ro` bind mount), `app` ga `proxy_pass`, faqat nginx port publish qiladi (`127.0.0.1:8080`). Ikki tarmoq yarating: nginx ikkalasida, qolganlar faqat ichkisida. `curl` bilan `/` va `/visits` ni tekshiring; `app` loglarida mijoz IP'si qanday ko'rinadi va `X-Forwarded-For` nima beradi? Yo'nalish: 7-bo'lim, "Mexanizm".

9. **Persistence check.** Bir necha so'rov yuboring, keyin `docker compose down` va `up -d`: `/visits` soni saqlandimi, Redis hisoblagichi-chi? Nima uchun? Keyin `down -v` va `up -d` qilib yana tekshiring. Redis ma'lumotini saqlash kerak bo'lsa nima qo'shilishi kerak? Yo'nalish: 2-bo'lim, "To'xtatish va o'chirish".

### C. Konfiguratsiya

10. **Interpolation and .env.** Image tag'lari, host porti va baza nomini `${VAR:-default}` ga chiqaring, majburiy bittasini `${VAR:?...}` qiling. `.env` va `.env.example` yarating. `docker compose config` chiqishini uch holatda solishtiring: `.env` bilan, `.env` siz, shell'da `VAR=... docker compose config`. Ustuvorlik tartibini yozing. Yo'nalish: 4-bo'lim, "Mexanizm: tartib".

11. **env_file vs .env.** `.env` ga `FOO=1` yozing va `app` da hech qayerda ishlatmang: `docker compose exec app env | grep FOO` nima beradi? Keyin `env_file` orqali, so'ng `environment:` da boshqa qiymat bilan bering. Har holatda natijani yozing va ikki mexanizm farqini o'z so'zingiz bilan tushuntiring. Yo'nalish: 4-bo'lim, "Bu nima: ikki alohida mexanizm".

12. **Secrets.** Postgres parolini `environment` dan Compose secret'ga ko'chiring (`POSTGRES_PASSWORD_FILE`), ilovangiz ham parolni `/run/secrets/...` dan o'qisin. `docker compose config` va `docker inspect` da parol endi ko'rinmasligini, konteyner ichida fayl ruxsatlari va egasini ko'rsating (qaysi mashinada ekanini yozing, macOS'da egasi boshqacha ko'rinishi mumkin). Secret fayli `.gitignore` da ekanini tekshiring. Yo'nalish: 4-bo'lim, "Secrets".

13. **Profiles.** `debug` profile'iga bazani ko'rish uchun asbob servisini (`adminer` yoki `psql` li `alpine`) va `seed` profile'iga test ma'lumot yozadigan bir martalik servisni qo'shing. `up -d`, `--profile debug up -d`, `docker compose run --rm seed` holatlarida qaysi servislar ishga tushganini yozing. Yo'nalish: 5-bo'lim, "Profiles".

14. **Override files.** Dev sozlamalarini (`build`, manba kodi bind mount yoki `watch`, debug port) `compose.override.yaml` ga, production sozlamalarini (`image:` registry'dan, `restart: unless-stopped`, resurs limitlari, log rotatsiyasi, `read_only`) `compose.prod.yaml` ga ajrating. Ikkala kombinatsiya uchun `docker compose config` ni solishtiring. `ports` ni ikkala faylda yozib "qo'shiladi" tuzog'ini ko'rsating va `!override` bilan tuzating. Yo'nalish: 5-bo'lim, "Bir necha fayl va birlashish".

### D. Ish jarayoni

15. **Compose watch.** `app` uchun `develop.watch` yozing: manba kodi `sync` (yoki `sync+restart`), dependency manifesti `rebuild`. `docker compose watch` ni ishga tushirib ikkala turdagi faylni o'zgartiring va logda nima sodir bo'lganini yozing. Bind mount yondashuvidan farqi va afzalligi nimada? Yo'nalish: 6-bo'lim, "compose watch".

16. **Stale upstream.** `docker compose up -d --force-recreate app` qiling va darhol `curl` bilan nginx orqali so'rov yuboring. Nima bo'ldi? `app` ning eski va yangi IP'sini solishtiring (`docker inspect` bilan, ikkala mashinada ishlaydi), nginx error logini o'qing. Kamida ikki yechimni sinab ko'ring va qaysi birini tanlaganingizni asoslang. Yo'nalish: 7-bo'lim, "Tuzoq: nginx nomni config yuklanganda yechadi".

17. **Scale.** `docker compose up -d --scale app=3` qiling (to'sqinlik qilsa nimani olib tashlash kerakligini toping). nginx orqali 10 ta so'rov yuborib javobdagi hostname'larni sanang. Trafik barcha nusxalarga ketyaptimi? Ketmayotgan bo'lsa nima uchun va nima qilish kerak? `nslookup app` (boshqa konteynerdan) nima qaytaradi? Yo'nalish: 7-bo'lim, "Nusxalar".

18. **Logs and failure.** `docker compose logs -f --tail 20` ni ochiq qoldirib, boshqa terminalda `docker compose kill db` qiling. `app` va nginx qanday javob berdi (`/`, `/visits`, `/healthz`)? `docker compose start db` dan keyin ilova o'zi tiklandimi? `restart: unless-stopped` va `depends_on.restart: true` bu ssenariyda nimani o'zgartiradi? Yo'nalish: 3-bo'lim, "Tuzoq: `depends_on` faqat `up` paytida ishlaydi".

### E. Yakuniy

19. **Production-like stack.** Yakuniy holat: to'rt servis (nginx, app, db, redis) va migrate; barchasida healthcheck, limit, restart policy, log rotatsiyasi; non-root va `read_only` mumkin bo'lgan joyda; secret'lar fayldan; pinned image tag'lar; faqat nginx publish qilingan. `docker compose -f compose.yaml -f compose.prod.yaml up -d --wait` exit 0 bilan tugasin. `Makefile` yoki `README` da `up`, `down`, `logs`, `psql`, `backup` (3-darsdagi `pg_dump` usuli) buyruqlarini hujjatlashtiring. Yo'nalish: butun dars.

20. **Cleanup.** `docker compose down -v --remove-orphans --rmi local` qiling, `docker compose ls -a`, `docker ps -a`, `docker volume ls`, `docker network ls` da shu darsdan hech narsa qolmaganini va boshqa loyiha resurslari joyida ekanini ko'rsating. 3-vazifadagi `/tmp` papkalarini ham o'chiring. `image:` bilan o'z nomi berilgan build image'i `--rmi local` dan keyin qoldimi (`docker image ls`)? Qolgan bo'lsa nomi bilan o'chiring. Yo'nalish: 2-bo'lim, "To'xtatish va o'chirish".

### Topshirish

Tayyor bo'lgach:
1. `docker/04-compose/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida; `stack/` ichida `compose.yaml`, `compose.override.yaml`, `compose.prod.yaml`, nginx config, migratsiya SQL fayli, `.env.example` va ilova kodi (`Dockerfile` bilan).
2. `make check` toza (host'da; `yamllint` o'rnatilgan).
3. `docker compose config -q` (asosiy va prod kombinatsiyasi uchun) xatosiz.
4. `.env`, secret fayllari va dump'lar commit qilinmagan (`git status` va `make secrets` bilan tekshiring), `.env.example` bor.
5. Project resurslari tozalangan: `docker compose ls -a` da `l4-` yo'q, `docker volume ls` va `docker network ls` da ham.
6. Menga xabar bering, compose fayllar, nginx config va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Compose project nima va uning nomi qayerdan olinadi? Nom to'qnashsa nima bo'ladi?
- Compose o'z holatini qayerda saqlaydi va `docker compose ps` nima uchun faqat o'z konteynerlarini ko'rsatadi?
- Servislar bir-birini qanday topadi? Nima uchun ichki aloqa uchun `ports` kerak emas?
- `up -d` qaysi holatda konteynerni qayta yaratadi, qayta yaratilganda nima yo'qoladi va nima saqlanadi?
- `depends_on: [db]` va `condition: service_healthy` farqi nima? Nima uchun ilovada baribir retry kerak?
- `.env` fayli va `env_file:` kaliti qaysi ikki xil ishni bajaradi? `dotenv` dan farqi nima?
- Parolni env o'rniga secret fayl sifatida berish nimani yaxshilaydi va nimani yaxshilamaydi?
- `docker compose config` qachon kerak bo'ladi?
- Override fayllar qanday birlashadi? `ports` bilan qanday tuzoq bor?
- `up -d`, `restart`, `up -d --build` har biri nimani yangilaydi va nimani yangilamaydi?
- `down` va `down -v` farqi nima?
- `app` qayta yaratilganda nginx nima uchun 502 berishi mumkin?
- macOS'da konteyner IP'siga host'dan nima uchun yetib bo'lmaydi va bu darsda u qayerda ahamiyatga ega?
- Compose qaysi muammolarni yecha olmaydi (keyingi dars uchun)?
