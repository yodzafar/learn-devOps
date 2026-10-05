# 2-dars: Distributivlar va laboratoriya

Maqsad: Linux distributivlarining ikki asosiy oilasini (Debian asosidagi va RPM asosidagi), ularning reliz modellarini va qo'llab-quvvatlash muddatlarini tushunish, notanish serverda distributivni aniqlay olish, va kurs davomida ishlatiladigan laboratoriyani qurish: Multipass'da Ubuntu 24.04 VM va Docker'da RPM distributiv konteyneri. 1-darsda kernel va distributiv chegarasini ko'rdingiz, bu darsda distributivlar bir-biridan nimasi bilan farq qilishini ko'rasiz. Paket menejerlari bu yerda faqat tanishuv darajasida, chuqur 12-darsda.

Taxminiy vaqt: 2 kun (siz uchun). Birinchi kun nazariya va Multipass, ikkinchi kun oilalarni solishtirish. E'tiborni quyidagilarga qarating: RHEL ekotizimidagi oqim (Fedora, CentOS Stream, RHEL, Rocky/Alma), LTS va EOL nimani anglatishi, "eski versiya raqami, lekin patch qilingan" (backport) tushunchasi, VM va konteyner farqi.

## Laboratoriya

Bu darsda laboratoriya quriladi va keyingi barcha darslarda ishlatiladi.

- **Ish mashinasi**: faqat Multipass o'rnatiladi (`sudo snap install multipass`, hujjat: https://documentation.ubuntu.com/multipass/). Boshqa hech narsa o'zgartirilmaydi.
- **Multipass VM `lab`** (Ubuntu 24.04): tizimni o'zgartiradigan hamma narsa shu yerda. VM ichida `ubuntu` foydalanuvchisi parolsiz `sudo` ga ega.
- **Docker konteynerlar**: RPM oilasi va taqqoslash uchun: `rockylinux:9`, `fedora:latest`, `debian:12`, `ubuntu:24.04`.

Tozalash: dars oxirida konteynerlar o'chirilgan bo'lsin (`docker ps -a`). `lab` VM o'chirilmaydi, faqat to'xtatiladi: `multipass stop lab`. U keyingi darslarda kerak.

---

## 1. Distributiv nimalardan iborat

Distributivlar bir-biridan kernel bilan emas, quyidagilar bilan farq qiladi:

| Komponent | Nima | Farq misoli |
|-----------|------|-------------|
| Paket formati va menejeri | dastur qanday o'rnatiladi va yangilanadi | `.deb` + `apt`, `.rpm` + `dnf` |
| Repozitoriylar | qaysi dasturlar, qaysi versiyada | Ubuntu 24.04 da Python 3.12, Rocky 9 da 3.9 |
| Reliz siyosati | qancha tez-tez chiqadi, qancha vaqt yangilanadi | Fedora 6 oyda, RHEL bir necha yilda |
| Standart sozlamalar | konfiguratsiya joylari, xavfsizlik tizimi, firewall | AppArmor yoki SELinux |
| Kim boshqaradi | hamjamiyat yoki kompaniya, pullik qo'llab-quvvatlash bormi | Debian (hamjamiyat), RHEL (Red Hat) |

Init tizimi (systemd), kernel va GNU utilitalari asosiy distributivlarning hammasida bir xil loyihalardan olinadi. Shuning uchun bitta oilani yaxshi bilsangiz, ikkinchisiga o'tish asosan paket menejeri va fayl joylashuvini o'rganishdir.

## 2. Ikki oila

