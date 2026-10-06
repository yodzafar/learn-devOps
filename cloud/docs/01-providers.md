# 1-dars: Cloud turlari va farqlari

Maqsad: cloud nima ekanini noldan tushunish: xizmat modellari (IaaS, PaaS, FaaS, SaaS), joylashtirish modellari (public, private, hybrid), region va availability zone tuzilishi, shared responsibility model va narx qanday shakllanishi. Siz frontend tomonda Vercel, Netlify, GitHub kabi xizmatlarning iste'molchisi bo'lgansiz: `git push` qilgansiz, sayt o'zi chiqqan. Bu modulda xuddi shu narsaga operator ko'zi bilan qaraysiz: o'sha platforma sizdan aynan nimani yashirgan (server, tarmoq, TLS, yangilash), qaysi qatlam kimning javobgarligida, nima uchun pul olinadi, qachon managed xizmat, qachon o'z serveringiz. Bu dars 2-4-darslardagi har bir amaliy qaror (region, instans tipi, S3 yoki disk, VM yoki managed) uchun asos.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1-4 bo'limlar va A, B guruh vazifalari, ikkinchi kun 5-7 bo'limlar va C guruhi, uchinchi kun 8-9 bo'limlar, "Birga bajaramiz", D guruhi va `decision.md`. Diqqatni quyidagilarga qarating: javobgarlik chegarasi har modelda qayerdan o'tadi, region va AZ nosozlik chegarasi sifatida, pul nima uchun olinadi (ayniqsa chiquvchi trafik va unutilgan resurslar), managed xizmatning yashirin narxi va foydasi.

Qanday o'qish kerak: bu dars tahliliy, lekin quruq o'qish emas. Har bo'limdagi misol buyrug'ini o'zingiz ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi raqamlar (vaqt, IP manzil) farq qiladi, bu normal; bunday joylar `<...>` bilan belgilangan yoki "sizda boshqa" deb aytilgan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsda cloud resurs yaratilmaydi, akkaunt ham shart emas (akkaunt 2-darsda ochiladi). Vazifalar tahliliy: rasmiy hujjat va narx sahifalarini o'qish, o'lchash, jadval tuzish, qarorni asoslash.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Brauzer | | provayderlarning hujjati, narx sahifalari va kalkulyatorlari (ro'yxatdan o'tmasdan ochiladi) |
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | `curl`, `ping`, `dig` bilan o'lchash, `task_5.sh`, repo (`make`, `git`) |
| `lab` VM (`SETUP.md`) | `ubuntu@lab:~$` | faqat zaxira: host'da biror buyruq yo'q bo'lsa |

