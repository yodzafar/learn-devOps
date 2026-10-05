# 4-dars: Jenkins va TeamCity

Maqsad: o'zingiz boshqaradigan CI serverlarini tushunish. GitHub Actions va GitLab CI'da server (control plane) birovning zimmasida edi, siz faqat YAML yozdingiz. Jenkins va TeamCity'da serverni o'rnatish, yangilash, zaxiralash va himoyalash ham sizning ishingiz. Ko'p korxonalarda (bank, telekom, yopiq tarmoq, eski mahsulotlar) aynan shular ishlaydi va DevOps muhandisi ularni ekspluatatsiya qiladi. Shu darsda 2-darsdagi pipeline'ni Jenkins'ga to'liq ko'chirasiz, TeamCity bilan yengilroq tanishasiz, va "hosted CI nimani bepul berayotgan ekan" degan savolga amaliy javob olasiz. 5-darsdagi deploy GitHub Actions'da davom etadi.

Taxminiy vaqt: 4 kun (siz uchun): Jenkins 3 kun, TeamCity 1 kun. Diqqatni quyidagilarga qarating: controller va agent ajratilishi va nima uchun controller'da build qilinmaydi, declarative `Jenkinsfile` tuzilishi, credentials qanday bog'lanadi, plugin'lar ekspluatatsiya yuki sifatida, Configuration as Code g'oyasi, TeamCity'ning build configuration va build chain modeli.

## Laboratoriya

- Hammasi ish mashinasida Docker konteynerlarida, ma'lumotlar named volume'larda. Ish mashinasiga Java, Jenkins yoki TeamCity paketlari o'rnatilmaydi.
- Jenkins: `http://localhost:8080`, TeamCity: `http://localhost:8111`. Ikkalasini bir vaqtda ko'tarish shart emas: TeamCity serveri va agent'i birga bir necha GB RAM oladi. Jenkins qismini tugatib, konteynerlarni to'xtatib, keyin TeamCity'ni ko'taring.
- Kod manbai: GitHub'dagi public `cicd-demo`. Server `localhost` da bo'lgani uchun GitHub undan webhook yubora olmaydi, shuning uchun trigger sifatida polling yoki qo'lda ishga tushirish ishlatiladi. Bu laboratoriya cheklovi, production'da webhook ishlatiladi.
- GHCR'ga push uchun alohida token kerak bo'ladi (bu yerda `GITHUB_TOKEN` yo'q): classic PAT (personal access token), faqat `write:packages` huquqi bilan, qisqa muddatli. Dars oxirida bekor qilinadi.
- Ish papkasi `cicd/04-jenkins-teamcity/`: `README.md`, `Jenkinsfile` nusxasi, Jenkins image `Dockerfile`, `jenkins.yaml` (JCasC), TeamCity Kotlin DSL eksporti.
- Tozalash: `docker rm -f` bilan barcha konteynerlar, `docker volume rm` bilan volume'lar, `docker network rm jenkins`, PAT'ni GitHub'da bekor qilish.

---

## 1. Jenkins arxitekturasi

Jenkins bu Java'da yozilgan open-source avtomatlashtirish serveri (2011-yildan, Hudson'dan ajralgan). Yadro kichik, deyarli hamma funksiya plugin orqali keladi.

| Qism | Vazifasi |
|------|----------|
| Controller | UI, konfiguratsiya, job'larni rejalashtirish, build tarixi, credentials. Bitta JVM jarayoni |
| Agent | build qadamlarini bajaradigan mashina yoki konteyner. Controller'ga ulanadi |
| Executor | agent'dagi parallel build uyasi. Agent'da N executor bo'lsa N build bir vaqtda |
| Node | controller yoki agent uchun umumiy nom. Controller'ning o'zi "built-in node" |
| `JENKINS_HOME` | butun holat: konfiguratsiya (XML), job'lar, build tarixi, plugin'lar, secret'lar. Ma'lumotlar bazasi yo'q, hammasi fayl tizimida |

Agent ulanish usullari: controller agent'ga SSH orqali kiradi, yoki agent controller'ga o'zi ulanadi (inbound, 50000-port yoki WebSocket). Dinamik agent'lar: Docker, Kubernetes yoki cloud plugin'lari har build uchun agent yaratib, tugagach yo'q qiladi (hosted runner'larga o'xshash model).

