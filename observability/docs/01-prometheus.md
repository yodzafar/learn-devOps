# 1-dars: Prometheus bilan metrics

Maqsad: metrikalar asosidagi monitoringni mexanizm darajasida noldan tushunish: Prometheus target'lardan ma'lumotni qanday tortib oladi (pull), time series va label nima, to'rt metrika turi simda (`/metrics` matnida) qanday ko'rinadi, ilovaga metrika qanday qo'shiladi va PromQL bilan undan rate, error ratio va percentile qanday hisoblanadi. Bu dars modulning poydevori: 2-darsda shu so'rovlar Grafana panellariga, 3-darsda alert qoidalariga aylanadi, 5-darsda exemplar orqali trace'larga bog'lanadi. Linux modulining 8-darsida bitta serverda `top`, `free`, `df` bilan bergan savollaringizni bu yerda ko'p jarayon uchun va vaqt o'qi bo'ylab berasiz.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun 1–4 bo'limlar va A guruh; ikkinchi kun 5–6 bo'limlar va B guruh; uchinchi kun 7-bo'lim va C guruh; to'rtinchi va beshinchi kun 8-bo'lim (PromQL), "Birga bajaramiz" va D guruh; oltinchi kun 9-bo'lim, E guruh va README. Config sintaksisi oson, vaqtning ko'pi PromQL'ga ketadi: counter ustida nima uchun `rate()`, histogram bucket'lari va `histogram_quantile`, cardinality, `rate` oynasi va scrape interval nisbati, `by`/`without`.

Qanday o'qish kerak: har bo'limdagi so'rovni Prometheus UI'da o'zingiz bajaring va natijani darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi qiymatlar farq qiladi, bu normal; o'zgaruvchan joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Hammasi host'dagi Docker Compose'da ishlaydi (docker moduli, 4-dars), ikkala mashinada bir xil. `lab` VM bu modulda ishlatilmaydi: to'liq stack 3–4 GB RAM oladi, VM'ning 2G xotirasiga sig'maydi. Stack papkasi `observability/stack/`, uni shu darsda yaratasiz va keyingi darslarda kengaytirasiz. Host'ga hech narsa o'rnatilmaydi: `promtool` (config va rule tekshiruvchi CLI) Prometheus image'i ichida bor.

```
mkdir -p observability/stack/{app,prometheus}
cd observability/stack
docker compose up -d
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose down        # end of session, volumes stay
```

- **Portlar**: Prometheus `9090`, namuna ilova `8000`, node_exporter `9100`, cAdvisor `8080`. Har birini faqat loopback'ka e'lon qiling (`127.0.0.1:9090:9090` shaklida), aks holda UI ofis yoki uy tarmog'idagi hammaga ochiladi (Prometheus UI'da default autentifikatsiya yo'q).
- **Versiyalar**: darsda image versiyasi ataylab berilmagan. Release sahifasidan joriy barqaror versiyani oling va aniq tag yozing, `latest` emas: https://github.com/prometheus/prometheus/releases , https://github.com/prometheus/node_exporter/releases , https://github.com/google/cadvisor/releases . Dars Prometheus 3.x ga yozilgan, tekshirish: `docker compose exec prometheus prometheus --version`.
- **Arxitektura**: barcha image'lar multi-arch bo'lishi kerak (Zorin `amd64`, Mac `arm64`). Registry sahifasidagi "OS/Arch" ro'yxatidan yoki pull'dan keyin `docker image inspect --format '{{.Os}}/{{.Architecture}}' <image>` bilan tekshiring.
- **Xotira**: `docker info | grep -i 'total memory'` Docker'ga berilgan xotirani ko'rsatadi. macOS'da bu Docker Desktop VM'ining limiti, Mac'ning butun RAM'i emas. Bu dars stack'i (5 servis) 1 GB atrofida oladi; `docker stats --no-stream` bilan kuzating.
- **Tozalash**: mashg'ulot oxirida `docker compose down` (volume'lar qoladi). `docker system prune` va `docker volume prune -a` ishlatilmaydi: ikkala mashinada boshqa loyihalarning konteyner va volume'lari bor.
- **Secret**: bu darsda secret yo'q. Keyingi darslarda ular commit qilinmaydigan `.env` da turadi (`make secrets` commit qilingan `.env` ni rad etadi).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker Engine to'g'ridan-to'g'ri host kernel'ida. `node-exporter` host'ning `/proc`, `/sys` va `/` ni read-only ko'rib haqiqiy ish mashinasini tasvirlaydi, natija host'dagi `top`, `free -m`, `df -h` bilan solishtiriladi. `cadvisor` haqiqiy engine'ning cgroup'larini o'qiydi. `network_mode: host` haqiqiy host tarmog'ini beradi. |
| macOS (uy) | Konteynerlar Docker Desktop'ning yashirin Linux VM'ida. O'sha `node-exporter` Mac'ni emas, shu VM'ni tasvirlaydi: CPU soni va xotira Docker Desktop resurs sozlamalariga teng, `top`/`free`/`df` Mac'da boshqa narsani ko'rsatadi (yoki yo'q). `/:/host:ro,rslave` mount'i xato bersa `rslave` ni olib tashlab ko'ring. `network_mode: host` VM tarmog'ini anglatadi. `cadvisor` Docker Desktop'da mo'rt: konteyner label'lari (`name`, `image`) yoki ayrim metrikalar chiqmasligi mumkin. Docker Desktop ichki sozlamalarini o'zgartirmang: nima chiqqanini README'ga yozing, 6, 7, 8 va 17-vazifalarning host'ga bog'liq qismini ofisda bajaring. |

Ikkinchi mashinada tiklash: `compose.yaml`, `prometheus/` va `app/` git orqali keladi, `git pull` dan keyin `docker compose up -d --build` yetarli. Ma'lumot volume'i ko'chmaydi, shuning uchun metrikalar tarixi har mashinada alohida: uyda kechagi ofis grafigi bo'lmaydi. Vazifa "N daqiqa yuklama bering" desa, shu mashinada qaytadan bering.

---

## 1. Monitoring va metrika nima

### Qaysi savolga javob beradi

Linux 8-darsida `top`, `free`, `df` bilan "hozir, shu serverda nima bo'lyapti" deb so'ragansiz. Ularning ikki cheklovi bor: o'tmishni eslamaydi (kecha soat 03:00 da CPU qancha edi?) va bitta mashinani ko'rsatadi. **Metrika** (metric) bu muntazam oraliqda o'lchab boriladigan raqam: so'rovlar soni, band xotira baytlari, navbat uzunligi. **Monitoring** bu shu raqamlarni yig'ish, saqlash, so'rash va ular bo'yicha ogohlantirish.

Log (hodisa yozuvi, 4-dars) bilan farqi narxda va shaklda. Log har hodisa uchun bitta qator, hajmi trafikka proporsional: soniyasiga 1000 so'rov bo'lsa 1000 qator. Metrika esa agregat: o'sha 1000 so'rov bitta sonni 1000 ga oshiradi, saqlanadigan ma'lumot hajmi trafikka emas, kuzatilayotgan sonlar miqdoriga bog'liq. Shuning uchun metrika "nima buzildi, qancha va qachondan beri" ga arzon javob beradi, "aynan qaysi so'rovda nima bo'ldi" ga esa javob bermaydi (bu log va trace ishi).

### Brauzer tajribasidan nima ko'chadi

Frontend'da Web Vitals va RUM (real user monitoring: haqiqiy foydalanuvchilar brauzeridan yig'iladigan o'lchovlar), Sentry, DevTools Performance paneli bilan ishlagansiz. Ko'chadigan g'oyalar: taqsimotga qarash (LCP ning p75 i kabi percentile), o'rtachaning aldashi, vaqt bo'yicha trend. Server tomonida farq qiladigani:

| | Brauzer (RUM) | Server (Prometheus) |
|---|---|---|
| Kim yuboradi | har brauzer o'zi yuboradi (push) | Prometheus o'zi kelib oladi (pull) |
| Nima saqlanadi | ko'pincha har hodisa alohida | faqat agregat sonlar |
| O'lchov | sahifa yoki sessiya bo'yicha | jarayon bo'yicha, yuzlab jarayon |
| Asosiy xavf | sampling va tarmoq | cardinality (3-bo'lim) |

`console.time` bitta o'lchovni chop etadi va unutadi; metrika o'sha o'lchovni hisoblagichga qo'shadi va hisoblagich doim `/metrics` da turadi.

### Real ishda qachon kerak

- "Sayt sekinlashdi" degan xabarda: qachondan, hamma endpoint'mi yoki bittasi, deploy bilan mos keladimi.
- Sig'imni rejalashtirishda: disk shu tezlikda necha kunda to'ladi.
- Alert'da (3-dars): odam qarab turmaydi, qoida qaraydi.

### Nima uchun shunday

Hodisalarni emas, sonlarni saqlash ataylab qilingan cheklov: tafsilot yo'qoladi, evaziga saqlash arzon va so'rov tez. Muqobili har so'rovni hodisa sifatida yozib, agregatni so'rov paytida hisoblash (log va trace asosidagi tizimlar): moslashuvchan, lekin qimmat. Amalda ikkalasi birga ishlatiladi: metrika muammo borligini aytadi, log va trace sababini.

## 2. Pull modeli va Prometheus arxitekturasi

### Scrape sikli

**Target** bu Prometheus kuzatadigan bitta `host:port` manzil. **Scrape** bu Prometheus'ning target'ga yuboradigan bitta HTTP `GET /metrics` so'rovi (HTTP: network moduli, 4-dars). Prometheus har `scrape_interval` da (masalan 15 soniyada) har target'ga shunday so'rov yuboradi, javobdagi barcha qiymatlarni o'qiydi va ularga o'z soatidagi vaqt belgisini qo'yib saqlaydi. Ilova hech qayerga hech narsa yubormaydi, faqat joriy holatini ko'rsatib turadi.

```
every 15s:
  GET http://api:8000/metrics  ->  200 OK, text  ->  store samples with timestamp now
  GET http://node-exporter:9100/metrics  ->  ...
```

Har scrape natijasida Prometheus o'zi ham bir nechta qiymat yozadi. Eng muhimi `up`: scrape muvaffaqiyatli bo'lsa 1, bo'lmasa 0.

```
up{instance="localhost:9090", job="prometheus"}   1
up{instance="mailer:9200", job="mailer"}          0
```

Birinchi qator: `prometheus` nomli scrape config'dagi `localhost:9090` target'i javob berdi. Ikkinchi qator: `mailer` target'i javob bermadi (konteyner yo'q, port yopiq yoki timeout). `job` va `instance` label'larini target emas, Prometheus qo'shadi (3-bo'lim). Qolgan avtomatik qiymatlar: `scrape_duration_seconds` (scrape qancha davom etgani), `scrape_samples_scraped` (javobda nechta qiymat bor edi). UI'dagi Status → Target health sahifasi har target holati va oxirgi xato matnini ko'rsatadi.

### Pull va push

| | Pull (Prometheus) | Push (StatsD, OTLP) |
|---|---|---|
| Target ro'yxati | monitoring tizimida (service discovery) | har ilova qabul qiluvchi manzilini biladi |
| Target o'ldi | darhol ko'rinadi: `up == 0` | "jim qoldi" ni "o'ldi" dan ajratish qiyin |
| Qisqa umrli job | scrape'ga ulgurmaydi, Pushgateway kerak | tabiiy |
| Firewall/NAT ortida | Prometheus target'ga yeta olishi shart | ilova tashqariga chiqa olsa yetadi |

Prometheus 3.x OTLP orqali push qabul qilishni ham biladi (`--web.enable-otlp-receiver`), 7-darsda ishlatamiz.

### Arxitektura

Prometheus bitta binary, ichida: scrape, lokal TSDB (time series database: vaqt qatorlarini saqlashga moslashgan baza), PromQL engine (so'rov tili), qoidalarni hisoblash (rule evaluation) va web UI. Alert yuborish alohida komponent: Alertmanager (3-dars). Prometheus ataylab klastersiz: har instans mustaqil, HA (high availability, bittasi o'lsa ikkinchisi ishlashi) uchun ikkita bir xil instans parallel ishlatiladi. Uzoq muddatli saqlash va bir nechta Prometheus ustidan umumiy ko'rinish uchun `remote_write` orqali Thanos, Mimir yoki VictoriaMetrics ulanadi, bu moduldan tashqarida.

### Real ishda qachon kerak

- Yangi servis monitoringda ko'rinmasa, birinchi qaraladigan joy Target health: target ro'yxatda bormi, `up` nechaga teng, xato matni nima.
- "Servis o'ldi" alert'i deyarli doim `up == 0` ustiga quriladi.

### Nima uchun shunday

Pull modeli Google'ning ichki Borgmon tizimidan olingan (Prometheus 2012-yilda SoundCloud'da shu g'oya bilan boshlangan). Sababi: monitoring tizimi kimni kuzatishi kerakligini o'zi biladi, shuning uchun "kelishi kerak edi, kelmadi" holati aniq ko'rinadi; ilova esa sodda qoladi, unga monitoring manzili ham, qayta urinish mantiqi ham kerak emas, va `/metrics` ni brauzer yoki `curl` bilan ochib tekshirish mumkin. Narxi: Prometheus har target'ga tarmoq orqali yeta olishi shart va qisqa umrli jarayonlar noqulay.

## 3. Time series, label va cardinality

### Ma'lumot modeli

**Time series** (vaqt qatori) bu bitta o'lchovning vaqt bo'yicha qiymatlari ketma-ketligi. **Sample** bu shu qatordagi bitta nuqta: `(timestamp, value)`, timestamp millisekund aniqligida, value `float64`. **Label** bu seriyaga yopishtirilgan `kalit="qiymat"` juftligi. Series metrika nomi va label'lar to'plami bilan aniqlanadi:

```
emails_sent_total{provider="smtp", result="ok"}      1027
emails_sent_total{provider="smtp", result="error"}   12
emails_sent_total{provider="ses",  result="ok"}      344
```

Bu uchta alohida series: nom bir xil, label to'plami har xil. Birinchi qator: SMTP orqali muvaffaqiyatli yuborilgan xatlar soni jarayon boshlanganidan beri 1027 ta. Nom ham aslida label, uning kaliti `__name__`. Label'larning har bir noyob kombinatsiyasi alohida series va diskda, xotirada alohida joy egallaydi.

Scrape paytida Prometheus har seriyaga ikkita label qo'shadi: `job` (scrape config nomi, `job_name`) va `instance` (target manzili, `host:port`). Shu sabab bir xil kodli uchta replika uchta alohida seriya beradi va ularni so'rovda ajratish yoki qo'shish mumkin.

### Cardinality

**Cardinality** bu bitta metrika (yoki butun Prometheus) nechta series'dan iboratligi. U label qiymatlari sonlarining ko'paytmasi:

```
emails_sent_total: provider (3 values) x result (2 values)            = 6 series
... add label template (40 values)                                    = 240 series
... add label recipient (100000 addresses)                            = 24 000 000 series
```

Har series xotirada indeks yozuvi va ochiq chunk (sample'lar bloki) egallaydi, shuning uchun xotira sample'lar soniga emas, faol series soniga proporsional. `user_id`, `email`, to'liq URL (`/orders/8812`), `trace_id` kabi cheksiz qiymatli label har yangi qiymatda yangi series yaratadi, xotira tugaydi va kernel jarayonni o'ldiradi (OOM, out of memory). Qoida: label qiymati oldindan ma'lum, cheklangan to'plamdan bo'lsin (`route="/orders/:id"`, URL emas). "Qaysi foydalanuvchi" degan savolning joyi log va trace.

O'lchash: `count({__name__=~".+"})` jami series soni, `topk(10, count by (__name__) ({__name__=~".+"}))` eng katta o'nta metrika, UI'da Status → TSDB status, CLI'da `promtool tsdb analyze`.

### Real ishda qachon kerak

- Yangi metrika qo'shishdan oldin: "label'lar ko'paytmasi nechta series beradi?" deb hisoblash.
- Prometheus xotirasi to'satdan o'sganda: TSDB status sahifasida qaysi metrika va qaysi label aybdorligini topish.

### Nima uchun shunday

Label'lar Prometheus'gacha bo'lgan iyerarxik nomlar (`mail.smtp.ok.count`, Graphite uslubi) o'rniga kelgan: nomga yangi o'lcham qo'shish barcha so'rovlarni buzardi, label esa buzmaydi va istalgan o'lcham bo'yicha filtrlash, guruhlash imkonini beradi. Narxi aynan cardinality: har kombinatsiya uchun alohida series indekslanadi, shu indeks so'rovni tez qiladi va shu indeks xotirani yeydi.

## 4. Exposition format va metrika turlari

### Simda nima uzatiladi

**Exposition format** bu `/metrics` javobining matn formati. Har metrika oilasi oldidan ikki izoh qatori keladi:

```
# HELP emails_sent_total Total emails handed to a provider.
# TYPE emails_sent_total counter
emails_sent_total{provider="smtp",result="ok"} 1027
emails_sent_total{provider="smtp",result="error"} 12
```

`# HELP` odam uchun tavsif. `# TYPE` metrika turi. Keyingi har qator bitta sample: nom, jingalak qavsda label'lar, bo'sh joy, qiymat. Vaqt belgisi odatda yo'q, uni scrape paytida Prometheus qo'yadi. Nomlash qoidalari: `snake_case`, birlik nom oxirida va bazaviy birlikda (`_seconds`, `_bytes`, millisekund emas), counter `_total` bilan tugaydi, prefiks ilova yoki sohani bildiradi (`http_`, `node_`, `emails_`). OpenMetrics shu formatning standartlashgan davomi, exemplar'lar shu formatda uzatiladi (5-dars).

### To'rt tur

| Tur | Ma'nosi | Misol | So'rovda |
|-----|---------|-------|----------|
| Counter | faqat o'sadi, restart'da 0 ga tushadi | `emails_sent_total` | doim `rate()` yoki `increase()` |
| Gauge | joriy qiymat, o'sadi va kamayadi | `email_queue_length`, `node_memory_MemAvailable_bytes` | to'g'ridan-to'g'ri, `avg_over_time` |
| Histogram | kuzatuvlarni bucket'larga sanaydi | `email_send_duration_seconds` | `histogram_quantile()` |
| Summary | quantile'ni client o'zi hisoblaydi | `go_gc_duration_seconds` | to'g'ridan-to'g'ri, agregatsiya qilib bo'lmaydi |

**Counter.** Qiymatning o'zi ma'nosiz (jarayon qachon ishga tushganiga bog'liq), ma'no o'zgarish tezligida. Jarayon restart bo'lsa counter 0 dan boshlanadi; `rate()` qiymat kamayganini ko'rsa buni **counter reset** deb tushunadi va tuzatadi (8-bo'lim). Shuning uchun counter hech qachon qo'lda kamaytirilmaydi: "jami yuborilgan xatlar" counter, "hozir navbatda turgan xatlar" gauge.

**Gauge.** Termometr kabi: hozirgi qiymat. `rate()` unga qo'llanmaydi, chunki kamayishi reset emas, oddiy hol.

### Histogram ichidan

Histogram davomiylik yoki hajm kabi kuzatuvlarning taqsimotini saqlaydi. **Bucket** bu "shu chegaragacha bo'lgan kuzatuvlar soni" hisoblagichi. Bitta histogram simda uch xil series beradi:

```
# TYPE email_send_duration_seconds histogram
email_send_duration_seconds_bucket{le="0.1"} 240
email_send_duration_seconds_bucket{le="0.5"} 310
email_send_duration_seconds_bucket{le="2"} 318
email_send_duration_seconds_bucket{le="+Inf"} 320
email_send_duration_seconds_sum 61.3
email_send_duration_seconds_count 320
```

Qatorma-qator: `le` ("less than or equal") bucket'ning yuqori chegarasi. 240 ta yuborish 0.1 soniyadan tez bo'lgan. `le="0.5"` dagi 310 kumulyativ: unga 0.1 dan tezlari ham kiradi, demak 0.1 va 0.5 orasida 310 − 240 = 70 ta. 0.5 va 2 orasida 8 ta, 2 soniyadan sekin 320 − 318 = 2 ta. `+Inf` bucket hamma kuzatuvni sanaydi va `_count` ga teng. `_sum` barcha davomiyliklar yig'indisi: 61.3 / 320 ≈ 0.19 s o'rtacha. Har bucket alohida counter, shuning uchun histogram'ni replikalar bo'yicha qo'shib (`sum by (le)`), keyin percentile hisoblash mumkin. Narxi: har label kombinatsiyasi uchun bucket soni + 2 ta series.

Chegaralar kodda oldindan tanlanadi va keyin aniq qiymat tiklanmaydi: 0.1 va 0.5 orasidagi 70 ta kuzatuvning qayerda yotgani noma'lum. `histogram_quantile` ularni bucket ichida tekis tarqalgan deb faraz qiladi (8-bo'lim). Shuning uchun chegaralar kutilgan latency va SLO (service level objective: servis sifati bo'yicha maqsad, 3-dars) chegarasi atrofida zich qo'yiladi.

Native histogram (bucket'lar avtomatik, bitta series) Prometheus 3.8 dan barqaror, lekin scrape'da alohida yoqiladi (`scrape_native_histograms`). Bu darsda klassik histogram ishlatamiz, chunki ekotizimning katta qismi hali shunda.

### Summary va histogram

Summary quantile'ni ilova ichida hisoblab tayyor beradi:

```
go_gc_duration_seconds{quantile="0.5"} <value>
go_gc_duration_seconds{quantile="1"} <value>
go_gc_duration_seconds_sum <value>
go_gc_duration_seconds_count <value>
```

Uni replikalar bo'yicha o'rtacha qilish matematik jihatdan noto'g'ri: ikki serverning p99 lari o'rtachasi umumiy p99 emas (biri 10 ta, ikkinchisi 10 000 ta so'rov ko'rgan bo'lishi mumkin). Bir nechta replika bo'ladigan servisda histogram tanlang.

### Real ishda qachon kerak

- Servis metrika bermayapti deyilganda birinchi qadam: `curl` bilan `/metrics` ni ochib ko'zda o'qish.
- Yangi metrika uchun tur tanlash: sanaladigan hodisa counter, joriy holat gauge, davomiylik histogram.

### Nima uchun shunday

Format matnli, chunki uni odam o'qiy olishi va istalgan tilda bir necha qator kod bilan chiqarish mumkin bo'lishi kerak edi. Bucket'lar kumulyativ, chunki shunda istalgan bucket'ni tashlab yuborish (cardinality'ni kamaytirish) qolganlarini buzmaydi va har bucket oddiy counter bo'lib qoladi. Web Vitals'dagi "LCP p75" ham shunday taqsimotdan chiqadi, faqat u yerda xom hodisalar saqlanadi, bu yerda faqat bucket hisoblagichlari.

## 5. prometheus.yml, reload va saqlash

### Config tuzilishi

Quyidagi misol darsdagi stack emas, xayoliy `mailer` servisi uchun:

```yaml
global:
  scrape_interval: 15s        # how often to scrape (default 1m)
  evaluation_interval: 15s    # how often to evaluate rules (default 1m)
rule_files:
  - /etc/prometheus/rules/*.yml
scrape_configs:
  - job_name: mailer
    static_configs:
      - targets: ["mailer:9200"]
        labels:
          env: lab
```

- `global` barcha job'lar uchun default qiymatlar. Amalda `scrape_interval` 15s–60s.
- `scrape_configs` ro'yxatining har elementi bitta **job**: bir xil vazifali target'lar guruhi. `job_name` `job` label'iga, target manzili `instance` label'iga aylanadi, `labels` ostidagilar shu target'ning barcha seriyalariga qo'shiladi.
- `metrics_path` default `/metrics`, `scheme` default `http`.
- `static_configs` qo'lda yozilgan ro'yxat. Production'da **service discovery** ishlatiladi (target ro'yxatini Prometheus tashqi manbadan o'zi oladi): `kubernetes_sd_configs`, `docker_sd_configs`, `file_sd_configs`, `dns_sd_configs`.
- Compose ichida target manzili servis nomi (`mailer:9200`, Compose DNS: docker moduli, 3–4-darslar), `localhost` emas: `localhost` Prometheus konteynerining o'zi.

### Relabeling (tanishuv)

**Relabeling** bu label'larni qoidalar bilan qayta yozish yoki ular bo'yicha tashlab yuborish. Ikki bosqichi bor:

| Kalit | Qachon ishlaydi | Nimaga ta'sir qiladi |
|-------|-----------------|----------------------|
| `relabel_configs` | scrape'dan oldin | target'ning o'zi: label'lari, manzili, scrape qilinishi yoki yo'qligi |
| `metric_relabel_configs` | scrape'dan keyin, saqlashdan oldin | javobdagi har series: o'zgartirish yoki tashlash |

```yaml
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: "go_gc_.*"
        action: drop
```

Bu parcha: har seriyaning `__name__` label'i olinadi, `go_gc_` bilan boshlansa series saqlanmaydi. `regex` butun qiymatga to'liq mos kelishi kerak. Ikkinchi bosqich keraksiz yoki yuqori cardinality'li metrikalarni kesish quroli, lekin scrape baribir bo'ladi, target ularni baribir hisoblaydi.

### Tekshirish va qayta yuklash

`promtool check config` faylni sintaksis va mazmun bo'yicha tekshiradi. Config'ni ishlab turgan jarayonga qayta o'qitishning ikki yo'li: jarayonga `SIGHUP` signali (signallar: linux moduli, 9-dars), masalan `docker compose kill -s SIGHUP prometheus`, yoki `--web.enable-lifecycle` flag'i yoqilgan bo'lsa `POST /-/reload`. Yangi config xato bo'lsa Prometheus eskisi bilan ishlashda davom etadi va log'ga xato yozadi.

### Saqlash va retention

Ma'lumot lokal diskda (`/prometheus`). Yangi sample'lar avval **WAL** ga (write-ahead log: jarayon yiqilsa qayta tiklash uchun diskka ketma-ket yoziladigan jurnal) va xotiradagi head blokka tushadi, keyin 2 soatlik bloklar bo'lib diskka yoziladi. **Retention** bu ma'lumot qancha saqlanishi, default 15 kun. Flag'lar: `--storage.tsdb.retention.time=30d`, `--storage.tsdb.retention.size=10GB` (qaysi biri birinchi to'lsa). Disk hajmi taxmini: `retention soniyalari × soniyasiga yoziladigan sample'lar × 1–2 bayt`, bunda soniyasiga sample'lar = series soni / scrape interval.

Compose'da `command:` yozsangiz u image'ning default argumentlarini to'liq almashtiradi, shuning uchun `--config.file=/etc/prometheus/prometheus.yml` va `--storage.tsdb.path=/prometheus` ni ham qayta yozish kerak. Volume ulanmasa konteyner qayta yaratilganda tarix yo'qoladi.

### Real ishda qachon kerak

- Yangi servisni monitoringga qo'shish: bitta job yoki service discovery qoidasi.
- Prometheus diski to'lganda: retention, series soni va scrape interval orasidagi hisob.

### Nima uchun shunday

Prometheus ataylab faqat lokal diskka yozadi: tarmoqdagi saqlash tizimi buzilganda monitoring ham ko'r bo'lib qolmasligi kerak, aynan o'sha payt u eng kerak. Restart o'rniga reload, chunki restart'da xotiradagi head blok WAL'dan qayta o'qiladi (katta instansda daqiqalar) va shu vaqtda scrape bo'lmaydi, grafikda teshik qoladi.

## 6. Exporter'lar

### Exporter nima

**Exporter** bu Prometheus formatini bilmaydigan tizimning holatini o'qib, `/metrics` ko'rinishida beradigan alohida jarayon. Linux kernel, PostgreSQL yoki nginx o'zi `/metrics` bermaydi, ularning yonida exporter turadi. O'z kodingizda esa exporter kerak emas, kutubxona bilan to'g'ridan-to'g'ri instrumentatsiya qilinadi (7-bo'lim).

| Manba | Nima beradi | Asosiy metrikalar |
|-------|-------------|-------------------|
| node_exporter | mashina: CPU, xotira, disk, tarmoq, filesystem (`/proc` va `/sys` dan, linux 8-dars) | `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_avail_bytes`, `node_load1` |
| cAdvisor | har konteyner uchun cgroup statistikasi (cgroup: docker moduli, 1-dars) | `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` |
| ilova o'zi | biznes va HTTP metrikalari | siz yozasiz |

### node_exporter

U `/proc` va `/sys` fayllarini o'qib songa aylantiradi. Konteynerda ishlaganda o'z konteynerining emas, host'ning fayllarini ko'rishi uchun host fayl tizimi faqat o'qish uchun beriladi (`/:/host:ro,rslave` mount'i va `--path.rootfs=/host` flag'i). Tarmoq statistikasi to'liq bo'lishi uchun rasmiy tavsiya `network_mode: host` va `pid: host`; u holda Prometheus unga servis nomi bilan emas, host manzili bilan yetadi.

```
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 48211.37
node_cpu_seconds_total{cpu="0",mode="user"} 912.44
node_cpu_seconds_total{cpu="0",mode="system"} 301.02
node_cpu_seconds_total{cpu="0",mode="iowait"} 17.9
```

Bu `top` dagi foizlarning xom manbasi: har yadro (`cpu`) har rejimda (`mode`) boot'dan beri necha soniya o'tkazgani. Birinchi qator: 0-yadro 48211 soniya bo'sh turgan. Bular counter, demak foiz olish uchun `rate()` kerak: bir yadro bir soniyada barcha rejimlarda jami 1 soniya o'tkazadi, shuning uchun bitta rejimning `rate` i 0 va 1 orasidagi ulush. Boshqa misol, tarmoq tezligi bit/s da: `rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8`.

macOS'da shu metrikalar Docker Desktop VM'iniki (Laboratoriya jadvali).

### cAdvisor

cAdvisor (Container Advisor, Google) engine'dagi har konteynerning cgroup hisoblagichlarini o'qiydi va `name`, `image`, `id` label'lari bilan beradi. Image `ghcr.io/google/cadvisor` da (0.53 dan oldingi versiyalar `gcr.io/cadvisor/cadvisor` da edi), kerakli mount'lar ro'yxati README'da. U ko'p metrika beradi (har konteyner × o'nlab metrika × ichki label'lar), shu sabab relabeling bilan kesish odatiy. U `privileged` rejimda ishlaydi: laboratoriyada maqbul, production'da ongli qaror.

### Real ishda qachon kerak

- RED (9-bo'lim) "sekin" desa, sabab resursdami yoki koddami: node_exporter va cAdvisor shu savolga javob beradi.
- Tayyor tizim (baza, proxy, navbat) uchun avval rasmiy exporter qidiriladi: https://prometheus.io/docs/instrumenting/exporters/ .

### Nima uchun shunday

Exporter'lar alohida jarayon, chunki Prometheus hech qaysi tizimning ichki formatini bilishni istamaydi: bitta kirish formati, tarjima chetda. Muqobili agent modeli (bitta agent hammasini yig'ib push qiladi, masalan Telegraf yoki OpenTelemetry Collector, 7-dars): jarayonlar kamroq, lekin agent murakkabroq.

## 7. Ilovani instrumentatsiya qilish

### Client library qanday ishlaydi

**Instrumentatsiya** bu o'z kodingizga o'lchov nuqtalarini qo'shish. **Client library** (Node.js: `prom-client`, Go: `github.com/prometheus/client_golang`) jarayon xotirasida **registry** yuritadi: barcha metrika obyektlari ro'yxati. Siz metrika obyektini bir marta yaratasiz, kod ichida `inc()`, `set()` yoki `observe()` chaqirasiz (bu shunchaki xotiradagi sonni o'zgartiradi, tarmoqqa hech narsa ketmaydi), `/metrics` handler esa scrape kelganda registry'ni matnga aylantiradi.

Xayoliy xat yuboruvchi worker uchun parcha (Node.js):

```js
const client = require('prom-client');
client.collectDefaultMetrics();                 // runtime metrics: heap, GC, event loop lag
const sent = new client.Counter({
  name: 'emails_sent_total',
  help: 'Total emails handed to a provider.',
  labelNames: ['provider', 'result'],
});
sent.inc({ provider: 'smtp', result: 'ok' });   // somewhere after a send
```

`/metrics` handler'da `client.register.metrics()` (Promise qaytaradi) va `client.register.contentType` ishlatiladi. Go'da ekvivalent: `promauto.NewCounterVec(prometheus.CounterOpts{...}, []string{"provider", "result"})` va `promhttp.Handler()`. Histogram xuddi shunday yaratiladi, qo'shimcha `buckets` ro'yxati bilan; ko'rsatilmasa default chegaralar 0.005 dan 10 soniyagacha (11 ta).

Default collector'lar runtime metrikalarini beradi: Node.js'da heap, GC va `nodejs_eventloop_lag_seconds` (event loop qancha kechikayotgani: brauzerdagi "long task" ning server tomondagi qarindoshi, bitta sinxron og'ir funksiya barcha so'rovlarni to'xtatganini ko'rsatadi); Go'da goroutine soni va GC.

### Qoidalar

- O'lchash bir joyda, middleware'da (har so'rov o'tadigan umumiy funksiya), har handler'da alohida emas.
- Yo'l label'i shablon bo'lsin (`/orders/:id`), haqiqiy URL emas (3-bo'lim).
- Topilmagan yo'llar (404) uchun bitta umumiy qiymat, aks holda skaner botlar cardinality'ni portlatadi.
- `/metrics` va `/healthz` ni o'lchamaslik odat.
- Davomiylik soniyada, histogram chegaralari kutilgan diapazonni qoplasin.

### Real ishda qachon kerak

Exporter resursni ko'rsatadi, lekin "buyurtmalar nechta, to'lov xatosi qancha" ni faqat kod biladi. Har yangi servisda birinchi kundan RED metrikalari (9-bo'lim) qo'shiladi.

### Nima uchun shunday

Registry xotirada va scrape'gacha hech narsa yuborilmaydi, shuning uchun `inc()` juda arzon va uni issiq yo'lga qo'yish mumkin. Bir nechta jarayonli ishga tushirishda (Node `cluster`, PM2) har jarayonning o'z registry'si bor, bu alohida yechim talab qiladi; konteynerda bitta jarayon ishlatilsa muammo yo'q.

## 8. PromQL

**PromQL** bu Prometheus so'rov tili. SQL'dan farqi: har ifoda natijasi jadval emas, seriyalar to'plami. Bu bo'limdagi so'rovlar Prometheus'ning o'z metrikalarida ishlaydi, ularni birinchi vazifadan keyin UI'da (Query sahifasi, Table va Graph ko'rinishlari) bajarish mumkin.

### Instant vector, range vector, selector

**Instant vector**: har seriyadan bittadan, eng so'nggi sample. **Selector** bu nom va matcher'lar (label filtrlari):

```
prometheus_http_requests_total{code="200", handler=~"/api/v1/.*"}
```

Matcher'lar: `=`, `!=`, `=~`, `!~` (regex RE2, butun qiymatga to'liq mos kelishi kerak). Natija:

```
prometheus_http_requests_total{code="200", handler="/api/v1/query", instance="localhost:9090", job="prometheus"}        37
prometheus_http_requests_total{code="200", handler="/api/v1/label/:name/values", instance="localhost:9090", job="prometheus"}  4
```

Ikki series: har birida to'liq label to'plami va hozirgi qiymat. E'tibor bering, `handler` shablon (`:name`), haqiqiy yo'l emas.

**Range vector**: har seriya uchun oynadagi barcha sample'lar, `[5m]` yozuvi bilan. Scrape interval 15s bo'lganda `prometheus_http_requests_total{handler="/api/v1/query"}[1m]`:

```
33 @1759830015.214
34 @1759830030.214
36 @1759830045.214
37 @1759830060.214
```

To'rt sample, har biri `qiymat @unix_vaqt`. Range vector'ni grafikka chizib bo'lmaydi, u funksiyaga beriladi. `offset 1h` o'tmishdagi qiymatni, `@` aniq vaqtni beradi. Instant so'rov sample'ni cheklangan muddat orqaga qarab qidiradi; target yoki series yo'qolsa u "eskirgan" (stale) hisoblanadi va natijadan chiqadi (Manbalar, "staleness").

### rate, irate, increase

`rate(x[1m])` oynadagi birinchi va oxirgi sample orasidagi o'sishni soniyaga bo'ladi. Yuqoridagi to'rt sample uchun: o'sish 37 − 33 = 4, ular orasida 45 soniya, 4 / 45 ≈ 0.089 so'rov/s. Sample'lar oyna chetlariga yetmagani uchun Prometheus o'sishni oyna uzunligiga ekstrapolatsiya qiladi: `increase(x[1m])` shu misolda 4 emas, 4 × 60 / 45 ≈ 5.33 qaytaradi (kasr son chiqishi normal), `rate` esa 5.33 / 60 ≈ 0.089. Ya'ni `increase` = `rate` × oyna uzunligi.

Mexanizmdan uch xulosa:

- `rate` ga oynada kamida 2 sample kerak, aks holda shu seriya uchun natija yo'q. Amaliy qoida: oyna scrape interval'dan kamida 4 marta katta (bitta scrape yiqilsa ham sample yetadi).
- Counter reset: oynadagi qiymat oldingisidan kichik bo'lsa (`36, 37, 2, 5`), `rate` buni restart deb oladi va tushishdan keyingi qiymatlarni oldingisiga qo'shib hisoblaydi (o'sish 37 − 36 + 2 + 3 = 6). Gauge'da bu mantiq noto'g'ri natija beradi, shuning uchun `rate` faqat counter'ga.
- `irate` faqat oynadagi oxirgi ikki sample'ga qaraydi: keskin, tez o'zgaruvchan grafik uchun; alert va recording rule uchun emas.

Oyna keng bo'lsa grafik silliq va kechikkan, tor bo'lsa keskin va shovqinli.

### Agregatsiya

```
sum by (handler) (rate(prometheus_http_requests_total[5m]))
sum without (instance, code) (rate(prometheus_http_requests_total[5m]))
topk(3, sum by (handler) (rate(prometheus_http_requests_total[5m])))
```

`by (handler)`: faqat `handler` label'i qoladi, qolganlari bo'yicha qo'shiladi. `without (...)`: sanalganlari olib tashlanadi, qolgan hammasi saqlanadi. Birinchi so'rov natijasi:

```
{handler="/metrics"}        0.0667
{handler="/api/v1/query"}   0.0222
```

Nom yo'qoldi (natija endi boshqa narsa, counter emas), har handler uchun bitta son: `/metrics` ga soniyasiga 0.0667 so'rov, bu aynan 15 soniyada 1 scrape. Operatorlar: `sum`, `avg`, `min`, `max`, `count`, `topk`, `bottomk`, `quantile`, `count_values`.

Tartib muhim: avval `rate`, keyin `sum`. Yig'indi ustidan `rate` olinsa (`rate(sum(x)[5m:])`, bu yerda `[5m:]` subquery yozuvi), bitta replika restart bo'lganda uning counter'i 0 ga tushadi, yig'indi biroz kamayadi, `rate` buni butun yig'indining reset'i deb oladi va soxta sakrash chiqadi.

### Binary operatorlar va vector matching

Ikki instant vector orasidagi `/`, `*`, `+`, `-`, `>` kabi operator chap va o'ngdagi seriyalarni label'lari to'liq bir xil bo'lganlari bo'yicha juftlaydi. Juftini topmagan series natijadan tushib qoladi.

```
prometheus_tsdb_head_chunks / prometheus_tsdb_head_series
```

Ikkala tomonda `{instance="localhost:9090", job="prometheus"}` bir xil, natija bitta son: har seriyaga o'rtacha nechta chunk. Ulush (ratio) ham shunday quriladi: suratda filtrlangan `sum(rate(...))`, maxrajda filtrsiz `sum(rate(...))`; ikkala tomon bir xil `by (...)` bilan agregatsiya qilinsa label'lar mos keladi. Label to'plamlari farq qilsa `on(...)` (faqat shu label'lar bo'yicha solishtir) yoki `ignoring(...)`, bir tomonda ko'p seriya bo'lsa `group_left` kerak. To'plam operatorlari: `and`, `or`, `unless`. Natija bo'sh chiqsa birinchi gumon: label'lar mos kelmayapti, har tomonni alohida bajarib ko'ring.

### histogram_quantile

`histogram_quantile(q, buckets)` bucket hisoblagichlaridan q-quantile'ni taxmin qiladi. 4-bo'limdagi misolni olaylik va shu sonlar oxirgi 5 daqiqadagi o'sish deb faraz qilaylik: jami 320, bucket'lar `le="0.1"` 240, `le="0.5"` 310, `le="2"` 318.

- p50: 0.5 × 320 = 160-kuzatuv. U birinchi bucket'da (0 dan 0.1 gacha, 240 ta). Tekis taqsimot farazi bilan: 0.1 × 160 / 240 ≈ 0.067 s.
- p95: 0.95 × 320 = 304-kuzatuv. U `le="0.5"` bucket'ida (241 dan 310 gacha, 70 ta). Ichidagi o'rni (304 − 240) / 70 ≈ 0.914, natija 0.1 + (0.5 − 0.1) × 0.914 ≈ 0.466 s.

Haqiqiy p95 0.1 va 0.5 orasida istalgan joyda bo'lishi mumkin, funksiya faqat taxmin beradi: bucket qancha keng bo'lsa xato shuncha katta. Quantile `+Inf` bucket'iga tushsa natija oxirgi chekli chegaraga teng bo'ladi.

```
histogram_quantile(0.9,
  sum by (le, handler) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
```

Tartib: har bucket counter bo'lgani uchun avval `rate`, keyin replikalar bo'yicha `sum`, va `le` agregatsiyada qolishi shart, chunki funksiya bucket'larni shu label orqali taniydi. O'rtacha: `rate(..._sum[5m]) / rate(..._count[5m])`. O'rtacha dumni (tail) yashiradi: 99 ta so'rov 50 ms va bittasi 10 s bo'lsa o'rtacha 150 ms, p99 esa muammoni ko'rsatadi. Bu Web Vitals'dagi p75 bilan bir xil mulohaza.

### Real ishda qachon kerak

Har dashboard paneli (2-dars) va har alert (3-dars) ortida PromQL turadi. Incident paytida so'rov noldan yoziladi: avval selector, keyin `rate`, keyin agregatsiya, har qadamda natijaga qarab.

### Nima uchun shunday

PromQL label'li seriyalar to'plami ustidagi funksional til, chunki monitoring savollari deyarli doim "shu o'lcham bo'yicha guruhlab, tezligini ol" shaklida, SQL'da buning uchun window funksiyalari va join yozish kerak bo'lardi. `rate` ekstrapolatsiya qiladi, chunki scrape'lar oyna chetlari bilan mos tushmaydi va usiz qisqa oynalarda tezlik muntazam kam chiqardi.

## 9. RED, USE va recording rules

### RED va USE

| Metod | Kim uchun | Nimani o'lchaydi |
|-------|-----------|-------------------|
| RED | so'rovga xizmat qiladigan servis | **R**ate (so'rov/s), **E**rrors (xato ulushi), **D**uration (latency taqsimoti) |
| USE | resurs: CPU, xotira, disk, tarmoq | **U**tilization (band ulushi), **S**aturation (navbat, kutish), **E**rrors |

Ikkalasi ham nazorat ro'yxati: "nimani o'lchashni unutdim?" degan savolga javob. RED foydalanuvchi nimani his qilayotganini ko'rsatadi (symptom), USE nima uchun ekanini (cause). Saturation bu resursga sig'magan ish: linux 8-darsdagi load average yadrolar sonidan katta bo'lsa, jarayonlar CPU navbatida turibdi. Google SRE'ning "four golden signals" i (latency, traffic, errors, saturation) shu ikkisining birlashmasi. Dashboard va alert'lar RED'dan boshlanadi, USE diagnostika uchun.

### Recording rules

**Recording rule** bu Prometheus har `evaluation_interval` da o'zi bajarib, natijasini yangi seriya sifatida saqlaydigan PromQL ifodasi. Og'ir yoki ko'p ishlatiladigan ifoda bir marta hisoblanadi: dashboard tezlashadi, alert ifodalari qisqaradi. Nomlash: `level:metric:operations` (qaysi label'lar qolgani, asl metrika, qo'llangan amallar).

```yaml
groups:
  - name: prometheus_self
    interval: 30s
    rules:
      - record: handler:prometheus_http_requests:rate5m
        expr: sum by (handler) (rate(prometheus_http_requests_total[5m]))
```

Tekshirish: `promtool check rules <fayl>`. Qoidalar unit test bilan ham tekshiriladi (`promtool test rules <test fayli>`): test faylida `input_series` sun'iy seriyalarni beradi, qiymatlar qisqa yozuvda (`'0+10x5'` degani 0 dan boshlab har qadamda 10 ga oshadigan 6 ta sample), `promql_expr_test` esa ma'lum `eval_time` da kutilgan natijani solishtiradi. To'liq format Manbalarda.

### Real ishda qachon kerak

- Yangi servis uchun dashboard: yuqorida RED, pastda USE.
- Dashboard sekin ochilsa yoki bir ifoda o'nta joyda takrorlansa: recording rule. Bir marta ishlatiladigan yengil ifoda uchun ortiqcha.

### Nima uchun shunday

RED (Tom Wilkie) va USE (Brendan Gregg) "hamma narsani o'lchang" o'rniga har servis va har resurs uchun bir xil qisqa ro'yxat beradi, shunda begona servis dashboard'ini ham darhol o'qiy olasiz. Recording rule saqlash evaziga hisobni tejaydi: yangi series qo'shiladi, lekin so'rov paytida minglab xom seriyani o'qish shart emas.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Metric | muntazam o'lchab boriladigan raqam |
| Target | Prometheus scrape qiladigan bitta `host:port` manzil |
| Scrape | target'ning `/metrics` iga yuboriladigan bitta HTTP so'rov |
| Job | bir xil vazifali target'lar guruhi, `job` label'i |
| Instance | bitta target manzili, `instance` label'i |
| Time series | nom va label'lar to'plami bilan aniqlanadigan sample'lar ketma-ketligi |
| Sample | bitta `(timestamp, value)` nuqta |
| Label | seriyaga yopishtirilgan `kalit="qiymat"` juftligi |
| Cardinality | noyob series'lar soni |
| Exposition format | `/metrics` javobining matn formati |
| Counter | faqat o'sadigan hisoblagich |
| Gauge | o'sadigan va kamayadigan joriy qiymat |
| Histogram | kuzatuvlarni kumulyativ bucket'larga sanaydigan metrika |
| Bucket | `le` chegarasigacha bo'lgan kuzatuvlar hisoblagichi |
| Summary | quantile'ni ilova ichida hisoblaydigan metrika |
| Exporter | begona tizim holatini `/metrics` ga tarjima qiladigan jarayon |
| Instrumentatsiya | o'z kodingizga o'lchov nuqtalarini qo'shish |
| Registry | client library'dagi metrika obyektlari ro'yxati |
| PromQL | Prometheus so'rov tili |
| Instant vector | har seriyadan bitta eng so'nggi sample |
| Range vector | har seriyadan oynadagi barcha sample'lar |
| Counter reset | restart sabab counter'ning 0 ga tushishi |
| Relabeling | label'larni qoidalar bilan qayta yozish yoki series tashlash |
| Recording rule | natijasi yangi seriya bo'lib saqlanadigan PromQL ifodasi |
| Retention | ma'lumot saqlanadigan muddat yoki hajm |
| WAL | yiqilishdan keyin tiklash uchun yoziladigan jurnal |
| TSDB | time series saqlashga moslashgan baza |
| RED / USE | servis va resurs uchun o'lchov nazorat ro'yxatlari |

## Tuzoqlar

- Yuqori cardinality'li label (`user_id`, to'liq URL, `trace_id`): series soni portlaydi, Prometheus OOM bo'ladi. Label qiymatlari cheklangan to'plam bo'lsin.
- Counter'ni `rate()` siz grafikka chizish yoki alert qilish: restart'da 0 ga tushadi, qiymatning o'zi ma'nosiz.
- `rate(sum(...))`: reset'lar yig'indida yo'qoladi. Doim `sum(rate(...))`.
- `rate` oynasi scrape interval'ga yaqin: oynada 2 sample bo'lmasa natija yo'q yoki grafik uzuq.
- `rate` ni gauge'ga qo'llash: har kamayish reset deb olinadi, natija yolg'on.
- `histogram_quantile` da `le` ni agregatsiyadan tushirib qoldirish, yoki bucket'larni SLO chegarasidan uzoq qo'yish.
- Summary quantile'larini replikalar bo'yicha `avg` qilish: natija hech narsani anglatmaydi.
- O'rtacha latency'ga qarab xulosa qilish: 1% so'rov 10 soniya bo'lsa o'rtacha buni ko'rsatmaydi.
- Compose'da target'ni `localhost:PORT` deb yozish: bu Prometheus konteynerining o'zi, servis nomi kerak.
- `command:` ga bitta flag qo'shib, `--config.file` va `--storage.tsdb.path` ni unutish: default argumentlar almashib ketadi.
- Volume'siz Prometheus: konteyner qayta yaratilganda butun tarix yo'qoladi.
- Portni `9090:9090` deb e'lon qilish: UI butun lokal tarmoqqa ochiladi, autentifikatsiya yo'q. `127.0.0.1:` prefiksi bilan yozing. Production'da `/metrics` ham internetga ochilmaydi: ichki tuzilma, versiyalar va trafik hajmi ko'rinadi.
- `latest` tag: Prometheus 2 → 3 kabi major o'tishlarda config va UI o'zgaradi, stack kutilmaganda buziladi.
- macOS'da `node-exporter` raqamlarini Mac'niki deb o'qish: ular Docker Desktop VM'iniki.
- Tozalashda `docker system prune` yoki `docker volume prune -a`: boshqa loyihalarning ma'lumoti ham ketadi. Faqat shu stack papkasida `docker compose down`.

## Manbalar

- https://prometheus.io/docs/introduction/overview/ – arxitektura va tushunchalar
- https://prometheus.io/docs/concepts/data_model/ – time series, label, sample
- https://prometheus.io/docs/concepts/metric_types/ – metrika turlari (majburiy)
- https://prometheus.io/docs/instrumenting/exposition_formats/ – exposition format
- https://prometheus.io/docs/practices/naming/ – nomlash va label qoidalari
- https://prometheus.io/docs/practices/histograms/ – histogram va summary taqqosi
- https://prometheus.io/docs/prometheus/latest/configuration/configuration/ – `prometheus.yml` kalitlari, relabeling
- https://prometheus.io/docs/prometheus/latest/querying/basics/ – PromQL asoslari, shu sahifada "Staleness" bo'limi
- https://prometheus.io/docs/prometheus/latest/querying/functions/ – `rate`, `irate`, `increase`, `histogram_quantile`
- https://prometheus.io/docs/prometheus/latest/querying/operators/ – agregatsiya va vector matching
- https://prometheus.io/docs/practices/rules/ – recording rule nomlash
- https://prometheus.io/docs/prometheus/latest/configuration/unit_testing_rules/ – `promtool test rules`
- https://prometheus.io/docs/prometheus/latest/storage/ – TSDB, retention, disk hisobi
- https://prometheus.io/docs/specs/native_histograms/ – native histogram holati
- https://prometheus.io/docs/instrumenting/exporters/ – rasmiy va hamjamiyat exporter'lari
- https://github.com/prometheus/node_exporter – node_exporter, Docker'da ishga tushirish
- https://github.com/google/cadvisor – cAdvisor README
- https://github.com/siimon/prom-client – Node.js client library
- https://pkg.go.dev/github.com/prometheus/client_golang/prometheus – Go client library
- https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/ – RED metodi
- https://www.brendangregg.com/usemethod.html – USE metodi
- https://sre.google/sre-book/monitoring-distributed-systems/ – four golden signals

---

## Birga bajaramiz

Bitta savolni boshidan oxirigacha kuzatamiz: "Prometheus'ning `/metrics` handler'i soniyasiga nechta so'rov olyapti va qancha tez javob beryapti?" Hali stack ham, ilova ham, exporter ham yo'q: vaqtinchalik bitta konteyner, config'siz. Stack bilan to'qnashmasligi uchun boshqa nom va `9091` port ishlatiladi. Ikkala mashinada bir xil ishlaydi.

1. Konteynerni ishga tushiramiz. Image ichida default config bor: Prometheus har 15 soniyada o'zini (`localhost:9090`, job nomi `prometheus`) scrape qiladi.

```
docker run -d --name prom-walk -p 127.0.0.1:9091:9090 prom/prometheus:<tag>
```

`<tag>` release sahifasidagi joriy versiya. `-p 127.0.0.1:9091:9090`: host'ning faqat loopback'idagi 9091 port konteynerning 9090 portiga ulanadi.

2. Bir daqiqa kutib, pull modelining natijasini HTTP API orqali so'raymiz (UI ham, 2-darsdagi Grafana ham aynan shu API'ni chaqiradi):

```
$ curl -s 'localhost:9091/api/v1/query?query=up'
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"up","instance":"localhost:9090","job":"prometheus"},"value":[<unix_vaqt>,"1"]}]}}
```

`resultType: vector` instant vector degani. `result` da bitta series: `metric` uning label'lari (`__name__` ham label), `value` juftligi sample: vaqt va qiymat. Qiymat `"1"`: oxirgi scrape muvaffaqiyatli. `instance` `localhost:9090`, 9091 emas: bu Prometheus konteyner ichidan ko'rgan manzil, host'dagi port unga noma'lum.

3. Endi scrape nimani o'qiyotganini o'zimiz o'qiymiz:

```
$ curl -s localhost:9091/metrics | grep 'prometheus_http_requests_total'
# HELP prometheus_http_requests_total Counter of HTTP requests.
# TYPE prometheus_http_requests_total counter
prometheus_http_requests_total{code="200",handler="/api/v1/query"} 1
prometheus_http_requests_total{code="200",handler="/metrics"} 6
```

Tur counter. Ikki series: 2-qadamdagi bitta API so'rovimiz va `/metrics` ga 6 ta so'rov (har 15 soniyada bitta scrape, ya'ni taxminan bir yarim daqiqa). Bu yerda `job` va `instance` yo'q, ular saqlash paytida qo'shiladi. Bizning `curl` ham shu handler'ga so'rov, shuning uchun counter keyingi safar bittaga ortiqcha sakraydi.

4. Besh daqiqacha kutamiz (7-qadamdagi `[5m]` oyna to'lishi uchun), keyin brauzerda `http://localhost:9091` ni ochib, Query sahifasida range vector so'raymiz: `prometheus_http_requests_total{handler="/metrics"}[1m]`.

```
prometheus_http_requests_total{code="200", handler="/metrics", instance="localhost:9090", job="prometheus"}
27 @<t-45>
28 @<t-30>
29 @<t-15>
30 @<t>
```

Bir daqiqalik oynada to'rtta sample, oralari 15 soniya, har birida counter bittaga oshgan. Qo'lda: o'sish 30 − 27 = 3, vaqt 45 s, 3 / 45 ≈ 0.0667 so'rov/s.

5. Xuddi shu hisobni Prometheus'ga qildiramiz:

```
rate(prometheus_http_requests_total{handler="/metrics"}[1m])       =>  0.0667
increase(prometheus_http_requests_total{handler="/metrics"}[1m])   =>  4
```

`rate` qo'lda chiqqan son bilan bir xil. `increase` 3 emas, 4: sample'lar orasidagi 45 soniyalik o'sish 60 soniyalik oynaga ekstrapolatsiya qilingan (3 × 60 / 45). Mantiqan ham to'g'ri: bir daqiqada 4 ta scrape bo'ladi. Graph ko'rinishida xom counter zinapoya bo'lib o'sadi, `rate` esa tekis chiziq.

6. Endi tezlik. Histogram'ni simda ko'ramiz:

```
$ curl -s localhost:9091/metrics | grep 'request_duration_seconds.*handler="/metrics"'
prometheus_http_request_duration_seconds_bucket{handler="/metrics",le="0.1"} 34
prometheus_http_request_duration_seconds_bucket{handler="/metrics",le="0.2"} 34
...
prometheus_http_request_duration_seconds_bucket{handler="/metrics",le="+Inf"} 34
prometheus_http_request_duration_seconds_sum{handler="/metrics"} 0.1292
prometheus_http_request_duration_seconds_count{handler="/metrics"} 34
```

Barcha 34 so'rov eng birinchi bucket'ga (0.1 soniyagacha) tushgan, keyingi bucket'lar shu sonni takrorlaydi (kumulyativ). O'rtacha: 0.1292 / 34 = 0.0038 s, ya'ni 3.8 ms.

7. p95 ni so'raymiz va o'rtacha bilan solishtiramiz:

```
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket{handler="/metrics"}[5m]))   =>  0.095
rate(prometheus_http_request_duration_seconds_sum{handler="/metrics"}[5m])
  / rate(prometheus_http_request_duration_seconds_count{handler="/metrics"}[5m])                          =>  0.0038
```

p95 95 ms, o'rtacha esa 3.8 ms: 25 marta farq. Bu yerda yolg'on gapirayotgan p95: hamma kuzatuv 0 dan 0.1 gacha bo'lgan bitta bucket'da, funksiya ularni shu oraliqda tekis tarqalgan deb faraz qiladi va 0.95 × 0.1 = 0.095 ni qaytaradi. Sinab ko'ring: 0.5 uchun 0.05, 0.99 uchun 0.099 chiqadi. Histogram "0.1 soniyadan tez" dan aniqroq narsa bilmaydi, chunki bu chegaralar millisekundli handler uchun emas, sekin so'rovlar uchun tanlangan.

8. Tozalaymiz. Faqat shu konteyner va uning anonim volume'i o'chadi:

```
docker rm -f -v prom-walk
```

Shu 8 qadamda ko'rganingiz: Prometheus target'ni o'zi borib o'qidi va `up` ni yozdi (2-bo'lim), saqlangan seriyaga `job` va `instance` qo'shildi (3-bo'lim), counter va histogram simda oddiy matn (4-bo'lim), default config'da bitta job bor (5-bo'lim), `rate` va `increase` range vector'dan qo'lda hisoblasa bo'ladigan arifmetika (8-bo'lim), `histogram_quantile` aniqligi esa bucket chegaralariga bog'liq (4 va 8-bo'limlar).

---

## Vazifalar

Ish papkasi: `observability/01-prometheus/` (`make new m=observability n=01 name=prometheus`). Javoblar shu papkadagi `README.md` da, har vazifa uchun `## N. Title` sarlavhasi ostida: ishlatilgan buyruq yoki PromQL, natijaning muhim qismi va o'z so'zingiz bilan izoh. Stack fayllari (`compose.yaml`, `prometheus/prometheus.yml`, `prometheus/rules/*.yml`, `app/`) `observability/stack/` da turadi va keyingi darslarda davom ettiriladi. Hammasi host'dagi Docker Compose'da, ikkala mashinada; macOS'da boshqacha bo'ladigan joylar vazifaning o'zida aytilgan. README'da har vazifa qaysi mashinada bajarilganini yozing (`uname -s`).

### A. Birinchi scrape

1. **Prometheus alone.** `compose.yaml` ga faqat `prometheus` servisini yozing: aniq versiya tag'i, `prometheus.yml` bind mount, ma'lumot uchun named volume, `9090` port (faqat `127.0.0.1` da). Config'da Prometheus o'zini scrape qilsin. UI'da Status → Target health sahifasida target `UP` ekanini ko'rsating va `up` so'rovi natijasidagi `job` va `instance` label'lari qayerdan kelganini izohlang. Yo'nalish: 2-bo'lim, "Scrape sikli"; 5-bo'lim, "Config tuzilishi".

2. **Read the exposition format.** `curl -s localhost:9090/metrics` chiqishidan bittadan counter, gauge, histogram va summary toping. Har biri uchun `# TYPE` qatorini va 2–3 qator namunani yozing. Histogram'da `_bucket`, `_sum`, `_count` qanday bog'langanini shu real raqamlar ustida tushuntiring. Yo'nalish: 4-bo'lim, "Histogram ichidan".

3. **Break the target.** `scrape_configs` ga mavjud bo'lmagan target (`nohost:9999`) qo'shing, config'ni qayta yuklang. Target health sahifasidagi xato matnini va `up{job="..."}` qiymatini yozing. Keyin `prometheus.yml` da YAML xatosi qiling va `promtool check config` nima deyishini ko'rsating. Ikkalasini tuzating. Yo'nalish: 2-bo'lim, "Scrape sikli"; 5-bo'lim, "Tekshirish va qayta yuklash".

4. **Reload without restart.** Config'ni ikki usulda qayta yuklang: `SIGHUP` va `--web.enable-lifecycle` bilan `/-/reload`. Har birida Prometheus log'ida nima chiqishini yozing. Nima uchun `docker compose restart` yomonroq variant ekanini izohlang. Yo'nalish: 5-bo'lim, "Tekshirish va qayta yuklash" va "Nima uchun shunday"; Tuzoqlardagi `command:` haqidagi band.

### B. Exporter'lar

5. **node_exporter.** `node-exporter` servisini qo'shing (host fayl tizimi faqat o'qish uchun). Uni scrape qiling va PromQL bilan hisoblang: CPU band foizi (`mode="idle"` orqali), bo'sh xotira foizi, `/` filesystem'dagi bo'sh joy foizi. Natijalarni `top`, `free -m`, `df -h` bilan solishtiring. Zorin'da bu buyruqlar host'da bajariladi. macOS'da metrikalar Docker Desktop VM'iniki: solishtirish uchun `docker info` dagi `CPUs` va `Total Memory` ni oling, `free -m` va `df -h` ni esa bir martalik konteyner ichida bajaring (`docker run --rm alpine free -m`); mount xato bersa nima qilganingizni va qaysi mountpoint ko'ringanini README'ga yozing. Yo'nalish: 6-bo'lim, "node_exporter"; 8-bo'lim, "rate, irate, increase" va "Binary operatorlar va vector matching".