- `curl` bu URL'ga so'rov yuboradigan buyruq qatori dasturi (brauzerdagi `fetch` ning terminal ko'rinishi), `ping` manzilga kichik paket yuborib javob vaqtini o'lchaydi, `dig` DNS'dan domen nomining IP manzilini so'raydi. Uchalasi `network` modulida batafsil o'tilgan.
- Tozalash kerak emas: hech narsa yaratilmaydi.
- Narxlar haqidagi har bir raqamni o'zingiz rasmiy sahifadan olasiz va `README.md` da olingan sanasi bilan yozasiz. Narxlar va free tier shartlari o'zgarib turadi, shuning uchun bu darsda ataylab bitta ham aniq narx yozilmagan.
- Bu dars oldingi holatga tayanmaydi. Mashinani almashtirsangiz hech narsa tiklash kerak emas: javoblar git orqali ko'chadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | `curl` va `ping` bor. `dig` bo'lmasa (`command -v dig` bo'sh qaytsa) uni `lab` VM ichida ishlating: `multipass exec lab -- dig +short example.com`. Shell bash yoki zsh. |
| macOS (uy) | `curl`, `ping`, `dig` tizim bilan birga keladi. Utilitalar BSD: `ping` cheksiz emas, lekin har doim `-c <son>` bering; `grep -P` yo'q; `date` ning GNU flag'lari yo'q. `task_5.sh` ni ikkala mashinada ishlaydigan qilib yozing (pastda, 5-vazifa yo'nalishida). |

Latency (kechikish) o'lchovi qaysi tarmoqdan qilinganiga bog'liq: ofis va uy internet provayderi boshqa bo'lsa, natijalar ham boshqa chiqadi. `README.md` da o'lchov qaysi mashina va qaysi tarmoqdan olinganini yozing.

---

## 1. Cloud nima

### Ta'rif

Cloud bu boshqa kompaniyaning data-markazidagi (minglab server turadigan bino) kompyuter resurslarini internet orqali, kerak bo'lgan paytda ijaraga olish. AQSH standartlar instituti NIST ta'rifi bo'yicha cloud besh xususiyatga ega:

| Xususiyat | Ma'nosi |
|-----------|---------|
| On-demand self-service | odam bilan gaplashmasdan, o'zingiz API orqali resurs olasiz |
| Broad network access | resursga tarmoq orqali kiriladi |
| Resource pooling | provayder temiri ko'p mijoz orasida bo'lishiladi (multi-tenancy: bitta jismoniy serverda bir nechta mijozning VM'lari) |
| Rapid elasticity | kerak bo'lganda ko'paytirish va kamaytirish |
| Measured service | ishlatilgan hajm o'lchanadi va shunga to'lanadi |

Operator uchun asosiy xulosa: **cloud bu API orqali boshqariladigan birovning data-markazi**. API bu dastur dasturga murojaat qiladigan interfeys, bu yerda oddiy HTTPS so'rovlari.

### Mexanizm: hamma narsa API chaqiruvi

Provayder konsoli (brauzerdagi boshqaruv sahifasi), CLI (terminal dasturi), SDK (dasturlash tili kutubxonasi) va Terraform (infratuzilmani fayl bilan tasvirlaydigan asbob, alohida modul) hammasi bir xil HTTPS API'ni chaqiradi. Konsolda "Launch instance" tugmasini bosganingizda brauzer `RunInstances` degan API chaqiruvini yuboradi; CLI'dagi `aws ec2 run-instances` ham aynan shuni yuboradi. Shuning uchun bu modulda har ish avval konsolda (tushunish uchun), keyin CLI'da (takrorlanuvchan bo'lishi uchun) qilinadi.

Frontend tajribasi bilan bog'liqlik: Vercel dashboard'idagi har tugma ham Vercel REST API'sini chaqiradi, `vercel` CLI ham shuni qiladi. Farq shundaki, AWS API'si VM, disk va tarmoq darajasigacha tushadi.

### Misol: API endpoint'i ochiq turibdi

Har AWS xizmatining har regionda o'z endpoint'i (API manzili) bor. Akkauntsiz ham unga ulanish mumkin, faqat buyruq bajarilmaydi:

```
$ dig +short ec2.eu-central-1.amazonaws.com
3.78.206.42
$ curl -s -o /dev/null -w '%{http_code}\n' https://ec2.eu-central-1.amazonaws.com
301
```

Birinchi buyruq: `dig +short` faqat javobni chiqaradi, bu Frankfurt regionidagi EC2 API serverlaridan birining IP manzili (sizda boshqa manzil chiqadi, chunki ular ko'p va almashib turadi). Ikkinchi buyruq: `-s` progress'ni yashiradi, `-o /dev/null` javob tanasini tashlaydi, `-w '%{http_code}\n'` faqat HTTP status kodini chiqaradi. `301` bu redirect: server bor, javob berdi, lekin imzolangan so'rovsiz ish qilmaydi. Imzo nima ekani va kalitlar 2-darsda.

### CapEx va OpEx

O'z serveringiz bu oldindan to'lanadigan kapital xarajat (CapEx: temirni sotib olasiz, keyin ishlatasiz). Cloud bu ishlatganga qarab to'lanadigan operatsion xarajat (OpEx: oylik hisob). Cloud doim arzon degani emas: doimiy, oldindan ma'lum yuklama uchun o'z temiringiz yoki arzon dedicated server (butunlay sizga ijaraga berilgan jismoniy server) ko'pincha arzonroq. Cloud tezlik, elastiklik va tayyor xizmatlar uchun tanlanadi.

### Real ishda qachon kerak

- Hamkasb "konsolda qilib qo'ydim" desa, bilasizki o'sha ishni CLI yoki Terraform bilan takrorlash mumkin, chunki ostida bir xil API.
- "Cloud'ga o'tsak arzonlashadi" degan gapni tekshirishda: yuklama doimiymi yoki o'zgaruvchanmi, shunga qarab javob har xil.

### Nima uchun shunday

API birinchi bo'lishining tarixiy sababi bor: AWS 2006-yilda Amazon'ning ichki infratuzilmasini tashqi mijozlarga xizmat sifatida ochgan, ichkarida esa jamoalar bir-birining tizimiga faqat API orqali murojaat qilishi shart edi. Muqobili (provayderga xat yozib server so'rash, bir necha kun kutish) klassik hosting'da bo'lgan va avtomatlashtirishga imkon bermagan. API bo'lgani uchun infratuzilmani kod sifatida saqlash mumkin bo'ldi.

## 2. Xizmat modellari

### Bitta savol

Farq bitta savolda: stack'ning (dastur ishlashi uchun kerakli qatlamlar to'plami) qaysi qatlamigacha provayder boshqaradi.

| Qatlam | On-premises | IaaS | PaaS | FaaS | SaaS |
|--------|-------------|------|------|------|------|
| Dastur kodi | siz | siz | siz | siz | provayder |
| Runtime, kutubxonalar | siz | siz | provayder | provayder | provayder |
| OS, patch'lar | siz | siz | provayder | provayder | provayder |
| Virtualizatsiya | siz | provayder | provayder | provayder | provayder |
| Server, disk, tarmoq, bino | siz | provayder | provayder | provayder | provayder |
| Ma'lumot va kirish huquqlari | siz | siz | siz | siz | siz |

On-premises bu hammasi o'z binoyingizda degani. Patch bu OS yoki dasturdagi xato va zaiflikni yopadigan yangilanish. Oxirgi qator eng muhimi: ma'lumot va kim nimaga kira olishi har doim sizda qoladi.

| Model | Nima olasiz | Misollar | Nimani yo'qotasiz |
|-------|-------------|----------|-------------------|
| IaaS (Infrastructure as a Service) | VM, disk, tarmoq | AWS EC2, GCP Compute Engine, Azure Virtual Machines, DigitalOcean Droplets, Hetzner Cloud | Vaqt: OS, patch, monitoring, backup sizda |
| PaaS (Platform as a Service) | Kod yoki image berasiz, platforma ishga tushiradi | Heroku, Vercel, Render, AWS Elastic Beanstalk, Google App Engine, Cloud Run | Nazorat: OS, tarmoq, ba'zan runtime versiyasi platforma qo'lida |
| FaaS (Function as a Service) | Funksiya, hodisaga javoban ishlaydi, chaqiruvga to'lanadi | AWS Lambda, Cloud Run functions, Azure Functions, Cloudflare Workers | Uzoq yashovchi jarayon, lokal holat; cold start, vaqt chegarasi bor |
| SaaS (Software as a Service) | Tayyor dastur | GitHub, Slack, Google Workspace, Datadog | Deyarli hamma narsa sozlanmaydi, ma'lumot birovda |

Cold start bu funksiya anchadan beri chaqirilmagan bo'lsa, birinchi so'rovda platforma uni qaytadan ishga tushirishi uchun ketadigan qo'shimcha kechikish.

### Mexanizm: PaaS sizdan nimani yashiradi

Vercel'ga `git push` qilganingizda platforma siz ko'rmaydigan ishlarni bajaradi. 4-darsda xuddi shularni IaaS'da qo'lda qilasiz:

| Ish | PaaS'da (Vercel) | IaaS'da (bu modulda, qo'lda) |
|-----|------------------|------------------------------|
| Server | ko'rinmaydi | EC2 instans yaratasiz, OS'ni yangilaysiz (3-dars) |
| Tarmoq va firewall | ko'rinmaydi | VPC, subnet, security group (3-dars) |
| Build | platforma `npm run build` qiladi | image'ni o'zingiz yig'asiz (4-dars) |
| TLS sertifikat | avtomatik | o'zingiz olasiz va yangilaysiz (4-dars) |
| Yangi versiyaga o'tish, rollback | tugma | o'z tartibingiz va skriptingiz (4-dars) |
| Log | dashboard'da | serverda o'zingiz yig'asiz (4-dars) |

### Misol: javob sarlavhasidan modelni ko'rish

```
$ curl -sI https://vercel.com | grep -iE '^(HTTP|server|x-vercel-id)'
HTTP/2 200
server: Vercel
x-vercel-id: hkg1::iad1::<id>
```

`-I` faqat javob sarlavhalarini so'raydi. `server: Vercel`: so'rovga platformaning o'z proxy'si javob berdi, uning ortidagi mashinalar haqida hech narsa ko'rinmaydi va siz ularga `ssh` (masofaviy serverga terminal orqali kirish) qila olmaysiz. `x-vercel-id` dagi `hkg1` va `iad1` so'rov qaysi edge nuqtadan kirib, qaysi regionda bajarilganini bildiradi (sizda boshqa kodlar chiqadi). Mijoz sifatida siz faqat kod va sozlamani boshqarasiz: bu PaaS ning aniq belgisi.

### Chegaralar aniq emas

Managed database (AWS RDS) PaaS ga yaqin: engine patch'i va backup provayderda, sxema va so'rovlar sizda. "Container as a Service" (ECS Fargate, Cloud Run) IaaS va PaaS orasida. Modelni nom bo'yicha emas, "OS'ga kim patch qo'yadi, server yiqilsa kim qayta ko'taradi" savoli bo'yicha aniqlang.

**Tuzoq: "serverless" serverlar yo'q degani emas.** Server bor, faqat siz uni ko'rmaysiz va boshqarmaysiz. Natijada debug qilish imkoniyati ham kamayadi: `ssh` qilib ichiga kirib bo'lmaydi, faqat log va metrikalar.

### Real ishda qachon kerak

- Yangi xizmatni baholashda: "bu yiqilsa kim tuzatadi, kim patch qo'yadi" savoli bilan javobgarligingizni darhol bilasiz.
- Incident paytida: PaaS'da faqat log va status sahifasiga qaraysiz, IaaS'da serverga kirib tekshirasiz.

### Nima uchun shunday

Modellar bir-birining o'rnini bosmagan, ustma-ust qurilgan: PaaS provayderlarining ko'pi o'zi IaaS ustida ishlaydi. Har yuqori qatlam nazoratni soddalikka almashtiradi. Bitta "eng yaxshi" model yo'qligining sababi shu: kichik jamoaga vaqt qimmat (PaaS), katta yoki maxsus talabli tizimga nazorat qimmat (IaaS).

## 3. Joylashtirish modellari

### To'rt variant

Xizmat modeli "provayder nimani boshqaradi" degan savolga javob bersa, joylashtirish modeli "infratuzilma kimniki va kim bilan bo'lishiladi" degan savolga javob beradi.

| Model | Ta'rif | Qachon |
|-------|--------|--------|
| Public cloud | Provayder infratuzilmasi, ko'p mijoz bilan bo'lishilgan, internet orqali API | Ko'p hollarda standart tanlov |
| Private cloud | Bitta tashkilot uchun ajratilgan (o'z data-markazida yoki ijarada), odatda OpenStack, VMware | Qat'iy regulyatsiya, ma'lumot mamlakatdan chiqmasligi shart, juda katta doimiy yuklama |
| Hybrid | Public va private birga, tarmoq bilan ulangan (VPN, ajratilgan kanal) | Eski tizimlar o'z joyida qoladi, yangilari cloud'da; ma'lumot lokal, hisoblash cloud'da |
| Multi-cloud | Bir nechta public provayder | Har biridan eng yaxshi xizmat, yoki bitta provayderga qaramlikni kamaytirish |

VPN bu ikki tarmoqni internet ustidan shifrlangan tunnel bilan ulash usuli.

### Mexanizm: public cloud'da izolyatsiya

Public cloud'da sizning VM'ingiz boshqa mijozlarning VM'lari bilan bitta jismoniy serverda turishi mumkin. Ularni **hypervisor** ajratadi: bu jismoniy server ustida bir nechta VM'ni ishga tushiradigan va ularni bir-biridan ajratadigan dastur (Multipass'dagi `lab` VM ham sizning kompyuteringizdagi hypervisor ustida ishlaydi). Tarmoq darajasida har mijozga o'z virtual tarmog'i (AWS'da VPC, 3-dars) beriladi. "Public" so'zi "hamma ko'ra oladi" degani emas, "hamma sotib ola oladi" degani.

### Misol: multi-cloud'ning haqiqiy narxi

Multi-cloud qog'ozda chiroyli, amalda qimmat. Bitta provayder bilan jamoa bitta narsani o'rganadi, ikkita bilan har birini ikki marta:

| Bilim sohasi | Bitta provayder | Ikki provayder |
|--------------|-----------------|----------------|
| Kirish boshqaruvi (IAM) | 1 model | 2 xil model, 2 xil policy tili |
| Tarmoq | 1 model | 2 model va ular orasidagi ulanish |
| Billing | 1 hisob | 2 hisob va provayderlar orasidagi pullik trafik |
| Monitoring, deploy | 1 pipeline | 2 pipeline yoki umumiy maxraj darajasidagi bitta |

Shuning uchun ko'p jamoalar bitta asosiy provayder va bir nechta SaaS bilan ishlaydi.

### Real ishda qachon kerak

- Bank yoki davlat tashkiloti bilan ishlaganda: "ma'lumot mamlakatdan chiqmasin" talabi private yoki hybrid modelga olib keladi.
- Arxitektura muhokamasida "lock-in bo'lmasin, multi-cloud qilamiz" taklifi chiqsa, yuqoridagi jadval bilan narxini ko'rsatasiz.

### Nima uchun shunday

Public cloud arzonligining manbai aynan bo'lishishda: provayder temirni bir marta sotib olib, minglab mijozning turli vaqtdagi yuklamasiga taqsimlaydi. Private cloud bu foydadan voz kechib, evaziga to'liq nazorat va joylashuv kafolatini oladi. Hybrid ko'pincha ongli tanlov emas, tarixning natijasi: eski tizimlarni birdaniga ko'chirib bo'lmaydi.

## 4. Region va availability zone

### Uch daraja

- **Region**: geografik hudud (masalan AWS `eu-central-1`, Frankfurt). Regionlar bir-biridan mustaqil: resurs, narx, mavjud xizmatlar ro'yxati region bo'yicha farq qiladi.
- **Availability zone (AZ)**: region ichidagi, alohida elektr ta'minoti va tarmog'i bor bir yoki bir nechta data-markaz. Bir regionda odatda uch va undan ko'p AZ bo'ladi, ular orasida past latency'li tarmoq bor. AZ nomi region nomiga harf qo'shib yoziladi: `eu-central-1a`, `eu-central-1b`.
- **Edge location**: CDN (statik fayllarni foydalanuvchiga yaqin nuqtadan tarqatadigan tarmoq) va DNS nuqtalari, foydalanuvchiga yaqin, regiondan ancha ko'p. Yuqoridagi `x-vercel-id` dagi `hkg1` shunday nuqta edi.

### Mexanizm: nosozlik chegarasi

Bular nosozlik chegaralari (failure domain: bitta nosozlik ta'sir qiladigan hudud). Bitta VM bitta AZ da yashaydi: AZ o'chsa VM ham o'chadi. Yuqori mavjudlik (high availability) uchun dastur kamida ikki AZ ga yoyiladi, region darajasidagi halokatdan himoya uchun ikkinchi regionda nusxa (disaster recovery) kerak.

Resurslarning doirasi (scope) har xil, bu AWS'da ham, boshqalarda ham shunday:

| Doira | AWS misollari |
|-------|---------------|
| Global | IAM, Route 53, CloudFront, billing |
| Region | VPC, S3 bucket (nomi global noyob, ma'lumot regionda), security group |
| AZ | EC2 instans, EBS volume, subnet |

**Tuzoq: konsolda "resurslarim yo'qolib qoldi".** Konsol va CLI bir vaqtda bitta regionni ko'rsatadi. Boshqa regionda yaratilgan instans ko'rinmaydi, lekin pul oladi. 3-darsda barcha regionlarni aylanib tekshiradigan skript yozasiz.

### Misol: uch regiongacha kechikishni o'lchash

Latency bu so'rov yuborilgandan javob kelguncha o'tgan vaqt. `curl` ulanishning har bosqichini alohida o'lchab bera oladi:

```
$ curl -o /dev/null -s -w 'dns=%{time_namelookup} connect=%{time_connect}\n' https://ec2.eu-central-1.amazonaws.com
dns=0.085073 connect=0.264639
$ curl -o /dev/null -s -w 'dns=%{time_namelookup} connect=%{time_connect}\n' https://ec2.ap-south-1.amazonaws.com
dns=0.103704 connect=0.299063
$ curl -o /dev/null -s -w 'dns=%{time_namelookup} connect=%{time_connect}\n' https://ec2.us-east-1.amazonaws.com
dns=0.192985 connect=0.442810
```

Bu shu repo turgan Zorin mashinasidan bir marta olingan o'lchov, sizda raqamlar boshqa bo'ladi. O'qish: vaqtlar soniyada va so'rov boshidan hisoblanadi. `time_namelookup` DNS javobi kelgan payt (0.085 s), `time_connect` TCP ulanish o'rnatilgan payt (0.265 s). Demak TCP ulanishning o'zi `0.265 - 0.085 = 0.18` soniya olgan: bu bitta borib-kelish (round trip), ya'ni tarmoq masofasining eng toza o'lchovi. Frankfurt va Mumbay deyarli teng chiqdi, AQSH sharqi sezilarli uzoq. O'zbekistondan qaralsa xaritada Mumbay Frankfurtdan yaqinroq, lekin tarmoq yo'li geografiyaga mos kelishi shart emas. Bitta o'lchov tasodifiy bo'lishi mumkin, shuning uchun vazifada bir necha marta o'lchab o'rtacha olasiz.

### Region tanlash mezonlari

Muhimlik tartibida:

1. **Qonun va ma'lumot joylashuvi (data residency)**: ba'zi ma'lumotlar mamlakat ichida saqlanishi shart bo'lishi mumkin. O'zbekistonda shaxsga doir ma'lumotlar bo'yicha lokalizatsiya talabi bor, real loyihada buni huquqshunos bilan aniqlang.
2. **Foydalanuvchiga yaqinlik (latency)**: taxmin qilmang, o'lchang.
3. **Xizmat mavjudligi**: yangi xizmatlar hamma regionda bo'lmaydi.
4. **Narx**: bir xil instans turli regionda turlicha turadi.

### Real ishda qachon kerak

- "Sayt sekin" shikoyatida: server foydalanuvchidan uzoq regionda bo'lsa, har so'rovga yuzlab millisekund qo'shiladi va buni kod optimizatsiyasi tuzatmaydi.
- Hisobda notanish xarajat chiqqanda: birinchi gumon boshqa regionda unutilgan resurs.
- Arxitektura chizishda: "bitta AZ o'chsa nima bo'ladi" savoliga javob bo'lishi kerak.

### Nima uchun shunday

Regionlarning mustaqilligi ataylab qilingan: bitta regiondagi nosozlik yoki xato sozlama boshqalariga tarqalmasligi kerak. Shu sababli resurslar region bo'yicha ajratilgan va konsol bittasini ko'rsatadi, noqulayligi ham shundan. AZ esa murosa: bir-biridan yetarlicha uzoq (bitta yong'in yoki elektr uzilishi ikkalasiga tegmaydi), lekin yetarlicha yaqin (orasidagi tarmoq tez, ma'lumotni sinxron nusxalash mumkin).

## 5. Shared responsibility model

### Chegara

AWS ta'rifi: provayder "security **of** the cloud" uchun, mijoz "security **in** the cloud" uchun javob beradi. Boshqa provayderlarda nomi boshqa, mazmuni bir xil.

| Provayder javobgar | Siz javobgar |
|--------------------|--------------|
| Bino, elektr, sovutish, jismoniy xavfsizlik | Akkauntga kirish: parol, MFA, IAM policy'lar |
| Server temiri, disk almashtirish | OS patch'lari (IaaS da), dastur va uning kutubxonalari |
| Hypervisor, mijozlar orasidagi izolyatsiya | Tarmoq qoidalari: security group, ochiq portlar |
| Managed xizmatning o'zi (RDS engine, S3 chidamliligi) | Ma'lumot: shifrlash, backup, kim o'qiy oladi |
| Global tarmoq | Kalitlar va secret'lar, ularni git'ga tushirmaslik |

MFA bu parolga qo'shimcha ikkinchi tasdiq (telefon ilovasidagi kod), IAM bu kim nimaga kira olishini boshqaradigan xizmat, security group bu VM oldidagi tarmoq firewall'i. Uchalasi 2 va 3-darslarda batafsil.

### Mexanizm: chegara model bilan birga siljiydi

Model yuqoriga ko'tarilgan sari (IaaS, PaaS, SaaS) sizning ulushingiz kamayadi, lekin hech qachon nolga tushmaydi: ochiq qoldirilgan S3 bucket (S3 dagi fayllar "papkasi"), sizib chiqqan access key, `0.0.0.0/0` ga (ya'ni butun internetga) ochiq 22-port doim mijoz aybi. Provayder siz bergan buyruqni aniq bajaradi, u buyruq xato bo'lsa ham.

### Misol: bitta hodisani chegaraga solish

Tasavvur qiling: dasturchi AWS access key'ni `.env` fayli bilan birga ochiq GitHub repo'ga commit qildi, bir soatdan keyin akkauntda begona VM'lar paydo bo'ldi. Tahlil:

| Savol | Javob |
|-------|-------|
| Provayder infratuzilmasi buzildimi | Yo'q: API to'g'ri kalit bilan kelgan so'rovni bajardi |
| Kalit kimning javobgarligida | Mijozning (jadvalning o'ng ustuni, oxirgi qator) |
| Nima oldini olar edi | `.gitignore`, uzoq muddatli kalit o'rniga vaqtinchalik credential, kalitga minimal huquq, budget alert (2-dars) |

Frontend tajribasidan o'xshash holat: `NEXT_PUBLIC_` prefiksi bilan secret'ni bundle'ga chiqarib yuborish. Vercel buni to'xtatmaydi, chunki bu platforma chegarasidan tashqarida, sizning tomoningizda.

**Tuzoq: "provayder backup oladi".** Provayder diskning buzilmasligini ta'minlaydi, lekin siz `DROP TABLE` qilsangiz yoki bucket'ni o'chirsangiz u buyruqni aniq bajaradi. Chidamlilik (durability: saqlangan ma'lumot temir nosozligidan yo'qolmasligi) backup emas. Backup siz yoqmaguningizcha yo'q.

### Real ishda qachon kerak

- Xavfsizlik auditi yoki mijoz so'rovnomasida: "bu nazorat kimda" degan har savolga shu jadval bilan javob beriladi.
- Incident'dan keyin: provayderga shikoyat yozishdan oldin hodisa chegaraning qaysi tomonida ekanini aniqlaysiz.

### Nima uchun shunday

Provayder sizning ma'lumotingiz ichiga qaramaydi va qaray olmasligi kerak: qaysi bucket ataylab ochiq (statik sayt), qaysi biri xato bilan ochiq ekanini u bilmaydi. Shuning uchun u faqat o'zi ko'ra oladigan qatlamga (temir, hypervisor, xizmatning o'zi) kafolat beradi. Muqobili (provayder hamma narsaga javob beradi) faqat SaaS'da bor va u yerda ham kirish huquqlari sizda qoladi.

## 6. Narx modellari

### Nima uchun pul olinadi

| O'lchov | Misol | E'tibor |
|---------|-------|---------|
| Hisoblash vaqti | VM soniya yoki soat bo'yicha | To'xtatilgan VM hisoblash uchun to'lamaydi, lekin diski uchun to'laydi |
| Saqlash | GB-oy: disk, object storage, snapshot | Instans o'chirilgach qolgan disk va snapshot'lar to'lashda davom etadi |
| So'rovlar | API chaqiruvlari, funksiya chaqiruvlari | Kichik, lekin millionlab bo'lsa seziladi |
| Trafik | Chiquvchi (egress) trafik pullik, kiruvchi odatda bepul | Hyperscaler'larda eng kutilmagan xarajat; AZ va region orasidagi trafik ham pullik |
| Ajratilgan resurs | Public IPv4 manzil, NAT gateway, load balancer | Trafik bo'lmasa ham soatbay to'lanadi |

Object storage bu fayllarni disk emas, HTTP API orqali saqlaydigan xizmat (S3, 3-dars). Snapshot bu diskning ma'lum paytdagi nusxasi. NAT gateway bu ichki tarmoqdagi mashinalarga internetga chiqish beradigan xizmat, load balancer so'rovlarni bir nechta server orasida taqsimlaydi.

### Mexanizm: hisob qanday yig'iladi

Hisob bitta narx emas, o'lchovlar yig'indisi. Har o'lchov uchun formula bir xil: `miqdor × birlik narxi × vaqt`. Pastdagi jadvalda narxlar o'rnida harflar turibdi, chunki haqiqiy raqamlarni vazifada o'zingiz rasmiy sahifadan olasiz:

| Qator | Miqdor | Birlik | Formula |
|-------|--------|--------|---------|
| VM | 1 dona | soat | `1 × P_vm × oydagi soatlar` |
| Disk | `<N>` GB | GB-oy | `N × P_disk` |
| Public IPv4 | 1 dona | soat | `1 × P_ip × oydagi soatlar` |
| Egress | `<T>` GB | GB | `T × P_egress` |

O'qish: birinchi va uchinchi qator vaqtga bog'liq, VM ishlamasa birinchisi to'xtaydi, lekin IP manzil ajratilgan bo'lsa uchinchisi davom etadi. Ikkinchi qator VM to'xtatilganda ham to'lanadi. To'rtinchisi faqat foydalanuvchilar ma'lumot yuklab olganda o'sadi va oldindan aytish eng qiyin qator. Vercel hisobidagi "bandwidth" qatori aynan shu egress'ning PaaS ko'rinishi.

### Sotib olish usullari

| Model | G'oya | Qachon | Xavf |
|-------|-------|--------|------|
| On-demand | Majburiyatsiz, ishlatgancha | O'qish, tajriba, oldindan noma'lum yuklama | Eng qimmat birlik narx |
| Reserved, Savings Plans, committed use | 1 yoki 3 yilga majburiyat evaziga chegirma | Barqaror, doim ishlaydigan yuklama (database, asosiy servis) | Ehtiyoj o'zgarsa ham to'laysiz |
| Spot, preemptible | Provayderning bo'sh quvvati katta chegirma bilan, istalgan payt qaytarib olinishi mumkin (AWS 2 daqiqa oldin ogohlantiradi) | Uzilishga chidamli ish: batch, CI runner, stateless worker | Database yoki yagona nusxali servis uchun yaramaydi |

### Free tier

Free tier bu o'rganish va sinov uchun cheklangan bepul hajm yoki kredit. Shartlari (muddat, qaysi xizmat, qancha) provayder va akkaunt ochilgan sanaga qarab farq qiladi va o'zgarib turadi. Har doim rasmiy sahifadan o'qing: https://aws.amazon.com/free/, https://cloud.google.com/free, https://azure.microsoft.com/free/.

**Tuzoq: free tier himoya emas.** Limitdan oshganingizda xizmat to'xtamaydi, shunchaki pul yozila boshlaydi. Himoya bu budget alert (2-dars) va resurslarni o'chirish odati.

### Real ishda qachon kerak

- Oylik hisob kutilgandan katta chiqqanda: qatorlarni shu besh o'lchov bo'yicha ajratib, qaysi biri o'sganini topasiz.
- Yangi servis rejalashtirishda: faqat VM narxini emas, disk, IP, trafik va backup'ni ham qo'shib hisoblaysiz.

### Nima uchun shunday

Provayder uchun xarajat keltiradigan har narsa alohida o'lchanadi, shuning uchun narx murakkab. Egress qimmatligining tijoriy sababi ham bor: ma'lumotni kiritish bepul, chiqarish pullik bo'lsa, mijozning boshqa provayderga ko'chishi qimmatlashadi. Public IPv4 uchun pul olinishi esa IPv4 manzillar tanqisligidan. Developer cloud'lar (7-bo'lim) aynan shu murakkablikka qarshi sodda, oldindan ma'lum oylik narx bilan raqobat qiladi.

## 7. Provayder turlari

### To'rt tur

| Tur | Misollar | Kuchli tomoni | Zaif tomoni |
|-----|----------|---------------|-------------|
| Hyperscaler | AWS, Google Cloud, Microsoft Azure | Yuzlab managed xizmat, ko'p region, ish bozorida eng ko'p so'raladi, enterprise talablari (compliance, IAM) | Murakkab narx, egress qimmat, o'rganish egri chizig'i tik |
| Developer cloud | DigitalOcean, Hetzner Cloud, Linode (Akamai), Vultr | Sodda va oldindan ma'lum narx, tez boshlash, arzon VM va trafik | Xizmatlar kam, regionlar kam, IAM sodda |
| Mahalliy provayder | Mamlakat ichidagi data-markazlar | Ma'lumot mamlakat ichida, mahalliy foydalanuvchiga past latency, mahalliy valyutada to'lov | API va avtomatlashtirish darajasi turlicha, managed xizmatlar kam |
| Edge, PaaS platformalar | Cloudflare, Vercel, Fly.io, Render | Deploy juda sodda, global tarqatish | Platforma chegaralari, o'sganda narx, vendor lock-in |

Compliance bu tashqi standart yoki qonun talablariga muvofiqlik (audit, sertifikatlar).

### Mexanizm: bir xil tushuncha, boshqa nom

Provayderlar bir xil qurilish bloklarini sotadi, faqat nomlari boshqa. Bu jadval butun modul davomida kerak bo'ladi: AWS'da o'rgangan har tushunchaning boshqa joyda nomi bor.

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| Virtual mashina | EC2 | Compute Engine | Virtual Machines | Droplets | Cloud Servers |
| Virtual tarmoq | VPC | VPC | Virtual Network (VNet) | VPC | Networks |
| Tarmoq firewall | Security Group | VPC firewall rules | Network Security Group | Cloud Firewalls | Firewalls |
| Blok disk | EBS | Persistent Disk | Managed Disks | Volumes | Volumes |
| Object storage | S3 | Cloud Storage | Blob Storage | Spaces | Object Storage |
| Statik IP | Elastic IP | Static external IP | Public IP | Reserved IP | Primary IP, Floating IP |
| Load balancer | Elastic Load Balancing | Cloud Load Balancing | Load Balancer, Application Gateway | Load Balancers | Load Balancers |
| DNS | Route 53 | Cloud DNS | Azure DNS | DNS | DNS |
| Kirish boshqaruvi | IAM | IAM | Microsoft Entra ID va Azure RBAC | Teams, API tokens | Projects, API tokens |
| Managed database | RDS | Cloud SQL | Azure Database for PostgreSQL/MySQL | Managed Databases | hujjatdan tekshiring |
| Konteyner PaaS | App Runner, ECS Fargate | Cloud Run | Container Apps | App Platform | yo'q |
| FaaS | Lambda | Cloud Run functions | Azure Functions | Functions | yo'q |
| Managed Kubernetes | EKS | GKE | AKS | DOKS | hujjatdan tekshiring |
| CLI | `aws` | `gcloud` | `az` | `doctl` | `hcloud` |

Provayderlar xizmat qo'shib va nomini o'zgartirib turadi, jadvalni vazifada o'zingiz rasmiy hujjat bilan solishtirasiz.

### Misol: jadvalni o'qish

"Menga Linux server, uning oldida firewall va fayllar uchun saqlash joyi kerak" degan bitta talab AWS'da "EC2, Security Group, S3", DigitalOcean'da "Droplet, Cloud Firewall, Spaces" bo'ladi. Qatorni chapdan o'ngga o'qing: tushuncha bitta, mahsulot nomi beshta. Vakansiyada "GCP tajribasi" yozilgan bo'lsa, AWS'da o'rgangan VPC va IAM bilimingizning katta qismi o'sha yerda ham ishlaydi, faqat nomlar va tafsilotlar almashadi.

### Real ishda qachon kerak

- Boshqa provayder hujjatini o'qiyotganda: notanish nomni shu jadval orqali tanish tushunchaga tarjima qilasiz.
- Kichik loyihaga provayder tanlashda: faqat VM va object storage kerak bo'lsa, hyperscaler murakkabligi ortiqcha bo'lishi mumkin.

### Nima uchun shunday

Hyperscaler'lar keng xizmat ro'yxati bilan katta korxonalarni, developer cloud'lar soddalik va narx bilan kichik jamoalarni, PaaS'lar deploy qulayligi bilan mahsulot jamoalarini nishonga oladi. Bozor bo'lingan, chunki bitta provayder bir vaqtda ham eng sodda, ham eng to'liq bo'la olmaydi.

## 8. Managed xizmat yoki self-hosted

### Bitta misolda

Managed xizmat bu provayder o'rnatadigan, yangilaydigan va tiklaydigan tayyor xizmat; self-hosted bu xuddi shu dasturni VM'ga o'zingiz o'rnatib yuritish. Misol: PostgreSQL ni VM'ga o'zingiz o'rnatish yoki managed database olish.

| Mezon | Self-hosted (VM'da) | Managed |
|-------|---------------------|---------|
| To'g'ridan-to'g'ri narx | Past: faqat VM va disk | Yuqori: xuddi shu quvvat qimmatroq |
| Yashirin narx | Sizning vaqtingiz: o'rnatish, patch, backup, replikatsiya, failover, monitoring, tungi qo'ng'iroq | Kam |
| Nazorat | To'liq: versiya, extension, konfiguratsiya, OS | Cheklangan: superuser yo'q, extension ro'yxati provayderda |
| Backup va tiklash | O'zingiz quraysiz va sinaysiz | Tugma bilan, point-in-time recovery |
| Ko'chirish (portability) | Oson: oddiy PostgreSQL | Engine standart bo'lsa oson, provayderga xos xizmat bo'lsa qiyin |
| Bilim talabi | Chuqur | Yuzaki yetadi (bu ham xavf: buzilganda tushunmaysiz) |

Replikatsiya bu ma'lumotning ikkinchi serverdagi doimiy nusxasi, failover asosiy server yiqilganda nusxaga avtomatik o'tish, point-in-time recovery database'ni o'tmishdagi istalgan daqiqa holatiga qaytarish.

### Mexanizm: umumiy xarajat

Solishtiriladigan narsa oylik hisob emas, umumiy xarajat: `to'g'ridan-to'g'ri narx + muhandis soatlari × soat qiymati + nosozlik xavfi`. Self-hosted variantda birinchi qo'shiluvchi kichik, ikkinchisi katta; managed'da aksincha.

Amaliy qoida: **holatli (stateful) va buzilishi qimmatga tushadigan narsani (database, navbat, object storage) managed oling, holatsiz (stateless) dasturni qayerda ishlatish esa ikkinchi darajali savol.** Stateful bu ma'lumotni o'zida saqlaydigan servis (yo'qolsa tiklab bo'lmaydi), stateless bu o'chirib qayta yoqsa hech narsa yo'qotmaydigan servis. Kichik jamoa uchun muhandis soati VM narxidan ancha qimmat. Istisno: o'rganish (bu kurs), juda katta hajm, yoki managed variant bermaydigan sozlama kerak bo'lganda.

### Misol: lock-in darajalari

**Vendor lock-in** bu bitta provayderga shunchalik bog'lanib qolishki, ko'chish qimmat bo'ladi.

| Daraja | Misol | Ko'chish |
|--------|-------|----------|
| Deyarli yo'q | VM, konteyner | istalgan joyga ko'chadi |
| Past | standart protokolli managed xizmat: PostgreSQL, Redis, S3 API | ma'lumotni ko'chirish va manzilni almashtirish |
| Yuqori | provayderga xos xizmat: DynamoDB, Lambda trigger'lari, IAM bilan chuqur integratsiya | kodni qayta yozish |

Lock-in o'z-o'zidan yomon emas, u tezlik evaziga to'lanadigan narx. Yomoni uni bilmasdan olish. Frontend'dagi o'xshashi: Next.js'ni Vercel'ga xos funksiyalar (masalan platformaning o'z image optimizatsiyasi yoki edge middleware) bilan qursangiz, boshqa hosting'ga ko'chish o'sha funksiyalarni almashtirishni talab qiladi.

### Real ishda qachon kerak

- "Database'ni qayerda turg'izamiz" savoli har yangi loyihada beriladi va javobi shu jadvaldan chiqadi.
- 4-darsda dasturni VM'ga qo'lda deploy qilasiz: bu o'rganish uchun, real kichik jamoa uchun esa ko'pincha PaaS yoki managed variant to'g'riroq bo'lishini bilgan holda.

### Nima uchun shunday

Managed xizmat provayder uchun ham foydali (ustama narx), mijoz uchun ham (bitta database administratorini yollashdan arzon). Bu mehnat taqsimoti: provayder bitta ishni minglab mijoz uchun avtomatlashtirgan. Self-hosted muqobili yo'qolmaydi, chunki nazorat va narx ma'lum hajmdan keyin muhimroq bo'lib qoladi.

## 9. Qanday tanlash kerak

### Savollar tartibi

1. **Cheklovlar**: ma'lumot qayerda turishi shart, qanday compliance kerak, to'lov usuli (karta, valyuta) bormi.
2. **Foydalanuvchi qayerda**: latency o'lchovi.
3. **Jamoa nimani biladi**: tanish provayder noma'lum "eng yaxshi" provayderdan tezroq natija beradi.
4. **Qaysi managed xizmatlar kerak**: faqat VM va object storage bo'lsa developer cloud yetadi; navbat, managed Kubernetes, data warehouse kerak bo'lsa hyperscaler.
5. **Narx**: bir oylik real ssenariyni kalkulyatorda hisoblang (VM, disk, trafik, backup, IP), faqat VM narxini solishtirmang.
6. **Chiqish yo'li**: bir yildan keyin ko'chish kerak bo'lsa nima to'sqinlik qiladi.

### Mexanizm: tartib nima uchun shunday

Ro'yxat "eng kam o'zgartirib bo'ladigan" mezondan boshlanadi. Qonun talabini muzokara qilib bo'lmaydi, shuning uchun u birinchi va variantlarni darhol qisqartiradi. Narx esa beshinchi: uni arxitektura bilan boshqarish mumkin. Har savol keyingisi uchun variantlar ro'yxatini toraytiradi.

### Misol: qarorni yozib qo'yish (ADR)

Architecture Decision Record (ADR) bu bitta qarorni bir sahifada qayd qiladigan hujjat. Skeleti:

```
# ADR-003: Message queue for background jobs
## Context
What problem, which constraints, what numbers we measured.
## Options
A, B, C with one line of trade-offs each.
## Decision
What we chose and the main reason.
## Consequences
What gets easier, what gets harder, what would make us revisit this.
```

Qatorma-qator: `Context` qaror qabul qilingan paytdagi sharoit (olti oydan keyin "nega bunday qilgan ekanmiz" savoliga javob), `Options` ko'rib chiqilgan muqobillar (faqat tanlangani emas), `Decision` bitta aniq gap, `Consequences` qarorning narxi va qaysi taxmin o'zgarsa qayta ko'rish kerakligi. Bu frontend jamoalaridagi RFC yoki "tech decision" hujjatining aynan o'zi.

### Nima uchun bu kursda AWS

Xizmat modeli eng to'liq, hujjati va ish bozoridagi talabi eng katta, IAM va VPC modeli boshqa provayderlarni tushunish uchun yaxshi asos. AWS'da VPC va IAM ni tushungan odam DigitalOcean'ni bir kunda o'zlashtiradi, teskarisi qiyinroq.

### Real ishda qachon kerak

- Yangi loyiha boshida va har yirik komponent qo'shilganda.
- Ishga kirganingizda mavjud tanlovni tushunish uchun: ADR bo'lmasa, shu olti savolni jamoaga berasiz.

### Nima uchun shunday

Provayderni o'zgartirish qimmat, shuning uchun qaror yozma va asoslangan bo'lishi kerak. "Eng yaxshi provayder" degan umumiy javob yo'q: bir xil provayder bitta cheklovlar to'plamida to'g'ri, boshqasida noto'g'ri tanlov. Tartibli savollar ro'yxati shaxsiy didni o'lchanadigan mezonlarga almashtiradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Cloud | API orqali boshqariladigan, ishlatganga to'lanadigan birovning data-markazi |
| API endpoint | xizmatning so'rov qabul qiladigan manzili, AWS'da har region uchun alohida |
| IaaS | provayder VM, disk va tarmoq beradi, OS dan yuqorisi sizda |
| PaaS | kod yoki image berasiz, platforma ishga tushiradi va yangilaydi |
| FaaS | hodisaga javoban ishlaydigan, chaqiruvga to'lanadigan funksiya |
| SaaS | tayyor dastur, siz faqat foydalanasiz va kirishni boshqarasiz |
| Serverless | serverni mijoz ko'rmaydigan va boshqarmaydigan model (FaaS, ba'zi PaaS) |
| Cold start | uzoq chaqirilmagan funksiyaning birinchi so'rovdagi qo'shimcha kechikishi |
| On-premises | infratuzilma o'z binoyingizda |
| Multi-tenancy | bitta temir bir nechta mijoz orasida bo'lishilishi |
| Hypervisor | jismoniy serverda VM'larni ishga tushiradigan va ajratadigan dastur |
| Region | provayderning mustaqil geografik hududi |
| Availability zone (AZ) | region ichidagi alohida elektr va tarmoqli data-markaz(lar) |
| Edge location | foydalanuvchiga yaqin CDN va DNS nuqtasi |
| Failure domain | bitta nosozlik ta'sir qiladigan hudud (VM, AZ, region) |
| High availability | bitta komponent o'chganda ham xizmat ishlashda davom etishi |
| Disaster recovery | katta halokatdan (region) keyin tiklash rejasi va zaxirasi |
| Data residency | ma'lumot qaysi mamlakatda saqlanishi haqidagi talab |
| Latency | so'rov yuborilgandan javob kelguncha o'tgan vaqt |
| Shared responsibility | xavfsizlik vazifalarining provayder va mijoz orasida bo'linishi |
| Durability | saqlangan ma'lumot temir nosozligidan yo'qolmasligi |
| Backup | ma'lumotning alohida saqlanadigan, tiklab ko'rilgan nusxasi |
| Egress | cloud'dan tashqariga chiquvchi trafik |
| On-demand | majburiyatsiz, ishlatgancha to'lanadigan narx modeli |
| Reserved, Savings Plan | 1 yoki 3 yillik majburiyat evaziga chegirma |
| Spot | bo'sh quvvat arzon narxda, istalgan payt qaytarib olinadi |
| Free tier | cheklangan bepul hajm yoki kredit, limit emas |
| CapEx, OpEx | oldindan to'lanadigan kapital xarajat, ishlatganga qarab operatsion xarajat |
| Hyperscaler | juda keng xizmat va regionga ega yirik provayder (AWS, GCP, Azure) |
| Managed xizmat | provayder o'rnatadigan, yangilaydigan va tiklaydigan xizmat |
| Self-hosted | dasturni VM'da o'zingiz o'rnatib yuritish |
| Stateful, stateless | ma'lumotni o'zida saqlaydigan va saqlamaydigan servis |
| Vendor lock-in | provayderga bog'lanish tufayli ko'chishning qimmatlashishi |
| ADR | bitta arxitektura qarorini qayd qiladigan qisqa hujjat |

## Tuzoqlar

- Chidamlilikni backup deb o'ylash: provayder sizning xato buyrug'ingizdan himoya qilmaydi.
- Faqat VM narxini solishtirish: egress trafik, public IPv4, NAT gateway, snapshot va load balancer hisobni bir necha barobar o'zgartiradi.
- Bitta AZ dagi bitta VM ni "cloud'da, demak ishonchli" deb hisoblash: bu oddiy bitta server, faqat birovning binosida.
- Free tier'ni limit deb o'ylash: u limit emas, chegirma. Oshsangiz xizmat to'xtamaydi, hisob keladi.
- Noto'g'ri regionda resurs yaratib unutish: konsol faqat tanlangan regionni ko'rsatadi.
- Region tanlashda latency'ni xaritaga qarab taxmin qilish: tarmoq yo'li geografiyaga mos kelmasligi mumkin, o'lchang.
- Bitta o'lchovga ishonish: birinchi so'rov DNS kesh bo'sh bo'lgani uchun sekinroq chiqadi, bir necha marta o'lchab o'rtacha oling.
- Ofisdagi o'lchovni uydagi bilan aralashtirish: tarmoq boshqa, natija boshqa. Qaysi mashina va tarmoq ekanini yozing.
- Ma'lumot joylashuvi talabini loyiha oxirida eslash: ko'chirish arxitekturani o'zgartiradi.
- "Lock-in bo'lmasin" deb hamma narsani o'zi ko'tarish: kichik jamoa database administratoriga aylanadi va mahsulot to'xtaydi.
- Spot instansga holatli servis qo'yish: instans ogohlantirishdan keyin qaytarib olinadi.
- SaaS va PaaS da "xavfsizlik provayderda" deb kirish huquqlarini tekshirmaslik: kim kira olishi doim sizda.
- Skriptni faqat bitta mashinada sinash: Zorin'da ishlagan GNU flag'i macOS'ning BSD utilitasida ishlamasligi mumkin.

## Manbalar

- https://csrc.nist.gov/pubs/sp/800/145/final : NIST cloud ta'rifi: besh xususiyat, uch xizmat modeli, to'rt joylashtirish modeli (7 bet, majburiy)
- https://aws.amazon.com/compliance/shared-responsibility-model/ : AWS shared responsibility model
- https://aws.amazon.com/about-aws/global-infrastructure/regions_az/ : region va AZ tuzilishi
- https://docs.aws.amazon.com/whitepapers/latest/aws-overview/introduction.html : AWS xizmatlariga umumiy sharh
- https://docs.aws.amazon.com/whitepapers/latest/how-aws-pricing-works/welcome.html : AWS narxlari qanday ishlaydi
- https://aws.amazon.com/ec2/pricing/ : EC2 narx modellari (on-demand, Savings Plans, spot)
- https://calculator.aws/ : AWS Pricing Calculator
- https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison : AWS, Azure va Google Cloud xizmatlari mosligi
- https://learn.microsoft.com/azure/architecture/aws-professional/ : Azure, AWS mutaxassislari uchun
- https://www.digitalocean.com/pricing va https://www.hetzner.com/cloud : developer cloud narx sahifalari
- https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html : Well-Architected Framework (Cost Optimization va Reliability ustunlari)
- https://curl.se/docs/manpage.html : `curl` qo'llanmasi, `--write-out` o'zgaruvchilari (`time_namelookup`, `time_connect`)

---

## Birga bajaramiz

Bitta yaxlit misol: o'zingiz bilgan PaaS'dagi saytni operator ko'zi bilan tahlil qilamiz. Vazifalardagi holatlardan boshqa: bu yerda bitta tayyor sayt (`vercel.com` ning o'zi) olinadi va unga darsning besh tushunchasi ketma-ket qo'llanadi. Hammasi host'da, akkauntsiz.

1. Sayt qayerda turganini DNS'dan so'rang:

```
$ dig +short vercel.com
<IP manzil>
<IP manzil>
```

Bir yoki bir nechta IP manzil chiqadi (sizda boshqa). Bular platformaning kirish nuqtalari, sayt egasining serveri emas. PaaS'da mijoz hech qachon o'z serverining manzilini bilmaydi: bu 2-bo'limdagi jadvalda "Server, disk, tarmoq: provayder" qatori.

2. Javob sarlavhalaridan qatlamlarni o'qing:

```
$ curl -sI https://vercel.com | grep -iE '^(HTTP|server|x-vercel-id|cache-control)'
HTTP/2 200
cache-control: <qiymat>
server: Vercel
x-vercel-id: <edge>::<region>::<id>
```

`HTTP/2 200`: TLS va HTTP/2 ni platforma ta'minladi, sertifikatni hech kim qo'lda o'rnatmagan (IaaS'da bu ish 4-darsda sizniki). `server: Vercel`: javob bergan dastur platformaniki. `x-vercel-id` ning birinchi qismi sizga eng yaqin edge location, ikkinchisi kod bajarilgan region: 4-bo'limdagi "edge" va "region" farqi bitta sarlavhada.

3. Kirish nuqtasigacha kechikishni o'lchang va 4-bo'limdagi region o'lchovi bilan solishtiring:

```
$ curl -o /dev/null -s -w 'dns=%{time_namelookup} connect=%{time_connect}\n' https://vercel.com
dns=<a> connect=<b>
```

`b - a` bu edge nuqtagacha bitta borib-kelish vaqti. Odatda u uzoq regiondagi API endpoint'iga o'lchangan qiymatdan kichik chiqadi: edge foydalanuvchiga yaqin qo'yiladi, region esa yo'q. Agar teng yoki katta chiqsa, sizga eng yaqin edge ham aslida uzoqda degani: bu ham natija, yozib qo'ying.

4. Javobgarlik chegarasini chizing. Shu saytning egasi bo'lsangiz:

| Narsa | Kimda |
|-------|-------|
| Edge serverlar, TLS, build mashinalari | platforma |
| Kod, kutubxonalardagi zaiflik (`npm audit`) | siz |
| Environment variable'lardagi secret'lar, jamoa a'zolarining kirish huquqi | siz |
| Platforma akkauntiga MFA | siz |

5. Narx o'lchovlarini toping. Platformaning narx sahifasini oching va 6-bo'limdagi besh o'lchovdan qaysilari borligini belgilang: build daqiqalari (hisoblash vaqti), bandwidth (egress), funksiya chaqiruvlari (so'rovlar). Raqamlarni yozmaymiz, faqat o'lchov turlarini: xuddi shu besh o'lchov AWS hisobida ham bo'ladi, faqat maydaroq bo'laklarda.

