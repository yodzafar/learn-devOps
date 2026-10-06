# 4-dars: Git hostinglar

Maqsad: Git hosting'ni foydalanuvchi emas, uni boshqaradigan muhandis ko'zi bilan ko'rish. To'rt asosiy platforma (GitHub, GitLab, Gitea, Bitbucket) nimasi bilan farq qilishini, ularga mashina nomidan qanday xavfsiz kirilishini (token, deploy key), hosting'ni o'zingiz qanday ko'tarishingizni va repo sozlamalaridan qaysilari ops zimmasida ekanini o'rganasiz. 3-darsdagi protected branch, review va hook tushunchalari bu yerda aniq sozlamalarga aylanadi. Keyingi CI/CD modulida pipeline'lar aynan shu platformalar ustida quriladi, GitOps'da esa repo production'ga kirish eshigi bo'ladi: repoga yozish huquqi deploy huquqiga teng.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh, ikkinchi kun 4-bo'lim va B guruh, uchinchi kun 5-bo'lim, "Birga bajaramiz" va C guruhning 9–15 vazifalari, to'rtinchi kun 6–7 bo'limlar, 16-vazifa va D guruh, beshinchi kun 21-vazifa (mini-loyiha) va tozalash. Diqqat qilinadigan joylar: SaaS va self-hosted farqining ops narxi, `gh` bilan avtomatlashtirish, token va deploy key'da eng kam huquq, Gitea'ni ko'tarish va mirroring, himoya qoidalarining o'zaro bog'lanishi (branch protection, `CODEOWNERS`, required checks).

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ko'ring va chiqishni darsdagi izoh bilan solishtiring. Akkaunt nomi, SHA, versiya kabi sizda farq qiladigan qiymatlar `<...>` bilan belgilangan. Hosting'larning web UI'si tez-tez o'zgaradi, shuning uchun darsda sozlamalar rasmiy hujjatdagi nomi bilan ataladi va hujjat havolasi beriladi: tugma joyini emas, sozlama nima qilishini eslab qoling. Har bo'lim oxiridagi "Nima uchun shunday" qoidaning sababini aytadi.

## Laboratoriya

Git ishlari ikkala mashinada host'ning o'zida bajariladi, `lab` VM bu darsda kerak emas (tizim holatini o'zgartiradigan vazifa yo'q). To'rt "joy" bor:

| Joy | Nima bajariladi |
|-----|-----------------|
| Host (Zorin yoki macOS) | `git`, `gh`, `ssh`, `curl`, `docker compose` buyruqlari; scratch repolar `~/git-lab/04/` da |
| Konteyner (`gitea`) | lokal Gitea serveri; ichiga faqat `docker compose exec` orqali kiriladi |
| GitHub (cloud) | shaxsiy akkauntdagi sinov repolari (`git-lab-04`, `ops-demo`), public, haqiqiy ma'lumotsiz |
| Kurs reposi | `git/04-hostings/` ish papkasi: `README.md` va so'ralgan fayllar |

Kerakli asboblar va ularni tekshirish (ikkala host'da bir xil buyruqlar):

```
git --version
gh --version
docker --version
docker compose version
```

- **`gh`** (GitHub CLI) birinchi marta shu darsda kerak bo'ladi, 3-darsda o'rnatilmagan. Har ikkala mashinada o'rnating: Zorin'da GitHub'ning rasmiy apt reposidan (`amd64`; aniq buyruqlar https://github.com/cli/cli/blob/trunk/docs/install_linux.md da, "Debian, Ubuntu" bo'limi), macOS'da `brew install gh` (`arm64`). Keyin har mashinada bir marta `gh auth login`.
- **Docker** `SETUP.md` bo'yicha o'rnatilgan: Zorin'da Docker Engine va `docker-compose-plugin` paketi (Docker'ning rasmiy apt reposi), macOS'da Docker Desktop (`arm64`, Compose uning ichida keladi). Docker bu kursda hali o'tilmagan (alohida docker moduli bor), shuning uchun kerakli atamalar 5-bo'limda bittadan tushuntiriladi.
- **Scratch repolar**: `mkdir -p ~/git-lab/04`. Kurs reposi ichida repo yaratmang (1-darsdagi "embedded repository" muammosi).
- **GitLab** bu darsda o'rnatilmaydi (o'quv mashinasi uchun og'ir), faqat tuzilishi o'rganiladi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker Engine to'g'ridan-to'g'ri host kernel'ida ishlaydi, image `amd64`. Volume fayllari host diskida `/var/lib/docker/volumes/` ostida turadi (faqat `sudo` bilan ko'rinadi, egasi konteyner ichidagi UID). Host'da `sshd` ishlayotgan bo'lishi mumkin va u 22-portni band qiladi, shuning uchun Gitea SSH'i host'ning `2222` portiga chiqariladi. |
| macOS (uy) | Docker Desktop yashirin Linux VM ichida ishlaydi, image `arm64` (Gitea image'i multi-arch, bir xil tag ikkala arxitekturada ishlaydi). `127.0.0.1` ga chiqarilgan portlar Zorin'dagi kabi ishlaydi, lekin konteyner IP manziliga va `/var/lib/docker/volumes/` ga host'dan yetib bo'lmaydi: volume ichini faqat `docker compose exec` orqali ko'rasiz. `gh` token saqlaydigan joy Zorin'dagidan farq qiladi (2-vazifa). |

Ikkala mashinada `3000` porti band bo'lishi mumkin (frontend dev serverlari ko'pincha shu portni oladi). Band bo'lsa dev serverni to'xtating yoki host tomondagi portni almashtiring va `ROOT_URL` ni ham shunga moslang (5-bo'lim).

**Holatni ikkinchi mashinada tiklash.** GitHub'dagi repolar, tokenlar va himoya qoidalari cloud'da, ikkala mashinadan bir xil ko'rinadi. Lokal narsalar ko'chmaydi: scratch klonlar (`gh repo clone` bilan qayta olinadi), deploy key'ning private qismi (ikkinchi mashinada yangi kalit yaratib, uni ham deploy key qilib qo'shing; private kalitni mashinalar orasida ko'chirmang) va Gitea (volume shu mashinada qoladi). Gitea'ga oid C guruh va 20-vazifani bitta mashinada boshlab o'sha yerda tugating; ikkinchi mashinada davom ettirish kerak bo'lsa, ish papkasidagi `compose.yaml` bilan qayta ko'tarib, admin va repolarni qaytadan yarating.

**Tozalash** (dars oxirida, har ikkala mashinada):

```
docker compose down -v            # in the folder with compose.yaml: container, network and volume
docker volume ls                  # no gitea volume must remain
rm -rf ~/git-lab/04
gh auth refresh -s delete_repo    # one-time: extra scope needed to delete repositories
gh repo delete <user>/git-lab-04 --yes
gh auth refresh -r delete_repo    # drop the scope again
```

Tokenlar GitHub'ning token sahifasida, deploy key'lar `gh repo deploy-key list` bilan tekshirilib o'chiriladi. Cloud xarajati yo'q: public repolar va bepul tarif yetadi.

---

## 1. Hosting nima qo'shadi

### Git serveri aslida nima

1-darsda ko'rdingiz: repo bu obyektlar va ref'lar. 3-darsda `git init --bare` bilan yaratilgan bare repo (working tree'siz, faqat `.git` ichidagi narsalardan iborat repo) ikki dasturchi o'rtasida "server" bo'lib xizmat qildi. Git hosting ham ichida xuddi shunday bare repolarni saqlaydi. Ustiga qo'shiladigan narsa Git'ning o'zida yo'q: kim kirayotganini aniqlash, unga nima mumkinligini hal qilish va repo atrofidagi hamkorlik.

### Mexanizm: push so'rovi hosting ichida

`git push` paytida ketma-ketlik har platformada bir xil sxemada:

1. Autentifikatsiya: SSH kalit yoki HTTPS orqali token bo'yicha "bu kim" aniqlanadi (3-dars).
2. Avtorizatsiya: hosting o'z bazasidan shu foydalanuvchining shu repodagi rolini tekshiradi. Git'ning o'zida "foydalanuvchi" tushunchasi yo'q, commit'dagi `user.name` shunchaki matn.
3. Qabul: serverda `git-receive-pack` jarayoni obyektlarni qabul qiladi. Ref'ni yangilashdan oldin server tomonidagi hook'lar ishlaydi (3-darsda client hook'larni ko'rgansiz, `pre-receive` ularning serverdagi qarindoshi). Branch himoyasi aynan shu yerda amalga oshadi, shuning uchun rad javobida `hook declined` so'zi chiqadi (7-bo'lim).
4. Hodisa: ref yangilangach hosting hodisa chiqaradi: webhook (hosting tashqi URL'ga yuboradigan HTTP so'rov), CI pipeline, bildirishnoma.

### Hosting qo'shadigan qatlamlar

- identifikatsiya va huquqlar: foydalanuvchi, guruh, rol, SSO (single sign-on, kompaniyaning yagona kirish tizimi);
- hamkorlik: pull request yoki merge request, review, issue;
- siyosat: branch himoyasi, majburiy tekshiruvlar, code owners;
- avtomatlashtirish: CI/CD, webhook, API;
- qo'shimcha registrlar: container va package registry, release sahifalari.

### Misol: PR Git'ga emas, hosting'ga tegishli

```
$ git ls-remote https://github.com/cli/cli.git 'refs/pull/1/*'
<sha>	refs/pull/1/head
```

`git ls-remote` klon qilmasdan remote'dagi ref'larni ko'rsatadi. Chapda commit SHA, o'ngda ref nomi. `refs/pull/1/head` ni Git emas, GitHub yaratgan (3-dars): bu PR'ning oxirgi commit'iga ko'rsatkich. PR'ning sarlavhasi, muhokamasi va tasdiqlari esa ref'da emas, GitHub bazasida. Shuning uchun reponi boshqa hosting'ga ko'chirganda Git tarixi to'liq o'tadi, lekin PR tarixi, issue'lar, CI konfiguratsiyasi, secret'lar va huquqlar alohida ish.

### Real ishda qachon kerak

- Hosting almashtirish rejasida: `git push` bir daqiqalik ish, qolgan qatlamlarni ko'chirish haftalar.
- "Kim push qila oladi" savoliga javob Git'da emas, hosting sozlamalarida. Audit paytida aynan shu yer ko'riladi.
- Hosting ishlamay qolganda: har klon to'liq tarixga ega, ish to'xtamaydi; to'xtaydigani PR, CI va deploy.

### Nima uchun shunday

Git 2005-yilda Linux kernel'i uchun yozilgan va hamkorlik email orqali yuborilgan patch'larga tayangan, markaziy server va huquqlar tizimi ataylab kiritilmagan. Bo'shliqni hostinglar to'ldirdi (GitHub 2008-yilda) va pull request'ni har biri o'zicha qurdi. Natijada protokol ochiq va hamma joyda bir xil, uning ustidagi qatlam esa platformaga bog'lab qo'yadi (vendor lock-in). Muqobili: Gerrit kabi tizimlar yoki kernel jamoasidagi email oqimi, ular ham Git ustidagi alohida qatlam.

## 2. Taqqoslash

### To'rt platforma

SaaS (software as a service) bu dastur provayder serverida ishlaydigan va sizga tayyor xizmat sifatida beriladigan model. Self-hosted bu dasturni o'z serveringizga o'zingiz o'rnatib yuritishingiz.

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

Aniq narxlar va kvotalar tez-tez o'zgaradi, qaror paytida rasmiy pricing sahifasidan oling. Runner bu CI job'larni bajaradigan alohida mashina yoki jarayon (CI/CD modulida). Gitea'ning 2022-yilda ajralgan forki Forgejo ham bor, tuzilishi va sozlamalari juda yaqin.

### SaaS yoki self-hosted

| | SaaS | Self-hosted |
|---|------|-------------|
| Ekspluatatsiya | provayderda | sizda: yangilash, backup, monitoring, xavfsizlik yamoqlari |
| Ma'lumot joylashuvi | provayder hududida | o'zingiz tanlagan joyda (regulyator talabi, yopiq tarmoq) |
| Mavjudlik | provayder nosozligi sizga ham nosozlik | o'zingiz ta'minlaysiz |
| Narx | foydalanuvchi va daqiqa boshiga | server + muhandis vaqti |

Self-hosting sababi odatda uchta: ma'lumot tashqariga chiqmasligi shart, internetdan uzilgan muhit (air-gapped), yoki foydalanuvchi boshiga narx katta jamoada qimmatga tushishi.

### Misol: bitta repo, ikki hosting

Git nuqtai nazaridan hosting shunchaki remote URL (3-dars), bitta klon bir nechta hosting'ga qaray oladi:

```
$ git remote -v
gitea	ssh://git@localhost:2222/<user>/demo.git (fetch)
gitea	ssh://git@localhost:2222/<user>/demo.git (push)
origin	git@github.com:<user>/demo.git (fetch)
origin	git@github.com:<user>/demo.git (push)
```

Har remote uchun ikki qator: `fetch` va `push` URL'lari (ular farq qilishi mumkin, 5-bo'limdagi "ikki push URL"). `origin` GitHub'ga scp-uslubidagi SSH manzil bilan, `gitea` esa to'liq `ssh://` URL bilan yozilgan, chunki nostandart portni (`2222`) faqat shu shaklda ko'rsatish mumkin. `git push gitea main` va `git push origin main` bir xil protokolda ishlaydi, farq faqat manzilda.

