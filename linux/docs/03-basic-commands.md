# 3-dars: Asosiy buyruqlar

Maqsad: fayl tizimida yurish va fayllar bilan ishlashning asosiy buyruqlarini (`pwd`, `cd`, `ls`, `mkdir`, `touch`, `cp`, `mv`, `rm`, `cat`, `less`, `find`), globbing va buyruqlar tarixini mexanizm darajasida tushunish. Dars "qanday yoziladi" haqida emas, "aslida nima sodir bo'ladi" haqida: pattern'ni buyruq emas shell ochishi, `cp` ning natijasi manzil mavjudligiga bog'liqligi, `mv` ning bir fayl tizimi ichida va tashqarisidagi farqi, `rm` ning qaytarib bo'lmasligi, `find` ifodasining chapdan o'ngga hisoblanishi. Serverda grafik fayl menejeri yo'q, shuning uchun deploy, backup, log tozalash va tashxisning hammasi shu buyruqlar bilan qilinadi. 5-dars (shell), 6-dars (ruxsatlar, linklar) va 7-dars (matn qayta ishlash) shu asosga quriladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–4 bo'limlar va A, B guruh vazifalari, ikkinchi kun 5–7 bo'limlar va C, D, E guruhlari, uchinchi kun 8-bo'lim, "Birga bajaramiz", F guruh, 22-vazifa va README'ni tartibga solish. E'tiborni quyidagilarga qarating: globbing va brace expansion farqi, tirnoqsiz pattern tuzoqlari, `cp -r` va `cp -a`, manzil mavjudligining ta'siri, uchta vaqt (mtime, ctime, atime), `find` ifodalarining bajarilish tartibi va `-delete` joylashuvi, `-exec ... \;` va `-exec ... +` farqi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi sana, inode raqami va PID farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan. O'chiradigan har qanday buyruqdan oldin uning nimaga ochilishini `echo` yoki `-print` bilan ko'ring: bu darsning asosiy odati shu.

## Laboratoriya

Hamma narsa `SETUP.md` bo'yicha yaratilgan `lab` VM (Multipass, Ubuntu 24.04) ichida bajariladi. Kirish va chiqish 1-darsdagi kabi:

```
multipass start lab        # start the VM if it is stopped
multipass shell lab        # enter; the prompt becomes ubuntu@lab:~$
exit                       # leave the VM
```

| Joy | Prompt | Bu darsda nima uchun |
|-----|--------|----------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | ish papkasini yaratish (`make new`), `make check`, `git`; 15-vazifadagi zsh taqqoslashi |
| `lab` VM | `ubuntu@lab:~$` | barcha vazifalar: GNU coreutils, GNU `find`, bash |

- **VM**: tajribalar `~/playground` papkasida (`mkdir -p ~/playground`). Yaratish, ko'chirish va o'chirish vazifalari faqat shu papka ichida bajariladi. `/etc`, `/var/log`, `/usr` faqat o'qiladi. Bu darsda `sudo` kerak emas: "Permission denied" chiqsa `sudo` qo'ymang, xatoni README'ga yozing.
- **O'rnatish**: hech narsa o'rnatilmaydi. `ls`, `cp`, `mv`, `rm`, `stat`, `touch` GNU coreutils paketidan, `find` GNU findutils'dan, `less` va `file` alohida paketlardan keladi va Ubuntu 24.04 VM'da tayyor turadi. 5-vazifadagi `tree` ixtiyoriy, uning o'rniga `find app -type d` yetarli.
- **Host'da sinash**: host'da faqat o'qiydigan buyruqlar (`ls`, `find`, `less`) ishlatilishi mumkin, lekin natija VM'dagidan farq qilishi mumkin (jadval pastda). Vazifa javoblari VM'dan olinadi.
- **Javoblar**: host'dagi `linux/03-basic-commands/README.md` ga yoziladi. VM'dagi natijani terminaldan ko'chiring yoki host'da `multipass exec lab -- <buyruq>` bilan oling.
- **Holatni tiklash**: bu dars oldingi darslar holatiga tayanmaydi, toza `lab` VM yetarli. `~/playground` mashinalar orasida ko'chmaydi (har mashinada o'z VM'i), ko'chadigani faqat git'dagi README. Mashinani dars o'rtasida almashtirsangiz, davom etayotgan guruhning fayllarini vazifa matnidagi buyruqlar bilan qayta yarating; har guruh o'z papkasida (`~/playground/a`, `~/playground/b` ...) bo'lgani uchun oldingi guruhlar kerak emas.
- **Tozalash**: dars oxirida VM ichida `rm -r ~/playground`, keyin host'da `multipass stop lab`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host ham Linux va GNU userland, shuning uchun o'qiydigan buyruqlar host'da ham VM'dagi kabi ishlaydi. Host'da hech narsa yaratilmaydi va o'chirilmaydi. Host shell'ini `echo $SHELL` bilan tekshiring: zsh bo'lsa globbing xatti-harakati bashdan farq qiladi (6-bo'lim). |
| macOS (uy) | Host userland BSD, shell zsh. Shu dars buyruqlarida aniq farqlar: `stat` chiqishi bitta qator va format flag'i `-f` (GNU'da `-c`); `touch -d "2 days ago"` ishlamaydi (BSD `touch -d` faqat ISO ko'rinishidagi sanani oladi); `cat -A` yo'q (`cat -vet` bor); `find` da boshlang'ich yo'l majburiy (`find -name x` xato, GNU'da yo'l yozilmasa `.` olinadi); `rm --preserve-root` kabi uzun flag'lar yo'q; `/proc`, `/dev/shm`, `findmnt` yo'q. Standart APFS fayl tizimi registrni farqlamaydi: `a.txt` va `A.txt` bitta fayl, Linux'da ikkita. Shuning uchun hamma vazifa VM'da. |

---

## 1. Yo'llar va navigatsiya

### Yo'l nima

Fayl tizimi bitta daraxt, ildizi `/` (FHS, 1-dars). **Yo'l** (path) bu daraxtdagi faylga yoki papkaga olib boradigan nomlar ketma-ketligi, bo'laklar `/` bilan ajratiladi. Yo'l ikki xil yoziladi:

| Yozuv | Ma'nosi |
|-------|---------|
| `/etc/ssh/sshd_config` | absolut yo'l: `/` dan boshlanadi, qayerda turganingizga bog'liq emas |
| `ssh/sshd_config` | nisbiy yo'l: joriy papkadan hisoblanadi |
| `.` | joriy papka |
| `..` | ota papka |
| `~` | uy papkangiz (`$HOME`), `~ali` bu `ali` foydalanuvchisining uy papkasi |
| `-` | faqat `cd -` da: oldingi papka (`$OLDPWD`) |

`.` va `..` shartli belgi emas, ular har papka ichida mavjud haqiqiy yozuvlar (`ls -a` da ko'rinadi). `~` esa fayl tizimida yo'q: uni shell buyruqni ishga tushirishdan oldin `/home/ubuntu` ga almashtiradi (tilde expansion, 5-darsda batafsil).

### Mexanizm: joriy papka jarayonniki

**Joriy papka** (current working directory, cwd) bu har jarayonning (ishlab turgan dasturning) alohida xususiyati: kernel har jarayon uchun "nisbiy yo'llar qayerdan hisoblansin" degan bitta papkani saqlaydi. `cd` shu qiymatni shell jarayonining o'zida o'zgartiradi (`chdir` system call'i), shuning uchun u tashqi dastur emas, builtin (1-dars): tashqi dastur faqat o'zining cwd'sini o'zgartira olardi, shell'nikini emas. Shell'dan ishga tushgan har buyruq cwd'ni shell'dan meros oladi.

```
ubuntu@lab:~$ cd /usr/share
ubuntu@lab:/usr/share$ pwd
/usr/share
ubuntu@lab:/usr/share$ cd ../lib
ubuntu@lab:/usr/lib$ cd -
/usr/share
ubuntu@lab:/usr/share$ ls -l /proc/$$/cwd
lrwxrwxrwx 1 ubuntu ubuntu 0 <sana> /proc/<PID>/cwd -> /usr/share
```

Qatorma-qator: `cd /usr/share` absolut yo'l bilan o'tish, prompt'dagi yo'l o'zgardi. `pwd` (print working directory) joriy papkani chiqaradi. `cd ../lib` nisbiy yo'l: avval bir pog'ona yuqoriga (`/usr`), keyin `lib` ga. `cd -` oldingi papkaga qaytadi va qayerga o'tganini o'zi chiqaradi (shell oldingi papkani `OLDPWD` o'zgaruvchisida saqlaydi). Oxirgi qatorda `$$` shell'ning o'z PID'i, `/proc/<PID>/cwd` esa kernel shu jarayon uchun saqlayotgan joriy papkaga symlink (boshqa yo'lga ishora qiluvchi fayl, 6-darsda): kernel'ning javobi `pwd` bilan bir xil. Argumentsiz `cd` uy papkasiga qaytaradi.

Shell joriy yo'lni matn sifatida ham eslab qoladi (`$PWD`), shuning uchun symlink orqali kirilgan papkada ikki xil javob bo'lishi mumkin. Ubuntu'da `/lib` aslida `usr/lib` ga symlink:

```
ubuntu@lab:~$ cd /lib
ubuntu@lab:/lib$ pwd
/lib
ubuntu@lab:/lib$ pwd -P
/usr/lib
```

`pwd` siz kirgan yo'lni (mantiqiy), `pwd -P` symlink'lar ochilgan haqiqiy yo'lni (fizik) ko'rsatadi.

### Real ishda qachon kerak

- Skript, cron va systemd unit'larda nisbiy yo'l xavfli: dastur qaysi papkadan ishga tushirilganiga bog'liq bo'lib qoladi. cron vazifasi uy papkasidan, systemd servisi standart holatda `/` dan ishga tushadi, terminalda ishlagan `./data/app.db` u yerda topilmaydi. Bunday joylarda absolut yo'l yoziladi.
- Node'dagi `process.cwd()` aynan shu qiymat, `__dirname` esa fayl joylashuvi. "Lokalda ishlaydi, serverda fayl topilmaydi" xatosining keng tarqalgan sababi shu ikkisini aralashtirish.
- "Bu jarayon qaysi papkada ishlayapti?" savoliga `ls -l /proc/<PID>/cwd` javob beradi (9-darsda).

### Nima uchun shunday

Nisbiy yo'l qisqa yozish va ko'chma loyihalar uchun kerak: repo ichidagi `src/index.ts` qaysi papkaga klon qilinsa ham ishlaydi. Buning narxi: ma'no cwd'ga bog'liq. cwd'ning har jarayonda alohida bo'lishi Unix'ning dastlabki dizaynidan: jarayonlar bir-birining holatini o'zgartira olmaydi, bitta terminalda `cd` qilish boshqasiga ta'sir qilmaydi. Muqobili (butun tizim uchun bitta joriy papka) ko'p foydalanuvchili tizimda ishlamas edi.

## 2. ls: papka mazmuni va fayl metadata'si

### ls nima o'qiydi

Papka aslida jadval: har qatorida fayl nomi va **inode** raqami. Inode bu fayl tizimidagi faylning "pasporti": turi, ruxsatlari, egasi, hajmi, vaqtlari va ma'lumot bloklarining manzili shu yerda, nomi esa yo'q (nom papkada turadi; batafsil 6 va 13-darslarda). Oddiy `ls` faqat papka jadvalini o'qiydi va nomlarni chiqaradi. `ls -l` har nom uchun qo'shimcha ravishda inode'ni so'raydi (`stat` oilasidagi system call), shuning uchun yuz minglab faylli papkada `ls -l` sezilarli sekinroq.

```
ubuntu@lab:~$ ls -l /etc/hostname /usr/bin/awk
-rw-r--r-- 1 root root  4 <sana> /etc/hostname
lrwxrwxrwx 1 root root 21 <sana> /usr/bin/awk -> /etc/alternatives/awk
ubuntu@lab:~$ ls -ld /usr
drwxr-xr-x <N> root root 4096 <sana> /usr
```

| Ustun | Ma'nosi |
|-------|---------|
| `-rw-r--r--` | birinchi belgi tur: `-` oddiy fayl, `d` papka, `l` symlink; qolgan to'qqiztasi ruxsatlar (6-darsda) |
| `1` | hard linklar soni, ya'ni shu inode'ga nechta nom ishora qiladi (6-darsda) |
| `root root` | ega va guruh |
| `4` | hajm, bayt (`-h` bilan `K`, `M`, `G`). `lab` so'zi va qator oxiri belgisi: 4 bayt |
| `<sana>` | oxirgi o'zgartirilgan vaqt (mtime, 3-bo'lim). Yaqin sanalar `Feb 10 12:00`, 6 oydan eskisi `Feb 10  2024` ko'rinishida |
| nom | symlink'da `->` dan keyin u ishora qiladigan yo'l; hajmi (`21`) shu yo'l matnining uzunligi |

