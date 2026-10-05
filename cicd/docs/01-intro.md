# 1-dars: CI/CD ga kirish

Maqsad: CI/CD nima muammoni yechishini va pipeline qanday qismlardan iboratligini asbobdan mustaqil tushunish. Frontend'da siz CI'ni iste'molchi sifatida ko'rgansiz (PR'da lint va test yashil bo'lishi kerak). Bu darsda uni loyihalovchi ko'zi bilan ko'rasiz: nima uchun build bir marta qilinadi, artifact va cache farqi nima, secret qayerdan oqib chiqadi, jamoa samaradorligi qanday o'lchanadi. Docker modulida image qurishni, cloud modulida uni VM'ga qo'lda deploy qilishni o'rgandingiz. Bu modul o'sha qo'l ishini avtomatlashtiradi. 2–4-darslarda shu tushunchalar to'rt asbobda qanday ifodalanishini, 5-darsda avtomatik deploy'ni ko'rasiz.

Taxminiy vaqt: 2 kun (siz uchun). Atamalar tanish, diqqatni quyidagilarga qarating: continuous delivery va continuous deployment orasidagi yagona farq, artifact va cache farqi, build once deploy many, pipeline'ning har qadami oddiy buyruq ekani (lokal Makefile bilan isbotlaysiz), DORA metrikalari.

## Laboratoriya

Hamma vazifa ish mashinasida, `cicd/01-intro/` ichida bajariladi. Tizim holati o'zgartirilmaydi: Node, linter va boshqa asboblar Docker konteynerida ishlaydi, ish mashinasiga hech narsa o'rnatilmaydi. Kerak bo'ladigan narsalar: Docker (o'rnatilgan) va `make` (tekshirish: `make --version`).

Asboblarni konteynerda ishlatish namunasi:

```
docker run --rm -v "$PWD":/app -w /app node:24-alpine npm test
docker run --rm -i hadolint/hadolint < Dockerfile
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:stable ci.sh
```

Tozalash: dars oxirida qurilgan image'larni `docker image ls` bilan topib `docker image rm` qiling.

---

## 1. Muammo: integratsiya do'zaxi

CI'siz jamoada har kim o'z branch'ida haftalab ishlaydi, reliz oldidan hammasi birlashtiriladi. Konfliktlar va yashirin nomuvofiqliklar bir vaqtda chiqadi, xato qaysi o'zgarishdan kelgani noma'lum. Deploy qo'lda, hujjatdagi 20 qadam bilan qilinadi, shuning uchun kam qilinadi, kam qilingani uchun har reliz katta va xavfli. Bu o'zini kuchaytiruvchi halqa.

CI/CD shu halqani teskarisiga aylantiradi: o'zgarishlar kichik, tez-tez birlashtiriladi, har biri avtomatik tekshiriladi va bir xil avtomatik yo'l bilan production'gacha boradi. Asosiy g'oya: og'riqli ishni tez-tez qilsangiz, uni avtomatlashtirishga majbur bo'lasiz va u og'riqsiz bo'ladi.

## 2. Uch atama

| Atama | Nima avtomatik | Production'ga chiqish |
|-------|----------------|------------------------|
| Continuous Integration (CI) | har commit'da build va testlar, natija bir necha daqiqada | bu haqda hech narsa demaydi |
| Continuous Delivery | CI + deploy qilishga tayyor artifact, staging'ga avtomatik deploy | bir tugma bilan, inson qarori |
| Continuous Deployment | hammasi | testlardan o'tgan har commit avtomatik chiqadi |

- **CI bu asbob emas, amaliyot.** Jenkins o'rnatilgani CI bor degani emas. Mezon: hamma kuniga kamida bir marta `main` ga birlashtiradi, har birlashtirish avtomatik tekshiriladi, buzilgan build darhol tuzatiladi.
- Continuous delivery va continuous deployment orasidagi yagona farq: production oldidagi qo'lda tasdiq (approval) bor yoki yo'q. Ikkalasida ham deploy jarayonining o'zi to'liq avtomatik.
- Continuous deployment kuchli avtomatik testlar, monitoring va tez rollback talab qiladi. Ko'p jamoalar continuous delivery'da to'xtaydi (regulyatsiya, reliz oynalari), bu normal.
- "CD" qisqartmasi ikkala ma'noda ishlatiladi, suhbatda qaysi biri nazarda tutilganini aniqlang.

