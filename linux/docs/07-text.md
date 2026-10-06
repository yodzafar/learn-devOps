# 7-dars: Matn qayta ishlash

Maqsad: matnli oqimlarni buyruq satrida tahlil qilish va o'zgartirish: `grep`, `sed`, `awk`, `head`, `tail`, `sort`, `uniq`, `cut`, `wc`, `tr`, `xargs` va ularni pipe bilan ulash. Linux'da konfiguratsiya, loglar, `/proc` va deyarli har buyruq chiqishi matn, shuning uchun "serverda hozir nima bo'lyapti" degan savolga birinchi javob shu vositalar bilan olinadi: monitoring ishlamay qolganda ham, yangi serverda ham ular bor. Dars 5-darsdagi pipe, redirection va quoting ustiga quriladi va haqiqiy nginx access logini tahlil qilish bilan tugaydi. 8-dars (resurslar va loglar), 9-dars (jarayonlar) va keyingi modullardagi `kubectl`, `docker`, `journalctl` chiqishlarini filtrlash shu ko'nikmaga tayanadi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A, B guruh vazifalari; ikkinchi kun 4–5 bo'limlar va C, D guruhlari; uchinchi kun 6-bo'lim (`awk`) va E guruhi; to'rtinchi kun 7–8 bo'limlar, "Birga bajaramiz" va F guruhi; beshinchi kun 22-vazifa (skript va hisobot) hamda README'ni tartibga solish. E'tiborni quyidagilarga qarating: pipeline'ni bosqichma-bosqich qurish, `sort | uniq -c | sort -rn` idiomasi, regex dialektlari (BRE, ERE, PCRE) va ularning JS regex'dan farqi, `awk` ning maydonlar modeli va assotsiativ massivlar, `sed -i` xavflari, `xargs` va bo'shliqli nomlar, locale ta'siri.

Qanday o'qish kerak: nazariyadagi misollar kichik namuna fayl (`req.log`, 8 qator) ustida ko'rsatilgan. Uni VM ichida heredoc bilan o'zingiz yarating va har buyruqni terib, chiqishni darsdagi bilan solishtiring: kirish bir xil bo'lgani uchun chiqish ham aynan bir xil chiqishi kerak. Farq chiqsa, bu xato terilgan buyruq yoki locale farqi (7-bo'lim), ikkalasini ham topish foydali mashq. Vazifalar esa boshqa, katta faylda (nginx logi) bajariladi. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsning hamma vazifasi `lab` VM ichida bajariladi (`SETUP.md`, Multipass, Ubuntu 24.04). Sabab: matn vositalari **userland** ga tegishli (1-dars: kernel'dan tashqaridagi dasturlar to'plami), Ubuntu'da ular GNU variantlari, macOS'da BSD variantlari. Nomlari bir xil, flag'lari va xatti-harakati farq qiladi. Serverlar Linux bo'lgani uchun GNU variantini o'rganamiz, VM esa ikkala host'da bir xil natija beradi.

```
multipass start lab
multipass shell lab        # prompt becomes ubuntu@lab:~$
```

| Joy | Nima bajariladi |
|-----|-----------------|
| Host (Zorin yoki macOS) | `make new`, `make check`, `git`, README va `task_22.sh` ni tahrirlash, `multipass transfer` |
| `lab` VM | barcha 22 vazifa: log tahlili, `/etc/passwd`, `/etc/ssh/sshd_config`, `sed -i`, `xargs`, `split`, `gzip` |

- Bu darsda tizim o'zgartirilmaydi: faqat fayllar o'qiladi va VM'dagi uy papkangizda yangi fayllar yaratiladi. `sudo` kerak emas. 5, 14 va 15-vazifalar `/etc/ssh/sshd_config` ni o'qiydi; u VM'da bor (OpenSSH server o'rnatilgan), host'da bo'lmasligi mumkin.
- Ma'lumot: Elastic'ning ochiq namunalaridan haqiqiy nginx access logi (taxminan 51 ming qator, 6.7M). VM ichida yuklab oling, repo'ga commit qilinmaydi:

```
mkdir -p ~/lab-data && cd ~/lab-data
curl -fsSL -o nginx_logs "https://raw.githubusercontent.com/elastic/examples/master/Common%20Data%20Formats/nginx_logs/nginx_logs"
wc -l nginx_logs
```

- Nazariya misollari uchun namuna fayl. Shu papkada yarating (heredoc 5-darsda o'tilgan: `<<'EOF'` dan `EOF` gacha bo'lgan qatorlar buyruqning stdin'iga beriladi):

```
cat > req.log <<'EOF'
08:01 10.0.0.1 GET /index.html 200 512
08:01 10.0.0.11 GET /api/users 200 2048
08:02 10.0.0.1 POST /api/login 401 128
08:02 110.0.0.1 GET /index.html 200 512
08:03 10.0.0.1 GET /img/404.png 200 4040
08:03 10.0.0.2 GET /missing 404 162
08:04 10.0.0.11 GET /api/users 500 0
08:05 10.0.0.1 GET /index.html 304 0
EOF
```

Olti maydon, bittadan bo'shliq bilan ajratilgan: vaqt, mijoz IP manzili, HTTP metodi, yo'l, status kodi, javob hajmi (bayt). Darsdagi misollarda `$` belgisi `ubuntu@lab:~/lab-data$` prompt'ining qisqartmasi, ya'ni hammasi VM ichida, shu papkada.

- Ubuntu'da `awk` buyrug'i `mawk` dasturiga ko'rsatadi: `readlink -f /usr/bin/awk` natijasi `/usr/bin/mawk`. Darsdagi hamma narsa POSIX awk doirasida (POSIX bu Unix tizimlari uchun umumiy standart, unga amal qilgan dastur hamma variantda ishlaydi), shuning uchun `gawk` kerak emas. Faqat gawk'da bor narsalar: `gensub()`, `asort()`, `PROCINFO["sorted_in"]`, `BEGINFILE`, `-i inplace`, `--csv`. Internetdagi misol shulardan birini ishlatsa, VM'da `sudo apt install gawk` kerak bo'ladi; bu darsda ular ishlatilmaydi.
- Fayllarni host va VM orasida ko'chirish (22-vazifa uchun): `task_22.sh` ni host'dagi ish papkasida yozasiz, VM'ga yuborib ishga tushirasiz, hisobotni qaytarib olasiz:

```
multipass transfer task_22.sh lab:/home/ubuntu/lab-data/task_22.sh     # host -> VM
multipass transfer lab:/home/ubuntu/lab-data/report.txt report.txt     # VM -> host
```

- Ko'chirilgan skript VM'da bajariladigan bo'lmasa (`Permission denied`, 6-dars), VM ichida `chmod +x task_22.sh` qiling.
- `shellcheck` (5-darsda o'rnatilgan) host'da `make check` uchun kerak. Ikkinchi mashinada hali yo'q bo'lsa: Zorin'da `sudo apt install shellcheck`, macOS'da `brew install shellcheck`.
- 2-vazifa uchta terminal so'raydi: uchta oynada alohida `multipass shell lab` oching.
- Ikkinchi mashinada tiklash: bu dars oldingi darslar holatiga tayanmaydi. `lab` VM bo'lsa, yuqoridagi `curl` va heredoc'ni o'sha mashinadagi VM'da qayta bajaring (log fayli git orqali ko'chmaydi, javoblar ko'chadi).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host'ning o'zi ham GNU userland (Ubuntu 24.04 asosida), shuning uchun darsdagi buyruqlar host'da bash ichida ham ishlaydi. Baribir vazifalarni VM'da bajaring: natijalar uydagi bilan bir xil bo'ladi va host'da `sshd_config` bo'lmasligi mumkin. |
| macOS (uy) | Host'da BSD userland va zsh. Aniq farqlar: `sed -i` ga bo'sh argument shart (`sed -i '' 's/a/b/' f`; `-i.bak` shakli ikkalasida ishlaydi), `sed --follow-symlinks` yo'q; `grep -P` yo'q; `awk` bu BSD awk (mawk ham, gawk ham emas); `cat -A` yo'q; `nproc` yo'q; bo'sh kirishda BSD `xargs` buyruqni umuman ishga tushirmaydi (GNU bir marta ishga tushiradi). Shuning uchun 11, 15, 20, 21-vazifalar host'da boshqacha natija beradi yoki ishlamaydi. Hammasini VM'da bajaring. |

Tozalash: dars oxirida VM ichida `rm -r ~/lab-data`, keyin host'da `multipass stop lab`.

---

## 1. Pipe va Unix falsafasi

### Bu nima

5-darsda pipe (`|`) bir buyruqning stdout'ini keyingisining stdin'iga ulashini ko'rdingiz. Bu darsdagi vositalarning hammasi **filtr**: stdin'dan matn o'qiydi, biror narsa qiladi, stdout'ga matn yozadi. Har biri bitta ishni qiladi, murakkab ish ularni ulab yig'iladi. Bunday zanjir **pipeline** deyiladi.

JS'dagi massiv metodlari zanjiri bilan o'xshashlik haqiqiy:

| JS | Shell | Nima qiladi |
|----|-------|-------------|
| `.filter(fn)` | `grep`, `awk 'shart'` | qatorlarni tanlaydi |
| `.map(fn)` | `cut`, `sed`, `awk '{print ...}'` | har qatorni o'zgartiradi |
| `.reduce(fn, acc)` | `awk '{s += $6} END {print s}'`, `wc -l` | hammasini bitta qiymatga yig'adi |
| `.sort()` | `sort` | saralaydi |
| `.slice(0, 5)` | `head -n 5` | boshidan kesadi |

Farqi mexanizmda: JS'da har metod avval to'liq yangi massiv yaratadi, keyin navbatdagisi ishlaydi. Pipeline'da esa ma'lumot oqim bo'lib o'tadi.

### Mexanizm

- Shell pipeline'dagi har buyruqni alohida **jarayon** (ishlab turgan dastur nusxasi, 1-dars) sifatida **bir vaqtda** ishga tushiradi va ularni kernel'dagi kichik bufer (pipe) orqali ulaydi.
- Chapdagi jarayon buferga yozadi, o'ngdagi o'qiydi. Bufer to'lsa yozuvchi kutadi, bo'sh bo'lsa o'quvchi kutadi. Shu sababli `grep` 10 GB faylni xotiraga yuklamaydi: qatorma-qator o'qiydi va o'tkazadi.
- Istisno: `sort` birinchi qatorni chiqarishdan oldin butun kirishni ko'rishi kerak (katta kirishda vaqtinchalik fayl ishlatadi).
- O'ngdagi jarayon chiqib ketsa, chapdagisi yopiq pipe'ga yozishga uringanda kernel unga `SIGPIPE` signalini yuboradi va u to'xtaydi. Signal bu kernel jarayonga yuboradigan qisqa xabar (1-darsda `SIGTERM` va `SIGINT` ni ko'rgansiz, batafsil 9-darsda).
- Pipe'ga faqat stdout o'tadi, stderr terminalda qoladi (5-dars).

### Misol

```
$ seq 1 1000000 | head -n 2
1
2
```

`seq 1 1000000` birdan milliongacha sonlarni yozadi. `head -n 2` ikki qatorni o'qib chiqib ketadi. `seq` keyingi yozishda `SIGPIPE` oladi va million qatorni yozib tugatmasdan to'xtaydi, shuning uchun buyruq bir zumda tugaydi.

Pipeline bosqichma-bosqich quriladi. "Qaysi status necha marta?" savoliga javobni uch qadamda yig'amiz:

```
$ cut -d' ' -f5 req.log | head -n 3
200
200
401
$ cut -d' ' -f5 req.log | sort | uniq -c
      4 200
      1 304
      1 401
      1 404
      1 500
```

Birinchi buyruqda faqat 5-maydon ajratildi va `head` bilan to'g'ri ustun olinganini tekshirdik. Ikkinchisida `sort` bir xil qiymatlarni yonma-yon keltirdi, `uniq -c` har guruhni bitta qatorga yig'ib oldiga sonini yozdi: `200` to'rt marta, qolganlari bir martadan. Yig'indi 4+1+1+1+1 = 8, fayldagi qatorlar soni bilan mos. `cut`, `sort`, `uniq` 4-bo'limda batafsil.

### Real ishda qachon kerak

- Incident paytida: "oxirgi 10 daqiqada qaysi IP eng ko'p so'rov yubordi", "qaysi endpoint 500 qaytaryapti" savollariga dashboard'siz javob.
- Boshqa buyruq chiqishini toraytirish: `docker ps`, `kubectl get pods`, `journalctl` natijasi ham matn, shu vositalar bilan filtrlanadi.
- CI skriptlarida: versiyani fayldan ajratib olish, test chiqishidan sonni olish.

### Nima uchun shunday

Unix mualliflari (1970-yillar, Bell Labs) bitta katta dastur o'rniga kichik filtrlar va ularni ulaydigan pipe'ni tanlashgan: har vosita sodda, alohida sinaladi, yangi masala esa yangi dastur yozmasdan mavjudlarini ulab yechiladi. Buning bahosi: umumiy format faqat "qatorlarga bo'lingan matn", tuzilma (maydon, tur) haqida kelishuv yo'q, har buyruq ajratuvchini o'zi bilishi kerak. Muqobili tuzilmali ma'lumot uzatish: PowerShell obyektlar uzatadi, JSON loglar uchun `jq` ishlatiladi (8-bo'lim oxirida).

