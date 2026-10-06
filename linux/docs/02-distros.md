# 2-dars: Distributivlar va laboratoriya

Maqsad: Linux distributivlarining ikki asosiy oilasini (Debian asosidagi va RPM asosidagi), ularning reliz modellarini va qo'llab-quvvatlash muddatlarini tushunish, notanish serverda distributivni aniqlay olish, va kurs davomida ishlatiladigan laboratoriyani ichidan bilish: Multipass'dagi Ubuntu 24.04 VM (`lab`) va Docker'dagi RPM distributiv konteyneri. 1-darsda kernel va distributiv chegarasini ko'rdingiz (kernel bitta loyiha, distributiv uning ustiga qurilgan to'plam), bu darsda distributivlar bir-biridan aynan nimasi bilan farq qilishini ko'rasiz. `SETUP.md` da `lab` VM'ni bitta buyruq bilan yaratgansiz; bu yerda o'sha buyruq ortida nima turganini, snapshot, `exec`, `transfer`, `delete` va `purge` qanday ishlashini o'rganasiz, chunki qolgan hamma dars shu laboratoriyada o'tadi. Paket menejerlari bu yerda faqat tanishuv darajasida, chuqur 12-darsda.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1, 2 va 4-bo'limlar, A guruh vazifalari. Ikkinchi kun 5-bo'lim (VM, konteyner, Multipass) va B guruhi. Uchinchi kun 3-bo'lim (reliz, EOL, backport), "Birga bajaramiz", C, D, E guruhlari va README'ni tartibga solish. E'tiborni quyidagilarga qarating: RHEL ekotizimidagi oqim (Fedora, CentOS Stream, RHEL, Rocky/Alma), LTS va EOL nimani anglatishi, "eski versiya raqami, lekin patch qilingan" (backport) tushunchasi, VM va konteyner farqi, snapshot nimani saqlaydi va nimani saqlamaydi.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi versiya raqamlari, IP manzil va hajmlar farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan. Bu darsda buyruqlar uch joyda bajariladi (host, VM, konteyner), har misolda prompt qayerda turganingizni ko'rsatadi: `$` host, `ubuntu@lab:~$` VM, `[root@<id> /]#` yoki `root@<id>:/#` konteyner.

## Laboratoriya

Bu darsda laboratoriyaning o'zi o'rganiladi. Uchta joy bor:

| Joy | Bu darsda nima bajariladi |
|-----|---------------------------|
| Host (Zorin yoki macOS) | `multipass` va `docker` buyruqlari, ish papkasidagi fayllar, `make`, `git`. Host tizimi o'zgartirilmaydi, yagona istisno: Multipass yo'q bo'lsa o'rnatish |
| `lab` VM (Ubuntu 24.04) | Debian oilasiga oid hamma narsa, `hostnamectl`, `systemctl`, `lsblk`, `apt`, snapshot tajribasi. VM ichida `ubuntu` foydalanuvchisi parolsiz `sudo` ga ega |
| Konteynerlar | distributivlarni tez solishtirish: `ubuntu:24.04`, `debian:12`, `rockylinux:9`, `fedora:latest`, bir marta `centos:7`. "Birga bajaramiz" da `almalinux:9` |

Multipass va `lab` VM `SETUP.md` bo'yicha 1-darsdan oldin o'rnatilgan. Bu darsdagi 5 va 6-vazifalar shu mavjud o'rnatishni tekshiradi, noldan qurmaydi. Agar hozir ikkinchi mashinada bo'lsangiz va u yerda hali Multipass yo'q bo'lsa, o'rnatish:

```
# Zorin (amd64): snap package, the daemon starts automatically
sudo snap install multipass

# macOS (arm64): Homebrew cask
brew install --cask multipass

# both hosts: create the lab VM
multipass launch 24.04 --name lab --cpus 2 --memory 2G --disk 10G
```

Docker ham `SETUP.md` da o'rnatilgan (Zorin'da Docker Engine, macOS'da Docker Desktop yoki muqobili). Tekshirish: `docker run --rm hello-world`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM va image'lar `amd64` (`x86_64`). Multipass snap sifatida o'rnatilgan va QEMU orqali kernel'dagi KVM'dan foydalanadi; virtualizatsiya bor-yo'qligi `/proc/cpuinfo` dan tekshiriladi. Host'ning o'zida ham `/etc/os-release` bor (`ID=zorin`), ixtiyoriy eslatmalar ishlaydi. Konteyner ichidagi `uname -r`, `lsblk`, `/proc/cmdline` Zorin'ning o'z kernel'i va disklarini ko'rsatadi. |
| macOS (uy) | VM va image'lar `arm64` (`aarch64`). Multipass Homebrew cask sifatida o'rnatilgan va QEMU orqali macOS'ning Hypervisor.framework'idan foydalanadi; `/proc/cpuinfo` yo'q, tekshiruv `sysctl kern.hv_support`. Host'da `/etc/os-release` yo'q, o'rniga `sw_vers`. Docker yashirin Linux VM ichida ishlaydi, shuning uchun konteyner ichidagi `uname -r`, `lsblk`, `/proc/cmdline` Mac'ni emas, o'sha yashirin VM'ni ko'rsatadi. `hostnamectl`, `systemctl`, `apt` host'da yo'q, faqat `lab` VM'da. |

Holat va tozalash:

- Bu dars 1-darsdagi holatga tayanmaydi: ishlaydigan `lab` VM yetarli. 1-darsda VM ichida o'rnatilgan `tealdeer` bo'lsa ham, bo'lmasa ham farqi yo'q.
- VM va snapshot'lar mashinalar orasida ko'chmaydi: ofisdagi `lab` va uydagi `lab` ikki alohida VM. 9-vazifadagi snapshot qaysi mashinada olingan bo'lsa o'sha yerda qoladi. Darsni bir mashinada boshlab ikkinchisida davom ettirsangiz, ikkinchisida `lab` borligini `multipass list` bilan tekshiring, yo'q bo'lsa yuqoridagi `launch` buyrug'i bilan yarating. Javoblar (README) git orqali ko'chadi.
- Nomlangan konteynerlar ham ko'chmaydi. Har vazifa oxirida ularni o'chiring, dars oxirida `docker ps -a` bo'sh bo'lsin.
- `lab` VM o'chirilmaydi, dars oxirida faqat to'xtatiladi: `multipass stop lab`. U keyingi hamma darsda kerak. Bu darsda yaratiladigan ikkinchi VM (`tmp`, 10-vazifa) o'sha vazifaning o'zida butunlay o'chiriladi.

---

## 1. Distributiv nimalardan iborat

### Bir xil qismlar va farqli qismlar

1-darsdan: distributiv bu kernel + user space dasturlari + paket menejeri + init tizimi + standart sozlamalar + qo'llab-quvvatlash siyosati. Asosiy server distributivlarida kernel (kernel.org), init tizimi (systemd), C kutubxonasi (glibc), shell (bash) va utilitalar (GNU coreutils) bir xil loyihalardan olinadi. Distributivlar bir-biridan o'sha loyihalarning qaysi versiyasini olgani va atrofiga nima qurgani bilan farq qiladi:

| Komponent | Nima | Farq misoli |
|-----------|------|-------------|
| Paket formati va menejeri | dastur qanday o'rnatiladi va yangilanadi | `.deb` + `apt`, `.rpm` + `dnf` |
| Repozitoriylar | qaysi dasturlar, qaysi versiyada | Ubuntu 24.04 da Python 3.12, Rocky 9 da 3.9 |
| Reliz siyosati | qancha tez-tez chiqadi, qancha vaqt yangilanadi | Fedora 6 oyda, RHEL bir necha yilda |
| Standart sozlamalar | konfiguratsiya joylari, xavfsizlik tizimi, firewall | AppArmor yoki SELinux |
| Kim boshqaradi | hamjamiyat yoki kompaniya, pullik qo'llab-quvvatlash bormi | Debian (hamjamiyat), RHEL (Red Hat) |

Repozitoriy (repo) bu distributiv saqlaydigan paketlar ombori: HTTP server ustidagi papkalar va indeks fayllari, `npm` registry'sining tizim darajasidagi o'xshashi. Farqi shundaki, npm registry'da paketning hamma versiyasi turadi va siz xohlaganini tanlaysiz, distributiv repo'sida esa har dastur uchun odatda bitta versiya bo'ladi va uni distributiv tanlagan.

### Mexanizm: distributiv qanday yig'iladi

Dasturning asl mualliflari chiqargan kod **upstream** deyiladi (bash uchun GNU loyihasi, OpenSSH uchun OpenBSD jamoasi). Distributiv jamoasi (maintainer'lar) upstream kodni oladi, o'z patch'larini qo'shadi, o'z sozlamalari bilan kompilyatsiya qiladi va **paket** qilib o'raydi. Paket bu arxiv: ichida tayyor binary'lar, konfiguratsiya fayllari, metadata (nom, versiya, bog'liqliklar ro'yxati) va o'rnatishdan oldin yoki keyin ishlaydigan skriptlar bor. Paketlar distributiv kaliti bilan imzolanadi va repo'ga qo'yiladi. Reliz kuni repo'ning shu paytdagi holati "muzlatiladi" va nom oladi (Ubuntu 24.04 "noble", Debian 12 "bookworm").

Bundan muhim natija chiqadi: bitta distributiv relizi ichidagi hamma paket bir-biri bilan birga sinovdan o'tgan to'plam. `package-lock.json` bitta loyiha uchun bog'liqliklar versiyasini qotiradi; distributiv relizi xuddi shu ishni butun operatsion tizim uchun qiladi, faqat lock faylni siz emas, distributiv jamoasi yozadi.

### Misol: bitta dastur, ikki distributivda

Host'da, ikki image'da bir xil ikki buyruq (image bu konteynerning boshlang'ich fayl tizimi, 1-dars):

```
$ docker run --rm ubuntu:24.04 bash --version | head -1
GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu)
$ docker run --rm rockylinux:9 bash --version | head -1
GNU bash, version 5.1.8(1)-release (x86_64-redhat-linux-gnu)
```

O'qilishi: dastur ikkalasida ham GNU bash, lekin Ubuntu 24.04 uning 5.2.21 versiyasini, Rocky Linux 9 esa 5.1.8 versiyasini olgan. Qavs ichidagi satr binary qaysi platforma uchun yig'ilganini aytadi: Ubuntu'da `pc-linux-gnu`, Rocky'da `redhat-linux-gnu`, ya'ni har distributiv bashni o'zi, o'z sozlamalari bilan kompilyatsiya qilgan. Mac'da `x86_64` o'rnida `aarch64` chiqadi.

```
$ docker run --rm ubuntu:24.04 ldd --version | head -1
ldd (Ubuntu GLIBC 2.39-0ubuntu8.<N>) 2.39
$ docker run --rm rockylinux:9 ldd --version | head -1
ldd (GNU libc) 2.34
```

`ldd` glibc bilan birga keladigan asbob, shuning uchun uning versiyasi glibc versiyasidir. glibc bu C standart kutubxonasi: deyarli har bir dastur (jumladan `node`) system call'larni shu kutubxona orqali qiladi (1-dars). Ubuntu 24.04 da 2.39, Rocky 9 da 2.34. Bu farq amaliy: yangiroq glibc bilan yig'ilgan binary eski glibc'li tizimda ishga tushmaydi (xato matnida `GLIBC_2.<NN> not found` bo'ladi). Shuning uchun tayyor binary'lar ko'pincha eng eski qo'llab-quvvatlanadigan distributivda yig'iladi.

### Real ishda qachon kerak

- Hujjatda "Python 3.11 kerak" deyilgan, serveringiz Rocky 9: repo'dagi standart versiya 3.9. Buni oldindan bilish o'rnatish rejasini o'zgartiradi (boshqa repo, konteyner yoki boshqa distributiv).
- Yuklab olingan binary bir serverda ishlaydi, ikkinchisida `GLIBC_... not found` deydi: sabab distributivlar orasidagi glibc versiyasi farqi.
- Bitta oilani yaxshi bilsangiz ikkinchisiga o'tish asosan paket menejeri va fayl joylashuvini o'rganishdir, chunki kernel, systemd va coreutils bir xil.

### Nima uchun shunday

Kernel, kompilyator, kutubxonalar va minglab dasturlarni manba kodidan o'zi yig'ib, bir-biriga moslab chiqish bir odam uchun haftalab ish. 1990-yillar boshida aynan shu ishni bir marta qilib, tayyor holda tarqatadigan loyihalar paydo bo'ldi (Slackware va Debian 1993-yilda, Red Hat Linux 1994–1995 yillarda). Ular ikki savolga turlicha javob berdi: paketlar qanday formatda bo'lsin va loyihani kim boshqarsin. Shu ikki javobdan bugungi ikki oila kelib chiqqan. Muqobili ham mavjud: Gentoo kabi distributivlarda har paket sizning mashinangizda manba kodidan yig'iladi, lekin serverlarda bu deyarli ishlatilmaydi, chunki sekin va takrorlanishi qiyin.

## 2. Ikki oila

### Oila nima

"Oila" bu umumiy ajdoddan chiqqan va bir xil paket formatini ishlatadigan distributivlar guruhi. Hosila distributiv (masalan Zorin) ajdodining repo'larini asos qilib oladi va ustiga o'z paketlarini qo'shadi, shuning uchun ajdod uchun yozilgan ko'rsatma unda ham ishlaydi.

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

Jadvaldagi yangi atamalar:

- **Past va yuqori darajali vosita.** `dpkg` va `rpm` bitta paket faylini o'rnatadi va o'rnatilgan paketlar bazasini yuritadi, lekin tarmoqqa chiqmaydi va bog'liqliklarni o'zi topmaydi. `apt` va `dnf` repo'dan paketni va uning barcha bog'liqliklarini topib yuklaydi, keyin o'rnatishni past darajali vositaga topshiradi. Batafsil 12-darsda.
- **Admin guruhi.** `sudo` buyrug'i (5-darsda) kimga root huquqi berishini konfiguratsiyadan o'qiydi; standart konfiguratsiyada bu ma'lum bir guruh a'zolari. Guruh nomi oilaga qarab farq qiladi.
- **MAC (Mandatory Access Control).** Oddiy fayl ruxsatlari (6-darsda) ustidan ishlaydigan ikkinchi nazorat qatlami: kernel har dastur uchun yozilgan siyosatga qarab "bu dastur bu faylga tega oladimi" deb tekshiradi, hatto dastur root bo'lsa ham. AppArmor siyosatni fayl yo'llari bo'yicha, SELinux har fayl va jarayonga yopishtirilgan yorliqlar (label) bo'yicha yozadi.
- **rsyslog.** Loglarni matn fayllarga yozadigan servis. systemd journal (1-dars) bilan yonma-yon ishlaydi; fayl nomlari oilaga qarab farq qiladi.

Yana uch narsa:

- Paket nomlari farq qiladi: `apache2` va `httpd`, `openssh-server` ikkalasida bir xil, `libssl-dev` va `openssl-devel`. Ansible va Dockerfile yozganda bu har doim uchraydi.
- SELinux RHEL oilasida standart yoqilgan. "Ruxsatlar to'g'ri, lekin baribir `Permission denied`" holatining RHEL'dagi birinchi gumondori.
- Ikkala oilaga ham kirmaydigan muhim distributiv: **Alpine** (`apk` paket menejeri, glibc o'rniga musl kutubxonasi, GNU coreutils o'rniga BusyBox). Server sifatida kam, konteyner base image sifatida juda ko'p uchraydi, `node:<versiya>-alpine` image'lari shuning ustiga qurilgan.

### Misol: oilani fayllardan tanish

`lab` VM Debian oilasidan. Jadvalning log qatorini tekshiramiz:

```
ubuntu@lab:~$ ls /var/log/syslog /var/log/auth.log /var/log/messages
ls: cannot access '/var/log/messages': No such file or directory
/var/log/auth.log  /var/log/syslog
```

Birinchi qator xato (stderr): `/var/log/messages` yo'q, chunki bu RPM oilasidagi nom. Ikkinchi qator mavjud ikki fayl: `syslog` umumiy tizim logi, `auth.log` kirish va `sudo` hodisalari. RHEL oilasidagi serverda natija teskari bo'ladi: `messages` va `secure` bor, `syslog` va `auth.log` yo'q. Internetdagi ko'rsatma "`tail /var/log/messages` ni qarang" desa, u RPM oilasi uchun yozilgan, Ubuntu'da o'sha ma'lumot `/var/log/syslog` da.

### Debian oilasi

- **Debian**: hamjamiyat boshqaradi, ortida kompaniya yo'q. Uch tarmoq bor: yangi paket avval `unstable` (kod nomi doim "sid") ga tushadi, bir muddat jiddiy xatosiz tursa `testing` ga o'tadi, `testing` esa taxminan har 2 yilda muzlatilib yangi `stable` bo'ladi (12 "bookworm" 2023, 13 "trixie" 2025). Stable'da paket versiyalari muzlatiladi, faqat xavfsizlik va jiddiy xato tuzatishlari kiradi.
- **Ubuntu**: Canonical kompaniyasi, Debian asosida (har reliz uchun paketlar Debian `unstable` dan olinadi va Ubuntu patch'lari qo'shiladi). Har 6 oyda reliz (aprel va oktabr), versiya raqami `YY.MM`. Har 2 yilda, juft yillarning aprelida **LTS** (22.04, 24.04, 26.04): 5 yil standart qo'llab-quvvatlash, Ubuntu Pro obunasi bilan uzaytiriladi. Oraliq relizlar atigi 9 oy yangilanadi, serverga qo'yilmaydi.
- **Zorin OS**: Ubuntu LTS asosidagi desktop distributiv, ofisdagi host'ingiz. Paketlarining ko'pi to'g'ridan-to'g'ri Ubuntu repo'laridan keladi.
- Cloud'da eng ko'p uchraydigan server distributivi Ubuntu LTS. Kurs laboratoriyasi shuning uchun Ubuntu 24.04.

### RPM oilasi

Bu yerda distributivlar bir-biriga "oqim" bo'lib bog'langan: o'zgarish chapdan o'ngga oqadi.

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

Mexanizm: bir necha yilda bir marta Red Hat Fedora'ning ma'lum relizidan shoxlab yangi RHEL major versiyasini boshlaydi (RHEL 9 Fedora 34 asosida). Shundan keyin o'sha major uchun barcha o'zgarishlar avval CentOS Stream'ga tushadi, sinovdan o'tadi va taxminan har 6 oyda RHEL'ning navbatdagi minor versiyasi (9.4, 9.5) sifatida chiqadi. Rocky va AlmaLinux RHEL chiqqach uning bilan mos paketlarni o'zlari yig'ib chiqaradi. "Binary mos (ABI)" degani: RHEL uchun yig'ilgan dastur qayta kompilyatsiyasiz ishlaydi. ABI (Application Binary Interface) bu yig'ilgan dastur va kutubxonalar orasidagi kelishuv: funksiya nomlari, argumentlar tartibi, ma'lumot tuzilmalari o'lchami.

Tarixni bilish kerak, chunki eski hujjatlar va serverlarda uchraydi: **CentOS Linux** RHEL'ning bepul nusxasi edi va oqimda RHEL'dan keyin turardi. CentOS Linux 8 qo'llab-quvvatlashi 2021-yil oxirida, CentOS Linux 7 esa 2024-yil 30-iyunda tugadi. O'rnini Rocky va AlmaLinux egalladi. **CentOS Stream** boshqa narsa: u RHEL'dan keyin emas, oldin turadi.

**Tuzoq: "CentOS" so'zi ikki xil narsani anglatadi.** "CentOS 7 server" bu EOL bo'lgan, yangilanish olmaydigan tizim. "CentOS Stream 9" tirik, lekin RHEL'ning aniq nusxasi emas. Vakansiya yoki hujjatda "CentOS" ko'rsangiz qaysi biri ekanini aniqlang.

### Real ishda qachon kerak

- Internetdan topilgan ko'rsatmani o'qiyotganda birinchi savol: bu qaysi oila uchun yozilgan? `apt`, `/etc/default`, `apache2` ko'rsangiz Debian oilasi; `dnf` yoki `yum`, `/etc/sysconfig`, `httpd` ko'rsangiz RPM oilasi.
- Dockerfile'da base image'ni almashtirsangiz (`debian` dan `alpine` ga yoki `rockylinux` ga) paket o'rnatish qatorlari ham, paket nomlari ham o'zgaradi.
- Yangi ishda "bizda RHEL" deyilsa: SELinux yoqilgan, firewall `firewalld`, admin guruhi `wheel`, loglar `/var/log/messages` va `/var/log/secure` da deb kutasiz.

### Nima uchun shunday

Ikki oila ikki xil boshqaruv modelidan o'sgan. Debian 1993-yilda ko'ngillilar loyihasi sifatida boshlangan va shundayligicha qolgan; Ubuntu 2004-yilda uning ustiga "aniq jadval bo'yicha reliz va tijorat qo'llab-quvvatlash" qo'shdi. Red Hat esa boshidan tijorat kompaniyasi: 2003-yilda bepul Red Hat Linux ikkiga bo'lindi, pullik RHEL va hamjamiyat distributivi Fedora. RHEL manba kodi ochiq bo'lgani uchun uni bepul qayta yig'adigan CentOS paydo bo'ldi; 2020-yil dekabrda Red Hat CentOS Linux'ni to'xtatib CentOS Stream'ga o'tishini e'lon qilgach, o'sha bo'shliqni Rocky Linux va AlmaLinux to'ldirdi. Paket formatlari ham shu tarixdan: `.deb` Debian'da, `.rpm` Red Hat'da yaratilgan va ikkalasi 30 yildan beri parallel yashaydi, chunki har birining ustida minglab paket va asboblar qurilgan.

## 3. Reliz modellari va qo'llab-quvvatlash

### To'rt model

Reliz modeli bu distributiv paketlarni qachon va qanday yangilashi haqidagi qoida.

| Model | Qanday ishlaydi | Misol | Qayerga mos |
|-------|-----------------|-------|-------------|
| Point release (stable) | versiya chiqadi, paketlar muzlatiladi, faqat tuzatishlar | Debian, Ubuntu LTS, RHEL, Rocky | serverlar |
| Stream | bitta major ichida uzluksiz yangilanish | CentOS Stream | RHEL uchun dastur tayyorlash, test |
| Tez reliz | 6 oyda yangi versiya, qisqa qo'llab-quvvatlash | Fedora, Ubuntu oraliq relizlari | ish stansiyasi, yangi kernel kerak bo'lsa |
| Rolling | versiya yo'q, har doim eng yangi paketlar | Arch, openSUSE Tumbleweed | shaxsiy mashina |

- **LTS** (Long Term Support): uzoq muddat xavfsizlik yangilanishi oladigan reliz.
- **EOL** (End of Life): shu kundan keyin xavfsizlik tuzatishlari chiqmaydi, repozitoriylar arxivga ko'chiriladi. EOL tizim ishlayveradi, lekin har yangi zaiflik unda abadiy ochiq qoladi va paket o'rnatish sinadi, chunki paket menejeri eski repo manzilidan javob ololmaydi.
- **CVE** (Common Vulnerabilities and Exposures): ommaga e'lon qilingan zaiflikning yagona raqami, `CVE-<yil>-<raqam>` ko'rinishida. Skanerlar va changelog'lar shu raqam bilan gaplashadi.

### Mexanizm: backport

Stable distributiv reliz paytida har paketning upstream versiyasini muzlatadi. Upstream keyinroq zaiflikni yangi versiyada tuzatsa, distributiv yangi versiyaga o'tmaydi: maintainer faqat o'sha tuzatish patch'ini olib, muzlatilgan eski versiyaga qo'llaydi va paketni qayta yig'adi. Bu **backport** deyiladi. Natijada upstream versiya raqami o'zgarmaydi, faqat oxiridagi distributiv revizyasi o'sadi.

```
ubuntu@lab:~$ dpkg-query -W openssl
openssl	3.0.13-0ubuntu3.<N>
```

`dpkg-query -W` o'rnatilgan paketning nomi va versiyasini chiqaradi. Versiya satri oxirgi `-` belgisidan ikkiga bo'linadi. Chap qism `3.0.13`: upstream versiya, Ubuntu 24.04 chiqqan 2024-yil aprelidan beri o'zgarmagan. O'ng qism `0ubuntu3.<N>`: distributiv revizyasi; `0` bu paket Debian revizyasisiz, to'g'ridan-to'g'ri Ubuntu'da yig'ilganini bildiradi, `ubuntu3` Ubuntu'ning reliz paytidagi revizyasi, nuqtadan keyingi `<N>` esa relizdan keyin chiqqan har yangilanishda o'sadi. Ba'zi paketlarda boshida `1:` kabi epoch ham bo'ladi (Ubuntu 24.04 dagi OpenSSH: `1:9.6p1-3ubuntu13.<N>`): epoch upstream raqamlash sxemasini o'zgartirganda versiyalarni to'g'ri solishtirish uchun qo'shiladi. RPM oilasida xuddi shu g'oya: `openssl-3.<x>.<y>-<N>.el9_<M>`, bunda `el9` "Enterprise Linux 9", oxiridagi qism revizya.

**Tuzoq: versiya raqamiga qarab zaiflikni baholash.** Xavfsizlik skaneri "OpenSSH 9.6 zaif" deydi, lekin distributiv tuzatishni backport qilgan bo'lishi mumkin. Haqiqatni paketning changelog'i va distributivning security tracker'i ko'rsatadi, upstream versiya raqami emas.

### Server uchun tanlash

- Kompaniyada nima standart bo'lsa o'sha. Aralash park ekspluatatsiyani qimmatlashtiradi.
- Vendor sertifikati yoki pullik qo'llab-quvvatlash talab qilinsa: RHEL yoki Ubuntu Pro.
- Faqat qo'llab-quvvatlanadigan versiya, va uning EOL sanasi loyiha muddatidan uzoqroq.
- Konteyner base image alohida qaror: kichik hajm va kam zaiflik muhim (`debian:12-slim`, `alpine`, distroless). Docker modulida.

### Real ishda qachon kerak

- Yangi server uchun OS tanlashda EOL sanasi birinchi qaraladigan narsa: serverning kutilgan umri undan qisqa bo'lishi kerak.
- Xavfsizlik skaneri hisobotini o'qiyotganda: avval distributivning tracker'idan CVE holatini tekshirasiz, keyin xulosa qilasiz.
- Meros qolgan serverda `apt update` yoki `yum install` repo xatosi bilan sinsa, birinchi gumon: reliz EOL bo'lgan.

### Nima uchun shunday

Stable model "o'zgarish bu xavf" degan fikrga qurilgan: server uchun paketning yangi imkoniyatidan ko'ra uning xulqi o'zgarmasligi muhimroq, shuning uchun faqat tuzatish kiritiladi. Narxi: dasturlar eskiradi va backport qo'l mehnati talab qiladi, shuning uchun qo'llab-quvvatlash muddati cheklangan va uzaytirilgani pullik. Muqobili rolling model: hamma narsa yangi, lekin har yangilanish xulqni o'zgartirishi mumkin. Frontend'dagi o'xshashi haqiqiy: Node.js'ning LTS va Current liniyalari aynan shu murosaning ikki tomoni.

## 4. Distributivni aniqlash

### /etc/os-release

Standart usul: `/etc/os-release` fayli (1-darsda birinchi marta o'qilgan). Bu systemd loyihasi belgilagan standart, barcha zamonaviy distributivlarda bor va `KEY=value` formatida yozilgan. Faylni distributivning o'zi paket ichida olib keladi, shuning uchun u minimal konteyner image'ida ham mavjud.

| Maydon | Ma'nosi | Ubuntu 24.04 | Zorin OS 18 |
|--------|---------|--------------|-------------|
| `ID` | distributivning mashina o'qiydigan nomi | `ubuntu` | `zorin` |
| `ID_LIKE` | qaysi distributiv(lar)ga o'xshash, yaqinidan uzog'iga | `debian` | `ubuntu debian` |
| `VERSION_ID` | versiya raqami | `24.04` | `18` |
| `VERSION_CODENAME` | kod nomi, repo yo'llarida ishlatiladi | `noble` | `noble` |
| `PRETTY_NAME` | odam o'qiydigan nom | `Ubuntu 24.04.x LTS` | `Zorin OS 18.x` |

### Mexanizm: faylni shell o'zgaruvchilariga aylantirish

Fayl formati shell sintaksisiga mos, shuning uchun uni shell'ning `.` (source) buyrug'i bilan o'qish mumkin: `.` faylni alohida jarayonda emas, joriy shell'ning o'zida bajaradi, natijada har `KEY=value` qatori shell o'zgaruvchisiga aylanadi (shell o'zgaruvchilari 5-darsda).

```
ubuntu@lab:~$ . /etc/os-release && echo "$ID $VERSION_ID"
ubuntu 24.04
```

`&&` "chapdagi muvaffaqiyatli tugasa o'ngdagini bajar" degani (exit code `0`, 1-dars). Skriptda oilani aniqlash odatda `case` bilan yoziladi; g'oya (umumiy misol, vazifa yechimi emas):

```
. /etc/os-release
case " $ID $ID_LIKE " in
  *" debian "*) echo "Debian family" ;;
  *" rhel "*|*" fedora "*) echo "RPM family" ;;
  *) echo "unknown: $ID" ;;
esac
```

`ID` va `ID_LIKE` bitta satrga qo'shiladi va unda oila nomi qidiriladi. Shunda `ubuntu` (`ID_LIKE=debian`) ham, `zorin` (`ID_LIKE="ubuntu debian"`) ham birinchi shoxga tushadi.

### Boshqa manbalar

```
ubuntu@lab:~$ hostnamectl
 Static hostname: lab
       Icon name: computer-vm
         Chassis: vm
      Machine ID: <id>
         Boot ID: <id>
  Virtualization: <tur>
Operating System: Ubuntu 24.04.<N> LTS
          Kernel: Linux 6.8.0-<NN>-generic
    Architecture: x86-64
...
```

`hostnamectl` systemd asbobi: `Operating System` qatorini `/etc/os-release` dagi `PRETTY_NAME` dan, `Kernel` ni kernel'dan oladi, `Chassis: vm` va `Virtualization` mashina virtual ekanini va gipervizor turini aytadi (qiymat host'ga qarab farq qiladi), `Architecture` Mac'dagi VM'da `arm64`. U systemd bilan gaplashadi, shuning uchun systemd ishlamaydigan joyda (konteyner) foyda bermaydi.

- `lsb_release -a` har doim ham o'rnatilgan emas (minimal image'larda yo'q), unga tayanmang.
- Eski usullar: `/etc/debian_version`, `/etc/redhat-release`. Eski skriptlarda uchraydi. Ehtiyot bo'ling: Ubuntu'da `/etc/debian_version` Ubuntu versiyasini emas, asos qilingan Debian tarmog'ini ko'rsatadi (24.04 da `trixie/sid`).
- macOS'da bularning hech biri yo'q: `sw_vers` (`ProductName`, `ProductVersion`, `BuildVersion`).

### Real ishda qachon kerak

- Notanish serverga kirganda birinchi ikki buyruq: `cat /etc/os-release` va `uname -r` (1-dars).
- O'rnatish skriptlari (Docker, Node, Tailscale va boshqalar) aynan shu faylni o'qib `apt` yoki `dnf` shoxini tanlaydi. Skript "unsupported distribution" desa, u sizning `ID` ni tanimagan.
- Ansible va Terraform'da serverlarni oila bo'yicha tarmoqlash ham shu maydonlarga tayanadi.

### Nima uchun shunday

2012-yilgacha har distributiv o'z faylini ishlatardi (`/etc/redhat-release`, `/etc/debian_version`, `/etc/SuSE-release`), formati ham har xil edi, skriptlar o'nlab holatni tekshirishga majbur edi. `lsb_release` buyrug'i yagona interfeys bo'lishi kerak edi, lekin u alohida paket va ko'p joyda o'rnatilmagan. systemd loyihasi bitta oddiy fayl formatini taklif qildi va hamma distributiv uni qabul qildi. `ID_LIKE` hosila distributivlar muammosini yechadi: yuzlab hosilalarning har birini skriptga yozish o'rniga hosila o'zi "men kimga o'xshayman" deb e'lon qiladi.

## 5. Laboratoriya: VM va konteyner

### Farq

1-darsdan: VM o'z kernel'ini yuklaydi, konteyner host kernel'ida ishlaydigan izolyatsiyalangan jarayonlar guruhi.

| | VM (Multipass) | Konteyner (Docker) |
|---|----------------|--------------------|
| Kernel | o'ziniki | host bilan umumiy (Mac'da Docker'ning yashirin VM'i bilan) |
| PID 1 | `systemd` | siz ishga tushirgan dastur |
| Boot, servislar, `systemctl` | bor | yo'q |
| Disk qurilmalari, mount, LVM, swap | to'liq, o'z virtual diski | cheklangan, host qurilmalari ko'rinadi |
| Ishga tushish | o'nlab soniya | bir soniyadan kam |
| Qachon | users, systemd, firewall, disk, kernel parametrlari | paket menejeri, fayl buyruqlari, distributivlarni tez solishtirish |

Qoida: vazifa servis, foydalanuvchi, disk yoki tarmoq sozlamasiga tegsa VM, aks holda konteyner yetadi.

### Mexanizm: Multipass ichida nima bor

Multipass uch qismdan iborat. `multipass` buyrug'i faqat mijoz: u fonda doim ishlab turadigan `multipassd` servisiga (daemon) so'rov yuboradi. Daemon VM'larni **gipervizor** orqali ishga tushiradi; gipervizor bu VM'larga CPU va xotirani bo'lib beradigan dastur qatlami. Ikkala host'da ham bu QEMU, lekin tezlikni CPU'ning apparat virtualizatsiyasi beradi: Zorin'da kernel moduli KVM (Intel `vmx` yoki AMD `svm` CPU flag'i kerak), macOS'da Hypervisor.framework. Shu sababli VM host bilan bir xil arxitekturada bo'ladi: Zorin'da `amd64`, Mac'da `arm64`.

`multipass launch 24.04 --name lab ...` bajarilganda: (1) daemon Canonical serveridan Ubuntu 24.04 **cloud image**'ini yuklaydi (o'rnatuvchisiz, tayyor disk nusxasi; AWS va boshqa cloud'lar ham shunday image'dan boshlaydi) va keshlaydi; (2) undan `--disk` hajmidagi virtual disk yaratadi; (3) VM'ni `--cpus` va `--memory` bilan yoqadi; (4) birinchi yuklanishda VM ichidagi **cloud-init** servisi hostname'ni o'rnatadi, `ubuntu` foydalanuvchisini yaratadi va Multipass'ning SSH kalitini qo'yadi. `multipass shell` va `multipass exec` aslida shu kalit bilan SSH orqali ulanadi.

```
$ multipass find
Image                       Aliases           Version          Description
24.04                       <alias'lar>       <sana>           Ubuntu 24.04 LTS
...
$ multipass list
Name                    State             IPv4             Image
lab                     Running           <IP>             Ubuntu 24.04 LTS
$ multipass info lab
Name:           lab
State:          Running
Snapshots:      <N>
IPv4:           <IP>
Release:        Ubuntu 24.04.<N> LTS
Image hash:     <hash> (Ubuntu 24.04 LTS)
CPU(s):         2
Load:           <1m> <5m> <15m>
Disk usage:     <N>GiB out of 9.6GiB
Memory usage:   <N>MiB out of 1.9GiB
Mounts:         --
```

`find` yuklash mumkin bo'lgan image'lar: `Image` asosiy nom, `Aliases` shu image'ning boshqa nomlari, `Version` image yig'ilgan sana. `list` da `State` (`Running`, `Stopped`, `Deleted`), `IPv4` VM'ning host ichidagi virtual tarmoqdagi manzili (tashqaridan ko'rinmaydi). `info` da `Snapshots` snapshot'lar soni, `Release` VM ichidagi `PRETTY_NAME`, `CPU(s)` `--cpus` dan, `Load` yuklama o'rtachasi (8-darsda), `Disk usage` va `Memory usage` dagi "out of" qiymatlari `--disk 10G` va `--memory 2G` dan biroz kam, chunki bir qismi bo'lim jadvali, boot bo'limi va kernel'ning o'ziga ketadi. VM to'xtatilgan bo'lsa `IPv4`, `Load`, `Disk usage`, `Memory usage` o'rnida `--` turadi.

**Tuzoq: image nomisiz `multipass launch`.** Nom berilmasa Multipass o'sha paytdagi standart LTS'ni oladi va u vaqt o'tishi bilan o'zgaradi. Kurs 24.04 ga yozilgan, har doim `24.04` ni aniq yozing.

### Kundalik buyruqlar

```
multipass shell lab                     # interactive shell as user "ubuntu"
multipass exec lab -- uname -r          # run one command without entering
```

`--` dan keyingi hamma narsa VM ichida bajariladigan buyruq va uning argumentlari; `--` siz `-r` kabi flag'ni `multipass` o'ziniki deb o'ylaydi.

| Buyruq | Nima qiladi |
|--------|-------------|
| `multipass stop lab`, `multipass start lab` | to'xtatish, ishga tushirish (disk saqlanadi, xotiradagi holat yo'qoladi) |
| `multipass transfer file.txt lab:/home/ubuntu/` | fayl ko'chirish; teskarisi `multipass transfer lab:/home/ubuntu/file.txt .` |
| `multipass snapshot lab --name clean` | snapshot (VM to'xtatilgan bo'lishi kerak) |
| `multipass list --snapshots` | barcha snapshot'lar ro'yxati |
| `multipass restore lab.clean` | snapshot'ga qaytarish (VM to'xtatilgan bo'lishi kerak) |
| `multipass delete lab` | o'chirilgan deb belgilaydi, `multipass recover lab` bilan qaytariladi |
| `multipass purge` | o'chirilgan VM'larni butunlay yo'q qiladi |

