# 5-dars: Distributed tracing

Maqsad: bitta so'rov bir nechta servisdan o'tganda vaqt qayerda ketganini va xato qayerda tug'ilganini ko'rish. Metrika "p95 o'sdi" deydi, log har servisning o'z hikoyasini aytadi, trace esa ularni bitta so'rov bo'yicha sababiy daraxtga bog'laydi. Bu darsda trace qanday tuzilganini, kontekst servislar orasida qanday uzatilishini (W3C `traceparent`), nima uchun hamma trace saqlanmasligini (sampling) o'rganasiz, namuna ilovaga ikkinchi servis qo'shib ikkalasini instrumentatsiya qilasiz, trace'larni Jaeger va Tempo'da ko'rasiz va ularni 1-darsdagi metrikalar hamda 4-darsdagi log'lar bilan bog'laysiz. Instrumentatsiya OpenTelemetry SDK bilan qilinadi; uning ichki tuzilishi va Collector 7-darsda.

Taxminiy vaqt: 3 kun (siz uchun). HTTP header'lar va async kontekst sizga tanish. Diqqatni quyidagilarga qarating: span daraxti qanday yig'iladi (parent ID), propagation uzilganda nima ko'rinadi, head va tail sampling qarori qayerda qabul qilinadi, exemplar va `trace_id` orqali signallar orasida o'tish.

## Laboratoriya

`observability/stack/` ustida. Yangi servislar: `inventory` (ikkinchi namuna servis, port `8001`), `tempo` (HTTP API `3200`, OTLP `4317`/`4318`), `jaeger` (`jaeger` profilida, UI `16686`). Versiyalar: https://github.com/grafana/tempo/releases , https://www.jaegertracing.io/download/ . Tempo uchun ishlaydigan namuna config: https://github.com/grafana/tempo/tree/main/example/docker-compose (single-binary).

```
mkdir -p tempo app-inventory
docker compose up -d tempo inventory
docker compose --profile jaeger up -d jaeger     # group B only
curl -s localhost:3200/ready
```

OTLP portlarini (`4317`, `4318`) host'ga publish qilish shart emas: ilovalar Compose tarmog'ida servis nomi bilan yuboradi. Jaeger va Tempo ikkalasi ham shu portlarni tinglaydi, host'ga ikkalasini publish qilsangiz to'qnashadi. Tozalash: `docker compose --profile jaeger down`.

---

## 1. Trace modeli

### Span
Span bitta ish birligi: kiruvchi HTTP so'rovga ishlov berish, chiquvchi so'rov, DB so'rovi, funksiya.

| Maydon | Ma'nosi |
|--------|---------|
| `trace_id` | 16 bayt (32 hex belgi), butun so'rov uchun bitta |
| `span_id` | 8 bayt (16 hex belgi), shu span uchun |
| `parent_span_id` | ota span; bo'sh bo'lsa bu root span |
| name | past cardinality'li nom: `GET /products/:id`, URL emas |
| kind | `SERVER`, `CLIENT`, `INTERNAL`, `PRODUCER`, `CONSUMER` |
| start, end | boshlanish va tugash vaqti |
| attributes | kalit-qiymat: `http.request.method`, `http.response.status_code`, `db.system.name` |
| events | span ichidagi vaqt belgili yozuvlar, masalan exception |
| status | `Unset`, `Ok`, `Error` |

Resource attributes span'ni kim yaratganini bildiradi: `service.name`, `service.version`, `deployment.environment.name`.

### Trace
Trace bir xil `trace_id` li span'lar to'plami, `parent_span_id` orqali daraxtga yig'iladi. Hech qaysi servis butun trace'ni bilmaydi: har biri o'z span'larini mustaqil yuboradi, backend ularni `trace_id` bo'yicha birlashtiradi. Waterfall ko'rinishida gorizontal o'q vaqt, ichma-ichlik chaqiruv zanjiri.

Bitta servis chaqiruvi odatda ikki span: chaqiruvchi tomonda `CLIENT`, qabul qiluvchida `SERVER`. Ular orasidagi vaqt farqi tarmoq va navbat.

### Trace, log va metrika
Trace har so'rovning tafsiloti: yuqori cardinality (har qanday atribut bo'yicha qidirish mumkin), lekin hajm katta, shuning uchun namuna olinadi. Metrika hamma so'rovni sanaydi, lekin tafsilotsiz. Shuning uchun alert va dashboard metrikada, sabab qidirish trace'da.

