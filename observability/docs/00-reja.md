# Observability moduli rejasi (metrics, logs, traces, profiles, OpenTelemetry)

Ishlash tartibi: men nazariya va vazifalar beraman, siz stack'ni `compose.yaml` va config fayllar bilan o'zingiz yig'asiz, so'rovlarni (PromQL, LogQL, TraceQL) o'zingiz yozasiz, men tekshirib xatolar, xavfsizlik va idiomalarni ko'rsataman.
Har dars uchun alohida papka: `observability/01-prometheus/`, `observability/02-grafana/` va hokazo. Yaratish: `make new m=observability n=01 name=prometheus`. Bu papkalarda javoblar (`README.md`) turadi; stack'ning o'zi bitta umumiy papkada o'sib boradi: `observability/stack/` (pastda).

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Metrics va alerting | 3 | 11–12 kun | 9 kun | Dashboard va grafik o'qish tanish, Grafana UI tez o'zlashadi. Yangi: pull modeli, time series va label'lar, PromQL (`rate`, `histogram_quantile`), cardinality, Alertmanager routing, SLO burn rate. PromQL qisqartirilmaydi |
| II - Logs, traces, profiles | 3 | 10–11 kun | 8 kun | Structured logging (pino), HTTP header'lar, Chrome DevTools flame chart tanish. Yangi: Loki label modeli, LogQL, context propagation, sampling, continuous profiling |
| III - OpenTelemetry va mini-loyiha | 1 | 5 kun | 4 kun | Node.js'da instrumentation yozish oson. Yangi: Collector pipeline'lari, semantic conventions, uch signalni bitta yo'ldan o'tkazish. Mini-loyiha shu yerda |
| **Jami** | **7** | **5–5.5 hafta** | **4 hafta (21 kun)** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, stack to'xtatilgan va siz mexanizmni o'z so'zingiz bilan tushuntira olasiz. Vaqt yetmasa birinchi qisqaradigan dars: 6-dars (profiling), u holda faqat A va B guruh vazifalari bajariladi.

## Uch ustun va profiling

| Signal | Savol | Ma'lumot shakli | Narxi | Bu moduldagi asbob |
|--------|-------|-----------------|-------|--------------------|
| Metrics | Nima buzildi, qancha, qachondan beri? | Raqamli time series, agregatsiyalangan | Arzon, hajmi so'rovlar soniga emas, series soniga bog'liq | Prometheus |
| Logs | Aynan nima sodir bo'ldi? | Vaqt belgili hodisa yozuvlari | Hajmi trafikka proporsional | Loki, Elasticsearch |
| Traces | Bitta so'rov qaysi servislardan o'tdi, vaqt qayerda ketdi? | Span'lar daraxti | Qimmat, shuning uchun sampling | Tempo, Jaeger |
| Profiles | Qaysi funksiya CPU yoki xotirani yeyapti? | Stack trace namunalari | Past overhead, doimiy yig'iladi | Pyroscope |

Monitoring oldindan ma'lum savollarga javob beradi ("disk to'ldimi?"). Observability oldindan bilinmagan savolni tizimni qayta deploy qilmasdan so'rash imkoni. Signallar alohida emas, o'zaro bog'langanda qiymatga ega: alert metrikadan chiqadi, metrikadagi exemplar trace'ga, trace `trace_id` orqali log'ga, span profilga olib boradi. Modul shu zanjirni qurish bilan tugaydi.

## Laboratoriya

- Barcha vazifalar ish mashinasidagi Docker Compose'da bajariladi. Ish mashinasiga hech narsa o'rnatilmaydi: `promtool`, `amtool`, `logcli` kabi CLI'lar tegishli konteyner ichidan (`docker compose exec`) ishlatiladi.
- **Yagona stack papkasi**: `observability/stack/`. Ichida `compose.yaml`, har komponent uchun config papkasi (`prometheus/`, `grafana/`, `alertmanager/`, `loki/`, `alloy/`, `tempo/`, `otelcol/`) va namuna ilova (`app/`). Har dars shu stack'ga servis qo'shadi, oldingisini buzmaydi:

| Dars | Stack'ga qo'shiladi |
|------|---------------------|
| 1 | `api` (namuna ilova, Node.js yoki Go), `loadgen`, `prometheus`, `node-exporter`, `cadvisor` |
| 2 | `grafana` (provisioning bilan) |
| 3 | `alertmanager`, webhook qabul qiluvchi, Grafana Alerting qoidalari |
| 4 | `loki`, `alloy`; `logs-es` profilida `elasticsearch`, `kibana` |
| 5 | `inventory` (ikkinchi servis), `tempo`; `jaeger` profilida `jaeger` |
| 6 | `pyroscope` |
| 7 | `otelcol` (OpenTelemetry Collector), yakuniy tozalash va mini-loyiha |

- Og'ir servislar (Elasticsearch, Kibana, Jaeger) Compose `profiles` ostida turadi va faqat kerak bo'lganda yoqiladi. To'liq stack taxminan 3–4 GB RAM oladi, Elasticsearch yoqilganda yana 1–2 GB. `docker stats` bilan kuzating.
- Image versiyalari: `latest` ishlatilmaydi. Har komponent uchun release sahifasidan joriy barqaror versiyani olib, `compose.yaml` da aniq tag bilan yozasiz. Darslarda versiya raqami ataylab berilmagan, chunki bu asboblar tez o'zgaradi.
- `node-exporter` va `cadvisor` host fayl tizimini faqat o'qish uchun mount qiladi, `alloy` esa `docker.sock` ni. Bu ish mashinasini o'zgartirmaydi, lekin `docker.sock` ga kirish amalda root huquqi ekanini eslang (docker moduli, 1-dars).
- Secret'lar (Telegram bot token, Grafana admin paroli) `.env` yoki alohida faylda, `.gitignore` da. `compose.yaml` va config'lar commit qilinadi, secret va ma'lumot volume'lari yo'q.
- Har mashg'ulot oxirida `docker compose down` (volume'lar qoladi), modul oxirida `docker compose down -v` va `docker volume ls` bilan tekshirish.

## I bosqich - Metrics va alerting

1. **Prometheus**: pull modeli, time series va label'lar, metrika turlari (counter, gauge, histogram, summary), exposition format, `prometheus.yml` va scrape config, node_exporter va cAdvisor, ilovani client library bilan instrumentatsiya qilish, PromQL (selector, `rate`/`irate`, agregatsiya, `histogram_quantile`), recording rules, cardinality, retention, RED va USE metodlari
2. **Grafana**: data source, panel turlari, variables va templating, RED/USE uchun dashboard dizayni, community dashboard import, dashboard va data source'larni kod sifatida provisioning, user/team/folder asoslari, annotations
3. **Alerting**: Prometheus alerting rules (`for`, labels, annotations), Alertmanager routing tree, grouping, inhibition, silence, receiver'lar (webhook, Telegram, Slack, email), symptom-based alerting, SLO va error budget burn rate, alert fatigue, runbook, Grafana Alerting va Alertmanager taqqosi, on-call tushunchalari (rotation, escalation), Grafana OnCall holati

## II bosqich - Logs, traces, profiles

4. **Logging**: structured logging va log level'lar, Loki arxitekturasi, label va full-text index farqi, Grafana Alloy bilan yig'ish (Promtail EOL), LogQL (stream selector, filter, parser, metric query), Elasticsearch/ELK/OpenSearch (inverted index, shard, Filebeat/Logstash, Kibana), Loki va Elasticsearch taqqosi, retention va narx
5. **Tracing**: span va trace, context propagation (W3C `traceparent`), head va tail sampling, bir-birini chaqiradigan ikki servisni instrumentatsiya qilish, Jaeger all-in-one, Tempo va Grafana, TraceQL asoslari, exemplar va trace-to-logs bog'lanishi
6. **Profiling**: continuous profiling, CPU va memory profillari, flame graph o'qish, pull va push (SDK) rejimlari, Pyroscope, namuna ilovani profillash, yashirilgan hot path'ni topish, overhead

