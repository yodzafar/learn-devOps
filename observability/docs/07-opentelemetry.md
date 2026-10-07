# 7-dars: OpenTelemetry va modul mini-loyihasi

Maqsad: oldingi oltita darsda har signal o'z yo'li bilan ketdi: metrikalar `prom-client` yoki `client_golang` orqali scrape bilan (1-dars), log'lar stdout va Alloy orqali (4-dars), trace'lar OTLP bilan to'g'ridan-to'g'ri Tempo'ga (5-dars), profillar Pyroscope SDK bilan (6-dars). OpenTelemetry (OTel) telemetriyani yaratish va tashishning yagona, vendor'ga bog'lanmagan standarti: bitta API va SDK, bitta protokol (OTLP), bitta oraliq komponent (Collector). Bu darsda OTel nimadan iboratligini va nima emasligini, resource attribute va semantic conventions'ni, Collector'ning ichki tuzilishini (receiver, processor, exporter, connector, pipeline) noldan o'rganasiz, keyin ilovaning trace, metrika va log'larini Collector orqali Tempo, Prometheus va Loki'ga yo'naltirasiz. Yakunida modul mini-loyihasi: to'liq stack kod sifatida va simulyatsiya qilingan incident'ni alert'dan profilgacha tekshirish. Kubernetes modulida aynan shu Collector DaemonSet va gateway sifatida qaytadi, bu darsda u faqat Compose'da.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun 1–3 bo'limlar, "Birga bajaramiz" va A guruh; ikkinchi kun 4–5 bo'limlar va B guruh; uchinchi kun 6–8 bo'limlar va C guruh; to'rtinchi kun 16–18-vazifalar (stack'ni yakunlash va nosozlik qo'shish); beshinchi kun 19–20-vazifalar (incident va postmortem); oltinchi kun 21-vazifa, ikkinchi mashinada tiklash sinovi va yakuniy tozalash. Diqqatni quyidagilarga qarating: API va SDK ajratilishi, Collector'da komponentni e'lon qilish bilan pipeline'ga ulash farqi, processor'lar tartibi, konteynerda receiver qaysi manzilda tinglashi, resource attribute'lar Prometheus va Loki label'lariga qanday aylanishi, OTel metrika nomlari eski dashboard'larni qanday buzishi.

Qanday o'qish kerak: har bo'limdagi config parchasini o'z `otelcol/config.yaml` faylingizga ko'chirmang, avval "Birga bajaramiz" dagi alohida Collector'da sinab, `debug` exporter chiqishini darsdagi izoh bilan solishtiring. Sizdagi vaqt belgilari, trace ID'lar va versiyalar farq qiladi, bunday joylar `<...>` bilan belgilangan. Collector tez o'zgaradigan loyiha: komponent nomi yoki kalit sizdagi versiyada boshqacha bo'lsa, `validate` buyrug'i va o'sha komponentning README fayli hal qiluvchi manba, dars emas.

## Laboratoriya

Hamma narsa host'dagi Docker Compose'da, umumiy `observability/stack/` papkasida ishlaydi (stack 2G xotirali `lab` VM uchun katta). Host'ga hech narsa o'rnatilmaydi. Yangi servis bitta: `otelcol` (OpenTelemetry Collector). Image: `otel/opentelemetry-collector-contrib`, aniq tag bilan (`latest` emas), versiyani https://github.com/open-telemetry/opentelemetry-collector-releases/releases sahifasidan olasiz. Image multi-arch bo'lishi kerak (Zorin'da `amd64`, Mac'da `arm64`), Docker Hub'dagi tag sahifasida "OS/ARCH" ro'yxatidan tekshiring. Contrib image'ida config yo'li: `/etc/otelcol-contrib/config.yaml`, uni `otelcol/config.yaml` dan read-only mount qilasiz.

```
mkdir -p otelcol
docker compose run --rm otelcol validate --config=/etc/otelcol-contrib/config.yaml
docker compose run --rm otelcol components     # what this binary contains
docker compose up -d otelcol
docker compose logs -f otelcol
```

- `validate` config'ni o'qiydi, tekshiradi va Collector'ni ishga tushirmasdan chiqadi (toza bo'lsa exit code 0). `components` shu binary ichiga qaysi receiver, processor, exporter, connector va extension'lar yig'ilganini ro'yxatlaydi.
- Collector image'i `scratch` asosida (docker moduli, 2-dars): ichida shell ham, `curl` ham yo'q, `docker compose exec otelcol sh` ishlamaydi. Diagnostika: konteyner log'i, `debug` exporter, Collector'ning o'z metrikalari va extension'lar.
- **Manzillar.** Compose ichida ilovalar Collector'ga servis nomi bilan murojaat qiladi: `http://otelcol:4318` (docker moduli, 3–4-darslar). Konteyner ichidagi `localhost` o'sha konteynerning o'zi, shuning uchun `api` konteyneridan `localhost:4318` hech qayerga bormaydi. Ikkinchi tomoni: Collector receiver'i default holatda `localhost` da tinglaydi, ya'ni faqat o'z konteyneri ichidan kelgan ulanishni qabul qiladi. Boshqa konteynerlar ulana olishi uchun receiver `0.0.0.0:4317`/`0.0.0.0:4318` da tinglashi kerak. Host'ga publish qilish esa alohida masala: ilovalar Compose tarmog'ida bo'lgani uchun OTLP portlarini host'ga chiqarish shart emas; `curl` bilan sinash uchun chiqarsangiz, `127.0.0.1:4318:4318` ko'rinishida faqat loopback'ka bog'lang. Xulosa: konteyner ichida `0.0.0.0`, host tomonda `127.0.0.1`.
- Secret'lar (Grafana admin paroli, Telegram token) avvalgidek commit qilinmaydigan `.env` da, repoda faqat `.env.example` (`make secrets` commit qilingan `.env` ni rad etadi). `compose.yaml`, `otelcol/config.yaml` va boshqa config'lar commit qilinadi, volume'lar yo'q. `make check` ish papkalaridagi YAML'ni `yamllint` bilan tekshiradi.
- Og'ir, profil ostidagi servislar (`elasticsearch`, `kibana`, `jaeger`) bu darsda o'chiq turadi. To'liq stack 3–4 GB RAM oladi, `docker stats --no-stream` bilan kuzating.

| Narsa | Zorin (ofis) | macOS (uy) |
|-------|--------------|------------|
| Docker | Docker Engine host kernel'ida, xotira chegarasi yo'q (host RAM) | Docker Desktop yashirin Linux VM ichida. `docker info` dagi `Total Memory` qatori VM limitini ko'rsatadi; 6 GB dan kam bo'lsa Settings → Resources'da oshiring |
| Image arxitekturasi | `amd64` | `arm64` |
| `hostmetrics` receiver, `docker_stats` receiver, `node-exporter`, `cadvisor` | haqiqiy ish mashinasini tasvirlaydi (uning CPU'si, disklari, hamma konteynerlari) | Docker Desktop VM'ini tasvirlaydi: Mac'ning CPU va disklari emas, VM'niki |
| Portlar | `127.0.0.1:<port>` host'da to'g'ridan-to'g'ri | xuddi shunday, Docker Desktop VM'dan host'ga uzatadi |
| Konteyner IP'lari, `--network host` | host'dan ko'rinadi | host'dan ko'rinmaydi; faqat publish qilingan portlar va servis nomlari ishlatiladi |

Host fayl tizimini mount qilish faqat o'qish uchun (`:ro`) bo'ladi, `docker.sock` ni mount qilish esa amalda root huquqini berish degani (docker moduli 1-dars, shu modul 1-dars). Host darajasidagi raqamlar ofis va uyda farq qiladi, shuning uchun README'da har o'lchov yonida qaysi mashinada olinganini yozing.

**Ikkinchi mashinada tiklash (modulning yopuvchi tekshiruvi).** Laboratoriya holati mashinalar orasida ko'chmaydi, kod ko'chadi. Stack to'liq kod sifatida yozilgan bo'lsa, ikkinchi mashinada to'rt qadam yetadi:

```
git pull
cd observability/stack
cp .env.example .env          # then fill in real values by hand
docker compose up -d
docker compose ps
```

Shundan keyin har dashboard, data source, alert qoidasi, recording rule va Collector pipeline'i qaytib kelishi kerak, chunki ular provisioning va config fayllarda. Faqat tarix yo'q: metrikalar, log'lar, trace'lar va profillar volume'larda edi, ular commit qilinmaydi. Biror narsa qaytmasa (masalan UI'da qo'lda yaratilgan dashboard), u kod emas ekan: 16-vazifaning mezoni shu.

**Tozalash.** Har mashg'ulot oxirida `docker compose down` (volume'lar qoladi). Modul oxirida, 21-vazifada, faqat shu loyiha uchun:

```
docker compose --profile "*" down -v
docker volume ls
docker ps -a
```

`-v` shu Compose loyihasining nomli volume'larini o'chiradi, `--profile "*"` profil ostidagi servislarni ham qamraydi. `docker system prune` va `docker volume prune -a` ishlatilmaydi: ikkala mashinada boshqa loyihalarning konteyner va volume'lari bor, ular ham o'chib ketadi.

---

## 1. OpenTelemetry nima va nima emas

### Nimadan iborat

OpenTelemetry bu CNCF (Cloud Native Computing Foundation, Kubernetes va Prometheus ham shu fond loyihalari) loyihasi: bitta dastur emas, spetsifikatsiya va uning amalga oshirilishlari to'plami. Telemetriya deb ilova o'zi haqida chiqaradigan ma'lumotga aytiladi: metrikalar, log'lar, trace'lar, profillar.

| Qism | Vazifasi |
|------|----------|
| Spetsifikatsiya | hamma tillar uchun umumiy qoidalar: API qanday ko'rinadi, SDK nima qiladi, ma'lumot modeli |
| API | kod chaqiradigan interfeys: tracer, meter, logger. SDK ulanmagan bo'lsa hech narsa qilmaydi (no-op) |
| SDK | API'ning amalga oshirilishi: sampling, batching, resource, exporter'lar |
| Instrumentation libraries | tayyor o'rovlar: HTTP server va client, DB driver, framework |
| OTLP | OpenTelemetry Protocol, telemetriyani tashish formati: gRPC (port `4317`) va HTTP (port `4318`) |
| Semantic conventions | atribut va metrika nomlarining umumiy lug'ati |
| Collector | telemetriyani qabul qiladigan, qayta ishlaydigan va jo'natadigan alohida jarayon |

OTel **backend emas va UI emas**: ma'lumotni saqlamaydi, so'rov tilini bermaydi, grafik chizmaydi. Saqlash Prometheus, Loki, Tempo'da, ko'rsatish Grafana'da qoladi. OTel faqat yaratadi, qayta ishlaydi va yetkazadi.

### Mexanizm: API va SDK ajratilishi

