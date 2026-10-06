# 6-dars: Fayllar: ruxsatlar, linklar, arxivlar

Maqsad: Linux'ning fayl ruxsatlari modelini (ega, guruh, boshqalar; `rwx`; octal; `umask`), egalikni o'zgartirishni (`chown`), maxsus bitlarni (setuid, setgid, sticky), hard va soft linklarni hamda arxivlash va siqishni (`tar`, `gzip`, `zip`) mexanizm darajasida, noldan tushunish. `Permission denied` ops ishida eng ko'p uchraydigan xato, uni `chmod 777` bilan emas, kernel tekshiruvi qanday ishlashini bilib yechish kerak. Frontend ishida bu qatlam deyarli ko'rinmaydi: `npm install` fayllarni o'zi yaratadi, brauzer esa fayl tizimiga umuman yetmaydi. Serverda esa har servis o'z foydalanuvchisi nomidan ishlaydi va har "nima uchun o'qiy olmayapti" savoli shu darsdagi modelga borib taqaladi. Bu dars 3-darsdagi `ls -l` ustunlarini va 5-darsdagi shell va `sudo` ni davom ettiradi; 10-dars (foydalanuvchi va guruhlar), 13-dars (inode va fayl tizimlari), Docker modulidagi volume ruxsatlari va Kubernetes'dagi `securityContext` shu yerdagi modelga tayanadi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va 1–6 vazifalar, ikkinchi kun 3–5 bo'limlar va 7–12 vazifalar, uchinchi kun 6-bo'lim va C guruhi (13–17), to'rtinchi kun 7-bo'lim va D guruhi (18–21), beshinchi kun "Birga bajaramiz", 22-vazifa, README va tozalash. E'tiborni quyidagilarga qarating: ruxsat tekshiruvi algoritmi (birinchi mos kelgan sinf hal qiladi), `rwx` ning fayl va papka uchun har xil ma'nosi, o'chirish huquqi papkaga tegishli ekani, `umask` ayirish emas mask ekani, setgid papka, nisbiy symlink qayerdan hisoblanishi, `tar` da egalik va yo'llar.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Sizdagi sana, hajm va inode raqamlari farq qiladi, bunday joylar `<...>` bilan belgilangan. Har tajribadan oldin natijani taxmin qiling: bu darsda taxmin ko'p marta noto'g'ri chiqadi va aynan o'sha joylar esda qoladi.

## Laboratoriya

Bu dars to'liq `lab` VM ichida bajariladi (`SETUP.md` bo'yicha yaratilgan Ubuntu 24.04, foydalanuvchi `ubuntu`, shell `bash`). Sabab: foydalanuvchi va guruh yaratiladi, `chown` va `sudo` ishlatiladi, bular ish mashinasida qilinmaydi. Host'da faqat repo ishi (`make new`, `make check`, `git`) qoladi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | `make new`, README yozish, `make check`, `git`, `multipass` buyruqlari |
| `lab` VM | `ubuntu@lab:~$` | barcha 22 vazifa: `chmod`, `chown`, `umask`, `ln`, `tar`, sinov foydalanuvchilari |

