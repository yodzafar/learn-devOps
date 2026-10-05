# 10-dars: Foydalanuvchilarni boshqarish

Maqsad: Linux'da foydalanuvchi va guruhlar qayerda saqlanishi, qanday yaratilishi va huquqlar `sudo` orqali qanday beriladi, shuni tushunish. 6-darsdagi fayl huquqlari (`rwx`, egasi, guruhi) faqat "kim" degan savolga javob bo'lgandagina ma'noga ega, bu dars shu "kim" haqida. Amaliy natija: yangi serverga `deploy` foydalanuvchisini SSH kalit bilan kiradigan, cheklangan `sudo` huquqli qilib sozlash va dastur uchun login qila olmaydigan servis akkaunt yaratish. Servis akkaunt 11-darsda systemd unit'ning `User=` qatorida ishlatiladi.

Taxminiy vaqt: 2 kun (siz uchun). Diqqatni quyidagilarga qarating: `/etc/passwd` va `/etc/shadow` maydonlari, `usermod -aG` dagi `-a`, guruh a'zoligi qachon kuchga kirishi, `sudoers` sintaksisi va `visudo`, `~/.ssh` huquqlari, parolni bloklash SSH kalitni bloklamasligi.

## Laboratoriya

- Hamma o'zgartiruvchi vazifalar Multipass VM ichida (`multipass shell lab`). Ish mashinasida foydalanuvchi yaratmang, `sudoers` ga tegmang.
- Ish mashinasida faqat o'qish (`id`, `getent`, `cat /etc/passwd`) va SSH kalit juftini yaratish.
- RHEL oilasi bilan solishtirish uchun: `docker run --rm -it rockylinux:9 bash` (konteyner ichida siz root, `sudo` kerak emas; `passwd` buyrug'i yo'q bo'lsa `dnf install -y passwd`).
- VM'ning IP manzili: `multipass info lab` (`IPv4` qatori). SSH bilan kirishni sinash uchun shu manzil ishlatiladi.
- **Ehtiyot chorasi:** `sudoers` yoki SSH sozlamasini o'zgartirayotganda VM'ga ochiq ikkinchi terminalni (`multipass shell lab`) yopmang. Xato qilsangiz shu sessiyadan tuzatasiz. VM butunlay buzilsa: `multipass delete lab && multipass purge`, keyin 2-darsdagi buyruq bilan qayta yarating.
- Tozalash: dars oxirida yaratilgan test foydalanuvchilar va `sudoers.d` fayllarini o'chiring (oxirgi vazifada).

---

## 1. Foydalanuvchi va guruh ma'lumotlari

Kernel foydalanuvchini nom bilan emas, raqam bilan biladi: **UID** va **GID**. Nomlar faqat odam uchun, ular quyidagi fayllarda raqamga bog'lanadi.

### /etc/passwd

Hammaga o'qishga ochiq, har qatorda ikki nuqta bilan ajratilgan 7 maydon:

```
deploy:x:1001:1001:Deploy User,,,:/home/deploy:/bin/bash
```

| # | Maydon | Izoh |
|---|--------|------|
| 1 | login nomi | |
| 2 | parol | `x` degani parol `/etc/shadow` da |
| 3 | UID | |
| 4 | asosiy guruh GID | yangi fayllar shu guruh bilan yaratiladi |
| 5 | GECOS | to'liq ism va izoh |
| 6 | home katalog | |
| 7 | login shell | `/usr/sbin/nologin` bo'lsa interaktiv kirib bo'lmaydi |

UID oraliqlari (`/etc/login.defs` dagi `UID_MIN`, `SYS_UID_MIN` bilan belgilanadi):

| UID | Kim |
|-----|-----|
| 0 | `root`. Kernel uchun maxsus bo'lgan narsa nom emas, aynan UID 0 |
| 1–999 | tizim va servis akkauntlari (`www-data`, `sshd`, `postgres`) |
| 1000+ | oddiy foydalanuvchilar |
| 65534 | `nobody` |

### /etc/shadow

Faqat root (va `shadow` guruhi) o'qiydi. 9 maydon:

```
deploy:$y$j9T$...:20000:0:99999:7:::
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
| 9 | zaxira | |

Hash formati `$id$salt$hash`: har foydalanuvchiga tasodifiy salt qo'shilgani uchun bir xil parollar har xil hash beradi.

### /etc/group

```
docker:x:988:yodzafar,deploy
```

Maydonlar: guruh nomi, parol (ishlatilmaydi), GID, **qo'shimcha** a'zolar ro'yxati. Foydalanuvchining asosiy guruhi bu yerda a'zo sifatida ko'rinmaydi, u `/etc/passwd` ning 4-maydonida. Ubuntu va RHEL har yangi foydalanuvchiga o'zi bilan bir nomli shaxsiy guruh yaratadi (user private group).

### O'qish asboblari

```
$ id deploy                 # uid, gid, all groups
$ getent passwd deploy      # lookup through NSS (files, LDAP, sssd)
$ getent group docker
$ groups deploy
$ who ; w ; last -n 10      # who is logged in now, login history
```

Fayllarni `grep` qilish o'rniga `getent` ishlating: korporativ muhitda foydalanuvchilar LDAP yoki boshqa katalogdan kelishi mumkin va ular `/etc/passwd` da bo'lmaydi.

## 2. Foydalanuvchi yaratish, o'zgartirish, o'chirish

### useradd va adduser

| | `useradd` | `adduser` |
|---|-----------|-----------|
| Nima | past darajali standart asbob, hamma distributivda | Debian/Ubuntu'da interaktiv o'ram (parol, ism so'raydi, home yaratadi) |
| RHEL oilasida | home'ni standart yaratadi (`CREATE_HOME yes`) | `useradd` ga symlink |
| Ubuntu'da standart holat | `-m` siz home yaratmaydi, shell `/bin/sh` | home yaratadi, shell `/bin/bash` |
| Skriptda | shu ishlatiladi | interaktiv bo'lgani uchun noqulay |

```
$ sudo useradd -m -s /bin/bash -c "Deploy User" deploy
$ sudo passwd deploy
```

`-m` home katalogni yaratib, ichiga `/etc/skel` dagi fayllarni (`.bashrc`, `.profile`) nusxalaydi. `-G sudo,docker` qo'shimcha guruhlar, `-u 1500` aniq UID, `-g` asosiy guruh. Standart qiymatlar: `useradd -D` va `/etc/login.defs`.

**Tuzoq: Ubuntu'da `useradd deploy`.** Flag'siz chaqirilsa home katalog yo'q, shell `/bin/sh`, parol bloklangan akkaunt hosil bo'ladi. Skriptda har doim `-m -s /bin/bash` ni aniq yozing, shunda ikkala oilada bir xil ishlaydi.

### usermod

```
$ sudo usermod -aG docker deploy     # append to a supplementary group
$ sudo usermod -s /usr/sbin/nologin deploy
$ sudo usermod -L deploy             # lock the password
$ sudo usermod -U deploy             # unlock
```

**Tuzoq: `-G` ni `-a` siz yozish.** `usermod -G docker deploy` foydalanuvchini `docker` ga qo'shmaydi, balki qo'shimcha guruhlari ro'yxatini faqat `docker` bilan **almashtiradi**. `sudo` guruhidan chiqib qolgan administrator shu xatoning klassik qurboni.

**Tuzoq: guruh a'zoligi darhol kuchga kirmaydi.** Jarayon guruhlar ro'yxatini login paytida oladi va bolalariga meros qoldiradi (9-dars). Guruhga qo'shilgandan keyin qayta login kerak. `id deploy` (fayldan o'qiydi) yangi guruhni ko'rsatadi, joriy shell'dagi `id` esa yo'q. Vaqtinchalik yechim: `newgrp docker` yangi shell ochadi.

Guruhdan chiqarish: `sudo gpasswd -d deploy docker`. Guruh yaratish va o'chirish: `groupadd`, `groupdel`.

### userdel

`sudo userdel deploy` faqat akkauntni o'chiradi, `sudo userdel -r deploy` home va mail spool bilan birga. Home'dan tashqaridagi fayllar qoladi va `ls -l` da egasi nom o'rniga raqam (UID) bo'lib ko'rinadi. Keyinroq shu UID bilan yangi foydalanuvchi yaratilsa, u eski fayllarning egasi bo'lib qoladi. Qolgan fayllarni topish: `sudo find / -xdev -nouser`.

### passwd va chage

| Buyruq | Nima qiladi |
|--------|-------------|
| `passwd` | o'z parolini o'zgartirish |
| `sudo passwd deploy` | boshqaning parolini o'rnatish |
| `sudo passwd -S deploy` | holat: `P` parol bor, `L` bloklangan, `NP` parolsiz |
| `sudo passwd -l deploy` / `-u` | parolni bloklash (hash oldiga `!` qo'yadi) va ochish |
| `sudo chage -l deploy` | parol muddati ma'lumotlari |
| `sudo chage -M 90 -W 14 deploy` | 90 kunda eskiradi, 14 kun oldin ogohlantiradi |
| `sudo chage -d 0 deploy` | keyingi kirishda parolni almashtirishga majburlash |
| `sudo chage -E 2026-12-31 deploy` | akkaunt tugash sanasi (`-E -1` olib tashlaydi) |

**Tuzoq: `passwd -l` SSH kalitni to'xtatmaydi.** Parolni bloklash faqat parol bilan kirishni yopadi. `~/.ssh/authorized_keys` dagi kalit bilan kirish davom etadi. Ishdan ketgan xodim akkauntini to'liq yopish uchun akkauntni muddati tugagan qiling: `sudo usermod -L -e 1 deploy` (yoki `chage -E 0`), va ishlab turgan sessiyalarini tekshiring (`who`, `pgrep -u deploy`).

## 3. sudo va sudoers

### su va sudo

| | `su - user` | `sudo cmd` |
|---|-------------|------------|
| Kimning paroli | **maqsad** foydalanuvchining | **o'zingizning** |
| Root paroli kerakmi | ha, uni hamma administrator bilishi kerak | yo'q, root paroli umuman bo'lmasligi mumkin |
| Huquq doirasi | to'liq shell | aniq buyruqlargacha cheklash mumkin |
| Audit | faqat "kim `su` qildi" | har buyruq logga yoziladi |

`su user` (defissiz) environment'ni saqlab qoladi, `su - user` to'liq login shell ochadi (home'ga o'tadi, `PATH` yangilanadi). Ubuntu'da `root` paroli standart holatda bloklangan, shuning uchun `su -` ishlamaydi va root huquqi faqat `sudo` orqali.

Foydali shakllar: `sudo -i` (root login shell), `sudo -u postgres psql` (boshqa foydalanuvchi nomidan), `sudo -l` (menga nima ruxsat berilgan), `sudo -l -U deploy` (boshqaga nima ruxsat berilgan), `sudo -k` (keshlangan parolni unutish).

### sudoers sintaksisi

Qoidalar `/etc/sudoers` va `/etc/sudoers.d/` dagi fayllarda:

```
# who   where=(as whom)     what
root    ALL=(ALL:ALL)       ALL
%sudo   ALL=(ALL:ALL)       ALL
deploy  ALL=(root) NOPASSWD: /usr/bin/systemctl restart demoapp, /usr/bin/systemctl status demoapp
```

- Birinchi maydon foydalanuvchi yoki `%guruh`.
- `ALL=` qaysi hostda (bitta `sudoers` ko'p serverga tarqatilganda ma'noli, odatda `ALL`).
- `(root)` yoki `(ALL:ALL)` kimning nomidan (`foydalanuvchi:guruh`).
- `NOPASSWD:` parol so'ramaslik. Avtomatlashtirish uchun kerak, lekin faqat aniq buyruqlar bilan.
- Buyruqlar to'liq yo'l bilan, vergul bilan ajratiladi. Argument yozilsa faqat aynan shu argumentlar bilan ruxsat.
- Bir nechta qoida mos kelsa **oxirgisi** yutadi.

Administrator guruhi Ubuntu'da `sudo`, RHEL oilasida `wheel`.

### visudo va sudoers.d

`sudoers` ni hech qachon oddiy editor bilan ochmang. `visudo` faylni bloklaydi va saqlashdan oldin sintaksisni tekshiradi; xato bilan saqlangan `sudoers` hamma uchun `sudo` ni o'chiradi.

```
$ sudo visudo -f /etc/sudoers.d/deploy    # edit a drop-in safely
$ sudo visudo -c                          # check all files
```

O'z qoidalaringizni asosiy faylga emas, `/etc/sudoers.d/` ga alohida fayl qilib yozing: huquqi `0440`, egasi root. Nomida nuqta bo'lgan yoki `~` bilan tugaydigan fayllar o'qilmaydi (`deploy.conf` ishlamaydi, `deploy` ishlaydi).

**Tuzoq: shell'ga chiqish imkonini beradigan buyruqlar.** `deploy ALL=(root) NOPASSWD: /usr/bin/vim` amalda to'liq root: `vim` ichidan `:!bash` ishlaydi. `less`, `find` (`-exec`), `tar`, `awk`, `python`, `docker` ham shunday. Ruxsat ro'yxatiga faqat argumentlari bilan qat'iy belgilangan buyruqlar kirsin. `docker` guruhiga a'zolik ham amalda root huquqi (konteynerga host'ning `/` ini mount qilish mumkin).

`sudo` chaqiruvlari `/var/log/auth.log` ga (RHEL'da `/var/log/secure`) va journal'ga yoziladi: kim, qaysi terminaldan, qaysi katalogda, qaysi buyruqni.

## 4. SSH kalit bilan kirish

Parol o'rniga kalit jufti: private kalit sizda qoladi, public kalit serverda foydalanuvchining `~/.ssh/authorized_keys` fayliga yoziladi. Server tasodifiy ma'lumotni imzolashni so'raydi va imzoni public kalit bilan tekshiradi; private kalit tarmoqqa chiqmaydi.

Ish mashinasida kalit yaratish (agar hali yo'q bo'lsa):

```
$ ssh-keygen -t ed25519 -C "yodzafar@workstation"
$ cat ~/.ssh/id_ed25519.pub
```

Passphrase qo'ying: kalit fayli o'g'irlansa ham ishlatib bo'lmaydi. `id_ed25519` private (hech kimga berilmaydi, repo'ga tushmaydi), `id_ed25519.pub` public.

Serverda yangi foydalanuvchiga kalit qo'yish (parol bilan kirish yopiq bo'lgani uchun `ssh-copy-id` ishlamaydi, administrator sifatida qo'lda):

```
$ sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
$ sudo nano /home/deploy/.ssh/authorized_keys      # paste the public key, one per line
$ sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
$ sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Huquqlar majburiy: `sshd` ning `StrictModes` sozlamasi (standart `yes`) home, `~/.ssh` yoki `authorized_keys` boshqalar yoza oladigan bo'lsa yoki egasi noto'g'ri bo'lsa, kalitni jimgina rad etadi.

| Yo'l | Huquq | Egasi |
|------|-------|-------|
| `~` (home) | guruh va boshqalar yoza olmasin (masalan `750`) | foydalanuvchi |
| `~/.ssh` | `700` | foydalanuvchi |
| `~/.ssh/authorized_keys` | `600` | foydalanuvchi |
| `~/.ssh/id_ed25519` (mijozda) | `600` | foydalanuvchi |

Tekshirish va diagnostika:

```
$ ssh -i ~/.ssh/id_ed25519 deploy@<VM_IP>
$ ssh -v deploy@<VM_IP>                    # client side: which keys are offered
$ sudo journalctl -u ssh -n 20             # server side: why it was rejected
```

Server tomonidagi sabab har doim server logida: mijoz faqat `Permission denied (publickey)` ni ko'radi.

`sshd` sozlamalari `/etc/ssh/sshd_config` va `/etc/ssh/sshd_config.d/*.conf` da. Muhimlari: `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`. Har kalit so'z uchun birinchi uchragan qiymat kuchga kiradi. O'zgartirgandan keyin `sudo sshd -t` bilan sintaksisni tekshiring, keyin `sudo systemctl reload ssh` (RHEL'da unit nomi `sshd`). SSH'ni mustahkamlash tarmoq va xavfsizlik darslarida davom etadi.

## 5. Servis akkauntlari

Dastur root sifatida ishlamasligi kerak: undagi zaiflik butun serverni beradi. Har servisga o'z akkaunti yaratiladi, u faqat o'z fayllariga ega va login qila olmaydi.

```
$ sudo useradd --system --no-create-home --shell /usr/sbin/nologin demoapp
$ getent passwd demoapp
$ sudo passwd -S demoapp
```

- `--system` (`-r`): UID tizim oralig'idan (1000 dan past) olinadi, parol muddati qo'yilmaydi, home yaratilmaydi.
- `/usr/sbin/nologin`: interaktiv kirishga urinilsa `This account is currently not available.` deb chiqaradi. RHEL oilasida an'anaviy yo'l `/sbin/nologin` (ikkalasi bir fayl).
- Parol o'rnatilmagan (`L`), `authorized_keys` yo'q: akkauntga tashqaridan kirish yo'li qolmaydi.

Shell `nologin` bo'lsa ham jarayonni shu foydalanuvchi nomidan ishga tushirish mumkin, chunki bu login emas: `sudo -u demoapp whoami` ishlaydi, systemd `User=demoapp` bilan ishga tushiradi. Akkauntga kerakli kataloglar beriladi:

```
$ sudo install -d -o demoapp -g demoapp -m 750 /var/lib/demoapp
```

Paketlar o'z servis akkauntlarini o'zi yaratadi (`www-data`, `postgres`, `redis`), siz faqat o'z dasturlaringiz uchun yaratasiz.

## Tuzoqlar

- `usermod -G` ni `-a` siz ishlatib, foydalanuvchini boshqa guruhlardan (shu jumladan `sudo` dan) chiqarib yuborish.
- Guruhga qo'shib, qayta login qilmasdan "ishlamayapti" deyish.
- `sudoers` ni `visudo` siz tahrirlash. Bitta sintaksis xatosi `sudo` ni hamma uchun o'chiradi; root paroli yo'q serverda bu konsol orqali tiklashni anglatadi.
- `NOPASSWD: ALL` ni qulaylik uchun berish, yoki shell'ga chiqish imkoni bor buyruqni (`vim`, `less`, `find`, `docker`) ruxsat ro'yxatiga qo'shish.
- `passwd -l` bilan akkauntni "yopdim" deb o'ylash: SSH kalit ishlayveradi.
- `~/.ssh` yoki `authorized_keys` huquqlari keng yoki egasi root bo'lib qolgani uchun kalit rad etilishi. `sudo` bilan yaratilgan fayl egasi root bo'ladi.
- SSH sozlamasini o'zgartirib, joriy sessiyani yopib qo'yish. Avval yangi terminalda kirib ko'ring, keyin eskisini yoping.
- Private kalitni serverga nusxalash, chatga yuborish yoki repo'ga commit qilish. Serverga faqat `.pub` boradi.
- Bir nechta odam bitta umumiy akkaunt (`admin`, `deploy`) va bitta kalitdan foydalanishi: kim nima qilganini bilib bo'lmaydi. Har odamga o'z akkaunti yoki kamida o'z kaliti.
- Dasturni root yoki o'z shaxsiy akkauntingiz nomidan ishga tushirish. Har servisga alohida `nologin` akkaunt.

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

---

## Vazifalar

Ish papkasi: `linux/10-users/` (`make new m=linux n=10 name=users` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni yoniga saqlang. Parol hash'lari, private kalitlar README'ga va repo'ga tushmasin (hash o'rniga `$y$...` deb qisqartiring). Aytilmagan bo'lsa VM'da bajaring.

### A. Ma'lumot fayllari

1. **Who am I.** Ish mashinasida va VM'da `id`, `groups`, `getent passwd "$USER"` ni oling. `/etc/passwd` qatoringizdagi 7 maydonning har birini nomlang. Guruhlaringizdan `sudo`, `adm`, `docker` (bor bo'lsa) nima huquq berishini bir gapdan yozing.

2. **Account inventory.** VM'da `/etc/passwd` dan 7-darsdagi `awk` bilan: UID 1000 va undan katta foydalanuvchilar ro'yxatini; login shell'lar bo'yicha akkauntlar sonini (`sort | uniq -c`) chiqaring. Nechta akkaunt interaktiv kira oladi? `nobody` ning UID'i va vazifasini yozing.

3. **shadow fields.** VM'da `sudo getent shadow ubuntu` va `sudo chage -l ubuntu` ni oling. Ikkinchi maydon nima bilan boshlanadi va bu nimani anglatadi (Multipass VM'da parol bormi)? 3-maydondagi sonni `date -d "1970-01-01 +N days"` bilan sanaga aylantiring. `/etc/shadow` ning fayl huquqlarini ko'rsating va nima uchun `/etc/passwd` dan farq qilishini izohlang.

