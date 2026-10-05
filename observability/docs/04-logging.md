# 4-dars: Logging

Maqsad: log'larni har konteynerga `docker logs` bilan kirib o'qishdan markazlashgan, so'rov yoziladigan tizimga o'tkazish. Metrika "xato ulushi 8%" deydi, log "qaysi xato, qaysi so'rovda, qanday matn bilan" deydi. Ikki xil yondashuvni mexanizm darajasida ko'rasiz: Loki (faqat label'lar indekslanadi, matn siqilgan holda saqlanadi) va Elasticsearch (har so'z indekslanadi). Asosiy amaliyot Loki bilan, chunki u 2-darsdagi Grafana va 1-darsdagi label modeli bilan bir xil tilda gaplashadi; Elasticsearch va Kibana bilan kichikroq tanishuv bo'ladi. 5-darsda log'larga `trace_id` qo'shilib trace'lar bilan bog'lanadi.

Taxminiy vaqt: 3 kun (siz uchun). Structured logging sizga pino/winston'dan tanish. Diqqatni quyidagilarga qarating: Loki'da label va matn filtri orasidagi chegara (nima label bo'ladi, nima yo'q), LogQL pipeline bosqichlari tartibi, log'dan metrika chiqarish, inverted index nima uchun tez va nima uchun qimmat, retention.

## Laboratoriya

`observability/stack/` ustida. Yangi servislar: `loki` (port `3100`), `alloy` (UI port `12345`). Elasticsearch va Kibana `logs-es` Compose profili ostida, faqat D guruh vazifalarida yoqiladi. Versiyalar: https://github.com/grafana/loki/releases , https://github.com/grafana/alloy/releases , Elastic uchun https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic .

```
mkdir -p loki alloy
docker compose up -d loki alloy
curl -s localhost:3100/ready
docker compose --profile logs-es up -d      # only for group D
docker compose --profile logs-es down       # stop ES + Kibana when done
```

Alloy konteyner log'larini o'qish uchun `/var/run/docker.sock` ni faqat o'qish uchun mount qiladi. Bu ish mashinasini o'zgartirmaydi, lekin socket'ga kirish amalda root huquqi: bu image'ni faqat rasmiy manbadan, aniq versiya bilan oling. Elasticsearch kamida 1 GB RAM oladi, `docker stats` bilan kuzating. Tozalash: `docker compose --profile logs-es down`, modul oxirida volume'lar bilan.

---

## 1. Log nima bo'lishi kerak

### Structured logging
Matnli log (`User 42 failed to pay: timeout`) odam uchun qulay, mashina uchun regex talab qiladi. Structured log har yozuvni kalit-qiymatli obyekt qiladi, odatda bir qatorda JSON:

```json
{"time":"2026-10-05T10:15:03.120Z","level":"error","msg":"payment failed","route":"/checkout","status":500,"duration_ms":812,"request_id":"9f2c","err":"upstream timeout"}
```

Node.js'da `pino`, Go'da standart `log/slog` (`slog.NewJSONHandler`) shu formatni beradi. Qoidalar:

- Konteynerda log **stdout/stderr** ga yoziladi, faylga emas (docker moduli). Yig'ish, rotatsiya va jo'natish platformaning ishi.
- Har yozuvda: vaqt (UTC, RFC 3339), `level`, `msg` (o'zgarmas matn), kontekst maydonlari. O'zgaruvchi qiymat `msg` ichiga emas, alohida maydonga: `msg="payment failed"`, `user_id=42`. Shunda `msg` bo'yicha guruhlash mumkin.
- `request_id` (keyin `trace_id`) har so'rovning barcha log'larida bir xil: bitta so'rov tarixini yig'ish uchun.
- Parol, token, karta raqami, shaxsiy ma'lumot log'ga tushmaydi. Log'lar ko'p odamga ochiq va uzoq saqlanadi.

### Log level'lar
| Level | Ma'nosi | Production'da |
|-------|---------|---------------|
| `debug` | dasturchi uchun ichki tafsilot | o'chiq, vaqtincha yoqiladi |
| `info` | normal hodisa: so'rov tugadi, servis ishga tushdi | yoqiq |
| `warn` | kutilmagan, lekin ishlov berilgan: retry, fallback | yoqiq |
| `error` | operatsiya bajarilmadi, e'tibor kerak | yoqiq, hisoblanadi |

Level env orqali o'zgaradi (`LOG_LEVEL`), qayta build'siz. Foydalanuvchining noto'g'ri kiritishi (`400`) `error` emas: `error` soni alert manbai bo'ladi, uni shovqin bilan to'ldirmang.

### Yig'ish zanjiri
```
app stdout -> container runtime (json-file) -> collector (Alloy) -> storage (Loki / Elasticsearch) -> Grafana / Kibana
```
Collector har node'da ishlaydi, log'ga label qo'shadi (qaysi konteyner, qaysi servis), batch qilib yuboradi va storage vaqtincha yetib bo'lmasa qayta urinadi.

## 2. Loki

### G'oya
Loki log matnini indekslamaydi. Har log qatori **stream** ga tegishli, stream label'lar to'plami bilan aniqlanadi (xuddi Prometheus series kabi): `{service="api", env="lab"}`. Indeksda faqat label'lar va chunk'larga havolalar turadi; matnning o'zi siqilgan chunk'larda, object storage'da (S3, GCS, laboratoriyada lokal disk). So'rov ikki bosqichda: label selector kerakli stream va chunk'larni tanlaydi, keyin ular ochilib matn bo'yicha "grep" qilinadi.

Oqibati: yozish va saqlash arzon (indeks kichik), tor selector bilan so'rov tez, keng selector bilan katta oraliqdagi so'rov sekin (ko'p chunk o'qiladi).

### Arxitektura
| Komponent | Vazifasi |
|-----------|----------|
| Distributor | push qabul qiladi, tekshiradi, limitlarni qo'llaydi, ingester'larga tarqatadi |
| Ingester | stream'larni xotirada chunk'ga yig'adi, to'lganda storage'ga yozadi |
| Querier, query frontend | so'rovni bo'laklaydi, ingester va storage'dan o'qiydi |
| Compactor | indeksni ixchamlaydi, retention va o'chirishni bajaradi |
| Ruler | LogQL asosidagi alert va recording rule'lar |

Monolithic rejimda hammasi bitta jarayonda (laboratoriya va kichik hajm), katta hajmda komponentlar alohida masshtablanadi. Image ichida tayyor lokal config bor: `/etc/loki/local-config.yaml` (filesystem storage, bitta instans).

### Label'lar: eng muhim qaror
Label'lar kam va cheklangan qiymatli bo'ladi: `service`, `container`, `env`, `level`. Har noyob label kombinatsiyasi alohida stream, har stream alohida chunk'lar.

**Tuzoq: yuqori cardinality'li label.** `user_id`, `request_id`, `trace_id`, `path` label qilinsa millionlab mayda stream paydo bo'ladi: indeks shishadi, chunk'lar to'lmaydi, ingester xotirasi tugaydi, so'rovlar sekinlashadi. Bu qiymatlar log matnida (yoki structured metadata'da) qoladi va so'rov vaqtida filtrlanadi: `{service="api"} | json | user_id="42"`.

**Structured metadata**: stream'ni bo'lmaydigan, lekin qatorga biriktirilgan kalit-qiymat (`trace_id` uchun mos). Loki 3.x da default yoqiq, OTLP orqali kelgan log atributlari shu yerga tushadi (7-dars).

### Grafana Alloy bilan yig'ish
**Promtail endi yo'q**: Loki hujjatlariga ko'ra Promtail 2026-yil 2-martda end of life bo'ldi, yangilanish va qo'llab-quvvatlash to'xtagan, rivojlanish Grafana Alloy'da. Eski maqola va compose fayllarda Promtail ko'rsangiz, Alloy'ga o'tkazing (`alloy convert --source-format=promtail`).

Alloy config'i komponentlardan iborat, har biri chiqishini keyingisiga uzatadi:

```alloy
discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "default" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.containers.targets
  forward_to = [loki.write.local.receiver]
}

loki.write "local" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}
```

- `discovery.docker` konteynerlarni topadi va `__meta_docker_*` label'larini beradi (masalan `__meta_docker_container_name`, `__meta_docker_container_label_com_docker_compose_service`). `__` bilan boshlanadigan label'lar Loki'ga yuborilmaydi, ularni `discovery.relabel` bilan haqiqiy label'ga aylantirasiz (Prometheus `relabel_configs` bilan bir xil mantiq).
- `loki.process` qatorlarni qayta ishlaydi: `stage.json` maydon ajratadi, `stage.labels` uni label qiladi, `stage.drop` keraksizni tashlaydi.
- Alloy UI (`http://localhost:12345`) komponentlar grafigini va har birining holatini ko'rsatadi: log kelmayotgan bo'lsa birinchi qaraladigan joy.
- Ishga tushirish: `alloy run /etc/alloy/config.alloy --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data`. Formatlash: `alloy fmt`.

## 3. LogQL

So'rov stream selector'dan boshlanadi, keyin `|` bilan pipeline:

```
{service="api"} |= "error" != "healthz" | json | status >= 500 | line_format "{{.route}} {{.err}}"
```

| Bosqich | Sintaksis | Vazifasi |
|---------|-----------|----------|
| Stream selector | `{service="api", level=~"error\|warn"}` | majburiy, indeks orqali chunk tanlaydi |
| Line filter | `\|=`, `!=`, `\|~`, `!~` | matn bo'yicha (regex RE2), eng arzon filtr |
| Parser | `\| json`, `\| logfmt`, `\| pattern "<ip> - <_> ..."`, `\| regexp` | maydonlarni vaqtinchalik label'ga aylantiradi |
| Label filter | `\| status >= 500`, `\| duration > 200ms` | ajratilgan maydon bo'yicha |
| Format | `\| line_format`, `\| label_format`, `\| drop`, `\| keep` | chiqishni o'zgartiradi |

Tartib unumdorlikni belgilaydi: avval imkon qadar tor selector, keyin line filter (parser'dan oldin), keyin parser va label filter. Parse qilib bo'lmagan qatorlar `__error__` label'ini oladi, ularni `| __error__=""` bilan chiqarib tashlaysiz.

### Metric query'lar
Log'dan raqam chiqarish, natija Prometheus'dagi kabi vector:

```
sum by (level) (count_over_time({service="api"} [5m]))
sum(rate({service="api"} | json | status >= 500 [5m]))
quantile_over_time(0.95, {service="api"} | json | unwrap duration_ms [5m]) by (route)
```

`unwrap` maydonni son sifatida oladi. Bular dashboard paneli va alert bo'la oladi (Grafana Alerting yoki Loki ruler orqali). Lekin doimiy kuzatiladigan narsa uchun haqiqiy metrika arzonroq: har hisobda log'larni qayta o'qish qimmat.

## 4. Elasticsearch, ELK, OpenSearch

### Inverted index
Elasticsearch har hujjatni (JSON) analiz qiladi: `text` maydonlar so'zlarga bo'linadi (analyzer), har so'z uchun "qaysi hujjatlarda bor" ro'yxati yoziladi. Bu inverted index: kitob oxiridagi ko'rsatkich kabi. Qidiruv hujjatlarni o'qimasdan so'z bo'yicha ro'yxatni topadi, shuning uchun ixtiyoriy so'z bo'yicha terabaytlar ichida tez. Narxi: indeks xom ma'lumot hajmiga yaqin joy oladi, yozish CPU va RAM talab qiladi.

- **Mapping**: maydon turlari. `text` (analiz qilinadi, to'liq matnli qidiruv), `keyword` (aniq qiymat, agregatsiya va filtr), `date`, son turlari. Dynamic mapping birinchi ko'rgan qiymatiga qarab tur tanlaydi.
- **Index** va **shard**: indeks primary shard'larga bo'linadi (har biri alohida Lucene indeksi), har primary'ning replica'lari boshqa node'da. Shard soni parallellik va node'lar bo'yicha taqsimotni belgilaydi.
- Log'lar uchun vaqt bo'yicha indekslar yoki data stream, hayot sikli ILM bilan: hot → warm → cold → delete.

**Tuzoq: mapping explosion va tur ziddiyati.** Har xil servis `status` ni bir joyda son, boshqa joyda matn qilib yuborsa, ikkinchisining hujjatlari rad etiladi. Erkin JSON kalitlari (masalan foydalanuvchi kiritgan obyekt) minglab maydon yaratadi va klasterni sekinlashtiradi.

### Stack
```
Filebeat (har node'da) -> [Logstash: parse, enrich] -> Elasticsearch -> Kibana
```
Filebeat yengil jo'natuvchi, Logstash og'ir qayta ishlash (grok, filtrlar) uchun ixtiyoriy bo'g'in, Kibana UI (Discover, KQL so'rov tili, vizualizatsiya). Shu o'rinda Fluent Bit, Vector yoki OpenTelemetry Collector ham ishlatiladi. **OpenSearch** Elasticsearch 7.10 dan ajralgan ochiq fork (Apache 2.0), API'si katta qismda mos, UI'si OpenSearch Dashboards. Litsenziya yoki AWS muhiti sabab tanlanadi, tushunchalar bir xil.

## 5. Loki va Elasticsearch

| | Loki | Elasticsearch |
|---|---|---|
| Nima indekslanadi | faqat label'lar | har maydon, har so'z |
| Yozish narxi | past | yuqori (analiz, indeks) |
| Saqlash | siqilgan chunk'lar, object storage | indeks + ma'lumot, tez disk |
| "Shu servisning oxirgi soatdagi xatolari" | tez | tez |
| "30 kun ichida shu IP hamma servislarda" | sekin (ko'p chunk skaner) | tez |
| Agregatsiya va analitika | LogQL metric query'lar, cheklangan | kuchli (aggregations) |
| Operatsion murakkablik | pastroq | yuqori: shard, heap, mapping, ILM |
| Ekotizim | Grafana, Prometheus label'lari bilan bir xil | Kibana, SIEM, to'liq matnli qidiruv |

Tanlov: Grafana/Prometheus stack'i bor, log asosan incident paytida servis va vaqt bo'yicha qidiriladi, byudjet muhim: Loki. Log'lar ustida murakkab qidiruv va analitika, xavfsizlik tahlili (SIEM), log aslida mahsulotning bir qismi: Elasticsearch yoki OpenSearch.

### Retention va narx
Log hajmi trafikka proporsional va eng qimmat signal. Qoidalar: `debug` production'da o'chiq; shovqinli qatorlar (health check'lar) collector'da tashlanadi; retention muhit va turga qarab (masalan ilova log'lari 14–30 kun, audit log'lari talabga ko'ra uzoqroq). Loki'da retention default o'chiq (log'lar abadiy turadi): compactor'da `retention_enabled: true` va `limits_config.retention_period`, stream bo'yicha alohida muddat `retention_stream` bilan. Elasticsearch'da ILM delete fazasi.

## Tuzoqlar

- `request_id`, `user_id`, `trace_id` ni Loki label'i qilish: stream'lar portlaydi, Loki sekinlashadi yoki yiqiladi.
- Selector'siz yoki juda keng selector bilan uzoq oraliqda qidirish (`{env="prod"} |= "x"` 30 kun): hamma chunk o'qiladi. Avval servis va vaqtni toraytiring.
- Log'da secret va shaxsiy ma'lumot: log tizimi eng ko'p odam kira oladigan joy. Maskalash ilovada, collector'da emas (unda kech).
- Matnga yopishtirilgan o'zgaruvchilar (`"user 42 failed"`): guruhlab ham, hisoblab ham bo'lmaydi.
- Ko'p qatorli stack trace: har qator alohida yozuv bo'lib ketadi. JSON ichida bitta maydon qiling yoki collector'da multiline bosqich.
- Retention'siz Loki yoki ILM'siz Elasticsearch: disk to'ladi, log tizimi eng kerakli paytda yozishni to'xtatadi.
- Log'ni metrika o'rnida ishlatish: har dashboard yangilanishida gigabaytlar qayta o'qiladi. Doimiy raqam kerak bo'lsa metrika yozing.
- Elasticsearch'da xavfsizlikni o'chirib (`xpack.security.enabled=false`) tarmoqqa ochish: laboratoriya sozlamasi production'ga ko'chib qolmasin.
- Promtail yoki eski Docker Loki plugin asosidagi qo'llanmalardan nusxa olish: Promtail EOL, yangi narsa Alloy yoki OTel Collector bilan quriladi.
- Collector'siz, ilovadan to'g'ridan-to'g'ri log storage'ga yozish: storage o'lsa ilova bloklanadi yoki log yo'qoladi.

## Manbalar

- https://grafana.com/docs/loki/latest/get-started/architecture/ – Loki arxitekturasi
- https://grafana.com/docs/loki/latest/get-started/labels/ – label'lar va cardinality (majburiy)
- https://grafana.com/docs/loki/latest/query/ – LogQL
- https://grafana.com/docs/loki/latest/operations/storage/retention/ – retention
- https://grafana.com/docs/loki/latest/send-data/promtail/ – Promtail EOL e'loni
- https://grafana.com/docs/alloy/latest/ – Grafana Alloy
- https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/ – Docker log'larini yig'ish
- https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.relabel/ – relabeling
- https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic – Elasticsearch va Kibana Docker'da
- https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-filestream – Filebeat filestream input
- https://opensearch.org/docs/latest/ – OpenSearch
- https://12factor.net/logs – log'lar hodisalar oqimi sifatida
- https://getpino.io/ – pino (Node.js), https://pkg.go.dev/log/slog – slog (Go)

---

## Vazifalar

Javoblar `observability/04-logging/README.md` da (`make new m=observability n=04 name=logging`), har vazifa uchun `## N. Title` ostida: config yoki so'rov, natijaning muhim qismi, izoh. Stack fayllari (`loki/`, `alloy/config.alloy`, ilova o'zgarishlari) `observability/stack/` da.

### A. Structured logging

1. **Structured logs in the app.** `api` ilovasida log'larni JSON'ga o'tkazing (pino yoki slog): har so'rov uchun bitta `info` yozuv (`method`, `route`, `status`, `duration_ms`, `request_id`), 5xx uchun `error` yozuv (`err` maydoni bilan). `request_id` kiruvchi `X-Request-Id` header'idan olinsin yoki generatsiya qilinsin. `docker compose logs api` dan ikki qator namunani ko'rsating.

2. **Log levels.** `LOG_LEVEL` env'ini qo'shing. `debug` da qo'shimcha yozuvlar chiqsin, `warn` da `info` lar chiqmasin. 400 javoblarni qaysi level'da yozdingiz va nima uchun? Health check so'rovlarini log'dan chiqarib tashlang yoki `debug` ga tushiring.

3. **Secrets in logs.** Ilovaga `Authorization` header'li so'rov yuboring va butun header'larni log qiladigan qator yozing. Log'da token ko'rinishini ko'rsating. Keyin logger'ning redaction imkoniyati yoki o'z kodingiz bilan maskalang. Nima uchun buni collector'da emas, ilovada qilish kerak?

### B. Loki va Alloy

4. **Loki service.** `loki` servisini qo'shing (image ichidagi lokal config bilan, named volume). `/ready` va `/metrics` ni tekshiring. Loki'ni Prometheus scrape config'iga qo'shing. Grafana'ga Loki data source'ni provisioning orqali (`uid: loki`) qo'shing.

5. **Alloy pipeline.** `alloy/config.alloy` yozing: Docker konteynerlarini topish, log'larini o'qish, Loki'ga yuborish. `alloy` servisini docker socket faqat o'qish uchun mount qilingan holda qo'shing. Alloy UI'da komponentlar grafigini ko'ring va har komponent sog'lom ekanini ko'rsating. Grafana Explore'da biror log qatorini toping.

6. **Relabel to useful labels.** Hozir log'larda qanday label'lar borligini ko'ring (`/loki/api/v1/labels` yoki Explore). `discovery.relabel` bilan `service` (compose servis nomi) va `container` label'larini qo'shing. `{service="api"}` ishlashini ko'rsating. Nima uchun container ID label sifatida yomon tanlov?

7. **Level as a label.** `loki.process` bilan JSON'dan `level` ni ajratib label qiling. `{service="api", level="error"}` ishlasin. Loki'da stream'lar soni qanday o'zgardi (`/loki/api/v1/series` yoki `loki_ingester_memory_streams` metrikasi)? JSON bo'lmagan log'lar (Prometheus, Grafana) bilan nima bo'ldi?

8. **Label cardinality bomb.** Ataylab `request_id` ni ham label qiling. 5 daqiqa yuklamadan keyin stream'lar soni, ingester xotirasi (`docker stats`) va Loki log'idagi ogohlantirish yoki rad etish xabarlarini yozing. Tuzating. Shu ma'lumotni label'siz qanday qidirasiz? Structured metadata bu yerda nima beradi?

9. **Drop noise.** Alloy'da `/healthz` va `/metrics` so'rovlari log'larini tashlab yuboring (`stage.drop` yoki match). Oldin va keyin `bytes_over_time` bilan `api` log hajmini solishtiring.

10. **Break the pipeline.** Loki'ni to'xtating, 2 daqiqa yuklama bering, qayta yoqing. Shu oraliqdagi log'lar Loki'da bormi? Alloy log'i va UI'da nima ko'rindi? Keyin `config.alloy` da sintaksis xatosi qiling va `alloy fmt` hamda konteyner log'i nima deyishini yozing.

### C. LogQL

11. **Filters and parsers.** So'rovlar yozing: `api` ning barcha error log'lari; `timeout` so'zi bor, lekin `/healthz` bo'lmagan qatorlar; `| json` dan keyin `status >= 500` va `duration_ms > 200`; `line_format` bilan faqat `route` va `err` chiqadigan ko'rinish. Bitta `request_id` bo'yicha so'rovning barcha log'larini toping.

12. **Filter order.** Bir xil natija beradigan ikki so'rov yozing: birida line filter parser'dan oldin, ikkinchisida faqat parser va label filter. Explore'dagi so'rov statistikasida (qayta ishlangan bayt va vaqt) farqni solishtiring. Oraliqni kattalashtirganda farq qanday o'zgaradi?

13. **Pattern parser.** JSON bo'lmagan log manbai uchun (masalan Grafana yoki o'zingiz qo'shgan nginx access log) `pattern` yoki `logfmt` parser bilan maydon ajrating va status bo'yicha filtrlang. `__error__` label'i qachon paydo bo'lishini ko'rsating.

14. **Metric queries.** LogQL bilan hisoblang: level bo'yicha log qatorlari tezligi; 5xx log'lari ulushi (ikki `rate` nisbati); `unwrap duration_ms` bilan route bo'yicha p95. Natijalarni 1-darsdagi Prometheus metrikalari bilan solishtiring: mos keladimi, farq bo'lsa nima uchun?

15. **Logs on the dashboard.** RED dashboard'ga ikkita panel qo'shing: level bo'yicha log tezligi (Time series) va `route` variable'iga bog'langan error log'lari (Logs panel). Grafikda xato cho'qqisini belgilab, shu vaqt oralig'idagi log'larga o'ting. Provisioning'dagi JSON'ni yangilang.

16. **Log-based alert.** Grafana Alerting'da Loki so'rovi asosida qoida yozing: `api` da ma'lum xato matni (`upstream timeout`) 5 daqiqada N martadan ko'p. 3-darsdagi contact point'ga yuboring. Buni metrika asosidagi alert'dan qachon afzal ko'rasiz?

17. **Retention.** Loki uchun o'z config faylingizni yozing (image'dagi lokal config asosida): compactor retention yoqilgan, umumiy muddat 7 kun, `level="debug"` stream'lari uchun 24 soat. Loki shu config bilan ko'tarilsin. Retention default holatda qanday ekanini va `delete_request_store` nima uchun talab qilinishini hujjatdan topib yozing.

### D. Elasticsearch va Kibana

18. **Single-node Elasticsearch.** `logs-es` profilida `elasticsearch` (single-node, heap cheklangan, konteynerga xotira limiti) va `kibana` servislarini qo'shing. Laboratoriya uchun xavfsizlikni o'chirishingiz mumkin, lekin buni izoh bilan belgilang. `_cluster/health` va `_cat/indices?v` chiqishini yozing. Yangi indeks yaratganingizda holat nima uchun `yellow` bo'lishini tushuntiring.

19. **Index and mapping.** `_bulk` API bilan 20–30 ta log hujjatini (1-vazifadagi format) indekslang. Mapping'ni ko'ring: `msg`, `route`, `status` qaysi turni oldi? `match` (`msg` bo'yicha) va `term` (`route` bo'yicha) so'rovlarini yozing va `text` bilan `keyword` farqini natijada ko'rsating. Keyin `status` ni matn qilib hujjat yuboring: xato nima deydi?

20. **Ship and explore.** Filebeat konteynerini qo'shing: Docker konteyner log'larini o'qib Elasticsearch'ga yuborsin (rasmiy hujjatdagi `filestream` input va container parser). Kibana'da data view yarating, Discover'da KQL bilan `api` ning 5xx log'larini toping. Xuddi shu savolni LogQL'da yozib solishtiring. Tugagach profilni o'chiring va volume'larni tozalang.

21. **Mini-project: logs in the stack.** Toza `docker compose up -d` dan keyin (ES profilisiz): `api` JSON log yozadi, Alloy uni `service`, `container`, `level` label'lari bilan Loki'ga yetkazadi, shovqin tashlangan, retention sozlangan, Grafana'da Loki data source va log panelli dashboard provisioning'dan keladi. Ssenariy: xato ulushini oshiring, 3-darsdagi alert'dan boshlab dashboard → log panel → bitta `request_id` ning to'liq tarixi yo'lini bosib o'ting va `README.md` ga yozing. Oxirida o'z so'zingiz bilan: shu loyihaga Loki yoki Elasticsearch, nima uchun?

### Topshirish

Tayyor bo'lgach:
1. `docker compose config -q` toza, Alloy UI'da barcha komponentlar sog'lom.
2. `make check` toza; log namunalarida token yoki shaxsiy ma'lumot yo'q.
3. `logs-es` profili o'chirilgan, Elasticsearch volume'lari tozalangan (`docker volume ls`).
4. `docker compose down` qilingan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Structured log matnli logdan nimasi bilan farq qiladi va `msg` nima uchun o'zgarmas bo'lishi kerak?
- Loki nimani indekslaydi, nimani yo'q? Bu yozish va o'qish narxiga qanday ta'sir qiladi?
- Nima uchun `trace_id` Loki label'i bo'lmasligi kerak, lekin Elasticsearch'da oddiy maydon bo'la oladi?
- LogQL so'rovida bosqichlar tartibi unumdorlikka qanday ta'sir qiladi?
- Inverted index nima va nima uchun u ham tez, ham qimmat?
- `text` va `keyword` maydon farqi nima?
- Log'dan metrika chiqarish qachon to'g'ri, qachon haqiqiy metrika yozish kerak?
- Promtail'ning hozirgi holati qanday va o'rniga nima ishlatiladi?
- Retention sozlanmasa Loki va Elasticsearch'da nima bo'ladi?
