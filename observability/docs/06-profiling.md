# 6-dars: Continuous profiling

Maqsad: "qaysi servis sekin" degan savoldan "qaysi funksiya, qaysi qator CPU yoki xotirani yeyapti" degan savolga o'tish. Metrika (observability 1-dars) servis sekinlashganini yoki xotira o'sayotganini aytadi, trace (observability 5-dars) vaqt qaysi servisda va qaysi span'da ketganini ko'rsatadi, lekin span ichida nima bo'layotganini hech biri ko'rsatmaydi. Profil aynan shu bo'shliqni to'ldiradi. Bu darsda profiling qanday ishlashini (stack sampling), namunalar qanday qilib flame graph'ga aylanishini va uni qanday o'qishni, profilni production'da doimiy yig'ish (continuous profiling) nima berishini noldan o'rganasiz, Pyroscope'ni stack'ga qo'shasiz va namuna ilovaga yashirilgan hot path'ni topasiz. 7-darsdagi incident tekshiruvining (alert, metrika, log, trace, profil) oxirgi bo'g'ini shu.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar, "Birga bajaramiz" va A guruh vazifalari; ikkinchi kun 4–5 bo'limlar va B guruhi; uchinchi kun 6-bo'lim, C va D guruhlari, README'ni tartibga solish. Diqqatni quyidagilarga qarating: sampling qanday ishlaydi va nima uchun arzon, flame graph'da kenglik nimani anglatadi (vaqt o'qi emas), self va total, CPU va wall-clock profil farqi, ikki davrni solishtirish (diff). Modul rejasiga ko'ra vaqt yetmasa shu dars qisqaradi: u holda nazariyani to'liq o'qing, vazifalardan faqat A va B guruhlarini bajaring.

Qanday o'qish kerak: 3-bo'limdagi flame graph misolini qog'ozda yoki muharrirda o'zingiz qayta hisoblang (namunalarni sanang, kengliklarni tekshiring), keyin "Birga bajaramiz" ni terib ishga tushiring. Sizdagi raqamlar (namunalar soni, foizlar, runtime ichki funksiyalari nomi) darsdagidan farq qiladi, bu normal; bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker Compose'da, umumiy `observability/stack/` papkasi ustida bajariladi (stack 2G'li `lab` VM'ga sig'maydi). Host'ga hech narsa o'rnatilmaydi: profiler ilova konteynerining ichida ishlaydi, profillar bazasi alohida konteynerda. Bu darsda stack'ga bitta yangi servis qo'shiladi:

| Servis | Vazifasi | Port | Versiya qayerdan |
|--------|----------|------|------------------|
| `pyroscope` | profillarni qabul qiladi, saqlaydi, flame graph qaytaradi | `4040` | https://github.com/grafana/pyroscope/releases |

Image tag'ini release sahifasidan olib aniq yozasiz, `latest` ishlatilmaydi. Port host'ga faqat `127.0.0.1` ga bog'lab chiqariladi. Compose ichidagi servislar Pyroscope'ga servis nomi bilan murojaat qiladi (`http://pyroscope:4040`), `localhost` bilan emas: konteyner ichida `localhost` shu konteynerning o'zi (docker 3–4-darslar). Profillar ilovadan SDK orqali (push) yoki Alloy orqali (pull) keladi; Alloy 4-darsdan beri stack'da.

```
cd observability/stack
docker compose up -d
docker compose ps
```