## 3. Pipeline anatomiyasi

Pipeline bu commit'ni production'gacha olib boradigan avtomatik qadamlar zanjiri. Asboblarda nomlar farq qiladi, tushunchalar bir xil:

| Tushuncha | Ma'nosi | GitHub Actions | GitLab CI | Jenkins |
|-----------|---------|----------------|-----------|---------|
| Pipeline | bir trigger'dan boshlangan butun ish | workflow run | pipeline | build (run) |
| Stage | mantiqiy bosqich (test, build, deploy) | yo'q, `needs` bilan ifodalanadi | stage | stage |
| Job | bitta mashinada bajariladigan ish birligi | job | job | stage (agent bilan) |
| Step | job ichidagi bitta buyruq | step | `script` qatori | step |
| Runner/agent | job'ni bajaradigan mashina yoki konteyner | runner | runner | agent |
| Trigger | pipeline'ni boshlovchi hodisa | `on:` | `rules`, `workflow` | trigger, webhook |

### Trigger
Odatda: branch'ga push, pull/merge request, tag, jadval (cron), qo'lda ishga tushirish, boshqa pipeline. Qaysi trigger'da qaysi job'lar ishlashi pipeline dizaynining muhim qismi: PR'da test va build, `main` da qo'shimcha image push va deploy.

### Job izolyatsiyasi
Har job toza muhitda boshlanadi (yangi VM yoki konteyner) va tugagach muhit yo'q qilinadi. Bundan ikki oqibat chiqadi:

- Job'lar orasida fayl o'z-o'zidan o'tmaydi. `build` job'ida yaratilgan `dist/` papka `deploy` job'ida yo'q. O'tkazish uchun artifact kerak.
- Har job'da dependency'lar qaytadan o'rnatiladi. Tezlashtirish uchun cache kerak.

Step'lar esa bitta job ichida bir xil fayl tizimini bo'lishadi.

### Artifact va cache
Ikkalasi ham "fayllarni saqlab qo'yish", lekin maqsadi qarama-qarshi:

| | Artifact | Cache |
|-|----------|-------|
| Nima | pipeline natijasi: binary, `dist/`, test hisoboti, image | qayta yuklab olish mumkin bo'lgan narsa: `~/.npm`, Docker layer'lar |
| Maqsad | job'lar orasida uzatish, saqlash, deploy qilish | tezlashtirish |
| Yo'q bo'lsa | pipeline buziladi | pipeline sekinroq, lekin natija bir xil |
| Kalit | aynan shu run'ga bog'langan | lockfile hash'i kabi kalit, run'lar orasida bo'lishiladi |

**Tuzoq: cache to'g'rilikka ta'sir qilmasligi kerak.** Cache o'chirilganda pipeline natijasi o'zgarsa (masalan build faqat cache'dagi eski fayl tufayli o'tayotgan bo'lsa), bu xato. `node_modules` ni emas, paket menejeri cache'ini (`~/.npm`) saqlash va `npm ci` ishlatish shu sababdan tavsiya qilinadi.

### Tez feedback va tartib
Stage'lar arzon va tezdan qimmat va sekinga qarab tartiblanadi: lint (soniyalar), unit test (daqiqa), build, integration test, deploy. Birinchi xatoda pipeline to'xtaydi (fail fast). Mustaqil job'lar parallel ishlaydi. Amaliy mezon: PR'dagi asosiy tekshiruv 10 daqiqadan oshmasin. Undan sekin bo'lsa dasturchilar natijani kutmay kontekst almashtiradi va CI qadri tushadi.

