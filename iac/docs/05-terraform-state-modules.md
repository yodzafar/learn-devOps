# 5-dars: Terraform state, modullar va CI

Maqsad: 4-darsdagi "bir kishi, bir noutbuk, lokal state" holatidan jamoa ishlata oladigan holatga o'tish: S3 remote backend va locking, state bilan xavfsiz ishlash (`mv`, `rm`, `import`, `moved`), drift'ni aniqlash, muhitlarni ajratish (workspace yoki papka), modul yozish va versiyalash, state'dagi secret'lar, statik tekshiruv (tflint, trivy/checkov), pipeline'da `plan` va `apply`. Oxirida Terraform va 3-darsdagi Ansible role'lari birlashadi: bitta buyruq butun app muhitini quradi, bitta buyruq o'chiradi. Bu modulning yakuniy darsi.

Taxminiy vaqt: 5 kun (siz uchun): 1.5 kun backend va state amallari, 1.5 kun modullar va muhitlar, 1 kun lint va CI, 1 kun mini-loyiha. Diqqatni quyidagilarga qarating: lock nimadan himoya qiladi, refactoring paytida resurs qayta yaratilmasligi uchun nima qilinadi, `sensitive` nimani yashirmaydi, CI'da qaysi reja qo'llanadi, ikki asbob orasida ma'lumot qanday uzatiladi.

## Laboratoriya

- **AWS akkaunt**: deyarli barcha vazifalar. Budget alert yoqilgan, teg `Project = iac-lab`. Bu darsda resurslar bir necha marta yaratilib o'chiriladi; har mashg'ulot oxirida muhitlar `destroy` qilinadi va 4-dars 10-bo'limdagi tekshiruv bajariladi. State bucket dars davomida qoladi (narxi arzimas), oxirgi vazifada qaror qilasiz.
- **Ish mashinasi**: `terraform`, `ansible` (2-darsdan), AWS CLI. Linter'lar o'rnatilmaydi, Docker orqali ishlatiladi:

```
docker run --rm -v "$(pwd):/data" -t ghcr.io/terraform-linters/tflint
docker run --rm -v "$(pwd):/src" aquasec/trivy config /src
```

- **GitHub**: CI vazifalari uchun cicd modulidagi kabi repo va Actions.

Bir vaqtda ikkitadan ortiq EC2 ishlatmang, NAT gateway va load balancer yaratmang. Registry modulini ko'rib chiqish vazifasi (13) faqat `plan`, `apply` qilinmaydi.

---

## 1. Remote state

Lokal state'ning uch muammosi: u bitta noutbukda (hamkasb va CI ko'rmaydi), ikki kishi bir vaqtda `apply` qilsa buziladi, va ichida secret'lar ochiq. Backend state'ni qayerda saqlash va qanday qulflashni belgilaydi.

