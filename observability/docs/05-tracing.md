# 5-dars: Distributed tracing

Maqsad: bitta so'rov bir nechta servisdan o'tganda vaqt qayerda ketganini va xato qayerda tug'ilganini ko'rish. Metrika "p95 o'sdi" deydi (1-dars), log har jarayonning o'z hikoyasini aytadi (4-dars), trace esa ularni bitta so'rov bo'yicha sababiy daraxtga bog'laydi. Bu darsda trace qanday tuzilganini (span, parent ID), kontekst servislar orasida va jarayon ichida qanday uzatilishini (W3C `traceparent`, async context), nima uchun hamma trace saqlanmasligini (sampling) noldan o'rganasiz. Keyin namuna ilovaga ikkinchi servis qo'shib ikkalasini instrumentatsiya qilasiz, trace'larni Jaeger va Tempo'da ko'rasiz va ularni metrikalar hamda log'lar bilan bog'laysiz. Instrumentatsiya OpenTelemetry SDK bilan qilinadi; uning ichki tuzilishi, Collector va qolgan signallar 7-darsda.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar, "Birga bajaramiz" va A guruhning 1–2 vazifalari. Ikkinchi kun 3–4 bo'limlar va A guruhning qolgani (3–5). Uchinchi kun 5-bo'lim va B guruh (Jaeger). To'rtinchi kun 6-bo'lim va C guruh (Tempo, TraceQL, sampling). Beshinchi kun 7-bo'lim, D guruh va mini-loyiha. Diqqatni quyidagilarga qarating: span daraxti qanday yig'iladi (parent ID), propagation uzilganda nima ko'rinadi, head va tail sampling qarori qayerda qabul qilinadi, exemplar va `trace_id` orqali signallar orasida qanday o'tiladi.

Qanday o'qish kerak: har bo'limdagi misol trace'ni qog'ozda yoki boshingizda o'zingiz yig'ib ko'ring (qaysi span kimning bolasi, vaqt qayerda ketdi), keyin "Birga bajaramiz" da xuddi shunday trace'ni qo'lda yuborib UI'da ko'rasiz. ID'lar, vaqtlar va versiyalar sizda boshqa bo'ladi; bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hamma narsa ikkala mashinada ham host'dagi Docker Compose'da, yagona stack papkasi `observability/stack/` ichida ishlaydi (1–4 darslarda yig'ilgan stack ustiga). `lab` VM bu modulda ishlatilmaydi: stack uning 2G xotirasiga sig'maydi. Host'ga hech narsa o'rnatilmaydi, SDK paketlari ilova image'i ichida o'rnatiladi.

Bu darsda qo'shiladigan servislar:

| Servis | Nima | Portlar |
|--------|------|---------|
| `inventory` | ikkinchi namuna servis, siz yozasiz (Node.js yoki Go) | `8001` |
| `tempo` | trace backend | HTTP API `3200`, OTLP gRPC `4317`, OTLP HTTP `4318` |
| `jaeger` | ikkinchi trace backend, faqat `jaeger` profilida | UI `16686`, OTLP `4317`/`4318` |

Versiyalar: https://github.com/grafana/tempo/releases va https://www.jaegertracing.io/download/ . `latest` yozilmaydi, aniq tag tanlanadi. Image'lar multi-arch bo'lishi kerak (`amd64` va `arm64`); ishonchingiz komil bo'lmasa registry sahifasida tag'ning arxitekturalar ro'yxatini tekshiring. Tempo uchun ishlaydigan namuna config'lar: https://github.com/grafana/tempo/tree/main/example/docker-compose .

```
cd observability/stack
mkdir -p tempo app-inventory
docker compose up -d tempo inventory
docker compose --profile jaeger up -d jaeger     # group B only
curl -s localhost:3200/ready                     # Tempo readiness, only if 3200 is published
```

Portlar qoidasi:

- UI va API portlari host'ga faqat `127.0.0.1` ga bog'lab publish qilinadi (`"127.0.0.1:3200:3200"`), aks holda ular ofis tarmog'idagi hammaga ochiladi.
- OTLP portlarini (`4317`, `4318`) host'ga publish qilish shart emas: ilovalar Compose tarmog'ida servis nomi bilan yuboradi (`http://tempo:4318`). Jaeger va Tempo ikkalasi ham shu portlarni tinglaydi, host'ga ikkalasini publish qilsangiz to'qnashadi.
- Konteyner ichida `localhost` shu konteynerning o'zi (docker moduli, 3–4 darslar). Shuning uchun Compose ichida servislar bir-birini va exporter endpoint'ini servis nomi bilan chaqiradi: `http://inventory:8001`, `http://tempo:4318`. Agar ishlab chiqish paytida servisni Compose'dan tashqarida, to'g'ridan-to'g'ri host'da ishga tushirsangiz, endpoint host'ga publish qilingan port bo'ladi (`http://localhost:4318`), konteynerdan host'dagi jarayonga esa `host.docker.internal` orqali boriladi. Bu nom Docker Desktop'da (Mac) tayyor, Linux Engine'da (Zorin) Compose servisiga `extra_hosts: ["host.docker.internal:host-gateway"]` qo'shilsa paydo bo'ladi.

| Mashina | Zorin (ofis) | macOS (uy) |
|---------|--------------|------------|
| Arxitektura | image'lar `amd64` | image'lar `arm64` |
| Xotira | konteynerlar host RAM'ini to'g'ridan-to'g'ri ishlatadi | Docker Desktop VM'i chegarasi bor: `docker info` dagi `Total Memory` ni tekshiring, to'liq stack 3–4 GB oladi |
| `host.docker.internal` | `extra_hosts` bilan qo'shiladi | tayyor |
| Konteyner IP'lari | host'dan ko'rinadi, lekin darsda ishlatilmaydi | host'dan ko'rinmaydi (yashirin VM), faqat publish qilingan portlar |
| Soat | hamma konteyner host kernel'i soatidan foydalanadi | hamma konteyner Docker Desktop VM'i soatidan foydalanadi |

Ikkala holatda ham konteynerlar bitta soatni bo'lishadi, shuning uchun laboratoriyada span vaqtlari bir-biriga mos chiqadi. Alohida serverlarda bu o'z-o'zidan bo'lmaydi (Tuzoqlar).

Ikkinchi mashinada tiklash: `compose.yaml`, `tempo/tempo.yaml`, Grafana provisioning fayllari va servislar kodi git orqali keladi (`git pull`). Trace ma'lumoti volume'da turadi va ko'chmaydi. Shuning uchun ikkinchi mashinada: untracked `.env` ni qayta yarating (u commit qilinmaydi, `make secrets` commit qilingan `.env` ni rad etadi), `docker compose up -d --build` qiling va `loadgen` yangi trace'lar hosil qilguncha bir daqiqa kuting. Oldingi mashinadagi trace ID'lar bu yerda topilmaydi, bu normal.

Mashg'ulot oxirida: `docker compose --profile jaeger down` (volume'lar qoladi). `docker system prune` va `docker volume prune -a` ishlatilmaydi: ular boshqa darslarning ma'lumotini ham o'chiradi.

---

## 1. Trace modeli

### Tracing qaysi savolga javob beradi

Brauzer DevTools'ning Network tabidagi waterfall sizga tanish: har so'rov gorizontal chiziq, chap cheti boshlanish vaqti, uzunligi davomiyligi. Lekin brauzer faqat bitta sakrashni ko'radi: "`/api/cart` 240 ms kutdi". Server ichida bu 240 ms qayerga ketganini (gateway, boshqa servis, ma'lumotlar bazasi) u bilmaydi. Distributed tracing shu waterfall'ning serverlar ichidagi davomi: so'rov har servisdan o'tganda har bir ish bo'lagi alohida chiziq bo'lib yoziladi va hammasi bitta rasmga yig'iladi.

Oldingi signallar bu savolga javob bera olmaydi. Metrika (1-dars) agregat: histogram "`/cart` ning p95 qiymati 800 ms bo'ldi" deydi, lekin aynan qaysi so'rov va uning ichida nima sekin ekanini aytmaydi. Log (4-dars) bitta jarayon aytgan gaplar: request ID bilan bir servis ichidagi qatorlarni topasiz, lekin ikki servisning log'larini sababiy tartibda ("bu chaqiruv o'sha so'rovning ichida bo'lgan") bog'laydigan narsa yo'q. Trace aynan shu bog'lanishni saqlaydi.

### Span

Span bu bitta ish birligining yozuvi: kiruvchi HTTP so'rovga ishlov berish, chiquvchi so'rov, DB so'rovi yoki bitta funksiya. Span boshlanganda vaqt belgilanadi, tugaganda (`end`) u tayyor bo'ladi va yuboriladi.

| Maydon | Ma'nosi |
|--------|---------|
| `trace_id` | 128 bit (16 bayt, 32 hex belgi), butun so'rov uchun bitta |
| `span_id` | 64 bit (8 bayt, 16 hex belgi), shu span uchun |
| `parent_span_id` | ota span'ning `span_id` si; bo'sh bo'lsa bu **root span** (trace'ning birinchi span'i) |
| name | past cardinality'li nom: `GET /cart/:id`, aniq URL emas |
| kind | span'ning roli: `SERVER`, `CLIENT`, `INTERNAL`, `PRODUCER`, `CONSUMER` |
| start, end | boshlanish va tugash vaqti (nanosekund aniqlikda) |
| attributes | kalit-qiymat juftlari: `http.request.method`, `http.response.status_code`, `db.system.name` |
| events | span ichidagi vaqt belgili yozuvlar, masalan exception |
| status | `Unset` (default), `Ok`, `Error` |

Cardinality (1-dars) bu maydon qabul qiladigan turli qiymatlar soni. Kind qiymatlari: `SERVER` kiruvchi so'rovga ishlov berish, `CLIENT` chiquvchi so'rov, `INTERNAL` jarayon ichidagi ish, `PRODUCER` va `CONSUMER` navbatga xabar qo'yish va undan olish. Status `Unset` "xato belgilanmagan" degani, "muvaffaqiyatli" degani emas: xatoni span'da kod yoki instrumentatsiya aniq belgilashi kerak.

