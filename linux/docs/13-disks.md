# 13-dars: Disk va fayl tizimlari

Maqsad: "disk" dan "katalogdagi fayl" gacha bo'lgan qatlamlarni noldan tushunish: block device, partition, (ixtiyoriy) LVM, fayl tizimi, mount nuqtasi. 8-darsda `df` va `du` bilan bo'sh joyni ko'rdingiz, 6-darsda inode va link bilan tanishdingiz; bu darsda shu narsalar qanday yaratilishi, daraxtga ulanishi va kengaytirilishini o'rganasiz. Amaliy natija: yangi diskni formatlab, reboot'dan keyin ham saqlanadigan qilib mount qilish, to'lgan volume'ni servisni to'xtatmasdan kengaytirish, swap sozlash. Frontend ishida disk siz uchun "loyiha papkasi" edi va uning ostida nima borligi ko'rinmasdi. Serverda esa "disk to'ldi", "volume ulanmadi", "reboot'dan keyin ma'lumot yo'q" degan hodisalar aynan shu qatlamlarda yuz beradi. Cloud'da volume ulash, Kubernetes'dagi PersistentVolume va Docker volume'lar shu tushunchalarga tayanadi. Dars oxirida 8–13-darslarni birlashtiruvchi mini-loyiha bor.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar, "Birga bajaramiz" va A guruh vazifalari; ikkinchi kun 3–4 bo'limlar va B guruhi; uchinchi kun 5–6 bo'limlar, C va D guruhlari; to'rtinchi va beshinchi kun E guruhi (mini-loyiha), tozalash va README. Diqqatni quyidagilarga qarating: qatlamlar tartibi, inode tugashi, `/etc/fstab` da UUID va `nofail`, `mount -a` bilan tekshirmasdan reboot qilmaslik, LVM'da kengaytirish ikki qadam ekani (LV, keyin fayl tizimi), xfs kichraytirilmasligi.

Qanday o'qish kerak: har bo'limdagi misolni `lab` VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi qurilma nomlari, UUID'lar va hajmlar farq qiladi, bu normal; darsda bunday joylar `<...>` bilan yoki `/dev/loopA` kabi shartli nom bilan belgilangan. Bu darsdagi buyruqlarning yarmi ma'lumotni qaytarib bo'lmas qilib o'chira oladi, shuning uchun har o'zgartiruvchi buyruqdan oldin `lsblk` bilan qurilma nomini tekshirish odatini shu yerda shakllantiring.

## Laboratoriya

Bu dars to'liq `SETUP.md` bo'yicha yaratilgan `lab` virtual mashinasi (Multipass, Ubuntu 24.04, 10G disk) ichida bajariladi. Host'ning (Zorin yoki macOS) diskiga hech bir vazifa tegmaydi. Multipass VM'ga ikkinchi disk ulashning oddiy buyrug'i yo'q, shuning uchun "disk" sifatida **loop device** ishlatiladi: VM ichidagi oddiy fayl kernel'ga block device qilib ko'rsatiladi. Real serverda farq faqat nomda (`/dev/vdb`, `/dev/nvme1n1`), buyruqlar bir xil.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | `make`, `git`, `multipass` (snapshot, restore), `shellcheck` |
| `lab` VM | `ubuntu@lab:~$` | darsdagi barcha buyruqlar: `lsblk`, `losetup`, `mkfs`, `mount`, `/etc/fstab`, swap, LVM |

- **Paketlar** (VM ichida, odatda o'rnatilgan, buyruq bor-yo'qligini tekshiradi): `sudo apt install -y lvm2 xfsprogs parted`. 12-vazifa uchun 8-darsdagi `stress-ng` kerak.
- **Bo'sh joy**: VM'da `df -h /` kamida 3 GB bo'sh ko'rsatsin (uchta 512M fayl, swapfile va zaxira). `SETUP.md` dagi 10G disk bunga yetadi.
- **Disk fayllarini yaratish va ulash** (VM ichida):

```
sudo mkdir -p /var/tmp/lab
sudo truncate -s 512M /var/tmp/lab/d1.img /var/tmp/lab/d2.img /var/tmp/lab/d3.img
sudo losetup -fP --show /var/tmp/lab/d1.img     # prints the device, e.g. /dev/loop0
losetup -l                                      # which file is attached where
```

- `truncate` **sparse** fayl yaratadi: fayl 512M ko'rinadi, lekin diskda faqat haqiqatan yozilgan qismi joy oladi (2-bo'lim). `losetup -f` birinchi bo'sh loop raqamini oladi, `-P` bo'limlar jadvalini o'qishni yoqadi, `--show` tanlangan qurilma nomini chiqaradi. Loop raqamlari har mashinada har xil bo'lishi mumkin (snap paketlari ham loop ishlatadi), shuning uchun har doim `losetup` chiqargan nomni ishlating. Darsda ular `/dev/loopA`, `/dev/loopB`, `/dev/loopC` deb yoziladi: bu shartli nom, uni o'z qurilmangiz nomiga almashtirasiz.
- **Loop ulanishi reboot'da yo'qoladi**, fayllar va ularning ichidagi ma'lumot qoladi. Bu darsda ataylab ishlatiladigan xususiyat: "disk reboot'dan keyin topilmadi" holatini xavfsiz o'ynash imkonini beradi.
- **Snapshot**: noto'g'ri `/etc/fstab` VM'ni yuklanmaydigan qilib qo'yishi mumkin (4-bo'lim). `fstab` ga tegadigan vazifalardan (9, 10, 11, 18, 21) oldin host'da snapshot oling. Snapshot uchun VM to'xtatilgan bo'lishi shart:

```
multipass stop lab
multipass snapshot lab --name before-fstab
multipass start lab
# if the VM no longer boots:
multipass stop lab
multipass restore lab.before-fstab
```

  `restore` VM diskini snapshot paytidagi holatga qaytaradi, undan keyingi o'zgarishlar yo'qoladi. Snapshot'dan keyin VM qayta yuklangani uchun loop'lar uzilgan bo'ladi: `losetup` bilan qayta ulang. Ikkinchi himoya `nofail` opsiyasi: darsdagi har `fstab` qatorida u bo'ladi.
- **Tozalash tartibi** (yaratishga teskari): `umount`, `swapoff`, `lvremove`, `vgremove`, `pvremove`, `losetup -d`, fayllarni o'chirish, `/etc/fstab` dan o'z qatorlaringizni olib tashlash.

**Oldingi darslar holati.** A–D guruhlar toza `lab` VM'da bajariladi. E guruh (mini-loyiha) uchun VM'da quyidagilar bo'lishi kerak: 10-darsdagi `deploy` va `demoapp` foydalanuvchilari (`deploy` uchun SSH kaliti bilan), 11-darsdagi `demoapp.service` va uning `/srv/demoapp` dagi fayllari. Tekshirish: `id deploy`, `id demoapp`, `systemctl cat demoapp.service`, `systemctl is-active demoapp`. Laboratoriya holati mashinalar orasida ko'chmaydi, faqat javoblar git orqali ko'chadi. Shuning uchun mini-loyihani ikkinchi mashinada bajarsangiz, avval o'sha mashinadagi `lab` VM'da holatni tiklang: `linux/10-users/README.md` dagi o'z buyruqlaringiz bilan ikki foydalanuvchini, `linux/11-systemd/` dagi saqlangan unit faylingiz va README'dagi qadamlar bilan `demoapp.service` ni qayta yarating (faylni VM'ga `multipass transfer` bilan o'tkazish mumkin). Loop fayllar, VG va swapfile ham ko'chmaydi: darsni o'rtasida mashina almashtirsangiz, Laboratoriya bo'limidagi buyruqlar bilan disklarni qayta yarating va guruhni boshidan boshlang. Iloji bo'lsa bitta guruhni (ayniqsa E ni) bitta mashinada tugating.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`. Host'ning o'zi Linux, shuning uchun ixtiyoriy "host'da ham ko'ring" eslatmalarida faqat o'qiydigan buyruqlar (`lsblk`, `lsblk -f`, `df -hT`, `findmnt`) ishlaydi. Host'da `mkfs`, `fdisk`, `parted`, `dd of=/dev/...`, `/etc/fstab` tahriri bajarilmaydi: bitta noto'g'ri qurilma nomi ish mashinasidagi ma'lumotni o'chiradi. |
| macOS (uy) | VM `arm64`, VM ichidagi buyruqlar va natijalar bir xil. Host Linux emas: `lsblk`, `losetup`, `findmnt`, `mkfs.ext4`, LVM yo'q, `/etc/fstab` ishlatilmaydi, fayl tizimi APFS va uni `diskutil` boshqaradi. Host'ga oid ixtiyoriy savollarda `diskutil list` va `df -h` yetadi, qolgan hamma narsa faqat VM'da. Mac'da bajarib bo'lmaydigan majburiy vazifa yo'q. |

---

## 1. Block device'lar va qatlamlar

### Qatlamlar

Fayl nomidan jismoniy diskkacha bir necha qatlam bor va har bir hodisa ("joy yo'q", "ko'rinmayapti", "sekin") shulardan birida yuz beradi:

```
file name            /srv/data/report.txt
mount point          /srv/data            (a directory in the single tree)
filesystem           ext4 or xfs          (names, inodes, data blocks)
[logical volume]     /dev/vgdata/lvdata   (optional: LVM)
[partition]          /dev/sdb1            (optional)
block device         /dev/sdb             (disk, cloud volume, loop file)
```

Kvadrat qavsdagi qatlamlar ixtiyoriy: fayl tizimini butun diskka ham, bo'limga ham, LVM volume'iga ham qo'yish mumkin. Dars shu sxema bo'yicha pastdan yuqoriga boradi.

### Block device nima

**Block device** bu belgilangan o'lchamli bloklar (odatda 512 bayt yoki 4096 bayt) bilan ixtiyoriy tartibda o'qiladigan va yoziladigan qurilma: "N-blokni ber", "N-blokka yoz". U fayl, katalog yoki nom nima ekanini bilmaydi, faqat raqamlangan bloklar qatori. Kernel har bir block device'ni `/dev` da maxsus fayl sifatida ko'rsatadi (1-darsdagi "hamma narsa fayl"). Nom drayverdan kelib chiqadi:

| Nom | Nima |
|-----|------|
| `/dev/sda`, `/dev/sdb` | SCSI, SATA, USB disklar; bo'limlari `sda1`, `sda2` |
| `/dev/vda` | virtio disk (KVM/QEMU VM'lar, ko'p cloud provayderlar) |
| `/dev/nvme0n1` | NVMe: 0-kontroller, 1-namespace; bo'limlari `nvme0n1p1` |
| `/dev/xvda` | Xen (eski AWS instanslari) |
| `/dev/loop0` | loop device: oddiy fayl block device sifatida |
| `/dev/mapper/vg-lv`, `/dev/dm-0` | device mapper: LVM, shifrlash (LUKS) |

### Misol: lsblk

`lsblk` (list block devices) qatlamlarni daraxt qilib ko'rsatadi. VM ichida:

```
ubuntu@lab:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   10G  0 disk
├─sda1    8:1    0    9G  0 part /
├─sda14   8:14   0    4M  0 part
├─sda15   8:15   0  106M  0 part /boot/efi
└─sda16 259:0    0  913M  0 part /boot
```

Ustunlar: `NAME` qurilma nomi, daraxt chiziqlari "kim kimning ichida" ekanini bildiradi; `MAJ:MIN` kernel'dagi drayver raqami va qurilma raqami; `RM` olinadigan qurilmami (USB); `SIZE` hajm; `RO` faqat o'qish uchunmi; `TYPE` qatlam turi (`disk`, `part`, `lvm`, `loop`); `MOUNTPOINTS` daraxtning qaysi katalogiga ulangan. Qatorlar: `sda` 10G butun disk (`SETUP.md` dagi `--disk 10G`); `sda1` root fayl tizimi; `sda15` UEFI firmware o'qiydigan kichik bo'lim; `sda16` kernel va initramfs turadigan `/boot` (1-dars); `sda14` eski BIOS yuklovchisi uchun, mount qilinmaydi. Sizda bo'limlar soni va nomlari biroz farq qilishi mumkin: Mac'dagi `arm64` VM'da `sda14` yo'q, ba'zi muhitlarda disk `vda` deb nomlanadi. `sr0` yoki `loop` qatorlari ham chiqishi mumkin.

`lsblk -f` xuddi shu daraxtga fayl tizimi turi, label va UUID'ni qo'shadi:

```
ubuntu@lab:~$ lsblk -f /dev/sda
NAME    FSTYPE FSVER LABEL           UUID     FSAVAIL FSUSE% MOUNTPOINTS
sda
├─sda1  ext4   1.0   cloudimg-rootfs <uuid>   <N>G    <N>%   /
├─sda14
├─sda15 vfat   FAT32 UEFI            <uuid>   <N>M    <N>%   /boot/efi
└─sda16 ext4   1.0   BOOT            <uuid>   <N>M    <N>%   /boot
```

`FSTYPE` bo'sh bo'lsa qurilmada tanilgan fayl tizimi yo'q. `mkfs` dan oldin shu ustunga qarash qoida: bo'sh bo'lmasa, u yerda kimningdir ma'lumoti bor. Bitta qurilma uchun xuddi shu ma'lumotni `sudo blkid /dev/sda1` beradi.

### Loop device

Loop device oddiy faylni block device qilib ko'rsatadi: kernel `/dev/loop0` ga kelgan "N-blokni o'qi" so'rovini faylning tegishli joyidan o'qishga aylantiradi. Snap paketlari (12-dars) aynan shunday ishlaydi: har snap bitta fayl bo'lib, loop orqali mount qilinadi. Shuning uchun Zorin host'ida `lsblk` o'nlab `loop` qatorlarini ko'rsatadi.

```
ubuntu@lab:~$ sudo losetup -fP --show /var/tmp/lab/d1.img
/dev/loop0
ubuntu@lab:~$ losetup -l
NAME       SIZELIMIT OFFSET AUTOCLEAR RO BACK-FILE            DIO LOG-SEC
/dev/loop0         0      0         0  0 /var/tmp/lab/d1.img    0     512
ubuntu@lab:~$ lsblk /dev/loop0
NAME  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0   7:0    0  512M  0 loop
```

`losetup -l` da muhimi ikki ustun: `NAME` (qurilma) va `BACK-FILE` (ortidagi fayl). `lsblk` endi uni 512M li `loop` turidagi qurilma deb ko'radi va undan keyingi barcha asboblar (`parted`, `mkfs`, `pvcreate`) uni haqiqiy diskdan farqlamaydi. Uzish: `sudo losetup -d /dev/loop0`, fayl bo'yicha qidirish: `losetup -j /var/tmp/lab/d1.img`.

### Partition

Disk bo'limlarga (partition) bo'linadi: bo'lim bu diskning "shu blokdan shu blokkacha" degan uzluksiz qismi. Bo'limlar ro'yxati, ya'ni **partition table**, disk boshida saqlanadi. Ikki formati bor:

| | MBR (dos) | GPT |
|---|-----------|-----|
| Maksimal hajm | 2 TiB | amalda cheksiz |
| Bo'limlar soni | 4 ta primary | standart 128 |
| Zaxira nusxa | yo'q | disk oxirida |

Yangi tizimlarda GPT ishlatiladi. Asboblar: `fdisk` (interaktiv), `parted` (skriptda `-s` bilan), ko'rish uchun `sudo fdisk -l` yoki `sudo parted -l`.

```
ubuntu@lab:~$ sudo parted -s /dev/loop0 mklabel gpt mkpart data ext4 1MiB 100%
ubuntu@lab:~$ lsblk /dev/loop0
NAME      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0       7:0    0  512M  0 loop
└─loop0p1 259:1    0  510M  0 part
```

`mklabel gpt` yangi bo'sh GPT jadval yozadi (eskisini o'chiradi), `mkpart data ext4 1MiB 100%` esa `data` nomli bitta bo'limni 1 MiB dan disk oxirigacha yaratadi. Bu yerdagi `ext4` faqat jadvaldagi belgi, fayl tizimi yaratilmaydi, uni `mkfs` qiladi. Bo'lim `loop0p1` nomi bilan paydo bo'ldi (`losetup -P` shuni ta'minlaydi) va diskdan 2M kichik: boshidagi 1 MiB tekislash uchun, oxiridagi joy GPT'ning zaxira nusxasi uchun. Qurilmadagi barcha imzolarni (jadval, fayl tizimi belgisi) o'chirish: `sudo wipefs -a /dev/loop0`.

