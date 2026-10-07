# 2-dars: Grafana bilan vizualizatsiya

Maqsad: 1-darsdagi PromQL so'rovlarini odam bir qarashda tushunadigan dashboard'ga aylantirish va butun Grafana sozlamasini (data source, dashboard, folder) UI'da qo'lda emas, git'dagi fayllardan kod sifatida ko'tarish. Grafana ma'lumot saqlamaydi: u data source'larga so'rov yuboradigan va natijani chizadigan qatlam. Shu sabab keyingi darslarda Loki, Tempo va Pyroscope ham aynan shu Grafana'ga data source bo'lib ulanadi, 3-darsda esa alert qoidalari shu yerda ham yoziladi. Siz frontend dasturchi sifatida UI'ni baholay olasiz, bu darsda shu ko'nikma ishlaydi: dashboard bu axborot dizayni, har panel bitta savolga javob berishi kerak.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–2 bo'limlar, "Birga bajaramiz"ning 1–5 qadamlari va A guruh; ikkinchi kun 3–4 bo'limlar, B va C guruhlar; uchinchi kun 5–7 bo'limlar, "Birga bajaramiz"ning qolgan qadamlari, D va E guruhlar. Tugmalar joylashuvini yodlashga vaqt sarflamang, Grafana UI'si har katta versiyada o'zgaradi. Vaqtni mexanizmlarga bering: panel vaqt oralig'ini qanday qilib `step` ga aylantiradi, `$__rate_interval` nima uchun kerak, ko'p qiymatli variable so'rovni qanday o'zgartiradi, data source `uid` ning roli, provisioning qilingan dashboard'ni UI'da tahrirlasangiz nima bo'ladi.

Qanday o'qish kerak: har bo'limdagi so'rov va sozlamani o'z stack'ingizda takrorlang va Query inspector'da Grafana aslida nima yuborganini ko'ring. Sozlama nomlari (masalan **Min interval**, **Repeat by variable**) Grafana hujjatidagi nomlar bilan berilgan; menyu yo'li sizdagi versiyada boshqacha bo'lsa, "Manbalar"dagi sahifadan toping. Sizdagi raqamlar (so'rovlar soni, `step`, xotira) farq qiladi, bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker Compose'da, 1-darsda boshlangan yagona stack papkasida ishlaydi: `observability/stack/`. Host'ga hech narsa o'rnatilmaydi. Bu darsda stack'ga bitta servis qo'shiladi: `grafana`. U bilan birga git'ga kiradigan papkalar paydo bo'ladi:

```
observability/stack/
  compose.yaml                      # from lesson 1, you add the grafana service
  .env                              # secrets, NOT committed
  grafana/
    provisioning/datasources/       # data source YAML, committed
    provisioning/dashboards/        # dashboard provider YAML, committed
    dashboards/                     # dashboard JSON files, committed
```

Servis haqida aniq ma'lum faktlar (compose ta'rifini 1-vazifada o'zingiz yozasiz):

| Narsa | Qiymat |
|-------|--------|
| Image | `grafana/grafana`, aniq tag bilan (https://github.com/grafana/grafana/releases), `latest` emas. Image multi-arch: Zorin'da `amd64`, Mac'da `arm64` varianti o'zi tanlanadi |
| Port | konteyner ichida `3000`; host'da faqat `127.0.0.1` ga bog'lanadi (docker moduli, 3-dars), brauzerda `http://localhost:3000` |
| Ma'lumot | `/var/lib/grafana` (SQLite baza shu yerda), named volume |
| Provisioning | `/etc/grafana/provisioning` ostidagi `datasources/` va `dashboards/` papkalari |
| Admin | `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD` env o'zgaruvchilari |

Kundalik buyruqlar (`observability/stack/` ichida, ikkala host'da bir xil):

```
docker compose up -d                    # start the whole stack
docker compose logs -f grafana          # provisioning errors show up here
curl -s http://localhost:3000/api/health
docker compose down                     # end of session, volumes are kept
```

`/api/health` login talab qilmaydi va `"database": "ok"` hamda Grafana versiyasi bor kichik JSON qaytaradi: Grafana tirikligini tekshirishning eng arzon yo'li.

- **Secret'lar**: admin paroli va 18-vazifadagi token faqat `.env` da. Compose `.env` ni o'zi o'qiydi va `compose.yaml` dagi `${VAR}` o'rniga qo'yadi (docker moduli, 4-dars). `.env` commit qilinmaydi, `make secrets` tekshiruvi commit qilingan `.env` ni rad etadi.
- **Tozalash**: mashg'ulot oxirida `docker compose down`. `docker system prune` va `docker volume prune -a` ishlatilmaydi, ular boshqa loyihalaringiz volume'larini ham o'chiradi. Faqat Grafana volume'ini o'chirish kerak bo'lgan vazifalarda (12, 13) uni nomi bilan o'chirasiz: `docker compose rm -sf grafana`, keyin `docker volume ls` dan nomini topib `docker volume rm <nom>`.
- **`make check`** ish papkalaridagi YAML'ni `yamllint` bilan tekshiradi, topshirishdan oldin toza bo'lishi kerak.

### Ikki mashina: nima ko'chadi, nima ko'chmaydi

Bu darsning asosiy g'oyasi aynan ikki mashinali ishda ko'rinadi. UI'da bosib qurilgan dashboard Grafana'ning bazasida, ya'ni **shu mashinadagi** Docker volume'da yashaydi. Volume git'ga kirmaydi, demak ofisda qurgan dashboard uyda yo'q. Provisioning fayllari (YAML va JSON) esa git'da, `git pull` va `docker compose up -d` dan keyin ikkala mashinada bir xil paydo bo'ladi.

| Narsa | Qayerda yashaydi | Ikkinchi mashinaga o'tadimi |
|-------|------------------|-----------------------------|
| `compose.yaml`, provisioning YAML, dashboard JSON | git | ha |
| UI'da qurilib, eksport qilinmagan dashboard, qo'lda qo'shilgan data source, user, team | Grafana volume | yo'q |
| `.env` (admin paroli, token) | faqat lokal fayl | yo'q, har mashinada qo'lda yaratiladi |
| Metrikalar tarixi | Prometheus volume | yo'q, grafik stack ko'tarilgan paytdan boshlanadi |

Ikkinchi mashinada tiklash: `git pull`, `observability/stack/.env` ni qo'lda yarating (parol boshqa bo'lishi mumkin), `docker compose up -d`. 1-dars stack'i ham shu buyruq bilan ko'tariladi. Prometheus tarixi bo'sh bo'lgani uchun dashboard'da vaqt oralig'ini `Last 15 minutes` qilib qarang. Kun oxirida UI'da qilgan ishingizni JSON'ga eksport qilib commit qilmagan bo'lsangiz, u o'sha mashinada qoladi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | `node-exporter` va `cadvisor` haqiqiy ish mashinasini tasvirlaydi: CPU yadrolari, xotira, disklar va tarmoq interfeyslari Zorin'niki. Community dashboard panellarining ko'pi to'ladi. |
| macOS (uy) | Docker Desktop yashirin Linux VM ichida ishlaydi, shuning uchun host metrikalari Mac'ni emas, o'sha VM'ni tasvirlaydi: CPU va xotira Docker Desktop resurs sozlamalariga teng, disk va interfeys nomlari VM'niki. Ba'zi cAdvisor metrikalari yoki label'lari bo'lmasligi mumkin, natijada USE va community dashboard'da ayrim panellar bo'sh chiqadi. Buni "tuzatmang": 4-bo'limdagi usul bilan sababini aniqlab README'ga yozing. Konteyner IP'lari host'dan ko'rinmaydi, lekin bu darsda kerak emas: brauzer faqat `localhost:3000` ga boradi. |

---

## 1. Grafana nima va nima emas

### Uch qism: brauzer, Grafana server, data source

Grafana ikki narsadan iborat: Go'da yozilgan backend server va brauzerda ishlaydigan React ilova (frontend). Uchinchi tomon **data source**: Grafana so'rov yuboradigan tashqi tizim (bu darsda Prometheus) va unga ulanish sozlamasi. Grafana'ning o'zi metrika saqlamaydi. Uning kichik bazasi bor (standart holatda SQLite, konteynerda `/var/lib/grafana/grafana.db` fayli) va unda faqat sozlamalar turadi: dashboard'lar (JSON hujjat sifatida), data source ulanishlari, user'lar, team'lar, folder'lar, alert qoidalari.

Bundan amaliy xulosa: Grafana volume'i yo'qolsa metrikalar yo'qolmaydi (ular Prometheus volume'ida), lekin qo'lda qurilgan dashboard'lar yo'qoladi. Prometheus volume'i yo'qolsa dashboard'lar joyida, lekin bo'sh.

### Mexanizm: data source proxy

Panel ochilganda nima sodir bo'ladi:

1. Brauzerdagi frontend Grafana backend'iga `POST /api/ds/query` yuboradi: qaysi data source (`uid`), qaysi so'rov, qaysi vaqt oralig'i.
2. Grafana backend'i data source sozlamasidagi `url` ga o'zi HTTP so'rov yuboradi (Prometheus uchun `/api/v1/query_range` yoki `/api/v1/query`, 1-dars) va kerak bo'lsa saqlangan parol yoki token'ni qo'shadi.
3. Javobni jadval ko'rinishidagi ichki formatga (data frame) o'tkazib brauzerga qaytaradi, frontend uni chizadi.

