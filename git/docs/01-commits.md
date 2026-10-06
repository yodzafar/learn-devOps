# 1-dars: Commit va object model

Maqsad: Git'ni buyruqlar to'plami sifatida emas, ma'lumotlar tuzilmasi sifatida ko'rish. Siz `add`, `commit`, `push` ni har kuni ishlatasiz, lekin `.git` papkasi ichida nima yotishini ko'rmagansiz. Bu darsda commit, tree va blob obyektlari qanday bog'langanini, working tree, index va repository orasida ma'lumot qanday ko'chishini va har bir "bekor qilish" buyrug'i aynan qaysi qatlamni o'zgartirishini noldan ochamiz. Ops ishida bu bilim hodisa paytida kerak bo'ladi: noto'g'ri `reset`, yo'qolgan commit, tarixga tushib qolgan secret. 2-darsdagi branch, merge va rebase shu modelning ustiga quriladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh vazifalari, ikkinchi kun 3–5 bo'limlar va B, C guruhlari, uchinchi kun 6-bo'lim, "Birga bajaramiz", D guruhi va 20-vazifa. Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: SHA qayerdan keladi, index nima uchun alohida qatlam, `reset` ning uch rejimi qaysi qatlamda to'xtaydi, `revert` va `reset` farqi, `reflog` nimani tiklay oladi va nimani yo'q.

Qanday o'qish kerak: har bo'limdagi misolni scratch repoda o'zingiz terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Blob va tree SHA'lari faqat tarkibga bog'liq, shuning uchun sizda ham aynan darsdagidek chiqishi kerak (chiqmasa, fayl tarkibi farq qiladi). Commit SHA'lari esa vaqt va muallifga bog'liq, sizda boshqa bo'ladi; darsda ular `<sha>` deb belgilangan.

## Laboratoriya

Bu dars to'liq host'da bajariladi, `lab` VM kerak emas: Git ikkala mashinada bir xil ishlaydi. Yagona talab `SETUP.md` dagi asosiy asboblar (`git`, `make`) o'rnatilgan bo'lishi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host, scratch repo (`~/git-lab/01/...`) | `user@host:~/git-lab/01/demo$` yoki `%` (zsh) | barcha tajribalar va vazifalar |
| Host, kurs reposi | `.../dev-ops$` | faqat javob yozish (`git/01-commits/README.md`) va `make check` |

Scratch repo bu tajriba uchun yaratilgan, istalgan payt o'chirib tashlash mumkin bo'lgan repo. Kurs reposi ichida `git init` qilmang: ichki repo "embedded repository" bo'lib qoladi va kurs reposining tarixiga aralashadi.

```
mkdir -p ~/git-lab/01 && cd ~/git-lab/01
git init -b main demo && cd demo
git config user.name "Lab User"          # local config, only this repo
git config user.email "lab@example.com"
```

