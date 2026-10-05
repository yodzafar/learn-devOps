# Linux o'quv rejasi (operatsion tizimlar: buyruq satridan server ekspluatatsiyasigacha)

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni laboratoriyada bajarib javoblarni `README.md` ga yozasiz, men buyruqlar, natija talqini va tushuntirishlarni tekshirib xato va xavfli odatlarni ko'rsataman.
Har dars uchun alohida papka: `linux/01-intro/`, `linux/02-distros/` va hokazo. Yaratish: `make new m=linux n=01 name=intro`.

Kurs yo'l xaritasidagi mavzular: "Linuxga kirish", "Distributivlar (Debian-based, RPM-based)", "Asosiy buyruqlar", "Muharrirlar (Nano, Vim)", "Shell va muhit", "Fayllar bilan ishlash", "Matn qayta ishlash", "Server resurslarini ko'rish", "Jarayonlar", "Foydalanuvchilar", "Servislar (systemd)", "Paketlar (apt, yum, dnf)", "Disk va fayl tizimlari". Har mavzu bitta dars.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Asoslar | 4 | 11–12 kun | 8–9 kun | Terminal, `cd`, `ls`, git va npm tanish. Yangi: kernel va distributiv chegarasi, boot, FHS, oilalar farqi, Vim grammatikasi. Vim mashqi qisqartirilmaydi |
| II - Shell va matn | 3 | 12–13 kun | 9–11 kun | `process.env`, npm skriptlar va JS regex tajribasi yordam beradi. Quoting, startup fayllar, ruxsat modeli, `awk` yangi va keyingi hamma modulda kerak, shoshilmang |
| III - Tizim boshqaruvi | 4 | 11–12 kun | 9 kun | Butunlay yangi soha: load va xotira talqini, signal'lar, foydalanuvchi va guruhlar, systemd unit'lar |
| IV - Paketlar va disklar | 2 | 6–7 kun | 5–6 kun | `apt install` tanish; repo va imzolar, inode, mount, swap, LVM yangi. Oxirida mini-loyiha |
| **Jami** | **13** | **40–44 kun** | **31–35 kun (taxminan 6–7 hafta)** | |

Dars bo'yicha taqsimot (siz uchun): 1-dars 2 kun, 2-dars 2 kun, 3-dars 2 kun, 4-dars 2–3 kun, 5-dars 3–4 kun, 6-dars 3 kun, 7-dars 3–4 kun, 8-dars 2 kun, 9-dars 2 kun, 10-dars 2 kun, 11-dars 3 kun, 12-dars 2 kun, 13-dars 3–4 kun.

Bir mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz mexanizmni (nima uchun shunday ishlashini) o'z so'zingiz bilan, buyruqqa qaramasdan tushuntira olasiz.

Bu modul qolgan hamma modulning poydevori: Docker (namespace, cgroup, PID 1, volume ruxsatlari), Kubernetes (node'lar Linux, `/proc`, systemd, kubelet), CI/CD (runner'dagi shell va muhit), IaC va Ansible (paketlar, servislar, foydalanuvchilar) shu yerdagi tushunchalarga tayanadi. Shuning uchun bu yerda tezlikdan ko'ra chuqurlik muhim.

## Laboratoriya

- **Ish mashinasi (Zorin OS 18, Ubuntu 24.04 asosida)**: faqat o'qiydigan buyruqlar (`ls`, `cat`, `ps`, `man`, `journalctl`, `find`) va ish papkasidagi fayllar. Tizim holatini o'zgartiradigan hech narsa bu yerda bajarilmaydi. Ish mashinasidagi shell `zsh`, serverlarda esa bash: shell'ga bog'liq vazifalar bash'da bajariladi.
- **Multipass VM `lab` (Ubuntu 24.04)**: asosiy laboratoriya, 2-darsda quriladi. O'rnatish: `sudo snap install multipass` (hujjat: https://documentation.ubuntu.com/multipass/). Foydalanuvchi, guruh, `sudoers`, systemd unit, paket, disk, swap, LVM, firewall bilan bog'liq hamma narsa shu yerda. Xavfli vazifadan oldin snapshot olinadi (`multipass snapshot`), buzilsa `multipass restore`.
- **Docker konteynerlar**: bir martalik tajribalar va RPM oilasi uchun: `docker run --rm -it ubuntu:24.04 bash`, `docker run --rm -it rockylinux:9 bash`. Konteynerda systemd, boot va alohida kernel yo'q, shuning uchun 8–11 va 13-darslar VM'da.
- **Ma'lumot**: 7-darsda haqiqiy nginx access logi yuklab olinadi, repo tashqarisida (`~/lab-data`) saqlanadi va commit qilinmaydi.
- **Tozalash**: har dars oxirida vaqtinchalik konteynerlar o'chiriladi (`docker ps -a`), VM to'xtatiladi (`multipass stop lab`). Modul oxirida: `multipass delete lab && multipass purge`.
- Javoblar `README.md` ga, skriptlar (`task_N.sh`) ish papkasiga. Topshirishdan oldin `make check` toza bo'lishi kerak (skriptlar `shellcheck` dan o'tadi).

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
