# 4-dars: Terraform asoslari

Maqsad: Terraform (yoki OpenTofu) bilan resurslarni deklarativ yaratish, o'zgartirish va o'chirishni noldan o'rganish: core va provider qanday bo'lingan, `init`/`plan`/`apply`/`destroy` sikli ichida aslida nima sodir bo'ladi, HCL tili, resource va data source, variable/local/output, state fayli nimani saqlaydi, dependency graph, `count` va `for_each`, `lifecycle`, `fmt`/`validate` va saqlangan reja. Avval lokal Docker provider bilan mexanizmlarni pulsiz o'zlashtirasiz, keyin cloud modulida qo'lda qurgan tarmoq va serverni (VPC, subnet, security group, EC2, S3) kod bilan qayta qurasiz. 1-darsdagi "state" va "removal problem" savollariga bu yerda amaliy javob olasiz. 5-dars shu kodni remote state, modullar va CI bilan jamoaviy ishga yaroqli qiladi.

Taxminiy vaqt: 8 kun (siz uchun). 1-kun: o'rnatish, 1–3 bo'limlar va "Birga bajaramiz". 2-kun: 4–6 bo'limlar va A guruh. 3-kun: 7–9 bo'limlar va B guruh. 4-kun: C guruh. 5-kun: 10-bo'lim va 15–17 vazifalar. 6-kun: 18–20 vazifalar. 7-kun: 21–22 vazifalar. 8-kun: ikkinchi mashinada `init` va lock fayl tekshiruvi, README'ni tartibga solish. Diqqatni quyidagilarga qarating: `plan` chiqishini o'qish (in-place update va replace farqi), state aynan nimani saqlaydi va yo'qolsa nima bo'ladi, `count` indeks siljishi, `(known after apply)` qayerdan keladi, AWS'da `destroy` dan keyingi tekshiruv.

Qanday o'qish kerak: har bo'limdagi misolni bo'sh vaqtinchalik papkada o'zingiz terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi ID, hash, versiya va vaqtlar farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan. Versiya raqamlari darsda namuna sifatida berilgan: haqiqiy versiyani registry sahifasidan va o'z lock faylingizdan o'qiysiz (3-bo'lim). Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Terraform serverga kirmaydi, u API bilan gaplashadi. Shuning uchun bu darsda `lab` VM kerak emas: CLI host'da ishlaydi, resurslar esa uch joyda paydo bo'ladi.

| Joy | Nima ishlaydi | Qaysi vazifalar |
|-----|---------------|-----------------|
| Host (Zorin yoki macOS) | `terraform` (yoki `tofu`) CLI, `.tf` fayllar, lokal state fayli | hammasi |
| Lokal Docker | Terraform yaratadigan konteyner, image va network'lar | A, B, C guruhlar (bepul) |
| AWS akkaunt | VPC, subnet, security group, EC2, S3 | D guruh (pullik bo'lishi mumkin) |

O'rnatish (hujjat: https://developer.hashicorp.com/terraform/install). Zorin'da HashiCorp'ning rasmiy apt repozitoriysidan, paket arxitekturasi `amd64`:

```
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
```

Zorin'da repo qatoridagi kod nomi Ubuntu asosiniki (`noble`) bo'lishi kerak, buyruq uni `/etc/os-release` dagi `UBUNTU_CODENAME` dan oladi (linux 1-dars). macOS'da Homebrew orqali, HashiCorp'ning o'z tap'idan (tap bu Homebrew'ga qo'shimcha paket manbai), binary `arm64`:

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

`terraform version` birinchi qatorda versiyani, ikkinchisida platformani ko'rsatadi: Zorin'da `on linux_amd64`, Mac'da `on darwin_arm64`. Bu ikki so'z 3-bo'limda lock fayl uchun kerak bo'ladi.

OpenTofu (iac 1-dars: Terraform'ning ochiq litsenziyali fork'i) tanlasangiz: macOS'da `brew install opentofu`, Zorin uchun https://opentofu.org/docs/intro/install/ dagi yo'riqnoma. Keyin barcha buyruqlarda `terraform` o'rniga `tofu` yoziladi, `.tf` fayllar bir xil. Repodagi tekshiruv ham buni biladi: `make check TF=tofu`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Provider binary'lari `linux_amd64`. Docker provider `unix:///var/run/docker.sock` bilan gaplashadi. Image'lar `amd64`. AWS CLI profili shu mashinaniki. Uydagi IP'dan boshqa public IP. |
| macOS (uy) | Provider binary'lari `darwin_arm64`. Docker Desktop socket'i foydalanuvchi uy papkasida bo'lishi mumkin, `/var/run/docker.sock` faqat tegishli sozlama yoqilgan bo'lsa bor: faol manzilni `docker context ls` ning `DOCKER ENDPOINT` ustunidan oling. Image'lar `arm64`. Publish qilingan portlar `localhost` da ishlaydi, konteyner IP'lari host'dan ko'rinmaydi (docker 3-dars). AWS CLI profili alohida sozlanadi. |

Ikki mashina qoidalari:

- **State ko'chmaydi.** Bu darsda state lokal: `terraform.tfstate` bitta mashinaning ish papkasida yotadi va hech qachon commit qilinmaydi (`make secrets` tekshiruvi `*.tfstate`, `*.tfstate.backup` va `*.tfvars` ni rad etadi). Oqibati: ofisda yaratilgan resursni uydan boshqarib bo'lmaydi (5-darsdagi remote state'gacha). Shuning uchun har mashg'ulot `apply` qilingan o'sha mashinada `terraform destroy` va tekshiruv buyrug'i bilan tugaydi. Docker resurslari baribir faqat o'sha mashinaning Docker'ida mavjud.
- **Git orqali ko'chadi**: `.tf` fayllar va `.terraform.lock.hcl`. **Ko'chmaydi**: `.terraform/`, state, plan fayli, `*.tfvars`, AWS kalitlari. Ikkinchi mashinada `git pull` dan keyin `terraform init` qaytadan bajariladi.
- Ish papkasidagi `.gitignore` ga darhol qo'shing: `.terraform/`, `*.tfstate`, `*.tfstate.*`, `*.tfplan`, `*.tfvars`.
- Docker resurslariga `iac-` prefiksi bilan nom bering va ularni faqat `terraform destroy` bilan o'chiring, `docker system prune` bilan emas: prune boshqa darslarning resurslarini ham olib ketadi va Terraform state'ini haqiqatdan uzib qo'yadi.
- **AWS** (D guruh): boshlashdan oldin budget alert yoqilganini tekshiring (cloud 2-dars), `aws sts get-caller-identity` to'g'ri akkauntni ko'rsatsin. Bitta region, eng kichik instans tipi, NAT gateway va load balancer yo'q, hamma resursda `Project = iac-lab` tegi. Har mashg'ulot oxirida `terraform destroy` va 10-bo'limdagi tekshiruv majburiy.

---

## 1. Terraform qanday ishlaydi

### Core va provider

Terraform bu infratuzilmani kod sifatida tasvirlab, uni API chaqiruvlari orqali yaratadigan provisioning asbobi (iac 1-dars: provisioning bu resursning o'zini yaratish, configuration management esa uning ichini sozlash). U ikki qismdan iborat:

- **Core** bu `terraform` binary'sining o'zi. U `.tf` fayllarni o'qiydi, resurslar grafini quradi, state bilan solishtirib rejani hisoblaydi. Core AWS yoki Docker haqida hech narsa bilmaydi.
- **Provider** bu alohida binary, plugin. U bitta aniq API'ni biladi: `hashicorp/aws` AWS API'sini, `kreuzwerker/docker` Docker daemon API'sini. Core provider'ni alohida jarayon sifatida ishga tushiradi va u bilan lokal RPC (jarayonlar orasidagi chaqiruv) orqali gaplashadi.

Core "shu argumentlar bilan `aws_vpc` yarat" deydi, provider buni `CreateVpc` API chaqiruviga aylantiradi, javobdagi ID va atributlarni core'ga qaytaradi, core ularni state'ga yozadi. Har resurs turi ortida provider'ning to'rt amali turadi: create, read, update, delete. Cloud modulida `aws ec2 create-vpc` deb qo'lda bergan buyruqlaringizni endi provider beradi.

Node tajribasiga haqiqiy o'xshashlik: core paket menejeri va runtime, provider esa `npm install` yuklab beradigan dependency. Farqi: provider JS moduli emas, platformaga bog'liq tayyor binary.

### Ish sikli: to'rt buyruq ichida nima bo'ladi

| Buyruq | Ichida nima bo'ladi |
|--------|---------------------|
| `terraform init` | `required_providers` ni o'qiydi, provider binary'larini registry'dan `.terraform/` ga yuklaydi, tanlangan versiya va checksum'larni `.terraform.lock.hcl` ga yozadi, backend'ni (state saqlanadigan joy, hozircha lokal fayl) sozlaydi. Resurslarga tegmaydi. |
| `terraform plan` | 1) state'dagi har resursni provider orqali API'dan qayta o'qiydi (refresh); 2) uch narsani solishtiradi: kod (kerakli holat), state (oxirgi ma'lum holat), real holat; 3) graf bo'yicha tartiblangan amallar ro'yxatini chiqaradi. Hech narsani o'zgartirmaydi. |
| `terraform apply` | yangi reja tuzadi, ko'rsatadi, `yes` dan keyin amallarni graf tartibida bajaradi va har amaldan keyin natijani state'ga yozadi. |
| `terraform destroy` | state'dagi barcha resurslarni teskari tartibda o'chiradi (`terraform apply -destroy` ning qisqa nomi). |

Bu iac 1-darsdagi declarative modelning aniq ko'rinishi: siz "nima bo'lishi kerak" ni yozasiz, "nima qilish kerak" ni `plan` hisoblaydi. React bilan o'xshashlik bu yerda haqiqiy: komponent kerakli UI'ni tasvirlaydi, reconciliation oldingi daraxt bilan solishtirib DOM amallarini hisoblaydi. Terraform'da "oldingi daraxt" state, "DOM" esa real infratuzilma. Muhim farq: DOM'ni faqat React o'zgartiradi, infratuzilmani esa konsoldan istalgan odam o'zgartirishi mumkin, shuning uchun `plan` har safar real holatni qayta o'qiydi.

### Misol: plan chiqishini o'qish

Bo'sh papkada `main.tf` (bu ikki provider na Docker, na cloud talab qiladi, shuning uchun mexanizmni ko'rsatishga qulay):

