# 1-dars: Prometheus bilan metrics

Maqsad: metrikalar asosidagi monitoringni mexanizm darajasida tushunish: Prometheus target'lardan ma'lumotni qanday tortib oladi (pull), time series va label nima, to'rt metrika turi qachon ishlatiladi, ilovaga metrika qanday qo'shiladi va PromQL bilan undan rate, error ratio va percentile qanday hisoblanadi. Bu dars modulning poydevori: 2-darsda shu so'rovlar Grafana panellariga, 3-darsda alert qoidalariga aylanadi, 5-darsda exemplar orqali trace'larga bog'lanadi. Docker modulidagi Compose bilimi bu yerda to'liq ishlatiladi.

Taxminiy vaqt: 4 kun (siz uchun). Diqqatni quyidagilarga qarating: counter ustida nima uchun doim `rate()` ishlatilishi, histogram bucket'lari va `histogram_quantile` qanday ishlashi, label cardinality, `rate` oynasi va scrape interval nisbati, agregatsiyada `by`/`without`. Config sintaksisi oson, PromQL'ga ko'proq vaqt ajrating.

## Laboratoriya

Hammasi ish mashinasidagi Docker Compose'da. Stack papkasi `observability/stack/` (reja, "Laboratoriya" bo'limi), uni shu darsda yaratasiz va keyingi darslarda kengaytirasiz. Ish mashinasiga hech narsa o'rnatilmaydi: `promtool` Prometheus image'i ichida bor.

```
mkdir -p observability/stack/{app,prometheus}
cd observability/stack
docker compose up -d
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose down        # end of session, volumes stay
```

Image versiyalarini release sahifalaridan oling va aniq tag yozing (`latest` emas): https://github.com/prometheus/prometheus/releases , https://github.com/prometheus/node_exporter/releases , https://github.com/google/cadvisor/releases . Bu dars Prometheus 3.x ga yozilgan; `docker compose exec prometheus prometheus --version` bilan tekshiring. Portlar: Prometheus `9090`, namuna ilova `8000`, node_exporter `9100`, cAdvisor `8080`.

---

## 1. Monitoring modeli

### Pull va push
Prometheus har `scrape_interval` da target'ning HTTP endpoint'iga (`/metrics`) o'zi so'rov yuboradi va javobdagi barcha qiymatlarni o'z vaqt belgisi bilan saqlaydi. Ilova hech qayerga hech narsa yubormaydi, faqat joriy holatini ko'rsatib turadi.

| | Pull (Prometheus) | Push (StatsD, OTLP) |
|---|---|---|
| Target ro'yxati | monitoring tizimida (service discovery) | har ilova manzilni biladi |
| Target o'ldi | darhol ko'rinadi: `up == 0` | "jim qoldi"ni "o'ldi"dan ajratish qiyin |
| Qisqa umrli job | scrape'ga ulgurmaydi, Pushgateway kerak | tabiiy |
| Firewall/NAT ortida | Prometheus target'ga yeta olishi shart | ilova tashqariga chiqa olsa yetadi |

Prometheus 3.x OTLP orqali push qabul qilishni ham biladi (`--web.enable-otlp-receiver`), 7-darsda ishlatamiz.

### Arxitektura
Bitta binary: scrape, lokal TSDB (time series database), PromQL engine, qoidalarni hisoblash (rule evaluation) va web UI. Alert yuborish alohida komponent: Alertmanager (3-dars). Prometheus ataylab klastersiz: har instans mustaqil, HA uchun ikkita bir xil instans parallel ishlatiladi. Uzoq muddatli saqlash va global ko'rinish uchun `remote_write` orqali Thanos, Mimir yoki VictoriaMetrics ulanadi, bu moduldan tashqarida.

### Time series va label
Time series bu metrika nomi va label'lar to'plami bilan aniqlanadigan `(timestamp, float64)` juftliklari ketma-ketligi:

```
http_requests_total{method="GET", route="/products", status="200"}  1027
```

Nom ham aslida label: `__name__`. Label'larning har bir noyob kombinatsiyasi alohida series. Scrape paytida Prometheus har seriyaga `job` (scrape config nomi) va `instance` (`host:port`) label'larini qo'shadi.

