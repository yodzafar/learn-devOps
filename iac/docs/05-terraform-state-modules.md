# 5-dars: Terraform state, modullar va CI

Maqsad: 4-darsdagi "bir kishi, bir noutbuk, lokal state" holatidan bir nechta odam (va sizning ikki mashinangiz) birga ishlata oladigan holatga o'tish. Buning uchun state'ni S3 remote backend'ga ko'chirasiz va lock nima ekanini ko'rasiz, state bilan xavfsiz ishlashni (`state list/show/mv/rm`, `import`, `moved`, `removed`, `-replace`) va drift'ni aniqlashni o'rganasiz, muhitlarni ajratishning ikki usulini (workspace va papka) solishtirasiz, modul yozasiz va versiyalaysiz, state ichidagi secret'lar bilan nima qilishni bilasiz, statik tekshiruv (tflint, trivy yoki checkov) va pipeline'da `plan`/`apply` oqimini qurasiz. Oxirida Terraform va 3-darsdagi Ansible role'lari birlashadi: bitta buyruq butun app muhitini quradi, bitta buyruq o'chiradi. Bu modulning yakuniy darsi.

Taxminiy vaqt: 8 kun (siz uchun). 1–2-kunlar: 1–2 bo'limlar va A guruh (remote state, lock). 3-kun: 3-bo'lim, "Birga bajaramiz" va B guruh. 4–5-kunlar: 4–6 bo'limlar va C guruh (modullar, muhitlar). 6-kun: 7-bo'lim va D guruh (lint, CI). 7-kun: 8-bo'lim va 18–19-vazifalar. 8-kun: 20-vazifa, tozalikni tekshirish va README. Diqqatni mexanizmga qarating: lock nimadan himoya qiladi, refactoring paytida resurs qayta yaratilmasligi uchun nima qilinadi, `sensitive` nimani yashirmaydi, CI'da aynan qaysi reja qo'llanadi, ikki asbob orasida ma'lumot qanday uzatiladi.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. ID, vaqt, akkaunt raqami va IP kabi sizda boshqacha bo'ladigan joylar `<...>` bilan belgilangan. AWS'ga tegadigan har mashg'ulotdan oldin budget alert'ni tekshiring, mashg'ulot oxirida `terraform destroy` qiling. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsning asosiy ipi: ikki mashinangiz birinchi marta **bitta infratuzilma holatini** bo'lishadi. Hozirgacha laboratoriya holati mashinalar orasida ko'chmas edi (VM va konteynerlar har joyda qayta yaratilardi). Remote backend'dan keyin ofisda `apply` qilingan VPC'ni uyda `plan` ko'radi, chunki ikkala mashina bitta state faylini S3'dan o'qiydi. Kod git orqali, state S3 orqali ko'chadi; qolgan hamma narsa (kalitlar, `.terraform/`) har mashinada alohida.

| Muhit | Bu darsda nima uchun |
|-------|----------------------|
| Host (Zorin yoki macOS) | `terraform` (4-dars), `ansible` (2-dars), AWS CLI (cloud moduli), `git`, `make`, `docker` |
| Lokal, cloud'siz | "Birga bajaramiz" va 12-vazifaning workspace qismi: `hashicorp/local`, `hashicorp/random` va 4-darsdagi Docker provider |
| AWS akkaunt | deyarli barcha vazifalar: state bucket, VPC, security group, EC2 |
| GitHub | 16–17-vazifalar: repo va Actions (cicd 2), AWS'ga OIDC orqali kirish (cicd 5) |

Yangi asboblar faqat linter'lar. Ular o'rnatilmaydi, Docker orqali ishlatiladi (ikkala mashinada bir xil buyruq):

```
docker run --rm -v "$(pwd):/data" -t ghcr.io/terraform-linters/tflint
docker run --rm -v "$(pwd):/src" aquasec/trivy config /src
```

macOS'da image `arm64` variantda tortiladi. Docker'siz ishlatmoqchi bo'lsangiz macOS'da `brew install tflint trivy`; Zorin uchun (`amd64`) o'rnatish yo'li har asbobning rasmiy sahifasida (Manbalar), versiya va URL'ni o'sha yerdan oling.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Provider binary'lari `linux_amd64`. AWS profili, SSH kaliti va tashqi IP shu mashinaniki. Lock xatosidagi `Who` maydonida shu mashinaning `user@host` i chiqadi. |
| macOS (uy) | Provider binary'lari `darwin_arm64`. AWS profili, SSH kaliti va tashqi IP boshqa. BSD userland: skript va `Makefile` da `sed -i`, `grep -P` ishlatmang. Docker yashirin Linux VM ichida, lekin bu darsda linter'lar faqat fayl o'qiydi, farq sezilmaydi. |