## 2. Context propagation

Kontekst (`trace_id`, joriy `span_id`, sampling qarori) ikki chegaradan o'tishi kerak:

- **Jarayon ichida**: kiruvchi so'rovdan chiquvchi chaqiruvgacha. Node.js'da `AsyncLocalStorage` (SDK o'zi boshqaradi), Go'da `context.Context` (har funksiyaga qo'lda uzatiladi).
- **Jarayonlar orasida**: HTTP header'lar orqali. Chaqiruvchi **inject** qiladi, qabul qiluvchi **extract** qiladi.

### W3C Trace Context
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             |  |                                |                |
          version  trace-id (32 hex)       parent-id (16 hex)   flags (01 = sampled)
```

`tracestate` vendor'ga xos qo'shimcha ma'lumot, `baggage` header'i esa ilova darajasidagi kalit-qiymatlarni (masalan `tenant=acme`) butun zanjir bo'ylab olib o'tadi. Eski formatlar (B3, Jaeger'ning `uber-trace-id`) hali uchraydi; yangi tizimda W3C tanlanadi, OpenTelemetry SDK'larida u default.

**Tuzoq: uzilgan trace.** Zanjirdagi bitta bo'g'in header'ni uzatmasa (instrumentatsiyasiz HTTP client, header'larni kesadigan proxy, navbat orqali o'tgan xabar), keyingi servis yangi `trace_id` bilan yangi trace boshlaydi. UI'da bitta uzun trace o'rniga ikkita qisqa, bog'lanmagan trace ko'rinadi. Go'da propagator'ni qo'lda o'rnatmaslik (`otel.SetTextMapPropagator`) shu natijani beradi: global default hech narsa uzatmaydi.

## 3. Sampling

Har so'rovni saqlash qimmat va keraksiz: 1000 ta muvaffaqiyatli bir xil so'rovning bittasi yetadi, lekin xatoli va sekinlari hammasi kerak.

| | Head sampling | Tail sampling |
|---|---|---|
| Qaror qachon | trace boshida, root span'da | trace tugagach, hamma span yig'ilgach |
| Qayerda | SDK (ilova) | Collector (`tail_sampling` processor) |
| Mezon | tasodifiy ulush (`trace_id` asosida) | mazmun: xato, davomiylik, atribut |
| Narxi | arzon, tashlab yuborilgan span umuman yaratilmaydi | hamma span Collector'gacha keladi, xotirada bufer |
| Kamchiligi | kam uchraydigan xato namunaga tushmasligi mumkin | bitta trace'ning hamma span'i bitta Collector instansiga tushishi shart |

Head sampling'da qaror `traceparent` flag'i orqali quyi servislarga uzatiladi va ular unga bo'ysunadi (`parentbased_*` sampler'lar), aks holda trace'lar yarim bo'lib qoladi. SDK'da env orqali: `OTEL_TRACES_SAMPLER=parentbased_traceidratio`, `OTEL_TRACES_SAMPLER_ARG=0.1`.

Sampling'dan qat'i nazar RED metrikalari to'liq bo'lishi kerak: ular ilovadagi counter/histogram'dan yoki sampling'dan **oldin** span'lardan hisoblanadi.

## 4. Instrumentatsiya

Jaeger'ning o'z client kutubxonalari eskirgan, hozir hamma backend (Jaeger, Tempo va boshqalar) uchun bitta yo'l: OpenTelemetry SDK va OTLP protokoli (gRPC `4317`, HTTP `4318`).

- **Avtomatik (zero-code)**: tayyor kutubxonalar HTTP server, HTTP client, DB driver'larni o'rab oladi. Node.js'da kodga tegmasdan:

```
npm install @opentelemetry/api @opentelemetry/auto-instrumentations-node
node --require @opentelemetry/auto-instrumentations-node/register server.js
```

- **Qo'lda**: biznes mantiq uchun o'z span'ingiz (`tracer.startActiveSpan("reserve-stock", ...)`), atribut va xato belgilash. Go'da avtomatik variant kamroq: `otelhttp.NewHandler` va `otelhttp.NewTransport` bilan handler va client o'raladi, exporter va propagator kodda sozlanadi.

Sozlash env orqali (hamma tillar uchun bir xil nomlar):

| O'zgaruvchi | Misol |
|-------------|-------|
| `OTEL_SERVICE_NAME` | `api` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://tempo:4318` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` yoki `grpc` |
| `OTEL_TRACES_EXPORTER` | `otlp` (`console` debug uchun, `none` o'chirish) |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment.name=lab,service.version=1.2.0` |

**Tuzoq: yuklanish tartibi.** Node.js'da instrumentation `http`, `express` kabi modullar `require` qilinishidan oldin yuklanishi shart (`--require` yoki `--import`). Aks holda modul allaqachon o'ralmagan holda xotirada va span'lar chiqmaydi, xato ham yo'q.

Span nomi va atributlarida cardinality qoidasi metrikadagidek: nom shablon (`GET /products/:id`), aniq qiymat atributda (`url.path`). Maxfiy ma'lumot (token, parol, so'rov tanasi) atributga yozilmaydi.

## 5. Backend'lar: Jaeger va Tempo

### Jaeger
CNCF loyihasi, o'z UI'si bilan: trace qidirish, waterfall, servislar bog'liqligi grafigi, ikki trace'ni solishtirish. Jaeger v2 OpenTelemetry Collector asosida qurilgan bitta binary (`jaeger`), OTLP'ni to'g'ridan-to'g'ri qabul qiladi. Sozlamasiz ishga tushirilsa all-in-one rejimda, trace'lar xotirada (restart'da yo'qoladi); production'da storage: Elasticsearch/OpenSearch, Cassandra va boshqalar. Jaeger v1 komponentlari (`jaeger-agent`, `jaeger-collector`, eski `all-in-one` image) rasmiy download sahifasida deprecated deb belgilangan, oxirgi versiyasi 1.76: eski qo'llanmalardagi `jaegertracing/all-in-one` ni ishlatmang.

### Tempo
Grafana Labs loyihasi, Loki bilan bir xil falsafa: trace'lar arzon object storage'da (Parquet bloklar), og'ir indeks klasteri yo'q, UI Grafana. Trace ID bo'yicha topish va TraceQL bilan qidirish. Qo'shimcha **metrics-generator** span'lardan RED metrikalari (`traces_spanmetrics_*`) va service graph (`traces_service_graph_*`) hisoblab, Prometheus'ga `remote_write` qiladi.

Monolithic rejim (`-target=all`) bitta jarayon, laboratoriya uchun yetarli. Minimal config'ning asosi:

```yaml
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc: { endpoint: "0.0.0.0:4317" }
        http: { endpoint: "0.0.0.0:4318" }
storage:
  trace:
    backend: local
    wal:   { path: /var/tempo/wal }
    local: { path: /var/tempo/blocks }
```

**Tuzoq: receiver `localhost` da.** OTLP receiver default `localhost` ni tinglaydi. Konteynerda bu faqat konteynerning o'zi degani: boshqa servislar `connection refused` oladi. Endpoint'ni `0.0.0.0:4317` (yoki servis nomi) qilib aniq yozing.

| | Jaeger | Tempo |
|---|---|---|
| UI | o'ziniki (Grafana'ga ham data source bo'ladi) | Grafana |
| Storage | Elasticsearch/OpenSearch, Cassandra va boshqalar | object storage |
| So'rov | servis, operatsiya, tag, davomiylik bo'yicha forma | TraceQL |
| Kuchli tomoni | mustaqil, yetuk UI | Grafana stack bilan bog'lanish, arzon saqlash |

## 6. TraceQL asoslari

So'rov `{ }` ichidagi span filtridan iborat, natija mos span'lari bor trace'lar.

```
{ resource.service.name = "api" && span:duration > 500ms }
{ span:status = error }
{ span.http.response.status_code >= 500 && span.http.route = "/checkout" }
{ resource.service.name = "api" } >> { resource.service.name = "inventory" && span:status = error }
{ span:status = error } | count() > 2
```

- Scope'lar: `resource.` (servis haqida), `span.` (span atributlari), intrinsic maydonlar ikki nuqta bilan: `span:duration`, `span:name`, `span:status`, `span:kind`, `trace:duration`, `trace:rootService`. Eski qisqa shakllar (`duration`, `status`, `name`) ham uchraydi.
- Operatorlar: `=`, `!=`, `>`, `<`, `=~`; mantiqiy `&&`, `||`.
- Strukturaviy: `>>` avlod, `>` bevosita bola, `~` qardosh. "api ichidan chaqirilgan va xato bergan inventory span'lari" kabi savollar shu bilan yoziladi.
- Pipeline: `| count()`, `| avg(span:duration)`, `| select(...)`.

## 7. Signallarni bog'lash

Alohida turgan uch tizim uch marta qidirish degani. Qiymat o'tish yo'llarida:

- **Metrika → trace (exemplar)**: exemplar histogram namunasiga biriktirilgan `trace_id`. Grafana grafikda nuqtalar sifatida ko'rsatadi, bosilsa shu trace ochiladi: "p99 cho'qqisidagi aniq bitta sekin so'rov". Kerak: Prometheus'da `--enable-feature=exemplar-storage`, exemplar yuboruvchi manba (Tempo metrics-generator `send_exemplars: true` bilan yoki OpenMetrics formatida exemplar beradigan client library), Grafana Prometheus data source'ida `exemplarTraceIdDestinations` (Tempo `uid` ga).
- **Trace → log**: Tempo data source'idagi `tracesToLogsV2`: span'dan Loki'ga, servis label'i va `trace_id` bo'yicha tayyor so'rov bilan.
- **Log → trace**: Loki data source'idagi `derivedFields`: log qatoridagi `trace_id` ni regex bilan topib Tempo'ga havolaga aylantiradi.

Buning sharti: log'da `trace_id` bo'lishi. Node.js'da auto-instrumentation pino/winston yozuvlariga `trace_id` va `span_id` ni o'zi qo'shadi; Go'da `trace.SpanContextFromContext(ctx)` dan olib logger'ga maydon qilib berasiz. `trace_id` Loki label'i emas, log maydoni (4-dars).

## Tuzoqlar

- Propagation uzilishi: bitta instrumentatsiyasiz client yoki header kesadigan proxy trace'ni ikkiga bo'ladi. Yangi servis qo'shilganda birinchi tekshiruv: trace uzluksizmi.
- Span nomida yoki atribut kalitida yuqori cardinality (`GET /products/8812`): qidiruv va span metrikalari portlaydi.
- 100% sampling bilan production'ga chiqish: trace hajmi log hajmidan ham oshadi. Sampling strategiyasi boshidan bo'lsin.
- Servislar har biri mustaqil head sampling qilishi (`traceidratio` `parentbased` siz): yarim trace'lar.
- Tail sampling'ni bir nechta Collector replikasi ortida trace bo'yicha yo'naltirishsiz qo'yish: qaror to'liq bo'lmagan ma'lumotda qabul qilinadi.
- Span atributlariga token, parol, shaxsiy ma'lumot yozish: trace'lar ham log kabi ko'pchilikka ochiq.
- RED metrikalarini sampling'dan keyingi span'lardan hisoblash: 10% namuna 10% trafikni ko'rsatadi.
- Servislar soatlari mos emas: bola span otadan oldin boshlangandek ko'rinadi. NTP ishlashi shart.
- Jaeger all-in-one'ni xotiradagi storage bilan "vaqtincha" production'ga qo'yish: restart'da hamma trace yo'qoladi.
- Xatoni span'da belgilamaslik: exception ushlab olingan, lekin span status `Unset` qolgan, `{ span:status = error }` uni topmaydi.

## Manbalar

- https://opentelemetry.io/docs/concepts/signals/traces/ – span, trace, kontekst tushunchalari (majburiy)
- https://www.w3.org/TR/trace-context/ – `traceparent` va `tracestate` spetsifikatsiyasi
- https://opentelemetry.io/docs/concepts/context-propagation/ – propagation
- https://opentelemetry.io/docs/concepts/sampling/ – head va tail sampling
- https://opentelemetry.io/docs/zero-code/js/ – Node.js zero-code instrumentation
- https://opentelemetry.io/docs/languages/go/getting-started/ – Go instrumentation
- https://opentelemetry.io/docs/languages/sdk-configuration/ – `OTEL_*` env o'zgaruvchilari
- https://www.jaegertracing.io/docs/latest/getting-started/ – Jaeger v2 ishga tushirish
- https://www.jaegertracing.io/download/ – Jaeger versiyalari, v1 deprecated belgisi
- https://grafana.com/docs/tempo/latest/ – Tempo
- https://grafana.com/docs/tempo/latest/traceql/ – TraceQL
- https://grafana.com/docs/tempo/latest/metrics-from-traces/ – metrics-generator, span metrics, service graph
- https://grafana.com/docs/grafana/latest/fundamentals/exemplars/ – exemplar'lar
- https://grafana.com/docs/grafana/latest/datasources/tempo/ – Tempo data source, trace to logs

---

## Vazifalar

Javoblar `observability/05-tracing/README.md` da (`make new m=observability n=05 name=tracing`), har vazifa uchun `## N. Title` ostida: nima qildingiz, config yoki so'rov, kuzatuv (trace ID, span'lar soni, vaqtlar), izoh. Stack fayllari (`app-inventory/`, `tempo/tempo.yaml`, provisioning o'zgarishlari) `observability/stack/` da.

### A. Ikki servis va propagation

1. **Second service.** `inventory` servisini yozing (`api` bilan bir tilda yoki boshqa tilda): `GET /stock/:id` tasodifiy 10–150 ms kechikish bilan javob beradi, taxminan 3% holatda `500`. `api` ning `/checkout` endpoint'i endi `inventory` ni chaqirsin va uning xatosini `502` qilib qaytarsin. Hozircha tracing'siz. `inventory` ga ham 1-darsdagi metrikalar va 4-darsdagi JSON log'ni qo'shing.

2. **Trace by hand.** Instrumentatsiyasiz holatda bitta sekin `/checkout` so'rovining sababini faqat log va metrikalar bilan topishga urining. Qaysi savolga javob bera olmadingiz? Bu tracing'siz dunyoning bazaviy holati, yozib qo'ying.

3. **Console exporter.** `api` ga OpenTelemetry tracing qo'shing, exporter `console`. Bitta so'rov yuboring va stdout'dagi span'dan `trace_id`, `span_id`, `parent`, kind, atributlarni ko'rsating. `/checkout` uchun nechta span chiqdi va har biri nima?

4. **Read traceparent.** `inventory` ga kiruvchi header'larni vaqtincha log qiling. `api` orqali so'rov yuboring va `traceparent` qiymatini to'rt qismga ajratib tushuntiring. Keyin `curl` bilan o'zingiz tuzgan `traceparent` header'ini `api` ga yuboring: `api` span'idagi `trace_id` siznikiga tengmi?

5. **Break propagation.** `inventory` ni ham instrumentatsiya qiling. Keyin propagation'ni ataylab uzing (Node.js'da chiquvchi so'rovni instrumentatsiya qilinmagan usulda yuboring yoki header'ni olib tashlang; Go'da propagator'ni o'rnatmang). Backend'da nima ko'rinadi: nechta trace, qanday bog'langan? Tuzating.

### B. Jaeger

6. **Jaeger all-in-one.** `jaeger` profilida Jaeger v2 ni qo'shing, ikkala servisni OTLP orqali unga yo'naltiring. UI'da `/checkout` trace'ini toping. Waterfall'dan o'qing: umumiy vaqt, `inventory` da ketgan vaqt, `CLIENT` va `SERVER` span orasidagi farq. Servislar bog'liqligi grafigini ko'rsating.

7. **Find the slow and the failed.** Jaeger UI'da davomiyligi 200 ms dan yuqori va xatoli trace'larni filtr bilan toping. Xatoli trace'da xato qaysi span'da tug'ilgan va yuqoriga qanday tarqalgan (`500` → `502`)? Span'da exception event bormi?

8. **Manual span.** `api` da `/checkout` ichidagi biznes qadamga (masalan narx hisoblash, sun'iy 30 ms) qo'lda span qo'shing: nom, ikkita atribut, xato holatida status `Error` va exception yozuvi. Trace'da yangi span qayerda paydo bo'ldi? Ushlangan, lekin status belgilanmagan xato UI'da qanday ko'rinishini ham sinang.

9. **Restart loses traces.** Jaeger konteynerini restart qiling. Trace'lar qoldimi? Nima uchun, va production'da bu qanday hal qilinishini hujjatdan topib 2–3 gapda yozing. Profilni o'chiring.

### C. Tempo va TraceQL

10. **Tempo service.** `tempo/tempo.yaml` yozing (monolithic, lokal storage, OTLP receiver'lar), `tempo` servisini qo'shing, ilovalarni unga yo'naltiring. Grafana'ga Tempo data source'ni provisioning bilan (`uid: tempo`) qo'shing. Explore'da trace ID bo'yicha trace oching.

11. **Receiver on localhost.** Tempo config'ida OTLP receiver endpoint'ini olib tashlang yoki `localhost:4318` qiling. Ilova log'ida va Tempo'da nima ko'rinadi? Trace'lar yo'qolganini ilova foydalanuvchisi sezadimi? Tuzating va nima uchun tracing exporter xatosi so'rovni yiqitmasligi kerakligini izohlang.

12. **TraceQL queries.** TraceQL bilan toping: `api` ning 300 ms dan uzoq span'lari; xato statusli barcha span'lar; `/checkout` route'idagi 5xx javoblar; `api` ichidan chaqirilgan va xato bergan `inventory` span'lari (strukturaviy operator); ikkitadan ko'p xatoli span'i bor trace'lar.

13. **Head sampling.** `api` da `parentbased_traceidratio` bilan 10% sampling yoqing. 200 ta so'rov yuboring: Tempo'da nechta trace? `inventory` da sampling sozlanmagan bo'lsa ham u nechta span yubordi va nima uchun? Keyin `inventory` da `parentbased` siz `traceidratio` 50% qo'yib yarim trace'larni ko'rsating. 1-darsdagi `http_requests_total` bu paytda to'liq sanayaptimi?

14. **Service graph and span metrics.** Tempo'da metrics-generator'ni yoqing (span-metrics va service-graphs processor'lari), Prometheus'da remote write qabul qilishni yoqing. Prometheus'da `traces_spanmetrics_*` va `traces_service_graph_*` seriyalarini ko'rsating. Grafana'da service graph'ni oching. Span metrikalaridagi so'rov tezligini ilovaning o'z counter'i bilan solishtiring.

### D. Bog'lash

15. **Trace ID in logs.** Ikkala servis log'lariga `trace_id` va `span_id` qo'shing. Bitta trace ID ni olib, Loki'da LogQL bilan shu so'rovning ikkala servisdagi barcha log'larini toping. `trace_id` ni Loki label'i qilmaganingizni ko'rsating.

16. **Logs to trace.** Loki data source provisioning'iga derived field qo'shing: log qatoridagi `trace_id` Tempo'ga havola bo'lsin. Explore'da error log qatoridan bir bosishda trace'ga o'ting.

17. **Trace to logs.** Tempo data source'da trace-to-logs'ni sozlang (Loki `uid`, servis nomi label'iga moslash, trace ID bo'yicha filtr). Span'dan uning log'lariga o'ting. Label nomlari mos kelmasa (`service.name` va `service`) nima bo'ladi va qanday moslanadi?

18. **Exemplars.** Prometheus'da exemplar storage'ni yoqing, Prometheus data source'da exemplar'larni Tempo'ga bog'lang. Latency panelida exemplar'larni yoqing, yuqoridagi nuqtani bosib sekin so'rovning trace'iga o'ting. Exemplar qaysi manbadan kelayotganini (metrics-generator yoki ilova) yozing.

19. **Mini-project: find the slow hop.** `inventory` ga yashirin muammo qo'shing: ma'lum `id` lar uchun (masalan 7 ga karrali) 800 ms kechikish. O'zingizni bilmagan odam o'rniga qo'ying va yo'lni bosib o'ting: latency dashboard → exemplar → trace → sekin span va uning atributlari → shu trace'ning log'lari. `README.md` ga har qadamda nima ko'rganingizni va qaysi so'rov (PromQL, TraceQL, LogQL) ishlatilganini yozing. Shu muammoni faqat metrika va log bilan topish qancha qiyin bo'lardi?

### Topshirish

Tayyor bo'lgach:
1. Toza `docker compose up -d` dan keyin `/checkout` trace'i ikkala servis span'lari bilan Tempo'da ko'rinadi.
2. Data source bog'lanishlari (exemplar, trace-to-logs, derived field) provisioning fayllarida.
3. `make check` toza.
4. `jaeger` profili o'chirilgan, `docker compose down` qilingan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Span'lar daraxti qanday yig'iladi, agar hech bir servis butun trace'ni bilmasa?
- `traceparent` header'ining to'rt qismi nima va sampling qarori qayerda uzatiladi?
- Propagation uzilganda UI'da nima ko'rinadi va eng ko'p uchraydigan sabablari nima?
- Head va tail sampling farqi nima? Kam uchraydigan xatoni ushlash uchun qaysi biri kerak va uning narxi nima?
- `parentbased` sampler nima uchun kerak?
- Nima uchun RED metrikalarini sampling qilingan trace'lardan hisoblab bo'lmaydi?
- Exemplar nima va u qaysi ikki signalni bog'laydi?
- Jaeger va Tempo o'rtasida qanday tanlaysiz?
- Nima uchun `trace_id` log maydoni bo'ladi, lekin Loki label'i emas?
