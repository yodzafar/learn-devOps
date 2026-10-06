# Linux o'quv rejasi (operatsion tizimlar: buyruq satridan server ekspluatatsiyasigacha)

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. Terminalda `cd`, `ls`, `git` va `npm` darajasida ishlagan, lekin operatsion tizimning o'zi (kernel, jarayonlar, ruxsatlar, servislar, disklar) yangi soha deb olinadi. Shuning uchun darslar hech narsani "tanish" deb o'tkazib yubormaydi: har atama birinchi uchraganda ta'riflanadi, har mavzu mexanizmi va ishlaydigan misoli bilan beriladi.

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni laboratoriyada bajarib javoblarni `README.md` ga yozasiz, men buyruqlar, natija talqini va tushuntirishlarni tekshirib xato va xavfli odatlarni ko'rsataman.
Har dars uchun alohida papka: `linux/01-intro/`, `linux/02-distros/` va hokazo. Yaratish: `make new m=linux n=01 name=intro`.

Kurs yo'l xaritasidagi mavzular: "Linuxga kirish", "Distributivlar (Debian-based, RPM-based)", "Asosiy buyruqlar", "Muharrirlar (Nano, Vim)", "Shell va muhit", "Fayllar bilan ishlash", "Matn qayta ishlash", "Server resurslarini ko'rish", "Jarayonlar", "Foydalanuvchilar", "Servislar (systemd)", "Paketlar (apt, yum, dnf)", "Disk va fayl tizimlari". Har mavzu bitta dars.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har darsning muddati o'sha darsning `Taxminiy vaqt` qatorida, bu jadval ularning yig'indisi. Hafta 5 o'quv kuni deb olinadi.

| Bosqich | Darslar | Dars bo'yicha (kun) | Siz uchun | Sabab |
|---------|---------|---------------------|-----------|-------|
| I - Asoslar | 4 | 1-dars: 3, 2-dars: 3, 3-dars: 3, 4-dars: 4 | 13 kun | Kernel va distributiv chegarasi, boot, FHS, oilalar farqi, `find`, Vim grammatikasi. Hammasi VM ichida qo'lda bajariladi, Vim mashqi qisqartirilmaydi |
| II - Shell va matn | 3 | 5-dars: 5, 6-dars: 5, 7-dars: 5 | 15 kun | Quoting, startup fayllar, ruxsat modeli, regex dialektlari va `awk` keyingi hamma modulda kerak, shoshilmang |
| III - Tizim boshqaruvi | 4 | 8-dars: 3, 9-dars: 3, 10-dars: 3, 11-dars: 5 | 14 kun | Butunlay yangi soha: load va xotira talqini, signal'lar, foydalanuvchi va guruhlar, systemd unit'lar |
| IV - Paketlar va disklar | 2 | 12-dars: 3, 13-dars: 5 | 8 kun | Repo va imzolar, inode, mount, swap, LVM. Oxirida mini-loyiha |
| **Jami** | **13** | | **50 kun (10 hafta)** | |

Bir mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz mexanizmni (nima uchun shunday ishlashini) o'z so'zingiz bilan, buyruqqa qaramasdan tushuntira olasiz.

Bu modul qolgan hamma modulning poydevori: Docker (namespace, cgroup, PID 1, volume ruxsatlari), Kubernetes (node'lar Linux, `/proc`, systemd, kubelet), CI/CD (runner'dagi shell va muhit), IaC va Ansible (paketlar, servislar, foydalanuvchilar) shu yerdagi tushunchalarga tayanadi. Shuning uchun bu yerda tezlikdan ko'ra chuqurlik muhim.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS 18 (Ubuntu 24.04 asosida, `amd64`), uyda macOS (Apple Silicon, `arm64`). Har dars ikkalasida bir xil bajariladi. Asboblarni o'rnatish va `lab` VM'ni yaratish ildizdagi `SETUP.md` da (Multipass: Zorin'da snap, macOS'da Homebrew), 1-darsdan oldin bir marta, har mashinada alohida. Har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.

| Muhit | Nima uchun | Qoidasi |
|-------|-----------|---------|
| Host (Zorin yoki macOS) | `make`, `git`, `multipass`, `docker` buyruqlari va ish papkasidagi fayllar | tizim holati o'zgartirilmaydi. macOS Linux emas (`/proc`, `systemctl`, `apt`, GNU flag'lar yo'q), Zorin'da esa ish mashinasini buzish xavfi bor, shuning uchun Linux vazifalari host'da bajarilmaydi. Host'dagi shell `zsh` bo'lishi mumkin, serverlarda bash |
| Multipass VM `lab` (Ubuntu 24.04, 2 CPU, 2G, 10G) | asosiy laboratoriya: barcha Linux buyruqlari, foydalanuvchi, guruh, `sudoers`, systemd unit, paket, disk, swap, LVM | `SETUP.md` bo'yicha yaratilgan, 2-darsda chuqur o'rganiladi. Xavfli vazifadan oldin snapshot (`multipass snapshot`), buzilsa `multipass restore`. Ikkala host'da bir xil Ubuntu, farqi faqat arxitektura |
| Docker konteynerlar | bir martalik tajribalar va RPM oilasi: `docker run --rm -it ubuntu:24.04 bash`, `docker run --rm -it rockylinux:9 bash` | host'da ishga tushiriladi. Konteynerda systemd, boot va alohida kernel yo'q, shuning uchun 8–11 va 13-darslar VM'da. macOS'da konteyner Docker Desktop'ning yashirin Linux VM'ida ishlaydi |