## 2. Ko'rish va sanash: head, tail, wc

### Bu nima

Faylni to'liq ochmasdan uning boshi, oxiri va hajmini bilish vositalari. Katta log bilan ishlashda birinchi qadam har doim shu.

| Buyruq | Nima qiladi |
|--------|-------------|
| `head -n 20 f`, `head -c 100 f` | birinchi 20 qator, birinchi 100 bayt |
| `tail -n 20 f` | oxirgi 20 qator |
| `tail -n +2 f` | 2-qatordan oxirigacha (sarlavha qatorini tashlash) |
| `tail -f f` | fayl oxirini kuzatish, yangi qatorlar chiqib turadi |
| `tail -F f` | xuddi shu, lekin fayl almashtirilsa (log rotatsiyasi) nomi bo'yicha qayta ochadi |
| `wc -l`, `-w`, `-c` | qatorlar, so'zlar, baytlar soni |

### Misol

```
$ wc -l req.log
8 req.log
$ wc -l < req.log
8
$ head -n 2 req.log
08:01 10.0.0.1 GET /index.html 200 512
08:01 10.0.0.11 GET /api/users 200 2048
$ tail -n +7 req.log
08:04 10.0.0.11 GET /api/users 500 0
08:05 10.0.0.1 GET /index.html 304 0
```

- `wc -l req.log` son va fayl nomini chiqaradi. Skriptda faqat son kerak bo'lsa faylni stdin orqali bering (`< req.log`): `wc` nomni bilmaydi va faqat `8` chiqadi.
- `wc -l` aslida yangi qator belgisini (`\n`) sanaydi. Oxirgi qator `\n` bilan tugamagan faylda natija bittaga kam chiqadi.
- `tail -n +7` dagi `+` "oxiridan 7 ta" emas, "7-qatordan boshlab" degani: 8 qatorli fayldan 7 va 8-qatorlar chiqdi.

### Mexanizm: tail -f va file descriptor

`tail -f` faylni bir marta ochadi va o'sha ochiq **file descriptor** (jarayon ochgan faylning raqami, 1 va 5-darslar) orqali yangi baytlarni kutadi. File descriptor fayl nomiga emas, **inode** ga bog'langan (inode bu fayl ma'lumoti va metadata'sini saqlaydigan tuzilma, nom esa unga ko'rsatkich, 6-dars). Log rotatsiyasi (eski logni boshqa nomga o'tkazib, yangisini boshlash; buni odatda `logrotate` dasturi qiladi) faylni `mv` qiladi va shu nom bilan yangi fayl yaratadi. `-f` eski inode'da qoladi, unga endi hech kim yozmaydi. `-F` esa nomni kuzatadi va yangi fayl paydo bo'lsa uni qayta ochadi. Bu `tail -f` va `-F` ning butun farqi; 2-vazifada o'zingiz ko'rasiz.

### Real ishda qachon kerak

- Deploy'dan keyin `tail -F /var/log/nginx/error.log` bilan xatolarni jonli kuzatish.
- CSV sarlavhasini tashlab qayta ishlash: `tail -n +2 data.csv | ...`.
- "Bu fayl qanchalik katta?" savoli: `wc -l` va `ls -lh` (3-dars), `cat` qilishdan oldin.

### Nima uchun shunday

`head` va `tail` alohida buyruq, chunki ikkalasi ham oqim bilan ishlaydi va pipeline'ning istalgan joyiga qo'yiladi: `... | head` tekshirish uchun eng arzon usul. `tail -f` descriptor'ni kuzatishi Unix'ning "ochilgan fayl nomdan mustaqil yashaydi" qoidasidan kelib chiqadi (6-darsdagi hard link bilan bir xil sabab); `-F` shu qoida loglar uchun noqulay bo'lgani uchun keyin qo'shilgan.

## 3. grep va regex

### Bu nima

`grep PATTERN fayl...` pattern mos kelgan **qatorlarni** chiqaradi. Pattern bu **regex** (regular expression, matn shablonini tasvirlaydigan mini-til), JS'dagi `/.../` bilan bir oiladan, lekin dialekti boshqa.

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

Exit code (5-dars): `0` topildi, `1` topilmadi, `2` xato. `if grep -q ...; then` shunga tayanadi.

### Mexanizm

`grep` kirishni qatorma-qator o'qiydi va har qatorda pattern'ni **qatorning istalgan joyidan** qidiradi (JS'dagi `re.test(line)` kabi, `^...$` bo'lmasa qism mosligi yetarli). Mos kelsa butun qatorni chiqaradi. `-c` mos **qatorlarni** sanaydi: bitta qatorda uch topilma bo'lsa ham bir deb hisoblanadi. `-o` esa har topilmani alohida qatorga chiqaradi.

### Regex dialektlari

POSIX ikkita dialektni belgilaydi: **BRE** (basic) va **ERE** (extended). Uchinchisi **PCRE** (Perl uslubi), JS regex'ga eng yaqini.

| Element | JS | BRE: `grep`, `sed` | ERE: `grep -E`, `sed -E`, `awk` | PCRE: `grep -P` (faqat GNU) |
|---------|----|--------------------|-------------------------------|-----------------------------|
| istalgan belgi, qator boshi va oxiri | `.` `^` `$` | bir xil | bir xil | bir xil |
| to'plam | `[abc]` `[^abc]` `[0-9]` | bir xil | bir xil | bir xil |
| 0 yoki ko'p | `*` | `*` | `*` | `*` |
| 1 yoki ko'p | `+` | oddiy belgi (`\{1,\}` yozing) | `+` | `+` |
| 0 yoki 1 | `?` | oddiy belgi (`\{0,1\}` yozing) | `?` | `?` |
| n dan m gacha | `{n,m}` | `\{n,m\}` | `{n,m}` | `{n,m}` |
| guruh | `( )` | `\( \)` | `( )` | `( )` |
| raqam | `\d` | `[0-9]` | `[0-9]` | `\d` |
| bo'shliq belgisi | `\s` | `[[:space:]]` | `[[:space:]]` | `\s` |
| lazy (`+?`), lookahead | bor | yo'q | yo'q | bor |