**Resource attributes** span'ni kim yaratganini bildiradi va jarayonning hamma span'lari uchun bir xil: `service.name`, `service.version`, `deployment.environment.name`. Atribut nomlari OpenTelemetry semantic conventions (kelishilgan nomlar lug'ati, 7-dars) dan olinadi, shunda har xil tilda yozilgan servislarni bir xil so'rov bilan qidirish mumkin.

### Mexanizm: daraxt qanday yig'iladi

Trace bu bir xil `trace_id` li span'lar to'plami. Hech qaysi servis butun trace'ni bilmaydi va hech kim uni "yig'ib yubormaydi": har jarayon faqat o'z span'larini, tugagan zahoti (partiyalab) backend'ga yuboradi. Backend (Jaeger, Tempo) bu trace'larni saqlaydigan va qidiradigan tizim. U bir xil `trace_id` li span'larni to'playdi va `parent_span_id` → `span_id` havolalari bo'yicha daraxtga teradi. Demak daraxt uchun ikki narsa yetarli: hamma span'da bir xil `trace_id` va har birida otasining ID'si. Shu ikkisini servislar orasida olib o'tish 2-bo'limning mavzusi.

### Misol: bitta trace, qatorma-qator

`gateway` servisi `GET /cart/42` so'rovini oladi, sessiyani o'qiydi, keyin `pricing` servisini chaqiradi, u esa ma'lumotlar bazasiga so'rov yuboradi. Backend'ga beshta span keladi (ikkita jarayondan, aralash tartibda):

```
trace_id = 5b8aa5a2d2c872e8321cf37308d69df2

span_id           parent_span_id    service  kind      name             start   duration
a1b2c3d4e5f60001  (empty)           gateway  SERVER    GET /cart/:id      0 ms   240 ms
a1b2c3d4e5f60002  a1b2c3d4e5f60001  gateway  INTERNAL  load-session       2 ms    18 ms
a1b2c3d4e5f60003  a1b2c3d4e5f60001  gateway  CLIENT    GET               25 ms   200 ms
b7ad6b7169203331  a1b2c3d4e5f60003  pricing  SERVER    GET /prices/:id   31 ms   188 ms
b7ad6b7169203332  b7ad6b7169203331  pricing  CLIENT    SELECT prices     40 ms   170 ms
```

`start` root span boshlanishiga nisbatan berilgan. Backend `parent_span_id` bo'yicha yig'gan daraxt (waterfall):

```
gateway  GET /cart/:id        |================================================| 0..240
gateway    load-session       |===|                                              2..20
gateway    GET (client)            |========================================|    25..225
pricing      GET /prices/:id        |======================================|     31..219
pricing        SELECT prices          |==================================|       40..210
```

O'qiymiz:

- 1-qator: root span, `parent_span_id` bo'sh. Butun so'rov 240 ms. Bu brauzer Network tabida ko'rgan raqam.
- 2-qator: `load-session` root'ning bolasi, 2 ms da boshlanib 20 ms da tugagan (18 ms). Kind `INTERNAL`: tarmoqqa chiqmagan.
- 3-qator: `gateway` ning chiquvchi so'rovi, `CLIENT`. 25 ms da boshlanib 225 ms da tugagan (200 ms). Root'da undan keyin 15 ms qolgan (225..240): javobni yig'ish va yuborish.
- 4-qator: xuddi shu chaqiruvning `pricing` tomonidagi yarmi, `SERVER`. Uning otasi `gateway` ning `CLIENT` span'i: ikki jarayon orasidagi yagona ko'prik shu havola. U 31 ms da boshlangan, ya'ni so'rov tarmoqda 6 ms yurgan (25 → 31), 219 ms da tugagan, javob yana 6 ms yurgan (219 → 225). `CLIENT` 200 ms, `SERVER` 188 ms: farq 12 ms tarmoq va navbat.
- 5-qator: DB so'rovi 170 ms. `pricing` ning o'z ishi 188 − 170 = 18 ms.

Xulosa: 240 ms ning 170 ms i bitta SQL so'rovida. Sekin servis `gateway` ham emas, `pricing` ning kodi ham emas, uning DB so'rovi. Metrika "p95 o'sdi" degan, trace esa "mana shu so'rovda mana shu joy" deydi.

Bitta servis chaqiruvi odatda ikki span beradi: chaqiruvchida `CLIENT`, qabul qiluvchida `SERVER`. Faqat `CLIENT` bor, `SERVER` yo'q bo'lsa, qabul qiluvchi instrumentatsiya qilinmagan yoki kontekst unga yetib bormagan.

### Trace, log va metrika

| | Metrika | Log | Trace |
|---|---|---|---|
| Birlik | time series nuqtasi | bitta jarayonning bitta hodisasi | bitta so'rovning span'lar daraxti |
| Savol | nima buzildi, qancha | bu jarayon nima dedi | bu so'rovda vaqt qayerda ketdi |
| Hajm | series soniga bog'liq | trafikka proporsional | trafikka proporsional va eng katta, shuning uchun sampling |

Alert va dashboard metrikada quriladi (hamma so'rovni sanaydi), sabab qidirish trace'da.

### Real ishda qachon kerak

- "Checkout sekin" degan shikoyat: 6 servisdan qaysi biri aybdor ekanini jamoalar bahslashmasdan, bitta trace ko'rsatadi.
- Xato qayerda tug'ilgan: foydalanuvchi `502` ko'radi, trace'da eng chuqur `Error` statusli span asl manba.
- N+1 muammosi: bitta so'rov ichida bir xil `SELECT` 50 marta ketma-ket turgan waterfall ko'zga darhol tashlanadi.
- Yangi jamoa a'zosi uchun arxitektura: qaysi servis kimni chaqirishini hujjat emas, haqiqiy trace'lardan chizilgan service graph ko'rsatadi.

### Nima uchun shunday

Model Google'ning 2010-yilgi Dapper maqolasidan keladi: har ish bo'lagi o'z ID'si va ota ID'si bilan yoziladi, daraxt keyin yig'iladi. Muqobili har servis log'iga umumiy request ID yozish (4-dars): u "bu qatorlar bitta so'rovga tegishli" deydi, lekin ichma-ichlikni, parallel chaqiruvlarni va har bo'lakning davomiyligini bermaydi. Span'larni markaziy "yig'uvchi" siz, har jarayon mustaqil yuborishi esa servislarni bir-biriga bog'lamaydi: `pricing` trace yuborish uchun `gateway` ni kutmaydi va uning tracing'i buzilsa ham ishlayveradi.

## 2. Context propagation

### Bu nima

**Trace context** bu keyingi span to'g'ri daraxtga tushishi uchun kerak bo'lgan minimal ma'lumot: `trace_id`, joriy span'ning `span_id` si va sampling qarori. **Context propagation** shu ma'lumotni ish ketayotgan yo'l bo'ylab olib o'tish. U ikki chegaradan o'tishi kerak:

- **Jarayonlar orasida**: tarmoq orqali, HTTP header'da (network moduli, 4-dars). Chaqiruvchi kontekstni chiquvchi so'rovga yozadi (**inject**), qabul qiluvchi kiruvchi so'rovdan o'qiydi (**extract**).
- **Jarayon ichida**: kiruvchi so'rovni qabul qilgan kod bilan chiquvchi so'rovni yuboradigan kod orasida. Ular orasida bir necha `await`, callback va kutubxona qatlami bor.

### Mexanizm: jarayon ichida

Node.js bitta thread'da minglab so'rovga navbatma-navbat ishlov beradi, shuning uchun "joriy span" ni global o'zgaruvchida saqlab bo'lmaydi: `await` paytida boshqa so'rovning kodi ishlab, uni almashtirib qo'yadi. Node'da buning yechimi `AsyncLocalStorage` (`node:async_hooks` moduli): u qiymatni asinxron zanjirga bog'laydi va shu zanjirdagi har `await`, callback va timer'dan keyin o'sha qiymat qaytib turadi. OpenTelemetry SDK joriy span'ni shunda saqlaydi. Natija: handler ichida chuqurda chaqirilgan `fetch` hech qanday parametr olmasa ham, instrumentatsiya "hozir qaysi span faol" ekanini biladi va yangi span'ni uning bolasi qiladi.

Go'da yashirin kontekst yo'q: `context.Context` har funksiyaga birinchi parametr sifatida qo'lda uzatiladi. `ctx` ni uzatishni unutgan joyingizda zanjir uziladi.

### Mexanizm: jarayonlar orasida, W3C Trace Context

Yuqoridagi misolda `gateway` ning `CLIENT` span'i (`...0003`) `pricing` ga yuborgan so'rovga shu header'ni qo'shadi:

```
traceparent: 00-5b8aa5a2d2c872e8321cf37308d69df2-a1b2c3d4e5f60003-01
```

Chiziqcha bilan ajratilgan to'rt maydon:

| Maydon | Qiymat | Ma'nosi |
|--------|--------|---------|
| version | `00` | format versiyasi, hozircha yagona |
| trace-id | `5b8aa5a2d2c872e8321cf37308d69df2` | 32 ta kichik hex belgi (16 bayt); hammasi nol bo'lishi mumkin emas |
| parent-id | `a1b2c3d4e5f60003` | 16 hex belgi (8 bayt): header'ni yuborgan span'ning `span_id` si |
| trace-flags | `01` | 8 bitli bayroqlar; eng kichik bit `sampled`: `01` yozilyapti, `00` yozilmayapti |

`pricing` tomonda instrumentatsiya header'ni extract qiladi va yangi `SERVER` span yaratadi: `trace_id` header'dagi bilan bir xil, `parent_span_id` = header'dagi parent-id, `span_id` yangi tasodifiy (`b7ad6b7169203331`). Shu span ichida `pricing` yana kimnidir chaqirsa, uning `traceparent` ida trace-id o'sha, parent-id esa endi `b7ad6b7169203331` bo'ladi. Ya'ni trace-id zanjir bo'ylab o'zgarmaydi, parent-id har sakrashda yangilanadi.

Kiruvchi so'rovda `traceparent` bo'lmasa (yoki u noto'g'ri formatda bo'lsa), servis yangi `trace_id` yaratadi va uning span'i root bo'ladi.

Yonidagi ikki header:

- `tracestate`: tracing tizimlarining o'ziga xos qo'shimcha ma'lumoti, `vendor=value` juftlari ro'yxati. O'qimasangiz ham o'zgartirmasdan uzatiladi.
- `baggage`: alohida W3C spetsifikatsiyasi, ilova darajasidagi kalit-qiymatlar (`baggage: tenant=acme,plan=pro`). Butun zanjir bo'ylab har chiquvchi so'rovga qo'shiladi. Xavfi shunda: u tashqi (uchinchi tomon) API'larga ham ketadi va har so'rovni kattalashtiradi. Baggage'ga token, email, shaxsiy ma'lumot yozilmaydi.

Eski formatlar (Zipkin'ning B3 header'lari, Jaeger'ning `uber-trace-id`) hali uchraydi. Yangi tizimda W3C tanlanadi, OpenTelemetry'da u standart propagator.

### Trace'ni nima uzadi

Zanjirdagi bitta bo'g'in kontekstni uzatmasa, keyingi servis yangi `trace_id` bilan yangi trace boshlaydi. UI'da bitta uzun trace o'rniga ikkita qisqa, bog'lanmagan trace ko'rinadi: birinchisi `CLIENT` span bilan tugaydi, ikkinchisi o'z root'iga ega.

| Sabab | Nima bo'ladi |
|-------|--------------|
| Instrumentatsiya qilinmagan HTTP client | inject bo'lmaydi, header umuman ketmaydi |
| Header'larni tozalaydigan proxy yoki gateway | header yo'lda yo'qoladi |
| Instrumentatsiyasiz oraliq servis | header'ni oladi, lekin o'zining chiquvchi so'roviga ko'chirmaydi |
| Navbat (queue) yoki fon ishi | HTTP header yo'q; kontekst xabar metadata'siga qo'lda yoziladi va o'qiladi |
| Jarayon ichida kontekst yo'qolishi | Go'da `ctx` uzatilmagan; Node'da instrumentatsiya kech yuklangan (4-bo'lim) |
| Go'da propagator o'rnatilmagan | `otel.SetTextMapPropagator` chaqirilmasa global propagator hech narsa uzatmaydi |

### Real ishda qachon kerak

- Yangi servis yoki proxy qo'shilganda birinchi tekshiruv: trace uzluksizmi.
- Frontend'dan boshlash: brauzerdagi `fetch` ham `traceparent` yubora oladi, shunda trace foydalanuvchi bosgan tugmadan boshlanadi (bu modulda yo'q).
- Qo'llab-quvvatlash: javob header'ida yoki xato sahifasida trace ID qaytarilsa, foydalanuvchi shikoyatidan to'g'ridan-to'g'ri trace'ga o'tiladi.

### Nima uchun shunday

Kontekst header'da yuriladi, chunki HTTP header'lar so'rov tanasiga tegmaydigan, har til va har proxy tushunadigan yagona yon kanal. W3C standarti (2020-yilda Recommendation bo'lgan) dan oldin har tizimning o'z header'i bor edi va ikki xil tracing ishlatgan kompaniyalar orasida trace uzilardi; umumiy format bulut provayderlari, proxy'lar va kutubxonalarga bitta narsani qo'llab-quvvatlash imkonini berdi. Muqobili (markaziy "so'rovlar reyestri" ga har servis murojaat qilishi) har so'rovga qo'shimcha tarmoq chaqiruvi va yagona nosozlik nuqtasi bo'lardi. Header'da esa ma'lumot so'rov bilan birga, bepul yuradi.


## 3. Sampling

### Bu nima

**Sampling** (namuna olish) bu qaysi trace'lar saqlanib, qaysilari tashlab yuborilishini hal qilish. Har so'rovni saqlash qimmat va keraksiz: 1000 ta bir xil muvaffaqiyatli `GET /cart` ning bittasi yetadi, xatoli va sekinlari esa hammasi kerak. Trace hajmi log hajmidan ham katta bo'lishi mumkin: bitta so'rov o'nlab span beradi, har span'da o'nlab atribut.

Qaror qachon qabul qilinishiga qarab ikki usul bor.

### Head sampling: qaror boshida

Root span yaratilayotgan payt, hali so'rov nima bilan tugashini hech kim bilmaganda, SDK "yozamanmi" deb qaror qiladi. Eng ko'p ishlatiladigan sampler `traceidratio`: `trace_id` dan hisoblangan son berilgan ulushdan kichik bo'lsa trace yoziladi. `trace_id` tasodifiy bo'lgani uchun bu tasodifiy ulush beradi, lekin bir xil `trace_id` uchun qaror har doim bir xil (deterministik).

Qaror `traceparent` ning flags maydoniga yoziladi (`01` yoki `00`) va keyingi servislarga yetib boradi. Ular unga bo'ysunishi kerak, aks holda har servis o'zi tanga tashlaydi va trace'lar yarim bo'lib qoladi. Bunga `parentbased_*` sampler'lar javob beradi: "ota bo'lsa, uning qaroriga ergash; ota bo'lmasa (men root'man), ichki sampler'ni ishlat".