API paketi deyarli bo'sh: unda interfeyslar va "hech narsa qilmaydigan" default amalga oshirish bor. Kod `tracer.startSpan(...)` yoki `meter.createCounter(...)` ni chaqiradi; jarayon boshida SDK ro'yxatdan o'tkazilgan bo'lsa chaqiruv SDK'ga boradi, bo'lmasa no-op'ga tushadi va deyarli nol xarajat bilan qaytadi.

Bu sizga TS'dan ma'lum naqsh: kutubxona aniq bir vendor SDK'siga emas, `Logger` interfeysiga qarab yoziladi, qaysi logger ulanishini esa ilova hal qiladi. OTel'da ham shunday:

- **Kutubxona muallifi** (masalan HTTP framework yoki DB driver) faqat API paketiga bog'lanadi. U foydalanuvchisi tracing ishlatadimi, qaysi backend'ga yuboradi, bilmaydi va bilishi shart emas.
- **Ilova egasi** jarayon boshida SDK'ni sozlaydi: qaysi sampler, qaysi exporter, qaysi resource. Bu bitta joyda, odatda env orqali.

Natija: vendor almashtirish kodni emas, exporter sozlamasini yoki Collector config'ini o'zgartirish degani. 5-darsda `OTEL_EXPORTER_OTLP_ENDPOINT` ni Tempo'dan Jaeger'ga o'zgartirganingizda kodga tegmaganingiz shu ajratishning natijasi edi.

### Signallar va ularning holati

OTel'da har ma'lumot turi **signal** deyiladi: traces, metrics, logs, shuningdek baggage (kontekst bilan birga servislar orasida uzatiladigan kalit-qiymatlar) va profiles. Har signal ikki darajada alohida yetuklikka ega: spetsifikatsiyada va har til SDK'sida. Bitta tilda trace'lar barqaror, log'lar esa hali o'zgarayotgan bo'lishi mumkin. Bu holat tez o'zgaradi, shuning uchun darsda jadval berilmaydi: ishlatishdan oldin https://opentelemetry.io/docs/specs/status/ (spetsifikatsiya) va https://opentelemetry.io/docs/languages/ (o'z tilingiz) sahifalarini o'qing. Ikki narsa barqaror bilim: log'lar uchun OTel yangi logging API taklif qilmaydi, mavjud logger (pino, slog) "bridge" orqali ulanadi; profiles signali boshqalaridan keyin boshlangan, shu sababli 6-darsda Pyroscope SDK ishlatildi.

### Real ishda qachon kerak

- Yangi servisga tracing qo'shishda: bugun boshqa yo'l deyarli qolmagan, backend'lar OTLP qabul qiladi.
- Vendor yoki backend almashtirishda: ilova kodi OTel API'da bo'lsa, o'zgarish config'da qoladi.
- "OTel o'rnatdik, dashboard qani?" degan savolga javobda: OTel backend emas, saqlash va UI alohida tanlanadi.

### Nima uchun shunday

OTel 2019-yilda ikki raqobatchi loyiha, OpenTracing (faqat API) va OpenCensus (API va amalga oshirish birga) birlashuvidan chiqqan. Undan oldin har vendor o'z agentini va o'z formatini talab qilardi: vendor almashtirish hamma servisni qayta instrumentatsiya qilish edi, kutubxona mualliflari esa qaysi vendorni qo'llashni bilmay hech birini qo'llamasdi. API va SDK ajratilishi aynan kutubxonalar muammosini hal qiladi: API barqaror va yengil, unga bog'lanish xavfsiz. Muqobili, vendor agenti, bugun ham bor va ba'zan qulayroq (bitta o'rnatish, tayyor UI), lekin sizni o'sha vendorga bog'laydi.

## 2. Instrumentatsiya: resource, semantic conventions, OTLP

### Auto va manual

Instrumentatsiya bu kodga telemetriya chiqaradigan chaqiruvlarni qo'shish.

- **Zero-code (auto)**: kodga tegmasdan. Node.js'da `--require @opentelemetry/auto-instrumentations-node/register` (5-darsda ishlatgansiz): u `http`, `express`, DB driver kabi modullarni yuklanish paytida o'rab oladi. Java'da agent, Python'da `opentelemetry-instrument`. Go kompilyatsiya qilinadigan til bo'lgani uchun kutubxona o'rovlari (`otelhttp`) kodda ulanadi.
- **Manual**: biznes ma'nosi bor narsalar: o'z span'ingiz, o'z metrikangiz, o'z atributlaringiz. Auto instrumentatsiya "HTTP so'rov keldi" ni biladi, "buyurtma to'landi" ni bilmaydi.

Amaliy tartib: avval auto (HTTP, DB, chiquvchi chaqiruvlar tayyor keladi), keyin eng muhim biznes operatsiyalariga manual.

SDK env orqali sozlanadi (5-dars jadvali). Signal bo'yicha exporter: `OTEL_TRACES_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_LOGS_EXPORTER` (qiymatlar: `otlp`, `console`, `none`). Manzil `OTEL_EXPORTER_OTLP_ENDPOINT`, protokol `OTEL_EXPORTER_OTLP_PROTOCOL` (`grpc`, `http/protobuf`). Metrikalar davriy eksport qilinadi (`OTEL_METRIC_EXPORT_INTERVAL`, millisekundda): bu push, Prometheus scrape'i emas (5-bo'lim).

### Resource attribute va oddiy atribut

Atribut bu telemetriyaga yopishtirilgan kalit-qiymat. Ular ikki darajada yashaydi:

| | Resource attribute | Span, metrika yoki log atributi |
|---|---|---|
| Nimani tavsiflaydi | telemetriya **manbasini**: qaysi servis, qaysi versiya, qaysi muhit | **bitta hodisani**: shu so'rov, shu o'lchov |
| Qachon belgilanadi | jarayon boshida bir marta | har span yoki o'lchovda |
| Misol | `service.name`, `service.version`, `deployment.environment.name` | `http.request.method`, `http.route`, `http.response.status_code` |
| Signallar orasida | uchala signalda bir xil | signalga xos |

```
OTEL_SERVICE_NAME=billing
OTEL_RESOURCE_ATTRIBUTES=service.namespace=demo,service.version=2.3.1,deployment.environment.name=lab
```

Resource uchala signalda bir xil bo'lgani uchun signallarni bog'lash shu orqali ishlaydi: Grafana'da trace'dan log'ga o'tish "shu `service.name`, shu vaqt, shu trace ID" degan so'rov. `service.name` belgilanmasa SDK `unknown_service` (ko'pincha jarayon nomi bilan, masalan `unknown_service:node`) qo'yadi va hamma servis bitta nom ostida aralashadi. Resource detector'lar host, konteyner, cloud va Kubernetes atributlarini avtomatik qo'shadi (SDK'da yoki Collector'ning `resourcedetection` processor'ida).

### Semantic conventions

Semantic conventions bu "bir xil narsani hamma bir xil nomlasin" degan lug'at. Usiz bitta servis `method`, ikkinchisi `http_method`, uchinchisi `verb` deb yozadi va har dashboard faqat bitta servisda ishlaydi.

| Soha | Nomlar |
|------|--------|
| HTTP span va metrika atributlari | `http.request.method`, `http.response.status_code`, `http.route`, `url.path`, `server.address` |
| HTTP server metrikasi | `http.server.request.duration` (histogram, soniyada) |
| Resource | `service.name`, `service.namespace`, `service.version`, `service.instance.id`, `deployment.environment.name` |

Lug'at ham o'zgargan: eski kod va maqolalarda oldingi nomlar uchraydi (`http.method`, `http.status_code`, `deployment.environment`). O'z atributlaringizga prefiks bering (`shop.order.id`), umumiy nomlar bilan to'qnashmasin.

### OTLP: gRPC va HTTP

OTLP bitta ma'lumot modelini (resource → scope → span, metrika yoki log yozuvi) ikki transport orqali tashiydi:

| | OTLP/gRPC | OTLP/HTTP |
|---|---|---|
| Port (kelishuv bo'yicha) | `4317` | `4318` |
| Yo'l | gRPC servislar | `/v1/traces`, `/v1/metrics`, `/v1/logs` |
| Kodlash | protobuf | protobuf yoki JSON |
| Qachon qulay | servisdan Collector'ga, Collector'dan backend'ga | brauzer, proxy va load balancer'lar orqali, `curl` bilan sinash |

Ikkalasi bir xil ma'lumotni olib yuradi, tanlov tarmoq infratuzilmasiga bog'liq. HTTP varianti oddiy `POST` bo'lgani uchun uni qo'lda yuborish mumkin, "Birga bajaramiz" shunga asoslangan. Yuboruvchi tomonda eng ko'p uchraydigan xato: gRPC exporter'ni `4318` ga yoki HTTP exporter'ni `4317` ga yo'naltirish, ulanish bor, ma'lumot yo'q.

### Misol: bitta span ichida nima bor

Collector'ning `debug` exporter'i (3-bo'lim) `verbosity: detailed` bilan kelgan span'ni to'liq bosadi. `billing` servisidan kelgan bitta HTTP span'i:

```
ResourceSpans #0
Resource attributes:
     -> service.name: Str(billing)
     -> service.version: Str(2.3.1)
     -> deployment.environment.name: Str(lab)
ScopeSpans #0
InstrumentationScope @opentelemetry/instrumentation-http <versiya>
Span #0
    Trace ID       : <32 hex>
    Parent ID      :
    ID             : <16 hex>
    Name           : GET /invoices/:id
    Kind           : Server
    Status code    : Unset
Attributes:
     -> http.request.method: Str(GET)
     -> http.route: Str(/invoices/:id)
     -> http.response.status_code: Int(200)
```

Qatorma-qator (bir necha xizmat qatorlari qisqartirilgan): `Resource attributes` jarayon boshida env'dan olingan uch qiymat, ular shu jarayonning har span'ida bir xil. `InstrumentationScope` span'ni qaysi kutubxona yaratganini aytadi, bu yerda auto instrumentatsiyaning HTTP moduli. `Trace ID` va `ID` 5-darsdagi trace va span identifikatorlari, `Parent ID` bo'sh, demak bu trace'ning ildiz span'i. `Kind: Server` kiruvchi so'rov. `Attributes` faqat shu so'rovga tegishli. `Str(...)` va `Int(...)` qiymat turini ko'rsatadi: OTLP'da atributlar turli (satr, butun son, bool, massiv), Prometheus label'lari kabi faqat satr emas.

### Real ishda qachon kerak

- Yangi servisda birinchi ish: `service.name`, `service.version` va muhit atributini belgilash. Bularsiz keyingi hamma narsa aralashadi.
- "Deploy'dan keyin yomonlashdimi?" savoliga `service.version` bo'yicha solishtirish javob beradi.
- Jamoalararo dashboard'lar: hamma semantic conventions'ga amal qilsa, bitta RED dashboard har servisda ishlaydi.

### Nima uchun shunday

Resource alohida daraja qilingani hajm va ma'no uchun: OTLP'da resource bir partiyadagi hamma span uchun bir marta yoziladi, har span'da takrorlanmaydi, backend esa "manba" va "hodisa" ni farqlay oladi (Prometheus `service.name` ni `job` ga aylantiradi, 5-bo'lim). Semantic conventions'ning narxi: nomlar uzun va nuqtali, Prometheus an'analaridan farq qiladi va vaqt o'tishi bilan o'zgargan. Muqobili, har jamoaning o'z nomlari, kichik tizimda ishlaydi, o'ninchi servisda buziladi.

## 3. Collector: tuzilishi va pipeline'lar

### Nima uchun oraliq bo'g'in

OpenTelemetry Collector bu ilova bilan backend'lar orasida turadigan alohida jarayon: telemetriyani qabul qiladi, o'zgartiradi va bir yoki bir nechta joyga jo'natadi. 5-darsda ilova trace'ni to'g'ridan-to'g'ri Tempo'ga yuborgan edi. Collector qo'yilganda:

- Ilova faqat bitta manzilni biladi (`otelcol:4318`). Backend qo'shish, almashtirish yoki ikki joyga birdan yuborish ilovani qayta deploy qilmasdan, Collector config'ida hal bo'ladi.
- Batch, retry va navbat ilovadan tashqarida: backend sekinlashsa ilova emas, Collector kutadi.
- Markaziy qayta ishlash: maxfiy atributlarni o'chirish, label qo'shish, tail sampling, keraksiz telemetriyani tashlash.
- Protokol tarjimasi: Prometheus scrape, fayldagi log'lar, eski formatlar OTLP'ga aylanadi va aksincha.

Bu frontend'dagi API gateway yoki BFF (backend for frontend) ga o'xshaydi: brauzer o'nta mikroservis manzilini emas, bitta gateway manzilini biladi, marshrutlash va qayta urinish gateway'da.

**Joylashtirish.** Ikki sxema bor: **agent** (har host yoki pod yonida, ilovaga yaqin; mahalliy atributlarni qo'shadi, tez qabul qiladi) va **gateway** (markaziy, bir nechta replika; sampling, filtr, backend'ga yuborish). Production'da ko'pincha ikkalasi birga: ilova → agent → gateway → backend. Bu darsda bitta Collector ikkala rolni bajaradi. Grafana Alloy (4-dars) ham OTel Collector asosida qurilgan: `loki.*` komponentlari yonida `otelcol.*` komponentlari bor.

**Distributsiyalar.** Collector bitta binary emas, komponentlar to'plamidan yig'iladi. `otelcol` (core) minimal to'plam, `otelcol-contrib` hamma community komponentlari bilan. Laboratoriya uchun contrib qulay; production'da OpenTelemetry Collector Builder (`ocb`) bilan faqat kerakli komponentlardan o'z build'ingizni yig'ish tavsiya etiladi: kichikroq image, kamroq zaiflik.

### Mexanizm: komponentlar va pipeline

Config'da ikki qatlam bor. Birinchisi, komponentlarni **e'lon qilish** (`receivers:`, `processors:`, `exporters:`, `connectors:`, `extensions:` bo'limlari). Ikkinchisi, ularni **ulash** (`service:` bo'limi). Collector faqat `service` da ishlatilgan komponentlarni yaratadi.

```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  batch: {}
exporters:
  debug: { verbosity: basic }
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
```

Qatorma-qator: `otlp` receiver ikki transportda tinglaydi, `0.0.0.0` boshqa konteynerlardan ulanishga ruxsat beradi (Laboratoriya, "Manzillar"). `batch` processor ma'lumotni partiyalarga yig'adi. `debug` exporter kelgan narsani Collector'ning o'z log'iga yozadi. `service.pipelines.traces` "trace'lar `otlp` dan kirsin, `batch` dan o'tsin, `debug` ga chiqsin" deydi.

Pipeline bu bitta signal uchun yo'l: `traces`, `metrics` yoki `logs`, ixtiyoriy nom bilan (`traces/sampled`). Ichida ma'lumot shunday oqadi:

```
receiver(s) ──► processor 1 ──► processor 2 ──► ... ──► exporter(s)
   fan-in          ro'yxatda yozilgan tartibda            fan-out
```

Bir nechta receiver bitta pipeline'ga quyiladi (fan-in), oxirida har exporter ma'lumotning nusxasini oladi (fan-out). Bitta receiver bir nechta pipeline'da qatnashishi mumkin: `otlp` odatda `traces`, `metrics` va `logs` uchalasida turadi.

| Tur | Vazifasi | Misollar |
|-----|----------|----------|
| Receiver | ma'lumotni qabul qiladi yoki o'zi yig'adi | `otlp`, `prometheus` (scrape qiladi), `filelog`, `hostmetrics`, `docker_stats` |
| Processor | o'tayotgan ma'lumotni o'zgartiradi yoki tashlaydi | `memory_limiter`, `batch`, `resource`, `attributes`, `filter`, `transform`, `tail_sampling`, `resourcedetection` |
| Exporter | ma'lumotni tashqariga jo'natadi | `debug`, OTLP gRPC va HTTP exporter'lari, `prometheus` (scrape uchun endpoint ochadi), `prometheusremotewrite` |
| Connector | bir pipeline uchun exporter, boshqasi uchun receiver | `spanmetrics`, `forward`, `count` |
| Extension | pipeline'dan tashqaridagi yordamchi | `health_check`, `zpages`, `pprof`, `file_storage` |

**Nomlash.** Komponent nomi `type` yoki `type/name`: bitta turdan bir nechtasi kerak bo'lsa nom qo'shiladi (`attributes/redact`, `attributes/env`). OTLP exporter'larining turlari versiyaga bog'liq: yangi versiyalarda `otlp_grpc` va `otlp_http`, eski versiyalar va qo'llanmalarda `otlp` va `otlphttp`. Sizdagi image qaysi nomlarni bilishini `components` chiqishi aytadi, shu darsdagi misollar ham shunga moslab o'qiladi.

**Env interpolatsiyasi.** Config ichida `${env:NAME}` muhit o'zgaruvchisidan olinadi. Manzillar va token'lar shu yo'l bilan Compose'dagi `.env` dan keladi, config faylda secret qolmaydi.

### Misol: `debug` exporter chiqishi

Yuqoridagi config bilan bitta span kelganda Collector log'ida (`docker compose logs otelcol`):

```
<vaqt>	info	Traces	{"otelcol.component.id": "debug", "otelcol.component.kind": "exporter", "otelcol.signal": "traces", "resource spans": 1, "spans": 1}
```

Qatorma-qator: `info` log darajasi; `Traces` signal; `otelcol.component.id` qaysi exporter yozgani (eski versiyalarda kalitlar `kind`, `name`, `data_type` deb nomlangan); `resource spans: 1` partiyada bitta resource (bitta servis), `spans: 1` unda bitta span. `verbosity: basic` faqat sonlarni beradi; `normal` har yozuvga bir qator; `detailed` 2-bo'limdagi kabi to'liq tarkibni. `detailed` yuklama ostida log'ni to'ldirib yuboradi, uni faqat sinovda yoqing.

### Real ishda qachon kerak

- "Ilova trace yuboryapti, Tempo'da yo'q": avval `debug` exporter'ni pipeline'ga qo'shib Collector'gacha yetib kelayotganini ajratasiz. Kelyapti bo'lsa muammo chiqishda, kelmayapti bo'lsa ilova yoki tarmoqda.
- Backend almashtirish yoki ikki backend'ga parallel yuborish (migratsiya paytida): bitta exporter qo'shib pipeline ro'yxatiga yozish.

### Nima uchun shunday

E'lon va ulashning ajratilgani bitta komponentni bir nechta pipeline'da qayta ishlatish uchun: `otlp` receiver bir marta e'lon qilinadi, uch pipeline'da ishlatiladi; bitta `batch` sozlamasi hamma joyda. Narxi: e'lon qilingan, lekin ulanmagan komponent xatosiz "yo'q" bo'lib turadi va bu eng ko'p uchraydigan "nima uchun ma'lumot kelmayapti" sababi. Muqobili, har tool'ning o'z agenti (node_exporter, Alloy, Pyroscope agent), oddiyroq, lekin har signal uchun alohida sozlash va alohida nosozlik nuqtasi.

## 4. Processor'lar va ularning tartibi

### Asosiy processor'lar

| Processor | Nima qiladi |
|-----------|-------------|
| `memory_limiter` | Collector xotirasini kuzatadi, chegaraga yaqinlashganda yangi ma'lumotni rad etadi |
| `batch` | yozuvlarni hajm yoki vaqt bo'yicha partiyalarga yig'adi, exporter'ga kamroq va kattaroq so'rov boradi |
| `resource` | resource attribute qo'shadi, o'zgartiradi yoki o'chiradi |
| `attributes` | span, log yoki metrika atributlarini qo'shadi, o'zgartiradi, o'chiradi yoki hash qiladi |
| `filter` | shartga mos yozuvlarni tashlaydi (masalan `/healthz` span'lari) |
| `transform` | OTTL (OpenTelemetry Transformation Language) ifodalari bilan erkin o'zgartirish |
| `resourcedetection` | host, Docker, cloud muhitidan resource attribute'larni avtomatik qo'shadi |
| `tail_sampling` | trace tugagach, butun trace bo'yicha saqlash yoki tashlash qarorini qiladi (6-bo'lim) |

### Mexanizm: tartib nima uchun muhim

Processor'lar `processors: [...]` ro'yxatida yozilgan tartibda, ketma-ket ishlaydi: har biri oldingisining chiqishini oladi. Umumiy qoida:

1. **`memory_limiter` birinchi.** U xotira chegarasiga yetganda ma'lumotni receiver darajasida rad etadi, receiver yuboruvchiga xato qaytaradi va yuboruvchi (SDK yoki boshqa Collector) keyinroq qayta urinadi. Agar u oxirida tursa, ma'lumot allaqachon xotiraga olingan bo'ladi, himoya kech.
2. **Tashlaydigan processor'lar o'rtada** (`filter`, sampling): keyingi bosqichlar keraksiz ma'lumotga vaqt sarflamasin.
3. **O'zgartiradigan processor'lar** (`resource`, `attributes`, `transform`) tashlashdan keyin, lekin tashlash qarori o'zgartirilgan atributga bog'liq bo'lsa, undan oldin.
4. **`batch` oxirida.** Tashlab yuboriladigan ma'lumotni batch qilish behuda, va batch'dan keyin turgan processor partiyani yana bo'laklashi mumkin.

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100
  attributes/redact:
    actions:
      - { key: user.email, action: delete }
  batch: {}
```

Qatorma-qator: `memory_limiter` har soniyada xotirani tekshiradi; 400 MiB qattiq chegara, `spike_limit_mib` keskin o'sish uchun zaxira, ya'ni rad etish 300 MiB atrofida boshlanadi. Bu son konteyner xotira limitidan kichik bo'lishi shart, aks holda Docker konteynerni OOM bilan o'ldiradi va `memory_limiter` ishlashga ulgurmaydi. `attributes/redact` har yozuvdan `user.email` atributini o'chiradi. `action` qiymatlari: `insert` (yo'q bo'lsa qo'shish), `update` (bor bo'lsa almashtirish), `upsert` (ikkalasi), `delete`, `hash`.

`resource` processor xuddi shu `actions` ko'rinishida, faqat resource darajasida ishlaydi: "hamma telemetriyaga muhit nomini qo'shish" uning ishi. Ilovadagi `OTEL_RESOURCE_ATTRIBUTES` bilan Collector'dagi `resource` orasida tanlov: ilova o'zi haqida biladigan narsa (nom, versiya) ilovada, muhit haqidagi narsa (klaster, region) Collector'da.

### Misol: `filter` bilan shovqinni tashlash

Health check so'rovlari har 5 soniyada keladi va trace'lar orasida ko'pchilikni tashkil qiladi. `filter` processor OTTL shartiga mos span'ni tashlaydi:

```yaml
processors:
  filter/healthz:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
```

`traces.span` ostidagi har shart rost bo'lgan span tashlanadi. `error_mode: ignore` shart hisoblashda xato bo'lsa (masalan atribut turi boshqa) yozuvni o'tkazib yuborish, Collector'ni to'xtatmaslik. Bu processor "Birga bajaramiz" da ishlatiladi.

### Real ishda qachon kerak

- Shaxsiy ma'lumot (email, token, karta raqami) span atributiga tushib qolgan: ilova tuzatilguncha Collector'da o'chirish yoki hash qilish. Bu ham GDPR kabi talablar bo'yicha ish.
- Yuklama cho'qqisida Collector OOM bo'lib qayta ishga tushyapti: `memory_limiter` qo'yilmagan yoki konteyner limitidan katta.
- Telemetriya narxini tushirish: `filter` bilan health check, statik fayl so'rovlarini tashlash.

### Nima uchun shunday

Tartibni foydalanuvchi belgilashi (Collector o'zi saralamasligi) ataylab: processor'lar umumiy, ular orasidagi bog'liqlikni faqat siz bilasiz, masalan `transform` yangi atribut yozadi va `filter` aynan shu atributga qaraydi. Narxi: noto'g'ri tartib xato bermaydi, faqat jim ishlamaydi yoki xotirani himoya qilmaydi. Shuning uchun "`memory_limiter` birinchi, `batch` oxirida" qoidasini yodlab, qolganini har safar o'ylab qo'yish kerak.

## 5. Backend'larga yo'naltirish va nomlar

### Yo'nalishlar jadvali

| Signal | Exporter turi | Manzil | Backend'da kerak |
|--------|---------------|--------|------------------|
| Traces | OTLP gRPC | `tempo:4317` | Tempo OTLP receiver (5-dars) |
| Metrics | OTLP HTTP | `http://prometheus:9090/api/v1/otlp` | `--web.enable-otlp-receiver` flag'i |
| Logs | OTLP HTTP | `http://loki:3100/otlp` | Loki 3.x (structured metadata default yoqiq) |

OTLP HTTP exporter bazaviy manzilga signal yo'lini o'zi qo'shadi (`/v1/metrics`, `/v1/logs`, `/v1/traces`), shuning uchun manzilda `/v1/...` yozilmaydi. Compose tarmog'ida TLS yo'q, gRPC exporter'da `tls: { insecure: true }` kerak; HTTP manzil `http://` bilan boshlangani uchun TLS ishlatilmaydi. Production'da bu ochiq tarmoq orqali bo'lsa TLS va autentifikatsiya majburiy.

### Mexanizm: Prometheus OTLP metrikalarini qanday qabul qiladi

1–2-darslarda Prometheus o'zi borib metrikani olardi (**pull**, scrape). OTLP'da ilova yoki Collector metrikani Prometheus'ga o'zi yuboradi (**push**). Prometheus 3.x da buning uchun `--web.enable-otlp-receiver` flag'i kerak (flag'siz endpoint 404 qaytaradi). Prometheus'ning OTLP qo'llanmasi out-of-order yozishni ham yoqishni tavsiya qiladi (`storage.tsdb.out_of_order_time_window`), chunki push'da namunalar har doim vaqt tartibida kelmaydi.

