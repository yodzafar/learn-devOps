# 4-dars: Git hostinglar

Maqsad: Git hosting'ni foydalanuvchi emas, uni boshqaradigan muhandis ko'zi bilan ko'rish. To'rt asosiy platforma (GitHub, GitLab, Gitea, Bitbucket) nimasi bilan farq qilishini, ularga mashina nomidan qanday xavfsiz kirilishini (token, deploy key), hosting'ni o'zingiz qanday ko'tarishingizni va repo sozlamalaridan qaysilari ops zimmasida ekanini o'rganasiz. 3-darsdagi protected branch, review va hook tushunchalari bu yerda aniq sozlamalarga aylanadi. Keyingi CI/CD modulida pipeline'lar aynan shu platformalar ustida quriladi, GitOps'da esa repo production'ga kirish eshigi bo'ladi: repoga yozish huquqi deploy huquqiga teng.

Taxminiy vaqt: 3 kun (siz uchun). GitHub UI tanish. Diqqat: SaaS va self-hosted farqining ops narxi, `gh` bilan avtomatlashtirish, token va deploy key'da eng kam huquq, Gitea'ni ko'tarish va mirroring, himoya qoidalarining o'zaro bog'lanishi (branch protection + `CODEOWNERS` + required checks).

## Laboratoriya

Uch muhit:

- **GitHub**: shaxsiy akkaunt, `gh` CLI (o'rnatilgan; o'rnatish yo'riqnomasi: https://github.com/cli/cli#installation). Sinov repolari public bo'ladi (himoya qoidalari bepul tarifda public repoda ishlaydi), ularga haqiqiy ma'lumot tushmaydi.
- **Gitea**: ish mashinasida Docker Compose bilan, portlar faqat `127.0.0.1` ga bog'lanadi. `compose.yaml` ni o'zingiz yozasiz (5-bo'lim) va ish papkasiga saqlaysiz.
- **Scratch repolar**: `~/git-lab/04/`.

GitLab bu darsda o'rnatilmaydi (og'ir), faqat tuzilishi o'rganiladi.

Tozalash: `docker compose down -v` (konteyner va volume), `docker volume ls` bilan tekshirish, `rm -rf ~/git-lab/04`, GitHub'dagi sinov repolari, tokenlar va deploy key'lar o'chiriladi. Repo o'chirish uchun `gh` ga qo'shimcha scope kerak: `gh auth refresh -s delete_repo`.

---

## 1. Hosting nima qo'shadi

Git protokoli hamma joyda bir xil: `clone`, `fetch`, `push` istalgan hosting bilan bir xil ishlaydi va reponi platformalar orasida ko'chirish oson (5-bo'lim). Hosting Git ustiga quyidagilarni qo'shadi va aynan shular platformaga bog'lab qo'yadi:

- identifikatsiya va huquqlar: foydalanuvchi, guruh, rol, SSO;
- hamkorlik: pull/merge request, review, issue;
- siyosat: branch himoyasi, majburiy tekshiruvlar, code owners;
- avtomatlashtirish: CI/CD, webhook, API;
- qo'shimcha registrlar: container va package registry, release sahifalari.

Ko'chirishda Git tarixi to'liq o'tadi, lekin PR tarixi, issue'lar, CI konfiguratsiyasi, secret'lar va huquqlar alohida ish.

## 2. Taqqoslash