- "Yoki" (JS'da `a|b`): ERE va PCRE'da xuddi shunday yoziladi, POSIX BRE'da umuman yo'q.
- BRE'da `+`, `?`, `|`, `( )`, `{ }` oddiy belgilar. GNU grep va GNU sed qo'shimcha sifatida BRE ichida `\+`, `\?`, `\|` ni tushunadi, lekin bu boshqa tizimlarda ishlamaydi. Chalkashmaslik uchun regex kerak bo'lsa doim `-E`.
- `\d` BRE va ERE'da yo'q: `grep -E '\d+'` raqamlarga mos kelmaydi. `[0-9]` yozing. `[[:space:]]`, `[[:alnum:]]`, `[[:upper:]]` kabi yozuvlar POSIX belgi sinflari, ular to'plam (`[ ]`) ichida yoziladi.
- BRE va ERE'da "ochko'zlik" (greedy) o'chirilmaydi: `.*` har doim imkon qadar uzun mos keladi. JS'dagi `.*?` o'rniga inkor to'plam yoziladi: `[^ ]*` ("bo'shliqqacha").
- Pattern har doim bittalik tirnoqda: aks holda shell `*`, `$`, `|` ni o'zi talqin qiladi (3 va 5-darslar).

### Misol

```
$ grep -n ' 5[0-9][0-9] ' req.log
7:08:04 10.0.0.11 GET /api/users 500 0
$ grep -E ' (401|404) ' req.log
08:02 10.0.0.1 POST /api/login 401 128
08:03 10.0.0.2 GET /missing 404 162
$ grep -c '[0-9]+' req.log
0
$ grep -cE '[0-9]+' req.log
8
```

- Birinchi buyruq: "bo'shliq, 5, ikki raqam, bo'shliq". `-n` tufayli chiqish `7:` bilan boshlanadi, bu qator raqami, keyin qatorning o'zi (u ham `08:04` bilan boshlangani uchun ikki nuqta ketma-ket ko'rinadi). Ikki tomondagi bo'shliq pattern'ni status maydoniga "bog'laydi".
- Ikkinchi buyruq: ERE'da guruh va "yoki". 5-qator (`/img/404.png`) chiqmadi, chunki u yerda `404` atrofida bo'shliq yo'q.
- Uchinchi va to'rtinchi: BRE'da `+` oddiy belgi, ya'ni "raqam va undan keyin plyus belgisi" qidirildi, bunday qator yo'q, natija `0`. ERE'da `+` "bir yoki ko'p", hamma 8 qator mos.

**Tuzoq: nuqta va qism mosligi.** Endi IP manzilini qidiramiz:

```
$ grep -c '10.0.0.1' req.log
7
$ grep -cFw '10.0.0.1' req.log
4
$ grep -c 404 req.log
2
```

Birinchi natija 7, lekin `10.0.0.1` manzilidan aslida 4 ta so'rov bor. Ikki sabab: regex'da nuqta "istalgan belgi", va grep qism mosligini qidiradi, shuning uchun `10.0.0.11` (2 ta qator) va `110.0.0.1` (1 ta qator) ham mos keldi. `-F` pattern'ni oddiy satr qiladi, `-w` esa topilmaning ikki tomonida so'z belgisi (harf, raqam, `_`) bo'lmasligini talab qiladi: to'g'ri javob 4. Xuddi shunday `grep -c 404` natijasi 2, holbuki 404 statusli so'rov bitta: ikkinchi qator `/img/404.png` yo'li va `4040` bayt tufayli mos keldi. Sonni hisobotga yozishdan oldin "pattern aynan qaysi maydonga tegishli" deb so'rang; maydon bo'yicha aniq tekshiruv 6-bo'limda (`awk`).

`-o` va exit code:

```
$ grep -oE '^[0-9]{2}:[0-9]{2}' req.log | uniq -c
      2 08:01
      2 08:02
      2 08:03
      1 08:04
      1 08:05
$ grep -q ' 999 ' req.log; echo $?
1
```

`-o` har qatordan faqat mos qismni (vaqtni) chiqardi, `uniq -c` daqiqa bo'yicha sanadi (fayl vaqt bo'yicha tartiblangani uchun bu yerda `sort` kerak bo'lmadi, 4-bo'lim). `-q` hech narsa chiqarmaydi, `$?` qiymati `1`: topilmadi.

### Real ishda qachon kerak

- Konfiguratsiyada sozlama qayerda berilganini topish: `grep -rn 'client_max_body_size' /etc/nginx`.
- Logda xato atrofidagi kontekst: `grep -C 3 'OutOfMemory' app.log`.
- Skriptda shart: `if grep -q '^ID=ubuntu' /etc/os-release; then ...`.
- Boshqa buyruq chiqishini toraytirish: `docker ps | grep -v Exited`.

### Nima uchun shunday

`grep` nomi `ed` muharriridagi `g/re/p` buyrug'idan ("global, regular expression, print"). BRE 1970-yillardagi shu muharrirdan qolgan: unda `+`, `?`, `|` yo'q edi, keyin ERE (`egrep`) qo'shilganda eski skriptlar buzilmasligi uchun BRE'da bu belgilar oddiyligicha qoldirildi va ikki dialekt POSIX'ga shu holicha kirdi. `\d`, lazy va lookahead Perl'dan chiqqan, JS ularni Perl'dan olgan, POSIX esa olmagan. GNU grep'dagi `-P` shu bo'shliqni to'ldiradi, lekin u GNU'ga xos: macOS'dagi BSD grep'da yo'q, shuning uchun ko'chma skriptlarda ERE va `[0-9]` ishlatiladi.

## 4. cut, tr, sort, uniq

### Bu nima

To'rtta kichik filtr: `cut` qatordan ustun kesib oladi, `tr` belgilarni almashtiradi yoki o'chiradi, `sort` qatorlarni saralaydi, `uniq` yonma-yon turgan bir xil qatorlarni birlashtiradi.

### cut va tr

```
cut -d: -f1,7 /etc/passwd        # fields 1 and 7, delimiter ":"
cut -c1-10 file                  # characters 1 to 10
tr 'a-z' 'A-Z' < file            # translate characters
tr -d '\r' < win.txt > unix.txt  # delete carriage returns
tr -s '=' < file                 # squeeze repeated "=" into one
```

Mexanizm: `cut` har qatorni `-d` bilan berilgan **bitta belgi** bo'yicha bo'ladi va `-f` dagi maydonlarni o'sha ajratuvchi bilan chiqaradi. Ketma-ket ikki ajratuvchi orasida bo'sh maydon bor deb hisoblanadi. `tr` qator va maydonni bilmaydi: stdin'dagi har belgini birinchi to'plamdan ikkinchisidagi mos o'rinli belgiga almashtiradi. U fayl argumenti olmaydi, faqat stdin'dan o'qiydi.

```
$ cut -d: -f1,7 /etc/passwd | head -n 2
root:/bin/bash
daemon:/usr/sbin/nologin
$ cut -d' ' -f2,5 req.log | head -n 2
10.0.0.1 200
10.0.0.11 200
$ printf 'a  b\n' | cut -d' ' -f2

$ printf 'a  b\n' | awk '{print $2}'
b
$ echo 'x===y==z' | tr -s '='
x=y=z
```

- `/etc/passwd` (1-dars) maydonlari `:` bilan ajratilgan: 1-maydon foydalanuvchi nomi, 7-maydon login shell.
- `req.log` da ajratuvchi aynan bitta bo'shliq, shuning uchun `cut -d' '` to'g'ri ishladi.
- Uchinchi buyruqda `a` va `b` orasida ikki bo'shliq bor: `cut` uchun bu uch maydon (`a`, bo'sh, `b`), 2-maydon bo'sh, natija bo'sh qator. `awk` esa ketma-ket bo'shliqlarni bitta ajratuvchi deb oladi (6-bo'lim). Bo'shliq bilan tekislangan chiqishlarda (`ls -l`, `ps`, `df`) `cut` shu sababli ishlamaydi.
- `tr -s` ketma-ket takrorlangan belgini bittaga siqadi.

### sort va uniq

| Flag | Ma'nosi |
|------|---------|
| `sort -n` | sonli saralash |
| `sort -r` | teskari |
| `sort -k2,2` | 2-maydon bo'yicha (`-k2` esa 2-maydondan qator oxirigacha) |
| `sort -t: -k3,3n` | ajratuvchi `:`, 3-maydon sonli |
| `sort -h` | `du -h` uslubidagi hajmlar (`2K`, `1G`) |
| `sort -V` | versiya raqamlari (`1.9` `1.10` dan oldin) |
| `sort -u` | takrorlarni tashlab |
| `uniq -c` | ketma-ket bir xil qatorlarni sanab birlashtiradi |
| `uniq -d`, `uniq -u` | faqat takrorlanganlar, faqat yagonalar |

