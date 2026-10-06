# 2-dars: Birinchi sozlash

Maqsad: yangi AWS akkauntni resurs yaratishdan oldin xavfsiz va nazorat ostidagi holatga keltirish: root foydalanuvchini yopish, IAM orqali kundalik ish uchun alohida identifikatsiya, xarajat uchun budget alert, AWS CLI va profillar (ikkala mashinada), credential gigiyenasi, CloudTrail. 1-darsdagi shared responsibility jadvalining "siz javobgar" ustunidagi birinchi qator aynan shu: akkauntga kim kira olishi. Vercel yoki Netlify'da bu ish bitta "Login with GitHub" tugmasi va bitta token bilan tugagan; AWS'da kirish, ruxsat va xarajat nazorati sizning qo'lingizda va noldan quriladi. Bu yerda qilingan sozlama 3 va 4-darslardagi har bir buyruq uchun asos, IAM policy tili esa keyingi Terraform va CI/CD modullarida har kuni kerak bo'ladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh hamda 4-vazifa (akkaunt, root, budget, admin user). Ikkinchi kun 4–6 bo'limlar, 5–15-vazifalar (CLI, policy, role). Uchinchi kun 7–8 bo'limlar, "Birga bajaramiz", D guruh va README'ni tartibga solish. Diqqatni mexanizmga qarating: root va IAM identifikatsiya farqi, so'rov qanday imzolanadi, policy qanday baholanadi (implicit deny, allow, explicit deny), role va vaqtinchalik credential, CLI credential'ni qaysi tartibda qidiradi, kalit sizib chiqsa nima qilinadi.

Qanday o'qish kerak: konsol qadamlarini o'qib, o'sha sahifani o'zingiz oching (AWS konsol tugmalarini tez-tez qayta nomlaydi, darsda sahifa va sozlama nomlari hujjatdagidek berilgan; topilmasa konsol qidiruvidan foydalaning). CLI misollarini o'zingiz terib, chiqishni darsdagi izoh bilan solishtiring. Sizdagi qiymatlar farq qiladi: account ID, ARN, kalit ID va sanalar `<...>` bilan belgilangan. Narx, free tier limiti va kredit miqdori darsda aytilmaydi, chunki ular o'zgaradi: har safar rasmiy sahifadan o'qiladi.

## Laboratoriya

Bu darsda uchta "joy" bor:

| Joy | Nima bajariladi |
|-----|-----------------|
| AWS konsol (brauzer) | akkaunt ochish, root MFA, billing sozlamalari, budget, birinchi admin user |
| Host (Zorin yoki macOS) | AWS CLI v2: barcha `aws ...` buyruqlari, `~/.aws/` fayllari, `make`, `git` |
| `lab` VM | bu darsda shart emas. Faqat macOS'da ishlamaydigan Linux buyrug'i kerak bo'lsa (`SETUP.md`) |

- **Cloud akkaunt**: shaxsiy AWS akkaunt, shu darsda ochiladi. Bank kartasi va telefon raqami kerak. Akkaunt ochishda taklif qilinadigan reja va free tier shartlarini https://aws.amazon.com/free/ sahifasidan o'qing, bu dars ularni raqam bilan aytmaydi.
- **Xarajat**: bu darsda ishlatiladigan IAM, STS, budget va CloudTrail event history uchun haq olinmasligi kerak, hech qanday instans, disk yoki bucket yaratilmaydi. Buni taxmin deb qabul qilmang: A guruhda budget alert yoqiladi va dars oxirida Bills sahifasi tekshiriladi. Budget keyingi darslar uchun ham himoya.
- **Region**: bitta region tanlang va modul oxirigacha o'zgartirmang (1-dars, 4-bo'lim: region tanlash mezonlari). Darsdagi misollarda `eu-central-1` yozilgan, o'zingizniki boshqa bo'lsa almashtiring.
- **Tozalash**: dars oxirida test uchun yaratilgan IAM user, role, policy va access key'lar o'chiriladi. Qoladigan narsalar: root MFA, bitta admin identifikatsiya, budget'lar, CLI profili.

### AWS CLI v2 ni o'rnatish

