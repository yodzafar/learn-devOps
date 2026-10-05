# 3-dars: Asosiy buyruqlar

Maqsad: fayl tizimida yurish va fayllar bilan ishlashning asosiy buyruqlarini (`pwd`, `cd`, `ls`, `mkdir`, `touch`, `cp`, `mv`, `rm`, `cat`, `less`, `find`), globbing va buyruqlar tarixini mexanizm darajasida tushunish. Bu buyruqlarni kundalik ishlatgansiz, shuning uchun dars "qanday yoziladi" haqida emas, "aslida nima sodir bo'ladi" haqida: pattern'ni buyruq emas shell ochishi, `cp` ning natijasi manzil mavjudligiga bog'liqligi, `mv` ning bir fayl tizimi ichida va tashqarisidagi farqi, `rm` ning qaytarib bo'lmasligi. 5-dars (shell), 6-dars (ruxsatlar, linklar) va 7-dars (matn qayta ishlash) shu asosga quriladi.

Taxminiy vaqt: 2 kun (siz uchun). E'tiborni quyidagilarga qarating: globbing va brace expansion farqi, tirnoqsiz pattern tuzoqlari, `cp -r` va `cp -a`, oxirgi slash semantikasi, `find` ifodalarining bajarilish tartibi va `-delete` joylashuvi, `-exec ... \;` va `-exec ... +` farqi.

## Laboratoriya

- **`lab` VM** (asosiy joy): `multipass start lab && multipass shell lab`. Barcha tajribalar `~/playground` papkasida. O'chirish va ko'chirish vazifalari faqat shu yerda bajariladi.
- **Ish mashinasi**: faqat o'qiydigan buyruqlar (`ls`, `find`, `less`). Ish mashinangizdagi shell `zsh`, globbing xatti-harakati bashdan farq qiladi (5-bo'lim), shuning uchun globbing vazifalari VM'dagi bashda.
- Javoblar ish papkasidagi `README.md` ga yoziladi. VM'dan natija olish uchun terminaldan ko'chiring yoki `multipass transfer` ishlating.

Tozalash: dars oxirida VM ichida `rm -r ~/playground`, keyin `multipass stop lab`.

---

## 1. Yo'llar va navigatsiya

| Yozuv | Ma'nosi |
|-------|---------|
| `/etc/ssh/sshd_config` | absolut yo'l, `/` dan boshlanadi, joriy papkaga bog'liq emas |
| `ssh/sshd_config` | nisbiy yo'l, joriy papkadan hisoblanadi |
| `.` | joriy papka |
| `..` | ota papka |
| `~` | uy papkangiz (`$HOME`), `~ali` bu `ali` ning uy papkasi |
| `-` | `cd -` oldingi papkaga qaytadi (`$OLDPWD`) |