```
terraform {
  backend "s3" {
    bucket       = "iac-lab-tfstate-123456789012"
    key          = "app/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

- `key` bucket ichidagi obyekt yo'li. Har muhit va har mustaqil stack uchun alohida `key`.
- Backend o'zgarganda `terraform init` state'ni ko'chirishni taklif qiladi: `init -migrate-state`. Ko'chirmasdan qayta sozlash: `init -reconfigure`.
- `backend` blokida Terraform o'zgaruvchi (`var.`) ishlatishga ruxsat bermaydi. Muhitga qarab farq qiladigan qismlar `-backend-config=<file>` yoki `-backend-config="key=..."` bilan beriladi (partial configuration).
- State bucket talablari: versioning yoqilgan (buzilgan state'ni oldingi versiyadan tiklash uchun), public access bloklangan, shifrlash, kirish huquqi tor.

Tovuq va tuxum: state bucket'ning o'zi ham resurs. Odatiy yechim: alohida kichik `bootstrap` konfiguratsiyasi, u faqat bucket'ni yaratadi va lokal state bilan ishlaydi (yoki yaratilgach o'z state'ini shu bucket'ga ko'chiradi).

### Locking
State'ga yozadigan har amal (`plan` ham refresh paytida) lock oladi. Lock band bo'lsa ikkinchi jarayon `Error acquiring the state lock` bilan to'xtaydi va lock ID, kim, qachon olganini ko'rsatadi.

S3 backend'da ikki mexanizm bo'lgan, versiyaga qarab:
- **S3 native lock** (`use_lockfile = true`): state yonida `<key>.tflock` obyekti yaratiladi. Terraform 1.10 dan mavjud.
- **DynamoDB lock** (`dynamodb_table`): eski usul, `LockID` partition key'li jadval talab qiladi. Yangi Terraform versiyalarida eskirgan (deprecated) deb belgilangan, eski loyihalarda ko'p uchraydi. Ko'chish davrida ikkalasini birga sozlash mumkin.

Standart holatda lock o'chiq (`use_lockfile` ning default'i `false`), uni aniq yoqish kerak. O'zingiz ishlatayotgan Terraform yoki OpenTofu versiyasi uchun backend hujjatini (Manbalar) o'qing: argumentlar va kerakli IAM ruxsatlar (`.tflock` obyekti uchun `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`) o'sha yerda.

Jarayon o'ldirilsa lock qolib ketadi. `terraform force-unlock <LOCK_ID>` faqat boshqa hech kim ishlamayotganiga amin bo'lganingizda.

## 2. State bilan ishlash

| Maqsad | Deklarativ (kodda, review qilinadi) | Buyruq (bir martalik) |
|--------|--------------------------------------|------------------------|
| Resurs manzilini o'zgartirish (qayta nomlash, modulga ko'chirish) | `moved { from = ... to = ... }` | `terraform state mv <from> <to>` |
| Mavjud resursni boshqaruvga olish | `import { to = ... id = "..." }` | `terraform import <address> <id>` |
| Resursni o'chirmasdan boshqaruvdan chiqarish | `removed { from = ... lifecycle { destroy = false } }` | `terraform state rm <address>` |
| Ko'rish | | `state list`, `state show <address>`, `state pull` |

Deklarativ bloklar afzal: ular PR'da ko'rinadi, `plan` da tekshiriladi va hamma muhitda bir xil qo'llanadi. `state mv`/`rm` state'ni darhol o'zgartiradi, reja ham, review ham yo'q.

Refactoring qoidasi: resursni qayta nomlaganda yoki modulga ko'chirganda Terraform buni "eskisi o'chirildi, yangisi qo'shildi" deb ko'radi. `moved` bloki "bu o'sha resurs" deb aytadi. Mezon: refactoring'dan keyin `plan` `No changes` yoki faqat `has moved to` ko'rsatishi kerak.

Import: `import` bloki resursni state'ga qo'shadi, lekin kodni siz yozasiz. Kod real resursga mos kelmaguncha `plan` farq ko'rsatadi. Boshlang'ich kodni hosil qilish: `terraform plan -generate-config-out=generated.tf`, keyin uni tozalash shart.

### Drift detection
- `terraform plan -refresh-only`: faqat state va real holat farqini ko'rsatadi, kodni hisobga olmaydi.
- `terraform plan -detailed-exitcode`: exit code `0` farq yo'q, `1` xato, `2` farq bor. Jadval bo'yicha ishlaydigan CI job'ida drift signali sifatida ishlatiladi.

Drift topilganda ikki yo'l: kod to'g'ri bo'lsa `apply` real holatni qaytaradi; real holat to'g'ri bo'lsa (incident paytidagi asosli o'zgarish) kodni yangilaysiz. Uchinchi yo'l, "shunday qolaversin", yo'q.

## 3. Muhitlar: workspace yoki papka

**Workspace**: bitta kod, bitta backend, bir nechta nomlangan state. `terraform workspace new stage`, `select`, `list`, `show`; kodda `terraform.workspace`. S3 backend'da `default` dan boshqa workspace state'lari `env:/<workspace>/<key>` yo'lida saqlanadi.

**Papka** (directory-per-environment): har muhit alohida root modul, o'z backend `key` i va o'z `tfvars` i bilan; umumiy kod modullarda.

```
modules/
  network/      app_server/
envs/
  dev/    main.tf  backend.tf  terraform.tfvars
  stage/  main.tf  backend.tf  terraform.tfvars