Uchinchi buyruqdagi `-d` muhim: papka nomi berilganda `ls` standart holatda uning ichini ko'rsatadi, `-d` bilan papkaning o'zini. Papka ro'yxati boshidagi `total <N>` qatori fayllar egallagan disk bloklari yig'indisi (1K birliklarda), fayllar soni emas.

| Flag | Nima qiladi |
|------|-------------|
| `-a`, `-A` | yashirin fayllarni ham ko'rsatadi; `-A` `.` va `..` siz |
| `-h` | odam o'qiydigan hajm, `-l` bilan birga |
| `-t`, `-S` | vaqt bo'yicha (yangisi birinchi), hajm bo'yicha (kattasi birinchi) |
| `-r` | teskari tartib |
| `-d` | papka ichini emas, o'zini ko'rsatadi |
| `-R` | rekursiv |
| `-i` | inode raqami |
| `-1` | har qatorda bitta nom |

"Yashirin" fayl bu shunchaki nomi nuqta bilan boshlanadigan fayl. Alohida atribut yo'q, `ls` va shell bunday nomlarni standart holatda tashlab ketadi, xolos.

### stat va file

`ls -l` inode'ning bir qismini ko'rsatadi, `stat` hammasini:

```
ubuntu@lab:~$ stat /etc/hostname
  File: /etc/hostname
  Size: 4         	Blocks: 8          IO Block: 4096   regular file
Device: <maj>,<min>	Inode: <N>      Links: 1
Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Access: <sana> <vaqt> <zona>
Modify: <sana> <vaqt> <zona>
Change: <sana> <vaqt> <zona>
 Birth: <sana> <vaqt> <zona>
```

