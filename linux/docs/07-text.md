# 7-dars: Matn qayta ishlash

Maqsad: matnli oqimlarni buyruq satrida tahlil qilish va o'zgartirish: `grep`, `sed`, `awk`, `head`, `tail`, `sort`, `uniq`, `cut`, `wc`, `tr`, `xargs` va ularni pipe bilan ulash. Linux'da konfiguratsiya, loglar, `/proc` va deyarli har buyruq chiqishi matn, shuning uchun "serverda hozir nima bo'lyapti" degan savolga birinchi javob shu vositalar bilan olinadi: monitoring ishlamay qolganda ham, yangi serverda ham ular bor. Dars 5-darsdagi pipe, redirection va quoting ustiga quriladi va haqiqiy nginx access logini tahlil qilish bilan tugaydi. 8-dars (resurslar va loglar), 9-dars (jarayonlar) va keyingi modullardagi `kubectl`, `docker`, `journalctl` chiqishlarini filtrlash shu ko'nikmaga tayanadi.

Taxminiy vaqt: 3–4 kun (siz uchun). JS'dagi `filter`, `map`, `reduce` va regex tajribangiz to'g'ridan-to'g'ri ko'chadi. E'tiborni quyidagilarga qarating: pipeline'ni bosqichma-bosqich qurish, `sort | uniq -c | sort -rn` idiomasi, `grep` regex turlari (BRE, ERE), `awk` ning maydonlar modeli va assotsiativ massivlar, `sed -i` xavflari, `xargs` va bo'shliqli nomlar, locale ta'siri.

## Laboratoriya

- **`lab` VM** (tavsiya etiladi): `multipass start lab && multipass shell lab`. Bu darsda tizim o'zgartirilmaydi, faqat fayllar o'qiladi va uy papkangizda yangi fayllar yaratiladi. 5, 14 va 15-vazifalar `/etc/ssh/sshd_config` ni o'qiydi, u ish mashinangizda yo'q (OpenSSH server o'rnatilmagan), VM'da bor.
- **Ish mashinasi**: log tahlili vazifalarini (1, 3, 4, 6, 9, 16–19, 22) bu yerda ham bajarish mumkin, bash'da (`bash` deb kiring).
- Ma'lumot: Elastic'ning ochiq namunalaridan haqiqiy nginx access logi (taxminan 51 ming qator, 6.7M). Repo'ga commit qilinmaydi, repo tashqarisida saqlang:

```
mkdir -p ~/lab-data && cd ~/lab-data
curl -fsSL -o nginx_logs "https://raw.githubusercontent.com/elastic/examples/master/Common%20Data%20Formats/nginx_logs/nginx_logs"
wc -l nginx_logs
```

- Ubuntu'da `awk` bu `mawk` (`readlink -f /usr/bin/awk`). Darsdagi hamma narsa POSIX awk doirasida, `gawk` kerak emas.
- Ish mashinangizda locale ingliz bo'lmasa, sonlar va saralash tartibi farq qilishi mumkin (7-bo'lim). Natijalar kutilgandan farq qilsa buyruq oldiga `LC_ALL=C` qo'ying.

