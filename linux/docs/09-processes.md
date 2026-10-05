# 9-dars: Jarayonlarni boshqarish

Maqsad: Linux'da jarayon (process) qanday tug'ilishi, yashashi va o'lishini tushunish. Jarayon modeli (fork/exec, PID/PPID), holatlar, signal'lar va job control keyingi hamma narsaning asosi: systemd servisni qanday to'xtatishi (11-dars), `docker stop` nima uchun 10 soniya kutishi, Kubernetes'dagi graceful shutdown, CI'da osilib qolgan job. 8-darsda "qaysi jarayon resurs yeyapti" ni topdingiz, bu darsda u bilan nima qilishni o'rganasiz.

Taxminiy vaqt: 2 kun (siz uchun). `ps` va `kill` tanish bo'lishi mumkin, diqqatni quyidagilarga qarating: fork/exec modeli va undan kelib chiqadigan zombie/orphan, `SIGTERM` va `SIGKILL` farqi, bash'da `trap` ning kechikishi, terminal yopilganda jarayonlar bilan nima bo'lishi, PID 1 ning maxsus roli.

## Laboratoriya

- O'qiydigan buyruqlar (`ps`, `pstree`, `/proc`) ish mashinasida ham ishlaydi. Ish mashinangizda shell `zsh`: job control va `disown` xatti-harakati bash'dan farq qiladi, shuning uchun B va C guruh vazifalarini VM ichidagi `bash` da bajaring.
- Asosiy muhit: Multipass VM (`multipass shell lab`). Bir nechta terminal kerak bo'ladi: har birida alohida `multipass shell lab`.
- PID 1 tajribasi uchun ish mashinasida bir martalik konteyner: `docker run --rm ...`.
- Paketlar (VM'da): `sudo apt install -y psmisc` (`pstree`, `killall`; odatda o'rnatilgan).
- Tozalash: dars oxirida `pgrep -a sleep` bo'sh bo'lsin, test konteynerlari o'chirilgan bo'lsin.

---

## 1. Jarayon modeli

### Dastur va jarayon

Dastur diskdagi fayl, jarayon uning ishlayotgan nusxasi: o'z virtual xotirasi, ochiq fayl deskriptorlari, environment o'zgaruvchilari, joriy katalogi, egasi (UID/GID) va kernel bergan raqami (**PID**) bilan.

### fork va exec

Linux'da yangi jarayon ikki qadamda yaratiladi:

1. `fork()`: ota jarayon o'zining nusxasini yaratadi. Bola yangi PID oladi, qolgan hamma narsa (environment, ochiq fayllar, joriy katalog) meros bo'ladi.
2. `exec()`: bola o'z xotirasini boshqa dastur bilan almashtiradi. PID o'zgarmaydi.

Shell'da `ls` yozganingizda aynan shu bo'ladi: bash fork qiladi, bola `ls` ni exec qiladi, bash `wait()` bilan bolaning tugashini kutadi va exit code'ni `$?` ga yozadi. 5-darsdagi "environment bolaga meros bo'ladi, ota o'zgarmaydi" qoidasi shu mexanizmning natijasi.

Har jarayonning otasi bor (**PPID**), shuning uchun jarayonlar daraxt hosil qiladi. Ildizi PID 1: kernel boot oxirida ishga tushiradigan birinchi user space jarayoni, zamonaviy distributivlarda `systemd`.

```
$ echo $$ $PPID          # PID of this shell and of its parent
$ pstree -p -s $$        # ancestors of this shell up to PID 1
```

### Jarayon holatlari

`ps` ning `STAT` (yoki `S`) ustunidagi birinchi harf:

| Harf | Holat | Izoh |
|------|-------|------|
| `R` | running/runnable | CPU'da yoki CPU navbatida |
| `S` | interruptible sleep | hodisa kutyapti (tarmoq, timer, input). Ko'pchilik jarayon shu holatda |
| `D` | uninterruptible sleep | odatda disk I/O. Signal qabul qilmaydi, load average'ga kiradi |
| `T` | stopped | `SIGSTOP`/`SIGTSTP` bilan to'xtatilgan |
| `Z` | zombie | tugagan, otasi hali exit code'ni o'qimagan |
| `I` | idle | bo'sh turgan kernel thread |