`Size: 4` mazmun hajmi baytda. `Blocks: 8` diskda egallangan joy 512 baytlik birliklarda: 4 baytli fayl ham butun bitta 4096 baytlik blokni band qiladi (8 × 512). `regular file` tur. `Device` fayl qaysi qurilmada (fayl tizimida) turgani, `Inode` uning shu fayl tizimidagi raqami: bu juftlik faylni yagona aniqlaydi. `Links` hard linklar soni. Birinchi `Access` qatori ruxsatlar (`0644` octal va harfli ko'rinish) hamda ega va guruh, raqam va nom bilan. Oxirgi to'rt qator vaqtlar: atime, mtime, ctime (3-bo'lim) va `Birth` (yaratilgan vaqt, ext4'da bor, hamma fayl tizimida emas). Skript uchun bitta maydon `-c` bilan olinadi: `stat -c '%s %n' fayl` hajm va nomni beradi.

`file` buyrug'i fayl turini kengaytmaga emas, mazmunning boshidagi baytlarga qarab aniqlaydi:

```
ubuntu@lab:~$ file /etc/hostname /etc
/etc/hostname: ASCII text
/etc:          directory
```

Linux'da kengaytma faqat odam uchun kelishuv: `.txt` deb nomlangan fayl binary bo'lishi mumkin, kernel kengaytmaga qaramaydi.

Papka uchun `ls -l` dagi hajm (odatda `4096`) papka jadvalining hajmi, ichidagi fayllar yig'indisi emas. Yig'indi uchun `du -sh papka` (8-darsda).

**Tuzoq: `ls` chiqishini skriptda parse qilmang.** Fayl nomida bo'shliq yoki hatto yangi qator bo'lishi mumkin, sana formati locale'ga bog'liq. Skriptda glob (`for f in *.log`) yoki `find` ishlatiladi, bitta maydon kerak bo'lsa `stat -c`.

### Real ishda qachon kerak

- `ls -lt | head` "bu papkada oxirgi nima o'zgardi?" savoliga javob: deploy'dan keyin qaysi fayl yangilangani, qaysi log hozir yozilayotgani.
- `ls -lS | head` papkadagi eng katta fayllar (disk to'lganda birinchi qadam, 8-darsda `du` bilan davom etadi).
- `ls -la` konfiguratsiya qidirganda: `.env`, `.git`, `.ssh` nuqta bilan boshlanadi va oddiy `ls` da ko'rinmaydi.
- `ls -ld papka` ruxsat muammosida: papkaning o'z ruxsati va egasi kerak, ichi emas.

### Nima uchun shunday

Nom va metadata ajratilgani (nom papkada, qolgani inode'da) bitta faylga bir nechta nom berishga va faylni ko'chirmasdan qayta nomlashga imkon beradi (4-bo'limdagi `mv` shunga tayanadi). Nuqtali fayllarning yashirinligi dastlab xato edi: ilk Unix'dagi `ls` `.` va `..` ni ko'rsatmaslik uchun nuqta bilan boshlanadigan hamma nomni tashlab ketgan, foydalanuvchilar esa bundan sozlama fayllarini "ko'zdan yashirish" uchun foydalana boshlagan. Kelishuv shundan qolgan.

## 3. Yaratish: mkdir, touch va fayl vaqtlari

### mkdir

`mkdir` papka yaratadi. Ota papka mavjud bo'lmasa xato beradi, `-p` (parents) esa butun zanjirni yaratadi va papka allaqachon mavjud bo'lsa ham xato bermaydi:

```
ubuntu@lab:~/playground$ mkdir one/two
mkdir: cannot create directory 'one/two': No such file or directory
ubuntu@lab:~/playground$ mkdir -p one/two
ubuntu@lab:~/playground$ mkdir -p one/two
ubuntu@lab:~/playground$ echo $?
0
```

Birinchi buyruqda `one` yo'q, shuning uchun `one/two` ni yaratib bo'lmadi. `-p` bilan ikkalasi yaratildi. Uchinchi buyruq hech narsa qilmadi va exit code `0` qaytardi (exit code 1-darsda). Bunday buyruq **idempotent** deyiladi: bir marta yoki o'n marta bajarilsa ham natija bir xil. Skript va deploy'larda aynan shu xususiyat kerak, chunki skript qayta ishga tushirilganda "papka bor" degan xato bilan to'xtab qolmaydi.

### touch va uchta vaqt

`touch fayl` fayl bo'lmasa bo'sh fayl yaratadi, bo'lsa vaqtlarini hozirgi vaqtga yangilaydi. Asl vazifasi ikkinchisi, nomi ham shundan ("tegib qo'yish"). Har inode'da uchta vaqt saqlanadi:

| Vaqt | Qachon o'zgaradi | `ls` da | `stat -c` |
|------|------------------|---------|-----------|
| mtime (Modify) | mazmun o'zgarganda | `ls -l` (standart) | `%y` |
| ctime (Change) | inode o'zgarganda: ruxsat, ega, nom, linklar soni, mazmun | `ls -lc` | `%z` |
| atime (Access) | mazmun o'qilganda | `ls -lu` | `%x` |

Mazmun o'zgarsa hajm va mtime ham o'zgaradi, bular inode maydonlari, demak ctime ham yangilanadi. Teskarisi to'g'ri emas: faqat metadata o'zgarsa mtime joyida qoladi. Nom o'zgartirish misolida:

```
ubuntu@lab:~/playground$ touch -d "3 days ago" report.txt
ubuntu@lab:~/playground$ stat -c 'm=%y  c=%z' report.txt
m=<3 kun oldingi sana> <vaqt> <zona>  c=<bugungi sana> <vaqt> <zona>
ubuntu@lab:~/playground$ mv report.txt final.txt
ubuntu@lab:~/playground$ stat -c 'm=%y  c=%z' final.txt
m=<3 kun oldingi sana> <vaqt> <zona>  c=<bugungi sana> <yangi vaqt> <zona>
```

`touch -d` mtime'ni (va atime'ni) uch kun orqaga qo'ydi, ctime esa bugungi: vaqtni o'zgartirishning o'zi inode'ni o'zgartirdi. `mv` dan keyin mtime tegilmadi (mazmun o'sha), ctime yana yangilandi.

atime har o'qishda yangilanmaydi. Har `cat` diskka yozuv keltirib chiqarmasligi uchun Linux standart holatda `relatime` rejimida ishlaydi: atime faqat u mtime yoki ctime'dan eski bo'lsa, yoki oxirgi yangilanganiga 24 soatdan oshgan bo'lsa yangilanadi.

ctime "yaratilgan vaqt" (creation time) emas va uni buyruq bilan xohlagan sanaga o'rnatib bo'lmaydi: uni faqat kernel, inode o'zgargan paytda qo'yadi. mtime'ni esa fayl egasi `touch -d` bilan istalgan sanaga qo'ya oladi.

### Real ishda qachon kerak

- `mkdir -p` har deploy skriptida va Dockerfile'da: "papka bo'lsa tegma, bo'lmasa yarat".
- mtime `ls -lt`, `find -mtime`, `make`, `rsync` va backup vositalari uchun "fayl o'zgarganmi?" belgisi. `make` maqsad fayl manbadan eski bo'lsagina qayta quradi, `touch` bilan qayta qurishni majburlash mumkin.
- Hodisa tahlilida ("bu konfiguratsiyani kim, qachon o'zgartirgan?") mtime'ga ishonib bo'lmaydi, chunki u qo'lda o'zgartiriladi. ctime ishonchliroq, lekin u ham faqat oxirgi o'zgarishni ko'rsatadi.
- `touch` bo'sh belgi fayllar uchun: lock fayl, "qayta ishga tushirish kerak" bayrog'i.

### Nima uchun shunday

Uchta vaqt uch xil savolga javob beradi: mazmun qachon o'zgardi (build va backup uchun), metadata qachon o'zgardi (audit va inkremental backup uchun: ruxsati o'zgargan fayl ham qayta saqlanishi kerak), qachon o'qildi (ishlatilmayotgan fayllarni topish uchun). Yaratilgan vaqt klassik Unix'da umuman saqlanmagan, `Birth` maydoni keyinroq qo'shilgan va hamma fayl tizimida yo'q, shuning uchun vositalar unga tayanmaydi. atime'ning to'liq aniqligidan `relatime` foydasiga voz kechilgan, chunki har o'qishni yozuvga aylantirish diskni behuda yuklar edi.

## 4. cp, mv, rm

### cp: nusxa olish

`cp manba manzil` manba faylni ochadi, yangi inode'li yangi fayl yaratadi va baytlarni ko'chiradi. Natijada ikki mustaqil fayl bo'ladi. Standart holatda `cp` mavjud manzil faylning ustidan so'ramasdan yozadi, yangi faylning egasi nusxa olgan foydalanuvchi, vaqti esa hozirgi vaqt bo'ladi.

| Flag | Nima qiladi |
|------|-------------|
| `-r` | papkani ichidagilari bilan rekursiv ko'chiradi |
| `-a` | arxiv rejimi: rekursiv, va ruxsat, ega, vaqtlar, linklar kabi barcha metadata saqlanadi |
| `-i` | ustidan yozishdan oldin so'raydi |
| `-n` | mavjud faylning ustidan yozmaydi |
| `-u` | faqat manba yangiroq bo'lsa yoki manzilda yo'q bo'lsa ko'chiradi |
| `-v` | nima qilayotganini chiqaradi |

```
ubuntu@lab:~/playground$ touch -d "2024-01-15" old.txt
ubuntu@lab:~/playground$ cp old.txt plain.txt
ubuntu@lab:~/playground$ cp -a old.txt arch.txt
ubuntu@lab:~/playground$ ls -l --time-style=long-iso old.txt plain.txt arch.txt
-rw-rw-r-- 1 ubuntu ubuntu 0 2024-01-15 00:00 arch.txt
-rw-rw-r-- 1 ubuntu ubuntu 0 2024-01-15 00:00 old.txt
-rw-rw-r-- 1 ubuntu ubuntu 0 <bugun> <vaqt> plain.txt
```

`--time-style=long-iso` sanani yil bilan to'liq ko'rsatadi. Oddiy `cp` dan chiqqan `plain.txt` bugungi vaqtni oldi, `cp -a` dan chiqqan `arch.txt` manbaning vaqtini saqladi. (Ruxsat ustuni sizda boshqacha bo'lsa, bu `umask` farqi, 6-darsda.) Egani saqlash faqat root uchun ishlaydi: oddiy foydalanuvchi faylni boshqa foydalanuvchiga "sovg'a" qila olmaydi. Backup va deploy uchun `cp -a` (yoki `rsync -a`) ishlatiladi.

**Natija manzil mavjudligiga bog'liq.** `cp -r src dst` da `dst` yo'q bo'lsa, `src` ning nusxasi `dst` nomi bilan yaratiladi. `dst` mavjud papka bo'lsa, `cp` "shu papkaning ichiga" deb tushunadi va natija `dst/src` bo'ladi. Bitta skriptni ikki marta ishlatganda natija har xil chiqishining sababi shu. Papkaning o'zini emas, ichidagilarini ko'chirish uchun `cp -a src/. dst/` yoziladi: `src/.` "src ning ichi" degani va yashirin fayllarni ham oladi.

### mv: ko'chirish va nom o'zgartirish

`mv` uchun ko'chirish va nom o'zgartirish bitta amal: `rename` system call'i. Bir fayl tizimi ichida `mv` ma'lumotga tegmaydi, faqat papka jadvalidagi yozuvni o'zgartiradi (eski nom o'chadi, yangi nom o'sha inode'ga ishora qiladi). Shuning uchun u hajmdan qat'i nazar bir zumda bajariladi va **atomik**: ya'ni yo to'liq bajariladi, yo umuman bajarilmaydi, oraliq holatni hech kim ko'rmaydi.

```
ubuntu@lab:~/playground$ ls -i final.txt
<N> final.txt
ubuntu@lab:~/playground$ mkdir -p archive && mv final.txt archive/final-v1.txt
ubuntu@lab:~/playground$ ls -i archive/final-v1.txt
<N> archive/final-v1.txt
```

Boshqa papka, boshqa nom, lekin inode raqami o'sha: fayl ko'chmadi, faqat nomi ko'chdi. `&&` "chapdagisi muvaffaqiyatli bo'lsa o'ngdagisini bajar" degani (5-darsda).

Manzil boshqa fayl tizimida bo'lsa (boshqa disk, tmpfs, tarmoq diski), `rename` ishlamaydi, chunki inode raqami faqat o'z fayl tizimi ichida ma'noga ega. Bu holda `mv` o'zi nusxa oladi va keyin manbani o'chiradi: sekin, atomik emas, o'rtada uzilsa manzilda yarim fayl qoladi. Qaysi yo'l qaysi fayl tizimida ekanini `findmnt -T <yo'l>` ko'rsatadi.

`mv` ham standart holatda mavjud manzil faylning ustidan so'ramasdan yozadi (`-i` so'raydi, `-n` yozmaydi).

### rm: o'chirish

`rm fayl` papka jadvalidan nomni o'chiradi (`unlink` system call'i). Inode'ga boshqa nom ishora qilmasa va faylni hech bir jarayon ochiq ushlab turmagan bo'lsa, kernel bloklarni bo'sh deb belgilaydi. Terminalda savat yo'q, qaytarish buyrug'i yo'q.

```
ubuntu@lab:~/playground$ mkdir -p junk/sub && touch junk/a.txt junk/sub/b.txt
ubuntu@lab:~/playground$ rm -rv junk
removed 'junk/a.txt'
removed 'junk/sub/b.txt'
removed directory 'junk/sub'
removed directory 'junk'
```

`-r` rekursiv, `-v` har qadamni chiqaradi. Tartibga qarang: avval ichidagilar, oxirida papkaning o'zi, chunki faqat bo'sh papkani o'chirish mumkin. `rmdir papka` faqat bo'sh papkani o'chiradi (xavfsizroq). `-f` mavjud bo'lmagan faylga xato bermaydi va hech qachon so'ramaydi, `-i` har fayl uchun so'raydi. O'chirish huquqi faylning emas, u turgan papkaning ruxsatiga bog'liq, chunki o'zgarayotgan narsa papka jadvali (6-darsda).

**Tuzoq: bo'sh o'zgaruvchi bilan `rm -rf`.** `rm -rf "$DIR/"*` da `DIR` bo'sh bo'lsa buyruq `rm -rf /*` ga aylanadi. GNU `rm` faqat aynan `/` argumentini rad etadi (`--preserve-root`, standart yoqilgan), `/*` ni esa shell oldindan `/bin /boot /etc ...` ga ochib beradi va himoya ishlamaydi. Skriptda `set -u` va `"${DIR:?}"` ishlatiladi (5-darsda).

**Tuzoq: `-` bilan boshlanadigan nom.** Papkada `-rf` nomli fayl bo'lsa, `rm *` uni flag deb o'qiydi. Himoya: `rm -- *` (`--` "flag'lar tugadi" degani) yoki `rm ./*`.

### Real ishda qachon kerak

- Konfiguratsiyani tahrirlashdan oldin: `cp -a nginx.conf nginx.conf.bak`. Buzilsa qaytarish bitta `mv`.
- Atomik almashtirish: yangi fayl vaqtinchalik nom bilan o'sha papkada yoziladi, keyin `mv` bilan joyiga qo'yiladi. O'quvchi dastur yo eski, yo yangi to'liq faylni ko'radi, yarim yozilganini hech qachon. Vaqtinchalik fayl `/tmp` da bo'lsa bu kafolat yo'qolishi mumkin (boshqa fayl tizimi).
- Disk to'lganda katta logni `rm` qildingiz, joy bo'shamadi: servis faylni hali ochiq ushlab turibdi, bloklar u yopilgandagina bo'shaydi (8 va 13-darslarda).

### Nima uchun shunday

Unix asboblari "foydalanuvchi nima qilayotganini biladi" tamoyilida qurilgan: so'ramaydi, tasdiq kutmaydi, shuning uchun ularni skript va pipe ichida ishlatish oson. Narxi: xato ham jim bajariladi. Savat grafik muhitning qatlami, fayl tizimining emas. Serverda himoya boshqa darajada quriladi: backup, snapshot (2-dars), git, va o'chirishdan oldin ko'rish odati. `mv` ning `rename` ga asoslangani esa tasodif emas: nom va inode ajratilgani uchun gigabaytli faylni "ko'chirish" bitta jadval yozuvini o'zgartirishga teng.

## 5. O'qish: cat, less

### cat

`cat fayl` (concatenate, "ulash") berilgan fayllarni ketma-ket o'qib stdout'ga, ya'ni terminalga chiqaradi. Kichik fayllar uchun qulay. `cat -n` qator raqamlarini qo'shadi, `cat -A` ko'rinmas belgilarni ko'rinadigan qiladi: tab `^I`, qator oxiri `$`, Windows'dan kelgan carriage return `^M`.

```
ubuntu@lab:~/playground$ printf 'PORT=8080 \n' > app.env
ubuntu@lab:~/playground$ cat app.env
PORT=8080
ubuntu@lab:~/playground$ cat -A app.env
PORT=8080 $
```

`printf` matnni formatlab chiqaradi, `>` chiqishni faylga yo'naltiradi (5-darsda). Oddiy `cat` da qiymat toza ko'rinadi, `cat -A` esa `8080` va qator oxiri (`$`) orasidagi ortiqcha bo'shliqni ochib beradi. "Konfiguratsiya to'g'ri yozilgan, lekin servis portni tanimayapti" turidagi xatolar ko'pincha shunday ko'rinmas belgi bo'lib chiqadi.

### less

`less` **pager**: matnni ekranma-ekran ko'rsatadigan dastur (`man` ham sahifalarni shu orqali ko'rsatadi, 1-dars). U faylni to'liq xotiraga yuklamaydi, faqat ekranga kerakli qismini o'qiydi, shuning uchun gigabaytli logni ham darhol ochadi. Mazmun terminalning scrollback'ini to'ldirmaydi va faylni tasodifan o'zgartirib bo'lmaydi.

| `less` klavishi | Nima qiladi |
|-----------------|-------------|
| `Space`, `b` | sahifa pastga, yuqoriga |
| `g`, `G` | boshi, oxiri |
| `/so'z`, `?so'z` | oldinga, orqaga qidiruv; `n`, `N` keyingi, oldingi topilma |
| `F` | oxirini kuzatish (`tail -f` kabi), `Ctrl+C` bilan oddiy rejimga qaytish |
| `-N`, `-S` (ichida yozing) | qator raqamlari, uzun qatorlarni kesish (yoqish va o'chirish) |
| `q` | chiqish |

**Tuzoq: binary faylni `cat` qilish.** Binary ichidagi baytlar terminal uchun boshqaruv ketma-ketligi bo'lib chiqishi va terminalni buzishi mumkin (g'alati belgilar, yo'qolgan kursor). Avval `file fayl` bilan turini ko'ring. Terminal buzilsa `reset` buyrug'i tiklaydi.

### Real ishda qachon kerak

- Serverda log o'qish deyarli har doim `less`: oxiriga `G`, xatoni orqaga qarab `?error`, jonli kuzatish `F`.
- `cat` qisqa konfiguratsiyani ko'rish va fayllarni ulash uchun. Uzun faylni `cat` qilish terminal tarixini yuvib ketadi.
- `cat -A` YAML'dagi tab, `.env` dagi ortiqcha bo'shliq, Windows'da tahrirlangan skriptdagi `^M` ni topish uchun.

### Nima uchun shunday

`cat` ataylab sodda: baytlarni o'zgartirmasdan uzatadi, shuning uchun uni boshqa buyruqlar bilan ulash mumkin (pipe, 5 va 7-darslar). Ekranma-ekran ko'rsatish alohida dasturning ishi. Birinchi pager `more` faqat oldinga yura olardi, `less` orqaga qaytishni qo'shgan, nomi ham shu hazildan ("less is more").

## 6. Globbing va brace expansion

### Pattern'ni kim ochadi

**Globbing** (pathname expansion) bu shell'ning `*`, `?`, `[...]` belgilari bor so'zni mos fayl nomlari ro'yxatiga almashtirishi. Buni buyruq emas, **shell** qiladi: `ls *.md` da shell joriy papkani o'qiydi, mos nomlarni topadi va `ls notes.md todo.md` ni ishga tushiradi. `ls` yulduzchani hech qachon ko'rmaydi. Shuning uchun glob har qanday buyruq bilan bir xil ishlaydi va nimaga ochilishini `echo` bilan oldindan ko'rish mumkin.

| Pattern | Mos keladi |
|---------|------------|
| `*` | istalgan belgilar ketma-ketligi (bo'sh ham), `/` va nom boshidagi `.` dan tashqari |
| `?` | aynan bitta belgi |
| `[abc]`, `[a-z]`, `[0-9]` | to'plamdan bitta belgi |
| `[!abc]` | to'plamda bo'lmagan bitta belgi |
| `**` | rekursiv, bash'da faqat `shopt -s globstar` dan keyin |

```
ubuntu@lab:~/playground/demo$ touch notes.md todo.md img1.png img2.png img10.png .secret.md
ubuntu@lab:~/playground/demo$ echo *.md
notes.md todo.md
ubuntu@lab:~/playground/demo$ echo img?.png
img1.png img2.png
ubuntu@lab:~/playground/demo$ echo img[0-9]*.png
img1.png img10.png img2.png
ubuntu@lab:~/playground/demo$ echo *.xyz
*.xyz
```

Qatorma-qator: `*.md` ikkita faylga ochildi, `.secret.md` chiqmadi, chunki `*` nom boshidagi nuqtaga mos kelmaydi. `img?.png` da `?` aynan bitta belgi, shuning uchun `img10.png` yo'q. Uchinchisida natija alifbo tartibida: `img10` `img2` dan oldin, chunki solishtirish belgima-belgi (`1` < `2`), son sifatida emas. Aniq tartib locale (til va saralash sozlamasi, 7-darsda) ga bog'liq; VM'da u `C.UTF-8`, `echo $LANG` bilan ko'ring. To'rtinchisi muhim: hech narsa mos kelmasa bash pattern'ni o'zgarishsiz, harfma-harf qoldiradi va buyruqqa `*.xyz` satrining o'zi boradi. `ls *.xyz` dagi xatoni shuning uchun shell emas, `ls` chiqaradi. zsh'da boshqacha: xatoni shell o'zi beradi (`no matches found`) va buyruq umuman ishga tushmaydi.

- Tirnoq globbing'ni o'chiradi: `'*.md'` va `"*.md"` ochilmaydi, buyruqqa yulduzcha bilan boradi.
- Glob regex emas: globda `*` "istalgan narsa", regex'da "oldingi belgining takrori" (7-darsda).
- `shopt` bash'ning ichki sozlamalarini yoqadi va o'chiradi (`-s` yoqish, `-u` o'chirish): `globstar`, `dotglob` shular jumlasidan.

### Brace expansion

`{a,b,c}` va `{1..5}` glob emas. Bu **brace expansion**: shell fayl tizimiga umuman qaramasdan satrlarni generatsiya qiladi va bu globbing'dan oldin bajariladi.

```
ubuntu@lab:~/playground/demo$ echo file{1..3}.txt
file1.txt file2.txt file3.txt
ubuntu@lab:~/playground/demo$ echo {web,api}-{dev,prod}
web-dev web-prod api-dev api-prod
ubuntu@lab:~/playground/demo$ echo config.yaml{,.bak}
config.yaml config.yaml.bak
```

Bu fayllarning birortasi mavjud emas, baribir chiqdi: glob "bor narsani topadi", brace "yozilganni ko'paytiradi". Ikkinchi misolda ikki qavs barcha kombinatsiyalarni beradi. Uchinchisida birinchi variant bo'sh, shuning uchun `cp config.yaml{,.bak}` aslida `cp config.yaml config.yaml.bak`. `mkdir -p app/{src,test}` kabi yozuvlar shu mexanizm.

**Tuzoq: tirnoqsiz pattern boshqa buyruqqa.** `find . -name *.txt` da shell `*.txt` ni joriy papkadagi fayllarga ochib yuboradi va `find` siz yozmagan argumentlarni oladi. Pattern buyruqning o'ziga yetib borishi kerak bo'lsa (`find -name`, `grep`, `tar --exclude`), tirnoqqa oling: `find . -name '*.txt'`.

### Real ishda qachon kerak

- O'chirish va ko'chirishdan oldin tekshiruv: `echo rm *.tmp` buyruqni bajarmaydi, faqat ochilgan ko'rinishini chiqaradi.
- `*` yashirin fayllarni olmaydi: `mv app/* new/` dan keyin `.env` va `.git` eski joyda qoladi. Deploy skriptlaridagi "konfiguratsiya yo'qoldi" xatosining manbai.
- `package.json` skriptlaridagi `"lint": "eslint src/**/*.ts"` tirnoqsiz bo'lsa, `**` ni `sh` ochadi (globstar'siz u `*` kabi ishlaydi) va chuqur papkalar tushib qoladi. Tirnoq ichida yozilsa pattern eslint'ning o'ziga boradi va u o'zi ochadi. Bu aynan shu bo'limdagi qoida.
- Dockerfile `COPY`, `.gitignore`, CI konfiguratsiyalaridagi pattern'lar ham glob oilasidan, lekin har vosita o'z qoidalariga ega: `.gitignore` dagi `*` bashdagi bilan har doim ham bir xil emas.

### Nima uchun shunday

Unix'da pattern'ni shell ochadi, shunda har dastur o'z pattern kodini yozishi shart emas va hammasi bir xil ishlaydi. Windows'ning `cmd.exe` da aksincha: yulduzcha dasturga boradi va har dastur uni o'zi (yoki umuman) ochadi. Unix yo'lining narxi: buyruq siz nima yozganingizni emas, shell nimaga ochganini ko'radi, tirnoq tuzoqlari shundan. Mos kelmagan pattern'ni o'zgarishsiz qoldirish tarixiy sh xatti-harakati, bash moslik uchun saqlagan; zsh xavfsizroq yo'lni tanlagan.

## 7. find

### Ifoda qanday hisoblanadi

Glob faqat bitta papkada va faqat nom bo'yicha tanlaydi. `find` esa papka daraxtini to'liq aylanib chiqadi va har bir fayl va papka uchun **ifodani** hisoblaydi: ifoda testlar (rost yoki yolg'on qaytaradi) va amallardan (biror ish qiladi) iborat.

```
find <qayerdan> <testlar> <amal>
find /var/log -type f -name '*.log' -size +1M -print
```

Ifoda har fayl uchun **chapdan o'ngga** hisoblanadi, bo'laklar orasida ko'rinmas "va" (`-a`) turadi. Biror test yolg'on chiqsa, o'ngdagilar shu fayl uchun o'tkazib yuboriladi (JS'dagi `a && b && c` kabi qisqa tutashuv). Amallar ham shu zanjirning oddiy bo'lagi: navbati kelganda bajariladi. Yuqoridagi misol: "oddiy faylmi? ha bo'lsa nomi `*.log` mi? ha bo'lsa 1M dan kattami? ha bo'lsa yo'lini chiqar".

| Test | Ma'nosi |
|------|---------|
| `-name 'p'`, `-iname 'p'` | nom glob bo'yicha (faqat oxirgi bo'lak, yo'l emas); `-iname` registrga qaramaydi |
| `-path 'p'` | butun yo'l glob bo'yicha, bunda `*` `/` ga ham mos keladi: `-path '*/.git/*'` |
| `-type f`, `d`, `l` | oddiy fayl, papka, symlink |
| `-size +10M`, `-size -1k` | kattaroq, kichikroq |
| `-mtime -7`, `-mtime +30` | 7 kundan yangi, 30 kundan eski |
| `-mmin -60` | oxirgi 60 daqiqada o'zgargan |
| `-newer fayl` | berilgan fayldan yangi |
| `-user ali`, `-perm 644` | ega, ruxsat (aynan shu) |
| `-empty` | bo'sh fayl yoki bo'sh papka |
| `-maxdepth N`, `-mindepth N` | chuqurlik chegarasi; bular global sozlama, testlardan oldin yoziladi |
| `!`, `-o`, `\( \)` | emas, yoki, guruhlash |

| Amal | Nima qiladi |
|------|-------------|
| `-print` | yo'lni chiqaradi; hech qanday amal yozilmasa `find` uni o'zi qo'shadi |
| `-ls` | `ls -l` ga o'xshash ko'rinishda chiqaradi |
| `-delete` | o'chiradi |
| `-prune` | papka bo'lsa, uning ichiga tushmaydi |
| `-exec cmd {} \;` | har fayl uchun buyruqni alohida ishga tushiradi, `{}` o'rniga yo'l qo'yiladi |
| `-exec cmd {} +` | yo'llarni yig'ib, buyruqni iloji boricha kam marta ishga tushiradi |

6-bo'limdagi `demo` papkasiga ichki papkalar qo'shamiz:

```
ubuntu@lab:~/playground/demo$ mkdir -p docs/old && touch docs/guide.md docs/old/draft.md
ubuntu@lab:~/playground/demo$ find . -name '*.md' | sort
./.secret.md
./docs/guide.md
./docs/old/draft.md
./notes.md
./todo.md
ubuntu@lab:~/playground/demo$ find . -maxdepth 1 -type f ! -name '*.md' | sort
./img1.png
./img10.png
./img2.png
```

Birinchi buyruq: `echo *.md` ikkita fayl topgan edi, `find` beshta: u ichki papkalarga tushadi va `-name` dagi `*` nom boshidagi nuqtaga ham mos keladi (shell globidan farqi). Har natija boshlang'ich yo'l (`.`) bilan boshlanadi. `find` natijani papka jadvalidagi tartibda beradi, alifbo bo'yicha emas, shuning uchun misolda `| sort` bor (pipe, 5-darsda). Ikkinchi buyruq: `-maxdepth 1` faqat joriy papka, `-type f` faqat oddiy fayllar, `!` keyingi testni inkor qiladi.

Sonli testlarning o'lchov birligi butun songa yaxlitlanadi. `-mtime +30` "30 to'liq sutkadan ko'p", ya'ni kamida 31 sutka oldin o'zgargan degani. `-size` da hajm birlikka qarab yuqoriga yaxlitlanadi, shuning uchun `-size -1M` faqat bo'sh fayllarni topadi (1 baytli fayl ham "1M" deb yaxlitlanadi). Kichik fayllar uchun kichikroq birlik (`k`) ishlating.

### -exec: ikki shakl

```
ubuntu@lab:~/playground/demo$ find . -name '*.md' -exec wc -c {} \;
0 ./notes.md
0 ./todo.md
0 ./.secret.md
0 ./docs/guide.md
0 ./docs/old/draft.md
ubuntu@lab:~/playground/demo$ find . -name '*.md' -exec wc -c {} +
0 ./notes.md
0 ./todo.md
0 ./.secret.md
0 ./docs/guide.md
0 ./docs/old/draft.md
0 total
```

`wc -c` fayl hajmini baytda chiqaradi va bir nechta fayl berilsa oxirida `total` qatorini qo'shadi (qatorlar tartibi sizda boshqacha bo'lishi mumkin). `\;` shaklida `total` yo'q: `wc` besh marta, har safar bitta fayl bilan ishga tushdi. `+` shaklida bitta `total`: `wc` bir marta, beshta fayl bilan ishga tushdi. 10 000 fayl uchun `\;` 10 000 ta jarayon yaratadi, `+` bir nechta. `+` deyarli har doim to'g'ri tanlov; `\;` buyruq faqat bitta fayl qabul qilganda yoki har fayl uchun alohida natija kerak bo'lganda. `;` shell uchun maxsus belgi, shuning uchun `\;` deb ekranlanadi.

### -delete va tartib

**Tuzoq: `-delete` ning joyi.** `find . -delete -name '*.tmp'` hamma narsani o'chiradi: `-delete` zanjirda `-name` dan oldin turibdi va har fayl uchun birinchi bo'lib bajariladi. Tartib: avval testlar, oxirida amal. Qoida: buyruqni avval `-print` bilan ishga tushiring, ro'yxatni o'qing, keyin `-print` ni `-delete` ga almashtiring.

**Tuzoq: `-o` va amal.** "Va" "yoki" dan kuchliroq bog'laydi. `find . -name '*.a' -o -name '*.b' -print` faqat `.b` larni chiqaradi, chunki `-print` faqat ikkinchi shartga bog'langan. To'g'risi: `find . \( -name '*.a' -o -name '*.b' \) -print`.

Ruxsat yo'q papkalar haqidagi xatolar (`Permission denied`) stderr'ga chiqadi va natijani ko'mib yuboradi. `2>/dev/null` ularni tashlab yuboradi (5-darsda).

### Real ishda qachon kerak

- Disk to'lganda: katta fayllar (`-size`), eski loglar (`-mtime`). Log tozalash cron vazifalari odatda bitta `find ... -mtime +N -delete` qatori.
- "Bu konfiguratsiya qayerda?": `find /etc -name '*nginx*'`. "Deploy'dan keyin nima o'zgardi?": `find /srv/app -newer marker`.
- Ruxsatlarni ommaviy tuzatish: `find . -type d -exec chmod 755 {} +` (6-darsda).
- Dockerfile va CI'da `node_modules`, `__pycache__`, `*.map` kabi ortiqcha narsalarni tozalash.

### Nima uchun shunday

`find` flag'lar to'plami emas, kichik ifoda tili: shuning uchun tartib ma'noga ega va `-delete` kabi amal "shartdan keyin" turishi kerak. Bu noqulay ko'rinadi, lekin o'sha dizayn murakkab shartlarni (`!`, `-o`, guruhlash) bitta o'tishda hisoblashga imkon beradi. Muqobili `find ... | xargs cmd` (7-darsda): u ham ishlaydi, lekin nomida bo'shliq bor fayllarda qo'shimcha ehtiyot talab qiladi, `-exec ... +` esa nomlarni to'g'ridan-to'g'ri argument qilib beradi. Daraxtni har safar aylanish sekin bo'lgani uchun `locate` (oldindan qurilgan indeks) ham bor, lekin u real vaqtdagi holatni ko'rsatmaydi.

## 8. Buyruqlar tarixi

### Tarix qayerda yashaydi

Interaktiv bash har bajarilgan buyruq qatorini xotiradagi ro'yxatga qo'shadi. Diskdagi `~/.bash_history` fayli sessiya boshida o'qiladi va sessiya **tugaganda** yoziladi. Bundan uch xulosa: ikki ochiq terminal bir-birining yangi buyruqlarini ko'rmaydi; sessiya `kill -9` bilan o'ldirilsa yoki ulanish qo'pol uzilsa, o'sha sessiya tarixi yo'qolishi mumkin; tarixni majburan hozir yozish uchun `history -a` bor.

```
ubuntu@lab:~$ history 3
  <N>  cd ~/playground/demo
  <N>  find . -name '*.md' | sort
  <N>  history 3
ubuntu@lab:~$ echo one two three
one two three
ubuntu@lab:~$ echo !$
echo three
three
```

`history 3` oxirgi uch yozuvni raqami bilan ko'rsatadi (o'zi ham tarixda). `!$` oldingi buyruqning oxirgi argumentiga almashadi. Bash tarix almashtirishidan keyin avval hosil bo'lgan buyruqni chiqaradi (`echo three`), keyin bajaradi: nima ishga tushganini ko'rib turasiz.

| Vosita | Nima qiladi |
|--------|-------------|
| `history`, `history 20` | butun tarix, oxirgi 20 tasi |
| `Ctrl+R` | teskari qidiruv: yozgan sari mos buyruq chiqadi, yana `Ctrl+R` oldingi topilma, `Enter` bajaradi, `Ctrl+G` bekor qiladi |
| `!!` | oxirgi buyruq (masalan `sudo !!`) |
| `!$` | oxirgi buyruqning oxirgi argumenti (`Alt+.` ham) |
| `!42` | 42-raqamli buyruq |
| `history -d 42` | bitta yozuvni o'chirish |

O'zgaruvchilar: `HISTSIZE` xotiradagi ro'yxat uzunligi, `HISTFILESIZE` fayldagi qatorlar chegarasi, `HISTCONTROL` nimani yozmaslik. Ubuntu'ning standart `~/.bashrc` faylida `HISTCONTROL=ignoreboth`: ketma-ket takrorlar va bo'shliq bilan boshlangan buyruqlar tarixga tushmaydi.

**Tuzoq: tarixdagi secret'lar.** `mysql -psecret` yoki `curl -H "Authorization: Bearer ..."` tarixga ochiq matnda tushadi va `~/.bash_history` da qoladi; buyruq ishlayotgan paytda argumentlar `ps` chiqishida boshqa foydalanuvchilarga ham ko'rinadi. Secret'ni argument sifatida bermang: fayl, muhit o'zgaruvchisi yoki interaktiv so'rov ishlating.

### Real ishda qachon kerak

- `Ctrl+R` uzun `docker run`, `kubectl`, `ssh` buyruqlarini qayta terish o'rniga. Kundalik eng ko'p ishlatiladigan klavish.
- Hodisadan keyin "serverda nima qilingan edi?" savoli uchun `history` birinchi manba, lekin ishonchli audit emas: yuqoridagi sabablar bilan to'liq bo'lmasligi va tahrirlangan bo'lishi mumkin.
- Notanish serverga kirganda `~/.bash_history` oldingi administrator nima qilganini ko'rsatadi (va ba'zan unutilgan parollarni ham, shuning uchun bu fayl xavfsizlik tekshiruvlarida qaraladi).

### Nima uchun shunday

Tarixning faqat chiqishda yozilishi eski, sekin disklar davridan qolgan soddalik: har buyruqda faylga yozmaslik va bir necha sessiyaning yozuvlari aralashib ketmasligi. Narxi ham shu: sessiyalar bir-birini ko'rmaydi. zsh bu yerda boshqa standartlarni taklif qiladi (sessiyalar orasida umumiy tarix sozlamasi bor), bash'da esa xatti-harakat `histappend` va `PROMPT_COMMAND` orqali sozlanadi (5-darsda startup fayllar bilan birga).

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Absolut yo'l | `/` dan boshlanadigan, joriy papkaga bog'liq bo'lmagan yo'l |
| Nisbiy yo'l | joriy papkadan hisoblanadigan yo'l |
| Joriy papka (cwd) | jarayonning nisbiy yo'llar hisoblanadigan papkasi, har jarayonda alohida |
| Inode | faylning nomdan tashqari barcha metadata'sini va bloklar manzilini saqlaydigan fayl tizimi yozuvi |
| Metadata | fayl mazmuni emas, u haqidagi ma'lumot: tur, ruxsat, ega, hajm, vaqtlar |
| mtime | mazmun oxirgi o'zgargan vaqt |
| ctime | inode (metadata yoki mazmun) oxirgi o'zgargan vaqt, yaratilgan vaqt emas |
| atime | mazmun oxirgi o'qilgan vaqt, `relatime` tufayli taxminiy |
| Yashirin fayl | nomi nuqta bilan boshlanadigan fayl, alohida atributi yo'q |
| Idempotent | necha marta bajarilsa ham bir xil natija beradigan amal (`mkdir -p`) |
| Atomik | yo to'liq bajariladigan, yo umuman bajarilmaydigan, oraliq holati ko'rinmaydigan amal |
| `rename` | nomni o'zgartiradigan system call, bir fayl tizimi ichidagi `mv` ning asosi |
| `unlink` | papka jadvalidan nomni o'chiradigan system call, `rm` ning asosi |
| Pager | matnni ekranma-ekran ko'rsatadigan dastur (`less`) |
| Globbing | shell'ning `*`, `?`, `[...]` pattern'ini mavjud fayl nomlariga ochishi |
| Brace expansion | shell'ning `{a,b}` va `{1..3}` dan fayl tizimiga qaramasdan satrlar generatsiya qilishi |
| Test (`find`) | fayl uchun rost yoki yolg'on qaytaradigan ifoda bo'lagi (`-name`, `-type`) |
| Amal (`find`) | fayl ustida ish bajaradigan ifoda bo'lagi (`-print`, `-delete`, `-exec`) |
| Tarix (history) | bash eslab qolgan buyruqlar ro'yxati, chiqishda `~/.bash_history` ga yoziladi |

## Tuzoqlar

- `rm -rf "$VAR/"*` bo'sh o'zgaruvchi bilan. Production'ni o'chirgan eng mashhur xato turi. `set -u`, `"${VAR:?}"`, va avval `echo`.
- `find ... -delete` ni testlardan oldin yozish, yoki `-print` bilan sinab ko'rmasdan ishlatish.
- Tirnoqsiz pattern: `find -name *.log`, `grep -r *.js`. Joriy papkada mos fayl bo'lmaguncha ishlaydi, bo'lgan kuni sinadi.
- `cp -r src dst` ni idempotent deb o'ylash: ikkinchi ishga tushirishda `dst/src` paydo bo'ladi.
- `cp -r` bilan backup olish: vaqtlar hozirgi vaqtga, ega nusxa olgan foydalanuvchiga almashadi. `cp -a` yoki `rsync -a`.
- `*` yashirin fayllarni olmaydi: `mv app/* new/` dan keyin `.env` va `.git` eski joyda qoladi.
- Skriptda `cd` natijasini tekshirmaslik: `cd build; rm -rf *` da `cd` muvaffaqiyatsiz bo'lsa `rm` joriy papkada ishlaydi. `cd build && rm ...` yoki `set -e`.
- Fayl tizimlari orasidagi `mv` atomik emas. Katta faylni `/tmp` dan boshqa diskka `mv` qilish o'rtada uzilsa yarim fayl qoladi.
- mtime'ni dalil deb qabul qilish: uni fayl egasi `touch -d` bilan o'zgartira oladi. ctime'ni "yaratilgan vaqt" deb o'qish.
- `ls` chiqishini skriptda parse qilish, `find -size -1M` dan kichik fayllarni kutish.
- Parol va tokenni buyruq argumentida yozish: tarixda va `ps` chiqishida ko'rinadi.
- macOS host'da sinab, natijani Linux'niki deb yozish: BSD `stat`, `touch -d`, `find` va registrni farqlamaydigan fayl tizimi boshqa natija beradi. Javoblar VM'dan.

## Manbalar

- https://www.gnu.org/software/coreutils/manual/coreutils.html – GNU coreutils (`ls`, `cp`, `mv`, `rm`, `touch`, `stat`)
- https://www.gnu.org/software/findutils/manual/html_mono/find.html – GNU findutils, `find` to'liq qo'llanma
- https://www.gnu.org/software/bash/manual/bash.html#Pattern-Matching – bash pattern matching
- https://www.gnu.org/software/bash/manual/bash.html#Brace-Expansion – brace expansion
- https://www.gnu.org/software/bash/manual/bash.html#Using-History-Interactively – bash history
- https://man7.org/linux/man-pages/man7/glob.7.html – `glob(7)`
- https://man7.org/linux/man-pages/man7/inode.7.html – `inode(7)`: inode maydonlari va uchta vaqt
- https://man7.org/linux/man-pages/man2/rename.2.html – `rename(2)`: atomiklik va fayl tizimlari orasidagi cheklov (`EXDEV`)
- https://man7.org/linux/man-pages/man1/find.1.html – `find(1)`
- https://mywiki.wooledge.org/ParsingLs – nima uchun `ls` chiqishini parse qilmaslik kerak
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 2–4, 8, 17 boblar

---

## Birga bajaramiz

Kichik "kiruvchi hisobotlar" papkasini boshidan oxirigacha yuritamiz: tuzilma yaratish, fayllarni ko'rish, tanlab ko'chirish, konfiguratsiyani atomik almashtirish, `find` bilan tekshirish va tozalash. Hamma narsa VM ichida, `~/playground/walk` da.

1. Tuzilmani bitta buyruq bilan yarating va ichiga kiring:

```
ubuntu@lab:~$ mkdir -p ~/playground/walk/{inbox,done,conf}
ubuntu@lab:~$ cd ~/playground/walk
ubuntu@lab:~/playground/walk$ ls
conf  done  inbox
```

Shell `{inbox,done,conf}` ni uchta yo'lga ochdi, `mkdir` uchta argument oldi. `-p` tufayli `playground` va `walk` ham yaratildi, qayta bajarilsa xato bo'lmaydi.

2. Fayllar yarating: uchta hisobot, bitta yashirin fayl; bittasini eskiga aylantiring, bittasiga mazmun yozing:

```
ubuntu@lab:~/playground/walk$ touch inbox/report-{01..03}.csv inbox/.lock
ubuntu@lab:~/playground/walk$ touch -d "10 days ago" inbox/report-01.csv
ubuntu@lab:~/playground/walk$ echo "id,total" > inbox/report-02.csv
ubuntu@lab:~/playground/walk$ ls -lt inbox
total 4
-rw-rw-r-- 1 ubuntu ubuntu 9 <bugun> <vaqt> report-02.csv
-rw-rw-r-- 1 ubuntu ubuntu 0 <bugun> <vaqt> report-03.csv
-rw-rw-r-- 1 ubuntu ubuntu 0 <10 kun oldin> report-01.csv
```

`{01..03}` nol bilan to'ldirilgan ketma-ketlik beradi. `ls -lt` mtime bo'yicha saraladi: eng oxirgi yozilgan `report-02.csv` tepada (9 bayt: `id,total` va qator oxiri), qo'lda eskirtirilgan `report-01.csv` pastda. `total 4`: faqat bitta fayl bitta 4K blok egallagan, bo'sh fayllar blok egallamaydi. `.lock` ko'rinmaydi, u yashirin (`ls -A inbox` ko'rsatadi).

3. Ko'chirishdan oldin pattern nimaga ochilishini ko'ring, keyin ko'chiring:

```
ubuntu@lab:~/playground/walk$ echo mv inbox/report-0[12].csv done/
mv inbox/report-01.csv inbox/report-02.csv done/
ubuntu@lab:~/playground/walk$ mv -v inbox/report-0[12].csv done/
renamed 'inbox/report-01.csv' -> 'done/report-01.csv'
renamed 'inbox/report-02.csv' -> 'done/report-02.csv'
```

`echo` buyruqni bajarmadi, faqat shell ochgan ko'rinishini chiqardi: `mv` aynan shu uchta argumentni oladi. Oxirgi argument mavjud papka bo'lgani uchun `mv` "shu papkaning ichiga" deb tushundi. `renamed` so'zi mexanizmni aytib turibdi: bir fayl tizimi ichida bu nom o'zgartirish, nusxa emas.

4. Konfiguratsiya yarating, backup oling va yangi versiyani atomik almashtiring:

```
ubuntu@lab:~/playground/walk$ echo "mode=fast" > conf/app.conf
ubuntu@lab:~/playground/walk$ cp -a conf/app.conf{,.bak}
ubuntu@lab:~/playground/walk$ ls -i conf
<N1> app.conf  <N2> app.conf.bak
ubuntu@lab:~/playground/walk$ echo "mode=safe" > conf/app.conf.new
ubuntu@lab:~/playground/walk$ mv conf/app.conf.new conf/app.conf
ubuntu@lab:~/playground/walk$ ls -i conf
<N3> app.conf  <N2> app.conf.bak
ubuntu@lab:~/playground/walk$ cat conf/app.conf
mode=safe
```

`app.conf{,.bak}` ikki argumentga ochildi, `cp -a` vaqtni saqlagan mustaqil nusxa yaratdi (inode `<N2>` boshqa). Yangi mazmun avval yonidagi `app.conf.new` ga to'liq yozildi, keyin `mv` uni joyiga qo'ydi. Ikkinchi `ls -i` da `app.conf` ning inode'i o'zgargan (`<N3>`): bu yangi faylning inode'i, eski nom bir amalda unga ko'chdi va eski inode (`<N1>`) bo'shatildi. Shu paytda `app.conf` ni o'qiyotgan dastur yo eski, yo yangi to'liq mazmunni ko'radi.

5. `find` bilan butun daraxtni tekshiring:

```
ubuntu@lab:~/playground/walk$ find . -type f -mtime +7
./done/report-01.csv
ubuntu@lab:~/playground/walk$ find . -type f -name '*.csv' -exec stat -c '%s %n' {} +
9 ./done/report-02.csv
0 ./done/report-01.csv
0 ./inbox/report-03.csv
```

Birinchisi: 7 sutkadan eski yagona fayl, `mv` mtime'ni o'zgartirmagani uchun u ko'chgandan keyin ham "eski". Ikkinchisi: `'*.csv'` tirnoqda, shuning uchun pattern `find` ga yetib bordi; `+` shakli `stat` ni bir marta, uchta yo'l bilan ishga tushirdi, `-c '%s %n'` har biri uchun hajm va nomni chiqardi (qatorlar tartibi farq qilishi mumkin).

6. `inbox` dagi bo'sh fayllarni avval ko'rib, keyin o'chiring:

```
ubuntu@lab:~/playground/walk$ find inbox -type f -empty -print
inbox/report-03.csv
inbox/.lock
ubuntu@lab:~/playground/walk$ find inbox -type f -empty -delete
ubuntu@lab:~/playground/walk$ ls -A inbox
ubuntu@lab:~/playground/walk$ rmdir inbox
```

`-print` bilan ro'yxat kutilgandek ekaniga ishonch hosil qilindi (yashirin `.lock` ham bor: `find` uchun nuqtali nom oddiy nom), keyin faqat oxirgi so'z `-delete` ga almashtirildi. Testlar amaldan oldin turibdi. `ls -A` hech narsa chiqarmadi, `rmdir` bo'sh papkani o'chirdi; bo'sh bo'lmaganida rad etgan bo'lardi.

7. Tozalang va tarixga qarang:

```
ubuntu@lab:~/playground/walk$ cd ~ && rm -r ~/playground/walk
ubuntu@lab:~$ history | tail -n 3
```

Oxirgi uch buyruq raqamlari bilan chiqadi. Ular hozircha faqat shu sessiya xotirasida, `~/.bash_history` ga `exit` paytida yoziladi.

Shu 7 qadamda ko'rganingiz: brace expansion va `mkdir -p` (6 va 3-bo'limlar), `touch -d` va mtime bo'yicha saralash (3 va 2-bo'limlar), glob'ni `echo` bilan oldindan ko'rish va `mv` ning `rename` ekani (6 va 4-bo'limlar), `cp -a` backup va atomik almashtirish (4-bo'lim), `find` testlari, `-exec ... +` va "avval `-print`, keyin `-delete`" tartibi (7-bo'lim), tarixning xotirada turishi (8-bo'lim).

