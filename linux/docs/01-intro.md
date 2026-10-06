# 1-dars: Linuxga kirish

Maqsad: Linux deb nomlanadigan tizim aslida qanday qatlamlardan iboratligini (kernel, user space, distributiv), kompyuter yoqilgandan login promptigacha nima sodir bo'lishini, fayl tizimi daraxtida (FHS) nima qayerda yotishini va terminal, shell, buyruq uchligi orasidagi farqni noldan tushunish. Oxirida yordam tizimi (`man`, `--help`, `help`, `tldr`) bilan ishlashni o'rganasiz, chunki keyingi 12 darsda har yangi buyruqni shu orqali o'zingiz ochasiz. Bu dars butun kursning lug'ati: Docker (umumiy kernel), systemd (PID 1), Kubernetes (`/proc`, `/sys`, cgroup) mavzulari shu yerdagi tushunchalarga tayanadi. Frontend ishida brauzer va Node sizdan operatsion tizimni yashirgan, bu kursda esa aynan o'sha yashirin qatlam o'rganiladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A, B, C guruh vazifalari, ikkinchi kun 4–5 bo'limlar va D, E guruhlari, uchinchi kun "Birga bajaramiz", 22-vazifa va README'ni tartibga solish. Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: kernel va distributiv chegarasi, konteyner nima uchun host kernel'ini ko'rsatishi, `/proc` va `/sys` nima uchun diskda joy egallamasligi, builtin va tashqi buyruq farqi, `man` sahifasining bo'limlari.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring, chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi raqamlar (kernel versiyasi, PID, hajm) farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi, yodlash emas tushunish uchun.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` virtual mashinasi kerak (Multipass, Ubuntu 24.04, `multipass launch 24.04 --name lab --cpus 2 --memory 2G --disk 10G`). Virtual mashina (VM) bu kompyuter ichida dastur sifatida ishlaydigan, o'z kernel'i va o'z diskiga ega bo'lgan to'liq ikkinchi kompyuter. Multipass uni bitta buyruq bilan yaratadi va ikkala host'da bir xil Ubuntu beradi. Distributivlar va snapshot'lar haqida batafsil 2-darsda, bu darsda faqat kirish va chiqish kerak:

```
multipass shell lab        # enter the VM; the prompt becomes ubuntu@lab:~$
exit                       # leave the VM, back to the host shell
```

Uchta "joy" bor va dars davomida qaysi birida turganingizni prompt'dan bilasiz:

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | repo bilan ishlash (`make`, `git`), `multipass`, `docker` buyruqlari |
| `lab` VM | `ubuntu@lab:~$` | barcha Linux vazifalari: `/proc`, `/boot`, systemd, `journalctl`, `man` |
| Konteyner | `root@<id>:/#` | taqqoslash uchun bir martalik Ubuntu user space |

- **VM**: barcha o'qiydigan buyruqlar (`uname`, `cat`, `ls`, `ps`, `man`, `journalctl`, `systemd-analyze`) shu yerda. VM'dagi `ubuntu` foydalanuvchisi `sudo` ni parolsiz ishlata oladi, lekin bu darsda `sudo` kerak emas (bitta istisno: 20-vazifadagi `tealdeer` paketi, u yordam vositasi va VM ichida o'rnatiladi). Biror buyruq "Permission denied" yoki "Operation not permitted" desa, `sudo` qo'ymang: xatoni o'qing va README'ga yozing, bu vazifaning qismi.
- **Konteyner**: host'da ishga tushiriladi, `--rm` chiqishda konteynerni o'chiradi, `-it` interaktiv terminal beradi. Tozalash shart emas:

```
docker run --rm -it ubuntu:24.04 bash
# inside the container: run commands, then
exit
```

- Bitta buyruqni kirmasdan bajarish: `docker run --rm ubuntu:24.04 uname -r` (konteyner) va `multipass exec lab -- uname -r` (VM). Taqqoslash vazifalarida qulay.
- VM'dagi standart shell `bash`, host'da (Zorin'da ham, macOS'da ham) `zsh` bo'lishi mumkin. Shell'ga bog'liq vazifalar (14–17, 20) VM ichida bajariladi, shuning uchun qo'shimcha hech narsa kerak emas. Kurs davomida serverlardagi standart shell bash bo'ladi.
- Bu dars oldingi holatga tayanmaydi: `lab` VM toza bo'lsa yetarli. Mashinani almashtirsangiz, ikkinchi mashinada ham `SETUP.md` bo'yicha `lab` bo'lishi kerak, boshqa tiklash yo'q.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM va konteyner `x86_64` (`amd64`). Konteyner ichidagi `uname -r` Zorin'ning o'z kernel'ini ko'rsatadi, chunki Docker Engine to'g'ridan-to'g'ri host kernel'ida ishlaydi. Host'ning o'zi ham Linux, shuning uchun ixtiyoriy "host'da ham sinab ko'ring" eslatmalari ishlaydi. |
| macOS (uy) | VM va konteyner `aarch64` (`arm64`). Host Linux emas: `/proc`, `systemctl`, `journalctl`, `free`, `lsblk` yo'q, `ls --help` ishlamaydi (BSD `ls`). Konteyner ichidagi `uname -r` Docker Desktop'ning yashirin Linux VM'ining kernel'ini (`<versiya>-linuxkit`) ko'rsatadi, Mac kernel'ini emas. Vazifalar faqat `lab` VM va konteynerda bajariladi, host'ga tegishli savollar ixtiyoriy. |

---

## 1. Linux nima: kernel, user space, distributiv

### Ikki ma'no

"Linux" so'zi ikki ma'noda ishlatiladi. Tor ma'noda bu faqat **kernel** (yadro): Linus Torvalds 1991-yilda boshlagan, kernel.org da chiqadigan bitta dastur. Kernel bu hardware'ni boshqaradigan va qolgan barcha dasturlarga xizmat ko'rsatadigan markaziy dastur: u jarayonlarga CPU vaqtini taqsimlaydi, xotirani bo'lib beradi, diskdagi baytlarni fayl ko'rinishida beradi, tarmoq paketlarini yuboradi va qabul qiladi. Keng ma'noda "Linux" bu kernel ustiga qurilgan butun operatsion tizim: shell, utilitalar, kutubxonalar, servislar.

| Qatlam | Nima qiladi | Misol |
|--------|-------------|-------|
| Hardware | CPU, RAM, disk, tarmoq kartasi | |
| Kernel | jarayonlarni rejalashtirish, xotira, fayl tizimlari, tarmoq steki, drayverlar | `vmlinuz-6.8.0-<NN>-generic` fayli |
| System call interfeysi | user space kernel'dan xizmat so'raydigan yagona eshik | `open`, `read`, `write`, `fork`, `execve` |
| User space | kutubxonalar (glibc), shell, utilitalar, init tizimi, sizning dasturlaringiz | `bash`, `ls`, `systemd`, `node` |

### Mexanizm: kernel space va user space

CPU ikki rejimda ishlaydi. Kernel imtiyozli rejimda: u istalgan xotira manziliga va istalgan qurilmaga murojaat qila oladi. Oddiy dastur (user space) cheklangan rejimda: u diskka yoki tarmoqqa to'g'ridan-to'g'ri murojaat qila olmaydi, hatto boshqa dasturning xotirasini ham ko'ra olmaydi. Dastur biror narsa kerak bo'lsa **system call** (syscall) qiladi: CPU'ga maxsus buyruq beradi, boshqaruv kernel'ga o'tadi, kernel ruxsatni tekshiradi, ishni bajaradi va natijani qaytaradi. Shuning uchun fayl ruxsatlari, foydalanuvchilar, konteyner izolyatsiyasi kabi narsalarning hammasi kernel'da amalga oshiriladi: dastur ularni chetlab o'ta olmaydi, chunki hardware'ga yagona yo'l kernel orqali.

Node'da `fs.readFile('a.txt')` chaqirsangiz, zanjir shunday: sizning JS kodingiz → Node'ning C++ qatlami (libuv) → glibc kutubxonasi → `openat` va `read` system call'lari → kernel → disk drayveri. `node` kernel emas, u ham oddiy user space dastur.

`ls`, `cp`, `cat` kabi buyruqlar ham kernel emas. Ular **GNU coreutils** paketidan keladi (shuning uchun "GNU/Linux" atamasi bor). Kernel'dan tashqaridagi barcha dasturlar to'plami **userland** deyiladi. Bu amaliy ahamiyatga ega: Alpine Linux'da o'sha `ls` BusyBox'dan keladi va ba'zi flag'lar yo'q; macOS'da `ls` BSD'dan keladi va `--help` ni tushunmaydi. Buyruq nomi bir xil, dastur boshqa.

### Distributiv

Distributiv (distro) bu kernel + user space dasturlari + paket menejeri + init tizimi + standart sozlamalar + yangilash va qo'llab-quvvatlash siyosati. Paket menejeri bu dasturlarni o'rnatadigan, yangilaydigan va o'chiradigan asbob (Ubuntu'da `apt`), `npm` ning tizim darajasidagi o'xshashi. Ubuntu, Debian, Rocky Linux, Fedora bir xil kernel loyihasidan foydalanadi, lekin kernel versiyasi, paket formati (`.deb` yoki `.rpm`), konfiguratsiya joylashuvi va reliz muddatlari farq qiladi. Zorin OS Ubuntu ustiga qurilgan distributiv, Ubuntu esa Debian ustiga. Batafsil 2-darsda.

### Misol: kernel'dan va distributivdan so'rash

Ikki xil savolga ikki xil fayl javob beradi. VM ichida:

```
ubuntu@lab:~$ uname -r
6.8.0-<NN>-generic
ubuntu@lab:~$ uname -a
Linux lab 6.8.0-<NN>-generic #<build>-Ubuntu SMP PREEMPT_DYNAMIC <sana> x86_64 x86_64 x86_64 GNU/Linux
```

`uname -a` maydonlari chapdan o'ngga: `Linux` kernel nomi (`-s`); `lab` hostname (`-n`); `6.8.0-<NN>-generic` kernel release (`-r`), bunda `6.8.0` upstream versiya, `<NN>` Ubuntu'ning o'z build raqami, `generic` kernel varianti; `#<build>-Ubuntu SMP PREEMPT_DYNAMIC <sana>` kernel version (`-v`), ya'ni qachon va qanday sozlamalar bilan kompilyatsiya qilingani (`SMP` ko'p yadroli, `PREEMPT_DYNAMIC` rejalashtirish rejimi); `x86_64` uch marta: mashina arxitekturasi (`-m`), protsessor (`-p`) va hardware platformasi (`-i`); `GNU/Linux` operatsion tizim nomi (`-o`). Mac'dagi VM'da uchta `x86_64` o'rnida `aarch64` turadi, qolgani bir xil.

```
ubuntu@lab:~$ cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.5 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
...
```

`PRETTY_NAME` odam uchun to'liq nom, nuqtadan keyingi `5` point release raqami (sizda boshqa bo'lishi mumkin); `VERSION_ID` skriptlar solishtiradigan qisqa versiya; `VERSION_CODENAME` kod nomi, paket manbalarida shu nom ishlatiladi; `ID` distributivning mashina uchun nomi; `ID_LIKE` "men kimga o'xshayman", ya'ni qaysi distributivning paketlari va yo'llari bu tizimda ham ishlaydi. Skript yozuvchi uchun qoida: avval `ID` ni tekshir, tanimasang `ID_LIKE` ga qara. Fayl formati `KEY=value`, shuning uchun uni shell'da `. /etc/os-release` bilan o'qib `$ID` deb ishlatish mumkin (5-darsda).