Qo'shimcha belgilar: `s` session leader, `+` foreground guruhida, `l` ko'p thread'li, `<` yuqori prioritet, `N` past prioritet.

## 2. Jarayonlarni ko'rish

### ps

`ps` ning ikki sintaksisi bor va ikkalasi ham ishlatiladi:

| Buyruq | Uslub | Nima beradi |
|--------|-------|-------------|
| `ps aux` | BSD (defissiz) | hamma jarayon, `%CPU`, `%MEM`, `VSZ`, `RSS`, `STAT` bilan |
| `ps -ef` | UNIX | hamma jarayon, `PPID` bilan |
| `ps -ef --forest` | | daraxt ko'rinishida |
| `ps -p 1234 -o pid,ppid,user,stat,etime,cmd` | | bitta jarayon, tanlangan ustunlar |
| `ps -eo pid,ppid,stat,ni,%cpu,%mem,cmd --sort=-%mem \| head` | | xotira bo'yicha saralangan |
| `ps -u deploy` | | bitta foydalanuvchining jarayonlari |
| `ps -eLf` | | thread'lar bilan (`LWP` ustuni) |

`ps` bir lahzalik surat, `top` jonli. Nom bo'yicha qidirish uchun `ps aux | grep nginx` o'rniga `pgrep -a nginx` (`grep` ning o'zi natijaga tushib qolmaydi). `pgrep -f` to'liq buyruq qatori bo'yicha qidiradi, `pgrep -u deploy` egasi bo'yicha.

Kvadrat qavsdagi nomlar (`[kworker/0:1]`, `[kthreadd]`) kernel thread'lari, ular PID 2 (`kthreadd`) ning bolalari va ularni boshqarmaysiz.

### /proc

`/proc` diskdagi katalog emas, kernel ma'lumotlarining fayl ko'rinishi. `ps`, `top`, `free` hammasi shu yerdan o'qiydi. Har jarayon uchun `/proc/<PID>/`:

| Yo'l | Mazmuni |
|------|---------|
| `cmdline` | buyruq qatori, argumentlar NUL bayt bilan ajratilgan (`tr '\0' ' '` bilan o'qing) |
| `environ` | environment (ham NUL bilan), faqat egasi va root o'qiydi |
| `status` | holat, PPID, UID/GID, `VmRSS`, thread'lar soni, signal maskalari |
| `cwd`, `exe` | joriy katalog va bajarilayotgan faylga symlink |
| `fd/` | ochiq fayl deskriptorlari (0, 1, 2 va boshqalar) |
| `limits` | resurs limitlari (ochiq fayllar soni va boshqalar) |

`/proc/self` har doim o'qiyotgan jarayonning o'ziga ishora qiladi. Ishlab turgan servisning haqiqiy environment'ini, qaysi faylga log yozayotganini yoki qaysi binary'dan ishga tushganini shu yerdan bilasiz, konfiguratsiya fayliga ishonish shart emas.

**Tuzoq: environment'dagi secret.** `environ` ni jarayon egasi va root o'qiy oladi, buyruq qatoridagi argumentlar (`cmdline`) esa hammaga ko'rinadi. Parolni argument sifatida berish (`mysql -pSECRET`) uni `ps aux` da hammaga ochadi.

## 3. Job control: foreground va background

Terminalda ishga tushgan buyruq **foreground** da: klaviaturadan o'qiydi, `Ctrl+C` unga boradi. Shell har pipeline'ni **job** deb hisoblaydi.

| Amal | Natija |
|------|--------|
| `cmd &` | background'da ishga tushirish, shell `[1] 12345` (job raqami va PID) chiqaradi |
| `Ctrl+Z` | foreground job'ga `SIGTSTP`: to'xtatib qo'yadi (holat `T`) |
| `jobs -l` | shu shell'ning job'lari, PID bilan |
| `bg %1` | to'xtatilgan job'ni background'da davom ettirish (`SIGCONT`) |
| `fg %1` | job'ni foreground'ga qaytarish |
| `kill %1` | job'ga signal yuborish |
| `wait` | barcha background job'lar tugashini kutish |
| `$!` | oxirgi background jarayonning PID'i |

Job raqamlari (`%1`) faqat shu shell ichida ma'noga ega, PID esa butun tizimda.

### Terminal yopilganda nima bo'ladi

SSH uzilsa yoki terminal oynasi yopilsa, kernel session leader'ga (shell'ga) `SIGHUP` yuboradi. Bash uni olgach o'zining barcha job'lariga ham `SIGHUP` yuboradi, standart reaksiya esa o'lish. Uzoq ishlaydigan buyruq shuning uchun SSH uzilganda yo'qoladi. Himoyalanish usullari:

| Usul | Nima qiladi | Qachon |
|------|-------------|--------|
| `nohup cmd &` | `SIGHUP` ni e'tiborsiz qilib ishga tushiradi; chiqish terminal bo'lsa `nohup.out` ga yo'naltiradi | oldindan bilganingizda |
| `disown %1` | job'ni shell jadvalidan o'chiradi, shell unga `SIGHUP` yubormaydi | allaqachon ishga tushirib qo'yganingizda |
| `disown -h %1` | jadvalda qoldiradi, faqat `SIGHUP` yubormaslikni belgilaydi | |
| `setsid cmd` | yangi session'da ishga tushiradi, terminaldan butunlay uziladi | |
| `tmux` / `screen` | terminalning o'zi serverda yashaydi, qayta ulanasiz | interaktiv uzoq ish |
| systemd unit yoki `systemd-run` | to'g'ri yechim: log, restart, limitlar bilan | har qanday doimiy servis |

**Tuzoq: `nohup` production servis uchun emas.** `nohup node app.js &` jarayon yiqilsa qayta ko'tarmaydi, reboot'dan keyin ishga tushmaydi, loglari `nohup.out` da cheksiz o'sadi. Doimiy ishlaydigan narsa systemd unit bo'lishi kerak (11-dars).

**Tuzoq: `disown` dan keyin ham jarayon o'lishi mumkin.** Jarayon terminalga yozmoqchi bo'lsa va terminal yopilgan bo'lsa, yozish xato beradi. Chiqishni faylga yo'naltiring: `cmd > out.log 2>&1 &`.

## 4. Signal'lar

Signal bu jarayonga kernel orqali yuboriladigan asinxron xabar. Jarayon har signal uchun uch narsadan birini qiladi: standart amal (ko'pincha o'lim), o'z handler'i, yoki e'tiborsiz qoldirish. Ikki signal bundan mustasno: `SIGKILL` va `SIGSTOP` ni ushlab ham, e'tiborsiz qoldirib ham bo'lmaydi, ularni kernel o'zi bajaradi.

| Signal | Raqam | Standart amal | Kim yuboradi, nima uchun |
|--------|-------|---------------|--------------------------|
| `SIGHUP` | 1 | o'lim | terminal yopildi; daemon'lar uchun an'anaviy "konfiguratsiyani qayta o'qi" |
| `SIGINT` | 2 | o'lim | `Ctrl+C` |
| `SIGQUIT` | 3 | o'lim + core dump | `Ctrl+\` |
| `SIGKILL` | 9 | o'lim, ushlab bo'lmaydi | oxirgi chora, OOM killer |
| `SIGUSR1`, `SIGUSR2` | 10, 12 | o'lim | dasturning o'zi ma'no beradi (masalan logni qayta ochish) |
| `SIGSEGV` | 11 | o'lim + core dump | noto'g'ri xotira murojaati |
| `SIGPIPE` | 13 | o'lim | o'quvchisi yo'q pipe'ga yozish (`yes \| head -1`) |
| `SIGTERM` | 15 | o'lim | "iltimos, tugat": `kill` ning standart signali, `systemctl stop`, `docker stop` |
| `SIGCHLD` | 17 | e'tiborsiz | bola tugaganda otaga |
| `SIGCONT` | 18 | davom etish | `bg`, `fg` |
| `SIGSTOP` | 19 | to'xtash, ushlab bo'lmaydi | |
| `SIGTSTP` | 20 | to'xtash | `Ctrl+Z` |

Raqamlar x86 va ARM Linux uchun. To'liq ro'yxat: `kill -l`, tavsif: `man 7 signal`. Skriptlarda raqam emas, nom yozing.

### kill, pkill, killall

```
$ kill 1234              # SIGTERM
$ kill -TERM 1234        # the same, explicit
$ kill -KILL 1234        # SIGKILL, last resort
$ kill -0 1234           # send nothing, only check the process exists
$ pkill -f "node server" # by full command line pattern
$ pkill -HUP nginx       # by name, specific signal
$ killall sleep          # all processes with this exact name
```

Signalni faqat jarayon egasi yoki root yubora oladi.

### SIGTERM va SIGKILL

`SIGTERM` ni dastur ushlaydi va tartibli tugaydi: yangi so'rov qabul qilishni to'xtatadi, joriylarini tugatadi, bufer va fayllarni yozib yopadi, lock va vaqtinchalik fayllarni o'chiradi. `SIGKILL` da dastur hech narsa qila olmaydi: kernel uni darhol olib tashlaydi. Yarim yozilgan fayl, yopilmagan tranzaksiya, qolib ketgan lock fayl shundan chiqadi.

To'g'ri tartib: `SIGTERM`, bir necha soniya kutish, faqat shundan keyin `SIGKILL`. `systemctl stop` va `docker stop` aynan shunday ishlaydi (kutish mos ravishda standart 90 va 10 soniya).

**Tuzoq: `kill -9` refleksi.** Birinchi urinishda `-9` yuborish ma'lumot buzilishining klassik sababi. `SIGKILL` faqat jarayon `SIGTERM` ga javob bermaganda.

`D` holatidagi jarayon signal qabul qilmaydi (I/O tugashini kutadi), `Z` holatidagi allaqachon o'lgan: ikkalasiga ham `kill -9` ta'sir qilmaydi.

### Exit code va signal

Jarayon signaldan o'lsa, shell `$?` ga `128 + signal raqami` ni yozadi:

| `$?` | Sabab |
|------|-------|
| 130 | `SIGINT` (128 + 2) |
| 137 | `SIGKILL` (128 + 9): `kill -9`, OOM killer, `docker stop` timeout |
| 143 | `SIGTERM` (128 + 15) |

CI logida yoki `docker ps -a` da `Exited (137)` ko'rsangiz, birinchi gumon OOM.

### trap

Bash skriptida signal handler `trap` bilan o'rnatiladi:

```
#!/usr/bin/env bash
tmp=$(mktemp)
cleanup() { rm -f "$tmp"; echo "cleaned up"; }
trap cleanup EXIT
trap 'echo "got SIGTERM"; exit 143' TERM
trap 'echo "got SIGINT"; exit 130' INT
```

`EXIT` signal emas, bash'ning pseudo-signali: skript istalgan yo'l bilan tugaganda (oddiy tugash, `exit`, ushlangan signaldan keyingi `exit`) ishlaydi. Tozalash uchun eng ishonchli joy. `SIGKILL` da hech qanday trap ishlamaydi.

**Tuzoq: trap foreground buyruq tugashini kutadi.** Bash signal handler'ni faqat joriy foreground buyruq tugagach bajaradi. Skript `sleep 3600` da turgan bo'lsa, `SIGTERM` handler bir soatdan keyin ishlaydi. Yechim: buyruqni background'ga chiqarib `wait` qilish, chunki `wait` signal kelganda darhol qaytadi:

```
sleep 3600 &
wait $!
```

### PID 1 va konteynerlar

PID 1 uchun kernel maxsus qoida qo'llaydi: handler o'rnatilmagan signal unga yetkazilmaydi (standart "o'lim" amali ishlamaydi). Konteynerda sizning dasturingiz PID 1 bo'ladi. Agar u `SIGTERM` handler yozmagan bo'lsa, `docker stop` 10 soniya kutib `SIGKILL` yuboradi. Ikkinchi klassik holat: Dockerfile'da `CMD npm start` (shell shakli) yozilsa, PID 1 `sh` bo'ladi va signal dasturingizga umuman yetib bormaydi. Docker modulida `exec` shakli va `--init` bilan chuqur ko'ramiz.

## 5. Prioritet: nice va renice

CPU yetishmaganda scheduler vaqtni **nice** qiymatiga qarab taqsimlaydi: -20 (eng yuqori prioritet) dan 19 (eng past) gacha, standart 0. Nom "boshqalarga nisbatan muloyimlik" dan: nice qancha baland bo'lsa, jarayon shuncha kam CPU talab qiladi.

```
$ nice -n 10 tar czf backup.tgz /srv/data   # start with low priority
$ renice -n 15 -p 1234                      # change a running process
$ ps -o pid,ni,cmd -p 1234
```

- Oddiy foydalanuvchi nice'ni faqat oshira oladi (prioritetni pasaytiradi). Kamaytirish va manfiy qiymat uchun root kerak.
- nice faqat CPU uchun raqobat bo'lganda ta'sir qiladi. Bo'sh mashinada nice 19 jarayon ham to'liq tezlikda ishlaydi.
- Disk I/O uchun alohida asbob: `ionice -c 3 cmd` (idle klass), ta'siri I/O scheduler'ga bog'liq.
- Qattiq chegara kerak bo'lsa nice emas, cgroup limiti (systemd'da `CPUQuota=`, `MemoryMax=`, 11-dars).