6. Lock-in'ni baholang: statik fayllar (deyarli yo'q, istalgan hosting'ga ko'chadi), server funksiyalari (past yoki o'rta, runtime'ga bog'liq), platformaga xos funksiyalar (yuqori).

Xulosa: bitta saytda xizmat modeli, edge va region, javobgarlik chegarasi, narx o'lchovlari va lock-in ko'rindi. Vazifalarda xuddi shu ko'zoynakni AWS xizmatlariga va o'z loyihangizga qo'llaysiz.

---

## Vazifalar

Vazifalarni `cloud/01-providers/` papkasida bajaring (`make new m=cloud n=01 name=providers` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida yoziladi: nima qildingiz (buyruq yoki o'qilgan sahifa havolasi), natijaning muhim qismi va o'z so'zingiz bilan izoh. Narx yozilgan har joyda manba havolasi va sana bo'lsin. So'ralgan fayllar (jadval, skript) shu papkada saqlanadi.

### A. Xizmat modellari

1. **Classify services.** Quyidagi 12 xizmatni IaaS, PaaS, FaaS yoki SaaS ga ajrating va har biriga bir gaplik asos yozing: EC2, S3, RDS, Lambda, Vercel, GitHub Actions, Cloudflare Workers, Heroku, Google Workspace, Hetzner Cloud Server, Cloud Run, Datadog. Qaysilarini bitta toifaga sig'dirish qiyin bo'ldi va nima uchun?

   Yo'nalish: 2-bo'limdagi "OS'ga kim patch qo'yadi, yiqilsa kim ko'taradi" savolini har xizmatga bering. Notanish xizmatning rasmiy sahifasidagi birinchi xatboshini o'qing.

2. **Responsibility matrix.** Bitta web dastur (Node API va PostgreSQL) uchun jadval tuzing: qatorlarda 8 ta vazifa (OS patch, runtime yangilash, TLS sertifikat, database backup, disk nosozligi, kirish huquqlari, DDoS himoyasi, dastur zaifligi), ustunlarda uch variant (EC2 da hammasi o'zingiz, Fargate va RDS, Vercel va managed Postgres). Har katakda "men" yoki "provayder" yozing.

   Yo'nalish: 2-bo'limdagi qatlamlar jadvali va 5-bo'limdagi chegara. Ikkilangan katakda "provayder asbob beradi, yoqish menda" holatini alohida belgilang.

3. **Your own stack.** Oxirgi ishlagan frontend loyihangizdagi barcha tashqi xizmatlarni (hosting, CI, monitoring, auth, CDN va boshqalar) sanab chiqing, har birining modelini aniqlang. Qaysi biri o'chib qolsa mahsulot to'xtar edi va o'sha holatda sizning javobgarligingizda nima qolgan edi?

   Yo'nalish: `package.json`, CI konfiguratsiyasi va environment variable'lar ro'yxati tashqi xizmatlarning eng to'liq manbai.

4. **Serverless limits.** AWS Lambda hujjatidan quotas sahifasini toping. Uchta cheklovni (masalan bajarilish vaqti, xotira, payload hajmi) yozing va qaysi turdagi dastur bu modelga sig'masligini izohlang. Raqamlarni hujjatdan oling, manbani ko'rsating.

   Yo'nalish: hujjatda "Lambda quotas" deb qidiring. Har cheklovga "qaysi dastur bunga uriladi" misolini o'ylang (uzoq ulanish, katta fayl, og'ir hisob).

### B. Region va availability zone

5. **Measure latency.** Kamida 5 ta AWS regioniga latency o'lchang. Region endpoint'i `ec2.<region>.amazonaws.com` shaklida. `curl -o /dev/null -s -w '%{time_connect}\n' https://ec2.eu-central-1.amazonaws.com` buyrug'ini har region uchun 5 martadan ishlatadigan `task_5.sh` yozing, o'rtachasini jadvalga kiriting. Natija xaritadagi masofaga mos keldimi? `time_connect` aynan nimani o'lchaydi (network modulini eslang)?

   Yo'nalish: 4-bo'limdagi misol. Skript ikkala mashinada ishlashi kerak: `#!/usr/bin/env bash`, oddiy `for` sikllari, o'rtacha uchun `awk` (ikkalasida bor); `grep -P`, `readarray` va associative array ishlatmang (macOS'dagi bash 3.2 da yo'q). `shellcheck task_5.sh` toza bo'lsin.

6. **Region differences.** AWS regional services sahifasidan foydalanib, siz tanlagan eng yaqin regionda mavjud bo'lmagan ikkita xizmatni toping. Keyin EC2 narx sahifasida bitta instans tipining ikki regiondagi on-demand narxini solishtiring. Xulosa: region tanlashda nimalar hisobga olinadi?

   Yo'nalish: "AWS Services by Region" sahifasi va Manbalardagi EC2 narx sahifasi. Narxga sana va havola qo'ying.

7. **Failure domains.** Uch ssenariyni tahlil qiling: bitta VM o'chdi, butun AZ o'chdi, butun region o'chdi. Har biri uchun: bitta AZ dagi bitta VM da ishlayotgan dasturga nima bo'ladi, undan himoyalanish uchun arxitekturada nima kerak va bu taxminan qancha qo'shimcha murakkablik va xarajat keltiradi?

   Yo'nalish: 4-bo'limdagi "nosozlik chegarasi". Xarajatni raqamda emas, "nechta qo'shimcha resurs va qaysi yangi muammo (ma'lumotni sinxronlash)" ko'rinishida baholang.

8. **Scope of resources.** AWS hujjatidan foydalanib 8 ta resursning doirasini aniqlang (global, region yoki AZ): IAM user, S3 bucket, EC2 instans, EBS volume, VPC, subnet, security group, Route 53 hosted zone. EBS volume'ni boshqa AZ dagi instansga ulab bo'ladimi, bo'lmasa nima qilinadi?

   Yo'nalish: 4-bo'limdagi doira jadvali boshlang'ich nuqta, lekin har javobni hujjatdan tasdiqlang. EBS uchun "snapshot" so'zi kalit.

### C. Javobgarlik va narx

9. **Incident analysis.** Ommaga ma'lum bo'lgan bitta cloud xavfsizlik hodisasini toping (ochiq qolgan bucket yoki sizib chiqqan access key bilan bog'liq), manba havolasini bering. Shared responsibility model bo'yicha ayb kim tomonda edi? Qaysi aniq nazorat choralari uni oldini olar edi?

   Yo'nalish: 5-bo'limdagi misol jadvalining uch savolini o'z hodisangizga bering.

10. **Durability is not backup.** Ikki tushunchani o'z so'zingiz bilan ajrating. Uchta halokat ssenariysini yozing (disk buzildi, dasturchi jadvalni o'chirdi, akkaunt buzib kirilib hammasi o'chirildi) va har birida faqat provayder chidamliligi yordam beradimi yoki alohida backup kerakmi, izohlang.

    Yo'nalish: har ssenariyda "buyruqni kim berdi: temirmi yoki odammi" deb so'rang. Uchinchi ssenariyda backup qayerda turishi kerakligini o'ylang.

11. **Monthly estimate.** AWS Pricing Calculator'da (https://calculator.aws/) kichik loyihani hisoblang: bitta eng kichik umumiy maqsadli instans (oy bo'yi ishlaydi), 30 GB disk, bitta public IPv4, oyiga 100 GB chiquvchi trafik, 50 GB S3. Har qatorning ulushini yozing. Qaysi qator kutilmagan bo'ldi? Hisob havolasini (share link) `README.md` ga qo'ying.

    Yo'nalish: 6-bo'limdagi formula jadvali. Kalkulyatorda har qator alohida xizmat sifatida qo'shiladi (EC2, EBS, VPC ichida public IPv4, data transfer, S3).

12. **Same workload elsewhere.** 11-vazifadagi yuklamani DigitalOcean va Hetzner narx sahifalari bo'yicha hisoblang. Uch provayderni jadvalda solishtiring. Farq asosan qaysi qatordan kelyapti? Arzonroq variantda nimadan voz kechasiz?

    Yo'nalish: developer cloud'larda trafik va IP ko'pincha VM narxiga kiritilgan, qancha kiritilganini narx sahifasidan o'qing. 7-bo'limdagi "zaif tomoni" ustuni.

13. **Purchase models.** Uch yuklama uchun sotib olish modelini tanlang va asoslang: (a) 24/7 ishlaydigan production database, (b) kechasi bir marta ishlaydigan 2 soatlik hisobot, (c) CI runner'lar. Har birida noto'g'ri model tanlansa nima bo'lishini yozing.

    Yo'nalish: 6-bo'limdagi "Sotib olish usullari" jadvalining "Qachon" va "Xavf" ustunlari.

14. **Hidden costs list.** AWS narx hujjatlaridan foydalanib, "resurs ishlatilmayapti, lekin pul olinyapti" holatlaridan kamida oltitasini toping (masalan to'xtatilgan instans diski). Har biri uchun: nima uchun pul olinadi va uni qanday aniqlash mumkin. Bu ro'yxat 3-darsdagi tozalash skriptingizga asos bo'ladi.

    Yo'nalish: 6-bo'limdagi "Saqlash" va "Ajratilgan resurs" qatorlari. Har topilma uchun konsolning qaysi sahifasida ko'rinishini yozing.

### D. Tanlov

15. **Verify the mapping table.** 7-bo'limdagi moslik jadvalidan beshta qatorni tanlang va har bir katakni provayderning rasmiy hujjatidan tekshiring, havolalarini yozing. "Hujjatdan tekshiring" deb yozilgan kataklarni to'ldiring. Nomi yoki mavjudligi o'zgargan xizmat topdingizmi?

    Yo'nalish: har provayderning mahsulotlar ro'yxati sahifasi (products). Jadvaldagi nomga ishonmang, sahifadagi hozirgi nomni yozing.

16. **Managed or self-hosted.** Uch kishilik jamoa, bitta mahsulot, PostgreSQL kerak. Managed database va VM'dagi o'z PostgreSQL uchun bir yillik umumiy xarajatni taxminlang: to'g'ridan-to'g'ri narx (narx sahifasidan) va muhandis vaqti (o'zingiz taxmin qilgan soatlar, taxminni asoslang). Qaysi sharoitda xulosa teskari bo'ladi?

    Yo'nalish: 8-bo'limdagi umumiy xarajat formulasi. Soatlarni ishlar bo'yicha ajrating (o'rnatish, backup'ni sinash, yangilash, nosozlik).

17. **Lock-in audit.** Tasavvur qiling: dastur AWS'da Lambda, DynamoDB, S3 va SQS ustiga qurilgan. Har komponentni boshqa provayderga ko'chirish qiyinligini past, o'rta, yuqori deb baholang va sababini yozing. Qaysi birini standart alternativaga almashtirish ko'chishni eng ko'p osonlashtiradi?

    Yo'nalish: 8-bo'limdagi lock-in darajalari jadvali. Har komponent uchun "boshqa provayderda bir xil API bormi" deb so'rang.

18. **Provider decision record.** Mini-loyiha. `decision.md` yozing (bir sahifa, Architecture Decision Record uslubida: kontekst, variantlar, qaror, oqibatlar). Ssenariy: O'zbekistondagi foydalanuvchilar uchun web dastur (API, PostgreSQL, fayl saqlash), uch kishilik jamoa, cheklangan byudjet, shaxsga doir ma'lumot bor. Kamida uch variantni (hyperscaler, developer cloud, mahalliy provayder yoki aralash) 9-bo'limdagi olti savol bo'yicha solishtiring, 5-vazifadagi latency va 11–12-vazifalardagi narx raqamlaringizni ishlating. Qaysi taxminlar noto'g'ri chiqsa qaroringiz o'zgarishini alohida yozing.

    Yo'nalish: 9-bo'limdagi ADR skeleti va olti savol tartibi. Avval cheklovlar variantlarni qisqartirsin, keyin raqamlar.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 18 ta vazifaning har biri `## N. Title` sarlavhasi ostida, narxlarda manba va sana bor, o'lchovlarda qaysi mashina va tarmoq ekani yozilgan.
2. `task_5.sh` va `decision.md` papkada, `make check` toza. `task_5.sh` ikkala mashinada (Zorin va macOS) ishga tushib ko'rilgan.
3. Hech qanday cloud resurs yaratilmagan (bu darsda kerak emas).
4. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- IaaS va PaaS ni bitta savol bilan qanday ajratasiz?
- Vercel sizdan yashirgan, IaaS'da esa qo'lda qilinadigan kamida to'rtta ishni ayting.
- Qaysi javobgarlik hech bir xizmat modelida provayderga o'tmaydi?
- Region va AZ farqi nima, bitta AZ dagi bitta VM nimadan himoyalanmagan?
- Nima uchun konsolda resurs "ko'rinmay qolishi" mumkin va bu nega xavfli?
- `time_connect` dan `time_namelookup` ni ayirsangiz nima qoladi?
- Chidamlilik (durability) va backup farqi nima?
- To'xtatilgan VM uchun nimalar pul olishda davom etadi?
- Spot instans qaysi yuklamaga mos, qaysisiga mos emas va nima uchun?
- Free tier nima uchun xarajatdan himoya qilmaydi?
- Managed database'ning yashirin foydasi va yashirin narxi nima?
- Vendor lock-in qachon ongli ravishda qabul qilinadigan narx bo'ladi?
