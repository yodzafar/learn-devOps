# 3-dars: Alerting

Maqsad: dashboard'ga odam qarab turishi shart bo'lmasligi uchun muammo haqida tizimning o'zi xabar berishini sozlash, va buni shunday qilishki, xabar kam, aniq va harakatga undaydigan bo'lsin. Prometheus alert shartini hisoblaydi, Alertmanager kimga, qachon va qanday guruhlab yuborishni hal qiladi. Bu dars 1-darsdagi RED so'rovlari va recording rule'larga tayanadi, 2-darsdagi Grafana'da ikkinchi alerting tizimini (Grafana Alerting) ko'rasiz, yakunida on-call jarayoni va Grafana OnCall'ning hozirgi holati bilan tanishasiz. 7-darsdagi incident simulyatsiyasi shu yerda yozilgan alert'dan boshlanadi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqatni quyidagilarga qarating: `for` va alert holatlari, routing tree qanday aylanib chiqilishi (`continue`), `group_wait`/`group_interval`/`repeat_interval` farqi, inhibition va silence farqi, symptom va cause alert'lari, burn rate hisobi. YAML sintaksisi ikkinchi darajali, vaqtni "bu alert tunda meni uyg'otishga arziydimi" degan savolga sarflang.

## Laboratoriya

`observability/stack/` ustida. Yangi servislar: `alertmanager` (port `9093`, versiya: https://github.com/prometheus/alertmanager/releases ), webhook qabul qiluvchi kichik servis (o'zingiz yozasiz) va email sinovi uchun SMTP tutqich (masalan Mailpit, https://mailpit.axllent.org/ ). `amtool` Alertmanager image'i ichida bor.

```
mkdir -p alertmanager
docker compose up -d alertmanager
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

Telegram vazifasi uchun @BotFather orqali bot yaratasiz. Bot token secret: alohida faylda (`alertmanager/telegram_token`), `.gitignore` da, config'da `bot_token_file` orqali. Token chatga, README'ga yoki commit'ga tushib qolsa, uni BotFather'da darhol qayta yarating. Tozalash: `docker compose down`.

---

## 1. Alert zanjiri

```
Prometheus (rule evaluation) --firing alerts--> Alertmanager --notification--> receiver
```

Mas'uliyat bo'lingan. Prometheus faqat "shart bajarilyaptimi" degan savolga javob beradi va har `evaluation_interval` da faol alert'larni Alertmanager'ga qayta yuboradi. Alertmanager deduplikatsiya, guruhlash, routing, inhibition, silence va yuborishni bajaradi. Shu sabab ikkita bir xil Prometheus (HA juftligi) bir xil alert yuborsa ham odam bitta xabar oladi.

```yaml
# prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]
```

## 2. Prometheus alerting rules

```yaml
groups:
  - name: api_alerts
    rules:
      - alert: ApiHighErrorRatio
        expr: |
          sum(rate(http_requests_total{job="api",status=~"5.."}[5m]))
            / sum(rate(http_requests_total{job="api"}[5m])) > 0.05
        for: 5m
        labels: { severity: critical, team: shop }
        annotations:
          summary: "API error ratio {{ $value | humanizePercentage }}"
          runbook_url: "https://example.org/runbooks/api-high-error-ratio"
```

- `expr` natijasidagi har seriya alohida alert instansi. Label'lari alert label'lariga aylanadi.
- **Holatlar**: inactive → pending (shart bajarildi, `for` hali o'tmadi) → firing. Shart bir marta bajarilmasa pending nolga qaytadi. `for` qisqa sakrashlarni kesadi, narxi: xabar shuncha kechikadi.
- `keep_firing_for` shart yo'qolgandan keyin ham alert'ni bir muddat ushlab turadi (flapping'ga qarshi).
- `labels` routing uchun (kimga, qanchalik jiddiy), `annotations` odam uchun (nima bo'ldi, nima qilish kerak). Annotation'larda shablon: `{{ $labels.instance }}`, `{{ $value }}`, `humanize`, `humanizePercentage`, `humanizeDuration`.
- Faol alert'lar `ALERTS{alertstate="firing"}` seriyasi sifatida ham ko'rinadi.

**Tuzoq: o'zgaruvchan label.** Alert `labels` ichiga `{{ $value }}` yozilsa, qiymat har o'zgarganda label to'plami, demak alert identifikatori o'zgaradi: `for` hech qachon to'lmaydi yoki har safar yangi xabar ketadi. Qiymat faqat annotation'da.

**Tuzoq: ma'lumot yo'q bo'lsa alert ham yo'q.** `rate(...) > 0.05` seriya umuman bo'lmasa (ilova o'lgan, metrika nomi o'zgargan) bo'sh natija beradi va alert jim turadi. Shuning uchun `up == 0` va `absent(up{job="api"})` kabi alohida qoidalar kerak.

## 3. Alertmanager

### Routing tree
Config'ning asosi `route` daraxti. Har alert ildizdan kiradi, bolalar tartib bilan tekshiriladi, birinchi mos kelgan tarmoqqa tushadi (uning ichida yana chuqurroq). `continue: true` bo'lsa keyingi qardosh ham tekshiriladi. Hech biri mos kelmasa ildiz receiver'i oladi.

```yaml
route:
  receiver: default
  group_by: [alertname, team]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: ['severity="critical"']
      receiver: telegram-oncall
    - matchers: ['team="shop"']
      receiver: shop-webhook
```

### Grouping va vaqtlar
`group_by` label'lari bir xil alert'lar bitta xabarga yig'iladi. 50 ta instans birdan yiqilsa 50 ta emas, bitta xabar keladi.

| Parametr | Default | Ma'nosi |
|----------|---------|---------|
| `group_wait` | 30s | yangi guruhning birinchi xabaridan oldin kutish (qo'shni alert'lar yig'ilsin) |
| `group_interval` | 5m | guruhga yangi alert qo'shilsa yoki biri resolve bo'lsa, keyingi xabargacha |
| `repeat_interval` | 4h | hech narsa o'zgarmagan, hali firing guruhni qayta eslatish |

### Inhibition va silence
- **Inhibition**: boshqa alert firing bo'lgani uchun buni avtomatik bostirish. Host o'lgan bo'lsa, undagi har servis uchun alohida alert keraksiz.

```yaml
inhibit_rules:
  - source_matchers: ['alertname="InstanceDown"']
    target_matchers: ['severity="warning"']
    equal: [instance]
```

- **Silence**: odam qo'lda, vaqt bilan cheklangan holda (rejali ish, ma'lum muammo) matcher bo'yicha xabarni o'chiradi. UI yoki `amtool silence add`. Doim muddat va izoh bilan.
- **Mute/active time intervals**: jadval bo'yicha (masalan warning'lar faqat ish vaqtida).

Uchala holatda ham alert Prometheus'da firing bo'lib qoladi, faqat xabar ketmaydi.

### Receiver'lar
Bitta receiver ichida bir nechta integratsiya bo'lishi mumkin: `webhook_configs`, `telegram_configs`, `slack_configs`, `email_configs`, shuningdek PagerDuty, Opsgenie, Discord, MS Teams va boshqalar.

```yaml
receivers:
  - name: telegram-oncall
    telegram_configs:
      - bot_token_file: /etc/alertmanager/telegram_token
        chat_id: -1001234567890
        send_resolved: true
```

Webhook universal: Alertmanager JSON `POST` yuboradi (`status`, `groupLabels`, `commonLabels`, `alerts[]` har birida `labels`, `annotations`, `startsAt`, `endsAt`). Qo'llab-quvvatlanmaydigan har qanday tizim shu orqali ulanadi. Xabar matni Go template bilan sozlanadi (`message`, `text`, `html` maydonlari va `templates:` fayllari).

`amtool` asosiy buyruqlari: `check-config`, `config routes show`, `config routes test <label=value ...>` (alert qaysi receiver'ga borishini config'ni ishga tushirmasdan ko'rsatadi), `alert`, `silence add|query|expire`.

## 4. Nimaga alert qilish kerak

### Symptom va cause
| | Symptom-based | Cause-based |
|---|---|---|
| Misol | error ratio > 5%, p95 > 1s | CPU > 90%, bitta pod restart bo'ldi |
| Foydalanuvchiga ta'siri | aniq bor | noma'lum, ko'pincha yo'q |
| Soni | kam (har servisga 2–4) | cheksiz o'sadi |

Page (odamni uyg'otadigan xabar) faqat symptom'ga: foydalanuvchi hozir zarar ko'ryapti yoki tez orada ko'radi (disk 4 soatda to'ladi: `predict_linear`). Cause metrikalari dashboard'da turadi va symptom alert'idan keyin diagnostikada ishlatiladi. CPU 95% bo'lib, latency va xato joyida bo'lsa, bu muammo emas, samarali ishlatilgan server.

Har alert uchun uchta savol: bu haqiqiymi, shoshilinchmi, odam biror narsa qila oladimi? Bittasiga "yo'q" bo'lsa, bu page emas: ticket, dashboard yoki o'chirib tashlash.

### SLO va error budget burn rate
SLI o'lchov (muvaffaqiyatli so'rovlar ulushi), SLO maqsad (30 kunda 99.9%), error budget ruxsat etilgan xato: `1 - SLO = 0.1%`, vaqtga aylantirilsa 30 kunda taxminan 43 daqiqa to'liq uzilish.

Burn rate budget qanchalik tez yonayotganini ko'rsatadi: `error ratio / (1 - SLO)`. Burn rate 1 bo'lsa budget aynan 30 kunda tugaydi. 14.4 bo'lsa 1 soatda oylik budgetning 2% i ketadi.

| Burn rate | Uzun oyna | Qisqa oyna | Yongan budget | Harakat |
|-----------|-----------|------------|---------------|---------|
| 14.4 | 1h | 5m | 2% | page |
| 6 | 6h | 30m | 5% | page |
| 1 | 3d | 6h | 10% | ticket |

Ikki oyna birga ishlatiladi: uzun oyna muammo jiddiy ekanini, qisqa oyna u hozir ham davom etayotganini tasdiqlaydi (aks holda muammo tugagandan keyin ham alert bir soat firing turadi). Oddiy "error > 5% for 5m" dan afzalligi: sekin, lekin uzoq davom etadigan 0.5% xatoni ham ushlaydi, qisqa sakrashda esa uyg'otmaydi.

### Alert fatigue va runbook
Harakat talab qilmaydigan har xabar keyingi haqiqiy xabarga ishonchni kamaytiradi. Odamlar kanalni mute qiladi va haqiqiy incident o'tkazib yuboriladi. Davolash: har hafta alert'larni ko'rib chiqish, harakatsiz yopilganlarini tuzatish yoki o'chirish; `for` va grouping; severity'ni halol belgilash (critical = hozir uyg'ot).

Runbook alert'ga biriktirilgan qisqa ko'rsatma (`runbook_url` annotation): alert nimani anglatadi, ta'siri, birinchi tekshiruvlar (qaysi dashboard, qaysi so'rov), ma'lum sabablar va tuzatish, kimga eskalatsiya. Tungi soat 3 da o'ylash emas, o'qish kerak.

Monitoringni kim kuzatadi: doim firing turadigan `Watchdog` alert'i (`expr: vector(1)`) tashqi servisga yuboriladi; xabar kelmay qolsa zanjir uzilgan (dead man's switch).

## 5. Grafana Alerting va Alertmanager

Grafana'ning o'z alerting tizimi bor: qoidalarni Grafana hisoblaydi, ichida o'rnatilgan Alertmanager bor.

| | Prometheus + Alertmanager | Grafana Alerting |
|---|---|---|
| Qoida qayerda hisoblanadi | Prometheus | Grafana (Grafana-managed rules) |
| Data source | faqat Prometheus | har qanday: Prometheus, Loki, SQL, Elasticsearch; bitta qoidada bir nechtasi |
| Config | YAML fayllar, git | UI, yoki `provisioning/alerting/` fayllari, API, Terraform |
| Yuborish | Alertmanager: route, receiver | notification policy, contact point (tushunchalar bir xil) |
| Grafana o'chsa | alert'lar ishlayveradi | alert'lar to'xtaydi |

Terminlar mosligi: receiver = contact point, route = notification policy, `for` = pending period; silence va mute timing ikkalasida bor. Grafana-managed qoida holatlari: Normal, Pending, Alerting, NoData, Error; ma'lumot yo'q yoki so'rov xato bo'lganda nima qilish (`noDataState`, `execErrState`) qoidaning o'zida belgilanadi.

Grafana tashqi Alertmanager'ni data source sifatida ko'ra oladi (silence va alert'larni UI'da boshqarish) va o'z alert'larini unga yuborishi ham mumkin. Amaliy tanlov: infratuzilma va servis metrikalari uchun Prometheus qoidalari (kod, HA, Grafana'ga bog'liq emas); log yoki SQL asosidagi va Prometheus'da ifodalab bo'lmaydigan alert'lar uchun Grafana Alerting. Ikkalasida bir xil alert'ni takrorlamang.

## 6. On-call

- **Rotation**: navbatchilik jadvali (odatda haftalik), primary va secondary. Almashinuvda handoff: ochiq muammolar, shubhali joylar.
- **Escalation policy**: primary N daqiqada acknowledge qilmasa secondary'ga, keyin jamoa rahbariga. Alertmanager buni bilmaydi, u faqat xabar yuboradi; "kim navbatda" va "javob bermasa kimga" on-call tizimining ishi.
- **Acknowledge / resolve**, MTTA (javobgacha vaqt) va MTTR (tiklashgacha vaqt).
- **Postmortem**: aybdor qidirmaydigan (blameless) tahlil: nima bo'ldi, qanday aniqlandi, nima uchun, nima o'zgartiriladi. 7-dars mini-loyihasida yozasiz.
- Sog'lom on-call belgisi: navbatda kam page (haftasiga bir nechta), har biri harakatli, dam olish kompensatsiyasi bor.

## 7. Grafana OnCall holati

Grafana OnCall OSS (o'z serveringizda ishlatiladigan on-call tizimi: jadvallar, eskalatsiya, Telegram/Slack/telefon) **2025-yil 11-martda maintenance mode'ga o'tdi va 2026-yil 24-martda arxivlandi**: `grafana/oncall` repozitoriysi faqat o'qish uchun, yangi versiya va xavfsizlik tuzatishlari chiqmaydi, SMS/telefon/push uchun ishlatilgan Grafana Cloud ulanishi ham shu sanada o'chirilgan. Rivojlanish Grafana Cloud IRM (OnCall va Incident birlashgan tijoriy mahsulot) ichida davom etmoqda. Rasmiy e'lon: https://grafana.com/blog/grafana-oncall-maintenance-mode/ .

Shu sabab bu darsda OnCall amaliyoti yo'q: arxivlangan loyihani o'rnatishni o'rganish foydasiz. Amaliyot Alertmanager va Grafana Alerting bilan cheklanadi, on-call esa tushuncha darajasida. Real ishda rotation va eskalatsiya uchun Grafana Cloud IRM, PagerDuty yoki shunga o'xshash servis ishlatiladi, Alertmanager ularga tayyor integratsiya yoki webhook orqali ulanadi.

## Tuzoqlar

- Cause'ga page qilish (CPU, xotira, bitta restart): tunda uyg'onasiz, qiladigan ish yo'q. Page faqat symptom'ga.
- `for` siz alert: bitta scrape'dagi sakrash xabar bo'lib ketadi. Juda uzun `for` esa incident'ning birinchi 15 daqiqasini yashiradi.
- Ma'lumot yo'qolganda jim turadigan alert: `absent()` va `up == 0` qoidalarisiz ilova o'lganini bilmay qolasiz.
- Label'da `{{ $value }}`: alert identifikatori har hisobda o'zgaradi.
- `group_by: [...]` (hamma label bo'yicha) yoki umuman guruhlamaslik: incident paytida yuzlab xabar.
- Routing'da tartib va `continue` ni tushunmaslik: critical alert umumiy tarmoqqa tushib, on-call'ga yetmaydi. `amtool config routes test` bilan tekshiring.
- Muddatsiz yoki izohsiz silence: uch oydan keyin nima uchun alert kelmayotganini hech kim bilmaydi.
- Bot token yoki SMTP parolini config ichida commit qilish. `*_file` maydonlari va `.gitignore`.
- Monitoringni monitoring qilmaslik: Alertmanager o'lsa hech kim xabar olmaydi. Watchdog kerak.
- Runbook'siz alert: har safar boshidan tekshiruv, MTTR uzayadi.

## Manbalar

- https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ – alerting rules
- https://prometheus.io/docs/alerting/latest/alertmanager/ – Alertmanager tushunchalari (grouping, inhibition, silence)
- https://prometheus.io/docs/alerting/latest/configuration/ – config ma'lumotnomasi, receiver'lar ro'yxati
- https://prometheus.io/docs/practices/alerting/ – nimaga alert qilish kerak
- https://sre.google/workbook/alerting-on-slos/ – burn rate, multiwindow alert'lar (majburiy)
- https://sre.google/sre-book/monitoring-distributed-systems/ – symptom va cause
- https://sre.google/sre-book/being-on-call/ – on-call amaliyoti
- https://grafana.com/docs/grafana/latest/alerting/ – Grafana Alerting
- https://grafana.com/docs/grafana/latest/alerting/set-up/provision-alerting-resources/file-provisioning/ – alerting'ni fayldan provisioning
- https://grafana.com/blog/grafana-oncall-maintenance-mode/ – Grafana OnCall OSS maintenance mode va arxivlash e'loni
- https://grafana.com/docs/grafana-cloud/alerting-and-irm/irm/ – Grafana Cloud IRM

---

## Vazifalar

Javoblar `observability/03-alerting/README.md` da (`make new m=observability n=03 name=alerting`), har vazifa uchun `## N. Title` ostida: config'ning muhim qismi, buyruq, kuzatilgan natija (xabar matni, holat, vaqt) va izoh. Stack fayllari (`prometheus/rules/alerts.yml`, `alertmanager/alertmanager.yml`, webhook servisi) `observability/stack/` da; runbook'lar `observability/03-alerting/runbooks/` da.

### A. Alerting rules

1. **First alert rule.** `prometheus/rules/alerts.yml` da `InstanceDown` qoidasini yozing (`up == 0`, `for: 1m`, `severity`, `summary` annotation'ida instans nomi). `promtool check rules` o'tsin. `docker compose stop api` qiling va Prometheus UI'ning Alerts sahifasida inactive → pending → firing o'tishini vaqtlari bilan yozing. `ALERTS` seriyasini so'rang.

2. **Tune for.** `for` ni olib tashlang va `api` ni 20 soniyaga to'xtatib qayta yoqing: alert firing bo'ldimi? `for: 1m` bilan takrorlang. `for` va `evaluation_interval` birga eng yomon holatda xabarni qancha kechiktirishini hisoblang.

3. **Symptom alerts.** `api` uchun ikkita symptom alert yozing: error ratio (5xx ulushi chegaradan yuqori) va p95 latency. 1-darsdagi recording rule'lardan foydalaning. Annotation'da qiymat odam o'qiydigan shaklda bo'lsin. Loadgen yoki ilovada xato ulushini vaqtincha oshirib (env o'zgaruvchi orqali) alert'ni firing qiling.

4. **Absent data.** `api` metrikasi nomini ilovada vaqtincha o'zgartiring (yoki job'ni scrape config'dan olib tashlang). Error ratio alert'i nima uchun jim turganini ko'rsating. `absent()` bilan buni ushlaydigan qoida yozing.

5. **Label trap.** Alert `labels` ichiga `value: "{{ $value }}"` qo'shing va `for: 2m` bilan kuzating: Alerts sahifasida nima bo'lyapti? Sababini izohlab, tuzating.

6. **Rule unit test.** Error ratio alert'i uchun `promtool test rules` testi yozing: `input_series` bilan xato ulushi chegaradan oshgan holat, `alert_rule_test` da kutilgan label va annotation'lar. Chegaradan past holatda alert yo'qligini ham tekshiring.

### B. Alertmanager

7. **Alertmanager and webhook.** `alertmanager` servisini qo'shing va Prometheus'ga ulang. Kelgan `POST` body'sini stdout'ga chiqaradigan kichik webhook servis yozing (Node.js yoki Go, 20–30 qator) va default receiver qiling. Alert'ni firing qilib, JSON payload tuzilishini (`status`, `groupLabels`, `alerts[]`) yozing. `send_resolved` bilan resolve xabarini ham oling.

8. **Grouping timers.** `group_by: [alertname]` bilan uchta target'ni birdan to'xtating (`api`, `node-exporter`, `cadvisor`): nechta xabar keldi, ichida nechta alert? `group_wait`, `group_interval`, `repeat_interval` ni kichik qiymatlarga qo'yib, har biri qaysi xabarni boshqarishini vaqt belgilari bilan ko'rsating.

9. **Routing tree.** Daraxt yozing: `severity="critical"` → `oncall` receiver, `team="shop"` → `shop` receiver, qolgani → `default`. `amtool config routes test` bilan to'rt xil label to'plami qayerga borishini tekshiring. Critical va `team=shop` alert ikkala joyga ham borishi uchun nimani o'zgartirish kerak? Bolalar tartibini almashtirib natija qanday o'zgarishini ko'rsating.

10. **Inhibition.** `InstanceDown` firing bo'lganda o'sha `instance` uchun boshqa alert'lar bostirilishi uchun inhibit rule yozing. `api` ni to'xtating: qaysi alert'lar firing, qaysi biri xabar bo'lib keldi? Alertmanager UI'da inhibited alert qanday ko'rinadi?

11. **Silences.** `amtool silence add` bilan `alertname` va `instance` bo'yicha 10 daqiqalik silence yarating (izoh bilan). Alert firing bo'lsa ham xabar kelmasligini ko'rsating. `amtool silence query` va `expire` ishlating. Silence va inhibition farqini o'z so'zingiz bilan yozing.

12. **Break the config.** `alertmanager.yml` da mavjud bo'lmagan receiver'ga ishora qiling. `amtool check-config` va konteyner log'i nima deydi? Alertmanager ishlab turgan paytda buzuq config'ni reload qilsangiz (`SIGHUP`) nima bo'ladi: eski config qoladimi?

### C. Receiver'lar

13. **Telegram receiver.** Bot yarating, uni guruh yoki shaxsiy chatga qo'shing, `chat_id` ni aniqlang. `telegram_configs` ni `bot_token_file` bilan sozlang, critical alert'lar shu yerga borsin. Xabar matnini shablon bilan o'zgartiring: alert nomi, summary, runbook havolasi. Token repoda yo'qligini `git status` va `make check` bilan tasdiqlang.

14. **Email receiver.** SMTP tutqich (Mailpit) servisini qo'shing va `email_configs` orqali warning alert'larni unga yuboring. Kelgan xatni UI'da ko'ring. Real SMTP bilan ishlashda qaysi maydonlar secret bo'lishini va ularni qanday berishni yozing. (Slack'ingiz bo'lsa, ixtiyoriy: `slack_configs` ni incoming webhook bilan sinang.)

15. **Watchdog.** Doim firing turadigan `Watchdog` alert'ini yozing va alohida route bilan webhook'ga qisqa `repeat_interval` da yuboring. Webhook servisingizga "oxirgi N daqiqada Watchdog kelmadi" holatini log'ga yozadigan tekshiruv qo'shing. Alertmanager'ni to'xtatib sinang.

### D. SLO va jarayon

16. **Burn rate alert.** `api` uchun SLO belgilang: 30 kunda 99.9% so'rov 5xx siz. 1h, 5m, 6h, 30m oynalari uchun error ratio recording rule'larini va ikki bosqichli (14.4 va 6) multiwindow burn rate alert'ini yozing. Xato ulushini 2% ga ko'tarib qaysi alert qancha vaqtda firing bo'lishini kuzating. Laboratoriyada kutish uzun bo'lsa oynalarni proporsional qisqartiring va buni yozib qo'ying.

17. **Budget math.** Hisoblang va izohlang: 99.9% va 99.99% SLO uchun 30 kunlik error budget daqiqalarda; xato ulushi 0.5% bo'lsa 99.9% SLO'da burn rate va budget necha kunda tugashi; 3-vazifadagi oddiy "error > 5%" alert'i bu holatni ushlaydimi?

18. **Runbooks.** Uchta alert'ingiz uchun `runbooks/` da Markdown runbook yozing (ma'nosi, ta'siri, birinchi 3 tekshiruv aniq PromQL bilan, ehtimoliy sabablar, eskalatsiya). `runbook_url` annotation'ini repodagi fayl manziliga qo'ying va Telegram xabarida havola chiqishini ko'rsating.

19. **Alert review.** Shu darsda yozgan barcha alert'larni jadvalga oling: nomi, symptom yoki cause, severity, page yoki ticket, odam nima qiladi. "Odam hech narsa qila olmaydi" chiqqan har alert uchun qaror yozing: o'chirish, severity tushirish yoki dashboard'ga ko'chirish.

### E. Grafana Alerting

20. **Grafana-managed rule.** Grafana'da Prometheus so'rovi asosida alert rule yarating (masalan in-flight so'rovlar soni chegaradan yuqori), contact point sifatida o'z webhook'ingizni va notification policy'ni sozlang. Firing qiling va payload'ni Alertmanager webhook payload'i bilan solishtiring. No data holatida qoida nima qilishini sozlamadan toping va sinang.

21. **Provision alerting.** 20-vazifadagi rule, contact point va policy'ni UI'dan eksport qilib `grafana/provisioning/alerting/` ga fayl sifatida qo'ying. Grafana volume'ini o'chirib ko'taring: hammasi tiklansin. Alertmanager'ni Grafana'ga data source sifatida qo'shing va 11-vazifadagi silence'ni Grafana UI'dan ko'ring.

22. **Mini-project: alerting as code.** Toza `docker compose up -d` dan keyin: Prometheus'da symptom, burn rate, `InstanceDown`, `absent` va Watchdog qoidalari; Alertmanager'da routing (critical → Telegram, warning → email, hammasi → webhook log), inhibition; har alert'da runbook. Ssenariy o'tkazing: `api` da xato ulushini 20% ga ko'taring, keyin `api` ni butunlay to'xtating. `README.md` ga vaqt chizig'ini yozing: qaysi alert qachon pending, firing, qaysi xabar qayerga keldi, qaysi biri inhibit bo'ldi, resolve qachon keldi.

### Topshirish

Tayyor bo'lgach:
1. `promtool check rules`, `promtool test rules` va `amtool check-config` toza.
2. `make check` toza, bot token va parollar repoda yo'q.
3. Telegram'dagi sinov xabarlari skrinshoti yoki matni `README.md` da (token ko'rinmasin).
4. `docker compose down` qilingan, faol silence'lar qolmagan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Prometheus va Alertmanager o'rtasida mas'uliyat qanday bo'lingan? Nima uchun bitta komponent emas?
- `for` nima beradi va nimani yo'qotadi?
- `group_wait`, `group_interval`, `repeat_interval` har biri qaysi vaziyatda ishlaydi?
- Inhibition, silence va mute time interval farqi nima?
- Symptom-based alert nima va nima uchun CPU 90% ga page qilmaysiz?
- Burn rate 14.4 nimani anglatadi? Nima uchun ikki oyna birga ishlatiladi?
- Seriya yo'qolganda alert nima uchun jim qoladi va buni qanday yopasiz?
- Grafana Alerting'ni qachon tanlaysiz, Prometheus qoidalarini qachon?
- Grafana OnCall OSS'ning hozirgi holati qanday va bu amaliy tanlovga qanday ta'sir qiladi?
