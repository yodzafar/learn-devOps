# 3-dars: GitLab CI

Maqsad: GitLab CI modelini noldan tushunish va 2-darsdagi pipeline'ni unga ko'chirish. GitLab ko'p kompaniyalarda (ayniqsa self-managed ko'rinishda, ya'ni kompaniyaning o'z serverida, ichki tarmoqda) asosiy platforma, shuning uchun `.gitlab-ci.yml` ni o'qiy va yoza olish kerak. G'oyalar 1-darsdagi bilan bir xil (pipeline, stage, job, runner, cache, artifact), 2-darsdagi GitHub Actions bilan solishtirganda esa "tushuncha o'sha, yozilishi boshqa" va bir necha joyda model ham boshqa: stage'lar birinchi darajali tushuncha, job standart holatda konteynerda ishlaydi, shartlar `rules` bilan yoziladi, o'z runner'ingizni ulash oddiy ish. Shu darsda runner'ni Docker'da o'zingiz ko'tarasiz, bu 4-darsdagi Jenkins agent'lari va 5-darsdagi deploy uchun ham asos.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va 1–5 vazifalar, ikkinchi kun 4–6 bo'limlar va 6–8 vazifalar, uchinchi kun 9-bo'lim va B guruhi (runner, bitta o'tirishda), to'rtinchi kun 6-bo'limning image qismi, 7, 8, 10 bo'limlar va 13–16 vazifalar, beshinchi kun "Birga bajaramiz", 17-vazifa, tozalash va README. Kalitlarni yodlashga emas, mexanizmga e'tibor bering: job'ni kim va qayerda bajaradi, `rules` qanday tartibda o'qiladi, takroriy pipeline qayerdan chiqadi, cache nima uchun kafolatsiz, Docker-in-Docker nima uchun privileged so'raydi, protected variable nimadan himoya qiladi.

Qanday o'qish kerak: har bo'limdagi YAML bo'lagini o'qing, keyin o'z loyihangizdagi job log'ini darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi versiya, ID va hash'lar farq qiladi, darsda bunday joylar `<...>` bilan belgilangan. Misollar ataylab boshqa loyihada (kichik Python kutubxonasi) berilgan, `cicd-demo` uchun faylni o'zingiz yozasiz. GitLab UI menyu nomlarini vaqti-vaqti bilan o'zgartiradi: darsdagi yo'l topilmasa, Manbalar'dagi hujjat sahifasiga qarang.

## Laboratoriya

Bu darsda kod uch joyda ishlaydi va qaysi birida turganingizni bilish muhim:

| Joy | Nima ishlaydi | Arxitektura |
|-----|---------------|-------------|
| Host (Zorin yoki macOS) | `git`, `docker`, `make`; runner konteyneri shu yerda turadi | Zorin `amd64`, Mac `arm64` |
| gitlab.com hosted runner | `tags` siz job'lar: GitLab'ning o'z mashinalarida, har job yangi VM ichidagi konteynerda | Linux `x86_64` |
| O'z runner'ingiz (host'dagi Docker) | `tags: [local]` qo'yilgan job'lar | host bilan bir xil |

- **gitlab.com akkaunt** (free tier). Hosted runner'lardan foydalanish uchun shaxsni tasdiqlash (telefon yoki karta) so'ralishi mumkin, free tier'dagi compute minutes ham cheklangan (aniq qoidalar o'zgarib turadi, https://docs.gitlab.com/ci/pipelines/compute_minutes/ ga qarang). Tasdiqlashni xohlamasangiz, avval 9-bo'lim bo'yicha o'z runner'ingizni ulang va hamma job'ni unda ishlating: o'z runner'ingizdagi job'lar compute minutes sarflamaydi.
- **Loyiha**: gitlab.com'da `cicd-demo` nomli bo'sh loyiha (README'siz) yaratiladi va 2-darsdagi lokal repo'ga ikkinchi remote sifatida ulanadi: `git remote add gitlab git@gitlab.com:<user>/cicd-demo.git`. Remote bu lokal repo biladigan uzoq repo manzili (git 3-dars). Bitta kod bazasi, ikki CI: `.github/workflows/` ni faqat GitHub, `.gitlab-ci.yml` ni faqat GitLab o'qiydi.
- **SSH kalit**: git 3-darsdagi kabi, har mashinaning o'z kaliti GitLab profilingizga qo'shiladi (User settings > SSH Keys). Tekshirish ikkala host'da bir xil: `ssh -T git@gitlab.com` javobi `Welcome to GitLab, @<user>!`.
- **Self-hosted runner**: host'dagi Docker'da `gitlab-runner` nomli konteyner, konfiguratsiyasi `gitlab-runner-config` named volume'ida (docker 3-dars). Host'ga paket o'rnatilmaydi. Yangi asbob kerak emas: `git` va `docker` `SETUP.md` bo'yicha ikkala mashinada bor.
- **Self-managed GitLab** o'rnatilmaydi: u bir necha GB RAM talab qiladi, bu dars uchun gitlab.com yetarli. Pipeline sintaksisi ikkalasida bir xil.
- **Faylni tekshirish**: GitLab UI'da Build > Pipeline editor. U sintaksisni tekshiradi, pipeline grafini chizadi va "Full configuration" yorlig'ida `include` va `extends` yoyilgandan keyingi yakuniy YAML'ni ko'rsatadi.
- **Ish papkasi**: `cicd/03-gitlab-ci/` (`README.md`, `.gitlab-ci.yml` nusxasi, token'siz `config.toml`, pipeline havolalari).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker Engine to'g'ridan-to'g'ri host kernel'ida. Runner va uning job konteynerlari `amd64`. `/var/run/docker.sock` ulangan runner host'ning o'z Docker daemon'ini boshqaradi, bu Zorin'da root huquqiga teng (9-bo'lim). O'z runner'ingizda qurilgan image `linux/amd64`. |
| macOS (uy) | Docker Desktop'ning yashirin Linux VM'i. Runner va job konteynerlari `arm64`, qurilgan image `linux/arm64` (hosted runner qurgani esa `amd64`). Socket ulangan runner Mac'ni emas, Docker Desktop VM'idagi daemon'ni boshqaradi. `amd64` uchungina chiqarilgan image'lar emulyatsiyada sekin ishlaydi yoki ishlamaydi. |

Mashinani almashtirganda nima ko'chadi, nima yo'q:

| Narsa | Qayerda yashaydi | Ikkinchi mashinada |
|-------|------------------|--------------------|
| GitLab loyihasi, CI/CD variable'lar, pipeline'lar, registry, environment'lar | gitlab.com | tayyor, hech narsa qilinmaydi |
| `.gitlab-ci.yml` | repo | `git pull` |
| `gitlab` remote | lokal klonning `.git/config` fayli | `git remote add gitlab ...` qayta bajariladi |
| SSH kalit | har mashinaning `~/.ssh` papkasi | shu mashina kaliti GitLab profiliga qo'shiladi |
| Runner konteyneri va `config.toml` | shu mashinaning Docker'i | ko'chmaydi |

Runner haqida alohida: ofisda ko'tarilgan runner uyda offline, `tags: [local]` job'lari esa mos runner topilmagani uchun pending holatda turib qoladi. Ikki yo'l bor: B guruhi va 13-vazifaning runner qismini bitta mashinada bitta o'tirishda bajarish, yoki har mashinada alohida runner ro'yxatdan o'tkazish (har biri UI'da alohida runner, alohida token) va oxirida ikkalasini ham o'chirish.

Tozalash (dars oxirida, har mashinada): runner konteyneri va volume'lari nomi bilan o'chiriladi (9-bo'lim), UI'da runner olib tashlanadi, sinov image'lari registry'dan, sinov variable'lari va deploy token loyihadan o'chiriladi. `docker system prune` ishlatilmaydi: u boshqa darslarning image va volume'larini ham olib ketadi.

---

## 1. .gitlab-ci.yml tuzilishi: stage, job, needs

### Bitta fayl, ikki xil kalit

GitLab CI konfiguratsiyasi repo ildizidagi bitta `.gitlab-ci.yml` faylida. Push kelganda GitLab shu commit'dagi faylni o'qiydi va undan **pipeline** yaratadi: pipeline bu bitta commit uchun bajariladigan job'lar to'plami (1-dars). Fayl ichidagi yuqori darajali kalitlar ikki xil: band qilingan global kalit so'zlar (`stages`, `default`, `variables`, `workflow`, `include`) va qolgan hammasi, ya'ni **job**'lar. Job bu runner bajaradigan bitta ish birligi, nomi ixtiyoriy, majburiy qismi `script`.

```yaml
stages: [check, test, package]

default:
  image: python:3.13-slim

ruff:
  stage: check
  script:
    - pip install ruff
    - ruff check .

pytest:
  stage: test
  script:
    - pip install -r requirements.txt
    - pytest

wheel:
  stage: package
  script:
    - pip install build
    - python -m build
```

Qatorma-qator: `stages` ustunlar ro'yxati va ularning tartibi. `default` har job meros oladigan sozlamalar, bu yerda `image`: job qaysi konteyner image'ida ishlashi (image bu konteynerning boshlang'ich fayl tizimi, docker 1-dars). `ruff`, `pytest`, `wheel` uchta job, har biri `stage` bilan o'z ustunini aytadi. `script` shell buyruqlari ro'yxati: ular ketma-ket bajariladi, birortasi noldan farqli exit code qaytarsa (linux 1-dars) job shu yerda to'xtaydi va failed bo'ladi.

### Mexanizm: stage tartibi

- Stage'lar `stages` dagi tartibda birin-ketin bajariladi. Bitta stage ichidagi job'lar parallel boshlanadi (runner'lar yetarli bo'lsa).
- Stage'dagi barcha job'lar muvaffaqiyatli tugagachgina keyingi stage boshlanadi. Biror job yiqilsa keyingi stage'lardagi job'lar skipped holatiga o'tadi va pipeline failed bo'ladi.
- `stages` yozilmasa standart ro'yxat ishlaydi: `.pre`, `build`, `test`, `deploy`, `.post`. Job'da `stage` yozilmasa u `test` stage'iga tushadi.
- `before_script` har job'da `script` dan oldin o'sha shell'da bajariladi. `after_script` job yiqilsa ham ishlaydi, lekin alohida shell'da: `script` da e'lon qilingan shell o'zgaruvchilari unda ko'rinmaydi.
- Nuqta bilan boshlanadigan job (`.base`) yashirin: pipeline'ga tushmaydi, shablon sifatida ishlatiladi (7-bo'lim).

Yuqoridagi fayl uchun Build > Pipelines sahifasidagi graf uch ustun: `check` ostida `ruff`, `test` ostida `pytest`, `package` ostida `wheel`. `ruff` yiqilsa `pytest` va `wheel` kulrang skipped belgisi bilan qoladi.

### needs: stage tartibini aylanib o'tish

Stage modeli sodda, lekin qo'pol: `test` stage'idagi eng sekin job tugamaguncha `package` dagi hech bir job boshlanmaydi, garchi unga faqat bitta tez job kerak bo'lsa ham. `needs` job'ning aniq qaysi job'larga bog'liqligini aytadi va GitLab uni stage'ni kutmasdan, o'sha job'lar tugashi bilan boshlaydi. Natijada pipeline ustunlar ketma-ketligidan **DAG**'ga (directed acyclic graph, yo'nalishli va halqasiz bog'liqlik grafi) aylanadi.

```yaml
wheel:
  stage: package
  needs: [pytest]
  script:
    - python -m build

changelog:
  stage: package
  needs: []
  script:
    - sh scripts/check-changelog.sh
```

`wheel` endi faqat `pytest` ni kutadi: `test` stage'ida yana sekin job bo'lsa ham, `pytest` tugagan zahoti boshlanadi. `changelog` da `needs: []` bo'sh: hech kimni kutmaydi va `package` ustunida tursa ham pipeline boshida, birinchi stage bilan birga boshlanadi. Pipeline sahifasida job'lar orasidagi bog'liqlik chiziqlarini ko'rsatadigan ko'rinish bor, unda `pytest` dan `wheel` ga chiziq chiqadi. `needs` yana bir narsani o'zgartiradi: job faqat `needs` da sanalgan job'larning artifact'larini yuklab oladi (5-bo'lim), oldingi stage'larning hammasinikini emas.

### Real ishda qachon kerak

- Begona loyihaning pipeline'i sekin bo'lsa birinchi qaraladigan joy graf: qaysi job butun stage'ni ushlab turibdi va uni `needs` bilan aylanib o'tsa bo'ladimi.
- Monorepo'da frontend va backend job'lari bir-birini kutmasligi uchun har zanjir `needs` bilan alohida bog'lanadi.
- `needs` ni haddan oshirsangiz stage'lar ma'nosini yo'qotadi va faylni o'qish qiyinlashadi. Amaliy qoida: stage'lar umumiy tartibni beradi, `needs` faqat o'lchangan sekinlik bor joyga qo'yiladi.

### Nima uchun shunday

GitLab CI 2012-yillarda stage modeli bilan boshlangan: "avval hamma tekshiruv, keyin build, keyin deploy" degan tartibni yozish va o'qish oson. `needs` keyinroq (12-versiyalarda) qo'shildi, chunki katta pipeline'larda stage to'sig'i vaqtni behuda sarflar edi. GitHub Actions teskari yo'ldan borgan (2-dars): unda stage tushunchasi yo'q, hamma job standart holatda parallel va tartib faqat `needs` bilan beriladi. GitLab'da ikkalasi bor, shuning uchun bitta faylda ikki xil tartib mexanizmini ajrata bilish kerak. Bitta fayl tanlovi ham ataylab: butun pipeline bir joydan o'qiladi, katta loyihalarda esa fayl `include` bilan bo'linadi.

## 2. Job qanday bajariladi: runner, executor, job log

### Uchta ishtirokchi

**GitLab serveri** (gitlab.com) pipeline'ni yaratadi, job'lar navbatini saqlaydi va log'ni ko'rsatadi, lekin job'ni o'zi bajarmaydi. **GitLab Runner** alohida dastur (Go'da yozilgan bitta binary): u ma'lum oraliqda serverga HTTPS so'rov yuborib "menga mos job bormi?" deb so'raydi (polling). Ulanishni har doim runner ochadi, server runner'ga hech qachon ulanmaydi. **Executor** runner ichidagi sozlama bo'lib, olingan job qayerda va qanday bajarilishini belgilaydi: `docker` executor har job uchun yangi konteyner yaratadi, `shell` executor buyruqlarni runner turgan mashinaning o'zida bajaradi (boshqalari 9-bo'limda).

gitlab.com'dagi **hosted runner**'lar GitLab o'zi boshqaradigan runner'lar: Linux `x86_64`, har job uchun yangi VM va uning ichida `image` dan yaratilgan konteyner. Job'da `tags` yozilmasa u standart kichik Linux runner'iga tushadi.

### Mexanizm: job'ning hayoti

1. Push keladi, GitLab `.gitlab-ci.yml` ni o'qib pipeline va job'larni yaratadi. Job'lar pending (runner kutmoqda) holatida.
2. Mos runner (tag'lari to'g'ri keladigan, shu loyihaga ruxsati bor) job'ni oladi, holat running bo'ladi.
3. Docker executor `image` ni pull qiladi va undan konteyner yaratadi. `services` bo'lsa ular oldin ko'tariladi (6-bo'lim).
4. Yordamchi konteyner (runner helper image) repo'ni job konteyneri bilan umumiy papkaga klonlaydi, cache va oldingi job'lar artifact'larini tiklaydi. GitHub Actions'dagi `actions/checkout` qadami yo'q: klonlash har job'ning o'rnatilgan qismi.
5. Job konteynerida `before_script` va `script`, keyin `after_script` bajariladi.
6. Helper cache'ni saqlaydi, artifact'larni GitLab'ga yuklaydi. Konteynerlar o'chiriladi, exit code'ga qarab job success yoki failed bo'ladi.

Klonlashni maxsus variable'lar boshqaradi: `GIT_DEPTH` nechta oxirgi commit olinishini (shallow clone, git 1-dars; standart 20, loyiha sozlamasidan), `GIT_STRATEGY` usulni (`fetch`, `clone` yoki `none`) belgilaydi.

### Misol: job log'ini o'qish

1-bo'limdagi `pytest` job'ining log'i (Build > Jobs yoki pipeline grafida job ustiga bosiladi):

```
Running with gitlab-runner <versiya> (<revision>)
  on <runner nomi> <id>, system ID: <system-id>
Preparing the "docker" executor
Using Docker executor with image python:3.13-slim ...
Pulling docker image python:3.13-slim ...
Using docker image sha256:<hash> for python:3.13-slim with digest python@sha256:<hash> ...
Preparing environment
Running on runner-<id>-project-<N>-concurrent-0 via <hostname>...
Getting source from Git repository
Fetching changes with git depth set to 20...
Initialized empty Git repository in /builds/<user>/<loyiha>/.git/
Checking out <sha> as detached HEAD (ref is main)...
Executing "step_script" stage of the job script
$ pip install -r requirements.txt
...
$ pytest
...
Cleaning up project directory and file based variables
Job succeeded
```

Birinchi ikki qator: runner versiyasi va job qaysi runner'ga tushgani (hosted runner'da GitLab'ning nomi, o'z runner'ingizda siz bergan nom). `Preparing the "docker" executor` executor turi. `Using docker image sha256:... with digest ...` aynan qaysi image ishlatilgani: tag o'zgaruvchan, digest esa image tarkibining hash'i (docker 2-dars), "kecha o'tgan, bugun yiqildi" holatida birinchi shu qator solishtiriladi. `Running on runner-...-concurrent-0` job konteynerining hostname'i. `Fetching changes with git depth set to 20` shallow clone. `/builds/<user>/<loyiha>` repo klonlangan papka, `CI_PROJECT_DIR` variable'i shu yo'lni saqlaydi va `script` shu papkada boshlanadi. `detached HEAD`: job branch'ni emas, aniq commit'ni checkout qiladi (git 2-dars), shuning uchun job ichida `git branch --show-current` bo'sh chiqadi. `$` bilan boshlangan qatorlar `script` dagi buyruqlar, ostida ularning chiqishi. Oxirgi qator `Job succeeded` yoki `ERROR: Job failed: exit code 1`.

### Real ishda qachon kerak

- Job uzoq vaqt pending tursa muammo YAML'da emas, runner'da: mos tag'li runner yo'q, offline yoki band.
- "Lokal ishlaydi, CI'da yo'q" holatida log boshidagi image digest, git depth va runner nomi lokal muhit bilan farqni ko'rsatadi.
- Shallow clone tufayli `git describe` yoki to'liq tarix talab qiladigan asboblar xato beradi, bunday job'da `GIT_DEPTH: 0` qo'yiladi.

### Nima uchun shunday

Polling modeli tarmoq xavfsizligi uchun tanlangan: runner faqat chiquvchi HTTPS ulanish ochadi, shuning uchun u NAT yoki firewall ortida (network 6-dars), ofis noutbukida yoki ichki tarmoqda tura oladi va unga hech qanday port ochilmaydi. Muqobili (server runner'ga ulanadigan push modeli) har runner'ga ochiq manzil va kiruvchi qoida talab qilar edi. Job standart holatda konteynerda ishlashi ham ataylab: muhit `image` qatorida yozilgan, takrorlanadigan va job tugagach yo'qoladi. GitHub Actions'da standart muhit asboblar oldindan o'rnatilgan VM, konteyner ixtiyoriy (2-dars). GitLab yo'lida job ichida Docker daemon yo'q, buning narxi 6-bo'limda.

## 3. rules va workflow

### rules: job pipeline'ga qo'shiladimi

Har pipeline yaratilganda GitLab har job uchun "bu job shu pipeline'ga kiradimi va qanday holatda?" degan savolga javob beradi. Javob `rules` ro'yxatidan olinadi:

1. Qoidalar yuqoridan pastga tekshiriladi.
2. Birinchi mos kelgan qoida ishlaydi, qolganlari o'qilmaydi. Qoidada `when` yozilmagan bo'lsa job oddiy tarzda (`on_success`) qo'shiladi.
3. Hech bir qoida mos kelmasa job pipeline'ga qo'shilmaydi: grafda umuman ko'rinmaydi, xato ham chiqmaydi.
4. Job'da `rules` umuman yo'q bo'lsa u branch va tag pipeline'lariga qo'shiladi, merge request pipeline'iga esa yo'q.

```yaml
publish:
  stage: package
  script:
    - sh scripts/publish.sh
  rules:
    - if: $CI_COMMIT_TAG
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        - src/**/*
      when: manual
      allow_failure: true
```

O'qilishi: birinchi qoida `$CI_COMMIT_TAG` bo'sh emasmi, deb so'raydi. Bu variable faqat tag pipeline'ida mavjud, demak tag push qilinganda job avtomatik qo'shiladi. Ikkinchi qoida ikki shartni birga talab qiladi (`if` va `changes` orasida "va"): pipeline default branch'da bo'lsin va `src/` ostidagi fayl o'zgargan bo'lsin, shunda job `manual` holatida (ishga tushirish tugmasi bilan) qo'shiladi. `allow_failure: true` tugma bosilmaguncha pipeline'ni to'sib turmaslik uchun. Feature branch'dagi push'da ikkala qoida ham mos kelmaydi va `publish` grafda bo'lmaydi.

| Kalit | Ma'nosi |
|-------|---------|
| `if` | CI variable'lari ustidagi shart: `==`, `!=`, `=~` (regex), `&&`, `\|\|`; yolg'iz `$VAR` "mavjud va bo'sh emas" degani |
| `changes` | ko'rsatilgan yo'llardagi fayllar o'zgarganmi |
| `exists` | repo'da shunday fayl bormi |
| `when` | `on_success` (standart), `manual`, `always`, `never`, `delayed` |
| `allow_failure` | job yiqilsa (yoki manual job bosilmasa) pipeline davom etadimi |

`changes` nimaga nisbatan solishtirishi pipeline turiga bog'liq: merge request pipeline'ida target branch'ga nisbatan, branch pipeline'ida shu push'dagi o'zgarishlarga nisbatan, yangi branch'ning birinchi pipeline'ida esa solishtiradigan narsa yo'q va `changes` har doim rost chiqadi. Eski loyihalarda `rules` o'rnida `only`/`except` uchraydi: o'qiy olish kerak, yangi kodda `rules` yoziladi, bitta job'da ikkalasini aralashtirib bo'lmaydi.

### Pipeline turlari va takroriy pipeline

Pipeline nima sababdan yaratilganini `CI_PIPELINE_SOURCE` variable'i aytadi: `push`, `merge_request_event`, `schedule`, `web` (UI'dagi "New pipeline" tugmasi), `api` va boshqalar. Ikki tur ko'p chalkashtiradi:

- **Branch pipeline**: branch'ga push kelganda. `CI_COMMIT_BRANCH` to'ldirilgan.
- **Merge request pipeline**: ochiq merge request (MR, GitHub'dagi pull request'ning GitLab'dagi nomi, git 3-dars) bor branch'ga push kelganda va faylda `merge_request_event` ni qabul qiladigan kamida bitta job bo'lganda. Unda `CI_MERGE_REQUEST_IID` kabi MR variable'lari bor, `CI_COMMIT_BRANCH` esa bo'sh.

Shundan tuzoq chiqadi: job'larga MR sharti qo'shilgan zahoti ochiq MR'li branch'ga bitta push ikki pipeline yaratadi (bittasi branch, bittasi MR uchun), bir xil job'lar ikki marta ishlaydi. Yechim global `workflow: rules`: u job'lar uchun emas, butun pipeline uchun "yaratilsinmi?" degan savolga javob beradi va xuddi `rules` kabi yuqoridan pastga o'qiladi.

```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH
```

`CI_OPEN_MERGE_REQUESTS` shu branch manba bo'lgan ochiq MR'lar ro'yxati, MR bo'lmasa bo'sh. Uch qatorning har biri qaysi pipeline'ni o'tkazishi yoki to'sishini 5-vazifada o'zingiz ochasiz. Diqqat: bu ro'yxatda tag pipeline'i uchun qoida yo'q, demak tag push'da pipeline umuman yaratilmaydi. `workflow: rules` da ham "hech biri mos kelmasa yo'q" qoidasi ishlaydi.

### Real ishda qachon kerak

- "Nega bu job ishlamadi?" savolining javobi deyarli har doim `rules`: Pipeline editor'dagi "Full configuration" va pipeline'ning `CI_PIPELINE_SOURCE` qiymatiga qaraladi.
- Deploy job'larini faqat default branch yoki tag bilan cheklash, hujjat o'zgarishida og'ir testlarni o'tkazib yuborish (`changes`).
- Compute minutes hisobi: takroriy pipeline xarajatni ikki barobar qiladi.

### Nima uchun shunday

`only`/`except` ikki alohida ro'yxat edi va ularning kesishmasini (masalan "main'da, lekin faqat `src/` o'zgarganda, manual") ifodalab bo'lmas edi. `rules` bitta tartiblangan ro'yxat, firewall qoidalari kabi "birinchi mos kelgan yutadi" tamoyilida (network 6-dars): natijani oldindan aytish mumkin, lekin tartib muhim. GitHub Actions'da bu ikki joyga bo'lingan (2-dars): `on:` workflow qachon ishlashini, job'dagi `if:` esa alohida expression tilida job'ni belgilaydi. GitLab'da shartlar oddiy CI variable'lari ustida, alohida til yo'q, narxi esa takroriy pipeline kabi yashirin o'zaro ta'sirlar.

## 4. Variable'lar

### Uch manba va ustunlik tartibi

CI variable bu job'ga oddiy environment variable (linux 5-dars) bo'lib tushadigan nom va qiymat. `${{ }}` kabi alohida expression tili yo'q: `script` ichida `$NOM` deb o'qiladi. Manbalar:

- **Predefined**: GitLab har job'ga o'zi beradi (`CI_` bilan boshlanadi).
- **`.gitlab-ci.yml` dagi `variables`**: global yoki job ichida. Repo'da ochiq turadi, faqat konfiguratsiya uchun.
- **UI'dagi variable'lar** (Settings > CI/CD > Variables): loyiha, guruh yoki instance darajasida. Secret'lar shu yerda.

Bir xil nom bir necha joyda bo'lsa, ustunlik (yuqoridan pastga, kuchlisidan kuchsiziga):

| Tartib | Manba |
|--------|-------|
| 1 | pipeline'ni ishga tushirishda berilgan (UI'dagi "New pipeline" formasi, schedule, trigger, API) |
| 2 | loyiha variable'lari (UI) |
| 3 | guruh, keyin instance variable'lari (UI) |
| 4 | job ichidagi `variables` |
| 5 | global `variables` |
| 6 | predefined variable'lar |

Demak UI'dagi qiymat YAML'dagini bosib o'tadi: faylda `LOG_LEVEL: info` tursa-yu, loyiha variable'i `LOG_LEVEL=debug` bo'lsa, job `debug` ni ko'radi.

| Predefined variable | Qiymati |
|---------------------|---------|
| `CI_COMMIT_SHA`, `CI_COMMIT_SHORT_SHA` | commit hash, to'liq va qisqa |
| `CI_COMMIT_BRANCH`, `CI_DEFAULT_BRANCH` | joriy branch (MR va tag pipeline'ida bo'sh) va default branch |
| `CI_COMMIT_REF_SLUG` | branch yoki tag nomi, URL va image tag uchun tozalangan |
| `CI_PIPELINE_SOURCE` | pipeline nima sababdan yaratilgan (3-bo'lim) |
| `CI_PROJECT_DIR` | repo klonlangan papka |
| `CI_REGISTRY`, `CI_REGISTRY_IMAGE` | registry manzili va loyihaning image yo'li (10-bo'lim) |
| `CI_JOB_TOKEN` | faqat shu job davomida amal qiladigan token |

### Protected, masked, file

UI'da variable yaratganda uchta muhim xususiyat bor:

- **Protected**: variable faqat protected branch va protected tag'lardagi pipeline'ga beriladi (8-bo'lim). Boshqa branch'dagi job'da u umuman yo'q, bo'sh satr.
- **Masked**: qiymat job log'ida `[MASKED]` bilan almashtiriladi. Qiymat formatiga talablar bor (bir qator, bo'shliqsiz, kamida 8 belgi; aniq ro'yxat hujjatda). "Masked and hidden" varianti saqlangandan keyin UI'da ham qayta ko'rsatilmaydi.
- **File** turi: qiymat vaqtinchalik faylga yoziladi, variable esa shu fayl yo'lini saqlaydi. SSH kalit, kubeconfig, sertifikat uchun.
- **Environment scope**: variable faqat ko'rsatilgan environment'ga deploy qiladigan job'ga beriladi.

Misol: loyihada masked `API_KEY` bor, job uni xato bilan chop etadi:

```
$ echo "key is $API_KEY"
key is [MASKED]
```

Masking faqat log matnidagi aynan shu satrni qidiradi. Qiymat o'zgartirilsa (kodlansa, bo'laklansa, faylga yozilib artifact qilinsa) masking uni tanimaydi. Shuning uchun masked himoya emas, tasodifiy oqishdan sug'urta.

**Tuzoq: `.gitlab-ci.yml` dagi `variables` secret emas.** U repo tarixida abadiy qoladi. Secret faqat UI'da, shell history'ga ham yozilmaydi.

### Real ishda qachon kerak

- Production token'i har doim protected va masked: aks holda istalgan branch'ga push qila oladigan odam `.gitlab-ci.yml` ni o'zgartirib uni o'qiydi.
- Bir xil pipeline'ni boshqa qiymat bilan bir marta ishga tushirish: "New pipeline" formasida variable beriladi, fayl o'zgarmaydi.

### Nima uchun shunday

Variable'lar oddiy env bo'lgani uchun har qanday til va asbob ularni qo'shimcha kutubxonasiz o'qiydi, Node'dagi `process.env` kabi. Ustunlik tartibi "operator dasturchidan kuchli" tamoyilida: repo'dagi standart qiymatni UI'dan faylga tegmasdan bosib o'tish mumkin. Protected tushunchasi GitLab'ning asosiy xavfsizlik chegarasi: ishonch branch'ga bog'lanadi. GitHub'da shu vazifani environment secret'lari va fork cheklovlari bajaradi (2-dars).

## 5. Cache va artifacts

### Ikki xil saqlash

Ikkalasi ham job tugagach fayllarni saqlaydi, lekin maqsad boshqa (1-dars): **cache** qayta yuklab olsa bo'ladigan narsani tezlatish uchun (paket menejeri keshi), **artifact** job'ning natijasi (build, hisobot), keyingi job'lar va odamlar uchun.

| | cache | artifacts |
|-|-------|-----------|
| Qayerda saqlanadi | runner tomonida: lokal disk yoki sozlangan obyekt ombori | GitLab serverida |
| Kafolat | yo'q (best-effort): boshqa runner'da bo'lmasligi mumkin | bor |
| Kimga beriladi | bir xil `key` li job'larga, pipeline'lar orasida | shu pipeline'ning keyingi stage job'lariga (yoki `needs`/`dependencies` bo'yicha), UI'dan yuklab olinadi |
| Muddat | runner siyosati | `expire_in` |

Mexanizm: job boshida helper cache arxivini `key` bo'yicha qidiradi va topilsa loyiha papkasiga yoyadi, oxirida `paths` dagi papkalarni arxivlab qayta saqlaydi. Artifact'lar job oxirida GitLab'ga HTTP orqali yuklanadi va keyingi job boshida yuklab olinadi.

```yaml
pytest:
  variables:
    PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
  cache:
    key:
      files: [requirements.txt]
    paths: [.cache/pip]
  script:
    - pip install -r requirements.txt
    - pytest --junitxml=report.xml
  artifacts:
    when: always
    reports:
      junit: report.xml
    expire_in: 1 week
```

Qatorma-qator: cache `paths` faqat loyiha papkasi ichida bo'la oladi, shuning uchun pip keshi `PIP_CACHE_DIR` bilan ichkariga ko'chirilgan. `key: files` kalitni `requirements.txt` tarkibining hash'idan hosil qiladi: fayl o'zgarsa yangi kalit, eski cache ishlatilmaydi. `artifacts: when: always` job yiqilsa ham hisobotni yuklaydi (yiqilgan testning hisoboti eng kerakli). `reports: junit` faylni test hisoboti sifatida belgilaydi: natija MR sahifasida va pipeline'ning Tests yorlig'ida ko'rinadi. Log'da (kalit va raqamlar sizda boshqa):

```
Checking cache for <key>...
Successfully extracted cache
...
Creating cache <key>...
.cache/pip: found <N> matching artifact files and directories
Created cache
Uploading artifacts...
report.xml: found 1 matching artifact files and directories
```

Birinchi pipeline'da `Successfully extracted cache` o'rnida cache topilmagani haqida qator chiqadi va job baribir davom etadi. `cache: policy` qiymatlari: `pull-push` (standart), `pull` (faqat o'qiydi), `push`. Keraksiz artifact'larni olmaslik uchun `dependencies: []`.

### Real ishda qachon kerak

- Job cache'siz ham to'g'ri ishlashi shart: cache faqat tezlik. Build natijasini keyingi job'ga cache orqali uzatish xato, bu artifact ishi.
- Bir nechta runner bo'lsa har birining lokal cache'i alohida: job har safar boshqa runner'ga tushsa cache deyarli ishlamaydi. Yechim umumiy (distributed) cache, ya'ni runner'lar S3 kabi obyekt omboriga yozadi.

### Nima uchun shunday

Cache runner tomonida turishi tezlik uchun: lokal diskdan yoyish tarmoqdan yuklashdan tez va GitLab serverini yuklamaydi. Narxi kafolatsizlik. Artifact'lar serverda, chunki ularni boshqa runner'dagi job, MR sahifasi va odam ko'rishi kerak. GitHub Actions'da ikkalasi ham GitHub xizmatida saqlanadi va alohida action'lar bilan chaqiriladi (2-dars), GitLab'da ular job kalitlari.

## 6. Services va Docker image qurish

### services: job yonidagi konteyner

`services` job bilan birga qo'shimcha konteyner ko'taradi (ma'lumotlar bazasi, kesh serveri), job unga tarmoq orqali ulanadi. Mexanizm: runner avval service konteynerini, keyin job konteynerini yaratadi va ularni shunday bog'laydiki, service job ichida hostname bo'yicha topiladi. Hostname image nomidan hosil bo'ladi (`nginx:alpine` uchun `nginx`) yoki `alias` bilan aniq beriladi. Bu Compose'dagi servis nomi bo'yicha DNS bilan bir xil g'oya (docker 3-dars).

```yaml
smoke:
  image: alpine:3.21
  services:
    - name: nginx:alpine
      alias: web
  script:
    - wget -qO- http://web/ | grep -i "welcome to nginx"
```

`web` nomi faqat shu job ichida mavjud. `localhost` ishlamaydi: service boshqa konteyner, o'z tarmoq namespace'ida (docker 3-dars). Job'ning `variables` qiymatlari service konteyneriga ham uzatiladi, bazalar parolini shu orqali oladi. Runner service porti ochilishini cheklangan vaqt kutadi, lekin port ochiq degani so'rovga tayyor degani emas: test o'zi qayta urinish bilan ulanishi kerak.

### Docker image qurish: uch yo'l

Job konteyner ichida ishlaydi va unda Docker daemon yo'q (daemon bu image quradigan va konteyner yuritadigan fon dasturi, docker 1-dars). `docker build` uchun daemon kerak, uni olishning uch yo'li bor:

| Yo'l | Qanday ishlaydi | Narxi |
|------|-----------------|-------|
| Docker-in-Docker (dind) | `docker:dind` service bo'lib ko'tariladi, ichida alohida daemon; job undagi daemon bilan tarmoq orqali gaplashadi | **privileged** konteyner talab qiladi; har job'da layer cache bo'sh |
| Socket binding | host'ning `/var/run/docker.sock` fayli job konteyneriga ulanadi, job host daemon'ini ishlatadi | tez va cache bor, lekin job host Docker'ini to'liq boshqaradi |
| Daemon'siz builder | BuildKit rootless, Buildah kabi asboblar daemon va privileged'siz quradi | sozlash murakkabroq |

```yaml
docker-info:
  image: docker:27
  services:
    - docker:27-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker info
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
```

`image: docker:27` da faqat `docker` CLI bor. `docker:27-dind` service'i `docker` hostname'i bilan daemon ko'taradi. `DOCKER_TLS_CERTDIR` daemon va CLI orasidagi TLS sertifikatlari yoziladigan umumiy papka. `docker info` chiqishidagi `Server:` qismi host'ni emas, dind ichidagi bo'sh daemon'ni ko'rsatadi. Login paroli `--password-stdin` bilan beriladi, argument sifatida emas (jarayonlar ro'yxatida ko'rinmasin). Tag'lar misol, o'zingiz mavjud versiyani tanlang.

Privileged konteynerga kernel imkoniyatlarining (capabilities, docker modulida) deyarli hammasi beriladi: u qurilmalarga yetadi, fayl tizimlarini mount qiladi, ya'ni host'dan amalda izolyatsiyalanmagan. dind'ga bu ichki konteynerlar uchun namespace va cgroup yaratish uchun kerak. gitlab.com hosted runner'larida privileged yoqilgan (har job alohida VM), o'z runner'ingizda `config.toml` da `privileged = true` qilinadi, TLS bilan ishlash uchun hujjat sertifikat volume'ini ham talab qiladi (Manbalar, "using_docker_build"). dind'da cache yo'qligini `docker build --cache-from` bilan registry'dagi oldingi image yumshatadi.

### Real ishda qachon kerak

- Integration testlar: haqiqiy Postgres yoki Redis bilan, mock'siz.
- Runner'ga kimning kodi tushishi tanlovni belgilaydi: faqat o'z jamoangiz bo'lsa dind yoki socket, begona MR'lar bo'lsa daemon'siz builder yoki har job'ga alohida VM.

### Nima uchun shunday

Konteyner ichida konteyner qurish muammosi GitLab'ning "job konteynerda" tanlovidan kelib chiqadi. GitHub hosted runner'ida job VM'da va Docker daemon tayyor turadi, shuning uchun 2-darsda bu savol tug'ilmagan. dind privileged so'rashi Docker'ning tabiati: daemon kernel bilan to'g'ridan-to'g'ri ishlaydi. Rootless builder'lar aynan shu xavfni yopish uchun paydo bo'lgan.

## 7. include, extends va shablonlar

Fayl o'sgan sari takror ko'payadi. Qayta ishlatish vositalari:

| Vosita | Nima qiladi |
|--------|-------------|
| `extends: .base` | yashirin job'dan kalitlarni meros oladi (hash'lar chuqur birlashadi, ro'yxatlar almashtiriladi) |
| `!reference [.base, script]` | boshqa job'ning bitta kalitini shu joyga qo'yadi |
| YAML anchor (`&nom`, `*nom`) | YAML'ning o'z nusxalash vositasi, faqat bitta fayl ichida |
| `include: local` | shu repo'dagi boshqa YAML fayl |
| `include: project` | boshqa loyihadagi fayl, `ref` bilan versiyalanadi |
| `include: template` | GitLab bilan keladigan tayyor shablonlar |
| `include: component` | CI/CD Catalog'dagi versiyalangan komponent, `inputs` bilan |
| `include: remote` | ixtiyoriy URL |

```yaml
.python:
  image: python:3.13-slim
  before_script:
    - pip install -r requirements.txt

.notify:
  after_script:
    - echo "job $CI_JOB_NAME finished"

pytest:
  extends: .python
  script:
    - pytest
  after_script:
    - !reference [.notify, after_script]
```

Mexanizm: GitLab avval barcha `include` fayllarini bitta hujjatga qo'shadi, keyin `extends` ni yoyadi. `pytest` ning yakuniy ko'rinishida `image` va `before_script` `.python` dan, `script` o'zidan, `after_script` esa `.notify` dan ko'chirilgan. Job'ning o'z kaliti shablondagini bosib o'tadi: `pytest` da `before_script` yozilsa `.python` dagisi to'liq almashadi, qo'shilmaydi. Natijani taxmin qilmasdan Pipeline editor'ning "Full configuration" yorlig'ida ko'rasiz.

Shu oilaga yaqin ikki kalit: `interruptible: true` (branch'ga yangi pipeline kelganda eski pipeline job'i bekor qilinishi mumkin, GitHub'dagi `cancel-in-progress` ga o'xshash) va `resource_group` (8-bo'lim).

**Tuzoq: `include: remote` va versiyasiz `include: project`.** Begona, o'zgaruvchan kod sizning secret'laringiz bilan ishlaydi (2-darsdagi tag bilan pin qilingan action muammosi). `ref` ni tag yoki commit SHA bilan qotiring.

### Real ishda qachon kerak

Platforma jamoasi umumiy pipeline'ni bitta loyihada saqlaydi, yuzlab loyiha uni `include: project` yoki `component` bilan ulaydi: xavfsizlik skaneri bir joyda yangilanadi. Kichik loyihada `extends` va `include: local` yetadi.

### Nima uchun shunday

YAML anchor'lari fayldan tashqariga chiqa olmaydi va birlashtirish qoidalari qo'pol, shuning uchun GitLab o'z vositalarini qo'shgan. GitHub'da bu vazifa action va reusable workflow'da (2-dars): ular alohida birlik sifatida chaqiriladi, GitLab'da esa matn darajasida birlashtiriladi. Birlashtirish moslashuvchan, lekin yakuniy faylni ko'rmasdan xulosa qilish xavfli.

## 8. Environments, manual job va protected branch

**Environment** bu GitLab'dagi deploy nishonining nomi (`staging`, `production`). Job'da `environment` yozilsa GitLab uni deployment sifatida qayd etadi: Operate > Environments sahifasida har muhitda qaysi commit turgani va tarixi ko'rinadi.

```yaml
deploy-demo:
  stage: deploy
  script:
    - sh scripts/deploy.sh demo
  environment:
    name: demo
    url: https://demo.example.com
  resource_group: demo
  rules:
    - if: $CI_COMMIT_TAG
      when: manual
```

`environment: name` deployment yozuvini yaratadi, `url` sahifada havola bo'lib chiqadi. `resource_group` shu nomdagi job'lardan bir vaqtda faqat bittasi ishlashini ta'minlaydi: ikki pipeline bir paytda deploy qilmaydi. `when: manual` job'ni grafda ishga tushirish tugmasi bilan ko'rsatadi, kimdir bosmaguncha bajarilmaydi. Environments sahifasidan oldingi deployment'ni qayta ishga tushirish (rollback) mumkin.

**Protected branch** bu kim push va merge qila olishi cheklangan branch (Settings > Repository > Protected branches), default branch standart holatda protected. Protected variable'lar va protected deb belgilangan runner'lar faqat shunday branch va tag'lardagi pipeline'ga xizmat qiladi. Zanjir: secret'ga yetish uchun kod protected branch'da bo'lishi kerak, u yerga esa faqat ruxsatli odam merge qiladi.

- **Protected environments** (kim deploy qila olishi) va deployment approval pulli tarifda. Free tarifda o'rinbosar: `when: manual`, protected branch va protected variable.
- Dinamik environment: `name: review/$CI_COMMIT_REF_SLUG` har branch uchun alohida muhit (review app), `on_stop` va `auto_stop_in` bilan tozalanadi.

### Real ishda qachon kerak

"Production'da hozir qaysi commit?" savoliga Environments sahifasi javob beradi. Manual job continuous delivery'ning tugmasi (1-dars): hamma narsa tayyor, oxirgi qarorni odam beradi.

### Nima uchun shunday

GitLab deploy'ni oddiy job'dan ajratadi, chunki deploy'ning tarixi, navbati va ruxsati bo'lishi kerak. GitHub'da approval environment'ning "required reviewers" sozlamasida (2-dars), GitLab free tarifda esa ishonch branch himoyasiga tayanadi: kim `main` ga merge qila olsa, o'sha deploy qila oladi.

## 9. O'z runner'ingiz: executor, Docker'da ko'tarish, ro'yxatdan o'tkazish

### Runner darajalari va executor turlari

Runner uch darajada ulanadi: instance (hamma loyihaga, gitlab.com hosted runner'lari shunday), group va project (faqat bitta loyihaga). Bu darsda faqat **project runner**, faqat o'z `cicd-demo` loyihangizga: unga begona kod tushmaydi. Executor (2-bo'lim) turlari:

| Executor | Job qayerda ishlaydi | Izolyatsiya | Qachon |
|----------|----------------------|-------------|--------|
| `shell` | runner turgan mashinaning o'zida | yo'q | sodda, lekin job'lar bir-birini va host'ni ko'radi |
| `docker` | har job uchun yangi konteyner | konteyner darajasida | eng ko'p tarqalgan tanlov |
| `docker-autoscaler` | talabga qarab yaratiladigan cloud VM'lardagi konteynerlar | VM darajasida | katta hajm |
| `kubernetes` | har job uchun pod | pod darajasida | klaster bor joyda |
| `ssh`, `virtualbox`, `instance` | uzoq mashina yoki VM | turlicha | maxsus holatlar |

### Docker'da ko'tarish

Runner'ning o'zi konteynerda ishlaydi, job konteynerlarini esa host Docker daemon'idan so'raydi. Buning uchun unga daemon'ning Unix socket'i ulanadi:

```
docker volume create gitlab-runner-config
docker run -d --name gitlab-runner --restart unless-stopped \
  -v gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

Birinchi `-v` konfiguratsiyani named volume'da saqlaydi (konteyner o'chsa ham qoladi). Ikkinchi `-v` host'dagi `/var/run/docker.sock` faylini konteynerga beradi. Bu fayl Docker daemon'ning API eshigi: unga yoza olgan jarayon istalgan konteynerni istalgan mount bilan yarata oladi, masalan host'ning `/` papkasini ulab. Shuning uchun socket'ga ega bo'lish Zorin'da root bo'lishga teng. macOS'da socket Docker Desktop VM'idagi daemon'ga olib boradi: xavf o'sha VM va unga ulangan papkalar bilan chegaralanadi. Job konteynerlari runner konteynerining ichida emas, uning yonida, host daemon'ida paydo bo'ladi. Rasmiy hujjat `latest` tag'ini ishlatadi; real ishda GitLab versiyasiga mos aniq tag qotiriladi (docker 2-dars).

### Ro'yxatdan o'tkazish

Ikki qadam. Birinchisi UI'da: loyiha > Settings > CI/CD > Runners > "New project runner" (yoki "Create project runner"). U yerda tag'lar va untagged job'larni olish-olmasligi belgilanadi, natijada `glrt-` bilan boshlanadigan **runner authentication token** bir marta ko'rsatiladi. Eski qo'llanmalardagi registration token usuli eskirgan, ishlatilmaydi. Ikkinchi qadam host'da, interaktiv rejimda (token shell history'ga tushmasin):

```
docker exec -it gitlab-runner gitlab-runner register
```

Buyruq GitLab URL'ini (`https://gitlab.com`), token'ni, runner nomini, executor'ni (`docker`) va standart image'ni (`alpine:latest`) so'raydi. Tekshirish:

```
$ docker exec gitlab-runner gitlab-runner list
Listing configured runners          ConfigFile=/etc/gitlab-runner/config.toml
<nom>          Executor=docker Token=<...> URL=https://gitlab.com
```

Token bu yerda ham ko'rinadi: README'ga ko'chirganda yashiring. `gitlab-runner verify` runner GitLab'ga ulana olishini tekshiradi. Sozlamalar `/etc/gitlab-runner/config.toml` da:

```toml
concurrent = 1

[[runners]]
  name = "<nom>"
  url = "https://gitlab.com"
  token = "glrt-<...>"
  executor = "docker"
  [runners.docker]
    image = "alpine:latest"
    privileged = false
    volumes = ["/cache"]
```

`concurrent` butun runner jarayoni bir vaqtda nechta job bajarishini cheklaydi. Har `[[runners]]` bloki bitta ro'yxatdan o'tgan runner. `[runners.docker]` ichida `image` (job'da `image` yozilmasa ishlatiladi), `privileged` (6-bo'lim), `volumes` (job konteyneriga ulanadigan yo'llar). Faylni tahrirlash ikkala host'da bir xil: `docker cp gitlab-runner:/etc/gitlab-runner/config.toml .` bilan olib, tahrirlab, teskari `docker cp` bilan qaytariladi (host'dagi nusxadan token'ni o'chiring).

Job'ni shu runner'ga yo'naltirish: job'da `tags: [local]`. Job faqat sanalgan barcha tag'larga ega runner'ga tushadi.

### Tozalash

```
docker exec gitlab-runner gitlab-runner unregister --all-runners
docker rm -f gitlab-runner
docker volume rm gitlab-runner-config
docker volume ls --filter name=runner-
```

Oxirgi buyruq Docker executor job'lar uchun yaratgan cache volume'larini ko'rsatadi, ularni `docker volume rm <nom>` bilan nomma-nom o'chiring. Keyin UI'da runner'ni ham olib tashlang.

### Real ishda qachon kerak

- Ichki tarmoqdagi resursga (xususiy registry, baza) yetishi kerak bo'lgan job'lar, maxsus hardware yoki `arm64` build, compute minutes tejash.
- Xavf 2-darsdagi self-hosted runner xavfi bilan bir xil: runner'ga tushgan kod runner turgan mashinada ishlaydi. Socket yoki privileged bilan bu host'da root degani. Begona MR'lar tushadigan runner uchun bu sozlama mumkin emas.

### Nima uchun shunday

GitLab self-managed mahsulot sifatida boshlangan: kompaniya serverni ham, runner'larni ham o'zi yuritadi. Shuning uchun runner alohida, ochiq kodli dastur va executor tanlovi birinchi darajali sozlama. GitHub hosted runner'lardan boshlagan, o'z runner'i u yerda ikkinchi yo'l (2-dars). Runner'ni konteynerda yuritish host'ga paket o'rnatmaslik uchun, narxi socket'ni ulash zarurati.

## 10. Container registry

Har GitLab loyihasida o'rnatilgan container registry (image'lar ombori, docker 2-dars) bor: `registry.gitlab.com/<namespace>/<loyiha>`. UI'da Deploy > Container registry. Job ichida login uchun alohida secret kerak emas, GitLab tayyor variable'lar beradi:

| Variable | Qiymati |
|----------|---------|
| `CI_REGISTRY` | registry manzili (`registry.gitlab.com`) |
| `CI_REGISTRY_IMAGE` | shu loyihaning image yo'li |
| `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` | faqat job davomida amal qiladigan login va parol |
| `CI_JOB_TOKEN` | job tokeni, registry va GitLab API'ning bir qismiga ruxsat beradi |

Mexanizm: job boshlanganda GitLab shu job uchun vaqtinchalik token yaratadi, job tugashi bilan u bekor bo'ladi. O'g'irlangan log'dan olingan token keyin ishlamaydi. Login qatori 6-bo'limdagi misolda. Tag sifatida `$CI_COMMIT_SHA` ishlatilsa har image aniq commit'ga bog'lanadi (1-darsdagi "build once, deploy many").

Pipeline'dan tashqarida (serverda, noutbukda) pull qilish uchun **deploy token** yaratiladi (Settings > Repository > Deploy tokens, `read_registry` scope): u shaxsga emas, loyihaga bog'langan, faqat o'qiydi va alohida bekor qilinadi. Eski tag'lar uchun cleanup policy sozlanadi.

### Real ishda qachon kerak

5-darsda server image'ni aynan deploy token bilan tortadi. Registry'dagi image'lar joy egallaydi: sinov image'larini o'chirish odat bo'lishi kerak.

### Nima uchun shunday

Registry'ni loyihaga biriktirish ruxsatlarni soddalashtiradi: kim loyihani ko'rsa, o'sha image'ni tortadi, CI esa uzoq yashaydigan parolsiz ishlaydi. Bu GHCR va `GITHUB_TOKEN` juftligining o'xshashi (2-dars). Farq: GitHub'da token huquqlari `permissions` bilan har workflow'da toraytiriladi, GitLab'da job token'ning doirasi loyiha sozlamalarida.

## 11. GitHub Actions bilan taqqos

| | GitHub Actions (2-dars) | GitLab CI |
|-|-------------------------|-----------|
| Fayl | `.github/workflows/` da bir nechta workflow | bitta `.gitlab-ci.yml` (+ `include`) |
| Tartib | faqat `needs` | `stages` + `needs` |
| Standart muhit | VM (`runs-on`) | konteyner (`image`) |
| Kodni olish | `actions/checkout` qadami | avtomatik |
| Qadam birligi | `steps` (`run` yoki `uses`) | `script` qatorlari |
| Shartlar | `on:` + `if:` expression | `rules:` + `workflow: rules` |
| Qiymatlar | `${{ }}` context'lari | oddiy env variable'lar |
| Qayta ishlatish | action, reusable workflow | `extends`, `include`, component |
| Token | `GITHUB_TOKEN` + `permissions` | `CI_JOB_TOKEN` |
| Secret himoyasi | environment secrets, fork cheklovi | protected, masked, environment scope |
| Approval | environment required reviewers | `when: manual`, protected environments (pulli) |
| Bekor qilish | `concurrency` + `cancel-in-progress` | `interruptible`, `resource_group` |
| O'z runner | mumkin, ikkinchi darajali yo'l | birinchi darajali, executor tanlovi bilan |

### Nima uchun shunday

Ikki tizim ikki xil boshlang'ich nuqtadan kelgan: GitLab CI kompaniya ichida o'z serverida yuritiladigan yagona platformaning qismi (bitta fayl, o'z runner, konteyner), GitHub Actions esa ochiq kodli loyihalar bozori atrofida qurilgan (tayyor action'lar, hosted VM, voqealarga asoslangan workflow'lar). Makefile'dagi mantiq (1-dars) ikkalasida o'zgarmaydi, o'zgaradigani faqat uni chaqiradigan YAML qobig'i.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Pipeline | bitta commit uchun yaratilgan job'lar to'plami |
| Stage | pipeline'dagi ustun: stage'lar ketma-ket, ichidagi job'lar parallel |
| Job | runner bajaradigan bitta ish birligi, majburiy qismi `script` |
| DAG | `needs` bilan hosil bo'ladigan yo'nalishli, halqasiz bog'liqlik grafi |
| GitLab Runner | serverdan job so'rab olib bajaradigan alohida dastur |
| Hosted runner | gitlab.com o'zi boshqaradigan runner |
| Executor | runner job'ni qayerda bajarishini belgilaydigan sozlama (`docker`, `shell`) |
| Helper image | repo klonlash, cache va artifact bilan ishlaydigan yordamchi konteyner image'i |
| `rules` | job pipeline'ga qo'shilishini hal qiladigan tartiblangan shartlar ro'yxati |
| `workflow: rules` | pipeline'ning o'zi yaratilishini hal qiladigan global qoidalar |
| Branch pipeline / MR pipeline | push sababli va ochiq merge request sababli yaratiladigan ikki pipeline turi |
| Predefined variable | GitLab har job'ga avtomatik beradigan `CI_` variable |
| Protected variable | faqat protected branch va tag pipeline'lariga beriladigan variable |
| Masked variable | qiymati job log'ida `[MASKED]` bilan yashiriladigan variable |
| Cache | qayta hosil qilsa bo'ladigan fayllarni tezlik uchun saqlash, kafolatsiz |
| Artifact | job natijasi, GitLab serverida saqlanadi va keyingi job'larga beriladi |
| Service | job yonida ko'tariladigan qo'shimcha konteyner, hostname bo'yicha topiladi |
| Docker-in-Docker (dind) | konteyner ichida alohida Docker daemon yuritish, privileged talab qiladi |
| Privileged | konteynerga deyarli barcha kernel imkoniyatlarini beradigan rejim |
| Socket binding | host'ning `/var/run/docker.sock` faylini konteynerga ulash |
| Yashirin job | nuqta bilan boshlanadigan, faqat shablon bo'lgan job |
| Environment | deploy nishonining GitLab'dagi nomi va deployment tarixi |
| Manual job | tugma bosilgandagina ishlaydigan job (`when: manual`) |
| `resource_group` | bir vaqtda faqat bitta job ishlashini ta'minlaydigan guruh |
| Protected branch | push va merge huquqi cheklangan branch |
| Runner authentication token | runner'ni GitLab'ga bog'laydigan `glrt-` token |
| Tag (runner) | job'ni aniq runner'ga yo'naltiradigan belgi (git tag emas) |
| `config.toml` | runner konfiguratsiya fayli |
| Deploy token | loyihaga bog'langan, cheklangan huquqli token |

## Tuzoqlar

- Production secret'ini protected qilmaslik: istalgan branch'dan `.gitlab-ci.yml` ni o'zgartirib o'qib olish mumkin.
- Masked'ni himoya deb o'ylash: u faqat log'dagi aynan o'sha satrni yashiradi.
- `workflow: rules` siz MR pipeline qo'shish: har push'ga ikki pipeline, ikki barobar daqiqa.
- `rules` da hech bir qoida mos kelmasa job jimgina yo'qoladi, pipeline esa "yashil". Yashil pipeline'da kerakli job borligini ham tekshiring.
- `changes` yangi branch'ning birinchi pipeline'ida har doim rost.
- Cache'ga artifact kabi tayanish: boshqa runner'da cache yo'q, job yiqiladi.
- `artifacts: paths` ga butun loyiha papkasini yoki `.env` ni qo'shish: artifact'ni loyihani ko'ra olgan har kim yuklab oladi.
- Service'ga `localhost` orqali ulanish: service boshqa konteyner, `alias` ishlatiladi.
- `shell` executor'li umumiy runner: job'lar bir-birining fayllarini va host'ni ko'radi.
- Privileged dind yoki socket ulangan runner'ga ishonchsiz kod tushirish.
- Runner token'ini README'ga, `config.toml` nusxasiga yoki shell history'ga tushirish.
- Runner o'chiq mashinada qolgan: `tags: [local]` job'lari pending'da turadi va pipeline tugamaydi.
- Mac'dagi runner'da qurilgan image `arm64`: uni `amd64` serverda ishlatib bo'lmaydi (`Exec format error`, linux 1-dars).
- `include` ni versiyasiz ulash; deploy job'ida `resource_group` yo'qligi.
- Tozalashda `docker system prune`: boshqa darslar holatini ham o'chiradi.

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
- https://docs.gitlab.com/ci/variables/ – variable'lar, ustunlik tartibi, masked va protected
- https://docs.gitlab.com/ci/yaml/includes/ – `include` misollari
- https://docs.gitlab.com/ci/runners/hosted_runners/ – gitlab.com hosted runner'lari
- https://docs.gitlab.com/ci/pipelines/compute_minutes/ – compute minutes
- https://docs.gitlab.com/runner/configuration/advanced-configuration/ – `config.toml` kalitlari
- https://docs.gitlab.com/user/project/deploy_tokens/ – deploy token

## Birga bajaramiz

Vazifalardan boshqa, alohida loyihada bitta kichik pipeline'ni noldan quramiz: `ci-playground` nomli loyiha bitta HTML sahifa "quradi" va uni tekshiradi. Node ham, Docker build ham yo'q, faqat `alpine` image'i va shell. Maqsad: job log'ini o'qish, artifact'ning stage'lar orasida o'tishi, variable ustunligi va tag pipeline'ini o'z ko'zingiz bilan ko'rish. Job'lar hosted runner'da ishlaydi (tasdiqlashsiz bo'lsangiz, bu yurishni 9-bo'limdan keyin o'z runner'ingizda bajaring).

1. gitlab.com'da `ci-playground` nomli bo'sh, private loyiha yarating (README'siz) va host'da yangi repo oching:

```
$ mkdir ci-playground && cd ci-playground
$ git init -b main
$ git remote add origin git@gitlab.com:<user>/ci-playground.git
```

2. Eng kichik `.gitlab-ci.yml`: bitta job, `stages` yozilmagan.

```yaml
hello:
  image: alpine:3.21
  script:
    - echo "branch=$CI_COMMIT_BRANCH source=$CI_PIPELINE_SOURCE"
    - pwd
```

```
$ git add .gitlab-ci.yml && git commit -m "ci: first job"
$ git push -u origin main
```

Build > Pipelines'da bitta pipeline, grafda bitta `test` ustuni (job'da `stage` yo'q, standart `test`). Job log'ining oxiri:

```
$ echo "branch=$CI_COMMIT_BRANCH source=$CI_PIPELINE_SOURCE"
branch=main source=push
$ pwd
/builds/<user>/ci-playground
Job succeeded
```

Log boshidagi runner, image digest va `Fetching changes with git depth set to ...` qatorlarini 2-bo'limdagi izoh bilan solishtiring.

3. Ikki stage va artifact. Faylni almashtiring:

```yaml
stages: [render, verify]

variables:
  SITE_TITLE: "Notes"

default:
  image: alpine:3.21

page:
  stage: render
  script:
    - mkdir public
    - echo "<h1>$SITE_TITLE</h1>" > public/index.html
  artifacts:
    paths: [public/]
    expire_in: 1 day

title:
  stage: verify
  script:
    - cat public/index.html
    - grep -q "<h1>" public/index.html
```

Push qiling. Grafda ikki ustun: `render` ostida `page`, `verify` ostida `title`. `page` log'ining oxirida `Uploading artifacts...` va `public/: found <N> matching artifact files and directories`. `title` log'ida `script` dan oldin `Downloading artifacts for page (<job-id>)...` qatori bor va `cat` `<h1>Notes</h1>` ni chiqaradi. Ikki job ikki alohida konteynerda ishladi: `public/` ikkinchisiga faqat artifact tufayli yetib bordi. Tajriba: `artifacts` blokini olib tashlab push qiling, `title` `No such file or directory` bilan yiqiladi. Keyin blokni qaytaring.

4. Variable ustunligi. Settings > CI/CD > Variables'da `SITE_TITLE` = `From UI` loyiha variable'ini yarating (masked va protected belgilanmagan). Faylga tegmasdan Build > Pipelines > "New pipeline" tugmasi bilan `main` uchun yangi pipeline yarating (formada variable kiritmang). `title` endi `<h1>From UI</h1>` chiqaradi: loyiha variable'i YAML'dagi global qiymatdan kuchli (4-bo'lim jadvalida 2 va 5-qatorlar).

5. Eng kuchli manba. Build > Pipelines > "New pipeline" formasida `main` ni tanlab, variable sifatida `SITE_TITLE` = `Manual run` kiriting. Natija `<h1>Manual run</h1>`, 2-qadamdagi `hello` usulida tekshirsangiz `CI_PIPELINE_SOURCE` endi `web`. Keyin UI'dagi `SITE_TITLE` variable'ini o'chiring.

6. Tag'da ishlaydigan job. Faylga qo'shing:

```yaml
release-note:
  stage: verify
  script:
    - echo "release $CI_COMMIT_TAG from $CI_COMMIT_SHORT_SHA"
  rules:
    - if: $CI_COMMIT_TAG
```

Commit va push: `main` dagi pipeline'da `release-note` yo'q (qoida mos kelmadi, job jimgina qo'shilmadi). Endi tag:

```
$ git tag v0.1.0
$ git push origin v0.1.0
```

Yangi pipeline paydo bo'ladi, unda uchala job bor: `page` va `title` da `rules` yo'q, ular branch va tag pipeline'larining ikkalasiga kiradi, `release-note` esa faqat shu yerda. Uning log'ida `release v0.1.0 from <sha>`. Bu pipeline'da `CI_COMMIT_BRANCH` bo'sh.

7. Tozalash: loyihani o'chiring (Settings > General > Advanced > Delete project) va lokal `ci-playground` papkasini olib tashlang. Bu loyiha vazifalarga kerak emas.

Shu 7 qadamda ko'rganingiz: job konteynerda, avtomatik klonlangan repo ichida ishlaydi va log'i bosqichma-bosqich o'qiladi (2-bo'lim); stage'lar ketma-ket, `stage` siz job `test` da (1-bo'lim); fayl job'dan job'ga faqat artifact orqali o'tadi (5-bo'lim); bir xil nomli variable'da UI YAML'dan, qo'lda berilgani esa hammasidan kuchli (4-bo'lim); `rules` mos kelmasa job yo'qoladi, `rules` siz job tag pipeline'ida ham ishlaydi (3-bo'lim).

---

## Vazifalar

Pipeline `cicd-demo` reposida (`gitlab` remote) yoziladi. Javoblar `cicd/03-gitlab-ci/` da (yaratish: `make new m=cicd n=03 name=gitlab-ci`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, pipeline yoki job havolasi, log'ning muhim qismi va o'z so'zingiz bilan izoh. `.gitlab-ci.yml` ning yakuniy nusxasini va `config.toml` ni (token'siz) shu papkaga saqlang. Pipeline natijalari qaysi mashinadan push qilganingizga bog'liq emas; host'da bajariladigan qismlar (remote, runner, `docker` buyruqlari) qaysi mashinada bajarilganini README'da yozing. B guruhi va 13-vazifaning runner qismi bitta mashinada, bitta o'tirishda bajarilsin (Laboratoriya).

### A. Pipeline asoslari

1. **Second remote.** gitlab.com'da bo'sh `cicd-demo` loyihasini yarating, `gitlab` remote qo'shing va `main` ni push qiling. `git remote -v` natijasini yozing. `.github/workflows/` GitLab'da nima qilishini (yoki qilmasligini) tekshiring. Ikkinchi mashinada remote va SSH kalit qayta sozlanadi: nima uchun ular git bilan ko'chmaydi? Yo'nalish: Laboratoriya, "Loyiha" va jadval.

2. **First pipeline.** `.gitlab-ci.yml` yozing: `lint` va `test` stage'lari, job'lar `node` image'ida `Makefile` target'larini yoki ularning ichidagi buyruqlarni chaqirsin. Diqqat: 1-darsdagi `Makefile` Node'ni `docker run` orqali ishlatadi, job esa allaqachon konteyner ichida. Bu ziddiyatni qanday hal qilganingizni yozing (Makefile'ni ikkala muhitda ishlaydigan qilish 1-darsdagi "mantiq YAML'da emas" qoidasining sinovi). Yo'nalish: 1-bo'lim, "Bitta fayl, ikki xil kalit" va 2-bo'lim, "Mexanizm: job'ning hayoti".

3. **Stages vs needs.** Uchinchi `build` stage'i qo'shing (hozircha `echo`). `lint` ga `sleep 60` qo'yib, `build` ni avval oddiy stage tartibida, keyin `needs: [unit]` bilan ishga tushiring. Pipeline grafini ikkala holatda tasvirlang: `build` qachon boshlandi? Yo'nalish: 1-bo'lim, "needs: stage tartibini aylanib o'tish".

4. **Rules.** Shunday qiling: `lint` va `test` MR'da va `main` da ishlaydi, `build` faqat `main` da, `docs/` yoki `*.md` o'zgargan commit'larda `test` ishlamaydi (`changes`). Har holat uchun pipeline'da qaysi job'lar paydo bo'lganini ko'rsating. Hech bir qoida mos kelmaganda job bilan nima bo'lishini sinab ko'ring. Yo'nalish: 3-bo'lim, "rules: job pipeline'ga qo'shiladimi".

5. **Duplicate pipelines.** MR oching va `workflow: rules` siz, job'larda MR sharti bor holatda push qiling: nechta pipeline yaratildi? 3-bo'limdagi `workflow: rules` ni qo'shing va qayta tekshiring. Har qoida qatorini o'z so'zingiz bilan izohlang. Yo'nalish: 3-bo'lim, "Pipeline turlari va takroriy pipeline".

6. **Variables.** Bitta job'da `env | grep ^CI_ | sort` chiqaring va 10 ta eng foydali predefined variable'ni tanlab izohlang. UI'da ikki variable yarating: biri masked, biri protected. Feature branch'dagi job'da protected variable qiymati nima? Maskalangan qiymatni `rev` orqali chop etib ko'ring, so'ng variable'larni o'chiring. Yo'nalish: 4-bo'lim, "Uch manba va ustunlik tartibi" va "Protected, masked, file".

7. **Cache vs artifacts.** `test` job'iga `package-lock.json` ga bog'langan npm cache va JUnit hisobotini `artifacts:reports:junit` sifatida qo'shing. Ikki ketma-ket pipeline'da cache log qatorlarini taqqoslang. Testni buzib, MR sahifasida test hisoboti qanday ko'rinishini yozing. Cache'ni UI'dan tozalab, pipeline baribir o'tishini ko'rsating. Yo'nalish: 5-bo'lim, "Ikki xil saqlash".

8. **Services.** Integration test job'i yozing: `postgres` (yoki `redis`) service'i `alias` bilan, test unga ulanib bitta so'rov bajaradi (ilovaga minimal kod qo'shish mumkin yoki `psql`/`redis-cli` image'idan foydalaning). Service hostname qayerdan kelishini va service tayyor bo'lmasdan test boshlansa nima bo'lishini izohlang. Yo'nalish: 6-bo'lim, "services: job yonidagi konteyner".

### B. Runner

9. **Runner in Docker.** 9-bo'limdagi buyruqlar bilan runner konteynerini ko'taring, UI'da project runner yaratib `local` tag'i bilan ro'yxatdan o'tkazing. `gitlab-runner list` va `config.toml` ni (token'ni yashirib) `README.md` ga qo'ying. Runner GitLab bilan qaysi yo'nalishda ulanadi va nima uchun ish mashinangizda port ochish kerak emas? Runner qaysi mashinada (Zorin yoki macOS) turganini va konteyner arxitekturasini (`docker exec gitlab-runner uname -m`) yozing. Yo'nalish: 9-bo'lim, "Docker'da ko'tarish" va "Ro'yxatdan o'tkazish"; 2-bo'lim, "Uchta ishtirokchi".

10. **Route by tags.** Bitta job'ga `tags: [local]` qo'ying va u sizning runner'ingizda ishlaganini job log'ining boshidan isbotlang. Job ishlayotganda host'da `docker ps` qiling: qanday konteynerlar paydo bo'ldi? Runner konteynerini to'xtatib pipeline ishga tushiring: job qanday holatda turadi va qancha? Yo'nalish: 9-bo'lim, "Ro'yxatdan o'tkazish"; 2-bo'lim, "Mexanizm: job'ning hayoti".

11. **Executor isolation.** Runner'da ikki job ketma-ket ishlating: birinchisi `/tmp/leak.txt` va loyiha papkasida commit qilinmagan fayl yaratadi, ikkinchisi ularni qidiradi. `docker` executor'da nima saqlanib qoldi, nima yo'q? `shell` executor'da natija qanday bo'lar edi (hujjat asosida, o'rnatmasdan)? Yo'nalish: 9-bo'lim, "Runner darajalari va executor turlari".

12. **Runner concurrency.** `config.toml` da `concurrent` ni 1 va keyin 3 qilib, uchta parallel job'li stage'ni ishga tushiring. Umumiy vaqtni taqqoslang. O'zgarishdan keyin runner'ni qayta ishga tushirish kerak bo'ldimi? Yo'nalish: 9-bo'lim, "Ro'yxatdan o'tkazish" (`config.toml`).

### C. Image va ko'chirish

13. **Build with dind.** `build-image` job'ini dind bilan yozing: image'ni `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA` ga push qilsin, faqat `main` da. Avval hosted runner'da ishga tushiring. Keyin o'z runner'ingizda (`tags: [local]`): `privileged` yoqilmagan holatda xatoni o'qing va yozing, so'ng `config.toml` ni tuzating. Privileged rejim nimaga ruxsat berishini docker modulidagi bilim bilan izohlang. Hosted runner va o'z runner'ingiz qurgan image arxitekturasi bir xilmi (macOS'da farq qiladi)? Yo'nalish: 6-bo'lim, "Docker image qurish: uch yo'l".

14. **Registry and deploy token.** Push qilingan image'ni UI'da (Deploy → Container registry) toping. `read_registry` scope'li deploy token yarating va u bilan lokal mashinada `docker login registry.gitlab.com` qilib image'ni pull qiling. Deploy token shaxsiy access token'dan nimasi bilan yaxshiroq? Oxirida `docker logout` va token'ni bekor qiling. Token'ni buyruq argumentida emas, `--password-stdin` orqali bering. Yo'nalish: 10-bo'lim.

15. **Environments.** `deploy-staging` (avtomatik) va `deploy-production` (`when: manual`, `resource_group`) job'larini `echo` bilan qo'shing, ikkalasi `environment` e'lon qilsin. Environments sahifasida deployment tarixini ko'rsating. Oldingi deployment'ni UI'dan qayta ishga tushiring (rollback tugmasi) va u aslida qaysi job'ni qaysi commit bilan ishga tushirganini yozing. Yo'nalish: 8-bo'lim.

16. **Include and extends.** Takrorlanuvchi qismlarni (`image`, cache, `before_script`) yashirin `.node` job'iga chiqarib `extends` bilan ishlating. Keyin job'larning bir qismini `ci/build.yml` ga ko'chirib `include: local` bilan ulang. Pipeline editor'dagi to'liq yoyilgan konfiguratsiyani ko'rib, birlashtirish natijasi kutganingizdek ekanini tekshiring. Yo'nalish: 7-bo'lim.

17. **Port and compare.** Yakuniy `.gitlab-ci.yml`: 2-darsdagi to'liq pipeline'ning ekvivalenti (lint, test, build va push, staging, production approval). Taqqoslash jadvali tuzing: fayl hajmi (qator), noldan pipeline vaqti, cache bilan vaqt, har tizimda nima osonroq va nima qiyinroq chiqdi, secret va token modeli. Qaysi qismlar o'zgarishsiz ko'chdi (Makefile target'lari) va qaysilari qayta yozildi? Yo'nalish: 11-bo'lim va butun dars.

### Topshirish

Tayyor bo'lgach:
1. `cicd/03-gitlab-ci/README.md` da 17 ta vazifaning har biri `## N. Title` sarlavhasi ostida; papkada `.gitlab-ci.yml` (va `ci/build.yml`) nusxasi hamda token'siz `config.toml` bor.
2. `main` dagi oxirgi pipeline yashil, Pipeline editor xato ko'rsatmaydi.
3. Bitta push'ga bitta pipeline yaratiladi (takroriy yo'q).
4. Registry'da commit SHA bilan teglangan yakuniy image bor, sinov image'lari o'chirilgan.
5. Sinov variable'lari va deploy token o'chirilgan, `docker logout registry.gitlab.com` bajarilgan, README va `config.toml` nusxasida token yo'q.
6. Runner konteyneri, `gitlab-runner-config` va `runner-` bilan boshlanadigan volume'lar nomi bilan o'chirilgan (runner ko'tarilgan har mashinada), UI'da runner olib tashlangan. `docker ps -a` va `docker volume ls` da shu darsdan narsa qolmagan.
7. `make check` toza (host'da). Menga xabar bering, loyiha havolasini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Push'dan `Job succeeded` gacha nima sodir bo'ladi: kim pipeline yaratadi, kim job'ni oladi, kod konteynerga qanday tushadi?
- Stage va `needs` qanday birga ishlaydi? `needs` nimani tezlashtiradi?
- `rules` qanday tartibda tekshiriladi va hech biri mos kelmasa nima bo'ladi?
- Takroriy pipeline qayerdan paydo bo'ladi va `workflow: rules` uni qanday yopadi?
- Protected variable nimadan himoya qiladi? Masked variable nimadan himoya qilmaydi?
- GitLab'da cache nima uchun kafolatlanmagan, artifacts esa kafolatlangan?
- `docker` va `shell` executor farqi nima? Qaysi biri job'lar orasida holat qoldiradi?
- Docker-in-Docker nima uchun privileged talab qiladi va bu nimasi bilan xavfli?
- Runner GitLab'ga qanday ulanadi: kim kimga ulanish ochadi?
- GitHub Actions va GitLab CI modelidagi uchta eng muhim farqni ayting.
- Bir xil nomli variable YAML'da ham, UI'da ham bo'lsa job qaysi birini ko'radi va nima uchun shunday tartib tanlangan?
- Service'ga nima uchun `localhost` orqali ulanib bo'lmaydi?
- `/var/run/docker.sock` ulangan runner Zorin'da va macOS'da nimaga yetadi? Nima uchun u faqat o'z loyihangizga ulangan?
- Ofisda ko'tarilgan runner uyda nima uchun ishlamaydi va `tags: [local]` job'i bilan nima bo'ladi?