---

## Vazifalar

Ish papkasi: `linux/03-basic-commands/` (`make new m=linux n=03 name=basic-commands` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (butun chiqish emas) va o'z so'zingiz bilan izoh. Barcha vazifalar `lab` VM'da, `~/playground` ichida bajariladi (boshqasi aytilmagan bo'lsa); host'da faqat 15-vazifaning zsh qismi. Har guruh uchun alohida kichik papka oching (`~/playground/a`, `~/playground/b` ...). `sudo` ishlatilmaydi. "Yo'nalish" qaysi bo'limga qarash kerakligini aytadi, javobni emas.

### A. Navigatsiya va ls

1. **Absolute and relative.** `/var/log` ga absolut yo'l bilan o'ting. U yerdan `/etc/ssh` ga faqat nisbiy yo'l bilan o'ting. `cd -` ni ikki marta bajaring va nima bo'lganini izohlang. `ls -ld . ..` nimani ko'rsatadi va `/` da `..` qayerga olib boradi? Yo'nalish: 1-bo'lim, "Mexanizm: joriy papka jarayonniki".

2. **ls columns.** `ls -l /etc/passwd /etc/shadow /tmp /bin` ni bajaring. Har qator uchun: fayl turi, ega, guruh, hajm, vaqt. `/tmp` uchun nima ko'rsatildi: papkaning o'zimi yoki ichimi? Buni qaysi flag bilan o'zgartirasiz? Yo'nalish: 2-bo'lim, "ls nima o'qiydi".

