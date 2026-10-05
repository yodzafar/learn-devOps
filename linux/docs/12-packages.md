# 12-dars: Paketlarni boshqarish

Maqsad: serverga dastur qanday o'rnatilishi, qayerdan kelishi va unga nima uchun ishonish mumkinligini tushunish. `npm` dan tanish tushunchalar bor (registry, versiya, dependency), lekin tizim paketlarida farqlar muhim: paketlar root sifatida o'rnatiladi va o'rnatish paytida skript bajaradi, manba GPG imzo bilan tekshiriladi, bitta paketning bitta versiyasi butun tizimga o'rnatiladi. Ikki oilani ko'rasiz: Debian/Ubuntu (`apt`, `dpkg`) va RHEL/Rocky/Fedora (`dnf`, `rpm`). Bu bilim Dockerfile yozishda (har ikkinchi qator `apt-get install`), Ansible'da (`apt`/`dnf` modullari) va server yangilanishlarini rejalashtirishda kerak bo'ladi.

Taxminiy vaqt: 2 kun (siz uchun). `apt install` tanish, diqqatni quyidagilarga qarating: `apt` va `dpkg` (`dnf` va `rpm`) qatlamlari, repository va imzo zanjiri, uchinchi tomon repo'sini `signed-by` bilan qo'shish, `hold` va pinning, `unattended-upgrades`, Dockerfile'dagi `apt-get` naqshi.

## Laboratoriya

- `apt` vazifalari: Multipass VM (`multipass shell lab`) yoki bir martalik konteyner `docker run --rm -it ubuntu:24.04 bash`. Konteynerda siz root (`sudo` yozilmaydi) va paket ro'yxati bo'sh, avval `apt update`.
- `dnf` vazifalari: `docker run --rm -it rockylinux:9 bash`.
- `unattended-upgrades` va servis o'rnatadigan paketlar (systemd kerak) faqat VM'da.
- Ish mashinasida faqat o'qiydigan buyruqlar: `apt list`, `apt-cache policy`, `dpkg -l`, `dpkg -S`, `apt-mark showhold`, `snap list`. Ish mashinasida vazifa uchun paket o'rnatmang va repo qo'shmang.
- Tozalash: konteynerlar `--rm` bilan o'zi o'chadi; VM'da dars uchun qo'shilgan repo fayllari, kalitlar va `hold` belgilari olib tashlanadi (oxirgi vazifada).

---

## 1. Paket va paket menejeri

