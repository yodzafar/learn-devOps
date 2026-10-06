# 8-dars: Server resurslarini ko'rish

Maqsad: "server sekin ishlayapti" degan shikoyatga tizimli javob berishni noldan o'rganish. Server to'rtta asosiy resursga ega: CPU (protsessor vaqti), xotira (RAM), disk va tarmoq. Bu darsda birinchi uchtasi va ikki ma'lumot manbai (loglar, servislar holati) bo'yicha qaysi buyruq nimani ko'rsatishini, raqamlarni qanday o'qishni va qaysi raqam aldashini o'rganasiz. Frontend ishida brauzerning DevTools'idagi Performance va Memory tablari shu vazifani bajaradi; serverda DevTools yo'q, uning o'rnida `uptime`, `top`, `vmstat`, `free`, `df`, `iostat`, `journalctl` bor. 7-darsdagi `grep`, `awk` va pipe bu yerda chiqishlarni filtrlash uchun ishlatiladi. Keyingi darslar shu yerda ko'rilgan narsalarni chuqurlashtiradi: 9-dars jarayonlar va signallar, 11-dars systemd va journal, 13-dars disk.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A, B guruh vazifalari, ikkinchi kun 4–6 bo'limlar va C, D guruhlari, uchinchi kun 7-bo'lim, "Birga bajaramiz", E guruhi va README'ni tartibga solish. Buyruqlarni yodlash emas, talqin muhim. Diqqatni quyidagilarga qarating: load average CPU foizi emasligi, `free` dagi `available` ustuni, `wa` va `st` nimani bildirishi, `df` va `du` nima uchun har xil raqam berishi, OOM killer izini logdan topish.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi raqamlar (load, megabaytlar, PID) farq qiladi, bu normal; darsda bunday joylar `<N>`, `<PID>`, `<sana>` bilan belgilangan. Ikkita terminal oynasi kerak bo'ladi: birida yuklama ishlaydi, ikkinchisida kuzatasiz. Ikkinchi oynada ham `multipass shell lab` deb kirasiz.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` virtual mashinasi kerak (Multipass, Ubuntu 24.04, 2 CPU, 2G RAM, 10G disk). Darsdagi barcha Linux buyruqlari shu VM ichida bajariladi, host'ga bog'liq vazifa yo'q.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | `make`, `git`, `multipass`, 9-vazifadagi `docker` |
| `lab` VM, 1-oyna | `ubuntu@lab:~$` | yuklama yaratish (`stress-ng`, `dd`) |
| `lab` VM, 2-oyna | `ubuntu@lab:~$` | kuzatish (`top`, `vmstat`, `iostat`) |

- **Paketlar** (VM ichida, bir marta). `sysstat` paketi `mpstat`, `iostat`, `pidstat`, `sar` ni beradi; `stress-ng` sun'iy yuklama yaratadi; `htop` `top` ning qulay varianti. Uchalasi ham `amd64` va `arm64` uchun Ubuntu arxivida bor:

```
ubuntu@lab:~$ sudo apt update && sudo apt install -y sysstat htop stress-ng
```

- **Yuklama faqat VM'da.** CPU, xotira va diskni to'ldiradigan vazifalar ish kompyuteringizga ta'sir qilmasligi uchun VM ichida bajariladi. VM 2 yadro va 2G xotira bilan cheklangan, shuning uchun yuklama undan tashqariga chiqmaydi.
- **Konteyner** (faqat 9-vazifa): host'da `docker run -m 100m ubuntu:24.04 ...`. `-m 100m` konteynerga 100 MiB xotira limiti qo'yadi, limit kernel'ning cgroup mexanizmi orqali ishlaydi va host'ga ta'sir qilmaydi. `ubuntu:24.04` image'i ikkala arxitektura uchun chiqadi.
- **Tozalash**: yaratilgan katta fayllarni o'chiring (`rm /var/tmp/*.bin`), `pgrep stress-ng` hech narsa chiqarmasligini tekshiring, `docker rm oomtest`.
- **Oldingi holat**: bu dars oldingi darslardan qolgan holatga tayanmaydi. Mashinani almashtirsangiz, ikkinchi mashinadagi `lab` VM'da faqat yuqoridagi `apt install` ni qayta bajaring. Javoblar git orqali ko'chadi.
- VM buzilsa: `multipass stop lab && multipass restore lab.clean && multipass start lab` (SETUP.md), keyin paketlarni qayta o'rnating.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `x86_64`. Host ham Linux, shuning uchun `uptime`, `free -h`, `nproc` ni host'da ham ixtiyoriy sinab, VM bilan solishtirish mumkin. Docker to'g'ridan-to'g'ri host kernel'ida ishlaydi: 9-vazifadagi OOM xabari host'ning `journalctl -k` chiqishida ko'rinadi. |
| macOS (uy) | VM `aarch64`. Host Linux emas: `free`, `nproc`, `vmstat` (Linux varianti), `iostat -x`, `journalctl`, `/proc` yo'q; `uptime` va `df -h` bor, lekin BSD varianti. Hamma vazifa VM'da bajariladi. Docker yashirin Linux VM ichida ishlaydi, shuning uchun 9-vazifada konteynerning OOM xabari Mac'da ko'rinmaydi; kernel xabarini `lab` VM'da `systemd-run` bilan olasiz (3-bo'lim). VM ichida `iostat` qurilma nomlari va `/proc/cpuinfo` maydonlari farq qilishi mumkin, ustunlar bir xil. |

---

## 1. Umumiy holat: uptime va load average

### Bu nima

Serverga kirganda birinchi savol: "hozir bu mashina bandmi?". Eng arzon javob `uptime`: bitta qator, hech narsa o'rnatish kerak emas.

```
ubuntu@lab:~$ uptime
 <vaqt> up  4:40,  1 user,  load average: 0.08, 0.03, 0.01
ubuntu@lab:~$ nproc
2
ubuntu@lab:~$ cat /proc/loadavg
0.08 0.03 0.01 1/<N> <PID>
```

Qatorni chapdan o'qiymiz: `<vaqt>` hozirgi soat; `up 4:40` mashina 4 soat 40 daqiqadan beri o'chmagan; `1 user` nechta login sessiya bor; `load average` dan keyingi uchta son oxirgi 1, 5 va 15 daqiqa uchun o'rtacha load. `nproc` kernel ko'rayotgan CPU yadrolari soni, VM `--cpus 2` bilan yaratilgani uchun `2`. `/proc/loadavg` o'sha uch sonning manbai (`uptime` shu faylni o'qiydi); to'rtinchi va beshinchi maydonlarni 1-vazifada o'zingiz ochasiz.

### Mexanizm: load nimani sanaydi

Kernel har jarayonni (aniqrog'i har **task**'ni, ya'ni jarayon yoki thread'ni) holat bilan belgilaydi. Bu darsda ikkitasi muhim:

| Holat | Nomi | Ma'nosi |
|-------|------|---------|
| `R` | running/runnable | CPU'da ishlayapti yoki CPU navbatida turibdi |
| `D` | uninterruptible sleep | uzilmas kutish, odatda disk I/O javobini kutyapti |
| `S` | sleeping | biror hodisani kutib uxlayapti (tarmoq, timer); load'ga kirmaydi |

**Load** bu ma'lum paytda `R` va `D` holatidagi task'lar soni. **Load average** shu sonning vaqt bo'yicha silliqlangan (eksponensial) o'rtachasi: kernel har 5 soniyada joriy sonni o'lchab, eski o'rtachaga oz-ozdan qo'shadi. Shuning uchun yuklama boshlanganda 1 daqiqalik son birdaniga emas, asta ko'tariladi va yuklama tugagach asta tushadi.

Ikki xulosa:

- **Load CPU foizi emas.** U yadrolar soniga nisbatan o'qiladi. 2 yadroli VM'da load `2.0` "ikkala yadro band, navbat yo'q" degani; `4.0` "har ishlayotgan task'ga bitta kutayotgan task to'g'ri keladi"; `0.5` "mashina deyarli bo'sh". 32 yadroli serverda load `8.0` esa xotirjam holat.
- **Load baland, CPU bo'sh bo'lishi mumkin.** Sekin diskni kutayotgan jarayonlar `D` holatida turadi va loadni oshiradi, CPU esa bekor. Load faqat "nimadir kutilyapti" deydi, nima ekanini keyingi bo'limlardagi asboblar ko'rsatadi.

Uch sonning nisbati yo'nalishni beradi: `8.0, 3.0, 1.0` muammo hozir boshlangan va o'syapti; `1.0, 3.0, 8.0` muammo o'tib ketyapti.

Node tajribasiga bog'lash: Node.js event loop bitta thread'da ishlaydi. Og'ir sinxron hisob-kitob qilayotgan bitta Node jarayoni load'ga ko'pi bilan `1.0` qo'shadi, nechta yadro bo'lishidan qat'i nazar. `cluster` yoki bir nechta `pm2` instansi bo'lsa, har biri alohida task.