Bu rejim **proxy** (yoki server access) deyiladi, provisioning'da `access: proxy` deb yoziladi. Eski versiyalarda brauzer data source'ga to'g'ridan-to'g'ri boradigan Browser rejimi ham bor edi, Prometheus data source'da u olib tashlangan. Proxy rejimining ikki oqibati bor. Birinchisi: data source paroli hech qachon brauzerga chiqmaydi. Ikkinchisi: Prometheus'ga **brauzer emas, Grafana konteyneri** yetib borishi kerak.

### `localhost` tuzog'i

Data source URL'i Grafana konteyneri ichidan ochiladi. Har konteynerning o'z network namespace'i bor (docker moduli, 3-dars), shuning uchun konteyner ichidagi `localhost` bu konteynerning o'zi, sizning mashinangiz emas. Grafana konteynerida 9090-portda hech narsa tinglamaydi. To'g'ri manzil Compose tarmog'idagi servis nomi: Compose har loyiha uchun tarmoq yaratadi va undagi DNS servis nomini konteyner IP'siga aylantiradi (docker moduli, 4-dars).

```
browser  --> http://localhost:3000   (published port, host loopback)
grafana  --> http://prometheus:9090  (service name, Compose network DNS)
grafana  -X- http://localhost:9090   (the grafana container itself)
```

Chalkashlik manbai: brauzerda `http://localhost:9090` ochiladi (Prometheus porti host'ga chiqarilgan), shuning uchun o'sha manzil data source'da ham ishlashi kerakdek tuyuladi. Savol har doim bitta: bu URL'ni **kim** ochyapti? Xato matnini 1-vazifada o'zingiz ko'rasiz.

### Sozlash qatlamlari

Grafana uch joydan sozlanadi:

| Qatlam | Nima | Misol |
|--------|------|-------|
| `grafana.ini` | asosiy config fayl, bo'limlarga (`[security]`, `[auth.anonymous]`) bo'lingan | `admin_password = ...` |
| Env o'zgaruvchilar | `GF_<SECTION>_<KEY>` shaklida, fayldagi qiymatni bosib o'tadi; bo'lim nomidagi nuqta `_` ga aylanadi | `GF_SECURITY_ADMIN_PASSWORD`, `GF_AUTH_ANONYMOUS_ENABLED` |
| Provisioning | data source, dashboard va boshqalarni tasvirlaydigan YAML fayllar (5-bo'lim) | `provisioning/datasources/*.yaml` |

Konteynerda env yo'li qulay: image'ni o'zgartirmasdan `compose.yaml` dan sozlanadi. Compose fragmenti (to'liq servis emas):

```yaml
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}   # value comes from .env
```

`${GRAFANA_ADMIN_PASSWORD}` ni Compose `.env` dan oladi, konteyner ichida esa `GF_SECURITY_ADMIN_PASSWORD` paydo bo'ladi, Grafana uni `[security] admin_password` deb o'qiydi.

**Tuzoq: admin paroli faqat birinchi ishga tushishda qo'llanadi.** Grafana admin user'ni baza bo'sh bo'lganda yaratadi va parolni shu payt yozadi. Keyin `.env` dagi qiymatni o'zgartirsangiz, bazadagi parol o'zgarmaydi. Parolni almashtirish UI'dan yoki `grafana cli admin reset-admin-password` bilan qilinadi ("Manbalar"). Parol berilmasa standart `admin` / `admin` bo'ladi va birinchi kirishda almashtirish so'raladi.

### Data source `uid`

Har data source'ning uch identifikatori bor: `name` (odam uchun, o'zgarishi mumkin), `id` (bazadagi raqam, har instansda boshqa) va `uid` (qisqa satr). Dashboard JSON'i data source'ga `uid` orqali ishora qiladi:

```json
"datasource": { "type": "prometheus", "uid": "prom-main" }
```

UI'da yaratilgan data source'ga tasodifiy `uid` beriladi. Ofisdagi Grafana'da u bir xil, uydagisida boshqa bo'ladi, natijada ofisda eksport qilingan dashboard uyda data source'ni topa olmaydi va panellar xato ko'rsatadi. Yechim: data source'ni provisioning'da e'lon qilib, `uid` ni o'zingiz belgilash (5-bo'lim). Shunda u hamma joyda bir xil.

### Real ishda qachon kerak

- "Dashboard bo'sh" shikoyatida birinchi ajratish: Grafana ishlamayaptimi (`/api/health`), data source'ga yeta olmayaptimi (data source sahifasidagi **Save & test**), yoki so'rov bo'sh natija qaytaryaptimi (Query inspector).
- Grafana'ni yangi serverga ko'chirishda nimani zaxiralash kerakligini bilish: baza (yoki provisioning fayllari), metrikalar emas.
- Kubernetes'da data source URL'i ham servis nomi bo'ladi (`http://prometheus.monitoring.svc:9090`), mantiq aynan shu.

### Nima uchun shunday

Grafana 2014-yilda Kibana'ning fork'i sifatida, Graphite metrikalari uchun boshlangan va boshidanoq "saqlash boshqa tizimning ishi" degan qarorga tayangan. Shu ajratish tufayli bitta dashboard'da Prometheus, Loki va SQL baza panellari yonma-yon turadi, saqlash tizimini almashtirganda esa (masalan Prometheus'dan Mimir'ga) dashboard'lar qoladi. Muqobil yo'l: o'z UI'siga ega monolit tizimlar (Prometheus'ning o'z veb interfeysi, Kibana va Elasticsearch juftligi). Prometheus UI'si so'rovni sinash uchun yetarli, lekin unda saqlanadigan dashboard, variable va ruxsatlar yo'q. Proxy rejimi tanlanganining sababi xavfsizlik va tarmoq: brauzerga parol berilmaydi, Prometheus'ni tashqi tarmoqqa ochish shart emas.

## 2. Panel va so'rov

### Panel nimadan iborat

**Dashboard** panellar to'plami, **panel** esa uch narsa: bir yoki bir nechta so'rov (`A`, `B`, ...), vizualizatsiya turi va sozlamalar. Vizualizatsiya turini savol tanlaydi:

| Vizualizatsiya | Qaysi savolga javob | So'rov turi |
|----------------|---------------------|-------------|
| Time series | vaqt bo'yicha qanday o'zgardi: rate, latency, utilization | Range |
| Stat | hozir qancha: bitta katta raqam | Instant |
| Gauge, Bar gauge | chegarasi ma'lum qiymat qayerda turibdi: disk to'lishi | Instant |
| Table | ko'p seriyaning joriy qiymati: endpoint bo'yicha top | Instant |
| Heatmap | taqsimot vaqt bo'yicha: histogram bucket'lari | Range |
| State timeline | holatlar ketma-ketligi: `up`, alert holati | Range |
| Logs, Traces, Flame graph | 4–6-darslar | |

### Mexanizm: range va instant so'rov

Prometheus HTTP API'sida ikki xil so'rov bor (1-dars). **Instant** so'rov (`/api/v1/query`) ifodani bitta vaqt nuqtasida hisoblaydi va har seriya uchun bitta qiymat qaytaradi. **Range** so'rov (`/api/v1/query_range`) `start`, `end` va `step` oladi: ifoda `start` dan `end` gacha har `step` soniyada bir marta hisoblanadi va har seriya uchun nuqtalar qatori qaytadi. Grafana'ning Prometheus so'rov muharririda bu **Type** sozlamasi: `Range`, `Instant` yoki `Both`.

Time series panelga range kerak. Stat va Table'ga instant yetadi: range bilan ham ishlaydi (panel qatordan oxirgi qiymatni oladi), lekin Prometheus yuzlab nuqtani hisoblab, bittasi ishlatiladi. Jadvalda esa range so'rov har seriyani ko'p qatorga yoyib yuboradi, shuning uchun Table uchun `Instant` va **Format**: `Table` tanlanadi.

### Mexanizm: vaqt oralig'idan `step` gacha

Ekranda panel kengligi cheklangan: 1000 pikselli grafikda 1000 dan ortiq nuqta chizishning ma'nosi yo'q. Grafana shundan `step` ni hisoblaydi:

1. **Max data points**: standart holatda panelning pikseldagi kengligi.
2. Interval = (vaqt oralig'i) / (Max data points), "chiroyli" qiymatga yaxlitlanadi.
3. Interval **Min interval** dan kichik bo'lolmaydi. Prometheus data source'da pastki chegara standart holatda data source sozlamasidagi **Scrape interval** (belgilanmasa `15s`).
4. Natija `$__interval` variable'ida turadi va range so'rovning `step` i bo'ladi.

Max data points, Min interval va hisoblangan Interval panel muharririning **Query options** qismida ko'rinadi. Taxminan 1000 piksel kenglikdagi panel va 15 soniyalik scrape interval uchun:

| Vaqt oralig'i | Oraliq / 1000 | `$__interval` (taxminan) |
|---------------|---------------|--------------------------|
| 5 daqiqa | 0.3 s | `15s` (pastki chegara) |
| 6 soat | 21.6 s | `20s` yoki `30s` |
| 24 soat | 86.4 s | `1m` yoki `2m` |
| 7 kun | 605 s | `10m` |

Aniq qiymatni taxmin qilmang: panel menyusidagi **Inspect → Query** (Query inspector) Grafana yuborgan haqiqiy so'rovni ko'rsatadi, ichida `expr`, `start`, `end`, `step` (yoki `intervalMs`) va variable'lar o'rniga qo'yilgan qiymatlar bor. Bu frontend ishidagi DevTools Network tab'ining o'zi: avval "aslida nima yuborildi" ni ko'ring, keyin taxmin qiling.

### `$__rate_interval`

`rate(x[oyna])` har hisoblash nuqtasida orqaga `oyna` uzunligida qaraydi va ichidagi sample'lardan (1-dars: sample bu bitta scrape'da olingan qiymat) soniyalik o'sishni chiqaradi. Buning uchun oynada **kamida ikkita sample** bo'lishi shart. Oyna tanlashda uch yo'l bor:

| Yozuv | Qisqa oraliqda (5 daqiqa) | Uzoq oraliqda (24 soat) |
|-------|---------------------------|-------------------------|
| `rate(x[1m])` | ishlaydi | `step` taxminan 2 daqiqa, oyna 1 daqiqa: har nuqta faqat oxirgi daqiqani ko'radi, qolgan yarmi hech qaysi nuqtaga kirmaydi. Shu "ko'r" joyga tushgan cho'qqi grafikda yo'q |
| `rate(x[$__interval])` | oyna `15s`, scrape ham `15s`: oynaga odatda bitta sample tushadi, `rate` hech narsa qaytarmaydi, panel bo'sh | ishlaydi, lekin qo'shni oynalar chegarasidagi o'sish yo'qoladi |
| `rate(x[$__rate_interval])` | oyna `1m`, ishlaydi | oyna `step` dan katta, hamma sample qamraladi |

`$__rate_interval` Grafana'ning Prometheus data source'i hisoblaydigan variable:

```
$__rate_interval = max($__interval + scrape interval, 4 * scrape interval)
```

Birinchi had oynaning `step` dan bir scrape interval'ga uzunroq bo'lishini ta'minlaydi (qo'shni nuqtalar orasida tashlab ketilgan sample qolmaydi), ikkinchi had oynada har doim bir nechta sample bo'lishini (bitta scrape muvaffaqiyatsiz bo'lsa ham). 15 soniyalik scrape uchun: 5 daqiqalik oraliqda `max(15s + 15s, 60s) = 1m`, `$__interval` 2 daqiqa bo'lgan oraliqda `max(120s + 15s, 60s) = 2m15s`.

