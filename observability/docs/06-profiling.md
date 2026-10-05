# 6-dars: Continuous profiling

Maqsad: "qaysi servis sekin" degan savoldan "qaysi funksiya, qaysi qator CPU yoki xotirani yeyapti" degan savolga o'tish. Trace vaqt qaysi servisda va qaysi span'da ketganini ko'rsatadi, lekin span ichida nima bo'layotganini ko'rsatmaydi; profil aynan shu bo'shliqni to'ldiradi. Bu darsda profiling qanday ishlashini (stack sampling), flame graph'ni qanday o'qishni, profilni production'da doimiy yig'ish (continuous profiling) nima berishini o'rganasiz, Pyroscope'ni stack'ga qo'shasiz va namuna ilovaga yashirilgan hot path'ni topasiz. 7-darsdagi incident tekshiruvining oxirgi bo'g'ini shu.

Taxminiy vaqt: 2 kun (siz uchun). Chrome DevTools Performance paneli sizga tanish, lekin flame graph undagi flame chart emas, farqiga e'tibor bering. Diqqatni quyidagilarga qarating: sampling qanday ishlaydi va nima uchun arzon, flame graph'da kenglik nimani anglatadi (vaqt o'qi emas), self va total, CPU va wall-clock profil farqi, ikki davrni solishtirish (diff).

## Laboratoriya

`observability/stack/` ustida. Yangi servis: `pyroscope` (port `4040`, versiya: https://github.com/grafana/pyroscope/releases ). Profillar ilovadan SDK orqali (push) yoki Alloy orqali (pull, Go uchun) keladi; Alloy 4-darsdan beri stack'da.

```
docker compose up -d pyroscope
curl -s localhost:4040/ready
```

Yuklama uchun 1-darsdagi `loadgen` yetadi, ba'zi vazifalarda uni vaqtincha kuchaytirasiz. CPU'ni to'liq band qiladigan vazifalarda `api` konteyneriga compose'da CPU limiti qo'ying (docker moduli), aks holda ish mashinasi sekinlashadi. eBPF asosidagi profiling host'ga privileged kirish talab qiladi, shuning uchun bu darsda faqat nazariy. Tozalash: `docker compose down`.

---

## 1. Profiling nima

### Sampling
Profiler jarayonni to'xtatib har funksiyani o'lchamaydi (bu juda qimmat bo'lardi). U ma'lum chastotada, odatda soniyasiga 100 marta, "hozir qaysi stack bajarilyapti" deb qaraydi va ko'rgan stack trace'ni sanaydi. 10 soniyada 1000 namunadan 300 tasida stack tepasida `JSON.parse` turgan bo'lsa, CPU vaqtining taxminan 30% i o'sha yerda. Natija statistik: kam chaqiriladigan tez funksiya namunaga tushmasligi mumkin, lekin CPU'ni yeyayotgan narsa albatta ko'rinadi.

Shu sabab overhead past va trafikka emas, sampling chastotasiga bog'liq. Buni production'da doimiy yoqib qo'yish mumkin.

### Profil turlari
| Tur | Nimani o'lchaydi | Qaysi savolga javob |
|-----|------------------|----------------------|
| CPU | CPU'da bajarilayotgan vaqt | nima hisoblayapti? |
| Wall-clock | o'tgan real vaqt, kutish ham kiradi | nima sekin (CPU yoki I/O kutish)? |
| Heap: in-use | hozir xotirada turgan obyektlar | xotirani nima ushlab turibdi (leak)? |
| Heap: alloc | davr ichidagi barcha ajratishlar | GC'ni nima band qilyapti? |
| Goroutine, mutex, block (Go) | goroutine'lar, lock kutish | nima bloklanib turibdi? |

Til bo'yicha farq bor: Go runtime'ida hammasi o'rnatilgan (`pprof`). Pyroscope'ning Node.js SDK'si wall va heap profillarini beradi, CPU vaqtini wall profilga qo'shish alohida yoqiladi (`wall.collectCpuTime`).

**Tuzoq: CPU profilda I/O ko'rinmaydi.** So'rov sekin, lekin sababi DB yoki tashqi servisni kutish bo'lsa, CPU profil deyarli bo'sh chiqadi: kutayotgan kod CPU ishlatmaydi. Bu holatda trace (5-dars) yoki wall-clock profil kerak. Profil "CPU va xotira qayerda", trace "vaqt qayerda".

### Bir martalik va continuous profiling
Bir martalik profiling: muammo bo'lganda serverga kirib 30 soniya profil olish. Kamchiligi: muammo allaqachon o'tib ketgan, "odatda qanday edi" bilan solishtirib bo'lmaydi. Continuous profiling har instansdan doimiy, past chastotada profil yig'ib, vaqt belgisi va label'lar bilan markaziy joyda saqlaydi. Natijada: incident vaqtini keyin ochib ko'rish, deploy'dan oldin va keyingi holatni solishtirish, "CPU xarajatining qancha foizi qaysi funksiyada" degan savolga butun flot bo'yicha javob.

## 2. Flame graph o'qish

Flame graph minglab stack trace'ning yig'ilgan ko'rinishi.

- Har to'rtburchak bitta funksiya (stack frame).
- **Vertikal** o'q stack chuqurligi: funksiya ustidagi (yoki Grafana'dagi kabi teskari "icicle" ko'rinishda ostidagi) to'rtburchaklar u chaqirgan funksiyalar. Root bitta, butun kenglikda.
- **Kenglik** shu funksiya stack'da bo'lgan namunalar ulushi. Keng degani ko'p vaqt (yoki ko'p xotira).
- **Gorizontal tartib vaqt emas.** Bir xil stack'lar birlashtiriladi va alifbo bo'yicha tartiblanadi. Chapdagi narsa oldin bo'lgan degani emas.
- Rang odatda ma'no tashimaydi (yoki paket bo'yicha guruhlaydi).

| Tushuncha | Ma'nosi |
|-----------|---------|
| Total (cumulative) | funksiya va u chaqirgan hamma narsa |
| Self (flat) | faqat funksiyaning o'z kodi, bolalarsiz |

O'qish tartibi: eng keng "minoralar"ni toping, ular bo'ylab chaqiruv yo'nalishida yuring va kenglik bolalarga bo'linmay tugaydigan joyni toping. O'sha frame'ning self vaqti katta: CPU aynan shu yerda yonyapti. `handleRequest` keng bo'lishi yangilik emas (u hamma narsani chaqiradi), muhimi qaysi bola uni keng qilgani.

Pyroscope va Grafana'dagi qo'shimcha ko'rinishlar: **Top table** (self bo'yicha saralangan funksiyalar ro'yxati), **Sandwich** (tanlangan funksiyani kim chaqiradi va u kimni chaqiradi: bitta util funksiya yuz joydan chaqirilganda foydali), **Diff** (ikki davr yoki ikki label to'plami farqi: nima ko'paydi, nima kamaydi).

**Tuzoq: flame chart bilan adashtirish.** Chrome DevTools'dagi flame chart'da X o'qi vaqt, chaqiruvlar ketma-ket ko'rinadi. Flame graph'da X o'qi agregatsiya. Flame graph'dan "avval A, keyin B chaqirilgan" degan xulosa chiqarib bo'lmaydi.

## 3. Pyroscope

Grafana Pyroscope profillar bazasi: profillarni qabul qiladi, label'lar bilan saqlaydi (Loki va Tempo kabi, katta hajmda object storage'da), so'rovga flame graph qaytaradi. Bitta binary, port `4040`, o'z UI'si ham bor. Grafana'da data source turi `grafana-pyroscope-datasource`; ko'rish Explore, Profiles Drilldown yoki dashboard'dagi Flame graph paneli orqali.