SDK'da env orqali (hamma tillarda bir xil nom):

```
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1
```

Mavjud qiymatlar: `always_on`, `always_off`, `traceidratio`, `parentbased_always_on` (default), `parentbased_always_off`, `parentbased_traceidratio`. Default `parentbased_always_on`, ya'ni sozlamasangiz hamma narsa yoziladi.

### Misol: ikki servis, ikki xil sozlama

`gateway` da `parentbased_traceidratio` 0.1, `pricing` da hech narsa sozlanmagan (default `parentbased_always_on`). 1000 ta so'rov yuborildi:

```
service   sampler                     incoming flag   recorded spans
gateway   parentbased_traceidratio    (no parent)     ~100 traces x 3 spans
pricing   parentbased_always_on       01 on ~100      ~100 traces x 2 spans
                                      00 on ~900      0
```

O'qiymiz:

- `gateway` root, ota yo'q: ichki `traceidratio` ishlaydi, taxminan 100 trace tanlanadi (aniq 100 emas, tasodifiy).
- `pricing` o'zi 100% sozlangan bo'lsa ham faqat ~100 trace yozadi: u ota qaroriga ergashadi. Flag `00` kelgan 900 so'rovda span'lar yaratiladi (kontekst baribir uzatiladi), lekin yozilmaydi va yuborilmaydi.
- Natija: ~100 ta to'liq trace, yarimtasi yo'q.

Agar `pricing` da `parentbased` siz `traceidratio` 0.5 qo'yilsa, u ota flag'iga qaramaydi va `trace_id` bo'yicha o'zi qaror qiladi: `gateway` yozgan 100 trace'ning taxminan yarmida `pricing` qismi bo'lmaydi. Waterfall'da `CLIENT` span bor, uning ostida hech narsa yo'q.

### Tail sampling: qaror oxirida

Hamma span'lar to'liq yuboriladi, ularni oraliq komponent (OpenTelemetry Collector, 7-dars) bir muddat xotirada ushlab turadi va trace tugagach mazmuniga qarab qaror qiladi: xato bormi, davomiyligi qancha, qaysi atribut bor. Collector'ning `tail_sampling` processor'i bunga misol:

```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow
        type: latency
        latency: { threshold_ms: 500 }
      - name: some-of-the-rest
        type: probabilistic
        probabilistic: { sampling_percentage: 5 }
```

`decision_wait` birinchi span kelgandan keyin qaror uchun kutiladigan vaqt; policy'lardan birortasi "ha" desa trace saqlanadi. Natija: hamma xato va sekin trace, qolganlarining 5%.

| | Head sampling | Tail sampling |
|---|---|---|
| Qaror qachon | trace boshida, root span'da | trace tugagach, hamma span yig'ilgach |
| Qayerda | SDK (ilova ichida) | Collector (`tail_sampling` processor) |
| Mezon | tasodifiy ulush (`trace_id` asosida) | mazmun: xato, davomiylik, atribut |
| Narxi | arzon, tashlangan span umuman yuborilmaydi | hamma span Collector'gacha keladi, xotirada bufer |
| Kamchiligi | kam uchraydigan xato namunaga tushmasligi mumkin | bitta trace'ning hamma span'i bitta Collector instansiga tushishi shart |

Oxirgi qatorga e'tibor: Collector bir nechta replikada ishlasa va span'lar ular orasida tasodifiy taqsimlansa, har replika trace'ning bir qismini ko'radi va qaror to'liq bo'lmagan ma'lumotda qabul qilinadi. Shuning uchun oldiga `trace_id` bo'yicha yo'naltiradigan qatlam qo'yiladi (Collector'ning `loadbalancing` exporter'i).

### Sampling va metrikalar

Sampling'dan qat'i nazar RED metrikalari (Rate, Errors, Duration: so'rovlar tezligi, xatolar, davomiylik, 1-dars) to'liq bo'lishi kerak. Ular ilovadagi counter va histogram'dan yoki span'lardan sampling'dan **oldin** hisoblanadi. 10% namunadan hisoblangan "so'rov/s" haqiqiy trafikning 10% ini ko'rsatadi va alert'lar yolg'on gapiradi.

### Real ishda qachon kerak

- Production'ga chiqishdan oldin: trafik va trace hajmini baholab, ulush tanlanadi. Laboratoriyada 100% normal.
- Kam uchraydigan xatolar muhim bo'lsa (to'lov, 0.1% holat): head sampling ularni yo'qotadi, tail sampling kerak.
- Narx muammosi: trace backend hisobi kutilgandan oshsa, birinchi qaraladigan joy sampling ulushi.

### Nima uchun shunday

Head sampling'ning kuchi arzonligida: qaror bitta bit bo'lib header bilan yuradi, tashlangan trace hech qayerga yuborilmaydi va ilova ortiqcha ish qilmaydi. Uning ko'rligi (so'rov qanday tugashini bilmaydi) tail sampling'ni tug'dirgan, u esa xotira va qo'shimcha infratuzilma bilan to'lanadi. Ko'p tizim ikkalasini birga ishlatadi: SDK'da yumshoq head sampling (masalan 50%), Collector'da tail sampling. `parentbased` default bo'lgani esa W3C flag'ining maqsadi: zanjirning birinchi bo'g'ini qaror qiladi, qolganlari ergashadi.

## 4. Instrumentatsiya

### Bu nima

**Instrumentatsiya** (1-dars) bu kodga o'lchov nuqtalarini qo'shish; tracing'da bu span yaratish, kontekstni inject/extract qilish va span'larni yuborish. Hozir buning yagona umumiy yo'li **OpenTelemetry** (OTel): tildan va backend'dan mustaqil API, SDK va **OTLP** (OpenTelemetry Protocol, telemetriyani yuborish protokoli: gRPC `4317`, HTTP `4318`). Jaeger'ning eski o'z client kutubxonalari eskirgan; Jaeger ham, Tempo ham OTLP'ni qabul qiladi. Bitta instrumentatsiya, backend esa faqat endpoint bilan almashadi.

OTel'da ikki qatlam bor: **API** (kod chaqiradigan interfeys, `@opentelemetry/api`) va **SDK** (span'larni yig'ib, sampling qilib, yuboradigan amalga oshirish). Kutubxonalar faqat API'ga bog'lanadi; SDK o'rnatilmasa API "hech narsa qilmaydigan" rejimda ishlaydi. Batafsil 7-darsda.

### Avtomatik (zero-code) instrumentatsiya

Tayyor instrumentatsiya kutubxonalari HTTP server, HTTP client, `express`, DB driver'larni o'rab oladi va span'larni o'zi yaratadi. Node.js'da kodga tegmasdan:

```
npm install @opentelemetry/api @opentelemetry/auto-instrumentations-node
node --require @opentelemetry/auto-instrumentations-node/register server.js
```

`register` moduli SDK'ni ishga tushiradi, sozlamani env'dan o'qiydi va `http`, `express` kabi modullarni yuklanishida o'rab oladi (monkey-patching: modulning funksiyasini o'z o'ramiga almashtirish). Shu sababli tartib muhim: u ilova modullaridan **oldin** yuklanishi shart. `server.js` ichida birinchi qatorlarda `require` qilish ham ishlaydi, lekin `--require` (ESM ilova uchun `--import`) ishonchliroq.