### B. Yaratish va o'zgartirish

4. **useradd defaults.** VM'da `sudo useradd alice` (flag'siz) bajaring. `getent passwd alice`, `ls -ld /home/alice`, `sudo passwd -S alice` natijalarini yozing: nima yetishmayapti? `rockylinux:9` konteynerida xuddi shu buyruqni bajarib farqni ko'rsating va farq qayerdan kelishini (`/etc/login.defs`, `useradd -D`) toping. VM'dagi `alice` ni o'chiring.

5. **Proper user.** VM'da `bob` ni to'g'ri yarating: home bilan, shell `/bin/bash`, izoh maydoni bilan. Parol o'rnating. `/home/bob` ichidagi fayllar qayerdan kelganini (`/etc/skel`) ko'rsating. `su - bob` bilan kirib `whoami`, `pwd`, `echo $SHELL` ni tekshiring.

6. **The -aG trap.** `devs` va `ops` guruhlarini yarating. `bob` ni `usermod -aG` bilan `devs` ga qo'shing, `id bob` ni oling. Keyin `usermod -G ops bob` (`-a` siz) bajaring va `id bob` ni qayta oling. Nima bo'ldi? To'g'rilab, `bob` ikkala guruhda bo'lsin.

7. **Group takes effect on login.** Bir terminalda `su - bob` bilan kirib turing. Ikkinchi terminalda `shared` guruhini yarating, `bob` ni qo'shing va `sudo install -d -m 2770 -g shared /srv/shared` bilan katalog yarating. Birinchi terminalda `id` va `touch /srv/shared/x` ni sinang. Keyin chiqib qayta kiring va takrorlang. `id bob` va joriy sessiyadagi `id` nima uchun farq qilganini 9-darsdagi meros tushunchasi bilan izohlang. `2770` dagi `2` nima qilishini (6-dars) eslab yozing.