```
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}

resource "random_pet" "name" {
  length = 2
}

resource "local_file" "note" {
  filename = "${path.module}/out/note.txt"
  content  = "owner: ${random_pet.name.id}"
}
```

`random_pet` tasodifiy "sifat-hayvon" nomini generatsiya qilib state'da saqlaydigan resurs, `local_file` diskda fayl yaratadi. `terraform init` dan keyin:

```
$ terraform plan

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # local_file.note will be created
  + resource "local_file" "note" {
      + content              = (known after apply)
      + directory_permission = "0777"
      + file_permission      = "0777"
      + filename             = "./out/note.txt"
      + id                   = (known after apply)
      ...
    }

  # random_pet.name will be created
  + resource "random_pet" "name" {
      + id        = (known after apply)
      + length    = 2
      + separator = "-"
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

Qatorma-qator:

- `Resource actions are indicated with the following symbols` ostida shu rejada uchraydigan belgilar ro'yxati. Bu yerda faqat `+ create`.
- `# local_file.note will be created` har resurs oldidagi izoh: manzil va amal. Shoshganda ham shu qatorlarni o'qing.
- `+ filename = "./out/note.txt"` siz yozgan argument; `+ file_permission = "0777"` siz yozmagan, provider'ning standart qiymati.
- `+ content = (known after apply)`: qiymat hozir noma'lum, chunki u `random_pet.name.id` ga bog'liq, u esa faqat resurs yaratilganda paydo bo'ladi. `id` ham shunday. Cloud'da bu ID, ARN va IP manzillar bo'ladi.
- `Plan: 2 to add, 0 to change, 0 to destroy.` yakuniy hisob. `apply` dan oldin shu uch sonni kutganingiz bilan solishtiring: "bitta teg qo'shdim" deganda `1 to change` chiqishi kerak, `3 to destroy` emas.

Barcha belgilar:

| Belgi | Izoh qatori | Ma'no |
|-------|-------------|-------|
| `+` | `will be created` | yaratiladi |
| `-` | `will be destroyed` | o'chiriladi |
| `~` | `will be updated in-place` | mavjud resurs o'zgartiriladi, ID o'sha |
| `-/+` | `must be replaced` | o'chirib qayta yaratiladi; sabab bo'lgan atribut yonida `# forces replacement` |
| `+/-` | `must be replaced` | avval yangisi yaratiladi, keyin eskisi o'chiriladi (`create_before_destroy`, 8-bo'lim) |
| `<=` | `will be read during apply` | data source `apply` paytida o'qiladi |

In-place yoki replace ekanini provider belgilaydi: API atributni mavjud resursda o'zgartirishga ruxsat bermasa (masalan EC2 instansning AMI'si, konteynerning image'i), yagona yo'l qayta yaratish. Yuqoridagi `local_file` da `content` shunday atribut: uni o'zgartirsangiz `-/+` chiqadi ("Birga bajaramiz" da ko'rasiz). `-/+` ko'rsangiz to'xtab o'qing: bu ma'lumot yo'qolishi va downtime bo'lishi mumkin.

### Real ishda qachon kerak

- Har pull request'da `plan` chiqishi review qilinadi: kod diff'i "nima yozildi" ni, plan esa "infratuzilmada nima bo'ladi" ni ko'rsatadi.
- `Plan:` qatoridagi `to destroy` soni noldan katta bo'lsa, sababini bilmaguncha `apply` qilinmaydi.
- Xato chiqqanda birinchi savol: bu core xatosimi (sintaksis, havola) yoki provider xatosi (API rad etdi: ruxsat yo'q, nom band, limit).

### Nima uchun shunday

Core va provider ajratilgani uchun bitta asbob va bitta til minglab API'lar bilan ishlaydi, va provider core'dan mustaqil versiyalanadi. Muqobili CloudFormation kabi bitta cloud'ga bog'langan asbob: u chuqurroq integratsiya beradi, lekin faqat AWS uchun. `plan` va `apply` ning ajratilishi esa xavfsizlik uchun: infratuzilmadagi xato `git revert` bilan qaytmaydi, shuning uchun o'zgarish bajarilishidan oldin odam ko'zidan o'tadi.

## 2. HCL

### Blok, argument, ifoda

HCL (HashiCorp Configuration Language) bu Terraform konfiguratsiyasi yoziladigan til. U uch narsadan iborat:

```
resource "random_pet" "name" {
  length = var.pet_length
}
```

- **Blok**: tur (`resource`), label'lar (`"random_pet"`, `"name"`), tana `{ }`. Blok turlari: `terraform`, `provider`, `resource`, `data`, `variable`, `locals`, `output`, `module`. Ba'zi resurslarda ichki bloklar ham bo'ladi (masalan `lifecycle { }`).
- **Argument**: `nom = ifoda`. Chap tomonda nom, o'ng tomonda qiymat hisoblanadigan ifoda.
- **Ifoda**: literal (`2`, `"dev"`, `true`), havola (`var.env`), funksiya chaqiruvi, shart, `for`.

Resurs manzili `<type>.<name>`: `random_pet.name`. Ikkinchi label faqat Terraform ichidagi nom, real resurs nomi emas: real nom resursning argumenti bilan beriladi.

### Havolalar

| Havola | Nimaga |
|--------|--------|
| `random_pet.name.id` | resursning atributi |
| `data.aws_ami.ubuntu.id` | data source'ning atributi (4-bo'lim) |
| `var.env` | variable qiymati (5-bo'lim) |
| `local.name_prefix` | local qiymat |
| `module.network.vpc_id` | modul output'i (5-dars) |
| `path.module` | joriy modul papkasining yo'li |

Havola faqat qiymat olish emas: u bog'liqlik ham yaratadi (7-bo'lim).

### Tiplar va string template

Tiplar: `string`, `number`, `bool`, `list(T)` (tartibli), `set(T)` (tartibsiz, noyob), `map(T)` (kalit va qiymat), `object({...})` (har maydonining o'z tipi bor). TypeScript'dagi `string[]`, `Set<string>`, `Record<string, T>` va obyekt tipiga mos keladi, lekin HCL'da tip faqat variable e'lonida yoziladi, qolgan joyda Terraform uni o'zi chiqaradi.

String ichida interpolatsiya JS template literal'iga o'xshaydi, faqat backtick emas oddiy qo'shtirnoq: `"app-${var.env}"`. Ko'p qatorli matn heredoc bilan yoziladi (`<<-EOT` ... `EOT`).

### Ifodalar, funksiyalar va console

- Shart: `var.env == "prod" ? 3 : 1`.
- `for`: `[for s in var.names : upper(s)]` (list qaytaradi), `{for s in var.names : s => length(s)}` (map qaytaradi).
- Funksiyalar faqat o'rnatilgan, o'zingiz funksiya yoza olmaysiz: `length`, `upper`, `merge`, `lookup`, `toset`, `cidrsubnet`, `file`, `templatefile`, `jsonencode`.

Ifodani resurs yaratmasdan sinash uchun `terraform console`:

```
$ terraform console
> upper("dev")
"DEV"
> [for s in ["a", "b"] : "iac-${s}"]
[
  "iac-a",
  "iac-b",
]
> cidrsubnet("10.20.0.0/16", 8, 3)
"10.20.3.0/24"
```

Oxirgi misol: `cidrsubnet(prefix, newbits, netnum)` berilgan tarmoq prefiksiga `newbits` bit qo'shadi (`/16` + 8 = `/24`) va shu o'lchamdagi `netnum`-chi tarmoqni qaytaradi (CIDR: network 3-dars). Subnet manzillarini qo'lda hisoblamaslik uchun ishlatiladi.

### Fayllar

Papkadagi barcha `*.tf` fayllar bitta **modul** (birga o'qiladigan konfiguratsiya birligi) sifatida o'qiladi. Fayl nomlari va bloklar tartibi ahamiyatsiz. Odat: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`. Ichki papkalar avtomatik o'qilmaydi.

### Real ishda qachon kerak

- Notanish konfiguratsiyani o'qiganda avval blok turlarini ajratasiz: nima yaratiladi (`resource`), nima o'qiladi (`data`), nima kirish parametri (`variable`).
- `terraform console` murakkab `for` yoki `cidrsubnet` ifodasini `plan` kutmasdan tekshirish uchun.

### Nima uchun shunday

HCL ataylab dasturlash tili emas: sikl va shart faqat qiymat hisoblash uchun, bajarilish tartibini siz emas, graf belgilaydi. Shu cheklov tufayli Terraform konfiguratsiyani ishga tushirmasdan to'liq tahlil qilib, reja tuza oladi. JSON yoki YAML tanlanmagan, chunki ularda havola, izoh va ifoda yo'q. Muqobil yondashuv Pulumi (iac 1-dars): u yerda infratuzilma TypeScript yoki Python'da yoziladi, evaziga istalgan kod bajarilishi mumkin va "reja" ni oldindan ko'rish qiyinlashadi.

## 3. Provider, versiyalar va lock fayl

### required_providers va provider bloki

```
terraform {
  required_version = ">= 1.6"   # illustrative value

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"        # illustrative value, check the registry page
    }
  }
}