Go'da "kodga tegmasdan" variant kamroq: handler va client o'raladi, exporter va propagator kodda sozlanadi:

```go
otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
    propagation.TraceContext{}, propagation.Baggage{}))
handler := otelhttp.NewHandler(mux, "server")
client := &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}
```

`otelhttp.NewHandler` har kiruvchi so'rov uchun `SERVER` span ochadi va header'dan kontekstni extract qiladi; `NewTransport` har chiquvchi so'rov uchun `CLIENT` span ochadi va inject qiladi. Birinchi qator bo'lmasa inject va extract hech narsa qilmaydi (2-bo'lim). So'rov ichida `req.Context()` ni keyingi chaqiruvlarga uzatish sizning ishingiz.

### Sozlash env orqali

Hamma tillar uchun bir xil nomlar (OTel spetsifikatsiyasi):

| O'zgaruvchi | Misol | Ma'nosi |
|-------------|-------|---------|
| `OTEL_SERVICE_NAME` | `pricing` | `service.name` resource atributi |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://tempo:4318` | qayerga yuborish |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` yoki `grpc` | port bilan mos bo'lishi shart |
| `OTEL_TRACES_EXPORTER` | `otlp` | `console` debug uchun stdout'ga, `none` o'chirish |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment.name=lab,service.version=1.2.0` | qo'shimcha resource atributlari |
| `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG` | 3-bo'lim | sampling |

Compose'da bular servisning `environment:` bo'limiga yoziladi; endpoint'da servis nomi (Laboratoriya, portlar qoidasi).

### Misol: console exporter chiqishi

Xayoliy `pricing` servisi `OTEL_TRACES_EXPORTER=console` bilan ishga tushirilgan va unga kontekstli so'rov kelgan. Node SDK stdout'ga har span'ni JavaScript obyekti ko'rinishida chiqaradi (qisqartirilgan, maydon nomlari SDK versiyasiga qarab biroz farq qiladi):

```
{
  resource: { attributes: { 'service.name': 'pricing', ... } },
  instrumentationScope: { name: '@opentelemetry/instrumentation-http', version: '<...>' },
  traceId: '5b8aa5a2d2c872e8321cf37308d69df2',
  parentSpanContext: { traceId: '5b8a...', spanId: 'a1b2c3d4e5f60003', ... },
  name: 'GET /prices/:id',
  id: 'b7ad6b7169203331',
  kind: 1,
  timestamp: 1759917303031000,
  duration: 188214.5,
  attributes: { 'http.request.method': 'GET', 'http.response.status_code': 200, ... },
  status: { code: 0 },
  events: []
}
```

O'qiymiz:

- `resource`: span'ni kim yaratgan; `service.name` env'dan.
- `instrumentationScope`: span'ni qaysi instrumentatsiya kutubxonasi yaratgan. Bu yerda `http` moduli.
- `traceId`: kiruvchi `traceparent` dagi bilan bir xil, ya'ni extract ishlagan.
- `parentSpanContext.spanId` (eski versiyalarda `parentId`): `gateway` ning `CLIENT` span'i. Bo'sh bo'lsa bu root span.
- `id`: shu span'ning `span_id` si.
- `kind: 1`: JavaScript API'da `SpanKind` raqamlari `INTERNAL=0`, `SERVER=1`, `CLIENT=2`, `PRODUCER=3`, `CONSUMER=4`. OTLP protokolida esa raqamlash 1 dan boshlanadi (`SERVER=2`), shuning uchun raqamni emas, nomini eslang.
- `timestamp` va `duration` mikrosekundda: 188214.5 µs ≈ 188 ms.
- `status: { code: 0 }`: `Unset`. `1` `Ok`, `2` `Error`.

### Qo'lda span

Avtomatik instrumentatsiya chegaralarni (HTTP, DB) ko'radi, lekin sizning biznes qadamlaringizni ko'rmaydi. Ular uchun span qo'lda yaratiladi. Umumiy shakl (Node.js, xayoliy hisobot generatori):

```js
const { trace, SpanStatusCode } = require('@opentelemetry/api');
const tracer = trace.getTracer('reports');
await tracer.startActiveSpan('render-pdf', async (span) => {
  try { span.setAttribute('report.pages', pages); await render(); }
  catch (err) { span.recordException(err); span.setStatus({ code: SpanStatusCode.ERROR }); throw err; }
  finally { span.end(); }
});
```

`startActiveSpan` span'ni joriy kontekstga qo'yadi, shuning uchun `render()` ichidagi har qanday instrumentatsiya qilingan chaqiruv uning bolasi bo'ladi. `recordException` span'ga exception event qo'shadi, lekin statusni o'zgartirmaydi: `setStatus` alohida chaqiriladi. `span.end()` chaqirilmasa span hech qachon yuborilmaydi.

### Yuborish qanday ishlaydi va nima uchun so'rovni yiqitmaydi

SDK span'larni tugashi bilan darhol tarmoqqa yubormaydi: **BatchSpanProcessor** ularni xotiradagi navbatga qo'yadi va partiyalab (default bir necha soniyada bir) exporter'ga beradi. Exporter backend'ga yetib bormasa, xato SDK'ning ichki log'iga yoziladi, navbat to'lsa yangi span'lar tashlanadi. So'rovga ishlov berish bu orada davom etadi. Telemetriya yordamchi signal: uning nosozligi foydalanuvchiga ko'rinmasligi kerak, aks holda monitoring tizimi ishlamay qolsa ilova ham yiqiladi.

### Cardinality va maxfiylik

Span nomi va atributlarida cardinality qoidasi metrikadagidek: nom shablon (`GET /cart/:id`), aniq qiymat atributda (`url.path`). Span nomi bo'yicha guruhlash, qidiruv va span metrikalari (5-bo'lim) quriladi; har so'rovda yangi nom ularni portlatadi. Maxfiy ma'lumot (token, parol, so'rov tanasi, shaxsiy ma'lumot) atributga yozilmaydi: trace'larni log kabi ko'p odam o'qiydi.

### Real ishda qachon kerak

- Yangi servis: birinchi kundan zero-code instrumentatsiya, keyin kerakli joylarga qo'lda span.
- "Bu 300 ms qayerga ketdi" savoliga avtomatik span'lar javob bermasa (vaqt bitta handler ichida, CPU ishida), o'sha joyga qo'lda span qo'shiladi.
- Debug: `OTEL_TRACES_EXPORTER=console` bilan backend'siz span'lar to'g'ri yaratilyaptimi tekshiriladi.

### Nima uchun shunday

API va SDK ajratilgani kutubxona mualliflari uchun: `express` yoki DB driver API'ga bog'lanib span yaratadi, lekin qaysi backend, qanday sampling ekanini ilova egasi hal qiladi. Env nomlari hamma tilda bir xil bo'lgani ops jamoasiga Node va Go servislarini bir xil `compose.yaml` bilan sozlash imkonini beradi. Muqobili (har vendor o'z agent'i va o'z SDK'si) backend almashtirishni butun kodni qayta yozishga aylantirgan edi; OpenTelemetry aynan shu muammoni yopish uchun OpenTracing va OpenCensus loyihalari birlashishidan tug'ilgan.

## 5. Backend'lar: Jaeger va Tempo

### Backend nima qiladi

Trace backend uchta ish qiladi: OTLP orqali span'larni qabul qiladi (**receiver**), ularni saqlaydi va `trace_id` bo'yicha birlashtiradi, qidiruv va ko'rish uchun API beradi. Ilova nuqtai nazaridan backend'lar bir xil: faqat `OTEL_EXPORTER_OTLP_ENDPOINT` o'zgaradi.

### Jaeger

CNCF loyihasi, o'z UI'si bilan: servis va operatsiya bo'yicha qidirish, waterfall, servislar bog'liqligi grafigi (System Architecture), ikki trace'ni solishtirish. **Jaeger v2** OpenTelemetry Collector asosida qurilgan bitta binary (`jaeger`), OTLP'ni to'g'ridan-to'g'ri qabul qiladi. Sozlamasiz ishga tushirilsa all-in-one rejimda ishlaydi: qabul qilish, saqlash va UI bitta jarayonda, trace'lar **xotirada** (restart'da yo'qoladi). Production'da tashqi storage ulanadi: Elasticsearch/OpenSearch, Cassandra va boshqalar.

Jaeger v1 komponentlari (`jaeger-agent`, `jaeger-collector`, eski `jaegertracing/all-in-one` image) rasmiy download sahifasida deprecated deb belgilangan, oxirgi versiyasi 1.76. Eski qo'llanmalardagi `all-in-one` image va `6831/udp` portlari bu darsda ishlatilmaydi; image `jaegertracing/jaeger:<version>`.

Ishlayotganini tekshirish uchun UI ishlatadigan HTTP API'dan foydalanish mumkin:

```
$ curl -s localhost:16686/api/services
{"data":["pricing","gateway"],"total":2,"limit":0,"offset":0,"errors":null}
```

`data` Jaeger span olgan servislar nomlari (`service.name` dan). Bo'sh ro'yxat ilovalar unga hali hech narsa yubormaganini bildiradi. Bu API UI uchun yozilgan va rasmiy barqaror interfeys emas; tekshiruvga yetadi, avtomatlashtirishga emas.

### Tempo

Grafana Labs loyihasi, Loki bilan bir xil falsafa (4-dars): to'liq indeks klasteri yo'q, trace'lar arzon object storage'da (S3 kabi fayl ombori; laboratoriyada lokal disk) Parquet formatidagi bloklarda saqlanadi, UI esa Grafana. Trace ID bo'yicha topish tez, mazmun bo'yicha qidirish TraceQL bilan (6-bo'lim). Ichki oqim: **distributor** OTLP'ni qabul qiladi, **ingester** span'larni xotirada va WAL'da (write-ahead log, yozuvni avval diskdagi jurnalga qo'yish) yig'ib blok qiladi, **querier** so'rovga javob beradi. **Monolithic** rejim (`-target=all`) bularning hammasi bitta jarayonda, laboratoriya uchun yetarli.

Minimal config'ning asosi:

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

Tempo versiyalari orasida config kalitlari o'zgarib turadi: o'z tag'ingiz uchun shu versiyaning `example/docker-compose` papkasidagi config'ni asos qiling.

Qo'shimcha **metrics-generator** komponenti kelayotgan span'lardan metrika hisoblaydi va Prometheus'ga `remote_write` (Prometheus'ga HTTP orqali sample'larni push qilish protokoli) bilan yuboradi: **span metrics** (`traces_spanmetrics_*`, servis va span nomi bo'yicha so'rovlar soni va davomiylik histogram'i) va **service graph** (`traces_service_graph_*`, qaysi servis kimni qancha chaqirgani). Prometheus buni qabul qilishi uchun `--web.enable-remote-write-receiver` flag'i bilan ishga tushiriladi. Generator span'larni ingestion paytida ko'radi, shuning uchun SDK sampling'dan keyingi oqimni sanaydi (3-bo'lim).

### Misol: Tempo API

```
$ curl -s localhost:3200/ready
ready
$ curl -s localhost:3200/api/traces/5b8aa5a2d2c872e8321cf37308d69df2 | head -c 200
{"batches":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"gateway"}} ...
```

- `/ready`: `ready` qaytsa Tempo so'rov qabul qilishga tayyor. Ishga tushgandan keyin bir necha soniya boshqa matn (tayyor emaslik sababi) qaytishi normal.
- `/api/traces/<id>`: trace OTLP tuzilishiga yaqin JSON'da: `batches` ro'yxati (v2 API, `/api/v2/traces/<id>`, xuddi shuni `trace.resourceSpans` ko'rinishida beradi), har biri bitta resource (servis) va uning span'lari. Trace topilmasa `404`.

Bu port faqat `127.0.0.1` ga publish qilingan bo'lsa host'dan ishlaydi; aks holda Grafana Explore ishlatiladi.

**Tuzoq: receiver `localhost` da.** OTLP receiver endpoint'i ko'rsatilmasa, yangi versiyalarda default `localhost:4317`/`localhost:4318`. Konteynerda bu faqat konteynerning o'zi: boshqa servislarning exporter'i `connection refused` oladi, Tempo esa jim turadi. Endpoint'ni `0.0.0.0` bilan aniq yozing.

| | Jaeger | Tempo |
|---|---|---|
| UI | o'ziniki (Grafana'ga ham data source bo'ladi) | Grafana |
| Storage | Elasticsearch/OpenSearch, Cassandra va boshqalar | object storage |
| So'rov | servis, operatsiya, tag, davomiylik bo'yicha forma | TraceQL |
| Kuchli tomoni | mustaqil, yetuk UI, tez boshlash | Grafana stack bilan bog'lanish, arzon saqlash, span metrics |

### Real ishda qachon kerak

- Grafana, Loki, Prometheus allaqachon bor: Tempo tabiiy tanlov, signallar bitta UI'da bog'lanadi.
- Grafana yo'q, alohida tracing kerak yoki Elasticsearch jamoada bor: Jaeger.
- Lokal ishlab chiqishda tezkor ko'rish: Jaeger v2 bitta `docker run` bilan ("Birga bajaramiz").

### Nima uchun shunday

Jaeger 2015-yilda Uber'da, storage sifatida qidiruv indeksli bazalar (Cassandra, Elasticsearch) ishlatiladigan davrda tug'ilgan: har tag bo'yicha qidirish tez, lekin indeks klasteri qimmat. Tempo 2020-yilda teskari savoldan boshlangan: trace'larning aksariyati hech qachon ochilmaydi, ularni eng arzon joyda saqlab, kerakli trace'ga metrika (exemplar) yoki log (`trace_id`) orqali kelish mumkin. Bu Loki'ning "faqat label'ni indeksla" qaroriga o'xshaydi. Jaeger v2 ning Collector ustiga qayta qurilishi esa ekotizimning OpenTelemetry atrofida birlashganini ko'rsatadi.

## 6. TraceQL asoslari

### Bu nima

**TraceQL** Tempo'ning so'rov tili. U span'larni filtrlaydi va natijada mos span'lari bor trace'larni qaytaradi. Sintaksisi PromQL va LogQL dan ko'ra CSS selector'larga yaqinroq: `{ }` ichida shart, `>>` va `>` bilan ichma-ichlik.

### Tuzilishi

```
{ resource.service.name = "pricing" && span:duration > 100ms }
{ span:status = error }
{ span.http.response.status_code >= 500 && span.http.route = "/prices/:id" }
{ resource.service.name = "gateway" } >> { span.db.system.name = "postgresql" && span:duration > 50ms }
{ span:status = error } | count() > 3
```

Qatorma-qator:

1. `pricing` servisining 100 ms dan uzoq har qanday span'i bor trace'lar.
2. Kamida bitta span'i xato statusli trace'lar.
3. Ma'lum route'da 5xx javob bergan span'lar.
4. `gateway` span'ining avlodi bo'lgan va 50 ms dan uzoq ketgan DB span'lari: "gateway ichidan boshlangan sekin SQL".
5. Uchtadan ko'p xatoli span'i bor trace'lar.

Qoidalar:

- **Scope'lar**: `resource.` (servis haqida, resource attributes), `span.` (span atributlari). Prefikssiz `.http.route` ikkalasida qidiradi, lekin sekinroq.
- **Intrinsic** (span'ning o'z maydonlari, atribut emas) ikki nuqta bilan: `span:duration`, `span:name`, `span:status`, `span:kind`, `trace:duration`, `trace:rootService`, `trace:rootName`. Eski qisqa shakllar (`duration`, `status`, `name`) ham uchraydi.
- **Operatorlar**: `=`, `!=`, `>`, `>=`, `<`, `<=`, `=~` (regex), `!~`; mantiqiy `&&`, `||`. Qiymat turlari: matn qo'shtirnoqda, son, davomiylik (`100ms`, `1s`), status (`error`, `ok`, `unset`), kind (`server`, `client`).
- **Strukturaviy**: `A >> B` B A ning avlodi, `A > B` bevosita bola, `A ~ B` qardosh (bir otaning bolalari). Natija o'ng tomondagi span'lar.
- **Pipeline**: `|` dan keyin agregat: `count()`, `avg(span:duration)`, `max(...)`, `select(span.http.route)` (natijaga qo'shimcha atribut chiqarish).

### Misol: natijani o'qish

Grafana → Explore → Tempo data source, so'rov turi TraceQL, 4-so'rov. Natija jadvali (qisqartirilgan):

```
Trace ID           Start time   Service   Name             Duration   Matched
5b8aa5a2d2c8...    10:15:03     gateway   GET /cart/:id    240ms      1
9e1f03c7aa41...    10:15:41     gateway   GET /cart/:id    312ms      2
```

- Har qator bitta trace; `Service` va `Name` root span'dan (`trace:rootService`, `trace:rootName`).
- `Duration` butun trace'ning davomiyligi, mos span'niki emas.
- `Matched`: shu trace'da shartga mos kelgan span'lar soni. Ikkinchi trace'da ikkita sekin SQL bor: ehtimol N+1 boshlanishi. Qatorni ochsangiz mos span'lar (span set) ko'rinadi, undan butun waterfall'ga o'tiladi.

### Real ishda qachon kerak

- Incident paytida: "oxirgi 15 daqiqada `pricing` dagi xatolar qaysi trace'larda va ular qaysi root endpoint'dan kelgan".
- Regressiyani isbotlash: deploy'dan oldin va keyin bir xil so'rov bilan `| avg(span:duration)`.
- Kutilmagan bog'liqlikni topish: "bu servisni kim chaqiryapti" strukturaviy so'rov bilan.

### Nima uchun shunday

Trace daraxt, shuning uchun so'rov tili ham daraxtni tushunishi kerak: metrika yoki log tili "A ichida B" savolini bera olmaydi. Tempo dastlab faqat trace ID bo'yicha qidirardi (indeksiz falsafa), keyin Parquet formatiga o'tib ustunli skanerlash tezlashgach TraceQL qo'shildi. Muqobil yondashuv, Jaeger'ning tag forma qidiruvi, oddiy savollar uchun qulayroq, lekin strukturaviy va agregat savollarni bermaydi.

## 7. Signallarni bog'lash

### Muammo

Alohida turgan uch tizim uch marta qidirish degani: grafikda cho'qqi ko'rdingiz, vaqtni eslab Tempo'ga o'tdingiz, taxminan mos trace qidirdingiz, keyin Loki'da shu vaqt oralig'ida log qidirdingiz. Qiymat signallar orasidagi bir bosishli o'tish yo'llarida. Ularning hammasi bitta kalitga tayanadi: `trace_id`.

### Uchta yo'l

- **Metrika → trace (exemplar)**: **exemplar** histogram namunasiga biriktirilgan bitta misol: qiymat, vaqt va `trace_id`. Grafana grafikda nuqtalar sifatida ko'rsatadi, bosilsa shu trace ochiladi: "p99 cho'qqisidagi aniq bitta sekin so'rov". Kerak bo'ladiganlar: Prometheus'da `--enable-feature=exemplar-storage`; exemplar beradigan manba (Tempo metrics-generator `remote_write` da `send_exemplars: true` bilan, yoki OpenMetrics formatida exemplar chiqaradigan client library); Grafana'ning Prometheus data source'ida `exemplarTraceIdDestinations` (exemplar label nomi `name` va Tempo'ning `datasourceUid` i).
- **Trace → log**: Tempo data source'idagi `tracesToLogsV2` sozlamasi: span'dan Loki'ga, servis label'i va `trace_id` bo'yicha tayyor so'rov bilan. Asosiy kalitlar: `datasourceUid` (Loki), `tags` (span atributini Loki label'iga moslash ro'yxati), `filterByTraceID`.
- **Log → trace**: Loki data source'idagi `derivedFields`: log qatoridagi `trace_id` ni regex (`matcherRegex`) bilan topib Tempo'ga (`datasourceUid`) havolaga aylantiradi.

### Mexanizm: exemplar formatda qanday ko'rinadi

OpenMetrics formatida exemplar bucket qatorining oxiriga `#` dan keyin yoziladi:

```
http_request_duration_seconds_bucket{route="/cart/:id",le="1"} 1204 # {trace_id="9e1f03c7aa41c0b2d6e18f7735d0a915"} 0.83 1759917341.120
```

- `... 1204`: oddiy bucket qiymati (1-dars).
- `# {trace_id="..."}`: exemplar label'lari, bu yerda bitta: shu bucket'ga tushgan so'rovlardan birining trace ID'si.
- `0.83`: shu so'rovning o'lchangan qiymati (0.83 s).
- `1759917341.120`: o'lchangan vaqt.

Prometheus exemplar'larni alohida xotira buferida saqlaydi va `/api/v1/query_exemplars` orqali beradi; Grafana panelda "Exemplars" yoqilganda shu API'ni so'raydi. Bu formatni faqat OpenMetrics chiqara oladi, eski Prometheus matn formati exemplar'ni bilmaydi.

### Mexanizm: log'da `trace_id`

Hamma o'tishning sharti: log qatorida `trace_id` bo'lishi. Node.js'da auto-instrumentation pino va winston yozuvlariga `trace_id` va `span_id` ni o'zi qo'shadi (ularning instrumentatsiyasi orqali). Go'da `trace.SpanContextFromContext(ctx)` dan olib, logger'ga maydon qilib berasiz. Natijadagi JSON qator (4-dars formatida):