8. **Password aging.** `bob` uchun: parol 60 kunda eskirsin, 7 kun oldin ogohlantirsin, keyingi kirishda parolni almashtirishga majbur bo'lsin. `chage -l bob` chiqishini oldin va keyin ko'rsating. `su - bob` bilan kirganda nima bo'ldi?

9. **Locking is not enough.** `bob` ning parolini bloklang, `sudo passwd -S bob` va shadow'dagi hash boshlanishini ko'rsating. Bu SSH kalit bilan kirishni to'xtatadimi (15-vazifadan keyin `bob` ga ham kalit qo'yib amalda sinab, javobni to'ldiring)? Akkauntni to'liq yopish buyrug'ini yozing va sinang. Keyin akkauntni qayta oching.

10. **Deleting a user.** `carol` ni yarating, uning nomidan `/srv/shared` ichida va `/var/tmp` da fayl yarating (`sudo -u carol touch ...`). `userdel -r carol` dan keyin o'sha fayllarni `ls -ln` bilan ko'ring: egasi nima bo'ldi? Egasiz fayllarni `find` bilan toping. Xavfi nimada ekanini yozing va fayllarni tozalang.

### C. sudo

11. **su vs sudo.** VM'da `sudo -i`, `sudo -s`, `sudo su -` uchalasini bajarib, har birida `whoami`, `pwd`, `echo $HOME` ni solishtiring. `su -` (sudo'siz) nima uchun ishlamaydi? `sudo passwd -S root` bilan tasdiqlang.

