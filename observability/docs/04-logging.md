# 4-dars: Logging

Maqsad: log'larni har konteynerga `docker logs` bilan kirib o'qishdan markazlashgan, so'rov yoziladigan tizimga o'tkazish. Metrika (observability 1-dars) "xato ulushi 8%" deydi, log "qaysi xato, qaysi so'rovda, qanday matn bilan" deydi. Linux 7-darsda bitta log faylga `grep` va `awk` bilan savol bergansiz; bu dars o'sha savollarni o'nlab konteyner ustida, indeks bilan va brauzerdan berishni o'rgatadi. Yo'l noldan quriladi: yaxshi log qatori qanday bo'ladi, u `console.log` dan saqlash tizimigacha qaysi bo'g'inlardan o'tadi, Loki uni qanday saqlaydi (faqat label'lar indekslanadi), LogQL bilan qanday so'raladi va Elasticsearch nima uchun teskari yo'lni tanlagan (har so'z indekslanadi). Asosiy amaliyot Loki bilan, chunki u 2-darsdagi Grafana va 1-darsdagi label modeli bilan bir xil tilda gaplashadi; Elasticsearch va Kibana bilan kichikroq tanishuv bo'ladi. 5-darsda log'larga `trace_id` qo'shilib trace'lar bilan bog'lanadi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh; ikkinchi kun 3–4 bo'limlar, "Birga bajaramiz" va B guruhning 4–7 vazifalari; uchinchi kun 8–10 vazifalar, 5–6 bo'limlar va C guruhning 11–14 vazifalari; to'rtinchi kun 7-bo'lim va 15–17 vazifalar, 8–9 bo'limlar va D guruhning 18–19 vazifalari; beshinchi kun 20-vazifa, mini-loyiha (21) va README. Diqqatni quyidagilarga qarating: Loki'da label va matn filtri orasidagi chegara (nima label bo'ladi, nima yo'q), LogQL pipeline bosqichlari tartibi, log'dan metrika chiqarish, inverted index nima uchun tez va nima uchun qimmat, retention.

Qanday o'qish kerak: har bo'limdagi misolni o'z stack'ingizda takrorlang va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi vaqt belgilari, ID'lar va sonlar farq qiladi, bunday joylar `<...>` bilan belgilangan. Nazariya misollari ataylab boshqa servis (`mailer`) ustida yozilgan: vazifalarda ularni `api` ilovangizga o'zingiz moslaysiz. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hammasi host'dagi Docker Compose'da, umumiy `observability/stack/` papkasida (1–3 darslarda qurilgan stack ustiga). Host'ga hech narsa o'rnatilmaydi: `logcli`, `alloy fmt` kabi CLI'lar konteyner ichidan (`docker compose exec` yoki `docker run --rm`) ishlatiladi. Bu darsda qo'shiladigan servislar:

| Servis | Port (faqat `127.0.0.1` ga publish qilinadi) | Qachon ishlaydi |
|--------|-----------------------------------------------|-----------------|
| `loki` | `3100` (HTTP API) | doim |
| `alloy` | `12345` (UI) | doim |
| `elasticsearch`, `kibana` | `9200`, `5601` | faqat `logs-es` Compose profili bilan, D guruh vazifalarida |

```
cd observability/stack
mkdir -p loki alloy
docker compose up -d                        # everything except profiled services
curl -s localhost:3100/ready                # prints "ready" after Loki's startup delay
docker compose --profile logs-es up -d      # only for group D
docker compose --profile logs-es down       # stop ES + Kibana when done (volumes kept)
```

- **Versiyalar**: `latest` ishlatilmaydi, aniq tag yoziladi. Joriy barqaror versiyalar: https://github.com/grafana/loki/releases , https://github.com/grafana/alloy/releases , Elastic uchun https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic . Image ikkala arxitekturada (`amd64`, `arm64`) borligini registry sahifasidagi "OS/Arch" ro'yxatidan tekshiring; Elasticsearch va Kibana bir xil versiyada bo'lishi shart.
- **Docker socket**: Alloy konteyner log'larini Docker API orqali o'qiydi, buning uchun `/var/run/docker.sock` mount qilinadi. Socket'ga kirish Docker Engine'ni to'liq boshqarish, ya'ni amalda host'da root huquqi (docker 1-dars). `:ro` bilan mount qilish faqat socket faylining o'zini almashtirishdan saqlaydi, API orqali yuboriladigan buyruqlarni cheklamaydi. Shuning uchun bu image faqat rasmiy manbadan, aniq versiya bilan olinadi.
- **Xotira**: Elasticsearch va Kibana og'ir. Elasticsearch single-node rejimda (`discovery.type=single-node`) ishga tushiriladi: bu rejimda production bootstrap tekshiruvlari (jumladan `vm.max_map_count` kernel parametri talabi) majburlanmaydi, shuning uchun Zorin host'ida `sysctl` o'zgartirilmaydi. JVM heap `ES_JAVA_OPTS` (`-Xms`, `-Xmx`) bilan cheklanadi va konteynerga xotira limiti qo'yiladi. `docker stats` bilan kuzating.
- **Secret'lar**: parol va token'lar commit qilinmaydigan `.env` da (`make secrets` commit qilingan `.env` ni rad etadi). `compose.yaml`, `loki/`, `alloy/` config'lari commit qilinadi, volume'lar yo'q.
- **Mashg'ulot oxiri**: `docker compose --profile logs-es down`, keyin `docker compose down` (volume'lar qoladi). `docker system prune` va `docker volume prune -a` ishlatilmaydi: ikkala mashinada boshqa loyihalarning konteyner va volume'lari bor. Keraksiz volume nomi bilan o'chiriladi: `docker volume rm <nom>`.

| Mashina | Zorin (ofis) | macOS (uy) |
|---------|--------------|------------|
| Arxitektura | `amd64` image'lar | `arm64` image'lar |
| Konteyner log fayllari | host'da, `/var/lib/docker/containers/<id>/<id>-json.log` (root o'qiydi) | Docker Desktop'ning yashirin Linux VM'i ichida, host'dan ko'rinmaydi |
| `/var/run/docker.sock` mount | host'dagi Docker Engine socket'i | VM ichidagi engine socket'i, konteyner uchun xuddi shunday ishlaydi |
| Docker API orqali yig'ish (bu darsdagi asosiy yo'l) | ishlaydi | ishlaydi |
| Host yo'lini tail qilish (`/var/lib/docker/containers`, 20-vazifadagi Filebeat) | ishlaydi | host'da bu yo'l yo'q; 20-vazifadagi eslatmaga qarang |
| Host tizim log'lari (journald, `/var/log`) | ixtiyoriy, faqat o'qish uchun | bu yerda mavjud emas (Mac'da journald yo'q) |
| Xotira chegarasi | host RAM | Docker Desktop VM limiti: `docker info` chiqishidagi `Total Memory` qatori. Kam bo'lsa Docker Desktop sozlamalarida (Resources) oshiriladi |

Ikkinchi mashinada tiklash: `git pull`, `.env` ni qo'lda qayta yarating (git'da yo'q), `docker compose up -d`. Config va `compose.yaml` git orqali keladi, shuning uchun pipeline bir xil ishlaydi. Volume'lar ko'chmaydi: Loki'dagi log tarixi har mashinada o'ziniki va bo'sh boshlanadi. Vazifa natijasi uchun log kerak bo'lsa `loadgen` ni bir necha daqiqa ishlatib yangi log hosil qiling.

---

## 1. Yaxshi log qatori

### Log nima va uni kim o'qiydi

Log bu dastur ish paytida yozib boradigan, vaqt belgisi bor hodisa yozuvlari: "so'rov keldi", "to'lov rad etildi", "bazaga ulanib bo'lmadi". Frontend'da `console.log` ni DevTools'da o'zingiz, shu zahoti ko'rasiz. Serverda uni hech kim jonli kuzatmaydi: log soatlar yoki kunlar o'tgach, incident paytida, minglab so'rovlarning qatorlari aralashgan holda o'qiladi, ko'pincha odam emas, so'rov tili orqali. Shuning uchun server log'i odam uchun emas, avvalo mashina uchun yoziladi.

### Structured logging

Matnli log (`Retry 2 for user 42: smtp timeout after 812ms`) odamga qulay, lekin undan "nechanchi urinish" yoki "necha millisekund" ni olish uchun regex kerak (linux 7-darsdagi `awk` mashqlari shu edi). **Structured log** har yozuvni kalit-qiymatli obyekt qiladi, odatda bir qatorda bitta JSON:

```json
{"time":"2026-10-05T10:15:03.120Z","level":"warn","msg":"email send retry","service":"mailer","template":"welcome","attempt":2,"took_ms":812,"request_id":"9f2c61d0","err":"smtp timeout"}
```

Maydonma-maydon:

- `time`: hodisa vaqti, UTC, RFC 3339 formatida (`Z` oxirida UTC degani). Serverlar har xil vaqt zonasida bo'lishi mumkin, UTC bitta umumiy o'q beradi.
- `level`: muhimlik darajasi (pastdagi jadval). Filtrlash va hisoblash shu maydon bo'yicha.
- `msg`: **o'zgarmas** matn. O'zgaruvchi qiymat (`42`, `812`) matn ichiga emas, alohida maydonga yoziladi. Shunda `msg="email send retry"` bo'yicha barcha shunday hodisalarni sanash mumkin; `"Retry 2 for user 42"` kabi matn esa har safar yangi satr va guruhlanmaydi.
- `service`, `template`, `attempt`, `took_ms`: kontekst. Nomlar barqaror bo'lishi kerak: bir joyda `took_ms`, boshqa joyda `duration` yozilsa, so'rov ikkalasini bilishi kerak bo'ladi. Birlik nomda (`_ms`), qiymat son turida (tirnoqsiz), aks holda "800 dan katta" degan filtr ishlamaydi.
- `request_id`: **correlation ID**, bitta kiruvchi so'rovga tegishli barcha log qatorlarida bir xil turadigan identifikator. Server bir vaqtda yuzlab so'rovga xizmat qiladi va ularning qatorlari aralashib yoziladi; aynan bitta so'rov tarixini yig'ib beradigan yagona narsa shu ID. Odatda kiruvchi `X-Request-Id` header'idan olinadi, yo'q bo'lsa generatsiya qilinadi. 5-darsda uning o'rnini `trace_id` egallaydi.
- `err`: xato matni alohida maydonda. Ko'p qatorli stack trace ham bitta maydon ichida (`\n` bilan) turadi, aks holda har qatori alohida yozuvga aylanadi.

### Logger kutubxonasi nima qiladi

`console.log(obj)` obyektni odam o'qiydigan ko'rinishda chiqaradi, level va vaqt qo'shmaydi. Structured logger (Node.js'da `pino` yoki `winston`, Go'da standart `log/slog` ning `slog.NewJSONHandler` i) har chaqiruvda vaqt va level qo'shib, bitta JSON qatorni stdout'ga yozadi va belgilangan level'dan past yozuvlarni umuman chiqarmaydi. Bitta tafsilot: pino default holatda `level` ni son bilan (`30` info, `40` warn, `50` error), `time` ni Unix epoch millisekundda yozadi:

```json
{"level":40,"time":1759659303120,"pid":1,"hostname":"<container id>","msg":"email send retry","attempt":2}
```