6. **Host network trade-off.** node_exporter'ni bir marta oddiy bridge tarmoqda, bir marta `network_mode: host` bilan ishga tushiring. `node_network_receive_bytes_total` da qaysi interfeyslar ko'rinishini ikkala holatda yozing va farqni tushuntiring. Host rejimida Prometheus unga qanday manzil bilan yetdi? Bu vazifa to'liq ma'noda Zorin'da bajariladi. macOS'da "host" Docker Desktop VM'ining tarmog'i: nima ko'rinsa shuni yozing, Prometheus yeta olmasa "bu yerda mavjud emas" deb belgilang va ofisda yakunlang. Oxirida stack'ni bridge variantiga qaytaring. Yo'nalish: 6-bo'lim, "node_exporter"; docker moduli, 3-dars.

7. **cAdvisor.** `cadvisor` servisini README'dagi mount'lar bilan qo'shing. Har konteyner uchun CPU ishlatilishi (`rate` bilan, yadro ulushida) va xotirani (`container_memory_working_set_bytes`) `name` label'i bo'yicha chiqaring. `docker stats` bilan solishtiring. cAdvisor nechta series berayotganini `count by (job) ({__name__=~".+"})` bilan o'lchang. macOS'da avval `name` label'i umuman bormi, tekshiring; bo'lmasa qaysi label'lar borligini yozing va solishtirish qismini ofisda bajaring. Yo'nalish: 6-bo'lim, "cAdvisor"; 8-bo'lim, "Agregatsiya".