Zorin host'ida (ixtiyoriy, faqat ofisda): `ID=zorin`, `ID_LIKE="ubuntu debian"`, `VERSION_CODENAME=noble`. Zorin o'zini Ubuntu va Debian'ga o'xshash deb e'lon qiladi, shuning uchun Ubuntu uchun yozilgan o'rnatish skriptlari unda ishlaydi. macOS'da bu fayl yo'q: `sw_vers` buyrug'i macOS versiyasini ko'rsatadi, `uname -s` esa `Darwin` qaytaradi.

Kernel versiyasi haqida yana bir manba `/proc/version`: `uname -a` ko'rsatgan ma'lumotga qo'shimcha qaysi kompilyator bilan yig'ilgani ham yoziladi.

```
ubuntu@lab:~$ cat /proc/version
Linux version 6.8.0-<NN>-generic (buildd@<host>) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-<...>) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #<build>-Ubuntu SMP PREEMPT_DYNAMIC <sana>
```

`buildd` bu Ubuntu'ning avtomatik build serverlari, `gcc-13` kompilyator, `GNU ld` linker. `uname` aslida shu ma'lumotni kernel'dan `uname` system call'i orqali oladi, `/proc/version` esa o'sha ma'lumotni fayl ko'rinishida beradi (3-bo'lim).

### macOS qayerda turadi

macOS Linux emas, lekin Unix oilasidan. Uning kernel'i **XNU**, operatsion tizim yadrosi **Darwin** deb nomlanadi, yordamchi buyruqlari (`ls`, `sed`, `grep`, `date`) **BSD** (Berkeley Unix) avlodidan olingan. Linux kernel'i ham, GNU coreutils ham Unix'ning qayta yozilgan variantlari, shuning uchun ikkalasida `ls`, `cd`, `cat`, `/etc`, `/usr`, `/var` bor va umumiy tushunchalar (jarayon, fayl, ruxsat, signal, PID 1) bir xil. Farq tafsilotlarda:

| Narsa | Linux (`lab` VM, serverlar) | macOS (uy host'i) |
|-------|-----------------------------|-------------------|
| Kernel | Linux, `uname -s` → `Linux` | XNU, `uname -s` → `Darwin` |
| Kernel haqida ma'lumot | `/proc`, `/sys` | yo'q, `sysctl` va alohida buyruqlar |
| PID 1 | `systemd` | `launchd` |
| Utilitalar | GNU: `ls --help`, `sed -i`, `grep -P` | BSD: uzun flag'lar kam, `sed -i ''`, `grep -P` yo'q |
| Paket menejeri | `apt` (tizimning qismi) | Homebrew (tizimdan tashqari) |
| Tarmoq | `ip`, `ss` | `ifconfig`, `netstat`, `lsof` |

Serverlar deyarli hammasi Linux. Shuning uchun kurs Linux VM ichida o'tiladi: Mac'da o'rgangan BSD flag'i serverda ishlamasligi mumkin, VM'dagi esa aynan serverdagi bilan bir xil. Mac'da host buyruqlari (`git`, `make`, `docker`, `multipass`) ishlaydi, Linux'ga oid hamma narsa VM'da.

### Konteyner va VM: kernel kimniki

Konteyner bu host kernel'ida ishlaydigan, lekin o'z fayl tizimi (image) va izolyatsiyalangan jarayonlar ro'yxatiga ega jarayonlar guruhi. Image bu konteynerning boshlang'ich fayl tizimi, masalan `ubuntu:24.04` image'ida Ubuntu'ning user space fayllari bor, lekin kernel yo'q. VM esa o'z kernel'ini yuklaydi. Shuning uchun uchta joyda `uname -r` uch xil natija beradi:

| Joy | Zorin (ofis) | macOS (uy) |
|-----|--------------|------------|
| Host, `uname -r` | Zorin kernel'i (`7.0.0-<NN>-generic`) | Darwin kernel'i (`<NN>.<N>.<N>`) |
| `docker run --rm ubuntu:24.04 uname -r` | Zorin kernel'i, host bilan bir xil | Docker Desktop VM kernel'i (`<versiya>-linuxkit`) |
| `lab` VM, `uname -r` | `6.8.0-<NN>-generic` | `6.8.0-<NN>-generic` |
| `docker run --rm ubuntu:24.04 cat /etc/os-release` | Ubuntu 24.04 | Ubuntu 24.04 |

Konteyner `/etc/os-release` da Ubuntu'ni ko'rsatadi, lekin `uname -r` konteyner ishlayotgan kernel'ni qaytaradi: Zorin'da bu Zorin kernel'i, Mac'da Docker Desktop'ning yashirin Linux VM'i kernel'i (Mac kernel'i Linux konteynerni ishlata olmaydi, shuning uchun Docker Desktop o'z Linux VM'ini yashirincha ishga tushiradi). VM ichida esa har doim Ubuntu'ning o'z kernel'i, host'dan qat'i nazar.

**Tuzoq: konteyner o'z kernel'iga ega emas.** Konteyner bu faqat boshqa distributivning user space'i, kernel umumiy. Shuning uchun kernel moduli yoki kernel parametri (`sysctl`) talab qiladigan dastur konteyner image'ini almashtirish bilan tuzalmaydi. Kernel'ni o'zgartirish kerak bo'lsa host yoki VM o'zgartiriladi.

### Real ishda qachon kerak

- Xato hisobotida "qaysi Linux?" deb so'ralganda ikkita javob beriladi: `uname -r` va `cat /etc/os-release`. Birisiz ikkinchisi to'liq emas.
- Binary yuklab olayotganda `uname -m` arxitekturani aytadi: `x86_64` uchun `amd64` fayl, `aarch64` uchun `arm64` fayl. Noto'g'ri arxitektura `Exec format error` bilan tugaydi.
- Konteynerda ishlamayotgan narsa kernel'ga bog'liqmi yoki user space'gami, deb ajratish: birinchisini image almashtirish tuzatmaydi.
- Install skriptlari `ID` va `ID_LIKE` bo'yicha tarmoqlanadi; Zorin kabi hosila distributivlarda `ID_LIKE` tufayli ishlaydi.

### Nima uchun shunday

Kernel va user space ajratilishi xavfsizlik va barqarorlik uchun: buzilgan yoki yomon niyatli dastur hardware'ga to'g'ridan-to'g'ri yeta olmaydi va boshqa dasturni buza olmaydi. Linux kernel'i va GNU utilitalari alohida loyihalar bo'lgani uchun ularni boshqa-boshqa almashtirish mumkin: Alpine Linux kernel'ni saqlab userland'ni BusyBox'ga, Android esa kernel'ni saqlab butun user space'ni o'zinikiga almashtirgan. Konteynerlar aynan shu ajratishga tayanadi: kernel bitta, userland'lar ko'p. Bu ajratish yo'q bo'lgan tizimda (masalan macOS) Linux konteynerlarini ishlatish uchun to'liq VM kerak bo'ladi, Docker Desktop shuni qiladi.

## 2. Tizim qanday yuklanadi (boot)

### Bosqichlar

Kompyuter yoqilganda xotira bo'sh, diskda esa dasturlar yotadi. Kimdir birinchi dasturni xotiraga yuklashi kerak, u keyingisini yuklaydi va shunday zanjir login promptigacha davom etadi. Har bosqich keyingisini topib, xotiraga yuklab, boshqaruvni beradi:

| Bosqich | Kim | Nima qiladi | Qayerdan ko'rish |
|---------|-----|-------------|------------------|
| 1. Firmware | UEFI (eski tizimlarda BIOS) | hardware'ni tekshiradi, diskdan bootloader'ni topadi | `ls /sys/firmware/efi` mavjud bo'lsa UEFI |
| 2. Bootloader | GRUB | kernel va initramfs'ni xotiraga yuklaydi, kernel'ga parametrlar beradi | `ls /boot`, `cat /proc/cmdline` |
| 3. Kernel | `vmlinuz-*` | hardware'ni ishga tushiradi, initramfs'ni vaqtinchalik root sifatida ochadi | `journalctl -k -b` |
| 4. initramfs | `initrd.img-*` | haqiqiy root diskni topish uchun kerakli drayverlarni yuklaydi (LVM, shifrlash, RAID), root'ni mount qiladi | |
| 5. Init | `systemd`, PID 1 | servislarni bog'liqlik tartibida ishga tushiradi, target'ga yetadi | `ps -p 1 -o pid,comm`, `systemd-analyze` |
| 6. Login | `getty`, display manager yoki `sshd` | foydalanuvchini kutadi | |

