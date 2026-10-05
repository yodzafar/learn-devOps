# 4-dars: Terraform asoslari

Maqsad: Terraform (yoki OpenTofu) bilan resurslarni deklarativ yaratish, o'zgartirish va o'chirishni o'rganish: HCL, provider, resource, data source, variable/output/local, `init`/`plan`/`apply`/`destroy` sikli, state fayli, dependency graph, lifecycle, `count` va `for_each`. Avval lokal Docker provider bilan mexanizmlarni pulsiz o'zlashtirasiz, keyin cloud modulida qo'lda qurgan tarmoq va serverni (VPC, subnet, security group, EC2, S3) kod bilan qayta qurasiz. 1-darsdagi "state" va "removal problem" savollariga bu yerda javob olasiz. 5-dars shu kodni remote state, modullar va CI bilan jamoaviy ishga yaroqli qiladi.

Taxminiy vaqt: 5 kun (siz uchun): 2 kun Docker provider, 3 kun AWS. HCL sintaksisi tez o'zlashadi, diqqatni quyidagilarga qarating: `plan` chiqishini o'qish (in-place update va replace farqi), state aynan nimani saqlaydi va yo'qolsa nima bo'ladi, `count` indeks siljishi, `(known after apply)` qayerdan keladi, AWS'da har resursning narxi va `destroy` dan keyingi tekshiruv.

## Laboratoriya

- **Ish mashinasi**: `terraform` CLI shu yerda. Terraform serverga kirmaydi, API bilan gaplashadi, shuning uchun VM kerak emas.
- **Lokal Docker** (A, B, C guruhlar): bepul, resurslar bu sizning Docker daemon'ingizdagi konteyner, image va network'lar.
- **AWS akkaunt** (D guruh): cloud modulidagi IAM user yoki profil. Boshlashdan oldin: budget alert yoqilganini tekshiring, `aws sts get-caller-identity` to'g'ri akkauntni ko'rsatsin. Har mashg'ulot oxirida `terraform destroy` va tekshiruv majburiy.

O'rnatish, HashiCorp apt repozitoriysidan (hujjat: https://developer.hashicorp.com/terraform/install):

```
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
```

Zorin OS'da repo qatoridagi kod nomi Ubuntu asosiniki (`noble`) bo'lishi kerak, yuqoridagi buyruq uni `UBUNTU_CODENAME` dan oladi. OpenTofu tanlasangiz: https://opentofu.org/docs/intro/install/ , keyin barcha buyruqlarda `terraform` o'rniga `tofu`.

Ish papkasidagi `.gitignore` ga darhol qo'shing: `.terraform/`, `*.tfstate`, `*.tfstate.*`, `*.tfplan`, secret saqlaydigan `*.tfvars`. `.terraform.lock.hcl` esa commit qilinadi.

Tozalash: Docker qismi uchun `terraform destroy`, keyin `docker ps -a` da dars konteynerlari yo'q. AWS qismi uchun 10-bo'limdagi tekshiruv ro'yxati.

---

## 1. Terraform qanday ishlaydi

Terraform ikki qismdan iborat. **Core** (CLI) HCL'ni o'qiydi, resurslar grafini quradi, state bilan solishtirib rejani hisoblaydi. **Provider** alohida plugin (binary), u aniq API bilan gaplashadi: `hashicorp/aws`, `kreuzwerker/docker`. Core "bu resursni yarat" deydi, provider uni API chaqiruviga aylantiradi.

Ish sikli:

| Buyruq | Nima qiladi |
|--------|-------------|
| `terraform init` | provider'larni `.terraform/` ga yuklaydi, backend'ni sozlaydi, `.terraform.lock.hcl` yozadi |
| `terraform plan` | real holatni o'qiydi (refresh), kod bilan solishtiradi, rejani ko'rsatadi. Hech narsani o'zgartirmaydi |
| `terraform apply` | rejani ko'rsatadi, `yes` dan keyin bajaradi, state'ni yangilaydi |
| `terraform destroy` | state'dagi barcha resurslarni o'chiradi (`apply -destroy` ning qisqasi) |