3. **Sorting listings.** `/var/log` dagi eng katta 5 ta faylni, `/etc` da eng oxirgi o'zgartirilgan 5 ta yozuvni va eng eskisini toping (`ls` flag'lari va `head` bilan). `ls -lh /var/log` dagi papka hajmi bilan `du -sh /var/log/journal` (yoki boshqa papka) natijasi nima uchun farq qiladi? Yo'nalish: 2-bo'lim, flag'lar jadvali va "stat va file" oxiri.

4. **Hidden files.** VM'dagi uy papkangizda `ls`, `ls -a`, `ls -A` natijalarini solishtiring. Faylni "yashirin" qiladigan narsa nima? `stat ~/.bashrc` va `file ~/.bashrc /usr/bin/ls /etc/localtime` chiqishini izohlang. Yo'nalish: 2-bo'lim, "stat va file".

### B. Yaratish, ko'chirish, o'chirish

5. **Tree in one command.** Bitta `mkdir` buyrug'i bilan `app/{src/{api,web},test,docs,logs/{2025,2026}}` tuzilmasini yarating va `find app -type d` (yoki `tree`) bilan tekshiring. `-p` siz `mkdir x/y/z` ni bajaring va xatoni yozing. `mkdir -p` ni ikki marta bajarsangiz nima bo'ladi? Yo'nalish: 3-bo'lim, "mkdir" va 6-bo'lim, "Brace expansion".

