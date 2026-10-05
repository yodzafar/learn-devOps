# 7-dars: OpenTelemetry va modul mini-loyihasi

Maqsad: oldingi darslarda har signal o'z yo'li bilan ketdi: metrikalar `prom-client` yoki `client_golang` orqali scrape bilan, log'lar stdout va Alloy orqali, trace'lar OTLP bilan, profillar Pyroscope SDK bilan. OpenTelemetry (OTel) telemetriyani yaratish va tashishning yagona, vendor'ga bog'lanmagan standarti: bitta API va SDK, bitta protokol (OTLP), bitta oraliq komponent (Collector). Bu darsda OTel qismlarini, signallar holatini, Collector pipeline'larini va semantic conventions'ni o'rganasiz, ilovaning metrika, log va trace'larini Collector orqali Prometheus, Loki va Tempo'ga yo'naltirasiz. Yakunida modul mini-loyihasi: to'liq stack kod sifatida va simulyatsiya qilingan incident'ni alert'dan profilgacha tekshirish. Kubernetes modulida aynan shu Collector DaemonSet va gateway sifatida qaytadi.

Taxminiy vaqt: 4 kun (siz uchun): 2 kun OTel va Collector, 2 kun mini-loyiha. Diqqatni quyidagilarga qarating: API va SDK ajratilishi, Collector'da komponent e'lon qilish bilan pipeline'ga ulash farqi, processor'lar tartibi, resource attribute'lar Prometheus va Loki label'lariga qanday aylanishi, OTel metrika nomlari eski dashboard'larni qanday buzishi.

## Laboratoriya

`observability/stack/` ustida. Yangi servis: `otelcol` (OpenTelemetry Collector, contrib distributsiyasi: image `otel/opentelemetry-collector-contrib`, versiya https://github.com/open-telemetry/opentelemetry-collector-releases/releases ). Config konteyner ichida `/etc/otelcol-contrib/config.yaml`.

```
mkdir -p otelcol
docker compose run --rm otelcol validate --config=/etc/otelcol-contrib/config.yaml
docker compose up -d otelcol
docker compose logs -f otelcol
```

Collector image'i `scratch` asosida: ichida shell yo'q, `docker compose exec otelcol sh` ishlamaydi. Diagnostika: konteyner log'i, `debug` exporter va Collector'ning o'z metrikalari. Ilovalar endi faqat `otelcol:4317`/`4318` ni biladi, backend manzillarini bilmaydi. Mini-loyiha oxirida modul to'liq tozalanadi: `docker compose --profile "*" down -v`, keyin `docker volume ls` va `docker ps -a` bilan tekshirish.

---

## 1. OpenTelemetry nima

CNCF loyihasi, spetsifikatsiya va uning amalga oshirilishlari to'plami. U backend emas: ma'lumotni saqlamaydi va ko'rsatmaydi, faqat yaratadi, qayta ishlaydi va yetkazadi.

| Qism | Vazifasi |
|------|----------|
| API | kod chaqiradigan interfeys: tracer, meter, logger. SDK ulanmagan bo'lsa hech narsa qilmaydi (no-op) |
| SDK | API'ning amalga oshirilishi: sampling, batching, resource, exporter'lar |
| Instrumentation libraries | tayyor o'rovlar: HTTP server/client, DB driver, framework |
| OTLP | tashish protokoli: gRPC (`4317`) va HTTP (`4318`) |
| Collector | telemetriyani qabul qiluvchi, qayta ishlovchi va jo'natuvchi alohida jarayon |
| Semantic conventions | atribut va metrika nomlari lug'ati |

API va SDK ajratilishining ma'nosi: kutubxona muallifi faqat API'ga bog'lanadi, ilova egasi SDK va exporter'ni tanlaydi. Vendor almashtirish kodni emas, exporter yoki Collector config'ini o'zgartirish degani.

### Signallar va holati
| Signal | Spetsifikatsiya holati | Izoh |
|--------|------------------------|------|
| Traces | barqaror | eng yetuk signal |
| Metrics | barqaror | |
| Logs | barqaror | mavjud logger'lar "bridge" orqali ulanadi, yangi logging API emas |
| Baggage | barqaror | kontekst bilan birga uzatiladigan kalit-qiymatlar |
| Profiles | ishlab chiqilmoqda | OTLP'da development holatida, Collector komponentlarida alpha; production uchun hali Pyroscope SDK yoki eBPF |

Bu spetsifikatsiya darajasi. Har til SDK'sida holat alohida: masalan dars yozilgan paytda JavaScript'da traces va metrics barqaror, logs esa development; Go'da logs release candidate. Ishlatishdan oldin https://opentelemetry.io/docs/languages/ dagi o'z tilingiz jadvalini tekshiring.

## 2. Instrumentatsiya

### Auto va manual
- **Zero-code (auto)**: kodga tegmasdan. Node.js'da `--require @opentelemetry/auto-instrumentations-node/register` (5-darsda ishlatgansiz), Java'da agent, Python'da `opentelemetry-instrument`. Go'da kutubxona o'rovlari (`otelhttp`) kodda ulanadi.
- **Manual**: biznes ma'nosi bor narsalar: o'z span'ingiz, o'z metrikangiz (`meter.createCounter("shop.orders")`), atributlar.

Amaliy tartib: avval auto (HTTP, DB, chiquvchi chaqiruvlar bepul keladi), keyin eng muhim biznes operatsiyalariga manual.

### Sozlash
SDK env orqali sozlanadi (5-dars jadvali). Signal bo'yicha exporter: `OTEL_TRACES_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_LOGS_EXPORTER` (`otlp`, `console`, `none`). Metrikalar davriy eksport qilinadi (`OTEL_METRIC_EXPORT_INTERVAL`, millisekundda): bu push, Prometheus scrape'i emas.

### Resource attributes
Resource telemetriya manbasini tavsiflaydi va uchala signalda bir xil bo'ladi, bog'lash shu orqali ishlaydi:

```
OTEL_SERVICE_NAME=api
OTEL_RESOURCE_ATTRIBUTES=service.namespace=shop,service.version=1.5.0,deployment.environment.name=lab
```

`service.name` belgilanmasa `unknown_service` bo'lib qoladi va hamma servis bitta nom ostida aralashadi. Resource detector'lar host, konteyner, cloud va Kubernetes atributlarini avtomatik qo'shadi (SDK'da yoki Collector'ning `resourcedetection` processor'ida).