**Tuzoq: controller'da build qilish.** Build controller bilan bir xil mashinada, bir xil foydalanuvchi ostida ishlasa, `Jenkinsfile` yoza oladigan har kim `JENKINS_HOME` dagi barcha credential'larni o'qiy oladi va serverni buza oladi. Production qoidasi: built-in node'da executor soni 0, barcha build'lar agent'larda. Laboratoriyada soddalik uchun bu qoidani buzamiz va buni bilib turamiz.

## 2. Jenkins'ni Docker'da ishga tushirish

Rasmiy image: `jenkins/jenkins` (`lts-jdk21` tag'i LTS liniyasi). Eng sodda ishga tushirish:

```
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home jenkins/jenkins:lts-jdk21
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Birinchi kirishda setup wizard shu parolni so'raydi, plugin'lar to'plamini o'rnatadi va admin foydalanuvchi yaratadi.

Pipeline ichida Docker ishlatish uchun (image qurish, build'ni konteynerda bajarish) controller'ga Docker CLI va daemon kerak. Rasmiy qo'llanmadagi sxema:

1. `docker network create jenkins`.
2. `docker:dind` konteyneri shu tarmoqda `docker` alias bilan, privileged, TLS sertifikatlari `jenkins-docker-certs` volume'ida, `jenkins-data` volume'i ham ulangan.
3. O'z image'ingiz: `jenkins/jenkins` ustiga `docker-ce-cli` va kerakli plugin'lar.
4. Jenkins konteyneri `DOCKER_HOST=tcp://docker:2376`, `DOCKER_CERT_PATH=/certs/client`, `DOCKER_TLS_VERIFY=1` env'lari bilan.

```dockerfile
FROM jenkins/jenkins:lts-jdk21
USER root
# install docker-ce-cli from Docker's apt repository (see the official guide)
USER jenkins
RUN jenkins-plugin-cli --plugins "docker-workflow configuration-as-code"
```

Aniq buyruqlar va `Dockerfile` ning to'liq matni rasmiy qo'llanmada (Manbalar), ularni o'sha yerdan oling: apt repo qadamlari vaqt o'tishi bilan o'zgaradi. `jenkins-data` ning dind konteyneriga ham ulanishi shart: Jenkins workspace yo'lini dind daemon'iga beradi, daemon o'sha yo'lni o'z fayl tizimidan qidiradi (docker modulidagi "bind mount yo'li daemon tomonda hal qilinadi" qoidasi).

Bu 3-darsdagi dind bilan bir xil kelishuv: privileged konteyner, laboratoriya uchun maqbul.

## 3. Jenkinsfile: declarative pipeline

Pipeline ta'rifi repo ildizidagi `Jenkinsfile` da, Groovy asosidagi DSL. Ikki sintaksis bor: **declarative** (qat'iy tuzilma, `pipeline { }` bloki, tavsiya qilinadi) va **scripted** (erkin Groovy, `node { }` bloki, eski va murakkab holatlar uchun).

```groovy
pipeline {
  agent any
  options { timeout(time: 15, unit: 'MINUTES') }
  stages {
    stage('Test') {
      steps { sh 'make test' }
    }
    stage('Build') {
      when { branch 'main' }
      steps { sh 'make build' }
    }
  }
  post {
    always { junit allowEmptyResults: true, testResults: 'junit.xml' }
    failure { echo 'pipeline failed' }
  }
}
```

| Blok | Vazifasi | GitHub Actions'dagi o'xshashi |
|------|----------|-------------------------------|
| `agent` | qayerda ishlaydi: `any`, `none`, `label`, `docker` | `runs-on`, `container` |
| `stages` / `stage` | ketma-ket bosqichlar | job'lar + `needs` |
| `steps` | buyruqlar: `sh`, `echo`, `checkout`, plugin step'lari | `steps` |
| `environment` | env variable'lar, `credentials()` bilan secret | `env`, `secrets` |
| `when` | shart: `branch`, `expression`, `changeset` | `if` |
| `parallel` | stage ichida parallel tarmoqlar | parallel job'lar |
| `matrix` | kombinatsiyalar | `strategy.matrix` |
| `post` | yakuniy amallar: `always`, `success`, `failure`, `cleanup` | `if: always()` / `failure()` |
| `options` | `timeout`, `retry`, `disableConcurrentBuilds`, `buildDiscarder` | `timeout-minutes`, `concurrency` |
| `triggers` | `pollSCM`, `cron` | `on` |
| `input` | qo'lda tasdiq kutish | environment approval |