6. **Three timestamps.** Fayl yarating va `stat` bilan uchta vaqtini yozing. Keyin ketma-ket: mazmunini o'zgartiring, `chmod` bilan ruxsatini o'zgartiring, `cat` bilan o'qing. Har qadamdan keyin qaysi vaqt o'zgarganini jadvalga yozing. `touch -d "2020-01-01" fayl` dan keyin qaysi vaqt o'zgarmadi va nima uchun bu muhim? Yo'nalish: 3-bo'lim, "touch va uchta vaqt".

7. **cp destination semantics.** `src/` papkasini bir nechta fayl bilan yarating. `cp -r src dst` ni ikki marta ketma-ket bajaring va har safar `find dst` natijasini yozing. Farqni izohlang. Ikkala holatda ham bir xil natija beradigan yozuvni toping. Yo'nalish: 4-bo'lim, "cp: nusxa olish".

8. **cp -r versus cp -a.** `src/` ichida eski vaqtli fayl (`touch -d`), ruxsati `600` bo'lgan fayl va symlink (`ln -s`) yarating. `cp -r src r` va `cp -a src a` qiling, `ls -l` bilan uchala papkani solishtiring: vaqt, ruxsat va symlink bilan nima bo'ldi? Backup uchun qaysi biri to'g'ri? Yo'nalish: 4-bo'lim, "cp: nusxa olish". Faqat o'zingiz ko'rgan natijani yozing, taxminni emas.