Atamalar: **firmware** bu kompyuter platasidagi chipga yozilgan, yoqilganda birinchi ishlaydigan dastur; **UEFI** uning zamonaviy standarti; **bootloader** diskdan kernel'ni yuklaydigan kichik dastur, Linux'da odatda GRUB; **initramfs** (initial RAM filesystem) xotiraga yuklanadigan kichik vaqtinchalik fayl tizimi; **init** kernel ishga tushiradigan birinchi user space dastur; **mount** fayl tizimini daraxtdagi biror papkaga ulash (3-bo'lim).

### Mexanizm: initramfs nima uchun kerak

Kernel root fayl tizimini (ya'ni `/` turgan diskni) mount qilishi uchun o'sha diskning drayveri kerak. Drayver esa o'sha diskda yotadi: tovuq va tuxum muammosi. Yechim: bootloader kernel bilan birga kichik arxivni (initramfs) xotiraga yuklaydi, ichida eng kerakli drayverlar va root'ni topadigan skript bor. Kernel avval shu arxivni root qilib ochadi, skript haqiqiy diskni topib mount qiladi, keyin boshqaruv haqiqiy diskdagi `init` ga o'tadi. Shifrlangan disk, LVM, tarmoq orqali boot kabi holatlar aynan shu bosqichda yechiladi.

### PID 1

Kernel yuklanishni tugatgach bitta user space dastur ishga tushiradi va unga 1 raqamini beradi. **PID** (process ID) bu kernel har jarayonga beradigan raqam. PID 1 yagona jarayonki, uni kernel o'zi ishga tushirgan; qolgan hamma jarayon uning avlodi (yoki avlodining avlodi). Zamonaviy distributivlarda bu `systemd` (11-darsda chuqur). Agar PID 1 to'xtasa kernel panic qiladi, tizim o'ladi.

```
ubuntu@lab:~$ ps -p 1 -o pid,ppid,user,comm,args
    PID    PPID USER     COMMAND         COMMAND
      1       0 root     systemd         /sbin/init
```

`PID 1` jarayon raqami; `PPID 0` ota jarayon raqami, 0 degani "ota yo'q, kernel ishga tushirgan"; `USER root` kim nomidan ishlayapti; `COMMAND systemd` (`comm` ustuni) jarayonning haqiqiy nomi; oxirgi `COMMAND /sbin/init` (`args` ustuni) ishga tushirilgan buyruq satri. Ikkalasi farq qiladi, chunki kernel `/sbin/init` ni ishga tushirgan, bu esa `systemd` ga symlink (3-bo'lim). Zorin host'ida (ixtiyoriy) `args` ustunida `/sbin/init splash` ko'rinadi, `splash` grafik yuklanish ekrani uchun parametr.

Node tajribasiga bog'lash: `pm2` dasturlarni ishga tushiradi, o'lsa qayta ko'taradi, logini yig'adi. systemd butun tizim uchun shu ishni qiladi va o'zi PID 1, ya'ni uni hech kim ishga tushirmagan, kernel bergan.

### Misol: yuklanish qancha vaqt oldi

```
ubuntu@lab:~$ systemd-analyze
Startup finished in <N>s (kernel) + <N>s (userspace) = <N>s
multi-user.target reached after <N>s in userspace.
```

Birinchi qator bosqichlar bo'yicha vaqt: `kernel` kernel ishga tushgandan systemd boshlangunga qadar, `userspace` systemd barcha servislarni ko'targuncha. Firmware vaqtni hisoblab bergan tizimlarda (UEFI) qatorda `(firmware)` va `(loader)` qismlari ham chiqadi, Zorin host'ida masalan `8.021s (firmware) + 2.070s (loader) + 2.880s (kernel) + 9.274s (userspace)`. Ikkinchi qator: qaysi **target**'ga yetildi. Target bu systemd'da tizim holati: server va VM uchun `multi-user.target` (tarmoq, servislar, matnli login), desktop uchun `graphical.target` (ustiga grafik oyna). Standart target'ni `systemctl get-default` ko'rsatadi.

```
ubuntu@lab:~$ systemd-analyze blame | head -5
<N>s <unit>.service
<N>s <unit>.service
...
```

`blame` har servis (systemd'da **unit**) qancha vaqt olganini eng sekinidan boshlab chiqaradi. Bu ro'yxat "nima uchun server sekin yuklanadi" savolining birinchi javobi. Unit nima qilishini `systemctl status <unit>` ko'rsatadi (11-darsda).

### Misol: kernel'ga berilgan parametrlar va kernel xabarlari

```
ubuntu@lab:~$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-6.8.0-<NN>-generic root=<disk identifikatori> ro <boshqa parametrlar>
```

Bu GRUB kernel'ga bergan satr. `BOOT_IMAGE` qaysi kernel fayli yuklangan; `root=` haqiqiy root fayl tizimi qayerda (UUID, PARTUUID yoki `/dev/...` ko'rinishida, 13-darsda); `ro` root avval read-only mount qilinadi, fayl tizimi tekshirilgach systemd uni read-write qiladi. Zorin host'ida bunga `quiet splash` qo'shiladi: kernel xabarlarini yashirish va grafik ekran.

Kernel yuklanish davomida nima qilganini log'ga yozadi. **journal** bu systemd'ning markaziy log bazasi, `journalctl` uni o'qiydi:

```
ubuntu@lab:~$ journalctl -k -b | head -3
<Oy> <kun> <vaqt> lab kernel: Linux version 6.8.0-<NN>-generic (buildd@<host>) (...) #<build>-Ubuntu SMP PREEMPT_DYNAMIC <sana>
<Oy> <kun> <vaqt> lab kernel: Command line: BOOT_IMAGE=/boot/vmlinuz-6.8.0-<NN>-generic root=... ro ...
<Oy> <kun> <vaqt> lab kernel: KERNEL supported cpus:
```

`-k` faqat kernel xabarlari, `-b` faqat joriy boot. Har qator: vaqt, hostname (`lab`), manba (`kernel`), xabar. Birinchi xabar `/proc/version` bilan, ikkinchisi `/proc/cmdline` bilan bir xil: kernel yuklanishda o'zi haqida aytgan narsa shu fayllarda ham turadi. `dmesg` ham shu kernel buferini ko'rsatadi, lekin Ubuntu'da oddiy foydalanuvchiga yopiq:

```
ubuntu@lab:~$ dmesg
dmesg: read kernel buffer failed: Operation not permitted
ubuntu@lab:~$ sysctl kernel.dmesg_restrict
kernel.dmesg_restrict = 1
```

`sysctl` kernel'ning ish vaqtidagi sozlamalarini o'qiydi va o'zgartiradi; `kernel.dmesg_restrict = 1` degani kernel buferini faqat root o'qiydi (xotira manzillari va hardware ma'lumoti sizib chiqmasligi uchun). `journalctl -k` ishlaydi, chunki `ubuntu` foydalanuvchisi `adm` guruhida va journal fayllarini o'qish huquqi bor.

### Konteynerda boot yo'q

Konteyner ichida bootloader ham, kernel yuklanishi ham, odatda systemd ham yo'q. Konteyner ishga tushganda kernel allaqachon ishlab turibdi (host'niki), Docker faqat image fayl tizimini ochib siz ko'rsatgan dasturni PID 1 qilib ishga tushiradi:

```
$ docker run --rm ubuntu:24.04 ps -p 1 -o pid,comm
    PID COMMAND
      1 ps
$ docker run --rm ubuntu:24.04 cat /proc/1/comm
cat
```

Birinchi holatda PID 1 `ps` ning o'zi, ikkinchisida `cat`: siz qaysi buyruqni bersangiz, o'sha PID 1. `docker run -it ubuntu:24.04 bash` da PID 1 `bash` bo'ladi. Shuning uchun konteynerda `systemctl` ishlamaydi va PID 1 bo'lgan dastur signal'larni to'g'ri qayta ishlashi shart (Docker modulida).

### Real ishda qachon kerak

- Server yuklanmayapti: bosqichni aniqlash (GRUB menyusi chiqdimi, kernel xabarlari chiqdimi, systemd boshlanib servisda qotib qoldimi) muammo qayerda ekanini aytadi.
- Server sekin yuklanadi: `systemd-analyze blame` va `systemd-analyze critical-chain`.
- Disk yoki tarmoq kartasi ko'rinmaydi: `journalctl -k` dagi kernel xabarlari, drayver yuklandimi.
- Kernel yangilangandan keyin muammo: `/boot` dagi eski kernel bilan yuklash, shuning uchun eski versiya o'chirilmaydi.

### Nima uchun shunday

Ko'p bosqichli zanjir tarixiy va amaliy sabablarga ega: firmware kichik va universal bo'lishi kerak (har qanday OS'ni yuklaydi), bootloader esa OS'ga xos. initramfs 2000-yillarda, root disklar shifrlash, LVM, tarmoq orqasida qolgach zarur bo'ldi. `systemd` 2010-yilda SysV init o'rniga keldi: SysV servislarni ketma-ket skriptlar bilan ishga tushirardi, systemd bog'liqlik grafigi bo'yicha parallel ishga tushiradi va servisni kuzatadi (o'lsa qayta ko'taradi). Hozir barcha asosiy distributivlar (Ubuntu, Debian, Fedora, RHEL, SUSE, Arch) systemd ishlatadi; muqobillar (OpenRC, runit) Alpine va Void kabi kichik distributivlarda. macOS'da shu rolni `launchd` o'ynaydi, systemd'dan oldin paydo bo'lgan va unga ta'sir qilgan.

## 3. Fayl tizimi ierarxiyasi (FHS)

### Bitta daraxt

Linux'da disk harflari (`C:`, `D:`) yo'q. Bitta daraxt bor, ildizi `/` (root), boshqa disklar va virtual fayl tizimlari shu daraxtning papkalariga **mount** qilinadi: ya'ni papka boshqa fayl tizimining kirish eshigi bo'lib qoladi. `findmnt <yo'l>` berilgan yo'l qaysi fayl tizimida turganini ko'rsatadi. Nima qayerda yotishini **Filesystem Hierarchy Standard** (FHS) belgilaydi, distributivlar unga asosan amal qiladi.

```
ubuntu@lab:~$ ls -l /
total <N>
lrwxrwxrwx   1 root root    7 <sana> bin -> usr/bin
drwxr-xr-x   <N> root root 4096 <sana> boot
drwxr-xr-x  <N> root root <N> <sana> dev
drwxr-xr-x  <N> root root 4096 <sana> etc
drwxr-xr-x   3 root root 4096 <sana> home
lrwxrwxrwx   1 root root    7 <sana> lib -> usr/lib
lrwxrwxrwx   1 root root    9 <sana> lib64 -> usr/lib64
drwx------   2 root root <N> <sana> lost+found
drwxr-xr-x   2 root root 4096 <sana> media
drwxr-xr-x   2 root root 4096 <sana> mnt
drwxr-xr-x   2 root root 4096 <sana> opt
dr-xr-xr-x <N> root root    0 <sana> proc
drwx------   <N> root root 4096 <sana> root
drwxr-xr-x  <N> root root <N> <sana> run
lrwxrwxrwx   1 root root    8 <sana> sbin -> usr/sbin
drwxr-xr-x   <N> root root 4096 <sana> snap
drwxr-xr-x   2 root root 4096 <sana> srv
dr-xr-xr-x  13 root root    0 <sana> sys
drwxrwxrwt  <N> root root 4096 <sana> tmp
drwxr-xr-x  12 root root 4096 <sana> usr
drwxr-xr-x  <N> root root 4096 <sana> var
```

Qatorni o'qish: birinchi belgi fayl turi (`d` papka, `l` symlink, `-` oddiy fayl); keyingi 9 belgi ruxsatlar (6-darsda); son havolalar soni; `root root` egasi va guruhi; hajm baytlarda; sana; nom. `bin -> usr/bin` degani `/bin` haqiqiy papka emas, `/usr/bin` ga ko'rsatuvchi **symlink** (boshqa yo'lga ishora qiluvchi fayl): `/bin/ls` va `/usr/bin/ls` bitta fayl. `proc` va `sys` hajmi `0`: ular diskda emas (quyida). `tmp` oxiridagi `t` hamma yoza oladigan, lekin faqat o'zi yaratganini o'chira oladigan papka belgisi. `lost+found` ext4 fayl tizimining tuzatishdan keyin topilgan bo'laklar uchun papkasi, konteynerda yo'q. Mac'dagi VM'da `lib64` symlink'i bo'lmaydi: u faqat `x86_64` arxitekturasida kerak.

### Papkalar

| Papka | Ichida nima | Eslatma |
|-------|-------------|---------|
| `/etc` | tizim konfiguratsiyasi, matn fayllar | backup va konfiguratsiya boshqaruvining asosiy obyekti |
| `/home` | foydalanuvchilar uy papkalari | `~` shu yerga ochiladi, VM'da `/home/ubuntu` |
| `/root` | root foydalanuvchining uy papkasi | `/home` da emas, chunki `/home` alohida diskda bo'lishi mumkin |
| `/usr` | o'rnatilgan dasturlar va kutubxonalar: `/usr/bin`, `/usr/sbin`, `/usr/lib`, `/usr/share` | paket menejeri boshqaradi, qo'lda tegilmaydi |
| `/usr/local` | paket menejerisiz, qo'lda o'rnatilgan dasturlar | `/usr/local/bin` `PATH` da `/usr/bin` dan oldin turadi |
| `/bin`, `/sbin`, `/lib` | `/usr/bin`, `/usr/sbin`, `/usr/lib` ga symlink | "usr merge", zamonaviy distributivlarda |
| `/var` | o'zgaruvchan ma'lumot: `/var/log` (loglar), `/var/lib` (dasturlar holati, masalan `/var/lib/apt`, `/var/lib/docker`), `/var/cache` | disk to'lishining eng ko'p uchraydigan joyi |
| `/tmp` | vaqtinchalik fayllar, hamma yoza oladi | reboot'da yoki muddat bo'yicha tozalanadi |
| `/run` | ishlayotgan tizim holati: PID fayllar, socket'lar | `tmpfs`, xotirada, reboot'da yo'qoladi |
| `/boot` | kernel, initramfs, GRUB | 2-bo'limdagi fayllar |
| `/dev` | qurilma fayllari | kernel yaratadi (`devtmpfs`) |
| `/proc` | jarayonlar va kernel haqida ma'lumot | virtual, diskda yo'q |
| `/sys` | qurilmalar, drayverlar, kernel sozlamalari | virtual, diskda yo'q |
| `/opt` | mustaqil, o'z papkasida yashaydigan dasturlar | odatda vendor paketlari |
| `/srv` | server xizmat qiladigan ma'lumot | ko'p distributivda bo'sh |
| `/mnt`, `/media` | qo'lda va avtomatik mount nuqtalari | |
| `/snap` | snap paketlari (Ubuntu'ga xos) | FHS'da yo'q, Ubuntu qo'shimchasi |

`/usr/bin` va `/usr/sbin` farqi: `sbin` (system binaries) administrator buyruqlari (`mount`, `useradd`, `sshd`). Ubuntu'da oddiy foydalanuvchining `PATH` ida ham `/usr/sbin` bor, lekin ko'pi root huquqi talab qiladi.

### Misol: bitta dastur, to'rt joy

Windows'dagi "bitta papkada hamma narsa" modeli Linux'da faqat `/opt` da uchraydi. Odatda bitta dastur to'rt joyga yoyiladi: binary `/usr/bin` da, sozlamasi `/etc` da, ma'lumoti `/var/lib` da, logi `/var/log` da. `apt` misolida, VM ichida:

```
ubuntu@lab:~$ type -a apt
apt is /usr/bin/apt
apt is /bin/apt
ubuntu@lab:~$ ls /etc/apt
apt.conf.d  auth.conf.d  keyrings  preferences.d  sources.list  sources.list.d  trusted.gpg.d
ubuntu@lab:~$ ls /var/lib/apt/lists | head -3
<server>_ubuntu_dists_noble_InRelease
<server>_ubuntu_dists_noble_main_binary-<arch>_Packages
...
ubuntu@lab:~$ ls /var/log/apt
eipp.log.xz  history.log  term.log
ubuntu@lab:~$ ls /var/cache/apt/archives/partial
ls: cannot open directory '/var/cache/apt/archives/partial': Permission denied
```

`type -a apt` binary'ni ikki yo'lda ko'rsatadi, chunki `/bin` `/usr/bin` ga symlink va ikkalasi `PATH` da; `/etc/apt` sozlamalar, `sources.list.d` da paketlar qayerdan olinishi; `/var/lib/apt/lists` yuklab olingan paket ro'yxatlari (apt'ning holati, `apt update` shu yerni yangilaydi); `/var/log/apt/history.log` nima o'rnatilgani tarixi; `/var/cache/apt/archives` yuklangan `.deb` fayllar keshi, uning `partial` papkasi faqat `_apt` tizim foydalanuvchisiga ochiq (`drwx------ _apt root`), shuning uchun `ubuntu` ga "Permission denied". Bu xato tizim buzilgani emas, ruxsat tizimi ishlayotganining belgisi (6-darsda).

Nima uchun bunday yoyiladi: `/etc` ni backup qilsangiz barcha sozlamalar bir joyda; `/var` ni alohida diskka qo'ysangiz loglar to'lib `/` ni to'xtatmaydi; `/usr` ni read-only qilib tizimni himoyalash mumkin, chunki u ish vaqtida o'zgarmaydi.

### "Hamma narsa fayl"

Kernel qurilmalar va o'z ichki holatini fayl ko'rinishida beradi, shuning uchun ularni `cat`, `echo`, `ls` bilan o'qish va yozish mumkin, alohida API yoki asbob kerak emas:

```
ubuntu@lab:~$ findmnt /proc
TARGET SOURCE FSTYPE OPTIONS
/proc  proc   proc   rw,nosuid,nodev,noexec,relatime
ubuntu@lab:~$ ls -l /proc/cpuinfo
-r--r--r-- 1 root root 0 <sana> /proc/cpuinfo
ubuntu@lab:~$ cat /proc/cpuinfo | wc -l
<N>
ubuntu@lab:~$ grep -c ^processor /proc/cpuinfo
2
```

`findmnt /proc`: `/proc` ga `proc` turidagi fayl tizimi mount qilingan, manbasi disk emas (`SOURCE proc`), `nosuid,nodev,noexec` xavfsizlik opsiyalari (undan dastur ishga tushirib bo'lmaydi). `ls -l /proc/cpuinfo` hajmni `0` deb ko'rsatadi, lekin `cat` o'nlab qator qaytaradi: fayl diskda saqlanmaydi, siz o'qigan paytda kernel mazmunni generatsiya qiladi, shuning uchun oldindan hajmi yo'q. `processor` qatorlari soni `2`, chunki VM `--cpus 2` bilan yaratilgan; `nproc` ham shuni aytadi, chunki u xuddi shu ma'lumotni kernel'dan oladi. Mac'dagi VM'da `/proc/cpuinfo` maydonlari boshqacha (ARM protsessorda `model name` o'rniga `CPU implementer`, `Features`), lekin `processor` qatorlari bir xil.

`/proc/<PID>/` har bir jarayon uchun papka: `status` (holat, PPid, xotira), `cmdline` (buyruq satri), `environ` (muhit o'zgaruvchilari), `exe` (binary'ga symlink), `cwd` (joriy papkaga symlink), `fd/` (ochiq fayllar). `ps`, `top`, `free` alohida sehr qilmaydi, shu fayllarni o'qib formatlaydi. `$$` bash'da joriy shell'ning PID'i, shuning uchun `ls -l /proc/$$/exe` hozir ishlayotgan shell binary'sini ko'rsatadi.

Qurilma fayllari `/dev` da:

```
ubuntu@lab:~$ ls -l /dev/null /dev/zero /dev/urandom /dev/tty
crw-rw-rw- 1 root root 1, 3 <sana> /dev/null
crw-rw-rw- 1 root tty  5, 0 <sana> /dev/tty
crw-rw-rw- 1 root root 1, 9 <sana> /dev/urandom
crw-rw-rw- 1 root root 1, 5 <sana> /dev/zero
```

Birinchi belgi `c`: character device (belgili qurilma), baytlar ketma-ket o'qiladi; disklar `b` (block device) bo'ladi, ularga bloklab tasodifiy murojaat qilinadi. Hajm o'rnida ikkita son `1, 3`: major va minor raqamlar, kernel qaysi drayver (major) va o'sha drayverdagi qaysi qurilma (minor) ekanini shu orqali biladi. `/dev/null` yozilgan hamma narsani yutadi, o'qisangiz darhol tugaydi (EOF); `/dev/zero` cheksiz nol baytlar; `/dev/urandom` tasodifiy baytlar; `/dev/tty` joriy terminal. `echo hello > /dev/null` keraksiz chiqishni yo'qotishning standart usuli, `head -c 8 /dev/urandom | od -An -tx1` kernel'dan 8 tasodifiy bayt olib hex ko'rinishda chiqaradi (`od` baytlarni ko'rsatadigan utilita, `-An` manzilsiz, `-tx1` har baytni hex).

`ls -l` chiqishidagi birinchi belgi fayl turi: `-` oddiy fayl, `d` papka, `l` symlink, `c` belgili qurilma, `b` blokli qurilma, `s` socket, `p` pipe.

**Tuzoq: `/tmp` va `/run` ga tayanmang.** `/run` xotirada (`tmpfs`), reboot'da bo'shaydi. `/tmp` ni tizim muddat bo'yicha tozalaydi. Reboot'dan keyin kerak bo'ladigan narsa `/var/lib` yoki uy papkasiga yoziladi.

### Real ishda qachon kerak

- Disk to'ldi: deyarli har doim `/var` (loglar, Docker image'lari, paket keshi). Qayerda qidirishni bilish birinchi daqiqada yechadi (8-darsda `du`, `df`).
- Servis sozlamasini topish: `/etc/<servis>/`, Dockerfile yoki Ansible'da shu yo'llar yoziladi.
- Monitoring agentlari (Prometheus node_exporter) `/proc` va `/sys` ni o'qiydi; Kubernetes resurs limitlari `/sys/fs/cgroup` orqali ishlaydi.
- Konteynerga volume ulashda qaysi papka holat (`/var/lib/<app>`) va qaysi biri konfiguratsiya (`/etc/<app>`) ekanini bilish.

### Nima uchun shunday

FHS tarix mahsuli: 1970-yillardagi Unix'da disk kichik edi, `/bin` va `/lib` birinchi (kichik) diskda, `/usr` (dastlab "user") ikkinchi diskda turardi. Keyin `/usr` dasturlar uchun bo'lib qoldi, `/home` esa foydalanuvchilar uchun ajratildi. Zamonaviy distributivlar "usr merge" qildi: `/bin`, `/sbin`, `/lib` ni `/usr` ga symlink qilib takrorlanishni yo'qotdi, shuning uchun `ls -l /` da o'sha `->` qatorlar. "Hamma narsa fayl" Unix'ning asosiy dizayn g'oyasi: bitta interfeys (`open`, `read`, `write`) fayl, qurilma, socket, kernel ma'lumotiga birdek ishlaydi, shuning uchun `cat`, `grep`, `>` kabi oddiy asboblar hamma narsaga yetadi. macOS da `/proc` yo'q, chunki XNU bu g'oyani qabul qilmagan, ma'lumot `sysctl` va alohida buyruqlar orqali olinadi; Linux'da esa `/proc` 1990-yillardan Plan 9 ta'sirida kengaygan.

## 4. Terminal, shell, buyruq

### Uchta alohida narsa

Siz "terminal ochdim va buyruq yozdim" deganda uchta dastur ishlaydi:

| Narsa | Nima | Misol |
|-------|------|-------|
| Terminal emulator | klaviaturani o'qib, matnni ekranga chizadigan oyna | GNOME Terminal, Terminal.app, VS Code terminal, ssh sessiyasi |
| TTY | kernel'dagi terminal qurilmasi, emulator va shell orasidagi kanal | `tty` buyrug'i: `/dev/pts/0` |
| Shell | buyruq satrini o'qib, dasturlarni ishga tushiradigan interpretator | `bash`, `zsh`, `sh` (Ubuntu'da `dash`) |

Terminal emulator o'z-o'zidan buyruq tushunmaydi, u faqat belgilarni uzatadi. **TTY** (teletype, tarixiy nom) kernel'dagi qurilma fayli, emulator bir tomondan, shell ikkinchi tomondan ulanadi; `/dev/pts/<N>` dagi `pts` pseudo-terminal, har yangi oyna yoki ssh sessiyasi yangi raqam oladi. **Shell** siz yozgan satrni so'zlarga bo'lib, birinchisini buyruq deb topib, qolganini argument qilib dasturga uzatadi, dastur tugaguncha kutadi va natija kodini oladi. `multipass shell lab` host'dagi terminal emulatorni VM ichidagi `bash` ga ulaydi: emulator host'da, TTY va shell VM'da.

### Misol: qaysi shell ishlayapti

```
ubuntu@lab:~$ echo $SHELL
/bin/bash
ubuntu@lab:~$ ps -p $$ -o comm=
bash
ubuntu@lab:~$ sh
$ echo $SHELL
/bin/bash
$ ps -p $$ -o comm=
sh
$ exit
ubuntu@lab:~$ ls -l /bin/sh
lrwxrwxrwx 1 root root 4 <sana> /bin/sh -> dash
```

`$SHELL` login shell'ni ko'rsatadi, ya'ni `/etc/passwd` da foydalanuvchiga yozilgan shell'ni, hozir ishlayotganini emas: `sh` ichiga kirganda ham `/bin/bash` qolaveradi. `ps -p $$ -o comm=` hozir ishlayotgan jarayon nomini ko'rsatadi (`$$` joriy shell PID'i, `-o comm=` faqat nom ustuni, sarlavhasiz) va u `sh` ga o'zgaradi. Prompt ham o'zgaradi: `dash` da oddiy `$`. `/bin/sh` Ubuntu'da `dash` ga symlink: kichik va tez POSIX shell, skriptlar uchun, lekin bash kengaytmalari (`[[ ]]`, massivlar) yo'q. `#!/bin/sh` bilan boshlangan skriptda bash sintaksisi ishlamasligining sababi shu. `cat /etc/shells` tizimdagi login shell sifatida ruxsat etilgan shell'lar ro'yxati.

Prompt haqida: `user@host:~$`. Oxiridagi `$` oddiy foydalanuvchi, `#` root. Hujjatlardagi qator boshidagi `$` yoki `#` buyruq qismi emas, ko'chirmang: `#` bilan ko'chirilgan qator shell'da kommentga aylanadi va jimgina hech narsa qilmaydi.

### Buyruq anatomiyasi

```
ls -l -a --human-readable /etc /var
# command | short options | long option | arguments
```

- Shell satrni bo'shliq bo'yicha so'zlarga bo'ladi: birinchi so'z buyruq, qolgani argumentlar. Buyruq o'zi argumentlardan qaysi biri flag (opsiya) ekanini `-` bo'yicha ajratadi, shell bunga aralashmaydi.
- Qisqa flag'lar birlashadi: `-l -a -h` va `-lah` bir xil. Uzun flag'lar `--` bilan boshlanadi, skriptlarda o'qishga oson (`--human-readable` `-h` bilan bir xil).
- Qiymatli flag: `head -n 5 file`, `head --lines=5 file`.
- Yakka `--` "flag'lar tugadi" degani: `rm -- -n` nomi `-n` bo'lgan faylni o'chiradi, `rm -n` esa `-n` ni flag deb o'qiydi:

```
ubuntu@lab:~$ rm -n
rm: invalid option -- 'n'
Try 'rm ./-n' to remove the file '-n'.
Try 'rm --help' for more information.
```

Xatoni o'qing: `rm` `-n` ni flag deb tushundi va bunday flag yo'q; ikkinchi qatorda yechimni o'zi aytadi (`./-n` yo'l sifatida yozish, `--` ning muqobili). Linux xatolari ko'pincha shunday: birinchi qator muammo, keyingisi maslahat.

- Bo'shliqli nom qo'shtirnoqda yoziladi, aks holda shell uni ikki argumentga bo'ladi (5-darsda quoting).

### Builtin va tashqi buyruq

`ls` bu diskdagi dastur (`/usr/bin/ls`): shell uni topib yangi jarayon sifatida ishga tushiradi. `cd` esa shell'ning o'z ichidagi buyruq (**builtin**). Sabab: joriy papka (cwd) har jarayonning o'z xususiyati, bola jarayon ota jarayonning papkasini o'zgartira olmaydi. `cd` alohida dastur bo'lsa, u o'zining papkasini o'zgartirib tugardi, shell'niki o'sha-o'sha qolardi.

```
ubuntu@lab:~$ type -a cd
cd is a shell builtin
ubuntu@lab:~$ type -a echo
echo is a shell builtin
echo is /usr/bin/echo
echo is /bin/echo
ubuntu@lab:~$ type -a ll
ll is aliased to `ls -alF'
ubuntu@lab:~$ which cd
ubuntu@lab:~$ echo $?
1
```

`type -a` nomning barcha ma'nolarini ko'rsatadi: `cd` faqat builtin; `echo` ham builtin, ham diskda dastur (builtin yutadi, chunki shell avval o'zinikini tekshiradi; `/usr/bin/echo` boshqa dasturlar `echo` ni ishga tushirishi uchun kerak); `ll` **alias**, ya'ni shell'dagi qisqartma (Ubuntu'ning standart `~/.bashrc` faylida belgilangan). `which` esa faqat `PATH` dagi papkalarda fayl qidiradi: builtin va alias haqida bilmaydi, `cd` uchun hech narsa chiqarmay exit code `1` qaytaradi. Shuning uchun `which` o'rniga `type` ishlating.

**PATH** bu shell buyruqni qidiradigan papkalar ro'yxati, `:` bilan ajratilgan: `echo $PATH` → `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:...`. Shell chapdan o'ngga birinchi topilganini ishga tushiradi, shuning uchun `/usr/local/bin` dagi dastur `/usr/bin` dagidan ustun. Node'dagi o'xshashi: `npx eslint` yoki `package.json` dagi `scripts` `node_modules/.bin` ni qidiradi, `npm run` buni avtomatik `PATH` ga qo'shadi. Mexanizm bir xil: nom → papkalar ro'yxati → birinchi topilgan fayl.

### Exit code

Har dastur tugaganda kernel'ga 0–255 oralig'ida son qaytaradi: **exit code**. `0` muvaffaqiyat, qolgani xato, ma'nosi dasturga qarab. Shell oxirgi buyruq kodini `$?` da saqlaydi. Node'da bu `process.exitCode` yoki `process.exit(1)`. Ko'p uchraydigan qiymatlar: `1` umumiy xato, `2` noto'g'ri ishlatish (flag xatosi), `127` buyruq topilmadi, `126` fayl bor lekin ishga tushirib bo'lmaydi, `128+N` dastur N raqamli signal'dan o'ldi (`Ctrl+C` bu SIGINT, raqami 2, shuning uchun `130`).

```
ubuntu@lab:~$ nosuchcommand
nosuchcommand: command not found
ubuntu@lab:~$ echo $?
127
```

Ubuntu'da `command-not-found` paketi o'rnatilgan bo'lsa, xabar uzunroq bo'lishi mumkin (`Command '...' not found` va qaysi paketda borligi haqida maslahat), exit code baribir `127`. `$?` faqat oxirgi buyruqqa tegishli: `echo $?` dan keyin yana `echo $?` desangiz `0` chiqadi, chunki birinchi `echo` muvaffaqiyatli tugadi.

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

`Ctrl+C` **signal**: kernel orqali dasturga yuboriladigan qisqa xabar (SIGINT, "interrupt"), dastur uni ushlab o'zicha reaksiya qilishi mumkin (Node'da `process.on('SIGINT', ...)`), ushlamasa o'ladi. `Ctrl+D` signal emas: terminal dasturga "stdin tugadi" (EOF) deb bildiradi, dastur kiritishni o'qib bo'lib odatdagidek tugaydi. Shuning uchun `sleep` ni `Ctrl+C` bilan to'xtatsangiz exit code `130`, `cat` ni `Ctrl+D` bilan tugatsangiz `0`. Farqi 9-darsda (signal'lar) muhim bo'ladi.

### Real ishda qachon kerak

- Skript serverda ishlamaydi, lokal ishlaydi: ko'pincha `#!/bin/sh` bilan bash sintaksisi yoki `PATH` da yo'q buyruq.
- CI'da qadam qizil: exit code `0` bo'lmagan buyruq pipeline'ni to'xtatadi, shuning uchun har buyruqning kodini bilish kerak.
- `which` bilan topilmagan buyruq aslida alias yoki funksiya bo'lishi mumkin (`type` ko'rsatadi).
- Konteynerda `Ctrl+C` ishlamaydi: PID 1 signal'ni qayta ishlamaydi (Docker modulida).

### Nima uchun shunday

Terminal, TTY va shell ajratilgani 1970-yillardan qolgan: o'shanda terminal haqiqiy apparat (klaviatura va printer yoki ekran) edi, simi orqali kompyuterga ulanardi, kernel'dagi TTY qatlami shu simni boshqarardi. Bugun apparat o'rnida emulator dasturi, lekin qatlamlar o'zgarmadi, shuning uchun ssh orqali uzoq serverga ulanish lokal terminal bilan bir xil ishlaydi. Shell'lar ko'p: Bourne shell (`sh`, 1979) standart bo'ldi, `bash` (Bourne Again Shell, 1989) uni kengaytirdi va Linux'da standart, `zsh` interaktiv qulayliklar qo'shdi va macOS'da standart, `dash` esa POSIX standartiga qattiq amal qilgan tez shell, Debian va Ubuntu uni `/bin/sh` qilib skriptlar tezroq ishlashini ta'minlagan. Serverlarda skriptlar `bash` yoki `sh` uchun yoziladi, chunki ular hamma joyda bor; `zsh` serverlarda odatda yo'q.

## 5. Yordam tizimi

### To'rt manba

| Vosita | Qachon | Misol |
|--------|--------|-------|
| `man` | to'liq, rasmiy hujjat | `man ls`, `man 5 passwd` |
| `--help` | tezkor flag ro'yxati | `ls --help` |
| `help` | bash builtin'lari (ularda `man` sahifasi yo'q) | `help cd` |
| `tldr` | amaliy misollar, 5–8 ta eng ko'p ishlatiladigan holat | `tldr tar` |
| `man -k` (`apropos`) | buyruq nomini bilmasangiz, kalit so'z bo'yicha qidiruv | `man -k partition` |

**man** (manual) bu tizimga paketlar bilan birga o'rnatiladigan hujjat sahifalari to'plami, internetsiz ishlaydi va aynan o'rnatilgan versiyaga mos. `--help` dasturning o'zi chiqaradigan qisqa yordam (GNU utilitalarining konvensiyasi, BSD'da ko'pincha yo'q). `help` bash'ning builtin buyrug'i, faqat builtin'lar haqida: `cd`, `type`, `echo`, `export`. Builtin'larning alohida man sahifasi yo'q, ular `man bash` ichida SHELL BUILTIN COMMANDS bo'limida.

### man bo'limlari

Bir nom bir nechta bo'limda bo'lishi mumkin: `passwd` ham buyruq (1), ham fayl formati (5).

| Bo'lim | Mazmuni | Misol |
|--------|---------|-------|
| 1 | foydalanuvchi buyruqlari | `man 1 ls` |
| 2 | system call'lar | `man 2 open` |
| 3 | kutubxona funksiyalari | `man 3 printf` |
| 4 | qurilma fayllari | `man 4 null` |
| 5 | fayl formatlari va konfiguratsiya | `man 5 passwd`, `man 5 sudoers` |
| 7 | umumiy mavzular | `man 7 signal`, `man 7 hier` |
| 8 | administrator buyruqlari | `man 8 mount` |

```
ubuntu@lab:~$ man -f passwd
passwd (1)           - change user password
passwd (1ssl)        - OpenSSL application commands
passwd (5)           - the password file
```

`man -f` (`whatis`) nom qaysi bo'limlarda borligini bir qatorlik tavsif bilan ko'rsatadi: `passwd (1)` parol o'zgartiradigan buyruq, `passwd (1ssl)` OpenSSL'ning ichki buyrug'i (bo'lim nomiga qo'shimcha harf qo'yilgan), `passwd (5)` `/etc/passwd` fayl formati. `man passwd` bo'limsiz yozilsa birinchi topilgani (1) ochiladi, fayl formati kerak bo'lsa `man 5 passwd` deb aniq yozish shart. Hujjatlarda `passwd(5)` yozuvi "5-bo'limdagi passwd sahifasi" degani.

### man sahifasini o'qish

```
ubuntu@lab:~$ man ls
LS(1)                            User Commands                           LS(1)

NAME
       ls - list directory contents

SYNOPSIS
       ls [OPTION]... [FILE]...

DESCRIPTION
       List  information  about  the FILEs (the current directory by default).
       Sort entries alphabetically if none of -cftuvSUX nor --sort  is  speci-
       fied.
```

Sarlavha `LS(1)`: nom va bo'lim. `NAME` bir qatorlik tavsif (`man -k` shu qatorda qidiradi). `SYNOPSIS` buyruqning shakli: `[ ]` ichidagisi ixtiyoriy, `...` takrorlanishi mumkin, `|` "yoki", katta harfli so'z siz qo'yadigan qiymat. `ls [OPTION]... [FILE]...` degani: istalgancha flag va istalgancha fayl, hammasi ixtiyoriy. `DESCRIPTION` da flag'lar ro'yxati keladi, odatda alifbo tartibida. Boshqa standart bo'limlar: `EXIT STATUS`, `ENVIRONMENT`, `FILES`, `EXAMPLES`, `SEE ALSO` (bog'liq sahifalar, ko'pincha eng foydali qism).

man sahifasi `less` ichida ochiladi. **less** bu uzun matnni sahifalab ko'rsatadigan dastur (pager): `Space` sahifa pastga, `b` yuqoriga, `/so'z` qidiruv, `n` keyingi topilma, `N` oldingisi, `g` va `G` boshi va oxiri, `h` less'ning o'z yordami, `q` chiqish. Flag qidirish usuli: `man ls`, keyin `/--sort` yoki `/ -S` (bo'shliq bilan, aks holda matn ichidagi har `S` topiladi). `man 7 hier` shu darsdagi FHS'ning tizimdagi tavsifi.

### tldr

`man tar` yuzlab qator, `tldr tar` bir ekran misol. `tldr` man o'rnini bosmaydi: misol bilan boshlaysiz, flag ma'nosini `man` dan tekshirasiz. Bir nechta klient bor, kursda Rust'da yozilgan `tealdeer` (buyruq nomi `tldr`), Ubuntu 24.04 repozitoriyasida bor. VM ichida o'rnatiladi (bu darsdagi yagona `sudo`):

```
ubuntu@lab:~$ sudo apt install tealdeer     # https://tealdeer-rs.github.io/tealdeer/installing.html
ubuntu@lab:~$ tldr --update                 # download the pages cache (needed once)
ubuntu@lab:~$ tldr tar
```

Mashina almashganda ikkinchi VM'da qayta o'rnatiladi (VM holati ko'chmaydi). O'rnatmasdan ham ishlatish mumkin: https://tldr.inbrowser.app.

**Tuzoq: minimal image'da hujjat yo'q.** `ubuntu:24.04` konteyner image'idan man sahifalari, `less`, `vim`, `nano` olib tashlangan, image kichik bo'lishi uchun. Konteynerda `man ls` deyilsa:

```
root@<id>:/# man ls
This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, including manpages, you can run the 'unminimize'
command. You will still need to ensure the 'man-db' package is installed.
root@<id>:/# less /etc/passwd
bash: less: command not found
```

`man` o'rnida shu xabarni chiqaradigan kichik skript turadi; `less` esa umuman yo'q (exit code `127`). Hujjatni VM'da o'qing. Production konteynerida ham shunday: debug qilishda `vi` yoki `less` topilmasligi normal holat, `cat`, `grep`, `head` bilan ishlanadi.

### Real ishda qachon kerak

- Internetdan topilgan buyruqni ishlatishdan oldin flag ma'nosini `man` dan tekshirish: flag distributiv va versiyaga qarab farq qiladi, `man` esa aynan sizdagi versiyani tavsiflaydi.
- Konfiguratsiya fayli formatini bilish: `man 5 sshd_config`, `man 5 crontab`, `man 5 fstab`.
- Buyruq nomini bilmasangiz: `man -k <kalit so'z>`.
- Serverda internet yo'q yoki cheklangan: `man` yagona hujjat.

### Nima uchun shunday

`man` 1971-yildagi birinchi Unix qo'llanmasidan kelgan, bo'lim raqamlari o'sha kitobning boblari: 1-bob buyruqlar, 2-bob system call'lar va hokazo, shuning uchun raqamlar bugungacha o'zgarmagan. Sahifalar dastur bilan birga paketda keladi, shuning uchun hujjat va dastur versiyasi har doim mos; veb hujjatda esa eng yangi versiya ko'rsatiladi, sizdagi eski bo'lishi mumkin. `--help` keyinroq GNU konvensiyasi sifatida paydo bo'ldi (BSD utilitalarida odatda yo'q, macOS'da `ls --help` xato beradi). `tldr` 2013-yilda jamoat loyihasi sifatida, man sahifalari misolsiz va uzun degan shikoyatga javob bo'lib paydo bo'ldi. Minimal image'lardan hujjat olib tashlanishi hajm va xavfsizlik uchun: kamroq fayl, kamroq zaiflik yuzasi, tezroq yuklanish.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Kernel | hardware'ni boshqaradigan va barcha dasturlarga xizmat ko'rsatadigan markaziy dastur, Linux aslida shu |
| User space | kernel'dan tashqarida, cheklangan rejimda ishlaydigan barcha dasturlar |
| System call | user space dasturining kernel'dan xizmat so'rash usuli (`open`, `read`, `fork`) |
| Userland | kernel'dan tashqaridagi dasturlar to'plami: shell, utilitalar, kutubxonalar |
| Distributiv | kernel + userland + paket menejeri + init + sozlamalar + qo'llab-quvvatlash siyosati |
| Paket menejeri | tizim dasturlarini o'rnatuvchi, yangilovchi va o'chiruvchi asbob (`apt`) |
| Arxitektura | protsessor turi: `x86_64` (`amd64`) yoki `aarch64` (`arm64`), binary'lar unga mos bo'lishi shart |
| Darwin / XNU | macOS'ning operatsion tizim yadrosi va kernel'i, Linux emas |
| BSD userland | macOS'dagi `ls`, `sed`, `grep` kelib chiqqan Unix oilasi, flag'lari GNU'dan farq qiladi |
| VM | o'z kernel'i va diskiga ega, host ichida dastur sifatida ishlaydigan to'liq kompyuter |
| Konteyner | host kernel'ida ishlaydigan, o'z fayl tizimi (image) va izolyatsiyalangan jarayonlariga ega guruh |
| Image | konteynerning boshlang'ich fayl tizimi, kernel'siz |
| Multipass | Ubuntu VM'larni bitta buyruq bilan yaratadigan asbob, `lab` VM shunda ishlaydi |
| Firmware / UEFI | platadagi chipda yashaydigan, yoqilganda birinchi ishlaydigan dastur va uning zamonaviy standarti |
| Bootloader (GRUB) | kernel va initramfs'ni diskdan xotiraga yuklaydigan dastur |
| initramfs | root diskni topish uchun kernel bilan birga yuklanadigan kichik vaqtinchalik fayl tizimi |
| PID | kernel har jarayonga beradigan raqam |
| PID 1 / init | kernel ishga tushiradigan birinchi user space jarayon, qolgan hamma uning avlodi |
| systemd | zamonaviy Linux'da PID 1 va servis menejeri |
| Target | systemd'da tizim holati (`multi-user.target`, `graphical.target`) |
| Unit | systemd boshqaradigan obyekt, ko'pincha servis (`*.service`) |
| Journal | systemd'ning markaziy log bazasi, `journalctl` o'qiydi |
| FHS | Filesystem Hierarchy Standard, nima qaysi papkada yotishini belgilaydi |
| Mount | fayl tizimini daraxtdagi papkaga ulash |
| Virtual fayl tizimi | diskda yo'q, kernel o'qilgan paytda generatsiya qiladigan fayl tizimi (`proc`, `sysfs`, `tmpfs`) |
| Symlink | boshqa yo'lga ishora qiluvchi fayl, `ls -l` da `->` bilan |
| Device file | `/dev` dagi qurilma fayli, `c` (belgili) yoki `b` (blokli) |
| Terminal emulator | klaviaturani o'qib matnni ekranga chizadigan dastur |
| TTY | kernel'dagi terminal qurilmasi, emulator va shell orasidagi kanal |
| Shell | buyruq satrini o'qib dasturlarni ishga tushiradigan interpretator (`bash`, `zsh`, `dash`) |
| Builtin | shell'ning o'z ichidagi buyruq, alohida dastur emas (`cd`, `type`) |
| Alias | shell'dagi buyruq qisqartmasi (`ll`) |
| PATH | shell buyruqni qidiradigan papkalar ro'yxati |
| Exit code | dastur tugaganda qaytaradigan 0–255 son, `0` muvaffaqiyat, `$?` da |
| Signal | kernel orqali jarayonga yuboriladigan qisqa xabar (SIGINT, `Ctrl+C`) |
| EOF | kiritish tugaganini bildiruvchi holat, terminalda `Ctrl+D` |
| man bo'limi | man sahifasining kategoriyasi: 1 buyruq, 5 fayl formati, 8 administrator buyrug'i |
| Pager (`less`) | uzun matnni sahifalab ko'rsatadigan dastur |

## Tuzoqlar

- Konteyner ichidagi `uname -r` host kernel'ini (Mac'da Docker Desktop VM kernel'ini) ko'rsatadi. Distributivni `/etc/os-release` dan, kernel'ni `uname` dan aniqlang, ikkalasini aralashtirmang.
- macOS'da o'rganilgan flag serverda ishlamasligi mumkin (`sed -i ''`, BSD `ls`, `date`). Linux buyruqlarini `lab` VM'da sinang, host'da emas.
- `/usr` ostiga qo'lda fayl qo'ymang, paket yangilanishi ustidan yozadi. Qo'lda o'rnatiladigan narsa `/usr/local` yoki `/opt` ga.
- Diskni to'ldiradigan joy deyarli har doim `/var` (loglar, Docker ma'lumotlari, kesh). `/var` to'lsa servislar yoza olmay to'xtaydi.
- `/tmp` va `/run` dagi fayl reboot'dan keyin yo'q. PID fayl yoki socket'ni `/run` ga, saqlanadigan holatni `/var/lib` ga yozing.
- `$SHELL` hozirgi shell emas. Skript qaysi interpretatorda ishlashini birinchi qatordagi shebang (`#!`) belgilaydi, `$SHELL` emas.
- `#!/bin/sh` Ubuntu'da `dash`. Bash sintaksisi yozilgan skript lokal ishlab, serverda yoki CI'da sinadi.
- Hujjatdagi buyruq boshidagi `$` va `#` prompt belgisi. `#` bilan ko'chirilgan qator shell'da kommentga aylanadi va jimgina hech narsa qilmaydi.
- `which` builtin va alias'ni ko'rmaydi, "topilmadi" degani buyruq yo'q degani emas. `type -a` ishlating.
- "Permission denied" ko'rganda darhol `sudo` qo'ymang: avval nima uchun yopiq ekanini tushuning. VM'da `sudo` parolsiz, bu odatni yomon tomonga buzishi mumkin.
- Internetdan topilgan buyruqni `man` yoki `--help` bilan tekshirmasdan `sudo` bilan ishlatmang. Flag ma'nosi distributiv va versiyaga qarab farq qilishi mumkin.

## Manbalar

- https://www.kernel.org/doc/html/latest/admin-guide/README.html – kernel nima va u qanday tarqatiladi
- https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html – Filesystem Hierarchy Standard 3.0
- https://man7.org/linux/man-pages/man7/hier.7.html – `hier(7)`, fayl tizimi ierarxiyasi
- https://man7.org/linux/man-pages/man7/bootup.7.html – `bootup(7)`, systemd bilan yuklanish ketma-ketligi
- https://man7.org/linux/man-pages/man5/proc.5.html – `proc(5)`, `/proc` dagi har bir fayl
- https://man7.org/linux/man-pages/man1/uname.1.html – `uname(1)`, maydonlar ma'nosi
- https://www.freedesktop.org/software/systemd/man/latest/os-release.html – `/etc/os-release` maydonlari
- https://www.gnu.org/software/bash/manual/bash.html – Bash Reference Manual
- https://documentation.ubuntu.com/multipass/ – Multipass hujjati (`lab` VM)
- https://docs.docker.com/desktop/setup/install/mac-install/ – Docker Desktop macOS'da, yashirin Linux VM haqida
- https://tldr.sh – tldr pages loyihasi
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 1–6 boblar
- Nemeth va boshq., "UNIX and Linux System Administration Handbook" (5-nashr) – 1 va 2 boblar

## Birga bajaramiz

Bitta jarayonni tug'ilishidan o'limigacha kuzatamiz va yo'lda darsdagi hamma qatlamni ko'ramiz: shell, PATH, binary'ning paketi, `/proc`, kernel, man, signal, exit code. Misol `sleep` buyrug'i, u berilgan soniya hech narsa qilmay turadi, kuzatish uchun qulay. Hamma narsa VM ichida.

1. VM'ga kiring va qayerda turganingizni aniqlang:

```
$ multipass shell lab
ubuntu@lab:~$ uname -sr
Linux 6.8.0-<NN>-generic
ubuntu@lab:~$ tty
/dev/pts/0
```

`uname -sr` kernel nomi va release: Linux kernel, Ubuntu'ning 6.8 kernel'i (host qanday bo'lishidan qat'i nazar). `tty` sizning terminal qurilmangiz, birinchi sessiya `pts/0`.

2. `sleep` nima va qayerdan keladi:

```
ubuntu@lab:~$ type -a sleep
sleep is /usr/bin/sleep
sleep is /bin/sleep
ubuntu@lab:~$ dpkg -S /usr/bin/sleep
coreutils: /usr/bin/sleep
ubuntu@lab:~$ man -f sleep
sleep (1)            - delay for a specified amount of time
```

`type -a` tashqi dastur ekanini aytadi (builtin emas), ikki yo'l `/bin -> usr/bin` symlink tufayli. `dpkg -S` fayl qaysi paketdan kelganini aytadi: `coreutils`, ya'ni `ls` va `cat` bilan bir paket, kernel emas. `man -f` 1-bo'limda (foydalanuvchi buyrug'i) sahifasi borligini ko'rsatadi.

