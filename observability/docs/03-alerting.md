# 3-dars: Alerting

Maqsad: dashboard'ga odam qarab turishi shart bo'lmasligi uchun muammo haqida tizimning o'zi xabar berishini sozlash, va buni shunday qilishki, xabar kam, aniq va harakatga undaydigan bo'lsin. Alert bu "shart bajarildi, odam bilishi kerak" degan avtomatik signal. Siz ehtimol alert'larni qabul qilgansiz (Sentry xatlari, shovqinli Slack kanali), lekin ularni loyihalamagansiz. Bu darsda zanjirning ikkala yarmini noldan qurasiz: Prometheus shartni hisoblaydi (1-dars PromQL va recording rule'lariga tayanadi), Alertmanager kimga, qachon va qanday guruhlab yuborishni hal qiladi. Keyin "nimaga alert qilish kerak" degan asosiy savolga o'tasiz: symptom va cause, SLO va error budget, burn rate. Oxirida Grafana'ning o'z alerting tizimi (2-darsdagi Grafana ustida) va on-call jarayoni. 7-darsdagi incident simulyatsiyasi shu yerda yozilgan alert'dan boshlanadi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh vazifalari, ikkinchi kun 3–4 bo'limlar va B guruhi, uchinchi kun C guruhi va "Birga bajaramiz" ni o'z stack'ingizda takrorlash, to'rtinchi kun 5-bo'lim va D guruhi, beshinchi kun 6–7 bo'limlar, E guruhi va mini-loyiha. Diqqatni quyidagilarga qarating: `for` va alert holatlari, routing tree qanday aylanib chiqilishi (`continue`), `group_wait`/`group_interval`/`repeat_interval` farqi, inhibition va silence farqi, symptom va cause alert'lari, burn rate hisobi. YAML sintaksisi ikkinchi darajali, vaqtni "bu alert tunda meni uyg'otishga arziydimi" degan savolga sarflang.

Qanday o'qish kerak: har bo'limdagi qoida yoki config bo'lagini o'qing, keyin o'z stack'ingizda shunga o'xshash (aynan o'zi emas) narsani sinab, Prometheus va Alertmanager UI'da nima ko'rinishini darsdagi izoh bilan solishtiring. Vaqt belgilari, fingerprint va IP'lar sizda boshqa bo'ladi, darsda bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker Compose'da, yagona `observability/stack/` papkasida ishlaydi (1–2 darslarda qurilgan: `api`, `loadgen`, `prometheus`, `node-exporter`, `cadvisor`, `grafana`). Host'ga hech narsa o'rnatilmaydi: `promtool` Prometheus image'i ichida, `amtool` Alertmanager image'i ichida bor va `docker compose exec` orqali ishlatiladi.

| Narsa | Qayerda | Qanday ochiladi |
|-------|---------|-----------------|
| Alerting rules | `stack/prometheus/rules/*.yml`, Prometheus konteyneriga mount | `http://localhost:9090` → Alerts |
| Alertmanager config | `stack/alertmanager/alertmanager.yml` | `http://localhost:9093` |
| Webhook qabul qiluvchi | o'zingiz yozadigan kichik servis (7-vazifa) | `docker compose logs -f <servis>` |
| Email tutqich (Mailpit) | Compose servisi, SMTP `1025`, UI `8025` | `http://localhost:8025` |
| Grafana Alerting | 2-darsdagi `grafana` servisi | `http://localhost:3000` → Alerting |

Bu darsda qo'shiladigan servislar: `alertmanager` (image `prom/alertmanager`, release'lar: https://github.com/prometheus/alertmanager/releases ), webhook qabul qiluvchi va Mailpit (https://mailpit.axllent.org/ ). Modul qoidasi o'zgarmaydi: `latest` emas, release sahifasidan olingan aniq tag. Port'lar faqat `127.0.0.1` ga publish qilinadi (docker moduli, 3-dars), chunki Alertmanager UI'da autentifikatsiya yo'q: uni ochgan har kim silence yarata oladi.

Compose ichida servislar bir-birini servis nomi bilan topadi (docker moduli, 3–4 darslar): Prometheus config'ida Alertmanager manzili `alertmanager:9093`, Alertmanager config'ida webhook manzili `http://<servis-nomi>:<port>/...`. `localhost` konteyner ichida o'sha konteynerning o'zini bildiradi, shuning uchun config'da `localhost` yozilsa xabar hech qayerga bormaydi. `localhost` faqat host'dagi brauzer va `curl` uchun.

```
docker compose up -d
docker compose exec prometheus promtool check rules /etc/prometheus/rules/alerts.yml
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

Xavfsizlik va tartib:

- **Secret'lar**: Telegram bot token va chat ID, real SMTP paroli, Slack webhook URL'i hech qachon commit qilinmaydi. Token alohida faylda (`alertmanager/telegram_token`), `.gitignore` da, config'da `bot_token_file` orqali ko'rsatiladi. README'ga ham, skrinshotga ham tushmasin. Tushib qolsa, @BotFather'da tokenni darhol qayta yarating. Repo'dagi `make secrets` tekshiruvi commit qilingan `.env` ni rad etadi.
- **Real xabarlar faqat o'z chat'ingizga** ketadi. Ikkala mashina bitta bot va bitta chat'dan foydalanadi: ofisdagi stack ishlab turgan paytda uyda ham ko'tarsangiz, har xabar ikki marta keladi. Ketishdan oldin `docker compose down`.
- **Sinov yuklamasi**: alert'ni firing qilish uchun ish mashinasining o'zini qiynamang (`stress`, diskni to'ldirish yo'q). Uch usul yetarli: `loadgen` orqali namuna ilovaga yuk berish yoki uning xato ulushini oshirish, konteynerni to'xtatish (`docker compose stop api`), yoki chegarani ataylab past qo'yib keyin qaytarish.
- Har mashg'ulot oxirida `docker compose down` (volume'lar qoladi). `docker system prune` va `docker volume prune -a` ishlatilmaydi. `make check` ish papkalaridagi YAML'ni `yamllint` bilan tekshiradi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Image'lar `amd64`. `node-exporter` haqiqiy ish mashinasini ko'rsatadi: uning diski, CPU'si, xotirasi. Host alert'i chegarasi shu mashinaning real holatiga mos tanlanadi. |
| macOS (uy) | Image'lar `arm64`. Docker Desktop yashirin Linux VM ichida ishlaydi, `node-exporter` Mac'ni emas, o'sha VM'ni ko'rsatadi: disk hajmi, `mountpoint` va `device` label qiymatlari, CPU soni boshqa. Ofisda sozlangan host alert'i bu yerda hech qachon firing bo'lmasligi yoki doim firing turishi mumkin. |

Shuning uchun host metrikalari bo'yicha selector'ni ko'chirmang: qaysi mashinada bo'lsangiz, avval Prometheus'da metrikaning haqiqiy label qiymatlarini ko'ring (masalan `node_filesystem_avail_bytes` ni so'rab `mountpoint` va `fstype` ustunlariga qarang), keyin selector yozing. Ilova (`api`) bo'yicha alert'lar ikkala mashinada bir xil ishlaydi. Yozgan webhook servisingiz bazaviy image'i multi-arch bo'lishi kerak; tayyor image ishlatsangiz `docker buildx imagetools inspect <image>:<tag>` chiqishida `linux/amd64` va `linux/arm64` ikkalasi borligini tekshiring.

Ikkinchi mashinada tiklash: rules fayllari, `alertmanager.yml`, shablonlar, `compose.yaml` va Grafana provisioning fayllari git orqali keladi, `git pull` va `docker compose up -d` yetarli. Git orqali kelmaydigan narsalar: silence'lar va notification tarixi (Alertmanager volume'ida, har mashinada alohida), alert'larning `pending`/`firing` holati (Prometheus xotirasida) va bot token fayli. Token faylini ikkinchi mashinada qo'lda yarating (parol menejeridan), chat'ga yozib yubormang.

---

## 1. Alert nima va zanjir qanday tuzilgan

### Shovqinli alert nima uchun o'chiriladi

Frontend ishida ko'p uchraydigan manzara: Sentry har bir `TypeError` uchun xat yuboradi, Slack'dagi `#alerts` kanalida kuniga yuzlab xabar. Bir haftadan keyin hamma kanalni mute qiladi, xatlarga filter qo'yadi. Bu dangasalik emas, to'g'ri reaksiya: xabarlarning 99% i harakat talab qilmasa, ularni o'qish vaqt isrofi. Narxi keyin ko'rinadi: haqiqiy incident (to'lov ishlamay qoldi) xuddi shu kanalga xuddi shu ko'rinishda keladi va uni hech kim ko'rmaydi. Bu holat **alert fatigue** deyiladi: keraksiz xabarlar ko'pligidan odam haqiqiy xabarga ham reaksiya qilmay qo'yishi.

Bundan darsning asosiy mezoni chiqadi: alert'ning sifati "nechta muammoni ushlaydi" bilan emas, "kelgan xabarlarning qanchasi odamdan harakat talab qildi" bilan o'lchanadi. Zanjirning har bo'g'ini (`for`, guruhlash, inhibition, routing, severity) shu nisbatni yaxshilash uchun mavjud.

### Zanjir: kim nima qiladi

```
api, node-exporter ... --scrape--> Prometheus --(rule evaluation)--> alert instances
Prometheus --POST /api/v2/alerts (repeated)--> Alertmanager --notification--> receiver
```

Ish ikki dastur orasida bo'lingan:

| Bo'g'in | Savol | Nima qiladi |
|---------|-------|-------------|
| Prometheus | "Shart hozir bajarilyaptimi?" | har `evaluation_interval` da qoidadagi PromQL ifodani hisoblaydi, alert holatini yuritadi, faol alert'larni Alertmanager'ga yuboradi |
| Alertmanager | "Buni kimga, qachon, qanday shaklda aytaman?" | deduplikatsiya, guruhlash, routing, inhibition, silence va xabar yuborish |
| Receiver | "Xabar qayerga tushadi?" | Telegram chat, email, webhook, on-call tizimi |