`git init -b main demo` `demo` papkasini yaratadi, ichida `.git` papkasini ochadi va birinchi branch nomini `main` qiladi. `git config` bu yerda `--global` siz yozilgan, ya'ni sozlama faqat shu reponing `.git/config` fayliga tushadi va sizning haqiqiy ismingiz, global sozlamalaringiz tegilmaydi. Global sozlamalarni ko'rish uchun: `git config --list --show-origin` (har qator qaysi fayldan kelganini ko'rsatadi).

- Javoblar `git/01-commits/README.md` ga yoziladi (papka `make new m=git n=01 name=commits` bilan yaratiladi).
- Tozalash: `rm -rf ~/git-lab/01`.
- Bu dars oldingi holatga tayanmaydi. Scratch repolar har mashinada lokal va ko'chmaydi: ofisda boshlagan vazifani uyda davom ettirmoqchi bo'lsangiz, scratch repo'ni uyda qaytadan yarating, javoblar (README) esa kurs reposi orqali `git push` va `git pull` bilan ko'chadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Git `apt` dan, Ubuntu 24.04 da `git version 2.43.0`. Fayl tizimi (ext4) katta-kichik harfni farqlaydi: `README.md` va `readme.md` ikki alohida fayl. |
| macOS (uy) | Git Xcode Command Line Tools bilan keladi (`xcode-select --install`), versiya `git version <N> (Apple Git-<NN>)` ko'rinishida va odatda Ubuntu'dagidan eskiroq. Bu darsdagi hamma narsa (`git init -b` 2.28 dan, `git restore` 2.23 dan) unda ishlaydi; tekshirish: `git --version`. Yangiroq kerak bo'lsa `brew install git`. Fayl tizimi (APFS) standart holatda katta-kichik harfni farqlamaydi: `README.md` va `readme.md` bitta fayl, Git `core.ignorecase=true` qo'yadi. Finder har papkaga `.DS_Store` fayli tashlaydi, u 5-bo'limdagi global ignore uchun yaxshi misol. |

---

## 1. Object model

### Bu nima

Git bu **content-addressable storage**, ya'ni "tarkib bo'yicha manzillanadigan ombor": har bir saqlangan narsa (obyekt) o'z tarkibining hash'i bilan nomlanadi. Hash bu istalgan uzunlikdagi baytlardan hisoblanadigan qat'iy uzunlikdagi "barmoq izi": tarkib bir bayt o'zgarsa, hash butunlay boshqa chiqadi. Git'da bu SHA-1, 40 ta o'n oltilik belgi. Obyektlar `.git/objects/` ichida yotadi. To'rt tur bor:

| Obyekt | Nima saqlaydi | Nima saqlamaydi |
|--------|---------------|-----------------|
| blob | fayl tarkibi (baytlar) | fayl nomi, huquqlar |
| tree | katalog: `mode`, tur, SHA, nom qatorlari (blob va boshqa tree'larga ishora) | fayl tarkibi |
| commit | bitta root tree SHA, parent commit(lar) SHA, author, committer, vaqt, xabar | diff |
| tag | annotated tag: nishon obyekt SHA, tagger, xabar (2-darsda) | |

Frontend o'xshatishi: bundler chiqaradigan `app.3f9a1c.js` dagi `3f9a1c` ham tarkib hash'i. Tarkib o'zgarmasa nom o'zgarmaydi, shuning uchun kesh ishonchli. Git xuddi shu g'oyani butun loyiha tarixiga qo'llaydi.

### Mexanizm: SHA qanday hisoblanadi

SHA-1 `"<type> <size>\0<content>"` satridan olinadi (`\0` nol bayt). Fayl nomi, sana, mashina nomi formulaga kirmaydi, shuning uchun natija faqat tarkibga bog'liq va har mashinada bir xil:

```
$ echo 'hello' | git hash-object --stdin
ce013625030ba8dba906f756967f9e9ca394464a
```

`git hash-object` tarkibdan SHA hisoblaydi (bu holda hech narsa yozmaydi, `-w` flag'i bilan yozadi). Sizda ham aynan shu 40 belgi chiqadi, Zorin'da ham, Mac'da ham. `echo` oxiriga `\n` qo'shadi, tarkib 6 bayt: `hello\n`.

Obyekt diskda zlib bilan siqilgan fayl sifatida yotadi, yo'li SHA'ning o'zi: birinchi 2 belgi katalog, qolgan 38 tasi fayl nomi (`.git/objects/ce/013625...`). `cat` bilan o'qib bo'lmaydi, buning uchun `git cat-file` bor: `-t` turini, `-p` tarkibini odam o'qiydigan shaklda ko'rsatadi.

### Misol: bitta commit ichida nima bor

Yangi repoda ikki fayl yaratamiz (`~/git-lab/01/notes`, yaratish buyruqlari Laboratoriya bo'limidagidek):

```
$ printf 'buy milk\n' > todo.txt
$ mkdir conf && printf 'port=8080\n' > conf/app.ini
$ git add todo.txt conf
$ git commit -q -m "Add todo list and app config"
$ find .git/objects -type f | wc -l
5
```

Besh obyekt: ikki blob (ikki fayl), ikki tree (ildiz katalog va `conf`), bitta commit. Endi yuqoridan pastga tushamiz:

```
$ git cat-file -p HEAD
tree 8921adc72ec9dc22a0bc85cf571c2e77283e5195
author Lab User <lab@example.com> <vaqt> +0500
committer Lab User <lab@example.com> <vaqt> +0500

Add todo list and app config
```

Qatorma-qator: `tree` bu commit'ning root tree'si, ya'ni loyihaning shu paytdagi to'liq holati; `author` o'zgarishni yozgan odam va vaqt (Unix soniyalari va vaqt zonasi); `committer` uni tarixga qo'ygan odam; bo'sh qatordan keyin xabar. `parent` qatori yo'q, chunki bu birinchi commit. Diff ham yo'q: commit diff saqlamaydi.

```
$ git cat-file -p 'HEAD^{tree}'
040000 tree f2300616277f845e86ded3e0bebf75432badd14d	conf
100644 blob 033cf0e445d41ea46c78db8a666132423a10fe4b	todo.txt
$ git cat-file -p 'HEAD^{tree}:conf'
100644 blob fc6826aa998f757813aa4c9d806c3b3e61cf5592	app.ini
$ git cat-file -p 033cf0e
buy milk
```

`HEAD^{tree}` "HEAD commit'ining tree'si" degani (zsh'da `^` va `{}` maxsus belgilar, shuning uchun qo'shtirnoq ichida). Har qator to'rt maydon: `mode` (`100644` oddiy fayl, `100755` bajariladigan fayl, `040000` katalog), obyekt turi, SHA, nom. Fayl nomi blob'da emas, aynan shu yerda, tree'da saqlanadi. Oxirgi buyruq blob'ni ochadi: ichida faqat tarkib. SHA'ni to'liq yozish shart emas, repo ichida yagona bo'lsa 7 belgi yetadi.

Sxema:

```
commit <sha>  ──tree──▶  tree 8921adc (root)
                          ├── blob 033cf0e  todo.txt   "buy milk"
                          └── tree f230061  conf
                               └── blob fc6826a  app.ini   "port=8080"
```

### Asosiy xulosalar

- **Commit bu diff emas, snapshot.** Har commit butun loyiha holatining root tree'siga ishora qiladi. `git show` dagi diff har safar parent bilan solishtirib hisoblanadi.
- **O'zgarmagan fayl qayta saqlanmaydi.** Tarkib bir xil bo'lsa blob SHA bir xil, yangi tree eski blob'ga ishora qiladi. Bir xil tarkibli ikki fayl ham bitta blob. `todo.txt` ni o'zgartirib ikkinchi commit qilsangiz, yangi root tree'da `conf` qatori aynan o'sha `f230061` bo'lib qoladi.
- **Obyektlar o'zgarmas (immutable).** "Commit'ni o'zgartirish" degan narsa yo'q: `amend`, `rebase` yangi SHA li yangi commit yaratadi, eskisi o'z joyida qoladi (shuning uchun tiklash mumkin).
- **Tarix bu DAG** (directed acyclic graph, yo'nalgan va aylanasiz graf). Commit parent'iga ishora qiladi, parent bolasini bilmaydi. Parent SHA commit tarkibiga kirgani uchun eski commit'ni o'zgartirish undan keyingi barcha commit'lar SHA sini o'zgartiradi.

### Ref va HEAD

40 belgili SHA'ni odam eslab qolmaydi, shuning uchun **ref** bor: ichida bitta SHA yozilgan kichik matn fayli. Branch bu ref (`.git/refs/heads/main`). `HEAD` esa "hozir qayerdaman" ko'rsatkichi, odatda branch'ga ishora qiladi:

```
$ cat .git/HEAD
ref: refs/heads/main
$ cat .git/refs/heads/main
<sha>
```

Yangi commit qilinganda Git commit obyektini yozadi va `refs/heads/main` ichidagi SHA'ni yangisiga almashtiradi. "Branch oldinga siljidi" degani shu, boshqa hech narsa emas. Batafsil 2-darsda.

### Packfile

Ko'p obyekt to'planganda `git gc` (garbage collection, keraksiz obyektlarni yig'ishtirish va siqish) ularni packfile'ga (`.git/objects/pack/`) yig'adi va o'xshash obyektlarni delta (farq) sifatida saqlaydi. Shuning uchun "har commit to'liq snapshot" bo'lsa ham repo kichik qoladi. Hajm: `git count-objects -vH` (`count` alohida fayl ko'rinishidagi obyektlar, `in-pack` packfile ichidagilar).

### Revision yozuvlari

Commit'ni SHA'siz ko'rsatish usullari:

| Yozuv | Ma'nosi |
|-------|---------|
| `HEAD~2` | birinchi parent bo'ylab 2 qadam orqaga |
| `HEAD^2` | merge commit'ning ikkinchi parent'i |
| `main@{1}`, `HEAD@{2}` | reflog'dagi avvalgi holat (6-bo'lim) |
| `A..B` | `B` dan yetiladigan, `A` dan yetilmaydigan commit'lar |
| `A...B` | ikkalasidan biridan yetiladigan, umumiy bo'lmaganlar; `diff` da: merge base'dan `B` gacha |
| `HEAD:path/file` | o'sha commit'dagi fayl (blob) |

To'liq ro'yxat: `man gitrevisions`.

### Real ishda qachon kerak

- CI "commit `abc1234` da build yiqildi" deydi: bu SHA aynan bitta snapshot'ni bildiradi, uni istalgan mashinada `git checkout abc1234` bilan aynan qayta tiklash mumkin. Deploy'lar shuning uchun branch nomiga emas, SHA'ga bog'lanadi.
- "Kim buni o'zgartirdi" savoli: commit'dagi `author` va `committer` maydonlari.
- Repo hajmi kutilmaganda o'sdi: `git count-objects -vH` va katta blob'ni qidirish.

### Nima uchun shunday

Git 2005-yilda Linux kernel'i uchun yozilgan: minglab dasturchi, markaziy server yo'q, tarix buzilmasligi shart. Tarkib hash'i uchala talabni birdan yechadi: bir xil tarkib har joyda bir xil nom oladi (markaziy raqamlash kerak emas), har commit o'zidan oldingi butun tarixning hash'ini o'z ichiga oladi (bitta bayt o'zgarsa SHA mos kelmaydi), snapshot'larni solishtirish esa SHA'ni solishtirish kabi arzon. Muqobil yondashuv (SVN) har fayl uchun diff'lar zanjirini saqlaydi; unda branch va merge qimmat. Git SHA-256 formatini ham qo'llaydi (`git init --object-format=sha256`), lekin hostinglar va asboblar hali asosan SHA-1 repolar bilan ishlaydi.

## 2. Uch qatlam: working tree, index, repository

### Bu nima

| Qatlam | Qayerda | Nima |
|--------|---------|------|
| working tree | loyiha katalogi | siz tahrirlaydigan oddiy fayllar |
| index (staging area) | `.git/index` | keyingi commit'ning tayyorlanayotgan snapshot'i |
| repository | `.git/objects` + ref'lar | commit qilingan tarix |

### Mexanizm

Index "o'zgarishlar ro'yxati" emas, to'liq snapshot: har kuzatilayotgan (tracked) fayl uchun blob SHA saqlaydi. `git add` ikki ish qiladi: fayl tarkibini blob qilib `.git/objects` ga yozadi va index'dagi shu fayl qatoriga yangi SHA'ni qo'yadi. `git commit` index'dan tree obyektlarini yasaydi, commit obyektini yozadi va branch ref'ini siljitadi. Demak blob `add` paytida paydo bo'ladi, commit paytida emas.

### Misol: add paytida nima bo'ladi

Bo'sh repoda (hali commit yo'q) faqat `todo.txt` ni qo'shamiz:

```
$ find .git/objects -type f | wc -l
0
$ git add todo.txt
$ find .git/objects -type f
.git/objects/03/3cf0e445d41ea46c78db8a666132423a10fe4b
$ git ls-files -s
100644 033cf0e445d41ea46c78db8a666132423a10fe4b 0	todo.txt
$ git status -sb
## No commits yet on main
A  todo.txt
?? conf/
```

`add` dan oldin obyekt yo'q, keyin bitta: blob. Commit hali yo'q, lekin tarkib allaqachon omborda. `git ls-files -s` index'ni ko'rsatadi: mode, blob SHA, stage raqami (`0` oddiy holat, 1–3 merge conflict paytida, 2-darsda), fayl nomi. `git status -sb` qisqa format: birinchi qator branch, keyin har faylga ikki ustun. Chap ustun index holati (`A` qo'shilgan), o'ng ustun working tree holati. `??` kuzatilmayotgan (untracked) fayl yoki katalog.

### Misol: uch xil diff

Birinchi commit'dan keyin `todo.txt` ga qator qo'shib `add` qilamiz, keyin yana bir qator qo'shamiz (`add` siz):

```
$ printf 'call bank\n' >> todo.txt && git add todo.txt
$ printf 'fix bike\n' >> todo.txt
$ git status -sb
## main
MM todo.txt
```

`MM`: chap `M` index HEAD'dan farq qiladi, o'ng `M` working tree index'dan farq qiladi. Bitta faylning uch xil versiyasi bor: HEAD'da 1 qator, index'da 2 qator, diskda 3 qator.

```
$ git diff
...
 buy milk
 call bank
+fix bike
$ git diff --staged
...
 buy milk
+call bank
```

| Buyruq | Nimani nima bilan solishtiradi |
|--------|--------------------------------|
| `git diff` | working tree va index (hali stage qilinmagan narsa) |
| `git diff --staged` | index va HEAD (keyingi commit'ga aynan nima tushadi) |
| `git diff HEAD` | working tree va HEAD (ikkalasi birga) |

**Tuzoq: `add` dan keyin faylni yana tahrirlasangiz, commit'ga `add` paytidagi versiya tushadi.** Yuqoridagi holatda `git commit` qilsangiz `fix bike` commit'ga kirmaydi. `git commit -a` kuzatilayotgan fayllarni avtomatik stage qiladi, lekin yangi (untracked) fayllarni qo'shmaydi.

### Qismlab stage qilish: `add -p`

Hunk bu diff'ning bitta uzluksiz bo'lagi (`@@ -1,2 +1,3 @@` bilan boshlanadi). `git add -p` har hunk uchun so'raydi: `y` qo'shish, `n` o'tkazish, `s` hunk'ni bo'lish, `e` qo'lda tahrirlash, `q` chiqish, `?` yordam. Maqsad: bitta ish seansida qilingan ikki mustaqil o'zgarishni ikki alohida commit'ga ajratish. Simmetrik buyruqlar: `git restore -p --staged` (index'dan qismlab chiqarish), `git restore -p` (working tree'dan qismlab tashlash). Commit'dan oldin `git diff --staged` ni o'qish odat bo'lsin.

### Real ishda qachon kerak

- Bugfix ustida ishlayotib yo'l-yo'lakay formatlashni ham tuzatdingiz: `add -p` bilan ikki commit, review osonlashadi va bugfix'ni alohida revert qilish mumkin.
- CI'da "file not found", lokalda hammasi ishlaydi: yangi fayl untracked qolgan, `git status` da `??`.
- Debug uchun qo'shilgan `console.log` commit'ga tushmasligi kerak: uni stage qilmaysiz, `git diff --staged` bilan tekshirasiz.

### Nima uchun shunday

Ko'p versiya nazorati tizimlarida commit "diskdagi hamma o'zgarish" degani. Git o'rtaga index qo'ydi, chunki ish jarayoni va toza tarix ikki xil narsa: siz tartibsiz ishlaysiz, tarix esa mantiqiy bo'laklarga bo'linishi kerak. Index shu bo'laklarni yig'adigan stol. Ikkinchi sabab tezlik: index har faylning SHA'si va vaqt belgisini saqlaydi, shuning uchun `git status` minglab faylni qayta o'qimasdan nima o'zgarganini biladi. Merge conflict ham index'da yechiladi (2-dars).

## 3. Yaxshi commit

### Bu nima va nima uchun muhim

Commit review, `bisect` (xato kirgan commit'ni ikkiga bo'lib qidirish, 2-dars), `revert` va `cherry-pick` birligi. Shuning uchun **atomik** bo'lishi kerak: bitta mantiqiy o'zgarish, alohida olinganda build va testlar o'tadi. "Refactor + bugfix + format" bitta commit'da bo'lsa, bugfix'ni alohida revert qilib bo'lmaydi.

### Xabar formati

```
Fix nginx upstream timeout for slow report endpoint

Reports over 50k rows take ~40s to render and hit the default
30s proxy_read_timeout, returning 504 to the client.
Raise the timeout only for /reports, keep the global default.

Refs: OPS-142
```

- 1-qator (subject): taxminan 50 belgigacha, buyruq maylida ("Fix", "Add", "Remove"), oxirida nuqtasiz. `git log --oneline` va PR sarlavhalari shundan olinadi.
- 2-qator bo'sh. Bo'lmasa asboblar subject va body'ni ajrata olmaydi.
- Body: taxminan 72 belgida o'ralgan, **nima uchun** degan savolga javob beradi. "Nima" o'zgargani diff'da ko'rinadi, sabab esa faqat shu yerda saqlanadi.
- Oxirida trailer'lar (`Kalit: qiymat` ko'rinishidagi yakuniy qatorlar): `Refs:`, `Co-authored-by:`, `Signed-off-by:` (`git commit -s`).
- Conventional Commits (`feat:`, `fix:`, `chore:` ...) jamoa kelishuvi, changelog va versiyani avtomatik chiqarish uchun ishlatiladi. Frontend'da `commitlint` va `semantic-release` shu kelishuvga tayanadi. Git buni talab qilmaydi, tekshiruv hook yoki CI orqali qo'yiladi (3-darsda).

Ko'p qatorli xabar uchun `-m` ishlatmang: `git commit` (flag'siz) editor ochadi. Qaysi editor ochilishi `core.editor` sozlamasi yoki `EDITOR` o'zgaruvchisidan olinadi.

### Author va committer

Ikki alohida maydon: author o'zgarishni yozgan, committer uni tarixga qo'ygan. Oddiy commit'da ikkalasi bir xil. `amend`, rebase, cherry-pick da author va uning sanasi saqlanadi, committer va uning sanasi yangilanadi. Ko'rish:

```
$ git log --format=fuller -1
commit <sha>
Author:     Lab User <lab@example.com>
AuthorDate: <sana>
Commit:     Lab User <lab@example.com>
CommitDate: <sana>

    Add todo list and app config
```

### Real ishda qachon kerak

Tungi hodisada `git log --oneline` bilan oxirgi deploy'ga nima kirganini o'qiysiz. "wip", "fix", "update" degan uch commit hech narsa aytmaydi; "Raise proxy_read_timeout for /reports" esa aybdorni bir daqiqada topadi. Infratuzilma repolarida (Terraform, Kubernetes manifestlari) commit xabari ko'pincha "nima uchun production shunday sozlangan" degan savolga yagona hujjat.

### Nima uchun shunday

50/72 qoidasi Git'ning kelib chiqishidan: kernel dasturchilari patch'larni email orqali yuborgan, subject xat sarlavhasiga, body 80 ustunli terminalga sig'ishi kerak edi. Asboblar (`log --oneline`, GitHub PR sarlavhasi, `git shortlog`) hozir ham shu tuzilmaga tayanadi. Author va committer ajratilishi ham o'shandan: patch'ni bir odam yozadi, maintainer tarixga qo'yadi.

## 4. Tarixni o'qish

### Bu nima

`git log` commit'lar grafini `HEAD` dan boshlab parent'lar bo'ylab orqaga yuradi. Flag'lar ikki ish qiladi: qaysi commit'lar ko'rsatilishini filtrlaydi va har commit qanday ko'rsatilishini belgilaydi.

| Buyruq | Nima uchun |
|--------|-----------|
| `git log --oneline --graph --decorate --all` | butun DAG, branch va tag'lar bilan |
| `git log -p -- path` | fayl bo'yicha commit'lar va diff'lari |
| `git log --stat` | har commit'da qaysi fayl necha qator o'zgargan |
| `git log -S'text'` | `text` uchrashlari soni o'zgargan commit'lar (pickaxe): "bu qator qachon paydo bo'ldi yoki yo'qoldi" |
| `git log -G'regex'` | diff'i regex'ga mos commit'lar |
| `git log --grep='pattern'` | xabari bo'yicha qidirish |
| `git log --since='2 weeks ago' --author='name'` | vaqt va muallif filtri |
| `git log --follow -- path` | fayl nomi o'zgargan bo'lsa ham tarixini kuzatish |
| `git show <sha>` | commit va uning diff'i; `git show <sha>:path` o'sha paytdagi fayl |
| `git blame -L 10,20 file` | qatorlarni oxirgi o'zgartirgan commit'lar |

`-- path` dagi `--` "bundan keyin flag emas, fayl yo'li" degani; fayl nomi branch nomi bilan bir xil bo'lsa chalkashlikni oldini oladi.

### Misol

Uch commit'li `notes` reposida:

```
$ git log --oneline
<sha3> Add bike
<sha2> Add bank call
<sha1> Add todo list and app config
$ git log --oneline -S'bank' -- todo.txt
<sha2> Add bank call
$ git show <sha1>:todo.txt
buy milk
```

Birinchi buyruq: yangi commit tepada, har qatorda qisqa SHA va subject. Ikkinchisi: `bank` so'zi uchrashlari soni o'zgargan yagona commit, ya'ni u qo'shilgan joy. Uchinchisi: fayl checkout qilinmasdan, o'sha commit'dagi tarkibi to'g'ridan-to'g'ri blob'dan o'qildi.

### Rename mexanizmi

Git rename'ni saqlamaydi: tree'da faqat eski nom yo'qolib, yangisi paydo bo'ladi. `git mv a b` aslida `mv a b` + `git rm a` + `git add b`. `log --follow`, `diff -M` rename'ni tarkib o'xshashligidan taxmin qiladi (standart chegara 50%). Shuning uchun faylni ko'chirish va ichini katta o'zgartirishni alohida commit'larga ajrating.

### Real ishda qachon kerak

- "Bu timeout qiymati qachon va nima uchun 30 ga tushirilgan?": `git log -S'timeout 30' -- nginx.conf`, keyin `git show`.
- "Juma kungi deploy'dan beri nima o'zgardi?": `git log --oneline <eski-sha>..HEAD --stat`.
- Postmortem yozishda `git blame` qatorni commit'ga, commit xabari esa sababga olib boradi.

### Nima uchun shunday

Rename'ni saqlamaslik ataylab qilingan: snapshot modeli "nima bo'lgan" ni saqlaydi, "qanday qilib" ni emas. Shu tufayli funksiyaning bir fayldan boshqasiga ko'chishini ham (`git blame -C`) kuzatish mumkin, rename yozuviga tayanadigan tizim esa buni ko'rmaydi. Narxi: taxmin ba'zan adashadi.

## 5. .gitignore

### Bu nima

`.gitignore` bu Git'ga "bu fayllarni untracked ro'yxatida ko'rsatma va `git add .` bilan qo'shma" deydigan qoidalar fayli. Frontend'dan tanish: `node_modules/`, `dist/`, `.env`. Ops'da ro'yxat uzunroq: `terraform.tfstate`, `.terraform/`, kubeconfig, kalitlar, dump'lar.

### Qoidalar (`man gitignore`)

| Qator | Ma'nosi |
|-------|---------|
| `*.log` | istalgan chuqurlikdagi `.log` fayllar |
| `/build` | faqat `.gitignore` turgan katalogdagi `build` |
| `logs/` | faqat katalog (shu nomli fayl emas) |
| `**/tmp` | istalgan chuqurlikdagi `tmp` |
| `!keep.log` | istisno (negation): oldingi qoida ignore qilgan faylni qaytaradi |

- Keyingi qator oldingisini bekor qiladi. Lekin ota katalog ignore qilingan bo'lsa, ichidagi faylni `!` bilan qaytarib bo'lmaydi, chunki Git ignore qilingan katalog ichiga kirmaydi.
- Uch daraja: repo ichidagi `.gitignore` (commit qilinadi, jamoa uchun), `.git/info/exclude` (faqat shu klon), global fayl (`core.excludesFile`, default `~/.config/git/ignore`; IDE va OS fayllari uchun, masalan Mac'dagi `.DS_Store`).
- Diagnostika: `git check-ignore -v path` qaysi fayl, qaysi qator sabab ekanini ko'rsatadi; `git status --ignored`.

```
$ printf '*.log\n!keep.log\n' > .gitignore
$ git check-ignore -v debug.log
.gitignore:1:*.log	debug.log
$ git check-ignore -v keep.log
.gitignore:2:!keep.log	keep.log
$ git check-ignore -v todo.txt; echo "exit=$?"
exit=1
```

Chiqish formati: `fayl:qator:qoida`, keyin tekshirilgan yo'l. Ikkinchi holatda mos kelgan qoida `!` bilan boshlanadi, ya'ni fayl ignore qilinmagan, lekin qaysi qator hal qilgani ko'rinadi. Uchinchisida hech qoida mos kelmadi: chiqish bo'sh va exit code `1`.

**Tuzoq: `.gitignore` faqat untracked fayllarga ta'sir qiladi.** Allaqachon commit qilingan fayl ignore ro'yxatiga qo'shilsa ham kuzatilaveradi. Kuzatuvdan chiqarish: `git rm --cached path` (fayl diskda qoladi, index'dan chiqadi) va commit.

**Tuzoq: secret tarixda qoladi.** `.env` ni keyingi commit'da o'chirish uni tarixdan olib tashlamaydi: 1-bo'limdan bilasiz, eski commit va uning blob'i o'zgarmas. `git show <old-sha>:.env` hali ishlaydi, klon qilgan har kim ko'radi. To'g'ri tartib: avval secret'ni almashtirish (rotate, ya'ni eskisini bekor qilib yangisini chiqarish), keyin kerak bo'lsa tarixni `git filter-repo` bilan tozalash. Push qilingan secret'ni oshkor bo'lgan deb hisoblang.

### Real ishda qachon kerak

Terraform reposining birinchi commit'idan oldin `.gitignore` yoziladi: `terraform.tfstate` ichida parollar ochiq matnda bo'lishi mumkin. Kimdir `git add .` qilgan repoda "nima uchun bu fayl ko'rinmayapti" yoki "nima uchun bu fayl ignore bo'lmayapti" savoliga `git check-ignore -v` bir soniyada javob beradi.

### Nima uchun shunday

Ignore qoidalari index'ga emas, faqat "untracked fayllarni ko'rsatish va qo'shish" bosqichiga ulangan. Tracked fayl uchun Git allaqachon qaror qabul qilgan (u index'da), shuning uchun ignore unga tegmaydi. Bu kutilmagan tuyuladi, lekin teskarisi xavfliroq bo'lardi: `.gitignore` ga bitta qator qo'shish tarixdagi faylni jimgina yo'qotardi.

## 6. Bekor qilish

### Avval savol

O'zgarish qaysi qatlamda va boshqalar bilan bo'lishilganmi (push qilinganmi)? Javobga qarab buyruq tanlanadi:

| Holat | Buyruq | Nimani o'zgartiradi |
|-------|--------|---------------------|
| working tree'dagi tahrirni tashlash | `git restore file` | working tree (index'dan oladi). Qaytarib bo'lmaydi |
| stage'dan chiqarish | `git restore --staged file` | index (HEAD'dan oladi), working tree tegilmaydi |
| faylni eski commit holatiga keltirish | `git restore --source=<sha> file` | working tree |
| oxirgi commit xabari yoki tarkibini tuzatish | `git commit --amend` | yangi commit, eski o'rniga |
| lokal commit'larni olib tashlash | `git reset` | branch pointer (+ index, + working tree) |
| bo'lishilgan commit'ni bekor qilish | `git revert <sha>` | teskari diff bilan yangi commit |
| untracked fayllarni o'chirish | `git clean -n`, keyin `git clean -fd` | working tree. Qaytarib bo'lmaydi |

