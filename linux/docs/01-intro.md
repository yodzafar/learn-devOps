# 1-dars: Linuxga kirish

Maqsad: Linux tizimi qanday qatlamlardan iboratligini (kernel, user space, distributiv), kompyuter yoqilgandan login oynasigacha nima sodir bo'lishini, fayl tizimi ierarxiyasida (FHS) nima qayerda yotishini va terminal, shell, buyruq orasidagi farqni tushunish. Oxirida yordam tizimi (`man`, `--help`, `help`, `tldr`) bilan ishlashni o'rganasiz, chunki keyingi 12 darsda har yangi buyruqni shu orqali o'zingiz ochasiz. Bu dars butun kursning lug'ati: Docker (umumiy kernel), systemd (PID 1), Kubernetes (`/proc`, `/sys`, cgroup) mavzulari shu yerdagi tushunchalarga tayanadi.

Taxminiy vaqt: 2 kun (siz uchun). Terminal sizga tanish, shuning uchun buyruqlarni yodlashga emas, mexanizmga e'tibor bering: kernel va distributiv chegarasi, konteyner nima uchun host kernel'ini ko'rsatishi, `/proc` va `/sys` nima uchun diskda joy egallamasligi, builtin va tashqi buyruq farqi, `man` sahifasining bo'limlari.

## Laboratoriya

Bu darsda hech narsa o'rnatilmaydi va tizim o'zgartirilmaydi (bitta istisno: 20-vazifadagi `tealdeer` paketi, u faqat yordam vositasi).

- **Ish mashinasi (Zorin OS 18)**: barcha o'qiydigan buyruqlar (`uname`, `cat`, `ls`, `ps`, `man`, `journalctl`). `sudo` kerak emas. Biror buyruq `sudo` so'rasa, uni ishlatmang, xatoni o'qing va README'ga yozing.
- **Docker konteyner**: taqqoslash uchun bir martalik konteyner. `--rm` chiqishda konteynerni o'chiradi, tozalash shart emas:

```
docker run --rm -it ubuntu:24.04 bash
# inside the container: run commands, then
exit
```

- Ish mashinangizdagi shell `zsh`. Shell'ga bog'liq vazifalarda (14–17, 20) avval `bash` deb yozib bash ichiga kiring, tugagach `exit`. Kurs davomida serverlardagi standart shell bash bo'ladi.
- Multipass VM keyingi darsda o'rnatiladi, bu darsda kerak emas.

---

## 1. Linux nima: kernel, user space, distributiv

"Linux" so'zi ikki ma'noda ishlatiladi. Tor ma'noda bu faqat **kernel**: Linus Torvalds 1991-yilda boshlagan, kernel.org da chiqadigan dastur. Keng ma'noda bu kernel ustiga qurilgan butun operatsion tizim.

| Qatlam | Nima qiladi | Misol |
|--------|-------------|-------|
| Hardware | CPU, RAM, disk, tarmoq kartasi | |
| Kernel | jarayonlarni rejalashtirish, xotira, fayl tizimlari, tarmoq steki, drayverlar | `vmlinuz-7.0.0-34-generic` |
| System call interfeysi | user space kernel'dan xizmat so'raydigan yagona eshik | `open`, `read`, `write`, `fork`, `execve` |
| User space | kutubxonalar (glibc), shell, utilitalar, init tizimi, sizning dasturlaringiz | `bash`, `ls`, `systemd`, `node` |

- **Kernel space** va **user space** CPU darajasida ajratilgan. Oddiy dastur diskka yoki tarmoqqa to'g'ridan-to'g'ri murojaat qila olmaydi, u system call qiladi va kernel ruxsatni tekshirib ishni bajaradi. `node` da `fs.readFile` chaqirsangiz, oxirida `openat` va `read` system call'lari bajariladi.
- `ls`, `cp`, `cat` kabi buyruqlar kernel emas. Ular GNU coreutils paketidan (shuning uchun "GNU/Linux" atamasi bor). Bu amaliy ahamiyatga ega: Alpine Linux'da ular BusyBox'dan keladi va ba'zi flag'lar yo'q.