### PSI (pressure stall information)

Load ikki xil kutishni (CPU va I/O) bitta songa qo'shib yuboradi. Zamonaviy kernel aniqroq o'lchov beradi: har resurs uchun alohida fayl.

```
ubuntu@lab:~$ cat /proc/pressure/cpu
some avg10=0.00 avg60=0.00 avg300=0.00 total=<N>
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
ubuntu@lab:~$ cat /proc/pressure/memory
some avg10=0.00 avg60=0.00 avg300=0.00 total=<N>
full avg10=0.00 avg60=0.00 avg300=0.00 total=<N>
```

`some` qatori: kamida bitta task shu resursni kutib to'xtab turgan vaqt ulushi. `full` qatori: hamma ishlamoqchi bo'lgan task'lar bir vaqtda to'xtab turgan vaqt ulushi (tizim shu resurs tufayli umuman oldinga siljimagan). `avg10`, `avg60`, `avg300` oxirgi 10, 60 va 300 soniya uchun foiz: `some avg10=12.50` degani oxirgi 10 soniyaning 12.5 foizida kimdir kutgan. `total` boot'dan beri jami kutish vaqti, mikrosoniyada. Uchinchi fayl `/proc/pressure/io` disk uchun.

### Real ishda qachon kerak

- Serverga SSH bilan kirgandan keyingi birinchi buyruq: `uptime`. Uch son va `nproc` muammo bormi, o'syaptimi, shuni aytadi.
- Monitoring alert'lari ko'pincha "load > yadrolar soni x 2, 5 daqiqa davomida" shaklida yoziladi.
- Kubernetes va systemd xotira bosimini PSI orqali o'lchaydi; "nima uchun pod sekin" savolida PSI load'dan aniqroq.

### Nima uchun shunday

Load average 1970-yillardagi Unix'dan qolgan: o'shanda u faqat CPU navbatini sanardi. Linux 1993-yilda `D` holatini ham qo'shdi, chunki sekin disk ham "tizim band" degani, CPU bo'sh bo'lsa ham. Natijada son foydali, lekin ikki ma'noli bo'lib qoldi (Brendan Gregg maqolasi, Manbalar). PSI 2018-yilda (kernel 4.20) aynan shu ikki ma'nolikni yechish uchun qo'shildi: resurs bo'yicha ajratilgan va foizda. Load baribir yo'qolmaydi: u har Unix'da bor, bitta qatorda ko'rinadi va yo'nalishni ko'rsatadi.

## 2. CPU

### top: jonli jadval

`top` har 3 soniyada yangilanadigan ekran. Chiqish `q` bilan. Skript yoki README uchun bir marta olish: `-b` (batch, ekransiz) va `-n 1` (bir marta).

```
ubuntu@lab:~$ top -b -n 1 | head -8
top - <vaqt> up  4:41,  1 user,  load average: 0.05, 0.03, 0.01
Tasks: <N> total,   1 running, <N> sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  3.1 sy,  0.0 ni, 96.9 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   <N> total,   <N> free,   <N> used,   <N> buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   <N> avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
      1 root      20   0   <N>   <N>   <N> S   0.0   0.6   <vaqt> systemd
```

Birinchi qator `uptime` bilan bir xil. Ikkinchi qator task'lar soni holat bo'yicha (`zombie` 9-darsda). Uchinchi qator CPU vaqti qayerga ketgani, foizda, hamma yadro bo'yicha o'rtacha:

| Maydon | Ma'nosi | Baland bo'lsa |
|--------|---------|---------------|
| `us` | user space kodi | dastur hisob-kitob qilyapti |
| `sy` | kernel kodi (syscall'lar) | ko'p I/O, ko'p context switch, ko'p yangi jarayon |
| `ni` | nice qiymati musbat (past prioritetli) jarayonlar | fon ishlari |
| `id` | bo'sh | |
| `wa` | CPU bo'sh, lekin I/O kutilyapti | disk sekin yoki to'yingan |
| `hi`, `si` | hardware va software interrupt'lar | tarmoq yuklamasi katta |
| `st` | steal: hypervisor boshqa VM'ga bergan vaqt | cloud'da "shovqinli qo'shni" yoki burstable instansda CPU krediti tugagan |

**Hypervisor** bu bitta jismoniy mashinada bir nechta VM'ni ishlatadigan dastur; sizning `lab` VM'ingiz ham hypervisor ustida turibdi. `st` sizning VM ishlamoqchi bo'lgan, lekin hypervisor CPU'ni bermagan vaqt.

To'rtinchi va beshinchi qatorlar xotira (3-bo'lim). Jadval ustunlari: `PR` va `NI` prioritet (9-darsda); `VIRT` jarayon band qilgan virtual manzil maydoni (deyarli foydasiz raqam, Node jarayonida gigabaytlab bo'ladi); `RES` haqiqatda RAM'da turgan qismi, asosiy raqam shu; `SHR` boshqa jarayonlar bilan bo'lishilgan qismi; `S` holat (`R`, `S`, `D`); `%CPU` bitta yadroga nisbatan, shuning uchun ko'p thread'li jarayon 2 yadroda 200% gacha ko'rsatadi; `TIME+` jarayon jami ishlatgan CPU vaqti.

Interaktiv rejimdagi foydali tugmalar: `1` har yadroni alohida ko'rsatadi, `P` CPU bo'yicha, `M` xotira bo'yicha saralaydi, `c` to'liq buyruq satri, `k` signal yuborish, `q` chiqish.

**Tuzoq: bitta yadro 100%, umumiy CPU 12%.** 8 yadroli mashinada bitta thread'li jarayon (masalan Node.js event loop) bir yadroni to'liq band qilsa, umumiy qator 12.5% ko'rsatadi va "CPU bo'sh" deb o'ylaysiz, servis esa so'rovlarga ulgurmayapti. `top` da `1` ni bosing yoki `mpstat -P ALL` ishlating.

### vmstat: butun tizim bitta qatorda

```
ubuntu@lab:~$ vmstat 1 3
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 0  0      0 <N> <N> <N>    0    0    <N>    <N>  <N>  <N>  1  1 98  0  0  0
 0  0      0 <N> <N> <N>    0    0     0     0   <N>  <N>  0  0 100  0  0  0
 0  0      0 <N> <N> <N>    0    0     0     0   <N>  <N>  0  0 100  0  0  0
```

`vmstat 1 3` degani: 1 soniya oraliq bilan 3 marta o'lcha. Ustunlar:

| Ustun | Ma'nosi |
|-------|---------|
| `r` | CPU'da ishlayotgan va navbatdagi task'lar. Doimiy ravishda `nproc` dan katta bo'lsa CPU yetishmayapti |
| `b` | I/O kutib bloklangan (`D` holatidagi) task'lar |
| `swpd`, `free`, `buff`, `cache` | xotira, KiB'da (3-bo'lim) |
| `si`, `so` | swap'dan o'qish va swap'ga yozish, KiB/s. Doimiy noldan katta bo'lsa xotira yetishmayapti |
| `bi`, `bo` | block device'dan (diskdan) o'qilgan va unga yozilgan bloklar |
| `in`, `cs` | soniyadagi interrupt va context switch'lar |
| `us sy id wa st` | `top` dagi bilan bir xil foizlar |
| `gu` | VM mehmonlarini ishlatishga ketgan vaqt (faqat hypervisor host'ida noldan farq qiladi) |

**Context switch** bu kernel CPU'ni bir task'dan olib boshqasiga berishi; har biri oz vaqt oladi, soniyasiga o'n minglab bo'lsa `sy` ko'tariladi.

**Tuzoq: birinchi qator.** `vmstat`, `iostat`, `mpstat` oraliq bilan chaqirilganda birinchi qator boot'dan beri o'rtachani ko'rsatadi, hozirgi holatni emas. Yuqoridagi misolda birinchi qatordagi `us 1 sy 1` 4 soatlik o'rtacha. Har doim ikkinchi qatordan boshlab o'qing.

### mpstat va pidstat: qaysi yadro, qaysi jarayon

```
ubuntu@lab:~$ mpstat -P ALL 1 1
Linux 6.8.0-<NN>-generic (lab) 	<sana> 	_x86_64_	(2 CPU)

<vaqt>  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
<vaqt>  all    0.00    0.00    0.50    0.00    0.00    0.00    0.00    0.00    0.00   99.50
<vaqt>    0    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00  100.00
<vaqt>    1    0.00    0.00    1.00    0.00    0.00    0.00    0.00    0.00    0.00   99.00
```

Sarlavha qatorida kernel, hostname, arxitektura (Mac'dagi VM'da `_aarch64_`) va CPU soni. `all` qatori o'rtacha, `0` va `1` har yadro alohida. Bitta yadroda `%usr` 100 ga yaqin, `all` da 50 bo'lsa, bu yuqoridagi tuzoqning aynan o'zi.

```
ubuntu@lab:~$ pidstat 1 1
<vaqt>   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
<vaqt>  1000    <PID>    0.00    1.00    0.00    0.00    1.00     1  pidstat
```

`pidstat` shu oraliqda CPU ishlatgan jarayonlarni ko'rsatadi: `UID` egasi (1000 bu `ubuntu`), `%usr` va `%system` jarayonning user va kernel vaqti, `%wait` jarayon CPU navbatida kutgan vaqt (baland bo'lsa CPU yetishmayapti), `CPU` oxirgi ishlagan yadro raqami. `pidstat -d 1` disk I/O bo'yicha, `pidstat -r 1` xotira bo'yicha shu jadvalni beradi. `top` dan farqi: chiqish ekranni tozalamaydi, vaqt o'qi bilan pastga qarab yoziladi, uni faylga saqlab keyin o'qish mumkin.