12. **Scoped sudoers.** `bob` ga faqat ikkita buyruqni parolsiz root sifatida bajarishga ruxsat bering: `systemctl restart ssh` va `systemctl status ssh` (yo'lni `command -v systemctl` bilan aniqlang). Qoidani `visudo -f` orqali `/etc/sudoers.d/` ga yozing, fayl huquqini tekshiring, faylning nusxasini ish papkasiga `task_12.sudoers` nomi bilan saqlang. `bob` sifatida `sudo -l` ni oling, ruxsat berilgan buyruqni va ruxsat berilmagan buyruqni (`sudo systemctl stop ssh`, `sudo cat /etc/shadow`) sinang. Rad etilgan urinish logda qanday ko'rinadi?

13. **Break sudoers safely.** Ikkinchi root terminalini ochiq qoldiring. `sudo visudo -f /etc/sudoers.d/broken` da ataylab sintaksis xatosi yozing va saqlashga urining: `visudo` nima taklif qildi? Chiqib keting (saqlamasdan). Keyin `visudo -c` ni bajaring. Fayl nomini `bob.conf` qilib to'g'ri qoida yozsangiz ishlaydimi, nima uchun? Tajriba fayllarini o'chiring.

14. **Shell escape.** `bob` ga `NOPASSWD: /usr/bin/less /var/log/syslog` ruxsatini bering. `bob` sifatida `sudo less /var/log/syslog` ni ochib, `less` ichidan root shell olishga urinib ko'ring (`man less` da `!` buyrug'ini qidiring). Natijani va bundan chiqadigan qoidani yozing. https://gtfobins.github.io/ dan yana ikkita shunday buyruq toping. Qoidani o'chiring.