Profil seriyasi profil turi va label'lar bilan tanlanadi: `{service_name="api"}`. Label'lar Prometheus'dagi kabi: `service_name`, `env`, `version`, `instance`. Cardinality qoidasi ham o'sha.

### Profil yuborish usullari
| | SDK (push) | Alloy `pyroscope.scrape` (pull) | Alloy `pyroscope.ebpf` |
|---|---|---|---|
| Qanday | ilova ichidagi kutubxona profil yig'ib yuboradi | Alloy ilovaning pprof HTTP endpoint'larini scrape qiladi | yadro darajasida butun host stack'larini yig'adi |
| Kod o'zgarishi | bor (init kodi) | Go'da `net/http/pprof` import | yo'q |
| Tillar | Go, Java, Python, Ruby, Node.js, .NET, Rust | asosan Go | kompilyatsiya qilinadigan tillar yaxshi, qolganlari cheklangan |
| Qo'shimcha | dinamik label'lar (kod bo'lagi bo'yicha) | target'lar service discovery'dan, Prometheus'dagi kabi | root huquqi, Linux |

Node.js (push):

```js
const Pyroscope = require('@pyroscope/nodejs');
Pyroscope.init({
  serverAddress: 'http://pyroscope:4040',
  appName: 'api',
  tags: { env: 'lab' },
});
Pyroscope.start();
```