`htop` esa `top` ning rangli varianti: har yadro uchun alohida chiziq, daraxt ko'rinishi (`F5`), qidiruv (`F3`), filtr (`F4`). U odatda o'rnatilmagan bo'ladi, shuning uchun begona serverda `top` ni bilish shart.

### Real ishda qachon kerak

- "API sekin javob beryapti": `top` da jarayonning `%CPU` si 100% atrofida turgan bo'lsa va u Node bo'lsa, event loop band; yechim kodda yoki instanslar sonida.
- `sy` baland: dastur juda ko'p mayda syscall qilyapti yoki juda ko'p jarayon tug'ilyapti (masalan har so'rovga yangi jarayon ochadigan skript).
- `st` baland: muammo sizning kodingizda emas, cloud provayderning host'ida yoki instans turida (`t3` kabi burstable instanslar kreditsiz qolganda).

### Nima uchun shunday

Bitta `top` yetmasligining sababi: har asbob bitta savolga javob beradi. `top` "hozir kim", `vmstat` "tizim bo'yicha vaqt o'qi", `mpstat` "qaysi yadro", `pidstat` "qaysi jarayon, vaqt o'qi bilan". Hammasi bitta manbadan o'qiydi: `/proc/stat` (CPU hisoblagichlari) va `/proc/<PID>/stat`. Kernel foiz saqlamaydi, u boot'dan beri har holatda o'tgan vaqtni sanaydi; asbob ikki marta o'qib, farqni oraliqqa bo'ladi. Birinchi qator tuzog'i shundan: birinchi o'lchovda "oldingi" qiymat yo'q, shuning uchun boot'dan beri o'rtacha chiqadi.

## 3. Xotira

### free

```
ubuntu@lab:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           1.9Gi       <N>Mi       <N>Gi       <N>Mi       <N>Mi       <N>Gi
Swap:             0B          0B          0B
```

`-h` raqamlarni odam o'qiydigan birlikda beradi (`-m` mebibaytda). `total` VM'ga berilgan RAM (2G so'ralgan, kernel o'ziga ozginasini olgani uchun 1.9Gi); `used` dasturlar band qilgan; `free` umuman ishlatilmayotgan; `shared` asosan `tmpfs` (xotiradagi fayl tizimlari, masalan `/run`); `buff/cache` kernel keshi; `available` yangi dastur uchun haqiqatda mavjud xotira. `Swap` qatori `0B`: Multipass VM'da swap odatda yo'q.

### Mexanizm: page cache va available