Eski qo'llanmalarda `git checkout -- file` va `git reset HEAD file` uchraydi; `git restore` (Git 2.23 dan) shu ikki ishni aniqroq nom bilan qiladi.

### reset: uch rejim

`git reset <commit>` joriy branch pointer'ini `<commit>` ga ko'chiradi. Rejim qolgan ikki qatlamga nima bo'lishini belgilaydi: reset ketma-ket uch qadam qiladi va rejim qayerda to'xtashni aytadi.

| Rejim | Branch pointer | Index | Working tree | Qachon |
|-------|----------------|-------|--------------|--------|
| `--soft` | ko'chadi | tegilmaydi | tegilmaydi | oxirgi N commit'ni bittaga yig'ish: o'zgarishlar staged holda qoladi |
| `--mixed` (default) | ko'chadi | yangi HEAD'ga tenglashadi | tegilmaydi | commit'larni buzib, qaytadan `add -p` bilan ajratish |
| `--hard` | ko'chadi | tenglashadi | tenglashadi | hammasini tashlash. Commit qilinmagan tahrirlar yo'qoladi |

`git reset file` (commit'siz, yo'l bilan) branch'ni ko'chirmaydi, faqat index'dagi faylni HEAD'ga qaytaradi, ya'ni `restore --staged` bilan bir xil.

