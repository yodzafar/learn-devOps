# SETUP: ikki mashinada bir xil laboratoriya

Kurs ikki kompyuterda o'tiladi: ofisda Zorin OS (Linux), uyda macOS. Darslar ikkalasida bir xil ishlashi uchun Linux'ga oid hamma narsa **`lab` nomli Ubuntu virtual mashinasi** ichida bajariladi. Host (Zorin yoki macOS) faqat uchta ish uchun kerak: shu repo bilan ishlash, VM'ni boshqarish va Docker.

Bu faylni bir marta, har ikkala mashinada alohida bajaring. Keyingi modullarga kerak bo'ladigan asboblar (kubectl, Terraform, Ansible, AWS CLI va boshqalar) shu yerda emas, birinchi kerak bo'lgan darsning "Laboratoriya" bo'limida o'rnatiladi.

## Nima uchun VM

macOS Linux emas. U ham Unix oilasidan, lekin kernel'i boshqa (Darwin/XNU), yordamchi buyruqlari BSD'dan olingan. Amalda:

| Narsa | Linux (Zorin, serverlar) | macOS |
|-------|--------------------------|-------|
| Kernel | Linux | Darwin (XNU) |
| `/proc`, `/sys` | bor | yo'q |
| Servis menejeri | systemd (`systemctl`, `journalctl`) | launchd (`launchctl`) |
| Paket menejeri | `apt`, `dnf` | Homebrew (`brew`), tizimga kirmaydi |
| Tarmoq buyruqlari | `ip`, `ss` | `ifconfig`, `netstat`, `lsof` |
| `sed -i`, `grep -P`, `date`, `stat` | GNU varianti | BSD varianti, flag'lari boshqacha |
| Docker | to'g'ridan-to'g'ri host kernel'ida | yashirin Linux VM ichida |

Serverlar deyarli hammasi Linux. Shuning uchun o'rganiladigan muhit Linux bo'lishi kerak, VM esa uni ikkala mashinada bir xil qilib beradi. Zorin'da ham vazifalar host'da emas, VM'da bajariladi: ish kompyuteringizni buzib qo'ymaysiz va javoblar ikki mashinada farq qilmaydi.

## 1. Asosiy asboblar

### Zorin (ofis)

`git`, `make` va Docker allaqachon o'rnatilgan. Tekshirish:

```
git --version
make --version
docker version
```

### macOS (uy)

Mac'ingiz Apple Silicon, ya'ni protsessor arxitekturasi `arm64`. Bu ba'zi yuklab olinadigan fayllarda kerak bo'ladi:

```
uname -m        # arm64
```

1. Xcode Command Line Tools (ichida `git` va `make` bor):

```
xcode-select --install
```

2. Homebrew, macOS uchun paket menejeri. O'rnatish buyrug'ini rasmiy sahifadan oling: https://brew.sh

3. Docker. Uch variantdan bittasi yetadi:

| Variant | O'rnatish | Eslatma |
|---------|-----------|---------|
| Docker Desktop | https://docs.docker.com/desktop/setup/install/mac-install/ | rasmiy, eng ko'p hujjatlashtirilgan; kurs shuni nazarda tutadi |
| OrbStack | https://orbstack.dev | yengil va tez; litsenziya shartlarini saytidan tekshiring |
| Colima | `brew install colima docker` | to'liq ochiq kodli, faqat terminal |

Tekshirish: `docker run --rm hello-world`.

## 2. Multipass va `lab` VM

Multipass Canonical'ning asbobi: bitta buyruq bilan Ubuntu VM yaratadi, Linux'da ham, Apple Silicon Mac'da ham bir xil ishlaydi. Hujjat: https://documentation.ubuntu.com/multipass/

O'rnatish:

```
# Zorin
sudo snap install multipass

# macOS
brew install --cask multipass
```

VM yaratish (ikkala mashinada bir xil):

```
multipass launch 24.04 --name lab --cpus 2 --memory 2G --disk 10G
multipass list
multipass shell lab        # enter the VM; leave with: exit
```

Ichkarida tekshirish:

```
cat /etc/os-release        # Ubuntu 24.04
uname -m                   # x86_64 on Zorin, aarch64 on the Mac
```

Toza holatni saqlab qo'ying, buzilsa shu nuqtaga qaytasiz:

```
multipass stop lab
multipass snapshot lab --name clean
multipass start lab
```

Kundalik buyruqlar:

| Buyruq | Vazifasi |
|--------|----------|
| `multipass shell lab` | VM ichiga kirish |
| `multipass exec lab -- <buyruq>` | kirmasdan bitta buyruq bajarish |
| `multipass transfer <fayl> lab:` | host'dan VM'ga fayl ko'chirish (teskarisi: `lab:<fayl> .`) |
| `multipass stop lab`, `multipass start lab` | o'chirish, yoqish |
| `multipass restore lab.clean` | snapshot'ga qaytish (VM to'xtatilgan bo'lishi kerak) |
| `multipass delete lab && multipass purge` | butunlay o'chirish |

VM ichidagi `ubuntu` foydalanuvchisi `sudo` ni parolsiz ishlata oladi. Bu faqat laboratoriya uchun qulaylik, haqiqiy serverda bunday bo'lmaydi (`linux` 10-dars).

## 3. Arxitektura farqi

Mac'da VM va konteynerlar `arm64` (`aarch64`), Zorin'da `amd64` (`x86_64`). Ko'p hollarda farq sezilmaydi, lekin:

- Binary yuklab olayotganda to'g'ri arxitekturani tanlang (`linux-arm64` yoki `linux-amd64`). Darslar ikkalasini ko'rsatadi.
- Docker image'lar ko'pincha ikkala arxitektura uchun chiqadi. Faqat `amd64` uchun chiqqan image Mac'da emulyatsiya bilan sekin ishlaydi yoki ishlamaydi.
- Mac'da yig'ilgan image `arm64` bo'ladi, `amd64` serverda ishlamaydi. Yechimi `docker` modulining 2-darsida (`docker buildx`, multi-platform).

## 4. Ikki mashina orasida ishni ko'chirish

- **Javoblar va fayllar** git orqali ko'chadi. Repoga remote qo'shing (masalan GitHub'da private repo), ofisda `git push`, uyda `git pull`. Remote hali sozlanmagan bo'lsa: `gh repo create dev-ops --private --source=. --push`.
- **Laboratoriya holati ko'chmaydi.** VM, konteyner, volume, klaster har mashinada alohida. Dars oldingi darsdan qolgan holatga tayansa (masalan yaratilgan user yoki servis), darsning "Laboratoriya" bo'limida uni ikkinchi mashinada qanday tez tiklash yozilgan.
- **Tavsiya:** bitta darsni iloji bo'lsa bitta mashinada tugating, mashinani dars oralig'ida almashtiring.
- **Cloud va tashqi akkauntlar** (AWS, GitHub, GitLab) mashinaga bog'liq emas, lekin CLI kalitlari har mashinada alohida sozlanadi. Kalitlarni git orqali ko'chirmang.

## 5. Tekshirish ro'yxati

Har mashinada:

```
git --version && make --version && docker run --rm hello-world
multipass exec lab -- lsb_release -ds
make help
```

Uchala qator xatosiz ishlasa, `linux/docs/01-intro.md` ga o'ting.
