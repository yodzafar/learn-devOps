# 1-dars: Cloud turlari va farqlari

Maqsad: cloud xizmat modellarini (IaaS, PaaS, SaaS, FaaS), joylashtirish modellarini (public, private, hybrid), region va availability zone tuzilishini, shared responsibility modelini va narx shakllanishini tushunish. Siz frontend tomonda Vercel, Netlify, GitHub kabi PaaS va SaaS xizmatlarning iste'molchisi bo'lgansiz, endi xuddi shu narsalarga operator ko'zi bilan qaraysiz: qaysi qatlam kimning javobgarligida, nima uchun pul olinadi, qachon managed xizmat, qachon o'z serveringiz. Bu dars 2–4-darslardagi har bir amaliy qaror (region, instans tipi, S3 yoki disk, VM yoki managed) uchun asos.

Taxminiy vaqt: 2 kun (siz uchun). Atamalar tanish, diqqatni quyidagilarga qarating: javobgarlik chegarasi har modelda qayerdan o'tadi, region va AZ nosozlik chegarasi sifatida, pul nima uchun olinadi (ayniqsa chiquvchi trafik va unutilgan resurslar), managed xizmatning yashirin narxi va foydasi.

## Laboratoriya

Bu darsda resurs yaratilmaydi, akkaunt ham shart emas. Vazifalar tahliliy: rasmiy hujjat va narx sahifalarini o'qish, jadval tuzish, qarorni asoslash. Kerak bo'ladigan narsalar:

- Brauzer: provayderlarning narx sahifalari va kalkulyatorlari (ro'yxatdan o'tmasdan ochiladi).
- Ish mashinasi: `curl`, `ping`, `dig` (network modulidan tanish), latency o'lchash uchun.

Tozalash kerak emas. Narxlar haqidagi har bir raqamni o'zingiz rasmiy sahifadan olasiz va `README.md` da olingan sanasi bilan yozasiz: narxlar va free tier shartlari o'zgarib turadi, bu darsda ataylab bitta ham aniq narx yozilmagan.

---

## 1. Cloud nima

NIST ta'rifi bo'yicha cloud besh xususiyatga ega: o'z-o'ziga xizmat (on-demand self-service: odam bilan gaplashmasdan API orqali resurs olish), tarmoq orqali kirish, resurslar umumiy hovuzi (resource pooling, multi-tenancy), tez elastiklik (kerak bo'lganda ko'paytirish va kamaytirish), o'lchanadigan xizmat (ishlatganingizga to'lash).