### Semantic conventions
Bir xil narsani hamma bir xil nomlasa, dashboard va so'rovlar servislar va tillar orasida ko'chadi.

| Soha | Nomlar |
|------|--------|
| HTTP span va metrika atributlari | `http.request.method`, `http.response.status_code`, `http.route`, `url.path`, `server.address` |
| HTTP server metrikasi | `http.server.request.duration` (histogram, soniyada) |
| Resource | `service.name`, `service.namespace`, `service.version`, `service.instance.id`, `deployment.environment.name` |

Eski kod va maqolalarda oldingi nomlar uchraydi (`http.method`, `http.status_code`). O'z atributlaringizga prefiks bering (`shop.order.id`), umumiy nomlar bilan to'qnashmasin.

## 3. Collector

### Nima uchun oraliq bo'g'in
- Ilova faqat bitta manzilni biladi. Backend qo'shish, almashtirish, ikki joyga yuborish Collector config'ida.
- Batch, retry, navbat ilovadan tashqarida: backend sekinlashsa ilova bloklanmaydi.
- Markaziy qayta ishlash: maxfiy atributlarni o'chirish, label qo'shish, tail sampling, shovqinni tashlash.
- Protokol tarjimasi: Prometheus scrape, fayl log'lari, eski formatlar OTLP'ga.

Joylashtirish: **agent** (har host yoki pod yonida, ilovaga yaqin) va **gateway** (markaziy, bir nechta replika). Ko'pincha ikkalasi birga. Grafana Alloy ham Collector distributsiyasi: 4-darsdagi `loki.*` komponentlari yonida `otelcol.*` komponentlari bor. Distributsiyalar: `otelcol` (core, minimal to'plam) va `otelcol-contrib` (hamma komponentlar: laboratoriya uchun qulay, production'da keraklilaridan o'z build'ingizni yig'ish tavsiya etiladi).

### Config tuzilishi
```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  memory_limiter: { check_interval: 1s, limit_mib: 400 }
  batch: {}
exporters:
  otlp_grpc/tempo:
    endpoint: tempo:4317
    tls: { insecure: true }
  debug: { verbosity: basic }
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc/tempo, debug]
```