Kelgan metrika Prometheus modeliga tarjima qilinadi:

| OTel | Prometheus |
|------|------------|
| `http.server.request.duration`, birlik `s`, histogram | `http_server_request_duration_seconds_bucket`, `_sum`, `_count` |
| counter `shop.checkouts` | `shop_checkouts_total` |
| `service.namespace` + `service.name` | `job="shop/api"` (namespace bo'lmasa `job="api"`) |
| `service.instance.id` | `instance` |
| qolgan resource attribute'lar | alohida `target_info` seriyasining label'lari |
| span/metrika atributlari (`http.route`) | label'lar, nuqtalar pastki chiziqqa: `http_route` |

Nuqtalar pastki chiziqqa, birlik suffiks'ga (`_seconds`, `_bytes`), counter'ga `_total` qo'shiladi. Bu Prometheus 3.x ning default tarjima strategiyasi; `prometheus.yml` dagi `otlp.translation_strategy` bilan o'zgartirish mumkin, lekin dashboard'lar shu default'ga qarab yoziladi.

**`target_info`.** Resource attribute'lar ko'p (host nomi, konteyner ID, SDK versiyasi), ularni har seriyaga label qilib qo'yish cardinality'ni (1-dars) portlatadi. Shuning uchun ular bitta `target_info{job, instance, ...}` seriyasiga yig'iladi va kerak bo'lsa so'rovda `job`/`instance` bo'yicha join qilinadi. Tez-tez filtrlanadigan bir-ikkitasini (`service.version`, `deployment.environment.name`) label'ga ko'tarish mumkin:

```yaml
# prometheus.yml
otlp:
  promote_resource_attributes:
    - service.version
```

Ko'tarishdan oldin so'rang: bu qiymat qancha xil bo'ladi? `service.version` har deploy'da bitta yangi qiymat, chidasa bo'ladi. `service.instance.id` yoki `container.id` har restart'da yangi: har restart yangi seriyalar to'plami.

**`up` yo'q.** `up` seriyasini Prometheus scrape natijasidan o'zi yaratardi (1-dars). Push'da scrape yo'q, demak `up` ham yo'q: servis o'lsa uning seriyalari shunchaki yangilanmay qoladi va taxminan 5 daqiqadan keyin (staleness) so'rovlardan yo'qoladi. 3-darsdagi "ma'lumot yo'q bo'lsa alert ham yo'q" tuzog'i shu yerda yana chiqadi.

### Mexanizm: Loki OTLP log'larini qanday qabul qiladi

Loki `/otlp/v1/logs` endpoint'ida OTLP log'larini qabul qiladi. Cheklangan ro'yxatdagi resource attribute'lar (jumladan `service.name`, `service.namespace`, `deployment.environment.name`) avtomatik **index label** bo'ladi, nuqtalar pastki chiziqqa: `service_name`. Qolgan resource attribute'lar va log yozuvining atributlari, jumladan `trace_id` va `span_id`, **structured metadata** ga tushadi (4-dars): ular index'da emas, lekin LogQL'da label kabi filtrlanadi:

```
{service_name="billing"} | trace_id="<32 hex>"
```

Log matnining o'zi (`body`) satr sifatida saqlanadi. Ro'yxatni Loki config'idagi `distributor.otlp_config` va `limits_config` orqali o'zgartirish mumkin, aniq kalitlar Loki OTLP hujjatida.

### Tuzoq: nomlar o'zgaradi

`prom-client` yoki `client_golang` dan (1-dars) OTel metrikalariga o'tganda deyarli hamma nom boshqacha bo'ladi:

| | 1-dars (client library) | OTel orqali |
|---|---|---|
| Latency histogram | `http_request_duration_seconds` (siz bergan nom) | `http_server_request_duration_seconds` |
| Label'lar | `route`, `status`, `method` | `http_route`, `http_response_status_code`, `http_request_method` |
| `job` | `prometheus.yml` dagi `job_name` | `service.namespace/service.name` |
| Log label'i (4-dars) | `service` | `service_name` |
| Bucket chegaralari | siz tanlagan | SDK yoki instrumentatsiya tanlagan, tekshirish kerak |

Dashboard, recording rule va alert'lar xato bermaydi, jimgina bo'sh qoladi. Bucket chegaralari alohida tuzoq: ba'zi SDK versiyalarida default chegaralar millisekund uchun mo'ljallangan, soniyadagi histogram'da deyarli hamma qiymat birinchi bucket'ga tushadi va `histogram_quantile` ma'nosiz chiqadi. `_bucket` seriyasining `le` qiymatlarini bir marta ko'zdan kechiring. Migratsiyaning umumiy usuli: ikkala manbani bir muddat parallel yuritish, so'rovlarni ko'chirish, solishtirish, keyin eskisini o'chirish.

### Real ishda qachon kerak

- Ilova OTel'ga ko'chirilgandan keyin "alert'lar jim": birinchi tekshiriladigan narsa metrika va label nomlari.
- Bitta servisning bir nechta versiyasini solishtirish: `service.version` label'da yoki `target_info` bilan join.
- Push manbalari (qisqa umrli job'lar, serverless funksiyalar): ular scrape qilinguncha yashamaydi, OTLP push tabiiy yo'l.

### Nima uchun shunday

Prometheus OTLP'ni o'z modeliga majburan tarjima qiladi, chunki PromQL va saqlash formati label'li time series atrofida qurilgan: nuqtali nomlar va turli tipdagi atributlar uchun joy yo'q edi (Prometheus 3 UTF-8 nomlarni qo'llaydi, lekin default hali ham eski shakl, eski so'rovlar buzilmasligi uchun). Loki esa index'ni kichik saqlash falsafasida (4-dars): faqat bir nechta barqaror atribut label, qolgani metadata. Muqobil yo'l, Collector'ning `prometheus` exporter'i bilan endpoint ochib Prometheus'ga scrape qildirish, `up` ni qaytaradi, lekin Collector'ning o'zi scrape target'i bo'ladi, ilovalar emas.

## 6. Connector'lar va tail sampling

### Connector nima

Connector bu bir pipeline'ning oxirida exporter, boshqasining boshida receiver bo'lib turadigan komponent. U ikki pipeline'ni bog'laydi va ko'pincha signal turini o'zgartiradi: trace'lar kiradi, metrikalar chiqadi.

```yaml
connectors:
  spanmetrics: {}
service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [spanmetrics, debug]
    metrics/from-spans:
      receivers: [spanmetrics]
      exporters: [debug]
```

Qatorma-qator: `spanmetrics` `connectors:` da e'lon qilinadi; `traces` pipeline'ida u **exporter** ro'yxatida (span'larni yeydi), `metrics/from-spans` pipeline'ida **receiver** ro'yxatida (metrika chiqaradi). Ikki tomondan ulanmasa `validate` xato beradi.

### Mexanizm: `spanmetrics`

`spanmetrics` har span'dan RED metrikalarini (1-dars) hisoblaydi: so'rovlar soni, xatolar (span status `Error`) va davomiylik histogram'i. Default o'lchamlar: `service.name`, span nomi, span turi (`span.kind`) va status kodi; `dimensions:` bilan qo'shimcha atribut (masalan `http.route`) qo'shiladi. Prometheus'da ular taxminan `traces_span_metrics_calls_total` va `traces_span_metrics_duration_milliseconds_bucket` ko'rinishida chiqadi (prefiks `namespace` sozlamasiga, birlik `histogram.unit` ga bog'liq).

Bu 5-darsdagi Tempo metrics-generator bilan bir xil ish. Farqi joyida: Tempo faqat o'ziga yetib kelgan, ya'ni sampling'dan keyingi span'lardan hisoblaydi; Collector'dagi connector esa sampling'dan oldin qo'yilsa, hamma span'dan. Ikkalasini birga yoqsangiz bir xil metrikalar ikki nom bilan chiqadi.

### Mexanizm: tail sampling Collector'da

5-darsda head sampling (qaror trace boshida, SDK'da) va tail sampling (qaror trace tugagach) farqini ko'rgansiz. `tail_sampling` processor har trace'ning span'larini `decision_wait` muddat xotirada yig'adi, keyin siyosatlarni tekshiradi:

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - { name: errors, type: status_code, status_code: { status_codes: [ERROR] } }
      - { name: rest, type: probabilistic, probabilistic: { sampling_percentage: 5 } }
```

Qatorma-qator: `decision_wait: 10s` trace'ning birinchi span'idan keyin 10 soniya kutish; shu orada kelmagan span keyin kelsa, qaror allaqachon qilingan. `errors` siyosati bitta span'i `ERROR` bo'lgan trace'ni saqlaydi. `rest` qolganining 5% ini. Siyosatlar orasida "biri saqlasa saqlanadi" mantiqi ishlaydi. Boshqa turlar ham bor (`latency`, `string_attribute`, `and`, `composite`), to'liq ro'yxat processor README'sida.

Uch oqibat:

- **Xotira.** Collector `decision_wait` davomida hamma trace'ni xotirada ushlaydi: sekundiga 1000 span va 10 soniya bu 10 000 span. `memory_limiter` shu sababli ham kerak.
- **Head sampling 100% bo'lishi kerak.** SDK trace'ning 10% ini yuborsa, tail sampling faqat shu 10% dan tanlaydi, qolgan xatolar Collector'ga hech qachon kelmaydi.
- **Replikalar.** Bitta trace'ning span'lari turli Collector replikalariga tushsa, har biri yarim trace bo'yicha qaror qiladi. Yechim: oldinda `loadbalancing` exporter'li qatlam, u span'larni trace ID bo'yicha bir xil replikaga yo'naltiradi (5-dars).

**Tartib.** Span metrikalari to'g'ri bo'lishi uchun ular sampling'dan **oldin** hisoblanishi kerak: kiruvchi pipeline span'larni connector'ga va sampling qiladigan ikkinchi pipeline'ga (masalan `forward` connector orqali) uzatadi. Bitta pipeline ichida processor'lar exporter'dan oldin ishlaydi, shuning uchun `tail_sampling` va `spanmetrics` bitta pipeline'da tursa connector faqat saqlangan span'larni ko'radi.

### Real ishda qachon kerak

- Tracing narxi oshganda: hamma xato va sekin trace saqlanadi, oddiy muvaffaqiyatli so'rovlardan kichik ulush.
- Tempo yoki boshqa backend'da metrics-generator yo'q yoki qimmat: RED metrikalarini Collector'da hisoblash.

### Nima uchun shunday

Connector'lar alohida tur qilib qo'shilishidan oldin signal turini o'zgartirish uchun exporter va receiver'ni tarmoq orqali bog'lash kerak edi: Collector o'ziga o'zi yuborardi. Connector buni jarayon ichida qiladi. Tail sampling'ning Collector'da turishi tabiiy: qaror uchun butun trace kerak, butun trace esa faqat hamma servis yuboradigan joyda, ya'ni Collector'da yig'iladi. Narxi xotira va replikalar orasidagi muvofiqlashtirish.

## 7. Chidamlilik va Collector'ni kuzatish

### Mexanizm: backend o'chsa nima bo'ladi

Exporter'larda ikki umumiy sozlama bor (exporterhelper): `retry_on_failure` (muvaffaqiyatsiz yuborishni ortib boruvchi oraliq bilan qayta urinish) va `sending_queue` (yuborishni kutayotgan partiyalar navbati).

```yaml
exporters:
  otlp_http/example:
    endpoint: http://backend:4318
    retry_on_failure: { enabled: true, max_elapsed_time: 300s }
    sending_queue: { enabled: true, queue_size: 1000 }
```

Qatorma-qator: backend javob bermasa exporter 300 soniyagacha qayta urinadi, shu vaqt ichida yangi partiyalar navbatga tushadi. Navbat to'lsa yangi ma'lumot tashlanadi va Collector log'ida "dropping data" mazmunidagi xabar chiqadi. Default navbat xotirada: Collector qayta ishga tushsa navbat yo'qoladi. Diskka yoziladigan navbat uchun `file_storage` extension va `sending_queue.storage` kerak, u volume talab qiladi.

Ilova tomonida ham xuddi shunday tuzilma bor: SDK'ning batch processor'i chegaralangan navbat ushlaydi. Collector o'lsa SDK yuborolmaydi, navbat to'lgach span'larni tashlaydi, lekin ilova so'rovlarga javob berishda davom etadi. Telemetriya ilovaning ishini to'xtatmasligi OTel'ning dizayn talabi. Xatolar ilova log'iga faqat SDK diagnostika darajasi (`OTEL_LOG_LEVEL`) yetarli bo'lsa chiqadi.

### Collector'ning ichki telemetriyasi

Collector o'z metrikalarini chiqaradi, `service.telemetry` bo'limida sozlanadi. Default'da ular Prometheus formatida `8888` portda, lekin yangi versiyalarda faqat `localhost` da. Boshqa konteyner (Prometheus) scrape qila olishi uchun:

```yaml
service:
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus: { host: 0.0.0.0, port: 8888 }
```

Eski versiyalarda bu `metrics: { address: 0.0.0.0:8888 }` deb yozilardi. Eng muhim seriyalar (versiyaga qarab oxirida `_total` bo'ladi):

| Seriya | Ma'nosi |
|--------|---------|
| `otelcol_receiver_accepted_spans` (`_metric_points`, `_log_records`) | receiver qabul qilgan yozuvlar |
| `otelcol_receiver_refused_spans` | rad etilgan (masalan `memory_limiter` sababli) |
| `otelcol_exporter_sent_spans` | backend muvaffaqiyatli qabul qilgan |
| `otelcol_exporter_send_failed_spans` | qayta urinishlardan keyin ham yuborilmagan |
| `otelcol_exporter_queue_size`, `otelcol_exporter_queue_capacity` | navbat to'lishi |

Qabul qilingan va yuborilgan sonlar farqi yo'qotishni yoki ataylab tashlashni (`filter`, sampling) ko'rsatadi; qaysi biri ekanini processor metrikalari va config ajratadi.

### Shell'siz konteynerni diagnostika qilish

Collector image'ida shell yo'q, shuning uchun diagnostika tashqaridan:

| Usul | Nima beradi |
|------|-------------|
| `docker compose logs otelcol` | ishga tushish xatolari, exporter xatolari, "Everything is ready" qatori |
| `debug` exporter | ma'lumot Collector'gacha yetib kelyaptimi |
| Ichki metrikalar (`8888`) | qancha keldi, qancha ketdi, navbat |
| `health_check` extension (default port `13133`) | tirikmi, healthcheck uchun |
| `zpages` extension (default port `55679`) | brauzerda `/debug/pipelinez`, `/debug/tracez`: pipeline'lar va so'nggi span'lar |
| `docker compose run --rm otelcol validate ...` | config xatolari, ishga tushirmasdan |

Extension'lar ham pipeline'lar kabi ikki qadamda: `extensions:` da e'lon qilinadi va `service.extensions: [health_check, zpages]` ro'yxatiga yoziladi. Endpoint default'da `localhost`, host'dan ochish uchun `0.0.0.0` va Compose'da `127.0.0.1:<port>` publish kerak. Image'da `curl` yo'qligi sababli Compose `healthcheck:` ni konteyner ichidan bajarib bo'lmaydi; holat boshqa konteynerdan yoki host'dan tekshiriladi.

### Real ishda qachon kerak

- "Telemetriya yo'qolyapti" degan shubha: `send_failed` va navbat to'lishi bo'yicha alert. Collector o'zini kuzatmasa, yo'qotishni hech qaysi dashboard ko'rsatmaydi, chunki dashboard'larning o'zi shu telemetriyaga bog'liq.
- Backend texnik xizmatga to'xtaganda qancha vaqt chidash mumkinligini hisoblash: navbat hajmi, bir partiya hajmi va kelish tezligi.

### Nima uchun shunday

Retry va navbat ilovadan Collector'ga ko'chirilgani ilovani backend nosozligidan izolyatsiya qiladi: backend o'chsa ilovaning xotirasi emas, Collector'niki to'ladi. Narxi: Collector yagona nosozlik nuqtasi bo'lib qoladi, production'da u bir nechta replika va diskdagi navbat bilan ishlaydi. Collector o'z metrikalarini Prometheus formatida berishi "monitoringni kim kuzatadi" (3-dars) savoliga javob: telemetriya yo'li o'zi ham telemetriya beradi.

## 8. Hamma narsa OTel orqalimi va incident zanjiri

### Taqqoslash

| | To'g'ridan-to'g'ri (1–6-darslar) | OTel SDK + Collector |
|---|---|---|
| Ilova bog'liqligi | har backend uchun alohida kutubxona | bitta API, bitta protokol |
| Metrikalar | pull, `up` bor, Prometheus nomlari | push, `up` yo'q, semantic conventions nomlari |
| Log'lar | stdout, platforma yig'adi | OTLP yoki baribir stdout + collector |
| Bog'lash | har signalda alohida label'lar | bir xil resource attribute'lar |
| Murakkablik | kam bo'g'in | yana bitta komponent, lekin markaziy boshqaruv |

Aralash sxema normal va keng tarqalgan: trace'lar OTel bilan (boshqa yo'l deyarli qolmagan), infratuzilma metrikalari Prometheus exporter'lari va scrape bilan (node_exporter, cAdvisor qayta yozilmaydi), ilova metrikalari jamoa tanloviga ko'ra, log'lar ko'pincha stdout orqali (ilova telemetriya tizimi ishlamasa ham yozaveradi, ishga tushishdagi crash ham ushlanadi, `docker logs` ishlaydi), profillar Pyroscope bilan. Muhimi bog'lovchi: hamma signalda bir xil `service.name` va trace ID.

### Mexanizm: alert'dan funksiyagacha

Modulning maqsadi shu yo'lni bir necha daqiqada bosib o'tish:

1. **Alert** (3-dars): symptom, masalan burn rate. Runbook birinchi dashboard'ni ko'rsatadi.
2. **Metrics** (1–2-darslar): RED dashboard: qaysi servis, qaysi route, qachondan. Deploy annotation'i bormi? USE: resurs to'yinganmi?
3. **Logs** (4-dars): shu servis va vaqt oralig'idagi error log'lar: xato matni, qaysi so'rovlar.
4. **Traces** (5-dars): exemplar yoki log'dagi `trace_id` orqali bitta sekin yoki xatoli so'rov: vaqt qaysi servis va span'da ketgan.
5. **Profiles** (6-dars): o'sha servisning shu vaqtdagi flame graph'i: qaysi funksiya.

Har qadam savolni toraytiradi: tizim → servis → so'rov → span → funksiya. Bog'lanishlar (exemplar, derived field, trace-to-logs, trace-to-profiles, bir xil `service.name`) bo'lmasa har qadamda vaqt oralig'i va servis nomini qo'lda ko'chirasiz. Ikki o'lchov muhim: **MTTD** (mean time to detect, nosozlik boshlanishidan alert'gacha) va **MTTR** (mean time to resolve yoki recover, tiklanishgacha). Alert sozlamalari (`for`, burn rate oynalari) MTTD'ni, bog'lanishlar va runbook'lar MTTR'ni belgilaydi.

### Postmortem

Postmortem bu incident'dan keyin yoziladigan hujjat: nima bo'ldi, qanday aniqlandi, nima uchun bo'ldi va takrorlanmasligi uchun nima qilinadi. **Blameless** degani aybdor qidirilmaydi: "X noto'g'ri buyruq yozdi" emas, "tizim noto'g'ri buyruqni bajarishga yo'l qo'ydi va buni hech narsa ushlamadi". Odamlar xatoni yashirmasligi uchun shunday. Odatiy bo'limlar: xulosa, ta'sir (qancha foydalanuvchi, qancha so'rov, error budget'ning qancha qismi, 3-dars), vaqt chizig'i, asosiy sabab, aniqlash qanday ishladi, nima yaxshi ishladi, harakatlar (egasi va muddati bilan).

### Real ishda qachon kerak

- On-call paytida: alert kelganda shu zanjir bo'yicha harakat, runbook'da yozilgan.
- Har jiddiy incident'dan keyin postmortem; harakatlar ro'yxatida ko'pincha observability'ning o'zi bo'ladi (yetishmagan panel, ishlamagan bog'lanish).

### Nima uchun shunday

Uch ustun (metrics, logs, traces) va profillar alohida-alohida foydali, lekin qimmatli bo'lgani ular orasida sakrash imkoni. OTel'ning asosiy hissasi yangi signal emas, umumiy kontekst: bir xil resource va bir xil trace ID hamma signalda. Muqobili, bitta vendor platformasi, bog'lanishni tayyor beradi, lekin hamma signalni bitta vendorga bog'laydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| OpenTelemetry (OTel) | telemetriyani yaratish va tashish uchun vendor'ga bog'lanmagan CNCF standarti va uning amalga oshirilishlari |
| Telemetriya | ilova o'zi haqida chiqaradigan ma'lumot: metrika, log, trace, profil |
| Signal | OTel'dagi telemetriya turi: traces, metrics, logs, baggage, profiles |
| API | kod chaqiradigan interfeys, SDK ulanmasa no-op |
| SDK | API'ning amalga oshirilishi: sampling, batching, resource, exporter |
| Instrumentatsiya | kodga telemetriya chiqaradigan chaqiruvlarni qo'shish, auto yoki manual |
| OTLP | OpenTelemetry Protocol, gRPC (`4317`) va HTTP (`4318`) orqali |
| Resource | telemetriya manbasini tavsiflovchi atributlar to'plami (`service.name` va boshqalar) |
| Semantic conventions | atribut va metrika nomlarining umumiy lug'ati |
| Collector | telemetriyani qabul qiladigan, qayta ishlaydigan va jo'natadigan alohida jarayon |
| Agent / gateway | ilova yonidagi Collector / markaziy Collector |
| Distributsiya | ma'lum komponentlar to'plamidan yig'ilgan Collector binary'si (core, contrib, o'zingizniki) |
| Receiver | Collector'ga ma'lumot kiradigan komponent |
| Processor | pipeline ichida ma'lumotni o'zgartiradigan yoki tashlaydigan komponent |
| Exporter | ma'lumotni Collector'dan tashqariga jo'natadigan komponent |
| Connector | bir pipeline uchun exporter, boshqasi uchun receiver bo'lgan komponent |
| Extension | pipeline'dan tashqaridagi yordamchi komponent (`health_check`, `zpages`) |
| Pipeline | bitta signal uchun receiver → processor'lar → exporter yo'li |
| OTTL | `filter` va `transform` processor'laridagi shart va o'zgartirish tili |
| `debug` exporter | kelgan ma'lumotni Collector log'iga yozadigan exporter |
| `target_info` | Prometheus'da label'ga ko'tarilmagan resource attribute'lar saqlanadigan seriya |
| Promote | resource attribute'ni Prometheus metrika label'iga ko'tarish |
| Structured metadata | Loki'da index'ga kirmaydigan, lekin filtrlanadigan kalit-qiymatlar |
| Sending queue | exporter'da yuborishni kutayotgan partiyalar navbati |
| `spanmetrics` | span'lardan RED metrikalarini hisoblaydigan connector |
| MTTD / MTTR | nosozlikni aniqlash / tiklashgacha o'rtacha vaqt |
| Postmortem (blameless) | incident tahlili hujjati, aybdor emas, tizimdagi bo'shliq qidiriladi |

## Tuzoqlar

- Komponentni e'lon qilib, pipeline'ga qo'shmaslik: Collector xatosiz ishga tushadi, ma'lumot yo'q. Extension'lar uchun ham xuddi shunday (`service.extensions`).
- Receiver'ni default `localhost` da qoldirish: boshqa konteynerlar ulana olmaydi. Aksincha, OTLP portlarini host'da `0.0.0.0` ga publish qilish: tarmoqdagi har kim telemetriya yubora oladi.
- Konteyner ichidan `localhost:4318` ga yuborish: bu ilovaning o'z konteyneri, Collector emas.
- gRPC exporter'ni `4318` ga yoki HTTP exporter'ni `4317` ga yo'naltirish; HTTP manzilga `/v1/traces` ni qo'lda qo'shib, yo'lni ikki marta yozish.
- `memory_limiter` siz Collector yoki konteyner limitidan katta `limit_mib`: yuklama cho'qqisida OOM, hamma signal birga yo'qoladi.
- `batch` ni filtr va sampling'dan oldin qo'yish.
- `service.name` ni belgilamaslik: hamma narsa `unknown_service`.
- OTel'ga o'tishda metrika va label nomlari o'zgarishini hisobga olmaslik: alert'lar jim, dashboard'lar bo'sh. Bucket chegaralarini tekshirmaslik.
- Resource attribute'larni hammasini Prometheus label'iga ko'tarish: `service.instance.id`, `container.id` har restart'da yangi, cardinality o'sadi.
- Push metrikalarida `up` yo'qligini unutish: `InstanceDown` alert'i bu servislar uchun jim.
- Log'larni ikki yo'ldan (stdout va OTLP) parallel yuborib, Loki'da dublikat saqlash.
- `spanmetrics` ni ham Collector'da, ham Tempo metrics-generator'da yoqish.
- Head sampling'ni pasaytirib tail sampling'ni yoqish, yoki tail sampling'ni bir nechta replikada trace ID bo'yicha yo'naltirishsiz ishlatish.
- Collector'ni kuzatmaslik: telemetriya yo'qolayotganini hech qaysi dashboard ko'rsatmaydi.
- Eski qo'llanmalardan config ko'chirish: `logging` exporter (`debug` ga almashgan), `otlp`/`otlphttp` nomlari, Loki uchun alohida exporter (Loki OTLP'ni o'zi qabul qiladi), Jaeger exporter (OTLP bilan almashgan), `telemetry.metrics.address`.
- `debug` exporter'ni `detailed` da qoldirish: yuklama ostida log diskni to'ldiradi.
- `docker system prune` yoki `docker volume prune -a` bilan tozalash: boshqa loyihalarning volume'lari ham o'chadi.

## Manbalar

- https://opentelemetry.io/docs/concepts/ – tushunchalar: signallar, komponentlar, resource (majburiy)
- https://opentelemetry.io/docs/specs/status/ – spetsifikatsiyada signallar holati
- https://opentelemetry.io/docs/languages/ – til SDK'lari va ularning holati
- https://opentelemetry.io/docs/languages/sdk-configuration/ – `OTEL_*` env o'zgaruvchilari
- https://opentelemetry.io/docs/specs/semconv/ – semantic conventions
- https://opentelemetry.io/docs/specs/otlp/ – OTLP spetsifikatsiyasi, JSON kodlash
- https://opentelemetry.io/docs/collector/configuration/ – Collector config: komponentlar, pipeline'lar, env
- https://opentelemetry.io/docs/collector/deployment/ – agent va gateway sxemalari
- https://opentelemetry.io/docs/collector/install/docker/ – Collector Docker'da
- https://opentelemetry.io/docs/collector/internal-telemetry/ – Collector'ning o'z metrikalari
- https://opentelemetry.io/docs/collector/custom-collector/ – `ocb` bilan o'z distributsiyangiz
- https://github.com/open-telemetry/opentelemetry-collector-contrib – contrib komponentlari README'lari (`tail_sampling`, `spanmetrics`, `filter`)
- https://github.com/open-telemetry/opentelemetry-collector-releases/releases – Collector versiyalari
- https://prometheus.io/docs/guides/opentelemetry/ – Prometheus'da OTLP qabul qilish, `promote_resource_attributes`
- https://grafana.com/docs/loki/latest/send-data/otel/ – Loki'ga OTLP log yuborish, label va structured metadata
- https://sre.google/sre-book/postmortem-culture/ – blameless postmortem

## Birga bajaramiz

Stack'dan tashqarida, alohida bitta Collector'ni ko'taramiz, unga `curl` bilan qo'lda ikki span yuboramiz, `filter` processor health check span'ini tashlaganini `debug` chiqishi va Collector'ning ichki metrikalarida ko'ramiz. Ilova ham, backend ham yo'q: maqsad Collector ichidagi oqimni ko'rish. Vazifalardagi holatlardan farqi: stack, `api` va Tempo ishtirok etmaydi. Hamma buyruq host'da, Zorin va macOS'da bir xil. Host portlari `14318` va `18888` tanlangan, stack'dagi portlar bilan to'qnashmasin.

1. Papka repo'dan tashqarida:

```
mkdir -p ~/otel-demo && cd ~/otel-demo
```

2. `~/otel-demo/config.yaml`:

```yaml
receivers:
  otlp:
    protocols:
      http: { endpoint: 0.0.0.0:4318 }
processors:
  memory_limiter: { check_interval: 1s, limit_mib: 200 }
  filter/healthz:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
  batch: {}
exporters:
  debug: { verbosity: detailed }
service:
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus: { host: 0.0.0.0, port: 8888 }
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, filter/healthz, batch]
      exporters: [debug]
```

Processor'lar 4-bo'lim qoidasi bo'yicha: `memory_limiter` birinchi, tashlovchi `filter` o'rtada, `batch` oxirida. `telemetry` bo'limi 7-bo'limdagi ichki metrikalarni konteyner tashqarisiga ochadi.

3. Config'ni tekshirish (`<versiya>` o'rniga Laboratoriya'da tanlagan tag):

```
$ docker run --rm -v "$PWD/config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
    otel/opentelemetry-collector-contrib:<versiya> validate --config=/etc/otelcol-contrib/config.yaml
$ echo $?
0
```

Chiqish bo'sh va exit code `0`: config to'g'ri. Image'ning entrypoint'i Collector binary'si, shuning uchun `validate` uning subbuyrug'i sifatida ishlaydi. Sizdagi versiya telemetriya kalitlarini boshqacha kutsa, xato shu yerda chiqadi va qaysi kalit ekanini aytadi.

4. Ishga tushirish, portlar faqat loopback'da:

```
$ docker run -d --name otel-demo \
    -p 127.0.0.1:14318:4318 -p 127.0.0.1:18888:8888 \
    -v "$PWD/config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
    otel/opentelemetry-collector-contrib:<versiya>
$ docker logs otel-demo 2>&1 | tail -n 2
<vaqt>	info	<...>	Starting HTTP server	{"endpoint": "[::]:4318", <...>}
<vaqt>	info	<...>	Everything is ready. Begin running and processing data.
```

Birinchi qator: OTLP HTTP receiver konteynerning hamma interfeyslarida (`[::]` IPv6 yozuvidagi "hammasi") `4318` da tinglayapti. Ikkinchisi: hamma pipeline yig'ildi. Bu qator yo'q bo'lsa, undan oldingi `error` qatorini qidiring. macOS'da `docker logs` xuddi shunday ishlaydi, faqat port uzatish Docker Desktop VM orqali.

5. Ikki span'li so'rov. `~/otel-demo/spans.json` (OTLP JSON: ID'lar hex satr, vaqt nanosekundda satr, `kind: 2` server span, `status.code: 2` xato):

```json
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"demo-cli"}}]},
"scopeSpans":[{"scope":{"name":"manual-curl"},"spans":[
{"traceId":"5b8efff798038103d269b633813fc60c","spanId":"eee19b7ec3c1b174","name":"GET /healthz","kind":2,
 "startTimeUnixNano":"1759917600000000000","endTimeUnixNano":"1759917600002000000",
 "attributes":[{"key":"http.route","value":{"stringValue":"/healthz"}}]},
{"traceId":"0af7651916cd43dd8448eb211c80319c","spanId":"b7ad6b7169203331","name":"POST /orders","kind":2,
 "startTimeUnixNano":"1759917600000000000","endTimeUnixNano":"1759917600350000000",
 "attributes":[{"key":"http.route","value":{"stringValue":"/orders"}}],"status":{"code":2}}]}]}]}