Boshlashdan oldin snapshot oling (host'da) va kerakli paketlarni o'rnating (VM'da). Snapshot bu VM diskining shu ondagi holati, buzilsa shu nuqtaga qaytasiz:

```
multipass stop lab && multipass snapshot lab --name before-06 && multipass start lab
multipass shell lab
sudo apt update && sudo apt install -y zip unzip zstd bzip2 xz-utils
```

`gzip` va `tar` tizimda doim bor, qolgan siqish vositalari alohida paket: o'rnatilgan bo'lsa `apt` shunchaki "already the newest version" deydi.

Sinov foydalanuvchilari (B guruhidan boshlab kerak): `alice`, `bob` va `devs` guruhi. Foydalanuvchilarni boshqarish 10-darsda chuqur o'tiladi, bu yerda faqat tayyor buyruqlar ishlatiladi:

```
sudo adduser --disabled-password --gecos "" alice
sudo adduser --disabled-password --gecos "" bob
sudo groupadd devs && sudo usermod -aG devs alice && sudo usermod -aG devs bob
```

`--disabled-password` parolsiz hisob yaratadi (parol bilan kirib bo'lmaydi), `--gecos ""` ism va telefon haqidagi savollarni o'tkazib yuboradi. Boshqa foydalanuvchi nomidan bitta buyruq: `sudo -u alice <buyruq>`, uning shell'iga kirish: `sudo -iu alice` (chiqish: `exit`).

Tozalash: `sudo deluser --remove-home alice`, `sudo deluser --remove-home bob`, `sudo groupdel devs`, `sudo rm -r /srv/devs /srv/drop`, `rm -r ~/files ~/demo ~/walk`. Yoki host'da: `multipass stop lab && multipass restore lab.before-06 && multipass start lab`.

Bu dars oldingi darslar holatiga tayanmaydi. Mashinani dars o'rtasida almashtirsangiz, ikkinchi mashinadagi `lab` VM'da yuqoridagi `apt install` va uchta foydalanuvchi buyrug'ini qayta bajaring, `~/files` ni qaytadan yarating; README javoblari git orqali ko'chadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`. Bu darsda arxitektura hech narsani o'zgartirmaydi. Host ham Linux, lekin undagi foydalanuvchi, guruhlar va `umask` VM'dagidan farq qilishi mumkin, shuning uchun javoblar faqat VM'dan olinadi. |
| macOS (uy) | VM `arm64`, ichidagi natijalar Zorin'dagi bilan bir xil. Host'da BSD utilitalari: `stat -c` yo'q (o'rniga `stat -f '%Sp %Lp %Su %Sg %N' fayl`), `ln -r` yo'q, `tar` esa bsdtar bo'lib, Mac'da yaratilgan arxivga `._nom` ko'rinishidagi qo'shimcha fayllar qo'shishi mumkin (`COPYFILE_DISABLE=1 tar ...` buni o'chiradi). Vazifalarni host'da sinamang, faqat VM'da. |

---

## 1. Ruxsat modeli

### Bu nima

Linux ko'p foydalanuvchili tizim: bitta serverda `root`, siz, `www-data` (web server), `postgres` (baza) kabi o'nlab foydalanuvchi nomidan dasturlar ishlaydi. Ruxsat modeli "kim qaysi faylni o'qiy oladi, o'zgartira oladi, ishga tushira oladi" savoliga javob beradi. Har faylda (aniqrog'i uning **inode**'ida, ya'ni fayl metadata'si saqlanadigan yozuvda, 13-darsda chuqur) uchta narsa turadi: ega (**UID**, foydalanuvchi raqami), guruh (**GID**, guruh raqami) va rejim (**mode**) bitlari. Har jarayonda esa: kim nomidan ishlayotgani (effective UID) va guruhlari ro'yxati. Fayl ochilayotganda kernel shu ikki tomonni solishtiradi.

Rejim uch sinfga bo'linadi: **u**ser (ega), **g**roup (guruh), **o**ther (boshqalar). Har sinfda uchta bit: `r` (read), `w` (write), `x` (execute).

### Misol: rejimni o'qish

```
ubuntu@lab:~$ stat -c '%A %a %U %G %n' /etc/passwd /etc/shadow
-rw-r--r-- 644 root root /etc/passwd
-rw-r----- 640 root shadow /etc/shadow
ubuntu@lab:~$ id
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),27(sudo),<boshqa guruhlar>
```

`stat` fayl metadata'sini chiqaradi, `-c` formatni beradi: `%A` rejim harflar bilan, `%a` octal, `%U` ega, `%G` guruh, `%n` nom. Birinchi qator: `-` oddiy fayl (`d` papka, `l` symlink bo'lardi); `rw-` ega (`root`) o'qiydi va yozadi; `r--` guruh (`root`) o'qiydi; `r--` qolgan hamma o'qiydi. `/etc/passwd` da foydalanuvchilar ro'yxati bor, parollar yo'q, shuning uchun hammaga ochiq. Ikkinchi qator: `/etc/shadow` da parol xeshlari turadi; guruh `shadow` o'qiy oladi, boshqalar uchun `---`, ya'ni hech narsa. `id` joriy jarayonning UID, asosiy GID va barcha guruhlarini ko'rsatadi: `ubuntu` `shadow` guruhida yo'q, demak u uchun other bitlari ishlaydi.

### Mexanizm: tekshiruv algoritmi

1. Jarayon UID'i 0 (root) bo'lsa: o'qish va yozishga ruxsat beriladi (bajarish uchun kamida bitta `x` bit bo'lishi kerak).
2. Jarayon UID'i fayl egasiga teng bo'lsa: **faqat** user bitlari qaraladi.
3. Aks holda, jarayon guruhlaridan biri fayl guruhiga teng bo'lsa: **faqat** group bitlari qaraladi.
4. Aks holda: other bitlari.

Birinchi mos kelgan sinf hal qiladi, keyingisiga o'tilmaydi. Bu kutilmagan natija beradi:

```
ubuntu@lab:~/demo$ echo hi > own.txt && chmod 044 own.txt
ubuntu@lab:~/demo$ ls -l own.txt
----r--r-- 1 ubuntu ubuntu 3 <sana> own.txt
ubuntu@lab:~/demo$ cat own.txt
cat: own.txt: Permission denied
```

Guruh ham, boshqalar ham o'qiy oladi, ega esa yo'q: kernel 2-qadamda to'xtadi, user bitlari `---`, javob "yo'q". Ega bu holatdan o'zi chiqadi (`chmod u+r own.txt`), chunki `chmod` qilish huquqi rejimga emas, egalikka bog'liq.

Guruhlar ro'yxati login paytida o'rnatiladi va jarayonga yopishib qoladi. Foydalanuvchi guruhga qo'shilgandan keyin ishlab turgan sessiyalar eskicha qoladi: `id` (joriy jarayon) va `id username` (bazadagi holat) farq qilishi mumkin.

### rwx: fayl va papka

| Bit | Faylda | Papkada |
|-----|--------|---------|
| `r` | mazmunni o'qish | ichidagi nomlar ro'yxatini o'qish (`ls`) |
| `w` | mazmunni o'zgartirish | yozuv qo'shish, o'chirish, nomini o'zgartirish (`x` bilan birga) |
| `x` | dastur sifatida ishga tushirish | ichiga kirish (`cd`) va ichidagi fayllarga nomi bo'yicha murojaat |

Papka bu "nom, inode raqami" juftliklari jadvali, xolos. Fayl mazmuni papkaning ichida emas, papkada faqat nom va "qayerdan topish" yoziladi. Shundan uchta oqibat chiqadi:

- Faylni **o'chirish** faylning emas, papkaning `w` va `x` ruxsatiga bog'liq: o'chirish papka jadvalidan qatorni olib tashlashdir. Faqat o'qish uchun bo'lgan (`444`), root'ga tegishli faylni ham o'z papkangizdan o'chira olasiz.
- Faylga yetish uchun yo'ldagi **har bir** papkada `x` kerak. Ubuntu 24.04 da `/home/ubuntu` rejimi `750`: ichidagi `644` fayl ham boshqa foydalanuvchilarga yopiq. Web server "403" berishining odatiy sababi shu.
- `r` bor, `x` yo'q papkada nomlar ko'rinadi, lekin fayllarning o'ziga yetib bo'lmaydi. `x` bor, `r` yo'q papkada ro'yxat ko'rinmaydi, lekin nomini bilgan faylni ochish mumkin.

```
ubuntu@lab:~/demo$ mkdir vault && echo x > vault/k.txt && chmod 400 vault
ubuntu@lab:~/demo$ ls vault
k.txt
ubuntu@lab:~/demo$ ls -l vault
ls: cannot access 'vault/k.txt': Permission denied
total 0
-????????? ? ? ? ?            ? k.txt
ubuntu@lab:~/demo$ chmod 100 vault && ls vault
ls: cannot open directory 'vault': Permission denied
ubuntu@lab:~/demo$ cat vault/k.txt
x
```

`400` (faqat `r`): `ls vault` nomni ko'rsatdi, chunki nomlar jadvalini o'qish mumkin. `ls -l` esa har fayl uchun `stat` qilishi kerak, bu "nomi bo'yicha murojaat", `x` siz bo'lmaydi; shuning uchun nom bor, qolgan ustunlar `?`. `100` (faqat `x`): ro'yxat yopiq, lekin nomini bilsangiz fayl o'qiladi. Oxirida `chmod 700 vault` bilan qaytaring.

Yo'ldagi to'siqni `namei -l` ko'rsatadi, u yo'lni bo'laklarga ajratib har birining rejimi va egasini chiqaradi:

```
ubuntu@lab:~/demo$ namei -l ~/demo/vault/k.txt
f: /home/ubuntu/demo/vault/k.txt
drwxr-xr-x root   root   /
drwxr-xr-x root   root   home
drwxr-x--- ubuntu ubuntu ubuntu
drwxrwxr-x ubuntu ubuntu demo
drwx------ ubuntu ubuntu vault
-rw-rw-r-- ubuntu ubuntu k.txt
```

Yuqoridan pastga o'qiladi: `/` va `home` hammaga `x` beradi; `ubuntu` papkasi boshqalarga (`---`) yopiq, guruhga `r-x`; `vault` faqat egaga ochiq. Boshqa foydalanuvchi uchinchi qatordayoq to'xtaydi, fayl rejimi `664` bo'lishining unga foydasi yo'q.

Skriptni `./script.sh` deb ishga tushirish uchun `r` va `x` ikkalasi kerak (interpretator faylni o'qiydi), kompilyatsiya qilingan binary uchun `x` yetarli.

### Real ishda qachon kerak

- Servis "Permission denied" bilan yiqilganda: servis kim nomidan ishlaydi (`ps -o user= -p PID`), fayl kimniki, yo'ldagi qaysi papka to'sadi (`namei -l`).
- Deploy'dan keyin nginx statik fayllarga 403 berganda: sabab ko'pincha fayl emas, yuqoridagi papkalardan birida `x` yo'qligi.
- Secret faylni (`.env`, kalit) kim o'qiy olishini tekshirishda: ega, guruh va other bitlari.

### Nima uchun shunday

Model 1970-yillardagi Unix'dan qolgan: har fayl uchun atigi 9 bit va ikkita raqam, tekshiruv bir necha solishtirish bilan bajariladi, shuning uchun juda tez va hamma fayl tizimlarida bir xil. "Birinchi mos kelgan sinf" qoidasi ataylab: u "shu guruhdan boshqa hamma" kabi istisnolarni ifodalash imkonini beradi. Papkaning oddiy jadval ekani esa hard link va o'chirish semantikasini soddalashtiradi (6-bo'lim). Modelning kamchiligi: bitta fayl uchun faqat bitta ega va bitta guruh. Nozikroq qoidalar kerak bo'lsa ACL (access control list, faylga qo'shimcha "falon foydalanuvchiga ham ruxsat" yozuvlari) ishlatiladi, lekin kundalik ishning katta qismi shu 9 bit bilan yechiladi.

## 2. chmod

### Bu nima

`chmod` (change mode) fayl rejimini o'zgartiradi. Uni faqat fayl egasi yoki root bajara oladi. Ikki yozuv shakli bor: octal (raqamli) va simvolik.

### Octal

Har sinf uch bit: `r`=4, `w`=2, `x`=1, yig'indisi bitta raqam. `rw-` = 4+2 = 6, `r-x` = 4+1 = 5. Uch sinf uchta raqam: `640` = `rw-` `r--` `---`.

| Octal | Ko'rinishi | Odatda nima uchun |
|-------|------------|-------------------|
| `644` | `rw-r--r--` | oddiy fayllar, konfiguratsiya |
| `600` | `rw-------` | shaxsiy kalitlar, secret'lar (`ssh` boshqa rejimdagi kalitni rad etadi) |
| `640` | `rw-r-----` | guruh o'qiydigan konfiguratsiya, loglar |
| `755` | `rwxr-xr-x` | papkalar, bajariladigan fayllar |
| `700` | `rwx------` | shaxsiy papka (`~/.ssh`) |
| `750` | `rwxr-x---` | guruhga ochiq papka |
| `664`, `775` | `rw-rw-r--`, `rwxrwxr-x` | guruh bilan birga yoziladigan fayl va papkalar |

### Simvolik

Shakli: kim (`u`, `g`, `o`, `a` = hammasi), amal (`+` qo'shish, `-` olib tashlash, `=` aynan o'rnatish), bitlar.

```
chmod u+x script.sh        # add execute for the owner
chmod go-w file            # remove write from group and other
chmod u=rw,go=r file       # set exactly (same as 644)
chmod a+r file             # a = all three classes
chmod -R g+rwX shared/     # X: execute only for directories and already-executable files
```

Octal rejimni to'liq o'rnatadi (oldingi holat ahamiyatsiz), simvolik mavjud rejimga nisbatan o'zgartiradi. Skriptlarda va hujjatlarda octal ko'proq uchraydi, chunki natija bir ma'noli; qo'lda "faqat `x` qo'shish" uchun simvolik qulay.

### Misol: rekursiv chmod tuzog'i

```
ubuntu@lab:~/demo$ mkdir -p docs/img && touch docs/a.md docs/img/b.png
ubuntu@lab:~/demo$ chmod -R 644 docs
chmod: cannot access 'docs/a.md': Permission denied
chmod: cannot access 'docs/img': Permission denied
ubuntu@lab:~/demo$ chmod -R u=rwX,go=rX docs
ubuntu@lab:~/demo$ stat -c '%a %n' docs docs/a.md docs/img docs/img/b.png
755 docs
644 docs/a.md
755 docs/img
644 docs/img/b.png
```

`-R` (recursive) avval `docs` ning o'zini `644` qildi, ya'ni papkadan `x` ni oldi. Shu ondan boshlab `chmod` ning o'zi ham ichkariga kira olmadi: ikkita `cannot access` xatosi shundan. Tuzatishda katta `X` ishlatildi: u papkalarga `x` beradi, oddiy fayllarga bermaydi (faqat allaqachon biror `x` biti bor fayllarga beradi). Natija: papkalar `755`, fayllar `644`. Boshqa yo'l papka va fayllarga alohida: `find docs -type d -exec chmod 755 {} +` va `find docs -type f -exec chmod 644 {} +` (`find` 7-darsda chuqur). `chmod -R 755` esa teskarisini buzadi: barcha fayllarni bajariladigan qiladi.

**Tuzoq: `chmod 777`.** Muammoni "yechadi", chunki tekshiruvni o'chiradi: tizimdagi har qanday jarayon (buzilgan web ilova ham) faylni o'zgartira oladi. To'g'ri yo'l: jarayon qaysi foydalanuvchi nomidan ishlayotganini va yo'ldagi qaysi element to'sayotganini aniqlash, keyin faqat o'sha sinfga faqat kerakli bitni berish.

### Real ishda qachon kerak

- Yangi skriptni ishga tushirish: `chmod u+x deploy.sh`. Git `x` bitini saqlaydi, shuning uchun bu bir marta qilinadi va commit bo'ladi.
- SSH kaliti: `chmod 600 ~/.ssh/id_ed25519`, aks holda `ssh` "UNPROTECTED PRIVATE KEY FILE" deb rad etadi.
- Dockerfile va Ansible'da rejim odatda octal bilan beriladi (`COPY --chmod=755`, `mode: "0644"`).

### Nima uchun shunday

Octal tanlangan, chunki bitta octal raqam aynan uch bitga teng va rejim uch bitli guruhlardan iborat: raqamga qarab bitlarni ko'rish oson. Simvolik shakl keyin qo'shilgan: "qolganiga tegma, faqat shuni o'zgartir" degan amalni octal ifodalay olmaydi. `X` esa aynan rekursiv ishlash uchun o'ylab topilgan, chunki papka va fayl uchun `x` ning ma'nosi boshqa-boshqa.

## 3. umask

### Bu nima

Yangi fayl qanday rejim bilan tug'iladi? Dastur fayl yaratayotganda kernel'dan rejim so'raydi (odatda fayl uchun `666`, papka uchun `777`), kernel esa undan jarayonning **umask** qiymatidagi bitlarni olib tashlaydi. umask bu "yangi fayllarga hech qachon berilmaydigan bitlar" ro'yxati, har jarayonning o'z xususiyati.

### Mexanizm

Formula: `natija = so'ralgan & ~umask` (bitli amal: umask'da yoqilgan bit natijada o'chadi). Bu ayirish emas, mask: `666` va umask `027` da natija `640` bo'ladi, `639` emas. Bitlar bilan: `110 110 110` dan `000 010 111` dagi bitlar o'chiriladi, qoladi `110 100 000`. umask faqat olib tashlaydi, hech qachon qo'shmaydi: fayl `x` bilan yaratilmaydi, chunki dastur `666` so'ragan.

| umask | Yangi fayl | Yangi papka | Qayerda uchraydi |
|-------|-----------|-------------|------------------|
| `022` | `644` | `755` | root va servislar uchun standart |
| `002` | `664` | `775` | Ubuntu'da oddiy foydalanuvchi (shaxsiy guruh bilan) |
| `027` | `640` | `750` | qattiqlashtirilgan serverlar |
| `077` | `600` | `700` | secret'lar bilan ishlash |

### Misol

```
ubuntu@lab:~/demo$ umask
0002
ubuntu@lab:~/demo$ touch notes.txt && mkdir box
ubuntu@lab:~/demo$ stat -c '%A %a %U %G %n' notes.txt box
-rw-rw-r-- 664 ubuntu ubuntu notes.txt
drwxrwxr-x 775 ubuntu ubuntu box
ubuntu@lab:~/demo$ (umask 027; touch f27; mkdir d27; stat -c '%a %n' f27 d27)
640 f27
750 d27
```

`umask` `0002` qaytardi (birinchi `0` maxsus bitlar o'rni, 5-bo'lim): faqat other'ning `w` biti olib tashlanadi. Shuning uchun fayl `664`, papka `775`. Uchinchi buyruq qavs ichida, ya'ni subshell'da (5-dars): umask u yerda `027` ga o'zgartirildi, natija `640` va `750`, tashqaridagi shell'ning umask'i esa o'zgarmadi. umask bolalarga meros bo'ladi, lekin boladagi o'zgarish otaga qaytmaydi.

VM'da `ubuntu` uchun `002`, root uchun `022`. Sabab: Ubuntu'da har foydalanuvchiga o'zi bilan bir nomli shaxsiy guruh beriladi (`ubuntu:ubuntu`), bu guruhda undan boshqa hech kim yo'q, demak guruhga `w` berish xavfsiz. Qiymat `/etc/login.defs` dagi `UMASK 022` va `USERGROUPS_ENAB yes` dan keladi: login paytida PAM moduli `pam_umask` shaxsiy guruhli foydalanuvchi uchun `022` ni `002` ga yumshatadi. PAM bu login jarayonidagi tekshiruv va sozlash modullari tizimi (10-darsda).

Yana ikki fakt: `umask -S` qiymatni simvolik ko'rsatadi (`u=rwx,g=rwx,o=rx`, bu qoladigan bitlar); `chmod` octal bilan umask'ga qaramaydi, `cp` va `tar` esa manba rejimiga umask qo'llaydi (`-p` yoki `-a` bo'lmasa).

macOS host'ida standart umask `022`, shuning uchun u yerda yaratilgan fayl `644` bo'ladi. Bu VM bilan farq, xato emas.

### Real ishda qachon kerak

- Servis yaratayotgan loglar yoki socket'lar "nima uchun guruhga yopiq" degan savolda: systemd unit'ida `UMask=` (11-dars).
- Secret yozadigan skriptda: faylni yaratib keyin `chmod 600` qilish o'rniga oldindan `umask 077`, shunda fayl bir lahza ham ochiq turmaydi.
- Jamoaviy papkada "hamkasbim yarata oladi, men yoza olmayman": uning umask'i `022` (4 va 5-bo'limlar).