- Komponent nomi `type/name`: bir turdan bir nechta bo'lishi mumkin (`otlp_http/loki`, `otlp_http/prometheus`).
- **Tuzoq: e'lon qilish yetmaydi.** `receivers:`, `processors:`, `exporters:` ostida yozilgan komponent `service.pipelines` ga qo'shilmaguncha ishlamaydi. Eng ko'p uchraydigan "nima uchun ma'lumot kelmayapti" sababi.
- Har signal uchun alohida pipeline: `traces`, `metrics`, `logs`. Bitta receiver bir nechta pipeline'da qatnashishi mumkin.
- Env interpolatsiyasi: `${env:LOKI_URL}`.
- OTLP exporter'lar nomi: `otlp_grpc` va `otlp_http`. Eski versiya va qo'llanmalarda `otlp` va `otlphttp` (hozir deprecated alias). O'z versiyangiz hujjatiga qarang.

| Tur | Misollar |
|-----|----------|
| Receivers | `otlp`, `prometheus` (scrape qiladi), `filelog`, `hostmetrics` |
| Processors | `memory_limiter`, `batch`, `resource`, `attributes`, `filter`, `transform` (OTTL tili), `tail_sampling`, `resourcedetection` |
| Exporters | `otlp_grpc`, `otlp_http`, `debug`, `prometheus` (scrape uchun endpoint ochadi), `prometheusremotewrite` |
| Connectors | `spanmetrics`: bir pipeline'ning chiqishi, boshqasining kirishi (trace'lardan RED metrikalari) |
| Extensions | `health_check`, `zpages`: pipeline'dan tashqari yordamchilar |

### Processor'lar tartibi
Tartib ro'yxatda yozilganidek. Qoida: `memory_limiter` birinchi (xotira tugashidan oldin yangi ma'lumotni rad etadi, yuboruvchi qayta urinadi), sampling va filtrlar o'rtada, `batch` oxirida (tashlab yuboriladigan ma'lumotni batch qilish behuda). `tail_sampling` qaror uchun trace'ni `decision_wait` muddat xotirada ushlaydi:

```yaml
tail_sampling:
  decision_wait: 10s
  policies:
    - { name: errors, type: status_code, status_code: { status_codes: [ERROR] } }
    - { name: slow, type: latency, latency: { threshold_ms: 500 } }
    - { name: rest, type: probabilistic, probabilistic: { sampling_percentage: 10 } }
```

### Backend'larga yo'naltirish
| Signal | Exporter | Manzil | Backend'da kerak |
|--------|----------|--------|-------------------|
| Traces | `otlp_grpc` | `tempo:4317` | Tempo OTLP receiver (5-dars) |
| Metrics | `otlp_http` | `http://prometheus:9090/api/v1/otlp` | `--web.enable-otlp-receiver` flag'i |
| Logs | `otlp_http` | `http://loki:3100/otlp` | structured metadata yoqiq (Loki 3.x da default) |

`otlp_http` exporter bazaviy manzilga signal yo'lini o'zi qo'shadi (`/v1/metrics`, `/v1/logs`, `/v1/traces`).

