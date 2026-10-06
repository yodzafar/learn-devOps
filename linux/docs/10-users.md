# 10-dars: Foydalanuvchilarni boshqarish

Maqsad: Linux'da foydalanuvchi va guruhlar qayerda saqlanishi, qanday yaratilishi va huquqlar `sudo` orqali qanday berilishini noldan tushunish. 6-darsdagi fayl huquqlari (`rwx`, egasi, guruhi) faqat "kim" degan savolga javob bo'lgandagina ma'noga ega, bu dars shu "kim" haqida. Frontend ishida "foydalanuvchi" deganda ilovaning ma'lumotlar bazasidagi qator tushuniladi; bu yerda esa operatsion tizimning o'z foydalanuvchilari haqida gap boradi: kernel har jarayon va har faylga shular orqali egalik belgilaydi. Amaliy natija: yangi serverga `deploy` foydalanuvchisini SSH kalit bilan kiradigan qilib sozlash, cheklangan `sudo` qoidasi yozish va dastur uchun login qila olmaydigan `demoapp` servis akkauntini yaratish. `deploy` va `demoapp` keyingi darslarda ishlatiladi (11-dars systemd, 13-dars disklar), shuning uchun dars oxirida VM'da qoladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A, B guruh vazifalari; ikkinchi kun 3-bo'lim, "Birga bajaramiz" va C guruhi; uchinchi kun 4–5 bo'limlar, D va E guruhlari, README'ni tartibga solish. Diqqatni quyidagilarga qarating: `/etc/passwd` va `/etc/shadow` maydonlari, `usermod -aG` dagi `-a`, guruh a'zoligi qachon kuchga kirishi, `sudoers` sintaksisi va `visudo`, `~/.ssh` huquqlari, parolni bloklash SSH kalitni bloklamasligi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ko'ring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi UID, GID, sana va hash'lar farq qiladi, darsda bunday joylar `<...>` bilan belgilangan. Misollardagi nomlar (`erin`, `nora`, `reportd`) vazifalardagi nomlardan ataylab boshqa: misolni ko'rib, vazifani o'zingiz moslaysiz.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` VM kerak (Multipass, Ubuntu 24.04). Dars VM'ni yaratmaydi, faqat ishlatadi. Bu dars tizimni o'zgartiradi (foydalanuvchi, guruh, `sudoers`), shuning uchun **hamma o'zgartiruvchi buyruq faqat VM ichida**. Host'da (Zorin ham, macOS ham) foydalanuvchi yaratmang, `sudoers` ga tegmang.

| Joy | Prompt | Bu darsda nima qilinadi |
|-----|--------|-------------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `make`, `git`, `multipass`, SSH kalit yaratish (`ssh-keygen`), VM'ga `ssh` bilan kirish, `docker run` |
| `lab` VM | `ubuntu@lab:~$` | barcha vazifalar: `useradd`, `usermod`, `visudo`, `chage`, `journalctl` |
| Konteyner | `[root@<id> /]#` | RHEL oilasi bilan solishtirish: `docker run --rm -it rockylinux:9 bash` |

- **Ikki terminal qoidasi.** `sudoers` yoki SSH sozlamasiga tegishdan oldin VM'ga ikkinchi terminal oching (`multipass shell lab`) va unda `sudo -i` bilan root bo'lib turing. Xato qilsangiz shu ochiq sessiyadan tuzatasiz. `multipass shell` SSH kalitingizga ham, `deploy` ga ham bog'liq emas, u har doim `ubuntu` sifatida kiritadi.
- **Snapshot.** `SETUP.md` da `clean` snapshot olingan. VM butunlay buzilsa: `multipass stop lab`, keyin `multipass restore lab.clean`. E'tibor bering, bu oldingi darslarda VM ichida qoldirilgan hamma narsani ham qaytaradi. Darsdan oldin o'z nuqtangizni saqlab qo'ysangiz xavfsizroq: `multipass stop lab && multipass snapshot lab --name before-10 && multipass start lab`.
- **VM'ning IP manzili.** Host'da `multipass info lab`, `IPv4` qatori. SSH vazifalarida host SSH mijozi bo'ladi (OpenSSH Zorin'da ham, macOS'da ham bor), VM esa server. Manzil har mashinada boshqa va VM qayta yaratilsa o'zgaradi.
- **Rocky konteyneri.** Konteyner ichida siz root, `sudo` kerak emas. `passwd` buyrug'i yo'q bo'lsa: `dnf install -y passwd`. `rockylinux:9` image'i `amd64` va `arm64` uchun chiqadi, ikkala mashinada emulyatsiyasiz ishlaydi (`docker manifest inspect rockylinux:9` bilan tekshirish mumkin).
- **Maxfiy narsalar.** Parol hash'lari va private kalit README'ga ham, repo'ga ham tushmaydi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `x86_64`. Host ham Linux, shuning uchun 1-vazifadagi `id`, `groups`, `getent passwd "$USER"` host'da ishlaydi va `sudo`, `adm`, `docker` guruhlari ko'rinadi. Host'da faqat o'qing, hech narsa yaratmang. |
| macOS (uy) | VM `aarch64`. Host'da `id` va `groups` bor, lekin `getent`, `useradd`, `chage`, `/etc/shadow` yo'q; foydalanuvchilar `/etc/passwd` da emas, Directory Services bazasida, uni `dscl . -read /Users/"$USER"` o'qiydi. Administrator guruhi `sudo` emas, `admin`. `date -d` ham yo'q (BSD `date`), shuning uchun 3-vazifadagi hisob VM'da. `ssh`, `ssh-keygen`, `multipass transfer` bir xil ishlaydi. |

**Holatni ikkinchi mashinada tiklash.** Laboratoriya holati mashinalar orasida ko'chmaydi, faqat README va fayllaringiz git orqali ko'chadi. Bu dars oldingi darslar holatiga tayanmaydi: toza `lab` yetarli. Lekin bu dars o'zi holat qoldiradi: `deploy` (home va bash bilan, parolsiz, SSH kalit bilan kiradi) va `demoapp` (tizim akkaunti, home'siz, shell `nologin`, katalogi `/var/lib/demoapp`). Keyingi darslarni boshqa mashinada davom ettirsangiz, o'sha mashinadagi VM'da 15- va 17-vazifalarni o'z README'ingizdagi buyruqlar bilan takrorlang (10 daqiqa). Kalit jufti har mashinada alohida: `authorized_keys` ga o'sha mashinaning public kaliti qo'yiladi, private kalit mashinalar orasida ko'chirilmaydi.

---

## 1. Foydalanuvchi va guruh ma'lumotlari

### Bu nima

Linux ko'p foydalanuvchili tizim: bitta mashinada bir vaqtda bir nechta odam va o'nlab dasturlar ishlaydi, har biri o'z "kimligi" bilan. **Foydalanuvchi** (user) bu shu kimlik, **guruh** (group) esa foydalanuvchilar to'plami, huquqni bir nechta odamga birdan berish uchun. Kernel foydalanuvchini nom bilan emas, raqam bilan biladi: **UID** (user ID) va **GID** (group ID). Nomlar faqat odam uchun, ular oddiy matn fayllarda raqamga bog'lanadi.

### Mexanizm

Har jarayon (9-dars) o'zi bilan uchta narsani olib yuradi: UID, asosiy GID va qo'shimcha guruhlar ro'yxati. Har faylda (6-dars) egasining UID'i va guruhining GID'i yozilgan. Jarayon faylni ochmoqchi bo'lganda kernel shu raqamlarni solishtiradi, nomlarga qaramaydi. `ls -l` da ko'rinadigan `ubuntu` nomi aslida `ls` ning `/etc/passwd` dan raqamni nomga tarjima qilgani; `ls -ln` raqamning o'zini ko'rsatadi.

### /etc/passwd

Foydalanuvchilar ro'yxati. Hammaga o'qishga ochiq, har qatorda ikki nuqta bilan ajratilgan 7 maydon:

```
ubuntu@lab:~$ getent passwd ubuntu
ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash
```

| # | Qiymat | Maydon | Izoh |
|---|--------|--------|------|
| 1 | `ubuntu` | login nomi | |
| 2 | `x` | parol | `x` degani parol hash'i `/etc/shadow` da |
| 3 | `1000` | UID | |
| 4 | `1000` | asosiy guruh GID | yangi fayllar shu guruh bilan yaratiladi |
| 5 | `Ubuntu` | GECOS | to'liq ism va izoh, erkin matn |
| 6 | `/home/ubuntu` | home katalog | login'dan keyin shu yerga tushasiz, `~` shu |
| 7 | `/bin/bash` | login shell | kirganda ishga tushadigan dastur; `/usr/sbin/nologin` bo'lsa interaktiv kirib bo'lmaydi |

UID oraliqlari (`/etc/login.defs` dagi `UID_MIN`, `SYS_UID_MIN` bilan belgilanadi):

| UID | Kim |
|-----|-----|
| 0 | `root`. Kernel uchun maxsus bo'lgan narsa nom emas, aynan UID 0: unga ruxsat tekshiruvlari qo'llanmaydi |
| 1–999 | tizim va servis akkauntlari (`www-data`, `sshd`, `postgres`) |
| 1000+ | oddiy foydalanuvchilar |
| 65534 | `nobody` |