### Nima uchun shunday

Rejimni har dastur o'zi tanlasa, xavfsizlik siyosati yuzlab dasturga sochilib ketardi. umask qarorni bir joyga, muhitga chiqaradi: dastur "men uchun `666` bo'lsa ham mayli" deydi, administrator esa umask bilan "bu tizimda other'ga yozish yo'q" deydi. U faqat olib tashlagani uchun dastur administrator xohlaganidan ko'proq ruxsat bera olmaydi. Node'da ham bu ko'rinadi: `fs.writeFile` standart `0o666` so'raydi va natija `process.umask()` ga bog'liq, bu o'sha kernel mexanizmi.

## 4. chown va chgrp

### Bu nima

`chown` (change owner) faylning egasi va guruhini, `chgrp` faqat guruhini o'zgartiradi.

```
sudo chown alice file            # owner
sudo chown alice:devs file       # owner and group
sudo chown :devs file            # group only (same as chgrp devs file)
sudo chown -R www-data:www-data /var/www/app
sudo chown --reference=a.txt b.txt
```

### Mexanizm: kim nimani o'zgartira oladi

- Egani faqat root o'zgartira oladi. Oddiy foydalanuvchi faylini boshqaga "sovg'a" qila olmaydi:

```
ubuntu@lab:~/demo$ chown root notes.txt
chown: changing ownership of 'notes.txt': Operation not permitted
```

Xato `Permission denied` emas, `Operation not permitted`: birinchisi "rejim bitlari ruxsat bermadi", ikkinchisi "bu amalning o'zi sizga taqiqlangan" degani. Sabab: sovg'a qilish mumkin bo'lsa, disk kvotasini (foydalanuvchi boshiga joy cheklovi) chetlab o'tish va birovning nomidan setuid fayl yasash mumkin bo'lardi (5-bo'lim).

- Fayl egasi guruhni o'zi a'zo bo'lgan guruhlardan biriga o'zgartira oladi, boshqasiga yo'q.
- Kernel nom emas, raqam (UID, GID) saqlaydi. Nomlar `/etc/passwd` va `/etc/group` fayllari orqali ko'rsatiladi, xolos. `ls -n` har doim raqam ko'rsatadi:

```
ubuntu@lab:~/demo$ ls -n notes.txt
-rw-rw-r-- 1 1000 1000 0 <sana> notes.txt
```

`1000 1000` bu `ubuntu` foydalanuvchisi va `ubuntu` guruhining raqamlari. Diskni boshqa serverga yoki volume'ni boshqa konteynerga ulasangiz, o'sha raqam boshqa nomga to'g'ri kelishi yoki umuman nomsiz chiqishi mumkin (`ls -l` da nom o'rnida raqam ko'rinadi).

### Real ishda qachon kerak

- Deploy'dan keyin fayllarni servis foydalanuvchisiga berish: `sudo chown -R www-data:www-data /var/www/app`.
- Docker volume muammolari: konteyner ichidagi `node` foydalanuvchisi (UID 1000) host'dagi UID 1000 bilan bir xil raqam, nomi boshqa bo'lsa ham kernel uchun bitta ega. Raqamlar mos kelmasa "Permission denied". Docker modulida shu mexanizm qayta uchraydi.
- `sudo` bilan yaratilgan fayllar root'niki bo'lib qoladi va keyin oddiy foydalanuvchi ularni o'zgartira olmaydi; `npm` ni `sudo` bilan ishlatgandan keyingi `EACCES` xatosi aynan shu.

**Tuzoq: `chown -R` noto'g'ri yo'lga.** `sudo chown -R user /usr` yoki bo'sh o'zgaruvchi bilan `sudo chown -R user "$DIR"/` dan keyin setuid dasturlar va `sudo` buziladi, tiklash qayta o'rnatishdan qiyin. Rekursiv buyruqdan oldin yo'lni `echo` bilan tekshiring.

### Nima uchun shunday

Raqam saqlanishi fayl tizimini foydalanuvchilar bazasidan mustaqil qiladi: disk formati nomlar haqida hech narsa bilmaydi, nomlar esa fayl, LDAP yoki boshqa manbadan kelishi mumkin. Egani faqat root o'zgartirishi "fayl kimniki bo'lsa, o'sha javobgar" degan tamoyilni saqlaydi. Muqobil yondashuv (egasi faylni xohlagan kishiga bera olishi) eski Unix variantlarida bo'lgan va xavfsizlik sababli tashlab ketilgan.

## 5. Maxsus bitlar

### Bu nima

Rejimda 9 bitdan tashqari yana uchta bit bor, ular to'rtinchi (eng chapdagi) octal raqamni tashkil qiladi:

| Bit | Octal | Faylda | Papkada | `ls -l` da |
|-----|-------|--------|---------|------------|
| setuid | `4000` | dastur fayl **egasi** huquqi bilan ishlaydi | ta'sir qilmaydi | user `x` o'rnida `s` |
| setgid | `2000` | dastur fayl **guruhi** huquqi bilan ishlaydi | yangi fayllar papka guruhini oladi, yangi papkalar setgid'ni ham | group `x` o'rnida `s` |
| sticky | `1000` | ta'sir qilmaydi | faylni faqat egasi (yoki papka egasi, root) o'chira oladi | other `x` o'rnida `t` |

### Misol

```
ubuntu@lab:~$ ls -l /usr/bin/passwd
-rwsr-xr-x 1 root root 64152 <sana> /usr/bin/passwd
ubuntu@lab:~$ ls -ld /tmp
drwxrwxrwt <N> root root 4096 <sana> /tmp
ubuntu@lab:~$ stat -c '%a %n' /usr/bin/passwd /tmp
4755 /usr/bin/passwd
1777 /tmp
```

Birinchi qator: user sinfida `rws`, `x` o'rnida `s` turibdi, bu setuid. Ega `root`, demak `passwd` ni kim ishga tushirsa ham jarayon root huquqi bilan ishlaydi. Ikkinchi qator: other sinfida `rwt`, bu sticky: `/tmp` ga hamma yoza oladi (`777`), lekin birovning faylini o'chira olmaydi. `stat` to'rt xonali octalni ko'rsatadi: `4755` va `1777`.

### Mexanizm

- **setuid.** Odatda jarayon uni ishga tushirgan foydalanuvchi huquqi bilan ishlaydi. setuid bitli binary'da kernel jarayonning effective UID'ini fayl egasiga almashtiradi. `passwd` parolni `/etc/shadow` ga yozishi kerak, u faylga esa faqat root yoza oladi; setuid shu bitta dasturga shu bitta ish uchun root huquqini beradi. `sudo` ham shunday ishlaydi. Har setuid root dastur potensial privilege escalation (oddiy foydalanuvchidan root'ga ko'tarilish) yo'li, shuning uchun ular kam va auditda tekshiriladi: `find / -perm -4000 -type f 2>/dev/null`.
- Linux setuid'ni skriptlarda (shebang'li fayllarda) e'tiborsiz qoldiradi, u faqat binary'da ishlaydi. `cp` setuid bitni nusxaga ko'chirmaydi.
- **setgid papka** jamoaviy papkalar uchun. Odatda yangi fayl yaratuvchining asosiy guruhini oladi (`alice:alice`), hamkasbi unga guruh orqali yeta olmaydi. setgid papkada yangi fayl papkaning guruhini (`devs`) meros oladi. O'rnatish: `chmod 2775 papka` yoki `chmod g+s papka`.
- **sticky** hamma yoza oladigan papkalarda 1-bo'limdagi "o'chirish papkaning `w` siga bog'liq" qoidasini cheklaydi: o'chirish uchun fayl egasi bo'lish ham kerak.
- Katta `S` yoki `T`: maxsus bit bor, lekin ostidagi `x` yo'q (masalan `chmod 4644` dan keyin `-rwSr--r--`). Odatda xato sozlama belgisi.