## 6. Zombie va orphan

### Zombie

Jarayon tugaganda kernel uning xotirasi va fayllarini bo'shatadi, lekin jarayonlar jadvalidagi yozuvni (PID, exit code) otasi `wait()` bilan o'qib olguncha saqlaydi. Shu oraliqdagi jarayon **zombie**: `ps` da holati `Z`, nomi `<defunct>`.

- Zombie resurs yemaydi (CPU 0, xotira 0), faqat bitta PID va jadval yozuvini band qiladi.
- Uni o'ldirib bo'lmaydi, chunki u allaqachon o'lgan. `kill -9` hech narsa qilmaydi.
- Qisqa muddatli zombie normal holat. Uzoq turgan va soni o'sayotgan zombie'lar ota jarayondagi xato belgisi (bolalarini `wait` qilmayapti). Minglab to'plansa PID'lar tugaydi va yangi jarayon yaratib bo'lmaydi.
- Davosi otada: ota tuzatiladi yoki o'ldiriladi. Ota o'lsa zombie'lar PID 1 ga o'tadi va u ularni darhol yig'ib oladi.

### Orphan

Ota boladan oldin o'lsa, bola **orphan** bo'ladi va kernel uni PID 1 ga (yoki eng yaqin "subreaper" jarayonga, masalan `systemd --user` ga) beradi. Bu xato emas: `nohup` va `setsid` bilan ataylab shunday qilinadi, daemon'lar an'anaviy ravishda shu yo'l bilan terminaldan uzilgan.