provider "docker" {
  host = var.docker_host
}
```

- `source` registry manzili: to'liq shakli `registry.terraform.io/kreuzwerker/docker`. `hashicorp/` bilan boshlanadiganlari HashiCorp'niki, qolganlari hamjamiyat yoki vendor provider'i.
- `version` cheklov. `~> 3.0` "3.x ichida istalgani, lekin 4.0 emas" degani, `~> 3.2.1` esa "3.2.x". npm'dagi `^` va `~` ga o'xshash g'oya. Joriy major versiyani bilish uchun registry'dagi provider sahifasini oching (`https://registry.terraform.io/providers/kreuzwerker/docker/latest`): sarlavhada oxirgi versiya, "Use Provider" tugmasi ostida tayyor `required_providers` bloki bor. Yuqoridagi raqamlar namuna.
- `provider` bloki sozlamalar: endpoint, region, credential manbai. Credential'ning o'zi bu yerga yozilmaydi.

Docker provider'ning `host` argumenti daemon manzili. Zorin'da bu `unix:///var/run/docker.sock`. macOS'da manzilni taxmin qilmang, so'rang:

```
$ docker context ls
NAME              DESCRIPTION   DOCKER ENDPOINT                 ERROR
<context> *       <...>         unix://<path>/docker.sock
```

Yulduzcha faol context'ni, `DOCKER ENDPOINT` ustuni esa provider'ga kerakli manzilni ko'rsatadi. Manzil mashinaga bog'liq bo'lgani uchun uni `.tf` ga qattiq yozmang: yo variable qiling, yo `host` ni umuman yozmay shell'da `DOCKER_HOST` muhit o'zgaruvchisini bering, provider uni o'qiydi.

### init nima yaratadi

```
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/random versions matching "~> 3.0"...
- Installing hashicorp/random v<X.Y.Z>...
- Installed hashicorp/random v<X.Y.Z> (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
...

Terraform has been successfully initialized!
```

`Finding ... versions matching` cheklovga mos eng yangi versiya qidirilmoqda; `Installing` va `Installed` binary yuklandi va imzosi tekshirildi; keyingi xatboshi lock fayl yaratilganini va uni commit qilish kerakligini aytadi. Natijada ikki narsa paydo bo'ladi:

| Narsa | Ichida | Node o'xshashi | Commit |
|-------|--------|----------------|--------|
| `.terraform/` | yuklangan provider binary'lari (`providers/registry.terraform.io/<ns>/<name>/<versiya>/<platforma>/`) | `node_modules/` | yo'q |
| `.terraform.lock.hcl` | tanlangan aniq versiya va checksum'lar | `package-lock.json` | ha |

Lock fayl ichi:

```
provider "registry.terraform.io/hashicorp/random" {
  version     = "<X.Y.Z>"
  constraints = "~> 3.0"
  hashes = [
    "h1:<...>",
    "zh:<...>",
  ]
}
```

`version` aynan tanlangan versiya: keyingi `init` cheklovga mos yangisi chiqqan bo'lsa ham shuni o'rnatadi. `constraints` siz yozgan cheklov. `hashes` provider paketining ruxsat etilgan checksum'lari: yuklangan binary shulardan biriga mos kelmasa `init` to'xtaydi (supply chain himoyasi). Versiyani yangilash ongli harakat: `terraform init -upgrade`.

### Ikki platforma va lock fayl

Provider binary'si platformaga bog'liq: Zorin `linux_amd64` paketini, Mac `darwin_arm64` paketini yuklaydi, ularning checksum'i har xil. `init` lock faylga avvalo o'zi ishlagan platformaning hash'ini yozadi. Oqibatda ikkinchi mashinada ikki xil noqulaylik chiqishi mumkin: `init` lock faylga yangi hash qo'shib uni o'zgartiradi (har mashina almashganda keraksiz git diff), yoki provider lokal cache yoki mirror'dan o'rnatilganda checksum lock fayldagi yozuvlarga mos kelmagani haqida xato beradi. Ikkalasining yechimi bitta: lock faylni bir marta ikkala platforma uchun to'ldirib commit qilish.

```
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

Bu buyruq ko'rsatilgan platformalar uchun paketlarni yuklab, checksum'larini lock faylga yozadi. Provider qo'shganingizda yoki versiyani yangilaganingizda takrorlang.

### Real ishda qachon kerak

- CI runner (odatda `linux_amd64`) va dasturchi Mac'i (`darwin_arm64`) bitta lock fayl bilan ishlashi uchun `providers lock` deyarli har jamoada kerak.
- Provider'ning yangi major versiyasi argumentlarni o'zgartirishi mumkin: versiya cheklovi va lock fayl "kecha ishlagan kod bugun buzildi" holatining oldini oladi.

### Nima uchun shunday

`package-lock.json` bilan sabab bir xil: cheklov (`~> 3.0`) niyatni, lock esa aniq natijani yozadi, shunda ikki mashina va CI bir xil provider bilan ishlaydi. Farqi: npm paketi asosan platformadan mustaqil JS, provider esa har platforma uchun alohida binary, shuning uchun lock faylda bitta versiyaga bir nechta hash to'g'ri keladi. Provider'lar core ichiga qo'shib yuborilmagan, chunki ular minglab va har biri o'z tezligida chiqadi.

## 4. Resource va data source

### Ikki xil blok

- `resource` Terraform boshqaradigan obyekt: uni yaratadi, o'zgartiradi, o'chiradi va state'da saqlaydi.
- `data` (data source) mavjud narsani faqat o'qiydi va hech narsa yaratmaydi. U provider'ning faqat "read" amalini chaqiradi.

```
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```

`aws_caller_identity` hozirgi credential qaysi akkauntga tegishli ekanini so'raydi (`aws sts get-caller-identity` ning o'zi, cloud 2-dars). Havola `data.` prefiksi bilan yoziladi. Bunday konfiguratsiyada `apply` hech qanday resurs yaratmaydi: `Plan:` qatori o'rniga faqat output o'zgarishi ko'rinadi.

### Argument va atribut

Har resurs turida ikki xil maydon bor. **Argument** ni siz yozasiz (`length = 2`). **Atribut** ni provider qaytaradi (`id`, `arn`, `public_ip`), u faqat o'qiladi. Qaysi argument majburiy, qaysi atribut qaytadi va qaysi argument o'zgarsa replace bo'ladi, hammasi registry'dagi resurs sahifasida: "Argument Reference" va "Attribute Reference" bo'limlari. Bu sahifa sizning asosiy ma'lumotnomangiz, argument nomlarini yoddan yozmang.

Data source qachon o'qiladi: argumentlari `plan` paytida ma'lum bo'lsa, `plan` ning o'zida o'qiladi. Argumenti hali yaratilmagan resursga bog'liq bo'lsa, o'qish `apply` ga qoldiriladi va rejada `<=` belgisi bilan chiqadi.

### Real ishda qachon kerak

- Boshqa jamoa yoki boshqa konfiguratsiya yaratgan narsaga ulanish: mavjud VPC, DNS zona, AMI.
- "Eng yangi" yoki "hozirgi" degan qiymatni qo'lda yozmaslik: akkaunt ID, regiondagi availability zone'lar ro'yxati, AMI ID (AMI ID har regionda boshqa va vaqt o'tishi bilan eskiradi, shuning uchun u hech qachon literal yozilmaydi).

### Nima uchun shunday

Data source bo'lmasa, tashqi qiymatlarni qo'lda nusxalab `.tf` ga yozish kerak bo'lardi, ular esa eskiradi va regionga bog'liq. Narxi: data source natijasi vaqt o'tishi bilan o'zgarishi mumkin, demak siz hech narsani o'zgartirmagan bo'lsangiz ham reja o'zgaradi. Buni qachon istash, qachon istamaslikni o'zingiz hal qilasiz.

## 5. Variable, local, output

### Uch xil qiymat

```
variable "env" {
  type        = string
  description = "Environment name"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env must be one of: dev, stage, prod."
  }
}

locals {
  name_prefix = "iac-${var.env}"
}