Bu to'g'ri JSON, lekin `level="warn"` deb qidirgan so'rov uni topmaydi. Logger sozlamasida level nomi va ISO vaqt yoqiladi (pino'da `formatters.level` va `timestamp` opsiyalari, hujjati Manbalarda).

### Log level'lar

| Level | Ma'nosi | Production'da |
|-------|---------|---------------|
| `debug` | dasturchi uchun ichki tafsilot | o'chiq, vaqtincha yoqiladi |
| `info` | normal hodisa: so'rov tugadi, servis ishga tushdi | yoqiq |
| `warn` | kutilmagan, lekin ishlov berilgan: retry, fallback | yoqiq |
| `error` | operatsiya bajarilmadi, e'tibor kerak | yoqiq, hisoblanadi |

Level bu chegara: `LOG_LEVEL=warn` bo'lsa `warn` va undan yuqorilari chiqadi, `info` va `debug` chiqmaydi. U environment variable orqali beriladi, shunda darajani o'zgartirish uchun image qayta build qilinmaydi, konteyner qayta ishga tushiriladi xolos. Foydalanuvchining noto'g'ri kiritishi (HTTP `400`) server xatosi emas: `error` soni alert manbai bo'ladi (3-dars), uni mijoz xatolari bilan to'ldirsangiz haqiqiy nosozlik shovqinda yo'qoladi.

### Log'ga nima yozilmaydi

