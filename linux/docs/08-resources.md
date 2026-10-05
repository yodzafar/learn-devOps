# 8-dars: Server resurslarini ko'rish

Maqsad: "server sekin ishlayapti" degan shikoyatga tizimli javob berishni o'rganish. To'rt asosiy resurs (CPU, xotira, disk, tarmoq) va ikki ma'lumot manbai (loglar, servislar holati) bo'yicha qaysi buyruq nimani ko'rsatishini, raqamlarni qanday o'qishni va qaysi raqam aldashini bilish kerak. 7-darsdagi `grep`/`awk`/pipe bu yerda loglarni filtrlash uchun ishlatiladi. Keyingi darslar shu yerda ko'rilgan narsalarni chuqurlashtiradi: 9-dars jarayonlar, 11-dars systemd va journal, 13-dars disk.

Taxminiy vaqt: 2 kun (siz uchun). Buyruqlarni yodlash emas, talqin muhim. Diqqatni quyidagilarga qarating: load average CPU foizi emasligi, `free` dagi `available` ustuni, `wa` va `st` nimani bildirishi, `df` va `du` nima uchun har xil raqam berishi, OOM killer izini logdan topish.

## Laboratoriya

- Faqat o'qiydigan buyruqlar (`uptime`, `top`, `free`, `df`, `journalctl`) ish mashinasida ham, VM'da ham bajariladi. Ikkalasini solishtirish foydali.
- Yuklama yaratadigan vazifalar (CPU, xotira, disk to'ldirish) faqat 2-darsda yaratilgan Multipass Ubuntu 24.04 VM ichida. Quyida VM nomi `lab` deb olinadi, sizda boshqacha bo'lsa almashtiring: `multipass shell lab`.
- VM'da kerakli paketlar: `sudo apt update && sudo apt install -y sysstat htop stress-ng`. `sysstat` paketi `mpstat`, `iostat`, `pidstat`, `sar` ni beradi.
- Xotira limiti bilan tajriba uchun ish mashinasida bir martalik konteyner: `docker run --rm -m 100m ubuntu:24.04 ...` (limit cgroup ichida, mashinaga ta'sir qilmaydi).
- Tozalash: yaratilgan katta fayllarni o'chiring (`rm`), `stress-ng` jarayonlari qolmaganini `pgrep stress-ng` bilan tekshiring.

---

## 1. Umumiy holat: uptime va load average

```
$ uptime
 16:49:36 up  4:40,  1 user,  load average: 1.61, 1.15, 0.73
```

Uchta son oxirgi 1, 5 va 15 daqiqa uchun o'rtacha load. Xuddi shu ma'lumot `/proc/loadavg` da.

### Load average nima

Linux'da load bu ma'lum paytda **CPU kutayotgan yoki ishlatayotgan** (holati `R`) va **uzilmas kutishda turgan** (holati `D`, odatda disk I/O) task'lar sonining eksponensial o'rtachasi. Ikki xulosa:

- Load CPU foizi emas. Uni yadrolar soni bilan solishtirish kerak: `nproc`. 4 yadroli mashinada load 4.0 "hamma yadro band, navbat yo'q" degani, 8.0 esa "har ishlayotgan task'ga bitta kutayotgan task to'g'ri keladi".
- Load baland, CPU bo'sh bo'lishi mumkin. Sekin disk yoki osilib qolgan NFS'ni kutayotgan jarayonlar `D` holatida turadi va loadni oshiradi. Shuning uchun load faqat "nimadir kutilyapti" deydi, nima ekanini keyingi asboblar ko'rsatadi.

Uch sonning nisbati yo'nalishni beradi: `8.0, 3.0, 1.0` muammo hozir boshlangan, `1.0, 3.0, 8.0` muammo o'tib ketyapti.

### PSI (pressure stall information)

Zamonaviy kernel aniqroq o'lchov beradi: `/proc/pressure/cpu`, `/proc/pressure/memory`, `/proc/pressure/io`. `some avg10=12.50` degani oxirgi 10 soniyaning 12.5 foizida kamida bitta task shu resursni kutib to'xtab turgan. Load'dan farqi: resurs bo'yicha ajratilgan va foizda.

## 2. CPU

### top

`top` har 3 soniyada yangilanadi. Yuqori qismdagi `%Cpu(s)` qatori:

| Maydon | Ma'nosi | Baland bo'lsa |
|--------|---------|---------------|
| `us` | user space kodi | dastur hisob-kitob qilyapti |
| `sy` | kernel kodi (syscall'lar) | ko'p I/O, ko'p context switch, ko'p fork |
| `ni` | nice qiymati musbat jarayonlar | past prioritetli fon ishlari |
| `id` | bo'sh | |
| `wa` | CPU bo'sh, lekin I/O kutilyapti | disk sekin yoki to'yingan |
| `hi`, `si` | hardware va software interrupt'lar | tarmoq yuklamasi katta |
| `st` | steal: hypervisor boshqa VM'ga bergan vaqt | cloud'da "shovqinli qo'shni" yoki burstable instansda CPU krediti tugagan |

Foydali tugmalar: `1` har yadroni alohida ko'rsatadi, `P` CPU bo'yicha, `M` xotira bo'yicha saralaydi, `c` to'liq buyruq qatori, `k` signal yuborish, `q` chiqish. Skriptda bir marta olish: `top -b -n 1 | head -20`.

Jarayon qatoridagi `%CPU` bitta yadroga nisbatan: ko'p thread'li jarayon 4 yadroda 400% gacha ko'rsatishi mumkin. `VIRT` band qilingan virtual manzil maydoni (deyarli foydasiz raqam), `RES` haqiqatda RAM'da turgan qismi, `SHR` boshqalar bilan bo'lishilgan qismi.

**Tuzoq: bitta yadro 100%, umumiy CPU 12%.** 8 yadroli mashinada bitta thread'li jarayon (masalan Node.js event loop) bir yadroni to'liq band qilsa, umumiy qator 12.5% ko'rsatadi va "CPU bo'sh" deb o'ylaysiz. `top` da `1` bosing yoki `mpstat -P ALL` ishlating.

### htop, mpstat, vmstat, pidstat

- `htop`: `top` ning qulay varianti (ranglar, daraxt ko'rinishi `F5`, filtr `F4`, qidiruv `F3`). Odatda o'rnatilmagan bo'ladi, production serverda `top` ni bilish shart.
- `mpstat -P ALL 1 5`: har yadro bo'yicha, 1 soniya oraliq bilan 5 marta.
- `pidstat 1`: jarayonlar bo'yicha CPU, vaqt o'qi bilan. `pidstat -d 1` disk I/O, `pidstat -r 1` xotira.
- `vmstat 1 5`: bitta qatorda butun tizim.

```
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 0  0 2097044 1748364 166292 5030512    0    0     0    12 5667 7819  6  2 92  0  0  0
```

| Ustun | Ma'nosi |
|-------|---------|
| `r` | CPU navbatidagi va ishlayotgan task'lar. Doimiy ravishda `nproc` dan katta bo'lsa CPU yetishmayapti |
| `b` | I/O kutib bloklangan task'lar |
| `si`, `so` | swap'dan o'qish va swap'ga yozish (KiB/s). Doimiy noldan katta bo'lsa xotira yetishmayapti |
| `bi`, `bo` | block device'dan o'qilgan va yozilgan bloklar |
| `in`, `cs` | soniyadagi interrupt va context switch'lar |

**Tuzoq: `vmstat`, `iostat`, `mpstat` ning birinchi qatori.** Oraliq bilan chaqirilganda birinchi qator boot'dan beri o'rtacha, hozirgi holat emas. Har doim ikkinchi qatordan boshlab o'qing.

## 3. Xotira

```
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi        10Gi       1.7Gi       1.3Gi       5.0Gi       5.0Gi
Swap:          2.0Gi       2.0Gi       104Ki
```

### buff/cache va available

Kernel bo'sh RAM'ni behuda turg'izmaydi: o'qilgan va yozilgan fayl ma'lumotlarini **page cache** da saqlaydi, keyingi o'qish diskka bormaydi. `buff/cache` shu kesh (va fayl tizimi metama'lumotlari uchun buferlar). Dasturga xotira kerak bo'lsa kernel keshning toza qismini darhol bo'shatadi.

Shuning uchun `free` ustuni kichik bo'lishi normal holat. To'g'ri savol "yangi dastur uchun qancha xotira bor": bunga `available` javob beradi (bo'sh xotira va tez bo'shatsa bo'ladigan kesh yig'indisi bo'yicha kernel bahosi). Manba: `/proc/meminfo` dagi `MemAvailable`.

Xotira haqiqatan tugayotganining belgilari: `available` `total` ning bir necha foiziga tushgan, `vmstat` da `si`/`so` doimiy noldan katta, `/proc/pressure/memory` da `some` o'sgan.

### Swap

Swap'da ma'lumot borligi o'zi muammo emas: kernel uzoq vaqt ishlatilmagan sahifalarni chiqarib qo'ygan bo'lishi mumkin. Muammo **faol** swap almashinuvi (`si`/`so`), chunki disk RAM'dan minglab marta sekin. Swap sozlash 13-darsda.

### OOM killer

Xotira va swap tugab, kernel hech narsani bo'shata olmasa, Out-Of-Memory killer bitta jarayonni tanlab `SIGKILL` yuboradi. Tanlov `/proc/<PID>/oom_score` bo'yicha (asosan xotira iste'moliga bog'liq), `/proc/<PID>/oom_score_adj` (-1000 dan 1000 gacha) bilan tuzatiladi: -1000 jarayonni butunlay himoya qiladi.

Jarayon uchun bu ogohlantirishsiz o'lim: uning o'z logida hech narsa qolmaydi. Iz faqat kernel logida:

```
$ sudo dmesg -T | grep -i -E 'out of memory|oom-kill|killed process'
$ journalctl -k --since "1 hour ago" | grep -i 'killed process'
```

Konteyner va systemd servislarida xotira limiti cgroup orqali qo'yiladi. Limitdan oshgan jarayonni ham OOM killer o'ldiradi, garchi mashinada RAM bo'sh bo'lsa ham. Kernel logida bu `Memory cgroup out of memory` deb yoziladi, Docker'da exit code 137 (128 + 9, 9-darsda) va `docker inspect` da `OOMKilled: true`.

## 4. Disk

### Joy: df va du

- `df -h`: fayl tizimlari bo'yicha band va bo'sh joy. `df -hT` tipini ham ko'rsatadi. `tmpfs`, `squashfs` (snap `loop` qurilmalari) qatorlari real disk emas.
- `df -i`: inode'lar bo'yicha. Joy bor, lekin inode tugagan bo'lsa ham `No space left on device` chiqadi (13-darsda).
- `du -sh /var/log`: katalog egallagan joy. Eng katta kataloglarni topish:

```
$ sudo du -xh --max-depth=1 /var | sort -h | tail -5
```

`-x` boshqa fayl tizimlariga o'tmaydi, `sort -h` `K`/`M`/`G` qo'shimchalarini tushunadi.

**Tuzoq: `df` to'la deydi, `du` joy topolmaydi.** Fayl o'chirilgan, lekin uni ochib turgan jarayon hali ishlayapti: nom yo'qolgan, bloklar esa jarayon faylni yopmaguncha band (6-darsdagi inode va link tushunchasi). Bunday fayllarni `sudo lsof +L1` ko'rsatadi. Yechim: jarayonni qayta ishga tushirish yoki log faylni o'chirish o'rniga bo'shatish (`truncate -s 0 app.log`).

### I/O: iostat

```
$ iostat -xz 1
Device  r/s  w/s  rkB/s  wkB/s  r_await  w_await  aqu-sz  %util
```

| Ustun | Ma'nosi |
|-------|---------|
| `r/s`, `w/s` | soniyadagi o'qish va yozish so'rovlari (IOPS) |
| `rkB/s`, `wkB/s` | o'tkazuvchanlik |
| `r_await`, `w_await` | so'rovning o'rtacha kutish vaqti, ms (navbat va bajarilish birga). Asosiy ko'rsatkich |
| `aqu-sz` | o'rtacha navbat uzunligi |
| `%util` | qurilma band bo'lgan vaqt ulushi |

`-x` kengaytirilgan ustunlar, `-z` faoliyatsiz qurilmalarni yashiradi. `%util` 100% ga yaqinligi eski aylanuvchi disk uchun to'yinishni bildiradi, SSD/NVMe va cloud volume'lar so'rovlarni parallel bajargani uchun ularda bu raqam kam narsa aytadi, `await` va `aqu-sz` ga qarang. Qaysi jarayon yozayotganini `pidstat -d 1` ko'rsatadi.

## 5. Loglar

### journalctl

systemd tizimlarida kernel, servislar va ularning stdout/stderr chiqishi **journal** ga tushadi (binar format, `journalctl` bilan o'qiladi).

| Buyruq | Nima ko'rsatadi |
|--------|-----------------|
| `journalctl -u ssh` | bitta unit loglari |
| `journalctl -u ssh -f` | jonli kuzatish (`tail -f` kabi) |
| `journalctl -u ssh -n 50 --no-pager` | oxirgi 50 qator, pager'siz |
| `journalctl -p err -b` | joriy boot'dan beri `err` va undan og'ir xabarlar |
| `journalctl --since "1 hour ago"` | vaqt oralig'i (`--until` ham bor) |
| `journalctl -k` | faqat kernel xabarlari |
| `journalctl -b -1` | oldingi boot loglari |
| `journalctl -xe` | oxiriga o'tib, izohlar bilan |
| `journalctl --disk-usage` | journal egallagan joy |

Prioritetlar syslog darajalari: `emerg`(0), `alert`, `crit`, `err`(3), `warning`, `notice`, `info`, `debug`(7). `-p warning` shu daraja va undan og'irlarini beradi. Oddiy foydalanuvchi faqat o'z loglarini ko'radi; hammasi uchun `sudo` yoki `adm`/`systemd-journal` guruhiga a'zolik kerak.

Journal hajmi `sudo journalctl --vacuum-size=200M` bilan qisqartiriladi, doimiy limit `/etc/systemd/journald.conf` dagi `SystemMaxUse=`.

### /var/log

Journal bilan birga matnli loglar ham bor (Ubuntu'da `rsyslog` yozadi), ularni 7-darsdagi asboblar bilan o'qiysiz:

| Fayl (Ubuntu) | RHEL oilasida | Mazmuni |
|---------------|---------------|---------|
| `/var/log/syslog` | `/var/log/messages` | umumiy tizim logi |
| `/var/log/auth.log` | `/var/log/secure` | login, `sudo`, SSH |
| `/var/log/kern.log` | `/var/log/messages` | kernel |
| `/var/log/dpkg.log`, `/var/log/apt/history.log` | `/var/log/dnf.log` | paket o'rnatish tarixi |
| `/var/log/nginx/`, `/var/log/postgresql/` | xuddi shunday | dasturlarning o'z loglari |

Eski loglar `logrotate` orqali aylantiriladi (`syslog.1`, `syslog.2.gz`): sozlamalari `/etc/logrotate.conf` va `/etc/logrotate.d/`. Siqilganlarini `zcat`/`zgrep` bilan o'qiysiz.

### dmesg

Kernel ring buffer: qurilmalar, drayverlar, fayl tizimi xatolari, OOM killer, segfault'lar. `sudo dmesg -T` vaqtni o'qiladigan ko'rinishda beradi, `sudo dmesg --level=err,warn` faqat muammolar, `sudo dmesg -w` jonli kuzatish. Ubuntu'da oddiy foydalanuvchiga `dmesg` yopiq (`kernel.dmesg_restrict=1`), shuning uchun `sudo`. Buffer hajmi cheklangan, eski xabarlar o'chadi; to'liq tarix `journalctl -k` da.

## 6. Servislar ro'yxati

Qaysi servislar ishlayapti va qaysi biri yiqilgan:

```
$ systemctl list-units --type=service --state=running
$ systemctl --failed
$ systemctl list-unit-files --type=service --state=enabled
$ systemctl status ssh
```

`list-units` hozir xotiraga yuklangan unit'larni, `list-unit-files` diskdagi barcha unit fayllarni va boot'da yoqilishini ko'rsatadi. `status` chiqishida holat, asosiy PID, xotira va oxirgi log qatorlari bor. Unit yozish va boshqarish 11-darsda.

## 7. Sekin serverda birinchi 60 soniya

Tartib umumiydan xususiyga: avval butun tizim, keyin resurs, keyin jarayon. Brendan Gregg (Netflix) ro'yxatiga asoslangan:

| # | Buyruq | Qidiriladigan narsa |
|---|--------|---------------------|
| 1 | `uptime` | load va uning yo'nalishi, `nproc` bilan solishtirish |
| 2 | `sudo dmesg -T \| tail -20` | OOM kill, disk va fayl tizimi xatolari |
| 3 | `vmstat 1 5` | `r` (CPU navbati), `si`/`so` (swap), `wa`, `st` |
| 4 | `mpstat -P ALL 1 3` | bitta yadro to'lib qolganmi |
| 5 | `pidstat 1 3` | qaysi jarayon CPU yeyapti |
| 6 | `iostat -xz 1 3` | `await`, `aqu-sz`, `%util` |
| 7 | `free -h` | `available`, swap |
| 8 | `df -h` va `df -i` | to'lgan fayl tizimi |
| 9 | `systemctl --failed` | yiqilgan servislar |
| 10 | `journalctl -p err --since "30 min ago"` | yaqindagi xatolar |
| 11 | `top` | umumiy tasdiq, saralash bilan |

Har resurs uchun uchta savol (USE metodi): **Utilization** (qancha band), **Saturation** (navbat bormi), **Errors** (xato bormi). Masalan CPU uchun: `us+sy` foizi, `vmstat` dagi `r`, `dmesg` dagi xatolar.

Tarmoq (`ss`, `ip`, `sar -n DEV`) keyingi modulda. Hozircha bilish kerak bo'lgani: sekinlik sababi server ichida bo'lmasligi ham mumkin (DNS, tashqi API, ma'lumotlar bazasi).

## Tuzoqlar

- Load average'ni CPU foizi deb o'qish. U yadrolar soniga nisbatan o'qiladi va I/O kutayotgan task'larni ham sanaydi.
- `free` ustuni kichikligidan vahimaga tushish. `available` ga qarang, page cache band xotira emas.
- Umumiy CPU foiziga qarab bitta to'lib qolgan yadroni o'tkazib yuborish.
- `vmstat`/`iostat` ning birinchi qatorini joriy holat deb o'qish.
- Katta log faylni `rm` bilan o'chirib joy bo'shamaganiga hayron bo'lish: jarayon faylni ochiq ushlab turibdi.
- Disk 100% to'lganda servislar g'alati xatolar bilan yiqiladi (yozib bo'lmaydi, lock fayl yaratilmaydi, ma'lumotlar bazasi to'xtaydi). `df -h` ni birinchilardan tekshiring.
- OOM kill'ni dastur logidan qidirish. Jarayon `SIGKILL` oladi va hech narsa yoza olmaydi, iz faqat kernel logida.
- Faqat `df -h` ga qarab `df -i` ni unutish.
- Production serverda og'ir diagnostika (`du` butun `/` bo'yicha, `find /`) ishga tushirib, I/O muammosini kuchaytirish. `-x` va aniq katalogdan boshlang.
- `st` (steal) ni e'tiborsiz qoldirish: muammo sizning VM'da emas, hypervisor'da bo'lishi mumkin.

## Manbalar

- https://netflixtechblog.com/linux-performance-analysis-in-60-000-milliseconds-accc10403c55 – Linux Performance Analysis in 60,000 Milliseconds (majburiy)
- https://www.brendangregg.com/usemethod.html – USE metodi
- https://www.brendangregg.com/blog/2017-08-08/linux-load-averages.html – Linux load average tarixi va ma'nosi
- https://www.linuxatemyram.com/ – buff/cache nima uchun "band" emas
- https://docs.kernel.org/accounting/psi.html – PSI hujjati
- https://man7.org/linux/man-pages/man1/top.1.html – top(1)
- https://man7.org/linux/man-pages/man8/vmstat.8.html – vmstat(8)
- https://man7.org/linux/man-pages/man1/free.1.html – free(1)
- https://man7.org/linux/man-pages/man1/iostat.1.html – iostat(1)
- https://www.freedesktop.org/software/systemd/man/latest/journalctl.html – journalctl(1)
- Brendan Gregg, "Systems Performance" (2-nashr), 2 va 6–9 boblar

---

## Vazifalar

Ish papkasi: `linux/08-resources/` (`make new m=linux n=08 name=resources` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptlarni yoniga saqlang. Qayerda bajarilishi har vazifada aytilgan; aytilmagan bo'lsa VM'da.

### A. Umumiy holat va CPU

1. **Load vs cores.** Ish mashinasida va VM'da `uptime` va `nproc` ni ishga tushiring. Har ikkisi uchun "load yadrolar soniga nisbatan qancha" ekanini hisoblang. `/proc/loadavg` dagi to'rtinchi maydon (`N/M` shaklidagi) nimani bildirishini `man 5 proc` (yoki `man proc_loadavg`) dan topib yozing.

2. **CPU saturation.** VM'da `stress-ng --cpu 4 --timeout 120s` ni ishga tushiring (VM yadrolaridan ko'p worker). Ikkinchi terminalda `uptime` ni har 20 soniyada, `vmstat 1 10` ni bir marta oling. 1 daqiqalik load qanday o'sdi, `r` ustuni qancha, `us` va `id` qancha? Load nima uchun birdaniga emas, asta ko'tarilishini izohlang.

3. **Single hot core.** VM'da `stress-ng --cpu 1 --timeout 60s` ishga tushiring. `top` ning umumiy `%Cpu(s)` qatorini yozib oling, keyin `1` ni bosing va `mpstat -P ALL 1 3` ni oling. Umumiy raqam nima uchun aldashini va bu Node.js servis uchun nimani anglatishini yozing.

4. **Find the process.** Yuklama ishlab turganida aybdor jarayonni uch usul bilan toping: `top` (saralash tugmasi bilan), `pidstat 1 3`, va `ps` ning `--sort` opsiyasi bilan. Har birining qulayligi qaysi vaziyatda ekanini 2–3 gapda yozing.

5. **First vmstat line.** Tinch VM'da `vmstat 1 5` oling. Birinchi qator bilan qolganlarining farqini ko'rsating va `man vmstat` dan buni tasdiqlovchi jumlani toping.

### B. Xotira

6. **Reading free.** Ish mashinasida `free -h` oling. `total`, `used`, `free`, `buff/cache`, `available` orasidagi bog'lanishni o'z raqamlaringiz bilan tushuntiring. `/proc/meminfo` dan `MemAvailable`, `Cached`, `SwapFree` qatorlarini `grep` bilan chiqarib `free` bilan solishtiring.

7. **Page cache in action.** VM'da `dd if=/dev/zero of=/var/tmp/big.bin bs=1M count=500` bilan fayl yarating. Oldin va keyin `free -m` oling: qaysi ustun o'sdi? Keyin `time cat /var/tmp/big.bin > /dev/null` ni ikki marta ketma-ket bajaring va vaqtlarni solishtiring. Natijani page cache orqali izohlang. Faylni o'chiring.

8. **Memory pressure.** VM'da `stress-ng --vm 1 --vm-bytes 75% --timeout 60s` ishga tushiring. Parallel ravishda `vmstat 1` va `cat /proc/pressure/memory` ni kuzating. `available`, `si`/`so` va PSI qiymatlari qanday o'zgardi?

9. **OOM in a cgroup.** Ish mashinasida `docker run --name oomtest -m 100m ubuntu:24.04 tail /dev/zero` ni ishga tushiring (`tail` xotirani cheksiz yig'adi, limit konteynerni himoya qiladi). Exit code'ni (`echo $?`), `docker inspect oomtest` dagi `OOMKilled` maydonini va `journalctl -k` dagi tegishli kernel qatorlarini toping. Konteynerni o'chiring (`docker rm oomtest`). Kernel xabaridan: qaysi jarayon, qancha xotira bilan o'ldirilgan?

10. **oom_score.** VM'da `sshd` (yoki `systemd-journald`) va o'z shell'ingiz uchun `/proc/<PID>/oom_score` va `oom_score_adj` ni o'qing. Qiymatlar nima uchun farq qiladi? Production'da ma'lumotlar bazasi jarayoniga qanday `oom_score_adj` qo'ygan bo'lardingiz va buning xavfi nimada?

### C. Disk

11. **df vs du.** VM'da `df -hT` va `df -i` oling, `tmpfs` va `loop`/`squashfs` qatorlari nima ekanini izohlang. Keyin `/var` ichidagi eng katta 5 katalogni `du` va `sort` bilan toping.

12. **Deleted but open.** VM'da: `dd if=/dev/zero of=/var/tmp/ghost.log bs=1M count=300`, keyin `tail -f /var/tmp/ghost.log &`, keyin `rm /var/tmp/ghost.log`. `df -h /var/tmp` joy bo'shaganini ko'rsatadimi? `sudo lsof +L1` bilan faylni toping, `tail` ni to'xtating va `df` ni qayta oling. Production'da ishlab turgan servisning log faylini qanday bo'shatish kerakligini yozing.

13. **I/O wait.** VM'da `iostat -xz 1` ni ishga tushirib, ikkinchi terminalda `dd if=/dev/zero of=/var/tmp/io.bin bs=1M count=1500 oflag=direct` bajaring. `w/s`, `wkB/s`, `w_await`, `%util` qanday o'zgardi, `vmstat` da `wa` va `b` nima ko'rsatdi? `pidstat -d 1` bilan yozayotgan jarayonni toping. Faylni o'chiring.

### D. Loglar va servislar

14. **journalctl filters.** VM'da quyidagilarni chiqaring: `ssh` unit'ining oxirgi 20 qatori; joriy boot'dagi `err` va undan og'ir xabarlar; oxirgi 15 daqiqadagi kernel xabarlari. Har biri uchun aniq buyruqni yozing. `journalctl --disk-usage` natijasini ham.

15. **Trace a sudo call.** VM'da `sudo ls /root` bajaring, keyin shu hodisani ikki joydan toping: `/var/log/auth.log` (7-darsdagi `grep` bilan) va `journalctl` orqali. Qatorda qaysi ma'lumotlar bor (kim, qaysi terminal, qaysi katalogdan, qaysi buyruq)?

16. **dmesg.** VM'da `sudo dmesg -T | head -30` va `sudo dmesg --level=err,warn` oling. Boot loglaridan CPU soni, RAM hajmi va root fayl tizimi qaysi qurilmadan mount qilinganini toping. `sudo` siz `dmesg` nima deydi va nima uchun?

17. **Services inventory.** VM'da ishlab turgan servislar ro'yxatini, yiqilgan unit'larni va boot'da yoqiladigan servislar sonini chiqaring. Ro'yxatdan sizga notanish 3 ta servisni tanlab, `systemctl status` va `man` orqali vazifasini bir gapdan yozing.

### E. Yakuniy

18. **60 seconds script.** `task_18.sh` yozing: 7-bo'limdagi tekshiruvlarni ketma-ket bajarib, har biri oldidan sarlavha chop etadigan va natijani `report-$(hostname)-$(date +%F-%H%M).txt` fayliga yozadigan skript. Interaktiv buyruqlarni batch rejimida ishlating, cheksiz ishlaydiganlarga takror sonini bering. `shellcheck` toza bo'lsin.

19. **Blind diagnosis.** VM'da quyidagi uch yuklamadan birini tasodifiy tanlab ishga tushiradigan skript yozing (`task_19.sh`, `$RANDOM` bilan): CPU yuklamasi, xotira bosimi, `/var/tmp` ga katta fayl yozish. Skriptni ishga tushirib, qaysi biri tanlanganiga qaramasdan, 18-vazifadagi hisobot va qo'shimcha buyruqlar yordamida sababni aniqlang. README'ga tashxis yo'lini yozing: qaysi raqam qaysi xulosaga olib keldi.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi (`shellcheck` skriptlar uchun).
2. VM'da `stress-ng` jarayonlari va `/var/tmp` dagi katta fayllar qolmagan, `oomtest` konteyneri o'chirilgan.
3. README'da har vazifa uchun buyruq, natija va izoh bor.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- 2 yadroli serverda load average `6.0, 5.5, 5.0`, CPU `id` 90%. Bu qanday bo'lishi mumkin va keyingi qadamingiz nima?
- `free` dagi `free` va `available` farqi nima, qaysi biriga qarab qaror qilinadi?
- `wa` va `st` nimani bildiradi, har biri baland bo'lsa aybdorni qayerdan qidirasiz?
- `df` 100% deydi, `du` esa atigi 40% ni topdi. Ikki mumkin bo'lgan sababni ayting.
- OOM killer ishlaganini qanday bilasiz va nima uchun dastur logida izi yo'q?
- `vmstat 1` ning birinchi qatoriga nima uchun ishonib bo'lmaydi?
- `journalctl -p err -b` aynan nimani chiqaradi?
- USE metodining uch savoli nima, disk uchun har biriga qaysi buyruq javob beradi?