output "prefix" {
  value       = local.name_prefix
  description = "Common prefix for resource names"
}
```

Modulni funksiya deb tasavvur qilsangiz: `variable` uning parametri, `locals` ichki `const`, `output` esa qaytaradigan qiymati.

- `variable`: `type` qiymat tipini cheklaydi, `default` bo'lmasa o'zgaruvchi majburiy (berilmasa Terraform interaktiv so'raydi), `validation` bloki qo'shimcha shartni tekshiradi va buzilsa `error_message` ni chiqaradi. `sensitive = true` qiymatni CLI chiqishida `(sensitive value)` deb yashiradi.
- `locals`: hisoblangan ichki qiymatlar, takrorni yo'qotadi. Tashqaridan berib bo'lmaydi.
- `output`: `apply` oxirida `Outputs:` ostida chiqadi va state'da saqlanadi. `terraform output` hammasini, `terraform output -raw prefix` bitta qiymatni qo'shtirnoqsiz (skript uchun), `terraform output -json` mashina uchun beradi.

### Qiymat qayerdan keladi

Variable qiymati manbalari, pastdan yuqoriga (keyingisi oldingisini yopadi):

| Tartib | Manba | Misol |
|--------|-------|-------|
| 1 | `default` | `default = "dev"` |
| 2 | muhit o'zgaruvchisi | `export TF_VAR_env=stage` |
| 3 | `terraform.tfvars` fayli | `env = "stage"` |
| 4 | `*.auto.tfvars` fayllari (alifbo tartibida) | `a.auto.tfvars` |
| 5 | `-var` va `-var-file` (yozilgan tartibda) | `terraform plan -var env=prod` |

`.tfvars` fayli faqat `nom = qiymat` qatorlaridan iborat. Bu repoda `*.tfvars` commit qilinmaydi (`make secrets`), chunki amalda ularga secret tushib qoladi. Mashinaga xos qiymatlar (Docker socket manzili, sizning IP) uchun `TF_VAR_` yoki lokal `.tfvars` qulay.

### sensitive nimani yashiradi, nimani yo'q

`sensitive = true` faqat terminal chiqishiga ta'sir qiladi. State faylida qiymat ochiq matnda turadi (6-bo'lim). Sensitive qiymatga tayangan output ham `sensitive = true` deb belgilanishi shart, aks holda Terraform xato beradi.

### Real ishda qachon kerak

- Bitta kod, turli muhit: dev va prod faqat variable qiymatlari bilan farq qiladi (5-dars).
- Output boshqa asbobga ko'prik: Terraform yaratgan server IP'si Ansible inventory'siga yoki CI qadamiga `terraform output -raw` orqali uzatiladi.

### Nima uchun shunday

Qiymat manbalarining ko'p qavatli tartibi Ansible'dagi o'zgaruvchi precedence bilan bir xil ehtiyojdan kelgan (iac 2-dars): standart qiymat kodda, muhitga xosi faylda, bir martalik o'zgartirish buyruq qatorida. Variable tipi va validation xatoni API'ga yetmasdan, `plan` boshida ushlaydi: TypeScript tipi xatoni runtime'gacha ushlagani kabi.

## 6. State

### Fayl ichida nima bor

Birinchi `apply` dan keyin papkada `terraform.tfstate` paydo bo'ladi. State bu Terraform'ning "men nimani yaratganman va u hozir qanday" degan yozuvi (tushuncha: iac 1-dars), amalda JSON fayl:

```
{
  "version": 4,
  "terraform_version": "<X.Y.Z>",
  "serial": 3,
  "lineage": "<uuid>",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "random_pet",
      "name": "name",
      "instances": [{ "attributes": { "id": "<adjective>-<animal>", "length": 2, "separator": "-" } }]
    }
  ]
}
```

| Maydon | Ma'no |
|--------|-------|
| `serial` | state har o'zgarib yozilganda ortadigan hisoblagich |
| `lineage` | state yaratilganda berilgan noyob ID, boshqa state bilan adashtirmaslik uchun |
| `outputs` | output qiymatlari |
| `resources[].mode` | `managed` (resource) yoki `data` (data source) |
| `resources[].type` va `name` | koddagi manzil |
| `instances[].attributes` | resursning **barcha** atributlari: siz yozganlari ham, provider qaytarganlari ham |

State uch vazifani bajaradi: (1) koddagi manzilni real ID bilan bog'laydi (`aws_instance.web` va `i-<...>`); (2) "nimani men yaratganman" ni eslab qoladi, shunda koddan olib tashlangan resursni o'chira oladi (iac 1-darsdagi removal problem'ning yechimi); (3) resurslar orasidagi bog'liqlikni saqlaydi, o'chirish tartibi uchun.

Yonida `terraform.tfstate.backup` ham bo'ladi: bu oldingi state nusxasi.

### Nima uchun ichida secret ochiq turadi

Provider resursning hamma atributini qaytaradi va core ularni keyingi solishtirish uchun saqlashi kerak. Ma'lumotlar bazasi paroli, generatsiya qilingan kalit, `sensitive` variable qiymati: hammasi `attributes` ichida ochiq matnda. Shuning uchun state secret kabi saqlanadi va hech qachon commit qilinmaydi.

### State'ni ko'rish

```
$ terraform state list
local_file.note
random_pet.name
```

`state list` manzillar ro'yxati, `state show <address>` bitta resursning saqlangan atributlari (HCL ko'rinishida, lekin bu kod emas, state'dagi nusxa). `terraform show` butun state'ni chiqaradi. Faylni qo'lda tahrirlamang: state ustidagi amallar (`mv`, `rm`, `import`) 5-darsda.

### State yo'qolsa

Resurslar joyida qoladi, lekin Terraform ularni "tanimaydi": manzil va ID orasidagi bog' yo'q. Keyingi `plan` hammasini qaytadan yaratishni taklif qiladi. Natija resurs turiga bog'liq: nomi noyob bo'lishi shart bo'lgan resursda nom to'qnashuvi xatosi, qolganlarida esa jimgina ikkinchi nusxa (va ikki barobar xarajat). Shuning uchun lokal state faqat o'rganish uchun, jamoada remote backend (5-dars).

### Drift

Drift bu real holatning state va koddan uzoqlashishi (iac 1-dars), masalan kimdir resursni konsoldan o'zgartirgan yoki o'chirgan. State Terraform'ning haqiqat haqidagi tasavvuri, haqiqatning o'zi emas: drift faqat keyingi `plan` paytidagi refresh'da ko'rinadi. Oddiy `plan` drift'ni topib, kodga qaytaradigan amalni taklif qiladi. `terraform plan -refresh-only` esa faqat "real holat state'dan nimasi bilan farq qiladi" ni ko'rsatadi va `apply -refresh-only` state'ni real holatga moslaydi, resursga tegmaydi.

### Real ishda qachon kerak

- "Bu resursni kim yaratgan, Terraform'mi?" degan savolga `terraform state list` javob beradi.
- Incident paytida konsoldan qilingan tezkor tuzatish keyingi `plan` da drift bo'lib chiqadi: yo kodga ko'chiriladi, yo `apply` uni qaytarib yuboradi.

### Nima uchun shunday

Muqobili state'siz ishlash: har safar cloud'dagi hamma resursni o'qib, teg yoki nom bo'yicha "meniki" ni topish. Bu sekin, hamma API'da teg yo'q va koddan o'chirilgan resursni topib bo'lmaydi. Ansible state saqlamaydi va shu sababli "olib tashlangan narsani o'chirish" ni o'zi bilmaydi (iac 2-dars). State'ning narxi: u yo'qolishi, eskirishi va secret saqlashi mumkin bo'lgan qo'shimcha fayl. 5-dars shu narxni boshqarishga bag'ishlangan.

## 7. Dependency graph

### Tartibni graf belgilaydi

Terraform resurslarni faylda yozilgan tartibda emas, bog'liqlik grafi bo'yicha yaratadi. Graf bu tugunlari resurslar, qirralari "A uchun avval B kerak" degan munosabat bo'lgan tuzilma. Bir resurs boshqasining atributiga havola qilsa, **yashirin bog'liqlik** (implicit dependency) hosil bo'ladi:

```
content = "owner: ${random_pet.name.id}"   # local_file.note depends on random_pet.name
```

Core barcha havolalarni yig'ib grafni quradi va uni bog'liqlik tartibida aylanib chiqadi: avval hech kimga bog'liq bo'lmaganlar, keyin ularga tayanganlar. O'zaro bog'liq bo'lmagan resurslar parallel yaratiladi (standart 10 ta bir vaqtda, `-parallelism=N` bilan o'zgaradi). O'chirish teskari tartibda. Ikki resurs bir-biriga havola qilsa Terraform `Cycle` xatosi bilan to'xtaydi.

Tartib `apply` log'ida ko'rinadi: `random_pet.name: Creation complete after 0s [id=<adjective>-<animal>]` qatori `local_file.note: Creating...` qatoridan oldin chiqadi, chunki faylga parolning emas, aynan shu nomning qiymati kerak va u faqat yaratilgandan keyin ma'lum. `terraform graph` grafni DOT formatida (Graphviz matn formati) chiqaradi. Aniq ko'rinishi versiyaga bog'liq, lekin qirra har doim `"local_file.note" -> "random_pet.name"` shaklida: strelka "bog'liq" degani, ya'ni chapdagi o'ngdagidan keyin yaratiladi.

### depends_on

Ba'zan bog'liqlik bor, lekin uni ifodalaydigan havola yo'q: resurs boshqasining hech bir atributini ishlatmaydi, ammo u tayyor bo'lmaguncha ishlamaydi. Shunda bog'liqlik qo'lda yoziladi:

```
depends_on = [aws_internet_gateway.main]
```

Bu oxirgi chora. Ko'pincha havola yetarli, ortiqcha `depends_on` esa rejani keraksiz konservativ qiladi: bog'langan resurs o'zgarsa, Terraform bunisining qiymatlarini ham "noma'lum" deb hisoblaydi.

### Real ishda qachon kerak

- ID yoki nomni string bilan qo'lda yozish o'rniga havola ishlatish: havola ham qiymat, ham tartib beradi. String yozilsa graf bog'liqlikni ko'rmaydi va resurslar noto'g'ri tartibda yoki parallel yaratiladi.
- `destroy` nima uchun "resurs band" deb to'xtaganini tushunish: ko'pincha graf bilmaydigan (qo'lda yaratilgan) bog'liq resurs bor.

### Nima uchun shunday

Bash skriptda tartibni siz belgilaysiz va u bitta chiziq bo'ylab ketadi. Graf esa tartibni koddagi faktlardan chiqaradi: parallel bajarish va to'g'ri teskari o'chirish tekin keladi, fayldagi bloklarni istalgancha ko'chirish mumkin. Webpack yoki `tsc` import'lardan modul grafini qurib, qurish tartibini o'zi topgani bilan bir xil g'oya.

## 8. Meta-argumentlar: count, for_each, lifecycle

Meta-argument bu provider'ga emas, core'ga tegishli va har qanday resursda ishlaydigan argument: `count`, `for_each`, `depends_on`, `provider`, `lifecycle`.

### count va for_each

Ikkalasi bitta blokdan bir nechta resurs nusxasi (instance) yaratadi, farqi nusxaning **kimligi** nimaga bog'langanida.

```
# var.envs is ["dev", "stage", "prod"]
resource "random_pet" "by_index" {
  count  = length(var.envs)
  prefix = var.envs[count.index]
}