- Stage'lar standart holatda **bitta agent'da, bitta workspace'da** ketma-ket ishlaydi, shuning uchun fayllar stage'lar orasida o'z-o'zidan saqlanadi. Bu GitHub/GitLab job izolyatsiyasidan farq qiladi. Har stage'ga alohida agent berilsa (`agent none` + stage darajasida `agent`), fayllarni `stash`/`unstash` bilan uzatish kerak.
- Artifact saqlash: `archiveArtifacts artifacts: 'dist/**'`.
- Foydali env variable'lar: `BUILD_NUMBER`, `GIT_COMMIT`, `BRANCH_NAME` (multibranch'da), `WORKSPACE`.
- Sintaksisni tekshirish: UI'dagi Pipeline Syntax (snippet generator) va "Replay" (oxirgi build'ni o'zgartirilgan `Jenkinsfile` bilan commit'siz qayta ishga tushirish).

### Job turlari
- **Pipeline**: bitta branch'dagi `Jenkinsfile`.
- **Multibranch Pipeline**: repo'ni skanerlaydi, `Jenkinsfile` bor har branch va PR uchun avtomatik job yaratadi. Zamonaviy standart.
- **Freestyle**: UI'da tugmalar bilan sozlanadigan eski job turi. Pipeline as code emas, eski serverlarda ko'p uchraydi, yangi ish uchun ishlatilmaydi.

### Docker agent
Docker Pipeline plugin'i bilan stage konteyner ichida bajariladi: Jenkins image'ni pull qiladi, workspace'ni ulaydi, buyruqlarni ichida ishlatadi va oxirida konteynerni o'chiradi.

```groovy
stage('Test') {
  agent { docker { image 'node:24-alpine' } }
  steps { sh 'npm ci && npm test' }
}
```

Shu bilan build asboblari agent mashinasiga o'rnatilmaydi, versiya `Jenkinsfile` da qotiriladi. Bu GitLab'dagi `image:` ning o'xshashi.

**Tuzoq: konteynerdagi foydalanuvchi.** Jenkins konteynerni o'z UID'i bilan ishga tushiradi (workspace fayllariga yozish uchun). Image ichida bu UID uchun home papka yo'q bo'lsa, `npm` kabi asboblar cache papkasiga yoza olmay yiqiladi. Yechim: `HOME` yoki asbobning cache yo'lini workspace ichiga yo'naltirish.

## 4. Plugin'lar

Jenkins'ning kuchi ham, asosiy og'rig'i ham shu. Git bilan ishlash, pipeline DSL'ning o'zi, credentials, Docker, deyarli hamma narsa plugin.

- Plugin'lar bir-biriga bog'liq va controller JVM'i ichida to'liq huquq bilan ishlaydi. Bitta zaif plugin butun serverni ochadi.
- Jenkins loyihasi muntazam security advisory chiqaradi, ularning katta qismi plugin'larga tegishli. Yangilamaslik xavfsizlik teshigi, ko'r-ko'rona yangilash esa buzilish xavfi (plugin'lar orasidagi versiya nomuvofiqligi).
- Tashlab qo'yilgan plugin'lar ko'p. O'rnatishdan oldin: oxirgi reliz qachon, ochiq security muammolari bormi, o'rnatishlar soni.
- Plugin ro'yxati kod sifatida saqlanadi: `plugins.txt` (`name:version` qatorlari) va image qurishda `jenkins-plugin-cli --plugin-file`. UI orqali qo'lda o'rnatilgan plugin'lar takrorlanmaydigan serverga olib keladi.

Amaliy qoida: plugin'lar soni minimal, mantiq `Jenkinsfile` dagi `sh` va repo'dagi skriptlarda. Har yangi plugin doimiy qarz.

## 5. Credentials

Jenkins secret'larni `JENKINS_HOME` da shifrlangan holda saqlaydi (kalit ham o'sha yerda, `secrets/` papkasida, shuning uchun `JENKINS_HOME` zaxira nusxasi secret sifatida himoyalanadi). Credential turlari: Secret text, Username with password, SSH Username with private key, Secret file, sertifikat. Har biri **ID** ga ega, pipeline shu ID orqali murojaat qiladi. Scope: global, yoki folder darajasida (faqat o'sha folder'dagi job'lar ko'radi).