- **Holat ko'chishi**: laboratoriya holati (VM ichidagi fayllar, foydalanuvchilar, paketlar, snapshot'lar) mashinalar orasida ko'chmaydi, javoblar git orqali ko'chadi. Dars oldingi dars holatiga tayansa, uni ikkinchi mashinada qanday tiklash o'sha darsning "Laboratoriya" bo'limida yozilgan.
- **Skriptlar**: `task_N.sh` ish papkasida (host'da) yoziladi, VM'ga `multipass transfer` bilan ko'chirib sinaladi.
- **Ma'lumot**: 7-darsda haqiqiy nginx access logi VM ichiga yuklab olinadi (`~/lab-data`), repoga kirmaydi va commit qilinmaydi.
- **Tozalash**: har dars oxirida vaqtinchalik konteynerlar o'chiriladi (`docker ps -a`), VM to'xtatiladi (`multipass stop lab`). `lab` VM keyingi modullarda ham kerak, shuning uchun modul oxirida o'chirilmaydi.
- Javoblar `README.md` ga, skriptlar ish papkasiga. Topshirishdan oldin host'da `make check` toza bo'lishi kerak (skriptlar `shellcheck` dan o'tadi: Zorin'da `sudo apt install shellcheck`, macOS'da `brew install shellcheck`).

## I bosqich - Asoslar
1. **Linuxga kirish**: kernel va user space, distributiv nima, boot ketma-ketligi (firmware, GRUB, kernel, initramfs, systemd), FHS, `/proc` va `/sys`, terminal, TTY va shell farqi, builtin va tashqi buyruq, `man` bo'limlari, `--help`, `help`, `tldr`
2. **Distributivlar va laboratoriya**: Debian oilasi (Debian, Ubuntu) va RPM oilasi (RHEL, CentOS Stream, Fedora, Rocky, AlmaLinux, Oracle Linux), reliz modellari, LTS va EOL, backport, `/etc/os-release`, VM va konteyner farqi, Multipass VM, RPM distributiv Docker'da
3. **Asosiy buyruqlar**: yo'llar, `ls`, `cd`, `pwd`, `mkdir`, `touch` va fayl vaqtlari, `cp`, `mv`, `rm`, `cat`, `less`, globbing va brace expansion, `find` (testlar, `-exec`, `-delete`), history
4. **Muharrirlar**: Nano, Vim (rejimlar, harakatlar, operator grammatikasi, text object, qidirish va almashtirish, `:g`, visual block), minimal `.vimrc`, swap fayl, `sudoedit`, serverda `vi` bilan omon qolish

## II bosqich - Shell va matn
5. **Shell va muhit**: kengayish tartibi, shell va muhit o'zgaruvchilari, `export`, `PATH`, `.profile` va `.bashrc` yuklanish tartibi, quoting, redirection va pipe, exit code'lar, `sudo` va `sudoers`, `visudo`, birinchi bash skript, shellcheck
6. **Fayllar bilan ishlash**: ruxsat modeli va tekshiruv algoritmi, `rwx` fayl va papkada, octal, `chmod`, `umask`, `chown`, setuid, setgid, sticky bit, hard va soft linklar, `tar`, `gzip`, `xz`, `zstd`, `zip`
7. **Matn qayta ishlash**: pipe, `head`, `tail`, `wc`, `grep` va regex (BRE, ERE), `cut`, `tr`, `sort`, `uniq`, `sed`, `awk` (maydonlar, agregatsiya, assotsiativ massivlar), `xargs`, locale, haqiqiy nginx logini tahlil qilish

## III bosqich - Tizim boshqaruvi
8. **Server resurslarini ko'rish**: `uptime` va load average, CPU (`top`, `vmstat`), xotira (`free`, `available`, OOM killer), disk (`df`, `du`), loglar (`journalctl`, `/var/log`), servislar ro'yxati
9. **Jarayonlarni boshqarish**: fork va exec, `ps`, jarayon holatlari, zombie va orphan, background va foreground, job control, signal'lar (`SIGTERM`, `SIGKILL`, `SIGHUP`), `nice` va `renice`
10. **Foydalanuvchilarni boshqarish**: `/etc/passwd`, `/etc/shadow`, `/etc/group`, `useradd`, `usermod`, `userdel`, guruhlar va a'zolik, parolni bloklash, `sudoers` chuqurroq, SSH kalit bilan kirish va `~/.ssh` huquqlari, servis akkauntlari
11. **Servislarni boshqarish (systemd)**: unit turlari va joylashuvi, `systemctl`, `enable` va `start` farqi, `.service` unit yozish, `Restart=` siyosatlari, bog'liqliklar, muhit va secret'lar, drop-in override, `journalctl -u`, timer va cron, target'lar

## IV bosqich - Paketlar va disklar
12. **Paketlarni boshqarish**: `apt` va `dpkg`, `dnf`/`yum` va `rpm`, repozitoriylar va imzolar, uchinchi tomon repo'si, versiyani ushlab turish (hold, pinning), avtomatik yangilanish va tozalash, snap va flatpak (qisqa)
13. **Disk va fayl tizimlari**: blok qurilmalar va bo'limlar, inode, fayl tizimlari (ext4, xfs), `mount` va `/etc/fstab`, swap, LVM (PV, VG, LV, kengaytirish), yakuniy mini-loyiha

## Yakuniy natija

Modul tugagach siz:

- notanish Linux serverga ssh orqali kirib, distributivi, versiyasi, kernel'i, resurslari va ishlayotgan servislarini 10 daqiqada aniqlay olasiz;
- konfiguratsiya faylini `vim` yoki `nano` da tahrirlab, sintaksisini tekshirib, servisni xavfsiz qayta ishga tushira olasiz;
- `Permission denied`, `command not found`, "terminalda ishlaydi, cron'da yo'q", "disk to'ldi", "servis ko'tarilmayapti" turidagi muammolarni taxmin bilan emas, tartib bilan tashxislaysiz;
- logni `grep`, `awk`, `sort`, `uniq` bilan tahlil qilib, savolga son bilan javob bera olasiz;
- `set -euo pipefail` bilan, shellcheck'dan toza o'tadigan kichik bash skriptlar yozasiz;
- foydalanuvchi, guruh, cheklangan `sudo` qoidasi va systemd servisini noldan sozlaysiz;
- Debian va RPM oilasida paket o'rnatish, repo qo'shish va versiyani qotirishni bilasiz;
- yangi diskni bo'limlab, LVM ustida fayl tizimi yaratib, doimiy mount qilasiz va kengaytirasiz.

## Ataylab kiritilmagan

- Tarmoq (IP, DNS, firewall, `ss`, `tcpdump`, SSH tunnellar): alohida modul, `network/docs/00-reja.md`.
- Chuqur bash dasturlash (massivlar, `getopts`, katta skriptlar): bu modulda skript faqat vosita darajasida; avtomatlashtirish IaC modulida.
- Konteyner ichki tuzilishi (namespace, cgroup, overlayfs): `docker/docs/00-reja.md`.
- Monitoring va log yig'ish tizimlari: `observability/docs/00-reja.md`. Bu yerda faqat bitta serverdagi qo'l vositalari.
- SELinux va AppArmor siyosatini yozish, kernel yig'ish va tuning, eBPF, unumdorlik tahlili (`perf`, `strace` chuqur).
- Desktop Linux (grafik muhit, drayverlar), pochta va DNS serverlarini sozlash, RAID.
- LPIC yoki RHCSA imtihoniga tayyorgarlik. Kerak bo'lsa alohida so'rang.

## Manbalar

- Shotts, "The Linux Command Line" (2-nashr, https://linuxcommand.org/tlcl.php): I va II bosqich uchun asosiy kitob
- Nemeth, Snyder, Hein va boshq., "UNIX and Linux System Administration Handbook" (5-nashr): III va IV bosqich
- Ward, "How Linux Works" (3-nashr): boot, jarayonlar, disklar, systemd qanday ishlashi
- Kerrisk, "The Linux Programming Interface": mexanizmlarni chuqur tushunish uchun ma'lumotnoma (ruxsatlar, jarayonlar, signal'lar)
- Neil, "Practical Vim" (2-nashr): 4-dars
- Aho, Kernighan, Weinberger, "The AWK Programming Language" (2-nashr): 7-dars
- man sahifalari: https://man7.org/linux/man-pages/ va tizimdagi `man`
- Bash Reference Manual: https://www.gnu.org/software/bash/manual/bash.html
- GNU coreutils: https://www.gnu.org/software/coreutils/manual/coreutils.html
- systemd hujjatlari: https://www.freedesktop.org/software/systemd/man/latest/
- Ubuntu Server hujjati: https://documentation.ubuntu.com/server/
- Multipass: https://documentation.ubuntu.com/multipass/
- shellcheck: https://www.shellcheck.net/