PID 1 ning ikkinchi vazifasi shundan: o'ziga o'tgan har bolani `wait` qilib yig'ish. Konteynerda PID 1 sizning dasturingiz bo'lsa va u begona bolalarni yig'masa, zombie'lar to'planadi. `docker run --init` shu muammoni kichik init jarayoni (`tini`) qo'yib yechadi.

## Tuzoqlar

- Birinchi urinishda `kill -9`. Avval `SIGTERM`, kutish, keyin `SIGKILL`.
- Doimiy servisni `nohup ... &` bilan ishga tushirish. Restart yo'q, reboot'dan keyin yo'q, log boshqaruvi yo'q.
- Bash skriptida `trap` yozib, `sleep` yoki uzoq buyruq tufayli u kech ishlashini bilmaslik. `cmd & wait $!` naqshi.
- Skriptda tozalashni faqat oxirgi qatorga yozish. Xato yoki signal bo'lsa u bajarilmaydi, `trap ... EXIT` ishlating.
- Zombie'ni o'ldirishga urinish. Muammo otada.
- `pkill -f` ga keng pattern berish: `pkill -f python` mashinadagi hamma Python jarayonini, shu jumladan tizimnikini o'ldiradi. Avval `pgrep -af` bilan nima mos kelishini ko'ring.
- Parol va token'ni buyruq argumenti sifatida berish: `ps` orqali hammaga ko'rinadi.
- Exit code 137 ni "dastur xatosi" deb o'qish. Bu tashqaridan `SIGKILL`, ko'pincha xotira limiti.
- Konteynerda PID 1 bo'lib ishlaydigan dasturda `SIGTERM` handler yozmaslik: har deploy 10 soniya kutadi va so'rovlar uziladi.
- `nice` ni resurs limiti deb o'ylash. U faqat raqobat paytidagi ulushni o'zgartiradi.

