# 1-dars: Commit va object model

Maqsad: Git'ni buyruqlar to'plami sifatida emas, ma'lumotlar tuzilmasi sifatida ko'rish. Commit, tree va blob obyektlari qanday bog'langanini, working tree, index va repository orasida ma'lumot qanday ko'chishini va har bir "bekor qilish" buyrug'i aynan qaysi qatlamni o'zgartirishini tushunish. Ops ishida bu bilim hodisa paytida kerak bo'ladi: noto'g'ri `reset`, yo'qolgan commit, tarixga tushib qolgan secret. 2-darsdagi branch, merge va rebase shu modelning ustiga quriladi.

Taxminiy vaqt: 2 kun (siz uchun). `add`, `commit`, `log` tanish, ularga vaqt sarflamang. Diqqatni quyidagilarga qarating: obyekt turlari va SHA qayerdan kelishi, index alohida qatlam ekani, `reset` ning uch rejimi, `revert` va `reset` farqi, `reflog` bilan tiklash va uning chegaralari.

## Laboratoriya

Ish mashinasida, kurs reposidan tashqaridagi scratch repolarda. Kurs reposi ichida `git init` qilmang: ichki repo "embedded repository" bo'lib qoladi.

```
mkdir -p ~/git-lab/01 && cd ~/git-lab/01
git init -b main demo && cd demo
git config user.name "Lab User"          # local config, only this repo
git config user.email "lab@example.com"
```

Javoblar `git/01-commits/README.md` ga yoziladi. Tozalash: `rm -rf ~/git-lab/01`. Global Git config'ingizni bu darsda o'zgartirish shart emas, ko'rish uchun: `git config --list --show-origin`.

---

## 1. Object model

Git bu content-addressable storage: har bir obyekt o'z tarkibining hash'i bilan nomlanadi va `.git/objects/` ichida saqlanadi. To'rt tur bor:

| Obyekt | Nima saqlaydi | Nima saqlamaydi |
|--------|---------------|-----------------|
| blob | fayl tarkibi (baytlar) | fayl nomi, huquqlar |
| tree | katalog: `mode`, tur, SHA, nom qatorlari (blob va boshqa tree'larga ishora) | fayl tarkibi |
| commit | bitta root tree SHA, parent commit(lar) SHA, author, committer, vaqt, xabar | diff |
| tag | annotated tag: nishon obyekt SHA, tagger, xabar (2-darsda) | |

Asosiy xulosalar:

- **Commit bu diff emas, snapshot.** Har commit butun loyiha holatining root tree'siga ishora qiladi. `git show` dagi diff har safar parent bilan solishtirib hisoblanadi.
- **O'zgarmagan fayl qayta saqlanmaydi.** Tarkib bir xil bo'lsa blob SHA bir xil, yangi tree eski blob'ga ishora qiladi. Bir xil tarkibli ikki fayl ham bitta blob.
- **Obyektlar o'zgarmas (immutable).** "Commit'ni o'zgartirish" degan narsa yo'q: `amend`, `rebase` yangi SHA li yangi commit yaratadi, eskisi o'z joyida qoladi (shuning uchun tiklash mumkin).
- **Tarix bu DAG.** Commit parent'iga ishora qiladi, parent bolasini bilmaydi. Parent SHA commit tarkibiga kirgani uchun eski commit'ni o'zgartirish undan keyingi barcha commit'lar SHA sini o'zgartiradi.

### SHA qanday hisoblanadi

SHA-1 `"<type> <size>\0<content>"` satridan olinadi. Shuning uchun natija faqat tarkibga bog'liq va har mashinada bir xil:

```
echo 'hello' | git hash-object --stdin   # ce013625030ba8dba906f756967f9e9ca394464a
git cat-file -t ce01362                  # blob (after the object is written)
git cat-file -p HEAD                     # commit: tree, parent, author, message
git cat-file -p 'HEAD^{tree}'            # root tree listing
git ls-tree -r HEAD                      # all files of the snapshot
```

Obyekt fayli zlib bilan siqilgan, yo'li `.git/objects/ce/013625...` (birinchi 2 belgi katalog). Ko'p obyekt to'planganda `git gc` ularni packfile'ga (`.git/objects/pack/`) yig'adi va o'xshash obyektlarni delta sifatida saqlaydi, shuning uchun "har commit to'liq snapshot" bo'lsa ham repo kichik qoladi. Hajm: `git count-objects -vH`.

Qisqa SHA (7+ belgi) repo ichida yagona bo'lsa yetadi. Git SHA-256 formatini ham qo'llaydi (`git init --object-format=sha256`), lekin hostinglar va asboblar hali asosan SHA-1 repolar bilan ishlaydi.

### Revision yozuvlari

| Yozuv | Ma'nosi |
|-------|---------|
| `HEAD~2` | birinchi parent bo'ylab 2 qadam orqaga |
| `HEAD^2` | merge commit'ning ikkinchi parent'i |
| `main@{1}`, `HEAD@{2}` | reflog'dagi avvalgi holat (6-bo'lim) |
| `A..B` | `B` dan yetiladigan, `A` dan yetilmaydigan commit'lar |
| `A...B` | ikkalasidan biridan yetiladigan, umumiy bo'lmaganlar; `diff` da: merge base'dan `B` gacha |
| `HEAD:path/file` | o'sha commit'dagi fayl (blob) |