## III bosqich - OpenTelemetry va mini-loyiha

7. **OpenTelemetry**: API/SDK/OTLP/Collector, signallar va ularning holati (traces, metrics, logs, profiles), auto va manual instrumentation, Collector pipeline'lari (receiver, processor, exporter), semantic conventions, resource attributes, hamma signalni ilovadan Collector orqali Prometheus/Loki/Tempo'ga yo'naltirish. Mini-loyiha: to'liq stack bitta `compose.yaml` da kod sifatida, dashboard va alert'lar, simulyatsiya qilingan incident'ni alert → metrics → logs → trace → profile zanjiri bo'yicha tekshirish

## Yakuniy natija

Moduldan keyin siz:

- Servis uchun qaysi metrikalar kerakligini RED va USE bo'yicha aniqlab, ularni ilovaga qo'sha olasiz va PromQL bilan rate, error ratio, percentile hisoblaysiz.
- Prometheus, Grafana, Alertmanager, Loki, Tempo, Pyroscope va OpenTelemetry Collector'dan iborat stack'ni noldan, to'liq kod sifatida (compose + config + provisioning) ko'tara olasiz.
- Symptom-based alert yozib, uni to'g'ri odamga, to'g'ri guruhlab, runbook havolasi bilan yetkazasiz; alert fatigue sabablarini ko'ra olasiz.
- Label cardinality nima uchun Prometheus va Loki'ni o'ldirishini tushuntirib, uni o'lchay olasiz.
- Incident'da alert'dan boshlab metrika, log, trace va profil orqali sababgacha yetib borasiz va buni postmortem shaklida yoza olasiz.
- Kubernetes modulida shu stack'ni klasterda (kube-prometheus-stack, Alloy DaemonSet) ko'rganda har komponent nima qilishini bilasiz.

## Ataylab kiritilmagan

- Kubernetes'dagi monitoring (Prometheus Operator, ServiceMonitor, kube-state-metrics): `kubernetes` modulida.
- Uzoq muddatli va gorizontal masshtablanadigan metrics saqlash (Thanos, Grafana Mimir, VictoriaMetrics): faqat 1-darsda "qachon kerak bo'ladi" darajasida.
- Tijoriy SaaS platformalar (Datadog, New Relic, Dynatrace, Grafana Cloud) amaliyoti. Tushunchalar bir xil, interfeys boshqa.
- Grafana OnCall amaliyoti: OSS loyiha arxivlangan (3-dars, 7-bo'lim), on-call faqat tushuncha darajasida.
- eBPF asosidagi kuzatuv (Beyla/OBI, Pixie, Cilium Hubble), RUM va frontend monitoring (Faro, Sentry), synthetic monitoring (Blackbox exporter 3-darsda faqat tilga olinadi).
- ELK'ni production darajasida boshqarish (ILM, cluster sizing, xavfsizlik): 4-darsda faqat single-node tanishuv.

## Manbalar

- Beyer va boshq., "Site Reliability Engineering" (sre.google/sre-book): 6-bob "Monitoring Distributed Systems" (four golden signals), bepul onlayn
- Beyer va boshq., "The Site Reliability Workbook" (sre.google/workbook): "Alerting on SLOs" bobi, 3-dars uchun majburiy
- Brazil, "Prometheus: Up & Running" (2-nashr, Pivovarov bilan): I bosqich uchun asosiy kitob
- Majors, Fong-Jones, Miranda, "Observability Engineering": tushunchalar va madaniyat
- Gregg, "Systems Performance" (2-nashr): USE metodi va flame graph'lar (brendangregg.com)
- Rasmiy hujjatlar: prometheus.io/docs, grafana.com/docs (Grafana, Loki, Alloy, Tempo, Pyroscope), opentelemetry.io/docs, jaegertracing.io/docs, elastic.co/docs
- W3C Trace Context spetsifikatsiyasi (w3.org/TR/trace-context)