### revert va amend

`git revert <sha>` commit'ni o'chirmaydi, uning teskari diff'ini yangi commit qilib qo'shadi. Tarix qayta yozilmaydi, shuning uchun push qilingan branch'da yagona xavfsiz usul. Merge commit'ni revert qilishda qaysi parent "asosiy" ekanini ko'rsatish kerak: `git revert -m 1 <merge-sha>`.

`git commit --amend` oxirgi commit o'rniga yangi SHA li commit yaratadi (index'dagi qo'shimchalar bilan; `--no-edit` xabarni saqlaydi). **Qoida: push qilingan va boshqalar ishlatayotgan commit'larni `amend`, `reset`, `rebase` bilan qayta yozmang.** Ularning klonida eski SHA qoladi va keyingi `pull` tarixni chigallashtiradi. O'z feature branch'ingizda qayta yozish mumkin (3-darsda `--force-with-lease`).

### reflog: xavfsizlik to'ri

Har safar `HEAD` yoki branch ko'chganda (commit, reset, checkout, rebase, amend) Git buni lokal jurnalga yozadi: `.git/logs/`. `git reflog` bu jurnalni ko'rsatadi, `HEAD@{1}` bitta amal oldingi holat. Uch commit'li `notes` reposida ikki commit'ni "yo'qotamiz":