**Tuzoq: qurilma nomlari barqaror emas.** `/dev/sdb` kernel disklarni topgan tartibga bog'liq: disk qo'shilsa yoki cloud instans qayta ishga tushsa `sdb` va `sdc` almashib qolishi mumkin. Barqaror identifikatorlar `/dev/disk/by-uuid/` va `/dev/disk/by-id/` da (`ls -l /dev/disk/by-uuid/` ularni symlink sifatida ko'rsatadi); `fstab` da shular ishlatiladi (4-bo'lim).

### Real ishda qachon kerak

- Cloud'da instansga yangi volume ulaganingizda u bo'sh block device bo'lib keladi (`lsblk` da `FSTYPE` siz). Uni formatlash va mount qilish sizning ishingiz.
- "Disk qo'shdim, lekin joy ko'paymadi" shikoyatida birinchi buyruq `lsblk`: disk ko'rinadimi, ustida bo'lim yoki fayl tizimi bormi, mount qilinganmi.
- Cloud'dagi ma'lumot disklari ko'pincha bo'limlarga bo'linmaydi: butun diskka to'g'ridan-to'g'ri fayl tizimi yoki LVM qo'yiladi, chunki keyin diskni kattalashtirish osonroq (bo'lim jadvalini siljitish kerak emas).
- Docker image qatlamlari, snap'lar, ISO fayllar: hammasi "fayl ichidagi fayl tizimi" g'oyasi, loop device shuning eng sodda ko'rinishi.

### Nima uchun shunday

Block device abstraksiyasi fayl tizimini hardware'dan ajratadi: ext4 ostida SATA disk, NVMe, tarmoq orqali ulangan cloud volume yoki oddiy fayl turganini bilmaydi va bilishi shart emas. Shu ajratish tufayli qatlamlarni erkin ustma-ust qo'yish mumkin: disk ustiga shifrlash (LUKS), uning ustiga LVM, uning ustiga fayl tizimi. Qurilmalarning `/dev` da fayl bo'lib ko'rinishi esa oddiy asboblarni (`dd`, `cat`, ruxsatlar) ularga ham qo'llash imkonini beradi. macOS'da xuddi shu g'oya bor (`/dev/disk0`, disk image'lar uchun `hdiutil`), lekin asboblar va nomlar boshqa, shuning uchun dars VM'da o'tiladi.

## 2. Fayl tizimi va inode

### Fayl tizimi nima

Block device shunchaki raqamlangan bloklar. **Fayl tizimi** (filesystem) ularning ustiga tuzilma quradi: qaysi bloklar qaysi faylga tegishli, fayl nomlari, kataloglar, huquqlar, bo'sh joy hisobi. Fayl tizimini yaratish (formatlash) bu qurilmaga shu tuzilmaning bo'sh holatini yozish demak. Fayl tizimi qurilmaning ichida yashaydi: diskni boshqa serverga ko'chirsangiz, fayllar, huquqlar va UUID u bilan birga ko'chadi.

### inode

Har fayl va katalog uchun bitta **inode** (index node) bor: turi, huquqlari, egasi (UID/GID), hajmi, vaqt belgilari, hard link'lar soni va ma'lumot bloklariga ko'rsatkichlar. Inode'da **fayl nomi yo'q**. Nom katalogda saqlanadi: katalog bu "nom → inode raqami" juftliklari ro'yxati. 6-darsdagi xulosalar shundan kelib chiqadi: hard link bir inode'ga ikkinchi nom, `mv` bir fayl tizimi ichida faqat katalog yozuvini o'zgartiradi, o'chirilgan, lekin hali ochiq fayl joy egallab turadi (8-dars), chunki inode va bloklar oxirgi nom **va** oxirgi ochiq descriptor yo'qolgandagina bo'shatiladi.

```
ubuntu@lab:~$ stat /etc/hostname
  File: /etc/hostname
  Size: 4         	Blocks: 8          IO Block: 4096   regular file
Device: 8,1	Inode: <N>      Links: 1
Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Access: <sana> <vaqt> +0000
Modify: <sana> <vaqt> +0000
Change: <sana> <vaqt> +0000
 Birth: <sana> <vaqt> +0000
```

