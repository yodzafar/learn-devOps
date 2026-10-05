# 3-dars: GitLab CI

Maqsad: GitLab CI modelini tushunish va 2-darsdagi pipeline'ni unga ko'chirish. GitLab ko'p kompaniyalarda (ayniqsa self-managed ko'rinishda, ichki tarmoqda) asosiy platforma, shuning uchun uni o'qiy va yoza olish kerak. Model GitHub Actions'dan bir necha joyda tubdan farq qiladi: stage'lar birinchi darajali tushuncha, job'lar standart holatda konteynerda ishlaydi, shartlar `rules` bilan yoziladi, runner'ni o'zingiz ulash oddiy ish. Shu darsda o'z runner'ingizni Docker'da ko'tarasiz, bu 4-darsdagi Jenkins agent'lari va 5-darsdagi deploy uchun ham asos.

Taxminiy vaqt: 3 kun (siz uchun). Tushunchalar 2-darsdan tanish, diqqatni farqlarga qarating: stage va `needs`, `rules` va takroriy pipeline muammosi, cache va artifacts ning GitLab'dagi xatti-harakati, executor turlari, Docker-in-Docker va uning narxi, protected variable'lar.

## Laboratoriya

- gitlab.com akkaunt (free tier). Yangi akkauntda hosted runner'lardan foydalanish uchun shaxsni tasdiqlash (telefon yoki karta) so'ralishi mumkin. Tasdiqlashni xohlamasangiz, B guruhidagi o'z runner'ingizni avval ulab, hamma job'ni unda ishlating.
- gitlab.com'da `cicd-demo` nomli bo'sh loyiha yarating va uni mavjud repo'ga ikkinchi remote sifatida ulang: `git remote add gitlab git@gitlab.com:<user>/cicd-demo.git`. SSH kalitni GitLab profilingizga qo'shing (git modulidagi kabi). Bitta kod bazasi, ikki CI: GitHub workflow'lari GitLab'da e'tiborga olinmaydi va aksincha.
- Self-hosted runner ish mashinasida Docker konteynerida, konfiguratsiyasi named volume'da. Ish mashinasiga paket o'rnatilmaydi.
- Self-managed GitLab (o'z serveringizda `gitlab/gitlab-ce` image yoki Linux paketi) o'rnatilmaydi: u bir necha GB RAM talab qiladi va bu dars maqsadi uchun gitlab.com yetarli. Pipeline sintaksisi ikkalasida bir xil.
- Ish papkasi `cicd/03-gitlab-ci/`: `README.md`, `.gitlab-ci.yml` nusxasi, pipeline havolalari.
- Tozalash: runner konteyneri va volume'ini o'chiring, GitLab'da runner'ni loyihadan olib tashlang, sinov image'larini registry'dan o'chiring.

Pipeline faylini tekshirish: GitLab UI'da Build → Pipeline editor (sintaksis tekshiruvi va to'liq yoyilgan konfiguratsiya ko'rinishi bor).

---

## 1. .gitlab-ci.yml tuzilishi

Bitta fayl, repo ildizida. Yuqori darajadagi kalitlarning ko'pi job, maxsus kalit so'zlar esa global sozlama (`stages`, `variables`, `default`, `workflow`, `include`).

```yaml
stages: [lint, test, build]

default:
  image: node:24-alpine

unit:
  stage: test
  script:
    - npm ci
    - npm test
```

- **Stage'lar tartib bilan** bajariladi, bitta stage ichidagi job'lar parallel. Stage'dagi biror job yiqilsa keyingi stage boshlanmaydi. `stages` yozilmasa standart: `.pre`, `build`, `test`, `deploy`, `.post`.
- Job'ning majburiy qismi `script`. `before_script` va `after_script` ham bor, `after_script` job yiqilsa ham ishlaydi (alohida shell'da).
- Hosted runner'larda job standart holatda **konteyner ichida** ishlaydi, `image` qaysi image ekanini belgilaydi. GitHub Actions'da esa standart holat VM, konteyner ixtiyoriy.
- Repo avtomatik klonlanadi, `checkout` qadami yo'q. Chuqurlik `GIT_DEPTH`, strategiya `GIT_STRATEGY` variable'lari bilan boshqariladi.
- Nuqta bilan boshlanadigan job (`.base`) yashirin: ishga tushmaydi, shablon sifatida ishlatiladi.