**Prometheus tomoni.** OTLP metrikalari Prometheus nomlariga tarjima qilinadi: `http.server.request.duration` (birlik `s`) → `http_server_request_duration_seconds_bucket/_sum/_count`. `service.name` `job` ga (`service.namespace` bo'lsa `namespace/name`), `service.instance.id` `instance` ga aylanadi. Qolgan resource attribute'lar default holatda metrika label'i emas, alohida `target_info` seriyasida; kerakligini `prometheus.yml` dagi `otlp.promote_resource_attributes` bilan label'ga ko'tarasiz. Push bo'lgani uchun `up` seriyasi yo'q: target o'lganini boshqa yo'l bilan bilish kerak.

**Loki tomoni.** `service.name`, `service.namespace`, `deployment.environment.name` kabi cheklangan ro'yxatdagi resource attribute'lar avtomatik index label bo'ladi (nuqtalar pastki chiziqqa: `service_name`), qolgan atributlar, jumladan trace ID, structured metadata'ga tushadi.

**Tuzoq: nomlar o'zgaradi.** `prom-client` dan OTel metrikalariga o'tsangiz, `http_request_duration_seconds` endi `http_server_request_duration_seconds`, label'lar `route`/`status` o'rniga `http_route`/`http_response_status_code`, log label'i `service` o'rniga `service_name`. Dashboard, recording rule va alert'lar jimgina bo'sh qoladi. Migratsiya: ikkalasini parallel yuritish, so'rovlarni ko'chirish, keyin eskisini o'chirish.

### Collector'ni kuzatish
Collector o'zi ham kuzatilishi kerak: u hamma telemetriya o'tadigan yagona nuqta. Ichki metrikalarini (`otelcol_receiver_accepted_*`, `otelcol_exporter_sent_*`, `otelcol_exporter_send_failed_*`, navbat hajmi) Prometheus bilan scrape qiling, `service.telemetry` bo'limida sozlanadi. Qabul qilingan va yuborilgan sonlar farqi yo'qotishni bildiradi.

## 4. Hamma narsa OTel orqalimi?

| | To'g'ridan-to'g'ri (1–6-darslar) | OTel SDK + Collector |
|---|---|---|
| Ilova bog'liqligi | har backend uchun alohida kutubxona | bitta API, bitta protokol |
| Metrikalar | pull, `up` bor, Prometheus nomlari | push, nomlar semantic conventions bo'yicha |
| Log'lar | stdout, platforma yig'adi | OTLP yoki baribir stdout + collector |
| Murakkablik | kam bo'g'in | yana bitta komponent, lekin markaziy boshqaruv |

Aralash sxema normal va keng tarqalgan: trace'lar OTel bilan (boshqa yo'l deyarli qolmagan), infratuzilma metrikalari Prometheus exporter'lari va scrape bilan (node_exporter, cAdvisor qayta yozilmaydi), ilova metrikalari jamoa tanloviga ko'ra, log'lar stdout orqali (ilova log tizimi ishlamasa ham yozaveradi, `docker logs` ishlaydi), profillar Pyroscope bilan.

## 5. Incident tekshiruvi zanjiri

Modulning maqsadi shu yo'lni bir necha daqiqada bosib o'tish:

1. **Alert** (3-dars): symptom, masalan burn rate. Runbook birinchi dashboard'ni ko'rsatadi.
2. **Metrics** (1–2-darslar): RED dashboard: qaysi servis, qaysi route, qachondan. Deploy annotation'i bormi? USE: resurs to'yinganmi?
3. **Logs** (4-dars): shu servis va vaqt oralig'idagi error log'lar: xato matni, qaysi so'rovlar.
4. **Traces** (5-dars): exemplar yoki log'dagi `trace_id` orqali bitta sekin yoki xatoli so'rov: vaqt qaysi servis va span'da ketgan.
5. **Profiles** (6-dars): o'sha servisning shu vaqtdagi flame graph'i: qaysi funksiya.

Har qadam savolni toraytiradi: tizim → servis → so'rov → span → funksiya. Bog'lanishlar (exemplar, derived field, trace-to-logs, bir xil `service.name`) bo'lmasa, har qadamda vaqt va servisni qo'lda ko'chirasiz, MTTR shuncha uzayadi.

## Tuzoqlar

- Komponentni e'lon qilib, pipeline'ga qo'shmaslik: Collector xatosiz ishga tushadi, ma'lumot yo'q.
- `memory_limiter` siz Collector: yuklama cho'qqisida OOM bo'lib, hamma signal birga yo'qoladi.
- Receiver'ni `localhost` da qoldirish (Collector default'i): konteynerdagi boshqa servislar ulana olmaydi. Aksincha, `0.0.0.0:4317` ni internetga ochish: har kim telemetriya yubora oladi.
- `service.name` ni belgilamaslik: hamma narsa `unknown_service`.
- OTel'ga o'tishda metrika va label nomlari o'zgarishini hisobga olmaslik: alert'lar jim, dashboard'lar bo'sh.
- Resource attribute'larni hammasini Prometheus label'iga ko'tarish: cardinality (`service.instance.id`, `container.id` har restart'da yangi).
- Collector'ni kuzatmaslik: telemetriya yo'qolayotganini hech qaysi dashboard ko'rsatmaydi, chunki dashboard'larning o'zi shu telemetriyaga bog'liq.
- Bitta Collector'ga hamma narsani bog'lab, uni yagona nosozlik nuqtasiga aylantirish: production'da replikalar va ilova tomonida chegaralangan navbat.
- Tail sampling'ni bir nechta replikada trace ID bo'yicha yo'naltirishsiz ishlatish (5-dars).
- Eski qo'llanmalardan config ko'chirish: `logging` exporter (`debug` ga almashgan), `otlp`/`otlphttp` nomlari, Loki uchun maxsus exporter (hozir Loki OTLP'ni o'zi qabul qiladi), Jaeger exporter (OTLP bilan almashgan).