8. **Drop with relabeling.** `metric_relabel_configs` bilan cAdvisor'dan keraksiz metrikalar oilasini (masalan `container_tasks_state`) tashlab yuboring. Oldin va keyin series sonini yozing. `relabel_configs` va `metric_relabel_configs` farqini o'z so'zingiz bilan tushuntiring. Sizdagi cAdvisor bu oilani bermasa, 3-bo'limdagi `topk` so'rovi bilan eng katta oilani topib, o'shani tashlang. Yo'nalish: 5-bo'lim, "Relabeling (tanishuv)".

### C. Ilova metrikalari

9. **Sample app.** `stack/app/` da kichik HTTP servis yozing (Node.js yoki Go, tanlov sizniki), `Dockerfile` bilan: `GET /products` (tasodifiy 20–300 ms kechikish), `GET /products/:id`, `GET /checkout` (taxminan 5% holatda `500`), `GET /healthz`. Hozircha metrikasiz. Uni `api` nomi bilan compose'ga qo'shing (`8000` port, `127.0.0.1` da). Base image multi-arch bo'lsin, shunda bir xil `Dockerfile` ikkala mashinada build bo'ladi. Yo'nalish: docker moduli, 2 va 4-darslar.

10. **Instrument with a client library.** Ilovaga client library qo'shing: default runtime metrikalari, `http_requests_total` counter (`method`, `route`, `status`), `http_request_duration_seconds` histogram (bucket'larni o'zingiz asoslab tanlang), `http_requests_in_flight` gauge va `/metrics` endpoint. Prometheus'da `api` job'ini qo'shing. `curl localhost:8000/metrics` dan o'z metrikalaringizni ko'rsating. Yo'nalish: 7-bo'lim, "Client library qanday ishlaydi" va "Qoidalar"; 4-bo'lim, "Histogram ichidan".