- `pwd` joriy papkani chiqaradi, argumentsiz `cd` uyga qaytaradi.
- Joriy papka jarayonning xususiyati (`/proc/$$/cwd`). Skriptlar va servis konfiguratsiyalarida nisbiy yo'l xavfli: dastur qaysi papkadan ishga tushirilganiga bog'liq bo'lib qoladi. cron va systemd unit'larda har doim absolut yo'l yoziladi.
- `.` va `..` har papkada mavjud haqiqiy yozuvlar (`ls -a` da ko'rinadi).

## 2. ls

```
ls -l /etc/hostname
-rw-r--r-- 1 root root 9 Feb 10 12:00 /etc/hostname
```

| Ustun | Ma'nosi |
|-------|---------|
| `-rw-r--r--` | birinchi belgi tur (`-` fayl, `d` papka, `l` symlink), keyin ruxsatlar (6-darsda) |
| `1` | hard linklar soni (6-darsda) |
| `root root` | ega va guruh |
| `9` | hajm, bayt (`-h` bilan `K`, `M`, `G`) |
| `Feb 10 12:00` | oxirgi o'zgartirilgan vaqt (mtime) |

| Flag | Nima qiladi |
|------|-------------|
| `-a`, `-A` | yashirin fayllarni ham (`.` bilan boshlanadigan); `-A` `.` va `..` siz |
| `-h` | odam o'qiydigan hajm, `-l` bilan birga |
| `-t`, `-S` | vaqt bo'yicha (yangisi birinchi), hajm bo'yicha (kattasi birinchi) |
| `-r` | teskari tartib |
| `-d` | papka ichini emas, o'zini ko'rsatadi: `ls -ld /tmp` |
| `-R` | rekursiv |
| `-i` | inode raqami |
| `-1` | har qatorda bitta nom |

- "Yashirin" fayl bu shunchaki nomi nuqta bilan boshlanadigan fayl, alohida atribut emas.
- Papka uchun `ls -l` dagi hajm papka yozuvining hajmi, ichidagi fayllar yig'indisi emas. Yig'indi uchun `du -sh papka`.
- Fayl haqida to'liq ma'lumot: `stat fayl` (hajm, inode, uchta vaqt), turi: `file fayl` (mazmuniga qarab aniqlaydi, kengaytmaga emas).

**Tuzoq: `ls` chiqishini skriptda parse qilmang.** Fayl nomida bo'shliq yoki yangi qator bo'lishi mumkin, format locale'ga bog'liq. Skriptda glob (`for f in *.log`) yoki `find` ishlatiladi.

## 3. Yaratish: mkdir, touch

- `mkdir a/b/c` ota papka bo'lmasa xato beradi. `mkdir -p a/b/c` butun zanjirni yaratadi va papka mavjud bo'lsa xato bermaydi (skriptlar uchun idempotent).
- `touch fayl` fayl bo'lmasa bo'sh fayl yaratadi, bo'lsa vaqtlarini hozirga yangilaydi. Asl vazifasi vaqtni yangilash.

Har faylda uchta vaqt bor (`stat` ko'rsatadi):

| Vaqt | Qachon o'zgaradi | `ls` da |
|------|------------------|---------|
| mtime (Modify) | mazmun o'zgarganda | `ls -l` (standart) |
| ctime (Change) | inode o'zgarganda: ruxsat, ega, nom, mazmun | `ls -lc` |
| atime (Access) | o'qilganda (`relatime` tufayli har o'qishda emas) | `ls -lu` |

ctime "yaratilgan vaqt" emas va uni qo'lda o'rnatib bo'lmaydi. mtime ni esa `touch -d "2 days ago" fayl` bilan o'zgartirish mumkin, shuning uchun mtime dalil emas.

## 4. cp, mv, rm

### cp

| Flag | Nima qiladi |
|------|-------------|
| `-r` | papkani rekursiv ko'chiradi |
| `-a` | arxiv rejimi: rekursiv + ruxsat, ega, vaqt va symlink'larni saqlaydi |
| `-i` | ustidan yozishdan oldin so'raydi |
| `-n` | mavjud faylni ustidan yozmaydi |
| `-u` | faqat manba yangiroq bo'lsa yoki manzilda yo'q bo'lsa |
| `-v` | nima qilayotganini chiqaradi |

- `cp` standart holatda ustidan jimgina yozadi va vaqtni hozirga o'rnatadi. Backup va deploy uchun `cp -a`.
- **Natija manzil mavjudligiga bog'liq**: `cp -r src dst` da `dst` yo'q bo'lsa `src` nusxasi `dst` nomi bilan yaratiladi; `dst` mavjud papka bo'lsa natija `dst/src`. Bir skriptni ikki marta ishlatganda natija har xil chiqishining sababi shu.
- Papkaning ichini (o'zini emas) ko'chirish: `cp -a src/. dst/`.

### mv

`mv` ham ko'chiradi, ham nomini o'zgartiradi, bu bitta amal. Bir fayl tizimi ichida `mv` ma'lumotni ko'chirmaydi, faqat papka yozuvini o'zgartiradi: darhol bajariladi, atomik, inode o'sha-o'sha qoladi. Boshqa fayl tizimiga `mv` aslida nusxa olish va o'chirish: sekin va o'rtada uzilishi mumkin.

Atomik `mv` deploy'da ishlatiladi: fayl vaqtinchalik nom bilan yoziladi, keyin `mv` bilan joyiga qo'yiladi, o'quvchi hech qachon yarim yozilgan faylni ko'rmaydi. Buning uchun vaqtinchalik fayl o'sha fayl tizimida bo'lishi kerak.

### rm

- `rm fayl`, `rm -r papka`, `rmdir papka` (faqat bo'sh papka). `-f` mavjud bo'lmagan faylga xato bermaydi va so'ramaydi, `-i` har biri uchun so'raydi.
- Terminalda savat yo'q. `rm` papka yozuvini o'chiradi, ma'lumotni qaytarish standart vositalar bilan mumkin emas. Himoya: backup, snapshot, o'chirishdan oldin `ls` yoki `echo` bilan ko'rish.
- O'chirish huquqi faylning emas, papkaning ruxsatiga bog'liq (6-darsda).

**Tuzoq: bo'sh o'zgaruvchi bilan `rm -rf`.** `rm -rf "$DIR/"*` da `DIR` bo'sh bo'lsa buyruq `rm -rf /*` ga aylanadi. GNU `rm` faqat aynan `/` ni rad etadi (`--preserve-root`), `/*` ni shell alohida papkalarga ochib beradi va himoya ishlamaydi. Skriptda `set -u` va `"${DIR:?}"` ishlatiladi (5-darsda).

**Tuzoq: `-` bilan boshlanadigan nom.** `rm -rf` nomli fayl bo'lsa `rm *` uni flag deb o'qiydi. Himoya: `rm -- *` yoki `rm ./*`.

## 5. O'qish: cat, less

- `cat fayl` butun faylni stdout'ga chiqaradi. Kichik fayllar va pipe'ning boshlanishi uchun. `cat -n` qator raqamlari, `cat -A` ko'rinmas belgilar (tab `^I`, qator oxiri `$`, Windows'ning `^M`).
- Katta fayl uchun `less`: faylni to'liq xotiraga yuklamaydi, gigabaytli logni ham darhol ochadi.

| `less` klavishi | Nima qiladi |
|-----------------|-------------|
| `Space`, `b` | sahifa pastga, yuqoriga |
| `g`, `G` | boshi, oxiri |
| `/so'z`, `?so'z` | oldinga, orqaga qidiruv; `n`, `N` keyingi, oldingi |
| `F` | oxirini kuzatish (`tail -f` kabi), `Ctrl+C` bilan qaytish |
| `-N`, `-S` (ichida yozing) | qator raqamlari, uzun qatorlarni kesish |
| `q` | chiqish |

**Tuzoq: binary faylni `cat` qilish** terminalni buzishi mumkin (boshqaruv ketma-ketliklari). Avval `file fayl`. Terminal buzilsa `reset` buyrug'i tiklaydi.

## 6. Globbing

Pattern'ni buyruq emas, **shell** ochadi. `ls *.log` da `ls` yulduzchani hech qachon ko'rmaydi: shell uni mos fayl nomlari ro'yxatiga almashtiradi va `ls a.log b.log` ni ishga tushiradi.

| Pattern | Mos keladi |
|---------|------------|
| `*` | istalgan belgilar ketma-ketligi (bo'sh ham), `/` va boshidagi `.` dan tashqari |
| `?` | aynan bitta belgi |
| `[abc]`, `[a-z]`, `[0-9]` | to'plamdan bitta belgi |
| `[!abc]` | to'plamda bo'lmagan bitta belgi |
| `**` | rekursiv, faqat `shopt -s globstar` dan keyin (bash) |

- Nima ochilishini ko'rish uchun `echo`: `echo rm *.tmp` buyruqni bajarmaydi, faqat ochilgan ko'rinishini chiqaradi.
- `*` yashirin fayllarga mos kelmaydi. `rm -r dir/*` dan keyin `dir/.env` joyida qoladi.
- Glob regex emas: `*` globda "istalgan narsa", regex'da "oldingi belgining takrori" (7-darsda).
- Tirnoq globbing'ni o'chiradi: `'*.log'` va `"*.log"` shell tomonidan ochilmaydi.

### Hech narsa mos kelmasa

bash'da mos kelmagan pattern o'zgarishsiz, harfma-harf buyruqqa uzatiladi: `ls *.xyz` da `ls` ga `*.xyz` satri boradi va xatoni `ls` chiqaradi (`cannot access '*.xyz'`). zsh'da esa xatoni shell o'zi beradi (`no matches found`) va buyruq umuman ishga tushmaydi.

### Brace expansion

`{a,b,c}` va `{1..5}` glob emas: fayl mavjudligiga qaramasdan satrlar generatsiya qiladi va globbing'dan oldin bajariladi.

```
echo file{1..3}.txt          # file1.txt file2.txt file3.txt
mkdir -p app/{src,test,docs} # three directories with one command
cp config.yaml{,.bak}        # cp config.yaml config.yaml.bak
```

**Tuzoq: tirnoqsiz pattern boshqa buyruqqa.** `find . -name *.txt` da shell `*.txt` ni joriy papkadagi fayllarga ochib yuboradi va `find` noto'g'ri argumentlar oladi. Pattern buyruqning o'ziga yetib borishi kerak bo'lsa (`find -name`, `grep`, `tar --exclude`) tirnoqqa oling: `find . -name '*.txt'`.

## 7. find

`find` papka daraxtini aylanib, har fayl uchun ifodani hisoblaydi:

```
find <qayerdan> <testlar> <amal>
find /var/log -type f -name '*.log' -size +1M -print
```

| Test | Ma'nosi |
|------|---------|
| `-name 'p'`, `-iname 'p'` | nom glob bo'yicha (faqat nom, yo'l emas), registrsiz |
| `-type f`, `d`, `l` | fayl, papka, symlink |
| `-size +10M`, `-size -1k` | kattaroq, kichikroq |
| `-mtime -7`, `-mtime +30` | 7 kundan yangi, 30 kundan eski |
| `-mmin -60` | oxirgi 60 daqiqada o'zgargan |
| `-newer fayl` | berilgan fayldan yangi |
| `-user ali`, `-perm 644` | ega, ruxsat |
| `-empty` | bo'sh fayl yoki papka |
| `-maxdepth N`, `-mindepth N` | chuqurlik chegarasi |
| `!`, `-o`, `\( \)` | emas, yoki, guruhlash (standart bog'lovchi "va") |

| Amal | Nima qiladi |
|------|-------------|
| `-print` | yo'lni chiqaradi (amal yozilmasa standart) |
| `-ls` | `ls -l` ko'rinishida |
| `-delete` | o'chiradi |
| `-exec cmd {} \;` | har fayl uchun buyruqni alohida ishga tushiradi |
| `-exec cmd {} +` | fayllarni yig'ib, buyruqni iloji boricha kam marta ishga tushiradi |

- Ifoda **chapdan o'ngga** hisoblanadi va test yolg'on bo'lsa o'ngdagilar o'tkazib yuboriladi. `-delete` ham ifodaning bir qismi.
- `\;` da 10 000 fayl uchun 10 000 jarayon, `+` da bir nechta. `+` deyarli har doim to'g'ri tanlov.
- Ruxsat yo'q papkalar haqidagi xatolar stderr'ga chiqadi: `find / -name x 2>/dev/null`.

**Tuzoq: `-delete` ning joyi.** `find . -delete -name '*.tmp'` hamma narsani o'chiradi, chunki `-delete` `-name` dan oldin hisoblanadi. Tartib: avval testlar, oxirida amal. Qoida: avval `-print` bilan ishga tushiring, natijani ko'ring, keyin `-print` ni `-delete` ga almashtiring.

## 8. Buyruqlar tarixi

| Vosita | Nima qiladi |
|--------|-------------|
| `history`, `history 20` | tarix, oxirgi 20 tasi |
| `Ctrl+R` | teskari qidiruv, yana `Ctrl+R` oldingi topilma |
| `!!` | oxirgi buyruq (`sudo !!`) |
| `!$` | oxirgi buyruqning oxirgi argumenti (`Alt+.` ham) |
| `!42` | 42-raqamli buyruq |
| `history -d 42` | bitta yozuvni o'chirish |

- bash tarixni xotirada saqlaydi va `~/.bash_history` ga sessiya **tugaganda** yozadi. Ikki ochiq terminal bir-birining tarixini ko'rmaydi, sessiya `kill -9` bilan o'ldirilsa tarix yo'qoladi.
- `HISTSIZE` (xotirada), `HISTFILESIZE` (faylda) hajmni belgilaydi. Ubuntu'da `HISTCONTROL=ignoreboth`: takrorlar va bo'shliq bilan boshlangan buyruqlar tarixga yozilmaydi.

**Tuzoq: tarixdagi secret'lar.** `mysql -psecret` yoki `curl -H "Authorization: Bearer ..."` tarixga ochiq matnda tushadi va `~/.bash_history` da qoladi. Secret'ni argument sifatida bermang: fayl, muhit o'zgaruvchisi yoki interaktiv so'rov ishlating.

## Tuzoqlar

- `rm -rf "$VAR/"*` bo'sh o'zgaruvchi bilan. Production'ni o'chirgan eng mashhur xato turi. `set -u`, `"${VAR:?}"`, va avval `echo`.
- `find ... -delete` ni testlardan oldin yozish, yoki `-print` bilan sinab ko'rmasdan ishlatish.
- Tirnoqsiz pattern: `find -name *.log`, `grep -r *.js`. Joriy papkada mos fayl bo'lmaguncha ishlaydi, bo'lgan kuni sinadi.
- `cp -r src dst` ni idempotent deb o'ylash: ikkinchi ishga tushirishda `dst/src` paydo bo'ladi.
- `cp -r` bilan backup olish: ega, ruxsat va vaqtlar yo'qoladi. `cp -a` yoki `rsync -a`.
- `*` yashirin fayllarni olmaydi: `mv app/* new/` dan keyin `.env` va `.git` eski joyda qoladi.
- Skriptda nisbiy yo'l va `cd` natijasini tekshirmaslik: `cd build; rm -rf *` da `cd` muvaffaqiyatsiz bo'lsa `rm` joriy papkada ishlaydi. `cd build && rm ...` yoki `set -e`.
- Fayl tizimlari orasidagi `mv` atomik emas. Katta faylni `/tmp` dan boshqa diskka `mv` qilish o'rtada uzilsa yarim fayl qoladi.
- Parol va tokenni buyruq argumentida yozish: tarixda va `ps` chiqishida ko'rinadi.

## Manbalar

- https://www.gnu.org/software/coreutils/manual/coreutils.html – GNU coreutils (`ls`, `cp`, `mv`, `rm`, `touch`, `stat`)
- https://www.gnu.org/software/findutils/manual/html_mono/find.html – GNU findutils, `find` to'liq qo'llanma
- https://www.gnu.org/software/bash/manual/bash.html#Pattern-Matching – bash pattern matching
- https://www.gnu.org/software/bash/manual/bash.html#Brace-Expansion – brace expansion
- https://www.gnu.org/software/bash/manual/bash.html#Using-History-Interactively – bash history
- https://man7.org/linux/man-pages/man7/glob.7.html – `glob(7)`
- https://mywiki.wooledge.org/ParsingLs – nima uchun `ls` chiqishini parse qilmaslik kerak
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 2–4, 8, 17 boblar

---

## Vazifalar

Ish papkasi: `linux/03-basic-commands/` (`make new m=linux n=03 name=basic-commands` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Vazifalar `lab` VM'da, `~/playground` ichida bajariladi (boshqasi aytilmagan bo'lsa). Har guruh uchun alohida kichik papka oching (`~/playground/a`, `~/playground/b` ...).

### A. Navigatsiya va ls

1. **Absolute and relative.** `/var/log` ga absolut yo'l bilan o'ting. U yerdan `/etc/ssh` ga faqat nisbiy yo'l bilan o'ting. `cd -` ni ikki marta bajaring va nima bo'lganini izohlang. `ls -ld . ..` nimani ko'rsatadi va `/` da `..` qayerga olib boradi?

2. **ls columns.** `ls -l /etc/passwd /etc/shadow /tmp /bin` ni bajaring. Har qator uchun: fayl turi, ega, guruh, hajm, vaqt. `/tmp` uchun nima ko'rsatildi: papkaning o'zimi yoki ichimi? Buni qaysi flag bilan o'zgartirasiz?

3. **Sorting listings.** `/var/log` dagi eng katta 5 ta faylni, `/etc` da eng oxirgi o'zgartirilgan 5 ta yozuvni va eng eskisini toping (`ls` flag'lari va `head` bilan). `ls -lh /var/log` dagi papka hajmi bilan `du -sh /var/log/journal` (yoki boshqa papka) natijasi nima uchun farq qiladi?

4. **Hidden files.** Uy papkangizda `ls`, `ls -a`, `ls -A` natijalarini solishtiring. Faylni "yashirin" qiladigan narsa nima? `stat ~/.bashrc` va `file ~/.bashrc /usr/bin/ls /etc/localtime` chiqishini izohlang.

### B. Yaratish, ko'chirish, o'chirish

5. **Tree in one command.** Bitta `mkdir` buyrug'i bilan `app/{src/{api,web},test,docs,logs/{2025,2026}}` tuzilmasini yarating va `find app -type d` (yoki `tree`) bilan tekshiring. `-p` siz `mkdir x/y/z` ni bajaring va xatoni yozing. `mkdir -p` ni ikki marta bajarsangiz nima bo'ladi?

6. **Three timestamps.** Fayl yarating va `stat` bilan uchta vaqtini yozing. Keyin ketma-ket: mazmunini o'zgartiring, `chmod` bilan ruxsatini o'zgartiring, `cat` bilan o'qing. Har qadamdan keyin qaysi vaqt o'zgarganini jadvalga yozing. `touch -d "2020-01-01" fayl` dan keyin qaysi vaqt o'zgarmadi va nima uchun bu muhim?

7. **cp destination semantics.** `src/` papkasini bir nechta fayl bilan yarating. `cp -r src dst` ni ikki marta ketma-ket bajaring va har safar `find dst` natijasini yozing. Farqni izohlang. Ikkala holatda ham bir xil natija beradigan yozuvni toping.

8. **cp -r versus cp -a.** `src/` ichida eski vaqtli fayl (`touch -d`), ruxsati `600` bo'lgan fayl va symlink (`ln -s`) yarating. `cp -r src r` va `cp -a src a` qiling, `ls -l` bilan uchala papkani solishtiring: vaqt, ruxsat va symlink bilan nima bo'ldi? Backup uchun qaysi biri to'g'ri?

9. **mv and inodes.** Fayl yarating, `ls -i` bilan inode raqamini yozing. Uni shu papka ichida, keyin `/tmp` ga, keyin `/dev/shm` ga `mv` qiling va har safar inode raqamini tekshiring. Qaysi ko'chirishda inode o'zgardi? `findmnt -T` bilan uchala joyning fayl tizimini aniqlang va natijani izohlang.

10. **rm safety.** Quyidagilarni bajaring va har bir xatoni yozing: papkani `-r` siz `rm` qilish, bo'sh bo'lmagan papkani `rmdir` qilish, mavjud bo'lmagan faylni `rm` va `rm -f` qilish (exit code'larni solishtiring). `touch -- -rf` bilan fayl yarating, `rm *` uni o'chiradimi? To'g'ri usulda o'chiring.

11. **Empty variable trap.** Faqat `echo` bilan, hech narsa o'chirmasdan: `DIR=""` qilib `echo rm -rf "$DIR/"*` ni bajaring va chiqishni yozing. Xuddi shuni `echo rm -rf "${DIR:?}/"*` bilan takrorlang. Ikkinchi yozuv nima qildi? `rm --preserve-root` bu holatda nima uchun yordam bermas edi?

### C. O'qish

12. **less navigation.** `less /var/log/syslog` (yoki `/var/log/dpkg.log`) da: oxiriga o'ting, `error` so'zini orqaga qarab qidiring, qator raqamlarini yoqing, uzun qatorlarni kesish rejimini yoqing, `F` rejimiga o'tib qayting. Ishlatgan klavishlaringizni yozing. `cat` o'rniga `less` ishlatishning ikki sababi nima?

13. **Look before cat.** `file /usr/bin/ls /etc/hostname /var/log/wtmp` ni bajaring. `/usr/bin/ls` ni `cat` qilmasdan, uning birinchi 64 baytini xavfsiz ko'rish usulini toping (`head -c` va `od`). `printf 'a\tb\r\n' > t.txt` yarating va `cat t.txt` bilan `cat -A t.txt` farqini izohlang.

### D. Globbing

14. **Glob preview.** `touch app.log app.log.1 app.log.2.gz error.log a1.txt a2.txt a10.txt b1.txt .hidden.log` yarating. Faqat `echo` va pattern bilan tanlang: (a) barcha `.log` bilan tugaydiganlar, (b) `a` dan keyin aynan bitta belgi va `.txt`, (c) `a` yoki `b` bilan boshlanadigan `.txt`, (d) raqam bilan tugaydigan nomlar, (e) `a` bilan boshlanmaydiganlar. `.hidden.log` qaysi birida chiqdi va nima uchun?

15. **Brace versus glob.** `echo {a,b}.conf` va `echo [ab].conf` ni fayllar yo'q papkada bajaring va farqni izohlang. `ls *.xyz` xatosini kim chiqaradi: shell yoki `ls`? Xuddi shu buyruqni ish mashinangizdagi `zsh` da bajaring va xatolarni solishtiring. `cp fayl{,.bak}` nimaga ochilishini `echo` bilan ko'rsating.

16. **Unquoted pattern.** Ichida `a.txt` va `b.txt` bo'lgan papkada `find . -name *.txt` ni bajaring, xatoni yozing. Shell `find` ga aslida qanday argumentlar berganini `echo find . -name *.txt` bilan ko'rsating. Papkada faqat bitta `.txt` fayl bo'lsa nima bo'ladi va nima uchun bu yanada xavfli?

17. **Hidden and recursive.** `d/` papkasida oddiy va yashirin fayllar yarating. `ls d/*` va `echo d/.*` nimani ko'rsatadi? `shopt -s globstar` dan oldin va keyin `echo **/*.log` natijasini solishtiring (ichma-ich papkalarda `.log` fayllar yarating). `shopt -s dotglob` nimani o'zgartiradi?

### E. find

18. **find by tests.** Har biri uchun bitta `find` buyrug'i yozing: (a) `/etc` da oxirgi 7 kunda o'zgargan oddiy fayllar, (b) `/var` da 1M dan katta fayllar (`2>/dev/null` bilan), (c) `/etc` ning birinchi darajasidagi symlink'lar, (d) `/usr/share` da nomi `readme` bilan boshlanadigan fayllar, registrga qaramasdan, (e) uy papkangizdagi bo'sh papkalar. (b) da `2>/dev/null` olib tashlansa nima chiqadi?

19. **exec forms.** Ichida 20 ta fayl bo'lgan papkada `find . -type f -exec echo {} \;` va `find . -type f -exec echo {} +` ni bajaring. Har birida `echo` necha marta ishga tushdi, buni chiqishdan qanday bilasiz? `-exec ls -l {} +` bilan `-ls` farqi bormi? Qaysi shaklni qachon tanlaysiz?

20. **delete placement.** `del/` papkasida 5 ta `.tmp` va 5 ta `.keep` fayl yarating va `cp -a del del2` bilan nusxa oling. `del` da to'g'ri tartibda (avval `-print`, keyin `-delete`) faqat `.tmp` larni o'chiring. `del2` da `find del2 -delete -name '*.tmp'` ni bajaring va nima qolganini ko'ring. Nima uchun bunday bo'ldi?

### F. Tarix

21. **History mechanics.** `echo $HISTSIZE $HISTFILESIZE $HISTCONTROL` qiymatlarini yozing. Boshiga bo'shliq qo'yib buyruq bajaring va `history | tail` da bor-yo'qligini tekshiring. `!!`, `!$` va `Ctrl+R` ni sinang. Ikkinchi `multipass shell lab` sessiyasini oching: u birinchi sessiyaning hozirgi buyruqlarini ko'radimi, nima uchun?

### G. Yakuniy

22. **Project cleanup.** `~/playground/proj` da quyidagi buyruqlar bilan "iflos" loyiha yarating: `mkdir -p proj/{src,logs,tmp,node_modules/{a,b}}`; `touch proj/src/{index,app,util}.js proj/tmp/{1..5}.tmp proj/node_modules/{a,b}/index.js`; `touch -d "45 days ago" proj/logs/old-{1..3}.log`; `touch proj/logs/new-{1..2}.log`; `head -c 2M /dev/urandom > proj/tmp/big.bin`. Keyin har birini avval ko'rib (`-print` yoki `echo`), so'ng bajaring: (a) barcha `.tmp` fayllarni o'chiring, (b) 30 kundan eski loglarni `proj/archive/` ga ko'chiring (papkani yarating), (c) 1M dan katta fayllarni hajmi bilan ro'yxatlang, (d) `node_modules` dan tashqari barcha `.js` fayllarni toping, (e) `proj` ning vaqtlar va ruxsatlar saqlangan nusxasini `proj.bak` ga oling. Buyruqlar va yakuniy `find proj | sort` natijasini README'ga yozing.

### Topshirish

Tayyor bo'lgach:
1. `linux/03-basic-commands/README.md` da 22 ta vazifa `## N. Title` sarlavhalari ostida.
2. `make check` toza o'tadi.
3. VM'da `~/playground` o'chirilgan, `/tmp` va `/dev/shm` da 9-vazifadan qolgan fayl yo'q.
4. `multipass stop lab` qilingan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `ls *.log` da yulduzchani kim ochadi? Mos fayl bo'lmasa bash va zsh nima qiladi?
- Glob va brace expansion farqi nima?
- `find . -name *.txt` nima uchun ba'zan ishlaydi, ba'zan xato beradi?
- `cp -r src dst` natijasi nimaga bog'liq? `cp -r` va `cp -a` farqi nima?
- `mv` qachon atomik va bir zumda, qachon yo'q? Buni qanday tekshirasiz?
- mtime, ctime, atime farqi nima? Qaysi birini qo'lda o'zgartirib bo'ladi?
- `find` ifodasi qanday tartibda hisoblanadi va `-delete` ni noto'g'ri joyga qo'ysangiz nima bo'ladi?
- `-exec ... \;` va `-exec ... +` farqi nima?
- `rm -rf "$DIR/"*` nima uchun xavfli va qanday himoyalanasiz?
- bash tarixi qachon faylga yoziladi va tarixga secret tushmasligi uchun nima qilasiz?
