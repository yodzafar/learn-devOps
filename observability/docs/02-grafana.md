# 2-dars: Grafana bilan vizualizatsiya

Maqsad: 1-darsdagi PromQL so'rovlarini odam bir qarashda tushunadigan dashboard'ga aylantirish va butun Grafana sozlamasini (data source, dashboard, folder) UI'da qo'lda emas, fayllardan kod sifatida ko'tarish. Grafana ma'lumot saqlamaydi, u data source'larga so'rov yuboradigan va natijani chizadigan qatlam. Shu sabab keyingi darslarda Loki, Tempo va Pyroscope ham aynan shu Grafana'ga data source bo'lib ulanadi, 3-darsda esa alert qoidalari shu yerda ham yoziladi.

Taxminiy vaqt: 2 kun (siz uchun). UI intuitiv, unga ko'p vaqt sarflamang. Diqqatni quyidagilarga qarating: `$__rate_interval` nima uchun kerak, variable'lar ko'p qiymatli bo'lganda so'rov qanday o'zgaradi, provisioning fayllari va data source `uid` ning roli, dashboard dizaynida "yuqoridan pastga: symptom, keyin cause" tartibi.

## Laboratoriya

`observability/stack/` dagi 1-dars stack'i ustida. Yangi servis: `grafana`. Image versiyasini https://github.com/grafana/grafana/releases dan oling. Port `3000`.

```
mkdir -p grafana/provisioning/{datasources,dashboards} grafana/dashboards
docker compose up -d grafana
docker compose logs -f grafana     # provisioning errors show up here
```

