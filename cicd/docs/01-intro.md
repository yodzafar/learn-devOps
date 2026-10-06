# 1-dars: CI/CD ga kirish

Maqsad: CI/CD qaysi muammoni yechishini va pipeline qanday qismlardan iboratligini asbobdan mustaqil, noldan tushunish. Frontend ishida siz CI'ni iste'molchi sifatida ko'rgansiz: PR ochasiz, lint va test yashil bo'ladi, Vercel yoki Netlify preview havolasini beradi. Bu darsda o'sha yashil belgi ortida nima ishlaganini ochamiz: qaysi mashina, qaysi buyruq, natija qanday "yashil" yoki "qizil" ga aylanadi, nima uchun build bir marta qilinadi, secret qayerdan oqib chiqadi, jamoa samaradorligi qanday o'lchanadi. Docker modulida image qurishni (docker 2), cloud modulida uni VM'ga qo'lda deploy qilishni (cloud 4) o'rgandingiz. Bu modul o'sha qo'l ishini avtomatlashtiradi: 2–4-darslarda shu tushunchalar to'rt asbobda qanday yozilishini, 5-darsda avtomatik deploy'ni ko'rasiz.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–5 bo'limlar va A guruhning 1–3 vazifalari, ikkinchi kun 6–10 bo'limlar, 4–7 vazifalar va "Birga bajaramiz", uchinchi kun B guruh (8–16) va README'ni tartibga solish. Diqqatni mexanizmga qarating: uch atama orasidagi farq, toza muhit va exit code, artifact va cache farqi, build once deploy many, pipeline'ning har qadami oddiy buyruq ekani (buni lokal Makefile bilan o'zingiz isbotlaysiz).

Qanday o'qish kerak: har bo'limdagi misolni host terminalida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizda farq qiladigan qiymatlar (hash, vaqt, versiya) `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsda CI servisi ishlatilmaydi (u 2-darsdan boshlanadi). Hamma narsa host'da, `cicd/01-intro/` ichida bajariladi, asboblar esa Docker konteynerida ishlaydi.

| Joy | Nima ishlaydi |
|-----|---------------|
| Host (Zorin yoki macOS) | `make`, `git`, `docker` buyruqlari, `ci.sh` skripti |
| Konteyner (bir martalik, `--rm`) | Node, `npm`, linter'lar: host'ga Node o'rnatilmaydi |
| `lab` VM, cloud | bu darsda kerak emas |

Kerakli narsalar `SETUP.md` dan: Docker va `make`. Tekshirish:

```
$ docker version --format '{{.Server.Version}}'
<versiya>
$ make --version | head -1
GNU Make <versiya>
```

Agar `make` yo'q bo'lsa: Zorin'da (`amd64`) `sudo apt install make`, macOS'da (`arm64`) `xcode-select --install` (Xcode Command Line Tools). `shellcheck` (linux 5), `hadolint` (docker 2) va `yamllint` (docker 4) oldingi modullarda o'rnatilgan, ular `make check` uchun kerak. O'rnatilmagan mashinada konteyner shakli ishlaydi:

```
docker run --rm -i hadolint/hadolint < Dockerfile
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:stable ci.sh
```

Asbobni konteynerda ishlatishning umumiy shakli (bu yerda Node versiyasini so'rash):

```
$ docker run --rm -v "$PWD":/app -w /app node:lts-alpine node --version
v<LTS major>.<N>.<N>
```

`--rm` konteynerni tugagach o'chiradi; `-v "$PWD":/app` joriy papkani konteyner ichiga `/app` qilib ulaydi (bind mount, docker 3); `-w /app` ishchi papka; `node:lts-alpine` image, qolgani konteyner ichida bajariladigan buyruq. `lts` tegi siljiydi, shuning uchun `Dockerfile` da aniq major yoziladi: joriy LTS raqamini shu buyruq chiqishidan yoki https://nodejs.org/en/about/previous-releases sahifasidan oling.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Image'lar `amd64` (`docker run --rm alpine:3 uname -m` → `x86_64`). Konteyner ichidagi jarayon standart holatda `root`, shuning uchun u bind mount orqali yaratgan fayllar host'da ham `root` ga tegishli bo'ladi va siz ularni `sudo` siz o'chira olmaysiz. GNU Make 4.x. |
| macOS (uy) | Image'lar `arm64` (`uname -m` → `aarch64`). Bind mount Docker Desktop'ning fayl almashish qatlamidan o'tadi: papka ulashilgan yo'l ostida bo'lishi kerak (uy papkasi standart holatda ulashilgan), konteyner yaratgan fayllar Mac foydalanuvchisiga tegishli ko'rinadi. GNU Make 3.81 (Xcode bilan keladi), host shell zsh, utilitalar BSD. |

Bundan uch qoida chiqadi:

- **Fayl egasi.** Konteyner host papkasiga fayl yozadigan bo'lsa (`node_modules`, `coverage/`), `--user "$(id -u):$(id -g)"` qo'shing: jarayon sizning UID va GID'ingiz bilan ishlaydi va fayllar ikkala host'da ham sizniki bo'ladi. Bu holda konteynerda uy papkasi yo'q, uy papkasiga yozadigan asbob (masalan `npm` o'z cache'ini) "permission denied" bersa `-e HOME=/tmp` qo'shiladi.
- **Make versiyasi.** Makefile ikkala mashinada ishlashi kerak, shuning uchun 3.81 dan keyin qo'shilgan imkoniyatlar ishlatilmaydi: `.ONESHELL`, `.RECIPEPREFIX`, `.SHELLFLAGS` (3.82), `$(file ...)` va `!=` (4.0). Retsept qatorlari TAB bilan boshlanadi.
- **Host buyruqlari.** `ci.sh` va Makefile retseptlarida GNU'ga xos flag yozilmaydi (`sed -i` argumentsiz, `grep -P`, `date -d`). Shubhali buyruqni konteyner ichiga oling.

Bir xil `docker run` buyrug'i ikki mashinada ikki xil arxitekturadagi image'ni tortadi (multi-arch image: bitta teg ortida har arxitektura uchun alohida image). "Menda ishlaydi" muammosining kichik namunasi shu: ofisda qurilgan image uydagi bilan bayt darajasida bir xil emas. CI'da build bitta joyda qilinishining sabablaridan biri (7-bo'lim).

Ikkinchi mashinada takrorlanadigan narsa: image'lar (`docker pull` yoki `make build` qayta bajariladi) va `node_modules` (commit qilinmaydi). Kod, `Makefile`, `ci.sh`, `Dockerfile` va README git orqali ko'chadi. Tozalash: dars oxirida sinov konteynerlarini `docker ps -a`, image'larni `docker image ls` bilan topib o'chiring.

---

## 1. Muammo: kam integratsiya nima uchun og'riqli

### Bu nima

Integratsiya bu sizning o'zgarishingizni jamoaning umumiy kodiga (`main`) qo'shish va natija birga ishlashini tekshirish. CI'siz jamoada har kim o'z branch'ida (git 2) haftalab ishlaydi, reliz oldidan hammasi birlashtiriladi. Konfliktlar va yashirin nomuvofiqliklar bir vaqtda chiqadi. Bu holat "integration hell" deb ataladi.

### Mexanizm: og'riq branch yoshi bilan o'sadi

Ikki alohida narsa o'sadi:

- **Merge conflict** (git 2): ikki branch bir faylning bir joyini o'zgartirgan. Branch qancha uzoq yashasa, `main` shuncha uzoqlashadi va kesishish ehtimoli oshadi.
- **Sinalmagan kombinatsiya**: git konflikt ko'rsatmaydi, lekin kod birga ishlamaydi. Masalan A branch funksiya nomini o'zgartirdi, B branch eski nom bilan yangi chaqiruv qo'shdi. Har ikki branch'da testlar yashil, birlashgach qizil.

### Hisoblab ko'ramiz

Besh dasturchi ikki hafta alohida ishlab, bir kunda birlashtirsa, o'zaro ta'sir qilishi mumkin bo'lgan juftliklar soni `5 × 4 / 2 = 10`. O'n dasturchida `10 × 9 / 2 = 45`. Hech biri oldin birga sinalmagan. Xato chiqsa, shubhali commit'lar soni ham katta: har biri 20 commit qilgan bo'lsa, 200 commit. `git bisect` (ikkiga bo'lib qidirish) bilan ham taxminan 8 qadam kerak (`2^8 = 256`), va bu faqat har oraliq commit build bo'lsa ishlaydi.

Har kim kuniga bir marta birlashtirsa: har integratsiyada yangi narsa bitta odamning bir kunlik ishi. Test qizarsa, sabab deyarli aniq: oxirgi kichik o'zgarish. Qidirish shart emas, revert qilish arzon.

Ikkinchi halqa deploy'da: qo'lda, hujjatdagi 20 qadam bilan qilinadigan deploy kam qilinadi, kam qilingani uchun har reliz katta va xavfli, xavfli bo'lgani uchun yana kam qilinadi. CI/CD bu halqani teskari aylantiradi: o'zgarishlar kichik, tez-tez birlashtiriladi, har biri avtomatik tekshiriladi va bir xil avtomatik yo'l bilan production'gacha boradi.

### Real ishda qachon kerak

- "PR ikki hafta ochiq turdi, endi rebase qilib bo'lmayapti" holati shu mexanizmning o'zi.
- Reliz kuni "kim nimani buzdi" yig'ilishi bo'lsa, integratsiya kech qilinmoqda.
- Frontend'dagi lokal qatlam: `husky` va `lint-staged` (git 3, hook'lar) commit oldidan lint ishlatadi. Bu pipeline'ning sizning mashinangizdagi birinchi bosqichi, lekin uni `--no-verify` bilan chetlab o'tish mumkin, shuning uchun server tomonidagi tekshiruv baribir kerak.

### Nima uchun shunday

Asosiy g'oya: og'riqli ishni tez-tez qilsangiz, uni avtomatlashtirishga majbur bo'lasiz va u og'riqsiz bo'ladi. "Continuous integration" 1990-yillar oxirida Extreme Programming amaliyoti sifatida tarqalgan, Martin Fowler maqolasi (Manbalar) uning eng mashhur bayoni. Muqobili "integratsiya fazasi": reliz oldidan alohida haftalar ajratish. U ishlaydi, lekin feedback kech keladi va fazaning davomiyligini oldindan aytib bo'lmaydi.

## 2. Uch va'da: CI, continuous delivery, continuous deployment

### Bu nima

Uch atama uch xil va'da, har keyingisi oldingisini o'z ichiga oladi:

| Atama | Nima avtomatik | Production'ga chiqish |
|-------|----------------|------------------------|
| Continuous Integration (CI) | har commit'da build va testlar, natija bir necha daqiqada | bu haqda hech narsa demaydi |
| Continuous Delivery | CI + deploy qilishga tayyor artifact, staging'ga avtomatik deploy | bir tugma bilan, inson qarori |
| Continuous Deployment | hammasi | testlardan o'tgan har commit avtomatik chiqadi |

Staging bu production'ga o'xshatib qurilgan sinov muhiti (7-bo'lim), artifact bu build natijasi (4-bo'lim).

### Mexanizm: har birining mezoni

- **CI bu asbob emas, amaliyot.** Jenkins o'rnatilgani CI bor degani emas. Mezon uchta: hamma kuniga kamida bir marta `main` ga birlashtiradi, har birlashtirish avtomatik tekshiriladi, buzilgan build darhol tuzatiladi.
- **Continuous delivery**: `main` dagi har commit istalgan paytda chiqarishga yaroqli, deploy jarayonining o'zi to'liq avtomatik, faqat "chiqaramizmi" qarorini inson beradi.
- **Continuous deployment**: o'sha qaror ham avtomatik. Yagona farq production oldidagi qo'lda tasdiq (approval) bor yoki yo'qligida.

"CD" qisqartmasi ikkala ma'noda ishlatiladi, suhbatda qaysi biri nazarda tutilganini aniqlang.

### Misol: uch jamoa

| Jamoa | Kuzatuv | Xulosa |
|-------|---------|--------|
| A | PR'da testlar avtomatik, lekin feature branch'lar 2–3 hafta yashaydi, reliz oyiga bir marta qo'lda | CI serveri bor, CI amaliyoti yo'q: integratsiya kuniga emas, oyiga bir marta |
| B | Kichik PR'lar har kuni `main` ga, `main` avtomatik staging'ga chiqadi, production'ga payshanba kuni release manager tugma bosadi | continuous delivery |
| C | `main` ga merge bo'lgan commit 15 daqiqada production'da, tasdiqsiz | continuous deployment |

A jamoa "bizda CI/CD bor" deyishi mumkin, chunki pipeline fayli mavjud. Mezonlar bo'yicha esa birinchi va'da ham bajarilmagan.

### Real ishda qachon kerak

- Yangi jamoaga qo'shilganda birinchi savollar: `main` ga qanchalik tez-tez merge qilinadi, production'ga kim va qanday chiqaradi.
- Continuous deployment kuchli avtomatik testlar, monitoring va tez rollback talab qiladi. Ko'p jamoalar continuous delivery'da to'xtaydi (regulyatsiya, reliz oynalari), bu normal.
- Vercel'da `main` ga push darhol production'ga chiqishi continuous deployment'ning tayyor ko'rinishi edi: qarorni platforma siz uchun avtomatlashtirgan.

### Nima uchun shunday

Uch bosqich ajratilishi sababi: har biri alohida ishonch darajasini talab qiladi. CI "kod birga ishlaydi" ga, delivery "deploy jarayoni ishonchli" ga, deployment "testlar inson ko'zini almashtira oladi" ga ishonishni bildiradi. Bosqichni sakrab o'tish (testlarsiz avtomatik deploy) tezlikni emas, nosozlikni avtomatlashtiradi.

## 3. Pipeline anatomiyasi: hodisa, graf, runner, exit code

### Bu nima

Pipeline bu commit'ni production'gacha olib boradigan avtomatik qadamlar zanjiri. Aniqroq: hodisa (trigger) bilan boshlanadigan, job'lardan tuzilgan yo'naltirilgan graf. Asboblarda nomlar farq qiladi, tushunchalar bir xil:

| Tushuncha | Ma'nosi | GitHub Actions | GitLab CI | Jenkins |
|-----------|---------|----------------|-----------|---------|
| Pipeline | bir trigger'dan boshlangan butun ish | workflow run | pipeline | build (run) |
| Stage | mantiqiy bosqich (test, build, deploy) | yo'q, `needs` bilan ifodalanadi | stage | stage |
| Job | bitta mashinada bajariladigan ish birligi | job | job | stage (agent bilan) |
| Step | job ichidagi bitta buyruq | step | `script` qatori | step |
| Runner/agent | job'ni bajaradigan mashina yoki konteyner | runner | runner | agent |
| Trigger | pipeline'ni boshlovchi hodisa | `on:` | `rules`, `workflow` | trigger, webhook |

### Mexanizm: PR ochilganda nima bo'ladi

1. Hodisa. Siz push qilasiz yoki PR ochasiz. Git hosting (git 4) CI tizimiga "shu repo, shu commit SHA, shu hodisa" degan xabar yuboradi. Boshqa trigger'lar: tag, jadval (cron), qo'lda ishga tushirish, boshqa pipeline.
2. Graf. CI tizimi o'sha commit'dagi pipeline faylini o'qiydi va qaysi job'lar shu hodisaga tegishli ekanini aniqlaydi: PR'da test va build, `main` da qo'shimcha image push va deploy. Job'lar orasidagi "bundan keyin" bog'lanishlari grafni beradi: mustaqil job'lar parallel, bog'liqlari ketma-ket.
3. Runner. Har job navbatga qo'yiladi. Runner (Jenkins va TeamCity'da agent) bu navbatdan job olib bajaradigan dastur va u ishlayotgan mashina. U repo'ni klonlaydi, step'larni tartib bilan shell'da ishga tushiradi, log'ni CI tizimiga uzatadi.
4. Natija. Har step'ning exit code'i (linux 1: dastur tugaganda qaytaradigan son, `0` muvaffaqiyat) tekshiriladi. Nol bo'lmasa step, job va pipeline "failed" bo'ladi. PR'dagi qizil belgi shu.

Git 4 dagi "required checks" aynan shu natijaga ulanadi: branch protection job statusi yashil bo'lmaguncha merge'ga ruxsat bermaydi.

### Toza muhit

Har job toza muhitda boshlanadi (yangi VM yoki konteyner) va tugagach muhit yo'q qilinadi. Buni lokal ko'rish mumkin, chunki `docker run --rm` ham har safar image'dan yangi konteyner yaratadi:

```
$ docker run --rm alpine:3 sh -c 'echo built > /tmp/out.txt; ls /tmp'
out.txt
$ docker run --rm alpine:3 ls /tmp
$
```

Birinchi konteyner `/tmp/out.txt` ni yaratdi va ko'rsatdi. Ikkinchi konteynerda `ls /tmp` hech narsa chiqarmadi: u birinchisining fayl tizimini ko'rmaydi. Ikki oqibat:

- Job'lar orasida fayl o'z-o'zidan o'tmaydi. O'tkazish uchun artifact kerak (4-bo'lim).
- Har job'da dependency'lar qaytadan o'rnatiladi. Tezlashtirish uchun cache kerak (4-bo'lim).

Step'lar esa bitta job ichida bir xil fayl tizimini bo'lishadi.

### Exit code: pipeline'ning yagona tili

CI tizimi sizning testlaringizni "tushunmaydi". U faqat buyruq qaytargan sonni ko'radi:

```
$ docker run --rm alpine:3 sh -c 'exit 3'; echo $?
3
$ sh -c 'true && sh -c "exit 3" && echo next'; echo $?
3
```

Birinchi qator: `docker run` konteyner ichidagi jarayonning exit code'ini o'zi qaytaradi, shuning uchun konteynerdagi test xatosi host'dagi pipeline'ga yetib keladi. Ikkinchi qator: `&&` zanjirida (linux 5) birinchi nol bo'lmagan kod zanjirni to'xtatdi, `next` chop etilmadi. Pipeline'ning "fail fast" (birinchi xatoda to'xtash) xulqi shu mexanizmning kattalashtirilgani. `docker run` ning o'z kodlari ham bor: `125` Docker'ning o'zi xato berdi, `126` buyruqni ishga tushirib bo'lmadi, `127` buyruq topilmadi.

Xulosa: xato bo'lganda nol qaytaradigan skript (masalan xatoni yutib yuboradigan `|| true`) pipeline'ni yashil qiladi, garchi hech narsa tekshirilmagan bo'lsa ham.

### Real ishda qachon kerak

- "Lokal o'tadi, CI'da yiqiladi": deyarli har doim toza muhit farqi (commit qilinmagan fayl, global o'rnatilgan paket, boshqa Node versiyasi).
- "Testlar yiqildi, lekin pipeline yashil": exit code qayerdadir yo'qolgan.
- Pipeline'ni tezlashtirish: grafda nima parallel bo'la olishini ko'rish.

### Nima uchun shunday

Toza muhit takrorlanuvchanlik uchun: oldingi job qoldirgan fayl natijaga ta'sir qilmasa, bir commit har safar bir xil natija beradi. Muqobili doimiy build serveri (eski Jenkins uslubi): tez, lekin yillar davomida qo'lda o'rnatilgan narsalar yig'iladi va server o'lsa build'ni hech kim qayta tiklay olmaydi. Exit code tanlanishi sababi: bu Unix'dagi har qanday dastur, har qanday tilda gapiradigan yagona umumiy protokol.

## 4. Artifact, cache va tez feedback

### Bu nima

Toza muhitning ikki oqibatiga ikki mexanizm javob beradi. Ikkalasi ham "fayllarni saqlab qo'yish", lekin maqsadi qarama-qarshi:

| | Artifact | Cache |
|-|----------|-------|
| Nima | pipeline natijasi: kompilyatsiya qilingan Go binary, `.jar`, reliz arxivi | qayta yuklab olish mumkin bo'lgan narsa: `~/.cache/pip`, Go modul cache'i |
| Maqsad | job'lar orasida uzatish, saqlash, deploy qilish | tezlashtirish |
| Yo'q bo'lsa | pipeline buziladi | pipeline sekinroq, lekin natija bir xil |
| Kalit | aynan shu run'ga bog'langan | lockfile hash'i kabi kalit, run'lar orasida bo'lishiladi |

### Mexanizm

**Artifact**: job tugaganda ko'rsatilgan fayllar CI tizimining omboriga yuklanadi, keyingi job ularni yuklab oladi. Docker image uchun ombor rolini registry (docker 2) bajaradi.

**Cache**: job boshida CI kalit bo'yicha saqlangan arxivni qidiradi. Topilsa ochadi (cache hit), topilmasa job noldan ishlaydi va oxirida arxiv saqlanadi (cache miss). Kalit odatda lockfile hash'idan yasaladi: `package-lock.json` o'zgarsa kalit o'zgaradi va eski cache ishlatilmaydi.

Sinov savoli: "shu narsani o'chirsam, pipeline natijasi o'zgaradimi yoki faqat sekinlashadimi?" Birinchisi artifact, ikkinchisi cache.

### Misol: takrorlanuvchi o'rnatish

`npm install` `package.json` dagi oraliqlar (`^1.2.0`) bo'yicha yangi versiya olishi va lockfile'ni o'zgartirishi mumkin. `npm ci` esa faqat `package-lock.json` dagi aniq versiyalarni o'rnatadi, avval `node_modules` ni o'chiradi va lockfile `package.json` ga mos kelmasa xato bilan to'xtaydi. CI'da shuning uchun `npm ci`: bir commit har safar bir xil dependency daraxtini beradi. Cache bu jarayonni faqat tezlashtiradi (paketlar tarmoqdan emas, diskdan olinadi), natijani o'zgartirmaydi.

**Tuzoq: cache to'g'rilikka ta'sir qilmasligi kerak.** Cache o'chirilganda pipeline natijasi o'zgarsa (masalan build faqat cache'dagi eski fayl tufayli o'tayotgan bo'lsa), bu xato.

### Tez feedback va tartib

Stage'lar arzon va tezdan qimmat va sekinga qarab tartiblanadi: lint (soniyalar), unit test (daqiqa), build, integration test, deploy. Birinchi xatoda pipeline to'xtaydi (fail fast), mustaqil job'lar parallel ishlaydi. Amaliy mezon: PR'dagi asosiy tekshiruv 10 daqiqadan oshmasin. Undan sekin bo'lsa dasturchilar natijani kutmay kontekst almashtiradi va CI qadri tushadi. Commit'dan 5 daqiqa keyin kelgan xato kontekst yodda turganida tuzatiladi, ikki hafta keyin QA'dan kelgani arxeologiya talab qiladi.

### Real ishda qachon kerak

- Pipeline 20 daqiqa bo'lib qolganda: avval nima cache qilinmayotganini va nima ketma-ket turib parallel bo'la olishini qarang.
- "Cache'ni tozalagandan keyin tuzaldi" degan gap cache to'g'rilikka ta'sir qilayotganini bildiradi, ildiz sababni toping.
- Test hisoboti yoki coverage PR'da ko'rinishi uchun u job'dan artifact sifatida chiqarilishi kerak.

### Nima uchun shunday

Ikki mexanizm ajratilgani sababi: ularning kafolatlari har xil. Artifact aniq bir run'ga tegishli va yo'qolmasligi kerak, cache esa istalgan payt o'chirilishi mumkin va tizim buni sezmasligi lozim. Bittasiga birlashtirilsa (hamma narsani "saqlab qo'yamiz"), qaysi fayl natija, qaysi biri tezlatgich ekani yo'qoladi va eski fayl tufayli o'tadigan build paydo bo'ladi.

## 5. Pipeline as code va lokal pipeline

### Bu nima

Pipeline ta'rifi repo ichidagi faylda turadi (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`), CI tizimining UI sozlamalarida emas. Bu "pipeline as code".