Go (pull) uchun Alloy:

```alloy
pyroscope.scrape "api" {
  targets    = [{"__address__" = "api:8000", "service_name" = "api"}]
  forward_to = [pyroscope.write.local.receiver]
}
pyroscope.write "local" {
  endpoint { url = "http://pyroscope:4040" }
}
```

`pyroscope.scrape` default holatda `/debug/pprof/` ostidagi CPU, xotira, goroutine, mutex, block profillarini 15 soniyada bir oladi. Go'da push ham mumkin: `github.com/grafana/pyroscope-go` (`pyroscope.Start(pyroscope.Config{...})`).

### Qaysi rejimni tanlash
- Bitta til, kodga kira olasiz, endpoint yoki kod bo'lagi bo'yicha label kerak: SDK (push).
- Go servislar parki, Prometheus uslubidagi service discovery allaqachon bor: pull. Ilova Pyroscope manzilini bilmaydi, profil yig'ish markazdan yoqiladi va o'chiriladi.
- Kodni o'zgartirib bo'lmaydi yoki butun node'ning (jumladan begona jarayonlar va yadro) manzarasi kerak: eBPF. Kubernetes'da DaemonSet sifatida keng ishlatiladi; talqin qilinadigan tillarda stack'lar to'liq chiqmasligi mumkin.

### Label'lar va diff
Statik label'lar (`version`, `env`) deploy'larni solishtirish imkonini beradi: `version="1.4.0"` va `version="1.5.0"` diff'i regressiyani aniq funksiyagacha ko'rsatadi. Dinamik label'lar kod bo'lagini belgilaydi (Node.js'da `Pyroscope.wrapWithLabels({ route: 'report' }, fn)`), shunda "faqat shu endpoint'ning profili"ni ajratish mumkin.

### Trace bilan bog'lash
Span profiles: profil namunalariga span ID biriktiriladi va Grafana'da trace span'idan "shu span davomidagi profil"ga o'tiladi (Tempo data source'idagi traces to profiles sozlamasi). Qo'llab-quvvatlash tilga bog'liq, hujjatdan tekshiring. Bu modulda qo'lda bog'lash yetadi: trace'dan vaqt oralig'i va servisni olib, Pyroscope'da shu oraliqni ochasiz.

## 4. Tahlil amaliyoti

- **CPU hot path**: Top table'da self bo'yicha birinchi qatorlar, keyin flame graph'da kontekst (kim chaqiryapti). Tipik topilmalar: sikl ichida qayta-qayta serializatsiya (`JSON.stringify`/`JSON.parse`), sikl ichida kompilyatsiya qilinadigan regex, O(n²) qidiruv, keraksiz nusxalash, sinxron kriptografiya, haddan ortiq logging.
- **Xotira**: in-use profil vaqt o'tishi bilan faqat o'sayotgan bo'lsa leak: qaysi funksiya ajratgan obyektlar ushlab turilganini ko'rsatadi (kim ushlab turganini emas). Alloc profil keng bo'lsa GC bosimi: qisqa umrli obyektlarni kamaytirish kerak.
- **Node.js o'ziga xosligi**: bitta event loop. CPU'ni band qilgan sinxron funksiya faqat o'z so'rovini emas, shu paytdagi hamma so'rovni kutdiradi. Belgisi: hamma route'da latency birdan o'sadi, event loop lag metrikasi (1-dars, default metrikalar) ko'tariladi, flame graph'da bitta keng minora.
- **Optimizatsiya tartibi**: o'lcha → eng keng joyni top → bitta narsani o'zgartir → diff bilan tasdiqla. Profilsiz optimizatsiya taxmin, va taxmin odatda noto'g'ri joyni ko'rsatadi.