## Manbalar

- https://opentelemetry.io/docs/concepts/ – tushunchalar: signallar, komponentlar (majburiy)
- https://opentelemetry.io/docs/specs/status/ – signallar holati (Profiles shu yerda)
- https://opentelemetry.io/docs/languages/ – til SDK'lari va ularning holati
- https://opentelemetry.io/docs/collector/configuration/ – Collector config
- https://opentelemetry.io/docs/collector/deployment/ – agent va gateway sxemalari
- https://opentelemetry.io/docs/collector/install/docker/ – Collector Docker'da
- https://github.com/open-telemetry/opentelemetry-collector-contrib – contrib komponentlari va README'lari (`tail_sampling`, `spanmetrics`)
- https://opentelemetry.io/docs/specs/semconv/ – semantic conventions
- https://opentelemetry.io/docs/languages/sdk-configuration/ – `OTEL_*` env o'zgaruvchilari
- https://prometheus.io/docs/guides/opentelemetry/ – Prometheus'da OTLP qabul qilish
- https://grafana.com/docs/loki/latest/send-data/otel/ – Loki'ga OTLP log yuborish
- https://sre.google/sre-book/postmortem-culture/ – blameless postmortem

---

## Vazifalar

Javoblar `observability/07-opentelemetry/README.md` da (`make new m=observability n=07 name=opentelemetry`), har vazifa uchun `## N. Title` ostida: config'ning muhim qismi, buyruq, kuzatuv, izoh. Stack fayllari (`otelcol/config.yaml`, yangilangan `compose.yaml`, provisioning, qoidalar) `observability/stack/` da; mini-loyiha hisoboti `observability/07-opentelemetry/postmortem.md` da.

### A. Collector asoslari

1. **Collector with debug exporter.** `otelcol` servisini qo'shing. Config: OTLP receiver (gRPC va HTTP), `debug` exporter, uchala signal uchun pipeline. `validate` buyrug'i toza o'tsin. `api` ni Collector'ga yo'naltiring (faqat trace'lar) va Collector log'ida span'lar kelayotganini ko'rsating. `debug` verbosity'ni `detailed` qilib bitta span'ning resource va atributlarini yozing.

2. **Declared but not wired.** Config'ga `otlp_grpc/tempo` exporter'ini e'lon qiling, lekin pipeline'ga qo'shmang. Collector xato beradimi? Trace Tempo'da bormi? Keyin pipeline'ga mavjud bo'lmagan komponent nomini yozing: `validate` nima deydi? Ikkalasini tuzating.

3. **Traces through the Collector.** Trace'larni Collector orqali Tempo'ga yuboring, ikkala ilovada ham (`api`, `inventory`). Ilovalardagi backend manzillarini olib tashlang: ular faqat Collector'ni bilsin. Grafana'da 5-darsdagi trace-to-logs va TraceQL so'rovlari hali ishlashini tekshiring.

4. **Shell-less image.** `docker compose exec otelcol sh` ni sinang va xatoni yozing. Shell'siz konteynerni qanday diagnostika qilasiz: kamida uch usulni amalda ko'rsating (log, `debug` exporter, ichki metrikalar yoki `zpages` extension).

5. **Processors.** `memory_limiter` va `batch` ni qo'shing. `resource` yoki `attributes` processor bilan hamma telemetriyaga `deployment.environment.name=lab` qo'shing va bitta maxfiy deb hisoblangan atributni (masalan `http.request.header.authorization` yoki o'zingiz qo'shgan sinov atributi) o'chiring. Tempo'dagi span'da natijani ko'rsating. Processor'lar tartibini nima uchun shunday tanladingiz?

### B. Metrics va logs OTel orqali