Tozalash: dars oxirida `rm -r ~/lab-data` (qayerda yaratgan bo'lsangiz), `multipass stop lab`.

---

## 1. Pipe va Unix falsafasi

Har vosita bitta ishni qiladi, stdin'dan o'qiydi, stdout'ga yozadi. Murakkab ish ularni `|` bilan ulab yig'iladi.

```
awk '{print $1}' nginx_logs | sort | uniq -c | sort -rn | head -5
```

- Pipeline'dagi buyruqlar **bir vaqtda** ishlaydi, har biri alohida jarayon. Ma'lumot oqim bo'lib o'tadi: `grep` 10 GB faylni xotiraga yuklamaydi, qatorma-qator o'qiydi. Istisno: `sort` butun kirishni ko'rishi kerak (katta kirishda vaqtinchalik fayl ishlatadi).
- `head` kerakli qatorlarni olib chiqib ketsa, oldingi buyruq yozishda SIGPIPE oladi va to'xtaydi. Shuning uchun `... | head -5` butun faylni o'qib chiqishni kutmaydi.
- Pipe'ga faqat stdout o'tadi, stderr terminalda qoladi (5-dars).
- Pipeline'ni bosqichma-bosqich quring: har qadamdan keyin `| head` bilan natijani ko'ring, keyin navbatdagi bo'g'inni qo'shing. Tayyor uzun qatorni birdan yozish xatoni topishni qiyinlashtiradi.

## 2. Ko'rish va sanash: head, tail, wc

| Buyruq | Nima qiladi |
|--------|-------------|
| `head -n 20 f`, `head -c 100 f` | birinchi 20 qator, birinchi 100 bayt |
| `tail -n 20 f` | oxirgi 20 qator |
| `tail -n +2 f` | 2-qatordan oxirigacha (sarlavhani tashlash) |
| `tail -f f` | fayl oxirini kuzatish, yangi qatorlar chiqib turadi |
| `tail -F f` | xuddi shu, lekin fayl almashtirilsa (log rotatsiyasi) qayta ochadi |
| `wc -l`, `-w`, `-c` | qatorlar, so'zlar, baytlar soni |

`tail -f` ochiq fayl descriptor'ni kuzatadi. Rotatsiyada fayl nomi o'zgartirilib yangisi yaratiladi, `-f` eski faylda qoladi va "jim bo'lib qoladi". Loglar uchun `-F`.

## 3. grep

`grep PATTERN fayl...` pattern mos kelgan **qatorlarni** chiqaradi.

| Flag | Ma'nosi |
|------|---------|
| `-i` | registrga qaramasdan |
| `-v` | mos **kelmagan** qatorlar |
| `-n` | qator raqami bilan |
| `-c` | mos qatorlar soni (topilmalar soni emas) |
| `-o` | faqat mos kelgan qism, har biri alohida qatorda |
| `-w` | butun so'z |
| `-r`, `-l` | papka bo'ylab rekursiv; faqat fayl nomlari |
| `-A N`, `-B N`, `-C N` | topilmadan keyin, oldin, ikki tomonda N qator |
| `-E` | kengaytirilgan regex (ERE) |
| `-F` | pattern regex emas, oddiy satr |
| `-q` | chiqishsiz, faqat exit code (skriptlarda) |

Exit code: 0 topildi, 1 topilmadi, 2 xato. `if grep -q ...; then` shunga tayanadi.

### Regex

| Element | Ma'nosi |
|---------|---------|
| `.` | istalgan bitta belgi |
| `^`, `$` | qator boshi, qator oxiri |
| `[abc]`, `[0-9]`, `[^abc]` | to'plamdan bitta belgi, to'plamdan tashqari |
| `*` | oldingi element 0 yoki ko'p marta |
| `+`, `?` | 1 yoki ko'p, 0 yoki 1 (ERE) |
| `{n,m}` | n dan m gacha (ERE) |
| `a|b`, `( )` | yoki, guruh (ERE) |
| `\.` | harfma-harf nuqta |

- Standart `grep` BRE ishlatadi: unda `+`, `?`, `|`, `( )`, `{ }` oddiy belgilar. `grep -E` da ular maxsus. Chalkashmaslik uchun regex kerak bo'lsa doim `-E`.
- JS'dagi `\d`, `\w`, `\s` POSIX regex'da kafolatlanmagan: `[0-9]`, `[[:alnum:]_]`, `[[:space:]]` yozing. GNU grep'da `-P` (PCRE) bor, lekin u hamma tizimda mavjud emas.
- Pattern har doim bittalik tirnoqda: aks holda shell `*`, `$`, `|` ni o'zi talqin qiladi (3 va 5-darslar).

**Tuzoq: nuqta va qism mosligi.** `grep 10.0.0.1` da nuqta "istalgan belgi", u `10.0.0.11`, `110.0.0.1` va `10a0b0c1` ga ham mos keladi. Aniq qidiruv: `grep -F -w '10.0.0.1'`. Xuddi shunday `grep 404` status kodini emas, ichida `404` bor har qatorni topadi (bayt soni, URL, IP).

## 4. cut, tr, sort, uniq

### cut va tr

```
cut -d: -f1,7 /etc/passwd        # fields 1 and 7, delimiter ":"
cut -c1-10 file                  # characters 1 to 10
tr 'a-z' 'A-Z' < file            # translate characters
tr -d '\r' < win.txt > unix.txt  # delete carriage returns
tr -s ' ' < file                 # squeeze repeated spaces into one
```

- `cut` ajratuvchisi aynan bitta belgi va ketma-ket ajratuvchilar bo'sh maydon hisoblanadi. Bir nechta bo'shliq bilan tekislangan chiqishda (`ls -l`, `ps`, `df`) `cut` noto'g'ri ishlaydi, u yerda `awk` kerak.
- `tr` belgilar bilan ishlaydi (satrlar bilan emas), faqat stdin'dan o'qiydi, fayl argumenti olmaydi.

### sort va uniq

| Flag | Ma'nosi |
|------|---------|
| `sort -n` | sonli saralash (`-n` siz `10` `9` dan oldin turadi) |
| `sort -r` | teskari |
| `sort -k2,2` | 2-maydon bo'yicha (`-k2` esa 2-maydondan qator oxirigacha) |
| `sort -t: -k3,3n` | ajratuvchi `:`, 3-maydon sonli |
| `sort -h` | `du -h` uslubidagi hajmlar (`2K`, `1G`) |
| `sort -V` | versiya raqamlari (`1.9` `1.10` dan oldin) |
| `sort -u` | takrorlarni tashlab |
| `uniq -c` | ketma-ket bir xil qatorlarni sanab birlashtiradi |
| `uniq -d`, `uniq -u` | faqat takrorlanganlar, faqat yagonalar |

`uniq` faqat **yonma-yon** turgan takrorlarni ko'radi, shuning uchun oldidan `sort` kerak. Eng ko'p ishlatiladigan idioma, "nima necha marta uchraydi, ko'pidan kamiga":

```
... | sort | uniq -c | sort -rn | head
```

## 5. sed

`sed` oqim muharriri: har qatorni o'qiydi, buyruqlarni qo'llaydi, natijani chiqaradi. Faylni o'zgartirmaydi (faqat `-i` bilan).

```
sed 's/old/new/' f            # first match on each line
sed 's/old/new/g' f           # all matches
sed -n '10,20p' f             # print only lines 10-20 (-n: no automatic print)
sed '/^#/d' f                 # delete comment lines
sed '5d' f                    # delete line 5
sed -E 's/([0-9]+)x([0-9]+)/\2x\1/' f   # groups and back-references
sed 's|/var/www|/srv/www|g' f # any delimiter can replace "/"
sed '/^Port /s/22/2222/' f    # substitute only on lines matching an address
```

- Buyruq oldidagi **manzil** qaysi qatorlarga qo'llanishini belgilaydi: raqam, oraliq (`10,20`), regex (`/pattern/`), `$` (oxirgi qator).
- Almashtirish qismida `&` butun mos kelgan matn, `\1`, `\2` guruhlar.
- `-E` grep'dagi kabi ERE'ni yoqadi.
- `-i` faylni joyida o'zgartiradi. `-i.bak` avval nusxa oladi.

**Tuzoq: `sed -i`.** U faylni tahrirlamaydi, yangi fayl yozib eskisining o'rniga qo'yadi: inode o'zgaradi, hard linklar uziladi, symlink oddiy faylga aylanadi (symlink saqlanishi uchun GNU sed'da `--follow-symlinks`). Regex xato bo'lsa konfiguratsiya jimgina buziladi. Tartib: avval `-i` siz ishga tushirib chiqishni (yoki `diff` ni) ko'ring, keyin `-i.bak`.