To'liq ro'yxat: `man gitrevisions`.

## 2. Uch qatlam: working tree, index, repository

| Qatlam | Qayerda | Nima |
|--------|---------|------|
| working tree | loyiha katalogi | siz tahrirlaydigan fayllar |
| index (staging area) | `.git/index` | keyingi commit'ning tayyorlanayotgan snapshot'i |
| repository | `.git/objects` + ref'lar | commit qilingan tarix |

Index "o'zgarishlar ro'yxati" emas, to'liq snapshot: har kuzatilayotgan fayl uchun blob SHA saqlaydi (`git ls-files -s`). `git add` faylni blob qilib `.git/objects` ga yozadi va index'dagi SHA ni yangilaydi. `git commit` index'dan tree yasaydi va commit obyektini yaratadi. Demak blob `add` paytida paydo bo'ladi, commit paytida emas.

```
git diff            # working tree vs index
git diff --staged   # index vs HEAD (what the next commit will contain)
git diff HEAD       # working tree vs HEAD
git status -sb      # short status: left column index, right column working tree
```

**Tuzoq: `add` dan keyin faylni yana tahrirlasangiz, commit'ga `add` paytidagi versiya tushadi.** `git status` da fayl bir vaqtda ham "staged", ham "not staged" ko'rinadi. `git commit -a` kuzatilayotgan fayllarni avtomatik stage qiladi, lekin yangi (untracked) fayllarni qo'shmaydi.

### Qismlab stage qilish: `add -p`

`git add -p` har hunk uchun so'raydi: `y` qo'shish, `n` o'tkazish, `s` hunk'ni bo'lish, `e` qo'lda tahrirlash, `q` chiqish, `?` yordam. Maqsad: bitta ish seansida qilingan ikki mustaqil o'zgarishni ikki alohida commit'ga ajratish. Simmetrik buyruqlar: `git restore -p --staged` (index'dan qismlab chiqarish), `git restore -p` (working tree'dan qismlab tashlash). Commit'dan oldin `git diff --staged` ni o'qish odat bo'lsin.

## 3. Yaxshi commit

Commit review, `bisect`, `revert` va `cherry-pick` birligi. Shuning uchun **atomik** bo'lishi kerak: bitta mantiqiy o'zgarish, alohida olinganda build va testlar o'tadi. "Refactor + bugfix + format" bitta commit'da bo'lsa, bugfix'ni alohida revert qilib bo'lmaydi.

Xabar formati:

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
- Oxirida trailer'lar: `Refs:`, `Co-authored-by:`, `Signed-off-by:` (`git commit -s`).
- Conventional Commits (`feat:`, `fix:`, `chore:` ...) jamoa kelishuvi, changelog va versiyani avtomatik chiqarish uchun ishlatiladi. Git buni talab qilmaydi, tekshiruv hook yoki CI orqali qo'yiladi (3-darsda).

Author va committer alohida maydonlar: author o'zgarishni yozgan, committer uni tarixga qo'ygan (rebase, cherry-pick, amend da farq qiladi). Ko'rish: `git log --format=fuller`.

## 4. Tarixni o'qish

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

Git rename'ni saqlamaydi: tree'da faqat eski nom yo'qolib, yangisi paydo bo'ladi. `log --follow`, `diff -M` rename'ni tarkib o'xshashligidan taxmin qiladi. Shuning uchun faylni ko'chirish va ichini katta o'zgartirishni alohida commit'larga ajrating.