9. **mv and inodes.** Fayl yarating, `ls -i` bilan inode raqamini yozing. Uni shu papka ichida, keyin `/tmp` ga, keyin `/dev/shm` ga `mv` qiling va har safar inode raqamini tekshiring. Qaysi ko'chirishda inode o'zgardi? `findmnt -T` bilan uchala joyning fayl tizimini aniqlang va natijani izohlang. Yo'nalish: 4-bo'lim, "mv: ko'chirish va nom o'zgartirish".

10. **rm safety.** Quyidagilarni bajaring va har bir xatoni yozing: papkani `-r` siz `rm` qilish, bo'sh bo'lmagan papkani `rmdir` qilish, mavjud bo'lmagan faylni `rm` va `rm -f` qilish (exit code'larni solishtiring). `touch -- -rf` bilan fayl yarating, `rm *` uni o'chiradimi? To'g'ri usulda o'chiring. Yo'nalish: 4-bo'lim, "rm: o'chirish". Faqat `~/playground/b` ichida.

11. **Empty variable trap.** Faqat `echo` bilan, hech narsa o'chirmasdan: `DIR=""` qilib `echo rm -rf "$DIR/"*` ni bajaring va chiqishni yozing. Xuddi shuni `echo rm -rf "${DIR:?}/"*` bilan takrorlang. Ikkinchi yozuv nima qildi? `rm --preserve-root` bu holatda nima uchun yordam bermas edi? Yo'nalish: 4-bo'lim, "rm: o'chirish" dagi birinchi tuzoq. `echo` ni olib tashlamang.