### Distributiv

Distributiv (distro) bu kernel + user space dasturlari + paket menejeri + init tizimi + standart sozlamalar + yangilash va qo'llab-quvvatlash siyosati. Ubuntu, Debian, Rocky Linux, Fedora bir xil kernel loyihasidan foydalanadi, lekin kernel versiyasi, paket formati (`.deb` yoki `.rpm`), konfiguratsiya joylashuvi va reliz muddatlari farq qiladi. Batafsil 2-darsda.

```
uname -r                # kernel release: 7.0.0-34-generic
uname -a                # kernel name, hostname, release, build, architecture
cat /etc/os-release     # distro identity: NAME, VERSION_ID, ID, ID_LIKE
```

`uname` kernel haqida, `/etc/os-release` distributiv haqida ma'lumot beradi. Bular ikki xil savol.

**Tuzoq: konteyner o'z kernel'iga ega emas.** `ubuntu:24.04` konteyneri ichida `cat /etc/os-release` Ubuntu'ni ko'rsatadi, lekin `uname -r` host kernel'ini qaytaradi. Konteyner bu faqat boshqa distributivning user space'i, kernel umumiy. Shuning uchun kernel moduli yoki kernel parametri talab qiladigan dastur konteyner image'ini almashtirish bilan tuzalmaydi. VM esa o'z kernel'ini yuklaydi.

## 2. Tizim qanday yuklanadi (boot)

| Bosqich | Kim | Nima qiladi | Qayerdan ko'rish |
|---------|-----|-------------|------------------|
| 1. Firmware | UEFI (eski tizimlarda BIOS) | hardware'ni tekshiradi, diskdan bootloader'ni topadi | `ls /sys/firmware/efi` mavjud bo'lsa UEFI |
| 2. Bootloader | GRUB | kernel va initramfs'ni xotiraga yuklaydi, kernel'ga parametrlar beradi | `ls /boot`, `cat /proc/cmdline` |
| 3. Kernel | `vmlinuz-*` | hardware'ni ishga tushiradi, initramfs'ni vaqtinchalik root sifatida ochadi | `journalctl -k -b` |
| 4. initramfs | `initrd.img-*` | haqiqiy root diskni topish uchun kerakli drayverlarni yuklaydi (LVM, shifrlash, RAID), root'ni mount qiladi | |
| 5. Init | `systemd`, PID 1 | servislarni bog'liqlik tartibida ishga tushiradi, target'ga yetadi | `ps -p 1 -o pid,comm`, `systemd-analyze` |
| 6. Login | `getty`, display manager yoki `sshd` | foydalanuvchini kutadi | |

- **initramfs nima uchun kerak**: kernel root fayl tizimini mount qilishi uchun disk drayveri kerak, drayver esa o'sha diskda yotadi. initramfs bu muammoni yechadigan, xotiraga yuklanadigan kichik vaqtinchalik fayl tizimi.
- **PID 1** kernel ishga tushiradigan birinchi va yagona user space jarayoni, qolgan hamma jarayon uning avlodi. Zamonaviy distributivlarda bu `systemd` (11-darsda chuqur).
- **Target** systemd'da tizim holati: server uchun `multi-user.target`, desktop uchun `graphical.target`.
- Kernel xabarlari: `journalctl -k -b` (`-k` kernel, `-b` joriy boot). `dmesg` ham shu bufer, lekin Ubuntu'da oddiy foydalanuvchiga yopiq.

```
cat /proc/cmdline          # parameters GRUB passed to the kernel
systemd-analyze            # time spent in firmware, loader, kernel, userspace
systemd-analyze blame      # slowest units first
```

**Tuzoq: konteynerda boot yo'q.** Konteyner ichida bootloader ham, kernel yuklanishi ham, odatda systemd ham yo'q. PID 1 bu siz ishga tushirgan dastur (`bash`, `node`, `nginx`). Shuning uchun konteynerda `systemctl` ishlamaydi va PID 1 signal'larni to'g'ri qayta ishlashi shart (Docker modulida).

