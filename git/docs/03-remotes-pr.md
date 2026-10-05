# 3-dars: Remote va pull request

Maqsad: lokal repo bilan server orasida aynan nima almashilishini (ref'lar va obyektlar) tushunish va shu asosda jamoa ishini tashkil qilish: tracking branch, xavfsiz force push, SSH kalit va imzo, fork, pull request, workflow tanlovi, branch himoyasi va hook'lar. 1 va 2-darslarda tarix bitta mashinada edi, endi u bir nechta nusxada yashaydi va "tarixni qayta yozish" boshqalarga ta'sir qiladi. 4-darsda shu tushunchalar aniq hostinglar sozlamalariga aylanadi, CI/CD modulida esa pipeline'lar aynan shu yerdagi hodisalardan (push, PR, tag) ishga tushadi.

Taxminiy vaqt: 3 kun (siz uchun). `push`, `pull`, PR ochish kundalik ish. Diqqat: remote-tracking ref lokal ekani, `fetch` va `pull` farqi, `--force-with-lease` nimani tekshirishi, SSH signing, workflow'larning ops oqibatlari, client-side hook nima uchun himoya emasligi.

## Laboratoriya

Ikki muhit:

- **Lokal "server"**: bare repo va ikki klon, ikki dasturchini imitatsiya qiladi. Tarmoq va akkaunt kerak emas.

```
mkdir -p ~/git-lab/03 && cd ~/git-lab/03
git init --bare -b main server.git
git clone server.git alice && git clone server.git bob
# set a different local user.name / user.email in alice and bob
```

- **GitHub**: shaxsiy akkauntingizda `git-lab-03` nomli repo (C va D guruh vazifalari). Himoya qoidalari bepul tarifda faqat public repoda ishlaydi, shuning uchun repo public bo'lsin va unga hech qanday haqiqiy ma'lumot tushmasin. `gh` o'rnatilgan, lekin u 4-darsda o'rganiladi: bu darsda web UI yetarli.

`pre-commit` asbobi kerak bo'ladi (E guruh). U foydalanuvchi darajasida o'rnatiladi: `sudo apt install pipx`, keyin `pipx install pre-commit` (rasmiy yo'riqnoma: https://pre-commit.com/#install).

Tozalash: `rm -rf ~/git-lab/03`, GitHub'da `git-lab-03` va fork'ni o'chirish, sinov uchun yuklangan SSH kalit qolsa ham bo'ladi (o'zingizniki), lekin sinov deploy key va tokenlarni olib tashlang.

---

## 1. Remote nima

Remote bu boshqa reponing nomi va URL'i, `.git/config` da saqlanadi. `origin` shunchaki `git clone` qo'yadigan default nom.

```
git remote -v                     # names and URLs
git remote add upstream <url>     # one more remote
git remote show origin            # branches, tracking, push/pull state
git ls-remote origin              # refs on the server right now (network call)
```

`.git/config` dagi `fetch = +refs/heads/*:refs/remotes/origin/*` qatori **refspec**: serverdagi `refs/heads/*` branch'lari lokalda `refs/remotes/origin/*` nomi ostida saqlansin (`+` fast-forward bo'lmasa ham yangilansin).

### Remote-tracking branch

`origin/main` serverdagi `main` emas. Bu **lokal** ref: "oxirgi marta server bilan gaplashganimda u yerdagi `main` shu commit'da edi" degan yozuv. U faqat `fetch`, `pull` va `push` paytida yangilanadi, unga commit qilib bo'lmaydi. `git status` dagi "ahead 2, behind 3" ham shu eski nusxaga nisbatan hisoblanadi, shuning uchun avval `git fetch`.

URL turlari: `git@github.com:user/repo.git` (SSH), `https://github.com/user/repo.git` (HTTPS), lokal yo'l yoki `file://`. Protokol faqat transport, tarix bir xil.

## 2. fetch va pull

| Buyruq | Nima qiladi |
|--------|-------------|
| `git fetch` | yangi obyektlarni yuklaydi, `origin/*` ref'larini yangilaydi. Lokal branch'lar va working tree'ga tegmaydi, har doim xavfsiz |
| `git pull` | `fetch` + joriy branch'ga integratsiya: `merge` yoki `rebase` |
| `git fetch --prune` | serverda o'chirilgan branch'larning `origin/*` nusxalarini ham o'chiradi (`fetch.prune true` bilan doimiy) |

`pull` ning ikkinchi qadami sozlamaga bog'liq: `pull.rebase false` (merge), `pull.rebase true` (rebase), `pull.ff only` (faqat fast-forward, aks holda xato). Lokal va remote branch ajralgan bo'lsa va hech biri sozlanmagan bo'lsa, zamonaviy Git tanlov qilmaydi va `fatal: Need to specify how to reconcile divergent branches.` deb to'xtaydi.

Amaliy tanlov: feature branch'da `git pull --rebase` (ortiqcha "Merge branch 'x' of ..." commit'lari paydo bo'lmaydi), deploy skriptlarida va serverlarda `git pull --ff-only` (kutilmagan merge yoki conflict o'rniga aniq xato). `fetch` qilib, keyin `git log HEAD..origin/main` bilan nima kelganini ko'rib, so'ng integratsiya qilish eng nazoratli yo'l.

### Tracking (upstream)

Lokal branch'ning upstream'i bu u bog'langan remote-tracking branch. Argumentsiz `git pull` va `git push` shunga qarab ishlaydi, `@{u}` yozuvi uni bildiradi.

```
git push -u origin feature          # push and set upstream
git branch --set-upstream-to=origin/feature
git branch -vv                      # upstream and ahead/behind per branch
git log @{u}..HEAD                  # commits not pushed yet
```

`git switch feature` lokalda bunday branch bo'lmasa va `origin/feature` bo'lsa, tracking branch'ni o'zi yaratadi. `push.autoSetupRemote true` (Git 2.37+) birinchi push'da `-u` yozishdan qutqaradi.

## 3. Push

`git push origin feature` lokal `feature` dagi commit'larni yuboradi va serverdan `refs/heads/feature` ni yangi SHA ga ko'chirishni so'raydi. Server faqat **fast-forward** ko'chirishni qabul qiladi: yangi commit eskisining avlodi bo'lishi kerak. Aks holda `! [rejected] (non-fast-forward)` yoki `(fetch first)`.

Rad etilishning ikki sababi va ikki xil yechimi bor:

- serverda siz ko'rmagan yangi commit'lar bor: `fetch`, integratsiya (merge yoki rebase), qayta push;
- siz tarixni qayta yozdingiz (amend, rebase): force push kerak, faqat o'z branch'ingizda.

| Buyruq | Nima qiladi |
|--------|-------------|
| `git push --force` | serverdagi ref'ni shartsiz almashtiradi. Bu orada boshqa birov push qilgan commit'lar yo'qoladi |
| `git push --force-with-lease` | faqat serverdagi ref hali sizning `origin/<branch>` nusxangizga teng bo'lsa almashtiradi, aks holda rad etadi |
| `git push --force-with-lease --force-if-includes` | qo'shimcha: remote-tracking ref'dagi commit'lar lokal branch tarixiga (reflog'iga) kirganini ham tekshiradi |
| `git push origin --delete feature` | serverdagi branch'ni o'chiradi |