Pyroscope tayyorligini brauzerda `http://localhost:4040` ni ochib yoki `http://localhost:4040/ready` manzilidan tekshirasiz (tayyor bo'lsa `ready` matni qaytadi).

- **Yuklama**: CPU yuklamasi faqat konteyner ichida yaratiladi: 1-darsdagi `loadgen` namuna ilovaga so'rov yuboradi, ba'zi vazifalarda uni vaqtincha kuchaytirasiz. Ish mashinasining o'zi stress qilinmaydi. CPU'ni to'liq band qiladigan vazifalarda `api` konteyneriga Compose'da CPU limiti qo'yiladi (cgroup limiti, docker 1-dars), aks holda bitta sekin endpoint butun mashinani sekinlashtiradi.
- **eBPF profiling**: yadro darajasidagi profiling host kernel'iga privileged kirish talab qiladi. Zorin'da bu ish mashinasiga tegadi, macOS'da esa faqat Docker Desktop VM'ini ko'radi. Shuning uchun u bu darsda faqat tushuncha sifatida o'tiladi (5-bo'lim), laboratoriyada o'z servisingizni SDK yoki pprof endpoint orqali profillaysiz.
- **Secret'lar**: yangi secret kerak emas. Avvalgi darslardagi `.env` commit qilinmaydi (`make secrets` buni tekshiradi). `compose.yaml` va config'lar commit qilinadi, volume'lar yo'q.
- **Tozalash**: mashg'ulot oxirida `docker compose down` (volume'lar qoladi). `docker system prune` va `docker volume prune -a` ishlatilmaydi.

| Narsa | Zorin (ofis) | macOS (uy) |
|-------|--------------|------------|
| Profil qaysi kodni tasvirlaydi | `amd64` kod, konteyner to'g'ridan-to'g'ri host kernel'ida | `arm64` kod, Docker Desktop'ning yashirin Linux VM'i ichida |
| Absolyut raqamlar | CPU vaqti, namunalar soni, runtime ichki frame'lari o'ziga xos | boshqa CPU, boshqa JIT kodi: raqamlar va ba'zi frame'lar Zorin'dagidan farq qiladi |
| Image arxitekturasi | `amd64` variant tortiladi | `arm64` variant tortiladi; image faqat `amd64` bo'lsa emulyatsiya ishlaydi va profilni emulyator egallaydi, bunday image'dan qoching |
| CPU limiti | host yadrolariga nisbatan | Docker Desktop VM'iga berilgan yadrolarga nisbatan |
| eBPF | qilinmaydi (ish mashinasi) | qilinmaydi (faqat VM ko'rinadi) |

Image ko'p arxitekturali ekaniga ishonchingiz komil bo'lmasa, registry sahifasidagi tag'ning "OS/Arch" ro'yxatida `linux/amd64` va `linux/arm64` borligini tekshiring.

**Ikki mashina qoidasi: oldin va keyin bitta mashinada.** Tuzatishdan oldingi va keyingi profilni, overhead o'lchovini (16-vazifa) faqat bitta mashinada solishtiring va README'ga qaysi mashina ekanini yozing (`uname -sm` natijasi bilan). Zorin'da olingan "oldin" ni Mac'da olingan "keyin" bilan solishtirish hech narsani isbotlamaydi.

**Ikkinchi mashinada tiklash.** Stack holati git orqali ko'chadi, ma'lumot ko'chmaydi. Ikkinchi mashinada: `git pull`, avvalgi darslardagi `.env` ni qo'lda qayta yarating, `docker compose up -d`, 2–3 daqiqa `loadgen` ishlashini kuting. Pyroscope volume'i bo'sh bo'ladi: oldingi mashinada yig'ilgan profillar bu yerda yo'q, kerakli davrni shu mashinada qayta yig'asiz.

---

## 1. Profil nima: stack sampling

### Call stack va namuna

Jarayon (linux 9-dars) ishlayotganda har thread'ning **call stack**'i bor: hozir bajarilayotgan funksiya, uni chaqirgan funksiya, uni chaqirgani va hokazo, eng tubida dasturning kirish nuqtasi. Stack'ning har bir qavati **frame** deyiladi. Node'da `new Error().stack` yoki `console.trace()` chiqaradigan ro'yxat aynan shu.

**Profil** bu "dastur resursni (CPU vaqti, xotira) kodning qaysi joyida sarflayapti" degan savolga javob beradigan o'lchov natijasi. Uni olishning zamonaviy usuli **sampling**: profiler har funksiya chaqiruvini o'lchamaydi, balki ma'lum chastotada (odatda soniyasiga 100 marta) "hozir stack qanday?" deb qaraydi va ko'rgan stack'ni yozib oladi. Bitta bunday surat **namuna** (sample).

### Mexanizm

1. Profiler taymer o'rnatadi. Linux'da CPU profil uchun odatda jarayon iste'mol qilgan CPU vaqtini sanaydigan taymer ishlatiladi: jarayon har 10 ms CPU ishlatganda kernel unga signal yuboradi (Go runtime'i `SIGPROF` signalidan foydalanadi). V8 (Node) alohida thread'dan asosiy thread'ni davriy to'xtatib stack'ini o'qiydi.
2. Signal kelgan onda thread nima qilayotgan bo'lsa to'xtaydi, profiler stack'ni tubigacha yurib chiqadi (stack walking) va frame manzillari ro'yxatini bufferga yozadi. Bu mikrosekundlar oladi.
3. Davr oxirida bir xil stack'lar sanaladi: "shu stack 40 marta ko'rildi".
4. Manzillar funksiya nomi, fayl va qatorga aylantiriladi (symbolization, 6-bo'lim).

Natija jadval: stack va uning yonida son. Hech qanday funksiya "o'ralmaydi", kod o'zgarmaydi.

### Misol: 10 ta xom namuna

Buyurtma servisi 100 Hz chastotada profillanmoqda. 100 ms CPU vaqti ichida profiler 10 marta qaradi va shularni ko'rdi (chapda stack tubi, o'ngda hozir bajarilayotgan funksiya):

```
t=10ms   main;handleOrder;renderInvoice;formatDate
t=20ms   main;handleOrder;renderInvoice;formatDate
t=30ms   main;handleOrder;priceItems;lookupTax
t=40ms   main;handleOrder;renderInvoice;formatDate
t=50ms   main;gc
t=60ms   main;handleOrder;priceItems;lookupTax
t=70ms   main;handleOrder;renderInvoice;formatDate
t=80ms   main;handleOrder;priceItems
t=90ms   main;handleOrder;renderInvoice
t=100ms  main;handleOrder;validate
```

Qatorma-qator: har qator bitta namuna, `;` chaqiruv zanjirini ajratadi. `formatDate` 4 qatorda eng o'ngda turibdi, demak 10 namunadan 4 tasida CPU aynan `formatDate` kodini bajarayotgan edi: CPU vaqtining taxminan 40% i. Har namuna 10 ms'ni "ifodalaydi", ya'ni `formatDate` taxminan `4 × 10 ms = 40 ms`. `validate` bir marta ko'rindi: 10% mi? 10 ta namunadan bunday xulosa chiqarib bo'lmaydi, pastga qarang.

### Aniqlik statistik

Sampling so'rovnomaga o'xshaydi: hammadan emas, tasodifiy tanlanganlardan so'raladi. Ulushi `p` bo'lgan funksiya uchun `n` namunadagi xatolik taxminan `sqrt(p × (1 − p) / n)`:

| Namunalar | `p = 0.40` uchun xatolik | O'qilishi |
|-----------|--------------------------|-----------|
| 10 | `sqrt(0.24 / 10) ≈ 0.15` | 40% ± 15 punkt: deyarli taxmin |
| 100 | `sqrt(0.24 / 100) ≈ 0.049` | 40% ± 5 punkt |
| 10 000 | `sqrt(0.24 / 10000) ≈ 0.0049` | 40% ± 0.5 punkt |

Xulosa: CPU'ni ko'p yeyayotgan narsa albatta ko'rinadi, kam chaqiriladigan tez funksiya esa namunaga umuman tushmasligi mumkin. Qisqa profil (bir necha soniya, bitta instans) shovqinli; uzoqroq oraliq va ko'proq instans yig'ilsa rasm tiniqlashadi. Profil "necha marta chaqirildi" degan savolga javob bermaydi: 40 namuna bitta uzun chaqiruv ham, million qisqa chaqiruv ham bo'lishi mumkin.

### Nima uchun arzon

Narx chaqiruvlar soniga emas, sampling chastotasiga bog'liq: soniyasiga 100 marta stack o'qish, servis 10 so'rov qabul qilyaptimi yoki 10 000 mi, bir xil ish. Shuning uchun sampling profiler'ni production'da doimiy yoqib qo'yish mumkin (aniq narx 6-bo'limda).

### Real ishda qachon kerak

- Dashboard'da (2-dars) servis CPU'si deploy'dan keyin 30% dan 70% ga chiqdi, kod diff'i katta: profil qaysi funksiya o'sganini aytadi.
- Trace'da (5-dars) span 800 ms, ichida bola span yo'q: vaqt shu servisning o'z kodida ketgan, qayerda ekanini profil ko'rsatadi.
- Cloud hisobi katta: flotdagi CPU'ning qancha ulushi serializatsiya, logging yoki kriptografiyaga ketayotganini profil raqam bilan beradi.

### Nima uchun shunday

Muqobili **instrumenting profiler**: har funksiyaning kirish va chiqishiga o'lchov kodi qo'yiladi. U aniq chaqiruvlar sonini beradi, lekin har chaqiruvga narx qo'shadi: kichik va tez-tez chaqiriladigan funksiyalar bir necha barobar sekinlashadi va natija buziladi (o'lchov o'lchanayotgan narsani o'zgartiradi). Sampling aniqlikni statistikaga almashib, narxni doimiy va past qiladi. Chrome DevTools Performance paneli ham JS uchun aynan sampling ishlatadi: yozuvdagi JS stack'lar taxminan har millisekundda olingan namunalardan tiklanadi. Demak mexanizm sizga tanish asbobdagi bilan bir xil, farq keyingi bo'limlarda: nima o'lchanadi, qanday agregatsiya qilinadi va qayerda saqlanadi.

## 2. Nimani o'lchaymiz: profil turlari

### CPU vaqti, wall-clock va off-CPU

Bitta so'rov 200 ms davom etdi deylik. Shundan 30 ms'da thread CPU'da hisob-kitob qildi, 170 ms'da esa ma'lumotlar bazasidan javob kutdi. Kutayotgan thread CPU ishlatmaydi: kernel uni uxlatib, CPU'ni boshqa ishga beradi (linux 8-dars, jarayon holatlari).

| Tushuncha | Ta'rif | Shu so'rovda |
|-----------|--------|--------------|
| CPU vaqti (on-CPU) | thread haqiqatan CPU'da bajarilgan vaqt | 30 ms |
| Off-CPU vaqti | thread kutgan vaqt: I/O, lock, uyqu, navbat | 170 ms |
| Wall-clock vaqti | soat bo'yicha o'tgan vaqt, ikkalasining yig'indisi | 200 ms |

100 Hz'li **CPU profil** bu so'rovdan `30 ms / 10 ms = 3` namuna oladi va 170 ms'lik kutishni umuman ko'rmaydi. **Wall-clock profil** esa soat bo'yicha namuna oladi: 20 namunadan 17 tasi kutish joyida bo'ladi.

**Tuzoq: CPU profilda I/O ko'rinmaydi.** So'rov sekin, lekin sababi DB yoki tashqi servisni kutish bo'lsa, CPU profil deyarli bo'sh chiqadi. Bu holatda trace yoki wall-clock profil kerak. Qisqa formula: profil "CPU va xotira qayerda", trace "vaqt qayerda".

### Profil turlari

| Tur | Nimani o'lchaydi | Qaysi savolga javob |
|-----|------------------|----------------------|
| CPU | CPU'da bajarilgan vaqt | nima hisoblayapti? |
| Wall-clock | o'tgan real vaqt, kutish ham kiradi | nima sekin (CPU yoki kutish)? |
| Heap: in-use | hozir xotirada tirik turgan obyektlar, ularni ajratgan stack bo'yicha | xotirani nima egallab turibdi (leak)? |
| Heap: alloc | davr ichidagi barcha ajratishlar, keyin bo'shatilganlari ham | GC'ni nima band qilyapti? |
| Goroutine (Go) | hozir mavjud goroutine'lar va ularning stack'i | nima to'planib qolgan? |
| Mutex, block (Go) | lock va kanal kutishda o'tgan vaqt | nima bloklanib turibdi? |

**Heap** bu dastur ishlash davomida obyektlar uchun so'rab oladigan xotira sohasi; **GC** (garbage collector) hech kim murojaat qilmayotgan obyektlarni topib xotirasini bo'shatadigan runtime qismi. Heap profili ham sampling: har ajratish emas, o'rtacha har 512 KB ajratilgan xotiradan bitta namuna olinadi (Go'da ham, V8'ning sampling heap profiler'ida ham standart qiymat shu) va o'sha paytdagi stack yoziladi. Shuning uchun heap profilida "kenglik" vaqt emas, bayt (yoki obyektlar soni).

