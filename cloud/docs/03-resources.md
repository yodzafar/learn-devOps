# 3-dars: Virtual mashina, tarmoq, S3

Maqsad: cloud'ning uchta asosiy qurilish blokini qo'lda yaratish, bog'lash va o'chirishni o'rganish: EC2 (virtual mashina), VPC (tarmoq) va S3 (object storage). Linux modulidagi server va network modulidagi subnet, routing, firewall bilimlari bu yerda API orqali boshqariladigan resurslarga aylanadi. Har narsani avval konsolda bir marta (nima borligini ko'rish uchun), keyin CLI'da (takrorlash va skript qilish uchun) bajarasiz. 4-darsdagi deploy aynan shu resurslar ustiga quriladi, Terraform modulida esa shu qadamlarni kod bilan yozasiz.

Taxminiy vaqt: 4 kun (siz uchun): 1-kun EC2, 2-kun VPC, 3-kun S3, 4-kun integratsiya va tozalash. Diqqatni quyidagilarga qarating: subnet'ni nima "public" qiladi, security group'ning stateful ekani, instans o'chirilgach nimalar qolib pul oladi, S3 da kirish qaysi qatlamlarda hal qilinadi, o'chirish tartibi (bog'liqliklar).

## Laboratoriya

- **Cloud akkaunt**: 2-darsda sozlangan AWS akkaunt, admin profil. Bitta region tanlang (1-darsdagi latency o'lchovingiz bo'yicha) va butun dars davomida faqat shunda ishlang: `export AWS_REGION=<region>`.
- **Boshlashdan oldin**: `aws sts get-caller-identity`, 2-darsdagi `task_20.sh`, budget alert mavjudligi. Budget bo'lmasa bu darsni boshlamang.
- **Instans tipi**: faqat eng kichigi. Akkauntingizda free tier'ga kiradigan tiplarni buyruq bilan aniqlang: `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query 'InstanceTypes[].InstanceType' --output text`. Narxlar: https://aws.amazon.com/ec2/pricing/on-demand/, free tier: https://aws.amazon.com/free/.
- **Tag**: har resursga `project=devops-course`.
- **Pullik bo'lishi mumkin bo'lgan narsalar**: ishlab turgan instans, EBS volume va snapshot (instans to'xtatilgan bo'lsa ham), public IPv4 manzil (Elastic IP ham), NAT gateway (bu darsda **yaratilmaydi**), S3 dagi ma'lumot. Aniq narxni har birining pricing sahifasidan o'qing.
- **Har mashg'ulot oxirida**: instanslarni terminate qiling (stop emas), Elastic IP ni release qiling. VPC, subnet, security group, key pair bepul, ular keyingi kungacha qolishi mumkin.
- **Dars oxirida**: hammasi o'chiriladi, oxirgi vazifadagi skript barcha regionlarda hech narsa qolmaganini ko'rsatadi.
- **Server ichidagi ishlar** (paket, disk formatlash) EC2 instansda bajariladi, ish mashinasida emas.

---

## 1. EC2: virtual mashina

Instans yaratish uchun olti narsa tanlanadi:

| Parametr | Nima | Izoh |
|----------|------|------|
| AMI | Disk image: OS va oldindan o'rnatilgan dasturlar | ID region bo'yicha har xil (`ami-...`), vaqt o'tishi bilan yangilanadi |
| Instance type | vCPU, xotira, tarmoq | `t3.micro`: oila `t`, avlod `3`, o'lcham `micro`. `g` qo'shimchasi (`t4g`) ARM protsessor |
| Key pair | SSH public key | AWS public qismni instansga joylaydi, private qism faqat sizda |
| Subnet | Qaysi tarmoq va AZ | Instans bitta AZ ga bog'lanadi |
| Security group | Tarmoq firewall qoidalari | Bir nechta bo'lishi mumkin |
| Storage | Root volume hajmi va turi | EBS, standart `gp3` |

### AMI

AMI ID ni qo'lda nusxalamang, u eskiradi. Canonical joriy Ubuntu AMI'larini SSM public parameter sifatida e'lon qiladi:

```
aws ssm get-parameters \
  --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query 'Parameters[0].Value' --output text
```

Muqobil: `aws ec2 describe-images --owners 099720109477` (Canonical'ning AWS akkaunti) va nom bo'yicha filtr. Ubuntu AMI'da standart foydalanuvchi `ubuntu`. AMI arxitekturasi instans tipiga mos bo'lishi shart: `amd64` AMI ARM (`t4g`) instansda ishga tushmaydi.

`t` oilasi burstable: CPU krediti to'planadi va sarflanadi, kredit tugasa unumdorlik pasayadi yoki qo'shimcha haq olinadi (unlimited rejimi). O'rganish uchun yetarli, doimiy CPU yuklamasi uchun emas.

### Key pair

Private key hech qachon serverga yoki AWS'ga yuborilmaydi. Eng toza yo'l: mavjud public key'ni import qilish.

```
aws ec2 import-key-pair --key-name lab \
  --public-key-material fileb://~/.ssh/id_ed25519.pub
```

`aws ec2 create-key-pair` ishlatilsa AWS juftlikni o'zi yaratadi va private qismni bir marta qaytaradi, uni `chmod 400` qilib saqlash kerak. Key pair faqat birinchi yuklanishda `~/.ssh/authorized_keys` ga yoziladi: keyin AWS'dagi key pair'ni o'chirish instansga kirishni bekor qilmaydi.

### Security group

Security group (SG) instansning tarmoq interfeysiga biriktiriladigan firewall:

- Faqat `allow` qoidalar bor, `deny` yo'q. Yozilmagan hamma narsa taqiqlangan.
- **Stateful**: kiruvchi ulanishga ruxsat berilsa javob paketi avtomatik o'tadi, teskarisi ham.
- Yangi SG: kiruvchi hamma narsa yopiq, chiquvchi hamma narsa ochiq.
- Manba sifatida CIDR yoki boshqa SG ko'rsatiladi: "database SG ga faqat app SG dan 5432-port". Bu IP'larga bog'lanmagan qoidalar yozish imkonini beradi.

```
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id sg-0abc... \
  --protocol tcp --port 22 --cidr "$MYIP/32"
```

**Tuzoq: `0.0.0.0/0` ga ochiq 22-port.** Internetdagi har bir public IP doimiy skanerlanadi, ochilgan SSH portiga daqiqalar ichida parol tanlash urinishlari keladi. SSH faqat o'z IP'ingizdan. Uy IP'ingiz o'zgarsa qoidani yangilaysiz.

### User data va cloud-init

User data bu instansning birinchi yuklanishida `root` nomidan bir marta bajariladigan skript yoki cloud-init konfiguratsiyasi. Shu bilan "toza AMI dan tayyor server" olinadi.

```
#!/bin/bash
apt-get update
apt-get install -y nginx
echo "hello from $(hostname)" > /var/www/html/index.html
```

- Natija instansda `/var/log/cloud-init-output.log` da, holat `cloud-init status` bilan.
- Standart holatda faqat birinchi yuklanishda ishlaydi, reboot'da qayta ishlamaydi.
- User data shifrlanmagan va instansdan o'qiladi: unga secret yozilmaydi.

Instans o'zi haqidagi ma'lumotni metadata xizmatidan oladi (`169.254.169.254`, faqat instans ichidan). IMDSv2 da avval token olinadi:

```
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

Instansga biriktirilgan IAM role credential'lari ham shu yerdan beriladi (2-dars, role).

### Hayot sikli va EBS

| Holat | Hisoblash haqi | Disk haqi | Public IP (avtomatik) |
|-------|----------------|-----------|------------------------|
| running | bor | bor | bor |
| stopped | yo'q | **bor** | qaytarib olinadi, start'da yangisi beriladi |
| terminated | yo'q | root volume o'chsa yo'q | yo'q |

EBS volume bu tarmoq orqali ulangan blok disk:

- Bitta AZ ga tegishli, faqat o'sha AZ dagi instansga ulanadi.
- Root volume'da `DeleteOnTermination` standart `true`. Qo'shimcha ulangan volume'larda standart `false`: instans o'chgach ular `available` holatida qolib pul oladi.
- Snapshot: volume'ning S3 da saqlanadigan nusxasi, region darajasida, boshqa AZ da yangi volume yaratish mumkin. Alohida haq olinadi.
- Yangi bo'sh volume instansda blok qurilma bo'lib ko'rinadi (`lsblk`), fayl tizimi va mount o'zingizdan (linux moduli).

**Tuzoq: stop qilingan instans bepul emas.** Disk va (bo'lsa) Elastic IP uchun to'lov davom etadi. Laboratoriyada terminate qiling.

## 2. Tarmoq: VPC

VPC bu akkauntingizdagi izolyatsiya qilingan virtual tarmoq, o'z CIDR bloki bilan (masalan `10.0.0.0/16`). Har regionda tayyor **default VPC** bor (`172.31.0.0/16`, har AZ da bittadan public subnet), shuning uchun birinchi instans tarmoq sozlamasdan ishga tushadi. Production'da o'z VPC'ingiz quriladi.

| Komponent | Vazifasi | Doira |
|-----------|----------|-------|
| VPC | Manzil maydoni va izolyatsiya chegarasi | Region |
| Subnet | VPC CIDR'ining bir qismi | Bitta AZ |
| Route table | Subnet'dan chiqadigan trafik qayerga borishi | Subnet'ga biriktiriladi |
| Internet gateway (IGW) | VPC va internet orasidagi eshik | VPC'ga bitta |
| NAT gateway | Private subnet'dan internetga faqat chiquvchi ulanish | Public subnet'da turadi |
| Security group | Instans darajasidagi stateful firewall | VPC |
| Network ACL | Subnet darajasidagi stateless firewall | Subnet |
| Elastic IP | O'zgarmas public IPv4 | Region |

AWS har subnet'da 5 ta manzilni o'zi uchun band qiladi (birinchi to'rtta va oxirgisi): `/24` da 251 ta ishlatiladigan manzil.

### Public va private subnet

"Public" degan belgi yo'q. Subnet public bo'lishi uchun uch shart birga bajarilishi kerak:

1. VPC'ga internet gateway ulangan.
2. Subnet'ning route table'ida `0.0.0.0/0` yo'li IGW ga qaragan.
3. Instansda public IPv4 bor (subnet'da "auto-assign public IP" yoki Elastic IP).

Bittasi yetishmasa instansga internetdan kirib bo'lmaydi. Private subnet'da `0.0.0.0/0` yo'li yo'q yoki NAT gateway'ga qaragan. Har route table'da o'chirib bo'lmaydigan `local` yo'li bor: VPC ichidagi barcha subnet'lar bir-birini ko'radi.

```
aws ec2 create-route --route-table-id rtb-0abc... \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-0abc...
aws ec2 associate-route-table --route-table-id rtb-0abc... --subnet-id subnet-0abc...
```

Odatiy tuzilma: public subnet'da load balancer va bastion, private subnet'da dastur va database. Private instansga kirish: bastion orqali (`ssh -J ubuntu@bastion ubuntu@10.0.2.15`) yoki AWS Systems Manager Session Manager.

### NAT gateway

Private subnet'dagi instans paket yangilash yoki tashqi API chaqirish uchun internetga chiqishi kerak, lekin internetdan unga kirib bo'lmasligi kerak. NAT gateway shuni qiladi (network modulidagi source NAT).

**Tuzoq: NAT gateway eng ko'p unutiladigan xarajat.** U soatbay va o'tgan har GB uchun haq oladi, ustiga Elastic IP ham kerak, trafik bo'lmasa ham hisob ketadi. Bu darsda yaratilmaydi: private instansning internetga chiqa olmasligini ko'rasiz, narxini esa https://aws.amazon.com/vpc/pricing/ dan o'zingiz hisoblaysiz.

### Security group va Network ACL

| | Security group | Network ACL |
|---|----------------|-------------|
| Daraja | Instans (tarmoq interfeysi) | Subnet |
| Holat | Stateful | Stateless: javob trafigi uchun alohida qoida kerak |
| Qoidalar | Faqat allow | Allow va deny |
| Baholash | Hamma qoidalar birga | Raqam tartibida, birinchi mos kelgani |
| Standart | Kiruvchi yopiq, chiquvchi ochiq | Default NACL hammasiga ruxsat beradi |

Kundalik ish SG bilan qilinadi. NACL kam hollarda kerak: butun subnet uchun aniq IP oralig'ini bloklash. Stateless NACL da javob paketlari ephemeral portlarga qaytishini (network moduli) unutish odatiy xato.

### Elastic IP va public IPv4

Avtomatik berilgan public IP instans stop/start qilinganda o'zgaradi. Elastic IP (EIP) akkauntingizga tegishli o'zgarmas manzil, instansga ulanadi va uziladi. DNS yozuvi qaratiladigan server uchun kerak (4-dars).

Public IPv4 manzillar pullik resurs, ishlatilayotgani ham, bo'sh turgani ham. Ajratilgan, lekin hech narsaga ulanmagan EIP unutilgan xarajatning klassik misoli. Tekshirish: `aws ec2 describe-addresses`.

## 3. S3: object storage

S3 fayl tizimi emas, kalit-qiymat ombori: **bucket** ichida **object** lar, har biri kalit (`logs/2026/app.log`), ma'lumot va metadata. Katalog yo'q, `/` shunchaki kalitning bir qismi, konsol uni papka qilib ko'rsatadi.

- Bucket nomi butun dunyoda noyob, DNS qoidalariga mos (kichik harf, raqam, defis).
- Bucket bitta regionda yaratiladi, ma'lumot o'sha regionda bir nechta AZ ga tarqatiladi.
- Obyekt qisman o'zgartirilmaydi, faqat butunlay qayta yoziladi. Shuning uchun database fayli yoki log'ni "append" qilish uchun yaramaydi.
- HTTP API orqali ishlaydi, `mount` qilinmaydi.

Ikki xil CLI: `aws s3` (yuqori darajali: `ls`, `cp`, `mv`, `rm`, `sync`, `mb`, `rb`, `presign`) va `aws s3api` (har bir API amali, to'liq nazorat).

### Storage class

Class obyekt darajasida belgilanadi. G'oya: kam o'qiladigan ma'lumot arzonroq saqlanadi, lekin o'qish qimmatroq yoki sekinroq.

| Class | Qachon | Savdolashuv |
|-------|--------|-------------|
| Standard | Tez-tez o'qiladigan | Saqlash eng qimmat, o'qish haqi yo'q |
| Standard-IA, One Zone-IA | Kam o'qiladigan, lekin darhol kerak | Saqlash arzon, har o'qish uchun haq, minimal saqlash muddati; One Zone bitta AZ da |
| Intelligent-Tiering | O'qilish chastotasi noma'lum | Avtomatik ko'chiradi, kuzatuv haqi bor |
| Glacier Instant Retrieval | Arxiv, kamdan-kam, lekin darhol | Saqlash yanada arzon, o'qish qimmat |
| Glacier Flexible Retrieval, Deep Archive | Uzoq muddatli arxiv | Eng arzon saqlash, o'qish uchun avval tiklash kerak (daqiqalardan soatlargacha) |

Aniq narx va minimal muddatlar: https://aws.amazon.com/s3/pricing/.

### Versioning va lifecycle

Versioning yoqilganda har yozish yangi versiya yaratadi, o'chirish esa obyektni yo'q qilmay ustiga **delete marker** qo'yadi. Tasodifiy o'chirish va ustidan yozishdan himoya. Yoqilgandan keyin o'chirib bo'lmaydi, faqat to'xtatiladi (suspend).

```
aws s3api put-bucket-versioning --bucket my-bucket \
  --versioning-configuration Status=Enabled
aws s3api list-object-versions --bucket my-bucket --prefix notes.txt
```

**Tuzoq: versiyalar ko'rinmaydi, lekin pul oladi.** `aws s3 ls` faqat joriy versiyalarni ko'rsatadi. Eski versiyalar to'planadi va saqlash haqi oladi. Versioning doim lifecycle qoidasi bilan birga yoqiladi.

Lifecycle qoidalari obyektlarni yoshiga qarab boshqa class'ga o'tkazadi yoki o'chiradi: "30 kundan keyin Standard-IA, 365 kundan keyin o'chir", "joriy bo'lmagan versiyalarni 30 kundan keyin o'chir", "tugallanmagan multipart upload'larni 7 kundan keyin tozala".

### Kirish nazorati

S3 da kirish bir nechta qatlamda hal qilinadi, har so'rov hammasidan o'tishi kerak:

1. **Block Public Access (BPA)**: akkaunt va bucket darajasidagi to'rtta kalit. Yoqilgan bo'lsa policy nima desa ham public kirish bloklanadi. Yangi bucket'larda standart yoqilgan.
2. **IAM policy** (identity-based): bu identifikatsiya nima qila oladi (2-dars).
3. **Bucket policy** (resource-based): bu bucket'ga kim kira oladi, `Principal` bilan.
4. ACL: eski mexanizm, yangi bucket'larda standart o'chirilgan. Ishlatmang.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
```

Bu bucket policy shifrlanmagan (HTTP) so'rovlarni rad etadi. 2-darsdagi qoida bu yerda ham ishlaydi: explicit deny g'olib.

### Presigned URL

Private obyektni AWS credential'i yo'q odamga vaqtincha berish usuli: URL ichida imzo va muddat bor, URL egasi imzolagan identifikatsiya nomidan aynan shu bitta amalni bajaradi.

```
aws s3 presign s3://my-bucket/report.pdf --expires-in 300
```

Frontend'dan fayl yuklashda tanish pattern: backend presigned URL beradi, brauzer to'g'ridan-to'g'ri S3 ga yuklaydi. URL'ni kim bilsa o'sha kira oladi, muddatni qisqa qo'ying. Imzolagan credential muddati tugasa (masalan role sessiyasi) URL ham ishlamay qoladi.

### Static website hosting

Bucket statik saytni to'g'ridan-to'g'ri bera oladi: `aws s3 website s3://my-bucket --index-document index.html --error-document error.html`. Buning uchun bucket'da BPA o'chiriladi va public o'qishga ruxsat beruvchi bucket policy qo'yiladi. Website endpoint faqat HTTP, HTTPS va o'z domen uchun oldiga CloudFront (CDN) qo'yiladi, o'shanda bucket private qoladi. Bu darsda mexanizmni ko'rish uchun public variantni qilasiz va darhol o'chirasiz.

**Tuzoq: bucket'ni "ishlamayapti" deb public qilish.** Ochiq bucket'lar ma'lumot sizishining eng mashhur sababi. Public faqat ataylab public bo'lishi kerak bo'lgan statik kontent uchun, alohida bucket'da.

## 4. O'chirish tartibi va tekshirish

Resurslar bog'liq, o'chirish yaratishning teskari tartibida: instanslar (terminate tugashini kuting: `aws ec2 wait instance-terminated`), Elastic IP (release), qo'shimcha EBS volume va snapshot'lar, IGW (avval detach, keyin delete), subnet'lar, o'z route table'lar, o'z security group'lar, VPC, key pair. Noto'g'ri tartibda `DependencyViolation` xatosi chiqadi, uni o'qing: u nima to'sayotganini aytadi.

S3: bucket faqat bo'sh bo'lsa o'chadi. Versioning yoqilgan bucket'da `aws s3 rm --recursive` faqat delete marker qo'yadi, versiyalar qoladi. Hamma versiya va delete marker'lar o'chirilishi kerak (konsoldagi "Empty" tugmasi yoki lifecycle qoidasi shuni qiladi).

Tekshirish uchun buyruqlar: `aws ec2 describe-instances`, `describe-volumes`, `describe-snapshots --owner-ids self`, `describe-addresses`, `describe-nat-gateways`, `describe-vpcs`, `aws s3 ls`, va tag bo'yicha: `aws resourcegroupstaggingapi get-resources --tag-filters Key=project,Values=devops-course`. EC2 buyruqlari faqat bitta regionni ko'rsatadi, to'liq tekshiruv barcha regionlarni aylanadi.

Boshqa provayderlardagi mosliklar:

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| VM | EC2 instance | Compute Engine VM | Virtual Machine | Droplet | Server |
| Image | AMI | Image | Image | Image, Snapshot | Image, Snapshot |
| Birinchi yuklanish skripti | User data (cloud-init) | Startup script, cloud-init | Custom data (cloud-init) | User data (cloud-init) | User data (cloud-init) |
| Blok disk | EBS | Persistent Disk | Managed Disk | Volume | Volume |
| Tarmoq | VPC (region) | VPC (global, subnet region) | VNet (region) | VPC (region) | Network |
| Firewall | Security group | Firewall rules | Network Security Group | Cloud Firewall | Firewall |
| Statik IP | Elastic IP | Static external IP | Public IP (static) | Reserved IP | Primary IP, Floating IP |
| Object storage | S3 | Cloud Storage | Blob Storage | Spaces (S3 API) | Object Storage (S3 API) |

cloud-init deyarli hamma joyda bir xil ishlaydi, S3 API esa ko'p provayderda qo'llab-quvvatlanadi: `aws s3 --endpoint-url ...` bilan boshqa provayder omboriga ham ulanish mumkin.

## Tuzoqlar

- SSH portini `0.0.0.0/0` ga ochish yoki "vaqtincha" hamma portni ochib unutish.
- Instansni stop qilib "o'chirdim" deb o'ylash: disk va Elastic IP pul olishda davom etadi.
- Qo'shimcha EBS volume va snapshot'larni instans bilan birga o'chadi deb o'ylash.
- Bo'sh turgan Elastic IP va unutilgan NAT gateway.
- Boshqa regionda yaratilgan resursni ko'rmaslik: konsol va CLI faqat joriy regionni ko'rsatadi.
- User data'ga secret yozish: u instans ichidan va API orqali o'qiladi.
- AMI ID ni skriptga qotirib yozish: boshqa regionda ishlamaydi, vaqt o'tib eskiradi.
- Private key'ni (`.pem`) repozitoriyga yoki ish papkasiga qo'yish.
- Versioning'ni lifecycle'siz yoqish: ko'rinmas eski versiyalar yillar davomida to'planadi.
- Kirish muammosini Block Public Access'ni o'chirib yoki `"Principal": "*"` bilan "hal qilish".

## Manbalar

- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html – EC2 User Guide
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html – user data va cloud-init
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html – instance metadata, IMDSv2
- https://cloudinit.readthedocs.io/en/latest/ – cloud-init hujjati
- https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html – VPC qanday ishlaydi (majburiy)
- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html va https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html – security group va NACL
- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html – NAT gateway
- https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html – EBS
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html – S3 User Guide
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html – Block Public Access
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html – lifecycle
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html – static website hosting
- https://docs.aws.amazon.com/cli/latest/reference/ec2/ va https://docs.aws.amazon.com/cli/latest/reference/s3/ – CLI reference
- https://aws.amazon.com/ec2/pricing/, https://aws.amazon.com/vpc/pricing/, https://aws.amazon.com/s3/pricing/ – narxlar

---

## Vazifalar

Vazifalarni `cloud/03-resources/` papkasida bajaring (`make new m=cloud n=03 name=resources` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar yoki konsol qadamlari, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (skript, policy JSON, user data) shu papkada saqlanadi. Private key, account ID va public IP'laringizni yozmang. Har mashg'ulot oxirida instanslarni terminate qiling.

### A. EC2

1. **Preflight.** `aws sts get-caller-identity`, budget'lar ro'yxati va `AWS_REGION` ni tekshiring. Akkauntingizda free tier'ga kiradigan instans tiplarini buyruq bilan aniqlang va bittasini tanlang. EC2 narx sahifasidan shu tipning tanlangan regiondagi soatlik narxini, EBS va public IPv4 narxini sana bilan yozing: bu dars eng yomon holatda (hammasi 4 kun ishlab qolsa) qanchaga tushadi?

2. **Launch from the console.** Konsolda default VPC'da bitta Ubuntu 24.04 instans yarating: eng kichik tip, o'z key pair'ingiz, yangi security group (SSH faqat sizning IP'dan), `project=devops-course` tag. SSH bilan kiring. Launch wizard'dagi har bo'lim 1-bo'limdagi jadvalning qaysi qatoriga mos keladi? Instans ichida `lsblk`, `ip -4 addr`, `ip route` natijalarini yozing: public IP interfeysda ko'rinadimi, nima uchun?

3. **Instance metadata.** Instans ichidan IMDSv2 orqali `instance-id`, `instance-type`, `placement/availability-zone` va `public-ipv4` ni oling. Token'siz so'rov yuborsangiz qanday HTTP status qaytadi? Bu xizmatga instansdan tashqaridan kirib bo'ladimi, `169.254.0.0/16` qanday manzil oralig'i (network moduli)?

4. **Stop and start.** Instansni stop qiling, keyin start qiling. Public IP, private IP va instans ID dan qaysilari o'zgardi? Stop holatida `aws ec2 describe-volumes` nima ko'rsatadi va shu paytda nima uchun pul olinadi? Instansni terminate qiling va root volume taqdirini tekshiring.

5. **Launch from the CLI.** Xuddi shunday instansni faqat CLI bilan yarating: AMI ID ni SSM parametridan oling, public key'ni `import-key-pair` bilan yuklang, security group yarating va faqat o'z IP'ingizga 22-portni oching, `run-instances` da tag bering, `aws ec2 wait instance-running` dan keyin public IP ni `--query` bilan oling va SSH qiling. Buyruqlarni `task_5.sh` ga yozing (ID'lar o'zgaruvchilarda, qotirib yozilmagan).

6. **Security group behavior.** Instansda `python3 -m http.server 8080` ishga tushiring. Ish mashinasidan `curl` qiling: nima bo'ladi, timeout yoki "connection refused"? SG ga 8080 ni o'z IP'ingiz uchun oching, takrorlang. Serverni to'xtatib yana `curl` qiling. Uch holatdagi xato turini izohlang (network modulidagi DROP va REJECT farqi). Instansdan tashqariga `curl https://example.com` ishlaydi, kiruvchi qoidasiz ham javob qaytadi: nima uchun?

7. **User data.** `task_7.sh` user data skripti yozing: nginx o'rnatib, sahifada instans ID va AZ ni (metadata'dan) ko'rsatsin. Instansni shu user data bilan CLI orqali yarating (`--user-data file://task_7.sh`), SG da 80-portni oching, SSH qilmasdan `curl` bilan tekshiring. Keyin instansga kirib `/var/log/cloud-init-output.log` va `cloud-init status` ni ko'ring. Skriptga ataylab xato buyruq qo'shib yangi instans yarating: xatoni qayerdan topdingiz?

8. **EBS volume.** Instans AZ sida 1 GB `gp3` volume yarating va ulang. Instansda uni toping, `ext4` qilib formatlang, mount qiling, fayl yozing. Volume'dan snapshot oling. Instansni terminate qiling: volume qaysi holatda qoldi? Boshqa AZ da volume yaratishga urinib uni instansga ulab ko'ring va xatoni yozing. Oxirida volume va snapshot'ni o'chiring.

### B. Tarmoq

9. **Inspect the default VPC.** Default VPC'ning CIDR'ini, subnet'larini (AZ va CIDR bilan), route table'ini va internet gateway'ini CLI bilan chiqaring. 2-bo'limdagi "public subnet uch sharti" ning har biri default VPC'da qayerda bajarilganini ko'rsating.

10. **Build a VPC.** CLI bilan o'z VPC'ingizni quring: `10.0.0.0/16`, bitta public subnet (`10.0.1.0/24`) va bitta private subnet (`10.0.2.0/24`), internet gateway, public subnet uchun alohida route table (`0.0.0.0/0` IGW ga), private subnet main route table'da qoladi. Hammasiga tag. Buyruqlarni `task_10.sh` ga yozing va tuzilmani matnli diagramma bilan `README.md` da chizing.

11. **Break the public subnet.** Public subnet'da instans yarating (public IP bilan) va SSH ishlashini tekshiring. Keyin uch shartni navbat bilan buzing va har safar nima bo'lishini yozing, so'ng tiklang: (a) route table'dan `0.0.0.0/0` yo'lini o'chirish, (b) public IP'siz instans yaratish, (c) SG dan SSH qoidasini olib tashlash. Uchala holatda ish mashinasidagi alomat bir xilmi? Qaysi qatlam buzilganini qanday buyruqlar bilan aniqlash mumkin?

12. **Private instance.** Private subnet'da ikkinchi instans yarating. Uning SG sida SSH manbasi sifatida CIDR emas, public instansning security group ID sini ko'rsating. `ssh -J` bilan public instans orqali kiring (private key'ni bastion'ga nusxalamang). Private instansda `sudo apt-get update` ishlating: nima bo'ladi va nima uchun? `ip route` instans ichida va VPC route table orasidagi farqni izohlang.

13. **NAT gateway cost.** NAT gateway yaratmang. VPC narx sahifasidan tanlangan region uchun NAT gateway'ning soatlik va GB narxini, public IPv4 narxini oling va hisoblang: bir oy davomida unutilgan, 50 GB trafik o'tkazgan bitta NAT gateway qanchaga tushadi (manba va sana bilan). Kichik loyihada private instanslarga internet berishning ikkita arzonroq muqobilini toping va kamchiliklarini yozing.

14. **NACL is stateless.** Public subnet uchun yangi network ACL yarating va biriktiring (yangi NACL standart hammasini rad etadi). Faqat kiruvchi 22-portga ruxsat bering: SSH ishlaydimi? Nima yetishmayotganini aniqlang va minimal qoidalar to'plamini yozing. SG bilan xuddi shu natija uchun nechta qoida kerak bo'lgan edi? Oxirida subnet'ni default NACL ga qaytaring va o'zingiznikini o'chiring.

15. **Elastic IP.** Elastic IP ajrating va public instansga ulang. Instansni stop/start qiling: manzil saqlandimi? EIP ni uzing (disassociate), `aws ec2 describe-addresses` da ulanmagan holatini ko'rsating, keyin release qiling. Ulanmagan EIP nima uchun pul oladi?

### C. S3

16. **Bucket basics.** Konsolda `devops-course-<noyob-qo'shimcha>` nomli bucket yarating, bitta fayl yuklang. Keyin CLI bilan: ikkinchi bucket yarating (`aws s3 mb`), `aws s3 sync` bilan kichik katalogni yuklang, `ls --recursive`, bitta faylni o'zgartirib qayta `sync` qiling (nima yuklandi?), `sync --delete` nima qilishini `--dryrun` bilan ko'rsating. Band nom bilan (masalan `test`) bucket yaratishga urinib xatoni yozing.

17. **Versioning and lifecycle.** Bucket'da versioning yoqing. Bitta faylni uch marta turli mazmun bilan yuklang, keyin `aws s3 rm` bilan o'chiring. `aws s3 ls` va `aws s3api list-object-versions` natijalarini solishtiring: delete marker qayerda? Ikkinchi versiyani `--version-id` bilan tiklang (yuklab oling). `task_17.json` lifecycle konfiguratsiyasi yozing: joriy bo'lmagan versiyalar 7 kundan keyin o'chsin, tugallanmagan multipart upload'lar 1 kundan keyin tozalansin. Uni qo'llang va `get-bucket-lifecycle-configuration` bilan tekshiring.

18. **Access layers.** 2-darsdagi kabi policy'siz `lab-s3` IAM user va profil yarating. (a) Shu profil bilan bucket'ni o'qishga uringing. (b) `task_18.json` bucket policy yozing: faqat shu user'ga faqat `reports/` prefiksidagi obyektlarni o'qish va ro'yxatini ko'rish. Qo'llang, `reports/a.txt` va `private/b.txt` ni o'qib ko'ring. (c) Bucket policy'ga `aws:SecureTransport` sharti bilan `Deny` qo'shing va `aws s3api get-object ... --endpoint-url http://s3.<region>.amazonaws.com` bilan tekshiring. Har bosqichdagi xato va muvaffaqiyatni baholash mantiqi bilan izohlang.

19. **Presigned URL.** Private obyekt uchun 60 soniyalik presigned URL yarating. `curl` bilan darhol va 2 daqiqadan keyin so'rov yuboring, ikkinchi javobdagi xato kodini yozing. URL parametrlarini (`X-Amz-Expires`, `X-Amz-Credential`, `X-Amz-Signature`) izohlang. URL'dagi obyekt kalitini o'zgartirib so'rov yuboring: nima bo'ladi va nima uchun? Frontend'dan to'g'ridan-to'g'ri yuklash uchun bu mexanizm qanday ishlatiladi?

20. **Static website.** Alohida bucket'da statik sayt joylang: `index.html` va `error.html`, website hosting'ni yoqing, website endpoint'ni `curl` qiling (hali 403). Bucket uchun Block Public Access'ni o'chiring va public o'qish bucket policy'sini (`task_20.json`) qo'ying, yana `curl` qiling. Mavjud bo'lmagan yo'lni so'rang. `curl -I https://...` website endpoint'da ishlaydimi? Tugagach darhol BPA ni qayta yoqing va policy'ni o'chiring. Production'da HTTPS va private bucket uchun nima qilinadi?

### D. Integratsiya va tozalash

21. **Instance role to S3.** Mini-loyiha. Access key'siz ishlaydigan zanjir quring: faqat bitta bucket'ning `uploads/` prefiksiga yozish va o'qishga ruxsat beruvchi policy (`task_21.json`) bilan IAM role, uni instance profile orqali o'z VPC'ingizdagi public instansga biriktiring. Instansda AWS CLI o'rnating (rasmiy qo'llanma bo'yicha) va `aws sts get-caller-identity` natijasidagi `Arn` ni ko'rsating, `~/.aws/credentials` yo'qligini tekshiring. Instansdan `uploads/` ga fayl yozing, `reports/` ga yozishga urinib xatoni ko'ring. Credential qayerdan kelyapti (3-vazifani eslang) va uning muddati bormi?

22. **Teardown and proof.** Hamma narsani 4-bo'limdagi tartibda o'chiring: instanslar, EIP, volume va snapshot'lar, o'z VPC'ingiz (IGW, subnet, route table, SG, NACL), key pair, IAM role, instance profile, `lab-s3` user, barcha bucket'lar (versiyalari bilan). Yo'lda uchragan `DependencyViolation` va `BucketNotEmpty` xatolarini yozing. Keyin `leftovers.sh` yozing: **barcha yoqilgan regionlarni** aylanib instans (terminated emas), volume, snapshot (o'zingizniki), Elastic IP, NAT gateway, default bo'lmagan VPC larni, hamda bir marta S3 bucket'lar va `project=devops-course` tag'li resurslarni chiqaradigan skript. Uning natijasi bo'sh bo'lishi kerak. Ertasi kuni Billing konsolidagi Bills sahifasini ko'rib, qaysi xizmatlar bo'yicha xarajat yozilganini qo'shing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa, har biri `## N. Title` ostida; `task_*.sh`, `task_*.json` va `leftovers.sh` papkada.
2. `leftovers.sh` natijasi bo'sh, natija `README.md` ga qo'yilgan. Default VPC joyida.
3. Budget alert kelmagan yoki kelgan bo'lsa sababi yozilgan. Bills sahifasidagi summa yozilgan.
4. Fayllarda private key, access key, account ID yo'q. `make check` toza.
5. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Subnet'ni public qiladigan uch shart nima? Bittasi yo'q bo'lsa alomat qanday?
- Security group stateful, NACL stateless degani amalda nimani anglatadi?
- Instans stop va terminate qilinganda nimalar qoladi va pul oladi?
- User data qachon va kim nomidan ishlaydi, unga nima yozilmaydi?
- EBS volume nima uchun boshqa AZ dagi instansga ulanmaydi, ma'lumotni qanday ko'chirasiz?
- NAT gateway nima uchun kerak va nima uchun laboratoriyada yaratilmadi?
- S3 nima uchun fayl tizimi emas? Bu qaysi yuklamalarga mos kelmasligini anglatadi?
- S3 da so'rov qaysi qatlamlardan o'tadi? Block Public Access bucket policy'dan qanday farq qiladi?
- Versioning yoqilgan bucket'da `rm` nima qiladi va bucket'ni to'liq bo'shatish uchun nima kerak?
- Presigned URL kimning nomidan ishlaydi va qachon o'z kuchini yo'qotadi?