### Real ishda qachon kerak

- Yangi jamoa yoki loyiha uchun hosting tanlash, yoki mavjudini almashtirishni asoslash.
- Regulyator "kod mamlakat hududida saqlansin" deganda SaaS variantlari tushib qoladi.
- Byudjet muhokamasida: foydalanuvchi boshiga narx bilan server va muhandis vaqtini solishtirish.

### Nima uchun shunday

"Bepul" self-hosting uchun kamdan-kam to'g'ri sabab: Git serveri yo'qolsa butun kompaniya ishi to'xtaydi, demak backup, tiklash sinovi, yangilash tartibi va navbatchilik kerak, bular muhandis vaqti. SaaS shu ishni provayderga beradi va evaziga nazoratning bir qismini oladi. GitLab bir xil mahsulotni ikki modelda sotadi, GitHub asosan SaaS, Gitea esa SaaS'ga muqobil sifatida "bitta binar" g'oyasi bilan paydo bo'lgan (Gogs loyihasining 2016-yildagi forki).

## 3. gh CLI

### Bu nima

`gh` GitHub'ning rasmiy buyruq satri asbobi: web UI'da qilinadigan ishni terminal buyrug'iga, demak skriptga aylantiradi. U `git` o'rnini bosmaydi: `git` obyekt va ref'lar bilan ishlaydi, `gh` esa hosting qatlami bilan (PR, sozlama, secret, reliz).

### Mexanizm

GitHub'ning hamma imkoniyati REST API orqali ochiq: bu `https://api.github.com` ga yuboriladigan HTTP so'rovlar, javob JSON. `gh` ning har buyrug'i shunday so'rovlarga aylanadi va `Authorization` sarlavhasiga saqlangan tokenni qo'yadi. Token `gh auth login` paytida OAuth oqimi orqali olinadi (brauzerda bir martalik kod tasdiqlanadi) va tizimning secret saqlagichiga (u topilmasa `gh` ning konfiguratsiya fayliga) yoziladi. Skript va CI'da interaktiv login o'rniga `GH_TOKEN` muhit o'zgaruvchisi o'qiladi: u berilgan bo'lsa saqlangan tokendan ustun turadi.

### Misol: holat va xom API

```
$ gh auth status
github.com
  ✓ Logged in to github.com account <user> (keyring)
  - Active account: true
  - Git operations protocol: ssh
  - Token: gho_************************************
  - Token scopes: 'admin:public_key', 'gist', 'read:org', 'repo'
```