Ikkinchi mashinada takrorlanadigan ishlar (birinchi marta va har `git pull` dan keyin kerak bo'lsa):

```
aws sts get-caller-identity          # which account and identity this machine uses
terraform init                       # downloads providers, connects to the same S3 backend
terraform plan                       # must show the state the other machine left
```

- `.terraform/` commit qilinmaydi, shuning uchun har mashinada `terraform init` kerak. Commit qilinadigan `.terraform.lock.hcl` da ikkala platforma hash'lari bo'lishi shart: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` (4-dars). Aks holda ikkinchi mashinada `init` checksum xatosi beradi.
- AWS kalitlari har mashinada o'z CLI profilida (`AWS_PROFILE` yoki `aws configure`), `.tf` va commit qilinadigan `*.tfvars` da emas.
- Mashinaga bog'liq qiymatlar endi umumiy state'ga tushadi. SSH ingress uchun tashqi IP (`curl -s https://checkip.amazonaws.com`) ofisda va uyda boshqa: u o'zgaruvchi bo'lib, git-ignore qilingan `*.auto.tfvars` yoki `TF_VAR_...` orqali beriladi, hech qachon `0.0.0.0/0` emas. Mashinani almashtirgach birinchi `plan` security group'da in-place o'zgarish ko'rsatadi, bu kutilgan holat. SSH kaliti ham har mashinada alohida: ikkalasining **public** kalitini serverga qanday berishni o'zingiz hal qilasiz (public kalit secret emas).
- Lokal qoldiqlar (`terraform.tfstate`, `*.tfstate.backup`, plan fayllari, secret'li `*.tfvars`) commit qilinmaydi, `make secrets` ularni rad etadi. Generatsiya qilingan Ansible inventory ham (ichida IP bor) commit qilinmaydi, 3-darsdagi kabi.

AWS tartibi (har mashg'ulotda, shu ketma-ketlikda):

1. Budget alert borligini tekshiring: `aws budgets describe-budgets --account-id <ACCOUNT_ID>`.
2. Bitta region, eng kichik instans tipi, bir vaqtda ikkitadan ortiq EC2 yo'q, NAT gateway va load balancer yo'q. 13-vazifa faqat `plan`, `apply` qilinmaydi.
3. Har resursda `Project = iac-lab` tegi (provider'dagi `default_tags`, 4-dars).
4. Mashg'ulot oxirida `terraform destroy` va teg bo'yicha tekshiruv:

```
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=iac-lab \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

State bucket alohida `bootstrap/` konfiguratsiyasida turadi va muhitlar bilan birga o'chirilmaydi: dars davomida u qoladi, yuqoridagi tekshiruvda faqat u ko'rinishi kerak. Modul tugaganda (20-vazifa) u eng oxirida o'chiriladi va tekshiruv bo'sh chiqishi kerak. Hozirgina terminate qilingan EC2 bu ro'yxatda bir muddat ko'rinib turishi mumkin; shubha bo'lsa `aws ec2 describe-instances` da holatini qarang.

---

## 1. Remote state va backend

### Lokal state nima uchun yetmaydi

State (4-dars, 6-bo'lim) bu Terraform'ning "men nimani yaratganman" degan yozuvi: koddagi har resurs manzilini (`aws_instance.app`) real obyekt ID'siga (`i-0abc...`) bog'laydigan JSON fayl. 4-darsda u ish papkasidagi `terraform.tfstate` edi. Bunda uchta muammo bor:

- **U bitta diskda.** Ofisda `apply` qildingiz, uyda `git pull` qildingiz: kod bor, state yo'q. Uydagi Terraform "hech narsa yaratilmagan" deb hisoblaydi va hammasini ikkinchi marta yaratmoqchi bo'ladi. Hamkasb va CI uchun ham xuddi shunday. Bu muammo bir kishida ham bor, ikki mashina yetarli.
- **Bir vaqtda yozishdan himoya yo'q.** Ikki jarayon bir paytda `apply` qilsa, ikkalasi eski state'ni o'qiydi va oxirgi yozgani birinchisining natijasini o'chirib yuboradi.
- **Ichida secret'lar ochiq matnda** (6-bo'lim), shuning uchun uni git'ga qo'yish yechim emas. Git yana bir sababga ko'ra yaramaydi: `git pull` qilishni unutgan odam eski state bilan ishlaydi.

### Backend nima

**Backend** bu Terraform state'ni qayerda saqlashi va qanday qulflashini belgilaydigan sozlama. Hech narsa yozilmasa `local` backend ishlaydi (ish papkasidagi fayl). `s3` backend state'ni S3 bucket'dagi obyekt sifatida saqlaydi (S3 va bucket: cloud moduli).

```
terraform {
  backend "s3" {
    bucket       = "iac-lab-tfstate-<ACCOUNT_ID>"
    key          = "notes/dev/terraform.tfstate"
    region       = "<REGION>"
    encrypt      = true
    use_lockfile = true
  }
}
```

- `bucket` va `region`: state turadigan bucket. Bucket nomi butun AWS bo'yicha yagona bo'lishi kerak, shuning uchun akkaunt raqami qo'shiladi.
- `key`: bucket ichidagi obyekt yo'li. Har muhit va har mustaqil konfiguratsiya uchun alohida `key`, aks holda ikki konfiguratsiya bir-birining state'ini ustidan yozadi.
- `encrypt = true`: obyekt server tomonida shifrlab saqlanadi.
- `use_lockfile = true`: lock (2-bo'lim).

Mexanizm: `terraform init` backend blokini o'qiydi va sozlamani `.terraform/terraform.tfstate` fayliga yozib qo'yadi (nomi chalg'itadi: bu infratuzilma state'i emas, "state qayerda" degan ko'rsatkich). Shundan keyin har `plan`/`apply` shunday ishlaydi: lock oladi, state'ni S3'dan xotiraga yuklaydi, ishni bajaradi, yangi state'ni S3'ga yozadi, lock'ni bo'shatadi. Diskda state nusxasi qolmaydi.

### Backend o'zgarganda: `init -migrate-state`

Backend bloki qo'shilsa yoki o'zgarsa, keyingi buyruq `Backend initialization required` xatosi bilan to'xtaydi: `.terraform/` dagi ko'rsatkich kodga mos kelmay qoldi. Ikki yo'l bor:

- `terraform init -migrate-state`: eski backend'dagi state'ni yangisiga ko'chiradi. Yangi joy bo'sh bo'lsa tasdiq so'raydi:

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

Birinchi xatboshi nima topilganini aytadi: eski (`local`) backend'da state bor, yangisida yo'q. `yes` ko'chiradi, `no` yangi backend'da bo'sh state bilan boshlaydi (resurslar AWS'da qoladi, lekin Terraform ularni "unutadi"). Oxirgi ikki qator ko'rsatkich yangilanganini bildiradi.

- `terraform init -reconfigure`: hech narsa ko'chirmaydi, faqat ko'rsatkichni yangi sozlamaga almashtiradi. State allaqachon yangi joyda turgan bo'lsa (masalan ikkinchi mashinada) shu kerak.

`backend` blokida `var.` va `local.` ishlatib bo'lmaydi, chunki backend o'zgaruvchilar hisoblanishidan oldin, `init` paytida o'qiladi. Muhitga qarab farq qiladigan qism buyruq satridan beriladi (**partial configuration**): `terraform init -backend-config="key=notes/stage/terraform.tfstate"` yoki `-backend-config=<file>`.

### State bucket talablari va tovuq-tuxum muammosi

State bucket oddiy bucket emas, u butun infratuzilmaning kaliti:

- **Versioning** yoqilgan: har yozuv yangi versiya, buzilgan state oldingi versiyadan tiklanadi.
- **Shifrlash** yoqilgan va **public access to'liq bloklangan**. State hech qachon ochiq bo'lmasligi kerak.
- **Kirish huquqi tor**: bucket'ni o'qiy olgan har kim state'dagi barcha secret'larni o'qiydi.
- **Tasodifiy o'chirishdan himoyalangan** va muhitlar bilan birga `destroy` qilinmaydi.

Muammo: bucket'ning o'zi ham resurs. Uni Terraform bilan yaratmoqchisiz, lekin Terraform state'ni saqlash uchun o'sha bucket'ni talab qiladi. Odatiy yechim **bootstrap**: alohida kichik konfiguratsiya, u faqat bucket'ni yaratadi va boshida lokal state bilan ishlaydi. Keyin uning state'i bilan nima qilish (lokal qoldirish, shu bucket'ga ko'chirish) ochiq savol, 1-vazifada o'zingiz javob berasiz.

### Real ishda qachon kerak

- Loyihada birinchi kundan: ikkinchi odam, ikkinchi mashina yoki CI paydo bo'lishi bilan lokal state ishlamaydi.
- Yangi mashinada ishni davom ettirish: `git clone`, profil, `terraform init`, tamom.
- "Kecha nima o'zgardi" savoli: bucket versiyalari state tarixini beradi.

### Nima uchun shunday

Terraform state'ni cloud'ning o'zidan har safar qayta hisoblamaydi, chunki bu sekin va noaniq: AWS'dagi qaysi VPC "sizniki" ekanini teg yoki nomdan ishonchli bilib bo'lmaydi. Shuning uchun aniq yozuv (state) kerak, yozuv bo'lgach uni hamma ko'radigan bitta joyda saqlash kerak. Backend'lar almashtiriladigan qilib qilingan (S3, Google Cloud Storage, Azure Blob, HCP Terraform va boshqalar), asbob bitta cloud'ga bog'lanmaydi. Muqobil model: AWS CloudFormation state'ni servis ichida o'zi saqlaydi, sizda fayl yo'q, lekin u faqat AWS uchun.

## 2. Locking

### Lock nima va nimadan himoya qiladi

**Lock** (qulf) bu "state bilan hozir men ishlayapman" degan belgi: u turgan paytda boshqa jarayon shu state bilan ishlay olmaydi. Himoya qilinadigan holat: ofisdagi `apply` state'ni o'qidi va resurs yaratyapti; shu paytda CI ham `apply` boshladi va o'sha eski state'ni o'qidi. Ikkalasi tugagach oxirgi yozilgan state birinchisining resurslarini bilmaydi: ular AWS'da bor, state'da yo'q. Xuddi shu muammo baza migration'larida ham bor (migration: baza sxemasini o'zgartiradigan skript): ikki kishi bir vaqtda ishga tushirsa natija buziladi, shuning uchun migration asboblari ham baza darajasida lock oladi.

### Mexanizm

State'ni o'zgartirishi mumkin bo'lgan har buyruq (`plan`, `apply`, `destroy`, `state mv`, `import`) boshida lock oladi, oxirida bo'shatadi. S3 backend'da ikki mexanizm bo'lgan:

- **S3 native lock** (`use_lockfile = true`): state obyekti yonida `<key>.tflock` obyekti yaratiladi. S3'ning "faqat obyekt hali yo'q bo'lsa yoz" degan shartli yozuvi ikki jarayondan faqat bittasi yutishini kafolatlaydi. Bu imkoniyat Terraform 1.10 dan boshlab bor.
- **DynamoDB lock** (`dynamodb_table = "<jadval>"`): eski usul, `LockID` nomli partition key'li jadval talab qiladi. Yangi Terraform versiyalarida eskirgan (deprecated) deb belgilangan, lekin eski loyihalarda ko'p uchraydi.

Standart holatda S3 backend'da lock **o'chiq**, uni aniq yoqish kerak. Argumentlar va kerakli IAM ruxsatlar versiyaga qarab o'zgargan, shuning uchun o'zingiz ishlatayotgan Terraform yoki OpenTofu versiyasi uchun backend hujjatini (Manbalar) o'qing.

### Lock band bo'lganda

Lock boshqa jarayonda bo'lsa, buyruq darhol to'xtaydi:

```
╷
│ Error: Error acquiring the state lock
│
│ Error message: <backend-specific text>
│ Lock Info:
│   ID:        <LOCK_ID>
│   Path:      <bucket>/<key>
│   Operation: OperationTypeApply
│   Who:       <user>@<host>
│   Version:   <terraform version>
│   Created:   <timestamp>
│   Info:
│
│ Terraform acquires a state lock to protect the state from being written
│ by multiple users at the same time. Please resolve the issue above and try
│ again. For most commands, you can disable locking with the "-lock=false"
│ flag, but this is not recommended.
╵
```

Qatorma-qator: `ID` lock'ning yagona identifikatori (`force-unlock` shuni so'raydi); `Path` qaysi state qulflangani; `Operation` lock'ni olgan amal turi (bu yerda `apply`); `Who` uni olgan foydalanuvchi va mashina (ofis yoki uy ekanini shundan bilasiz); `Version` o'sha tomondagi Terraform versiyasi; `Created` qachon olingani. Oxirgi xatboshi `-lock=false` ni eslatadi: u lock'ni butunlay chetlab o'tadi, o'qiydigan buyruqdan boshqasida ishlatilmaydi.

`-lock-timeout=<vaqt>` (masalan `-lock-timeout=5m`) darhol xato bermay, lock bo'shashini shu vaqt davomida qayta-qayta sinab kutadi. CI'da foydali.

### Stale lock va `force-unlock`

Jarayon o'ldirilsa (noutbuk qopqog'i yopildi, tarmoq uzildi, CI job bekor qilindi), lock bo'shatilmay qoladi. Bu **stale lock**: xato matni yuqoridagidek, lekin `Who` dagi jarayon endi yo'q. Uni `terraform force-unlock <LOCK_ID>` olib tashlaydi (tasdiq so'raydi). Xavfi: lock egasi aslida hali ishlayotgan bo'lsa, siz himoyani uning oyog'i ostidan tortib olasiz va ikki yozuvchi holati yuzaga keladi. Shuning uchun avval `Who` va `Created` ni o'qing, o'sha odamdan (yoki o'zingizning ikkinchi mashinangizdan, CI'dagi job'lardan) so'rang, keyingina oching.

### Real ishda qachon kerak

- CI va odam bir vaqtda ishlaganda: lock ikkinchisini to'xtatadi.
- Uzilib qolgan `apply` dan keyin: stale lock'ni aniqlash va xavfsiz ochish.
- Meros loyihada `dynamodb_table` ni ko'rganda: bu lock jadvali ekanini bilish.

### Nima uchun shunday

Lock pessimistik: "avval band qil, keyin ishla". Muqobili optimistik bo'lardi (ishla, yozishda to'qnashuvni tekshir), lekin `apply` real resurs yaratadi va uni "qaytarib qo'yib" bo'lmaydi, shuning uchun to'qnashuvni oldindan to'sish to'g'ri. S3 uzoq vaqt shartli yozuvni bermagan, shu sababli lock uchun alohida servis (DynamoDB) kerak bo'lgan; S3 bu imkoniyatni qo'shgach lock fayli yetarli bo'ldi va bitta resurs kamaydi.

## 3. State bilan ishlash

### Ko'rish: `state list`, `state show`, `state pull`

State'ni qo'lda tahrirlamaysiz, u bilan `terraform state` buyruqlari orqali ishlaysiz. Misol sifatida `hashicorp/local` provider'i bilan ikki fayl yaratadigan kichik konfiguratsiyani olaylik (`local_file` resursi diskda fayl yaratadi, cloud kerak emas):

```
$ terraform state list
local_file.motd
local_file.readme
$ terraform state show local_file.motd
# local_file.motd:
resource "local_file" "motd" {
    content              = "welcome"
    directory_permission = "0777"
    file_permission      = "0644"
    filename             = "./out/motd.txt"
    id                   = "<sha1>"
    ...
}
```

`state list` har qatorda bitta **resurs manzilini** (resource address: `<tip>.<nom>`, modul ichida `module.<nom>.<tip>.<nom>`) beradi. `state show` bitta resursning state'dagi barcha atributlarini HCL'ga o'xshash ko'rinishda chiqaradi: `content`, `filename` siz yozganlar, `id` va ruxsatlar provider hisoblagan qiymatlar. `terraform state pull` butun state'ni JSON holida stdout'ga beradi (remote backend'da ham). JSON boshidagi ikki maydon muhim: `lineage` state yaratilganda bir marta beriladigan yagona ID, `serial` har yozuvda bittaga oshadigan hisoblagich. `terraform state push <file>` aksini qiladi va shu ikki maydonni tekshiradi: `lineage` boshqa yoki `serial` eskiroq bo'lsa rad etadi.

### Manzilni o'zgartirish: `moved` va `state mv`

Terraform resursni manzili bo'yicha taniydi. `local_file.motd` ni kodda `local_file.banner` deb qayta nomlasangiz, `plan` buni "motd kodda yo'q, demak o'chiriladi; banner state'da yo'q, demak yaratiladi" deb o'qiydi: `1 to add, 1 to destroy`. Fayl uchun bu arzimas, baza yoki server uchun bu ma'lumot yo'qolishi yoki downtime. **`moved` bloki** Terraform'ga "bu o'sha obyekt, faqat manzili o'zgardi" deydi:

```
moved {
  from = local_file.motd
  to   = local_file.banner
}
```

```
$ terraform plan
  # local_file.motd has moved to local_file.banner
    resource "local_file" "banner" {
        id       = "<sha1>"
        # (N unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

Birinchi qator ko'chish e'lon qilinganini, resurs bloki ichidagi `unchanged attributes` hech bir atribut o'zgarmasligini, oxirgi qator real dunyoda hech narsa bo'lmasligini aytadi. `apply` faqat state'dagi manzilni yangilaydi. Xuddi shu blok resursni modul ichiga ko'chirganda ham ishlaydi (`to = module.files.local_file.banner`). Refactoring mezoni: `plan` faqat `has moved to` qatorlarini va `0 to add, 0 to destroy` ni ko'rsatishi kerak.

Buyruq shakli: `terraform state mv local_file.motd local_file.banner`. U state'ni darhol o'zgartiradi (`Move "local_file.motd" to "local_file.banner"`, `Successfully moved 1 object(s).`), reja ham, review ham yo'q, va har muhit state'ida alohida bajarilishi kerak.

### Mavjud resursni boshqaruvga olish: `import`

Konsolda qo'lda yaratilgan resurs AWS'da bor, state'da yo'q. **Import** uni state'ga yozadi, ya'ni manzilni real ID'ga bog'laydi. Kodni import yozmaydi, uni siz yozasiz. Misol: qo'lda yaratilgan CloudWatch log group (loglar saqlanadigan nomlangan konteyner):

```
resource "aws_cloudwatch_log_group" "audit" {
  name = "/iac-lab/audit"
}

import {
  to = aws_cloudwatch_log_group.audit
  id = "/iac-lab/audit"
}
```

`id` ning formati har resurs tipida boshqa (nom, ID yoki ARN), u provider hujjatidagi resurs sahifasining "Import" bo'limida yozilgan. `plan` da resurs `will be imported` deb belgilanadi va xulosa `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.` bo'ladi. Agar kodingiz real resursdan farq qilsa (masalan real resursda retention sozlangan, kodda yo'q), o'sha `plan` importdan tashqari `1 to change` ham ko'rsatadi: kodni real holatga moslashtirmaguningizcha Terraform resursni kodga "tortadi". Boshlang'ich kodni Terraform'ning o'zi yozib berishi mumkin: `terraform plan -generate-config-out=generated.tf` (`resource` bloki hali yozilmagan bo'lsa). Natija xom, uni tozalash kerak. Eski buyruq shakli: `terraform import aws_cloudwatch_log_group.audit /iac-lab/audit`, u ham state'ni rejasiz darhol o'zgartiradi.

### Boshqaruvdan chiqarish: `removed` va `state rm`

Teskari amal: resurs AWS'da qolsin, lekin Terraform uni unutsin. Deklarativ shakli:

```
removed {
  from = aws_cloudwatch_log_group.audit
  lifecycle {
    destroy = false
  }
}
```

`resource` bloki o'chiriladi, o'rniga shu blok yoziladi; `plan` resurs endi boshqarilmasligini, lekin o'chirilmasligini aytadi. Buyruq shakli `terraform state rm <address>` (`Removed <address>`, `Successfully removed 1 resource instance(s).`). Ikkalasi ham `destroy` emas: resurs ishlashda va pul sarflashda davom etadi.

| Maqsad | Deklarativ (kodda, review qilinadi) | Buyruq (bir martalik) |
|--------|--------------------------------------|------------------------|
| Manzilni o'zgartirish | `moved` | `terraform state mv <from> <to>` |
| Boshqaruvga olish | `import` bloki | `terraform import <address> <id>` |
| O'chirmasdan boshqaruvdan chiqarish | `removed` + `destroy = false` | `terraform state rm <address>` |

Deklarativ bloklar afzal: ular PR'da ko'rinadi, `plan` da tekshiriladi va har muhitda (dev, stage) bir xil qo'llanadi.

### Majburan qayta yaratish: `-replace`

Ba'zan kod o'zgarmagan, lekin obyektning o'zi buzilgan (server ichi qo'lda chalkashtirilgan). `terraform apply -replace=local_file.banner` shu bitta resursni o'chirib qayta yaratishni rejaga qo'shadi: `plan` da `# local_file.banner will be replaced, as requested` va `-/+` belgisi chiqadi. Bu eski `terraform taint` buyrug'ining o'rnini bosgan: farqi shuki, `-replace` oddiy reja ichida ko'rinadi va tasdiq so'raydi.

### Drift'ni aniqlash

**Drift** (4-dars) bu real holat state'dan uzoqlashishi: kimdir konsolda o'zgartirgan.

- `terraform plan -refresh-only`: faqat state va real holat farqini ko'rsatadi, kodni hisobga olmaydi. `apply -refresh-only` state'ni real holatga tenglashtiradi, resursga tegmaydi.
- `terraform plan -detailed-exitcode`: exit code (linux 1-dars) `0` farq yo'q, `1` xato, `2` farq bor. Jadval bo'yicha ishlaydigan CI job'ida drift signali.

Terraform faqat o'zi boshqaradigan resurslarning o'zi kuzatadigan atributlarini ko'radi. Drift topilganda ikki yo'l bor: kod to'g'ri bo'lsa `apply` real holatni qaytaradi; real holat to'g'ri bo'lsa (incident paytidagi asosli o'zgarish) kod yangilanadi. "Shunday qolaversin" degan uchinchi yo'l yo'q.

### Real ishda qachon kerak

- Kod o'sib, resurslarni qayta nomlash yoki modulga ajratish kerak bo'lganda: `moved`.
- Kompaniya yillar davomida konsolda qurgan narsani kodga o'tkazishda: `import`.
- Resursni boshqa jamoa yoki boshqa konfiguratsiyaga topshirishda: bir joyda `removed`, ikkinchisida `import`.
- Buzilgan state'ni tiklashda: bucket versiyasi, `state pull`/`push`, `serial`.

### Nima uchun shunday

`moved`, `import` va `removed` bloklari keyinroq qo'shilgan; undan oldin faqat `state mv`, `import` va `state rm` buyruqlari bor edi. Buyruqlar kimningdir noutbukida, hech kimga ko'rinmasdan state'ni o'zgartirardi va har muhitda qo'lda takrorlanardi. Bloklar xuddi baza migration fayllari kabi: o'zgarish kodda yoziladi, review qilinadi, har muhitda bir xil tartibda qo'llanadi. Buyruqlar yo'qolmagan, ular bir martalik tuzatish va favqulodda holatlar uchun qolgan.

## 4. Muhitlar: workspace yoki papka

### Ikki yondashuv

**Muhit** (environment) bu bir xil infratuzilmaning mustaqil nusxasi: dev, stage, prod. Har birining state'i alohida bo'lishi shart, aks holda dev'dagi `destroy` prod'ni ham o'chiradi.

**Workspace**: bitta kod, bitta backend, bir nechta nomlangan state.

```
$ terraform workspace new stage
Created and switched to workspace "stage"!
$ terraform workspace list
  default
* stage
$ terraform workspace show
stage
```

`new` yangi bo'sh state yaratadi va unga o'tadi; `list` da yulduzcha joriy workspace'ni ko'rsatadi; `select <nom>` almashtiradi. Kodda joriy nom `terraform.workspace` ifodasi orqali olinadi (masalan nom prefiksi uchun). S3 backend'da `default` dan boshqa workspace state'lari `env:/<workspace>/<key>` yo'lida saqlanadi.

**Papka** (directory-per-environment): har muhit alohida root modul (5-bo'lim), o'z backend `key` i va o'z qiymatlari bilan; umumiy kod modullarda.

```
modules/
  network/      app_server/
envs/
  dev/    main.tf  backend.tf  terraform.tfvars
  stage/  main.tf  backend.tf  terraform.tfvars
```

### Halol solishtiruv

| | Workspace | Papka |
|---|-----------|-------|
| Qaysi muhitdaman | ko'rinmas holat (`workspace show`) | joriy papka, prompt'da ko'rinadi |
| Muhitlar farqi | `terraform.workspace` ga bog'liq shartlar | har muhitning o'z `main.tf` va qiymatlari |
| Akkaunt, backend, huquqlarni ajratish | qiyin, backend bitta | tabiiy |
| Modul versiyasini bosqichma-bosqich ko'tarish | yo'q, kod bitta | bor: avval dev, keyin stage |
| Takror kod | yo'q | bir oz (modul chaqiruvlari) |

Workspace'ning asosiy xavfi shuki, joriy muhit `git branch` kabi yashirin holat: `stage` deb o'ylab `default` da `apply` qilish oson. Papkaning narxi takror: har muhitda modul chaqiruvlari qayta yoziladi. Uzoq yashaydigan muhitlar (dev, stage, prod) uchun papka afzal; workspace qisqa umrli nusxalar uchun qulay (PR uchun vaqtinchalik muhit).

### Real ishda qachon kerak

- Prod alohida AWS akkauntda bo'lsa: faqat papka modeli (har papkaning o'z backend va provider sozlamasi).
- "Shu branch uchun vaqtinchalik muhit ko'tarib, tekshirib, o'chiramiz": workspace.

### Nima uchun shunday

Workspace dastlab aynan vaqtinchalik parallel nusxalar uchun yaratilgan; Terraform hujjatining o'zi uni kuchli ajratish talab qiladigan muhitlar uchun tavsiya qilmaydi (Manbalar). Papka modelining takrorini kamaytirish uchun Terragrunt kabi ustqurmalar bor, ular bu kursga kirmaydi.

## 5. Modullar

### Modul nima

**Modul** bu bitta papkadagi `.tf` fayllar to'plami. Siz `terraform apply` ni ishga tushiradigan papka **root modul**, u `module` bloki bilan chaqirgan papkalar **child modul**. Demak 4-darsdan beri modul yozgansiz, faqat bitta. Child modul React komponentiga o'xshaydi va bu o'xshatish aniq: `variable` lar props (kirish), `output` lar qaytariladigan qiymat, ichidagi resurslar tashqaridan ko'rinmaydigan ichki tafsilot, va bitta modulni turli qiymatlar bilan bir necha marta chaqirish mumkin.

Misol: 3-bo'limdagi log group'ni qayta ishlatiladigan modulga aylantiramiz.

```
# modules/log_group/variables.tf
variable "name" {
  description = "Log group name, must start with a slash"
  type        = string
}

variable "retention_in_days" {
  description = "How long log events are kept"
  type        = number
  default     = 7
}

# modules/log_group/main.tf
resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
}

# modules/log_group/outputs.tf
output "arn" {
  description = "ARN of the log group"
  value       = aws_cloudwatch_log_group.this.arn
}
```

Chaqiruv (root modulda):

```
module "audit_logs" {
  source = "../../modules/log_group"
  name   = "/iac-lab/audit"
}

output "audit_log_arn" {
  value = module.audit_logs.arn
}
```

Mexanizm: `module` blokidagi `source` kod qayerdan olinishini aytadi, qolgan argumentlar child modulning `variable` lariga beriladi (`retention_in_days` berilmagan, default ishlaydi). Root modul child'ning faqat output'larini ko'radi: `module.audit_logs.arn`. Modul ichidagi resursning to'liq manzili `module.audit_logs.aws_cloudwatch_log_group.this`, `state list` shuni ko'rsatadi. Yangi modul qo'shilgach yoki `source` o'zgargach `terraform init` kerak, u modullarni `.terraform/modules/` ga joylaydi:

```
$ terraform init
Initializing the backend...
Initializing modules...
- audit_logs in ../../modules/log_group
...
```

`- audit_logs in ...` qatori: chaqiruv nomi va kod olingan joy. Lokal yo'l uchun fayllar ko'chirilmaydi, to'g'ridan-to'g'ri o'qiladi.

Tuzilish odati: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (`required_providers`, 4-dars), `README.md`. `provider` bloklari (region, profil, `default_tags`) faqat root modulda yoziladi; child modul `required_providers` da faqat talabini e'lon qiladi va provider sozlamasini chaqiruvchidan meros oladi. Backend ham faqat root modulda.

### `source` shakllari va versiyalash

| Manba | Misol | Versiya qanday belgilanadi |
|-------|-------|----------------------------|
| Lokal yo'l | `../../modules/log_group` | repo bilan birga yuradi, alohida versiya yo'q |
| Registry | `terraform-aws-modules/vpc/aws` | `version = "~> N.0"` argumenti |
| Git | `git::https://github.com/<org>/<repo>.git//log_group?ref=v1.2.0` | `ref` (tag yoki commit); `//` dan keyin repo ichidagi papka |

**Terraform Registry** (registry.terraform.io) bu provider va tayyor modullarning ochiq katalogi, npm registry'ning o'xshashi. Registry modullari semver bilan chiqadi va `version` cheklovi `package.json` dagi kabi ishlaydi (`~> 5.1` degani `5.x`, lekin `6.0` emas). Muhim farq: `.terraform.lock.hcl` faqat **provider** versiyalari va hash'larini qulflaydi, modul versiyalarini emas. `package-lock.json` ga o'xshash narsa modullar uchun yo'q, shuning uchun aniq `version` yoki `ref` yozish sizning yagona qulfingiz. Versiyasiz manba har `init` da boshqa kod tortishi mumkin.

Registry moduli begona kod: bitta chaqiruv o'nlab resurs yaratishi mumkin (VPC moduli sozlamaga qarab pullik NAT gateway yaratadi). `plan` ni o'qimasdan `apply` qilinmaydi.

### Qachon modul yozmaslik kerak

Yaxshi modul belgilari: bitta mas'uliyat, kam va tushunarli kirishlar (`description`, `type`, kerak bo'lsa `validation`), boshqalarga kerak bo'ladigan output'lar. Yomon belgi: bitta resursni o'ragan va uning har argumentini variable qilib tashqariga chiqargan "wrapper", u hech narsani soddalashtirmaydi, faqat bir qatlam qo'shadi. Yuqoridagi `log_group` misoli ham sintaksisni ko'rsatish uchun, real loyihada bunday modul ortiqcha. Qoida: kod ikkinchi marta kerak bo'lganda yoki bir nechta resurs birga "bitta narsa" ni tashkil qilganda (tarmoq, app server) modulga ajrating, undan oldin emas.

### Real ishda qachon kerak

- Bir xil tarmoq yoki server to'plami dev va stage'da kerak bo'lganda.
- Platforma jamoasi boshqa jamoalarga "to'g'ri sozlangan bucket" ni tayyor holda berganda.
- Modulda breaking change chiqqanda: papka modelida avval dev yangi versiyaga o'tadi, keyin stage.

### Nima uchun shunday

Modul tizimi ataylab sodda: sinf ham, meros ham yo'q, faqat "kirish, resurslar, chiqish". Sababi `plan` o'qilishi kerak: har resursning manzili chaqiruv zanjirini to'liq ko'rsatadi (`module.a.module.b.aws_x.y`). Provider'ning root'da turishi bitta modulni turli region va akkauntlarga qayta ishlatish imkonini beradi. Muqobili: Pulumi yoki AWS CDK'da abstraksiya oddiy dasturlash tilidagi funksiya va sinflar bilan quriladi, kuchliroq, lekin natijani oldindan o'qish qiyinroq.

## 6. State va secret'lar

### `sensitive` nimani qiladi

`sensitive = true` (variable'da, output'da yoki provider belgilagan atributda) qiymatni Terraform'ning ekrandagi chiqishida yashiradi:

```
variable "api_token" {
  type      = string
  sensitive = true
}
```

```
  + content = (sensitive value)
```

`plan` qiymat o'rniga `(sensitive value)` yozadi, u bog'langan boshqa ifodalar ham yashiriladi. Lekin bu faqat ko'rsatishga oid belgi, shifrlash emas: provider resursni yaratish uchun haqiqiy qiymatni biladi va uni state'ga yozadi. State'da va `plan -out` faylida qiymat **ochiq matn**. Demak state'ni o'qiy oladigan har kim (bucket'ga `s3:GetObject` huquqi bor har kim) barcha secret'larni o'qiydi.

### Himoya qatlamlari

- State bucket: tor huquq, shifrlash, public access bloklangan (1-bo'lim); state va plan fayllari hech qachon repoda va ochiq CI artifact'ida emas.
- Secret'ni Terraform orqali o'tkazmaslik: uni secret manager'da (AWS Secrets Manager yoki SSM Parameter Store, secret'larni saqlaydigan AWS servislari) alohida yaratish, Terraform'da faqat nomi yoki ARN'iga havola qilish, ilova qiymatni ishga tushganda o'zi o'qiydi.
- Yangi Terraform versiyalarida state'ga yozilmaydigan ephemeral resurslar va write-only argumentlar bor; qaysi versiyada va qaysi resurslarda mavjudligini hujjatdan tekshiring (Manbalar).
- OpenTofu'da state'ni client tomonida shifrlash imkoniyati bor.

### Real ishda qachon kerak

- Baza paroli, API token yoki private key Terraform orqali o'tadigan har joyda.
- "State bucket'ga kimning huquqi bor" degan audit savoli aslida "barcha secret'larni kim o'qiy oladi" degan savol.

### Nima uchun shunday

State real holatning to'liq nusxasi bo'lishi kerak, aks holda Terraform parol o'zgarganini (drift) aniqlay olmaydi. Parol resursning atributi bo'lsa, u ham state'da turadi. 3-darsdagi Ansible Vault boshqa model: u yerda secret manbada shifrlangan va faqat ishga tushirish paytida ochiladi; Terraform'da esa natija (state) himoya qilinadi.

## 7. Statik tekshiruv va CI

### Asboblar

**Statik tekshiruv** kodni ishga tushirmasdan, AWS'ga murojaat qilmasdan o'qib xato qidiradi (frontend'dagi ESLint va `tsc` kabi).

| Asbob | Nimani topadi |
|-------|---------------|
| `terraform fmt -check -recursive` | format. `make check` aynan shuni ishlatadi |
| `terraform validate` | sintaksis, tiplar, mavjud bo'lmagan argument va havolalar |
| tflint | provider'ga xos xatolar (mavjud bo'lmagan instans tipi), ishlatilmagan o'zgaruvchi, eskirgan sintaksis. Sozlama `.tflint.hcl`, plugin'lar `tflint --init` bilan |
| trivy (`trivy config <dir>`) yoki checkov (`checkov -d <dir>`) | xavfsizlik xatolari: hammaga ochiq security group, shifrlanmagan yoki ochiq bucket |

Skaner topilmasi har doim ham xato emas (laboratoriyada HTTP porti `0.0.0.0/0` ga ochiq bo'lishi maqsadli). Istisno global o'chirish bilan emas, kodning o'sha joyida, sababi yozilgan izoh bilan, asbobning ignore sintaksisi orqali belgilanadi.

### PR'dagi pipeline nima qiladi

Standart oqim (GitHub Actions: cicd 2): **PR'da `plan`, `main` ga merge'da `apply`**.

1. PR ochildi: `fmt -check`, `validate`, lint, xavfsizlik skaneri. Bular arzon va AWS'siz.
2. `terraform init` va `terraform plan`, natija PR'da ko'rinadi (job summary yoki komment). Reviewer kodni emas, kod **nima qilishini** ko'radi: `2 to add, 1 to destroy`.
3. Merge'dan keyin `main` da: `plan -out=tfplan`, qo'lda tasdiq, so'ng aynan o'sha faylni `apply tfplan`.

Bu darsning vazifalarida yo'q, lekin shu g'oyalarni ko'rsatadigan boshqa job: jadval bo'yicha drift tekshiruvi.

```
on:
  schedule:
    - cron: "0 6 * * 1-5"
permissions:
  id-token: write
  contents: read
jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      # checkout, AWS credentials via OIDC, setup-terraform: see cicd 5
      - run: terraform init -input=false
      - run: terraform plan -input=false -lock-timeout=5m -detailed-exitcode
```

`schedule` job'ni ish kunlari ertalab ishga tushiradi; `id-token: write` OIDC token olishga ruxsat (cicd 5); `-input=false` savol kutib osilib qolmaslik uchun; `-detailed-exitcode` farq bo'lsa `2` qaytaradi va job qizaradi. Action'larning joriy major versiyasini ularning sahifasidan oling.

Muhim qoidalar:

- **Credential**: uzoq muddatli AWS kalitlari emas, OIDC orqali vaqtinchalik role (cicd 5). `plan` uchun faqat o'qish huquqli role, `apply` uchun alohida, faqat `main` branch'dan olinadigan role. Aks holda istalgan PR `apply` huquqini oladi.
- **Ko'rilgan reja qo'llanadi**: `plan -out` fayli va `apply <fayl>` orasida hech narsa qayta hisoblanmaydi. `apply -auto-approve` esa yangi reja tuzadi va uni hech kim ko'rmagan.
- **Ketma-ketlik**: bir state uchun bir vaqtda bitta job (`concurrency` guruhi). State lock ikkinchi himoya, birinchi emas.
- Plan chiqishida secret bo'lishi mumkin; plan fayli esa secret'larni ochiq saqlaydi (6-bo'lim), uni ochiq artifact qilmang.

### Real ishda qachon kerak

- Jamoada hech kim noutbukdan prod'ga `apply` qilmasligi kerak bo'lganda: yagona yo'l pipeline.
- Audit: har infratuzilma o'zgarishi PR, review va job log'iga ega.

### Nima uchun shunday

`plan` va `apply` ning ajratilishi Terraform'ning asosiy g'oyasi (4-dars), pipeline uni jamoa jarayoniga aylantiradi: reja review obyekti. Arzon tekshiruvlar oldin turadi, chunki format xatosi uchun AWS'ga borish shart emas. Bu oqimni tayyor holda beradigan asboblar bor (Atlantis, HCP Terraform), ular rejada "ataylab kiritilmagan" ro'yxatida; mexanizmni qo'lda qurgach ularni o'rganish oson.

## 8. Terraform + Ansible

### Mehnat taqsimoti

1-darsdagi ajratish: **provisioning** (server va tarmoqni yaratish) Terraform'ning ishi, **configuration management** (server ichini sozlash: paketlar, userlar, servislar) Ansible'ning ishi. Terraform server tashqarisini API orqali boshqaradi va state'ga tayanadi; Ansible server ichiga SSH orqali kiradi va har safar haqiqiy holatni tekshiradi. Orada uzatiladigan ma'lumot oz: host manzili va roli.

| Usul | Qanday | Qachon |
|------|--------|--------|
| Teg + dynamic inventory | Terraform `Role`, `Project` teglarini qo'yadi, `aws_ec2` plugin (3-dars) serverlarni AWS'dan o'zi topadi | serverlar soni o'zgaruvchan; ikki asbob bir-biridan mustaqil |
| Output'dan inventory | `terraform output` qiymatlaridan skript inventory hosil qiladi | kichik, statik muhit |
| `user_data` (cloud-init, 1-dars) | server birinchi yuklanishda o'zini sozlaydi | oddiy bootstrap, immutable model |

Output'ni mashina o'qiydigan shaklda olish:

```
$ terraform -chdir=envs/dev output -raw audit_log_arn
arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/iac-lab/audit
$ terraform -chdir=envs/dev output -json
{
  "audit_log_arn": {
    "sensitive": false,
    "type": "string",
    "value": "arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/iac-lab/audit"
  }
}
```

`-chdir=<dir>` buyruqni boshqa papkada bajaradi (`Makefile` dan qulay). `-raw` bitta string output'ni qo'shtirnoqsiz, skriptda ishlatishga tayyor beradi. `-json` barcha output'larni beradi: kalit output nomi, ichida `sensitive` belgisi, `type` va `value`. Hosil qilingan inventory'da IP bor, u har `apply` da va har mashinada boshqa, shuning uchun commit qilinmaydi va qo'lda tahrirlanmaydi (3-dars qoidasi).

Arxitektura ataylab tanlanadi: instans tipi `x86_64` yoki Graviton (`arm64`) bo'lishini Terraform'dagi tip va AMI belgilaydi, ular bir-biriga mos bo'lishi shart. Ansible tomonda arxitektura qattiq yozilmaydi, fact'dan olinadi (`ansible_architecture`, 2-dars), shunda role ikkala holatda ham, Multipass VM'da ham ishlaydi.

### Provisioner'lar va "server hali tayyor emas"

Terraform'da resurs ichidan buyruq chaqiradigan provisioner'lar bor (`local-exec`, `remote-exec`), ular bilan Ansible'ni ham chaqirish mumkin. Hujjatning o'zi ularni oxirgi chora deb ataydi: buyruq nima qilgani state'da aks etmaydi, `plan` uni ko'rsata olmaydi, xato bo'lsa resurs "tainted" (keyingi `apply` da qayta yaratiladigan) bo'lib qoladi. Ikki asbobni tashqi orkestrator (`Makefile`, pipeline) ketma-ket chaqirgani toza.

**Tuzoq: `apply` tugadi, server hali tayyor emas.** EC2 `running` holatiga o'tishi SSH ochilgan va cloud-init tugagan degani emas. Ansible'dan oldin kutish kerak: `ansible.builtin.wait_for_connection` moduli SSH ishlaguncha kutadi, serverda `cloud-init status --wait` esa cloud-init tugaguncha qaytmaydi.

### Real ishda qachon kerak

- Serverlar uzoq yashaydigan va ichida ko'p sozlama bo'lgan muhit: Terraform + Ansible.
- Serverlar qisqa umrli va image'dan ko'tariladigan muhit: Terraform + tayyor image (Packer) + ozgina `user_data`, Ansible deyarli kerak bo'lmaydi.

### Nima uchun shunday

Har asbob o'z modeliga mos ishda kuchli: Terraform'ning state va graph'i "mavjud yoki yo'q" turidagi API obyektlariga mos, Ansible'ning task ketma-ketligi "fayl ichidagi qator, servis holati" turidagi ishlarga. Ansible'da ham cloud modullari, Terraform'da ham provisioner bor, lekin birini ikkinchisining ishiga majburlasangiz o'sha asbobning asosiy kafolati (`plan`, idempotency) yo'qoladi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| State | Terraform'ning resurs manzillarini real obyekt ID'lariga bog'laydigan yozuvi (JSON) |
| Backend | state qayerda saqlanishi va qanday qulflanishini belgilaydigan sozlama (`local`, `s3`) |
| Remote state | ish papkasida emas, umumiy joyda (masalan S3 bucket'da) turadigan state |
| Partial configuration | backend argumentlarining bir qismini `init -backend-config=...` orqali berish |
| Bootstrap | state bucket'ning o'zini yaratadigan alohida kichik konfiguratsiya |
| Versioning (S3) | obyektning har yozuvi alohida versiya bo'lib saqlanishi, eski state'ni tiklash imkoni |
| Lock | bir vaqtda faqat bitta jarayon state bilan ishlashini ta'minlaydigan belgi |
| Stale lock | egasi o'lgan, lekin bo'shatilmay qolgan lock |
| `force-unlock` | lock'ni ID bo'yicha majburan olib tashlaydigan buyruq |
| `serial` / `lineage` | state'ning har yozuvda oshadigan hisoblagichi va uning yagona kelib chiqish ID'si |
| Resurs manzili | resursning Terraform'dagi nomi: `<tip>.<nom>` yoki `module.<nom>.<tip>.<nom>` |
| `moved` bloki | resurs manzili o'zgarganini e'lon qiladi, obyekt qayta yaratilmaydi |
| Import | mavjud real resursni state'ga yozish (kodni siz yozasiz) |
| `removed` bloki | resursni o'chirmasdan (`destroy = false`) boshqaruvdan chiqarish |
| `-replace` | bitta resursni kod o'zgarmasa ham qayta yaratishni rejaga qo'shadigan flag |
| Drift | real holatning state va koddan uzoqlashishi |
| Refresh-only | faqat state'ni real holat bilan solishtiradigan `plan`/`apply` rejimi |
| Muhit (environment) | bir xil infratuzilmaning mustaqil nusxasi: dev, stage, prod |
| Workspace | bitta kod va backend ichidagi nomlangan alohida state |
| Root modul | `terraform` buyruqlari ishga tushiriladigan papka |
| Child modul | boshqa modul `module` bloki bilan chaqiradigan papka |
| `source` | modul kodi olinadigan joy: lokal yo'l, registry yoki git |
| Terraform Registry | provider va tayyor modullarning ochiq katalogi |
| `sensitive` | qiymatni CLI chiqishida yashiradigan belgi, shifrlash emas |
| Statik tekshiruv | kodni ishga tushirmasdan o'qib xato qidirish (`validate`, tflint, trivy) |
| OIDC role | pipeline uzoq muddatli kalitsiz, qisqa umrli token bilan oladigan AWS role |
| Provisioning / configuration | serverni yaratish (Terraform) va uning ichini sozlash (Ansible) |
| Provisioner | Terraform resursi ichidan buyruq chaqirish mexanizmi, oxirgi chora |

## Tuzoqlar

- Lock'siz remote state. S3 backend'da lock standart holatda o'chiq; ikki `apply` bir vaqtda ishlasa state buziladi.
- `force-unlock` ni xato matnidagi `Who` va `Created` ni o'qimasdan ishlatish: boshqa mashinada ishlab turgan `apply` ostidan himoyani olib tashlaysiz.
- Ikkinchi mashinada `init` qilmasdan yoki `git pull` siz ishlash: kod eski, state yangi, `plan` kutilmagan `destroy` ko'rsatadi. `plan` ni har doim o'qing.
- Mashinaga bog'liq qiymat (tashqi IP) endi umumiy state'da: uyda `apply` qilingach ofisdan SSH yopiladi. Bu xato emas, o'zgaruvchini yangilab `apply` qilasiz.
- `.terraform.lock.hcl` da faqat bitta platforma hash'i: ikkinchi mashinada `init` checksum xatosi beradi.
- Resursni `moved` siz qayta nomlash yoki modulga ko'chirish: `plan` da destroy + create, production'da downtime yoki ma'lumot yo'qolishi.
- `terraform state rm` ni "o'chirish" deb o'ylash. Resurs AWS'da qoladi, pul sarflaydi va uni endi hech kim boshqarmaydi.
- `sensitive = true` ga ishonib state'ni keng ochiq qoldirish yoki plan faylini ochiq artifact qilish.
- Workspace'ni tekshirmasdan `apply`: `stage` deb o'ylab `default` da ishlash.
- Modul versiyasini belgilamaslik (`ref` siz git manbasi, `version` siz registry moduli): lock fayli modullarni qulflamaydi, bugungi `init` kechagidan boshqa kod tortadi.
- CI'da `apply` uchun admin huquqli uzoq muddatli kalit va himoyalanmagan branch.
- State bucket'ni muhit bilan bitta konfiguratsiyaga qo'yish: `destroy` state'ning o'zi turgan joyni o'chirishga urinadi.
- `make down` dan keyin tekshirmaslik: Terraform'dan tashqarida qo'lda yaratilgan resurs (import tajribasi) `destroy` bilan o'chmaydi.

## Manbalar

- https://developer.hashicorp.com/terraform/language/backend/s3 – S3 backend: `use_lockfile`, DynamoDB lock, IAM ruxsatlar
- https://opentofu.org/docs/language/settings/backends/s3/ – OpenTofu S3 backend
- https://developer.hashicorp.com/terraform/language/state/locking – state locking
- https://developer.hashicorp.com/terraform/cli/commands/force-unlock – `force-unlock`
- https://developer.hashicorp.com/terraform/cli/state – state buyruqlari
- https://developer.hashicorp.com/terraform/language/modules/develop/refactoring – `moved` bloki, refactoring
- https://developer.hashicorp.com/terraform/language/import – `import` bloki va config generatsiyasi
- https://developer.hashicorp.com/terraform/language/state/workspaces – workspace'lar va ularning cheklovlari
- https://developer.hashicorp.com/terraform/language/modules/develop – modul yozish
- https://developer.hashicorp.com/terraform/language/modules/sources – modul manbalari
- https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest – registry'dagi VPC moduli (13-vazifa)
- https://developer.hashicorp.com/terraform/language/state/sensitive-data – state'dagi secret'lar
- https://developer.hashicorp.com/terraform/language/resources/ephemeral – ephemeral resurslar
- https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax – provisioner'lar nima uchun oxirgi chora
- https://developer.hashicorp.com/terraform/tutorials/automation/github-actions – GitHub Actions bilan Terraform
- https://github.com/terraform-linters/tflint – tflint (o'rnatish, qoidalar, ignore sintaksisi)
- https://trivy.dev/latest/docs/scanner/misconfiguration/ – trivy config skaneri; https://github.com/aquasecurity/trivy
- https://www.checkov.io/ – checkov
- Yevgeniy Brikman, "Terraform: Up & Running" (3-nashr), 3, 4, 6 va 9 boblar

---

## Birga bajaramiz

Bitta yaxlit misol: cloud'siz, `hashicorp/random` va `hashicorp/local` provider'lari bilan kichik konfiguratsiyani yaratamiz, resursni qayta nomlaymiz, modulga ajratamiz, state'ni boshqa joyga ko'chiramiz va oxirida `state rm` nima qilishini ko'ramiz. Hech narsa pul sarflamaydi, ikkala mashinada bir xil ishlaydi. Repodan tashqarida ishlang:

1. Papka va boshlang'ich kod. `random_pet` tasodifiy nom hosil qiladi (masalan `calm-otter`), `local_file` uni faylga yozadi:

```
$ mkdir -p ~/tf-refactor-demo && cd ~/tf-refactor-demo
```

```
# main.tf
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}

resource "random_pet" "name" {}

resource "local_file" "greeting" {
  filename = "${path.module}/out/card.txt"
  content  = "Hello, ${random_pet.name.id}"
}
```

```
$ terraform init
$ terraform apply
...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
$ cat out/card.txt
Hello, <adjective>-<animal>
$ terraform state list
local_file.greeting
random_pet.name
```

Ikki resurs yaratildi, `state list` ularning manzillarini ko'rsatdi. Fayldagi nomni eslab qoling: u butun yurish davomida o'zgarmasligi kerak, chunki `random_pet` qayta yaratilsa nom ham o'zgaradi. Bu bizning "server qayta yaratilmadi" degan isbotimiz.

2. Qayta nomlash, `moved` siz. `main.tf` da `"greeting"` ni `"card"` ga o'zgartiring:

```
$ terraform plan
...
Plan: 1 to add, 0 to change, 1 to destroy.
```

Terraform buni ikki xil resurs deb o'qidi: `local_file.greeting` o'chiriladi, `local_file.card` yaratiladi. `apply` qilmang.

3. Endi `moved` blokini qo'shing:

```
moved {
  from = local_file.greeting
  to   = local_file.card
}
```

```
$ terraform plan
  # local_file.greeting has moved to local_file.card
    resource "local_file" "card" {
        id       = "<sha1>"
        # (N unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
$ terraform apply
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Faqat manzil o'zgardi. `terraform state list` endi `local_file.card` ni ko'rsatadi, fayl mazmuni o'sha.

4. Modulga ajratish. Ikkala resursni `modules/card/main.tf` ga ko'chiring va ichki nomlarini `this` qiling; fayl papkasi kirish o'zgaruvchisi bo'lsin:

```
# modules/card/main.tf
variable "dir" {
  description = "Directory where the card file is written"
  type        = string
}

resource "random_pet" "this" {}

resource "local_file" "this" {
  filename = "${var.dir}/card.txt"
  content  = "Hello, ${random_pet.this.id}"
}

output "filename" {
  value = local_file.this.filename
}
```

Root `main.tf` da resurslar o'rniga chaqiruv va ikkita `moved` qoladi (`required_providers` bloki joyida, 3-qadamdagi eski `moved` ham tursin):

```
module "card" {
  source = "./modules/card"
  dir    = "${path.root}/out"
}

moved {
  from = random_pet.name
  to   = module.card.random_pet.this
}

moved {
  from = local_file.card
  to   = module.card.local_file.this
}
```

```
$ terraform init
Initializing modules...
- card in modules/card
...
$ terraform plan
  # local_file.card has moved to module.card.local_file.this
  ...
  # random_pet.name has moved to module.card.random_pet.this
  ...
Plan: 0 to add, 0 to change, 0 to destroy.
$ terraform apply
$ terraform state list
module.card.local_file.this
module.card.random_pet.this
$ cat out/card.txt
Hello, <adjective>-<animal>
```

`init` yangi modulni ro'yxatga oldi; `plan` ikkita ko'chishni ko'rsatdi, yaratish va o'chirish yo'q; fayldagi nom 1-qadamdagi bilan bir xil. E'tibor bering: `dir` ga `path.root` berildi. Modul ichida `path.module` yozilganda u modul papkasini ko'rsatardi, `filename` o'zgarardi va `plan` ko'chishdan tashqari faylni almashtirishni ham taklif qilardi. Refactoring'da "faqat `has moved to`" mezoni aynan shunday xatolarni ushlaydi.

5. State'ni boshqa joyga ko'chirish. S3 o'rniga `local` backend'ning boshqa yo'lini ishlatamiz, mexanizm bir xil. `terraform` blokiga qo'shing:

```
  backend "local" {
    path = "state/demo.tfstate"
  }
```

```
$ terraform plan
(Backend initialization required xatosi)
$ terraform init -migrate-state
$ ls state/
demo.tfstate
$ terraform plan
...
No changes. Your infrastructure matches the configuration.
```

`init -migrate-state` 1-bo'limdagi savolni beradi (bu safar eski va yangi backend ikkalasi ham `local`), `yes` dan keyin state yangi yo'lda. `plan` toza: resurslar o'sha, faqat yozuv turadigan joy o'zgardi.

6. Majburan qayta yaratish:

```
$ terraform apply -replace='module.card.local_file.this'
  # module.card.local_file.this will be replaced, as requested
...
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

Kod o'zgarmagan, lekin fayl o'chirilib qayta yozildi. `random_pet` ga tegilmadi, nom o'sha.

7. `state rm` o'chirish emas:

```
$ terraform state rm 'module.card.local_file.this'
Removed module.card.local_file.this
Successfully removed 1 resource instance(s).
$ cat out/card.txt
Hello, <adjective>-<animal>
$ terraform plan
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

Fayl diskda turibdi, lekin Terraform uni unutdi va endi "yo'q, yarataman" deb hisoblaydi.

8. Tozalash:

```
$ terraform destroy
$ cd ~ && rm -rf ~/tf-refactor-demo
```

`destroy` faqat state'da qolgan `random_pet` ni o'chiradi; `card.txt` boshqaruvdan chiqarilgani uchun qo'lda (`rm -rf`) o'chiriladi. AWS'da bu qo'lda o'chirilmagan resurs pul sarflashda davom etgan bo'lardi.

Qaysi qadam qaysi bo'limni ko'rsatdi: 1 va 7-qadamlar `state list` va `state rm` (3-bo'lim), 2–3-qadamlar `moved` (3-bo'lim), 4-qadam modul anatomiyasi va modulga ko'chirish (5-bo'lim), 5-qadam backend va `init -migrate-state` (1-bo'lim), 6-qadam `-replace` (3-bo'lim). Vazifalarda xuddi shu amallarni AWS resurslarida, S3 backend bilan bajarasiz.

---

## Vazifalar

Ish papkasi: `iac/05-terraform-state-modules/` (`make new m=iac n=05 name=terraform-state-modules`), ichida `bootstrap/`, `modules/`, `envs/dev/`, `envs/stage/`, `ansible/` (3-darsdagi role'lar nusxasi yoki ularga havola) va `Makefile`. Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, `plan` chiqishining muhim qismi, o'z so'zingiz bilan izoh va qaysi mashinada bajarilgani. Boshlang'ich kod: 4-darsdagi `aws/` papkasi nusxasi. State, plan fayllari, kalitlar, secret'li `*.tfvars`, generatsiya qilingan inventory va vault paroli commit qilinmaydi. AWS vazifalari har ikkala mashinada bir xil bajariladi; har mashg'ulot "Laboratoriya" dagi AWS tartibi bilan boshlanadi va `destroy` hamda teg bo'yicha tekshiruv bilan tugaydi.

### A. Remote state

1. **Bootstrap state bucket.** `bootstrap/` da state uchun S3 bucket yarating: versioning, shifrlash, public access bloklangan, `prevent_destroy`. Bu konfiguratsiyaning o'z state'i qayerda turadi va bu nima uchun maqbul (yoki maqbul emas), ayniqsa ikkinchi mashinangiz nuqtai nazaridan? Tovuq va tuxum muammosini o'z so'zingiz bilan yozing. Yo'nalish: 1-bo'lim, "State bucket talablari va tovuq-tuxum muammosi".

2. **Migrate state.** 4-darsdagi AWS kodini `apply` qiling (lokal state), keyin `backend "s3"` blokini `use_lockfile = true` bilan qo'shib `terraform init -migrate-state` qiling. Bucket'da state obyektini AWS CLI bilan ko'rsating. Lokal `terraform.tfstate` da nima qoldi? `plan` toza ekanini tasdiqlang. Mashinani birinchi marta almashtirgan kuningiz ikkinchi mashinada `git pull`, `terraform init` va `plan` qiling: nima ko'rindi va nima uchun? Yo'nalish: 1-bo'lim, "Backend o'zgarganda: `init -migrate-state`"; "Laboratoriya" dagi ikkinchi mashina ro'yxati.

3. **Lock contention.** Bir terminalda `terraform apply` ni tasdiq so'rovida to'xtatib turing, ikkinchisida `plan` qiling. Xato matnidan lock ID, kim va qachon olganini yozing. Shu paytda bucket'da `.tflock` obyektini toping va mazmunini o'qing. `-lock-timeout=30s` nima qiladi? `force-unlock` qachon to'g'ri, qachon xavfli? Yo'nalish: 2-bo'lim, "Lock band bo'lganda" va "Stale lock va `force-unlock`".

4. **State version recovery.** Bir nechta `apply` dan keyin `aws s3api list-object-versions` bilan state versiyalarini ko'ring. Oldingi versiyani yuklab olib, `serial` qiymatlarini solishtiring. Buzilgan state'ni tiklash rejasini qadamma-qadam yozing (bajarmasdan), `terraform state push` nima uchun ehtiyotkorlik talab qilishini ayting. Yo'nalish: 3-bo'lim, "Ko'rish: `state list`, `state show`, `state pull`".

5. **Secrets in state.** `hashicorp/random` provider'ining `random_password` resursini qo'shing va `sensitive` output qiling. `apply` chiqishi, `terraform output`, `terraform output -raw` va `terraform state pull` ning har biri qiymatni ko'rsatadimi? Xulosa yozing: `sensitive` nimani himoya qiladi, state'ni nima himoya qiladi. Yo'nalish: 6-bo'lim, "`sensitive` nimani qiladi".

### B. State amallari

6. **Rename with moved.** `aws_instance` ning Terraform nomini o'zgartiring va `plan` ni o'qing (apply qilmang): nima taklif qilinyapti? `moved` bloki qo'shing: endi-chi? `apply` qiling va instans ID'si o'zgarmaganini ko'rsating. Xuddi shu ishni `terraform state mv` bilan qilish nimasi bilan farq qiladi? Yo'nalish: 3-bo'lim, "Manzilni o'zgartirish: `moved` va `state mv`".

7. **Import.** AWS CLI bilan qo'lda security group yoki S3 bucket yarating (teg bilan). Unga mos `resource` va `import` blokini yozing. Birinchi `plan` da qanday farqlar chiqdi? Kodni real holatga moslab, `plan` faqat import ko'rsatadigan holatga keltiring, `apply` qiling. `-generate-config-out` ni ham sinab, hosil bo'lgan kod sifatini baholang. Yo'nalish: 3-bo'lim, "Mavjud resursni boshqaruvga olish: `import`".

8. **Remove from state.** 7-vazifadagi resursni o'chirmasdan boshqaruvdan chiqaring (`removed` bloki, `destroy = false`). `state list` da yo'qligini, AWS'da borligini ko'rsating. Keyin uni AWS CLI bilan qo'lda o'chiring. Bu amal production'da qachon kerak bo'ladi? Yo'nalish: 3-bo'lim, "Boshqaruvdan chiqarish: `removed` va `state rm`".

9. **Drift detection.** Konsol yoki CLI orqali Terraform boshqaradigan security group'ga yangi ingress qoidasi qo'shing va instans tegini o'zgartiring. `plan -refresh-only`, oddiy `plan` va `plan -detailed-exitcode` (`echo $?`) natijalarini yozing. Qaysi drift ko'rindi, qaysi biri ko'rinmadi va nima uchun? Bittasini kod foydasiga, ikkinchisini real holat foydasiga hal qiling. Yo'nalish: 3-bo'lim, "Drift'ni aniqlash".

### C. Modullar va muhitlar

10. **Network module.** VPC, subnet, internet gateway va route resurslarini `modules/network` ga ko'chiring: tipli va tavsifli kirish o'zgaruvchilari, kerakli output'lar. `envs/dev` dan chaqiring. Resurslar qayta yaratilmasligi uchun `moved` bloklarini yozing: `plan` da `0 to add, 0 to destroy`. `state list` dagi yangi manzillarni ko'rsating. Yo'nalish: 5-bo'lim, "Modul nima"; "Birga bajaramiz", 4-qadam.

11. **App server module.** Security group, key pair va instansni `modules/app_server` ga ko'chiring (yana `moved` bilan). Modul `subnet_id` va `vpc_id` ni kirish sifatida oladi, public IP va instans ID'sini qaytaradi; instansga `Role = app` tegi qo'yadi. SSH ingress manbasi o'zgaruvchi bo'lib qoladi (joriy tashqi IP, `0.0.0.0/0` emas). Modul ichida nima uchun `provider` bloki bo'lmasligi kerak? Yo'nalish: 5-bo'lim, "Modul nima" (tuzilish odati).

12. **Two environments.** `envs/stage` yarating: o'sha modullar, boshqa CIDR, boshqa nom prefiksi, backend'da boshqa `key`. `apply` qiling, ikkala muhit mustaqil ekanini ko'rsating (bucket'da ikki state, AWS'da ikki VPC), keyin `stage` ni darhol `destroy` qiling. Alohida sinov papkasida 4-darsdagi Docker kodi bilan `terraform workspace new` ni sinab, state qayerda saqlanishini toping. Ikki yondashuvni o'z tajribangizdan solishtiring. Yo'nalish: 4-bo'lim, "Ikki yondashuv" va "Halol solishtiruv".

13. **Registry module review.** `terraform-aws-modules/vpc/aws` modulini registry'da o'qing: nechta kirish o'zgaruvchisi, standart holatda nima yaratadi, NAT gateway'ni qaysi parametr yoqadi. Alohida papkada versiyasini belgilab chaqiring va faqat `plan` qiling (apply qilmang): nechta resurs? O'z `network` modulingiz bilan solishtiring: qaysi holatda qaysi biri to'g'ri tanlov? Yo'nalish: 5-bo'lim, "`source` shakllari va versiyalash".

14. **Module versioning.** Modul `source` ini git manzili va `?ref=` bilan yozish sintaksisini hujjatdan toping va o'z repongiz uchun misol yozing (qo'llamasdan). Javob bering: `ref` siz manba nimasi bilan xavfli; modulda breaking change (o'zgaruvchi nomi o'zgardi) bo'lsa dev va stage'ni qanday ketma-ketlikda yangilaysiz; bu papka modelida mumkin, workspace modelida nima uchun qiyin? Yo'nalish: 5-bo'lim, "`source` shakllari va versiyalash"; 4-bo'lim, "Halol solishtiruv".

### D. Sifat va CI

15. **tflint and config scan.** `tflint` va `trivy config` (yoki `checkov`) ni Docker orqali ishga tushiring ("Laboratoriya" dagi buyruqlar). Topilmalarni yozing: nechta, qaysi darajada. Kamida uchtasini kodda tuzating, kamida bittasini asosli istisno sifatida asbobning ignore sintaksisi bilan belgilang (sintaksisni hujjatdan toping) va sababini yozing. Yo'nalish: 7-bo'lim, "Asboblar".

16. **Plan on pull request.** GitHub Actions workflow: PR'da `fmt -check`, `validate`, tflint va `envs/dev` uchun `plan`. AWS'ga kirish OIDC role orqali (cicd modulida sozlagan bo'lsangiz o'sha provider, bo'lmasa role'ni `bootstrap/` ga qo'shing), role faqat o'qish va state bucket huquqlariga ega. Plan natijasi job summary'da ko'rinsin. Ataylab formatni buzib PR oching va job qizarishini ko'rsating. Yo'nalish: 7-bo'lim, "PR'dagi pipeline nima qiladi"; cicd 2 va cicd 5.

17. **Apply on merge.** `main` ga merge'da `plan -out` va o'sha faylni `apply` qiladigan job: GitHub environment orqali qo'lda tasdiq, `concurrency` guruhi, `apply` uchun alohida role. Kichik o'zgarish (teg) bilan to'liq oqimni o'tkazing. CI yaratgan muhitni noutbukdan `destroy` qila olasizmi, nima uchun? PR'da ko'rilgan va merge'dan keyin qo'llangan reja farq qilishi mumkin bo'lgan holatni tasvirlang. Yo'nalish: 7-bo'lim, "PR'dagi pipeline nima qiladi" (muhim qoidalar).

### E. Terraform + Ansible

18. **Inventory handoff.** Terraform yaratgan instansni Ansible'ga ikki usulda bering: (a) 3-darsdagi `aws_ec2` dynamic inventory, `Project` va `Role` teglari bo'yicha; (b) `terraform output -json` dan hosil qilingan statik inventory (generatsiya qilinadi, qo'lda yozilmaydi va commit qilinmaydi). Ikkalasida `ansible -m ansible.builtin.ping` ishlasin, ikkala mashinangizdan ham (har birining o'z SSH kaliti bilan). Server "hali tayyor emas" muammosini qanday hal qildingiz? Yo'nalish: 8-bo'lim, "Mehnat taqsimoti" va "Provisioner'lar va server hali tayyor emas".

19. **One command environment.** `Makefile` yozing: `make up` `envs/dev` ni `apply` qiladi, server tayyor bo'lishini kutadi va 3-darsdagi role'lar bilan `ansible-playbook` ni ishga tushiradi; oxirida ilova URL'ini chop etadi. `make down` hammasini o'chiradi. `Makefile` Zorin'da ham, macOS'da ham ishlashi kerak (BSD `sed`, `grep` farqlari). Mezon: toza holatdan `make up`, `curl http://<public-IP>/` ilova javobini qaytaradi; ikkinchi `make up` da Terraform `No changes`, Ansible `changed=0`. Vaqtni o'lchang va `README.md` ga arxitektura tavsifi (instans arxitekturasi tanlovi bilan), narx bahosi va cloud modulidagi qo'lda qurish vaqti bilan solishtiruvni yozing. Yo'nalish: 8-bo'lim to'liq.

20. **Final teardown.** `make down`, keyin "Laboratoriya" dagi teg bo'yicha tekshiruvni bajaring; 7–8-vazifalarda qo'lda yaratilgan resurslar ham yo'qligini tasdiqlang. State bucket haqida qaror: qoldirish qancha turishini AWS narx sahifasidan baholang, lekin bu modulning oxirgi darsi bo'lgani uchun uni (va agar yaratgan bo'lsangiz lock jadvalini, CI role'larini) eng oxirida o'chiring. `prevent_destroy` va versiyalangan obyektlar buni qanday qiyinlashtiradi, qaysi tartibda bajardingiz? Oxirida teg bo'yicha tekshiruv bo'sh chiqishini ko'rsating. Yo'nalish: 1-bo'lim, "State bucket talablari va tovuq-tuxum muammosi"; "Laboratoriya", AWS tartibi.

### Topshirish

Tayyor bo'lgach:
1. `iac/05-terraform-state-modules/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida; papkada `bootstrap/`, `modules/network/`, `modules/app_server/`, `envs/dev/`, `envs/stage/`, workflow fayllari va `Makefile` bor.
2. `make check` toza (u `terraform fmt -check -recursive` ni ishlatadi); har root modulda `terraform validate` toza; tflint toza yoki istisnolar asoslangan.
3. `.terraform.lock.hcl` da `linux_amd64` va `darwin_arm64` hash'lari bor; ikkala mashinada `terraform init` va `plan` ishlagan.
4. Toza holatdan `make up` ishlaydi, `make down` hammasini o'chiradi.
5. CI: PR'da plan, merge'da tasdiq bilan apply ishlaganiga havola (workflow run).
6. `make secrets` toza: repoda state, plan fayli, kalit, secret'li `*.tfvars`, IP yozilgan inventory, vault paroli yo'q; workflow'da uzoq muddatli AWS kaliti yo'q.
7. AWS toza: teg bo'yicha tekshiruvning bo'sh chiqishi `README.md` da, state bucket o'chirilgan, ertasi kuni Billing tekshirilgan.
8. Menga xabar bering, `README.md`, modullar, workflow va `Makefile` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Remote state lokal state'ning qaysi uch muammosini yechadi? Bir kishi ikki mashinada ishlaganda ham nima uchun kerak?
- Kod git orqali, state S3 orqali ko'chadi. Ikkinchi mashinada yana nima qayta yaratiladi va nima uchun ular ko'chmaydi?
- Lock nimadan himoya qiladi? S3 backend'da u qanday amalga oshiriladi va standart holatda yoqilganmi?
- Stale lock nima, uni qanday taniysiz va `force-unlock` dan oldin nimani tekshirasiz?
- Resursni modulga ko'chirganda nima uchun `plan` destroy + create ko'rsatadi va buni qanday oldini olasiz?
- `terraform state rm` va `terraform destroy` farqi nima?
- `import` bloki nimani qiladi va nimani qilmaydi?
- `sensitive = true` qiymatni qayerda yashiradi, qayerda yashirmaydi?
- Workspace va directory-per-environment orasida qanday tanlaysiz?
- `.terraform.lock.hcl` nimani qulflaydi, nimani qulflamaydi? Modul versiyasi qayerda belgilanadi?
- CI'da nima uchun `plan -out` fayli `apply` qilinadi, shunchaki `apply -auto-approve` emas?
- Terraform'dan Ansible'ga host ma'lumotini uzatishning qaysi usullari bor, har birining kuchli tomoni nima?
- Provisioner'lar nima uchun oxirgi chora hisoblanadi?