Qatorma-qator: `Size: 4` fayl mazmuni 4 bayt (`lab` va qator oxiri); `Blocks: 8` diskda egallangan joy 512 baytlik birliklarda, ya'ni 4096 bayt, chunki fayl tizimi joyni butun bloklar (`IO Block: 4096`) bilan beradi va 4 baytli fayl ham bitta to'liq blokni oladi; `Device: 8,1` qaysi qurilmada (`lsblk` dagi `MAJ:MIN`, ya'ni `sda1`); `Inode` shu fayl tizimi ichidagi inode raqami; `Links: 1` shu inode'ga nechta nom ishora qiladi. Keyingi qator huquqlar va egasi (4 va 10-darslar). Uch vaqt: `Modify` mazmun oxirgi marta o'zgargan, `Change` inode o'zgargan (huquq, egasi, nom, link soni), `Access` oxirgi o'qilgan; `Birth` fayl yaratilgan vaqt. Faqat inode raqamini `ls -i` ko'rsatadi.

`Size` va `Blocks` teskari tomonga ham farq qiladi. Laboratoriyadagi `truncate` yaratgan **sparse** faylda `Size` 512M, `Blocks` esa deyarli 0: fayl tizimi hech narsa yozilmagan oraliqlar uchun blok ajratmaydi. `ls -l` hajmni (`Size`), `du` egallangan joyni (`Blocks`) ko'rsatadi.

### Inode'lar soni chekli

```
ubuntu@lab:~$ df -i /
Filesystem      Inodes  IUsed   IFree IUse% Mounted on
/dev/sda1      <N>     <N>     <N>     <N>% /
```

`df -h` bloklarni, `df -i` inode'larni sanaydi: `Inodes` jami, `IUsed` band, `IFree` bo'sh. Bular ikki alohida resurs va istalgan biri tugashi mumkin.

**Tuzoq: inode tugashi.** ext4 da inode'lar soni `mkfs` paytida belgilanadi va keyin o'zgarmaydi. Millionlab mayda fayl (sessiya fayllari, kesh, mail navbati) inode'larni tugatadi: `df -h` bo'sh joy ko'rsatadi, lekin har yozish `No space left on device` beradi. Tekshirish `df -i`, qaysi katalogda ekanini topish: `sudo du --inodes -x / | sort -n | tail`. Sizga tanish misol: bitta `node_modules` yuz minglab mayda fayldan iborat, o'nlab loyiha turgan CI serverida bayt emas, aynan inode tugashi mumkin.

### ext4, xfs, btrfs

| | ext4 | xfs | btrfs |
|---|------|-----|-------|
| Standart qayerda | Debian, Ubuntu | RHEL, Rocky, Amazon Linux | openSUSE, Fedora desktop |
| Inode'lar | `mkfs` da belgilanadi | dinamik | dinamik |
| Kattalashtirish | online, `resize2fs` | online, `xfs_growfs` | online |
| Kichraytirish | faqat unmount qilingan holda | **mumkin emas** | online |
| Xususiyati | sodda, eng ko'p sinalgan | katta fayllar va parallel yozishda kuchli | copy-on-write, snapshot, subvolume, checksum |
| Tekshirish va tuzatish | `e2fsck` | `xfs_repair` | `btrfs check`, `btrfs scrub` |

ext4 va xfs **journal** yuritadi: tuzilmani o'zgartirishdan oldin niyatini alohida joyga yozib qo'yadi, shuning uchun to'satdan o'chishdan keyin fayl tizimi yarim yozilgan holatda qolmaydi. btrfs xuddi shu maqsadga copy-on-write bilan erishadi (eski blokni ustidan yozmaydi, yangisini yozib ko'rsatkichni almashtiradi). Tanlov odatda distributivning standartiga ergashadi; xfs tanlasangiz kichraytira olmasligingizni oldindan biling.

### mkfs

```
ubuntu@lab:~$ sudo mkfs.ext4 -L data /dev/loop0p1
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done
Creating filesystem with <N> 4k blocks and <N> inodes
Filesystem UUID: <uuid>
Superblock backups stored on blocks:
	<...>

Allocating group tables: done
Writing inode tables: done
Creating journal (<N> blocks): done
Writing superblocks and filesystem accounting information: done
```

Muhim qatorlar: `Creating filesystem with <N> 4k blocks and <N> inodes` blok o'lchami 4 KiB va inode'lar soni shu lahzada qat'iy belgilandi; `Filesystem UUID` fayl tizimining noyob identifikatori, u qurilma ichidagi **superblock** ga yoziladi (superblock bu fayl tizimining o'zi haqidagi asosiy yozuv: o'lchamlar, UUID, holat; uning zaxira nusxalari bor, keyingi qator shularni sanaydi); `Creating journal` journal uchun joy ajratildi. `-L data` label beradi. xfs uchun: `sudo mkfs.xfs /dev/loopB`.

`mkfs` qurilmadagi mavjud ma'lumotni yo'q qiladi. xfs mavjud fayl tizimini ko'rsa `-f` talab qiladi, ext4 terminalda so'raydi, skriptda esa jim ishlashi mumkin. Zamonaviy `mkfs.xfs` 300 MB dan kichik qurilmani rad etadi.

ext4 standart holatda bloklarning 5 foizini root uchun zaxiralaydi (disk to'lganda ham tizim servislari yoza olsin va root kirib tozalay olsin). Shuning uchun `df` da `Used + Avail` `Size` dan kichik. Faqat ma'lumot saqlanadigan katta volume'da buni kamaytirish mumkin: `sudo tune2fs -m 1 /dev/...`. Parametrlarni ko'rish: `sudo tune2fs -l /dev/...` (`Inode count`, `Block count`, `Reserved block count`, `Block size`).

### Real ishda qachon kerak

- "No space left on device", lekin `df -h` joy ko'rsatyapti: `df -i`.
- "Faylni o'chirdim, joy bo'shamadi": inode hali ochiq descriptor orqali tirik (8-dars, `lsof +L1`).
- Yangi volume uchun fayl tizimi tanlash: distributiv standarti, kelajakda kichraytirish kerak bo'ladimi, mayda fayllar ko'pmi.
- Log fayl `ls -l` da 20G, `du` da 1G ko'rsatsa: sparse fayl, vahima qilishga hojat yo'q.

### Nima uchun shunday

Nom va inode ajratilgani uchun bitta faylga bir nechta nom berish (hard link), ochiq faylni o'chirish va atom tarzda almashtirish (`mv` yangi faylni eski nom ustiga) mumkin: deploy paytida konfiguratsiyani "yarim yozilgan" holatsiz almashtirish shunga tayanadi. ext4 inode jadvalini oldindan ajratadi, chunki bu sodda va tez, narxi esa qat'iy limit; xfs va btrfs inode'ni kerak bo'lganda ajratadi, narxi murakkabroq tuzilma. Journal bo'lmagan eski fayl tizimlarida (ext2) to'satdan o'chishdan keyin butun diskni soatlab tekshirish (`fsck`) kerak bo'lardi, journal shu muammoni yechgan.

## 3. mount

### Bitta daraxtga ulash

Fayl tizimi katalog daraxtining biror nuqtasiga ulangachgina ko'rinadi. Bu amal **mount**, ulangan katalog **mount nuqtasi** (mount point) deyiladi. Linux'da disk harflari (`C:`, `D:`) yo'q, hammasi bitta `/` daraxtida (1-dars): `/` bitta fayl tizimi, `/boot` boshqasi, `/srv/data` uchinchisi bo'lishi mumkin va dastur buni sezmaydi.

Mexanizm: kernel "mount jadvali" yuritadi. Yo'lni ochayotganda (`/mnt/data/a.txt`) u har katalogdan o'tishda jadvalga qaraydi: `/mnt/data` mount nuqtasi bo'lsa, shu yerdan boshlab boshqa fayl tizimining ildiz katalogiga o'tadi. Ostidagi katalog o'chmaydi, shunchaki to'siladi.

```
ubuntu@lab:~$ sudo mkdir -p /mnt/data
ubuntu@lab:~$ sudo mount /dev/loop0p1 /mnt/data
ubuntu@lab:~$ findmnt /mnt/data
TARGET    SOURCE       FSTYPE OPTIONS
/mnt/data /dev/loop0p1 ext4   rw,relatime
ubuntu@lab:~$ df -hT /mnt/data
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/loop0p1   ext4  <N>M  <N>K  <N>M   1% /mnt/data
ubuntu@lab:~$ ls /mnt/data
lost+found
```

`findmnt` ustunlari: `TARGET` mount nuqtasi, `SOURCE` qurilma, `FSTYPE` tur (kernel uni superblock'dan o'zi aniqladi, `-t ext4` yozish shart emas), `OPTIONS` amaldagi opsiyalar. `df -hT` da `Size` bo'lim hajmidan (510M) sezilarli kichik: farq inode jadvali va journal'ga ketgan, `Avail` esa yana 5 foiz zaxiraga kamaygan. `lost+found` ext4 ning o'z katalogi, `e2fsck` egasiz qolgan fayl parchalarini shu yerga qo'yadi; yangi fayl tizimi "bo'sh" bo'lsa ham unda shu katalog bor. Yangi fayl tizimining ildizi `root` ga tegishli, oddiy foydalanuvchi yoza olishi uchun mount'dan **keyin** `chown` qilinadi (egalik fayl tizimi ichida saqlanadi, mount nuqtasi katalogida emas). Uzish: `sudo umount /mnt/data` (buyruq nomi `umount`, `unmount` emas).

### Opsiyalar

| Opsiya | Ma'nosi |
|--------|---------|
| `defaults` | `rw,suid,dev,exec,auto,nouser,async` |
| `ro` / `rw` | faqat o'qish / o'qish va yozish |
| `noatime` | o'qishda access vaqtini yangilamaslik (kamroq yozish) |
| `noexec`, `nosuid`, `nodev` | binary bajarish, setuid, device fayllarni taqiqlash (`/tmp`, yuklangan fayllar uchun himoya) |
| `nofail` | qurilma topilmasa boot to'xtamasin (4-bo'lim) |

Ishlab turgan mount'ning opsiyasini o'zgartirish: `sudo mount -o remount,ro /mnt/data`. `relatime` (standart) access vaqtini har o'qishda emas, kamroq yangilaydi; `noatime` umuman yangilamaydi.

**Tuzoq: mount mavjud mazmunni yopadi.** Bo'sh bo'lmagan katalogga mount qilsangiz, eski fayllar o'chmaydi, lekin ko'rinmay qoladi va joy egallab turadi. Teskari holat xavfliroq: mount yiqilgan bo'lsa dastur ma'lumotni ostidagi katalogga, ya'ni root diskka yozadi va uni to'ldiradi, keyin mount tiklanganda "ma'lumot yo'qoldi" bo'lib ko'rinadi. Bu sizga Docker'dan tanish bo'lishi mumkin: loyiha papkasini konteynerning `/app` iga bind mount qilganda image ichidagi `/app/node_modules` "yo'qoladi". Mexanizm aynan shu: mount ostidagi katalogni to'sadi.

**Tuzoq: `target is busy`.** Biror jarayon shu fayl tizimida fayl ochgan yoki joriy katalogi shu yerda bo'lsa `umount` rad etadi. Kimligini `sudo lsof +f -- /mnt/data` yoki `sudo fuser -vm /mnt/data` ko'rsatadi. Ko'pincha aybdor o'zingizning shell'ingiz (`cd /mnt/data` da turibsiz).

### Real ishda qachon kerak

- Yangi volume'ni servis ma'lumot katalogiga ulash (`/var/lib/postgresql`, `/srv/app`).
- "Ma'lumot yo'qoldi" hodisasida birinchi tekshiruv: `findmnt <katalog>`. Bo'sh javob mount yo'qligini, ya'ni siz ostidagi katalogni ko'rayotganingizni bildiradi.
- Xavfsizlik: foydalanuvchi fayl yuklaydigan katalogni `noexec,nosuid,nodev` bilan mount qilish.
- Kubernetes pod'idagi `volumeMounts` va Docker'dagi `-v` shu amalning o'zi, faqat konteyner ichidagi daraxtda.

### Nima uchun shunday

Bitta daraxt dasturni saqlash joyidan mustaqil qiladi: servis `/var/lib/app` ga yozadi, u root diskdami, alohida volume'dami yoki tarmoq fayl tizimidami, bu administrator qarori va dastur kodiga tegmaydi. Ma'lumot root diskni to'ldira boshlasa, katalogni alohida volume'ga ko'chirib o'sha yo'lga mount qilasiz va dastur hech narsani sezmaydi. Windows'dagi disk harflarida esa yo'lning o'zi saqlash joyini bildiradi va ko'chirish yo'lni o'zgartiradi. Bu erkinlikning narxi yuqoridagi ikki tuzoq: yo'l bir xil qolgani uchun ostida qaysi fayl tizimi turganini ko'z bilan bilib bo'lmaydi, `findmnt` bilan tekshirish kerak.

## 4. /etc/fstab

### Doimiy mount

Qo'lda qilingan `mount` reboot'gacha yashaydi. Doimiy mount'lar `/etc/fstab` (filesystem table) faylida yoziladi, har qatorda 6 maydon:

```
# <device>                                 <mountpoint>  <type>  <options>        <dump> <pass>
UUID=3f2a9c1e-7b1d-4c58-9d0e-5a6b7c8d9e0f  /mnt/data     ext4    defaults,nofail  0      2
```

| # | Maydon | Izoh |
|---|--------|------|
| 1 | qurilma | `UUID=...` (tavsiya), `LABEL=...`, `/dev/mapper/vg-lv` (LVM nomlari barqaror) yoki yo'l |
| 2 | mount nuqtasi | mavjud katalog; swap uchun `none` |
| 3 | tur | `ext4`, `xfs`, `swap`, `nfs` |
| 4 | opsiyalar | vergul bilan, bo'sh joysiz |
| 5 | dump | eskirgan, `0` |
| 6 | fsck tartibi | `0` tekshirilmaydi, `1` root, `2` qolganlar. xfs uchun `0` |

UUID fayl tizimi yaratilganda beriladi va uning ichida saqlanadi: `sudo blkid -s UUID -o value /dev/loopA`. VM'ning o'z `fstab` ini o'qing, u `LABEL=` shaklini ishlatadi:

```
ubuntu@lab:~$ cat /etc/fstab
LABEL=cloudimg-rootfs	/	 ext4	discard,commit=30,errors=remount-ro	0 1
LABEL=BOOT	/boot	ext4	defaults	0 2
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1
```

Birinchi qator: `cloudimg-rootfs` label'li fayl tizimi (`lsblk -f` da `sda1`) `/` ga, `ext4`, `errors=remount-ro` (fayl tizimida xato topilsa faqat o'qishga o'tsin), fsck tartibi `1`. Cloud image label ishlatadi, chunki bitta image minglab VM'ga ko'chiriladi va hammasida label bir xil. O'z disklaringizda UUID xavfsizroq: ikki diskda bir xil label tasodifan uchrashi mumkin, UUID esa yo'q.

### Mexanizm: fstab'ni kim o'qiydi

Boot paytida `systemd-fstab-generator` har `fstab` qatoridan bitta **mount unit** yasaydi (11-darsdagi unit turlaridan biri): `/mnt/data` uchun `mnt-data.mount`. Systemd avval qurilma paydo bo'lishini kutadi, keyin mount qiladi. Shuning uchun `fstab` ni tahrirlagandan keyin `systemctl daemon-reload` kerak (unit'lar qayta yasalsin) va shuning uchun servisni mount'ga bog'lash mumkin (`RequiresMountsFor=`). Qo'lda ishlatiladigan `mount -a` esa `fstab` ni to'g'ridan-to'g'ri o'qib, hali mount qilinmagan hamma qatorni ulaydi.

Tahrirdan keyingi majburiy tartib:

```
sudo cp /etc/fstab /etc/fstab.bak
sudo nano /etc/fstab
sudo findmnt --verify            # syntax and sanity check
sudo systemctl daemon-reload     # systemd regenerates mount units from fstab
sudo mount -a                    # mount everything not yet mounted
findmnt /mnt/data
```

`findmnt --verify` hamma narsa joyida bo'lsa `Success, no errors or warnings detected` deydi, aks holda qaysi qatorda nima noto'g'ri ekanini (mavjud bo'lmagan mount nuqtasi, topilmagan qurilma, noma'lum tur) sanaydi. `mount -a` jim tugasa va `findmnt` qatorni ko'rsatsa, qator to'g'ri.

**Tuzoq: xato `fstab` bilan reboot.** `nofail` siz yozilgan qator ishlamasa (UUID'da xato, disk olib tashlangan), systemd boot'ni to'xtatib `emergency.target` ga tushadi (11-dars). SSH ko'tarilmaydi; cloud'da bu serial console yoki diskni boshqa instansga ulab tuzatish degani, Multipass'da esa `multipass shell lab` ishlamay qoladi va snapshot'dan tiklashga to'g'ri keladi (Laboratoriya). Qoidalar: har doim `mount -a` bilan sinash, root'dan boshqa hamma qatorga `nofail`, zaxira nusxa. Qurilmani kutish vaqti standart 90 soniya, `x-systemd.device-timeout=10s` opsiyasi bilan qisqartiriladi.

### Real ishda qachon kerak

- Har yangi volume: formatlash, mount, `fstab` qatori, `mount -a` bilan sinov. To'rttasi birga bitta ish.
- Server reboot'dan keyin "ma'lumot yo'q": `fstab` da qator yo'q yoki `nofail` bilan jimgina o'tib ketgan. `systemctl --failed` va `findmnt` ko'rsatadi.
- Terraform yoki Ansible bilan volume ulaganda ham oxirgi qadam shu fayl (Ansible'da `mount` moduli uni siz uchun yozadi).

### Nima uchun shunday

`fstab` Unix'ning eng eski konfiguratsiya fayllaridan biri: oddiy matn, qatorma-qator, har qanday asbob o'qiy oladi. Systemd uni almashtirmadi, balki unit'larga tarjima qiladi, shu bilan mount'lar ham servislar kabi bog'liqlik grafiga kiradi ("avval disk, keyin baza"). `nofail` siz qatorning boot'ni to'xtatishi xato emas, ataylab qilingan qaror: ma'lumot diski bo'lmasa baza bo'sh katalogda ishga tushib ketishidan ko'ra tizim to'xtagani yaxshi. Siz qaysi diskning yo'qligi halokatli, qaysisiniki yo'qligini `nofail` bilan o'zingiz belgilaysiz; servisning disksiz ishga tushmasligini esa `RequiresMountsFor=` ta'minlaydi.

## 5. Swap

### Swap nima

**Swap** bu RAM yetmaganda kernel kam ishlatilgan xotira sahifalarini chiqarib qo'yadigan disk maydoni: alohida bo'lim yoki oddiy fayl (swapfile). Xotira sahifalarga (page, odatda 4 KiB) bo'lingan. Sahifalar ikki xil: **page cache** (diskdagi fayllarning xotiradagi nusxasi, kerak bo'lsa shunchaki tashlab yuboriladi, chunki asli diskda bor) va **anonim sahifalar** (jarayonning heap va stack'i, masalan Node jarayonidagi JS obyektlari; ularning diskda asli yo'q). Xotira tor kelganda kernel anonim sahifani faqat swap bo'lsagina bo'shata oladi: uni swap'ga yozadi, RAM'dagi joyni boshqaga beradi, jarayon o'sha sahifaga qayta murojaat qilganda diskdan qaytarib o'qiydi. Swap bo'lmasa va tashlaydigan kesh qolmasa, **OOM killer** ishga tushadi: kernel biror jarayonni o'ldirib xotira bo'shatadi (8-dars).

Cloud VM'lar va Multipass VM odatda swap'siz keladi.

```
ubuntu@lab:~$ sudo dd if=/dev/zero of=/swapfile bs=1M count=512 status=progress
ubuntu@lab:~$ sudo chmod 600 /swapfile
ubuntu@lab:~$ sudo mkswap /swapfile
Setting up swapspace version 1, size = 512 MiB (536866816 bytes)
no label, UUID=<uuid>
ubuntu@lab:~$ sudo swapon /swapfile
ubuntu@lab:~$ swapon --show
NAME      TYPE SIZE USED PRIO
/swapfile file 512M   0B   -2
ubuntu@lab:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           1.9Gi       <N>Mi       <N>Gi       <N>Mi       <N>Mi       <N>Gi
Swap:          511Mi          0B       511Mi
```

Qadamlar: `dd` 512 ta 1 MiB nol blok yozib faylni to'liq ajratadi (swapfile sparse bo'lmasligi kerak, shuning uchun bu yerda `truncate` emas); `chmod 600` faqat root o'qiy olsin; `mkswap` faylga swap imzosini yozadi, bu swap uchun "mkfs"; `swapon` uni kernel'ga topshiradi. `swapon --show` da `TYPE file` (bo'lim bo'lsa `partition`), `USED` hozir chiqarilgan hajm, `PRIO` bir nechta swap bo'lganda tartib. `free -h` ning `Swap:` qatori endi nol emas.

Doimiy qilish uchun `fstab` qatori: `/swapfile none swap sw 0 0`. O'chirish: `sudo swapoff /swapfile` (kernel swap'dagi hamma sahifani RAM'ga qaytaradi, joy yetmasa rad etadi). Fayl huquqi `600` bo'lishi shart: swap'da boshqa jarayonlarning xotirasi (parollar, kalitlar) yotadi.

### swappiness

`vm.swappiness` (0 dan 200 gacha, standart 60) kernel xotira bo'shatishda nimani afzal ko'rishini belgilaydi: anonim sahifalarni swap'ga chiqarishnimi yoki page cache'ni tashlashnimi. Past qiymat swap'dan qochadi, lekin bu "RAM necha foiz to'lganda swap boshlanadi" degan chegara emas.

```
ubuntu@lab:~$ cat /proc/sys/vm/swappiness
60
ubuntu@lab:~$ sudo sysctl vm.swappiness=10                                   # until reboot
vm.swappiness = 10
ubuntu@lab:~$ echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
ubuntu@lab:~$ sudo sysctl --system                                           # load all sysctl files
```

`sysctl` kernel parametrlarini ishlab turgan tizimda o'qiydi va o'zgartiradi; ular `/proc/sys/` ostida fayl sifatida ko'rinadi (`vm.swappiness` → `/proc/sys/vm/swappiness`). Buyruq bilan qo'yilgan qiymat reboot'gacha yashaydi, `/etc/sysctl.d/*.conf` dagi qiymat har boot'da yuklanadi. `sysctl --system` qaysi fayllarni qaysi tartibda qo'llaganini chiqaradi.

Swap ishlayotganini `vmstat 1` ko'rsatadi (8-dars): `swpd` chiqarilgan hajm, `si` va `so` sekundiga diskdan qaytarilgan va diskka chiqarilgan hajm. `swpd` katta, lekin `si`/`so` nol bo'lsa muammo yo'q (bir marta chiqarilgan, qayta so'ralmayapti); `si`/`so` doimiy katta bo'lsa tizim "thrashing" holatida, ya'ni vaqtini sahifa tashishga sarflayapti.