11. **Load generator.** Compose'ga `loadgen` servisini qo'shing: `curlimages/curl` image'ida cheksiz shell sikli uchala endpoint'ga turli chastotada so'rov yuborsin. 5 daqiqa ishlatib, `http_requests_total` ning xom grafigi va `rate(http_requests_total[1m])` grafigini solishtiring. `api` ni restart qiling: ikkala grafikda nima bo'ldi? Yo'nalish: 4-bo'lim, "To'rt tur" (counter); 8-bo'lim, "rate, irate, increase".

12. **Cardinality bomb.** Ataylab xato qiling: `route` label'iga shablon o'rniga haqiqiy yo'lni (`/products/123`) yozing va loadgen'da tasodifiy `id` yuboring. 3 daqiqadan keyin `count(http_requests_total)` va Status → TSDB status sahifasidagi eng katta metrikalarni yozing. Tuzating. Eski series'lar qachon yo'qolishini kuzating va sababini izohlang. Yo'nalish: 3-bo'lim, "Cardinality"; Manbalardagi "Staleness" bo'limi.

### D. PromQL

13. **Rate window.** `rate(http_requests_total[15s])`, `[1m]`, `[5m]` va `irate(...[1m])` ni bitta grafikda solishtiring (scrape interval 15s). Qaysi biri bo'sh, qaysi biri silliq, qaysi biri keskin? Sababini mexanizm orqali tushuntiring. Yo'nalish: 8-bo'lim, "rate, irate, increase".

