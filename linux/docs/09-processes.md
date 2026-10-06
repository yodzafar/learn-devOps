# 9-dars: Jarayonlarni boshqarish

Maqsad: Linux'da jarayon (process) qanday tug'ilishi, yashashi va o'lishini noldan tushunish. Jarayon modeli (`fork` va `execve`, PID va PPID), holatlar, signal'lar, job control, prioritet (`nice`), zombie va orphan keyingi hamma narsaning asosi: systemd servisni qanday to'xtatishi (11-dars), `docker stop` nima uchun 10 soniya kutishi, Kubernetes'dagi graceful shutdown, CI'da osilib qolgan job. 8-darsda "qaysi jarayon resurs yeyapti" degan savolga javob topdingiz, bu darsda o'sha jarayon bilan nima qilishni o'rganasiz: to'xtatish, davom ettirish, tartibli tugatish, prioritetini o'zgartirish. Node'da `process.on('SIGTERM')`, `child_process.spawn` va `process.kill` orqali shu mexanizmlarning ustki qatlamini ishlatgansiz, endi ularning ostidagi kernel qismini ko'rasiz.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A, B guruh vazifalari, ikkinchi kun 4-bo'lim va C guruhi, uchinchi kun 5–6 bo'limlar, "Birga bajaramiz", D guruhi va 20-vazifa. Diqqatni quyidagilarga qarating: fork/exec modeli va undan kelib chiqadigan zombie va orphan, `SIGTERM` va `SIGKILL` farqi, bash'da `trap` ning kechikishi, terminal yopilganda jarayonlar bilan nima bo'lishi, PID 1 ning maxsus roli.

Qanday o'qish kerak: har bo'limdagi misolni `lab` VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. PID'lar har safar boshqa bo'ladi, darsda ular `<PID>` kabi belgilangan; `ps` ustunlarining kengligi ham biroz farq qilishi mumkin. Ko'p tajribalar ikki terminal talab qiladi: birida jarayon ishlaydi, ikkinchisidan unga qaraysiz yoki signal yuborasiz.

## Laboratoriya

Hamma narsa `SETUP.md` dagi `lab` VM (Multipass, Ubuntu 24.04) ichida bajariladi, chunki `/proc`, GNU `ps`, `pstree` va bash'ning job control'i faqat u yerda ikkala mashinada bir xil. Yagona istisno 16-vazifa: PID 1 tajribasi host'dagi bir martalik Docker konteynerida.

| Joy | Nima bajariladi |
|-----|-----------------|
| `lab` VM (`multipass shell lab`) | barcha misollar va 1–15, 17–20 vazifalar |
| Host (Zorin yoki macOS) | `make new`, `make check`, `git`, 16-vazifadagi `docker run`, ixtiyoriy "host'da ham qarang" qismlari |
| Konteyner | 16-vazifa (`docker run ... ubuntu:24.04`) |

- **Ikki terminal**: host'da ikkita terminal oynasi oching va har birida `multipass shell lab` qiling. Har biri alohida SSH sessiyasi va alohida bash, `tty` buyrug'i birida `/dev/pts/0`, ikkinchisida `/dev/pts/1` ko'rsatadi.
- **Shell**: VM'da `bash`. Host'da (ikkala mashinada ham) shell `zsh` bo'lishi mumkin, uning job control va `disown` xatti-harakati bash'dan farq qiladi. Shuning uchun B va C guruh vazifalari faqat VM'dagi bash'da bajariladi.
- **Paketlar (VM ichida)**: `pstree` va `killall` `psmisc` paketida, `stress-ng` alohida paket (8-darsda o'rnatgan bo'lsangiz bor). Tekshirish va o'rnatish:

```
ubuntu@lab:~$ type pstree stress-ng shellcheck
ubuntu@lab:~$ sudo apt update && sudo apt install -y psmisc stress-ng shellcheck
```

`shellcheck` (shell skriptlardagi xatolarni topadigan statik tekshiruvchi) 20-vazifa uchun; uni host'da `make check` ham ishlatadi. Bu darsda `sudo` faqat shu o'rnatish va 18-vazifaning oxirgi qismi uchun kerak.

- **Oldingi holat**: dars oldingi darslar holatiga tayanmaydi. Mashinani almashtirsangiz, ikkinchi mashinadagi `lab` VM'da yuqoridagi `apt install` ni bir marta bajaring, boshqa tiklash yo'q. Skriptlar (`task_13.sh`, `task_14.sh`, `task_20.sh`) repo'da yashaydi; ularni VM'ga `multipass transfer linux/09-processes/task_13.sh lab:` bilan ko'chirasiz yoki VM'da yozib, `multipass transfer lab:task_13.sh linux/09-processes/` bilan qaytarasiz.
- **Tozalash**: dars oxirida VM'da `pgrep -a sleep` va `pgrep -a stress-ng` bo'sh bo'lsin, host'da `docker ps -a` da `pid1` konteyneri qolmasin.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host'ning o'zi Linux, shuning uchun `ps`, `pstree`, `/proc` host'da ham ishlaydi va ixtiyoriy "host'da qarang" qismlarini bajarish mumkin. Grafik terminaldagi jarayon zanjiri VM'dagidan boshqa (9-vazifa). Docker Engine host kernel'ida ishlaydi: konteyner jarayoni host'dagi `ps -ef` da ham ko'rinadi (boshqa PID bilan). |
| macOS (uy) | Host'dagi `ps` BSD varianti: `ps aux` va `ps -ef` ishlaydi, lekin `--forest`, `--sort`, `-o cmd` yo'q (`-o command` bor). `/proc` yo'q, `pstree` standart o'rnatilmagan (ixtiyoriy: `brew install pstree`, `arm64`). `pgrep -a` boshqa ma'noda (ajdodlarni ham qo'shish), ro'yxat uchun `pgrep -l`. Signal raqamlari ham boshqa (`SIGUSR1` 30, `SIGSTOP` 17, `SIGCONT` 19), shuning uchun har doim nom yoziladi. Docker Desktop konteynerlarni yashirin Linux VM ichida ishlatadi: konteyner jarayonlari Mac'dagi `ps` da ko'rinmaydi, lekin `docker exec`, `docker stop`, `docker inspect` bir xil ishlaydi, 16-vazifa o'zgarishsiz bajariladi. |

---

## 1. Jarayon modeli

### Dastur va jarayon

Dastur bu diskdagi fayl (masalan `/usr/bin/sleep`), jarayon esa uning ishlayotgan nusxasi. Bitta dasturdan bir vaqtda o'nta jarayon ishlashi mumkin. Kernel har jarayon uchun quyidagilarni saqlaydi:

| Narsa | Izoh |
|-------|------|
| **PID** | process ID, kernel bergan raqam, jarayon tirik ekan o'zgarmaydi |
| **PPID** | parent PID, shu jarayonni yaratgan ota jarayonning raqami |
| Virtual xotira | kod, ma'lumot, stack; boshqa jarayonlar uni ko'rmaydi |
| Fayl deskriptorlari | ochiq fayllar, socket'lar, pipe'lar jadvali (`0` stdin, `1` stdout, `2` stderr, 1-dars) |
| Environment | `KEY=value` juftliklari (5-dars) |
| Joriy katalog, UID va GID | nisbiy yo'llar qayerdan hisoblanadi; jarayon kim nomidan ishlaydi (10-dars) |
| Signal sozlamalari | qaysi signal uchun handler bor, qaysi biri e'tiborsiz (4-bo'lim) |

### Mexanizm: fork va execve

Linux'da "yangi dastur ishga tushirish" degan bitta amal yo'q. U ikki system call'dan (1-dars: dastur kernel'dan xizmat so'raydigan eshik) yig'iladi:

1. `fork()`: ota jarayon o'zining nusxasini yaratadi. Bola yangi PID oladi, qolgan hamma narsa nusxalanadi: xotira, environment, ochiq fayl deskriptorlari, joriy katalog, UID. Xotira aslida darhol ko'chirilmaydi: kernel sahifalarni ikkala jarayonga umumiy qilib qo'yadi va faqat kimdir yozganda nusxa oladi (**copy-on-write**), shuning uchun `fork` tez.
2. `execve()`: bola o'z xotirasini boshqa dastur bilan almashtiradi. PID, ochiq fayl deskriptorlari, joriy katalog va environment saqlanadi, kod va ma'lumot yangi dasturniki bo'ladi. `execve` muvaffaqiyatli bo'lsa qaytmaydi: eski dastur endi yo'q.
3. `wait()`: ota bolaning tugashini kutadi va uning exit code'ini oladi.

Shell'da `ls` yozganingizda aynan shu uch qadam bo'ladi: bash `fork` qiladi, bola `ls` ni `execve` qiladi, bash `wait` bilan kutadi va exit code'ni `$?` ga yozadi. 5-darsdagi "environment bolaga meros bo'ladi, bolaning o'zgartirishi otaga qaytmaydi" qoidasi shu mexanizmning natijasi: bola nusxa bilan ishlaydi.

Node'da `child_process.spawn('ls', ['-l'])` xuddi shu juftlikni bajaradi (libuv ichida `fork` va `execvp`), `child.on('exit', (code, signal) => ...)` esa `wait` ning natijasi. Diqqat: Node'dagi `child_process.fork()` Unix'ning `fork` i emas, u yangi Node jarayonini IPC kanali bilan `spawn` qiladi, nomi chalg'itadi.