```

```
$ curl -s -X POST http://127.0.0.1:14318/v1/traces \
    -H 'Content-Type: application/json' --data @spans.json
{"partialSuccess":{}}
```

`partialSuccess` bo'sh obyekt: receiver hamma yozuvni qabul qildi. Bu "backend'ga yetdi" degani emas, faqat "Collector'ga kirdi" degani.

6. `debug` chiqishi:

```
$ docker logs otel-demo 2>&1 | grep -E 'Traces|Name|http.route|Status code'
<vaqt>	info	Traces	{<...>, "resource spans": 1, "spans": 1}
    Name           : POST /orders
    Status code    : Error
     -> http.route: Str(/orders)
```

Ikki span yuborildi, `debug` ga bittasi yetdi: `GET /healthz` `filter/healthz` da tashlandi. `Status code: Error` JSON'dagi `code: 2`. `debug` exporter pipeline oxirida turgani uchun u processor'lardan keyingi holatni ko'rsatadi, ya'ni "exporter'ga nima ketyapti".

7. Ichki metrikalar:

```
$ curl -s http://127.0.0.1:18888/metrics | grep -E '^otelcol_(receiver_accepted|exporter_sent)_spans'
otelcol_exporter_sent_spans_total{exporter="debug",<...>} 1
otelcol_receiver_accepted_spans_total{receiver="otlp",transport="http",<...>} 2
```

Receiver 2 ta qabul qildi, exporter 1 ta yubordi. Farq 1: bu yerda u ataylab tashlash (`filter`), production'da esa bunday farq yo'qotish ham bo'lishi mumkin, shuning uchun processor'lar config'ini bilmasdan farqni talqin qilib bo'lmaydi (7-bo'lim). Suffiks `_total` va qo'shimcha label'lar versiyaga bog'liq.

8. Tozalash:

```
docker rm -f otel-demo
rm -r ~/otel-demo
docker ps -a --filter name=otel-demo
```

Oxirgi buyruq faqat sarlavha qatorini qaytarishi kerak.

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 2 | 3-bo'lim: e'lon va pipeline; 4-bo'lim: processor tartibi, `filter` |
| 3–4 | Laboratoriya: `validate`, receiver manzili, loopback publish |
| 5 | 2-bo'lim: OTLP/HTTP, resource va atribut |
| 6 | 3-bo'lim: `debug` exporter; 4-bo'lim: tashlash |
| 7 | 7-bo'lim: ichki telemetriya, qabul va yuborish farqi |

---

## Vazifalar

Javoblar `observability/07-opentelemetry/README.md` da (`make new m=observability n=07 name=opentelemetry`), har vazifa uchun `## N. Title` ostida: config'ning muhim qismi, buyruq, kuzatilgan natija va o'z so'zingiz bilan izoh. Stack fayllari (`otelcol/config.yaml`, yangilangan `compose.yaml`, provisioning, qoidalar) `observability/stack/` da; mini-loyiha hisoboti `observability/07-opentelemetry/postmortem.md` da. Hamma buyruq host'da `observability/stack/` papkasidan, `docker compose` orqali, ikkala mashinada bir xil. README'da har o'lchov yonida qaysi mashinada (Zorin yoki macOS) olinganini yozing. Yuklama uchun `loadgen` yoki `curl` siklidan foydalaning, ish mashinasining o'zini yuklamang.