Operator uchun asosiy xulosa: **cloud bu API orqali boshqariladigan birovning data-markazi**. Konsol, CLI, Terraform, SDK hammasi bir xil API'ni chaqiradi. Shuning uchun bu modulda har ishni avval konsolda (tushunish uchun), keyin CLI'da (takrorlanuvchan bo'lishi uchun) qilasiz.

Iqtisodiy farq: o'z serveringiz bu oldindan to'lanadigan kapital xarajat (CapEx), cloud bu ishlatganga qarab to'lanadigan operatsion xarajat (OpEx). Cloud doim arzon degani emas: doimiy, oldindan ma'lum yuklama uchun o'z temiringiz yoki arzon dedicated server ko'pincha arzonroq. Cloud tezlik, elastiklik va tayyor xizmatlar uchun tanlanadi.

## 2. Xizmat modellari

Farq bitta savolda: stack'ning qaysi qatlamigacha provayder boshqaradi.

| Qatlam | On-premises | IaaS | PaaS | FaaS | SaaS |
|--------|-------------|------|------|------|------|
| Dastur kodi | siz | siz | siz | siz | provayder |
| Runtime, kutubxonalar | siz | siz | provayder | provayder | provayder |
| OS, patch'lar | siz | siz | provayder | provayder | provayder |
| Virtualizatsiya | siz | provayder | provayder | provayder | provayder |
| Server, disk, tarmoq, bino | siz | provayder | provayder | provayder | provayder |
| Ma'lumot va kirish huquqlari | siz | siz | siz | siz | siz |

Oxirgi qator eng muhimi: ma'lumot va kim nimaga kira olishi har doim sizda qoladi.

| Model | Nima olasiz | Misollar | Nimani yo'qotasiz |
|-------|-------------|----------|-------------------|
| IaaS | VM, disk, tarmoq | AWS EC2, GCP Compute Engine, Azure Virtual Machines, DigitalOcean Droplets, Hetzner Cloud | Vaqt: OS, patch, monitoring, backup sizda |
| PaaS | Kod yoki image berasiz, platforma ishga tushiradi | Heroku, Vercel, Render, AWS Elastic Beanstalk, Google App Engine, Cloud Run | Nazorat: OS, tarmoq, ba'zan runtime versiyasi platforma qo'lida |
| FaaS | Funksiya, hodisaga javoban ishlaydi, chaqiruvga to'lanadi | AWS Lambda, Cloud Run functions, Azure Functions, Cloudflare Workers | Uzoq yashovchi jarayon, lokal holat; cold start, vaqt chegarasi bor |
| SaaS | Tayyor dastur | GitHub, Slack, Google Workspace, Datadog | Deyarli hamma narsa sozlanmaydi, ma'lumot birovda |

Chegaralar aniq emas. Managed database (AWS RDS) bu PaaS ga yaqin: engine patch'i va backup provayderda, sxema va so'rovlar sizda. "Container as a Service" (ECS Fargate, Cloud Run) IaaS va PaaS orasida. Modelni nom bo'yicha emas, "OS'ga kim patch qo'yadi, server yiqilsa kim qayta ko'taradi" savoli bo'yicha aniqlang.

**Tuzoq: "serverless" serverlar yo'q degani emas.** Server bor, faqat siz uni ko'rmaysiz va boshqarmaysiz. Natijada debug qilish imkoniyati ham kamayadi: `ssh` qilib ichiga kirib bo'lmaydi, faqat log va metrikalar.

## 3. Joylashtirish modellari

| Model | Ta'rif | Qachon |
|-------|--------|--------|
| Public cloud | Provayder infratuzilmasi, ko'p mijoz bilan bo'lishilgan, internet orqali API | Ko'p hollarda standart tanlov |
| Private cloud | Bitta tashkilot uchun ajratilgan (o'z data-markazida yoki ijarada), odatda OpenStack, VMware | Qat'iy regulyatsiya, ma'lumot mamlakatdan chiqmasligi shart, juda katta doimiy yuklama |
| Hybrid | Public va private birga, tarmoq bilan ulangan (VPN, ajratilgan kanal) | Eski tizimlar o'z joyida qoladi, yangilari cloud'da; ma'lumot lokal, hisoblash cloud'da |
| Multi-cloud | Bir nechta public provayder | Har biridan eng yaxshi xizmat, yoki bitta provayderga qaramlikni kamaytirish |

Multi-cloud qog'ozda chiroyli, amalda qimmat: jamoa ikki IAM modelini, ikki tarmoq modelini, ikki billing'ni bilishi kerak, provayderlar orasidagi trafik esa pullik. Ko'p jamoalar bitta asosiy provayder va bir nechta SaaS bilan ishlaydi.

## 4. Region va availability zone

- **Region**: geografik hudud (masalan AWS `eu-central-1`, Frankfurt). Regionlar bir-biridan mustaqil: resurs, narx, mavjud xizmatlar ro'yxati region bo'yicha farq qiladi.
- **Availability zone (AZ)**: region ichidagi, alohida elektr ta'minoti va tarmog'i bor bir yoki bir nechta data-markaz. Bir regionda odatda uch va undan ko'p AZ bo'ladi, ular orasida past latency'li tarmoq bor.
- **Edge location**: CDN va DNS nuqtalari, foydalanuvchiga yaqin, regiondan ancha ko'p.

Bular nosozlik chegaralari (failure domain). Bitta VM bitta AZ da yashaydi: AZ o'chsa VM ham o'chadi. Yuqori mavjudlik (high availability) uchun dastur kamida ikki AZ ga yoyiladi, region darajasidagi halokatdan himoya uchun ikkinchi regionda nusxa (disaster recovery) kerak.

Resurslarning doirasi (scope) har xil, bu AWS'da ham, boshqalarda ham shunday:

| Doira | AWS misollari |
|-------|---------------|
| Global | IAM, Route 53, CloudFront, billing |
| Region | VPC, S3 bucket (nomi global noyob, ma'lumot regionda), security group |
| AZ | EC2 instans, EBS volume, subnet |

**Tuzoq: konsolda "resurslarim yo'qolib qoldi".** Konsol va CLI bir vaqtda bitta regionni ko'rsatadi. Boshqa regionda yaratilgan instans ko'rinmaydi, lekin pul oladi. 3-darsda barcha regionlarni aylanib tekshiradigan skript yozasiz.

Region tanlash mezonlari, muhimlik tartibida:

1. **Qonun va ma'lumot joylashuvi (data residency)**: ba'zi ma'lumotlar mamlakat ichida saqlanishi shart bo'lishi mumkin. O'zbekistonda shaxsga doir ma'lumotlar bo'yicha lokalizatsiya talabi bor, real loyihada buni huquqshunos bilan aniqlang.
2. **Foydalanuvchiga yaqinlik (latency)**: taxmin qilmang, o'lchang.
3. **Xizmat mavjudligi**: yangi xizmatlar hamma regionda bo'lmaydi.
4. **Narx**: bir xil instans turli regionda turlicha turadi.

## 5. Shared responsibility model

AWS ta'rifi: provayder "security **of** the cloud" uchun, mijoz "security **in** the cloud" uchun javob beradi. Boshqa provayderlarda nomi boshqa, mazmuni bir xil.

| Provayder javobgar | Siz javobgar |
|--------------------|--------------|
| Bino, elektr, sovutish, jismoniy xavfsizlik | Akkauntga kirish: parol, MFA, IAM policy'lar |
| Server temiri, disk almashtirish | OS patch'lari (IaaS da), dastur va uning kutubxonalari |
| Hypervisor, mijozlar orasidagi izolyatsiya | Tarmoq qoidalari: security group, ochiq portlar |
| Managed xizmatning o'zi (RDS engine, S3 chidamliligi) | Ma'lumot: shifrlash, backup, kim o'qiy oladi |
| Global tarmoq | Kalitlar va secret'lar, ularni git'ga tushirmaslik |

Model yuqoriga ko'tarilgan sari (IaaS, PaaS, SaaS) sizning ulushingiz kamayadi, lekin hech qachon nolga tushmaydi: ochiq qoldirilgan S3 bucket, sizib chiqqan access key, `0.0.0.0/0` ga ochiq 22-port doim mijoz aybi.

**Tuzoq: "provayder backup oladi".** Provayder diskning buzilmasligini ta'minlaydi, lekin siz `DROP TABLE` qilsangiz yoki bucket'ni o'chirsangiz u buyruqni aniq bajaradi. Chidamlilik (durability) backup emas. Backup siz yoqmaguningizcha yo'q.

## 6. Narx modellari

### Nima uchun pul olinadi

| O'lchov | Misol | E'tibor |
|---------|-------|---------|
| Hisoblash vaqti | VM soniya yoki soat bo'yicha | To'xtatilgan VM hisoblash uchun to'lamaydi, lekin diski uchun to'laydi |
| Saqlash | GB-oy: disk, object storage, snapshot | Instans o'chirilgach qolgan disk va snapshot'lar to'lashda davom etadi |
| So'rovlar | API chaqiruvlari, funksiya chaqiruvlari | Kichik, lekin millionlab bo'lsa seziladi |
| Trafik | Chiquvchi (egress) trafik pullik, kiruvchi odatda bepul | Hyperscaler'larda eng kutilmagan xarajat; AZ va region orasidagi trafik ham pullik |
| Ajratilgan resurs | Public IPv4 manzil, NAT gateway, load balancer | Trafik bo'lmasa ham soatbay to'lanadi |

### Sotib olish usullari

| Model | G'oya | Qachon | Xavf |
|-------|-------|--------|------|
| On-demand | Majburiyatsiz, ishlatgancha | O'qish, tajriba, oldindan noma'lum yuklama | Eng qimmat birlik narx |
| Reserved, Savings Plans, committed use | 1 yoki 3 yilga majburiyat evaziga chegirma | Barqaror, doim ishlaydigan yuklama (database, asosiy servis) | Ehtiyoj o'zgarsa ham to'laysiz |
| Spot, preemptible | Provayderning bo'sh quvvati katta chegirma bilan, istalgan payt qaytarib olinishi mumkin (AWS 2 daqiqa oldin ogohlantiradi) | Uzilishga chidamli ish: batch, CI runner, stateless worker | Database yoki yagona nusxali servis uchun yaramaydi |

Free tier bu o'rganish va sinov uchun cheklangan bepul hajm yoki kredit. Shartlari (muddat, qaysi xizmat, qancha) provayder va akkaunt ochilgan sanaga qarab farq qiladi va o'zgarib turadi. Har doim rasmiy sahifadan o'qing: https://aws.amazon.com/free/, https://cloud.google.com/free, https://azure.microsoft.com/free/.

**Tuzoq: free tier himoya emas.** Limitdan oshganingizda xizmat to'xtamaydi, shunchaki pul yozila boshlaydi. Himoya bu budget alert (2-dars) va resurslarni o'chirish odati.

## 7. Provayder turlari

| Tur | Misollar | Kuchli tomoni | Zaif tomoni |
|-----|----------|---------------|-------------|
| Hyperscaler | AWS, Google Cloud, Microsoft Azure | Yuzlab managed xizmat, ko'p region, ish bozorida eng ko'p so'raladi, enterprise talablari (compliance, IAM) | Murakkab narx, egress qimmat, o'rganish egri chizig'i tik |
| Developer cloud | DigitalOcean, Hetzner Cloud, Linode (Akamai), Vultr | Sodda va oldindan ma'lum narx, tez boshlash, arzon VM va trafik | Xizmatlar kam, regionlar kam, IAM sodda |
| Mahalliy provayder | Mamlakat ichidagi data-markazlar | Ma'lumot mamlakat ichida, mahalliy foydalanuvchiga past latency, mahalliy valyutada to'lov | API va avtomatlashtirish darajasi turlicha, managed xizmatlar kam |
| Edge, PaaS platformalar | Cloudflare, Vercel, Fly.io, Render | Deploy juda sodda, global tarqatish | Platforma chegaralari, o'sganda narx, vendor lock-in |

Asosiy xizmatlarning mosligi. Bu jadval butun modul davomida kerak bo'ladi: AWS'da o'rgangan har tushunchaning boshqa joyda nomi bor.

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

## 8. Managed xizmat yoki self-hosted

Misol: PostgreSQL ni VM'ga o'zingiz o'rnatish yoki managed database olish.

| Mezon | Self-hosted (VM'da) | Managed |
|-------|---------------------|---------|
| To'g'ridan-to'g'ri narx | Past: faqat VM va disk | Yuqori: xuddi shu quvvat qimmatroq |
| Yashirin narx | Sizning vaqtingiz: o'rnatish, patch, backup, replikatsiya, failover, monitoring, tungi qo'ng'iroq | Kam |
| Nazorat | To'liq: versiya, extension, konfiguratsiya, OS | Cheklangan: superuser yo'q, extension ro'yxati provayderda |
| Backup va tiklash | O'zingiz quraysiz va sinaysiz | Tugma bilan, point-in-time recovery |
| Ko'chirish (portability) | Oson: oddiy PostgreSQL | Engine standart bo'lsa oson, provayderga xos xizmat bo'lsa qiyin |
| Bilim talabi | Chuqur | Yuzaki yetadi (bu ham xavf: buzilganda tushunmaysiz) |

Amaliy qoida: **holatli (stateful) va buzilishi qimmatga tushadigan narsani (database, navbat, object storage) managed oling, holatsiz (stateless) dasturni qayerda ishlatish esa ikkinchi darajali savol.** Kichik jamoa uchun muhandis soati VM narxidan ancha qimmat. Istisno: o'rganish (bu kurs), juda katta hajm, yoki managed variant bermaydigan sozlama kerak bo'lganda.

**Vendor lock-in** darajalari: VM va konteyner (deyarli yo'q, istalgan joyga ko'chadi), standart protokolli managed xizmat (PostgreSQL, Redis, S3 API: past), provayderga xos xizmat (DynamoDB, Lambda trigger'lari, IAM bilan chuqur integratsiya: yuqori). Lock-in o'z-o'zidan yomon emas, u tezlik evaziga to'lanadigan narx. Yomoni uni bilmasdan olish.

## 9. Qanday tanlash kerak

Savollar tartibi:

1. **Cheklovlar**: ma'lumot qayerda turishi shart, qanday compliance kerak, to'lov usuli (karta, valyuta) bormi.
2. **Foydalanuvchi qayerda**: latency o'lchovi.
3. **Jamoa nimani biladi**: tanish provayder noma'lum "eng yaxshi" provayderdan tezroq natija beradi.
4. **Qaysi managed xizmatlar kerak**: faqat VM va object storage bo'lsa developer cloud yetadi; navbat, managed Kubernetes, data warehouse kerak bo'lsa hyperscaler.
5. **Narx**: bir oylik real ssenariyni kalkulyatorda hisoblang (VM, disk, trafik, backup, IP), faqat VM narxini solishtirmang.
6. **Chiqish yo'li**: bir yildan keyin ko'chish kerak bo'lsa nima to'sqinlik qiladi.

Nima uchun bu kursda AWS: xizmat modeli eng to'liq, hujjati va ish bozoridagi talabi eng katta, IAM va VPC modeli boshqa provayderlarni tushunish uchun yaxshi asos. AWS'da VPC va IAM ni tushungan odam DigitalOcean'ni bir kunda o'zlashtiradi, teskarisi qiyinroq.

## Tuzoqlar

- Chidamlilikni backup deb o'ylash: provayder sizning xato buyrug'ingizdan himoya qilmaydi.
- Faqat VM narxini solishtirish: egress trafik, public IPv4, NAT gateway, snapshot va load balancer hisobni bir necha barobar o'zgartiradi.
- Bitta AZ dagi bitta VM ni "cloud'da, demak ishonchli" deb hisoblash: bu oddiy bitta server, faqat birovning binosida.
- Free tier'ni limit deb o'ylash: u limit emas, chegirma. Oshsangiz xizmat to'xtamaydi, hisob keladi.
- Noto'g'ri regionda resurs yaratib unutish: konsol faqat tanlangan regionni ko'rsatadi.
- Region tanlashda latency'ni xaritaga qarab taxmin qilish: tarmoq yo'li geografiyaga mos kelmasligi mumkin, o'lchang.
- Ma'lumot joylashuvi talabini loyiha oxirida eslash: ko'chirish arxitekturani o'zgartiradi.
- "Lock-in bo'lmasin" deb hamma narsani o'zi ko'tarish: kichik jamoa database administratoriga aylanadi va mahsulot to'xtaydi.
- Spot instansga holatli servis qo'yish: instans ogohlantirishdan keyin qaytarib olinadi.
- SaaS va PaaS da "xavfsizlik provayderda" deb kirish huquqlarini tekshirmaslik: kim kira olishi doim sizda.

## Manbalar

- https://csrc.nist.gov/pubs/sp/800/145/final – NIST cloud ta'rifi: besh xususiyat, uch xizmat modeli, to'rt joylashtirish modeli (7 bet, majburiy)
- https://aws.amazon.com/compliance/shared-responsibility-model/ – AWS shared responsibility model
- https://aws.amazon.com/about-aws/global-infrastructure/regions_az/ – region va AZ tuzilishi
- https://docs.aws.amazon.com/whitepapers/latest/aws-overview/introduction.html – AWS xizmatlariga umumiy sharh
- https://docs.aws.amazon.com/whitepapers/latest/how-aws-pricing-works/welcome.html – AWS narxlari qanday ishlaydi
- https://aws.amazon.com/ec2/pricing/ – EC2 narx modellari (on-demand, Savings Plans, spot)
- https://calculator.aws/ – AWS Pricing Calculator
- https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison – AWS, Azure va Google Cloud xizmatlari mosligi
- https://learn.microsoft.com/azure/architecture/aws-professional/ – Azure, AWS mutaxassislari uchun
- https://www.digitalocean.com/pricing va https://www.hetzner.com/cloud – developer cloud narx sahifalari
- https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html – Well-Architected Framework (Cost Optimization va Reliability ustunlari)

---

## Vazifalar

Vazifalarni `cloud/01-providers/` papkasida bajaring (`make new m=cloud n=01 name=providers` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida yoziladi: nima qildingiz (buyruq yoki o'qilgan sahifa havolasi), natijaning muhim qismi va o'z so'zingiz bilan izoh. Narx yozilgan har joyda manba havolasi va sana bo'lsin. So'ralgan fayllar (jadval, skript) shu papkada saqlanadi.

### A. Xizmat modellari

1. **Classify services.** Quyidagi 12 xizmatni IaaS, PaaS, FaaS yoki SaaS ga ajrating va har biriga bir gaplik asos yozing: EC2, S3, RDS, Lambda, Vercel, GitHub Actions, Cloudflare Workers, Heroku, Google Workspace, Hetzner Cloud Server, Cloud Run, Datadog. Qaysilarini bitta toifaga sig'dirish qiyin bo'ldi va nima uchun?

2. **Responsibility matrix.** Bitta web dastur (Node API va PostgreSQL) uchun jadval tuzing: qatorlarda 8 ta vazifa (OS patch, runtime yangilash, TLS sertifikat, database backup, disk nosozligi, kirish huquqlari, DDoS himoyasi, dastur zaifligi), ustunlarda uch variant (EC2 da hammasi o'zingiz, Fargate va RDS, Vercel va managed Postgres). Har katakda "men" yoki "provayder" yozing.

3. **Your own stack.** Oxirgi ishlagan frontend loyihangizdagi barcha tashqi xizmatlarni (hosting, CI, monitoring, auth, CDN va boshqalar) sanab chiqing, har birining modelini aniqlang. Qaysi biri o'chib qolsa mahsulot to'xtar edi va o'sha holatda sizning javobgarligingizda nima qolgan edi?

4. **Serverless limits.** AWS Lambda hujjatidan quotas sahifasini toping. Uchta cheklovni (masalan bajarilish vaqti, xotira, payload hajmi) yozing va qaysi turdagi dastur bu modelga sig'masligini izohlang. Raqamlarni hujjatdan oling, manbani ko'rsating.

### B. Region va availability zone

5. **Measure latency.** Kamida 5 ta AWS regioniga latency o'lchang. Region endpoint'i `ec2.<region>.amazonaws.com` shaklida. `curl -o /dev/null -s -w '%{time_connect}\n' https://ec2.eu-central-1.amazonaws.com` buyrug'ini har region uchun 5 martadan ishlatadigan `task_5.sh` yozing, o'rtachasini jadvalga kiriting. Natija xaritadagi masofaga mos keldimi? `time_connect` aynan nimani o'lchaydi (network modulini eslang)?

6. **Region differences.** AWS regional services sahifasidan foydalanib, siz tanlagan eng yaqin regionda mavjud bo'lmagan ikkita xizmatni toping. Keyin EC2 narx sahifasida bitta instans tipining ikki regiondagi on-demand narxini solishtiring. Xulosa: region tanlashda nimalar hisobga olinadi?

7. **Failure domains.** Uch ssenariyni tahlil qiling: bitta VM o'chdi, butun AZ o'chdi, butun region o'chdi. Har biri uchun: bitta AZ dagi bitta VM da ishlayotgan dasturga nima bo'ladi, undan himoyalanish uchun arxitekturada nima kerak va bu taxminan qancha qo'shimcha murakkablik va xarajat keltiradi?

8. **Scope of resources.** AWS hujjatidan foydalanib 8 ta resursning doirasini aniqlang (global, region yoki AZ): IAM user, S3 bucket, EC2 instans, EBS volume, VPC, subnet, security group, Route 53 hosted zone. EBS volume'ni boshqa AZ dagi instansga ulab bo'ladimi, bo'lmasa nima qilinadi?

### C. Javobgarlik va narx

9. **Incident analysis.** Ommaga ma'lum bo'lgan bitta cloud xavfsizlik hodisasini toping (ochiq qolgan bucket yoki sizib chiqqan access key bilan bog'liq), manba havolasini bering. Shared responsibility model bo'yicha ayb kim tomonda edi? Qaysi aniq nazorat choralari uni oldini olar edi?

10. **Durability is not backup.** Ikki tushunchani o'z so'zingiz bilan ajrating. Uchta halokat ssenariysini yozing (disk buzildi, dasturchi jadvalni o'chirdi, akkaunt buzib kirilib hammasi o'chirildi) va har birida faqat provayder chidamliligi yordam beradimi yoki alohida backup kerakmi, izohlang.

11. **Monthly estimate.** AWS Pricing Calculator'da (https://calculator.aws/) kichik loyihani hisoblang: bitta eng kichik umumiy maqsadli instans (oy bo'yi ishlaydi), 30 GB disk, bitta public IPv4, oyiga 100 GB chiquvchi trafik, 50 GB S3. Har qatorning ulushini yozing. Qaysi qator kutilmagan bo'ldi? Hisob havolasini (share link) `README.md` ga qo'ying.

12. **Same workload elsewhere.** 11-vazifadagi yuklamani DigitalOcean va Hetzner narx sahifalari bo'yicha hisoblang. Uch provayderni jadvalda solishtiring. Farq asosan qaysi qatordan kelyapti? Arzonroq variantda nimadan voz kechasiz?

13. **Purchase models.** Uch yuklama uchun sotib olish modelini tanlang va asoslang: (a) 24/7 ishlaydigan production database, (b) kechasi bir marta ishlaydigan 2 soatlik hisobot, (c) CI runner'lar. Har birida noto'g'ri model tanlansa nima bo'lishini yozing.

14. **Hidden costs list.** AWS narx hujjatlaridan foydalanib, "resurs ishlatilmayapti, lekin pul olinyapti" holatlaridan kamida oltitasini toping (masalan to'xtatilgan instans diski). Har biri uchun: nima uchun pul olinadi va uni qanday aniqlash mumkin. Bu ro'yxat 3-darsdagi tozalash skriptingizga asos bo'ladi.

### D. Tanlov

15. **Verify the mapping table.** 7-bo'limdagi moslik jadvalidan beshta qatorni tanlang va har bir katakni provayderning rasmiy hujjatidan tekshiring, havolalarini yozing. "Hujjatdan tekshiring" deb yozilgan kataklarni to'ldiring. Nomi yoki mavjudligi o'zgargan xizmat topdingizmi?

16. **Managed or self-hosted.** Uch kishilik jamoa, bitta mahsulot, PostgreSQL kerak. Managed database va VM'dagi o'z PostgreSQL uchun bir yillik umumiy xarajatni taxminlang: to'g'ridan-to'g'ri narx (narx sahifasidan) va muhandis vaqti (o'zingiz taxmin qilgan soatlar, taxminni asoslang). Qaysi sharoitda xulosa teskari bo'ladi?

17. **Lock-in audit.** Tasavvur qiling: dastur AWS'da Lambda, DynamoDB, S3 va SQS ustiga qurilgan. Har komponentni boshqa provayderga ko'chirish qiyinligini past, o'rta, yuqori deb baholang va sababini yozing. Qaysi birini standart alternativaga almashtirish ko'chishni eng ko'p osonlashtiradi?

18. **Provider decision record.** Mini-loyiha. `decision.md` yozing (bir sahifa, Architecture Decision Record uslubida: kontekst, variantlar, qaror, oqibatlar). Ssenariy: O'zbekistondagi foydalanuvchilar uchun web dastur (API, PostgreSQL, fayl saqlash), uch kishilik jamoa, cheklangan byudjet, shaxsga doir ma'lumot bor. Kamida uch variantni (hyperscaler, developer cloud, mahalliy provayder yoki aralash) 9-bo'limdagi olti savol bo'yicha solishtiring, 5-vazifadagi latency va 11–12-vazifalardagi narx raqamlaringizni ishlating. Qaysi taxminlar noto'g'ri chiqsa qaroringiz o'zgarishini alohida yozing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 18 ta vazifaning har biri `## N. Title` sarlavhasi ostida, narxlarda manba va sana bor.
2. `task_5.sh` va `decision.md` papkada, `make check` toza.
3. Hech qanday cloud resurs yaratilmagan (bu darsda kerak emas).
4. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- IaaS va PaaS ni bitta savol bilan qanday ajratasiz?
- Qaysi javobgarlik hech bir xizmat modelida provayderga o'tmaydi?
- Region va AZ farqi nima, bitta AZ dagi bitta VM nimadan himoyalanmagan?
- Nima uchun konsolda resurs "ko'rinmay qolishi" mumkin va bu nega xavfli?
- Chidamlilik (durability) va backup farqi nima?
- To'xtatilgan VM uchun nimalar pul olishda davom etadi?
- Spot instans qaysi yuklamaga mos, qaysisiga mos emas va nima uchun?
- Free tier nima uchun xarajatdan himoya qilmaydi?
- Managed database'ning yashirin foydasi va yashirin narxi nima?
- Vendor lock-in qachon ongli ravishda qabul qilinadigan narx bo'ladi?