### Misol: ota va bola

```
ubuntu@lab:~$ echo $$ $PPID
<bash> <sshd>
ubuntu@lab:~$ sleep 100 &
[1] <PID>
ubuntu@lab:~$ ps -o pid,ppid,stat,cmd
    PID    PPID STAT CMD
 <bash>  <sshd> Ss   -bash
  <PID>  <bash> S    sleep 100
   <ps>  <bash> R+   ps -o pid,ppid,stat,cmd
```

`$$` shu shell'ning PID'i, `$PPID` uning otasi (VM'ga SSH orqali kirganingiz uchun bu `sshd` jarayoni). Argumentsiz `ps` faqat shu terminaldagi jarayonlarni ko'rsatadi. Birinchi qator shell'ning o'zi: nomidagi `-` belgisi uning login shell ekanini bildiradi (5-dars). Ikkinchi qator `sleep`: uning `PPID` ustuni bash'ning PID'iga teng, ya'ni bash uni `fork` qilgan. Uchinchi qator `ps` ning o'zi: u ham bash'ning bolasi va ro'yxatni chiqarayotgan paytda ishlayotgani uchun holati `R`. `STAT` ustuni keyingi kichik bo'limda.

Har jarayonning otasi borligi uchun jarayonlar daraxt hosil qiladi. Ildizi PID 1: kernel boot oxirida ishga tushiradigan birinchi user space jarayoni, Ubuntu'da `systemd` (1-dars). Daraxtni `pstree -p` (PID'lar bilan) yoki `ps -ef --forest` ko'rsatadi; `pstree -p -s <PID>` bitta jarayonning PID 1 gacha bo'lgan ajdodlarini chiqaradi.

### exec builtin

Bash'ning `exec` builtin'i `fork` siz to'g'ridan-to'g'ri `execve` qiladi: shell o'zini berilgan dastur bilan almashtiradi. Bu konteyner entrypoint skriptlarining oxirgi qatorida ishlatiladi (`exec node server.js`): skript tayyorgarlik qiladi, keyin o'z o'rnini dasturga beradi va dastur o'sha PID bilan ishlaydi. Nima uchun muhimligi 4-bo'limda ("PID 1 va konteynerlar").

### Jarayon holatlari

Jarayon har lahzada bitta holatda bo'ladi. `ps` ning `STAT` (yoki `S`) ustunidagi birinchi harf:

| Harf | Holat | Izoh |
|------|-------|------|
| `R` | running/runnable | CPU'da ishlayapti yoki CPU navbatida turibdi |
| `S` | interruptible sleep | hodisa kutyapti (tarmoq, timer, klaviatura). Ko'pchilik jarayon ko'p vaqt shu holatda, signal kelsa uyg'onadi |
| `D` | uninterruptible sleep | odatda disk I/O tugashini kutyapti. Kutish tugamaguncha signalga javob bermaydi, load average'ga kiradi (8-dars) |
| `T` | stopped | `SIGSTOP` yoki `SIGTSTP` bilan to'xtatilgan, `SIGCONT` kelguncha CPU olmaydi |
| `Z` | zombie | tugagan, lekin otasi hali exit code'ni `wait` bilan o'qimagan (6-bo'lim) |
| `I` | idle | bo'sh turgan kernel thread |

Birinchi harfdan keyingi belgilar qo'shimcha ma'lumot: `s` session leader, `+` foreground guruhida (3-bo'lim), `l` ko'p thread'li, `<` yuqori prioritet, `N` past prioritet (5-bo'lim).

```
ubuntu@lab:~$ ps -o pid,ppid,stat,comm -p 1,2,$$
    PID    PPID STAT COMMAND
      1       0 Ss   systemd
      2       0 S    kthreadd
 <bash>  <sshd> Ss   bash
```

PID 1 (`systemd`) va PID 2 (`kthreadd`) ning otasi `0`, ya'ni ularni boshqa jarayon emas, kernel'ning o'zi yaratgan. `systemd` uxlab turibdi (`S`) va session leader (`s`): hodisa kelmaguncha u CPU ishlatmaydi. `kthreadd` kernel thread'larining otasi: `ps -ef` da kvadrat qavsdagi nomlar (`[kworker/0:1]`, `[kthreadd]`) kernel ichida ishlaydigan thread'lar, ularda user space kodi yo'q va ularni siz boshqarmaysiz. Shell'ingiz ham `Ss`: u `ps` tugashini `wait` bilan kutib uxlayapti.

### Real ishda qachon kerak

- "Servis environment o'zgaruvchisini ko'rmayapti": o'zgaruvchi otada (masalan systemd unit'da) berilmagan, bola faqat otasidagini meros oladi.
- Dockerfile entrypoint skripti oxirida `exec` yo'qligi: dastur shell'ning bolasi bo'lib qoladi va signal unga yetmaydi.
- `ps` da `D` holatida turgan ko'p jarayon: muammo CPU'da emas, disk yoki tarmoq fayl tizimida.
- `T` holatidagi "osilib qolgan" jarayon: kimdir `Ctrl+Z` bosgan va unutgan.

### Nima uchun shunday

`fork` va `exec` ajratilgani uchun ikkalasining orasida bola o'zini sozlashi mumkin: shell `ls > out.txt` da avval `fork` qiladi, bolada `1`-deskriptorni faylga ulaydi, keyin `execve` qiladi. `ls` yo'naltirish haqida hech narsa bilmaydi, u shunchaki stdout'ga yozadi. Pipe, environment o'zgartirish, UID almashtirish, `nice` ham xuddi shu oraliqda qilinadi. Muqobil yondashuv (Windows'dagi `CreateProcess`) bitta chaqiruvga o'nlab parametr beradi. Unix dizayni 1970-yillardan qolgan va soddaligi uchun saqlangan; zamonaviy Linux'da glibc'ning `fork` funksiyasi ichkarida `clone` system call'ini chaqiradi, konteynerlar ham shu `clone` ning namespace flag'lari bilan yaratiladi (docker moduli).

## 2. Jarayonlarni ko'rish

### ps

`ps` jarayonlar ro'yxatining bir lahzalik suratini chiqaradi (`top` jonli ko'rsatadi, 8-dars). Tarixiy sababga ko'ra uning ikki sintaksisi bor va ikkalasi ham ishlatiladi:

| Buyruq | Uslub | Nima beradi |
|--------|-------|-------------|
| `ps aux` | BSD (defissiz) | hamma jarayon, `%CPU`, `%MEM`, `VSZ`, `RSS`, `STAT` bilan |
| `ps -ef` | UNIX | hamma jarayon, `PPID` bilan |
| `ps -ef --forest` | | daraxt ko'rinishida |
| `ps -p <PID> -o pid,ppid,user,stat,etime,cmd` | | bitta jarayon, tanlangan ustunlar |
| `ps -eo pid,ppid,stat,ni,%cpu,%mem,cmd --sort=-%cpu \| head` | | hamma jarayon, CPU bo'yicha kamayish tartibida |
| `ps -u ubuntu` | | bitta foydalanuvchining jarayonlari |
| `ps -eLf` | | thread'lar bilan (`LWP` ustuni) |

`-e` hamma jarayon, `-o` ustunlar ro'yxati, `--sort=-ustun` saralash (minus kamayish tartibi), `-p` PID bo'yicha tanlash.

```
ubuntu@lab:~$ ps aux | head -2
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.<N> <N> <N> ?        Ss   <vaqt>   0:0<N> /sbin/init
```

Maydonlar chapdan o'ngga: `USER` jarayon egasi; `PID`; `%CPU` jarayon butun umri davomida ishlatgan CPU vaqtining umriga nisbati (hozirgi lahza emas, shuning uchun `top` dagi raqamdan farq qiladi); `%MEM` fizik xotiradagi ulushi; `VSZ` virtual xotira hajmi, kB (jarayon so'ragan manzillar, ko'pi hali ishlatilmagan); `RSS` hozir fizik xotirada turgan qismi, kB (8-dars); `TTY` bog'langan terminal, `?` terminalsiz (daemon); `STAT` holat; `START` qachon ishga tushgan; `TIME` jami ishlatgan CPU vaqti; `COMMAND` buyruq satri. `-o` bilan so'raladigan `etime` ustuni jarayon ishga tushganidan beri o'tgan devor soati vaqti, `ni` nice qiymati.

### pgrep

Nom bo'yicha qidirish uchun `ps aux | grep <nom>` o'rniga `pgrep`: u jarayonlar ro'yxatini o'zi o'qiydi va o'zini natijaga qo'shmaydi.

```
ubuntu@lab:~$ pgrep -a cron
<PID> /usr/sbin/cron -f -P
ubuntu@lab:~$ pgrep -u ubuntu -l
<PID> systemd
<PID> (sd-pam)
<PID> sshd
<PID> bash
```