In-use va alloc farqi: funksiya soniyasiga 100 MB vaqtinchalik obyekt yaratib, darhol tashlab yuborsa, alloc profilida u ulkan, in-use profilida deyarli yo'q. Aksincha, sekin o'sadigan va hech qachon tozalanmaydigan ro'yxat alloc'da kichik, in-use'da vaqt o'tgan sari kengayib boradi.

### Til bo'yicha farq

- **Go**: runtime'da hammasi o'rnatilgan (`runtime/pprof` paketi, HTTP uchun `net/http/pprof`). CPU profil standart 100 Hz. Mutex va block profillari standart holatda o'chiq: `runtime.SetMutexProfileFraction` va `runtime.SetBlockProfileRate` chaqirilmaguncha bo'sh keladi.
- **Node.js**: V8'da CPU profiler va sampling heap profiler bor. `node --cpu-prof` jarayon tugaganda `.cpuprofile` fayl yozadi, `node --heap-prof` heap uchun shunday qiladi, `node --inspect` esa DevTools'ni ulab jonli profil olish imkonini beradi. Pyroscope'ning Node.js SDK'si wall va heap profillarini yuboradi, CPU vaqtini wall profilga qo'shish alohida yoqiladi (`wall.collectCpuTime`). Qaysi tur qaysi versiyada borligi o'zgarib turadi: SDK sahifasidan tekshiring (Manbalar).
- Goroutine, mutex, block turlari Go'ga xos, Node'da ularning o'xshashi yo'q, chunki JS kodi bitta thread'da bajariladi.

### Node.js: event loop va CPU

Node'da JS kodingiz bitta thread'da, event loop ichida bajariladi. Sinxron funksiya 300 ms CPU'da hisoblasa, shu 300 ms davomida event loop boshqa hech narsa qila olmaydi: boshqa so'rovlarning callback'lari, taymerlar, tarmoqdan kelgan javoblar navbatda turadi. Brauzerda buning nomi "long task" va natijasi qotib qolgan UI; serverda natija: bitta og'ir so'rov shu paytdagi hamma so'rovni kutdiradi. Belgisi: hamma route'da latency birdan o'sadi, event loop lag metrikasi (1-dars, default metrikalar) ko'tariladi, CPU profilda bitta keng minora. Bir nechta OS thread'da parallel bajariladigan runtime'larda manzara boshqacha, buni 8-vazifada o'zingiz tekshirasiz.

### Real ishda qachon kerak

- p95 latency o'sdi, CPU metrikasi ham o'sdi: CPU profil.
- p95 latency o'sdi, CPU o'zgarmadi: sabab kutish. Trace, keyin kerak bo'lsa wall-clock yoki (Go'da) block va mutex profili.
- Konteyner xotirasi arra tishi shaklida o'sib OOM kill bo'lyapti (docker 1-dars): in-use heap profilini ikki vaqt nuqtasida solishtirish.
- GC pauzalari ko'p, CPU'ning sezilarli qismi GC'da: alloc profil.

### Nima uchun shunday

Turlar ko'pligi "resurs" so'zining ko'p ma'noliligidan: CPU vaqti, soat vaqti, tirik baytlar va ajratilgan baytlar turli hodisalar va ularni turli joyda sanash kerak (taymer signalida, ajratish funksiyasida, lock'da). Yagona "hamma narsa profili" bo'lmaydi. DevTools bilan farq shu yerda boshlanadi: Performance paneli bitta tab'ning wall-clock yozuvini beradi (kutish ham, render ham bir vaqt o'qida), Memory panelidagi heap snapshot esa butun obyektlar grafini beradi va "kim ushlab turibdi" (retainer) degan savolga javob beradi. Snapshot jarayonni to'xtatadi va hajmi heap bilan teng, shuning uchun uni production'da doimiy olib bo'lmaydi. Sampling heap profil arzon, lekin faqat "kim ajratgan" ni biladi.

## 3. Flame graph o'qish

### Namunalardan rasmga

1-bo'limdagi 10 ta xom namunani eslang. 10 000 ta namunani qatorma-qator o'qib bo'lmaydi, shuning uchun ular ikki bosqichda yig'iladi.

Birinchi bosqich: bir xil stack'lar birlashtiriladi va yoniga soni yoziladi. Bu **folded** (collapsed) stack formati, flame graph muallifi Brendan Gregg'ning vositalari aynan shu matn bilan ishlaydi:

```
main;gc 1
main;handleOrder;priceItems 1
main;handleOrder;priceItems;lookupTax 2
main;handleOrder;renderInvoice 1
main;handleOrder;renderInvoice;formatDate 4
main;handleOrder;validate 1
```

Qatorma-qator: `main;gc 1` "stack tubida `main`, tepasida `gc`, bu holat 1 marta ko'rildi". `main;handleOrder;priceItems 1` namunada CPU `priceItems` ning o'z kodida edi (u hali hech kimni chaqirmagan), `...;priceItems;lookupTax 2` esa ikki marta `lookupTax` ichida. Sonlar yig'indisi `1 + 1 + 2 + 1 + 4 + 1 = 10`, ya'ni hamma namuna hisobda. Qatorlar alifbo bo'yicha tartiblangan, vaqt bo'yicha emas: `t=50ms` dagi `gc` birinchi qatorga chiqdi.

Ikkinchi bosqich: har frame uchun ikki son hisoblanadi.

| Frame | Total (o'zi va bolalari) | Self (faqat o'zi) |
|-------|--------------------------|-------------------|
| `main` | 10 (100%) | 0 |
| `handleOrder` | 9 (90%) | 0 |
| `renderInvoice` | 5 (50%) | 1 |
| `formatDate` | 4 (40%) | 4 |
| `priceItems` | 3 (30%) | 1 |
| `lookupTax` | 2 (20%) | 2 |
| `gc` | 1 (10%) | 1 |
| `validate` | 1 (10%) | 1 |