Birinchi kirish: `admin` / `admin` (parol almashtirish so'raladi). Admin parolini `GF_SECURITY_ADMIN_PASSWORD` orqali `.env` dan bering, `.env` commit qilinmaydi. Tozalash: `docker compose down`; Grafana volume'ini o'chirsangiz UI'da qo'lda qilingan hamma narsa yo'qoladi, provisioning'dagi narsalar qayta tiklanadi. Bu darsning asosiy g'oyasi ham shu.

---

## 1. Grafana nima va nima emas

- Grafana o'z bazasida (default SQLite, `/var/lib/grafana/grafana.db`) faqat sozlamalarni saqlaydi: dashboard'lar, data source'lar, user'lar, alert qoidalari. Metrika, log va trace'lar data source'da qoladi.
- Har panel ochilganda brauzer Grafana backend'iga, u esa data source'ga so'rov yuboradi (`access: proxy`). Demak brauzer Prometheus'ga to'g'ridan-to'g'ri yeta olishi shart emas, Grafana konteyneri yeta olsa bo'ldi: URL `http://prometheus:9090`, `localhost` emas.
- Sozlash uch qatlamda: `grafana.ini`, uni bosib o'tadigan env o'zgaruvchilar (`GF_<SECTION>_<KEY>`, masalan `GF_SECURITY_ADMIN_PASSWORD`, `GF_AUTH_ANONYMOUS_ENABLED`) va provisioning fayllari.

### Data source
Data source bu ulanish sozlamasi va so'rov muharriri (plugin). Bu modulda: Prometheus, Loki (4-dars), Tempo va Jaeger (5-dars), Pyroscope (6-dars), Alertmanager (3-dars), Elasticsearch (4-dars). Har birining `uid` si bor, dashboard JSON'i data source'ga nom bilan emas, `uid` bilan ishora qiladi.

**Tuzoq: tasodifiy uid.** UI'da yaratilgan data source'ga tasodifiy `uid` beriladi. Shu Grafana'dan eksport qilingan dashboard boshqa muhitda "data source not found" beradi. Provisioning'da `uid` ni o'zingiz belgilang (`uid: prometheus`) va hamma muhitda bir xil saqlang.

## 2. Panel va so'rov

Dashboard panellardan iborat, panel bir yoki bir nechta so'rov (A, B, ...), vizualizatsiya turi va sozlamalardan.

| Vizualizatsiya | Qachon |
|----------------|--------|
| Time series | vaqt bo'yicha o'zgarish: rate, latency, utilization |
| Stat | bitta raqam: joriy error ratio, uptime |
| Gauge, Bar gauge | chegarasi ma'lum qiymat: disk to'lishi |
| Table | ko'p seriyaning joriy qiymati: route bo'yicha top |
| Heatmap | taqsimot: histogram bucket'lari vaqt bo'yicha |
| State timeline | holatlar: `up`, alert holati |
| Logs, Traces, Flame graph | 4–6-darslar |

Panel sozlamalarida eng muhimlari: **Unit** (`s`, `bytes`, `percentunit`, `reqps`; birliksiz grafik yarim ma'lumot), **Legend** (`{{route}}` shabloni bilan, default uzun label ro'yxati emas), **Thresholds** (rang chegarasi), **Min/Max** (foiz uchun 0–1), **Instant** va **Range** so'rov turi (Stat va Table uchun Instant yetadi va arzon).

### $__rate_interval
Grafana vaqt oralig'i va panel kengligiga qarab har nuqta orasidagi qadamni (`$__interval`) tanlaydi. 7 kunlik grafikda qadam bir necha daqiqa, 5 daqiqalik grafikda bir necha soniya bo'ladi. `rate(x[1m])` qat'iy oyna bilan uzoq oraliqda nuqtalar orasidagi ma'lumotni tashlab ketadi, `rate(x[$__interval])` esa qisqa oraliqda scrape interval'dan kichik bo'lib bo'sh natija beradi. `$__rate_interval` ikkalasini hal qiladi: u `max($__interval + scrape interval, 4 × scrape interval)`.

```
sum by (route) (rate(http_requests_total{job="api"}[$__rate_interval]))
```

Buning ishlashi uchun Prometheus data source sozlamasida **Scrape interval** (`jsonData.timeInterval`) haqiqiy qiymatga teng bo'lishi kerak.

### Explore va Drilldown
Explore dashboard'siz so'rov yozish joyi: incident paytida asosiy ish maydoni. Yangi versiyalardagi Drilldown ilovalari (Metrics, Logs, Traces, Profiles) so'rov yozmasdan ko'rib chiqish imkonini beradi. Dashboard oldindan ma'lum savollar uchun, Explore yangi savollar uchun.

## 3. Variables va templating

Variable dashboard tepasidagi ochiladigan ro'yxat, so'rovlarda `$name` yoki `${name}` sifatida ishlatiladi. Bitta dashboard hamma servis, instans yoki muhit uchun ishlaydi.

| Turi | Qiymat manbai |
|------|---------------|
| Query | data source'dan: `label_values(http_requests_total, route)` |
| Custom | qo'lda yozilgan ro'yxat |
| Data source | berilgan turdagi data source'lar ro'yxati |
| Interval | `1m,5m,1h` |
| Ad hoc filters | ixtiyoriy label filtri, hamma so'rovga avtomatik qo'shiladi |

- Zanjir (chained): `label_values(http_requests_total{job="$job"}, route)` avvalgi variable'ga bog'liq.
- **Multi-value** va **Include All** yoqilsa qiymat `a|b|c` regex'iga aylanadi, shuning uchun so'rovda `=` emas `=~` yoziladi: `route=~"$route"`.
- **Repeat**: panel yoki row variable'ning har qiymati uchun takrorlanadi.

**Tuzoq: `=` bilan multi-value.** `route="$route"` bitta qiymatda ishlaydi, ikkita tanlanganda `route="/a|/b"` bo'lib hech narsa topmaydi va panel jimgina bo'sh qoladi.

## 4. Dashboard dizayni

Dashboard savolga javob beradi. "Hamma metrikani bir sahifaga" dashboard emas, shovqin.

- **Servis dashboard'i (RED)**: tepada bir qatorda Stat panellar (so'rov/s, error %, p95), ostida uchta Time series: Rate (route bo'yicha), Errors (ulush, foizda), Duration (p50/p95/p99 yoki heatmap). Foydalanuvchi his qiladigan narsa yuqorida.
- **Resurs dashboard'i (USE)**: har resurs uchun qator: CPU, xotira, disk, tarmoq; har qatorda Utilization, Saturation, Errors.
- Bir xil narsa bir xil rang va birlikda; Y o'qi 0 dan (aks holda kichik tebranish falokat bo'lib ko'rinadi); xato qizil, muvaffaqiyat yashil.
- Dashboard'lar ierarxiyasi: umumiy ko'rinish → servis → instans. Panel yoki dashboard link'lari (data link) bilan bir-biriga o'tiladi, variable qiymati URL orqali uzatiladi.
- Har panelda **Description** (nima o'lchanadi, qachon xavotirlanish kerak). Uch oydan keyin o'zingiz ham eslamaysiz.
- Heatmap histogram uchun: so'rov `sum by (le) (rate(..._bucket[$__rate_interval]))`, format **Heatmap**. Percentile chizig'i yashiradigan ikki cho'qqili taqsimotni ko'rsatadi.

### Community dashboard'lar
https://grafana.com/grafana/dashboards/ da tayyor dashboard'lar bor, ID yoki JSON orqali import qilinadi (Dashboards → New → Import). Eng mashhuri node_exporter uchun "Node Exporter Full" (ID `1860`). Import paytida data source tanlanadi.

**Tuzoq: ko'r-ko'rona import.** Community dashboard muallifning label'lari va exporter versiyasiga yozilgan. Yarmi "No data" chiqsa, panel so'rovini ochib qaysi metrika yoki label yo'qligini ko'ring. 30 panelli dashboard'ni tushunmasdan production'ga qo'yish alert fatigue'ning vizual varianti.

## 5. Provisioning: Grafana kod sifatida

Grafana ishga tushganda `/etc/grafana/provisioning/` ostidagi YAML fayllarni o'qiydi.

```yaml
# provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData: { timeInterval: 15s }
```

```yaml
# provisioning/dashboards/default.yml
apiVersion: 1
providers:
  - name: default
    type: file
    folder: Shop
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
```

- Dashboard provider ko'rsatilgan papkadagi `*.json` fayllarni yuklaydi va o'zgarishlarni kuzatadi. `foldersFromFilesStructure: true` papka tuzilishini Grafana folder'lariga aylantiradi.
- Dashboard JSON'ini olish: dashboard → Export → JSON. Ish tartibi: UI'da tahrirlash → eksport → faylga yozish → commit. Fayl haqiqat manbai.
- Provisioning fayllarida env interpolatsiyasi bor: `$VAR` yoki `${VAR}`; haqiqiy `$` belgisi `$$` deb yoziladi.
- Secret'lar `secureJsonData` da va env'dan: YAML'ga ochiq parol yozilmaydi.
- Provisioning qilingan data source UI'da tahrirlanmaydi (read-only).

**Tuzoq: `allowUiUpdates`.** `false` bo'lsa provisioning qilingan dashboard'ni UI'dan saqlab bo'lmaydi (faqat JSON nusxasini olish taklif qilinadi). `true` bo'lsa saqlanadi, lekin fayl o'zgarmaydi va keyingi yuklashda fayldagi versiya UI'dagi o'zgarishni bosib ketadi. Ikkala holatda ham fayl g'olib.

Kattaroq jamoalarda dashboard'lar Terraform (`grafana` provider) yoki generatorlar (Grafonnet, Grafana Foundation SDK) bilan yaratiladi. Bu modulda fayl provisioning yetarli.

## 6. User, team, folder

- **Organization**: to'liq ajratilgan muhit (o'z data source va dashboard'lari). Ko'pchilikka bitta yetadi.
- **Org rollari**: Viewer (ko'radi), Editor (dashboard yaratadi va tahrirlaydi), Admin (data source, user, team). Alohida **Grafana server admin** butun instansni boshqaradi.
- **Team**: user'lar guruhi. Ruxsat odamga emas, team'ga beriladi.
- **Folder**: dashboard va alert qoidalari konteyneri, ruxsat birligi. "Payments team → `Payments` folder'iga Edit, qolganlarga View".
- **Service account** va uning token'i: avtomatlashtirish (CI, annotation yuborish) uchun. Shaxsiy parol skriptga yozilmaydi.
- Production'da login SSO (OAuth/OIDC, LDAP) orqali, lokal user'lar emas. Anonymous kirish (`GF_AUTH_ANONYMOUS_ENABLED=true`) faqat laboratoriya yoki ichki televizor ekrani uchun, va faqat Viewer roli bilan.

## 7. Annotations

Annotation grafikdagi vaqt belgisi: "shu payt deploy bo'ldi", "shu payt incident boshlandi". Grafikdagi o'zgarishni sababga bog'laydi.

- **Qo'lda**: panelda `Ctrl` (yoki `Cmd`) bosib click, oraliq uchun sudrab belgilash.
- **Query asosida**: dashboard sozlamalari → Annotations, data source'dan so'rov. Masalan jarayon restart'lari: `changes(process_start_time_seconds{job="api"}[1m]) > 0`. 4-darsdan keyin Loki so'rovi bilan ham.
- **API orqali**: CI/CD pipeline deploy paytida `POST /api/annotations` yuboradi (service account token bilan, `tags: ["deploy"]`), dashboard esa shu tag bo'yicha ko'rsatadi. cicd modulidagi deploy job'iga bir qadam qo'shish kifoya.

"Latency qachon o'sdi?" savolidan keyingi savol doim "o'sha payt nima o'zgardi?". Deploy annotation'lari bu savolga soniyada javob beradi.

## Tuzoqlar

- Dashboard'larni faqat UI'da saqlash: volume yo'qolsa yoki boshqa muhit kerak bo'lsa hammasi qaytadan. Fayl va git haqiqat manbai bo'lsin.
- Data source `uid` ni belgilamaslik: dashboard'lar muhitlar orasida ko'chmaydi.
- `rate(x[1m])` qat'iy oyna bilan: uzoq oraliqda cho'qqilar yo'qoladi, qisqa scrape interval o'zgarsa bo'sh grafik. `$__rate_interval` ishlating.
- Multi-value variable bilan `=` matcher: panel jimgina bo'sh.
- Birliksiz va legendasiz panellar: 0.25 nima, soniyami, foizmi?
- Default `admin/admin` parol bilan tarmoqqa ochiq Grafana: data source'lar orqali ichki tizimlarga so'rov yuborish mumkin.
- Anonymous Admin (`GF_AUTH_ANONYMOUS_ORG_ROLE=Admin`): ko'p namuna compose fayllarida bor, laboratoriyadan tashqariga chiqmasin.
- 40 panelli "hamma narsa" dashboard'i: sekin ochiladi, Prometheus'ga har yangilanishda 40+ so'rov, hech kim o'qimaydi.
- Refresh `5s` va oraliq `30d`: har 5 soniyada og'ir so'rovlar. Og'ir ifodalar uchun recording rule (1-dars).
- Qisqa oraliqda o'rtacha, uzoq oraliqda ham o'sha panel: Grafana nuqtalarni siyraklashtiradi, qisqa cho'qqilar 7 kunlik ko'rinishda yo'qoladi. `max_over_time` yoki alohida panel kerak.

## Manbalar

- https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/ – Docker'da ishga tushirish, env sozlamalari
- https://grafana.com/docs/grafana/latest/administration/provisioning/ – data source va dashboard provisioning (majburiy)
- https://grafana.com/docs/grafana/latest/datasources/prometheus/ – Prometheus data source, `$__rate_interval`
- https://grafana.com/docs/grafana/latest/dashboards/variables/ – variables
- https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/ – dashboard dizayni, RED/USE
- https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/annotate-visualizations/ – annotations
- https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/ – rollar va ruxsatlar
- https://grafana.com/docs/grafana/latest/administration/service-accounts/ – service account'lar
- https://grafana.com/grafana/dashboards/ – community dashboard'lar katalogi
- https://grafana.com/blog/2020/09/28/new-in-grafana-7.2-__rate_interval-for-prometheus-rate-queries-that-just-work/ – `$__rate_interval` mexanizmi

---

## Vazifalar

Javoblar `observability/02-grafana/README.md` da (`make new m=observability n=02 name=grafana`), har vazifa uchun `## N. Title` ostida: nima qildingiz, so'rov yoki config'ning muhim qismi, kuzatuv va izoh. Skrinshot kerak bo'lsa shu papkaga qo'ying. Stack fayllari (`grafana/provisioning/...`, `grafana/dashboards/*.json`) `observability/stack/` da.

### A. Birinchi dashboard

1. **Grafana service.** `grafana` servisini compose'ga qo'shing: aniq versiya, named volume, admin paroli `.env` dan. `.env` `.gitignore` da ekanini tekshiring. UI'da Prometheus data source'ni qo'lda qo'shing va **Save & test** natijasini yozing. URL'ga `http://localhost:9090` yozib ko'ring: xato matni nima va nima uchun?

2. **Explore.** Explore'da 1-darsdagi uchta RED so'rovini ishlating. Query inspector'da (Inspect → Query) Grafana Prometheus'ga qaysi `start`, `end`, `step` bilan so'rov yuborganini yozing. Vaqt oralig'ini 5 daqiqadan 24 soatga o'zgartiring: `step` qanday o'zgardi?

3. **Rate interval.** Bitta panelda uchta so'rov chizing: `rate(...[1m])`, `rate(...[$__interval])`, `rate(...[$__rate_interval])`. Oraliqni 5 daqiqa va 24 soat qilib solishtiring. Qaysi biri qachon bo'sh yoki noto'g'ri, sababi nima? Data source'dagi scrape interval sozlamasini noto'g'ri (`1m`) qilib nima o'zgarishini ko'rsating.

4. **RED dashboard.** `api` uchun dashboard yarating: tepada uchta Stat (so'rov/s, error %, p95), ostida Rate (route bo'yicha), Errors (foiz), Duration (p50/p95/p99). Har panelda to'g'ri unit, o'qiladigan legend, description. Error % uchun threshold (masalan 1% sariq, 5% qizil).

5. **Heatmap.** Latency histogram'ini Heatmap panelida chizing. Loadgen'ga sekin so'rovlar guruhini qo'shing (masalan har o'ninchi so'rov 1 soniyadan uzoq endpoint'ga). Heatmap'da ikki cho'qqi ko'rinadimi? p95 chizig'i shu holatni qanday ko'rsatdi, o'rtacha-chi?

### B. Variables

6. **Query variable.** `route` variable'ini `label_values(...)` bilan yarating, Multi-value va Include All yoqilgan. Panellarni shu variable bo'yicha filtrlang. Avval `route="$route"` yozib ikkita qiymat tanlang va nima bo'lishini ko'rsating, keyin tuzating. Query inspector'da variable qanday qiymatga aylanganini yozing.

7. **Chained variables.** `job` va unga bog'liq `instance` variable'larini yarating. `job` o'zgarganda `instance` ro'yxati yangilanishini ko'rsating. Bog'liqlik qaysi so'rov orqali ifodalangan?

8. **Repeat.** Bitta latency panelini `route` variable'i bo'yicha repeat qiling. Route'lar soni 50 ta bo'lsa bu dizayn nimaga olib keladi va o'rniga nima qilgan bo'lardingiz?

### C. USE va community dashboard

9. **Import Node Exporter Full.** ID `1860` dashboard'ni import qiling. "No data" chiqqan kamida ikkita panelni toping, so'rovini ochib sababini aniqlang (yo'q metrika, boshqa label, o'chirilgan collector). Bitta foydali panelning so'rovini tahlil qilib o'z so'zingiz bilan tushuntiring.

10. **USE dashboard.** O'zingiz host uchun ixcham USE dashboard yozing: CPU, xotira, disk, tarmoq uchun utilization va saturation (jami 6–8 panel). Community dashboard'dan nimani oldingiz, nimani ataylab tashladingiz?

11. **Container panel.** cAdvisor metrikalaridan har konteyner CPU va xotirasini ko'rsatadigan Table yoki Bar gauge panel qo'shing (Instant so'rov). `api` konteyneriga compose'da xotira limiti qo'ying va panelda limitga nisbatan foizni ko'rsating.

### D. Provisioning

12. **Datasource as code.** Prometheus data source'ni provisioning fayliga ko'chiring (`uid: prometheus`, scrape interval bilan). Grafana volume'ini o'chirib qayta ko'taring: data source o'zi paydo bo'lishini ko'rsating. UI'da uni tahrirlashga urinib ko'ring: nima bo'ladi?

13. **Dashboards as code.** RED va USE dashboard'larini JSON'ga eksport qilib `grafana/dashboards/` ga qo'ying, provider yozing. Volume'ni yana o'chirib ko'taring: dashboard'lar `Shop` folder'ida paydo bo'lsin. JSON'da `datasource.uid` qanday yozilganini ko'rsating va nima uchun 12-vazifadagi qat'iy `uid` muhimligini izohlang.

14. **Break provisioning.** Uchta xatoni navbat bilan qiling va `docker compose logs grafana` dagi xabarni yozing: data source YAML'ida noto'g'ri indentatsiya; dashboard JSON'ida mavjud bo'lmagan data source `uid`; ikki dashboard faylida bir xil `uid`. Har birida UI'da nima ko'rinadi?

15. **UI edits vs file.** `allowUiUpdates: false` bilan provisioning qilingan dashboard'ni UI'da o'zgartirib saqlashga urining. Keyin `true` qiling, saqlang, Grafana'ni restart qiling. Har ikki holatda o'zgarish nima bo'ldi? Jamoada qaysi tartibni tanlaysiz va nima uchun?

### E. Kirish huquqlari va annotations

16. **Users and folders.** Viewer rolida `viewer1` va Editor rolida `editor1` user yarating, `dev` team'iga `editor1` ni qo'shing. `Shop` folder'iga `dev` team uchun Edit, qolganlarga View bering. Har user bilan kirib (private oynada) nima qila olishini tekshiring: Explore, dashboard tahrirlash, data source ko'rish.

17. **Query annotations.** RED dashboard'ga `api` restart'larini ko'rsatadigan query annotation qo'shing. `docker compose restart api` qiling va grafikda belgi paydo bo'lishini, shu paytda rate grafigida nima ko'ringanini yozing.

18. **Deploy annotation via API.** Service account va token yarating (token `.env` da, commit qilinmaydi). `curl` bilan `deploy` tag'li annotation yuboradigan `annotate.sh` skript yozing (argument: matn). Dashboard'da shu tag bo'yicha annotation'larni yoqing. cicd modulidagi pipeline'ingizga bu qadamni qayerga qo'shgan bo'lardingiz?

19. **Mini-project: Grafana from zero.** `docker compose down -v`, keyin bitta `docker compose up -d`: Grafana admin paroli `.env` dan, Prometheus data source, `Shop` folder'ida RED va USE dashboard'lari (variable'lar va restart annotation bilan) hech qanday qo'lda qadamsiz paydo bo'lsin. `README.md` ga har dashboard qaysi savolga javob berishini va incident paytida qaysi tartibda qarashingizni yozing.

### Topshirish

Tayyor bo'lgach:
1. `docker compose down -v && docker compose up -d` dan keyin hamma narsa provisioning'dan tiklanadi.
2. `make check` toza: `.env` va token'lar repoda yo'q, YAML va shell lint o'tadi.
3. Dashboard JSON'lar `grafana/dashboards/` da, commit'ga tayyor.
4. `docker compose down` qilingan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Grafana metrikalarni qayerda saqlaydi? Grafana volume'i yo'qolsa nima yo'qoladi, nima yo'qolmaydi?
- `$__rate_interval` qaysi ikki muammoni hal qiladi?
- Multi-value variable so'rovda nimaga aylanadi va nima uchun `=~` kerak?
- Data source `uid` ni qo'lda belgilash nima beradi?
- `allowUiUpdates` ning ikkala qiymatida UI'dagi o'zgarish taqdiri qanday?
- RED dashboard'da panellar qaysi tartibda joylashadi va nima uchun?
- Community dashboard'ni import qilishning foydasi va xavfi nima?
- Deploy annotation'lari incident tekshiruvida qaysi savolga javob beradi?