Formuladagi "scrape interval" Prometheus'ning haqiqiy config'idan emas, **data source sozlamasidan** olinadi (UI'da Scrape interval, provisioning'da `jsonData.timeInterval`). Grafana Prometheus'ning `prometheus.yml` faylini o'qimaydi, ikki qiymatni mos tutish sizning ishingiz. Noto'g'ri qiymat nima qilishini 3-vazifada ko'rasiz.

Ishlaydigan misol (Prometheus o'zining HTTP so'rovlarini sanaydi, bu metrika har Prometheus'da bor):

```
sum by (handler) (rate(prometheus_http_requests_total[$__rate_interval]))
```

Panelda har `handler` (Prometheus API yo'li, masalan `/api/v1/query_range`) uchun bitta chiziq chiqadi, qiymati soniyasiga so'rovlar. Dashboard'ni yangilaganingizda `/api/v1/query_range` chizig'i ko'tariladi: siz o'z so'rovlaringizni ko'ryapsiz.

### Unit, legend, threshold

Birliksiz grafik yarim ma'lumot: `0.25` soniyami, foizmi, so'rovmi? Asosiy sozlamalar (hujjatdagi nomlari bilan):

| Sozlama | Qayerda | Nima qiladi |
|---------|---------|-------------|
| **Unit** | Standard options | qiymatni formatlaydi va o'lchovni tanlaydi. JSON'dagi ID'lar: `s` (soniya, `0.25` ni `250 ms` deb ko'rsatadi), `bytes`, `percentunit` (0–1 ni 0–100% deb), `percent` (0–100), `reqps` |
| **Min**, **Max** | Standard options | o'q chegarasi. Ulush uchun 0 va 1 |
| **Decimals** | Standard options | kasr xonalari soni |
| **Thresholds** | Thresholds | qiymat chegaralari va ranglari. Stat va Gauge'da rangni, Time series'da (yoqilsa) chiziq yoki sohani beradi |
| **Legend** | so'rov muharriri, Options | seriya nomi shabloni: `{{handler}}`. Standart holatda butun label to'plami chiqadi va o'qib bo'lmaydi |
| **Calculation** | Stat, Gauge: Value options | range natijadan bitta raqam olish usuli (`Last *`, `Mean`, `Max`) |
| **Description** | Panel options | panel burchagidagi izoh: nima o'lchanadi, qachon xavotirlanish kerak |

`percentunit` va `percent` ni adashtirish eng ko'p uchraydigan xato: PromQL ulushni 0–1 da beradi, `percent` bilan `0.05` "0.05%" bo'lib ko'rinadi, aslida 5%.

### Explore

**Explore** dashboard'siz so'rov yozish joyi: data source tanlanadi, so'rov yoziladi, natija grafik va jadval bo'lib chiqadi, hech narsa saqlanmaydi. Dashboard oldindan ma'lum savollar uchun, Explore yangi savollar uchun: incident paytida asosiy ish maydoni shu. Yangi versiyalardagi Drilldown ilovalari (Metrics, Logs, Traces, Profiles) so'rov yozmasdan ko'rib chiqish imkonini beradi.

### Real ishda qachon kerak

- "Grafikda cho'qqi bor edi, 7 kunlik ko'rinishda yo'q": `step` kattalashgan, o'rtacha cho'qqini yeb yuborgan. `max_over_time` bilan alohida panel yoki qisqa oraliq kerak.
- "Panel 5 daqiqalik oraliqda bo'sh, 1 soatlikda ishlaydi": deyarli har doim `rate` oynasi scrape interval'ga nisbatan kichik.
- Dashboard sekin ochilsa: Query inspector'dagi so'rov vaqti va qaytgan nuqtalar soni qaysi panel og'irligini aytadi.

### Nima uchun shunday

`step` ni panel kengligidan hisoblash Prometheus'ni himoya qiladi: 30 kunlik oraliqni 15 soniyalik qadam bilan so'rash har seriya uchun 170 mingdan ortiq nuqta degani, Prometheus esa bitta seriya uchun 11000 nuqtadan ortig'ini rad etadi. `$__rate_interval` 2020-yilda (Grafana 7.2) qo'shilgan: ungacha hamma `rate(x[5m])` kabi qat'iy oyna yoki `$__interval` yozgan va yuqoridagi ikki xatodan biriga tushgan. Muqobil yo'l qat'iy oyna (`[5m]`): alert qoidalarida aynan shunday yoziladi (3-dars), chunki u yerda panel ham, o'zgaruvchan `step` ham yo'q. Dashboard'da esa oraliq o'zgaradi, shuning uchun oyna ham o'zgarishi kerak.

## 3. Variables va templating

### Variable nima

**Variable** dashboard tepasidagi ochiladigan ro'yxat. So'rovlarda `$name` yoki `${name}` deb yoziladi va Grafana so'rovni yuborishdan oldin uning o'rniga tanlangan qiymatni matn sifatida qo'yadi. Shu tufayli bitta dashboard hamma servis, instans yoki muhit uchun ishlaydi: 20 ta servis uchun 20 ta nusxa emas, bitta dashboard va `service` variable'i. Variable'lar ishlatilgan dashboard **template** deyiladi, shundan "templating" atamasi.

| Turi | Qiymat manbai |
|------|---------------|
| Query | data source'dan so'rov bilan olinadi |
| Custom | qo'lda yozilgan ro'yxat: `prod,staging,dev` |
| Interval | vaqt oraliqlari ro'yxati: `1m,5m,1h` |
| Data source | berilgan turdagi data source'lar ro'yxati |
| Ad hoc filters | ixtiyoriy label filtri, hamma so'rovga avtomatik qo'shiladi |

### Mexanizm: query variable

Prometheus data source'da query variable uchun maxsus funksiyalar bor (bular PromQL emas, Grafana'niki):

| Funksiya | Nima qaytaradi |
|----------|----------------|
| `label_values(label)` | shu label'ning Prometheus'dagi hamma qiymatlari |
| `label_values(metric, label)` | faqat shu metrika seriyalaridagi qiymatlar |
| `metrics(regex)` | nomi regex'ga mos metrikalar |
| `query_result(query)` | ixtiyoriy PromQL natijasi |

Misol: `handler` nomli variable, so'rovi `label_values(prometheus_http_requests_total, handler)`. Dashboard ochilganda Grafana Prometheus'dan shu metrikadagi `handler` qiymatlarini so'raydi va ro'yxatni to'ldiradi. Panel so'rovida:

```
sum by (handler) (rate(prometheus_http_requests_total{handler=~"$handler"}[$__rate_interval]))
```

**Zanjir (chained variables)**: variable so'rovi ichida boshqa variable ishlatilsa, ikkinchisi birinchisiga bog'lanadi. Kubernetes'dagi misol: `cluster` variable'i bor, `namespace` variable'ining so'rovi `label_values(kube_pod_info{cluster="$cluster"}, namespace)`. `cluster` o'zgarganda Grafana `namespace` so'rovini qayta ishlatadi va ro'yxat yangilanadi. Bog'liqlik alohida sozlama emas, so'rov matnidagi `$cluster` ning o'zi.

### Mexanizm: multi-value va `=~`

Variable sozlamasida **Multi-value** (bir nechta qiymat tanlash) va **Include All option** (ro'yxatga `All` qo'shish) bor. Bir nechta qiymat tanlanganda bitta matn o'rniga nima qo'yiladi? Prometheus data source'da Grafana qiymatlarni regex alternativasiga aylantiradi (`a` va `b` tanlansa `(a|b)` ko'rinishida) va qiymat ichidagi maxsus regex belgilarini ekranlaydi. Aniq shaklini Query inspector ko'rsatadi.