## 6. awk

`awk` har qatorni maydonlarga bo'ladi va `pattern { action }` qoidalarini qo'llaydi. Bu kichik dasturlash tili: o'zgaruvchilar, arifmetika, massivlar, `printf`.

| Nom | Ma'nosi |
|-----|---------|
| `$0` | butun qator |
| `$1`, `$2`, ... | maydonlar |
| `NF` | joriy qatordagi maydonlar soni (`$NF` oxirgi maydon) |
| `NR` | joriy qator raqami |
| `FS`, `OFS` | kirish va chiqish maydon ajratuvchisi |
| `BEGIN { }`, `END { }` | birinchi qatordan oldin, oxirgi qatordan keyin |

```
awk '{print $1, $9}' nginx_logs               # select fields
awk '$9 >= 400' nginx_logs                    # filter: no action means print the line
awk -F: '$3 >= 1000 {print $1}' /etc/passwd   # another field separator
awk '{s += $10} END {print s}' nginx_logs     # sum a column
awk 'NR > 1 && NF == 14' file                 # conditions on line number and field count
awk '{c[$9]++} END {for (k in c) print c[k], k}' nginx_logs   # group by and count
```

- Standart ajratuvchi "bir yoki bir nechta bo'shliq yoki tab", shuning uchun tekislangan chiqishlar (`ps`, `df`, `ls -l`) to'g'ri bo'linadi. `cut` dan asosiy farqi shu.
- Assotsiativ massiv (`c[kalit]++`) bu JS'dagi obyekt yoki `Map`. `for (k in c)` tartibi kafolatlanmagan, shuning uchun natija `sort` ga beriladi.
- Aniqlanmagan o'zgaruvchi 0 yoki bo'sh satr. Sonli va satrli taqqoslash kontekstga qarab tanlanadi: `$9 == 404` sonli, `$9 == "404"` satrli.
- `print a, b` orasiga `OFS` (standart bo'shliq) qo'yadi, `print a b` yopishtiradi. Formatlash uchun `printf "%-15s %5d\n", $1, $2`.
- Dastur har doim **bittalik** tirnoqda: `$1` ni awk ko'rishi kerak, shell emas. Shell o'zgaruvchisini uzatish: `awk -v min="$MIN" '$9 >= min'`.

Qachon nima: bitta maydonni aniq ajratuvchi bo'yicha olish uchun `cut`, qatorlarni filtrlash uchun `grep`, matnni almashtirish uchun `sed`, maydonlar, hisob-kitob yoki guruhlash kerak bo'lsa `awk`.

## 7. xargs

Ko'p buyruqlar ma'lumotni stdin'dan emas, argumentlardan oladi (`rm`, `mkdir`, `gzip`, `kill`). `xargs` stdin'dagi so'zlarni argumentlarga aylantirib buyruqni ishga tushiradi.

```
find . -name '*.log' | xargs wc -l            # wc -l a.log b.log c.log ...
find . -name '*.log' -print0 | xargs -0 gzip  # safe with spaces and newlines in names
cat hosts.txt | xargs -n 1 ping -c 1          # one argument per invocation
cat hosts.txt | xargs -I {} ssh {} uptime     # place the argument where {} is
find . -name '*.png' -print0 | xargs -0 -P 4 -n 10 optipng   # 4 processes in parallel
```

- Standart holatda `xargs` kirishni bo'shliq va yangi qator bo'yicha bo'ladi va tirnoqlarni o'zi talqin qiladi. Nomida bo'shliq bor fayl ikki argumentga aylanadi. Fayl nomlari uchun doim `-print0` va `-0` juftligi.
- Kirish bo'sh bo'lsa ham GNU `xargs` buyruqni bir marta ishga tushiradi. `-r` buni o'chiradi.
- `-n N` har chaqiruvga N ta argument, `-P N` parallel jarayonlar soni.
- Buyruq berilmasa `echo` ishlatiladi. Xavfli buyruqdan oldin `xargs echo rm` bilan nima bajarilishini ko'ring.

### Locale

Saralash tartibi, harf sinflari va sonlar formati `LANG` va `LC_*` ga bog'liq: bir xil pipeline ikki serverda har xil natija berishi mumkin (`sort` tartibi, `awk` `printf` da nuqta o'rniga vergul). Skriptlarda va natijani solishtirganda `LC_ALL=C` bilan bayt tartibiga o'tiladi; bu katta fayllarda `sort` va `grep` ni tezlashtiradi ham.