```
{"time":"2026-10-08T10:15:03.213Z","level":"error","msg":"price lookup failed","service":"pricing","trace_id":"5b8aa5a2d2c872e8321cf37308d69df2","span_id":"b7ad6b7169203331"}
```

`trace_id` Loki **label** emas, log maydoni: har so'rovda yangi qiymat, label bo'lsa har so'rov yangi stream yaratadi (4-dars, cardinality). LogQL'da u matn filtri yoki `| json | trace_id="..."` bilan topiladi. 4-darsdagi `request_id` ning o'rnini shu maydon egallaydi.

### Label nomlari mos kelishi kerak

Trace → log o'tishida Grafana span'ning resource atributidan Loki so'rovini quradi. Span'da `service.name="pricing"`, Loki'da esa stream label'i, aytaylik, `service="pricing"` (yoki `container`). Nomlar boshqa: moslash ro'yxati bo'lmasa so'rov noto'g'ri label bilan quriladi va bo'sh natija qaytadi. Loki label nomida nuqta ham bo'lmaydi.

### Real ishda qachon kerak

- On-call oqimi: alert (metrika) → dashboard'dagi exemplar → trace → shu trace'ning log'lari. Har o'tish bitta bosish.
- Foydalanuvchi shikoyati: xato sahifasidagi trace ID'dan to'g'ridan-to'g'ri trace'ga, undan log'larga.
- Log'dagi bitta g'alati xato qatoridan uning to'liq kontekstiga (qaysi so'rov, qaysi servislar orqali).

### Nima uchun shunday

Uch signal uch xil saqlash modelini talab qiladi (agregat son, matn, daraxt) va bitta bazada saqlash hammasini yomonlashtiradi. Ularni bog'lash uchun umumiy kalit yetadi, `trace_id` esa allaqachon har so'rovda bor. Exemplar shuning uchun faqat bitta ID saqlaydi, butun trace'ni emas: metrika arzonligicha qoladi, tafsilot esa kerak bo'lganda boshqa tizimdan olinadi. Bog'lanishlar data source provisioning'ida yoziladi, chunki bu tizimlar bir-birini bilmaydi; ularni faqat Grafana tanishtiradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Distributed tracing | bitta so'rovning bir nechta servis orqali yo'lini span'lar daraxti sifatida yozish |
| Span | bitta ish birligining yozuvi: nom, vaqt, atributlar, status, ota havolasi |
| Trace | bir xil `trace_id` li span'lar to'plami, `parent_span_id` bo'yicha daraxt |
| Root span | ota'si yo'q, trace'ni boshlagan span |
| `trace_id` / `span_id` | trace uchun 16 baytli / span uchun 8 baytli tasodifiy identifikator |
| Span kind | span'ning roli: `SERVER`, `CLIENT`, `INTERNAL`, `PRODUCER`, `CONSUMER` |
| Span status | `Unset`, `Ok`, `Error`; xato aniq belgilanmasa `Unset` |
| Span event | span ichidagi vaqt belgili yozuv, masalan exception |
| Resource attributes | span'ni yaratgan jarayon haqidagi atributlar: `service.name` va boshqalar |
| Waterfall | span'larni vaqt o'qida ichma-ich ko'rsatish |
| Trace context | `trace_id`, joriy `span_id` va sampling qarori |
| Context propagation | trace context'ni jarayon ichida va jarayonlar orasida uzatish |
| Inject / extract | kontekstni chiquvchi so'rovga yozish / kiruvchidan o'qish |
| `traceparent` | W3C header: `version-traceid-parentid-flags` |
| `tracestate` / `baggage` | vendor qo'shimcha ma'lumoti / ilova kalit-qiymatlarini zanjir bo'ylab olib o'tuvchi header |
| `AsyncLocalStorage` | Node.js'da qiymatni asinxron chaqiruvlar zanjiriga bog'laydigan mexanizm |
| Sampling | qaysi trace'lar saqlanishini hal qilish |
| Head / tail sampling | qaror trace boshida SDK'da / trace tugagach Collector'da |
| `parentbased` sampler | ota span qaroriga ergashadigan sampler |
| OpenTelemetry (OTel) | telemetriya uchun tildan va vendor'dan mustaqil API, SDK va protokol |
| OTLP | OpenTelemetry Protocol, gRPC `4317` va HTTP `4318` |
| Zero-code instrumentation | kodni o'zgartirmasdan kutubxonalarni o'rab span yaratish |
| Exporter | span'larni tashqariga (backend, console) yuboruvchi SDK qismi |
| BatchSpanProcessor | span'larni navbatda yig'ib partiyalab yuboruvchi SDK qismi |
| Jaeger v2 | Collector asosidagi trace backend, o'z UI'si bilan |
| Tempo | object storage'da saqlovchi, Grafana bilan ishlaydigan trace backend |
| metrics-generator | Tempo komponenti: span'lardan span metrics va service graph hisoblaydi |
| Service graph | servislar kim kimni chaqirishi grafigi |
| TraceQL | Tempo'ning span filtri va strukturaviy so'rov tili |
| Exemplar | histogram namunasiga biriktirilgan bitta misol: qiymat, vaqt, `trace_id` |
| Derived field | Loki'da log qatoridan regex bilan olingan, havolaga aylanadigan maydon |
| Trace to logs | Tempo span'idan Loki so'roviga o'tish sozlamasi |

## Tuzoqlar

- Propagation uzilishi: bitta instrumentatsiyasiz client, header kesadigan proxy yoki Go'da o'rnatilmagan propagator trace'ni ikkiga bo'ladi. Yangi servis qo'shilganda birinchi tekshiruv: trace uzluksizmi.
- Node.js'da instrumentatsiya ilova modullaridan keyin yuklangan: span'lar yo'q, xato ham yo'q. `--require` yoki `--import`.
- Span nomida yoki atribut kalitida yuqori cardinality (`GET /cart/8812`): qidiruv va span metrikalari portlaydi.
- 100% sampling bilan production'ga chiqish: trace hajmi log hajmidan ham oshadi. Sampling strategiyasi boshidan bo'lsin.
- Servislar har biri mustaqil head sampling qilishi (`traceidratio` `parentbased` siz): yarim trace'lar.
- Tail sampling'ni bir nechta Collector replikasi ortida `trace_id` bo'yicha yo'naltirishsiz qo'yish: qaror to'liq bo'lmagan ma'lumotda qabul qilinadi.
- Span atributlariga yoki `baggage` ga token, parol, shaxsiy ma'lumot yozish: trace'lar ham log kabi ko'pchilikka ochiq, baggage esa tashqi API'larga ham ketadi.
- RED metrikalarini sampling'dan keyingi span'lardan hisoblash: 10% namuna 10% trafikni ko'rsatadi.
- Servislar soatlari mos emas: bola span otadan oldin boshlangandek ko'rinadi. Alohida serverlarda NTP ishlashi shart; laboratoriyada konteynerlar bitta soatni bo'lishadi.
- OTLP receiver yoki exporter endpoint'ida `localhost`: konteyner ichida bu o'zi. Receiver `0.0.0.0` da, exporter servis nomi bilan.
- Protokol va port aralashishi: `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` va `:4318`, yoki `http/protobuf` va `:4317`. Span'lar ketmaydi, ilova ishlayveradi.
- Jaeger va Tempo'ning OTLP portlarini ikkalasini host'ga publish qilish: port to'qnashuvi.
- Eski qo'llanmadan `jaegertracing/all-in-one` (v1, deprecated) ni olish.
- Jaeger'ni xotiradagi storage bilan "vaqtincha" production'ga qo'yish: restart'da hamma trace yo'qoladi.
- Xatoni span'da belgilamaslik: exception ushlangan, `recordException` chaqirilgan, lekin status `Unset` qolgan: `{ span:status = error }` uni topmaydi.
- `span.end()` chaqirilmagan qo'lda span: u hech qachon yuborilmaydi.
- `trace_id` ni Loki label'i qilish: har so'rov yangi stream (4-dars).
- Trace → log'da label nomlari mos emas (`service.name` va `service`): o'tish bo'sh natija beradi.
- macOS'da Docker Desktop xotirasi yetmasligi: Tempo yoki Jaeger OOM bilan o'ladi. `docker info` dagi `Total Memory` ni tekshiring.

## Manbalar

- https://opentelemetry.io/docs/concepts/signals/traces/ – span, trace, kontekst tushunchalari (majburiy)
- https://www.w3.org/TR/trace-context/ – `traceparent` va `tracestate` spetsifikatsiyasi
- https://www.w3.org/TR/baggage/ – `baggage` header'i
- https://opentelemetry.io/docs/concepts/context-propagation/ – propagation
- https://nodejs.org/api/async_context.html – `AsyncLocalStorage`
- https://opentelemetry.io/docs/concepts/sampling/ – head va tail sampling
- https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor – `tail_sampling` processor
- https://opentelemetry.io/docs/zero-code/js/ – Node.js zero-code instrumentation
- https://opentelemetry.io/docs/languages/js/instrumentation/ – Node.js'da qo'lda span
- https://opentelemetry.io/docs/languages/go/getting-started/ – Go instrumentation
- https://opentelemetry.io/docs/languages/sdk-configuration/ – `OTEL_*` env o'zgaruvchilari
- https://opentelemetry.io/docs/specs/otlp/ – OTLP protokoli, JSON kodlash qoidalari
- https://www.jaegertracing.io/docs/latest/getting-started/ – Jaeger v2 ishga tushirish
- https://www.jaegertracing.io/download/ – Jaeger versiyalari, v1 deprecated belgisi
- https://grafana.com/docs/tempo/latest/ – Tempo
- https://grafana.com/docs/tempo/latest/traceql/ – TraceQL
- https://grafana.com/docs/tempo/latest/metrics-from-traces/ – metrics-generator, span metrics, service graph
- https://grafana.com/docs/grafana/latest/fundamentals/exemplars/ – exemplar'lar
- https://grafana.com/docs/grafana/latest/datasources/tempo/ – Tempo data source, trace to logs
- https://grafana.com/docs/grafana/latest/datasources/loki/ – Loki data source, derived fields
- https://research.google/pubs/dapper-a-large-scale-distributed-systems-tracing-infrastructure/ – Dapper maqolasi, modelning manbasi

---

## Birga bajaramiz

Trace'ni hech qanday SDK'siz, qo'lda yasab backend'ga yuboramiz va UI'da ko'ramiz. Maqsad: ilova kodi qilayotgan ishni (ID yaratish, ota havolasi, kind, status, OTLP) ko'z bilan ko'rish. Ssenariy vazifalardagidan boshqa: xayoliy `web` servisi `GET /weather/:city` ga ishlov berib `geo` servisini chaqiradi, `geo` esa `500` qaytaradi. Backend vaqtinchalik, stack'dan tashqarida ishga tushirilgan Jaeger v2 konteyneri; u 6-vazifadagi Compose servisining o'rnini bosmaydi. Buyruqlar host'da, ikkala mashinada bir xil (zsh va bash).