### Rejimdan tashqari mexanizmlar

Rejim to'g'ri, lekin baribir `Permission denied` bo'lsa, navbat bilan tekshiriladi: ACL (`ls -l` da rejim oxirida `+`; ko'rish `getfacl fayl`, `acl` paketidan), o'zgarmas atribut (`lsattr fayl` da `i`), fayl tizimi faqat o'qish uchun yoki `noexec` bilan mount qilingan (`findmnt -T fayl`), AppArmor yoki SELinux siyosati (loglarda `denied`). Bular keyingi darslar va modullarda.

### Real ishda qachon kerak

- Jamoa yoki bir necha servis yozadigan umumiy papka (`/srv/shared`, deploy papkasi): setgid va mos umask.
- Xavfsizlik auditi: kutilmagan setuid fayl (ayniqsa `/tmp` yoki `/home` da) buzilish belgisi.
- Kubernetes'da `securityContext.allowPrivilegeEscalation: false` aynan setuid orqali ko'tarilishni taqiqlaydi.

### Nima uchun shunday

setuid Unix'ning "oddiy foydalanuvchi ba'zan imtiyozli ish qilishi kerak" muammosiga eng erta yechimi: imtiyoz foydalanuvchiga emas, sinchiklab yozilgan bitta dasturga beriladi. Narxi: o'sha dasturdagi har xato butun tizimga yo'l ochadi. Zamonaviy muqobillar torroq: capabilities (root huquqini bo'laklarga ajratish), `sudo` qoidalari, alohida servis orqali ishlash. setgid papka va sticky bit esa "papka = oddiy jadval" modelining ikki noqulayligini (guruh merosi yo'qligi, hamma o'chira olishi) minimal vosita bilan tuzatadi.

## 6. Hard va soft linklar

### Bu nima

Fayl nomi va fayl ma'lumoti alohida narsalar. Ma'lumot va metadata inode'da, papka esa nomlarni inode raqamlariga bog'laydi. **Hard link** bu o'sha inode'ga yana bir nom. **Symlink** (symbolic link, soft link) bu ichida boshqa faylning yo'li yozilgan alohida kichik fayl, Windows'dagi shortcut'ga yaqin. `npm` `node_modules/.bin/` ichida aynan symlink'lar yaratadi: `node_modules/.bin/tsc -> ../typescript/bin/tsc`.

| | Hard link (`ln a b`) | Symlink (`ln -s a b`) |
|---|----------------------|------------------------|
| Nima | o'sha inode'ga yana bir nom | ichida yo'l yozilgan alohida kichik fayl |
| inode | bir xil | boshqa |
| Fayl tizimlari orasida | mumkin emas | mumkin |
| Papkaga | mumkin emas | mumkin |
| Asl nom o'chirilsa | ma'lumot qoladi | link "osilib qoladi" (dangling) |
| Ruxsatlar | umumiy (bitta inode) | linkniki ahamiyatsiz (`lrwxrwxrwx`), nishonniki ishlaydi |
| `ls -l` da | farqlab bo'lmaydi, faqat link count > 1 | `l` turi va `-> nishon` |

### Misol

```
ubuntu@lab:~/demo$ echo v1 > data.txt
ubuntu@lab:~/demo$ ln data.txt same.txt
ubuntu@lab:~/demo$ ln -s data.txt ptr.txt
ubuntu@lab:~/demo$ ls -li data.txt same.txt ptr.txt
<inode A> -rw-rw-r-- 2 ubuntu ubuntu 3 <sana> data.txt
<inode B> lrwxrwxrwx 1 ubuntu ubuntu 8 <sana> ptr.txt -> data.txt
<inode A> -rw-rw-r-- 2 ubuntu ubuntu 3 <sana> same.txt
ubuntu@lab:~/demo$ rm data.txt
ubuntu@lab:~/demo$ cat same.txt
v1
ubuntu@lab:~/demo$ cat ptr.txt
cat: ptr.txt: No such file or directory
ubuntu@lab:~/demo$ find . -xtype l
./ptr.txt
```

`ls -li` birinchi ustunda inode raqamini chiqaradi: `data.txt` va `same.txt` da u bir xil, `ptr.txt` da boshqa. Rejimdan keyingi ustun link count: `2`, ya'ni shu inode'ga ikkita nom ko'rsatadi. `ptr.txt` qatori `l` bilan boshlanadi, hajmi `8` bayt, bu ichidagi `data.txt` satrining uzunligi. `rm data.txt` dan keyin `same.txt` mazmuni joyida: bitta nom o'chdi, inode qoldi. Symlink esa endi yo'q nomga ko'rsatadi; xato `ptr.txt` haqida aytilgan, lekin aslida topilmagan narsa nishon. `find . -xtype l` osilib qolgan symlink'larni topadi.

### Mexanizm

- Hard linklar teng huquqli, "asl" va "nusxa" yo'q. Ma'lumot link count 0 ga tushganda **va** faylni ochiq ushlab turgan jarayon qolmaganda bo'shatiladi. O'chirilgan, lekin jarayon ochiq ushlab turgan log fayli diskni egallashda davom etishining sababi shu (`df` to'la deydi, `du` topa olmaydi).
- Hard link boshqa fayl tizimiga o'tolmaydi (`Invalid cross-device link`), chunki inode raqami faqat o'z fayl tizimi ichida ma'noga ega. Papkaga ham mumkin emas (`hard link not allowed for directory`), aks holda daraxtda halqa paydo bo'lardi.
- Symlink ichidagi yo'l oddiy satr. **Nisbiy yo'l linkning o'zi turgan papkadan hisoblanadi**, buyruq berilgan joydan emas. `ln -s` nishon mavjudligini tekshirmaydi:

```
ubuntu@lab:~/demo$ mkdir -p tools/bin tools/share && echo hello > tools/share/msg.txt
ubuntu@lab:~/demo$ ln -s tools/share/msg.txt tools/bin/msg
ubuntu@lab:~/demo$ cat tools/bin/msg
cat: tools/bin/msg: No such file or directory
ubuntu@lab:~/demo$ ln -sfr tools/share/msg.txt tools/bin/msg
ubuntu@lab:~/demo$ readlink tools/bin/msg
../share/msg.txt
```

Birinchi `ln -s` link ichiga `tools/share/msg.txt` satrini yozdi. Link `tools/bin/` da turgani uchun kernel `tools/bin/tools/share/msg.txt` ni qidirdi, u yo'q. `-r` (relative) flag'i GNU `ln` ga to'g'ri nisbiy yo'lni o'zi hisoblatadi: `../share/msg.txt`. `-f` mavjud linkni almashtiradi. `readlink link` ichidagi satrni, `readlink -f link` (yoki `realpath`) barcha linklar ochilgandan keyingi yakuniy absolut yo'lni ko'rsatadi. Bir inode'ning barcha nomlari: `find . -samefile fayl`.

- Papkaga ko'rsatuvchi linkni almashtirishda `-n` kerak:

```
ln -s releases/v2 current        # relative target, resolved from the link's directory
ln -sfn releases/v3 current      # replace the link; -n: do not follow the old link into its target
```

**Tuzoq: `-n` siz `ln -sf`.** `cur` papkaga ko'rsatuvchi symlink bo'lsa, `ln -sf b cur` linkni almashtirmaydi: `ln` `cur` ni papka deb ko'radi va uning **ichida** `b` nomli yangi link yaratadi. Tekshirilgan: `ln -s a cur; ln -sf b cur` dan keyin `find . -type l` ikkita link ko'rsatadi, `./cur` va `./a/b`.

**Tuzoq: oxirgi slash.** `rm link` linkni o'chiradi, nishonga tegmaydi. Lekin `rm -r link/` (slash bilan) nishon papkasining ichini o'chiradi. Tab completion slash'ni o'zi qo'shadi.

### Real ishda qachon kerak

- Deploy: `current -> releases/<versiya>` sxemasi, yangi versiyaga o'tish va rollback bitta linkni almashtirish.
- nginx'ning `sites-enabled` papkasi `sites-available` dagi fayllarga symlink'lardan iborat: saytni yoqish va o'chirish link yaratish va o'chirish.
- Tizimning o'zi: `/bin -> usr/bin`, `/etc/alternatives/editor`, `/etc/localtime`.
- "Disk to'la, lekin katta fayl topilmayapti": o'chirilgan, ammo hali ochiq fayl (9 va 13-darslar).

### Nima uchun shunday

Hard link nom va ma'lumotni ajratishning tabiiy oqibati: papka jadvalida bitta inode'ga ikkita qator yozishga hech narsa to'sqinlik qilmaydi. Uning cheklovlari (bitta fayl tizimi, papkaga mumkin emas) symlink'ni keltirib chiqargan: u inode raqamiga emas, nomga bog'lanadi, shuning uchun istalgan joyga ko'rsata oladi, lekin narxi ham shu, nishon yo'qolsa link buni bilmaydi. Amalda symlink ko'proq ishlatiladi, chunki u ko'rinadi (`ls -l` da `->`) va papkaga ham ishlaydi; hard link asosan joy tejaydigan backup va paket menejerlari ichida (`pnpm` global store'dan `node_modules` ga hard link qiladi).