**Tuzoq: cardinality.** Series soni label qiymatlari sonlarining ko'paytmasi. `user_id`, `email`, to'liq URL (`/products/8812`), `trace_id` kabi cheksiz qiymatli label har so'rovda yangi series yaratadi, xotira tugaydi va Prometheus OOM bo'ladi. Label qiymati cheklangan to'plamdan bo'lishi shart: `route="/products/:id"`, URL emas. Yuqori cardinality'li ma'lumot joyi log va trace.

## 2. Metrika turlari

| Tur | Ma'nosi | Misol | So'rovda |
|-----|---------|-------|----------|
| Counter | faqat o'sadi, restart'da 0 ga tushadi | `http_requests_total` | doim `rate()` yoki `increase()` |
| Gauge | joriy qiymat, o'sadi va kamayadi | `node_memory_MemAvailable_bytes`, navbat uzunligi | to'g'ridan-to'g'ri, `avg_over_time` |
| Histogram | kuzatuvlarni bucket'larga sanaydi | `http_request_duration_seconds` | `histogram_quantile()` |
| Summary | quantile'ni client o'zi hisoblaydi | `go_gc_duration_seconds` | to'g'ridan-to'g'ri, agregatsiya qilib bo'lmaydi |

### Counter
Qiymatning o'zi ma'nosiz (jarayon qachon ishga tushganiga bog'liq), ma'no o'zgarish tezligida. `rate()` qiymat kamayganini ko'rsa buni restart deb tushunadi va tuzatadi (counter reset). Shuning uchun "joriy so'rovlar soni"ni gauge bilan, "jami so'rovlar"ni counter bilan o'lchang, counter'ni hech qachon qo'lda kamaytirmang.

### Histogram
Bitta histogram uch xil series beradi:

```
http_request_duration_seconds_bucket{le="0.1"}   240
http_request_duration_seconds_bucket{le="0.5"}   310
http_request_duration_seconds_bucket{le="+Inf"}  320
http_request_duration_seconds_sum                48.7
http_request_duration_seconds_count              320
```

Bucket'lar kumulyativ: `le="0.5"` 0.5 soniyadan tez barcha so'rovlarni sanaydi, `le="0.1"` dagilarni ham. `+Inf` bucket `_count` ga teng. Har bucket alohida counter, shuning uchun histogram'ni instanslar bo'yicha qo'shib (`sum by (le)`), keyin percentile hisoblash mumkin. Narxi: har label kombinatsiyasi uchun bucket soni + 2 ta series.

**Tuzoq: bucket chegaralari.** Percentile bucket ichida chiziqli interpolatsiya bilan taxmin qilinadi. SLO chegarangiz 300 ms bo'lsa va bucket'lar `0.1, 1, 10` bo'lsa, p95 uchun javob juda qo'pol bo'ladi. Chegaralarni kutilgan latency va SLO atrofida zich qo'ying.

Native histogram (bucket'lar avtomatik, bitta series) Prometheus 3.8 dan barqaror, lekin scrape'da alohida yoqiladi (`scrape_native_histograms`). Bu darsda klassik histogram ishlatamiz, chunki ekotizimning katta qismi hali shunda.

### Summary va histogram
Summary quantile'ni ilova ichida hisoblaydi (`{quantile="0.99"}`). Uni instanslar bo'yicha o'rtacha qilish matematik jihatdan noto'g'ri: ikki serverning p99 lari o'rtachasi umumiy p99 emas. Bir nechta replika bo'ladigan servisda histogram tanlang.

## 3. Exposition format

`/metrics` oddiy matn. Har metrika oldidan `# HELP` va `# TYPE`:

```
# HELP http_requests_total Total HTTP requests.
# TYPE http_requests_total counter
http_requests_total{method="GET",route="/products",status="200"} 1027
```

Nomlash qoidalari: `snake_case`, birlik nom oxirida va bazaviy birlikda (`_seconds`, `_bytes`, millisekund emas), counter `_total` bilan tugaydi, prefiks ilova yoki sohani bildiradi (`http_`, `node_`, `shop_`). OpenMetrics shu formatning standartlashgan davomi, exemplar'lar shu formatda uzatiladi (5-dars).

## 4. prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - /etc/prometheus/rules/*.yml
scrape_configs:
  - job_name: api
    static_configs:
      - targets: ["api:8000"]
        labels: { env: lab }
```

- `scrape_interval` default 1m, amalda 15s–60s. `metrics_path` default `/metrics`, `scheme` default `http`.
- `static_configs` qo'lda yozilgan ro'yxat. Production'da service discovery (`kubernetes_sd_configs`, `docker_sd_configs`, `file_sd_configs`, `dns_sd_configs`) ishlatiladi.
- `relabel_configs` scrape'dan oldin target label'larini, `metric_relabel_configs` scrape'dan keyin har series'ni o'zgartiradi yoki tashlab yuboradi (`action: drop`). Ikkinchisi keraksiz yoki yuqori cardinality'li metrikalarni kesish quroli.
- Compose ichida target manzili servis nomi (`api:8000`), `localhost` emas: `localhost` Prometheus konteynerining o'zi.
- Config'ni tekshirish: `promtool check config`. Qayta yuklash: `SIGHUP` (`docker compose kill -s SIGHUP prometheus`) yoki `--web.enable-lifecycle` flag'i bilan `POST /-/reload`.

Har scrape avtomatik `up` (1 yoki 0), `scrape_duration_seconds`, `scrape_samples_scraped` series'larini yaratadi. UI'da Status → Target health sahifasi har target holati va oxirgi xatosini ko'rsatadi.

### Saqlash va retention
Ma'lumot lokal diskda (`/prometheus`), 2 soatlik bloklarga yoziladi, avval WAL'ga. Default retention 15 kun. Flag'lar: `--storage.tsdb.retention.time=30d`, `--storage.tsdb.retention.size=10GB` (qaysi biri birinchi to'lsa). Volume ulanmasa konteyner o'chganda tarix yo'qoladi. Disk hajmi taxminan `series soni × scrape'lar soni × 1–2 bayt`.

## 5. Exporter'lar

Exporter bu Prometheus formatini bilmaydigan tizim metrikalarini `/metrics` ga tarjima qiladigan jarayon.

| Exporter | Nima beradi | Asosiy metrikalar |
|----------|-------------|-------------------|
| node_exporter | host: CPU, xotira, disk, tarmoq, filesystem | `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_avail_bytes` |
| cAdvisor | har konteyner uchun cgroup statistikasi | `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` |
| ilova o'zi | biznes va HTTP metrikalari | siz yozasiz |

node_exporter host'ni ko'rishi uchun konteynerga host fayl tizimi faqat o'qish uchun beriladi (`-v /:/host:ro,rslave`, `--path.rootfs=/host`). Tarmoq va jarayon statistikasi to'liq bo'lishi uchun rasmiy tavsiya `network_mode: host` va `pid: host`; u holda Prometheus unga servis nomi bilan emas, host manzili bilan yetadi. cAdvisor image'i endi `ghcr.io/google/cadvisor` da (0.53 dan oldingi versiyalar `gcr.io/cadvisor/cadvisor` da edi), mount'lar ro'yxati README'da. U `privileged` rejimda ishlaydi: laboratoriyada maqbul, production'da ongli qaror.

## 6. Ilovani instrumentatsiya qilish

Client library (Node.js: `prom-client`, Go: `github.com/prometheus/client_golang`) registry yuritadi: siz metrika obyektini yaratasiz, kod ichida `inc()`/`observe()` chaqirasiz, `/metrics` handler registry'ni matnga aylantiradi.

```js
const client = require('prom-client');
client.collectDefaultMetrics();
const duration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration.',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5],
});
```

Go'da ekvivalent: `promauto.NewHistogramVec(prometheus.HistogramOpts{...}, []string{"method","route","status"})` va `promhttp.Handler()`. Default collector'lar runtime metrikalarini beradi: event loop lag, heap, GC (Node.js), goroutine soni, GC (Go).

Qoidalar: o'lchash middleware'da bir joyda, `route` label'i shablon bo'lsin (`/products/:id`), 404 lar uchun bitta umumiy qiymat (aks holda skaner botlar cardinality'ni portlatadi), `/metrics` va `/healthz` ni o'lchamaslik odat.

## 7. PromQL

### Selector'lar va ma'lumot turlari
- Instant vector: `http_requests_total{route="/checkout", status=~"5.."}`. Matcher'lar: `=`, `!=`, `=~`, `!~` (regex to'liq mos kelishi kerak, RE2).
- Range vector: `http_requests_total[5m]`, har seriya uchun oxirgi 5 daqiqadagi barcha nuqtalar. Grafikka chizib bo'lmaydi, funksiyaga beriladi.
- `offset 1h` o'tmishdagi qiymat, `@` aniq vaqt.

### rate, irate, increase
`rate(x[5m])` oynadagi birinchi va oxirgi nuqta orasidagi soniyalik o'rtacha o'sish (reset'lar tuzatilgan). `increase` shu qiymat × oyna uzunligi, ekstrapolatsiya sabab butun son chiqmasligi normal. `irate` faqat oxirgi ikki nuqtaga qaraydi: keskin, tez o'zgaruvchan grafik uchun, alert uchun emas.

**Tuzoq: oyna juda tor.** `rate` ga oynada kamida 2 nuqta kerak. Scrape interval 15s bo'lsa `[15s]` bo'sh natija beradi. Amaliy qoida: oyna scrape interval'dan kamida 4 marta katta.

### Agregatsiya
```
sum by (route) (rate(http_requests_total[5m]))
sum without (instance) (rate(http_requests_total[5m]))
topk(3, sum by (route) (rate(http_requests_total[5m])))
```
Tartib muhim: avval `rate`, keyin `sum`. `rate(sum(...))` da bitta instans restart bo'lsa reset yig'indida ko'rinmay qoladi va natija buziladi. Operatorlar: `sum`, `avg`, `min`, `max`, `count`, `topk`, `bottomk`, `quantile`, `count_values`.

### Binary operatorlar va vector matching
Ikki vector label'lari to'liq mos seriyalar bo'yicha juftlanadi. Error ratio:

```
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))
```
Label to'plamlari farq qilsa `on(...)` / `ignoring(...)`, bir tomonda ko'p seriya bo'lsa `group_left` kerak. Natija bo'sh chiqsa birinchi gumon: label'lar mos kelmayapti.

### histogram_quantile
```
histogram_quantile(0.95,
  sum by (le, route) (rate(http_request_duration_seconds_bucket[5m])))
```
`le` label'i agregatsiyada qolishi shart, aks holda funksiya bucket'larni ko'ra olmaydi. O'rtacha latency: `rate(..._sum[5m]) / rate(..._count[5m])`, lekin o'rtacha dumni (tail) yashiradi, shuning uchun p95/p99 ga qarang.

### Recording rules
Og'ir yoki ko'p ishlatiladigan ifodani oldindan hisoblab yangi seriya sifatida saqlaydi. Dashboard tezlashadi, alert ifodalari qisqaradi. Nomlash: `level:metric:operations`.

```yaml
groups:
  - name: api_red
    interval: 30s
    rules:
      - record: route:http_requests:rate5m
        expr: sum by (route) (rate(http_requests_total[5m]))
```
Tekshirish: `promtool check rules`, unit test: `promtool test rules`.

## 8. RED va USE

| Metod | Kim uchun | Nimani o'lchaydi |
|-------|-----------|-------------------|
| RED | so'rovga xizmat qiladigan servis | **R**ate (so'rov/s), **E**rrors (xato ulushi), **D**uration (latency taqsimoti) |
| USE | resurs: CPU, xotira, disk, tarmoq | **U**tilization (band foizi), **S**aturation (navbat, kutish), **E**rrors |

RED foydalanuvchi nimani his qilayotganini ko'rsatadi (symptom), USE nima uchun ekanini (cause). Google SRE'ning "four golden signals" i (latency, traffic, errors, saturation) shu ikkisining birlashmasi. Dashboard va alert'lar RED'dan boshlanadi, USE diagnostika uchun.

Cardinality'ni o'lchash: `count({__name__=~".+"})` (jami series), `topk(10, count by (__name__) ({__name__=~".+"}))`, UI'da Status → TSDB status, CLI'da `promtool tsdb analyze`.

## Tuzoqlar

- Yuqori cardinality'li label (`user_id`, to'liq URL, `trace_id`): series soni portlaydi, Prometheus OOM bo'ladi. Label qiymatlari cheklangan to'plam bo'lsin.
- Counter'ni `rate()` siz grafikka chizish yoki alert qilish: restart'da 0 ga tushadi, qiymat ma'nosiz.
- `rate(sum(...))`: reset'lar yo'qoladi. Doim `sum(rate(...))`.
- `rate` oynasi scrape interval'dan kichik yoki unga teng: bo'sh natija yoki uzuq grafik.
- `histogram_quantile` da `le` ni agregatsiyadan tushirib qoldirish, yoki bucket'larni SLO chegarasidan uzoq qo'yish.
- Summary quantile'larini instanslar bo'yicha `avg` qilish: natija hech narsani anglatmaydi.
- `/metrics` ni internetga ochiq qoldirish: ichki tuzilma, versiyalar va trafik hajmi ko'rinadi. Prometheus UI'da autentifikatsiya default yo'q.
- Volume'siz Prometheus: konteyner qayta yaratilganda butun tarix yo'qoladi.
- `latest` tag: Prometheus 2 → 3 kabi major o'tishlarda config va UI o'zgaradi, stack kutilmaganda buziladi.
- O'rtacha latency'ga qarab xulosa qilish: 1% so'rov 10 soniya bo'lsa o'rtacha buni ko'rsatmaydi.

## Manbalar

- https://prometheus.io/docs/introduction/overview/ – arxitektura va tushunchalar
- https://prometheus.io/docs/concepts/metric_types/ – metrika turlari (majburiy)
- https://prometheus.io/docs/practices/naming/ – nomlash va label qoidalari
- https://prometheus.io/docs/practices/histograms/ – histogram va summary taqqosi
- https://prometheus.io/docs/prometheus/latest/querying/basics/ – PromQL asoslari, funksiyalar yonidagi sahifalarda
- https://prometheus.io/docs/practices/rules/ – recording rule nomlash
- https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/ – `promtool test rules`
- https://prometheus.io/docs/specs/native_histograms/ – native histogram holati
- https://github.com/prometheus/node_exporter – node_exporter, Docker'da ishga tushirish
- https://github.com/google/cadvisor – cAdvisor README
- https://github.com/siimon/prom-client – Node.js client library
- https://pkg.go.dev/github.com/prometheus/client_golang/prometheus – Go client library
- https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/ – RED metodi
- https://www.brendangregg.com/usemethod.html – USE metodi
- https://sre.google/sre-book/monitoring-distributed-systems/ – four golden signals

---

## Vazifalar

Javoblar `observability/01-prometheus/README.md` da (`make new m=observability n=01 name=prometheus`), har vazifa uchun `## N. Title` sarlavhasi ostida: ishlatilgan buyruq yoki PromQL, natijaning muhim qismi va o'z so'zingiz bilan izoh. Stack fayllari (`compose.yaml`, `prometheus/prometheus.yml`, `prometheus/rules/*.yml`, `app/`) `observability/stack/` da turadi va keyingi darslarda davom ettiriladi.

### A. Birinchi scrape

1. **Prometheus alone.** `compose.yaml` ga faqat `prometheus` servisini yozing: aniq versiya tag'i, `prometheus.yml` bind mount, ma'lumot uchun named volume, `9090` port. Config'da Prometheus o'zini scrape qilsin. UI'da Status → Target health sahifasida target `UP` ekanini ko'rsating va `up` so'rovi natijasidagi `job` va `instance` label'lari qayerdan kelganini izohlang.

2. **Read the exposition format.** `curl -s localhost:9090/metrics` chiqishidan bittadan counter, gauge, histogram va summary toping. Har biri uchun `# TYPE` qatorini va 2–3 qator namunani yozing. Histogram'da `_bucket`, `_sum`, `_count` qanday bog'langanini shu real raqamlar ustida tushuntiring.

3. **Break the target.** `scrape_configs` ga mavjud bo'lmagan target (`nohost:9999`) qo'shing, config'ni qayta yuklang. Target health sahifasidagi xato matnini va `up{job="..."}` qiymatini yozing. Keyin `prometheus.yml` da YAML xatosi qiling va `promtool check config` nima deyishini ko'rsating. Ikkalasini tuzating.

4. **Reload without restart.** Config'ni ikki usulda qayta yuklang: `SIGHUP` va `--web.enable-lifecycle` bilan `/-/reload`. Har birida Prometheus log'ida nima chiqishini yozing. Nima uchun `docker compose restart` yomonroq variant ekanini izohlang.

### B. Exporter'lar

5. **node_exporter.** `node-exporter` servisini qo'shing (host fayl tizimi faqat o'qish uchun). Uni scrape qiling va PromQL bilan hisoblang: CPU band foizi (`mode="idle"` orqali), bo'sh xotira foizi, `/` filesystem'dagi bo'sh joy foizi. Natijalarni `top`, `free -m`, `df -h` bilan solishtiring.