Qatorma-qator: `github.com` qaysi host (GitHub Enterprise Server bo'lsa boshqa nom turadi); `Logged in ... account <user>` qaysi akkaunt, qavs ichidagi so'z token qayerdan o'qilganini bildiradi; `Active account` bir nechta akkaunt bo'lsa qaysi biri ishlatilishi; `Git operations protocol` bu `gh repo clone` kabi buyruqlar `git` ni SSH yoki HTTPS URL bilan chaqirishi; `Token` yashirilgan token, `gho_` prefiksi OAuth token ekanini bildiradi (`ghp_` classic PAT, `github_pat_` fine-grained PAT); `Token scopes` shu tokenga berilgan huquq doiralari (4-bo'lim). Ro'yxat sizda boshqacha bo'lishi mumkin.

```
$ gh api repos/cli/cli --jq '.default_branch, .visibility'
trunk
public
$ gh api -i repos/cli/does-not-exist | head -1
HTTP/2.0 404 Not Found
```

`gh api <endpoint>` autentifikatsiya qilingan xom so'rov yuboradi; `--jq` javob JSON'idan maydon tanlaydi (alohida `jq` o'rnatish shart emas); `-i` javobning HTTP status qatori va sarlavhalarini ham chiqaradi. O'z repongiz ichida turganda endpoint'da `{owner}` va `{repo}` yozsangiz, `gh` ularni joriy repodan to'ldiradi. Status kodlari: `200` muvaffaqiyat, `401` token yo'q yoki yaroqsiz, `403` token bor lekin huquq yetmaydi, `404` topilmadi. GitHub private resursga huquqsiz so'rovga ko'pincha `403` emas `404` qaytaradi, shunda resurs mavjudligi ham oshkor bo'lmaydi.

### Buyruqlar xaritasi

| Guruh | Buyruqlar |
|-------|-----------|
| repo | `gh repo create`, `clone`, `fork`, `view`, `edit`, `delete`, `gh repo deploy-key add/list/delete` |
| PR | `gh pr create`, `list`, `view`, `checkout <N>`, `diff`, `review --approve`, `checks`, `merge` |
| sozlama | `gh secret set/list`, `gh variable set/list`, `gh ruleset list/view/check` |
| reliz | `gh release create <tag> --generate-notes` |
| xom API | `gh api <endpoint>`; `-X` metod, `--input` so'rov tanasi fayldan, `--jq` filtr |

Odatiy oqim (har buyruqning flag'lari `gh <buyruq> --help` da):

```
gh repo create demo --public --clone   # create on GitHub and clone into ./demo
gh pr create --fill                    # title and body taken from commits
gh pr checks                           # CI status of the current branch's PR
gh pr merge --squash --delete-branch   # merge and remove the branch
```

`gh api` UI'da bor, lekin alohida buyrug'i yo'q har narsani qamraydi. Shuning uchun repo sozlamalarini kod sifatida saqlash mumkin: JSON fayl va `gh api -X PUT <endpoint> --input file.json`. GitLab uchun shu rolni `glab`, Gitea uchun `tea` bajaradi.

### Real ishda qachon kerak

- 40 ta repoga bir xil sozlamani qo'yish: UI'da 40 marta bosish o'rniga bitta sikl.
- CI ichida reliz yaratish, PR'ga izoh yozish, boshqa repoda workflow'ni ishga tushirish.
- Audit: "qaysi repolarda himoya yo'q" savoliga API orqali bir daqiqada javob.

### Nima uchun shunday

UI'da qo'lda qilingan sozlama takrorlanmaydi va review qilinmaydi: kim, qachon, nima uchun o'zgartirgani ko'rinmaydi. API orqali qilingan sozlama fayl bo'lib repoda yotadi, PR orqali o'zgaradi va istalgan payt qayta qo'llanadi. Bu "infrastructure as code" g'oyasining eng kichik ko'rinishi, Terraform modulida shu ish GitHub provider'i bilan qilinadi. Frontend'dagi o'xshashi haqiqiy: ESLint qoidalarini har kim IDE'da qo'lda sozlashi o'rniga `eslint.config.js` repoda turadi.

## 4. Tokenlar va deploy key

### Muammo: mashina ham kirishi kerak

Odam brauzer, parol, ikki bosqichli tasdiq va SSH kalit bilan kiradi (3-dars). CI job, production serveri yoki skript esa brauzer ocha olmaydi, lekin u ham reponi klon qilishi yoki API chaqirishi kerak. Buning uchun alohida, cheklangan identifikator beriladi. Ikki turi bor:

- **Token**: hosting bergan uzun tasodifiy satr, HTTPS so'rovda parol o'rnida yuboriladi. PAT (personal access token) bu foydalanuvchi o'z nomidan chiqaradigan token.
- **Deploy key**: foydalanuvchiga emas, bitta repoga biriktirilgan SSH public kalit.

### Mexanizm

Hosting tokenning o'zini emas, hash'ini saqlaydi, shuning uchun token faqat yaratilgan paytda bir marta ko'rsatiladi. So'rov kelganda hosting tokenni topadi va uchta narsani tekshiradi: egasi kim, token doirasi (scope yoki permission) shu amalga yetadimi, muddati o'tmaganmi. Yakuniy huquq egasining huquqi va token doirasining kesishmasi: token egasidan ko'p narsa qila olmaydi. Deploy key'da SSH ulanish paytida GitHub kelgan public kalitni bazadan qidiradi: u foydalanuvchi kaliti bo'lsa foydalanuvchi nomidan, deploy key bo'lsa faqat o'sha bitta repo nomidan ishlaydi.

| Vosita | Kimga bog'langan | Doirasi | Qachon |
|--------|------------------|---------|--------|
| Personal access token, classic (GitHub) | foydalanuvchi | keng scope'lar (`repo` barcha repolarga) | faqat fine-grained qo'llamaydigan holatlarda |
| Fine-grained PAT (GitHub) | foydalanuvchi | tanlangan repolar, har resurs uchun read yoki write, muddat | skriptlar, API |
| Project / group access token (GitLab) | loyiha yoki guruh | rol + scope'lar, muddat | CI va integratsiyalar |
| Access token (Gitea) | foydalanuvchi | scope'lar (`read:repository`, `write:repository` ...) | API, HTTPS orqali git |
| Deploy key | **bitta repo** | SSH public kalit, default read-only, ixtiyoriy write | server yoki CI bitta reponi `clone`/`pull` qilishi |
| CI ichki tokeni (`GITHUB_TOKEN`, GitLab `CI_JOB_TOKEN`) | bitta job | avtomatik beriladi, job tugashi bilan o'ladi | pipeline ichidan o'z reposiga murojaat |

Fine-grained PAT yaratishda GitHub so'raydigan maydonlar: "Token name", "Expiration", "Resource owner", "Repository access" (masalan "Only select repositories") va "Permissions" (har resurs uchun "No access", "Read-only" yoki "Read and write"; "Metadata: Read-only" avtomatik qo'shiladi).

### Misol: bir xil so'rov, uch xil identifikator

```
$ gh api user --jq .login
<user>
$ GH_TOKEN=<fine-grained-token> gh api user --jq .login
<user>
$ GH_TOKEN=invalid gh api user
{
  "message": "Bad credentials",
  ...
}
gh: Bad credentials (HTTP 401)
```

Birinchi so'rov `gh auth login` tokeni bilan ketdi. Ikkinchisida `GH_TOKEN` faqat shu bitta buyruq uchun berildi va saqlangan tokendan ustun keldi: javob bir xil, chunki fine-grained token ham o'sha foydalanuvchiga bog'langan, lekin uning qo'lidan keladigan ish ancha tor. Uchinchisida token yaroqsiz: `401` "kimligingni bilmadim" degani, `403` esa "bildim, lekin ruxsat yo'q". Eslatma: `GH_TOKEN=<...>` buyruq satrida yozilsa shell tarixiga tushadi; skriptda u CI secret'idan, qo'lda sinovda `read -rs GH_TOKEN` kabi ko'rinmas kiritishdan olinadi.

Deploy key uchun SSH tomoni (kalit yaratish 3-darsda):

```
# ~/.ssh/config
Host github-<alias>
    HostName github.com
    User git
    IdentityFile ~/.ssh/<key-file>
    IdentitiesOnly yes
```

`Host` bu siz o'ylab topgan taxallus, `HostName` haqiqiy manzil. `IdentityFile` shu taxallus uchun qaysi private kalit ishlatilishini aytadi, `IdentitiesOnly yes` esa SSH agent'dagi boshqa kalitlarni taklif qilmaslikni: usiz SSH avval shaxsiy kalitingizni yuboradi va siz deploy key emas, o'z nomingizdan kirib qo'yasiz. Klon manzilida `github.com` o'rniga taxallus yoziladi: `git clone github-<alias>:<user>/<repo>.git`. Tekshirish: `ssh -T github-<alias>` javobida foydalanuvchi nomi emas, `<user>/<repo>` chiqadi.

GitHub'da bitta SSH kalit faqat bitta repoga deploy key bo'la oladi (ikkinchisida "Key is already in use"). Bir server bir nechta repo tortsa: har repoga alohida kalit va alohida `Host` taxallusi.

### Qoidalar

- **Eng kam huquq** (least privilege): bitta repo, faqat read, qisqa muddat. Production serveri kodni tortib olishi uchun write huquqi kerak emas.
- **Odam tokeni mashinaga berilmaydi.** Xodim ketganda token o'ladi va deploy to'xtaydi, yoki o'lmaydi va bu yanada yomon. Mashina uchun deploy key, loyiha tokeni yoki alohida xizmat akkaunti (odamga emas, tizimga tegishli akkaunt).
- **Token parolga teng.** Kodga, `.git/config` ga, CI loglariga tushmasligi kerak. `git clone https://<token>@host/...` tokenni URL bilan birga `.git/config` va shell tarixiga yozadi. To'g'ri yo'llar: credential helper (Git parolni tizim saqlagichidan oladigan mexanizm, `gh auth setup-git` uni `gh` ga ulaydi), SSH kalit, CI'da secret.
- Har tokenning egasi, maqsadi va muddati yozib qo'yiladi, almashtirish (rotation) tartibi oldindan ma'lum bo'ladi.

### Real ishda qachon kerak

- GitOps: klaster ichidagi Argo CD yoki Flux konfiguratsiya reposini read-only deploy key bilan o'qiydi.
- Hodisa: token logga chiqib ketdi. Birinchi qadam uni bekor qilish (revoke), keyin nima qilinganini audit logdan ko'rish.
- Offboarding: xodim ketganda uning nomidagi tokenlar ro'yxati bo'sh bo'lishi kerak.

### Nima uchun shunday

Classic PAT'da `repo` scope'i foydalanuvchi yeta oladigan barcha repolarga to'liq huquq beradi: bitta sizib chiqqan token butun tashkilotni ochadi. Fine-grained PAT shu sabab keyinroq qo'shildi: repo ro'yxati, resurs bo'yicha huquq va majburiy muddat. Deploy key'ning bitta repoga bog'lanishi ham shu mantiq: buzilgan server faqat o'zi tortadigan reponi ko'radi. Eng yaxshi variant esa umuman uzoq yashaydigan secret saqlamaslik: CI ichki tokeni job bilan birga o'ladi, cloud'ga kirishda OIDC orqali qisqa muddatli token olinadi (CI/CD modulida).

## 5. Gitea'ni self-host qilish

### Docker atamalari (bu dars uchun yetarlisi)

Docker alohida modulda noldan o'tiladi, bu yerda Gitea'ni ko'tarish uchun kerakli beshta tushuncha:

- **Image**: dastur va unga kerakli hamma fayllar jamlangan, o'zgarmas paket (`gitea/gitea:<versiya>`). Tag (`:` dan keyingi qism) versiyani tanlaydi.
- **Konteyner**: image'dan ishga tushirilgan, o'z fayl tizimi va tarmog'iga ega izolyatsiyalangan jarayon. Konteyner o'chirilsa ichida yozilgan fayllar ham ketadi.
- **Volume**: Docker boshqaradigan, konteynerdan tashqarida yashaydigan papka. Konteyner ichidagi yo'lga ulanadi va konteyner o'chirilganda ham qoladi.
- **Published port**: `HOST_IP:HOST_PORT:CONTAINER_PORT` yozuvi, host'dagi manzil va portga kelgan ulanishni konteyner portiga uzatadi. `HOST_IP` yozilmasa Docker host'ning barcha tarmoq interfeyslarida tinglaydi; `127.0.0.1` yozilsa faqat shu mashinaning o'zidan kirish mumkin.
- **`compose.yaml`**: bir yoki bir nechta konteynerni (image, o'zgaruvchilar, volume, portlar) tavsiflaydigan fayl. `docker compose up -d` shu faylga ko'ra hammasini fonda ko'taradi. `package.json` dagi `scripts` ga o'xshaydi: uzun buyruq o'rniga repoda turadigan tavsif.

### Gitea ichida nima bor

Gitea bitta jarayon: web UI va API (konteyner ichida `3000` port) va Git operatsiyalari. Rasmiy image'da uning yonida SSH server ham ishlaydi (konteyner ichida `22` port). Hamma holat `/data` da: repolar (bare repolar), SQLite bazasi (bitta fayldan iborat ma'lumotlar bazasi: foydalanuvchilar, PR'lar, sozlamalar) va `app.ini` konfiguratsiya fayli. Shuning uchun `/data` ga volume ulanadi. `app.ini` dagi har sozlamani `GITEA__<section>__<KEY>` ko'rinishidagi muhit o'zgaruvchisi bilan berish mumkin: konteyner ishga tushganda ularni `app.ini` ga yozadi.

| Sozlama | Ma'nosi |
|---------|---------|
| `USER_UID`, `USER_GID` | konteyner ichidagi `git` foydalanuvchisining ID lari (volume'dagi fayllar egasi) |
| `GITEA__database__DB_TYPE=sqlite3` | baza turi; production'da PostgreSQL |
| `GITEA__server__ROOT_URL` | tashqi URL: klon havolalari va webhook'lar shundan yasaladi |
| `GITEA__server__SSH_PORT` | klon havolasida ko'rsatiladigan SSH port (host tomondagi port) |
| `GITEA__security__INSTALL_LOCK=true` | birinchi ishga tushishdagi web o'rnatish sahifasini o'chiradi |
| `GITEA__service__DISABLE_REGISTRATION=true` | ochiq ro'yxatdan o'tishni yopadi |
| `GITEA__migrations__ALLOW_LOCALNETWORKS=true` | lokal tarmoq manzillaridan migratsiya va mirror'ga ruxsat (default taqiqlangan) |

### Misol: compose faylining shakli

Quyida boshqa dastur (`nginx` web serveri) uchun ataylab soddalashtirilgan fayl, Gitea'niki shu shaklda, lekin o'z qiymatlari bilan (9-vazifa; to'liq namunasi Manbalardagi "Install with Docker" sahifasida):

```
services:
  web:
    image: nginx:1.27              # pinned version, never "latest"
    environment:
      - TZ=Asia/Tashkent           # KEY=value passed into the container
    volumes:
      - web-data:/usr/share/nginx/html
    ports:
      - "127.0.0.1:8080:80"        # host 127.0.0.1:8080 -> container port 80
volumes:
  web-data:                        # named volume, managed by Docker
```

`services` ostidagi har kalit bitta konteyner; `volumes` (pastdagi) nomlangan volume'ni e'lon qiladi, servis ichidagi `volumes` uni konteyner yo'liga ulaydi. Gitea uchun ikki port chiqariladi: `3000` (web) va konteynerdagi `22` host'ning `2222` portiga, chunki host'ning o'z `22` porti band bo'lishi mumkin. Image versiyasini rasmiy sahifadagi joriy stable'dan oling va aniq yozing (`gitea/gitea:<versiya>`).

Ko'tarilgandan keyin:

```
$ docker compose ps
NAME      IMAGE                    COMMAND   SERVICE   CREATED   STATUS         PORTS
<name>    gitea/gitea:<versiya>    "<...>"   gitea     <...>     Up <N> minutes 127.0.0.1:2222->22/tcp, 127.0.0.1:3000->3000/tcp
$ curl -s http://localhost:3000/api/v1/version
{"version":"<versiya>"}
```

`STATUS` ustunida `Up` konteyner ishlayotganini, `PORTS` qaysi host manzili qaysi konteyner portiga ulanganini ko'rsatadi: bu yerda `127.0.0.1` turishi shart, `0.0.0.0` chiqsa port tashqi tarmoqqa ochiq. `curl` javobi Gitea API'si tirikligini bildiradi. Administrator CLI orqali yaratiladi (buyruq konteyner ichida `git` foydalanuvchisi nomidan ishlashi shart):

```
docker compose exec -u git gitea gitea admin user create \
  --username labadmin --password '<password>' --email lab@example.com --admin
```

`docker compose exec <servis> <buyruq>` ishlab turgan konteyner ichida buyruq bajaradi; birinchi `gitea` servis nomi, ikkinchisi dastur. SSH bilan klon: `ssh://git@localhost:2222/<user>/<repo>.git`. API hujjati instansiyaning o'zida: `/api/swagger`. Volume qayerda turganini `docker volume inspect <volume>` ko'rsatadi (`Mountpoint`): Zorin'da bu host diskidagi haqiqiy yo'l, macOS'da Docker Desktop VM'i ichidagi yo'l, host'dan ochilmaydi.

### Mirroring

Mirror bu reponing barcha ref'lari bilan aynan nusxasi. `git clone --mirror` bare repo yaratadi va uning refspec'i (3-dars) hamma narsani qamraydi:

```
$ git clone --mirror <src-url> demo.git
$ git -C demo.git config --get remote.origin.fetch
+refs/*:refs/*
$ git -C demo.git config --get remote.origin.mirror
true
```

Oddiy klonda refspec `+refs/heads/*:refs/remotes/origin/*` edi: faqat branch'lar, ular ham `origin/` ostiga. Mirror'da `refs/*` aynan `refs/*` ga tushadi: branch, tag va boshqa barcha ref'lar o'z nomi bilan.

| Usul | Qanday | Qachon |
|------|--------|--------|
| bir martalik ko'chirish | `git clone --mirror <src>`, keyin `git push --mirror <dst>` | hostingdan hostingga migratsiya |
| pull mirror | Gitea: "New Migration", "This repository will be a mirror". Gitea manbadan davriy `fetch` qiladi, repo read-only | tashqi reponing ichki nusxasi, zaxira |
| push mirror | Gitea: repo Settings, "Mirror Settings". Har o'zgarish tashqi remote'ga yuboriladi | asosiy repo ichkarida, tashqarida ochiq nusxa |
| ikki push URL | `git remote set-url --add --push origin <url>` | qo'lda, kichik loyihalar |

**Tuzoq: `git push --mirror` manbada yo'q ref'larni nishonda o'chiradi.** Uni faqat bo'sh yoki aynan mirror uchun mo'ljallangan repoga qarating. Mirror zaxira o'rnini to'liq bosmaydi: manbadagi xato (force push, o'chirilgan branch) ham sodiqlik bilan ko'chiriladi.

### Real ishda qachon kerak

- Kichik jamoa yoki uy serveri uchun yengil Git hosting; GitHub repolarining ichki nusxasi.
- Yopiq tarmoqdagi build serveri tashqi kutubxona repolarini pull mirror orqali oladi.
- Production'da qo'shiladigan narsalar: tashqi baza (PostgreSQL), TLS'li reverse proxy, backup (`gitea dump` yoki volume va baza nusxasi) va tiklash sinovi, versiya yangilash tartibi.

### Nima uchun shunday

Gitea Go'da yozilgani uchun bitta statik binar: runtime, alohida navbat yoki kesh servisi shart emas, shu sabab kichik serverda ham ishlaydi. Konfiguratsiyaning muhit o'zgaruvchilari orqali berilishi konteyner dunyosidagi odat: image o'zgarmaydi, muhitga xos qiymatlar tashqaridan keladi (Node'dagi `process.env` va `.env` bilan bir xil g'oya). Image tag'ini aniq yozish `package-lock.json` vazifasini bajaradi: `latest` bugun bir versiya, ertaga boshqa, baza migratsiyasi esa orqaga qaytmaydi.

## 6. GitLab self-managed: tuzilishi

### Bitta dastur emas

GitLab komponentlar to'plami. Linux package (Omnibus) ularni bitta paketga yig'adi:

| Komponent | Vazifasi |
|-----------|----------|
| NGINX, Workhorse | kiruvchi HTTP, katta yuklamalar (git over HTTP, fayllar) |
| Puma (Rails) | web UI va API |
| Sidekiq | fon vazifalari (email, webhook, pipeline hodisalari) |
| Gitaly | Git repolariga kirish qatlami: barcha git amallari shu orqali |
| GitLab Shell | SSH orqali git |
| PostgreSQL, Redis | metadata bazasi; kesh, navbat, sessiyalar |
| GitLab Runner | CI job'larni bajaradi, **alohida** o'rnatiladi va serverda turmasligi kerak |

### Mexanizm: so'rov yo'li

Brauzerdan kelgan sahifa so'rovi: NGINX qabul qiladi, Workhorse orqali Puma'ga (Rails ilovasi) o'tadi, Puma PostgreSQL'dan metadata'ni, Gitaly'dan repo ma'lumotini oladi. Asosiy g'oya: Rails diskdagi repoga o'zi tegmaydi, har Git amali Gitaly'ga RPC (tarmoq orqali funksiya chaqiruvi) bilan boradi. Sekin ishlar (email, webhook yuborish) so'rov ichida bajarilmaydi: Redis'dagi navbatga yoziladi va ularni Sidekiq fonda bajaradi. Node dunyosidagi o'xshashi: API server va BullMQ kabi navbat ishchisi alohida jarayonlar.

### Boshqaruv

```
sudo gitlab-ctl status          # every component with its state and pid
sudo gitlab-ctl reconfigure     # apply /etc/gitlab/gitlab.rb
sudo gitlab-ctl tail            # follow logs of all components
sudo gitlab-backup create       # repositories and database
```

- Sozlash bitta faylda: `/etc/gitlab/gitlab.rb`. Faylni tahrirlash o'zi hech narsani o'zgartirmaydi, `reconfigure` undan har komponentning konfiguratsiyasini qayta yasaydi.
- O'rnatish usullari: Linux package, Docker image (`gitlab/gitlab-ce`), Kubernetes uchun Helm chart.
- Backup ikki qism: `gitlab-backup create` va alohida saqlanadigan `/etc/gitlab/gitlab-secrets.json` bilan `gitlab.rb`. Secrets faylisiz backup'dagi shifrlangan ma'lumot (CI o'zgaruvchilari, 2FA) o'qilmaydi.
- Yangilash faqat belgilangan upgrade path bo'ylab: versiyalarni sakrab o'tib bo'lmaydi.

Bu buyruqlarni bu darsda ishga tushirmaysiz, ular GitLab serverida ishlaydi; maqsad hujjatni o'qiganda nima nima ekanini ajrata olish.

### Real ishda qachon kerak

- GitLab self-managed ishlatadigan kompaniyada "GitLab sekin" degan shikoyatni komponentga bog'lash: sahifa sekinmi (Puma), push sekinmi (Gitaly, disk), pipeline boshlanmayaptimi (Sidekiq, runner).
- Backup va yangilash rejasini tuzish yoki tekshirish.

### Nima uchun shunday

GitLab Rails monoliti sifatida boshlangan va yuk oshgani sari og'ir qismlar ajratib chiqarilgan: Git amallari Gitaly'ga, katta HTTP yuklamalar Workhorse'ga. Bu har qismni alohida masshtablash imkonini beradi (katta o'rnatishlarda Gitaly alohida serverlarda), narxi esa ko'p harakatlanuvchi qism. Gitea bilan farq aniq: GitLab ko'p imkoniyat beradi va evaziga doimiy ekspluatatsiya ishini talab qiladi.

## 7. Ops muhandis javob beradigan sozlamalar

### Nima uchun bu ops ishi

CI/CD bilan `main` ga tushgan commit avtomatik production'ga boradi. Demak repo sozlamalari production'ga kirish nazorati: `main` ga kim, qanday shart bilan yoza olishi deploy huquqini belgilaydi. Asosiy qoidalar bir-biriga tayanadi.

### Branch protection va rulesets

Mexanizm: har push'da server ref'ni yangilashdan oldin qoidalarni tekshiradi (1-bo'limdagi 3-qadam), har merge tugmasi bosilganda esa PR holatini (tasdiqlar, check'lar). Qoida buzilsa ref o'zgarmaydi. GitHub'dagi klassik branch protection sozlamalari (rasmiy nomlari bilan):

| Sozlama | Nima qiladi |
|---------|-------------|
| Require a pull request before merging | to'g'ridan-to'g'ri push yopiladi, o'zgarish faqat PR orqali |
| Require approvals | kamida N ta tasdiq |
| Dismiss stale pull request approvals when new commits are pushed | yangi commit kelsa eski tasdiqlar bekor bo'ladi |
| Require review from Code Owners | `CODEOWNERS` dagi egalar tasdig'i shart |
| Require status checks to pass before merging | ko'rsatilgan CI check'lar o'tishi shart |
| Require branches to be up to date before merging | PR branch'i `main` ning hozirgi holatini o'z ichiga olishi shart |
| Require linear history | merge commit taqiqlanadi (faqat squash yoki rebase) |
| Do not allow bypassing the above settings | qoidalar adminlarga ham amal qiladi |
| Allow force pushes, Allow deletions | default o'chiq: force push va branch'ni o'chirish taqiqlangan |

Himoyalangan branch'ga to'g'ridan-to'g'ri push qilganda foydalanuvchi ko'radigan javob:

```
$ git push origin main
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: Changes must be made through a pull request.
To github.com:<user>/<repo>.git
 ! [remote rejected] main -> main (protected branch hook declined)
error: failed to push some refs to 'github.com:<user>/<repo>.git'
```

`remote:` bilan boshlangan qatorlar server yozgan matn: `GH006` GitHub'ning xato kodi, ikkinchi qator aynan qaysi qoida buzilganini aytadi. `! [remote rejected]` Git'ning o'z qatori: obyektlar yetib bordi, lekin server ref'ni yangilashdan bosh tortdi; qavs ichida sabab. Bu 3-darsdagi `[rejected] (non-fast-forward)` dan farq qiladi: u yerda tarix mos kelmagan edi, bu yerda siyosat ruxsat bermadi. Qoida ruleset orqali qo'yilgan bo'lsa kod `GH013` ("Repository rule violations found") bo'ladi.

API orqali himoya `PUT /repos/{owner}/{repo}/branches/{branch}/protection` bilan yoziladi. So'rov tanasida to'rt kalit majburiy (`required_status_checks`, `enforce_admins`, `required_pull_request_reviews`, `restrictions`), kerak bo'lmagani `null` bo'ladi; qolgan maydonlar Manbalardagi REST hujjatida. Bitta kalitning shakli:

```
"required_status_checks": {
  "strict": true,
  "contexts": ["lint", "test"]
}
```

`strict` bu "Require branches to be up to date", `contexts` majburiy check nomlari.

GitHub'da ikki mexanizm bor: klassik branch protection va yangiroq rulesets (bir nechta qoida qatlamlanadi, tashkilot darajasida beriladi, kimga bypass berilgani aniq ko'rinadi). GitLab'da "Protected branches" ("Allowed to merge" va "Allowed to push and merge" rol bo'yicha), Gitea'da repo Settings, "Branches" ostidagi branch protection qoidasi.

### CODEOWNERS

Yo'l bo'yicha majburiy reviewer'lar ro'yxati. Fayl GitHub'da `.github/`, repo ildizi yoki `docs/` da; GitLab'da `.gitlab/`, ildiz yoki `docs/` da. Sintaksis `.gitignore` naqshlariga o'xshash (1-dars), har qatorda naqsh va egalar:

```
*              @acme/developers
/infra/        @acme/platform
*.tf           @acme/platform
/.github/      @acme/platform
```

Mexanizm: PR ochilganda hosting o'zgargan har fayl uchun faylni yuqoridan pastga o'qiydi va **oxirgi mos kelgan qator** egalarini reviewer qilib qo'shadi (qoidalar qo'shilmaydi, keyingisi oldingisini bosadi). `infra/main.tf` uchun uchta qator mos keladi, oxirgisi `*.tf`, natija `@acme/platform`. Fayl o'zi hech narsani majburlamaydi: himoyada "Require review from Code Owners" yoqilgandagina kuchga kiradi. CI konfiguratsiyasi va `CODEOWNERS` ning o'zi ham egali bo'lishi kerak, aks holda himoyani PR ichida o'chirib qo'yish mumkin.

### Required checks

Merge'dan oldin o'tishi shart bo'lgan CI job'lar ro'yxati. Status check bu tashqi tizim (CI) commit'ga yozib qo'yadigan "o'tdi" yoki "yiqildi" belgisi. "Branch yangilangan bo'lishi shart" talabi check'ni `main` ning hozirgi holati bilan birga sinashni kafolatlaydi (2-darsdagi semantic conflict). Tuzoq: job nomi o'zgartirilsa, eski nomdagi required check abadiy "kutilmoqda" bo'lib PR'larni bloklaydi.

### Secrets

CI secret'lari hosting'da shifrlangan saqlanadi, saqlangach qiymatini qayta o'qib bo'lmaydi, loglarda maskalanadi.

```
$ gh secret set <NAME>
? Paste your secret: ****
✓ Set Actions secret <NAME> for <user>/<repo>
```

Qiymat interaktiv so'raladi, shuning uchun shell tarixiga tushmaydi; `gh` uni yuborishdan oldin reponing public kaliti bilan shifrlaydi. Darajalar: repo, environment (masalan `production`, tasdiqlovchi bilan), tashkilot. GitLab'da CI/CD variables: "masked" (logda yashiriladi) va "protected" (faqat protected branch va tag'larda ko'rinadi). Fork'dan kelgan PR'ga secret berilmaydi. Uzoq yashaydigan cloud kalitlari o'rniga OIDC orqali qisqa muddatli token olish afzal (CI/CD modulida).

### Qolganlari

Ruxsatlar guruh orqali va eng kam rol bilan; ruxsat etilgan merge usullari (workflow'ga mos, 3-dars); merge'dan keyin branch'ni avtomatik o'chirish; secret scanning va push protection (push ichida token topilsa rad etadi); webhook'lar va ularning secret'i; audit log; default branch nomi.

### Real ishda qachon kerak

- Yangi repo ochilganda: himoya, `CODEOWNERS`, merge usuli va secret'lar birinchi kun qo'yiladi, hodisadan keyin emas.
- Audit (SOC 2, ISO 27001): "production'ga tushgan har o'zgarish boshqa odam tomonidan ko'rilganmi" savoliga javob shu sozlamalar.
- Hodisa tahlili: `main` ga kim, qaysi PR orqali, kimning tasdig'i bilan yozgani.

### Nima uchun shunday

3-darsdagi client hook'lar (`pre-commit`, husky) qulaylik, lekin majburlash emas: ular dasturchi mashinasida ishlaydi va `--no-verify` bilan chetlab o'tiladi. Majburlash faqat serverda mumkin, chunki ref'ni server yangilaydi. Qoidalar bir-birini to'ldiradi: PR talabi review'ni, `CODEOWNERS` to'g'ri reviewer'ni, required checks avtomatik tekshiruvni, adminlarga ham amal qilishi esa istisno yo'qligini kafolatlaydi. Bittasi tushib qolsa qolganlarini aylanib o'tish yo'li ochiladi. Muqobili ishonchga asoslangan jarayon ("hamma PR ochadi deb kelishdik"), u birinchi shoshilinch tuzatishgacha yashaydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Git hosting | bare repolar ustiga identifikatsiya, huquq, PR, siyosat va avtomatlashtirish qo'shadigan servis |
| SaaS | provayder serverida ishlaydigan va tayyor xizmat sifatida beriladigan dastur |
| Self-hosted (self-managed) | o'z serveringizda o'zingiz o'rnatib yuritadigan dastur |
| Vendor lock-in | platformaga xos qatlam (PR, CI, sozlamalar) tufayli ko'chishning qiyinlashishi |
| REST API | HTTP so'rovlar va JSON javoblar orqali ishlaydigan dasturiy interfeys |
| Webhook | hodisa bo'lganda hosting tashqi URL'ga yuboradigan HTTP so'rov |
| Token | parol o'rnida yuboriladigan, hosting bergan tasodifiy satr |
| PAT | personal access token, foydalanuvchi o'z nomidan chiqaradigan token (classic yoki fine-grained) |
| Scope / permission | tokenga berilgan huquq doirasi |
| Deploy key | bitta repoga biriktirilgan SSH public kalit, default read-only |
| Xizmat akkaunti | odamga emas, tizimga tegishli alohida akkaunt |
| Least privilege | ish uchun yetarli eng kam huquqni berish tamoyili |
| Rotation | token yoki kalitni rejali ravishda yangisiga almashtirish |
| Credential helper | Git'ga parol yoki tokenni tizim saqlagichidan olib beradigan mexanizm |
| Image | dastur va unga kerakli fayllar jamlangan o'zgarmas paket |
| Konteyner | image'dan ishga tushirilgan izolyatsiyalangan jarayon |
| Volume | Docker boshqaradigan, konteyner o'chsa ham qoladigan papka |
| Published port | host manzili va portini konteyner portiga ulaydigan yozuv |
| `compose.yaml` | konteynerlar to'plamini tavsiflaydigan Docker Compose fayli |
| SQLite | bitta fayldan iborat, alohida serversiz ma'lumotlar bazasi |
| Mirror | reponing barcha ref'lari bilan aynan nusxasi |
| Pull mirror / push mirror | nusxa manbadan o'zi tortadi / manba nusxaga o'zi yuboradi |
| Gitaly | GitLab'da Git repolariga kirishni ta'minlaydigan RPC servis |
| Runner | CI job'larni bajaradigan alohida mashina yoki jarayon |
| Branch protection | branch'ga push va merge shartlarini serverda majburlaydigan qoidalar |
| Ruleset | GitHub'ning qatlamlanadigan, tashkilot darajasida beriladigan yangi qoida mexanizmi |
| `CODEOWNERS` | yo'l naqshi bo'yicha majburiy reviewer'larni belgilaydigan fayl |
| Status check | CI commit'ga yozadigan "o'tdi" yoki "yiqildi" belgisi |
| Secret | hosting'da shifrlangan saqlanadigan va CI job'ga beriladigan maxfiy qiymat |
| Environment | deploy nishoni (masalan `production`), o'z secret'lari va tasdiqlovchilari bilan |

## Tuzoqlar

- Himoya qoidalari adminlarga amal qilmasa, "shoshilinch" to'g'ridan-to'g'ri push odatga aylanadi va qoida qog'ozda qoladi.
- Xodimning shaxsiy tokeni CI yoki serverda: u ketganda yo deploy to'xtaydi, yo sobiq xodim kirish huquqini saqlab qoladi.
- Keng scope'li, muddatsiz token. Sizib chiqsa butun tashkilot repolari ochiladi.
- Write huquqli deploy key production serverida: buzilgan server reponi ham buzadi.
- `~/.ssh/config` da `IdentitiesOnly yes` yo'q: SSH deploy key o'rniga shaxsiy kalitingiz bilan kiradi va "read-only" sinovi yolg'on natija beradi.
- `CODEOWNERS` bor, lekin himoyada talab yoqilmagan, yoki fayl o'zi egasiz.
- Self-hosted Git serveri backup'siz yoki tiklash sinovisiz. Mirror backup emas.
- `git push --mirror` ni mavjud, ishlatilayotgan repoga qaratish: u yerdagi ortiqcha branch va tag'lar o'chadi.
- Gitea yoki GitLab'ni `latest` tag bilan ishlatish: kutilmagan major yangilanish va baza migratsiyasi.
- Self-hosted instansiyada ochiq ro'yxatdan o'tishni yopmaslik va uni internetga chiqarish.
- `ports` da `HOST_IP` ni yozmaslik: servis mashinaning barcha interfeyslarida ochiladi. Zorin'da Docker chiqargan port `ufw` qoidalarini chetlab o'tadi, chunki Docker o'z iptables qoidalarini yozadi.
- `docker compose down -v` volume'ni ham o'chiradi: Gitea'dagi repolar va foydalanuvchilar qaytmaydi. Dars oxiridagi tozalashdan boshqa joyda `-v` yozmang.
- `ROOT_URL` yoki `SSH_PORT` haqiqiy tashqi manzilga mos emas: UI ishlaydi, lekin ko'rsatilgan klon havolalari ishlamaydi.
- Public repoda himoyani sinab, keyin repo private'ga o'tkazilganda tarif tufayli qoidalar jimgina ishlamay qolishi. Tarif cheklovlarini oldindan tekshiring.

## Manbalar

- https://cli.github.com/manual/ – `gh` qo'llanmasi
- https://docs.github.com/en/rest/branches/branch-protection – branch protection REST API (`protection.json` maydonlari)
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches – branch protection sozlamalari
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets – rulesets
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners – CODEOWNERS
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens – tokenlar
- https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys – deploy key va mashina kirishi
- https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions – secret'lar
- https://git-scm.com/docs/git-clone – `--mirror` va `--bare`
- https://git-scm.com/docs/git-push – `--mirror`, bir nechta push URL
- https://git-scm.com/docs/gitcredentials – credential helper'lar
- https://git-scm.com/docs/githooks – `pre-receive` va boshqa server hook'lari
- https://docs.gitea.com/installation/install-with-docker – Gitea'ni Docker bilan o'rnatish (majburiy)
- https://docs.gitea.com/administration/config-cheat-sheet – `app.ini` sozlamalari
- https://docs.gitea.com/administration/command-line – `gitea admin` buyruqlari
- https://docs.gitea.com/usage/repo-mirror – Gitea mirroring
- https://docs.gitea.com/administration/backup-and-restore – Gitea backup
- https://docs.docker.com/reference/compose-file/ – `compose.yaml` formati
- https://docs.gitlab.com/install/ – GitLab o'rnatish usullari va talablar
- https://docs.gitlab.com/development/architecture/ – GitLab arxitekturasi
- https://docs.gitlab.com/user/project/codeowners/ – GitLab Code Owners
- https://support.atlassian.com/bitbucket-cloud/ – Bitbucket Cloud hujjatlari

## Birga bajaramiz

Hosting qiladigan ishning eng kichik modelini o'z qo'limiz bilan, tarmoqsiz va Docker'siz quramiz: bare repo "server", undagi `pre-receive` hook "branch protection", ikkinchi bare repo esa "zaxira hosting". Hammasi host'da, ikkala mashinada bir xil. Bu vazifalardagi holatlarning hech biri emas, lekin ularning ortidagi mexanizmni ko'rsatadi.

1. Ikki "server" va bitta ishchi klon:

```
$ mkdir -p ~/git-lab/04/mini && cd ~/git-lab/04/mini
$ git init -q --bare -b main server.git
$ git init -q --bare -b main backup.git
$ git clone server.git work && cd work
Cloning into 'work'...
warning: You appear to have cloned an empty repository.
done.
$ echo v1 > app.conf && git add app.conf && git commit -q -m "Add app.conf"
$ git push -u origin main
To <path>/server.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

`--bare` working tree'siz repo yaratadi (3-dars), `-b main` boshlang'ich branch nomi. Hozircha `server.git` hamma narsani qabul qiladi: unda siyosat yo'q.

2. Serverga siyosat qo'shamiz. `server.git/hooks/pre-receive` fayli:

```
#!/bin/sh
# stdin: one line per pushed ref: <old-sha> <new-sha> <ref-name>
while read -r old new ref; do
  if [ "$ref" = "refs/heads/main" ]; then
    echo "POLICY: direct push to main is not allowed, push a branch" >&2
    exit 1
  fi
done
```

Keyin `chmod +x ../server.git/hooks/pre-receive`. Git serverda obyektlarni qabul qilgach, ref'larni yangilashdan oldin shu skriptni ishga tushiradi va unga har ref uchun bir qator beradi. Skript noldan farqli kod bilan chiqsa butun push rad etiladi.

3. `main` ga to'g'ridan-to'g'ri push:

```
$ echo v2 > app.conf && git commit -q -am "Change app.conf"
$ git push origin main
remote: POLICY: direct push to main is not allowed, push a branch
To <path>/server.git
 ! [remote rejected] main -> main (pre-receive hook declined)
error: failed to push some refs to '<path>/server.git'
```

`remote:` qatori hook'ning `stderr` ga yozgan matni, Git uni mijozga olib keldi. `! [remote rejected] ... (pre-receive hook declined)` shakli 7-bo'limdagi GitHub javobi bilan bir xil: u yerda qavs ichida `protected branch hook declined` edi. Hosting'dagi branch protection shu mexanizmning foydalanuvchi va rollarni biladigan, UI'dan sozlanadigan ko'rinishi.

4. Branch orqali esa o'tadi:

```
$ git switch -c feature/conf
Switched to a new branch 'feature/conf'
$ git push -u origin feature/conf
To <path>/server.git
 * [new branch]      feature/conf -> feature/conf
branch 'feature/conf' set up to track 'origin/feature/conf'.
```

Hook faqat `refs/heads/main` ni tekshiradi. Haqiqiy hosting'da keyingi qadam PR bo'lardi: `main` ni foydalanuvchi emas, server o'zi merge qilib yangilaydi.

5. Ikkinchi hosting'ga bir vaqtda yuborish (5-bo'lim jadvalidagi "ikki push URL"):

```
$ git remote set-url --add --push origin ~/git-lab/04/mini/server.git
$ git remote set-url --add --push origin ~/git-lab/04/mini/backup.git
$ git remote -v
origin	<path>/server.git (fetch)
origin	<path>/server.git (push)
origin	<path>/backup.git (push)
```

Birinchi `--add --push` aniq push URL'ni yozadi (shu paytgacha u fetch URL'dan olinar edi), ikkinchisi yana bittasini qo'shadi. Endi bitta `fetch` manzili va ikkita `push` manzili bor.

6. Push va ikki tomonni solishtirish:

```
$ echo v3 >> app.conf && git commit -q -am "Extend app.conf"
$ git push origin feature/conf
To <path>/server.git
   <sha1>..<sha2>  feature/conf -> feature/conf
To <path>/backup.git
 * [new branch]      feature/conf -> feature/conf
$ git ls-remote ../server.git
<sha0>	HEAD
<sha2>	refs/heads/feature/conf
<sha0>	refs/heads/main
$ git ls-remote ../backup.git
<sha2>	refs/heads/feature/conf
```

Bitta `git push` ikki `To` bloki chiqardi: har push URL'ga alohida. `server.git` da branch bor edi (`<sha1>..<sha2>` yangilandi), `backup.git` da yo'q edi (`[new branch]`). `ls-remote` farqni ko'rsatadi: `backup.git` da `main` yo'q, chunki u yerga faqat siz push qilgan ref bordi. Bu usul mirror emas: aynan nusxa uchun `clone --mirror` va `push --mirror` kerak.

7. Tozalash: `cd ~ && rm -rf ~/git-lab/04/mini`.

Shu 7 qadamda ko'rganingiz: hosting ichida bare repo yotadi va huquq qatlami uning ustida (1-bo'lim); bitta klon bir nechta hosting'ga qaray oladi (2-bo'lim); bir necha push URL va mirror farqi (5-bo'lim); siyosat serverda, ref yangilanishidan oldin majburlanadi va rad javobining shakli shundan (7-bo'lim). Token, `gh` va Gitea qismlari (3–5 bo'limlar) vazifalarda.

---

## Vazifalar

Vazifalarni GitHub'dagi sinov repolarida, lokal Gitea'da va `~/git-lab/04/` da bajaring, hamma buyruq host'da (Zorin yoki macOS), Gitea ichidagi buyruqlar `docker compose exec` orqali. Javoblarni `git/04-hostings/README.md` ga yozing (papka `make new m=git n=04 name=hostings` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`compose.yaml`, `CODEOWNERS`, `protection.json`, `RUNBOOK.md`) shu papkaga saqlanadi. Token va parollar hech qayerga yozilmaydi: chiqishdagi qiymatlarni `***` bilan almashtiring. C guruh va 20-vazifani bitta mashinada boshlab o'sha yerda tugating (Gitea holati mashinalar orasida ko'chmaydi, "Laboratoriya" bo'limiga qarang); qolgan vazifalar GitHub'da, istalgan mashinadan davom ettiriladi.

### A. Taqqoslash va gh CLI

1. **Hosting choice.** Uch vaziyat uchun hosting tanlang va 4–6 gapda asoslang (model, CI, narx modeli, ekspluatatsiya yuki bo'yicha): (a) 8 kishilik startap, hammasi cloud'da; (b) bank, kod tashqi tarmoqqa chiqishi taqiqlangan, 200 dasturchi; (c) uyingizdagi server, shaxsiy loyihalar va GitHub repolarining zaxirasi. Har birida self-hosting'ning yashirin xarajatlarini sanang. Yo'nalish: 2-bo'lim, "SaaS yoki self-hosted" va "Nima uchun shunday".

2. **gh auth.** `gh auth status` chiqishini (tokenni yashirib) yozing: qaysi akkaunt, qaysi protokol, qaysi scope'lar. Token qayerda saqlanadi? `gh api user --jq .login` va `gh api rate_limit --jq .resources.core` nima qaytaradi? Skriptda interaktiv login'siz `gh` qanday autentifikatsiya qilinadi? Yo'nalish: 3-bo'lim, "Mexanizm" va "Misol: holat va xom API".

3. **Repo from the terminal.** Faqat `gh` bilan (brauzersiz): `git-lab-04` public repo yarating va klon qiling, branch oching, commit qiling, PR yarating, PR holati va diff'ini ko'ring, squash merge qilib branch'ni o'chiring. Har qadam buyrug'ini yozing. `gh pr checkout` 3-darsdagi `refs/pull/<N>/head` bilan qanday bog'liq? Yo'nalish: 3-bo'lim, "Buyruqlar xaritasi"; 1-bo'lim, "Misol: PR Git'ga emas, hosting'ga tegishli".

4. **Raw API.** `gh api` bilan: reponing ruxsat etilgan merge usullarini o'qing, `gh repo edit` bilan faqat squash merge'ni qoldiring va merge'dan keyin branch avtomatik o'chishini yoqing, natijani API orqali tasdiqlang. UI o'rniga API ishlatishning ops uchun foydasi nima? Yo'nalish: 3-bo'lim, "Misol: holat va xom API"; flag'lar `gh repo edit --help` da.

### B. Token va deploy key

5. **Fine-grained token.** Faqat `git-lab-04` ga, faqat "Contents: read" huquqli, 7 kunlik fine-grained token yarating. `GH_TOKEN` orqali shu token bilan: repo tarkibini o'qing (ishlashi kerak), issue yarating va boshqa private repongizni o'qing (ikkalasi rad etilishi kerak; private repo bo'lmasa vaqtinchalik bo'sh repo oching). HTTP status kodlarini yozing va public repo nima uchun bu sinovga yaramasligini izohlang. Classic token'dagi `repo` scope bundan nimasi bilan xavfliroq? Status kodini `gh api -i` ko'rsatadi; tokenni buyruq satriga yozmang (`read -rs`). Yo'nalish: 4-bo'lim, "Mexanizm" va "Misol: bir xil so'rov, uch xil identifikator".

6. **Token in the URL.** Scratch katalogda `git clone https://<token>@github.com/...` qiling (5-vazifadagi token bilan). Token qayerlarda iz qoldirdi (`.git/config`, shell tarixi)? Tokenni bekor qiling va bekor bo'lganini tekshiring. To'g'ri usullarni sanang. Shell tarixi fayli Zorin'da ham, macOS'da ham `zsh` bo'lsa `~/.zsh_history`, `bash` bo'lsa `~/.bash_history`. Yo'nalish: 4-bo'lim, "Qoidalar".

7. **Deploy key.** Alohida SSH kalit yaratib `git-lab-04` ga read-only deploy key qilib qo'shing (`gh repo deploy-key add`). `~/.ssh/config` da alohida `Host` alias orqali aynan shu kalit bilan klon qiling, keyin push qilib ko'ring va xatoni yozing. Shu kalitni ikkinchi repoga qo'shib ko'ring: nima bo'ldi? Bir server 3 ta reponi tortishi kerak bo'lsa qanday sozlaysiz? Ikkinchi mashinada bu vazifani takrorlamoqchi bo'lsangiz yangi kalit yarating, private kalitni ko'chirmang. Yo'nalish: 4-bo'lim, `~/.ssh/config` misoli.

8. **Machine identity.** Jadval tuzing: deploy key, fine-grained PAT, CI ichki tokeni, alohida xizmat akkaunti. Ustunlar: kimga bog'langan, doirasi, muddati, xodim ketganda nima bo'ladi, qachon ishlatiladi. Production serveri konfiguratsiya reposini `pull` qilishi uchun qaysi birini tanlaysiz va nima uchun? Yo'nalish: 4-bo'lim, jadval va "Qoidalar".

### C. Gitea

9. **Compose up.** Gitea uchun `compose.yaml` yozing: versiyasi belgilangan image, nomlangan volume, portlar faqat `127.0.0.1` da, SQLite, o'rnatish sahifasi o'chirilgan, ochiq ro'yxatdan o'tish yopiq. Ko'taring, `docker compose ps` va `curl` bilan API versiyasini ko'rsating. Portni `0.0.0.0` ga bog'lash ish mashinasida nimani anglatadi? Faylni ish papkasiga saqlang. `3000` port band bo'lsa host tomondagi portni almashtiring; image `amd64` (Zorin) va `arm64` (macOS) uchun bir xil tag. Yo'nalish: 5-bo'lim, "Docker atamalari" va "Misol: compose faylining shakli".

10. **Admin and users.** CLI orqali admin yarating, UI'da ikkinchi oddiy foydalanuvchi va `platform` tashkilotini oching. Admin CLI buyrug'ini `-u git` siz ishga tushirib ko'ring va xatoni yozing. Ro'yxatdan o'tish yopiqligini tekshiring. Yo'nalish: 5-bo'lim, "Misol: compose faylining shakli" (admin CLI buyrug'i).

11. **SSH and HTTPS access.** Gitea'da repo yarating. Unga ikki yo'l bilan push qiling: SSH (port `2222`, public kalit akkauntga qo'shilgan) va HTTP (parol o'rnida scope'i cheklangan access token). `GITEA__server__SSH_PORT` noto'g'ri bo'lsa UI'dagi klon havolasi qanday ko'rinadi va nima buziladi? Yo'nalish: 5-bo'lim, "Gitea ichida nima bor"; 2-bo'lim, "Misol: bitta repo, ikki hosting".

12. **Data survives.** `docker compose down` (volume'siz) va `up -d` qiling: repo va foydalanuvchilar joyidami? Volume ichida repolar, baza va `app.ini` qayerda joylashganini `docker compose exec` bilan toping. `down -v` nima qilgan bo'lardi? Bundan backup uchun qanday xulosa chiqadi? Zorin'da qo'shimcha: `docker volume inspect` ko'rsatgan `Mountpoint` ni `sudo ls` bilan ko'ring; macOS'da bu yo'l Docker Desktop VM'i ichida, host'dan ochilmaydi. Yo'nalish: 5-bo'lim, "Docker atamalari" va "Gitea ichida nima bor".

13. **One-time migration.** `git-lab-04` ni `git clone --mirror` va `git push --mirror` bilan Gitea'dagi bo'sh repoga ko'chiring. Branch va tag'lar o'tganini `git ls-remote` bilan ikki tomonda solishtiring. Nima ko'chmadi (PR, sozlamalar, deploy key)? `refs/pull/*` ref'lari bilan nima bo'ldi? Yo'nalish: 5-bo'lim, "Mirroring".

14. **Pull mirror.** Gitea'da GitHub'dagi ochiq reponing pull mirror'ini yarating. GitHub tomonda yangi commit qiling, Gitea'da qo'lda sinxronlashni ishga tushirib commit kelganini ko'rsating. Mirror repoga push qilib ko'ring, xatoni yozing. Default sinxronlash oralig'i qancha va uni qayerda o'zgartirasiz? Yo'nalish: 5-bo'lim, "Mirroring" jadvali va Manbalardagi "Gitea mirroring" sahifasi.

15. **Mirror is not backup.** 13-vazifadagi juftlikda manba repoda branch'ni o'chiring va tag'ni force bilan ko'chiring, keyin yana `push --mirror` qiling. Gitea tomonda nima bo'ldi? Haqiqiy backup mirror'dan nimasi bilan farq qilishi kerak? Gitea uchun backup rejasini 5–6 gapda yozing (nima, qanchalik tez-tez, qayerga, tiklash qanday sinaladi). Yo'nalish: 5-bo'lim, "Mirroring" va "Real ishda qachon kerak".

16. **GitLab on paper.** GitLab arxitektura hujjatidan foydalanib, `git push` (SSH orqali) so'rovining yo'lini komponentma-komponent yozing: qaysi komponent qabul qiladi, huquqni kim tekshiradi, diskka kim yozadi, pipeline'ni kim ishga tushiradi. Runner nima uchun GitLab serverining o'zida turmasligi kerak? Backup'da `gitlab-secrets.json` nima uchun alohida saqlanadi? Yo'nalish: 6-bo'lim, "Mexanizm: so'rov yo'li" va "Boshqaruv".

### D. Repo sozlamalari

17. **Branch protection as code.** `git-lab-04` ning `main` branch'i uchun himoyani `protection.json` fayli va `gh api -X PUT` orqali o'rnating: PR majburiy, force push va o'chirish taqiqlangan, chiziqli tarix, qoidalar adminga ham amal qiladi. `gh api` bilan o'qib tasdiqlang. To'g'ridan-to'g'ri push va force push'ni sinab, server javoblarini yozing. Faylni ish papkasiga saqlang. Yo'nalish: 7-bo'lim, "Branch protection va rulesets"; maydonlar Manbalardagi REST hujjatida.

18. **CODEOWNERS.** `git-lab-04` da `infra/`, `src/`, `.github/` kataloglari va `CODEOWNERS` yarating (egasi sifatida o'z akkauntingiz). Qoidalar tartibini almashtirib "oxirgi mos kelgan ustun" ekanini PR'da ko'rsating. Himoyada code owner review talabini yoqing. Yakka akkaunt bilan o'z PR'ingizni tasdiqlay olasizmi, bu nimani ko'rsatadi? `CODEOWNERS` ning o'zi nima uchun egali bo'lishi kerak? Yo'nalish: 7-bo'lim, "CODEOWNERS".

19. **Secrets.** `gh secret set` bilan repo secret va `production` environment secret yarating (soxta qiymat). `gh secret list` nimani ko'rsatadi, qiymatni qayta o'qib bo'ladimi? Hujjatdan toping va yozing: fork'dan kelgan PR secret'ni ko'radimi, environment'ga "required reviewers" qo'yilsa nima o'zgaradi, secret logga chiqsa nima bo'ladi. Yo'nalish: 7-bo'lim, "Secrets".

20. **Protection on Gitea.** Xuddi shu siyosatni Gitea'dagi repoda UI orqali takrorlang: `main` himoyasi (push taqiqi, PR majburiy, kamida 1 tasdiq) va ikkinchi foydalanuvchi bilan to'liq PR oqimi (biri ochadi, ikkinchisi tasdiqlaydi). To'g'ridan-to'g'ri push'ga server javobini yozing. GitHub'dagi sozlamalar bilan farqlarni jadvalga soling. Yo'nalish: 7-bo'lim, "Branch protection va rulesets"; "Birga bajaramiz", 3-qadam.

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

    README'da har talab qanday bajarilganini buyruq va natija bilan ko'rsating. Yo'nalish: butun modul (1–4 darslar).

### Topshirish

Tayyor bo'lgach:
1. `git/04-hostings/README.md` da 21 ta vazifa, har biri `## N. Title` sarlavhasi ostida; har javobda qaysi mashinada (Zorin yoki macOS) bajarilgani ko'rinadi.
2. `compose.yaml`, `CODEOWNERS`, `protection.json`, `RUNBOOK.md` ish papkasida, `make check` toza.
3. Token, parol va private kalit hech bir faylda yo'q.
4. Tozalangan: `docker compose down -v` (`docker volume ls` va `docker ps -a` bilan tekshirilgan), `~/git-lab/04`, GitHub'dagi sinov repolari, tokenlar va deploy key'lar (`gh repo deploy-key list`, token sahifasi bilan tekshirilgan), `~/.ssh/config` dagi sinov `Host` taxalluslari va sinov kalitlari. Ikkala mashinada ham ishlagan bo'lsangiz, ikkalasida.
5. Menga xabar bering, tekshiraman. Bu modulning oxirgi darsi: qabul qilingach modul yopiladi.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Hostinglar orasida reponi ko'chirganda nima oson o'tadi, nima alohida ish talab qiladi?
- `git push` so'rovi hosting ichida qaysi bosqichlardan o'tadi va branch himoyasi qaysi bosqichda ishlaydi?
- SaaS va self-hosted tanlovida qaysi omillar hal qiluvchi? "Bepul" nima uchun yetarli sabab emas?
- `gh` va `git` orasidagi chegara qayerda? Sozlamani UI o'rniga API orqali qo'yish nimani beradi?
- Deploy key, fine-grained token va CI ichki tokeni qachon ishlatiladi? Nima uchun xodimning shaxsiy tokeni serverga qo'yilmaydi?
- HTTP `401`, `403` va `404` javoblari token haqida nimani aytadi?
- Image, konteyner va volume farqi nima? Gitea ma'lumoti qaysi birida yashaydi va `down -v` nimani o'chiradi?
- Portni `127.0.0.1` ga bog'lash bilan bog'lamaslik orasidagi farq nima? macOS va Zorin'da Docker'ning qaysi farqi bu darsda sezildi?
- `git clone --mirror` oddiy klondan nimasi bilan farq qiladi va `push --mirror` nima uchun xavfli?
- Pull mirror va push mirror farqi nima? Mirror nima uchun backup emas?
- GitLab self-managed qaysi asosiy komponentlardan iborat va Gitea'ga nisbatan ekspluatatsiya narxi nima uchun yuqori?
- Branch protection, `CODEOWNERS` va required checks bir-birini qanday to'ldiradi? Bittasi yo'q bo'lsa qanday tuynuk qoladi?
- Client hook (`pre-commit`) va server tomondagi himoya farqi nima, nima uchun majburlash faqat serverda mumkin?
- CI secret'lari qayerda saqlanadi va fork'dan kelgan PR'ga nima uchun berilmaydi?
- Repoga yozish huquqi nima uchun production'ga kirish huquqi bilan teng deb qaraladi?