### Real ishda qachon kerak

- Kichik (1–2 GB RAM) VPS: kichik swapfile `apt upgrade` yoki build paytidagi xotira cho'qqisida jarayon o'ldirilishining oldini oladi.
- Latency muhim bo'lgan servislarda (ma'lumotlar bazalari) past swappiness qo'yiladi.
- Kubernetes node'larida an'anaviy ravishda swap o'chiriladi, chunki kubelet standart sozlamada swap yoqilgan node'da ishga tushmaydi.
- "Server juda sekin, lekin CPU bo'sh" shikoyatida `vmstat` dagi `si`/`so` birinchi gumondor.

### Nima uchun shunday

Swap xotirani ko'paytirmaydi, u tezlikni vaqtga almashtiradi: disk RAM'dan minglab marta sekin. Uning foydasi boshqa joyda: kutilmagan xotira cho'qqisida OOM killer o'rniga sekinlashuv beradi va tashxis qo'yishga vaqt qoldiradi, kernel'ga esa hech qachon ishlatilmaydigan anonim sahifalarni chiqarib, bo'shagan RAM'ni foydali keshga berish imkonini yaratadi. Qarama-qarshi fikr ham asosli: sekin "tirik" server ko'pincha tez o'lib qayta ishga tushgan serverdan yomonroq, chunki load balancer uni hali sog'lom deb hisoblaydi. Shuning uchun qaror servisga bog'liq va Kubernetes kabi tizimlar oldindan aytib bo'ladigan xatti-harakatni afzal ko'rib swap'ni o'chiradi. macOS'da swap'ni tizim o'zi dinamik boshqaradi va sozlash talab qilmaydi; serverda bu sizning qaroringiz.