AWS CLI bu AWS API'ga terminaldan so'rov yuboradigan dastur (6-bo'lim). Rasmiy qo'llanma: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html. O'rnatishni o'zingiz bajarasiz (5-vazifa).

Zorin (ofis, `x86_64`): rasmiy zip arxivi, foydalanuvchi darajasida, `sudo` siz. `-i` dastur fayllari qayerga ko'chirilishini, `-b` esa `aws` symlink'i qaysi papkaga qo'yilishini belgilaydi.

```
cd "$(mktemp -d)"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install -i ~/.local/aws-cli -b ~/.local/bin
aws --version
```

`~/.local/bin` `PATH` da bo'lishi kerak (linux moduli, 5-dars; `node_modules/.bin` kabi: shell buyruqni faqat `PATH` dagi papkalardan qidiradi). `unzip` topilmasa uni o'zingiz `apt` orqali o'rnatasiz. Yangilash: yangi zip'ni yuklab, xuddi shu buyruqqa `--update` qo'shiladi. O'chirish: `rm -rf ~/.local/aws-cli ~/.local/bin/aws ~/.local/bin/aws_completer`.

macOS (uy, `arm64`): ikki yo'ldan biri. Homebrew: `brew install awscli` (binary `/opt/homebrew/bin/aws`, yangilash `brew upgrade awscli`). Yoki rasmiy `AWSCLIV2.pkg` o'rnatuvchisi (yuqoridagi qo'llanmaning macOS bo'limida, grafik o'rnatuvchi administrator parolini so'raydi, binary `/usr/local/bin/aws`). Ikkalasini birga o'rnatmang: `PATH` da qaysi biri oldin tursa o'sha ishlaydi va versiyalar adashadi.

`aws --version` chiqishi bitta qator: `aws-cli/2.<x>.<y> Python/3.<x>.<y> <OS>/<kernel> <tur>/<arxitektura>`. Birinchi qism `aws-cli/2` bilan boshlanishi shart (v1 eskirgan, flag'lari farq qiladi), `<OS>` Zorin'da `Linux`, Mac'da `Darwin`, oxirida Zorin'da `x86_64`, Mac'da `arm64`.

### Ikki mashina

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | CLI: rasmiy `x86_64` zip, `~/.local/bin/aws`. `aws --version` da `Linux/... x86_64`. Fayl ruxsatlarini `ls -l ~/.aws/` bilan ko'rasiz. |
| macOS (uy) | CLI: Homebrew yoki `.pkg`, `arm64`. `aws --version` da `Darwin/... arm64`. Shell `zsh`, lekin darsdagi `aws` buyruqlari bir xil. Skriptlar macOS'dagi bash 3.2 va BSD utilitalarida ham ishlashi kerak: GNU `date -d`, `grep -P`, suffikssiz `sed -i` ishlatilmaydi. |

Mashinalar orasida nima ko'chadi va nima ko'chmaydi:

- **AWS akkaunt bitta**: IAM user, budget, CloudTrail yozuvlari cloud'da turadi va ikkala mashinadan bir xil ko'rinadi. Konsol qadamlari (A guruh, 4-vazifa) bir marta bajariladi.
- **CLI, profil va access key har mashinada alohida**: `~/.aws/` git'ga hech qachon tushmaydi va mashinalar orasida nusxalanmaydi. Ikkinchi mashinada CLI qayta o'rnatiladi va o'sha mashina uchun **alohida** access key yaratilib `aws configure` qilinadi. Shunda bitta mashina yo'qolsa faqat o'sha kalit o'chiriladi.
- **Cheklov**: bitta IAM user'da ko'pi bilan ikkita access key bo'ladi. Ikki mashinada ikkita kalit tursa, kalit almashtirish (16-vazifa) uchun bo'sh o'rin qolmaydi. Shuning uchun 16-vazifani ikkinchi mashinaga kalit qo'shishdan oldin bajaring; keyinchalik ikkinchi mashinada kalit o'rniga IAM Identity Center (19-vazifa) ishlatish toza yechim.
- **Javoblar git orqali ko'chadi**: `README.md`, `task_9.json`, `task_20.sh`. Repodagi `make secrets` tekshiruvi `credentials`, `.pem`, `.key` fayllarini rad etadi, lekin README ichiga qo'lda yozilgan kalitni u ham, siz ham o'tkazib yuborishingiz mumkin: kalitni hech qayerga ko'chirmang.

---

## 1. Akkaunt va root user

### Akkaunt nima

AWS akkaunt bu uchta narsaning chegarasi: **resurslar** (bir akkauntdagi server boshqa akkauntdan ko'rinmaydi), **billing** (hisob akkauntga yoziladi) va **xavfsizlik** (ruxsatlar akkaunt ichida beriladi). Har akkauntning 12 xonali **account ID** si bor, u resurs manzillarida (ARN, 2-bo'lim) qatnashadi. Account ID parol emas, lekin uni ham keraksiz joyga yozmang: README'da `<ACCOUNT_ID>` yoki `123456789012` qoldiring.

Vercel'dagi "team" ga o'xshaydi: loyihalar va hisob team'ga tegishli. Farqi: AWS'da kompaniyalar bitta akkaunt bilan cheklanmaydi, production, staging va har jamoa uchun alohida akkaunt ochadi, chunki akkaunt eng kuchli izolyatsiya chegarasi.

### Mexanizm: root user

Akkaunt ochilganda email va parol bilan kiradigan **root user** paydo bo'ladi. U akkauntning egasi: hamma narsaga qodir va akkaunt ichidagi IAM policy bilan cheklanmaydi. Akkauntni yopish, to'lov usulini va root emailini o'zgartirish kabi ishlarni faqat u bajaradi (to'liq ro'yxat hujjatda, Manbalar). Root parolini bilgan odam akkauntning to'liq egasi, shuning uchun qoidalar:

- Kuchli noyob parol, parol menejerida.
- **MFA** darhol yoqiladi. MFA (multi-factor authentication) bu paroldan tashqari ikkinchi isbot: telefoningizdagi ilova chiqaradigan 6 xonali kod, passkey yoki USB xavfsizlik kaliti. Parol sizib chiqsa ham, ikkinchi omilsiz kirib bo'lmaydi.
- Root uchun **access key** (dasturlar uchun kalit, 2-bo'lim) yaratilmaydi. Bor bo'lsa o'chiriladi.
- Kundalik ishda ishlatilmaydi: faqat akkaunt ochish, MFA, billing kirishini yoqish va faqat root bajaradigan kam sonli vazifalar uchun.
- Root emaili sizniki va unga kirish ham MFA bilan himoyalangan: root parolini tiklash shu email orqali o'tadi.

### Misol: konsolda nima ko'rasiz

Akkaunt ochish https://aws.amazon.com sahifasidagi "Create an AWS Account" dan boshlanadi: email va akkaunt nomi, emailni tasdiqlash, root paroli, aloqa ma'lumoti, karta, telefon orqali tasdiqlash, support rejasi. Jarayonda akkaunt rejasi (plan) tanlash so'ralishi mumkin: shartlarini o'sha paytdagi https://aws.amazon.com/free/ sahifasidan o'qib tanlang (1-vazifa).

Root bilan kirgach, o'ng yuqoridagi akkaunt nomi ostida **Security credentials** sahifasi bor. Unda ikki bo'lim muhim:

- **Multi-factor authentication (MFA)**: "Assign MFA device" tugmasi. Qurilma turlari: passkey or security key, authenticator app, hardware TOTP token. Authenticator app tanlansa QR kod chiqadi, ilova uni o'qiydi va ketma-ket ikkita kodni kiritasiz. Tugagach ro'yxatda qurilma va uning identifikatori ko'rinadi.
- **Access keys**: ro'yxat bo'sh bo'lishi kerak. Bo'sh bo'lmasa kalitni o'chirasiz.

Tekshirish: chiqib qayta kirganda paroldan keyin MFA kodi so'raladi. CLI sozlangach (6-bo'lim) xuddi shu holatni buyruq bilan ko'rish mumkin: `aws iam get-account-summary` javobidagi `SummaryMap` ichida `AccountMFAEnabled` (1 bo'lsa root MFA yoqilgan) va `AccountAccessKeysPresent` (0 bo'lsa root kaliti yo'q) maydonlari bor.

**Tuzoq: MFA qurilmasini yo'qotish.** Telefon yo'qolsa va zaxira bo'lmasa akkauntni tiklash uzoq jarayon. Bir nechta MFA qurilmasi ro'yxatdan o'tkazing yoki authenticator ilovasining zaxirasi borligiga ishonch hosil qiling.

### Real ishda qachon kerak

- Yangi loyiha yoki mijoz uchun akkaunt ochilganda birinchi 15 daqiqa: root MFA, root kaliti yo'qligi, budget. Bu tartib har akkauntda bir xil.
- Xavfsizlik auditi birinchi bo'lib "root qachon oxirgi marta ishlatilgan" deb so'raydi. To'g'ri javob: akkaunt ochilgan kuni.

### Nima uchun shunday

Root AWS'ning birinchi yillaridan qolgan: avval akkauntda faqat bitta egasi bor edi, IAM keyinroq (2010-yillar boshida) qo'shildi. Root'ni cheklab bo'lmasligi ataylab: IAM sozlamalari buzilib hamma o'zini qulflab qo'ysa, akkauntni qutqaradigan oxirgi eshik shu. Aynan shu sabab u seyfda turadi. Muqobil yondashuv Google Cloud'da: u yerda alohida "root" yo'q, egasi oddiy Google akkaunt, lekin o'sha akkauntni himoyalash vazifasi baribir sizda.

## 2. IAM: kim so'rayapti va ruxsat bormi

### Ikki savol

IAM (Identity and Access Management) AWS'ning kirish nazorati xizmati. U har so'rovda ikki savolga javob beradi. **Authentication** (autentifikatsiya): bu so'rovni kim yuboryapti, rostdan o'shami? **Authorization** (avtorizatsiya): shu identifikatsiyaga shu amalni shu resursda bajarishga ruxsat bormi? Web dasturda ham shunday: login cookie'si "kim" ni aytadi, backend'dagi rol tekshiruvi esa "mumkinmi" ni. IAM global xizmat (region tanlanmaydi) va uning o'zi uchun haq olinmaydi.

| Tushuncha | Nima | Credential |
|-----------|------|------------|
| User | Bitta odam yoki dastur uchun doimiy identifikatsiya | Konsol paroli, access key (uzoq muddatli) |
| Group | User'lar to'plami, policy'ni bir joyda biriktirish uchun | Yo'q, group nomidan kirib bo'lmaydi |
| Role | Vaqtincha "kiyib olinadigan" identifikatsiya, doimiy egasi yo'q (4-bo'lim) | Faqat vaqtinchalik |
| Policy | Ruxsatlarni tasvirlaydigan JSON hujjat (3-bo'lim) | Yo'q |

Credential bu identifikatsiyani isbotlaydigan maxfiy ma'lumot: odam uchun parol va MFA, dastur uchun access key. So'rov yuboruvchi (user, role yoki AWS xizmati) hujjatlarda **principal** deb ataladi.

### ARN

Har bir identifikatsiya va resursning **ARN** (Amazon Resource Name) manzili bor. Tuzilishi: `arn:partition:service:region:account-id:resource`.

- `arn:aws:iam::<ACCOUNT_ID>:user/alice`: IAM global, shuning uchun region o'rni bo'sh (ikki `:` ketma-ket).
- `arn:aws:ec2:eu-central-1:<ACCOUNT_ID>:instance/i-<...>`: region ham, akkaunt ham bor.
- `arn:aws:s3:::my-bucket/logs/*`: S3 bucket nomi butun dunyoda noyob, shuning uchun region ham, akkaunt ham bo'sh. `*` shablon.

Policy'da "qaysi resurs" va xato xabarida "kim" doim ARN bilan yoziladi.

### Mexanizm: hamma narsa imzolangan HTTPS so'rov

1-darsda (1-bo'lim) ko'rdingiz: cloud'da har amal API chaqiruvi. Konsoldagi tugma, `aws` buyrug'i va kodingizdagi SDK (AWS'ning dasturlash tili uchun kutubxonasi, masalan `@aws-sdk/client-s3`) uchalasi bitta HTTPS API'ning mijozi: `https://ec2.eu-central-1.amazonaws.com` kabi xizmat endpoint'iga so'rov yuboradi. Konsol alohida kuchga ega emas, u ham xuddi shu API'ni chaqiradi.

Dastur o'zini **access key** bilan tanitadi. U ikki qismdan iborat: **access key ID** (`AKIA` bilan boshlanadigan ochiq identifikator, login kabi) va **secret access key** (maxfiy qism, faqat yaratilgan paytda bir marta ko'rsatiladi). Vercel yoki npm token'idan muhim farq: token so'rov ichida serverga yuboriladi, secret access key esa **hech qachon yuborilmaydi**. Uning o'rniga so'rov imzolanadi. Bu usul Signature Version 4 (SigV4) deyiladi:

1. Mijoz so'rovning qat'iy shaklini tuzadi: metod, yo'l, parametrlar, sarlavhalar, tana xeshi, vaqt.
2. Secret'dan sana, region va xizmat nomi orqali bir kunlik imzo kaliti hosil qiladi va shu kalit bilan so'rovning HMAC-SHA256 imzosini hisoblaydi (HMAC: maxfiy kalit qatnashadigan xesh, kalitsiz uni qayta hisoblab bo'lmaydi).
3. So'rovga `Authorization` sarlavhasi qo'shiladi: `AWS4-HMAC-SHA256 Credential=AKIA<...>/<sana>/eu-central-1/sts/aws4_request, SignedHeaders=host;x-amz-date, Signature=<64 ta hex belgi>`.
4. AWS access key ID bo'yicha o'zidagi secret'ni topadi, imzoni o'zi qayta hisoblaydi va solishtiradi. Mos kelsa "kim" aniq, keyin authorization boshlanadi (3-bo'lim).

Oqibatlari: so'rovni yo'lda ushlagan odam secret'ni ololmaydi; so'rovning bir baytini o'zgartirsa imzo buziladi; imzo vaqtga bog'langan, shuning uchun eski so'rovni qayta yuborib bo'lmaydi va mashina soati bir necha daqiqaga adashsa so'rovlar rad etiladi.

### Misol: noto'g'ri secret

Access key ID to'g'ri, lekin secret'da bitta belgi xato bo'lsa (CLI sozlangach buni ataylab sinab ko'rish mumkin):

```
$ aws sts get-caller-identity
An error occurred (SignatureDoesNotMatch) when calling the GetCallerIdentity operation: The request signature we calculated does not match the signature you provided. Check your AWS Secret Access Key and signing method. Consult the service documentation for details.
```

O'qilishi: `SignatureDoesNotMatch` xato kodi; `GetCallerIdentity` chaqirilgan API amali (CLI'dagi `get-caller-identity` ning API nomi); matn mexanizmni aynan aytadi: "biz hisoblagan imzo siz yuborgan imzoga mos kelmadi". AWS secret'ni ko'rmagan, faqat ikki imzoni solishtirgan. Bu authentication xatosi: ruxsatlar hali tekshirilmagan ham.

### Real ishda qachon kerak

- Har "ishlamayapti" holatida birinchi savol: xato authentication'danmi (kalit noto'g'ri, muddati o'tgan, soat adashgan) yoki authorization'danmi (`AccessDenied`). Ikkalasining davosi boshqa-boshqa.
- Jamoaga yangi odam qo'shilganda: user yaratiladi, group'ga qo'shiladi, ruxsat group orqali keladi. Odam ketganda bitta user o'chiriladi.
- Node backend S3'ga yozganda SDK aynan shu imzoni hisoblaydi. Unga kalit qayerdan kelishi 4-bo'limda.

### Nima uchun shunday

Secret'ni yubormasdan imzolash sababi: kalit tarmoqda umuman yurmasa, uni proxy logidan yoki ushlangan so'rovdan o'g'irlab bo'lmaydi. Narxi: mijoz murakkabroq, `curl` bilan qo'lda so'rov yuborish qiyin, shuning uchun CLI va SDK kerak. Muqobili bearer token (GitHub, Vercel, npm): sodda, lekin token har so'rovda ochiq yuboriladi. AWS ham vaqtinchalik credential'larda qo'shimcha session token ishlatadi (4-bo'lim), lekin imzo baribir qoladi.

## 3. Policy va baholash mantiqi

### Policy nima

Policy bu "kimga, nima, qayerda mumkin yoki mumkin emas" ni yozadigan JSON hujjat. Yangi yaratilgan user'da hech qanday policy yo'q va u hech narsa qila olmaydi. Ruxsat policy biriktirish bilan paydo bo'ladi.

### Misol: policy'ni qatorma-qator o'qish

Faraz qiling, kechasi test serverlarini o'chirib-yoqadigan skript uchun ruxsat kerak (bu faqat o'qish uchun misol, yaratish shart emas):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SeeInstances",
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    },
    {
      "Sid": "StartStopCourseInstances",
      "Effect": "Allow",
      "Action": ["ec2:StartInstances", "ec2:StopInstances"],
      "Resource": "arn:aws:ec2:eu-central-1:<ACCOUNT_ID>:instance/*",
      "Condition": {
        "StringEquals": { "aws:ResourceTag/project": "devops-course" }
      }
    }
  ]
}
```

- `Version`: policy tilining versiyasi, sana emas. Doim `"2012-10-17"`.
- `Statement`: qoidalar ro'yxati. Har biri mustaqil baholanadi.
- `Sid`: qoidaning ixtiyoriy nomi, o'qish uchun.
- `Effect`: `Allow` yoki `Deny`.
- `Action`: `xizmat:Amal` ko'rinishida, API amali nomi bilan. Wildcard mumkin (`ec2:Describe*`).
- `Resource`: ARN yoki ARN shabloni. Birinchi qoidada `"*"`, chunki `DescribeInstances` ro'yxat qaytaradigan amal va uni alohida resursga toraytirib bo'lmaydi. Ikkinchisida shu akkaunt va regiondagi istalgan instans.
- `Condition`: qo'shimcha shart. Bu yerda instansning `project` tag'i `devops-course` bo'lsagina amal ruxsat etiladi. Boshqa shartlar: manba IP, MFA bilan kirilganmi.

Natija: skript hamma instansni ko'radi, lekin faqat kurs tag'i bor instansni to'xtatadi yoki yoqadi. O'chirish (`ec2:TerminateInstances`) yozilmagan, demak mumkin emas.

### Policy turlari

- **Identity-based**: user, group yoki role'ga biriktiriladi ("bu identifikatsiya nima qila oladi"). Ikki ko'rinishi bor: **managed policy** alohida obyekt, ARN'i bor va bir nechta identifikatsiyaga biriktiriladi; **inline policy** bitta identifikatsiyaning ichiga yozilgan va u bilan birga o'chadi.
- Managed policy'ning ikki manbasi: **AWS managed** (tayyor, AWS yangilab turadi: `ReadOnlyAccess`, `AdministratorAccess`) va **customer managed** (o'zingiz yozasiz).
- **Resource-based**: resursning o'ziga biriktiriladi (masalan S3 bucket policy: "bu resursga kim kira oladi"). Unda qo'shimcha `Principal` maydoni bor. Role'ning trust policy'si ham shu turdan (4-bo'lim).

### Mexanizm: baholash mantiqi

Bitta akkaunt ichida so'rov shunday baholanadi:

1. Boshlang'ich holat: **implicit deny** (default deny). Hech narsa yozilmagan bo'lsa ruxsat yo'q.
2. So'rovga tegishli barcha policy'lar yig'iladi (user'ning o'ziniki, group'lariniki, resursniki). Birortasida mos `Allow` bo'lsa ruxsat beriladi.
3. Istalgan joyda mos `Deny` bo'lsa u hamma `Allow` dan ustun: **explicit deny g'olib**.

Shuning uchun `AdministratorAccess` bor user'ga ham bitta `Deny` bilan chegara qo'yish mumkin, ikki policy "ziddiyati" esa doim taqiq foydasiga hal bo'ladi. Rad etilgan so'rovning xato matni kim (ARN), qaysi amal, qaysi resurs va qaysi sababdan rad etilganini aytadi; sabab qismi implicit va explicit deny uchun turlicha (7 va 10-vazifalarda o'zingiz solishtirasiz). Policy'ni haqiqiy so'rov yubormasdan sinash uchun IAM policy simulator bor, CLI'da `aws iam simulate-principal-policy` (parametrlari: `--policy-source-arn`, `--action-names`, `--resource-arns`; `aws iam simulate-principal-policy help`).

**Tuzoq: amal va resurs darajasi mos kelmasligi.** Har amal ma'lum resurs turiga tegishli. S3'da bucket'ning o'zi (`arn:aws:s3:::my-bucket`) va uning ichidagi obyektlar (`arn:aws:s3:::my-bucket/*`) ikki xil resurs: bucket ichini ro'yxatlash bucket'ga, obyektni o'qish obyektga tegishli amal. `Resource` noto'g'ri darajada yozilsa `Allow` hech qachon "mos" kelmaydi va implicit deny qoladi. Har amal qaysi resurs turiga tegishli ekani Service Authorization Reference'da yozilgan (Manbalar).

### Least privilege

Tamoyil: identifikatsiya faqat vazifasi uchun kerakli amallarni, faqat kerakli resurslarda bajara olsin. Amalda yo'l: kengroq managed policy bilan boshlash, nima ishlatilganini ko'rish (CloudTrail, konsoldagi "Last accessed" ma'lumoti), keyin toraytirish. `"Action": "*", "Resource": "*"` faqat odam-admin uchun, dastur va CI uchun hech qachon.

### Real ishda qachon kerak

- Har `AccessDenied` da: qaysi qadamda rad etildi? Allow yo'qmi (qo'shish kerak) yoki kimdir ataylab Deny yozganmi (qo'shgan Allow yordam bermaydi).
- CI pipeline, backup skripti, dastur uchun identifikatsiya yaratilganda: faqat kerakli amal va resurs.
- Terraform modulida har xizmat uchun policy yoziladi: sintaksis aynan shu JSON.

### Nima uchun shunday

Default deny xavfsizlikning asosiy qoidasi: unutilgan narsa yopiq qoladi, ochiq emas. Explicit deny'ning ustunligi esa "himoya panjarasi" qurishga imkon beradi: kim qanday Allow qo'shmasin, panjara turaveradi. Muqobili tartibga bog'liq qoidalar (firewall'dagi kabi, birinchi mos kelgan qoida yutadi; network moduli, 6-dars): ularda natija qoidalar tartibiga bog'liq, IAM'da esa tartib ahamiyatsiz, bu yuzlab policy'ni birlashtirganda muhim. JSON tanlangani sababi: policy'ni kod kabi saqlash, review qilish va generatsiya qilish mumkin.

## 4. Role va vaqtinchalik credential

### Role nima

Role bu doimiy egasi va doimiy kaliti yo'q identifikatsiya: uni kimdir vaqtincha "kiyib oladi" (assume), ishini qiladi va muddat tugagach credential o'z-o'zidan yaroqsiz bo'ladi. Role'da ikki policy bor:

- **Trust policy**: kim bu role'ni olishi mumkin (resource-based policy, `Principal` maydoni bilan).
- **Permission policy**: olgandan keyin nima qila oladi (oddiy identity-based policy).

### Mexanizm: STS

Role olish ham API chaqiruvi: `sts:AssumeRole`. STS (Security Token Service) vaqtinchalik credential beradigan xizmat. Ketma-ketlik: chaqiruvchi o'z credential'i bilan imzolangan `AssumeRole` so'rovini yuboradi; STS ikki narsani tekshiradi (chaqiruvchining o'zida `sts:AssumeRole` ga ruxsat bormi va role'ning trust policy'si uni principal sifatida tan oladimi); mos kelsa muddati cheklangan uchlikni qaytaradi: access key ID, secret access key va **session token**. Keyingi so'rovlar shu uchlik bilan imzolanadi, session token har so'rovga qo'shib yuboriladi. `Expiration` vaqtidan keyin AWS ularni rad etadi.

### Misol: xizmat uchun trust policy

EC2 instansdagi dastur role olishi uchun trust policy'da principal odam emas, xizmat bo'ladi:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

O'qilishi: "EC2 xizmatiga (`Principal`) shu role'ni olishga (`sts:AssumeRole`) ruxsat (`Allow`)". `Resource` yo'q, chunki resurs role'ning o'zi. Odam yoki boshqa akkaunt uchun `Principal` ichida `"AWS": "<ARN>"` yoziladi (11-vazifa). `aws sts assume-role --role-arn <ARN> --role-session-name <nom>` javobida ikki obyekt bor: `Credentials` (`AccessKeyId`, `SecretAccessKey`, `SessionToken`, `Expiration`) va `AssumedRoleUser` (sessiyaning ARN'i va ID'si). Kalit ID'larining prefiksi turiga qarab farq qiladi, jadvali IAM hujjatining "IAM identifiers" sahifasida.

Role qayerda ishlatiladi:

- **EC2 instansdagi dastur**: instansga role biriktiriladi (instance profile), SDK kalitni instansning metadata xizmatidan o'zi oladi va yangilab turadi. Serverga access key yozilmaydi. 4-darsda S3 backup uchun shunday qilasiz.
- **Boshqa akkauntga kirish**: bitta identifikatsiya bilan bir nechta akkauntda ishlash.
- **Odamlar**: IAM Identity Center orqali (quyida).
- **CI/CD**: OIDC federation orqali, kalitsiz (CI/CD modulida).

### IAM Identity Center

AWS odamlar uchun IAM user o'rniga IAM Identity Center'ni tavsiya qiladi: foydalanuvchi bitta portalga (parol va MFA bilan) kiradi, unga akkaunt va **permission set** (ichkarida role) tayinlanadi. CLI'da `aws configure sso` portal manzili (SSO start URL), SSO region, akkaunt va role'ni so'rab `~/.aws/config` ga `sso_session`, `sso_account_id`, `sso_role_name` qatorli profil yozadi; `aws sso login --profile <nom>` brauzerda tasdiq so'raydi va shundan keyin CLI qisqa muddatli credential'ni o'zi oladi. Diskda uzoq muddatli secret qolmaydi.

Bu darsda asosiy yo'l MFA bilan himoyalangan bitta IAM admin user, chunki user, group, policy va access key mexanizmini qo'lda ko'rish kerak. Identity Center 19-vazifada (ixtiyoriy), ikki mashinada ishlash uchun esa qulayroq.

### Real ishda qachon kerak

- Serverdagi dastur AWS xizmatini chaqirsa: doim role, hech qachon access key.
- GitHub Actions'dan deploy: OIDC orqali role, repozitoriy secret'ida kalit saqlanmaydi.
- Production'ga kirish: odam kundalik ishda cheklangan, kerak bo'lganda kuchliroq role'ni vaqtincha oladi va bu CloudTrail'da ko'rinadi.

### Nima uchun shunday

Qoida: **uzoq muddatli access key qancha kam bo'lsa shuncha yaxshi.** Sizib chiqqan vaqtinchalik credential muddati tugagach foydasiz, access key esa siz o'chirmaguningizcha ishlaydi. Trust va permission'ning ajratilgani sababi: "kim kiradi" va "ichkarida nima mumkin" ni alohida odamlar alohida boshqaradi. Muqobili har dastur uchun IAM user va kalit: sodda, lekin kalitlarni tarqatish, saqlash va almashtirish qo'l mehnatiga aylanadi.

## 5. Budget, billing va tag'lar

### Alert bu limit emas

AWS'da xarajatni to'xtatadigan "limit" tugmasi yo'q. Bor narsa: ogohlantirish.

| Vosita | Nima qiladi |
|--------|-------------|
| AWS Budgets | Oylik summa (haqiqiy yoki prognoz) chegaradan oshsa email yuboradi. "Zero spend budget" va "Monthly cost budget" shablonlari bor |
| CloudWatch billing alarm | Eski usul: `EstimatedCharges` metrikasiga alarm, faqat `us-east-1` da, Billing preferences'da alohida yoqiladi. Prognozni bilmaydi |
| Free tier alerts | Free tier limitiga yaqinlashganda email (Billing preferences'da yoqiladi) |
| Cost Explorer | Xarajatni xizmat, region, tag bo'yicha ko'rsatadi |
| Bills sahifasi | Joriy oy hisobi xizmatlar bo'yicha |

### Mexanizm

Har xizmat ishlatilgan resursni o'lchab billing tizimiga yuboradi (1-dars, 6-bo'lim), u yerda summa yig'iladi. Budgets shu yig'ilgan ma'lumotni chegara bilan solishtiradi. Ma'lumot real vaqtda emas, kechikib yangilanadi (hujjatga ko'ra kamida kuniga bir marta), shuning uchun alert kelganda pul allaqachon sarflangan. **Actual** alert sarflangan summaga, **forecasted** alert oy oxirigacha prognozga qaraydi (prognoz uchun bir necha kunlik tarix kerak). Alert resursni to'xtatmaydi: to'xtatish sizning ishingiz.

### Misol: konsol va CLI

Tartib: (1) root bilan Account sahifasida **IAM user and role access to Billing information** ni yoqing, aks holda admin user ham billing'ni ko'rmaydi; (2) Billing and Cost Management konsolida **Budgets**, "Create budget", "Use a template"; (3) shablon, summa va email. Yaratilgach budget ro'yxatda ko'rinadi, chegaradan oshganda email keladi. CLI'da tekshirish:

```
$ aws budgets describe-budgets --account-id <ACCOUNT_ID> \
    --query 'Budgets[].[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit,TimeUnit]' --output text
<budget nomi>	<summa>	USD	MONTHLY
```

Har qator bitta budget: nomi, chegara, valyuta, davr. Bo'sh chiqish budget yo'qligini bildiradi.

### Tag'lar

**Tag** bu resursga yopishtiriladigan `kalit=qiymat` yorlig'i. Bu modulda har resursga `project=devops-course` qo'yiladi. Sababi ikki xil: Cost Explorer'da pul qaysi tajribadan kelganini ko'rish (buning uchun tag Billing'da "cost allocation tag" sifatida faollashtiriladi) va o'zingiz yaratgan narsani topib o'chirish. Misol: regiondagi shu tag'li resurslar ro'yxati (hozir bo'sh bo'lishi kerak):

```
$ aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=project,Values=devops-course --query 'ResourceTagMappingList[].ResourceARN'
[]
```

Bu buyruq faqat bitta regionni va faqat tag'langan resurslarni ko'rsatadi: tag qo'yilmagan resurs unga tushmaydi. Shuning uchun tag yaratish paytida qo'yiladi, keyin emas.

### Real ishda qachon kerak

- Har yangi akkauntda birinchi kun: budget. Unutilgan instans yoki NAT gateway oy oxiridagi hisobda emas, ertasi kuni emailda ko'rinadi.
- Jamoada "bu resurs kimniki, o'chirsa bo'ladimi" savoliga yagona javob tag'lar.

### Nima uchun shunday

AWS qattiq limit qo'ymaydi, chunki limit ishlasa production to'xtaydi, ma'lumot o'chadi: aksariyat kompaniyalar uchun to'xtab qolish ortiqcha hisobdan qimmatroq. Shaxsiy akkaunt uchun bu noqulay, shuning uchun himoya uch qatlamli: tag va kichik resurslar, har mashg'ulot oxirida o'chirish, eng oxirida alert. Budget'ning "action" imkoniyati (chegarada policy biriktirish yoki instansni to'xtatish) bor, lekin u ham kechikkan ma'lumotga tayanadi va cap emas.

## 6. AWS CLI

### Konfiguratsiya fayllari

`aws configure` to'rt narsani so'raydi (access key ID, secret access key, default region, output format) va ikki faylga yozadi:

```
# ~/.aws/credentials
[default]
aws_access_key_id = AKIA<...>
aws_secret_access_key = <...>

# ~/.aws/config
[default]
region = eu-central-1
output = json

[profile audit]
role_arn = arn:aws:iam::<ACCOUNT_ID>:role/<role-nomi>
source_profile = default
```

**Profil** bu nomlangan sozlamalar to'plami. `credentials` faylida bo'lim nomi `[nom]`, `config` faylida `[profile nom]` (faqat `default` so'zsiz yoziladi). `role_arn` va `source_profile` li profilda CLI `source_profile` kaliti bilan o'zi `sts:AssumeRole` chaqiradi va vaqtinchalik credential'ni kesh qiladi. Secret ochiq matnda turadi, xuddi `~/.npmrc` dagi `_authToken` kabi: fayl ruxsati `600` (faqat egasi o'qiydi; linux moduli, 6-dars) bo'lishi shart, `ls -l ~/.aws/` da `-rw-------`.

Profil tanlash: `--profile <nom>` (bitta buyruq uchun) yoki `export AWS_PROFILE=<nom>` (shu terminal uchun). `aws configure list-profiles` profillar ro'yxatini beradi.

### Mexanizm: credential va region qidirish tartibi

CLI credential'ni birinchi topilgan joydan oladi, soddalashtirilgan tartib: (1) buyruq qatori (`--profile`), (2) environment o'zgaruvchilari (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`), (3) `AWS_PROFILE` yoki `default` profil fayllari, (4) konteyner va EC2 instans metadata'si (role). Region uchun: `--region`, `AWS_REGION`, `AWS_DEFAULT_REGION`, profil. `aws configure list` har qiymat qayerdan kelganini ko'rsatadi:

```
$ aws configure list
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************<...> shared-credentials-file
secret_key     ****************<...> shared-credentials-file
    region             eu-central-1      config-file    ~/.aws/config
```

To'rt qator: profil (tanlanmagan, demak `default`), kalit ID va secret (oxirgi 4 belgisi, manbasi `credentials` fayli), region (`config` fayli). `Type` ustuni manbani aytadi: environment'dan kelsa `env`. CLI versiyasiga qarab jadval ko'rinishi biroz farq qilishi mumkin, to'rt ustun o'sha.

**Tuzoq: eskirgan environment o'zgaruvchisi.** Terminalda `AWS_ACCESS_KEY_ID` export qilingan bo'lsa u profil fayllaridan ustun. "Profilni almashtirdim, lekin eski akkauntda ishlayapti" holatining odatiy sababi shu (14-vazifa).

### Misol: kimman

```
$ aws sts get-caller-identity
{
    "UserId": "AIDA<...>",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/<user-nomi>"
}
```

`UserId` identifikatsiyaning o'zgarmas ichki ID'si (user nomi o'zgarsa ham qoladi), `Account` so'rov qaysi akkauntga ketayotgani, `Arn` kim nomidan. Bu amal IAM ruxsat talab qilmaydi, shuning uchun credential yaroqli bo'lsa doim ishlaydi. Har ish seansini va har skriptni shu bilan boshlang: noto'g'ri akkaunt yoki profilda `delete` ishlatish cloud'dagi eng qimmat xatolardan biri.

### Natijani shakllantirish

- `--output json|yaml|text|table`. Skript uchun `text` (tab bilan ajratilgan), odam uchun `table`.
- `--query`: JMESPath ifodasi (JSON ichidan qiymat tanlash tili, `jq` filtriga o'xshaydi, lekin sintaksisi boshqa va CLI ichiga o'rnatilgan). Filtrlash mijoz tomonda bajariladi: AWS to'liq javobni yuboradi, CLI kesadi. `Users[].UserName` ro'yxatning har elementidan bitta maydon, `Users[].[UserName,Arn]` har elementdan bir nechta maydon (qator), `Users[?UserName=='alice']` shart bo'yicha filtr.
- `aws <xizmat> help`, `aws <xizmat> <buyruq> help`: lokal hujjat. `--dry-run` (EC2 buyruqlarida): bajarmasdan ruxsatni tekshiradi.
- Uzun natijalar pager'da ochiladi (`q` bilan chiqiladi). O'chirish: `--no-cli-pager` yoki `AWS_PAGER=""`.

### Region

Region va AZ 1-darsda (4-bo'lim) o'tilgan. CLI uchun region bu so'rov qaysi endpoint'ga ketishi: `--region eu-central-1` bilan EC2 so'rovi `ec2.eu-central-1.amazonaws.com` ga boradi va faqat o'sha regiondagi resurslarni ko'radi.

```
$ aws ec2 describe-regions --region-names eu-central-1
{
    "Regions": [
        {
            "Endpoint": "ec2.eu-central-1.amazonaws.com",
            "RegionName": "eu-central-1",
            "OptInStatus": "opt-in-not-required"
        }
    ]
}
```

`Endpoint` shu regionning EC2 API manzili, `OptInStatus` region akkauntda standart yoqilganmi yoki alohida yoqish kerakligini aytadi. IAM kabi global xizmatlarda endpoint bitta.

### Real ishda qachon kerak

- Konsolda 10 daqiqa bosiladigan ish CLI'da bitta buyruq va uni skriptga, runbook'ka, CI'ga qo'yish mumkin.
- Bir nechta akkaunt (mijozlar, prod va staging) bilan ishlaganda profillar va `get-caller-identity` odati.

### Nima uchun shunday

Qidirish tartibi "aniqroq manba umumiyroq manbadan ustun" tamoyiliga qurilgan: bitta buyruq uchun flag, bitta terminal uchun environment, mashina uchun fayl. Shu sabab bitta skript noutbukda profil bilan, CI'da environment bilan, serverda role bilan o'zgarishsiz ishlaydi. Kalit va sozlama ikki faylga ajratilgani ham ataylab: `config` ni ko'rsatsa bo'ladi, `credentials` ni yo'q.

## 7. Credential gigiyenasi

### Qoidalar

- Access key hech qachon git'ga, image'ga, chat'ga, skrinshot'ga tushmaydi. `.gitignore` da `.env`, `*.pem`, `credentials` bo'lsin.
- Kalit kod ichiga yozilmaydi. Lokal: profil. Serverda: instance role. CI'da: OIDC yoki CI secret'lari.
- Har maqsadga va har mashinaga alohida kalit, minimal policy: sizib chiqsa zarar chegaralangan bo'ladi.
- Konsoldagi MFA access key'ni himoyalamaydi: kalit bilan yuborilgan so'rov MFA so'ramaydi. Admin kaliti bor noutbuk shifrlangan va ekrani qulflanadigan bo'lsin.
- Commit'dan oldin secret skaner: gitleaks (https://github.com/gitleaks/gitleaks), pre-commit hook sifatida.

### Mexanizm: rotation

Rotation bu kalitni rejali almashtirish: yangi kalit yaratish (`aws iam create-access-key`), joyiga qo'yish, eskisini `Inactive` qilish (`aws iam update-access-key`), hech narsa buzilmasa o'chirish (`aws iam delete-access-key`). User'da bir vaqtda ikkita kalit bo'la olishi aynan shu uchun. Holatni ko'rish:

```
$ aws iam list-access-keys --query 'AccessKeyMetadata[].[AccessKeyId,Status,CreateDate]' --output text
AKIA<...>	Active	<sana>
```

Har qator bitta kalit: ID, holat (`Active` yoki `Inactive`), yaratilgan vaqt. Kalit oxirgi marta qachon va qaysi xizmatda ishlatilganini `aws iam get-access-key-last-used --access-key-id <ID>` aytadi.

### Kalit sizib chiqsa

Public repozitoriylar avtomatik skanerlanadi: ochiq GitHub'ga tushgan AWS kaliti daqiqalar ichida topiladi va odatda kriptovalyuta mayning uchun katta instanslar ochishda ishlatiladi. Tartib: (1) kalitni darhol `Inactive` qiling va o'chiring, git tarixidan tozalash kalitni xavfsiz qilmaydi, (2) yangi kalit yarating, (3) CloudTrail'da o'sha kalit bilan nima qilinganini ko'ring, (4) barcha regionlarda notanish resurs, IAM user, role va access key'larni qidiring, (5) Bills sahifasini tekshiring va kerak bo'lsa AWS Support'ga yozing.

### Real ishda qachon kerak

- Xodim ketganda, noutbuk yo'qolganda, kalit logga tushganda: rotation tayyor tartib bo'lishi kerak, o'sha kuni o'ylab topiladigan narsa emas.

### Nima uchun shunday

Uzoq muddatli kalit qulay, lekin vaqt o'tgan sari u ko'proq joyga nusxalanadi (eski noutbuk, zaxira, CI). Rotation shu to'planishni kesadi. Yaxshiroq muqobil kalitning umuman yo'qligi: Identity Center, role, OIDC (4-bo'lim).

## 8. CloudTrail

### Nima

CloudTrail akkauntdagi API chaqiruvlarini yozib boradigan audit jurnali: kim, qachon, qayerdan (IP), qaysi amal, natijasi. Konsoldagi har tugma ham API chaqiruvi, u ham yoziladi.

### Mexanizm

- **Event history**: standart yoqilgan, haq olinmaydi, oxirgi 90 kunlik **management event**'lar (resurs yaratish, o'zgartirish, o'chirish, kirish). Region bo'yicha ko'riladi, global xizmatlar (IAM, STS global endpoint) event'lari `us-east-1` da.
- **Trail**: event'larni S3 ga doimiy saqlash uchun alohida sozlanadi (S3 saqlash narxi bor). Production akkauntda majburiy, bu darsda yaratilmaydi.
- **Data event**'lar (masalan har bir S3 obyektni o'qish) standart yozilmaydi.

Har event JSON hujjat: `eventTime`, `eventName`, `eventSource`, `awsRegion`, `sourceIPAddress`, `userIdentity` (kim), rad etilgan bo'lsa `errorCode` va `errorMessage`.

### Misol

```
$ aws cloudtrail lookup-events --region us-east-1 --max-results 3 \
    --lookup-attributes AttributeKey=EventName,AttributeValue=CreateAccessKey \
    --query 'Events[].[EventTime,EventName,Username]' --output text
<vaqt>	CreateAccessKey	<user-nomi>
```

Har qator bitta event: vaqt, amal, uni bajargan identifikatsiya. To'liq JSON `Events[].CloudTrailEvent` maydonida satr ko'rinishida turadi. Event'lar bir necha daqiqa kechikib paydo bo'ladi.

### Real ishda qachon kerak

- `AccessDenied` sababini topish, "bu resursni kim o'chirdi" savoli, hodisa tahlili shu yerdan boshlanadi.
- Least privilege: identifikatsiya haqiqatda qaysi amallarni chaqirganini ko'rib policy'ni toraytirish.

### Nima uchun shunday

Hamma narsa API orqali o'tgani uchun (2-bo'lim) bitta nuqtada to'liq jurnal yuritish mumkin: serverda bunga `auditd`, shell tarixi va loglarni yig'ish kerak bo'lardi. Event history'ning 90 kun bilan cheklangani sabab uzoq saqlash sizning S3'ingizda va sizning hisobingizdan bo'ladi.

Boshqa provayderlardagi mosliklar:

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| Yuqori chegara | Account | Project | Subscription | Team | Project |
| Identifikatsiya | IAM user, role | Google account, service account | Entra ID user, managed identity | Team a'zosi, API token | Project a'zosi, API token |
| Ruxsat berish | Policy (JSON) | IAM role binding | Azure RBAC role assignment | Token scope | Token read yoki read-write |
| Xarajat ogohlantirishi | Budgets | Budgets and alerts | Cost Management budgets | Billing alerts | hujjatdan tekshiring |
| Audit log | CloudTrail | Cloud Audit Logs | Activity Log | hujjatdan tekshiring | hujjatdan tekshiring |
| CLI kirish | `aws configure`, `aws sso login` | `gcloud auth login` | `az login` | `doctl auth init` | `hcloud context create` |

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Account, account ID | resurs, billing va xavfsizlik chegarasi; uning 12 xonali raqami |
| Root user | akkaunt egasi, email va parol bilan kiradi, IAM policy bilan cheklanmaydi |
| MFA | paroldan tashqari ikkinchi isbot (kod, passkey, xavfsizlik kaliti) |
| IAM | AWS'ning identifikatsiya va ruxsat xizmati |
| Authentication / authorization | "kim so'rayapti" ni isbotlash / "unga mumkinmi" ni hal qilish |
| Principal | so'rov yuboruvchi: user, role yoki AWS xizmati |
| User / group / role | doimiy identifikatsiya / user'lar to'plami / vaqtincha olinadigan identifikatsiya |
| ARN | resurs yoki identifikatsiyaning to'liq manzili |
| Access key | dastur uchun credential: access key ID va secret access key juftligi |
| SigV4 | so'rovni secret'ni yubormasdan imzolash usuli |
| Policy | ruxsatlarni tasvirlaydigan JSON hujjat (`Effect`, `Action`, `Resource`, `Condition`) |
| Managed / inline policy | alohida, qayta ishlatiladigan policy / bitta identifikatsiya ichiga yozilgan policy |
| Identity-based / resource-based | identifikatsiyaga / resursga biriktirilgan policy |
| Implicit deny | hech qanday `Allow` yo'qligi sababli rad etish |
| Explicit deny | policy'da yozilgan `Deny`, har qanday `Allow` dan ustun |
| Least privilege | faqat kerakli amal, faqat kerakli resurs |
| Trust policy | role'ni kim olishi mumkinligini belgilaydigan policy |
| STS, session token | vaqtinchalik credential beradigan xizmat; ularning uchinchi qismi |
| IAM Identity Center, permission set | odamlar uchun portal orqali kirish; akkauntda tayinlanadigan ruxsatlar to'plami |
| Profil | `~/.aws/` dagi nomlangan sozlama va credential to'plami |
| JMESPath | `--query` ishlatadigan JSON tanlash tili |
| Budget (actual, forecasted) | xarajat chegarasi va unga bog'langan ogohlantirish (sarflangan yoki prognoz bo'yicha) |
| Tag | resursga qo'yiladigan `kalit=qiymat` yorlig'i |
| Rotation | kalitni rejali ravishda yangisiga almashtirish |
| CloudTrail, management event | API chaqiruvlari jurnali; resurslarni boshqaruvchi amallar yozuvi |

## Tuzoqlar

- Root bilan kundalik ishlash yoki root uchun access key yaratish: sizib chiqsa cheklab bo'lmaydi.
- MFA'siz admin: bitta parol sizishi butun akkaunt.
- Access key'ni git'ga commit qilish. Keyingi commit bilan o'chirish yordam bermaydi, kalit tarixda qoladi va allaqachon o'qilgan.
- `~/.aws/` ni ikkinchi mashinaga nusxalash yoki "qulaylik uchun" bulutli diskka qo'yish: har mashinaga o'z kaliti.
- `AdministratorAccess` ni dastur yoki CI identifikatsiyasiga berish: "keyin toraytiramiz" hech qachon kelmaydi.
- Budget alert'ni limit deb o'ylash: u xarajatni to'xtatmaydi va kechikib keladi.
- `aws sts get-caller-identity` siz ish boshlash: noto'g'ri profil yoki eskirgan `AWS_*` o'zgaruvchisi bilan boshqa akkauntda o'zgarish qilish.
- Eski, ishlatilmaydigan access key va user'larni qoldirish: har biri ochiq eshik.
- Billing'ga IAM kirishini yoqmaslik va shuning uchun hisobni faqat oy oxirida ko'rish.
- Policy'da `Resource` darajasini adashtirish va muammoni `"*"` bilan "hal qilish".
- Resursni tag'siz yaratish: bir oydan keyin u kimniki va qaysi tajribadan qolganini topib bo'lmaydi.
- Mac'da Homebrew va `.pkg` ni birga o'rnatish, Zorin'da v1 (`apt` dagi eski `awscli`) ni qoldirish: `which aws` va `aws --version` bilan qaysi biri ishlayotganini tekshiring.
- Narx yoki free tier limitini eski maqoladan olish: faqat rasmiy sahifa va o'z Bills sahifangiz.

## Manbalar

- https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html – IAM security best practices (majburiy)
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html – root user va faqat root bajaradigan vazifalar
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html – policy baholash mantiqi
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html – policy elementlari
- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html – ARN va ID prefikslari (IAM identifiers)
- https://docs.aws.amazon.com/service-authorization/latest/reference/reference.html – har xizmatning amal va resurs turlari
- https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html – AWS CLI v2 o'rnatish (Linux va macOS)
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html – config va credentials fayllari, profillar
- https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html – CLI va IAM Identity Center
- https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html – `--query` va JMESPath
- https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html – AWS Budgets
- https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html – CloudTrail event history
- https://aws.amazon.com/free/ – free tier shartlari (aniq limitlar faqat shu yerdan)
- https://aws.amazon.com/pricing/ – xizmatlar narxi

## Birga bajaramiz

Bitta identifikatsiyani tug'ilishidan o'chirilishigacha kuzatamiz: `demo-catalog` nomli user faqat EC2 instans tiplari katalogini o'qiy olsin (katalogni o'qish resurs yaratmaydi; 3-darsda eng kichik instans tipini tanlashda shu buyruq kerak bo'ladi). Shart: 4 va 5-vazifalar bajarilgan, `default` profil admin user'niki. Hamma narsa host'da, ikkala mashinada bir xil.

1. Avval kimligingizni tekshiring: `aws sts get-caller-identity`. `Arn` admin user'ingizni ko'rsatishi kerak (6-bo'lim).

2. User yarating, tag bilan:

```
$ aws iam create-user --user-name demo-catalog --tags Key=project,Value=devops-course
{
    "User": {
        "Path": "/",
        "UserName": "demo-catalog",
        "UserId": "AIDA<...>",
        "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/demo-catalog",
        "CreateDate": "<vaqt>",
        "Tags": [ { "Key": "project", "Value": "devops-course" } ]
    }
}
```

`Path` user'lar uchun ixtiyoriy "papka" (standart `/`), `UserId` ichki ID, `Arn` to'liq manzil. Parol ham, policy ham yo'q: bu user hozircha hech narsa qila olmaydi.

3. Unga access key yarating va alohida profilga yozing:

```
$ aws iam create-access-key --user-name demo-catalog
{
    "AccessKey": {
        "UserName": "demo-catalog",
        "AccessKeyId": "AKIA<...>",
        "Status": "Active",
        "SecretAccessKey": "<faqat shu yerda bir marta ko'rinadi>",
        "CreateDate": "<vaqt>"
    }
}
$ aws configure --profile demo-catalog
AWS Access Key ID [None]: AKIA<...>
AWS Secret Access Key [None]: <...>
Default region name [None]: eu-central-1
Default output format [None]: json
```

`SecretAccessKey` keyin hech qayerdan qayta o'qilmaydi: yo'qotsangiz kalit o'chirilib yangisi yaratiladi. Terminal tarixida secret qolmasligi uchun uni buyruq argumenti sifatida emas, `aws configure` so'roviga javob sifatida kiritdik.

4. Shu profil bilan katalogni so'rang:

```
$ aws ec2 describe-instance-types --instance-types t3.micro --profile demo-catalog
An error occurred (UnauthorizedOperation) when calling the DescribeInstanceTypes operation: You are not authorized to perform this operation. User: arn:aws:iam::<ACCOUNT_ID>:user/demo-catalog is not authorized to perform: ec2:DescribeInstanceTypes because no identity-based policy allows the ec2:DescribeInstanceTypes action
```

Authentication o'tdi (AWS user'ni ARN'i bilan aytyapti), authorization o'tmadi. EC2 xato kodini `UnauthorizedOperation` deb ataydi (boshqa xizmatlarda `AccessDenied`). Oxirgi qism sababni aytadi: hech bir policy bu amalga ruxsat bermaydi, ya'ni implicit deny (3-bo'lim).

5. Vaqtinchalik katalogda (repoda emas) policy yozing va inline policy sifatida biriktiring:

```
$ cd "$(mktemp -d)"
$ cat > catalog.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "ec2:DescribeInstanceTypes",
    "Resource": "*"
  }]
}
JSON
$ aws iam put-user-policy --user-name demo-catalog \
    --policy-name catalog-read --policy-document file://catalog.json
```

`put-user-policy` muvaffaqiyatda hech narsa chiqarmaydi (`echo $?` nol). `file://` CLI'ga qiymatni fayldan o'qishni aytadi. `Resource` bu yerda `"*"`, chunki katalog amali alohida resursga bog'lanmaydi.

6. So'rovni takrorlang, bu safar natijani shakllantirib (IAM o'zgarishi bir necha soniyada tarqaladi, darhol ishlamasa qayta urining):

```
$ aws ec2 describe-instance-types --instance-types t3.micro t4g.micro --profile demo-catalog \
    --query 'sort_by(InstanceTypes,&InstanceType)[].[InstanceType,VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB,ProcessorInfo.SupportedArchitectures[0]]' \
    --output text
t3.micro	2	1024	x86_64
t4g.micro	2	1024	arm64
```

Har qator bitta instans tipi: nomi, vCPU soni, xotira (MiB), arxitektura. `sort_by(...)` tartibni barqaror qiladi, `[].[...]` har elementdan to'rt maydon oladi, `[0]` ro'yxatning birinchi elementi. `t3` Zorin'dagi kabi `x86_64`, `t4g` Mac'dagi kabi `arm64`: 4-darsda image arxitekturasi shu yerga bog'lanadi.

7. Ruxsat faqat yozilgan amalga tegishli ekanini ko'ring: `aws ec2 describe-instances --profile demo-catalog` yana `UnauthorizedOperation` beradi, endi `ec2:DescribeInstances` uchun.

8. Tozalash. User'ni o'chirishdan oldin unga tegishli hamma narsa o'chiriladi, aks holda `DeleteConflict` xatosi chiqadi:

```
$ aws iam delete-user-policy --user-name demo-catalog --policy-name catalog-read
$ aws iam delete-access-key --user-name demo-catalog --access-key-id AKIA<...>
$ aws iam delete-user --user-name demo-catalog
$ aws iam list-users --query "Users[?UserName=='demo-catalog'].UserName"
[]
```

Oxirgi buyruq bo'sh ro'yxat qaytardi: user yo'q. Profilni o'chiradigan CLI buyrug'i yo'q: `~/.aws/credentials` dan `[demo-catalog]`, `~/.aws/config` dan `[profile demo-catalog]` bo'limini muharrirda o'chiring va `aws configure list-profiles` bilan tekshiring. Vaqtinchalik katalogdagi `catalog.json` ni ham o'chiring.

Shu 8 qadamda ko'rganingiz: har ish `get-caller-identity` dan boshlanadi (6-bo'lim); yangi user'da ruxsat yo'q, authentication o'tib authorization o'tmaydi (2 va 3-bo'limlar); bitta `Allow` faqat o'zida yozilgan amalni ochadi (3-bo'lim); `--query` natijani kesadi (6-bo'lim); kalit va profil mashinada qoladigan iz, ular ham tozalanadi (7-bo'lim); resurs tag bilan yaratiladi (5-bo'lim).

---

## Vazifalar

Vazifalarni `cloud/02-first-setup/` papkasida bajaring (`make new m=cloud n=02 name=first-setup` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar yoki konsol qadamlari, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (policy JSON, skript) shu papkada saqlanadi. `README.md` ga account ID, access key va secret yozmang: account ID o'rniga `123456789012`, kalit o'rniga `AKIA...` qoldiring. Konsol vazifalari (A guruh, 4) brauzerda bir marta bajariladi; CLI vazifalari host'da, qaysi mashinada (Zorin yoki macOS) bajarganingizni README'da yozing. Vazifalarni bitta mashinada boshidan oxirigacha bajarish yetarli; ikkinchi mashinada faqat 5 va 6-vazifalar takrorlanadi (o'sha mashina uchun alohida kalit bilan, Laboratoriya bo'limidagi cheklovga qarang). Policy fayllari va skriptlardan tashqari hech narsa `~/.aws/` dan repoga ko'chirilmaydi.

### A. Akkaunt va root

1. **Create the account.** AWS akkaunt oching. Jarayonda taklif qilingan reja va free tier shartlarini https://aws.amazon.com/free/ dan o'qib, o'zingizga tegishli uchta shartni (muddat, kredit yoki limit, tugaganda nima bo'ladi) sana bilan yozing. Kelajakdagi o'zingiz uchun: bu shartlar qachon tugaydi? Yo'nalish: 1-bo'lim, "Misol: konsolda nima ko'rasiz".

2. **Lock down root.** Root uchun MFA yoqing va Security credentials sahifasida root access key yo'qligini tekshiring. Chiqib, qayta kirib MFA so'ralishini ko'ring. Root faqat o'zi bajara oladigan uchta vazifani hujjatdan topib yozing. Yo'nalish: 1-bo'lim, "Mexanizm: root user".

3. **Budget alert.** Root bilan billing ma'lumotiga IAM kirishini yoqing. AWS Budgets'da ikkita budget yarating: "Zero spend budget" shabloni va o'zingiz chidaydigan kichik oylik summa uchun "Monthly cost budget" (haqiqiy xarajatning 50% va 100% ida, prognozning 100% ida email). Free tier alert'larni ham yoqing. Tasdiqlash emailini ko'rsating. Yo'nalish: 5-bo'lim, "Misol: konsol va CLI".

### B. IAM

4. **Admin identity.** `admins` group yarating, unga `AdministratorAccess` biriktiring, o'zingiz uchun IAM user yaratib group'ga qo'shing, konsol paroli va MFA o'rnating. Root'dan chiqing va shu user bilan kiring. Bundan keyin root ishlatilmaydi. Nima uchun policy user'ga emas, group'ga biriktirildi? Yo'nalish: 2-bo'lim, "Ikki savol".

5. **Install the CLI.** AWS CLI v2 ni Laboratoriya bo'limidagi, shu mashinangizga mos usul bilan o'rnating (Zorin: `x86_64` zip, macOS: Homebrew yoki `.pkg`). `aws --version` va `which aws` natijasini yozing. Admin user uchun access key yarating, `aws configure` bilan `default` profilni sozlang. `ls -l ~/.aws/` huquqlarini tekshiring. `aws --version` chiqishidagi qaysi qism mashinangiz arxitekturasini ko'rsatadi? Yo'nalish: Laboratoriya, "AWS CLI v2 ni o'rnatish" va 6-bo'lim, "Konfiguratsiya fayllari".

6. **Who am I.** `aws sts get-caller-identity` ishlating va uchta maydonni izohlang. Keyin `AWS_ACCESS_KEY_ID=AKIAFAKE AWS_SECRET_ACCESS_KEY=fake aws sts get-caller-identity` ishlating, xatoni o'qing. `aws configure list` ikki holatda credential manbasini qanday ko'rsatadi? Yo'nalish: 6-bo'lim, "Misol: kimman" va 2-bo'lim, "Misol: noto'g'ri secret".

7. **Implicit deny.** `lab-readonly` user yarating (policy'siz, konsol parolisiz), unga access key yaratib `lab-readonly` profiliga yozing. Shu profil bilan `aws iam list-users` va `aws s3 ls` ishlating. Xato matnini to'liq yozing va undagi har qismni (kim, qaysi amal, qaysi resurs, nima sababdan) izohlang. Yo'nalish: 3-bo'lim, "Mexanizm: baholash mantiqi".

8. **Managed policy.** `lab-readonly` user'ga `ReadOnlyAccess` managed policy biriktiring va 7-vazifadagi buyruqlarni takrorlang. Keyin shu profil bilan `aws iam create-user --user-name hack` ishlatib ko'ring. Policy'ning JSON'ini konsolda oching: `Action` lar qanday shablonlar bilan yozilgan? Yo'nalish: 3-bo'lim, "Policy turlari".

9. **Custom policy.** `task_9.json` yozing: faqat nomi `devops-course-` bilan boshlanadigan bucket'larda obyektlarni ko'rish va o'qishga ruxsat beradigan identity-based policy (bucket hali yo'q, 3-darsda kerak bo'ladi). Uni customer managed policy sifatida yarating. `aws iam simulate-principal-policy` bilan uchta holatni tekshiring: mos bucket'dan `s3:GetObject`, boshqa nomli bucket'dan `s3:GetObject`, mos bucket'ga `s3:PutObject`. Natijadagi `EvalDecision` qiymatlarini izohlang. Yo'nalish: 3-bo'lim, "Misol: policy'ni qatorma-qator o'qish" va "Tuzoq: amal va resurs darajasi mos kelmasligi".

10. **Explicit deny wins.** `lab-readonly` user'ga `ReadOnlyAccess` ustiga `iam:*` amallarini `Deny` qiladigan inline policy qo'shing. `aws iam list-users --profile lab-readonly` natijasi qanday o'zgardi? Xato matni 7-vazifadagidan nimasi bilan farq qiladi? Baholash mantiqining uch qadamini shu misolda tushuntiring. Yo'nalish: 3-bo'lim, "Mexanizm: baholash mantiqi".

11. **Assume a role.** `lab-s3-reader` role yarating: trust policy'da faqat sizning admin user'ingiz, permission sifatida `AmazonS3ReadOnlyAccess`. `~/.aws/config` ga `role_arn` va `source_profile` li profil qo'shing. Shu profil bilan `aws sts get-caller-identity` ishlating: `Arn` qanday ko'rinishda? Keyin `aws sts assume-role` ni qo'lda chaqirib javobdagi `Expiration` ni toping. Vaqtinchalik credential'ning access key ID si qaysi prefiks bilan boshlanadi, uzoq muddatlisi-chi? Yo'nalish: 4-bo'lim, "Mexanizm: STS" va 6-bo'lim, "Konfiguratsiya fayllari".

12. **Wrong principal.** 11-vazifadagi role'ni `lab-readonly` profili orqali olishga urinib ko'ring (`source_profile` ni almashtirib). Xatoni yozing. Bu xato trust policy'danmi yoki permission policy'danmi, qanday aniqladingiz? Yo'nalish: 4-bo'lim, "Role nima".

### C. CLI

13. **Query and output.** Faqat `--query` va `--output` yordamida (`jq` va `grep` siz): (a) barcha IAM user'lar nomi va yaratilgan sanasini jadval ko'rinishida, (b) `admins` group'ga biriktirilgan policy ARN'larini matn ko'rinishida, (c) siz tanlagan regiondagi AZ nomlarini chiqaring. Buyruqlarni yozing. Yo'nalish: 6-bo'lim, "Natijani shakllantirish".

14. **Credential precedence.** Tajriba bilan isbotlang: `AWS_PROFILE=lab-readonly` o'rnatilgan terminalda `--profile default` berilsa qaysi biri yutadi? `AWS_ACCESS_KEY_ID` va `AWS_SECRET_ACCESS_KEY` (lab-readonly kalitlari) export qilinib, `AWS_PROFILE=default` bo'lsa-chi? Har holatda `aws sts get-caller-identity` va `aws configure list` natijasini ko'rsating. Oxirida o'zgaruvchilarni `unset` qiling. Yo'nalish: 6-bo'lim, "Mexanizm: credential va region qidirish tartibi".

15. **Region scope.** `aws ec2 describe-regions` bilan akkauntingizda yoqilgan regionlar sonini toping. `aws ec2 describe-availability-zones` ni ikki xil `--region` bilan ishlating. `aws iam list-users --region` ga turli region bersangiz natija o'zgaradimi, nima uchun? Yo'nalish: 6-bo'lim, "Region".

### D. Gigiyena va audit

16. **Key rotation.** Admin user uchun kalitni almashtiring: ikkinchi kalit yarating, profilga yozing, tekshiring, eskisini `Inactive` qiling, yana tekshiring, eskisini o'chiring. `aws iam list-access-keys` natijasini har bosqichda ko'rsating. Nima uchun eski kalit darhol o'chirilmay avval `Inactive` qilinadi? Yo'nalish: 7-bo'lim, "Mexanizm: rotation".

17. **Leak drill.** Vaqtinchalik katalogda yangi git repozitoriy yarating (push qilinmaydi). Unga `lab-readonly` ning access key'ini fayl ichida commit qiling, keyingi commit'da faylni o'chiring. `git log -p` bilan kalit hali ham tarixda ekanini ko'rsating. gitleaks hujjatidagi usul bilan (Docker image orqali) repozitoriyni skanerlang, topilmani yozing. Keyin 7-bo'limdagi tartib bo'yicha kalitni o'chiring va katalogni yo'q qiling. Real hodisada yana qaysi qadamlar bo'lar edi? Yo'nalish: 7-bo'lim, "Kalit sizib chiqsa".

18. **Read CloudTrail.** CloudTrail event history'dan (konsol va `aws cloudtrail lookup-events`) toping: (a) o'zingizning oxirgi `ConsoleLogin`, (b) 4-vazifadagi `CreateUser`, (c) 7 yoki 10-vazifadagi rad etilgan chaqiruvlardan biri. Har birida `userIdentity`, `sourceIPAddress`, `errorCode` maydonlarini ko'rsating. IAM event'lari qaysi regionda chiqdi va nima uchun? Yo'nalish: 8-bo'lim, "Mexanizm" va "Misol".

19. **Identity Center.** Ixtiyoriy. IAM Identity Center'ni yoqing, o'zingizga user va `AdministratorAccess` permission set tayinlang, `aws configure sso` bilan profil yarating, `aws sso login` dan keyin `aws sts get-caller-identity` natijasini ko'rsating. `~/.aws/` ichida nima saqlandi va u access key'dan nimasi bilan xavfsizroq? Bajarmasangiz, hujjatni o'qib shu savollarga nazariy javob yozing. Yo'nalish: 4-bo'lim, "IAM Identity Center".

20. **Cleanup and baseline.** `lab-readonly` user'ni (avval kalitlari va policy'lari bilan), `lab-s3-reader` role'ni va 9-vazifadagi policy'ni o'chiring, `~/.aws/` dan ularning profillarini olib tashlang. Keyin `task_20.sh` yozing: akkauntning boshlang'ich holatini chiqaradigan skript (`get-caller-identity`, IAM user'lar va har birining access key'lari soni va yoshi, root MFA yoqilganligi `aws iam get-account-summary` orqali, budget'lar ro'yxati). Skript ikkala mashinada ishlashi kerak (macOS'da bash 3.2 va BSD utilitalar: GNU `date -d`, `grep -P` ishlatilmaydi; kalit yoshini `CreateDate` orqali ko'rsatish yetarli) va unda kalit yoki secret yozilmaydi. Oxirida tanlagan regioningizda ishlab turgan EC2 instans va `project=devops-course` tag'li resurs yo'qligini ham buyruq bilan ko'rsating (bu darsda hech narsa yaratilmagan, natija bo'sh bo'lishi kerak). Skript natijasini (account ID yashirilgan holda) `README.md` ga qo'ying. Bu skriptni 3 va 4-darslar boshida qayta ishlatasiz. Yo'nalish: "Birga bajaramiz" 8-qadam, 1-bo'lim va 5-bo'lim, "Tag'lar".

### Topshirish

Tayyor bo'lgach:
1. `cloud/02-first-setup/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida (19-vazifa bajarilmagan bo'lsa nazariy javob bilan); papkada `task_9.json` va `task_20.sh` bor.
2. Root MFA yoqilgan, root access key yo'q, kundalik ish admin IAM user (yoki Identity Center) orqali.
3. Ikkala budget mavjud, tasdiqlash emaili kelgan.
4. Test user, role, policy va ortiqcha access key'lar o'chirilgan, `~/.aws/` da faqat kerakli profil qolgan: `task_20.sh` natijasi buni ko'rsatadi. Bills sahifasida kutilmagan xarajat yo'q.
5. `README.md` va fayllarda haqiqiy kalit, secret va account ID yo'q; `~/.aws/` dan hech narsa repoga tushmagan. `make check` toza.
6. Ikkinchi mashinada ishlasangiz: u yerda CLI o'rnatilgan, alohida kalit bilan profil sozlangan va `aws sts get-caller-identity` ishlaydi.
7. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- AWS akkaunt qaysi uch narsaning chegarasi? Root user IAM admin user'dan nimasi bilan farq qiladi va nima uchun kundalik ishda ishlatilmaydi?
- Authentication va authorization farqi nima? `SignatureDoesNotMatch` va `AccessDenied` qaysi biriga tegishli?
- Secret access key so'rov ichida yuboriladimi? Imzolash bearer token'dan nimasi bilan xavfsizroq?
- Konsol, CLI va SDK orasidagi munosabat qanday?
- User, group va role farqi nima? Qaysi biri uzoq muddatli credential'ga ega emas?
- Policy baholashning uch qadami qanday? Yangi user nima uchun hech narsa qila olmaydi?
- Trust policy va permission policy nimani hal qiladi?
- Nima uchun serverdagi dastur uchun access key emas, role ishlatiladi?
- CLI credential'ni qaysi tartibda qidiradi va bu qanday xatoga olib keladi?
- Nima uchun har mashinada alohida access key bo'ladi va `~/.aws/` git'ga tushmaydi?
- Budget alert nima qila oladi va nima qila olmaydi? Tag xarajat nazoratida qanday yordam beradi?
- Access key git'ga tushib qoldi. Birinchi uch qadamingiz qanday va nima uchun commit'ni o'chirish yetarli emas?
- CloudTrail event history nimani ko'rsatadi, nimani ko'rsatmaydi?
- `s3:ListBucket` va `s3:GetObject` uchun `Resource` nima uchun turlicha yoziladi?
