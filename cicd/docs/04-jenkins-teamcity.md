# 4-dars: Jenkins va TeamCity

Maqsad: o'zingiz boshqaradigan (self-hosted) CI serverlarini noldan tushunish. 2-darsda (GitHub Actions) va 3-darsda (GitLab CI) server birovning zimmasida edi: siz faqat YAML yozdingiz, pipeline'ni rejalashtiradigan, log saqlaydigan, secret'larni shifrlaydigan dasturni GitHub va GitLab o'zi ishlatib turdi. Jenkins va TeamCity'da o'sha server ham sizniki: o'rnatish, yangilash, plugin'lar, zaxira, credential'lar va agent'lar sizning ishingiz. Boshqacha aytganda bu darsda siz platforma jamoasisiz, shuning uchun dars pipeline sintaksisi haqida qancha bo'lsa, serverni ekspluatatsiya qilish haqida ham shuncha. Ko'p korxonalarda (bank, telekom, yopiq tarmoq, eski mahsulotlar) aynan shular ishlaydi va DevOps muhandisi ularga qaraydi. Shu darsda 2-darsdagi pipeline'ni Jenkins'ga to'liq ko'chirasiz, TeamCity bilan yengilroq tanishasiz va "hosted CI nimani bepul berayotgan ekan" degan savolga amaliy javob olasiz. 5-darsdagi deploy GitHub Actions'da davom etadi.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun 1–2 bo'limlar, "Birga bajaramiz" va A guruh; ikkinchi kun 3-bo'lim va 5–8 vazifalar; uchinchi kun 5-bo'lim va 9–12 vazifalar; to'rtinchi kun 4 va 6-bo'limlar, 13–14 vazifalar; beshinchi kun 7-bo'lim va C guruh; oltinchi kun 8-bo'lim, 19-vazifa, tozalash va README. Diqqatni quyidagilarga qarating: controller va agent ajratilishi va nima uchun controller'da build qilinmaydi, butun holat `JENKINS_HOME` da yotishi va zaxira nima ekanligi, declarative `Jenkinsfile` tuzilishi, credential qanday bog'lanadi va qanday oqib chiqadi, plugin'lar ekspluatatsiya yuki sifatida, Configuration as Code g'oyasi, TeamCity'ning build configuration va build chain modeli. Vaqt yetmasa bu modulda birinchi qisqartiriladigan dars shu: u holda 1, 3, 4, 6, 7 va 8-bo'limlarni o'qing (ular amaliy qismsiz ham tushunarli yozilgan) va faqat 19-vazifani yozma bajaring.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Sizdagi versiya raqamlari, konteyner ID'lari, vaqtlar va UI'dagi ayrim tugma nomlari farq qiladi (Jenkins UI versiyadan versiyaga o'zgaradi), bu normal; darsda bunday joylar `<...>` bilan belgilangan. Image tag'lari, LTS versiya raqamlari va litsenziya limitlari tez eskiradi, shuning uchun dars ularni fakt sifatida aytmaydi, qayerdan tekshirishni ko'rsatadi.

## Laboratoriya

Hammasi host'dagi Docker konteynerlarida ishlaydi, ma'lumotlar named volume'larda (named volume bu Docker boshqaradigan, konteyner o'chirilganda ham qoladigan nomli saqlash joyi, docker 3-dars). Host'ga Java, Jenkins yoki TeamCity paketlari o'rnatilmaydi. `lab` VM bu darsda kerak emas.

| Nima | Qayerda ishlaydi | Manzil yoki nom |
|------|------------------|-----------------|
| Jenkins controller | host'dagi konteyner | `http://localhost:8080`, volume `jenkins-data` |
| Pipeline uchun Docker engine | `docker:dind` konteyneri, `jenkins` tarmog'ida | volume `jenkins-docker-certs` |
| TeamCity server va agent | host'dagi ikki konteyner, `teamcity` tarmog'ida | `http://localhost:8111`, volume'lar `teamcity-*` |
| Kod manbai | GitHub'dagi public `cicd-demo` (2-darsda yaratilgan) | `Jenkinsfile` shu repoda |
| Javoblar | bu o'quv repozitoriysi | `cicd/04-jenkins-teamcity/` |

