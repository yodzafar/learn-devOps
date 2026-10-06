# Cloud provayderlar: modul rejasi

Ishlash tartibi: men nazariya va vazifalar beraman, siz AWS akkauntida konsol va CLI orqali bajarasiz, javoblarni `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `cloud/01-providers/`, `cloud/02-first-setup/` va hokazo. Yaratish: `make new m=cloud n=01 name=providers`.

Bu modulga kelguncha linux, git, network va docker modullari tugagan deb hisoblanadi. Bu yerda server sozlash va deploy ataylab qo'lda qilinadi: CI/CD va Terraform keyingi modullarda keladi, ular avtomatlashtiradigan qadamlarni avval qo'lda bir marta bosib o'tish kerak.

Kim uchun yozilgan: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. Cloud bilan tajriba ko'pi bilan Vercel yoki Netlify'ga frontend deploy qilish darajasida deb olinadi. Server, IAM, VPC, security group, object storage, reverse proxy va TLS sozlash yangi mavzu hisoblanadi va har darsda noldan tushuntiriladi: har atama birinchi uchraganda ta'riflanadi, har bo'limda mexanizm, ishlaydigan misol va uning chiqishi bor. PaaS tajribasiga bog'lash haqiqiy bo'lgan joyda beriladi: PaaS aynan shu modulda qo'lda qilinadigan VM, tarmoq va TLS ishlarini yashiradi.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot sharti bilan. Darslar batafsil formatda (har biri 600–1100 qator), shuning uchun har darsning muddati birinchi variantdagi "siz uchun" muddatning 1.5 baravari, yuqoriga yaxlitlangan.

| Bosqich | Dars | Avvalgi muddat | Yangi muddat (siz uchun) | Asosiy yangi mavzular |
|---------|------|----------------|--------------------------|-----------------------|
| I - Tushunchalar | 1 | 2 kun | 3 kun | xizmat modellari, region va AZ, shared responsibility, narx modellari; PaaS nimani yashirishi |
| II - Akkaunt va xavfsizlik | 2 | 2 kun | 3 kun | root va IAM, policy baholanishi, role va vaqtinchalik credential, budget alert, AWS CLI v2 ikki mashinada |
| III - Asosiy resurslar | 3 | 4 kun | 6 kun | EC2, VPC, subnet, security group, S3 policy, tozalash tartibi |
| IV - Deployment | 4 | 5 kun | 8 kun | image arxitekturasi, reverse proxy, DNS, TLS, secret, backup, hardening, runbook |
| **Jami** | **4 dars** | **13 kun** | **20 kun (4 hafta, haftasiga 5 o'quv kuni)** | |

Bosqichlar bo'yicha: I 3 kun, II 3 kun, III 6 kun, IV 8 kun.

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, resurslar o'chirilgan va siz mavzuni o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

- **Asosiy provayder: AWS.** Amaliyot AWS'da, lekin har darsda GCP, Azure, DigitalOcean va Hetzner ekvivalentlari jadvali bor, ko'nikma provayderga bog'lanib qolmasligi kerak.
- **Akkaunt**: shaxsiy AWS akkaunt (2-darsda ochiladi). Bank kartasi talab qilinadi. Free tier va kredit shartlari o'zgarib turadi, aniq raqamlarni dars emas, rasmiy sahifa aytadi: https://aws.amazon.com/free/ va https://aws.amazon.com/pricing/.
- **Ikki mashina**: kurs ofisda Zorin OS (`amd64`), uyda macOS (Apple Silicon, `arm64`) da o'tiladi. Umumiy tayyorgarlik (repo, Docker, Multipass'dagi `lab` VM) ildizdagi `SETUP.md` da, bu modul uni qayta tushuntirmaydi. Har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.
- **Host asboblari**: AWS CLI v2, Docker, `ssh`, `dig`, `curl`. AWS CLI v2 2-darsda ikki shaklda o'rnatiladi: Zorin'da rasmiy `x86_64` zip arxivi foydalanuvchi darajasida (`sudo` siz), macOS'da rasmiy `.pkg` yoki `brew install awscli`. Host'da yo'q Linux buyrug'i kerak bo'lsa `lab` VM ishlatiladi.
- **Akkaunt umumiy, credential'lar mashinaga xos**: AWS akkaunt bitta, lekin CLI profili va SSH private key har mashinada alohida sozlanadi va hech qachon git orqali ko'chirilmaydi. Laboratoriya holati emas, faqat javoblar (`README.md`, skriptlar) git orqali ko'chadi; cloud'dagi resurslar ikkala mashinadan bir xil ko'rinadi.
- **Skriptlar**: `leftovers.sh` kabi yordamchi skriptlar ikkala mashinada ishlaydigan portable bash bo'ladi (macOS'da bash 3.2 va BSD utilitalar: `grep -P`, GNU `date -d`, suffikssiz `sed -i` ishlatilmaydi), yoki dars ularni `lab` VM ichida ishlatishni aytadi.
- **Image arxitekturasi**: Mac'da yig'ilgan image `linux/arm64` bo'ladi va `amd64` EC2 instansda ishlamaydi. 4-dars uch yechimni o'rgatadi: `docker build --platform linux/amd64`, `arm64` (Graviton) instans tipi, yoki serverning o'zida build.
- **Server ichidagi o'zgarishlar** (paket, user, firewall, systemd) faqat EC2 instansda bajariladi, ish mashinasida emas.

Har resurs yaratiladigan darsda majburiy tartib:

1. Budget alert yoqilgan (2-darsda sozlanadi, 3 va 4-darslar boshida tekshiriladi).
2. Eng kichik instans tipi, bitta region, hamma resursda `project=devops-course` tag'i.
3. Har mashg'ulot oxirida instanslar to'xtatiladi yoki o'chiriladi, dars oxirida hammasi o'chiriladi.
4. Oxirgi vazifa: hech narsa ishlab qolmaganini buyruq bilan isbotlash.

## I bosqich - Tushunchalar
1. **Turlari va farqlari**: IaaS, PaaS, SaaS, FaaS, public/private/hybrid, region va availability zone, shared responsibility model, narx modellari (on-demand, reserved, spot), hyperscaler va developer cloud va mahalliy provayder, managed service yoki self-hosted, provayder tanlash mezonlari

## II bosqich - Akkaunt va xavfsizlik
2. **Birinchi sozlash**: akkaunt ochish, root himoyasi va MFA, IAM (user, group, role, policy, least privilege), IAM Identity Center, budget va billing alert, AWS CLI v2, profillar va SSO, `aws sts get-caller-identity`, credential gigiyenasi, CloudTrail

## III bosqich - Asosiy resurslar
3. **Virtual mashina, tarmoq, S3**: EC2 (AMI, instance type, key pair, security group, user data va cloud-init, EBS), VPC (subnet, route table, internet gateway, NAT gateway, NACL, Elastic IP), S3 (bucket, object, storage class, versioning, lifecycle, bucket policy, block public access, presigned URL, static website); har biri avval konsolda, keyin CLI'da

## IV bosqich - Deployment
4. **Dasturlarni serverga joylash**: konteynerlangan web dasturni VM'ga qo'lda deploy qilish (Docker, Caddy yoki nginx reverse proxy, Let's Encrypt TLS, DNS yozuvi, restart policy, env va secret, loglar, zero-downtime, S3'ga backup, hardening), managed variantlar (ECS/Fargate, App Runner, Elastic Beanstalk, Lightsail) haqida tushuncha, modul mini-loyihasi: runbook, deploy qilingan dastur, teardown

## Yakuniy natija

Moduldan keyin siz:

- Xizmat modelini (IaaS/PaaS/SaaS/FaaS) va javobgarlik chegarasini aniq ayta olasiz, loyiha uchun provayder va xizmat tanlovini asoslab bera olasiz.
- Yangi AWS akkauntni xavfsiz holatga keltirasiz: root yopilgan, MFA, least privilege IAM, budget alert, CLI profillari.
- VPC, subnet, security group, EC2 va S3 ni konsolsiz, faqat CLI bilan yarata va o'chira olasiz, har birining narxga ta'sirini bilasiz.
- Konteynerlangan dasturni toza VM'ga HTTPS bilan deploy qilasiz, yangilaysiz, backup olasiz, tiklaysiz va buni runbook sifatida yozib berasiz.
- Xuddi shu ishni boshqa provayderda qaysi xizmatlar bilan qilishni bilasiz.
- Dars oxirida akkauntda hech narsa qolmaganini tekshirish odatiga egasiz.

## Ataylab kiritilmagan

- **Terraform va IaC**: alohida modul. Bu yerda konsol va CLI, chunki IaC nimani avtomatlashtirishini avval qo'lda ko'rish kerak.
- **CI/CD orqali deploy**: alohida modul. Bu yerda deploy qo'lda.
- **Kubernetes (EKS, GKE)**: alohida modul.
- **Managed database (RDS), load balancer, autoscaling, CDN**: faqat tushuncha darajasida tilga olinadi, amaliyoti keyingi modullarda.
- **Serverless (Lambda) chuqur**: 1-darsda model sifatida, amaliyotsiz.
- **Ko'p akkauntli tuzilma (Organizations, Control Tower), compliance, FinOps**: jamoa darajasidagi mavzular, kerak bo'lsa alohida so'rang.
- **Sertifikat imtihonlariga tayyorgarlik**: maqsad imtihon emas, ishlaydigan ko'nikma.

## Manbalar

- AWS Documentation: https://docs.aws.amazon.com/ (har dars tegishli bo'limga havola beradi)
- AWS Well-Architected Framework: https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html
- AWS CLI Command Reference: https://docs.aws.amazon.com/cli/latest/reference/
- AWS Shared Responsibility Model: https://aws.amazon.com/compliance/shared-responsibility-model/
- NIST SP 800-145, "The NIST Definition of Cloud Computing": https://csrc.nist.gov/pubs/sp/800/145/final
- Wittig, Wittig, "Amazon Web Services in Action" (Manning, 3-nashr)
- Kim, Humble, Debois, Willis, "The DevOps Handbook" (deploy va runbook madaniyati uchun)
- Google Cloud docs: https://cloud.google.com/docs, Azure docs: https://learn.microsoft.com/azure/, DigitalOcean docs: https://docs.digitalocean.com/, Hetzner Cloud docs: https://docs.hetzner.com/cloud/
