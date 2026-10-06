# 2-dars: Branch, merge, rebase

Maqsad: 1-darsda commit'lar graf (DAG) ekanini ko'rdingiz. Bu darsda shu graf ustidagi amallarni ochamiz: branch aslida nima (bitta SHA yozilgan fayl), ikki tarix qanday birlashadi (fast-forward, merge commit, three-way merge), conflict qayerdan keladi va qanday yechiladi, rebase tarixni qanday qayta yozadi, cherry-pick, stash, tag va bisect ichkarida nima qiladi. Siz feature branch ochib PR orqali merge qilishga o'rgangansiz, lekin GitHub'dagi "Merge", "Squash" va "Rebase" tugmalari ortida nima sodir bo'lishini ko'rmagansiz. Ops ishida bu kerak: release branch'ga hotfix ko'chirish, buzuq merge'ni qaytarish, "qaysi commit production'ni sindirdi" ni topish. 3-darsdagi remote va PR shu amallarning tarmoq orqali varianti.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruhi, ikkinchi kun B guruhi (merge va conflict), uchinchi kun 3-bo'lim va C guruhi (rebase), to'rtinchi kun 4–7 bo'limlar, "Birga bajaramiz" va D guruhi, beshinchi kun E guruhi (bisect va 22-vazifa) va README. Diqqat: fast-forward bilan merge commit farqi va oqibatlari, three-way merge va merge base, rebase'da `ours`/`theirs` almashishi, interactive rebase va autosquash, annotated tag, `bisect run`.

Qanday o'qish kerak: har amaldan oldin va keyin `git log --oneline --graph --all` ni ishga tushiring va grafni qog'ozga chizing. Bu darsdagi hamma narsa "qaysi ref qaysi commit'ga ko'chdi va qaysi yangi commit paydo bo'ldi" degan bitta savolga keladi. Commit SHA'lari sizda boshqa bo'ladi, darsda `<sha>` deb yozilgan.

## Laboratoriya

Bu dars ham to'liq host'da, `~/git-lab/02/` ostidagi scratch repolarda bajariladi (1-darsdagidek `git init -b main`, lokal `user.name` va `user.email`). `lab` VM kerak emas.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host, scratch repo (`~/git-lab/02/...`) | `user@host:~/git-lab/02/demo$` yoki `%` (zsh) | barcha tajribalar va vazifalar |
| Host, kurs reposi | `.../dev-ops$` | javoblar (`git/02-branches-merge/README.md`), `task_21.sh`, `make check` |

Bir nechta vazifa bir xil boshlang'ich holatni talab qiladi: repo tayyor bo'lgach `cp -r demo demo-rebase` bilan nusxa olib ishlash qulay (repo bu oddiy papka, `.git` bilan birga ko'chadi). Conflict'larni o'qish oson bo'lishi uchun scratch repolarda:

```
git config merge.conflictStyle zdiff3   # show the common ancestor in conflict markers
```

- Javoblar `git/02-branches-merge/README.md` ga. Tozalash: `rm -rf ~/git-lab/02`.
- Bu dars 1-darsdagi tushunchalarga tayanadi (obyekt, ref, `HEAD`, reflog), lekin uning repolariga emas. Scratch repolar har mashinada lokal: mashinani almashtirsangiz vazifa reposini qaytadan yaratasiz, javoblar kurs reposi orqali ko'chadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | `git version 2.43.0`, hamma narsa ishlaydi. `sed -i 's/a/b/' file` GNU sintaksisi. |
| macOS (uy) | `zdiff3` Git 2.35 dan beri bor. `git --version` eskiroq ko'rsatsa, `diff3` yozing (farqi kichik: `zdiff3` ikki tomonda bir xil bo'lgan qatorlarni marker tashqarisiga chiqaradi) yoki `brew install git`. Faylni joyida o'zgartirish: `sed -i '' 's/a/b/' file` (BSD `sed`), shuning uchun darsdagi misollar faylni `printf` bilan qayta yozadi, bu ikkalasida bir xil. zsh'da `HEAD^`, `stash@{0}` kabi yozuvlarni qo'shtirnoqqa oling. |

---

## 1. Branch bu pointer

### Bu nima

Branch bu commit'lar nusxasi ham, papka ham emas. Branch bu **ref**: ichida bitta commit SHA'si yozilgan 41 baytli fayl (`.git/refs/heads/<nom>`). Branch yaratish shu faylni yozish, shuning uchun u bir zumda bo'ladi va joy egallamaydi. "Branch'dagi commit'lar" degani shu SHA'dan parent'lar bo'ylab orqaga yurib yetiladigan commit'lar.

### Mexanizm

```
$ cat .git/HEAD
ref: refs/heads/main
$ cat .git/refs/heads/main
<sha>
$ git branch feature/login
$ cat .git/refs/heads/feature/login
<sha>
```

Ikkala faylda bir xil SHA: ikki nom bitta commit'ga ishora qiladi. Nomdagi `/` haqiqiy papka yaratadi (`refs/heads/feature/login`), shuning uchun `feature` nomli branch bor bo'lsa `feature/login` ni yaratib bo'lmaydi. Commit qilinganda faqat `HEAD` ko'rsatgan branch fayli yangi SHA'ga almashadi, boshqa branch'lar joyida qoladi. Ko'p ref to'planganda Git ularni bitta `.git/packed-refs` fayliga yig'ishi mumkin, shuning uchun ref'ni o'qishning ishonchli usuli `git rev-parse <nom>`.

### HEAD va detached HEAD

`HEAD` odatda branch'ga ishora qiladi (`ref: refs/heads/main`). `git switch --detach <sha>` yoki `git checkout <sha>` dan keyin `.git/HEAD` ichida to'g'ridan-to'g'ri SHA yoziladi: bu **detached HEAD**. Bu holatda commit qilish mumkin, lekin yangi commit'ga hech qaysi branch ishora qilmaydi. Boshqa branch'ga o'tsangiz, u faqat reflog orqali topiladi va muddati tugagach `git gc` o'chiradi. Qutqarish: `git switch -c <nom>` (shu joyda branch yaratadi). CI tizimlari odatda aniq SHA'ni detached holatda checkout qiladi, shuning uchun pipeline ichida `git branch --show-current` bo'sh qaytishi normal.