```

| | Workspace | Papka |
|---|-----------|-------|
| Qaysi muhitdaman | ko'rinmas holat (`workspace show`) | joriy papka |
| Muhitlar farqi | `terraform.workspace` ga bog'liq shartlar | har muhitning o'z `main.tf` va qiymatlari |
| Akkaunt, backend, huquqlarni ajratish | qiyin | tabiiy |
| Modul versiyasini bosqichma-bosqich ko'tarish | yo'q, kod bitta | bor, avval dev, keyin stage |
| Takror | yo'q | bir oz (modul chaqiruvlari) |

Uzoq yashaydigan muhitlar (dev, stage, prod) uchun papka afzal: xato muhitda `apply` qilish ehtimoli kamroq va muhitlar bir-biridan mustaqil o'zgaradi. Workspace qisqa umrli nusxalar uchun qulay (PR uchun vaqtinchalik muhit).

## 4. Modullar

Modul bu `.tf` fayllar papkasi. Siz ishga tushiradigan papka root modul, u chaqirganlari child modul. Modul funksiyaga o'xshaydi: `variable` parametr, `output` qaytariladigan qiymat, ichidagi resurslar tashqaridan ko'rinmaydi.

```
module "network" {
  source      = "../../modules/network"
  name        = "iac-dev"
  vpc_cidr    = "10.10.0.0/16"
}

module "app_server" {
  source    = "../../modules/app_server"
  subnet_id = module.network.public_subnet_id
}
```

- Modul tuzilishi: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (`required_providers`), `README.md`.
- Yangi modul qo'shilgach yoki `source` o'zgargach `terraform init` kerak.
- `provider` bloklari root modulda yoziladi, child modul faqat `required_providers` da talabini e'lon qiladi.
- Modul ichidagi resurs manzili: `module.network.aws_vpc.this`.

Manbalar (`source`):

| Manba | Misol | Versiya |
|-------|-------|---------|
| Lokal yo'l | `../../modules/network` | repo bilan birga, alohida versiya yo'q |
| Registry | `terraform-aws-modules/vpc/aws` | `version = "~> N.0"` argumenti |
| Git | `git::https://github.com/org/infra-modules.git//network?ref=v1.2.0` | `ref` (tag yoki commit) |

Registry va git modullarida versiyani har doim belgilang. Registry moduli begona kod: u o'nlab resurs yaratishi mumkin (masalan VPC moduli sozlamaga qarab pullik NAT gateway yaratadi), `plan` ni o'qimasdan `apply` qilmang.

Yaxshi modul belgilari: bitta mas'uliyat, kam va tushunarli kirish parametrlari (`description`, `type`, `validation` bilan), boshqa modullar ishlatadigan output'lar, ichida `provider` va backend yo'q. Yomon belgi: bitta resursni o'ragan, har argumentini variable qilib tashqariga chiqargan "wrapper".

## 5. State va secret'lar

`sensitive = true` (variable, output yoki provider belgilagan atribut) qiymatni faqat CLI chiqishida `(sensitive value)` deb yashiradi. State'da va plan faylida u ochiq matn. Demak state'ni o'qiy oladigan har kim barcha secret'larni o'qiydi.

Himoya qatlamlari:
- State bucket'ga kirish huquqi tor, shifrlash yoqilgan, state hech qachon repoda emas.
- Secret'ni Terraform orqali o'tkazmaslik: uni secret manager'da (AWS Secrets Manager, SSM Parameter Store) alohida yaratish, Terraform'da faqat ARN yoki nomiga havola qilish, ilova qiymatni ishga tushganda o'zi o'qiydi.
- Yangi Terraform versiyalarida state'ga yozilmaydigan ephemeral resurslar va write-only argumentlar bor; qaysi versiyada va qaysi resurslarda mavjudligini hujjatdan tekshiring (Manbalar).
- OpenTofu'da state'ni client tomonida shifrlash imkoniyati bor.

## 6. Statik tekshiruv va CI

| Asbob | Nimani topadi |
|-------|---------------|
| `terraform fmt -check`, `validate` | format, sintaksis, tiplar |
| tflint | provider'ga xos xatolar (mavjud bo'lmagan instans tipi), ishlatilmagan o'zgaruvchi, eskirgan sintaksis. Sozlama `.tflint.hcl`, plugin'lar `tflint --init` bilan |
| trivy (`trivy config`) yoki checkov (`checkov -d .`) | xavfsizlik xatolari: ochiq security group, shifrlanmagan bucket, public access |