**Total** (Go'da `cum`, cumulative) bu frame stack'ning istalgan joyida bo'lgan namunalar soni: o'zi bajarilayotgan va u chaqirgan funksiyalar bajarilayotgan paytlar. **Self** (Go'da `flat`) faqat frame stack'ning eng tepasida bo'lgan namunalar: CPU aynan shu funksiyaning o'z kodini bajargan. Tekshiruv: self ustuni yig'indisi doim 10, total esa yig'ilmaydi (`main` ning 10 tasi bolalarida ham sanalgan).

### Flame graph chizilishi

Endi total sonlar to'rtburchak kengligiga aylanadi. Grafana va Pyroscope root'ni tepaga qo'yadi (teskari, "icicle" ko'rinish). Har namuna 6 belgi, o'ngdagi sonlar namunalar:

```
[main                                                      ]  10
[gc  ][handleOrder                                         ]  1 | 9
      [priceItems      ][renderInvoice               ][val ]  3 | 5 | 1
      [lookupTax ]      [formatDate            ]              2 | 4
```

Qatorma-qator:
- 1-qator: `main` butun kenglikda, chunki u har namunada bor. Root doim 100%.
- 2-qator: `main` ning bolalari. `gc` 1 namuna, `handleOrder` 9. Ularning yig'indisi otaning kengligiga teng, chunki `main` ning self'i 0. Alifbo bo'yicha `gc` chapda, garchi vaqt bo'yicha o'rtada bo'lsa ham.
- 3-qator: `handleOrder` ning bolalari: `priceItems` 3, `renderInvoice` 5, `validate` 1. Yig'indi 9, ota ham 9: `handleOrder` ning o'z kodi namunaga tushmagan.
- 4-qator: `priceItems` ostida `lookupTax` 2 namuna, yonida 1 namunalik bo'sh joy qoldi. Bo'sh joy bu ota'ning self vaqti. `renderInvoice` ostida ham shunday: `formatDate` 4, bo'sh joy 1.

Klassik flame graph'da (Brendan Gregg, `perf` va boshqa vositalar) root pastda, "olov" tepaga o'sadi. Ma'no bir xil, faqat rasm teskari.

### O'qish qoidalari

- **Kenglik**: shu frame stack'da bo'lgan namunalar ulushi. CPU profilda vaqt, heap profilda bayt yoki obyekt soni.
- **Vertikal o'q**: stack chuqurligi. Frame ostidagi (icicle'da) to'rtburchaklar u chaqirgan funksiyalar.
- **Gorizontal tartib vaqt emas**: bir xil stack'lar birlashtirilgan va alifbo bo'yicha qo'yilgan. "Chapdagi oldin bo'lgan" degan xulosa chiqarilmaydi.
- **Rang** odatda ma'no tashimaydi: frame'larni farqlash uchun yoki paket (modul) bo'yicha guruhlash uchun beriladi.
- **Bo'sh joy** ota frame ostida, bolalar bilan qoplanmagan qism: ota'ning self vaqti.

O'qish tartibi: eng keng "minoralar" ni toping, ular bo'ylab chaqiruv yo'nalishida yuring va kenglik bolalarga bo'linmay tugaydigan joyni toping. O'sha frame'ning self'i katta, CPU aynan shu yerda yonyapti. Misolda `handleOrder` 90% bo'lishi yangilik emas (u hamma narsani chaqiradi); yangilik shu 90% ning 40 punkti `formatDate` da ekanligi. Sanalar formatlash buyurtmani narxlashdan qimmat, va bu birinchi qarashda kutilmagan topilma: profil aynan shunday narsalarni ochadi.

### Qo'shimcha ko'rinishlar

| Ko'rinish | Nima ko'rsatadi | Qachon kerak |
|-----------|-----------------|--------------|
| Top table | funksiyalar ro'yxati, self va total ustunlari, saralanadi | "eng qimmat funksiya" ni tez topish |
| Sandwich | tanlangan funksiyani kim chaqiradi (yuqorida) va u kimni chaqiradi (pastda) | bitta util funksiya yuz joydan chaqirilganda, uning umumiy narxi va chaqiruvchilari |
| Diff (comparison) | ikki davr yoki ikki label to'plami farqi, rang bilan: qizil ko'paydi, yashil kamaydi | deploy'dan oldin va keyin, tuzatishdan oldin va keyin |

Sandwich nima uchun kerak: `JSON.stringify` 15 xil joydan chaqirilsa, flame graph'da u 15 ta tor to'rtburchak bo'lib sochilib ketadi va har biri arzimasdek ko'rinadi. Sandwich ularni bitta qatorga yig'ib "jami 25%" deydi.

### Go'da xuddi shu: `go tool pprof -top`

Go profilini terminalda ham o'qish mumkin. Masalan yuqoridagi tuzilishga o'xshash Go dasturining 30 soniyalik CPU profili:

```
$ go tool pprof -top cpu.pprof
Type: cpu
Duration: 30s, Total samples = 2.80s ( 9.33%)
Showing nodes accounting for 2.80s, 100% of 2.80s total
      flat  flat%   sum%        cum   cum%
     1.12s 40.00% 40.00%      1.12s 40.00%  main.formatDate
     0.56s 20.00% 60.00%      0.56s 20.00%  main.lookupTax
     0.28s 10.00% 70.00%      1.40s 50.00%  main.renderInvoice
     <...>
         0     0%   100%      2.52s 90.00%  main.handleOrder
```

Qatorma-qator:
- `Duration: 30s, Total samples = 2.80s ( 9.33%)`: 30 soniya ichida jarayon jami 2.8 s CPU ishlatgan, ya'ni o'rtacha bitta yadroning 9% i. Go namunalarni son emas, vaqt sifatida ko'rsatadi: 280 namuna × 10 ms.
- `flat` va `flat%`: self. `main.formatDate` ning o'z kodi 1.12 s.
- `sum%`: shu qatorgacha flat% lar yig'indisi. "Birinchi uchta funksiya CPU'ning 70% i" degan savolga javob.
- `cum` va `cum%`: total. `main.handleOrder` ning flat'i 0, cum'i 90%: u faqat boshqalarni chaqiradi.

`-top` standart holatda flat bo'yicha saralaydi, `-cum` qo'shilsa total bo'yicha. Pyroscope'dagi Top table xuddi shu ikki ustun.

### Real ishda qachon kerak

- Incident paytida "p95 nima uchun o'sdi" savoliga: flame graph'da yangi paydo bo'lgan yoki kengaygan minora.
- Code review'dan oldin: "bu o'zgarish tezlashtiradimi?" degan bahsni diff bilan raqamga aylantirish.
- Kutubxona tanlashda: logger, serializer yoki ORM'ning sizning yuklamangizdagi haqiqiy ulushini ko'rish.

### Nima uchun shunday

Flame graph'ni Brendan Gregg 2011-yilda `perf` chiqargan minglab qator stack'larni o'qish qiyin bo'lgani uchun o'ylab topgan. Alifbo tartibi ataylab tanlangan: vaqt tartibida bir xil stack'lar bo'lak-bo'lak sochilib ketadi, alifbo tartibida esa bitta keng to'rtburchakka birlashadi va kenglik ulushni to'g'ridan-to'g'ri ko'rsatadi. Chrome DevTools Performance panelidagi **flame chart** boshqa narsa: unda X o'qi vaqt, har chaqiruv o'z vaqtida alohida chiziladi va "avval A, keyin B" ni ko'rish mumkin. Flame chart bitta yozuvning ketma-ketligini tushunishga, flame graph ko'p namunaning agregatini ko'rishga mos. Continuous profiling soatlab va ko'p instansdan yig'adi, ketma-ketlik u yerda ma'nosiz, agregat esa aynan kerakli narsa.

## 4. Pyroscope: profillar bazasi

### Bu nima

Grafana **Pyroscope** profillar uchun ma'lumotlar bazasi: ilovalardan yoki Alloy'dan profillarni qabul qiladi, ularni vaqt belgisi va label'lar bilan saqlaydi, so'rovga birlashtirilgan profil (flame graph) qaytaradi. U Loki (4-dars) va Tempo'ning (5-dars) "aka-ukasi": bitta binary, laboratoriyada hamma komponent bitta jarayonda (monolithic rejim), production'da komponentlar alohida masshtablanadi va ma'lumot object storage'da (S3 va o'xshashlari) saqlanadi. Port `4040`, o'z web UI'si va HTTP API'si bor.

**Continuous profiling** bu har instansdan doimiy, past chastotada profil yig'ib, markaziy joyda vaqt va label'lar bilan saqlash. Muqobili bir martalik profiling: muammo bo'lganda serverga kirib 30 soniya profil olish. Uning kamchiligi: muammo allaqachon o'tib ketgan bo'lishi mumkin, "odatda qanday edi" bilan solishtirib bo'lmaydi, va serverga kirish huquqi kerak.

### Ma'lumot modeli

Prometheus'da seriya metrika nomi va label'lar bilan aniqlanadi (1-dars). Pyroscope'da xuddi shunday, faqat metrika nomi o'rnida **profil turi** turadi. Profil turi ID'si besh qismdan iborat: `nom:namuna_turi:namuna_birligi:davr_turi:davr_birligi`. Go ilovasining CPU profili:

```
process_cpu:cpu:nanoseconds:cpu:nanoseconds
```

O'qilishi: profil oilasi `process_cpu`, har namunaning qiymati `cpu` vaqti, birligi nanosekund; namunalar CPU vaqti bo'yicha davriy olinadi. Heap in-use: `memory:inuse_space:bytes:space:bytes`, ya'ni qiymat tirik baytlar. Node SDK'si yuboradigan turlarning aniq ID'lari SDK versiyasiga bog'liq, Grafana'dagi profil turi ro'yxatidan o'qiysiz.

Label'lar Prometheus'dagi kabi: `service_name`, `env`, `version`, `instance` va siz qo'shganlar. Seriya tanlash ham tanish sintaksis bilan: `{service_name="api", env="lab"}`. Cardinality qoidasi o'sha: har yangi label qiymati yangi seriya, `user_id` yoki `request_id` label bo'lmaydi.

Saqlash: Pyroscope har namunani alohida saqlamaydi. Bir instansdan, masalan, har 10–15 soniyada kelgan profil allaqachon folded ko'rinishga yaqin agregat (stack va son), Pyroscope ularni label bo'yicha guruhlab siqib yozadi. So'rovda tanlangan vaqt oralig'i va label'larga mos profillar qo'shiladi (merge) va bitta flame graph qaytadi. Shuning uchun "oxirgi 1 soat, hamma instans" so'rovi bitta instansning 10 soniyasidan ancha tiniq rasm beradi (1-bo'limdagi statistika).

