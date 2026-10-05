# 2-dars: Branch va merge

Maqsad: branch'ni "kod nusxasi" emas, commit'ga ishora qiluvchi ko'chma pointer sifatida tushunish va shu model orqali merge, rebase, cherry-pick, stash, tag va bisect nima qilishini aniq ko'rish. 1-darsdagi object model va reflog bu yerda to'liq ishlatiladi: har bir amal DAG'ga yangi commit qo'shadi yoki pointer'ni ko'chiradi, boshqa hech narsa emas. 3-darsda shu amallar remote va pull request bilan birga ishlatiladi.

Taxminiy vaqt: 3 kun (siz uchun). Feature branch va merge kundalik ish, ularga vaqt sarflamang. Diqqat: fast-forward bilan merge commit farqi va oqibatlari, three-way merge va merge base, rebase'da `ours`/`theirs` almashishi, interactive rebase va autosquash, annotated tag, `bisect run`.

## Laboratoriya

Ish mashinasida, `~/git-lab/02/` ostidagi scratch repolarda (1-darsdagidek `git init -b main`, lokal `user.name` va `user.email`). Bir nechta vazifa bir xil boshlang'ich holatni talab qiladi: repo tayyor bo'lgach `cp -r demo demo-rebase` bilan nusxa olib ishlash qulay. Conflict'larni o'qish oson bo'lishi uchun scratch repolarda:

```
git config merge.conflictStyle zdiff3   # show the common ancestor in conflict markers
```

Javoblar `git/02-branches-merge/README.md` ga. Tozalash: `rm -rf ~/git-lab/02`.

---

## 1. Branch bu pointer

Branch `.git/refs/heads/<nom>` fayli, ichida bitta commit SHA si (40 belgi). Branch yaratish shu faylni yozish demak, shuning uchun bir zumda bajariladi va hech narsa nusxalanmaydi. Commit qilinganda joriy branch pointer'i yangi commit'ga suriladi.

```
cat .git/refs/heads/main        # a commit SHA
cat .git/HEAD                   # ref: refs/heads/main
git rev-parse main HEAD         # same SHA twice
git branch -vv                  # branches, their commits and upstreams
```

(Ko'p ref'li repoda `git gc` ref'larni bitta `.git/packed-refs` fayliga yig'adi, alohida fayl bo'lmasligi mumkin.)

### HEAD va detached HEAD

`HEAD` "hozir qayerdaman" degan ko'rsatkich. Odatda u branch'ga ishora qiladi (symbolic ref), commit qilinganda o'sha branch suriladi. `git switch --detach <sha>` yoki `git checkout <sha|tag>` dan keyin `HEAD` to'g'ridan-to'g'ri commit'ga ishora qiladi: **detached HEAD**. Bu holatda commit qilish mumkin, lekin hech bir branch ularga ishora qilmaydi: boshqa branch'ga o'tsangiz ular faqat reflog orqali topiladi va oxir-oqibat `gc` o'chiradi. Saqlab qolish: `git switch -c <nom>`.

CI tizimlari reponi ko'pincha aynan detached HEAD holatida checkout qiladi (ma'lum commit yoki tag), shuning uchun pipeline ichida "joriy branch nomi" ni Git'dan emas, CI o'zgaruvchisidan olish kerak.

### Asosiy buyruqlar

| Buyruq | Nima qiladi |
|--------|-------------|
| `git switch <b>`, `git switch -c <b> [start]`, `git switch -` | o'tish, yaratib o'tish, avvalgisiga qaytish |
| `git branch -d <b>` | o'chirish, faqat merge qilingan bo'lsa |
| `git branch -D <b>` | majburan o'chirish (commit'lar reflog'da qoladi) |
| `git branch --merged main`, `--no-merged main` | `main` ga kirgan va kirmagan branch'lar |
| `git branch -m <new>` | nomini o'zgartirish |
| `git merge-base A B` | ikki branch'ning eng yaqin umumiy ajdodi |

`git checkout` ikki ish qilardi (branch almashtirish va fayl tiklash), `switch` va `restore` (Git 2.23+) ularni ajratadi. Eski hujjat va skriptlarda `checkout` uchraydi, u hali ishlaydi.

## 2. Merge

`git merge feature` joriy branch'ga `feature` dagi ishni qo'shadi. Natija ikki xil bo'lishi mumkin:

| Tur | Qachon | Nima bo'ladi |
|-----|--------|--------------|
| fast-forward | joriy branch `feature` ning ajdodi (ajralish yo'q) | pointer oldinga suriladi, yangi commit yo'q |
| merge commit (true merge) | ikkala tomonda yangi commit bor | ikki parent'li yangi commit yaratiladi |

Boshqarish: `--no-ff` har doim merge commit yaratadi (feature chegarasi tarixda ko'rinadi, butun feature'ni `revert -m 1` bilan qaytarish oson); `--ff-only` fast-forward mumkin bo'lmasa xato beradi (kutilmagan merge commit'dan himoya); `--squash` barcha o'zgarishlarni index'ga yig'adi, commit'ni o'zingiz qilasiz, natijada bitta parent'li oddiy commit (branch "merge qilingan" deb hisoblanmaydi, `branch -d` rad etadi).

### Three-way merge

True merge uch nuqtani solishtiradi: **merge base** (umumiy ajdod), `ours` (joriy branch, `HEAD`) va `theirs` (qo'shilayotgan branch). Har qism uchun qoida:

- faqat bir tomon o'zgartirgan: o'sha o'zgarish olinadi;
- ikkala tomon bir xil o'zgartirgan: o'sha olinadi;
- ikkala tomon bir joyni har xil o'zgartirgan: **conflict**.

Shuning uchun conflict "ikki fayl farq qiladi" degani emas, "base'ga nisbatan ikki tomon bir joyga tekkan" degani. Base'ni ko'rmasdan conflict'ni to'g'ri hal qilish qiyin, `zdiff3` uslubi uni marker ichida ko'rsatadi:

```
<<<<<<< HEAD
timeout = 60
||||||| 9f2c1ab
timeout = 30
=======
timeout = 45
>>>>>>> feature
```

### Conflict'ni hal qilish

Merge to'xtaganda index'da conflict'li fayl uch bosqichda turadi: 1 (base), 2 (ours), 3 (theirs). Ko'rish: `git ls-files -u`, `git show :2:file`.

1. `git status`: "Unmerged paths" ro'yxati.
2. Faylni tahrirlab markerlarni olib tashlang, yoki butun faylni bir tomondan oling: `git restore --ours file` / `git restore --theirs file`.
3. `git add file` ("hal qilindi" belgisi).
4. `git merge --continue` (yoki `git commit`). Voz kechish: `git merge --abort`.

**Tuzoq: Git faqat matn darajasidagi conflict'ni ko'radi.** Bir tomon funksiya nomini o'zgartirsa, ikkinchisi boshqa faylda eski nom bilan yangi chaqiruv qo'shsa, merge "toza" o'tadi, lekin kod ishlamaydi (semantic conflict). Merge'dan keyin build va test majburiy, CI aynan shuning uchun merge natijasida ishlaydi.

Bir xil conflict qayta-qayta chiqsa (uzoq yashaydigan branch'lar): `git config rerere.enabled true` yechimni eslab qoladi va keyingi safar o'zi qo'llaydi.

## 3. Rebase

`git rebase main` (feature branch'da turib) feature'dagi commit'larni merge base'dan uzib, `main` ning uchiga birma-bir qayta qo'llaydi. Tarkib o'xshash, lekin parent boshqa, demak **har commit yangi SHA li yangi commit**. Eski commit'lar reflog'da qoladi.

| | merge | rebase |
|---|-------|--------|
| Tarix | haqiqiy: qachon ajraldi, qachon qo'shildi | chiziqli, "ajralish bo'lmagandek" |
| Mavjud commit'lar | o'zgarmaydi | qayta yaratiladi (yangi SHA) |
| Conflict | bir marta, merge paytida | har qayta qo'llanayotgan commit'da alohida chiqishi mumkin |
| Bo'lishilgan branch'da | xavfsiz | xavfli |

**Oltin qoida: boshqalar ishlatayotgan branch'ni rebase qilmang.** O'z feature branch'ingizni PR'dan oldin tozalash uchun rebase, umumiy branch'lar (`main`, `develop`, release) uchun merge yoki revert.

**Tuzoq: rebase'da `ours` va `theirs` almashadi.** Rebase paytida Git `main` ning uchida turib sizning commit'laringizni qo'llaydi, shuning uchun `ours` bu `main` (va allaqachon qo'llangan commit'lar), `theirs` bu sizning qayta qo'llanayotgan commit'ingiz. `restore --ours` merge'dagiga teskari natija beradi.

Boshqarish: conflict'dan keyin `git add` va `git rebase --continue`; `--skip` joriy commit'ni tashlaydi; `--abort` hammasini boshlang'ich holatga qaytaradi. Rebase tugagach natija yoqmasa: `git reset --hard ORIG_HEAD` yoki reflog. `git rebase --onto <new-base> <old-base> <branch>` commit'lar oralig'ini boshqa asosga ko'chiradi (masalan boshqa feature ustiga qurilgan branch'ni `main` ga ko'chirish).

### Interactive rebase

`git rebase -i <base>` qayta qo'llanadigan commit'lar ro'yxatini muharrirda ochadi (eng eskisi tepada). Qatorlarni tahrirlab tarix qayta yoziladi:

| Buyruq | Ta'siri |
|--------|---------|
| `pick` | commit'ni o'zicha qoldirish |
| `reword` | faqat xabarni o'zgartirish |
| `edit` | shu commit'da to'xtash (tarkibini o'zgartirish yoki bo'lish uchun) |
| `squash` | oldingi commit'ga qo'shish, xabarlarni birlashtirish |
| `fixup` | oldingi commit'ga qo'shish, bu commit xabarini tashlash |
| `drop` | commit'ni olib tashlash (qatorni o'chirish bilan bir xil) |
| `exec <cmd>` | shu nuqtada buyruq ishga tushirish (masalan test) |

Qatorlar tartibini almashtirish commit'lar tartibini almashtiradi. Amaliy oqim: review paytida tuzatishni `git commit --fixup=<sha>` bilan yozasiz, oxirida `git rebase -i --autosquash <base>` ularni kerakli commit ostiga `fixup` qilib o'zi joylaydi. `git rebase -i --root` birinchi commit'dan boshlab qayta yozadi.

## 4. Cherry-pick

`git cherry-pick <sha>` bitta commit kiritgan o'zgarishni (parent'iga nisbatan diff'ini) joriy branch'ga yangi commit qilib qo'llaydi. Yangi SHA, Git ikki commit orasidagi bog'liqlikni saqlamaydi.

- Ops'dagi asosiy qo'llanish: **backport**. Tuzatish `main` da qilinadi, keyin `release/1.4` ga cherry-pick qilinadi.
- `-x` xabarga `(cherry picked from commit ...)` qatorini qo'shadi, backport'da doim ishlating: keyin qaysi tuzatish qayerdan kelgani ko'rinadi.
- `-n` commit qilmasdan faqat index va working tree'ga qo'llaydi. Oraliq: `git cherry-pick A..B` (`A` kirmaydi).
- Conflict rebase'dagidek: `--continue`, `--abort`.

Ikki uzoq yashaydigan branch orasida doimiy cherry-pick qilish dublikat commit'lar va keyingi merge'da conflict keltiradi. Bu odatda workflow muammosi belgisi (3-darsda).

## 5. Stash

`git stash` commit qilinmagan o'zgarishlarni (index va working tree) chetga olib, working tree'ni `HEAD` holatiga qaytaradi. Ichkarida stash bu oddiy commit'lar, `refs/stash` ref'i va uning reflog'i (`stash@{0}`, `stash@{1}` ...).

| Buyruq | Nima qiladi |
|--------|-------------|
| `git stash push -m "msg"` | saqlash; `-u` untracked fayllarni ham oladi |
| `git stash list`, `git stash show -p stash@{0}` | ro'yxat, tarkib |
| `git stash apply` | qo'llash, stash ro'yxatda qoladi |
| `git stash pop` | qo'llash va o'chirish (conflict bo'lsa o'chirilmaydi) |
| `git stash drop`, `git stash branch <b>` | o'chirish; stash'dan yangi branch ochish |

**Tuzoq: stash "yashirin xotira" ga aylanadi.** Default holatda untracked fayllar stash'ga tushmaydi (`-u` kerak), nomsiz stash'lar haftalab to'planadi va nimaligi unutiladi. Bir kundan uzoq saqlanadigan ish uchun `wip` commit'li branch ishonchliroq: u push qilinadi, stash esa faqat lokal.

## 6. Tag

Tag bu ko'chmaydigan nom: reliz nuqtasini belgilaydi. Ikki turi bor:

| | lightweight | annotated |
|---|-------------|-----------|
| Yaratish | `git tag v1.0.0` | `git tag -a v1.0.0 -m "Release 1.0.0"` |
| Nima | `refs/tags/` dagi ref, to'g'ridan-to'g'ri commit'ga | alohida **tag obyekti**: tagger, sana, xabar, commit'ga ishora |
| Imzolash | yo'q | mumkin (`-s`, 3-darsda) |
| `git describe` | default hisobga olmaydi (`--tags` kerak) | ishlatadi |
| Qo'llanish | lokal, vaqtinchalik belgi | relizlar |

- Tag'lar oddiy `git push` bilan ketmaydi: `git push origin v1.0.0`, yoki `git push --follow-tags` (yetiladigan annotated tag'lar).
- `git describe` versiya satri beradi: `v1.0.0-3-gabc1234` (tag'dan keyin 3 commit, joriy qisqa SHA). Build artefaktlarini nomlashda ishlatiladi.
- O'chirish: `git tag -d v1.0.0`, serverda `git push origin --delete v1.0.0`.

**Tuzoq: chop etilgan tag'ni ko'chirmang.** `git fetch` mavjud tag'ni yangilamaydi, shuning uchun bir xil `v1.0.0` turli mashinalarda turli commit'ni bildirib qoladi, CI va artefaktlar bir-biriga mos kelmaydi. Xato reliz uchun yangi versiya (`v1.0.1`) chiqariladi.

## 7. Bisect

`git bisect` regressiyani kiritgan commit'ni binary search bilan topadi: N commit uchun taxminan log2(N) qadam (1000 commit, 10 qadam).

```
git bisect start
git bisect bad                  # current commit is broken
git bisect good v1.2.0          # this one worked
# git checks out a middle commit: test it, then mark good/bad, repeat
git bisect run ./test.sh        # or automate the whole search
git bisect reset                # return to where you started
```

`bisect run` skriptning exit code'iga qaraydi: `0` good, `1`–`127` bad (`125` dan tashqari), `125` "bu commit'ni tekshirib bo'lmaydi, o'tkazib yubor" (masalan build bo'lmaydi). Jarayon jurnali: `git bisect log`.

Bisect faqat tarix shunga yaroqli bo'lsa ishlaydi: har commit build bo'ladi va bitta mantiqiy o'zgarish (1-darsdagi atomik commit). 40 faylli bitta squash commit'ni bisect "aybdor" deb topadi, lekin undan nariga o'tolmaydi.

## Tuzoqlar

- Bo'lishilgan branch'ni rebase qilish yoki amend qilish: hamkasblar tarixi ajraladi, eski commit'lar keyingi merge'da dublikat bo'lib qaytadi.
- Rebase conflict'ida `--ours`/`--theirs` ni merge'dagidek ishlatish: teskari tomon olinadi va o'z ishingiz jimgina yo'qoladi.
- "Conflict yo'q" ni "merge to'g'ri" deb qabul qilish. Semantic conflict'ni faqat build va test ushlaydi.
- Detached HEAD'da commit qilib, branch yaratmay boshqa joyga o'tish: ish faqat reflog'da qoladi.
- Uzoq yashaydigan feature branch: `main` dan qancha uzoq ajralsa, merge shuncha og'ir. Tez-tez `main` ni qo'shib turing yoki branch'ni kichik qiling.
- Reliz tag'ini ko'chirish yoki o'chirib qayta yaratish: klonlar va CI kesh'ida eski nishon qoladi.
- Lightweight tag bilan reliz: kim, qachon, nima uchun belgilagani saqlanmaydi, `git describe` uni ko'rmaydi.
- `git stash pop` conflict berganida stash o'chmaydi, lekin buni bilmay qayta `pop` qilish yoki `drop` qilib yuborish.
- `git branch -D` merge qilinmagan ishni ogohlantirishsiz o'chiradi (reflog 30 kun ichida qutqaradi, serverda esa yo'q).
- Squash merge'dan keyin eski feature branch'da ishlashni davom ettirish: `main` dagi squash commit va branch'dagi asl commit'lar Git uchun bog'lanmagan, keyingi merge conflict beradi.

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

---

## Vazifalar

Vazifalarni `~/git-lab/02/` dagi scratch repolarda bajaring. Javoblarni `git/02-branches-merge/README.md` ga yozing (papka `make new m=git n=02 name=branches-merge` bilan yaratiladi): har vazifa uchun `## N. Title` sarlavhasi, ostida buyruqlar, natijaning muhim qismi (ko'pincha `git log --oneline --graph --all`) va o'z so'zingiz bilan izoh. So'ralgan skriptlar (`task_21.sh`) shu papkaga saqlanadi.

### A. Branch va HEAD

1. **Branch is a file.** Yangi repoda 2 commit qiling. `.git/HEAD` va `.git/refs/heads/main` ni o'qing. `git branch` ishlatmasdan, faqat fayl yozish orqali `manual` nomli branch yarating va `git branch -vv` uni ko'rishini tekshiring. Branch yaratish nima uchun repo hajmiga bog'liq emas?

2. **Detached HEAD.** `git switch --detach HEAD~1` qiling, `.git/HEAD` tarkibi qanday o'zgardi? Shu holatda commit qiling, keyin `main` ga qayting. Git qanday ogohlantirish berdi? Commit'ni reflog orqali topib, unga branch bering.

3. **Delete and restore.** Merge qilinmagan branch'ni `-d` bilan o'chirib ko'ring, xatoni yozing. `-D` bilan o'chiring va tiklang. `git branch --merged` va `--no-merged` branch o'chirishdan oldin qanday yordam beradi?

### B. Merge

4. **Fast-forward vs merge commit.** Bir xil boshlang'ich repodan uch nusxa oling. `feature` branch'ini `main` ga uch usulda qo'shing: oddiy `merge`, `merge --no-ff`, `merge --squash` (+ commit). Har birida graph'ni, `HEAD` ning parent'lari sonini (`git cat-file -p HEAD`) va `git branch -d feature` natijasini yozing.

5. **ff-only refusal.** `main` va `feature` ikkalasida ham yangi commit bo'lgan holatda `git merge --ff-only feature` qiling. Xatoni yozing. Bu flag qaysi vaziyatda (masalan deploy skriptida `pull`) foydali?

6. **Three-way merge.** Bitta fayldagi uchta qatorni tayyorlang: birinchisini faqat `main` da, ikkinchisini faqat `feature` da, uchinchisini ikkalasida har xil o'zgartiring. Merge qiling. Qaysi qatorlar avtomatik qo'shildi, qaysi biri conflict berdi? `git merge-base` va `git ls-files -u` natijasini ko'rsating, `git show :1:file`, `:2:file`, `:3:file` nimani bildiradi?

7. **Conflict resolution.** 6-vazifadagi conflict'ni `zdiff3` markerlarini o'qib qo'lda hal qiling va merge'ni yakunlang. Keyin holatni qaytarib (`reset --hard ORIG_HEAD`), merge'ni takrorlang va bu safar `git merge --abort` qiling. Abort'dan keyin index va working tree qanday holatda?

8. **Semantic conflict.** Ikki faylli kichik skript yozing (masalan `lib.sh` da funksiya, `main.sh` da chaqiruv). Bir branch'da funksiya nomini o'zgartiring, ikkinchisida eski nom bilan yangi chaqiruv qo'shing. Merge conflict'siz o'tishini va skript ishlamasligini ko'rsating. Bundan qanday himoyalaniladi?

9. **Revert a merge.** `--no-ff` bilan qilingan merge'ni `git revert -m 1` bilan bekor qiling. `-m 1` nimani bildiradi? Keyin o'sha branch'ni qayta merge qilib ko'ring: Git nima deydi va nima uchun o'zgarishlar qaytmaydi? Ularni qaytarish yo'lini toping.

### C. Rebase va tarixni qayta yozish

10. **Rebase changes SHAs.** `feature` da 3 commit, `main` da 2 yangi commit bo'lsin. Rebase'dan oldin va keyin `git log --oneline --graph --all` ni yozing. Feature commit'larining SHA lari nima uchun o'zgardi, tree'lari-chi? Eski commit'lar qayerda?

11. **Rebase conflict sides.** 6-vazifadagi holatni tayyorlab, bu safar `feature` ni `main` ustiga rebase qiling. Conflict markerida `HEAD` tomoni kimning kodi? `git restore --ours` va `--theirs` ni alohida nusxalarda sinab, merge'dagi natija bilan solishtiring. Farqning sababini mexanizm orqali tushuntiring.

12. **Abort and recover.** Rebase'ni o'rtasida `--abort` qiling. Keyin rebase'ni oxirigacha bajaring va "yoqmadi" deb faraz qilib, branch'ni rebase'dan oldingi holatga ikki usulda qaytaring (`ORIG_HEAD`, reflog).

13. **Interactive rebase.** 6 commit'li branch tayyorlang: `Add feature`, `wip`, `fix typo`, `Add tests`, `oops`, `Update docs`. `git rebase -i` bilan: ikki "wip/typo" commit'ni tegishlisiga `fixup` qiling, bittasini `reword`, bittasining o'rnini almashtiring, bittasini `drop`. Oldingi va keyingi log'ni va todo ro'yxatini yozing.

14. **Autosquash.** 3 toza commit'li branch'da birinchi commit'ga tegishli tuzatishni `git commit --fixup=<sha>` bilan yozing, keyin `git rebase -i --autosquash` qiling. Todo ro'yxati qanday ko'rinishda ochildi? Bu oqim PR review'da nima uchun qulay?

15. **Split a commit.** Ikki mustaqil o'zgarishni o'z ichiga olgan eski (oxirgi emas) commit'ni interactive rebase'ning `edit` buyrug'i bilan ikki commit'ga bo'ling. Qaysi buyruqlar ketma-ketligini ishlatdingiz va har qadamda `HEAD` qayerda edi?

16. **Rebase onto.** `main` dan `feature-a`, undan `feature-b` chiqqan zanjir yarating. `feature-b` ni `feature-a` commit'larisiz to'g'ridan-to'g'ri `main` ustiga ko'chiring (`--onto`). Graph'ni oldin va keyin ko'rsating, buyruqning uch argumentini izohlang.

### D. Cherry-pick, stash, tag

17. **Backport with cherry-pick.** `main` va `release/1.0` branch'lari bo'lsin. `main` da bugfix commit qiling va uni `release/1.0` ga `cherry-pick -x` bilan o'tkazing. Ikki commit'ning SHA, tree va xabarini solishtiring. Keyin `release/1.0` ni `main` ga merge qilsangiz nima bo'ladi?

18. **Stash internals.** Staged, unstaged va untracked o'zgarishlar hosil qiling. `git stash` va `git stash -u` farqini ko'rsating. `git log --graph --oneline stash@{0}` bilan stash aslida nima ekanini ko'rsating. `pop` paytida conflict hosil qiling: stash ro'yxatda qoldimi?

19. **Tags.** Bitta commit'ga lightweight, boshqasiga annotated tag qo'ying. `git cat-file -t <tag>` va `git cat-file -p <tag>` natijalarini solishtiring. Bir necha commit qo'shib `git describe` va `git describe --tags` ni ishga tushiring, chiqqan satrning har qismini izohlang. `git checkout <tag>` dan keyin `HEAD` qanday holatda?

### E. Bisect va kichik loyiha

20. **Manual bisect.** Skript bilan 20 commit'li repo yarating (har commit `calc.sh` ga kichik o'zgarish kiritadi), ulardan biri natijani buzsin (qaysi biri ekanini o'zingizdan yashiring, masalan tasodifiy tanlab). `git bisect` ni qo'lda `good`/`bad` bilan yuritib aybdor commit'ni toping. Necha qadam ketdi va bu log2(N) ga mosmi?

21. **bisect run.** 20-vazifa uchun `task_21.sh` test skripti yozing (to'g'ri bo'lsa `exit 0`, buzuq bo'lsa `exit 1`) va `git bisect run` bilan avtomatik toping. Keyin commit'lardan birini skript umuman ishlamaydigan qilib qo'ying va `125` exit code bilan o'tkazib yuborishni qo'shing. `git bisect log` ni yozing.

22. **Release branch drill.** Bitta repoda to'liq ssenariy: `main` da 3 commit, `v1.0.0` annotated tag; `release/1.0` branch; `main` da 2 yangi feature (biri `--no-ff` merge, biri rebase + fast-forward); `main` da topilgan bug `main` da tuzatiladi va `release/1.0` ga backport qilinadi, `v1.0.1` tag; `main` dagi bir feature'ning butun merge'i revert qilinadi. Yakuniy `git log --oneline --graph --all --decorate` ni yozing va har ref qaysi commit'da nima uchun turganini izohlang. `git describe` `main` va `release/1.0` da nima beradi?

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