## 6. LVM

### Muammo va yechim

Oddiy bo'limning chegarasi qattiq: to'lsa, kengaytirish uchun undan keyingi joy bo'sh bo'lishi kerak, ikki diskni bitta fayl tizimiga birlashtirib bo'lmaydi. **LVM** (Logical Volume Manager) disk va fayl tizimi orasiga moslashuvchan qatlam qo'yadi: disklar umumiy hovuzga yig'iladi va undan kerakli hajmdagi "virtual bo'limlar" ajratiladi.

| Tushuncha | Nima | Buyruqlar |
|-----------|------|-----------|
| PV (physical volume) | LVM'ga berilgan disk yoki bo'lim | `pvcreate`, `pvs`, `pvdisplay` |
| VG (volume group) | bir yoki bir nechta PV'dan yig'ilgan umumiy hovuz | `vgcreate`, `vgextend`, `vgs` |
| LV (logical volume) | hovuzdan ajratilgan "virtual bo'lim", ustiga fayl tizimi qo'yiladi | `lvcreate`, `lvextend`, `lvs` |
| PE (physical extent) | ajratish birligi, standart 4 MiB | |

```
disks:   /dev/loopA    /dev/loopB        (PV)
              \            /
             vgdemo  (VG, one pool)
              /            \
        lvweb 200M      free space       (LV)
             |
        ext4 on /dev/vgdemo/lvweb  ->  mounted at /mnt/web
```

### Mexanizm

`pvcreate` qurilma boshiga LVM imzosi va metadata uchun joy yozadi. VG yaratilganda har PV'ning qolgan qismi 4 MiB li extent'larga (PE) bo'linadi. LV bu "mening 0–49 extent'larim falon PV'ning falon extent'larida" degan jadval. Kernel'dagi **device mapper** shu jadval bo'yicha LV'ga kelgan har o'qish va yozishni tegishli PV'ning tegishli joyiga yo'naltiradi. LV'ni kengaytirish jadvalga yana bir necha extent qo'shish demak, ular boshqa diskda bo'lsa ham, shuning uchun bu ishlab turgan tizimda soniyada bajariladi.

### Misol: yaratish

Quyidagi misol `vgdemo` nomi bilan, o'qish va taqqoslash uchun. O'zingiz takrorlasangiz, bo'lim oxiridagi tozalash buyruqlarini bajaring: D guruh vazifalari toza qurilmalardan boshlanadi.

```
ubuntu@lab:~$ sudo pvcreate /dev/loopA /dev/loopB
  Physical volume "/dev/loopA" successfully created.
  Physical volume "/dev/loopB" successfully created.
ubuntu@lab:~$ sudo vgcreate vgdemo /dev/loopA /dev/loopB
  Volume group "vgdemo" successfully created
ubuntu@lab:~$ sudo lvcreate -n lvweb -L 200M vgdemo
  Logical volume "lvweb" created.
ubuntu@lab:~$ sudo pvs
  PV         VG     Fmt  Attr PSize   PFree
  /dev/loopA vgdemo lvm2 a--  508.00m 308.00m
  /dev/loopB vgdemo lvm2 a--  508.00m 508.00m
ubuntu@lab:~$ sudo vgs
  VG     #PV #LV #SN Attr   VSize    VFree
  vgdemo   2   1   0 wz--n- 1016.00m 816.00m
ubuntu@lab:~$ sudo lvs
  LV    VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lvweb vgdemo -wi-a----- 200.00m
```

`pvs`: har PV 512M emas, 508M: boshidagi joy metadata'ga ketgan va qolgani butun 4 MiB li extent'larga yaxlitlangan. `PFree` ko'rsatadiki, `lvweb` ning 200M i to'liq birinchi PV'dan olingan. `vgs`: `#PV 2` ikki disk, `#LV 1`, `#SN 0` snapshot yo'q, `VSize` hovuz hajmi, `VFree` hali ajratilmagan joy. `lvs`: `LSize` LV hajmi; `Attr` dagi `a` LV faol (active), mount qilingach `o` (open) ham qo'shiladi.

```
ubuntu@lab:~$ sudo mkfs.ext4 /dev/vgdemo/lvweb
ubuntu@lab:~$ sudo mkdir -p /mnt/web && sudo mount /dev/vgdemo/lvweb /mnt/web
ubuntu@lab:~$ lsblk /dev/loopA
NAME           MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loopA            7:<N>  0  512M  0 loop
└─vgdemo-lvweb 252:0    0  200M  0 lvm  /mnt/web
```

LV ikki nom bilan ko'rinadi: `/dev/vgdemo/lvweb` va `/dev/mapper/vgdemo-lvweb` (ikkalasi `/dev/dm-N` ga symlink). Bu nomlar VG va LV nomidan yasaladi, disklar tartibiga bog'liq emas, shuning uchun `fstab` da ishlatsa bo'ladi. `lsblk` da `TYPE lvm` yangi qatlamni ko'rsatadi. `-L 200M` aniq hajm, `-l 100%FREE` VG'dagi hamma bo'sh joy.

### Online kengaytirish

Kengaytirish har doim ikki qadam: avval LV (block device), keyin uning ichidagi fayl tizimi. Fayl tizimi o'z hajmini superblock'da saqlaydi va ostidagi qurilma kattalashganini o'zi sezmaydi.

```
ubuntu@lab:~$ sudo lvextend -L +100M /dev/vgdemo/lvweb     # step 1: grow the LV
ubuntu@lab:~$ sudo lvs vgdemo
  LV    VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lvweb vgdemo -wi-ao---- 300.00m
ubuntu@lab:~$ df -h /mnt/web                               # the filesystem is still the old size
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/vgdemo-lvweb  <N>M  <N>K  <N>M   1% /mnt/web
ubuntu@lab:~$ sudo resize2fs /dev/vgdemo/lvweb             # step 2: grow ext4 while mounted
resize2fs 1.47.0 (5-Feb-2023)
Filesystem at /dev/vgdemo/lvweb is mounted on /mnt/web; on-line resizing required
<...>
The filesystem on /dev/vgdemo/lvweb is now <N> (4k) blocks long.
```

`lvs` 300M ko'rsatadi, `df` esa hali eski hajmni: bu ikki qatlam ikki xil narsani o'lchaydi. `resize2fs` hajmsiz chaqirilganda fayl tizimini qurilmaning to'liq hajmigacha kengaytiradi; `on-line resizing` mount uzilmasdan bajarilganini bildiradi. xfs uchun ikkinchi qadam `sudo xfs_growfs <mount nuqtasi>` (qurilma emas, mount nuqtasi beriladi). Ikkalasini bir buyruqda qilish: `sudo lvextend -r -L +100M /dev/vgdemo/lvweb` (`-r`, ya'ni `--resizefs`, fayl tizimi turini aniqlab kerakli asbobni o'zi chaqiradi). VG'da joy tugasa hovuzga yangi disk qo'shiladi: `sudo pvcreate /dev/loopC` va `sudo vgextend vgdemo /dev/loopC`.

**Tuzoq: `lvextend` dan keyin `df` o'zgarmadi.** LV kattalashdi (`lvs` ko'rsatadi), fayl tizimi esa eski hajmda. Ikkinchi qadam unutilgan.

Kichraytirish boshqa gap: xfs umuman kichraymaydi, ext4 faqat unmount holda va avval fayl tizimi, keyin LV tartibida; tartib buzilsa fayl tizimining oxiri kesiladi va ma'lumot yo'qoladi. Shuning uchun LV'ni kichik yaratib, kerak bo'lganda kattalashtirish va VG'da bo'sh joy qoldirish odat.

### Snapshot va boshqa imkoniyatlar

**Snapshot** bu LV'ning shu lahzadagi holati: `sudo lvcreate -s -n snap -L 100M vgdemo/lvweb`. U nusxa ko'chirmaydi. Asl LV'da biror blok o'zgarishidan oldin uning eski mazmuni snapshot uchun ajratilgan joyga (bu yerda 100M) ko'chiriladi, o'zgarmagan bloklar umumiy qoladi. `lvs` dagi `Data%` shu joyning qancha qismi to'lganini ko'rsatadi; 100 foizga yetsa snapshot yaroqsiz bo'ladi. Ishlatilishi: backup olish paytida muzlatilgan holat, xavfli o'zgarishdan oldin qaytish nuqtasi. Snapshot ham oddiy LV kabi mount qilinadi (`-o ro` bilan; xfs bo'lsa UUID to'qnashuvi sababli `-o ro,nouuid`). LVM yana diskni ishlab turgan tizimdan chiqarishni (`pvmove`, `vgreduce`) va thin provisioning'ni beradi.