3. Jarayonni fonda ishga tushiring va PID'ini oling:

```
ubuntu@lab:~$ sleep 300 &
[1] <PID>
ubuntu@lab:~$ echo $!
<PID>
```

Oxiridagi `&` buyruqni fonda ishga tushiradi, shell kutmaydi va prompt qaytadi. `[1]` job raqami, keyingi son PID. `$!` oxirgi fon jarayonining PID'i. Keyingi buyruqlarda `<PID>` o'rniga o'zingizdagi raqamni yozing.

4. Kernel bu jarayon haqida nimalarni biladi:

```
ubuntu@lab:~$ cat /proc/<PID>/comm
sleep
ubuntu@lab:~$ ls -l /proc/<PID>/exe
lrwxrwxrwx 1 ubuntu ubuntu 0 <sana> /proc/<PID>/exe -> /usr/bin/sleep
ubuntu@lab:~$ tr '\0' ' ' < /proc/<PID>/cmdline; echo
sleep 300
ubuntu@lab:~$ grep -E '^(Name|State|Pid|PPid|Threads|VmRSS)' /proc/<PID>/status
Name:	sleep
State:	S (sleeping)
Pid:	<PID>
PPid:	<shell PID>
VmRSS:	    <N> kB
Threads:	1
```

`comm` jarayon nomi; `exe` ishga tushirilgan binary'ga symlink (shell `PATH` dan topgan fayl); `cmdline` buyruq satri, argumentlar `\0` (nol bayt) bilan ajratilgan, shuning uchun `tr` bilan bo'shliqqa almashtirdik; `status` da `State: S (sleeping)` jarayon kernel'da kutib turibdi (CPU ishlatmaydi), `PPid` ota jarayon, bu sizning shell'ingiz (`echo $$` bilan solishtiring), `VmRSS` xotirada egallagan hajm, `Threads` ip soni. Hammasi fayl, hammasi `cat` va `grep` bilan o'qildi.