### /etc/shadow

Parol hash'lari va muddatlari. **Hash** bu paroldan bir tomonlama funksiya bilan olingan satr: paroldan hash hisoblanadi, hash'dan parolni qaytarib bo'lmaydi. Faylni faqat root (va `shadow` guruhi) o'qiydi. 9 maydon:

```
erin:$y$j9T$<salt>$<hash>:<kunlar>:0:99999:7:::
```

| # | Maydon | Izoh |
|---|--------|------|
| 1 | login nomi | |
| 2 | parol hash'i | `$y$` yescrypt, `$6$` SHA-512. `!` yoki `*` bilan boshlansa parol bilan kirib bo'lmaydi |
| 3 | oxirgi o'zgartirilgan kun | 1970-01-01 dan beri kunlarda. `0` bo'lsa keyingi kirishda almashtirish majburiy |
| 4 | minimal yosh | parolni qayta o'zgartirishgacha kutiladigan kunlar |
| 5 | maksimal yosh | necha kundan keyin eskiradi (`99999` amalda hech qachon) |
| 6 | ogohlantirish | eskirishdan necha kun oldin |
| 7 | inactive | eskirgandan keyin akkaunt bloklanguncha kunlar |
| 8 | akkaunt tugash sanasi | kunlarda. Parolga emas, butun akkauntga tegishli |
| 9 | zaxira | ishlatilmaydi |

Hash formati `$id$salt$hash`. **Salt** bu har foydalanuvchiga qo'shiladigan tasodifiy satr: shu tufayli bir xil parollar har xil hash beradi va oldindan hisoblangan jadvallar foyda bermaydi. Backend'da parolni `bcrypt` bilan saqlash g'oyasi aynan shu, faqat bu yerda tizim darajasida.

### /etc/group

```
ubuntu@lab:~$ getent group sudo
sudo:x:27:ubuntu
```

Maydonlar: guruh nomi, parol (ishlatilmaydi), GID, **qo'shimcha** a'zolar ro'yxati (vergul bilan). Har foydalanuvchining bitta **asosiy guruhi** bor (primary, `/etc/passwd` ning 4-maydoni) va istalgancha **qo'shimcha guruhi** (supplementary, `/etc/group` ning 4-maydoni). Asosiy guruh `/etc/group` da a'zo sifatida ko'rinmaydi. Ubuntu va RHEL har yangi foydalanuvchiga o'zi bilan bir nomli shaxsiy guruh yaratadi (user private group).

### Misol: o'qish asboblari

```
ubuntu@lab:~$ id
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),27(sudo),<boshqa guruhlar>
ubuntu@lab:~$ id -un ; id -u
ubuntu
1000
```

`id` chiqishini o'qish: `uid=1000(ubuntu)` raqam va qavsda nomi; `gid=1000(ubuntu)` asosiy guruh; `groups=` to'liq ro'yxat, birinchisi asosiy guruh, qolganlari qo'shimcha. `adm` guruhi loglarni o'qish huquqini beradi (1-darsda `journalctl -k` shu tufayli ishlagan), `sudo` guruhi administrator huquqini (3-bo'lim). `id -un` faqat nom, `id -u` faqat raqam, skriptlarda qulay.