6. **OTLP metrics to Prometheus.** Prometheus'da OTLP qabul qilishni yoqing. Ilovada OTel metrikalarini yoqing (auto-instrumentation HTTP metrikalari va bitta o'z counter'ingiz, masalan `shop.checkouts`). Collector'da `metrics` pipeline'ini Prometheus'ga ulang. Prometheus'da yangi seriyalarni toping: nomi, `job`, `instance` qanday shakllangan?

7. **Names changed.** 1-darsdagi `prom-client`/`client_golang` metrikalari va OTel metrikalarini yonma-yon solishtiring: nom, label'lar, bucket chegaralari, birlik. 1-darsdagi p95 so'rovini OTel metrikalari uchun qayta yozing. Eski dashboard va alert'lardan qaysilari buzilardi? Migratsiya rejasini 4–5 qadamda yozing.

8. **Resource attributes as labels.** `target_info` seriyasini ko'rsating. `service.version` ni ilovada belgilang va u metrikada label emasligini ko'rsating. `otlp.promote_resource_attributes` bilan label'ga ko'taring. Keyin `service.instance.id` ni ham ko'tarib, ilovani 5 marta restart qiling: series soni nima bo'ldi?

9. **No up metric.** `api` ni to'xtating. OTLP orqali kelayotgan metrikalar bilan nima bo'ladi, `up` bormi? 3-darsdagi `InstanceDown` alert'i bu servisni ushlaydimi? Push modelida "servis o'ldi"ni aniqlashning ikki usulini taklif qiling va bittasini amalga oshiring.

10. **OTLP logs to Loki.** Ilova log'larini OTel orqali ham yuboring (Node.js: logger instrumentation'i va `OTEL_LOGS_EXPORTER`, Go: slog bridge) va Collector'da `logs` pipeline'ini Loki'ning OTLP endpoint'iga ulang. Loki'da bu log'lar qanday label'lar bilan paydo bo'ldi, `trace_id` qayerda (label, structured metadata yoki matn)? LogQL bilan bitta trace'ning log'larini toping.

11. **Stdout or OTLP logs.** Hozir log'lar ikki yo'ldan kelyapti (Alloy orqali stdout va OTLP). Loki'da dublikatni ko'rsating. Ikki yo'lni solishtiring: ilova boshlanishidagi crash log'i, Collector o'lgan payt, `docker logs`, tilingiz SDK'sida logs holati. Bittasini tanlab, ikkinchisini o'chiring va qarorni asoslang.

12. **Span metrics connector.** Collector'da `spanmetrics` connector bilan trace'lardan RED metrikalari chiqaring va Prometheus'ga yuboring. Tempo metrics-generator (5-dars) bilan bir xil ishni ikki joyda qilmaslik uchun bittasini qoldiring. Connector pipeline'da qanday ulanishini (qaysi pipeline'da exporter, qaysisida receiver) chizib ko'rsating.

### C. Sampling va chidamlilik

13. **Tail sampling.** Ilovalarda head sampling'ni 100% ga qaytaring va Collector'da `tail_sampling` yoqing: xatoli va 500 ms dan sekin trace'lar to'liq, qolgani 10%. 500 ta so'rovdan keyin Tempo'da nechta trace qoldi, ular orasida xatolilar ulushi qancha? Span metrikalari sampling'dan oldin hisoblanayotganini tekshiring (pipeline'lar tartibi).

14. **Backend down.** Tempo'ni 2 daqiqaga to'xtating. Collector log'i va `otelcol_exporter_send_failed_*`, navbat metrikalarida nima ko'rinadi? Tempo qaytgach trace'lar yetib keldimi? Keyin Collector'ning o'zini to'xtating: ilova so'rovlarga javob berishda davom etadimi, ilova log'ida nima bor?

15. **Watch the Collector.** Collector ichki metrikalarini Prometheus'da scrape qiling. Dashboard paneli qo'shing: signal bo'yicha qabul qilingan va yuborilgan birliklar tezligi, yuborish xatolari, navbat. "Collector telemetriya yo'qotyapti" alert qoidasini yozing va 14-vazifadagi usul bilan sinang.

### D. Mini-loyiha