Kernel bo'sh RAM'ni behuda turg'izmaydi. Diskdan o'qilgan va diskka yozilgan fayl ma'lumotlarini xotirada saqlab qoladi: bu **page cache**. Shu faylni keyingi safar o'qish diskka bormaydi, xotiradan olinadi. `buff/cache` ustuni shu kesh (va fayl tizimi metama'lumotlari uchun buferlar). Dasturga xotira kerak bo'lsa kernel keshning toza (diskda nusxasi bor) qismini darhol bo'shatadi.

Shuning uchun uzoq ishlagan serverda `free` ustuni kichik bo'lishi normal holat: bo'sh xotira isrof qilingan xotira. To'g'ri savol "yangi dastur uchun qancha xotira bor" va unga `available` javob beradi: bo'sh xotira va tez bo'shatsa bo'ladigan kesh yig'indisi bo'yicha kernel bahosi. Manbai `/proc/meminfo`:

```
ubuntu@lab:~$ grep -E '^(MemTotal|MemFree|MemAvailable|Cached|SwapTotal)' /proc/meminfo
MemTotal:        <N> kB
MemFree:         <N> kB
MemAvailable:    <N> kB
Cached:          <N> kB
SwapTotal:             0 kB
```

`free` shu faylni o'qib formatlaydi: `MemTotal` bu `total`, `MemFree` bu `free`, `MemAvailable` bu `available`. Birlik `kB` deb yozilgan, aslida kibibayt (1024 bayt).

Frontend tajribasiga bog'lash: brauzerning HTTP keshi diskni to'ldiradi, lekin joy kerak bo'lsa brauzer uni o'zi tozalaydi va siz "disk to'ldi" deb xavotirlanmaysiz. Page cache RAM uchun xuddi shu rolni o'ynaydi.

Xotira haqiqatan tugayotganining belgilari: `available` `total` ning bir necha foiziga tushgan; `vmstat` da `si`/`so` doimiy noldan katta; `/proc/pressure/memory` da `some` o'sgan.

### Swap

**Swap** bu diskdagi maydon: xotira yetmaganda kernel uzoq ishlatilmagan xotira sahifalarini u yerga chiqarib qo'yadi va kerak bo'lganda qaytarib o'qiydi. Swap'da ma'lumot borligi o'zi muammo emas. Muammo **faol** almashinuv (`si`/`so` doimiy noldan katta), chunki disk RAM'dan minglab marta sekin va tizim "qotib" qoladi. Swap yo'q tizimda (sizning VM kabi) xotira tugasa kernel darhol keyingi mexanizmga o'tadi. Swap yaratish 13-darsda.

### OOM killer

Xotira (va swap) tugab, kernel hech narsani bo'shata olmasa, **OOM killer** (Out-Of-Memory killer) bitta jarayonni tanlab unga `SIGKILL` yuboradi. `SIGKILL` bu jarayon ushlay olmaydigan, darhol o'ldiradigan signal (9-darsda). Tanlov `/proc/<PID>/oom_score` bo'yicha: son qancha katta bo'lsa, jarayon shuncha "birinchi nomzod" (asosan xotira iste'moliga bog'liq). `/proc/<PID>/oom_score_adj` (-1000 dan 1000 gacha) bilan tuzatiladi: -1000 jarayonni butunlay himoya qiladi.

```
ubuntu@lab:~$ cat /proc/$$/oom_score /proc/$$/oom_score_adj
<N>
0
```

`$$` joriy shell'ning PID'i (1-dars). Birinchi son hisoblangan ball, ikkinchisi tuzatish (oddiy jarayonlarda `0`).

Jarayon uchun bu ogohlantirishsiz o'lim: `process.on('exit')` ham, `try/catch` ham ishlamaydi, dasturning o'z logida hech narsa qolmaydi. Iz faqat kernel logida.

### Misol: cgroup limiti va OOM

**cgroup** (control group) bu kernel mexanizmi: jarayonlar guruhiga resurs limiti qo'yadi. Docker'ning `-m` flagi ham, systemd servislarining `MemoryMax=` sozlamasi ham shu orqali ishlaydi. Guruh limitdan oshsa, OOM killer shu guruh ichidan jarayon o'ldiradi, garchi mashinada RAM bo'sh bo'lsa ham. Buni VM'da `systemd-run` bilan ko'ramiz: u buyruqni vaqtinchalik cgroup ichida ishga tushiradi. Yuklama sifatida `head -c 300M /dev/zero | tail` olamiz: `tail` qator oxirini kutib 300 MiB nolni xotirasiga yig'adi.

```
ubuntu@lab:~$ sudo systemd-run --scope -p MemoryMax=50M -p MemorySwapMax=0 sh -c 'head -c 300M /dev/zero | tail'
Running as unit: run-<id>.scope; invocation ID: <id>
Killed
ubuntu@lab:~$ echo $?
137
ubuntu@lab:~$ journalctl -k --since "2 min ago" | grep -i -E 'oom|killed process'
<sana> lab kernel: tail invoked oom-killer: gfp_mask=<...>, order=0, oom_score_adj=0
<sana> lab kernel: Memory cgroup out of memory: Killed process <PID> (tail) total-vm:<N>kB, anon-rss:<N>kB, file-rss:<N>kB, shmem-rss:0kB, UID:0 pgtables:<N>kB oom_score_adj:0
```

`--scope` buyruqni joriy terminalda, lekin alohida cgroup'da ishlatadi; `-p MemoryMax=50M` limit; `-p MemorySwapMax=0` swap'ga qochishni taqiqlaydi. `Killed` ni shell yozdi: bola jarayon signal bilan o'ldi. Exit code `137` bu 128 + 9, ya'ni "9-signal (`SIGKILL`) bilan o'ldirilgan" (9-darsda). Kernel logidagi birinchi qator: xotira so'rab OOM killer'ni uyg'otgan jarayon `tail`. Ikkinchi qator: `Memory cgroup out of memory` (butun tizim emas, cgroup limiti), o'ldirilgan jarayon PID va nomi, `total-vm` uning virtual xotirasi, `anon-rss` haqiqatda RAM'da turgan qismi (limitga yaqin son). Butun tizim xotirasi tugaganda xabar `Out of memory: Killed process ...` bo'ladi, `Memory cgroup` so'zisiz.

Docker'da xuddi shu hodisa: exit code 137 va `docker inspect` dagi `OOMKilled: true`. Zorin'da konteynerning OOM xabari host kernel logiga tushadi. Mac'da konteyner Docker'ning yashirin Linux VM'ida ishlaydi va xabar o'sha VM kernel'ida qoladi, shuning uchun Mac'da kernel xabarini yuqoridagi `systemd-run` usuli bilan `lab` VM'da ko'rasiz.

### Real ishda qachon kerak

- Servis "o'z-o'zidan" qayta ishga tushyapti, logida xato yo'q: birinchi gumon OOM kill. `journalctl -k | grep -i 'killed process'`.
- Kubernetes'da pod holati `OOMKilled`: konteyner o'z `limits.memory` sidan oshgan. Node'da bu ko'pincha `--max-old-space-size` limitdan katta qo'yilganini bildiradi.
- "Server xotirasi 95% band" degan alert: avval `available` ga qarang, ehtimol bu shunchaki page cache.

### Nima uchun shunday

Linux xotirani "optimistik" beradi (overcommit): dastur 1 GiB so'rasa, kernel "xo'p" deydi, lekin haqiqiy sahifalarni faqat dastur ularga yozganda ajratadi. Ko'p dasturlar so'raganidan kam ishlatadi, shuning uchun bu tejamkor. Narxi: hamma bir vaqtda va'da qilingan xotirani talab qilsa, kernel bera olmaydi va qaytarib oladigan yo'l qolmaydi, kimnidir o'ldirish kerak. Muqobili (overcommit'ni o'chirish, `vm.overcommit_memory=2`) mavjud, lekin unda dasturlar xotira bor bo'lsa ham rad javobi oladi. Page cache esa "bo'sh RAM foyda bermaydi" g'oyasidan: disk sekin, xotira tez, bo'sh turgan xotirani kesh qilish tekin tezlik.

## 4. Disk

Diskda ikki alohida savol bor: **joy** (qancha to'lgan) va **tezlik** (so'rovlar qancha kutyapti).

### Joy: df

```
ubuntu@lab:~$ df -hT
Filesystem     Type      Size  Used Avail Use% Mounted on
tmpfs          tmpfs     <N>M  <N>M  <N>M   1% /run
/dev/sda1      ext4      9.6G  <N>G  <N>G  <N>% /
tmpfs          tmpfs     <N>M     0  <N>M   0% /dev/shm
/dev/sda16     ext4      <N>M  <N>M  <N>M  <N>% /boot
/dev/sda15     vfat      <N>M  <N>M  <N>M   6% /boot/efi
...
```

`df` (disk free) har **fayl tizimi** bo'yicha bitta qator beradi. `-h` odam o'qiydigan birlik, `-T` tip ustunini qo'shadi. Ustunlar: `Filesystem` manba qurilma (sizda nomlar farq qilishi mumkin, masalan `/dev/vda1`); `Type` fayl tizimi turi; `Size`, `Used`, `Avail` hajm, band, bo'sh; `Use%` to'lganlik; `Mounted on` daraxtning qaysi papkasiga ulangan (1-dars, mount). Muhim qator `/`: VM'ning 10G diski. `tmpfs` qatorlari real disk emas, ular xotirada yashaydi. Snap paketlari o'rnatilgan tizimda `squashfs` tipidagi `/dev/loop<N>` qatorlari ham chiqadi: bular snap paketlarining faqat o'qiladigan image'lari, har doim 100% to'la va bu normal.

`df -i` xuddi shu jadvalni **inode**'lar bo'yicha beradi. Inode bu fayl haqidagi yozuv (6-dars); ularning soni fayl tizimi yaratilganda belgilanadi. Millionlab mayda fayl (sessiya fayllari, kesh) inode'larni tugatsa, joy bor bo'lsa ham `No space left on device` chiqadi.

### Joy: du

`df` "qaysi fayl tizimi to'la" deydi, `du` (disk usage) "uning ichida nima joy egallayapti" ni topadi:

```
ubuntu@lab:~$ sudo du -xh --max-depth=1 /usr | sort -h | tail -4
<N>M	/usr/bin
<N>M	/usr/share
<N>M	/usr/lib
<N>G	/usr
```

`-x` boshqa fayl tizimlariga o'tmaydi; `-h` odam o'qiydigan birlik; `--max-depth=1` faqat birinchi darajadagi papkalar yig'indisi; `sort -h` `K`/`M`/`G` qo'shimchalarini tushunib saralaydi; `tail -4` eng kattalari. Oxirgi qator papkaning o'zi (jami). Eng katta papkani topgach, shu buyruqni uning ichida takrorlaysiz va shunday chuqurlashasiz. `sudo` kerak, chunki `du` o'qiy olmagan papkalarni sanamaydi. `du -sh <papka>` bitta jami raqam beradi.

Node tajribasiga bog'lash: `du -sh node_modules` ni ishlatgansiz. Bu o'sha buyruq, faqat endi `/var` uchun.

**Tuzoq: `df` to'la deydi, `du` joy topolmaydi.** Fayl o'chirilgan, lekin uni ochib turgan jarayon hali ishlayapti: nom katalogdan yo'qolgan, bloklar esa jarayon faylni yopmaguncha band (6-darsdagi inode va link tushunchasi: fayl oxirgi nom **va** oxirgi ochiq deskriptor yo'qolganda o'chadi). `du` nomlar bo'yicha yuradi va faylni ko'rmaydi, `df` bloklarni sanaydi va ko'radi. Bunday fayllarni `sudo lsof +L1` ko'rsatadi (`lsof` ochiq fayllar ro'yxati, `+L1` link soni 1 dan kam, ya'ni o'chirilganlar). Yechim: jarayonni qayta ishga tushirish, yoki log faylni o'chirish o'rniga bo'shatish (`truncate -s 0 app.log`).

### Tezlik: iostat

```
ubuntu@lab:~$ iostat -xz 1 2
...
Device            r/s     rkB/s   ...  r_await  ...     w/s     wkB/s   ...  w_await  ...  aqu-sz  %util
sda              0.00      0.00   ...     0.00  ...    <N>      <N>   ...     <N>  ...    0.00   <N>
```

