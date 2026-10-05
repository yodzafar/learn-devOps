# 6-dars: Fayllar: ruxsatlar, linklar, arxivlar

Maqsad: Linux'ning fayl ruxsatlari modelini (ega, guruh, boshqalar; `rwx`; octal; `umask`), egalikni o'zgartirishni (`chown`), maxsus bitlarni (setuid, setgid, sticky), hard va soft linklarni hamda arxivlash va siqishni (`tar`, `gzip`, `zip`) mexanizm darajasida tushunish. `Permission denied` ops ishida eng ko'p uchraydigan xato, uni `chmod 777` bilan emas, kernel tekshiruvi qanday ishlashini bilib yechish kerak. Bu dars 3-darsdagi `ls -l` ustunlarini va 5-darsdagi `sudo` ni davom ettiradi; 10-dars (foydalanuvchi va guruhlar), 13-dars (inode va fayl tizimlari), Docker modulidagi volume ruxsatlari va Kubernetes'dagi `securityContext` shu yerdagi modelga tayanadi.

Taxminiy vaqt: 3 kun (siz uchun). E'tiborni quyidagilarga qarating: ruxsat tekshiruvi algoritmi (birinchi mos kelgan sinf hal qiladi), `rwx` ning fayl va papka uchun har xil ma'nosi, o'chirish huquqi papkaga tegishli ekani, `umask` ayirish emas mask ekani, setgid papka, relativ symlink qayerdan hisoblanishi, `tar` da egalik va yo'llar.

## Laboratoriya

- **`lab` VM**: barcha vazifalar. Foydalanuvchi va guruh yaratiladi, `chown` ishlatiladi, shuning uchun ish mashinasida bajarilmaydi. Boshlashdan oldin snapshot:

```
multipass stop lab && multipass snapshot lab --name before-06 && multipass start lab
multipass shell lab
sudo apt update && sudo apt install -y zip unzip zstd
```

- Sinov foydalanuvchilari (B guruhi): `alice`, `bob` va `devs` guruhi. Boshqa foydalanuvchi nomidan buyruq: `sudo -u alice <buyruq>`, shell: `sudo -iu alice`. Foydalanuvchilarni boshqarish 10-darsda chuqur, bu yerda faqat tayyor buyruqlar ishlatiladi:

```
sudo adduser --disabled-password --gecos "" alice
sudo adduser --disabled-password --gecos "" bob
sudo groupadd devs && sudo usermod -aG devs alice && sudo usermod -aG devs bob
```

Tozalash: `sudo deluser --remove-home alice`, `sudo deluser --remove-home bob`, `sudo groupdel devs`, `sudo rm -r /srv/devs /srv/drop`, `rm -r ~/files`. Yoki `multipass restore lab.before-06`.

---

## 1. Ruxsat modeli

Har faylda (aniqrog'i inode'da) uchta narsa saqlanadi: ega (UID), guruh (GID) va rejim (mode) bitlari. Har jarayonda esa: effective UID va guruhlar ro'yxati. Kernel fayl ochilayotganda shularni solishtiradi.

```
stat -c '%A %a %U %G %n' /etc/passwd /etc/shadow
-rw-r--r-- 644 root root   /etc/passwd
-rw-r----- 640 root shadow /etc/shadow
```

Rejim uch sinfga bo'linadi: **u**ser (ega), **g**roup (guruh), **o**ther (boshqalar), har birida `r`, `w`, `x`.

### Tekshiruv algoritmi