## 3. Fayl tizimi ierarxiyasi (FHS)

Linux'da disk harflari (`C:`, `D:`) yo'q. Bitta daraxt bor, ildizi `/`, boshqa disklar va virtual fayl tizimlari shu daraxtning papkalariga mount qilinadi. Nima qayerda yotishini Filesystem Hierarchy Standard belgilaydi.

| Papka | Ichida nima | Eslatma |
|-------|-------------|---------|
| `/etc` | tizim konfiguratsiyasi, matn fayllar | backup va konfiguratsiya boshqaruvining asosiy obyekti |
| `/home` | foydalanuvchilar uy papkalari | `~` shu yerga ochiladi |
| `/root` | root foydalanuvchining uy papkasi | `/home` da emas, chunki `/home` alohida diskda bo'lishi mumkin |
| `/usr` | o'rnatilgan dasturlar va kutubxonalar: `/usr/bin`, `/usr/sbin`, `/usr/lib`, `/usr/share` | paket menejeri boshqaradi, qo'lda tegilmaydi |
| `/usr/local` | paket menejerisiz, qo'lda o'rnatilgan dasturlar | `/usr/local/bin` `PATH` da `/usr/bin` dan oldin turadi |
| `/bin`, `/sbin`, `/lib` | `/usr/bin`, `/usr/sbin`, `/usr/lib` ga symlink | "usr merge", zamonaviy distributivlarda |
| `/var` | o'zgaruvchan ma'lumot: `/var/log` (loglar), `/var/lib` (dasturlar holati, masalan `/var/lib/docker`), `/var/cache` | disk to'lishining eng ko'p uchraydigan joyi |
| `/tmp` | vaqtinchalik fayllar, hamma yoza oladi | reboot'da yoki muddat bo'yicha tozalanadi |
| `/run` | ishlayotgan tizim holati: PID fayllar, socket'lar | `tmpfs`, xotirada, reboot'da yo'qoladi |
| `/boot` | kernel, initramfs, GRUB | |
| `/dev` | qurilma fayllari | kernel yaratadi (`devtmpfs`) |
| `/proc` | jarayonlar va kernel haqida ma'lumot | virtual, diskda yo'q |
| `/sys` | qurilmalar, drayverlar, kernel sozlamalari | virtual, diskda yo'q |
| `/opt` | mustaqil, o'z papkasida yashaydigan dasturlar | odatda vendor paketlari |
| `/srv` | server xizmat qiladigan ma'lumot | ko'p distributivda bo'sh |
| `/mnt`, `/media` | qo'lda va avtomatik mount nuqtalari | |

Amaliy qoida: bitta dastur to'rt joyga yoyiladi. Binary `/usr/bin` da, sozlamasi `/etc` da, ma'lumoti `/var/lib` da, logi `/var/log` da. Windows'dagi "bitta papkada hamma narsa" modeli faqat `/opt` da uchraydi.

### "Hamma narsa fayl"

Kernel qurilmalar va o'z ichki holatini fayl ko'rinishida beradi, shuning uchun ularni `cat`, `echo`, `ls` bilan o'qish va yozish mumkin:

```
cat /proc/cpuinfo              # CPU model, cores
cat /proc/meminfo              # memory counters
ls -l /proc/$$/exe             # binary of the current shell ($$ is its PID)
echo hello > /dev/null         # device that discards everything
head -c 8 /dev/urandom | od -An -tx1   # 8 random bytes from a kernel device
```

- `/proc/<PID>/` har bir jarayon uchun papka: `status`, `cmdline`, `environ`, `fd/`. `ps`, `top`, `free` shu fayllarni o'qiydi.
- `/proc` va `/sys` dagi fayllar hajmi 0 ko'rinadi, chunki ular diskda saqlanmaydi: o'qilgan paytda kernel mazmunni generatsiya qiladi.
- `ls -l` chiqishida birinchi belgi fayl turi: `-` oddiy fayl, `d` papka, `l` symlink, `c` belgili qurilma, `b` blokli qurilma, `s` socket, `p` pipe.