`plan` uch manbani solishtiradi: kod (kerakli holat), state (oxirgi ma'lum holat) va provider orqali o'qilgan real holat. Natija amallar ro'yxati:

| Belgi | Ma'no |
|-------|-------|
| `+` | yaratiladi |
| `-` | o'chiriladi |
| `~` | joyida o'zgartiriladi (in-place update) |
| `-/+` | o'chirib qayta yaratiladi (replace); sabab bo'lgan atribut yonida `# forces replacement` |
| `<=` | data source o'qiladi |

Replace yoki in-place ekanini provider belgilaydi: API atributni o'zgartirishga ruxsat bermasa (EC2 ning AMI'si, konteynerning image'i), yagona yo'l qayta yaratish. `plan` da `-/+` ko'rsangiz to'xtab o'qing: bu ma'lumot yo'qolishi va downtime bo'lishi mumkin.

`(known after apply)` qiymat faqat resurs yaratilgandan keyin ma'lum bo'lishini bildiradi (ID, IP manzil).

## 2. HCL

```
resource "docker_container" "web" {
  name  = "iac-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}
```

- **Blok**: tur (`resource`), label'lar (`"docker_container"`, `"web"`), tana `{ }`. Ichida argumentlar (`name = ...`) va ichki bloklar (`ports { }`).
- Resurs manzili `<type>.<name>`: `docker_container.web`. Nom faqat Terraform ichida, real resurs nomi emas.
- Havola: `docker_image.nginx.image_id`, `var.external_port`, `local.tags`, `data.aws_ami.ubuntu.id`, `module.network.vpc_id`.
- Tiplar: `string`, `number`, `bool`, `list(T)`, `set(T)`, `map(T)`, `object({...})`. String ichida interpolatsiya: `"app-${var.env}"`.
- Papkadagi barcha `*.tf` fayllar bitta modul sifatida birga o'qiladi. Fayl nomlari va bloklar tartibi ahamiyatsiz; odat: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- Ifodalar: shartli `cond ? a : b`, `for` (`[for s in var.names : upper(s)]`), funksiyalar (`length`, `merge`, `lookup`, `cidrsubnet`, `templatefile`, `jsonencode`). Sinab ko'rish: `terraform console`.

HCL dasturlash tili emas: sikl va shart faqat qiymat hisoblash uchun, bajarilish tartibini siz emas, graf belgilaydi.

## 3. Provider va versiyalar

```
terraform {
  required_version = ">= 1.9"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0"
    }
  }
}

provider "docker" {}
```

- `source` registry manzili (`registry.terraform.io/kreuzwerker/docker`). `~> 4.0` "4.x, lekin 5.0 emas" degani. Joriy major versiyani registry sahifasidan oling, yuqoridagi raqamlar namuna.
- `.terraform.lock.hcl` tanlangan aniq versiya va checksum'larni yozadi, `package-lock.json` ning o'xshashi. Commit qilinadi; yangilash: `terraform init -upgrade`.
- `.terraform/` yuklangan plugin'lar (`node_modules` o'xshashi), commit qilinmaydi.
- `provider` bloki sozlamalar: region, endpoint, credential manbai. Credential'lar bu yerga yozilmaydi.

## 4. Resource va data source

- `resource` Terraform boshqaradigan obyekt: yaratadi, o'zgartiradi, o'chiradi.
- `data` mavjud narsani faqat o'qiydi: `data "aws_ami" "ubuntu"` eng yangi Ubuntu AMI ID'sini topadi, `data "aws_caller_identity" "current"` akkaunt ID'sini beradi. Data source hech narsa yaratmaydi.

Har resurs turining argumentlari (siz yozasiz) va atributlari (provider qaytaradi: `id`, `arn`, `public_ip`) registry hujjatida. Bu hujjat sizning asosiy ma'lumotnomangiz.

## 5. Variable, local, output

```
variable "external_port" {
  type        = number
  default     = 8080
  description = "Host port for the web container"

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535
    error_message = "external_port must be between 1024 and 65535."
  }
}

locals {
  name_prefix = "iac-${var.env}"
}

output "url" {
  value = "http://localhost:${var.external_port}"
}
```

- `variable` modulning kirish parametri. `default` bo'lmasa majburiy. `sensitive = true` qiymatni CLI chiqishida yashiradi (state'da baribir ochiq, 5-dars).
- `locals` ichki hisoblangan qiymatlar, takrorni yo'qotadi.
- `output` natija: `apply` oxirida ko'rsatiladi, `terraform output`, skriptlar uchun `terraform output -raw url` va `-json`.