| Buyruq | Nima ko'rsatadi |
|--------|-----------------|
| `id <user>` | UID, GID, barcha guruhlar (fayllardan o'qiydi) |
| `id` (argumentsiz) | **joriy jarayonning** haqiqiy kimligi |
| `getent passwd <user>`, `getent group <guruh>` | bazadan qator, manba qayerda bo'lishidan qat'i nazar |
| `groups <user>` | faqat guruh nomlari |
| `who`, `w` | hozir kim kirgan |
| `last -n 10` | oxirgi 10 ta kirish tarixi |

`getent` (get entries) **NSS** orqali qidiradi. NSS (Name Service Switch) bu "foydalanuvchini qayerdan qidirish kerak" degan sozlama (`/etc/nsswitch.conf`): fayllar, LDAP, `sssd` va hokazo. Fayllarni `grep` qilish o'rniga `getent` ishlating: korporativ muhitda foydalanuvchilar markaziy katalogdan keladi va `/etc/passwd` da bo'lmaydi.

### Real ishda qachon kerak

- "Permission denied" ni tekshirishda birinchi ikki buyruq: `id` (men kimman) va `ls -ld <yo'l>` (bu kimniki).
- Docker'da volume fayllari "noto'g'ri egaga" o'tib qolishi: konteyner ichidagi UID 1000 host'da ham UID 1000, nomlar esa har tomonda o'z `/etc/passwd` idan o'qiladi.
- Xavfsizlik tekshiruvi: kim interaktiv kira oladi (7-maydon), kimda UID 0, kimning paroli muddatsiz.

### Nima uchun shunday

Dastlabki Unix'da hash `/etc/passwd` ning ikkinchi maydonida turardi. Lekin bu faylni hamma o'qishi shart (`ls -l` nomlarni shu yerdan oladi), demak hash'larni ham hamma o'qib, oflayn tanlab ko'rishi mumkin edi. 1980-yillar oxirida hash'lar faqat root o'qiydigan `/etc/shadow` ga ko'chirildi, eski maydonda `x` qoldi. Raqamli UID esa tezlik va soddalik uchun: kernel satrlarni solishtirmaydi va nomni o'zgartirish fayllarga tegmaydi. Oddiy matn fayl formati 50 yildan beri o'zgarmagan, chunki uni `awk`, `grep`, `cut` bilan o'qish mumkin (7-dars). Muqobili markaziy katalog (LDAP, FreeIPA, Active Directory): yuzlab serverda bitta foydalanuvchilar bazasi, NSS aynan shuni ulash uchun kiritilgan.

## 2. Foydalanuvchi yaratish, o'zgartirish, o'chirish

### Bu nima

Foydalanuvchi yaratish aslida bir nechta faylga qator qo'shish: `/etc/passwd`, `/etc/shadow`, `/etc/group`, va home katalogni yaratish. Buni qo'lda emas, `shadow-utils` oilasidagi buyruqlar qiladi: ular fayllarni bloklaydi, bo'sh UID tanlaydi va formatni buzmaydi.

### useradd va adduser

| | `useradd` | `adduser` |
|---|-----------|-----------|
| Nima | past darajali standart asbob, hamma distributivda | Debian/Ubuntu'da interaktiv o'ram (parol, ism so'raydi, home yaratadi) |
| RHEL oilasida | home'ni standart yaratadi (`CREATE_HOME yes`) | `useradd` ga symlink |
| Ubuntu'da standart holat | `-m` siz home yaratmaydi, shell `/bin/sh` | home yaratadi, shell `/bin/bash` |
| Skriptda | shu ishlatiladi | interaktiv bo'lgani uchun noqulay |

`useradd` flag'lari:

| Flag | Ma'nosi |
|------|---------|
| `-m` | home katalogni yaratadi va ichiga `/etc/skel` dagi fayllarni nusxalaydi |
| `-s <shell>` | login shell |
| `-c "<matn>"` | GECOS (izoh) maydoni |
| `-G g1,g2` | qo'shimcha guruhlar |
| `-g <guruh>` | asosiy guruh |
| `-u <UID>` | aniq UID |
| `-e <YYYY-MM-DD>` | akkaunt tugash sanasi |
| `-r`, `--system` | tizim akkaunti (5-bo'lim) |

`/etc/skel` (skeleton) yangi home uchun shablon katalog: ichidagi `.bashrc`, `.profile` har yangi foydalanuvchiga nusxalanadi. `npm init` shablonidan `package.json` paydo bo'lishiga o'xshaydi. Standart qiymatlarni `useradd -D` va `/etc/login.defs` ko'rsatadi.

### Misol: foydalanuvchi yaratish

```
ubuntu@lab:~$ sudo useradd -m -s /bin/bash -c "Erin Example" erin
ubuntu@lab:~$ getent passwd erin
erin:x:<UID>:<GID>:Erin Example:/home/erin:/bin/bash
ubuntu@lab:~$ ls -la /home/erin
total <N>
drwxr-x--- 2 erin erin 4096 <sana> .
drwxr-xr-x 4 root root 4096 <sana> ..
-rw-r--r-- 1 erin erin  220 <sana> .bash_logout
-rw-r--r-- 1 erin erin 3771 <sana> .bashrc
-rw-r--r-- 1 erin erin  807 <sana> .profile
ubuntu@lab:~$ sudo passwd -S erin
erin L <sana> 0 99999 7 -1
```

Qatorma-qator: `useradd` muvaffaqiyatli bo'lsa hech narsa chiqarmaydi. `getent` qatorida UID birinchi bo'sh raqam (odatda oldingi foydalanuvchidan keyingisi), GID shu nomli yangi shaxsiy guruh. `/home/erin` huquqi `drwxr-x---` (`750`): boshqalar kira olmaydi, bu Ubuntu'ning `HOME_MODE` sozlamasi. Uchta nuqtali fayl `/etc/skel` dan kelgan, egasi `erin`. `passwd -S` maydonlari: nom, holat (`L` locked, `P` parol bor, `NP` parolsiz), oxirgi o'zgarish sanasi, keyin shadow'ning 4–7 maydonlari. `L` chunki parol hali o'rnatilmagan: yangi akkauntga parol bilan kirib bo'lmaydi, bu xavfsiz standart.

Parol o'rnatish: `sudo passwd erin` (ikki marta so'raydi, ekranda ko'rinmaydi). Bu misolni tugatgach tozalang: `sudo userdel -r erin`.

**Tuzoq: Ubuntu'da flag'siz `useradd`.** Home katalog yaratilmaydi va shell `/bin/sh` bo'ladi. Skriptda har doim `-m -s /bin/bash` ni aniq yozing, shunda Debian va RHEL oilalarida bir xil ishlaydi.

### usermod va guruhlar

```
sudo usermod -aG <guruh> <user>           # append to a supplementary group
sudo usermod -s /usr/sbin/nologin <user>  # change the login shell
sudo usermod -L <user>                    # lock the password
sudo usermod -U <user>                    # unlock
sudo gpasswd -d <user> <guruh>            # remove from a group
sudo groupadd <guruh> ; sudo groupdel <guruh>
```

**Tuzoq: `-G` ni `-a` siz yozish.** `-G` qo'shimcha guruhlar ro'yxatini **o'rnatadi**, `-a` (append) esa "mavjudlariga qo'sh" degani. `-a` siz buyruq foydalanuvchini ro'yxatda yo'q hamma guruhdan chiqaradi. `sudo` guruhidan chiqib qolgan administrator shu xatoning klassik qurboni. JS'dagi `arr = [x]` va `arr.push(x)` farqi kabi.

**Mexanizm: guruh a'zoligi darhol kuchga kirmaydi.** Jarayon guruhlar ro'yxatini login paytida oladi va bolalariga meros qoldiradi (9-dars). `usermod` faqat faylni o'zgartiradi, ishlab turgan jarayonlarga tegmaydi. Shuning uchun `id <user>` (fayldan o'qiydi) yangi guruhni ko'rsatadi, o'sha foydalanuvchining ochiq shell'idagi argumentsiz `id` esa yo'q. Yechim: chiqib qayta kirish. Vaqtinchalik: `newgrp <guruh>` yangi guruh bilan yangi shell ochadi.

### userdel

`sudo userdel <user>` faqat akkauntni o'chiradi, `sudo userdel -r <user>` home va mail spool bilan birga. Home'dan tashqaridagi fayllar qoladi va `ls -l` da egasi nom o'rniga raqam bo'lib ko'rinadi, chunki raqamni nomga tarjima qiladigan qator endi yo'q. Keyinroq shu UID bilan yangi foydalanuvchi yaratilsa, u eski fayllarning egasi bo'lib qoladi. Egasiz fayllarni topish: `sudo find / -xdev -nouser` (`-xdev` boshqa fayl tizimlariga, masalan `/proc` ga o'tmaydi).

### passwd va chage

| Buyruq | Nima qiladi |
|--------|-------------|
| `passwd` | o'z parolini o'zgartirish |
| `sudo passwd <user>` | boshqaning parolini o'rnatish |
| `sudo passwd -S <user>` | holat: `P`, `L`, `NP` |
| `sudo passwd -l <user>` / `-u` | parolni bloklash (hash oldiga `!` qo'yadi) va ochish |
| `sudo chage -l <user>` | parol va akkaunt muddati ma'lumotlari |
| `sudo chage -M 90 -W 14 <user>` | 90 kunda eskiradi, 14 kun oldin ogohlantiradi |
| `sudo chage -d 0 <user>` | keyingi kirishda parolni almashtirishga majburlash |
| `sudo chage -E 2027-12-31 <user>` | akkaunt tugash sanasi (`-E -1` olib tashlaydi) |

`chage` (change age) shadow'ning 3–8 maydonlarini tahrirlaydi. `chage -l` chiqishi shu maydonlarning odam o'qiydigan ko'rinishi:

```
ubuntu@lab:~$ sudo chage -l erin
Last password change                                    : <sana>
Password expires                                        : never
Password inactive                                       : never
Account expires                                         : never
Minimum number of days between password change          : 0
Maximum number of days between password change          : 99999
Number of days of warning before password expires       : 7
```

Birinchi qator 3-maydon; `Password expires` 3- va 5-maydonlardan hisoblanadi (`99999` kun bo'lgani uchun `never`); `Password inactive` 7-maydon; `Account expires` 8-maydon; oxirgi uch qator 4-, 5-, 6-maydonlar.

**Tuzoq: `passwd -l` SSH kalitni to'xtatmaydi.** Parolni bloklash faqat parol bilan kirishni yopadi, `~/.ssh/authorized_keys` dagi kalit bilan kirish davom etadi (4-bo'lim). Akkauntni to'liq yopish uchun uni muddati tugagan qilinadi: `sudo usermod -L -e 1 <user>` (tugash sanasi 1970-yil 2-yanvar, ya'ni o'tib ketgan) yoki `sudo chage -E 0 <user>`. Keyin ishlab turgan sessiya va jarayonlar tekshiriladi: `who`, `pgrep -u <user>` (9-dars).

### Real ishda qachon kerak

- Jamoaga yangi odam qo'shildi (onboarding) yoki ketdi (offboarding): bu darsning 18- va 19-vazifalari.
- Dockerfile'dagi `RUN useradd ...` va `USER app` qatorlari: konteynerda ham dastur root bo'lmasligi kerak.
- Ansible'ning `user` moduli ichkarida aynan shu buyruqlarni chaqiradi.

### Nima uchun shunday

`useradd` ning Ubuntu'dagi "bo'sh" standartlari tarixiy: u past darajali asbob, siyosatni (home kerakmi, qaysi shell) chaqiruvchi hal qiladi deb o'ylangan, qulay o'ram sifatida esa Debian `adduser` ni yozgan. Red Hat boshqa yo'l tanladi va siyosatni `/etc/login.defs` ga qo'ydi. Natija: bir xil buyruq ikki oilada ikki xil ishlaydi, shuning uchun flag'larni aniq yozish odat bo'lishi kerak. Guruhlarning login paytida olinishi ham ataylab: har fayl ochilishida `/etc/group` ni qayta o'qish sekin bo'lardi va jarayon huquqlari ish paytida kutilmaganda o'zgarib qolardi.

## 3. sudo va sudoers

### Bu nima

Kundalik ishda hech kim root bo'lib o'tirmaydi: bitta xato buyruq butun tizimni buzadi va kim nima qilgani bilinmaydi. Buning o'rniga oddiy foydalanuvchi sifatida ishlanadi, root huquqi esa faqat kerakli buyruq uchun olinadi. Ikki asbob bor: `su` (substitute user, boshqa foydalanuvchiga o'tish) va `sudo` (bitta buyruqni boshqa foydalanuvchi, odatda root nomidan bajarish).

| | `su - <user>` | `sudo <cmd>` |
|---|-------------|------------|
| Kimning paroli | **maqsad** foydalanuvchining | **o'zingizning** |
| Root paroli kerakmi | ha, uni hamma administrator bilishi kerak | yo'q, root paroli umuman bo'lmasligi mumkin |
| Huquq doirasi | to'liq shell | aniq buyruqlargacha cheklash mumkin |
| Audit | faqat "kim `su` qildi" | har buyruq logga yoziladi |

`su <user>` (defissiz) environment'ni saqlab qoladi, `su - <user>` to'liq login shell ochadi (home'ga o'tadi, `PATH` yangilanadi). Ubuntu'da `root` paroli standart holatda bloklangan, root huquqi faqat `sudo` orqali.

### Mexanizm

`sudo` binary'sida **setuid** biti bor (6-dars): uni kim ishga tushirsa ham jarayon root huquqi bilan boshlanadi. Keyin `sudo` o'zi qaror qiladi: `sudoers` qoidalarini o'qiydi, sizni (chaqiruvchini) topadi, kerak bo'lsa parolingizni so'raydi, ruxsat bo'lsa buyruqni ishga tushiradi, bo'lmasa rad etadi va logga yozadi. To'g'ri kiritilgan parol bir necha daqiqa eslab qolinadi.

```
ubuntu@lab:~$ ls -l /usr/bin/sudo
-rwsr-xr-x 1 root root <hajm> <sana> /usr/bin/sudo
```

`rws` dagi `s` setuid biti, egasi `root`. Shu bit bo'lmasa `sudo` oddiy dastur bo'lib qolardi.

Foydali shakllar:

| Buyruq | Ma'nosi |
|--------|---------|
| `sudo -i` | root login shell |
| `sudo -u <user> <cmd>` | root emas, boshqa foydalanuvchi nomidan |
| `sudo -l` | menga nima ruxsat berilgan |
| `sudo -l -U <user>` | boshqaga nima ruxsat berilgan (root uchun) |
| `sudo -n <cmd>` | parol so'ramaslik; parol kerak bo'lsa xato bilan chiqadi (skriptlar uchun) |
| `sudo -k` | eslab qolingan parolni unutish |

### sudoers sintaksisi

Qoidalar `/etc/sudoers` va `/etc/sudoers.d/` dagi fayllarda:

```
# who   where=(as whom)     what
root    ALL=(ALL:ALL)       ALL
%sudo   ALL=(ALL:ALL)       ALL
erin    ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx, /usr/bin/systemctl status nginx
```

- Birinchi maydon foydalanuvchi yoki `%guruh`. Ikkinchi qator: `sudo` guruhining har a'zosi hamma narsani qila oladi.
- `ALL=` qaysi hostda (bitta `sudoers` ko'p serverga tarqatilganda ma'noli, odatda `ALL`).
- `(root)` yoki `(ALL:ALL)` kimning nomidan (`foydalanuvchi:guruh`).
- `NOPASSWD:` parol so'ramaslik. Avtomatlashtirish uchun kerak, lekin faqat aniq buyruqlar bilan.
- Buyruqlar to'liq yo'l bilan, vergul bilan ajratiladi. Argument yozilsa faqat aynan shu argumentlar bilan ruxsat.
- Bir nechta qoida mos kelsa **oxirgisi** yutadi.

Administrator guruhi Ubuntu'da `sudo`, RHEL oilasida `wheel`. `lab` VM'da `ubuntu` foydalanuvchisi parolsiz `sudo` qila oladi, chunki cloud-init (bulut image'larini birinchi yuklashda sozlaydigan asbob) `/etc/sudoers.d/` ga shunday qoida yozgan. Bu laboratoriya qulayligi, haqiqiy serverda bunday qoldirilmaydi.

### visudo va sudoers.d

`sudoers` ni hech qachon oddiy editor bilan ochmang. `visudo` faylning vaqtinchalik nusxasini ochadi, saqlashda sintaksisni tekshiradi va faqat to'g'ri bo'lsa joyiga qo'yadi. Xato bilan saqlangan `sudoers` hamma uchun `sudo` ni o'chiradi; root paroli yo'q serverda bu "eshik ichkaridan qulflandi" degani.

```
ubuntu@lab:~$ sudo visudo -c
/etc/sudoers: parsed OK
/etc/sudoers.d/90-cloud-init-users: parsed OK
/etc/sudoers.d/README: parsed OK
```

`-c` (check) barcha fayllarni tekshiradi, har fayl uchun bitta qator; sizda fayl nomlari boshqacha bo'lishi mumkin. `sudo visudo -f /etc/sudoers.d/<nom>` alohida faylni xavfsiz tahrirlaydi. `visudo` qaysi editorni ochishi `EDITOR` o'zgaruvchisi va tizim standartiga bog'liq (Ubuntu'da odatda `nano`).

O'z qoidalaringizni asosiy faylga emas, `/etc/sudoers.d/` ga alohida fayl qilib yozing: huquqi `0440`, egasi root. Nomida nuqta bo'lgan yoki `~` bilan tugaydigan fayllar o'qilmaydi. Bu nginx'ning `conf.d` yoki ESLint'ning bir nechta config faylini birlashtirishi kabi **drop-in** uslubi: paket yangilanganda asosiy fayl almashtiriladi, sizning faylingizga tegilmaydi.

**Tuzoq: shell'ga chiqish imkonini beradigan buyruqlar.** `NOPASSWD: /usr/bin/vim` amalda to'liq root: `vim` ichidan `:!bash` ishlaydi va u shell root bo'ladi. Pager'lar, `find` (`-exec`), `tar`, `awk`, `python`, `docker` ham shunday. Ruxsat ro'yxatiga faqat argumentlari bilan qat'iy belgilangan buyruqlar kirsin. `docker` guruhiga a'zolik ham amalda root huquqi (konteynerga host'ning `/` ini mount qilish mumkin).