### Mexanizm

CI tizimi hodisadagi commit SHA bo'yicha repo'ni oladi va pipeline faylini o'sha commit'ning o'zidan o'qiydi. Natija:

- Pipeline o'zgarishi kod bilan birga PR'da review qilinadi (git 3) va tarixda qoladi.
- Har branch o'z pipeline versiyasiga ega, eski commit'ni o'sha paytdagi pipeline bilan qayta qurish mumkin.
- CI serveri yo'qolsa, pipeline yo'qolmaydi.

### Misol: faylni qatorma-qator o'qish

GitHub Actions uchun eng kichik pipeline (sintaksis 2-darsda, hozir faqat tuzilishga qarang):

```yaml
on:
  pull_request:
  push:
    branches: [main]
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<versiya>
      - run: make check
```

`on:` trigger'lar: har PR va `main` ga har push. `jobs:` graf, bu yerda bitta `verify` job'i. `runs-on:` runner turi: GitHub bergan toza Ubuntu VM. `steps:` ketma-ket qadamlar: birinchisi repo'ni klonlaydi (toza muhitda kod ham yo'q), ikkinchisi `make check` ni shell'da ishga tushiradi va uning exit code'i job natijasini belgilaydi. Butun mantiq `make check` ichida, YAML faqat "qachon va qayerda" ni aytadi.