## 7. Arxivlash va siqish

### Bu nima

Ikki alohida ish: **arxivlash** (ko'p fayl va papkani metadata bilan bitta oqimga yig'ish, `tar`) va **siqish** (bitta oqimni kichraytirish, `gzip`, `xz`, `zstd`). `.tar.gz` bu avval tar, keyin gzip. `zip` ikkalasini birga qiladi. `npm pack` chiqaradigan `.tgz` ham oddiy `tar.gz`, Docker image qatlamlari ham tar arxivlar.

### tar

| Flag | Ma'nosi |
|------|---------|
| `-c`, `-x`, `-t` | yaratish, ochish, ro'yxatini ko'rish (bittasi majburiy) |
| `-f fayl` | arxiv fayli; `-f` dan keyin darhol nom keladi |
| `-z`, `-j`, `-J`, `--zstd` | gzip, bzip2, xz, zstd bilan siqish |
| `-v` | fayllarni chiqarib borish |
| `-C papka` | shu papkaga o'tib ishlash |
| `-p` | ruxsatlarni aynan saqlab ochish (root uchun standart) |
| `--exclude='pattern'` | chiqarib tashlash |
| `--strip-components=N` | ochishda yo'lning birinchi N elementini tashlash |

```
tar -czf site.tar.gz -C /var/www site     # create; paths inside start with "site/"
tar -tzf site.tar.gz | head               # list before extracting
tar -xzf site.tar.gz -C /tmp/restore      # extract into an existing directory
tar -xf site.tar.gz                       # compression is detected automatically on extract
```

### Misol: arxiv ichida nima saqlanadi

2-bo'limdagi `docs` papkasini arxivlaymiz:

```
ubuntu@lab:~/demo$ tar -czf docs.tar.gz docs
ubuntu@lab:~/demo$ tar -tvzf docs.tar.gz
drwxr-xr-x ubuntu/ubuntu     0 <sana> docs/
-rw-r--r-- ubuntu/ubuntu     0 <sana> docs/a.md
drwxr-xr-x ubuntu/ubuntu     0 <sana> docs/img/
-rw-r--r-- ubuntu/ubuntu     0 <sana> docs/img/b.png
ubuntu@lab:~/demo$ tar -cf e.tar /etc/hostname
tar: Removing leading `/' from member names
ubuntu@lab:~/demo$ tar -tf e.tar
etc/hostname
```

`-tvzf`: `t` ro'yxat, `v` batafsil, `z` gzip, `f` fayl nomi. Har qatorda rejim, `ega/guruh`, hajm, vaqt va arxiv ichidagi yo'l. Yo'llar buyruqda qanday berilgan bo'lsa shunday saqlanadi: `docs` deb berildi, hamma yo'l `docs/` dan boshlanadi. Absolut yo'l berilganda tar boshidagi `/` ni olib tashlaydi va ogohlantiradi: arxiv ochilganda fayl `/etc/hostname` ga emas, joriy papkadagi `etc/hostname` ga tushadi. Bu himoya: begona arxiv tizim fayllari ustidan yozib yubormasin.

### Mexanizm: egalik va ochish

- tar ega (nom va raqam), rejim va vaqtlarni saqlaydi. Ochishda egalik faqat root uchun tiklanadi; oddiy foydalanuvchi ochsa hamma fayl uniki bo'ladi (4-bo'lim: oddiy foydalanuvchi `chown` qila olmaydi). Rejimga esa oddiy foydalanuvchida umask qo'llanadi.
- Boshqa mashinada nomlar boshqa UID'ga to'g'ri kelishi mumkin: `--numeric-owner` raqamlarni aynan ishlatadi.
- Symlink'lar link sifatida saqlanadi (nishon mazmuni emas), hard linklar ham saqlanadi.

**Tuzoq: `tar -cfz a.tar.gz dir`.** `-f` dan keyingi so'z fayl nomi, ya'ni arxiv `z` nomli faylga yoziladi va tar `a.tar.gz` ni arxivlanadigan fayl deb qidiradi. `f` har doim flag'lar guruhining oxirida: `-czf`.

**Tuzoq: tarbomb.** Ichida umumiy yuqori papkasi bo'lmagan arxiv joriy papkaga yuzlab fayl sochadi va mavjudlarini ustidan yozadi. Har doim avval `-t` bilan ko'ring va alohida papkaga (`-C`) oching.

### gzip va boshqalar

| Vosita | Kengaytma | Xususiyati |
|--------|-----------|------------|
| `gzip` | `.gz` | tez, hamma joyda bor, o'rtacha siqish; loglar va HTTP uchun standart |
| `bzip2` | `.bz2` | gzip'dan yaxshiroq siqadi, sezilarli sekin; yangi ishlarda kam |
| `xz` | `.xz` | eng kuchli siqish, siqishda sekin va xotira talab qiladi |
| `zstd` | `.zst` | gzip darajasidagi yoki yaxshiroq siqish, ancha tez; zamonaviy tanlov |

```
ubuntu@lab:~/demo$ seq 1 200000 > n.txt && gzip -k n.txt
ubuntu@lab:~/demo$ ls -l n.txt n.txt.gz
-rw-rw-r-- 1 ubuntu ubuntu 1288895 <sana> n.txt
-rw-rw-r-- 1 ubuntu ubuntu  428478 <sana> n.txt.gz
ubuntu@lab:~/demo$ zcat n.txt.gz | tail -1
200000
```

`seq 1 200000` 1 dan 200000 gacha sonlarni yozdi (1.3M atrofida), gzip uni taxminan uch barobar kichraytirdi. `-k` (keep) siz `gzip fayl` asl faylni `fayl.gz` ga **almashtiradi**. Ochish: `gunzip` yoki `gzip -d`. Daraja: `-1` (tez) dan `-9` (kuchli) gacha. `zcat` siqilgan faylni diskka ochmasdan o'qiydi; `zless` va `zgrep` ham shunday. Rotatsiya qilingan loglar (`/var/log/*.gz`) shular bilan o'qiladi. gzip faqat bitta oqimni siqadi, papkani emas, shuning uchun tar bilan birga ishlatiladi. Brauzer tanigan `Content-Encoding: gzip` ham aynan shu algoritm.

### zip

```
zip -r site.zip site/        # -r is required for directories
unzip -l site.zip            # list
unzip site.zip -d /tmp/out   # extract into a directory
```

`zip` Windows va macOS bilan almashish uchun qulay, lekin Unix egaligini tiklamaydi. Serverlar orasidagi backup va deploy uchun tar.

### Real ishda qachon kerak

- Backup va uni tekshirish: `tar -czf`, keyin `tar -tzf` va vaqti-vaqti bilan haqiqiy tiklash sinovi.
- Release artefakti: CI build natijasini `tar.gz` qilib serverga uzatadi, u yerda `releases/<versiya>/` ga ochiladi.
- GitHub'dan binary yuklash: deyarli hammasi `tool_linux_amd64.tar.gz` yoki `..._arm64.tar.gz` ko'rinishida (Zorin'dagi VM uchun `amd64`, Mac'dagi VM uchun `arm64`).
- Eski loglarni o'qish: `zgrep error /var/log/syslog.2.gz`.

### Nima uchun shunday

tar (tape archive) lentaga ketma-ket yozish uchun yaratilgan, shuning uchun u oddiy oqim: boshida mundarija yo'q, ro'yxat uchun ham butun arxiv o'qiladi. Arxivlash va siqishni ajratish Unix'ning "har asbob bitta ish" tamoyili: siqish algoritmini tar'ga tegmasdan almashtirish mumkin (gzip, keyin xz, endi zstd). zip teskari yo'lni tanlagan: har fayl alohida siqiladi va oxirida mundarija bor, shuning uchun bitta faylni tez sug'urib olish mumkin, lekin umumiy siqish yomonroq va Unix metadata'si to'liq emas.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Mode (rejim) | faylning ruxsat bitlari: 9 ta asosiy va 3 ta maxsus bit |
| UID, GID | foydalanuvchi va guruhning raqami; kernel nomni emas shu raqamni saqlaydi |
| Owner, group, other | ruxsat tekshiriladigan uch sinf: ega, fayl guruhi a'zolari, qolgan hamma |
| `r`, `w`, `x` | o'qish, yozish, bajarish; papkada ro'yxat, jadvalni o'zgartirish, ichiga kirish |
| Octal | rejimning raqamli yozuvi, har sinf bitta raqam (`r`=4, `w`=2, `x`=1) |
| umask | yangi fayl rejimidan olib tashlanadigan bitlar, jarayon xususiyati |
| Shaxsiy guruh | Ubuntu'da har foydalanuvchiga beriladigan o'zi bilan bir nomli guruh |
| `chown`, `chgrp` | ega va guruhni o'zgartiradigan buyruqlar |
| setuid | binary'ni fayl egasi huquqi bilan ishga tushiradigan bit (`4000`) |
| setgid | faylda guruh huquqi bilan ishga tushirish, papkada guruhni meros qilish (`2000`) |
| Sticky bit | papkada faylni faqat egasi o'chira olishini ta'minlaydigan bit (`1000`) |
| Privilege escalation | oddiy foydalanuvchidan yuqoriroq huquqqa (odatda root) ko'tarilish |
| ACL | 9 bitga qo'shimcha, alohida foydalanuvchi va guruhlar uchun ruxsat yozuvlari |
| Inode | fayl metadata'si va ma'lumot joylashuvini saqlaydigan yozuv, nomi yo'q |
| Link count | bitta inode'ga nechta nom (hard link) ko'rsatayotgani |
| Hard link | mavjud inode'ga qo'shimcha nom |
| Symlink | ichida boshqa faylning yo'li yozilgan alohida fayl |
| Dangling link | nishoni yo'q symlink |
| Arxiv | ko'p fayl va ularning metadata'si yig'ilgan bitta fayl (`.tar`) |
| Siqish | ma'lumotni kichraytirish (`gzip`, `xz`, `zstd`), arxivlashdan alohida ish |
| Tarbomb | umumiy yuqori papkasiz arxiv, ochilganda joriy papkaga fayl sochadi |
| Snapshot | VM diskining saqlangan holati, unga qaytish mumkin |

## Tuzoqlar

- `chmod 777` va `chmod -R 777`. Sababni topish o'rniga himoyani o'chirish. Audit va xavfsizlik skanerlarida birinchi topiladigan narsa.
- `chmod -R` va `chown -R` ni noto'g'ri yo'lga berish (`/`, `..`, bo'sh o'zgaruvchi). `chown -R user /usr` dan keyin setuid dasturlar va `sudo` buziladi.
- `chmod -R 644 papka`: papkalardan `x` olinadi va ichiga kirib bo'lmay qoladi. `X` yoki `find -type d` va `-type f`.
- Secret fayllar (`.env`, kalitlar) `644` yoki `664` bilan: serverdagi har foydalanuvchi va har buzilgan servis o'qiydi. `600` va to'g'ri ega.
- Guruhga qo'shilgandan keyin sessiyani yangilamaslik: `usermod -aG docker user` dan keyin qayta login qilinmaguncha huquq yo'q.
- Faqat faylning rejimiga qarash. Yo'ldagi papkalardan birida `x` yo'qligi, ACL, `noexec` mount, AppArmor ham sabab bo'lishi mumkin. `namei -l`.
- Volume yoki backup'ni boshqa tizimda ochganda nomga ishonish. Egalik raqam bilan saqlanadi.
- `ln -sf` da `-n` ni unutish, va symlink'ni oxirgi slash bilan o'chirish.
- Nisbiy symlink'ni boshqa papkaga ko'chirish yoki noto'g'ri papkadan turib yaratish: link osilib qoladi.
- Backup'ni tekshirmaslik. Ochib ko'rilmagan arxiv backup emas.
- Arxivni oddiy foydalanuvchi sifatida ochib, egalik tiklandi deb o'ylash; yoki noma'lum manbadan kelgan arxivni ko'rmasdan root sifatida `/` da ochish.
- Host'da sinash: Zorin host'ida umask va guruhlar boshqa bo'lishi mumkin, macOS'da `stat -c` va `ln -r` ishlamaydi (BSD variantlari). Javoblar faqat `lab` VM'dan.

## Manbalar

- https://man7.org/linux/man-pages/man7/path_resolution.7.html : `path_resolution(7)`, ruxsat tekshiruvi qadamlari
- https://man7.org/linux/man-pages/man7/inode.7.html : `inode(7)`, rejim bitlari va vaqtlar
- https://man7.org/linux/man-pages/man2/umask.2.html : `umask(2)`
- https://man7.org/linux/man-pages/man2/chown.2.html : `chown(2)`, kim nimani o'zgartira oladi
- https://man7.org/linux/man-pages/man7/symlink.7.html : `symlink(7)`
- https://man7.org/linux/man-pages/man1/namei.1.html : `namei(1)`
- https://www.gnu.org/software/coreutils/manual/coreutils.html#File-permissions : GNU coreutils, File permissions
- https://www.gnu.org/software/coreutils/manual/coreutils.html#ln-invocation : `ln`
- https://www.gnu.org/software/tar/manual/tar.html : GNU tar qo'llanmasi
- https://www.gnu.org/software/gzip/manual/gzip.html : GNU gzip
- https://facebook.github.io/zstd/ : Zstandard
- Kerrisk, "The Linux Programming Interface": 15 bob (File Attributes), 18 bob (Directories and Links)
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php): 9 va 18 boblar

---

## Birga bajaramiz

Kichik `report` loyihasini noldan yig'amiz va yo'lda darsdagi hamma narsani ko'ramiz: umask, `x` biti, secret fayl, yo'ldagi to'siq, linklar, arxiv va tiklash. Hamma narsa VM ichida, `~/walk` papkasida; vazifalardagi `~/files` ga tegmaydi.

1. Papka va fayllarni yarating, ular qanday rejim bilan tug'ilganini ko'ring:

```
ubuntu@lab:~$ mkdir -p ~/walk/report/bin && cd ~/walk
ubuntu@lab:~/walk$ printf '#!/bin/bash\necho report ok\n' > report/bin/hello.sh
ubuntu@lab:~/walk$ echo token=abc123 > report/token.txt && echo a,b > report/data.csv
ubuntu@lab:~/walk$ stat -c '%A %a %U %G %n' report report/bin/hello.sh report/token.txt
drwxrwxr-x 775 ubuntu ubuntu report
-rw-rw-r-- 664 ubuntu ubuntu report/bin/hello.sh
-rw-rw-r-- 664 ubuntu ubuntu report/token.txt
```

Papka `775`, fayllar `664`: so'ralgan `777` va `666` dan umask `002` olib tashlangan (3-bo'lim). Skriptda `x` yo'q, secret esa other'ga o'qishga ochiq. Ikkalasi ham muammo.

2. Skriptni ishga tushiring:

```
ubuntu@lab:~/walk$ ./report/bin/hello.sh
-bash: ./report/bin/hello.sh: Permission denied
ubuntu@lab:~/walk$ bash report/bin/hello.sh
report ok
ubuntu@lab:~/walk$ chmod u+x report/bin/hello.sh && ./report/bin/hello.sh
report ok
ubuntu@lab:~/walk$ stat -c '%A %a' report/bin/hello.sh
-rwxrw-r-- 764
```

Birinchi urinish: kernel faylni dastur sifatida ishga tushirishdan bosh tortdi, `x` yo'q. Ikkinchisi ishladi, chunki u yerda bajarilayotgan dastur `bash`, skript esa unga oddiy o'qiladigan fayl: `r` yetarli. `chmod u+x` faqat egaga `x` qo'shdi, qolgan bitlarga tegmadi: `664` dan `764`.

3. Secret'ni boshqa foydalanuvchi o'qiy oladimi? `nobody` tizimdagi hech narsaga ega bo'lmagan maxsus foydalanuvchi, "other" sinfini sinash uchun qulay:

```
ubuntu@lab:~/walk$ sudo -u nobody cat /home/ubuntu/walk/report/data.csv
cat: /home/ubuntu/walk/report/data.csv: Permission denied
ubuntu@lab:~/walk$ namei -l /home/ubuntu/walk/report/data.csv
f: /home/ubuntu/walk/report/data.csv
drwxr-xr-x root   root   /
drwxr-xr-x root   root   home
drwxr-x--- ubuntu ubuntu ubuntu
drwxrwxr-x ubuntu ubuntu walk
drwxrwxr-x ubuntu ubuntu report
-rw-rw-r-- ubuntu ubuntu data.csv
```

Fayl `664`, other uchun `r` bor, lekin o'qib bo'lmadi. `namei -l` sababni ko'rsatadi: `/home/ubuntu` rejimi `750`, other uchun `x` yo'q, `nobody` uchinchi qatordan o'ta olmaydi. Demak `token.txt` ham hozircha himoyalangan, lekin faqat tasodifan: papka boshqa joyga ko'chirilsa yoki arxivlab uzatilsa `664` ochilib qoladi. Secret'ning o'zini yoping:

```
ubuntu@lab:~/walk$ chmod 600 report/token.txt
ubuntu@lab:~/walk$ (umask 077; echo t2 > report/token2.txt; stat -c '%a %n' report/token2.txt)
600 report/token2.txt
```

Ikkinchi qator to'g'riroq usulni ko'rsatadi: subshell'da `umask 077` bilan fayl birdaniga `600` bo'lib tug'iladi, yaratish va `chmod` orasida ochiq turadigan lahza yo'q.

4. Linklar. Ma'lumot fayliga hard link, skriptga qulay nom sifatida symlink:

```
ubuntu@lab:~/walk$ ln report/data.csv report/data-copy.csv
ubuntu@lab:~/walk$ stat -c '%h %n' report/data.csv
2 report/data.csv
ubuntu@lab:~/walk$ ln -s report/bin/hello.sh hello
ubuntu@lab:~/walk$ ls -l hello
lrwxrwxrwx 1 ubuntu ubuntu 19 <sana> hello -> report/bin/hello.sh
ubuntu@lab:~/walk$ ./hello
report ok
```

`%h` link count: `2`, ya'ni `data.csv` va `data-copy.csv` bitta inode'ning ikki nomi. Symlink ichidagi nisbiy yo'l `report/bin/hello.sh` to'g'ri ishladi, chunki link `~/walk` da turibdi va yo'l aynan shu papkadan hisoblanadi (6-bo'limdagi `tools/bin/msg` misoli bilan solishtiring: u yerda link boshqa papkada edi). `19` bu satr uzunligi.

5. Arxivlang va ichiga qarang:

```
ubuntu@lab:~/walk$ tar -czf report.tar.gz report
ubuntu@lab:~/walk$ tar -tvzf report.tar.gz
drwxrwxr-x ubuntu/ubuntu 0 <sana> report/
-rw-rw-r-- ubuntu/ubuntu 4 <sana> report/data.csv
-rw------- ubuntu/ubuntu 3 <sana> report/token2.txt
hrw-rw-r-- ubuntu/ubuntu 0 <sana> report/data-copy.csv link to report/data.csv
-rw------- ubuntu/ubuntu 13 <sana> report/token.txt
drwxrwxr-x ubuntu/ubuntu 0 <sana> report/bin/
-rwxrw-r-- ubuntu/ubuntu 27 <sana> report/bin/hello.sh
ubuntu@lab:~/walk$ stat -c '%a %n' report.tar.gz
664 report.tar.gz
```

Arxiv har faylning rejimi va egasini saqlagan. `data-copy.csv` qatori `h` bilan boshlanadi va hajmi `0`: tar uni ikkinchi nusxa qilib emas, "`report/data.csv` ga hard link" deb yozgan. Qatorlar tartibi sizda boshqacha bo'lishi mumkin. Muhim kuzatuv: ichidagi secret `600`, lekin arxivning o'zi `664`. Secret'li arxiv ham secret, uning rejimi alohida o'rnatilishi kerak.

6. Boshqa joyga oching va solishtiring:

```
ubuntu@lab:~/walk$ mkdir /tmp/walk-restore && tar -xzf report.tar.gz -C /tmp/walk-restore
ubuntu@lab:~/walk$ diff -r report /tmp/walk-restore/report && echo same
same
ubuntu@lab:~/walk$ stat -c '%a %h %n' /tmp/walk-restore/report/token.txt /tmp/walk-restore/report/data.csv
600 1 /tmp/walk-restore/report/token.txt
664 2 /tmp/walk-restore/report/data.csv
```

`diff -r` ikki papkani rekursiv solishtiradi, hech narsa chiqarmasa mazmun bir xil. Rejim (`600`) va hard link (link count `2`) tiklangan. `hello` symlink'i arxivga kirmagan, chunki u `report/` dan tashqarida edi: arxiv faqat berilgan yo'l ostidagini oladi.

7. Tozalash: `rm -r ~/walk /tmp/walk-restore`.

Bu yurishda egalik o'zgarmadi (hamma narsa `ubuntu`niki). Boshqa foydalanuvchilar, setgid papka va root sifatida ochish vazifalarda.

## Vazifalar

Ish papkasi: `linux/06-files/` (`make new m=linux n=06 name=files` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Skript (`task_22.sh`) shu papkaga saqlanadi; uni VM'da sinash uchun `multipass transfer task_22.sh lab:` bilan ko'chiring. Vazifalar `lab` VM'da, `~/files` ichida (boshqasi aytilmagan bo'lsa). Har tajribada avval natijani taxmin qilib yozing, keyin bajaring.

### A. Ruxsatlar

1. **Reading modes.** `stat -c '%A %a %U %G %n'` ni `/etc/passwd`, `/etc/shadow`, `/usr/bin/passwd`, `/tmp`, `/home/ubuntu`, `~/.ssh`, `~/.ssh/authorized_keys` uchun bajaring. Har biri uchun: kim o'qiy oladi, kim yoza oladi, rejim nima uchun aynan shunday tanlangan? `id` chiqishiga qarab, `ubuntu` foydalanuvchisi `/etc/shadow` ni o'qiy oladimi (sinab ko'ring)? Yo'nalish: 1-bo'lim "Misol: rejimni o'qish", 5-bo'lim.

2. **Octal and symbolic.** Jadvalni to'ldiring (octal, `rwx` ko'rinishi, simvolik `chmod` buyrug'i): `640`, `750`, `rw-rw-r--`, `u=rwx,g=rx,o=`, `600`, `rwx--x--x`. Har birini bitta faylga octal bilan, ikkinchisiga simvolik bilan qo'llab, `stat -c %a` bir xil ekanini ko'rsating. `chmod +x fayl` va `chmod a+x fayl` har doim bir xilmi (`umask 027` bilan sinang)? Yo'nalish: 2-bo'lim; `man chmod` da "who" ko'rsatilmagan holat haqidagi jumlani toping.

3. **Directory bits.** `d/` papkasida `f.txt` yarating. Papka rejimini navbat bilan `r--`, `--x`, `-wx`, `rw-` (faqat user uchun, masalan `400`, `100`, `300`, `600`) qilib, har birida sinang: `ls d`, `ls -l d`, `cat d/f.txt`, `touch d/new`, `rm d/f.txt`, `cd d`. Natijalarni jadvalga yozing (ishladi yoki xato matni). Jadvaldan papka uchun `r`, `w`, `x` ma'nosini o'z so'zingiz bilan chiqaring. Yo'nalish: 1-bo'lim "rwx: fayl va papka" va `vault` misoli.

4. **Delete without write.** `~/files/own/` papkasida `sudo touch root.txt && sudo chmod 444 root.txt` qiling. `ubuntu` sifatida: faylga yozishga urinib ko'ring, keyin `rm root.txt` qiling. Nima uchun yozib bo'lmadi, lekin o'chirib bo'ldi? Faylni o'chirishdan himoya qilish uchun nimaning ruxsati o'zgarishi kerak? Yo'nalish: 1-bo'lim, papka jadval ekani.

5. **First match wins.** Fayl yarating va `chmod 047` qiling. Egasi sifatida `cat` qiling, keyin `sudo -u bob cat` (fayl bob yeta oladigan joyda bo'lsin, masalan `/tmp`). Kim o'qiy oldi? Tekshiruv algoritmining qaysi qadami buni tushuntiradi? Ega bu holatdan o'zi chiqa oladimi va nima uchun? Yo'nalish: 1-bo'lim "Mexanizm: tekshiruv algoritmi". `bob` hali yo'q bo'lsa, Laboratoriya bo'limidagi buyruqlar bilan yarating.

6. **Path traversal.** `/tmp/p/a/b/secret.txt` ni yarating, fayl rejimi `644`. `chmod 700 /tmp/p/a` qiling va `sudo -u bob cat /tmp/p/a/b/secret.txt` ni sinang. `namei -l /tmp/p/a/b/secret.txt` chiqishida to'siq qayerda ekanini ko'rsating. Bobga faylni o'qishga imkon beradigan, lekin `a` ichidagi nomlar ro'yxatini ko'rsatmaydigan eng kichik o'zgarishni toping. Yo'nalish: 1-bo'lim `namei` misoli va papkadagi `r` bilan `x` farqi.

7. **umask.** `umask` va `umask -S` qiymatini yozing. `022`, `027`, `077` har biri uchun avval natijani hisoblang (bitlar bilan), keyin subshell ichida sinang: `(umask 027; touch f; mkdir d; stat -c '%a %n' f d)`. Nima uchun `umask 000` bilan ham fayl `666`, `777` emas? VM'da standart umask qayerdan kelganini toping (`grep -E '^UMASK|USERGROUPS_ENAB' /etc/login.defs`). `sudo -i` ichidagi umask bilan solishtiring. Yo'nalish: 3-bo'lim; `man pam_umask`.

8. **Recursive chmod trap.** `mkdir -p site/{css,js} && touch site/index.html site/css/a.css site/js/a.js` yarating. `chmod -R 644 site` qiling va `ls site/css`, `cat site/index.html` ni sinang, xatoni izohlang. Ikki usulda tuzating: `find` bilan (papkalar `755`, fayllar `644`) va bitta simvolik `chmod -R` bilan (`X`). `X` va `x` farqini ko'rsating. Yo'nalish: 2-bo'lim "Misol: rekursiv chmod tuzog'i".

### B. Egalik va maxsus bitlar

9. **chown rules.** Laboratoriya bo'limidagi buyruqlar bilan `alice`, `bob`, `devs` ni yarating. `ubuntu` sifatida o'z faylingizni `sudo` siz `chown alice` qilib ko'ring, xatoni yozing va nima uchun kernel buni taqiqlashini izohlang. `sudo -iu alice` ichida: fayl yarating, `chgrp devs` (ishlaydi) va `chgrp sudo` (ishlamaydi) ni sinang. `id alice` va alice sessiyasi ichidagi `id` bir xilmi? Yo'nalish: 4-bo'lim "Mexanizm".

10. **Shared directory.** `sudo mkdir /srv/devs && sudo chown root:devs /srv/devs && sudo chmod 775 /srv/devs` qiling. alice fayl yaratsin, bob unga yozib ko'rsin. Faylning guruhi nima va bob nima uchun yoza olmadi (yoki oldi)? Endi `sudo chmod 2775 /srv/devs` qiling, alice yangi fayl va papka yaratsin: guruh va rejimni oldingi fayl bilan solishtiring. Bu sxema ishlashi uchun umask qanday bo'lishi kerak (alice sessiyasida `umask 022` bilan sinang)? Yo'nalish: 5-bo'lim setgid papka, 3-bo'lim jadvali.

11. **Sticky bit.** `sudo mkdir /srv/drop && sudo chmod 777 /srv/drop` qiling. alice fayl yaratsin, bob uni o'chirsin: bo'ldimi? `sudo chmod 1777 /srv/drop` dan keyin takrorlang va xato matnini yozing. `ls -ld /srv/drop /tmp` dagi belgini ko'rsating. `chmod 1776` da `ls -ld` nima ko'rsatadi va bu nimani anglatadi? Yo'nalish: 5-bo'lim, sticky va katta `T`.

12. **setuid audit.** `find / -perm -4000 -type f 2>/dev/null` va `-perm -2000` natijasini oling. Uchta setuid dasturni tanlab, har biri nima uchun root huquqiga muhtojligini yozing. `cp /usr/bin/passwd ~/files/` qiling va rejimni asl bilan solishtiring: bit qayerga ketdi va nima uchun bu to'g'ri xatti-harakat? `-perm -4000` va `-perm 4000` farqi nima? Yo'nalish: 5-bo'lim; `man find` da `-perm` ning uch shakli.

### C. Linklar

13. **Hard link.** `a.txt` yarating, `ln a.txt b.txt` qiling. `ls -li` dagi inode va link count ni yozing. `b.txt` orqali mazmunni o'zgartiring, `chmod 600 b.txt` qiling va `a.txt` ni tekshiring. `rm a.txt` dan keyin `b.txt` da nima bor? Keyin sinang va xatolarni yozing: `ln b.txt /dev/shm/c.txt`, `ln ~/files hardlink-to-dir`. Har cheklovning sababi nima? Yo'nalish: 6-bo'lim "Misol" va "Mexanizm"; `/dev/shm` alohida fayl tizimi (`findmnt -T /dev/shm`).

14. **Symlink.** `ln -s b.txt s.txt` yarating. `ls -li`, `readlink s.txt`, `stat s.txt` va `stat -L s.txt` ni solishtiring. `chmod 644 s.txt` nimaning rejimini o'zgartirdi? `b.txt` ni o'chiring: `ls -l s.txt` va `cat s.txt` nima deydi? `find . -xtype l` bilan toping. `b.txt` ni qayta yarating: link "tirildi"mi va bu hard linkdan qanday farq qiladi? Yo'nalish: 6-bo'lim jadvali; `man stat` da `-L`.

15. **Relative symlink trap.** `mkdir -p proj/{bin,lib} && echo hi > proj/lib/tool.sh` yarating. `~/files` da turib `ln -s proj/lib/tool.sh proj/bin/tool` qiling va `cat proj/bin/tool` ni sinang. Xatoni `readlink` va `readlink -f` bilan tushuntiring: yo'l qayerdan hisoblanyapti? Uch usulda to'g'rilang: to'g'ri nisbiy yo'l, absolut yo'l, `ln -sr`. Keyin `proj` ni `/tmp` ga `mv` qiling: qaysi variant ishlashda davom etdi? Yo'nalish: 6-bo'lim `tools/bin/msg` misoli.

16. **Release switch.** `mkdir -p app/releases/{v1,v2,v3}` va har birida `echo vN > VERSION` yarating. `app/current` symlink'ini `v1` ga qarating, `cat app/current/VERSION` bilan tekshiring. `ln -sf releases/v2 current` (`-n` siz) bilan almashtirib ko'ring: nima bo'ldi, `find app -type l` nimani ko'rsatadi? Tozalab, `-sfn` bilan `v2`, keyin `v3` ga o'tkazing, keyin `v2` ga rollback qiling. Bu sxema deploy uchun nima beradi? Yo'nalish: 6-bo'lim "Tuzoq: `-n` siz `ln -sf`".

17. **System links.** `ls -l /bin /sbin /etc/localtime /usr/bin/editor /etc/alternatives/editor` ni bajaring va `readlink -f /usr/bin/editor` bilan zanjirni oxirigacha kuzating. `ls -li /usr/bin | awk '$3 > 1' | head` bilan hard linkli dasturlarni toping va bittasining barcha nomlarini `find /usr/bin -samefile ...` bilan chiqaring. Tizim nima uchun bu yerda nusxa emas link ishlatadi? Yo'nalish: 6-bo'lim "Real ishda qachon kerak"; `awk` 7-darsda, bu yerda tayyor buyruq sifatida.

### D. Arxivlar

18. **tar roundtrip.** 8-vazifadagi `site/` ga symlink va rejimi `600` bo'lgan fayl qo'shing. `site.tar.gz` yarating, `-tvzf` bilan ro'yxatini ko'ring (rejim, ega, symlink qanday ko'rsatilgan?), `/tmp/restore` ga oching va `diff -r site /tmp/restore/site` bilan tekshiring. `--exclude='*.css'` bilan ikkinchi arxiv yarating va ro'yxatini solishtiring. Yo'nalish: 7-bo'lim "Misol: arxiv ichida nima saqlanadi", "Birga bajaramiz" 5–6 qadamlar.

19. **tar pitfalls.** (a) `tar -cfz x.tar.gz site` ni bajaring, xatoni yozing va papkada qanday fayl paydo bo'lganini ko'ring. (b) `tar -cf ssh.tar /etc/ssh` (xatolarga e'tibor bermang) qiling: tar nima deb ogohlantirdi, `tar -tf ssh.tar | head -3` da yo'llar qanday? Uni `/tmp/x` ga ochsangiz fayllar qayerga tushadi? (c) `--strip-components=2` bilan ochib farqni ko'rsating. (d) `-C` bilan arxiv yaratishda yo'llar qanday o'zgarishini ko'rsating. Yo'nalish: 7-bo'lim flag'lar jadvali va ikki tuzoq.

20. **Ownership in archives.** `/srv/devs` ni (alice va bob fayllari bilan) `sudo tar -czf /tmp/devs.tar.gz -C /srv devs` bilan arxivlang. Uni ikki marta oching: `ubuntu` sifatida `~/files/as-user/` ga va `sudo` bilan `/tmp/as-root/` ga. Egalik va setgid bit ikki holatda qanday tiklandi? `tar -tvzf` va `tar --numeric-owner -tvzf` chiqishlarini solishtiring. Xuddi shu papkani `zip -r` bilan arxivlab, `sudo unzip` bilan ochib egalikni tekshiring. Backup uchun xulosa yozing. Yo'nalish: 7-bo'lim "Mexanizm: egalik va ochish", 4-bo'lim (raqam va nom).

21. **Compression compare.** `sudo cat /var/log/syslog > big.log` (fayl kichik bo'lsa bir necha marta o'ziga qo'shib 50M atrofiga yetkazing). `gzip -1`, `gzip -9`, `bzip2`, `xz`, `zstd` har biri uchun `time` bilan siqish vaqtini va natija hajmini jadvalga yozing (har safar asl faylni saqlang: `-k`). Qaysi biri eng kichik, qaysi biri eng tez? Kunlik log rotatsiyasi va oylik arxiv uchun qaysi birini tanlaysiz? `zcat`, `zgrep -c` va `zless` ni `.gz` faylda sinang; `gzip big.log` (`-k` siz) asl fayl bilan nima qildi? Yo'nalish: 7-bo'lim "gzip va boshqalar". Vaqtlar Zorin va Mac'da farq qiladi, bu normal: nisbatlarni solishtiring.

### E. Yakuniy

22. **Backup script.** `task_22.sh <manba-papka> <backup-papka>` yozing: backup papkasini yo'q bo'lsa `700` rejimda yaratadi; manbani `<nom>-YYYYmmdd-HHMMSS.tar.gz` ga arxivlaydi (arxiv ichida yo'llar manba papka nomidan boshlansin, absolut bo'lmasin); arxiv rejimi `600`; yaratilgan arxivni `tar -tzf` bilan tekshiradi va muvaffaqiyatsiz bo'lsa nolga teng bo'lmagan kod bilan tugaydi; `latest` symlink'ini yangi arxivga qaratadi (nisbiy, `-sfn`); faqat oxirgi 3 ta arxivni qoldirib eskilarini o'chiradi. Talablar: `set -euo pipefail`, noto'g'ri argumentlarda usage va `exit 2`, barcha o'zgaruvchilar tirnoqda, shellcheck toza. Sinov: skriptni 5 marta ishga tushirib `ls -l` natijasini, noto'g'ri argument bilan exit code'ni, va `latest` dan `/tmp/verify` ga tiklab `diff -r` natijasini README'ga yozing. Yo'nalish: 3-bo'lim (umask bilan yaratish), 6-bo'lim (nisbiy link qayerdan hisoblanadi), 7-bo'lim (`-C`), 5-darsdagi skript asoslari. Skriptni VM'da (bash, GNU `tar` va `ln`) sinang, host'da emas.

### Topshirish

Tayyor bo'lgach:
1. `linux/06-files/README.md` da 22 ta vazifa `## N. Title` sarlavhalari ostida.
2. Ish papkasida `task_22.sh` bor, shellcheck hech narsa chiqarmaydi.
3. `make check` toza o'tadi (host'da).
4. VM'da: `alice`, `bob`, `devs` o'chirilgan, `/srv/devs`, `/srv/drop`, `/tmp` dagi sinov fayllari, `~/files`, `~/demo` va `~/walk` tozalangan (yoki `multipass restore lab.before-06`).
5. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Kernel faylga ruxsatni qanday tartibda tekshiradi? Rejimi `047` bo'lgan faylni egasi nima uchun o'qiy olmaydi?
- Papkada `r`, `w`, `x` nimani anglatadi? Faylni o'chirish huquqi nimaga bog'liq?
- `umask 027` bilan yaratilgan fayl va papka rejimi qanday bo'ladi va nima uchun bu ayirish emas?
- VM'da `ubuntu` uchun umask nima uchun `002`, root uchun `022`?
- Nima uchun oddiy foydalanuvchi faylini boshqaga `chown` qila olmaydi?
- setuid, setgid (fayl va papkada), sticky bit har biri nima qiladi? Har biriga tizimdan misol keltiring.
- `chmod 777` nima uchun yechim emas va `Permission denied` ni qanday tartibda tekshirasiz?
- Hard link va symlink farqi nima? Fayl ma'lumoti qachon haqiqatan o'chiriladi?
- Nisbiy symlink qayerdan hisoblanadi? `ln -sfn` dagi `-n` nima uchun kerak?
- tar egalikni qanday saqlaydi va qachon tiklaydi? Arxiv ichidagi yo'llar qanday aniqlanadi?
- gzip, xz va zstd orasida qanday tanlaysiz? `tar` va `zip` farqi nima?