**Tuzoq: `--force-with-lease` `origin/<branch>` ga tayanadi.** IDE yoki fon jarayoni avtomatik `fetch` qilib tursa, `origin/<branch>` siz ko'rmagan commit'lar bilan yangilanadi va "lease" o'tib ketadi: begona commit'lar baribir ustidan yoziladi. `--force-if-includes` aynan shu holatni yopadi.

`main` va release branch'lariga force push server tomonda taqiqlanadi (6-bo'lim): buni odamlarning ehtiyotkorligiga qoldirib bo'lmaydi.

## 4. SSH kalitlar va imzolash

### Autentifikatsiya

```
ssh-keygen -t ed25519 -C "you@example.com"   # ~/.ssh/id_ed25519 and .pub
ssh -T git@github.com                        # test: "Hi <user>! You've successfully authenticated..."
```

Public kalit (`.pub`) hosting akkauntiga yuklanadi, private kalit mashinadan chiqmaydi va passphrase bilan himoyalanadi (`ssh-agent` uni seans davomida eslab turadi: `ssh-add`). Bir nechta akkaunt yoki hosting uchun `~/.ssh/config`:

```
Host github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

HTTPS'da parol o'rnida token ishlatiladi (4-darsda), uni credential helper saqlaydi.

### Commit'ni imzolash

`user.name` va `user.email` ni hech kim tekshirmaydi: istalgan kishi `git config user.email ceo@company.com` qilib commit yoza oladi. Imzo commit'ni kalit egasiga bog'laydi. Git 2.34+ SSH kalit bilan imzolay oladi:

```
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true     # sign every commit
git config tag.gpgsign true        # sign annotated tags
git log --show-signature -1
```

Lokal tekshirish uchun ishonchli kalitlar ro'yxati kerak: `gpg.ssh.allowedSignersFile` sozlamasi ko'rsatgan faylda har qatorda `email ssh-ed25519 AAAA...`. Hostingda public kalit alohida "Signing key" sifatida yuklanadi, shunda commit yonida "Verified" belgisi chiqadi. Ops uchun qo'llanish: protected branch'da "signed commits" talabi va reliz tag'larini imzolash (`git tag -s`), pipeline esa deploy'dan oldin `git verify-tag` qiladi.

## 5. Fork va pull request

**Fork** bu reponing server tomondagi, sizning akkauntingizdagi nusxasi. Asl repoga yozish huquqi bo'lmaganda (open source, tashqi pudratchi) ishlatiladi. Lokal klonda ikki remote bo'ladi: `origin` (fork, yozasiz) va `upstream` (asl repo, faqat o'qiysiz). Fork o'zi yangilanmaydi: `git fetch upstream`, `git rebase upstream/main` (yoki merge), `git push origin main`.

**Pull request** (GitLab'da merge request) Git tushunchasi emas, hosting funksiyasi: "shu branch'ni anavi branch'ga qo'shing" degan so'rov, uning atrofida diff, muhokama, CI natijalari va tasdiqlar. Hosting har PR uchun maxsus ref ham saqlaydi: GitHub'da `refs/pull/<N>/head`, GitLab'da `refs/merge-requests/<N>/head`. Boshqa birovning PR'ini lokal tekshirish:

```
git fetch origin pull/42/head:pr-42 && git switch pr-42
```

### PR oqimi

1. `main` dan qisqa yashaydigan branch, kichik atomik commit'lar.
2. Push, PR ochish. Tavsifda: nima uchun, qanday tekshirilgan, qanday qaytariladi (rollback). Tugallanmagan ish uchun draft PR.
3. CI ishlaydi, reviewer ko'radi. Tuzatishlar yangi commit bilan (yoki `--fixup`), review davomida tarixni qayta yozish reviewer'ga "oxirgi ko'rganimdan beri nima o'zgardi" ni yo'qotadi.
4. Merge, branch o'chiriladi.

Merge usullari (hosting tugmasi):

| Usul | `main` dagi natija | Qachon |
|------|--------------------|--------|
| merge commit | barcha commit'lar + merge commit (`--no-ff`) | commit'lar toza va alohida qimmatli; butun PR `revert -m 1` bilan qaytadi |
| squash and merge | bitta commit | PR ichidagi tarix "wip" lardan iborat; `main` chiziqli, bitta PR bitta commit |
| rebase and merge | commit'lar `main` uchiga qayta qo'llanadi (yangi SHA), merge commit yo'q | chiziqli tarix va alohida commit'lar birga kerak |

Yaxshi review ops nuqtai nazaridan: PR kichik (bir necha yuz qatordan kam), bitta maqsadli; infratuzilma o'zgarishida "plan" yoki diff natijasi PR'ga ilova qilinadi; reviewer "ishlaydimi" dan tashqari "buzilsa qanday qaytaramiz" ni so'raydi.

## 6. Workflow'lar va branch himoyasi

| | Trunk-based | GitHub Flow | GitFlow |
|---|-------------|-------------|---------|
| Doimiy branch'lar | `main` | `main` | `main`, `develop` |
| Vaqtinchalik | juda qisqa feature branch (soatlar, 1–2 kun) yoki to'g'ridan-to'g'ri `main` | feature branch + PR | `feature/*`, `release/*`, `hotfix/*` |
| Reliz | `main` dan istalgan payt, tag yoki qisqa release branch | merge qilindi, deploy qilindi | `release/*` barqarorlashtiriladi, `main` ga merge va tag |
| Tugallanmagan ish | feature flag ortida `main` da | branch'da | `develop` da to'planadi |
| Mos keladi | CI/CD kuchli, tez-tez deploy | web servislar, kichik va o'rta jamoa | versiyalangan mahsulot, bir nechta qo'llab-quvvatlanadigan reliz |
| Narxi | kuchli avtomatik testlar va feature flag intizomi shart | `main` har doim deploy qilinadigan holatda bo'lishi kerak | uzoq yashaydigan branch'lar, katta merge'lar, sekin yetkazish |

Ops xulosalari:

- Branch qancha uzoq yashasa, integratsiya shuncha og'riqli va xavfli. "Accelerate" (DORA) tadqiqotlari qisqa branch va tez-tez integratsiyani yuqori yetkazib berish ko'rsatkichlari bilan bog'laydi.
- GitFlow muallifining o'zi keyinroq uzluksiz yetkaziladigan web ilovalar uchun soddaroq oqimni (GitHub Flow kabi) tavsiya qilgan. GitFlow bir nechta versiyani parallel qo'llab-quvvatlash kerak bo'lganda o'rinli.
- Workflow CI/CD dizaynini belgilaydi: qaysi branch qaysi muhitga deploy bo'ladi, reliz tag'dan chiqadimi yoki merge'danmi.
- "Muhit boshiga branch" (`dev`, `staging`, `prod` branch'lari orasida merge) keng tarqalgan anti-pattern: muhitlar kod jihatdan ajralib ketadi. Bitta artefakt muhitlar bo'ylab ko'tariladi, farq konfiguratsiyada.

### Protected branch

Himoya qoidalari **server tomonda** tekshiriladi, shuning uchun chetlab o'tib bo'lmaydi: to'g'ridan-to'g'ri push taqiqi (faqat PR orqali), N ta tasdiq, CI'dan o'tish sharti (required status checks), force push va o'chirish taqiqi, chiziqli tarix talabi, imzolangan commit talabi, qoidalar adminlarga ham amal qilishi. Aniq sozlash 4-darsda.

## 7. Hook'lar

Hook bu Git ma'lum hodisada ishga tushiradigan bajariluvchi fayl. Lokal hook'lar `.git/hooks/` da (namunalar `*.sample`), nol bo'lmagan exit code amalni to'xtatadi.

| Hook | Qayerda | Qachon | Odatiy vazifa |
|------|---------|--------|---------------|
| `pre-commit` | client | commit'dan oldin, xabarsiz | lint, format, secret qidirish |
| `commit-msg` | client | xabar yozilgach; `$1` xabar fayli yo'li | xabar formatini tekshirish |
| `pre-push` | client | push'dan oldin | testlar, himoyalangan branch'ga push'ni to'xtatish |
| `pre-receive`, `update` | server | push qabul qilinishidan oldin | siyosat: majburiy qoidalar |
| `post-receive` | server | push qabul qilingach | xabarnoma, deploy trigger |

**Tuzoq: client-side hook himoya emas.** `.git/hooks` klon bilan birga kelmaydi (har kim o'zi o'rnatadi) va `git commit --no-verify` uni chetlab o'tadi. Client hook tez teskari aloqa uchun, majburiy siyosat esa server tomonda: protected branch, server hook, CI'dagi required check. Bir xil tekshiruv ikkala joyda ham turadi.

Hook'larni jamoa bilan bo'lishish: `git config core.hooksPath .githooks` (repo ichidagi katalog), yoki **pre-commit** freymvorki: repo ildizidagi `.pre-commit-config.yaml` hook'lar ro'yxatini versiyasi bilan saqlaydi.

```
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: check-yaml
      - id: check-added-large-files
      - id: detect-private-key
```

`pre-commit install` hook'ni `.git/hooks/pre-commit` ga yozadi, `pre-commit run --all-files` butun repo bo'yicha ishlatadi (CI'da aynan shu buyruq), `pre-commit autoupdate` `rev` larni yangilaydi. Secret qidirish uchun `gitleaks` kabi asboblar ham shu yerga hook bo'lib ulanadi.

## Tuzoqlar

- Umumiy branch'ga `git push --force`: boshqalarning push qilgan commit'lari yo'qoladi. O'z branch'ingizda ham `--force-with-lease`.
- `origin/main` ni "serverdagi hozirgi holat" deb o'ylash. U oxirgi `fetch` paytidagi nusxa.
- `git pull` ni sozlamasiz ishlatish: kutilmagan merge commit'lar, yoki serverda conflict bilan to'xtab qolgan deploy. Serverda faqat `--ff-only`.
- Private kalitni passphrase'siz saqlash, mashinalar orasida nusxalash yoki repoga commit qilish. Har mashina va har maqsad uchun alohida kalit.
- Client hook'ga siyosat sifatida tayanish. `--no-verify` va yangi klon uni yo'q qiladi.
- Uzoq yashaydigan branch va muhit branch'lari: katta, xavfli merge'lar va muhitlar orasidagi tushunarsiz farq.
- Fork'dan kelgan PR'da CI'ga secret berish: begona kod sizning token'laringiz bilan ishlaydi. Hostinglar buni default cheklaydi, cheklovni o'chirmang.
- Review paytida force push: reviewer nima o'zgarganini ko'ra olmaydi. Tuzatishni alohida commit bilan yuboring, merge'da squash qiling.
- "Verified" belgisi yo'qligini e'tiborsiz qoldirish: author maydoni soxtalashtirilishi mumkin, imzo talabi bo'lmasa buni hech narsa to'xtatmaydi.

## Manbalar

- https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches – Pro Git 3.5, remote-tracking branch (majburiy)
- https://git-scm.com/book/en/v2/Git-Internals-The-Refspec – Pro Git 10.5, refspec
- https://git-scm.com/docs/git-push – `--force-with-lease`, `--force-if-includes`
- https://git-scm.com/docs/githooks – hook'lar ro'yxati va argumentlari
- https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work – Pro Git 7.4, imzolash
- https://docs.github.com/en/authentication/connecting-to-github-with-ssh – SSH kalit sozlash
- https://docs.github.com/en/authentication/managing-commit-signature-verification – commit imzosini tekshirish
- https://docs.github.com/en/pull-requests – pull request hujjatlari
- https://trunkbaseddevelopment.com – trunk-based development
- https://nvie.com/posts/a-successful-git-branching-model/ – GitFlow asl maqolasi va muallifning keyingi izohi
- https://docs.github.com/en/get-started/using-github/github-flow – GitHub Flow
- https://pre-commit.com – pre-commit freymvorki

---

## Vazifalar

A va B guruhlarni `~/git-lab/03/` dagi bare repo va ikki klonda, qolganlarini GitHub'dagi `git-lab-03` reposida bajaring. Javoblarni `git/03-remotes-pr/README.md` ga yozing (papka `make new m=git n=03 name=remotes-pr` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (hook skriptlari, `.pre-commit-config.yaml` nusxasi) shu papkaga saqlanadi. Private kalit va token README'ga ham, ish papkasiga ham tushmasin.

### A. Remote, fetch, pull

1. **Bare repository.** Laboratoriyadagi `server.git` ni yarating va ichini `alice` klonidagi `.git` bilan solishtiring: bare repoda nima yo'q va nima uchun server uchun aynan shu kerak? `alice` dan birinchi commit'ni push qiling, `bob` da `git remote show origin` va `.git/config` dagi refspec'ni izohlang.

2. **Stale tracking ref.** `alice` 2 commit push qilsin. `bob` da `fetch` qilmasdan `git status` va `git log origin/main --oneline` ni ko'ring, keyin `git ls-remote origin` bilan solishtiring. Farqni izohlang. `git fetch` dan keyin nima o'zgardi, `bob` ning lokal `main` i va working tree'si-chi?

3. **Inspect before integrating.** 2-vazifa davomida `bob` da `git log HEAD..origin/main` va `git diff HEAD...origin/main` bilan kelgan o'zgarishlarni ko'ring, keyin `git merge --ff-only origin/main` qiling. Bu `git pull` dan nimasi bilan farq qiladi?

4. **Divergent pull.** `alice` va `bob` ikkalasi `main` ga har xil commit qilsin, `alice` push qilsin. `bob` da `pull.rebase` va `pull.ff` sozlanmagan holda `git pull` qiling va xabarni yozing. Keyin holatni uch nusxada `--no-rebase`, `--rebase`, `--ff-only` bilan sinab, graph'larni solishtiring.

5. **Upstream tracking.** `alice` da `feature` branch yaratib `-u` siz `git push` qiling, xatoni yozing. Upstream'ni o'rnating, `git branch -vv` va `git rev-parse --abbrev-ref @{u}` ni ko'rsating. `bob` da `git switch feature` nima qildi? `git log @{u}..HEAD` qaysi savolga javob beradi?

6. **Prune.** `alice` serverdagi `feature` ni o'chirsin. `bob` da `git branch -r` hali nimani ko'rsatadi? `git fetch --prune` dan keyin-chi? `bob` ning lokal `feature` branch'i qanday holatda (`git branch -vv`)?

### B. Push va force

7. **Non-fast-forward rejection.** `alice` push qilgan holatda `bob` eski `main` dan commit qilib push qilsin. Xato matnini to'liq yozing va uni mexanizm (server ref'ni qanday ko'chiradi) orqali izohlang. To'g'ri hal qiling.

8. **Force overwrites work.** `alice` va `bob` bitta `shared` branch'da ishlasin. `bob` commit push qilsin, `alice` esa `fetch` qilmasdan `amend` qilib `git push --force` qilsin. `bob` ning commit'i serverda qoldimi (`git ls-remote`, yangi klon)? Uni qayerdan tiklash mumkin?

9. **force-with-lease.** 8-vazifani `--force-with-lease` bilan takrorlang: rad etish xabarini yozing. Keyin `alice` da `git fetch` qilib (o'zgarishni integratsiya qilmasdan) yana `--force-with-lease` qiling: nima bo'ldi va nima uchun? `--force-if-includes` qo'shilganda natija qanday?

10. **Rewriting your own branch.** `alice` o'z `feature` branch'ini push qilsin, keyin `main` ustiga rebase qilsin. Oddiy `git push` nima uchun rad etiladi? Xavfsiz force push qiling. Qanday shartda bu amal maqbul, qanday shartda yo'q?

### C. SSH va imzolash

11. **SSH key and config.** Bu dars uchun alohida `ed25519` kalit yarating (passphrase bilan, alohida fayl nomida), public qismini GitHub akkauntingizga qo'shing va `~/.ssh/config` orqali aynan shu kalit ishlatilishini sozlang. `ssh -T git@github.com` va `ssh -vT` chiqishidan qaysi kalit taklif qilinganini ko'rsating. Private kalit faylining huquqlari qanday va nima uchun?

12. **Forged author.** Scratch repoda `user.name` va `user.email` ni o'ylab topilgan shaxs qilib (masalan `Fake CEO`, `ceo@example.com`; haqiqiy odamning ma'lumotini ishlatmang) commit yozing va `git-lab-03` ga push qiling. Git yoki GitHub buni biror joyda tekshirdimi, commit UI'da kimning nomi bilan ko'rindi? Email haqiqiy akkauntga tegishli bo'lganda nima bo'lishini izohlang va xulosa chiqaring.

13. **SSH signing.** SSH kalit bilan commit imzolashni sozlang, imzolangan commit va `git tag -s` bilan tag yarating. `allowed_signers` faylini sozlab `git log --show-signature` va `git verify-tag` natijasini ko'rsating. Kalitni GitHub'ga signing key sifatida qo'shing: 12-vazifadagi commit va imzolangan commit UI'da qanday farq qiladi?

### D. Fork va pull request

14. **Fork and upstream.** Istalgan kichik ochiq reponi fork qiling, klon qilib `upstream` remote qo'shing. Asl repoda yangi commit'lar paydo bo'lganda fork'ning `main` ini yangilash ketma-ketligini yozing (bajarib yoki, yangi commit bo'lmasa, tartibini izohlab). `origin` va `upstream` ga push huquqlaringiz qanday?

15. **PR refs.** `git-lab-03` da branch'dan PR oching. `git ls-remote origin` chiqishidan PR ref'larini toping. PR'ni branch nomi orqali emas, `refs/pull/<N>/head` orqali alohida lokal branch'ga oling. Bu qachon kerak bo'ladi?

16. **Merge methods.** Har birida 3 commit bo'lgan uchta PR oching va ularni uch usulda merge qiling: merge commit, squash, rebase. Har biridan keyin `main` ning graph'ini, commit SHA lari PR'dagi bilan bir xilmi-yo'qmi va butun PR'ni qaytarish (revert) qanday bajarilishini yozing.

17. **Review round.** PR ochib, o'zingizga review izoh qoldiring (qator izohi va "suggested change"). Tuzatishni `--fixup` commit bilan yuboring, merge'dan oldin `--autosquash` va `--force-with-lease` bilan tozalang. Xuddi shu ishni review o'rtasida amend + force push bilan qilganda reviewer nimani yo'qotadi?

18. **Workflow decision.** Uch vaziyat uchun workflow tanlang va 4–6 gapda asoslang: (a) 5 kishilik jamoa, SaaS web servis, kuniga bir necha deploy; (b) mijozlarga o'rnatiladigan dastur, bir vaqtda 2.x va 3.x versiyalar qo'llab-quvvatlanadi; (c) Terraform infratuzilma reposi, 3 muhit. Har biri uchun: doimiy branch'lar, reliz qanday belgilanadi, hotfix yo'li, qaysi branch himoyalanadi.

### E. Hook'lar

19. **commit-msg hook.** `core.hooksPath` orqali ulanadigan `commit-msg` hook yozing: subject 72 belgidan uzun bo'lsa yoki ikkinchi qator bo'sh bo'lmasa commit'ni rad etsin va sababini `stderr` ga yozsin. Yaroqli va yaroqsiz xabarlar bilan sinang. `--no-verify` bilan nima bo'ladi? Skript nusxasi: `commit-msg`.

20. **pre-push guard.** `pre-push` hook yozing: `main` ga to'g'ridan-to'g'ri push'ni to'xtatsin (hook `stdin` dan oladigan ref qatorlarini `man githooks` dan o'qing). Bare repoga qarshi sinang. Yangi klonda hook bormi? Bu himoyani server tomonda nima almashtiradi? Skript nusxasi: `pre-push`.

21. **pre-commit framework.** `git-lab-03` klonida `pre-commit` ni o'rnatib, `.pre-commit-config.yaml` yozing: bo'sh joy, fayl oxiri, YAML sintaksisi, katta fayl va private key tekshiruvlari. Har hook'ni ataylab buzib (xato YAML, 2 MB fayl, soxta private key sarlavhasi) xabarlarni yozing. `pre-commit run --all-files` va `pre-commit autoupdate` nima qiladi? Config nusxasini ish papkasiga saqlang.

22. **Team repo setup.** `git-lab-03` ni "jamoa reposi" holatiga keltiring va README'da hujjatlashtiring: `CONTRIBUTING.md` (tanlangan workflow, branch nomlash, commit xabari qoidasi, merge usuli), `.pre-commit-config.yaml`, `main` uchun himoya (PR majburiy, force push taqiqlangan, chiziqli tarix). Keyin ikki "buzish" sinovi: `main` ga to'g'ridan-to'g'ri push va PR branch'idan `main` ga force push. Server javoblarini yozing va 20-vazifadagi client hook bilan solishtiring: qaysi biri himoya, qaysi biri qulaylik?

### Topshirish

Tayyor bo'lgach:
1. `git/03-remotes-pr/README.md` da 22 ta vazifa, har biri `## N. Title` sarlavhasi ostida.
2. `commit-msg`, `pre-push` skriptlari va `.pre-commit-config.yaml` nusxasi ish papkasida, `make check` toza.
3. Hech qanday private kalit yoki token kurs reposida yo'q.
4. `~/git-lab/03` o'chirilgan, GitHub'dagi fork va (4-darsda kerak bo'lmasa) `git-lab-03` o'chirilgan, sinov kaliti akkauntdan olib tashlangan yoki ataylab qoldirilgan.
5. Menga xabar bering, tekshiraman.

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