PromQL'da `=` aniq tenglik, `=~` regex mosligi (1-dars). Shuning uchun ko'p qiymatli variable bilan faqat `=~` ishlaydi: `handler="(a|b)"` so'zma-so'z `(a|b)` degan label qiymatini qidiradi, bunday seriya yo'q, Prometheus xato emas, bo'sh natija qaytaradi va panel jimgina "No data" ko'rsatadi. `All` tanlanganda standart holatda hamma qiymat bitta uzun alternativaga yig'iladi; ro'yxat katta bo'lsa **Custom all value** ga `.*` yozib qisqartiriladi (diqqat: `.*` shu label umuman yo'q seriyalarga ham mos keladi, `.+` esa yo'q).

Variable'ni boshqa formatda qo'yish kerak bo'lsa `${name:format}` yoziladi: `${name:pipe}` (`a|b`), `${name:csv}` (`a,b`), `${name:raw}` (ekranlashsiz).

### Interval variable va repeat

Interval variable foydalanuvchiga agregatsiya oynasini tanlatadi: `window` variable'i `1m,5m,1h` bo'lsa, `avg_over_time(up[$window])` yoziladi. Bu `$__rate_interval` o'rnini bosmaydi: u "silliqroq yoki batafsilroq ko'rsat" degan ongli tanlov uchun.

**Repeat**: panel sozlamasidagi **Repeat by variable** panelni variable'ning har tanlangan qiymati uchun ko'paytiradi (**Repeat direction**, **Max per row** joylashuvni boshqaradi), har nusxa ichida variable bitta qiymatga teng. Row (panellar qatori) ham shunday takrorlanadi. Har nusxa alohida so'rov yuboradi, buni 8-vazifada o'ylab ko'rasiz.

### Real ishda qachon kerak

- Bir xil tuzilgan servislar ko'p bo'lsa: bitta template dashboard, servis variable'i.
- Muhitlar (`prod`, `staging`) bitta Grafana'da bo'lsa: Data source variable yoki `env` label'i bo'yicha Query variable.
- Variable qiymati URL'da (`?var-handler=...`) turadi, shuning uchun aynan shu ko'rinishga havola yuborish mumkin: incident chatida "mana shu grafikka qarang" degani.

### Nima uchun shunday