```
$ git reset --hard HEAD~2
HEAD is now at <sha1> Add todo list and app config
$ git log --oneline
<sha1> Add todo list and app config
$ git reflog
<sha1> HEAD@{0}: reset: moving to HEAD~2
<sha3> HEAD@{1}: commit: Add bike
<sha2> HEAD@{2}: commit: Add bank call
<sha1> HEAD@{3}: commit (initial): Add todo list and app config
$ git reset --hard 'HEAD@{1}'
HEAD is now at <sha3> Add bike
```

`git log` da bitta commit qoldi, lekin `reflog` `HEAD` ning har bir harakatini eslaydi: eng yangi yozuv tepada, har qatorda `HEAD` o'sha paytda ko'rsatgan SHA, `HEAD@{N}` belgisi va amal nomi. `HEAD@{1}` reset'dan oldingi holat, unga qaytdik va ikkala commit joyida. Commit obyektlari hech qayoqqa ketmagan edi, faqat ularga ishora qiladigan ref qolmagan edi. Yo'qolgan commit'ga nom berish ham mumkin: `git branch rescue <sha3>`.

Chegaralari:

- Reflog **lokal**: push qilinmaydi, klonda bo'lmaydi. Repo katalogi o'chsa reflog ham yo'q.
- Muddati bor: default 90 kun, hech qaysi ref'dan yetilmaydigan yozuvlar uchun 30 kun (`gc.reflogExpire`, `gc.reflogExpireUnreachable`). Keyin `git gc` obyektlarni o'chiradi.
- **Faqat commit qilingan narsa tiklanadi.** `reset --hard` yoki `restore` tashlagan, hech qachon commit qilinmagan tahrir reflog'da yo'q. Bir marta `add` qilingan bo'lsa, blob obyekt sifatida qolgan bo'lishi mumkin: `git fsck --lost-found` dangling (hech narsa ishora qilmaydigan) blob'larni ko'rsatadi.