Skaner topilmasi har doim ham xato emas (laboratoriyada HTTP `0.0.0.0/0` ga ochiq bo'lishi maqsadli). Har istisno kodda izoh bilan, asboblarning ignore sintaksisi orqali belgilanadi, global o'chirish orqali emas.

### Pipeline
Standart oqim: PR'da `plan`, merge'da `apply`.

```
permissions:
  id-token: write
  contents: read
steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.AWS_ROLE_ARN }}
      aws-region: eu-central-1
  - uses: hashicorp/setup-terraform@v3
  - run: terraform init -input=false
  - run: terraform plan -input=false -out=tfplan
```

Action'larning joriy major versiyasini ularning sahifasidan oling. Muhim qoidalar:
- **Credential**: uzoq muddatli AWS kalitlari emas, OIDC orqali vaqtinchalik role (cicd modulidagi kabi). `plan` uchun faqat o'qish huquqli role, `apply` uchun alohida, faqat `main` branch'dan olinadigan role.
- **Ko'rilgan reja qo'llanadi**: `apply` bosqichi PR'da review qilingan rejaga mos bo'lishi kerak. Eng sodda variant: merge'dan keyin qaytadan `plan -out` va o'sha faylni `apply`, orasida qo'lda tasdiq (GitHub environment protection).
- **Ketma-ketlik**: bir stack uchun bir vaqtda bitta job (`concurrency` guruhi). State lock ikkinchi himoya, birinchi emas.
- `-input=false` CI'da savol kutib osilib qolmaslik uchun; `-lock-timeout=5m` band lock'ni biroz kutish uchun.
- Plan chiqishi PR'da ko'rinsin (job summary yoki komment), lekin unda secret bo'lishi mumkinligini unutmang.

## 7. Terraform + Ansible

Terraform serverni yaratadi, Ansible ichini sozlaydi. Orada uzatiladigan ma'lumot: host manzili va rollari.

| Usul | Qanday | Qachon |
|------|--------|--------|
| Teg + dynamic inventory | Terraform `Role`, `Project` teglarini qo'yadi, `aws_ec2` plugin topadi (3-dars) | serverlar soni o'zgaruvchan; ikki asbob bir-biridan mustaqil |
| Output'dan inventory | `terraform output -json` ni skript inventory'ga aylantiradi, yoki `local_file` + `templatefile()` | kichik, statik muhit |
| `user_data` (cloud-init) | server o'zini birinchi yuklanishda sozlaydi | oddiy bootstrap, immutable model |

Terraform provisioner'lari (`local-exec`, `remote-exec`) bilan Ansible'ni resurs ichidan chaqirish mumkin, lekin hujjatning o'zi ularni oxirgi chora deb ataydi: natija state'da aks etmaydi, xato bo'lsa resurs "tainted" bo'lib qoladi. Ikki asbobni tashqi orkestrator (Makefile, pipeline) ketma-ket chaqirgani toza.

**Tuzoq: `apply` tugadi, server hali tayyor emas.** EC2 `running` holatiga o'tishi SSH ochiq va cloud-init tugagan degani emas. Ansible'dan oldin kutish kerak: `ansible.builtin.wait_for_connection` va cloud-init tugashini kutadigan task (`cloud-init status --wait`).

## Tuzoqlar

- Lock'siz remote state. Ikki `apply` bir vaqtda ishlasa state buziladi; S3 backend'da lock default o'chiq.
- `force-unlock` ni xato matnini o'qimasdan ishlatish: boshqa odamning ishlab turgan `apply` i ostidan state'ni tortib olish.
- Resursni `moved` siz qayta nomlash yoki modulga ko'chirish: `plan` da destroy + create, production'da bu downtime yoki ma'lumot yo'qolishi.
- `terraform state rm` ni "o'chirish" deb o'ylash. Resurs AWS'da qoladi, pul sarflaydi, endi uni hech kim boshqarmaydi.
- `sensitive = true` ga ishonib state'ni keng ochiq qoldirish yoki plan faylini artifact sifatida ommaga ochish.
- Workspace'ni tekshirmasdan `apply`: `stage` deb o'ylab `default` da ishlash.
- Modul versiyasini belgilamaslik (`ref` siz git manbasi, `version` siz registry moduli): bugungi `init` kechagidan boshqa kod tortadi.
- CI'da `apply` uchun admin huquqli uzoq muddatli kalit va himoyalanmagan branch.
- PR'da ko'rilgan reja bilan merge'dan keyin qo'llangan reja orasidagi farqni e'tiborsiz qoldirish.
- Mini-loyihada `make down` dan keyin tekshirmaslik: Ansible yaratgan narsa server bilan o'chadi, lekin Terraform'dan tashqarida qo'lda yaratilgan resurs (import tajribasidagi bucket) qolib ketadi.

## Manbalar

- https://developer.hashicorp.com/terraform/language/backend/s3 – S3 backend: `use_lockfile`, DynamoDB lock, IAM ruxsatlar
- https://opentofu.org/docs/language/settings/backends/s3/ – OpenTofu S3 backend
- https://developer.hashicorp.com/terraform/cli/commands/state – state buyruqlari
- https://developer.hashicorp.com/terraform/language/moved – `moved` bloki, refactoring
- https://developer.hashicorp.com/terraform/language/import – `import` bloki va config generatsiyasi
- https://developer.hashicorp.com/terraform/language/state/workspaces – workspace'lar va ularning cheklovlari
- https://developer.hashicorp.com/terraform/language/modules/develop – modul yozish
- https://developer.hashicorp.com/terraform/language/modules/sources – modul manbalari
- https://developer.hashicorp.com/terraform/language/state/sensitive-data – state'dagi secret'lar
- https://developer.hashicorp.com/terraform/language/resources/ephemeral – ephemeral resurslar
- https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax – provisioner'lar nima uchun oxirgi chora
- https://developer.hashicorp.com/terraform/tutorials/automation/github-actions – GitHub Actions bilan Terraform
- https://github.com/terraform-linters/tflint – tflint
- https://trivy.dev/latest/docs/scanner/misconfiguration/ – trivy config skaneri
- https://www.checkov.io/ – checkov
- Yevgeniy Brikman, "Terraform: Up & Running" (3-nashr), 3, 4, 6 va 9 boblar

---

## Vazifalar

Ish papkasi: `iac/05-terraform-state-modules/` (`make new m=iac n=05 name=terraform-state-modules`), ichida `bootstrap/`, `modules/`, `envs/dev/`, `envs/stage/`, `ansible/` (3-darsdagi role'lar nusxasi yoki ularga havola) va `Makefile`. Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, `plan` chiqishining muhim qismi va o'z so'zingiz bilan izoh. Boshlang'ich kod: 4-darsdagi `aws/` papkasi nusxasi. State, plan fayllari, kalitlar va vault paroli commit qilinmaydi.

### A. Remote state

1. **Bootstrap state bucket.** `bootstrap/` da state uchun S3 bucket yarating: versioning, shifrlash, public access bloklangan, `prevent_destroy`. Bu konfiguratsiyaning o'z state'i qayerda turadi va bu nima uchun maqbul (yoki maqbul emas)? Tovuq va tuxum muammosini o'z so'zingiz bilan yozing.

2. **Migrate state.** 4-darsdagi AWS kodini `apply` qiling (lokal state), keyin `backend "s3"` blokini `use_lockfile = true` bilan qo'shib `terraform init -migrate-state` qiling. Bucket'da state obyektini AWS CLI bilan ko'rsating. Lokal `terraform.tfstate` da nima qoldi? `plan` toza ekanini tasdiqlang.

3. **Lock contention.** Bir terminalda `terraform apply` ni tasdiq so'rovida to'xtatib turing, ikkinchisida `plan` qiling. Xato matnidan lock ID, kim va qachon olganini yozing. Shu paytda bucket'da `.tflock` obyektini toping va mazmunini o'qing. `-lock-timeout=30s` nima qiladi? `force-unlock` qachon to'g'ri, qachon xavfli?

4. **State version recovery.** Bir nechta `apply` dan keyin `aws s3api list-object-versions` bilan state versiyalarini ko'ring. Oldingi versiyani yuklab olib, `serial` qiymatlarini solishtiring. Buzilgan state'ni tiklash rejasini qadamma-qadam yozing (bajarmasdan), `terraform state push` nima uchun ehtiyotkorlik talab qilishini ayting.

5. **Secrets in state.** `hashicorp/random` provider'ining `random_password` resursini qo'shing va `sensitive` output qiling. `apply` chiqishi, `terraform output`, `terraform output -raw` va `terraform state pull` ning har biri qiymatni ko'rsatadimi? Xulosa yozing: `sensitive` nimani himoya qiladi, state'ni nima himoya qiladi.

### B. State amallari

6. **Rename with moved.** `aws_instance` ning Terraform nomini o'zgartiring va `plan` ni o'qing (apply qilmang): nima taklif qilinyapti? `moved` bloki qo'shing: endi-chi? `apply` qiling va instans ID'si o'zgarmaganini ko'rsating. Xuddi shu ishni `terraform state mv` bilan qilish nimasi bilan farq qiladi?

7. **Import.** AWS CLI bilan qo'lda security group yoki S3 bucket yarating (teg bilan). Unga mos `resource` va `import` blokini yozing. Birinchi `plan` da qanday farqlar chiqdi? Kodni real holatga moslab, `plan` faqat import ko'rsatadigan holatga keltiring, `apply` qiling. `-generate-config-out` ni ham sinab, hosil bo'lgan kod sifatini baholang.

8. **Remove from state.** 7-vazifadagi resursni o'chirmasdan boshqaruvdan chiqaring (`removed` bloki, `destroy = false`). `state list` da yo'qligini, AWS'da borligini ko'rsating. Keyin uni AWS CLI bilan qo'lda o'chiring. Bu amal production'da qachon kerak bo'ladi?

9. **Drift detection.** Konsol yoki CLI orqali Terraform boshqaradigan security group'ga yangi ingress qoidasi qo'shing va instans tegini o'zgartiring. `plan -refresh-only`, oddiy `plan` va `plan -detailed-exitcode` (`echo $?`) natijalarini yozing. Qaysi drift ko'rindi, qaysi biri ko'rinmadi va nima uchun? Bittasini kod foydasiga, ikkinchisini real holat foydasiga hal qiling.

### C. Modullar va muhitlar

10. **Network module.** VPC, subnet, internet gateway va route resurslarini `modules/network` ga ko'chiring: tipli va tavsifli kirish o'zgaruvchilari, kerakli output'lar. `envs/dev` dan chaqiring. Resurslar qayta yaratilmasligi uchun `moved` bloklarini yozing: `plan` da `0 to add, 0 to destroy`. `state list` dagi yangi manzillarni ko'rsating.

11. **App server module.** Security group, key pair va instansni `modules/app_server` ga ko'chiring (yana `moved` bilan). Modul `subnet_id` va `vpc_id` ni kirish sifatida oladi, public IP va instans ID'sini qaytaradi; instansga `Role = app` tegi qo'yadi. Modul ichida nima uchun `provider` bloki bo'lmasligi kerak?

12. **Two environments.** `envs/stage` yarating: o'sha modullar, boshqa CIDR, boshqa nom prefiksi, backend'da boshqa `key`. `apply` qiling, ikkala muhit mustaqil ekanini ko'rsating (bucket'da ikki state, AWS'da ikki VPC), keyin `stage` ni darhol `destroy` qiling. Alohida sinov papkasida 4-darsdagi Docker kodi bilan `terraform workspace new` ni sinab, state qayerda saqlanishini toping. Ikki yondashuvni o'z tajribangizdan solishtiring.

13. **Registry module review.** `terraform-aws-modules/vpc/aws` modulini registry'da o'qing: nechta kirish o'zgaruvchisi, standart holatda nima yaratadi, NAT gateway'ni qaysi parametr yoqadi. Alohida papkada versiyasini belgilab chaqiring va faqat `plan` qiling (apply qilmang): nechta resurs? O'z `network` modulingiz bilan solishtiring: qaysi holatda qaysi biri to'g'ri tanlov?

14. **Module versioning.** Modul `source` ini git manzili va `?ref=` bilan yozish sintaksisini hujjatdan toping va o'z repongiz uchun misol yozing (qo'llamasdan). Javob bering: `ref` siz manba nimasi bilan xavfli; modulda breaking change (o'zgaruvchi nomi o'zgardi) bo'lsa dev va stage'ni qanday ketma-ketlikda yangilaysiz; bu papka modelida mumkin, workspace modelida nima uchun qiyin?

### D. Sifat va CI

15. **tflint and config scan.** `tflint` va `trivy config` (yoki `checkov`) ni Docker orqali ishga tushiring. Topilmalarni yozing: nechta, qaysi darajada. Kamida uchtasini kodda tuzating, kamida bittasini asosli istisno sifatida asbobning ignore sintaksisi bilan belgilang (sintaksisni hujjatdan toping) va sababini yozing.

16. **Plan on pull request.** GitHub Actions workflow: PR'da `fmt -check`, `validate`, tflint va `envs/dev` uchun `plan`. AWS'ga kirish OIDC role orqali (cicd modulida sozlagan bo'lsangiz o'sha provider, bo'lmasa role'ni `bootstrap/` ga qo'shing), role faqat o'qish va state bucket huquqlariga ega. Plan natijasi job summary'da ko'rinsin. Ataylab formatni buzib PR oching va job qizarishini ko'rsating.

17. **Apply on merge.** `main` ga merge'da `plan -out` va o'sha faylni `apply` qiladigan job: GitHub environment orqali qo'lda tasdiq, `concurrency` guruhi, `apply` uchun alohida role. Kichik o'zgarish (teg) bilan to'liq oqimni o'tkazing. CI yaratgan muhitni noutbukdan `destroy` qila olasizmi, nima uchun? PR'da ko'rilgan va merge'dan keyin qo'llangan reja farq qilishi mumkin bo'lgan holatni tasvirlang.

### E. Terraform + Ansible

18. **Inventory handoff.** Terraform yaratgan instansni Ansible'ga ikki usulda bering: (a) 3-darsdagi `aws_ec2` dynamic inventory, `Project` va `Role` teglari bo'yicha; (b) `terraform output -json` dan hosil qilingan statik inventory. Ikkalasida `ansible -m ansible.builtin.ping` ishlasin. Server "hali tayyor emas" muammosini qanday hal qildingiz?

19. **One command environment.** `Makefile` yozing: `make up` `envs/dev` ni `apply` qiladi, server tayyor bo'lishini kutadi va 3-darsdagi role'lar bilan `ansible-playbook` ni ishga tushiradi; oxirida ilova URL'ini chop etadi. `make down` hammasini o'chiradi. Mezon: toza holatdan `make up`, `curl http://<public-IP>/` ilova javobini qaytaradi; ikkinchi `make up` da Terraform `No changes`, Ansible `changed=0`. Vaqtni o'lchang va `README.md` ga arxitektura tavsifi, narx bahosi va cloud modulidagi qo'lda qurish vaqti bilan solishtiruvni yozing.

20. **Final teardown.** `make down`, keyin 4-dars 10-bo'limdagi tekshiruvni teg bo'yicha bajaring; 7–8-vazifalarda qo'lda yaratilgan resurslar ham yo'qligini tasdiqlang. State bucket haqida qaror qiling: qoldirasizmi (narxi qancha) yoki o'chirasizmi. O'chirsangiz: `prevent_destroy` va versiyalangan obyektlar buni qanday qiyinlashtiradi, qaysi tartibda bajardingiz?

### Topshirish

Tayyor bo'lgach:
1. `make check` toza; `terraform fmt -check -recursive` va har root modulda `terraform validate` toza; tflint toza yoki istisnolar asoslangan.
2. Toza holatdan `make up` ishlaydi, `make down` hammasini o'chiradi.
3. CI: PR'da plan, merge'da tasdiq bilan apply ishlaganiga havola (workflow run).
4. Repoda state, plan fayli, kalit, vault paroli yo'q; workflow'da uzoq muddatli AWS kaliti yo'q.
5. AWS toza: teg bo'yicha tekshiruv chiqishi `README.md` da, ertasi kuni Billing tekshirilgan.
6. Menga xabar bering, `README.md`, modullar, workflow va `Makefile` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Remote state lokal state'ning qaysi uch muammosini yechadi?
- Lock nimadan himoya qiladi? S3 backend'da u qanday amalga oshiriladi va standart holatda yoqilganmi?
- Resursni modulga ko'chirganda nima uchun `plan` destroy + create ko'rsatadi va buni qanday oldini olasiz?
- `terraform state rm` va `terraform destroy` farqi nima?
- `import` bloki nimani qiladi va nimani qilmaydi?
- `sensitive = true` qiymatni qayerda yashiradi, qayerda yashirmaydi?
- Workspace va directory-per-environment orasida qanday tanlaysiz?
- CI'da nima uchun `plan -out` fayli `apply` qilinadi, shunchaki `apply -auto-approve` emas?
- Terraform'dan Ansible'ga host ma'lumotini uzatishning qaysi usullari bor, har birining kuchli tomoni nima?
- Provisioner'lar nima uchun oxirgi chora hisoblanadi?