`-a` PID yoniga to'liq buyruq satrini chiqaradi, `-l` faqat nomni, `-u` egasi bo'yicha filtrlaydi. Standart holatda pattern faqat jarayon nomiga (`comm`, 15 belgigacha) solishtiriladi; `-f` to'liq buyruq satriga, `-x` aniq to'liq moslikka. `pkill` xuddi shu tanlash qoidalari bilan signal yuboradi (4-bo'lim).

### /proc

`/proc` diskdagi katalog emas, kernel ma'lumotlarining fayl ko'rinishi (1-dars). `ps`, `top`, `pgrep` hammasi shu yerdan o'qiydi. Har jarayon uchun `/proc/<PID>/`:

| Yo'l | Mazmuni |
|------|---------|
| `cmdline` | buyruq satri, argumentlar NUL bayt bilan ajratilgan (`tr '\0' ' '` bilan o'qing) |
| `environ` | jarayon ishga tushgan paytdagi environment (ham NUL bilan), faqat egasi va root o'qiydi |
| `status` | holat, PPID, UID/GID, `VmRSS`, thread'lar soni, signal maskalari |
| `cwd`, `exe` | joriy katalog va bajarilayotgan faylga symlink |
| `fd/` | ochiq fayl deskriptorlari |
| `limits` | resurs limitlari (ochiq fayllar soni va boshqalar) |

`/proc/self` har doim o'qiyotgan jarayonning o'ziga ishora qiladi. 1-darsda `comm`, `exe`, `cmdline`, `fd` ni ko'rgansiz, bu yerda yangisi `limits` va `status` dagi signal qatorlari:

```
ubuntu@lab:~$ grep -E 'Limit|open files|processes' /proc/$$/limits
Limit                     Soft Limit           Hard Limit           Units
Max processes             <N>                  <N>                  processes
Max open files            1024                 <N>                  files
ubuntu@lab:~$ grep -E '^Sig(Ign|Cgt)' /proc/$$/status
SigIgn:	<mask>
SigCgt:	<mask>
```

`limits` da har resurs uchun ikki chegara: `Soft Limit` hozir amal qiladigani, `Hard Limit` jarayon o'zi ko'tara oladigan shift. `Max open files 1024` bitta jarayon bir vaqtda ocha oladigan deskriptorlar soni: ko'p ulanishli Node serverdagi `EMFILE: too many open files` xatosi shu raqamga urilganini bildiradi (systemd'da `LimitNOFILE=`, 11-dars). `SigIgn` va `SigCgt` o'n oltilik bit maskalar: `N`-signal uchun `N-1`-bit yoniq bo'lsa, jarayon uni mos ravishda e'tiborsiz qoldiradi yoki o'z handler'i bilan ushlaydi. Dastur manbasini o'qimasdan "bu jarayon `SIGTERM` ni ushlaydimi" degan savolga shu yerdan javob olinadi (3-bo'limda `nohup` misolida ishlatamiz).

**Tuzoq: buyruq satridagi secret.** `environ` ni faqat jarayon egasi va root o'qiy oladi, `cmdline` esa hammaga ochiq. Parolni argument sifatida berish (`mysql -pSECRET`) uni `ps aux` orqali mashinadagi har foydalanuvchiga ko'rsatadi.

### Real ishda qachon kerak

- Ishlab turgan servisning haqiqiy environment'ini, qaysi binary'dan ishga tushganini va qaysi faylga log yozayotganini bilish: konfiguratsiya fayliga ishonish o'rniga `/proc/<PID>/environ`, `exe`, `fd/`.
- "Diskda joy yo'q, lekin fayl o'chirilgan": o'chirilgan faylni hali ochiq ushlab turgan jarayon `/proc/<PID>/fd` da `(deleted)` belgisi bilan ko'rinadi.
- Skriptda "jarayon tirikmi" tekshiruvi: `pgrep -x <nom>` ning exit code'i (topilsa `0`).
- Deploy'dan keyin eski versiya hali ishlayaptimi: `ps -o pid,etime,cmd -p <PID>` dagi `etime`.

### Nima uchun shunday

`ps` ning ikki sintaksisi 1980-yillardagi ikki Unix oilasidan (AT&T System V va BSD) qolgan; Linux'dagi `procps` ikkalasini qo'llaydi, shuning uchun `ps aux` va `ps -ef` bir xil ro'yxatni boshqa ustunlar bilan beradi. Jarayon ma'lumotining fayl ko'rinishida berilishi (`/proc`) Unix'ning "hamma narsa fayl" g'oyasidan: yangi asbob yozish uchun maxsus API emas, `cat` va `grep` yetadi. macOS'da `/proc` yo'q, u yerda `ps` kernel'dan `sysctl` orqali so'raydi va oddiy foydalanuvchi boshqa jarayonning ichini bunday oson ko'ra olmaydi.

## 3. Job control: foreground va background

### Mexanizm: session, process group, terminal

Terminalga kirganingizda uchta tushuncha paydo bo'ladi. **Session** bu bitta login'ga tegishli jarayonlar to'plami, uni boshlagan shell **session leader** deyiladi. **Process group** bu birga boshqariladigan jarayonlar guruhi: shell har pipeline'ni (`a | b | c`) alohida guruhga joylaydi va uni **job** deb ataydi. Terminal har lahzada bitta guruhni **foreground** deb biladi: faqat u klaviaturadan o'qiy oladi, qolganlari **background**.

`Ctrl+C` bosganingizda signalni shell emas, kernel'ning terminal drayveri yuboradi: `SIGINT` foreground guruhdagi hamma jarayonga boradi. Shuning uchun `Ctrl+C` butun pipeline'ni to'xtatadi, shell'ning o'zi esa tirik qoladi (u foreground guruhda emas).

```
ubuntu@lab:~$ sleep 300 | cat &
[1] <B>
ubuntu@lab:~$ ps -o pid,pgid,sid,tpgid,stat,cmd
    PID    PGID     SID   TPGID STAT CMD
 <bash>  <bash>  <bash>    <ps> Ss   -bash
    <A>     <A>  <bash>    <ps> S    sleep 300
    <B>     <A>  <bash>    <ps> S    cat
   <ps>    <ps>  <bash>    <ps> R+   ps -o pid,pgid,sid,tpgid,stat,cmd
```

`[1] <B>`: job raqami va pipeline'dagi oxirgi jarayonning PID'i (`$!` ham shu). `PGID` process group raqami: `sleep` va `cat` da bir xil va pipeline'dagi birinchi jarayonning PID'iga teng, ya'ni ular bitta job. `SID` session raqami: hamma qatorda bash'ning PID'i, chunki bash session leader. `TPGID` terminal hozir foreground deb bilgan guruh: bu `ps` ning guruhi, shuning uchun faqat `ps` ning `STAT` ida `+` bor. Tozalash: `kill %1`.

### Job'larni boshqarish

| Amal | Natija |
|------|--------|
| `cmd &` | background'da ishga tushirish, shell `[1] <PID>` chiqaradi |
| `Ctrl+Z` | foreground job'ga `SIGTSTP`: to'xtatib qo'yadi (holat `T`) |
| `jobs -l` | shu shell'ning job'lari, PID bilan |
| `bg %1` | to'xtatilgan job'ni background'da davom ettirish (`SIGCONT`) |
| `fg %1` | job'ni foreground'ga qaytarish |
| `kill %1` | job'ga signal yuborish |
| `wait` | barcha background job'lar tugashini kutish |
| `$!` | oxirgi background jarayonning PID'i |

```
ubuntu@lab:~$ sleep 200
^Z
[1]+  Stopped                 sleep 200
ubuntu@lab:~$ bg %1
[1]+ sleep 200 &
ubuntu@lab:~$ jobs -l
[1]+ <PID> Running                 sleep 200 &
ubuntu@lab:~$ kill %1
ubuntu@lab:~$ jobs
[1]+  Terminated              sleep 200
```

`^Z` bu `Ctrl+Z`: terminal drayveri `SIGTSTP` yubordi, `sleep` to'xtadi va shell prompt'ni qaytardi. `bg %1` unga `SIGCONT` yuborib background'da davom ettirdi (qator oxiridagi `&` shuni bildiradi). `jobs -l` da job raqami, PID, holat va buyruq. `kill %1` job'ga `SIGTERM` yubordi, `Terminated` xabari keyingi buyruqda chiqdi. Job raqamlari (`%1`) faqat shu shell ichida ma'noga ega, PID esa butun tizimda.

### Terminal yopilganda nima bo'ladi

SSH uzilsa yoki terminal oynasi yopilsa, kernel session leader'ga (shell'ga) `SIGHUP` ("hangup", aloqa uzildi) yuboradi. Bash uni olgach o'zining barcha job'lariga ham `SIGHUP` yuboradi, standart reaksiya esa o'lish. Uzoq ishlaydigan buyruq shuning uchun SSH uzilganda yo'qoladi. Himoyalanish usullari:

| Usul | Nima qiladi | Qachon |
|------|-------------|--------|
| `nohup cmd &` | `SIGHUP` ni e'tiborsiz qilib ishga tushiradi; chiqish terminal bo'lsa `nohup.out` ga yo'naltiradi | oldindan bilganingizda |
| `disown %1` | job'ni shell jadvalidan o'chiradi, shell unga `SIGHUP` yubormaydi | allaqachon ishga tushirib qo'yganingizda |
| `disown -h %1` | jadvalda qoldiradi, faqat `SIGHUP` yubormaslikni belgilaydi | |
| `setsid cmd` | yangi session'da ishga tushiradi, terminaldan butunlay uziladi | |
| `tmux` / `screen` | terminalning o'zi serverda yashaydi, qayta ulanasiz | interaktiv uzoq ish |
| systemd unit yoki `systemd-run` | to'g'ri yechim: log, restart, limitlar bilan | har qanday doimiy servis |

`nohup` ning ichida sehr yo'q: u `SIGHUP` ni "e'tiborsiz" qilib qo'yadi va berilgan buyruqni `execve` qiladi, e'tiborsiz qilingan signal esa `execve` dan keyin ham e'tiborsiz qoladi. Buni 2-bo'limdagi maskada ko'rish mumkin:

```
ubuntu@lab:~$ nohup sleep 200 &
[1] <PID>
nohup: ignoring input and appending output to 'nohup.out'
ubuntu@lab:~$ grep SigIgn /proc/$!/status
SigIgn:	0000000000000001
ubuntu@lab:~$ kill %1
```

`nohup` xabari: stdin uzildi, stdout joriy katalogdagi `nohup.out` ga ulandi. `SigIgn` maskasida eng kichik bit yoniq: 1-signal, ya'ni `SIGHUP` e'tiborsiz. Oddiy `sleep 200 &` da bu qiymat nollardan iborat bo'lardi.

**Tuzoq: `nohup` production servis uchun emas.** `nohup node app.js &` jarayon yiqilsa qayta ko'tarmaydi, reboot'dan keyin ishga tushmaydi, loglari `nohup.out` da cheksiz o'sadi. Doimiy ishlaydigan narsa systemd unit bo'lishi kerak (11-dars); `pm2` Node dunyosida xuddi shu bo'shliqni to'ldiradi.

**Tuzoq: `disown` dan keyin ham jarayon o'lishi mumkin.** Jarayon yopilgan terminalga yozmoqchi bo'lsa, yozish xato beradi. Chiqishni faylga yo'naltiring: `cmd > out.log 2>&1 &`.

### Real ishda qachon kerak

- Serverda uzoq buyruq (backup, migratsiya) boshladingiz va SSH uzilishidan qo'rqasiz: `tmux` ichida ishga tushiring yoki `systemd-run` ishlating.
- Foreground'da boshlab qo'ygan uzoq buyruqni terminalni bo'shatish uchun `Ctrl+Z`, `bg`, kerak bo'lsa `disown`.
- Skriptda bir nechta ishni parallel boshlab hammasini kutish: `cmd1 & cmd2 & wait`.

### Nima uchun shunday

Job control 1980-yillarda bitta fizik terminalda bir nechta ish bilan shug'ullanish uchun qo'shilgan: oyna va tab'lar yo'q edi. `SIGHUP` modem liniyasi uzilganini bildirardi va "foydalanuvchi ketdi, uning jarayonlarini tozala" degan mantiq o'shandan qolgan. Bugun bu mantiq SSH sessiyalariga xizmat qiladi, uzoq yashaydigan ishlar esa terminalga umuman bog'lanmasligi kerak: ularni systemd boshqaradi.

## 4. Signal'lar

### Mexanizm

Signal bu jarayonga kernel orqali yuboriladigan asinxron xabar: faqat raqam, ichida ma'lumot yo'q. Yuboruvchi boshqa jarayon (`kill` system call'i), terminal drayveri (`Ctrl+C`) yoki kernel'ning o'zi (noto'g'ri xotira murojaati, bola tugashi) bo'lishi mumkin. Kernel signalni jarayonning "kutilayotgan signallar" ro'yxatiga yozadi va jarayon keyingi safar kernel'dan user space'ga qaytayotganda uni yetkazadi. Jarayon har signal uchun uch narsadan birini tanlagan bo'ladi:

- **standart amal** (default action): ko'p signal uchun o'lim;
- **handler**: jarayonning o'z funksiyasi, signal kelganda oddiy kod to'xtatilib shu funksiya chaqiriladi;
- **e'tiborsiz qoldirish** (ignore).

Ikki signal bundan mustasno: `SIGKILL` va `SIGSTOP` ni ushlab ham, e'tiborsiz qoldirib ham bo'lmaydi, ularni kernel o'zi bajaradi. Signalni faqat jarayon egasi yoki root yubora oladi.

| Signal | Raqam | Standart amal | Kim yuboradi, nima uchun |
|--------|-------|---------------|--------------------------|
| `SIGHUP` | 1 | o'lim | terminal yopildi; daemon'lar uchun an'anaviy "konfiguratsiyani qayta o'qi" |
| `SIGINT` | 2 | o'lim | `Ctrl+C` |
| `SIGQUIT` | 3 | o'lim + core dump | `Ctrl+\` |
| `SIGKILL` | 9 | o'lim, ushlab bo'lmaydi | oxirgi chora, OOM killer (8-dars) |
| `SIGUSR1`, `SIGUSR2` | 10, 12 | o'lim | dasturning o'zi ma'no beradi (masalan logni qayta ochish) |
| `SIGSEGV` | 11 | o'lim + core dump | noto'g'ri xotira murojaati |
| `SIGPIPE` | 13 | o'lim | o'quvchisi yo'q pipe'ga yozish (`yes \| head -1`) |
| `SIGTERM` | 15 | o'lim | "iltimos, tugat": `kill` ning standart signali, `systemctl stop`, `docker stop` |
| `SIGCHLD` | 17 | e'tiborsiz | bola tugaganda otaga |
| `SIGCONT` | 18 | davom etish | `bg`, `fg` |
| `SIGSTOP` | 19 | to'xtash, ushlab bo'lmaydi | |
| `SIGTSTP` | 20 | to'xtash | `Ctrl+Z` |

Raqamlar x86 va ARM Linux uchun (macOS'da bir qismi boshqa). Core dump bu jarayon o'lgan paytdagi xotirasining debug uchun faylga yozilgan nusxasi. To'liq ro'yxat: `kill -l`, tavsif: `man 7 signal`. Skriptlarda raqam emas, nom yozing.

### kill, pkill, killall

`kill` nomiga qaramay "signal yubor" degani. Bash'da u builtin, shuning uchun `%1` kabi job raqamlarini tushunadi.

```
$ kill <PID>             # SIGTERM
$ kill -TERM <PID>       # the same, explicit
$ kill -KILL <PID>       # SIGKILL, last resort
$ kill -0 <PID>          # send nothing, only check the process exists
$ pkill -f "node server" # by full command line pattern
$ pkill -HUP nginx       # by name, specific signal
$ killall sleep          # all processes with this exact name
```

```
ubuntu@lab:~$ kill -l 15
TERM
ubuntu@lab:~$ kill -l 137
KILL
ubuntu@lab:~$ kill -0 1; echo $?
bash: kill: (1) - Operation not permitted
1
ubuntu@lab:~$ kill -0 $$; echo $?
0
```

`kill -l <raqam>` raqamni nomga aylantiradi; 128 dan katta son berilsa uni exit code deb olib, qaysi signal ekanini aytadi (`137` ning ma'nosi quyida). `kill -0` hech narsa yubormaydi, faqat "yubora olarmidim" ni tekshiradi: PID 1 mavjud, lekin root'niki, shuning uchun `Operation not permitted`; o'z shell'ingizga `0`. Mavjud bo'lmagan PID uchun xato `No such process` bo'ladi. Node'dagi `process.kill(pid, 0)` aynan shu tekshiruv.

### SIGTERM va SIGKILL

`SIGTERM` ni dastur ushlaydi va tartibli tugaydi (**graceful shutdown**): yangi so'rov qabul qilishni to'xtatadi, joriylarini tugatadi, bufer va fayllarni yozib yopadi, lock va vaqtinchalik fayllarni o'chiradi. Node'da bu shunday ko'rinadi:

```
process.on('SIGTERM', () => {
  server.close(() => process.exit(0)); // stop accepting, finish in-flight requests
});
```

Node'da `SIGTERM` uchun listener qo'shilsa, standart amal (o'lim) o'chadi: `process.exit` ni o'zingiz chaqirmasangiz jarayon tugamaydi. `SIGKILL` da dastur hech narsa qila olmaydi: kernel uni darhol olib tashlaydi. Yarim yozilgan fayl, yopilmagan tranzaksiya, qolib ketgan lock fayl shundan chiqadi.

To'g'ri tartib: `SIGTERM`, bir necha soniya kutish, faqat shundan keyin `SIGKILL`. `systemctl stop` va `docker stop` aynan shunday ishlaydi (kutish mos ravishda standart 90 va 10 soniya).

**Tuzoq: `kill -9` refleksi.** Birinchi urinishda `-9` yuborish ma'lumot buzilishining klassik sababi. `SIGKILL` faqat jarayon `SIGTERM` ga javob bermaganda.

`D` holatidagi jarayon signalni kutish tugagandan keyingina ko'radi, `Z` holatidagi allaqachon o'lgan: ikkalasida ham `kill -9` darhol natija bermaydi.

### Exit code va signal

Jarayon signaldan o'lsa, shell `$?` ga `128 + signal raqami` ni yozadi:

| `$?` | Sabab |
|------|-------|
| 130 | `SIGINT` (128 + 2) |
| 137 | `SIGKILL` (128 + 9): `kill -9`, OOM killer, `docker stop` timeout |
| 143 | `SIGTERM` (128 + 15) |

Bu shell'ning kelishuvi: kernel otaga "exit code" yoki "qaysi signaldan o'ldi" ni alohida beradi. Node buni ajratilgan holda ko'rsatadi: `child.on('exit', (code, signal))` da signaldan o'lgan bola uchun `code` `null`, `signal` `'SIGTERM'`. CI logida yoki `docker ps -a` da `Exited (137)` ko'rsangiz, birinchi gumon OOM.

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

`mktemp` noyob nomli vaqtinchalik fayl yaratib yo'lini chiqaradi. `EXIT` signal emas, bash'ning pseudo-signali: skript istalgan yo'l bilan tugaganda (oddiy tugash, `exit`, ushlangan signaldan keyingi `exit`) ishlaydi, shuning uchun tozalash uchun eng ishonchli joy. `SIGKILL` da hech qanday trap ishlamaydi.

**Tuzoq: trap foreground buyruq tugashini kutadi.** Bash handler'ni faqat joriy foreground buyruq tugagach bajaradi. Skript `sleep 3600` da turgan bo'lsa, `SIGTERM` handler bir soatdan keyin ishlaydi. Yechim: buyruqni background'ga chiqarib `wait` qilish, chunki `wait` builtin signal kelganda darhol qaytadi:

```
sleep 3600 &
wait $!
```

### PID 1 va konteynerlar

PID 1 uchun kernel maxsus qoida qo'llaydi: handler o'rnatilmagan signal unga yetkazilmaydi, ya'ni standart "o'lim" amali ishlamaydi (tizimning init jarayoni tasodifan o'lmasligi uchun). Konteyner o'z PID namespace'iga ega (jarayonlar raqamlanishi noldan boshlanadigan izolyatsiya, docker moduli) va unda sizning dasturingiz PID 1 bo'ladi. Agar u `SIGTERM` handler yozmagan bo'lsa, `docker stop` 10 soniya kutib `SIGKILL` yuboradi (tashqi namespace'dan kelgan `SIGKILL` har doim ishlaydi). Ikkinchi klassik holat: Dockerfile'da `CMD npm start` (shell shakli) yozilsa, PID 1 `sh` bo'ladi va signal dasturingizga umuman yetib bormaydi. Docker modulida `exec` shakli va `--init` bilan chuqur ko'ramiz.

Mashina farqi: Zorin'da konteynerning PID 1 jarayoni host'dagi `ps -ef` da oddiy jarayon sifatida ko'rinadi (host PID'i boshqa), macOS'da ko'rinmaydi, chunki u Docker Desktop'ning yashirin VM'ida. Ikkalasida ham ichkaridan qarash uchun `docker exec <nom> ps -ef` ishlatiladi.

### Real ishda qachon kerak

- Har deploy'da servis aniq 10 yoki 90 soniya "osilib" to'xtaydi: dastur `SIGTERM` ni ushlamayapti yoki signal unga yetmayapti.
- `nginx -s reload`, `systemctl reload`: konfiguratsiyani uzilishsiz qayta o'qish ichkarida `SIGHUP`.
- Pod yoki konteyner `137` bilan tugadi: xotira limiti yoki shutdown timeout'i.
- Kubernetes pod'ni o'chirishda avval `SIGTERM`, `terminationGracePeriodSeconds` dan keyin `SIGKILL` yuboradi: xuddi shu ikki bosqich.

### Nima uchun shunday

Signal eng eski va eng sodda jarayonlararo aloqa: ichida ma'lumot yo'q, lekin har jarayonga, u nima bilan band bo'lmasin, yetib boradi. `SIGKILL` va `SIGSTOP` ushlab bo'lmaydigan qilingan, aks holda buzilgan yoki yomon niyatli dasturni to'xtatishning kafolatlangan yo'li qolmasdi. `SIGTERM` esa ataylab ushlanadigan: tizim dasturga ishini tartibli yopish imkonini beradi. Muqobili (HTTP orqali "shutdown" endpoint, boshqaruv socket'i) har dastur uchun alohida protokol talab qiladi, signal esa hamma dasturda bir xil, shuning uchun systemd, Docker va Kubernetes shu ikki signalga tayangan.

## 5. Prioritet: nice va renice

### Mexanizm

CPU yetishmaganda scheduler (kernel'ning CPU vaqtini jarayonlarga taqsimlaydigan qismi, 8-dars) vaqtni **nice** qiymatiga qarab bo'ladi: -20 (eng yuqori prioritet) dan 19 (eng past) gacha, standart 0. Nom "boshqalarga nisbatan muloyimlik" dan: nice qancha baland bo'lsa, jarayon shuncha kam talab qiladi. Nice navbat tartibi emas, ulush: har qiymatga vazn mos keladi (nice 0 uchun 1024) va har bir qadam vaznni taxminan 1.25 marta o'zgartiradi. Bitta yadro uchun raqobatlashayotgan nice 0 va nice 5 jarayonlar vaznlari 1024 va 335, ya'ni CPU taxminan 75% va 25% bo'linadi. Nice qiymati `fork` da bolaga meros bo'ladi.

```
ubuntu@lab:~$ nice
0
ubuntu@lab:~$ nice -n 10 sleep 100 &
[1] <PID>
ubuntu@lab:~$ ps -o pid,ni,stat,cmd -p $!
    PID  NI STAT CMD
  <PID>  10 SN   sleep 100
ubuntu@lab:~$ renice -n 15 -p $!
<PID> (process ID) old priority 10, new priority 15
ubuntu@lab:~$ kill %1
```

Argumentsiz `nice` joriy shell'ning qiymatini chiqaradi. `nice -n 10 cmd` buyruqni joriy qiymatga 10 qo'shib ishga tushiradi. `ps` da `NI` ustuni 10, `STAT` dagi `N` "past prioritet" belgisi. `renice` ishlab turgan jarayonning qiymatini o'zgartiradi va eski hamda yangi qiymatni aytadi.

- Oddiy foydalanuvchi nice'ni faqat oshira oladi (prioritetni pasaytiradi). Kamaytirish va manfiy qiymat uchun root kerak.
- Nice faqat CPU uchun raqobat bo'lganda ta'sir qiladi.
- Disk I/O uchun alohida asbob: `ionice -c 3 cmd` (idle klass), ta'siri I/O scheduler'ga bog'liq.
- Qattiq chegara kerak bo'lsa nice emas, cgroup limiti (systemd'da `CPUQuota=`, `MemoryMax=`, 11-dars).

### Real ishda qachon kerak

- Ish vaqtida ishga tushadigan backup, arxivlash, indekslash: `nice -n 10 tar czf backup.tgz /srv/data`, asosiy servisga xalaqit bermasin.
- Allaqachon ishlab turgan og'ir job'ni o'ldirmasdan chetga surish: `renice`.
- Build serverda kompilyatsiyani past prioritetda yuritish, SSH sessiyangiz sezgir qolsin.

### Nima uchun shunday

Nice 1970-yillardagi ko'p foydalanuvchili mashinalardan: og'ir hisob-kitob boshlagan odam boshqalarga "muloyim" bo'lishi uchun. Oddiy foydalanuvchiga faqat pasaytirish ruxsat etilgan, aks holda hamma o'ziga eng yuqori prioritetni qo'yardi. Linux kernel'i 6.6 versiyadan EEVDF scheduler'ini ishlatadi (undan oldin CFS), ikkalasida ham nice vaznga aylanadi. Konteyner va Kubernetes dunyosida ulush va limitlar nice bilan emas, cgroup bilan beriladi (`cpu.weight`, `cpu.max`), chunki nice bitta jarayonga, cgroup esa butun guruhga tegishli.

## 6. Zombie va orphan

### Zombie

Jarayon tugaganda kernel uning xotirasi va fayllarini bo'shatadi, lekin jarayonlar jadvalidagi yozuvni (PID, exit code) otasi `wait` bilan o'qib olguncha saqlaydi, aks holda ota bolaning qanday tugaganini bila olmasdi. Shu oraliqdagi jarayon **zombie**: `ps` da holati `Z`, nomi `<defunct>`. Kernel bola tugaganda otaga `SIGCHLD` yuboradi, to'g'ri yozilgan ota shu paytda `wait` qiladi.

Zombie'ni ataylab yasaymiz: Python jarayoni `fork` qiladi, bola darhol chiqadi, ota esa `wait` qilmay 60 soniya uxlaydi.

```
ubuntu@lab:~$ python3 -c 'import os,time; os.fork() or os._exit(0); time.sleep(60)' &
[1] <PID>
ubuntu@lab:~$ ps -o pid,ppid,stat,cmd
    PID    PPID STAT CMD
 <bash>  <sshd> Ss   -bash
  <PID>  <bash> S    python3 -c import os,time; os.fork() or os._exit(0); time.sleep(60)
    <Z>   <PID> Z    [python3] <defunct>
   <ps>  <bash> R+   ps -o pid,ppid,stat,cmd
```

`os.fork()` otada bolaning PID'ini (nolga teng emas), bolada `0` ni qaytaradi, shuning uchun `or os._exit(0)` faqat bolada bajariladi. Uchinchi qator zombie: holati `Z`, otasi (`PPID`) Python jarayoni, buyruq satri o'rnida `[python3] <defunct>`, chunki xotirasi allaqachon bo'shatilgan. 60 soniyadan keyin ota tugaydi, zombie PID 1 ga o'tadi va u uni darhol yig'ib oladi: `ps` da ikkalasi ham yo'qoladi.

- Zombie resurs yemaydi (CPU 0, xotira 0), faqat bitta PID va jadval yozuvini band qiladi.
- Uni o'ldirib bo'lmaydi, chunki u allaqachon o'lgan.
- Qisqa muddatli zombie normal holat. Uzoq turgan va soni o'sayotgan zombie'lar ota jarayondagi xato belgisi (bolalarini `wait` qilmayapti). Minglab to'plansa PID'lar tugaydi va yangi jarayon yaratib bo'lmaydi.
- Davosi otada: ota tuzatiladi yoki to'xtatiladi.

Node `child_process` orqali yaratilgan bolalarni o'zi `wait` qiladi (`exit` hodisasi shundan keladi), shuning uchun Node'da zombie odatda konteynerdagi PID 1 muammosi sifatida uchraydi (quyida).

### Orphan

Ota boladan oldin o'lsa, bola **orphan** (yetim) bo'ladi va kernel uni PID 1 ga yoki eng yaqin **subreaper** ga beradi (subreaper bu "yetim avlodlarimni menga ber" deb kernel'ga e'lon qilgan jarayon, masalan grafik sessiyadagi `systemd --user`). Bu **reparenting** deyiladi va xato emas: `nohup` va `setsid` bilan ataylab shunday qilinadi, daemon'lar an'anaviy ravishda shu yo'l bilan terminaldan uzilgan.

PID 1 ning ikkinchi vazifasi shundan: o'ziga o'tgan har bolani `wait` qilib yig'ish (**reaping**). `systemd` buni qiladi. Konteynerda PID 1 sizning dasturingiz bo'lsa va u begona bolalarni yig'masa, zombie'lar to'planadi. `docker run --init` shu muammoni kichik init jarayoni (`tini`) qo'yib yechadi: u signal'larni dasturga uzatadi va yetimlarni yig'adi (docker moduli).

### Real ishda qachon kerak

- Monitoring "zombie processes" ogohlantirishi: sonini emas, otasini qidirasiz (`ps -eo pid,ppid,stat,cmd` da `Z` qatorlarning `PPID` i).
- Konteynerda health check yoki `docker exec` orqali ko'p qisqa jarayon ishga tushsa va PID 1 ularni yig'masa, `<defunct>` lar to'planadi: `--init` yoki to'g'ri init.
- Deploy skripti tugaganidan keyin ham ishlayotgan jarayonlar: ular orphan bo'lib PID 1 ga o'tgan, `PPID` `1`.

### Nima uchun shunday

Exit code'ni kimdir o'qishi kerak, kernel esa ota qachon so'rashini bilmaydi, shuning uchun yozuvni saqlab turadi: zombie shu dizaynning yon ta'siri, xato emas. Yetimlarni PID 1 ga berish esa "har jarayonning `wait` qiladigan otasi bo'lsin" degan qoidani saqlaydi. Muqobili (yetimni otasi bilan birga o'ldirish) fon servislarini imkonsiz qilardi; guruhni birga tugatish kerak bo'lganda bugun cgroup ishlatiladi, systemd servisning hamma jarayonlarini shu orqali topadi va to'xtatadi (11-dars).

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Jarayon (process) | dasturning ishlayotgan nusxasi: o'z xotirasi, deskriptorlari va PID'i bilan |
| PID, PPID | jarayonning va uning otasining kernel bergan raqami |
| `fork` | jarayonning nusxasini (bolani) yaratadigan system call |
| `execve` | jarayon ichidagi dasturni boshqasiga almashtiradigan system call, PID saqlanadi |
| `wait` | ota bolaning tugashini kutib exit code'ini oladigan system call |
| Copy-on-write | xotira sahifasi faqat yozilganda nusxalanadigan usul |
| Kernel thread | kernel ichida ishlaydigan, `ps` da kvadrat qavsda ko'rinadigan thread |
| Session, session leader | bitta login'ga tegishli jarayonlar to'plami va uni boshlagan shell |
| Process group, job | birga boshqariladigan jarayonlar guruhi; shell'dagi bitta pipeline |
| Foreground, background | terminaldan o'qiy oladigan guruh va qolgan guruhlar |
| Signal | jarayonga kernel orqali yuboriladigan raqamli asinxron xabar |
| Handler | signal kelganda chaqiriladigan jarayonning o'z funksiyasi |
| Standart amal | handler bo'lmaganda kernel bajaradigan amal (o'lim, to'xtash, e'tiborsiz) |
| Graceful shutdown | `SIGTERM` dan keyin ishni tartibli yakunlab chiqish |
| Core dump | o'lgan jarayon xotirasining debug uchun faylga yozilgan nusxasi |
| `trap` | bash'da signal yoki `EXIT` uchun handler o'rnatadigan builtin |
| Nice | CPU uchun raqobatdagi ulushni belgilaydigan qiymat, -20 dan 19 gacha |
| Zombie | tugagan, lekin otasi hali `wait` qilmagan jarayon (`Z`, `<defunct>`) |
| Orphan | otasi o'zidan oldin o'lgan jarayon |
| Reparenting | orphan'ni PID 1 yoki subreaper'ga o'tkazish |
| Subreaper | yetim avlodlarini o'ziga olishni kernel'ga e'lon qilgan jarayon |
| Reaping | tugagan bolani `wait` qilib jadvaldan o'chirish |
| PID namespace | jarayonlar o'z raqamlanishiga ega bo'lgan izolyatsiya, ichidagi birinchi jarayon PID 1 |

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
- Node'da `SIGTERM` listener yozib, ichida `process.exit` ni chaqirmaslik: standart amal o'chgan, jarayon endi `SIGTERM` dan o'lmaydi.
- `nice` ni resurs limiti deb o'ylash. U faqat raqobat paytidagi ulushni o'zgartiradi.
- Signal raqamini yodlab skriptga yozish: macOS va Linux'da raqamlar farq qiladi, nom (`-TERM`, `-USR1`) hamma joyda bir xil.
- macOS host'da `pgrep -a` yoki `ps --forest` ni sinab "ishlamadi" deb xulosa qilish: u BSD varianti, dars buyruqlari `lab` VM uchun.

## Manbalar

- https://man7.org/linux/man-pages/man7/signal.7.html – signal(7): ro'yxat, standart amallar (majburiy)
- https://man7.org/linux/man-pages/man1/ps.1.html – ps(1), ustunlar va holat kodlari
- https://man7.org/linux/man-pages/man5/proc.5.html – proc(5)
- https://man7.org/linux/man-pages/man2/fork.2.html – fork(2)
- https://man7.org/linux/man-pages/man2/execve.2.html – execve(2), nima saqlanadi va nima almashadi
- https://man7.org/linux/man-pages/man2/wait.2.html – wait(2), zombie haqida NOTES bo'limi
- https://man7.org/linux/man-pages/man7/credentials.7.html – credentials(7): session va process group
- https://man7.org/linux/man-pages/man7/pid_namespaces.7.html – PID namespace va PID 1 ning signal qoidalari
- https://man7.org/linux/man-pages/man1/nice.1.html – nice(1); https://man7.org/linux/man-pages/man1/renice.1.html – renice(1)
- https://www.gnu.org/software/bash/manual/html_node/Job-Control.html – Bash job control
- https://www.gnu.org/software/bash/manual/html_node/Signals.html – Bash signal'larni qanday qayta ishlaydi (trap kechikishi, SIGHUP)
- https://nodejs.org/api/process.html#signal-events – Node.js: signal hodisalari va standart handler'lar
- https://docs.docker.com/reference/cli/docker/container/stop/ – `docker stop`: SIGTERM, kutish, SIGKILL
- Michael Kerrisk, "The Linux Programming Interface", 20–26 va 34-boblar

## Birga bajaramiz

Bitta haqiqiy tarmoq servisini terminaldan ishga tushirib, uning butun hayotini kuzatamiz: daraxtdagi o'rni, ochiq deskriptorlari, to'xtatish va davom ettirish, prioritet, ushlanadigan va ushlanmaydigan signal farqi. Servis sifatida Python'ning ichki HTTP serveri (`python3 -m http.server`), u VM'da tayyor. Ikki terminal kerak, ikkalasida `multipass shell lab`.

1. Birinchi terminalda bo'sh papkada serverni background'da, chiqishini faylga yo'naltirib ishga tushiring:

```
ubuntu@lab:~$ mkdir -p ~/web && cd ~/web
ubuntu@lab:~/web$ python3 -m http.server 8000 > web.log 2>&1 &
[1] <PID>
ubuntu@lab:~/web$ ps -o pid,ppid,pgid,stat,ni,cmd -p $!
    PID    PPID    PGID STAT  NI CMD
  <PID>  <bash>   <PID> S      0 python3 -m http.server 8000
```

Bash `fork` qildi, bola stdout va stderr'ni `web.log` ga uladi va `python3` ni `execve` qildi. `PPID` shell'ingiz, `PGID` o'z PID'iga teng (alohida job), holat `S`: server so'rov kutib uxlayapti, nice `0`.

2. Kernel bu jarayon haqida nima biladi:

```
ubuntu@lab:~/web$ ls -l /proc/$!/fd
total 0
lrwx------ 1 ubuntu ubuntu 64 <sana> 0 -> /dev/pts/0
l-wx------ 1 ubuntu ubuntu 64 <sana> 1 -> /home/ubuntu/web/web.log
l-wx------ 1 ubuntu ubuntu 64 <sana> 2 -> /home/ubuntu/web/web.log
lrwx------ 1 ubuntu ubuntu 64 <sana> 3 -> 'socket:[<N>]'
ubuntu@lab:~/web$ grep SigCgt /proc/$!/status
SigCgt:	<mask>
```

`0` terminaldan meros, `1` va `2` yo'naltirish tufayli faylga ulangan (ruxsatda faqat `w`), `3` server ochgan tinglovchi socket. `SigCgt` nolga teng emas: Python `SIGINT` (2-signal) uchun handler o'rnatgan, `SIGTERM` uchun esa yo'q. Bu 6-qadamda ko'rinadi.

3. Ikkinchi terminaldan so'rov yuboring, keyin serverni to'xtatib qayta so'rang:

```
ubuntu@lab:~$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/
200
ubuntu@lab:~$ kill -STOP <PID>
ubuntu@lab:~$ ps -o pid,stat,cmd -p <PID>
    PID STAT CMD
  <PID> T    python3 -m http.server 8000
ubuntu@lab:~$ curl -m 3 http://localhost:8000/; echo "exit=$?"
curl: (28) Operation timed out after <N> milliseconds with 0 bytes received
exit=28
```

`SIGSTOP` dan keyin holat `T`. Jarayon o'lmagan, port band, kernel ulanishni qabul qiladi, lekin javob beradigan kod CPU olmayapti: `curl` 3 soniyadan keyin timeout bilan chiqadi. Tashqaridan bu "servis osilib qoldi" ko'rinishida bo'ladi.

4. Davom ettiring va prioritetini pasaytiring:

```
ubuntu@lab:~$ kill -CONT <PID>
ubuntu@lab:~$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8000/
200
ubuntu@lab:~$ renice -n 5 -p <PID>
<PID> (process ID) old priority 0, new priority 5
```

`SIGCONT` dan keyin server hech narsa bo'lmagandek ishlaydi: xotirasi va socket'i joyida edi. `renice` jarayonni qayta ishga tushirmasdan nice'ni o'zgartirdi; VM bo'sh bo'lgani uchun tezlikda farq sezilmaydi.

5. Birinchi terminalda job holatini ko'ring: `jobs -l` da `[1]+ <PID> Running`. To'xtatilgan paytda bu yerda `Stopped (signal)` turgan bo'lardi.

6. Ushlanadigan signal bilan tugating (ikkinchi terminaldan `kill -INT <PID>`), birinchi terminalda kodni o'qing:

```
ubuntu@lab:~/web$ wait %1; echo "exit=$?"
[1]+  Done                    python3 -m http.server 8000 > web.log 2>&1
exit=0
ubuntu@lab:~/web$ tail -1 web.log
Keyboard interrupt received, exiting.
```

Python `SIGINT` ni ushladi, handler ishladi: server xabar yozdi, stdout buferini faylga tushirdi va `0` bilan chiqdi. Shell job haqida `Terminated` emas, `Done` dedi va kod `128 + N` emas: jarayon signaldan o'lmagan, signalni ushlab o'zi tugagan.

7. Xuddi shu serverni qayta ishga tushiring (1-qadamdagi buyruq), bitta `curl` qiling va endi `kill <PID>` (`SIGTERM`) yuboring:

```
ubuntu@lab:~/web$ wait %1; echo "exit=$?"
[1]+  Terminated              python3 -m http.server 8000 > web.log 2>&1
exit=143
ubuntu@lab:~/web$ cat web.log
127.0.0.1 - - [<sana>] "GET / HTTP/1.1" 200 -
```

Bu serverda `SIGTERM` handler yo'q, kernel standart amalni bajardi: `Terminated`, `143 = 128 + 15`. `web.log` da faqat stderr'ga darhol yozilgan so'rov qatori bor; xayrlashuv xabari yo'q va buferda turgan stdout matni ham yo'qoldi, chunki jarayonga hech narsa qilish imkoni berilmadi. Handler bor va yo'q holat orasidagi farq shu.

8. Tozalang: `pgrep -af http.server` bo'sh ekanini tekshiring, `cd ~ && rm -r ~/web`.

Shu 8 qadamda ko'rganingiz: `fork` va `execve` orasidagi yo'naltirish (1-bo'lim), `/proc/<PID>/fd` va signal maskasi (2-bo'lim), job va uning holatlari (3-bo'lim), `SIGSTOP` va `SIGCONT`, handler bilan va handlersiz tugash, exit code (4-bo'lim), `renice` (5-bo'lim). Zombie va orphan bu misolda yo'q, ular 6-bo'limdagi misolda va D guruh vazifalarida.

---

## Vazifalar

Ish papkasi: `linux/09-processes/` (`make new m=linux n=09 name=processes` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptlarni (`task_N.sh`) yoniga saqlang. Aytilmagan bo'lsa hamma narsa `lab` VM ichidagi bash'da bajariladi. "Host'da" deb belgilangan ixtiyoriy qismlarni o'sha mashinada bo'lsangiz qo'shing.

### A. Jarayon modeli va ko'rish

1. **Process tree.** VM'da (`multipass shell` orqali) `pstree -p -s $$` bilan o'z shell'ingizdan PID 1 gacha bo'lgan zanjirni chiqaring. Zanjirdagi har jarayon nima ekanini bir gapdan izohlang. Ixtiyoriy, host'da: Zorin'da terminal emulyatori ichida xuddi shu buyruq; macOS'da `pstree` bo'lmasa `ps -o pid,ppid,comm -p <PID>` bilan otama-ota yuqoriga chiqing. Zanjir VM'dagidan nimasi bilan farq qiladi? Yo'nalish: 1-bo'lim, "Misol: ota va bola".

2. **fork and exec.** Bash'da `echo $$` ni yozib oling, keyin `sleep 300 &` va `ps -o pid,ppid,cmd -p $!` ni bajaring. Keyin yangi bash ichida (`bash` deb kiring) `echo $$` va `exec sleep 30` ni bajaring: `exec` dan keyin nima bo'ldi, PID o'zgardimi, 30 soniyadan keyin qayerga qaytdingiz? Farqni fork/exec modeli orqali tushuntiring. Yo'nalish: 1-bo'lim, "Mexanizm: fork va execve" va "exec builtin".

3. **ps columns.** Xotira bo'yicha eng katta 5 jarayonni `ps -eo` va `--sort` bilan `pid,ppid,user,stat,ni,rss,etime,cmd` ustunlarida chiqaring. `RSS` va `VSZ` farqini, `etime` nimani bildirishini yozing. `ps aux | grep sshd` va `pgrep -a sshd` natijalarini solishtiring. Yo'nalish: 2-bo'lim, "ps" va "pgrep".

4. **Explore /proc.** `sleep 600 &` ni ishga tushirib, uning `/proc/<PID>/` katalogidan quyidagilarni oling: buyruq qatori (o'qiladigan ko'rinishda), joriy katalog, binary yo'li, ochiq fayl deskriptorlari va ular qayerga ishora qilishi, `status` dan `State`, `PPid`, `VmRSS`. Keyin `FOO=secret sleep 600 &` qilib, `environ` dan `FOO` ni toping. Yo'nalish: 2-bo'lim, "/proc".

5. **Process states.** `sleep 600` ni foreground'da ishga tushirib `Ctrl+Z` bosing. `ps -o pid,stat,cmd` bilan holatini ko'ring. `bg` dan keyin holat qanday o'zgardi? VM'da `ps -eo stat | sort | uniq -c` bilan har holatdagi jarayonlar sonini chiqaring va natijani izohlang. Yo'nalish: 1-bo'lim, "Jarayon holatlari".

### B. Job control

6. **jobs, bg, fg.** Uchta `sleep` (300, 400, 500) ni ketma-ket background'da ishga tushiring. `jobs -l` ni oling. Ikkinchisini foreground'ga olib, to'xtatib, background'da davom ettiring. Uchinchisini job raqami orqali o'ldiring. Har qadamdagi `jobs` chiqishini yozing, `+` va `-` belgilari nimani bildirishini izohlang (`man bash`, `/JOB CONTROL`). Yo'nalish: 3-bo'lim, "Job'larni boshqarish".

7. **SIGHUP on disconnect.** VM'ga birinchi terminaldan kirib `sleep 1000 &` ishga tushiring va PID'ini yozib oling. Terminal oynasini yoping (`exit` emas, oynaning o'zini). Ikkinchi terminaldan jarayon tirikligini tekshiring. Tajribani `exit` bilan chiqib takrorlang. Ikki holat natijasi bir xilmi? `shopt huponexit` qiymatini tekshirib, natijani izohlang. Yo'nalish: 3-bo'lim, "Terminal yopilganda nima bo'ladi".

8. **nohup and disown.** 7-vazifani uch variantda takrorlang: `nohup sleep 1000 &`; `sleep 1000 &` dan keyin `disown`; `setsid sleep 1000`. Har birida terminal oynasini yopgandan keyin jarayon tirikmi, uning PPID'i nima bo'ldi, `nohup.out` qayerda paydo bo'ldi? Oxirida hammasini `pkill` bilan tozalang. Yo'nalish: 3-bo'lim, "Terminal yopilganda nima bo'ladi".

9. **Reparenting.** VM'da `bash -c 'sleep 500 & echo child=$!; sleep 5'` ni ishga tushiring. 5 soniya ichida va undan keyin `ps -o pid,ppid,cmd -p <child>` ni oling. Yangi ota kim? Xuddi shu tajribani host'dagi grafik terminalda takrorlang (macOS'da `-o pid,ppid,command`): u yerda ota PID 1 emas bo'lishi mumkin, kimligini va nima uchunligini aniqlang; ikki mashinada javob farq qilsa sababini yozing. Yo'nalish: 6-bo'lim, "Orphan".

### C. Signal'lar

10. **Signal table.** `kill -l` chiqishidan `HUP`, `INT`, `QUIT`, `KILL`, `TERM`, `CONT`, `STOP`, `TSTP`, `USR1` raqamlarini toping. `man 7 signal` dan har birining standart amalini yozing. Qaysi ikkitasini ushlab bo'lmaydi va nima uchun shunday loyihalangan deb o'ylaysiz? Yo'nalish: 4-bo'lim, "Mexanizm".

11. **Exit codes.** `sleep 300` ni foreground'da ishga tushirib, uch xil usul bilan to'xtating va har safar `echo $?` ni yozing: `Ctrl+C`; boshqa terminaldan `kill`; boshqa terminaldan `kill -9`. Raqamlarni formulasi bilan izohlang. Yo'nalish: 4-bo'lim, "Exit code va signal".

12. **STOP and CONT.** VM'da `stress-ng --cpu 1 --timeout 300s` (yoki `yes > /dev/null`) ishga tushiring. `top` da CPU'ni ko'ring, keyin jarayonga `SIGSTOP` yuboring: holat va CPU qanday o'zgardi? `SIGCONT` bilan davom ettiring. Bu juftlik production'da qanday vaziyatda foydali bo'lishi mumkin? Yo'nalish: 4-bo'lim, "Mexanizm" va "Birga bajaramiz", 3–4 qadamlar.

13. **trap script.** `task_13.sh` yozing: vaqtinchalik fayl yaratadi (`mktemp`), har soniyada unga qator qo'shadi, `SIGINT` va `SIGTERM` da "signal oldim" deb chop etib tugaydi, har qanday tugashda (`EXIT`) vaqtinchalik faylni o'chiradi. Uch usulda tekshiring: `Ctrl+C`, `kill`, `kill -9`. Qaysi holatda fayl qolib ketdi va nima uchun? Yo'nalish: 4-bo'lim, "trap".

14. **Delayed trap.** `task_14.sh` yozing: `trap 'echo got TERM; exit 143' TERM`, keyin `sleep 60`. Skriptni ishga tushirib, boshqa terminaldan skript PID'iga `SIGTERM` yuboring va handler qachon ishlaganini `date` bilan o'lchang. Keyin skriptni `sleep 60 & wait $!` naqshi bilan tuzating va qayta o'lchang. Tuzatilgan variantda `sleep` jarayonining o'zi nima bo'ldi, uni ham to'xtatish uchun nima qo'shish kerak? Yo'nalish: 4-bo'lim, "Tuzoq: trap foreground buyruq tugashini kutadi".

15. **pkill safely.** Uchta jarayon ishga tushiring: `sleep 1001`, `sleep 1002`, `bash -c 'sleep 1003'`. Faqat `sleep 1002` ni `pkill` bilan o'ldiring, lekin avval `pgrep -af` bilan patterningiz aynan nimaga mos kelishini ko'rsating. `pkill sleep`, `pkill -f 1002` va `pkill -x` farqini izohlang. Yo'nalish: 2-bo'lim, "pgrep".

16. **PID 1 ignores signals.** Host'da `docker run -d --name pid1 ubuntu:24.04 sleep 600` ni ishga tushiring. `docker exec pid1 ps -ef` (kerak bo'lsa `cat /proc/1/cmdline`) bilan PID 1 ni ko'ring. `time docker stop pid1` qancha vaqt oldi va `docker inspect` dagi exit code nima? Xuddi shuni `--init` flag'i bilan takrorlang va farqni PID 1 qoidasi orqali tushuntiring. Konteynerlarni o'chiring. Ikkala host'da buyruqlar bir xil; ixtiyoriy: Zorin'da konteynerning `sleep` jarayonini host'dagi `ps -ef` dan toping, macOS'da nima uchun topilmasligini yozing. Yo'nalish: 4-bo'lim, "PID 1 va konteynerlar".

### D. Prioritet, zombie

17. **nice under contention.** VM'da (yadrolar soni N bo'lsin, `nproc`) bir vaqtda `stress-ng --cpu N --timeout 60s` va `nice -n 19 stress-ng --cpu N --timeout 60s` ni ishga tushiring. `top` da ikki guruhning `NI` va `%CPU` ustunlarini solishtiring. Keyin faqat nice 19 variantni yolg'iz ishga tushiring: u qancha CPU oldi? Xulosa yozing. Yo'nalish: 5-bo'lim, "Mexanizm".

18. **renice limits.** Oddiy foydalanuvchi sifatida ishlab turgan jarayoningizga `renice -n 10`, keyin `renice -n 5` qilib ko'ring. Ikkinchi buyruq xatosini yozing va sababini izohlang. `sudo` bilan manfiy qiymat qo'ying. Yo'nalish: 5-bo'lim.

19. **Make a zombie.** `(sleep 1 & exec sleep 120) &` ni bajaring. 2 soniyadan keyin `ps -eo pid,ppid,stat,cmd | grep -E 'defunct|sleep 120'` ni oling. Zombie kim, otasi kim, bu konstruksiya nima uchun zombie hosil qilishini (kim `wait` qilmayapti) tushuntiring. Zombie'ga `kill -9` yuboring: nima o'zgardi? Uni yo'qotishning to'g'ri usulini qo'llang va natijani ko'rsating. Yo'nalish: 6-bo'lim, "Zombie".

### E. Yakuniy

20. **Graceful worker.** `task_20.sh` yozing: "worker" skript. U `worker.pid` fayliga o'z PID'ini yozadi, har 2 soniyada `worker.log` ga vaqt belgisi bilan qator qo'shadi. `SIGTERM`/`SIGINT` da joriy iteratsiyani tugatib, logga "shutting down" yozib, PID faylni o'chirib 0 bilan chiqadi. `SIGHUP` da logga "reloading config" yozib ishlashda davom etadi. `SIGUSR1` da bajarilgan iteratsiyalar sonini logga yozadi. Signal'ga reaksiya 1 soniyadan oshmasin (14-vazifadagi naqsh). `shellcheck` toza bo'lsin. README'da har signal uchun sinov buyrug'i va log parchasini ko'rsating, va bu skript nima uchun baribir systemd unit o'rnini bosmasligini 3 gapda yozing. Yo'nalish: 4-bo'lim, "trap" va 3-bo'lim, "Tuzoq: `nohup` production servis uchun emas".

### Topshirish

Tayyor bo'lgach:
1. `linux/09-processes/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida; `task_13.sh`, `task_14.sh`, `task_20.sh` shu papkada.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; VM, konteyner yoki host'da bajarilgani ko'rinadi.
3. `make check` toza o'tadi (host'da).
4. VM'da test jarayonlari qolmagan (`pgrep -a sleep`, `pgrep -a stress-ng` bo'sh), host'da `docker ps -a` da `pid1` konteynerlari yo'q.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Shell'da buyruq yozganingizda fork va exec qaysi tartibda ishlaydi va bola nimalarni meros oladi?
- `fork` va `exec` nima uchun ikki alohida qadam, yo'naltirish (`>`) qaysi oraliqda bajariladi?
- `R`, `S`, `D`, `T`, `Z` holatlari nimani bildiradi, qaysilarida jarayon signalga darhol javob bermaydi?
- `Ctrl+C` signalini kim yuboradi va kimlarga boradi? Shell nima uchun o'lmaydi?
- `SIGTERM` va `SIGKILL` farqi nima, nima uchun avval birinchisi yuboriladi?
- Exit code 137 va 143 nimani bildiradi?
- SSH uzilganda background jarayon nima uchun o'ladi va uni saqlab qolishning uch usuli qanday?
- Zombie nima, nima uchun uni `kill -9` bilan o'ldirib bo'lmaydi, qanday yo'qotiladi?
- Orphan jarayonni kim asrab oladi va PID 1 ning bu yerdagi vazifasi nima?
- Bash'da `trap` handler nima uchun kech ishlashi mumkin?
- `nice -n 19` jarayon bo'sh mashinada qancha CPU oladi va nima uchun?
- Konteynerda `docker stop` nima uchun ba'zan 10 soniya kutadi? Node'da `SIGTERM` listener yozsangiz nima o'zgaradi?