## 5. .gitignore

Qoidalar (`man gitignore`):

- `*.log` istalgan chuqurlikda, `/build` faqat `.gitignore` turgan katalogda, `logs/` faqat katalog, `**/tmp` istalgan chuqurlikda, `!keep.log` istisno (negation).
- Keyingi qator oldingisini bekor qiladi. Lekin ota katalog ignore qilingan bo'lsa, ichidagi faylni `!` bilan qaytarib bo'lmaydi.
- Uch daraja: repo ichidagi `.gitignore` (commit qilinadi, jamoa uchun), `.git/info/exclude` (faqat shu klon), global fayl (`core.excludesFile`, default `~/.config/git/ignore`; IDE va OS fayllari uchun).
- Diagnostika: `git check-ignore -v path` qaysi fayl, qaysi qator sabab ekanini ko'rsatadi; `git status --ignored`.

**Tuzoq: `.gitignore` faqat untracked fayllarga ta'sir qiladi.** Allaqachon commit qilingan fayl ignore ro'yxatiga qo'shilsa ham kuzatilaveradi. Kuzatuvdan chiqarish: `git rm --cached path` (fayl diskda qoladi) va commit.

**Tuzoq: secret tarixda qoladi.** `.env` ni keyingi commit'da o'chirish uni tarixdan olib tashlamaydi: `git show <old-sha>:.env` hali ishlaydi, klon qilgan har kim ko'radi. To'g'ri tartib: avval secret'ni almashtirish (rotate), keyin kerak bo'lsa tarixni `git filter-repo` bilan tozalash. Push qilingan secret'ni oshkor bo'lgan deb hisoblang.

## 6. Bekor qilish

Avval savol: o'zgarish qaysi qatlamda va boshqalar bilan bo'lishilganmi?

| Holat | Buyruq | Nimani o'zgartiradi |
|-------|--------|---------------------|
| working tree'dagi tahrirni tashlash | `git restore file` | working tree (index'dan oladi). Qaytarib bo'lmaydi |
| stage'dan chiqarish | `git restore --staged file` | index (HEAD'dan oladi), working tree tegilmaydi |
| faylni eski commit holatiga keltirish | `git restore --source=<sha> file` | working tree |
| oxirgi commit xabari yoki tarkibini tuzatish | `git commit --amend` | yangi commit, eski o'rniga |
| lokal commit'larni olib tashlash | `git reset` | branch pointer (+ index, + working tree) |
| bo'lishilgan commit'ni bekor qilish | `git revert <sha>` | teskari diff bilan yangi commit |
| untracked fayllarni o'chirish | `git clean -n`, keyin `git clean -fd` | working tree. Qaytarib bo'lmaydi |

### reset: uch rejim

`git reset <commit>` joriy branch pointer'ini `<commit>` ga ko'chiradi. Rejim qolgan ikki qatlamga nima bo'lishini belgilaydi:

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

Har safar `HEAD` yoki branch ko'chganda (commit, reset, checkout, rebase, amend) Git buni lokal jurnalga yozadi: `.git/logs/`. `git reflog` bu jurnalni ko'rsatadi, `HEAD@{1}` bitta amal oldingi holat.

```
git reflog                      # e.g. "a1b2c3d HEAD@{1}: commit: Add config"
git reset --hard HEAD@{1}       # undo the last reset/rebase/amend
git branch rescue a1b2c3d       # or give the lost commit a name
```

Chegaralari:

- Reflog **lokal**: push qilinmaydi, klonda bo'lmaydi. Repo katalogi o'chsa reflog ham yo'q.
- Muddati bor: default 90 kun, hech qaysi ref'dan yetilmaydigan yozuvlar uchun 30 kun (`gc.reflogExpire`, `gc.reflogExpireUnreachable`). Keyin `git gc` obyektlarni o'chiradi.
- **Faqat commit qilingan narsa tiklanadi.** `reset --hard` yoki `restore` tashlagan, hech qachon commit qilinmagan tahrir reflog'da yo'q. Bir marta `add` qilingan bo'lsa, blob obyekt sifatida qolgan bo'lishi mumkin: `git fsck --lost-found` dangling blob'larni ko'rsatadi.

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

---

## Vazifalar