`evaluation_interval` bu Prometheus qoidalarni necha vaqtda bir hisoblashi (`prometheus.yml` dagi `global` bo'limida, default 1 daqiqa; 1-darsda recording rule'lar uchun ko'rgansiz). Deduplikatsiya bu bir xil alert bir necha marta kelsa bitta deb hisoblash.

### Mexanizm: Prometheus alert'ni qayta-qayta yuboradi

Prometheus alert'ni bir marta "yoqib", keyin "o'chir" demaydi. Alert firing bo'lib turgan vaqt davomida u Alertmanager'ga muntazam ravishda qayta yuboriladi, har yuborishda `endsAt` maydoni bilan: "shu vaqtgacha mendan yangilanish kelmasa, alert tugagan deb hisobla". Bundan ikki natija chiqadi:

- Prometheus o'lib qolsa, Alertmanager'dagi alert'lar bir muddatdan keyin o'zi "resolved" bo'ladi (yangilanish kelmadi). Shuning uchun "resolved" xabari har doim ham "muammo tuzaldi" degani emas.
- Alertmanager qayta ishga tushsa, bir necha soniyada hamma faol alert'ni yana oladi, chunki Prometheus yuborishda davom etadi.

Alertmanager manzili `prometheus.yml` da beriladi:

```yaml
rule_files:
  - /etc/prometheus/rules/*.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]
```

`rule_files` qoidalar yotgan fayllar (1-darsda recording rule'lar uchun yozgansiz, alerting rule'lar ham shu yerdan o'qiladi). `alerting.alertmanagers` ostidagi `targets` Compose servis nomi va port. Ulanganini Prometheus UI'da Status menyusidagi Alertmanager'lar ro'yxatidan (yoki "Runtime & build information" sahifasidan, versiyaga qarab) ko'rasiz.

### Real ishda qachon kerak

Incident'dan keyin "nega bilmay qoldik" yoki "nega 300 ta xabar keldi" degan savolga javob shu jadvaldan boshlanadi: muammo shartda (Prometheus) bo'lganmi yoki yetkazishda (Alertmanager). Alert Prometheus'ning Alerts sahifasida firing, lekin xabar kelmagan bo'lsa, Alertmanager tomonini qaraysiz: route, silence, inhibition, receiver xatosi.

### Nima uchun shunday

Bitta dastur o'rniga ikkita bo'lishining sababi: shartni hisoblash ma'lumotga yaqin turishi kerak (har Prometheus o'z ma'lumoti bo'yicha), yetkazish esa markazda bo'lishi kerak. Kompaniyada o'nlab Prometheus bo'lishi mumkin, lekin "kim navbatda, qaysi kanal" degan bilim bitta joyda turgani ma'qul. Ikkinchi sabab ishonchlilik: ikkita bir xil Prometheus (HA juftligi, ya'ni biri o'lsa ikkinchisi ishlashi uchun dublikat) bir xil alert'ni yuborsa, Alertmanager ularni label'lari bo'yicha bitta deb biladi va odam bitta xabar oladi. Muqobili 6-bo'limda: Grafana Alerting ikkala vazifani bitta dasturda bajaradi.

## 2. Prometheus alerting rules

### Qoida tuzilishi

Alerting rule recording rule bilan bir xil faylda, bir xil `groups` tuzilishida yoziladi, faqat `record` o'rnida `alert` turadi. Misol (host diski, vazifalardagi alert'lardan boshqa holat):

```yaml
groups:
  - name: host_alerts
    rules:
      - alert: HostDiskSpaceLow
        expr: |
          node_filesystem_avail_bytes{fstype!="tmpfs"}
            / node_filesystem_size_bytes{fstype!="tmpfs"} < 0.10
        for: 10m
        labels:
          severity: warning
          team: infra
        annotations:
          summary: "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is almost full"
          description: "Free space is {{ $value | humanizePercentage }}."
          runbook_url: "https://example.org/runbooks/host-disk-space-low"
```

Qatorma-qator:

- `alert` alert nomi, natijada `alertname` label'iga aylanadi.
- `expr` PromQL ifoda. Taqqoslash operatori (`< 0.10`) filtr sifatida ishlaydi: shartga mos kelmagan seriyalar natijadan tushib qoladi (1-dars). Natijada qolgan **har seriya alohida alert instansi**. Uchta filesystem chegaradan past bo'lsa, bitta qoidadan uchta alert chiqadi, har biri o'z `instance` va `mountpoint` label'lari bilan. Bo'sh natija "alert yo'q" degani.
- `for` shart shuncha vaqt uzluksiz bajarilgandan keyingina alert firing bo'ladi.
- `labels` alert'ga qo'shiladigan label'lar. Ular `expr` natijasidagi label'lar bilan birlashadi.
- `annotations` odam o'qiydigan matnlar. `{{ ... }}` ichidagi qismlar shablon.