## Manbalar

- https://man7.org/linux/man-pages/man7/signal.7.html – signal(7): ro'yxat, standart amallar (majburiy)
- https://man7.org/linux/man-pages/man1/ps.1.html – ps(1), ustunlar va holat kodlari
- https://man7.org/linux/man-pages/man5/proc.5.html – proc(5)
- https://man7.org/linux/man-pages/man2/fork.2.html – fork(2)
- https://man7.org/linux/man-pages/man2/wait.2.html – wait(2), zombie haqida NOTES bo'limi
- https://www.gnu.org/software/bash/manual/html_node/Job-Control.html – Bash job control
- https://www.gnu.org/software/bash/manual/html_node/Signals.html – Bash signal'larni qanday qayta ishlaydi (trap kechikishi, SIGHUP)
- https://man7.org/linux/man-pages/man7/pid_namespaces.7.html – PID namespace va PID 1 ning signal qoidalari
- Michael Kerrisk, "The Linux Programming Interface", 20–26 va 34-boblar

---

## Vazifalar

Ish papkasi: `linux/09-processes/` (`make new m=linux n=09 name=processes` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptlarni (`task_N.sh`) yoniga saqlang. Aytilmagan bo'lsa VM ichidagi bash'da bajaring.

### A. Jarayon modeli va ko'rish

1. **Process tree.** `pstree -p -s $$` bilan o'z shell'ingizdan PID 1 gacha bo'lgan zanjirni chiqaring: ish mashinasida (terminal emulyatori ichida) va VM'da (`multipass shell` orqali). Zanjirdagi har jarayon nima ekanini bir gapdan izohlang.

2. **fork and exec.** Bash'da `echo $$` ni yozib oling, keyin `sleep 300 &` va `ps -o pid,ppid,cmd -p $!` ni bajaring. Keyin yangi bash ichida (`bash` deb kiring) `echo $$` va `exec sleep 30` ni bajaring: `exec` dan keyin nima bo'ldi, PID o'zgardimi, 30 soniyadan keyin qayerga qaytdingiz? Farqni fork/exec modeli orqali tushuntiring.

3. **ps columns.** Xotira bo'yicha eng katta 5 jarayonni `ps -eo` va `--sort` bilan `pid,ppid,user,stat,ni,rss,etime,cmd` ustunlarida chiqaring. `RSS` va `VSZ` farqini, `etime` nimani bildirishini yozing. `ps aux | grep sshd` va `pgrep -a sshd` natijalarini solishtiring.

4. **Explore /proc.** `sleep 600 &` ni ishga tushirib, uning `/proc/<PID>/` katalogidan quyidagilarni oling: buyruq qatori (o'qiladigan ko'rinishda), joriy katalog, binary yo'li, ochiq fayl deskriptorlari va ular qayerga ishora qilishi, `status` dan `State`, `PPid`, `VmRSS`. Keyin `FOO=secret sleep 600 &` qilib, `environ` dan `FOO` ni toping.

5. **Process states.** `sleep 600` ni foreground'da ishga tushirib `Ctrl+Z` bosing. `ps -o pid,stat,cmd` bilan holatini ko'ring. `bg` dan keyin holat qanday o'zgardi? Ish mashinangizda `ps -eo stat | sort | uniq -c` bilan har holatdagi jarayonlar sonini chiqaring va natijani izohlang.

### B. Job control

6. **jobs, bg, fg.** Uchta `sleep` (300, 400, 500) ni ketma-ket background'da ishga tushiring. `jobs -l` ni oling. Ikkinchisini foreground'ga olib, to'xtatib, background'da davom ettiring. Uchinchisini job raqami orqali o'ldiring. Har qadamdagi `jobs` chiqishini yozing, `+` va `-` belgilari nimani bildirishini izohlang.

7. **SIGHUP on disconnect.** VM'ga birinchi terminaldan kirib `sleep 1000 &` ishga tushiring va PID'ini yozib oling. Terminal oynasini yoping (`exit` emas, oynaning o'zini). Ikkinchi terminaldan jarayon tirikligini tekshiring. Tajribani `exit` bilan chiqib takrorlang. Ikki holat natijasi bir xilmi? `shopt huponexit` qiymatini tekshirib, natijani izohlang.

8. **nohup and disown.** 7-vazifani uch variantda takrorlang: `nohup sleep 1000 &`; `sleep 1000 &` dan keyin `disown`; `setsid sleep 1000`. Har birida terminal oynasini yopgandan keyin jarayon tirikmi, uning PPID'i nima bo'ldi, `nohup.out` qayerda paydo bo'ldi? Oxirida hammasini `pkill` bilan tozalang.

9. **Reparenting.** `bash -c 'sleep 500 & echo child=$!; sleep 5'` ni ishga tushiring. 5 soniya ichida va undan keyin `ps -o pid,ppid,cmd -p <child>` ni oling. Yangi ota kim? Xuddi shu tajribani ish mashinasidagi grafik terminalda takrorlang: u yerda ota PID 1 emas bo'lishi mumkin, kimligini va nima uchunligini aniqlang.

### C. Signal'lar

10. **Signal table.** `kill -l` chiqishidan `HUP`, `INT`, `QUIT`, `KILL`, `TERM`, `CONT`, `STOP`, `TSTP`, `USR1` raqamlarini toping. `man 7 signal` dan har birining standart amalini yozing. Qaysi ikkitasini ushlab bo'lmaydi va nima uchun shunday loyihalangan deb o'ylaysiz?

11. **Exit codes.** `sleep 300` ni foreground'da ishga tushirib, uch xil usul bilan to'xtating va har safar `echo $?` ni yozing: `Ctrl+C`; boshqa terminaldan `kill`; boshqa terminaldan `kill -9`. Raqamlarni formulasi bilan izohlang.

12. **STOP and CONT.** Ish mashinasida yoki VM'da `stress-ng --cpu 1 --timeout 300s` (yoki `yes > /dev/null`) ishga tushiring. `top` da CPU'ni ko'ring, keyin jarayonga `SIGSTOP` yuboring: holat va CPU qanday o'zgardi? `SIGCONT` bilan davom ettiring. Bu juftlik production'da qanday vaziyatda foydali bo'lishi mumkin?

13. **trap script.** `task_13.sh` yozing: vaqtinchalik fayl yaratadi (`mktemp`), har soniyada unga qator qo'shadi, `SIGINT` va `SIGTERM` da "signal oldim" deb chop etib tugaydi, har qanday tugashda (`EXIT`) vaqtinchalik faylni o'chiradi. Uch usulda tekshiring: `Ctrl+C`, `kill`, `kill -9`. Qaysi holatda fayl qolib ketdi va nima uchun?

14. **Delayed trap.** `task_14.sh` yozing: `trap 'echo got TERM; exit 143' TERM`, keyin `sleep 60`. Skriptni ishga tushirib, boshqa terminaldan skript PID'iga `SIGTERM` yuboring va handler qachon ishlaganini `date` bilan o'lchang. Keyin skriptni `sleep 60 & wait $!` naqshi bilan tuzating va qayta o'lchang. Tuzatilgan variantda `sleep` jarayonining o'zi nima bo'ldi, uni ham to'xtatish uchun nima qo'shish kerak?

15. **pkill safely.** Uchta jarayon ishga tushiring: `sleep 1001`, `sleep 1002`, `bash -c 'sleep 1003'`. Faqat `sleep 1002` ni `pkill` bilan o'ldiring, lekin avval `pgrep -af` bilan patterningiz aynan nimaga mos kelishini ko'rsating. `pkill sleep`, `pkill -f 1002` va `pkill -x` farqini izohlang.

16. **PID 1 ignores signals.** Ish mashinasida `docker run -d --name pid1 ubuntu:24.04 sleep 600` ni ishga tushiring. `docker exec pid1 ps -ef` (kerak bo'lsa `cat /proc/1/cmdline`) bilan PID 1 ni ko'ring. `time docker stop pid1` qancha vaqt oldi va `docker inspect` dagi exit code nima? Xuddi shuni `--init` flag'i bilan takrorlang va farqni PID 1 qoidasi orqali tushuntiring. Konteynerlarni o'chiring.

### D. Prioritet, zombie

17. **nice under contention.** VM'da (yadrolar soni N bo'lsin) bir vaqtda `stress-ng --cpu N --timeout 60s` va `nice -n 19 stress-ng --cpu N --timeout 60s` ni ishga tushiring. `top` da ikki guruhning `NI` va `%CPU` ustunlarini solishtiring. Keyin faqat nice 19 variantni yolg'iz ishga tushiring: u qancha CPU oldi? Xulosa yozing.

18. **renice limits.** Oddiy foydalanuvchi sifatida ishlab turgan jarayoningizga `renice -n 10`, keyin `renice -n 5` qilib ko'ring. Ikkinchi buyruq xatosini yozing va sababini izohlang. `sudo` bilan manfiy qiymat qo'ying.

19. **Make a zombie.** `(sleep 1 & exec sleep 120) &` ni bajaring. 2 soniyadan keyin `ps -eo pid,ppid,stat,cmd | grep -E 'defunct|sleep 120'` ni oling. Zombie kim, otasi kim, bu konstruksiya nima uchun zombie hosil qilishini (kim `wait` qilmayapti) tushuntiring. Zombie'ga `kill -9` yuboring: nima o'zgardi? Uni yo'qotishning to'g'ri usulini qo'llang va natijani ko'rsating.

### E. Yakuniy

20. **Graceful worker.** `task_20.sh` yozing: "worker" skript. U `worker.pid` fayliga o'z PID'ini yozadi, har 2 soniyada `worker.log` ga vaqt belgisi bilan qator qo'shadi. `SIGTERM`/`SIGINT` da joriy iteratsiyani tugatib, logga "shutting down" yozib, PID faylni o'chirib 0 bilan chiqadi. `SIGHUP` da logga "reloading config" yozib ishlashda davom etadi. `SIGUSR1` da bajarilgan iteratsiyalar sonini logga yozadi. Signal'ga reaksiya 1 soniyadan oshmasin (14-vazifadagi naqsh). `shellcheck` toza bo'lsin. README'da har signal uchun sinov buyrug'i va log parchasini ko'rsating, va bu skript nima uchun baribir systemd unit o'rnini bosmasligini 3 gapda yozing.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi.
2. VM'da va ish mashinasida test jarayonlari qolmagan (`pgrep -a sleep`, `pgrep -a stress-ng` bo'sh), `pid1` konteynerlari o'chirilgan.
3. README'da har vazifa uchun buyruq, natija va izoh bor.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Shell'da buyruq yozganingizda fork va exec qaysi tartibda ishlaydi va bola nimalarni meros oladi?
- `SIGTERM` va `SIGKILL` farqi nima, nima uchun avval birinchisi yuboriladi?
- Exit code 137 va 143 nimani bildiradi?
- SSH uzilganda background jarayon nima uchun o'ladi va uni saqlab qolishning uch usuli qanday?
- Zombie nima, nima uchun uni `kill -9` bilan o'ldirib bo'lmaydi, qanday yo'qotiladi?
- Orphan jarayonni kim asrab oladi va PID 1 ning bu yerdagi vazifasi nima?
- Bash'da `trap` handler nima uchun kech ishlashi mumkin?
- `nice -n 19` jarayon bo'sh mashinada qancha CPU oladi va nima uchun?
- Konteynerda `docker stop` nima uchun ba'zan 10 soniya kutadi?