Paket bu arxiv: fayllar (binary, kutubxona, konfiguratsiya, unit fayl, man sahifa), metama'lumot (nom, versiya, arxitektura, bog'liqliklar) va o'rnatish/o'chirish paytida root sifatida bajariladigan skriptlar (`postinst`, `prerm` va boshqalar; servis akkauntni yaratish, systemd unit'ni yoqish shular ichida).

Ikki qatlam bor:

| Qatlam | Debian oilasi | RHEL oilasi | Vazifasi |
|--------|---------------|-------------|----------|
| Past | `dpkg` (`.deb`) | `rpm` (`.rpm`) | bitta paket faylini o'rnatish, o'chirish, o'rnatilganlar bazasi. Bog'liqlikni tekshiradi, lekin o'zi yuklab olmaydi |
| Yuqori | `apt` | `dnf` | repository'lardan qidirish, bog'liqliklarni yechish, yuklash, imzoni tekshirish, keyin past qatlamni chaqirish |

`npm` dan asosiy farqlar: paketlar global (har loyihaga alohida `node_modules` yo'q), bir vaqtda odatda bitta versiya, versiyalarni distributiv belgilaydi (Ubuntu 24.04 butun umri davomida paketning asosiy versiyasini saqlab, faqat xavfsizlik tuzatishlarini ko'chiradi). Yangiroq versiya kerak bo'lsa: uchinchi tomon repo'si, konteyner yoki til menejeri.

## 2. Debian oilasi: apt va dpkg

### apt

| Buyruq | Nima qiladi |
|--------|-------------|
| `apt update` | repo'lardan paketlar **ro'yxatini** yangilaydi. Hech narsa o'rnatmaydi |
| `apt upgrade` | o'rnatilgan paketlarni yangilaydi, hech narsani o'chirmaydi |
| `apt full-upgrade` | yangilaydi, kerak bo'lsa paketlarni o'chiradi ham |
| `apt install nginx` | o'rnatish (bog'liqliklari bilan) |
| `apt install nginx=<versiya>` | aniq versiya (`apt-cache madison nginx` dagi to'liq satr) |
| `apt install ./file.deb` | lokal fayl, bog'liqliklarini repo'dan tortadi |
| `apt remove nginx` | o'chiradi, `/etc` dagi konfiguratsiya qoladi |
| `apt purge nginx` | konfiguratsiyasi bilan o'chiradi |
| `apt autoremove` | boshqa paket uchun avtomatik o'rnatilib, endi keraksiz bo'lganlarni o'chiradi |
| `apt search`, `apt show nginx` | qidirish, tavsif |
| `apt list --installed`, `apt list --upgradable` | ro'yxatlar |
| `apt-cache policy nginx` | o'rnatilgan va nomzod versiya, qaysi repo'dan, prioritet |

**Tuzoq: `apt update` siz `install`.** Lokal ro'yxat eskirgan bo'lsa `apt` repo'da allaqachon yo'q versiyani so'raydi va `404 Not Found` oladi. Yangi konteyner va yangi VM'da birinchi buyruq har doim `apt update`.

### apt va apt-get

`apt` interaktiv ishlatish uchun (progress, ranglar), uning chiqish formati barqaror deb kafolatlanmagan, pipe'da o'zi ogohlantiradi: `WARNING: apt does not have a stable CLI interface. Use with caution in scripts.` Skript, Dockerfile va CI'da `apt-get` va `apt-cache` ishlatiladi.

Avtomatlashtirishda savol so'ralmasligi kerak:

```
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
```

`-y` tasdiqlarga "ha", `DEBIAN_FRONTEND=noninteractive` paket sozlash dialoglarini (masalan `tzdata` vaqt zonasini so'rashi) o'chiradi, `--no-install-recommends` "tavsiya etilgan" qo'shimcha paketlarni o'rnatmaydi.

Dockerfile naqshi: `update`, `install` va ro'yxatni tozalash bitta `RUN` da. Alohida `RUN apt-get update` qatlami keshlanib qoladi va keyingi `install` eskirgan ro'yxat bilan ishlaydi:

```
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
```

### dpkg

| Buyruq | Savol |
|--------|-------|
| `dpkg -l` / `dpkg -l 'nginx*'` | nima o'rnatilgan (birinchi ustun: `ii` o'rnatilgan, `rc` o'chirilgan, konfiguratsiyasi qolgan) |
| `dpkg -L nginx-common` | bu paket qaysi fayllarni o'rnatgan |
| `dpkg -S /usr/bin/curl` | bu fayl qaysi paketdan |
| `dpkg -s curl` | paket holati va metama'lumoti |
| `dpkg -i file.deb` | faylni o'rnatish (bog'liqliklarni yuklamaydi) |
| `dpkg --configure -a` | uzilib qolgan o'rnatishni tugatish |

Tarix: `/var/log/apt/history.log` (qaysi buyruq, qachon, nima o'zgardi) va `/var/log/dpkg.log`. "Kecha ishlardi, bugun ishlamayapti" bo'lganda birinchi qaraladigan joylardan.

**Tuzoq: lock xatosi.** `Could not get lock /var/lib/dpkg/lock-frontend` boshqa `apt` jarayoni ishlayotganini bildiradi (ko'pincha yangi VM'da fon yangilanishi). Lock faylni o'chirmang, jarayon tugashini kuting (`ps aux | grep -E 'apt|dpkg'`). O'rnatish o'rtasida uzilgan bo'lsa: `sudo dpkg --configure -a`, keyin `sudo apt --fix-broken install`.

## 3. Repository va ishonch zanjiri

### Manba ro'yxati

Ubuntu 24.04 da asosiy repo'lar deb822 formatida, `/etc/apt/sources.list.d/ubuntu.sources`:

```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Eski bir qatorli format (`.list` fayllarda) hali ham keng tarqalgan: `deb [signed-by=...] URL suite component`.

| Tushuncha | Ma'nosi |
|-----------|---------|
| Suite | reliz va uning oqimi: `noble` (reliz paytidagi holat), `noble-updates` (tuzatishlar), `noble-security` (xavfsizlik), `noble-backports` |
| Component | `main` (Canonical qo'llab-quvvatlaydi, erkin), `universe` (hamjamiyat), `restricted` va `multiverse` (erkin bo'lmagan) |
| Signed-By | shu repo'ni tekshirish uchun ishlatiladigan kalit fayli |

### Imzo qanday ishlaydi

1. Repo egasi `InRelease` faylini o'z private kaliti bilan imzolaydi. Bu faylda paket indekslarining (`Packages`) hash'lari bor.
2. `Packages` indeksida har `.deb` faylning hash'i bor.
3. `apt update` `InRelease` imzosini `Signed-By` dagi public kalit bilan tekshiradi, `apt install` yuklangan `.deb` hash'ini indeks bilan solishtiradi.

Shuning uchun repo oddiy HTTP mirror orqali kelsa ham paketni yo'lda almashtirib bo'lmaydi. Ishonchning ildizi diskdagi public kalit: uni qayerdan va qanday olganingiz butun zanjirning eng zaif nuqtasi.

### Uchinchi tomon repo'sini to'g'ri qo'shish

Docker, PostgreSQL, HashiCorp, Kubernetes kabi loyihalar o'z repo'sini yuritadi. Namuna (Docker'ning rasmiy yo'riqnomasidagi qadamlar):

```
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
```

Uch qoida:

- Kalit alohida faylga, `/etc/apt/keyrings/` ga (yoki paket o'rnatgan bo'lsa `/usr/share/keyrings/`), HTTPS orqali rasmiy manzildan.
- Repo ta'rifida `signed-by=` shu faylga ishora qiladi. Natijada bu kalit faqat shu repo'ni tasdiqlay oladi.
- Har repo o'z faylida, `/etc/apt/sources.list.d/` da. O'chirish oson, nima qo'shilgani ko'rinib turadi.

**Tuzoq: `apt-key add` va `trusted.gpg.d`.** Eski yo'riqnomalardagi `curl ... | sudo apt-key add -` kalitni global ishonchli qiladi: u istalgan repo'ni, shu jumladan Ubuntu'ning o'z paketlarini imzolashga yaroqli bo'lib qoladi. Bitta uchinchi tomon kaliti o'g'irlansa, u orqali `openssl` ni ham almashtirish mumkin. `apt-key` eskirgan deb e'lon qilingan; har doim `signed-by`.

**Tuzoq: `curl | sudo bash` o'rnatuvchilari.** Bu skript root sifatida istalgan narsani qiladi va odatda ichida repo qo'shadi. Avval yuklab o'qing, yoki qadamlarni qo'lda bajaring. `[trusted=yes]` va `--allow-unauthenticated` imzo tekshiruvini o'chiradi, production'da ishlatilmaydi.

Uchinchi tomon repo'si tizim paketlarini almashtira olishini ham hisobga oling: u xuddi shu nomli yangiroq paketni taklif qilsa, `apt upgrade` uni o'rnatadi. Bunga qarshi vosita pinning.

## 4. Versiyani ushlab turish

### hold

```
$ sudo apt-mark hold docker-ce
$ apt-mark showhold
$ sudo apt-mark unhold docker-ce
```

Ushlab qo'yilgan paket `apt upgrade` da yangilanmaydi. Ma'lumotlar bazasi, container runtime, `kubelet`/`kubeadm` kabi yangilanishi rejali bo'lishi kerak komponentlar uchun ishlatiladi. Narxi: xavfsizlik tuzatishlari ham kelmaydi, shuning uchun `hold` vaqtinchalik qaror va hujjatlashtirilishi kerak.

### Pinning

Nozikroq boshqaruv `/etc/apt/preferences.d/` dagi fayllar bilan:

```
Package: nginx*
Pin: version 1.24.*
Pin-Priority: 1001
```

Har paket versiyasi prioritetga ega (`apt-cache policy` ko'rsatadi): repo'dagilar standart 500, o'rnatilgan versiya 100. Eng yuqori prioritetli versiya nomzod bo'ladi. 1000 dan yuqori prioritet downgrade'ga ham ruxsat beradi, manfiy prioritet versiyani butunlay taqiqlaydi. `Pin: origin download.docker.com` yoki `Pin: release a=noble-backports` bilan butun manbaga prioritet berish mumkin.

Mavjud versiyalar: `apt-cache madison nginx` yoki `apt list -a nginx`.

## 5. Avtomatik yangilanish va tozalash

### unattended-upgrades

Xavfsizlik yangilanishlarini qo'lsiz o'rnatadi. Ubuntu Server'da standart o'rnatilgan va yoqilgan.

| Fayl | Nima |
|------|------|
| `/etc/apt/apt.conf.d/20auto-upgrades` | yoqilganmi: `APT::Periodic::Update-Package-Lists "1";` va `APT::Periodic::Unattended-Upgrade "1";` (kunlarda oraliq) |
| `/etc/apt/apt.conf.d/50unattended-upgrades` | nima yangilanadi (`Allowed-Origins`, standart holatda security), qora ro'yxat (`Package-Blacklist`), avtomatik reboot (`Automatic-Reboot`, standart `false`) |
| `/var/log/unattended-upgrades/` | nima qilingani |

Ishga tushirishni `apt-daily.timer` va `apt-daily-upgrade.timer` bajaradi (11-dars). Quruq sinov: `sudo unattended-upgrade --dry-run --debug`.

Yangilanish o'rnatilishi uning ishlayotganini anglatmaydi: kernel yangilanishi reboot'ni, kutubxona yangilanishi (`openssl`, `glibc`) undan foydalanayotgan servislarni qayta ishga tushirishni talab qiladi. Reboot kerakligini `/var/run/reboot-required` fayli bildiradi, servislarni `needrestart` tekshiradi.

### Tozalash

| Buyruq | Nimani bo'shatadi |
|--------|-------------------|
| `apt clean` | yuklangan `.deb` fayllar keshi (`/var/cache/apt/archives/`) |
| `apt autoremove --purge` | keraksiz bog'liqliklar, shu jumladan eski kernel'lar |
| `rm -rf /var/lib/apt/lists/*` | paket ro'yxatlari (faqat image qurishda, keyingi `apt update` qayta yuklaydi) |

`/boot` alohida kichik bo'lim bo'lgan serverlarda eski kernel'lar to'planib joyni tugatadi va navbatdagi yangilanish yarim yo'lda yiqiladi: `autoremove` muntazam bajarilishi kerak.

## 6. RHEL oilasi: dnf va rpm

RHEL 8 dan beri `yum` buyrug'i `dnf` ga symlink: eski yo'riqnomalardagi `yum install` aynan `dnf install`.

| Buyruq | Nima qiladi |
|--------|-------------|
| `dnf install nginx`, `dnf remove nginx` | o'rnatish, o'chirish |
| `dnf upgrade` | hamma paketni yangilash. Alohida "update" qadami yo'q: metama'lumot keshi eskirgan bo'lsa o'zi yangilaydi |
| `dnf check-update` | yangilanishlar ro'yxati; exit code 100 "yangilanish bor", 0 "yo'q" (skriptda qulay) |
| `dnf search`, `dnf info nginx` | qidirish, tavsif |
| `dnf list installed`, `dnf list --showduplicates nginx` | o'rnatilganlar, mavjud versiyalar |
| `dnf provides /usr/bin/dig` | bu fayl yoki buyruqni qaysi paket beradi (o'rnatilmagan bo'lsa ham) |
| `dnf repolist`, `dnf repolist --all` | yoqilgan va hamma repo'lar |
| `dnf history`, `dnf history info N`, `dnf history undo N` | tranzaksiyalar tarixi va bekor qilish |
| `dnf clean all`, `dnf makecache` | keshni tozalash va qayta qurish |

`rpm` past qatlam:

| Buyruq | Savol |
|--------|-------|
| `rpm -qa` | nima o'rnatilgan |
| `rpm -qi bash` | paket ma'lumoti |
| `rpm -ql bash` | paket fayllari |
| `rpm -qf /usr/bin/bash` | fayl qaysi paketdan |
| `rpm -q --scripts bash` | o'rnatish skriptlari |
| `rpm -K file.rpm` | fayl imzosini tekshirish |

### Repo'lar

Ta'riflar `/etc/yum.repos.d/*.repo` da, INI formatida:

```
[baseos]
name=Rocky Linux $releasever - BaseOS
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=BaseOS-$releasever$rltype
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
```

Debian oilasidan farqi: bu yerda odatda har `.rpm` paketning o'zi imzolangan va `gpgcheck=1` shuni tekshiradi. `gpgkey` da ko'rsatilgan kalit birinchi ishlatilganda import qilinadi (tasdiq so'raydi). `gpgcheck=0` imzo tekshiruvini o'chiradi, uchinchi tomon `.repo` faylini qo'shishdan oldin shu qatorga qarang.

Asosiy repo'lar: `baseos` (tizim yadrosi), `appstream` (dasturlar), `extras`. Qo'shimcha paketlar uchun hamjamiyat repo'si EPEL: `dnf install -y epel-release`. Uchinchi tomon repo'si `.repo` faylini `/etc/yum.repos.d/` ga qo'yish yoki `dnf config-manager --add-repo URL` (`dnf-plugins-core` paketi) bilan qo'shiladi.

Versiyani ushlash: `dnf install -y python3-dnf-plugin-versionlock`, keyin `dnf versionlock add nginx`, `dnf versionlock list`, `dnf versionlock delete nginx`. Avtomatik yangilanish: `dnf-automatic` paketi va uning timer'i.

## 7. apt va dnf yonma-yon

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
| Paket nomlari | `apache2`, `libssl-dev`, `openssh-server` | `httpd`, `openssl-devel`, `openssh-server` |
| O'rnatilgan servis | odatda darhol ishga tushadi va `enable` bo'ladi | o'rnatiladi, lekin ishga tushmaydi: `systemctl enable --now` kerak |

Oxirgi ikki qator ikki oila orasida ko'chirilgan skript va playbook'lar buzilishining eng ko'p sababi.

## 8. snap va flatpak (qisqa)

An'anaviy paketlar tizim kutubxonalarini bo'lishadi. Universal formatlar dasturni bog'liqliklari bilan birga o'raydi va cheklangan muhitda ishga tushiradi.

| | snap | flatpak |
|---|------|---------|
| Kim | Canonical, Ubuntu'da standart | hamjamiyat, Fedora va boshqalarda standart |
| Do'kon | Snap Store (yagona, markazlashgan) | Flathub va boshqa remote'lar |
| Yo'nalish | desktop, server va CLI asboblari | asosan desktop dasturlar |
| Buyruqlar | `snap list`, `snap install X`, `snap refresh`, `snap remove X` | `flatpak list`, `flatpak install`, `flatpak update` |
| Yangilanish | avtomatik, fon rejimida | qo'lda yoki desktop orqali |

Serverda bilish kerak bo'lganlari: har snap squashfs image sifatida mount qilinadi, shuning uchun `df` va `lsblk` da `loop` qurilmalar ko'rinadi (13-dars); snap'lar o'zi yangilanadi (`snap refresh --hold` bilan to'xtatiladi); `--classic` rejimidagi snap cheklovsiz ishlaydi. Multipass ham snap sifatida tarqatiladi. Server dasturlari uchun production'da ko'proq `apt`/`dnf` paketlari va konteynerlar ishlatiladi.

## Tuzoqlar

- `apt update` siz `apt install`: eskirgan ro'yxat, `404`. Dockerfile'da `update` va `install` ni alohida `RUN` ga ajratish ham shu xatoning bir ko'rinishi.
- Kalitni `apt-key add` yoki `trusted.gpg.d` orqali global ishonchli qilish. Har doim `signed-by` va alohida kalit fayli.
- Internetdan topilgan `curl | sudo bash` ni o'qimasdan ishga tushirish; `gpgcheck=0`, `[trusted=yes]` bilan imzoni o'chirish.
- Production serverda `apt upgrade` ni nima yangilanishini ko'rmasdan bajarish. Avval `apt list --upgradable`, muhim komponentlar `hold` da, yangilanish avval staging'da.
- `hold` qo'yib unutish: paket yillab xavfsizlik tuzatishlarisiz qoladi.
- Yangilanishdan keyin servisni qayta ishga tushirmaslik yoki reboot qilmaslik: diskda yangi versiya, xotirada eski zaif kod ishlayapti.
- Skriptda `apt` (barqaror bo'lmagan chiqish) va `-y`/`DEBIAN_FRONTEND` siz chaqiruv: CI dialog kutib osilib qoladi.
- Lock xatosida lock faylni o'chirish. Ishlayotgan `dpkg` bilan parallel yozish paket bazasini buzadi.
- Debian uchun yozilgan qo'llanmani RHEL'da (yoki teskarisi) paket nomlari va "servis o'zi ishga tushadi" farqini hisobga olmasdan qo'llash.
- Tizim Python'iga `sudo pip install` bilan paket o'rnatish: `apt` boshqaradigan fayllar ustidan yoziladi. Til paketlari uchun virtual muhit yoki konteyner.

## Manbalar

- https://manpages.ubuntu.com/manpages/noble/en/man5/sources.list.5.html – sources.list(5): deb822 formati, `Signed-By`
- https://manpages.ubuntu.com/manpages/noble/en/man5/apt_preferences.5.html – apt_preferences(5): pinning va prioritetlar
- https://wiki.debian.org/DebianRepository/UseThirdParty – uchinchi tomon repo'sini to'g'ri qo'shish qoidalari (majburiy)
- https://documentation.ubuntu.com/server/explanation/software/third-party-repository-usage/ – Ubuntu Server: third party repository usage
- https://documentation.ubuntu.com/server/how-to/software/automatic-updates/ – Ubuntu Server: automatic updates
- https://docs.docker.com/engine/install/ubuntu/ – `signed-by` bilan repo qo'shishning amaliy namunasi
- https://www.debian.org/doc/manuals/debian-reference/ch02.en.html – Debian Reference, 2-bob: package management
- https://dnf.readthedocs.io/en/latest/command_ref.html – DNF command reference
- https://docs.rockylinux.org/books/admin_guide/13-softwares/ – Rocky Linux Admin Guide: software management
- https://snapcraft.io/docs – snap hujjatlari
- https://docs.flatpak.org/en/latest/ – flatpak hujjatlari

---

## Vazifalar

Ish papkasi: `linux/12-packages/` (`make new m=linux n=12 name=packages` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`Dockerfile`, skript, repo fayli nusxasi) yoniga saqlang. Har vazifada muhit ko'rsatilgan: WS (ish mashinasi, faqat o'qish), VM, U (`ubuntu:24.04` konteyner), R (`rockylinux:9` konteyner).

### A. apt va dpkg

1. **Inventory.** (WS) Nechta paket o'rnatilgan (`dpkg -l` yoki `apt list --installed` va `wc -l`)? `apt-mark showmanual | wc -l` va `apt-mark showauto | wc -l` ni oling: "manual" va "auto" farqi nima va `autoremove` bunga qanday tayanadi? `apt list --upgradable` nechta paket ko'rsatadi?

2. **Which package owns it.** (WS) `curl`, `ls`, `systemctl` va `docker` binary'lari qaysi paketdan ekanini `dpkg -S` bilan toping (yo'lni `command -v` bilan, symlink bo'lsa `readlink -f` bilan aniqlang). Shu paketlardan birining fayllar ro'yxatidan konfiguratsiya va unit fayllarini (`/etc`, `systemd`) `grep` bilan ajrating.

3. **Stale lists.** (U) Yangi konteynerda `apt update` siz `apt install -y curl` ni bajaring: xato nima? `ls /var/lib/apt/lists/` ni `apt update` dan oldin va keyin solishtiring. `apt update` chiqishidagi `Get:`, `Hit:` qatorlari va `InRelease` so'zi nimani bildirishini yozing.

4. **Install lifecycle.** (VM) `nginx` ni o'rnating. `apt-cache policy nginx`, `dpkg -L nginx-common | head`, `systemctl is-enabled nginx` ni oling. `/etc/nginx/nginx.conf` ga izoh qatori qo'shing. `apt remove nginx nginx-common` dan keyin fayl bormi, `dpkg -l | grep nginx` da holat ustuni nima? `apt purge` dan keyin-chi? `/var/log/apt/history.log` dan shu amallaringizni toping.

5. **Dependencies.** (U) `apt-get install -y nginx` va `apt-get install -y --no-install-recommends nginx` ni ikki alohida konteynerda `--dry-run` (yoki `-s`) bilan bajarib, o'rnatiladigan paketlar sonini solishtiring. `apt-cache depends nginx` va `apt-cache rdepends nginx-common` nimani ko'rsatadi? `Depends` va `Recommends` farqini yozing.

6. **Slim Dockerfile.** `Dockerfile` yozing: `ubuntu:24.04` asosida `curl` va `ca-certificates` o'rnatilgan image, 2-bo'limdagi naqsh bo'yicha. Ikkinchi variantni (`Dockerfile.naive`) ataylab yomon yozing: `update` va `install` alohida `RUN`, `--no-install-recommends` va tozalashsiz. Ikkalasini build qilib `docker images` da hajmini solishtiring. `docker history` bilan qaysi qatlam qancha joy olganini ko'rsating. Test image'larni o'chiring.

7. **Interactive prompt.** (U) `apt-get install tzdata` ni `-y` va `DEBIAN_FRONTEND` siz bajaring: nima so'radi? CI'da bu nimaga olib keladi? To'g'ri variantni yozing.

### B. Repository va imzo

8. **Read the sources.** (VM) `/etc/apt/sources.list.d/ubuntu.sources` ni o'qing: nechta manba bloki, qaysi suite va component'lar, `Signed-By` qaysi fayl? `apt-cache policy` (argumentsiz) chiqishidagi qatorlarni shu fayl bilan bog'lang. `curl` paketi qaysi suite'dan kelganini `apt-cache policy curl` dan aniqlang.

9. **Add a third-party repo.** (VM) Docker'ning rasmiy repo'sini 3-bo'limdagi qadamlar bilan qo'shing (https://docs.docker.com/engine/install/ubuntu/ bilan solishtirib). Har qadam nima qilishini README'da izohlang: `install -d`, `curl -fsSL` flag'lari, `signed-by`, `arch=`, `$VERSION_CODENAME`. `apt update` dan keyin `apt-cache policy docker-ce` nima ko'rsatadi? Mavjud versiyalarni `apt-cache madison docker-ce` bilan chiqaring. Paketni o'rnatish shart emas.

10. **Break the signature.** (VM) Docker repo fayli va kalitdan zaxira nusxa oling. Birinchi tajriba: `signed-by` yo'lini mavjud bo'lmagan faylga o'zgartiring va `sudo apt update` qiling. Ikkinchi tajriba: `signed-by` ni Ubuntu'ning o'z kalitiga (`/usr/share/keyrings/ubuntu-archive-keyring.gpg`) qarating. Har ikki xato xabarini yozing (`NO_PUBKEY` va shunga o'xshash so'zlarni qidiring) va `apt` bu holatda repo bilan nima qilishini izohlang. Tiklang.

11. **Why not apt-key.** `man apt-key` (VM) dagi DEPRECATION bo'limini va Debian wiki'dagi UseThirdParty sahifasini o'qing. O'z so'zingiz bilan 4–5 gapda yozing: global ishonchli kalit qanday hujumga yo'l ochadi, `signed-by` buni qanday cheklaydi, va u nimadan himoya qilmaydi (repo egasining o'zi yomon niyatli bo'lsa).

12. **Hold and pin.** (VM) `nginx` ni o'rnatib `apt-mark hold` qiling. `apt-mark showhold` va `sudo apt upgrade --dry-run` (yoki `-s`) chiqishida ushlangan paket qanday ko'rsatiladi? `unhold` qiling. Keyin `/etc/apt/preferences.d/` ga Docker repo'sidagi barcha paketlarga manfiy prioritet beradigan pin yozing (`Pin: origin`), `apt-cache policy docker-ce` da prioritet va `Candidate` qanday o'zgarganini ko'rsating. Pin faylini ish papkasiga saqlang.

13. **Unattended upgrades.** (VM) `systemctl list-timers 'apt-*'`, `/etc/apt/apt.conf.d/20auto-upgrades` va `50unattended-upgrades` dagi `Allowed-Origins` blokini o'qing: qaysi manbalardan avtomatik yangilanadi, avtomatik reboot yoqilganmi? `sudo unattended-upgrade --dry-run --debug` chiqishining muhim qismini yozing. `/var/run/reboot-required` bormi? Production DB serverida bu mexanizmni qanday sozlagan bo'lardingiz (nima avtomatik, nima qo'lda, qachon reboot), 5–6 gapda yozing.

### C. dnf va rpm

14. **dnf basics.** (R) `dnf repolist`, keyin `dnf install -y nginx`. `rpm -qi nginx`, `rpm -ql nginx | grep -E 'etc|systemd'`, `rpm -qf /usr/sbin/nginx`, `rpm -q --scripts nginx` ni oling. `dnf history` va `dnf history info` oxirgi tranzaksiya uchun nima ko'rsatadi? `dnf history undo` bilan o'rnatishni bekor qiling va `rpm -q nginx` bilan tekshiring.

15. **provides and repos.** (R) Minimal konteynerda `dig`, `ps`, `ip` kabi buyruqlar bo'lmasligi mumkin (`command -v` bilan tekshiring). `dnf provides` bilan ularni qaysi paket berishini toping va yo'qlarini o'rnating. `/etc/yum.repos.d/rocky.repo` dan `[baseos]` blokini o'qing: `gpgcheck`, `gpgkey`, `enabled`, `mirrorlist` nima qiladi? `dnf install -y epel-release` dan keyin `dnf repolist` va `/etc/yum.repos.d/` qanday o'zgardi?

16. **check-update exit code.** (R) `dnf check-update; echo $?` ni bajaring va kodni izohlang. `task_16.sh` yozing: `dnf check-update` exit code'iga qarab "yangilanish bor: N ta paket", "yangilanish yo'q" yoki "xato" deb chop etsin va mos exit code qaytarsin. `shellcheck` toza bo'lsin. Skriptni konteynerga `docker run -v` bilan ulab sinang.

17. **Same task, two families.** Bir xil natijani ikkala konteynerda (U va R) oling va buyruqlarni yonma-yon jadval qilib yozing: (a) web server o'rnatish (paket nomlariga e'tibor bering), (b) uning konfiguratsiya fayllari ro'yxati, (c) `/etc/os-release` faylini qaysi paket o'rnatgani, (d) o'rnatilgan paketlar soni, (e) keshni tozalash va tozalashdan oldin/keyin kesh katalogi hajmi (`du -sh`).

### D. Yakuniy

18. **snap on your machine.** (WS) `snap list` (o'rnatilgan bo'lsa) va `df -hT | grep -E 'squashfs|loop'` ni oling. Har snap nima uchun alohida mount ko'rinishida turganini izohlang. `snap info multipass` (yoki boshqa o'rnatilgan snap) dan `channels` va `confinement` ni toping. Bitta dasturni `apt`, `snap` va konteyner orqali o'rnatishning har biri uchun bitta afzallik va bitta kamchilik yozing.

19. **Package audit script.** `task_19.sh` yozing: Debian yoki RHEL oilasida ekanini `/etc/os-release` dagi `ID`/`ID_LIKE` orqali aniqlaydi va mos buyruqlar bilan qisqa hisobot chiqaradi: distributiv nomi va versiyasi, o'rnatilgan paketlar soni, mavjud yangilanishlar soni, ushlab qo'yilgan paketlar, standart bo'lmagan (uchinchi tomon) repo'lar ro'yxati, reboot kerakmi (Debian oilasida fayl orqali). Skript hech narsani o'zgartirmaydi va root talab qilmaydigan buyruqlar bilan cheklanadi (yangilanishlar sonini mavjud keshdan oladi). `shellcheck` toza. VM'da va `rockylinux:9` konteynerida ishga tushirib, ikkala chiqishni README'ga qo'ying.

20. **Cleanup.** (VM) Docker repo fayli, kaliti va pin faylini o'chiring, `nginx` ni `purge` qiling, `apt-mark showhold` bo'sh ekanini tekshiring, `sudo apt update` xatosiz va ogohlantirishsiz o'tishini ko'rsating. `sudo apt autoremove --purge` va `sudo apt clean` dan oldin va keyin `df -h /` va `du -sh /var/cache/apt` ni solishtiring.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi.
2. VM'da uchinchi tomon repo'lari, kalitlar, pin va `hold` qolmagan; test image va konteynerlar o'chirilgan.
3. README'da har vazifa uchun buyruq, natija va izoh bor; ish mashinasida hech narsa o'rnatilmagan.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `apt` va `dpkg` (`dnf` va `rpm`) orasidagi vazifa taqsimoti qanday?
- `apt update` aynan nima qiladi va nima uchun `dnf` da alohida shunday qadam yo'q?
- Paket HTTP mirror'dan kelsa ham nima uchun uni yo'lda almashtirib bo'lmaydi? Zanjirni bosqichma-bosqich ayting.
- `signed-by` `apt-key add` dan nimasi bilan xavfsizroq?
- `apt remove` va `apt purge` farqi nima?
- `apt-mark hold` qachon kerak va uning narxi nima?
- Dockerfile'da `apt-get update` va `install` nima uchun bitta `RUN` da yoziladi?
- Xavfsizlik yangilanishi o'rnatildi. Zaiflik yopilgan deyish uchun yana nima tekshirilishi kerak?
- Ubuntu uchun yozilgan o'rnatish skriptini Rocky'ga ko'chirganda qaysi farqlar uni buzadi? Kamida uchta.