`sudo` chaqiruvlari `/var/log/auth.log` ga (RHEL'da `/var/log/secure`) va journal'ga yoziladi: kim, qaysi terminaldan, qaysi katalogda, qaysi buyruqni. O'qish: `sudo journalctl -t sudo -n 20` yoki `sudo grep sudo /var/log/auth.log`.

### Real ishda qachon kerak

- CI/CD deploy foydalanuvchisi faqat o'z servisini qayta ishga tushira olsin, boshqa hech narsa.
- Dasturchilarga loglarni o'qish yoki bitta servis holatini ko'rish huquqi, to'liq root'siz.
- Hodisa tahlili: "kecha soat 3 da servisni kim to'xtatdi" savoliga `sudo` logi javob beradi.

### Nima uchun shunday

`sudo` 1980-yillarda universitet serverlarida paydo bo'lgan: root parolini o'nlab odamga tarqatmaslik va kim nima qilganini bilish uchun. Asosiy g'oya **eng kam huquq tamoyili** (least privilege): har kimga faqat ishi uchun kerak bo'lgan huquq. Ubuntu root parolini umuman bloklab, hamma narsani `sudo` orqali o'tkazadi; RHEL o'rnatishda root paroli so'raydi, lekin u yerda ham `wheel` guruhi afzal. `visudo` ning mavjudligi tajribadan: `sudoers` xatosi o'zini tuzatish vositasini ham o'chiradi, shuning uchun tekshiruv saqlashdan oldin bo'lishi shart. Muqobillari: `doas` (OpenBSD'dan, sintaksisi soddaroq), `pkexec` (polkit), systemd'ning `run0` buyrug'i.

## 4. SSH kalit bilan kirish

### Bu nima

**SSH** (Secure Shell) masofadagi mashinaga shifrlangan kanal orqali kirish protokoli; serverda `sshd` dasturi tinglaydi, mijozda `ssh` buyrug'i ulanadi. Kirishning ikki usuli bor: parol va **kalit jufti**. Kalit jufti ikki fayl: **private kalit** faqat sizda qoladi, **public kalit** serverga beriladi. GitHub'ga `git push` uchun SSH kalit qo'shgan bo'lsangiz, bu aynan o'sha mexanizm: GitHub o'rnida sizning serveringiz.

### Mexanizm

Public kalit serverda foydalanuvchining `~/.ssh/authorized_keys` fayliga yoziladi, har qatorda bitta kalit. Kirishda mijoz "menda shu public kalitning private jufti bor" deydi; server tasodifiy ma'lumotni imzolashni so'raydi; mijoz private kalit bilan imzolaydi; server imzoni public kalit bilan tekshiradi. Private kalit tarmoqqa chiqmaydi, serverda saqlanmaydi, shuning uchun server buzilsa ham kalitingiz o'g'irlanmaydi. Parol esa har kirishda serverga yuboriladi va uni tanlab topish mumkin.

Bu darsda host mijoz, `lab` VM server:

```
host (Zorin or macOS)                      lab VM
~/.ssh/id_ed25519      (private)           /home/<user>/.ssh/authorized_keys
~/.ssh/id_ed25519.pub  (public)   ----->   (a copy of the .pub line)
```

### Misol: kalit yaratish (host'da, ikkala mashinada bir xil)

```
$ ls ~/.ssh/id_ed25519.pub        # check first: do not overwrite an existing key
$ ssh-keygen -t ed25519 -C "<siz>@<mashina>"
Generating public/private ed25519 key pair.
Enter file in which to save the key (<home>/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
...
$ cat ~/.ssh/id_ed25519.pub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA<...> <siz>@<mashina>
```

`-t ed25519` kalit turi (zamonaviy, qisqa va tez), `-C` izoh, qaysi kalit kimniki ekanini keyin ajratish uchun. Birinchi savolda Enter bossangiz standart yo'l qoladi. **Passphrase** kalit faylini shifrlaydigan parol: fayl o'g'irlansa ham ishlatib bo'lmaydi, qo'ying. `.pub` fayl bitta qator, uch qism: tur, kalitning o'zi, izoh. Kalit allaqachon bor bo'lsa (masalan GitHub uchun) yangisini yaratmang, o'shani ishlating.

### Serverda kalitni o'rnatish

Odatda `ssh-copy-id` ishlatiladi, lekin u parol bilan kirib kalitni ko'chiradi. Bulut serverlarida va `lab` VM'da parol bilan kirish yopiq, shuning uchun administrator (`ubuntu`) kalitni qo'lda qo'yadi:

```
sudo install -d -m 700 -o <user> -g <user> /home/<user>/.ssh
sudo nano /home/<user>/.ssh/authorized_keys      # paste the .pub line, one key per line
sudo chown <user>:<user> /home/<user>/.ssh/authorized_keys
sudo chmod 600 /home/<user>/.ssh/authorized_keys
```

`install -d` katalogni bir yo'la egasi (`-o`), guruhi (`-g`) va huquqi (`-m`) bilan yaratadi: `mkdir`, `chown`, `chmod` uchligining o'rniga. `sudo` bilan yaratilgan fayl egasi root bo'ladi, shuning uchun `chown` shart.

Huquqlar majburiy: `sshd` ning `StrictModes` sozlamasi (standart `yes`) home, `~/.ssh` yoki `authorized_keys` boshqalar yoza oladigan bo'lsa yoki egasi noto'g'ri bo'lsa, kalitni rad etadi. Sabab: boshqa foydalanuvchi bu faylga yoza olsa, o'z kalitini qo'shib sizning nomingizdan kira oladi.

| Yo'l | Huquq | Egasi |
|------|-------|-------|
| `~` (home) | guruh va boshqalar yoza olmasin (masalan `750`) | foydalanuvchi |
| `~/.ssh` | `700` | foydalanuvchi |
| `~/.ssh/authorized_keys` | `600` | foydalanuvchi |
| `~/.ssh/id_ed25519` (mijozda) | `600` | foydalanuvchi |

### Kirish va diagnostika

```
$ multipass info lab | grep IPv4          # on the host: find the VM address
$ ssh <user>@<VM_IP>                       # on the host
$ ssh -v <user>@<VM_IP>                    # client side: which keys are offered
ubuntu@lab:~$ sudo journalctl -u ssh -n 20 # server side: why it was rejected
```

Birinchi ulanishda `ssh` serverning host kalitini ko'rsatib `Are you sure you want to continue connecting (yes/no/[fingerprint])?` deb so'raydi: bu server kimligini eslab qolish, `yes` dan keyin u `~/.ssh/known_hosts` ga yoziladi. Rad etilganda mijoz faqat `Permission denied (publickey).` ni ko'radi, sabab ataylab aytilmaydi (hujumchiga ma'lumot bermaslik uchun). Haqiqiy sabab har doim server logida, masalan `Authentication refused: bad ownership or modes for directory /home/<user>/.ssh`.

`sshd` sozlamalari `/etc/ssh/sshd_config` va `/etc/ssh/sshd_config.d/*.conf` da. Muhimlari: `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`. Har kalit so'z uchun birinchi uchragan qiymat kuchga kiradi. Amaldagi yakuniy qiymatlarni `sudo sshd -T` chiqaradi. O'zgartirgandan keyin `sudo sshd -t` bilan sintaksisni tekshiring, keyin `sudo systemctl reload ssh` (RHEL'da unit nomi `sshd`). SSH'ni mustahkamlash tarmoq va xavfsizlik darslarida davom etadi; bu darsda sozlamani faqat o'qiysiz.

### Real ishda qachon kerak

- Har bulut serveriga birinchi kirish kalit bilan: AWS, Hetzner, DigitalOcean serverni yaratishda public kalitingizni so'raydi.
- CI/CD (GitHub Actions, GitLab CI) serverga deploy qilishda `deploy` foydalanuvchisining kaliti bilan kiradi.
- Ansible butunlay SSH ustida ishlaydi.

### Nima uchun shunday

Parollar internetga ochiq serverda yashay olmaydi: har ochiq 22-portga botlar kuniga minglab parol sinaydi. Kalit esa amalda tanlab topilmaydi va serverda maxfiy narsa saqlanmaydi. `ed25519` 2014-yildan OpenSSH'da; eski `rsa` kalitlari hali ishlaydi, lekin uzunroq va sekinroq. Huquqlarni qat'iy tekshirish (`StrictModes`) noqulay tuyuladi, lekin u ko'p foydalanuvchili serverda bitta `chmod 777` butun akkauntni ochib qo'ymasligi uchun. Katta tashkilotlardagi muqobil: SSH sertifikatlari (kalitlarni markaziy CA imzolaydi, muddati bilan) yoki bulutning o'z vositalari (AWS SSM Session Manager), ular `authorized_keys` fayllarini qo'lda tarqatishni yo'qotadi.

## 5. Servis akkauntlari

### Bu nima

**Servis akkaunt** bu odam uchun emas, dastur uchun yaratilgan foydalanuvchi: unga hech kim login qilmaydi, u faqat jarayonning "kimligi" bo'lib xizmat qiladi. Dastur root sifatida ishlamasligi kerak: undagi bitta zaiflik butun serverni beradi. Har servisga o'z akkaunti yaratiladi, u faqat o'z fayllariga ega.

### Mexanizm

Servis akkaunt oddiy foydalanuvchidan uch narsa bilan farq qiladi: UID tizim oralig'idan (1000 dan past), home katalogi yo'q (yoki ma'lumot katalogi `/var/lib/<nom>`), login shell'i `/usr/sbin/nologin`. `nologin` bu shell o'rnida turadigan kichik dastur: xabar chiqaradi va darhol chiqadi. Login shu dasturni ishga tushirgani uchun interaktiv sessiya ochilmaydi. Lekin jarayonni shu foydalanuvchi nomidan boshlash login emas: root (yoki systemd) jarayon UID'ini to'g'ridan-to'g'ri o'rnatadi, shell umuman ishtirok etmaydi.

### Misol

```
ubuntu@lab:~$ sudo useradd --system --no-create-home --shell /usr/sbin/nologin reportd
ubuntu@lab:~$ getent passwd reportd
reportd:x:<999 yoki undan past>:<GID>::/home/reportd:/usr/sbin/nologin
ubuntu@lab:~$ sudo su - reportd
This account is currently not available.
ubuntu@lab:~$ sudo -u reportd id -un
reportd
```

Qatorma-qator: `--system` (`-r`) UID'ni tizim oralig'idan oladi va parol muddati qo'ymaydi. `getent` qatorida GECOS bo'sh (`::`); home maydonida `/home/reportd` yozilgan, lekin katalogning o'zi yaratilmagan (`ls -d /home/reportd` "No such file" deydi), maydon shunchaki bo'sh qola olmaydi. `su -` login shell'ni ishga tushirishga urinadi, u `nologin`, natija rad xabari. `sudo -u` esa shell'siz to'g'ridan-to'g'ri `id` ni shu UID bilan ishga tushiradi va ishlaydi. Misoldan keyin: `sudo userdel reportd`.

Akkauntga kerakli katalog bitta buyruq bilan beriladi:

```
sudo install -d -o <svc> -g <svc> -m 750 /var/lib/<svc>
```

Paketlar o'z servis akkauntlarini o'zi yaratadi (`www-data`, `postgres`, `redis`), siz faqat o'z dasturlaringiz uchun yaratasiz. RHEL oilasida `nologin` ning an'anaviy yo'li `/sbin/nologin`.

### Real ishda qachon kerak

- systemd unit'dagi `User=` qatori (11-dars): servis shu akkaunt nomidan ishlaydi.
- Dockerfile'dagi `USER node`: `node` rasmiy image'idagi tayyor servis akkaunt, konteynerda root bo'lmaslik uchun.
- Node ilovasini serverda `pm2` bilan o'z shaxsiy akkauntingizdan ishga tushirish o'rniga alohida akkaunt: ilova buzilsa, hujumchi sizning SSH kalitlaringiz va `sudo` huquqingizga yetmaydi.

### Nima uchun shunday

Bu ham eng kam huquq tamoyili, faqat odamlarga emas, dasturlarga qo'llangan. Web server buzilsa, hujumchi `www-data` bo'ladi: ma'lumotlar bazasi fayllarini (`postgres` niki) o'qiy olmaydi, tizim fayllarini o'zgartira olmaydi. Tarixan servislar root yoki umumiy `nobody` nomidan ishlagan; `nobody` ni bir nechta servis bo'lishsa, ular bir-birining fayllarini ko'radi, shuning uchun har servisga alohida akkaunt qoida bo'ldi. Zamonaviy muqobil: systemd'ning `DynamicUser=yes` sozlamasi servis ishga tushganda vaqtinchalik UID ajratadi (11-darsda eslatiladi), konteynerlarda esa user namespace.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| UID, GID | kernel foydalanuvchi va guruhni taniydigan raqamlar |
| root | UID 0 bo'lgan, ruxsat tekshiruvlari qo'llanmaydigan foydalanuvchi |
| Asosiy guruh (primary) | `/etc/passwd` ning 4-maydonidagi guruh, yangi fayllar shu guruh bilan yaratiladi |
| Qo'shimcha guruh (supplementary) | `/etc/group` orqali berilgan qolgan a'zoliklar |
| GECOS | `/etc/passwd` ning 5-maydoni, to'liq ism va izoh |
| Login shell | foydalanuvchi kirganda ishga tushadigan dastur, `/etc/passwd` ning 7-maydoni |
| `/etc/shadow` | parol hash'lari va muddatlari, faqat root o'qiydi |
| Hash, salt | paroldan bir tomonlama olingan satr va uni takrorlanmas qiladigan tasodifiy qo'shimcha |
| NSS | foydalanuvchi va guruhlarni qayerdan qidirishni belgilaydigan qatlam, `getent` shu orqali ishlaydi |
| `/etc/skel` | yangi home katalogga nusxalanadigan shablon fayllar |
| Password aging | parolning yoshi va eskirish qoidalari, `chage` boshqaradi |
| `su` | boshqa foydalanuvchiga o'tish, maqsad foydalanuvchining parolini so'raydi |
| `sudo` | bitta buyruqni boshqa foydalanuvchi (odatda root) nomidan, o'z parolingiz bilan bajarish |
| `sudoers` | kim, qayerda, kimning nomidan, nimani bajara olishi yozilgan qoidalar |
| `visudo` | `sudoers` ni sintaksis tekshiruvi bilan tahrirlaydigan asbob |
| Drop-in | asosiy config'ga tegmasdan `*.d/` katalogiga qo'shiladigan alohida fayl |
| `NOPASSWD` | qoidadagi buyruqlar uchun parol so'ralmasligi |
| Least privilege | har kimga va har dasturga faqat ishi uchun kerak bo'lgan huquq |
| SSH | masofadagi mashinaga shifrlangan kanal orqali kirish protokoli |
| Private, public kalit | juftning maxfiy yarmi (faqat mijozda) va ochiq yarmi (serverga beriladi) |
| `authorized_keys` | serverda shu akkauntga kirishga ruxsat etilgan public kalitlar ro'yxati |
| Passphrase | private kalit faylini shifrlaydigan parol |
| `StrictModes` | `sshd` ning `~/.ssh` egasi va huquqlarini tekshiradigan sozlamasi |
| Servis akkaunt | dastur uchun yaratilgan, login qila olmaydigan tizim foydalanuvchisi |
| `nologin` | shell o'rnida turib interaktiv kirishni rad etadigan dastur |

## Tuzoqlar

- `usermod -G` ni `-a` siz ishlatib, foydalanuvchini boshqa guruhlardan (shu jumladan `sudo` dan) chiqarib yuborish.
- Guruhga qo'shib, qayta login qilmasdan "ishlamayapti" deyish.
- `sudoers` ni `visudo` siz tahrirlash. Bitta sintaksis xatosi `sudo` ni hamma uchun o'chiradi; root paroli yo'q serverda bu konsol orqali tiklashni anglatadi.
- `/etc/sudoers.d/` dagi fayl nomiga nuqta qo'yish (`deploy.conf`): fayl jimgina o'qilmaydi.
- `NOPASSWD: ALL` ni qulaylik uchun berish, yoki shell'ga chiqish imkoni bor buyruqni (`vim`, `less`, `find`, `docker`) ruxsat ro'yxatiga qo'shish.
- `passwd -l` bilan akkauntni "yopdim" deb o'ylash: SSH kalit ishlayveradi.
- `~/.ssh` yoki `authorized_keys` huquqlari keng yoki egasi root bo'lib qolgani uchun kalit rad etilishi. `sudo` bilan yaratilgan fayl egasi root bo'ladi.
- SSH sozlamasini o'zgartirib, joriy sessiyani yopib qo'yish. Avval yangi terminalda kirib ko'ring, keyin eskisini yoping.
- Private kalitni serverga nusxalash, chatga yuborish yoki repo'ga commit qilish. Serverga faqat `.pub` boradi.
- Bir nechta odam bitta umumiy akkaunt va bitta kalitdan foydalanishi: kim nima qilganini bilib bo'lmaydi. Har odamga o'z akkaunti yoki kamida o'z kaliti.
- Dasturni root yoki o'z shaxsiy akkauntingiz nomidan ishga tushirish. Har servisga alohida `nologin` akkaunt.
- Bu darsdagi buyruqlarni VM o'rniga host'da bajarib qo'yish. Har o'zgartiruvchi buyruqdan oldin prompt'ga qarang: `ubuntu@lab` bo'lishi kerak.
- macOS host'ida `getent`, `useradd`, `date -d` qidirish: ular yo'q, VM'da bajaring.

## Manbalar

- https://man7.org/linux/man-pages/man5/passwd.5.html – passwd(5)
- https://man7.org/linux/man-pages/man5/shadow.5.html – shadow(5)
- https://man7.org/linux/man-pages/man8/useradd.8.html – useradd(8)
- https://man7.org/linux/man-pages/man8/usermod.8.html – usermod(8)
- https://man7.org/linux/man-pages/man1/chage.1.html – chage(1)
- https://www.sudo.ws/docs/man/sudoers.man/ – sudoers(5) rasmiy qo'llanma (majburiy: "SUDOERS FILE FORMAT" va misollar)
- https://www.sudo.ws/docs/man/visudo.man/ – visudo(8)
- https://man.openbsd.org/sshd_config – sshd_config(5)
- https://man.openbsd.org/ssh-keygen – ssh-keygen(1)
- https://documentation.ubuntu.com/server/how-to/security/user-management/ – Ubuntu Server: user management
- https://gtfobins.github.io/ – sudo orqali shell'ga chiqish imkonini beradigan buyruqlar ro'yxati
- https://documentation.ubuntu.com/multipass/ – Multipass hujjati (`info`, `transfer`, `snapshot`)

---

## Birga bajaramiz

Bitta yaxlit stsenariy: jamoaga uch oyga pudratchi `nora` keladi. Unga muddatli akkaunt, `audit` guruhi orqali umumiy katalog va bitta buyruqqa cheklangan `sudo` kerak; uning hisobot dasturi uchun `reportd` servis akkaunti kerak. Oxirida hammasini izsiz o'chiramiz. Hamma narsa VM ichida, `ubuntu` sifatida. Bu misol vazifalardagi nomlar va qoidalardan boshqa; SSH kaliti bu yurishda yo'q, uni 15-vazifada o'zingiz qilasiz.

1. Ikkinchi terminalni oching va root bo'lib turing (xavfsizlik to'ri), birinchi terminalda boshlang'ich holatni yozib oling:

```
# terminal 2
ubuntu@lab:~$ sudo -i
root@lab:~#

# terminal 1
ubuntu@lab:~$ sudo visudo -c
ubuntu@lab:~$ getent passwd nora reportd ; echo "exit=$?"
exit=2
```

`getent` hech narsa chiqarmadi va exit code `2` qaytardi: bunday akkauntlar yo'q, davom etish mumkin.

2. Guruh va muddatli foydalanuvchi:

```
ubuntu@lab:~$ sudo groupadd audit
ubuntu@lab:~$ sudo useradd -m -s /bin/bash -c "Nora (contractor)" -G audit -e 2027-01-31 nora
ubuntu@lab:~$ id nora
uid=<UID>(nora) gid=<GID>(nora) groups=<GID>(nora),<GID2>(audit)
ubuntu@lab:~$ sudo chage -l nora | grep 'Account expires'
Account expires                                         : Jan 31, 2027
```

`-G audit` yaratish paytida berilgani uchun `-a` kerak emas: yangi foydalanuvchida yo'qotadigan guruh yo'q. `-e` shadow'ning 8-maydonini to'ldiradi: shu sanadan keyin akkaunt o'zi yopiladi, uni o'chirishni unutib qo'ysangiz ham. Sanani bugundan keyingi sana qilib oling.

3. Umumiy katalog va uni `nora` nomidan sinash:

```
ubuntu@lab:~$ sudo install -d -m 2770 -g audit /srv/audit
ubuntu@lab:~$ ls -ld /srv/audit
drwxrws--- 2 root audit 4096 <sana> /srv/audit
ubuntu@lab:~$ sudo -u nora touch /srv/audit/q1.txt
ubuntu@lab:~$ sudo ls -l /srv/audit
total 0
-rw-rw-r-- 1 nora audit 0 <sana> q1.txt
ubuntu@lab:~$ ls /srv/audit
ls: cannot open directory '/srv/audit': Permission denied
```

`drwxrws---`: egasi root, guruhi `audit`, guruh ustunidagi `s` setgid biti (6-dars), shuning uchun ichidagi yangi fayl guruhi `nora` emas, `audit` bo'ldi. `sudo -u nora` har safar yangi jarayon boshlaydi va guruhlarni fayldan yangidan o'qiydi, shuning uchun bu yerda "qayta login" muammosi ko'rinmadi. Oxirgi buyruqda `ubuntu` rad etildi: u `audit` a'zosi emas, `sudo` guruhida bo'lishi fayl huquqlarini chetlab o'tmaydi, faqat `sudo` bilan chaqirilgan buyruq root bo'ladi.

4. Cheklangan `sudo` qoidasi. Editorda bitta qator yozib saqlang:

```
ubuntu@lab:~$ command -v apt-get
/usr/bin/apt-get
ubuntu@lab:~$ sudo visudo -f /etc/sudoers.d/nora-apt
# in the editor, one line:
nora ALL=(root) NOPASSWD: /usr/bin/apt-get update
ubuntu@lab:~$ sudo ls -l /etc/sudoers.d/nora-apt
-r--r----- 1 root root <N> <sana> /etc/sudoers.d/nora-apt
ubuntu@lab:~$ sudo -l -U nora
...
User nora may run the following commands on lab:
    (root) NOPASSWD: /usr/bin/apt-get update
```

`command -v` to'liq yo'lni beradi, `sudoers` da faqat to'liq yo'l yoziladi. `visudo -f` yangi faylni `0440` (`-r--r-----`) huquq bilan yaratdi, qo'lda `chmod` kerak bo'lmadi. `sudo -l -U nora` avval `Defaults` qatorlarini, keyin ruxsat etilgan buyruqlarni ko'rsatadi. Fayl nomida nuqta yo'qligiga e'tibor bering.

5. Qoidani `nora` nomidan sinang. `-n` parol so'ramaslikni bildiradi, shuning uchun ruxsat yo'q joyda buyruq osilib qolmaydi, xato bilan chiqadi:

```
ubuntu@lab:~$ sudo -u nora sudo -n /usr/bin/apt-get update | tail -1
Reading package lists...
ubuntu@lab:~$ sudo -u nora sudo -n /usr/bin/apt-get upgrade
sudo: a password is required
ubuntu@lab:~$ sudo journalctl -t sudo -n 5
```

Birinchi buyruq ishladi: argument qoidadagi bilan aynan bir xil. Ikkinchisi rad etildi: `upgrade` qoidada yo'q, `nora` da parol ham yo'q. Journal'da ikkala urinish ko'rinadi: kim (`nora`), qaysi katalogdan (`PWD=`), kim nomidan (`USER=root`), qaysi buyruq (`COMMAND=`).

6. Servis akkaunt va uning katalogi:

```
ubuntu@lab:~$ sudo useradd --system --no-create-home --shell /usr/sbin/nologin reportd
ubuntu@lab:~$ sudo install -d -o reportd -g reportd -m 750 /var/lib/reportd
ubuntu@lab:~$ sudo -u reportd touch /var/lib/reportd/state.db
ubuntu@lab:~$ sudo -u nora ls /var/lib/reportd
ls: cannot open directory '/var/lib/reportd': Permission denied
```

Dastur (`reportd`) o'z katalogiga yoza oladi, odam (`nora`) esa unga kira olmaydi: ikkalasi alohida kimlik.

7. Shartnoma tugadi. Avval yopamiz, keyin izlarni topamiz, keyin o'chiramiz:

```
ubuntu@lab:~$ sudo usermod -L -e 1 nora
ubuntu@lab:~$ pgrep -u nora ; who | grep nora
ubuntu@lab:~$ sudo grep -rl nora /etc/sudoers.d/
/etc/sudoers.d/nora-apt
ubuntu@lab:~$ sudo rm /etc/sudoers.d/nora-apt && sudo visudo -c
ubuntu@lab:~$ sudo userdel -r nora
ubuntu@lab:~$ sudo ls -ln /srv/audit
total 0
-rw-rw-r-- 1 <UID> <GID2> 0 <sana> q1.txt
```

`pgrep` va `who` bo'sh: ishlab turgan jarayon va sessiya yo'q. `userdel -r` home'ni o'chirdi, lekin `/srv/audit/q1.txt` qoldi va egasi endi yalang'och raqam: 2-bo'limdagi "egasiz fayl".

8. Qolganini tozalang va yakuniy holatni tekshiring:

```
ubuntu@lab:~$ sudo rm -r /srv/audit /var/lib/reportd
ubuntu@lab:~$ sudo userdel reportd
ubuntu@lab:~$ sudo groupdel audit
ubuntu@lab:~$ getent passwd nora reportd ; getent group audit ; sudo visudo -c
```

Uchala `getent` bo'sh, `visudo -c` hamma fayl uchun `parsed OK` desa, VM boshlang'ich holatda. Ikkinchi terminaldagi root sessiyani endi yopish mumkin.

---

## Vazifalar

Ish papkasi: `linux/10-users/` (`make new m=linux n=10 name=users` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni yoniga saqlang. Parol hash'lari, private kalitlar README'ga va repo'ga tushmasin (hash o'rniga `$y$...` deb qisqartiring). Aytilmagan bo'lsa VM'da bajaring. Vazifalardagi "ish mashinasi" host'ni bildiradi (Zorin yoki macOS). `Yo'nalish:` qatori qayerdan boshlashni aytadi, yechimni emas.

### A. Ma'lumot fayllari

1. **Who am I.** Ish mashinasida va VM'da `id`, `groups`, `getent passwd "$USER"` ni oling. `/etc/passwd` qatoringizdagi 7 maydonning har birini nomlang. Guruhlaringizdan `sudo`, `adm`, `docker` (bor bo'lsa) nima huquq berishini bir gapdan yozing. Yo'nalish: 1-bo'lim. macOS host'ida `getent` yo'q: `id` va `groups` ni oling, `getent` o'rniga `dscl . -read /Users/"$USER" UniqueID PrimaryGroupID NFSHomeDirectory UserShell` ni ishlating va 7 maydonni VM'dagi qatordan nomlang; Mac'da `sudo` va `adm` guruhlari yo'qligini qayd eting.

2. **Account inventory.** VM'da `/etc/passwd` dan 7-darsdagi `awk` bilan: UID 1000 va undan katta foydalanuvchilar ro'yxatini; login shell'lar bo'yicha akkauntlar sonini (`sort | uniq -c`) chiqaring. Nechta akkaunt interaktiv kira oladi? `nobody` ning UID'i va vazifasini yozing. Yo'nalish: `awk -F:` va maydon raqamlari 1-bo'limdagi jadvalda; "interaktiv" ni 7-maydon belgilaydi.

3. **shadow fields.** VM'da `sudo getent shadow ubuntu` va `sudo chage -l ubuntu` ni oling. Ikkinchi maydon nima bilan boshlanadi va bu nimani anglatadi (Multipass VM'da parol bormi)? 3-maydondagi sonni `date -d "1970-01-01 +N days"` bilan sanaga aylantiring. `/etc/shadow` ning fayl huquqlarini ko'rsating va nima uchun `/etc/passwd` dan farq qilishini izohlang. Yo'nalish: 1-bo'limdagi shadow jadvali va "Nima uchun shunday". `date -d` GNU flag'i, VM'da bajaring. Hash'ni README'ga ko'chirmang.

### B. Yaratish va o'zgartirish

4. **useradd defaults.** VM'da `sudo useradd alice` (flag'siz) bajaring. `getent passwd alice`, `ls -ld /home/alice`, `sudo passwd -S alice` natijalarini yozing: nima yetishmayapti? `rockylinux:9` konteynerida xuddi shu buyruqni bajarib farqni ko'rsating va farq qayerdan kelishini (`/etc/login.defs`, `useradd -D`) toping. VM'dagi `alice` ni o'chiring. Yo'nalish: 2-bo'limdagi `useradd` va `adduser` jadvali. Konteyner host'da ishga tushiriladi, ichida `sudo` kerak emas.

5. **Proper user.** VM'da `bob` ni to'g'ri yarating: home bilan, shell `/bin/bash`, izoh maydoni bilan. Parol o'rnating. `/home/bob` ichidagi fayllar qayerdan kelganini (`/etc/skel`) ko'rsating. `su - bob` bilan kirib `whoami`, `pwd`, `echo $SHELL` ni tekshiring. Yo'nalish: 2-bo'limdagi flag'lar jadvali va `erin` misoli. Parolni README'ga yozmang.

6. **The -aG trap.** `devs` va `ops` guruhlarini yarating. `bob` ni `usermod -aG` bilan `devs` ga qo'shing, `id bob` ni oling. Keyin `usermod -G ops bob` (`-a` siz) bajaring va `id bob` ni qayta oling. Nima bo'ldi? To'g'rilab, `bob` ikkala guruhda bo'lsin. Yo'nalish: 2-bo'lim, "`-G` ni `-a` siz yozish".

7. **Group takes effect on login.** Bir terminalda `su - bob` bilan kirib turing. Ikkinchi terminalda `shared` guruhini yarating, `bob` ni qo'shing va `sudo install -d -m 2770 -g shared /srv/shared` bilan katalog yarating. Birinchi terminalda `id` va `touch /srv/shared/x` ni sinang. Keyin chiqib qayta kiring va takrorlang. `id bob` va joriy sessiyadagi `id` nima uchun farq qilganini 9-darsdagi meros tushunchasi bilan izohlang. `2770` dagi `2` nima qilishini (6-dars) eslab yozing. Yo'nalish: 2-bo'limdagi "guruh a'zoligi darhol kuchga kirmaydi" va 1-bo'limdagi `id` jadvali.

8. **Password aging.** `bob` uchun: parol 60 kunda eskirsin, 7 kun oldin ogohlantirsin, keyingi kirishda parolni almashtirishga majbur bo'lsin. `chage -l bob` chiqishini oldin va keyin ko'rsating. `su - bob` bilan kirganda nima bo'ldi? Yo'nalish: 2-bo'limdagi `passwd` va `chage` jadvali; `chage -l` qatorlarini shadow maydonlariga bog'lang.

9. **Locking is not enough.** `bob` ning parolini bloklang, `sudo passwd -S bob` va shadow'dagi hash boshlanishini ko'rsating. Bu SSH kalit bilan kirishni to'xtatadimi (15-vazifadan keyin `bob` ga ham kalit qo'yib amalda sinab, javobni to'ldiring)? Akkauntni to'liq yopish buyrug'ini yozing va sinang. Keyin akkauntni qayta oching. Yo'nalish: 2-bo'limdagi "`passwd -l` SSH kalitni to'xtatmaydi"; qayta ochish uchun `chage` jadvalidagi `-E` qatoriga qarang.

10. **Deleting a user.** `carol` ni yarating, uning nomidan `/srv/shared` ichida va `/var/tmp` da fayl yarating (`sudo -u carol touch ...`). `userdel -r carol` dan keyin o'sha fayllarni `ls -ln` bilan ko'ring: egasi nima bo'ldi? Egasiz fayllarni `find` bilan toping. Xavfi nimada ekanini yozing va fayllarni tozalang. Yo'nalish: 2-bo'lim, `userdel`. `carol` `/srv/shared` ga yoza olishi uchun nima kerakligini 7-vazifadan eslang.

### C. sudo

11. **su vs sudo.** VM'da `sudo -i`, `sudo -s`, `sudo su -` uchalasini bajarib, har birida `whoami`, `pwd`, `echo $HOME` ni solishtiring. `su -` (sudo'siz) nima uchun ishlamaydi? `sudo passwd -S root` bilan tasdiqlang. Yo'nalish: 3-bo'limdagi `su` va `sudo` jadvali; `sudo -s` ni `man sudo` dan o'qing.

12. **Scoped sudoers.** `bob` ga faqat ikkita buyruqni parolsiz root sifatida bajarishga ruxsat bering: `systemctl restart ssh` va `systemctl status ssh` (yo'lni `command -v systemctl` bilan aniqlang). Qoidani `visudo -f` orqali `/etc/sudoers.d/` ga yozing, fayl huquqini tekshiring, faylning nusxasini ish papkasiga `task_12.sudoers` nomi bilan saqlang. `bob` sifatida `sudo -l` ni oling, ruxsat berilgan buyruqni va ruxsat berilmagan buyruqni (`sudo systemctl stop ssh`, `sudo cat /etc/shadow`) sinang. Rad etilgan urinish logda qanday ko'rinadi? Yo'nalish: 3-bo'limdagi sintaksis va "Birga bajaramiz" ning 4–5 qadamlari. Ikki terminal qoidasiga amal qiling. Faylni host'ga olish: VM'da `sudo cat` bilan o'qib ko'chiring yoki `multipass exec lab -- sudo cat <yo'l>` chiqishini host'da faylga yo'naltiring.

13. **Break sudoers safely.** Ikkinchi root terminalini ochiq qoldiring. `sudo visudo -f /etc/sudoers.d/broken` da ataylab sintaksis xatosi yozing va saqlashga urining: `visudo` nima taklif qildi? Chiqib keting (saqlamasdan). Keyin `visudo -c` ni bajaring. Fayl nomini `bob.conf` qilib to'g'ri qoida yozsangiz ishlaydimi, nima uchun? Tajriba fayllarini o'chiring. Yo'nalish: 3-bo'lim, "visudo va sudoers.d". Boshlashdan oldin snapshot oling (Laboratoriya bo'limi).

14. **Shell escape.** `bob` ga `NOPASSWD: /usr/bin/less /var/log/syslog` ruxsatini bering. `bob` sifatida `sudo less /var/log/syslog` ni ochib, `less` ichidan root shell olishga urinib ko'ring (`man less` da `!` buyrug'ini qidiring). Natijani va bundan chiqadigan qoidani yozing. https://gtfobins.github.io/ dan yana ikkita shunday buyruq toping. Qoidani o'chiring. Yo'nalish: 3-bo'limdagi "shell'ga chiqish" tuzog'i.