### needs va DAG
`needs` stage tartibini aylanib o'tadi: job ko'rsatilgan job'lar tugashi bilan boshlanadi, oldingi stage to'liq tugashini kutmaydi.

```yaml
build-image:
  stage: build
  needs: [unit, lint]
```

`needs` dagi job'larning artifact'lari avtomatik yuklab olinadi. `needs: []` bo'lsa job darhol, birinchi stage bilan birga boshlanadi. Katta pipeline'larda bu sezilarli tezlashtiradi: sekin job tezlarini to'sib turmaydi.

## 2. rules va workflow

`rules` job pipeline'ga qo'shiladimi yoki yo'qmi, shuni hal qiladi. Qoidalar yuqoridan pastga tekshiriladi, birinchi mos kelgani ishlaydi, hech biri mos kelmasa job qo'shilmaydi.

```yaml
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
    - when: never
```

| Kalit | Ma'nosi |
|-------|---------|
| `if` | CI variable'lari ustidagi shart (`==`, `!=`, `=~`, `&&`, `\|\|`) |
| `changes` | ko'rsatilgan yo'llardagi fayllar o'zgarganmi |
| `exists` | repo'da fayl bormi |
| `when` | `on_success` (standart), `manual`, `always`, `never`, `delayed` |
| `allow_failure` | job yiqilsa pipeline davom etadimi |

Eski `only`/`except` kalitlari eski loyihalarda uchraydi, yangi kodda `rules` ishlatiladi. Bitta job'da ikkalasini aralashtirib bo'lmaydi.

### Pipeline turlari va takroriy pipeline
Branch'ga push branch pipeline yaratadi. Merge request ochiq bo'lsa va job'larda `$CI_PIPELINE_SOURCE == "merge_request_event"` sharti bo'lsa, merge request pipeline ham yaratiladi. Natija: bitta push'ga ikki pipeline.

**Tuzoq: duplicate pipelines.** Yechim global `workflow: rules`, u butun pipeline yaratilishini boshqaradi:

```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH
```

Ma'nosi: MR pipeline'ga ruxsat, ochiq MR'i bor branch uchun branch pipeline yo'q, qolgan branch'lar uchun bor.

## 3. Variable'lar

Uch manba: GitLab beradigan predefined variable'lar, `.gitlab-ci.yml` dagi `variables`, va UI'dagi (Settings → CI/CD → Variables) loyiha, guruh yoki instance variable'lari. Hammasi job'ga oddiy env variable bo'lib tushadi, `${{ }}` kabi alohida expression tili yo'q.

| Predefined variable | Qiymati |
|---------------------|---------|
| `CI_COMMIT_SHA`, `CI_COMMIT_SHORT_SHA` | commit hash |
| `CI_COMMIT_BRANCH`, `CI_DEFAULT_BRANCH` | joriy va default branch |
| `CI_PIPELINE_SOURCE` | `push`, `merge_request_event`, `schedule`, `web`, `api` ... |
| `CI_REGISTRY`, `CI_REGISTRY_IMAGE` | registry manzili va loyiha image yo'li |
| `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` | job davomida amal qiladigan registry login'i |
| `CI_JOB_TOKEN` | job tokeni, job tugashi bilan bekor bo'ladi |
| `CI_PROJECT_DIR` | repo klonlangan papka |

UI'dagi variable xususiyatlari:

- **Protected**: faqat protected branch va tag'lardagi pipeline'ga beriladi. Production secret'lari shunday bo'lishi shart, aks holda istalgan branch'ga push qila oladigan odam `.gitlab-ci.yml` ni o'zgartirib secret'ni o'qiydi.
- **Masked**: log'da yashiriladi (qiymat formatiga talablar bor). "Masked and hidden" varianti UI'da ham qayta ko'rsatilmaydi.
- **File** turi: qiymat vaqtinchalik faylga yoziladi, variable esa fayl yo'lini saqlaydi. SSH kalit, kubeconfig, sertifikat uchun.
- **Environment scope**: variable faqat ko'rsatilgan environment'ga deploy qiladigan job'ga beriladi.

**Tuzoq: `.gitlab-ci.yml` dagi `variables` secret emas.** U repo'da ochiq turadi. U yerga faqat konfiguratsiya yoziladi.

## 4. Cache va artifacts

