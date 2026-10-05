# 13-dars: Disk va fayl tizimlari

Maqsad: "disk" dan "katalogdagi fayl" gacha bo'lgan qatlamlarni tushunish: block device, partition, (ixtiyoriy) LVM, fayl tizimi, mount nuqtasi. 8-darsda `df` va `du` bilan joyni ko'rdingiz, 6-darsda inode va link bilan tanishdingiz; bu darsda shu narsalar qanday yaratilishi va kengaytirilishini o'rganasiz. Amaliy natija: yangi diskni formatlab, reboot'dan keyin ham saqlanadigan qilib mount qilish, to'lgan volume'ni servisni to'xtatmasdan kengaytirish, swap sozlash. Cloud'da volume ulash, Kubernetes'dagi PersistentVolume va Docker volume'lar shu tushunchalarga tayanadi. Dars oxirida 8–13-darslarni birlashtiruvchi mini-loyiha bor.

Taxminiy vaqt: 3–4 kun (siz uchun), shundan 1 kun mini-loyiha. Diqqatni quyidagilarga qarating: qatlamlar tartibi, inode tugashi, `/etc/fstab` da UUID va `nofail`, `mount -a` bilan tekshirmasdan reboot qilmaslik, LVM'da kengaytirish ikki qadam ekani (LV, keyin fayl tizimi), xfs kichraytirilmasligi.

## Laboratoriya

- Ish mashinasida faqat o'qish: `lsblk`, `lsblk -f`, `df -hT`, `df -i`, `findmnt`, `stat`, `cat /etc/fstab`, `swapon --show`. Ish mashinasida `mkfs`, `fdisk`, `parted`, `dd of=/dev/...`, `/etc/fstab` tahriri bajarilmaydi: bitta noto'g'ri qurilma nomi ma'lumotni qaytarib bo'lmas qilib o'chiradi.
- Hamma o'zgartiruvchi vazifalar Multipass VM ichida (`multipass shell lab`). Multipass VM'ga ikkinchi disk ulashning oddiy buyrug'i yo'q, shuning uchun "disk" sifatida **loop device** ishlatiladi: oddiy fayl kernel'ga block device qilib ko'rsatiladi. Real serverda farqi faqat nomda (`/dev/vdb`, `/dev/nvme1n1`).
- VM'da bo'sh joy: `df -h /` kamida 3 GB bo'sh ko'rsatsin (uchta 512M fayl, swapfile va zaxira). Kam bo'lsa VM'ni kattaroq disk bilan qayta yarating (`multipass launch` ning `--disk` opsiyasi). Paketlar: `sudo apt install -y lvm2 xfsprogs parted` (odatda o'rnatilgan).
- Disk fayllarini yaratish va ulash:

```
sudo mkdir -p /var/tmp/lab
sudo truncate -s 512M /var/tmp/lab/d1.img /var/tmp/lab/d2.img /var/tmp/lab/d3.img
sudo losetup -fP --show /var/tmp/lab/d1.img     # prints the device, e.g. /dev/loop5
losetup -l                                      # which file is attached where
```

- `truncate` sparse fayl yaratadi: 512M ko'rinadi, diskda yozilgan qismigina joy oladi. Loop raqamlari har mashinada har xil (snap'lar ham loop ishlatadi), har doim `losetup` chiqargan nomni ishlating. Quyida ular `/dev/loopA`, `/dev/loopB`, `/dev/loopC` deb yoziladi.
- Loop ulanishi reboot'da yo'qoladi (fayllar qoladi). Bu darsda ataylab ishlatiladigan xususiyat.
- Har buyruqdan oldin qurilma nomini `lsblk` bilan tekshiring. VM butunlay buzilsa: `multipass delete lab && multipass purge` va 2-darsdagi buyruq bilan qayta yaratish.
- Tozalash tartibi (teskari): `umount`, `swapoff`, `lvremove`/`vgremove`/`pvremove`, `losetup -d`, fayllarni o'chirish, `/etc/fstab` dan qatorlarni olib tashlash.

---

## 1. Block device'lar

Block device bu belgilangan o'lchamli bloklar bilan ixtiyoriy tartibda o'qiladigan/yoziladigan qurilma. Kernel ularni `/dev` da fayl sifatida ko'rsatadi:

| Nom | Nima |
|-----|------|
| `/dev/sda`, `/dev/sdb` | SCSI/SATA/USB disklar; bo'limlari `sda1`, `sda2` |
| `/dev/vda` | virtio disk (KVM/QEMU VM'lar) |
| `/dev/nvme0n1` | NVMe: 0-kontroller, 1-namespace; bo'limlari `nvme0n1p1` |
| `/dev/xvda` | Xen (eski AWS instanslari) |
| `/dev/loop0` | loop device: fayl block device sifatida |
| `/dev/mapper/vg-lv`, `/dev/dm-0` | device mapper: LVM, shifrlash (LUKS) |

```
$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   10G  0 disk
├─sda1    8:1    0    9G  0 part /
└─sda15   8:15   0  106M  0 part /boot/efi
```

`lsblk -f` fayl tizimi tipi, label va UUID'ni, `blkid /dev/sda1` bitta qurilma uchun shularni ko'rsatadi. `TYPE` ustuni qatlamni bildiradi: `disk`, `part`, `lvm`, `loop`.

**Tuzoq: qurilma nomlari barqaror emas.** `/dev/sdb` kernel disklarni topgan tartibga bog'liq: disk qo'shilsa yoki cloud instans qayta ishga tushsa `sdb` va `sdc` almashib qolishi mumkin. Barqaror identifikatorlar `/dev/disk/by-uuid/`, `/dev/disk/by-id/` da; `fstab` da shular ishlatiladi.

### Partition

Disk bo'limlarga bo'linadi, bo'limlar jadvali disk boshida saqlanadi:

| | MBR (dos) | GPT |
|---|-----------|-----|
| Maksimal hajm | 2 TiB | amalda cheksiz |
| Bo'limlar soni | 4 ta primary | standart 128 |
| Zaxira nusxa | yo'q | disk oxirida |

Asboblar: `fdisk` (interaktiv), `parted` (skriptda `-s` bilan), ko'rish uchun `sudo fdisk -l` yoki `sudo parted -l`.

```
$ sudo parted -s /dev/loopA mklabel gpt mkpart data ext4 1MiB 100%
$ lsblk /dev/loopA            # loopAp1 appears (losetup -P enables partition scan)
```

Cloud'da ma'lumot disklari ko'pincha bo'limlarga bo'linmaydi: butun diskka to'g'ridan-to'g'ri fayl tizimi yoki LVM qo'yiladi, chunki keyin diskni kattalashtirish osonroq (bo'lim jadvalini siljitish kerak emas).

## 2. Fayl tizimi va inode

Block device shunchaki raqamlangan bloklar. Fayl tizimi ularning ustiga tuzilma quradi: qaysi bloklar qaysi faylga tegishli, fayl nomlari, huquqlar.

### inode

Har fayl va katalog uchun bitta **inode**: tipi, huquqlari, egasi (UID/GID), hajmi, vaqt belgilari, hard link'lar soni va ma'lumot bloklariga ko'rsatkichlar. Inode'da **fayl nomi yo'q**. Nom katalogda saqlanadi: katalog bu "nom, inode raqami" juftliklari ro'yxati. 6-darsdagi xulosalar shundan: hard link bir inode'ga ikkinchi nom, `mv` bir fayl tizimi ichida faqat katalog yozuvini o'zgartiradi, o'chirilgan lekin ochiq fayl joy egallab turadi (8-dars).

```
$ ls -i /etc/hostname
$ stat /etc/hostname      # Size, Blocks, Inode, Links, Access/Modify/Change times
$ df -i                   # inode usage per filesystem
```

`stat` dagi uch vaqt: `Modify` (mazmun o'zgargan), `Change` (inode o'zgargan: huquq, egasi, nom), `Access` (o'qilgan).

**Tuzoq: inode tugashi.** ext4 da inode'lar soni `mkfs` paytida belgilanadi va keyin o'zgarmaydi. Millionlab mayda fayl (sessiya fayllari, kesh, mail navbati) inode'larni tugatadi: `df -h` bo'sh joy ko'rsatadi, lekin har yozish `No space left on device` beradi. Tekshirish `df -i`, qaysi katalogda ekanini topish: `sudo du --inodes -x / | sort -n | tail`.

### ext4, xfs, btrfs

| | ext4 | xfs | btrfs |
|---|------|-----|-------|
| Standart qayerda | Debian, Ubuntu | RHEL, Rocky, Amazon Linux | openSUSE, Fedora desktop |
| Inode'lar | `mkfs` da belgilanadi | dinamik | dinamik |
| Kattalashtirish | online, `resize2fs` | online, `xfs_growfs` | online |
| Kichraytirish | faqat unmount qilingan holda | **mumkin emas** | online |
| Xususiyati | sodda, eng ko'p sinalgan | katta fayllar va parallel yozishda kuchli | copy-on-write, snapshot, subvolume, checksum |
| Tekshirish/tuzatish | `e2fsck` | `xfs_repair` | `btrfs check`, `btrfs scrub` |

Uchalasi ham journal yoki CoW orqali to'satdan o'chishdan keyin tuzilmaning butunligini saqlaydi. Tanlov odatda distributivning standartiga ergashadi; xfs tanlasangiz kichraytira olmasligingizni oldindan biling.

### mkfs

```
$ sudo mkfs.ext4 -L data /dev/loopA
$ sudo mkfs.xfs /dev/loopB
```

`mkfs` qurilmadagi mavjud ma'lumotni yo'q qiladi va tasdiq so'ramaydi (xfs mavjud fayl tizimini ko'rsa `-f` talab qiladi, ext4 so'rab o'tadi yoki skriptda jim ishlaydi). Zamonaviy `mkfs.xfs` 300 MB dan kichik qurilmani rad etadi.

ext4 standart holatda bloklarning 5 foizini root uchun zaxiralaydi (disk to'lganda ham tizim servislari yoza olsin). Shuning uchun `df` da `Used + Avail` `Size` dan kichik. Faqat ma'lumot saqlanadigan katta volume'da buni kamaytirish mumkin: `sudo tune2fs -m 1 /dev/...`. Parametrlarni ko'rish: `sudo tune2fs -l /dev/...`.

## 3. mount

Fayl tizimi katalog daraxtining biror nuqtasiga ulangachgina ko'rinadi. Linux'da disk harflari yo'q, hammasi bitta `/` daraxtida.

```
$ sudo mkdir -p /mnt/data
$ sudo mount /dev/loopA /mnt/data
$ findmnt /mnt/data                 # source, fstype, options
$ sudo umount /mnt/data
```

| Opsiya | Ma'nosi |
|--------|---------|
| `defaults` | `rw,suid,dev,exec,auto,nouser,async` |
| `ro` / `rw` | faqat o'qish / o'qish-yozish |
| `noatime` | o'qishda access vaqtini yangilamaslik (kamroq yozish) |
| `noexec`, `nosuid`, `nodev` | binary bajarish, setuid, device fayllarni taqiqlash (`/tmp`, yuklangan fayllar uchun himoya) |
| `nofail` | qurilma topilmasa boot to'xtamasin |

Ishlab turgan mount'ni opsiyasini o'zgartirish: `sudo mount -o remount,ro /mnt/data`.

**Tuzoq: mount mavjud mazmunni yopadi.** Bo'sh bo'lmagan katalogga mount qilsangiz, eski fayllar o'chmaydi, lekin ko'rinmay qoladi va joy egallab turadi. Teskari holat xavfliroq: mount yiqilgan bo'lsa dastur ma'lumotni ostidagi katalogga, ya'ni root diskka yozadi va uni to'ldiradi, keyin mount tiklanganda "ma'lumot yo'qoldi" bo'lib ko'rinadi.

**Tuzoq: `target is busy`.** Biror jarayon shu fayl tizimida fayl ochgan yoki joriy katalogi shu yerda bo'lsa `umount` rad etadi. Kimligini `sudo lsof +f -- /mnt/data` yoki `sudo fuser -vm /mnt/data` ko'rsatadi. Ko'pincha aybdor o'zingizning shell'ingiz (`cd /mnt/data` da turibsiz).

## 4. /etc/fstab

Qo'lda qilingan `mount` reboot'gacha yashaydi. Doimiy mount'lar `/etc/fstab` da, har qatorda 6 maydon:

```
# <device>                                 <mountpoint>  <type>  <options>        <dump> <pass>
UUID=3f2a9c1e-7b1d-4c58-9d0e-5a6b7c8d9e0f  /mnt/data     ext4    defaults,nofail  0      2
```

| # | Maydon | Izoh |
|---|--------|------|
| 1 | qurilma | `UUID=...` (tavsiya), `LABEL=...`, `/dev/mapper/vg-lv` (LVM nomlari barqaror), yoki yo'l |
| 2 | mount nuqtasi | mavjud katalog; swap uchun `none` |
| 3 | tip | `ext4`, `xfs`, `swap`, `nfs` |
| 4 | opsiyalar | vergul bilan, bo'sh joysiz |
| 5 | dump | eskirgan, `0` |
| 6 | fsck tartibi | `0` tekshirilmaydi, `1` root, `2` qolganlar. xfs uchun `0` |

UUID fayl tizimi yaratilganda beriladi va uning ichida saqlanadi: `sudo blkid -s UUID -o value /dev/loopA`.

Tahrirdan keyingi majburiy tartib:

```
$ sudo cp /etc/fstab /etc/fstab.bak
$ sudo nano /etc/fstab
$ sudo findmnt --verify            # syntax and sanity check
$ sudo systemctl daemon-reload     # systemd generates mount units from fstab
$ sudo mount -a                    # mount everything not yet mounted
$ findmnt /mnt/data
```

**Tuzoq: xato `fstab` bilan reboot.** `nofail` siz yozilgan qator ishlamasa (UUID'da xato, disk olib tashlangan), systemd boot'ni to'xtatib `emergency.target` ga tushadi (11-dars). SSH ko'tarilmaydi; cloud'da bu serial console yoki diskni boshqa instansga ulab tuzatish degani. Qoidalar: har doim `mount -a` bilan sinash, root'dan boshqa hamma qatorga `nofail`, zaxira nusxa. Qurilmani kutish vaqti standart 90 soniya, `x-systemd.device-timeout=10s` opsiyasi bilan qisqartiriladi.

## 5. Swap

Swap bu RAM yetmaganda kernel kam ishlatilgan xotira sahifalarini chiqarib qo'yadigan disk maydoni: alohida bo'lim yoki oddiy fayl (swapfile). Cloud VM'lar va Multipass VM odatda swap'siz keladi.

```
$ sudo dd if=/dev/zero of=/swapfile bs=1M count=512 status=progress
$ sudo chmod 600 /swapfile
$ sudo mkswap /swapfile
$ sudo swapon /swapfile
$ swapon --show ; free -h
```

Doimiy qilish uchun `fstab` qatori: `/swapfile none swap sw 0 0`. O'chirish: `sudo swapoff /swapfile`. Fayl huquqi `600` bo'lishi shart: swap'da boshqa jarayonlarning xotirasi (parollar, kalitlar) yotadi.

### swappiness

`vm.swappiness` (0 dan 200 gacha, standart 60) kernel xotira bo'shatishda nimani afzal ko'rishini belgilaydi: anonim sahifalarni swap'ga chiqarishnimi yoki page cache'ni tashlashnimi. Past qiymat swap'dan qochadi, lekin bu "RAM necha foiz to'lganda swap boshlanadi" degan chegara emas.

```
$ cat /proc/sys/vm/swappiness
$ sudo sysctl vm.swappiness=10                                   # until reboot
$ echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
$ sudo sysctl --system                                           # load all sysctl files
```

Swap kerakmi: kichik swap kutilmagan xotira cho'qqisida OOM killer o'rniga sekinlashuv beradi va tashxis qo'yishga vaqt qoldiradi. Latency muhim bo'lgan servislarda (ma'lumotlar bazalari) past swappiness qo'yiladi. Kubernetes node'larida an'anaviy ravishda swap o'chiriladi, chunki kubelet standart sozlamada swap yoqilgan node'da ishga tushmaydi.

## 6. LVM

Oddiy bo'limning chegarasi qattiq: to'lsa, kengaytirish uchun undan keyingi joy bo'sh bo'lishi kerak. **LVM** disk va fayl tizimi orasiga moslashuvchan qatlam qo'yadi.

| Tushuncha | Nima | Buyruqlar |
|-----------|------|-----------|
| PV (physical volume) | LVM'ga berilgan disk yoki bo'lim | `pvcreate`, `pvs`, `pvdisplay` |
| VG (volume group) | bir yoki bir nechta PV'dan yig'ilgan umumiy hovuz | `vgcreate`, `vgextend`, `vgs` |
| LV (logical volume) | hovuzdan ajratilgan "virtual bo'lim", ustiga fayl tizimi qo'yiladi | `lvcreate`, `lvextend`, `lvs` |
| PE (physical extent) | ajratish birligi, standart 4 MiB | |

```
disks:   /dev/loopA    /dev/loopB        (PV)
              \            /
             vgdata  (VG, one pool)
              /            \
        lvdata 600M     free space       (LV)
             |
        ext4 on /dev/vgdata/lvdata  ->  mounted at /srv/data
```

Yaratish:

```
$ sudo pvcreate /dev/loopA /dev/loopB
$ sudo vgcreate vgdata /dev/loopA /dev/loopB
$ sudo lvcreate -n lvdata -L 600M vgdata
$ sudo mkfs.ext4 /dev/vgdata/lvdata
$ sudo mount /dev/vgdata/lvdata /srv/data
```

LV ikki nom bilan ko'rinadi: `/dev/vgdata/lvdata` va `/dev/mapper/vgdata-lvdata` (ikkalasi `/dev/dm-N` ga symlink). Bu nomlar barqaror, `fstab` da ishlatsa bo'ladi. `-l 100%FREE` VG'dagi hamma bo'sh joyni beradi.

### Online kengaytirish

Kengaytirish har doim ikki qadam: avval LV (block device), keyin uning ichidagi fayl tizimi.

```
$ sudo vgextend vgdata /dev/loopC            # add a new disk to the pool (if VG is full)
$ sudo lvextend -L +300M /dev/vgdata/lvdata  # grow the LV
$ sudo resize2fs /dev/vgdata/lvdata          # grow ext4, mounted
$ sudo xfs_growfs /srv/data                  # for xfs: takes the mountpoint
```

Yoki bir qadamda: `sudo lvextend -r -L +300M /dev/vgdata/lvdata` (`-r`, ya'ni `--resizefs`, fayl tizimini ham o'zi kengaytiradi). `-L 1G` aniq hajm, `-L +300M` qo'shimcha, `-l +100%FREE` qolgan hamma joy. Fayl tizimi mount qilingan holda, servis to'xtamasdan bajariladi.

**Tuzoq: `lvextend` dan keyin `df` o'zgarmadi.** LV kattalashdi (`lvs` ko'rsatadi), fayl tizimi esa eski hajmda. Ikkinchi qadam unutilgan.

Kichraytirish boshqa gap: xfs umuman kichraymaydi, ext4 faqat unmount holda va avval fayl tizimi, keyin LV tartibida; tartib buzilsa ma'lumot yo'qoladi. Shuning uchun LV'ni kichik yaratib, kerak bo'lganda kattalashtirish va VG'da bo'sh joy qoldirish odat.

LVM yana nimalar beradi: **snapshot** (`lvcreate -s -n snap -L 100M vgdata/lvdata`: LV'ning shu lahzadagi holati, backup yoki xavfli o'zgarishdan oldin), diskni ishlab turgan tizimdan chiqarish (`pvmove`, `vgreduce`), thin provisioning.

Cloud'da LVM'siz ham volume kattalashtiriladi: provayder konsolida disk hajmi oshiriladi, keyin `growpart /dev/vda 1` (bo'limni kengaytiradi) va `resize2fs`/`xfs_growfs`. Root disk uchun buni birinchi boot'da cloud-init o'zi bajaradi.

## Tuzoqlar

- Noto'g'ri qurilmaga `mkfs` yoki `dd`. Har buyruqdan oldin `lsblk -f`; qurilmada fayl tizimi bor-yo'qligini ko'ring.
- `fstab` ga `/dev/sdb1` kabi nom yozish. Disklar tartibi o'zgarsa boshqa disk mount bo'ladi yoki boot to'xtaydi. UUID yoki LVM nomi.
- `fstab` ni `findmnt --verify` va `mount -a` bilan sinamasdan reboot qilish; ma'lumot disklarida `nofail` yozmaslik.
- Faqat `df -h` ga qarab inode tugaganini ko'rmaslik.
- `lvextend` qilib fayl tizimini kengaytirishni unutish, yoki teskarisi: xfs'ni kichraytirishni rejalashtirish.
- VG'dagi hamma joyni birinchi kuni bitta LV'ga berib qo'yish. Zaxira va snapshot uchun joy qolmaydi.
- Mount nuqtasi ostidagi katalogga yozib qo'yish (mount yiqilganda) va root diskni to'ldirish. Servisni mount'ga bog'lang (`RequiresMountsFor=`).
- Swap faylni `600` dan keng huquq bilan qoldirish.
- Diskni to'ldirib, `umount` qila olmay (`target is busy`) majburlash. Avval kim ushlab turganini toping.
- LVM snapshot'ni backup deb hisoblash: u o'sha disklarda yashaydi, disk o'lsa birga yo'qoladi; to'lib qolgan snapshot yaroqsiz bo'ladi.

## Manbalar

- https://man7.org/linux/man-pages/man5/fstab.5.html – fstab(5) (majburiy)
- https://man7.org/linux/man-pages/man8/mount.8.html – mount(8): opsiyalar
- https://man7.org/linux/man-pages/man7/inode.7.html – inode(7)
- https://man7.org/linux/man-pages/man8/lsblk.8.html – lsblk(8)
- https://man7.org/linux/man-pages/man8/losetup.8.html – losetup(8)
- https://man7.org/linux/man-pages/man8/lvm.8.html – lvm(8) va tegishli sahifalar
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/index – RHEL 9: LVM bo'yicha to'liq qo'llanma
- https://documentation.ubuntu.com/server/explanation/storage/about-lvm/ – Ubuntu Server: LVM haqida
- https://wiki.archlinux.org/title/LVM – ArchWiki LVM (amaliy misollar)
- https://wiki.archlinux.org/title/Swap – ArchWiki Swap: swapfile, swappiness
- https://docs.kernel.org/admin-guide/sysctl/vm.html – `vm.swappiness` rasmiy tavsifi
- https://docs.kernel.org/filesystems/ext4/ – ext4 hujjati
- https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html – systemd va fstab: `nofail`, `x-systemd.*` opsiyalari

---

## Vazifalar

Ish papkasi: `linux/13-disks/` (`make new m=linux n=13 name=disks` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (skript, unit, `fstab` parchasi) yoniga saqlang. 1–2-vazifalar ish mashinasida (faqat o'qish), qolgan hammasi VM'da. Har o'zgartiruvchi buyruqdan oldin `lsblk` bilan qurilma nomini tekshiring.

### A. Qurilmalar va inode

1. **Map your disks.** Ish mashinasida va VM'da `lsblk`, `lsblk -f`, `df -hT`, `findmnt /` ni oling. Har ikkisi uchun qatlamlarni chizing (disk, bo'limlar, bor bo'lsa LVM/LUKS, fayl tizimi, mount nuqtasi). `loop` qurilmalar nima uchun ko'p (12-dars)? Root fayl tizimining tipi va UUID'i nima, `/etc/fstab` da u qanday yozilgan?

2. **stat and inodes.** Ish mashinasida biror fayl uchun `stat` chiqishini o'qing: `Size` va `Blocks` nima uchun mos kelmaydi, `Links` nima? Faylga `chmod` qiling, keyin mazmunini o'zgartiring: har safar uch vaqtning qaysi biri o'zgardi? Hard link yaratib (6-dars) ikkala nomning inode raqami va `Links` sonini ko'rsating. `df -i /` da inode'larning necha foizi band?

3. **Loop devices.** VM'da Laboratoriya bo'limidagi kabi uchta 512M fayl yarating va uchalasini loop device sifatida ulang. `ls -lh` va `du -h` fayllar uchun nima ko'rsatadi va nima uchun farq qiladi? `losetup -l` va `lsblk` chiqishidan o'z qurilmalaringizni toping va nomlarini yozib qo'ying.

4. **Partition table.** Birinchi loop qurilmada `parted -s` bilan GPT jadval va ikkita bo'lim yarating (yarmidan). `lsblk` va `sudo parted /dev/loopA print` chiqishini ko'rsating. Keyin bo'limlar jadvalini o'chiring (`sudo wipefs -a /dev/loopA`) va natijani tekshiring: keyingi vazifalarda qurilma butunligicha ishlatiladi.

### B. Fayl tizimi, mount, fstab

5. **mkfs and mount.** Birinchi qurilmada ext4 (label bilan), ikkinchisida xfs yarating. `/mnt/e4` va `/mnt/xfs` ga mount qiling. `lsblk -f`, `df -hT`, `findmnt` chiqishlarini ko'rsating. Ikkalasida `Size` 512M dan qanchaga kichik va nima uchun? ext4 uchun `tune2fs -l` dan `Inode count`, `Reserved block count`, `Block size` ni toping.

6. **Mount hides content.** `/mnt/e4` ni unmount qiling. Bo'sh `/mnt/e4` katalogiga `under.txt` fayl yarating, keyin qayta mount qiling: fayl ko'rinadimi? Mount ichida `over.txt` yarating, unmount qiling: endi nima ko'rinadi? Bu xatti-harakat production'da qanday ikki muammoga olib kelishini yozing.

7. **Target is busy.** Bir terminalda `cd /mnt/e4` qilib turing, ikkinchisida `sudo umount /mnt/e4` bajaring. Xatoni yozing, aybdor jarayonni ikki xil buyruq bilan toping, muammoni hal qilib unmount qiling. `umount -l` (lazy) nima qiladi va nima uchun uni odat qilmaslik kerak?

8. **Inode exhaustion.** Uchinchi qurilmada kam inode bilan ext4 yarating: `sudo mkfs.ext4 -N 1000 /dev/loopC`, `/mnt/small` ga mount qiling. Sikl bilan bo'sh fayllar yarating (`touch`), xato chiqquncha. Xato matni nima? `df -h /mnt/small` va `df -i /mnt/small` ni yonma-yon ko'rsating. Nechta fayl sig'di? Unmount qilib, `wipefs -a` bilan qurilmani tozalang.

9. **fstab with UUID.** ext4 va xfs fayl tizimlarini `/etc/fstab` ga UUID orqali, `nofail` bilan yozing (avval zaxira nusxa). 4-bo'limdagi tartibni to'liq bajaring: `findmnt --verify`, `daemon-reload`, `umount`, `mount -a`. `fstab` dagi o'z qatorlaringizni ish papkasiga `task_9.fstab` qilib saqlang. `systemctl list-units --type=mount | grep mnt` nimani ko'rsatadi va bu unit'lar qayerdan paydo bo'ldi?

10. **Break fstab safely.** `fstab` ga uchinchi qator qo'shing: mavjud bo'lmagan UUID, `nofail` bilan, `x-systemd.device-timeout=10s` bilan. `findmnt --verify` va `mount -a` nima deydi? `sudo reboot` qiling. VM ko'tarildimi? `lsblk`, `losetup -l`, `findmnt /mnt/e4`, `systemctl --failed` va `journalctl -b -p warning | grep -i -E 'mount|loop|dev-disk'` ni oling. Sizning to'g'ri qatorlaringiz ham mount bo'lmadi: nima uchun (Laboratoriya bo'limini eslang)? `nofail` bo'lmaganda nima bo'lardi (sinamang, tushuntiring)? Loop'larni qayta ulab `mount -a` bilan tiklang va noto'g'ri qatorni o'chiring.

### C. Swap

11. **Swapfile.** `free -h` va `swapon --show` bilan boshlang'ich holatni yozing. 512M swapfile yarating va yoqing. Huquqni `644` qoldirib `swapon` qilsangiz nima deydi (sinab, keyin to'g'rilang)? `fstab` ga qo'shing, `swapoff -a` va `swapon -a` bilan qator ishlashini tekshiring. Oxirida `vm.swappiness` ni 10 ga o'zgartirib, `/etc/sysctl.d/` orqali doimiy qiling (`sudo sysctl --system` chiqishida faylingiz ko'rinsin) va "swappiness=10 degani RAM 90% to'lganda swap boshlanadi" degan gap nima uchun noto'g'ri ekanini kernel hujjatiga tayanib yozing.

12. **Swap under pressure.** `stress-ng --vm 1 --vm-bytes 90% --timeout 60s` (8-dars) ni swap bilan ishga tushirib `vmstat 1` da `si`/`so` va `swpd` ni kuzating. Keyin `swapoff` qilib takrorlang: endi nima bo'ldi, `journalctl -k` da nima bor? Ikki natijani "swap kerakmi" savoliga javob sifatida talqin qiling.

### D. LVM

13. **PV, VG, LV.** 9-vazifadagi ikki fayl tizimini unmount qiling, `fstab` qatorlarini olib tashlang, qurilmalarni `wipefs -a` bilan tozalang. Ikkita qurilmadan `vgdata` yarating, undan 300M `lvdata` ajrating, ext4 qo'yib `/srv/data` ga mount qiling. `pvs`, `vgs`, `lvs`, `lsblk` chiqishlarini ko'rsating. VG hajmi nima uchun 1024M dan biroz kichik? `/dev/vgdata/lvdata` va `/dev/mapper/vgdata-lvdata` nimaga ishora qiladi?

14. **Extend online.** `/srv/data` ga yozishni davom ettiradigan fon siklini ishga tushiring (`while true; do date >> /srv/data/heartbeat.log; sleep 1; done &`). Volume'ni `dd` bilan deyarli to'ldiring va `df -h` ni ko'rsating. Avval faqat `lvextend -L +200M` qiling: `lvs` va `df -h` nima deydi? Keyin fayl tizimini kengaytiring. So'ng bir qadamda (`-r` bilan) yana 100M qo'shing. `heartbeat.log` da uzilish bormi (vaqt belgilarini tekshiring)?

15. **Grow the pool.** `lvextend -l +100%FREE -r` bilan VG'ni tugating, `vgs` da `VFree` 0 ekanini ko'rsating. Yana 100M so'rang: xato nima? Uchinchi qurilmani `pvcreate` va `vgextend` bilan qo'shib, so'rovni takrorlang. Yakuniy `pvs`, `vgs`, `lvs`, `df -h /srv/data` ni ko'rsating. Fon siklini to'xtating.

16. **Snapshot.** Uchinchi qurilma hisobidan qolgan joyda `lvdata` ning 100M snapshot'ini yarating. `/srv/data` da bir faylni o'chiring va boshqasini o'zgartiring. Snapshot'ni `/mnt/snap` ga `ro` mount qilib, eski holat saqlanganini ko'rsating. `lvs` dagi `Data%` ustuni nimani bildiradi va 100% ga yetsa nima bo'ladi? Snapshot'ni unmount qilib `lvremove` bilan o'chiring. Snapshot nima uchun backup emasligini 2 gapda yozing.

17. **xfs cannot shrink.** VG'da 300M `lvx` yarating, xfs qo'yib mount qiling, `lvextend -r` bilan 100M kengaytiring (qaysi asbob chaqirilganini chiqishdan toping). Keyin kichraytirishga urinib ko'ring: `sudo lvreduce -r -L -100M /dev/vgdata/lvx`. Nima deydi? `lvx` ni unmount qilib o'chiring. LV hajmini rejalashtirish bo'yicha qoidangizni yozing.

### E. Mini-loyiha (8–13-darslar)

Bitta VM'da kichik "production" yig'asiz. 10-darsdagi `deploy` va `demoapp` foydalanuvchilari, 11-darsdagi `demoapp.service` kerak bo'ladi. D guruhdagi `vgdata` dan foydalaning: joy yetmasa `/srv/data` ni unmount qilib `lvdata` ni o'chiring.

18. **Project: storage.** `vgdata` da 300M `lvapp` yarating (ext4), `/srv/demoapp` ga `fstab` orqali (`nofail`, `noatime`) mount qiling. Diqqat: 11-darsda `/srv/demoapp` da fayllar bor edi; mount ularni yopadi (6-vazifa). Mazmunni yangi volume'ga to'g'ri ko'chiring, egasi `demoapp`. `demoapp.service` ga `RequiresMountsFor=/srv/demoapp` qo'shing va bu nima berishini `systemctl list-dependencies demoapp` bilan ko'rsating. `curl` bilan servis ishlashini tasdiqlang.

19. **Project: operations.** (a) `deploy` foydalanuvchisiga faqat `systemctl restart|status demoapp` va `journalctl -u demoapp` uchun parolsiz `sudo` bering (10-dars) va `deploy` sifatida SSH orqali kirib sinang. (b) `sysstat` paketini o'rnating (12-dars). (c) Har 5 daqiqada `/srv/demoapp/status.txt` ni qayta yozadigan timer yozing (11-dars): sana, `uptime`, `free -m` ning `Mem:` qatori, `df -h /srv/demoapp`, `systemctl is-active demoapp` (8-dars). `curl localhost:<port>/status.txt` natijasini ko'rsating. Unit, timer, skript va sudoers fayllarini ish papkasiga saqlang.

20. **Project: incident drill.** Ikki hodisani o'ynang va har birini 8-darsdagi checklist bo'yicha tashxislab, qadamlaringizni yozing. (a) Jarayon o'limi: `demoapp` ning asosiy jarayoniga `SIGKILL` yuboring (9-dars); servis qancha vaqtda qaytdi, journal'da nima yozildi, `NRestarts` nechchi? (b) Disk to'lishi: `sudo -u demoapp dd if=/dev/zero of=/srv/demoapp/fill.bin bs=1M` bilan volume'ni to'ldiring. `status.txt` timer'i va servis loglarida nima ko'rindi? `df` va `du` bilan sababni toping, lekin faylni o'chirmang: buning o'rniga servisni to'xtatmasdan volume'ni 200M ga kengaytiring. Kengaytirish paytida ikkinchi terminalda `while true; do curl -s -o /dev/null -w '%{http_code}\n' localhost:<port>; sleep 1; done` ishlab tursin: uzilish bo'ldimi?

21. **Project: reboot and runbook.** VM'ni reboot qiling. Nima ko'tarilmadi va nima uchun: `systemctl --failed`, `systemctl status demoapp`, `journalctl -b -u demoapp`, `lsblk` bilan ko'rsating. `RequiresMountsFor=` bo'lmaganda servis nima qilgan bo'lardi va bu nima uchun yomonroq? Tiklash qadamlarini bajaring (loop'larni ulash, kerak bo'lsa `sudo vgchange -ay vgdata`, `mount -a`, servisni ishga tushirish) va ularni bitta `recover.sh` skriptiga yozing (`shellcheck` toza). README'ga shu "server" uchun bir sahifalik runbook yozing: arxitektura (qatlamlar sxemasi), deploy, kuzatish buyruqlari, "disk to'ldi" va "servis failed" holatlari uchun qadamlar, real serverda loop o'rnida nima bo'lishi va qaysi qadamlar keraksiz bo'lib qolishi.

22. **Cleanup.** Hammasini teskari tartibda yig'ishtiring: servis va timer'larni to'xtatib `disable` qiling, `fstab` va `sysctl.d` dagi qatorlaringizni olib tashlang, `umount`, `swapoff` va swapfile'ni o'chirish, `lvremove`, `vgremove`, `pvremove`, `losetup -d`, `/var/tmp/lab` ni o'chirish. Yakuniy `lsblk`, `losetup -l`, `sudo vgs`, `swapon --show`, `findmnt --verify`, `systemctl --failed` chiqishlarini ko'rsating. Modul tugadi: VM kerak bo'lmasa `multipass stop lab` (keyingi modullarda yana ishlatiladi).

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi (`shellcheck` skriptlar uchun).
2. Ish papkasida `fstab` parchasi, unit/timer/sudoers fayllari, `recover.sh` va runbook bor; secret va private kalit yo'q.
3. VM tozalangan: begona `fstab` qatorlari, VG, loop va swapfile yo'q, `findmnt --verify` xatosiz, reboot'dan keyin VM muammosiz ko'tariladi.
4. Ish mashinasida hech narsa o'zgartirilmagan.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Diskdan fayl nomigacha bo'lgan qatlamlarni tartib bilan ayting. LVM qayerda turadi?
- Inode nima saqlaydi, nima saqlamaydi? `df -h` joy bor desa ham yozib bo'lmasligi mumkinmi?
- `fstab` da nima uchun `/dev/sdb1` emas, UUID yoziladi?
- `fstab` ni tahrirlagandan keyin reboot'dan oldin qaysi tekshiruvlarni qilasiz va `nofail` nima uchun kerak?
- Bo'sh bo'lmagan katalogga mount qilinsa undagi fayllar bilan nima bo'ladi?
- PV, VG, LV nima va oddiy bo'limga nisbatan LVM nima beradi?
- LV'ni online kengaytirish qaysi ikki qadamdan iborat va nima uchun ikkita?
- ext4 va xfs orasida kichraytirish bo'yicha farq nima va bu rejalashtirishga qanday ta'sir qiladi?
- `vm.swappiness` nimani boshqaradi, swap'siz serverda xotira tugasa nima bo'ladi?
- Servis ma'lumot katalogi alohida volume'da. Mount yiqilganda servis ishga tushmasligi nima uchun to'g'ri xatti-harakat?