`fstype!="tmpfs"` selector'i misol xolos: Zorin'da va Docker Desktop VM'ida filesystem turlari va mountpoint'lar har xil, o'z mashinangizdagi qiymatlarni ko'rib tanlang (Laboratoriya bo'limi).

### Holatlar va `for` mexanizmi

Har alert instansi uch holatdan birida bo'ladi:

| Holat | Ma'nosi | Alertmanager'ga yuboriladimi |
|-------|---------|------------------------------|
| `inactive` | shart bajarilmayapti (ifoda bu seriyani qaytarmadi) | yo'q |
| `pending` | shart bajarildi, lekin `for` muddati hali to'lmadi | yo'q |
| `firing` | shart `for` davomida har hisobda bajarildi | ha, qayta-qayta |

`evaluation_interval: 15s` va `for: 10m` bo'lsa: birinchi "rost" hisobda alert `pending` ga o'tadi va vaqt belgilanadi. Keyingi har 15 soniyalik hisobda Prometheus ikki narsani tekshiradi: seriya hali natijada bormi va birinchi belgidan beri 10 daqiqa o'tdimi. Ikkalasi ha bo'lsa `firing`. Orada bitta hisobda seriya natijada bo'lmasa, alert `inactive` ga qaytadi va hisob noldan boshlanadi. `for` yozilmasa birinchi "rost" hisobdayoq `firing`.

Prometheus UI'ning Alerts sahifasida har qoida holati bo'yicha rang bilan ko'rinadi, ochilganda instanslar, ularning label'lari, holati, qachondan beri faol ekani va joriy qiymati turadi (ko'rinish versiyaga qarab farq qiladi, holat nomlari bir xil). Faol alert'lar oddiy seriya sifatida ham mavjud:

```
ALERTS{alertname="HostDiskSpaceLow", alertstate="pending", instance="node-exporter:9100", mountpoint="/", severity="warning", team="infra"}  1
```

`ALERTS` Prometheus o'zi yozadigan sintetik seriya: har faol alert uchun bittadan, `alertstate` label'i `pending` yoki `firing`. Uni grafikka chizib "alert qachon yonib-o'chgan" degan tarixni ko'rish mumkin.

Xabar odamga yetguncha kechikish bir nechta bo'lakdan yig'iladi: scrape interval (yangi qiymat Prometheus'ga tushguncha), `evaluation_interval` (keyingi hisobgacha), `for`, va Alertmanager'dagi `group_wait` (3-bo'lim). Har biri kichik, yig'indisi sezilarli.

`keep_firing_for` teskari tomon uchun: shart yo'qolgandan keyin ham alert'ni ko'rsatilgan muddat firing holatida ushlab turadi. Bu flapping'ga, ya'ni alert'ning qisqa oraliqda yonib-o'chib, har safar yangi "firing" va "resolved" xabar yuborishiga qarshi.

### Label va annotation farqi

| | `labels` | `annotations` |
|---|----------|---------------|
| Kim uchun | mashina: Alertmanager routing, guruhlash, inhibition, silence | odam: nima bo'ldi, nima qilish kerak |
| Alert identifikatoriga kiradimi | ha | yo'q |
| Odatdagi mazmun | `severity`, `team`, `service` | `summary`, `description`, `runbook_url`, `dashboard_url` |

Alert'ning identifikatori (fingerprint) uning to'liq label to'plami. Label to'plami boshqa bo'lsa, bu boshqa alert. Shablonda mavjud narsalar: `{{ $labels.<nom> }}` (seriya label'i), `{{ $value }}` (ifodaning hisoblangan qiymati), va formatlovchi funksiyalar: `humanize` (`1234567` → `1.235M`), `humanizePercentage` (`0.0734` → `7.34%`), `humanizeDuration` (soniyalarni `1h 2m 3s` shakliga).

Qiymat o'zgaruvchan narsa, shuning uchun u annotation'da turadi. Label'ga har hisobda o'zgaradigan narsa yozilsa nima bo'lishi 5-vazifada, mexanizmi shu jadvalning ikkinchi qatorida.

### Ma'lumot yo'q bo'lsa alert ham yo'q

`expr` bo'sh natija qaytarsa alert yo'q. Bo'sh natijaning ikki sababi bor: shart bajarilmayapti (yaxshi) yoki seriyaning o'zi yo'q (yomon: target o'lgan, metrika nomi o'zgargan, exporter olib tashlangan). Prometheus bu ikkisini farqlamaydi. Yuqoridagi disk qoidasi `node-exporter` to'xtasa jim turadi, chunki `node_filesystem_avail_bytes` seriyasi yo'qoladi va "10% dan kam" sharti hech narsaga mos kelmaydi.

Buni yopadigan ikki vosita bor: har target uchun Prometheus o'zi yozadigan `up` seriyasi (1-dars: scrape muvaffaqiyatli bo'lsa 1, aks holda 0) va `absent(<selector>)` funksiyasi, u selector'ga mos seriya umuman bo'lmasa qiymati 1 bo'lgan bitta seriya qaytaradi, bo'lsa bo'sh natija. Farqi: `up` target scrape config'da turgan, lekin javob bermayotgan holatni ushlaydi; `absent()` seriya umuman yo'q holatni (target config'dan olib tashlangan yoki metrika nomi o'zgargan).

### Tekshirish: promtool

```
$ docker compose exec prometheus promtool check rules /etc/prometheus/rules/host.yml
Checking /etc/prometheus/rules/host.yml
  SUCCESS: 1 rules found
```

`check rules` sintaksisni tekshiradi: YAML, PromQL va shablon tahlil qilinadi. U "bu alert to'g'ri vaqtda firing bo'ladimi" degan savolga javob bermaydi. Buning uchun `promtool test rules`: sun'iy seriyalar beriladi va ma'lum vaqtda qaysi alert qaysi label'lar bilan firing bo'lishi kutilishi yoziladi.

```yaml
rule_files:
  - host.yml
evaluation_interval: 1m
tests:
  - interval: 1m
    input_series:
      - series: 'node_filesystem_avail_bytes{instance="h1", mountpoint="/", fstype="ext4"}'
        values: '5+0x20'
      - series: 'node_filesystem_size_bytes{instance="h1", mountpoint="/", fstype="ext4"}'
        values: '100+0x20'
    alert_rule_test:
      - eval_time: 5m
        alertname: HostDiskSpaceLow
        exp_alerts: []
```

`input_series` sun'iy ma'lumot: `values: '5+0x20'` "5 dan boshla, har qadamda 0 qo'sh, yana 20 marta", ya'ni 21 daqiqa davomida 5. Bo'sh joy 5/100 = 5%, shart bajariladi. `alert_rule_test` da 5-daqiqada `exp_alerts: []` deyilgan: firing alert kutilmaydi, chunki `for: 10m` hali to'lmagan (alert `pending`, test faqat firing'ni sanaydi). `eval_time: 15m` uchun esa `exp_labels` va `exp_annotations` bilan to'liq alert kutilishi yoziladi. Test `rule_files` dagi yo'lni test fayli turgan papkaga nisbatan qidiradi. Muvaffaqiyatli o'tsa chiqish `SUCCESS` bilan tugaydi, aks holda kutilgan va haqiqiy alert'lar farqi chiqadi.

### Real ishda qachon kerak

Qoidalar repoda turadi va CI pipeline'da (cicd moduli) `promtool check rules` va `promtool test rules` ishlaydi: buzuq qoida production'ga yetmaydi. Kimdir chegarani o'zgartirsa, test "bu holatda alert endi firing bo'lmaydi" deb yiqiladi va o'zgarish ongli muhokama qilinadi.

### Nima uchun shunday

`for` ning muqobili har qisqa sakrashga xabar yuborish bo'lardi: bitta sekin scrape yoki deploy paytidagi 20 soniyalik uzilish odamni bezovta qiladi. Narxi: xabar `for` qadar kechikadi, shuning uchun u incident'ning qancha qismini "ko'rmay turishga" rozi ekaningizni bildiradi. Label va annotation ajratilganining sababi: mashina uchun barqaror kalit kerak (guruhlash va silence shu bo'yicha ishlaydi), odam uchun esa o'zgaruvchan tafsilot. Ikkalasi bitta maydonda bo'lsa, qiymat har o'zgarganda alert "yangi" bo'lib qolardi.

## 3. Alertmanager: routing va guruhlash

### Alertmanager nima qiladi

Alertmanager Prometheus'dan kelgan alert'larni xabarga aylantiradigan alohida dastur. Unga kelgan har alert label to'plami xolos. U bitta YAML fayl (`alertmanager.yml`) bo'yicha ishlaydi, asosiy bo'limlari: `route` (daraxt: qaysi alert qaysi receiver'ga), `receivers` (xabar qayerga va qanday yuboriladi), `inhibit_rules` (4-bo'lim). U PromQL bilmaydi va metrikalarni ko'rmaydi: qaror faqat label'lar asosida qabul qilinadi. Shuning uchun 2-bo'limdagi `labels` (`severity`, `team`) aslida Alertmanager uchun yoziladi.

### Routing tree

`route` daraxt: ildiz va ichma-ich bolalar (`routes`). Misol (vazifadagidan boshqa tuzilish):

```yaml
route:
  receiver: log
  group_by: [alertname, team]
  routes:
    - matchers: ['team="db"']
      receiver: db-chat
      routes:
        - matchers: ['severity="critical"']
          receiver: db-pager
    - matchers: ['env="staging"']
      receiver: blackhole
```

Aylanib chiqish qoidalari:

1. Har alert ildizdan kiradi. Ildizda `matchers` yo'q, u hamma alert'ga mos keladi va uning `receiver` i default hisoblanadi.
2. Bolalar yozilgan tartibda tekshiriladi. `matchers` ro'yxatidagi hamma shart bajarilsa (ular orasida "va" amali), alert shu tarmoqqa tushadi va shu tarmoqning bolalari tekshiriladi.
3. Mos kelgan tarmoqdan keyin qardoshlar tekshirilmaydi, agar o'sha tarmoqda `continue: true` yozilmagan bo'lsa.
4. Hech bir bola mos kelmasa, alert ota tugunning receiver'ida qoladi.
5. Bola `group_by`, `group_wait` kabi sozlamalarni otadan meros oladi, o'zida yozilgani ustun.

Matcher sintaksisi: `label="qiymat"`, `label!="qiymat"`, `label=~"regex"`, `label!~"regex"`. Eski config'larda uchraydigan `match` va `match_re` kalitlari deprecated, yangi config'da `matchers` ishlatiladi.

Daraxtni Alertmanager'ni ishlatmasdan sinash mumkin. `amtool config routes test` label to'plami qaysi receiver'ga borishini aytadi:

```
$ docker compose exec alertmanager amtool config routes test \
    --config.file=/etc/alertmanager/alertmanager.yml team=db severity=critical
db-pager
$ docker compose exec alertmanager amtool config routes test \
    --config.file=/etc/alertmanager/alertmanager.yml team=db severity=warning
db-chat
$ docker compose exec alertmanager amtool config routes test \
    --config.file=/etc/alertmanager/alertmanager.yml team=web env=staging
blackhole
$ docker compose exec alertmanager amtool config routes test \
    --config.file=/etc/alertmanager/alertmanager.yml team=web
log
```

Birinchisi: `team="db"` tarmog'iga tushdi, ichidagi `severity="critical"` bolasi ham mos keldi, eng chuqur mos tugun yutadi. Ikkinchisi: `db` tarmog'iga tushdi, bolasi mos kelmadi, shu tarmoqning o'z receiver'i. Uchinchisi: birinchi bola mos emas, ikkinchisi mos. To'rtinchisi: hech biri mos emas, ildizning `log` i. E'tibor bering: `team=db env=staging` alert'i `db-chat` ga boradi, `blackhole` ga emas, chunki birinchi qardosh mos keldi va `continue` yo'q. `amtool config routes show` daraxtning o'zini chizib beradi.

### Guruhlash: `group_by`

Bitta sabab ko'pincha o'nlab alert tug'diradi: tarmoq uzilsa 50 ta instans birdan "down". Alertmanager alert'larni **guruh**ga yig'adi va guruh uchun bitta xabar yuboradi. Guruh kaliti: alert tushgan route va `group_by` da sanalgan label'larning qiymatlari. `group_by: [alertname, team]` bo'lsa, `alertname` va `team` i bir xil hamma alert bitta xabarda ro'yxat bo'lib keladi.

`group_by` qanchalik keng bo'lsa (kam label), xabar shunchalik kam, lekin bitta xabar ichida aloqasiz narsalar aralashadi. Juda tor bo'lsa (ko'p label, yoki maxsus `group_by: ['...']` qiymati, u har alert'ni alohida guruh qiladi), incident paytida yuzlab xabar keladi.

### Uchta taymer

| Parametr | Default | Qachon ishlaydi |
|----------|---------|-----------------|
| `group_wait` | 30s | yangi guruh paydo bo'ldi: birinchi xabardan oldin shuncha kutiladi, shu sababdan chiqqan qo'shni alert'lar ham yig'ilib olsin |
| `group_interval` | 5m | guruh bo'yicha xabar yuborilgan: guruh tarkibi o'zgarsa (yangi alert qo'shildi yoki biri resolved bo'ldi), keyingi xabar oldingisidan kamida shuncha keyin |
| `repeat_interval` | 4h | guruhda hech narsa o'zgarmadi va alert'lar hali firing: shuncha vaqtdan keyin eslatma |

Mexanizm: guruh birinchi alert kelganda yaratiladi va `group_wait` dan keyin birinchi marta "flush" qilinadi (xabar yuboriladi). Shundan keyin guruh har `group_interval` da tekshiriladi: tarkib o'zgargan bo'lsa yangi xabar, o'zgarmagan bo'lsa oxirgi xabardan beri `repeat_interval` o'tgandagina takror. Demak eslatma faqat `group_interval` qadamlarida ketadi.

Ishlangan misol: `group_wait: 30s`, `group_interval: 5m`, `repeat_interval: 4h`, uchta instans ketma-ket yiqiladi.

| Vaqt | Hodisa | Xabar |
|------|--------|-------|
| 10:00:00 | A alert'i keldi, guruh yaratildi | yo'q, `group_wait` boshlandi |
| 10:00:20 | B keldi (o'sha guruh) | yo'q |
| 10:00:30 | `group_wait` tugadi | 1-xabar: firing A, B |
| 10:02:00 | C keldi | yo'q, `group_interval` kutilmoqda |
| 10:05:30 | birinchi `group_interval` qadami, tarkib o'zgargan | 2-xabar: firing A, B, C |
| 10:10:30 ... | qadamlar, o'zgarish yo'q | yo'q |
| 10:40:00 | B resolved bo'ldi | yo'q |
| 10:40:30 | navbatdagi qadam, tarkib o'zgargan | 3-xabar: A, C firing, B resolved (`send_resolved: true` bo'lsa) |
| 14:40:30 | o'zgarish yo'q, oxirgi xabardan 4 soat o'tdi | 4-xabar: eslatma |

C alert'i uchun kechikish 3.5 daqiqa bo'ldi: `group_interval` shovqinni kamaytiradi, lekin mavjud guruhga qo'shilgan yangi alert'ni kechiktiradi.

### Real ishda qachon kerak

Jamoa ko'payganda routing tree "kim nimaga javobgar" xaritasiga aylanadi: yangi servis qo'shilsa, unga `team` label'i beriladi va daraxtga bitta tarmoq qo'shiladi. Config o'zgarishi review'dan o'tadi va CI'da `amtool check-config` hamda bir nechta `routes test` buyrug'i ishlaydi, chunki tartibdagi xato "critical alert hech kimga yetmadi" degan eng qimmat xato.

### Nima uchun shunday

Routing label'lar bo'yicha bo'lgani uchun alert yozuvchi (servis jamoasi) va yetkazishni sozlovchi (platforma jamoasi) bir-biriga bog'lanmaydi: ular faqat label nomlari to'g'risida kelishadi. Muqobili, ya'ni har qoidaga "shu chat'ga yubor" deb yozish, navbatchi almashganda yuzlab qoidani tahrirlashni talab qilardi. Uchta alohida taymer bo'lishining sababi: "birinchi xabar tez kelsin", "o'zgarishlar oqimi bosib qolmasin" va "unutilmasin" uch xil talab, bitta son bilan uchalasini qondirib bo'lmaydi.

## 4. Inhibition, silence va receiver'lar

### Inhibition

Inhibition bu boshqa alert firing bo'lgani uchun buni avtomatik bostirish. Misol: bitta narsa uchun warning va critical ikkala alert firing bo'lsa, warning ortiqcha.

```yaml
inhibit_rules:
  - source_matchers: ['severity="critical"']
    target_matchers: ['severity="warning"']
    equal: [alertname, instance]
```

O'qilishi: `source_matchers` ga mos alert firing bo'lsa, `target_matchers` ga mos alert'lar bostiriladi, lekin faqat `equal` da sanalgan label'lari source bilan bir xil bo'lganlari. `equal` siz bitta critical butun tizimdagi hamma warning'ni o'chirib qo'yardi. Bostirilgan alert yo'qolmaydi: Prometheus'da firing, Alertmanager UI'da "Inhibited" belgisini yoqsangiz ko'rinadi, faqat xabar ketmaydi. Source tugashi bilan target yana oddiy alert.

### Silence

Silence bu odam qo'lda yaratadigan, vaqt bilan cheklangan "shu matcher'larga mos alert'lar bo'yicha xabar yuborma" yozuvi. Rejali ish (serverni yangilash) yoki allaqachon ma'lum, ustida ishlanayotgan muammo uchun. UI'dan yoki `amtool` bilan:

```
$ docker compose exec alertmanager amtool silence add \
    --alertmanager.url=http://localhost:9093 \
    --author=zafar --duration=30m --comment="disk cleanup in progress" \
    alertname=HostDiskSpaceLow team=infra
<silence-id>
$ docker compose exec alertmanager amtool silence query --alertmanager.url=http://localhost:9093
ID            Matchers                                    Ends At     Created By  Comment
<silence-id>  alertname="HostDiskSpaceLow" team="infra"  <vaqt> UTC  zafar       disk cleanup in progress
```

Bu yerda `localhost` to'g'ri, chunki `amtool` Alertmanager konteynerining ichida ishlayapti. `silence add` yangi silence'ning ID'sini qaytaradi; `silence query` faol silence'larni, `silence expire <id>` muddatidan oldin tugatishni bajaradi. Silence Alertmanager'ning o'z diskida saqlanadi (config faylida emas), shuning uchun git'ga tushmaydi va ikkinchi mashinada bo'lmaydi.

Uchinchi vosita: jadval bo'yicha o'chirish. Config'da `time_intervals` nomlanadi va route'da `mute_time_intervals` yoki `active_time_intervals` orqali ishlatiladi (masalan warning'lar faqat ish vaqtida). Uchala holatda ham alert Prometheus'da firing bo'lib qoladi, faqat xabar ketmaydi.

### Receiver'lar

Receiver nomlangan yuborish joyi. Bitta receiver ichida bir nechta integratsiya bo'lishi mumkin: `webhook_configs`, `telegram_configs`, `email_configs`, `slack_configs`, shuningdek PagerDuty, Opsgenie, Discord, MS Teams va boshqalar.

**Webhook** universal: Alertmanager ko'rsatilgan URL'ga JSON bilan HTTP `POST` yuboradi. Qo'llab-quvvatlanmaydigan har qanday tizim shu orqali ulanadi. Bitta guruh uchun body:

```json
{
  "version": "4",
  "groupKey": "<...>",
  "truncatedAlerts": 0,
  "status": "firing",
  "receiver": "log",
  "groupLabels": { "alertname": "HostDiskSpaceLow", "team": "infra" },
  "commonLabels": { "alertname": "HostDiskSpaceLow", "severity": "warning", "team": "infra" },
  "commonAnnotations": {},
  "externalURL": "http://<...>:9093",
  "alerts": [
    {
      "status": "firing",
      "labels": { "alertname": "HostDiskSpaceLow", "instance": "node-exporter:9100", "mountpoint": "/", "severity": "warning", "team": "infra" },
      "annotations": { "summary": "Disk / on node-exporter:9100 is almost full", "description": "Free space is 7.34%." },
      "startsAt": "<sana>T10:00:05.<...>Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "generatorURL": "http://<...>:9090/graph?<...>",
      "fingerprint": "<...>"
    }
  ]
}
```

`status` guruh holati: ichida kamida bitta firing alert bo'lsa `firing`, hammasi tugagan bo'lsa `resolved`. `groupLabels` shu guruhni hosil qilgan `group_by` qiymatlari. `commonLabels` va `commonAnnotations` guruhdagi hamma alert'da bir xil bo'lganlari (ikkita alert'ning `summary` si har xil bo'lsa, u `commonAnnotations` ga kirmaydi). `alerts[]` har alert alohida: o'z `status` i, to'liq label va annotation'lari, `startsAt` (firing bo'lgan vaqt), `endsAt` (firing paytida nol qiymat, resolved bo'lganda haqiqiy vaqt), `generatorURL` (Prometheus'da shu ifodaga havola), `fingerprint` (label to'plamidan hisoblangan identifikator).

**`send_resolved`**: `true` bo'lsa, alert tugaganda ham xabar ketadi. Default integratsiyaga qarab har xil (webhook'da yoqilgan, email'da o'chirilgan), shuning uchun har receiver'da aniq yozing.

**Telegram** (`telegram_configs`): asosiy kalitlar `bot_token` yoki `bot_token_file`, `chat_id`, `message` (shablon), `parse_mode`, `send_resolved`. Bot @BotFather orqali yaratiladi; chat ID'ni qanday bilish Telegram Bot API hujjatida (Manbalar). Token fayldan o'qilgani uchun `alertmanager.yml` ni xavfsiz commit qilish mumkin.

**Email** (`email_configs`): `to`, `from`, `smarthost` (SMTP server `host:port`), `require_tls`, autentifikatsiya uchun `auth_username` va `auth_password` yoki `auth_password_file`. Umumiy qiymatlarni `global` bo'limida (`smtp_smarthost`, `smtp_from`, `smtp_require_tls`) bir marta berish mumkin. Laboratoriyada haqiqiy pochta o'rniga Mailpit ishlatiladi: u SMTP'ni qabul qilib, xatni hech kimga yubormaydi, faqat o'z UI'sida ko'rsatadi.

Xabar matni Go template bilan yoziladi (2-bo'limdagi qoida shablonidan boshqa ma'lumot bilan: bu yerda butun guruh mavjud). `.Status`, `.GroupLabels`, `.CommonLabels`, `.CommonAnnotations` va `.Alerts` ro'yxati bor:

```
{{ range .Alerts }}{{ .Labels.instance }}: {{ .Annotations.description }}
{{ end }}
```

Bu guruhdagi har alert uchun bir qator chiqaradi. Katta shablonlar alohida faylda turadi va config'ning `templates:` ro'yxatida ko'rsatiladi.

Config tekshiruvi:

```
$ docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
Checking '/etc/alertmanager/alertmanager.yml'  SUCCESS
Found:
 - global config
 - route
 - 1 inhibit rules
 - 2 receivers
 - 0 templates
```

Alertmanager config'ni ishga tushganda va reload signalida (`docker compose kill -s SIGHUP alertmanager`) o'qiydi. Faylni tahrirlashning o'zi hech narsani o'zgartirmaydi.

### Real ishda qachon kerak

Deploy yoki migratsiya oldidan silence yaratish odatiy qadam (ko'pincha pipeline'ning o'zi yaratadi va tugagach olib tashlaydi). Inhibition qoidalari incident'dan keyin paydo bo'ladi: "asosiy sabab bitta edi, yonida 40 ta xabar keldi" degan kuzatuv yangi inhibit rule'ga aylanadi.

### Nima uchun shunday

Inhibition va silence ikkalasi ham xabarni to'xtatadi, lekin bilim manbai boshqa: inhibition tizim tuzilishi haqidagi doimiy bilim (config'da, git'da, avtomatik), silence esa odamning shu kungi qarori (vaqtinchalik, muallif va izoh bilan). Alert'ni qoidadan o'chirib tashlash muqobil emas: ish tugagach uni qaytarishni unutish oson, silence esa o'zi tugaydi. Token'ning `*_file` orqali berilishi config'ni secret'dan ajratadi: config hamma ko'radigan repoda, secret alohida kanalda (docker moduli va cicd modulidagi secret qoidalari bilan bir xil g'oya).

## 5. Nimaga alert qilish kerak

### Symptom va cause

Symptom bu foydalanuvchi sezadigan narsa (so'rovlar xato qaytaryapti, sahifa sekin). Cause bu uning ehtimoliy sababi (CPU band, disk to'la, konteyner qayta ishga tushdi).

| | Symptom-based | Cause-based |
|---|---|---|
| Misol | xato ulushi yuqori, latency yuqori | CPU > 90%, bitta konteyner restart bo'ldi |
| Foydalanuvchiga ta'siri | aniq bor | noma'lum, ko'pincha yo'q |
| Soni | kam (har servisga 2–4) | cheksiz o'sadi |

**Page** bu odamni darhol bezovta qiladigan (tunda uyg'otadigan) xabar. Page faqat symptom'ga beriladi: foydalanuvchi hozir zarar ko'ryapti yoki tez orada ko'radi (masalan disk joriy tezlikda bir necha soatda to'ladi, buni `predict_linear` funksiyasi bilan ifodalash mumkin). Cause metrikalari dashboard'da turadi va symptom alert'idan keyin diagnostikada ishlatiladi (1-darsdagi RED symptom tomoni, USE cause tomoni). CPU 95% bo'lib, latency va xato joyida bo'lsa, bu muammo emas, samarali ishlatilgan server.

Har alert uchun uchta savol: bu haqiqiymi, shoshilinchmi, odam biror narsa qila oladimi? Bittasiga "yo'q" bo'lsa, bu page emas: ticket (ish vaqtida ko'riladigan vazifa), dashboard yoki o'chirib tashlash.

### SLI, SLO va error budget

- **SLI** (service level indicator) o'lchov: masalan muvaffaqiyatli so'rovlar ulushi.
- **SLO** (service level objective) shu o'lchov uchun maqsad: masalan 30 kunda 99.5%.
- **Error budget** ruxsat etilgan nosozlik: `1 - SLO`. 99.5% uchun 0.5%.

Vaqtga aylantirsak: 30 kun = 30 × 24 × 60 = 43 200 daqiqa. 99.5% SLO'da budget 43 200 × 0.005 = 216 daqiqa to'liq uzilish; 99% da 432 daqiqa. SLO'ga bitta "to'qqiz" qo'shilishi budget'ni o'n marta qisqartiradi.

### Burn rate

Burn rate budget qanchalik tez sarflanayotganini ko'rsatadi:

```
burn rate = error ratio / (1 - SLO)
```

Burn rate 1 bo'lsa budget aynan SLO davri oxirida (30 kunda) tugaydi. 99.5% SLO'da xato ulushi 2% bo'lsa: 0.02 / 0.005 = 4, budget 30 / 4 = 7.5 kunda tugaydi.

Alert chegarasi "qancha vaqtda budget'ning qancha qismi yonsa odam bilishi kerak" degan qarordan chiqadi: `burn rate = yongan ulush × davr / oyna`. 30 kun = 720 soat.

| Oyna | Yongan budget | Burn rate | Budget tugashiga | Harakat |
|------|---------------|-----------|------------------|---------|
| 1h | 2% | 0.02 × 720 / 1 = 14.4 | 30 kun / 14.4 = 50 soat | page |
| 6h | 5% | 0.05 × 720 / 6 = 6 | 5 kun | page |
| 3d (72h) | 10% | 0.10 × 720 / 72 = 1 | 30 kun | ticket |

Burn rate SLO'ga bog'liq emas, xato ulushi chegarasi esa bog'liq: 99.5% SLO'da 14.4 burn rate 14.4 × 0.005 = 7.2% xato ulushi, 6 esa 3%.

### Multi-window, multi-burn-rate

Har bosqichda ikki oyna "va" bilan birga ishlatiladi: uzun oyna muammo jiddiy ekanini, undan 12 marta qisqa oyna muammo hozir ham davom etayotganini tasdiqlaydi. Bitta bosqich bo'lagi (99.5% SLO'li boshqa servis uchun, recording rule'lar oldindan yozilgan deb):

```yaml
- alert: CheckoutErrorBudgetFastBurn
  expr: |
    job:slo_errors:ratio_rate1h{job="checkout"} > (14.4 * 0.005)
    and
    job:slo_errors:ratio_rate5m{job="checkout"} > (14.4 * 0.005)
  labels:
    severity: critical
```

Vaqtlarni hisoblaymiz. Xato ulushi 0% dan birdan 100% ga chiqsa, 1 soatlik oynaning o'rtachasi 7.2% dan 0.072 × 60 = 4.3 daqiqada oshadi, 5 daqiqalik oyna allaqachon 100%: alert taxminan 4–5 daqiqada firing. Xato ulushi 10% bo'lsa, 1 soatlik o'rtacha 7.2% ga 0.72 × 60 = 43 daqiqada yetadi. Xato ulushi 5% bo'lsa bu bosqich umuman ishlamaydi (5% < 7.2%), uni sekin bosqich (3% chegara, 6 soatlik oyna) ushlaydi. Muammo tugagach esa 5 daqiqalik oyna 5 daqiqada tozalanadi va alert o'chadi; qisqa oyna bo'lmasa, 1 soatlik o'rtacha tushguncha alert yana uzoq firing turardi.

### Monitoringni kim kuzatadi

Prometheus yoki Alertmanager o'lsa, hech qanday alert kelmaydi va bu "hammasi yaxshi" bilan bir xil ko'rinadi. Yechim **dead man's switch**: sharti doim rost bo'lgan, ya'ni doim firing turadigan alert (odatda `Watchdog` deb nomlanadi) alohida route orqali qisqa `repeat_interval` bilan tashqi qabul qiluvchiga boradi. Qabul qiluvchi teskari mantiq bilan ishlaydi: xabar kelib tursa jim, kelmay qolsa u o'zi bong uradi. Nomi poyezd mashinisti pedalidan: pedal bosib turilmasa poyezd to'xtaydi.

### Runbook

Runbook alert'ga biriktirilgan qisqa ko'rsatma (`runbook_url` annotation'i): alert nimani anglatadi, ta'siri, birinchi tekshiruvlar (qaysi dashboard, qaysi so'rov), ma'lum sabablar va tuzatish, kimga eskalatsiya. Tungi soat 3 da o'ylash emas, o'qish kerak.

### Real ishda qachon kerak

Alert fatigue'ni davolash doimiy ish: har hafta kelgan alert'lar ko'rib chiqiladi, harakatsiz yopilganlari tuzatiladi yoki o'chiriladi, severity halol belgilanadi (critical = hozir uyg'ot). SLO esa jamoalar orasidagi kelishuv vositasi: budget tugayotgan bo'lsa yangi funksiyalar to'xtatilib, ishonchlilik ustida ishlanadi.

### Nima uchun shunday

Oddiy "xato > 5%, `for: 5m`" chegarasi ikki tomondan yomon: 6 daqiqalik keskin sakrashga uyg'otadi, lekin kun bo'yi davom etgan 2% xatoni ko'rmaydi, holbuki ikkinchisi budget'ni ko'proq yeydi. Burn rate alert'i "hozirgi tezlikda va'damizni buzamizmi" degan savolga javob beradi, bu esa biznes uchun ahamiyatli yagona savol. Usul Google SRE Workbook'ning "Alerting on SLOs" bobidan, undagi 14.4 / 6 / 1 sonlari yuqoridagi jadvaldagi hisobdan chiqadi, sehrli sonlar emas.

## 6. Grafana Alerting

### Bu nima

Grafana'ning (2-dars) o'z alerting tizimi bor: qoidalarni Grafana'ning o'zi hisoblaydi (Grafana-managed rules) va ichiga o'rnatilgan Alertmanager orqali yuboradi. Ya'ni 1-bo'limdagi ikki bo'g'in bitta dasturda.

| | Prometheus + Alertmanager | Grafana Alerting |
|---|---|---|
| Qoida qayerda hisoblanadi | Prometheus | Grafana |
| Data source | faqat Prometheus | har qanday: Prometheus, Loki, SQL, Elasticsearch; bitta qoidada bir nechtasi |
| Config | YAML fayllar, git | UI, yoki `provisioning/alerting/` fayllari, API, Terraform |
| Yuborish | route, receiver | notification policy, contact point |
| Grafana o'chsa | alert'lar ishlayveradi | alert'lar to'xtaydi |

Terminlar mosligi: receiver = contact point, route = notification policy, `for` = pending period; silence va mute timing ikkalasida bor.

### Mexanizm

Grafana-managed qoida uch qadamdan iborat: so'rov (data source'ga, masalan PromQL), ifoda (natijani bitta songa keltirish va chegara bilan solishtirish) va baholash sozlamalari (qoida necha vaqtda bir hisoblanadi, pending period). Holatlari: Normal, Pending, Alerting, shuningdek NoData va Error. Oxirgi ikkitasi Prometheus qoidalarida yo'q: 2-bo'limda "ma'lumot yo'q bo'lsa alert jim" edi, Grafana'da esa ma'lumot kelmagani yoki so'rov xato bergani alohida holat va unda nima qilish har qoidaning o'zida sozlanadi.

UI'da yaratilgan qoida Grafana bazasida turadi (volume'da), git'da emas. Kod sifatida saqlash uchun 2-darsdagi provisioning mexanizmi ishlatiladi: `grafana/provisioning/alerting/` ichidagi fayllar Grafana ishga tushganda o'qiladi. Qoida, contact point va policy'ni UI'dan fayl ko'rinishida eksport qilish mumkin.

Grafana tashqi Alertmanager'ni data source sifatida ham ko'ra oladi: shunda Prometheus'dan kelgan alert'lar va silence'lar Grafana UI'da ko'rinadi va boshqariladi, hisoblash esa Prometheus'da qoladi.

### Real ishda qachon kerak

Amaliy tanlov: infratuzilma va servis metrikalari uchun Prometheus qoidalari (kod, test, Grafana'ga bog'liq emas); log yoki SQL asosidagi va PromQL'da ifodalab bo'lmaydigan shartlar uchun (masalan "oxirgi soatda buyurtmalar jadvaliga yozuv tushmadi") Grafana Alerting. Bitta alert'ni ikkala tizimda takrorlamang: ikki xabar keladi va qaysi biri asosiy ekani noma'lum bo'ladi.

### Nima uchun shunday

Grafana Alerting data source'lar xilma-xil bo'lgani uchun paydo bo'lgan: hamma narsa Prometheus'da turmaydi. Narxi: vizualizatsiya dasturi endi kritik yo'lda, u o'chsa alert ham yo'q. Prometheus yo'li esa kamroq narsaga bog'liq va `promtool` bilan test qilinadi, lekin faqat metrikalar bilan ishlaydi.

## 7. On-call va uning asboblari

### Jarayon

On-call bu ma'lum vaqt oralig'ida alert'larga javob berish uchun mas'ul bo'lish navbatchiligi.

- **Rotation**: navbatchilik jadvali (odatda haftalik), primary va secondary. Almashinuvda handoff: ochiq muammolar, shubhali joylar.
- **Escalation policy**: primary N daqiqada acknowledge qilmasa (ya'ni "ko'rdim, shug'ullanyapman" deb belgilamasa) xabar secondary'ga, keyin jamoa rahbariga o'tadi.
- **MTTA** (mean time to acknowledge) javobgacha o'rtacha vaqt, **MTTR** (mean time to recovery) tiklashgacha o'rtacha vaqt.
- **Post-incident review (postmortem)**: aybdor qidirmaydigan (blameless) tahlil: nima bo'ldi, qanday aniqlandi, nima uchun, nima o'zgartiriladi. 7-dars mini-loyihasida yozasiz.
- Sog'lom on-call belgisi: navbatda kam page (haftasiga bir nechta), har biri harakatli, runbook havolasi bor, dam olish kompensatsiyasi bor.

### Alertmanager nimani bilmaydi

Alertmanager faqat xabar yuboradi. "Hozir kim navbatda", "ko'rdimi", "javob bermasa kimga" degan savollar uning ishi emas: `repeat_interval` eslatma, eskalatsiya emas. Bu vazifalarni alohida toifadagi dasturlar bajaradi: on-call (incident response) tizimlari. Ular alert'ni Alertmanager'dan tayyor integratsiya yoki webhook orqali oladi, jadval bo'yicha navbatchini topadi va unga telefon, SMS yoki push orqali yetkazadi. Toifada bir nechta variant bor: tijoriy servislar (PagerDuty, Grafana Cloud IRM va boshqalar) va o'z serveringizda ishlatiladigan ochiq kodli loyihalar.

### Grafana OnCall holati

Grafana OnCall OSS shu toifadagi ochiq kodli loyiha edi (jadvallar, eskalatsiya, Telegram/Slack/telefon). Grafana Labs 2025-yil mart oyida uni maintenance mode'ga o'tkazganini va 2026-yil mart oyida arxivlash rejasini e'lon qilgan; rivojlanish Grafana Cloud IRM (OnCall va Incident birlashgan tijoriy mahsulot) ichida davom etadi. Bu sohada mahsulot holati tez o'zgaradi, shuning uchun joriy holatni o'zingiz tekshiring: https://github.com/grafana/oncall sahifasida repozitoriy arxivlanganmi (faqat o'qish uchun), oxirgi release qachon chiqqan.

Shu sabab bu darsda OnCall amaliyoti yo'q: qo'llab-quvvatlanmaydigan loyihani o'rnatishni o'rganish foydasiz. Amaliyot Alertmanager va Grafana Alerting bilan cheklanadi, on-call esa tushuncha darajasida.

### Real ishda qachon kerak

Kichik jamoada Alertmanager'dan Telegram guruhiga xabar yetarli. Tungi navbatchilik paydo bo'lishi bilan "xabar ketdi" yetmaydi, "odam ko'rgani tasdiqlandi" kerak bo'ladi va on-call tizimi qo'shiladi. Asbob tanlashda loyihaning tirikligi (oxirgi release, arxiv belgisi) texnik imkoniyatdan oldin tekshiriladi.

### Nima uchun shunday

Alertmanager ataylab tor: u holatsiz xabar marshrutizatori, odamlar jadvali va acknowledge holatini saqlamaydi. Bu uni sodda va ishonchli qiladi, jadval va eskalatsiya esa tashkilotga xos murakkab narsa bo'lib, alohida mahsulotga chiqarilgan. Muqobili (hammasini bitta dasturda qilish) Grafana IRM kabi mahsulotlar yo'li.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Alert | "shart bajarildi, odam bilishi kerak" degan avtomatik signal, texnik jihatdan label to'plami |
| Alerting rule | Prometheus'da PromQL ifoda, `for`, label va annotation'lardan iborat qoida |
| `evaluation_interval` | Prometheus qoidalarni necha vaqtda bir hisoblashi |
| inactive / pending / firing | alert holatlari: shart yo'q / shart bor, `for` to'lmagan / `for` to'lgan |
| `for` | shart uzluksiz bajarilishi kerak bo'lgan muddat |
| Flapping | alert'ning qisqa oraliqda qayta-qayta yonib-o'chishi |
| Label / annotation | mashina uchun kalit (routing, identifikator) / odam uchun matn |
| Fingerprint | alert'ning label to'plamidan hisoblangan identifikatori |
| Alertmanager | alert'larni guruhlab, yo'naltirib, xabar yuboradigan dastur |
| Routing tree | alert'ni label'lari bo'yicha receiver'ga olib boradigan daraxt |
| Matcher | label bo'yicha shart (`=`, `!=`, `=~`, `!~`) |
| Receiver | nomlangan yuborish joyi (webhook, Telegram, email) |
| Guruh | route va `group_by` qiymatlari bir xil alert'lar to'plami, bitta xabar bo'lib ketadi |
| `group_wait` / `group_interval` / `repeat_interval` | birinchi xabar oldidan kutish / o'zgarishlar orasidagi minimal oraliq / o'zgarishsiz eslatma oralig'i |
| Inhibition | boshqa alert firing bo'lgani uchun avtomatik bostirish |
| Silence | odam yaratadigan, muddatli "xabar yuborma" yozuvi |
| Webhook | hodisa haqida berilgan URL'ga HTTP `POST` yuborish usuli |
| `send_resolved` | alert tugaganda ham xabar yuborish sozlamasi |
| Alert fatigue | keraksiz xabarlar ko'pligidan haqiqiysiga ham reaksiya qilmay qo'yish |
| Symptom / cause | foydalanuvchi sezadigan oqibat / uning ehtimoliy sababi |
| Page / ticket | odamni darhol bezovta qiladigan xabar / ish vaqtida ko'riladigan vazifa |
| SLI / SLO | sifat o'lchovi / shu o'lchov uchun maqsad |
| Error budget | SLO ruxsat bergan nosozlik hajmi, `1 - SLO` |
| Burn rate | error budget sarflanish tezligi, `error ratio / (1 - SLO)` |
| Dead man's switch (Watchdog) | doim firing turadigan alert, uning kelmay qolishi monitoring o'lganini bildiradi |
| Runbook | alert'ga biriktirilgan qisqa harakat ko'rsatmasi |
| Contact point / notification policy | Grafana Alerting'dagi receiver / route |
| On-call, rotation, escalation | navbatchilik, uning jadvali, javob bo'lmaganda keyingi odamga o'tkazish |
| MTTA / MTTR | javobgacha / tiklashgacha o'rtacha vaqt |

## Tuzoqlar

- Cause'ga page qilish (CPU, xotira, bitta restart): tunda uyg'onasiz, qiladigan ish yo'q. Page faqat symptom'ga.
- `for` siz alert: bitta scrape'dagi sakrash xabar bo'lib ketadi. Juda uzun `for` esa incident boshini yashiradi.
- Ma'lumot yo'qolganda jim turadigan alert: seriya yo'q bo'lsa shart ham "bajarilmaydi". `up` va `absent()` qoidalarisiz ilova o'lganini bilmay qolasiz.
- Label'da har hisobda o'zgaradigan qiymat: alert identifikatori o'zgarib turadi.
- Config'da `localhost`: konteyner ichida bu o'sha konteynerning o'zi. Prometheus → Alertmanager va Alertmanager → webhook manzillari servis nomi bilan.
- Faylni tahrirlab reload qilmaslik: Prometheus ham, Alertmanager ham eski config bilan ishlayveradi. Avval `promtool check rules` / `amtool check-config`, keyin reload.
- Juda tor `group_by` yoki umuman guruhlamaslik: incident paytida yuzlab xabar.
- Routing'da tartib va `continue` ni tushunmaslik: critical alert umumiy tarmoqqa tushib, navbatchiga yetmaydi. `amtool config routes test` bilan tekshiring.
- `equal` siz inhibit rule: bitta alert aloqasi yo'q hamma narsani bostiradi.
- Muddatsiz yoki izohsiz silence: uch oydan keyin nima uchun alert kelmayotganini hech kim bilmaydi.
- "Resolved" ni "tuzaldi" deb o'qish: Prometheus o'lgan yoki seriya yo'qolgan bo'lsa ham alert resolved bo'ladi.
- Bot token yoki SMTP parolini config ichida commit qilish. `*_file` maydonlari va `.gitignore`.
- Ikkala mashinada stack'ni birga ishlatish: bitta bot, bitta chat, har xabar ikki marta.
- Ofisda sozlangan host alert'ini uyda ko'chirish: macOS'da `node-exporter` Docker Desktop VM'ini ko'rsatadi, label qiymatlari va chegaralar boshqa.
- Burn rate chegarasida SLO'ni unutish: 14.4 xato ulushi emas, ko'paytuvchi. Chegara `14.4 × (1 - SLO)`.
- Monitoringni monitoring qilmaslik: Alertmanager o'lsa hech kim xabar olmaydi. Watchdog kerak.
- Runbook'siz alert: har safar boshidan tekshiruv, MTTR uzayadi.

## Manbalar

- https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ – alerting rules, holatlar, shablonlar
- https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/ – `promtool test rules` formati
- https://prometheus.io/docs/alerting/latest/alertmanager/ – Alertmanager tushunchalari (grouping, inhibition, silence)
- https://prometheus.io/docs/alerting/latest/configuration/ – config ma'lumotnomasi, receiver'lar va ularning kalitlari
- https://prometheus.io/docs/alerting/latest/notifications/ – xabar shablonlaridagi ma'lumot tuzilishi
- https://prometheus.io/docs/practices/alerting/ – nimaga alert qilish kerak
- https://sre.google/workbook/alerting-on-slos/ – burn rate, multiwindow alert'lar (majburiy)
- https://sre.google/sre-book/monitoring-distributed-systems/ – symptom va cause
- https://sre.google/sre-book/being-on-call/ – on-call amaliyoti
- https://grafana.com/docs/grafana/latest/alerting/ – Grafana Alerting
- https://core.telegram.org/bots/api – Telegram Bot API (bot, chat ID, `getUpdates`)
- https://mailpit.axllent.org/ – Mailpit
- https://github.com/grafana/oncall – Grafana OnCall OSS repozitoriysi, joriy holatini shu yerdan tekshiring

---

## Birga bajaramiz

Bitta alert'ni qoidadan boshlab `pending`, `firing`, kelgan xabar va `resolved` gacha kuzatamiz. Ssenariy vazifalardagidan boshqa: Prometheus'ning o'z metrikasi bo'yicha ataylab ma'nosiz alert, chegarasi past qo'yilgani uchun darhol ishlaydi. 1–3 qadamlar uchun faqat Prometheus kerak. 4-qadamdan boshlab `alertmanager` servisi va webhook qabul qiluvchi kerak, ularni 7-vazifada o'zingiz qurasiz: yurishni avval o'qib chiqing, 7-vazifadan keyin o'z stack'ingizda takrorlang. Vaqtlar UTC'da va misol uchun; sizda soniyalar boshqa bo'ladi, oraliqlar esa shu config'da bir xil chiqishi kerak.

Sozlamalar: Prometheus'da `evaluation_interval: 15s`; Alertmanager ildiz route'ida `group_by: [alertname]`, `group_wait: 10s`, `group_interval: 1m`, `repeat_interval: 1h`, receiver webhook, `send_resolved: true`.

1. Qoida. `prometheus/rules/demo.yml`:

```yaml
groups:
  - name: demo
    rules:
      - alert: DemoHeadSeriesHigh
        expr: prometheus_tsdb_head_series > 100
        for: 1m
        labels:
          severity: info
        annotations:
          summary: "Prometheus holds {{ $value | humanize }} series in memory"
```

`prometheus_tsdb_head_series` Prometheus xotirasidagi faol seriyalar soni (1-dars, cardinality). Laboratoriyada u yuzdan ancha ko'p, shart doim rost.

2. Tekshirish va yuklash (14:00:00 da):

```
$ docker compose exec prometheus promtool check rules /etc/prometheus/rules/demo.yml
Checking /etc/prometheus/rules/demo.yml
  SUCCESS: 1 rules found
$ docker compose kill -s SIGHUP prometheus
```

`SIGHUP` Prometheus'ga config va qoidalarni qayta o'qishni aytadi, konteyner qayta ishga tushmaydi.

3. Holatlarni kuzatish. `http://localhost:9090` → Alerts:

| Vaqt | Hisob | Holat |
|------|-------|-------|
| 14:00:05 | birinchi hisob, shart rost | `pending` |
| 14:00:20, :35, :50 | shart rost, 1 daqiqa to'lmagan | `pending` |
| 14:01:05 | shart 60 soniyadan beri rost | `firing` |

Shu payt Graph sahifasida `ALERTS{alertname="DemoHeadSeriesHigh"}` so'rovi `alertstate="firing"` li bitta seriya qaytaradi. 14:01:05 gacha Alertmanager bu alert haqida hech narsa bilmaydi: `pending` yuborilmaydi.

4. Alertmanager. 14:01:05 da Prometheus alert'ni yuboradi, Alertmanager yangi guruh yaratadi va `group_wait` ni boshlaydi. `http://localhost:9093` da alert darhol ko'rinadi, xabar esa 14:01:15 da ketadi. Webhook servisining log'ida (`docker compose logs -f <servis>`):

```json
{
  "version": "4",
  "status": "firing",
  "receiver": "<receiver-nomi>",
  "groupLabels": { "alertname": "DemoHeadSeriesHigh" },
  "commonLabels": { "alertname": "DemoHeadSeriesHigh", "instance": "<...>", "job": "prometheus", "severity": "info" },
  "alerts": [
    {
      "status": "firing",
      "labels": { "alertname": "DemoHeadSeriesHigh", "instance": "<...>", "job": "prometheus", "severity": "info" },
      "annotations": { "summary": "Prometheus holds <N> series in memory" },
      "startsAt": "<sana>T14:01:05.<...>Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }
  ]
}
```

(Qisqartirilgan: `groupKey`, `externalURL`, `generatorURL`, `fingerprint` maydonlari ham bor.) `startsAt` 14:01:05, ya'ni firing bo'lgan vaqt, xabar esa 10 soniya keyin keldi: bu `group_wait`. `instance` va `job` label'lari qoidada yozilmagan, ular `expr` natijasidagi seriyadan keldi. `<N>` o'rnida `humanize` qilingan son (masalan `2.5k` ko'rinishida).

5. Jimlik. 14:02:15, 14:03:15, 14:04:15 da guruh tekshiriladi (`group_interval`), tarkib o'zgarmagan, `repeat_interval` (1 soat) o'tmagan: xabar yo'q. Prometheus bu orada alert'ni qayta-qayta yuborib turadi, Alertmanager ularni o'sha bitta alert deb biladi (deduplikatsiya).

6. Tugatish. 14:05:00 da qoidadagi chegarani ataylab yetib bo'lmaydigan songa o'zgartiramiz (`> 100000000`) va yana `promtool check rules`, keyin `SIGHUP`. 14:05:05 dagi hisobda ifoda bo'sh natija qaytaradi, alert `inactive` ga o'tadi va Prometheus Alertmanager'ga uni `endsAt` bilan "tugadi" deb yuboradi. Navbatdagi guruh qadami 14:05:15 da, tarkib o'zgargan:

```json
{
  "status": "resolved",
  "alerts": [
    { "status": "resolved", "startsAt": "<sana>T14:01:05.<...>Z", "endsAt": "<sana>T14:05:05.<...>Z" }
  ]
}
```

(Qolgan maydonlar oldingi xabardagidek.) Endi `endsAt` haqiqiy vaqt. Bu xabar faqat `send_resolved: true` bo'lgani uchun keldi.

7. Tozalash: `demo.yml` ni o'chiring, `SIGHUP` yuboring, Alerts sahifasida qoida yo'qolganini tekshiring.

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 1–2 | 2-bo'lim: qoida tuzilishi, `promtool check rules` |
| 3 | 2-bo'lim: holatlar va `for` mexanizmi, `ALERTS` seriyasi |
| 4 | 1-bo'lim: zanjir; 3-bo'lim: `group_wait`; 4-bo'lim: webhook payload |
| 5 | 3-bo'lim: `group_interval` va `repeat_interval`; 1-bo'lim: deduplikatsiya |
| 6 | 4-bo'lim: `send_resolved`; 2-bo'lim: bo'sh natija = alert yo'q |

Bu alert 5-bo'lim mezoni bo'yicha yomon alert: symptom emas, odam hech narsa qila olmaydi. U faqat mexanizmni ko'rsatish uchun.

---

## Vazifalar

Javoblar `observability/03-alerting/README.md` da (`make new m=observability n=03 name=alerting`), har vazifa uchun `## N. Title` ostida: config'ning muhim qismi, buyruq, kuzatilgan natija (xabar matni, holat, vaqt) va o'z so'zingiz bilan izoh. Stack fayllari (`prometheus/rules/alerts.yml`, `alertmanager/alertmanager.yml`, webhook servisi, `compose.yaml`) `observability/stack/` da; runbook'lar `observability/03-alerting/runbooks/` da. Hamma buyruq host'da `observability/stack/` papkasidan, `docker compose` orqali; ikkala mashinada bir xil. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozib qo'ying: vaqtlar va host label'lari shunga bog'liq. Sinov uchun ish mashinasini yuklamang: `loadgen`, konteynerni to'xtatish yoki vaqtincha past chegara.

### A. Alerting rules

1. **First alert rule.** `prometheus/rules/alerts.yml` da `InstanceDown` qoidasini yozing (`up == 0`, `for: 1m`, `severity`, `summary` annotation'ida instans nomi). `promtool check rules` (konteyner ichida) o'tsin, Prometheus'ga reload yuboring. `docker compose stop api` qiling va Prometheus UI'ning Alerts sahifasida inactive → pending → firing o'tishini vaqtlari bilan yozing. `ALERTS` seriyasini so'rang. Oxirida `api` ni qayta yoqing. Yo'nalish: 2-bo'lim, "Qoida tuzilishi" va "Holatlar va `for` mexanizmi".

2. **Tune for.** `for` ni olib tashlang va `api` ni 20 soniyaga to'xtatib qayta yoqing: alert firing bo'ldimi? `for: 1m` bilan takrorlang. `for` va `evaluation_interval` birga eng yomon holatda xabarni qancha kechiktirishini hisoblang (o'z `prometheus.yml` ingizdagi qiymatlar bilan). Yo'nalish: 2-bo'lim, "Holatlar va `for` mexanizmi".

3. **Symptom alerts.** `api` uchun ikkita symptom alert yozing: error ratio (5xx ulushi chegaradan yuqori) va p95 latency. 1-darsdagi recording rule'lardan foydalaning. Annotation'da qiymat odam o'qiydigan shaklda bo'lsin. Loadgen yoki ilovada xato ulushini vaqtincha oshirib (env o'zgaruvchi orqali) alert'ni firing qiling, keyin qaytaring. Yo'nalish: 2-bo'lim, "Label va annotation farqi"; 5-bo'lim, "Symptom va cause".

4. **Absent data.** `api` metrikasi nomini ilovada vaqtincha o'zgartiring (yoki job'ni scrape config'dan olib tashlang). Error ratio alert'i nima uchun jim turganini ko'rsating. `absent()` bilan buni ushlaydigan qoida yozing. O'zgarishni qaytaring. Yo'nalish: 2-bo'lim, "Ma'lumot yo'q bo'lsa alert ham yo'q".

5. **Label trap.** Alert `labels` ichiga `value: "{{ $value }}"` qo'shing va `for: 2m` bilan kuzating: Alerts sahifasida nima bo'lyapti? Sababini izohlab, tuzating. Yo'nalish: 2-bo'lim, "Label va annotation farqi".

6. **Rule unit test.** Error ratio alert'i uchun `promtool test rules` testi yozing: `input_series` bilan xato ulushi chegaradan oshgan holat, `alert_rule_test` da kutilgan label va annotation'lar. Chegaradan past holatda alert yo'qligini ham tekshiring. Test fayli konteyner ichidan ko'rinadigan papkada tursin (rules papkasi yonida). Yo'nalish: 2-bo'lim, "Tekshirish: promtool".

### B. Alertmanager

7. **Alertmanager and webhook.** `alertmanager` servisini qo'shing (aniq image tag, port `127.0.0.1` ga) va Prometheus'ga servis nomi orqali ulang. Kelgan `POST` body'sini stdout'ga chiqaradigan kichik webhook servis yozing (Node.js yoki Go, 20–30 qator, multi-arch bazaviy image) va default receiver qiling. Alert'ni firing qilib, JSON payload tuzilishini (`status`, `groupLabels`, `alerts[]`) yozing. `send_resolved` bilan resolve xabarini ham oling. Shundan keyin "Birga bajaramiz" ni o'z stack'ingizda takrorlang. Yo'nalish: 1-bo'lim, "Mexanizm: Prometheus alert'ni qayta-qayta yuboradi"; 4-bo'lim, "Receiver'lar".

8. **Grouping timers.** `group_by: [alertname]` bilan uchta target'ni birdan to'xtating (`api`, `node-exporter`, `cadvisor`): nechta xabar keldi, ichida nechta alert? `group_wait`, `group_interval`, `repeat_interval` ni kichik qiymatlarga qo'yib, har biri qaysi xabarni boshqarishini vaqt belgilari bilan ko'rsating. Yo'nalish: 3-bo'lim, "Guruhlash: `group_by`" va "Uchta taymer".

9. **Routing tree.** Daraxt yozing: `severity="critical"` → `oncall` receiver, `team="shop"` → `shop` receiver, qolgani → `default`. `amtool config routes test` bilan to'rt xil label to'plami qayerga borishini tekshiring. Critical va `team=shop` alert ikkala joyga ham borishi uchun nimani o'zgartirish kerak? Bolalar tartibini almashtirib natija qanday o'zgarishini ko'rsating. Yo'nalish: 3-bo'lim, "Routing tree".

10. **Inhibition.** `InstanceDown` firing bo'lganda o'sha `instance` uchun boshqa alert'lar bostirilishi uchun inhibit rule yozing. `api` ni to'xtating: qaysi alert'lar firing, qaysi biri xabar bo'lib keldi? Alertmanager UI'da inhibited alert qanday ko'rinadi? Yo'nalish: 4-bo'lim, "Inhibition".

11. **Silences.** `amtool silence add` bilan `alertname` va `instance` bo'yicha 10 daqiqalik silence yarating (izoh bilan). Alert firing bo'lsa ham xabar kelmasligini ko'rsating. `amtool silence query` va `expire` ishlating. Silence va inhibition farqini o'z so'zingiz bilan yozing. Yo'nalish: 4-bo'lim, "Silence".

12. **Break the config.** `alertmanager.yml` da mavjud bo'lmagan receiver'ga ishora qiling. `amtool check-config` va konteyner log'i nima deydi? Alertmanager ishlab turgan paytda buzuq config'ni reload qilsangiz (`SIGHUP`) nima bo'ladi: eski config qoladimi? Config'ni tuzatib, toza holatga qaytaring. Yo'nalish: 4-bo'lim, "Receiver'lar" (config tekshiruvi va reload).

### C. Receiver'lar

13. **Telegram receiver.** Bot yarating, uni guruh yoki shaxsiy chatga qo'shing (faqat o'z chat'ingiz), `chat_id` ni aniqlang. `telegram_configs` ni `bot_token_file` bilan sozlang, critical alert'lar shu yerga borsin. Xabar matnini shablon bilan o'zgartiring: alert nomi, summary, runbook havolasi. Token repoda yo'qligini `git status` va `make check` bilan tasdiqlang. Ikkinchi mashinada token faylini qo'lda yarating va ikkala stack bir vaqtda ishlamasligiga e'tibor bering. Yo'nalish: 4-bo'lim, "Receiver'lar"; Laboratoriya, "Secret'lar".

14. **Email receiver.** SMTP tutqich (Mailpit) servisini qo'shing (image multi-arch ekanini tekshiring) va `email_configs` orqali warning alert'larni unga yuboring. Kelgan xatni UI'da ko'ring. Real SMTP bilan ishlashda qaysi maydonlar secret bo'lishini va ularni qanday berishni yozing. (Slack'ingiz bo'lsa, ixtiyoriy: `slack_configs` ni incoming webhook bilan sinang, URL secret.) Yo'nalish: 4-bo'lim, "Receiver'lar".

15. **Watchdog.** Doim firing turadigan `Watchdog` alert'ini yozing va alohida route bilan webhook'ga qisqa `repeat_interval` da yuboring. Webhook servisingizga "oxirgi N daqiqada Watchdog kelmadi" holatini log'ga yozadigan tekshiruv qo'shing. Alertmanager'ni to'xtatib sinang. Yo'nalish: 5-bo'lim, "Monitoringni kim kuzatadi"; 3-bo'lim, "Uchta taymer".

### D. SLO va jarayon

16. **Burn rate alert.** `api` uchun SLO belgilang: 30 kunda 99.9% so'rov 5xx siz. 1h, 5m, 6h, 30m oynalari uchun error ratio recording rule'larini va ikki bosqichli (14.4 va 6) multiwindow burn rate alert'ini yozing. Xato ulushini 2% ga ko'tarib qaysi alert qancha vaqtda firing bo'lishini kuzating. Laboratoriyada kutish uzun bo'lsa oynalarni proporsional qisqartiring va buni yozib qo'ying. Yo'nalish: 5-bo'lim, "Burn rate" va "Multi-window, multi-burn-rate".

17. **Budget math.** Hisoblang va izohlang: 99.9% va 99.99% SLO uchun 30 kunlik error budget daqiqalarda; xato ulushi 0.5% bo'lsa 99.9% SLO'da burn rate va budget necha kunda tugashi; 3-vazifadagi oddiy "error > 5%" alert'i bu holatni ushlaydimi? Yo'nalish: 5-bo'lim, "SLI, SLO va error budget" va "Burn rate".

18. **Runbooks.** Uchta alert'ingiz uchun `runbooks/` da Markdown runbook yozing (ma'nosi, ta'siri, birinchi 3 tekshiruv aniq PromQL bilan, ehtimoliy sabablar, eskalatsiya). `runbook_url` annotation'ini repodagi fayl manziliga qo'ying va Telegram xabarida havola chiqishini ko'rsating. Yo'nalish: 5-bo'lim, "Runbook".

19. **Alert review.** Shu darsda yozgan barcha alert'larni jadvalga oling: nomi, symptom yoki cause, severity, page yoki ticket, odam nima qiladi. "Odam hech narsa qila olmaydi" chiqqan har alert uchun qaror yozing: o'chirish, severity tushirish yoki dashboard'ga ko'chirish. Yo'nalish: 5-bo'lim, "Symptom va cause"; 1-bo'lim, "Shovqinli alert nima uchun o'chiriladi".

### E. Grafana Alerting

20. **Grafana-managed rule.** Grafana'da Prometheus so'rovi asosida alert rule yarating (masalan in-flight so'rovlar soni chegaradan yuqori), contact point sifatida o'z webhook'ingizni (servis nomi bilan) va notification policy'ni sozlang. Firing qiling va payload'ni Alertmanager webhook payload'i bilan solishtiring. No data holatida qoida nima qilishini sozlamadan toping va sinang. Yo'nalish: 6-bo'lim, "Mexanizm".

21. **Provision alerting.** 20-vazifadagi rule, contact point va policy'ni UI'dan eksport qilib `grafana/provisioning/alerting/` ga fayl sifatida qo'ying. Grafana volume'ini o'chirib ko'taring (faqat shu bitta volume, nomi bilan; `prune` emas): hammasi tiklansin. Alertmanager'ni Grafana'ga data source sifatida qo'shing va 11-vazifadagi silence'ni Grafana UI'dan ko'ring. Yo'nalish: 6-bo'lim, "Mexanizm".

22. **Mini-project: alerting as code.** Toza `docker compose up -d` dan keyin: Prometheus'da symptom, burn rate, `InstanceDown`, `absent` va Watchdog qoidalari; Alertmanager'da routing (critical → Telegram, warning → email, hammasi → webhook log), inhibition; har alert'da runbook. Ssenariy o'tkazing: `api` da xato ulushini 20% ga ko'taring, keyin `api` ni butunlay to'xtating. `README.md` ga vaqt chizig'ini yozing: qaysi alert qachon pending, firing, qaysi xabar qayerga keldi, qaysi biri inhibit bo'ldi, resolve qachon keldi. Loyiha ikkinchi mashinada ham `git pull`, token fayli va `docker compose up -d` bilan ko'tarilishini tekshiring. Yo'nalish: hamma bo'limlar; vaqt chizig'i shakli uchun "Birga bajaramiz".

### Topshirish

Tayyor bo'lgach:
1. 22 ta vazifaning javobi `observability/03-alerting/README.md` da, `## N. Title` sarlavhalari ostida; runbook'lar `observability/03-alerting/runbooks/` da.
2. Stack fayllari `observability/stack/` da: `prometheus/rules/alerts.yml` (va test fayli), `alertmanager/alertmanager.yml`, webhook servisi, `grafana/provisioning/alerting/`, yangilangan `compose.yaml`.
3. `promtool check rules`, `promtool test rules` va `amtool check-config` toza (konteyner ichidan).
4. `make check` toza; bot token, chat ID va parollar repoda ham, README'da ham yo'q (`git status` da token fayli ko'rinmaydi).
5. Telegram'dagi sinov xabarlari skrinshoti yoki matni `README.md` da (token ko'rinmasin).
6. Sinov uchun o'zgartirilgan narsalar qaytarilgan (chegaralar, xato ulushi, to'xtatilgan konteynerlar), faol silence'lar qolmagan, `docker compose down` qilingan.
7. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Prometheus va Alertmanager o'rtasida mas'uliyat qanday bo'lingan? Nima uchun bitta komponent emas?
- Alert qaysi holatda Alertmanager'ga yuboriladi va nima uchun qayta-qayta yuboriladi?
- `for` nima beradi va nimani yo'qotadi?
- Label va annotation farqi nima, nima uchun qiymat label'ga yozilmaydi?
- Routing tree'da alert qanday yo'l bosadi, `continue` nimani o'zgartiradi?
- `group_wait`, `group_interval`, `repeat_interval` har biri qaysi vaziyatda ishlaydi?
- Inhibition, silence va mute time interval farqi nima?
- "Resolved" xabari nima uchun har doim ham "muammo tuzaldi" degani emas?
- Symptom-based alert nima va nima uchun CPU 90% ga page qilmaysiz?
- Burn rate 14.4 nimani anglatadi va bu son qayerdan chiqadi? Nima uchun ikki oyna birga ishlatiladi?
- Seriya yo'qolganda alert nima uchun jim qoladi va buni qanday yopasiz?
- Monitoring tizimining o'zi o'lganini qanday bilasiz?
- Grafana Alerting'ni qachon tanlaysiz, Prometheus qoidalarini qachon?
- Uydagi Mac'da host alert'i nima uchun ofisdagidan boshqacha ishlaydi?
- Alertmanager nima uchun on-call tizimini almashtira olmaydi? Grafana OnCall OSS'ning joriy holatini qayerdan tekshirasiz va bu amaliy tanlovga qanday ta'sir qiladi?