### D. SSH va servis akkaunt

15. **Key login for a new user.** VM'da `deploy` foydalanuvchisini yarating (parolsiz). Ish mashinangizdagi public kalitni (yo'q bo'lsa `ed25519` juft yarating) uning `authorized_keys` fayliga to'g'ri egasi va huquqlar bilan qo'ying. Ish mashinasidan `ssh deploy@<VM_IP>` bilan kiring. `ssh -v` chiqishidan qaysi kalit taklif qilingani va qabul qilingani ko'rsatilgan qatorlarni toping. Yo'nalish: 4-bo'lim. Kalit host'da yaratiladi (Zorin va macOS'da bir xil), manzil `multipass info lab` dan. `.pub` qatorini VM'ga `multipass transfer` bilan yoki nusxalab qo'yish mumkin. `ssh -v` da `debug1:` bilan boshlanib kalit haqida gapiradigan qatorlarni qidiring.

16. **Break key auth.** `deploy` ning `~/.ssh` katalogiga `chmod 777` qiling (yoki `authorized_keys` egasini root qiling) va qayta kirishga urining. Mijoz nima dedi, server logi (`journalctl -u ssh`) nima dedi? Tuzating. Keyin `sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin|pubkeyauthentication'` bilan amaldagi sozlamalarni ko'ring va qaysi fayl ularni belgilaganini `/etc/ssh/sshd_config.d/` dan toping. Yo'nalish: 4-bo'limdagi huquqlar jadvali va "Kirish va diagnostika". Sozlamani faqat o'qing, o'zgartirmang. Tuzatgach kirish yana ishlashini tekshiring.

17. **Service account.** `demoapp` servis akkauntini yarating: tizim UID'i, home'siz, shell `nologin`. `getent passwd`, `id`, `sudo passwd -S` bilan tekshiring. `sudo su - demoapp` va `sudo -u demoapp whoami` ni sinang: biri nima uchun ishlamaydi, ikkinchisi ishlaydi? `/var/lib/demoapp` katalogini faqat shu akkaunt kira oladigan qilib yarating va `bob` kira olmasligini ko'rsating. Bu akkaunt 11-darsda kerak bo'ladi, o'chirmang. Yo'nalish: 5-bo'lim va `reportd` misoli.

### E. Yakuniy

18. **Onboarding script.** `task_18.sh` yozing: argument sifatida login nomi va public kalit fayli yo'lini oladi; foydalanuvchi yo'q bo'lsa yaratadi (home, bash), `devs` guruhiga qo'shadi, kalitni `authorized_keys` ga to'g'ri huquqlar bilan o'rnatadi, parolni birinchi kirishda almashtirish shart emas (parol yo'q, faqat kalit). Skript idempotent bo'lsin: ikkinchi marta ishga tushirilganda xato bermasin va kalitni ikki marta yozmasin. Argument yetishmasa yoki root bo'lmasa tushunarli xato bilan chiqsin. `shellcheck` toza. VM'ga `multipass transfer` bilan ko'chirib, yangi `dave` foydalanuvchisi uchun sinang va SSH bilan kirib ko'rsating. Yo'nalish: "mavjudmi" tekshiruvlari uchun `getent` ning exit code'i ("Birga bajaramiz" 1-qadam) va `id -u`; qator faylda bormi degan savolga `grep` ning `-q`, `-x`, `-F` flag'larini `man grep` dan o'qing. Skript VM'da ishlaydi, shuning uchun Linux buyruqlari yetarli; `.pub` faylni ham VM'ga ko'chirish kerak.