### Asosiy buyruqlar

| Buyruq | Nima qiladi |
|--------|-------------|
| `git switch <branch>` | branch'ga o'tish (`HEAD`, index va working tree almashadi) |
| `git switch -c <branch> [<start>]` | yaratish va o'tish |
| `git branch -vv` | branch'lar, oxirgi commit va upstream (3-dars) |
| `git branch --merged main` | `main` ga to'liq qo'shilgan branch'lar (o'chirsa bo'ladi) |
| `git branch -d <branch>` | o'chirish; merge qilinmagan bo'lsa rad etadi |
| `git branch -D <branch>` | majburiy o'chirish (commit'lar reflog'da qoladi) |
| `git branch -m <old> <new>` | nomini o'zgartirish |
| `git log --oneline --graph --all` | butun graf |

`git switch` va `git restore` (Git 2.23 dan) eski `git checkout` ning ikki vazifasini ajratadi: branch almashtirish va fayl tiklash.

### Real ishda qachon kerak

- "Bu branch'ni o'chirsam ish yo'qoladimi?": `git branch --merged main` ro'yxatida bo'lsa yo'qolmaydi.
- CI skripti branch nomini topa olmayapti: pipeline detached HEAD'da ishlaydi, nom muhit o'zgaruvchisidan olinadi (CI modulida).
- Tasodifan o'chirilgan branch: `git reflog` dan SHA, keyin `git branch <nom> <sha>`.

### Nima uchun shunday

SVN kabi eski tizimlarda branch butun daraxtning nusxasi edi: qimmat, shuning uchun kam ochilardi. Git'da commit'lar o'zgarmas va bir-biriga SHA orqali bog'langan, demak tarixning "uchi" ni bilish yetarli, qolgani undan tiklanadi. Branch arzon bo'lgani uchun "har vazifaga bitta branch" ish uslubi paydo bo'ldi.

## 2. Merge

### Bu nima

`git merge <branch>` joriy branch'ga boshqa branch'ning tarixini qo'shadi. Natija ikki xil bo'lishi mumkin:

| Tur | Qachon | Nima bo'ladi |
|-----|--------|--------------|
| Fast-forward | joriy branch uchi qo'shilayotgan branch'ning ajdodi (joriy branch'da yangi commit yo'q) | yangi commit yaratilmaydi, ref oldinga siljiydi |
| Merge commit | ikkala tomonda ham yangi commit bor | ikki parent'li yangi commit |

Flag'lar: `--no-ff` fast-forward mumkin bo'lsa ham merge commit yaratadi (tarixda "bu commit'lar bitta feature edi" degan chegara qoladi va uni bitta `revert -m 1` bilan qaytarish mumkin); `--ff-only` faqat fast-forward, bo'lmasa rad etadi (skriptlar va `pull` uchun xavfsiz); `--squash` barcha o'zgarishni index'ga yig'adi, merge commit yaratmaydi, branch'lar orasidagi bog'lanish tarixda qolmaydi.

### Misol: fast-forward

```
$ git switch -c feature/scale
Switched to a new branch 'feature/scale'
$ printf 'replicas=4\nimage=shop:1.0\nport=8080\n' > deploy.conf
$ git commit -qam "Scale to 4 replicas"
$ git switch -q main
$ git merge feature/scale
Updating <sha>..<sha>
Fast-forward
 deploy.conf | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

`Updating A..B`: `main` `A` dan `B` ga ko'chdi. `Fast-forward`: yangi commit yo'q, `main` fayliga shunchaki `feature/scale` ning SHA'si yozildi. Qolgan ikki qator `--stat` xulosasi.

### Three-way merge

Ikkala tomonda commit bo'lsa, Git uchta snapshot'ni oladi: **merge base** (ikki branch'ning eng yaqin umumiy ajdodi, `git merge-base A B`), "ours" (joriy branch uchi) va "theirs" (qo'shilayotgan branch uchi). Har fayl, har bo'lak uchun qoida:

| Base'ga nisbatan | Natija |
|------------------|--------|
| faqat ours o'zgartirgan | ours olinadi |
| faqat theirs o'zgartirgan | theirs olinadi |
| ikkalasi bir xil o'zgartirgan | o'sha o'zgarish |
| ikkalasi har xil o'zgartirgan | **conflict** |

Git commit'larni birma-bir "qayta o'ynamaydi", faqat uchta snapshot'ni solishtiradi. Shuning uchun branch'da 1 commit bo'ladimi yoki 50 ta, merge natijasi bir xil.

### Misol: conflict

`main` da `image=shop:1.0.1`, `feature/image` da `image=shop:1.1`, base'da `image=shop:1.0`:

```
$ git merge feature/image
Auto-merging deploy.conf
CONFLICT (content): Merge conflict in deploy.conf
Automatic merge failed; fix conflicts and then commit the result.
$ git status -sb
## main
UU deploy.conf
$ cat deploy.conf
replicas=4
<<<<<<< HEAD
image=shop:1.0.1
||||||| <base-sha>
image=shop:1.0
=======
image=shop:1.1
>>>>>>> feature/image
port=8080
```

`UU` "ikkala tomon o'zgartirgan" (unmerged). Fayl ichida: `<<<<<<< HEAD` dan `|||||||` gacha ours, `|||||||` dan `=======` gacha base (bu qism faqat `diff3`/`zdiff3` uslubida chiqadi), `=======` dan `>>>>>>>` gacha theirs. Base'ni ko'rish hal qiladi: kim nimani o'zgartirgani darhol ko'rinadi. `replicas` va `port` qatorlari conflict'siz qo'shildi.

Index'da bu fayl uch nusxada turadi (1-darsdagi stage raqami):

```
$ git ls-files -s
100644 <blob> 1	deploy.conf
100644 <blob> 2	deploy.conf
100644 <blob> 3	deploy.conf
```

Stage 1 base, 2 ours, 3 theirs. `git show :2:deploy.conf` kabi alohida o'qish mumkin.

### Conflict'ni hal qilish

1. Faylni tahrirlang: markerlarni olib tashlab, to'g'ri natijani yozing (bir tomon, ikkinchisi yoki ikkalasining birikmasi).
2. `git add <file>`: bu "hal qilindi" belgisi, index'dagi uch stage o'rniga bitta stage 0 qo'yiladi.
3. `git commit` (yoki `git merge --continue`): merge commit yaratiladi.

Butun faylni bir tomondan olish: `git checkout --ours <file>` yoki `--theirs`. Voz kechish: `git merge --abort` (merge'dan oldingi holatga qaytaradi). Yakunlangan merge'ni bekor qilish: lokal bo'lsa `git reset --hard ORIG_HEAD` (`ORIG_HEAD` xavfli amaldan oldingi `HEAD`), push qilingan bo'lsa `git revert -m 1 <merge-sha>` (`-m 1` "birinchi parent asosiy chiziq, ikkinchi parent olib kelgan o'zgarishni teskarila").

**Tuzoq: revert qilingan merge'ni qayta merge qilish.** Revert faqat o'zgarishni teskarilaydi, graf esa "bu branch allaqachon qo'shilgan" deb biladi. O'sha branch'ni qayta merge qilsangiz eski commit'lar kelmaydi. Yo'li: avval revert commit'ning o'zini revert qilish.

**Tuzoq: semantik conflict.** Git faqat matnni solishtiradi. Bir branch funksiya nomini o'zgartirsa, ikkinchisi boshqa faylda eski nom bilan yangi chaqiruv qo'shsa, merge conflict'siz o'tadi va kod buziladi. Himoya: merge'dan keyin testlar (CI).

### Real ishda qachon kerak

- GitHub PR'dagi uch tugma shu yerdan: "Create a merge commit" bu `--no-ff`, "Squash and merge" bu `--squash` + commit, "Rebase and merge" 3-bo'lim.
- Deploy skriptida `git merge --ff-only`: server hech qachon o'zi merge commit yaratmasligi kerak.
- Buzuq release'ni qaytarish: `git revert -m 1`.

### Nima uchun shunday

Ikki snapshot'ni solishtirishning o'zi yetmaydi: "A da qator bor, B da yo'q" degani A qo'shganmi yoki B o'chirganmi, bilib bo'lmaydi. Uchinchi nuqta (base) buni hal qiladi. Merge commit'ning ikki parent'i esa keyingi merge'lar uchun yangi base'ni beradi, shuning uchun bir marta hal qilingan conflict qayta chiqmaydi.

## 3. Rebase

### Bu nima

`git rebase main` (feature branch'da turib) branch'ning `main` da yo'q commit'larini oladi va ularni `main` ning uchi ustiga birma-bir qayta yaratadi. Natija: chiziqli tarix, merge commit yo'q.

```
before:                         after `git rebase main`:
A---B---C  main                 A---B---C  main
     \                                   \
      D---E  feature                      D'---E'  feature
