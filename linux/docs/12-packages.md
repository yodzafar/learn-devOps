# 12-dars: Paketlarni boshqarish

Maqsad: serverga dastur qanday o'rnatilishi, qayerdan kelishi va unga nima uchun ishonish mumkinligini noldan tushunish. Paket nima va uning ichida nima borligini, `apt` va `dpkg` (RHEL oilasida `dnf` va `rpm`) orasidagi vazifa taqsimotini, repository va GPG imzo zanjirini, uchinchi tomon repo'sini `signed-by` bilan xavfsiz qo'shishni, versiyani ushlab turishni (`hold`, pinning) va avtomatik xavfsizlik yangilanishlarini o'rganasiz. `npm` dan ba'zi tushunchalar tanish (registry, versiya, dependency), lekin tizim paketlarida farqlar muhim: paketlar root sifatida o'rnatiladi va o'rnatish paytida root nomidan skript bajaradi, manba imzo bilan tekshiriladi, bitta paketning bitta versiyasi butun tizimga o'rnatiladi. Bu bilim Dockerfile yozishda (har ikkinchi qator `apt-get install`), Ansible'da (`apt` va `dnf` modullari) va server yangilanishlarini rejalashtirishda kerak bo'ladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh vazifalari (1–7), ikkinchi kun 3–5 bo'limlar va B guruhi (8–13), uchinchi kun 6–8 bo'limlar, "Birga bajaramiz", C va D guruhlari (14–20). Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: `apt update` aslida nimani yuklaydi, `apt-cache policy` chiqishidagi raqamlar nima, imzo zanjirida qaysi fayl qaysi faylni tasdiqlaydi, `remove` va `purge` farqi, Debian va RHEL oilalari qayerda bir-biridan ajraladi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida (6-bo'limda Rocky konteynerida) o'zingiz terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Paket versiyalari, hajmlar va sanalar sizda farq qiladi, darsda bunday joylar `<...>` bilan belgilangan. Mac'dagi VM'da `amd64` o'rnida `arm64`, `archive.ubuntu.com/ubuntu` o'rnida `ports.ubuntu.com/ubuntu-ports` chiqadi, bu normal va 3-bo'limda tushuntiriladi.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` VM (Multipass, Ubuntu 24.04) va host'dagi Docker kerak. Paket o'rnatish tizimni o'zgartiradi, shuning uchun hech bir vazifa host'da (Zorin yoki macOS) paket o'rnatmaydi va repo qo'shmaydi: hammasi VM yoki bir martalik konteynerda.

| Joy | Belgi | Prompt | Nima uchun kerak |
|-----|-------|--------|------------------|
| Host (Zorin yoki macOS) | H | `user@host:~$` yoki `%` | `docker run`, `docker build`, `make`, `git`. Paket o'rnatilmaydi |
| `lab` VM | VM | `ubuntu@lab:~$` | `apt`, `dpkg`, repo va kalitlar, `hold`, pinning, `unattended-upgrades`, snap. systemd kerak bo'lgan hamma narsa |
| Ubuntu konteyner | U | `root@<id>:/#` | toza, bo'sh paket ro'yxatli muhit: `docker run --rm -it ubuntu:24.04 bash` |
| Rocky konteyner | R | `[root@<id> /]#` | `dnf` va `rpm`: `docker run --rm -it rockylinux:9 bash` |

- **VM**: `ubuntu` foydalanuvchisi `sudo` ni parolsiz ishlata oladi. O'qiydigan buyruqlar (`apt-cache`, `apt list`, `dpkg -l`, `dpkg -S`, `apt-mark showhold`) `sudo` siz ishlaydi, tizimni o'zgartiradiganlar (`apt update`, `install`, `remove`, `/etc/apt` ga yozish) `sudo` bilan.
- **Konteynerlar**: ichida siz root, shuning uchun `sudo` yozilmaydi (u o'rnatilmagan ham). Ubuntu image'ida paket ro'yxati bo'sh, birinchi buyruq `apt update`. `--rm` chiqishda konteynerni o'chiradi, tozalash shart emas. Konteynerda systemd yo'q (1-dars: konteynerda PID 1 sizning buyrug'ingiz), shuning uchun servis ishga tushishini kuzatadigan vazifalar VM'da.
- `rockylinux:9` image'i ikkala arxitektura uchun mavjud. Tekshirish (host'da, hech narsa yuklamaydi): `docker manifest inspect rockylinux:9 | grep architecture` chiqishida `amd64` va `arm64` bor. Docker o'zi host arxitekturasiga mosini tortadi.
- **Oldingi darslardan holat**: bu dars 10 va 11-darslardagi `deploy`, `demoapp` akkauntlari yoki `demoapp.service` ga tayanmaydi, toza `lab` yetarli. 11-darsdagi timer tushunchasi (`systemctl list-timers`) 5-bo'limda eslatiladi.
- **Mashinani almashtirsangiz**: javoblar git orqali ko'chadi, VM holati ko'chmaydi. B guruhdagi 10, 12 va 20-vazifalar 9-vazifada qo'shilgan Docker repo'siga, 12 va 20-vazifalar o'rnatilgan `nginx` ga tayanadi. Ikkinchi mashinada davom ettirsangiz, avval o'sha VM'da 9-vazifadagi repo qo'shish qadamlarini (README'ingizda yozilgan) va `sudo apt install -y nginx` ni qayta bajaring. Bu 2 daqiqalik ish.
- **Tozalash**: 20-vazifa VM'ni dastlabki holatga qaytaradi. Shubha bo'lsa SETUP.md dagi `clean` snapshot'ga qaytish mumkin.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM va konteynerlar `amd64`. Paket fayllari `_amd64.deb` va `.x86_64.rpm`, Ubuntu arxivi `archive.ubuntu.com/ubuntu` va `security.ubuntu.com/ubuntu`. Host'ning o'zi ham `apt` ishlatadi, shuning uchun o'qiydigan buyruqlarni (`apt-cache policy`, `dpkg -l`, `snap list`) host'da ham ixtiyoriy sinab ko'rish mumkin. Host'da hech narsa o'rnatilmaydi. |
| macOS (uy) | VM va konteynerlar `arm64` (`aarch64`). Paket fayllari `_arm64.deb` va `.aarch64.rpm`, Ubuntu arxivi hamma suite'lar uchun `ports.ubuntu.com/ubuntu-ports`. Host'da `apt`, `dpkg`, `snap` yo'q, paket menejeri Homebrew (`brew`), u tizimning qismi emas va root talab qilmaydi. Hamma vazifa VM va konteynerda bajariladi, Mac foydalanuvchisi bajara olmaydigan vazifa yo'q. |

---

## 1. Paket va paket menejeri

### Paket nima

Paket bu bitta dasturni (yoki kutubxonani) o'rnatish uchun kerakli hamma narsa solingan arxiv fayl. Ichida uch narsa bor:

| Qism | Nima | Misol |
|------|------|-------|
| Fayllar | binary, kutubxona, standart konfiguratsiya, systemd unit, man sahifa. Har fayl tizimdagi to'liq yo'li bilan | `/usr/bin/tree`, `/usr/share/man/man1/tree.1.gz` |
| Metama'lumot | nom, versiya, arxitektura, bog'liqliklar (bu paket ishlashi uchun kerak bo'lgan boshqa paketlar), tavsif | `Depends: libc6 (>= 2.38)` |
| Maintainer skriptlar | o'rnatish va o'chirish paytida **root sifatida** bajariladigan shell skriptlar: `preinst`, `postinst`, `prerm`, `postrm` | servis akkauntini yaratish, systemd unit'ni yoqish |

Paket menejeri bu paketlarni o'rnatadigan, yangilaydigan, o'chiradigan va tizimda nima o'rnatilganini bazada saqlaydigan asbob. 1-darsda aytilganidek, bu `npm` ning tizim darajasidagi o'xshashi, lekin farqlar katta (quyida).

### Ikki oila, ikki qatlam

Linux distributivlari paket formati bo'yicha ikki katta oilaga bo'linadi: Debian oilasi (Debian, Ubuntu, Zorin) `.deb` formatini, RHEL oilasi (Red Hat Enterprise Linux, Rocky, AlmaLinux, Fedora) `.rpm` formatini ishlatadi. Har oilada ikki qatlamli asboblar bor:

| Qatlam | Debian oilasi | RHEL oilasi | Vazifasi |
|--------|---------------|-------------|----------|
| Past | `dpkg` (`.deb`) | `rpm` (`.rpm`) | bitta paket faylini o'rnatish, o'chirish, o'rnatilganlar bazasini yuritish. Bog'liqlikni tekshiradi, lekin o'zi hech narsa yuklab olmaydi |
| Yuqori | `apt` | `dnf` | repository'lardan qidirish, bog'liqliklarni yechish, yuklash, imzoni tekshirish, keyin past qatlamni chaqirish |

Repository (repo) bu paketlar va ularning indeksi turadigan server, `npm` dagi registry'ning o'xshashi. `apt install nginx` deganingizda `apt` indeksdan `nginx` ni topadi, unga kerakli 5–10 paketni hisoblaydi, hammasini yuklaydi, imzoni tekshiradi va har birini `dpkg` ga beradi. `dpkg` arxivni ochadi, fayllarni joyiga qo'yadi va maintainer skriptlarni bajaradi.

### Mexanizm: .deb ichida nima bor

Paketni o'rnatmasdan yuklab olib ichiga qarash mumkin. `apt-get download` faylni joriy papkaga yuklaydi va root talab qilmaydi. VM ichida:

```
ubuntu@lab:~$ cd /tmp && apt-get download tree
Get:1 http://archive.ubuntu.com/ubuntu noble/universe amd64 tree amd64 2.1.1-<N> [<N> kB]
Fetched <N> kB in 0s (<N> kB/s)
ubuntu@lab:/tmp$ ls tree_*
tree_2.1.1-<N>_amd64.deb
```

Fayl nomi uch qismdan iborat: paket nomi `tree`, versiya `2.1.1-<N>` (chiziqchagacha upstream, ya'ni dastur muallifining versiyasi, chiziqchadan keyin distributivning o'z tahrir raqami), arxitektura `amd64`. Mac'dagi VM'da fayl `tree_2.1.1-<N>_arm64.deb` bo'ladi: binary paketlar har arxitektura uchun alohida kompilyatsiya qilinadi. Faqat skript va ma'lumotdan iborat paketlarda arxitektura `all` bo'ladi.

```
ubuntu@lab:/tmp$ dpkg-deb -I tree_*.deb
 new Debian package, version 2.0.
 size <N> bytes: control archive=<N> bytes.
     <N> bytes,    <N> lines      control
     <N> bytes,    <N> lines      md5sums
 Package: tree
 Version: 2.1.1-<N>
 Architecture: amd64
 Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
 Installed-Size: <N>
 Depends: libc6 (>= 2.38)
 Section: utils
 Priority: optional
 Description: displays an indented directory tree, in color
 ...
```

Qatorma-qator: `control archive` paketning metama'lumot qismi, ichida ikki fayl bor: `control` (pastdagi maydonlar) va `md5sums` (har faylning nazorat yig'indisi). `Package`, `Version`, `Architecture` fayl nomidagi uchlik. `Installed-Size` o'rnatilgandan keyin diskda egallaydigan joy, kilobaytda. `Depends` bog'liqlik: `libc6` paketining 2.38 yoki undan yangi versiyasi bo'lmasa `dpkg` bu paketni sozlashdan bosh tortadi. `tree` da maintainer skript yo'q, shuning uchun ro'yxatda `postinst` ko'rinmaydi.

```
ubuntu@lab:/tmp$ dpkg-deb -c tree_*.deb
drwxr-xr-x root/root         0 <sana> ./usr/bin/
-rwxr-xr-x root/root     <N> <sana> ./usr/bin/tree
...
-rw-r--r-- root/root      <N> <sana> ./usr/share/man/man1/tree.1.gz
```

`-c` (contents) fayllar ro'yxati: bu `ls -l` ga o'xshash format (9-dars), har fayl egasi `root/root` va yo'li tizim ildiziga nisbatan. O'rnatish aslida shu arxivni `/` ga ochish va bazaga yozib qo'yish.

Maintainer skriptlarni allaqachon o'rnatilgan paketda ko'rish mumkin. `dpkg` har paketning metama'lumotini `/var/lib/dpkg/info/` da saqlaydi:

```
ubuntu@lab:/tmp$ ls /var/lib/dpkg/info/openssh-server.*
/var/lib/dpkg/info/openssh-server.conffiles  /var/lib/dpkg/info/openssh-server.postinst
/var/lib/dpkg/info/openssh-server.list       /var/lib/dpkg/info/openssh-server.postrm
/var/lib/dpkg/info/openssh-server.md5sums    /var/lib/dpkg/info/openssh-server.preinst
...
```

`.list` paket o'rnatgan fayllar ro'yxati (`dpkg -L` shuni o'qiydi), `.conffiles` konfiguratsiya fayllari ro'yxati (`remove` va `purge` farqi shunga tayanadi, 2-bo'lim), `.postinst` o'rnatishdan keyin, `.preinst` oldin, `.postrm` o'chirishdan keyin bajariladigan skript. `less /var/lib/dpkg/info/openssh-server.postinst` bilan o'qib ko'ring: bu oddiy shell skript (5-dars), ichida host kalitlarini yaratish va servisni yoqish bor. Tekshirishdan keyin `rm /tmp/tree_*.deb` bilan faylni o'chiring.

### npm bilan taqqoslash

| | `npm` | `apt`/`dpkg` |
|---|-------|--------------|
| Qayerga o'rnatadi | loyiha papkasidagi `node_modules` | butun tizimga: `/usr`, `/etc`, `/var` |
| Bir paketning nechta versiyasi | har loyihada o'ziniki, bir daraxtda bir nechta | odatda bitta versiya butun tizimda |
| Kim nomidan | oddiy foydalanuvchi | root |
| O'rnatish skriptlari | `postinstall` (foydalanuvchi huquqi bilan) | `postinst` va boshqalar, root huquqi bilan |
| Versiyani kim tanlaydi | siz (`package.json`, semver oralig'i) | distributiv: har relizda bitta versiya muzlatilgan |
| Manbani tekshirish | registry'ga HTTPS, integrity hash `package-lock.json` da | GPG imzo zanjiri (3-bo'lim) |
| Tur | kutubxona va CLI asboblari | hamma narsa: kernel, kutubxona, servis, shrift |

Eng muhim farq versiya siyosatida. Ubuntu 24.04 chiqqan kuni har paketning asosiy versiyasi muzlatiladi va reliz umri davomida (LTS uchun 5 yil) o'zgarmaydi: faqat xavfsizlik va jiddiy xato tuzatishlari eski versiyaga ko'chiriladi (backport). Shuning uchun `curl` versiyasi `8.5.0-2ubuntu10.<N>` kabi ko'rinadi: `8.5.0` o'zgarmaydi, oxirgi raqam tuzatishlar soni bilan o'sadi. Yangiroq asosiy versiya kerak bo'lsa uch yo'l bor: uchinchi tomon repo'si (3-bo'lim), konteyner yoki til menejeri (`nvm`, `pyenv`).

### Real ishda qachon kerak

- "Bu fayl serverga qayerdan keldi?" degan savolga javob paket bazasida: `dpkg -S` (2-bo'lim).
- Paket o'rnatilganda servis o'zi ishga tushib qolganini ko'rsangiz, sababi `postinst` skripti. Uni `/var/lib/dpkg/info/` dan o'qish mumkin.
- Binary yuklaganda yoki image tanlaganda arxitektura mos kelishi shart: `dpkg --print-architecture` Zorin VM'ida `amd64`, Mac VM'ida `arm64` qaytaradi.
- Notanish `.deb` faylni o'rnatishdan oldin `dpkg-deb -I` va `dpkg-deb -c` bilan nima qilishini ko'rish.

### Nima uchun shunday

Ikki qatlam tarixiy va amaliy sababga ega. `dpkg` (1994) va `rpm` (1997) internet sekin va doimiy bo'lmagan davrda yozilgan: ular lokal fayl bilan ishlaydi va tarmoqqa muhtoj emas. Bog'liqliklarni qo'lda yuklash azobga aylangach ("dependency hell"), ustiga tarmoqdan o'zi yuklaydigan `apt` va `yum` (keyin `dnf`) qo'shildi. Ajratish hozir ham foydali: tarmoqsiz serverda `.deb` ni qo'lda o'rnatish, buzilgan holatni past qatlamda tuzatish mumkin. "Bitta versiya butun tizimga" qoidasi esa xavfsizlik uchun: `openssl` da zaiflik topilsa, bitta paketni yangilash hamma dasturni tuzatadi. `node_modules` modelida har loyihani alohida yangilash kerak bo'lardi. Narxi: ikki dastur bitta kutubxonaning ikki xil versiyasini talab qilsa, tizim paketlari buni yecha olmaydi, konteynerlar aynan shu muammoga javob.

---

## 2. Debian oilasi: apt va dpkg

### apt buyruqlari

| Buyruq | Nima qiladi |
|--------|-------------|
| `apt update` | repo'lardan paketlar **ro'yxatini** (indeksni) yangilaydi. Hech narsa o'rnatmaydi va yangilamaydi |
| `apt upgrade` | o'rnatilgan paketlarni yangilaydi, hech narsani o'chirmaydi |
| `apt full-upgrade` | yangilaydi, bog'liqlik talab qilsa paketlarni o'chiradi ham |
| `apt install nginx` | o'rnatish (bog'liqliklari bilan) |
| `apt install nginx=<versiya>` | aniq versiya (`apt-cache madison nginx` dagi to'liq satr) |
| `apt install ./file.deb` | lokal fayl, bog'liqliklarini repo'dan tortadi |
| `apt remove nginx` | o'chiradi, `/etc` dagi konfiguratsiya qoladi |
| `apt purge nginx` | konfiguratsiyasi bilan o'chiradi |
| `apt autoremove` | boshqa paket uchun avtomatik o'rnatilib, endi keraksiz bo'lganlarni o'chiradi |
| `apt search`, `apt show nginx` | qidirish, tavsif |
| `apt list --installed`, `apt list --upgradable` | ro'yxatlar |
| `apt-cache policy nginx` | o'rnatilgan va nomzod versiya, qaysi repo'dan, prioritet |

### Mexanizm: apt update nima qiladi

`apt` repo'ga har buyruqda murojaat qilmaydi. U repo indeksining lokal nusxasini `/var/lib/apt/lists/` da saqlaydi va `search`, `show`, `policy`, `install` shu nusxaga qarab ishlaydi. `apt update` shu nusxani yangilaydi. Bu `npm` dan farq: `npm install` har safar registry'dan so'raydi, `apt install` esa oxirgi `apt update` paytidagi rasmga ishonadi.

```
ubuntu@lab:~$ sudo apt update
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Get:2 http://archive.ubuntu.com/ubuntu noble-updates InRelease [<N> kB]
Get:3 http://security.ubuntu.com/ubuntu noble-security InRelease [<N> kB]
Hit:4 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Get:5 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages [<N> kB]
...
Fetched <N> MB in <N>s (<N> kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
<N> packages can be upgraded. Run 'apt list --upgradable' to see them.
```

Qatorma-qator: `Hit` "serverdagi fayl lokal nusxa bilan bir xil, yuklamadim"; `Get` "o'zgargan, yukladim", qavsdagi son hajm. `InRelease` har suite'ning imzolangan mundarija fayli (3-bo'lim), `noble-updates/main amd64 Packages` esa `noble-updates` suite'ining `main` qismidagi `amd64` paketlar indeksi. `Reading package lists` yuklangan indekslarni o'qish, `Building dependency tree` paketlar orasidagi bog'liqlik grafini qurish, `Reading state information` hozir nima o'rnatilganini `dpkg` bazasidan o'qish. Oxirgi qator: nechta o'rnatilgan paketning yangiroq versiyasi bor. Mac VM'ida URL'lar `http://ports.ubuntu.com/ubuntu-ports` va `arm64 Packages`.

**Tuzoq: `apt update` siz `install`.** Lokal ro'yxat eskirgan bo'lsa `apt` repo'da allaqachon yo'q versiyani so'raydi va `404 Not Found` oladi. Ro'yxat umuman bo'sh bo'lsa (yangi konteyner) `Unable to locate package` chiqadi. Yangi konteyner va yangi VM'da birinchi buyruq har doim `apt update`.

### Misol: apt-cache policy ni o'qish

Bu darsdagi eng muhim diagnostika buyrug'i. U "qaysi versiya o'rnatilgan, qaysi biri o'rnatilardi va nima uchun" degan savolga javob beradi:

```
ubuntu@lab:~$ apt-cache policy curl
curl:
  Installed: 8.5.0-2ubuntu10.<N>
  Candidate: 8.5.0-2ubuntu10.<N>
  Version table:
 *** 8.5.0-2ubuntu10.<N> 500
        500 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages
        500 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages
        100 /var/lib/dpkg/status
     8.5.0-2ubuntu10 500
        500 http://archive.ubuntu.com/ubuntu noble/main amd64 Packages
```

`Installed` hozir o'rnatilgan versiya (`(none)` bo'lsa o'rnatilmagan). `Candidate` nomzod: hozir `apt install curl` desangiz o'rnatiladigan versiya. Ikkalasi teng bo'lsa paket yangi. `Version table` ma'lum bo'lgan hamma versiyalar, yangisidan eskisiga. `***` o'rnatilgan versiyani belgilaydi. Versiya yonidagi `500` uning prioriteti, ostidagi qatorlar shu versiya qayerdan olinishi mumkinligi: `noble-updates/main` va `noble-security/main` (ikkala suite'da bor), `/var/lib/dpkg/status` esa "allaqachon o'rnatilgan" degan manba, uning prioriteti 100. Pastdagi `8.5.0-2ubuntu10` reliz kunidagi asl versiya, faqat `noble/main` da turadi. `apt` eng yuqori prioritetli, tenglikda eng yangi versiyani nomzod qiladi (4-bo'lim).

### Misol: o'rnatishni oldindan ko'rish

`-s` (`--simulate`, `--dry-run`) hech narsani o'zgartirmay, nima bo'lishini ko'rsatadi va root talab qilmaydi:

```
ubuntu@lab:~$ apt-get install -s tree
NOTE: This is only a simulation!
      apt-get needs root privileges for real execution.
...
The following NEW packages will be installed:
  tree
0 upgraded, 1 newly installed, 0 to remove and <N> not upgraded.
Inst tree (2.1.1-<N> Ubuntu:24.04/noble [amd64])
Conf tree (2.1.1-<N> Ubuntu:24.04/noble [amd64])
```

`The following NEW packages` yangi o'rnatiladiganlar (bog'liqliklar ham shu yerda chiqadi). Xulosa qatori to'rt son: yangilanadigan, yangi, o'chiriladigan va yangilanishi mumkin, lekin bu amalda tegilmaydigan paketlar. `0 to remove` ga doim qarang: kutilmagan o'chirish shu yerda ko'rinadi. `Inst` va `Conf` `dpkg` ning ikki bosqichi: avval fayllarni ochish (unpack), keyin sozlash (`postinst` ni bajarish). O'rnatish o'rtada uzilsa paket "ochilgan, lekin sozlanmagan" holatda qoladi.

### apt va apt-get

`apt` odam uchun (progress, ranglar), uning chiqish formati barqaror deb kafolatlanmagan, pipe'da o'zi ogohlantiradi: `WARNING: apt does not have a stable CLI interface. Use with caution in scripts.` Skript, Dockerfile va CI'da `apt-get` va `apt-cache` ishlatiladi, ularning chiqishi va xatti-harakati versiyalar orasida saqlanadi.

Avtomatlashtirishda savol so'ralmasligi kerak, chunki javob beradigan odam yo'q:

```
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
```

`-y` tasdiqlarga "ha" deydi. `DEBIAN_FRONTEND=noninteractive` paket sozlash dialoglarini o'chiradi (ba'zi paketlar `postinst` da savol beradi) va standart javobni oladi. `--no-install-recommends` "tavsiya etilgan" qo'shimcha paketlarni o'rnatmaydi. Paket metama'lumotida uch darajali bog'liqlik bor: `Depends` (usiz ishlamaydi, majburiy), `Recommends` (ko'p hollarda kerak, standart holatda o'rnatiladi), `Suggests` (foydali bo'lishi mumkin, o'rnatilmaydi).

Dockerfile naqshi: `update`, `install` va ro'yxatni tozalash bitta `RUN` da. Docker har `RUN` natijasini qatlam sifatida keshlaydi; alohida `RUN apt-get update` qatlami bir marta bajarilib keshda qoladi va haftalar o'tib o'zgartirilgan keyingi `install` qatori eskirgan ro'yxat bilan ishlaydi:

```
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
```

### dpkg: o'rnatilganlar bazasi

| Buyruq | Savol |
|--------|-------|
| `dpkg -l` / `dpkg -l 'nginx*'` | nima o'rnatilgan |
| `dpkg -L nginx-common` | bu paket qaysi fayllarni o'rnatgan |
| `dpkg -S /usr/bin/curl` | bu fayl qaysi paketdan |
| `dpkg -s curl` | paket holati va metama'lumoti |
| `dpkg -i file.deb` | faylni o'rnatish (bog'liqliklarni yuklamaydi) |
| `dpkg --configure -a` | uzilib qolgan o'rnatishni tugatish |

```
ubuntu@lab:~$ dpkg -l curl
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name           Version               Architecture Description
+++-==============-=====================-============-===============================================
ii  curl           8.5.0-2ubuntu10.<N>   amd64        command line tool for transferring data with URL syntax
```

Birinchi uch qator sarlavha emas, birinchi ustunning kaliti. Ustun ikki harfdan iborat: birinchisi **istalgan** holat (`i` install, `r` remove, `p` purge, `h` hold), ikkinchisi **haqiqiy** holat (`i` installed, `c` faqat konfiguratsiya fayllari qolgan, `n` yo'q, `U` ochilgan, sozlanmagan). `ii` "o'rnatilishi kerak va o'rnatilgan", ya'ni sog'lom holat. `rc` "o'chirilgan, konfiguratsiyasi qolgan", `hi` "ushlab qo'yilgan va o'rnatilgan". Boshqa kombinatsiya (`iU`, `iF`) uzilgan o'rnatishni bildiradi.

```
ubuntu@lab:~$ command -v curl
/usr/bin/curl
ubuntu@lab:~$ dpkg -S /usr/bin/curl
curl: /usr/bin/curl
ubuntu@lab:~$ dpkg -L curl | head -4
/.
/usr
/usr/bin
/usr/bin/curl
```

`dpkg -S` (search) fayl yo'lidan paketga, `dpkg -L` (list) paketdan fayllarga boradi. `-S` to'liq va haqiqiy yo'lni kutadi: buyruq symlink bo'lsa (8-dars) avval `readlink -f` bilan manzilini toping, aks holda `no path found matching pattern` chiqadi.

### remove va purge

Paket fayllari ikki turga bo'linadi: oddiy fayllar va **conffile** (paket `/etc` ga qo'ygan konfiguratsiya, ro'yxati `.conffiles` da). `apt remove` oddiy fayllarni o'chiradi, conffile'larni qoldiradi: siz tahrirlagan sozlamalar qayta o'rnatganda saqlanadi, `dpkg -l` da holat `rc`. `apt purge` conffile'larni ham o'chiradi va `postrm` skriptiga "hammasini tozala" deydi (u paket yaratgan ma'lumot va log papkalarini o'chirishi mumkin). Yangilanishda ham conffile himoyalangan: siz o'zgartirgan faylni paket ustidan yozmaydi, yangi versiyasi bilan farq bo'lsa so'raydi.

### Tarix va lock

Tarix: `/var/log/apt/history.log` (qaysi buyruq, kim, qachon, nima o'zgardi) va `/var/log/dpkg.log` (past qatlam, har paket holati sekundma-sekund). "Kecha ishlardi, bugun ishlamayapti" bo'lganda birinchi qaraladigan joylardan:

```
ubuntu@lab:~$ tail -6 /var/log/apt/history.log
Start-Date: <sana>  <vaqt>
Commandline: apt install tree
Requested-By: ubuntu (1000)
Install: tree:amd64 (2.1.1-<N>)
End-Date: <sana>  <vaqt>
```

`Commandline` aynan terilgan buyruq, `Requested-By` `sudo` ni kim chaqirgani (UID bilan, 10-dars), `Install` (yoki `Upgrade`, `Remove`, `Purge`) nima o'zgargani. Avtomatik yangilanishlar ham shu yerga yoziladi, ularda `Requested-By` bo'lmaydi.

**Tuzoq: lock xatosi.** `Could not get lock /var/lib/dpkg/lock-frontend` boshqa `apt` jarayoni ishlayotganini bildiradi (ko'pincha yangi VM'da fon yangilanishi). Lock bu "men hozir bazaga yozyapman" degan belgi fayl. Uni o'chirmang: ikki jarayon bazaga parallel yozsa baza buziladi. Jarayon tugashini kuting (`ps aux | grep -E 'apt|dpkg'`, 7-dars). O'rnatish o'rtasida uzilgan bo'lsa: `sudo dpkg --configure -a`, keyin `sudo apt --fix-broken install`.

### Real ishda qachon kerak

- Production'da har qanday `upgrade` oldidan `apt list --upgradable` va `apt-get upgrade -s`: nima yangilanadi va nima o'chiriladi.
- Incident tahlilida `history.log`: xato boshlangan vaqtda paket yangilanganmi.
- Dockerfile yozishda `apt-get`, `-y`, `--no-install-recommends` va ro'yxatni tozalash; bu image hajmi va build barqarorligiga bevosita ta'sir qiladi.
- "Bu konfiguratsiya fayli kimniki" savolida `dpkg -S`, "paket qayerga nima qo'ydi" savolida `dpkg -L`.

### Nima uchun shunday

Indeksning lokal nusxasi tezlik va takrorlanuvchanlik uchun: bog'liqlik grafini qurish uchun o'n minglab paket ta'rifi kerak, uni har buyruqda tarmoqdan so'rash sekin bo'lardi, bundan tashqari `update` va `install` orasida "dunyo" o'zgarmaydi. Narxi shu darsdagi birinchi tuzoq: nusxa eskiradi. `dnf` boshqa yo'l tanlagan: kesh muddati o'tsa o'zi yangilaydi (6-bo'lim). `remove` va `purge` ajratilishi administratorning mehnatini himoya qiladi: sozlangan servisni vaqtincha olib tashlab qayta o'rnatish konfiguratsiyani yo'qotmasligi kerak. `apt` va `apt-get` ning yonma-yon yashashi orqaga moslik uchun: `apt-get` chiqishiga minglab skriptlar bog'langan, uni chiroyli qilish ularni sindirardi, shuning uchun 2014-yilda odamlar uchun alohida `apt` buyrug'i qo'shildi.

---

## 3. Repository va ishonch zanjiri

### Manba ro'yxati

`apt` qaysi repo'lardan foydalanishini `/etc/apt/sources.list.d/` dagi fayllardan biladi. Ubuntu 24.04 da asosiy repo'lar deb822 formatida (har maydon alohida qatorda, `Kalit: qiymat`), `ubuntu.sources` faylida:

```
ubuntu@lab:~$ cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

`Types: deb` binary paketlar (`deb-src` manba kodi bo'lardi). `URIs` repo manzili. `Suites` shu manzildagi qaysi oqimlar. `Components` har oqimning qaysi qismlari. `Signed-By` shu repo'ni tekshiradigan public kalit fayli. Bo'sh qator bloklarni ajratadi, bu yerda ikki blok: asosiy arxiv va xavfsizlik arxivi. Fayl boshida izoh qatorlari (`#`) bo'lishi mumkin. Mac VM'ida ikkala blokda ham `URIs: http://ports.ubuntu.com/ubuntu-ports/` turadi: Ubuntu `amd64` paketlarini asosiy arxivda, qolgan arxitekturalarni (`arm64` ham) alohida "ports" arxivida tarqatadi. Tarkib va imzo kaliti bir xil, faqat manzil boshqa.

Eski bir qatorli format (`.list` fayllarda) hali ham keng tarqalgan va uchinchi tomon yo'riqnomalarida ko'p uchraydi: `deb [signed-by=...] URL suite component`.

| Tushuncha | Ma'nosi |
|-----------|---------|
| Suite | reliz va uning oqimi: `noble` (reliz kunidagi holat, o'zgarmaydi), `noble-updates` (xato tuzatishlari), `noble-security` (xavfsizlik tuzatishlari), `noble-backports` (ixtiyoriy yangiroq versiyalar) |
| Component | `main` (Canonical qo'llab-quvvatlaydi, erkin), `universe` (hamjamiyat), `restricted` va `multiverse` (erkin bo'lmagan) |
| Signed-By | shu repo'ni tekshirish uchun ishlatiladigan kalit fayli |

Repo ichidagi fayl yo'li shu so'zlardan yig'iladi: `<URI>/dists/<suite>/InRelease` va `<URI>/dists/<suite>/<component>/binary-<arch>/Packages`. Shuning uchun `apt update` chiqishida `noble-updates/main amd64 Packages` kabi yozuvlar ko'rinadi.

### Mexanizm: imzo qanday ishlaydi

GPG (GNU Privacy Guard) bu ochiq kalitli kriptografiya asbobi. Kalit juft bo'ladi: private kalit (faqat egasida) bilan imzo qo'yiladi, public kalit (hammaga tarqatiladi) bilan imzo tekshiriladi. Public kalit bilan imzo yasab bo'lmaydi. Hash esa fayl mazmunidan hisoblanadigan qisqa "barmoq izi": fayl bir bayt o'zgarsa hash butunlay boshqa chiqadi.

Zanjir uch halqadan iborat:

1. Repo egasi har suite uchun `InRelease` faylini private kaliti bilan imzolaydi. Bu faylda shu suite'dagi hamma `Packages` indekslarining hash'lari yozilgan.
2. Har `Packages` indeksida undagi har `.deb` faylning hash'i va hajmi yozilgan.
3. `apt update` `InRelease` imzosini `Signed-By` dagi public kalit bilan tekshiradi va yuklangan `Packages` hash'ini `InRelease` dagisi bilan solishtiradi. `apt install` yuklangan `.deb` hash'ini `Packages` dagisi bilan solishtiradi.

Natija: bitta imzo butun repo'ni qamraydi. Yo'lda kimdir `.deb` ni almashtirsa hash mos kelmaydi; `Packages` ni ham almashtirsa uning hash'i `InRelease` ga mos kelmaydi; `InRelease` ni almashtirsa imzo buziladi, chunki private kalit unda yo'q. Shuning uchun Ubuntu arxivi oddiy HTTP orqali va ixtiyoriy ko'zgu (mirror) serverlardan tarqatilsa ham paketni yo'lda almashtirib bo'lmaydi. Ishonchning ildizi diskdagi public kalit: uni qayerdan va qanday olganingiz butun zanjirning eng zaif nuqtasi. Ubuntu kaliti `ubuntu-keyring` paketida, tizim bilan birga keladi.

Bu `package-lock.json` dagi `integrity` maydoniga o'xshaydi: u yerda ham yuklangan arxiv hash'i solishtiriladi. Farqi: lock fayldagi hash'ni siz birinchi o'rnatishda registry'dan olgansiz, `apt` da esa hash'lar ro'yxatining o'zi imzolangan.

### Misol: uchinchi tomon repo'sini qo'shish

Docker, PostgreSQL, HashiCorp, Kubernetes kabi loyihalar o'z repo'sini yuritadi, chunki Ubuntu arxividagi versiya muzlatilgan. Qo'shish uch qadamdan iborat: kalitni olish, manba faylini yozish, ro'yxatni yangilash. Namuna HashiCorp repo'si (Terraform shu yerdan keladi):

```
ubuntu@lab:~$ sudo install -m 0755 -d /etc/apt/keyrings
ubuntu@lab:~$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
ubuntu@lab:~$ gpg --show-keys /etc/apt/keyrings/hashicorp.gpg
pub   rsa4096 <sana> [SC] [expires: <sana>]
      <40 ta hex belgi>
uid                      HashiCorp Security (HashiCorp Package Signing) <security+packaging@hashicorp.com>
sub   rsa4096 <sana> [S] [expires: <sana>]
```

`install -m 0755 -d` papkani ruxsatlari bilan yaratadi (9-dars), 24.04 da u odatda allaqachon bor. `curl -fsSL` kalitni HTTPS orqali rasmiy manzildan oladi. `gpg --dearmor` matnli (ASCII armor, `-----BEGIN PGP PUBLIC KEY BLOCK-----` bilan boshlanadigan) kalitni binary formatga o'giradi; `apt` ikkalasini ham tushunadi: matnli kalit `.asc`, binary kalit `.gpg` kengaytmasi bilan saqlanadi, kengaytma mazmunga mos bo'lishi shart. `gpg --show-keys` faylni import qilmasdan ichini ko'rsatadi: `pub` kalit turi va muddati, ostidagi 40 belgili satr **fingerprint** (kalitning barmoq izi), `uid` egasi. Fingerprint'ni loyihaning rasmiy sahifasidagi bilan solishtirish kalit haqiqiy ekanini tekshirishning yagona yo'li.

```
ubuntu@lab:~$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com noble main
ubuntu@lab:~$ sudo apt update
...
Get:5 https://apt.releases.hashicorp.com noble InRelease [<N> kB]
Get:6 https://apt.releases.hashicorp.com noble/main amd64 Packages [<N> kB]
...
ubuntu@lab:~$ apt-cache policy terraform
terraform:
  Installed: (none)
  Candidate: <versiya>
  Version table:
     <versiya> 500
        500 https://apt.releases.hashicorp.com noble/main amd64 Packages
...
```

Manba qatori shell tomonidan yig'iladi (4-dars, command substitution): `$(dpkg --print-architecture)` shu mashinaning arxitekturasini qo'yadi, Zorin VM'ida `amd64`, Mac VM'ida `arm64`. Qo'lda `arch=amd64` deb yozilgan yo'riqnoma Mac VM'ida "paket topilmadi" bilan tugaydi, shuning uchun har doim shu shakl ishlatiladi. `$(. /etc/os-release && echo "$VERSION_CODENAME")` reliz kod nomini (`noble`) qo'yadi (1-dars). `sudo tee` kerak, chunki `sudo echo ... > fayl` da yo'naltirishni root emas, sizning shell'ingiz bajaradi (4-dars). `tee` yozgan qatorni ekranga ham chiqaradi, uni o'qib tekshiring. `apt update` da yangi repo'ning `InRelease` va `Packages` fayllari yuklangani ko'rinadi, `policy` esa `terraform` paketi endi ma'lum va shu repo'dan kelishini ko'rsatadi. Sinovdan keyin tozalash: `sudo rm /etc/apt/sources.list.d/hashicorp.list /etc/apt/keyrings/hashicorp.gpg && sudo apt update`.

Uch qoida:

- Kalit alohida faylga, `/etc/apt/keyrings/` ga (paket o'rnatgan kalitlar `/usr/share/keyrings/` da turadi), HTTPS orqali rasmiy manzildan.
- Repo ta'rifida `signed-by=` shu faylga ishora qiladi. Natijada bu kalit faqat shu repo'ni tasdiqlay oladi.
- Har repo o'z faylida, `/etc/apt/sources.list.d/` da. O'chirish oson, nima qo'shilgani ko'rinib turadi.

**Tuzoq: `apt-key add` va `trusted.gpg.d`.** Eski yo'riqnomalardagi `curl ... | sudo apt-key add -` kalitni global ishonchli qiladi: u istalgan repo'ni, shu jumladan Ubuntu'ning o'z paketlarini imzolashga yaroqli bo'lib qoladi. Bitta uchinchi tomon kaliti o'g'irlansa, u orqali `openssl` ning "yangi versiyasi" ni ham taklif qilish mumkin. `apt-key` eskirgan deb e'lon qilingan; har doim `signed-by`.

**Tuzoq: `curl | sudo bash` o'rnatuvchilari.** Bu skript root sifatida istalgan narsani qiladi va odatda ichida repo qo'shadi. Avval yuklab o'qing yoki qadamlarni qo'lda bajaring. `[trusted=yes]` va `--allow-unauthenticated` imzo tekshiruvini o'chiradi, production'da ishlatilmaydi.

Uchinchi tomon repo'si tizim paketlarini almashtira olishini ham hisobga oling: u xuddi shu nomli yangiroq paketni taklif qilsa, `apt upgrade` uni o'rnatadi ("Birga bajaramiz" da ko'rasiz). Bunga qarshi vosita pinning (4-bo'lim).

### Real ishda qachon kerak

- Har yangi serverga Docker, PostgreSQL yoki Kubernetes asboblarini o'rnatish shu uch qadamdan boshlanadi. Ansible va Terraform'dagi provisioning kodi ham aynan shuni yozadi.
- `apt update` da `NO_PUBKEY` yoki `EXPKEYSIG` xatosi: kalit yo'q yoki muddati o'tgan. Yechim kalitni rasmiy manzildan yangilash, tekshiruvni o'chirish emas.
- Xavfsizlik auditida `/etc/apt/sources.list.d/` va `/etc/apt/keyrings/` ko'riladi: har repo serverga root huquqi bilan kod yetkaza oladigan tomon.
- Ichki tarmoqda (internetsiz) kompaniya o'z mirror'ini yuritadi; imzo zanjiri tufayli mirror'ga ishonish shart emas, faqat kalitga.

### Nima uchun shunday

Imzo alohida paketlarga emas, indeksga qo'yilgani mirror'lar tarmog'ini imkonli qiladi: minglab universitet va provayder serverlari Ubuntu arxivining nusxasini tarqatadi va ularning hech biriga ishonish talab qilinmaydi. HTTPS bu vazifani bajara olmaydi: u faqat "men shu server bilan gaplashyapman" ni kafolatlaydi, server buzilgan bo'lsa yoki mirror yomon niyatli bo'lsa yordam bermaydi. `signed-by` 2010-yillar oxirida global kalitlar muammosiga javob sifatida paydo bo'ldi: eski modelda har qo'shilgan kalit butun tizim uchun ishonchli edi va uchinchi tomon repo'lari ko'paygan sari xavf o'sdi. Muhim cheklov: `signed-by` repo egasining o'zidan himoya qilmaydi. Repo qo'shish bu uning egasiga serveringizda root huquqi bilan kod bajarishga ruxsat berish (maintainer skriptlar), shuning uchun har repo ongli qaror bo'lishi kerak.

---

## 4. Versiyani ushlab turish

### hold

`apt upgrade` hamma paketni nomzod versiyaga ko'taradi. Ba'zi komponentlar uchun bu xavfli: ma'lumotlar bazasi, container runtime, Kubernetes'ning `kubelet` va `kubeadm` asboblari faqat rejali va tartib bilan yangilanishi kerak. `hold` paketni "tegilmasin" deb belgilaydi:

```
ubuntu@lab:~$ sudo apt-mark hold tree
tree set on hold.
ubuntu@lab:~$ apt-mark showhold
tree
ubuntu@lab:~$ dpkg -l tree | tail -1
hi  tree           2.1.1-<N>    amd64        displays an indented directory tree, in color
ubuntu@lab:~$ sudo apt-mark unhold tree
Canceled hold on tree.
```

`apt-mark hold` `dpkg` bazasidagi "istalgan holat" ni `h` ga o'zgartiradi, shuning uchun `dpkg -l` da birinchi ustun `hi` (2-bo'limdagi kalit). Ushlab qo'yilgan paket `apt upgrade` va `unattended-upgrades` da yangilanmaydi va boshqa paket uni yangilashni talab qilsa, o'sha paket ham kutadi. Narxi: xavfsizlik tuzatishlari ham kelmaydi. Shuning uchun `hold` vaqtinchalik qaror, sababi va muddati hujjatlashtirilishi kerak.

### Pinning

Pinning nozikroq boshqaruv: `/etc/apt/preferences.d/` dagi fayllar bilan versiya yoki butun manbaga prioritet beriladi. Mexanizm 2-bo'limdagi `apt-cache policy` raqamlarida:

| Prioritet | Ma'nosi |
|-----------|---------|
| 100 | allaqachon o'rnatilgan versiya (`/var/lib/dpkg/status`) |
| 500 | repo'dagi versiya, standart qiymat |
| 100 | `noble-backports` kabi "avtomatik emas" deb belgilangan suite'lar (faqat so'ralganda o'rnatiladi, keyin yangilanib turadi) |
| 990 | `APT::Default-Release` bilan tanlangan reliz |
| 1000 dan yuqori | downgrade'ga ham ruxsat beradi |
| manfiy | versiya hech qachon o'rnatilmaydi |

Qoida: eng yuqori prioritetli versiya nomzod bo'ladi; prioritetlar teng bo'lsa eng yangi versiya yutadi; 1000 dan past prioritet o'rnatilgandan eskiroq versiyaga qaytarmaydi. Fayl uch qatorli bloklardan iborat:

```
ubuntu@lab:~$ cat /etc/apt/preferences.d/tree-pin
Package: tree
Pin: version 2.1.1*
Pin-Priority: 1001
```

`Package` qaysi paket (`*` hamma paket, `nginx*` kabi glob mumkin). `Pin` nimaga qarab tanlash: `version <naqsh>` versiya bo'yicha, `release a=noble-backports` suite bo'yicha, `origin <hostname>` repo serveri bo'yicha. `Pin-Priority` beriladigan son. Natijani yana `policy` ko'rsatadi:

```
ubuntu@lab:~$ apt-cache policy tree
tree:
  Installed: 2.1.1-<N>
  Candidate: 2.1.1-<N>
  Version table:
 *** 2.1.1-<N> 1001
        500 http://archive.ubuntu.com/ubuntu noble/universe amd64 Packages
        100 /var/lib/dpkg/status
```

Versiya yonidagi son `500` dan `1001` ga o'zgardi: bu pin ishlaganining isboti. Ostidagi `500` manbaning o'z prioriteti, u o'zgarmaydi. Pin yozib, `policy` da son o'zgarmagan bo'lsa, `Pin` qatoridagi naqsh hech narsaga mos kelmagan (eng ko'p uchraydigan xato). Fayl nomi kengaytmasiz yoki `.pref` bilan bo'lishi kerak. Mavjud versiyalar ro'yxati: `apt-cache madison tree` yoki `apt list -a tree`.

`hold` va pinning farqi: `hold` "hozirgi versiyada qol" degan oddiy bayroq, `dpkg` bazasida. Pinning "qaysi versiya nomzod bo'lsin" degan qoida, `apt` konfiguratsiyasida, va u hali o'rnatilmagan paketlarga ham ta'sir qiladi.

### Real ishda qachon kerak

- Kubernetes rasmiy yo'riqnomasi `kubelet`, `kubeadm`, `kubectl` o'rnatilgach darhol `apt-mark hold` qilishni aytadi: klaster versiyasi tasodifiy `apt upgrade` bilan o'zgarmasligi kerak.
- Uchinchi tomon repo'si tizim paketini almashtirmasligi uchun shu repo'ga past prioritet beriladi, kerakli paketlargagina yuqori.
- Yangi versiyada xato chiqsa: eski versiyaga `apt install paket=<versiya>` bilan qaytib, tuzatish chiqquncha `hold`.

### Nima uchun shunday

`npm` da versiyani `package.json` va lock fayl ushlaydi, chunki har loyiha o'z daraxtiga ega. Tizim paketlarida lock fayl yo'q: "to'g'ri versiya" bu repo'dagi eng yangisi degan faraz bor, chunki distributiv reliz ichida mos kelmaydigan o'zgarish kiritmaslikka va'da beradi. `hold` va pinning shu farazdan chetga chiqish kerak bo'lgan kam holatlar uchun. Prioritet tizimi raqamli bo'lgani bir nechta repo va relizni aralashtirishga imkon beradi (masalan asosan `stable`, bitta paket `backports` dan), lekin murakkabligi tufayli xatoga moyil; shuning uchun ko'p jamoalar pinning o'rniga aniq versiyali konteyner image'lariga o'tgan.

---

## 5. Avtomatik yangilanish va tozalash

### unattended-upgrades

Xavfsizlik tuzatishi chiqqan kundan boshlab zaiflik ommaga ma'lum, hujumchilar tuzatishni o'qib ekspluatatsiya yozadi. Yuzlab serverga qo'lda `apt upgrade` qilish kechikadi. `unattended-upgrades` paketi xavfsizlik yangilanishlarini qo'lsiz o'rnatadi; Ubuntu Server va cloud image'larda (`lab` VM ham) standart o'rnatilgan va yoqilgan.

| Fayl | Nima |
|------|------|
| `/etc/apt/apt.conf.d/20auto-upgrades` | yoqilganmi va qancha tez-tez |
| `/etc/apt/apt.conf.d/50unattended-upgrades` | nima yangilanadi (`Allowed-Origins`), qora ro'yxat (`Package-Blacklist`), avtomatik reboot (`Automatic-Reboot`) |
| `/var/log/unattended-upgrades/` | nima qilingani |

```
ubuntu@lab:~$ cat /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Birinchi qator "paket ro'yxatini har 1 kunda yangila" (avtomatik `apt update`), ikkinchisi "har 1 kunda unattended-upgrade ni ishga tushir". `"0"` o'chirilgan degani. Ishga tushirishni cron emas, ikki systemd timer bajaradi (11-dars): `apt-daily.timer` ro'yxatni yangilaydi, `apt-daily-upgrade.timer` yangilanishlarni o'rnatadi. Ularni `systemctl list-timers 'apt-*'` ko'rsatadi; yangi VM'dagi lock xatosining (2-bo'lim) sababi ko'pincha shu timer'lar.

Nima qilishini o'zgartirmasdan ko'rish: `sudo unattended-upgrade --dry-run --debug`. Chiqishda qaysi manbalarga ruxsat borligi va qaysi paketlar yangilanishi yoziladi.

### O'rnatildi degani ishlayapti degani emas

Yangilanish diskdagi faylni almashtiradi. Ishlab turgan jarayon esa eski faylni xotiraga yuklab olgan va uni ishlatishda davom etadi (8-darsdagi inode: o'chirilgan fayl ochiq turgan jarayon uchun hali mavjud). Shuning uchun:

- kernel yangilanishi reboot'ni talab qiladi. Belgi: `/var/run/reboot-required` fayli paydo bo'ladi, `/var/run/reboot-required.pkgs` esa sababchi paketlarni sanaydi;
- kutubxona yangilanishi (`openssl`, `glibc`) undan foydalanayotgan servislarni qayta ishga tushirishni talab qiladi. Buni `needrestart` asbobi tekshiradi, 24.04 da u `apt` dan keyin o'zi ishga tushadi.

Node servisida ham xuddi shunday: `node_modules` ni yangilash ishlab turgan jarayonga ta'sir qilmaydi, `pm2 restart` kerak.

### Tozalash

| Buyruq | Nimani bo'shatadi |
|--------|-------------------|
| `apt clean` | yuklangan `.deb` fayllar keshi (`/var/cache/apt/archives/`) |
| `apt autoremove --purge` | keraksiz bog'liqliklar, shu jumladan eski kernel'lar |
| `rm -rf /var/lib/apt/lists/*` | paket ro'yxatlari (faqat image qurishda, keyingi `apt update` qayta yuklaydi) |

`autoremove` qanday biladi: `apt` har paketni "manual" (siz nomini yozib o'rnatgansiz) yoki "auto" (bog'liqlik sifatida kelgan) deb belgilaydi. Hech bir manual paket talab qilmaydigan auto paket keraksiz hisoblanadi. `apt-mark showmanual` va `apt-mark showauto` shu belgilarni ko'rsatadi.

`/boot` alohida kichik bo'lim bo'lgan serverlarda eski kernel'lar to'planib joyni tugatadi va navbatdagi yangilanish yarim yo'lda yiqiladi: `autoremove` muntazam bajarilishi kerak (disklar 13-darsda).

### Real ishda qachon kerak

- Har production serverda savol: xavfsizlik yangilanishlari avtomatikmi, reboot kim va qachon qiladi. Odatiy javob: yangilanish avtomatik, reboot rejali oynada yoki navbat bilan (klasterda bittadan).
- Zaiflik e'lon qilinganda tekshiruv ro'yxati: paket versiyasi yangilanganmi (`apt-cache policy`), servis qayta ishga tushganmi, reboot kerakmi.
- Disk to'lganda (`/var`): `apt clean` tez va xavfsiz birinchi qadam.

### Nima uchun shunday

Standart sozlama faqat `-security` manbasini avtomatik yangilaydi, chunki xavfsizlik tuzatishlari minimal o'zgarish bilan chiqariladi va xatti-harakatni o'zgartirmaslikka intiladi; oddiy `-updates` da esa xavf yuqoriroq. Avtomatik reboot standart o'chiq, chunki tizim sizning servisingiz uchun qaysi vaqt xavfsiz ekanini bilmaydi. Bu ikki xavfni tortish: yangilanmagan server (ma'lum zaiflik bilan) va kutilmagan yangilanish (servis buzilishi). Tajriba ko'rsatadiki, birinchisi ko'proq zarar keltiradi, shuning uchun standart "xavfsizlik avtomatik". Katta infratuzilmalar boshqa model ishlatadi: serverni yangilamaydi, yangi image'dan qayta yaratadi (immutable infrastructure, keyingi modullarda).

---

## 6. RHEL oilasi: dnf va rpm

Bank, telekom va davlat sektorida serverlar ko'pincha RHEL yoki uning bepul nusxalari (Rocky Linux, AlmaLinux) da ishlaydi. Tushunchalar bir xil (paket, repo, imzo, ikki qatlam), buyruqlar va ba'zi xatti-harakatlar boshqa. Bu bo'lim host'dan ishga tushiriladigan konteynerda bajariladi:

```
$ docker run --rm -it rockylinux:9 bash
[root@<id> /]# cat /etc/os-release | head -3
NAME="Rocky Linux"
VERSION="9.<N> (Blue Onyx)"
ID="rocky"
```

Prompt formati boshqa (`[user@host papka]#`), `ID="rocky"`, undan keyingi `ID_LIKE` qatorida `rhel centos fedora` turadi (1-dars). RHEL 8 dan beri `yum` buyrug'i `dnf` ga symlink: eski yo'riqnomalardagi `yum install` aynan `dnf install`.

### dnf

| Buyruq | Nima qiladi |
|--------|-------------|
| `dnf install nginx`, `dnf remove nginx` | o'rnatish, o'chirish |
| `dnf upgrade` | hamma paketni yangilash. Alohida "update" qadami yo'q: metama'lumot keshi eskirgan bo'lsa o'zi yangilaydi |
| `dnf check-update` | yangilanishlar ro'yxati; exit code 100 "yangilanish bor", 0 "yo'q", 1 "xato" |
| `dnf search`, `dnf info nginx` | qidirish, tavsif |
| `dnf list installed`, `dnf list --showduplicates nginx` | o'rnatilganlar, mavjud versiyalar |
| `dnf provides /usr/bin/dig` | bu fayl yoki buyruqni qaysi paket beradi (o'rnatilmagan bo'lsa ham) |
| `dnf repolist`, `dnf repolist --all` | yoqilgan va hamma repo'lar |
| `dnf history`, `dnf history info N`, `dnf history undo N` | tranzaksiyalar tarixi va bekor qilish |
| `dnf clean all`, `dnf makecache` | keshni tozalash va qayta qurish |

```
[root@<id> /]# dnf repolist
repo id                    repo name
appstream                  Rocky Linux 9 - AppStream
baseos                     Rocky Linux 9 - BaseOS
extras                     Rocky Linux 9 - Extras
[root@<id> /]# dnf install -y less
Rocky Linux 9 - BaseOS                          <N> MB/s | <N> MB     00:0<N>
Rocky Linux 9 - AppStream                       <N> MB/s | <N> MB     00:0<N>
Rocky Linux 9 - Extras                          <N> kB/s | <N> kB     00:0<N>
Dependencies resolved.
================================================================================
 Package        Architecture     Version               Repository        Size
================================================================================
Installing:
 less           x86_64           <versiya>.el9         baseos           <N> k

Transaction Summary
================================================================================
Install  1 Package
...
Complete!
```

`repolist` uchta yoqilgan repo'ni ko'rsatadi: `baseos` (tizim asosi), `appstream` (dasturlar), `extras`. `install` ning birinchi uch qatori repo metama'lumotini yuklash: bu `apt update` ning o'rnini bosadi va kesh bo'sh yoki eskirgan bo'lgani uchun avtomatik bajarildi. `Dependencies resolved` dan keyin jadval: qaysi paket, arxitektura (`x86_64`, Mac'da `aarch64`), versiya (`el9` Enterprise Linux 9 uchun yig'ilganini bildiradi), qaysi repo'dan. `Transaction Summary`: `dnf` har amalni tranzaksiya deb ataydi va raqamlab tarixga yozadi. Agar konteyneringizda `less` allaqachon bo'lsa `Nothing to do.` chiqadi, boshqa kichik paket bilan sinang (masalan `tree`).

### rpm

| Buyruq | Savol | `dpkg` dagi o'xshashi |
|--------|-------|----------------------|
| `rpm -qa` | nima o'rnatilgan | `dpkg -l` |
| `rpm -qi bash` | paket ma'lumoti | `dpkg -s bash` |
| `rpm -ql bash` | paket fayllari | `dpkg -L bash` |
| `rpm -qf /usr/bin/bash` | fayl qaysi paketdan | `dpkg -S /usr/bin/bash` |
| `rpm -q --scripts bash` | o'rnatish skriptlari | `/var/lib/dpkg/info/*.postinst` |
| `rpm -K file.rpm` | fayl imzosini tekshirish | yo'q (imzo indeksda) |

```
[root@<id> /]# rpm -qf /usr/bin/bash
bash-5.1.8-<N>.el9.x86_64
```

`rpm` paketni to'liq nomi bilan qaytaradi: nom `bash`, versiya `5.1.8`, reliz `<N>.el9`, arxitektura `x86_64`. `-q` (query) so'rov rejimi, undan keyingi harf nima so'ralayotgani: `a` all, `i` info, `l` list, `f` file.

### Repo'lar va imzo

Ta'riflar `/etc/yum.repos.d/*.repo` da, INI formatida (bo'lim nomi kvadrat qavsda, ostida `kalit=qiymat`):

```
[baseos]
name=Rocky Linux $releasever - BaseOS
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=BaseOS-$releasever$rltype
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
```

`$releasever` va `$basearch` ni `dnf` o'zi to'ldiradi (reliz raqami va arxitektura: `x86_64` yoki `aarch64`), shuning uchun bitta `.repo` fayl ikkala mashinada o'zgarishsiz ishlaydi. Debian oilasidan farqi: bu yerda odatda har `.rpm` paketning o'zi imzolangan va `gpgcheck=1` shuni tekshiradi. `gpgkey` da ko'rsatilgan kalit birinchi ishlatilganda import qilinadi (`-y` siz tasdiq so'raydi). `gpgcheck=0` imzo tekshiruvini o'chiradi, uchinchi tomon `.repo` faylini qo'shishdan oldin shu qatorga qarang.

Qo'shimcha paketlar uchun hamjamiyat repo'si EPEL (Extra Packages for Enterprise Linux): `dnf install -y epel-release`. E'tibor bering, repo'ning o'zi paket sifatida o'rnatiladi: paket `.repo` faylini va kalitni joyiga qo'yadi. Uchinchi tomon repo'si `.repo` faylini `/etc/yum.repos.d/` ga qo'yish yoki `dnf config-manager --add-repo URL` (`dnf-plugins-core` paketi) bilan qo'shiladi.

Versiyani ushlash: `dnf install -y python3-dnf-plugin-versionlock`, keyin `dnf versionlock add nginx`, `dnf versionlock list`, `dnf versionlock delete nginx`. Avtomatik yangilanish: `dnf-automatic` paketi va uning timer'i.

### Real ishda qachon kerak

- Buyurtmachi infratuzilmasi RHEL'da bo'lsa, Ubuntu'da yozilgan skript va Dockerfile'ni ko'chirish.
- Ansible playbook ikkala oilani qo'llab-quvvatlashi kerak bo'lganda paket nomlari va servis xatti-harakati farqini bilish (7-bo'lim).
- Minimal konteynerda yetishmayotgan buyruqni topish: `dnf provides` o'rnatilmagan paketlar ichidan ham qidiradi.

### Nima uchun shunday

Ikki oila 1990-yillarda mustaqil paydo bo'lgan: Debian hamjamiyat loyihasi, Red Hat tijorat kompaniyasi sifatida, va har biri o'z formatini yaratgan. Birlashtirish urinishlari muvaffaqiyatsiz bo'lgan, chunki format ortida butun ekotizim (build tizimi, siyosat, o'n minglab paket) turadi. `dnf` keyinroq yozilgani uchun ba'zi qarorlari boshqacha: metama'lumotni o'zi yangilaydi (unutilgan `update` muammosi yo'q, narxi: har buyruq sekinroq boshlanishi mumkin) va tranzaksiya tarixini bekor qilish imkoni bilan saqlaydi. RHEL oilasida servis o'rnatilganda ishga tushmasligi ongli siyosat: administrator avval sozlasin, keyin o'zi yoqsin. Debian "o'rnatdingmi, demak ishlatmoqchisan" deb hisoblaydi. Ikkalasining ham mantig'i bor, muhimi farqni bilish.

---

## 7. apt va dnf yonma-yon

Bu jadval ikki oila orasidagi lug'at. Uni yodlash shart emas, lekin qaysi tushuncha ikkalasida borligini va qayerda nomi yoki xatti-harakati farq qilishini ko'rib chiqing.

| Vazifa | Debian/Ubuntu | RHEL/Rocky/Fedora |
|--------|---------------|-------------------|
| Ro'yxatni yangilash | `apt update` | kerak emas (`dnf makecache`) |
| Hammasini yangilash | `apt upgrade` | `dnf upgrade` |
| O'rnatish / o'chirish | `apt install X` / `apt remove X` | `dnf install X` / `dnf remove X` |
| Konfiguratsiyasi bilan o'chirish | `apt purge X` | alohida tushuncha yo'q |
| Qidirish / ma'lumot | `apt search` / `apt show` | `dnf search` / `dnf info` |
| Fayl qaysi paketdan (o'rnatilgan) | `dpkg -S /path` | `rpm -qf /path` |
| Paket fayllari | `dpkg -L X` | `rpm -ql X` |
| Buyruqni qaysi paket beradi | `apt-file search` (alohida paket) | `dnf provides` |
| O'rnatilganlar | `dpkg -l`, `apt list --installed` | `rpm -qa`, `dnf list installed` |
| Lokal fayl | `apt install ./x.deb` | `dnf install ./x.rpm` |
| Versiyani ushlash | `apt-mark hold X` | `dnf versionlock add X` |
| Keraksizlarni o'chirish | `apt autoremove` | `dnf autoremove` |
| Keshni tozalash | `apt clean` | `dnf clean all` |
| Tarix | `/var/log/apt/history.log` | `dnf history` (bekor qilish bilan) |
| Repo ta'riflari | `/etc/apt/sources.list.d/` | `/etc/yum.repos.d/` |
| Avtomatik yangilanish | `unattended-upgrades` | `dnf-automatic` |
| Arxitektura nomi | `amd64`, `arm64` | `x86_64`, `aarch64` |
| Paket nomlari | `apache2`, `libssl-dev`, `openssh-server` | `httpd`, `openssl-devel`, `openssh-server` |
| O'rnatilgan servis | odatda darhol ishga tushadi va `enable` bo'ladi | o'rnatiladi, lekin ishga tushmaydi: `systemctl enable --now` kerak |

Oxirgi uch qator ikki oila orasida ko'chirilgan skript va playbook'lar buzilishining eng ko'p sababi. Paket nomlarida naqsh bor: kutubxonaning sarlavha fayllari (kompilyatsiya uchun) Debian'da `-dev`, RHEL'da `-devel` qo'shimchasi bilan keladi, lekin asosiy nom ham farq qilishi mumkin (`apache2` va `httpd`), shuning uchun har doim `search` bilan tekshiriladi.

### Real ishda qachon kerak

- Ko'p distributivli Ansible roli yoki o'rnatish skripti yozishda (`ID_LIKE` bo'yicha tarmoqlanish, 19-vazifa).
- Internetdagi yo'riqnoma boshqa oila uchun yozilgan bo'lsa, uni o'z tizimingizga "tarjima" qilishda.
- Bazaviy image tanlashda (`ubuntu`, `debian`, `rockylinux`, `ubi`): jamoa qaysi asboblarni bilishi hal qiluvchi omillardan.

### Nima uchun shunday

Farqlarning ko'pi sirtda: bir xil tushunchalar boshqa nom bilan. Chuqur farqlar siyosatda: servisni avtomatik yoqish, konfiguratsiyani saqlab o'chirish (`purge` tushunchasi), imzoning joyi (indeksda yoki paketda). Shu sababli avtomatlashtirish asboblari (Ansible `package` moduli) sirtdagi farqni yashira oladi, lekin siyosatdagi farqni emas: "o'rnatdim, ishlayaptimi?" savoliga javob oilaga bog'liq bo'lib qoladi.

---

## 8. snap va flatpak (qisqa)

### Nima va nima uchun

An'anaviy paketlar tizim kutubxonalarini bo'lishadi: dastur distributivdagi `libssl` versiyasi bilan ishlashi shart. Dastur muallifi uchun bu har distributiv va har reliz uchun alohida paket degani. Universal formatlar dasturni bog'liqliklari bilan birga bitta faylga o'raydi va cheklangan muhitda (sandbox) ishga tushiradi. Bu `node_modules` modeliga yaqinroq: har dastur o'z bog'liqliklarini o'zi bilan olib yuradi.

| | snap | flatpak |
|---|------|---------|
| Kim | Canonical, Ubuntu'da standart | hamjamiyat, Fedora va boshqalarda standart |
| Do'kon | Snap Store (yagona, markazlashgan) | Flathub va boshqa remote'lar |
| Yo'nalish | desktop, server va CLI asboblari | asosan desktop dasturlar |
| Buyruqlar | `snap list`, `snap install X`, `snap refresh`, `snap remove X` | `flatpak list`, `flatpak install`, `flatpak update` |
| Yangilanish | avtomatik, fon rejimida | qo'lda yoki desktop orqali |

### Mexanizm: snap qanday o'rnatiladi

Snap bu squashfs formatidagi bitta fayl (`.snap`): siqilgan, faqat o'qiladigan fayl tizimi image'i. O'rnatish arxivni ochish emas, shu faylni `/snap/<nom>/<reviziya>/` ga **mount** qilish (fayl tizimini papkaga ulash, 13-dars). Faylni disk kabi ulash uchun kernel `loop` qurilmasidan foydalanadi. Shuning uchun snap o'rnatilgan tizimda `df` va `lsblk` da ko'p `loop` qatorlari ko'rinadi:

```
ubuntu@lab:~$ df -hT | grep squashfs
/dev/loop0     squashfs   <N>M   <N>M     0 100% /snap/<nom>/<reviziya>
```

Ustunlar: qurilma, fayl tizimi turi, hajm, band, bo'sh, foiz, mount nuqtasi. `100%` va `0` bo'sh joy xato emas: faqat o'qiladigan image har doim "to'la". Disk to'lganini tekshirganda bu qatorlar e'tiborga olinmaydi. Toza `lab` VM'da snap o'rnatilmagan bo'lishi mumkin, u holda chiqish bo'sh (18-vazifada o'zingiz o'rnatasiz).

Serverda bilish kerak bo'lganlari: snap'lar o'zi yangilanadi (`snap refresh --hold` bilan to'xtatiladi); yangilanishda eski reviziya saqlanadi va `snap revert` bilan qaytish mumkin; **confinement** (cheklov rejimi) `strict` bo'lsa snap faqat ruxsat berilgan resurslarni ko'radi, `classic` bo'lsa cheklovsiz ishlaydi. Zorin'da Multipass snap sifatida o'rnatilgan, Mac'da esa Homebrew orqali: bir xil dastur, ikki xil tarqatish yo'li.

### Real ishda qachon kerak

- `lsblk` yoki `df` chiqishidagi `loop` qurilmalarni tushunish va ularni haqiqiy disklar bilan aralashtirmaslik.
- Ubuntu serverida `certbot`, `lxd`, `kubectl` kabi asboblar rasmiy ravishda snap orqali tarqatiladi.
- Server dasturlari uchun production'da ko'proq `apt`/`dnf` paketlari va konteynerlar ishlatiladi; snap va flatpak asosan desktop va CLI asboblari uchun.

### Nima uchun shunday

Universal formatlar dastur mualliflarining muammosini yechadi: bitta paket hamma distributivda ishlaydi va muallif yangilanishni o'zi boshqaradi. Narxi: har dastur o'z kutubxonalarini olib yuradi (disk va xotira ko'proq), xavfsizlik tuzatishi distributivga emas, har dastur muallifiga bog'liq bo'lib qoladi. Bu "bitta versiya butun tizimga" (1-bo'lim) qoidasining teskari tomoni. Konteynerlar ham xuddi shu g'oyaga tayanadi (dastur + bog'liqliklari bitta image'da), faqat izolyatsiya kuchliroq va orkestratsiya asboblari bor; shuning uchun server tomonda konteynerlar yutgan.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Paket | dastur fayllari, metama'lumot va o'rnatish skriptlari solingan arxiv (`.deb`, `.rpm`) |
| Paket menejeri | paketlarni o'rnatuvchi, yangilovchi, o'chiruvchi va o'rnatilganlar bazasini yurituvchi asbob |
| Repository (repo) | paketlar va ularning indeksi turadigan server |
| Bog'liqlik (dependency) | paket ishlashi uchun o'rnatilgan bo'lishi kerak bo'lgan boshqa paket |
| `Depends` / `Recommends` / `Suggests` | majburiy, standart o'rnatiladigan tavsiya va ixtiyoriy bog'liqlik darajalari |
| Maintainer skript | o'rnatish yoki o'chirishda root sifatida bajariladigan skript (`preinst`, `postinst`, `prerm`, `postrm`) |
| Conffile | paket `/etc` ga qo'ygan, `remove` da saqlanadigan konfiguratsiya fayli |
| Indeks (`Packages`) | repo'dagi hamma paketlarning ta'rifi va hash'lari yozilgan fayl |
| `InRelease` | suite'ning imzolangan mundarijasi, indekslar hash'ini saqlaydi |
| Suite | reliz oqimi: `noble`, `noble-updates`, `noble-security`, `noble-backports` |
| Component | repo'ning qismi: `main`, `universe`, `restricted`, `multiverse` |
| deb822 | manba ta'rifining ko'p qatorli `Kalit: qiymat` formati (`.sources` fayllar) |
| GPG kalit | imzo qo'yish (private) va tekshirish (public) uchun kalit jufti |
| `signed-by` | kalitni faqat bitta repo uchun ishonchli qiladigan manba sozlamasi |
| Candidate | `apt install` hozir o'rnatadigan nomzod versiya |
| Hold | paketni yangilanishdan ushlab turadigan belgi |
| Pinning | versiya yoki manbaga prioritet berib nomzodni boshqarish (`/etc/apt/preferences.d/`) |
| unattended-upgrades | xavfsizlik yangilanishlarini avtomatik o'rnatadigan servis |
| snap / flatpak | dasturni bog'liqliklari bilan o'raydigan universal paket formatlari |

## Tuzoqlar

- `apt update` siz `apt install`: eskirgan ro'yxat, `404` yoki `Unable to locate package`. Dockerfile'da `update` va `install` ni alohida `RUN` ga ajratish ham shu xatoning bir ko'rinishi.
- Kalitni `apt-key add` yoki `trusted.gpg.d` orqali global ishonchli qilish. Har doim `signed-by` va alohida kalit fayli.
- Manba qatorida `arch=amd64` ni qo'lda yozish: Mac'dagi `arm64` VM'da va ARM serverlarda paket topilmaydi. `arch=$(dpkg --print-architecture)` yozing.
- Kalit kengaytmasi mazmunga mos emas (`gpg --dearmor` qilinmagan matnli kalit `.gpg` nomi bilan): `apt update` kalitni o'qiy olmaydi va `NO_PUBKEY` beradi.
- Internetdan topilgan `curl | sudo bash` ni o'qimasdan ishga tushirish; `gpgcheck=0`, `[trusted=yes]` bilan imzoni o'chirish.
- Production serverda `apt upgrade` ni nima yangilanishini ko'rmasdan bajarish. Avval `apt list --upgradable` va `-s`, muhim komponentlar `hold` da, yangilanish avval staging'da.
- `hold` qo'yib unutish: paket yillab xavfsizlik tuzatishlarisiz qoladi.
- Pin yozib `apt-cache policy` bilan tekshirmaslik: naqsh mos kelmasa pin jimgina ishlamaydi.
- Yangilanishdan keyin servisni qayta ishga tushirmaslik yoki reboot qilmaslik: diskda yangi versiya, xotirada eski zaif kod ishlayapti.
- Skriptda `apt` (barqaror bo'lmagan chiqish) va `-y`/`DEBIAN_FRONTEND` siz chaqiruv: CI dialog kutib osilib qoladi.
- Lock xatosida lock faylni o'chirish. Ishlayotgan `dpkg` bilan parallel yozish paket bazasini buzadi.
- Debian uchun yozilgan qo'llanmani RHEL'da (yoki teskarisi) paket nomlari va "servis o'zi ishga tushadi" farqini hisobga olmasdan qo'llash.
- Tizim Python'iga `sudo pip install` bilan paket o'rnatish: `apt` boshqaradigan fayllar ustidan yoziladi. Til paketlari uchun virtual muhit yoki konteyner.
- `df` dagi `100%` to'la `loop` qurilmalarni disk to'lgan deb o'ylash: bular snap image'lari.
- Mac host'ida `apt` yoki `dpkg` izlash: u yerda yo'q. Homebrew boshqa asbob, darsdagi buyruqlar VM va konteynerda.

## Manbalar

- https://manpages.ubuntu.com/manpages/noble/en/man8/apt.8.html – apt(8)
- https://manpages.ubuntu.com/manpages/noble/en/man1/dpkg.1.html – dpkg(1): holat harflari, `-l`, `-L`, `-S`
- https://manpages.ubuntu.com/manpages/noble/en/man5/sources.list.5.html – sources.list(5): deb822 formati, `Signed-By`
- https://manpages.ubuntu.com/manpages/noble/en/man5/apt_preferences.5.html – apt_preferences(5): pinning va prioritetlar
- https://wiki.debian.org/DebianRepository/UseThirdParty – uchinchi tomon repo'sini to'g'ri qo'shish qoidalari (majburiy)
- https://wiki.debian.org/SecureApt – imzo zanjiri qanday ishlashi
- https://documentation.ubuntu.com/server/explanation/software/third-party-repository-usage/ – Ubuntu Server: third party repository usage
- https://documentation.ubuntu.com/server/how-to/software/automatic-updates/ – Ubuntu Server: automatic updates
- https://docs.docker.com/engine/install/ubuntu/ – `signed-by` bilan repo qo'shishning amaliy namunasi (9-vazifa)
- https://developer.hashicorp.com/terraform/install – HashiCorp repo'si (3-bo'limdagi misol)
- https://www.postgresql.org/download/linux/ubuntu/ – PGDG repo'si ("Birga bajaramiz")
- https://www.debian.org/doc/manuals/debian-reference/ch02.en.html – Debian Reference, 2-bob: package management
- https://www.debian.org/doc/debian-policy/ch-maintainerscripts.html – Debian Policy: maintainer skriptlar
- https://dnf.readthedocs.io/en/latest/command_ref.html – DNF command reference
- https://docs.rockylinux.org/books/admin_guide/13-softwares/ – Rocky Linux Admin Guide: software management
- https://snapcraft.io/docs – snap hujjatlari
- https://docs.flatpak.org/en/latest/ – flatpak hujjatlari

## Birga bajaramiz

Bitta haqiqiy vaziyatni boshidan oxirigacha o'tamiz: serverga PostgreSQL mijozi (`psql`) kerak, Ubuntu arxividagi versiya eski, yangisi PostgreSQL loyihasining o'z repo'sida (PGDG). Yo'lda darsdagi hamma qatlamni ko'ramiz: `policy`, kalit, deb822 manba, imzo, nomzod almashishi, `dpkg` bazasi va tozalash. Hamma narsa `lab` VM ichida. Bu misol vazifalardagi Docker repo'sidan boshqa repo va boshqa format (deb822, matnli kalit) bilan ishlaydi.

1. Hozir Ubuntu nima taklif qiladi:

```
ubuntu@lab:~$ sudo apt update
ubuntu@lab:~$ apt-cache policy postgresql-client
postgresql-client:
  Installed: (none)
  Candidate: 16+<N>
  Version table:
     16+<N> 500
        500 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages
...
```

`Installed: (none)` o'rnatilmagan. `Candidate: 16+<N>`: Ubuntu 24.04 PostgreSQL 16 bilan muzlatilgan (1-bo'lim). `postgresql-client` aslida "metapaket": o'zida fayl yo'q, faqat `postgresql-client-16` ga bog'liqlik, shunda nom versiyasiz qoladi.

2. Kalitni olish va ko'rish:

```
ubuntu@lab:~$ sudo install -m 0755 -d /etc/apt/keyrings
ubuntu@lab:~$ sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /etc/apt/keyrings/pgdg.asc
ubuntu@lab:~$ head -1 /etc/apt/keyrings/pgdg.asc
-----BEGIN PGP PUBLIC KEY BLOCK-----
ubuntu@lab:~$ gpg --show-keys /etc/apt/keyrings/pgdg.asc
pub   rsa4096 <sana> [SC]
      <40 ta hex belgi>
uid                      PostgreSQL Debian Repository
```

`head -1` fayl matnli (ASCII armor) ekanini ko'rsatadi, shuning uchun kengaytma `.asc` va `--dearmor` kerak emas. `gpg --show-keys` dagi fingerprint'ning oxirgi 8 belgisi URL'dagi `ACCC4CF8` bilan mos kelishi kerak: bu kalitning qisqa identifikatori. To'liq fingerprint'ni https://www.postgresql.org/download/linux/ubuntu/ dagi bilan solishtiring.

3. Manba faylini deb822 formatida yozish. `tee` ga matn here-document orqali beriladi (4-dars):

```
ubuntu@lab:~$ sudo tee /etc/apt/sources.list.d/pgdg.sources <<'EOF'
Types: deb
URIs: https://apt.postgresql.org/pub/repos/apt
Suites: noble-pgdg
Components: main
Signed-By: /etc/apt/keyrings/pgdg.asc
EOF
```

deb822 da `Architectures:` maydoni yozilmasa `apt` tizimning o'z arxitekturasini oladi, shuning uchun bu fayl Zorin va Mac VM'larida o'zgarishsiz ishlaydi (bir qatorli formatdagi `arch=$(dpkg --print-architecture)` ning o'rnini shu bosadi). Suite nomi `noble-pgdg`: repo egasi o'z suite'larini o'zi nomlaydi.

4. Ro'yxatni yangilash va imzo tekshirilganini ko'rish:

```
ubuntu@lab:~$ sudo apt update
...
Get:5 https://apt.postgresql.org/pub/repos/apt noble-pgdg InRelease [<N> kB]
Get:6 https://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 Packages [<N> kB]
...
Reading package lists... Done
```

Xato va `W:` ogohlantirish yo'q, demak `InRelease` imzosi `pgdg.asc` bilan tekshirildi. Bu yerda `NO_PUBKEY` chiqsa, `Signed-By` yo'li yoki kalit fayli noto'g'ri.

5. Nomzod o'zgardimi:

```
ubuntu@lab:~$ apt-cache policy postgresql-client
postgresql-client:
  Installed: (none)
  Candidate: <NN>+<N>.pgdg24.04+1
  Version table:
     <NN>+<N>.pgdg24.04+1 500
        500 https://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 Packages
     16+<N> 500
        500 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages
```

Endi ikki versiya ma'lum va ikkalasining prioriteti 500. Tenglikda yangisi yutadi, shuning uchun `Candidate` PGDG versiyasiga o'tdi (`<NN>` 16 dan katta). Hech narsa o'rnatmadingiz, lekin `apt install postgresql-client` ning ma'nosi o'zgardi. Uchinchi tomon repo'si tizim paketini "almashtira oladi" degani aynan shu.

6. O'rnatishdan oldin simulyatsiya, keyin o'rnatish:

```
ubuntu@lab:~$ apt-get install -s postgresql-client | grep -E '^(Inst|[0-9]+ upgraded)'
0 upgraded, <N> newly installed, 0 to remove and <N> not upgraded.
Inst libpq5 (<versiya>.pgdg24.04+1 ...)
Inst postgresql-client-common (<versiya> ...)
Inst postgresql-client-<NN> (<versiya> ...)
Inst postgresql-client (<versiya> ...)
ubuntu@lab:~$ sudo apt-get install -y postgresql-client
ubuntu@lab:~$ psql --version
psql (PostgreSQL) <NN>.<N> (Ubuntu <NN>.<N>-<N>.pgdg24.04+1)
```

Simulyatsiyada bitta paket so'radingiz, bir nechtasi keladi: metapaket, haqiqiy mijoz, umumiy fayllar va `libpq5` kutubxonasi. Versiyalardagi `pgdg` qo'shimchasi hammasi yangi repo'dan kelayotganini ko'rsatadi. `0 to remove` ekaniga ishonch hosil qilindi.

7. `psql` aslida qaysi paketdan:

```
ubuntu@lab:~$ command -v psql
/usr/bin/psql
ubuntu@lab:~$ dpkg -S /usr/bin/psql
postgresql-client-common: /usr/bin/psql
ubuntu@lab:~$ readlink -f /usr/bin/psql
/usr/share/postgresql-common/pg_wrapper
ubuntu@lab:~$ dpkg -L postgresql-client-<NN> | grep 'bin/psql'
/usr/lib/postgresql/<NN>/bin/psql
```

`/usr/bin/psql` symlink (8-dars) va u `postgresql-client-common` paketiga tegishli, haqiqiy binary emas: u `pg_wrapper` skriptiga ko'rsatadi. Haqiqiy binary `/usr/lib/postgresql/<NN>/bin/` da, versiyali paketda. Debian shu yo'l bilan "bitta versiya" qoidasini PostgreSQL uchun chetlab o'tadi: bir nechta asosiy versiya yonma-yon o'rnatiladi, wrapper keraklisini tanlaydi.

8. Tozalash: hammasini teskari tartibda qaytaramiz.

```
ubuntu@lab:~$ sudo apt-get purge -y postgresql-client postgresql-client-<NN> postgresql-client-common
ubuntu@lab:~$ sudo apt-get autoremove --purge -y
ubuntu@lab:~$ sudo rm /etc/apt/sources.list.d/pgdg.sources /etc/apt/keyrings/pgdg.asc
ubuntu@lab:~$ sudo apt update
ubuntu@lab:~$ apt-cache policy postgresql-client | head -3
postgresql-client:
  Installed: (none)
  Candidate: 16+<N>
```

`autoremove` endi hech kim talab qilmaydigan `libpq5` ni olib tashlaydi. Repo fayli va kalit o'chirilgach `apt update` lokal indeksdan PGDG'ni chiqaradi va nomzod yana Ubuntu'ning 16 versiyasiga qaytadi. Oxirgi `policy` tozalash to'liq bo'lganining isboti.

Shu 8 qadamda ko'rganingiz: `apt` lokal indeksga qarab ishlaydi (2-bo'lim), repo qo'shish bu kalit va manba fayli (3-bo'lim), bir xil nomli paketda prioritet va versiya nomzodni hal qiladi (4-bo'lim), `dpkg` bazasi har fayl kimniki ekanini biladi (2-bo'lim), tozalash esa hammasini izsiz qaytaradi.

---

## Vazifalar

Ish papkasi: `linux/12-packages/` (`make new m=linux n=12 name=packages` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`Dockerfile`, skript, repo fayli nusxasi) yoniga saqlang. Har vazifada muhit ko'rsatilgan: VM (`lab`), U (`ubuntu:24.04` konteyner), R (`rockylinux:9` konteyner), H (host: faqat `docker` buyruqlari, paket o'rnatilmaydi). README'da qaysi mashinada (Zorin `amd64` yoki Mac `arm64`) bajarganingizni bir marta yozib qo'ying, chiqishlardagi arxitektura va URL shunga bog'liq. Har vazifa oxiridagi "Yo'nalish" qaysi bo'limga qarash kerakligini aytadi, javobni emas.

### A. apt va dpkg

1. **Inventory.** (VM) Nechta paket o'rnatilgan (`dpkg -l` yoki `apt list --installed` va `wc -l`; sarlavha qatorlarini hisobdan chiqarishni unutmang)? `apt-mark showmanual | wc -l` va `apt-mark showauto | wc -l` ni oling: "manual" va "auto" farqi nima va `autoremove` bunga qanday tayanadi? `apt list --upgradable` nechta paket ko'rsatadi? `dpkg --print-architecture` nima qaytardi? Yo'nalish: 2-bo'lim "dpkg: o'rnatilganlar bazasi", 5-bo'lim "Tozalash".

2. **Which package owns it.** (VM) `curl`, `ls`, `systemctl` va `ssh` binary'lari qaysi paketdan ekanini `dpkg -S` bilan toping (yo'lni `command -v` bilan, symlink bo'lsa `readlink -f` bilan aniqlang). Shu paketlardan birining fayllar ro'yxatidan konfiguratsiya va unit fayllarini (`/etc`, `systemd`) `grep` bilan ajrating. Ixtiyoriy, faqat Zorin host'ida: xuddi shuni `docker` binary'si uchun bajaring (o'qiydigan buyruq, hech narsa o'zgarmaydi). Yo'nalish: 2-bo'lim, `dpkg -S` va `dpkg -L` misoli.

3. **Stale lists.** (U) Yangi konteynerda `apt update` siz `apt install -y curl` ni bajaring: xato nima? `ls /var/lib/apt/lists/` ni `apt update` dan oldin va keyin solishtiring. `apt update` chiqishidagi `Get:`, `Hit:` qatorlari va `InRelease` so'zi nimani bildirishini o'z chiqishingizdan misol bilan yozing. Yangi konteynerda nima uchun hamma qator `Get`? Yo'nalish: 2-bo'lim, "Mexanizm: apt update nima qiladi".

4. **Install lifecycle.** (VM) `nginx` ni o'rnating. `apt-cache policy nginx`, `dpkg -L nginx-common | head`, `systemctl is-enabled nginx` va `systemctl is-active nginx` ni oling: servisni kim yoqdi? `/etc/nginx/nginx.conf` ga izoh qatori qo'shing. `apt remove nginx nginx-common` dan keyin fayl bormi, `dpkg -l | grep nginx` da holat ustuni nima? `apt purge` dan keyin-chi? `/var/log/apt/history.log` dan shu amallaringizni toping. Yo'nalish: 2-bo'lim, "remove va purge" va "Tarix va lock"; 1-bo'lim, maintainer skriptlar.

5. **Dependencies.** (U) `apt-get install -y nginx` va `apt-get install -y --no-install-recommends nginx` ni ikki alohida konteynerda `--dry-run` (yoki `-s`) bilan bajarib, o'rnatiladigan paketlar sonini solishtiring. `apt-cache depends nginx` va `apt-cache rdepends nginx-common` nimani ko'rsatadi? `Depends` va `Recommends` farqini yozing. Yo'nalish: 2-bo'lim, "apt va apt-get" va "o'rnatishni oldindan ko'rish".

6. **Slim Dockerfile.** (H) `Dockerfile` yozing: `ubuntu:24.04` asosida `curl` va `ca-certificates` o'rnatilgan image, 2-bo'limdagi naqsh bo'yicha. Ikkinchi variantni (`Dockerfile.naive`) ataylab yomon yozing: `update` va `install` alohida `RUN`, `--no-install-recommends` va tozalashsiz. Ikkalasini build qilib `docker images` da hajmini solishtiring. `docker history` bilan qaysi qatlam qancha joy olganini ko'rsating. Test image'larni o'chiring. Dockerfile ikkala mashinada o'zgarishsiz build bo'lishi kerak (unda arxitektura yozilmaydi). Yo'nalish: 2-bo'lim, Dockerfile naqshi.

7. **Interactive prompt.** (U) `apt-get install tzdata` ni `-y` va `DEBIAN_FRONTEND` siz bajaring: nima so'radi? CI'da bu nimaga olib keladi? To'g'ri variantni yozing va u qaysi vaqt zonasini tanlaganini `cat /etc/timezone` bilan ko'rsating. Yo'nalish: 2-bo'lim, "apt va apt-get".

### B. Repository va imzo

8. **Read the sources.** (VM) `/etc/apt/sources.list.d/ubuntu.sources` ni o'qing: nechta manba bloki, qaysi suite va component'lar, `Signed-By` qaysi fayl, `URIs` nima (Zorin va Mac VM'larida nima uchun farq qiladi)? `apt-cache policy` (argumentsiz) chiqishidagi qatorlarni shu fayl bilan bog'lang. `curl` paketi qaysi suite'dan kelganini `apt-cache policy curl` dan aniqlang. Yo'nalish: 3-bo'lim "Manba ro'yxati", 2-bo'lim "apt-cache policy ni o'qish".

9. **Add a third-party repo.** (VM) Docker'ning rasmiy repo'sini https://docs.docker.com/engine/install/ubuntu/ dagi qadamlar bilan qo'shing va 3-bo'limdagi uch qoidaga mosligini tekshiring. Har qadam nima qilishini README'da izohlang: `install -d`, `curl -fsSL` flag'larining har biri, `signed-by`, `arch=`, `$VERSION_CODENAME`. Hosil bo'lgan manba faylida arxitektura nima deb yozildi va u qo'lda yozilganmi? `apt update` dan keyin `apt-cache policy docker-ce` nima ko'rsatadi? Mavjud versiyalarni `apt-cache madison docker-ce` bilan chiqaring. Paketni o'rnatish shart emas. Repo fayli nusxasini ish papkasiga saqlang (kalit commit qilinmaydi). Yo'nalish: 3-bo'lim, "Misol: uchinchi tomon repo'sini qo'shish".

10. **Break the signature.** (VM) Docker repo fayli va kalitdan zaxira nusxa oling. Birinchi tajriba: `signed-by` yo'lini mavjud bo'lmagan faylga o'zgartiring va `sudo apt update` qiling. Ikkinchi tajriba: `signed-by` ni Ubuntu'ning o'z kalitiga (`/usr/share/keyrings/ubuntu-archive-keyring.gpg`) qarating. Har ikki xato xabarini yozing (`NO_PUBKEY` va shunga o'xshash so'zlarni qidiring) va `apt` bu holatda repo bilan nima qilishini izohlang: qolgan repo'lar yangilandimi, `apt-cache policy docker-ce` nima ko'rsatadi? Tiklang va `apt update` toza o'tishini ko'rsating. Yo'nalish: 3-bo'lim, "Mexanizm: imzo qanday ishlaydi".

11. **Why not apt-key.** `man apt-key` (VM) dagi DEPRECATION bo'limini va Debian wiki'dagi UseThirdParty sahifasini o'qing. O'z so'zingiz bilan 4–5 gapda yozing: global ishonchli kalit qanday hujumga yo'l ochadi, `signed-by` buni qanday cheklaydi, va u nimadan himoya qilmaydi (repo egasining o'zi yomon niyatli bo'lsa). Yo'nalish: 3-bo'lim, tuzoqlar va "Nima uchun shunday".

12. **Hold and pin.** (VM) `nginx` ni o'rnatib `apt-mark hold` qiling. `apt-mark showhold` va `sudo apt upgrade --dry-run` (yoki `-s`) chiqishida ushlangan paket qanday ko'rsatiladi, `dpkg -l nginx` da birinchi ustun nima? `unhold` qiling. Keyin `/etc/apt/preferences.d/` ga Docker repo'sidagi barcha paketlarga manfiy prioritet beradigan pin yozing (`Pin: origin`), `apt-cache policy docker-ce` da prioritet va `Candidate` qanday o'zgarganini pin'dan oldingi chiqish bilan yonma-yon ko'rsating. Pin faylini ish papkasiga saqlang. Yo'nalish: 4-bo'lim.

13. **Unattended upgrades.** (VM) `systemctl list-timers 'apt-*'`, `/etc/apt/apt.conf.d/20auto-upgrades` va `50unattended-upgrades` dagi `Allowed-Origins` blokini o'qing: qaysi manbalardan avtomatik yangilanadi, avtomatik reboot yoqilganmi? `sudo unattended-upgrade --dry-run --debug` chiqishining muhim qismini yozing. `/var/run/reboot-required` bormi? Production DB serverida bu mexanizmni qanday sozlagan bo'lardingiz (nima avtomatik, nima qo'lda, qachon reboot), 5–6 gapda yozing. Yo'nalish: 5-bo'lim.

### C. dnf va rpm

14. **dnf basics.** (R) `dnf repolist`, keyin `dnf install -y nginx`. `rpm -qi nginx`, `rpm -ql nginx | grep -E 'etc|systemd'`, `rpm -qf /usr/sbin/nginx`, `rpm -q --scripts nginx` ni oling. Paketning to'liq nomidagi arxitektura qismi nima (Zorin va Mac'da farqi)? `dnf history` va `dnf history info` oxirgi tranzaksiya uchun nima ko'rsatadi? `dnf history undo` bilan o'rnatishni bekor qiling va `rpm -q nginx` bilan tekshiring. Yo'nalish: 6-bo'lim, "dnf" va "rpm".

15. **provides and repos.** (R) Minimal konteynerda `dig`, `ps`, `ip` kabi buyruqlar bo'lmasligi mumkin (`command -v` bilan tekshiring). `dnf provides` bilan ularni qaysi paket berishini toping va yo'qlarini o'rnating. `/etc/yum.repos.d/rocky.repo` dan `[baseos]` blokini o'qing: `gpgcheck`, `gpgkey`, `enabled`, `mirrorlist` nima qiladi, `$basearch` sizning mashinangizda nimaga aylanadi? `dnf install -y epel-release` dan keyin `dnf repolist` va `/etc/yum.repos.d/` qanday o'zgardi? Yo'nalish: 6-bo'lim, "Repo'lar va imzo".

16. **check-update exit code.** (R) `dnf check-update; echo $?` ni bajaring va kodni izohlang. `task_16.sh` yozing: `dnf check-update` exit code'iga qarab "yangilanish bor: N ta paket", "yangilanish yo'q" yoki "xato" deb chop etsin va mos exit code qaytarsin. `shellcheck` toza bo'lsin. Skriptni konteynerga `docker run -v` bilan ulab sinang (host'da yozasiz, konteynerda ishlatasiz; ikkala mashinada bir xil). Yo'nalish: 6-bo'lim, `dnf` jadvali; 5 va 6-darslar (exit code, `case`).

17. **Same task, two families.** Bir xil natijani ikkala konteynerda (U va R) oling va buyruqlarni yonma-yon jadval qilib yozing: (a) web server o'rnatish (paket nomlariga e'tibor bering), (b) uning konfiguratsiya fayllari ro'yxati, (c) `/etc/os-release` faylini qaysi paket o'rnatgani, (d) o'rnatilgan paketlar soni, (e) keshni tozalash va tozalashdan oldin/keyin kesh katalogi hajmi (`du -sh`). Yo'nalish: 7-bo'lim.

### D. Yakuniy

18. **snap on your machine.** (VM) `snap list` ni oling. Bo'sh bo'lsa `sudo snap install hello-world` bilan sinov snap'ini o'rnating va qayta oling: sizning snap'ingiz bilan birga yana nima o'rnatildi va nima uchun? `df -hT | grep -E 'squashfs|loop'` ni oling va har snap nima uchun alohida mount ko'rinishida turganini izohlang. `snap info --verbose hello-world` dan `channels` va `confinement` ni toping. Bitta dasturni `apt`, `snap` va konteynerdan o'rnatishning har biri uchun bitta afzallik va bitta kamchilik yozing. Host bo'yicha bir gap: Zorin'da `snap list` va `snap info multipass` (o'qiydigan buyruqlar), Mac'da `brew list --cask` nima ko'rsatadi, Multipass har birida qanday o'rnatilgan? Oxirida `sudo snap remove hello-world`. Yo'nalish: 8-bo'lim.

19. **Package audit script.** `task_19.sh` yozing: Debian yoki RHEL oilasida ekanini `/etc/os-release` dagi `ID`/`ID_LIKE` orqali aniqlaydi va mos buyruqlar bilan qisqa hisobot chiqaradi: distributiv nomi va versiyasi, arxitektura, o'rnatilgan paketlar soni, mavjud yangilanishlar soni, ushlab qo'yilgan paketlar, standart bo'lmagan (uchinchi tomon) repo'lar ro'yxati, reboot kerakmi (Debian oilasida fayl orqali). Skript hech narsani o'zgartirmaydi va root talab qilmaydigan buyruqlar bilan cheklanadi (yangilanishlar sonini mavjud keshdan oladi). `shellcheck` toza. VM'da va `rockylinux:9` konteynerida ishga tushirib, ikkala chiqishni README'ga qo'ying. Skriptda `amd64` yoki `x86_64` qo'lda yozilmagan bo'lsin: u ikkala mashinada ishlashi kerak. Yo'nalish: 7-bo'lim jadvali, 1-dars (`ID_LIKE`), 5 va 6-darslar.

20. **Cleanup.** (VM) Docker repo fayli, kaliti va pin faylini o'chiring, `nginx` ni `purge` qiling, `apt-mark showhold` bo'sh ekanini tekshiring, `sudo apt update` xatosiz va ogohlantirishsiz o'tishini ko'rsating. `sudo apt autoremove --purge` va `sudo apt clean` dan oldin va keyin `df -h /` va `du -sh /var/cache/apt` ni solishtiring. Ikkala mashinada ham ishlagan bo'lsangiz, tozalashni ikkala VM'da bajaring. Yo'nalish: 5-bo'lim "Tozalash", "Birga bajaramiz" 8-qadam.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi (host'da).
2. VM'da uchinchi tomon repo'lari, kalitlar, pin va `hold` qolmagan (`ls /etc/apt/sources.list.d/ /etc/apt/keyrings/ /etc/apt/preferences.d/`, `apt-mark showhold`); test image va konteynerlar o'chirilgan (`docker ps -a`, `docker images`).
3. README'da har vazifa uchun buyruq, natija va izoh bor, muhit (VM, U, R, H) va mashina (Zorin yoki Mac) ko'rinadi; host'da hech narsa o'rnatilmagan.
4. Ish papkasida `Dockerfile`, `Dockerfile.naive`, `task_16.sh`, `task_19.sh`, repo va pin fayllari nusxasi bor; kalit fayllari yo'q.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `apt` va `dpkg` (`dnf` va `rpm`) orasidagi vazifa taqsimoti qanday?
- `.deb` paket ichida qaysi uch narsa bor va maintainer skript kim nomidan bajariladi? Bu `npm` dagi `postinstall` dan nimasi bilan xavfliroq?
- `apt update` aynan nima qiladi va nima uchun `dnf` da alohida shunday qadam yo'q?
- `apt-cache policy` chiqishidagi `Installed`, `Candidate` va `500`, `100` raqamlari nima?
- Paket HTTP mirror'dan kelsa ham nima uchun uni yo'lda almashtirib bo'lmaydi? Zanjirni bosqichma-bosqich ayting.
- `signed-by` `apt-key add` dan nimasi bilan xavfsizroq va u nimadan himoya qilmaydi?
- Manba qatorida nima uchun `arch=amd64` emas, `arch=$(dpkg --print-architecture)` yoziladi?
- `apt remove` va `apt purge` farqi nima?
- `apt-mark hold` qachon kerak va uning narxi nima? Pinning undan nimasi bilan farq qiladi?
- Dockerfile'da `apt-get update` va `install` nima uchun bitta `RUN` da yoziladi?
- Xavfsizlik yangilanishi o'rnatildi. Zaiflik yopilgan deyish uchun yana nima tekshirilishi kerak?
- Ubuntu uchun yozilgan o'rnatish skriptini Rocky'ga ko'chirganda qaysi farqlar uni buzadi? Kamida uchta.
- `df` da `100%` to'la `loop` qurilmalar nima va nima uchun ular muammo emas?