5. Jarayonning ochiq fayllari:

```
ubuntu@lab:~$ ls -l /proc/<PID>/fd
total 0
lrwx------ 1 ubuntu ubuntu 64 <sana> 0 -> /dev/pts/0
lrwx------ 1 ubuntu ubuntu 64 <sana> 1 -> /dev/pts/0
lrwx------ 1 ubuntu ubuntu 64 <sana> 2 -> /dev/pts/0
```

`fd` (file descriptor) jarayon ochgan fayllar raqamlari: `0` stdin, `1` stdout, `2` stderr, uchalasi sizning terminal qurilmangizga (`tty` ko'rsatgan `/dev/pts/0`) ulangan, chunki `sleep` shell'dan terminalni meros qilib oldi. `sleep` boshqa fayl ochmaydi, shuning uchun ro'yxat uchta.

6. Kernel haqida xuddi shu usulda:

```
ubuntu@lab:~$ grep -c ^processor /proc/cpuinfo
2
ubuntu@lab:~$ grep MemTotal /proc/meminfo
MemTotal:        <N> kB
ubuntu@lab:~$ findmnt /proc
TARGET SOURCE FSTYPE OPTIONS
/proc  proc   proc   rw,nosuid,nodev,noexec,relatime
```

Jarayon haqidagi ham, CPU va xotira haqidagi ma'lumot ham bitta virtual fayl tizimida. `MemTotal` taxminan 2 GB (`--memory 2G`), kernel o'ziga ozgina ajratib qolgani uchun aniq 2097152 kB chiqmaydi.

7. Jarayonni signal bilan tugating va kodini o'qing:

```
ubuntu@lab:~$ kill <PID>
ubuntu@lab:~$ wait <PID>; echo $?
[1]+  Terminated              sleep 300
143
ubuntu@lab:~$ ls /proc/<PID>
ls: cannot access '/proc/<PID>': No such file or directory
```

`kill` nomiga qaramay signal yuboradi, standart signal SIGTERM (raqami 15, "iltimos tugat"). `sleep` uni ushlamaydi va o'ladi. `[1]+ Terminated` qatori interaktiv shell'ning fon job tugagani haqidagi xabari (keyingi prompt'da chiqadi, o'rni biroz farq qilishi mumkin). `wait` fon jarayon tugashini kutib uning exit code'ini `$?` ga qo'yadi: `143 = 128 + 15`, ya'ni "15-signal'dan tugadi". `Ctrl+C` bo'lsa SIGINT (2) va `130` bo'lardi. Jarayon o'lgach kernel `/proc/<PID>` papkasini yo'q qiladi: u diskda yo'q edi, jarayon bilan birga ketdi.

8. Oxirida man sahifasida tekshirish: `man 1 sleep` ni oching, `/SUFFIX` deb qidiring (`sleep 5m` kabi yozuvlar), `q` bilan chiqing. Keyin `man 7 signal` da `/SIGTERM` qidirib raqamini toping. VM'dan `exit` bilan chiqing.

Shu 8 qadamda ko'rganingiz: buyruq shell orqali PATH'dan topildi (4-bo'lim), binary paketdan keladi, kernel'dan emas (1-bo'lim), kernel jarayon haqida hamma narsani `/proc` da fayl sifatida beradi (3-bo'lim), signal va exit code jarayon hayotini tugatadi (4-bo'lim), `man` esa hammasini tasdiqlaydi (5-bo'lim).

---

## Vazifalar

Ish papkasi: `linux/01-intro/` (`make new m=linux n=01 name=intro` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (butun chiqish emas) va o'z so'zingiz bilan izoh. Agar vazifa VM'da bajarilgan bo'lsa, natijani README'ga qo'lda ko'chiring yoki `multipass exec lab -- <buyruq>` orqali host'da oling. Barcha buyruqlar `lab` VM ichida bajariladi, aksi aytilgan joylarda (`docker run`) host'da. `sudo` ishlatilmaydi (20-vazifadagi o'rnatishdan tashqari). "Zorin'da" yoki "macOS'da" deb belgilangan qismlar ixtiyoriy, o'sha mashinada bo'lsangiz qo'shing.

### A. Kernel va distributiv

1. **Kernel version.** VM'da `uname -r`, `uname -a` va `cat /proc/version` ni bajaring. `uname -a` chiqishidagi har bir maydon nimani bildirishini `man uname` dan topib yozing (qaysi flag qaysi maydonni beradi). Kernel versiyasi qaysi fayldan o'qiladi va `uname` o'sha ma'lumotni qayerdan oladi? Ixtiyoriy: host'da `uname -sr` ni bajaring (Zorin'da Linux, macOS'da Darwin) va VM bilan solishtiring. Yo'nalish: 1-bo'lim, "Misol: kernel'dan va distributivdan so'rash".

2. **Distro identity.** VM'da `cat /etc/os-release` ni bajaring. `ID`, `ID_LIKE`, `VERSION_ID`, `VERSION_CODENAME` qiymatlarini yozing va har biri nima uchun kerakligini izohlang. `ID_LIKE` maydoni install skripti yozuvchi uchun nimani anglatadi? `ls -l /etc/os-release` nima ko'rsatadi, fayl aslida qayerda? Ixtiyoriy: Zorin host'ida `ID_LIKE` nima uchun ikkita qiymatga ega; macOS'da bu fayl yo'q, `sw_vers` nima qaytaradi? Yo'nalish: 1-bo'lim, "Distributiv".

3. **Shared kernel.** Host'da `docker run --rm ubuntu:24.04 uname -r` va `docker run --rm ubuntu:24.04 cat /etc/os-release` ni bajaring. Natijani VM'dagi (`multipass exec lab -- uname -r`) va host'dagi `uname -r` bilan uchta ustunli jadvalga yozing. Qaysi juftliklar bir xil, qaysilari farq qiladi va nima uchun? Mac'da konteyner kernel'i nimaniki? Shundan kelib chiqib: konteyner image'ini almashtirish bilan kernel versiyasini o'zgartirish mumkinmi? Yo'nalish: 1-bo'lim, "Konteyner va VM: kernel kimniki".

4. **Userland origin.** VM'da `type -a ls`, `ls --version | head -1` va `dpkg -S /usr/bin/ls` ni bajaring. `ls` qaysi paketdan keladi? Shu paketdagi yana 5 ta buyruqni `dpkg -L coreutils | grep /usr/bin/ | head` orqali toping va har biri nima qilishini `man -f` bilan bir qatorda yozing. `ls` kernel'ning qismimi? `type -a ls` nima uchun ikki qator chiqaradi? Yo'nalish: 1-bo'lim, "Mexanizm: kernel space va user space".

### B. Boot

5. **Boot artifacts.** VM'da `ls -lh /boot` va `cat /proc/cmdline` ni bajaring. Qaysi fayl kernel, qaysi biri initramfs, qaysilari symlink va nimaga ko'rsatadi? Kernel yangilangandan keyin nima uchun bir nechta versiya qoladi? `/proc/cmdline` dagi `BOOT_IMAGE=`, `root=` va `ro` parametrlari nimani bildiradi? `ls /sys/firmware/efi` bor-yo'qligidan VM'ingiz UEFI yoki BIOS bilan yuklanganini aniqlang. Yo'nalish: 2-bo'lim, "Bosqichlar".

6. **PID 1.** VM'da `ps -p 1 -o pid,ppid,user,comm,args` ni, host'da `docker run --rm ubuntu:24.04 ps -p 1 -o pid,comm` ni, keyin `docker run --rm -it ubuntu:24.04 bash` ichida `cat /proc/1/comm` ni bajaring. Uch natija nima uchun farq qiladi? VM'da `comm` va `args` ustunlari nima uchun bir xil emas (`ls -l /sbin/init` bilan tekshiring)? Konteynerda PID 1 nima bo'lishini kim belgilaydi? Yo'nalish: 2-bo'lim, "PID 1" va "Konteynerda boot yo'q".

7. **Boot timing.** VM'da `systemd-analyze` va `systemd-analyze blame | head -10` ni bajaring. Yuklanish qaysi bosqichlarga bo'lingan va har biriga qancha vaqt ketgan? Har bosqichni 2-bo'limdagi jadval qatoriga bog'lang. `systemctl get-default` nima qaytaradi va bu nima uchun desktop'dagidan farq qiladi? Eng sekin unit nima ish qiladi (`systemctl status <unit>` bilan qarang, chiqishning `Loaded` va `Active` qatorlarini izohlang)? Yo'nalish: 2-bo'lim, "Misol: yuklanish qancha vaqt oldi".

8. **Kernel messages.** VM'da `journalctl -k -b | head -30` ni bajaring: kernel versiyasi, command line va CPU haqidagi qatorlarni toping va ular `/proc/version`, `/proc/cmdline` bilan mos ekanini ko'rsating. Keyin `sudo` siz `dmesg` ni bajaring, xatoni so'zma-so'z yozing va nima uchun oddiy foydalanuvchiga yopiqligini izohlang (`sysctl kernel.dmesg_restrict` qiymatiga qarang). `journalctl -k` nima uchun ishladi (`id` buyrug'i bilan guruhlaringizni ko'ring)? Yo'nalish: 2-bo'lim, "Misol: kernel'ga berilgan parametrlar va kernel xabarlari".

### C. Fayl tizimi

9. **Root tour.** VM'da `ls -l /` ni bajaring. Har bir papka uchun bitta gapda nima saqlanishini o'z so'zingiz bilan jadvalga yozing (darsdagi jadvalni ko'chirmang, har papkadan `ls` bilan topilgan bitta real fayl yoki ichki papka misol keltiring). Qaysilari symlink va qayerga ko'rsatadi? `proc` va `sys` hajmi nima uchun `0`? Mac'dagi VM'da `lib64` yo'q, Zorin'dagida bor: sababini yozing. Yo'nalish: 3-bo'lim, "Bitta daraxt".

10. **One program, four places.** VM'da `sshd` (openssh-server) misolida to'rt savolga javob toping: binary qayerda (`type -a sshd`), konfiguratsiya qayerda (`ls /etc/ssh`), ma'lumoti va logi qayerda (`systemctl status ssh` dagi log qatorlari, `journalctl -u ssh | head`). Keyin `cloud-init` uchun xuddi shu to'rt savolga javob bering (binary, `/etc/cloud`, `/var/lib/cloud`, `/var/log/cloud-init*.log`). Oxirida `ls /var/cache/apt/archives/partial` ni bajaring: xatoni yozing va `ls -ld` orqali nima uchun yopiq ekanini izohlang. Yo'nalish: 3-bo'lim, "Misol: bitta dastur, to'rt joy".

11. **Virtual filesystems.** VM'da `findmnt /proc`, `findmnt /sys`, `findmnt /run` va `ls -l /proc/cpuinfo` ni bajaring. Uch fayl tizimining `SOURCE` va `FSTYPE` ustunlarini izohlang. Fayl hajmi nima uchun 0, lekin `cat /proc/cpuinfo | wc -l` nolga teng emas? `/proc/meminfo` dan `MemTotal` va `MemAvailable` ni, `/proc/cpuinfo` dan yadrolar sonini toping, keyin `free -h` va `nproc` bilan solishtiring. Bu raqamlar `multipass launch` dagi qaysi flag'lardan kelgan? Yo'nalish: 3-bo'lim, "Hamma narsa fayl".

12. **Process as files.** VM'da `echo $$` bilan shell PID'ini oling. `/proc/$$/` ichidan: `exe` qayerga ko'rsatadi, `cmdline` da nima bor, `status` dagi `PPid` kimga tegishli (`ps -p <PPid> -o pid,comm,args`), `cwd` nima? Boshqa papkaga `cd` qilib `ls -l /proc/$$/cwd` ni qayta ko'ring. `ls -l /proc/$$/fd` da nechta fayl bor va ular qayerga ulangan? Yo'nalish: 3-bo'lim, "Hamma narsa fayl" va "Birga bajaramiz".

13. **Device files.** VM'da `ls -l /dev/null /dev/zero /dev/urandom /dev/tty` va `lsblk` ni bajaring. `ls -l` chiqishidagi birinchi belgi (`c`, `b`) nimani bildiradi, hajm o'rnidagi ikki son nima? `lsblk` dagi VM diskingiz `/dev` da qaysi nom bilan turadi (`ls -l /dev/<nom>`), birinchi belgisi nima va hajmi `multipass launch` dagi qaysi flag'ga mos? `echo test > /dev/null; echo $?` va `head -c 8 /dev/urandom | od -An -tx1` natijalarini izohlang. Yo'nalish: 3-bo'lim, "Hamma narsa fayl".

### D. Terminal va shell

14. **Which shell.** VM'da `echo $SHELL`, `ps -p $$ -o comm=`, `cat /etc/shells`, `ls -l /bin/sh` ni bajaring. Keyin `sh` ni ishga tushirib birinchi ikkitasini qayta bajaring, `exit` bilan qayting. Qaysi qiymat o'zgardi, qaysi biri yo'q va nima uchun? Prompt qanday o'zgardi? `tty` nima qaytaradi, ikkinchi terminal oynasidan `multipass shell lab` qilib qarasangiz-chi? Ixtiyoriy: host'da `echo $SHELL` (ikkala host'da `zsh` bo'lishi mumkin). Yo'nalish: 4-bo'lim, "Misol: qaysi shell ishlayapti".

15. **Builtin or binary.** VM'da `type -a` ni `cd`, `ls`, `echo`, `pwd`, `type`, `man`, `ll` uchun bajaring. Har birini turga ajrating (builtin, fayl, alias) va bir xil nom ikki turda bo'lsa qaysi biri ishlashini yozing. `which cd` nima qaytaradi va `echo $?` qancha? Nima uchun `cd` tashqi dastur bo'la olmaydi? `ll` alias qayerda belgilangan (`grep ll ~/.bashrc`)? Yo'nalish: 4-bo'lim, "Builtin va tashqi buyruq".

16. **Command anatomy.** VM'da `ls -l -a -h /etc`, `ls -lah /etc` va uzun flag'lar bilan yozilgan ekvivalentini (flag nomlarini `ls --help` dan toping) bajaring va bir xil ekanini ko'rsating (`| head -3` yetadi). Uy papkasida `touch -- -n` bilan `-n` nomli fayl yarating, uni `rm -n` bilan o'chirib ko'ring, xatoni to'liq yozing va xatoning o'zi taklif qilgan ikki yechimni sinang. `echo $?` xatodan keyin qancha? Yo'nalish: 4-bo'lim, "Buyruq anatomiyasi".

17. **Keyboard signals.** VM'da `sleep 100` ni `Ctrl+C` bilan to'xtating va darhol `echo $?` ni ko'ring. `cat` ni argumentsiz ishga tushiring, ikki qator yozing va `Ctrl+D` bilan tugating, `echo $?` ni ko'ring. Ikki exit code nima uchun farq qiladi, `130` qanday hisoblanadi? Mavjud bo'lmagan buyruq yozib `echo $?` ni ko'ring. `Ctrl+R` bilan shu darsdagi `systemd-analyze` buyrug'ini tarixdan toping va qanday qilganingizni yozing. Yo'nalish: 4-bo'lim, "Exit code" va "Kerakli klavishlar".

### E. Yordam tizimi

18. **man sections.** VM'da `man -f passwd` ni bajaring. `man passwd` va `man 5 passwd` nima haqida, bo'limsiz `man passwd` qaysi birini ochadi? `man 5 passwd` dan `/etc/passwd` qatoridagi 7 ta maydon nomini yozing va o'z foydalanuvchingiz qatorini (`grep "^$USER:" /etc/passwd`) shu bo'yicha maydon-maydon izohlang. Oxirgi maydon 14-vazifadagi `$SHELL` bilan mosmi? Yo'nalish: 5-bo'lim, "man bo'limlari".

19. **Reading a man page.** VM'da faqat `man ls` dan foydalanib (qidiruv: `/`) quyidagilarni bajaradigan flag'larni toping va `/var/log` da sinang: hajm bo'yicha saralash, vaqt bo'yicha saralash, teskari tartib, faqat papkaning o'zini ko'rsatish, inode raqamini chiqarish. Har flag uchun qisqa va uzun shaklini yozing. `man ls` SYNOPSIS qatoridagi `[ ]` va `...` nimani anglatadi? `less` ichida qidiruvda `n` va `N` nima qiladi? Yo'nalish: 5-bo'lim, "man sahifasini o'qish".

20. **Three help sources.** VM'da `man cd`, `cd --help` va `help cd` ni bajaring: har birining natijasini va `echo $?` ni yozing, qaysi biri `cd` ning haqiqiy hujjati va nima uchun (`cd` qaysi turdagi buyruq)? `man bash` ichida `/SHELL BUILTIN` qidirib `cd` ni toping. VM'da `sudo apt install tealdeer` va `tldr --update` ni bajarib `tldr tar` va `man tar` ni solishtiring: papkani `.tar.gz` ga yig'ish buyrug'ini har ikkisidan toping, qaysi birida tezroq topdingiz? `man -k "copy files"` nima qaytaradi? Yo'nalish: 5-bo'lim, "To'rt manba" va "tldr".

21. **Minimal image.** Host'da `docker run --rm -it ubuntu:24.04 bash` ichida `man ls`, `less /etc/passwd`, `vi`, `nano` ni bajarib ko'ring, har birining natijasini va `echo $?` ni yozing (ikki xil natija bor: xabar chiqargan va "command not found"). `ls /usr/bin | wc -l` ni konteynerda va VM'da solishtiring. Image nima uchun bunday qisqartirilgan va bu production'da debug qilishga qanday ta'sir qiladi? Mac'da konteyner ichida `uname -m` nima ko'rsatadi, Zorin'da-chi? Yo'nalish: 5-bo'lim, "Tuzoq: minimal image'da hujjat yo'q".

### F. Yakuniy

22. **System passport.** README'da `lab` VM'ning "pasporti" jadvalini tuzing, ustunlar: xususiyat, qiymat, qaysi buyruq yoki fayldan olindi. Qatorlar: kernel versiyasi, arxitektura, distributiv va versiya, asos distributiv (`ID_LIKE`), firmware turi (UEFI yoki BIOS), PID 1, standart target (`systemctl get-default`), login shell, `/bin/sh` nimaga ko'rsatadi, CPU yadrolari, umumiy xotira, root fayl tizimi turi (`findmnt /`), oxirgi yuklanish vaqti (`uptime -s` yoki `who -b`), hostname. Xuddi shu jadvalni `ubuntu:24.04` konteyneri uchun to'ldiring va javob olib bo'lmaydigan qatorlarga sababini yozing. Ixtiyoriy uchinchi ustun: host (Zorin'da Linux buyruqlari ishlaydi; macOS'da `uname -sr`, `uname -m`, `sw_vers`, `ps -p 1 -o comm=`, `echo $SHELL` yetadi, qolganiga "Linux emas" deb yozing). Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `linux/01-intro/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; VM, konteyner yoki host'da bajarilgani aniq ko'rinadi.
3. `make check` toza o'tadi (host'da).
4. `docker ps -a` da shu darsdan qolgan konteyner yo'q; `multipass list` da `lab` `Running` yoki `Stopped` holatda (o'chirilmagan).
5. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Kernel va distributiv farqi nima, `ls` qaysi biriga tegishli?
- Nima uchun konteyner ichida `uname -r` host kernel'ini ko'rsatadi, VM ichida esa yo'q? Mac'da konteyner qaysi kernel'ni ko'rsatadi va nima uchun?
- macOS nima uchun Linux emas, lekin unda ham `ls`, `/etc`, PID 1 bor? Kurs nima uchun VM'da o'tiladi?
- Yuklanish bosqichlarini tartib bilan ayting. initramfs qaysi muammoni yechadi?
- PID 1 nima va konteynerda u nima bo'ladi? `systemd` va `pm2` o'xshashligi qayerda tugaydi?
- Bitta servisning binary, konfiguratsiya, ma'lumot va log fayllari qaysi papkalarda yotadi va nima uchun bir papkada emas?
- `/proc` dagi fayllar hajmi nima uchun 0 va ularni kim "yozadi"?
- `/tmp`, `/run` va `/var/lib` orasidagi farq nima?
- Terminal emulator, TTY va shell orasidagi farq nima? `multipass shell lab` da uchalasi qayerda ishlaydi?
- `cd` nima uchun builtin? `which` va `type` farqi nima?
- Exit code `0`, `1`, `127` va `130` nimani bildiradi? `Ctrl+C` va `Ctrl+D` farqi nima?
- `man 5 passwd` dagi `5` nimani bildiradi? `man`, `--help`, `help`, `tldr` har birini qachon ishlatasiz?
