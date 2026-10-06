# 11-dars: Servislarni boshqarish (systemd)

Maqsad: systemd'ni foydalanuvchi sifatida emas, unit yozuvchi sifatida bilish. Dasturni serverda "to'g'ri" ishga tushirish degani: boot'da o'zi ko'tariladi, yiqilsa qayta turadi, root sifatida ishlamaydi, loglari bir joyda, to'xtatilganda tartibli tugaydi. Bularning hammasi bitta `.service` faylida e'lon qilinadi. Frontend ishida buni siz uchun `pm2`, Vercel yoki hosting paneli qilgan; serverda shu ishni systemd bajaradi va uni o'zingiz sozlaysiz. Dars 9-darsdagi signal va jarayon bilimiga (systemd servisni `SIGTERM` bilan to'xtatadi), 10-darsdagi servis akkauntga (`User=`) va 8-darsdagi `journalctl` ga tayanadi. Kubernetes'dagi restart policy, probe va resurs limitlari shu g'oyalarning davomi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh (1–4 vazifalar); ikkinchi kun 3-bo'lim, "Birga bajaramiz" va 5–7 vazifalar; uchinchi kun 6 va 8-bo'limlar, 8–10 vazifalar; to'rtinchi kun 4–5 bo'limlar va C guruh (11–14); beshinchi kun 7, 9, 10-bo'limlar, D va E guruhlari (15–19). `systemctl start/stop` tez o'tadi, diqqatni quyidagilarga qarating: unit fayl qayerda yashaydi va qaysi biri ustun, `enable` va `start` farqi, `After=` va `Wants=`/`Requires=` farqi, `Restart=` siyosatlari va start limit, environment fayl formati, drop-in override, timer va cron farqi.

Qanday o'qish kerak: har bo'limdagi misolni `lab` VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Sizdagi PID, sana, xotira raqamlari farq qiladi; bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qoidaning sababini aytadi.

## Laboratoriya

Bu dars to'liq `SETUP.md` bo'yicha yaratilgan `lab` VM (Multipass, Ubuntu 24.04, systemd 255) ichida bajariladi. systemd to'liq ishlashi uchun haqiqiy VM kerak: oddiy Docker konteynerida PID 1 systemd emas (1-dars), `systemctl` u yerda `System has not been booted with systemd as init system` deb javob beradi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `make`, `git`, `multipass shell lab`, `multipass transfer` |
| `lab` VM | `ubuntu@lab:~$` | barcha vazifalar: unit yozish, `systemctl`, `journalctl`, `curl localhost` |