### D. SSH va servis akkaunt

15. **Key login for a new user.** VM'da `deploy` foydalanuvchisini yarating (parolsiz). Ish mashinangizdagi public kalitni (yo'q bo'lsa `ed25519` juft yarating) uning `authorized_keys` fayliga to'g'ri egasi va huquqlar bilan qo'ying. Ish mashinasidan `ssh deploy@<VM_IP>` bilan kiring. `ssh -v` chiqishidan qaysi kalit taklif qilingani va qabul qilingani ko'rsatilgan qatorlarni toping.

16. **Break key auth.** `deploy` ning `~/.ssh` katalogiga `chmod 777` qiling (yoki `authorized_keys` egasini root qiling) va qayta kirishga urining. Mijoz nima dedi, server logi (`journalctl -u ssh`) nima dedi? Tuzating. Keyin `sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin|pubkeyauthentication'` bilan amaldagi sozlamalarni ko'ring va qaysi fayl ularni belgilaganini `/etc/ssh/sshd_config.d/` dan toping.

17. **Service account.** `demoapp` servis akkauntini yarating: tizim UID'i, home'siz, shell `nologin`. `getent passwd`, `id`, `sudo passwd -S` bilan tekshiring. `sudo su - demoapp` va `sudo -u demoapp whoami` ni sinang: biri nima uchun ishlamaydi, ikkinchisi ishlaydi? `/var/lib/demoapp` katalogini faqat shu akkaunt kira oladigan qilib yarating va `bob` kira olmasligini ko'rsating. Bu akkaunt 11-darsda kerak bo'ladi, o'chirmang.