6. **Host network trade-off.** node_exporter'ni bir marta oddiy bridge tarmoqda, bir marta `network_mode: host` bilan ishga tushiring. `node_network_receive_bytes_total` da qaysi interfeyslar ko'rinishini ikkala holatda yozing va farqni tushuntiring. Host rejimida Prometheus unga qanday manzil bilan yetdi?

7. **cAdvisor.** `cadvisor` servisini README'dagi mount'lar bilan qo'shing. Har konteyner uchun CPU ishlatilishi (`rate` bilan, yadro ulushida) va xotirani (`container_memory_working_set_bytes`) `name` label'i bo'yicha chiqaring. `docker stats` bilan solishtiring. cAdvisor nechta series berayotganini `count by (job) ({__name__=~".+"})` bilan o'lchang.

8. **Drop with relabeling.** `metric_relabel_configs` bilan cAdvisor'dan keraksiz metrikalar oilasini (masalan `container_tasks_state`) tashlab yuboring. Oldin va keyin series sonini yozing. `relabel_configs` va `metric_relabel_configs` farqini o'z so'zingiz bilan tushuntiring.

### C. Ilova metrikalari

9. **Sample app.** `stack/app/` da kichik HTTP servis yozing (Node.js yoki Go, tanlov sizniki), `Dockerfile` bilan: `GET /products` (tasodifiy 20–300 ms kechikish), `GET /products/:id`, `GET /checkout` (taxminan 5% holatda `500`), `GET /healthz`. Hozircha metrikasiz. Uni `api` nomi bilan compose'ga qo'shing (`8000` port).