Tushuncha 1-darsdagi bilan bir xil, lekin GitLab'dagi xatti-harakatda farqlar bor:

| | cache | artifacts |
|-|-------|-----------|
| Saqlanadi | runner'da (lokal disk yoki sozlangan obyekt ombori) | GitLab serverida |
| Kafolat | yo'q: boshqa runner'da cache bo'lmasligi mumkin | bor |
| Keyingi job'larga | bir xil kalitli job'lar, pipeline'lar orasida | keyingi stage job'lariga avtomatik (yoki `needs`/`dependencies` bo'yicha) |
| Muddat | runner siyosatiga bog'liq | `expire_in` |

```yaml
unit:
  cache:
    key:
      files: [package-lock.json]
    paths: [.npm/]
  script:
    - npm ci --cache .npm --prefer-offline
  artifacts:
    when: always
    reports:
      junit: junit.xml
    expire_in: 1 week
```

- Cache yo'llari loyiha papkasi ichida bo'lishi kerak, shuning uchun npm cache `.npm/` ga yo'naltiriladi.
- `cache:policy`: `pull-push` (standart), `pull` (faqat o'qiydi, job tezroq tugaydi), `push`.
- `artifacts:reports:junit` test natijalarini MR sahifasida va pipeline'ning Tests yorlig'ida ko'rsatadi.
- `dependencies: []` keraksiz artifact'larni yuklab olmaslik uchun.

**Tuzoq: bir nechta runner va lokal cache.** Har runner o'z lokal cache'iga ega. Job har safar boshqa runner'ga tushsa cache deyarli ishlamaydi. Yechim: umumiy (distributed) cache yoki cache'ga tayanmaydigan dizayn.

## 5. Services

`services` job yonida qo'shimcha konteyner ko'taradi, job undan tarmoq orqali foydalanadi. Integration testlar uchun:

```yaml
integration:
  image: node:24-alpine
  services:
    - name: postgres:17-alpine
      alias: db
  variables:
    POSTGRES_PASSWORD: test
    DATABASE_URL: postgres://postgres:test@db:5432/postgres
  script:
    - npm run test:integration
```

Service'ga `alias` nomi (yoki image nomidan hosil bo'lgan hostname) orqali murojaat qilinadi. Job'ning `variables` qiymatlari service konteyneriga ham uzatiladi. Service tayyor bo'lishini kutish kafolatlanmaydi, test o'zi retry bilan ulanishi kerak.

### Docker image qurish
Job konteyner ichida ishlaydi, unda Docker daemon yo'q. Keng tarqalgan yechim Docker-in-Docker (dind): `docker:dind` service sifatida ko'tariladi, job undagi daemon bilan gaplashadi.

```yaml
build-image:
  image: docker:27
  services: [docker:27-dind]
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
```

- dind **privileged** konteyner talab qiladi. gitlab.com hosted runner'larida bu yoqilgan, o'z runner'ingizda `config.toml` da `privileged = true` qilish kerak.
- Privileged konteyner host'dan amalda izolyatsiyalanmagan (docker modulidagi capabilities mavzusi). Ishonchsiz kod ishlaydigan runner'da bu jiddiy xavf.
- Har job'da dind daemon noldan boshlanadi, layer cache yo'q. Tezlashtirish: `docker build --cache-from` bilan registry'dagi oldingi image'dan foydalanish.
- Muqobillar: host'ning `/var/run/docker.sock` ni job'ga ulash (tez, lekin job host'da root huquqiga ega bo'ladi) yoki daemon talab qilmaydigan builder'lar (BuildKit rootless, Buildah). Qaysi biri mos kelishi runner'ga kimning kodi tushishiga bog'liq.

## 6. include, extends va shablonlar

Takrorlanishni kamaytirish vositalari:

| Vosita | Nima qiladi |
|--------|-------------|
| `extends: .base` | yashirin job'dan kalitlarni meros oladi (chuqur birlashtirish) |
| `!reference [.base, script]` | boshqa job'ning bitta kalitini joyiga qo'yadi |
| YAML anchor (`&`, `*`) | faqat bitta fayl ichida ishlaydi |
| `include: local` | shu repo'dagi boshqa YAML fayl |
| `include: project` | boshqa loyihadagi fayl (`ref` bilan versiyalanadi) |
| `include: template` | GitLab bilan keladigan tayyor shablonlar |
| `include: component` | CI/CD Catalog'dagi versiyalangan komponent, `inputs` bilan |
| `include: remote` | ixtiyoriy URL |

`include: project` va `component` GitHub'dagi reusable workflow'ning o'rnini bosadi: platforma jamoasi umumiy pipeline'ni bitta loyihada saqlaydi, boshqa loyihalar uni `ref` bilan ulaydi.

**Tuzoq: `include: remote` va versiyasiz `include: project`.** Bu 2-darsdagi tag bilan pin qilingan action bilan bir xil muammo: begona, o'zgaruvchan kod sizning secret'laringiz bilan ishlaydi. `ref` ni tag yoki commit SHA bilan qotiring.

Trigger bilan bog'liq yana ikki kalit: `interruptible: true` (yangi pipeline kelganda eski job bekor qilinishi mumkin, GitHub'dagi `cancel-in-progress` ga o'xshash) va `resource_group: production` (shu guruhdagi job'lardan bir vaqtda faqat bittasi ishlaydi, deploy'lar uchun).

## 7. Environments

```yaml
deploy-prod:
  stage: deploy
  script: ./deploy.sh
  environment:
    name: production
    url: https://app.example.com
  resource_group: production
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
```

- `environment` job'ni deployment sifatida belgilaydi. Operate → Environments sahifasida har environment'da qaysi commit turgani va deployment tarixi ko'rinadi, u yerdan oldingi deployment'ni qayta ishga tushirish (rollback) mumkin.
- `when: manual` job'ni tugma bilan ishga tushiriladigan qiladi. Free tarifda approval shu orqali qilinadi.
- **Protected environments** (kim deploy qila olishini cheklash) va deployment approval qoidalari pulli tarifda. Free tarifda yaqin o'rinbosar: protected branch (kim `main` ga merge qila oladi) va protected variable'lar.
- Dinamik environment'lar: `name: review/$CI_COMMIT_REF_SLUG` har branch uchun alohida muhit, `on_stop` va `auto_stop_in` bilan tozalanadi (review apps).

## 8. Runner'lar

GitLab Runner bu alohida dastur (Go'da yozilgan bitta binary). U GitLab'ga ulanib job so'raydi (polling, chiquvchi ulanish), bajaradi va log qaytaradi. Uch daraja: instance (gitlab.com'da hosted runner'lar shu), group, project.

### Executor turlari
Executor runner job'ni qayerda va qanday bajarishini belgilaydi:

| Executor | Job qayerda ishlaydi | Izolyatsiya | Qachon |
|----------|----------------------|-------------|--------|
| `shell` | runner o'rnatilgan mashinada, to'g'ridan | yo'q, job'lar orasida holat qoladi | oddiy, lekin iflos va xavfli |
| `docker` | har job uchun yangi konteyner | konteyner darajasida | eng ko'p tarqalgan tanlov |
| `docker-autoscaler` | talabga qarab yaratiladigan cloud VM'lardagi konteynerlar | VM darajasida | katta hajm, hosted runner'larga o'xshash |
| `kubernetes` | har job uchun pod | pod darajasida | klaster bor joyda |
| `ssh`, `virtualbox`, `instance` | uzoq mashina yoki VM | turlicha | maxsus holatlar |

### Docker'da runner ko'tarish va ro'yxatdan o'tkazish
Runner'ning o'zi konteynerda ishlaydi va host'ning Docker socket'i orqali job konteynerlarini yaratadi:

```
docker volume create gitlab-runner-config
docker run -d --name gitlab-runner --restart unless-stopped \
  -v gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

Ro'yxatdan o'tkazish ikki qadam. Avval GitLab UI'da (loyiha → Settings → CI/CD → Runners → New project runner) runner yaratiladi: tag'lar va "run untagged jobs" belgilanadi, natijada `glrt-` bilan boshlanadigan runner authentication token beriladi. Keyin:

```
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive --url https://gitlab.com --token "<glrt-token>" \
  --executor docker --docker-image alpine:latest
```

Sozlamalar `/etc/gitlab-runner/config.toml` ga yoziladi: `concurrent` (bir vaqtda nechta job), `[[runners]]` bloklari, `[runners.docker]` ichida `privileged`, `volumes`, `pull_policy`. Tekshirish: `docker exec gitlab-runner gitlab-runner list` va `verify`.

Job'ni aniq runner'ga yo'naltirish `tags` bilan: `tags: [local]`.

**Tuzoq: socket ulangan runner.** Bu sozlamada runner (va `volumes` ga socket qo'shilsa, job ham) host Docker'ini to'liq boshqaradi, ya'ni host'da root. Shaxsiy laboratoriya uchun maqbul, begona MR'lar tushadigan runner uchun yo'q. 2-darsdagi self-hosted runner xavflari bu yerda ham to'liq amal qiladi.

## 9. Container registry

Har GitLab loyihasida o'rnatilgan registry bor: `registry.gitlab.com/<namespace>/<project>`. Job ichida `CI_REGISTRY_USER`/`CI_REGISTRY_PASSWORD` (yoki `CI_JOB_TOKEN`) bilan login qilinadi, alohida secret kerak emas. Bu GHCR va `GITHUB_TOKEN` juftligining o'xshashi. Serverdan pull qilish uchun **deploy token** (`read_registry` scope) yaratiladi: u shaxsga emas, loyihaga bog'langan. Eski tag'larni avtomatik o'chirish uchun cleanup policy sozlanadi.

## 10. GitHub Actions bilan taqqos

| | GitHub Actions | GitLab CI |
|-|----------------|-----------|
| Fayl | bir nechta workflow fayli | bitta `.gitlab-ci.yml` (+ `include`) |
| Tartib | faqat `needs` | `stages` + `needs` |
| Standart muhit | VM | konteyner (`image`) |
| Kodni olish | `actions/checkout` | avtomatik |
| Shartlar | `on:` + `if:` expression | `rules:` + `workflow:rules` |
| Qayta ishlatish | action, reusable workflow | `extends`, `include`, component |
| Token | `GITHUB_TOKEN` + `permissions` | `CI_JOB_TOKEN` |
| Secret himoyasi | environment secrets, fork cheklovi | protected, masked, environment scope |
| Approval | environment required reviewers | `when: manual`, protected environments (pulli) |
| O'z runner | mumkin, ikkinchi darajali yo'l | birinchi darajali, executor tanlovi bilan |

## Tuzoqlar

- Production secret'ini protected qilmaslik. Istalgan branch'dan `.gitlab-ci.yml` ni o'zgartirib o'qib olish mumkin.
- `workflow: rules` siz MR pipeline qo'shish: har push'ga ikki pipeline, ikki barobar daqiqa.
- Cache'ga artifact kabi tayanish. Boshqa runner'da cache yo'q, job yiqiladi.
- `artifacts: paths` ga butun loyiha papkasini yoki `.env` ni qo'shish.
- `shell` executor'li umumiy runner: job'lar bir-birining fayllarini va host'ni ko'radi.
- Privileged dind yoki socket ulangan runner'ga ishonchsiz kod tushirish.
- `rules` oxirida kutilmagan standart: hech bir qoida mos kelmasa job jimgina yo'qoladi, pipeline esa "yashil".
- `include` ni versiyasiz ulash.
- Deploy job'ida `resource_group` yo'qligi: ikki pipeline bir vaqtda deploy qiladi.

## Manbalar

- https://docs.gitlab.com/ci/yaml/ – `.gitlab-ci.yml` kalitlari bo'yicha to'liq ma'lumotnoma (asosiy)
- https://docs.gitlab.com/ci/jobs/job_rules/ – `rules`
- https://docs.gitlab.com/ci/yaml/workflow/ – `workflow: rules`, takroriy pipeline'lar
- https://docs.gitlab.com/ci/variables/predefined_variables/ – predefined variable'lar
- https://docs.gitlab.com/ci/caching/ – cache va artifacts farqi
- https://docs.gitlab.com/ci/services/ – services
- https://docs.gitlab.com/ci/docker/using_docker_build/ – Docker image qurish usullari va xavflari
- https://docs.gitlab.com/ci/environments/ – environments
- https://docs.gitlab.com/runner/executors/ – executor turlari
- https://docs.gitlab.com/runner/install/docker/ – runner'ni Docker'da ishga tushirish
- https://docs.gitlab.com/runner/register/ – ro'yxatdan o'tkazish
- https://docs.gitlab.com/user/packages/container_registry/ – container registry

---

## Vazifalar

Pipeline `cicd-demo` reposida (`gitlab` remote) yoziladi. Javoblar `cicd/03-gitlab-ci/` da (yaratish: `make new m=cicd n=03 name=gitlab-ci`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, pipeline havolasi, log'ning muhim qismi va o'z so'zingiz bilan izoh. `.gitlab-ci.yml` ning yakuniy nusxasini va `config.toml` ni (token'siz) shu papkaga saqlang.

### A. Pipeline asoslari

1. **Second remote.** gitlab.com'da bo'sh `cicd-demo` loyihasini yarating, `gitlab` remote qo'shing va `main` ni push qiling. `git remote -v` natijasini yozing. `.github/workflows/` GitLab'da nima qilishini (yoki qilmasligini) tekshiring.

2. **First pipeline.** `.gitlab-ci.yml` yozing: `lint` va `test` stage'lari, job'lar `node` image'ida `Makefile` target'larini yoki ularning ichidagi buyruqlarni chaqirsin. Diqqat: 1-darsdagi `Makefile` Node'ni `docker run` orqali ishlatadi, job esa allaqachon konteyner ichida. Bu ziddiyatni qanday hal qilganingizni yozing (Makefile'ni ikkala muhitda ishlaydigan qilish 1-darsdagi "mantiq YAML'da emas" qoidasining sinovi).

3. **Stages vs needs.** Uchinchi `build` stage'i qo'shing (hozircha `echo`). `lint` ga `sleep 60` qo'yib, `build` ni avval oddiy stage tartibida, keyin `needs: [unit]` bilan ishga tushiring. Pipeline grafini ikkala holatda tasvirlang: `build` qachon boshlandi?

4. **Rules.** Shunday qiling: `lint` va `test` MR'da va `main` da ishlaydi, `build` faqat `main` da, `docs/` yoki `*.md` o'zgargan commit'larda `test` ishlamaydi (`changes`). Har holat uchun pipeline'da qaysi job'lar paydo bo'lganini ko'rsating. Hech bir qoida mos kelmaganda job bilan nima bo'lishini sinab ko'ring.

5. **Duplicate pipelines.** MR oching va `workflow: rules` siz, job'larda MR sharti bor holatda push qiling: nechta pipeline yaratildi? 2-bo'limdagi `workflow: rules` ni qo'shing va qayta tekshiring. Har qoida qatorini o'z so'zingiz bilan izohlang.

6. **Variables.** Bitta job'da `env | grep ^CI_ | sort` chiqaring va 10 ta eng foydali predefined variable'ni tanlab izohlang. UI'da ikki variable yarating: biri masked, biri protected. Feature branch'dagi job'da protected variable qiymati nima? Maskalangan qiymatni `rev` orqali chop etib ko'ring, so'ng variable'larni o'chiring.

7. **Cache vs artifacts.** `test` job'iga `package-lock.json` ga bog'langan npm cache va JUnit hisobotini `artifacts:reports:junit` sifatida qo'shing. Ikki ketma-ket pipeline'da cache log qatorlarini taqqoslang. Testni buzib, MR sahifasida test hisoboti qanday ko'rinishini yozing. Cache'ni UI'dan tozalab, pipeline baribir o'tishini ko'rsating.

8. **Services.** Integration test job'i yozing: `postgres` (yoki `redis`) service'i `alias` bilan, test unga ulanib bitta so'rov bajaradi (ilovaga minimal kod qo'shish mumkin yoki `psql`/`redis-cli` image'idan foydalaning). Service hostname qayerdan kelishini va service tayyor bo'lmasdan test boshlansa nima bo'lishini izohlang.

### B. Runner

9. **Runner in Docker.** 8-bo'limdagi buyruqlar bilan runner konteynerini ko'taring, UI'da project runner yaratib `local` tag'i bilan ro'yxatdan o'tkazing. `gitlab-runner list` va `config.toml` ni (token'ni yashirib) `README.md` ga qo'ying. Runner GitLab bilan qaysi yo'nalishda ulanadi va nima uchun ish mashinangizda port ochish kerak emas?

10. **Route by tags.** Bitta job'ga `tags: [local]` qo'ying va u sizning runner'ingizda ishlaganini job log'ining boshidan isbotlang. Job ishlayotganda host'da `docker ps` qiling: qanday konteynerlar paydo bo'ldi? Runner konteynerini to'xtatib pipeline ishga tushiring: job qanday holatda turadi va qancha?

11. **Executor isolation.** Runner'da ikki job ketma-ket ishlating: birinchisi `/tmp/leak.txt` va loyiha papkasida commit qilinmagan fayl yaratadi, ikkinchisi ularni qidiradi. `docker` executor'da nima saqlanib qoldi, nima yo'q? `shell` executor'da natija qanday bo'lar edi (hujjat asosida, o'rnatmasdan)?

12. **Runner concurrency.** `config.toml` da `concurrent` ni 1 va keyin 3 qilib, uchta parallel job'li stage'ni ishga tushiring. Umumiy vaqtni taqqoslang. O'zgarishdan keyin runner'ni qayta ishga tushirish kerak bo'ldimi?

### C. Image va ko'chirish

13. **Build with dind.** `build-image` job'ini dind bilan yozing: image'ni `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA` ga push qilsin, faqat `main` da. Avval hosted runner'da ishga tushiring. Keyin o'z runner'ingizda (`tags: [local]`): `privileged` yoqilmagan holatda xatoni o'qing va yozing, so'ng `config.toml` ni tuzating. Privileged rejim nimaga ruxsat berishini docker modulidagi bilim bilan izohlang.

14. **Registry and deploy token.** Push qilingan image'ni UI'da (Deploy → Container registry) toping. `read_registry` scope'li deploy token yarating va u bilan lokal mashinada `docker login registry.gitlab.com` qilib image'ni pull qiling. Deploy token shaxsiy access token'dan nimasi bilan yaxshiroq? Oxirida `docker logout` va token'ni bekor qiling.

15. **Environments.** `deploy-staging` (avtomatik) va `deploy-production` (`when: manual`, `resource_group`) job'larini `echo` bilan qo'shing, ikkalasi `environment` e'lon qilsin. Environments sahifasida deployment tarixini ko'rsating. Oldingi deployment'ni UI'dan qayta ishga tushiring (rollback tugmasi) va u aslida qaysi job'ni qaysi commit bilan ishga tushirganini yozing.

16. **Include and extends.** Takrorlanuvchi qismlarni (`image`, cache, `before_script`) yashirin `.node` job'iga chiqarib `extends` bilan ishlating. Keyin job'larning bir qismini `ci/build.yml` ga ko'chirib `include: local` bilan ulang. Pipeline editor'dagi to'liq yoyilgan konfiguratsiyani ko'rib, birlashtirish natijasi kutganingizdek ekanini tekshiring.

17. **Port and compare.** Yakuniy `.gitlab-ci.yml`: 2-darsdagi to'liq pipeline'ning ekvivalenti (lint, test, build va push, staging, production approval). Taqqoslash jadvali tuzing: fayl hajmi (qator), noldan pipeline vaqti, cache bilan vaqt, har tizimda nima osonroq va nima qiyinroq chiqdi, secret va token modeli. Qaysi qismlar o'zgarishsiz ko'chdi (Makefile target'lari) va qaysilari qayta yozildi?

### Topshirish

Tayyor bo'lgach:
1. `main` dagi oxirgi pipeline yashil, Pipeline editor xato ko'rsatmaydi.
2. Bitta push'ga bitta pipeline yaratiladi (takroriy yo'q).
3. Registry'da commit SHA bilan teglangan image bor.
4. Sinov variable'lari va deploy token o'chirilgan, `config.toml` nusxasida token yo'q.
5. Runner konteyneri va volume'i o'chirilgan, UI'da runner olib tashlangan.
6. `make check` toza. Menga xabar bering, loyiha havolasini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Stage va `needs` qanday birga ishlaydi? `needs` nimani tezlashtiradi?
- `rules` qanday tartibda tekshiriladi va hech biri mos kelmasa nima bo'ladi?
- Takroriy pipeline qayerdan paydo bo'ladi va `workflow: rules` uni qanday yopadi?
- Protected variable nimadan himoya qiladi? Masked variable nimadan himoya qilmaydi?
- GitLab'da cache nima uchun kafolatlanmagan, artifacts esa kafolatlangan?
- `docker` va `shell` executor farqi nima? Qaysi biri job'lar orasida holat qoldiradi?
- Docker-in-Docker nima uchun privileged talab qiladi va bu nimasi bilan xavfli?
- Runner GitLab'ga qanday ulanadi: kim kimga ulanish ochadi?
- GitHub Actions va GitLab CI modelidagi uchta eng muhim farqni ayting.