### Overhead
Sampling profiler narxi past, lekin nol emas: har namunada stack yig'iladi, profil siqiladi va tarmoqqa yuboriladi. U sampling chastotasi, stack chuqurligi va yoqilgan profil turlari soniga bog'liq (mutex va block profillari Go'da qimmatroq, sozlanadi). Umumiy raqamga ishonmang: 1-darsdagi CPU va latency metrikalari bilan profiler yoqilgan va o'chirilgan holatni o'zingiz o'lchang. Profiler env orqali o'chiriladigan bo'lsin.

Profil ma'lumoti funksiya va fayl nomlarini ochadi (ichki tuzilma), ba'zan label orqali boshqa ma'lumotni ham. Pyroscope endpoint'i va Go'ning `/debug/pprof` i tashqi tarmoqqa ochilmaydi.

## Tuzoqlar

- Flame graph'da X o'qini vaqt deb o'qish: tartib alifbo bo'yicha, ketma-ketlik emas.
- Total'i katta, self'i nol funksiyani "aybdor" deb topish: `main` yoki router doim keng. Self'ga va barglarga qarang.
- CPU profildan I/O kutishni qidirish: ko'rinmaydi. Trace yoki wall-clock profil kerak.
- Bitta instansning 10 soniyalik profilidan butun tizim haqida xulosa: sampling statistik, qisqa namuna shovqinli. Uzoqroq oraliq va bir nechta instansni yig'ing.
- Yuklamasiz profil olish: idle jarayon profili runtime'ning o'z ishini (GC, timer'lar) ko'rsatadi, sizning muammoingizni emas.
- Minify yoki bundle qilingan kod: funksiya nomlari o'qilmaydi. Server kodini profil uchun o'qiladigan holda saqlang yoki source map qo'llab-quvvatlanishini tekshiring.
- `/debug/pprof` ni asosiy port bilan birga internetga ochish: ichki ma'lumot sizib chiqadi va profil so'rovi bilan servisni yuklash mumkin.
- Profil label'larida yuqori cardinality (`user_id`, `request_id`): Prometheus va Loki'dagi muammoning aynan o'zi.
- Optimizatsiyadan keyin o'lchamaslik: diff'siz "tezlashdi" degan gap tasdiqlanmagan.
- Mikro-optimizatsiya: flame graph'da 1% egallagan funksiyani ikki barobar tezlashtirish 0.5% beradi. Avval eng keng joy.

## Manbalar

- https://grafana.com/docs/pyroscope/latest/introduction/ – continuous profiling tushunchalari
- https://grafana.com/docs/pyroscope/latest/introduction/flamegraphs/ – flame graph o'qish (majburiy)
- https://grafana.com/docs/pyroscope/latest/introduction/profiling-types/ – profil turlari
- https://grafana.com/docs/pyroscope/latest/get-started/ – Pyroscope'ni ishga tushirish
- https://grafana.com/docs/pyroscope/latest/configure-client/language-sdks/nodejs/ – Node.js SDK
- https://grafana.com/docs/pyroscope/latest/configure-client/language-sdks/go_push/ – Go SDK (push)
- https://grafana.com/docs/alloy/latest/reference/components/pyroscope/pyroscope.scrape/ – Alloy bilan pull
- https://grafana.com/docs/pyroscope/latest/configure-client/trace-span-profiles/ – span profiles
- https://www.brendangregg.com/flamegraphs.html – flame graph muallifidan
- https://pkg.go.dev/net/http/pprof – Go pprof endpoint'lari
- https://nodejs.org/en/learn/diagnostics/flame-graphs – Node.js'da flame graph

---

## Vazifalar

Javoblar `observability/06-profiling/README.md` da (`make new m=observability n=06 name=profiling`), har vazifa uchun `## N. Title` ostida: nima qildingiz, flame graph'dan o'qilgan aniq raqamlar (funksiya nomi, self va total foizi), izoh. Flame graph skrinshotlarini shu papkaga qo'ying. Stack o'zgarishlari `observability/stack/` da.

### A. Pyroscope va birinchi profil

1. **Pyroscope service.** `pyroscope` servisini qo'shing (aniq versiya, named volume). Grafana'ga Pyroscope data source'ni provisioning bilan qo'shing. Pyroscope o'zini profillaydi: Grafana Explore'da uning CPU profilini oching va qaysi profil turlari borligini yozing.

2. **Profile the app.** `api` ni profillang: Node.js bo'lsa SDK (push), Go bo'lsa `net/http/pprof` va Alloy `pyroscope.scrape` (pull). Server manzili va yoqish/o'chirish env orqali bo'lsin. Loadgen ishlab turgan holda `api` ning flame graph'ini oching. Root'dan boshlab eng keng yo'lni yozing: qaysi frame'lar sizning kodingiz, qaysilari runtime yoki framework?

3. **Idle vs loaded.** Loadgen'ni to'xtatib 3 daqiqa kuting, keyin yoqing. Ikki davrning flame graph'ini solishtiring. Idle profilda nima ko'rinadi va nima uchun undan xulosa chiqarib bo'lmaydi?

4. **Self vs total.** Top table'ni self bo'yicha, keyin total bo'yicha saralang. Har ro'yxatning birinchi beshtasini yozing. Nima uchun ikki ro'yxat butunlay boshqacha? Qaysi biri "qayerni optimizatsiya qilish kerak" degan savolga javob beradi?

5. **Break the push.** Profil manzilini noto'g'ri qiling (yoki Pyroscope'ni to'xtating). Ilova ishlashda davom etadimi, log'da nima chiqadi? Pyroscope qaytgach profillar tiklanadimi, oradagi davr nima bo'ldi?

### B. CPU hot path

6. **Plant a hot path.** `api` ga `GET /report` endpoint qo'shing: ataylab samarasiz kod, masalan 2000 elementli massivni sikl ichida har iteratsiyada to'liq JSON'ga aylantirib qayta parse qilish, yoki sikl ichida regex kompilyatsiya qilish. Kod ishlasin va to'g'ri natija qaytarsin, faqat sekin bo'lsin. Loadgen'ga shu endpoint'ni kam chastotada qo'shing.

7. **Find it in the flame graph.** Kodga qaramasdan, faqat Pyroscope orqali hot path'ni toping: qaysi funksiya, self va total ulushi qancha, kim chaqiryapti. Sandwich ko'rinishida shu funksiyaning chaqiruvchilarini ko'rsating. Flame graph'dan yo'lni `README.md` ga stack sifatida yozing.

8. **Blast radius.** `/report` so'rovlari ketayotgan paytda `/products` ning p95 latency'si va `api` konteyneri CPU'sini 2-darsdagi dashboard'da kuzating. Node.js'da event loop lag metrikasini, Go'da goroutine sonini ham. Bitta sekin endpoint boshqalarga ta'sir qildimi? Node.js va Go'da javob nima uchun farq qiladi?

9. **Trace vs profile.** Bitta sekin `/report` so'rovining trace'ini Tempo'da oching. Trace nimani ko'rsatdi, nimani ko'rsata olmadi? Xuddi shu vaqt oralig'ining profilini oching. Ikki signal qaysi nuqtada bir-birini to'ldiradi?

10. **Fix and diff.** Hot path'ni tuzating (natija o'zgarmasin). Ilovaga `version` label'ini qo'shing va tuzatishdan oldin hamda keyingi versiyalarni Pyroscope diff ko'rinishida solishtiring. Qaysi frame'lar kamaydi, foizda qancha? `/report` latency'si va CPU metrikalarida ham tasdiqlang.

11. **Labels per route.** Dinamik label bilan (Node.js: `wrapWithLabels`, Go: SDK'dagi tag wrapper yoki `pprof.Do`) `/report` handler'ini belgilang. Faqat shu label'li profilni ajratib oching. Nima uchun bu yerda `route` label bo'lishi mumkin, `request_id` esa yo'q?

### C. Xotira

12. **Plant a leak.** `api` ga yashirin leak qo'shing: har `/products` so'rovida global massiv yoki map'ga hech qachon tozalanmaydigan obyekt qo'shilsin. 10 daqiqa yuklama bering. `container_memory_working_set_bytes` va runtime heap metrikasi grafigini ko'rsating.

13. **Find the leak.** Heap in-use profilini oching va ajratuvchi funksiyani toping. Ikki vaqt nuqtasini diff bilan solishtiring: nima o'sdi? Profil "kim ajratgan"ni ko'rsatadi, "kim ushlab turibdi"ni emas: bu sizning holatingizda qanday namoyon bo'ldi?

14. **OOM and limits.** `api` ga kichik xotira limiti qo'ying va leak bilan ishlating. Konteyner o'lganda `docker inspect` dagi holatni (`OOMKilled`), restart'dan keyingi xotira grafigini va 3-darsdagi alert'lardan qaysi biri ishlaganini yozing. Limitga yaqinlashishni oldindan aytadigan alert ifodasini yozing (`predict_linear` yoki limitga nisbat). Leak'ni tuzating.

15. **Allocation churn.** Alloc profilini (yoki Node.js'da heap profil va GC metrikalarini) oching: qaysi funksiya eng ko'p qisqa umrli obyekt yaratadi? In-use va alloc profillari farqini shu misolda tushuntiring.

### D. Narx va yakun

16. **Measure overhead.** Bir xil yuklama bilan ikki marta 5 daqiqadan o'lchang: profiler o'chiq va yoqiq. `api` CPU'si (cAdvisor), p95 latency va so'rov/s ni jadvalga yozing. Farq o'lchov shovqinidan kattami? Sampling chastotasi yoki profil turlarini o'zgartirish imkoni bo'lsa, bittasini sinang.

17. **Pull vs push.** O'z ilovangizda ishlatmagan rejim uchun (push yoki pull) hujjat asosida yozing: nima sozlanadi, target'lar qayerdan olinadi, qaysi holatda afzal. eBPF profiling nima uchun bu laboratoriyada qilinmaganini va qachon ishlatilishini 3–4 gapda tushuntiring.

18. **Mini-project: profile-driven fix.** Ikkala muammoni (hot path va leak) qaytaring va yangi odam o'rnida tekshiring: 3-darsdagi latency alert'i → dashboard (qaysi route, CPU, xotira) → trace (span ichida nima noma'lum) → profil (funksiya). `README.md` da qisqa hisobot: belgi, har signal nima dedi, sabab (funksiya nomi va ulushi), tuzatish, diff va metrikalardagi natija. Profillash panelini (Flame graph) RED dashboard'ga qo'shib provisioning'ni yangilang.

### Topshirish

Tayyor bo'lgach:
1. Hot path va leak tuzatilgan, tuzatishdan oldingi va keyingi diff skrinshotlari papkada.
2. Pyroscope data source va yangilangan dashboard provisioning'da.
3. `make check` toza.
4. `api` dagi vaqtinchalik CPU/xotira limitlari ongli qiymatga qaytarilgan, `docker compose down` qilingan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Sampling profiler qanday ishlaydi va nima uchun uni production'da doimiy yoqib qo'yish mumkin?
- Flame graph'da kenglik va gorizontal tartib nimani anglatadi? Flame chart'dan farqi nima?
- Self va total vaqt farqi nima, qaysi biriga qarab optimizatsiya joyini tanlaysiz?
- So'rov DB'ni kutib sekinlashgan bo'lsa CPU profil nima ko'rsatadi va qaysi signal kerak?
- Continuous profiling bir martalik profiling'dan nimasi bilan ustun?
- In-use va alloc heap profillari qaysi muammolarni ko'rsatadi?
- Pull, push va eBPF rejimlarini qachon tanlaysiz?
- Trace va profil bir-birini qayerda to'ldiradi?