10. **Instrument with a client library.** Ilovaga client library qo'shing: default runtime metrikalari, `http_requests_total` counter (`method`, `route`, `status`), `http_request_duration_seconds` histogram (bucket'larni o'zingiz asoslab tanlang), `http_requests_in_flight` gauge va `/metrics` endpoint. Prometheus'da `api` job'ini qo'shing. `curl localhost:8000/metrics` dan o'z metrikalaringizni ko'rsating.

11. **Load generator.** Compose'ga `loadgen` servisini qo'shing: `curlimages/curl` image'ida cheksiz shell sikli uchala endpoint'ga turli chastotada so'rov yuborsin. 5 daqiqa ishlatib, `http_requests_total` ning xom grafigi va `rate(http_requests_total[1m])` grafigini solishtiring. `api` ni restart qiling: ikkala grafikda nima bo'ldi?

12. **Cardinality bomb.** Ataylab xato qiling: `route` label'iga shablon o'rniga haqiqiy yo'lni (`/products/123`) yozing va loadgen'da tasodifiy `id` yuboring. 3 daqiqadan keyin `count(http_requests_total)` va Status → TSDB status sahifasidagi eng katta metrikalarni yozing. Tuzating. Eski series'lar qachon yo'qolishini kuzating va sababini izohlang.