Vazifalarni `~/git-lab/01/` dagi scratch repolarda bajaring. Javoblarni `git/01-commits/README.md` ga yozing (papka `make new m=git n=01 name=commits` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (masalan `.gitignore` nusxasi) shu papkaga saqlanadi.

### A. Object model

1. **Anatomy of a commit.** Yangi repoda `README.md` va `src/app.js` fayllari bilan bitta commit qiling. `git cat-file -p` bilan `HEAD` dan boshlab commit, root tree, `src` tree va blob'gacha tushing. Har obyektning turi va SHA sini yozing, ular qanday bog'langanini sxema (matnli) ko'rinishida chizing. `.git/objects` da nechta obyekt paydo bo'ldi va nima uchun aynan shuncha?

2. **Content addressing.** `echo 'hello' | git hash-object --stdin` natijasini darsdagi SHA bilan solishtiring. Repoda bir xil tarkibli ikki fayl (`a.txt`, `b.txt`) yaratib commit qiling va `git ls-tree HEAD` bilan ikkalasining blob SHA sini ko'ring. Nechta blob saqlandi? Fayl nomi qayerda saqlanadi?

3. **Snapshot not diff.** 3 fayldan faqat bittasini o'zgartirib ikkinchi commit qiling. Ikki commit'ning root tree'larini `git cat-file -p` bilan solishtiring: qaysi SHA lar o'zgardi, qaysilari o'zgarmadi va nima uchun? "Commit snapshot saqlaydi, lekin repo kattalashib ketmaydi" degan gapni shu natija bilan asoslang.

4. **Blob without a commit.** Yangi fayl yaratib faqat `git add` qiling (commit'siz). `git ls-files -s` va `.git/objects` ni tekshiring: blob qachon yaratildi? Keyin faylni yana o'zgartirib `git status` va uchala `git diff` variantini (`diff`, `diff --staged`, `diff HEAD`) ishga tushiring, har biri nimani nima bilan solishtirganini yozing.

5. **Parent chain.** 3 commit'li tarixda oxirgi commit'ning xabarini `--amend` bilan o'zgartiring. Amend'dan oldingi va keyingi SHA ni, `tree` va `parent` qatorlarini solishtiring. Tree bir xil bo'lsa ham SHA nima uchun o'zgardi? Eski commit obyekti hali mavjudmi, qanday tekshirdingiz?

### B. Staging va commit

6. **Patch staging.** Bitta faylning ikki uzoq joyiga ikki mustaqil o'zgarish kiriting (masalan funksiya nomini tuzatish va yangi sozlama qo'shish). `git add -p` bilan ularni ikki alohida commit'ga ajrating. Ikkalasi bitta hunk bo'lib chiqsa nima qildingiz? Har commit'dan oldin `git diff --staged` natijasini yozing.

7. **Commit message.** 6-vazifadagi ikki commit uchun darsdagi formatda (subject, bo'sh qator, "nima uchun" body, trailer) xabar yozing. `git log --oneline` va `git log --format=fuller -1` natijasini ko'rsating. Author va committer sanasi qaysi holatda farq qilishini izohlang.

8. **Reading history.** Istalgan ochiq repoda (masalan o'z loyihangiz yoki `git clone --depth 200` bilan olingan biror kutubxona) quyidagilarni toping va buyruqlarni yozing: ma'lum satr birinchi marta qaysi commit'da paydo bo'lgan (`-S`), bitta faylning oxirgi 5 commit'i diff bilan, oxirgi 2 haftada eng ko'p commit qilgan muallif, bitta faylning 3 commit oldingi tarkibi.

9. **Rename detection.** Faylni `git mv` bilan ko'chirib commit qiling, keyin boshqa faylni ko'chirib, bir vaqtda ichining yarmidan ko'pini o'zgartirib commit qiling. `git log --follow` va `git show --stat` har ikki holatda nima ko'rsatadi? Git rename'ni qayerda saqlaydi?

### C. .gitignore

10. **Ignore rules.** Katalog tuzilmasi yarating: `logs/app.log`, `logs/keep.log`, `build/out.js`, `src/build/x.js`, `.env`, `.env.example`. Shunday `.gitignore` yozingki: barcha `*.log` ignore, lekin `logs/keep.log` kuzatilsin; faqat ildizdagi `build/` ignore, `src/build/` emas; `.env` ignore, `.env.example` emas. Har fayl uchun `git check-ignore -v` natijasini yozing. `.gitignore` nusxasini ish papkasiga saqlang.

11. **Already tracked file.** `config.local.json` ni commit qiling, keyin `.gitignore` ga qo'shing va faylni o'zgartiring. `git status` nima ko'rsatadi va nima uchun? Faylni diskda qoldirib kuzatuvdan chiqaring. Hamkasbingiz shu commit'ni `pull` qilganda uning diskidagi faylga nima bo'ladi?

12. **Leaked secret.** `.env` ga soxta `API_KEY=fake-123` yozib commit qiling, keyingi commit'da faylni o'chiring. Secret hali ham repoda ekanini kamida ikki usul bilan ko'rsating. Real hodisada bajariladigan qadamlarni tartibi bilan yozing va nima uchun tartib muhimligini izohlang.

### D. Bekor qilish

13. **Restore variants.** Bitta faylda: staged o'zgarish va uning ustiga unstaged o'zgarish hosil qiling. `git restore file`, `git restore --staged file`, `git restore --source=HEAD~1 file` ni alohida-alohida sinab, har biridan keyin `git status -sb` va uchala qatlamdagi fayl holatini yozing. Qaysi biri qaytarib bo'lmaydigan?

14. **Three resets.** 4 commit'li repo yarating va uni uch nusxaga ko'chiring (`cp -r`). Har nusxada `git reset --soft HEAD~2`, `--mixed`, `--hard` ni bajaring. Har biri uchun: branch qayerda, `git status` nima deydi, working tree'da fayllar qanday. Jadval ko'rinishida yozing.

15. **Squash with soft reset.** Oxirgi 3 ta "wip" commit'ni `reset --soft` yordamida bitta toza commit'ga aylantiring. Natijaviy tree avvalgisi bilan bir xil ekanini SHA orqali isbotlang.

16. **Revert vs reset.** "Push qilingan" deb faraz qilingan 3 commit'dan o'rtadagisini `git revert` bilan bekor qiling. `git log --oneline` ni ko'rsating. Keyin revert commit'ning o'zini revert qiling va natijani izohlang. Nima uchun bu yerda `reset` ishlatib bo'lmaydi?

17. **Reflog rescue.** 3 commit qiling, keyin `git reset --hard HEAD~3`. `git log` bo'sh yoki qisqa ekanini ko'rsating, so'ng `git reflog` orqali commit'larni to'liq tiklang. Ikkinchi sinov: branch yarating, unga commit qiling, `main` ga qaytib branch'ni `-D` bilan o'chiring va reflog orqali tiklang.

18. **What reflog cannot save.** Uch holatni sinang va har birida tiklash mumkinmi, qanday, yozing: (a) fayl tahrirlandi, `add` qilinmadi, `git restore file`; (b) fayl tahrirlandi, `add` qilindi, keyin `git reset --hard` (`git fsck --lost-found` ni sinang); (c) commit qilindi, keyin `reset --hard HEAD~1`. Xulosa: ishni yo'qotmaslik uchun qaysi odat yetarli?

19. **Clean dry run.** Repoda untracked fayl, untracked katalog va ignore qilingan fayl yarating. `git clean -n`, `-nd`, `-ndx` natijalarini solishtiring. Faqat untracked fayl va kataloglarni o'chiring, ignore qilingan fayl qolsin. `-x` production serverdagi klon uchun nima uchun xavfli?

### E. Kichik loyiha

20. **Messy history repair.** Quyidagi "iflos" repo yarating: 1-commit `app.js` va `.env` (soxta secret) birga; 2-commit `wip`; 3-commit ikki mustaqil o'zgarish birga; 4-commit xabarida xato; ustiga commit qilinmagan tahrir. Hech narsa push qilinmagan deb hisoblang. Shu darsdagi asboblar bilan (`reset`, `add -p`, `amend`, `restore`, `.gitignore`; rebase'siz) tarixni toza holatga keltiring: `.env` hech bir commit'da yo'q, har commit atomik va yaxshi xabarli, commit qilinmagan tahrir saqlangan. Oldingi va keyingi `git log --stat` ni, bajarilgan qadamlarni va har qadamda qaysi qatlam o'zgarganini yozing. Oxirida `git log --all -p -S'fake'` bilan secret tarixda yo'qligini tekshiring va reflog'da hali borligini ko'rsatib, bu nimani anglatishini izohlang.

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