1. Jaeger'ni vaqtinchalik ishga tushiramiz. `<version>` o'rniga download sahifasidagi aniq v2 tag'ini yozing. Portlar faqat `127.0.0.1` ga. Stack'ingizda `4318` yoki `16686` host'ga publish qilingan bo'lsa, avval o'sha servisni to'xtating.

```
$ docker run --rm -d --name jaeger-demo \
    -p 127.0.0.1:16686:16686 -p 127.0.0.1:4318:4318 \
    jaegertracing/jaeger:<version>
<container id>
$ curl -s localhost:16686/api/services
{"data":[],"total":0,"limit":0,"offset":0,"errors":null}
```

`--rm` to'xtatilganda konteynerni o'chiradi. Servislar ro'yxati bo'sh (yoki faqat Jaeger'ning o'zi): hali hech kim span yubormagan. macOS'da port Docker Desktop VM'i orqali yo'naltiriladi, natija bir xil.

2. ID'lar va vaqt. Ishchi papka repodan tashqarida:

```
$ cd "$(mktemp -d)"
$ TRACE=4bf92f3577b34da6a3ce929d0e0e4736
$ NOW=$(date +%s)000000000
$ echo $NOW
1759917300000000000
```

`trace_id` 32 hex, span ID'lar 16 hex (1-bo'lim). OTLP vaqtni Unix epoch'dan nanosekundda kutadi: `date +%s` soniya beradi (GNU va BSD `date` da bir xil), oxiriga to'qqizta nol qo'shamiz. Vaqt hozirgi bo'lishi kerak, aks holda UI qidiruvi (default oxirgi 1 soat) uni ko'rsatmaydi.

3. Uchta span: `web` ning `SERVER` root'i (0..180 ms), `web` ning `CLIENT` span'i (10..170 ms), `geo` ning `SERVER` span'i (15..165 ms, xato). OTLP JSON'da kind va status raqam: `SERVER=2`, `CLIENT=3`, status `ERROR=2`.

```
$ cat > spans.json <<JSON
{"resourceSpans":[
 {"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"web"}}]},
  "scopeSpans":[{"scope":{"name":"by-hand"},"spans":[
   {"traceId":"$TRACE","spanId":"00000000000000a1","name":"GET /weather/:city","kind":2,
    "startTimeUnixNano":"$NOW","endTimeUnixNano":"$((NOW+180000000))",
    "attributes":[{"key":"http.response.status_code","value":{"intValue":"502"}}],"status":{"code":2}},
   {"traceId":"$TRACE","spanId":"00000000000000a2","parentSpanId":"00000000000000a1","name":"GET","kind":3,
    "startTimeUnixNano":"$((NOW+10000000))","endTimeUnixNano":"$((NOW+170000000))","status":{"code":2}}]}]},
 {"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"geo"}}]},
  "scopeSpans":[{"scope":{"name":"by-hand"},"spans":[
   {"traceId":"$TRACE","spanId":"00000000000000b1","parentSpanId":"00000000000000a2","name":"GET /coords/:city","kind":2,
    "startTimeUnixNano":"$((NOW+15000000))","endTimeUnixNano":"$((NOW+165000000))",
    "attributes":[{"key":"http.response.status_code","value":{"intValue":"500"}}],"status":{"code":2,"message":"upstream db timeout"}}]}]}
]}
JSON
```

Heredoc tirnoqsiz (`<<JSON`), shuning uchun shell `$TRACE` va `$((...))` ni qiymatga almashtiradi. Ikki `resourceSpans` elementi ikki jarayonni bildiradi: haqiqatda ular ikki xil konteynerdan alohida keladi. `geo` span'ining `parentSpanId` si `web` ning `CLIENT` span'i: 2-bo'limdagi ko'prik. OTLP JSON'da ID'lar hex matn, butun sonli atribut esa matn ichida (`"intValue":"500"`).

4. Yuboramiz. Bu ilova SDK'si exporter orqali qiladigan ishning o'zi:

```
$ curl -s -X POST localhost:4318/v1/traces \
    -H 'Content-Type: application/json' --data @spans.json
{"partialSuccess":{}}
$ curl -s localhost:16686/api/services
{"data":["geo","web"],"total":2,"limit":0,"offset":0,"errors":null}
```

`partialSuccess` bo'sh: hamma span qabul qilindi. Biror span rad etilganda bu yerda `rejectedSpans` soni va sabab bo'ladi. Ikkinchi so'rov: Jaeger endi ikki servisni biladi, ular faqat `service.name` dan olingan.

5. UI'da ko'ramiz: `http://localhost:16686/trace/4bf92f3577b34da6a3ce929d0e0e4736`. Waterfall:

```
web  GET /weather/:city   |==============================| 180ms   (error)
web    GET                  |==========================|   160ms   (error)
geo      GET /coords/:city   |========================|    150ms   (error)
```

- Uch qator, ikki servis, bitta trace: daraxt `parentSpanId` havolalaridan yig'ildi, garchi span'lar alohida resource'larda kelgan bo'lsa ham.
- `CLIENT` 160 ms, `geo` `SERVER` 150 ms: 10 ms tarmoq (5 ms borish, 5 ms qaytish), 1-bo'limdagi hisob.
- Uchala span'da xato belgisi. Eng chuqurdagi `geo` span'ini oching: `otel.status_description` (yoki status message) `upstream db timeout`. Xato shu yerda tug'ilgan, yuqoridagilar uni tarqatgan (`500` → `502`).
- System Architecture (yoki Deep Dependency Graph) bo'limida `web → geo` qirrasi paydo bo'ladi. U `CLIENT` va `SERVER` juftligidan chiqariladi; xotiradagi storage'da grafik kechikib yoki faqat qidiruvdan keyin chiqishi mumkin.

6. Propagation uzilishini simulyatsiya qilamiz. `web` header yubormagandek holat: `geo` yangi `trace_id` yaratadi va uning span'i root bo'ladi. Shu so'rovning `geo` qismini boshqa `trace_id` bilan va ota'siz yuboramiz (`web` qismi esa avvalgi trace'da allaqachon bor):

```
$ cat > broken.json <<JSON
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"geo"}}]},
  "scopeSpans":[{"scope":{"name":"by-hand"},"spans":[
   {"traceId":"0af7651916cd43dd8448eb211c80319c","spanId":"00000000000000c1","name":"GET /coords/:city","kind":2,
    "startTimeUnixNano":"$((NOW+60000000))","endTimeUnixNano":"$((NOW+90000000))","status":{"code":2}}]}]}]}
JSON
$ curl -s -X POST localhost:4318/v1/traces \
    -H 'Content-Type: application/json' --data @broken.json
{"partialSuccess":{}}
```

Jaeger Search'da `geo` servisini tanlang: endi ikkita trace. Yangisi bitta span'dan iborat, `geo` uning root'i, hech qanday `web` span'i yo'q. UI'da bu ikki trace orasida hech qanday bog'lanish yo'q: faqat vaqtning yaqinligi. Haqiqiy uzilishda xuddi shunday bo'ladi: `web` trace'ida `CLIENT` span'i ostida bola yo'q, `geo` esa alohida trace'da. 2-bo'limdagi "trace'ni nima uzadi" ning ko'rinishi shu.

7. `traceparent` ni tuzib ko'ring. Agar `web` haqiqatan instrumentatsiya qilingan bo'lsa, `geo` ga ketgan header qanday bo'lardi? `00-4bf92f3577b34da6a3ce929d0e0e4736-00000000000000a2-01`: version, trace-id, `CLIENT` span'ining ID'si (server span'ining emas), flags `01` (yozilyapti). Parent-id nima uchun `a1` emas, `a2` ekanini o'zingizga tushuntiring.

8. Tozalash:

```
$ docker stop jaeger-demo
jaeger-demo
```

`--rm` tufayli konteyner o'chdi, xotiradagi trace'lar bilan birga: bu 9-vazifaning mavzusi. Vaqtinchalik papkani ham o'chirishingiz mumkin.

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 2–3 | 1-bo'lim: span maydonlari, ID uzunliklari, kind, status, resource |
| 4 | 4-bo'lim: exporter qiladigan ish, OTLP HTTP `4318` |
| 5 | 1-bo'lim: daraxt yig'ilishi, `CLIENT`/`SERVER` farqi; 5-bo'lim: Jaeger UI |
| 6 | 2-bo'lim: uzilgan trace |
| 7 | 2-bo'lim: `traceparent` maydonlari |
| 8 | 5-bo'lim: xotiradagi storage |

---

## Vazifalar