Parol, token, `Authorization` va `Cookie` header'lari, karta raqami, shaxsiy ma'lumot (telefon, pasport, to'liq ism bilan manzil). Log tizimi kompaniyada eng ko'p odam kira oladigan joy, log'lar haftalab saqlanadi, backup'ga va uchinchi tomon servislariga ko'chadi. Bir marta yozilgan secret'ni u yerdan tozalash deyarli imkonsiz, token'ni almashtirish kerak bo'ladi. Shuning uchun maskalash (redaction) ilovaning o'zida qilinadi: logger'ga "shu yo'ldagi maydonlarni `[REDACTED]` ga almashtir" deb aytiladi (pino'da `redact` opsiyasi). Collector'da maskalash kech: qator o'sha paytgacha konteyner runtime'ining log faylida ochiq yotgan bo'ladi.

### Real ishda qachon kerak

- Yangi servis yozilganda birinchi kun: logger, maydon nomlari va `request_id` kelishib olinadi. Keyin o'zgartirish barcha dashboard va alert'larni sindiradi.
- Incident'da: mijoz "to'lovim o'tmadi" deydi, sizda javob header'idagi `request_id` bor, bitta so'rov bilan uning butun tarixi chiqadi.
- Xavfsizlik auditida: "log'larda token bormi" degan savolga `grep` emas, logger'dagi redaction ro'yxati javob beradi.

### Nima uchun shunday

Matnli log'lar bitta serverda `tail -f` bilan o'qiladigan davrdan qolgan. Servislar ko'payib log'lar markaziy tizimga yig'ila boshlagach, har formatga alohida regex yozish va uni har o'zgarishda tuzatish asosiy xarajatga aylandi. JSON'da parse qilish bitta umumiy amal, maydon qo'shish eski so'rovlarni buzmaydi. Narxi: qator uzunroq va ko'z bilan o'qish qiyinroq, lekin bu so'rov tili (`line_format`, 5-bo'lim) bilan qoplanadi. Muqobili `logfmt` (`level=warn msg="email send retry" attempt=2`): ixchamroq va o'qishli, Prometheus, Loki va Grafana'ning o'z log'lari shu formatda, lekin ichma-ich obyekt va son turi yo'q.

## 2. Qatorning yo'li: stdout'dan saqlash tizimigacha

### Nima uchun stdout

Konteynerdagi ilova log'ni faylga emas, stdout va stderr ga yozadi (docker 1-dars). Twelve-Factor App tamoyili buni shunday aytadi: ilova log'ni hodisalar oqimi deb biladi va uni qayerga yetkazish, saqlash, rotatsiya qilish bilan shug'ullanmaydi, bu ishlar ijro muhitiga (platformaga) tegishli. Ilova fayl yo'lini, log serveri manzilini va uning parolini bilmaydi; laptop'da o'sha oqim terminalga, production'da collector'ga boradi, kod bir xil.

### Mexanizm: besh bo'g'in

```
app (stdout) -> container runtime (json-file) -> collector (Alloy) -> store (Loki / Elasticsearch) -> UI (Grafana / Kibana)
```

1. Ilova `write` system call'i bilan qatorni 1-file descriptor'ga (stdout) yozadi.
2. Docker konteynerning stdout va stderr'ini o'zi ushlab oladi va **logging driver** ga beradi. Logging driver bu Docker'ning konteyner chiqishini qayerga yozishini belgilaydigan moduli. Default driver `json-file`: har qator konteyner papkasidagi faylga JSON o'ramida yoziladi. `docker logs` va `docker compose logs` aynan shu faylni o'qiydi.
3. **Collector** (log yig'uvchi agent) har host'da ishlaydigan alohida jarayon: konteynerlarni topadi, log'larini o'qiydi, har qatorga "qaysi servis, qaysi konteyner" degan label qo'shadi, batch qilib saqlash tizimiga yuboradi va tizim vaqtincha javob bermasa qayta urinadi.
4. **Store** qatorlarni qabul qilib indekslaydi va diskda saqlaydi (3 va 8-bo'limlar).
5. UI so'rov yuboradi va natijani ko'rsatadi (observability 2-darsdagi Grafana Explore).

### Misol: bitta qator ikki ko'rinishda

Ilova yozgan qator (`docker compose logs mailer` ko'rsatadigan ko'rinish, Compose oldiga konteyner nomini qo'shadi):

```
mailer-1  | {"time":"2026-10-05T10:15:03.120Z","level":"warn","msg":"email send retry","attempt":2}
```

O'sha qator Docker'ning log faylida (Zorin'da `sudo` bilan o'qiladi, faqat ko'rish uchun; macOS'da bu fayl Docker Desktop VM'i ichida):

```
{"log":"{\"time\":\"2026-10-05T10:15:03.120Z\",\"level\":\"warn\",\"msg\":\"email send retry\",\"attempt\":2}\n","stream":"stdout","time":"2026-10-05T10:15:03.120481923Z"}
```

- `log`: ilova yozgan qator, o'zgarishsiz, oxiridagi `\n` bilan. Ilovaning JSON'i bu yerda satr ichida, tirnoqlari `\"` qilib ekranlangan: Docker uni tushunmaydi, shunchaki matn deb saqlaydi.
- `stream`: `stdout` yoki `stderr`, qator qaysi oqimdan kelgani.
- `time`: Docker qatorni qabul qilgan vaqt (nanosekundgacha). Bu ilovaning o'z `time` maydonidan biroz kech. Collector odatda shu vaqtni yozuv vaqti qilib oladi.

Fayl cheksiz o'smasligi uchun `json-file` driver'iga `max-size` va `max-file` opsiyalari beriladi (docker 1-dars): ular bo'lmasa gap ko'p ilova host diskini to'ldiradi.

### Ikki mashinada collector log'ni qanday oladi

Collector log'ga ikki yo'l bilan yetishi mumkin. Birinchisi: host'dagi `/var/lib/docker/containers/` fayllarini to'g'ridan-to'g'ri tail qilish. Bu faqat Linux host'da (Zorin) ishlaydi, chunki macOS'da bu papka Docker Desktop'ning yashirin VM'i ichida. Ikkinchisi: Docker API'dan so'rash (konteynerlar ro'yxati va `docker logs` ga teng oqim). Buning uchun collector konteyneriga `/var/run/docker.sock` mount qilinadi; macOS'da ham konteyner ichidan bu yo'l VM'dagi engine socket'iga ulanadi. Shuning uchun bu darsda ikkinchi yo'l asosiy: bitta config ikkala mashinada ishlaydi.

Host'ning o'z tizim log'lari (linux 8 va 11-darslardagi journald, `/var/log`) alohida manba. Zorin'da ularni yig'ish ixtiyoriy va faqat o'qish uchun mount bilan; Mac'da journald yo'q, bu qism u yerda mavjud emas.

### Real ishda qachon kerak

- "Log'lar kelmayapti" degan muammoda zanjir bo'g'inma-bo'g'in tekshiriladi: `docker compose logs` da bormi (1–2 bo'g'in), collector UI'da o'qilyaptimi (3), store qabul qilyaptimi (4).
- Konteyner o'chirilganda uning log fayli ham o'chadi. Markazlashgan yig'ish bo'lmasa, yiqilib qayta yaratilgan konteynerning o'limidan oldingi log'lari yo'qoladi, ya'ni eng kerakli qatorlar.
- Kubernetes'da ham xuddi shu zanjir: kubelet konteyner log'ini node'dagi faylga yozadi, collector har node'da DaemonSet bo'lib ishlaydi (kubernetes moduli).

### Nima uchun shunday

Ilova o'zi faylga yozsa, har ilovada rotatsiya, disk to'lishi va fayl ruxsatlari qayta hal qilinadi; konteynerning yozish qatlami shishadi va konteyner bilan birga o'chadi. Ilova to'g'ridan-to'g'ri log serveriga yozsa, server sekinlashganda ilova ham sekinlashadi yoki log'ni yo'qotadi, va har ilovaga server manzili bilan paroli tarqatiladi. Stdout eng kichik umumiy shartnoma: har tilda bor, hech qanday kutubxona talab qilmaydi. Collector alohida jarayon bo'lgani uchun buferlash, qayta urinish va label qo'shish bir joyda, bir marta yoziladi. Muqobillar bor va ishlatiladi: Docker'ning boshqa logging driver'lari (`journald`, `fluentd`) yoki ilovadan OTLP orqali yuborish (7-dars), lekin stdout yo'li har doim zaxira bo'lib qoladi.

## 3. Loki: label'lar indeksi va chunk'lar

### G'oya: stream va label

Loki log matnini indekslamaydi. Har log qatori bitta **stream** ga tegishli: stream bu label'lari bir xil bo'lgan qatorlar ketma-ketligi, xuddi Prometheus'da bitta series label to'plami bilan aniqlangani kabi (observability 1-dars). `{service="mailer", env="lab"}` bitta stream, `{service="mailer", env="prod"}` boshqa stream. Indeksda faqat label'lar va "shu stream'ning shu vaqt oralig'idagi ma'lumoti qaysi chunk'larda" degan havolalar turadi. **Chunk** bu bitta stream'ning ketma-ket qatorlaridan yig'ilgan, siqilgan blok. Matnning o'zi chunk'larda, object storage'da (S3, GCS; laboratoriyada konteyner ichidagi lokal disk) saqlanadi.

So'rov ikki bosqichda bajariladi: label selector indeks orqali kerakli stream va chunk'larni tanlaydi, keyin o'sha chunk'lar ochilib, ichidagi matn ketma-ket "grep" qilinadi. Oqibati: yozish va saqlash arzon (indeks kichik), tor selector va qisqa vaqt bilan so'rov tez, keng selector bilan uzoq oraliqdagi so'rov sekin, chunki ko'p chunk o'qiladi va ochiladi.

### Mexanizm: yozish va o'qish yo'li

| Komponent | Vazifasi |
|-----------|----------|
| Distributor | push so'rovini qabul qiladi, label'larni tekshiradi, limitlarni qo'llaydi, qatorlarni ingester'larga tarqatadi |
| Ingester | har stream uchun xotirada ochiq chunk tutadi, unga qator qo'shadi; chunk to'lganda yoki eskirganda uni storage'ga yozadi |
| Querier, query frontend | so'rovni vaqt bo'yicha bo'laklarga ajratadi, yangi qatorlarni ingester'dan, eskilarini storage'dan o'qiydi |
| Compactor | indeks fayllarini ixchamlaydi, retention va o'chirishni bajaradi (7-bo'lim) |
| Ruler | LogQL asosidagi alert va recording rule'larni hisoblaydi |

Yozish yo'li: Alloy `POST /loki/api/v1/push` yuboradi, distributor qabul qiladi, ingester qatorni stream'ning ochiq chunk'iga qo'shadi. Chunk ma'lum hajmga yetganda yoki ma'lum vaqt yangi qator kelmasa (Loki config'idagi `chunk_target_size`, `chunk_idle_period`, `max_chunk_age`) siqilib storage'ga tushadi. Shuning uchun hali flush qilinmagan oxirgi daqiqalar ingester xotirasida turadi va Loki keskin o'chsa yo'qolishi mumkin; buni ingester'ning WAL'i (write-ahead log, diskka oldindan yoziladigan jurnal) yumshatadi.

**Monolithic rejim**: hamma komponent bitta jarayonda ishlaydi (`-target=all`, default). Laboratoriya va kichik hajm uchun shu. Katta hajmda komponentlar alohida masshtablanadi (read, write va backend yo'llari). Image ichida tayyor config bor: `/etc/loki/local-config.yaml` (filesystem storage, bitta instans, autentifikatsiyasiz). Autentifikatsiya o'chiq bo'lganda Loki hamma ma'lumotni bitta **tenant** (ijarachi, ma'lumotlari ajratilgan mijoz) ostida saqlaydi, uning nomi `fake`; metrikalarda shu nomni ko'rasiz.

### Misol: Loki'dan nima bor deb so'rash

Quyidagi chiqish label'lar Alloy'da sozlangandan keyingi holat (4-bo'lim). `python3 -m json.tool` faqat JSON'ni chiroyli chiqarish uchun, ikkala mashinada bor.

```
$ curl -s localhost:3100/loki/api/v1/labels
{"status":"success","data":["container","service","service_name"]}

$ curl -sG localhost:3100/loki/api/v1/label/service/values
{"status":"success","data":["alloy","grafana","loki","mailer","prometheus"]}

$ curl -sG localhost:3100/loki/api/v1/series --data-urlencode 'match[]={service="mailer"}' | python3 -m json.tool
{
    "status": "success",
    "data": [
        {
            "container": "stack-mailer-1",
            "service": "mailer",
            "service_name": "mailer"
        }
    ]
}

$ curl -s localhost:3100/metrics | grep '^loki_ingester_memory_streams'
loki_ingester_memory_streams{tenant="fake"} 9
```

- `labels`: oxirgi vaqt oralig'idagi (default 6 soat) barcha label nomlari. `service_name` ni siz qo'shmagansiz: Loki 3.x qabul paytida uni o'zi qo'shadi, qiymatini `service`, `app`, `container` kabi label'lardan oladi, hech biri bo'lmasa `unknown_service` yozadi. Grafana'ning Logs Drilldown sahifasi shu label'ga tayanadi.
- `label/service/values`: bitta label'ning qiymatlari. Ro'yxat qisqa va cheklangan, label'dan aynan shu kutiladi.
- `series`: selector'ga mos stream'lar. `mailer` uchun bitta stream: konteyner qayta yaratilsa ham nomi o'zgarmaydi, stream ham bitta qoladi.
- `loki_ingester_memory_streams`: ingester xotirasida ochiq turgan stream'lar soni, cardinality'ning eng to'g'ridan-to'g'ri o'lchovi. `tenant="fake"` yuqorida aytilgan yagona tenant.

### Label'lar: eng muhim qaror

Label'lar kam va cheklangan qiymatli bo'ladi: `service`, `container`, `env`, ehtimol `level`. Har noyob label kombinatsiyasi alohida stream, har stream alohida chunk'lar. 5 servis × 4 level = 20 stream; bu yaxshi.

**Yuqori cardinality'li label** (cardinality: label olishi mumkin bo'lgan turli qiymatlar soni, 1-dars). `user_id`, `request_id`, `trace_id`, `path` label qilinsa har so'rov yangi stream ochadi: indeks shishadi, har stream'da bitta-ikkita qator bo'lgani uchun chunk'lar to'lmaydi va mayda bo'laklar bo'lib yoziladi, ingester xotirasi tugaydi, so'rov minglab mayda chunk'ni ochadi. Loki o'zini himoya qiladi: `limits_config` dagi `max_global_streams_per_user` (bitta tenant uchun faol stream'lar chegarasi) oshsa, push rad etiladi va bu `loki_discarded_samples_total` metrikasida `reason` label'i bilan ko'rinadi. Bunday qiymatlar log matnida qoladi va so'rov vaqtida filtrlanadi: `{service="mailer"} | json | request_id="9f2c61d0"`.

**Structured metadata**: qatorga biriktirilgan, lekin stream'ni bo'lmaydigan kalit-qiymat. U indeksga kirmaydi, chunk ichida qator yonida saqlanadi va so'rovda label kabi filtrlanadi (`| trace_id="..."`). Yuqori cardinality'li, lekin tez-tez qidiriladigan ID'lar uchun mos. Loki 3.x da default yoqiq (schema `v13` va `tsdb` indeksi bilan), OTLP orqali kelgan log atributlari shu yerga tushadi (7-dars).

### Real ishda qachon kerak

- Yangi servis log'ini ulashdan oldin: qaysi maydon label bo'ladi, qaysi biri matnda qoladi, shu qaror keyin narx va tezlikni belgilaydi.
- Loki sekinlashsa yoki push'lar rad etilsa birinchi qaraladigan joy: `loki_ingester_memory_streams` va `series` API, qaysi label portlagan.
- Incident'da so'rov tez chiqishi uchun selector'ni servis va vaqt bilan toraytirish odati.

### Nima uchun shunday

Grafana Labs Loki'ni "log'lar uchun Prometheus" deb loyihalagan: bir xil label modeli, metrika va log o'rtasida bir xil label'lar bilan o'tish. To'liq matnli indeks (8-bo'lim) yozishda qimmat va xom ma'lumotga yaqin joy oladi; ko'p jamoalar log'ni asosan "shu servis, shu vaqt" bo'yicha o'qiydi va bu holatda butun matnni indekslash ortiqcha xarajat. Loki indeksni kichik qilib, hisobni so'rov vaqtiga, parallel o'qishga ko'chirgan; arzon object storage buni amalga oshiradi. Muqobil yo'l (Elasticsearch) aksincha: yozishda qimmat, ixtiyoriy so'z bo'yicha qidiruvda tez.

## 4. Grafana Alloy bilan yig'ish

### Promtail endi yo'q

Uzoq vaqt Loki'ning collector'i Promtail edi. Loki hujjatlariga ko'ra Promtail 2026-yil 2-martda end of life (EOL, ishlab chiqaruvchi yangilanish va xavfsizlik tuzatishlarini to'xtatgan holat) bo'ldi, rivojlanish Grafana Alloy'da davom etadi. Internetdagi ko'p maqola va `compose.yaml` namunalarida hali Promtail yoki eski Docker Loki logging plugin'i bor: ulardan nusxa olmang. Eski Promtail config'ini Alloy'ga `alloy convert --source-format=promtail` buyrug'i o'tkazadi.

### Alloy config tili

Alloy bitta binary, u log, metrika, trace va profillarni yig'a oladi (7-darsda yana ko'rasiz). Config'i **komponentlar** dan iborat: har komponent blok ko'rinishida yoziladi (`turi "nomi" { argumentlar }`), argumentlarni oladi va **export** larni (boshqa komponent ishlata oladigan chiqishlar) beradi. Komponentlar bir-biriga havola orqali ulanadi va Alloy ulardan graf quradi. Frontend'dagi o'xshatish haqiqiy: bu stream'lar zanjiri (`pipe`), har bo'g'in chiqishini keyingisiga uzatadi.

Quyidagi misol Docker emas, fayl manbaidan o'qiydi; u faqat sintaksis va ulanishni ko'rsatadi (`mailer` log faylini tail qiladi deb faraz qilaylik):

```alloy
local.file_match "mailer" {
  path_targets = [{"__path__" = "/var/log/mailer/*.log", "service" = "mailer"}]
}

loki.source.file "mailer" {
  targets    = local.file_match.mailer.targets
  forward_to = [loki.write.local.receiver]
}

loki.write "local" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

- `local.file_match` fayllarni topadi va `targets` export qiladi. `__path__` maxsus kalit: qaysi faylni o'qish.
- `loki.source.file` shu target'larni oladi (`local.file_match.mailer.targets`: tur, nom, export nomi) va o'qigan qatorlarini `forward_to` ro'yxatidagi qabul qiluvchilarga yuboradi.
- `loki.write` `receiver` export qiladi va qatorlarni batch qilib Loki'ga push qiladi; Loki javob bermasa qayta urinadi.

Docker uchun mos komponentlar boshqa, ulanish mantig'i xuddi shu:

| Komponent | Asosiy argumentlar | Nima beradi |
|-----------|-------------------|-------------|
| `discovery.docker` | `host` (masalan `unix:///var/run/docker.sock`) | ishlayotgan konteynerlar ro'yxati, har biri `__meta_docker_*` label'lari bilan |
| `discovery.relabel` | `targets`, bir nechta `rule` bloki | label'lari o'zgartirilgan target'lar va `rules` export'i |
| `loki.source.docker` | `host`, `targets`, `forward_to`, ixtiyoriy `relabel_rules` | Docker API orqali konteyner log'larini o'qiydi |
| `loki.process` | `forward_to`, bir nechta `stage.*` bloki | qatorlarni qayta ishlaydi va `receiver` export qiladi |
| `loki.write` | `endpoint { url = ... }` | Loki'ga yuboradi |

Ishga tushirish: `alloy run /etc/alloy/config.alloy --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data`. Default holatda UI faqat `127.0.0.1` da tinglaydi, ya'ni konteyner ichidan tashqariga chiqmaydi; shuning uchun `listen-addr` beriladi, host'da esa port baribir `127.0.0.1` ga publish qilinadi. `--storage.path` da Alloy har fayl yoki konteynerdan qayergacha o'qiganini saqlaydi; volume bo'lsa qayta ishga tushganda log'lar takrorlanmaydi.

### Relabel: `__meta_docker_*` dan foydali label'ga

`discovery.docker` har konteyner uchun ko'p meta label beradi, masalan:

- `__meta_docker_container_name`: konteyner nomi, Docker API'dagi kabi boshida `/` bilan (`/stack-mailer-1`).
- `__meta_docker_container_label_com_docker_compose_service`: Compose servis nomi (`mailer`). Konteynerdagi har Docker label shu shaklda keladi: nuqta va tire `_` ga almashadi.
- `__meta_docker_container_label_com_docker_compose_project`: Compose loyiha nomi.

`__` bilan boshlanadigan label'lar Loki'ga yuborilmaydi, ular faqat relabel bosqichida ishlatiladi. Relabel qoidasi Prometheus'dagi `relabel_configs` bilan bir xil mantiq (1-dars): manba label'larni oladi, regex bilan solishtiradi, natijani nishon label'ga yozadi. Misol, loyiha nomini `project` label'iga:

```alloy
discovery.relabel "compose" {
  targets = discovery.docker.containers.targets
  rule {
    source_labels = ["__meta_docker_container_label_com_docker_compose_project"]
    target_label  = "project"
  }
}
```

`action` yozilmasa default `replace`, `regex` yozilmasa `(.*)` va `replacement` `$1`: qiymat to'liq ko'chiriladi. Boshqa action'lar: `keep` va `drop` (target'ni qoldirish yoki tashlash), `labelmap` (nomi regex'ga mos label'larni ko'paytirish). `loki.source.docker` ga bu qoidalar `relabel_rules = discovery.relabel.compose.rules` orqali beriladi.

### `loki.process`: qatorni qayta ishlash

`loki.process` ichida stage'lar yuqoridan pastga bajariladi va o'zaro **extracted map** (qatordan ajratilgan vaqtinchalik qiymatlar xaritasi) orqali ma'lumot almashadi:

| Stage | Vazifasi |
|-------|----------|
| `stage.json` | qatorni JSON deb o'qib, `expressions` dagi maydonlarni extracted map'ga oladi |
| `stage.logfmt`, `stage.regex` | xuddi shu, boshqa formatlar uchun |
| `stage.labels` | extracted map'dagi qiymatni label qiladi |
| `stage.structured_metadata` | qiymatni structured metadata qiladi (3-bo'lim) |
| `stage.timestamp` | yozuv vaqtini qatordagi maydondan oladi |
| `stage.drop` | shartga mos qatorni tashlaydi (`source`, `expression`, `value`) |
| `stage.match` | `selector` ga mos qatorlar uchungina ichki stage'larni bajaradi yoki ularni tashlaydi |
| `stage.multiline` | bir necha qatorli yozuvni (stack trace) bitta yozuvga birlashtiradi |

Misol, `mailer` ning `template` maydonini (qiymatlari bir nechta, cheklangan) label qilish:

```alloy
loki.process "mailer" {
  forward_to = [loki.write.local.receiver]
  stage.json {
    expressions = { template = "template" }
  }
  stage.labels {
    values = { template = "" }
  }
}
```

`expressions` da kalit extracted map'dagi nom, qiymat JSON ichidagi yo'l. `stage.labels` da bo'sh qiymat "extracted map'da shu nomli kalitni ol" degani. JSON bo'lmagan qatorda `stage.json` xato beradi, qator esa o'zgarishsiz o'tib ketadi: log yo'qolmaydi, faqat label qo'shilmaydi.

### Misol: Alloy UI va formatlash

`http://localhost:12345` da Alloy UI komponentlar ro'yxatini va grafini ko'rsatadi. Har komponent yonida holat: `healthy` yoki `unhealthy` (masalan `loki.write` Loki'ga ulana olmasa). Komponentni bossangiz uning argumentlari, export'lari va oxirgi xatosi chiqadi: log kelmayotgan bo'lsa birinchi qaraladigan joy. Formatni tekshirish:

```
$ docker compose exec alloy alloy fmt /etc/alloy/config.alloy
local.file_match "mailer" {
	path_targets = [{"__path__" = "/var/log/mailer/*.log", "service" = "mailer"}]
}
...
```

- `alloy fmt` faylni o'zgartirmaydi, formatlangan ko'rinishini stdout'ga chiqaradi (`-w` bilan faylga yozadi). Chiqish kelsa sintaksis to'g'ri.
- Sintaksis xatosida chiqish o'rniga fayl nomi, qator va ustun ko'rsatilgan xato keladi; xuddi shu config bilan `alloy run` ishga tushmaydi va konteyner log'ida o'sha xato turadi.

### Real ishda qachon kerak

- Yangi servis qo'shilganda collector config'i o'zgarmasligi kerak: discovery uni o'zi topadi, relabel nomini beradi. Har servis uchun alohida qoida yozish kerak bo'lsa, config yomon qurilgan.
- "Log Grafana'da yo'q" muammosida: Alloy UI'da `loki.source.docker` konteynerni ko'ryaptimi, `loki.write` sog'lommi.
- Kubernetes'da xuddi shu Alloy `discovery.kubernetes` bilan DaemonSet bo'lib ishlaydi.

### Nima uchun shunday

Komponent grafi bitta collector'ga ko'p manba va ko'p signalni ulash imkonini beradi, va har bo'g'inning holatini alohida ko'rish mumkin. Promtail faqat log uchun edi; metrika uchun alohida agent, trace uchun yana boshqasi kerak bo'lardi. Alloy ularni bitta jarayonga, bitta config tiliga birlashtirdi va OpenTelemetry Collector komponentlarini ham ichiga oldi (7-dars). Muqobillar: Fluent Bit, Vector, OpenTelemetry Collector; tushunchalar (manba, qayta ishlash, chiqish) hammasida bir xil.

## 5. LogQL: selector, filter va parser

### Tuzilishi

LogQL so'rovi doim **stream selector** dan boshlanadi, keyin `|` bilan **pipeline** (qatorlar ketma-ket o'tadigan bosqichlar) keladi:

```
{service="mailer"} |= "retry" != "healthz" | json | took_ms > 500 | line_format "{{.template}} {{.err}}"
```

| Bosqich | Sintaksis | Vazifasi |
|---------|-----------|----------|
| Stream selector | `{service="mailer", level=~"error\|warn"}` | majburiy, indeks orqali stream va chunk tanlaydi. Operatorlar: `=`, `!=`, `=~`, `!~` |
| Line filter | `\|=`, `!=`, `\|~`, `!~` | xom matn bo'yicha (regex RE2 sintaksisida), eng arzon filtr |
| Parser | `\| json`, `\| logfmt`, `\| pattern`, `\| regexp` | qatordan maydon ajratib, vaqtinchalik label qiladi |
| Label filter | `\| took_ms > 500`, `\| level="warn"` | ajratilgan maydon bo'yicha; son, davomiylik (`200ms`) va matn bilan solishtiradi |
| Format | `\| line_format`, `\| label_format`, `\| drop`, `\| keep` | chiqishni o'zgartiradi |

Selector'da kamida bitta matcher bo'sh qiymatga mos kelmasligi kerak: `{service=~".*"}` rad etiladi, `{service=~".+"}` qabul qilinadi.

### Mexanizm: tartib nima uchun muhim

Har bosqich oldingisidan qolgan qatorlarni oladi. Line filter matnda pastki satr qidiradi, qatorni parse qilmaydi; parser esa har qatorni JSON sifatida o'qiydi, bu ancha qimmat. Shuning uchun tartib: avval imkon qadar tor selector, keyin line filter (parser'dan **oldin**, u qatorlarning ko'pini arzon yo'l bilan tashlaydi), keyin parser va label filter. Masalan `took_ms > 500` ni topish uchun avval `|= "took_ms"` yoki `|= "retry"` bilan toraytirish mumkin. Natija bir xil, qayta ishlangan bayt va vaqt kamayadi. Grafana Explore'da buni Query inspector'ning Stats yorlig'ida ko'rasiz: qayta ishlangan baytlar, qatorlar va bajarilish vaqti.

`| json` argumentsiz barcha maydonlarni ajratadi, ichma-ich obyektlar `_` bilan tekislanadi (`{"http":{"status":500}}` dan `http_status`). Parse qilib bo'lmagan qator yo'qolmaydi, unga `__error__` label'i (masalan `JSONParserErr`) qo'shiladi. Label filter'dagi solishtirish uni odatda chiqarib tashlaydi, lekin ishonch uchun `| __error__=""` aniq yoziladi.

### Misol: filter va parser

Grafana Explore'da (Loki data source) so'rov:

```
{service="mailer"} |= "retry" | json | attempt >= 2 | line_format "{{.template}} attempt={{.attempt}} {{.err}}"
```

Natija (Explore'dagi Logs ko'rinishi, eng yangisi tepada):

```
2026-10-05 10:15:03.120  welcome attempt=2 smtp timeout
2026-10-05 10:12:47.981  reset_password attempt=3 smtp timeout
```

- Chap ustun yozuv vaqti (Grafana sizning brauzer vaqt zonangizda ko'rsatadi).
- Qolgan qism `line_format` natijasi: Go template sintaksisi, `{{.nom}}` ajratilgan maydon yoki label qiymati. Asl JSON qator ko'rinmaydi, lekin qatorni ochsangiz barcha label'lar va ajratilgan maydonlar ro'yxati chiqadi.
- `attempt=1` bo'lgan retry'lar `attempt >= 2` filtrida tushib qoldi: `json` dan keyin `attempt` son sifatida solishtirildi.

Xuddi shu so'rov API orqali: `curl -sG localhost:3100/loki/api/v1/query_range --data-urlencode 'query=<so'rov>' --data-urlencode 'since=1h' --data-urlencode 'limit=20'`. Javobda `resultType` `streams` bo'ladi, har stream uchun label'lar va `[vaqt_nanosekund, qator]` juftliklari.

### JSON bo'lmagan qatorlar: `logfmt` va `pattern`

Grafana, Loki va Prometheus o'z log'larini `logfmt` da yozadi (1-bo'lim), ular uchun `| logfmt` yetarli. Erkin formatdagi qator uchun `pattern` parser: shablonda `<nom>` maydonni oladi, `<_>` o'tkazib yuboradi, qolgan matn so'zma-so'z mos kelishi kerak. Masalan `2026-10-05 10:15:03 WARN mailer smtp retry` ko'rinishidagi qator uchun:

```
{service="legacy-mailer"} | pattern "<_> <_> <lvl> <svc> <msg>" | lvl="WARN"
```

Shablonga mos kelmagan qatorda maydonlar ajratilmaydi va `lvl="WARN"` filtri ularni tashlaydi. Regex kerak bo'lsa `| regexp` bor, lekin u sekinroq va o'qish qiyin.

### Real ishda qachon kerak

- Incident'da: `request_id` bo'yicha bitta so'rov tarixi, `|=` bilan xato matni bo'yicha qidiruv, `line_format` bilan faqat kerakli maydonlar.
- Dashboard'dagi Logs paneli (observability 2-dars) shu so'rovlar bilan ishlaydi; sekin so'rov dashboard'ni ham sekinlashtiradi.

### Nima uchun shunday

LogQL ataylab PromQL'ga o'xshatilgan: selector bir xil sintaksisda, shuning uchun Grafana bir xil label'lar bilan metrikadan log'ga o'ta oladi. Pipeline g'oyasi Unix'dagi `grep | awk | sed` zanjiridan (linux 7-dars): har bosqich oddiy, birlashib kuchli bo'ladi. Parse'ni yozishda emas, o'qishda qilish (schema-on-read) format o'zgarganda eski ma'lumotni qayta indekslamaslik imkonini beradi; narxi har so'rovda qayta parse.

## 6. LogQL metric query'lar

### Log'dan raqam

Metric query log qatorlarini sanaydi yoki ulardagi sonni yig'adi va Prometheus'dagi kabi vector qaytaradi. Ikki tur bor:

- **Log range aggregation**: qatorlarning o'zini sanaydi. `count_over_time(... [5m])` oraliqdagi qatorlar soni, `rate(... [5m])` sekundiga qatorlar, `bytes_over_time` va `bytes_rate` qatorlar hajmi.
- **Unwrapped range aggregation**: `| unwrap <maydon>` bilan qatordagi sonni oladi. `sum_over_time`, `avg_over_time`, `max_over_time`, `quantile_over_time(0.95, ...)`. Maydon son bo'lmasa qator `__error__` oladi; davomiylik matni uchun `unwrap duration(maydon)`.

Ustiga PromQL'dagi kabi `sum by (...)`, `topk`, arifmetika qo'yiladi. Misol, `mailer` uchun template bo'yicha p95 yuborish vaqti:

```
quantile_over_time(0.95, {service="mailer"} | json | unwrap took_ms [5m]) by (template)
```

### Misol: API orqali instant query

```
$ curl -sG localhost:3100/loki/api/v1/query \
    --data-urlencode 'query=sum by (level) (count_over_time({service="mailer"} | json [5m]))' \
    | python3 -m json.tool
{
    "status": "success",
    "data": {
        "resultType": "vector",
        "result": [
            { "metric": { "level": "info" }, "value": [ 1759659600, "412" ] },
            { "metric": { "level": "warn" }, "value": [ 1759659600, "23" ] },
            { "metric": { "level": "error" }, "value": [ 1759659600, "4" ] }
        ],
        "stats": { ... }
    }
}
```

(Qatorlar qisqartirilgan.)

- `resultType: vector`: har guruh uchun bitta son, oxirgi vaqt nuqtasida. `query_range` da esa `matrix`, ya'ni grafik uchun nuqtalar qatori.
- `metric`: guruh label'lari. `level` bu yerda stream label'i emas, `| json` ajratgan maydon; `sum by` uni ham guruhlay oladi.
- `value`: `[unix_vaqt, "son"]`, son matn ko'rinishida (Prometheus API bilan bir xil).
- `stats`: so'rov qancha bayt va qatorni o'qigani; 5-bo'limdagi solishtirish shu yerdan ham olinadi.

### Dashboard va alert

Metric query Grafana'da oddiy Time series panel bo'ladi, Logs panel esa xom qatorlarni ko'rsatadi; ikkalasini bitta dashboard'ga qo'yib, grafikdagi cho'qqidan shu vaqt oralig'idagi log'larga o'tiladi (2-dars, dashboard variable'lari va vaqt oralig'i). Alert ikki yo'l bilan: Grafana Alerting'da Loki so'rovi asosida qoida (3-darsdagi contact point'lar bilan), yoki Loki ruler'ida Prometheus formatidagi qoida fayli.

### Real ishda qachon kerak

- Ilova metrika bermaydigan joyda (uchinchi tomon servis, eski tizim) log'dan xato tezligini olish.
- Aniq xato matni bo'yicha alert: "`certificate expired` qatori paydo bo'ldi" kabi holatni metrika bilan ifodalash qiyin.
- Har doim ko'rinib turadigan raqam (so'rov tezligi, latency) uchun esa haqiqiy metrika (1-dars) arzonroq va aniqroq.

### Nima uchun shunday

Prometheus metrikasi yozish paytida bir marta hisoblanadi va kichik son bo'lib saqlanadi. Log'dan metrika har so'rovda qatorlarni qayta o'qiydi: dashboard har 30 soniyada yangilansa, gigabaytlar qayta skaner qilinadi. LogQL metric query'lari "metrika yo'q edi, lekin kerak bo'ldi" holatini yopadi; doimiy ehtiyoj paydo bo'lsa yo ilovaga metrika qo'shiladi, yo Loki ruler'ida recording rule yoziladi (natijani Prometheus'ga yozadi).

## 7. Retention, hajm va narx

### Log eng qimmat signal

Log hajmi trafikka proporsional: har so'rov bir nechta qator, har qator yuzlab bayt. Metrika esa trafik oshsa ham bir xil series soni bilan qoladi. Shuning uchun log tizimining narxi asosan uchta narsaga bog'liq: qancha yoziladi, qancha saqlanadi, qancha keng so'raladi.

Hajmni kamaytirish qoidalari:

- `debug` production'da o'chiq (1-bo'lim).
- Shovqinli, foydasiz qatorlar (health check, metrics scrape so'rovlari) collector'da `stage.drop` bilan tashlanadi: ular hech qachon yozilmaydi va pul turmaydi.
- Retention muhit va log turiga qarab: masalan ilova log'lari 14–30 kun, audit log'lari qonun yoki kompaniya talabiga ko'ra uzoqroq, debug log'lari bir kun.

### Mexanizm: Loki'da retention

Loki'da retention **default o'chiq**: `retention_period` 0, ya'ni log'lar abadiy turadi va disk to'lguncha o'sadi. Uni compactor bajaradi: indeksdan muddati o'tgan chunk'larga havolalarni o'chiradi, keyin chunk'larning o'zini. Kalitlar (qiymatlar misol uchun):

```yaml
compactor:
  retention_enabled: true
  delete_request_store: filesystem
limits_config:
  retention_period: 720h            # 30 days for everything
  retention_stream:
    - selector: '{service="loadgen"}'
      priority: 1
      period: 48h
```

- `retention_enabled`: compactor retention'ni bajaradimi. Bu bo'lmasa `retention_period` e'tiborga olinmaydi.
- `delete_request_store`: retention yoqilganda compactor bu kalitni talab qiladi, aks holda Loki ishga tushmaydi. Nima uchun, 17-vazifada hujjatdan topasiz.
- `retention_period`: tenant uchun umumiy muddat. Soat birligida yoziladi.
- `retention_stream`: selector'ga mos stream'lar uchun alohida muddat; bir nechta mos kelsa `priority` kattasi yutadi.

O'chirish darhol emas: compactor davriy ishlaydi va o'chirishni biroz kechiktirib bajaradi, shuning uchun muddati o'tgan log bir necha soat ko'rinib turishi normal.

### Misol: kim qancha yozyapti

```
sum by (service) (bytes_over_time({service=~".+"}[1h]))
```

Grafana Explore'da Table ko'rinishida:

```
service      Value
loadgen      48.2 MB
mailer       3.10 MB
grafana      1.05 MB
loki         0.62 MB
```

- `{service=~".+"}`: `service` label'i bor hamma stream. Bu keng selector, uni faqat qisqa oraliqda ishlating.
- `bytes_over_time`: oxirgi bir soatda shu servis yozgan qatorlar hajmi (siqilmagan).
- Birinchi qatorda shovqin manbai darhol ko'rinadi. Bu misolda `loadgen` har so'rovni log qilyapti, va uni tashlash yoki qisqa retention berish birinchi tejash qadami.

### Real ishda qachon kerak

- Yangi log tizimi ishga tushganda birinchi kun: retention yoqiladi, aks holda bir necha oydan keyin disk to'ladi va log tizimi aynan incident paytida yozishni to'xtatadi.
- Oy oxirida hisob kelganda: qaysi servis eng ko'p yozyapti, uning qatorlari kerakmi.
- Xavfsizlik va huquqiy talab: shaxsiy ma'lumotli log'lar belgilangan muddatdan uzoq saqlanmasligi kerak.

### Nima uchun shunday

Loki retention'ni default o'chiq qoldiradi, chunki ma'lumotni o'chirish qaytarib bo'lmaydigan amal: noto'g'ri default bilan log yo'qotishdan ko'ra, operator ongli ravishda yoqqani xavfsizroq. Narxi: sozlanmasa disk to'ladi. Elasticsearch'da xuddi shu ishni ILM (8-bo'lim) qiladi; bulutdagi boshqariladigan log servislarida esa retention odatda majburiy parametr va to'g'ridan-to'g'ri hisobga ta'sir qiladi.

## 8. Elasticsearch: inverted index va mapping

### Bu nima

Elasticsearch bu JSON hujjatlarni saqlaydigan va ular bo'yicha to'liq matnli qidiruv qiladigan tizim, ichida Apache Lucene kutubxonasi ishlaydi. Log uchun har qator bitta **hujjat** (document). Hujjatlar **index** ga yoziladi (ma'lumotlar bazasidagi jadvalga yaqin tushuncha), API oddiy HTTP va JSON: `PUT`, `GET`, `POST _search`.

### Mexanizm: inverted index

Elasticsearch hujjatni yozishda analiz qiladi: `text` turidagi maydonlar **analyzer** orqali so'zlarga (token'larga) bo'linadi, kichik harfga o'tkaziladi, keyin har token uchun "qaysi hujjatlarda bor" ro'yxati yoziladi. Bu **inverted index**, kitob oxiridagi ko'rsatkich kabi: "timeout: 12, 45, 301-sahifalar". Qidiruv hujjatlarni o'qimaydi, token bo'yicha tayyor ro'yxatni oladi, shuning uchun ixtiyoriy so'z bo'yicha terabaytlar ichida ham tez. Narxi: indeks xom ma'lumotga yaqin joy oladi, har yozuvda analiz va indekslash CPU va RAM talab qiladi.

### Misol: analyzer token'lari

```
$ curl -s -X POST localhost:9200/_analyze -H 'Content-Type: application/json' \
    -d '{"analyzer":"standard","text":"SMTP timeout after 812ms"}' | python3 -m json.tool
{
    "tokens": [
        { "token": "smtp",    "start_offset": 0,  "end_offset": 4,  "type": "<ALPHANUM>", "position": 0 },
        { "token": "timeout", "start_offset": 5,  "end_offset": 12, "type": "<ALPHANUM>", "position": 1 },
        { "token": "after",   "start_offset": 13, "end_offset": 18, "type": "<ALPHANUM>", "position": 2 },
        { "token": "812ms",   "start_offset": 19, "end_offset": 24, "type": "<ALPHANUM>", "position": 3 }
    ]
}
```

- `token`: inverted index'ga kiradigan so'z. `SMTP` kichik harfga o'tdi: `smtp` deb qidirsangiz ham, `SMTP` deb qidirsangiz ham topiladi, chunki so'rov ham shu analyzer'dan o'tadi.
- `start_offset`, `end_offset`: so'zning asl matndagi o'rni (natijada mos joyni ajratib ko'rsatish uchun).
- `position`: so'zlar tartibi; "smtp timeout" kabi ibora qidiruvi shu bilan ishlaydi.
- `812ms` bitta token: `812` deb qidirsangiz topilmaydi. Analyzer qanday bo'lishini bilish shuning uchun muhim.

### Mapping

**Mapping** bu index'dagi maydonlar va ularning turlari ro'yxati, ma'lumotlar bazasidagi sxema kabi:

- `text`: analiz qilinadi, to'liq matnli qidiruv uchun (`match` so'rovi). Saralash va guruhlash uchun yaramaydi.
- `keyword`: analiz qilinmaydi, butun qiymat bitta token. Aniq moslik (`term` so'rovi), filtr va agregatsiya uchun.
- `date`, son turlari (`long`, `integer`, `float`), `boolean`, `ip`.

**Dynamic mapping**: mapping berilmagan maydonni Elasticsearch birinchi ko'rgan qiymatiga qarab turlaydi. JSON son `long` yoki `float` bo'ladi, sanaga o'xshagan matn `date`, boshqa matn `text` va uning ichida `.keyword` qo'shimcha maydoni (masalan `template` va `template.keyword`). Tur bir marta belgilangach, o'sha index'da o'zgarmaydi.

**Mapping explosion va tur ziddiyati.** Bir servis `took_ms` ni son, boshqasi `"812ms"` matn qilib yuborsa, birinchi kelgani turni belgilaydi va ikkinchisining hujjatlari rad etiladi. Erkin JSON kalitlari (masalan foydalanuvchi kiritgan obyekt log qilinsa) minglab maydon yaratadi: har maydon mapping'ga, klaster holatiga qo'shiladi, `index.mapping.total_fields.limit` (default 1000) oshganda yozish to'xtaydi.

### Shard, replica va klaster holati

Index **primary shard** larga bo'linadi, har biri alohida Lucene indeksi; shard'lar node'lar bo'yicha taqsimlanib parallel ishlaydi. Har primary'ning **replica** si (nusxasi) bo'lishi mumkin; Elasticsearch replica'ni hech qachon o'z primary'si bilan bir node'ga qo'ymaydi, aks holda node o'lganda ikkalasi birga yo'qoladi. Klaster holati rang bilan:

| Holat | Ma'nosi |
|-------|---------|
| `green` | barcha primary va replica shard'lar joylashtirilgan |
| `yellow` | barcha primary'lar bor, kamida bitta replica joylashtirilmagan |
| `red` | kamida bitta primary joylashtirilmagan, ma'lumotning bir qismi o'qilmaydi |

Log'lar uchun odatda vaqt bo'yicha index'lar yoki **data stream** (bitta nom ostida avtomatik almashadigan vaqt index'lari) ishlatiladi, hayot siklini **ILM** (Index Lifecycle Management) boshqaradi: hot (yozilmoqda, tez disk), warm, cold (kam so'raladi, arzon disk), delete.

### Real ishda qachon kerak

- Log'lar ustida "shu IP 30 kun ichida qaysi servislarda uchragan" kabi qidiruv kerak bo'lsa.
- Xavfsizlik tahlili (SIEM, xavfsizlik hodisalarini yig'ib tahlil qiladigan tizim) va murakkab agregatsiyalar.
- Log maydonlari ko'p va qidiruv ularning ixtiyoriysi bo'yicha bo'lishi mumkin bo'lsa.

### Nima uchun shunday

Elasticsearch log uchun emas, matnli qidiruv (sayt ichidagi qidiruv, hujjatlar) uchun yaratilgan va log'ga keyin moslashgan. Qidiruv tizimida har so'z bo'yicha tez topish asosiy talab, yozish narxi ikkinchi darajali. Log'da esa yozish hajmi katta, o'qish nisbatan kam: shuning uchun Elasticsearch log uchun kuchli, lekin qimmat. Shard va replica modeli gorizontal masshtab va node o'limidan himoya beradi; narxi operatsion murakkablik (heap, shard soni, mapping, ILM).

## 9. ELK ekotizimi va Loki bilan taqqos

### Stack

```
Filebeat (har host'da) -> [Logstash: parse, enrich] -> Elasticsearch -> Kibana
```

- **Filebeat**: yengil jo'natuvchi, Alloy'ning ELK dunyosidagi o'rni. `filestream` input fayllarni tail qiladi, `container` parser Docker'ning `json-file` o'ramini (2-bo'lim) ochadi, `ndjson` parser qatordagi JSON'ni maydonlarga ajratadi.
- **Logstash**: og'ir qayta ishlash (grok regex'lari, boyitish, marshrutlash) uchun ixtiyoriy bo'g'in. Kichik o'rnatishda kerak emas.
- **Kibana**: UI. Discover sahifasida log'lar, **KQL** (Kibana Query Language) so'rov tili: `template : "welcome" and took_ms > 500`. Kibana'da avval **data view** yaratiladi: qaysi index'lar (masalan `filebeat-*`) va qaysi vaqt maydoni.
- **OpenSearch**: Elasticsearch 7.10 dan ajralgan ochiq fork (Apache 2.0 litsenziyasi), API'si katta qismda mos, UI'si OpenSearch Dashboards. Litsenziya yoki AWS muhiti sabab tanlanadi, tushunchalar bir xil.

Filebeat o'rnida Fluent Bit, Vector yoki OpenTelemetry Collector ham ishlatiladi.

### Misol: Filebeat config'ni tekshirish

```
$ docker compose exec filebeat filebeat test config
Config OK
```

- `filebeat test config` config faylini o'qib sintaksis va kalitlarni tekshiradi, hech narsa yubormaydi. `Config OK` dan boshqa narsa chiqsa, xato qaysi kalitda ekani yoziladi.
- `filebeat test output` esa Elasticsearch'ga ulanishni tekshiradi; javobsiz bo'lsa birinchi qadam tarmoq va manzil.

### Taqqos

| | Loki | Elasticsearch |
|---|---|---|
| Nima indekslanadi | faqat label'lar | har maydon, har so'z |
| Yozish narxi | past | yuqori (analiz, indeks) |
| Saqlash | siqilgan chunk'lar, object storage | indeks va ma'lumot, tez disk |
| "Shu servisning oxirgi soatdagi xatolari" | tez | tez |
| "30 kun ichida shu IP hamma servislarda" | sekin (ko'p chunk skaner) | tez |
| Agregatsiya va analitika | LogQL metric query'lar, cheklangan | kuchli (aggregations) |
| Operatsion murakkablik | pastroq | yuqori: shard, heap, mapping, ILM |
| Ekotizim | Grafana, Prometheus label'lari bilan bir xil | Kibana, SIEM, to'liq matnli qidiruv |

Tanlov: Grafana va Prometheus stack'i bor, log asosan incident paytida servis va vaqt bo'yicha qidiriladi, byudjet muhim: Loki. Log'lar ustida murakkab qidiruv va analitika, xavfsizlik tahlili, log mahsulotning bir qismi bo'lsa: Elasticsearch yoki OpenSearch. Ko'p kompaniyalarda ikkalasi ham bor: operatsion log'lar Loki'da, xavfsizlik log'lari SIEM'da.

### Real ishda qachon kerak

- Yangi loyihada log tizimini tanlashda va mavjudini almashtirish taklifini baholashda: savol "qaysi biri yaxshiroq" emas, "bizning log'lar qanday so'raladi".
- Ishga kirganda: ko'p kompaniyalarda ELK yoki OpenSearch allaqachon bor, ikkala modelni tushunish o'tishni osonlashtiradi.

### Nima uchun shunday

ELK 2010-yillarda log markazlashtirishning standarti bo'lgan, chunki o'sha paytda boshqa yaxshi to'liq matnli qidiruv yo'q edi. Konteynerlar va mikroservislar log hajmini keskin oshirgach, hammasini indekslash qimmatlashdi va Loki kabi "kam indeks, arzon saqlash" modeli paydo bo'ldi. Ikkalasi turli savolga optimallashgan, shuning uchun biri ikkinchisini to'liq siqib chiqarmagan.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Log | dastur ish paytida yozadigan, vaqt belgili hodisa yozuvi |
| Structured log | har yozuv kalit-qiymatli obyekt (odatda bir qatorda bitta JSON) bo'lgan log |
| `logfmt` | `kalit=qiymat` juftliklaridan iborat qatorli log formati |
| Log level | yozuvning muhimlik darajasi (`debug`, `info`, `warn`, `error`) va chiqarish chegarasi |
| Correlation ID (`request_id`) | bitta so'rovning barcha log qatorlarini bog'laydigan identifikator |
| Redaction | secret va shaxsiy ma'lumotni log'ga yozishdan oldin maskalash |
| Logging driver | Docker'ning konteyner stdout/stderr'ini qayerga yozishini belgilaydigan moduli (default `json-file`) |
| Collector | log'larni o'qib, label qo'shib, saqlash tizimiga yuboradigan agent (Alloy, Filebeat) |
| Stream | Loki'da label'lari bir xil qatorlar ketma-ketligi |
| Chunk | bitta stream qatorlarining siqilgan bloki |
| Tenant | Loki'da ma'lumotlari ajratilgan mijoz; autentifikatsiyasiz rejimda `fake` |
| Distributor, ingester, querier, compactor | Loki komponentlari: qabul, xotirada yig'ish, o'qish, ixchamlash va retention |
| Structured metadata | qatorga biriktirilgan, stream'ni bo'lmaydigan kalit-qiymat |
| Promtail | Loki'ning eski collector'i, 2026-yil 2-martdan EOL |
| Grafana Alloy | komponentlar grafidan iborat universal collector |
| Relabel | target label'larini qoidalar bilan o'zgartirish |
| LogQL | Loki so'rov tili: selector, pipeline, metric query |
| Line filter | xom matn bo'yicha filtr (`\|=`, `!=`, `\|~`, `!~`) |
| Parser | qatordan maydon ajratadigan bosqich (`json`, `logfmt`, `pattern`, `regexp`) |
| `__error__` | parse qilib bo'lmagan qatorga qo'shiladigan label |
| `unwrap` | qatordagi maydonni son sifatida metric query'ga beradi |
| Retention | log'lar saqlanadigan muddat va undan keyin o'chirish |
| Inverted index | har so'z uchun uni o'z ichiga olgan hujjatlar ro'yxati |
| Analyzer | matnni token'larga bo'ladigan va normallashtiradigan qoida |
| Mapping | Elasticsearch index'idagi maydonlar va turlari |
| `text` / `keyword` | analiz qilinadigan matn / butun qiymat bitta token |
| Shard, replica | index bo'lagi va uning boshqa node'dagi nusxasi |
| ILM | Elasticsearch'da index hayot siklini (hot, warm, cold, delete) boshqarish |
| KQL | Kibana so'rov tili |
| OpenSearch | Elasticsearch 7.10 dan ajralgan ochiq fork |

## Tuzoqlar

- `request_id`, `user_id`, `trace_id` ni Loki label'i qilish: stream'lar portlaydi, Loki sekinlashadi yoki push'larni rad etadi.
- Selector'siz yoki juda keng selector bilan uzoq oraliqda qidirish (`{env="prod"} |= "x"` 30 kun): hamma chunk o'qiladi. Avval servis va vaqtni toraytiring.
- Line filter'ni parser'dan keyin qo'yish: natija bir xil, narx bir necha barobar.
- Log'da secret va shaxsiy ma'lumot: log tizimi eng ko'p odam kira oladigan joy. Maskalash ilovada, collector'da emas (unda kech).
- Matnga yopishtirilgan o'zgaruvchilar (`"user 42 failed"`): guruhlab ham, hisoblab ham bo'lmaydi.
- Ko'p qatorli stack trace: har qator alohida yozuv bo'lib ketadi. JSON ichida bitta maydon qiling yoki collector'da `stage.multiline`.
- pino'ning default son level'lari (`40`) va epoch vaqti: `level="warn"` so'rovi hech narsa topmaydi.
- Retention'siz Loki yoki ILM'siz Elasticsearch: disk to'ladi, log tizimi eng kerakli paytda yozishni to'xtatadi.
- Log'ni metrika o'rnida ishlatish: har dashboard yangilanishida gigabaytlar qayta o'qiladi. Doimiy raqam kerak bo'lsa metrika yozing.
- Elasticsearch'da xavfsizlikni o'chirib (`xpack.security.enabled=false`) portni tarmoqqa ochish: laboratoriya sozlamasi production'ga ko'chib qolmasin. Bu darsda port faqat `127.0.0.1` da.
- Elasticsearch'da bir maydonga turli servislar turli tur yuborishi: hujjatlar jim rad etiladi.
- Promtail yoki eski Docker Loki plugin asosidagi qo'llanmalardan nusxa olish: Promtail EOL, yangi narsa Alloy yoki OTel Collector bilan quriladi.
- Collector'siz, ilovadan to'g'ridan-to'g'ri log storage'ga yozish: storage o'lsa ilova bloklanadi yoki log yo'qoladi.
- macOS'da `/var/lib/docker/containers` ni host yo'li sifatida mount qilishga urinish: u yo'l Docker Desktop VM'i ichida, host'da yo'q.
- `docker system prune` yoki `docker volume prune -a` bilan "tozalash": boshqa loyihalarning volume'lari ham ketadi. Volume nomi bilan o'chiriladi.

## Manbalar

- https://grafana.com/docs/loki/latest/get-started/architecture/ – Loki arxitekturasi
- https://grafana.com/docs/loki/latest/get-started/labels/ – label'lar va cardinality (majburiy)
- https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/ – structured metadata
- https://grafana.com/docs/loki/latest/query/ – LogQL
- https://grafana.com/docs/loki/latest/query/log_queries/ – line filter, parser, format
- https://grafana.com/docs/loki/latest/query/metric_queries/ – metric query'lar, `unwrap`
- https://grafana.com/docs/loki/latest/reference/loki-http-api/ – Loki HTTP API (push, query, labels, series)
- https://grafana.com/docs/loki/latest/operations/storage/retention/ – retention
- https://grafana.com/docs/loki/latest/send-data/promtail/ – Promtail EOL e'loni
- https://grafana.com/docs/alloy/latest/ – Grafana Alloy
- https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.docker/ – Docker discovery
- https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/ – Docker log'larini yig'ish
- https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.relabel/ – relabeling
- https://grafana.com/docs/alloy/latest/reference/components/loki/loki.process/ – `loki.process` stage'lari
- https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic – Elasticsearch va Kibana Docker'da
- https://www.elastic.co/docs/reference/beats/filebeat/filebeat-input-filestream – Filebeat filestream input
- https://opensearch.org/docs/latest/ – OpenSearch
- https://12factor.net/logs – log'lar hodisalar oqimi sifatida
- https://getpino.io/ – pino (Node.js), redaction: https://getpino.io/#/docs/redaction
- https://pkg.go.dev/log/slog – slog (Go)

---

## Birga bajaramiz

Loki'ga Alloy'siz, to'g'ridan-to'g'ri HTTP API orqali bir necha qator yozamiz va ularni label, filter, parser va metric query bilan so'raymiz. Ssenariy vazifalardagidan boshqa: `api` va Alloy ishtirok etmaydi, `mailer-demo` degan to'qima servis nomidan `curl` bilan push qilamiz. Shunday qilib 3, 5 va 6-bo'limlardagi mexanizmni collector'siz, sof ko'rinishda ko'rasiz. Kerak bo'lgani faqat ishlayotgan `loki` servisi (4-vazifa); yurishni avval o'qing, 4-vazifadan keyin takrorlang. Buyruqlar host'da, ikkala mashinada bir xil (`date +%s` BSD va GNU'da ham Unix sekundlarini beradi).

1. Loki tayyormi:

```
$ curl -s localhost:3100/ready
ready
```

Ishga tushgandan keyingi birinchi soniyalarda boshqa matn (ingester hali tayyor emasligi haqida) chiqishi mumkin; bir oz kutib qaytaring.

2. Ikki stream'ga besh qator push qilamiz. Vaqt nanosekundda bo'lishi kerak, shuning uchun sekundlarga to'qqizta raqam qo'shamiz:

```
now=$(date +%s)
curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:3100/loki/api/v1/push \
  -H 'Content-Type: application/json' --data-binary @- <<JSON
{"streams":[
 {"stream":{"service":"mailer-demo","env":"lab"},"values":[
  ["${now}000000001","{\"level\":\"info\",\"msg\":\"email sent\",\"template\":\"welcome\",\"took_ms\":120}"],
  ["${now}000000002","{\"level\":\"warn\",\"msg\":\"email send retry\",\"template\":\"welcome\",\"attempt\":2,\"took_ms\":812}"],
  ["${now}000000003","{\"level\":\"info\",\"msg\":\"email sent\",\"template\":\"invoice\",\"took_ms\":95}"],
  ["${now}000000004","not a json line from a misconfigured module"]]},
 {"stream":{"service":"mailer-demo","env":"staging"},"values":[
  ["${now}000000005","{\"level\":\"error\",\"msg\":\"email send failed\",\"template\":\"welcome\",\"took_ms\":3000,\"err\":\"smtp timeout\"}"]]}
]}
JSON
```

Natija `204`: Loki qabul qildi, javob tanasi yo'q. Heredoc tirnoqsiz (`<<JSON`) bo'lgani uchun `${now}` o'rniga son qo'yiladi, `\"` esa o'zgarishsiz qoladi va JSON ichidagi qatorning tirnog'i bo'ladi. `400` kelsa javob tanasini ko'rish uchun `-o /dev/null` ni olib tashlang: odatda JSON sintaksisi yoki juda eski vaqt belgisi sabab.

3. Label'lar va stream'lar:

```
$ curl -sG localhost:3100/loki/api/v1/label/env/values
{"status":"success","data":["lab","staging"]}
$ curl -sG localhost:3100/loki/api/v1/series --data-urlencode 'match[]={service="mailer-demo"}'
{"status":"success","data":[{"env":"lab","service":"mailer-demo","service_name":"mailer-demo"},{"env":"staging","service":"mailer-demo","service_name":"mailer-demo"}]}
```

Ikki stream: `env` qiymati har xil. `service_name` ni Loki o'zi `service` dan qo'shdi (3-bo'lim). `level` label emas, u faqat qator ichida.

4. Line filter va parser. Grafana Explore'da (Loki data source, oxirgi 15 daqiqa):

```
{service="mailer-demo"} |= "welcome" | json | took_ms > 500
```

Ikki qator chiqadi: `warn` (812) va `error` (3000). `|= "welcome"` `invoice` qatorini va JSON bo'lmagan qatorni parse'dan oldin tashladi. Endi `|= "welcome"` ni olib tashlab `{service="mailer-demo"} | json` ni ishlating: JSON bo'lmagan qatorni oching, unda `__error__=JSONParserErr` label'i bor. `| json | __error__=""` qo'shsangiz u yo'qoladi.

5. `line_format` bilan o'qishli ko'rinish:

```
{service="mailer-demo"} | json | __error__="" | line_format "{{.level}} {{.template}} {{.took_ms}}ms {{.err}}"
```

Har qator `warn welcome 812ms` kabi ko'rinadi; `err` yo'q qatorlarda oxiri bo'sh qoladi.

6. Metric query, API orqali:

```
$ curl -sG localhost:3100/loki/api/v1/query \
    --data-urlencode 'query=sum by (env, level) (count_over_time({service="mailer-demo"} | json | __error__="" [15m]))' \
    | python3 -m json.tool
```

Natijada uchta element: `{env="lab", level="info"}` qiymati `"2"`, `{env="lab", level="warn"}` `"1"`, `{env="staging", level="error"}` `"1"`. JSON bo'lmagan qator `__error__=""` sabab hisobga kirmadi. 15 daqiqadan ko'p vaqt o'tgan bo'lsa natija bo'sh: oraliq `[15m]` so'rov vaqtidan orqaga sanaladi.

7. Tozalash. Loki'da bitta qatorni o'chirish oddiy amal emas (delete API compactor'da alohida yoqiladi), shuning uchun bu demo qatorlar retention muddati tugaguncha yoki `loki` volume'i o'chirilguncha qoladi. Ular kichik va boshqa label'larga ta'sir qilmaydi. Muhimi: Explore'dagi so'rovlarda `service="mailer-demo"` ni o'z servislaringiz bilan aralashtirmang.

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 2 | 3-bo'lim: push yo'li, stream label'lari bilan aniqlanadi |
| 3 | 3-bo'lim: labels va series API, `service_name` |
| 4 | 5-bo'lim: line filter parser'dan oldin, `__error__` |
| 5 | 5-bo'lim: `line_format` |
| 6 | 6-bo'lim: log range aggregation, parse qilingan maydon bo'yicha `sum by` |

---

## Vazifalar

Javoblar `observability/04-logging/README.md` da (`make new m=observability n=04 name=logging`), har vazifa uchun `## N. Title` ostida: config yoki so'rov, natijaning muhim qismi, izoh. Stack fayllari (`loki/`, `alloy/config.alloy`, ilova o'zgarishlari) `observability/stack/` da. Hamma buyruq host'da `observability/stack/` papkasidan, `docker compose` orqali; ikkala mashinada bir xil, farqli joylar vazifaning o'zida aytilgan. README'da qaysi mashinada bajarganingizni (`uname -s`) yozing. Log namunalarida token yoki shaxsiy ma'lumot qoldirmang.

### A. Structured logging

1. **Structured logs in the app.** `api` ilovasida log'larni JSON'ga o'tkazing (pino yoki slog): har so'rov uchun bitta `info` yozuv (`method`, `route`, `status`, `duration_ms`, `request_id`), 5xx uchun `error` yozuv (`err` maydoni bilan). `request_id` kiruvchi `X-Request-Id` header'idan olinsin yoki generatsiya qilinsin. `docker compose logs api` dan ikki qator namunani ko'rsating. Yo'nalish: 1-bo'lim, "Structured logging" va "Logger kutubxonasi nima qiladi".

2. **Log levels.** `LOG_LEVEL` env'ini qo'shing. `debug` da qo'shimcha yozuvlar chiqsin, `warn` da `info` lar chiqmasin. 400 javoblarni qaysi level'da yozdingiz va nima uchun? Health check so'rovlarini log'dan chiqarib tashlang yoki `debug` ga tushiring. Yo'nalish: 1-bo'lim, "Log level'lar".

3. **Secrets in logs.** Ilovaga `Authorization` header'li so'rov yuboring va butun header'larni log qiladigan qator yozing. Log'da token ko'rinishini ko'rsating. Keyin logger'ning redaction imkoniyati yoki o'z kodingiz bilan maskalang. Nima uchun buni collector'da emas, ilovada qilish kerak? Sinov uchun to'qima token ishlating, haqiqiysini emas. Yo'nalish: 1-bo'lim, "Log'ga nima yozilmaydi".

### B. Loki va Alloy

4. **Loki service.** `loki` servisini qo'shing (image ichidagi lokal config bilan, named volume). `/ready` va `/metrics` ni tekshiring. Loki'ni Prometheus scrape config'iga qo'shing. Grafana'ga Loki data source'ni provisioning orqali (`uid: loki`) qo'shing. Yo'nalish: 3-bo'lim, "Mexanizm: yozish va o'qish yo'li"; data source provisioning 2-darsda.

5. **Alloy pipeline.** `alloy/config.alloy` yozing: Docker konteynerlarini topish, log'larini o'qish, Loki'ga yuborish. `alloy` servisini docker socket faqat o'qish uchun mount qilingan holda qo'shing. Alloy UI'da komponentlar grafigini ko'ring va har komponent sog'lom ekanini ko'rsating. Grafana Explore'da biror log qatorini toping. Yo'nalish: 4-bo'lim, "Alloy config tili" va Docker komponentlari jadvali; Laboratoriyadagi socket haqidagi ogohlantirish.

6. **Relabel to useful labels.** Hozir log'larda qanday label'lar borligini ko'ring (`/loki/api/v1/labels` yoki Explore). `discovery.relabel` bilan `service` (compose servis nomi) va `container` label'larini qo'shing. `{service="api"}` ishlashini ko'rsating. Nima uchun container ID label sifatida yomon tanlov? Yo'nalish: 4-bo'lim, "Relabel"; 3-bo'lim, "Label'lar: eng muhim qaror".

7. **Level as a label.** `loki.process` bilan JSON'dan `level` ni ajratib label qiling. `{service="api", level="error"}` ishlasin. Loki'da stream'lar soni qanday o'zgardi (`/loki/api/v1/series` yoki `loki_ingester_memory_streams` metrikasi)? JSON bo'lmagan log'lar (Prometheus, Grafana) bilan nima bo'ldi? Yo'nalish: 4-bo'lim, "`loki.process`".

8. **Label cardinality bomb.** Ataylab `request_id` ni ham label qiling. 5 daqiqa yuklamadan keyin stream'lar soni, ingester xotirasi (`docker stats`) va Loki log'idagi ogohlantirish yoki rad etish xabarlarini yozing. Tuzating. Shu ma'lumotni label'siz qanday qidirasiz? Structured metadata bu yerda nima beradi? Yo'nalish: 3-bo'lim, "Label'lar: eng muhim qaror"; observability 1-darsdagi cardinality bomb bilan solishtiring.

9. **Drop noise.** Alloy'da `/healthz` va `/metrics` so'rovlari log'larini tashlab yuboring (`stage.drop` yoki match). Oldin va keyin `bytes_over_time` bilan `api` log hajmini solishtiring. Yo'nalish: 4-bo'lim, stage'lar jadvali; 7-bo'lim, "Misol: kim qancha yozyapti".

10. **Break the pipeline.** Loki'ni to'xtating, 2 daqiqa yuklama bering, qayta yoqing. Shu oraliqdagi log'lar Loki'da bormi? Alloy log'i va UI'da nima ko'rindi? Keyin `config.alloy` da sintaksis xatosi qiling va `alloy fmt` hamda konteyner log'i nima deyishini yozing. Oxirida config'ni tiklang. Yo'nalish: 2-bo'lim, "Mexanizm: besh bo'g'in"; 4-bo'lim, "Misol: Alloy UI va formatlash".

### C. LogQL

11. **Filters and parsers.** So'rovlar yozing: `api` ning barcha error log'lari; `timeout` so'zi bor, lekin `/healthz` bo'lmagan qatorlar; `| json` dan keyin `status >= 500` va `duration_ms > 200`; `line_format` bilan faqat `route` va `err` chiqadigan ko'rinish. Bitta `request_id` bo'yicha so'rovning barcha log'larini toping. Yo'nalish: 5-bo'lim.

12. **Filter order.** Bir xil natija beradigan ikki so'rov yozing: birida line filter parser'dan oldin, ikkinchisida faqat parser va label filter. Explore'dagi so'rov statistikasida (qayta ishlangan bayt va vaqt) farqni solishtiring. Oraliqni kattalashtirganda farq qanday o'zgaradi? Yo'nalish: 5-bo'lim, "Mexanizm: tartib nima uchun muhim".

13. **Pattern parser.** JSON bo'lmagan log manbai uchun (masalan Grafana yoki o'zingiz qo'shgan nginx access log) `pattern` yoki `logfmt` parser bilan maydon ajrating va status bo'yicha filtrlang. `__error__` label'i qachon paydo bo'lishini ko'rsating. Yo'nalish: 5-bo'lim, "JSON bo'lmagan qatorlar".

14. **Metric queries.** LogQL bilan hisoblang: level bo'yicha log qatorlari tezligi; 5xx log'lari ulushi (ikki `rate` nisbati); `unwrap duration_ms` bilan route bo'yicha p95. Natijalarni 1-darsdagi Prometheus metrikalari bilan solishtiring: mos keladimi, farq bo'lsa nima uchun? Yo'nalish: 6-bo'lim.

15. **Logs on the dashboard.** RED dashboard'ga ikkita panel qo'shing: level bo'yicha log tezligi (Time series) va `route` variable'iga bog'langan error log'lari (Logs panel). Grafikda xato cho'qqisini belgilab, shu vaqt oralig'idagi log'larga o'ting. Provisioning'dagi JSON'ni yangilang. Yo'nalish: 6-bo'lim, "Dashboard va alert"; variable'lar 2-darsda.

16. **Log-based alert.** Grafana Alerting'da Loki so'rovi asosida qoida yozing: `api` da ma'lum xato matni (`upstream timeout`) 5 daqiqada N martadan ko'p. 3-darsdagi contact point'ga yuboring. Buni metrika asosidagi alert'dan qachon afzal ko'rasiz? Yo'nalish: 6-bo'lim; Grafana Alerting 3-darsning 6-bo'limida.

17. **Retention.** Loki uchun o'z config faylingizni yozing (image'dagi lokal config asosida): compactor retention yoqilgan, umumiy muddat 7 kun, `level="debug"` stream'lari uchun 24 soat. Loki shu config bilan ko'tarilsin. Retention default holatda qanday ekanini va `delete_request_store` nima uchun talab qilinishini hujjatdan topib yozing. Yo'nalish: 7-bo'lim, "Mexanizm: Loki'da retention"; image'dagi config'ni `docker compose exec loki cat /etc/loki/local-config.yaml` bilan ko'ring.

### D. Elasticsearch va Kibana

18. **Single-node Elasticsearch.** `logs-es` profilida `elasticsearch` (single-node, heap cheklangan, konteynerga xotira limiti) va `kibana` servislarini qo'shing. Laboratoriya uchun xavfsizlikni o'chirishingiz mumkin, lekin buni izoh bilan belgilang. `_cluster/health` va `_cat/indices?v` chiqishini yozing. Yangi indeks yaratganingizda holat nima uchun `yellow` bo'lishini tushuntiring. macOS'da avval `docker info` dagi `Total Memory` ni tekshiring. Yo'nalish: 8-bo'lim, "Shard, replica va klaster holati"; Laboratoriya, "Xotira".

19. **Index and mapping.** `_bulk` API bilan 20–30 ta log hujjatini (1-vazifadagi format) indekslang. Mapping'ni ko'ring: `msg`, `route`, `status` qaysi turni oldi? `match` (`msg` bo'yicha) va `term` (`route` bo'yicha) so'rovlarini yozing va `text` bilan `keyword` farqini natijada ko'rsating. Keyin `status` ni matn qilib hujjat yuboring: xato nima deydi? Yo'nalish: 8-bo'lim, "Mexanizm: inverted index" va "Mapping".

20. **Ship and explore.** Filebeat konteynerini qo'shing: Docker konteyner log'larini o'qib Elasticsearch'ga yuborsin (rasmiy hujjatdagi `filestream` input va container parser). Kibana'da data view yarating, Discover'da KQL bilan `api` ning 5xx log'larini toping. Xuddi shu savolni LogQL'da yozib solishtiring. Tugagach profilni o'chiring va volume'larni tozalang. macOS eslatmasi: `/var/lib/docker/containers` Docker Desktop VM'i ichida, host'dan mount qilib bo'lmaydi. Uyda bajarsangiz, `docker compose logs --no-log-prefix api` chiqishini loyiha ichidagi git'ga kirmaydigan faylga yozing va Filebeat'ga shu faylni `ndjson` parser bilan o'qiting; README'da qaysi yo'lni tanlaganingizni yozing. Yo'nalish: 9-bo'lim; 2-bo'lim, "Ikki mashinada collector log'ni qanday oladi".

21. **Mini-project: logs in the stack.** Toza `docker compose up -d` dan keyin (ES profilisiz): `api` JSON log yozadi, Alloy uni `service`, `container`, `level` label'lari bilan Loki'ga yetkazadi, shovqin tashlangan, retention sozlangan, Grafana'da Loki data source va log panelli dashboard provisioning'dan keladi. Ssenariy: xato ulushini oshiring, 3-darsdagi alert'dan boshlab dashboard → log panel → bitta `request_id` ning to'liq tarixi yo'lini bosib o'ting va `README.md` ga yozing. Oxirida o'z so'zingiz bilan: shu loyihaga Loki yoki Elasticsearch, nima uchun? Loyiha ikkinchi mashinada ham `git pull`, `.env` va `docker compose up -d` bilan ko'tarilishini tekshiring. Yo'nalish: hamma bo'limlar; 9-bo'lim, "Taqqos".

### Topshirish

Tayyor bo'lgach:
1. 21 ta vazifaning javobi `observability/04-logging/README.md` da, `## N. Title` sarlavhalari ostida.
2. Stack fayllari `observability/stack/` da: yangilangan `compose.yaml`, `loki/` config'i, `alloy/config.alloy`, Grafana provisioning (Loki data source, dashboard), ilova o'zgarishlari.
3. `docker compose config -q` toza, Alloy UI'da barcha komponentlar sog'lom.
4. `make check` toza; log namunalarida token yoki shaxsiy ma'lumot yo'q, `.env` commit qilinmagan.
5. `logs-es` profili o'chirilgan, Elasticsearch volume'lari nomi bilan o'chirilgan (`docker volume ls` da yo'q).
6. Sinov uchun o'zgartirilgan narsalar qaytarilgan (cardinality bomb label'i, xato ulushi, buzilgan config), `docker compose down` qilingan.
7. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Structured log matnli logdan nimasi bilan farq qiladi va `msg` nima uchun o'zgarmas bo'lishi kerak?
- Ilova log'ni nima uchun faylga emas, stdout'ga yozadi? Qator stdout'dan Grafana'gacha qaysi bo'g'inlardan o'tadi?
- Loki nimani indekslaydi, nimani yo'q? Bu yozish va o'qish narxiga qanday ta'sir qiladi?
- Nima uchun `trace_id` Loki label'i bo'lmasligi kerak, lekin Elasticsearch'da oddiy maydon bo'la oladi?
- Alloy'da `__meta_docker_*` label'lari qayerdan keladi va nima uchun Loki'ga to'g'ridan-to'g'ri yetib bormaydi?
- LogQL so'rovida bosqichlar tartibi unumdorlikka qanday ta'sir qiladi?
- Inverted index nima va nima uchun u ham tez, ham qimmat?
- `text` va `keyword` maydon farqi nima?
- Single-node klasterda yangi index nima uchun `yellow`?
- Log'dan metrika chiqarish qachon to'g'ri, qachon haqiqiy metrika yozish kerak?
- Promtail'ning hozirgi holati qanday va o'rniga nima ishlatiladi?
- Retention sozlanmasa Loki va Elasticsearch'da nima bo'ladi?
- macOS'da collector konteyner log'larini qaysi yo'l bilan oladi va qaysi yo'l u yerda ishlamaydi?