### A. Collector asoslari

1. **Collector with debug exporter.** `otelcol` servisini qo'shing. Config: OTLP receiver (gRPC va HTTP), `debug` exporter, uchala signal uchun pipeline. `validate` buyrug'i toza o'tsin. `api` ni Collector'ga yo'naltiring (faqat trace'lar) va Collector log'ida span'lar kelayotganini ko'rsating. `debug` verbosity'ni `detailed` qilib bitta span'ning resource va atributlarini yozing. Yo'nalish: Laboratoriya ("Manzillar"), 2-bo'lim (span tarkibi), 3-bo'lim.

2. **Declared but not wired.** Config'ga `otlp_grpc/tempo` exporter'ini e'lon qiling (sizdagi versiyada tur nomi boshqacha bo'lsa, `components` chiqishidagisini), lekin pipeline'ga qo'shmang. Collector xato beradimi? Trace Tempo'da bormi? Keyin pipeline'ga mavjud bo'lmagan komponent nomini yozing: `validate` nima deydi? Ikkalasini tuzating. Yo'nalish: 3-bo'lim, "Mexanizm: komponentlar va pipeline".

3. **Traces through the Collector.** Trace'larni Collector orqali Tempo'ga yuboring, ikkala ilovada ham (`api`, `inventory`). Ilovalardagi backend manzillarini olib tashlang: ular faqat Collector'ni bilsin. Grafana'da 5-darsdagi trace-to-logs va TraceQL so'rovlari hali ishlashini tekshiring. Yo'nalish: 5-bo'lim, yo'nalishlar jadvali.

