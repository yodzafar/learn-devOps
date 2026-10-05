# 11-dars: Servislarni boshqarish (systemd)

Maqsad: systemd'ni foydalanuvchi sifatida emas, unit yozuvchi sifatida bilish. Dasturni serverda "to'g'ri" ishga tushirish degani: boot'da o'zi ko'tariladi, yiqilsa qayta turadi, root sifatida ishlamaydi, loglari bir joyda, to'xtatilganda tartibli tugaydi. Bularning hammasi bitta `.service` faylida e'lon qilinadi. Dars 9-darsdagi signal va jarayon bilimiga (systemd servisni `SIGTERM` bilan to'xtatadi), 10-darsdagi servis akkauntga (`User=`) va 8-darsdagi `journalctl` ga tayanadi. Kubernetes'dagi restart policy, probe va resurs limitlari shu g'oyalarning davomi.

Taxminiy vaqt: 3 kun (siz uchun). `systemctl start/stop` tez o'tadi, diqqatni quyidagilarga qarating: unit fayl qayerda yashaydi va qaysi biri ustun, `enable` va `start` farqi, `After=` va `Wants=`/`Requires=` farqi, `Restart=` siyosatlari va start limit, environment fayl formati, drop-in override, timer va cron farqi.

## Laboratoriya

- Hammasi Multipass VM ichida (`multipass shell lab`). systemd to'liq ishlashi uchun haqiqiy VM kerak: oddiy Docker konteynerida PID 1 systemd emas, `systemctl` ishlamaydi.
- Ish mashinasida faqat o'qish: `systemctl status`, `systemctl cat`, `systemctl list-timers`, `journalctl`.
- Namuna dastur sifatida Python'ning ichki HTTP serveri ishlatiladi (`python3` Ubuntu 24.04 da o'rnatilgan), alohida kod yozish shart emas.
- 10-darsda yaratilgan `demoapp` servis akkaunti kerak. Yo'q bo'lsa: `sudo useradd --system --no-create-home --shell /usr/sbin/nologin demoapp`.
- Unit fayllarni VM'da yozasiz, tayyor nusxasini ish papkasiga olasiz: `multipass transfer lab:/etc/systemd/system/demoapp.service .`
- Tozalash: dars oxirida yaratilgan unit'lar `disable --now` qilinadi, fayllari o'chiriladi, `sudo systemctl daemon-reload` (oxirgi vazifada).

---

## 1. systemd va unit'lar

systemd PID 1: kernel ishga tushiradigan birinchi jarayon, qolgan hamma narsani u ko'taradi va kuzatadi. U boshqaradigan har obyekt **unit** deb ataladi, unit fayl nomining kengaytmasi tipini bildiradi:

| Tip | Nima |
|-----|------|
| `.service` | jarayon yoki jarayonlar guruhi (daemon, bir martalik vazifa) |
| `.socket` | socket; ulanish kelganda tegishli servisni ishga tushiradi (socket activation) |
| `.timer` | vaqt bo'yicha servisni ishga tushirish (cron o'rniga) |
| `.target` | unit'lar guruhi, sinxronlash nuqtasi (eski "runlevel" o'rniga) |
| `.mount`, `.swap` | mount nuqtalari va swap (`/etc/fstab` dan avtomatik yaratiladi, 13-dars) |
| `.path` | fayl yoki katalog o'zgarganda servisni ishga tushirish |
| `.slice`, `.scope` | cgroup ierarxiyasi, resurs limitlari |

Har servis o'z **cgroup** ida ishlaydi. Shuning uchun systemd servisning hamma bola jarayonlarini biladi (PID fayl kerak emas), ularni birga to'xtata oladi va resurslarini birga o'lchaydi/cheklaydi.

### Unit fayllar qayerda