```

### Mexanizm

Git har commit uchun (`D`, keyin `E`) uning parent'iga nisbatan diff'ini hisoblaydi va yangi asos ustiga qo'llaydi, ya'ni ketma-ket cherry-pick qiladi (4-bo'lim). Har qadam yangi commit yaratadi: parent boshqa, demak SHA boshqa (1-dars). `D` va `D'` ning diff'i va xabari bir xil, lekin ular ikki alohida obyekt. Eski `D`, `E` o'chmaydi, reflog'da qoladi.

```
$ git rebase main
Successfully rebased and updated refs/heads/feature/port.
$ git log --oneline --graph --all
* <sha> Add metrics port
*   <sha> Merge branch 'feature/image'
|\
| * <sha> Bump image to 1.1
* | <sha> Hotfix image 1.0.1
|/
* <sha> Scale to 4 replicas
* <sha> Add deploy config
```

`feature/port` ning yagona commit'i endi merge commit ustida turibdi: `*` commit, `|` va `\`, `/` chiziqlari parent bog'lanishlari, ikki parent'li commit'dan ikki chiziq chiqadi.

**Tuzoq: rebase'da `ours` va `theirs` almashadi.** Rebase avval yangi asosga (`main`) o'tadi, keyin sizning commit'laringizni qo'llaydi. Shuning uchun conflict markerida `HEAD` (ours) tomoni bu `main`, pastki tomon sizning commit'ingiz. Merge'dagining teskarisi. Har conflict'dan keyin: tahrir, `git add`, `git rebase --continue`. Voz kechish: `git rebase --abort`. Yakunlangan rebase'ni qaytarish: `git reset --hard ORIG_HEAD` yoki reflog'dan (`git reflog feature`).

**Oltin qoida: boshqalar ishlatayotgan (push qilingan, umumiy) branch'ni rebase qilmang.** Eski commit'lar ularning klonida qoladi, sizda esa nusxalari: keyingi `pull` ikkalasini birlashtirib tarixni ikkilantiradi. O'z feature branch'ingizni rebase qilish normal (3-darsda `--force-with-lease`).

### Interactive rebase

`git rebase -i <base>` editor'da commit'lar ro'yxatini ochadi (eng eskisi tepada). Har qator boshidagi so'zni o'zgartirib, tarixni tahrirlaysiz:

| Buyruq | Nima qiladi |
|--------|-------------|
| `pick` | commit'ni o'zgarishsiz qoldirish |
| `reword` | faqat xabarni o'zgartirish |
| `edit` | shu commit'da to'xtash (tuzatish yoki ikkiga bo'lish uchun) |
| `squash` | oldingi commit'ga qo'shish, xabarlarni birlashtirish |
| `fixup` | oldingi commit'ga qo'shish, bu commit xabarini tashlash |
| `drop` | commit'ni olib tashlash |

Qatorlar tartibini almashtirish commit'lar tartibini almashtiradi. **Autosquash**: `git commit --fixup=<sha>` xabari `fixup! <asl subject>` bo'lgan commit yaratadi; `git rebase -i --autosquash <base>` uni o'zi kerakli joyga ko'chirib `fixup` deb belgilaydi. Commit'ni bo'lish: `edit` da to'xtab `git reset HEAD~1` (1-darsdagi `--mixed`), keyin `add -p` bilan ikki commit va `git rebase --continue`.

`git rebase --onto <new-base> <old-base> <branch>`: `<old-base>` dan keyingi commit'larni `<new-base>` ustiga ko'chiradi. Branch boshqa feature branch'dan chiqqan va endi to'g'ridan-to'g'ri `main` ga o'tkazilishi kerak bo'lganda ishlatiladi.

### Merge yoki rebase

| | Merge | Rebase |
|---|-------|--------|
| Tarix | haqiqiy: qachon ajralgan, qachon qo'shilgan | chiziqli, o'qish oson |
| SHA'lar | saqlanadi | o'zgaradi |
| Conflict | bir marta, yakuniy natijada | har commit uchun alohida chiqishi mumkin |
| Umumiy branch'da | xavfsiz | mumkin emas |

Keng tarqalgan kelishuv: o'z branch'ingizni PR'dan oldin rebase bilan yangilang va tozalang, `main` ga merge (yoki squash) bilan qo'shing.

### Real ishda qachon kerak

- PR'dan oldin "wip", "oops" commit'larini `rebase -i` bilan yig'ishtirish: reviewer mantiqiy qadamlarni ko'radi.
- Uzoq yashagan branch'ni `main` dan yangilash: merge commit'lar bilan to'ldirish o'rniga `git rebase main`.
- GitHub'dagi "Rebase and merge" tugmasi: PR commit'lari `main` ustiga qayta yaratiladi, SHA'lari o'zgaradi.

### Nima uchun shunday

Commit o'zgarmas va parent SHA uning tarkibida, shuning uchun commit'ni "boshqa joyga ko'chirish" imkonsiz, faqat nusxasini yaratish mumkin. Rebase'ning barcha xususiyatlari (yangi SHA, umumiy branch'dagi xavf, reflog orqali qaytarish) shu bitta faktdan chiqadi. Chiziqli tarix `bisect` (7-bo'lim) va `revert` ni osonlashtiradi, narxi: tarix "aslida qanday bo'lgani" ni emas, "qanday bo'lishi kerak edi" ni ko'rsatadi.

## 4. Cherry-pick

### Bu nima va mexanizm

`git cherry-pick <sha>` bitta commit'ning parent'iga nisbatan diff'ini oladi va joriy branch ustiga yangi commit qilib qo'llaydi. Yangi commit: SHA boshqa, author saqlanadi, committer siz (1-dars). Ichkarida bu ham three-way merge: base sifatida olinayotgan commit'ning parent'i ishlatiladi, shuning uchun conflict chiqishi mumkin (`git cherry-pick --continue` yoki `--abort`).

```
git switch release/1.0
git cherry-pick -x <sha>        # -x appends "(cherry picked from commit <sha>)" to the message
git cherry-pick <a>..<b>        # range: commits after <a> up to and including <b>
```

### Real ishda qachon kerak

**Backport**: bugfix `main` da tuzatildi, lekin production `release/1.0` branch'idan chiqadi. Butun `main` ni release'ga merge qilib bo'lmaydi (u yerda tayyor bo'lmagan feature'lar bor), faqat bitta commit ko'chiriladi. `-x` shart: keyin "bu fix release'da bormi" degan savolga `git log --grep` javob beradi.

### Nima uchun shunday

Cherry-pick graf'da bog'lanish qoldirmaydi: Git ikki commit bir xil o'zgarish ekanini bilmaydi. Shuning uchun u istisno asbob, branch'larni sinxronlash usuli emas. Ko'p commit'ni muntazam ko'chirish kerak bo'lsa, branch strategiyasi noto'g'ri tanlangan (3-dars).

## 5. Stash

### Bu nima

`git stash` commit qilinmagan o'zgarishlarni (index va working tree) chetga olib, working tree'ni `HEAD` holatiga qaytaradi. Keyin `git stash pop` bilan qaytarasiz. Holat: feature ustida ishlayapsiz, shoshilinch hotfix keldi, yarim ish commit'ga tayyor emas.

### Mexanizm

Stash sehrli joy emas, oddiy commit'lar: working tree holati uchun bitta commit, uning parent'lari joriy `HEAD` va index holati uchun yana bir commit. `-u` bilan untracked fayllar uchun uchinchi parent qo'shiladi. Oxirgi stash'ga `refs/stash` ref'i ishora qiladi, oldingilari shu ref'ning reflog'ida (`stash@{1}`, `stash@{2}`).

| Buyruq | Nima qiladi |
|--------|-------------|
| `git stash push -m "msg"` | tracked o'zgarishlarni saqlash |
| `git stash -u` | untracked fayllar bilan birga |
| `git stash list` | ro'yxat |
| `git stash show -p 'stash@{0}'` | diff'ini ko'rish |
| `git stash pop` | qo'llash va ro'yxatdan o'chirish (conflict bo'lsa o'chirmaydi) |
| `git stash apply` | qo'llash, ro'yxatda qoldirish |
| `git stash drop`, `git stash clear` | bittasini yoki hammasini o'chirish |
| `git stash branch <nom>` | stash'dan yangi branch yaratish |

### Real ishda qachon kerak

Qisqa muddatli pauza uchun: branch almashtirish, `pull` oldidan working tree'ni tozalash. Bir kundan ortiq yashaydigan narsa uchun stash emas, branch'da "wip" commit: u nomga ega, push qilinadi va yo'qolmaydi.

### Nima uchun shunday

Git'da ma'lumot saqlashning yagona yo'li obyekt, shuning uchun stash ham commit sifatida amalga oshirilgan. Bundan foyda: stash'ni `git show`, `git log --graph` bilan o'rganish va `drop` qilingan stash'ni `git fsck` orqali topish mumkin. Zarari: stash ro'yxati lokal va nomsiz, unutiladi.

## 6. Tag

### Bu nima

Tag bu commit'ga qo'yilgan o'zgarmas nom, odatda versiya (`v1.2.0`). Branch'dan farqi: commit qilinganda siljimaydi.

| Tur | Yaratish | Ichkarida | Qachon |
|-----|----------|-----------|--------|
| Lightweight | `git tag v1.0.0` | `refs/tags/v1.0.0` fayli, ichida commit SHA | lokal belgi |
| Annotated | `git tag -a v1.0.0 -m "Release 1.0.0"` | alohida tag obyekti (1-darsdagi to'rtinchi tur): tagger, sana, xabar, nishon SHA | release |

### Misol

```
$ git tag -a v1.1.0 -m "Release 1.1.0" main
$ git cat-file -t v1.1.0
tag
$ git cat-file -p v1.1.0
object <sha>
type commit
tag v1.1.0
tagger Lab User <lab@example.com> <vaqt> +0500

Release 1.1.0
$ git describe feature/port
v1.1.0-1-g<sha>
```

`cat-file -t` `tag` dedi: bu alohida obyekt (lightweight tag'da `commit` chiqardi). Ichida: `object` nishon commit, `type` nishon turi, `tag` nom, `tagger` kim va qachon, keyin xabar. `git describe` "eng yaqin annotated tag + undan keyingi commit'lar soni + `g` va qisqa SHA" formatida versiya satri beradi: `v1.1.0` dan 1 commit keyin. Build'larga versiya berishda shu ishlatiladi; lightweight tag'larni u standart holatda hisobga olmaydi.

Tag'lar `git push` bilan avtomatik ketmaydi: `git push origin v1.1.0` yoki `git push --follow-tags` (faqat annotated). SemVer (`MAJOR.MINOR.PATCH`) frontend'dan tanish: `package.json` dagi versiya bilan bir xil kelishuv. Push qilingan tag'ni boshqa commit'ga ko'chirmang: uni olgan klonlar yangilanmaydi va bitta versiya ikki xil kodni bildirib qoladi.

### Real ishda qachon kerak

CI/CD'da release ko'pincha tag bilan ishga tushadi: `v*` tag push bo'lsa pipeline image yig'adi va shu versiya bilan belgilaydi. Annotated tag "kim, qachon release qildi" ni saqlaydi va imzolanishi mumkin (3-dars).

### Nima uchun shunday

Branch harakatlanadigan, tag qotgan ko'rsatkich. Release takrorlanadigan bo'lishi uchun nom hech qachon boshqa kodga ishora qilmasligi kerak, xuddi image digest yoki `package-lock.json` dagi aniq versiya kabi. Annotated tag alohida obyekt bo'lgani uchun o'z SHA'siga, muallifiga va imzosiga ega.

## 7. Bisect

### Bu nima va mexanizm

"Kecha ishlardi, bugun ishlamayapti, orada 200 commit bor." `git bisect` binary search qiladi: yaxshi va yomon commit orasidagi o'rtadagisini checkout qiladi, siz sinab `good` yoki `bad` deysiz, oraliq har safar ikki baravar qisqaradi. N commit uchun taxminan log2(N) qadam: 200 commit 8 qadamda.

```
git bisect start
git bisect bad                  # current commit is broken
git bisect good v1.0.0          # this one worked
# git checks out a commit in the middle; test it, then:
git bisect good                 # or: git bisect bad
# repeat until git prints "<sha> is the first bad commit"
git bisect reset                # return to the original branch
```

Avtomatlashtirish: `git bisect run <script>`. Git har qadamda skriptni ishga tushiradi va exit code'ga qaraydi: `0` yaxshi, `1`–`127` (125 dan tashqari) yomon, `125` "bu commit'ni sinab bo'lmaydi, o'tkazib yubor" (masalan build bo'lmaydi). Bisect paytida siz detached HEAD'dasiz (1-bo'lim), `git bisect log` qadamlarni ko'rsatadi.

### Real ishda qachon kerak

Performance regressiyasi yoki "bu endpoint qachondan beri 500 qaytaradi": test skripti (`curl` + exit code) yoziladi va `bisect run` aybdor commit'ni odam aralashuvisiz topadi.

### Nima uchun shunday

Bisect tarix sifati uchun to'lov oladi: har commit alohida build bo'lishi va ishlashi kerak (1-darsdagi atomik commit). "wip" commit'lar bilan to'la tarixda bisect har ikkinchi qadamda sinib qoladi. Atomik commit va toza tarix qoidalari estetika emas, aynan shu asbob ishlashi uchun.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Branch | commit SHA'si yozilgan, commit qilinganda siljiydigan ref |
| Detached HEAD | `HEAD` branch'ga emas, to'g'ridan-to'g'ri commit'ga ishora qilgan holat |
| Fast-forward | yangi commit'siz, ref'ni oldinga siljitish bilan bajarilgan merge |
| Merge commit | ikki (yoki ko'p) parent'li commit |
| Merge base | ikki branch'ning eng yaqin umumiy ajdodi |
| Three-way merge | base, ours va theirs snapshot'larini solishtirib birlashtirish |
| Ours / theirs | merge'da: joriy branch / qo'shilayotgan branch (rebase'da teskari) |
| Conflict | ikki tomon bitta joyni har xil o'zgartirgan holat |
| Rebase | commit'larni boshqa asos ustiga qayta yaratish |
| Squash / fixup | commit'ni oldingisiga qo'shib yuborish (xabar bilan / xabarsiz) |
| `ORIG_HEAD` | merge, rebase, reset dan oldingi `HEAD` |
| Cherry-pick | bitta commit o'zgarishini joriy branch'ga nusxalash |
| Backport | tuzatishni eski release branch'iga ko'chirish |
| Stash | commit qilinmagan o'zgarishlarni vaqtincha chetga olish |
| Lightweight / annotated tag | oddiy ref / alohida tag obyekti |
| SemVer | `MAJOR.MINOR.PATCH` versiya kelishuvi |
| Bisect | xato kirgan commit'ni binary search bilan topish |

## Tuzoqlar

- Umumiy branch'ni rebase qilish hamkasblar tarixini ikkilantiradi. Faqat o'z branch'ingizni qayta yozing.
- Rebase conflict'ida `--ours` va `--theirs` merge'dagiga teskari. Avval markerlarni o'qing, keyin tanlang.
- Detached HEAD'da qilingan commit branch'siz qoladi. Chiqishdan oldin `git switch -c <nom>`.
- `git branch -D` merge qilinmagan ishni ogohlantirishsiz o'chiradi; tiklash faqat reflog orqali va faqat shu klonda.
- Revert qilingan merge'ni qayta merge qilish eski commit'larni olib kelmaydi. Avval revert'ni revert qiling.
- Conflict'siz merge kod ishlashini bildirmaydi (semantik conflict). Merge'dan keyin test.
- `git stash pop` conflict bersa stash ro'yxatda qoladi; hal qilgach `git stash drop` ni unutmang. `git stash` untracked fayllarni olmaydi (`-u` kerak).
- `--squash` merge'dan keyin feature branch `--merged` ro'yxatida chiqmaydi va `-d` rad etadi: graf'da bog'lanish yo'q.
- Lightweight tag'ni release uchun ishlatish: `git describe` va `--follow-tags` uni ko'rmaydi.
- Push qilingan tag'ni ko'chirish: klonlarda eski nishon qoladi.
- `git bisect reset` ni unutish: detached HEAD'da qolib, keyingi commit'lar branch'siz ketadi.
- macOS'da `sed -i 's/a/b/' file` xato beradi (BSD `sed` `-i ''` talab qiladi). Skriptlaringiz ikkala mashinada ishlashi kerak bo'lsa, faylni `printf` yoki `>` bilan qayta yozing.

## Manbalar

- https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell – Pro Git 3.1, branch pointer sifatida (majburiy)
- https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging – Pro Git 3.2
- https://git-scm.com/book/en/v2/Git-Branching-Rebasing – Pro Git 3.6, rebase va uning xavfi (majburiy)
- https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History – Pro Git 7.6, interactive rebase
- https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging – Pro Git 7.8, conflict'lar chuqur
- https://git-scm.com/docs/git-rebase – rebase reference
- https://git-scm.com/docs/git-bisect – bisect reference
- https://git-scm.com/book/en/v2/Git-Basics-Tagging – Pro Git 2.6, tag'lar
- https://semver.org – Semantic Versioning

## Birga bajaramiz

Bitta yaxlit yurish: `shop` reposida bitta konfiguratsiya fayli ustida fast-forward, conflict'li merge, rebase va annotated tag. Hammasi host'da, fayl `printf` bilan yoziladi, shuning uchun ikkala mashinada bir xil.

1. Repo va boshlang'ich commit:

```
$ mkdir -p ~/git-lab/02 && cd ~/git-lab/02
$ git init -q -b main shop && cd shop
$ git config user.name "Lab User" && git config user.email "lab@example.com"
$ git config merge.conflictStyle zdiff3
$ printf 'replicas=2\nimage=shop:1.0\nport=8080\n' > deploy.conf
$ git add deploy.conf && git commit -q -m "Add deploy config"
```

2. Fast-forward. Branch ochamiz, bitta qatorni o'zgartiramiz, `main` ga qaytib merge qilamiz:

```
$ git switch -q -c feature/scale
$ printf 'replicas=4\nimage=shop:1.0\nport=8080\n' > deploy.conf
$ git commit -qam "Scale to 4 replicas"
$ git switch -q main && git merge feature/scale
Updating <sha>..<sha>
Fast-forward
 deploy.conf | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
$ git rev-parse main feature/scale
<sha>
<sha>
```

`main` da yangi commit yo'q edi, shuning uchun Git faqat ref'ni siljitdi. `rev-parse` ikki nom uchun bir xil SHA chiqaradi: ikki branch bitta commit'da.

3. Ikki tomonda o'zgarish. Bir xil qatorni ikki branch'da har xil o'zgartiramiz:

```
$ git switch -q -c feature/image
$ printf 'replicas=4\nimage=shop:1.1\nport=8080\n' > deploy.conf
$ git commit -qam "Bump image to 1.1"
$ git switch -q main
$ printf 'replicas=4\nimage=shop:1.0.1\nport=8080\n' > deploy.conf
$ git commit -qam "Hotfix image 1.0.1"
$ git merge-base main feature/image
<sha of "Scale to 4 replicas">
```

Merge base bu ikki branch ajralgan nuqta. Three-way merge shu commit'dagi `deploy.conf` ni uchinchi nuqta sifatida oladi.

4. Merge va conflict:

```
$ git merge feature/image
Auto-merging deploy.conf
CONFLICT (content): Merge conflict in deploy.conf
Automatic merge failed; fix conflicts and then commit the result.
$ cat deploy.conf
replicas=4
<<<<<<< HEAD
image=shop:1.0.1
||||||| <base-sha>
image=shop:1.0
=======
image=shop:1.1
>>>>>>> feature/image
port=8080
```

O'qiymiz: base'da `1.0` edi, biz (`main`) hotfix bilan `1.0.1` qildik, ular (`feature/image`) `1.1` ga ko'tardi. Qaror matndan emas, ma'nodan chiqadi: `1.1` hotfix'ni o'z ichiga oladi deb faraz qilamiz va `1.1` ni tanlaymiz.

5. Hal qilish va yakunlash:

```
$ printf 'replicas=4\nimage=shop:1.1\nport=8080\n' > deploy.conf
$ git add deploy.conf
$ git commit -q -m "Merge branch 'feature/image'"
$ git log --oneline --graph
*   <sha> Merge branch 'feature/image'
|\
| * <sha> Bump image to 1.1
* | <sha> Hotfix image 1.0.1
|/
* <sha> Scale to 4 replicas
* <sha> Add deploy config
$ git cat-file -p HEAD | grep -c '^parent'
2
```

`git add` conflict'ni "hal qilindi" deb belgiladi, `commit` ikki parent'li merge commit yaratdi. Grafda ikki chiziq ajralib, qayta qo'shilgani ko'rinadi.

6. Rebase. Merge'dan oldingi commit'dan chiqqan eskirgan branch'ni yangilaymiz:

```
$ git switch -q -c feature/port HEAD~1
$ printf 'metrics=9090\n' >> deploy.conf
$ git commit -qam "Add metrics port"
$ git rev-parse --short HEAD
<sha-old>
$ git rebase main
Successfully rebased and updated refs/heads/feature/port.
$ git rev-parse --short HEAD
<sha-new>
$ git log --oneline --graph --all | head -2
* <sha-new> Add metrics port
*   <sha> Merge branch 'feature/image'
```

`HEAD~1` merge commit'ning birinchi parent'i ("Hotfix image 1.0.1"). Rebase'dan keyin commit xabari o'sha, SHA boshqa: bu yangi obyekt, parent'i endi merge commit. Eski `<sha-old>` `git reflog` da turibdi. Endi `git switch main && git merge feature/port` qilinsa fast-forward bo'ladi.

7. Release tag va versiya satri:

```
$ git tag -a v1.1.0 -m "Release 1.1.0" main
$ git describe feature/port
v1.1.0-1-g<sha-new>
```

8. Tozalash: `cd ~ && rm -rf ~/git-lab/02/shop`.

Vazifalarda xuddi shu amallar boshqa holatlarda: merge'ning uch usulini solishtirasiz, rebase conflict'ida tomonlarni aniqlaysiz, interactive rebase bilan tarixni tozalaysiz, bisect bilan buzuq commit'ni topasiz.

---

## Vazifalar

Vazifalarni `~/git-lab/02/` dagi scratch repolarda bajaring. Javoblarni `git/02-branches-merge/README.md` ga yozing (papka `make new m=git n=02 name=branches-merge` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi (ko'pincha `git log --oneline --graph --all`) va o'z so'zingiz bilan izoh. So'ralgan skriptlar (`task_21.sh`) shu papkaga saqlanadi.

### A. Branch va HEAD

1. **Branch is a file.** Yangi repoda 2 commit qiling. `.git/HEAD` va `.git/refs/heads/main` ni o'qing. `git branch` ishlatmasdan, faqat fayl yozish orqali `manual` nomli branch yarating va `git branch -vv` uni ko'rishini tekshiring. Branch yaratish nima uchun repo hajmiga bog'liq emas? Yo'nalish: 1-bo'lim, "Mexanizm".

2. **Detached HEAD.** `git switch --detach HEAD~1` qiling, `.git/HEAD` tarkibi qanday o'zgardi? Shu holatda commit qiling, keyin `main` ga qayting. Git qanday ogohlantirish berdi? Commit'ni reflog orqali topib, unga branch bering. Yo'nalish: 1-bo'lim, "HEAD va detached HEAD" va 1-darsdagi reflog.

3. **Delete and restore.** Merge qilinmagan branch'ni `-d` bilan o'chirib ko'ring, xatoni yozing. `-D` bilan o'chiring va tiklang. `git branch --merged` va `--no-merged` branch o'chirishdan oldin qanday yordam beradi? Yo'nalish: 1-bo'lim, "Asosiy buyruqlar" jadvali.

### B. Merge

4. **Fast-forward vs merge commit.** Bir xil boshlang'ich repodan uch nusxa oling. `feature` branch'ini `main` ga uch usulda qo'shing: oddiy `merge`, `merge --no-ff`, `merge --squash` (+ commit). Har birida graph'ni, `HEAD` ning parent'lari sonini (`git cat-file -p HEAD`) va `git branch -d feature` natijasini yozing. Yo'nalish: 2-bo'lim, birinchi jadval va flag'lar.

5. **ff-only refusal.** `main` va `feature` ikkalasida ham yangi commit bo'lgan holatda `git merge --ff-only feature` qiling. Xatoni yozing. Bu flag qaysi vaziyatda (masalan deploy skriptida `pull`) foydali? Yo'nalish: 2-bo'lim, `--ff-only`.

6. **Three-way merge.** Bitta fayldagi uchta qatorni tayyorlang: birinchisini faqat `main` da, ikkinchisini faqat `feature` da, uchinchisini ikkalasida har xil o'zgartiring. Merge qiling. Qaysi qatorlar avtomatik qo'shildi, qaysi biri conflict berdi? `git merge-base` va `git ls-files -u` natijasini ko'rsating, `git show :1:file`, `:2:file`, `:3:file` nimani bildiradi? Yo'nalish: 2-bo'lim, "Three-way merge" jadvali.

7. **Conflict resolution.** 6-vazifadagi conflict'ni `zdiff3` markerlarini o'qib qo'lda hal qiling va merge'ni yakunlang. Keyin holatni qaytarib (`reset --hard ORIG_HEAD`), merge'ni takrorlang va bu safar `git merge --abort` qiling. Abort'dan keyin index va working tree qanday holatda? Yo'nalish: 2-bo'lim, "Misol: conflict" va "Conflict'ni hal qilish".

8. **Semantic conflict.** Ikki faylli kichik skript yozing (masalan `lib.sh` da funksiya, `main.sh` da chaqiruv). Bir branch'da funksiya nomini o'zgartiring, ikkinchisida eski nom bilan yangi chaqiruv qo'shing. Merge conflict'siz o'tishini va skript ishlamasligini ko'rsating. Bundan qanday himoyalaniladi? Yo'nalish: 2-bo'lim, semantik conflict tuzog'i.

9. **Revert a merge.** `--no-ff` bilan qilingan merge'ni `git revert -m 1` bilan bekor qiling. `-m 1` nimani bildiradi? Keyin o'sha branch'ni qayta merge qilib ko'ring: Git nima deydi va nima uchun o'zgarishlar qaytmaydi? Ularni qaytarish yo'lini toping. Yo'nalish: 2-bo'lim, `revert -m 1` va qayta merge tuzog'i.

### C. Rebase va tarixni qayta yozish

10. **Rebase changes SHAs.** `feature` da 3 commit, `main` da 2 yangi commit bo'lsin. Rebase'dan oldin va keyin `git log --oneline --graph --all` ni yozing. Feature commit'larining SHA lari nima uchun o'zgardi, tree'lari-chi? Eski commit'lar qayerda? Yo'nalish: 3-bo'lim, "Mexanizm".

11. **Rebase conflict sides.** 6-vazifadagi holatni tayyorlab, bu safar `feature` ni `main` ustiga rebase qiling. Conflict markerida `HEAD` tomoni kimning kodi? `git restore --ours` va `--theirs` ni alohida nusxalarda sinab, merge'dagi natija bilan solishtiring. Farqning sababini mexanizm orqali tushuntiring. Yo'nalish: 3-bo'lim, `ours`/`theirs` tuzog'i.

12. **Abort and recover.** Rebase'ni o'rtasida `--abort` qiling. Keyin rebase'ni oxirigacha bajaring va "yoqmadi" deb faraz qilib, branch'ni rebase'dan oldingi holatga ikki usulda qaytaring (`ORIG_HEAD`, reflog). Yo'nalish: 3-bo'lim (`--abort`, `ORIG_HEAD`) va 1-darsdagi reflog.

13. **Interactive rebase.** 6 commit'li branch tayyorlang: `Add feature`, `wip`, `fix typo`, `Add tests`, `oops`, `Update docs`. `git rebase -i` bilan: ikki "wip/typo" commit'ni tegishlisiga `fixup` qiling, bittasini `reword`, bittasining o'rnini almashtiring, bittasini `drop`. Oldingi va keyingi log'ni va todo ro'yxatini yozing. Yo'nalish: 3-bo'lim, "Interactive rebase" jadvali.

14. **Autosquash.** 3 toza commit'li branch'da birinchi commit'ga tegishli tuzatishni `git commit --fixup=<sha>` bilan yozing, keyin `git rebase -i --autosquash` qiling. Todo ro'yxati qanday ko'rinishda ochildi? Bu oqim PR review'da nima uchun qulay? Yo'nalish: 3-bo'lim, autosquash.

15. **Split a commit.** Ikki mustaqil o'zgarishni o'z ichiga olgan eski (oxirgi emas) commit'ni interactive rebase'ning `edit` buyrug'i bilan ikki commit'ga bo'ling. Qaysi buyruqlar ketma-ketligini ishlatdingiz va har qadamda `HEAD` qayerda edi? Yo'nalish: 3-bo'lim, `edit` va commit'ni bo'lish.

16. **Rebase onto.** `main` dan `feature-a`, undan `feature-b` chiqqan zanjir yarating. `feature-b` ni `feature-a` commit'larisiz to'g'ridan-to'g'ri `main` ustiga ko'chiring (`--onto`). Graph'ni oldin va keyin ko'rsating, buyruqning uch argumentini izohlang. Yo'nalish: 3-bo'lim, `rebase --onto`.

### D. Cherry-pick, stash, tag

17. **Backport with cherry-pick.** `main` va `release/1.0` branch'lari bo'lsin. `main` da bugfix commit qiling va uni `release/1.0` ga `cherry-pick -x` bilan o'tkazing. Ikki commit'ning SHA, tree va xabarini solishtiring. Keyin `release/1.0` ni `main` ga merge qilsangiz nima bo'ladi? Yo'nalish: 4-bo'lim.

18. **Stash internals.** Staged, unstaged va untracked o'zgarishlar hosil qiling. `git stash` va `git stash -u` farqini ko'rsating. `git log --graph --oneline stash@{0}` bilan stash aslida nima ekanini ko'rsating. `pop` paytida conflict hosil qiling: stash ro'yxatda qoldimi? Yo'nalish: 5-bo'lim, "Mexanizm" va jadval.

19. **Tags.** Bitta commit'ga lightweight, boshqasiga annotated tag qo'ying. `git cat-file -t <tag>` va `git cat-file -p <tag>` natijalarini solishtiring. Bir necha commit qo'shib `git describe` va `git describe --tags` ni ishga tushiring, chiqqan satrning har qismini izohlang. `git checkout <tag>` dan keyin `HEAD` qanday holatda? Yo'nalish: 6-bo'lim.

### E. Bisect va kichik loyiha

20. **Manual bisect.** Skript bilan 20 commit'li repo yarating (har commit `calc.sh` ga kichik o'zgarish kiritadi), ulardan biri natijani buzsin (qaysi biri ekanini o'zingizdan yashiring, masalan tasodifiy tanlab). `git bisect` ni qo'lda `good`/`bad` bilan yuritib aybdor commit'ni toping. Necha qadam ketdi va bu log2(N) ga mosmi? Yo'nalish: 7-bo'lim, qo'lda bisect.

21. **bisect run.** 20-vazifa uchun `task_21.sh` test skripti yozing (to'g'ri bo'lsa `exit 0`, buzuq bo'lsa `exit 1`) va `git bisect run` bilan avtomatik toping. Keyin commit'lardan birini skript umuman ishlamaydigan qilib qo'ying va `125` exit code bilan o'tkazib yuborishni qo'shing. `git bisect log` ni yozing. Yo'nalish: 7-bo'lim, `bisect run` va exit code'lar.

22. **Release branch drill.** Bitta repoda to'liq ssenariy: `main` da 3 commit, `v1.0.0` annotated tag; `release/1.0` branch; `main` da 2 yangi feature (biri `--no-ff` merge, biri rebase + fast-forward); `main` da topilgan bug `main` da tuzatiladi va `release/1.0` ga backport qilinadi, `v1.0.1` tag; `main` dagi bir feature'ning butun merge'i revert qilinadi. Yakuniy `git log --oneline --graph --all --decorate` ni yozing va har ref qaysi commit'da nima uchun turganini izohlang. `git describe` `main` va `release/1.0` da nima beradi? Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `git/02-branches-merge/README.md` da 22 ta vazifa, har biri `## N. Title` sarlavhasi ostida, graph'lar bilan.
2. `task_21.sh` ish papkasida, `make check` toza (`shellcheck` xatosiz).
3. `~/git-lab/02` o'chirilgan.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Branch fizik jihatdan nima? Commit qilinganda nima ko'chadi?
- Detached HEAD nima, qachon paydo bo'ladi va undagi commit'lar nima uchun yo'qolishi mumkin?
- Fast-forward qachon mumkin? `--no-ff` tarixga nima beradi?
- Three-way merge qaysi uch nuqtani solishtiradi va conflict aynan qachon chiqadi?
- Rebase nima uchun commit SHA larini o'zgartiradi va nima uchun bo'lishilgan branch'da xavfli?
- Rebase'da `ours` va `theirs` nima uchun merge'dagiga teskari?
- `squash` va `fixup` farqi nima? `--autosquash` nimaga tayanadi?
- Annotated tag lightweight tag'dan nimasi bilan farq qiladi, relizga qaysi biri va nima uchun?
- `bisect run` exit code'larni qanday talqin qiladi? Qanday tarix bisect uchun yaroqsiz?
- Merge qilingan feature'ni revert qilgandan keyin uni qayta merge qilish nima uchun ishlamaydi?