Javoblar `observability/05-tracing/README.md` da (`make new m=observability n=05 name=tracing`), har vazifa uchun `## N. Title` ostida: nima qildingiz, config yoki so'rovning muhim qismi, kuzatuv (trace ID, span'lar soni, vaqtlar) va o'z so'zingiz bilan izoh. Stack fayllari (`app-inventory/`, `tempo/tempo.yaml`, provisioning o'zgarishlari, yangilangan `compose.yaml`) `observability/stack/` da. Hamma buyruq host'da `observability/stack/` papkasidan, ikkala mashinada bir xil. README'da qaysi mashinada bajarganingizni bir marta yozib qo'ying. Image'lar aniq tag bilan, `amd64` va `arm64` uchun mavjud bo'lsin; portlar `127.0.0.1` ga.

### A. Ikki servis va propagation

1. **Second service.** `inventory` servisini yozing (`api` bilan bir tilda yoki boshqa tilda): `GET /stock/:id` tasodifiy 10–150 ms kechikish bilan javob beradi, taxminan 3% holatda `500`. `api` ning `/checkout` endpoint'i endi `inventory` ni chaqirsin va uning xatosini `502` qilib qaytarsin. Hozircha tracing'siz. `inventory` ga ham 1-darsdagi metrikalar va 4-darsdagi JSON log'ni qo'shing. `api` dan `inventory` ga manzil env orqali berilsin (servis nomi bilan, `localhost` emas). Yo'nalish: Laboratoriya, portlar qoidasi; 1-dars 9–10 vazifalar.

2. **Trace by hand.** Instrumentatsiyasiz holatda bitta sekin `/checkout` so'rovining sababini faqat log va metrikalar bilan topishga urining. Qaysi savolga javob bera olmadingiz? Bu tracing'siz dunyoning bazaviy holati, yozib qo'ying. Yo'nalish: 1-bo'lim, "Tracing qaysi savolga javob beradi".

3. **Console exporter.** `api` ga OpenTelemetry tracing qo'shing, exporter `console`. Bitta so'rov yuboring va stdout'dagi span'dan `trace_id`, `span_id`, `parent`, kind, atributlarni ko'rsating. `/checkout` uchun nechta span chiqdi va har biri nima? Yo'nalish: 4-bo'lim, "Avtomatik instrumentatsiya" va "Misol: console exporter chiqishi".

4. **Read traceparent.** `inventory` ga kiruvchi header'larni vaqtincha log qiling. `api` orqali so'rov yuboring va `traceparent` qiymatini to'rt qismga ajratib tushuntiring. Keyin `curl` bilan o'zingiz tuzgan `traceparent` header'ini `api` ga yuboring: `api` span'idagi `trace_id` siznikiga tengmi? Ishingiz tugagach header log'ini olib tashlang. Yo'nalish: 2-bo'lim, "W3C Trace Context"; "Birga bajaramiz" 7-qadam.

5. **Break propagation.** `inventory` ni ham instrumentatsiya qiling. Keyin propagation'ni ataylab uzing (Node.js'da chiquvchi so'rovni instrumentatsiya qilinmagan usulda yuboring yoki header'ni olib tashlang; Go'da propagator'ni o'rnatmang). Backend'da nima ko'rinadi: nechta trace, qanday bog'langan? Tuzating. Backend sifatida hozircha console exporter'ning chiqishi yetadi (`trace_id` larni solishtiring) yoki 6-vazifadan keyin qaytib Jaeger'da ko'ring. Yo'nalish: 2-bo'lim, "Trace'ni nima uzadi"; "Birga bajaramiz" 6-qadam.

### B. Jaeger

6. **Jaeger all-in-one.** `jaeger` profilida Jaeger v2 ni qo'shing (`jaegertracing/jaeger` image'i, aniq tag; v1 `all-in-one` emas), ikkala servisni OTLP orqali unga yo'naltiring. UI'da `/checkout` trace'ini toping. Waterfall'dan o'qing: umumiy vaqt, `inventory` da ketgan vaqt, `CLIENT` va `SERVER` span orasidagi farq. Servislar bog'liqligi grafigini ko'rsating. Yo'nalish: 5-bo'lim, "Jaeger"; 1-bo'lim, "Misol: bitta trace, qatorma-qator".

7. **Find the slow and the failed.** Jaeger UI'da davomiyligi 200 ms dan yuqori va xatoli trace'larni filtr bilan toping. Xatoli trace'da xato qaysi span'da tug'ilgan va yuqoriga qanday tarqalgan (`500` → `502`)? Span'da exception event bormi? Yo'nalish: 1-bo'lim, "Span" (status, events); "Birga bajaramiz" 5-qadam.

8. **Manual span.** `api` da `/checkout` ichidagi biznes qadamga (masalan narx hisoblash, sun'iy 30 ms) qo'lda span qo'shing: nom, ikkita atribut, xato holatida status `Error` va exception yozuvi. Trace'da yangi span qayerda paydo bo'ldi? Ushlangan, lekin status belgilanmagan xato UI'da qanday ko'rinishini ham sinang. Yo'nalish: 4-bo'lim, "Qo'lda span".

9. **Restart loses traces.** Jaeger konteynerini restart qiling. Trace'lar qoldimi? Nima uchun, va production'da bu qanday hal qilinishini hujjatdan topib 2–3 gapda yozing. Profilni o'chiring. Yo'nalish: 5-bo'lim, "Jaeger"; Manbalardagi Jaeger hujjati.

### C. Tempo va TraceQL

10. **Tempo service.** `tempo/tempo.yaml` yozing (monolithic, lokal storage, OTLP receiver'lar), `tempo` servisini qo'shing (ma'lumot named volume'da), ilovalarni unga yo'naltiring. Grafana'ga Tempo data source'ni provisioning bilan (`uid: tempo`) qo'shing. Explore'da trace ID bo'yicha trace oching. Yo'nalish: 5-bo'lim, "Tempo" va "Misol: Tempo API"; Tempo'ning `example/docker-compose` config'lari.

11. **Receiver on localhost.** Tempo config'ida OTLP receiver endpoint'ini olib tashlang yoki `localhost:4318` qiling. Ilova log'ida va Tempo'da nima ko'rinadi? Trace'lar yo'qolganini ilova foydalanuvchisi sezadimi? Tuzating va nima uchun tracing exporter xatosi so'rovni yiqitmasligi kerakligini izohlang. Yo'nalish: 5-bo'lim, "Tuzoq: receiver `localhost` da"; 4-bo'lim, "Yuborish qanday ishlaydi".

12. **TraceQL queries.** TraceQL bilan toping: `api` ning 300 ms dan uzoq span'lari; xato statusli barcha span'lar; `/checkout` route'idagi 5xx javoblar; `api` ichidan chaqirilgan va xato bergan `inventory` span'lari (strukturaviy operator); ikkitadan ko'p xatoli span'i bor trace'lar. Har so'rov uchun bitta topilgan trace ID va `Matched` sonini yozing. Yo'nalish: 6-bo'lim.

13. **Head sampling.** `api` da `parentbased_traceidratio` bilan 10% sampling yoqing. 200 ta so'rov yuboring: Tempo'da nechta trace? `inventory` da sampling sozlanmagan bo'lsa ham u nechta span yubordi va nima uchun? Keyin `inventory` da `parentbased` siz `traceidratio` 50% qo'yib yarim trace'larni ko'rsating. 1-darsdagi `http_requests_total` bu paytda to'liq sanayaptimi? Oxirida sampling'ni laboratoriya uchun 100% ga qaytaring. Yo'nalish: 3-bo'lim.

14. **Service graph and span metrics.** Tempo'da metrics-generator'ni yoqing (span-metrics va service-graphs processor'lari), Prometheus'da remote write qabul qilishni yoqing. Prometheus'da `traces_spanmetrics_*` va `traces_service_graph_*` seriyalarini ko'rsating. Grafana'da service graph'ni oching. Span metrikalaridagi so'rov tezligini ilovaning o'z counter'i bilan solishtiring. Yo'nalish: 5-bo'lim, "Tempo" (metrics-generator); 3-bo'lim, "Sampling va metrikalar"; Manbalardagi metrics-from-traces hujjati.

### D. Bog'lash

15. **Trace ID in logs.** Ikkala servis log'lariga `trace_id` va `span_id` qo'shing. Bitta trace ID ni olib, Loki'da LogQL bilan shu so'rovning ikkala servisdagi barcha log'larini toping. `trace_id` ni Loki label'i qilmaganingizni ko'rsating. Yo'nalish: 7-bo'lim, "Mexanizm: log'da `trace_id`"; 4-dars.

16. **Logs to trace.** Loki data source provisioning'iga derived field qo'shing: log qatoridagi `trace_id` Tempo'ga havola bo'lsin. Explore'da error log qatoridan bir bosishda trace'ga o'ting. Yo'nalish: 7-bo'lim, "Uchta yo'l"; Manbalardagi Loki data source hujjati (provisioning faylida `$` belgisi qanday yozilishiga e'tibor bering).

17. **Trace to logs.** Tempo data source'da trace-to-logs'ni sozlang (Loki `uid`, servis nomi label'iga moslash, trace ID bo'yicha filtr). Span'dan uning log'lariga o'ting. Label nomlari mos kelmasa (`service.name` va `service`) nima bo'ladi va qanday moslanadi? Yo'nalish: 7-bo'lim, "Uchta yo'l" va "Label nomlari mos kelishi kerak".

18. **Exemplars.** Prometheus'da exemplar storage'ni yoqing, Prometheus data source'da exemplar'larni Tempo'ga bog'lang. Latency panelida exemplar'larni yoqing, yuqoridagi nuqtani bosib sekin so'rovning trace'iga o'ting. Exemplar qaysi manbadan kelayotganini (metrics-generator yoki ilova) yozing. Yo'nalish: 7-bo'lim, "Uchta yo'l" va "Mexanizm: exemplar formatda qanday ko'rinadi".

19. **Mini-project: find the slow hop.** `inventory` ga yashirin muammo qo'shing: ma'lum `id` lar uchun (masalan 7 ga karrali) 800 ms kechikish. O'zingizni bilmagan odam o'rniga qo'ying va yo'lni bosib o'ting: latency dashboard → exemplar → trace → sekin span va uning atributlari → shu trace'ning log'lari. `README.md` ga har qadamda nima ko'rganingizni va qaysi so'rov (PromQL, TraceQL, LogQL) ishlatilganini yozing. Shu muammoni faqat metrika va log bilan topish qancha qiyin bo'lardi? Loyiha ikkinchi mashinada ham `git pull`, `.env` va `docker compose up -d --build` bilan ko'tarilishini tekshiring. Yo'nalish: hamma bo'limlar; 2-vazifadagi bazaviy holat bilan solishtiring.

### Topshirish

Tayyor bo'lgach:
1. 19 ta vazifaning javobi `observability/05-tracing/README.md` da, `## N. Title` sarlavhalari ostida.
2. Toza `docker compose up -d` dan keyin `/checkout` trace'i ikkala servis span'lari bilan Tempo'da ko'rinadi.
3. Data source bog'lanishlari (exemplar, trace-to-logs, derived field) provisioning fayllarida, UI'da qo'lda emas.
4. Barcha image'lar aniq tag'da, portlar `127.0.0.1` ga; `.env`, `node_modules`, ma'lumot volume'lari commit qilinmagan.
5. Sinov uchun qilingan o'zgarishlar qaytarilgan: header log'i, buzilgan propagation, `localhost` receiver, 10% sampling.
6. `make check` toza.
7. `jaeger` profili o'chirilgan, `docker compose --profile jaeger down` qilingan.
8. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Span'lar daraxti qanday yig'iladi, agar hech bir servis butun trace'ni bilmasa?
- `traceparent` header'ining to'rt qismi nima va sampling qarori qayerda uzatiladi?
- Nima uchun Node.js'da joriy span'ni global o'zgaruvchida saqlab bo'lmaydi va Go bu muammoni qanday hal qiladi?
- Propagation uzilganda UI'da nima ko'rinadi va eng ko'p uchraydigan sabablari nima?
- Head va tail sampling farqi nima? Kam uchraydigan xatoni ushlash uchun qaysi biri kerak va uning narxi nima?
- `parentbased` sampler nima uchun kerak?
- Nima uchun RED metrikalarini sampling qilingan trace'lardan hisoblab bo'lmaydi?
- Nima uchun tracing exporter'ining nosozligi foydalanuvchi so'roviga ta'sir qilmasligi kerak va SDK buni qanday ta'minlaydi?
- Exemplar nima va u qaysi ikki signalni bog'laydi?
- Jaeger va Tempo o'rtasida qanday tanlaysiz?
- Nima uchun `trace_id` log maydoni bo'ladi, lekin Loki label'i emas?