**Tuzoq: `/tmp` va `/run` ga tayanmang.** `/run` reboot'da tozalanadi, `/tmp` ni tizim muddat bo'yicha tozalaydi. Reboot'dan keyin kerak bo'ladigan narsa `/var/lib` yoki uy papkasiga yoziladi.

## 4. Terminal, shell, buyruq

Uchta alohida narsa:

| Narsa | Nima | Misol |
|-------|------|-------|
| Terminal emulator | klaviaturani o'qib, matnni ekranga chizadigan oyna | GNOME Terminal, VS Code terminal, ssh sessiyasi |
| TTY | kernel'dagi terminal qurilmasi, emulator va shell orasidagi kanal | `tty` buyrug'i: `/dev/pts/0` |
| Shell | buyruq satrini o'qib, dasturlarni ishga tushiradigan interpretator | `bash`, `zsh`, `sh` (Ubuntu'da `dash`) |

```
echo $SHELL            # login shell from /etc/passwd
ps -p $$ -o comm=      # shell that is actually running now
cat /etc/shells        # shells installed on the system
ls -l /bin/sh          # on Ubuntu: sh -> dash
```

- `$SHELL` login shell'ni ko'rsatadi, hozir ishlayotganini emas. `zsh` ichida `bash` ni ishga tushirsangiz `$SHELL` o'zgarmaydi.
- Prompt: `user@host:~$`. Oxiridagi `$` oddiy foydalanuvchi, `#` root. Hujjatlardagi `$` yoki `#` buyruq qismi emas, ko'chirmang.
- Serverlarda bash standart. `/bin/sh` Ubuntu'da `dash`: tez, lekin bash kengaytmalari (`[[ ]]`, massivlar) yo'q. `#!/bin/sh` bilan boshlangan skriptda bash sintaksisi ishlamasligining sababi shu.

### Buyruq anatomiyasi

```
ls -l -a --human-readable /etc /var
# command | short options | long option | arguments
```

- Qisqa flag'lar birlashadi: `-l -a -h` va `-lah` bir xil. Uzun flag'lar `--` bilan boshlanadi, skriptlarda o'qishga oson.
- Qiymatli flag: `head -n 5 file`, `head --lines=5 file`.
- Yakka `--` "flag'lar tugadi" degani: `rm -- -n` nomi `-n` bo'lgan faylni o'chiradi.
- Shell bo'shliq bo'yicha argumentlarga ajratadi, shuning uchun bo'shliqli nom qo'shtirnoqda yoziladi (5-darsda quoting).

### Builtin va tashqi buyruq

`ls` bu diskdagi dastur (`/usr/bin/ls`), shell uni yangi jarayon sifatida ishga tushiradi. `cd` esa shell'ning o'z ichidagi buyruq (builtin): joriy papka jarayonning xususiyati, bola jarayon ota jarayonning papkasini o'zgartira olmaydi, shuning uchun `cd` alohida dastur bo'la olmaydi.

```
type cd          # cd is a shell builtin
type -a echo     # builtin AND /usr/bin/echo: the builtin wins
which ls         # only searches PATH, does not know builtins and aliases
```

`which` o'rniga `type` ishlating: `type` alias, funksiya va builtin'larni ham ko'rsatadi.

### Kerakli klavishlar