### D. PromQL

13. **Rate window.** `rate(http_requests_total[15s])`, `[1m]`, `[5m]` va `irate(...[1m])` ni bitta grafikda solishtiring (scrape interval 15s). Qaysi biri bo'sh, qaysi biri silliq, qaysi biri keskin? Sababini mexanizm orqali tushuntiring.

14. **RED queries.** `api` uchun uchta so'rov yozing: route bo'yicha so'rov/s, umumiy xato ulushi foizda (5xx), route bo'yicha p50/p95/p99 latency. p95 natijasini ilovadagi kechikish diapazoni bilan solishtiring: mantiqqa to'g'ri keladimi?

15. **Wrong aggregation.** `histogram_quantile` so'rovini uch xil buzing va natijani yozing: `le` ni `by` dan olib tashlang; `rate` siz yozing; `sum` va `rate` o'rnini almashtiring. Har biri nima uchun noto'g'ri?

16. **Bucket resolution.** Histogram bucket'larini ataylab qo'pol qiling (`[1, 10]`), 5 daqiqa yuklama bering va p95 ni yozing. Keyin asl bucket'larga qayting. Farqni interpolatsiya orqali tushuntiring.

17. **USE queries.** node_exporter va cAdvisor metrikalaridan host CPU va xotira uchun utilization va saturation (`node_load1` ni yadrolar soniga nisbati, `node_pressure_*` mavjud bo'lsa) so'rovlarini yozing. `api` konteyneri uchun CPU utilization'ni yozing.

18. **Vector matching.** Route bo'yicha xato ulushini hisoblang (har route uchun alohida foiz). Xatosi yo'q route'lar natijadan tushib qolishini ko'rsating va buni `or` yoki boshqa usul bilan qanday hal qilishni toping.

### E. Rules va saqlash

19. **Recording rules.** `prometheus/rules/api.yml` da RED uchun uchta recording rule yozing (nomlash qoidasi bo'yicha). `promtool check rules` toza o'tsin. UI'ning Rules sahifasida ular ko'rinishini va yangi seriyalar so'rovga javob berishini ko'rsating.

20. **Rule unit test.** Bitta recording rule uchun `promtool test rules` test faylini yozing (`input_series` va kutilgan qiymat). Testni bir marta ataylab noto'g'ri kutilgan qiymat bilan yiqiting va xato chiqishini yozing.

21. **Retention and storage.** Retention'ni `--storage.tsdb.retention.time` bilan 7 kunga qo'ying. `prometheus_tsdb_head_series` va volume hajmini (`docker system df -v`) yozing. Hozirgi series soni va scrape interval bilan 7 kunlik disk hajmini taxminan hisoblang.

22. **Mini-project: metrics baseline.** Stack'ni toza holatga keltiring: `docker compose down -v` dan keyin bitta `docker compose up -d` bilan `prometheus`, `node-exporter`, `cadvisor`, `api`, `loadgen` ko'tarilsin, barcha target'lar `UP`, recording rule'lar ishlasin, barcha image'lar aniq versiyada, `api` da healthcheck bo'lsin. `README.md` ga stack sxemasini (kim kimni scrape qiladi, portlar) va RED/USE so'rovlari ro'yxatini yozing. Bu 2-darsning boshlang'ich nuqtasi.

### Topshirish

Tayyor bo'lgach:
1. `docker compose config -q` xatosiz, `promtool check config` va `promtool check rules` toza.
2. `make check` toza (YAML lint, Dockerfile lint, secret tekshiruvi).
3. `docker compose down` qilingan, `docker ps` da stack konteynerlari yo'q.
4. Menga xabar bering, `README.md` va stack fayllarini o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Pull modelida target o'lganini Prometheus qanday biladi va push modelida bu nima uchun qiyinroq?
- Time series nima bilan aniqlanadi? Label cardinality nima uchun xotira muammosiga aylanadi?
- Counter ustida nima uchun doim `rate()` ishlatiladi va `rate` restart'ni qanday yengadi?
- Histogram bucket'lari nima uchun kumulyativ va `histogram_quantile` aniq qiymat emas, taxmin berishining sababi nima?
- Histogram va summary'dan qaysi birini bir nechta replikali servisda tanlaysiz va nima uchun?
- `sum(rate(x[5m]))` va `rate(sum(x)[5m:])` orasidagi farq nima?
- RED va USE qaysi savollarga javob beradi, alert'ni qaysi biridan boshlaysiz?
- Recording rule qachon kerak, qachon ortiqcha?
- `relabel_configs` va `metric_relabel_configs` qaysi bosqichda ishlaydi?
