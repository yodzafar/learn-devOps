# 2-dars: Birinchi sozlash

Maqsad: yangi AWS akkauntni resurs yaratishdan oldin xavfsiz va nazorat ostidagi holatga keltirish: root foydalanuvchini yopish, IAM orqali kundalik ish uchun alohida identifikatsiya, xarajat uchun budget alert, CLI va profillar, credential gigiyenasi, CloudTrail. 1-darsdagi shared responsibility jadvalining "siz javobgar" ustunidagi birinchi qator aynan shu: akkauntga kirish. Bu yerda qilingan sozlama 3 va 4-darslardagi har bir buyruq uchun asos, IAM policy tili esa keyingi Terraform va CI/CD modullarida har kuni kerak bo'ladi.

Taxminiy vaqt: 2 kun (siz uchun). CLI va JSON tanish, diqqatni quyidagilarga qarating: root va IAM identifikatsiyalar farqi, policy qanday baholanadi (implicit deny, explicit allow, explicit deny), role va vaqtinchalik credential'lar, CLI credential'ni qaysi tartibda qidiradi, kalit sizib chiqsa nima qilinadi.

## Laboratoriya

- **Cloud akkaunt**: shaxsiy AWS akkaunt, shu darsda ochiladi. Bank kartasi va telefon raqami kerak. Akkaunt ochishda taklif qilinadigan reja va free tier shartlarini https://aws.amazon.com/free/ sahifasidan o'qing, bu dars ularni raqam bilan aytmaydi.
- **Ish mashinasi**: AWS CLI v2 foydalanuvchi darajasida o'rnatiladi (`sudo` kerak emas, tizim kataloglariga tegilmaydi). Konfiguratsiya `~/.aws/` da yashaydi.
- **Xarajat**: bu darsdagi hamma narsa (IAM, budget, CloudTrail event history) bepul xizmatlar. Hech qanday instans, disk yoki bucket yaratilmaydi. Shunga qaramay budget alert birinchi kunning o'zida yoqiladi: u keyingi darslar uchun himoya.
- **Tozalash**: dars oxirida test uchun yaratilgan IAM user, group, role, policy va access key'lar o'chiriladi. Qoladigan narsalar: root MFA, bitta admin identifikatsiya, budget, CLI profili.

CLI o'rnatish (rasmiy qo'llanma: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):

```
cd "$(mktemp -d)"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
./aws/install -i ~/.local/aws-cli -b ~/.local/bin
aws --version
```

`~/.local/bin` `PATH` da bo'lishi kerak. O'chirish: `rm -rf ~/.local/aws-cli ~/.local/bin/aws ~/.local/bin/aws_completer`.

---

## 1. Akkaunt va root foydalanuvchi

AWS akkaunt bu resurslar, billing va xavfsizlik chegarasi (12 xonali account ID). Akkaunt ochilganda email va parol bilan kiradigan **root user** paydo bo'ladi. Root hamma narsaga qodir va uni IAM policy bilan cheklab bo'lmaydi: akkauntni yopish, to'lov usulini o'zgartirish, hamma resursni o'chirish.

Root uchun qoidalar:

- Kuchli noyob parol, parol menejerida.
- MFA darhol yoqiladi (passkey, xavfsizlik kaliti yoki authenticator ilovasi).
- Root uchun access key yaratilmaydi. Bor bo'lsa o'chiriladi.
- Kundalik ishda ishlatilmaydi. Faqat root talab qiladigan kam sonli vazifalar uchun (ro'yxati hujjatda: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html).
- Email manzili sizniki va unga kirish ham MFA bilan himoyalangan: root parolini tiklash shu email orqali o'tadi.

**Tuzoq: MFA qurilmasini yo'qotish.** Telefon yo'qolsa va zaxira bo'lmasa akkauntni tiklash uzoq jarayon. Bir nechta MFA qurilmasi ro'yxatdan o'tkazing yoki authenticator ilovasining zaxirasi borligiga ishonch hosil qiling.

## 2. IAM: kim, nima qila oladi

IAM (Identity and Access Management) ikki savolga javob beradi: bu so'rovni kim yuboryapti (authentication) va unga ruxsat bormi (authorization). IAM global xizmat, region tanlanmaydi, bepul.

| Tushuncha | Nima | Credential |
|-----------|------|------------|
| User | Bitta odam yoki dastur uchun doimiy identifikatsiya | Konsol paroli, access key (uzoq muddatli) |
| Group | User'lar to'plami, policy biriktirish uchun | Yo'q, o'zi kira olmaydi |
| Role | Vaqtincha "kiyib olinadigan" identifikatsiya, egasi yo'q | Faqat vaqtinchalik (STS beradi, muddati tugaydi) |
| Policy | Ruxsatlarni tasvirlaydigan JSON hujjat | Yo'q |

Har bir identifikatsiya va resursning ARN (Amazon Resource Name) manzili bor: `arn:aws:iam::123456789012:user/alice`, `arn:aws:s3:::my-bucket/logs/*`.

### Policy tuzilishi

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::my-bucket/backups/*"
  }]
}
```

- `Effect`: `Allow` yoki `Deny`.
- `Action`: `xizmat:Amal`, wildcard mumkin (`s3:Get*`).
- `Resource`: ARN yoki ARN shabloni. `"*"` hamma resurs.
- `Condition` (ixtiyoriy): qo'shimcha shart, masalan manba IP yoki MFA borligi.
- `Version` bu policy tilining versiyasi, sana emas. Doim `"2012-10-17"`.

Policy turlari: **identity-based** (user, group yoki role'ga biriktiriladi: "bu identifikatsiya nima qila oladi") va **resource-based** (resursga biriktiriladi, masalan S3 bucket policy: "bu resursga kim kira oladi", unda `Principal` maydoni bor). AWS managed policy'lar tayyor (`ReadOnlyAccess`, `AdministratorAccess`), customer managed policy'ni o'zingiz yozasiz.

### Baholash mantiqi

Bitta akkaunt ichida so'rov shunday baholanadi:

1. Standart holat: **implicit deny**. Hech narsa yozilmagan bo'lsa ruxsat yo'q.
2. Tegishli policy'lardan birida `Allow` bo'lsa ruxsat beriladi.
3. Istalgan joyda mos `Deny` bo'lsa u hamma `Allow` dan ustun: **explicit deny g'olib**.

Shuning uchun yangi yaratilgan user hech narsa qila olmaydi, va `AdministratorAccess` bor user'ga ham bitta `Deny` bilan chegara qo'yish mumkin.

**Tuzoq: amal va resurs darajasi mos kelmasligi.** `s3:ListBucket` bucket'ning o'ziga (`arn:aws:s3:::my-bucket`), `s3:GetObject` esa obyektlarga (`arn:aws:s3:::my-bucket/*`) tegishli. Faqat `/*` yozilgan policy bilan `aws s3 ls s3://my-bucket` `AccessDenied` beradi. Har amal qaysi resurs turiga tegishli ekani Service Authorization Reference'da yozilgan.

### Least privilege

Tamoyil: identifikatsiya faqat vazifasi uchun kerakli amallarni, faqat kerakli resurslarda bajara olsin. Amalda yo'l: keng managed policy bilan boshlash, nima ishlatilganini ko'rish (CloudTrail, IAM "Last accessed"), keyin toraytirish. `"Action": "*", "Resource": "*"` faqat admin uchun, dastur va CI uchun hech qachon.

### Role va vaqtinchalik credential

Role'da ikki policy bor: **trust policy** (kim bu role'ni olishi mumkin) va **permission policy** (olgandan keyin nima qila oladi). Role olinganda STS (Security Token Service) muddati cheklangan uchlik beradi: access key ID, secret access key, session token.

Role qayerda ishlatiladi:

- **EC2 instansdagi dastur**: instansga role biriktiriladi (instance profile), dastur kalitni metadata xizmatidan oladi. Serverga access key yozilmaydi. 4-darsda S3 backup uchun shunday qilasiz.
- **Boshqa akkauntga kirish**: bitta identifikatsiya bilan bir nechta akkauntda ishlash.
- **Odamlar**: IAM Identity Center orqali.
- **CI/CD**: OIDC federation orqali, kalitsiz (CI/CD modulida).

Qoida: **uzoq muddatli access key qancha kam bo'lsa shuncha yaxshi.** Sizib chiqqan vaqtinchalik credential muddati tugagach foydasiz, access key esa siz o'chirmaguningizcha ishlaydi.

### IAM Identity Center

AWS odamlar uchun IAM user o'rniga IAM Identity Center'ni tavsiya qiladi: foydalanuvchi bitta portalga kiradi, unga akkaunt va permission set (ichkarida role) tayinlanadi, CLI `aws configure sso` va `aws sso login` orqali brauzerda tasdiqlab qisqa muddatli credential oladi. Diskda uzoq muddatli kalit qolmaydi. Jamoa va bir nechta akkaunt bo'lsa bu standart yo'l.

Bu darsda asosiy yo'l sifatida MFA bilan himoyalangan bitta IAM admin user ishlatiladi, chunki user, group, policy va access key mexanizmini ko'rish kerak. Identity Center'ni yoqish ixtiyoriy vazifa sifatida berilgan.

## 3. Budget va billing alert

AWS'da xarajatni to'xtatadigan "limit" tugmasi yo'q. Bor narsa: ogohlantirish.

| Vosita | Nima qiladi |
|--------|-------------|
| AWS Budgets | Oylik summa (haqiqiy yoki prognoz) chegaradan oshsa email yuboradi. Konsolda "Zero spend budget" va "Monthly cost budget" shablonlari bor |
| Free tier alerts | Free tier limitiga yaqinlashganda email (Billing preferences'da yoqiladi) |
| Cost Explorer | Xarajatni xizmat, region, tag bo'yicha ko'rsatadi |
| Cost Anomaly Detection | Odatdan tashqari o'sishni aniqlaydi |
| Bills sahifasi | Joriy oy hisobi xizmatlar bo'yicha |

Sozlash tartibi: root bilan kirib Account sozlamalarida IAM user va role'larga billing ma'lumotiga kirishni yoqing (aks holda admin user ham billing'ni ko'rmaydi), keyin Billing and Cost Management, Budgets, Create budget.

```
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws budgets describe-budgets --account-id "$ACCOUNT" \
  --query 'Budgets[].[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit]' --output table
```

**Tuzoq: billing ma'lumoti kechikadi.** Xarajat real vaqtda emas, kechikib yangilanadi. Budget alert kelganida pul allaqachon sarflangan. Alert bu xavfsizlik to'ri, asosiy himoya esa har mashg'ulot oxirida resurslarni o'chirish.

**Tuzoq: tag'siz resurs.** Hamma resursga `project=devops-course` tag'ini qo'ying. Aks holda bir oydan keyin Cost Explorer'da bu pul qaysi tajribadan kelganini topa olmaysiz. Tag bo'yicha xarajat ko'rish uchun tag Billing'da "cost allocation tag" sifatida faollashtiriladi.

## 4. AWS CLI

### Konfiguratsiya fayllari

`aws configure` to'rt narsani so'raydi: access key ID, secret access key, default region, output format, va ikki faylga yozadi:

```
# ~/.aws/credentials
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

# ~/.aws/config
[default]
region = eu-central-1
output = json

[profile lab-readonly]
region = eu-central-1
```

`credentials` faylida bo'lim nomi `[nom]`, `config` faylida `[profile nom]` (faqat `default` so'zsiz yoziladi). Secret ochiq matnda turadi, fayl huquqlari `600` bo'lishi kerak.

### Profillar

```
aws configure --profile lab-readonly
aws s3 ls --profile lab-readonly
export AWS_PROFILE=lab-readonly
aws configure list
aws configure list-profiles
```

Role'ni profil orqali olish: CLI o'zi `sts:AssumeRole` chaqiradi va vaqtinchalik credential'ni kesh qiladi.

```
[profile lab-role]
role_arn = arn:aws:iam::123456789012:role/lab-s3-reader
source_profile = default
```

### Credential qidirish tartibi

CLI credential'ni birinchi topilgan joydan oladi, soddalashtirilgan tartib: buyruq qatori parametrlari (`--profile`), environment o'zgaruvchilari (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`), keyin `AWS_PROFILE` yoki `default` profil fayllari, oxirida konteyner va EC2 instans metadata'si (role).

**Tuzoq: eskirgan environment o'zgaruvchisi.** Terminalda `AWS_ACCESS_KEY_ID` export qilingan bo'lsa u profil fayllaridan ustun. "Profilni almashtirdim, lekin eski akkauntda ishlayapti" holatining odatiy sababi shu. `aws configure list` har qiymat qayerdan kelganini ko'rsatadi.

### Kimman

```
aws sts get-caller-identity
```

Javobda `Account`, `UserId`, `Arn`. Bu buyruq hech qanday IAM ruxsat talab qilmaydi va har doim ishlaydi. Har ish seansini va har skriptni shu bilan boshlang: noto'g'ri akkaunt yoki profilda `delete` ishlatish cloud'dagi eng qimmat xatolardan biri.

### Natijani shakllantirish

- `--output json|yaml|text|table`.
- `--query`: JMESPath ifodasi, natija mijoz tomonda filtrlanadi: `aws iam list-users --query 'Users[].UserName' --output text`.
- `--region`: bitta buyruq uchun region. Region tartibi: `--region`, `AWS_REGION`, `AWS_DEFAULT_REGION`, profil.
- `aws <xizmat> help`, `aws <xizmat> <buyruq> help`: lokal hujjat.
- `--dry-run` (EC2 buyruqlarida): bajarmasdan ruxsatni tekshiradi.
- Uzun natijalar pager'da ochiladi. O'chirish: `--no-cli-pager` yoki `AWS_PAGER=""`.

## 5. Credential gigiyenasi

- Access key hech qachon git'ga, image'ga, chat'ga, skrinshot'ga tushmaydi. `.gitignore` da `.env`, `*.pem`, `credentials` bo'lsin.
- Kalit kod ichiga yozilmaydi. Lokal: profil. Serverda: instance role. CI'da: OIDC yoki CI secret'lari.
- Har maqsadga alohida identifikatsiya va minimal policy: sizib chiqsa zarar chegaralangan bo'ladi.
- Kalitlar muntazam almashtiriladi (rotation): yangi kalit yaratish, joyiga qo'yish, eskisini `Inactive` qilish, hech narsa buzilmasa o'chirish.
- Commit'dan oldin secret skaner: gitleaks (https://github.com/gitleaks/gitleaks), pre-commit hook sifatida.

Public repozitoriylar avtomatik skanerlanadi: ochiq GitHub'ga tushgan AWS kaliti daqiqalar ichida topiladi va odatda kriptovalyuta mayning uchun katta instanslar ochishda ishlatiladi.

**Kalit sizib chiqsa tartib**: (1) kalitni darhol `Inactive` qiling va o'chiring, git tarixidan tozalash kalitni xavfsiz qilmaydi, (2) yangi kalit yarating, (3) CloudTrail'da o'sha kalit bilan nima qilinganini ko'ring, (4) barcha regionlarda notanish resurs, IAM user, role va access key'larni qidiring, (5) Bills sahifasini tekshiring va kerak bo'lsa AWS Support'ga yozing.

## 6. CloudTrail

CloudTrail akkauntdagi API chaqiruvlarini yozib boradi: kim, qachon, qayerdan (IP), qaysi amal, natijasi. Konsoldagi har tugma ham API chaqiruvi, u ham yoziladi.

- **Event history**: standart yoqilgan, bepul, oxirgi 90 kunlik management event'lar (resurs yaratish, o'zgartirish, o'chirish, kirish). Region bo'yicha ko'riladi, global xizmatlar (IAM, STS) event'lari `us-east-1` da.
- **Trail**: event'larni S3 ga doimiy saqlash uchun alohida sozlanadi (S3 saqlash narxi bor). Production akkauntda majburiy, bu darsda yaratilmaydi.
- Data event'lar (masalan har bir S3 obyektni o'qish) standart yozilmaydi.

```
aws cloudtrail lookup-events --max-results 5 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --region us-east-1
```

Event'lar bir necha daqiqa kechikib paydo bo'ladi. `AccessDenied` sababini topish, "bu resursni kim o'chirdi" savoliga javob va hodisa tahlili shu yerdan boshlanadi.

Boshqa provayderlardagi mosliklar:

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| Yuqori chegara | Account | Project | Subscription | Team | Project |
| Identifikatsiya | IAM user, role | Google account, service account | Entra ID user, managed identity | Team a'zosi, API token | Project a'zosi, API token |
| Ruxsat berish | Policy (JSON) | IAM role binding | Azure RBAC role assignment | Token scope | Token read yoki read-write |
| Xarajat ogohlantirishi | Budgets | Budgets and alerts | Cost Management budgets | Billing alerts | hujjatdan tekshiring |
| Audit log | CloudTrail | Cloud Audit Logs | Activity Log | hujjatdan tekshiring | hujjatdan tekshiring |
| CLI kirish | `aws configure`, `aws sso login` | `gcloud auth login` | `az login` | `doctl auth init` | `hcloud context create` |

## Tuzoqlar

- Root bilan kundalik ishlash yoki root uchun access key yaratish: sizib chiqsa cheklab bo'lmaydi.
- MFA'siz admin: bitta parol sizishi butun akkaunt.
- Access key'ni git'ga commit qilish. Keyingi commit bilan o'chirish yordam bermaydi, kalit tarixda qoladi va allaqachon o'qilgan.
- `AdministratorAccess` ni dastur yoki CI identifikatsiyasiga berish: "keyin toraytiramiz" hech qachon kelmaydi.
- Budget alert'ni limit deb o'ylash: u xarajatni to'xtatmaydi va kechikib keladi.
- `aws sts get-caller-identity` siz ish boshlash: noto'g'ri profil yoki eskirgan `AWS_*` o'zgaruvchisi bilan boshqa akkauntda o'zgarish qilish.
- Eski, ishlatilmaydigan access key va user'larni qoldirish: har biri ochiq eshik.
- Billing'ga IAM kirishini yoqmaslik va shuning uchun hisobni faqat oy oxirida ko'rish.
- Policy'da `Resource` darajasini adashtirish (`ListBucket` va `GetObject`) va muammoni `"*"` bilan "hal qilish".

## Manbalar

- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html – IAM security best practices (majburiy)
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html – root user va faqat root bajaradigan vazifalar
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html – policy baholash mantiqi
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html – policy elementlari
- https://docs.aws.amazon.com/service-authorization/latest/reference/reference.html – har xizmatning amal va resurs turlari
- https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html – AWS CLI v2 o'rnatish
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html – config va credentials fayllari, profillar
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html – CLI va IAM Identity Center
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html – `--query` va JMESPath
- https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html – AWS Budgets
- https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html – CloudTrail event history
- https://aws.amazon.com/free/ – free tier shartlari (aniq limitlar faqat shu yerdan)

---

## Vazifalar

Vazifalarni `cloud/02-first-setup/` papkasida bajaring (`make new m=cloud n=02 name=first-setup` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar yoki konsol qadamlari, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (policy JSON, skript) shu papkada saqlanadi. `README.md` ga account ID, access key va secret yozmang: account ID o'rniga `123456789012`, kalit o'rniga `AKIA...` qoldiring.

### A. Akkaunt va root

1. **Create the account.** AWS akkaunt oching. Jarayonda taklif qilingan reja va free tier shartlarini https://aws.amazon.com/free/ dan o'qib, o'zingizga tegishli uchta shartni (muddat, kredit yoki limit, tugaganda nima bo'ladi) sana bilan yozing. Kelajakdagi o'zingiz uchun: bu shartlar qachon tugaydi?

2. **Lock down root.** Root uchun MFA yoqing va Security credentials sahifasida root access key yo'qligini tekshiring. Chiqib, qayta kirib MFA so'ralishini ko'ring. Root faqat o'zi bajara oladigan uchta vazifani hujjatdan topib yozing.

3. **Budget alert.** Root bilan billing ma'lumotiga IAM kirishini yoqing. AWS Budgets'da ikkita budget yarating: "Zero spend budget" shabloni va o'zingiz chidaydigan kichik oylik summa uchun "Monthly cost budget" (haqiqiy xarajatning 50% va 100% ida, prognozning 100% ida email). Free tier alert'larni ham yoqing. Tasdiqlash emailini ko'rsating.

### B. IAM

4. **Admin identity.** `admins` group yarating, unga `AdministratorAccess` biriktiring, o'zingiz uchun IAM user yaratib group'ga qo'shing, konsol paroli va MFA o'rnating. Root'dan chiqing va shu user bilan kiring. Bundan keyin root ishlatilmaydi. Nima uchun policy user'ga emas, group'ga biriktirildi?

5. **Install the CLI.** AWS CLI v2 ni Laboratoriya bo'limidagi usul bilan o'rnating. `aws --version` va `which aws` natijasini yozing. Admin user uchun access key yarating, `aws configure` bilan `default` profilni sozlang. `ls -l ~/.aws/` huquqlarini tekshiring.

6. **Who am I.** `aws sts get-caller-identity` ishlating va uchta maydonni izohlang. Keyin `AWS_ACCESS_KEY_ID=AKIAFAKE AWS_SECRET_ACCESS_KEY=fake aws sts get-caller-identity` ishlating, xatoni o'qing. `aws configure list` ikki holatda credential manbasini qanday ko'rsatadi?

7. **Implicit deny.** `lab-readonly` user yarating (policy'siz, konsol parolisiz), unga access key yaratib `lab-readonly` profiliga yozing. Shu profil bilan `aws iam list-users` va `aws s3 ls` ishlating. Xato matnini to'liq yozing va undagi har qismni (kim, qaysi amal, qaysi resurs, nima sababdan) izohlang.

8. **Managed policy.** `lab-readonly` user'ga `ReadOnlyAccess` managed policy biriktiring va 7-vazifadagi buyruqlarni takrorlang. Keyin shu profil bilan `aws iam create-user --user-name hack` ishlatib ko'ring. Policy'ning JSON'ini konsolda oching: `Action` lar qanday shablonlar bilan yozilgan?

9. **Custom policy.** `task_9.json` yozing: faqat nomi `devops-course-` bilan boshlanadigan bucket'larda obyektlarni ko'rish va o'qishga ruxsat beradigan identity-based policy (bucket hali yo'q, 3-darsda kerak bo'ladi). Uni customer managed policy sifatida yarating. `aws iam simulate-principal-policy` bilan uchta holatni tekshiring: mos bucket'dan `s3:GetObject`, boshqa nomli bucket'dan `s3:GetObject`, mos bucket'ga `s3:PutObject`. Natijadagi `EvalDecision` qiymatlarini izohlang.

10. **Explicit deny wins.** `lab-readonly` user'ga `ReadOnlyAccess` ustiga `iam:*` amallarini `Deny` qiladigan inline policy qo'shing. `aws iam list-users --profile lab-readonly` natijasi qanday o'zgardi? Xato matni 7-vazifadagidan nimasi bilan farq qiladi? Baholash mantiqining uch qadamini shu misolda tushuntiring.

11. **Assume a role.** `lab-s3-reader` role yarating: trust policy'da faqat sizning admin user'ingiz, permission sifatida `AmazonS3ReadOnlyAccess`. `~/.aws/config` ga `role_arn` va `source_profile` li profil qo'shing. Shu profil bilan `aws sts get-caller-identity` ishlating: `Arn` qanday ko'rinishda? Keyin `aws sts assume-role` ni qo'lda chaqirib javobdagi `Expiration` ni toping. Vaqtinchalik credential'ning access key ID si qaysi prefiks bilan boshlanadi, uzoq muddatlisi-chi?

12. **Wrong principal.** 11-vazifadagi role'ni `lab-readonly` profili orqali olishga urinib ko'ring (`source_profile` ni almashtirib). Xatoni yozing. Bu xato trust policy'danmi yoki permission policy'danmi, qanday aniqladingiz?

### C. CLI

13. **Query and output.** Faqat `--query` va `--output` yordamida (`jq` va `grep` siz): (a) barcha IAM user'lar nomi va yaratilgan sanasini jadval ko'rinishida, (b) `admins` group'ga biriktirilgan policy ARN'larini matn ko'rinishida, (c) siz tanlagan regiondagi AZ nomlarini chiqaring. Buyruqlarni yozing.

14. **Credential precedence.** Tajriba bilan isbotlang: `AWS_PROFILE=lab-readonly` o'rnatilgan terminalda `--profile default` berilsa qaysi biri yutadi? `AWS_ACCESS_KEY_ID` va `AWS_SECRET_ACCESS_KEY` (lab-readonly kalitlari) export qilinib, `AWS_PROFILE=default` bo'lsa-chi? Har holatda `aws sts get-caller-identity` va `aws configure list` natijasini ko'rsating. Oxirida o'zgaruvchilarni `unset` qiling.

15. **Region scope.** `aws ec2 describe-regions` bilan akkauntingizda yoqilgan regionlar sonini toping. `aws ec2 describe-availability-zones` ni ikki xil `--region` bilan ishlating. `aws iam list-users --region` ga turli region bersangiz natija o'zgaradimi, nima uchun?

### D. Gigiyena va audit

16. **Key rotation.** Admin user uchun kalitni almashtiring: ikkinchi kalit yarating, profilga yozing, tekshiring, eskisini `Inactive` qiling, yana tekshiring, eskisini o'chiring. `aws iam list-access-keys` natijasini har bosqichda ko'rsating. Nima uchun eski kalit darhol o'chirilmay avval `Inactive` qilinadi?

17. **Leak drill.** Vaqtinchalik katalogda yangi git repozitoriy yarating (push qilinmaydi). Unga `lab-readonly` ning access key'ini fayl ichida commit qiling, keyingi commit'da faylni o'chiring. `git log -p` bilan kalit hali ham tarixda ekanini ko'rsating. gitleaks hujjatidagi usul bilan (Docker image orqali) repozitoriyni skanerlang, topilmani yozing. Keyin 5-bo'limdagi tartib bo'yicha kalitni o'chiring va katalogni yo'q qiling. Real hodisada yana qaysi qadamlar bo'lar edi?

18. **Read CloudTrail.** CloudTrail event history'dan (konsol va `aws cloudtrail lookup-events`) toping: (a) o'zingizning oxirgi `ConsoleLogin`, (b) 4-vazifadagi `CreateUser`, (c) 7 yoki 10-vazifadagi rad etilgan chaqiruvlardan biri. Har birida `userIdentity`, `sourceIPAddress`, `errorCode` maydonlarini ko'rsating. IAM event'lari qaysi regionda chiqdi va nima uchun?

19. **Identity Center.** Ixtiyoriy. IAM Identity Center'ni yoqing, o'zingizga user va `AdministratorAccess` permission set tayinlang, `aws configure sso` bilan profil yarating, `aws sso login` dan keyin `aws sts get-caller-identity` natijasini ko'rsating. `~/.aws/` ichida nima saqlandi va u access key'dan nimasi bilan xavfsizroq? Bajarmasangiz, hujjatni o'qib shu savollarga nazariy javob yozing.

20. **Cleanup and baseline.** `lab-readonly` user'ni (avval kalitlari va policy'lari bilan), `lab-s3-reader` role'ni va 9-vazifadagi policy'ni o'chiring, `~/.aws/` dan ularning profillarini olib tashlang. Keyin `task_20.sh` yozing: akkauntning boshlang'ich holatini chiqaradigan skript (`get-caller-identity`, IAM user'lar va har birining access key'lari soni va yoshi, root MFA yoqilganligi `aws iam get-account-summary` orqali, budget'lar ro'yxati). Skript natijasini (account ID yashirilgan holda) `README.md` ga qo'ying. Bu skriptni 3 va 4-darslar boshida qayta ishlatasiz.

### Topshirish

Tayyor bo'lgach:
1. Root MFA yoqilgan, root access key yo'q, kundalik ish admin IAM user (yoki Identity Center) orqali.
2. Ikkala budget mavjud, tasdiqlash emaili kelgan.
3. Test user, role, policy va ortiqcha access key'lar o'chirilgan: `task_20.sh` natijasi buni ko'rsatadi.
4. `README.md` va fayllarda haqiqiy kalit, secret va account ID yo'q. `make check` toza.
5. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Root user IAM admin user'dan nimasi bilan farq qiladi va nima uchun kundalik ishda ishlatilmaydi?
- User, group va role farqi nima? Qaysi biri uzoq muddatli credential'ga ega emas?
- Policy baholashning uch qadami qanday? Yangi user nima uchun hech narsa qila olmaydi?
- Trust policy va permission policy nimani hal qiladi?
- Nima uchun serverdagi dastur uchun access key emas, role ishlatiladi?
- CLI credential'ni qaysi tartibda qidiradi va bu qanday xatoga olib keladi?
- Budget alert nima qila oladi va nima qila olmaydi?
- Access key git'ga tushib qoldi. Birinchi uch qadamingiz qanday va nima uchun commit'ni o'chirish yetarli emas?
- CloudTrail event history nimani ko'rsatadi, nimani ko'rsatmaydi?
- `s3:ListBucket` va `s3:GetObject` uchun `Resource` nima uchun turlicha yoziladi?