16. **Stack as code.** `observability/stack/` ni yakuniy holatga keltiring: bitta `compose.yaml`, hamma image aniq versiyada, healthcheck'lar va `depends_on` shartlari, og'ir servislar profillarda, secret'lar `.env` va fayllarda (repoda yo'q), har servisga xotira limiti. `docker compose down -v` dan keyin bitta `docker compose up -d` bilan hammasi ko'tarilsin. `stack/README.md` da arxitektura sxemasi: har signal ilovadan backend'gacha qaysi yo'ldan boradi, portlar.

17. **Dashboards and alerts.** Provisioning'dan keladigan to'plamni yakunlang: servis RED dashboard'i (exemplar, log paneli, flame graph paneli, deploy annotation'lari bilan), USE dashboard'i, Collector dashboard'i; alert'lar: burn rate, latency, `InstanceDown` yoki uning push ekvivalenti, Watchdog, Collector yo'qotishi. Har alert'da runbook havolasi. Hammasi tanlagan metrika nomlaringiz (eski yoki OTel) bilan izchil bo'lsin.

18. **Fault injection.** Ilovaga boshqariladigan nosozliklar qo'shing (env yoki ichki admin endpoint orqali yoqiladi): `inventory` da ma'lum mahsulotlar uchun CPU'ni yeydigan sekin kod yo'li, va `api` da `inventory` ga qisqa timeout (sekinlik xatoga aylanadi). Nosozlik yoqilganda nima bo'lishini oldindan taxmin qilib yozing: qaysi metrika, qaysi alert, qancha vaqtda.

19. **Simulated incident.** Nosozlikni yoqing va vaqtni belgilang. Faqat observability vositalari bilan (kodga qaramasdan) tekshiring: alert xabari → RED/USE dashboard → error log'lar → trace → profil. Har qadamda ishlatilgan so'rovni (PromQL, LogQL, TraceQL), ko'rgan narsangizni va keyingi qadamga nima olib o'tganingizni yozing. Aniqlashgacha (alert kelguncha) va sababni topguncha ketgan vaqtni o'lchang.

20. **Postmortem.** `postmortem.md` yozing (blameless): xulosa, ta'sir (qancha so'rov, error budget'ning qancha qismi), vaqt chizig'i, asosiy sabab, aniqlash qanday ishladi va qayerda sekinlashdi, nima yaxshi ishladi, harakatlar ro'yxati (egasi va muddati bilan). Kamida bitta harakat observability'ning o'ziga tegishli bo'lsin (yetishmagan panel, bog'lanish, alert yoki runbook).

21. **Close the gap.** Postmortem'dagi observability harakatlaridan kamida ikkitasini amalga oshiring. Nosozlikni tuzating, keyin uni qayta yoqib tekshiruvni takrorlang: sababgacha yetish vaqti qanchaga qisqardi? Yakunda butun stack'ni tozalang va `docker volume ls`, `docker ps -a` chiqishini yozing.

### Topshirish

Tayyor bo'lgach:
1. `docker compose config -q`, Collector `validate`, `promtool check config`, `promtool check rules`, `amtool check-config` toza.
2. `make check` toza; `.env`, token'lar, volume ma'lumotlari repoda yo'q.
3. `stack/README.md` (arxitektura) va `postmortem.md` yozilgan.
4. Butun modul tozalangan: `docker compose --profile "*" down -v`, stack'dan konteyner va volume qolmagan.
5. Menga xabar bering: stack'ni toza holatdan ko'tarib, incident ssenariysini birga ko'rib chiqamiz.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- OpenTelemetry nima va nima emas? API bilan SDK nima uchun ajratilgan?
- Collector ilova va backend orasida nima beradi, narxi nima?
- Receiver, processor, exporter va connector vazifalari qanday farq qiladi? Komponent e'lon qilingan, lekin ishlamayotgan bo'lsa birinchi gumon nima?
- `memory_limiter` va `batch` pipeline'ning qayerida turadi va nima uchun?
- Resource attribute nima, u Prometheus va Loki'da nimaga aylanadi?
- Semantic conventions qanday muammoni hal qiladi va migratsiyada qanday muammo tug'diradi?
- OTLP push metrikalarida `up` yo'qligi nimani o'zgartiradi?
- Profiles signali OpenTelemetry'da hozir qanday holatda?
- Alert'dan funksiyagacha bo'lgan zanjirda har signal qaysi savolga javob beradi va ular nima orqali bog'lanadi?