### Tekshirish: Pyroscope tirikmi

```
$ curl -s http://localhost:4040/ready
ready
```

`ready` qaytsa Pyroscope so'rov qabul qilishga tayyor. Ishga tushgandan keyingi birinchi soniyalarda boshqa matn (masalan ingester hali tayyor emasligi haqida) va `503` holat kodi qaytishi mumkin, bu normal, biroz kuting. Compose'dagi healthcheck (docker 4-dars) ham shu endpoint'ga qaraydi.

### Grafana'da ko'rish

Grafana'da data source turi `grafana-pyroscope-datasource` (data source provisioning 2-darsda). Ko'rish uch joyda:

- **Explore**: Pyroscope data source'ini tanlaysiz, profil turini (masalan CPU yoki `wall`) va label selector'ni yozasiz. Natija ikki qism: tepada vaqt bo'yicha grafik (tanlangan profil turining jami qiymati), pastda Top table va flame graph yonma-yon.
- **Profiles Drilldown**: Grafana'ning profillar uchun ilovasi (yangi versiyalarda menyudagi Drilldown → Profiles, eskiroqlarida Explore ostida), so'rov yozmasdan servislar, profil turlari, label'lar bo'yicha ko'rish, diff ham shu yerda.
- **Dashboard**: Flame graph paneli. 18-vazifada RED dashboard'ingizga qo'shasiz.

Explore'dagi tipik ko'rinish (CPU profil, 15 daqiqa, qisqartirilgan):

```
Symbol                      Self          Total
formatDate                  4.80 s        4.80 s
lookupTax                   2.40 s        2.40 s
renderInvoice               1.20 s        6.00 s
<...>
handleOrder                 0 s          10.80 s
total                       0 s          12.00 s
```

Qatorma-qator: ustunlar Self va Total, 3-bo'limdagi bilan bir xil ma'noda. `total` sun'iy root frame: Pyroscope hamma stack'larni bitta ildiz ostiga yig'adi. Raqamlar sekundda, chunki CPU profilning birligi vaqt; 15 daqiqada jami 12 s CPU, ya'ni servis o'rtacha bitta yadroning taxminan 1.3% ini ishlatgan.

### Real ishda qachon kerak

- Kechagi incident'ni bugun tekshirish: vaqt oralig'ini incident payti qilib qo'yasiz, profil allaqachon bor.
- Butun flot bo'yicha savol: "hamma servislarimiz CPU'sining qancha qismi logging'da?" label'siz, hamma `service_name` bo'yicha so'rov.
- Deploy'lar orasidagi regressiya: `version` label'i bo'yicha diff (5-bo'lim).

### Nima uchun shunday

Profillarni metrikalar kabi label'li seriya qilib saqlash ularni qolgan signallar bilan bir tilda gaplashtiradi: Prometheus'dagi `service_name="api"` va Pyroscope'dagi `service_name="api"` bir xil narsani bildiradi, Grafana bir panelda metrikadan profilga o'tadi. Muqobili har profilni alohida fayl (`.pprof`, `.cpuprofile`) sifatida saqlash: bir martalik tahlil uchun yaxshi, lekin minglab fayl ichidan "shu servisning dushanba kungi profillarini birlashtir" degan so'rovni bajarib bo'lmaydi. Object storage'ga yozish Loki va Tempo'dagi sabab bilan: profil hajmi katta, arzon saqlash kerak, so'rov esa nisbatan kam.

## 5. Profil yuborish usullari: push, pull, eBPF

### Uch rejim

| | SDK (push) | Alloy `pyroscope.scrape` (pull) | Alloy `pyroscope.ebpf` |
|---|---|---|---|
| Qanday | ilova ichidagi kutubxona profil yig'ib Pyroscope'ga yuboradi | Alloy ilovaning pprof HTTP endpoint'larini davriy so'raydi | kernel darajasida host'dagi barcha jarayonlarning stack'larini yig'adi |
| Kod o'zgarishi | bor (init kodi) | Go'da `net/http/pprof` import | yo'q |
| Tillar | Go, Java, Python, Ruby, Node.js, .NET, Rust | asosan Go (pprof formatini beradigan har narsa) | kompilyatsiya qilinadigan tillar yaxshi, qolganlari cheklangan |
| Qo'shimcha | dinamik label'lar (kod bo'lagi bo'yicha) | target'lar service discovery'dan, Prometheus'dagi kabi | root huquqi, faqat Linux |

**Push** bu ilova o'zi ma'lumotni markazga yuborishi, **pull** bu markaz (yoki agent) ilovadan so'rab olishi. Bu farq sizga 1-darsdan tanish: Prometheus metrikalarni pull qiladi, Loki'ga log'lar Alloy orqali push qilinadi.

### Push: SDK

SDK ilova jarayoni ichida ishlaydi: profiler'ni yoqadi, har bir necha soniyada yig'ilgan profilni HTTP orqali Pyroscope'ga yuboradi. Node.js'da:

```js
// minimal SDK setup; address and on/off come from env
const Pyroscope = require('@pyroscope/nodejs');
Pyroscope.init({
  serverAddress: process.env.PYROSCOPE_URL,
  appName: 'checkout',
  tags: { env: 'lab', version: process.env.APP_VERSION },
});
Pyroscope.start();
```

`appName` Pyroscope'da `service_name` label'iga aylanadi, `tags` statik label'lar. `require` faylning boshida, boshqa modullardan oldin turishi kerak emas (tracing'dagidan farqli, 5-dars: profiler hech narsani "o'ramaydi"), lekin `start()` ilovaning birinchi og'ir ishidan oldin chaqirilsin. Pyroscope ishlamay qolsa SDK yuborishda xato qiladi, lekin ilovani to'xtatmasligi kerak; buni 5-vazifada o'zingiz tekshirasiz.

Go'da push: `github.com/grafana/pyroscope-go` paketi, `pyroscope.Start(pyroscope.Config{...})`.

### Pull: pprof endpoint va Alloy

Go'da `net/http/pprof` paketini import qilish `/debug/pprof/` ostida profil endpoint'larini ochadi. Ularni ko'rish:

```
$ curl -s http://localhost:6060/debug/pprof/ | grep -o 'href=[^>]*' | head -5
href='allocs?debug=1'
href='block?debug=1'
href='cmdline'
href='goroutine?debug=1'
href='heap?debug=1'
```