`-x` kengaytirilgan ustunlar, `-z` faoliyatsiz qurilmalarni yashiradi, `1 2` bir soniya oraliq bilan ikki marta (birinchi hisobot boot'dan beri o'rtacha, ikkinchisini o'qing). Ustunlar ko'p, muhimlari:

| Ustun | Ma'nosi |
|-------|---------|
| `r/s`, `w/s` | soniyadagi o'qish va yozish so'rovlari (IOPS) |
| `rkB/s`, `wkB/s` | o'tkazuvchanlik, kB/s |
| `r_await`, `w_await` | so'rovning o'rtacha kutish vaqti, ms (navbat va bajarilish birga). Asosiy ko'rsatkich |
| `aqu-sz` | o'rtacha navbat uzunligi |
| `%util` | qurilma band bo'lgan vaqt ulushi |

`%util` 100% ga yaqinligi eski aylanuvchi disk uchun to'yinishni bildiradi. SSD, NVMe va cloud volume'lar so'rovlarni parallel bajargani uchun ularda bu raqam kam narsa aytadi: `await` va `aqu-sz` ga qarang. Qaysi jarayon yozayotganini `pidstat -d 1` ko'rsatadi.

### Real ishda qachon kerak

- Disk 100% to'lganda servislar g'alati xatolar bilan yiqiladi: log yozib bo'lmaydi, lock fayl yaratilmaydi, ma'lumotlar bazasi to'xtaydi. `df -h` ni birinchilardan tekshiring.
- Aybdor deyarli har doim `/var`: loglar, Docker image'lari (`/var/lib/docker`), paket keshi.
- "Deploy paytida sayt sekinlashadi": `iostat` da `w_await` sakrasa, deploy diskni band qilyapti (image tortish, `npm ci`).

### Nima uchun shunday

`df` va `du` ikki xil manbadan o'qiydi va shuning uchun bir-birini tekshiradi: `df` fayl tizimining o'z hisobidan (superblock: jami va bo'sh bloklar) so'raydi, bir zumda javob beradi; `du` papkalarni aylanib har faylni sanaydi, sekin, lekin "qayerda" ni aytadi. O'chirilgan-lekin-ochiq fayl Unix dizaynining natijasi: nom va ma'lumot ajratilgan, shuning uchun ishlab turgan dastur ostidan faylni o'chirish uni buzmaydi (paket yangilash aynan shunga tayanadi), narxi esa ko'rinmas band joy.

## 5. Loglar

Raqamlar "nima" ni aytadi, loglar "nima uchun" ni. Linux'da uch manba bor: journal, `/var/log` dagi matn fayllar va kernel buferi.

### journalctl

systemd tizimlarida kernel xabarlari, servislar va ularning stdout/stderr chiqishi **journal** ga tushadi (1-dars). U binar formatda saqlanadi, `journalctl` bilan o'qiladi. Har yozuvda vaqt, hostname, manba va xabardan tashqari yashirin maydonlar (unit nomi, PID, prioritet) bor, filtrlar shularga tayanadi.

```
ubuntu@lab:~$ journalctl -u ssh -n 3 --no-pager
<sana> lab systemd[1]: Starting ssh.service - OpenBSD Secure Shell server...
<sana> lab sshd[<PID>]: Server listening on 0.0.0.0 port 22.
<sana> lab systemd[1]: Started ssh.service - OpenBSD Secure Shell server.
```

`-u ssh` faqat `ssh.service` unit'iga tegishli yozuvlar; `-n 3` oxirgi 3 qator; `--no-pager` chiqishni `less` ga bermay to'g'ridan-to'g'ri chop etadi (skript va README uchun). Qator tuzilishi: vaqt, hostname, `jarayon[PID]`, xabar. `systemd[1]` bu PID 1 servisni ishga tushirgani haqidagi yozuvlar, `sshd[<PID>]` servisning o'z chiqishi. Sizda qatorlar boshqacha bo'lishi mumkin (Ubuntu 24.04 da `ssh` socket orqali, birinchi ulanishda ishga tushadi).

| Buyruq | Nima ko'rsatadi |
|--------|-----------------|
| `journalctl -u ssh` | bitta unit loglari |
| `journalctl -u ssh -f` | jonli kuzatish (`tail -f` kabi) |
| `journalctl -p err -b` | joriy boot'dan beri `err` va undan og'ir xabarlar |
| `journalctl --since "1 hour ago"` | vaqt oralig'i (`--until` ham bor) |
| `journalctl -k` | faqat kernel xabarlari |
| `journalctl -b -1` | oldingi boot loglari |
| `journalctl -t <tag>` | syslog tegi bo'yicha (masalan `-t sudo`) |
| `journalctl -xe` | oxiriga o'tib, izohlar bilan |
| `journalctl --disk-usage` | journal egallagan joy |

Prioritetlar syslog darajalari: `emerg`(0), `alert`(1), `crit`(2), `err`(3), `warning`(4), `notice`(5), `info`(6), `debug`(7). `-p warning` shu daraja va undan og'irlarini beradi. Bu `console.error`, `console.warn`, `console.info` darajalarining kattaroq to'plami. Oddiy foydalanuvchi faqat o'z loglarini ko'radi; hammasi uchun `sudo` yoki `adm`/`systemd-journal` guruhiga a'zolik kerak (VM'dagi `ubuntu` `adm` guruhida).

Journal hajmi `sudo journalctl --vacuum-size=200M` bilan qisqartiriladi, doimiy limit `/etc/systemd/journald.conf` dagi `SystemMaxUse=`.

### /var/log

Journal bilan birga matnli loglar ham bor (Ubuntu'da `rsyslog` servisi journal'dan olib yozadi). Ularni 7-darsdagi asboblar bilan o'qiysiz:

| Fayl (Ubuntu) | RHEL oilasida | Mazmuni |
|---------------|---------------|---------|
| `/var/log/syslog` | `/var/log/messages` | umumiy tizim logi |
| `/var/log/auth.log` | `/var/log/secure` | login, `sudo`, SSH |
| `/var/log/kern.log` | `/var/log/messages` | kernel |
| `/var/log/dpkg.log`, `/var/log/apt/history.log` | `/var/log/dnf.log` | paket o'rnatish tarixi |
| `/var/log/nginx/`, `/var/log/postgresql/` | xuddi shunday | dasturlarning o'z loglari |

```
ubuntu@lab:~$ sudo grep 'sudo:' /var/log/auth.log | tail -1
<sana> lab sudo:   ubuntu : TTY=pts/0 ; PWD=/home/ubuntu ; USER=root ; COMMAND=/usr/bin/grep sudo: /var/log/auth.log
```

`sudo` har chaqiruvni yozadi: kim (`ubuntu`), qaysi terminaldan (`TTY`), qaysi papkadan (`PWD`), kim nomidan (`USER=root`), qaysi buyruq (`COMMAND`, to'liq yo'l bilan). Bu yerda oxirgi yozuv shu `grep` ning o'zi.

Eski loglar `logrotate` orqali aylantiriladi: `syslog` to'lgach `syslog.1` ga, keyin siqilib `syslog.2.gz` ga o'tadi, eng eskisi o'chiriladi. Sozlamalari `/etc/logrotate.conf` va `/etc/logrotate.d/`. Siqilganlarini `zcat` va `zgrep` bilan o'qiysiz.

### dmesg

Kernel ring buffer: kernel xotirasidagi aylanma bufer, unda qurilmalar, drayverlar, fayl tizimi xatolari, OOM killer xabarlari turadi. `sudo dmesg -T` vaqtni o'qiladigan ko'rinishda beradi, `sudo dmesg --level=err,warn` faqat muammolar, `sudo dmesg -w` jonli kuzatish. Ubuntu'da oddiy foydalanuvchiga `dmesg` yopiq (`kernel.dmesg_restrict=1`, 1-dars), shuning uchun `sudo`. Bufer hajmi cheklangan, eski xabarlar ustidan yoziladi; to'liq tarix `journalctl -k` da.

### Real ishda qachon kerak

- Servis yiqildi: `journalctl -u <servis> -n 100` oxirgi so'zlarini ko'rsatadi.
- "Kecha soat 3 da nima bo'ldi": `journalctl --since "<sana> 02:50" --until "<sana> 03:10"`.
- Xavfsizlik tekshiruvi: kim qachon `sudo` ishlatgan, kim SSH bilan kirgan, `auth.log` da.

### Nima uchun shunday

Matnli `/var/log` fayllar Unix an'anasi (syslog, 1980-yillar): oddiy, `grep` bilan o'qiladi, lekin tuzilmasiz va har dastur o'z formatida yozadi. journald (2011) har yozuvga maydonlar qo'shdi, shuning uchun "faqat shu unit, faqat shu boot, faqat xatolar" kabi filtrlar matn qidirmasdan ishlaydi; narxi binar format, uni faqat `journalctl` o'qiydi. Ubuntu ikkalasini birga saqlaydi. Konteyner dunyosida uchinchi model keng tarqalgan: dastur faqat stdout'ga yozadi, logni yig'ish platformaning ishi (Docker va Kubernetes modullarida).

## 6. Servislar ro'yxati

**Servis** bu fonda doimiy ishlaydigan dastur (web server, ma'lumotlar bazasi, `sshd`); systemd ularni **unit** sifatida boshqaradi. "Server sekin" shikoyatida ikki savol: nima ishlayapti va nima yiqilgan.

```
ubuntu@lab:~$ systemctl list-units --type=service --state=running --no-pager | head -4
  UNIT                     LOAD   ACTIVE SUB     DESCRIPTION
  cron.service             loaded active running Regular background program processing daemon
  dbus.service             loaded active running D-Bus System Message Bus
  multipathd.service       loaded active running Device-Mapper Multipath Device Controller
ubuntu@lab:~$ systemctl --failed --no-pager
  UNIT LOAD ACTIVE SUB DESCRIPTION

0 loaded units listed.
```

Ustunlar: `UNIT` nom; `LOAD` unit fayli o'qildimi; `ACTIVE` umumiy holat; `SUB` aniq holat (`running` ishlayapti, `exited` bir marta ishlab tugagan, `failed` yiqilgan); `DESCRIPTION` unit faylidagi tavsif. `systemctl --failed` yiqilgan unit'lar: sog'lom tizimda `0 loaded units listed`.

| Buyruq | Nima ko'rsatadi |
|--------|-----------------|
| `systemctl list-units --type=service --state=running` | hozir ishlayotgan servislar |
| `systemctl --failed` | yiqilgan unit'lar |
| `systemctl list-unit-files --type=service --state=enabled` | boot'da yoqiladigan servislar |
| `systemctl status <unit>` | holat, asosiy PID, xotira, oxirgi log qatorlari |

`list-units` hozir xotiraga yuklangan unit'larni, `list-unit-files` diskdagi barcha unit fayllarni va ular boot'da yoqilishini ko'rsatadi. Bu darsda faqat o'qiymiz; unit yozish va boshqarish 11-darsda.

### Real ishda qachon kerak

- Reboot'dan keyin "sayt ochilmayapti": servis `enabled` emas, ya'ni boot'da yoqilmagan.
- Begona serverni qabul qilish: `list-units --state=running` u yerda aslida nima ishlayotganini aytadi.

### Nima uchun shunday

Node dunyosida bu rolni `pm2 list` o'ynaydi: nima ishlayapti, necha marta qayta ko'tarilgan, qancha xotira yeydi. Farqi: systemd PID 1, u butun tizimning servislarini biladi va har birini alohida cgroup'da saqlaydi, shuning uchun `status` da servisning xotirasi va barcha bola jarayonlari aniq ko'rinadi. systemd'gacha (SysV init) "servis ishlayaptimi" savoliga yagona javob yo'q edi: har servis o'z PID faylini yozardi va u eskirib qolishi mumkin edi.

## 7. Sekin serverda birinchi 60 soniya

### Tartib

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

### USE metodi

Har resurs uchun uchta savol: **Utilization** (qancha band), **Saturation** (navbat bormi), **Errors** (xato bormi).

| Resurs | Utilization | Saturation | Errors |
|--------|-------------|------------|--------|
| CPU | `us`+`sy` foizi (`vmstat`, `mpstat`) | `vmstat` dagi `r`, load, `/proc/pressure/cpu` | `dmesg` |
| Xotira | `free` dagi `used` va `available` | `si`/`so`, `/proc/pressure/memory`, OOM kill | `dmesg` dagi OOM |
| Disk | `df` (joy), `iostat` dagi `%util` | `aqu-sz`, `await`, `vmstat` dagi `b` va `wa` | `dmesg` dagi I/O xatolari |

Utilization 100% bo'lmasa ham saturation bo'lishi mumkin (bitta to'lgan yadro), shuning uchun uchala savol ham so'raladi.

Tarmoq (`ss`, `ip`, `sar -n DEV`) keyingi modulda. Hozircha bilish kerak bo'lgani: sekinlik sababi server ichida bo'lmasligi ham mumkin (DNS, tashqi API, ma'lumotlar bazasi). Hamma raqam xotirjam bo'lsa, tashqariga qarang.

### Real ishda qachon kerak

- Tungi alert: 60 soniyalik ro'yxat vahimasiz, bir xil tartibda ishlash imkonini beradi; natijani faylga yozib hamkasblarga yuborish mumkin (18-vazifa).
- Post-mortem (hodisadan keyingi tahlil) yozishda: qaysi raqam qaysi xulosaga olib kelgani hujjatlashtiriladi.

### Nima uchun shunday

Ro'yxatsiz diagnostika "ko'cha chirog'i ostidan qidirish" ga aylanadi: odam o'zi bilgan bitta asbobni (`top`) ochadi va u ko'rsatgan narsani sabab deb o'ylaydi. USE metodi buni teskari qiladi: avval resurslar ro'yxati, keyin har biriga bir xil uch savol, shunda hech narsa tushib qolmaydi. Muqobil yondashuv servis tomonidan qarash (RED: Rate, Errors, Duration, ya'ni so'rovlar soni, xatolar, davomiylik); u monitoring modulida, ikkalasi bir-birini to'ldiradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Load average | `R` va `D` holatidagi task'lar sonining 1, 5, 15 daqiqalik silliqlangan o'rtachasi |
| Task | kernel rejalashtiradigan birlik: jarayon yoki thread |
| PSI | resursni kutib to'xtab turilgan vaqt ulushi, `/proc/pressure/` da |
| `us`, `sy`, `id` | CPU vaqtining user space, kernel va bo'sh ulushlari |
| `wa` (iowait) | CPU bo'sh turib I/O javobini kutgan vaqt ulushi |
| `st` (steal) | hypervisor VM'dan olib boshqasiga bergan CPU vaqti |
| Hypervisor | bitta jismoniy mashinada bir nechta VM'ni ishlatadigan dastur |
| Context switch | kernel CPU'ni bir task'dan boshqasiga o'tkazishi |
| RES (RSS) | jarayonning haqiqatda RAM'da turgan xotirasi |
| Page cache | fayl ma'lumotlarining kernel xotirasidagi keshi |
| `available` | yangi dastur uchun swap'siz berilishi mumkin bo'lgan xotira bahosi |
| Swap | xotira sahifalari vaqtincha chiqarib qo'yiladigan disk maydoni |
| OOM killer | xotira tugaganda jarayon tanlab `SIGKILL` yuboradigan kernel mexanizmi |
| cgroup | jarayonlar guruhiga resurs limiti qo'yadigan kernel mexanizmi |
| Overcommit | kernel mavjud xotiradan ko'p xotira va'da qilishi |
| Inode | fayl haqidagi yozuv; soni cheklangan, `df -i` ko'rsatadi |
| IOPS | diskka soniyadagi o'qish va yozish so'rovlari soni |
| `await` | disk so'rovining navbat bilan birga o'rtacha kutish vaqti, ms |
| Journal | systemd'ning markaziy, binar formatdagi log bazasi |
| Ring buffer | kernel xabarlari turadigan cheklangan aylanma bufer, `dmesg` o'qiydi |
| logrotate | eski log fayllarni aylantirib, siqib, o'chiradigan asbob |
| Unit | systemd boshqaradigan obyekt, masalan `ssh.service` |
| USE metodi | har resurs uchun Utilization, Saturation, Errors savollari |

## Tuzoqlar

- Load average'ni CPU foizi deb o'qish. U yadrolar soniga nisbatan o'qiladi va I/O kutayotgan task'larni ham sanaydi.
- `free` ustuni kichikligidan vahimaga tushish. `available` ga qarang, page cache band xotira emas.
- Umumiy CPU foiziga qarab bitta to'lib qolgan yadroni o'tkazib yuborish.
- `vmstat`, `iostat`, `mpstat` ning birinchi qatorini joriy holat deb o'qish.
- Katta log faylni `rm` bilan o'chirib joy bo'shamaganiga hayron bo'lish: jarayon faylni ochiq ushlab turibdi.
- Disk 100% to'lganda servislar g'alati xatolar bilan yiqiladi. `df -h` ni birinchilardan tekshiring.
- OOM kill'ni dastur logidan qidirish. Jarayon `SIGKILL` oladi va hech narsa yoza olmaydi, iz faqat kernel logida.
- Faqat `df -h` ga qarab `df -i` ni unutish.
- Production serverda og'ir diagnostika (`du` butun `/` bo'yicha, `find /`) ishga tushirib, I/O muammosini kuchaytirish. `-x` va aniq katalogdan boshlang.
- `st` (steal) ni e'tiborsiz qoldirish: muammo sizning VM'da emas, hypervisor'da bo'lishi mumkin.
- Mac host'ida `free`, `vmstat` yoki `iostat -x` ni sinash: bu buyruqlar yo'q yoki BSD varianti, ustunlari boshqa. Faqat VM ichidagi chiqishni o'qing.
- Mac'da konteyner OOM xabarini host'dan qidirish: u Docker'ning yashirin VM'i kernel'ida, `docker inspect` dagi `OOMKilled` ga qarang.
- Yuklamani VM'da qoldirib ketish: `stress-ng` `--timeout` siz cheksiz ishlaydi, VM esa host CPU'sini yeydi.

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
- https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html – systemd-run(1)
- Brendan Gregg, "Systems Performance" (2-nashr), 2 va 6–9 boblar

---

## Birga bajaramiz

Bitta "noma'lum" yuklamani ro'yxat bo'yicha topamiz, to'xtatamiz va izini logdan qidiramiz. Misol: `sha256sum /dev/zero`. `/dev/zero` cheksiz nol baytlar beradi (1-dars), `sha256sum` ularning xeshini hisoblaydi va hech qachon tugamaydi: bitta thread, sof hisob-kitob, disksiz. Vazifalarda `stress-ng` ishlatiladi, bu yerda ataylab boshqa yuklama. Hamma narsa VM ichida.

1. Tinch holatni yozib oling, keyin solishtirish uchun:

```
ubuntu@lab:~$ uptime
 <vaqt> up <N> min,  1 user,  load average: 0.00, 0.01, 0.00
```

2. Yuklamani fonda ishga tushiring. `&` buyruqni fonga yuboradi (9-darsda), shell PID'ni aytadi:

```
ubuntu@lab:~$ sha256sum /dev/zero &
[1] <PID>
```

3. 30 soniya kutib `uptime` ni ikki marta oling:

```
ubuntu@lab:~$ uptime
 <vaqt> up <N> min,  1 user,  load average: 0.42, 0.11, 0.03
ubuntu@lab:~$ uptime
 <vaqt> up <N> min,  1 user,  load average: 0.78, 0.25, 0.08
```

1 daqiqalik son asta o'sib `1.0` ga intiladi (bitta doimiy `R` task), 15 daqiqalik deyarli qimirlamagan: muammo yangi. `nproc` 2, demak load `1.0` "bir yadro band".

4. Tizim bo'yicha qarang. Birinchi qatorni tashlab o'qing:

```
ubuntu@lab:~$ vmstat 1 3
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 1  0      0 <N> <N> <N>    0    0    <N>    <N>  <N>  <N>  2  1 97  0  0  0
 1  0      0 <N> <N> <N>    0    0     0     0   <N>  <N> 50  0 50  0  0  0
 1  0      0 <N> <N> <N>    0    0     0     0   <N>  <N> 50  0 50  0  0  0
```

`r` 1: bitta task CPU'da, navbat yo'q (`nproc` dan kichik). `us` 50, `id` 50: ikki yadroning yarmi band. `wa` 0, `b` 0, `si`/`so` 0: disk va xotira aybdor emas. Xulosa: sof CPU yuklamasi, user space'da.

5. Qaysi yadro:

```
ubuntu@lab:~$ mpstat -P ALL 1 1 | tail -3
<vaqt>  all   50.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00   50.00
<vaqt>    0    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00  100.00
<vaqt>    1  100.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00
```

`all` 50% deydi, lekin aslida bir yadro 100%, ikkinchisi bo'sh. Bu "bitta issiq yadro" tuzog'ining ko'rinishi. Kernel task'ni yadrolar orasida ko'chirib turishi mumkin, sizda raqamlar aralashroq chiqsa hayron bo'lmang.

6. Qaysi jarayon:

```
ubuntu@lab:~$ pidstat 1 1 | grep -v pidstat
...
<vaqt>  1000    <PID>  100.00    0.00    0.00    0.00  100.00     1  sha256sum
```

`UID 1000` (`ubuntu`), `%usr` 100, `%system` 0, `Command sha256sum`. `top` da ham tasdiqlang: `top` ni oching, `P` ni bosing, birinchi qatorda `sha256sum`, `S` ustunida `R`, `%CPU` 100 atrofida; `1` ni bosib yadrolarni ko'ring; `q` bilan chiqing.

7. Jarayonni to'xtating va natijani tekshiring. `kill` signal yuboradi (9-darsda), `%1` shu shell'dagi birinchi fon ishi:

```
ubuntu@lab:~$ kill %1
[1]+  Terminated              sha256sum /dev/zero
ubuntu@lab:~$ pgrep sha256sum
ubuntu@lab:~$ uptime
 <vaqt> up <N> min,  1 user,  load average: 0.61, 0.35, 0.14
```

`pgrep` hech narsa chiqarmadi: jarayon yo'q. Load darhol nolga tushmaydi, asta so'nadi: o'rtacha silliqlangan.

8. Endi log tomoni. Bu yuklama kernel uchun xato emas, shuning uchun `dmesg` da izi yo'q: baland CPU log yozmaydi, uni faqat raqamlardan topasiz. Log qidirishni mashq qilish uchun journal'ga o'zimiz xabar yozamiz. `logger` buyrug'i syslog/journal'ga bitta yozuv qo'shadi, `-t` teg, `-p` prioritet:

```
ubuntu@lab:~$ logger -t walkthrough -p user.err "cpu hog found: sha256sum, killed"
ubuntu@lab:~$ journalctl -t walkthrough --no-pager
<sana> lab walkthrough[<PID>]: cpu hog found: sha256sum, killed
ubuntu@lab:~$ journalctl -p err --since "5 min ago" --no-pager | tail -1
<sana> lab walkthrough[<PID>]: cpu hog found: sha256sum, killed
ubuntu@lab:~$ grep walkthrough /var/log/syslog
<sana> lab walkthrough[<PID>]: cpu hog found: sha256sum, killed
```

Bitta yozuv uch yo'l bilan topildi: teg bo'yicha, prioritet va vaqt bo'yicha, va matn faylidan `grep` bilan. Uchinchisi journal'dagi yozuvni `rsyslog` `/var/log/syslog` ga ham ko'chirganini ko'rsatadi (vaqt formati faylda boshqacha bo'lishi mumkin).

9. Xulosa zanjiri, post-mortem uslubida: load o'sdi (1 daqiqalik son 15 daqiqalikdan katta) → `vmstat`: `r` 1, `us` 50, `wa` 0, swap 0, demak CPU, disk va xotira emas → `mpstat`: bitta yadro 100% → `pidstat`: `sha256sum`, `%usr` 100 → to'xtatildi, load so'ndi. 19-vazifada shunday zanjirni o'zingiz yozasiz, lekin sabab noma'lum bo'ladi.

---

## Vazifalar

Ish papkasi: `linux/08-resources/` (`make new m=linux n=08 name=resources` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptlarni yoniga saqlang (VM'da sinab, `multipass transfer` bilan yoki matnini ko'chirib). Hamma vazifa `lab` VM'da bajariladi, faqat 9-vazifaning Docker qismi host'da. Har vazifa ostidagi "Yo'nalish" qayerdan qidirishni aytadi, yechimni emas.

### A. Umumiy holat va CPU

1. **Load vs cores.** VM'da `uptime` va `nproc` ni ishga tushiring. "Load yadrolar soniga nisbatan qancha" ekanini hisoblang. `/proc/loadavg` dagi to'rtinchi maydon (`N/M` shaklidagi) va beshinchi maydon nimani bildirishini `man 5 proc` (yoki `man proc_loadavg`) dan topib yozing. Ixtiyoriy: host'da ham `uptime` ni oling (Zorin'da va macOS'da ishlaydi; yadrolar soni Zorin'da `nproc`, macOS'da `sysctl -n hw.ncpu`) va VM bilan solishtiring. Yo'nalish: 1-bo'lim, `man` sahifasida `loadavg` so'zini `/` bilan qidiring.

2. **CPU saturation.** VM'da `stress-ng --cpu 4 --timeout 120s` ni ishga tushiring (VM yadrolaridan ko'p worker). Ikkinchi oynada `uptime` ni har 20 soniyada, `vmstat 1 10` ni bir marta oling. 1 daqiqalik load qanday o'sdi, `r` ustuni qancha, `us` va `id` qancha? Load nima uchun birdaniga emas, asta ko'tarilishini izohlang. Yo'nalish: 1-bo'lim "Mexanizm", 2-bo'limdagi `vmstat` jadvali; `r` ni `nproc` bilan solishtiring.

3. **Single hot core.** VM'da `stress-ng --cpu 1 --timeout 60s` ishga tushiring. `top` ning umumiy `%Cpu(s)` qatorini yozib oling, keyin `1` ni bosing va `mpstat -P ALL 1 3` ni oling. Umumiy raqam nima uchun aldashini va bu Node.js servis uchun nimani anglatishini yozing. Yo'nalish: 2-bo'limdagi tuzoq; 8 yadroli serverda shu holat qanday ko'rinishini hisoblab ko'ring.

4. **Find the process.** Yuklama ishlab turganida aybdor jarayonni uch usul bilan toping: `top` (saralash tugmasi bilan), `pidstat 1 3`, va `ps` ning `--sort` opsiyasi bilan. Har birining qulayligi qaysi vaziyatda ekanini 2–3 gapda yozing. Yo'nalish: `man ps` da `--sort` va `-o` ni toping; `ps` bir lahzalik surat, `pidstat` oraliq bo'yicha o'lchaydi.

5. **First vmstat line.** Tinch VM'da `vmstat 1 5` oling. Birinchi qator bilan qolganlarining farqini ko'rsating va `man vmstat` dan buni tasdiqlovchi jumlani toping. Yo'nalish: `man vmstat` ning DESCRIPTION bo'limi, "first report" so'zlari.

### B. Xotira

6. **Reading free.** VM'da `free -h` oling. `total`, `used`, `free`, `buff/cache`, `available` orasidagi bog'lanishni o'z raqamlaringiz bilan tushuntiring. `/proc/meminfo` dan `MemAvailable`, `Cached`, `SwapFree` qatorlarini `grep` bilan chiqarib `free` bilan solishtiring. Ixtiyoriy, faqat Zorin'da: host'da ham `free -h` oling va uzoq ishlagan mashinada `buff/cache` qanchalik katta ekanini VM bilan solishtiring (macOS'da `free` yo'q). Yo'nalish: 3-bo'lim; `man free` da har ustunning `/proc/meminfo` dagi manbai yozilgan.

7. **Page cache in action.** VM'da `dd if=/dev/zero of=/var/tmp/big.bin bs=1M count=500` bilan fayl yarating. Oldin va keyin `free -m` oling: qaysi ustun o'sdi? Keyin `time cat /var/tmp/big.bin > /dev/null` ni ikki marta ketma-ket bajaring va vaqtlarni solishtiring. Natijani page cache orqali izohlang. Faylni o'chiring. Yo'nalish: 3-bo'lim "Mexanizm". Farq ko'rinmasa, o'ylab ko'ring: faylni hozirgina yozdingiz, u allaqachon keshda emasmi? Keshni ataylab bo'shatish usulini `man 5 proc` dagi `drop_caches` dan toping.

8. **Memory pressure.** VM'da `stress-ng --vm 1 --vm-bytes 75% --timeout 60s` ishga tushiring. Parallel ravishda `vmstat 1` va `cat /proc/pressure/memory` ni kuzating. `available`, `si`/`so` va PSI qiymatlari qanday o'zgardi? Yo'nalish: 1-bo'lim PSI, 3-bo'lim. VM'da swap bormi (`free -h`)? Shunga qarab `si`/`so` nima ko'rsatishi kerakligini oldindan taxmin qiling, keyin tekshiring.

9. **OOM in a cgroup.** Host'da `docker run --name oomtest -m 100m ubuntu:24.04 tail /dev/zero` ni ishga tushiring (`tail` xotirani cheksiz yig'adi, limit konteynerni to'xtatadi). Exit code'ni (`echo $?`) va `docker inspect oomtest` dagi `OOMKilled` maydonini toping, konteynerni o'chiring (`docker rm oomtest`). Kernel xabari uchun: `lab` VM'da xuddi shu `tail /dev/zero` ni `systemd-run` orqali 100M limit bilan ishga tushiring va `journalctl -k` dan tegishli qatorlarni toping. Kernel xabaridan: qaysi jarayon, qancha xotira bilan o'ldirilgan? Ixtiyoriy, faqat Zorin'da: konteyner uchun ham host'ning `journalctl -k` chiqishidan shu qatorni toping; Mac'da nima uchun topilmasligini yozing. Yo'nalish: 3-bo'limdagi misol (u yerda boshqa buyruq va boshqa limit); `docker inspect` chiqishini `grep` bilan filtrlang.

10. **oom_score.** VM'da `sshd` (yoki `systemd-journald`) va o'z shell'ingiz uchun `/proc/<PID>/oom_score` va `oom_score_adj` ni o'qing. Qiymatlar nima uchun farq qiladi? Production'da ma'lumotlar bazasi jarayoniga qanday `oom_score_adj` qo'ygan bo'lardingiz va buning xavfi nimada? Yo'nalish: PID'ni `pgrep` bilan toping; `man 5 proc` da `oom_score_adj`. Himoyalangan jarayon xotirani yeyaversa, kernel kimni o'ldiradi?

### C. Disk

11. **df vs du.** VM'da `df -hT` va `df -i` oling, `tmpfs` va `loop`/`squashfs` qatorlari nima ekanini izohlang (sizda `loop` qatorlari bo'lmasa, `snap list` bilan nima uchun ekanini tekshiring). Keyin `/var` ichidagi eng katta 5 katalogni `du` va `sort` bilan toping. Yo'nalish: 4-bo'lim; misol `/usr` uchun berilgan, flag'larni o'zingiz moslang.

12. **Deleted but open.** VM'da: `dd if=/dev/zero of=/var/tmp/ghost.log bs=1M count=300`, keyin `tail -f /var/tmp/ghost.log &`, keyin `rm /var/tmp/ghost.log`. `df -h /var/tmp` joy bo'shaganini ko'rsatadimi? `sudo lsof +L1` bilan faylni toping, `tail` ni to'xtating va `df` ni qayta oling. Production'da ishlab turgan servisning log faylini qanday bo'shatish kerakligini yozing. Yo'nalish: 4-bo'limdagi tuzoq; `lsof` chiqishida `(deleted)` so'zini va `SIZE/OFF` ustunini qidiring.

13. **I/O wait.** VM'da `iostat -xz 1` ni ishga tushirib, ikkinchi oynada `dd if=/dev/zero of=/var/tmp/io.bin bs=1M count=1500 oflag=direct` bajaring. `w/s`, `wkB/s`, `w_await`, `%util` qanday o'zgardi, `vmstat` da `wa` va `b` nima ko'rsatdi? `pidstat -d 1` bilan yozayotgan jarayonni toping. Faylni o'chiring. Yo'nalish: 4-bo'lim `iostat` jadvali; `oflag=direct` nima qilishini `man dd` dan toping va page cache bilan bog'lang. Oldin `df -h /` da 1.5G bo'sh joy borligini tekshiring.

### D. Loglar va servislar

14. **journalctl filters.** VM'da quyidagilarni chiqaring: `ssh` unit'ining oxirgi 20 qatori; joriy boot'dagi `err` va undan og'ir xabarlar; oxirgi 15 daqiqadagi kernel xabarlari. Har biri uchun aniq buyruqni yozing. `journalctl --disk-usage` natijasini ham. Yo'nalish: 5-bo'limdagi jadval, flag'larni birlashtiring; README uchun `--no-pager`.

15. **Trace a sudo call.** VM'da `sudo ls /root` bajaring, keyin shu hodisani ikki joydan toping: `/var/log/auth.log` (7-darsdagi `grep` bilan) va `journalctl` orqali. Qatorda qaysi ma'lumotlar bor (kim, qaysi terminal, qaysi katalogdan, qaysi buyruq)? Yo'nalish: 5-bo'limdagi `auth.log` misoli; journal uchun teg yoki vaqt bo'yicha filtr.

16. **dmesg.** VM'da `sudo dmesg -T | head -30` va `sudo dmesg --level=err,warn` oling. Boot loglaridan CPU soni, RAM hajmi va root fayl tizimi qaysi qurilmadan mount qilinganini toping. `sudo` siz `dmesg` nima deydi va nima uchun? Yo'nalish: 7-darsdagi `grep -i` bilan `cpus`, `memory`, `mounted` so'zlarini qidiring; `sysctl kernel.dmesg_restrict`.

17. **Services inventory.** VM'da ishlab turgan servislar ro'yxatini, yiqilgan unit'larni va boot'da yoqiladigan servislar sonini chiqaring. Ro'yxatdan sizga notanish 3 ta servisni tanlab, `systemctl status` va `man` orqali vazifasini bir gapdan yozing. Yo'nalish: 6-bo'lim; sanash uchun `--no-legend` flagi va `wc -l`.

### E. Yakuniy

18. **60 seconds script.** `task_18.sh` yozing: 7-bo'limdagi tekshiruvlarni ketma-ket bajarib, har biri oldidan sarlavha chop etadigan va natijani `report-$(hostname)-$(date +%F-%H%M).txt` fayliga yozadigan skript. Interaktiv buyruqlarni batch rejimida ishlating, cheksiz ishlaydiganlarga takror sonini bering. `shellcheck` toza bo'lsin. Skript VM'da ishlaydi (host'da, ayniqsa macOS'da, bu buyruqlarning yarmi yo'q). Yo'nalish: 5-darsdagi funksiya va redirect; `top` va `journalctl` ning pager'siz, bir martalik rejimlari 2 va 5-bo'limlarda.

19. **Blind diagnosis.** VM'da quyidagi uch yuklamadan birini tasodifiy tanlab ishga tushiradigan skript yozing (`task_19.sh`, `$RANDOM` bilan): CPU yuklamasi, xotira bosimi, `/var/tmp` ga katta fayl yozish. Skriptni ishga tushirib, qaysi biri tanlanganiga qaramasdan, 18-vazifadagi hisobot va qo'shimcha buyruqlar yordamida sababni aniqlang. README'ga tashxis yo'lini yozing: qaysi raqam qaysi xulosaga olib keldi. Yo'nalish: "Birga bajaramiz" ning 9-qadamidagi zanjir shakli; skript qaysi tarmoqni tanlaganini ekranga chiqarmasin, yuklamaga `--timeout` yoki hajm chegarasi bering.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi (host'da; `shellcheck` skriptlar uchun).
2. VM'da `stress-ng` jarayonlari va `/var/tmp` dagi katta fayllar qolmagan, `oomtest` konteyneri o'chirilgan (`docker ps -a`).
3. README'da har vazifa uchun buyruq, natijaning muhim qismi va izoh bor; qaysi vazifa VM'da, qaysi qismi host'da bajarilgani ko'rinadi.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- 2 yadroli serverda load average `6.0, 5.5, 5.0`, CPU `id` 90%. Bu qanday bo'lishi mumkin va keyingi qadamingiz nima?
- Load average va PSI farqi nima, `some` va `full` qatorlari nimani bildiradi?
- `free` dagi `free` va `available` farqi nima, qaysi biriga qarab qaror qilinadi?
- `wa` va `st` nimani bildiradi, har biri baland bo'lsa aybdorni qayerdan qidirasiz?
- `df` 100% deydi, `du` esa atigi 40% ni topdi. Ikki mumkin bo'lgan sababni ayting.
- OOM killer ishlaganini qanday bilasiz va nima uchun dastur logida izi yo'q? Exit code 137 qayerdan keladi?
- Mashinada RAM bo'sh, lekin konteyner OOM bilan o'ldirildi. Qanday? Mac'da bu xabarni nima uchun host'dan topib bo'lmaydi?
- `vmstat 1` ning birinchi qatoriga nima uchun ishonib bo'lmaydi?
- `journalctl -p err -b` aynan nimani chiqaradi?
- USE metodining uch savoli nima, disk uchun har biriga qaysi buyruq javob beradi?