### C. O'qish

12. **less navigation.** `less /var/log/syslog` (yoki `/var/log/dpkg.log`) da: oxiriga o'ting, `error` so'zini orqaga qarab qidiring, qator raqamlarini yoqing, uzun qatorlarni kesish rejimini yoqing, `F` rejimiga o'tib qayting. Ishlatgan klavishlaringizni yozing. `cat` o'rniga `less` ishlatishning ikki sababi nima? Yo'nalish: 5-bo'lim, "less".

13. **Look before cat.** `file /usr/bin/ls /etc/hostname /var/log/wtmp` ni bajaring. `/usr/bin/ls` ni `cat` qilmasdan, uning birinchi 64 baytini xavfsiz ko'rish usulini toping (`head -c` va `od`). `printf 'a\tb\r\n' > t.txt` yarating va `cat t.txt` bilan `cat -A t.txt` farqini izohlang. Yo'nalish: 5-bo'lim, "cat"; `head` va `od` uchun `man` (1-dars).

### D. Globbing

14. **Glob preview.** `touch app.log app.log.1 app.log.2.gz error.log a1.txt a2.txt a10.txt b1.txt .hidden.log` yarating. Faqat `echo` va pattern bilan tanlang: (a) barcha `.log` bilan tugaydiganlar, (b) `a` dan keyin aynan bitta belgi va `.txt`, (c) `a` yoki `b` bilan boshlanadigan `.txt`, (d) raqam bilan tugaydigan nomlar, (e) `a` bilan boshlanmaydiganlar. `.hidden.log` qaysi birida chiqdi va nima uchun? Yo'nalish: 6-bo'lim, "Pattern'ni kim ochadi".

15. **Brace versus glob.** `echo {a,b}.conf` va `echo [ab].conf` ni fayllar yo'q papkada bajaring va farqni izohlang. `ls *.xyz` xatosini kim chiqaradi: shell yoki `ls`? Xuddi shu buyruqni host'dagi `zsh` da bajaring va xatolarni solishtiring (macOS'da standart shell zsh; Zorin'da `echo $SHELL` bilan tekshiring, zsh bo'lmasa bu qismni uyda macOS'da bajaring, hech narsa o'rnatmang). `cp fayl{,.bak}` nimaga ochilishini `echo` bilan ko'rsating. Yo'nalish: 6-bo'lim, "Pattern'ni kim ochadi" va "Brace expansion".

16. **Unquoted pattern.** Ichida `a.txt` va `b.txt` bo'lgan papkada `find . -name *.txt` ni bajaring, xatoni yozing. Shell `find` ga aslida qanday argumentlar berganini `echo find . -name *.txt` bilan ko'rsating. Papkada faqat bitta `.txt` fayl bo'lsa nima bo'ladi va nima uchun bu yanada xavfli? Yo'nalish: 6-bo'lim, "Brace expansion" oxiridagi tuzoq.

17. **Hidden and recursive.** `d/` papkasida oddiy va yashirin fayllar yarating. `ls d/*` va `echo d/.*` nimani ko'rsatadi? `shopt -s globstar` dan oldin va keyin `echo **/*.log` natijasini solishtiring (ichma-ich papkalarda `.log` fayllar yarating). `shopt -s dotglob` nimani o'zgartiradi? Yo'nalish: 6-bo'lim, pattern jadvali; `dotglob` uchun `man bash` da `/dotglob`.

### E. find

18. **find by tests.** Har biri uchun bitta `find` buyrug'i yozing: (a) `/etc` da oxirgi 7 kunda o'zgargan oddiy fayllar, (b) `/var` da 1M dan katta fayllar (`2>/dev/null` bilan), (c) `/etc` ning birinchi darajasidagi symlink'lar, (d) `/usr/share` da nomi `readme` bilan boshlanadigan fayllar, registrga qaramasdan, (e) uy papkangizdagi bo'sh papkalar. (b) da `2>/dev/null` olib tashlansa nima chiqadi? Yo'nalish: 7-bo'lim, "Ifoda qanday hisoblanadi" dagi testlar jadvali.

19. **exec forms.** Ichida 20 ta fayl bo'lgan papkada `find . -type f -exec echo {} \;` va `find . -type f -exec echo {} +` ni bajaring. Har birida `echo` necha marta ishga tushdi, buni chiqishdan qanday bilasiz? `-exec ls -l {} +` bilan `-ls` farqi bormi? Qaysi shaklni qachon tanlaysiz? Yo'nalish: 7-bo'lim, "-exec: ikki shakl".

20. **delete placement.** `del/` papkasida 5 ta `.tmp` va 5 ta `.keep` fayl yarating va `cp -a del del2` bilan nusxa oling. `del` da to'g'ri tartibda (avval `-print`, keyin `-delete`) faqat `.tmp` larni o'chiring. `del2` da `find del2 -delete -name '*.tmp'` ni bajaring va nima qolganini ko'ring. Nima uchun bunday bo'ldi? Yo'nalish: 7-bo'lim, "-delete va tartib". Noto'g'ri buyruqni faqat `~/playground` ichidagi `del2` da bajaring.

### F. Tarix

21. **History mechanics.** `echo $HISTSIZE $HISTFILESIZE $HISTCONTROL` qiymatlarini yozing. Boshiga bo'shliq qo'yib buyruq bajaring va `history | tail` da bor-yo'qligini tekshiring. `!!`, `!$` va `Ctrl+R` ni sinang. Ikkinchi `multipass shell lab` sessiyasini oching: u birinchi sessiyaning hozirgi buyruqlarini ko'radimi, nima uchun? Yo'nalish: 8-bo'lim, "Tarix qayerda yashaydi".

### G. Yakuniy

22. **Project cleanup.** `~/playground/proj` da quyidagi buyruqlar bilan "iflos" loyiha yarating (`~/playground` ichida turib): `mkdir -p proj/{src,logs,tmp,node_modules/{a,b}}`; `touch proj/src/{index,app,util}.js proj/tmp/{1..5}.tmp proj/node_modules/{a,b}/index.js`; `touch -d "45 days ago" proj/logs/old-{1..3}.log`; `touch proj/logs/new-{1..2}.log`; `head -c 2M /dev/urandom > proj/tmp/big.bin`. Keyin har birini avval ko'rib (`-print` yoki `echo`), so'ng bajaring: (a) barcha `.tmp` fayllarni o'chiring, (b) 30 kundan eski loglarni `proj/archive/` ga ko'chiring (papkani yarating), (c) 1M dan katta fayllarni hajmi bilan ro'yxatlang, (d) `node_modules` dan tashqari barcha `.js` fayllarni toping, (e) `proj` ning vaqtlar va ruxsatlar saqlangan nusxasini `proj.bak` ga oling. Buyruqlar va yakuniy `find proj | sort` natijasini README'ga yozing. Yo'nalish: 3, 4, 6 va 7-bo'limlar; (d) uchun testlar jadvalidagi `-path`, `!` va amallar jadvalidagi `-prune`.

### Topshirish

Tayyor bo'lgach:
1. `linux/03-basic-commands/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida. Bu darsda alohida skript yoki boshqa fayl topshirilmaydi.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; 15-vazifada qaysi qism VM'da (bash), qaysi qism host'da (zsh) bajarilgani ko'rinadi.
3. `make check` toza o'tadi (host'da).
4. VM'da `~/playground` o'chirilgan, `/tmp` va `/dev/shm` da 9-vazifadan qolgan fayl yo'q.
5. `multipass stop lab` qilingan (`multipass list` da `Stopped`).
6. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Joriy papka kimning xususiyati va nima uchun `cd` builtin?
- `ls -l` ustunlari qayerdan olinadi? Fayl nomi inode'da saqlanadimi?
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