resource "random_pet" "by_key" {
  for_each = toset(var.envs)
  prefix   = each.key
}
```

| | `count = N` | `for_each = set yoki map` |
|---|-------------|---------------------------|
| Manzil | `random_pet.by_index[0]`, `[1]`, `[2]` | `random_pet.by_key["dev"]`, `["stage"]`, `["prod"]` |
| Ichida | `count.index` | `each.key`, `each.value` |
| Kimlik | ro'yxatdagi o'rni | kalitning o'zi |
| Qachon | bir xil nusxalar yoki shartli resurs (`count = var.enabled ? 1 : 0`) | har elementning o'z kimligi bor |

`for_each` list qabul qilmaydi, shuning uchun `toset()` bilan set'ga aylantiriladi.

### Indeks siljishi

Ro'yxat boshidan `"dev"` ni olib tashlasak, state'dagi manzillar bilan yangi kod shunday solishtiriladi:

| Manzil | State'da | Yangi kodda | Reja |
|--------|----------|-------------|------|
| `by_index[0]` | dev | stage | o'zgartirish yoki replace |
| `by_index[1]` | stage | prod | o'zgartirish yoki replace |
| `by_index[2]` | prod | yo'q | o'chirish |
| `by_key["dev"]` | dev | yo'q | o'chirish |
| `by_key["stage"]` | stage | stage | tegilmaydi |
| `by_key["prod"]` | prod | prod | tegilmaydi |

Terraform manzilni solishtiradi, mazmunni emas. `count` da bitta element olib tashlandi, lekin undan keyingi hamma element boshqa manzilga "ko'chdi" va Terraform ularni o'zgargan deb ko'radi. Production'da bu serverlarning qayta yaratilishi. Bu React'dagi list `key` muammosining aynan o'zi: `key={index}` bilan ro'yxat boshidan element o'chirilsa, React qolgan hamma elementni o'zgargan deb hisoblaydi; barqaror `key={item.id}` bilan faqat bittasi o'chadi. `for_each` kaliti shu barqaror `key`.

### lifecycle

Resurs ichidagi `lifecycle { }` bloki core'ning shu resursga standart munosabatini o'zgartiradi:

```
resource "aws_db_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}
```

- `create_before_destroy = true`: replace'da standart tartib "o'chir, keyin yarat" (`-/+`), bu bilan "yarat, keyin o'chir" (`+/-`). Downtime'siz almashtirish uchun. Ikkala nusxa bir muddat birga yashaydi, shuning uchun noyob nom talab qiladigan resurslarda to'qnashuv beradi.
- `prevent_destroy = true`: shu resursni o'chirishni o'z ichiga olgan har qanday reja xato bilan to'xtaydi. Ma'lumotlar bazasi va state bucket uchun. Himoya kodda: blokni yoki resursni koddan butunlay olib tashlasangiz, himoya ham ketadi.
- `ignore_changes = [tags]`: sanab o'tilgan atributlardagi farq rejaga kirmaydi. Tashqi tizim o'zgartiradigan qiymatlar uchun (boshqa asbob qo'yadigan teglar, autoscaling o'zgartiradigan son). Suiiste'mol qilinsa haqiqiy drift yashirinadi.
- `replace_triggered_by = [<address>]`: ko'rsatilgan resurs o'zgarganda buni ham qayta yaratadi.

### Real ishda qachon kerak

- Ro'yxat yoki map'dan resurslar yaratishda standart tanlov `for_each`; `count` asosan "bor yoki yo'q" kaliti sifatida.
- `prevent_destroy` ma'lumot saqlaydigan har resursda; `create_before_destroy` foydalanuvchi trafigi kelib turgan resurslarda.

### Nima uchun shunday

`count` tarixan birinchi paydo bo'lgan va sodda, `for_each` aynan indeks siljishi muammosi tufayli keyin qo'shilgan. `lifecycle` esa Terraform'ning umumiy qoidasi ("farq bo'lsa tuzat, kerak bo'lsa qayta yarat") har resursga to'g'ri kelmasligining tan olinishi: ba'zi resurs uchun o'chirish halokat, ba'zisi uchun bir soniyalik uzilish ham qimmat.

## 9. fmt, validate, plan fayli

### fmt va validate

`terraform fmt` fayllarni kanonik formatga keltiradi: ikki bo'shliqli indent, ketma-ket argumentlarda `=` belgilari bir ustunda. Prettier'dan farqi: sozlamasi yo'q, uslub bitta. `terraform fmt -check -diff` hech narsani o'zgartirmaydi, format buzilgan fayl nomini va farqni chiqarib, noldan farqli exit code qaytaradi (CI uchun); `-recursive` ichki papkalarni ham qamraydi. Repodagi `make check` aynan `fmt -check -recursive` ni ishlatadi.

`terraform validate` konfiguratsiyaning ichki to'g'riligini tekshiradi: sintaksis, argument nomlari va tiplari, havolalar. U `init` dan keyin ishlaydi (provider sxemasi kerak), lekin API'ga murojaat qilmaydi va credential talab qilmaydi. Xato bo'lmasa javobi bitta qator: `Success! The configuration is valid.`

Xatolar uch bosqichda ushlanadi, va qaysi xato qaysi bosqichda chiqishini bilish debug vaqtini tejaydi:

| Bosqich | Nima biladi | Nimani ushlaydi |
|---------|-------------|-----------------|
| `validate` | faqat kod va provider sxemasi | sintaksis, noma'lum argument, mavjud bo'lmagan havola, tip xatosi |
| `plan` | qo'shimcha: variable qiymatlari, state, o'qilgan real holat | validation sharti, data source topilmasligi, credential yo'qligi |
| `apply` | API'ning haqiqiy javobi | band nom, ruxsat yo'qligi, limit, mavjud bo'lmagan tashqi obyekt |

### Saqlangan reja

Oddiy `apply` rejani o'zi qayta tuzadi, demak siz ko'rgan `plan` va bajarilgan amallar orasida farq bo'lishi mumkin. Buni yo'qotish uchun:

```
terraform plan -out=app.tfplan
terraform show app.tfplan
terraform apply app.tfplan
```

`-out` rejani binary faylga yozadi, `show` uni odam o'qiydigan shaklda chiqaradi, `apply <fayl>` aynan shu rejani tasdiq so'ramasdan bajaradi. Reja o'zi tuzilgan paytdagi state'ga bog'langan: orada state o'zgargan bo'lsa, Terraform rejani eskirgan deb rad etadi. Plan fayli ichida variable qiymatlari, jumladan secret'lar ochiq bo'lishi mumkin: u commit qilinmaydi.

Yana ikki foydali bayroq: `terraform plan -destroy` o'chirish rejasini oldindan ko'rsatadi; `terraform apply -replace=<address>` bitta resursni kod o'zgarmagan bo'lsa ham qayta yaratadi (masalan buzilgan server).

### Real ishda qachon kerak

- CI oqimi (5-dars): pull request'da `fmt -check`, `validate`, `plan -out`; merge'dan keyin aynan o'sha fayl `apply` qilinadi.
- `validate` credential'siz ishlagani uchun pre-commit hook'ga va tezkor tekshiruvga mos.

### Nima uchun shunday

Tekshiruvlar arzonidan qimmatiga qarab terilgan: `fmt` va `validate` soniyada va tarmoqsiz, `plan` API o'qishlari bilan, `apply` haqiqiy o'zgarish bilan. Saqlangan reja "review qilingan narsa aynan bajarilgan narsa" kafolatini beradi; busiz review bilan `apply` orasida kirgan begona o'zgarish ko'rilmagan amallarni keltirib chiqarishi mumkin.

## 10. AWS: tarmoq, server, bucket

D guruhda cloud 3-darsda qo'lda qurgan sxemani kod bilan qayta qurasiz. Bu bo'lim to'liq konfiguratsiyani bermaydi (uni siz yozasiz), faqat AWS provider'ga xos mexanizmlarni tushuntiradi.

### Resurs turlari xaritasi

| Cloud modulidagi tushuncha | Terraform resurs turlari |
|----------------------------|--------------------------|
| VPC, subnet, internet gateway, route table | `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table`, `aws_route_table_association` |
| Security group va qoidalar | `aws_security_group`, `aws_vpc_security_group_ingress_rule`, `aws_vpc_security_group_egress_rule` |
| SSH kalit | `aws_key_pair` |
| EC2 instans | `aws_instance` |
| S3 bucket va sozlamalari | `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block` |

Tarmoq resurslarining o'zi uchun haq olinmaydi, instans, uning diski, public IPv4 manzil va S3 hajmi esa hisoblanadi. Aniq narx va free tier shartlari akkauntingizga va vaqtga bog'liq: ularni darsdan emas, Billing konsolidan va AWS narx sahifasidan oling. NAT gateway va load balancer bu darsda yaratilmaydi.

### Provider: region, credential, default_tags

```
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "iac-lab"
    }
  }
}
```

- **Credential** `.tf` ga yozilmaydi. Provider AWS CLI bilan bir xil zanjirdan o'qiydi: muhit o'zgaruvchilari (`AWS_PROFILE`, `AWS_ACCESS_KEY_ID`), keyin `~/.aws/` dagi profil (cloud 2-dars). Profil har mashinada alohida sozlangan, shuning uchun kod ikkala mashinada o'zgarishsiz ishlaydi.
- **`default_tags`** shu provider yaratadigan har resursga teglarni avtomatik qo'shadi (rejada `tags_all` atributida ko'rinadi). Tozalikni aynan shu teg bo'yicha tekshirasiz.

### In-place update AWS rejasida qanday ko'rinadi

Mavjud bucket'ga bitta teg qo'shilgandagi reja (shakl):

```
  # aws_s3_bucket.logs will be updated in-place
  ~ resource "aws_s3_bucket" "logs" {
        id       = "<bucket-name>"
      ~ tags     = {
          + "Team" = "platform"
        }
      ~ tags_all = {
          + "Team" = "platform"
        }
        # (<N> unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Tashqi `~` resurs joyida o'zgarishini, ichki `~ tags` qaysi atribut o'zgarishini, `+ "Team"` map'ga yangi kalit qo'shilishini bildiradi. `id` oldida belgi yo'q: resurs o'sha. Qaysi argument `# forces replacement` berishini taxmin qilmang, `plan` dan o'qing.

### AMI, arxitektura va user_data

- AMI ID literal yozilmaydi, `data "aws_ami"` bilan topiladi: `owners` (Canonical akkaunti `099720109477`), `most_recent = true` va `name` bo'yicha `filter`. Nom shablonini `aws ec2 describe-images --owners 099720109477` chiqishidan toping: unda Ubuntu versiyasi va arxitektura (`amd64` yoki `arm64`) bor.
- AMI arxitekturasi instans tipi arxitekturasiga mos kelishi shart (cloud 4-dars). Mac'da qurilgan image'lar `arm64`: instans tipini va AMI'ni shuni hisobga olib ongli tanlang.
- `user_data` ga iac 1-darsdagi cloud-init faylingiz `file()` yoki `templatefile()` bilan beriladi. cloud-init faqat birinchi yuklanishda ishlaydi.

### Security group qoidalari

- SSH hech qachon `0.0.0.0/0` ga ochilmaydi. Sizning public IP'ingiz ofisda va uyda har xil, shuning uchun u literal emas, variable (qiymati `TF_VAR_` yoki lokal `.tfvars` orqali).
- **Tuzoq: egress.** Konsolda yaratilgan security group'da "hamma chiquvchi trafikka ruxsat" qoidasi avtomatik bo'ladi. AWS provider yangi security group yaratganda bu standart qoidani olib tashlaydi: egress qoidasini o'zingiz yozmasangiz instans tashqariga chiqa olmaydi va `user_data` dagi `apt` jimgina muvaffaqiyatsiz bo'ladi.

### Bo'sh bo'lmagan bucket

`destroy` ichida obyekt (yoki obyekt versiyasi) bor bucket'ni o'chira olmaydi va xato beradi: S3 API bo'sh bo'lmagan bucket'ni o'chirishga ruxsat bermaydi. Laboratoriya bucket'i uchun `force_destroy = true` argumenti provider'ga avval hamma obyektni o'chirishni buyuradi. Production'da bu argument xavfli.

### Destroy'dan keyingi tekshiruv

`destroy` yarmida xato bilan to'xtashi mumkin, shuning uchun "buyruq berdim" yetarli emas, natija tekshiriladi. `apply` qilingan o'sha mashinada:

```
terraform destroy
terraform state list
aws ec2 describe-instances --filters "Name=tag:Project,Values=iac-lab" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query "Reservations[].Instances[].InstanceId"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=iac-lab" --query "Vpcs[].VpcId"
aws ec2 describe-volumes --filters "Name=tag:Project,Values=iac-lab" --query "Volumes[].VolumeId"
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=iac-lab --query "ResourceTagMappingList[].ResourceARN"
aws s3 ls
```

`state list` hech narsa chiqarmasligi, to'rtta so'rov bo'sh ro'yxat (`[]`) qaytarishi, `aws s3 ls` da dars bucket'i bo'lmasligi kerak. Tagging API bitta so'rovda regiondagi barcha turdagi teglangan resurslarni qaytaradi; endigina terminate qilingan instans unda bir muddat ko'rinib turishi mumkin, shunda `describe-instances` natijasiga tayaning. Ertasi kuni Billing konsolida kutilmagan xarajat yo'qligini ko'ring.

### Nima uchun shunday

Cloud'da "unutilgan resurs" pul degani, lokal state esa faqat bitta mashinada: shu ikki fakt "o'sha mashinada destroy va teg bo'yicha tekshiruv" qoidasini majburiy qiladi. `default_tags` qoidani har resursda qo'lda takrorlash o'rniga bitta joyga qo'yadi, credential'ning koddan tashqarida turishi esa `.tf` fayllarni xavfsiz commit qilish imkonini beradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Core | `terraform` binary'si: kodni o'qiydi, graf quradi, reja hisoblaydi |
| Provider | bitta API'ni biladigan alohida plugin binary |
| Registry | provider va modullar e'lon qilinadigan katalog (`registry.terraform.io`) |
| HCL | Terraform konfiguratsiya tili: bloklar, argumentlar, ifodalar |
| Resource | Terraform yaratadigan, o'zgartiradigan va o'chiradigan obyekt |
| Data source | mavjud narsani faqat o'qiydigan blok |
| Argument / atribut | siz yozadigan maydon / provider qaytaradigan maydon |
| Resurs manzili | `<type>.<name>` yoki `<type>.<name>[kalit]`, state'dagi kimlik |
| Variable / local / output | modulning kirish parametri / ichki hisoblangan qiymat / qaytaradigan qiymat |
| State | manzil va real ID bog'lanishi hamda barcha atributlar saqlanadigan JSON fayl |
| Backend | state saqlanadigan joy (bu darsda lokal fayl) |
| Refresh | `plan` boshida real holatni API'dan qayta o'qish |
| Drift | real holatning kod va state'dan uzoqlashishi |
| In-place update | resursni ID'sini saqlagan holda o'zgartirish (`~`) |
| Replace | resursni o'chirib qayta yaratish (`-/+` yoki `+/-`) |
| `(known after apply)` | qiymat faqat resurs yaratilgandan keyin ma'lum bo'ladi |
| Dependency graph | resurslar orasidagi bog'liqliklar tuzilmasi, bajarish tartibini belgilaydi |
| Implicit dependency | havola orqali avtomatik hosil bo'lgan bog'liqlik |
| Meta-argument | har qanday resursda ishlaydigan core argumenti (`count`, `for_each`, `lifecycle`) |
| Lock fayl | `.terraform.lock.hcl`: provider'larning aniq versiyasi va checksum'lari |
| Plan fayli | `plan -out` bilan saqlangan, aynan o'zi bajariladigan reja |

## Tuzoqlar

- `terraform.tfstate` ni commit qilish. Ichida secret'lar ochiq, va ikki mashinada ikki nusxa bilan ishlansa state haqiqatdan uziladi.
- Ofisda `apply` qilib, `destroy` ni uyga qoldirish. Uydagi papkada state yo'q: Terraform u resurslarni tanimaydi.
- `plan` ni o'qimasdan `apply -auto-approve`. `-/+` belgisi ma'lumotlar bazasini qayta yaratishi mumkin.
- Terraform boshqaradigan resursni konsoldan yoki `docker` buyrug'i bilan o'zgartirish. Keyingi `apply` uni qaytaradi yoki kutilmagan replace chiqadi.
- `count` bilan ro'yxat ustida resurs yaratish va boshidan yoki o'rtasidan element olib tashlash.
- Lock faylni bitta platforma hash'i bilan commit qilish yoki umuman commit qilmaslik.
- Docker socket manzilini yoki o'z IP'ingizni `.tf` ga qattiq yozish: ikkinchi mashinada ishlamaydi.
- Dars konteynerlarini `docker system prune` bilan tozalash: state ularni hali bor deb hisoblaydi.
- Security group'da egress qoidasini unutish; SSH'ni `0.0.0.0/0` ga ochish.
- `destroy` xato bilan yarmida to'xtaganini payqamaslik (masalan bo'sh bo'lmagan bucket). Har doim `terraform state list` va teg bo'yicha tekshiruvni ko'ring.
- `user_data` o'zgarishi mavjud instansda cloud-init'ni qayta ishlatadi deb kutish.
- AWS kalitlarini `provider` blokiga yoki `terraform.tfvars` ga yozib commit qilish.

## Manbalar

- https://developer.hashicorp.com/terraform/install – o'rnatish
- https://opentofu.org/docs/intro/install/ – OpenTofu o'rnatish
- https://developer.hashicorp.com/terraform/language/syntax/configuration – HCL sintaksisi
- https://developer.hashicorp.com/terraform/language/resources/syntax – resource bloklari
- https://developer.hashicorp.com/terraform/language/values/variables – variable, qiymat manbalari tartibi
- https://developer.hashicorp.com/terraform/language/files/dependency-lock – `.terraform.lock.hcl`
- https://developer.hashicorp.com/terraform/cli/commands/providers/lock – `providers lock`
- https://developer.hashicorp.com/terraform/language/state – state
- https://developer.hashicorp.com/terraform/language/meta-arguments/for_each – `for_each` va `count`
- https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle – lifecycle
- https://developer.hashicorp.com/terraform/cli/commands/plan – `plan` va uning rejimlari
- https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs – Docker provider
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs – AWS provider
- https://registry.terraform.io/providers/hashicorp/random/latest/docs – random provider
- https://registry.terraform.io/providers/hashicorp/local/latest/docs – local provider
- https://opentofu.org/docs/ – OpenTofu hujjatlari
- Yevgeniy Brikman, "Terraform: Up & Running" (3-nashr), 1–3 va 5 boblar

## Birga bajaramiz

Bitta kichik konfiguratsiyani tug'ilishidan o'chirilishigacha olib boramiz: tasodifiy parol generatsiya qilamiz va uni `.env` fayliga yozamiz. Docker ham, cloud ham kerak emas, faqat `random` va `local` provider'lari. Hammasi host'da, repodan tashqaridagi vaqtinchalik papkada (ichida parol bo'ladi).

1. Papka va `main.tf`:

```
$ mkdir ~/tf-walk && cd ~/tf-walk
```

```
terraform {
  required_providers {
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}

variable "env" {
  type    = string
  default = "dev"
}

resource "random_password" "db" {
  length = 16
}

resource "local_sensitive_file" "env" {
  filename = "${path.module}/out/${var.env}.env"
  content  = "DB_PASSWORD=${random_password.db.result}\n"
}
```

`random_password` parol generatsiya qilib state'da saqlaydi, `local_sensitive_file` mazmuni chiqishda yashiriladigan fayl yaratadi.

2. `terraform init`, keyin `ls -a`: `.terraform/` va `.terraform.lock.hcl` paydo bo'ldi. Lock faylni ochib, ikki provider uchun `version` va `hashes` ni toping. `terraform validate` `Success!` deydi.

3. Reja:

```
$ terraform plan
  # local_sensitive_file.env will be created
  + resource "local_sensitive_file" "env" {
      + content  = (sensitive value)
      + filename = "./out/dev.env"
      + id       = (known after apply)
      ...
    }

  # random_password.db will be created
  + resource "random_password" "db" {
      + id     = (known after apply)
      + length = 16
      + result = (sensitive value)
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

Ikki `+`, hech narsa o'zgarmaydi va o'chmaydi. `(sensitive value)` qiymat yashirilganini bildiradi, `(known after apply)` esa hali mavjud emasligini. Shu paytgacha diskda ham, state'da ham hech narsa yo'q.

4. Bajarish:

```
$ terraform apply
...
random_password.db: Creating...
random_password.db: Creation complete after 0s [id=none]
local_sensitive_file.env: Creating...
local_sensitive_file.env: Creation complete after 0s [id=<sha1>]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Fayl parolga havola qilgani uchun parol birinchi yaratildi, bloklar tartibi bunga ta'sir qilmagan. Darhol yana `terraform plan`: `No changes. Your infrastructure matches the configuration.` Bu idempotency (iac 1-dars): kod, state va real holat bir xil.

5. State'ni ko'ramiz:

```
$ terraform state list
local_sensitive_file.env
random_password.db
$ terraform state show random_password.db | grep result
    result      = (sensitive value)
$ grep '"result"' terraform.tfstate
            "result": "<16 belgili parol>",
```

CLI parolni yashiradi, state faylida esa u ochiq matnda. `cat out/dev.env` dagi parol bilan bir xil ekanini tekshiring.

6. O'zgartirish, faqat reja:

```
$ terraform plan -var env=stage
  # local_sensitive_file.env must be replaced
-/+ resource "local_sensitive_file" "env" {
      ~ filename = "./out/dev.env" -> "./out/stage.env" # forces replacement
      ~ id       = "<sha1>" -> (known after apply)
      ...
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

Fayl nomini joyida o'zgartirib bo'lmaydi, shuning uchun provider replace talab qiladi: `1 to add` va `1 to destroy` bitta resursga tegishli. `random_password.db` rejada yo'q: unga hech narsa tegmagan, parol o'sha qoladi. `apply` qilmaymiz.

7. Drift: `rm out/dev.env` bilan faylni Terraform'dan tashqarida o'chiring, keyin `terraform plan`. Refresh fayl yo'qligini ko'radi va reja `# local_sensitive_file.env will be created`, `Plan: 1 to add` deydi. `terraform apply` faylni tiklaydi, ichidagi parol avvalgisi bilan bir xil: uni state eslab qolgan.

8. Tozalash:

```
$ terraform destroy
Plan: 0 to add, 0 to change, 2 to destroy.
...
local_sensitive_file.env: Destruction complete after 0s
random_password.db: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
$ terraform state list
$ cd ~ && rm -rf ~/tf-walk
```

O'chirish teskari tartibda: avval fayl, keyin parol. `state list` bo'sh.

Shu 8 qadamda ko'rganingiz: `init` provider va lock fayl beradi (3-bo'lim); `plan` belgilar, `(known after apply)` va yakuniy hisobni ko'rsatadi (1-bo'lim); havola tartibni belgilaydi va o'chirish teskari ketadi (7-bo'lim); variable buyruq qatoridan yopiladi (5-bo'lim); `sensitive` faqat chiqishni yashiradi, state'da hammasi ochiq (5 va 6-bo'limlar); replace va drift rejada qanday ko'rinadi (1 va 6-bo'limlar).

---

## Vazifalar

Ish papkasi: `iac/04-terraform-basics/` (`make new m=iac n=04 name=terraform-basics`), ichida ikki alohida Terraform papkasi: `docker/` (A, B, C guruhlar) va `aws/` (D guruh), har biri o'z state'i bilan. Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, `plan` chiqishining muhim qismi va o'z so'zingiz bilan izoh. `.tf` fayllar va `.terraform.lock.hcl` commit qilinadi, `terraform.tfstate`, `.terraform/`, plan fayli va `*.tfvars` yo'q. Hamma buyruq host'da bajariladi; har guruhni bitta mashinada boshlab, o'sha mashinada `destroy` bilan tugating (state lokal). README'da qaysi mashinada bajarilganini yozing.

### A. Docker provider: birinchi sikl

1. **Install and init.** Terraform (yoki OpenTofu) o'rnating, versiyani yozing. `docker/` papkasida `versions.tf` (provider talabi) yozib `terraform init` qiling. `.terraform/` ichida nima paydo bo'ldi, hajmi qancha? `.terraform.lock.hcl` da nima yozilgan? Qaysi biri commit qilinadi va nima uchun? Lock faylni ikkala platforma uchun to'ldiring (`terraform providers lock`) va `git diff` da nima qo'shilganini yozing. Yo'nalish: 3-bo'lim, "init nima yaratadi" va "Ikki platforma va lock fayl".

2. **First apply.** `docker_image` (nginx) va `docker_container` (host porti 8080) yozing. `plan` chiqishini o'qing: nechta resurs, qaysi atributlar `(known after apply)`. `apply` qiling, `curl localhost:8080` va `docker ps` bilan tekshiring. Darhol yana `plan`: nima deydi? Docker manzilini `.tf` ga qattiq yozmang, resurs nomlariga `iac-` prefiksi bering. Yo'nalish: 1-bo'lim, "Misol: plan chiqishini o'qish"; 3-bo'lim, "required_providers va provider bloki".

3. **Read the state.** `terraform.tfstate` ni oching (faqat o'qish): `serial`, `lineage`, `resources` ni toping. Konteyner uchun state'da nechta atribut saqlangan, siz ulardan nechtasini yozgansiz? `terraform state list` va `terraform state show` chiqishi bilan solishtiring. Yana bir `apply` dan keyin `serial` o'zgardimi? Yo'nalish: 6-bo'lim, "Fayl ichida nima bor" va "State'ni ko'rish".

4. **Update or replace.** Konteynerning tashqi portini, keyin `restart` siyosatini, keyin nomini bittalab o'zgartirib faqat `plan` qiling. Har biri uchun: belgi (`~` yoki `-/+`), qaysi atribut `# forces replacement` deb belgilangan. Bittasini `apply` qilib, `docker ps` da konteyner ID'si o'zgarganini yoki o'zgarmaganini ko'rsating. Yo'nalish: 1-bo'lim, belgilar jadvali.

5. **Variables and outputs.** `container_name`, `external_port` (validation bilan) va `image_tag` o'zgaruvchilarini kiriting, URL uchun output qo'shing. `external_port` ga to'rt manbadan har xil qiymat bering (`default`, `TF_VAR_`, `terraform.tfvars`, `-var`) va qaysi biri yutishini bittalab olib tashlab tasdiqlang. `terraform output -raw` ni `curl` bilan birlashtiring. Yo'nalish: 5-bo'lim, "Qiymat qayerdan keladi".

6. **Validation errors.** Uch xil xato chiqaring va matnini o'qing: validation shartini buzadigan port; `number` o'zgaruvchiga `"abc"`; mavjud bo'lmagan resursga havola. Har biri qaysi bosqichda (`validate`, `plan`, `apply`) ushlandi? Yo'nalish: 9-bo'lim, "fmt va validate" (bosqichlar jadvali).

### B. Graph, count, lifecycle

7. **Dependency graph.** `docker_network` qo'shing va konteynerni unga ulang. `terraform graph` chiqishidan konteyner, image va network orasidagi qirralarni toping. `apply` va `destroy` log'ida yaratish va o'chirish tartibini yozing. Havolani olib tashlab network nomini string bilan yozsangiz nima buziladi? Yo'nalish: 7-bo'lim, "Tartibni graf belgilaydi".

8. **count vs for_each.** `names = ["api", "worker", "cron"]` ro'yxatidan `count` bilan uchta konteyner yarating. Ro'yxatdan `"api"` ni olib tashlab faqat `plan` qiling: nechta resursga tegildi, nima uchun? Keyin `destroy` qilib xuddi shu konteynerlarni `for_each` bilan qayta yozing va tajribani takrorlang: endi nechta? `state list` dagi manzillarni ikkala variantda solishtiring. Yo'nalish: 8-bo'lim, "Indeks siljishi".

9. **Lifecycle.** Uch tajriba: (a) `prevent_destroy = true` bilan `terraform destroy`, xatoni o'qing; (b) nomi qat'iy konteynerga `create_before_destroy = true` qo'yib replace chaqiring, xato sababini izohlang va qanday resurslarda bu ishlashini ayting; (c) `ignore_changes` bilan bitta atributdagi o'zgarishni e'tiborsiz qoldiring va `plan` da ko'rsating. Yo'nalish: 8-bo'lim, "lifecycle".

10. **fmt and validate.** Faylni ataylab yomon formatlang va bitta havolani buzing. `terraform fmt -check -diff` va `terraform validate` chiqishini yozing. Image nomini mavjud bo'lmagan tegga o'zgartiring: `validate` ushladimi, qaysi bosqich ushladi? `validate` nimani tekshira olmasligini umumlashtiring. Yo'nalish: 9-bo'lim, "fmt va validate".

### C. Drift va state

11. **Drift.** Terraform yaratgan konteynerni `docker rm -f` bilan qo'lda o'chiring. `terraform plan -refresh-only` nima ko'rsatadi, oddiy `plan` nima taklif qiladi? `apply` bilan tiklang. Keyin konteynerni qo'lda `docker stop` qiling: bu safar reja qanday? Yo'nalish: 6-bo'lim, "Drift".

12. **Lost state.** `terraform.tfstate` ni boshqa nomga ko'chiring (o'chirmang). `plan` nima deydi? `apply` qilib ko'ring: qaysi resurs yaratildi, qaysi birida xato chiqdi va nima uchun? Yarim yaratilgan resurslarni tozalab, asl state'ni qaytaring va `plan` toza ekanini ko'rsating. Xulosa: state'siz Terraform nimani bilmaydi? Yo'nalish: 6-bo'lim, "State yo'qolsa".

13. **Saved plan.** `terraform plan -out=app.tfplan`, `terraform show app.tfplan`. `apply` qilishdan oldin boshqa terminalda oddiy `apply` bilan boshqa o'zgarish kiriting, keyin saqlangan rejani qo'llang: xato matni nima? Bu himoya CI'da nima uchun kerak? Yo'nalish: 9-bo'lim, "Saqlangan reja".

14. **Docker cleanup.** `terraform plan -destroy` ni o'qing, keyin `destroy`. `docker ps -a`, `docker network ls` va `docker images` bilan hech narsa qolmaganini tekshiring. `keep_locally` argumenti image taqdiriga qanday ta'sir qiladi? Tozalash uchun `docker system prune` ishlatmang. Yo'nalish: 9-bo'lim, "Saqlangan reja"; registry'dagi `docker_image` sahifasi.

### D. AWS

15. **Provider and identity.** `aws/` papkasida AWS provider'ni region va `default_tags` bilan sozlang. `data "aws_caller_identity"` va `data "aws_availability_zones"` dan output chiqaring va `aws sts get-caller-identity` bilan solishtiring. Bu `apply` nechta resurs yaratdi? Terraform credential'ni qayerdan oldi? Budget alert yoqilganini tekshirib, summasini yozing. Qaysi mashinada va qaysi profil bilan ishlaganingizni yozing. Yo'nalish: 4-bo'lim, "Ikki xil blok"; 10-bo'lim, "Provider: region, credential, default_tags".

16. **Network.** VPC, bitta public subnet, internet gateway, route table va association yozing. CIDR'lar o'zgaruvchidan, subnet CIDR'i `cidrsubnet()` bilan hisoblansin. `plan` da nechta resurs? `apply` dan keyin AWS CLI bilan VPC va route'ni tekshiring. Cloud modulida shu qadamlar nechta CLI buyrug'i edi? Yo'nalish: 2-bo'lim, "Ifodalar, funksiyalar va console"; 10-bo'lim, "Resurs turlari xaritasi".

17. **Security group.** Security group va alohida qoida resurslari: SSH faqat sizning IP'ingizdan (`/32`, o'zgaruvchi orqali, validation bilan), HTTP hammadan, egress hammaga. Avval egress qoidasisiz `apply` qilib, konsol yoki CLI'da chiquvchi qoidalar ro'yxatini ko'ring va qo'lda yaratilgan security group bilan farqini yozing. IP'ingiz ofisda va uyda har xil: qiymat commit qilinmaydigan manbadan kelsin. Yo'nalish: 10-bo'lim, "Security group qoidalari".

18. **AMI data source.** `data "aws_ami"` bilan eng yangi Ubuntu 24.04 AMI'sini toping, ID va nomini output qiling. `most_recent = true` ning yon ta'siri nima: ertaga yangi AMI chiqsa mavjud instans rejasida nima ko'rinadi? Bunga qarshi ikki yechimni yozing. Yo'nalish: 4-bo'lim, "Nima uchun shunday"; 10-bo'lim, "AMI, arxitektura va user_data".

19. **EC2 instance.** `aws_key_pair` (laboratoriya public kalitingiz) va `aws_instance`: eng kichik tip, public subnet, security group, `user_data` da nginx o'rnatadigan cloud-init. Public IP'ni output qiling. `ssh` bilan kiring va `curl http://<IP>` javob berishini ko'rsating. `user_data` ishlamagan bo'lsa qaysi log'dan sababini topasiz? Instans tipi va AMI arxitekturasi mosligini asoslang. Yo'nalish: 10-bo'lim, "AMI, arxitektura va user_data".

20. **Plan reading on AWS.** Faqat `plan` qiling (apply'siz) va har o'zgarish uchun belgi va sababni yozing: instansga teg qo'shish; `instance_type` ni o'zgartirish; `user_data` ni o'zgartirish; subnet'ning `availability_zone` ini o'zgartirish. Qaysi biri eng xavfli va nima uchun? Tegni `apply` qilib in-place update'ni tasdiqlang. Yo'nalish: 10-bo'lim, "In-place update AWS rejasida qanday ko'rinadi".

21. **S3 bucket.** Global noyob nomli (akkaunt ID'si qo'shilgan) bucket, versioning yoqilgan, public access to'liq bloklangan. AWS CLI bilan fayl yuklang, keyin `terraform destroy -target=aws_s3_bucket.<name>` qilib xatoni o'qing. `force_destroy` bilan hal qiling. `-target` nima uchun kundalik ishda tavsiya etilmaydi? Yo'nalish: 10-bo'lim, "Bo'sh bo'lmagan bucket".

22. **Destroy and verify.** `terraform plan -destroy` ni o'qing, `destroy` qiling. 10-bo'limdagi tekshiruv buyruqlarining har birini ishga tushirib chiqishini yozing. Butun AWS qismi `apply` dan `destroy` gacha qancha vaqt oldi? 1-darsdagi "Pain summary" jadvaliga Terraform ustunini qo'shing. Hammasi `apply` qilingan o'sha mashinada bajariladi. Yo'nalish: 10-bo'lim, "Destroy'dan keyingi tekshiruv".

### Topshirish

Tayyor bo'lgach:
1. `iac/04-terraform-basics/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida; `docker/` va `aws/` papkalarida `.tf` fayllar (odatiy bo'linish: `versions.tf`, `main.tf`, `variables.tf`, `outputs.tf`).
2. `make check` toza (host'da), ikkala papkada `terraform fmt -check -recursive` va `terraform validate` toza.
3. Repoda `terraform.tfstate`, `.terraform/`, plan fayli, `*.tfvars` va kalit yo'q; ikkala papkada `.terraform.lock.hcl` bor va u `linux_amd64` hamda `darwin_arm64` uchun to'ldirilgan (buyruq README'da).
4. AWS resurslari `apply` qilingan mashinada o'chirilgan, 10-bo'limdagi tekshiruv chiqishi `README.md` da.
5. Docker resurslari o'chirilgan: `docker ps -a` va `docker network ls` da `iac-` prefiksli narsa yo'q.
6. Menga xabar bering, `README.md` va `.tf` fayllarni o'qib chiqaman.

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
- `(known after apply)` va `(sensitive value)` farqi nima? `sensitive` qiymat state'da qanday saqlanadi?
- Lock faylda nima uchun bitta provider versiyasiga bir nechta hash to'g'ri keladi va ikki mashinada ishlash uchun nima qilinadi?
- Nima uchun bu darsda `destroy` aynan `apply` qilingan mashinada bajarilishi shart?
- Yashirin bog'liqlik va `depends_on` farqi nima, ID'ni string bilan qo'lda yozish nimani buzadi?