**Tuzoq: mantiqni YAML ichiga yozish.** 40 qatorli `script:` bloki lokal ishga tushmaydi, test qilinmaydi va boshqa CI tizimiga ko'chmaydi. Mantiq repo ichidagi skript yoki `Makefile` target'ida tursin, pipeline faqat ularni chaqirsin. Shu darsning amaliy qismi aynan shuni quradi, 2–4-darslarda uch xil CI shu target'larni chaqiradi.

### Makefile pipeline sifatida

`make` (bu repo'dagi `make check`, `make new` dan tanish) target'lar va ularning bog'liqliklarini biladi, ya'ni o'zi kichik graf ijrochisi. `package.json` dagi `scripts` ga o'xshaydi, farqi: bog'liqlik grafi bor va tilga bog'liq emas. Boshqa holat uchun qisqa parcha:

```make
.PHONY: docs spell
docs: spell
	docker run --rm -v "$(PWD)":/work -w /work alpine:3 wc -l README.md
spell:
	test -s README.md
```

`docs: spell` "docs dan oldin spell bajarilsin" degani. Retsept qatorlari TAB bilan boshlanadi, har qator alohida shell'da ishlaydi va har birining exit code'i tekshiriladi. `.PHONY` va xatoda to'xtash xulqini 10- va 11-vazifalarda o'zingiz tekshirasiz.

### Real ishda qachon kerak

- CI'dagi xatoni debug qilish: `make test` lokal ishlasa, "commit, push, kut" sikli kerak emas.
- CI tizimini almashtirish (masalan Jenkins'dan GitHub Actions'ga): mantiq Makefile'da bo'lsa, faqat yupqa YAML qayta yoziladi.
- Yangi dasturchi `make ci` bilan pipeline nima qilishini bir buyruqda ko'radi.

### Nima uchun shunday

Ilgari pipeline CI serverining veb-formalarida sozlanardi (klassik Jenkins job'lari): kim nimani qachon o'zgartirgani ko'rinmasdi, review yo'q edi, server diski buzilsa hammasi yo'qolardi. Kod sifatida saqlash pipeline'ga ilova kodi bilan bir xil kafolatlarni beradi: tarix, review, revert. Narxi: pipeline faylini o'zgartira oladigan har kim pipeline nima qilishini ham o'zgartira oladi, bu 8-bo'limdagi xavfsizlik savoliga olib keladi.

## 6. Trunk-based development va feature flag

### Bu nima

CI'ning ta'rifi (kuniga kamida bir marta `main` ga) branch strategiyasiga talab qo'yadi. **Trunk-based development**: bitta asosiy branch (`main`, "trunk"), branch'lar qisqa (soatlar, ko'pi bilan 1–2 kun), PR'lar kichik. `main` har doim deploy qilishga yaroqli holatda.

### Mexanizm: tugallanmagan ish `main` ga qanday kiradi

Katta funksiya ikki kunda bitmaydi. Uni bo'laklab, **feature flag** ortida birlashtirasiz. Feature flag bu kod yo'lini konfiguratsiya orqali yoqib-o'chiradigan shart:

```js
// flag value comes from configuration, not from the build
if (flags.newCheckout) {
  return renderNewCheckout(cart);
}
return renderOldCheckout(cart);
```

Kod production'ga deploy qilingan, lekin `newCheckout` o'chiq bo'lgani uchun foydalanuvchi eski yo'lni ko'radi. Shu bilan ikki tushuncha ajraladi: **deploy** (kodni serverga chiqarish) va **release** (funksiyani foydalanuvchiga ochish). Deploy texnik hodisa, release biznes qarori va uni flag'ni yoqish bilan, yangi deploy'siz qilish mumkin.

### Misol: bir funksiya, ikki yo'l

| | Uzoq feature branch | Trunk-based |
|-|---------------------|-------------|
| 1-kun | `feature/checkout` ochildi | flag qo'shildi (o'chiq), birinchi kichik PR merge |
| 2–9-kun | branch'da 40 commit, `main` 120 commit oldinga ketdi | har kuni 1–2 PR, har biri `main` bilan birga sinalgan |
| 10-kun | bitta katta merge, konfliktlar, sinalmagan kombinatsiyalar | flag staging'da yoqiladi, sinov |
| Xato chiqsa | 40 commit ichidan qidirish | flag'ni o'chirish, keyin oxirgi kichik PR'ni ko'rish |

Uzoq branch'dagi "CI yashil" belgisi aldamchi: u faqat branch'ning o'zini tekshiradi, `main` bilan integratsiyani emas.

### Real ishda qachon kerak

- Katta refactoring yoki redesign: bo'laklab, flag ortida.
- Xavfli funksiyani avval ichki foydalanuvchilarga, keyin 5 foizga ochish.
- Git modulidagi GitFlow (`develop`, `release/*`) reliz sikllari uzun mahsulotlarga mos (mobil ilova, o'rnatiladigan dastur). Tez-tez deploy qilinadigan web servis uchun u ortiqcha kechikish.

### Nima uchun shunday

Trunk-based yondashuv 1-bo'limdagi hisobning bevosita natijasi: integratsiya og'rig'i branch yoshi bilan o'ssa, branch'ni qisqartirish kerak. Narxi bor: flag'lar kodda shartlar ko'paytiradi va o'chirilmagan eski flag'lar texnik qarzga aylanadi, shuning uchun funksiya to'liq ochilgach flag va eski yo'l o'chiriladi. Muqobili (uzoq branch'lar) kodni toza saqlaydi, lekin integratsiyani oxirga suradi.

## 7. Build once, deploy many: environment'lar va promotion

### Bu nima

**Environment** bu ilovaning ishlab turgan bitta nusxasi va uning konfiguratsiyasi. Tipik zanjir: `dev` (har commit, avtomatik), `staging` (production'ga o'xshash), `production`. Vercel'ning har PR uchun beradigan preview havolasi vaqtinchalik (ephemeral) environment: PR bilan tug'iladi, PR bilan o'ladi.

**Build once, deploy many**: artifact (bizda Docker image) bir marta quriladi va aynan o'sha artifact barcha environment'lardan o'tadi. Bir environment'dan keyingisiga o'tkazish **promotion** deyiladi: yangi build emas, o'sha artifact'ni keyingi joyga deploy qilish.

### Mexanizm

Staging'da sinalgan narsa va production'ga chiqqan narsa bayt darajasida bir xil bo'lishi kerak. Qayta build qilinsa dependency versiyasi, base image yoki build mashinasi farq qilishi mumkin (Laboratoriyadagi `amd64` va `arm64` misoli), demak sinalmagan narsa chiqadi. Bundan uch qoida:

- **Artifact o'zgarmas identifikator bilan belgilanadi**: commit SHA yoki image digest (docker 2: image tarkibining `sha256:` hash'i). `latest` identifikator emas, u siljiydigan ko'rsatkich. `package-lock.json` dependency'lar uchun nima qilsa, digest image uchun shuni qiladi: "taxminan shu" emas, "aynan shu".
- **Konfiguratsiya artifact ichida emas, environment'da**: env variable, config fayl, secret. Bu 12-factor qoidasi (Manbalar), cloud 4 da `.env` faylni serverga alohida qo'yganingiz shu edi.
- **Gate** bu promotion sharti: avtomatik (testlar, smoke test, ya'ni deploy'dan keyingi "ilova javob beryaptimi" tekshiruvi) yoki qo'lda (approval).

### Misol: bitta digest'ning yo'li

```
$ docker pull alpine:3
3: Pulling from library/alpine
...
Digest: sha256:<64 ta hex belgi>
Status: Downloaded newer image for alpine:3
docker.io/library/alpine:3
```

`3: Pulling from library/alpine` teg va repo; `Digest:` shu paytda `3` tegi ko'rsatib turgan image'ning hash'i; oxirgi qator to'liq nom. Ertaga `alpine:3` boshqa digest'ga siljishi mumkin, `alpine@sha256:<...>` esa hech qachon o'zgarmaydi. Promotion jadvali shunday ko'rinadi:

| Qadam | Nima bo'ladi | Image |
|-------|--------------|-------|
| `main` ga merge | build, registry'ga push | `shop@sha256:ab12...` (teg: commit SHA `7c1f2e9`) |
| staging deploy | o'sha image, `DB_URL` staging bazasiga | `sha256:ab12...` |
| gate | smoke test yashil, approval | |
| production deploy | o'sha image, `DB_URL` production bazasiga | `sha256:ab12...` |

Uchala qatorda digest bir xil, farq faqat deploy vaqtida berilgan konfiguratsiyada. Frontend bundle'larda bu qoida alohida tuzoqqa ega (build vaqtida bundle ichiga yoziladigan o'zgaruvchilar), uni 4-vazifada o'zingiz tahlil qilasiz.

### Real ishda qachon kerak

- Incident paytida birinchi savol: production'da hozir qaysi versiya, kim, qachon deploy qilgan. Bu deployment history, SHA teglari bo'lsa javob bir qatorda.
- Rollback: oldingi digest'ni qayta deploy qilish, qayta build emas (5-darsda).
- Environment'lar orasidagi farq qancha kichik bo'lsa, staging'dagi test shuncha ishonchli. Farq faqat konfiguratsiya va o'lchamda bo'lsin, deploy usulida emas.
- Har environment o'z secret'lariga ega: staging job'i production secret'ini ko'ra olmasligi kerak.

### Nima uchun shunday

Qoida Humble va Farley'ning "Continuous Delivery" kitobidan ("only build your binaries once") va 12-factor'ning build, release, run bosqichlarini ajratish talabidan keladi. Muqobili (har environment uchun alohida build) sodda ko'rinadi: `npm run build:staging`, `npm run build:prod`. Lekin u "staging'da ishlagan edi" degan gapni ma'nosiz qiladi, chunki staging'da boshqa artifact ishlagan.

## 8. Pipeline'da secret'lar

### Bu nima

Secret bu egasiga kirish huquqini beradigan qiymat: token, parol, SSH private key (git 4 da token va deploy key'larni ko'rdingiz). Pipeline registry'ga push qiladi, serverga kiradi, cloud API chaqiradi. Demak u production'ga eng kuchli kirish huquqiga ega tizimlardan biri va hujumchilar uchun asosiy nishon.

### Mexanizm: secret job'ga qanday yetadi

Secret repo'da turmaydi. U CI tizimining secret omborida shifrlangan holda saqlanadi va faqat job ishga tushganda runner'ga env variable yoki fayl sifatida beriladi. Qoidalar:

- **Least privilege** (eng kam huquq): token faqat kerakli ishni qila olsin (faqat bitta registry'ga push, faqat bitta serverga deploy). Har environment uchun alohida secret.
- Qisqa yashaydigan credential uzoq yashaydigandan yaxshi. Zamonaviy usul OIDC: pipeline cloud'dan bir necha daqiqalik token oladi, saqlanadigan kalit umuman yo'q (5-darsda).
- Ishonchsiz kod (fork'dan kelgan PR) secret'larni ko'rmasligi kerak: PR muallifi pipeline ishlatadigan kodni o'zi yozadi, demak `echo $TOKEN` ham yoza oladi. CI tizimlari buni standart holatda ta'minlaydi, lekin noto'g'ri sozlama bilan buzish oson.

### Misol: bitta flag secret'ni log'ga chiqaradi

`set -x` (linux 5) shell'ga har buyruqni bajarishdan oldin, o'zgaruvchilar ochilgan holda chop etishni buyuradi. Debug uchun qulay, secret uchun xavfli:

```
$ TOKEN=demo-123 bash -c 'set -x; test -n "$TOKEN"'
+ test -n demo-123
```

`+` bilan boshlangan qator shell'ning izi: `$TOKEN` o'rnida qiymatning o'zi turibdi. CI'da bu qator log'ga yoziladi, log'ni esa repo'ga kirishi bor har kim (public repo'da hamma) o'qiydi.

CI tizimlari log'da secret qiymatini `***` bilan almashtiradi (maskalash), lekin faqat aynan o'sha satrni:

```
$ printf 'demo-123' | base64
ZGVtby0xMjM=
```

`ZGVtby0xMjM=` endi boshqa satr, maskalash uni tanimaydi, `base64 -d` esa bir qadamda asl qiymatni qaytaradi. **Tuzoq: log maskalash himoya emas.** U tasodifiy xatodan saqlaydi, niyatli hujumdan emas.

Secret oqib chiqadigan yo'llar: log'ga chop etish (`set -x`, `env`, xato xabari ichida), artifact ichiga tushib qolish (`.env` fayl, `docker build` ning `ARG` qiymati image tarixida qoladi), uchinchi tomon action yoki plugin'ning buzilgan versiyasi, PR'dagi pipeline faylini o'zgartirish.

### Real ishda qachon kerak

- Yangi pipeline yozganda har job uchun savol: bu job qaysi secret'larni ko'radi va ularning har biri unga kerakmi.
- Secret log'da ko'rinib qolsa: log'ni o'chirish yetmaydi, secret bekor qilinadi va yangisi chiqariladi (rotation).
- Open-source loyihada fork PR'lari uchun pipeline sozlash.

### Nima uchun shunday

Secret'ning kodda turmasligi sababi: git tarixi abadiy va har klonda bor, bir marta commit qilingan token keyingi commit bilan "o'chmaydi". Alohida ombor esa kirishni cheklash, almashtirish va audit qilish imkonini beradi. Muqobili (secret'ni runner mashinasiga qo'lda qo'yish) kichik jamoada ishlaydi, lekin o'sha runner'da ishlagan har job hamma secret'ni ko'radi.

## 9. DORA metrikalari

### Bu nima

DORA (DevOps Research and Assessment) ko'p yillik tadqiqot dasturi, u dasturiy ta'minot yetkazish samaradorligini o'lchaydigan to'rt metrikani ommalashtirdi ("four keys", "Accelerate" kitobi):

| Metrika | Nimani o'lchaydi | Turi |
|---------|------------------|------|
| Deployment frequency | production'ga qanchalik tez-tez deploy qilinadi | tezlik |
| Lead time for changes | commit'dan production'gacha qancha vaqt | tezlik |
| Change failure rate | deploy'larning necha foizi nosozlikka olib keladi | barqarorlik |
| Time to restore service | nosozlikdan keyin qancha vaqtda tiklanadi | barqarorlik |

### Mexanizm: har biri qayerdan olinadi

Hamma ma'lumot pipeline va incident tarixida bor: deploy'lar soni va vaqti (deployment history), commit vaqti (git), qaysi deploy'dan keyin rollback yoki hotfix bo'lgani, incident ochilgan va yopilgan vaqt.

### Misol: bir oylik hisob

Jamoa 30 kunda production'ga 20 marta deploy qildi. Ulardan 3 tasidan keyin rollback yoki shoshilinch tuzatish kerak bo'ldi. Uch nosozlik 30, 45 va 120 daqiqada tiklandi. Commit'dan production'gacha o'rtacha 2 kun o'tgan.

- Deployment frequency: `20 / 30`, taxminan haftasiga 4–5 marta.
- Lead time for changes: 2 kun.
- Change failure rate: `3 / 20 = 15%`.
- Time to restore: `(30 + 45 + 120) / 3 = 65` daqiqa (median 45 daqiqa; bitta uzun incident o'rtachani tortadi, shuning uchun median ko'pincha foydaliroq).

### Real ishda qachon kerak

- "Pipeline'ga vaqt sarflash kerakmi" degan bahsda fikr o'rniga raqam ko'rsatish.
- O'zgarishdan oldin va keyin tendensiyani solishtirish (masalan trunk-based'ga o'tgach lead time qanday o'zgardi).

**Tuzoq: metrikani maqsadga aylantirish.** "Kuniga 10 deploy" KPI qilib qo'yilsa, jamoa bo'sh deploy'lar qiladi. Metrikalar jamoa darajasida, tendensiyani ko'rish uchun ishlatiladi, shaxsni baholash uchun emas.

### Nima uchun shunday

Tadqiqotning asosiy xulosasi: tezlik va barqarorlik bir-biriga zid emas. Yaxshi natija ko'rsatgan jamoalar ham tez-tez deploy qiladi, ham kam buzadi, chunki kichik o'zgarishni tekshirish va qaytarish oson (1-bo'limdagi hisob). Ikki juft metrika birga o'lchanishi sababi ham shu: faqat tezlikni o'lchasangiz sifat qurbon qilinadi, faqat barqarorlikni o'lchasangiz hech kim deploy qilmay qo'yadi. Keyingi yillardagi hisobotlarda to'plam o'zgartirilgan (nomlar aniqlashtirilgan, metrika qo'shilgan), joriy ro'yxat va ta'riflarni dora.dev'dan o'qing.

## 10. Asboblar manzarasi

### Bu nima

Keyingi uch dars to'rt asbobni o'rgatadi. Hammasi 3-bo'limdagi modelni amalga oshiradi, farq kim nimani boshqarishida:

| | GitHub Actions | GitLab CI | Jenkins | TeamCity |
|-|----------------|-----------|---------|----------|
| Model | GitHub'ga o'rnatilgan SaaS | GitLab'ga o'rnatilgan (SaaS va self-managed) | mustaqil open-source server | mustaqil tijorat server (JetBrains), cloud varianti ham bor |
| Control plane | hosted (Enterprise Server'da self-hosted) | hosted yoki self-managed | faqat self-hosted | self-hosted yoki TeamCity Cloud |
| Ijrochi | hosted runner yoki self-hosted runner | hosted runner yoki self-hosted runner | o'z agent'laringiz | o'z agent'laringiz (cloud'da hosted) |
| Konfiguratsiya | YAML, `.github/workflows/*.yml` | YAML, `.gitlab-ci.yml` | Groovy DSL, `Jenkinsfile` | UI yoki Kotlin DSL, `.teamcity/settings.kts` |
| Qayta ishlatish | action'lar marketplace, reusable workflow | `include`, shablonlar, CI/CD components | shared library, mingdan ortiq plugin | meta-runner, template, Kotlin kodi |
| Kuchli tomoni | kirish oson, ulkan ekotizim, GitHub bilan integratsiya | yagona platforma (repo, CI, registry, environments), kuchli `rules` va DAG | cheksiz moslashuvchanlik, har qanday muhit, bepul | qulay UI, build zanjirlari, test tahlili, tipli DSL |
| Zaif tomoni | GitHub'ga bog'liqlik, uchinchi tomon action'lar xavfi | ilg'or funksiyalar pulli tarifda | ekspluatatsiya yuki: yangilash, plugin'lar, xavfsizlik | litsenziya narxi, kichikroq hamjamiyat |

### Mexanizm: ikki qism

Har CI tizimi ikki qismdan iborat. **Control plane**: hodisalarni qabul qiladi, grafni tuzadi, navbatni yuritadi, log va secret'larni saqlaydi, UI ko'rsatadi. **Ijrochi** (runner, agent): job'ni bajaradi. "Hosted" bu qismni xizmat egasi ishlatadi, "self-hosted" siz o'z mashinangizda ishlatasiz. Tanlov mezonlari shu ikki qismdan chiqadi:

- Kod qayerda turadi: CI kod hosting'iga o'rnatilgan bo'lsa, hodisalar va PR statuslari tayyor ulangan.
- Control plane'ni kim ekspluatatsiya qiladi: self-hosted server yangilash, backup va xavfsizlik yamoqlarini sizga yuklaydi.
- Ijrochi qayerda turishi shart: job ichki tarmoqdagi resursga yetishi yoki maxsus operatsion tizim va qurilma talab qilishi mumkin.

### Misol: mezonlarni qo'llash

Open-source TypeScript kutubxonasi, kod GitHub'da, testlar Linux, macOS va Windows'da o'tishi kerak, maintainerlar ikki kishi. Kod GitHub'da (birinchi mezon), server boqishga odam yo'q (ikkinchi), uch operatsion tizim hosted runner sifatida tayyor va ichki tarmoq kerak emas (uchinchi). Xulosa: GitHub Actions, hosted runner'lar. Mezonlardan birortasi boshqacha bo'lsa xulosa ham o'zgaradi, buni 7-vazifada uch holatda sinaysiz.

### Real ishda qachon kerak

- Ish e'lonida "Jenkins" yoki "GitLab CI" yozilgan bo'lsa: model bir xil, sintaksis boshqa.
- Bir asbobdan ikkinchisiga migratsiya: mantiq Makefile'da bo'lsa (5-bo'lim), ko'chadigan narsa kam.

### Nima uchun shunday

Jenkins (2011, Hudson loyihasidan ajralgan) CI serverlari kod hosting'idan alohida bo'lgan davrdan: har narsa plugin, har narsa o'zingizda. Git hosting'lar CI'ni o'ziga qo'shgach (GitLab CI, keyin 2019-yilda GitHub Actions) ko'p jamoalar uchun "server boqish" yuki yo'qoldi. Mustaqil serverlar yo'qolmadi, chunki hamma kod ham ommaviy cloud'ga chiqa olmaydi. Model hammasida bir xil: trigger, job'lar grafi, ijrochi mashina, secret ombori, artifact. Bitta asbobni chuqur bilsangiz, ikkinchisi sintaksis masalasi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Integratsiya | o'zgarishni umumiy branch'ga qo'shish va birga ishlashini tekshirish |
| Continuous Integration | hamma kuniga kamida bir marta `main` ga birlashtiradigan va har birlashtirish avtomatik tekshiriladigan amaliyot |
| Continuous Delivery | har commit chiqarishga tayyor, production'ga chiqish inson qarori bilan |
| Continuous Deployment | testlardan o'tgan har commit production'ga tasdiqsiz chiqadi |
| Pipeline | hodisa bilan boshlanadigan avtomatik job'lar grafi |
| Trigger | pipeline'ni boshlovchi hodisa (push, PR, tag, jadval) |
| Stage | pipeline'ning mantiqiy bosqichi |
| Job | bitta runner'da toza muhitda bajariladigan ish birligi |
| Step | job ichidagi bitta buyruq |
| Runner (agent) | job'ni navbatdan olib bajaradigan dastur va uning mashinasi |
| Exit code | buyruq tugaganda qaytaradigan son, pipeline natijani shundan biladi |
| Fail fast | birinchi xatoda qolgan qadamlarni bajarmay to'xtash |
| Artifact | pipeline natijasi bo'lgan, saqlanadigan va deploy qilinadigan fayl yoki image |
| Cache | faqat tezlashtirish uchun saqlanadigan, yo'qolsa qayta olinadigan fayllar |
| Pipeline as code | pipeline ta'rifini repo ichidagi faylda saqlash |
| Trunk-based development | qisqa branch'lar va har doim deploy'ga yaroqli bitta asosiy branch |
| Feature flag | kod yo'lini konfiguratsiya orqali yoqib-o'chiradigan shart |
| Deploy va release | kodni serverga chiqarish va funksiyani foydalanuvchiga ochish |
| Environment | ilovaning ishlab turgan nusxasi va uning konfiguratsiyasi (dev, staging, production) |
| Promotion | o'sha artifact'ni qayta build qilmasdan keyingi environment'ga o'tkazish |
| Gate | promotion sharti: avtomatik tekshiruv yoki qo'lda approval |
| Smoke test | deploy'dan keyin ilova umuman javob berayotganini tekshiradigan qisqa sinov |
| Digest | image tarkibining `sha256:` hash'i, o'zgarmas identifikator |
| Secret | kirish huquqini beradigan qiymat (token, parol, kalit) |
| Least privilege | har token va job'ga faqat kerakli eng kam huquqni berish |
| Maskalash | CI log'ida secret satrini `***` bilan almashtirish |
| DORA metrikalari | yetkazish tezligi va barqarorligini o'lchaydigan to'rt ko'rsatkich |
| Control plane | CI tizimining hodisa, navbat, log va secret'larni boshqaradigan qismi |

## Tuzoqlar

- Har environment uchun alohida build qilish. Test qilingan va deploy qilingan artifact turli bo'ladi.
- `latest` tag bilan deploy. Qaysi commit ishlab turganini ham, nimaga rollback qilishni ham bilmaysiz.
- Sekin pipeline'ga chidash. 30 daqiqalik CI'ni odamlar aylanib o'tishni boshlaydi (`[skip ci]`, to'g'ridan `main` ga push).
- Flaky testni (bir xil kodda goh o'tib, goh yiqiladigan test) "qayta ishga tushirsa o'tadi" deb qoldirish. Jamoa qizil pipeline'ga ishonmay qo'yadi va haqiqiy xatoni ham retry qiladi.
- Buzilgan `main` ustiga yangi commit'lar qo'yish. Qoida: `main` qizil bo'lsa, birinchi ish uni tuzatish yoki revert.
- Butun mantiqni YAML ichiga yozish. Lokal takrorlab bo'lmaydi, har tuzatish "commit, push, kut" sikli bilan debug qilinadi.
- Exit code'ni yutib yuborish (`|| true`, xatoni tekshirmaydigan skript). Pipeline yashil, tekshiruv esa bajarilmagan.
- Bitta kuchli token'ni hamma job va environment'ga berish.
- Cache'ga to'g'rilik uchun tayanish yoki cache kalitini noto'g'ri tanlash (lockfile o'zgarganda eski dependency'lar ishlatiladi).
- Uzoq yashaydigan branch'da "CI yashil" deb xotirjam bo'lish. U faqat branch'ni tekshiradi, `main` bilan integratsiyani emas.
- Zorin'da konteyner `root` bo'lib yozgan fayllar (`node_modules`, `coverage/`) host'da `root` niki bo'lib qoladi. `--user "$(id -u):$(id -g)"` ishlating. macOS'da bu ko'rinmaydi, shuning uchun uyda ishlagan Makefile ofisda "Permission denied" berishi mumkin.
- Makefile'da GNU Make 4 imkoniyatlari yoki retseptda GNU'ga xos flag'lar. Zorin'da ishlaydi, macOS'da (Make 3.81, BSD utilitalar) sinadi.
- Ofisda (`amd64`) va uyda (`arm64`) qurilgan image'lar bir xil emas. Bir mashinada qurilgan image'ni ikkinchisida "o'sha" deb hisoblamang, har mashinada qayta quring.

## Manbalar

- https://martinfowler.com/articles/continuousIntegration.html – Continuous Integration (majburiy)
- https://martinfowler.com/bliki/ContinuousDelivery.html – Continuous Delivery qisqa ta'rifi
- https://martinfowler.com/bliki/DeploymentPipeline.html – deployment pipeline tushunchasi
- https://martinfowler.com/articles/feature-toggles.html – feature flag turlari va narxi
- https://trunkbaseddevelopment.com/ – trunk-based development
- https://dora.dev/guides/dora-metrics-four-keys/ – DORA metrikalari, joriy ta'riflar
- https://12factor.net/build-release-run – build, release, run bosqichlarini ajratish
- https://12factor.net/config – konfiguratsiya environment'da
- https://docs.npmjs.com/cli/commands/npm-ci – `npm ci` xulqi
- https://docs.docker.com/reference/cli/docker/container/run/ – `docker run`, exit code'lar, `--user`
- https://www.gnu.org/software/make/manual/make.html – GNU make qo'llanmasi
- Humble, Farley, "Continuous Delivery", 1-qism (5-bob: Anatomy of the Deployment Pipeline)
- Forsgren, Humble, Kim, "Accelerate" – DORA metrikalari qayerdan kelgani

## Birga bajaramiz

Kod emas, oddiy matn fayli uchun kichik pipeline quramiz: tekshiruv, paketlash, ikki "environment" ga promotion. Misol ataylab Node'siz va image'siz, vazifalardagi ilova bilan kesishmaydi. Hamma narsa host'da, vaqtinchalik papkada (macOS'da u uy papkasi ostida bo'lsin, aks holda bind mount ishlamaydi).

1. Loyiha va birinchi commit:

```
$ mkdir -p ~/cicd-walk && cd ~/cicd-walk
$ git init -q -b main
$ printf 'artifact\ncache\nrunner\n' > glossary.txt
$ git add glossary.txt && git commit -q -m "add glossary"
$ git rev-parse --short HEAD
<sha>
```

`-q` chiqishni o'chiradi, `-b main` branch nomini belgilaydi. `<sha>` shu holatning qisqa identifikatori, keyin artifact nomiga kiradi.

2. Bitta tekshiruvni toza muhitda bajaramiz. Qoida: atamalar alifbo tartibida. `sort -c` saralanganlikni faqat tekshiradi, hech narsa chop etmaydi va natijani exit code bilan aytadi:

```
$ docker run --rm -v "$PWD":/work -w /work alpine:3 sort -c glossary.txt; echo $?
0
```

Konteyner har safar yangi, unda faqat image va ulangan papka bor. `0` konteyner ichidagi `sort` dan `docker run` orqali host shell'ga yetib keldi. Shu buyruq Zorin'da `amd64`, Mac'da `arm64` image bilan ishladi, natija bir xil.

3. Tekshiruvni buzamiz:

```
$ echo 'agent' >> glossary.txt
$ docker run --rm -v "$PWD":/work -w /work alpine:3 sort -c glossary.txt; echo $?
sort: <tartib buzilgan qator haqida xabar>
1
```

`agent` oxirga qo'shildi, tartib buzildi. Xabar odam uchun, `1` esa mashina uchun: pipeline faqat shu songa qaraydi.

4. Qadamni nomlaymiz. `Makefile` (retsept qatori TAB bilan boshlanadi):

```make
.PHONY: sorted package
sorted:
	docker run --rm -v "$(PWD)":/work -w /work alpine:3 sort -c glossary.txt
package: sorted
	mkdir -p dist
	tar -czf dist/glossary.tar.gz glossary.txt
```

```
$ make package
docker run --rm -v "<yo'l>/cicd-walk":/work -w /work alpine:3 sort -c glossary.txt
sort: <tartib buzilgan qator haqida xabar>
make: *** [sorted] Error 1
$ ls dist
ls: dist: No such file or directory
```

`make` avval `package` ning bog'liqligi `sorted` ni ishga tushirdi va retsept qatorini chop etdi. Qator `1` qaytardi, `make` `Error 1` deb to'xtadi, `package` retsepti umuman boshlanmadi: `dist` papkasi yo'q. Xato qatori Mac'dagi Make 3.81 ko'rinishida; Zorin'dagi 4.x da `make: *** [Makefile:3: sorted] Error 1`, ya'ni fayl va qator raqami ham bor. `ls` xabari ham host'ga qarab farq qiladi (Zorin'da `ls: cannot access 'dist': ...`). `make` ning o'zi qanday kod qaytarishini 11-vazifada o'lchaysiz.

5. Tuzatamiz, commit qilamiz va artifact chiqaramiz:

```
$ sort -o glossary.txt glossary.txt
$ git commit -q -am "sort glossary"
$ make package
docker run --rm -v "<yo'l>/cicd-walk":/work -w /work alpine:3 sort -c glossary.txt
mkdir -p dist
tar -czf dist/glossary.tar.gz glossary.txt
$ mv dist/glossary.tar.gz "dist/glossary-$(git rev-parse --short HEAD).tar.gz"
$ ls dist
glossary-<sha2>.tar.gz
```

Endi uch retsept qatori ham bajarildi. Arxiv nomidagi `<sha2>` uni aynan qaysi commit'dan qurilganiga bog'laydi: `glossary-latest.tar.gz` bunday da'vo qila olmasdi.

6. Promotion: o'sha faylni ikki "environment" ga qayta qurmasdan o'tkazamiz, konfiguratsiyani alohida beramiz:

```
$ mkdir -p env/staging env/production
$ cp dist/glossary-*.tar.gz env/staging/ && cp dist/glossary-*.tar.gz env/production/
$ echo 'TITLE=Glossary (staging)' > env/staging/config
$ echo 'TITLE=Glossary' > env/production/config
$ cksum env/*/glossary-*.tar.gz
<CRC> <bayt> env/production/glossary-<sha2>.tar.gz
<CRC> <bayt> env/staging/glossary-<sha2>.tar.gz
```

`cksum` har fayl uchun nazorat yig'indisi va bayt hajmini chiqaradi (ikkala host'da bor). Ikki qatorda `<CRC>` va `<bayt>` bir xil: artifact bitta, farq faqat yonidagi `config` faylda. Image uchun shu rolni digest bajaradi.

7. Fayl egasi farqini ko'ramiz va tozalaymiz:

```
$ docker run --rm -v "$PWD":/work -w /work alpine:3 touch by-container.txt
$ ls -l by-container.txt
-rw-r--r-- 1 <egasi> <guruh> 0 <sana> by-container.txt
$ cd ~ && rm -rf ~/cicd-walk
```

Zorin'da `<egasi>` `root` (konteyner jarayoni root edi), Mac'da sizning foydalanuvchingiz. Papka sizniki bo'lgani uchun `rm -rf` ikkalasida ishlaydi; `--user "$(id -u):$(id -g)"` bilan takrorlasangiz Zorin'da ham ega siz bo'lasiz.

Shu 7 qadamda ko'rganingiz: toza muhitdagi qadam va exit code (3-bo'lim), mantiq Makefile'da va birinchi xatoda to'xtash (5-bo'lim), natija cache emas artifact ekani (4-bo'lim), SHA bilan nomlangan artifact'ning qayta build'siz promotion'i va konfiguratsiyaning tashqarida turishi (7-bo'lim), ikki mashina farqi (Laboratoriya).

---

## Vazifalar

Ish papkasi: `cicd/01-intro/` (`make new m=cicd n=01 name=intro` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`app/`, `Makefile`, `ci.sh`, `Dockerfile`) shu papkada saqlanadi. Barcha buyruqlar host'da bajariladi, Node va linter'lar konteynerda. Makefile va `ci.sh` ikkala mashinada (Zorin: Make 4.x, GNU utilitalar; macOS: Make 3.81, BSD utilitalar) o'zgarishsiz ishlashi kerak. B guruhni bir mashinada boshlab ikkinchisida davom ettirsangiz, image'larni qayta quring.

### A. Tahlil

1. **Three terms.** O'zingiz ishlagan (yoki ishlayotgan) loyihani oling. U CI, continuous delivery yoki continuous deployment bosqichlaridan qaysi birida? 2-bo'limdagi mezonlar bo'yicha asoslang: `main` ga qanchalik tez-tez birlashtiriladi, production'ga chiqish qanday qaror bilan bo'ladi, qaysi qadam qo'lda. Yo'nalish: 2-bo'lim, "Mexanizm: har birining mezoni".

2. **Pipeline map.** O'sha loyihaning (yoki o'zingiz bilgan open-source loyihaning) pipeline faylini o'qing. Jadval tuzing: har job uchun trigger, taxminiy davomiyligi, nimani cache qiladi, qanday artifact chiqaradi. Tartib "arzondan qimmatga" qoidasiga mos keladimi? Yo'nalish: 3-bo'lim, "Mexanizm: PR ochilganda nima bo'ladi" va 4-bo'lim, "Tez feedback va tartib".

3. **Artifact or cache.** Quyidagilarning har biri artifact yoki cache ekanini va sababini yozing: `~/.npm`, `dist/`, `coverage/lcov.info`, Docker build layer'lari, registry'ga push qilingan image, `node_modules`, JUnit XML hisoboti. Qaysi biri o'chirilsa pipeline buziladi? Yo'nalish: 4-bo'lim, "Mexanizm" (sinov savoli).

4. **Build once violation.** Frontend loyihada `VITE_API_URL` build vaqtida berilsa, "build once, deploy many" qanday buziladi? Kamida ikki yechim taklif qiling va har birining kamchiligini yozing. Yo'nalish: 7-bo'lim, "Mexanizm".

5. **Secret leak paths.** Pipeline'dan secret oqib chiqishining kamida beshta yo'lini sanang va har biri uchun bitta himoya chorasini yozing. Maskalash qaysi yo'llarni yopmasligini alohida ko'rsating. Yo'nalish: 8-bo'lim, "Misol: bitta flag secret'ni log'ga chiqaradi".

6. **DORA estimate.** O'zingiz bilgan jamoa uchun to'rt DORA metrikasini taxminan baholang (aniq raqam bo'lmasa oraliq). Qaysi biri eng zaif va uni yaxshilash uchun pipeline'da birinchi navbatda nimani o'zgartirgan bo'lardingiz? Yo'nalish: 9-bo'lim, "Misol: bir oylik hisob".

7. **Tool choice.** Uch holat uchun asbob tanlang va asoslang: (a) GitHub'dagi 5 kishilik startap, (b) internetga chiqishi yo'q yopiq tarmoqdagi bank, kod ichki GitLab'da, (c) 15 yillik C++ mahsuloti, Windows va Linux build'lari, maxsus apparatda testlar. Yo'nalish: 10-bo'lim, "Mexanizm: ikki qism".

### B. Lokal pipeline

8. **Demo app.** `app/` ichida kichik Node HTTP servis yozing (framework'siz yoki minimal): `GET /healthz` 200 qaytaradi, `GET /version` `APP_VERSION` env qiymatini qaytaradi, bitta sof funksiya va unga `node --test` bilan kamida 3 ta test. `package.json` da `test` va `lint` skriptlari bo'lsin. Bu ilova modul oxirigacha ishlatiladi. Host'ga Node o'rnatmang: `npm` buyruqlarini ham konteynerda bajaring. Yo'nalish: Laboratoriya, "Asbobni konteynerda ishlatishning umumiy shakli".

9. **Dockerfile.** Ilova uchun multi-stage `Dockerfile` yozing (docker modulidagi qoidalar: non-root user, `npm ci`, `.dockerignore`). Base image'da joriy LTS major'ni aniq yozing. `hadolint` ni konteynerda ishga tushirib ogohlantirishlarni tuzating yoki nima uchun qoldirganingizni izohlang. Yo'nalish: 4-bo'lim, "Misol: takrorlanuvchi o'rnatish" va docker 2.

10. **Makefile pipeline.** `Makefile` yozing: `lint`, `test`, `build`, `smoke` va hammasini ketma-ket chaqiradigan `ci` target'lari. Node buyruqlari konteynerda ishlasin, ish mashinasidagi Node'ga bog'liq bo'lmasin. `build` image'ni `git rev-parse --short HEAD` qiymati bilan teglasin. `smoke` konteynerni ko'tarib `/healthz` ni tekshirsin va o'chirsin. `.PHONY` nima uchun kerakligini izohlang. Makefile GNU Make 3.81 da ham ishlasin; konteyner host papkasiga fayl yozsa, Zorin'da fayl egasi kim bo'lishini tekshiring. Yo'nalish: 5-bo'lim, "Makefile pipeline sifatida" va Laboratoriyadagi uch qoida.

11. **Fail fast.** Testlardan birini ataylab buzing va `make ci` ni ishga tushiring. `build` bajarildimi? `echo $?` nima qaytardi? `make` qaysi mexanizm bilan to'xtaganini izohlang, so'ng `make -k ci` bilan farqni ko'rsating. Yo'nalish: 3-bo'lim, "Exit code: pipeline'ning yagona tili".

12. **Shell variant.** Xuddi shu pipeline'ni `ci.sh` sifatida yozing. Avval `set -euo pipefail` siz, bitta qadam xato qaytaradigan holatda ishga tushiring va skript davom etib ketishini ko'rsating. Keyin `set -euo pipefail` qo'shing. Har uch flag nimani o'zgartirishini yozing. `shellcheck` toza o'tsin. Skript macOS'dagi bash 3.2 da ham ishlasin. Yo'nalish: 3-bo'lim, "Exit code: pipeline'ning yagona tili" va linux 5.

13. **Immutable tag.** Image'ni ikki marta quring: orasida kodni o'zgartirib commit qiling. `docker image ls` da ikki xil SHA tag borligini ko'rsating. Endi ikkalasini ham `latest` deb teglab ko'ring: `latest` qaysi biriga ishora qiladi va eski versiyaga qaytish uchun nimani bilishingiz kerak bo'ladi? Yo'nalish: 7-bo'lim, "Mexanizm".

14. **Dirty tree guard.** Commit qilinmagan o'zgarish bor paytda `make build` qurgan image aslida qaysi kodni o'z ichiga oladi va tag nimani da'vo qiladi? `git status --porcelain` yordamida iflos daraxtda build'ni rad etadigan (yoki tag'ga `-dirty` qo'shadigan) tekshiruv qo'shing. Yo'nalish: 7-bo'lim, "Mexanizm" (o'zgarmas identifikator).

15. **Promotion drill.** Bitta image'ni qayta build qilmasdan ikki "environment" sifatida ishga tushiring: `staging` (port 8081, `APP_ENV=staging`) va `production` (port 8082, `APP_ENV=production`). Ikkalasida image ID bir xil ekanini `docker inspect` bilan isbotlang. Konfiguratsiya qayerdan kelayotganini izohlang. Yo'nalish: 7-bo'lim, "Misol: bitta digest'ning yo'li".

16. **Pipeline timing.** `make ci` ning har bosqichi qancha vaqt olishini o'lchang (`time`). Ikkinchi ishga tushirishda nima tezlashdi va nima uchun (Docker layer cache, npm cache)? Dependency o'rnatishni tezlashtirish uchun `Dockerfile` da qatorlar tartibi qanday bo'lishi kerakligini izohlang. Qaysi mashinada o'lchaganingizni yozing (Mac'da bind mount sekinroq bo'lishi mumkin). Yo'nalish: 4-bo'lim, "Mexanizm" va docker 2.

### Topshirish

Tayyor bo'lgach:
1. `cicd/01-intro/README.md` da 16 ta vazifaning har biri `## N. Title` sarlavhasi ostida; papkada `app/`, `Makefile`, `ci.sh`, `Dockerfile` bor.
2. `make ci` toza daraxtda noldan oxirigacha o'tadi va exit code 0.
3. Ataylab buzilgan test bilan `make ci` nol bo'lmagan exit code qaytaradi.
4. `shellcheck` va `hadolint` toza (yoki qoldirilgan ogohlantirish izohlangan).
5. Repo ildizida `make check` toza (host'da).
6. Qurilgan sinov image'lari va konteynerlari o'chirilgan (`docker ps -a`, `docker image ls`), `node_modules` commit qilinmagan.
7. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Integratsiya og'rig'i nima uchun branch yoshi bilan o'sadi? Konflikt va sinalmagan kombinatsiya farqi nima?
- Continuous delivery va continuous deployment orasidagi yagona farq nima?
- Nima uchun Jenkins o'rnatilgani "bizda CI bor" degani emas?
- PR'dagi yashil belgi qanday paydo bo'ladi: hodisadan exit code'gacha zanjirni ayting.
- Nima uchun har job toza muhitda boshlanadi va buning ikki oqibati nima?
- Artifact va cache farqi nima? Qaysi biri yo'qolsa pipeline buziladi?
- Nima uchun image har environment uchun qayta qurilmaydi?
- Deploy va release farqi nima, feature flag bunga qanday yordam beradi?
- Nima uchun pipeline mantiqini YAML'da emas, skript yoki Makefile'da saqlash tavsiya qilinadi?
- Log'dagi secret maskalash nima uchun to'liq himoya emas?
- DORA'ning to'rt metrikasidan qaysi ikkitasi tezlikni, qaysi ikkitasi barqarorlikni o'lchaydi? Ular nima uchun bir-biriga zid emas?
- Uzoq yashaydigan feature branch nima uchun CI g'oyasiga zid?
- Bir xil `docker run` buyrug'i Zorin va macOS'da qaysi ikki jihatdan boshqacha ishlaydi (arxitektura, fayl egasi)?