- Namuna dastur sifatida Python'ning ichki HTTP serveri ishlatiladi (`python3` Ubuntu 24.04 da o'rnatilgan), alohida kod yozish shart emas.
- Unit fayllarni VM'da `sudo nano` yoki `sudoedit` bilan yozasiz, tayyor nusxasini host'dagi ish papkasiga olasiz: `multipass transfer lab:/etc/systemd/system/demoapp.service .` (ikkala host'da bir xil ishlaydi).
- 2-vazifada `sudo reboot` bor: `multipass shell` sessiyasi uziladi, 20–30 soniyadan keyin `multipass shell lab` bilan qayta kiring.
- Boshlashdan oldin snapshot oling, xato unit VM'ni buzmaydi, lekin toza nuqta foydali: host'da `multipass stop lab && multipass snapshot lab --name before-11 && multipass start lab`.
- Tozalash: dars oxirida test unit'lar `disable --now` qilinadi, fayllari o'chiriladi, `sudo systemctl daemon-reload` (19-vazifa).

**Oldingi dars holati va ikkinchi mashina.** Dars 10-darsda yaratilgan `demoapp` servis akkauntiga tayanadi (`deploy` akkaunti bu darsda ishlatilmaydi, 13-darsda kerak bo'ladi). Laboratoriya holati mashinalar orasida ko'chmaydi: 10-darsni ofisda qilgan bo'lsangiz, uydagi `lab` da `demoapp` yo'q. Tekshirish va tiklash (VM ichida):

```
ubuntu@lab:~$ id demoapp || sudo useradd --system --no-create-home --shell /usr/sbin/nologin demoapp
```

Darsni bir mashinada boshlab ikkinchisida davom ettirsangiz, unit fayllar git orqali ish papkasida keladi, ularni VM'ga qaytarasiz: host'da `multipass transfer demoapp.service lab:/home/ubuntu/`, VM'da `sudo cp ~/demoapp.service /etc/systemd/system/ && sudo systemctl daemon-reload`. `/srv/demoapp` va `/etc/demoapp/demoapp.env` ni 5 va 8-vazifadagi javoblaringiz bo'yicha qayta yaratasiz. Bu darsdan 13-darsga `demoapp.service` va `demoapp` akkaunti o'tadi, nomlarini o'zgartirmang.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`. Host'ning o'zi ham systemd ishlatadi, shuning uchun 1 va 4-vazifalardagi ixtiyoriy "host bilan solishtiring" qismi ishlaydi. Host'da faqat o'qiydigan buyruqlar: `systemctl status`, `systemctl cat`, `systemctl list-timers`, `journalctl`. Host'da unit yaratilmaydi va o'zgartirilmaydi. |
| macOS (uy) | VM `arm64`, dars uchun farqi yo'q. Host'da systemd yo'q: PID 1 `launchd`, `systemctl` va `journalctl` buyruqlari mavjud emas. "Host bilan solishtiring" qismlari o'tkazib yuboriladi yoki ixtiyoriy ravishda `launchctl list | head` bilan almashtiriladi. Barcha vazifalar faqat VM'da. |

---

## 1. systemd va unit'lar

### Bu nima

systemd bu Linux'ning **init tizimi**: kernel ishga tushiradigan birinchi jarayon (PID 1, 1-dars), qolgan hamma narsani u ko'taradi va kuzatadi. **Servis** (daemon) bu terminalga bog'lanmagan, fonda doimiy ishlaydigan dastur: SSH server, nginx, sizning Node API'ngiz. systemd boshqaradigan har obyekt **unit** deb ataladi, unit bu matnli fayl bilan tasvirlangan bitta boshqaruv birligi. Fayl kengaytmasi tipini bildiradi:

| Tip | Nima |
|-----|------|
| `.service` | jarayon yoki jarayonlar guruhi (daemon, bir martalik vazifa) |
| `.socket` | socket; ulanish kelganda tegishli servisni ishga tushiradi (socket activation) |
| `.timer` | vaqt bo'yicha servisni ishga tushirish (cron o'rniga) |
| `.target` | unit'lar guruhi, sinxronlash nuqtasi (eski "runlevel" o'rniga) |
| `.mount`, `.swap` | mount nuqtalari va swap (`/etc/fstab` dan avtomatik yaratiladi, 13-dars) |
| `.path` | fayl yoki katalog o'zgarganda servisni ishga tushirish |
| `.slice`, `.scope` | cgroup ierarxiyasi, resurs limitlari |

### Mexanizm: cgroup

**cgroup** (control group, 8-dars) bu kernel'ning jarayonlarni guruhlab, guruhga resurs hisobi va limit qo'yish mexanizmi. systemd har servisni o'z cgroup'ida ishga tushiradi. Jarayon fork qilib bola yaratsa, bola ham shu cgroup'da qoladi va undan chiqib keta olmaydi. Shuning uchun systemd servisning hamma jarayonlarini aniq biladi (PID fayl kerak emas), ularni birga to'xtata oladi va resurslarini birga o'lchaydi. `pm2` esa faqat o'zi ishga tushirgan bitta jarayonni kuzatadi: uning bolalari "yetim" qolishi mumkin.

### Unit fayllar qayerda

| Katalog | Kimniki | Ustunlik |
|---------|---------|----------|
| `/etc/systemd/system/` | administrator (siz) | eng yuqori |
| `/run/systemd/system/` | runtime, reboot'da yo'qoladi | o'rta |
| `/usr/lib/systemd/system/` | paketlar (`apt`/`dnf` o'rnatadi) | eng past |

Bir xil nomli fayl yuqoriroq katalogda bo'lsa pastdagisini to'liq yopadi. Paket faylini (`/usr/lib/...`) hech qachon tahrirlamang: paket yangilanganda o'zgarishingiz yo'qoladi. Buning uchun drop-in bor (7-bo'lim).

### Misol: mavjud unit'ni o'qish

`cron` servisi Ubuntu'da standart o'rnatilgan. `systemctl cat` amaldagi unit matnini qaysi fayldan olingani bilan ko'rsatadi:

```
ubuntu@lab:~$ systemctl cat cron
# /usr/lib/systemd/system/cron.service
[Unit]
Description=Regular background program processing daemon
Documentation=man:cron(8)
After=remote-fs.target nss-user-lookup.target

[Service]
EnvironmentFile=-/etc/default/cron
ExecStart=/usr/sbin/cron -f -P $EXTRA_OPTS
IgnoreSIGPIPE=false
KillMode=process
Restart=on-failure
SyslogFacility=cron

[Install]
WantedBy=multi-user.target
```

Qatorma-qator: birinchi `#` qatori fayl yo'li, `/usr/lib/...` demak paketdan kelgan. `[Unit]` bo'limi: `Description` odam uchun nom (`status` da ko'rinadi), `After=` tartib (5-bo'lim). `[Service]` bo'limi: `EnvironmentFile=-...` o'zgaruvchilar fayli, `-` "fayl bo'lmasa xato emas" degani; `ExecStart=` ishga tushiriladigan buyruq to'liq yo'l bilan, `-f` cron'ga "foreground'da qol" deydi; `Restart=on-failure` yiqilsa qayta ko'tarish (4-bo'lim). `[Install]` bo'limi: `enable` qilinganda servis `multi-user.target` ga ulanadi (2-bo'lim). Sizdagi matn paket versiyasiga qarab bir-ikki qatorga farq qilishi mumkin.

Barcha yuklangan servislar ro'yxati: `systemctl list-units --type=service`, faqat yiqilganlari: `systemctl --failed`.

### Real ishda qachon kerak

- Begona serverga kirganda "bu yerda nima ishlayapti" savoliga `systemctl list-units --type=service --state=running` javob beradi.
- Dastur qanday ishga tushirilganini (qaysi flag, qaysi user) bilish uchun `ps` emas, `systemctl cat <nom>` o'qiladi.

### Nima uchun shunday

systemd'dan oldin (SysV init) har servis `/etc/init.d/` dagi shell skript bilan boshqarilgan: har biri o'zicha PID fayl yozgan, o'zicha daemon'ga aylangan, ketma-ket ishga tushgan. Skript xato qilsa init jarayonni "yo'qotib qo'ygan". systemd buni deklarativ faylga almashtirdi: siz "nima kerakligini" yozasiz, "qanday" ni systemd biladi; cgroup tufayli jarayon yo'qolmaydi; bog'liqlik grafigi tufayli servislar parallel ko'tariladi. Muqobillari bor (Alpine'da OpenRC, konteynerlarda `tini` yoki `s6`), lekin Ubuntu, Debian, RHEL oilasi va deyarli barcha cloud image'lar systemd ishlatadi.

## 2. systemctl

### Bu nima

`systemctl` systemd bilan gaplashadigan buyruq: u PID 1 ga so'rov yuboradi, ishni systemd bajaradi.

| Buyruq | Nima qiladi |
|--------|-------------|
| `systemctl start X` / `stop X` | hozir ishga tushirish / to'xtatish |
| `systemctl restart X` | to'xtatib qayta ishga tushirish |
| `systemctl reload X` | jarayonni to'xtatmasdan konfiguratsiyani qayta o'qitish (unit'da `ExecReload=` bo'lsa) |
| `systemctl enable X` / `disable X` | boot'da ishga tushishini yoqish / o'chirish |
| `systemctl enable --now X` | yoqish va hozir ishga tushirish |
| `systemctl status X` | holat, PID, cgroup, oxirgi log qatorlari |
| `systemctl is-active X`, `is-enabled X`, `is-failed X` | skriptlar uchun, exit code bilan |
| `systemctl mask X` / `unmask X` | unit'ni butunlay taqiqlash, qo'lda ham ishga tushmaydi |
| `systemctl daemon-reload` | unit fayllarni diskdan qayta o'qish |
| `systemctl cat X`, `systemctl show X -p Restart` | amaldagi unit matni va xususiyatlari |
| `systemctl list-dependencies X` | bog'liqliklar daraxti |

`.service` kengaytmasini yozmasa ham bo'ladi. O'zgartiruvchi buyruqlar `sudo` talab qiladi, o'qiydiganlari yo'q.

### Mexanizm: start va enable

Bular mustaqil ikki narsa:

- `start` hozir ishga tushiradi, reboot'dan keyingi holatga ta'sir qilmaydi.
- `enable` hozir hech narsani ishga tushirmaydi: unit'ning `[Install]` bo'limiga qarab symlink yaratadi. Boot paytida `multi-user.target` ko'tarilganda `multi-user.target.wants/` papkasidagi hamma symlink'lar bo'yicha servislar ham tortiladi.

```
ubuntu@lab:~$ sudo systemctl disable cron
Removed "/etc/systemd/system/multi-user.target.wants/cron.service".
ubuntu@lab:~$ systemctl is-enabled cron; systemctl is-active cron
disabled
active
ubuntu@lab:~$ sudo systemctl enable cron
Created symlink /etc/systemd/system/multi-user.target.wants/cron.service → /usr/lib/systemd/system/cron.service.
```

O'qiymiz: `disable` bitta symlink'ni o'chirdi, boshqa hech narsa qilmadi. Shuning uchun servis `disabled`, lekin hali `active`: jarayon ishlab turibdi, faqat keyingi boot'da ko'tarilmaydi. `enable` symlink'ni qaytardi. `mask` esa kuchliroq: unit nomini `/etc/systemd/system/` da `/dev/null` ga symlink qiladi, eng ustun katalogda "bo'sh" unit paydo bo'lgani uchun uni hech kim (qo'lda ham, boshqa unit bog'liqligi orqali ham) ishga tushira olmaydi.

**Tuzoq: `start` qilib `enable` ni unutish.** Servis oylab ishlaydi, birinchi reboot'dan keyin ko'tarilmaydi. Har doim `enable --now`, va `is-enabled` bilan tekshiring.

**Tuzoq: unit faylni o'zgartirib `daemon-reload` qilmaslik.** systemd unit'larni xotirada saqlaydi, faylni har safar qayta o'qimaydi. Fayl o'zgarganda `systemctl status` ogohlantiradi, lekin eski ta'rif ishlashda davom etadi. Tartib: tahrir, `daemon-reload`, `restart`.

### Misol: status ni o'qish

```
ubuntu@lab:~$ systemctl status cron
● cron.service - Regular background program processing daemon
     Loaded: loaded (/usr/lib/systemd/system/cron.service; enabled; preset: enabled)
     Active: active (running) since <sana>; 2h 13min ago
       Docs: man:cron(8)
   Main PID: <PID> (cron)
      Tasks: 1 (limit: <N>)
     Memory: <N>K (peak: <N>M)
        CPU: 35ms
     CGroup: /system.slice/cron.service
             └─<PID> /usr/sbin/cron -f -P

<sana> lab systemd[1]: Started cron.service - Regular background program processing daemon.
```

- Birinchi qator: nuqta rangi holatni bildiradi (yashil ishlayapti, oq to'xtagan, qizil failed), keyin unit nomi va `Description`.
- `Loaded`: fayl topildi va o'qildi; qavsda fayl yo'li, `enabled` (boot'da ko'tariladi), `preset: enabled` distributivning standart tavsiyasi.
- `Active`: `active (running)` jarayon ishlayapti. Boshqa qiymatlar: `inactive (dead)` to'xtatilgan, `failed` xato bilan tugagan, `activating (auto-restart)` restart kutilmoqda.
- `Main PID`: asosiy jarayon. `Tasks`, `Memory`, `CPU` butun cgroup bo'yicha hisob.
- `CGroup`: cgroup yo'li va ichidagi barcha jarayonlar daraxti.
- Pastda shu unit'ning oxirgi journal qatorlari (8-bo'lim).

Yiqilgan servisda sabab ko'rinadi: `code=exited, status=1/FAILURE` (dastur o'zi chiqdi) yoki `code=killed, signal=KILL` (signal o'ldirdi). systemd'ning o'z kodlari ham bor, ular dastur ishga tushmasdan oldingi xatoni bildiradi:

| Status | Ma'nosi |
|--------|---------|
| `203/EXEC` | `ExecStart` dagi faylni bajarib bo'lmadi (yo'l noto'g'ri, `x` huquqi yo'q) |
| `217/USER` | `User=` dagi foydalanuvchi mavjud emas |
| `200/CHDIR` | `WorkingDirectory=` ga o'tib bo'lmadi |

### Real ishda qachon kerak

- Deploy skriptida `systemctl is-active --quiet api || exit 1`: exit code orqali tekshiruv, matnni parse qilish kerak emas.
- "Sayt ishlamayapti" chaqiruvida birinchi buyruq `systemctl status <servis>`, ikkinchisi `journalctl -u <servis> -n 50`.

### Nima uchun shunday

`start` va `enable` ajratilgani uchun to'rt holatning hammasi mumkin va hammasi kerak: hozir ishlasin va boot'da ham (`enable --now`), hozir ishlasin lekin boot'da emas (bir martalik sinov), boot'da ishlasin lekin hozir emas (keyingi reboot'ga tayyorlash), umuman ishlamasin. `pm2` da ham xuddi shu ajratish bor: `pm2 start` hozirgi holat, `pm2 save` va `pm2 startup` boot holati. Symlink tanlangani sababi oddiylik: "boot'da nima ko'tariladi" savoliga `ls` javob beradi, maxsus ma'lumotlar bazasi yo'q.

## 3. .service unit yozish

### Namuna

`/etc/systemd/system/demoapp.service`:

```
[Unit]
Description=Demo HTTP app
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=demoapp
Group=demoapp
WorkingDirectory=/srv/demoapp
EnvironmentFile=/etc/demoapp/demoapp.env
ExecStart=/usr/bin/python3 -m http.server ${PORT}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Uch bo'lim: `[Unit]` tavsif va bog'liqliklar, `[Service]` qanday ishga tushirish, `[Install]` `enable` nima qilishi. Format INI'ga o'xshash: `Kalit=qiymat`, kalitlar katta-kichik harfga sezgir, `#` bilan boshlangan qator izoh.

### Mexanizm: ExecStart shell emas

systemd `ExecStart=` qatorini o'zi so'zlarga bo'ladi va to'g'ridan-to'g'ri `execve` system call'i bilan ishga tushiradi, orada `bash` yo'q. Oqibatlari:

- Binary to'liq yo'l bilan yoziladi (`/usr/bin/python3`). Yo'lni `command -v python3` aytadi.
- `|`, `>`, `&&`, `~`, glob (`*`) ishlamaydi: ular dasturga oddiy argument bo'lib boradi. Shell kerak bo'lsa aniq yozing: `ExecStart=/bin/bash -c '...'`, lekin yaxshisi alohida skript fayl.
- `cd papka && buyruq` o'rniga `WorkingDirectory=`.
- `User=`/`Group=` berilmasa servis **root** sifatida ishlaydi.
- Dastur foreground'da qolishi kerak. O'zini background'ga o'tkazadigan (`&`, `--daemon`) dastur `Type=simple` da "tugadi" deb hisoblanadi va systemd qolgan jarayonlarni o'ldiradi.

Yozgandan keyin sintaksisni tekshiring: `systemd-analyze verify /etc/systemd/system/demoapp.service` (xato bo'lmasa hech narsa chiqarmaydi).

### Type

| `Type=` | systemd qachon "ishga tushdi" deb hisoblaydi | Qachon |
|---------|----------------------------------------------|--------|
| `simple` (standart) | fork qilingan zahoti | foreground'da ishlaydigan zamonaviy dastur |
| `exec` | binary muvaffaqiyatli exec qilingach | `simple` kabi, lekin `ExecStart` xatosi `start` paytida ko'rinadi |
| `notify` | dastur `sd_notify` orqali "tayyorman" degach | buni qo'llaydigan dasturlar (sshd, nginx, PostgreSQL paketlari) |
| `forking` | ota jarayon chiqqach (eski uslubdagi daemon) | faqat eski dasturlar, `PIDFile=` bilan |
| `oneshot` | jarayon tugagach | skript, migratsiya, timer chaqiradigan vazifa |

Node, Go, Python servislari uchun deyarli har doim `simple` yoki `exec`.

### To'xtatish

`systemctl stop` servisning asosiy jarayoniga `SIGTERM` (`KillSignal=`) yuboradi, `TimeoutStopSec=` (standart 90 soniya) kutadi, keyin cgroup'da qolgan hamma jarayonga `SIGKILL`. Dasturingiz `SIGTERM` ni ushlab tartibli tugashi kerak (9-dars): Node'da `process.on('SIGTERM', ...)` ichida serverni yopish va ochiq so'rovlarni tugatish. `systemctl kill -s HUP demoapp` unit jarayonlariga istalgan signalni yuboradi.

### Real ishda qachon kerak

- Har qanday o'z dasturingizni (API, worker, bot) serverga qo'yganda. Paketdan kelgan dasturlar (nginx, PostgreSQL) unit'i bilan keladi, o'zingiznikiga siz yozasiz.
- Ansible va cloud-init'da deploy aynan shu: binary'ni ko'chirish, unit faylni qo'yish, `daemon-reload`, `enable --now`.

### Nima uchun shunday

Shell'siz `ExecStart` ataylab qilingan: shell qo'shimcha jarayon (signal unga boradi, dasturga emas), quoting xatolari va environment'ga yashirin bog'liqlik degani. Unit'da hamma narsa aniq yozilgani uchun servis har boot'da, har mashinada bir xil ishga tushadi. Dockerfile'dagi `CMD ["node","server.js"]` (exec shakli) va `CMD node server.js` (shell shakli) farqi aynan shu g'oya. Muqobili `nohup node server.js &` yoki `screen`: reboot'da ko'tarilmaydi, yiqilsa turmaydi, log yo'qoladi.

## 4. Restart siyosatlari

### Bu nima

`Restart=` jarayon tugaganda systemd nima qilishini belgilaydi:

| `Restart=` | Qachon qayta ishga tushiradi |
|------------|------------------------------|
| `no` (standart) | hech qachon |
| `on-failure` | nol bo'lmagan exit code, signaldan o'lim, timeout, watchdog |
| `on-abnormal` | signal, timeout, watchdog (nol bo'lmagan exit code'da yo'q) |
| `on-success` | faqat toza chiqishda |
| `always` | har qanday tugashda |

### Mexanizm

systemd asosiy jarayonning ota-jarayoni, shuning uchun kernel unga bola qanday tugaganini aytadi: exit code yoki signal raqami (9-dars). systemd buni "toza" yoki "xato" deb tasniflaydi va siyosatga qaraydi:

- Exit code 0 va `SIGTERM`, `SIGINT`, `SIGHUP`, `SIGPIPE` signallari "toza chiqish": `on-failure` ularda ishlamaydi.
- `systemctl stop` bilan to'xtatilgan servis hech qaysi siyosatda qayta ko'tarilmaydi: bu administrator xohishi.
- `RestartSec=` urinishlar orasidagi pauza, standart 100 ms. Ma'lumotlar bazasini kutayotgan servis uchun juda kam, 3–10 soniya qo'ying.

### Misol: journal'da restart

`Restart=on-failure`, `RestartSec=3` bo'lgan servisning asosiy jarayoni `SIGKILL` bilan o'ldirilganda journal (bu misoldagi `heartbeat.service` "Birga bajaramiz" bo'limida yoziladi):

```
<vaqt> lab systemd[1]: heartbeat.service: Main process exited, code=killed, status=9/KILL
<vaqt> lab systemd[1]: heartbeat.service: Failed with result 'signal'.
<vaqt> lab systemd[1]: heartbeat.service: Scheduled restart job, restart counter is at 1.
<vaqt> lab systemd[1]: Started heartbeat.service - Heartbeat demo.
```

Birinchi qator: jarayon qanday tugadi (`killed`, 9-signal). Ikkinchi: systemd natijani `signal` deb tasnifladi, bu "xato" toifasi. Uchinchi: siyosat ishladi, restart rejalashtirildi, hisoblagich 1. To'rtinchi: 3 soniyadan keyin yangi jarayon ishga tushdi. Hisoblagichni `systemctl show heartbeat -p NRestarts` ham ko'rsatadi.

### Start limit

Cheksiz restart sikli tizimni band qilmasligi uchun chegara bor: standart holatda 10 soniya ichida 5 martadan ko'p ishga tushish urinishi bo'lsa (`StartLimitIntervalSec=10s`, `StartLimitBurst=5`, ikkalasi `[Unit]` bo'limida), systemd taslim bo'ladi: unit `failed` holatiga o'tadi, logda `Start request repeated too quickly`. Shundan keyin `Restart=` ishlamaydi, qo'lda `systemctl reset-failed <nom>` va `start` kerak.

**Tuzoq: `Restart=always` muammoni yashiradi.** Har 5 daqiqada yiqilib qayta turadigan servis `active (running)` ko'rinadi. `NRestarts` va journal'dagi restart yozuvlarini kuzating, monitoringda restart soniga alert qo'ying.

### Real ishda qachon kerak

- O'z servislaringiz uchun odatiy tanlov `Restart=on-failure` va `RestartSec=3..10`.
- Tungi yiqilishni ertalab `NRestarts` va `journalctl -u X --since yesterday | grep -i restart` bilan topasiz.

### Nima uchun shunday

Dastur baribir yiqiladi: xotira tugaydi, baza uziladi, kodda xato chiqadi. Odam tunda uyg'onib `start` bosishi o'rniga supervisor qayta ko'taradi. `pm2` ning asosiy vazifasi ham shu, Kubernetes'da `restartPolicy` va CrashLoopBackOff aynan shu g'oyaning davomi. Start limit esa teskari xavfdan himoya: har 100 ms da yiqilib turadigan servis CPU va logni to'ldiradi, shuning uchun systemd to'xtab odamni kutadi.

## 5. Bog'liqliklar

### Bu nima

Servislar bir-biriga tayanadi: API bazasiz ishlamaydi, baza disk mount bo'lmasa ishlamaydi. Ikki mustaqil o'q bor, ularni aralashtirish eng ko'p uchraydigan xato:

| Direktiva | O'q | Ma'nosi |
|-----------|-----|---------|
| `Wants=B` | talab (yumshoq) | A ishga tushganda B ham ishga tushirilsin; B yiqilsa A baribir davom etadi |
| `Requires=B` | talab (qattiq) | B ishga tushmasa A ham ishga tushmaydi; B to'xtatilsa A ham to'xtatiladi |
| `After=B` | tartib | ikkalasi ham ishga tushayotgan bo'lsa, A B dan keyin |
| `Before=B` | tartib | teskarisi |

### Mexanizm

systemd `start A` so'rovini olganda **tranzaksiya** tuzadi: A va u talab qilgan (`Wants=`, `Requires=`) barcha unit'lar ro'yxati. Keyin shu ro'yxatni `After=`/`Before=` bo'yicha tartiblaydi; tartib ko'rsatilmagan unit'lar parallel ishga tushadi.

- `After=` hech narsani ishga tushirmaydi, faqat navbatni belgilaydi. `Wants=`/`Requires=` tartibni belgilamaydi. Amalda deyarli har doim juft yoziladi: `Wants=postgresql.service` va `After=postgresql.service`.
- `After=B` "B tayyor bo'lguncha kut" degani emas, "B ishga tushdi deb hisoblanguncha kut" degani. `Type=simple` servis fork qilingan zahoti "ishga tushgan" hisoblanadi, port hali ochilmagan bo'lishi mumkin. Shuning uchun dasturning o'zi ulanishni qayta urinishi kerak, `Restart=on-failure` bilan `RestartSec=` shuni qoplaydi.
- `network.target` tarmoq sozlanishi boshlanganini bildiradi, IP borligini emas. Tarmoq kerak bo'lgan servis uchun `After=network-online.target` va `Wants=network-online.target`.
- `[Install]` dagi `WantedBy=multi-user.target` teskari yo'nalishdagi `Wants=`: `enable` qilinganda target servisni "xohlaydi" (2-bo'limdagi symlink shu).

### Misol

```
ubuntu@lab:~$ systemctl list-dependencies cron | head -6
cron.service
● ├─system.slice
● └─sysinit.target
●   ├─apparmor.service
●   ├─dev-hugepages.mount
●   ├─dev-mqueue.mount
```

Daraxt `cron` nimalarni talab qilishini ko'rsatadi: `system.slice` (cgroup joyi) va `sysinit.target` (tizimning asosiy tayyorgarligi), ularni siz yozmagansiz, systemd har servisga standart qo'shadi. `--reverse` flag'i teskari savolga javob beradi: bu unit'ni kim talab qiladi. Faqat tartibni ko'rish uchun `systemctl show cron -p After`.

### Real ishda qachon kerak

- API va baza bitta serverda bo'lsa: API unit'ida bazaga `Wants=` va `After=`.
- Servis reboot'dan keyin "ba'zan" ko'tarilmasa, sabab ko'pincha tartib: `After=` yo'q va u kerakli narsadan oldin ishga tushgan.

### Nima uchun shunday

Ikki o'q ajratilgani parallel boot uchun: systemd faqat aytilgan joyda kutadi, qolganini bir vaqtda ko'taradi, shuning uchun tizim soniyalarda yuklanadi. `docker compose` dagi `depends_on` ham xuddi shu cheklovga ega: u tartibni beradi, tayyorlikni emas (buning uchun healthcheck kerak). Muqobil yondashuv "hamma narsani ketma-ket" (SysV'dagi raqamlangan skriptlar) sodda, lekin sekin va bitta osilgan servis butun boot'ni to'xtatadi.

## 6. Environment va secret'lar

### Bu nima

Servisga sozlamalar (port, log darajasi, baza manzili) environment o'zgaruvchilari orqali beriladi, xuddi Node'dagi `process.env` kabi:

```
[Service]
Environment=LOG_LEVEL=info
EnvironmentFile=/etc/demoapp/demoapp.env
```

### Mexanizm

`EnvironmentFile` ni systemd o'zi (root sifatida) o'qiydi va jarayonni yaratayotganda uning environment'iga joylaydi. Format shell skript emas: har qatorda `KEY=value`, `export` yozilmaydi, `$VAR` kengaytirilmaydi, `#` bilan boshlangan qator izoh. Bu `dotenv` fayliga o'xshaydi, lekin uni kutubxona emas, systemd o'qiydi. `EnvironmentFile=-/yo'l` dagi `-` "fayl bo'lmasa xato emas" degani.

`ExecStart=` ichida `${PORT}` va `$PORT` shakllari systemd tomonidan almashtiriladi (shell emas, faqat oddiy almashtirish). Dasturning o'zi esa environment'ni odatdagidek o'qiydi.

Secret'lar uchun: fayl `root:root`, huquqi `600`. systemd uni root sifatida o'qib, jarayonga environment qilib beradi, servis foydalanuvchisi faylni o'qiy olishi shart emas. Unit faylning o'ziga `Environment=DB_PASSWORD=...` yozmang: unit fayllar hammaga o'qishga ochiq va `systemctl show` orqali ko'rinadi.

### Misol: jarayon nimani ko'ryapti

Ishlab turgan servisning haqiqiy environment'i `/proc/<PID>/environ` da (1-dars), yozuvlar nol bayt bilan ajratilgan:

```
ubuntu@lab:~$ sudo cat /proc/$(systemctl show cron -p MainPID --value)/environ | tr '\0' '\n'
LANG=C.UTF-8
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
INVOCATION_ID=<hex>
JOURNAL_STREAM=<N>:<N>
SYSTEMD_EXEC_PID=<PID>
```

E'tibor bering: bor-yo'g'i bir necha o'zgaruvchi. `HOME`, `USER`, `NVM_DIR`, sizning `~/.bashrc` dagi narsalar yo'q. `PATH` ham systemd'ning qat'iy standart qiymati, sizning terminaldagi `PATH` emas.

**Tuzoq: login environment'ga tayanish.** Servis sizning `~/.bashrc`, `PATH`, `nvm` sozlamalaringizni ko'rmaydi (5-dars: ular interaktiv shell'da yuklanadi). Terminalda ishlagan buyruq unit'da `203/EXEC` yoki "command not found" berishining sababi shu. Hamma yo'llar to'liq, hamma o'zgaruvchilar unit'da aniq.

### Resurs limiti va himoya

Unit cgroup orqali cheklanadi va kernel namespace'lari orqali izolyatsiya qilinadi, eng foydalilari:

```
[Service]
MemoryMax=300M
CPUQuota=50%
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/var/lib/demoapp
```

`MemoryMax` dan oshgan servisni cgroup OOM killer o'ldiradi (8-dars), `status` da `Result: oom-kill` ko'rinadi. `CPUQuota=50%` bitta yadroning yarmi. `NoNewPrivileges` jarayon `setuid` binary orqali huquq oshira olmasligini kafolatlaydi (10-dars). `ProtectSystem=strict` butun fayl tizimini servis uchun read-only qiladi, yozish kerak joylar `ReadWritePaths=` bilan ochiladi. `ProtectHome` `/home` va `/root` ni yashiradi. `PrivateTmp` servisga alohida `/tmp` beradi. Unit'ning himoya bahosini `systemd-analyze security <nom>` beradi (0 dan 10 gacha, kichigi yaxshi).

### Real ishda qachon kerak

- Bitta binary'ni staging va production'da turli sozlama bilan ishlatish: unit bir xil, `.env` fayl boshqa.
- Buzilgan servis butun serverni olib ketmasligi uchun: `MemoryMax` qo'shni servislarni, sandbox esa fayl tizimini himoya qiladi.

### Nima uchun shunday

Sozlamani koddan ajratish "12-factor app" tamoyili: bir xil artefakt har muhitda. Secret'ni root o'qiydigan faylda saqlash dastur buzilgan taqdirda ham hujumchi faylni qayta o'qiy olmasligi uchun (u faqat xotiradagi qiymatni ko'radi). Sandbox opsiyalari konteynerlar ishlatadigan o'sha kernel mexanizmlari (namespace, cgroup): systemd servisi amalda "image'siz yengil konteyner". Muqobili Docker, u izolyatsiyani standart beradi, lekin alohida qatlam qo'shadi.

## 7. Drop-in override

### Bu nima

Paket o'rnatgan unit'ni o'zgartirishning to'g'ri usuli: faylni almashtirish emas, ustiga qo'shimcha yozish. **Drop-in** bu `<unit>.d/` papkasidagi `.conf` fayl bo'lib, asosiy unit bilan birlashtiriladi.

### Mexanizm

```
ubuntu@lab:~$ sudo systemctl edit cron
```

Editor ochiladi, izohlar orasidagi belgilangan joyga faqat o'zgartirmoqchi bo'lgan qatorlarni yozasiz:

```
[Service]
RestartSec=5
```

Saqlaganda `/etc/systemd/system/cron.service.d/override.conf` yaratiladi va `daemon-reload` avtomatik bajariladi. systemd unit'ni yuklaganda avval asosiy faylni, keyin `.d/` dagi fayllarni alifbo tartibida o'qiydi; keyingi qiymat oldingisini yopadi.

```
ubuntu@lab:~$ systemctl cat cron | tail -4

# /etc/systemd/system/cron.service.d/override.conf
[Service]
RestartSec=5
ubuntu@lab:~$ sudo systemctl revert cron
Removed "/etc/systemd/system/cron.service.d/override.conf".
Removed "/etc/systemd/system/cron.service.d".
```

`systemctl cat` har bo'lakni o'z fayl yo'li bilan ko'rsatadi, `status` da esa `Drop-In:` qatori paydo bo'ladi. `revert` barcha override'larni o'chirib paket holatiga qaytaradi.

- Ro'yxat tipidagi direktivalar (`ExecStart=`, `Environment=`, `After=`) qo'shiladi, almashtirilmaydi. `ExecStart` ni almashtirish uchun avval bo'sh qiymat bilan tozalash kerak: `ExecStart=` qatori, keyin yangi `ExecStart=/new/command`.
- `systemctl edit --full X` butun faylning nusxasini `/etc/systemd/system/` ga oladi (paket yangilanishlari endi ta'sir qilmaydi, kam ishlatiladi).
- `systemd-delta` tizimdagi barcha override'larni ko'rsatadi: begona serverda "bu yerda nima o'zgartirilgan" degan savolga javob.

### Real ishda qachon kerak

- Paketdagi nginx yoki PostgreSQL ga `LimitNOFILE=`, `Restart=` yoki environment qo'shish.
- Ansible bilan bitta sozlamani ko'p serverga tarqatish: kichik `override.conf` fayl ko'chiriladi, asosiy unit'ga tegilmaydi.

### Nima uchun shunday

Muammo ikki egadan kelib chiqadi: unit fayl paketniki, sozlama sizniki. Faylni tahrirlasangiz yangilanish uni ustidan yozadi yoki `apt` har safar "qaysi versiyani qoldiray" deb so'raydi. Drop-in ikkalasini ajratadi: paket o'z faylini erkin yangilaydi, sizning farqingiz alohida turadi. Frontend'dagi o'xshashi: `node_modules` ichidagi faylni tahrirlamaysiz, konfiguratsiya yoki `patch-package` bilan ustidan yozasiz.

## 8. Loglar: journalctl -u

### Bu nima va mexanizm

Servisning stdout va stderr'i systemd tomonidan `systemd-journald` ga ulangan (8-dars). Dastur yozgan har qator journal'ga metama'lumot bilan tushadi: qaysi unit, qaysi PID, qaysi UID, qachon. Dastur log faylni o'zi boshqarishi shart emas: `console.log` yoki `print` yetadi.

```
$ journalctl -u demoapp -f                    # follow, like tail -f
$ journalctl -u demoapp -n 100 --no-pager     # last 100 lines
$ journalctl -u demoapp --since "10 min ago" -p warning
$ journalctl -u demoapp -b -o json-pretty | head -40
```

### Misol

```
ubuntu@lab:~$ journalctl -u cron -n 3 --no-pager
<vaqt> lab systemd[1]: Started cron.service - Regular background program processing daemon.
<vaqt> lab cron[<PID>]: (CRON) INFO (pidfile fd = 3)
<vaqt> lab CRON[<PID>]: (root) CMD (   cd / && run-parts --report /etc/cron.hourly)
```

Har qator: vaqt, hostname, kim yozgani va PID kvadrat qavsda, xabar. Birinchi qatorni `systemd[1]` yozgan (PID 1 ning o'zi: "servisni ishga tushirdim"), qolganini dastur. Ya'ni systemd'ning o'z xabarlari (ishga tushdi, yiqildi, restart rejalashtirildi) va dastur chiqishi bitta oqimda, vaqt tartibida turadi. `-o json-pretty` har yozuvning barcha maydonlarini (`_PID`, `_UID`, `_SYSTEMD_UNIT`, `PRIORITY`) ko'rsatadi.

**Tuzoq: bufer tufayli log ko'rinmaydi.** Ko'p runtime stdout terminal bo'lmasa chiqishni buferlaydi: Python'da loglar daqiqalab kechikadi yoki jarayon o'ldirilganda yo'qoladi. Python uchun `Environment=PYTHONUNBUFFERED=1`.

### Real ishda qachon kerak

- Yiqilgan servisda birinchi savol "nima dedi": `journalctl -u X -n 50 --no-pager`.
- Deploy'dan keyin `journalctl -u X -f` ni ochib qo'yib, birinchi so'rovlarni kuzatish.

### Nima uchun shunday

Har dastur o'z log faylini yozgan davrda har biriga alohida rotatsiya, alohida huquq va alohida format kerak edi, dastur ishga tushmasdan yiqilsa esa log umuman bo'lmasdi. stdout'ga yozish va yig'ishni supervisor'ga topshirish hozir standart: Docker (`docker logs`) va Kubernetes (`kubectl logs`) ham aynan shunday ishlaydi, shuning uchun shu uslubda yozilgan dastur uchala muhitda o'zgarishsiz ishlaydi.

## 9. Timer va cron

### Bu nima

Davriy vazifa (backup, hisobot, kesh tozalash) uchun ikki fayl: nima qilishni aytadigan `.service` (odatda `Type=oneshot`) va qachonligini aytadigan bir xil nomli `.timer`.

```
# /etc/systemd/system/report.timer
[Unit]
Description=Run report every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
```

Timer yoqiladi, servis emas: `sudo systemctl enable --now report.timer`. Servisni qo'lda sinash: `sudo systemctl start report.service`.

### Mexanizm

Timer unit vaqt kelganda bir xil nomli servisga `start` beradi, xolos. Qolgan hamma narsa (user, environment, limitlar, loglar) oddiy servis qoidalari bo'yicha. Servis hali ishlayotgan bo'lsa yangi `start` hech narsa qilmaydi, ustma-ust ishga tushish bo'lmaydi.

- `OnCalendar=` kalendar ifodasi, formati `hafta-kuni yil-oy-kun soat:daqiqa:soniya`: `daily`, `hourly`, `Mon *-*-* 09:00:00`, `*-*-01 03:30:00`. `*:0/5` "har soatning 0-daqiqasidan boshlab har 5 daqiqada".
- `OnBootSec=5min`, `OnUnitActiveSec=1h` monoton timerlar: boot'dan yoki oxirgi ishga tushishdan keyin.
- `Persistent=true`: mashina o'chiq bo'lgani uchun o'tkazib yuborilgan ishga tushish yoqilgandan keyin bajariladi.
- `RandomizedDelaySec=` tasodifiy kechikish: yuzlab server bir soniyada bir xil ishni boshlamasligi uchun.

### Misol: ifodani tekshirish va timerlar ro'yxati

```
ubuntu@lab:~$ systemd-analyze calendar "Mon..Fri *-*-* 09:00:00"
  Original form: Mon..Fri *-*-* 09:00:00
Normalized form: Mon..Fri *-*-* 09:00:00
    Next elapse: <kun> <sana> 09:00:00 UTC
       From now: <N>h left
ubuntu@lab:~$ systemctl list-timers --no-pager | head -4
NEXT                        LEFT     LAST                        PASSED  UNIT                 ACTIVATES
<sana> <vaqt> UTC           <N>min   <sana> <vaqt> UTC           <N>min ago apt-daily.timer   apt-daily.service
...
```

`systemd-analyze calendar` ifodani hech narsa ishga tushirmasdan tekshiradi: `Normalized form` systemd uni qanday tushunganini, `Next elapse` keyingi ishga tushish vaqtini ko'rsatadi. Vaqt mintaqasiga e'tibor bering: VM'da UTC. `list-timers` ustunlari: `NEXT` keyingi ishga tushish, `LEFT` qancha qoldi, `LAST` va `PASSED` oxirgisi, `UNIT` timer, `ACTIVATES` qaysi servisni ishga tushiradi.

### cron

cron bu eski va sodda rejalashtiruvchi daemon: har daqiqada jadvallarni tekshiradi. `crontab -e` foydalanuvchi jadvali, `/etc/cron.d/` tizim fayllari (ularda qo'shimcha user maydoni bor). Besh maydon `daqiqa soat kun oy hafta-kuni` va buyruq:

```
*/5 * * * * /usr/local/bin/report.sh
```

| | cron | systemd timer |
|---|------|---------------|
| Sozlash | bitta qator | ikki fayl |
| Loglar | o'zingiz yo'naltirasiz, aks holda mail yoki yo'qoladi | journal, `journalctl -u` |
| O'tkazib yuborilgan vazifa | bajarilmaydi | `Persistent=true` |
| Oldingi ishga tushish tugamagan bo'lsa | ustiga yana bittasi ishga tushadi | ishga tushirmaydi, servis hali faol |
| Bog'liqliklar, limitlar, `User=`, sandbox | yo'q | servis unit'ning hamma imkoniyati |
| Qo'lda sinash | buyruqni nusxalab, boshqa environment'da | `systemctl start X.service`, aynan o'sha muhitda |
| Holatni ko'rish | yo'q | `list-timers`, `status` |

### Real ishda qachon kerak

- Tungi backup, sertifikat yangilash (`certbot.timer`), log tozalash, hisobot.
- Eski serverda `crontab -l` va `ls /etc/cron.d/` ni o'qish: "bu skript qayerdan ishga tushyapti" savoliga javob ko'pincha shu yerda.

### Nima uchun shunday

cron 1970-yillardan beri bor va "bitta qator" soddaligi tufayli hali ham hamma joyda uchraydi, uni o'qiy olish kerak. Lekin u vazifa natijasini kuzatmaydi: skript bir oy davomida xato bilan tugayotganini hech kim bilmasligi mumkin. Timer vazifani oddiy servisga aylantiradi, shuning uchun holat, log, limit va bog'liqliklar tekinga keladi. Yangi vazifalar uchun timer afzal; Kubernetes'dagi `CronJob` cron sintaksisini saqlab, timer g'oyalarini (holat, takror ishga tushmaslik siyosati) qo'shgan.

## 10. Target'lar

### Bu nima va mexanizm

Target o'zi hech narsa bajarmaydi: u unit'larni guruhlaydi va boot bosqichlarini belgilaydi. Boot paytida systemd standart target'ni "start" qiladi, u esa `Wants=` zanjiri orqali butun tizimni tortadi (5-bo'limdagi tranzaksiya).

| Target | Ma'nosi |
|--------|---------|
| `multi-user.target` | to'liq ishlaydigan tizim, grafik interfeyssiz. Serverlarning standart holati |
| `graphical.target` | `multi-user` va grafik login. Ish stansiyalari |
| `rescue.target` | bitta foydalanuvchi, minimal servislar |
| `emergency.target` | faqat root shell, root fayl tizimi read-only. Buzilgan `fstab` da shu yerga tushasiz (13-dars) |
| `network-online.target`, `timers.target`, `sockets.target` | sinxronlash nuqtalari |

### Misol

```
ubuntu@lab:~$ systemctl get-default
graphical.target
ubuntu@lab:~$ systemd-analyze
Startup finished in <N>s (kernel) + <N>s (userspace) = <N>s
graphical.target reached after <N>s in userspace.
```

`get-default` boot qaysi target'gacha borishini ko'rsatadi. Ubuntu cloud image'larida bu ko'pincha `graphical.target`, garchi grafik muhit o'rnatilmagan bo'lsa ham: `graphical.target` `multi-user.target` ni o'z ichiga oladi, display manager yo'qligi sababli amalda farq qilmaydi. `systemd-analyze` boot vaqtini kernel va user space bo'yicha ajratadi (1-dars), `systemd-analyze blame` har unit qancha vaqt olganini ko'rsatadi. `set-default` standart target'ni o'zgartiradi, `systemctl isolate rescue.target` hozir o'tkazadi (VM'da SSH uziladi, sinamang).

### Real ishda qachon kerak

- O'z unit'ingizda `WantedBy=` ga nima yozishni bilish: deyarli har doim `multi-user.target`, timer uchun `timers.target`.
- Server yuklanmay emergency shell'ga tushganda nima bo'lganini tushunish (13-darsda `fstab` bilan).

### Nima uchun shunday

SysV init'da 0 dan 6 gacha raqamlangan runlevel'lar bor edi va tizim bir vaqtda faqat bittasida turardi. Target'lar nomlangan, bir-birini o'z ichiga oladi va bir vaqtda bir nechtasi faol bo'ladi, shuning uchun "tarmoq tayyor", "timerlar tayyor" kabi oraliq nuqtalarni ifodalash mumkin. `enable` ning symlink'i nima uchun aynan `multi-user.target.wants/` ga tushishi ham shundan: servis "tizim to'liq ishlaydigan holatga kelganda meni ham ko'tar" deydi.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Init tizimi | kernel ishga tushiradigan birinchi jarayon (PID 1), qolgan servislarni ko'taradi va kuzatadi |
| Daemon (servis) | terminalga bog'lanmagan, fonda doimiy ishlaydigan dastur |
| Unit | systemd boshqaradigan bitta obyektning matnli ta'rifi (`.service`, `.timer`, `.target`) |
| cgroup | jarayonlar guruhiga resurs hisobi va limit qo'yadigan kernel mexanizmi |
| `daemon-reload` | systemd'ga unit fayllarni diskdan qayta o'qitish |
| `enable` | boot'da ishga tushish uchun target'ning `.wants/` papkasiga symlink yaratish |
| `mask` | unit'ni `/dev/null` ga symlink qilib, har qanday ishga tushirishni taqiqlash |
| Drop-in | `<unit>.d/*.conf` fayl, asosiy unit ustiga qo'shiladigan o'zgarish |
| Target | unit'larni guruhlovchi sinxronlash nuqtasi, o'zi hech narsa bajarmaydi |
| Start limit | qisqa vaqt ichida juda ko'p ishga tushish urinishidan keyin systemd'ning to'xtashi |
| Tranzaksiya | bitta `start` so'rovi uchun systemd tuzadigan unit'lar va ularning tartibi |
| `EnvironmentFile` | servisga beriladigan `KEY=value` qatorlari fayli, shell skript emas |
| Oneshot | ishini bajarib tugaydigan servis turi (skript, migratsiya) |
| Timer | vaqt kelganda bir xil nomli servisni ishga tushiradigan unit |
| cron | besh maydonli jadval bo'yicha buyruq ishga tushiradigan eski rejalashtiruvchi daemon |
| Sandbox | servis ko'ra oladigan fayl tizimi va huquqlarni cheklash (`ProtectSystem=` va boshqalar) |
| Socket activation | systemd portni o'zi tinglab, birinchi ulanishda servisni ishga tushirishi |

## Tuzoqlar

- `start` qilib `enable` ni unutish: servis birinchi reboot'gacha ishlaydi.
- Unit faylni tahrirlab `daemon-reload` qilmaslik va "o'zgarish ishlamayapti" deyish.
- `/usr/lib/systemd/system/` dagi paket faylini tahrirlash. Yangilanishda yo'qoladi; `systemctl edit` ishlating.
- `User=` yozmaslik: servis root sifatida ishlaydi.
- `After=` ni bog'liqlik deb o'ylash (u faqat tartib), yoki `Wants=` ni tartib deb o'ylash.
- `ExecStart=` da shell sintaksisi (`|`, `>`, `&&`, `cd ... &&`) yozish. `WorkingDirectory=` va alohida skript ishlating.
- `Restart=always` bilan crash loop'ni yashirish va restart sonini kuzatmaslik. Yoki aksincha: start limit'ga urilgan servis `failed` da qolib ketganini bilmaslik.
- Dasturni unit ichida background'ga o'tkazish (`&`, `nohup`, `--daemon`) va `Type=simple` qoldirish.
- Secret'ni unit faylning `Environment=` qatoriga yozish.
- Terminalda ishlagan buyruqni unit'ga ko'chirib, `PATH` va shell environment farqini hisobga olmaslik.
- Timer'ning vaqt mintaqasini unutish: server UTC'da, `OnCalendar=09:00` Toshkent vaqti bilan 14:00.
- macOS host'ida `systemctl` qidirish: u yerda yo'q, hamma narsa `lab` VM'da. Zorin host'ida esa unit o'zgartirmang, faqat o'qing.
- Konteyner ichida `systemctl` ishlatishga urinish: u yerda PID 1 systemd emas.

## Manbalar

- https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html – systemd.unit(5): bog'liqliklar, drop-in, yuklash yo'llari
- https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html – systemd.service(5): Type, Restart, ExecStart (majburiy)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html – systemd.exec(5): User, Environment, sandbox opsiyalari
- https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html – systemd.timer(5)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html – kalendar ifodalari sintaksisi
- https://www.freedesktop.org/software/systemd/man/latest/systemctl.html – systemctl(1)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html – MemoryMax, CPUQuota
- https://www.freedesktop.org/software/systemd/man/latest/systemd-analyze.html – systemd-analyze(1): verify, security, calendar, blame
- https://systemd.io/NETWORK_ONLINE/ – network.target va network-online.target farqi
- https://0pointer.de/blog/projects/systemd-for-admins-1.html – "systemd for Administrators" turkumi (muallifdan)
- https://man7.org/linux/man-pages/man5/crontab.5.html – crontab(5)
- https://documentation.ubuntu.com/multipass/ – Multipass hujjati (`transfer`, `snapshot`)

## Birga bajaramiz

Kichik "heartbeat" servisini noldan yozamiz: har 5 soniyada bir qator log chiqaradigan skript. U vazifalardagi HTTP serverdan boshqa misol, lekin yo'l bir xil: skript, unit, tekshirish, ishga tushirish, log, yiqitish, boot'ga ulash, tozalash. Hammasi `lab` VM ichida.

1. Skriptni yozing va bajariladigan qiling:

```
ubuntu@lab:~$ sudo nano /usr/local/bin/heartbeat.sh
ubuntu@lab:~$ cat /usr/local/bin/heartbeat.sh
#!/bin/bash
# print one line every 5 seconds, forever
while true; do
  echo "beat from PID $$ as $(id -un)"
  sleep 5
done
ubuntu@lab:~$ sudo chmod 755 /usr/local/bin/heartbeat.sh
```

Skript foreground'da qoladi (cheksiz sikl), stdout'ga yozadi. Aynan shunday dastur systemd uchun qulay.

2. Unit faylni yozing (`sudo nano /etc/systemd/system/heartbeat.service`):

```
[Unit]
Description=Heartbeat demo

[Service]
User=demoapp
ExecStart=/usr/local/bin/heartbeat.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

3. Tekshiring, yuklang, ishga tushiring:

```
ubuntu@lab:~$ systemd-analyze verify /etc/systemd/system/heartbeat.service
ubuntu@lab:~$ sudo systemctl daemon-reload
ubuntu@lab:~$ sudo systemctl start heartbeat
ubuntu@lab:~$ systemctl status heartbeat --no-pager
● heartbeat.service - Heartbeat demo
     Loaded: loaded (/etc/systemd/system/heartbeat.service; disabled; preset: enabled)
     Active: active (running) since <sana>; 4s ago
   Main PID: <PID> (heartbeat.sh)
      Tasks: 2 (limit: <N>)
     CGroup: /system.slice/heartbeat.service
             ├─<PID> /bin/bash /usr/local/bin/heartbeat.sh
             └─<PID> sleep 5

<vaqt> lab systemd[1]: Started heartbeat.service - Heartbeat demo.
<vaqt> lab heartbeat.sh[<PID>]: beat from PID <PID> as demoapp
```

`verify` jim, demak sintaksis to'g'ri. `Loaded` qatorida `disabled`: `start` qildik, `enable` hali yo'q. `CGroup` da ikki jarayon: skript va uning bolasi `sleep`, systemd ikkalasini ham ko'radi. Log qatorida `as demoapp`: `User=` ishladi, servis root emas.

4. Yiqitib ko'ring. Asosiy jarayonga `SIGKILL` yuboring va journal'ni kuzating:

```
ubuntu@lab:~$ sudo systemctl kill -s KILL heartbeat
ubuntu@lab:~$ journalctl -u heartbeat -n 5 --no-pager
```

4-bo'limdagi to'rt qatorni ko'rasiz: `code=killed, status=9/KILL`, `Failed with result 'signal'`, `Scheduled restart job, restart counter is at 1`, `Started`. Yangi `beat` qatorida PID boshqa. `systemctl show heartbeat -p NRestarts` `NRestarts=1` beradi.

5. Boot'ga ulang va symlink'ni ko'ring:

```
ubuntu@lab:~$ sudo systemctl enable heartbeat
Created symlink /etc/systemd/system/multi-user.target.wants/heartbeat.service → /etc/systemd/system/heartbeat.service.
ubuntu@lab:~$ systemctl is-enabled heartbeat
enabled
```

6. Unit'ni o'zgartiring: `Description=` ni `Heartbeat demo v2` qiling, `daemon-reload` siz `systemctl status heartbeat` ni ko'ring. Chiqish boshida unit fayl diskda o'zgargani va `daemon-reload` kerakligi haqida ogohlantirish chiqadi, `Description` esa eskicha. `sudo systemctl daemon-reload` dan keyin yangi nom ko'rinadi.

7. Tozalang:

```
ubuntu@lab:~$ sudo systemctl disable --now heartbeat
Removed "/etc/systemd/system/multi-user.target.wants/heartbeat.service".
ubuntu@lab:~$ sudo rm /etc/systemd/system/heartbeat.service /usr/local/bin/heartbeat.sh
ubuntu@lab:~$ sudo systemctl daemon-reload
ubuntu@lab:~$ systemctl status heartbeat
Unit heartbeat.service could not be found.
```

Shu 7 qadamda ko'rganingiz: unit uch bo'limdan iborat (3-bo'lim), `start` va `enable` alohida (2-bo'lim), cgroup bolalarni ham ushlaydi (1-bo'lim), `Restart=on-failure` signaldan o'limda ishlaydi (4-bo'lim), stdout journal'ga tushadi (8-bo'lim), `daemon-reload` siz o'zgarish ko'rinmaydi (2-bo'lim).

---

## Vazifalar

Ish papkasi: `linux/11-systemd/` (`make new m=linux n=11 name=systemd` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. Yozgan unit fayllaringiz, timer'lar va skriptlar nusxasini yoniga saqlang (`demoapp.service`, `report.timer` va hokazo, `multipass transfer` bilan). Hammasi `lab` VM'da; 1 va 4-vazifalardagi host qismi ixtiyoriy va faqat Zorin'da ishlaydi.

### A. systemctl va mavjud unit'lar

1. **Read a unit.** VM'da `systemctl cat ssh` ni oling. Fayl qaysi katalogdan yuklangan, `Type=`, `ExecStart=`, `Restart=`, `WantedBy=` qiymatlari nima? `systemctl status ssh` dagi `Loaded:` va `Active:` qatorlarini so'zma-so'z izohlang; `TriggeredBy:` qatori bo'lsa, u nimani bildiradi (1-bo'limdagi unit tiplari jadvaliga qarang)? Ixtiyoriy: Zorin host'ida xuddi shuni `cron` yoki `docker` unit'i uchun qiling va farqni yozing; macOS'da bu qism yo'q, o'rniga `ps -p 1 -o comm=` natijasini yozing. Yo'nalish: 1-bo'lim "Misol: mavjud unit'ni o'qish", 2-bo'lim "Misol: status ni o'qish".

2. **start vs enable.** VM'da `sudo apt install -y nginx`. `is-active` va `is-enabled` ni oling. `disable` qiling va `/etc/systemd/system/multi-user.target.wants/` da nima o'zgarganini ko'rsating; servis hali ishlayaptimi? `sudo reboot` dan keyin (qayta `multipass shell lab`) holatni tekshiring. Keyin `enable --now` qiling. To'rt kombinatsiyani (active/inactive va enabled/disabled) jadval qilib, har biri qanday hosil bo'lishini yozing. Yo'nalish: 2-bo'lim "Mexanizm: start va enable".

3. **mask.** `nginx` ni `stop` qilib `mask` qiling. `start` qilishga urining: xato nima? `ls -l /etc/systemd/system/nginx.service` nimani ko'rsatadi? `disable` va `mask` farqini va `mask` qachon kerak bo'lishini yozing. `unmask` qiling. Yo'nalish: 2-bo'lim.

4. **Dependencies and targets.** `systemctl get-default`, `systemctl list-dependencies multi-user.target | head -30` va `systemctl list-dependencies --reverse nginx` ni oling. `systemd-analyze blame | head` dan boot'da eng sekin 3 unit'ni toping. Ixtiyoriy (faqat Zorin): host'ning default target'i VM'nikidan farq qiladimi va nima uchun? Yo'nalish: 5 va 10-bo'limlar.

### B. O'z servisingiz

5. **First unit.** `/srv/demoapp/` katalogini yarating, ichiga `index.html` qo'ying, egasi `demoapp`. 3-bo'limdagi namunaga o'xshash `demoapp.service` yozing, lekin avval environment faylsiz: port `ExecStart` da to'g'ridan-to'g'ri `8080`. `systemd-analyze verify`, `daemon-reload`, `enable --now`. Tekshiring: `systemctl status`, `curl localhost:8080`, `ps -o user,pid,cmd -C python3`. Jarayon kim nomidan ishlayapti? Yo'nalish: 3-bo'lim, "Birga bajaramiz" 1–3 qadamlar.

6. **Break ExecStart.** `ExecStart` dagi yo'lni mavjud bo'lmagan binary'ga o'zgartiring, qayta ishga tushiring. `systemctl status` dagi `status=` kodini va journal xabarini yozing. Keyin yo'lni to'g'rilab, `User=` ni mavjud bo'lmagan foydalanuvchiga o'zgartiring: kod nima? Uchinchi tajriba: `ExecStart=/usr/bin/python3 -m http.server 8080 | tee /tmp/log` deb yozib ishga tushiring: `systemd-analyze verify` buni ushladimi, journal'da dastur nima dedi, `|` va undan keyingi so'zlar amalda kimga yetib bordi? Har uchala xatoni tuzating. Yo'nalish: 2-bo'limdagi status kodlari jadvali, 3-bo'lim "Mexanizm: ExecStart shell emas".

7. **Forgot daemon-reload.** Ishlab turgan unit'da `Description=` ni o'zgartiring va `daemon-reload` siz `systemctl restart demoapp`, keyin `systemctl status demoapp` qiling. Ogohlantirishni yozing. Qaysi ta'rif amalda? `daemon-reload` dan keyin qayta tekshiring. Yo'nalish: 2-bo'limdagi tuzoq.

8. **Environment file.** `/etc/demoapp/demoapp.env` yarating (`PORT=9090`, `PYTHONUNBUFFERED=1`), huquqi `600`, egasi root. Unit'ni `EnvironmentFile=` va `${PORT}` bilan qayta yozing. Tekshiring: `curl`, va `sudo cat /proc/<MainPID>/environ | tr '\0' '\n'`. `demoapp` foydalanuvchisi `.env` faylni o'qiy olmasa ham servis nima uchun ishlayapti? Faylga `export PORT=9091` yoki `PORT=$BASE` shaklida yozsangiz nima bo'ladi, sinab ko'ring. Yo'nalish: 6-bo'lim "Mexanizm".

9. **Logs.** `curl` bilan bir necha so'rov yuboring (mavjud bo'lmagan yo'lga ham). `journalctl -u demoapp` da so'rovlar ko'rinadimi? `PYTHONUNBUFFERED` ni olib tashlab farqni tekshiring. Bitta yozuvni `-o json-pretty` bilan chiqarib, `_PID`, `_UID`, `_SYSTEMD_UNIT`, `PRIORITY` maydonlarini toping. `http.server` loglari qaysi prioritet bilan tushgan va nima uchun (stdout yoki stderr)? Yo'nalish: 8-bo'lim.

10. **Graceful stop.** `systemctl stop demoapp` qancha vaqt oladi (`time`)? Journal'dan to'xtatish ketma-ketligini toping. Keyin `SIGTERM` ni e'tiborsiz qoldiradigan `stubborn.service` yozing (`ExecStart=/bin/bash -c 'trap "" TERM; while true; do sleep 1; done'`), `TimeoutStopSec=5` bilan. `stop` qancha vaqt oldi va `status` da natija qanday ko'rsatilgan? 9-darsdagi signal bilimi bilan izohlang. `stubborn.service` ni o'chiring. Yo'nalish: 3-bo'lim "To'xtatish".

### C. Restart va bog'liqliklar

11. **Restart policies.** `demoapp` da `Restart=on-failure`, `RestartSec=3` bo'lsin. To'rt usul bilan to'xtating va har safar qayta ko'tarildimi, tekshiring: `sudo systemctl kill -s KILL demoapp`; `sudo systemctl kill -s TERM demoapp`; `sudo kill -SEGV <MainPID>`; `sudo systemctl stop demoapp`. Natijalarni jadval qiling va 4-bo'limdagi qoidalar bilan izohlang. `systemctl show demoapp -p NRestarts` nima ko'rsatadi? Yo'nalish: 4-bo'lim "Mexanizm".

12. **Crash loop.** `flaky.service` yozing: `ExecStart=/bin/false`, `Restart=on-failure`, `RestartSec` ko'rsatilmagan. Ishga tushiring va 15 soniyadan keyin `status` va journal'ni oling. Necha marta urindi, oxirgi xabar nima? `start` qayta ishlaydimi, `reset-failed` nima qiladi? Keyin `RestartSec=5` qo'shib takrorlang: start limit'ga uriladimi, nima uchun? Production uchun xulosa yozing va unit'ni o'chiring. Yo'nalish: 4-bo'lim "Start limit".

13. **After vs Requires.** Ikkita oneshot unit yozing: `a.service` (`ExecStart=/bin/sleep 5`, `RemainAfterExit=yes`) va `b.service` (`ExecStart=/bin/echo b started`). To'rt variantni sinab, har birida `sudo systemctl start b` dan keyin `a` ning holati va journal'dagi vaqt tartibini yozing: bog'liqliksiz; `b` da faqat `After=a.service`; faqat `Wants=a.service`; ikkalasi birga. Keyin `a` ni `ExecStart=/bin/false` qilib, `Wants=` va `Requires=` farqini ko'rsating. Har sinovdan oldin ikkala unit'ni `stop` qiling. Oxirida o'chiring. Yo'nalish: 5-bo'lim.

14. **Resource limit.** `demoapp` ga `MemoryMax=50M` qo'ying va `systemctl status` dagi `Memory:` qatorini ko'ring. Keyin vaqtincha `hog.service` yozing: `ExecStart=/usr/bin/tail /dev/zero`, `MemoryMax=100M`, `Restart=no`. Ishga tushiring: `status` da natija nima (`Result:` yoki `oom-kill` so'zini qidiring), `journalctl -k` da nima bor? 8-darsdagi cgroup OOM bilan bog'lang. `hog.service` ni o'chiring. Yo'nalish: 6-bo'lim "Resurs limiti va himoya".

### D. Override, timer

15. **Drop-in override.** `sudo systemctl edit nginx` bilan `Restart=always` va `RestartSec=2` qo'shing. `systemctl cat nginx` chiqishida ikkala fayl qanday ko'rsatilgan? nginx master jarayoniga `SIGKILL` yuboring va qayta ko'tarilishini ko'rsating. `systemd-delta --type=extended` nima ko'rsatadi? Keyin drop-in orqali `ExecStart` ni almashtirishga urining, lekin tozalovchi bo'sh `ExecStart=` qatorisiz: xato nima? Oxirida `systemctl revert nginx`. Yo'nalish: 7-bo'lim.

16. **Timer.** `report.service` (oneshot, `User=demoapp`) va `report.timer` yozing: har 2 daqiqada `/var/lib/demoapp/report.log` ga sana, `uptime` va `free -m` ning `Mem:` qatorini qo'shadigan skriptni (`/usr/local/bin/report.sh`) ishga tushirsin. `systemd-analyze calendar` bilan ifodangizni tekshiring. `list-timers` chiqishini, 3 ta ishga tushishdan keyingi log faylni va `journalctl -u report.service` ni ko'rsating. Servisni timer kutmasdan qo'lda ham ishga tushirib ko'ring. Yo'nalish: 9-bo'lim.

17. **Same job in cron.** Xuddi shu skriptni `demoapp` nomidan cron orqali har 2 daqiqada ishga tushiring (`sudo crontab -u demoapp -e` yoki `/etc/cron.d/` fayli, farqini yozing), natija boshqa faylga yozilsin. Skriptga ataylab xato qo'shing (mavjud bo'lmagan buyruq): cron variantida xatoni qayerdan topdingiz, timer variantida qayerdan? 9-bo'limdagi jadvalning qaysi qatorlarini amalda ko'rdingiz? Cron yozuvini o'chiring. Yo'nalish: 9-bo'lim "cron".

### E. Yakuniy

18. **Hardened service.** `demoapp.service` ning yakuniy variantini yozing: `demoapp` foydalanuvchisi, environment fayl, `Restart=on-failure` oqilona `RestartSec` bilan, tarmoq bog'liqligi, `MemoryMax`, `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`. Sandbox ishlashini isbotlang: servisni vaqtincha `ExecStart=/usr/bin/touch /etc/demoapp-test` bilan (yoki `systemd-run` da shu xususiyatlar bilan) ishga tushirib xatoni ko'rsating. `systemd-analyze security demoapp` bahosini sandbox opsiyalarisiz va ular bilan solishtiring. Faylni ish papkasiga saqlang. Yo'nalish: 6-bo'lim.

19. **Runbook and cleanup.** README'ga `demoapp` uchun qisqa runbook yozing: deploy qilish qadamlari (fayllar, `daemon-reload`, `enable --now`), holatni tekshirish, loglarni ko'rish, konfiguratsiyani o'zgartirish, "servis failed holatida" bo'lganda tekshiruv tartibi (8-darsdagi checklist bilan bog'lab). Runbook'ga "ikkinchi mashinadagi `lab` da shu holatni noldan tiklash" bo'limini ham qo'shing. Keyin tozalang: `report.timer`, test unit'lar va `nginx` (`sudo apt purge -y nginx nginx-common`) o'chirilsin, `systemctl --failed` bo'sh bo'lsin. `demoapp.service` va `demoapp` akkaunti 13-darsdagi mini-loyiha uchun qolsin. Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `linux/11-systemd/README.md` da 19 ta vazifaning har biri `## N. Title` sarlavhasi ostida, buyruq, natija va izoh bilan.
2. `make check` toza o'tadi (host'da; `shellcheck` skriptlar uchun).
3. Ish papkasida unit va timer fayllar nusxasi bor, ichida secret yo'q (`demoapp.env` commit qilinmaydi).
4. VM'da `systemctl --failed` bo'sh, test unit'lar o'chirilgan, `systemd-analyze verify /etc/systemd/system/demoapp.service` ogohlantirishsiz, `systemctl is-enabled demoapp` `enabled`.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `systemctl start` va `systemctl enable` farqi nima, `enable` diskda aynan nimani o'zgartiradi?
- Unit faylni tahrirlagandan keyin nima uchun `daemon-reload` kerak?
- systemd servisning bola jarayonlarini PID faylsiz qanday biladi?
- `After=` va `Requires=` farqi nima, nima uchun odatda juft yoziladi?
- `Restart=on-failure` qaysi tugashlarda ishlaydi, qaysilarida yo'q?
- Servis `Start request repeated too quickly` bilan `failed` bo'ldi. Bu nima degani va keyingi qadamlaringiz?
- Paket o'rnatgan unit'ni qanday o'zgartirasiz va nima uchun faylning o'zini tahrirlamaysiz?
- Terminalda ishlagan buyruq unit'da nima uchun ishlamasligi mumkin? Kamida uch sabab.
- Secret'ni servisga qanday berasiz va nima uchun unit faylning o'ziga yozmaysiz?
- systemd timer cron'dan qaysi jihatlari bilan ustun, cron qachon yetarli?
- `systemctl stop` jarayonni qanday to'xtatadi va dasturingiz bunga qanday tayyor bo'lishi kerak?
- Bu darsni macOS host'ining o'zida nima uchun bajarib bo'lmaydi va konteyner nima uchun yechim emas?