Variable qiymati manbalari, pastdan yuqoriga (keyingisi oldingisini yopadi): `default`, `TF_VAR_<name>` muhit o'zgaruvchisi, `terraform.tfvars`, `*.auto.tfvars` (alifbo tartibida), buyruq qatoridagi `-var` va `-var-file` (yozilgan tartibda).

## 6. State

`apply` dan keyin papkada `terraform.tfstate` paydo bo'ladi. Bu JSON fayl:

| Maydon | Ma'no |
|--------|-------|
| `serial` | har yozishda ortadigan hisoblagich |
| `lineage` | state yaratilganda berilgan noyob ID, boshqa state bilan adashtirmaslik uchun |
| `outputs` | output qiymatlari |
| `resources` | har resurs: manzili, provider'i va barcha atributlari (real ID, shu jumladan parol kabi qiymatlar ochiq matnda) |

State uch vazifani bajaradi: koddagi manzilni real ID bilan bog'laydi (`docker_container.web` va konteyner ID'si), "nimani men yaratganman" ni eslab qoladi (koddan olib tashlangan resursni o'chirish uchun), va resurslar orasidagi bog'liqlikni saqlaydi (o'chirish tartibi uchun).

Ko'rish: `terraform state list`, `terraform state show <address>`, `terraform show`. Faylni qo'lda tahrirlamang.

State yo'qolsa resurslar joyida qoladi, lekin Terraform ularni "tanimaydi": keyingi `plan` hammasini qaytadan yaratishni taklif qiladi. Shuning uchun lokal state faqat o'rganish uchun; jamoada remote backend (5-dars).

**Tuzoq: state Terraform'ning haqiqat haqidagi tasavvuri, haqiqatning o'zi emas.** Kimdir resursni qo'lda o'zgartirsa (drift), buni faqat keyingi `plan` paytidagi refresh ko'rsatadi. Faqat drift'ni ko'rish: `terraform plan -refresh-only`.

## 7. Dependency graph

Terraform resurslarni yozilgan tartibda emas, bog'liqlik grafi bo'yicha yaratadi. Bir resurs boshqasining atributiga havola qilsa (`image = docker_image.nginx.image_id`), yashirin bog'liqlik hosil bo'ladi: avval image, keyin konteyner. Bog'liq bo'lmagan resurslar parallel yaratiladi (standart 10 ta, `-parallelism=N`). O'chirish teskari tartibda.

Havola orqali ifodalanmaydigan bog'liqlik uchun `depends_on = [aws_internet_gateway.main]`. Bu oxirgi chora: ko'pincha havola yetarli, ortiqcha `depends_on` rejani keraksiz konservativ qiladi.

Grafni ko'rish: `terraform graph` (DOT formatida matn chiqaradi).

## 8. Meta-argumentlar

Har qanday resursda ishlaydigan argumentlar: `count`, `for_each`, `depends_on`, `provider`, `lifecycle`.

### count va for_each

```
resource "docker_container" "app" {
  for_each = toset(["api", "worker", "cron"])
  name     = "iac-${each.key}"
  image    = docker_image.nginx.image_id
}
```

| | `count = 3` | `for_each = toset([...])` yoki map |
|---|------------|-------------------------------------|
| Manzil | `docker_container.app[0]`, `[1]`, `[2]` | `docker_container.app["api"]` |
| Ichida | `count.index` | `each.key`, `each.value` |
| O'rtadagi element olib tashlansa | keyingilarning indeksi siljiydi: ular o'zgartiriladi yoki qayta yaratiladi | faqat o'sha element o'chiriladi |
| Qachon | bir xil nusxalar, yoki shartli resurs (`count = var.enabled ? 1 : 0`) | har elementning o'z kimligi bor |

**Tuzoq: `count` bilan ro'yxat.** `count = length(var.names)` va `var.names[count.index]` yozib, ro'yxat boshidan element olib tashlasangiz, Terraform qolgan barcha resurslarni "nomi o'zgargan" deb ko'radi. Production'da bu serverlarning qayta yaratilishi.

### lifecycle

Resurs ichidagi `lifecycle { ... }` bloki hayot sikli qoidalarini o'zgartiradi:

- `create_before_destroy`: replace'da avval yangisi yaratiladi, keyin eskisi o'chiriladi (downtime'siz almashtirish; noyob nom talab qiladigan resurslarda to'qnashuv beradi).
- `prevent_destroy`: resursni o'chirishni o'z ichiga olgan reja xato bilan to'xtaydi. Ma'lumotlar bazasi va state bucket uchun. Blokni koddan butunlay olib tashlasangiz himoya ham ketadi.
- `ignore_changes = [tags]`: sanab o'tilgan atributlardagi farq e'tiborga olinmaydi (tashqi tizim o'zgartiradigan teglar, autoscaling o'zgartiradigan son).
- `replace_triggered_by`: boshqa resurs o'zgarganda buni qayta yaratish.

## 9. fmt, validate, plan fayli

- `terraform fmt` kanonik formatga keltiradi (`gofmt` kabi), `fmt -check -diff` CI uchun, `-recursive` ichki papkalar bilan.
- `terraform validate` sintaksis, tiplar va havolalarni tekshiradi. API'ga murojaat qilmaydi: mavjud bo'lmagan AMI yoki band bucket nomini faqat `plan` yoki `apply` ko'rsatadi.
- `terraform plan -out=app.tfplan`, keyin `terraform apply app.tfplan`: aynan ko'rilgan reja bajariladi, tasdiq so'ralmaydi. Orada state o'zgargan bo'lsa reja eskirgan deb rad etiladi. CI'dagi oqim shunga asoslanadi. Plan fayli ichida secret'lar ochiq bo'lishi mumkin, commit qilinmaydi.
- `terraform apply -replace=<address>` bitta resursni majburan qayta yaratadi.

## 10. AWS: tarmoq, server, bucket

Cloud modulida qo'lda qurgan sxema:

| Resurs | Terraform turi | Narx |
|--------|----------------|------|
| VPC, subnet, route table, internet gateway | `aws_vpc`, `aws_subnet`, `aws_route_table`, `aws_route_table_association`, `aws_internet_gateway` | bepul |
| Security group va qoidalar | `aws_security_group`, `aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule` | bepul |
| SSH kalit | `aws_key_pair` | bepul |
| EC2 instans | `aws_instance` | soatbay; EBS disk va public IPv4 manzil alohida hisoblanadi |
| S3 bucket | `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block` | saqlangan hajm va so'rovlar bo'yicha |

Free tier shartlari akkaunt yaratilgan sanaga bog'liq, o'zingiznikini Billing konsolidan tekshiring va cloud modulida ishlatgan eng kichik instans tipini oling. NAT gateway va load balancer bu darsda yaratilmaydi.

```
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "iac-lab"
      ManagedBy = "terraform"
    }
  }
}
```

- Provider AWS CLI bilan bir xil credential zanjirini ishlatadi (`AWS_PROFILE`, muhit o'zgaruvchilari, `~/.aws/`). Kalitlarni `.tf` ga yozmang.
- `default_tags` har resursga teg qo'shadi: tozalikni teg bo'yicha tekshirasiz.
- AMI'ni qo'lda yozmang, `data "aws_ami"` bilan toping: `owners = ["099720109477"]` (Canonical), `most_recent = true`, `name` filtri `ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*`.
- Birinchi yuklanishdagi sozlash: `user_data` ga 1-darsdagi cloud-init faylingiz (`file()` yoki `templatefile()` bilan).

**Tuzoq: egress qoidasi.** Konsolda yaratilgan security group'da "hamma chiquvchi trafikka ruxsat" qoidasi avtomatik bo'ladi. Terraform bilan yaratilganda provider bu standart qoidani olib tashlaydi: egress qoidasini o'zingiz yozmasangiz instans tashqariga chiqa olmaydi va `user_data` dagi `apt` jimgina muvaffaqiyatsiz bo'ladi.

**Tuzoq: bo'sh bo'lmagan bucket.** `destroy` ichida obyekt (yoki versiya) bor bucket'ni o'chira olmaydi va xato beradi. Laboratoriya bucket'i uchun `force_destroy = true`; production'da bu argument xavfli.

### Destroy'dan keyingi tekshiruv

```
terraform destroy
terraform state list
aws ec2 describe-instances --filters "Name=tag:Project,Values=iac-lab" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query "Reservations[].Instances[].InstanceId"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=iac-lab" --query "Vpcs[].VpcId"
aws ec2 describe-volumes --filters "Name=tag:Project,Values=iac-lab" --query "Volumes[].VolumeId"
aws s3 ls
```

Hammasi bo'sh ro'yxat qaytarishi kerak (`aws s3 ls` da dars bucket'i yo'q). Ertasi kuni Billing konsolida kutilmagan xarajat yo'qligini ko'ring.

## Tuzoqlar

- `terraform.tfstate` ni commit qilish. Ichida secret'lar ochiq, va ikki kishi ikki nusxa bilan ishlasa state buziladi.
- `plan` ni o'qimasdan `apply -auto-approve`. `-/+` belgisi ma'lumotlar bazasini qayta yaratishi mumkin.
- Terraform boshqaradigan resursni konsoldan o'zgartirish. Keyingi `apply` uni qaytaradi yoki kutilmagan replace chiqadi.
- `count` bilan ro'yxat ustida resurs yaratish va o'rtadan element olib tashlash.
- State'ni yo'qotish yoki boshqa papkadan `apply` qilish: resurslar ikki nusxada yaratiladi yoki nom to'qnashuvi bilan yarmida to'xtaydi.
- Security group'da egress qoidasini unutish; SSH'ni `0.0.0.0/0` ga ochish.
- `destroy` xato bilan yarmida to'xtaganini payqamaslik (masalan bo'sh bo'lmagan bucket). Har doim `terraform state list` bo'sh ekanini va AWS CLI tekshiruvini ko'ring.
- `user_data` o'zgarishi mavjud instansda cloud-init'ni qayta ishlatadi deb kutish. cloud-init birinchi yuklanishda ishlaydi (1-dars).
- AWS kalitlarini `provider` blokiga yoki `terraform.tfvars` ga yozib commit qilish.

## Manbalar

- https://developer.hashicorp.com/terraform/install – o'rnatish
- https://opentofu.org/docs/intro/install/ – OpenTofu o'rnatish
- https://developer.hashicorp.com/terraform/language/syntax/configuration – HCL sintaksisi
- https://developer.hashicorp.com/terraform/language/resources/syntax – resource bloklari
- https://developer.hashicorp.com/terraform/language/values/variables – variable, qiymat manbalari tartibi
- https://developer.hashicorp.com/terraform/language/files/dependency-lock – `.terraform.lock.hcl`
- https://developer.hashicorp.com/terraform/language/meta-arguments/for_each – `for_each` va `count`
- https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle – lifecycle
- https://developer.hashicorp.com/terraform/cli/commands/plan – `plan` va uning rejimlari
- https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs – Docker provider
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs – AWS provider
- Yevgeniy Brikman, "Terraform: Up & Running" (3-nashr), 1–3 va 5 boblar

---

## Vazifalar

Ish papkasi: `iac/04-terraform-basics/` (`make new m=iac n=04 name=terraform-basics`), ichida ikki alohida Terraform papkasi: `docker/` (A, B, C guruhlar) va `aws/` (D guruh), har biri o'z state'i bilan. Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, `plan` chiqishining muhim qismi va o'z so'zingiz bilan izoh. `.tf` fayllar commit qilinadi, `terraform.tfstate` va `.terraform/` yo'q.

### A. Docker provider: birinchi sikl

1. **Install and init.** Terraform (yoki OpenTofu) o'rnating, versiyani yozing. `docker/` papkasida `versions.tf` (provider talabi) yozib `terraform init` qiling. `.terraform/` ichida nima paydo bo'ldi, hajmi qancha? `.terraform.lock.hcl` da nima yozilgan? Qaysi biri commit qilinadi va nima uchun?

2. **First apply.** `docker_image` (nginx) va `docker_container` (host porti 8080) yozing. `plan` chiqishini o'qing: nechta resurs, qaysi atributlar `(known after apply)`. `apply` qiling, `curl localhost:8080` va `docker ps` bilan tekshiring. Darhol yana `plan`: nima deydi?

3. **Read the state.** `terraform.tfstate` ni oching (faqat o'qish): `serial`, `lineage`, `resources` ni toping. Konteyner uchun state'da nechta atribut saqlangan, siz ulardan nechtasini yozgansiz? `terraform state list` va `terraform state show` chiqishi bilan solishtiring. Yana bir `apply` dan keyin `serial` o'zgardimi?

4. **Update or replace.** Konteynerning tashqi portini, keyin `restart` siyosatini, keyin nomini bittalab o'zgartirib faqat `plan` qiling. Har biri uchun: belgi (`~` yoki `-/+`), qaysi atribut `# forces replacement` deb belgilangan. Bittasini `apply` qilib, `docker ps` da konteyner ID'si o'zgarganini yoki o'zgarmaganini ko'rsating.

5. **Variables and outputs.** `container_name`, `external_port` (validation bilan) va `image_tag` o'zgaruvchilarini kiriting, URL uchun output qo'shing. `external_port` ga to'rt manbadan har xil qiymat bering (`default`, `TF_VAR_`, `terraform.tfvars`, `-var`) va qaysi biri yutishini bittalab olib tashlab tasdiqlang. `terraform output -raw` ni `curl` bilan birlashtiring.

6. **Validation errors.** Uch xil xato chiqaring va matnini o'qing: validation shartini buzadigan port; `number` o'zgaruvchiga `"abc"`; mavjud bo'lmagan resursga havola. Har biri qaysi bosqichda (`validate`, `plan`, `apply`) ushlandi?

### B. Graph, count, lifecycle

7. **Dependency graph.** `docker_network` qo'shing va konteynerni unga ulang. `terraform graph` chiqishidan konteyner, image va network orasidagi qirralarni toping. `apply` va `destroy` log'ida yaratish va o'chirish tartibini yozing. Havolani olib tashlab network nomini string bilan yozsangiz nima buziladi?

8. **count vs for_each.** `names = ["api", "worker", "cron"]` ro'yxatidan `count` bilan uchta konteyner yarating. Ro'yxatdan `"api"` ni olib tashlab faqat `plan` qiling: nechta resursga tegildi, nima uchun? Keyin `destroy` qilib xuddi shu konteynerlarni `for_each` bilan qayta yozing va tajribani takrorlang: endi nechta? `state list` dagi manzillarni ikkala variantda solishtiring.

9. **Lifecycle.** Uch tajriba: (a) `prevent_destroy = true` bilan `terraform destroy`, xatoni o'qing; (b) nomi qat'iy konteynerga `create_before_destroy = true` qo'yib replace chaqiring, xato sababini izohlang va qanday resurslarda bu ishlashini ayting; (c) `ignore_changes` bilan bitta atributdagi o'zgarishni e'tiborsiz qoldiring va `plan` da ko'rsating.

10. **fmt and validate.** Faylni ataylab yomon formatlang va bitta havolani buzing. `terraform fmt -check -diff` va `terraform validate` chiqishini yozing. Image nomini mavjud bo'lmagan tegga o'zgartiring: `validate` ushladimi, qaysi bosqich ushladi? `validate` nimani tekshira olmasligini umumlashtiring.

### C. Drift va state

11. **Drift.** Terraform yaratgan konteynerni `docker rm -f` bilan qo'lda o'chiring. `terraform plan -refresh-only` nima ko'rsatadi, oddiy `plan` nima taklif qiladi? `apply` bilan tiklang. Keyin konteynerni qo'lda `docker stop` qiling: bu safar reja qanday?

12. **Lost state.** `terraform.tfstate` ni boshqa nomga ko'chiring (o'chirmang). `plan` nima deydi? `apply` qilib ko'ring: qaysi resurs yaratildi, qaysi birida xato chiqdi va nima uchun? Yarim yaratilgan resurslarni tozalab, asl state'ni qaytaring va `plan` toza ekanini ko'rsating. Xulosa: state'siz Terraform nimani bilmaydi?

13. **Saved plan.** `terraform plan -out=app.tfplan`, `terraform show app.tfplan`. `apply` qilishdan oldin boshqa terminalda oddiy `apply` bilan boshqa o'zgarish kiriting, keyin saqlangan rejani qo'llang: xato matni nima? Bu himoya CI'da nima uchun kerak?

14. **Docker cleanup.** `terraform plan -destroy` ni o'qing, keyin `destroy`. `docker ps -a`, `docker network ls` va `docker images` bilan hech narsa qolmaganini tekshiring. `keep_locally` argumenti image taqdiriga qanday ta'sir qiladi?

### D. AWS

15. **Provider and identity.** `aws/` papkasida AWS provider'ni region va `default_tags` bilan sozlang. `data "aws_caller_identity"` va `data "aws_availability_zones"` dan output chiqaring va `aws sts get-caller-identity` bilan solishtiring. Bu `apply` nechta resurs yaratdi? Terraform credential'ni qayerdan oldi? Budget alert yoqilganini tekshirib, summasini yozing.

16. **Network.** VPC, bitta public subnet, internet gateway, route table va association yozing. CIDR'lar o'zgaruvchidan, subnet CIDR'i `cidrsubnet()` bilan hisoblansin. `plan` da nechta resurs? `apply` dan keyin AWS CLI bilan VPC va route'ni tekshiring. Cloud modulida shu qadamlar nechta CLI buyrug'i edi?

17. **Security group.** Security group va alohida qoida resurslari: SSH faqat sizning IP'ingizdan (`/32`, o'zgaruvchi orqali, validation bilan), HTTP hammadan, egress hammaga. Avval egress qoidasisiz `apply` qilib, konsol yoki CLI'da chiquvchi qoidalar ro'yxatini ko'ring va qo'lda yaratilgan security group bilan farqini yozing.

18. **AMI data source.** `data "aws_ami"` bilan eng yangi Ubuntu 24.04 AMI'sini toping, ID va nomini output qiling. `most_recent = true` ning yon ta'siri nima: ertaga yangi AMI chiqsa mavjud instans rejasida nima ko'rinadi? Bunga qarshi ikki yechimni yozing.

19. **EC2 instance.** `aws_key_pair` (laboratoriya public kalitingiz) va `aws_instance`: eng kichik tip, public subnet, security group, `user_data` da nginx o'rnatadigan cloud-init. Public IP'ni output qiling. `ssh` bilan kiring va `curl http://<IP>` javob berishini ko'rsating. `user_data` ishlamagan bo'lsa qaysi log'dan sababini topasiz?

20. **Plan reading on AWS.** Faqat `plan` qiling (apply'siz) va har o'zgarish uchun belgi va sababni yozing: instansga teg qo'shish; `instance_type` ni o'zgartirish; `user_data` ni o'zgartirish; subnet'ning `availability_zone` ini o'zgartirish. Qaysi biri eng xavfli va nima uchun? Tegni `apply` qilib in-place update'ni tasdiqlang.

21. **S3 bucket.** Global noyob nomli (akkaunt ID'si qo'shilgan) bucket, versioning yoqilgan, public access to'liq bloklangan. AWS CLI bilan fayl yuklang, keyin `terraform destroy -target=aws_s3_bucket.<name>` qilib xatoni o'qing. `force_destroy` bilan hal qiling. `-target` nima uchun kundalik ishda tavsiya etilmaydi?

22. **Destroy and verify.** `terraform plan -destroy` ni o'qing, `destroy` qiling. 10-bo'limdagi tekshiruv buyruqlarining har birini ishga tushirib chiqishini yozing. Butun AWS qismi `apply` dan `destroy` gacha qancha vaqt oldi? 1-darsdagi "Pain summary" jadvaliga Terraform ustunini qo'shing.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza, ikkala papkada `terraform fmt -check -recursive` va `terraform validate` toza.
2. Repoda `terraform.tfstate`, `.terraform/`, plan fayli va kalit yo'q; `.terraform.lock.hcl` bor.
3. AWS resurslari o'chirilgan, 10-bo'limdagi tekshiruv chiqishi `README.md` da.
4. Docker resurslari o'chirilgan.
5. Menga xabar bering, `README.md` va `.tf` fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `plan` qaysi uch narsani solishtiradi?
- `~` va `-/+` farqi nima, qaysi biri in-place yoki replace bo'lishini kim belgilaydi?
- State fayli qaysi uch vazifani bajaradi? U yo'qolsa resurslarga nima bo'ladi, Terraform'ga nima bo'ladi?
- Terraform resurslarni qaysi tartibda yaratadi va bu tartibni qayerdan biladi?
- `count` bilan yaratilgan ro'yxat o'rtasidan element olib tashlansa nima bo'ladi? `for_each` buni qanday yechadi?
- `terraform validate` nimani ushlay olmaydi?
- `.terraform.lock.hcl` nima uchun commit qilinadi, `.terraform/` esa yo'q?
- Terraform yaratgan security group konsolda yaratilganidan nimasi bilan farq qiladi?
- `terraform destroy` dan keyin nima uchun qo'shimcha tekshiruv kerak?