Variable oddiy matn almashtirish, PromQL'ning o'zida parametr tushunchasi yo'q. Bu soddalikning narxi bor: Grafana so'rov sintaksisini tushunmaydi, `=` va `=~` ni siz to'g'ri yozishingiz kerak. Frontend'dagi o'xshashi haqiqiy: bu SQL'ni string interpolation bilan yig'ishning o'zi, faqat bu yerda xavf injection emas, jimgina bo'sh natija. Muqobili: har servis uchun dashboard nusxasi (bitta o'zgarishni 20 joyda takrorlash) yoki dashboard'larni kod bilan generatsiya qilish (5-bo'lim oxiri).

## 4. Dashboard dizayni

### Dashboard savolga javob beradi

"Hamma metrikani bir sahifaga" dashboard emas, shovqin. Har panel uchun uch savol: bu panel **qaysi savolga** javob beradi, **kim** qaraydi, va u odam **tunda soat 3 da**, alert'dan uyg'onib, 10 soniyada nimani tushunishi kerak? Javob topilmasa panel kerak emas. UI dizaynidagi ko'nikmangiz shu yerda to'g'ridan-to'g'ri ishlaydi: ierarxiya, izchillik, ortiqcha narsani olib tashlash.

- **Yuqoridan pastga: symptom, keyin cause.** Tepada foydalanuvchi his qiladigan narsa (xato ulushi, latency), pastda sabab bo'lishi mumkin bo'lgan resurslar.
- **Servis dashboard'i (RED, 1-dars)**: tepada bir qatorda Stat panellar, ostida Rate, Errors, Duration grafiklari.
- **Resurs dashboard'i (USE, 1-dars)**: har resurs (CPU, xotira, disk, tarmoq) uchun qator, har qatorda Utilization, Saturation, Errors.
- **Izchillik**: bir xil narsa hamma joyda bir xil birlik va rangda; xato qizil; Y o'qi 0 dan boshlanadi (aks holda kichik tebranish falokat bo'lib ko'rinadi); hamma panel bitta vaqt oralig'i va time zone'da.
- **Ierarxiya**: umumiy ko'rinish → servis → instans. Dashboard link va data link bilan biridan ikkinchisiga o'tiladi, variable qiymati URL orqali uzatiladi.
- **Description** har panelda: uch oydan keyin o'zingiz ham eslamaysiz.

### Heatmap: taqsimotni ko'rish

Percentile chizig'i (p95) taqsimotni bitta songa siqadi. Histogram bucket'larini (1-dars) Heatmap panelida chizsangiz, har vaqt ustunida so'rovlar qaysi latency oralig'iga qancha tushgani rang bilan ko'rinadi. Prometheus'ning o'z histogram'ida:

```
sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[$__rate_interval]))
```

So'rov muharririda **Format**: `Heatmap`, Legend `{{le}}`. Ikki guruhli (tez va sekin) taqsimot heatmap'da ikki alohida yo'l bo'lib ko'rinadi, chiziqli grafikda esa bitta "o'rtacha" chiziqqa aylanadi.

### Community dashboard'lar va bo'sh panel diagnostikasi

https://grafana.com/grafana/dashboards/ katalogida tayyor dashboard'lar bor, ID yoki JSON orqali import qilinadi, import paytida data source so'raladi. Eng mashhuri node_exporter uchun "Node Exporter Full" (ID `1860`). Bunday dashboard muallifning muhitiga yozilgan: Linux host metrikalari, ma'lum exporter versiyasi, ma'lum label nomlari (`job`, `instance`, `device`). Sizda ulardan biri boshqacha bo'lsa panel bo'sh chiqadi. Diagnostika tartibi har doim bir xil:

1. Panelni tahrirlash rejimida oching, so'rov matnini ko'ring (yoki Query inspector).
2. So'rovdagi metrika nomini Explore'da yolg'iz yozing (masalan `node_pressure_cpu_waiting_seconds_total`). Natija yo'q bo'lsa: metrika yo'q (collector o'chirilgan, kernel bermaydi, exporter versiyasi boshqa).
3. Metrika bor bo'lsa, label'larini so'rovdagi matcher'lar bilan solishtiring (`{job="node"}` kutilgan, sizda `job="node-exporter"`).
4. Variable'larni tekshiring: dashboard tepasidagi ro'yxat bo'sh bo'lsa, unga bog'liq hamma panel bo'sh.

macOS'da qo'shimcha sabab: metrikalar Docker Desktop VM'idan keladi, ba'zi qurilma va cgroup ma'lumotlari u yerda boshqacha yoki yo'q. Bu sizning xatongiz emas, README'ga "macOS'da shu panel bo'sh, sababi: ..." deb yozing.

### Real ishda qachon kerak

- On-call uchun: alert kelganda ochiladigan bitta dashboard, tepadan pastga o'qiladi.
- Yangi servis qo'shilganda: tayyor RED template'ga variable qiymati qo'shiladi, yangi dashboard chizilmaydi.
- Community dashboard: exporter nimalarni bera olishini ko'rish uchun yaxshi boshlang'ich nuqta, lekin 30 panelni tushunmasdan production'ga qo'yish alert fatigue'ning vizual varianti.

### Nima uchun shunday

RED va USE "nimani chizish kerak" degan savolni yopadi, aks holda har jamoa o'z ta'bicha chizadi va bir servisdan ikkinchisiga o'tgan odam dashboard'ni qayta o'rganadi. "Wall of graphs" ning narxi faqat e'tibor emas: 40 panel har yangilanishda Prometheus'ga 40 dan ortiq so'rov yuboradi. Muqobil yondashuv: dashboard'siz ishlash, faqat alert va Explore. Amalda ikkalasi kerak: dashboard ma'lum savollar uchun tayyor javob, Explore yangi savollar uchun.

## 5. Dashboard JSON modeli va provisioning

### Dashboard bu JSON hujjat

UI'da qurilgan har dashboard bazada bitta JSON hujjat bo'lib saqlanadi. Uni dashboard'ning eksport funksiyasi yoki sozlamalaridagi **JSON Model** orqali ko'rasiz. Qisqartirilgan misol:

```json
{
  "id": null,
  "uid": "prom-health",
  "title": "Prometheus health",
  "version": 3,
  "time": { "from": "now-15m", "to": "now" },
  "templating": { "list": [ { "name": "handler", "type": "query" } ] },
  "panels": [
    {
      "type": "timeseries",
      "title": "Scrape duration",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
      "datasource": { "type": "prometheus", "uid": "prom-main" },
      "targets": [ { "refId": "A", "expr": "scrape_duration_seconds", "legendFormat": "{{job}}" } ],
      "fieldConfig": { "defaults": { "unit": "s" } }
    }
  ]
}
```

Qatorma-qator: `id` bazadagi raqam, har Grafana instansida boshqa, faylda `null` bo'lishi kerak. `uid` dashboard'ning barqaror identifikatori, URL'da turadi (`/d/prom-health/...`), linklar va provisioning shunga tayanadi. `version` har saqlashda bittaga oshadi. `time` standart vaqt oralig'i. `templating.list` variable'lar. `panels` massivida har panel: `type` vizualizatsiya, `gridPos` joylashuv (kenglik 24 ustunli grid'da, `w: 12` yarim ekran), `datasource.uid` 1-bo'limdagi `uid`, `targets` so'rovlar (`expr` PromQL, `legendFormat` legend shabloni), `fieldConfig.defaults.unit` 2-bo'limdagi Unit. UI'dagi har sozlama shu JSON'dagi bitta maydon, React komponentining props'iga o'xshaydi.

### Mexanizm: provisioning

Grafana ishga tushganda `/etc/grafana/provisioning/` ostidagi papkalarni o'qiydi va ichidagi YAML'ga ko'ra bazani kerakli holatga keltiradi. Ikki tur kerak bo'ladi.

**Data source** (`provisioning/datasources/*.yaml`). Boshqa holat uchun to'liq misol, parol bilan himoyalangan staging Prometheus'i:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus staging
    type: prometheus
    uid: prom-staging
    access: proxy
    url: http://prom-staging.internal:9090
    basicAuth: true
    basicAuthUser: grafana
    jsonData:
      timeInterval: 30s
    secureJsonData:
      basicAuthPassword: ${PROM_STAGING_PASSWORD}
```

`apiVersion: 1` fayl formati versiyasi. `name` UI'dagi nom, `type` plugin turi, `uid` siz belgilagan barqaror identifikator, `access: proxy` 1-bo'limdagi rejim, `url` Grafana serveri ochadigan manzil. `jsonData.timeInterval` data source'dagi Scrape interval (`$__rate_interval` shundan hisoblanadi). `secureJsonData` bazada shifrlab saqlanadigan maydonlar; `${PROM_STAGING_PASSWORD}` Grafana **konteynerining** env'idan olinadi (provisioning fayllarida `$VAR` va `${VAR}` interpolatsiyasi bor, haqiqiy `$` belgisi `$$` deb yoziladi), demak qiymat `.env` → `compose.yaml` dagi `environment` → konteyner yo'li bilan keladi, YAML'da ochiq parol yo'q. Yana ikki kalit: `isDefault: true` (yangi panellar uchun standart data source) va `editable` (standart `false`: provisioning qilingan data source UI'da o'zgartirilmaydi).

**Dashboard provider** (`provisioning/dashboards/*.yaml`) dashboard'ning o'zini emas, JSON fayllar **qayerda yotishini** aytadi:

```yaml
apiVersion: 1
providers:
  - name: sandbox
    type: file
    folder: Sandbox
    allowUiUpdates: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/sandbox
```

`type: file` fayldan yuklash, `folder` dashboard'lar tushadigan Grafana folder'i (yo'q bo'lsa yaratiladi), `options.path` konteyner ichidagi papka (compose'da host'dagi `grafana/dashboards/` shu yerga mount qilinadi), `updateIntervalSeconds` papka necha soniyada qayta tekshirilishi: JSON fayl o'zgarsa Grafana restart'siz yangi versiyani yuklaydi. `options.foldersFromFilesStructure: true` bo'lsa papka tuzilishi Grafana folder'lariga aylanadi (bunda `folder` yozilmaydi).

### UI'dagi tahrir va fayl

Provisioning qilingan dashboard'ning haqiqat manbai fayl. `allowUiUpdates: false` da UI saqlashga ruxsat bermaydi va JSON nusxasini olishni taklif qiladi; `true` da bazaga saqlaydi, lekin faylga tegmaydi. Ikkala holatda ham fayl oxir-oqibat g'olib, tafsilotini 15-vazifada o'zingiz kuzatasiz. Ish tartibi: UI'da tahrirlash → JSON'ni eksport qilish → fayl ustiga yozish → `git diff` ni o'qish → commit.

Eksportda ikki variant bor. Oddiy eksport `datasource.uid` ni boricha qoldiradi, provisioning uchun shu kerak. Tashqi ulashish uchun mo'ljallangan variant data source o'rniga `${DS_PROMETHEUS}` kabi placeholder va `__inputs` bo'limini yozadi: uni UI'dagi import tushunadi, fayl provisioning'i esa tushunmaydi va panellar data source topilmadi deydi.

### Real ishda qachon kerak

- Ikki mashinangizning o'zi: ofisda qurilgan dashboard uyda `git pull` dan keyin paydo bo'ladi.
- Dashboard o'zgarishi code review'dan o'tadi, `git log` kim nimani qachon o'zgartirganini aytadi, xato o'zgarish `git revert` bilan qaytariladi.
- Yangi muhit (staging, yangi klaster) bir buyruq bilan bir xil dashboard'larni oladi.

### Nima uchun shunday

Bazadagi holat qo'lda bosilgan klik'lar tarixi: uni takrorlab, taqqoslab yoki review qilib bo'lmaydi. Provisioning Grafana'ni "infrastructure as code" ga olib keladi (terraform modulida batafsil). `uid` ning qo'lda belgilanishi shu g'oyaning shartidir: fayllar bir-biriga barqaror nom bilan ishora qilishi kerak, `package.json` paket nomiga tayanganidek. Muqobillar: Terraform'ning `grafana` provider'i yoki generatorlar (Grafonnet, Grafana Foundation SDK), ular JSON'ni kod bilan yaratadi va katta jamoalarda takrorlanishni kamaytiradi. Bu modulda fayl provisioning yetarli.

## 6. Organization, user, team, folder

### Kim nimani ko'radi

| Tushuncha | Nima |
|-----------|------|
| **Organization** | to'liq ajratilgan muhit: o'z data source, dashboard va user'lari. Ko'pchilikka bitta (standart `Main Org.`) yetadi |
| **User** | login qiladigan odam. Har organization'da bitta **org roli** bor |
| **Org rollari** | `Viewer` (ko'radi), `Editor` (dashboard yaratadi va tahrirlaydi), `Admin` (data source, user, team, folder ruxsatlari) |
| **Grafana server admin** | org rolidan alohida bayroq: butun instansni boshqaradi (user yaratish, organization'lar). Birinchi `admin` user shunday |
| **Team** | user'lar guruhi. Ruxsat odamga emas, team'ga beriladi |
| **Folder** | dashboard va alert qoidalari konteyneri va ruxsat birligi |
| **Service account** | odam emas, dastur uchun hisob: org roli va token'lari bor |

### Mexanizm: ruxsat qanday hisoblanadi

Ruxsat ikki qatlamdan yig'iladi. Org roli butun organization bo'yicha asosiy darajani beradi. Folder ruxsatlari (`View`, `Edit`, `Admin`) aniq folder uchun user, team yoki rol bo'yicha beriladi va dashboard'lar ularni folder'dan meros oladi. Amalda eng yuqori berilgan ruxsat ishlaydi: `Viewer` rolli odam team orqali `Edit` olgan folder'da tahrirlay oladi. Odatiy sxema: "Payments team'iga `Payments` folder'ida Edit, qolganlarga View".

Service account avtomatlashtirish uchun: CI pipeline yoki skript Grafana HTTP API'siga `Authorization: Bearer <token>` header'i bilan murojaat qiladi. Token service account'ga tegishli (`glsa_` bilan boshlanadi), faqat yaratilgan paytda bir marta ko'rsatiladi va service account rolidan ortiq huquq bermaydi. Shaxsiy parol skriptga yozilmaydi: odam ishdan ketsa yoki parolini almashtirsa pipeline sinadi, token esa alohida bekor qilinadi.

Production'da login SSO orqali (OAuth/OIDC, LDAP), lokal user'lar emas. Anonymous kirish (`GF_AUTH_ANONYMOUS_ENABLED=true`, roli `GF_AUTH_ANONYMOUS_ORG_ROLE`) faqat laboratoriya yoki ichki televizor ekrani uchun va faqat `Viewer` bilan.

### Real ishda qachon kerak

- Jamoalar bir-birining dashboard'ini tasodifan buzmasligi uchun: folder va team.
- Rahbariyat yoki boshqa bo'lim uchun: `Viewer`, tahrirlash imkonisiz.
- CI'dan deploy belgisi yuborish (7-bo'lim): eng kichik yetarli rolli service account.

### Nima uchun shunday

Ruxsatni team va folder'ga bog'lash odamlar almashganda sozlamani o'zgartirmaslik uchun: yangi xodim team'ga qo'shiladi, xolos. Data source ko'rish va Explore cheklangani bejiz emas: data source proxy orqali Grafana'ga kirgan odam ichki tizimga so'rov yubora oladi, shuning uchun ochiq va standart parolli Grafana ichki tarmoqqa eshik. Batafsilroq (har amal uchun alohida) RBAC Grafana Enterprise va Cloud'da bor, OSS'da rollar va folder ruxsatlari yetadi.

## 7. Annotations

### Annotation nima

**Annotation** grafikdagi vaqt belgisi (vertikal chiziq yoki oraliq) va unga yozilgan matn: "shu payt deploy bo'ldi", "shu payt config o'zgardi". "Latency qachon o'sdi?" savolidan keyingi savol doim "o'sha payt nima o'zgardi?", annotation shu ikki savolni bitta rasmga qo'yadi. Annotation'lar metrika emas: ular Grafana bazasida saqlanadi yoki har safar so'rov bilan hisoblanadi.

### Uch manba

- **Qo'lda**: Time series panelida `Ctrl` (macOS'da `Cmd`) bosib click qilinadi, oraliq uchun sudrab belgilanadi, matn va tag yoziladi. Bazada saqlanadi, demak boshqa mashinaga ko'chmaydi.
- **Query asosida**: dashboard sozlamalaridagi Annotations bo'limida data source va so'rov beriladi, so'rov qiymat qaytargan har vaqt nuqtasi belgiga aylanadi. Misol, Prometheus config'i qayta yuklangan paytlar:

```
changes(prometheus_config_last_reload_success_timestamp_seconds[1m]) > 0
```

`prometheus_config_last_reload_success_timestamp_seconds` oxirgi muvaffaqiyatli reload vaqtini saqlaydigan gauge. `changes(...[1m])` oxirgi daqiqada qiymat necha marta o'zgarganini sanaydi, `> 0` faqat o'zgarish bo'lgan nuqtalarni qoldiradi (1-dars: taqqoslash operatori filtr). Bu ta'rif dashboard JSON'ining `annotations.list` qismida turadi, shuning uchun provisioning bilan birga ko'chadi. Restart uchun qaysi metrika mos kelishini 17-vazifada o'zingiz topasiz.
- **HTTP API orqali**: tashqi tizim `POST /api/annotations` yuboradi. Misol, texnik ishlar oynasini oraliq sifatida belgilash:

```
curl -s -X POST http://localhost:3000/api/annotations \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"time": 1767261600000, "timeEnd": 1767265200000, "tags": ["maintenance"], "text": "DB upgrade"}'
```

`time` va `timeEnd` epoch **millisekundda** (soniyada emas); `time` berilmasa hozirgi vaqt olinadi, `timeEnd` bo'lmasa belgi nuqta bo'ladi. `dashboardUID` berilmagani uchun bu organization darajasidagi annotation: uni ko'rsatish uchun dashboard'da Grafana'ning ichki data source'idan tag bo'yicha filtrlaydigan annotation query yoqiladi. `tags` shu filtr uchun.

### Real ishda qachon kerak

- CI/CD pipeline (cicd moduli) deploy tugaganda annotation yuboradi: har grafikda deploy'lar ko'rinadi.
- Incident tahlilida: "xato ulushi deploy'dan 2 daqiqa keyin o'sdi" degan xulosa bir qarashda chiqadi.
- 4-darsdan keyin Loki so'rovi ham annotation manbai bo'ladi (masalan `level=fatal` yozuvlari).

### Nima uchun shunday

Metrikalar "nima bo'ldi" ni ko'rsatadi, "nima uchun" ko'pincha tizimdan tashqaridagi hodisada: deploy, config o'zgarishi, migratsiya. Bu hodisalar siyrak va matnli, ularni counter qilib saqlash noqulay, shuning uchun alohida qatlam bor. Query annotation afzalroq joyda (ma'lumot allaqachon metrikada bo'lsa) undan foydalaning: u hech qanday qo'shimcha integratsiya talab qilmaydi va fayl bilan ko'chadi. API annotation tizim o'zi metrika bermaydigan hodisalar uchun.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Data source | Grafana so'rov yuboradigan tashqi tizim va unga ulanish sozlamasi |
| Data source proxy | brauzer o'rniga Grafana serveri data source'ga so'rov yuboradigan rejim (`access: proxy`) |
| `uid` | data source yoki dashboard'ning instanslar orasida barqaror satr identifikatori |
| Panel | so'rov, vizualizatsiya turi va sozlamalardan iborat dashboard bo'lagi |
| Range / instant query | ifodani oraliqda har `step` da yoki bitta vaqt nuqtasida hisoblash |
| `step` | range so'rovda qo'shni hisoblash nuqtalari orasidagi vaqt |
| Max data points | panel so'raydigan nuqtalar sonining yuqori chegarasi, standart holatda panel kengligi |
| `$__interval` | Grafana vaqt oralig'i va Max data points'dan hisoblagan qadam |
| `$__rate_interval` | `rate` uchun xavfsiz oyna: `max($__interval + scrape interval, 4 * scrape interval)` |
| Query inspector | panel yuborgan haqiqiy so'rov va javobni ko'rsatadigan oyna |
| Explore | dashboard'siz, saqlanmaydigan so'rov yozish maydoni |
| Variable | dashboard tepasidagi tanlov, so'rovda `$name` o'rniga qiymati qo'yiladi |
| Multi-value | variable'da bir nechta qiymat tanlash, Prometheus'da regex alternativasiga aylanadi |
| Repeat | panel yoki row'ni variable'ning har qiymati uchun ko'paytirish |
| Threshold | qiymat chegarasi va unga bog'langan rang |
| Provisioning | Grafana holatini ishga tushishda fayllardan o'rnatish |
| Dashboard provider | dashboard JSON fayllari qaysi papkadan yuklanishini aytadigan provisioning yozuvi |
| Organization, team, folder | ajratilgan muhit, user'lar guruhi, dashboard'lar konteyneri va ruxsat birligi |
| Service account | dastur uchun hisob, API'ga token bilan kiradi |
| Annotation | grafikdagi vaqt belgisi va matni |

## Tuzoqlar

- Data source URL'iga `http://localhost:9090` yozish: konteyner ichida `localhost` konteynerning o'zi. Servis nomi yoziladi.
- Dashboard'larni faqat UI'da saqlash: volume yo'qolsa yoki ikkinchi mashinaga o'tsangiz hammasi qaytadan. Fayl va git haqiqat manbai bo'lsin.
- Data source `uid` ni belgilamaslik: eksport qilingan dashboard boshqa instansda data source'ni topmaydi.
- Tashqi ulashish uchun eksport variantini provisioning'ga qo'yish: `${DS_...}` placeholder'i fayldan yuklanganda almashtirilmaydi.
- `rate(x[1m])` qat'iy oyna yoki `rate(x[$__interval])`: biri uzoq oraliqda ma'lumot tashlaydi, ikkinchisi qisqa oraliqda bo'sh. `$__rate_interval` ishlating va data source'dagi Scrape interval haqiqiy qiymatga teng bo'lsin.
- Multi-value variable bilan `=` matcher: xato chiqmaydi, panel jimgina bo'sh.
- `percent` va `percentunit` ni adashtirish: qiymat 100 marta noto'g'ri ko'rinadi.
- Stat va Table'da range so'rov: ortiqcha yuk, jadvalda esa keraksiz qatorlar.
- `.env` dagi admin parolini o'zgartirib, parol o'zgarishini kutish: u faqat baza birinchi yaratilganda qo'llanadi.
- Standart `admin/admin` parol bilan tarmoqqa ochiq Grafana: data source'lar orqali ichki tizimlarga so'rov yuborish mumkin. Port `127.0.0.1` ga bog'lansin.
- Anonymous Admin (`GF_AUTH_ANONYMOUS_ORG_ROLE=Admin`): ko'p namuna compose fayllarida bor, laboratoriyadan tashqariga chiqmasin.
- Community dashboard'ni ko'r-ko'rona import qilish: bo'sh panel sababini so'rovdan toping, macOS'da ba'zi panellar bo'sh qolishi normal.
- 40 panelli "hamma narsa" dashboard'i va refresh `5s` bilan oraliq `30d`: Prometheus'ga doimiy og'ir yuk. Og'ir ifodalar uchun recording rule (1-dars).
- Annotation API'da vaqtni soniyada yuborish: belgi 1970-yilga tushadi va ko'rinmaydi. Millisekund kerak.
- Token'ni skript ichiga yoki commit'ga yozish: `.env` da turadi, `make check` buni tekshiradi.

## Manbalar

- https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/ – Docker'da ishga tushirish, env sozlamalari, volume
- https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/ – `grafana.ini` va `GF_<SECTION>_<KEY>` qoidasi
- https://grafana.com/docs/grafana/latest/cli/ – Grafana CLI, admin parolini tiklash
- https://grafana.com/docs/grafana/latest/administration/provisioning/ – data source va dashboard provisioning (majburiy)
- https://grafana.com/docs/grafana/latest/datasources/prometheus/ – Prometheus data source, so'rov muharriri, `$__rate_interval`, variable funksiyalari
- https://grafana.com/docs/grafana/latest/panels-visualizations/query-transform-data/ – so'rovlar, Query options (Max data points, Min interval), Query inspector
- https://grafana.com/docs/grafana/latest/panels-visualizations/visualizations/ – vizualizatsiya turlari va ularning sozlamalari
- https://grafana.com/docs/grafana/latest/dashboards/variables/ – variables, multi-value, format'lar, repeat
- https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/ – dashboard dizayni, RED/USE
- https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/ – dashboard JSON modeli
- https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/annotate-visualizations/ – annotations
- https://grafana.com/docs/grafana/latest/developers/http_api/annotations/ – annotations HTTP API
- https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/ – rollar va ruxsatlar
- https://grafana.com/docs/grafana/latest/administration/service-accounts/ – service account'lar va token'lar
- https://grafana.com/blog/2020/09/28/new-in-grafana-7.2-__rate_interval-for-prometheus-rate-queries-that-just-work/ – `$__rate_interval` mexanizmi
- https://prometheus.io/docs/prometheus/latest/querying/api/ – `query` va `query_range`, `step`
- https://prometheus.io/docs/prometheus/latest/querying/functions/#rate – `rate` va oyna
- https://grafana.com/grafana/dashboards/ – community dashboard'lar katalogi

## Birga bajaramiz

Bitta kichik dashboard'ni boshidan oxirigacha olib boramiz: "Prometheus health", ya'ni monitoring tizimining o'zi sog'mi. U faqat Prometheus'ning o'z metrikalaridan foydalanadi (`up`, `scrape_duration_seconds`, `prometheus_*`), ular 1-dars stack'ida `api` va host metrikalaridan mustaqil ravishda bor. Vazifalardagi RED va USE dashboard'lari boshqa metrikalar ustida, ularni o'zingiz qurasiz. Bu yurish 1-vazifadan keyin bajariladi (Grafana servisi va qo'lda qo'shilgan data source kerak).

1. Stack'ni ko'taring va Grafana tirikligini tekshiring:

```
docker compose up -d
curl -s http://localhost:3000/api/health
```

Javobda `"database": "ok"` bo'lsa backend va uning bazasi ishlayapti. Brauzerda `http://localhost:3000` ga `admin` va `.env` dagi parol bilan kiring.

2. Explore'da Prometheus data source'ni tanlab `up` ni **Type**: `Instant` bilan ishlating. Jadvalda har scrape target uchun bitta qator chiqadi: `job` va `instance` label'lari va qiymat `1` (oxirgi scrape muvaffaqiyatli) yoki `0`. Bu instant so'rov: bitta vaqt nuqtasi, har seriyadan bitta qiymat (2-bo'lim).

3. Yangi dashboard yarating, birinchi panel Stat, nomi "Targets up". So'rov `sum(up) / count(up)`, Type `Instant`. Unit `percentunit`, Min `0`, Max `1`. Thresholds: asosiy rang qizil, `1` dan yashil. Description: "Scrape qilinayotgan target'larning tirik ulushi. 100% dan past bo'lsa pastdagi grafikdan qaysi job ekanini toping". Panel bitta savolga javob beradi: "monitoring ko'rmi?". `sum(up)` tirik target'lar soni, `count(up)` hammasi, nisbat 0–1 oralig'ida, shuning uchun `percentunit`.

4. Ikkinchi panel Time series, "Scrape duration". So'rov `scrape_duration_seconds`, Legend `{{job}}`, Unit `s`. Har job uchun bitta chiziq, qiymat millisekundlarda ko'rinadi (Unit `0.004` ni `4 ms` deb formatlaydi). Query inspector'ni oching: `step` ni yozib oling, vaqt oralig'ini 15 daqiqadan 6 soatga o'zgartirib qayta qarang. `step` o'sdi, chunki panel kengligi o'zgarmadi, oraliq kattalashdi (2-bo'lim). Bu gauge, `rate` kerak emas.

5. Dashboard sozlamalarida `handler` nomli Query variable qo'shing: `label_values(prometheus_http_requests_total, handler)`, Multi-value va Include All yoqilgan. Uchinchi panel Time series, "API requests":

```
sum by (handler) (rate(prometheus_http_requests_total{handler=~"$handler"}[$__rate_interval]))
```

Legend `{{handler}}`, Unit `reqps`. Tepadagi ro'yxatdan ikki handler tanlang: grafikda ikki chiziq qoladi. Query inspector'da `$handler` va `$__rate_interval` o'rniga nima qo'yilganini ko'ring (3-bo'lim va 2-bo'lim).

6. To'rtinchi panel Time series, "Active series": `prometheus_tsdb_head_series`, Unit `short`. Bu Prometheus xotirasidagi faol seriyalar soni, 1-darsdagi cardinality'ning bitta raqami. Description'ga "keskin o'sish yangi yuqori cardinality'li label belgisi" deb yozing. Panellarni joylashtiring: Stat tepada, grafiklar ostida (4-bo'lim: avval umumiy holat, keyin tafsilot).

7. Dashboard'ga query annotation qo'shing: nomi "Config reload", so'rovi 7-bo'limdagi `changes(prometheus_config_last_reload_success_timestamp_seconds[1m]) > 0`. Keyin Prometheus'ga config'ni qayta o'qitadigan signal yuboring:

```
docker compose kill -s SIGHUP prometheus
```

`SIGHUP` Prometheus uchun "config'ni qayta yukla" degani, jarayon to'xtamaydi (signal: linux moduli, 1-dars). Bir daqiqa ichida hamma panelda vertikal belgi paydo bo'ladi.

8. Dashboard'ni saqlang, sozlamalarida `uid` ni o'qiladigan qiymatga o'zgartirmoqchi bo'lsangiz JSON Model'da `"uid": "prom-health"` qiling. Oddiy eksport bilan JSON'ni oling va `grafana/dashboards/sandbox/prom-health.json` ga yozing. Faylda `"id"` ni `null` qiling va `datasource` qatorlariga qarang:

```json
"datasource": { "type": "prometheus", "uid": "<random string>" }
```

Bu qo'lda qo'shilgan data source'ning tasodifiy `uid` si (1-bo'lim). Hozircha shunday qoldiring.

9. UI'dagi asl dashboard'ni o'chiring (aks holda bir xil `uid` li ikki manba bo'ladi). 5-bo'limdagi `sandbox` provider'ini `grafana/provisioning/dashboards/sandbox.yaml` ga yozing va compose'dagi `grafana` servisiga ikki mount qo'shing (fragment):

```yaml
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
```

`docker compose up -d grafana` konteynerni yangi mount'lar bilan qayta yaratadi. `docker compose logs grafana` da provisioning xatosi yo'qligini tekshiring. Dashboard `Sandbox` folder'ida paydo bo'ladi, endi u fayldan kelgan: panel nomini o'zgartirib saqlashga urinsangiz Grafana bazaga yozmaydi (`allowUiUpdates: false`).

10. Ikki mashina tekshiruvi (fikran yoki keyingi safar amalda): bu uch faylni commit qilib ikkinchi mashinada `git pull` va `docker compose up -d` qilsangiz, dashboard paydo bo'ladi, lekin panellar data source topilmadi deydi. Sabab 8-qadamdagi tasodifiy `uid`: u faqat birinchi mashinadagi bazada bor. Buni 12-vazifa hal qiladi, shundan keyin JSON'dagi `uid` ni yangi qat'iy qiymatga almashtirasiz. `Sandbox` fayllarini keyin qoldirish yoki o'chirish o'zingizga havola.

Shu 10 qadamda ko'rganingiz: Grafana metrika saqlamaydi, faqat so'raydi (1-bo'lim); instant va range so'rov, `step`, `$__rate_interval`, unit va threshold (2-bo'lim); query variable va `=~` (3-bo'lim); panel bitta savolga javob beradi va umumiy holat tepada turadi (4-bo'lim); dashboard bu JSON, provider uni fayldan yuklaydi, data source `uid` esa ko'chishning sharti (5-bo'lim); query annotation hodisani grafikka bog'laydi (7-bo'lim). 6-bo'lim (user va ruxsatlar) E guruh vazifalarida.

---

## Vazifalar

Ish papkasi: `observability/02-grafana/` (`make new m=observability n=02 name=grafana` bilan host'da yarating). Javoblar shu papkadagi `README.md` da, har vazifa uchun `## N. Title` ostida: nima qildingiz, so'rov yoki config'ning muhim qismi, kuzatuv va o'z so'zingiz bilan izoh. Skrinshot kerak bo'lsa shu papkaga qo'ying. Stack fayllari (`compose.yaml`, `grafana/provisioning/...`, `grafana/dashboards/*.json`) `observability/stack/` da. Hamma vazifa ikkala mashinada bajariladi; host metrikalariga tegishli raqamlar (C guruh) mashinaga qarab farq qiladi, README'da qaysi mashinada olinganini yozing. Mashg'ulotni tugatishdan oldin UI'da qurilgan dashboard'ni JSON'ga eksport qilib commit qiling, aks holda u ikkinchi mashinada bo'lmaydi.

### A. Birinchi dashboard

1. **Grafana service.** `grafana` servisini compose'ga qo'shing: aniq versiya, named volume, admin paroli `.env` dan, port host'da faqat `127.0.0.1` ga bog'langan. `.env` `.gitignore` da ekanini tekshiring. UI'da Prometheus data source'ni qo'lda qo'shing va **Save & test** natijasini yozing. URL'ga `http://localhost:9090` yozib ko'ring: xato matni nima va nima uchun? Yo'nalish: Laboratoriya jadvali va 1-bo'lim, "`localhost` tuzog'i".

2. **Explore.** Explore'da 1-darsdagi uchta RED so'rovini ishlating. Query inspector'da (Inspect → Query) Grafana Prometheus'ga qaysi `start`, `end`, `step` bilan so'rov yuborganini yozing. Vaqt oralig'ini 5 daqiqadan 24 soatga o'zgartiring: `step` qanday o'zgardi? Ikkinchi mashinada 24 soatlik tarix bo'lmasligi mumkin, `step` baribir hisoblanadi. Yo'nalish: 2-bo'lim, "Mexanizm: vaqt oralig'idan `step` gacha".

3. **Rate interval.** Bitta panelda uchta so'rov chizing: `rate(...[1m])`, `rate(...[$__interval])`, `rate(...[$__rate_interval])`. Oraliqni 5 daqiqa va 24 soat qilib solishtiring. Qaysi biri qachon bo'sh yoki noto'g'ri, sababi nima? Data source'dagi scrape interval sozlamasini noto'g'ri (`1m`) qilib nima o'zgarishini ko'rsating. Yo'nalish: 2-bo'lim, "`$__rate_interval`".

4. **RED dashboard.** `api` uchun dashboard yarating: tepada uchta Stat (so'rov/s, error %, p95), ostida Rate (route bo'yicha), Errors (foiz), Duration (p50/p95/p99). Har panelda to'g'ri unit, o'qiladigan legend, description. Error % uchun threshold (masalan 1% sariq, 5% qizil). Yo'nalish: 2-bo'lim, "Unit, legend, threshold" va 4-bo'lim.

5. **Heatmap.** Latency histogram'ini Heatmap panelida chizing. Loadgen'ga sekin so'rovlar guruhini qo'shing (masalan har o'ninchi so'rov 1 soniyadan uzoq endpoint'ga). Heatmap'da ikki cho'qqi ko'rinadimi? p95 chizig'i shu holatni qanday ko'rsatdi, o'rtacha-chi? Yo'nalish: 4-bo'lim, "Heatmap: taqsimotni ko'rish".

### B. Variables

6. **Query variable.** `route` variable'ini `label_values(...)` bilan yarating, Multi-value va Include All yoqilgan. Panellarni shu variable bo'yicha filtrlang. Avval `route="$route"` yozib ikkita qiymat tanlang va nima bo'lishini ko'rsating, keyin tuzating. Query inspector'da variable qanday qiymatga aylanganini yozing. Yo'nalish: 3-bo'lim, "Mexanizm: multi-value va `=~`".

7. **Chained variables.** `job` va unga bog'liq `instance` variable'larini yarating. `job` o'zgarganda `instance` ro'yxati yangilanishini ko'rsating. Bog'liqlik qaysi so'rov orqali ifodalangan? Yo'nalish: 3-bo'lim, "Mexanizm: query variable".

8. **Repeat.** Bitta latency panelini `route` variable'i bo'yicha repeat qiling. Route'lar soni 50 ta bo'lsa bu dizayn nimaga olib keladi va o'rniga nima qilgan bo'lardingiz? Yo'nalish: 3-bo'lim, "Interval variable va repeat".

### C. USE va community dashboard

9. **Import Node Exporter Full.** ID `1860` dashboard'ni import qiling. "No data" chiqqan kamida ikkita panelni toping, so'rovini ochib sababini aniqlang (yo'q metrika, boshqa label, o'chirilgan collector). Bitta foydali panelning so'rovini tahlil qilib o'z so'zingiz bilan tushuntiring. macOS'da bo'sh panellar ko'proq bo'ladi (metrikalar Docker Desktop VM'idan), sababini shu usul bilan aniqlang, tuzatishga urinmang. Yo'nalish: 4-bo'lim, "Community dashboard'lar va bo'sh panel diagnostikasi".

10. **USE dashboard.** O'zingiz host uchun ixcham USE dashboard yozing: CPU, xotira, disk, tarmoq uchun utilization va saturation (jami 6–8 panel). Community dashboard'dan nimani oldingiz, nimani ataylab tashladingiz? Raqamlar Zorin'da ish mashinasiniki, macOS'da Docker Desktop VM'iniki: README'da qaysi biri ekanini va ikkinchi mashinada qaysi panel boshqacha yoki bo'sh chiqqanini yozing. Yo'nalish: 4-bo'lim va Laboratoriya jadvali.

11. **Container panel.** cAdvisor metrikalaridan har konteyner CPU va xotirasini ko'rsatadigan Table yoki Bar gauge panel qo'shing (Instant so'rov). `api` konteyneriga compose'da xotira limiti qo'ying va panelda limitga nisbatan foizni ko'rsating. macOS'da kerakli metrika yoki label bo'lmasa, Explore'da nima borligini ko'rsatib README'ga yozing. Yo'nalish: 2-bo'lim, "Mexanizm: range va instant so'rov".

### D. Provisioning

12. **Datasource as code.** Prometheus data source'ni provisioning fayliga ko'chiring (`uid: prometheus`, scrape interval bilan). Grafana volume'ini o'chirib qayta ko'taring (faqat shu volume, nomi bilan: Laboratoriya, "Tozalash"): data source o'zi paydo bo'lishini ko'rsating. UI'da uni tahrirlashga urinib ko'ring: nima bo'ladi? Yo'nalish: 5-bo'lim, "Mexanizm: provisioning".

13. **Dashboards as code.** RED va USE dashboard'larini JSON'ga eksport qilib `grafana/dashboards/` ga qo'ying, provider yozing. Volume'ni yana o'chirib ko'taring: dashboard'lar `Shop` folder'ida paydo bo'lsin. JSON'da `datasource.uid` qanday yozilganini ko'rsating va nima uchun 12-vazifadagi qat'iy `uid` muhimligini izohlang. Yo'nalish: 5-bo'lim, "Dashboard bu JSON hujjat" va "UI'dagi tahrir va fayl".

14. **Break provisioning.** Uchta xatoni navbat bilan qiling va `docker compose logs grafana` dagi xabarni yozing: data source YAML'ida noto'g'ri indentatsiya; dashboard JSON'ida mavjud bo'lmagan data source `uid`; ikki dashboard faylida bir xil `uid`. Har birida UI'da nima ko'rinadi? Har xatodan keyin faylni to'g'ri holatga qaytaring. Yo'nalish: 5-bo'lim.

15. **UI edits vs file.** `allowUiUpdates: false` bilan provisioning qilingan dashboard'ni UI'da o'zgartirib saqlashga urining. Keyin `true` qiling, saqlang, Grafana'ni restart qiling. Har ikki holatda o'zgarish nima bo'ldi? Jamoada qaysi tartibni tanlaysiz va nima uchun? Yo'nalish: 5-bo'lim, "UI'dagi tahrir va fayl".

### E. Kirish huquqlari va annotations

16. **Users and folders.** Viewer rolida `viewer1` va Editor rolida `editor1` user yarating, `dev` team'iga `editor1` ni qo'shing. `Shop` folder'iga `dev` team uchun Edit, qolganlarga View bering. Har user bilan kirib (private oynada) nima qila olishini tekshiring: Explore, dashboard tahrirlash, data source ko'rish. Bu user va team'lar bazada yashaydi: ikkinchi mashinada ular bo'lmaydi, vazifani bitta mashinada bajarish yetadi. Yo'nalish: 6-bo'lim.

17. **Query annotations.** RED dashboard'ga `api` restart'larini ko'rsatadigan query annotation qo'shing. `docker compose restart api` qiling va grafikda belgi paydo bo'lishini, shu paytda rate grafigida nima ko'ringanini yozing. Yo'nalish: 7-bo'lim, "Uch manba".

18. **Deploy annotation via API.** Service account va token yarating (token `.env` da, commit qilinmaydi). `curl` bilan `deploy` tag'li annotation yuboradigan `annotate.sh` skript yozing (argument: matn). Dashboard'da shu tag bo'yicha annotation'larni yoqing. cicd modulidagi pipeline'ingizga bu qadamni qayerga qo'shgan bo'lardingiz? Token ham bazaga bog'liq: ikkinchi mashinada yangisi yaratiladi. Yo'nalish: 6-bo'lim, "Mexanizm: ruxsat qanday hisoblanadi" va 7-bo'lim.

19. **Mini-project: Grafana from zero.** `docker compose down -v`, keyin bitta `docker compose up -d`: Grafana admin paroli `.env` dan, Prometheus data source, `Shop` folder'ida RED va USE dashboard'lari (variable'lar va restart annotation bilan) hech qanday qo'lda qadamsiz paydo bo'lsin. `README.md` ga har dashboard qaysi savolga javob berishini va incident paytida qaysi tartibda qarashingizni yozing. Diqqat: `down -v` shu stack'ning hamma volume'ini, jumladan Prometheus tarixini ham o'chiradi, bu yerda bu ataylab. Eng yaxshi tekshiruv: ikkinchi mashinada `git pull` va `docker compose up -d`. Yo'nalish: butun dars.

### Topshirish

Tayyor bo'lgach:
1. `observability/02-grafana/README.md` da 19 ta vazifaning har biri `## N. Title` sarlavhasi ostida, C guruhda qaysi mashinada bajarilgani yozilgan; `annotate.sh` shu papkada.
2. `docker compose down -v && docker compose up -d` dan keyin hamma narsa provisioning'dan tiklanadi (19-vazifa).
3. `make check` toza (host'da): `.env` va token'lar repoda yo'q, YAML va shell lint o'tadi.
4. `observability/stack/` da `compose.yaml`, `grafana/provisioning/datasources/`, `grafana/provisioning/dashboards/` va `grafana/dashboards/*.json` commit'ga tayyor; Grafana volume'i va `.env` yo'q.
5. `docker compose down` qilingan (volume'lar qolgan).
6. Menga xabar bering, README va stack fayllarini o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Grafana metrikalarni qayerda saqlaydi? Grafana volume'i yo'qolsa nima yo'qoladi, nima yo'qolmaydi?
- Ofisda UI'da qurilgan dashboard uyda nima uchun yo'q va uni ikkala mashinada paydo qilish uchun nima kerak?
- Data source URL'ida `localhost` nima uchun ishlamaydi, brauzerda esa o'sha manzil ochiladi?
- Panel vaqt oralig'i va kengligidan `step` ni qanday chiqaradi? 5 daqiqalik va 7 kunlik ko'rinishda nima farq qiladi?
- `$__rate_interval` qaysi ikki muammoni hal qiladi va scrape interval qiymatini qayerdan oladi?
- Stat panel uchun instant so'rov nima uchun yetarli?
- Multi-value variable so'rovda nimaga aylanadi va nima uchun `=~` kerak?
- Data source `uid` ni qo'lda belgilash nima beradi?
- `allowUiUpdates` ning ikkala qiymatida UI'dagi o'zgarish taqdiri qanday?
- RED dashboard'da panellar qaysi tartibda joylashadi va nima uchun?
- Community dashboard'ni import qilishning foydasi va xavfi nima? Bo'sh panel sababini qanday topasiz?
- Org roli, team va folder ruxsati birgalikda qanday ishlaydi? Skript uchun nima uchun shaxsiy parol emas, service account token?
- Deploy annotation'lari incident tekshiruvida qaysi savolga javob beradi?