### E. Yakuniy

18. **Onboarding script.** `task_18.sh` yozing: argument sifatida login nomi va public kalit fayli yo'lini oladi; foydalanuvchi yo'q bo'lsa yaratadi (home, bash), `devs` guruhiga qo'shadi, kalitni `authorized_keys` ga to'g'ri huquqlar bilan o'rnatadi, parolni birinchi kirishda almashtirish shart emas (parol yo'q, faqat kalit). Skript idempotent bo'lsin: ikkinchi marta ishga tushirilganda xato bermasin va kalitni ikki marta yozmasin. Argument yetishmasa yoki root bo'lmasa tushunarli xato bilan chiqsin. `shellcheck` toza. VM'ga `multipass transfer` bilan ko'chirib, yangi `dave` foydalanuvchisi uchun sinang va SSH bilan kirib ko'rsating.

19. **Offboarding and cleanup.** `dave` uchun "ishdan ketdi" tartibini bajaring va README'ga qadamlar ro'yxati sifatida yozing: akkauntni to'liq bloklash, ishlab turgan jarayon va sessiyalarini tekshirish (9-dars), `sudoers.d` va guruhlardagi izlarini topish, fayllarini topish. Keyin dars davomida yaratilgan test foydalanuvchilar (`bob`, `dave`), guruhlar va `sudoers.d` fayllarini o'chiring. `deploy` va `demoapp` qolsin. Yakuniy `getent passwd | awk -F: '$3>=1000'` va `ls /etc/sudoers.d/` chiqishini ko'rsating.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi.
2. README va repo'da parol hash'i, private kalit yo'q (`git status` va `git diff` ni commit'dan oldin ko'ring).
3. VM'da faqat `deploy` va `demoapp` qolgan, `sudo visudo -c` xatosiz.
4. Menga xabar bering, tekshiraman.

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