4. **Shell-less image.** `docker compose exec otelcol sh` ni sinang va xatoni yozing. Shell'siz konteynerni qanday diagnostika qilasiz: kamida uch usulni amalda ko'rsating (log, `debug` exporter, ichki metrikalar yoki `zpages` extension). Yo'nalish: 7-bo'lim, "Shell'siz konteynerni diagnostika qilish".

5. **Processors.** `memory_limiter` va `batch` ni qo'shing. `resource` yoki `attributes` processor bilan hamma telemetriyaga `deployment.environment.name=lab` qo'shing va bitta maxfiy deb hisoblangan atributni (masalan `http.request.header.authorization` yoki o'zingiz qo'shgan sinov atributi) o'chiring. Tempo'dagi span'da natijani ko'rsating. Processor'lar tartibini nima uchun shunday tanladingiz? `memory_limiter` chegarasini Collector konteynerining xotira limiti bilan solishtiring. Yo'nalish: 4-bo'lim.

### B. Metrics va logs OTel orqali

6. **OTLP metrics to Prometheus.** Prometheus'da OTLP qabul qilishni yoqing. Ilovada OTel metrikalarini yoqing (auto-instrumentation HTTP metrikalari va bitta o'z counter'ingiz, masalan `shop.checkouts`). Collector'da `metrics` pipeline'ini Prometheus'ga ulang. Prometheus'da yangi seriyalarni toping: nomi, `job`, `instance` qanday shakllangan? Yo'nalish: 5-bo'lim, "Mexanizm: Prometheus OTLP metrikalarini qanday qabul qiladi".

7. **Names changed.** 1-darsdagi `prom-client`/`client_golang` metrikalari va OTel metrikalarini yonma-yon solishtiring: nom, label'lar, bucket chegaralari, birlik. 1-darsdagi p95 so'rovini OTel metrikalari uchun qayta yozing. Eski dashboard va alert'lardan qaysilari buzilardi? Migratsiya rejasini 4–5 qadamda yozing. Yo'nalish: 5-bo'lim, "Tuzoq: nomlar o'zgaradi".