| Katalog | Kimniki | Ustunlik |
|---------|---------|----------|
| `/etc/systemd/system/` | administrator (siz) | eng yuqori |
| `/run/systemd/system/` | runtime, reboot'da yo'qoladi | o'rta |
| `/usr/lib/systemd/system/` | paketlar (`apt`/`dnf` o'rnatadi) | eng past |

Bir xil nomli fayl yuqoriroq katalogda bo'lsa pastdagisini to'liq yopadi. Paket faylini (`/usr/lib/...`) hech qachon tahrirlamang: paket yangilanganda o'zgarishingiz yo'qoladi. Buning uchun drop-in bor (7-bo'lim). Amaldagi natijani `systemctl cat nginx` ko'rsatadi: qaysi fayllardan yig'ilgani bilan.

## 2. systemctl

| Buyruq | Nima qiladi |
|--------|-------------|
| `systemctl start X` / `stop X` | hozir ishga tushirish / to'xtatish |
| `systemctl restart X` | to'xtatib qayta ishga tushirish |
| `systemctl reload X` | jarayonni to'xtatmasdan konfiguratsiyani qayta o'qitish (unit'da `ExecReload=` bo'lsa) |
| `systemctl enable X` / `disable X` | boot'da ishga tushishini yoqish / o'chirish |
| `systemctl enable --now X` | yoqish va hozir ishga tushirish |
| `systemctl status X` | holat, PID, cgroup, oxirgi log qatorlari |
| `systemctl is-active X`, `is-enabled X`, `is-failed X` | skriptlar uchun, exit code bilan |
| `systemctl mask X` / `unmask X` | unit'ni butunlay taqiqlash (`/dev/null` ga symlink), qo'lda ham ishga tushmaydi |
| `systemctl daemon-reload` | unit fayllarni diskdan qayta o'qish |
| `systemctl cat X`, `systemctl show X -p Restart` | amaldagi unit matni va xususiyatlari |
| `systemctl list-dependencies X` | bog'liqliklar daraxti |

`.service` kengaytmasini yozmasa ham bo'ladi. O'zgartiruvchi buyruqlar `sudo` talab qiladi.

### start va enable

Bular mustaqil ikki narsa:

- `start` hozir ishga tushiradi, reboot'dan keyingi holatga ta'sir qilmaydi.
- `enable` hozir hech narsani ishga tushirmaydi: unit'ning `[Install]` bo'limiga qarab symlink yaratadi (masalan `/etc/systemd/system/multi-user.target.wants/demoapp.service`). Boot paytida `multi-user.target` ko'tarilganda shu symlink orqali servis ham tortiladi.

**Tuzoq: `start` qilib `enable` ni unutish.** Servis oylab ishlaydi, birinchi reboot'dan keyin ko'tarilmaydi. Har doim `enable --now`, va `is-enabled` bilan tekshiring.

**Tuzoq: unit faylni o'zgartirib `daemon-reload` qilmaslik.** systemd unit'larni xotirada saqlaydi. Fayl o'zgarganda `systemctl status` "changed on disk" deb ogohlantiradi, lekin eski ta'rif ishlashda davom etadi. Tartib: tahrir, `daemon-reload`, `restart`.

### status ni o'qish

```
● demoapp.service - Demo HTTP app
     Loaded: loaded (/etc/systemd/system/demoapp.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-10-05 10:00:00 UTC; 5min ago
   Main PID: 2345 (python3)
     CGroup: /system.slice/demoapp.service
```

`Loaded` qatori: fayl yo'li va `enabled`/`disabled`. `Active` qatori: `active (running)`, `inactive (dead)`, `failed`, `activating (auto-restart)`. Yiqilganda `Main PID` qatorida sabab bo'ladi: `code=exited, status=1/FAILURE` (dastur o'zi chiqdi) yoki `code=killed, signal=KILL` (signal). systemd'ning o'z kodlari ham bor:

| Status | Ma'nosi |
|--------|---------|
| `203/EXEC` | `ExecStart` dagi faylni bajarib bo'lmadi (yo'l noto'g'ri, `x` huquqi yo'q) |
| `217/USER` | `User=` dagi foydalanuvchi mavjud emas |
| `200/CHDIR` | `WorkingDirectory=` ga o'tib bo'lmadi |

## 3. .service unit yozish

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

Uch bo'lim: `[Unit]` tavsif va bog'liqliklar, `[Service]` qanday ishga tushirish, `[Install]` `enable` nima qilishi.

- `ExecStart=` da binary'ni to'liq yo'l bilan yozing: aniq va systemd'ning hamma versiyasida ishlaydi. Bu shell emas: `|`, `>`, `&&`, `~`, glob ishlamaydi, ular dasturga oddiy argument bo'lib boradi. Shell kerak bo'lsa aniq yozing: `ExecStart=/bin/bash -c '...'`, lekin yaxshisi skript fayl.
- `User=`/`Group=` berilmasa servis **root** sifatida ishlaydi.
- Dastur foreground'da ishlashi kerak. O'zini background'ga o'tkazadigan (`&`, daemonize) dastur `Type=simple` bilan "tugadi" deb hisoblanadi.
- Yozgandan keyin tekshiring: `systemd-analyze verify /etc/systemd/system/demoapp.service`.

### Type

| `Type=` | systemd qachon "ishga tushdi" deb hisoblaydi | Qachon |
|---------|----------------------------------------------|--------|
| `simple` (standart) | fork qilingan zahoti | foreground'da ishlaydigan zamonaviy dastur |
| `exec` | binary muvaffaqiyatli exec qilingach | `simple` kabi, lekin `ExecStart` xatosi `start` paytida ko'rinadi |
| `notify` | dastur `sd_notify` orqali "tayyorman" degach | buni qo'llaydigan dasturlar (nginx, PostgreSQL paketlari) |
| `forking` | ota jarayon chiqqach (eski uslubdagi daemon) | faqat eski dasturlar, `PIDFile=` bilan |
| `oneshot` | jarayon tugagach | skript, migratsiya, timer chaqiradigan vazifa |

### To'xtatish

`systemctl stop` servisning asosiy jarayoniga `SIGTERM` (`KillSignal=`) yuboradi, `TimeoutStopSec=` (standart 90 soniya) kutadi, keyin cgroup'da qolgan hamma jarayonga `SIGKILL`. Dasturingiz `SIGTERM` ni ushlab tartibli tugashi kerak (9-dars). `systemctl kill -s HUP demoapp` unit jarayonlariga istalgan signalni yuboradi.

## 4. Restart siyosatlari

| `Restart=` | Qachon qayta ishga tushiradi |
|------------|------------------------------|
| `no` (standart) | hech qachon |
| `on-failure` | nol bo'lmagan exit code, signaldan o'lim, timeout, watchdog |
| `on-abnormal` | signal, timeout, watchdog (nol bo'lmagan exit code'da yo'q) |
| `on-success` | faqat toza chiqishda |
| `always` | har qanday tugashda |

- `systemctl stop` bilan to'xtatilgan servis hech qaysi siyosatda qayta ko'tarilmaydi.
- Exit code 0 va `SIGTERM`, `SIGINT`, `SIGHUP`, `SIGPIPE` signallari "toza chiqish" hisoblanadi: `on-failure` ularda ishlamaydi.
- `RestartSec=` urinishlar orasidagi pauza, standart 100 ms. Ma'lumotlar bazasini kutayotgan servis uchun juda kam, 3–10 soniya qo'ying.

### Start limit

Cheksiz restart sikli tizimni band qilmasligi uchun chegara bor: standart holatda 10 soniya ichida 5 martadan ko'p ishga tushish urinishi bo'lsa (`StartLimitIntervalSec=10s`, `StartLimitBurst=5`, ikkalasi `[Unit]` bo'limida), systemd taslim bo'ladi: unit `failed` holatiga o'tadi, logda `Start request repeated too quickly`. Shundan keyin `Restart=` ishlamaydi, qo'lda `systemctl reset-failed demoapp` va `start` kerak.

**Tuzoq: `Restart=always` muammoni yashiradi.** Har 5 daqiqada yiqilib qayta turadigan servis `active (running)` ko'rinadi. `systemctl show demoapp -p NRestarts` va journal'dagi restart yozuvlarini kuzating, monitoringda restart soniga alert qo'ying.

## 5. Bog'liqliklar

Ikki mustaqil o'q bor, ularni aralashtirish eng ko'p uchraydigan xato:

| Direktiva | O'q | Ma'nosi |
|-----------|-----|---------|
| `Wants=B` | talab (yumshoq) | A ishga tushganda B ham ishga tushirilsin; B yiqilsa A baribir davom etadi |
| `Requires=B` | talab (qattiq) | B ishga tushmasa A ham ishga tushmaydi; B to'xtatilsa A ham to'xtatiladi |
| `After=B` | tartib | ikkalasi ham ishga tushayotgan bo'lsa, A B dan keyin |
| `Before=B` | tartib | teskarisi |

- `After=` hech narsani ishga tushirmaydi, faqat navbatni belgilaydi. `Wants=`/`Requires=` tartibni belgilamaydi: `After=` siz ikkala unit parallel ko'tariladi. Amalda deyarli har doim juft yoziladi: `Wants=postgresql.service` va `After=postgresql.service`.
- `After=B` "B tayyor bo'lguncha kut" degani emas, "B ishga tushdi deb hisoblanguncha kut" degani. `Type=simple` servis fork qilingan zahoti "ishga tushgan" hisoblanadi, port hali ochilmagan bo'lishi mumkin. Shuning uchun dasturning o'zi ulanishni qayta urinishi kerak, `Restart=on-failure` bilan `RestartSec=` shuni qoplaydi.
- `network.target` tarmoq sozlanishi boshlanganini bildiradi, IP borligini emas. Tarmoq kerak bo'lgan servis uchun `After=network-online.target` va `Wants=network-online.target`.
- `[Install]` dagi `WantedBy=multi-user.target` teskari yo'nalishdagi `Wants=`: `enable` qilinganda target servisni "xohlaydi".

## 6. Environment va secret'lar

```
[Service]
Environment=LOG_LEVEL=info
EnvironmentFile=/etc/demoapp/demoapp.env
```

`EnvironmentFile` formati shell skript emas: har qatorda `KEY=value`, `export` yozilmaydi, `$VAR` kengaytirilmaydi, `#` bilan boshlangan qator izoh. `EnvironmentFile=-/etc/demoapp/extra.env` dagi `-` "fayl bo'lmasa xato emas" degani.

`ExecStart=` ichida `${PORT}` va `$PORT` shakllari systemd tomonidan almashtiriladi (shell emas, faqat oddiy almashtirish). Dasturning o'zi esa environment'ni odatdagidek o'qiydi.

Secret'lar uchun: fayl `root:root`, huquqi `600` (systemd uni root sifatida o'qib, jarayonga environment qilib beradi, servis foydalanuvchisi faylni o'qiy olishi shart emas). Unit faylning o'ziga `Environment=DB_PASSWORD=...` yozmang: unit fayllar hammaga o'qishga ochiq va `systemctl show` orqali ko'rinadi.

**Tuzoq: login environment'ga tayanish.** Servis sizning `~/.bashrc`, `PATH`, `nvm` sozlamalaringizni ko'rmaydi (5-dars: ular interaktiv shell'da yuklanadi). Terminalda ishlagan buyruq unit'da `203/EXEC` yoki "command not found" berishining sababi shu. Hamma yo'llar to'liq, hamma o'zgaruvchilar unit'da aniq.

### Resurs limiti va himoya

Unit cgroup orqali cheklanadi va izolyatsiya qilinadi, eng foydalilari:

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

`MemoryMax` dan oshgan servisni cgroup OOM killer o'ldiradi (8-dars). `ProtectSystem=strict` butun fayl tizimini servis uchun read-only qiladi, yozish kerak joylar `ReadWritePaths=` bilan ochiladi. Unit'ning himoya bahosini `systemd-analyze security demoapp` beradi.

## 7. Drop-in override

Paket o'rnatgan unit'ni o'zgartirishning to'g'ri usuli: faylni almashtirish emas, ustiga qo'shimcha yozish.

```
$ sudo systemctl edit nginx
```

Bu `/etc/systemd/system/nginx.service.d/override.conf` ni yaratadi, editorda faqat o'zgartirmoqchi bo'lgan qatorlarni yozasiz, saqlaganda `daemon-reload` avtomatik bajariladi:

```
[Service]
Restart=always
RestartSec=5
```

- Drop-in asosiy fayl bilan birlashtiriladi, paket yangilansa ham saqlanadi.
- Ro'yxat tipidagi direktivalar (`ExecStart=`, `Environment=`, `After=`) qo'shiladi, almashtirilmaydi. `ExecStart` ni almashtirish uchun avval bo'sh qiymat bilan tozalash kerak: `ExecStart=` qatori, keyin yangi `ExecStart=/new/command`.
- `systemctl edit --full nginx` butun faylning nusxasini `/etc/systemd/system/` ga oladi (paket yangilanishlari endi ta'sir qilmaydi, kam ishlatiladi).
- `systemctl revert nginx` barcha override'larni o'chirib paket holatiga qaytaradi.
- `systemd-delta` tizimdagi barcha override'larni ko'rsatadi: begona serverda "bu yerda nima o'zgartirilgan" degan savolga javob.

## 8. Loglar: journalctl -u

Servisning stdout va stderr chiqishi avtomatik journal'ga tushadi. Dastur log faylni o'zi boshqarishi shart emas: stdout'ga yozsa bas.

```
$ journalctl -u demoapp -f                    # follow
$ journalctl -u demoapp -n 100 --no-pager
$ journalctl -u demoapp --since "10 min ago" -p warning
$ journalctl -u demoapp -b -o json-pretty | head -40
```

`-o json` har yozuvning metama'lumotlarini (`_PID`, `_UID`, `_SYSTEMD_UNIT`, `PRIORITY`) ko'rsatadi. systemd'ning o'z xabarlari ham (ishga tushdi, yiqildi, restart rejalashtirildi) shu yerda, dastur chiqishi bilan aralash.

**Tuzoq: bufer tufayli log ko'rinmaydi.** Ko'p runtime stdout terminal bo'lmasa chiqishni buferlaydi: Python'da loglar daqiqalab kechikadi yoki jarayon o'ldirilganda yo'qoladi. Python uchun `Environment=PYTHONUNBUFFERED=1`.

## 9. Timer va cron

Davriy vazifa uchun ikki fayl: nima qilishni aytadigan `.service` (odatda `Type=oneshot`) va qachonligini aytadigan bir xil nomli `.timer`.

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

- `OnCalendar=` kalendar ifodasi: `daily`, `hourly`, `Mon *-*-* 09:00:00`, `*-*-01 03:30:00`. Tekshirish: `systemd-analyze calendar "Mon *-*-* 09:00:00"` keyingi ishga tushish vaqtini ko'rsatadi.
- `OnBootSec=5min`, `OnUnitActiveSec=1h` monoton timerlar: boot'dan yoki oxirgi ishga tushishdan keyin.
- `Persistent=true`: mashina o'chiq bo'lgani uchun o'tkazib yuborilgan ishga tushish yoqilgandan keyin bajariladi.
- `systemctl list-timers` barcha timerlar, oxirgi va keyingi ishga tushish vaqti bilan.

cron: `crontab -e` (foydalanuvchi jadvali), `/etc/cron.d/` (tizim), besh maydon `daqiqa soat kun oy hafta-kuni` va buyruq: `*/5 * * * * /usr/local/bin/report.sh`.

| | cron | systemd timer |
|---|------|---------------|
| Sozlash | bitta qator | ikki fayl |
| Loglar | o'zingiz yo'naltirasiz, aks holda mail yoki yo'qoladi | journal, `journalctl -u` |
| O'tkazib yuborilgan vazifa | bajarilmaydi | `Persistent=true` |
| Oldingi ishga tushish tugamagan bo'lsa | ustiga yana bittasi ishga tushadi | ishga tushirmaydi, servis hali faol |
| Bog'liqliklar, limitlar, `User=`, sandbox | yo'q | servis unit'ning hamma imkoniyati |
| Qo'lda sinash | buyruqni nusxalab, boshqa environment'da | `systemctl start X.service`, aynan o'sha muhitda |
| Holatni ko'rish | yo'q | `list-timers`, `status` |

cron hali ham hamma joyda uchraydi va uni o'qiy olish kerak. Yangi vazifalar uchun timer afzal.

## 10. Target'lar

Target o'zi hech narsa bajarmaydi, unit'larni guruhlaydi va boot bosqichlarini belgilaydi:

| Target | Ma'nosi |
|--------|---------|
| `multi-user.target` | to'liq ishlaydigan tizim, grafik interfeyssiz. Serverlarning standart holati |
| `graphical.target` | `multi-user` va grafik login. Ish stansiyalari |
| `rescue.target` | bitta foydalanuvchi, minimal servislar |
| `emergency.target` | faqat root shell, root fayl tizimi read-only. Buzilgan `fstab` da shu yerga tushasiz (13-dars) |
| `network-online.target`, `timers.target`, `sockets.target` | sinxronlash nuqtalari |

`systemctl get-default` boot qaysi target'gacha borishini ko'rsatadi, `set-default` o'zgartiradi, `systemctl isolate rescue.target` hozir o'tkazadi. Boot vaqtini tahlil qilish: `systemd-analyze` va `systemd-analyze blame`.

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

## Manbalar

- https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html – systemd.unit(5): bog'liqliklar, drop-in, yuklash yo'llari
- https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html – systemd.service(5): Type, Restart, ExecStart (majburiy)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html – systemd.exec(5): User, Environment, sandbox opsiyalari
- https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html – systemd.timer(5)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html – kalendar ifodalari sintaksisi
- https://www.freedesktop.org/software/systemd/man/latest/systemctl.html – systemctl(1)
- https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html – MemoryMax, CPUQuota
- https://systemd.io/NETWORK_ONLINE/ – network.target va network-online.target farqi
- https://0pointer.de/blog/projects/systemd-for-admins-1.html – "systemd for Administrators" turkumi (muallifdan)
- https://man7.org/linux/man-pages/man5/crontab.5.html – crontab(5)

---

## Vazifalar

Ish papkasi: `linux/11-systemd/` (`make new m=linux n=11 name=systemd` bilan yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. Yozgan unit fayllaringiz, timer'lar va skriptlar nusxasini yoniga saqlang (`demoapp.service`, `report.timer` va hokazo). Hammasi VM'da, faqat 1-vazifa ish mashinasida ham.

### A. systemctl va mavjud unit'lar

1. **Read a unit.** Ish mashinasida va VM'da `systemctl cat ssh` (ish mashinasida yo'q bo'lsa `cron` yoki `docker`) ni oling. Fayl qaysi katalogdan yuklangan, `Type=`, `ExecStart=`, `Restart=`, `WantedBy=` qiymatlari nima? `systemctl status` dagi `Loaded:` va `Active:` qatorlarini so'zma-so'z izohlang.

2. **start vs enable.** VM'da `sudo apt install -y nginx`. `is-active` va `is-enabled` ni oling. `disable` qiling va `/etc/systemd/system/multi-user.target.wants/` da nima o'zgarganini ko'rsating; servis hali ishlayaptimi? `sudo reboot` dan keyin holatni tekshiring. Keyin `enable --now` qiling. To'rt kombinatsiyani (active/inactive va enabled/disabled) jadval qilib, har biri qanday hosil bo'lishini yozing.

3. **mask.** `nginx` ni `stop` qilib `mask` qiling. `start` qilishga urining: xato nima? `ls -l /etc/systemd/system/nginx.service` nimani ko'rsatadi? `disable` va `mask` farqini va `mask` qachon kerak bo'lishini yozing. `unmask` qiling.

4. **Dependencies and targets.** `systemctl get-default`, `systemctl list-dependencies multi-user.target | head -30` va `systemctl list-dependencies --reverse nginx` ni oling. `systemd-analyze blame | head` dan boot'da eng sekin 3 unit'ni toping. Ish mashinangizning default target'i VM'nikidan farq qiladimi?

### B. O'z servisingiz

5. **First unit.** `/srv/demoapp/` katalogini yarating, ichiga `index.html` qo'ying, egasi `demoapp`. 3-bo'limdagi namunaga o'xshash `demoapp.service` yozing, lekin avval environment faylsiz: port `ExecStart` da to'g'ridan-to'g'ri `8080`. `systemd-analyze verify`, `daemon-reload`, `enable --now`. Tekshiring: `systemctl status`, `curl localhost:8080`, `ps -o user,pid,cmd -C python3`. Jarayon kim nomidan ishlayapti?

6. **Break ExecStart.** `ExecStart` dagi yo'lni mavjud bo'lmagan binary'ga o'zgartiring, qayta ishga tushiring. `systemctl status` dagi `status=` kodini va journal xabarini yozing. Keyin yo'lni to'g'rilab, `User=` ni mavjud bo'lmagan foydalanuvchiga o'zgartiring: kod nima? Uchinchi tajriba: `ExecStart=/usr/bin/python3 -m http.server 8080 | tee /tmp/log` deb yozib ishga tushiring: `systemd-analyze verify` buni ushladimi, journal'da dastur nima dedi, `|` va undan keyingi so'zlar amalda kimga yetib bordi? Har uchala xatoni tuzating.

7. **Forgot daemon-reload.** Ishlab turgan unit'da `Description=` ni o'zgartiring va `daemon-reload` siz `systemctl restart demoapp`, keyin `systemctl status demoapp` qiling. Ogohlantirishni yozing. Qaysi ta'rif amalda? `daemon-reload` dan keyin qayta tekshiring.

8. **Environment file.** `/etc/demoapp/demoapp.env` yarating (`PORT=9090`, `PYTHONUNBUFFERED=1`), huquqi `600`, egasi root. Unit'ni `EnvironmentFile=` va `${PORT}` bilan qayta yozing. Tekshiring: `curl`, va `sudo cat /proc/<MainPID>/environ | tr '\0' '\n'`. `demoapp` foydalanuvchisi `.env` faylni o'qiy olmasa ham servis nima uchun ishlayapti? Faylga `export PORT=9091` yoki `PORT=$BASE` shaklida yozsangiz nima bo'ladi, sinab ko'ring.

9. **Logs.** `curl` bilan bir necha so'rov yuboring (mavjud bo'lmagan yo'lga ham). `journalctl -u demoapp` da so'rovlar ko'rinadimi? `PYTHONUNBUFFERED` ni olib tashlab farqni tekshiring. Bitta yozuvni `-o json-pretty` bilan chiqarib, `_PID`, `_UID`, `_SYSTEMD_UNIT`, `PRIORITY` maydonlarini toping. `http.server` loglari qaysi prioritet bilan tushgan va nima uchun (stdout yoki stderr)?

10. **Graceful stop.** `systemctl stop demoapp` qancha vaqt oladi (`time`)? Journal'dan to'xtatish ketma-ketligini toping. Keyin `SIGTERM` ni e'tiborsiz qoldiradigan `stubborn.service` yozing (`ExecStart=/bin/bash -c 'trap "" TERM; while true; do sleep 1; done'`), `TimeoutStopSec=5` bilan. `stop` qancha vaqt oldi va `status` da natija qanday ko'rsatilgan? 9-darsdagi signal bilimi bilan izohlang. `stubborn.service` ni o'chiring.

### C. Restart va bog'liqliklar

11. **Restart policies.** `demoapp` da `Restart=on-failure`, `RestartSec=3` bo'lsin. To'rt usul bilan to'xtating va har safar qayta ko'tarildimi, tekshiring: `sudo systemctl kill -s KILL demoapp`; `sudo systemctl kill -s TERM demoapp`; `sudo kill -SEGV <MainPID>`; `sudo systemctl stop demoapp`. Natijalarni jadval qiling va 4-bo'limdagi qoidalar bilan izohlang. `systemctl show demoapp -p NRestarts` nima ko'rsatadi?

12. **Crash loop.** `flaky.service` yozing: `ExecStart=/bin/false`, `Restart=on-failure`, `RestartSec` ko'rsatilmagan. Ishga tushiring va 15 soniyadan keyin `status` va journal'ni oling. Necha marta urindi, oxirgi xabar nima? `start` qayta ishlaydimi, `reset-failed` nima qiladi? Keyin `RestartSec=5` qo'shib takrorlang: start limit'ga uriladimi, nima uchun? Production uchun xulosa yozing va unit'ni o'chiring.

13. **After vs Requires.** Ikkita oneshot unit yozing: `a.service` (`ExecStart=/bin/sleep 5`, `RemainAfterExit=yes`) va `b.service` (`ExecStart=/bin/echo b started`). To'rt variantni sinab, har birida `sudo systemctl start b` dan keyin `a` ning holati va journal'dagi vaqt tartibini yozing: bog'liqliksiz; `b` da faqat `After=a.service`; faqat `Wants=a.service`; ikkalasi birga. Keyin `a` ni `ExecStart=/bin/false` qilib, `Wants=` va `Requires=` farqini ko'rsating. Har sinovdan oldin ikkala unit'ni `stop` qiling. Oxirida o'chiring.

14. **Resource limit.** `demoapp` ga `MemoryMax=50M` qo'ying va `systemctl status` dagi `Memory:` qatorini ko'ring. Keyin vaqtincha `hog.service` yozing: `ExecStart=/usr/bin/tail /dev/zero`, `MemoryMax=100M`, `Restart=no`. Ishga tushiring: `status` da natija nima (`Result:` yoki `oom-kill` so'zini qidiring), `journalctl -k` da nima bor? 8-darsdagi cgroup OOM bilan bog'lang. `hog.service` ni o'chiring.

### D. Override, timer

15. **Drop-in override.** `sudo systemctl edit nginx` bilan `Restart=always` va `RestartSec=2` qo'shing. `systemctl cat nginx` chiqishida ikkala fayl qanday ko'rsatilgan? nginx master jarayoniga `SIGKILL` yuboring va qayta ko'tarilishini ko'rsating. `systemd-delta --type=extended` nima ko'rsatadi? Keyin drop-in orqali `ExecStart` ni almashtirishga urining, lekin tozalovchi bo'sh `ExecStart=` qatorisiz: xato nima? Oxirida `systemctl revert nginx`.

16. **Timer.** `report.service` (oneshot, `User=demoapp`) va `report.timer` yozing: har 2 daqiqada `/var/lib/demoapp/report.log` ga sana, `uptime` va `free -m` ning `Mem:` qatorini qo'shadigan skriptni (`/usr/local/bin/report.sh`) ishga tushirsin. `systemd-analyze calendar` bilan ifodangizni tekshiring. `list-timers` chiqishini, 3 ta ishga tushishdan keyingi log faylni va `journalctl -u report.service` ni ko'rsating. Servisni timer kutmasdan qo'lda ham ishga tushirib ko'ring.

17. **Same job in cron.** Xuddi shu skriptni `demoapp` nomidan cron orqali har 2 daqiqada ishga tushiring (`sudo crontab -u demoapp -e` yoki `/etc/cron.d/` fayli, farqini yozing), natija boshqa faylga yozilsin. Skriptga ataylab xato qo'shing (mavjud bo'lmagan buyruq): cron variantida xatoni qayerdan topdingiz, timer variantida qayerdan? 9-bo'limdagi jadvalning qaysi qatorlarini amalda ko'rdingiz? Cron yozuvini o'chiring.

### E. Yakuniy

18. **Hardened service.** `demoapp.service` ning yakuniy variantini yozing: `demoapp` foydalanuvchisi, environment fayl, `Restart=on-failure` oqilona `RestartSec` bilan, tarmoq bog'liqligi, `MemoryMax`, `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`. Sandbox ishlashini isbotlang: servisni vaqtincha `ExecStart=/usr/bin/touch /etc/demoapp-test` bilan (yoki `systemd-run` da shu xususiyatlar bilan) ishga tushirib xatoni ko'rsating. `systemd-analyze security demoapp` bahosini sandbox opsiyalarisiz va ular bilan solishtiring. Faylni ish papkasiga saqlang.

19. **Runbook and cleanup.** README'ga `demoapp` uchun qisqa runbook yozing: deploy qilish qadamlari (fayllar, `daemon-reload`, `enable --now`), holatni tekshirish, loglarni ko'rish, konfiguratsiyani o'zgartirish, "servis failed holatida" bo'lganda tekshiruv tartibi (8-darsdagi checklist bilan bog'lab). Keyin tozalang: `report.timer`, test unit'lar va `nginx` (`sudo apt purge -y nginx nginx-common`) o'chirilsin, `systemctl --failed` bo'sh bo'lsin. `demoapp.service` va `demoapp` akkaunti 13-darsdagi mini-loyiha uchun qolsin.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza o'tadi (`shellcheck` skriptlar uchun).
2. Ish papkasida unit va timer fayllar nusxasi bor, ichida secret yo'q.
3. VM'da `systemctl --failed` bo'sh, test unit'lar o'chirilgan, `systemd-analyze verify /etc/systemd/system/demoapp.service` ogohlantirishsiz.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `systemctl start` va `systemctl enable` farqi nima, `enable` diskda aynan nimani o'zgartiradi?
- Unit faylni tahrirlagandan keyin nima uchun `daemon-reload` kerak?
- `After=` va `Requires=` farqi nima, nima uchun odatda juft yoziladi?
- `Restart=on-failure` qaysi tugashlarda ishlaydi, qaysilarida yo'q?
- Servis `Start request repeated too quickly` bilan `failed` bo'ldi. Bu nima degani va keyingi qadamlaringiz?
- Paket o'rnatgan unit'ni qanday o'zgartirasiz va nima uchun faylning o'zini tahrirlamaysiz?
- Terminalda ishlagan buyruq unit'da nima uchun ishlamasligi mumkin? Kamida uch sabab.
- systemd timer cron'dan qaysi jihatlari bilan ustun, cron qachon yetarli?
- `systemctl stop` jarayonni qanday to'xtatadi va dasturingiz bunga qanday tayyor bo'lishi kerak?