### Real ishda qachon kerak

- Noto'g'ri deploy production'da: `git revert <sha>` va push. Tarix "nima bo'ldi va qanday tuzatildi" ni saqlaydi, hamkasblarning klonlari buzilmaydi.
- Rebase yoki reset'dan keyin "commit'larim yo'qoldi": `git reflog`, vahimasiz.
- PR ochishdan oldin beshta "wip" commit'ni bitta toza commit'ga yig'ish: `reset --soft`.

### Nima uchun shunday

Obyektlar o'zgarmas bo'lgani uchun Git'da "bekor qilish" deyarli hech qachon o'chirish emas, ko'rsatkichni ko'chirish. Shuning uchun commit qilingan narsa xavfsiz (obyekt qoladi, reflog yo'lni eslaydi), commit qilinmagan narsa esa himoyasiz (u hali obyekt emas). `reset` va `revert` ning ikkalasi ham kerak: birinchisi tarixni qayta yozadi va faqat sizniki bo'lgan commit'larga mos, ikkinchisi tarixga qo'shadi va bo'lishilgan branch uchun.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Object | `.git/objects` da SHA nomi bilan saqlanadigan o'zgarmas birlik: blob, tree, commit yoki tag |
| SHA (hash) | obyekt tarkibidan hisoblangan 40 belgili nom |
| Blob | fayl tarkibi, nomsiz |
| Tree | katalog: nomlar va ular ko'rsatadigan blob/tree SHA'lari |
| Commit | root tree, parent(lar), author, committer va xabar |
| Snapshot | loyihaning bir paytdagi to'liq holati (root tree) |
| DAG | commit'lar parent'lariga ishora qiladigan aylanasiz graf |
| Ref | ichida SHA yozilgan nom: branch, tag |
| HEAD | hozirgi branch'ga (yoki commit'ga) ishora |
| Working tree | diskdagi tahrirlanadigan fayllar |
| Index (staging area) | keyingi commit'ning tayyorlanayotgan snapshot'i |
| Tracked / untracked | index'da bor fayl / Git hali bilmaydigan fayl |
| Hunk | diff'ning bitta uzluksiz bo'lagi |
| Trailer | commit xabari oxiridagi `Kalit: qiymat` qatori |
| Packfile | ko'p obyekt siqib yig'ilgan fayl |
| Reflog | `HEAD` va branch'lar harakatining lokal jurnali |
| Dangling object | hech bir ref yoki obyekt ishora qilmaydigan obyekt |
| Rotate | oshkor bo'lgan secret'ni bekor qilib yangisini chiqarish |

## Tuzoqlar

- `git reset --hard` va `git restore file` commit qilinmagan ishni ogohlantirishsiz o'chiradi. Shubha bo'lsa avval commit yoki `stash` qiling: commit qilingan narsa deyarli har doim tiklanadi.
- `.env` yoki kalit commit qilinib push bo'lsa, o'chirish yetmaydi: secret'ni darhol almashtiring, tarixni tozalash ikkinchi qadam.
- `.gitignore` ga qo'shish kuzatilayotgan faylni chiqarmaydi, `git rm --cached` kerak.
- Bo'lishilgan branch'da `reset` va `amend` o'rniga `revert`. Aks holda hamkasblarning tarixi siznikidan ajraladi.
- `git clean -fdx` ignore qilingan fayllarni ham o'chiradi (`node_modules`, lokal `.env`, `terraform.tfstate`). Avval har doim `-n` bilan quruq ishga tushiring.
- `git add .` kutilmagan fayllarni (dump, build natijasi, kalit) stage qiladi. Commit'dan oldin `git status` va `git diff --staged`.
- `git commit -a` bilan "hammasi commit bo'ldi" deb o'ylash: untracked fayllar tashqarida qoladi, CI'da "file not found".
- Reflog'ga zaxira sifatida tayanish: u faqat shu klonda va vaqtinchalik. Muhim narsa push qilingan bo'lishi kerak.
- Katta binar fayl (dump, arxiv) bir marta commit qilinsa, o'chirilgandan keyin ham har klon uni yuklab oladi.
- zsh'da `HEAD^`, `HEAD@{1}`, `HEAD^{tree}` ni qo'shtirnoqsiz yozish: `^` va `{}` shell tomonidan talqin qilinishi mumkin. Qo'shtirnoq ichida yozing yoki `HEAD~1` ishlating.
- macOS'da faqat harf registri bilan farq qiladigan nom o'zgartirish (`readme.md` → `README.md`): fayl tizimi farqni ko'rmaydi. `git mv readme.md README.md` ishlating; Linux'da (CI, server) bu ikki alohida fayl.

## Manbalar

- https://git-scm.com/book/en/v2/Git-Internals-Git-Objects – Pro Git 10.2, object model (majburiy)
- https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified – Pro Git 7.7, uch qatlam va `reset` (majburiy)
- https://git-scm.com/book/en/v2/Git-Basics-Undoing-Things – Pro Git 2.4
- https://git-scm.com/docs/gitrevisions – revision yozuvlari
- https://git-scm.com/docs/gitignore – ignore qoidalari
- https://git-scm.com/docs/git-reflog – reflog
- https://git-scm.com/docs/git-restore – restore
- https://cbea.ms/git-commit/ – "How to Write a Git Commit Message"
- https://www.conventionalcommits.org – Conventional Commits spetsifikatsiyasi

## Birga bajaramiz

Bitta yaxlit yurish: `notes` reposida fayl uch qatlamdan qanday o'tishini kuzatamiz, commit'ni tuzatamiz, xato reset qilamiz va tiklaymiz. Hammasi host'da, ikkala mashinada bir xil.

1. Repo va birinchi commit:

```
$ mkdir -p ~/git-lab/01 && cd ~/git-lab/01
$ git init -q -b main notes && cd notes
$ git config user.name "Lab User" && git config user.email "lab@example.com"
$ printf 'buy milk\n' > todo.txt
$ mkdir conf && printf 'port=8080\n' > conf/app.ini
$ git add todo.txt conf && git commit -q -m "Add todo list and app config"
$ git cat-file -p 'HEAD^{tree}'
040000 tree f2300616277f845e86ded3e0bebf75432badd14d	conf
100644 blob 033cf0e445d41ea46c78db8a666132423a10fe4b	todo.txt
```

Sizdagi ikki SHA aynan shunday bo'lishi kerak: tarkib bir xil, demak nom bir xil. Farq qilsa, `printf` satrini tekshiring (`cat -A todo.txt` Linux'da, `cat -e todo.txt` ikkalasida qator oxirini ko'rsatadi).

2. Faylni ikki bosqichda o'zgartiramiz va uch versiyani ko'ramiz:

```
$ printf 'call bank\n' >> todo.txt && git add todo.txt
$ printf 'fix bike\n' >> todo.txt
$ git status -sb
## main
MM todo.txt
$ git show HEAD:todo.txt | wc -l      # repository
1
$ git show :todo.txt | wc -l          # index
2
$ wc -l < todo.txt                    # working tree
3
```