- **Portlar faqat `127.0.0.1` ga bog'lanadi**: `-p 127.0.0.1:8080:8080`. `-p 8080:8080` deb yozilsa port mashinaning barcha tarmoq interfeyslarida ochiladi va CI serveringiz (ichida token'lar bilan) ofis yoki uy tarmog'idagi har kimga ko'rinadi. `localhost` dagi publish qilingan port Zorin'da ham, Docker Desktop'da ham bir xil ishlaydi.
- **Xotira**: ikkita server va agent'lar birga har ikki mashina uchun og'ir. Avval Jenkins qismini tugating, uning konteynerlarini to'xtating (`docker stop`), keyin TeamCity'ni ko'taring. Docker'ga qancha xotira ko'rinishini tekshirish: `docker info` chiqishidagi `Total Memory` qatori. Har ikki serverning joriy minimal talablari rasmiy hujjatda (Manbalar), raqamlar versiyaga qarab o'zgaradi.
- **Webhook yo'q**: webhook bu GitHub push bo'lganda CI serverning URL'iga yuboradigan HTTP so'rov. Server `localhost` da, GitHub esa internetda, u sizning `localhost` ingizga yeta olmaydi. Shuning uchun trigger sifatida polling (server repo'ni o'zi davriy so'raydi) yoki qo'lda ishga tushirish ishlatiladi. Bu laboratoriya cheklovi, production'da webhook ishlatiladi.
- **GHCR token**: bu yerda `GITHUB_TOKEN` (2-dars) yo'q, chunki u faqat GitHub Actions run'i ichida mavjud. GHCR'ga push uchun classic PAT (personal access token) yaratasiz: faqat `write:packages` huquqi (token yaratish sahifasida `repo` huquqi qo'shilib qolmaganini tekshiring), eng qisqa amal muddati. Token faqat Jenkins credential omborida turadi: `Jenkinsfile` ga, repo'ga, README'ga va shell tarixiga yozilmaydi. Dars oxirida GitHub'da bekor qilinadi (revoke).
- **Tozalash** har doim aniq nom bilan: `docker rm -f <konteyner>`, `docker volume rm <volume>`, `docker network rm <tarmoq>`. `docker system prune` va `docker volume prune -a` ishlatilmaydi, chunki ular boshqa darslardan qolgan narsalarni ham o'chiradi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Image'lar `linux/amd64`. Docker Engine host kernel'ida ishlaydi, konteynerlar host RAM'ini to'g'ridan ishlatadi (`Total Memory` host xotirasiga teng). Volume'lar host'ning `/var/lib/docker/volumes` papkasida. `/var/run/docker.sock` host engine'iga tegishli, egasi `root`, guruhi `docker`. Pipeline qurgan image `linux/amd64`. |
| macOS (uy) | Image'lar `linux/arm64`. Docker Desktop'ning yashirin Linux VM'i ichida ishlaydi, `Total Memory` shu VM'ga berilgan limit (Docker Desktop → Settings → Resources), Mac'ning butun RAM'i emas. Volume'lar VM ichida, Finder'da ko'rinmaydi. `/var/run/docker.sock` VM'dagi engine'ga olib boradi, konteyner ichidan ko'rinadigan egasi va guruhi Zorin'dagidan farq qiladi. Pipeline qurgan image `linux/arm64` (docker 2-dars). `jenkins/jenkins` LTS image'lari `amd64` va `arm64` uchun chiqadi; TeamCity image'lari uchun pull'dan oldin platformani tekshiring (7-bo'lim). |

Volume ichini ko'rish ikkala mashinada bir xil usulda: `docker exec <konteyner> ls <yo'l>` yoki `docker run --rm -v <volume>:/data alpine:3.20 ls /data`. Host'ning `/var/lib/docker` papkasiga tayanmang, Mac'da u yo'q.

**Ikkinchi mashinada nimani takrorlash kerak.** Jenkins va TeamCity holati bitta mashinadagi named volume'da yashaydi va git bilan ko'chmaydi. Ikki yo'l bor. Birinchisi: har asbobning vazifalarini bitta mashinada boshlab o'sha yerda tugatish (masalan Jenkins ofisda, TeamCity uyda). Ikkinchisi: ikkinchi mashinada serverni vazifalar yaratadigan fayllardan qayta qurish: `Dockerfile` va `plugins.txt` (3-vazifa), `Jenkinsfile` (`cicd-demo` da), `jenkins.yaml` (13-vazifa). Credential'ni qayta kiritasiz, build tarixi ko'chmaydi. Ikkinchi yo'lning og'riqli yoki oson bo'lishi aynan "configuration as code" ning foydasini ko'rsatadi: 13-vazifagacha qo'lda bosib sozlangan server ko'chmaydi, undan keyin esa bir necha buyruq bilan tiklanadi.

---

## 1. Jenkins arxitekturasi: controller, agent, executor

### Bu nima

Jenkins bu Java'da yozilgan open-source avtomatlashtirish serveri. CI serveri deganda uzluksiz ishlab turadigan, repo'dagi o'zgarishni ko'rib pipeline'ni (1-dars: stage, job, step) ishga tushiradigan, natija va loglarni saqlaydigan dastur tushuniladi. Jenkins yadrosi kichik: Git bilan ishlash, pipeline tili, credential'lar, Docker, deyarli hamma funksiya plugin (yadroga qo'shiladigan kengaytma) orqali keladi.

2–3-darslarda bu dasturni ko'rmagansiz, chunki u github.com va gitlab.com ichida edi. Self-hosted runner (2-darsning oxiri, 3-darsdagi GitLab Runner) da siz faqat ijrochi qismni o'zingiz ishlatgansiz. Endi rejalashtiruvchi qism ham sizda.

### Mexanizm: controller va agent

| Qism | Vazifasi |
|------|----------|
| Controller | UI, konfiguratsiya, job'larni rejalashtirish, build navbati, build tarixi, credential'lar. Bitta JVM jarayoni (JVM bu Java dasturlarini bajaradigan virtual mashina, Node dasturi uchun `node` jarayoni qanday bo'lsa shunday) |
| Agent | build qadamlarini (`sh`, `docker build`) bajaradigan mashina yoki konteyner. Unda kichik Java dasturi (`agent.jar`) ishlaydi va controller'dan buyruq oladi. GitHub Actions'dagi runner'ning o'xshashi |
| Executor | agent'dagi parallel build uyasi. Agent'da 3 executor bo'lsa, unda bir vaqtda 3 build ishlay oladi |
| Node | controller yoki agent uchun umumiy nom. Controller'ning o'zi "built-in node" deb ataladi va unda ham executor bo'lishi mumkin |
| Label | agent'ga yopishtiriladigan belgi (`linux`, `docker`, `arm64`). Pipeline "menga `docker` label'li agent kerak" deydi. `runs-on` dagi label'lar bilan bir xil g'oya |
| Build queue | bo'sh executor kutayotgan build'lar navbati |

Build ishga tushganda zanjir shunday: trigger (qo'lda, polling, webhook) → controller build'ni navbatga qo'yadi → talabga (label) mos va bo'sh executor'i bor node topiladi → controller o'sha agent'ga qadamlarni yuboradi → agent buyruqlarni o'z diskidagi **workspace** papkasida (build uchun ajratilgan ish papkasi, repo shu yerga klonlanadi) bajaradi → chiqish oqimi (log) controller'ga uzatiladi va controller uni saqlaydi. Pipeline'ning Groovy kodi controller'da bajariladi, faqat `sh` kabi qadamlar agent'ga jo'natiladi. Shu sababli og'ir hisob-kitobni Groovy'da yozish controller'ni sekinlashtiradi.

Agent controller'ga ikki usulda ulanadi. **SSH**: controller agent mashinasiga SSH (linux 8-dars) orqali kiradi va `agent.jar` ni o'zi ishga tushiradi. **Inbound**: agent o'zi controller'ga ulanadi, TCP port orqali (image'da 50000) yoki WebSocket orqali (UI bilan bir xil HTTP portda). Inbound usul agent firewall ortida turganda kerak. Uchinchi tur dinamik agent'lar: Docker, Kubernetes yoki cloud plugin'lari har build uchun yangi agent yaratadi va tugagach yo'q qiladi, bu hosted runner'larga eng yaqin model.

### `JENKINS_HOME`: holat qayerda

Jenkins'da ma'lumotlar bazasi yo'q. Butun holat bitta papkada, `JENKINS_HOME` da (rasmiy image'da `/var/jenkins_home`), oddiy fayllar ko'rinishida:

| Nima | Qanday saqlanadi |
|------|------------------|
| Server konfiguratsiyasi | XML fayllar (ildizda) |
| Job ta'riflari va build tarixi | `jobs/` ostida, har job o'z papkasida: ta'rif, har build'ning logi va natijasi |
| Plugin'lar | `plugins/` ostida, har plugin bitta arxiv fayl (`.jpi`) |
| Foydalanuvchilar | `users/` ostida |
| Credential'lar | shifrlangan holda XML ichida |
| Shifrlash kalitlari | `secrets/` ostida |
| Workspace'lar | `workspace/` ostida (controller'da build qilinsa) |

Bundan uchta amaliy xulosa chiqadi. Birinchisi: zaxira (backup) bu `JENKINS_HOME` ning nusxasi, boshqa narsa emas. Ikkinchisi: shifrlangan credential'lar va ularni ochadigan kalit bir papkada, shuning uchun zaxira fayli secret hisoblanadi (5-bo'lim). Uchinchisi: konteyner o'chirilsa, lekin `/var/jenkins_home` named volume'da bo'lsa, hech narsa yo'qolmaydi; volume'siz ishga tushirilgan Jenkins esa `docker rm` bilan birga butun sozlamani yo'qotadi.

### Misol: controller bitta jarayon, build esa uning bolasi

Ishlab turgan Jenkins konteynerining jarayonlarini host'dan ko'ramiz (`docker top` ikkala mashinada ishlaydi; konteynerni ko'tarish 2-bo'limda):

```
$ docker top jenkins-walk
UID    PID     PPID    ...  CMD
1000   <PID1>  <N>     ...  /usr/bin/tini -- /usr/local/bin/jenkins.sh
1000   <PID2>  <PID1>  ...  java -Duser.home=/var/jenkins_home ... -jar /usr/share/jenkins/jenkins.war
```

Birinchi qator `tini`: konteynerda PID 1 bo'lib ishlaydigan kichik init dasturi (linux 1-dars: PID 1), u signallarni uzatadi va yetim jarayonlarni yig'adi. Ikkinchi qator controller'ning o'zi: bitta `java` jarayoni, `jenkins.war` (Jenkins'ning butun kodi joylashgan arxiv) ni bajaradi. `UID` ustunidagi `1000` image ichidagi `jenkins` foydalanuvchisi (Mac'da bu ustunda ism yoki boshqa ko'rinish chiqishi mumkin, chunki `docker top` VM ichidagi `ps` ni chaqiradi). Agar shu paytda built-in node'da `sh 'sleep 60'` qadami bor build ishlayotgan bo'lsa, ro'yxatda yana bir nechta qator paydo bo'ladi: `sh` va `sleep 60`, ularning `UID` si ham `1000` va ular `java` jarayonining avlodi. Ya'ni controller'da bajarilgan build controller bilan bir xil foydalanuvchi ostida, bir xil fayl tizimida ishlaydi.

### Tuzoq: controller'da build qilish

Yuqoridagi misoldan to'g'ridan kelib chiqadi: build controller bilan bir xil foydalanuvchi ostida ishlasa, `Jenkinsfile` yoza oladigan har kim `sh 'cat ...'` bilan `JENKINS_HOME` dagi istalgan faylni, jumladan shifrlash kalitlari va credential'larni o'qiy oladi va server konfiguratsiyasini o'zgartira oladi. Production qoidasi: built-in node'da executor soni 0, barcha build'lar agent'larda. Laboratoriyada soddalik uchun bu qoidani buzamiz (alohida agent ko'tarmaymiz) va buni bilib turamiz.

### Real ishda qachon kerak

- "Build navbatda turibdi, ishlamayapti" degan shikoyat: avval executor'lar bandmi, keyin pipeline so'ragan label'li agent bormi va online'mi, deb qaraladi.
- Yangi turdagi build (masalan `arm64` yoki GPU) qo'shilganda controller o'zgarmaydi, yangi label'li agent ulanadi.
- Jenkins'ni ko'chirish yoki tiklash: `JENKINS_HOME` ni ko'chirish demakdir.
- Xavfsizlik auditi: birinchi savol "controller'da executor bormi".

### Nima uchun shunday

Jenkins 2004-yilda Sun Microsystems'da Kohsuke Kawaguchi boshlagan Hudson loyihasidan chiqqan, 2011-yilda Oracle bilan nizodan keyin Jenkins nomi bilan ajralgan. O'sha davrda CI serveri bitta mashinadagi bitta dastur edi, holatni fayllarda saqlash eng sodda yo'l bo'lgan: bazasiz o'rnatiladi, zaxirasi `cp`. Narxi: fayl tizimiga tayangan bitta controller'ni gorizontal ko'paytirib bo'lmaydi, open-source Jenkins'da controller yagona nosozlik nuqtasi. Controller va agent ajratilishi ikki sababdan: masshtab (build'lar ko'p mashinaga tarqaladi, controller yengil qoladi) va xavfsizlik (ishonchsiz kod sir saqlanadigan joydan uzoqda ishlaydi). Muqobil dizayn GitLab'da: holat PostgreSQL'da, runner'lar har doim alohida dastur, controller'da build qilish imkoniyatining o'zi yo'q.

## 2. Jenkins'ni Docker'da ishga tushirish

### Eng sodda ishga tushirish

Rasmiy image `jenkins/jenkins`. Tag'lar ikki liniyada chiqadi: haftalik relizlar va **LTS** (Long-Term Support: bir necha oyda bir tanlanadigan, faqat tuzatishlar oladigan barqaror liniya). Server uchun LTS olinadi. Darsda `jenkins/jenkins:lts-jdk21` tag'i ishlatiladi; joriy tavsiya etilgan tag va Java versiyasini image'ning Docker Hub sahifasidan yoki rasmiy o'rnatish qo'llanmasidan (Manbalar) tekshiring. Production'da `lts` kabi siljiydigan tag emas, aniq versiya raqami yoziladi (docker 2-dars: tag va digest).

```
docker run -d --name jenkins -p 127.0.0.1:8080:8080 \
  -v jenkins-data:/var/jenkins_home jenkins/jenkins:lts-jdk21
```

`-d` fonda; `--name jenkins` konteyner nomi; `-p 127.0.0.1:8080:8080` UI portini faqat host'ning loopback interfeysiga chiqaradi; `-v jenkins-data:/var/jenkins_home` named volume'ni `JENKINS_HOME` ga ulaydi (volume yo'q bo'lsa Docker o'zi yaratadi). Image 50000-portni ham e'lon qiladi (inbound agent'lar uchun), lekin laboratoriyada tashqi agent yo'q, shuning uchun u publish qilinmaydi.

Birinchi ishga tushishda Jenkins bo'sh `JENKINS_HOME` ni to'ldiradi, tasodifiy parolli vaqtinchalik admin yaratadi va parolni ham logga, ham faylga yozadi:

```
$ docker logs jenkins 2>&1 | grep -A 5 'initial setup is required'
Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

<32 ta hex belgi>

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
$ docker logs jenkins 2>&1 | grep 'fully up'
<sana vaqt> [id=<N>]	INFO	hudson.lifecycle.Lifecycle#onReady: Jenkins is fully up and running
```

Birinchi buyruqdagi `2>&1` kerak, chunki Jenkins logni stderr'ga yozadi (linux 5-dars: oqimlar). Parol qatori 32 belgili satr; oxirgi qator shu parol diskdagi qaysi faylda ekanini aytadi, uni `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword` bilan ham olish mumkin. `Jenkins is fully up and running` qatori chiqmaguncha UI "Please wait while Jenkins is getting ready to work" sahifasini ko'rsatadi; Mac'da birinchi start Zorin'dagidan sekinroq yoki tezroq bo'lishi mumkin, qatorni kuting.

### Setup wizard

`http://localhost:8080` ochilganda setup wizard (birinchi sozlash ustasi) uch qadamdan o'tkazadi: "Unlock Jenkins" (yuqoridagi parol: bu konteynerga kira oladigan odamgina serverni egallashini kafolatlaydi), plugin'lar tanlovi ("Install suggested plugins" pipeline, Git, credential'lar va boshqalarni o'rnatadi, bu bir necha daqiqa oladi va internet kerak), birinchi admin foydalanuvchini yaratish. Wizard tugagach vaqtinchalik parol kerak bo'lmaydi. Bu qadamlarning hammasi qo'lda bosiladi; 6-bo'limda xuddi shu natijaga fayl orqali, hech narsa bosmasdan erishiladi.

### Pipeline'ga Docker engine kerak: ikki yo'l

Pipeline image qurishi (`docker build`) yoki qadamni konteyner ichida bajarishi uchun ikki narsa kerak: Jenkins konteyneri ichida `docker` CLI (buyruq qatori dasturi) va u gaplashadigan Docker daemon (engine, konteynerlarni haqiqatda yaratadigan servis; docker 1-dars: client va daemon). Rasmiy `jenkins/jenkins` image'ida ikkalasi ham yo'q. CLI'ni o'z image'ingizga o'rnatasiz, daemon uchun esa ikki variant bor:

| | Host socket'ini ulash | `docker:dind` yon konteyneri |
|---|----------------------|------------------------------|
| Qanday | `-v /var/run/docker.sock:/var/run/docker.sock` | alohida privileged konteynerda ikkinchi daemon, Jenkins unga tarmoq orqali TLS bilan ulanadi |
| Pipeline kimga buyruq beradi | host'dagi (Mac'da Docker Desktop VM'idagi) engine'ga | faqat dind ichidagi engine'ga |
| Xavf | socket'ga yoza olgan jarayon host'da root bilan teng: istalgan papkani mount qilib konteyner ochadi, boshqa konteynerlaringizni ko'radi va o'chiradi | privileged konteyner ham kuchli huquq, lekin pipeline host engine'ini, sizning boshqa konteyner va image'laringizni ko'rmaydi |
| Ruxsat muammosi | image ichidagi `jenkins` foydalanuvchisi socket faylining guruhida bo'lishi kerak; Zorin'da bu host'dagi `docker` guruhining GID raqami, Docker Desktop'da socket egasi va guruhi boshqacha ko'rinadi | yo'q: ulanish fayl ruxsati bilan emas, TLS sertifikati bilan |
| Qurilgan image qayerda | host'ning `docker images` ro'yxatida | dind ichida, host'da ko'rinmaydi |

Laboratoriyada **dind** ishlatiladi, ikki sababdan: u ikkala mashinada bir xil ishlaydi (host socket'ining egasi va GID'iga bog'liq emas, uni konteyner ichidan `ls -ln /var/run/docker.sock` bilan o'zingiz solishtirib ko'rishingiz mumkin), va rasmiy Jenkins qo'llanmasi aynan shu sxemani beradi. Bu 3-darsdagi dind bilan bir xil kelishuv: privileged konteyner laboratoriya uchun maqbul, production'da esa build'lar alohida, bir martalik agent mashinalarida bajariladi.

Ikkala variantda ham bitta qoida amal qiladi (docker 3-dars): `-v /yo'l:/yo'l` dagi chap tomon CLI turgan joydan emas, **daemon turgan joydan** qidiriladi. Masalan A konteyneridagi CLI boshqa joydagi daemon'dan `-v /data/report:/out` bilan konteyner so'rasa, daemon `/data/report` ni o'z fayl tizimidan oladi; A konteyneridagi `/data/report` ga uning aloqasi yo'q, daemon tomonda bunday papka bo'lmasa bo'sh papka yaratiladi va ichida fayllar "yo'qolgan" bo'lib ko'rinadi. Jenkins workspace'ni build konteyneriga aynan shunday yo'l bilan ulaydi, 3-vazifadagi savolga javob shu qoidadan chiqadi.

### dind sxemasining qismlari

Sxema to'rt qismdan iborat, aniq buyruqlar rasmiy qo'llanmada (Manbalar). Buyruqlarni o'sha yerdan oling, lekin har flag nima uchun turganini quyidagi jadvaldan tushunib oling:

| Qism | Nima uchun |
|------|-----------|
| `docker network create jenkins` | user-defined tarmoq: undagi konteynerlar bir-birini nom bilan topadi (docker 3-dars: ichki DNS) |
| dind konteynerida `--privileged` | konteyner ichida daemon ishlashi uchun kernel imkoniyatlariga keng ruxsat kerak |
| `--network jenkins --network-alias docker` | dind shu tarmoqda `docker` nomi bilan ko'rinadi |
| `--env DOCKER_TLS_CERTDIR=/certs` va `jenkins-docker-certs` volume'i | dind start paytida TLS sertifikatlarini generatsiya qiladi; client sertifikatlari volume orqali Jenkins konteyneriga beriladi |
| Jenkins'da `DOCKER_HOST=tcp://docker:2376`, `DOCKER_CERT_PATH=/certs/client`, `DOCKER_TLS_VERIFY=1` | CLI lokal socket'ga emas, `docker` nomli host'ning 2376-portiga (TLS) ulanadi va shu sertifikatlarni ishlatadi |
| `jenkins-data` volume'i ikkala konteynerda | sababini 3-vazifada o'zingiz izohlaysiz (yuqoridagi "daemon turgan joy" qoidasi) |

Qo'llanmadagi dind buyrug'i `-p 2376:2376` bilan daemon portini host'ga ham chiqaradi. Laboratoriyada bu shart emas (Jenkins unga ichki tarmoq orqali ulanadi); chiqarsangiz `127.0.0.1` ga bog'lang. Qo'llanmadagi nomlarda `blueocean` so'zi uchraydi: bu eski UI plugin'ining nomi, tarixiy qoldiq.

Tekshirish g'oyasi: `docker version` ikki bo'lim chiqaradi, `Client:` (CLI o'zi haqida) va `Server:` (ulangan daemon haqida). Daemon'ga yeta olmagan CLI faqat `Client:` bo'limini va xato qatorini chiqaradi. Shu bilan "CLI bor, lekin engine'ga ulanmagan" holati ajratiladi.

### O'z image'ingiz: CLI va plugin'lar image ichida

Rasmiy image ustiga ikki narsa qo'shiladi. Mexanizmni ko'rsatadigan qisqa parcha (to'liq fayl emas):

```dockerfile
FROM jenkins/jenkins:lts-jdk21
USER root
# install the docker CLI package from Docker's apt repository (steps: official guide)
USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
```

`USER root` paket o'rnatish uchun, keyin albatta `USER jenkins` ga qaytiladi (image root bilan ishlamasligi kerak, docker 2-dars). `jenkins-plugin-cli` image tarkibidagi asbob: ro'yxatdagi plugin'larni va ularning bog'liqliklarini yuklab `/usr/share/jenkins/ref/plugins` ga qo'yadi, konteyner start bo'lganda ular `JENKINS_HOME/plugins` ga ko'chiriladi. `plugins.txt` har qatorda `nom:versiya` (masalan `git:<versiya>`) saqlaydi. Docker CLI'ni o'rnatadigan apt qadamlari vaqt o'tishi bilan o'zgaradi, shuning uchun dars ularni yozmaydi, rasmiy qo'llanmadan olinadi.

### Real ishda qachon kerak

- Jenkins'ni yangilash: image tag'ini o'zgartirib konteynerni qayta yaratish, `JENKINS_HOME` volume'i joyida qoladi. Oldin zaxira olinadi, chunki yangi versiya fayllarni yangi formatga o'tkazishi mumkin va orqaga qaytish har doim ham ishlamaydi.
- "Pipeline'da `docker: not found`" yoki "Cannot connect to the Docker daemon" xatolari: birinchisi CLI yo'qligi, ikkinchisi daemon'ga yo'l yo'qligi.
- Xavfsizlik ko'rigi: controller'ga host socket'i ulanganmi, UI qaysi interfeysda tinglayapti.

### Nima uchun shunday

Jenkins image'ida Docker yo'qligi ataylab: image bitta ish qiladi, build asboblari esa agent'larning ishi. Vaqtinchalik parol va "Unlock" qadami 2016-yilda Jenkins 2 bilan kelgan; undan oldin yangi o'rnatilgan Jenkins autentifikatsiyasiz ochiq turar va internetda minglab himoyasiz serverlar bo'lgan. Plugin'larni image ichiga qotirish (UI'dan o'rnatish o'rniga) `package-lock.json` bilan bir xil sababga ega: bugun va olti oydan keyin qurilgan server bir xil plugin versiyalariga ega bo'ladi.

## 3. Jenkinsfile: declarative pipeline

### Declarative va scripted

Pipeline ta'rifi repo ildizidagi `Jenkinsfile` da yoziladi (pipeline as code, 1-dars). Til Groovy (JVM'da ishlaydigan skript tili) asosidagi DSL. Ikki sintaksis bor. **Declarative**: qat'iy tuzilma, hammasi `pipeline { }` bloki ichida, Jenkins faylni ishga tushirishdan oldin tekshiradi; yangi ish uchun shu tavsiya qilinadi. **Scripted**: erkin Groovy, `node { stage('x') { sh '...' } }` ko'rinishida, `if`, sikl va `try/catch` bilan; eski serverlarda va murakkab holatlarda uchraydi. Bu darsda faqat declarative yoziladi.

### Misol: boshqa loyiha uchun to'liq fayl

Go'dagi kichik servis uchun (sizning `cicd-demo` uchun emas, uni 5-vazifada o'zingiz yozasiz):

```groovy
pipeline {
  agent any
  options { timeout(time: 15, unit: 'MINUTES') }
  environment { CGO_ENABLED = '0' }
  stages {
    stage('Vet') {
      steps { sh 'go vet ./...' }
    }
    stage('Package') {
      when { expression { env.GIT_BRANCH == 'origin/main' } }
      steps {
        sh 'go build -o dist/api ./cmd/api'
        archiveArtifacts artifacts: 'dist/api'
      }
    }
  }
  post {
    failure { echo 'pipeline failed' }
    cleanup { echo 'runs last, in every case' }
  }
}
```

Console output'da (build sahifasi → Console Output) ko'rinadigan skelet:

```
[Pipeline] Start of Pipeline
[Pipeline] node
Running on <node nomi> in /var/jenkins_home/workspace/<job nomi>
[Pipeline] {
[Pipeline] stage
[Pipeline] { (Vet)
[Pipeline] sh
+ go vet ./...
[Pipeline] }
[Pipeline] // stage
...
[Pipeline] End of Pipeline
Finished: SUCCESS
```

`[Pipeline]` bilan boshlangan qatorlar Jenkins'ning o'zi: qaysi qadam boshlandi va tugadi. `node` executor ajratilganini bildiradi, keyingi qator qaysi node va qaysi workspace papkasi ekanini aytadi. `{ (Vet)` stage boshlanishi. `+ go vet ./...` shell'ning o'zi chiqargan qator: `sh` qadami skriptni `-xe` rejimida ishlatadi, `-x` har buyruqni `+` bilan chop etadi, `-e` birinchi xatoda to'xtatadi (linux 5-dars). Oxirgi qator build natijasi: `SUCCESS`, `FAILURE`, `UNSTABLE` (build o'tdi, lekin masalan testlar yiqildi deb e'lon qilingan) yoki `ABORTED`. Stage'lar bo'yicha rangli jadval build yoki job sahifasida: plugin to'plamiga qarab u Stage View yoki Pipeline Graph View deb ataladi.

### Bloklar

| Blok | Vazifasi | GitHub Actions'dagi o'xshashi |
|------|----------|-------------------------------|
| `agent` | qayerda ishlaydi: `any`, `none`, `{ label 'x' }`, `{ docker { ... } }` | `runs-on`, `container` |
| `stages` / `stage` | ketma-ket bosqichlar | job'lar + `needs` |
| `steps` | qadamlar: `sh`, `echo`, `checkout`, plugin qadamlari | `steps` |
| `environment` | env variable'lar, `credentials()` bilan secret | `env`, `secrets` |
| `when` | stage sharti: `branch`, `expression`, `changeset` | `if` |
| `parallel` | stage ichida bir vaqtda ishlaydigan ichki stage'lar | parallel job'lar |
| `post` | yakuniy amallar: `always`, `success`, `failure`, `unstable`, `cleanup` | `if: always()`, `failure()` |
| `options` | `timeout`, `retry`, `disableConcurrentBuilds()`, `buildDiscarder(...)`, `skipDefaultCheckout()` | `timeout-minutes`, `concurrency` |
| `triggers` | `pollSCM`, `cron` | `on` |
| `input` | odam tasdig'ini kutish | environment approval |

- `parallel` ichida oddiy `stage` lar yoziladi: `stage('Checks') { parallel { stage('A') { ... } stage('B') { ... } } }`.
- Fayl saqlash: `archiveArtifacts artifacts: 'dist/**'` (controller'da build bilan birga saqlanadi). Test hisoboti: JUnit plugin'ining `junit` qadami XML fayllarni o'qib build'ga Test Result sahifasini qo'shadi.
- Tayyor env variable'lar: `BUILD_NUMBER`, `GIT_COMMIT`, `WORKSPACE`, `BRANCH_NAME` (faqat multibranch job'da).
- Sintaksis yordamchilari UI'da: job sahifasidagi "Pipeline Syntax" (snippet generator, qadamni formadan to'ldirib kodini beradi) va build sahifasidagi "Replay" (oxirgi build'ni o'zgartirilgan `Jenkinsfile` bilan commit'siz qayta ishlatish).

### `agent` qayerda e'lon qilinadi: workspace va executor

Yuqori darajadagi `agent any` butun pipeline uchun **bitta executor va bitta workspace** oladi va oxirigacha ushlab turadi. Shuning uchun fayllar stage'lar orasida o'z-o'zidan saqlanadi: `Vet` da yaratilgan fayl `Package` da turibdi. Bu GitHub/GitLab'dagi job izolyatsiyasidan farq qiladi (u yerda har job yangi mashina). Yuqorida `agent none` yozib har stage'ga o'z `agent` i berilsa, har stage boshqa node'ga va boshqa workspace'ga tushishi mumkin, fayllar `stash name: 'site', includes: 'public/**'` va keyingi stage'da `unstash 'site'` bilan uzatiladi. Umumiy qoida: executor `agent` bloki qamragan butun vaqt davomida band, ichidagi qadam ishlayaptimi yoki shunchaki kutib turibdimi, farqi yo'q.

### Jenkinsfile job'ga qanday aylanadi

Repo'dagi fayl o'zi ishga tushmaydi, Jenkins'da unga ko'rsatadigan job bo'lishi kerak:

- **Pipeline job, "Pipeline script"**: kod UI'dagi matn maydoniga yoziladi. Tajriba uchun, kod repo'da emas.
- **Pipeline job, "Pipeline script from SCM"** (SCM bu source control, ya'ni Git): job repo URL'i, branch va fayl yo'lini (`Jenkinsfile`) saqlaydi. Har build'da controller avval shu faylni repo'dan o'qiydi, keyin agent workspace'ga kodni o'zi checkout qiladi (declarative'da bu avtomatik, `skipDefaultCheckout()` bilan o'chiriladi).
- **Multibranch Pipeline**: repo'ni skanerlaydi va `Jenkinsfile` bor har branch (va PR) uchun avtomatik ichki job yaratadi, branch o'chsa job ham ketadi. Zamonaviy standart.
- **Freestyle**: UI'da tugmalar bilan sozlanadigan eski job turi. Pipeline as code emas, eski serverlarda ko'p uchraydi.

Trigger'lar ham faylda: `triggers { cron('H 2 * * 1-5') }` ish kunlari soat 2 larda ishga tushiradi. Beshta maydon oddiy cron (linux 9-dars), `H` esa Jenkins qo'shimchasi: "shu oraliqdan job nomi bo'yicha hisoblangan, har doim bir xil qiymat", shunda yuzlab job bir daqiqada birdan boshlanmaydi. `pollSCM` xuddi shu sintaksisda repo'ni tekshiradi va faqat yangi commit bo'lsa build boshlaydi.

### Docker agent

Docker Pipeline plugin'i (`docker-workflow`) bilan stage konteyner ichida bajariladi:

```groovy
stage('Version') {
  agent { docker { image 'python:3.12-slim' } }
  steps { sh 'python --version' }
}
```

Mexanizm: Jenkins image'ni pull qiladi, konteynerni uzoq yashaydigan buyruq bilan fonda ishga tushiradi, unga workspace papkasini ulaydi va uni Jenkins'ning o'z UID'i bilan ishlatadi (workspace fayllariga yoza olishi uchun), har `sh` qadamini `docker exec` orqali ichida bajaradi, oxirida konteynerni to'xtatib o'chiradi. Console'da `+ python --version` va `Python 3.12.<N>` qatorlari chiqadi, atrofida Jenkins bajargan `docker` buyruqlari ham ko'rinadi. Talablar: plugin o'rnatilgan, node'da `docker` CLI va ishlaydigan daemon bor (2-bo'lim). Foydasi: build asboblari agent'ga o'rnatilmaydi, versiya `Jenkinsfile` da qotiriladi; bu GitLab'dagi `image:` ning o'xshashi.

**Tuzoq: konteynerdagi foydalanuvchi.** Image ichida Jenkins UID'i uchun home papka yo'q bo'lsa, cache'ni home'ga yozadigan asboblar ruxsat xatosi bilan yiqiladi. Yechim yo'nalishi: `HOME` ni yoki asbobning cache yo'lini workspace ichiga yo'naltirish.

### Real ishda qachon kerak

- Eski freestyle job'larni `Jenkinsfile` ga ko'chirish: eng ko'p uchraydigan Jenkins ishi.
- Build nima uchun yiqilganini topish: Console Output'da birinchi `+ buyruq` dan keyingi xato qatori va oxiridagi `Finished:`.
- PR'lar uchun avtomatik build: Multibranch va webhook.

### Nima uchun shunday

Pipeline 2016-yilda (Jenkins 2) qo'shilgan, undan oldin faqat freestyle bor edi. Avval scripted paydo bo'lgan: to'liq Groovy erkinligi katta, o'qib bo'lmaydigan fayllarga olib keldi, shuning uchun 2017-yilda ustiga declarative qurildi (qat'iy tuzilma, oldindan tekshirish). Groovy tanlangani tarixiy: Jenkins JVM'da ishlaydi. Narxi: pipeline kodi controller ichida bajariladi, lokal ishga tushirib bo'lmaydi. Amaliy qoida shundan: mantiq `Makefile` va skriptlarda, `Jenkinsfile` faqat ularni chaqiradi. Muqobil yondashuv YAML (2–3-darslar): kuchsizroq, lekin server ichida kod bajarmaydi.

## 4. Plugin'lar

### Bu nima va ichida qanday ishlaydi

Plugin bu controller JVM'iga yuklanadigan Java arxivi. Git, pipeline DSL'ning o'zi, credential'lar, Docker qadamlari, hammasi plugin. Uch xususiyat ekspluatatsiyani belgilaydi: plugin'lar bir-biriga bog'liq (bittasini yangilash boshqalarining minimal versiyasini talab qiladi), har biri Jenkins yadrosining ma'lum minimal versiyasini talab qiladi, va hammasi controller ichida to'liq huquq bilan ishlaydi (izolyatsiya yo'q, bitta zaif plugin butun serverni ochadi).

Frontend'dagi haqiqiy o'xshashi `node_modules`: tranzitiv bog'liqliklar, tashlab qo'yilgan paketlar, `npm audit` ogohlantirishlari. Farqi: npm paketi sizning build'ingizda ishlaydi, Jenkins plugin'i esa barcha loyihalarning secret'lari turgan server ichida.

### Misol: ro'yxat kod sifatida

```
# plugins.txt: one plugin per line, name:version
git:<versiya>
workflow-aggregator:<versiya>
```

Versiyalarni plugins.jenkins.io dagi plugin sahifasidan olasiz (u yerda oxirgi reliz sanasi, talab qilinadigan Jenkins versiyasi, bog'liqliklar va ochiq security ogohlantirishlari ko'rinadi). Image qurilganda `jenkins-plugin-cli` har qatorni va uning bog'liqliklarini yuklaydi; versiyalar mos kelmasa build xato bilan to'xtaydi, ya'ni nomuvofiqlik ishlab turgan serverda emas, image qurishda chiqadi. O'rnatilganlarni UI'da Manage Jenkins → Plugins sahifasida ko'rasiz (Installed va Updates tablari).

### Real ishda qachon kerak

- Jenkins loyihasi muntazam security advisory (zaiflik haqidagi rasmiy e'lon) chiqaradi, ko'pi plugin'larga tegishli. Yangilamaslik teshik qoldiradi, ko'r-ko'rona yangilash esa serverni buzishi mumkin. Shuning uchun yangilash avval sinov nusxasida: yangi `plugins.txt` bilan image, zaxiradan tiklangan `JENKINS_HOME`, pipeline'lar yashilmi.
- Yangi plugin so'ralganda tekshiruv: oxirgi reliz qachon, ochiq zaifliklari bormi, o'rnatishlar soni, shu ishni `sh` qadami bilan qilib bo'lmaydimi.

### Nima uchun shunday

Kichik yadro va minglab plugin Jenkins'ni har qanday tizimga ulanadigan qildi va uni 15 yil yashatdi, lekin sifat va muvofiqlik javobgarligini server egasiga o'tkazdi. Muqobili TeamCity va GitLab'dagi "batteries included" yondashuvi: funksiyalar bitta jamoa tomonidan birga chiqariladi va birga sinaladi, tanlov kamroq, qarov ham kamroq. Amaliy qoida: plugin'lar soni minimal, har yangi plugin doimiy qarz.

## 5. Credentials

### Bu nima va ichida qanday ishlaydi

Credential bu Jenkins saqlaydigan secret: turlari Secret text, Username with password, SSH Username with private key, Secret file, sertifikat. Har biri **ID** ga ega, pipeline qiymatni emas, shu ID ni yozadi. Scope: global (hamma job ko'radi) yoki folder darajasida. Qiymatlar `JENKINS_HOME` da shifrlangan holda yotadi, kalit esa o'sha papkaning `secrets/` qismida. Jenkins'da `GITHUB_TOKEN` yoki `CI_JOB_TOKEN` (2–3-darslar) kabi avtomatik, bir run yashaydigan token yo'q: har tashqi tizim uchun credential'ni o'zingiz yaratasiz, saqlaysiz va almashtirib turasiz (rotation).

### Misol: bog'lash va niqoblash

```groovy
steps {
  withCredentials([usernamePassword(credentialsId: 'nexus-deploy',
      usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
    sh 'curl -fsS --user "$NEXUS_USER:$NEXUS_PASS" -T dist/api https://nexus.example.com/repo/api'
  }
}
```

`withCredentials` (Credentials Binding plugin) secret'ni faqat blok ichida env variable sifatida beradi. Console'da blok boshida `Masking supported pattern matches of $NEXUS_USER or $NEXUS_PASS` kabi qator chiqadi, shundan keyin log'da shu qiymatlarga teng har qanday matn `****` ga almashtiriladi. Qisqa shakli `environment { NEXUS = credentials('nexus-deploy') }`: Username with password turi uchun uch variable hosil bo'ladi, `NEXUS` (`user:pass`), `NEXUS_USR`, `NEXUS_PSW`. Niqoblash faqat aynan mos matnni yashiradi: secret base64'ga o'girilsa yoki faylga yozilib artifact qilinsa, u ochiq chiqadi. Imkon bo'lsa parolni buyruq argumenti sifatida emas, stdin orqali bering (`--password-stdin` kabi flag'lar shuning uchun bor), chunki argumentlar jarayonlar ro'yxatida ko'rinadi.

**Tuzoq: Groovy interpolatsiyasi.** Qo'sh tirnoqli `sh "curl --user ${NEXUS_PASS} ..."` da qiymatni Groovy o'zi, controller'da, buyruq matniga qo'yib yuboradi: secret skript matniga tushadi va ichidagi maxsus belgilar shell injection beradi. Bir tirnoqli `sh '... "$NEXUS_PASS"'` da Groovy matnga tegmaydi, qiymatni agent'dagi shell env'dan oladi. Bu 2-darsdagi script injection bilan bir xil mexanizm, JS'dagi template literal bilan SQL yig'ish xatosiga o'xshaydi. Jenkins bunday holatda log'ga ogohlantirish yozadi (11-vazifa).

### Real ishda qachon kerak

Xodim ketganda yoki token oqib chiqqanda qaysi credential qayerda ishlatilganini ID bo'yicha topasiz va almashtirasiz.

### Nima uchun shunday

Kalitning ma'lumot bilan bir papkada turishi Jenkins'ning bazasiz, o'zi yetarli dizaynidan: server qayta ishga tushganda hech kimdan parol so'ramaydi. Narxi: `JENKINS_HOME` zaxirasi va controller'da ishlagan har qanday build barcha secret'larga yetadi. Muqobili: secret'larni tashqi omborda (HashiCorp Vault, cloud secret manager) saqlash yoki 5-darsdagi OIDC bilan uzoq yashaydigan token'lardan butunlay voz kechish.

## 6. Configuration as Code va ekspluatatsiya yuki

### JCasC: bu nima va qanday ishlaydi

Setup wizard va Manage Jenkins sahifalarida bosib sozlangan server "click-ops" natijasi: sozlama faqat `JENKINS_HOME` dagi XML'da, kim nimani nima uchun o'zgartirgani yozilmagan, server yo'qolsa uni hech kim aynan qayta tiklay olmaydi. Jenkins Configuration as Code plugin'i (`configuration-as-code`, qisqacha JCasC) server sozlamalarini YAML fayldan o'qiydi: xavfsizlik, foydalanuvchilar, credential'lar, agent'lar, executor'lar. Fayl yo'li `CASC_JENKINS_CONFIG` env variable'i bilan beriladi (fayl, papka yoki URL). Jenkins har start'da faylni o'qib sozlamani unga moslaydi. Fayldagi `${NOM}` ko'rinishidagi joylarga qiymat env variable'dan (yoki boshqa secret manbasidan) qo'yiladi, shuning uchun fayl repo'da turadi, secret'ning o'zi esa yo'q.

### Misol: xavfsizlik sozlamasi fayldan

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${ADMIN_PASSWORD}"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
unclassified:
  location:
    url: "http://localhost:8080/"
```

`securityRealm` foydalanuvchilar qayerdan olinishini (bu yerda Jenkins'ning ichki bazasi, ro'yxatdan o'tish yopiq), `authorizationStrategy` kim nima qila olishini (kirgan foydalanuvchi hamma narsani, anonim hech narsani) belgilaydi; `ADMIN_PASSWORD` konteynerga `-e` bilan beriladi. Wizard'ni o'chirish: `JAVA_OPTS=-Djenkins.install.runSetupWizard=false`. Ishlab turgan server sozlamasini YAML ko'rinishida ko'rish va yuklab olish: Manage Jenkins → Configuration as Code. Eksport boshlang'ich nuqta, tayyor fayl emas: u juda ko'p standart qiymatni chiqaradi, secret'lar o'rnida shifrlangan matn turadi.

Natijada server uch fayl to'plamidan qayta yaratiladi: image (`Dockerfile` + `plugins.txt`), `jenkins.yaml`, repo'lardagi `Jenkinsfile` lar. Qolgan bo'shliq job'larning o'zi; ularni ham kod qilish yo'llari bor (Job DSL plugin'i, GitHub organization'ni skanerlaydigan folder turi), 13-vazifada shu haqda o'ylaysiz.

### Kim nima uchun javobgar

| Ish | Hosted CI (Actions, gitlab.com) | Jenkins |
|-----|----------------------------------|---------|
| Serverni yangilash, xavfsizlik yamoqlari | provayder | siz (muntazam LTS relizlari, advisory'lar) |
| Plugin'lar muvofiqligi | bunday muammo yo'q | siz |
| Zaxira va tiklashni sinash | provayder | siz (`JENKINS_HOME`) |
| Agent'lar, masshtablash, disk tozalash | provayder | siz |
| Foydalanuvchilar, SSO, huquqlar | platformada tayyor | siz (plugin'lar bilan) |
| Credential'larni almashtirib turish | qisman avtomatik token'lar | siz |
| Controller yuqori mavjudligi | provayder | open-source'da bitta controller, yagona nosozlik nuqtasi |

### Real ishda qachon kerak

Jenkins litsenziyasi bepul, lekin egalik narxi muhandis vaqtida to'lanadi: o'rta kattalikdagi tashkilotda Jenkins'ga qarash ko'pincha kimningdir to'liq ish o'rni. JCasC shu yukni kamaytiradi: yangilash "yangi image, eski YAML" bo'ladi, o'zgarish PR orqali review qilinadi, sinov serveri production nusxasi bo'ladi.

### Nima uchun shunday

Bu infratuzilmani kod sifatida boshqarish g'oyasining (IaC moduli) CI serverga tatbiqi. JCasC 2018-yilda paydo bo'lgan; undan oldin jamoalar xuddi shu ishni Groovy init skriptlari bilan qilgan, bu ishlagan, lekin har server uchun alohida dastur yozishni talab qilgan.

## 7. TeamCity

### Bu nima

TeamCity bu JetBrains'ning tijorat CI/CD serveri (2006-yildan). Self-hosted (On-Premises) va TeamCity Cloud variantlari bor. Self-hosted'ning bepul Professional litsenziyasi build configuration va agent soni bo'yicha cheklangan; joriy limitlarni JetBrains saytidagi litsenziya sahifasidan tekshiring. Jenkins'dan asosiy farqi: Git, Docker, test hisobotlari, build zanjirlari, versiyalangan sozlamalar qutidan chiqadi, plugin'larga bog'liqlik ancha kam. Holat `JENKINS_HOME` kabi bitta papkada emas: sozlamalar va artifact'lar Data Directory'da, build tarixi SQL bazada.

### Tushunchalar

| TeamCity | Ma'nosi | O'xshashi |
|----------|---------|-----------|
| Server, agent | rejalashtiruvchi va ijrochi; agent serverga o'zi ulanadi | controller, agent |
| Project | build configuration'lar va sozlamalar to'plami, ichma-ich bo'ladi | folder, group |
| Build configuration | bitta "nima va qanday qurilishi" ta'rifi | job |
| VCS root | repo'ga ulanish ta'rifi (URL, branch, autentifikatsiya) | checkout |
| Build step | runner turi bilan bitta qadam (Command Line, Docker, Node.js, Gradle) | step |
| Trigger | VCS trigger (server repo'ni kuzatadi), schedule, finish build | `on` |
| Agent requirements | build agent'dan nima talab qilishi | label'lar |
| Parameters | `%nom%` bilan murojaat, `env.` prefiksi env variable, password turi secret | variables, secrets |
| Snapshot dependency | "avval o'sha build, aynan shu commit'da" | `needs` |
| Artifact dependency | boshqa build artifact'ini olish | artifact download |
| Build chain | snapshot dependency'lar bilan bog'langan konfiguratsiyalar | pipeline grafi |

Build chain'ning muhim xususiyati: zanjirdagi barcha build'lar bir xil commit'dan olinadi va mos build allaqachon mavjud bo'lsa u qayta ishlatiladi. Bu "build once" (1-dars) ni tizim darajasida ta'minlaydi.

### Docker'da ishga tushirish

Rasmiy image'lar `jetbrains/teamcity-server` va `jetbrains/teamcity-agent`. Mac'da pull'dan oldin image `linux/arm64` uchun chiqadimi, tekshiring: Docker Hub'dagi Tags sahifasida OS/ARCH ustuni yoki `docker buildx imagetools inspect jetbrains/teamcity-server` chiqishidagi `Platform:` qatorlari. Faqat `linux/amd64` bo'lsa, Docker Desktop uni emulyatsiya ostida ishlatadi (`WARNING: The requested image's platform (linux/amd64) does not match the detected host platform` ogohlantirishi bilan): ishlaydi, lekin JVM bir necha barobar sekin ko'tariladi va build'lar sekin. Bu holda TeamCity qismini Zorin'da bajarish oqilona.

```
docker network create teamcity
docker run -d --name teamcity-server --network teamcity -p 127.0.0.1:8111:8111 \
  -v teamcity-data:/data/teamcity_server/datadir \
  -v teamcity-logs:/opt/teamcity/logs jetbrains/teamcity-server
docker run -d --name teamcity-agent --network teamcity \
  -e SERVER_URL="http://teamcity-server:8111" \
  -v teamcity-agent-conf:/data/teamcity_agent/conf jetbrains/teamcity-agent
```

Agent serverni tarmoq ichidagi nomi bilan topadi (`SERVER_URL`), unga port publish qilish kerak emas. Birinchi kirishda (`http://localhost:8111`) to'rt qadam: Data Directory tasdiqlanadi, baza tanlanadi (sinov uchun ichki HSQLDB, production uchun tashqi PostgreSQL yoki MySQL), litsenziya shartnomasi qabul qilinadi, admin yaratiladi. Agent ulangach Agents sahifasining "Unauthorized" bo'limida ko'rinadi va qo'lda **authorize** qilinadi. Start holatini `docker logs teamcity-server` dan kuzating. Agent ichida Docker ishlatish variantlari image'ning Docker Hub sahifasida.

### Kotlin DSL

Sozlamalar UI'da tuziladi yoki repo'dagi `.teamcity/settings.kts` da Kotlin kodi sifatida saqlanadi (Versioned Settings). Odatiy yo'l: UI'da tuzib, "View as code" bilan DSL'ni ko'rish. Boshqa loyiha uchun parcha:

```kotlin
object Docs : BuildType({
    name = "Docs"
    vcs { root(DslContext.settingsRoot) }
    steps {
        script {
            name = "Build site"
            scriptContent = "mkdocs build --strict"
        }
    }
    triggers { vcs { } }
})
```

`object Docs : BuildType` bitta build configuration; `vcs` qaysi VCS root'dan kod olinishi; `steps` ichidagi `script` Command Line runner; `triggers { vcs { } }` har yangi commit'da ishga tushirish. YAML'dan farqi: bu statik tipli haqiqiy til (TypeScript va oddiy JSON konfiguratsiya farqi kabi): IDE avtoto'ldirish beradi, xato kompilyatsiyada chiqadi, sikl va funksiya bilan o'nlab o'xshash konfiguratsiya generatsiya qilinadi. Narxi: kirish to'sig'i baland va "konfiguratsiya" dasturga aylanib ketishi mumkin.

### Real ishda qachon kerak

TeamCity ko'proq katta JVM, .NET, C++ va o'yin loyihalarida uchraydi: build chain, artifact qayta ishlatish va test tarixi tahlili u yerda vaqtni tejaydi.

### Nima uchun shunday

Authorize qadami ataylab qo'lda: agent build paytida kodni va secret parametrlarni oladi, shuning uchun tarmoqdagi begona mashina o'zini agent deb e'lon qilib ularni ola olmasligi kerak. JetBrains bitta mahsulotni bitta jamoa bilan chiqaradi, shuning uchun funksiyalar bir-biriga mos, evaziga litsenziya to'lanadi va moslashuvchanlik Jenkins'dagidan kam.

## 8. Qachon qaysi biri tanlanadi

Qaror to'rt savolga tayanadi: jamoa hajmi (CI serverga qaraydigan odam bormi), compliance (kod va secret'lar tashqi provayderga chiqishi mumkinmi), mavjud meros (nima allaqachon ishlab turibdi), egalik narxi (litsenziya emas, muhandis vaqti).

| Holat | Odatiy tanlov | Sabab |
|-------|---------------|-------|
| Kichik yoki o'rta jamoa, kod GitHub yoki GitLab'da, oddiy web servislar | o'sha platformaning CI'si | ekspluatatsiya yuki yo'q, integratsiya tayyor |
| Yopiq tarmoq, internetga chiqish yo'q, regulyator talabi, bepul bo'lishi shart | Jenkins yoki self-managed GitLab | to'liq o'z nazoratida |
| Juda turli muhitlar: mainframe, eski OS, maxsus apparat, g'alati VCS | Jenkins | deyarli hamma narsaga plugin yoki skript bilan ulanadi |
| Katta JVM/.NET/C++/o'yin loyihalari, murakkab build zanjirlari | TeamCity | build chain, artifact qayta ishlatish, test tahlili, qulay UI |
| Litsenziya to'lashga tayyor, plugin qarovidan qochmoqchi jamoa | TeamCity | qutidan chiqadigan funksiyalar, tijorat qo'llab-quvvatlash |
| Yillar davomida ishlayotgan yuzlab Jenkins job | Jenkins qoladi | migratsiya narxi foydadan katta |

### Real ishda qachon kerak

Hosted CI'da ham nazorat yo'qolmaydi: build'larni o'z tarmog'ingizda ishlatish kerak bo'lsa, self-hosted runner (2–3-darslar) qo'shiladi va faqat rejalashtiruvchi provayderda qoladi. Amalda ko'p korxonada tanlov texnik emas, tarixiy: Jenkins allaqachon bor va ishlaydi. Sizning vazifangiz ko'pincha uni almashtirish emas, tartibga keltirish: freestyle job'larni `Jenkinsfile` ga, qo'lda sozlamalarni JCasC'ga, controller'dagi build'larni agent'larga ko'chirish.

### Nima uchun shunday

Self-hosted CI 2000-yillarda yagona variant edi; hosted CI kod hosting bilan birlashgach (GitLab CI 2015, GitHub Actions 2019) yangi loyihalar uchun standart bo'ldi, chunki server qarovi umuman yo'qoladi. Self-hosted serverlar esa nazorat, yopiq tarmoq va meros talab qilgan joyda qoldi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Controller | Jenkins'ning markaziy jarayoni: UI, rejalashtirish, konfiguratsiya, credential'lar |
| Agent | build qadamlarini bajaradigan mashina yoki konteyner |
| Executor | node'dagi parallel build uyasi |
| Label | agent'ga qo'yiladigan belgi, pipeline shu bo'yicha agent tanlaydi |
| Built-in node | controller'ning o'zi node sifatida |
| Workspace | build uchun ajratilgan ish papkasi, kod shu yerga checkout qilinadi |
| `JENKINS_HOME` | Jenkins'ning butun holati yotgan papka |
| LTS | faqat tuzatishlar oladigan barqaror reliz liniyasi |
| Setup wizard | birinchi start'dagi sozlash ustasi (unlock, plugin'lar, admin) |
| dind | Docker-in-Docker: konteyner ichida ishlaydigan alohida Docker daemon |
| `Jenkinsfile` | repo'dagi pipeline ta'rifi fayli |
| Declarative / scripted | pipeline'ning qat'iy tuzilmali va erkin Groovy sintaksislari |
| Stage, step | pipeline bosqichi va uning ichidagi bitta qadam |
| `post` | pipeline yoki stage tugagach natijaga qarab bajariladigan blok |
| `stash` / `unstash` | fayllarni turli agent'lardagi stage'lar orasida uzatish |
| Multibranch Pipeline | har branch uchun avtomatik job yaratadigan job turi |
| Freestyle job | UI'da sozlanadigan eski job turi |
| Polling | serverning repo'ni davriy so'rab o'zgarish qidirishi |
| Webhook | repo hosting'ning CI serverga yuboradigan HTTP xabari |
| Plugin | controller JVM'iga yuklanadigan kengaytma |
| Security advisory | zaiflik haqidagi rasmiy e'lon |
| Credential, ID | Jenkins saqlaydigan secret va unga pipeline'dan murojaat qilinadigan nom |
| Masking | log'da secret qiymatini `****` ga almashtirish |
| PAT | personal access token, GitHub'da parol o'rnida ishlatiladigan token |
| JCasC | Jenkins sozlamalarini YAML fayldan o'qiydigan plugin |
| Click-ops | serverni UI'da qo'lda bosib sozlash |
| Build configuration | TeamCity'da bitta build ta'rifi |
| VCS root | TeamCity'da repo'ga ulanish ta'rifi |
| Snapshot dependency | TeamCity'da "avval o'sha build, shu commit'da" bog'lanishi |
| Build chain | snapshot dependency'lar bilan bog'langan build'lar zanjiri |
| Kotlin DSL | TeamCity sozlamalarining Kotlin kodi ko'rinishi (`.teamcity/settings.kts`) |

## Tuzoqlar

- Controller'da build qilish va controller'ga host Docker socket'ini ulash: `Jenkinsfile` yozgan har kim server (va host) egasi.
- `-p 8080:8080` bilan UI'ni barcha interfeyslarda ochish. Laboratoriyada har doim `127.0.0.1:`.
- Jenkins'ni va plugin'larni yillab yangilamaslik. Internetga ochiq eski Jenkins buzib kirishning klassik yo'li.
- UI'ni autentifikatsiyasiz qoldirish. Script Console (`/script`) admin uchun serverda ixtiyoriy kod bajaradi.
- `sh "..."` ichida secret'ni Groovy interpolatsiyasi bilan ishlatish.
- `JENKINS_HOME` ni zaxiralamaslik, tiklashni hech qachon sinamaslik yoki zaxirani ochiq joyda saqlash (ichida shifrlash kalitlari bor).
- Volume'siz ishga tushirilgan Jenkins: `docker rm` bilan hammasi yo'qoladi.
- UI'da qo'lda sozlangan freestyle job'lar: review yo'q, tarix yo'q.
- Uzun mantiqni `Jenkinsfile` ichida Groovy'da yozish: lokal ishlamaydi, debug og'ir.
- dind ichida qurilgan image host'ning `docker images` ro'yxatida yo'q; uni host'dan qidirmang.
- Doimiy agent'da workspace va image'lar to'planib disk to'lishi: `buildDiscarder`, workspace tozalash va agent'da rejali tozalash kerak. O'z ish mashinangizda esa faqat nom bilan o'chiring.
- TeamCity'da agent'ni tekshirmasdan authorize qilish yoki ichki HSQLDB bilan production'ga chiqish.
- Token'ni terminalga `export TOKEN=...` deb yozish: shell tarixida qoladi. Token faqat brauzerdan credential formasiga ko'chiriladi.

## Manbalar

- https://www.jenkins.io/doc/book/installing/docker/ – Jenkins'ni Docker'da o'rnatish (dind sxemasi, `Dockerfile`)
- https://www.jenkins.io/doc/book/pipeline/syntax/ – declarative va scripted pipeline sintaksisi
- https://www.jenkins.io/doc/book/pipeline/jenkinsfile/ – Jenkinsfile, credential'lar, interpolatsiya xavfi
- https://www.jenkins.io/doc/book/pipeline/docker/ – pipeline'da Docker agent
- https://www.jenkins.io/doc/book/using/using-credentials/ – credentials
- https://www.jenkins.io/doc/book/security/controller-isolation/ – controller izolyatsiyasi
- https://www.jenkins.io/doc/book/managing/casc/ – Configuration as Code
- https://github.com/jenkinsci/configuration-as-code-plugin – JCasC plugin'i, misollar (`demos/`)
- https://github.com/jenkinsci/docker – rasmiy image, `jenkins-plugin-cli`, `plugins.txt`
- https://plugins.jenkins.io/ – plugin katalogi (versiya, bog'liqlik, ogohlantirishlar)
- https://www.jenkins.io/security/advisories/ – security advisory'lar
- https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry – GHCR'ga token bilan kirish
- https://www.jetbrains.com/help/teamcity/teamcity-documentation.html – TeamCity hujjati
- https://www.jetbrains.com/help/teamcity/kotlin-dsl.html – Kotlin DSL
- https://hub.docker.com/r/jetbrains/teamcity-server – server image
- https://hub.docker.com/r/jetbrains/teamcity-agent – agent image, Docker ishlatish variantlari

## Birga bajaramiz

Bitta bir martalik Jenkins'ni ko'tarib, unda repo'siz kichik pipeline va soxta secret yaratamiz, keyin serverni zaxiradan boshqa volume'ga tiklaymiz. Nomlar vazifalardagidan boshqa (`jenkins-walk`), oxirida hammasi o'chiriladi. Buyruqlar host'da, ikkala mashinada bir xil.

1. Vaqtinchalik papka va server:

```
$ mkdir -p ~/jenkins-walk && cd ~/jenkins-walk
$ docker run -d --name jenkins-walk -p 127.0.0.1:8080:8080 \
    -v jenkins-walk-data:/var/jenkins_home jenkins/jenkins:lts-jdk21
$ docker ps --filter name=jenkins-walk --format '{{.Names}} {{.Ports}}'
jenkins-walk 127.0.0.1:8080->8080/tcp, 50000/tcp
```

`127.0.0.1:8080->8080/tcp` UI faqat loopback'da; `50000/tcp` image e'lon qilgan, lekin publish qilinmagan port. `docker logs jenkins-walk 2>&1 | grep 'fully up'` qator bermaguncha kuting, parolni 2-bo'limdagi usulda oling, wizard'dan "Install suggested plugins" bilan o'ting va admin yarating.

2. Soxta secret: Manage Jenkins → Credentials → global domen → Add Credentials, turi "Secret text", Secret `walk-12345`, ID `walk-token`. Bu haqiqiy token emas, ataylab.

3. New Item → `walk` → Pipeline, "Pipeline script" maydoniga:

```groovy
pipeline {
  agent any
  environment { OUT = 'out/report.txt' }
  stages {
    stage('Generate') {
      steps { sh 'mkdir -p out && echo "build $BUILD_NUMBER" > "$OUT"' }
    }
    stage('Secret') {
      steps {
        withCredentials([string(credentialsId: 'walk-token', variable: 'TOKEN')]) {
          sh 'echo "length: ${#TOKEN}"; echo "$TOKEN"'
        }
      }
    }
  }
  post { success { archiveArtifacts artifacts: 'out/*.txt' } }
}
```

4. Build Now, keyin Console Output:

```
[Pipeline] { (Generate)
[Pipeline] sh
+ mkdir -p out
+ echo build 1
...
[Pipeline] withCredentials
Masking supported pattern matches of $TOKEN
[Pipeline] {
[Pipeline] sh
+ echo length: 10
length: 10
+ echo ****
****
...
Finished: SUCCESS
```

`+` qatorlari shell'ning `-x` izi. `length: 10` secret haqiqatan env'da borligini ko'rsatadi (`walk-12345` 10 belgi), `****` esa Jenkins log'da qiymatni niqoblaganini. Build sahifasida `out/report.txt` artifact sifatida turibdi.

5. Zaxira. Avval serverni to'xtatamiz, shunda fayllar yozilayotgan paytda nusxalanmaydi:

```
$ docker stop jenkins-walk
$ docker run --rm -v jenkins-walk-data:/data:ro -v "$PWD":/backup alpine:3.20 \
    tar czf /backup/walk.tar.gz -C /data .
$ tar tzf walk.tar.gz | grep -E 'secrets/master.key|credentials.xml'
./credentials.xml
./secrets/master.key
```

Bir martalik `alpine` konteyneri volume'ni faqat o'qish uchun (`:ro`) ulab arxivlaydi. Ikkinchi buyruq arxivda shifrlangan credential'lar ham, kalit ham borligini ko'rsatadi: bu fayl secret, uni repo'ga qo'ymang.

6. "Halokat" va tiklash:

```
$ docker rm jenkins-walk && docker volume rm jenkins-walk-data
$ docker run --rm -v jenkins-walk-restored:/data -v "$PWD":/backup:ro alpine:3.20 \
    tar xzf /backup/walk.tar.gz -C /data
$ docker run --rm -v jenkins-walk-restored:/data alpine:3.20 ls -ln /data/config.xml
-rw-r--r--    1 1000     1000     <hajm> <sana> /data/config.xml
$ docker run -d --name jenkins-walk -p 127.0.0.1:8080:8080 \
    -v jenkins-walk-restored:/var/jenkins_home jenkins/jenkins:lts-jdk21
```

`ls -ln` egasi `1000` (image'dagi `jenkins`) ekanini tekshiradi; boshqa son chiqsa, xuddi shunday konteynerda `chown -R 1000:1000 /data` qiling. UI'da wizard chiqmaydi, o'z admin'ingiz bilan kirasiz, `walk` job'i, 1-build va uning artifact'i joyida. Build Now: `length: 10` va `****` yana chiqadi, ya'ni credential yangi volume'da ham ochildi, chunki kalit zaxira ichida keldi.

7. Tozalash va tekshirish:

```
$ docker rm -f jenkins-walk && docker volume rm jenkins-walk-restored
$ cd ~ && rm -f ~/jenkins-walk/walk.tar.gz && rmdir ~/jenkins-walk
$ docker ps -a --filter name=jenkins-walk -q; docker volume ls -q --filter name=jenkins-walk
```

Oxirgi buyruq hech narsa chiqarmasligi kerak. Zorin'da arxiv egasi `root` bo'ladi (konteyner root bilan yozgan), papka sizniki bo'lgani uchun `rm -f` baribir o'chiradi.

Shu 7 qadamda ko'rganingiz: konteyner, port va volume (2-bo'lim), wizard va parol (2-bo'lim), declarative pipeline va console output (3-bo'lim), credential ID va niqoblash (5-bo'lim), butun holat `JENKINS_HOME` da va zaxira secret ekanligi (1 va 5-bo'limlar), qo'lda bosilgan qadamlar esa 6-bo'limdagi JCasC nimani almashtirishini ko'rsatadi.

---

## Vazifalar

`Jenkinsfile` `cicd-demo` reposida (alohida `jenkins` branch'ida yoki `main` da) turadi. Javoblar `cicd/04-jenkins-teamcity/` da (yaratish: `make new m=cicd n=04 name=jenkins-teamcity`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi (console output parchasi) va o'z so'zingiz bilan izoh. `Dockerfile`, `plugins.txt`, `jenkins.yaml`, `Jenkinsfile` nusxasi va TeamCity DSL eksporti shu papkada saqlanadi.

### A. Jenkins: server

1. **Run Jenkins.** Jenkins'ni 2-bo'limdagi eng sodda buyruq bilan ko'taring, setup wizard'dan o'ting (tavsiya etilgan plugin'lar). `docker exec` bilan `/var/jenkins_home` ichini ko'rib chiqing: `config.xml`, `jobs/`, `plugins/`, `secrets/` nima saqlaydi? Konteynerni o'chirib qayta yarating: sozlamalar saqlanib qoldimi va nima uchun? Yo'nalish: 2-bo'lim, "Eng sodda ishga tushirish" va 1-bo'lim, "`JENKINS_HOME`: holat qayerda".

2. **Freestyle job.** UI'da freestyle job yarating: `cicd-demo` ni klonlab `ls` va `cat package.json` qiladigan shell qadam. Ishga tushiring. Bu job ta'rifi diskda qayerda va qanday formatda saqlanganini toping. Pipeline as code nuqtai nazaridan bunda nima yomon? Yo'nalish: 3-bo'lim, "Jenkinsfile job'ga qanday aylanadi".

3. **Custom image with Docker.** Rasmiy qo'llanma bo'yicha: `jenkins` tarmog'i, `docker:dind` konteyneri, `docker-ce-cli` va `plugins.txt` (versiyalari qotirilgan `docker-workflow`, `configuration-as-code` va boshqa keraklilari) bilan o'z image'ingiz. Jenkins'ni shu image'dan, oldingi `jenkins-data` volume'i bilan qayta ko'taring. Konteyner ichidan `docker version` server qismini ko'rsatayotganini tekshiring. `jenkins-data` nima uchun dind konteyneriga ham ulanishini izohlang. Yo'nalish: 2-bo'lim, "dind sxemasining qismlari" va "O'z image'ingiz".

4. **Controller executors.** Manage Jenkins → Nodes'da built-in node'ning executor sonini toping. Uni 0 qilsangiz va agent bo'lmasa build bilan nima bo'ladi (sinab ko'ring, navbatdagi xabarni yozing)? Laboratoriya uchun qaytarib qo'ying va production'da nima uchun 0 bo'lishi kerakligini aniq hujum ssenariysi bilan izohlang. Yo'nalish: 1-bo'lim, "Tuzoq: controller'da build qilish".

### B. Jenkins: pipeline

5. **First Jenkinsfile.** `Jenkinsfile` yozing: `Lint` va `Test` stage'lari `Makefile` target'larini chaqiradi. Pipeline job yarating ("Pipeline script from SCM"). Ishga tushirib Stage View va console output'ni ko'ring. Checkout qayerda sodir bo'ldi (siz yozmagan stage)? Yo'nalish: 3-bo'lim, "Jenkinsfile job'ga qanday aylanadi".

6. **Docker agent.** `Test` stage'ini `agent { docker { image 'node:...' } }` bilan konteynerda ishlating (bu holda `make` o'rniga to'g'ridan `npm` buyruqlari kerak bo'lishi mumkin, 3-darsdagi 2-vazifani eslang). Console output'dan Jenkins konteynerni qanday `docker run` argumentlari bilan ishga tushirganini toping. Foydalanuvchi/UID bilan bog'liq xato chiqsa, uni yozing va tuzating. Yo'nalish: 3-bo'lim, "Docker agent".

7. **Break and read.** Testni buzing va build'ni ishga tushiring. Qaysi stage qizil, keyingilari qanday holatda? `post { failure { ... } always { ... } }` qo'shib ikkala blok qachon ishlashini ko'rsating. JUnit hisobotini `junit` step'i bilan e'lon qiling va Test Result sahifasini tasvirlang. Yo'nalish: 3-bo'lim, "Bloklar".

8. **Polling trigger.** `triggers { pollSCM('H/2 * * * *') }` qo'shing, commit push qiling va build o'zi boshlanishini kuting. `H` nimani anglatadi? Nima uchun laboratoriyada webhook ishlamaydi va production'da polling o'rniga webhook afzal? Yo'nalish: 3-bo'lim, "Jenkinsfile job'ga qanday aylanadi" (trigger'lar).

9. **Parallel and stash.** `Lint` va `Test` ni `parallel` blokiga oling. Keyin `agent none` qilib har stage'ga alohida `agent` bering va bitta stage'da yaratilgan faylni keyingisida o'qishga urinib ko'ring. Xatoni yozing, `stash`/`unstash` bilan tuzating. Bu GitHub Actions'dagi qaysi mexanizmning o'xshashi? Yo'nalish: 3-bo'lim, "`agent` qayerda e'lon qilinadi".

10. **Credentials.** GitHub'da faqat `write:packages` huquqli, qisqa muddatli PAT yarating va Jenkins'ga "Username with password" credential sifatida qo'shing. `Build` stage'i image'ni qurib `ghcr.io/<owner>/cicd-demo:<GIT_COMMIT>` ga push qilsin. Console output'da token ko'rinmasligini tekshiring. GitHub Actions'dagi `GITHUB_TOKEN` bilan solishtirganda bu yerda qanday qo'shimcha javobgarlik paydo bo'ldi? Yo'nalish: 5-bo'lim, "Misol: bog'lash va niqoblash"; image dind ichida qoladi, arxitekturasi mashinaga bog'liq.

11. **Groovy interpolation trap.** Vaqtincha `sh "echo ${REGISTRY_PSW} | wc -c"` (qo'sh tirnoq) yozib ishga tushiring: Jenkins log'da qanday ogohlantirish berdi? Bir tirnoqqa o'zgartirib farqni izohlang: qiymatni kim va qachon joyiga qo'yadi? Yo'nalish: 5-bo'lim, "Tuzoq: Groovy interpolatsiyasi".

12. **Manual gate.** `Deploy production` stage'i qo'shing: `input` bilan tasdiq kutadi, keyin `echo`. `when { branch }` oddiy Pipeline job'da kutilgandek ishlaydimi? Tekshiring, kerak bo'lsa Multibranch Pipeline job yarating va branch'lar qanday aniqlanganini ko'rsating. `input` kutayotgan paytda executor band bo'ladimi va buni qanday oldini olish mumkin? Yo'nalish: 3-bo'lim, "`agent` qayerda e'lon qilinadi" va "Jenkinsfile job'ga qanday aylanadi".

13. **JCasC.** Joriy konfiguratsiyani UI'dan YAML sifatida eksport qiling va o'qing. Minimal `jenkins.yaml` yozing (system message, executor soni, bitta credential qiymati env variable'dan). **Yangi** volume bilan, setup wizard o'chirilgan holda Jenkins'ni ko'taring: qo'lda hech narsa bosmasdan sozlangan server olasiz. Qaysi qismlar hali ham kod emasligini (job'lar?) va uni qanday yopish mumkinligini yozing. Yo'nalish: 6-bo'lim, "JCasC" va "Misol".

14. **Upkeep audit.** Manage Jenkins → Plugins'da nechta plugin o'rnatilgan va nechtasida yangilanish bor? Jenkins security advisories sahifasidan oxirgi ikki advisory'ni oching: nechta plugin tilga olingan, sizda o'rnatilganlari bormi? `JENKINS_HOME` ni zaxiralash rejasini 5–6 gapda yozing: nima, qanchalik tez-tez, qayerga, tiklashni qanday sinaysiz. Yo'nalish: 4-bo'lim va "Birga bajaramiz" 5–6 qadamlar.

### C. TeamCity

15. **Run TeamCity.** Jenkins konteynerlarini to'xtating. TeamCity server va agent'ni 7-bo'limdagi buyruqlar bilan ko'taring, birinchi sozlashdan o'ting (ichki baza), agent'ni authorize qiling. Agent sahifasida uning parametrlarini ko'ring: TeamCity agent haqida nimalarni avtomatik aniqlagan? Authorize qadami nimadan himoya qiladi? Yo'nalish: 7-bo'lim, "Docker'da ishga tushirish" (Mac'da avval platformani tekshiring).

16. **Build configuration.** `cicd-demo` uchun project va build configuration yarating (repo URL'dan). TeamCity build step'larni avtomatik taklif qildimi? Command Line step bilan test'ni ishga tushiring (agent'da `make`, Node yoki Docker bor-yo'qligini avval tekshiring va yo'qligini qanday hal qilganingizni yozing). VCS trigger qo'shing va commit bilan sinang. Testni buzib build sahifasidagi xato ko'rinishini Jenkins'niki bilan taqqoslang. Yo'nalish: 7-bo'lim, "Tushunchalar".

17. **Build chain.** Ikkinchi konfiguratsiya (`Package`: fayllarni arxivlab artifact qiladi) yarating va uni birinchisiga snapshot dependency bilan bog'lang. `Package` ni ishga tushiring: `Test` nima bo'ldi? Yana bir marta, kod o'zgarmagan holda ishga tushiring: `Test` qayta ishladimi? Sababini va bu "build once" bilan qanday bog'liqligini izohlang. Yo'nalish: 7-bo'lim, "Tushunchalar" (build chain).

18. **Kotlin DSL.** "View as code" orqali konfiguratsiyaning Kotlin DSL ko'rinishini oching va eksport qilib ish papkasiga saqlang. Faylda project, VCS root, build type, step, trigger va dependency qayerda ekanini belgilang. YAML (`ci.yml`) va Groovy (`Jenkinsfile`) bilan taqqoslab, tipli DSL'ning bitta afzalligi va bitta kamchiligini yozing. Yo'nalish: 7-bo'lim, "Kotlin DSL".

### D. Xulosa

19. **Four-way comparison.** To'rt tizim bo'yicha jadval: "noldan birinchi yashil pipeline'gacha" ketgan vaqtingiz, pipeline fayli hajmi, secret/token modeli, build'ni konteynerda ishlatish qanchalik oson, xatoni topish qulayligi, siz bajargan ekspluatatsiya ishlari. Oxirida: 20 kishilik GitHub'dagi jamoaga nimani tavsiya qilasiz va qaysi holatda fikringiz o'zgaradi? Yo'nalish: 6-bo'lim, "Kim nima uchun javobgar" va 8-bo'lim.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 19 ta vazifaning har biri `## N. Title` sarlavhasi ostida; Jenkins'da to'liq pipeline (lint, test, build va push, manual gate) yashil, console output'da secret yo'q.
2. Ish papkasida `Dockerfile`, `plugins.txt`, `jenkins.yaml`, `Jenkinsfile`, TeamCity DSL eksporti va `README.md` bor.
3. PAT GitHub'da bekor qilingan.
4. Barcha konteynerlar, volume'lar (`jenkins-data`, `jenkins-docker-certs`, `teamcity-*`) va network'lar (`jenkins`, `teamcity`) aniq nom bilan o'chirilgan (`prune` siz), `docker ps -a` va `docker volume ls` bilan tekshirilgan.
5. `make check` toza. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Controller va agent vazifalari qanday bo'lingan? Nima uchun controller'da build qilinmaydi?
- Jenkins holati qayerda saqlanadi va zaxira nusxasi nima uchun secret hisoblanadi?
- Declarative pipeline'da stage'lar orasida fayllar nima uchun saqlanadi, GitHub Actions job'lari orasida esa yo'q?
- `sh "..."` va `sh '...'` farqi secret'lar uchun nima uchun muhim?
- Jenkins plugin'lari nima uchun bir vaqtda ham kuch, ham xavf?
- JCasC qaysi muammoni yechadi?
- Hosted CI siz uchun bajaradigan, Jenkins'da esa o'zingiz qiladigan ishlardan kamida to'rttasini ayting.
- TeamCity'da snapshot dependency nima qiladi va build chain "build once" ni qanday ta'minlaydi?
- Qaysi holatlarda korxona Jenkins'ni, qaysi holatlarda TeamCity'ni tanlaydi?