| | Debian oilasi | RPM (Red Hat) oilasi |
|---|---------------|----------------------|
| Distributivlar | Debian, Ubuntu, Zorin, Mint | RHEL, CentOS Stream, Fedora, Rocky, AlmaLinux, Oracle Linux |
| Paket formati | `.deb` | `.rpm` |
| Past darajali vosita | `dpkg` | `rpm` |
| Yuqori darajali menejer | `apt` | `dnf` (`yum` bu `dnf` ga symlink) |
| Repo sozlamalari | `/etc/apt/sources.list.d/` | `/etc/yum.repos.d/` |
| Admin guruhi (`sudo` huquqi) | `sudo` | `wheel` |
| Majburiy kirish nazorati (MAC) | AppArmor | SELinux |
| Standart firewall vositasi | `ufw` (Ubuntu) | `firewalld` |
| Servis sozlamalari uchun env fayllar | `/etc/default/` | `/etc/sysconfig/` |
| Tizim logi fayllari (rsyslog bo'lsa) | `/var/log/syslog`, `/var/log/auth.log` | `/var/log/messages`, `/var/log/secure` |
| Web server paketi nomi | `apache2` | `httpd` |
| `/etc/os-release` dagi `ID_LIKE` | `debian` | `rhel centos fedora` yoki `fedora` |

- Paket nomlari farq qiladi: `apache2` va `httpd`, `openssh-server` ikkalasida bir xil, `libssl-dev` va `openssl-devel`. Ansible va Dockerfile yozganda bu har doim uchraydi.
- SELinux RHEL oilasida standart yoqilgan. "Ruxsatlar to'g'ri, lekin baribir `Permission denied`" holatining RHEL'dagi birinchi gumondori.
- Ikkala oilaga ham kirmaydigan muhim distributiv: **Alpine** (`apk` paket menejeri, glibc o'rniga musl, GNU coreutils o'rniga BusyBox). Server sifatida kam, konteyner base image sifatida juda ko'p uchraydi.

### Debian oilasi

- **Debian**: hamjamiyat boshqaradi. Uch tarmoq: `unstable` (sid) dan `testing` ga, undan `stable` ga. Stable taxminan har 2 yilda chiqadi (12 "bookworm" 2023, 13 "trixie" 2025). Stable'da paket versiyalari muzlatiladi, faqat xavfsizlik va jiddiy xato tuzatishlari kiradi.
- **Ubuntu**: Canonical kompaniyasi, Debian asosida. Har 6 oyda reliz (aprel va oktabr), versiya raqami `YY.MM`. Har 2 yilda, juft yillarning aprelida **LTS** (22.04, 24.04, 26.04): 5 yil standart qo'llab-quvvatlash, Ubuntu Pro obunasi bilan uzaytiriladi. Oraliq relizlar atigi 9 oy yangilanadi, serverga qo'yilmaydi.
- Cloud'da eng ko'p uchraydigan server distributivi Ubuntu LTS. Kurs laboratoriyasi shuning uchun Ubuntu 24.04.

### RPM oilasi

Bu yerda distributivlar bir-biriga "oqim" bo'lib bog'langan:

```
Fedora  ->  CentOS Stream  ->  RHEL  ->  Rocky Linux, AlmaLinux, Oracle Linux
(upstream)  (next RHEL minor)  (paid)    (RHEL-compatible, free)
```

| Distributiv | Kim | Roli | Reliz |
|-------------|-----|------|-------|
| Fedora | hamjamiyat, Red Hat homiyligida | yangi texnologiyalar sinovi, RHEL uchun upstream | 6 oyda bir, har reliz taxminan 13 oy yangilanadi |
| CentOS Stream | Red Hat | RHEL'ning keyingi minor versiyasiga ketadigan o'zgarishlar oqimi | uzluksiz, minor versiyalar yo'q |
| RHEL | Red Hat | pullik obuna, sertifikatlangan, korporativ standart | major versiya uzoq yillar qo'llab-quvvatlanadi, minor versiyalar taxminan 6 oyda |
| Rocky Linux | hamjamiyat (RESF) | RHEL bilan mos bepul qayta yig'ma | RHEL ortidan |
| AlmaLinux | hamjamiyat (AlmaLinux OS Foundation) | RHEL bilan binary mos (ABI) bepul distributiv | RHEL ortidan |
| Oracle Linux | Oracle | RHEL bilan mos, bepul; qo'shimcha UEK kernel taklif qiladi | RHEL ortidan |

Tarixni bilish kerak, chunki eski hujjatlar va serverlarda uchraydi: **CentOS Linux** RHEL'ning bepul nusxasi edi. CentOS Linux 8 qo'llab-quvvatlashi 2021-yil oxirida, CentOS Linux 7 esa 2024-yil 30-iyunda tugadi. O'rnini Rocky va AlmaLinux egalladi. **CentOS Stream** boshqa narsa: u RHEL'dan keyin emas, oldin turadi.

**Tuzoq: "CentOS" so'zi ikki xil narsani anglatadi.** "CentOS 7 server" bu EOL bo'lgan, yangilanish olmaydigan tizim. "CentOS Stream 9" tirik, lekin RHEL'ning aniq nusxasi emas. Vakansiya yoki hujjatda "CentOS" ko'rsangiz qaysi biri ekanini aniqlang.

## 3. Reliz modellari va qo'llab-quvvatlash

| Model | Qanday ishlaydi | Misol | Qayerga mos |
|-------|-----------------|-------|-------------|
| Point release (stable) | versiya chiqadi, paketlar muzlatiladi, faqat tuzatishlar | Debian, Ubuntu LTS, RHEL, Rocky | serverlar |
| Stream | bitta major ichida uzluksiz yangilanish | CentOS Stream | RHEL uchun dastur tayyorlash, test |
| Tez reliz | 6 oyda yangi versiya, qisqa qo'llab-quvvatlash | Fedora, Ubuntu oraliq relizlari | ish stansiyasi, yangi kernel kerak bo'lsa |
| Rolling | versiya yo'q, har doim eng yangi paketlar | Arch, openSUSE Tumbleweed | shaxsiy mashina |

- **LTS** (Long Term Support): uzoq muddat xavfsizlik yangilanishi oladigan reliz.
- **EOL** (End of Life): shu kundan keyin xavfsizlik tuzatishlari chiqmaydi, repozitoriylar arxivga ko'chiriladi. EOL tizim ishlayveradi, lekin har yangi zaiflik unda abadiy ochiq qoladi.
- **Backport**: stable distributiv paketning upstream versiyasini o'zgartirmaydi, xavfsizlik tuzatishini eski versiyaga ko'chiradi. Ubuntu 24.04 dagi OpenSSH paketi `1:9.6p1-3ubuntu13.x` ko'rinishida: upstream versiya 9.6p1 bo'lib qoladi, oxiridagi distributiv revizyasi o'sadi.

**Tuzoq: versiya raqamiga qarab zaiflikni baholash.** Xavfsizlik skaneri "OpenSSH 9.6 zaif" deydi, lekin distributiv tuzatishni backport qilgan bo'lishi mumkin. Haqiqatni paketning changelog'i va distributivning security tracker'i ko'rsatadi, upstream versiya raqami emas.

### Server uchun tanlash

- Kompaniyada nima standart bo'lsa o'sha. Aralash park ekspluatatsiyani qimmatlashtiradi.
- Vendor sertifikati yoki pullik qo'llab-quvvatlash talab qilinsa: RHEL yoki Ubuntu Pro.
- Faqat qo'llab-quvvatlanadigan versiya, va uning EOL sanasi loyiha muddatidan uzoqroq.
- Konteyner base image alohida qaror: kichik hajm va kam zaiflik muhim (`debian:12-slim`, `alpine`, distroless). Docker modulida.

## 4. Distributivni aniqlash

Standart usul: `/etc/os-release`. Bu systemd standarti, barcha zamonaviy distributivlarda bor va shell o'zgaruvchilari formatida yozilgan.

| Maydon | Ma'nosi | Ubuntu 24.04 | Zorin OS 18 |
|--------|---------|--------------|-------------|
| `ID` | distributivning mashina o'qiydigan nomi | `ubuntu` | `zorin` |
| `ID_LIKE` | qaysi distributiv(lar)ga o'xshash, yaqinidan uzog'iga | `debian` | `ubuntu debian` |
| `VERSION_ID` | versiya raqami | `24.04` | `18` |
| `VERSION_CODENAME` | kod nomi, repo yo'llarida ishlatiladi | `noble` | `noble` |
| `PRETTY_NAME` | odam o'qiydigan nom | `Ubuntu 24.04.x LTS` | `Zorin OS 18.x` |

```
. /etc/os-release && echo "$ID $VERSION_ID"   # source the file, then use the variables
```

- Skriptda oilani aniqlash uchun `ID` ni, mos kelmasa `ID_LIKE` ni tekshiring. Faqat `ID == ubuntu` deb yozilgan skript Zorin yoki Mint'da ishlamaydi.
- `lsb_release -a` har doim ham o'rnatilgan emas (minimal image'larda yo'q), unga tayanmang.
- `hostnamectl` distributiv, kernel, arxitektura va virtualizatsiya turini birga ko'rsatadi (systemd bor joyda).
- Eski usullar: `/etc/debian_version`, `/etc/redhat-release`. Eski skriptlarda uchraydi.

## 5. Laboratoriya: VM va konteyner

| | VM (Multipass) | Konteyner (Docker) |
|---|----------------|--------------------|
| Kernel | o'ziniki | host bilan umumiy |
| PID 1 | `systemd` | siz ishga tushirgan dastur |
| Boot, servislar, `systemctl` | bor | yo'q |
| Disk qurilmalari, mount, LVM, swap | to'liq | cheklangan |
| Ishga tushish | o'nlab soniya | bir soniyadan kam |
| Qachon | users, systemd, firewall, disk, kernel parametrlari | paket menejeri, fayl buyruqlari, distributivlarni tez solishtirish |

Qoida: vazifa servis, foydalanuvchi, disk yoki tarmoq sozlamasiga tegsa VM, aks holda konteyner yetadi.

### Multipass

Multipass Canonical'ning Ubuntu VM'larini bitta buyruq bilan yaratadigan vositasi. Linux'da QEMU/KVM ustida ishlaydi, shuning uchun CPU virtualizatsiyasi yoqilgan bo'lishi kerak.

```
grep -Ec '(vmx|svm)' /proc/cpuinfo      # > 0 means hardware virtualization is available
sudo snap install multipass
multipass version
multipass find                          # available images
```

```
multipass launch 24.04 --name lab --cpus 2 --memory 2G --disk 10G
multipass list                          # name, state, IPv4, image
multipass info lab                      # resources, load, disk and memory usage
multipass shell lab                     # interactive shell as user "ubuntu"
multipass exec lab -- uname -r          # run one command without entering
```

| Buyruq | Nima qiladi |
|--------|-------------|
| `multipass stop lab`, `multipass start lab` | to'xtatish, ishga tushirish (disk saqlanadi) |
| `multipass transfer file.txt lab:/home/ubuntu/` | fayl ko'chirish (ikki tomonga ham) |
| `multipass snapshot lab --name clean` | snapshot (VM to'xtatilgan bo'lishi kerak) |
| `multipass restore lab.clean` | snapshot'ga qaytarish |
| `multipass delete lab` | o'chirilgan deb belgilaydi, `multipass recover lab` bilan qaytariladi |
| `multipass purge` | o'chirilgan VM'larni butunlay yo'q qiladi |

Xavfli vazifadan oldin snapshot oling: tizimni buzsangiz qayta o'rnatish o'rniga bir buyruq bilan qaytasiz.

### RPM distributiv Docker'da

```
docker run --rm -it rockylinux:9 bash       # throwaway: removed on exit
docker run -it --name rocky rockylinux:9 bash   # kept after exit
docker start -ai rocky                      # re-enter the kept container
docker rm rocky                             # remove it
```

Boshqa image'lar: `almalinux:9`, `fedora:latest`, `oraclelinux:9`, `quay.io/centos/centos:stream9`. Bu image'lar minimal: `man`, `less`, ba'zan `ps` va `which` ham yo'q, kerak bo'lsa `dnf install -y <paket>` bilan o'rnatiladi.

**Tuzoq: `--rm` konteyneridagi ish yo'qoladi.** Bir necha vazifa davomida holat kerak bo'lsa nomlangan konteyner (`--name`) ishlating va oxirida `docker rm` bilan o'chiring.

## Tuzoqlar

- EOL distributivda qolish. Tizim ishlayveradi, lekin paket o'rnatish sinadi (repozitoriylar arxivga ko'chgan) va zaifliklar yopilmaydi. EOL sanasini oldindan bilish va migratsiyani rejalashtirish ops ishining bir qismi.
- CentOS Linux va CentOS Stream'ni aralashtirish. Birinchisi o'lgan, ikkinchisi RHEL'dan oldingi oqim.
- Oraliq (LTS bo'lmagan) Ubuntu relizini serverga qo'yish: 9 oydan keyin majburiy upgrade.
- Skriptda distributivni faqat `ID` bo'yicha yoki `lsb_release` orqali aniqlash. `ID_LIKE` ni ham tekshiring.
- Bir oila uchun yozilgan ko'rsatmani ikkinchisida ko'r-ko'rona bajarish: paket nomi, konfiguratsiya yo'li, admin guruhi (`sudo` va `wheel`) farq qiladi.
- Upstream versiya raqamiga qarab "zaif" yoki "eski" deb xulosa qilish. Stable distributivlar tuzatishni backport qiladi.
- Konteynerda ishlagan narsa VM yoki serverda ham ishlaydi deb o'ylash. Konteynerda systemd, SELinux siyosati va alohida kernel yo'q.
- Ish mashinasida tajriba qilish. Tizimni o'zgartiradigan har qanday buyruq `lab` VM yoki konteynerda.

## Manbalar

- https://documentation.ubuntu.com/multipass/ – Multipass rasmiy hujjati (o'rnatish, buyruqlar, snapshot)
- https://www.freedesktop.org/software/systemd/man/latest/os-release.html – `os-release` maydonlari
- https://ubuntu.com/about/release-cycle – Ubuntu reliz sikli va LTS muddatlari
- https://www.debian.org/releases/ – Debian relizlari, stable, testing, unstable
- https://wiki.debian.org/LTS – Debian LTS
- https://access.redhat.com/support/policy/updates/errata – RHEL life cycle
- https://www.centos.org/centos-stream/ – CentOS Stream nima
- https://docs.fedoraproject.org/en-US/releases/lifecycle/ – Fedora reliz sikli
- https://wiki.rockylinux.org/rocky/version/ – Rocky Linux versiyalari va muddatlari
- https://wiki.almalinux.org/release-notes/ – AlmaLinux relizlari
- https://endoflife.date – ko'p mahsulotlar uchun EOL sanalari (norasmiy, lekin qulay; rasmiy sahifa bilan tekshiring)
- https://hub.docker.com/_/rockylinux – Rocky Linux rasmiy Docker image

---

## Vazifalar

Ish papkasi: `linux/02-distros/` (`make new m=linux n=02 name=distros` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Har vazifada qayerda bajarganingizni (ish mashinasi, `lab` VM, qaysi konteyner) ko'rsating.

### A. Distributivni aniqlash

1. **os-release fields.** Ish mashinasida `/etc/os-release` ni o'qing va 4-bo'limdagi beshta maydon qiymatini yozing. `hostnamectl` chiqishi bilan solishtiring: u qo'shimcha nima ko'rsatadi? `lsb_release -a` ishlaydimi?

2. **Four images.** `ubuntu:24.04`, `debian:12`, `rockylinux:9`, `fedora:latest` image'larining har birida `cat /etc/os-release` ni bajaring (`docker run --rm <image> cat /etc/os-release`). Jadval tuzing: `ID`, `ID_LIKE`, `VERSION_ID`. `ID_LIKE` bo'yicha oilani qanday aniqlaysiz? Fedora va Debian'da `ID_LIKE` bormi, nima uchun?

3. **Detection one-liner.** `/etc/os-release` ni source qilib `ID` va `VERSION_ID` ni chiqaradigan bir qatorli buyruqni yozing va to'rttala image'da ishlating (`docker run --rm <image> sh -c '...'`). Nima uchun buyruqni bitta tirnoq ichida berish kerak? Xuddi shu konteynerlarda `lsb_release -a` ni bajarib ko'ring va xatoni yozing.

4. **Tool presence.** Har to'rttala image'da `command -v apt dpkg dnf yum rpm` ni bajaring va qaysi vosita qayerda borligini jadvalga yozing. Rocky'da `ls -l /usr/bin/yum` nimani ko'rsatadi?

### B. Multipass

5. **Install Multipass.** Virtualizatsiya mavjudligini tekshiring, Multipass'ni o'rnating, `multipass version` va `multipass find` natijasini yozing. `multipass find` dagi `24.04` image'ining alias'lari qanday?

6. **Launch the lab VM.** `lab` nomli VM'ni 2 CPU, 2G xotira, 10G disk bilan yarating. `multipass list` va `multipass info lab` dan IP manzil, reliz, disk va xotira ishlatilishini yozing. `multipass shell lab` bilan kirib `whoami`, `id`, `sudo -l` ni bajaring: `ubuntu` foydalanuvchisi qaysi guruhlarda va `sudo` huquqi qanday berilgan?

7. **VM versus container.** `lab` VM'da va `ubuntu:24.04` konteynerida quyidagilarni bajarib jadvalga yozing: `uname -r`, `ps -p 1 -o comm=`, `systemctl is-system-running`, `lsblk`, `cat /proc/cmdline`. Har farqni izohlang. Qaysi biri ish mashinasining kernel'ini ko'rsatdi?

8. **Exec and transfer.** VM'ga kirmasdan `multipass exec` orqali `/etc/os-release` ni o'qing. Ish papkasida `hello.txt` yarating, uni VM'ga ko'chiring, VM ichida o'zgartiring va `from-vm.txt` nomi bilan qaytarib oling. `multipass exec lab -- ls -l | wc -l` da `wc` qayerda bajariladi: VM'da yoki ish mashinasida? Buni qanday isbotlaysiz?

9. **Snapshot and restore.** VM'ni to'xtatib `clean` nomli snapshot oling. VM'ni ishga tushiring, ichida `sudo touch /etc/lab-marker` va `sudo apt remove -y nano` ni bajaring. Snapshot'ga qayting va marker fayl ham, `nano` ham avvalgi holatda ekanini tekshiring. Ishlab turgan VM'dan snapshot olishga urinib ko'ring va xatoni yozing.

10. **Delete and recover.** `multipass launch 24.04 --name tmp` bilan ikkinchi VM yarating. `multipass delete tmp` dan keyin `multipass list` nimani ko'rsatadi? Uni `recover` bilan qaytaring, yana `delete` qiling va `multipass purge` bilan butunlay o'chiring. `delete` va `purge` farqini izohlang. `lab` VM joyida qolganini tekshiring.

### C. Oilalar farqi

11. **First package install.** `ubuntu:24.04` konteynerida `apt update && apt install -y nano`, `rockylinux:9` konteynerida `dnf install -y nano` ni bajaring. Ubuntu'da `apt update` siz o'rnatishga urinib ko'ring va xatoni yozing: nima uchun Debian oilasida avval `update` kerak? Har ikki menejer o'rnatishdan oldin nimalarni ko'rsatadi?

12. **Package naming.** Apache web serveri haqida ma'lumotni o'rnatmasdan oling: Ubuntu'da `apt show apache2`, Rocky'da `dnf info httpd`. Versiya, hajm va tavsifni solishtiring. Ubuntu'da `apt show httpd`, Rocky'da `dnf info apache2` nima deydi?

13. **Package ownership.** `bash` binary'si qaysi paketga tegishli: Ubuntu'da `dpkg -S /usr/bin/bash`, Rocky'da `rpm -qf /usr/bin/bash`. O'rnatilgan paketlar soni: `dpkg -l | grep -c '^ii'` va `rpm -qa | wc -l`. Minimal image'lar nechta paketdan iborat, `lab` VM'da-chi?

14. **Family layout.** Ubuntu va Rocky konteynerlarida quyidagilarni solishtirib jadval tuzing: `getent group sudo wheel`, `ls /etc/default /etc/sysconfig`, `ls /etc/apt /etc/yum.repos.d`. Qaysi papka va guruh qaysi oilaga xos? Bitta `.repo` faylni va Ubuntu'dagi `/etc/apt/sources.list.d/` ichidagi faylni o'qib, umumiy maydonlarni (URL, komponent, kalit) toping.

15. **Backported fixes.** `lab` VM'da `apt list --installed 2>/dev/null | grep openssh-server` bilan paket versiyasini oling va versiya satrining qismlarini (upstream versiya, distributiv revizyasi) ajrating. `apt changelog openssh-server | head -40` da CVE raqami bilan yozuv toping. Upstream versiya shu tuzatishdan keyin o'zgarganmi? Bundan xavfsizlik skaneri natijalarini o'qish uchun qanday xulosa chiqadi?

### D. Reliz va EOL

16. **EOL in practice.** `docker run --rm -it centos:7 bash` ichida `cat /etc/os-release` va `yum install -y nano` ni bajaring. Xatoni to'liq o'qing va nima sodir bo'lganini izohlang. Agar production'da shunday server sizga meros qolsa, birinchi uchta qadamingiz nima bo'ladi (tuzatib bermang, rejani yozing)?

17. **Support table.** Rasmiy sahifalardan (Manbalar bo'limi) foydalanib jadval to'ldiring: Ubuntu 22.04, Ubuntu 24.04, Debian 12, Debian 13, Rocky Linux 9, CentOS Stream 9, eng so'nggi Fedora. Ustunlar: chiqqan sana, standart qo'llab-quvvatlash tugash sanasi, manba URL. Bugungi sanaga ko'ra qaysi birini yangi serverga qo'ygan bo'lardingiz va qaysi birini yo'q?

18. **Kernel per distro.** `lab` VM'da `uname -r` ni, Rocky konteynerida `dnf info kernel` dagi versiyani, ish mashinasida `uname -r` ni yozing. Bir vaqtda qo'llab-quvvatlanayotgan uchta tizimda kernel versiyalari nima uchun bunchalik farq qiladi? Eski kernel raqami "xavfsiz emas" deganimi (15-vazifa xulosasini qo'llang)?

### E. Yakuniy

19. **Distro decision.** Uch holat uchun distributiv va versiyani tanlang, har biriga 3–4 gap asos yozing (reliz modeli, EOL sanasi, oila, qo'llab-quvvatlash): (a) bank ichki tizimi, vendor sertifikati va pullik support talab qilinadi; (b) startap, AWS'da 10 ta web server, jamoada Debian oilasi tajribasi bor; (c) Node.js servisi uchun Docker base image. Har holatda rad etilgan bitta muqobilni va sababini ham yozing.

20. **Lab cheat sheet.** README oxirida o'zingiz uchun laboratoriya eslatmasini yozing: `lab` VM'ni ishga tushirish, kirish, snapshot olish va qaytarish, to'xtatish; Ubuntu va Rocky konteynerini bir martalik va nomlangan holda ishga tushirish; tozalash buyruqlari. Har buyruqni yozishdan oldin bajarib tekshiring. Oxirida `multipass stop lab` qiling va `multipass list`, `docker ps -a` natijasini qo'shing.

### Topshirish

Tayyor bo'lgach:
1. `linux/02-distros/README.md` da 20 ta vazifa `## N. Title` sarlavhalari ostida.
2. `make check` toza o'tadi.
3. `docker ps -a` da shu darsdan qolgan konteyner yo'q, `multipass list` da faqat `lab` (Stopped) bor.
4. `lab` VM'da `clean` snapshot mavjud (`multipass info lab`).
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Distributivlar bir-biridan nimalari bilan farq qiladi, nimalari bir xil?
- Fedora, CentOS Stream, RHEL va Rocky Linux o'zaro qanday bog'langan?
- CentOS Linux va CentOS Stream farqi nima?
- LTS va EOL nima? EOL tizimda aynan nima ishlamay qoladi?
- Backport nima va nima uchun paketning upstream versiya raqami zaiflik haqida to'liq ma'lumot bermaydi?
- Skriptda distributiv oilasini qanday ishonchli aniqlaysiz?
- `sudo` guruhi va `wheel` guruhi qayerda uchraydi?
- Qaysi vazifalar uchun konteyner yetarli, qaysilari uchun VM shart? Nima uchun?
- Multipass'da `delete` va `purge` farqi nima, snapshot qachon olinadi?