## 8. Logni tahlil qilish

nginx "combined" formati va `awk` ning standart bo'linishi:

```
93.180.71.3 - - [17/May/2015:08:05:32 +0000] "GET /downloads/product_1 HTTP/1.1" 304 0 "-" "Debian APT-HTTP/1.3 (0.8.16~exp12ubuntu10.21)"
```

| Maydon | Mazmuni |
|--------|---------|
| `$1` | mijoz IP manzili |
| `$4`, `$5` | vaqt (`[17/May/2015:08:05:32`) va vaqt zonasi (`+0000]`) |
| `$6` | metod, tirnoq bilan (`"GET`) |
| `$7` | yo'l |
| `$9` | status kodi |
| `$10` | javob hajmi, bayt |
| `$11` | referer |
| `$12` va keyingilari | user agent (ichida bo'shliq bor, maydonlarga sochilib ketadi) |

User agent kabi tirnoq ichidagi maydonlar uchun ajratuvchini `"` qilish qulay: `awk -F'"' '{print $6}'` (`$2` so'rov qatori, `$4` referer, `$6` user agent).

Ish tartibi:

1. Avval qarang: `head -3`, `wc -l`, `ls -lh`. Format va hajmni biling.
2. Maydonni tekshiring: `awk '{print $9}' f | sort | uniq -c`. Kutilmagan qiymat chiqsa bo'linish noto'g'ri.
3. Filtrni iloji boricha erta qo'ying: oldin `grep` yoki `awk` sharti, keyin `sort`.
4. Natijani boshqa yo'l bilan tekshiring: jami son `wc -l` bilan, guruhlar yig'indisi jami bilan mos kelishi kerak.

JSON formatidagi loglar uchun bu vositalar o'rniga `jq` ishlatiladi; u keyingi modullarda (`kubectl -o json`, cloud CLI) uchraydi.

## Tuzoqlar

- `grep 404`, `grep error` kabi aniqlanmagan pattern bilan sanash. Natija ortiqcha chiqadi va shu son hisobotga tushadi. Maydon bo'yicha tekshiring: `awk '$9 == 404'`.
- `sort` siz `uniq`. Xato bermaydi, shunchaki noto'g'ri son chiqaradi.
- Sonlarni `-n` siz saralash: `100` `20` dan oldin turadi.
- `sed -i` ni sinovsiz, nusxasiz ishlatish; symlink'li konfiguratsiyada linkni uzib qo'yish.
- `cut -d' '` ni tekislangan chiqishga qo'llash: ustun raqami qatordan qatorga siljiydi.
- awk dasturini qo'shtirnoqda yozish: `"{print $1}"` da `$1` ni shell ochadi.
- `find | xargs rm` nomida bo'shliq bor fayllar bilan: noto'g'ri fayl o'chadi. `-print0 | xargs -0` yoki `find -delete`.
- `tail -f` bilan kuzatilayotgan log rotatsiyadan keyin jim bo'ladi va "xato yo'q" degan noto'g'ri xulosa chiqadi. `tail -F`.
- `cat f | grep x | awk '{print $1}'` kabi ortiqcha bo'g'inlar katta fayllarda sekinlashtiradi: `awk '/x/ {print $1}' f` yetarli. Lekin o'qilishi muhimroq bo'lsa ortiqcha bo'g'in gunoh emas.
- Locale farqi: saralash tartibi va o'nlik ajratuvchi serverdan serverga o'zgaradi. Skriptlarda `LC_ALL=C`.

## Manbalar

- https://www.gnu.org/software/grep/manual/grep.html – GNU grep, regex bo'limi bilan
- https://www.gnu.org/software/sed/manual/sed.html – GNU sed
- https://www.gnu.org/software/gawk/manual/gawk.html – "GAWK: Effective AWK Programming" (POSIX awk va gawk kengaytmalari ajratib ko'rsatilgan)
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html – POSIX awk spetsifikatsiyasi
- https://www.gnu.org/software/coreutils/manual/coreutils.html – `sort`, `uniq`, `cut`, `tr`, `wc`, `head`, `tail`
- https://www.gnu.org/software/findutils/manual/html_mono/find.html#Invoking-xargs – `xargs`
- https://man7.org/linux/man-pages/man7/regex.7.html – `regex(7)`, POSIX BRE va ERE
- https://nginx.org/en/docs/http/ngx_http_log_module.html – nginx log formati (`combined`)
- https://github.com/elastic/examples/tree/master/Common%20Data%20Formats/nginx_logs – darsdagi namuna log
- Kernighan, Pike, "The Unix Programming Environment" – 4 bob (Filters)
- Aho, Kernighan, Weinberger, "The AWK Programming Language" (2-nashr)

---

## Vazifalar

Ish papkasi: `linux/07-text/` (`make new m=linux n=07 name=text` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (uzun chiqishni `head` bilan qisqartiring) va o'z so'zingiz bilan izoh. Skript (`task_22.sh`) va uning chiqishi (`report.txt`) shu papkaga saqlanadi. Log fayli `~/lab-data/nginx_logs` da qoladi, repo'ga qo'shilmaydi. Barcha buyruqlar bash'da.

### A. Ko'rish va oqim

1. **First look.** `nginx_logs` uchun: hajm, qatorlar soni, birinchi va oxirgi 3 qator. Birinchi qatorni maydonlarga ajratib, har birining ma'nosini yozing. `awk '{print NF}' nginx_logs | sort -n | uniq -c` nimani ko'rsatadi va maydonlar soni nima uchun hamma qatorda bir xil emas? Log qaysi sanadan qaysi sanagacha?

2. **tail -f and rotation.** Bir terminalda `while true; do date >> app.log; sleep 1; done` ni ishga tushiring. Ikkinchisida `tail -f app.log`, uchinchisida `tail -F app.log`. Keyin `mv app.log app.log.1` qiling (sikl yangi `app.log` yaratadi). Ikki `tail` qanday tutdi va nima uchun? Siklni `Ctrl+C` bilan to'xtating va fayllarni o'chiring.

3. **SIGPIPE.** `yes | head -3` ni bajaring: `yes` cheksiz yozadi, pipeline nima uchun tugadi? `echo "${PIPESTATUS[@]}"` qiymatlarini 5-darsdagi exit code jadvali bilan izohlang. `time (sort nginx_logs | head -1)` va `time (head -1 nginx_logs)` farqini tushuntiring: qaysi buyruq butun faylni o'qishga majbur?

### B. grep

4. **Counting 404.** 404 javoblar sonini uch usulda hisoblang: `grep -c 404`, tirnoq va bo'shliqlar bilan aniqlashtirilgan pattern, va `awk '$9 == 404'`. Sonlar farq qiladimi? Farqni keltirib chiqargan qator(lar)ni toping (ishora: `grep 404 | grep -v ...`). Qaysi usulga ishonasiz va nima uchun?

5. **Context and recursion.** `grep -rn 'PermitRootLogin' /etc/ssh` va `grep -rl 'Port' /etc/ssh` ni bajaring (ruxsat xatolarini `2>/dev/null` bilan yashiring). `/etc/ssh/sshd_config` da `Port` so'zi bor qatorlarni atrofidagi 2 qator bilan chiqaring. Kommentga olinmagan (faol) sozlamalarni chiqaradigan `grep` yozing: komment va bo'sh qatorlarsiz.

6. **Regex.** `grep -E` bilan: (a) IP manzili `80.` bilan boshlanadigan qatorlar soni (`180.` emas), (b) status kodi 4xx bo'lgan, lekin 404 bo'lmagan qatorlar, (c) `-o` bilan faqat sana qismini (`17/May/2015`) ajratib, kunlar bo'yicha so'rovlar soni, (d) yo'li `product_1` yoki `product_2` bilan tugaydigan so'rovlar. `grep -c '93.180.71.3'` va `grep -cF '93.180.71.3'` har doim bir xil natija beradimi, nima uchun? `grep '[0-9]+'` va `grep -E '[0-9]+'` farqini ko'rsating.

7. **grep in scripts.** `grep -q` va exit code'dan foydalanib bir qatorli tekshiruvlar yozing: `/etc/passwd` da `ubuntu` (yoki o'z foydalanuvchingiz) bormi; logda 5xx javob bormi. Har biri "yes" yoki "no" chiqarsin. `grep -c` ning exit code'i 0 ta topilganda nima va bu `set -e` li skriptda qanday muammo tug'diradi?

### C. cut, sort, uniq, tr

8. **passwd fields.** `/etc/passwd` dan faqat foydalanuvchi nomi va shell'ni chiqaring. Qaysi shell nechta foydalanuvchida ishlatilganini, ko'pidan kamiga, hisoblang. UID bo'yicha sonli saralab, eng katta 5 ta UID'li foydalanuvchini ko'rsating. `-n` siz saralasangiz natija qanday buziladi?

9. **uniq needs sort.** `awk '{print $9}' nginx_logs | uniq -c | head` va `... | sort | uniq -c` natijalarini solishtiring. Birinchisi nima uchun "noto'g'ri", lekin xato bermaydi? Birinchisining chiqishi aslida qanday savolga javob beradi? Noyob IP manzillar sonini ikki usulda toping (`sort -u` va `sort | uniq`).

10. **Sort keys.** (a) `du -sh /var/log/* 2>/dev/null` ni hajm bo'yicha kattadan kichikka saralang; `-h` o'rniga `-n` ishlatilsa nima bo'ladi? (b) `printf '1.10\n1.9\n1.2\n'` ni `sort`, `sort -n`, `sort -V` bilan saralab farqni izohlang. (c) Logdan "status, bayt" juftliklarini chiqarib, status bo'yicha o'sish, bayt bo'yicha kamayish tartibida saralang (ikki kalit) va birinchi 10 tasini ko'rsating. `-k2` va `-k2,2` farqi nima?

11. **tr and line endings.** `printf 'name,role\r\nali,admin\r\n' > win.csv` yarating. `file win.csv`, `cat -A win.csv` va `cut -d, -f2 win.csv | cat -A` nimani ko'rsatadi? Bu ko'rinmas belgi skriptda qanday xatoga olib keladi (masalan `[[ "$role" == "admin" ]]`)? `tr` bilan tuzating. Yana: birinchi qatorni katta harfga o'tkazing; `echo "a    b   c" | tr -s ' '` nima qiladi; `tr 'a-z' 'A-Z' win.csv` nima uchun ishlamaydi?

12. **cut limits.** `ls -l /etc | cut -d' ' -f5 | head` bilan hajm ustunini olishga urinib ko'ring. Natija nima uchun noto'g'ri? Ikki usulda tuzating: `tr -s` bilan va `awk` bilan. `df -h` chiqishidan faqat mount nuqtasi va foiz ustunlarini, 50% dan yuqori bo'lganlarini chiqaring.

### D. sed

13. **Substitute.** `head -5 nginx_logs` ustida (faylni o'zgartirmasdan): (a) `GET` ni `POST` ga, (b) barcha `/` larni `|` ga (qulay ajratuvchi tanlang), (c) `-E` va guruhlar bilan qatorni `vaqt IP` ko'rinishiga keltiring (masalan `17/May/2015:08:05:32 93.180.71.3`), (d) IP'ning oxirgi oktetini `xxx` bilan niqoblang. `s/a/b/` va `s/a/b/g` farqini `echo aaa | sed ...` bilan ko'rsating.

14. **Print and delete.** `sed -n` bilan logning 1000–1005 qatorlarini chiqaring; xuddi shuni `head` va `tail` bilan ham qiling. `/etc/ssh/sshd_config` dan komment va bo'sh qatorlarni `sed` bilan olib tashlang va natijani 5-vazifadagi `grep` natijasi bilan `diff <(...) <(...)` orqali solishtiring. `sed '5q' f` nima qiladi va `head -5` dan farqi bormi?

15. **In-place safely.** `cp /etc/ssh/sshd_config cfg` va `ln -s cfg cfg.link` qiling. Faqat `#Port 22` qatorini `Port 2222` ga o'zgartiradigan `sed` yozing: avval `-i` siz `diff <(sed ...) cfg` bilan tekshiring, keyin `-i.bak` bilan qo'llang. `ls -li cfg cfg.bak` da inode'lar bilan nima bo'ldi? Endi xuddi shunday buyruqni `cfg.link` ga `-i` bilan qo'llang va `ls -l` ni ko'ring: link nima bo'ldi? `--follow-symlinks` bilan takrorlang.

### E. awk

16. **Fields and filters.** (a) status 400 va undan yuqori bo'lgan so'rovlarning IP, status va yo'lini chiqaring (birinchi 10 ta), (b) javob hajmi 1 MB dan katta bo'lgan so'rovlar sonini toping, (c) faqat 100–105 qatorlarni qator raqami bilan chiqaring, (d) har qatorning oxirgi maydonini chiqaring. `awk '{print $1 $9}'` va `awk '{print $1, $9}'` farqi nima? `awk "{print $1}" nginx_logs | head -2` nima uchun butun qatorni chiqaradi?

17. **Aggregation.** Jami yuborilgan baytlarni toping va `printf` bilan GB da, ikki xona aniqlikda chiqaring. O'rtacha javob hajmini faqat status 200 uchun hisoblang. Eng katta javob hajmini va uning qatorini toping. Agar natijada nuqta o'rniga vergul chiqsa (yoki aksincha), sababini toping va `LC_ALL=C` bilan solishtiring.

18. **Group by.** Assotsiativ massiv bilan: (a) har status kodi bo'yicha so'rovlar soni, (b) eng ko'p so'rov yuborgan 10 ta IP, (c) har status kodi bo'yicha jami baytlar. (a) va (b) natijasini `sort | uniq -c` usuli bilan olingan natija bilan solishtirib bir xilligini ko'rsating. (a) dagi sonlar yig'indisi `wc -l` ga tengmi?

19. **Custom separator.** `-F'"'` bilan eng ko'p uchraydigan 5 ta user agent'ni toping. Standart bo'linish bilan (`$12`) xuddi shu savolga nima uchun to'g'ri javob olib bo'lmaydi? `awk -F:` bilan `/etc/passwd` dan UID'i 1000 va undan yuqori, shell'i `nologin` yoki `false` bilan tugamaydigan foydalanuvchilarni chiqaring. `awk -v` orqali chegara UID'ni shell o'zgaruvchisidan uzating.

### F. xargs

20. **xargs and spaces.** Papkada `a.log`, `b.log`, `my app.log` yarating (har biriga bir necha qator yozing). `find . -name '*.log' | xargs wc -l` xatosini yozing: `xargs` `wc` ga qanday argumentlar berdi (`xargs echo` yoki `xargs -n 1 echo` bilan ko'rsating)? `-print0` va `-0` bilan tuzating. `-n 1` va `-I {}` bilan har fayl uchun alohida `echo "file: ..."` chiqaring. `find . -name '*.nope' | xargs wc -l` nima qiladi (ishga tushirmang: avval `xargs echo wc -l` bilan ko'ring) va `-r` nimani o'zgartiradi?

21. **Parallel xargs.** Logni 20 bo'lakka bo'ling: `split -n l/20 -d ~/lab-data/nginx_logs part-`. Bo'laklarni `gzip` bilan ketma-ket (`xargs -n 1`) va parallel (`xargs -n 1 -P 4`) siqing, har birini `time` bilan o'lchang (ikkinchi o'lchovdan oldin `gunzip part-*.gz`). `nproc` qiymati bilan bog'lab natijani izohlang. Keyin `zcat part-*.gz | wc -l` asl fayl bilan mos kelishini tekshiring va bo'laklarni o'chiring.

### G. Yakuniy

22. **Log report.** `task_22.sh <logfile>` yozing. U quyidagi hisobotni sarlavhalar bilan chiqaradi: jami so'rovlar; noyob IP'lar soni; eng faol 5 ta IP (son bilan); status kodlari taqsimoti (son va foiz); eng ko'p so'ralgan 5 ta yo'l; eng ko'p 404 bergan 5 ta yo'l; kunlar bo'yicha so'rovlar soni (xronologik tartibda, alifbo tartibida emas); eng yuklangan 3 ta soat (`sana:soat` ko'rinishida); jami trafik GB da; eng ko'p uchraydigan 3 ta user agent. Talablar: `#!/usr/bin/env bash`, `set -euo pipefail`, `LC_ALL=C`, argument tekshiruvi (yo'q yoki o'qib bo'lmaydigan fayl uchun usage va `exit 2`), fayl nomi bo'shliqli bo'lsa ham ishlashi, shellcheck toza. `./task_22.sh ~/lab-data/nginx_logs > report.txt` natijasini saqlang. README'da ikkita ko'rsatkichni mustaqil usul bilan qayta hisoblab tekshiring va hisobotdan chiqadigan uchta kuzatuvni yozing (masalan trafikning asosiy manbai kim, 404 ulushi nimani anglatishi mumkin).

### Topshirish

Tayyor bo'lgach:
1. `linux/07-text/README.md` da 22 ta vazifa `## N. Title` sarlavhalari ostida.
2. Ish papkasida `task_22.sh` va `report.txt` bor, shellcheck hech narsa chiqarmaydi.
3. `nginx_logs` va boshqa katta fayllar repo'da yo'q (`git status` bilan tekshiring).
4. `make check` toza o'tadi.
5. `~/lab-data` va vaqtinchalik fayllar o'chirilgan. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Pipeline'dagi buyruqlar ketma-ket ishlaydimi yoki bir vaqtdami? `... | head -1` nima uchun tez tugaydi?
- `uniq` oldidan nima uchun `sort` kerak? `sort | uniq -c | sort -rn | head` har bo'g'ini nima qiladi?
- BRE va ERE farqi nima? `grep 10.0.0.1` nima uchun ortiqcha qatorlarni topadi?
- `grep -c` nimani sanaydi va nima uchun `grep -c 404` status kodlari soni emas?
- Qachon `cut`, qachon `awk` ishlatasiz?
- `sed -i` fayl bilan aslida nima qiladi va undan oldin qanday ehtiyot choralari ko'rasiz?
- awk'da `NR`, `NF`, `$0`, `$NF` nima? Guruhlab sanash qanday yoziladi?
- awk dasturi nima uchun bittalik tirnoqda yoziladi va shell o'zgaruvchisi unga qanday uzatiladi?
- `find | xargs` qachon buziladi va qanday tuzatiladi? `xargs -P` nima beradi?
- `tail -f` va `tail -F` farqi nima?
- Locale matn qayta ishlash natijasiga qanday ta'sir qilishi mumkin?
