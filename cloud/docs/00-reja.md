# Cloud provayderlar: modul rejasi

Ishlash tartibi: men nazariya va vazifalar beraman, siz AWS akkauntida konsol va CLI orqali bajarasiz, javoblarni `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `cloud/01-providers/`, `cloud/02-first-setup/` va hokazo. Yaratish: `make new m=cloud n=01 name=providers`.

Bu modulga kelguncha linux, git, network va docker modullari tugagan deb hisoblanadi. Bu yerda server sozlash va deploy ataylab qo'lda qilinadi: CI/CD va Terraform keyingi modullarda keladi, ular avtomatlashtiradigan qadamlarni avval qo'lda bir marta bosib o'tish kerak.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Tushunchalar | 1 | 3 kun | 2 kun | SaaS/PaaS iste'molchi sifatida tanish (Vercel, Netlify, GitHub); yangi qism: regionlar, shared responsibility, narx modellari |
| II - Akkaunt va xavfsizlik | 1 | 3 kun | 2 kun | CLI va JSON bilan ishlash tanish; IAM modeli yangi, qisqartirilmaydi |
| III - Asosiy resurslar | 1 | 5 kun | 4 kun | Linux va network modullari asos beradi; VPC, security group, S3 policy yangi |
| IV - Deployment | 1 | 6 kun | 5 kun | Docker va compose tanish; TLS, DNS, hardening, backup va runbook yangi |
| **Jami** | **4** | **17 kun (3.5 hafta)** | **13 kun (2.5–3 hafta)** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, resurslar o'chirilgan va siz mavzuni o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

- **Asosiy provayder: AWS.** Amaliyot AWS'da, lekin har darsda GCP, Azure, DigitalOcean va Hetzner ekvivalentlari jadvali bor, ko'nikma provayderga bog'lanib qolmasligi kerak.
- **Akkaunt**: shaxsiy AWS akkaunt (2-darsda ochiladi). Bank kartasi talab qilinadi. Free tier va kredit shartlari o'zgarib turadi, aniq raqamlarni dars emas, rasmiy sahifa aytadi: https://aws.amazon.com/free/ va https://aws.amazon.com/pricing/.
- **Ish mashinasi**: AWS CLI v2 (2-darsda foydalanuvchi darajasida, `sudo` siz o'rnatiladi), Docker (o'rnatilgan), `ssh`, `dig`, `curl`.
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