Mexanizm: `sort` standart holatda qatorlarni **satr** sifatida, belgima-belgi solishtiradi (JS'dagi argumentsiz `[10, 9, 100].sort()` bilan bir xil xatti-harakat va bir xil tuzoq). `-n` qator boshidagi sonni son sifatida o'qiydi. `-k` kalit maydonni belgilaydi, bir nechta `-k` berilsa birinchisi teng bo'lganda keyingisi ishlaydi, har kalitga o'z modifikatori (`n`, `r`) qo'shiladi. `uniq` esa faqat **oldingi qator** bilan solishtiradi: xotirada bitta qator ushlaydi, shuning uchun cheksiz oqimda ham ishlaydi, lekin yonma-yon bo'lmagan takrorlarni ko'rmaydi.

```
$ printf '10\n9\n100\n' | sort
10
100
9
$ printf '10\n9\n100\n' | sort -n
9
10
100
$ printf 'a\nb\na\n' | uniq -c
      1 a
      1 b
      1 a
$ printf 'web 3 512\ndb 1 2048\ncache 3 128\n' | sort -k2,2nr -k3,3n
cache 3 128
web 3 512
db 1 2048
```

- Satr tartibida `1` belgisi `9` dan oldin, shuning uchun `10` va `100` tepada. `-n` bilan to'g'ri.
- `uniq -c` da `a` ikki marta alohida chiqdi: ikkinchi `a` oldingi qator (`b`) ga teng emas. Xato xabari yo'q, exit code 0.
- Oxirgi buyruq: birinchi kalit 2-maydon, sonli, kamayish (`3`, `3`, `1`); 2-maydon teng bo'lgan ikki qator ichida ikkinchi kalit 3-maydon, sonli, o'sish (`128`, keyin `512`).

Eng ko'p ishlatiladigan idioma, "nima necha marta uchraydi, ko'pidan kamiga":

```
$ cut -d' ' -f5 req.log | sort | uniq -c | sort -rn | head -n 3
      4 200
      1 500
      1 404
```

`sort` guruhlaydi, `uniq -c` sanaydi, `sort -rn` son bo'yicha kamayish tartibiga soladi, `head` tepasini oladi. Bu SQL'dagi `GROUP BY ... ORDER BY count DESC LIMIT 3` ning o'zi.

### Real ishda qachon kerak

- "Top N" savollarining hammasi: eng faol IP, eng ko'p uchragan xato, eng katta papka (`du -sh * | sort -rh | head`).
- Windows'dan kelgan fayldagi `\r` ni olib tashlash (`tr -d '\r'`), aks holda skript satrlarni solishtirganda mos kelmaydi.
- `:` yoki `,` bilan ajratilgan fayldan ustun olish (`/etc/passwd`, sodda CSV).

### Nima uchun shunday

`uniq` ning faqat qo'shni qatorlarni ko'rishi kamchilik emas, dizayn: u xotira ishlatmaydi, saralash esa alohida vositaning ishi. Muqobili bitta buyruqda hash jadval bilan sanash, buni `awk` qiladi (6-bo'lim): saralash kerak emas, lekin hamma kalit xotirada turadi. `cut` ataylab sodda (bitta belgi, regex yo'q), shuning uchun tez va oldindan aytib bo'ladigan; murakkabroq bo'linish `awk` ga qoldirilgan.

## 5. sed

### Bu nima

`sed` (stream editor) oqim muharriri: har qatorni o'qiydi, unga buyruqlarni qo'llaydi, natijani chiqaradi. Asosiy ishi almashtirish (`s`), JS'dagi `line.replace(/re/, 'new')` ning o'xshashi. Faylni o'zgartirmaydi (faqat `-i` bilan).

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

### Mexanizm

Sikl: qatorni buferga (pattern space) o'qiydi, skriptdagi har buyruqni tartib bilan qo'llaydi, bufer mazmunini chiqaradi, keyingi qatorga o'tadi. `-n` oxirgi qadamni (avtomatik chiqarish) o'chiradi, shunda faqat `p` buyrug'i aytgan qatorlar chiqadi.

- Buyruq oldidagi **manzil** u qaysi qatorlarga qo'llanishini belgilaydi: raqam (`5`), oraliq (`10,20`), regex (`/pattern/`), `$` (oxirgi qator). Manzil bo'lmasa hamma qatorga.
- Standart regex BRE, `-E` ERE'ni yoqadi (3-bo'lim).
- Almashtirish qismida `&` butun mos kelgan matn, `\1`, `\2` guruhlar (JS'da `$&`, `$1`, `$2`).
- `g` bayrog'isiz har qatorda faqat birinchi topilma almashtiriladi (JS'dagi `/g` bilan bir xil ma'no).

### Misol

```
$ echo 'a-b-c' | sed 's/-/+/'
a+b-c
$ echo 'a-b-c' | sed 's/-/+/g'
a+b+c
$ echo '1920x1080' | sed -E 's/([0-9]+)x([0-9]+)/\2x\1/'
1080x1920
$ echo 'port 8080' | sed -E 's/[0-9]+/[&]/'
port [8080]
$ sed -n '2,3p' req.log
08:01 10.0.0.11 GET /api/users 200 2048
08:02 10.0.0.1 POST /api/login 401 128
$ sed '/ 200 /d' req.log
08:02 10.0.0.1 POST /api/login 401 128
08:03 10.0.0.2 GET /missing 404 162
08:04 10.0.0.11 GET /api/users 500 0
08:05 10.0.0.1 GET /index.html 304 0
$ sed -n '/POST/s/401/403/p' req.log
08:02 10.0.0.1 POST /api/login 403 128
```

- Birinchi juftlik `g` farqini ko'rsatadi: bitta va hamma chiziqcha.
- Uchinchisida ikki guruh joy almashdi; to'rtinchisida `&` topilgan sonning o'zini qavsga oldi.
- `-n '2,3p'`: avtomatik chiqarish o'chirilgan, `p` faqat 2–3 qatorlarga qo'llandi.
- `'/ 200 /d'`: ichida ` 200 ` bor to'rt qator o'chirildi, qolgan to'rttasi chiqdi.
- Oxirgisi manzil va buyruq birga: faqat `POST` bor qatorda `401` almashtirildi, `s` dan keyingi `p` bayrog'i almashtirish bo'lgan qatorni chiqardi. `req.log` ning o'zi o'zgarmadi.

### sed -i

`-i` natijani faylning o'ziga yozadi, `-i.bak` avval `.bak` nusxa qoldiradi. Mexanizm muhim: sed faylni joyida tahrirlamaydi, yonida vaqtinchalik fayl yaratib natijani unga yozadi va oxirida uni asl nom ustiga ko'chiradi. Oqibatlari: fayl yangi inode oladi (6-dars), hard linklar eski mazmunda qoladi, symlink esa oddiy faylga aylanadi (symlink saqlanishi uchun GNU sed'da `--follow-symlinks`). Regex xato bo'lsa konfiguratsiya jimgina buziladi, xato xabari bo'lmaydi. Tartib: avval `-i` siz ishga tushirib chiqishni yoki `diff` ni ko'ring, keyin `-i.bak`. macOS'dagi BSD sed'da `-i` dan keyin argument shart: `sed -i '' 's/a/b/' f`.

### Real ishda qachon kerak

- Skriptda konfiguratsiyadagi bitta qiymatni almashtirish (Dockerfile va CI'da ko'p uchraydi): `sed -i 's/^#Port 22/Port 2222/' ...`.
- Katta faylning o'rtasidan bo'lak olish: `sed -n '1000,1010p' big.log`.
- Logni birovga berishdan oldin maxfiy qismlarni niqoblash.

### Nima uchun shunday

`sed` interaktiv `ed` muharririning oqim varianti: buyruqlar oldindan yoziladi, shuning uchun skriptga va pipeline'ga qo'yish mumkin. `-i` ning "yangi fayl yozib almashtirish" usuli xavfsizlik uchun: jarayon o'rtada uzilsa asl fayl yarim yozilgan holda qolmaydi. Muqobili konfiguratsiyani shablondan to'liq qayta yaratish, Ansible va Helm shunday qiladi (IaC modulida); `sed -i` esa bir martalik va kichik o'zgarishlar uchun.

## 6. awk

### Bu nima

`awk` har qatorni maydonlarga bo'ladi va `pattern { action }` qoidalarini qo'llaydi. Bu kichik dasturlash tili: o'zgaruvchilar, arifmetika, massivlar, `printf`. Maydonlar, hisob-kitob yoki guruhlash kerak bo'lgan joyda ishlatiladi.

| Nom | Ma'nosi |
|-----|---------|
| `$0` | butun qator |
| `$1`, `$2`, ... | maydonlar |
| `NF` | joriy qatordagi maydonlar soni (`$NF` oxirgi maydon) |
| `NR` | joriy qator raqami |
| `FS`, `OFS` | kirish va chiqish maydon ajratuvchisi |
| `BEGIN { }`, `END { }` | birinchi qatordan oldin, oxirgi qatordan keyin |

### Mexanizm

awk dasturi qoidalar ro'yxati. Har kirish qatori uchun: qator `FS` bo'yicha maydonlarga bo'linadi, keyin har qoidaning pattern'i tekshiriladi, rost bo'lsa action bajariladi. Pattern bo'lmasa action hamma qatorga qo'llanadi; action bo'lmasa qator chiqariladi (`{print $0}`). JS'da tasavvur qilsangiz: `for (const line of lines) { const f = line.trim().split(/\s+/); if (pattern) action }`, bunda `$1` bu `f[0]`.

- Standart ajratuvchi "bir yoki bir nechta bo'shliq yoki tab", shuning uchun tekislangan chiqishlar (`ps`, `df`, `ls -l`) to'g'ri bo'linadi. `cut` dan asosiy farqi shu. Boshqa ajratuvchi: `-F:`.
- O'zgaruvchilar e'lon qilinmaydi: aniqlanmagan o'zgaruvchi `0` yoki bo'sh satr. `s += $6` birinchi qatordayoq ishlaydi.
- Assotsiativ massiv (`c[kalit]++`) JS'dagi `Map` yoki obyekt: kalit istalgan satr. `for (k in c)` tartibi kafolatlanmagan, shuning uchun natija `sort` ga beriladi.
- Taqqoslash kontekstga qarab tanlanadi: `$5 == 404` sonli, `$5 == "404"` satrli.
- `print a, b` orasiga `OFS` (standart bo'shliq) qo'yadi, `print a b` yopishtiradi. Formatlash uchun `printf "%-15s %5d\n", $1, $2` (yangi qatorni o'zingiz qo'yasiz).
- Dastur har doim **bittalik** tirnoqda: `$1` ni awk ko'rishi kerak, shell emas (5-dars: qo'shtirnoq ichida shell `$1` ni o'z o'zgaruvchisi deb ochadi). Shell qiymatini uzatish: `awk -v min="$MIN" '$5 >= min'`.

### Misol

```
$ awk '{print $2, $5}' req.log | head -n 2
10.0.0.1 200
10.0.0.11 200
$ awk '$5 >= 400' req.log
08:02 10.0.0.1 POST /api/login 401 128
08:03 10.0.0.2 GET /missing 404 162
08:04 10.0.0.11 GET /api/users 500 0
$ awk '$5 == 404' req.log
08:03 10.0.0.2 GET /missing 404 162
$ awk 'NR == 2 {print NF, $NF}' req.log
6 2048
$ awk '{s += $6} END {print s}' req.log
7402
$ awk '{s += $6} END {printf "%.2f KB\n", s/1024}' req.log
7.23 KB
$ awk -v min=500 '$5 >= min {print $1, $4}' req.log
08:04 /api/users
$ awk '{c[$2]++} END {for (ip in c) print c[ip], ip}' req.log | sort -rn
4 10.0.0.1
2 10.0.0.11
1 110.0.0.1
1 10.0.0.2
```

- `{print $2, $5}`: pattern yo'q, har qatordan ikki maydon (map).
- `$5 >= 400`: action yo'q, sharti rost qatorlar chiqdi (filter). `$5 == 404` aynan bitta qator beradi: 3-bo'limdagi `grep -c 404` ning noto'g'ri `2` javobi shu yerda tuzaldi, chunki shart aniq maydonga qo'yilgan.
- `NR == 2`: faqat 2-qator, unda `6` ta maydon bor va oxirgisi `2048`.
- `s += $6` har qatorda yig'adi, `END` faqat bir marta, oxirida ishlaydi (reduce): 512+2048+128+512+4040+162+0+0 = 7402. `printf` shu sonni 1024 ga bo'lib ikki xona aniqlikda chiqardi.
- `-v min=500` awk o'zgaruvchisini dastur boshlanishidan oldin o'rnatadi.
- Oxirgisi guruhlab sanash: `c` massivida kalit IP, qiymat hisoblagich. `END` da hamma juftlik chiqariladi, `sort -rn` tartibga soladi. `10.0.0.1` to'rt marta, 3-bo'limdagi `grep -cFw` natijasi bilan mos. Hisoblagich o'rniga `b[$2] += $6` yozilsa, guruh bo'yicha yig'indi chiqadi.

Qachon nima: bitta maydonni aniq ajratuvchi bo'yicha olish uchun `cut`, qatorlarni filtrlash uchun `grep`, matnni almashtirish uchun `sed`, maydonlar, hisob-kitob yoki guruhlash kerak bo'lsa `awk`.

### Real ishda qachon kerak

- Log va metrikalardan tezkor agregatsiya: status bo'yicha son, endpoint bo'yicha o'rtacha vaqt.
- Tekislangan buyruq chiqishidan ustun olish: `df -h | awk '{print $5, $6}'`, `ps aux | awk '$3 > 50'`.
- `kubectl get pods --no-headers | awk '$3 != "Running" {print $1}'` kabi filtrlar (Kubernetes modulida).

### Nima uchun shunday

awk 1977-yilda Aho, Weinberger va Kernighan tomonidan aynan "qator va maydonlardan iborat matn" uchun yaratilgan (nomi familiyalarining bosh harflari). Sikl (`for line of lines`) va bo'linish tilga qurilgan, shuning uchun foydali dastur bir qatorga sig'adi. Bir nechta variant bor: Ubuntu'da standart `mawk` (kichik va tez), `gawk` (GNU, ko'p kengaytmali), macOS'da BSD awk. POSIX doirasida yozilgan dastur uchalasida bir xil ishlaydi. Muqobili Python yoki Node skripti: 20 qatordan oshadigan mantiq uchun to'g'ri tanlov, lekin serverda bir qatorli savolga awk tezroq va har doim o'rnatilgan.

## 7. xargs va locale

### Bu nima

Ko'p buyruqlar ma'lumotni stdin'dan emas, **argumentlardan** oladi (`rm`, `mkdir`, `gzip`, `kill`): `echo a.txt | rm` hech narsa o'chirmaydi, chunki `rm` stdin'ni o'qimaydi. `xargs` stdin'dagi so'zlarni argumentlarga aylantirib buyruqni ishga tushiradi.

```
find . -name '*.log' | xargs wc -l            # wc -l a.log b.log c.log ...
find . -name '*.log' -print0 | xargs -0 gzip  # safe with spaces and newlines in names
cat hosts.txt | xargs -n 1 ping -c 1          # one argument per invocation
cat hosts.txt | xargs -I {} ssh {} uptime     # place the argument where {} is
find . -name '*.png' -print0 | xargs -0 -P 4 -n 10 optipng   # 4 processes in parallel
```

### Mexanizm

`xargs` stdin'ni o'qiydi, uni bo'shliq va yangi qator bo'yicha so'zlarga bo'ladi (tirnoq va `\` ni o'zi talqin qiladi), so'zlarni buyruq oxiriga argument qilib qo'shadi va buyruqni ishga tushiradi. Argumentlar juda ko'p bo'lsa bir necha chaqiruvga bo'ladi.

- Nomida bo'shliq bor fayl ikki argumentga aylanadi. Yechim: `find -print0` nomlarni nol bayt (`\0`) bilan ajratadi, `xargs -0` faqat nol bayt bo'yicha bo'ladi. Nol bayt fayl nomida bo'la olmaydigan yagona belgi (yana `/`), shuning uchun bu juftlik har qanday nom bilan xavfsiz.
- `-n N` har chaqiruvga N ta argument, `-I {}` har kirish qatorini `{}` o'rniga qo'yadi (har qatorga bitta chaqiruv), `-P N` bir vaqtda N ta jarayon.
- Kirish bo'sh bo'lsa ham GNU `xargs` buyruqni bir marta, argumentsiz ishga tushiradi. `-r` buni o'chiradi.
- Buyruq berilmasa `echo` ishlatiladi. Xavfli buyruqdan oldin `xargs echo rm` bilan nima bajarilishini ko'ring.

### Misol

```
$ printf 'a b\nc\n' | xargs echo
a b c
$ printf 'a b\nc\n' | xargs -n 1 echo
a
b
c
$ printf 'a b\nc\n' | xargs -I {} echo "[{}]"
[a b]
[c]
```

Kirish ikki qator: `a b` va `c`. Birinchi buyruqda xargs uchta so'z ko'rdi va bitta `echo a b c` ishga tushirdi. `-n 1` bilan uch marta, har so'zga bittadan: `a b` qatori ikkiga bo'linib ketgani shu yerda ko'rinadi. `-I {}` bilan bo'linish qator bo'yicha: ikki chaqiruv, `a b` butun qoldi.

### Locale

**Locale** bu til va mintaqa sozlamasi (`LANG` va `LC_*` muhit o'zgaruvchilari, 5-dars): saralash tartibi, harf sinflari (`[[:alpha:]]` nimani o'z ichiga oladi) va sonlar formati unga bog'liq. Oqibati: bir xil pipeline ikki serverda har xil natija berishi mumkin (`sort` tartibi, `awk` `printf` da nuqta o'rniga vergul). `locale` buyrug'i joriy qiymatlarni ko'rsatadi. Skriptlarda va natijani solishtirganda `LC_ALL=C` bilan bayt tartibiga o'tiladi: `LC_ALL=C sort f`. Bu katta fayllarda `sort` va `grep` ni tezlashtiradi ham. `lab` VM'da standart locale odatda `C.UTF-8` (`locale` bilan tekshiring), shuning uchun darsdagi natijalar bayt tartibida. Sizda boshqa qiymat chiqsa yoki buyruqni Zorin host'ida sinasangiz, teng sonli qatorlarning o'zaro tartibi farq qilishi mumkin; `LC_ALL=C` bilan darsdagi natija chiqadi.

### Real ishda qachon kerak

- `find` natijasiga buyruq qo'llash (3-darsdagi `-exec` ning tezroq va parallel muqobili).
- Ro'yxat bo'yicha takrorlash: `cat hosts.txt | xargs -I {} ssh {} uptime`.
- `docker ps -aq | xargs -r docker rm`: `-r` ro'yxat bo'sh bo'lganda xatoni oldini oladi.

### Nima uchun shunday

Stdin va argumentlar jarayonga ma'lumot berishning ikki alohida kanali (5-dars), `xargs` ular orasidagi ko'prik. Standart bo'linishning bo'shliq bo'yichaligi tarixiy: 1970-yillarda fayl nomida bo'shliq deyarli uchramagan. `-0` keyin qo'shilgan to'g'ri yechim. Muqobillari: `find -exec ... {} +` (xargs'siz, nomlar bilan xavfsiz) va shell sikli `while IFS= read -r line` (sekinroq, lekin murakkab mantiq uchun).

## 8. Logni tahlil qilish

### Format

nginx "combined" formati web serverlar uchun amaldagi standart, vazifalardagi fayl shu formatda:

```
93.180.71.3 - - [17/May/2015:08:05:32 +0000] "GET /downloads/product_1 HTTP/1.1" 304 0 "-" "Debian APT-HTTP/1.3 (0.8.16~exp12ubuntu10.21)"
```

`awk` ning standart (bo'shliq bo'yicha) bo'linishida:

| Maydon | Mazmuni |
|--------|---------|
| `$1` | mijoz IP manzili |
| `$2`, `$3` | identd va foydalanuvchi nomi, deyarli har doim `-` |
| `$4`, `$5` | vaqt (`[17/May/2015:08:05:32`) va vaqt zonasi (`+0000]`) |
| `$6` | metod, tirnoq bilan (`"GET`) |
| `$7` | yo'l |
| `$8` | protokol, tirnoq bilan (`HTTP/1.1"`) |
| `$9` | status kodi |
| `$10` | javob hajmi, bayt |
| `$11` | referer (so'rov qaysi sahifadan kelgani) |
| `$12` va keyingilari | user agent (ichida bo'shliq bor, maydonlarga sochilib ketadi) |

### Mexanizm: ikki xil bo'linish

Format aralash: ba'zi maydonlar bo'shliq bilan, ba'zilari qo'shtirnoq ichida. Bo'shliq bo'yicha bo'linish `$1`–`$11` uchun ishonchli, user agent uchun yo'q. Tirnoq ichidagi maydonlar uchun ajratuvchini `"` qilish qulay: `awk -F'"' '{print $6}'`. Bunda `$1` birinchi tirnoqqacha bo'lgan hamma narsa, `$2` so'rov qatori (`GET /downloads/product_1 HTTP/1.1`), `$3` status va hajm, `$4` referer, `$6` user agent.

### Ish tartibi

1. Avval qarang: `head -n 3`, `wc -l`, `ls -lh`. Format va hajmni biling.
2. Maydonni tekshiring: `awk '{print $9}' f | sort | uniq -c`. Kutilmagan qiymat chiqsa bo'linish noto'g'ri.
3. Filtrni iloji boricha erta qo'ying: oldin `grep` yoki `awk` sharti, keyin `sort`.
4. Natijani boshqa yo'l bilan tekshiring: jami son `wc -l` bilan, guruhlar yig'indisi jami bilan mos kelishi kerak.

### Real ishda qachon kerak

Bu tartib faqat nginx uchun emas: har qanday matnli log (`/var/log/auth.log`, ilova logi, `journalctl` chiqishi) uchun bir xil. JSON formatidagi loglar uchun bu vositalar o'rniga `jq` ishlatiladi; u keyingi modullarda (`kubectl -o json`, cloud CLI) uchraydi.

### Nima uchun shunday

"combined" formati 1990-yillardagi NCSA va Apache serverlaridan meros: odam o'qishi uchun qulay, mashina uchun esa noqulay (tirnoq, qavs va bo'shliq aralash). Shuning uchun zamonaviy tizimlar logni JSON qilib yozadi va markaziy tizimga yig'adi (observability moduli). Lekin eski format hali hamma joyda bor, va bitta serverda tez javob kerak bo'lganda shu darsdagi vositalar yetarli.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Filtr | stdin'dan matn o'qib, stdout'ga o'zgartirilgan matn yozadigan dastur |
| Pipeline | pipe bilan ulangan, bir vaqtda ishlaydigan buyruqlar zanjiri |
| SIGPIPE | o'quvchisi yopilgan pipe'ga yozgan jarayonga kernel yuboradigan signal |
| Regex | matn shablonini tasvirlaydigan mini-til |
| BRE, ERE | POSIX regex'ning asosiy va kengaytirilgan dialektlari (`grep` va `grep -E`) |
| PCRE | Perl uslubidagi regex, JS'ga yaqin; GNU `grep -P` |
| Belgi sinfi | `[[:space:]]`, `[[:alnum:]]` kabi, to'plam ichida yoziladigan nomli belgilar guruhi |
| Maydon (field) | qatorning ajratuvchi bilan bo'lingan bo'lagi |
| Manzil (sed) | buyruq qaysi qatorlarga qo'llanishini belgilaydigan raqam, oraliq yoki regex |
| Pattern space | sed joriy qatorni ushlab turadigan bufer |
| Assotsiativ massiv | kaliti istalgan satr bo'lgan awk massivi |
| Log rotatsiyasi | eski log faylini boshqa nomga o'tkazib, yangisini boshlash |
| Locale | saralash tartibi, harf sinflari va son formatini belgilaydigan til va mintaqa sozlamasi |
| mawk, gawk | awk tilining ikki amalga oshirilishi: Ubuntu'dagi standart va GNU varianti |

## Tuzoqlar

- `grep 404`, `grep error` kabi aniqlanmagan pattern bilan sanash. Natija ortiqcha chiqadi va shu son hisobotga tushadi. Maydon bo'yicha tekshiring: `awk '$9 == 404'`.
- JS odatlari: `grep -E '\d+'` ishlamaydi (`[0-9]+`), `-E` siz `+`, `?`, `|` oddiy belgi, lazy `.*?` yo'q.
- `sort` siz `uniq`. Xato bermaydi, shunchaki noto'g'ri son chiqaradi.
- Sonlarni `-n` siz saralash: `100` `20` dan oldin turadi.
- `sed -i` ni sinovsiz, nusxasiz ishlatish; symlink'li konfiguratsiyada linkni uzib qo'yish.
- macOS'da yozilgan `sed -i ''` Linux'da, Linux'da yozilgan `sed -i` macOS'da buziladi. Ikkalasida ishlaydigan shakl: `sed -i.bak`.
- `cut -d' '` ni tekislangan chiqishga qo'llash: ustun raqami qatordan qatorga siljiydi.
- awk dasturini qo'shtirnoqda yozish: `"{print $1}"` da `$1` ni shell ochadi.
- `find | xargs rm` nomida bo'shliq bor fayllar bilan: noto'g'ri fayl o'chadi. `-print0 | xargs -0` yoki `find -delete`.
- `tail -f` bilan kuzatilayotgan log rotatsiyadan keyin jim bo'ladi va "xato yo'q" degan noto'g'ri xulosa chiqadi. `tail -F`.
- `cat f | grep x | awk '{print $1}'` kabi ortiqcha bo'g'inlar katta fayllarda sekinlashtiradi: `awk '/x/ {print $1}' f` yetarli. Lekin o'qilishi muhimroq bo'lsa ortiqcha bo'g'in gunoh emas.
- Locale farqi: saralash tartibi va o'nlik ajratuvchi serverdan serverga o'zgaradi. Skriptlarda `LC_ALL=C`.
- Internetdagi awk misoli `gensub` yoki `asort` ishlatsa, u gawk uchun yozilgan: Ubuntu'dagi `mawk` da "function never defined" turidagi xato beradi.

## Manbalar

- https://www.gnu.org/software/grep/manual/grep.html – GNU grep, regex bo'limi bilan
- https://www.gnu.org/software/sed/manual/sed.html – GNU sed
- https://www.gnu.org/software/gawk/manual/gawk.html – "GAWK: Effective AWK Programming" (POSIX awk va gawk kengaytmalari ajratib ko'rsatilgan)
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html – POSIX awk spetsifikatsiyasi
- https://www.gnu.org/software/coreutils/manual/coreutils.html – `sort`, `uniq`, `cut`, `tr`, `wc`, `head`, `tail`
- https://www.gnu.org/software/findutils/manual/html_mono/find.html#Invoking-xargs – `xargs`
- https://man7.org/linux/man-pages/man7/regex.7.html – `regex(7)`, POSIX BRE va ERE
- https://man7.org/linux/man-pages/man7/locale.7.html – `locale(7)`, `LC_*` kategoriyalari
- https://man7.org/linux/man-pages/man7/pipe.7.html – `pipe(7)`, pipe buferi va `SIGPIPE`
- https://nginx.org/en/docs/http/ngx_http_log_module.html – nginx log formati (`combined`)
- https://github.com/elastic/examples/tree/master/Common%20Data%20Formats/nginx_logs – darsdagi namuna log
- Kernighan, Pike, "The Unix Programming Environment" – 4 bob (Filters)
- Aho, Kernighan, Weinberger, "The AWK Programming Language" (2-nashr)

## Birga bajaramiz

Boshqa turdagi logni boshidan oxirigacha tahlil qilamiz: SSH serverining kirish urinishlari. Savol: "kim parol tanlab kirishga urinyapti, qaysi foydalanuvchi nomlari bilan va qachon?". Haqiqiy serverda bu yozuvlar `/var/log/auth.log` da yoki `journalctl -u ssh` da bo'ladi (8-dars); natija aniq bo'lishi uchun bu yerda kichik namuna yaratamiz. Hammasi VM ichida, `~/lab-data` da.

1. Namunani yarating va qarang:

```
$ cat > auth.log <<'EOF'
May 17 08:01:02 lab sshd[811]: Failed password for root from 203.0.113.5 port 40112 ssh2
May 17 08:01:05 lab sshd[811]: Failed password for root from 203.0.113.5 port 40113 ssh2
May 17 08:02:10 lab sshd[815]: Accepted publickey for ubuntu from 192.0.2.10 port 51000 ssh2
May 17 08:03:44 lab sshd[820]: Failed password for invalid user admin from 198.51.100.7 port 33001 ssh2
May 17 08:03:50 lab sshd[820]: Failed password for root from 203.0.113.5 port 40120 ssh2
May 17 08:04:01 lab sshd[822]: Failed password for invalid user test from 198.51.100.7 port 33002 ssh2
May 17 09:15:30 lab sshd[901]: Accepted publickey for ubuntu from 192.0.2.10 port 51022 ssh2
May 17 09:16:00 lab sshd[905]: Failed password for root from 203.0.113.50 port 41000 ssh2
EOF
$ wc -l < auth.log
8
```

Har qator: sana, vaqt, hostname, dastur va PID, keyin xabar. Ikki turdagi xabar bor: `Failed password` (muvaffaqiyatsiz urinish) va `Accepted publickey` (kalit bilan kirish, 10-dars).

2. Turlar bo'yicha sanang va jami bilan solishtiring:

```
$ grep -c 'Failed password' auth.log
6
$ grep -c 'Accepted' auth.log
2
```

6 + 2 = 8, `wc -l` bilan mos: hech bir qator hisobdan tushib qolmadi. Bu yerda pattern aniq (uzun so'z birikmasi), shuning uchun `grep -c` ga ishonsa bo'ladi.

3. IP qaysi maydonda? Avval maydonlar sonini tekshiring:

```
$ awk '/Failed password/ {print NF}' auth.log | sort -n | uniq -c
      4 14
      2 16
```

`/Failed password/` pattern, faqat shu qatorlar uchun `NF` chiqdi. To'rt qatorda 14 maydon, ikkitasida 16: `invalid user admin` yozuvi ikki ortiqcha so'z qo'shadi. Demak IP ba'zan `$11`, ba'zan `$13`, qat'iy raqam bilan olish xato beradi. Lekin oxiridan sanasa har doim bir joyda: `... from IP port N ssh2`, ya'ni oxiridan to'rtinchi maydon, `$(NF-3)`.

4. Urinishlar IP bo'yicha:

```
$ awk '/Failed password/ {print $(NF-3)}' auth.log | sort | uniq -c | sort -rn
      3 203.0.113.5
      2 198.51.100.7
      1 203.0.113.50
```

Filtr va maydon ajratish bitta awk'da, keyin 4-bo'limdagi idioma. 3 + 2 + 1 = 6, 2-qadamdagi son bilan mos.

5. Bitta IP'ni qidirishdagi tuzoq:

```
$ grep -c '203.0.113.5' auth.log
4
$ grep -cFw '203.0.113.5' auth.log
3
```

Birinchi natija 4, chunki `203.0.113.50` ham shu pattern'ga mos (qism mosligi). `-F` va `-w` bilan 3, 4-qadamdagi jadval bilan bir xil.

6. Soatlar bo'yicha:

```
$ grep 'Failed password' auth.log | cut -d' ' -f3 | cut -d: -f1 | sort | uniq -c
      5 08
      1 09
```

Birinchi `cut` bo'shliq bo'yicha 3-maydonni (vaqt), ikkinchisi `:` bo'yicha soatni oldi. Bu yerda `cut -d' '` ishladi, chunki maydonlar orasida bittadan bo'shliq. Haqiqiy syslog'da 1–9 kunlar ikki bo'shliq bilan yoziladi (`May  7`), u yerda bu buyruq siljiydi va `awk '{print $3}'` kerak bo'ladi.

7. Qaysi foydalanuvchi nomlari sinab ko'rilgan:

```
$ grep 'Failed password' auth.log | sed -E 's/.* for (invalid user )?([^ ]+) from .*/\2/' | sort | uniq -c | sort -rn
      4 root
      1 test
      1 admin
```

Regex butun qatorga mos keladi va uni ikkinchi guruh bilan almashtiradi: ` for ` dan keyin ixtiyoriy `invalid user ` (birinchi guruh, `?` bilan), keyin bo'shliqsiz so'z (ikkinchi guruh, `[^ ]+`), keyin ` from `. Natijada qatordan faqat foydalanuvchi nomi qoladi.

8. Topilgan IP'lar ustida buyruq, avval "quruq" rejimda:

```
$ awk '/Failed password/ {print $(NF-3)}' auth.log | sort -u | xargs -n 1 echo would-block
would-block 198.51.100.7
would-block 203.0.113.5
would-block 203.0.113.50
```

`sort -u` noyob IP'larni berdi, `xargs -n 1` har biri uchun alohida buyruq ishga tushirdi. `echo would-block` o'rnida haqiqiy ishda firewall buyrug'i turardi (network modulida); `echo` bilan avval nima bajarilishini ko'rish odati shu yerda. Oxirida `rm auth.log`.

Shu 8 qadamda ko'rganingiz: avval qarash va sanash (2-bo'lim), aniq pattern va qism mosligi tuzog'i (3-bo'lim), `cut` va `sort | uniq -c | sort -rn` idiomasi (4-bo'lim), `sed -E` guruhlari (5-bo'lim), awk pattern'i, `NF` va oxiridan maydon olish (6-bo'lim), `xargs` va quruq sinov (7-bo'lim), har natijani jami bilan solishtirish (8-bo'lim, "Ish tartibi").

---

## Vazifalar

Ish papkasi: `linux/07-text/` (`make new m=linux n=07 name=text` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (uzun chiqishni `head` bilan qisqartiring) va o'z so'zingiz bilan izoh. Barcha buyruqlar `lab` VM ichida, bash'da bajariladi (`multipass shell lab`, ish joyi `~/lab-data`); natijani README'ga qo'lda ko'chiring yoki `multipass exec lab -- <buyruq>` orqali host'da oling. `sudo` ishlatilmaydi. Skript (`task_22.sh`) host'dagi ish papkasida yoziladi, VM'ga `multipass transfer` bilan yuboriladi, uning chiqishi (`report.txt`) qaytarib olinadi va ikkalasi ish papkasida saqlanadi (Laboratoriya bo'limi). Log fayli VM'dagi `~/lab-data/nginx_logs` da qoladi, repo'ga qo'shilmaydi. Buyruqlarni host'da ham sinab ko'rish ixtiyoriy: farqlar Laboratoriya jadvalida, README'ga esa VM natijasi yoziladi.

### A. Ko'rish va oqim

1. **First look.** `nginx_logs` uchun: hajm, qatorlar soni, birinchi va oxirgi 3 qator. Birinchi qatorni maydonlarga ajratib, har birining ma'nosini yozing. `awk '{print NF}' nginx_logs | sort -n | uniq -c` nimani ko'rsatadi va maydonlar soni nima uchun hamma qatorda bir xil emas? Log qaysi sanadan qaysi sanagacha? Yo'nalish: 8-bo'lim, "Format" va "Ish tartibi".

2. **tail -f and rotation.** Bir terminalda `while true; do date >> app.log; sleep 1; done` ni ishga tushiring. Ikkinchisida `tail -f app.log`, uchinchisida `tail -F app.log`. Keyin `mv app.log app.log.1` qiling (sikl yangi `app.log` yaratadi). Ikki `tail` qanday tutdi va nima uchun? Siklni `Ctrl+C` bilan to'xtating va fayllarni o'chiring. Yo'nalish: 2-bo'lim, "Mexanizm: tail -f va file descriptor".

3. **SIGPIPE.** `yes | head -3` ni bajaring: `yes` cheksiz yozadi, pipeline nima uchun tugadi? `echo "${PIPESTATUS[@]}"` qiymatlarini 5-darsdagi exit code jadvali bilan izohlang. `time (sort nginx_logs | head -1)` va `time (head -1 nginx_logs)` farqini tushuntiring: qaysi buyruq butun faylni o'qishga majbur? Yo'nalish: 1-bo'lim, "Mexanizm" va "Misol".

### B. grep

4. **Counting 404.** 404 javoblar sonini uch usulda hisoblang: `grep -c 404`, tirnoq va bo'shliqlar bilan aniqlashtirilgan pattern, va `awk '$9 == 404'`. Sonlar farq qiladimi? Farqni keltirib chiqargan qator(lar)ni toping (ishora: `grep 404 | grep -v ...`). Qaysi usulga ishonasiz va nima uchun? Yo'nalish: 3-bo'lim, "Tuzoq: nuqta va qism mosligi"; 6-bo'lim, "Misol".

5. **Context and recursion.** `grep -rn 'PermitRootLogin' /etc/ssh` va `grep -rl 'Port' /etc/ssh` ni bajaring (ruxsat xatolarini `2>/dev/null` bilan yashiring). `/etc/ssh/sshd_config` da `Port` so'zi bor qatorlarni atrofidagi 2 qator bilan chiqaring. Kommentga olinmagan (faol) sozlamalarni chiqaradigan `grep` yozing: komment va bo'sh qatorlarsiz. Yo'nalish: 3-bo'lim, "Bu nima" (flag'lar jadvali).

6. **Regex.** `grep -E` bilan: (a) IP manzili `80.` bilan boshlanadigan qatorlar soni (`180.` emas), (b) status kodi 4xx bo'lgan, lekin 404 bo'lmagan qatorlar, (c) `-o` bilan faqat sana qismini (`17/May/2015`) ajratib, kunlar bo'yicha so'rovlar soni, (d) yo'li `product_1` yoki `product_2` bilan tugaydigan so'rovlar. `grep -c '93.180.71.3'` va `grep -cF '93.180.71.3'` har doim bir xil natija beradimi, nima uchun? `grep '[0-9]+'` va `grep -E '[0-9]+'` farqini ko'rsating. Yo'nalish: 3-bo'lim, "Regex dialektlari" va "Misol".

7. **grep in scripts.** `grep -q` va exit code'dan foydalanib bir qatorli tekshiruvlar yozing: `/etc/passwd` da `ubuntu` (yoki o'z foydalanuvchingiz) bormi; logda 5xx javob bormi. Har biri "yes" yoki "no" chiqarsin. `grep -c` ning exit code'i 0 ta topilganda nima va bu `set -e` li skriptda qanday muammo tug'diradi? Yo'nalish: 3-bo'lim, "Bu nima" (exit code) va "Mexanizm".

### C. cut, sort, uniq, tr

8. **passwd fields.** `/etc/passwd` dan faqat foydalanuvchi nomi va shell'ni chiqaring. Qaysi shell nechta foydalanuvchida ishlatilganini, ko'pidan kamiga, hisoblang. UID bo'yicha sonli saralab, eng katta 5 ta UID'li foydalanuvchini ko'rsating. `-n` siz saralasangiz natija qanday buziladi? Yo'nalish: 4-bo'lim, "cut va tr" va "sort va uniq".

9. **uniq needs sort.** `awk '{print $9}' nginx_logs | uniq -c | head` va `... | sort | uniq -c` natijalarini solishtiring. Birinchisi nima uchun "noto'g'ri", lekin xato bermaydi? Birinchisining chiqishi aslida qanday savolga javob beradi? Noyob IP manzillar sonini ikki usulda toping (`sort -u` va `sort | uniq`). Yo'nalish: 4-bo'lim, "sort va uniq".

10. **Sort keys.** (a) `du -sh /var/log/* 2>/dev/null` ni hajm bo'yicha kattadan kichikka saralang; `-h` o'rniga `-n` ishlatilsa nima bo'ladi? (b) `printf '1.10\n1.9\n1.2\n'` ni `sort`, `sort -n`, `sort -V` bilan saralab farqni izohlang. (c) Logdan "status, bayt" juftliklarini chiqarib, status bo'yicha o'sish, bayt bo'yicha kamayish tartibida saralang (ikki kalit) va birinchi 10 tasini ko'rsating. `-k2` va `-k2,2` farqi nima? Yo'nalish: 4-bo'lim, "sort va uniq" (kalitlar).

11. **tr and line endings.** `printf 'name,role\r\nali,admin\r\n' > win.csv` yarating. `file win.csv`, `cat -A win.csv` va `cut -d, -f2 win.csv | cat -A` nimani ko'rsatadi? Bu ko'rinmas belgi skriptda qanday xatoga olib keladi (masalan `[[ "$role" == "admin" ]]`)? `tr` bilan tuzating. Yana: birinchi qatorni katta harfga o'tkazing; `echo "a    b   c" | tr -s ' '` nima qiladi; `tr 'a-z' 'A-Z' win.csv` nima uchun ishlamaydi? Yo'nalish: 4-bo'lim, "cut va tr".

12. **cut limits.** `ls -l /etc | cut -d' ' -f5 | head` bilan hajm ustunini olishga urinib ko'ring. Natija nima uchun noto'g'ri? Ikki usulda tuzating: `tr -s` bilan va `awk` bilan. `df -h` chiqishidan faqat mount nuqtasi va foiz ustunlarini, 50% dan yuqori bo'lganlarini chiqaring. Yo'nalish: 4-bo'lim, "cut va tr"; 6-bo'lim, "Mexanizm".

### D. sed

13. **Substitute.** `head -5 nginx_logs` ustida (faylni o'zgartirmasdan): (a) `GET` ni `POST` ga, (b) barcha `/` larni `|` ga (qulay ajratuvchi tanlang), (c) `-E` va guruhlar bilan qatorni `vaqt IP` ko'rinishiga keltiring (masalan `17/May/2015:08:05:32 93.180.71.3`), (d) IP'ning oxirgi oktetini `xxx` bilan niqoblang. `s/a/b/` va `s/a/b/g` farqini `echo aaa | sed ...` bilan ko'rsating. Yo'nalish: 5-bo'lim, "Mexanizm" va "Misol".

14. **Print and delete.** `sed -n` bilan logning 1000–1005 qatorlarini chiqaring; xuddi shuni `head` va `tail` bilan ham qiling. `/etc/ssh/sshd_config` dan komment va bo'sh qatorlarni `sed` bilan olib tashlang va natijani 5-vazifadagi `grep` natijasi bilan `diff <(...) <(...)` orqali solishtiring. `sed '5q' f` nima qiladi va `head -5` dan farqi bormi? Yo'nalish: 5-bo'lim, "Mexanizm" (manzil va `-n`).

15. **In-place safely.** `cp /etc/ssh/sshd_config cfg` va `ln -s cfg cfg.link` qiling. Faqat `#Port 22` qatorini `Port 2222` ga o'zgartiradigan `sed` yozing: avval `-i` siz `diff <(sed ...) cfg` bilan tekshiring, keyin `-i.bak` bilan qo'llang. `ls -li cfg cfg.bak` da inode'lar bilan nima bo'ldi? Endi xuddi shunday buyruqni `cfg.link` ga `-i` bilan qo'llang va `ls -l` ni ko'ring: link nima bo'ldi? `--follow-symlinks` bilan takrorlang. Yo'nalish: 5-bo'lim, "sed -i".

### E. awk

16. **Fields and filters.** (a) status 400 va undan yuqori bo'lgan so'rovlarning IP, status va yo'lini chiqaring (birinchi 10 ta), (b) javob hajmi 1 MB dan katta bo'lgan so'rovlar sonini toping, (c) faqat 100–105 qatorlarni qator raqami bilan chiqaring, (d) har qatorning oxirgi maydonini chiqaring. `awk '{print $1 $9}'` va `awk '{print $1, $9}'` farqi nima? `awk "{print $1}" nginx_logs | head -2` nima uchun butun qatorni chiqaradi? Yo'nalish: 6-bo'lim, "Mexanizm" va "Misol".

17. **Aggregation.** Jami yuborilgan baytlarni toping va `printf` bilan GB da, ikki xona aniqlikda chiqaring. O'rtacha javob hajmini faqat status 200 uchun hisoblang. Eng katta javob hajmini va uning qatorini toping. Agar natijada nuqta o'rniga vergul chiqsa (yoki aksincha), sababini toping va `LC_ALL=C` bilan solishtiring. Yo'nalish: 6-bo'lim, "Misol"; 7-bo'lim, "Locale".

18. **Group by.** Assotsiativ massiv bilan: (a) har status kodi bo'yicha so'rovlar soni, (b) eng ko'p so'rov yuborgan 10 ta IP, (c) har status kodi bo'yicha jami baytlar. (a) va (b) natijasini `sort | uniq -c` usuli bilan olingan natija bilan solishtirib bir xilligini ko'rsating. (a) dagi sonlar yig'indisi `wc -l` ga tengmi? Yo'nalish: 6-bo'lim, "Misol" (assotsiativ massiv).

19. **Custom separator.** `-F'"'` bilan eng ko'p uchraydigan 5 ta user agent'ni toping. Standart bo'linish bilan (`$12`) xuddi shu savolga nima uchun to'g'ri javob olib bo'lmaydi? `awk -F:` bilan `/etc/passwd` dan UID'i 1000 va undan yuqori, shell'i `nologin` yoki `false` bilan tugamaydigan foydalanuvchilarni chiqaring. `awk -v` orqali chegara UID'ni shell o'zgaruvchisidan uzating. Yo'nalish: 8-bo'lim, "Mexanizm: ikki xil bo'linish"; 6-bo'lim, "Mexanizm" (`-F`, `-v`).

### F. xargs

20. **xargs and spaces.** Papkada `a.log`, `b.log`, `my app.log` yarating (har biriga bir necha qator yozing). `find . -name '*.log' | xargs wc -l` xatosini yozing: `xargs` `wc` ga qanday argumentlar berdi (`xargs echo` yoki `xargs -n 1 echo` bilan ko'rsating)? `-print0` va `-0` bilan tuzating. `-n 1` va `-I {}` bilan har fayl uchun alohida `echo "file: ..."` chiqaring. `find . -name '*.nope' | xargs wc -l` nima qiladi (ishga tushirmang: avval `xargs echo wc -l` bilan ko'ring) va `-r` nimani o'zgartiradi? Yo'nalish: 7-bo'lim, "Mexanizm" va "Misol".

21. **Parallel xargs.** Logni 20 bo'lakka bo'ling: `split -n l/20 -d ~/lab-data/nginx_logs part-`. Bo'laklarni `gzip` bilan ketma-ket (`xargs -n 1`) va parallel (`xargs -n 1 -P 4`) siqing, har birini `time` bilan o'lchang (ikkinchi o'lchovdan oldin `gunzip part-*.gz`). `nproc` qiymati bilan bog'lab natijani izohlang. Keyin `zcat part-*.gz | wc -l` asl fayl bilan mos kelishini tekshiring va bo'laklarni o'chiring. Yo'nalish: 7-bo'lim, "Mexanizm" (`-n`, `-P`).

### G. Yakuniy

22. **Log report.** `task_22.sh <logfile>` yozing. U quyidagi hisobotni sarlavhalar bilan chiqaradi: jami so'rovlar; noyob IP'lar soni; eng faol 5 ta IP (son bilan); status kodlari taqsimoti (son va foiz); eng ko'p so'ralgan 5 ta yo'l; eng ko'p 404 bergan 5 ta yo'l; kunlar bo'yicha so'rovlar soni (xronologik tartibda, alifbo tartibida emas); eng yuklangan 3 ta soat (`sana:soat` ko'rinishida); jami trafik GB da; eng ko'p uchraydigan 3 ta user agent. Talablar: `#!/usr/bin/env bash`, `set -euo pipefail`, `LC_ALL=C`, argument tekshiruvi (yo'q yoki o'qib bo'lmaydigan fayl uchun usage va `exit 2`), fayl nomi bo'shliqli bo'lsa ham ishlashi, shellcheck toza. `./task_22.sh ~/lab-data/nginx_logs > report.txt` natijasini saqlang. README'da ikkita ko'rsatkichni mustaqil usul bilan qayta hisoblab tekshiring va hisobotdan chiqadigan uchta kuzatuvni yozing (masalan trafikning asosiy manbai kim, 404 ulushi nimani anglatishi mumkin). Yo'nalish: butun dars; 8-bo'lim, "Ish tartibi"; Laboratoriya (`multipass transfer`).

### Topshirish

Tayyor bo'lgach:
1. `linux/07-text/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida, har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor.
2. Ish papkasida `task_22.sh` va `report.txt` bor (boshqa fayl kerak emas), shellcheck hech narsa chiqarmaydi.
3. `nginx_logs` va boshqa katta fayllar repo'da yo'q (`git status` bilan tekshiring).
4. `make check` toza o'tadi (host'da).
5. VM'dagi `~/lab-data` va vaqtinchalik fayllar o'chirilgan; `multipass list` da `lab` `Running` yoki `Stopped` holatda (o'chirilmagan). Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Pipeline'dagi buyruqlar ketma-ket ishlaydimi yoki bir vaqtdami? `... | head -1` nima uchun tez tugaydi?
- `uniq` oldidan nima uchun `sort` kerak? `sort | uniq -c | sort -rn | head` har bo'g'ini nima qiladi?
- BRE va ERE farqi nima? `grep 10.0.0.1` nima uchun ortiqcha qatorlarni topadi? JS'dagi `\d+` ni `grep -E` uchun qanday yozasiz va nima uchun?
- `grep -c` nimani sanaydi va nima uchun `grep -c 404` status kodlari soni emas?
- Qachon `cut`, qachon `awk` ishlatasiz?
- `sed -i` fayl bilan aslida nima qiladi va undan oldin qanday ehtiyot choralari ko'rasiz? macOS'dagi `sed -i` nimasi bilan farq qiladi?
- awk'da `NR`, `NF`, `$0`, `$NF` nima? Guruhlab sanash qanday yoziladi?
- awk dasturi nima uchun bittalik tirnoqda yoziladi va shell o'zgaruvchisi unga qanday uzatiladi? `mawk` va `gawk` farqi qachon seziladi?
- `find | xargs` qachon buziladi va qanday tuzatiladi? `xargs -P` nima beradi?
- `tail -f` va `tail -F` farqi nima?
- Locale matn qayta ishlash natijasiga qanday ta'sir qilishi mumkin?