| Klavish | Nima qiladi |
|---------|-------------|
| `Tab`, `Tab Tab` | to'ldirish, variantlar ro'yxati |
| `Ctrl+C` | joriy dasturga SIGINT yuboradi (to'xtatadi) |
| `Ctrl+D` | kiritish tugadi (EOF); bo'sh promptda shell'dan chiqadi |
| `Ctrl+L` | ekranni tozalaydi |
| `Ctrl+R` | tarix bo'yicha qidiruv |
| `Ctrl+A`, `Ctrl+E` | satr boshi, satr oxiri |
| `Ctrl+W`, `Ctrl+U` | oldingi so'zni, satr boshigacha o'chiradi |

`Ctrl+C` signal, `Ctrl+D` signal emas: u dasturga "stdin tugadi" deb bildiradi. Farqi 9-darsda (signal'lar) muhim bo'ladi.

## 5. Yordam tizimi

| Vosita | Qachon | Misol |
|--------|--------|-------|
| `man` | to'liq, rasmiy hujjat | `man ls`, `man 5 passwd` |
| `--help` | tezkor flag ro'yxati | `ls --help` |
| `help` | bash builtin'lari (ularda `man` sahifasi yo'q) | `help cd` |
| `tldr` | amaliy misollar, 5–8 ta eng ko'p ishlatiladigan holat | `tldr tar` |
| `man -k` (`apropos`) | buyruq nomini bilmasangiz, kalit so'z bo'yicha qidiruv | `man -k partition` |

### man bo'limlari

Bir nom bir nechta bo'limda bo'lishi mumkin: `passwd` ham buyruq (1), ham fayl formati (5).

| Bo'lim | Mazmuni | Misol |
|--------|---------|-------|
| 1 | foydalanuvchi buyruqlari | `man 1 ls` |
| 2 | system call'lar | `man 2 open` |
| 3 | kutubxona funksiyalari | `man 3 printf` |
| 5 | fayl formatlari va konfiguratsiya | `man 5 passwd`, `man 5 sudoers` |
| 7 | umumiy mavzular | `man 7 signal`, `man 7 hier` |
| 8 | administrator buyruqlari | `man 8 mount` |

- `man -f passwd` (`whatis`) nom qaysi bo'limlarda borligini ko'rsatadi.
- `man 7 hier` shu darsdagi FHS'ning tizimdagi tavsifi.
- man sahifasi `less` ichida ochiladi: `Space` sahifa pastga, `b` yuqoriga, `/so'z` qidiruv, `n` keyingi topilma, `g` va `G` boshi va oxiri, `q` chiqish.
- SYNOPSIS yozuvi: `[ ]` ixtiyoriy, `...` takrorlanishi mumkin, `|` yoki. Masalan `ls [OPTION]... [FILE]...`.

### tldr

`man tar` yuzlab qator, `tldr tar` bir ekran misol. `tldr` man o'rnini bosmaydi: misol bilan boshlaysiz, flag ma'nosini `man` dan tekshirasiz. O'rnatish (Rust'dagi `tealdeer` klienti, buyruq nomi `tldr`):

```
sudo apt install tealdeer     # https://tealdeer-rs.github.io/tealdeer/installing.html
tldr --update                 # download the pages cache
tldr tar
```

O'rnatmasdan ham ishlatish mumkin: https://tldr.inbrowser.app.

**Tuzoq: minimal image'da hujjat yo'q.** `ubuntu:24.04` konteyner image'idan man sahifalari, `less`, `vim`, `nano` olib tashlangan, image kichik bo'lishi uchun. Hujjatni ish mashinasida yoki VM'da o'qing.

## Tuzoqlar

- Konteyner ichidagi `uname -r` host kernel'ini ko'rsatadi. Distributivni `/etc/os-release` dan, kernel'ni `uname` dan aniqlang, ikkalasini aralashtirmang.
- `/usr` ostiga qo'lda fayl qo'ymang, paket yangilanishi ustidan yozadi. Qo'lda o'rnatiladigan narsa `/usr/local` yoki `/opt` ga.
- Diskni to'ldiradigan joy deyarli har doim `/var` (loglar, Docker ma'lumotlari, kesh). `/var` to'lsa servislar yoza olmay to'xtaydi.
- `/tmp` va `/run` dagi fayl reboot'dan keyin yo'q. PID fayl yoki socket'ni `/run` ga, saqlanadigan holatni `/var/lib` ga yozing.
- `$SHELL` hozirgi shell emas. Skript qaysi interpretatorda ishlashini birinchi qatordagi shebang (`#!`) belgilaydi, `$SHELL` emas.
- `#!/bin/sh` Ubuntu'da `dash`. Bash sintaksisi yozilgan skript ish mashinasida ishlab, serverda yoki CI'da sinadi.
- Hujjatdagi buyruq boshidagi `$` va `#` prompt belgisi. `#` bilan ko'chirilgan qator shell'da kommentga aylanadi va jimgina hech narsa qilmaydi.
- Internetdan topilgan buyruqni `man` yoki `--help` bilan tekshirmasdan `sudo` bilan ishlatmang. Flag ma'nosi distributiv va versiyaga qarab farq qilishi mumkin.