Qatorma-qator: index sahifa HTML, `grep` undan faqat havolalarni ajratdi. `allocs` alloc profil, `block` block profil, `cmdline` jarayonning buyruq qatori (profil emas), `goroutine` goroutine'lar, `heap` in-use. Ro'yxat davomida `mutex`, `profile` (CPU, `?seconds=N` davomida yig'iladi) va `trace` ham bor. Portni ilova o'zi tanlaydi; `6060` ko'p uchraydigan odat, standart emas.

Alloy (4-darsdan beri stack'da) bu endpoint'larni Prometheus scrape kabi so'raydi:

```alloy
pyroscope.scrape "payments" {
  targets    = [{"__address__" = "payments:6060", "service_name" = "payments"}]
  forward_to = [pyroscope.write.local.receiver]
}

pyroscope.write "local" {
  endpoint {
    url = "http://pyroscope:4040"
  }
}
```

`targets` qayerdan so'rash va qaysi label bilan, `forward_to` natijani kimga berish. `pyroscope.scrape` standart holatda CPU, xotira, goroutine, mutex, block profillarini 15 soniyada bir oladi; qaysi turlar yoqilishi `profiling_config` blokida sozlanadi. Target'larni qo'lda emas, `discovery.docker` yoki `discovery.kubernetes` dan olish mumkin, xuddi metrikalardagidek.

### eBPF

**eBPF** Linux kernel ichida xavfsiz tekshirilgan kichik dasturlarni ishga tushirish mexanizmi. `pyroscope.ebpf` kernel'ga stack yig'uvchi dastur yuklaydi va host'dagi hamma jarayonni (jumladan begona jarayonlar va kernel'ning o'zi) kod o'zgartirmasdan profillaydi. Narxi: root yoki maxsus capability'lar, faqat Linux, va talqin qilinadigan yoki JIT tillarda (Node, Python) funksiya nomlari to'liq chiqmasligi mumkin, chunki kernel JIT yaratgan kod manzillarini nomga aylantira olmaydi (6-bo'lim, symbolization). Kubernetes'da har node'ga DaemonSet sifatida qo'yiladi (kubernetes moduli). Bu darsda faqat tushuncha: Laboratoriya bo'limida sababi yozilgan.

### Label'lar va diff

**Statik label'lar** jarayon ishga tushganda bir marta beriladi: `env`, `version`, `region`. Ular deploy'larni solishtirish imkonini beradi: `{service_name="checkout", version="1.4.0"}` va `version="1.5.0"` diff'i regressiyani aniq funksiyagacha ko'rsatadi.

**Dinamik label'lar** kod bo'lagini belgilaydi: shu bo'lak bajarilayotgan paytda olingan namunalarga label qo'shiladi.

```js
// samples taken inside fn get the label route="export"
Pyroscope.wrapWithLabels({ route: 'export' }, () => {
  buildExport(rows);
});
```

Go'da xuddi shu `runtime/pprof` paketidagi `pprof.Do(ctx, pprof.Labels("route", "export"), func(ctx context.Context) { ... })` bilan qilinadi. Dinamik label ham seriya yaratadi: qiymatlar soni cheklangan bo'lishi kerak (route nomlari ha, foydalanuvchi ID'si yo'q).

### Trace bilan bog'lash

**Span profiles**: profil namunalariga o'sha paytdagi span ID biriktiriladi, Grafana'da trace span'idan "shu span davomidagi profil" ga bir bosishda o'tiladi (Tempo data source'idagi "Traces to profiles" sozlamasi). Qo'llab-quvvatlash tilga va SDK'ga bog'liq, hujjatdan tekshiring (Manbalar). Bu darsda qo'lda bog'lash yetadi: trace'dan vaqt oralig'i va servisni olib, Pyroscope'da shu oraliqni ochasiz. Avtomatik bog'lash 7-darsda (OpenTelemetry) yana ko'riladi.

### Qaysi rejimni tanlash

- Bitta til, kodga kira olasiz, endpoint yoki kod bo'lagi bo'yicha label kerak: SDK (push).
- Go servislar parki, Prometheus uslubidagi service discovery allaqachon bor: pull. Ilova Pyroscope manzilini bilmaydi, profil yig'ish markazdan yoqiladi va o'chiriladi.
- Kodni o'zgartirib bo'lmaydi yoki butun node'ning manzarasi kerak: eBPF.

### Real ishda qachon kerak

- Yangi servis: SDK bilan boshlaysiz, `version` label'i birinchi kundan.
- Platforma jamoasi: yuzlab Go servisdan profil yig'ish, har jamoadan kod o'zgarishini so'ramasdan: pull yoki eBPF.
- "Qaysi route qimmat" savoli: dinamik label.

### Nima uchun shunday

Uch rejim metrikalardagi bahsning takrori. Push ilovaga bog'liqlik qo'shadi (kutubxona, manzil), lekin ilova eng boy kontekstni biladi (route, foydalanuvchi turi). Pull ilovani soddaroq qoldiradi va yig'ishni markazlashtiradi, lekin endpoint ochish kerak va dinamik kontekst yo'q. eBPF hech narsani o'zgartirmaydi, lekin kernel darajasida ishlaydi va til runtime'ining ichini kamroq tushunadi. Go'da pprof endpoint'i til bilan birga keladi, shuning uchun Go olamida pull tabiiy; Node'da bunday standart endpoint yo'q, shuning uchun SDK asosiy yo'l.

## 6. Tahlil amaliyoti, symbolization va narx

### Tipik topilmalar

- **CPU hot path**: Top table'da self bo'yicha birinchi qatorlar, keyin flame graph'da kontekst (kim chaqiryapti). Ko'p uchraydiganlari: sikl ichida qayta-qayta serializatsiya (`JSON.stringify`/`JSON.parse`), sikl ichida yaratiladigan regex, O(n²) qidiruv (massiv ichida `find` sikl ichida), keraksiz nusxalash, sinxron kriptografiya (`pbkdf2Sync`, `bcrypt` ning sinxron varianti), haddan ortiq logging.
- **Xotira**: in-use profil vaqt o'tishi bilan faqat o'sayotgan bo'lsa leak. Profil qaysi funksiya ajratgan obyektlar tirik qolganini ko'rsatadi, kim ularni ushlab turganini emas (2-bo'lim). Alloc profil keng bo'lsa GC bosimi: qisqa umrli obyektlarni kamaytirish kerak.
- **Node.js**: CPU'ni band qilgan sinxron funksiya shu paytdagi hamma so'rovni kutdiradi (2-bo'lim). Belgisi: bitta keng minora va hamma route'da latency o'sishi.

### Optimizatsiya tartibi

1. O'lcha: profil va metrikalar (p95, CPU) tuzatishdan oldin.
2. Eng keng joyni top: self bo'yicha, keyin kontekst.
3. Bitta narsani o'zgartir.
4. Diff bilan tasdiqla: frame kamaydimi, metrikalar yaxshilandimi.

Profilsiz optimizatsiya taxmin, va taxmin odatda noto'g'ri joyni ko'rsatadi. **Amdahl qonuni** shuni raqamga aylantiradi: umumiy vaqtning `p` ulushini `s` barobar tezlashtirsangiz, umumiy yutuq `1 / ((1 − p) + p / s)`. Flame graph'da 1% egallagan funksiyani ikki barobar tezlashtirish umumiy vaqtni 0.5% ga qisqartiradi; 40% egallaganini ikki barobar tezlashtirish 20% beradi.

### Symbolization

Profiler stack'ni xotira manzillari sifatida yozadi (`0x4a3f10`). Manzilni `main.formatDate` va `invoice.go:42` ga aylantirish **symbolization** deyiladi. Tillar bo'yicha:

- **Go**: binary ichida runtime'ning o'z jadvali bor, runtime profilni allaqachon nomlar bilan beradi. `-ldflags="-s -w"` bilan qurilgan (debug ma'lumoti olib tashlangan) binary'da ham Go profillari funksiya nomlarini ko'rsatadi.
- **Node.js**: V8 JS funksiyalarini nomi bilan biladi, SDK nomlarni o'zi yozadi. Nomsiz funksiyalar `(anonymous)` bo'lib chiqadi, shuning uchun og'ir callback'larga nom bering. Server kodi minify qilingan yoki bitta faylga bundle qilingan bo'lsa nomlar `a`, `t`, `n` bo'lib qoladi: server kodini profil uchun o'qiladigan holda saqlang.
- **eBPF**: kernel tashqaridan qaraydi, native kod uchun binary'dagi symbol'lar kerak, JIT kod uchun runtime'ning yordamchi xaritasi (Node'da `--perf-basic-prof` flag'i shunday xarita yozadi).

### Overhead

Sampling profiler narxi past, lekin nol emas: har namunada stack yig'iladi, davr oxirida profil siqiladi va tarmoqqa yuboriladi. Narx sampling chastotasi, stack chuqurligi va yoqilgan profil turlari soniga bog'liq (Go'da mutex va block profillari qimmatroq, ularning chastotasi sozlanadi). Internetdagi umumiy foizlarga ishonmang: 16-vazifada CPU va latency metrikalari bilan profiler yoqilgan va o'chirilgan holatni bir xil yuklamada o'zingiz o'lchaysiz. Profiler env orqali o'chiriladigan bo'lsin: production'da shubha tug'ilsa qayta build qilmasdan o'chirish kerak.

### Xavfsizlik

Profil ichki tuzilmani ochadi: funksiya, fayl va paket nomlari, ba'zan label orqali boshqa ma'lumot. Go'ning `/debug/pprof` endpoint'i bundan tashqari so'rov bilan servisni yuklash imkonini beradi (`profile?seconds=60` 60 soniya CPU profil yig'diradi). Shuning uchun pprof alohida, faqat ichki tarmoqdagi portda ochiladi, asosiy API porti bilan birga internetga chiqmaydi. Pyroscope'ning `4040` porti ham laboratoriyada `127.0.0.1` ga bog'lanadi.

### Real ishda qachon kerak

- Performance ticket: "endpoint sekin" dan boshlab o'lchov, tuzatish, diff bilan isbot.
- Cloud xarajatini kamaytirish: flotdagi eng keng umumiy frame'lar (serializatsiya, siqish, logging) bo'yicha birinchi ish.
- Xotira bo'yicha OOM kill'lar: in-use diff.

### Nima uchun shunday

"O'lcha, keyin o'zgartir" qoidasi Donald Knuth'ning mashhur ogohlantirishidan keladi: dasturchilar sekin joyni taxmin qilishda doim adashadi, va vaqtning katta qismi kodning kichik qismida ketadi. Continuous profiling bu qoidani arzon qiladi: o'lchov allaqachon yig'ilgan, faqat ochib ko'rish qoladi. Symbolization va overhead haqidagi bo'limlar "profil doim to'g'ri" emasligini eslatadi: noma'lum nomlar, qisqa namuna yoki profiler'ning o'zi rasmni buzishi mumkin, shuning uchun har topilma metrika bilan tasdiqlanadi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Call stack, frame | bajarilayotgan funksiyalar zanjiri; uning bitta qavati |
| Profil | dastur resursni kodning qayerida sarflayotganini ko'rsatadigan o'lchov natijasi |
| Sampling | har chaqiruvni emas, ma'lum chastotada stack'ning suratini olish |
| Namuna (sample) | bitta olingan stack va uning qiymati (vaqt, bayt) |
| Instrumenting profiler | har funksiyaga o'lchov kodi qo'yadigan, aniq lekin qimmat profiler |
| On-CPU / off-CPU | thread CPU'da bajarilgan vaqt / kutgan vaqt |
| Wall-clock profil | soat bo'yicha namuna oladigan, kutishni ham ko'rsatadigan profil |
| Heap in-use / alloc | hozir tirik obyektlar / davr ichidagi barcha ajratishlar |
| GC | ishlatilmayotgan obyektlar xotirasini bo'shatadigan runtime qismi |
| Folded stack | `a;b;c 4` ko'rinishidagi birlashtirilgan stack va son |
| Self (flat) | frame stack tepasida bo'lgan ulush, faqat o'z kodi |
| Total (cum) | frame stack'ning istalgan joyida bo'lgan ulush, bolalari bilan |
| Flame graph | stack'lar agregati: kenglik ulush, tartib alifbo, X o'qi vaqt emas |
| Flame chart | X o'qi vaqt bo'lgan, chaqiruvlar ketma-ketligini ko'rsatadigan diagramma |
| Icicle | root tepada bo'lgan teskari flame graph |
| Top table, sandwich, diff | funksiyalar ro'yxati / funksiyaning chaqiruvchilari va chaqiriladiganlari / ikki profil farqi |
| Hot path | CPU'ning katta qismi ketadigan kod yo'li |
| Continuous profiling | profilni doimiy, past chastotada yig'ib markazda saqlash |
| Pyroscope | Grafana'ning profillar bazasi |
| Profil turi ID | `nom:namuna_turi:birlik:davr_turi:birlik` ko'rinishidagi profil identifikatori |
| Push / pull | ilova o'zi yuboradi / agent ilovadan so'rab oladi |
| pprof | Go'ning profil formati va `/debug/pprof` endpoint'lari |
| eBPF | kernel ichida kichik dasturlar ishga tushirish mexanizmi, kod o'zgartirmasdan profillash uchun |
| Statik / dinamik label | jarayon bo'yicha bir marta beriladigan / kod bo'lagi bo'yicha qo'shiladigan label |
| Span profiles | profil namunalarini span ID bilan bog'lash |
| Symbolization | xotira manzillarini funksiya nomi va qatorga aylantirish |
| Amdahl qonuni | qismni tezlashtirishdan keladigan umumiy yutuq chegarasi |

## Tuzoqlar

- Flame graph'da X o'qini vaqt deb o'qish: tartib alifbo bo'yicha, ketma-ketlik emas.
- Total'i katta, self'i nol funksiyani "aybdor" deb topish: `main` yoki router doim keng. Self'ga va barglarga qarang.
- CPU profildan I/O kutishni qidirish: ko'rinmaydi. Trace yoki wall-clock profil kerak.
- Bitta instansning 10 soniyalik profilidan butun tizim haqida xulosa: sampling statistik, qisqa namuna shovqinli. Uzoqroq oraliq va bir nechta instansni yig'ing.
- Yuklamasiz profil olish: idle jarayon profili runtime'ning o'z ishini (GC, taymerlar) ko'rsatadi, sizning muammoingizni emas.
- Heap profilini "kim ushlab turibdi" deb o'qish: u faqat "kim ajratgan" ni biladi.
- Minify yoki bundle qilingan server kodi: funksiya nomlari o'qilmaydi. Nomsiz callback'lar `(anonymous)` bo'lib birlashib ketadi.
- Oldin va keyingi profilni turli mashinada olish: Zorin `amd64` va Mac `arm64` raqamlari solishtirilmaydi.
- macOS'da faqat `amd64` image'ni profillash: emulyator profilni egallaydi, rasm haqiqatni aks ettirmaydi.
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
- https://grafana.com/docs/alloy/latest/reference/components/pyroscope/pyroscope.ebpf/ – eBPF profiling
- https://grafana.com/docs/pyroscope/latest/configure-client/trace-span-profiles/ – span profiles
- https://www.brendangregg.com/flamegraphs.html – flame graph muallifidan
- https://pkg.go.dev/net/http/pprof – Go pprof endpoint'lari
- https://pkg.go.dev/runtime/pprof – Go profil label'lari (`pprof.Do`)
- https://nodejs.org/en/learn/diagnostics/flame-graphs – Node.js'da flame graph
- https://developer.chrome.com/docs/devtools/performance/reference – DevTools flame chart (taqqoslash uchun)

---

## Birga bajaramiz

Pyroscope va Grafana'ni stack'dan alohida, vaqtinchalik konteynerlarda ko'tarib, kichik Node skriptini profillaymiz, flame graph'ni o'qiymiz, hot path'ni topamiz va diff bilan tuzatishni tasdiqlaymiz. Misol vazifalardagidan boshqa: `api` emas, alohida skript; hot path parol hash'lash va saralash; Grafana data source'i qo'lda qo'shiladi (vazifalarda provisioning bilan qilasiz). Hamma narsa repodan tashqarida, `~/tmp/prof-demo` papkasida, oxirida o'chiriladi. Ikkala mashinada bir xil ishlaydi; Mac'da image'larning `arm64` varianti tortiladi.

1. Papka va tarmoq. Ikki konteyner bir-birini nom bilan topishi uchun alohida Docker tarmog'i:

```
$ mkdir -p ~/tmp/prof-demo && cd ~/tmp/prof-demo
$ docker network create prof-demo
<tarmoq-id>
```

2. Pyroscope va Grafana. Versiyalarni release sahifalaridan oling (`latest` emas), portlar stack bilan to'qnashmasligi uchun `4041` va `3001`:

```
$ docker run -d --name prof-pyro --network prof-demo -p 127.0.0.1:4041:4040 grafana/pyroscope:<versiya>
$ docker run -d --name prof-grafana --network prof-demo -p 127.0.0.1:3001:3000 \
    -e GF_AUTH_ANONYMOUS_ENABLED=true -e GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
    grafana/grafana:<versiya>
$ curl -s http://localhost:4041/ready
ready
```

Anonim admin faqat shu vaqtinchalik, `127.0.0.1` ga bog'langan Grafana uchun; stack'dagi Grafana'da bunday qilinmaydi.

3. Skript. `app.js`:

```js
const Pyroscope = require('@pyroscope/nodejs');
const crypto = require('node:crypto');

Pyroscope.init({
  serverAddress: process.env.PYROSCOPE_URL,
  appName: 'prof-demo',
  tags: { version: process.env.APP_VERSION },
  wall: { collectCpuTime: true },
});
Pyroscope.start();

function hashPassword(pw) {
  return crypto.pbkdf2Sync(pw, 'demo-salt', 20000, 32, 'sha256');
}

function sortScores(n) {
  const a = Array.from({ length: n }, () => Math.random());
  for (let i = 0; i < a.length; i++)            // bubble sort: O(n^2) on purpose
    for (let j = 0; j < a.length - i - 1; j++)
      if (a[j] > a[j + 1]) [a[j], a[j + 1]] = [a[j + 1], a[j]];
  return a;
}

function tick() {
  hashPassword('secret-' + Date.now());
  sortScores(3000);
  setTimeout(tick, 50);
}
tick();
```

`'demo-salt'` va `'secret-'` sun'iy qiymatlar, haqiqiy parol emas. Kutubxonani konteyner ichida o'rnatamiz (host'ga Node kerak emas); versiyani npm sahifasidan oling:

```
$ docker run --rm -v "$PWD":/app -w /app node:22-bookworm-slim npm install @pyroscope/nodejs@<versiya>
added <N> packages in <...>s
```

Kutubxona native qism bilan keladi; Mac'da konteyner `linux/arm64`, Zorin'da `linux/amd64` uchun tayyor binary oladi. Shuning uchun `node_modules` ni mashinalar orasida ko'chirmang, har mashinada qayta o'rnating.

4. v1 ni ishga tushirish:

```
$ docker run -d --name prof-app --network prof-demo -v "$PWD":/app -w /app \
    -e PYROSCOPE_URL=http://prof-pyro:4040 -e APP_VERSION=v1 \
    node:22-bookworm-slim node app.js
$ docker stats --no-stream prof-app
CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT   ...
<...>          prof-app   <70-100>% <...>
```

`PYROSCOPE_URL` da servis nomi `prof-pyro`, chunki skript konteyner ichida (Laboratoriya bo'limi). CPU taxminan bitta yadro: skript deyarli tinimsiz hisoblayapti. 3–5 daqiqa kuting.

5. Data source. `http://localhost:3001` → Connections → Data sources → Add data source → Grafana Pyroscope, URL `http://prof-pyro:4040`, Save & test. Muvaffaqiyat xabari chiqishi kerak.

6. Flame graph. Explore → Pyroscope data source → profil turi sifatida `wall` turini tanlang (SDK CPU vaqtini alohida namuna turi sifatida ko'rsatsa, o'shani; nomlar SDK versiyasiga bog'liq), label selector `{service_name="prof-demo"}`, oraliq "Last 5 minutes". Top table self bo'yicha saralangan holda taxminan shunday:

```
Symbol                          Self       Total
sortScores /app/app.js          <~70>%     <~70>%
pbkdf2Sync node:internal/...    <~25>%     <~25>%
<...>
tick /app/app.js                <~0>%      <~97>%
```

O'qilishi: `sortScores` ning self va total'i deyarli teng, u hech kimni chaqirmaydi va CPU uning o'z siklida yonyapti. `pbkdf2Sync` Node ichki moduli, nomi yonida fayl yo'li `node:` bilan boshlanadi; uni chaqirgan `hashPassword` ning self'i nolga yaqin. `tick` total'i katta, self'i nol: u faqat ikkalasini chaqiradi. Flame graph'da `tick` ostida ikki minora: keng `sortScores` va torroq `hashPassword` → `pbkdf2Sync`. Kutilmagan joy: parol hash'lash "og'ir" deb o'ylanadi, lekin bu yuklamada bubble sort ko'proq yeyapti. Aniq foizlar mashinangizga bog'liq.

7. Sandwich. Top table'da `pbkdf2Sync` ustida sichqoncha menyusidan sandwich ko'rinishini tanlang: tepada chaqiruvchi zanjir (`tick` → `hashPassword`), pastda u chaqirgan ichki funksiyalar. Bitta chaqiruvchi bo'lgani uchun bu yerda oddiy; vazifalarda ko'p chaqiruvchili funksiyada ishlatasiz.

8. v2: bitta o'zgarish. `sortScores` ichidagi ikki ichma-ich siklni `a.sort((x, y) => x - y);` bilan almashtiring, natija bir xil saralangan massiv. Konteynerni yangi versiya bilan qayta ko'taring:

```
$ docker rm -f prof-app
$ docker run -d --name prof-app --network prof-demo -v "$PWD":/app -w /app \
    -e PYROSCOPE_URL=http://prof-pyro:4040 -e APP_VERSION=v2 \
    node:22-bookworm-slim node app.js
```

3–5 daqiqa kuting.

9. Diff. Grafana'da Profiles Drilldown (4-bo'lim: menyudagi Drilldown → Profiles) → `prof-demo` servisi → diff (comparison) ko'rinishi. Chap (baseline) tomonga `{service_name="prof-demo", version="v1"}`, o'ng (comparison) tomonga `version="v2"`, vaqt oralig'ini ikkala davrni qamrab oladigan qilib tanlang. Natijada `sortScores` yashil (kamaydi): v1'da u CPU'ning katta qismi edi, v2'da bir necha foiz. `pbkdf2Sync` ulushi oshgandek ko'rinadi: u o'zgarmadi, lekin jami kichraygani uchun nisbati o'sdi. Diff foizlarni solishtiradi, shuning uchun absolyut tasdiqni metrikadan oling:

```
$ docker stats --no-stream prof-app
CONTAINER ID   NAME       CPU %     MEM USAGE / LIMIT   ...
<...>          prof-app   <10-20>%  <...>
```

CPU sezilarli tushdi: diff "qayerda", metrika "qancha" ni tasdiqladi.

10. Tozalash:

```
$ docker rm -f prof-app prof-grafana prof-pyro
$ docker network rm prof-demo
$ rm -rf ~/tmp/prof-demo
```

Vazifalarda xuddi shu oqim `api` ustida, provisioning va loadgen bilan, stack ichida bajariladi.

## Vazifalar

Javoblar `observability/06-profiling/README.md` da (`make new m=observability n=06 name=profiling`), har vazifa uchun `## N. Title` ostida: nima qildingiz, flame graph'dan o'qilgan aniq raqamlar (funksiya nomi, self va total foizi), izoh. Flame graph skrinshotlarini shu papkaga qo'ying. Stack o'zgarishlari `observability/stack/` da. README boshida qaysi mashinada ishlaganingizni yozing (`uname -sm`).

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