**Snapshot** bu VM diskining ma'lum paytdagi holati. Multipass uni faqat to'xtatilgan VM'dan oladi, shuning uchun snapshot'da ishlab turgan jarayonlar va xotira yo'q, faqat disk. `restore` diskni o'sha holatga qaytaradi; hozirgi holat yo'qolishidan oldin Multipass "avval joriy holatdan ham snapshot olaymi" deb so'raydi (`--destructive` flag'i so'ramasdan tashlab yuboradi). Xavfli vazifadan oldin snapshot oling: tizimni buzsangiz qayta o'rnatish o'rniga bir buyruq bilan qaytasiz. `delete` ikki bosqichli: avval VM "savatga" tushadi (`list` da ko'rinadi, disk joyi band), `purge` savatni bo'shatadi va shundan keyin qaytarib bo'lmaydi.

Zorin'da eslatma: snap sifatida o'rnatilgan Multipass host fayllarini faqat home papkangiz ichidan o'qiy oladi (snap izolyatsiyasi), `transfer` uchun fayl shu yerda bo'lsin.

### RPM distributiv Docker'da

```
docker run --rm -it rockylinux:9 bash           # throwaway: removed on exit
docker run -it --name rocky rockylinux:9 bash   # kept after exit
docker start -ai rocky                          # re-enter the kept container
docker rm rocky                                 # remove it
docker ps -a                                    # all containers, including exited ones
```

`--rm` konteynerni chiqishda o'chiradi, `-it` interaktiv terminal beradi (1-dars), `--name` konteynerga nom beradi va u `exit` dan keyin `Exited` holatida qoladi; `docker start -ai` o'sha konteynerni, ichidagi o'zgarishlari bilan, qayta ishga tushirib terminalga ulaydi. Boshqa image'lar: `almalinux:9`, `fedora:latest`, `oraclelinux:9`, `quay.io/centos/centos:stream9`. Hammasi `amd64` va `arm64` uchun chiqadi, Docker host arxitekturasiga mosini o'zi tanlaydi. Bu image'lar minimal: `man`, `less`, ba'zan `ps` va `which` ham yo'q, kerak bo'lsa `dnf install -y <paket>` bilan o'rnatiladi. Konteyner ichida siz `root` siz, shuning uchun `sudo` kerak emas (va o'rnatilmagan ham).

**Tuzoq: `--rm` konteyneridagi ish yo'qoladi.** Bir necha vazifa davomida holat kerak bo'lsa nomlangan konteyner (`--name`) ishlating va oxirida `docker rm` bilan o'chiring.

### Real ishda qachon kerak

- Ansible playbook yoki o'rnatish skriptini haqiqiy serverga qo'yishdan oldin toza VM'da sinash: snapshot, sinov, `restore`, yana sinov.
- "Bu buyruq Rocky'da ham ishlaydimi" degan savolga 5 soniyada javob: bir martalik konteyner.
- Cloud'dagi server ham aslida VM va xuddi shunday cloud image va cloud-init bilan yaratiladi (Cloud va IaC modullarida), `lab` uning lokal nusxasi.

### Nima uchun shunday

VM to'liq izolyatsiya beradi, lekin har biri o'z kernel'i va xotirasini talab qiladi. Konteyner yengil, lekin kernel umumiy bo'lgani uchun systemd, disk va kernel sozlamalarini o'rganishga yaramaydi. Kurs shuning uchun ikkalasini ishlatadi. Multipass tanlanganining sababi: VirtualBox yoki o'rnatuvchi ISO bilan VM yaratish o'nlab qo'l qadami, Multipass esa bitta buyruq va ikkala host'da bir xil natija; muqobili Vagrant, lekin u Apple Silicon'da qo'shimcha sozlash talab qiladi. Snapshot'ning faqat to'xtatilgan VM'dan olinishi soddalik uchun: xotira holatini saqlash kerak bo'lmaydi va disk izchil holatda bo'ladi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Upstream | dasturning asl mualliflari va ular chiqargan kod; oqimda sizdan "yuqorida" turgan loyiha |
| Maintainer | distributivda paketni yig'adigan va yangilaydigan odam yoki jamoa |
| Paket | binary'lar, konfiguratsiya, metadata va skriptlardan iborat o'rnatiladigan arxiv (`.deb`, `.rpm`) |
| Repozitoriy | distributivning imzolangan paketlar ombori |
| Oila | umumiy ajdod va paket formatiga ega distributivlar guruhi |
| Hosila distributiv | boshqa distributiv repo'lari ustiga qurilgan distributiv (Zorin Ubuntu'dan) |
| `dpkg` / `rpm` | bitta paket faylini o'rnatadigan past darajali vositalar |
| `apt` / `dnf` | repo'dan paket va bog'liqliklarini topib o'rnatadigan menejerlar |
| glibc / musl | C standart kutubxonasining ikki xil amalga oshirilishi (ko'p distributivlar / Alpine) |
| ABI | yig'ilgan dastur va kutubxonalar orasidagi binary darajadagi kelishuv |
| MAC | fayl ruxsatlari ustidagi siyosatga asoslangan nazorat (AppArmor, SELinux) |
| Reliz modeli | paketlar qachon va qanday yangilanishi qoidasi (point, stream, tez, rolling) |
| LTS | uzoq muddat xavfsizlik yangilanishi oladigan reliz |
| EOL | qo'llab-quvvatlash tugagan sana, undan keyin tuzatish chiqmaydi |
| CVE | ommaga e'lon qilingan zaiflikning yagona raqami |
| Backport | tuzatishni yangi versiyadan muzlatilgan eski versiyaga ko'chirish |
| Distributiv revizyasi | paket versiyasining upstream qismidan keyingi, distributiv o'stiradigan qismi |
| `os-release` | distributiv o'zini tanishtiradigan `KEY=value` fayli |
| Gipervizor | VM'larga CPU va xotirani bo'lib beradigan qatlam (QEMU + KVM yoki Hypervisor.framework) |
| Cloud image | o'rnatuvchisiz, tayyor yuklanadigan disk nusxasi |
| cloud-init | birinchi yuklanishda VM'ni sozlaydigan servis (hostname, foydalanuvchi, SSH kalit) |
| Daemon | fonda doimiy ishlaydigan servis jarayoni (`multipassd`) |
| Snapshot | VM diskining ma'lum paytdagi saqlangan holati |

## Tuzoqlar

- EOL distributivda qolish. Tizim ishlayveradi, lekin paket o'rnatish sinadi (repozitoriylar arxivga ko'chgan) va zaifliklar yopilmaydi. EOL sanasini oldindan bilish va migratsiyani rejalashtirish ops ishining bir qismi.
- CentOS Linux va CentOS Stream'ni aralashtirish. Birinchisi o'lgan, ikkinchisi RHEL'dan oldingi oqim.
- Oraliq (LTS bo'lmagan) Ubuntu relizini serverga qo'yish: 9 oydan keyin majburiy upgrade.
- Skriptda distributivni faqat `ID` bo'yicha yoki `lsb_release` orqali aniqlash. `ID_LIKE` ni ham tekshiring.
- Bir oila uchun yozilgan ko'rsatmani ikkinchisida ko'r-ko'rona bajarish: paket nomi, konfiguratsiya yo'li, admin guruhi (`sudo` va `wheel`) farq qiladi.
- Upstream versiya raqamiga qarab "zaif" yoki "eski" deb xulosa qilish. Stable distributivlar tuzatishni backport qiladi.
- Konteynerda ishlagan narsa VM yoki serverda ham ishlaydi deb o'ylash. Konteynerda systemd, SELinux siyosati va alohida kernel yo'q.
- Host'da tajriba qilish. Tizimni o'zgartiradigan har qanday buyruq `lab` VM yoki konteynerda; bu Zorin'ga ham, macOS'ga ham tegishli.
- Mac'da konteyner ichidagi kernel, disk va `/proc/cmdline` ni "Mac'niki" deb o'qish. Ular Docker'ning yashirin Linux VM'iga tegishli.
- Snapshot'ni zaxira nusxa deb o'ylash. U VM bilan bir diskda va bir mashinada yotadi: `multipass delete lab && multipass purge` snapshot'larni ham yo'q qiladi, ikkinchi mashinaga ham ko'chmaydi.
- `multipass launch` da image nomini tushirib qoldirish yoki `fedora:latest` kabi `latest` tegiga tayanish: bugun va yarim yildan keyin boshqa versiya keladi. Takrorlanishi kerak bo'lgan joyda versiyani aniq yozing.
- Boshqa arxitektura uchun yig'ilgan image yoki binary: Mac'da `amd64`, Zorin'da `arm64` narsa emulyatsiya bilan sekin ishlaydi yoki `Exec format error` beradi (1-dars).

## Manbalar

- https://documentation.ubuntu.com/multipass/ – Multipass rasmiy hujjati (o'rnatish, buyruqlar, snapshot)
- https://www.freedesktop.org/software/systemd/man/latest/os-release.html – `os-release` maydonlari
- https://www.freedesktop.org/software/systemd/man/latest/hostnamectl.html – `hostnamectl(1)`
- https://ubuntu.com/about/release-cycle – Ubuntu reliz sikli va LTS muddatlari
- https://ubuntu.com/security/cves – Ubuntu CVE tracker (backport holati)
- https://www.debian.org/releases/ – Debian relizlari, stable, testing, unstable
- https://wiki.debian.org/LTS – Debian LTS
- https://security-tracker.debian.org/tracker/ – Debian security tracker
- https://www.debian.org/doc/debian-policy/ch-controlfields.html#version – `.deb` versiya satri formati (epoch, upstream, revizya)
- https://access.redhat.com/support/policy/updates/errata – RHEL life cycle
- https://www.centos.org/centos-stream/ – CentOS Stream nima
- https://docs.fedoraproject.org/en-US/releases/lifecycle/ – Fedora reliz sikli
- https://wiki.rockylinux.org/rocky/version/ – Rocky Linux versiyalari va muddatlari
- https://wiki.almalinux.org/release-notes/ – AlmaLinux relizlari
- https://endoflife.date – ko'p mahsulotlar uchun EOL sanalari (norasmiy, lekin qulay; rasmiy sahifa bilan tekshiring)
- https://hub.docker.com/_/rockylinux – Rocky Linux rasmiy Docker image
- https://hub.docker.com/_/centos – `centos` image sahifasi (deprecated eslatmasi bilan)
- https://cloud-init.io – cloud-init loyihasi

## Birga bajaramiz

Vaziyat: hamkasbingiz "serverimiz AlmaLinux 9, jarayonlarni `ps` bilan qarab ber" dedi. AlmaLinux'ni birinchi marta ko'ryapsiz. Uni konteynerda ochib, kimligini aniqlaymiz, yetishmagan asbobni o'rnatamiz va konteyner qayerda serverning o'rnini bosa olmasligini `lab` VM bilan solishtirib ko'ramiz. Bu image vazifalarda ishlatilmaydi.

1. Host'da qaysi mashinada ekaningizni aniqlang va nomlangan konteyner oching:

```
$ uname -sm
Linux x86_64
$ docker run -it --name alma almalinux:9 bash
[root@<id> /]#
```

`uname -sm` kernel nomi va arxitektura: Zorin'da `Linux x86_64`, Mac'da `Darwin arm64`. Docker shunga mos image variantini yukladi. Prompt o'zgardi: `root` foydalanuvchi, `<id>` konteyner hostname'i (konteyner ID'sining boshi).

2. Bu qaysi distributiv va qaysi oila:

```
[root@<id> /]# cat /etc/os-release
NAME="AlmaLinux"
VERSION="9.<N> (<kod nomi>)"
ID="almalinux"
ID_LIKE="rhel centos fedora"
VERSION_ID="9.<N>"
PLATFORM_ID="platform:el9"
PRETTY_NAME="AlmaLinux 9.<N> (<kod nomi>)"
...
```

`ID` ni hech bir skript tanimasligi mumkin, lekin `ID_LIKE` uchta ajdodni yaqinidan uzog'iga sanaydi: RHEL, CentOS, Fedora. Demak RPM oilasi, paket menejeri `dnf`. `VERSION_ID` da minor versiya ham bor (`9.<N>`), bu RHEL minor relizlariga mos. `PLATFORM_ID` dagi `el9` paket nomlarida ham uchraydi.

3. Bu to'liq tizimmi yoki faqat user space:

```
[root@<id> /]# cat /proc/1/comm
bash
[root@<id> /]# ps aux
bash: ps: command not found
```

PID 1 `systemd` emas, siz ishga tushirgan `bash`: bu konteyner, boot va servislar yo'q (1-dars). `ps` esa umuman yo'q: image minimal. Exit code `127` (`echo $?`), ya'ni "buyruq topilmadi".

4. Yetishmagan asbobni o'rnating. RHEL oilasida `ps` `procps-ng` paketida keladi:

```
[root@<id> /]# dnf install -y procps-ng
...
Installed:
  procps-ng-<versiya>.el9.<arch>
Complete!
[root@<id> /]# rpm -qf /usr/bin/ps
procps-ng-<versiya>.el9.<arch>
[root@<id> /]# ps -p 1 -o pid,comm
    PID COMMAND
      1 bash
```

`dnf` avval repo indekslarini yukladi, keyin bog'liqliklar bilan o'rnatiladigan paketlar jadvalini ko'rsatdi (`-y` tasdiqni avtomatik berdi), oxirida `Complete!`. `rpm -qf` fayl qaysi paketga tegishli ekanini aytadi: nom, versiya, `el9` va arxitektura. Buyruq nomi (`ps`) va paket nomi (`procps-ng`) bir xil emas, Ubuntu'da esa o'sha paket `procps` deb ataladi: oilalar orasidagi nom farqining misoli.

5. Chiqing va konteyner holatini ko'ring:

```
[root@<id> /]# exit
$ docker ps -a
CONTAINER ID   IMAGE         COMMAND   CREATED    STATUS                  PORTS     NAMES
<id>           almalinux:9   "bash"    <vaqt>     Exited (0) <vaqt> ago             alma
$ docker start -ai alma
[root@<id> /]# command -v ps
/usr/bin/ps
[root@<id> /]# exit
```

`--rm` bermaganimiz uchun konteyner o'chmadi: `STATUS` da `Exited (0)`, qavsdagi son `bash` ning exit code'i. `docker start -ai` o'sha konteynerni qaytardi va o'rnatilgan `ps` joyida. `--rm` bilan ochilganida 4-qadamdagi ish yo'qolgan bo'lardi.

6. Xuddi shu savollarni haqiqiy serverga o'xshash joyda, `lab` VM'da bering (kirmasdan):

```
$ multipass exec lab -- cat /proc/1/comm
systemd
$ multipass exec lab -- systemctl is-active ssh
active
```

VM'da PID 1 `systemd` va u servislarni boshqaradi (`ssh` servisi ishlayapti). Hamkasbingizning serveri ham shunday: konteynerda paket menejeri va fayl joylashuvini o'rgandingiz, lekin servislar bilan ishlashni faqat VM yoki haqiqiy serverda sinash mumkin. RPM oilasidagi to'liq VM Multipass'da yo'q (u faqat Ubuntu beradi), shuning uchun kursda RPM oilasi konteynerda, systemd esa `lab` da o'rganiladi.

7. Tozalang:

```
$ docker rm alma
alma
$ docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Shu 7 qadamda ko'rganingiz: distributivni `os-release` va `ID_LIKE` orqali aniqlash (4-bo'lim), oilaga xos paket menejeri va paket nomlari (2-bo'lim), minimal image va distributiv tanlagan versiyalar (1-bo'lim), bir martalik va nomlangan konteyner hamda VM va konteyner chegarasi (5-bo'lim).

---

## Vazifalar

Ish papkasi: `linux/02-distros/` (`make new m=linux n=02 name=distros` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Har vazifada qayerda bajarganingizni (host: Zorin yoki macOS, `lab` VM, qaysi konteyner) ko'rsating. `docker` va `multipass` buyruqlari host'da, `sudo` faqat `lab` VM ichida va faqat vazifa so'ragan joyda. "Zorin'da" yoki "macOS'da" deb belgilangan qismlar ixtiyoriy, o'sha mashinada bo'lsangiz qo'shing.

### A. Distributivni aniqlash

1. **os-release fields.** `lab` VM'da `/etc/os-release` ni o'qing va 4-bo'limdagi beshta maydon qiymatini yozing. `hostnamectl` chiqishi bilan solishtiring: u qo'shimcha nima ko'rsatadi? `lsb_release -a` ishlaydimi? Ixtiyoriy: Zorin host'ida xuddi shu beshta maydonni yozing va VM bilan solishtiring; macOS'da `sw_vers` nima qaytaradi? Yo'nalish: 4-bo'lim, "/etc/os-release" va "Boshqa manbalar".

2. **Four images.** `ubuntu:24.04`, `debian:12`, `rockylinux:9`, `fedora:latest` image'larining har birida `cat /etc/os-release` ni bajaring (`docker run --rm <image> cat /etc/os-release`). Jadval tuzing: `ID`, `ID_LIKE`, `VERSION_ID`. `ID_LIKE` bo'yicha oilani qanday aniqlaysiz? Fedora va Debian'da `ID_LIKE` bormi, nima uchun? Yo'nalish: 4-bo'lim, "Nima uchun shunday", va 2-bo'limdagi oqim.

3. **Detection one-liner.** `/etc/os-release` ni source qilib `ID` va `VERSION_ID` ni chiqaradigan bir qatorli buyruqni yozing va to'rttala image'da ishlating (`docker run --rm <image> sh -c '...'`). Nima uchun buyruqni bitta tirnoq ichida berish kerak (tirnoqni qo'shtirnoqqa almashtirib natijani solishtiring)? Xuddi shu konteynerlarda `lsb_release -a` ni bajarib ko'ring va xatoni yozing. Yo'nalish: 4-bo'lim, "Mexanizm: faylni shell o'zgaruvchilariga aylantirish".

4. **Tool presence.** Har to'rttala image'da `command -v apt dpkg dnf yum rpm` ni bajaring va qaysi vosita qayerda borligini jadvalga yozing. Rocky'da `ls -l /usr/bin/yum` nimani ko'rsatadi? Yo'nalish: 2-bo'lim, "Oila nima".

### B. Multipass

5. **Install Multipass.** Host'da virtualizatsiya mavjudligini tekshiring (Zorin: `grep -Ec '(vmx|svm)' /proc/cpuinfo`, noldan katta bo'lishi kerak; macOS: `sysctl kern.hv_support`). Multipass `SETUP.md` bo'yicha o'rnatilgan bo'lsa qayta o'rnatmang, qanday o'rnatilganini ko'rsating (Zorin: `snap list multipass`, macOS: `brew list --cask`); bu mashinada hali yo'q bo'lsa "Laboratoriya" bo'limidagi buyruq bilan o'rnating. `multipass version` (ikki qator nimani bildiradi?), `multipass get local.driver` va `multipass find` natijasini yozing. `multipass find` dagi `24.04` image'ining alias'lari qanday? Yo'nalish: 5-bo'lim, "Mexanizm: Multipass ichida nima bor".

6. **Launch the lab VM.** `lab` nomli VM 2 CPU, 2G xotira, 10G disk bilan bo'lishi kerak. U `SETUP.md` da yaratilgan bo'lsa qayta yaratmang: qaysi buyruq bilan yaratilganini yozing va parametrlar mosligini VM ichida `nproc`, `free -h`, `df -h /` bilan tasdiqlang; bu mashinada yo'q bo'lsa yarating. `multipass list` va `multipass info lab` dan IP manzil, reliz, disk va xotira ishlatilishini yozing. `multipass shell lab` bilan kirib `whoami`, `id`, `sudo -l` ni bajaring: `ubuntu` foydalanuvchisi qaysi guruhlarda va `sudo` huquqi qanday berilgan? Yo'nalish: 5-bo'lim, `multipass info` misoli, va 2-bo'lim, "Admin guruhi".

7. **VM versus container.** `lab` VM'da va `ubuntu:24.04` konteynerida quyidagilarni bajarib jadvalga yozing: `uname -r`, `ps -p 1 -o comm=`, `systemctl is-system-running`, `lsblk`, `cat /proc/cmdline`. Har farqni izohlang. Qaysi biri host'ning kernel'ini ko'rsatdi? Mac'da bo'lsangiz: konteyner ko'rsatgan kernel va disklar kimniki? Yo'nalish: 5-bo'lim, "Farq", va "Laboratoriya" dagi mashinalar jadvali.

8. **Exec and transfer.** VM'ga kirmasdan `multipass exec` orqali `/etc/os-release` ni o'qing. Host'dagi ish papkasida `hello.txt` yarating, uni VM'ga ko'chiring, VM ichida o'zgartiring va `from-vm.txt` nomi bilan qaytarib oling. `multipass exec lab -- ls -l | wc -l` da `wc` qayerda bajariladi: VM'da yoki host'da? Buni qanday isbotlaysiz? Yo'nalish: 5-bo'lim, "Kundalik buyruqlar"; qatorni birinchi bo'lib qaysi shell o'qishini o'ylang.

9. **Snapshot and restore.** Avval `multipass list --snapshots` bilan mavjud snapshot'larni ko'ring. VM'ni to'xtatib `clean` nomli snapshot oling (`SETUP.md` dan `clean` allaqachon bo'lsa, yangisiga `lesson2` nomini bering va keyingi qadamlarda shuni ishlating). VM'ni ishga tushiring, ichida `sudo touch /etc/lab-marker` va `sudo apt remove -y nano` ni bajaring. Snapshot'ga qayting va marker fayl ham, `nano` ham avvalgi holatda ekanini tekshiring. `restore` sizdan nima so'radi va nima deb javob berdingiz? Ishlab turgan VM'dan snapshot olishga urinib ko'ring va xatoni yozing. Yo'nalish: 5-bo'lim, "Kundalik buyruqlar", snapshot haqidagi xatboshi.

10. **Delete and recover.** `multipass launch 24.04 --name tmp` bilan ikkinchi VM yarating. `multipass delete tmp` dan keyin `multipass list` nimani ko'rsatadi? Uni `recover` bilan qaytaring, yana `delete` qiling va `multipass purge` bilan butunlay o'chiring. `delete` va `purge` farqini izohlang. `lab` VM joyida qolganini tekshiring. Yo'nalish: 5-bo'lim, "Kundalik buyruqlar".

### C. Oilalar farqi

11. **First package install.** `ubuntu:24.04` konteynerida `apt update && apt install -y nano`, `rockylinux:9` konteynerida `dnf install -y nano` ni bajaring. Ubuntu'da `apt update` siz o'rnatishga urinib ko'ring (yangi konteynerda) va xatoni yozing: nima uchun Debian oilasida avval `update` kerak? Har ikki menejer o'rnatishdan oldin nimalarni ko'rsatadi? Yo'nalish: 1-bo'lim, "Mexanizm: distributiv qanday yig'iladi", va "Birga bajaramiz" 4-qadam.

12. **Package naming.** Apache web serveri haqida ma'lumotni o'rnatmasdan oling: Ubuntu'da `apt show apache2`, Rocky'da `dnf info httpd`. Versiya, hajm va tavsifni solishtiring. Ubuntu'da `apt show httpd`, Rocky'da `dnf info apache2` nima deydi? Yo'nalish: 2-bo'lim, "Oila nima" jadvali.

13. **Package ownership.** `bash` binary'si qaysi paketga tegishli: Ubuntu'da `dpkg -S /usr/bin/bash`, Rocky'da `rpm -qf /usr/bin/bash`. O'rnatilgan paketlar soni: `dpkg -l | grep -c '^ii'` va `rpm -qa | wc -l`. Minimal image'lar nechta paketdan iborat, `lab` VM'da-chi? Yo'nalish: 2-bo'lim, "Past va yuqori darajali vosita".

14. **Family layout.** Ubuntu va Rocky konteynerlarida quyidagilarni solishtirib jadval tuzing: `getent group sudo wheel`, `ls /etc/default /etc/sysconfig`, `ls /etc/apt /etc/yum.repos.d`. Qaysi papka va guruh qaysi oilaga xos? Bitta `.repo` faylni va Ubuntu'dagi `/etc/apt/sources.list.d/` ichidagi faylni o'qib, umumiy maydonlarni (URL, komponent, kalit) toping. Yo'nalish: 2-bo'lim, "Oila nima" jadvali va "Misol: oilani fayllardan tanish".

15. **Backported fixes.** `lab` VM'da `apt list --installed 2>/dev/null | grep openssh-server` bilan paket versiyasini oling va versiya satrining qismlarini (upstream versiya, distributiv revizyasi) ajrating. `apt changelog openssh-server | head -40` da CVE raqami bilan yozuv toping. Upstream versiya shu tuzatishdan keyin o'zgarganmi? Bundan xavfsizlik skaneri natijalarini o'qish uchun qanday xulosa chiqadi? Yo'nalish: 3-bo'lim, "Mexanizm: backport".

### D. Reliz va EOL

16. **EOL in practice.** `docker run --rm -it centos:7 bash` ichida `cat /etc/os-release` va `yum install -y nano` ni bajaring. Image ikkala arxitektura uchun ham mavjud va yuklanadi (Docker Hub'da u deprecated deb belgilangan); kutilgan natija: o'rnatish sinadi. Xatoni to'liq o'qing va nima sodir bo'lganini izohlang (xato paket haqidami yoki repo haqidami?). Agar production'da shunday server sizga meros qolsa, birinchi uchta qadamingiz nima bo'ladi (tuzatib bermang, rejani yozing)? Yo'nalish: 3-bo'lim, "To'rt model" dagi EOL ta'rifi, va 2-bo'limdagi CentOS tarixi.

17. **Support table.** Rasmiy sahifalardan (Manbalar bo'limi) foydalanib jadval to'ldiring: Ubuntu 22.04, Ubuntu 24.04, Debian 12, Debian 13, Rocky Linux 9, CentOS Stream 9, eng so'nggi Fedora. Ustunlar: chiqqan sana, standart qo'llab-quvvatlash tugash sanasi, manba URL. Bugungi sanaga ko'ra qaysi birini yangi serverga qo'ygan bo'lardingiz va qaysi birini yo'q? Yo'nalish: 3-bo'lim, "Server uchun tanlash".

18. **Kernel per distro.** `lab` VM'da `uname -r` ni, Rocky konteynerida `dnf info kernel` dagi versiyani, host'da `uname -r` ni yozing (Zorin'da bu Linux kernel'i; macOS'da Darwin kernel'i chiqadi, uni Linux versiyalari bilan solishtirmang, o'rniga `docker run --rm ubuntu:24.04 uname -r` ni uchinchi qiymat qilib oling). Bir vaqtda qo'llab-quvvatlanayotgan uchta tizimda kernel versiyalari nima uchun bunchalik farq qiladi? Eski kernel raqami "xavfsiz emas" deganimi (15-vazifa xulosasini qo'llang)? Yo'nalish: 3-bo'lim, "Mexanizm: backport", va 1-bo'lim.

### E. Yakuniy

19. **Distro decision.** Uch holat uchun distributiv va versiyani tanlang, har biriga 3–4 gap asos yozing (reliz modeli, EOL sanasi, oila, qo'llab-quvvatlash): (a) bank ichki tizimi, vendor sertifikati va pullik support talab qilinadi; (b) startap, AWS'da 10 ta web server, jamoada Debian oilasi tajribasi bor; (c) Node.js servisi uchun Docker base image. Har holatda rad etilgan bitta muqobilni va sababini ham yozing. Yo'nalish: 3-bo'lim, "Server uchun tanlash", va 2-bo'lim.

20. **Lab cheat sheet.** README oxirida o'zingiz uchun laboratoriya eslatmasini yozing: `lab` VM'ni ishga tushirish, kirish, snapshot olish va qaytarish, to'xtatish; Ubuntu va Rocky konteynerini bir martalik va nomlangan holda ishga tushirish; tozalash buyruqlari; ikkinchi mashinada `lab` ni qanday tiklash. Har buyruqni yozishdan oldin bajarib tekshiring. Oxirida `multipass stop lab` qiling va `multipass list`, `docker ps -a` natijasini qo'shing. Yo'nalish: 5-bo'lim va "Laboratoriya".

### Topshirish

Tayyor bo'lgach:
1. `linux/02-distros/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida; 8-vazifadagi `hello.txt` va `from-vm.txt` ish papkasida.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; host (qaysi mashina), VM yoki konteynerda bajarilgani aniq ko'rinadi.
3. `make check` toza o'tadi (host'da).
4. `docker ps -a` da shu darsdan qolgan konteyner yo'q, `multipass list` da faqat `lab` (Stopped) bor, `tmp` purge qilingan.
5. `lab` VM'da `clean` snapshot mavjud (`multipass list --snapshots`); 9-vazifada `lesson2` olgan bo'lsangiz u ham qolsin.
6. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Distributivlar bir-biridan nimalari bilan farq qiladi, nimalari bir xil? Upstream va maintainer kim?
- Fedora, CentOS Stream, RHEL va Rocky Linux o'zaro qanday bog'langan?
- CentOS Linux va CentOS Stream farqi nima?
- LTS va EOL nima? EOL tizimda aynan nima ishlamay qoladi?
- Backport nima va nima uchun paketning upstream versiya raqami zaiflik haqida to'liq ma'lumot bermaydi?
- Skriptda distributiv oilasini qanday ishonchli aniqlaysiz? `ID_LIKE` qaysi muammoni yechadi?
- `sudo` guruhi va `wheel` guruhi qayerda uchraydi?
- Qaysi vazifalar uchun konteyner yetarli, qaysilari uchun VM shart? Nima uchun?
- `multipass launch` bajarilganda qanday bosqichlar o'tadi? Zorin va Mac'da VM arxitekturasi nima uchun farq qiladi?
- Multipass'da `delete` va `purge` farqi nima, snapshot qachon olinadi va u nimani saqlamaydi?
- Mac'da konteyner ichidagi `uname -r` va `lsblk` nimani ko'rsatadi va nima uchun?