## Manbalar

- https://www.kernel.org/doc/html/latest/admin-guide/README.html – kernel nima va u qanday tarqatiladi
- https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html – Filesystem Hierarchy Standard 3.0
- https://man7.org/linux/man-pages/man7/hier.7.html – `hier(7)`, fayl tizimi ierarxiyasi
- https://man7.org/linux/man-pages/man7/bootup.7.html – `bootup(7)`, systemd bilan yuklanish ketma-ketligi
- https://man7.org/linux/man-pages/man5/proc.5.html – `proc(5)`, `/proc` dagi har bir fayl
- https://www.freedesktop.org/software/systemd/man/latest/os-release.html – `/etc/os-release` maydonlari
- https://www.gnu.org/software/bash/manual/bash.html – Bash Reference Manual
- https://tldr.sh – tldr pages loyihasi
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 1–6 boblar
- Nemeth va boshq., "UNIX and Linux System Administration Handbook" (5-nashr) – 1 va 2 boblar

---

## Vazifalar

Ish papkasi: `linux/01-intro/` (`make new m=linux n=01 name=intro` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (butun chiqish emas) va o'z so'zingiz bilan izoh. Barcha buyruqlar o'qiydigan, `sudo` ishlatilmaydi (20-vazifadagi o'rnatishdan tashqari).

### A. Kernel va distributiv

1. **Kernel version.** `uname -r`, `uname -a` va `cat /proc/version` ni bajaring. `uname -a` chiqishidagi har bir maydon nimani bildirishini `man uname` dan topib yozing. Kernel versiyasi qaysi fayldan o'qiladi?

2. **Distro identity.** `cat /etc/os-release` ni bajaring. `ID`, `ID_LIKE`, `VERSION_ID`, `VERSION_CODENAME` qiymatlarini yozing. Zorin OS'da `ID_LIKE` nima uchun ikkita qiymatga ega va bu skript yozuvchi uchun nimani anglatadi?

3. **Shared kernel.** `docker run --rm ubuntu:24.04 uname -r` va `docker run --rm ubuntu:24.04 cat /etc/os-release` ni bajaring, natijani ish mashinasidagi bilan solishtiring. Qaysi biri bir xil, qaysi biri farq qiladi va nima uchun? Shundan kelib chiqib: konteyner image'ini almashtirish bilan kernel versiyasini o'zgartirish mumkinmi?

4. **Userland origin.** `type -a ls`, `ls --version | head -1` va `dpkg -S /usr/bin/ls` ni bajaring. `ls` qaysi paketdan keladi? Shu paketdagi yana 5 ta buyruqni `dpkg -L coreutils | grep /usr/bin/ | head` orqali toping. `ls` kernel'ning qismimi?

### B. Boot

5. **Boot artifacts.** `ls -lh /boot` va `cat /proc/cmdline` ni bajaring. Qaysi fayl kernel, qaysi biri initramfs, nima uchun ularning bir nechta versiyasi bor? `/proc/cmdline` dagi `root=` va `ro` parametrlari nimani bildiradi?

6. **PID 1.** `ps -p 1 -o pid,comm` ni ish mashinasida va `docker run --rm ubuntu:24.04 ps -p 1 -o pid,comm` orqali konteynerda bajaring. Natijalar nima uchun farq qiladi? Konteynerda PID 1 nima bo'lishini kim belgilaydi?