Cloud'da LVM'siz ham volume kattalashtiriladi: provayder konsolida disk hajmi oshiriladi, keyin `growpart /dev/vda 1` (bo'limni kengaytiradi) va `resize2fs` yoki `xfs_growfs`. Root disk uchun buni birinchi boot'da cloud-init o'zi bajaradi: `lab` VM'ning `sda1` i shu yo'l bilan 10G diskka yoyilgan.

Misolni tozalash (teskari tartibda):

```
sudo umount /mnt/web
sudo lvremove -y vgdemo/lvweb
sudo vgremove vgdemo
sudo pvremove /dev/loopA /dev/loopB
```

### Real ishda qachon kerak

- "Disk 95% to'ldi" alerti: VG'da joy bo'lsa bitta `lvextend -r` buyrug'i, servis to'xtamaydi. `sudo vgs` dagi `VFree` birinchi qaraladigan raqam.
- Bare-metal va an'anaviy VM'larda `/var`, `/home`, ma'lumot kataloglarini alohida LV qilish: bittasi to'lsa boshqalari va root omon qoladi.
- RHEL oilasidagi distributivlar standart o'rnatishda root'ni ham LVM'ga qo'yadi, shuning uchun `lsblk` da `lvm` turini tez-tez uchratasiz.
- Kubernetes'da ba'zi storage drayverlari (masalan TopoLVM) node'dagi LVM'dan PersistentVolume ajratadi.

### Nima uchun shunday

LVM qo'shimcha qatlam va har qatlam murakkablik: `lsblk` uzunroq, tiklash qiyinroq, yana bitta "kengaytirishni unutdim" joyi. Evaziga saqlash joyi jismoniy disk chegaralaridan ajraladi: hajm rejasini birinchi kuni to'g'ri topish shart emas, noto'g'ri bo'lsa keyin tuzatiladi. Cloud'da bu ehtiyojning katta qismini provayder o'zi yopadi (volume'ni API orqali kattalashtirish, provayder snapshot'lari), shuning uchun u yerda oddiy "butun diskka fayl tizimi" sxemasi keng tarqalgan. btrfs va ZFS esa volume boshqaruvi va fayl tizimini bitta qatlamga birlashtiradi. Qaysi yo'l tanlanmasin, mexanizm bir xil: fayl tizimi ostidagi block device kattalashadi, keyin fayl tizimiga buni aytish kerak.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Block device | belgilangan o'lchamli bloklar bilan ixtiyoriy tartibda o'qiladigan va yoziladigan qurilma (`/dev/sda`) |
| Loop device | oddiy faylni block device qilib ko'rsatadigan kernel qurilmasi (`/dev/loop0`) |
| Sparse fayl | ko'rinadigan hajmi katta, lekin diskda faqat yozilgan qismi joy oladigan fayl |
| Partition | diskning uzluksiz qismi, alohida qurilma sifatida ko'rinadi (`sda1`) |
| Partition table | disk boshidagi bo'limlar ro'yxati; ikki formati MBR va GPT |
| Fayl tizimi | bloklar ustidagi tuzilma: fayllar, kataloglar, huquqlar, bo'sh joy hisobi (ext4, xfs) |
| Superblock | fayl tizimining o'zi haqidagi asosiy yozuv: o'lcham, UUID, holat |
| inode | faylning nomdan boshqa barcha metadata'si va bloklariga ko'rsatkichlar |
| Journal | o'zgarish oldidan yoziladigan niyat qaydi, to'satdan o'chishdan keyin butunlikni saqlaydi |
| UUID | fayl tizimi yaratilganda beriladigan noyob identifikator, qurilma nomidan barqaror |
| Label | fayl tizimiga odam bergan nom (`mkfs -L`) |
| mount | fayl tizimini katalog daraxtining biror nuqtasiga ulash |
| Mount nuqtasi | fayl tizimi ulangan katalog |
| `/etc/fstab` | doimiy mount'lar jadvali, boot paytida systemd undan mount unit'lar yasaydi |
| `nofail` | qurilma topilmasa boot'ni to'xtatmaydigan `fstab` opsiyasi |
| Swap | RAM yetmaganda xotira sahifalari chiqariladigan disk maydoni |
| Page cache | diskdagi fayllarning xotiradagi nusxasi, kerak bo'lsa tashlab yuboriladi |
| Anonim sahifa | jarayonning diskda asli yo'q xotirasi (heap, stack) |
| swappiness | kernel swap'ga chiqarish va keshni tashlash orasida nimani afzal ko'rishini belgilovchi parametr |
| sysctl | kernel parametrlarini ishlab turgan tizimda o'qish va o'zgartirish asbobi |
| OOM killer | xotira tugaganda jarayonni o'ldirib joy bo'shatadigan kernel mexanizmi |
| LVM | disk va fayl tizimi orasidagi moslashuvchan volume boshqaruvi qatlami |
| PV | LVM'ga berilgan disk yoki bo'lim |
| VG | PV'lardan yig'ilgan umumiy joy hovuzi |
| LV | VG'dan ajratilgan virtual bo'lim, ustiga fayl tizimi qo'yiladi |
| PE (extent) | LVM'ning ajratish birligi, standart 4 MiB |
| Device mapper | LV'ga kelgan so'rovlarni PV'larga yo'naltiradigan kernel qatlami (`/dev/mapper/`) |
| Snapshot (LVM) | LV'ning bir lahzadagi holati, faqat o'zgargan bloklarning eski nusxasini saqlaydi |

## Tuzoqlar

- Noto'g'ri qurilmaga `mkfs` yoki `dd`. Har buyruqdan oldin `lsblk -f`; qurilmada fayl tizimi bor-yo'qligini ko'ring.
- `fstab` ga `/dev/sdb1` kabi nom yozish. Disklar tartibi o'zgarsa boshqa disk mount bo'ladi yoki boot to'xtaydi. UUID yoki LVM nomi yozing.
- `fstab` ni `findmnt --verify` va `mount -a` bilan sinamasdan reboot qilish; ma'lumot disklarida `nofail` yozmaslik. Laboratoriyada bundan oldin snapshot oling.
- Faqat `df -h` ga qarab inode tugaganini ko'rmaslik.
- `lvextend` qilib fayl tizimini kengaytirishni unutish, yoki teskarisi: xfs'ni kichraytirishni rejalashtirish.
- VG'dagi hamma joyni birinchi kuni bitta LV'ga berib qo'yish. Zaxira va snapshot uchun joy qolmaydi.
- Mount nuqtasi ostidagi katalogga yozib qo'yish (mount yiqilganda) va root diskni to'ldirish. Servisni mount'ga bog'lang (`RequiresMountsFor=`).
- Yangi fayl tizimiga mount'dan oldin `chown` qilish: egalik ostidagi katalogga yoziladi va mount uni to'sadi. Avval mount, keyin `chown`.
- Swap faylni `600` dan keng huquq bilan qoldirish.
- Diskni to'ldirib, `umount` qila olmay (`target is busy`) majburlash. Avval kim ushlab turganini toping.
- LVM snapshot'ni backup deb hisoblash: u o'sha disklarda yashaydi, disk o'lsa birga yo'qoladi; to'lib qolgan snapshot yaroqsiz bo'ladi.
- Loop raqamini yoddan yozish. Reboot yoki qayta ulashdan keyin `loop0` boshqa faylga tegishli bo'lishi mumkin; `losetup -l` bilan tekshiring.
- macOS host'ida Linux disk buyruqlarini qidirish. `lsblk`, `losetup`, `mkfs.ext4` u yerda yo'q, hammasi `lab` VM'da.

## Manbalar

- https://man7.org/linux/man-pages/man5/fstab.5.html – `fstab(5)` (majburiy)
- https://man7.org/linux/man-pages/man8/mount.8.html – `mount(8)`: opsiyalar
- https://man7.org/linux/man-pages/man8/findmnt.8.html – `findmnt(8)`, `--verify`
- https://man7.org/linux/man-pages/man7/inode.7.html – `inode(7)`
- https://man7.org/linux/man-pages/man8/lsblk.8.html – `lsblk(8)`
- https://man7.org/linux/man-pages/man8/losetup.8.html – `losetup(8)`
- https://man7.org/linux/man-pages/man8/lvm.8.html – `lvm(8)` va tegishli sahifalar
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index – RHEL 9: LVM bo'yicha to'liq qo'llanma
- https://documentation.ubuntu.com/server/explanation/storage/about-lvm/ – Ubuntu Server: LVM haqida
- https://wiki.archlinux.org/title/LVM – ArchWiki LVM (amaliy misollar)
- https://wiki.archlinux.org/title/Swap – ArchWiki Swap: swapfile, swappiness
- https://docs.kernel.org/admin-guide/sysctl/vm.html – `vm.swappiness` rasmiy tavsifi
- https://docs.kernel.org/filesystems/ext4/ – ext4 hujjati
- https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html – systemd va fstab: `nofail`, `x-systemd.*` opsiyalari
- https://documentation.ubuntu.com/multipass/ – Multipass hujjati: `snapshot`, `restore`, `transfer`

## Birga bajaramiz

Bitta "disk" ni bo'sh fayldan boshlab daraxtdagi katalogkacha olib boramiz, unga yozamiz, uzamiz va ma'lumot qayerda yashashini ko'ramiz. Misol vazifalardagidan boshqa: 256M li alohida fayl, bitta GPT bo'lim, `fstab` da UUID emas `LABEL=`, mount nuqtasi `/mnt/walk`. Hamma narsa VM ichida. Loop nomi sizda boshqa bo'lishi mumkin, quyida `/dev/loop0` deb olingan: uni birinchi qadamda chiqqan nomga almashtiring.

1. "Disk" yarating va ulang:

```
ubuntu@lab:~$ sudo mkdir -p /var/tmp/walk
ubuntu@lab:~$ sudo truncate -s 256M /var/tmp/walk/disk.img
ubuntu@lab:~$ ls -lh /var/tmp/walk/disk.img
-rw-r--r-- 1 root root 256M <sana> /var/tmp/walk/disk.img
ubuntu@lab:~$ sudo du -h /var/tmp/walk/disk.img
0	/var/tmp/walk/disk.img
ubuntu@lab:~$ sudo losetup -fP --show /var/tmp/walk/disk.img
/dev/loop0
```

`ls` 256M deydi, `du` 0: fayl sparse, hali bitta blok ham yozilmagan (2-bo'lim). `losetup` qurilma nomini chiqardi.

2. Bo'lim jadvali va bitta bo'lim. Avval qurilma bo'shligiga ishonch hosil qiling:

```
ubuntu@lab:~$ lsblk -f /dev/loop0
NAME  FSTYPE FSVER LABEL UUID FSAVAIL FSUSE% MOUNTPOINTS
loop0
ubuntu@lab:~$ sudo parted -s /dev/loop0 mklabel gpt mkpart walk ext4 1MiB 100%
ubuntu@lab:~$ sudo parted /dev/loop0 print
Model: Loopback device (loopback)
Disk /dev/loop0: 268MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End    Size   File system  Name  Flags
 1      1049kB  267MB  266MB               walk
```

`FSTYPE` bo'sh, demak hech kimning ma'lumoti yo'q. `parted print`: `Partition Table: gpt`, bitta bo'lim 1049kB (1 MiB) dan boshlanadi, `Name` biz bergan `walk`, `File system` ustuni bo'sh, chunki hali formatlanmagan. `parted` o'nlik birliklarda ko'rsatadi (268MB = 256 MiB).

3. Fayl tizimi, label bilan:

```
ubuntu@lab:~$ sudo mkfs.ext4 -L walkdata /dev/loop0p1
ubuntu@lab:~$ lsblk -f /dev/loop0
NAME      FSTYPE FSVER LABEL    UUID   FSAVAIL FSUSE% MOUNTPOINTS
loop0
└─loop0p1 ext4   1.0   walkdata <uuid>
```

Endi `loop0p1` da `ext4`, label va UUID bor. `MOUNTPOINTS` bo'sh: fayl tizimi mavjud, lekin daraxtda hali ko'rinmaydi.

4. `fstab` orqali mount. Zaxira nusxa, qator, tekshiruv, keyin `mount -a`:

```
ubuntu@lab:~$ sudo mkdir -p /mnt/walk
ubuntu@lab:~$ sudo cp /etc/fstab /etc/fstab.bak
ubuntu@lab:~$ echo 'LABEL=walkdata /mnt/walk ext4 defaults,noatime,nofail 0 2' | sudo tee -a /etc/fstab
ubuntu@lab:~$ sudo findmnt --verify
Success, no errors or warnings detected
ubuntu@lab:~$ sudo systemctl daemon-reload
ubuntu@lab:~$ sudo mount -a
ubuntu@lab:~$ findmnt /mnt/walk
TARGET    SOURCE       FSTYPE OPTIONS
/mnt/walk /dev/loop0p1 ext4   rw,noatime
```

`tee -a` faylga qo'shib yozadi (`-a` siz butun `fstab` ni o'chirib yuborardi, shuning uchun zaxira nusxa birinchi). `findmnt` da `SOURCE` label emas, haqiqiy qurilma: label faqat qidirish usuli. `OPTIONS` da `noatime` bor, `nofail` yo'q, chunki u kernel opsiyasi emas, systemd uchun ko'rsatma.

5. Yozing va qatlamlarni tekshiring:

```
ubuntu@lab:~$ sudo chown ubuntu:ubuntu /mnt/walk
ubuntu@lab:~$ echo "hello from the loop disk" > /mnt/walk/note.txt
ubuntu@lab:~$ stat -c '%n inode=%i links=%h dev=%D' /mnt/walk/note.txt /etc/hostname
/mnt/walk/note.txt inode=12 links=1 dev=<...>
/etc/hostname inode=<N> links=1 dev=<...>
ubuntu@lab:~$ sudo du -h /var/tmp/walk/disk.img
<N>M	/var/tmp/walk/disk.img
```

`chown` mount'dan keyin qilindi, shuning uchun egalik yangi fayl tizimining ildiziga yozildi. Ikki faylning `dev` qiymati har xil: ular ikki boshqa fayl tizimida, inode raqamlari esa har fayl tizimida mustaqil sanaladi (yangi ext4 da birinchi oddiy fayl odatda 12-inode, 11-si `lost+found`). `du` endi 0 emas: `mkfs` va bizning yozuvimiz faylning bir qismini haqiqatan to'ldirdi.

6. `target is busy` va uzish:

```
ubuntu@lab:~$ cd /mnt/walk
ubuntu@lab:/mnt/walk$ sudo umount /mnt/walk
umount: /mnt/walk: target is busy.
ubuntu@lab:/mnt/walk$ cd ~
ubuntu@lab:~$ sudo umount /mnt/walk
ubuntu@lab:~$ ls -A /mnt/walk
ubuntu@lab:~$ sudo losetup -d /dev/loop0
```

Aybdor o'z shell'imiz edi: joriy katalogi mount ichida. Chiqqach `umount` o'tdi. `ls -A` bo'sh: `note.txt` yo'qolmadi, biz endi ostidagi bo'sh katalogni ko'ryapmiz. `losetup -d` "diskni sug'urib oldi".

7. "Disk yo'q" holatida `fstab` qatori nima qiladi:

```
ubuntu@lab:~$ sudo mount -a
mount: /mnt/walk: can't find LABEL=walkdata.
ubuntu@lab:~$ sudo losetup -fP --show /var/tmp/walk/disk.img
/dev/loop0
ubuntu@lab:~$ sudo mount -a
ubuntu@lab:~$ cat /mnt/walk/note.txt
hello from the loop disk
```

Qurilma yo'qligida `mount -a` xato beradi, lekin tizim ishlayveradi; boot paytida aynan shu holatda `nofail` systemd'ni to'xtab qolishdan saqlaydi. Diskni qayta ulaganimizdan keyin fayl joyida: ma'lumot fayl tizimining ichida, fayl tizimi esa `disk.img` ichida yashaydi, mount va loop ulanishi faqat unga yo'l.

8. Tozalash, teskari tartibda:

```
ubuntu@lab:~$ sudo umount /mnt/walk
ubuntu@lab:~$ sudo losetup -d /dev/loop0
ubuntu@lab:~$ sudo cp /etc/fstab.bak /etc/fstab
ubuntu@lab:~$ sudo systemctl daemon-reload
ubuntu@lab:~$ sudo findmnt --verify
Success, no errors or warnings detected
ubuntu@lab:~$ sudo rm -r /var/tmp/walk && sudo rmdir /mnt/walk
```

Shu 8 qadamda ko'rganingiz: fayl block device bo'ldi (1-bo'lim), unda bo'lim va fayl tizimi paydo bo'ldi (1 va 2-bo'limlar), `fstab` qatori tekshirilib mount qilindi (3 va 4-bo'limlar), ma'lumot mount'ga emas fayl tizimiga tegishli ekani tasdiqlandi. Vazifalarda xuddi shu qatlamlarni UUID, xfs, swap va LVM bilan o'zingiz qurasiz.

---

## Vazifalar

Ish papkasi: `linux/13-disks/` (`make new m=linux n=13 name=disks` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (skript, unit, `fstab` parchasi) yoniga saqlang. Barcha vazifalar `lab` VM ichida bajariladi; host'ga oid savollar ixtiyoriy va faqat o'qiydigan buyruqlar bilan. Har o'zgartiruvchi buyruqdan oldin `lsblk` bilan qurilma nomini tekshiring. `fstab` ga tegadigan vazifalardan oldin Laboratoriya bo'limidagi snapshot'ni oling. Har vazifa oxiridagi "Yo'nalish" qaysi bo'limga qarash kerakligini aytadi, yechimni emas.

### A. Qurilmalar va inode

1. **Map your disks.** VM'da `lsblk`, `lsblk -f`, `df -hT`, `findmnt /` ni oling va qatlamlarni chizing (disk, bo'limlar, bor bo'lsa LVM/LUKS, fayl tizimi, mount nuqtasi). Root fayl tizimining turi va UUID'i nima, `/etc/fstab` da u qanday yozilgan va nima uchun UUID bilan emas? Ixtiyoriy, host uchun: Zorin'da xuddi shu to'rt buyruq (faqat o'qish), macOS'da `diskutil list` va `df -h`; farqlarni yozing. `loop` qurilmalar nima uchun ko'p bo'lishi mumkin (12-dars)? Yo'nalish: 1-bo'lim, "Misol: lsblk" va 4-bo'lim.

2. **stat and inodes.** VM'da uy katalogingizda fayl yaratib `stat` chiqishini o'qing: `Size` va `Blocks` nima uchun mos kelmaydi, `Links` nima? Faylga `chmod` qiling, keyin mazmunini o'zgartiring, keyin `cat` bilan o'qing: har safar uch vaqtning qaysi biri o'zgardi va qaysi biri kutganingizdek o'zgarmadi? Hard link yaratib (6-dars) ikkala nomning inode raqami va `Links` sonini ko'rsating. `df -i /` da inode'larning necha foizi band? Yo'nalish: 2-bo'lim, "inode".

3. **Loop devices.** VM'da Laboratoriya bo'limidagi kabi uchta 512M fayl yarating va uchalasini loop device sifatida ulang. `ls -lh` va `du -h` fayllar uchun nima ko'rsatadi va nima uchun farq qiladi? `losetup -l` va `lsblk` chiqishidan o'z qurilmalaringizni toping va nomlarini README'ga yozib qo'ying (keyingi vazifalarda `loopA`, `loopB`, `loopC` shular). Yo'nalish: Laboratoriya va 1-bo'lim, "Loop device".

4. **Partition table.** Birinchi loop qurilmada `parted -s` bilan GPT jadval va ikkita bo'lim yarating (yarmidan). `lsblk` va `sudo parted /dev/loopA print` chiqishini ko'rsating va ustunlarini izohlang. Keyin bo'limlar jadvalini o'chiring (`sudo wipefs -a /dev/loopA`) va natijani tekshiring: keyingi vazifalarda qurilma butunligicha ishlatiladi. Yo'nalish: 1-bo'lim, "Partition".

### B. Fayl tizimi, mount, fstab

5. **mkfs and mount.** Birinchi qurilmada ext4 (label bilan), ikkinchisida xfs yarating. `/mnt/e4` va `/mnt/xfs` ga mount qiling. `lsblk -f`, `df -hT`, `findmnt` chiqishlarini ko'rsating. Ikkalasida `Size` 512M dan qanchaga kichik va nima uchun? ext4 uchun `tune2fs -l` dan `Inode count`, `Reserved block count`, `Block size` ni toping va zaxira necha foiz ekanini hisoblang. Yo'nalish: 2-bo'lim, "mkfs" va 3-bo'lim.

6. **Mount hides content.** `/mnt/e4` ni unmount qiling. Bo'sh `/mnt/e4` katalogiga `under.txt` fayl yarating, keyin qayta mount qiling: fayl ko'rinadimi? Mount ichida `over.txt` yarating, unmount qiling: endi nima ko'rinadi? Bu xatti-harakat production'da qanday ikki muammoga olib kelishini yozing. Yo'nalish: 3-bo'lim, "Tuzoq: mount mavjud mazmunni yopadi".

7. **Target is busy.** Bir terminalda `cd /mnt/e4` qilib turing, ikkinchisida (`multipass shell lab` ni yana bir oynada oching) `sudo umount /mnt/e4` bajaring. Xatoni yozing, aybdor jarayonni ikki xil buyruq bilan toping, muammoni hal qilib unmount qiling. `umount -l` (lazy) nima qiladi va nima uchun uni odat qilmaslik kerak (`man umount`)? Yo'nalish: 3-bo'lim, "Tuzoq: target is busy".

8. **Inode exhaustion.** Uchinchi qurilmada kam inode bilan ext4 yarating: `sudo mkfs.ext4 -N 1000 /dev/loopC`, `/mnt/small` ga mount qiling. Sikl bilan bo'sh fayllar yarating (`touch`), xato chiqquncha. Xato matni nima? `df -h /mnt/small` va `df -i /mnt/small` ni yonma-yon ko'rsating. Nechta fayl sig'di va bu son nima uchun so'ralgan 1000 ga teng emas? Unmount qilib, `wipefs -a` bilan qurilmani tozalang. Yo'nalish: 2-bo'lim, "Inode'lar soni chekli".

9. **fstab with UUID.** ext4 va xfs fayl tizimlarini `/etc/fstab` ga UUID orqali, `nofail` bilan yozing (avval zaxira nusxa va snapshot). 4-bo'limdagi tartibni to'liq bajaring: `findmnt --verify`, `daemon-reload`, `umount`, `mount -a`. `fstab` dagi o'z qatorlaringizni ish papkasiga `task_9.fstab` qilib saqlang. `systemctl list-units --type=mount | grep mnt` nimani ko'rsatadi va bu unit'lar qayerdan paydo bo'ldi? Yo'nalish: 4-bo'lim, "Mexanizm: fstab'ni kim o'qiydi".

10. **Break fstab safely.** `fstab` ga uchinchi qator qo'shing: mavjud bo'lmagan UUID, `nofail` bilan, `x-systemd.device-timeout=10s` bilan. `findmnt --verify` va `mount -a` nima deydi? `sudo reboot` qiling. VM ko'tarildimi? `lsblk`, `losetup -l`, `findmnt /mnt/e4`, `systemctl --failed` va `journalctl -b -p warning | grep -i -E 'mount|loop|dev-disk'` ni oling. Sizning to'g'ri qatorlaringiz ham mount bo'lmadi: nima uchun (Laboratoriya bo'limini eslang)? `nofail` bo'lmaganda nima bo'lardi (sinamang, tushuntiring) va Multipass'da undan qanday chiqilardi? Loop'larni qayta ulab `mount -a` bilan tiklang va noto'g'ri qatorni o'chiring. Yo'nalish: 4-bo'lim, "Tuzoq: xato fstab bilan reboot".

### C. Swap

11. **Swapfile.** `free -h` va `swapon --show` bilan boshlang'ich holatni yozing. 512M swapfile yarating va yoqing. Huquqni `644` qoldirib `swapon` qilsangiz nima deydi (sinab, keyin to'g'rilang)? `fstab` ga qo'shing, `swapoff -a` va `swapon -a` bilan qator ishlashini tekshiring. Oxirida `vm.swappiness` ni 10 ga o'zgartirib, `/etc/sysctl.d/` orqali doimiy qiling (`sudo sysctl --system` chiqishida faylingiz ko'rinsin) va "swappiness=10 degani RAM 90% to'lganda swap boshlanadi" degan gap nima uchun noto'g'ri ekanini kernel hujjatiga tayanib yozing. Yo'nalish: 5-bo'lim.

12. **Swap under pressure.** `stress-ng --vm 1 --vm-bytes 90% --timeout 60s` (8-dars) ni swap bilan ishga tushirib, ikkinchi terminalda `vmstat 1` da `si`/`so` va `swpd` ni kuzating. Keyin `swapoff` qilib takrorlang: endi nima bo'ldi, `journalctl -k` da nima bor? Ikki natijani "swap kerakmi" savoliga javob sifatida talqin qiling. Yo'nalish: 5-bo'lim, "swappiness" oxiri va "Nima uchun shunday".

### D. LVM

13. **PV, VG, LV.** 9-vazifadagi ikki fayl tizimini unmount qiling, `fstab` qatorlarini olib tashlang, qurilmalarni `wipefs -a` bilan tozalang. Ikkita qurilmadan `vgdata` yarating, undan 300M `lvdata` ajrating, ext4 qo'yib `/srv/data` ga mount qiling. `pvs`, `vgs`, `lvs`, `lsblk` chiqishlarini ko'rsating. VG hajmi nima uchun 1024M dan biroz kichik? `/dev/vgdata/lvdata` va `/dev/mapper/vgdata-lvdata` nimaga ishora qiladi (`ls -l`)? Yo'nalish: 6-bo'lim, "Mexanizm" va "Misol: yaratish".

14. **Extend online.** `/srv/data` ga yozishni davom ettiradigan fon siklini ishga tushiring (`while true; do date >> /srv/data/heartbeat.log; sleep 1; done &`; yozish huquqi qanday berilishini o'zingiz hal qiling). Volume'ni `dd` bilan deyarli to'ldiring va `df -h` ni ko'rsating. Avval faqat `lvextend -L +200M` qiling: `lvs` va `df -h` nima deydi? Keyin fayl tizimini kengaytiring. So'ng bir qadamda (`-r` bilan) yana 100M qo'shing. `heartbeat.log` da uzilish bormi (vaqt belgilarini tekshiring)? Yo'nalish: 6-bo'lim, "Online kengaytirish".

15. **Grow the pool.** `lvextend -l +100%FREE -r` bilan VG'ni tugating, `vgs` da `VFree` 0 ekanini ko'rsating. Yana 100M so'rang: xato nima? Uchinchi qurilmani `pvcreate` va `vgextend` bilan qo'shib, so'rovni takrorlang. Yakuniy `pvs`, `vgs`, `lvs`, `df -h /srv/data` ni ko'rsating. Fon siklini to'xtating. Yo'nalish: 6-bo'lim, "Online kengaytirish".

16. **Snapshot.** Uchinchi qurilma hisobidan qolgan joyda `lvdata` ning 100M snapshot'ini yarating. `/srv/data` da bir faylni o'chiring va boshqasini o'zgartiring. Snapshot'ni `/mnt/snap` ga `ro` mount qilib, eski holat saqlanganini ko'rsating. `lvs` dagi `Data%` ustuni nimani bildiradi va 100% ga yetsa nima bo'ladi? Snapshot'ni unmount qilib `lvremove` bilan o'chiring. Snapshot nima uchun backup emasligini 2 gapda yozing. Yo'nalish: 6-bo'lim, "Snapshot va boshqa imkoniyatlar".

17. **xfs cannot shrink.** VG'da 300M `lvx` yarating, xfs qo'yib mount qiling (`mkfs.xfs` hajmni kichik desa, xabarni yozib oling va LV'ni biroz kattaroq qiling), `lvextend -r` bilan 100M kengaytiring (qaysi asbob chaqirilganini chiqishdan toping). Keyin kichraytirishga urinib ko'ring: `sudo lvreduce -r -L -100M /dev/vgdata/lvx`. Nima deydi? `lvx` ni unmount qilib o'chiring. LV hajmini rejalashtirish bo'yicha qoidangizni yozing. Yo'nalish: 2-bo'lim, "ext4, xfs, btrfs" va 6-bo'lim.

### E. Mini-loyiha (8–13-darslar)

Bitta VM'da kichik "production" yig'asiz. 10-darsdagi `deploy` va `demoapp` foydalanuvchilari, 11-darsdagi `demoapp.service` kerak bo'ladi; ular shu VM'da yo'q bo'lsa (masalan boshqa mashinada ishlayapsiz), Laboratoriya bo'limidagi "Oldingi darslar holati" bo'yicha tiklang. D guruhdagi `vgdata` dan foydalaning: joy yetmasa `/srv/data` ni unmount qilib `lvdata` ni o'chiring.

18. **Project: storage.** `vgdata` da 300M `lvapp` yarating (ext4), `/srv/demoapp` ga `fstab` orqali (`nofail`, `noatime`) mount qiling. Diqqat: 11-darsda `/srv/demoapp` da fayllar bor edi; mount ularni yopadi (6-vazifa). Mazmunni yangi volume'ga to'g'ri ko'chiring, egasi `demoapp`. `demoapp.service` ga `RequiresMountsFor=/srv/demoapp` qo'shing va bu nima berishini `systemctl list-dependencies demoapp` bilan ko'rsating. `curl` bilan servis ishlashini tasdiqlang. Yo'nalish: 3 va 4-bo'limlar, 11-darsdagi unit tahriri.

19. **Project: operations.** (a) `deploy` foydalanuvchisiga faqat `systemctl restart|status demoapp` va `journalctl -u demoapp` uchun parolsiz `sudo` bering (10-dars) va `deploy` sifatida SSH orqali kirib sinang. (b) `sysstat` paketini o'rnating (12-dars). (c) Har 5 daqiqada `/srv/demoapp/status.txt` ni qayta yozadigan timer yozing (11-dars): sana, `uptime`, `free -m` ning `Mem:` qatori, `df -h /srv/demoapp`, `systemctl is-active demoapp` (8-dars). `curl localhost:<port>/status.txt` natijasini ko'rsating. Unit, timer, skript va sudoers fayllarini ish papkasiga saqlang. Yo'nalish: 10, 11, 12-darslardagi o'z README'laringiz.

20. **Project: incident drill.** Ikki hodisani o'ynang va har birini 8-darsdagi checklist bo'yicha tashxislab, qadamlaringizni yozing. (a) Jarayon o'limi: `demoapp` ning asosiy jarayoniga `SIGKILL` yuboring (9-dars); servis qancha vaqtda qaytdi, journal'da nima yozildi, `NRestarts` nechchi? (b) Disk to'lishi: `sudo -u demoapp dd if=/dev/zero of=/srv/demoapp/fill.bin bs=1M` bilan volume'ni to'ldiring. `status.txt` timer'i va servis loglarida nima ko'rindi? `df` va `du` bilan sababni toping, lekin faylni o'chirmang: buning o'rniga servisni to'xtatmasdan volume'ni 200M ga kengaytiring. Kengaytirish paytida ikkinchi terminalda `while true; do curl -s -o /dev/null -w '%{http_code}\n' localhost:<port>; sleep 1; done` ishlab tursin: uzilish bo'ldimi? Yo'nalish: 6-bo'lim, "Online kengaytirish" va 8-darsdagi checklist.

21. **Project: reboot and runbook.** VM'ni reboot qiling. Nima ko'tarilmadi va nima uchun: `systemctl --failed`, `systemctl status demoapp`, `journalctl -b -u demoapp`, `lsblk` bilan ko'rsating. `RequiresMountsFor=` bo'lmaganda servis nima qilgan bo'lardi va bu nima uchun yomonroq? Tiklash qadamlarini bajaring (loop'larni ulash, kerak bo'lsa `sudo vgchange -ay vgdata`, `mount -a`, servisni ishga tushirish) va ularni bitta `recover.sh` skriptiga yozing (`shellcheck` toza). README'ga shu "server" uchun bir sahifalik runbook yozing: arxitektura (qatlamlar sxemasi), deploy, kuzatish buyruqlari, "disk to'ldi" va "servis failed" holatlari uchun qadamlar, real serverda loop o'rnida nima bo'lishi va qaysi qadamlar keraksiz bo'lib qolishi. Yo'nalish: 4-bo'lim, "Nima uchun shunday" va 3-bo'limdagi birinchi tuzoq.

22. **Cleanup.** Hammasini teskari tartibda yig'ishtiring: servis va timer'larni to'xtatib `disable` qiling, `fstab` va `sysctl.d` dagi qatorlaringizni olib tashlang, `umount`, `swapoff` va swapfile'ni o'chirish, `lvremove`, `vgremove`, `pvremove`, `losetup -d`, `/var/tmp/lab` ni o'chirish. Yakuniy `lsblk`, `losetup -l`, `sudo vgs`, `swapon --show`, `findmnt --verify`, `systemctl --failed` chiqishlarini ko'rsating. Modul tugadi: VM kerak bo'lmasa host'da `multipass stop lab` (keyingi modullarda yana ishlatiladi), keraksiz snapshot'larni `multipass list --snapshots` bilan ko'rib chiqing. Yo'nalish: Laboratoriya, "Tozalash tartibi".

### Topshirish

Tayyor bo'lgach:
1. `linux/13-disks/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida; har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor.
2. `make check` toza o'tadi (host'da; `shellcheck` skriptlar uchun).
3. Ish papkasida `task_9.fstab`, unit, timer, sudoers fayllari, `recover.sh` va runbook bor; secret va private kalit yo'q.
4. VM tozalangan: begona `fstab` qatorlari, VG, loop va swapfile yo'q, `findmnt --verify` xatosiz, reboot'dan keyin VM muammosiz ko'tariladi.
5. Host'da (Zorin yoki macOS) hech narsa o'zgartirilmagan: disk, `fstab`, swap.
6. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Diskdan fayl nomigacha bo'lgan qatlamlarni tartib bilan ayting. LVM qayerda turadi?
- Loop device nima va bu darsda nima uchun haqiqiy disk o'rnida ishlatildi? Reboot'dan keyin nima yo'qoladi, nima qoladi?
- Inode nima saqlaydi, nima saqlamaydi? `df -h` joy bor desa ham yozib bo'lmasligi mumkinmi?
- `ls -l` va `du` bitta fayl uchun nima sababdan har xil hajm ko'rsatishi mumkin?
- `fstab` da nima uchun `/dev/sdb1` emas, UUID yoziladi?
- `fstab` ni tahrirlagandan keyin reboot'dan oldin qaysi tekshiruvlarni qilasiz va `nofail` nima uchun kerak?
- Bo'sh bo'lmagan katalogga mount qilinsa undagi fayllar bilan nima bo'ladi? Docker bind mount'da bu qanday ko'rinadi?
- PV, VG, LV nima va oddiy bo'limga nisbatan LVM nima beradi?
- LV'ni online kengaytirish qaysi ikki qadamdan iborat va nima uchun ikkita?
- ext4 va xfs orasida kichraytirish bo'yicha farq nima va bu rejalashtirishga qanday ta'sir qiladi?
- `vm.swappiness` nimani boshqaradi, swap'siz serverda xotira tugasa nima bo'ladi?
- Servis ma'lumot katalogi alohida volume'da. Mount yiqilganda servis ishga tushmasligi nima uchun to'g'ri xatti-harakat?
- Bu darsning qaysi qismini macOS host'ida bajarib bo'lmaydi va nima uchun bu muammo emas?