1. Jarayon UID'i 0 (root) bo'lsa: ruxsat beriladi (bajarish uchun kamida bitta `x` bit bo'lishi kerak).
2. Jarayon UID'i fayl egasiga teng bo'lsa: **faqat** user bitlari qaraladi.
3. Aks holda, jarayon guruhlaridan biri fayl guruhiga teng bo'lsa: **faqat** group bitlari qaraladi.
4. Aks holda: other bitlari.

Birinchi mos kelgan sinf hal qiladi, keyingisiga o'tilmaydi. Rejimi `---r--r--` bo'lgan faylni egasi o'qiy olmaydi, boshqalar o'qiy oladi. Ega ruxsatni o'zi qaytarib olishi mumkin, chunki `chmod` huquqi rejimga emas, egalikka bog'liq.

Guruhlar ro'yxati login paytida o'rnatiladi. Foydalanuvchi guruhga qo'shilgandan keyin ishlab turgan sessiyalar eskicha qoladi: `id` (joriy jarayon) va `id username` (bazadagi holat) farq qilishi mumkin.

### rwx: fayl va papka

| Bit | Faylda | Papkada |
|-----|--------|---------|
| `r` | mazmunni o'qish | ichidagi nomlar ro'yxatini o'qish (`ls`) |
| `w` | mazmunni o'zgartirish | yozuv qo'shish, o'chirish, nomini o'zgartirish (`x` bilan birga) |
| `x` | dastur sifatida ishga tushirish | ichiga kirish (`cd`) va ichidagi fayllarga nomi bo'yicha murojaat |

Papka bu "nom, inode raqami" juftliklari jadvali. Shundan uchta oqibat chiqadi:

- Faylni **o'chirish** faylning emas, papkaning `w` va `x` ruxsatiga bog'liq: o'chirish papka jadvalidan qatorni olib tashlashdir. Faqat o'qish uchun bo'lgan (`444`), root'ga tegishli faylni ham o'z papkangizdan o'chira olasiz.
- Faylga yetish uchun yo'ldagi **har bir** papkada `x` kerak. `/home/ali` rejimi `700` bo'lsa, ichidagi `777` fayl ham boshqalarga yopiq. Web server "403" berishining odatiy sababi.
- `r` bor, `x` yo'q papkada nomlar ko'rinadi, lekin fayllarning o'ziga yetib bo'lmaydi. `x` bor, `r` yo'q papkada ro'yxat ko'rinmaydi, lekin nomini bilgan faylni ochish mumkin.

Skriptni `./script.sh` deb ishga tushirish uchun `r` va `x` ikkalasi kerak (interpretator faylni o'qiydi), kompilyatsiya qilingan binary uchun `x` yetarli.

## 2. chmod

### Octal

Har sinf uch bit: `r`=4, `w`=2, `x`=1, yig'indisi bitta raqam.

| Octal | Ko'rinishi | Odatda nima uchun |
|-------|------------|-------------------|
| `644` | `rw-r--r--` | oddiy fayllar, konfiguratsiya |
| `600` | `rw-------` | shaxsiy kalitlar, secret'lar (`ssh` boshqa rejimni rad etadi) |
| `640` | `rw-r-----` | guruh o'qiydigan konfiguratsiya, loglar |
| `755` | `rwxr-xr-x` | papkalar, bajariladigan fayllar |
| `700` | `rwx------` | shaxsiy papka (`~/.ssh`) |
| `750` | `rwxr-x---` | guruhga ochiq papka |
| `664`, `775` | `rw-rw-r--`, `rwxrwxr-x` | guruh bilan birga yoziladigan fayl va papkalar |

### Simvolik

```
chmod u+x script.sh        # add execute for the owner
chmod go-w file            # remove write from group and other
chmod u=rw,go=r file       # set exactly (same as 644)
chmod a+r file             # a = all three classes
chmod -R g+rwX shared/     # X: execute only for directories and already-executable files
```

- Octal rejimni to'liq o'rnatadi, simvolik mavjud rejimga nisbatan o'zgartiradi.
- Katta `X` rekursiv o'zgartirishda kerak: papkalarga `x` beradi, oddiy fayllarga bermaydi.

**Tuzoq: `chmod -R 644 papka`.** Papkalardan `x` olinadi va ichiga kirib bo'lmay qoladi. `chmod -R 755` esa barcha fayllarni bajariladigan qiladi. Papka va fayllarga alohida: `find p -type d -exec chmod 755 {} +` va `find p -type f -exec chmod 644 {} +`, yoki `chmod -R u=rwX,go=rX p`.

**Tuzoq: `chmod 777`.** Muammoni "yechadi", chunki tekshiruvni o'chiradi: tizimdagi har qanday jarayon (buzilgan web ilova ham) faylni o'zgartira oladi. To'g'ri yo'l: jarayon qaysi foydalanuvchi nomidan ishlayotganini (`ps -o user= -p PID`) va yo'ldagi qaysi element to'sayotganini aniqlash (`namei -l /to/liq/yo'l` har elementning rejimini ko'rsatadi).

## 3. umask

Yangi fayl yaratayotgan dastur rejim so'raydi (odatda fayl uchun `666`, papka uchun `777`), kernel undan jarayonning `umask` idagi bitlarni **olib tashlaydi**: `natija = so'ralgan & ~umask`.

| umask | Yangi fayl | Yangi papka | Qayerda uchraydi |
|-------|-----------|-------------|------------------|
| `022` | `644` | `755` | root va servislar uchun standart |
| `002` | `664` | `775` | Ubuntu'da oddiy foydalanuvchi (shaxsiy guruh bilan) |
| `027` | `640` | `750` | qattiqlashtirilgan serverlar |
| `077` | `600` | `700` | secret'lar bilan ishlash |

- `umask` joriy qiymatni ko'rsatadi, `umask -S` simvolik ko'rinishda, `umask 027` o'rnatadi. U jarayon xususiyati, bolalarga meros bo'ladi.
- Bu ayirish emas, mask: `666` va umask `027` da natija `640`, `639` emas. umask faqat bitlarni olib tashlaydi, hech qachon qo'shmaydi: fayl `x` bilan yaratilmaydi, chunki dastur `666` so'ragan.
- Standart qiymat `/etc/login.defs` (`UMASK`), PAM (`pam_umask`) va shell startup fayllaridan keladi. systemd servisi uchun unit faylida `UMask=`.
- `chmod` umask'ga qaramaydi (octal bilan), `cp` va `tar` esa manba rejimiga umask qo'llaydi (`-p` yoki `-a` bo'lmasa).

## 4. chown va chgrp

```
sudo chown alice file            # owner
sudo chown alice:devs file       # owner and group
sudo chown :devs file            # group only (same as chgrp devs file)
sudo chown -R www-data:www-data /var/www/app
sudo chown --reference=a.txt b.txt
```

- Egani faqat root o'zgartira oladi. Oddiy foydalanuvchi faylini boshqaga "sovg'a" qila olmaydi (aks holda disk kvotasi va setuid himoyasini chetlab o'tish mumkin bo'lardi).
- Fayl egasi guruhni o'zi a'zo bo'lgan guruhlardan biriga o'zgartira oladi.
- Kernel nom emas, raqam (UID, GID) saqlaydi. Nomlar `/etc/passwd` va `/etc/group` orqali ko'rsatiladi. Diskni boshqa serverga yoki volume'ni boshqa konteynerga ulasangiz, o'sha raqam boshqa nomga to'g'ri kelishi yoki umuman nomsiz chiqishi mumkin (`ls -l` da raqam ko'rinadi, `ls -n` har doim raqam ko'rsatadi). Docker volume ruxsat muammolarining ildizi shu.

## 5. Maxsus bitlar

Rejimning to'rtinchi (eng chapdagi) octal raqami:

| Bit | Octal | Faylda | Papkada | `ls -l` da |
|-----|-------|--------|---------|------------|
| setuid | `4000` | dastur fayl **egasi** huquqi bilan ishlaydi | ta'sir qilmaydi | user `x` o'rnida `s` |
| setgid | `2000` | dastur fayl **guruhi** huquqi bilan ishlaydi | yangi fayllar papka guruhini oladi, yangi papkalar setgid'ni ham | group `x` o'rnida `s` |
| sticky | `1000` | ta'sir qilmaydi | faylni faqat egasi (yoki papka egasi, root) o'chira oladi | other `x` o'rnida `t` |

```
ls -l /usr/bin/passwd    # -rwsr-xr-x root root : setuid
ls -ld /tmp              # drwxrwxrwt root root : sticky
chmod 2775 /srv/shared   # setgid directory; symbolic form: chmod g+s
```

- **setuid**: `passwd` oddiy foydalanuvchi nomidan ishga tushadi, lekin root huquqi bilan ishlaydi, chunki `/etc/shadow` ga yozishi kerak. Har setuid root dastur potensial privilege escalation yo'li, shuning uchun ular kam va auditda tekshiriladi: `find / -perm -4000 -type f 2>/dev/null`.
- Linux setuid'ni skriptlarda (shebang'li fayllarda) e'tiborsiz qoldiradi, u faqat binary'da ishlaydi.
- **setgid papka** jamoaviy papkalar uchun: usiz har kim yaratgan fayl o'z shaxsiy guruhida qoladi va hamkasbi yoza olmaydi.
- **sticky** hamma yoza oladigan papkalarda (`/tmp`) birovning faylini o'chirishni taqiqlaydi.
- Katta `S` yoki `T`: maxsus bit bor, lekin ostidagi `x` yo'q. Odatda xato sozlama belgisi.

### Rejimdan tashqari mexanizmlar

Rejim to'g'ri, lekin baribir `Permission denied` bo'lsa, navbat bilan tekshiriladi: ACL (`ls -l` da rejim oxirida `+`, ko'rish `getfacl fayl`), o'zgarmas atribut (`lsattr fayl` da `i`), fayl tizimi faqat o'qish uchun yoki `noexec` bilan mount qilingan (`findmnt -T fayl`), SELinux yoki AppArmor siyosati (loglarda `denied`). Bular keyingi darslar va modullarda.

## 6. Hard va soft linklar

Fayl nomi va fayl ma'lumoti alohida narsalar. Ma'lumot va metadata **inode** da (13-darsda chuqur), papka esa nomlarni inode raqamlariga bog'laydi. `ls -li` birinchi ustunda inode raqamini, uchinchi ustunda shu inode'ga nechta nom ko'rsatayotganini (link count) chiqaradi.

| | Hard link (`ln a b`) | Symlink (`ln -s a b`) |
|---|----------------------|------------------------|
| Nima | o'sha inode'ga yana bir nom | ichida yo'l yozilgan alohida kichik fayl |
| inode | bir xil | boshqa |
| Fayl tizimlari orasida | mumkin emas | mumkin |
| Papkaga | mumkin emas | mumkin |
| Asl nom o'chirilsa | ma'lumot qoladi | link "osilib qoladi" (dangling) |
| Ruxsatlar | umumiy (bitta inode) | linkniki ahamiyatsiz (`lrwxrwxrwx`), nishonniki ishlaydi |
| `ls -l` da | farqlab bo'lmaydi, faqat link count > 1 | `l` turi va `-> nishon` |

- Hard linklar teng huquqli, "asl" va "nusxa" yo'q. Ma'lumot link count 0 ga tushganda **va** faylni ochiq ushlab turgan jarayon qolmaganda bo'shatiladi. O'chirilgan, lekin jarayon ochiq ushlab turgan log fayli diskni egallashda davom etishining sababi shu (`df` to'la, `du` bo'sh).
- Symlink ichidagi yo'l satr sifatida saqlanadi. **Nisbiy yo'l linkning o'zi turgan papkadan hisoblanadi**, buyruq berilgan joydan emas. `ln -s` nishon mavjudligini tekshirmaydi.
- `readlink link` ichidagi yo'lni, `readlink -f link` (yoki `realpath`) barcha linklar ochilgandan keyingi yakuniy yo'lni ko'rsatadi.
- Osilib qolgan symlink'larni topish: `find . -xtype l`. Bir inode'ning barcha nomlari: `find . -samefile fayl`.

```
ln -s releases/v2 current        # relative target, resolved from the link's directory
ln -sfn releases/v3 current      # replace the link; -n: do not descend into the old target
ln -sr /srv/app/releases/v3 /srv/app/current   # -r: compute a relative target
```

Symlink tizimda hamma joyda: `/bin -> usr/bin`, `/etc/alternatives/editor`, `/etc/localtime`, deploy'dagi `current -> releases/<versiya>` sxemasi, nginx'ning `sites-enabled` papkasi.

**Tuzoq: `-n` siz `ln -sf`.** `current` mavjud bo'lib papkaga ko'rsatsa, `ln -sf releases/v3 current` linkni almashtirmaydi, `current/` ichida `v3` nomli yangi link yaratadi. Papkaga ko'rsatuvchi linkni almashtirishda `-n` shart.

**Tuzoq: oxirgi slash.** `rm link` linkni o'chiradi, nishonga tegmaydi. Lekin `rm -r link/` (slash bilan) nishon papkasining ichini o'chiradi. Tab completion slash'ni o'zi qo'shadi.

## 7. Arxivlash va siqish

Ikki alohida ish: **arxivlash** (ko'p fayl va papkani metadata bilan bitta oqimga yig'ish, `tar`) va **siqish** (bitta oqimni kichraytirish, `gzip`, `xz`, `zstd`). `.tar.gz` bu avval tar, keyin gzip. `zip` ikkalasini birga qiladi.

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

- tar ichida yo'llar qanday berilgan bo'lsa shunday saqlanadi. Absolut yo'l berilsa boshidagi `/` olib tashlanadi (`Removing leading '/' from member names`), ochganda joriy papkaga nisbatan tiklanadi.
- tar ega (nom va raqam), rejim va vaqtlarni saqlaydi. Ochishda egalik faqat root uchun tiklanadi, oddiy foydalanuvchi ochsa hamma fayl uniki bo'ladi. Boshqa mashinada nomlar boshqa UID'ga to'g'ri kelishi mumkin: `--numeric-owner` raqamlarni aynan saqlaydi.
- Symlink'lar link sifatida saqlanadi (nishon mazmuni emas), hard linklar ham saqlanadi.

**Tuzoq: `tar -cfz a.tar.gz dir`.** `-f` dan keyingi so'z fayl nomi, ya'ni arxiv `z` nomli faylga yoziladi va `a.tar.gz` ni arxivlanadigan fayl deb qidiradi. `f` har doim flag'lar guruhining oxirida: `-czf`.

**Tuzoq: tarbomb.** Ichida umumiy yuqori papkasi bo'lmagan arxiv joriy papkaga yuzlab fayl sochadi va mavjudlarini ustidan yozadi. Har doim avval `-t` bilan ko'ring va alohida papkaga (`-C`) oching.

### gzip va boshqalar

| Vosita | Kengaytma | Xususiyati |
|--------|-----------|------------|
| `gzip` | `.gz` | tez, hamma joyda bor, o'rtacha siqish; loglar va HTTP uchun standart |
| `bzip2` | `.bz2` | gzip'dan yaxshiroq siqadi, sezilarli sekin; yangi ishlarda kam |
| `xz` | `.xz` | eng kuchli siqish, siqishda sekin va xotira talab qiladi |
| `zstd` | `.zst` | gzip darajasidagi yoki yaxshiroq siqish, ancha tez; zamonaviy tanlov |

- `gzip fayl` asl faylni `fayl.gz` ga **almashtiradi**. Saqlab qolish: `gzip -k`. Ochish: `gunzip` yoki `gzip -d`. Daraja: `-1` (tez) dan `-9` (kuchli) gacha.
- gzip faqat bitta faylni siqadi, papkani emas. Shuning uchun tar bilan birga ishlatiladi.
- Siqilgan faylni ochmasdan o'qish: `zcat`, `zless`, `zgrep`. Rotatsiya qilingan loglar (`/var/log/*.gz`) shular bilan o'qiladi.

### zip

```
zip -r site.zip site/        # -r is required for directories
unzip -l site.zip            # list
unzip site.zip -d /tmp/out   # extract into a directory
```

`zip` Windows va macOS bilan almashish uchun qulay, lekin Unix egaligini saqlamaydi. Serverlar orasidagi backup va deploy uchun tar.

## Tuzoqlar

- `chmod 777` va `chmod -R 777`. Sababni topish o'rniga himoyani o'chirish. Audit va xavfsizlik skanerlarida birinchi topiladigan narsa.
- `chmod -R` va `chown -R` ni noto'g'ri yo'lga berish (`/`, `..`, bo'sh o'zgaruvchi). `chown -R user /usr` dan keyin setuid dasturlar va `sudo` buziladi, tizimni tiklash qayta o'rnatishdan qiyin.
- Secret fayllar (`.env`, kalitlar) `644` bilan: serverdagi har foydalanuvchi va har buzilgan servis o'qiydi. `600` va to'g'ri ega.
- Guruhga qo'shilgandan keyin sessiyani yangilamaslik: `usermod -aG docker user` dan keyin qayta login qilinmaguncha huquq yo'q.
- Faqat faylning rejimiga qarash. Yo'ldagi papkalardan birida `x` yo'qligi, ACL, `noexec` mount, SELinux ham sabab bo'lishi mumkin. `namei -l`.
- Volume yoki backup'ni boshqa tizimda ochganda nomga ishonish. Egalik raqam bilan saqlanadi.
- `ln -sf` da `-n` ni unutish, va symlink'ni oxirgi slash bilan o'chirish.
- Nisbiy symlink'ni boshqa papkaga ko'chirish yoki noto'g'ri papkadan turib yaratish: link osilib qoladi.
- Backup'ni tekshirmaslik. Ochib ko'rilmagan arxiv backup emas: `tar -tzf` va vaqti-vaqti bilan haqiqiy tiklash sinovi.
- Arxivni oddiy foydalanuvchi sifatida ochib, egalik tiklandi deb o'ylash; yoki arxivni noma'lum manbadan ko'rmasdan root sifatida `/` da ochish.

## Manbalar

- https://man7.org/linux/man-pages/man7/path_resolution.7.html – `path_resolution(7)`, ruxsat tekshiruvi qadamlari
- https://man7.org/linux/man-pages/man7/inode.7.html – `inode(7)`, rejim bitlari va vaqtlar
- https://man7.org/linux/man-pages/man2/umask.2.html – `umask(2)`
- https://man7.org/linux/man-pages/man2/chown.2.html – `chown(2)`, kim nimani o'zgartira oladi
- https://man7.org/linux/man-pages/man7/symlink.7.html – `symlink(7)`
- https://www.gnu.org/software/coreutils/manual/coreutils.html#File-permissions – GNU coreutils, File permissions
- https://www.gnu.org/software/coreutils/manual/coreutils.html#ln-invocation – `ln`
- https://www.gnu.org/software/tar/manual/tar.html – GNU tar qo'llanmasi
- https://www.gnu.org/software/gzip/manual/gzip.html – GNU gzip
- https://facebook.github.io/zstd/ – Zstandard
- Kerrisk, "The Linux Programming Interface" – 15 bob (File Attributes), 18 bob (Directories and Links)
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 9 va 18 boblar

---

## Vazifalar

Ish papkasi: `linux/06-files/` (`make new m=linux n=06 name=files` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Skript (`task_22.sh`) shu papkaga saqlanadi. Vazifalar `lab` VM'da, `~/files` ichida (boshqasi aytilmagan bo'lsa). Har tajribada avval natijani taxmin qilib yozing, keyin bajaring.

### A. Ruxsatlar

1. **Reading modes.** `stat -c '%A %a %U %G %n'` ni `/etc/passwd`, `/etc/shadow`, `/usr/bin/passwd`, `/tmp`, `/home/ubuntu`, `~/.ssh`, `~/.ssh/authorized_keys` uchun bajaring. Har biri uchun: kim o'qiy oladi, kim yoza oladi, rejim nima uchun aynan shunday tanlangan? `id` chiqishiga qarab, `ubuntu` foydalanuvchisi `/etc/shadow` ni o'qiy oladimi (sinab ko'ring)?

2. **Octal and symbolic.** Jadvalni to'ldiring (octal, `rwx` ko'rinishi, simvolik `chmod` buyrug'i): `640`, `750`, `rw-rw-r--`, `u=rwx,g=rx,o=`, `600`, `rwx--x--x`. Har birini bitta faylga octal bilan, ikkinchisiga simvolik bilan qo'llab, `stat -c %a` bir xil ekanini ko'rsating. `chmod +x fayl` va `chmod a+x fayl` har doim bir xilmi (`umask 027` bilan sinang)?

3. **Directory bits.** `d/` papkasida `f.txt` yarating. Papka rejimini navbat bilan `r--`, `--x`, `-wx`, `rw-` (faqat user uchun, masalan `400`, `100`, `300`, `600`) qilib, har birida sinang: `ls d`, `ls -l d`, `cat d/f.txt`, `touch d/new`, `rm d/f.txt`, `cd d`. Natijalarni jadvalga yozing (ishladi yoki xato matni). Jadvaldan papka uchun `r`, `w`, `x` ma'nosini o'z so'zingiz bilan chiqaring.

4. **Delete without write.** `~/files/own/` papkasida `sudo touch root.txt && sudo chmod 444 root.txt` qiling. `ubuntu` sifatida: faylga yozishga urinib ko'ring, keyin `rm root.txt` qiling. Nima uchun yozib bo'lmadi, lekin o'chirib bo'ldi? Faylni o'chirishdan himoya qilish uchun nimaning ruxsati o'zgarishi kerak?

5. **First match wins.** Fayl yarating va `chmod 047` qiling. Egasi sifatida `cat` qiling, keyin `sudo -u bob cat` (fayl bob yeta oladigan joyda bo'lsin, masalan `/tmp`). Kim o'qiy oldi? Tekshiruv algoritmining qaysi qadami buni tushuntiradi? Ega bu holatdan o'zi chiqa oladimi va nima uchun?

6. **Path traversal.** `/tmp/p/a/b/secret.txt` ni yarating, fayl rejimi `644`. `chmod 700 /tmp/p/a` qiling va `sudo -u bob cat /tmp/p/a/b/secret.txt` ni sinang. `namei -l /tmp/p/a/b/secret.txt` chiqishida to'siq qayerda ekanini ko'rsating. Bobga faylni o'qishga imkon beradigan, lekin `a` ichidagi nomlar ro'yxatini ko'rsatmaydigan eng kichik o'zgarishni toping.

7. **umask.** `umask` va `umask -S` qiymatini yozing. `022`, `027`, `077` har biri uchun avval natijani hisoblang (bitlar bilan), keyin subshell ichida sinang: `(umask 027; touch f; mkdir d; stat -c '%a %n' f d)`. Nima uchun `umask 000` bilan ham fayl `666`, `777` emas? VM'da standart umask qayerdan kelganini toping (`grep -E '^UMASK|USERGROUPS_ENAB' /etc/login.defs`). `sudo -i` ichidagi umask bilan solishtiring.

8. **Recursive chmod trap.** `mkdir -p site/{css,js} && touch site/index.html site/css/a.css site/js/a.js` yarating. `chmod -R 644 site` qiling va `ls site/css`, `cat site/index.html` ni sinang, xatoni izohlang. Ikki usulda tuzating: `find` bilan (papkalar `755`, fayllar `644`) va bitta simvolik `chmod -R` bilan (`X`). `X` va `x` farqini ko'rsating.

### B. Egalik va maxsus bitlar

9. **chown rules.** Laboratoriya bo'limidagi buyruqlar bilan `alice`, `bob`, `devs` ni yarating. `ubuntu` sifatida o'z faylingizni `sudo` siz `chown alice` qilib ko'ring, xatoni yozing va nima uchun kernel buni taqiqlashini izohlang. `sudo -iu alice` ichida: fayl yarating, `chgrp devs` (ishlaydi) va `chgrp sudo` (ishlamaydi) ni sinang. `id alice` va alice sessiyasi ichidagi `id` bir xilmi?

10. **Shared directory.** `sudo mkdir /srv/devs && sudo chown root:devs /srv/devs && sudo chmod 775 /srv/devs` qiling. alice fayl yaratsin, bob unga yozib ko'rsin. Faylning guruhi nima va bob nima uchun yoza olmadi (yoki oldi)? Endi `sudo chmod 2775 /srv/devs` qiling, alice yangi fayl va papka yaratsin: guruh va rejimni oldingi fayl bilan solishtiring. Bu sxema ishlashi uchun umask qanday bo'lishi kerak (alice sessiyasida `umask 022` bilan sinang)?

11. **Sticky bit.** `sudo mkdir /srv/drop && sudo chmod 777 /srv/drop` qiling. alice fayl yaratsin, bob uni o'chirsin: bo'ldimi? `sudo chmod 1777 /srv/drop` dan keyin takrorlang va xato matnini yozing. `ls -ld /srv/drop /tmp` dagi belgini ko'rsating. `chmod 1776` da `ls -ld` nima ko'rsatadi va bu nimani anglatadi?

12. **setuid audit.** `find / -perm -4000 -type f 2>/dev/null` va `-perm -2000` natijasini oling. Uchta setuid dasturni tanlab, har biri nima uchun root huquqiga muhtojligini yozing. `cp /usr/bin/passwd ~/files/` qiling va rejimni asl bilan solishtiring: bit qayerga ketdi va nima uchun bu to'g'ri xatti-harakat? `-perm -4000` va `-perm 4000` farqi nima?

### C. Linklar

13. **Hard link.** `a.txt` yarating, `ln a.txt b.txt` qiling. `ls -li` dagi inode va link count ni yozing. `b.txt` orqali mazmunni o'zgartiring, `chmod 600 b.txt` qiling va `a.txt` ni tekshiring. `rm a.txt` dan keyin `b.txt` da nima bor? Keyin sinang va xatolarni yozing: `ln b.txt /dev/shm/c.txt`, `ln ~/files hardlink-to-dir`. Har cheklovning sababi nima?

14. **Symlink.** `ln -s b.txt s.txt` yarating. `ls -li`, `readlink s.txt`, `stat s.txt` va `stat -L s.txt` ni solishtiring. `chmod 644 s.txt` nimaning rejimini o'zgartirdi? `b.txt` ni o'chiring: `ls -l s.txt` va `cat s.txt` nima deydi? `find . -xtype l` bilan toping. `b.txt` ni qayta yarating: link "tirildi"mi va bu hard linkdan qanday farq qiladi?

15. **Relative symlink trap.** `mkdir -p proj/{bin,lib} && echo hi > proj/lib/tool.sh` yarating. `~/files` da turib `ln -s proj/lib/tool.sh proj/bin/tool` qiling va `cat proj/bin/tool` ni sinang. Xatoni `readlink` va `readlink -f` bilan tushuntiring: yo'l qayerdan hisoblanyapti? Uch usulda to'g'rilang: to'g'ri nisbiy yo'l, absolut yo'l, `ln -sr`. Keyin `proj` ni `/tmp` ga `mv` qiling: qaysi variant ishlashda davom etdi?

16. **Release switch.** `mkdir -p app/releases/{v1,v2,v3}` va har birida `echo vN > VERSION` yarating. `app/current` symlink'ini `v1` ga qarating, `cat app/current/VERSION` bilan tekshiring. `ln -sf releases/v2 current` (`-n` siz) bilan almashtirib ko'ring: nima bo'ldi, `find app -type l` nimani ko'rsatadi? Tozalab, `-sfn` bilan `v2`, keyin `v3` ga o'tkazing, keyin `v2` ga rollback qiling. Bu sxema deploy uchun nima beradi?

17. **System links.** `ls -l /bin /sbin /etc/localtime /usr/bin/editor /etc/alternatives/editor` ni bajaring va `readlink -f /usr/bin/editor` bilan zanjirni oxirigacha kuzating. `ls -li /usr/bin | awk '$3 > 1' | head` bilan hard linkli dasturlarni toping va bittasining barcha nomlarini `find /usr/bin -samefile ...` bilan chiqaring. Tizim nima uchun bu yerda nusxa emas link ishlatadi?

### D. Arxivlar

18. **tar roundtrip.** 8-vazifadagi `site/` ga symlink va rejimi `600` bo'lgan fayl qo'shing. `site.tar.gz` yarating, `-tvzf` bilan ro'yxatini ko'ring (rejim, ega, symlink qanday ko'rsatilgan?), `/tmp/restore` ga oching va `diff -r site /tmp/restore/site` bilan tekshiring. `--exclude='*.css'` bilan ikkinchi arxiv yarating va ro'yxatini solishtiring.

19. **tar pitfalls.** (a) `tar -cfz x.tar.gz site` ni bajaring, xatoni yozing va papkada qanday fayl paydo bo'lganini ko'ring. (b) `tar -cf ssh.tar /etc/ssh` (xatolarga e'tibor bermang) qiling: tar nima deb ogohlantirdi, `tar -tf ssh.tar | head -3` da yo'llar qanday? Uni `/tmp/x` ga ochsangiz fayllar qayerga tushadi? (c) `--strip-components=2` bilan ochib farqni ko'rsating. (d) `-C` bilan arxiv yaratishda yo'llar qanday o'zgarishini ko'rsating.

20. **Ownership in archives.** `/srv/devs` ni (alice va bob fayllari bilan) `sudo tar -czf /tmp/devs.tar.gz -C /srv devs` bilan arxivlang. Uni ikki marta oching: `ubuntu` sifatida `~/files/as-user/` ga va `sudo` bilan `/tmp/as-root/` ga. Egalik va setgid bit ikki holatda qanday tiklandi? `tar -tvzf` va `tar --numeric-owner -tvzf` chiqishlarini solishtiring. Xuddi shu papkani `zip -r` bilan arxivlab, `sudo unzip` bilan ochib egalikni tekshiring. Backup uchun xulosa yozing.

21. **Compression compare.** `sudo cat /var/log/syslog > big.log` (fayl kichik bo'lsa bir necha marta o'ziga qo'shib 50M atrofiga yetkazing). `gzip -1`, `gzip -9`, `bzip2`, `xz`, `zstd` har biri uchun `time` bilan siqish vaqtini va natija hajmini jadvalga yozing (har safar asl faylni saqlang: `-k`). Qaysi biri eng kichik, qaysi biri eng tez? Kunlik log rotatsiyasi va oylik arxiv uchun qaysi birini tanlaysiz? `zcat`, `zgrep -c` va `zless` ni `.gz` faylda sinang; `gzip big.log` (`-k` siz) asl fayl bilan nima qildi?

### E. Yakuniy

22. **Backup script.** `task_22.sh <manba-papka> <backup-papka>` yozing: backup papkasini yo'q bo'lsa `700` rejimda yaratadi; manbani `<nom>-YYYYmmdd-HHMMSS.tar.gz` ga arxivlaydi (arxiv ichida yo'llar manba papka nomidan boshlansin, absolut bo'lmasin); arxiv rejimi `600`; yaratilgan arxivni `tar -tzf` bilan tekshiradi va muvaffaqiyatsiz bo'lsa nolga teng bo'lmagan kod bilan tugaydi; `latest` symlink'ini yangi arxivga qaratadi (nisbiy, `-sfn`); faqat oxirgi 3 ta arxivni qoldirib eskilarini o'chiradi. Talablar: `set -euo pipefail`, noto'g'ri argumentlarda usage va `exit 2`, barcha o'zgaruvchilar tirnoqda, shellcheck toza. Sinov: skriptni 5 marta ishga tushirib `ls -l` natijasini, noto'g'ri argument bilan exit code'ni, va `latest` dan `/tmp/verify` ga tiklab `diff -r` natijasini README'ga yozing.

### Topshirish

Tayyor bo'lgach:
1. `linux/06-files/README.md` da 22 ta vazifa `## N. Title` sarlavhalari ostida.
2. Ish papkasida `task_22.sh` bor, shellcheck hech narsa chiqarmaydi.
3. `make check` toza o'tadi.
4. VM'da: `alice`, `bob`, `devs` o'chirilgan, `/srv/devs`, `/srv/drop`, `/tmp` dagi sinov fayllari va `~/files` tozalangan (yoki `multipass restore lab.before-06`).
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Kernel faylga ruxsatni qanday tartibda tekshiradi? Rejimi `047` bo'lgan faylni egasi nima uchun o'qiy olmaydi?
- Papkada `r`, `w`, `x` nimani anglatadi? Faylni o'chirish huquqi nimaga bog'liq?
- `umask 027` bilan yaratilgan fayl va papka rejimi qanday bo'ladi va nima uchun bu ayirish emas?
- Nima uchun oddiy foydalanuvchi faylini boshqaga `chown` qila olmaydi?
- setuid, setgid (fayl va papkada), sticky bit har biri nima qiladi? Har biriga tizimdan misol keltiring.
- `chmod 777` nima uchun yechim emas va `Permission denied` ni qanday tartibda tekshirasiz?
- Hard link va symlink farqi nima? Fayl ma'lumoti qachon haqiqatan o'chiriladi?
- Nisbiy symlink qayerdan hisoblanadi? `ln -sfn` dagi `-n` nima uchun kerak?
- tar egalikni qanday saqlaydi va qachon tiklaydi? Arxiv ichidagi yo'llar qanday aniqlanadi?
- gzip, xz va zstd orasida qanday tanlaysiz? `tar` va `zip` farqi nima?