7. **Boot timing.** `systemd-analyze` va `systemd-analyze blame | head -10` ni bajaring. Yuklanish qaysi bosqichlarga bo'lingan va har biriga qancha vaqt ketgan? Har bosqichni 2-bo'limdagi jadval qatoriga bog'lang. Eng sekin unit nima ish qiladi (`systemctl status <unit>` bilan qarang)?

8. **Kernel messages.** `journalctl -k -b | head -30` ni bajaring: kernel command line va CPU haqidagi qatorlarni toping. Keyin `sudo` siz `dmesg` ni bajaring, xatoni yozing va nima uchun oddiy foydalanuvchiga yopiqligini izohlang (`sysctl kernel.dmesg_restrict` qiymatiga qarang).

### C. Fayl tizimi

9. **Root tour.** `ls -l /` ni bajaring. Har bir papka uchun bitta gapda nima saqlanishini o'z so'zingiz bilan jadvalga yozing (darsdagi jadvalni ko'chirmang, har papkadan bitta real fayl misol keltiring). Qaysilari symlink va qayerga ko'rsatadi?

10. **One program, four places.** Docker misolida: binary qayerda (`type -a docker`), konfiguratsiya qayerda (`ls /etc/docker`), ma'lumot qayerda (`ls /var/lib/docker`). Oxirgi buyruq xato beradi: xatoni yozing va izohlang. Xuddi shu to'rt savolga (binary, konfiguratsiya, ma'lumot, log) `ssh` yoki `cups` uchun javob toping.

11. **Virtual filesystems.** `findmnt /proc`, `findmnt /sys`, `findmnt /run` va `ls -l /proc/cpuinfo` ni bajaring. Fayl hajmi nima uchun 0, lekin `cat /proc/cpuinfo | wc -l` nolga teng emas? `/proc/meminfo` dan `MemTotal` va `MemAvailable` ni, `/proc/cpuinfo` dan yadrolar sonini toping, keyin `free -h` va `nproc` bilan solishtiring.

12. **Process as files.** `echo $$` bilan shell PID'ini oling. `/proc/$$/` ichidan: `exe` qayerga ko'rsatadi, `cmdline` da nima bor, `status` dagi `PPid` kimga tegishli (`ps -p <PPid>`), `cwd` nima? Boshqa papkaga `cd` qilib `ls -l /proc/$$/cwd` ni qayta ko'ring.

13. **Device files.** `ls -l /dev/null /dev/zero /dev/urandom /dev/tty` va `lsblk` ni bajaring. `ls -l` chiqishidagi birinchi belgi (`c`, `b`) nimani bildiradi, `lsblk` dagi diskingiz `/dev` da qaysi belgi bilan turadi? `echo test > /dev/null; echo $?` va `head -c 8 /dev/urandom | od -An -tx1` natijalarini izohlang.

### D. Terminal va shell

14. **Which shell.** `echo $SHELL`, `ps -p $$ -o comm=`, `cat /etc/shells`, `ls -l /bin/sh` ni bajaring. Keyin `bash` ni ishga tushirib birinchi ikkitasini qayta bajaring. Qaysi qiymat o'zgardi, qaysi biri yo'q va nima uchun? `tty` nima qaytaradi, ikkinchi terminal oynasida-chi?

15. **Builtin or binary.** bash ichida `type -a` ni `cd`, `ls`, `echo`, `pwd`, `type`, `man`, `ll` uchun bajaring. Har birini turga ajrating (builtin, fayl, alias). `which cd` nima qaytaradi? Nima uchun `cd` tashqi dastur bo'la olmaydi?

16. **Command anatomy.** `ls -l -a -h /etc`, `ls -lah /etc` va uzun flag'lar bilan yozilgan ekvivalentini (flag nomlarini `ls --help` dan toping) bajaring va bir xil ekanini ko'rsating. Ish papkasida `touch -- -n` bilan `-n` nomli fayl yarating, uni `rm -n` bilan o'chirib ko'ring, xatoni yozing, keyin to'g'ri usulda o'chiring.

17. **Keyboard signals.** `sleep 100` ni `Ctrl+C` bilan to'xtating va darhol `echo $?` ni ko'ring. `cat` ni argumentsiz ishga tushiring, ikki qator yozing va `Ctrl+D` bilan tugating, `echo $?` ni ko'ring. Ikki exit code nima uchun farq qiladi? `Ctrl+R` bilan shu darsdagi `systemd-analyze` buyrug'ini tarixdan toping.

### E. Yordam tizimi

18. **man sections.** `man -f passwd` ni bajaring. `man passwd` va `man 5 passwd` nima haqida? `man 5 passwd` dan `/etc/passwd` qatoridagi 7 ta maydon nomini yozing va o'z foydalanuvchingiz qatorini (`grep "^$USER:" /etc/passwd`) shu bo'yicha izohlang.

19. **Reading a man page.** Faqat `man ls` dan foydalanib (qidiruv: `/`) quyidagilarni bajaradigan flag'larni toping va `/var/log` da sinang: hajm bo'yicha saralash, vaqt bo'yicha saralash, teskari tartib, faqat papkaning o'zini ko'rsatish, inode raqamini chiqarish. `man ls` SYNOPSIS qatoridagi `[ ]` va `...` nimani anglatadi?

20. **Three help sources.** bash ichida `man cd`, `cd --help` va `help cd` ni bajaring: qaysi biri ishladi va nima uchun? `tealdeer` ni o'rnatib (darsdagi buyruqlar) `tldr tar` va `man tar` ni solishtiring: papkani `.tar.gz` ga yig'ish buyrug'ini har ikkisidan toping, qaysi birida tezroq topdingiz? `man -k "copy files"` nima qaytaradi?

21. **Minimal image.** `docker run --rm -it ubuntu:24.04 bash` ichida `man ls`, `less /etc/passwd`, `vi`, `nano` ni bajarib ko'ring, har birining natijasini yozing. `ls /usr/bin | wc -l` ni konteynerda va ish mashinasida solishtiring. Image nima uchun bunday qisqartirilgan va bu production'da debug qilishga qanday ta'sir qiladi?

### F. Yakuniy

22. **System passport.** README'da ish mashinangizning "pasporti" jadvalini tuzing, ustunlar: xususiyat, qiymat, qaysi buyruq yoki fayldan olindi. Qatorlar: kernel versiyasi, arxitektura, distributiv va versiya, asos distributiv (`ID_LIKE`), firmware turi (UEFI yoki BIOS), PID 1, standart target (`systemctl get-default`), login shell, `/bin/sh` nimaga ko'rsatadi, CPU yadrolari, umumiy xotira, root fayl tizimi turi (`findmnt /`), oxirgi yuklanish vaqti. Xuddi shu jadvalni `ubuntu:24.04` konteyneri uchun to'ldiring va javob olib bo'lmaydigan qatorlarga sababini yozing.

### Topshirish

Tayyor bo'lgach:
1. `linux/01-intro/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor.
3. `make check` toza o'tadi.
4. `docker ps -a` da shu darsdan qolgan konteyner yo'q.
5. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Kernel va distributiv farqi nima, `ls` qaysi biriga tegishli?
- Nima uchun konteyner ichida `uname -r` host kernel'ini ko'rsatadi, VM ichida esa yo'q?
- Yuklanish bosqichlarini tartib bilan ayting. initramfs qaysi muammoni yechadi?
- PID 1 nima va konteynerda u nima bo'ladi?
- Bitta servisning binary, konfiguratsiya, ma'lumot va log fayllari qaysi papkalarda yotadi?
- `/proc` dagi fayllar hajmi nima uchun 0 va ularni kim "yozadi"?
- `/tmp`, `/run` va `/var/lib` orasidagi farq nima?
- Terminal emulator, TTY va shell orasidagi farq nima?
- `cd` nima uchun builtin? `which` va `type` farqi nima?
- `man 5 passwd` dagi `5` nimani bildiradi? `man`, `--help`, `help`, `tldr` har birini qachon ishlatasiz?