14. **RED queries.** `api` uchun uchta so'rov yozing: route bo'yicha so'rov/s, umumiy xato ulushi foizda (5xx), route bo'yicha p50/p95/p99 latency. p95 natijasini ilovadagi kechikish diapazoni bilan solishtiring: mantiqqa to'g'ri keladimi? Yo'nalish: 8-bo'lim, "Agregatsiya", "Binary operatorlar va vector matching", "histogram_quantile"; 9-bo'lim, "RED va USE".

15. **Wrong aggregation.** `histogram_quantile` so'rovini uch xil buzing va natijani yozing: `le` ni `by` dan olib tashlang; `rate` siz yozing; `sum` va `rate` o'rnini almashtiring. Har biri nima uchun noto'g'ri? Yo'nalish: 8-bo'lim, "Agregatsiya" va "histogram_quantile".

16. **Bucket resolution.** Histogram bucket'larini ataylab qo'pol qiling (`[1, 10]`), 5 daqiqa yuklama bering va p95 ni yozing. Keyin asl bucket'larga qayting. Farqni interpolatsiya orqali tushuntiring. Yo'nalish: 8-bo'lim, "histogram_quantile"; "Birga bajaramiz", 7-qadam.

17. **USE queries.** node_exporter va cAdvisor metrikalaridan host CPU va xotira uchun utilization va saturation (`node_load1` ni yadrolar soniga nisbati, `node_pressure_*` mavjud bo'lsa) so'rovlarini yozing. `api` konteyneri uchun CPU utilization'ni yozing. macOS'da "host" bu Docker Desktop VM'i; cAdvisor `api` ni `name` bilan ko'rsatmasa, shu qismni ofisda bajaring. Yo'nalish: 9-bo'lim, "RED va USE"; 6-bo'lim.

18. **Vector matching.** Route bo'yicha xato ulushini hisoblang (har route uchun alohida foiz). Xatosi yo'q route'lar natijadan tushib qolishini ko'rsating va buni `or` yoki boshqa usul bilan qanday hal qilishni toping. Yo'nalish: 8-bo'lim, "Binary operatorlar va vector matching"; Manbalardagi operators sahifasi.

### E. Rules va saqlash

19. **Recording rules.** `prometheus/rules/api.yml` da RED uchun uchta recording rule yozing (nomlash qoidasi bo'yicha). `promtool check rules` toza o'tsin. UI'ning Rules sahifasida ular ko'rinishini va yangi seriyalar so'rovga javob berishini ko'rsating. Yo'nalish: 9-bo'lim, "Recording rules".

20. **Rule unit test.** Bitta recording rule uchun `promtool test rules` test faylini yozing (`input_series` va kutilgan qiymat). Testni bir marta ataylab noto'g'ri kutilgan qiymat bilan yiqiting va xato chiqishini yozing. Test faylini konteyner ko'radigan joyga (rules papkasi yoniga) qo'ying, `promtool` `docker compose exec` orqali ishlaydi. Yo'nalish: 9-bo'lim, "Recording rules"; Manbalardagi unit testing sahifasi.

21. **Retention and storage.** Retention'ni `--storage.tsdb.retention.time` bilan 7 kunga qo'ying. `prometheus_tsdb_head_series` va volume hajmini (`docker system df -v`) yozing. Hozirgi series soni va scrape interval bilan 7 kunlik disk hajmini taxminan hisoblang. Yo'nalish: 5-bo'lim, "Saqlash va retention".

22. **Mini-project: metrics baseline.** Stack'ni toza holatga keltiring: `docker compose down -v` dan keyin bitta `docker compose up -d` bilan `prometheus`, `node-exporter`, `cadvisor`, `api`, `loadgen` ko'tarilsin, barcha target'lar `UP`, recording rule'lar ishlasin, barcha image'lar aniq versiyada, `api` da healthcheck bo'lsin. `README.md` ga stack sxemasini (kim kimni scrape qiladi, portlar) va RED/USE so'rovlari ro'yxatini yozing. Bu 2-darsning boshlang'ich nuqtasi. `down -v` ni faqat `observability/stack/` ichida bajaring: u faqat shu loyihaning volume'larini o'chiradi (shu mashinadagi metrikalar tarixi ketadi). Ikkinchi mashinada ham `git pull` dan keyin bir marta ko'tarib ko'ring; macOS'da `cadvisor` target'i `UP` bo'lib, label'lari to'liq bo'lmasa, buni README'da qayd eting.

### Topshirish

Tayyor bo'lgach:
1. `observability/01-prometheus/README.md` da 22 ta vazifaning hammasi `## N. Title` sarlavhasi bilan bor; ofisga qoldirilgan qismlar (6, 7, 8, 17) aniq belgilangan yoki yakunlangan.
2. `observability/stack/` da `compose.yaml`, `prometheus/prometheus.yml`, `prometheus/rules/api.yml`, rule test fayli va `app/` (`Dockerfile` bilan) bor; `.env`, ma'lumot volume'lari va `node_modules` commit qilinmagan.
3. `docker compose config -q` xatosiz, `promtool check config` va `promtool check rules` toza.
4. `make check` toza (YAML lint, Dockerfile lint, secret tekshiruvi).
5. `docker compose down` qilingan, `docker ps` da stack konteynerlari yo'q, `prom-walk` konteyneri ham o'chirilgan.
6. Menga xabar bering, `README.md` va stack fayllarini o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Metrika log'dan nimasi bilan farq qiladi va qaysi savolga javob bera olmaydi?
- Pull modelida target o'lganini Prometheus qanday biladi va push modelida bu nima uchun qiyinroq?
- Time series nima bilan aniqlanadi? Label cardinality nima uchun xotira muammosiga aylanadi?
- `job` va `instance` label'larini kim qo'shadi va nima uchun `/metrics` matnida ular yo'q?
- Counter ustida nima uchun doim `rate()` ishlatiladi va `rate` restart'ni qanday yengadi?
- `increase` nima uchun kasr son qaytarishi mumkin?
- Histogram bucket'lari nima uchun kumulyativ va `histogram_quantile` aniq qiymat emas, taxmin berishining sababi nima?
- Histogram va summary'dan qaysi birini bir nechta replikali servisda tanlaysiz va nima uchun?
- `sum(rate(x[5m]))` va `rate(sum(x)[5m:])` orasidagi farq nima?
- RED va USE qaysi savollarga javob beradi, alert'ni qaysi biridan boshlaysiz?
- Recording rule qachon kerak, qachon ortiqcha?
- `relabel_configs` va `metric_relabel_configs` qaysi bosqichda ishlaydi?
- macOS'da `node-exporter` ko'rsatgan CPU soni va xotira nimaniki va nima uchun?