8. **Resource attributes as labels.** `target_info` seriyasini ko'rsating. `service.version` ni ilovada belgilang va u metrikada label emasligini ko'rsating. `otlp.promote_resource_attributes` bilan label'ga ko'taring. Keyin `service.instance.id` ni ham ko'tarib, ilovani 5 marta restart qiling: series soni nima bo'ldi? Oxirida `service.instance.id` ni ro'yxatdan olib tashlang. Yo'nalish: 5-bo'lim, `target_info`.

9. **No up metric.** `api` ni to'xtating. OTLP orqali kelayotgan metrikalar bilan nima bo'ladi, `up` bormi? 3-darsdagi `InstanceDown` alert'i bu servisni ushlaydimi? Push modelida "servis o'ldi"ni aniqlashning ikki usulini taklif qiling va bittasini amalga oshiring. Yo'nalish: 5-bo'lim, "`up` yo'q"; 3-dars, ma'lumot yo'q bo'lsa alert ham yo'q.

10. **OTLP logs to Loki.** Ilova log'larini OTel orqali ham yuboring (Node.js: logger instrumentation'i va `OTEL_LOGS_EXPORTER`, Go: slog bridge) va Collector'da `logs` pipeline'ini Loki'ning OTLP endpoint'iga ulang. Loki'da bu log'lar qanday label'lar bilan paydo bo'ldi, `trace_id` qayerda (label, structured metadata yoki matn)? LogQL bilan bitta trace'ning log'larini toping. Yo'nalish: 5-bo'lim, "Mexanizm: Loki OTLP log'larini qanday qabul qiladi".

11. **Stdout or OTLP logs.** Hozir log'lar ikki yo'ldan kelyapti (Alloy orqali stdout va OTLP). Loki'da dublikatni ko'rsating. Ikki yo'lni solishtiring: ilova boshlanishidagi crash log'i, Collector o'lgan payt, `docker logs`, tilingiz SDK'sida logs holati. Bittasini tanlab, ikkinchisini o'chiring va qarorni asoslang. Yo'nalish: 1-bo'lim (signallar holati), 8-bo'lim.

12. **Span metrics connector.** Collector'da `spanmetrics` connector bilan trace'lardan RED metrikalari chiqaring va Prometheus'ga yuboring. Tempo metrics-generator (5-dars) bilan bir xil ishni ikki joyda qilmaslik uchun bittasini qoldiring. Connector pipeline'da qanday ulanishini (qaysi pipeline'da exporter, qaysisida receiver) chizib ko'rsating. Yo'nalish: 6-bo'lim, "Connector nima" va "`spanmetrics`".

### C. Sampling va chidamlilik

13. **Tail sampling.** Ilovalarda head sampling'ni 100% ga qaytaring va Collector'da `tail_sampling` yoqing: xatoli va 500 ms dan sekin trace'lar to'liq, qolgani 10%. 500 ta so'rovdan keyin Tempo'da nechta trace qoldi, ular orasida xatolilar ulushi qancha? Span metrikalari sampling'dan oldin hisoblanayotganini tekshiring (pipeline'lar tartibi). Yo'nalish: 6-bo'lim, "Mexanizm: tail sampling Collector'da" va "Tartib".

14. **Backend down.** Tempo'ni 2 daqiqaga to'xtating. Collector log'i va `otelcol_exporter_send_failed_*`, navbat metrikalarida nima ko'rinadi? Tempo qaytgach trace'lar yetib keldimi? Keyin Collector'ning o'zini to'xtating: ilova so'rovlarga javob berishda davom etadimi, ilova log'ida nima bor? Yo'nalish: 7-bo'lim, "Mexanizm: backend o'chsa nima bo'ladi".

15. **Watch the Collector.** Collector ichki metrikalarini Prometheus'da scrape qiling. Dashboard paneli qo'shing: signal bo'yicha qabul qilingan va yuborilgan birliklar tezligi, yuborish xatolari, navbat. "Collector telemetriya yo'qotyapti" alert qoidasini yozing va 14-vazifadagi usul bilan sinang. Yo'nalish: 7-bo'lim, "Collector'ning ichki telemetriyasi"; 3-dars, alert qoidalari.

### D. Mini-loyiha

16. **Stack as code.** `observability/stack/` ni yakuniy holatga keltiring: bitta `compose.yaml`, hamma image aniq versiyada, healthcheck'lar va `depends_on` shartlari, og'ir servislar profillarda, secret'lar `.env` va fayllarda (repoda yo'q), har servisga xotira limiti. `docker compose down -v` dan keyin bitta `docker compose up -d` bilan hammasi ko'tarilsin. `stack/README.md` da arxitektura sxemasi: har signal ilovadan backend'gacha qaysi yo'ldan boradi, portlar. Ikkinchi mashinada Laboratoriya'dagi "Ikkinchi mashinada tiklash" qadamlari bilan tekshiring va natijani yozing. Yo'nalish: Laboratoriya; docker moduli, Compose darslari.

17. **Dashboards and alerts.** Provisioning'dan keladigan to'plamni yakunlang: servis RED dashboard'i (exemplar, log paneli, flame graph paneli, deploy annotation'lari bilan), USE dashboard'i, Collector dashboard'i; alert'lar: burn rate, latency, `InstanceDown` yoki uning push ekvivalenti, Watchdog, Collector yo'qotishi. Har alert'da runbook havolasi. Hammasi tanlagan metrika nomlaringiz (eski yoki OTel) bilan izchil bo'lsin. Yo'nalish: 2–3-darslar; 5-bo'lim (nomlar).

18. **Fault injection.** Ilovaga boshqariladigan nosozliklar qo'shing (env yoki ichki admin endpoint orqali yoqiladi): `inventory` da ma'lum mahsulotlar uchun CPU'ni yeydigan sekin kod yo'li, va `api` da `inventory` ga qisqa timeout (sekinlik xatoga aylanadi). Nosozlik yoqilganda nima bo'lishini oldindan taxmin qilib yozing: qaysi metrika, qaysi alert, qancha vaqtda. Admin endpoint host'ga publish qilinsa, faqat `127.0.0.1` da. Yo'nalish: 8-bo'lim, "Mexanizm: alert'dan funksiyagacha".

19. **Simulated incident.** Nosozlikni yoqing va vaqtni belgilang. Faqat observability vositalari bilan (kodga qaramasdan) tekshiring: alert xabari → RED/USE dashboard → error log'lar → trace → profil. Har qadamda ishlatilgan so'rovni (PromQL, LogQL, TraceQL), ko'rgan narsangizni va keyingi qadamga nima olib o'tganingizni yozing. Aniqlashgacha (alert kelguncha) va sababni topguncha ketgan vaqtni o'lchang. Yo'nalish: 8-bo'lim, MTTD va MTTR.

20. **Postmortem.** `postmortem.md` yozing (blameless): xulosa, ta'sir (qancha so'rov, error budget'ning qancha qismi), vaqt chizig'i, asosiy sabab, aniqlash qanday ishladi va qayerda sekinlashdi, nima yaxshi ishladi, harakatlar ro'yxati (egasi va muddati bilan). Kamida bitta harakat observability'ning o'ziga tegishli bo'lsin (yetishmagan panel, bog'lanish, alert yoki runbook). Yo'nalish: 8-bo'lim, "Postmortem".

21. **Close the gap.** Postmortem'dagi observability harakatlaridan kamida ikkitasini amalga oshiring. Nosozlikni tuzating, keyin uni qayta yoqib tekshiruvni takrorlang: sababgacha yetish vaqti qanchaga qisqardi? Yakunda butun stack'ni tozalang va `docker volume ls`, `docker ps -a` chiqishini yozing. Yo'nalish: Laboratoriya, "Tozalash".

### Topshirish

Tayyor bo'lgach:
1. 21 ta vazifaning javobi `observability/07-opentelemetry/README.md` da, `## N. Title` sarlavhalari ostida; `postmortem.md` va `stack/README.md` (arxitektura) yozilgan.
2. `docker compose config -q`, Collector `validate`, `promtool check config`, `promtool check rules`, `amtool check-config` toza (konteyner ichidan yoki `docker compose run --rm` bilan).
3. `make check` toza; `.env`, token'lar, volume ma'lumotlari repoda yo'q (`git status` da `.env` ko'rinmaydi).
4. Stack ikkinchi mashinada `git pull`, `.env` va `docker compose up -d` bilan ko'tarilgan, natija README'da.
5. Sinov uchun o'zgartirilgan narsalar qaytarilgan (nosozlik o'chiq, `debug` verbosity `basic`, ko'tarilgan `service.instance.id` olib tashlangan).
6. Butun modul tozalangan: `docker compose --profile "*" down -v`, stack'dan konteyner va volume qolmagan.
7. Menga "tekshir" deb xabar bering: stack'ni toza holatdan ko'tarib, incident ssenariysini birga ko'rib chiqamiz.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- OpenTelemetry nima va nima emas? API bilan SDK nima uchun ajratilgan?
- Resource attribute va span atributi farqi nima? `service.name` belgilanmasa nima bo'ladi?
- Semantic conventions qanday muammoni hal qiladi va migratsiyada qanday muammo tug'diradi?
- Collector ilova va backend orasida nima beradi, narxi nima? Agent va gateway farqi?
- Receiver, processor, exporter, connector va extension vazifalari qanday farq qiladi? Komponent e'lon qilingan, lekin ishlamayotgan bo'lsa birinchi gumon nima?
- `memory_limiter` va `batch` pipeline'ning qayerida turadi va nima uchun?
- Konteynerda receiver nima uchun `0.0.0.0` da tinglashi kerak, host'da port esa nima uchun `127.0.0.1` ga publish qilinadi?
- Resource attribute Prometheus va Loki'da nimaga aylanadi? `target_info` nima uchun bor?
- OTLP push metrikalarida `up` yo'qligi nimani o'zgartiradi?
- `spanmetrics` ni sampling'dan oldin yoki keyin qo'yish natijani qanday o'zgartiradi?
- Tail sampling bir nechta Collector replikasida nima uchun buziladi?
- Backend o'chganda telemetriya qayerda kutadi va qachon yo'qoladi? Collector o'chganda-chi?
- Collector telemetriya yo'qotayotganini qanday bilasiz?
- Profiles signali OpenTelemetry'da hozir qanday holatda va buni qayerdan tekshirasiz?
- Alert'dan funksiyagacha bo'lgan zanjirda har signal qaysi savolga javob beradi va ular nima orqali bog'lanadi?
- Uydagi Mac'da `hostmetrics` yoki `cadvisor` raqamlari nima uchun ofisdagidan boshqacha?