`git show :path` (commit'siz, ikki nuqta bilan) index'dagi versiyani ko'rsatadi. Uch qatlam, uch xil tarkib, hammasi bitta fayl nomi ostida. macOS'da `wc -l` sonni bo'shliqlar bilan chiqaradi, qiymat bir xil.

3. Ikki alohida commit qilamiz va snapshot qoidasini tekshiramiz:

```
$ git commit -q -m "Add bank call"
$ git commit -q -am "Add bike"
$ git cat-file -p 'HEAD^{tree}'
040000 tree f2300616277f845e86ded3e0bebf75432badd14d	conf
100644 blob 013e8a47b61f7feaebf6987a41edb98ca7f18ec9	todo.txt
```

Birinchi `commit` faqat index'dagini oldi (`fix bike` siz), ikkinchisi `-a` bilan qolganini. Tree'ga qarang: `todo.txt` blob'i yangi (`013e8a4`), `conf` tree'si esa birinchi commit'dagi bilan aynan bir xil (`f230061`). Uch commit bor, lekin `conf/app.ini` omborda bir marta saqlangan.

4. Xabarni tuzatamiz va eski commit qayerga ketganini ko'ramiz:

```
$ git rev-parse --short HEAD
<sha3>
$ git commit -q --amend -m "Add bike repair to todo"
$ git rev-parse --short HEAD
<sha3b>
$ git cat-file -t <sha3>
commit
```

`git rev-parse` nomni SHA'ga aylantiradi. Amend'dan keyin SHA boshqa: xabar commit tarkibining qismi, tarkib o'zgarsa nom o'zgaradi. Eski `<sha3>` hali omborda (`cat-file -t` uni topdi), faqat `main` endi unga ishora qilmaydi.

5. Xato: ikki commit'ni `--hard` bilan tashlaymiz, keyin tiklaymiz:

```
$ git reset --hard HEAD~2
HEAD is now at <sha1> Add todo list and app config
$ cat todo.txt
buy milk
$ git reflog -3
<sha1> HEAD@{0}: reset: moving to HEAD~2
<sha3b> HEAD@{1}: commit (amend): Add bike repair to todo
<sha3> HEAD@{2}: commit: Add bike
$ git reset --hard 'HEAD@{1}'
HEAD is now at <sha3b> Add bike repair to todo
$ wc -l < todo.txt
3
```

Reset branch'ni, index'ni va working tree'ni uchalasini birinchi commit'ga qaytardi. Reflog'da amend ham alohida yozuv bo'lib turibdi. `HEAD@{1}` ga qaytish uchala qatlamni tikladi.

6. Reflog nimani qutqara olmasligini ko'ramiz:

```
$ printf 'pay rent\n' >> todo.txt
$ git restore todo.txt
$ grep -c 'pay rent' todo.txt
0
$ git reflog -1
<sha3b> HEAD@{0}: reset: moving to HEAD@{1}
```

`pay rent` hech qachon `add` ham, commit ham qilinmagan edi: u blob bo'lmagan, `HEAD` ham ko'chmagan, reflog'da yangi yozuv yo'q. Bu tahrir qaytmaydi. Xulosa: commit arzon, yo'qotish qimmat.

7. Tozalash: `cd ~ && rm -rf ~/git-lab/01/notes`.

Vazifalarda xuddi shu asboblar boshqa holatlarga qo'llanadi: obyektlarni o'zingiz sanaysiz, `add -p` bilan ajratasiz, uchala reset rejimini solishtirasiz.

---

## Vazifalar

Vazifalarni `~/git-lab/01/` dagi scratch repolarda bajaring. Javoblarni `git/01-commits/README.md` ga yozing (papka `make new m=git n=01 name=commits` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (masalan `.gitignore` nusxasi) shu papkaga saqlanadi.

### A. Object model

1. **Anatomy of a commit.** Yangi repoda `README.md` va `src/app.js` fayllari bilan bitta commit qiling. `git cat-file -p` bilan `HEAD` dan boshlab commit, root tree, `src` tree va blob'gacha tushing. Har obyektning turi va SHA sini yozing, ular qanday bog'langanini sxema (matnli) ko'rinishida chizing. `.git/objects` da nechta obyekt paydo bo'ldi va nima uchun aynan shuncha? Yo'nalish: 1-bo'lim, "Misol: bitta commit ichida nima bor".

2. **Content addressing.** `echo 'hello' | git hash-object --stdin` natijasini darsdagi SHA bilan solishtiring. Repoda bir xil tarkibli ikki fayl (`a.txt`, `b.txt`) yaratib commit qiling va `git ls-tree HEAD` bilan ikkalasining blob SHA sini ko'ring. Nechta blob saqlandi? Fayl nomi qayerda saqlanadi? Yo'nalish: 1-bo'lim, "Mexanizm: SHA qanday hisoblanadi".

3. **Snapshot not diff.** 3 fayldan faqat bittasini o'zgartirib ikkinchi commit qiling. Ikki commit'ning root tree'larini `git cat-file -p` bilan solishtiring: qaysi SHA lar o'zgardi, qaysilari o'zgarmadi va nima uchun? "Commit snapshot saqlaydi, lekin repo kattalashib ketmaydi" degan gapni shu natija bilan asoslang. Yo'nalish: 1-bo'lim, "Asosiy xulosalar" va "Packfile".

4. **Blob without a commit.** Yangi fayl yaratib faqat `git add` qiling (commit'siz). `git ls-files -s` va `.git/objects` ni tekshiring: blob qachon yaratildi? Keyin faylni yana o'zgartirib `git status` va uchala `git diff` variantini (`diff`, `diff --staged`, `diff HEAD`) ishga tushiring, har biri nimani nima bilan solishtirganini yozing. Yo'nalish: 2-bo'lim, "Misol: add paytida nima bo'ladi" va "Misol: uch xil diff".

5. **Parent chain.** 3 commit'li tarixda oxirgi commit'ning xabarini `--amend` bilan o'zgartiring. Amend'dan oldingi va keyingi SHA ni, `tree` va `parent` qatorlarini solishtiring. Tree bir xil bo'lsa ham SHA nima uchun o'zgardi? Eski commit obyekti hali mavjudmi, qanday tekshirdingiz? Yo'nalish: 1-bo'lim (immutable obyektlar) va 6-bo'lim, "revert va amend".

### B. Staging va commit

6. **Patch staging.** Bitta faylning ikki uzoq joyiga ikki mustaqil o'zgarish kiriting (masalan funksiya nomini tuzatish va yangi sozlama qo'shish). `git add -p` bilan ularni ikki alohida commit'ga ajrating. Ikkalasi bitta hunk bo'lib chiqsa nima qildingiz? Har commit'dan oldin `git diff --staged` natijasini yozing. Yo'nalish: 2-bo'lim, "Qismlab stage qilish".

7. **Commit message.** 6-vazifadagi ikki commit uchun darsdagi formatda (subject, bo'sh qator, "nima uchun" body, trailer) xabar yozing. `git log --oneline` va `git log --format=fuller -1` natijasini ko'rsating. Author va committer sanasi qaysi holatda farq qilishini izohlang. Yo'nalish: 3-bo'lim.

8. **Reading history.** Istalgan ochiq repoda (masalan o'z loyihangiz yoki `git clone --depth 200` bilan olingan biror kutubxona) quyidagilarni toping va buyruqlarni yozing: ma'lum satr birinchi marta qaysi commit'da paydo bo'lgan (`-S`), bitta faylning oxirgi 5 commit'i diff bilan, oxirgi 2 haftada eng ko'p commit qilgan muallif, bitta faylning 3 commit oldingi tarkibi. Yo'nalish: 4-bo'lim jadvali.

9. **Rename detection.** Faylni `git mv` bilan ko'chirib commit qiling, keyin boshqa faylni ko'chirib, bir vaqtda ichining yarmidan ko'pini o'zgartirib commit qiling. `git log --follow` va `git show --stat` har ikki holatda nima ko'rsatadi? Git rename'ni qayerda saqlaydi? Yo'nalish: 4-bo'lim, "Rename mexanizmi".

### C. .gitignore

10. **Ignore rules.** Katalog tuzilmasi yarating: `logs/app.log`, `logs/keep.log`, `build/out.js`, `src/build/x.js`, `.env`, `.env.example`. Shunday `.gitignore` yozingki: barcha `*.log` ignore, lekin `logs/keep.log` kuzatilsin; faqat ildizdagi `build/` ignore, `src/build/` emas; `.env` ignore, `.env.example` emas. Har fayl uchun `git check-ignore -v` natijasini yozing. `.gitignore` nusxasini ish papkasiga saqlang. Yo'nalish: 5-bo'lim, qoidalar jadvali va `git check-ignore -v`.

11. **Already tracked file.** `config.local.json` ni commit qiling, keyin `.gitignore` ga qo'shing va faylni o'zgartiring. `git status` nima ko'rsatadi va nima uchun? Faylni diskda qoldirib kuzatuvdan chiqaring. Hamkasbingiz shu commit'ni `pull` qilganda uning diskidagi faylga nima bo'ladi? Yo'nalish: 5-bo'lim, birinchi tuzoq.

12. **Leaked secret.** `.env` ga soxta `API_KEY=fake-123` yozib commit qiling, keyingi commit'da faylni o'chiring. Secret hali ham repoda ekanini kamida ikki usul bilan ko'rsating. Real hodisada bajariladigan qadamlarni tartibi bilan yozing va nima uchun tartib muhimligini izohlang. Yo'nalish: 5-bo'lim, ikkinchi tuzoq va 1-bo'lim (immutable obyektlar).

### D. Bekor qilish

13. **Restore variants.** Bitta faylda: staged o'zgarish va uning ustiga unstaged o'zgarish hosil qiling. `git restore file`, `git restore --staged file`, `git restore --source=HEAD~1 file` ni alohida-alohida sinab, har biridan keyin `git status -sb` va uchala qatlamdagi fayl holatini yozing. Qaysi biri qaytarib bo'lmaydigan? Yo'nalish: 6-bo'lim, birinchi jadval va 2-bo'limdagi uch qatlam.

14. **Three resets.** 4 commit'li repo yarating va uni uch nusxaga ko'chiring (`cp -r`). Har nusxada `git reset --soft HEAD~2`, `--mixed`, `--hard` ni bajaring. Har biri uchun: branch qayerda, `git status` nima deydi, working tree'da fayllar qanday. Jadval ko'rinishida yozing. Yo'nalish: 6-bo'lim, "reset: uch rejim".

15. **Squash with soft reset.** Oxirgi 3 ta "wip" commit'ni `reset --soft` yordamida bitta toza commit'ga aylantiring. Natijaviy tree avvalgisi bilan bir xil ekanini SHA orqali isbotlang. Yo'nalish: 6-bo'lim, `--soft` qatori va `git rev-parse 'HEAD^{tree}'`.

16. **Revert vs reset.** "Push qilingan" deb faraz qilingan 3 commit'dan o'rtadagisini `git revert` bilan bekor qiling. `git log --oneline` ni ko'rsating. Keyin revert commit'ning o'zini revert qiling va natijani izohlang. Nima uchun bu yerda `reset` ishlatib bo'lmaydi? Yo'nalish: 6-bo'lim, "revert va amend".

17. **Reflog rescue.** 3 commit qiling, keyin `git reset --hard HEAD~3`. `git log` bo'sh yoki qisqa ekanini ko'rsating, so'ng `git reflog` orqali commit'larni to'liq tiklang. Ikkinchi sinov: branch yarating, unga commit qiling, `main` ga qaytib branch'ni `-D` bilan o'chiring va reflog orqali tiklang. Yo'nalish: 6-bo'lim, "reflog: xavfsizlik to'ri" va "Birga bajaramiz" 5-qadam.

18. **What reflog cannot save.** Uch holatni sinang va har birida tiklash mumkinmi, qanday, yozing: (a) fayl tahrirlandi, `add` qilinmadi, `git restore file`; (b) fayl tahrirlandi, `add` qilindi, keyin `git reset --hard` (`git fsck --lost-found` ni sinang); (c) commit qilindi, keyin `reset --hard HEAD~1`. Xulosa: ishni yo'qotmaslik uchun qaysi odat yetarli? Yo'nalish: 6-bo'lim, reflog chegaralari va "Birga bajaramiz" 6-qadam.

19. **Clean dry run.** Repoda untracked fayl, untracked katalog va ignore qilingan fayl yarating. `git clean -n`, `-nd`, `-ndx` natijalarini solishtiring. Faqat untracked fayl va kataloglarni o'chiring, ignore qilingan fayl qolsin. `-x` production serverdagi klon uchun nima uchun xavfli? Yo'nalish: 6-bo'lim, birinchi jadval va Tuzoqlar.

### E. Kichik loyiha

20. **Messy history repair.** Quyidagi "iflos" repo yarating: 1-commit `app.js` va `.env` (soxta secret) birga; 2-commit `wip`; 3-commit ikki mustaqil o'zgarish birga; 4-commit xabarida xato; ustiga commit qilinmagan tahrir. Hech narsa push qilinmagan deb hisoblang. Shu darsdagi asboblar bilan (`reset`, `add -p`, `amend`, `restore`, `.gitignore`; rebase'siz) tarixni toza holatga keltiring: `.env` hech bir commit'da yo'q, har commit atomik va yaxshi xabarli, commit qilinmagan tahrir saqlangan. Oldingi va keyingi `git log --stat` ni, bajarilgan qadamlarni va har qadamda qaysi qatlam o'zgarganini yozing. Oxirida `git log --all -p -S'fake'` bilan secret tarixda yo'qligini tekshiring va reflog'da hali borligini ko'rsatib, bu nimani anglatishini izohlang. Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `git/01-commits/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida: buyruqlar, natija, izoh.
2. `.gitignore` nusxasi ish papkasida, soxta bo'lsa ham `.env` fayli kurs reposiga tushmagan.
3. `make check` toza.
4. `~/git-lab/01` o'chirilgan.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Blob, tree va commit nimani saqlaydi? Fayl nomi qaysi obyektda?
- Commit SHA si nimalarga bog'liq va eski commit'ni o'zgartirish nima uchun keyingilarining hammasini o'zgartiradi?
- Index nima va `git add` aynan nima ish qiladi?
- `git diff`, `git diff --staged`, `git diff HEAD` nimani nima bilan solishtiradi?
- `reset --soft`, `--mixed`, `--hard` uchala qatlamga qanday ta'sir qiladi?
- `revert` va `reset` farqi nima, qaysi biri bo'lishilgan branch uchun?
- Reflog nima, qayerda saqlanadi, nimani tiklay olmaydi?
- Tracked faylni `.gitignore` ga qo'shish nima uchun yetmaydi?
- Push qilingan secret'ni keyingi commit'da o'chirish nima uchun yechim emas?