```groovy
environment {
  REGISTRY = credentials('ghcr-token')
}
steps {
  sh 'echo "$REGISTRY_PSW" | docker login ghcr.io -u "$REGISTRY_USR" --password-stdin'
}
```

`credentials()` Username/password turi uchun uch variable beradi: `REGISTRY` (`user:pass`), `REGISTRY_USR`, `REGISTRY_PSW`. Torroq doira uchun `withCredentials([...]) { }` bloki: secret faqat blok ichida mavjud.

**Tuzoq: Groovy interpolatsiyasi.** `sh "docker login -p ${REGISTRY_PSW}"` (qo'sh tirnoq) da qiymatni Groovy o'zi satrga qo'yadi: secret buyruq satriga, jarayonlar ro'yxatiga tushadi va maxsus belgilar shell injection beradi. To'g'risi bir tirnoq: `sh 'docker login -p "$REGISTRY_PSW"'`, bunda qiymatni shell env'dan oladi. Bu 2-darsdagi script injection bilan bir xil mexanizm. Jenkins bunday holatda log'ga ogohlantirish yozadi.

Jenkins'da `GITHUB_TOKEN` yoki `CI_JOB_TOKEN` kabi avtomatik, qisqa yashaydigan token yo'q. Har tashqi tizim uchun credential'ni o'zingiz yaratasiz, saqlaysiz va aylantirasiz (rotation).

## 6. Configuration as Code va ekspluatatsiya yuki

### JCasC
Jenkins Configuration as Code plugin'i (`configuration-as-code`) server sozlamalarini YAML fayldan o'qiydi: xavfsizlik, foydalanuvchilar, credential'lar (qiymatlari env yoki secret manbasidan), agent'lar, tool'lar.

```yaml
jenkins:
  systemMessage: "Managed by JCasC, do not edit in UI"
  numExecutors: 0
unclassified:
  location:
    url: "http://localhost:8080/"
```

Fayl yo'li `CASC_JENKINS_CONFIG` env variable'i bilan beriladi. Setup wizard'ni o'chirish: `JAVA_OPTS=-Djenkins.install.runSetupWizard=false`. Joriy konfiguratsiyani UI'dan YAML sifatida eksport qilish mumkin (Manage Jenkins → Configuration as Code). Natija: image (Jenkins + `plugins.txt`) + `jenkins.yaml` + `Jenkinsfile` lar repo'da, server "qo'lda sozlangan noyob hayvon" emas, qayta yaratiladigan narsa.

### Kim nima uchun javobgar

| Ish | Hosted CI (Actions, gitlab.com) | Jenkins |
|-----|----------------------------------|---------|
| Serverni yangilash, xavfsizlik yamoqlari | provayder | siz (muntazam LTS relizlari, advisory'lar) |
| Plugin'lar muvofiqligi | yo'q muammo | siz |
| Zaxira va tiklash | provayder | siz (`JENKINS_HOME`) |
| Agent'lar, masshtablash, disk tozalash | provayder | siz |
| Foydalanuvchilar, SSO, huquqlar | platformada tayyor | siz (plugin'lar bilan) |
| Controller yuqori mavjudligi | provayder | open-source'da bitta controller, yagona nosozlik nuqtasi |

Jenkins litsenziyasi bepul, lekin egalik narxi muhandis vaqtida to'lanadi. O'rta kattalikdagi tashkilotda Jenkins'ga qarash ko'pincha kimningdir to'liq ish o'rni.

## 7. TeamCity

TeamCity bu JetBrains'ning tijorat CI/CD serveri. Self-hosted (On-Premises) va TeamCity Cloud variantlari bor. Self-hosted'ning bepul Professional litsenziyasi cheklangan miqdordagi build configuration va agent bilan to'liq funksional (joriy limitlarni JetBrains saytidan tekshiring). Asosiy farq Jenkins'dan: ko'p funksiya (Git, Docker, test hisobotlari, build zanjirlari, versiyalangan sozlamalar) qutidan chiqadi, plugin'larga bog'liqlik ancha kam.

### Tushunchalar

| TeamCity | Ma'nosi | O'xshashi |
|----------|---------|-----------|
| Project | build configuration'lar va sozlamalar to'plami, ichma-ich bo'lishi mumkin | folder, group |
| Build configuration | bitta "nima va qanday qurilishi" ta'rifi | job / pipeline |
| VCS root | repo'ga ulanish | checkout |
| Build step | runner turi bilan bitta qadam (Command Line, Docker, Node.js, Gradle ...) | step |
| Trigger | VCS trigger, schedule, finish build | `on` |
| Agent, agent requirements | ijrochi va uni tanlash shartlari | runner, label'lar |
| Parameters | `%name%` bilan murojaat, `env.` prefiksi env variable, password turi secret | variables, secrets |
| Snapshot dependency | "avval o'sha build, aynan shu commit'da" | `needs` |
| Artifact dependency | boshqa build artifact'ini olish | artifact download |
| Build chain | snapshot dependency'lar bilan bog'langan konfiguratsiyalar | pipeline grafi |
| Template | umumiy sozlamalar shabloni | reusable workflow |

Build chain'ning muhim xususiyati: zanjirdagi barcha build'lar bir xil commit'dan olinadi va allaqachon mos build mavjud bo'lsa u qayta ishlatiladi. Bu "build once" ni tizim darajasida ta'minlaydi.

### Docker'da ishga tushirish
Rasmiy image'lar: `jetbrains/teamcity-server` va `jetbrains/teamcity-agent`.

```
docker network create teamcity
docker run -d --name teamcity-server --network teamcity -p 8111:8111 \
  -v teamcity-data:/data/teamcity_server/datadir \
  -v teamcity-logs:/opt/teamcity/logs jetbrains/teamcity-server
docker run -d --name teamcity-agent --network teamcity \
  -e SERVER_URL="http://teamcity-server:8111" \
  -v teamcity-agent-conf:/data/teamcity_agent/conf jetbrains/teamcity-agent
```

Birinchi kirishda: data directory tasdiqlanadi, ma'lumotlar bazasi tanlanadi (sinov uchun ichki HSQLDB, production uchun tashqi PostgreSQL yoki MySQL), litsenziya qabul qilinadi, admin yaratiladi. Agent ulangach Agents sahifasida "Unauthorized" bo'limida ko'rinadi va qo'lda **authorize** qilinadi: ruxsatsiz mashina build ololmaydi. Agent ichida Docker ishlatish variantlari (socket ulash yoki dind rejimi) image'ning Docker Hub sahifasida tasvirlangan.

### Kotlin DSL
Sozlamalar UI'da tuziladi yoki repo'dagi `.teamcity/settings.kts` da Kotlin kodi sifatida saqlanadi (Versioned Settings). Odatiy yo'l: UI'da tuzib, "View as code" bilan DSL'ni ko'rish va eksport qilish.

```kotlin
object Test : BuildType({
    name = "Test"
    vcs { root(DslContext.settingsRoot) }
    steps {
        script {
            name = "Unit tests"
            scriptContent = "make test"
        }
    }
    triggers { vcs { } }
})
```

YAML'dan farqi: bu haqiqiy, statik tipli til. IDE avtoto'ldirish va xatolarni kompilyatsiya vaqtida ko'rsatadi, sikl va funksiyalar bilan o'nlab o'xshash konfiguratsiyani generatsiya qilish mumkin. Narxi: kirish to'sig'i balandroq va "konfiguratsiya" dasturga aylanib ketishi mumkin.

## 8. Qachon qaysi biri tanlanadi

| Holat | Odatiy tanlov | Sabab |
|-------|---------------|-------|
| Kod GitHub yoki GitLab'da, oddiy web servislar | o'sha platformaning CI'si | ekspluatatsiya yuki yo'q, integratsiya tayyor |
| Yopiq tarmoq, internetga chiqish yo'q, bepul bo'lishi shart | Jenkins yoki self-managed GitLab | to'liq o'z nazoratida |
| Juda turli muhitlar: mainframe, eski OS, maxsus apparat, g'alati VCS | Jenkins | deyarli hamma narsaga plugin yoki skript bilan ulanadi |
| Katta JVM/.NET/C++/o'yin loyihalari, murakkab build zanjirlari, test tahlili muhim | TeamCity | build chain, artifact qayta ishlatish, flaky test aniqlash, qulay UI |
| JetBrains ekotizimidagi jamoa, litsenziya to'lashga tayyor, plugin qarovidan qochmoqchi | TeamCity | qutidan chiqadigan funksiyalar, tijorat qo'llab-quvvatlash |
| 10 yildan beri ishlayotgan yuzlab Jenkins job | Jenkins qoladi | migratsiya narxi foydadan katta |

Amalda ko'p korxonada tanlov texnik emas, tarixiy: Jenkins allaqachon bor va ishlaydi. Sizning vazifangiz ko'pincha uni almashtirish emas, tartibga keltirish: freestyle job'larni `Jenkinsfile` ga, qo'lda sozlamalarni JCasC'ga, controller'dagi build'larni agent'larga ko'chirish.

## Tuzoqlar

- Controller'da build qilish va controller'ga Docker socket ulash: `Jenkinsfile` yozgan har kim server egasi.
- Jenkins'ni va plugin'larni yillab yangilamaslik. Internetga ochiq eski Jenkins buzib kirishning klassik yo'li.
- Jenkins UI'ni autentifikatsiyasiz yoki internetga to'g'ridan ochish. Script Console (`/script`) admin uchun serverda ixtiyoriy kod bajaradi.
- `sh "..."` ichida secret'ni Groovy interpolatsiyasi bilan ishlatish.
- `JENKINS_HOME` ni zaxiralamaslik yoki zaxirani ochiq joyda saqlash (ichida shifrlash kalitlari ham bor).
- UI'da qo'lda sozlangan freestyle job'lar: review yo'q, tarix yo'q, server yo'qolsa qayta tiklab bo'lmaydi.
- Uzun mantiqni `Jenkinsfile` ichida Groovy'da yozish. Lokal ishga tushmaydi, debug qilish og'ir. Mantiq skriptda, `Jenkinsfile` uni chaqiradi.
- Doimiy agent'da workspace va Docker image'lar to'planib disk to'lishi. `cleanWs`, `buildDiscarder` va muntazam `docker system prune` kerak.
- TeamCity'da agent'ni tekshirmasdan authorize qilish yoki ichki HSQLDB bilan production'ga chiqish.

## Manbalar

- https://www.jenkins.io/doc/book/installing/docker/ – Jenkins'ni Docker'da o'rnatish (dind sxemasi, `Dockerfile`)
- https://www.jenkins.io/doc/book/pipeline/syntax/ – declarative va scripted pipeline sintaksisi (asosiy ma'lumotnoma)
- https://www.jenkins.io/doc/book/pipeline/jenkinsfile/ – Jenkinsfile bilan ishlash, credentials, interpolatsiya xavfi
- https://www.jenkins.io/doc/book/pipeline/docker/ – pipeline'da Docker agent
- https://www.jenkins.io/doc/book/using/using-credentials/ – credentials
- https://www.jenkins.io/doc/book/security/controller-isolation/ – controller izolyatsiyasi
- https://www.jenkins.io/doc/book/managing/casc/ – Configuration as Code
- https://github.com/jenkinsci/docker – rasmiy image, `jenkins-plugin-cli`, `plugins.txt`
- https://www.jenkins.io/security/advisories/ – security advisory'lar
- https://www.jetbrains.com/help/teamcity/teamcity-documentation.html – TeamCity hujjati
- https://www.jetbrains.com/help/teamcity/kotlin-dsl.html – Kotlin DSL
- https://hub.docker.com/r/jetbrains/teamcity-server – server image
- https://hub.docker.com/r/jetbrains/teamcity-agent – agent image, Docker ishlatish variantlari

---

## Vazifalar

`Jenkinsfile` `cicd-demo` reposida (alohida `jenkins` branch'ida yoki `main` da) turadi. Javoblar `cicd/04-jenkins-teamcity/` da (yaratish: `make new m=cicd n=04 name=jenkins-teamcity`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi (console output parchasi) va o'z so'zingiz bilan izoh. `Dockerfile`, `plugins.txt`, `jenkins.yaml`, `Jenkinsfile` nusxasi va TeamCity DSL eksporti shu papkada saqlanadi.

### A. Jenkins: server

1. **Run Jenkins.** Jenkins'ni 2-bo'limdagi eng sodda buyruq bilan ko'taring, setup wizard'dan o'ting (tavsiya etilgan plugin'lar). `docker exec` bilan `/var/jenkins_home` ichini ko'rib chiqing: `config.xml`, `jobs/`, `plugins/`, `secrets/` nima saqlaydi? Konteynerni o'chirib qayta yarating: sozlamalar saqlanib qoldimi va nima uchun?

2. **Freestyle job.** UI'da freestyle job yarating: `cicd-demo` ni klonlab `ls` va `cat package.json` qiladigan shell qadam. Ishga tushiring. Bu job ta'rifi diskda qayerda va qanday formatda saqlanganini toping. Pipeline as code nuqtai nazaridan bunda nima yomon?

3. **Custom image with Docker.** Rasmiy qo'llanma bo'yicha: `jenkins` tarmog'i, `docker:dind` konteyneri, `docker-ce-cli` va `plugins.txt` (versiyalari qotirilgan `docker-workflow`, `configuration-as-code` va boshqa keraklilari) bilan o'z image'ingiz. Jenkins'ni shu image'dan, oldingi `jenkins-data` volume'i bilan qayta ko'taring. Konteyner ichidan `docker version` server qismini ko'rsatayotganini tekshiring. `jenkins-data` nima uchun dind konteyneriga ham ulanishini izohlang.

4. **Controller executors.** Manage Jenkins → Nodes'da built-in node'ning executor sonini toping. Uni 0 qilsangiz va agent bo'lmasa build bilan nima bo'ladi (sinab ko'ring, navbatdagi xabarni yozing)? Laboratoriya uchun qaytarib qo'ying va production'da nima uchun 0 bo'lishi kerakligini aniq hujum ssenariysi bilan izohlang.

### B. Jenkins: pipeline

5. **First Jenkinsfile.** `Jenkinsfile` yozing: `Lint` va `Test` stage'lari `Makefile` target'larini chaqiradi. Pipeline job yarating ("Pipeline script from SCM"). Ishga tushirib Stage View va console output'ni ko'ring. Checkout qayerda sodir bo'ldi (siz yozmagan stage)?

6. **Docker agent.** `Test` stage'ini `agent { docker { image 'node:...' } }` bilan konteynerda ishlating (bu holda `make` o'rniga to'g'ridan `npm` buyruqlari kerak bo'lishi mumkin, 3-darsdagi 2-vazifani eslang). Console output'dan Jenkins konteynerni qanday `docker run` argumentlari bilan ishga tushirganini toping. Foydalanuvchi/UID bilan bog'liq xato chiqsa, uni yozing va tuzating.

7. **Break and read.** Testni buzing va build'ni ishga tushiring. Qaysi stage qizil, keyingilari qanday holatda? `post { failure { ... } always { ... } }` qo'shib ikkala blok qachon ishlashini ko'rsating. JUnit hisobotini `junit` step'i bilan e'lon qiling va Test Result sahifasini tasvirlang.

8. **Polling trigger.** `triggers { pollSCM('H/2 * * * *') }` qo'shing, commit push qiling va build o'zi boshlanishini kuting. `H` nimani anglatadi? Nima uchun laboratoriyada webhook ishlamaydi va production'da polling o'rniga webhook afzal?

9. **Parallel and stash.** `Lint` va `Test` ni `parallel` blokiga oling. Keyin `agent none` qilib har stage'ga alohida `agent` bering va bitta stage'da yaratilgan faylni keyingisida o'qishga urinib ko'ring. Xatoni yozing, `stash`/`unstash` bilan tuzating. Bu GitHub Actions'dagi qaysi mexanizmning o'xshashi?

10. **Credentials.** GitHub'da faqat `write:packages` huquqli, qisqa muddatli PAT yarating va Jenkins'ga "Username with password" credential sifatida qo'shing. `Build` stage'i image'ni qurib `ghcr.io/<owner>/cicd-demo:<GIT_COMMIT>` ga push qilsin. Console output'da token ko'rinmasligini tekshiring. GitHub Actions'dagi `GITHUB_TOKEN` bilan solishtirganda bu yerda qanday qo'shimcha javobgarlik paydo bo'ldi?

11. **Groovy interpolation trap.** Vaqtincha `sh "echo ${REGISTRY_PSW} | wc -c"` (qo'sh tirnoq) yozib ishga tushiring: Jenkins log'da qanday ogohlantirish berdi? Bir tirnoqqa o'zgartirib farqni izohlang: qiymatni kim va qachon joyiga qo'yadi?

12. **Manual gate.** `Deploy production` stage'i qo'shing: `input` bilan tasdiq kutadi, keyin `echo`. `when { branch }` oddiy Pipeline job'da kutilgandek ishlaydimi? Tekshiring, kerak bo'lsa Multibranch Pipeline job yarating va branch'lar qanday aniqlanganini ko'rsating. `input` kutayotgan paytda executor band bo'ladimi va buni qanday oldini olish mumkin?

13. **JCasC.** Joriy konfiguratsiyani UI'dan YAML sifatida eksport qiling va o'qing. Minimal `jenkins.yaml` yozing (system message, executor soni, bitta credential qiymati env variable'dan). **Yangi** volume bilan, setup wizard o'chirilgan holda Jenkins'ni ko'taring: qo'lda hech narsa bosmasdan sozlangan server olasiz. Qaysi qismlar hali ham kod emasligini (job'lar?) va uni qanday yopish mumkinligini yozing.

14. **Upkeep audit.** Manage Jenkins → Plugins'da nechta plugin o'rnatilgan va nechtasida yangilanish bor? Jenkins security advisories sahifasidan oxirgi ikki advisory'ni oching: nechta plugin tilga olingan, sizda o'rnatilganlari bormi? `JENKINS_HOME` ni zaxiralash rejasini 5–6 gapda yozing: nima, qanchalik tez-tez, qayerga, tiklashni qanday sinaysiz.

### C. TeamCity

15. **Run TeamCity.** Jenkins konteynerlarini to'xtating. TeamCity server va agent'ni 7-bo'limdagi buyruqlar bilan ko'taring, birinchi sozlashdan o'ting (ichki baza), agent'ni authorize qiling. Agent sahifasida uning parametrlarini ko'ring: TeamCity agent haqida nimalarni avtomatik aniqlagan? Authorize qadami nimadan himoya qiladi?

16. **Build configuration.** `cicd-demo` uchun project va build configuration yarating (repo URL'dan). TeamCity build step'larni avtomatik taklif qildimi? Command Line step bilan test'ni ishga tushiring (agent'da `make`, Node yoki Docker bor-yo'qligini avval tekshiring va yo'qligini qanday hal qilganingizni yozing). VCS trigger qo'shing va commit bilan sinang. Testni buzib build sahifasidagi xato ko'rinishini Jenkins'niki bilan taqqoslang.

17. **Build chain.** Ikkinchi konfiguratsiya (`Package`: fayllarni arxivlab artifact qiladi) yarating va uni birinchisiga snapshot dependency bilan bog'lang. `Package` ni ishga tushiring: `Test` nima bo'ldi? Yana bir marta, kod o'zgarmagan holda ishga tushiring: `Test` qayta ishladimi? Sababini va bu "build once" bilan qanday bog'liqligini izohlang.

18. **Kotlin DSL.** "View as code" orqali konfiguratsiyaning Kotlin DSL ko'rinishini oching va eksport qilib ish papkasiga saqlang. Faylda project, VCS root, build type, step, trigger va dependency qayerda ekanini belgilang. YAML (`ci.yml`) va Groovy (`Jenkinsfile`) bilan taqqoslab, tipli DSL'ning bitta afzalligi va bitta kamchiligini yozing.

### D. Xulosa

19. **Four-way comparison.** To'rt tizim bo'yicha jadval: "noldan birinchi yashil pipeline'gacha" ketgan vaqtingiz, pipeline fayli hajmi, secret/token modeli, build'ni konteynerda ishlatish qanchalik oson, xatoni topish qulayligi, siz bajargan ekspluatatsiya ishlari. Oxirida: 20 kishilik GitHub'dagi jamoaga nimani tavsiya qilasiz va qaysi holatda fikringiz o'zgaradi?

### Topshirish

Tayyor bo'lgach:
1. Jenkins'da to'liq pipeline (lint, test, build va push, manual gate) yashil, console output'da secret yo'q.
2. Ish papkasida `Dockerfile`, `plugins.txt`, `jenkins.yaml`, `Jenkinsfile`, TeamCity DSL eksporti va `README.md` bor.
3. PAT GitHub'da bekor qilingan.
4. Barcha konteynerlar, volume'lar (`jenkins-data`, `jenkins-docker-certs`, `teamcity-*`) va network'lar o'chirilgan, `docker ps -a` va `docker volume ls` bilan tekshirilgan.
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