19. **Offboarding and cleanup.** `dave` uchun "ishdan ketdi" tartibini bajaring va README'ga qadamlar ro'yxati sifatida yozing: akkauntni to'liq bloklash, ishlab turgan jarayon va sessiyalarini tekshirish (9-dars), `sudoers.d` va guruhlardagi izlarini topish, fayllarini topish. Keyin dars davomida yaratilgan test foydalanuvchilar (`bob`, `dave`), guruhlar va `sudoers.d` fayllarini o'chiring. `deploy` va `demoapp` qolsin. Yakuniy `getent passwd | awk -F: '$3>=1000'` va `ls /etc/sudoers.d/` chiqishini ko'rsating. Yo'nalish: "Birga bajaramiz" ning 7–8 qadamlari tartibni ko'rsatadi; `/var/lib/demoapp` ham qolishi kerak.

### Topshirish

Tayyor bo'lgach:
1. `linux/10-users/README.md` da 19 ta vazifaning har biri `## N. Title` sarlavhasi ostida; yonida `task_12.sudoers` va `task_18.sh`.
2. `make check` toza o'tadi.
3. README va repo'da parol, parol hash'i, private kalit yo'q (`git status` va `git diff` ni commit'dan oldin ko'ring).
4. VM'da test akkauntlardan faqat `deploy` va `demoapp` qolgan (`ubuntu` o'z joyida), `/var/lib/demoapp` bor, `sudo visudo -c` xatosiz, host'dan `ssh deploy@<VM_IP>` ishlaydi.
5. Dars oxiridagi holatni saqlab qo'yish ixtiyoriy, lekin foydali: `multipass stop lab && multipass snapshot lab --name after-10 && multipass start lab`.
6. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Parol hash'lari nima uchun `/etc/passwd` da emas, `/etc/shadow` da saqlanadi?
- `usermod -G docker bob` va `usermod -aG docker bob` farqi nima?
- Guruhga qo'shilgan foydalanuvchi nima uchun qayta login qilishi kerak?
- `su -` va `sudo -i` farqi nima, Ubuntu'da nima uchun birinchisi root uchun ishlamaydi?
- `sudoers` ni nima uchun faqat `visudo` bilan tahrirlash kerak?
- `NOPASSWD: /usr/bin/vim` nima uchun `NOPASSWD: ALL` bilan teng?
- Kalit to'g'ri, lekin server `Permission denied (publickey)` deyapti. Tekshiradigan uch narsangiz nima va sababni qayerdan o'qiysiz?
- Parolni bloklash akkauntni yopish uchun nima uchun yetarli emas?
- Servis akkaunt oddiy foydalanuvchidan nimasi bilan farq qiladi va shell'i `nologin` bo'lsa dastur qanday ishga tushadi?