## 4. Pipeline as code

Pipeline ta'rifi repo ichidagi faylda turadi (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`), UI'dagi sozlamalarda emas. Natija:

- Pipeline o'zgarishi kod bilan birga review qilinadi va tarixda qoladi.
- Har branch o'z pipeline versiyasiga ega, eski commit'ni o'sha paytdagi pipeline bilan qayta qurish mumkin.
- CI serveri yo'qolsa, pipeline yo'qolmaydi.

**Tuzoq: mantiqni YAML ichiga yozish.** 40 qatorli `script:` bloki lokal ishga tushmaydi, test qilinmaydi va boshqa CI tizimiga ko'chmaydi. Mantiq repo ichidagi skript yoki `Makefile` target'ida tursin (`make test`, `make build`), pipeline faqat ularni chaqirsin. Shu darsning amaliy qismi aynan shuni quradi, 2–4-darslarda uch xil CI shu target'larni chaqiradi.

## 5. Trunk-based development va qisqa feedback loop

CI'ning ta'rifi branch strategiyasiga talab qo'yadi: uzoq yashaydigan feature branch'lar integratsiyani kechiktiradi, demak CI emas.

- **Trunk-based development**: bitta asosiy branch (`main`), branch'lar qisqa (soatlar, ko'pi bilan 1–2 kun), kichik PR'lar. `main` har doim deploy qilishga yaroqli holatda.
- Tugallanmagan funksiya `main` ga **feature flag** ortida kiradi: kod deploy qilingan, lekin o'chirilgan. Deploy (kodni serverga chiqarish) va release (foydalanuvchiga ochish) ajraladi.
- Git modulidagi GitFlow (`develop`, `release/*`) reliz sikllari uzun mahsulotlarga mos (mobil ilova, o'rnatiladigan dastur). Tez-tez deploy qilinadigan web servis uchun u ortiqcha kechikish.

Feedback loop qancha qisqa bo'lsa, xatoni tuzatish shuncha arzon: commit'dan 5 daqiqa keyin kelgan xato kontekst yodda turganida tuzatiladi, ikki hafta keyin QA'dan kelgani esa arxeologiya talab qiladi.

## 6. Build once, deploy many

Artifact (bizda Docker image) bir marta quriladi va aynan o'sha artifact barcha environment'lardan o'tadi: dev, staging, production. Har environment uchun qayta build qilinmaydi.

Nima uchun: staging'da test qilingan narsa va production'ga chiqqan narsa bayt darajasida bir xil bo'lishi kerak. Qayta build qilinsa dependency versiyasi, base image yoki build vaqti farq qilishi mumkin, demak siz test qilinmagan narsani chiqarasiz.

Bundan kelib chiqadigan qoidalar:

- Konfiguratsiya artifact ichida emas, environment'da (env variable, config fayl, secret). Docker modulidagi 12-factor qoidasi.
- Artifact o'zgarmas identifikator bilan belgilanadi: commit SHA yoki image digest. `latest` identifikator emas, u siljiydigan ko'rsatkich.
- Bir environment'dan keyingisiga o'tkazish **promotion** deyiladi: yangi build emas, o'sha artifact'ni keyingi joyga deploy qilish.

**Tuzoq: frontend'dagi build-time env.** `NEXT_PUBLIC_*` yoki `VITE_*` kabi o'zgaruvchilar build vaqtida bundle ichiga yoziladi, natijada har environment uchun alohida build kerak bo'lib qoladi. Bu qoidani buzadi. Yechimlar: konfiguratsiyani runtime'da yuklash (masalan konteyner start bo'lganda generatsiya qilinadigan `config.js` yoki server bergan endpoint).

## 7. Environment'lar va promotion

Tipik zanjir: `dev` (har commit, avtomatik), keyin `staging` (production'ga o'xshash, avtomatik yoki PR merge'da), keyin `production` (approval yoki avtomatik).

- Environment'lar orasidagi farq qancha kichik bo'lsa, staging'dagi test shuncha ishonchli. Farq faqat konfiguratsiya va o'lchamda bo'lsin, deploy usulida emas.
- Har environment o'z secret'lariga ega. Staging job'i production secret'ini ko'ra olmasligi kerak.
- **Gate** bu promotion sharti: avtomatik (testlar, smoke test) yoki qo'lda (approval). CI tizimlarida environment obyektiga himoya qoidalari biriktiriladi (2- va 3-darslarda).
- Kim, qachon, qaysi versiyani qayerga deploy qilgani yozib boriladi. Bu deployment history, incident paytida birinchi qaraladigan joy.

## 8. Pipeline'da secret'lar

Pipeline registry'ga push qiladi, serverga kiradi, cloud API chaqiradi. Demak u production'ga eng kuchli kirish huquqiga ega tizimlardan biri va hujumchilar uchun asosiy nishon.

Qoidalar:

- Secret repo'da turmaydi, CI tizimining secret omborida turadi va job'ga env variable yoki fayl sifatida beriladi.
- **Least privilege**: token faqat kerakli ishni qila olsin (faqat bitta registry'ga push, faqat bitta serverga deploy). Har environment uchun alohida secret.
- Qisqa yashaydigan credential uzoq yashaydigandan yaxshi. Zamonaviy usul OIDC: pipeline cloud'dan bir necha daqiqalik token oladi, saqlanadigan kalit umuman yo'q (5-darsda).
- Ishonchsiz kod (fork'dan kelgan PR) secret'larni ko'rmasligi kerak. CI tizimlari buni standart holatda ta'minlaydi, lekin noto'g'ri sozlama bilan buzish oson.

Secret oqib chiqadigan yo'llar: log'ga chop etish (`set -x`, `env`, xato xabari ichida), artifact ichiga tushib qolish (`.env` fayl, `docker build` ning `ARG` qiymati image tarixida qoladi), uchinchi tomon action yoki plugin'ning buzilgan versiyasi, PR'dagi pipeline faylini o'zgartirish.

**Tuzoq: log maskalash himoya emas.** CI tizimlari secret qiymatini log'da `***` bilan almashtiradi, lekin faqat aynan o'sha satrni. `base64` qilingan, teskari yozilgan yoki bo'laklangan qiymat maskalanmaydi. Maskalash tasodifiy xatodan saqlaydi, niyatli hujumdan emas.

## 9. DORA metrikalari

DORA (DevOps Research and Assessment) tadqiqoti dasturiy ta'minot yetkazish samaradorligini o'lchaydigan to'rt metrikani ommalashtirdi:

| Metrika | Nimani o'lchaydi | Turi |
|---------|------------------|------|
| Deployment frequency | production'ga qanchalik tez-tez deploy qilinadi | tezlik |
| Lead time for changes | commit'dan production'gacha qancha vaqt | tezlik |
| Change failure rate | deploy'larning necha foizi nosozlikka olib keladi | barqarorlik |
| Time to restore service | nosozlikdan keyin qancha vaqtda tiklanadi | barqarorlik |

Tadqiqotning asosiy xulosasi: tezlik va barqarorlik bir-biriga zid emas. Eng yaxshi jamoalar ham tez-tez deploy qiladi, ham kam buzadi, chunki kichik o'zgarishni tekshirish va qaytarish oson. Keyingi yillardagi hisobotlarda metrikalar to'plami biroz o'zgartirilgan (nomlar aniqlashtirilgan, yangi metrika qo'shilgan), joriy holatini dora.dev'dan o'qing.

**Tuzoq: metrikani maqsadga aylantirish.** "Kuniga 10 deploy" KPI qilib qo'yilsa, jamoa bo'sh deploy'lar qiladi. Metrikalar jamoa darajasida, tendensiyani ko'rish uchun ishlatiladi, shaxsni baholash uchun emas.

## 10. Asboblar manzarasi

| | GitHub Actions | GitLab CI | Jenkins | TeamCity |
|-|----------------|-----------|---------|----------|
| Model | GitHub'ga o'rnatilgan SaaS | GitLab'ga o'rnatilgan (SaaS va self-managed) | mustaqil open-source server | mustaqil tijorat server (JetBrains), cloud varianti ham bor |
| Control plane | hosted (Enterprise Server'da self-hosted) | hosted yoki self-managed | faqat self-hosted | self-hosted yoki TeamCity Cloud |
| Ijrochi | hosted runner yoki self-hosted runner | hosted runner yoki self-hosted runner | o'z agent'laringiz | o'z agent'laringiz (cloud'da hosted) |
| Konfiguratsiya | YAML, `.github/workflows/*.yml` | YAML, `.gitlab-ci.yml` | Groovy DSL, `Jenkinsfile` | UI yoki Kotlin DSL, `.teamcity/settings.kts` |
| Qayta ishlatish | action'lar marketplace, reusable workflow | `include`, shablonlar, CI/CD components | shared library, mingdan ortiq plugin | meta-runner, template, Kotlin kodi |
| Kuchli tomoni | kirish oson, ulkan ekotizim, GitHub bilan integratsiya | yagona platforma (repo, CI, registry, environments), kuchli `rules` va DAG | cheksiz moslashuvchanlik, har qanday muhit, bepul | qulay UI, build zanjirlari, test tahlili, tipli DSL |
| Zaif tomoni | GitHub'ga bog'liqlik, uchinchi tomon action'lar xavfi | ilg'or funksiyalar pulli tarifda | ekspluatatsiya yuki: yangilash, plugin'lar, xavfsizlik | litsenziya narxi, kichikroq hamjamiyat |

Tanlov odatda kod qayerda turganiga bog'liq: repo GitHub'da bo'lsa Actions, GitLab'da bo'lsa GitLab CI tabiiy tanlov. Jenkins va TeamCity kod hosting'idan mustaqil, ular ko'pincha yopiq tarmoqdagi korxonalarda, murakkab eski build'larda va maxsus apparat kerak bo'lgan joylarda uchraydi (4-darsda batafsil).

Model hammasida bir xil ekanini eslab qoling: trigger, job'lar grafi, ijrochi mashina, secret ombori, artifact. Bitta asbobni chuqur bilsangiz, ikkinchisi sintaksis masalasi.

## Tuzoqlar

- Har environment uchun alohida build qilish. Test qilingan va deploy qilingan artifact turli bo'ladi.
- `latest` tag bilan deploy. Qaysi commit ishlab turganini ham, nimaga rollback qilishni ham bilmaysiz.
- Sekin pipeline'ga chidash. 30 daqiqalik CI'ni odamlar aylanib o'tishni boshlaydi (`[skip ci]`, to'g'ridan `main` ga push).
- Flaky testni "qayta ishga tushirsa o'tadi" deb qoldirish. Jamoa qizil pipeline'ga ishonmay qo'yadi va haqiqiy xatoni ham retry qiladi.
- Buzilgan `main` ustiga yangi commit'lar qo'yish. Qoida: `main` qizil bo'lsa, birinchi ish uni tuzatish yoki revert.
- Butun mantiqni YAML ichiga yozish. Lokal takrorlab bo'lmaydi, har tuzatish "commit, push, kut" sikli bilan debug qilinadi.
- Bitta kuchli token'ni hamma job va environment'ga berish.
- Cache'ga to'g'rilik uchun tayanish yoki cache kalitini noto'g'ri tanlash (lockfile o'zgarganda eski dependency'lar ishlatiladi).
- Uzoq yashaydigan branch'da "CI yashil" deb xotirjam bo'lish. U faqat branch'ni tekshiradi, `main` bilan integratsiyani emas.

## Manbalar

- https://martinfowler.com/articles/continuousIntegration.html – Continuous Integration (majburiy)
- https://martinfowler.com/bliki/ContinuousDelivery.html – Continuous Delivery qisqa ta'rifi
- https://martinfowler.com/bliki/DeploymentPipeline.html – deployment pipeline tushunchasi
- https://trunkbaseddevelopment.com/ – trunk-based development, feature flag'lar
- https://dora.dev/guides/dora-metrics-four-keys/ – DORA metrikalari
- https://12factor.net/build-release-run – build, release, run bosqichlarini ajratish
- https://12factor.net/config – konfiguratsiya environment'da
- https://www.gnu.org/software/make/manual/make.html – GNU make qo'llanmasi
- Humble, Farley, "Continuous Delivery", 1-qism (5-bob: Anatomy of the Deployment Pipeline)

---

## Vazifalar

Barchasini `cicd/01-intro/` da bajaring (yaratish: `make new m=cicd n=01 name=intro`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`app/`, `Makefile`, `ci.sh`, `Dockerfile`) shu papkada saqlanadi.

### A. Tahlil

1. **Three terms.** O'zingiz ishlagan (yoki ishlayotgan) loyihani oling. U CI, continuous delivery yoki continuous deployment bosqichlaridan qaysi birida? 2-bo'limdagi mezonlar bo'yicha asoslang: `main` ga qanchalik tez-tez birlashtiriladi, production'ga chiqish qanday qaror bilan bo'ladi, qaysi qadam qo'lda.

2. **Pipeline map.** O'sha loyihaning (yoki o'zingiz bilgan open-source loyihaning) pipeline faylini o'qing. Jadval tuzing: har job uchun trigger, taxminiy davomiyligi, nimani cache qiladi, qanday artifact chiqaradi. Tartib "arzondan qimmatga" qoidasiga mos keladimi?

3. **Artifact or cache.** Quyidagilarning har biri artifact yoki cache ekanini va sababini yozing: `~/.npm`, `dist/`, `coverage/lcov.info`, Docker build layer'lari, registry'ga push qilingan image, `node_modules`, JUnit XML hisoboti. Qaysi biri o'chirilsa pipeline buziladi?

4. **Build once violation.** Frontend loyihada `VITE_API_URL` build vaqtida berilsa, "build once, deploy many" qanday buziladi? Kamida ikki yechim taklif qiling va har birining kamchiligini yozing.

5. **Secret leak paths.** Pipeline'dan secret oqib chiqishining kamida beshta yo'lini sanang va har biri uchun bitta himoya chorasini yozing. Maskalash qaysi yo'llarni yopmasligini alohida ko'rsating.

6. **DORA estimate.** O'zingiz bilgan jamoa uchun to'rt DORA metrikasini taxminan baholang (aniq raqam bo'lmasa oraliq). Qaysi biri eng zaif va uni yaxshilash uchun pipeline'da birinchi navbatda nimani o'zgartirgan bo'lardingiz?

7. **Tool choice.** Uch holat uchun asbob tanlang va asoslang: (a) GitHub'dagi 5 kishilik startap, (b) internetga chiqishi yo'q yopiq tarmoqdagi bank, kod ichki GitLab'da, (c) 15 yillik C++ mahsuloti, Windows va Linux build'lari, maxsus apparatda testlar.

### B. Lokal pipeline

8. **Demo app.** `app/` ichida kichik Node HTTP servis yozing (framework'siz yoki minimal): `GET /healthz` 200 qaytaradi, `GET /version` `APP_VERSION` env qiymatini qaytaradi, bitta sof funksiya va unga `node --test` bilan kamida 3 ta test. `package.json` da `test` va `lint` skriptlari bo'lsin. Bu ilova modul oxirigacha ishlatiladi.

9. **Dockerfile.** Ilova uchun multi-stage `Dockerfile` yozing (docker modulidagi qoidalar: non-root user, `npm ci`, `.dockerignore`). `hadolint` ni konteynerda ishga tushirib ogohlantirishlarni tuzating yoki nima uchun qoldirganingizni izohlang.

10. **Makefile pipeline.** `Makefile` yozing: `lint`, `test`, `build`, `smoke` va hammasini ketma-ket chaqiradigan `ci` target'lari. Node buyruqlari konteynerda ishlasin, ish mashinasidagi Node'ga bog'liq bo'lmasin. `build` image'ni `git rev-parse --short HEAD` qiymati bilan teglasin. `smoke` konteynerni ko'tarib `/healthz` ni tekshirsin va o'chirsin. `.PHONY` nima uchun kerakligini izohlang.

11. **Fail fast.** Testlardan birini ataylab buzing va `make ci` ni ishga tushiring. `build` bajarildimi? `echo $?` nima qaytardi? `make` qaysi mexanizm bilan to'xtaganini izohlang, so'ng `make -k ci` bilan farqni ko'rsating.

12. **Shell variant.** Xuddi shu pipeline'ni `ci.sh` sifatida yozing. Avval `set -euo pipefail` siz, bitta qadam xato qaytaradigan holatda ishga tushiring va skript davom etib ketishini ko'rsating. Keyin `set -euo pipefail` qo'shing. Har uch flag nimani o'zgartirishini yozing. `shellcheck` toza o'tsin.

13. **Immutable tag.** Image'ni ikki marta quring: orasida kodni o'zgartirib commit qiling. `docker image ls` da ikki xil SHA tag borligini ko'rsating. Endi ikkalasini ham `latest` deb teglab ko'ring: `latest` qaysi biriga ishora qiladi va eski versiyaga qaytish uchun nimani bilishingiz kerak bo'ladi?

14. **Dirty tree guard.** Commit qilinmagan o'zgarish bor paytda `make build` qurgan image aslida qaysi kodni o'z ichiga oladi va tag nimani da'vo qiladi? `git status --porcelain` yordamida iflos daraxtda build'ni rad etadigan (yoki tag'ga `-dirty` qo'shadigan) tekshiruv qo'shing.

15. **Promotion drill.** Bitta image'ni qayta build qilmasdan ikki "environment" sifatida ishga tushiring: `staging` (port 8081, `APP_ENV=staging`) va `production` (port 8082, `APP_ENV=production`). Ikkalasida image ID bir xil ekanini `docker inspect` bilan isbotlang. Konfiguratsiya qayerdan kelayotganini izohlang.

16. **Pipeline timing.** `make ci` ning har bosqichi qancha vaqt olishini o'lchang (`time`). Ikkinchi ishga tushirishda nima tezlashdi va nima uchun (Docker layer cache, npm cache)? Dependency o'rnatishni tezlashtirish uchun `Dockerfile` da qatorlar tartibi qanday bo'lishi kerakligini izohlang.

### Topshirish

Tayyor bo'lgach:
1. `make ci` toza daraxtda noldan oxirigacha o'tadi va exit code 0.
2. Ataylab buzilgan test bilan `make ci` nol bo'lmagan exit code qaytaradi.
3. `shellcheck` va `hadolint` toza (yoki qoldirilgan ogohlantirish izohlangan).
4. Repo ildizida `make check` toza.
5. Qurilgan sinov image'lari va konteynerlari o'chirilgan.
6. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Continuous delivery va continuous deployment orasidagi yagona farq nima?
- Nima uchun Jenkins o'rnatilgani "bizda CI bor" degani emas?
- Artifact va cache farqi nima? Qaysi biri yo'qolsa pipeline buziladi?
- Nima uchun image har environment uchun qayta qurilmaydi?
- Deploy va release farqi nima, feature flag bunga qanday yordam beradi?
- Nima uchun pipeline mantiqini YAML'da emas, skript yoki Makefile'da saqlash tavsiya qilinadi?
- Log'dagi secret maskalash nima uchun to'liq himoya emas?
- DORA'ning to'rt metrikasidan qaysi ikkitasi tezlikni, qaysi ikkitasi barqarorlikni o'lchaydi? Ular nima uchun bir-biriga zid emas?
- Uzoq yashaydigan feature branch nima uchun CI g'oyasiga zid?
