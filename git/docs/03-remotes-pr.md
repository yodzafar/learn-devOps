# 3-dars: Remote va pull request

Maqsad: lokal repo bilan server orasida aynan nima almashilishini (ref'lar va obyektlar) ichkaridan ko'rish va shu asosda jamoa ishini tashkil qilish: remote va refspec, remote-tracking ref, `fetch` va `pull` farqi, upstream, push nima uchun rad etilishi, xavfsiz force push, SSH kalit va commit imzosi, fork, pull request, workflow tanlovi, branch himoyasi va hook'lar. 1 va 2-darslarda tarix bitta `.git` ichida edi, endi u bir nechta nusxada yashaydi va "tarixni qayta yozish" (2-dars, rebase) boshqalarga ta'sir qiladi. `git push`, `git pull` va PR tugmasini har kuni ishlatasiz, bu darsda ular ortida qaysi ref qayerda ko'chishini ko'rasiz. 4-darsda shu tushunchalar aniq hostinglar sozlamalariga aylanadi, CI/CD modulida esa pipeline'lar aynan shu yerdagi hodisalardan (push, PR, tag) ishga tushadi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh, ikkinchi kun 3-bo'lim va B guruh, uchinchi kun 4-bo'lim va C guruh (ikkala mashinada kalit sozlash vaqt oladi), to'rtinchi kun 5–6 bo'limlar va D guruh, beshinchi kun 7-bo'lim, "Birga bajaramiz", E guruh va README'ni tartibga solish. Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: `origin/main` lokal ref ekani, `fetch` hech qachon lokal branch'ga tegmasligi, push'ning "fast-forward" sharti, `--force-with-lease` aynan nimani solishtirishi, imzo va autentifikatsiya ikki xil narsa ekani, client-side hook nima uchun himoya emasligi.

Qanday o'qish kerak: har bo'limdagi misolni `~/git-lab/03/demo/` ichida o'zingiz terib ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Sizdagi hash'lar, sanalar va yo'llar farq qiladi, darsda ular `<hash>`, `<sana>`, `<yo'l>` bilan belgilangan. Har buyruqdan keyin `git log --oneline --graph --all` va `git branch -vv` ni ishlatish odat bo'lsin: bu darsdagi hamma narsa ref'larning ko'chishi, uni ko'rib turish kerak.

## Laboratoriya

Hamma ish ikkala mashinada host'ning o'zida bajariladi, `lab` VM va Docker kerak emas: Git, SSH klienti va brauzer yetarli. Ikki muhit bor.

**Lokal "server"**: bare repo (working tree'siz repo, 1-bo'lim) va ikki klon ikki dasturchini imitatsiya qiladi. Tarmoq va akkaunt kerak emas, A va B guruh vazifalari shu yerda.

```
mkdir -p ~/git-lab/03 && cd ~/git-lab/03
git init --bare -b main server.git
git clone server.git alice && git clone server.git bob
git -C alice config user.name "Alice" && git -C alice config user.email "alice@example.com"
git -C bob config user.name "Bob" && git -C bob config user.email "bob@example.com"
```

`git -C <papka>` buyruqni o'sha papkada bajaradi, `git config` `--global` siz yozilgani uchun sozlama faqat shu klonning `.git/config` iga tushadi. Bo'sh repodan klon qilinganda `warning: You appear to have cloned an empty repository.` chiqadi, bu normal. Eski Git'da bo'sh klon `master` da ochilishi mumkin (`git status` birinchi qatorida ko'rinadi): unda birinchi commit'dan oldin `git symbolic-ref HEAD refs/heads/main` bajaring.

**GitHub**: shaxsiy akkauntingizda `git-lab-03` nomli repo (C, D guruhlar va 21–22-vazifalar). Himoya qoidalari bepul tarifda faqat public repoda ishlaydi, shuning uchun repo public bo'lsin va unga hech qanday haqiqiy ma'lumot tushmasin. `gh` CLI 4-darsda o'rganiladi, bu darsda web UI yetarli.

Bu darsda birinchi marta kerak bo'ladigan asbob `pre-commit` (E guruh), foydalanuvchi darajasida o'rnatiladi:

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `pre-commit` | `sudo apt install pipx`, `pipx ensurepath`, yangi terminalda `pipx install pre-commit` | `brew install pre-commit` |
| Tekshirish | `pre-commit --version` | `pre-commit --version` |

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Git 2.43 (`apt`), darsdagi hamma flag bor. SSH kalit passphrase'ini `ssh-agent` seans davomida eslab turadi (`ssh-add`). Desktop seansida agent odatda allaqachon ishlab turadi, `ssh-add -l` bilan tekshiriladi. |
| macOS (uy) | Apple Git (Xcode Command Line Tools) eskiroq bo'lishi mumkin: `git --version` ni tekshiring. Darsda kerak bo'ladigan chegaralar: `--force-if-includes` 2.30, SSH imzo 2.34, `push.autoSetupRemote` 2.37. Versiya past bo'lsa `brew install git` va yangi terminal. Passphrase'ni Keychain'da saqlash mumkin: `ssh-add --apple-use-keychain` va `~/.ssh/config` da `UseKeychain yes` (4-bo'lim). |

Ikki mashina uchun qoidalar:

- **SSH kalit har mashinada alohida.** Private kalit mashinalar orasida ko'chirilmaydi: Zorin'da bitta, Mac'da bitta kalit yaratiladi va ikkalasining public qismi GitHub akkauntiga alohida nom bilan (`zorin-office`, `mac-home`) qo'shiladi. 11 va 13-vazifalarni qaysi mashinada bajarsangiz, o'sha mashinaning kaliti bilan bajarasiz; ikkinchi mashinada faqat kalit yaratish va qo'shish qadamini takrorlash yetarli.
- **Holat ko'chmaydi.** `~/git-lab/03/` har mashinada lokal. A yoki B guruhni bir mashinada boshlasangiz, o'sha yerda tugating yoki ikkinchisida yuqoridagi besh buyruq bilan qaytadan yarating (vazifalar oldingi vazifa holatiga tayanadigan joyda buni o'zi aytadi). GitHub'dagi `git-lab-03` umumiy: ikkinchi mashinada `git clone` qilasiz. Javoblar kurs reposi orqali ko'chadi.
- Bu dars 1 va 2-darslar holatiga tayanmaydi, faqat tushunchalariga: obyekt va SHA (1-dars, 1-bo'lim), reflog (1-dars, 6-bo'lim), branch pointer ekani va fast-forward (2-dars, 1–2 bo'limlar), rebase (2-dars, 3-bo'lim), tag (2-dars, 6-bo'lim).

Tozalash: `rm -rf ~/git-lab/03`, GitHub'da fork'ni va (4-darsda kerak bo'lmasa) `git-lab-03` ni o'chirish. O'z SSH kalitingiz akkauntda qolsa bo'ladi, sinov uchun qo'shilgan ortiqcha kalitlarni olib tashlang.

---

## 1. Remote va remote-tracking ref

### Bu nima

**Remote** bu boshqa reponing nomi va manzili (URL), lokal reponing `.git/config` faylida saqlanadi. U ulanish emas va fon jarayoni ham emas: Git serverga faqat siz `fetch`, `pull`, `push`, `ls-remote` yoki `clone` buyrug'ini berganingizda murojaat qiladi, qolgan vaqt hamma narsa lokal. `origin` maxsus so'z emas, bu `git clone` qo'yadigan standart nom.

Serverdagi repo odatda **bare repository**: unda working tree yo'q (1-dars, 2-bo'lim), faqat `.git` ichidagi narsalar bor. Serverda hech kim fayl tahrirlamaydi, u faqat obyekt va ref'larni saqlaydi va almashadi.

### Mexanizm: uch narsa

Klon qilganda Git uchta narsani yaratadi. `~/git-lab/03/demo/` da sinab ko'ring:

```
$ mkdir -p ~/git-lab/03/demo && cd ~/git-lab/03/demo
$ git init --bare -b main hub.git
Initialized empty Git repository in <yo'l>/demo/hub.git/
$ ls hub.git
config  description  HEAD  hooks  info  objects  refs
$ git clone hub.git dev1
Cloning into 'dev1'...
warning: You appear to have cloned an empty repository.
done.
$ cat dev1/.git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	url = <yo'l>/demo/hub.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "main"]
	remote = origin
	merge = refs/heads/main
```

Qatorma-qator:

- `ls hub.git`: bare repoda `.git` papkasi yo'q, uning ichidagi narsalar (`HEAD`, `objects`, `refs`) to'g'ridan-to'g'ri repo ildizida yotadi. Oddiy klonda shu fayllar `dev1/.git/` ichida, yonida esa working tree. Nomdagi `.git` qo'shimchasi bare repo uchun kelishuv, majburiyat emas. Git versiyasiga qarab ro'yxatda qo'shimcha `branches` papkasi ham chiqishi mumkin, u eskirgan va ishlatilmaydi.
- `[core] bare = false`: bu klon working tree'ga ega. `hub.git/config` da shu qator `bare = true`. (macOS'da `[core]` ichida qo'shimcha `ignorecase` va `precomposeunicode` qatorlari bo'ladi, ular fayl tizimi xususiyatlari.)
- `[remote "origin"] url`: birinchi narsa, manzil. Bu yerda lokal yo'l, GitHub'da `git@github.com:user/repo.git` bo'lardi.
- `fetch = +refs/heads/*:refs/remotes/origin/*`: ikkinchi narsa, **refspec** (ref'larni moslashtirish qoidasi, formati `<manba>:<manzil>`). O'qilishi: serverdagi har bir branch (`refs/heads/*`) lokalda `refs/remotes/origin/` ostida shu nom bilan saqlansin. Boshidagi `+` "fast-forward bo'lmasa ham yangilansin" degani, chunki bu nusxa serverni aks ettirishi kerak, server tarixi qayta yozilgan bo'lsa ham.
- `[branch "main"]`: uchinchi narsa, lokal `main` ning **upstream** i (2-bo'lim): u `origin` remote'idagi `refs/heads/main` bilan bog'langan.

### Remote-tracking ref

`refs/remotes/origin/main` (qisqa yozuvi `origin/main`) serverdagi `main` emas. Bu **lokal** ref, ya'ni `.git` ichidagi bitta SHA yozilgan fayl (2-dars, 1-bo'lim): "oxirgi marta server bilan gaplashganimda u yerdagi `main` shu commit'da edi" degan kesh. U faqat `fetch`, `pull` va muvaffaqiyatli `push` paytida yangilanadi. Unga commit qilib bo'lmaydi: `git switch origin/main` detached HEAD beradi (2-dars, 1-bo'lim).

Buni ko'rish uchun `dev1` dan commit push qiling, ikkinchi klon yarating, keyin `dev1` dan yana bir commit yuboring:

```
$ cd dev1 && git config user.name "Dev One" && git config user.email "dev1@example.com"
$ echo one > notes.txt && git add notes.txt && git commit -qm "Add notes"
$ git push -u origin main
To <yo'l>/demo/hub.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
$ cd .. && git clone -q hub.git dev2
$ cd dev1 && echo two >> notes.txt && git commit -qam "Add second note" && git push
To <yo'l>/demo/hub.git
   <hash1>..<hash2>  main -> main
```

Endi `dev2` da, `fetch` qilmasdan:

```
$ cd ../dev2
$ git status -sb
## main...origin/main
$ git rev-parse origin/main
<hash1 to'liq>
$ cat .git/refs/remotes/origin/main
<hash1 to'liq>
$ git ls-remote origin
<hash2 to'liq>	HEAD
<hash2 to'liq>	refs/heads/main
```

- `git status -sb` qisqa formatda branch qatorini beradi: `main...origin/main` va hech qanday `[ahead N]` yoki `[behind N]` yo'q. Git "hammasi teng" deyapti, chunki u lokal `main` ni lokal `origin/main` bilan solishtirdi, serverga bormadi.
- `git rev-parse origin/main` va `cat` bir xil SHA beradi: remote-tracking ref haqiqatan ham `.git` ichidagi oddiy fayl. (Git ref'larni vaqti-vaqti bilan `.git/packed-refs` fayliga jamlaydi; `cat` "No such file" desa, `rev-parse` ga ishoning.)
- `git ls-remote origin` tarmoqqa (bu yerda qo'shni papkaga) boradi va serverdagi ref'larni hozirgi holatida ko'rsatadi: u yerda `main` allaqachon `<hash2>` da. Lokal kesh eskirgan.

### URL turlari

| Ko'rinish | Transport | Autentifikatsiya |
|-----------|-----------|------------------|
| `git@github.com:user/repo.git` | SSH | SSH kalit (4-bo'lim) |
| `https://github.com/user/repo.git` | HTTPS | token, credential helper saqlaydi (4-darsda) |
| `/home/user/repo.git` yoki `file:///home/user/repo.git` | lokal fayl tizimi | fayl ruxsatlari |

Protokol faqat transport: qaysi biri ishlatilsa ham bir xil obyektlar va ref'lar almashiladi. Boshqaruv buyruqlari:

```
git remote -v                       # names and URLs (fetch and push)
git remote add upstream <url>       # one more remote
git remote set-url origin <url>     # change the URL, e.g. HTTPS to SSH
git remote show origin              # branches and tracking state (network call)
```

### Real ishda qachon kerak

- `git status` "up to date" deydi, hamkasb esa "push qildim" deydi: avval `git fetch`, chunki status keshga qaraydi.
- CI yoki deploy serverida klon qaysi URL'dan olinganini `git remote -v` bilan tekshirish; HTTPS'dan SSH'ga o'tish `set-url` bilan, qayta klon kerak emas.
- Repo boshqa hostingga ko'chganda (4-darsda mirroring) faqat URL o'zgaradi, tarix va SHA'lar o'sha.

### Nima uchun shunday

Git taqsimlangan tizim sifatida yaratilgan: har klon to'liq repo va markaziy server texnik jihatdan shart emas. Shuning uchun "server" tushunchasi Git ichida yo'q, faqat "boshqa repo, nomi falon" bor, `origin` shunchaki kelishuv. Remote-tracking ref'lar kesh bo'lgani uchun `log`, `diff`, `status`, `merge` tarmoqsiz va tez ishlaydi. Muqobili markazlashgan tizimlar (Subversion): har `log` va `commit` serverga boradi, tarmoqsiz ish yo'q. Narxi shuki, kesh eskiradi va uni o'zingiz `fetch` bilan yangilaysiz.

## 2. fetch, pull va upstream

### fetch ichkarida nima qiladi

`git fetch` to'rt qadamdan iborat:

1. Serverga ulanadi va uning ref'lari ro'yxatini (nom va SHA) oladi. `git ls-remote` aynan shu ro'yxatni ko'rsatadi.
2. Refspec bo'yicha qaysi ref'lar kerakligini aniqlaydi va server bilan kelishadi: "menda shu commit'lar bor, menga shular kerak".
3. Yetishmayotgan obyektlarni (commit, tree, blob; 1-dars, 1-bo'lim) bitta siqilgan paket (packfile) ko'rinishida yuklab `.git/objects` ga qo'shadi.
4. `refs/remotes/origin/*` ref'larini yangi SHA'larga ko'chiradi.

Lokal branch'lar, index va working tree'ga `fetch` tegmaydi. Shuning uchun u har doim xavfsiz: uni istalgan payt, commit qilinmagan o'zgarishlar bilan ham ishlatish mumkin.

```
$ git fetch
From <yo'l>/demo/hub
   <hash1>..<hash2>  main       -> origin/main
$ git status
On branch main
Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)

nothing to commit, working tree clean
$ cat notes.txt
one
```

- `From ...`: qaysi remote'dan olindi.
- `<hash1>..<hash2>  main -> origin/main`: serverdagi `main` lokal `origin/main` ga yozildi, u `<hash1>` dan `<hash2>` ga ko'chdi. Ikki nuqta (`..`) fast-forward ko'chishni bildiradi. Yangi branch bo'lsa shu joyda `* [new branch]`, server tarixi qayta yozilgan bo'lsa `+ <a>...<b>` va oxirida `(forced update)` turadi.
- `git status` endi haqiqatni aytadi: lokal `main` 1 commit orqada.
- `cat notes.txt` hali bitta qator: working tree o'zgarmagan, yangi commit faqat obyektlar bazasida va `origin/main` da.

Integratsiya alohida qadam. Avval nima kelganini ko'rish mumkin:

```
git log --oneline HEAD..origin/main    # commits the server has and I do not
git diff HEAD...origin/main            # their changes since the common ancestor
git merge --ff-only origin/main        # move local main forward, refuse anything else
```

`A..B` "B dan yetib boriladigan, A dan yetib borilmaydigan commit'lar"; `diff` dagi uch nuqta "merge base'dan (2-dars, 2-bo'lim) B gacha bo'lgan farq".

### pull bu fetch va integratsiya

`git pull` ikki buyruq: `git fetch`, keyin joriy branch'ga upstream'ni qo'shish. Ikkinchi qadam sozlamaga bog'liq:

| Sozlama yoki flag | Ikkinchi qadam |
|-------------------|----------------|
| `pull.rebase false` yoki `--no-rebase` | `git merge` (fast-forward mumkin bo'lsa fast-forward, bo'lmasa merge commit) |
| `pull.rebase true` yoki `--rebase` | `git rebase`: lokal commit'lar upstream uchiga qayta qo'llanadi |
| `pull.ff only` yoki `--ff-only` | faqat fast-forward, aks holda xato bilan to'xtaydi |

Lokal branch va upstream **ajralgan** (diverged: ikkalasida ham ikkinchisida yo'q commit bor) bo'lsa va hech narsa sozlanmagan bo'lsa, Git tanlovni o'zi qilmaydi va `fatal: Need to specify how to reconcile divergent branches.` deb to'xtaydi (yuqorisida uch variantni sanaydigan `hint:` qatorlari bilan). Ajralish bo'lmasa, sozlamasiz ham fast-forward qiladi.

`git fetch --prune` serverda o'chirilgan branch'larning `origin/*` nusxalarini ham o'chiradi (`git config --global fetch.prune true` bilan doimiy). Oddiy `fetch` ularni o'chirmaydi, shuning uchun `git branch -r` da oylar oldin merge qilingan branch'lar to'planib qoladi. Lokal branch'larga `--prune` ham tegmaydi.

### Upstream (tracking)

Lokal branch'ning **upstream** i bu u bog'langan remote-tracking ref, `.git/config` dagi `[branch "<nom>"]` bo'limida saqlanadi (1-bo'limdagi `remote` va `merge` qatorlari). Argumentsiz `git pull` va `git push` qayerga borishni, `git status` esa ahead/behind'ni shundan biladi. `@{u}` yozuvi "joriy branch'ning upstream'i" degani.

```
$ cd ../dev1 && git switch -c draft && echo d > draft.txt && git add . && git commit -qm "Start draft"
$ git push
fatal: The current branch draft has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream origin draft
...
$ git push -u origin draft
To <yo'l>/demo/hub.git
 * [new branch]      draft -> draft
branch 'draft' set up to track 'origin/draft'.
$ git branch -vv
* draft <hash3> [origin/draft] Start draft
  main  <hash2> [origin/main] Add second note
```

- Birinchi `git push` rad etildi: yangi branch'ning `[branch "draft"]` bo'limi yo'q, Git qayerga yuborishni bilmaydi va taxmin qilmaydi.
- `-u` (`--set-upstream`) ikki ish qiladi: push va `.git/config` ga upstream yozuvi. Oxirgi qator shuni tasdiqlaydi.
- `git branch -vv`: har branch uchun uchi, kvadrat qavsda upstream va farq bo'lsa `ahead N`, `behind N`; upstream serverda o'chirilgan va prune qilingan bo'lsa `gone`.

Qo'shimcha: `git branch --set-upstream-to=origin/draft` mavjud branch'ga upstream beradi; `git log @{u}..HEAD` hali yuborilmagan commit'larni ko'rsatadi; `git switch draft` lokalda bunday branch bo'lmasa va aynan bitta remote'da `draft` bo'lsa, lokal branch'ni upstream'i bilan o'zi yaratadi; `git config --global push.autoSetupRemote true` (Git 2.37+) birinchi push'da `-u` ni o'zi qo'yadi.

### Real ishda qachon kerak

- Feature branch'da `git pull --rebase`: tarixda "Merge branch 'x' of ..." commit'lari paydo bo'lmaydi.
- Deploy skriptlari va serverlarda `git pull --ff-only`: serverdagi klon hech qachon o'z commit'iga ega bo'lmasligi kerak, ajralish bo'lsa bu nosozlik belgisi va jim merge yoki yarim yo'lda qolgan conflict o'rniga aniq xato kerak.
- Eng nazoratli yo'l: `fetch`, `log HEAD..origin/main` bilan ko'rish, keyin ongli integratsiya. Katta o'zgarish kelganda (lockfile, migratsiya) nima kirayotganini oldindan bilasiz.

### Nima uchun shunday

`fetch` va integratsiya ajratilgan, chunki birinchisi mexanik va xavfsiz, ikkinchisi esa qaror: merge yoki rebase, hozir yoki keyin. `pull` qulaylik uchun ikkalasini birlashtiradi. Eski Git ajralgan holatda jim merge qilardi va tarixlar tasodifiy merge commit'larga to'lardi; zamonaviy Git'ning tanlovni sizdan talab qilib to'xtashi shu sababdan kiritilgan. Upstream konfiguratsiyada alohida saqlanishi lokal branch nomi serverdagidan farq qilishiga imkon beradi (masalan lokal `fix`, serverda `feature/fix-login`).

## 3. Push va force push

### Push ichkarida nima qiladi

`git push origin draft` ikki ish qiladi: serverda yo'q obyektlarni yuboradi va serverdan "`refs/heads/draft` ni eski SHA'dan yangi SHA'ga ko'chir" deb so'raydi. Muvaffaqiyatli bo'lsa lokal `origin/draft` ham yangilanadi. Push'ning sharti **fast-forward** (2-dars, 2-bo'lim): yangi commit serverdagi hozirgi commit'ning avlodi bo'lishi kerak, ya'ni ref faqat oldinga suriladi va serverdagi hech bir commit ref'siz qolmaydi. Bu shartni standart holatda `git push` ning o'zi tekshiradi va buzilsa yuborishdan bosh tortadi; server uni qo'shimcha majburiy qilishi mumkin (`receive.denyNonFastForwards` sozlamasi yoki hostingdagi branch himoyasi, 6-bo'lim), shunda `--force` ham o'tmaydi.

`dev2` da `draft` ni olib, bitta commit qo'shib push qiling. Keyin `dev1` da `fetch` qilmasdan o'z commit'ini `--amend` bilan qayta yozib (1-dars, 6-bo'lim: amend yangi SHA'li yangi commit yaratadi) push qilib ko'ring:

```
$ cd ../dev2 && git config user.name "Dev Two" && git config user.email "dev2@example.com"
$ git fetch -q && git switch -q draft && echo more >> draft.txt && git commit -qam "Extend draft" && git push -q
$ cd ../dev1 && git commit -q --amend -m "Start draft (reworded)"
$ git push
To <yo'l>/demo/hub.git
 ! [rejected]        draft -> draft (fetch first)
error: failed to push some refs to '<yo'l>/demo/hub.git'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. This is usually caused by another repository pushing to
hint: the same ref. If you want to integrate the remote changes, use
hint: 'git pull' before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
```

- `! [rejected]`: ref ko'chirilmadi. `draft -> draft` lokal va serverdagi ref nomlari.
- Qavs ichidagi sabab: `(fetch first)` serverdagi ref sizda umuman yo'q commit'ga qarab turibdi, Git avlodlikni tekshira ham olmaydi. Agar o'sha commit sizda bor bo'lsa-yu (avval `fetch` qilingan), lokal branch uning avlodi bo'lmasa, sabab `(non-fast-forward)` bo'ladi va hint "the tip of your current branch is behind its remote counterpart" deb boshlanadi.
- `hint:` qatorlari bitta yechimni taklif qiladi (`git pull`), lekin u har doim ham to'g'ri emas.

Rad etilishning ikki sababi va ikki xil yechimi bor:

| Sabab | Belgisi | Yechim |
|-------|---------|--------|
| Serverda siz ko'rmagan yangi commit'lar bor | siz tarixni qayta yozmagansiz | `fetch`, integratsiya (merge yoki rebase), qayta push |
| Siz allaqachon push qilingan tarixni qayta yozdingiz (amend, rebase) | eski commit'lar serverda, yangilari sizda | force push, faqat o'zingiz ishlayotgan branch'da |

Yuqoridagi misolda ikkala sabab birga: `dev1` tarixni qayta yozgan va serverda `dev2` ning commit'i bor. Shu holat force push'ning xavfini ko'rsatadi.

### Force push'ning uch darajasi

| Buyruq | Nimani tekshiradi |
|--------|-------------------|
| `git push --force` | hech narsani. Serverdagi ref shartsiz almashtiriladi, bu orada boshqa birov push qilgan commit'lar ref'siz qoladi |
| `git push --force-with-lease` | serverdagi ref hali sizning lokal `origin/<branch>` nusxangizga tengmi. Teng bo'lsa almashtiradi, bo'lmasa rad etadi |
| `git push --force-with-lease --force-if-includes` | qo'shimcha (Git 2.30+): `origin/<branch>` dagi commit'lar lokal branch'ingiz tarixidan (reflog'idan, 1-dars, 6-bo'lim) o'tganmi, ya'ni siz ularni haqiqatan o'z ishingizga qo'shganmisiz |

"Lease" so'zining ma'nosi: "men bu ref'ni oxirgi marta `X` holatida ko'rganman, hali ham `X` bo'lsagina almashtir". Solishtirish serverdagi haqiqiy qiymat bilan lokal kesh orasida bo'ladi:

```
$ git push --force-with-lease
To <yo'l>/demo/hub.git
 ! [rejected]        draft -> draft (stale info)
error: failed to push some refs to '<yo'l>/demo/hub.git'
```

`(stale info)`: `dev1` ning `origin/draft` i hali o'zining eski commit'ida, serverda esa `dev2` ning commit'i turibdi. Kesh eskirgan, lease bajarilmadi, `dev2` ning ishi saqlanib qoldi. Oddiy `--force` shu joyda `+ <a>...<b> draft -> draft (forced update)` deb jim o'tib ketardi (boshidagi `+` majburiy ko'chirish belgisi).

To'g'ri davomi: `git fetch`, `dev2` ning commit'ini ko'rish (`git log --oneline HEAD..origin/draft`), uni o'z tarixingizga qo'shish (`git rebase origin/draft` yoki `git pull --rebase`), keyin push.

**Tuzoq: `--force-with-lease` lokal keshga tayanadi.** IDE yoki fon jarayoni avtomatik `fetch` qilib tursa, `origin/<branch>` siz ko'rmagan commit'lar bilan yangilanadi, kesh serverga teng bo'lib qoladi va lease bajariladi: begona commit'lar baribir ustidan yoziladi. `--force-if-includes` aynan shu holatni yopadi.

Qolgan buyruqlar: `git push origin --delete draft` serverdagi branch'ni o'chiradi; `git push origin v1.0` bitta tag'ni yuboradi (tag'lar oddiy `git push` bilan ketmaydi, 2-dars, 6-bo'lim).

### Real ishda qachon kerak

- PR branch'ini `main` ustiga rebase qilganingizdan keyin (2-dars, 3-bo'lim) oddiy push har doim rad etiladi: bu kutilgan holat, `--force-with-lease` ishlatiladi.
- `main` va release branch'lariga force push server tomonda taqiqlanadi (6-bo'lim): buni odamlarning ehtiyotkorligiga qoldirib bo'lmaydi.
- Force push bilan "yo'qolgan" commit darhol o'chmaydi: u push qilgan odamning klonida va reflog'ida turadi, o'sha yerdan qayta push qilinadi.

### Nima uchun shunday

Fast-forward sharti "hech kimning ishi jim yo'qolmasin" degan kafolat: ref faqat oldinga surilsa, serverdagi har bir commit yangi uchdan yetib boriladigan bo'lib qoladi. `--force` bu kafolatni butunlay o'chiradi. `--force-with-lease` ma'lumotlar bazalaridagi optimistic locking (compare-and-swap) g'oyasi: blok qo'yilmaydi, lekin yozish paytida "men o'qigan qiymat hali o'shami" tekshiriladi. Muqobili branch'ni qulflash bo'lardi, u esa taqsimlangan ishga to'g'ri kelmaydi.

## 4. SSH kalitlar va commit imzosi

Bu bo'limda ikki xil savol bor va ular tez-tez aralashtiriladi. **Autentifikatsiya**: serverga kim ulanayotgani (push huquqi bormi). **Imzo**: commit'ni kim yaratgani. Birinchisi ulanishga, ikkinchisi commit obyektiga tegishli.

### SSH kalit jufti

SSH kalit ikki fayldan iborat: **private** kalit (faqat sizning mashinangizda) va **public** kalit (`.pub`, istalgan joyga berish mumkin). Mexanizm: server tasodifiy ma'lumot yuboradi, klient uni private kalit bilan imzolaydi, server imzoni akkauntga yuklangan public kalit bilan tekshiradi. Private kalit tarmoqqa chiqmaydi, parol umuman yuborilmaydi.

```
$ ssh-keygen -t ed25519 -C "zorin-office" -f ~/.ssh/id_ed25519_demo
Generating public/private ed25519 key pair.
Enter passphrase (empty for no passphrase):
...
$ cat ~/.ssh/id_ed25519_demo.pub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI<...> zorin-office
```

`-t ed25519` algoritm (zamonaviy, kaliti qisqa), `-C` izoh (qaysi mashina ekanini yozing), `-f` fayl nomi. `.pub` fayli uch maydon: tur, kalitning o'zi (base64), izoh. Shu bitta qator GitHub'da Settings, "SSH and GPG keys", "New SSH key" ga yuklanadi. **Passphrase** private kalit faylini diskda shifrlaydi: fayl o'g'irlansa ham passphrase'siz ishlamaydi. Uni har safar termaslik uchun **ssh-agent** (ochilgan kalitni xotirada ushlab turadigan fon jarayoni) ishlatiladi:

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Kalitni agent'ga qo'shish | `ssh-add ~/.ssh/<kalit>` (agent yo'q bo'lsa avval `eval "$(ssh-agent -s)"`) | `ssh-add --apple-use-keychain ~/.ssh/<kalit>` |
| Qayta yuklashdan keyin | passphrase bir marta qayta so'raladi | Keychain'dan o'zi oladi, agar `~/.ssh/config` da `UseKeychain yes` va `AddKeysToAgent yes` bo'lsa |
| Agent'dagi kalitlar | `ssh-add -l` | `ssh-add -l` |

Qaysi host uchun qaysi kalit ishlatilishini `~/.ssh/config` belgilaydi:

```
Host github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_demo
    IdentitiesOnly yes
```

`IdentitiesOnly yes` agent'dagi boshqa kalitlarni taklif qilmaslikni aytadi (bir nechta akkaunt bo'lganda muhim). `UseKeychain` faqat macOS'dagi OpenSSH tushunadigan parametr: bu fayl har mashinada alohida yoziladi, shuning uchun uni faqat Mac'da qo'shing. Tekshirish: `ssh -T git@github.com` javobi `Hi <user>! You've successfully authenticated, but GitHub does not provide shell access.`; `ssh -vT git@github.com` esa ulanishning har qadamini, jumladan qaysi kalit fayli taklif qilinganini ko'rsatadi.

### Commit imzosi

Commit'dagi `author` va `committer` (1-dars, 1-bo'lim) shunchaki matn: uni `user.name` va `user.email` dan Git o'zi yozadi va hech kim tekshirmaydi. Istalgan kishi istalgan email bilan commit yoza oladi, push huquqi esa faqat "kim yubordi" ni cheklaydi, "kim yozgan deb ko'rsatilgan" ni emas. **Imzo** commit mazmunini kalit egasiga bog'laydi. Git 2.34+ buni SSH kalit bilan qila oladi (undan oldin faqat GPG):

```
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519_demo.pub
git config commit.gpgsign true     # sign every commit; one-off: git commit -S
git config tag.gpgsign true        # sign annotated tags; one-off: git tag -s
```

Imzo commit obyektining ichida, alohida header sifatida saqlanadi:

```
$ git cat-file -p HEAD
tree <hash>
parent <hash>
author Dev One <dev1@example.com> <vaqt> +0500
committer Dev One <dev1@example.com> <vaqt> +0500
gpgsig -----BEGIN SSH SIGNATURE-----
 U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAg<...>
 -----END SSH SIGNATURE-----

Signed note
```

`gpgsig` header'i (nomi tarixiy, SSH imzo uchun ham shu) commit'ning qolgan mazmuni ustidan hisoblangan imzo. U obyekt ichida bo'lgani uchun commit SHA'siga kiradi: imzolangan commit'ni amend yoki rebase qilsangiz yangi commit qaytadan imzolanadi, boshqa odam esa sizning imzoingizni saqlagan holda mazmunni o'zgartira olmaydi.

Lokal tekshirish uchun Git kimning kaliti ishonchli ekanini bilishi kerak. Bu ro'yxat `gpg.ssh.allowedSignersFile` sozlamasi ko'rsatgan faylda, har qatorda `<email> <kalit turi> <kalit>`:

```
$ git log --show-signature -1
error: gpg.ssh.allowedSignersFile needs to be configured and exist for ssh signature verification
commit <hash>
No signature
...
$ echo "dev1@example.com $(cat ~/.ssh/id_ed25519_demo.pub)" > ~/git-lab/03/demo/allowed_signers
$ git config gpg.ssh.allowedSignersFile ~/git-lab/03/demo/allowed_signers
$ git log --show-signature -1
commit <hash>
Good "git" signature for dev1@example.com with ED25519 key SHA256:<fingerprint>
Author: Dev One <dev1@example.com>
```

Birinchi urinishda `No signature` imzo yo'qligini emas, tekshirib bo'lmaganini bildiradi (yuqoridagi `error:` qatori sababini aytadi). Fayl sozlangach: `Good "git" signature` imzo to'g'ri, `for dev1@example.com` ro'yxatdagi qaysi shaxsga tegishli, `SHA256:<fingerprint>` kalitning barmoq izi. Hostingda public kalit alohida "Signing key" turi bilan yuklanadi (autentifikatsiya kalitidan alohida yozuv, o'sha kalit bo'lsa ham), shunda commit yonida "Verified" belgisi chiqadi.

### Real ishda qachon kerak

- Yangi mashina, CI runner yoki server: har biriga alohida kalit, biri buzilsa faqat o'shani akkauntdan olib tashlaysiz.
- Protected branch'da "signed commits" talabi va reliz tag'larini imzolash (`git tag -s`): pipeline deploy'dan oldin `git verify-tag` qiladi va imzosiz tag'dan reliz chiqarmaydi.
- `Permission denied (publickey)` xatosida birinchi qadam `ssh -vT`: qaysi kalit taklif qilindi va server uni taniganmi.

### Nima uchun shunday

Git author'ni tekshirmaydi, chunki u taqsimlangan: markaziy "foydalanuvchilar bazasi" yo'q, patch'lar email orqali ham yuboriladi va commit'ni bir odam yozib, boshqasi qo'llashi mumkin (shuning uchun `author` va `committer` alohida). Shaxsni kriptografiya bilan bog'lash ixtiyoriy qatlam sifatida qo'shilgan. SSH imzo GPG'dan keyin paydo bo'ldi, chunki dasturchilarda SSH kalit baribir bor, GPG kalitlarini boshqarish esa alohida mashaqqat. Parol o'rniga kalit ishlatilishining sababi: parol serverga yuboriladi va uni o'g'irlash mumkin, private kalit esa mashinadan chiqmaydi.

## 5. Fork va pull request

### Fork

**Fork** bu reponing server tomondagi, sizning akkauntingizdagi nusxasi. Git buyrug'i emas, hosting funksiyasi: hosting o'z ichida klon yaratadi va "bu falon reponing fork'i" degan bog'lanishni eslab qoladi. Asl repoga yozish huquqi bo'lmaganda (open source, tashqi pudratchi) ishlatiladi. Lokal klonda ikki remote bo'ladi: `origin` (fork, yozasiz) va `upstream` (asl repo, faqat o'qiysiz; bu nom ham kelishuv va 2-bo'limdagi branch upstream'i bilan bir narsa emas). Fork o'zi yangilanmaydi:

```
git remote add upstream <asl repo URL>
git fetch upstream                  # creates refs/remotes/upstream/*
git switch main
git merge --ff-only upstream/main   # or: git rebase upstream/main
git push origin main                # bring the fork up to date
```

Jamoa ichida, hammada yozish huquqi bor repoda fork kerak emas: bitta repoda branch ochiladi.

### Pull request nima

**Pull request** (PR; GitLab'da merge request) Git obyekti emas: `.git` ichida "PR" degan narsa yo'q. Bu hosting ma'lumotlar bazasidagi yozuv: "shu branch'ni (head) anavi branch'ga (base) qo'shish so'raladi", uning atrofida diff, muhokama, CI natijalari va tasdiqlar. Git tomonida faqat ikkita ref va ular orasidagi commit'lar bor. Hosting PR ko'rsatadigan diff `git diff base...head` (merge base'dan head'gacha), commit'lar ro'yxati esa `git log base..head`.

Hosting har PR uchun maxsus ref ham saqlaydi: GitHub'da `refs/pull/<N>/head` (PR branch'ining uchi; ochiq PR uchun yana `refs/pull/<N>/merge`, base bilan sinov merge natijasi), GitLab'da `refs/merge-requests/<N>/head`. Ular `git ls-remote origin` da ko'rinadi, lekin oddiy `fetch` ularni olmaydi: 1-bo'limdagi refspec faqat `refs/heads/*` ni qamraydi. Refspec'ni qo'lda berish mumkin:

```
git fetch origin pull/42/head:pr-42    # <source ref on server>:<local branch to create>
git switch pr-42
```

Bu fork'dan kelgan PR'ni tekshirishda kerak: uning branch'i sizning `origin` ingizda emas, muallifning fork'ida yotadi, `refs/pull/<N>/head` esa asl repoda bor.

### Merge tugmasi ortida

PR sahifasidagi tugma serverda 2-darsdagi amallardan birini bajaradi:

| Usul | `main` dagi natija | Qachon |
|------|--------------------|--------|
| merge commit | barcha commit'lar asl SHA'lari bilan + merge commit (`--no-ff`, fast-forward mumkin bo'lsa ham) | commit'lar toza va alohida qimmatli; butun PR `revert -m 1` bilan qaytadi |
| squash and merge | PR'dagi hamma o'zgarish bitta yangi commit'da | PR ichidagi tarix "wip" lardan iborat; `main` chiziqli, bitta PR bitta commit |
| rebase and merge | commit'lar `main` uchiga qayta qo'llanadi (yangi SHA), merge commit yo'q | chiziqli tarix va alohida commit'lar birga kerak |

Squash va rebase'dan keyin `main` dagi commit'lar PR branch'idagi commit'lar bilan bir xil SHA'ga ega emas. Oqibati: lokal PR branch'ingiz Git nazarida "merge qilinmagan" bo'lib ko'rinadi, `git branch -d` rad etadi va `-D` kerak bo'ladi (2-dars, 1-bo'lim).

### PR oqimi

1. `main` dan qisqa yashaydigan branch, kichik atomik commit'lar (1-dars, 3-bo'lim).
2. Push, PR ochish. Tavsifda: nima uchun, qanday tekshirilgan, qanday qaytariladi (rollback). Tugallanmagan ish uchun draft PR.
3. CI ishlaydi, reviewer ko'radi. Tuzatishlar yangi commit bilan (yoki `git commit --fixup`, 2-dars, 3-bo'lim). Review o'rtasida tarixni qayta yozish reviewer'dan "oxirgi ko'rganimdan beri nima o'zgardi" ni olib qo'yadi.
4. Merge, branch o'chiriladi (lokalda `git fetch --prune`).

### Real ishda qachon kerak

- Infratuzilma o'zgarishi (Terraform, Kubernetes manifestlari) PR orqali o'tadi: PR'ga "plan" yoki diff natijasi ilova qilinadi, reviewer "ishlaydimi" dan tashqari "buzilsa qanday qaytaramiz" ni so'raydi.
- PR kichik (bir necha yuz qatordan kam) va bitta maqsadli bo'lsa, review haqiqiy bo'ladi va revert bitta harakat.
- Merge usuli repo sozlamasida cheklanadi (masalan faqat squash), shunda `main` tarixi bir xil qoidada.

### Nima uchun shunday

Git'ning o'zida faqat `git request-pull` bor: u "falon URL'dagi falon branch'ni oling" degan matn yaratadi va email orqali yuboriladi, Linux kernel shunday ishlaydi. Nomi ham shundan: muallif push qila olmaydi, u egadan "pull" qilishni so'raydi. Hostinglar shu g'oyani web interfeysga ko'chirib, ustiga review va CI qo'shgan. PR Git'dan tashqarida bo'lgani uchun u hostingga bog'liq: repo boshqa hostingga ko'chirilganda commit'lar ko'chadi, PR muhokamalari alohida import qilinadi.

## 6. Workflow'lar va branch himoyasi

### Uch oqim

**Workflow** bu jamoa branch'lardan qanday foydalanishi haqidagi kelishuv: qaysi branch doimiy, ish qayerda qilinadi, reliz qayerdan chiqadi.

| | Trunk-based | GitHub Flow | GitFlow |
|---|-------------|-------------|---------|
| Doimiy branch'lar | `main` | `main` | `main`, `develop` |
| Vaqtinchalik | juda qisqa feature branch (soatlar, 1–2 kun) yoki to'g'ridan-to'g'ri `main` | feature branch + PR | `feature/*`, `release/*`, `hotfix/*` |
| Reliz | `main` dan istalgan payt, tag yoki qisqa release branch | merge qilindi, deploy qilindi | `release/*` barqarorlashtiriladi, `main` ga merge va tag |
| Tugallanmagan ish | feature flag ortida `main` da | branch'da | `develop` da to'planadi |
| Mos keladi | CI/CD kuchli, tez-tez deploy | web servislar, kichik va o'rta jamoa | versiyalangan mahsulot, bir nechta qo'llab-quvvatlanadigan reliz |
| Narxi | kuchli avtomatik testlar va feature flag intizomi shart | `main` har doim deploy qilinadigan holatda bo'lishi kerak | uzoq yashaydigan branch'lar, katta merge'lar, sekin yetkazish |

Feature flag bu tugallanmagan kodni konfiguratsiyadagi kalit ortida o'chirilgan holda `main` ga qo'shish usuli (frontend'da A/B test yoki remote config kalitlari bilan bir xil g'oya).

Ops xulosalari:

- Branch qancha uzoq yashasa, merge base (2-dars, 2-bo'lim) shuncha orqada qoladi va integratsiya shuncha og'riqli. "Accelerate" (DORA) tadqiqotlari qisqa branch va tez-tez integratsiyani yuqori yetkazib berish ko'rsatkichlari bilan bog'laydi.
- GitFlow muallifining o'zi keyinroq uzluksiz yetkaziladigan web ilovalar uchun soddaroq oqimni (GitHub Flow kabi) tavsiya qilgan. GitFlow bir nechta versiyani parallel qo'llab-quvvatlash kerak bo'lganda o'rinli.
- Workflow CI/CD dizaynini belgilaydi: qaysi branch qaysi muhitga deploy bo'ladi, reliz tag'dan chiqadimi yoki merge'danmi.
- "Muhit boshiga branch" (`dev`, `staging`, `prod` branch'lari orasida merge) keng tarqalgan anti-pattern: muhitlar kod jihatdan ajralib ketadi. Bitta artefakt muhitlar bo'ylab ko'tariladi, farq konfiguratsiyada.

### Protected branch

**Protected branch** bu hosting server tomonda qo'yadigan qoidalar to'plami. Mexanizm: har push'da server ref'ni ko'chirishdan oldin qoidalarni tekshiradi va buzilsa ko'chirmaydi. Klient tomonda bu shunday ko'rinadi:

```
 ! [remote rejected] main -> main (<server bergan sabab>)
```

`[rejected]` (3-bo'lim) lokal Git'ning o'zi bosh tortganini, `[remote rejected]` esa serverning rad javobini bildiradi; sabab matni yuqorida `remote:` bilan boshlanadigan qatorlarda keladi. Tekshiruv serverda bo'lgani uchun uni `--force` yoki `--no-verify` bilan chetlab o'tib bo'lmaydi.

Odatiy qoidalar: to'g'ridan-to'g'ri push taqiqi (faqat PR orqali), N ta tasdiq, CI'dan o'tish sharti (required status checks), force push va o'chirish taqiqi, chiziqli tarix talabi (merge commit'siz), imzolangan commit talabi, qoidalar adminlarga ham amal qilishi. Aniq sozlash 4-darsda.

### Real ishda qachon kerak

- Yangi repo ochilganda birinchi ops ishi: `main` himoyasi va merge usulini tanlash.
- Terraform reposida `main` dagi har commit real infratuzilmaga qo'llanadi, shuning uchun PR'siz push umuman bo'lmasligi kerak.
- Hotfix yo'li oldindan yozib qo'yiladi: tungi avariyada "qaysi branch'dan, qayerga" deb o'ylash kech.

### Nima uchun shunday

Git branch'larni arzon qilgan (2-dars: branch bitta fayl), lekin ulardan qanday foydalanishni aytmaydi, shuning uchun kelishuv kerak. GitFlow 2010-yilda, relizlar oyda bir chiqqan davrda paydo bo'lgan; uzluksiz deploy tarqalgach, uzoq yashaydigan branch'larning narxi foydasidan oshib ketdi. Himoya server tomonda turadi, chunki bare repo'ning o'zi faqat fayl ruxsatlarini biladi: "kim nima qila oladi" ni hosting qo'shadi.

## 7. Hook'lar

### Bu nima va qanday ishlaydi

**Hook** bu Git ma'lum hodisada ishga tushiradigan bajariluvchi fayl. Git hodisa oldidan hook'lar katalogida (standart `.git/hooks/`) aniq nomdagi faylni qidiradi; fayl bor va bajariluvchi (`chmod +x`) bo'lsa, uni ishga tushiradi. Hook nol bo'lmagan exit code qaytarsa, "pre" turidagi hodisa to'xtatiladi. Til muhim emas: shell, Python, Node, birinchi qatordagi shebang (`#!/bin/sh`) hal qiladi. Yangi repoda `.git/hooks/` ichida faqat `*.sample` namunalar bor, ular `.sample` qo'shimchasi tufayli ishlamaydi.

| Hook | Qayerda | Qachon | Odatiy vazifa |
|------|---------|--------|---------------|
| `pre-commit` | client | commit'dan oldin, xabar yozilmasdan | lint, format, secret qidirish |
| `commit-msg` | client | xabar yozilgach; `$1` xabar fayli yo'li | xabar formatini tekshirish |
| `pre-push` | client | push'dan oldin; ref'lar ro'yxati `stdin` da | testlar, himoyalangan branch'ga push'ni to'xtatish |
| `pre-receive`, `update` | server | push qabul qilinishidan oldin | siyosat: majburiy qoidalar |
| `post-receive` | server | push qabul qilingach | xabarnoma, deploy trigger |

Misol: `.env` nomli fayl stage qilingan bo'lsa commit'ni to'xtatadigan `pre-commit` hook (`demo/dev1` ichida):

```
$ mkdir .githooks              # then create .githooks/pre-commit in your editor
$ cat .githooks/pre-commit
#!/bin/sh
# refuse to commit a file named .env
if git diff --cached --name-only | grep -qxF '.env'; then
    echo "pre-commit: .env must not be committed" >&2
    exit 1
fi
$ chmod +x .githooks/pre-commit && git config core.hooksPath .githooks
$ echo "TOKEN=fake" > .env && git add .env && git commit -m "Add env"
pre-commit: .env must not be committed
$ echo $?
1
$ git commit -q --no-verify -m "Add env" && git log --oneline -1
<hash> Add env
```

- `git diff --cached --name-only` index'dagi (1-dars, 2-bo'lim) o'zgargan fayllar nomlari; `grep -qxF` aynan `.env` qatori bor-yo'qligini tekshiradi.
- Xabar `stderr` ga (`>&2`) yoziladi, `exit 1` commit'ni to'xtatadi: `git commit` ning exit code'i ham `1`, commit yaratilmadi.
- `core.hooksPath` Git'ga hook'larni `.git/hooks` o'rniga repo ichidagi `.githooks` dan olishni aytadi: katalog commit qilinadi va jamoa bilan bo'lishiladi, lekin sozlamaning o'zini har kim o'z klonida qo'yishi kerak.
- `--no-verify` `pre-commit` va `commit-msg` hook'larini o'tkazib yuboradi: soxta token commit bo'ldi. (Sinovdan keyin `git reset --hard HEAD~1` bilan olib tashlang.)

**Tuzoq: client-side hook himoya emas.** `.git/hooks` va `core.hooksPath` sozlamasi klon bilan birga kelmaydi, `--no-verify` esa hook'ni chetlab o'tadi. Client hook tez teskari aloqa uchun, majburiy siyosat server tomonda: protected branch, server hook, CI'dagi required check. Bir xil tekshiruv ikkala joyda ham turadi.

### pre-commit freymvorki

**pre-commit** bu hook'larni boshqaradigan alohida asbob (Git'ning `pre-commit` hook'i bilan nomdosh, lekin boshqa narsa). Repo ildizidagi `.pre-commit-config.yaml` qaysi hook'lar qaysi versiyada ishlatilishini saqlaydi:

```
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-json
      - id: check-merge-conflict
```

`repo` hook'lar yashaydigan Git repo, `rev` uning tag'i (versiya qotiriladi, `package.json` dagi aniq versiya kabi), `id` o'sha repodagi hook nomi (to'liq ro'yxat repo README'sida). `pre-commit install` `.git/hooks/pre-commit` ga kichik skript yozadi va `pre-commit installed at .git/hooks/pre-commit` deb javob beradi; shundan keyin har commit'da faqat stage qilingan fayllar tekshiriladi. `pre-commit run --all-files` butun repo bo'yicha ishlatadi (CI'da aynan shu buyruq), `pre-commit autoupdate` `rev` larni oxirgi tag'ga yangilaydi. Secret qidirish uchun `gitleaks` kabi asboblar ham shu yerga hook bo'lib ulanadi.

### Real ishda qachon kerak

- Format va lint xatolari CI'da 5 daqiqadan keyin emas, commit paytida 1 soniyada chiqadi.
- Server hook'lar (`pre-receive`) self-hosted Gitea yoki GitLab'da siyosat uchun ishlatiladi (4-darsda); GitHub.com da ularning o'rnini branch himoyasi va required check'lar bosadi.
- `post-receive` eng sodda deploy mexanizmi: bare repoga push kelganda skript kodni chiqarib servisni qayta ishga tushiradi.

### Nima uchun shunday

Hook'lar klon bilan ko'chmasligi xavfsizlik qarori: aks holda `git clone` begona kodni sizning mashinangizda avtomatik ishga tushirishga yo'l ochardi (`npm install` dagi `postinstall` skriptlari bilan bir xil xavf). Narxi shuki, client hook'ni majburlab bo'lmaydi. Node loyihalarida shu vazifani `husky` bajaradi; `pre-commit` freymvorki tilga bog'liq emas va hook versiyalarini qotiradi, shuning uchun infratuzilma repolarida (Terraform, YAML, shell) keng tarqalgan.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Remote | boshqa reponing nomi va URL'i, `.git/config` da saqlanadi |
| `origin` | `git clone` remote'ga qo'yadigan standart nom |
| Bare repository | working tree'siz repo, faqat obyektlar va ref'lar; server tomonda ishlatiladi |
| Refspec | serverdagi ref'lar lokal ref'larga qanday moslashishini aytadigan `<manba>:<manzil>` qoidasi |
| Remote-tracking ref | `refs/remotes/<remote>/<branch>`, serverdagi branch'ning oxirgi ko'rilgan holati haqidagi lokal kesh |
| Fetch | yangi obyektlarni yuklab, remote-tracking ref'larni yangilaydigan amal; lokal branch'ga tegmaydi |
| Pull | `fetch` va undan keyin joriy branch'ga merge yoki rebase |
| Upstream | lokal branch bog'langan remote-tracking ref, `@{u}` bilan yoziladi |
| Ahead / behind | lokal branch'da upstream'da yo'q commit'lar soni va aksincha |
| Diverged | lokal branch va upstream ikkalasida ham ikkinchisida yo'q commit'lar bor holat |
| Prune | serverda o'chirilgan branch'larning remote-tracking nusxalarini o'chirish |
| Non-fast-forward | ref'ni eski commit'ning avlodi bo'lmagan commit'ga ko'chirish; push standart holatda rad etadi |
| Force push | fast-forward shartini o'chirib ref'ni almashtirish |
| Lease | `--force-with-lease` sharti: serverdagi ref hali lokal keshdagi qiymatga teng bo'lsagina almashtirish |
| SSH kalit jufti | private kalit (mashinada qoladi) va public kalit (serverga yuklanadi) |
| Passphrase | private kalit faylini diskda shifrlaydigan parol |
| ssh-agent | ochilgan private kalitni seans davomida xotirada ushlab turadigan jarayon |
| Imzo (signature) | commit yoki tag mazmunini kalit egasiga bog'laydigan, obyekt ichida saqlanadigan kriptografik belgi |
| `allowed_signers` | lokal imzo tekshiruvi uchun ishonchli email va public kalitlar ro'yxati |
| Fork | reponing hostingdagi, sizning akkauntingizdagi nusxasi |
| Pull request | bir branch'ni boshqasiga qo'shish so'rovi, hosting funksiyasi (review, CI, tasdiq) |
| Squash merge | PR'dagi hamma commit'larni bitta yangi commit qilib qo'shish |
| Workflow | jamoaning branch'lardan foydalanish kelishuvi (trunk-based, GitHub Flow, GitFlow) |
| Protected branch | server tomonda tekshiriladigan push va merge qoidalari qo'yilgan branch |
| Hook | Git ma'lum hodisada ishga tushiradigan bajariluvchi fayl |
| `core.hooksPath` | hook'lar katalogini `.git/hooks` o'rniga boshqa joyga ko'rsatadigan sozlama |

## Tuzoqlar

- Umumiy branch'ga `git push --force`: boshqalarning push qilgan commit'lari ref'siz qoladi. O'z branch'ingizda ham `--force-with-lease`.
- `origin/main` ni "serverdagi hozirgi holat" deb o'ylash. U oxirgi `fetch` paytidagi nusxa, `git status` ham shunga qaraydi.
- `git pull` ni sozlamasiz ishlatish: kutilmagan merge commit'lar yoki serverda conflict bilan to'xtab qolgan deploy. Serverda faqat `--ff-only`.
- Rad etilgan push'dagi `hint:` ga ko'r-ko'rona ergashish: tarixni qayta yozgan bo'lsangiz `git pull` eski va yangi commit'larni aralashtirib yuboradi. Avval sababni aniqlang (3-bo'lim jadvali).
- Private kalitni passphrase'siz saqlash, mashinalar orasida nusxalash yoki repoga commit qilish. Har mashina va har maqsad uchun alohida kalit.
- `UseKeychain yes` yozilgan `~/.ssh/config` ni Zorin'ga ko'chirish: Linux'dagi OpenSSH bu parametrni tanimaydi va xato beradi. Fayl umumiy bo'lishi shart bo'lsa, undan oldin `IgnoreUnknown UseKeychain` qatori qo'yiladi.
- Autentifikatsiya kalitini yuklab, imzo uchun ham ishlaydi deb o'ylash: GitHub'da "Signing key" alohida qo'shiladi, aks holda commit "Unverified" bo'lib qoladi.
- Client hook'ga siyosat sifatida tayanish. `--no-verify` va yangi klon uni yo'q qiladi.
- `core.hooksPath` o'rnatilgan repoda `pre-commit install`: freymvork hook'ni yozishdan bosh tortadi. Bitta repoda ikkalasidan bittasini tanlang.
- Uzoq yashaydigan branch va muhit branch'lari: katta, xavfli merge'lar va muhitlar orasidagi tushunarsiz farq.
- Fork'dan kelgan PR'da CI'ga secret berish: begona kod sizning token'laringiz bilan ishlaydi. Hostinglar buni standart holatda cheklaydi, cheklovni o'chirmang.
- Review paytida force push: reviewer nima o'zgarganini ko'ra olmaydi. Tuzatishni alohida commit bilan yuboring, merge'da squash qiling.
- "Verified" belgisi yo'qligini e'tiborsiz qoldirish: author maydoni soxtalashtirilishi mumkin, imzo talabi bo'lmasa buni hech narsa to'xtatmaydi.

## Manbalar

- https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches – Pro Git 3.5, remote-tracking branch (majburiy)
- https://git-scm.com/book/en/v2/Git-Internals-The-Refspec – Pro Git 10.5, refspec
- https://git-scm.com/book/en/v2/Git-Internals-Transfer-Protocols – Pro Git 10.6, fetch va push tarmoqda nima almashadi
- https://git-scm.com/docs/git-fetch va https://git-scm.com/docs/git-pull – `--prune`, `pull.rebase`, `pull.ff`
- https://git-scm.com/docs/git-push – `--force-with-lease`, `--force-if-includes`, "Note about fast-forwards"
- https://git-scm.com/docs/githooks – hook'lar ro'yxati, argumentlari va `stdin` formati
- https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work – Pro Git 7.4, imzolash
- https://docs.github.com/en/authentication/connecting-to-github-with-ssh – SSH kalit yaratish, agent, Keychain
- https://docs.github.com/en/authentication/managing-commit-signature-verification – commit imzosini tekshirish, SSH signing key
- https://docs.github.com/en/pull-requests – pull request hujjatlari, merge usullari
- https://docs.github.com/en/get-started/using-github/github-flow – GitHub Flow
- https://trunkbaseddevelopment.com – trunk-based development
- https://nvie.com/posts/a-successful-git-branching-model/ – GitFlow asl maqolasi va muallifning keyingi izohi
- https://pre-commit.com – pre-commit freymvorki, o'rnatish va hook'lar ro'yxati

---

## Birga bajaramiz

Bitta odam, ikki mashina: ofisda boshlangan ishni uyda davom ettirib, ertasi kuni ofisga qaytish. Bu sizning haqiqiy holatingiz (Zorin va macOS), faqat bu yerda ikkala "mashina" bitta kompyuterdagi ikki klon: `office` va `home`, "server" esa `notes.git` bare reposi. Yo'lda remote, kesh, upstream, o'z branch'ini qayta yozish va undan keyin ikkinchi klonni tartibga keltirishni ko'ramiz. Hamma narsa `~/git-lab/03/walk/` ichida.

1. Server va birinchi klon. Ofisda runbook (nosozlikda nima qilish yozilgan qo'llanma) boshlaymiz:

```
$ mkdir -p ~/git-lab/03/walk && cd ~/git-lab/03/walk
$ git init -q --bare -b main notes.git
$ git clone -q notes.git office && cd office
$ git config user.name "Me" && git config user.email "me@example.com"
$ echo "# Runbook" > runbook.md && git add runbook.md && git commit -qm "Start runbook"
$ git push -u origin main
To <yo'l>/walk/notes.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

Bo'sh serverda `main` yo'q edi, push uni yaratdi (`* [new branch]`), `-u` esa `office` dagi `main` ga upstream yozdi.

2. Ofisda `wip` branch'ida qoralama yozamiz va kun oxirida serverga qoldiramiz:

```
$ git switch -q -c wip
$ echo "## Backup" >> runbook.md && git commit -qam "Draft backup section"
$ git push -u origin wip
To <yo'l>/walk/notes.git
 * [new branch]      wip -> wip
branch 'wip' set up to track 'origin/wip'.
```

3. Uyda klon qilamiz. Klon faqat standart branch'ni (`main`) lokal branch qiladi, qolganlari remote-tracking ref sifatida keladi:

```
$ cd .. && git clone -q notes.git home && cd home
$ git config user.name "Me" && git config user.email "me@example.com"
$ git branch -a
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
  remotes/origin/wip
$ git switch wip
Switched to a new branch 'wip'
branch 'wip' set up to track 'origin/wip'.
```

`remotes/origin/HEAD -> origin/main` serverning standart branch'i qaysi ekanini eslab qolgan yozuv. `git switch wip` lokal `wip` yo'qligini, lekin `origin/wip` borligini ko'rdi va lokal branch'ni upstream'i bilan yaratdi. (Ikki xabar qatorining tartibi Git versiyasiga qarab farq qilishi mumkin.)

4. Uyda qoralamani to'ldiramiz, lekin yangi commit o'rniga kechagi commit'ni tuzatamiz:

```
$ echo "Run pg_dump before every migration." >> runbook.md
$ git commit -q -a --amend -m "Add backup section"
$ git status -sb
## wip...origin/wip [ahead 1, behind 1]
```

Amend eski commit'ni o'zgartirmadi, yonida yangi SHA'li commit yaratdi. Shuning uchun lokal `wip` da serverda yo'q 1 commit bor (`ahead 1`) va serverda lokal tarixda endi yo'q 1 commit bor (`behind 1`): branch o'z upstream'idan ajraldi.

5. Push qilamiz:

```
$ git push
To <yo'l>/walk/notes.git
 ! [rejected]        wip -> wip (non-fast-forward)
error: failed to push some refs to '<yo'l>/walk/notes.git'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. If you want to integrate the remote changes,
hint: use 'git pull' before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
```

Sabab `(non-fast-forward)`: serverdagi commit bizda bor, lekin yangi commit uning avlodi emas. Hint `git pull` ni taklif qiladi, bu yerda u noto'g'ri yo'l: eski va yangi versiya merge bo'lib, tuzatmoqchi bo'lgan commit tarixga qaytib kelardi. Bu branch'da faqat o'zimiz ishlaymiz va tarixni ataylab qayta yozdik, shuning uchun:

```
$ git push --force-with-lease
To <yo'l>/walk/notes.git
 + <hashA>...<hashB> wip -> wip (forced update)
```

Lease bajarildi: serverdagi `wip` hali biz oxirgi ko'rgan `<hashA>` da edi, demak oraliqda hech kim (bu yerda: ofisdagi o'zimiz) push qilmagan. Boshidagi `+` va uch nuqta majburiy, fast-forward bo'lmagan ko'chirishni bildiradi.

6. Ertasi kuni ofisda. Lokal `wip` hali kechagi eski commit'da:

```
$ cd ../office && git status -sb
## wip...origin/wip
$ git fetch
From <yo'l>/walk/notes
 + <hashA>...<hashB> wip        -> origin/wip  (forced update)
$ git status -sb
## wip...origin/wip [ahead 1, behind 1]
```

`fetch` gacha status "hammasi teng" dedi (eskirgan kesh). `fetch` chiqishidagi `+` va `(forced update)` server tarixi qayta yozilganini aytadi: refspec boshidagi `+` aynan shunga ruxsat beradi. Endi `ahead 1` bu ofisda qolgan eski commit. Unda yo'qotadigan ish yo'q (ko'rish uchun: `git diff origin/wip wip`), shuning uchun lokal branch'ni serverdagi holatga o'tkazamiz:

```
$ git reset --hard origin/wip
HEAD is now at <hashB> Add backup section
```

`reset --hard` (1-dars, 6-bo'lim) branch'ni, index'ni va working tree'ni `origin/wip` ga tenglashtiradi. Eski commit reflog'da qoladi. Agar ofisda push qilinmagan o'z commit'lari bo'lganida `reset` o'rniga `git rebase origin/wip` kerak bo'lardi.

7. Ish tayyor: `main` ga qo'shamiz va vaqtinchalik branch'ni serverdan o'chiramiz.

```
$ git switch -q main && git merge -q --ff-only wip && git push -q
$ git push origin --delete wip
To <yo'l>/walk/notes.git
 - [deleted]         wip
$ git branch -d wip
Deleted branch wip (was <hashB>).
```

8. Uyda tartibga keltirish:

```
$ cd ../home && git branch -r
  origin/HEAD -> origin/main
  origin/main
  origin/wip
$ git fetch --prune
From <yo'l>/walk/notes
 - [deleted]         (none)     -> origin/wip
   <hash1>..<hashB>  main       -> origin/main
$ git branch -vv
  main <hash1> [origin/main: behind 1] Start runbook
* wip  <hashB> [origin/wip: gone] Add backup section
$ git switch -q main && git pull -q --ff-only && git branch -d wip
Deleted branch wip (was <hashB>).
```

`git branch -r` hali `origin/wip` ni ko'rsatdi: server uni o'chirgan, kesh esa bilmaydi. `--prune` keshdagi nusxani o'chirdi (`- [deleted]`), lokal `wip` ga tegmadi, faqat uning upstream'i endi `gone`. `main` ni `--ff-only` bilan yangilagach `wip` to'liq `main` ichida, shuning uchun `-d` uni xavfsiz o'chirdi. Oxirida `cd ~ && rm -rf ~/git-lab/03/walk`.

Shu 8 qadamda ko'rganingiz: remote bu nom va URL, bare repo esa server (1-bo'lim); lokal branch va upstream bog'lanishi, `fetch` gacha kesh eskirgani, prune (2-bo'lim); amend'dan keyingi non-fast-forward rad javobi va faqat o'z branch'ingizda `--force-with-lease` (3-bo'lim); qayta yozilgan branch'ni ikkinchi klonda `pull` bilan emas, ongli `reset` yoki `rebase` bilan tartibga keltirish (1 va 2-darslar). SSH, PR va hook'lar bu yurishga kirmadi, ular C, D, E guruh vazifalarida.

---

## Vazifalar

Ish papkasi: `git/03-remotes-pr/` (`make new m=git n=03 name=remotes-pr` bilan yarating). A va B guruhlarni `~/git-lab/03/` dagi bare repo va ikki klonda (`server.git`, `alice`, `bob`), qolganlarini GitHub'dagi `git-lab-03` reposida bajaring; hammasi host'da, ikkala mashinada bir xil. Javoblarni ish papkasidagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (hook skriptlari, `.pre-commit-config.yaml` nusxasi) shu papkaga saqlanadi. Private kalit va token README'ga ham, ish papkasiga ham tushmasin. A va B guruhda vazifalar ketma-ket holatga tayanadi: mashinani almashtirsangiz, "Laboratoriya" dagi buyruqlar bilan qaytadan yarating. Har vazifa oxiridagi "Yo'nalish" qayerdan o'qishni aytadi, yechimni emas.

### A. Remote, fetch, pull

1. **Bare repository.** Laboratoriyadagi `server.git` ni yarating va ichini `alice` klonidagi `.git` bilan solishtiring: bare repoda nima yo'q va nima uchun server uchun aynan shu kerak? `alice` dan birinchi commit'ni push qiling, `bob` da `git remote show origin` va `.git/config` dagi refspec'ni izohlang. Yo'nalish: 1-bo'lim, "Mexanizm: uch narsa".

2. **Stale tracking ref.** `alice` 2 commit push qilsin. `bob` da `fetch` qilmasdan `git status` va `git log origin/main --oneline` ni ko'ring, keyin `git ls-remote origin` bilan solishtiring. Farqni izohlang. `git fetch` dan keyin nima o'zgardi, `bob` ning lokal `main` i va working tree'si-chi? Yo'nalish: 1-bo'lim, "Remote-tracking ref".

3. **Inspect before integrating.** 2-vazifa davomida `bob` da `git log HEAD..origin/main` va `git diff HEAD...origin/main` bilan kelgan o'zgarishlarni ko'ring, keyin `git merge --ff-only origin/main` qiling. Bu `git pull` dan nimasi bilan farq qiladi? Yo'nalish: 2-bo'lim, "fetch ichkarida nima qiladi".

4. **Divergent pull.** `alice` va `bob` ikkalasi `main` ga har xil commit qilsin, `alice` push qilsin. `bob` da `pull.rebase` va `pull.ff` sozlanmagan holda `git pull` qiling va xabarni yozing. Keyin holatni uch nusxada `--no-rebase`, `--rebase`, `--ff-only` bilan sinab, graph'larni solishtiring. Yo'nalish: 2-bo'lim, "pull bu fetch va integratsiya".

5. **Upstream tracking.** `alice` da `feature` branch yaratib `-u` siz `git push` qiling, xatoni yozing. Upstream'ni o'rnating, `git branch -vv` va `git rev-parse --abbrev-ref @{u}` ni ko'rsating. `bob` da `git switch feature` nima qildi? `git log @{u}..HEAD` qaysi savolga javob beradi? Yo'nalish: 2-bo'lim, "Upstream (tracking)".

6. **Prune.** `alice` serverdagi `feature` ni o'chirsin. `bob` da `git branch -r` hali nimani ko'rsatadi? `git fetch --prune` dan keyin-chi? `bob` ning lokal `feature` branch'i qanday holatda (`git branch -vv`)? Yo'nalish: 2-bo'lim, "pull bu fetch va integratsiya" (prune) va "Upstream (tracking)".

### B. Push va force

7. **Non-fast-forward rejection.** `alice` push qilgan holatda `bob` eski `main` dan commit qilib push qilsin. Xato matnini to'liq yozing va uni mexanizm (server ref'ni qanday ko'chiradi) orqali izohlang. To'g'ri hal qiling. Yo'nalish: 3-bo'lim, "Push ichkarida nima qiladi".

8. **Force overwrites work.** `alice` va `bob` bitta `shared` branch'da ishlasin. `bob` commit push qilsin, `alice` esa `fetch` qilmasdan `amend` qilib `git push --force` qilsin. `bob` ning commit'i serverda qoldimi (`git ls-remote`, yangi klon)? Uni qayerdan tiklash mumkin? Yo'nalish: 3-bo'lim, "Force push'ning uch darajasi"; reflog uchun 1-dars, 6-bo'lim.

9. **force-with-lease.** 8-vazifani `--force-with-lease` bilan takrorlang: rad etish xabarini yozing. Keyin `alice` da `git fetch` qilib (o'zgarishni integratsiya qilmasdan) yana `--force-with-lease` qiling: nima bo'ldi va nima uchun? `--force-if-includes` qo'shilganda natija qanday? `--force-if-includes` Git 2.30+ talab qiladi, `git --version` ni tekshiring. Yo'nalish: 3-bo'lim, "Force push'ning uch darajasi".

10. **Rewriting your own branch.** `alice` o'z `feature` branch'ini push qilsin, keyin `main` ustiga rebase qilsin. Oddiy `git push` nima uchun rad etiladi? Xavfsiz force push qiling. Qanday shartda bu amal maqbul, qanday shartda yo'q? Yo'nalish: 3-bo'lim, "Real ishda qachon kerak"; rebase uchun 2-dars, 3-bo'lim.

### C. SSH va imzolash

11. **SSH key and config.** Bu dars uchun alohida `ed25519` kalit yarating (passphrase bilan, alohida fayl nomida), public qismini GitHub akkauntingizga qo'shing va `~/.ssh/config` orqali aynan shu kalit ishlatilishini sozlang. `ssh -T git@github.com` va `ssh -vT` chiqishidan qaysi kalit taklif qilinganini ko'rsating. Private kalit faylining huquqlari qanday va nima uchun? Kalit har mashinada alohida yaratiladi: vazifani bir mashinada to'liq bajaring, ikkinchisida kalit yaratish va akkauntga qo'shishni takrorlang (macOS'da ixtiyoriy: passphrase'ni Keychain'ga saqlang). Yo'nalish: 4-bo'lim, "SSH kalit jufti".

12. **Forged author.** Scratch repoda `user.name` va `user.email` ni o'ylab topilgan shaxs qilib (masalan `Fake CEO`, `ceo@example.com`; haqiqiy odamning ma'lumotini ishlatmang) commit yozing va `git-lab-03` ga push qiling. Git yoki GitHub buni biror joyda tekshirdimi, commit UI'da kimning nomi bilan ko'rindi? Email haqiqiy akkauntga tegishli bo'lganda nima bo'lishini izohlang va xulosa chiqaring. Yo'nalish: 4-bo'lim, "Commit imzosi".

13. **SSH signing.** SSH kalit bilan commit imzolashni sozlang, imzolangan commit va `git tag -s` bilan tag yarating. `allowed_signers` faylini sozlab `git log --show-signature` va `git verify-tag` natijasini ko'rsating. Kalitni GitHub'ga signing key sifatida qo'shing: 12-vazifadagi commit va imzolangan commit UI'da qanday farq qiladi? SSH imzo Git 2.34+ talab qiladi (Mac'da `git --version`). Yo'nalish: 4-bo'lim, "Commit imzosi".

### D. Fork va pull request

14. **Fork and upstream.** Istalgan kichik ochiq reponi fork qiling, klon qilib `upstream` remote qo'shing. Asl repoda yangi commit'lar paydo bo'lganda fork'ning `main` ini yangilash ketma-ketligini yozing (bajarib yoki, yangi commit bo'lmasa, tartibini izohlab). `origin` va `upstream` ga push huquqlaringiz qanday? Yo'nalish: 5-bo'lim, "Fork".

15. **PR refs.** `git-lab-03` da branch'dan PR oching. `git ls-remote origin` chiqishidan PR ref'larini toping. PR'ni branch nomi orqali emas, `refs/pull/<N>/head` orqali alohida lokal branch'ga oling. Bu qachon kerak bo'ladi? Yo'nalish: 5-bo'lim, "Pull request nima".

16. **Merge methods.** Har birida 3 commit bo'lgan uchta PR oching va ularni uch usulda merge qiling: merge commit, squash, rebase. Har biridan keyin `main` ning graph'ini, commit SHA lari PR'dagi bilan bir xilmi-yo'qmi va butun PR'ni qaytarish (revert) qanday bajarilishini yozing. Yo'nalish: 5-bo'lim, "Merge tugmasi ortida".

17. **Review round.** PR ochib, o'zingizga review izoh qoldiring (qator izohi va "suggested change"). Tuzatishni `--fixup` commit bilan yuboring, merge'dan oldin `--autosquash` va `--force-with-lease` bilan tozalang. Xuddi shu ishni review o'rtasida amend + force push bilan qilganda reviewer nimani yo'qotadi? Yo'nalish: 5-bo'lim, "PR oqimi"; autosquash uchun 2-dars, 3-bo'lim.

18. **Workflow decision.** Uch vaziyat uchun workflow tanlang va 4–6 gapda asoslang: (a) 5 kishilik jamoa, SaaS web servis, kuniga bir necha deploy; (b) mijozlarga o'rnatiladigan dastur, bir vaqtda 2.x va 3.x versiyalar qo'llab-quvvatlanadi; (c) Terraform infratuzilma reposi, 3 muhit. Har biri uchun: doimiy branch'lar, reliz qanday belgilanadi, hotfix yo'li, qaysi branch himoyalanadi. Yo'nalish: 6-bo'lim, "Uch oqim".

### E. Hook'lar

19. **commit-msg hook.** `core.hooksPath` orqali ulanadigan `commit-msg` hook yozing: subject 72 belgidan uzun bo'lsa yoki ikkinchi qator bo'sh bo'lmasa commit'ni rad etsin va sababini `stderr` ga yozsin. Yaroqli va yaroqsiz xabarlar bilan sinang. `--no-verify` bilan nima bo'ladi? Skript nusxasi: `commit-msg`. Yo'nalish: 7-bo'lim, "Bu nima va qanday ishlaydi".

20. **pre-push guard.** `pre-push` hook yozing: `main` ga to'g'ridan-to'g'ri push'ni to'xtatsin (hook `stdin` dan oladigan ref qatorlarini `man githooks` dan o'qing). Bare repoga qarshi sinang. Yangi klonda hook bormi? Bu himoyani server tomonda nima almashtiradi? Skript nusxasi: `pre-push`. Yo'nalish: 7-bo'lim, "Bu nima va qanday ishlaydi" va 6-bo'lim, "Protected branch".

21. **pre-commit framework.** `git-lab-03` klonida `pre-commit` ni o'rnatib, `.pre-commit-config.yaml` yozing: bo'sh joy, fayl oxiri, YAML sintaksisi, katta fayl va private key tekshiruvlari. Har hook'ni ataylab buzib (xato YAML, 2 MB fayl, soxta private key sarlavhasi) xabarlarni yozing. `pre-commit run --all-files` va `pre-commit autoupdate` nima qiladi? Config nusxasini ish papkasiga saqlang. O'rnatish "Laboratoriya" jadvalida (Zorin'da `pipx`, macOS'da Homebrew); bu klonda `core.hooksPath` o'rnatilmagan bo'lsin. Yo'nalish: 7-bo'lim, "pre-commit freymvorki".

22. **Team repo setup.** `git-lab-03` ni "jamoa reposi" holatiga keltiring va README'da hujjatlashtiring: `CONTRIBUTING.md` (tanlangan workflow, branch nomlash, commit xabari qoidasi, merge usuli), `.pre-commit-config.yaml`, `main` uchun himoya (PR majburiy, force push taqiqlangan, chiziqli tarix). Keyin ikki "buzish" sinovi: `main` ga to'g'ridan-to'g'ri push va PR branch'idan `main` ga force push. Server javoblarini yozing va 20-vazifadagi client hook bilan solishtiring: qaysi biri himoya, qaysi biri qulaylik? Yo'nalish: 6-bo'lim, "Protected branch".

### Topshirish

Tayyor bo'lgach:
1. `git/03-remotes-pr/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida.
2. `commit-msg`, `pre-push` skriptlari va `.pre-commit-config.yaml` nusxasi ish papkasida, `make check` toza (host'da).
3. Hech qanday private kalit yoki token kurs reposida yo'q.
4. `~/git-lab/03` ikkala mashinada o'chirilgan, GitHub'dagi fork va (4-darsda kerak bo'lmasa) `git-lab-03` o'chirilgan. Akkauntda faqat o'zingiz ishlatadigan kalitlar qolgan (har mashina uchun bittadan), sinov kalitlari olib tashlangan.
5. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `origin/main` nima va qachon yangilanadi?
- `fetch` va `pull` farqi nima? Serverdagi deploy skriptida nima uchun `--ff-only`?
- Push qachon "non-fast-forward" deb rad etiladi? Ikki sababi va ikki yechimi qanday?
- `--force-with-lease` nimani tekshiradi va qaysi holatda himoya qilmaydi?
- SSH kalit bilan autentifikatsiya va commit imzolash qanday ikki xil muammoni yechadi?
- Fork bilan branch farqi nima, qachon qaysi biri?
- Merge commit, squash va rebase merge `main` tarixida nima qoldiradi, har birida revert qanday?
- Trunk-based, GitHub Flow va GitFlow qaysi sharoitda mos? Uzoq yashaydigan branch'ning narxi nima?
- Client-side hook nima uchun himoya emas? Majburiy siyosat qayerda turadi?
- Remote `.git/config` da qaysi yozuvlar bilan ifodalanadi? Refspec boshidagi `+` nimani bildiradi?
- Bare repo oddiy klondan nimasi bilan farq qiladi?
- Pull request Git obyektimi? Hosting uni Git tomonida qanday ifodalaydi va nima uchun oddiy `fetch` PR ref'larini olmaydi?
- Hamkasbingiz (yoki ikkinchi mashinadagi o'zingiz) branch'ni force push qildi. Lokal nusxani qanday tartibga keltirasiz va nima uchun `git pull` bu yerda yomon tanlov?