| | GitHub | GitLab | Gitea | Bitbucket |
|---|--------|--------|-------|-----------|
| Egasi | Microsoft | GitLab Inc. | ochiq loyiha (MIT), Go'da yozilgan | Atlassian |
| Hosting modeli | SaaS (github.com); korxonalar uchun self-hosted GitHub Enterprise Server | SaaS (gitlab.com) va self-managed, bir xil mahsulot | asosan self-hosted: bitta binar yoki konteyner | SaaS (Bitbucket Cloud); self-hosted Data Center |
| Kodi ochiqmi | yo'q | Community Edition ochiq, Enterprise Edition yopiq qo'shimchalar bilan | ha | yo'q |
| CI | GitHub Actions | GitLab CI/CD (`.gitlab-ci.yml`, runner'lar) | Gitea Actions (GitHub Actions'ga o'xshash sintaksis, o'z runner'i) | Bitbucket Pipelines |
| So'rov nomi | pull request | merge request | pull request | pull request |
| Narx modeli | bepul tarif + foydalanuvchi boshiga pullik tariflar; private repolar uchun CI daqiqalari kvotasi | bepul tarif + foydalanuvchi boshiga Premium/Ultimate; SaaS'da compute daqiqalari kvotasi; self-managed CE bepul | dastur bepul, xarajat: server va uni yuritish vaqti | kichik jamoalar uchun bepul tarif + foydalanuvchi boshiga tariflar; build daqiqalari kvotasi |
| Self-hosting og'irligi | faqat Enterprise litsenziyasi bilan | og'ir: ko'p komponent, kamida 8 GB RAM atrofida | yengil: yuzlab MB RAM, SQLite bilan ham ishlaydi | Data Center litsenziyasi |
| Kuchli tomoni | eng katta ekotizim, open source markazi, Actions marketplace | "hammasi bitta joyda": SCM, CI, registry, security skanerlari | soddalik, kam resurs, to'liq nazorat | Jira va Atlassian mahsulotlari bilan integratsiya |
| CLI | `gh` | `glab` | `tea` | REST API |

Aniq narxlar va kvotalar tez-tez o'zgaradi, qaror paytida rasmiy pricing sahifasidan oling.

### SaaS yoki self-hosted

| | SaaS | Self-hosted |
|---|------|-------------|
| Ekspluatatsiya | provayderda | sizda: yangilash, backup, monitoring, xavfsizlik yamoqlari |
| Ma'lumot joylashuvi | provayder hududida | o'zingiz tanlagan joyda (regulyator talabi, yopiq tarmoq) |
| Mavjudlik | provayder nosozligi sizga ham nosozlik | o'zingiz ta'minlaysiz |
| Narx | foydalanuvchi va daqiqa boshiga | server + muhandis vaqti |

Self-hosting sababi odatda uchta: ma'lumot tashqariga chiqmasligi shart, internetdan uzilgan muhit, yoki foydalanuvchi boshiga narx katta jamoada qimmatga tushishi. "Bepul" degan sabab kamdan-kam to'g'ri chiqadi: Git serveri yo'qolsa butun kompaniya ishi to'xtaydi, demak backup, tiklash sinovi va yangilash tartibi kerak.

## 3. gh CLI

`gh` GitHub API ustidagi CLI: web UI'da qilinadigan ishni skriptga aylantiradi.

```
gh auth login                      # browser or token; choose SSH or HTTPS for git
gh auth status                     # account, token scopes
gh repo create demo --public --clone
gh pr create --fill                # title/body from commits
gh pr checks && gh pr merge --squash --delete-branch
gh api repos/{owner}/{repo}/branches/main/protection
```

| Guruh | Buyruqlar |
|-------|-----------|
| repo | `gh repo create`, `clone`, `fork`, `view`, `edit`, `delete`, `gh repo deploy-key add/list/delete` |
| PR | `gh pr create`, `list`, `view`, `checkout <N>`, `diff`, `review --approve`, `checks`, `merge` |
| sozlama | `gh secret set/list`, `gh variable set/list`, `gh ruleset list/view/check` |
| reliz | `gh release create <tag> --generate-notes` |
| xom API | `gh api <endpoint>`; `{owner}` va `{repo}` joriy repodan to'ldiriladi; `--jq` bilan filtr |

Skript va CI'da `gh` interaktiv login o'rniga `GH_TOKEN` muhit o'zgaruvchisidan token oladi. `gh api` UI'da bor, lekin alohida buyrug'i yo'q har narsani (masalan branch protection yozish) qamraydi, shuning uchun repo sozlamalarini kod sifatida saqlash mumkin: JSON fayl + `gh api -X PUT ... --input file.json`. GitLab uchun shu rolni `glab`, Gitea uchun `tea` bajaradi.

## 4. Tokenlar va deploy key

Odam brauzer va SSH kalit bilan kiradi. Mashina (CI, server, skript) uchun alohida, cheklangan identifikator kerak.

| Vosita | Kimga bog'langan | Doirasi | Qachon |
|--------|------------------|---------|--------|
| Personal access token, classic (GitHub) | foydalanuvchi | keng scope'lar (`repo` barcha repolarga) | faqat fine-grained qo'llamaydigan holatlarda |
| Fine-grained PAT (GitHub) | foydalanuvchi | tanlangan repolar, har resurs uchun read yoki write, muddat | skriptlar, API |
| Project / group access token (GitLab) | loyiha yoki guruh | rol + scope'lar, muddat | CI va integratsiyalar |
| Access token (Gitea) | foydalanuvchi | scope'lar (`read:repository`, `write:repository` ...) | API, HTTPS orqali git |
| Deploy key | **bitta repo** | SSH public kalit, default read-only, ixtiyoriy write | server yoki CI bitta reponi `clone`/`pull` qilishi |
| CI ichki tokeni (`GITHUB_TOKEN`, GitLab `CI_JOB_TOKEN`) | bitta job | avtomatik beriladi, job tugashi bilan o'ladi | pipeline ichidan o'z reposiga murojaat |

Qoidalar:

- **Eng kam huquq**: bitta repo, faqat read, qisqa muddat. Production serveri kodni tortib olishi uchun write huquqi kerak emas.
- **Odam tokeni mashinaga berilmaydi.** Xodim ketganda token o'ladi va deploy to'xtaydi, yoki o'lmaydi va bu yanada yomon. Mashina uchun deploy key, loyiha tokeni yoki alohida xizmat akkaunti.
- **Token parolga teng.** Kodga, `.git/config` ga, CI loglariga tushmasligi kerak. `git clone https://<token>@host/...` tokenni URL bilan birga `.git/config` va shell tarixiga yozadi.
- Har tokenning egasi, maqsadi va muddati yozib qo'yiladi, almashtirish (rotation) tartibi oldindan ma'lum bo'ladi.

GitHub'da bitta SSH kalit faqat bitta repoga deploy key bo'la oladi (ikkinchisida "Key is already in use"). Bir server bir nechta repo tortsa: har repoga alohida kalit va `~/.ssh/config` da alohida `Host` alias'lari.

## 5. Gitea'ni self-host qilish

Gitea bitta jarayon: web UI, API va (konteynerda) SSH server. Rasmiy image `gitea/gitea`, ma'lumotlar `/data` da (repolar, SQLite bazasi, `app.ini` konfiguratsiyasi). `app.ini` dagi har sozlama `GITEA__<section>__<KEY>` ko'rinishidagi muhit o'zgaruvchisi bilan beriladi.

`compose.yaml` ning asosiy qismi (qolganini rasmiy yo'riqnomadan to'ldiring):

```
services:
  gitea:
    image: gitea/gitea:1.22          # pin a version, never "latest"
    environment:
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__server__ROOT_URL=http://localhost:3000/
      - GITEA__server__SSH_PORT=2222
    volumes: ["gitea-data:/data"]
    ports: ["127.0.0.1:3000:3000", "127.0.0.1:2222:22"]
```

| Sozlama | Ma'nosi |
|---------|---------|
| `USER_UID`, `USER_GID` | konteyner ichidagi `git` foydalanuvchisining ID lari |
| `GITEA__server__ROOT_URL` | tashqi URL: klon havolalari va webhook'lar shundan yasaladi |
| `GITEA__server__SSH_PORT` | klon havolasida ko'rsatiladigan SSH port (xost tomondagi port) |
| `GITEA__security__INSTALL_LOCK=true` | birinchi ishga tushishdagi web o'rnatish sahifasini o'chiradi |
| `GITEA__service__DISABLE_REGISTRATION=true` | ochiq ro'yxatdan o'tishni yopadi |
| `GITEA__migrations__ALLOW_LOCALNETWORKS=true` | lokal tarmoq manzillaridan migratsiya va mirror'ga ruxsat (default taqiqlangan) |

Administrator CLI orqali yaratiladi (buyruq konteyner ichida `git` foydalanuvchisi nomidan ishlashi shart):

```
docker compose exec -u git gitea gitea admin user create \
  --username labadmin --password '<password>' --email lab@example.com --admin
curl -s http://localhost:3000/api/v1/version
```

SSH bilan klon: `ssh://git@localhost:2222/<user>/<repo>.git`. API hujjati instansiyaning o'zida: `/api/swagger`. Production'da qo'shiladigan narsalar: tashqi baza (PostgreSQL), TLS'li reverse proxy, backup (`gitea dump` yoki volume va baza nusxasi) va tiklash sinovi, versiya yangilash tartibi.

### Mirroring

| Usul | Qanday | Qachon |
|------|--------|--------|
| bir martalik ko'chirish | `git clone --mirror <src>`, keyin `git push --mirror <dst>` | hostingdan hostingga migratsiya |
| pull mirror | Gitea: "New Migration", "This repository will be a mirror". Gitea manbadan davriy `fetch` qiladi, repo read-only | tashqi reponing ichki nusxasi, zaxira |
| push mirror | Gitea: repo Settings, "Mirror Settings". Har o'zgarish tashqi remote'ga yuboriladi | asosiy repo ichkarida, tashqarida ochiq nusxa |
| ikki push URL | `git remote set-url --add --push origin <url>` | qo'lda, kichik loyihalar |

`--mirror` barcha ref'larni (branch, tag, boshqa `refs/*`) aynan nusxalaydi. **Tuzoq: `git push --mirror` manbada yo'q ref'larni nishonda o'chiradi.** Uni faqat bo'sh yoki aynan mirror uchun mo'ljallangan repoga qarating. Mirror zaxira o'rnini to'liq bosmaydi: manbadagi xato (force push, o'chirilgan branch) ham sodiqlik bilan ko'chiriladi.

## 6. GitLab self-managed: tuzilishi

GitLab bitta dastur emas, komponentlar to'plami. Linux package (Omnibus) ularni bitta paketga yig'adi:

| Komponent | Vazifasi |
|-----------|----------|
| NGINX, Workhorse | kiruvchi HTTP, katta yuklamalar (git over HTTP, fayllar) |
| Puma (Rails) | web UI va API |
| Sidekiq | fon vazifalari (email, webhook, pipeline hodisalari) |
| Gitaly | Git repolariga kirish qatlami: barcha git amallari shu orqali |
| GitLab Shell | SSH orqali git |
| PostgreSQL, Redis | metadata bazasi; kesh, navbat, sessiyalar |
| GitLab Runner | CI job'larni bajaradi, **alohida** o'rnatiladi va serverda turmasligi kerak |

- Sozlash bitta faylda: `/etc/gitlab/gitlab.rb`, qo'llash `gitlab-ctl reconfigure`, holat `gitlab-ctl status`, loglar `gitlab-ctl tail`.
- O'rnatish usullari: Linux package, Docker image (`gitlab/gitlab-ce`), Kubernetes uchun Helm chart.
- Backup ikki qism: `gitlab-backup create` (repolar va baza) va alohida saqlanadigan `/etc/gitlab/gitlab-secrets.json` bilan `gitlab.rb`. Secrets faylisiz backup'dagi shifrlangan ma'lumot (CI o'zgaruvchilari, 2FA) o'qilmaydi.
- Yangilash faqat belgilangan upgrade path bo'ylab: versiyalarni sakrab o'tib bo'lmaydi.

Gitea bilan taqqoslaganda farq aniq: GitLab ko'p imkoniyat beradi va evaziga doimiy ekspluatatsiya ishini talab qiladi.

## 7. Ops muhandis javob beradigan sozlamalar

Repo sozlamalari production'ga kirish nazorati. Asosiy qoidalar bir-biriga tayanadi:

**Branch protection / rulesets.** `main` uchun: PR majburiy, kamida 1 tasdiq, yangi commit kelganda eski tasdiqlar bekor bo'lishi, required status checks, force push va o'chirish taqiqi, qoidalar adminlarga ham amal qilishi. GitHub'da ikki mexanizm bor: klassik branch protection va yangiroq rulesets (bir nechta qoida qatlamlanadi, tashkilot darajasida beriladi). GitLab'da "Protected branches" (kim merge, kim push qila oladi, rol bo'yicha), Gitea'da repo Settings, "Branches".

**CODEOWNERS.** Yo'l bo'yicha majburiy reviewer'lar. Fayl GitHub'da `.github/`, repo ildizi yoki `docs/` da; GitLab'da `.gitlab/`, ildiz yoki `docs/` da.

```
*              @acme/developers
/infra/        @acme/platform
*.tf           @acme/platform
/.github/      @acme/platform
```

Oxirgi mos kelgan qator ustun. Fayl o'zi hech narsani majburlamaydi: branch himoyasida "Require review from Code Owners" yoqilgandagina kuchga kiradi. CI konfiguratsiyasi va `CODEOWNERS` ning o'zi ham egali bo'lishi kerak, aks holda himoyani PR ichida o'chirib qo'yish mumkin.

**Required checks.** Merge'dan oldin o'tishi shart bo'lgan CI job'lar ro'yxati. "Branch yangilangan bo'lishi shart" talabi check'ni `main` ning hozirgi holati bilan birga sinashni kafolatlaydi (2-darsdagi semantic conflict). Tuzoq: job nomi o'zgartirilsa, eski nomdagi required check abadiy "kutilmoqda" bo'lib PR'larni bloklaydi.

**Secrets.** CI secret'lari hosting'da shifrlangan saqlanadi, saqlangach qiymatini qayta o'qib bo'lmaydi, loglarda maskalanadi. Darajalar: repo, environment (masalan `production`, tasdiqlovchi bilan), tashkilot. GitLab'da CI/CD variables: "masked" va "protected" (faqat protected branch va tag'larda ko'rinadi). Fork'dan kelgan PR'ga secret berilmaydi. Uzoq yashaydigan cloud kalitlari o'rniga OIDC orqali qisqa muddatli token olish afzal (CI/CD modulida).

**Qolganlari.** Ruxsatlar guruh orqali va eng kam rol bilan; ruxsat etilgan merge usullari (workflow'ga mos); merge'dan keyin branch'ni avtomatik o'chirish; secret scanning va push protection; webhook'lar va ularning secret'i; audit log; default branch nomi.

## Tuzoqlar

- Himoya qoidalari adminlarga amal qilmasa, "shoshilinch" to'g'ridan-to'g'ri push odatga aylanadi va qoida qog'ozda qoladi.
- Xodimning shaxsiy tokeni CI yoki serverda: u ketganda yo deploy to'xtaydi, yo sobiq xodim kirish huquqini saqlab qoladi.
- Keng scope'li, muddatsiz token. Sizib chiqsa butun tashkilot repolari ochiladi.
- Write huquqli deploy key production serverida: buzilgan server reponi ham buzadi.
- `CODEOWNERS` bor, lekin himoyada talab yoqilmagan, yoki fayl o'zi egasiz.
- Self-hosted Git serveri backup'siz yoki tiklash sinovisiz. Mirror backup emas.
- `git push --mirror` ni mavjud, ishlatilayotgan repoga qaratish: u yerdagi ortiqcha branch va tag'lar o'chadi.
- Gitea yoki GitLab'ni `latest` tag bilan ishlatish: kutilmagan major yangilanish va baza migratsiyasi.
- Self-hosted instansiyada ochiq ro'yxatdan o'tishni yopmaslik va uni internetga chiqarish.
- Public repoda himoyani sinab, keyin repo private'ga o'tkazilganda tarif tufayli qoidalar jimgina ishlamay qolishi. Tarif cheklovlarini oldindan tekshiring.

## Manbalar

- https://cli.github.com/manual/ – `gh` qo'llanmasi
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches – branch protection
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets – rulesets
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners – CODEOWNERS
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens – tokenlar
- https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys – deploy key va mashina kirishi
- https://docs.gitea.com/installation/install-with-docker – Gitea'ni Docker bilan o'rnatish (majburiy)
- https://docs.gitea.com/administration/config-cheat-sheet – `app.ini` sozlamalari
- https://docs.gitea.com/usage/repo-mirror – Gitea mirroring
- https://docs.gitea.com/administration/backup-and-restore – Gitea backup
- https://docs.gitlab.com/install/ – GitLab o'rnatish usullari va talablar
- https://docs.gitlab.com/development/architecture/ – GitLab arxitekturasi
- https://docs.gitlab.com/user/project/codeowners/ – GitLab Code Owners
- https://support.atlassian.com/bitbucket-cloud/ – Bitbucket Cloud hujjatlari

---

## Vazifalar

Vazifalarni GitHub'dagi sinov repolarida, lokal Gitea'da va `~/git-lab/04/` da bajaring. Javoblarni `git/04-hostings/README.md` ga yozing (papka `make new m=git n=04 name=hostings` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`compose.yaml`, `CODEOWNERS`, `protection.json`, `RUNBOOK.md`) shu papkaga saqlanadi. Token va parollar hech qayerga yozilmaydi: chiqishdagi qiymatlarni `***` bilan almashtiring.

### A. Taqqoslash va gh CLI

1. **Hosting choice.** Uch vaziyat uchun hosting tanlang va 4–6 gapda asoslang (model, CI, narx modeli, ekspluatatsiya yuki bo'yicha): (a) 8 kishilik startap, hammasi cloud'da; (b) bank, kod tashqi tarmoqqa chiqishi taqiqlangan, 200 dasturchi; (c) uyingizdagi server, shaxsiy loyihalar va GitHub repolarining zaxirasi. Har birida self-hosting'ning yashirin xarajatlarini sanang.

2. **gh auth.** `gh auth status` chiqishini (tokenni yashirib) yozing: qaysi akkaunt, qaysi protokol, qaysi scope'lar. Token qayerda saqlanadi? `gh api user --jq .login` va `gh api rate_limit --jq .resources.core` nima qaytaradi? Skriptda interaktiv login'siz `gh` qanday autentifikatsiya qilinadi?

3. **Repo from the terminal.** Faqat `gh` bilan (brauzersiz): `git-lab-04` public repo yarating va klon qiling, branch oching, commit qiling, PR yarating, PR holati va diff'ini ko'ring, squash merge qilib branch'ni o'chiring. Har qadam buyrug'ini yozing. `gh pr checkout` 3-darsdagi `refs/pull/<N>/head` bilan qanday bog'liq?

4. **Raw API.** `gh api` bilan: reponing ruxsat etilgan merge usullarini o'qing, `gh repo edit` bilan faqat squash merge'ni qoldiring va merge'dan keyin branch avtomatik o'chishini yoqing, natijani API orqali tasdiqlang. UI o'rniga API ishlatishning ops uchun foydasi nima?

### B. Token va deploy key

5. **Fine-grained token.** Faqat `git-lab-04` ga, faqat "Contents: read" huquqli, 7 kunlik fine-grained token yarating. `GH_TOKEN` orqali shu token bilan: repo tarkibini o'qing (ishlashi kerak), issue yarating va boshqa private repongizni o'qing (ikkalasi rad etilishi kerak; private repo bo'lmasa vaqtinchalik bo'sh repo oching). HTTP status kodlarini yozing va public repo nima uchun bu sinovga yaramasligini izohlang. Classic token'dagi `repo` scope bundan nimasi bilan xavfliroq?

6. **Token in the URL.** Scratch katalogda `git clone https://<token>@github.com/...` qiling (5-vazifadagi token bilan). Token qayerlarda iz qoldirdi (`.git/config`, shell tarixi)? Tokenni bekor qiling va bekor bo'lganini tekshiring. To'g'ri usullarni sanang.

7. **Deploy key.** Alohida SSH kalit yaratib `git-lab-04` ga read-only deploy key qilib qo'shing (`gh repo deploy-key add`). `~/.ssh/config` da alohida `Host` alias orqali aynan shu kalit bilan klon qiling, keyin push qilib ko'ring va xatoni yozing. Shu kalitni ikkinchi repoga qo'shib ko'ring: nima bo'ldi? Bir server 3 ta reponi tortishi kerak bo'lsa qanday sozlaysiz?

8. **Machine identity.** Jadval tuzing: deploy key, fine-grained PAT, CI ichki tokeni, alohida xizmat akkaunti. Ustunlar: kimga bog'langan, doirasi, muddati, xodim ketganda nima bo'ladi, qachon ishlatiladi. Production serveri konfiguratsiya reposini `pull` qilishi uchun qaysi birini tanlaysiz va nima uchun?

### C. Gitea

9. **Compose up.** Gitea uchun `compose.yaml` yozing: versiyasi belgilangan image, nomlangan volume, portlar faqat `127.0.0.1` da, SQLite, o'rnatish sahifasi o'chirilgan, ochiq ro'yxatdan o'tish yopiq. Ko'taring, `docker compose ps` va `curl` bilan API versiyasini ko'rsating. Portni `0.0.0.0` ga bog'lash ish mashinasida nimani anglatadi? Faylni ish papkasiga saqlang.

10. **Admin and users.** CLI orqali admin yarating, UI'da ikkinchi oddiy foydalanuvchi va `platform` tashkilotini oching. Admin CLI buyrug'ini `-u git` siz ishga tushirib ko'ring va xatoni yozing. Ro'yxatdan o'tish yopiqligini tekshiring.

11. **SSH and HTTPS access.** Gitea'da repo yarating. Unga ikki yo'l bilan push qiling: SSH (port `2222`, public kalit akkauntga qo'shilgan) va HTTP (parol o'rnida scope'i cheklangan access token). `GITEA__server__SSH_PORT` noto'g'ri bo'lsa UI'dagi klon havolasi qanday ko'rinadi va nima buziladi?

12. **Data survives.** `docker compose down` (volume'siz) va `up -d` qiling: repo va foydalanuvchilar joyidami? Volume ichida repolar, baza va `app.ini` qayerda joylashganini `docker compose exec` bilan toping. `down -v` nima qilgan bo'lardi? Bundan backup uchun qanday xulosa chiqadi?

13. **One-time migration.** `git-lab-04` ni `git clone --mirror` va `git push --mirror` bilan Gitea'dagi bo'sh repoga ko'chiring. Branch va tag'lar o'tganini `git ls-remote` bilan ikki tomonda solishtiring. Nima ko'chmadi (PR, sozlamalar, deploy key)? `refs/pull/*` ref'lari bilan nima bo'ldi?

14. **Pull mirror.** Gitea'da GitHub'dagi ochiq reponing pull mirror'ini yarating. GitHub tomonda yangi commit qiling, Gitea'da qo'lda sinxronlashni ishga tushirib commit kelganini ko'rsating. Mirror repoga push qilib ko'ring, xatoni yozing. Default sinxronlash oralig'i qancha va uni qayerda o'zgartirasiz?

15. **Mirror is not backup.** 13-vazifadagi juftlikda manba repoda branch'ni o'chiring va tag'ni force bilan ko'chiring, keyin yana `push --mirror` qiling. Gitea tomonda nima bo'ldi? Haqiqiy backup mirror'dan nimasi bilan farq qilishi kerak? Gitea uchun backup rejasini 5–6 gapda yozing (nima, qanchalik tez-tez, qayerga, tiklash qanday sinaladi).

16. **GitLab on paper.** GitLab arxitektura hujjatidan foydalanib, `git push` (SSH orqali) so'rovining yo'lini komponentma-komponent yozing: qaysi komponent qabul qiladi, huquqni kim tekshiradi, diskka kim yozadi, pipeline'ni kim ishga tushiradi. Runner nima uchun GitLab serverining o'zida turmasligi kerak? Backup'da `gitlab-secrets.json` nima uchun alohida saqlanadi?

### D. Repo sozlamalari

17. **Branch protection as code.** `git-lab-04` ning `main` branch'i uchun himoyani `protection.json` fayli va `gh api -X PUT` orqali o'rnating: PR majburiy, force push va o'chirish taqiqlangan, chiziqli tarix, qoidalar adminga ham amal qiladi. `gh api` bilan o'qib tasdiqlang. To'g'ridan-to'g'ri push va force push'ni sinab, server javoblarini yozing. Faylni ish papkasiga saqlang.

18. **CODEOWNERS.** `git-lab-04` da `infra/`, `src/`, `.github/` kataloglari va `CODEOWNERS` yarating (egasi sifatida o'z akkauntingiz). Qoidalar tartibini almashtirib "oxirgi mos kelgan ustun" ekanini PR'da ko'rsating. Himoyada code owner review talabini yoqing. Yakka akkaunt bilan o'z PR'ingizni tasdiqlay olasizmi, bu nimani ko'rsatadi? `CODEOWNERS` ning o'zi nima uchun egali bo'lishi kerak?

19. **Secrets.** `gh secret set` bilan repo secret va `production` environment secret yarating (soxta qiymat). `gh secret list` nimani ko'rsatadi, qiymatni qayta o'qib bo'ladimi? Hujjatdan toping va yozing: fork'dan kelgan PR secret'ni ko'radimi, environment'ga "required reviewers" qo'yilsa nima o'zgaradi, secret logga chiqsa nima bo'ladi.

20. **Protection on Gitea.** Xuddi shu siyosatni Gitea'dagi repoda UI orqali takrorlang: `main` himoyasi (push taqiqi, PR majburiy, kamida 1 tasdiq) va ikkinchi foydalanuvchi bilan to'liq PR oqimi (biri ochadi, ikkinchisi tasdiqlaydi). To'g'ridan-to'g'ri push'ga server javobini yozing. GitHub'dagi sozlamalar bilan farqlarni jadvalga soling.

### E. Modul mini-loyihasi

21. **Production-ready repository.** `ops-demo` nomli yangi repo uchun to'liq to'plam (GitHub public + lokal Gitea mirror). Talablar:
    - tarkib: kichik skript yoki konfiguratsiya, `README.md`, `CONTRIBUTING.md` (tanlangan workflow va asosi), `.gitignore`, `.pre-commit-config.yaml`, `CODEOWNERS`;
    - tarix: kamida 3 ta PR orqali qurilgan, har commit imzolangan va atomik, `main` chiziqli;
    - himoya: `protection.json` kod sifatida, to'g'ridan-to'g'ri va force push yopiq;
    - reliz: imzolangan annotated tag `v0.1.0`, `gh release create` bilan reliz;
    - hodisa mashqi: `main` ga "buzuq" PR merge qiling, uni PR orqali `revert` qiling, `v0.1.1` chiqaring;
    - mashina kirishi: read-only deploy key bilan `/tmp` ga "server kloni", u yerda `git pull --ff-only` va `git verify-tag`;
    - mirror: Gitea'ga ko'chirilgan va yangilanib turadigan nusxa (usulni tanlang va asoslang);
    - `RUNBOOK.md`: kirish huquqlari jadvali (kim, nima bilan, qanday huquq), token va kalitlarni almashtirish tartibi, "main buzildi" va "secret push qilindi" hodisalari uchun qadamlar, GitHub ishlamay qolganda Gitea nusxasidan ishni davom ettirish tartibi.

    README'da har talab qanday bajarilganini buyruq va natija bilan ko'rsating.

### Topshirish

Tayyor bo'lgach:
1. `git/04-hostings/README.md` da 21 ta vazifa, har biri `## N. Title` sarlavhasi ostida.
2. `compose.yaml`, `CODEOWNERS`, `protection.json`, `RUNBOOK.md` ish papkasida, `make check` toza.
3. Token, parol va private kalit hech bir faylda yo'q.
4. Tozalangan: `docker compose down -v`, `~/git-lab/04`, GitHub'dagi sinov repolari, tokenlar va deploy key'lar (`gh repo deploy-key list`, token sahifasi bilan tekshirilgan).
5. Menga xabar bering, tekshiraman. Bu modulning oxirgi darsi: qabul qilingach modul yopiladi.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Hostinglar orasida reponi ko'chirganda nima oson o'tadi, nima alohida ish talab qiladi?
- SaaS va self-hosted tanlovida qaysi omillar hal qiluvchi? "Bepul" nima uchun yetarli sabab emas?
- Deploy key, fine-grained token va CI ichki tokeni qachon ishlatiladi? Nima uchun xodimning shaxsiy tokeni serverga qo'yilmaydi?
- `git clone --mirror` oddiy klondan nimasi bilan farq qiladi va `push --mirror` nima uchun xavfli?
- Pull mirror va push mirror farqi nima? Mirror nima uchun backup emas?
- GitLab self-managed qaysi asosiy komponentlardan iborat va Gitea'ga nisbatan ekspluatatsiya narxi nima uchun yuqori?
- Branch protection, `CODEOWNERS` va required checks bir-birini qanday to'ldiradi? Bittasi yo'q bo'lsa qanday tuynuk qoladi?
- CI secret'lari qayerda saqlanadi va fork'dan kelgan PR'ga nima uchun berilmaydi?
- Repoga yozish huquqi nima uchun production'ga kirish huquqi bilan teng deb qaraladi?
