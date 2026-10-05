# 1-dars: Infrastructure as Code, umumiy ma'lumot

Maqsad: Infrastructure as Code (IaC) qanday muammoni yechishini va asboblar qaysi o'qlar bo'yicha farqlanishini tushunish: declarative va imperative, provisioning va configuration management, mutable va immutable, push va pull, state bor yoki yo'q. Cloud modulida muhitni konsol va CLI bilan qo'lda qurdingiz, cicd modulida ilovani pipeline orqali yetkazdingiz; infratuzilmaning o'zi hali qo'lda. Bu darsda asbob o'rnatilmaydi: avval oddiy bash skript va cloud-init bilan serverni tayyorlab, idempotency, dry-run va "o'chirish" muammolarini o'z qo'lingiz bilan his qilasiz. 2–3-darslardagi Ansible va 4–5-darslardagi Terraform aynan shu og'riqlarga javob.

Taxminiy vaqt: 2 kun (siz uchun). Deklarativ fikrlash sizga React (`UI = f(state)`) va `package.json` + lockfile dan tanish. Diqqatni quyidagilarga qarating: idempotency aniq nimani anglatadi, state nima uchun kerak va usiz asbob nimani bila olmaydi, provisioning bilan configuration management chegarasi, drift qayerdan paydo bo'ladi.

## Laboratoriya

Barcha vazifalar Multipass VM ichida bajariladi. Skriptlar foydalanuvchi yaratadi, paket o'rnatadi, `/etc` ga yozadi, shuning uchun ularni ish mashinasida ishga tushirmang. Skript faylini ish mashinasida yozasiz, VM'ga ko'chirib o'sha yerda bajarasiz.

Multipass linux modulida o'rnatilgan. O'rnatilmagan bo'lsa: `sudo snap install multipass` (hujjat: https://documentation.ubuntu.com/multipass/latest/how-to-guides/install-multipass/).

```
multipass launch 24.04 --name iac1 --cpus 1 --memory 1G --disk 5G
multipass transfer provision_v1.sh iac1:
multipass exec iac1 -- sudo bash provision_v1.sh
multipass shell iac1
```

Tozalash: `multipass delete --purge iac1` (va vazifalarda yaratilgan boshqa VM'lar), keyin `multipass list` bo'sh ekanini tekshiring. Bu darsda cloud resurs yaratilmaydi.

---

## 1. Muammo: qo'lda boshqariladigan infratuzilma

Cloud modulidagi muhitingizni eslang: VPC, subnet, security group, EC2, uning ichida Docker, foydalanuvchi, firewall, reverse proxy. Uni qayta qurish kerak bo'lsa, manba sifatida sizda nima bor? Xotira, `README` dagi eslatmalar va shell tarixi. Bu uch muammoni tug'diradi.

### Drift
Drift bu real holatning hujjatlashtirilgan (yoki kutilgan) holatdan uzoqlashishi. Manbalari:
- Tunda incident paytida konsoldan ochilgan security group qoidasi, keyin unutilgan.
- Bir serverda qo'lda yangilangan paket, ikkinchisida yo'q.
- "Vaqtincha" o'zgartirilgan config fayl.

Qo'lda boshqariladigan muhitda drift ko'rinmaydi, chunki solishtiradigan etalon yo'q. Ikki "bir xil" server oylar o'tib har xil bo'lib qoladi (snowflake server): birida ishlagan deploy ikkinchisida sinadi.

### Takrorlanuvchanlik (reproducibility)
Muhitni noldan qayta qurish kerak bo'ladigan holatlar: staging yaratish, region almashtirish, serverning buzilishi, yangi jamoa a'zosi uchun sandbox. Qo'lda bu soatlar va har safar biroz boshqacha natija. Kod bilan bu bitta buyruq va har safar bir xil natija.

### Review va tarix
Konsoldagi o'zgarishni hech kim review qilmaydi, `git blame` ham yo'q. Infratuzilma kodda bo'lsa, unga dasturiy kod bilan bir xil jarayon qo'llanadi: pull request, review, CI tekshiruvi, tarix, revert. Bu IaC ning asosiy g'oyasi: infratuzilma ta'rifi versiyalanadigan matn fayllarida, uni asbob bajaradi, odam emas.

IaC nimani bermaydi: yomon arxitekturani tuzatmaydi va xatoni tezroq, hamma serverga birdan tarqatishga ham imkon beradi. Shuning uchun `plan`, check mode va review jarayonning majburiy qismi.

## 2. Declarative va imperative

| | Imperative | Declarative |
|---|-----------|-------------|
| Nima yoziladi | qadamlar: "buni qil, keyin buni" | natija: "shunday bo'lsin" |
| Joriy holatni kim hisobga oladi | siz (`if` lar bilan) | asbob (joriy va kerakli holatni solishtiradi) |
| Qayta ishga tushirish | xavfli, agar maxsus yozilmagan bo'lsa | xavfsiz, farq bo'lmasa hech narsa qilmaydi |
| Misol | bash skript, `aws ec2 run-instances` | Terraform, Kubernetes manifest, `compose.yaml` |

```
# imperative: steps
aws ec2 create-vpc --cidr-block 10.0.0.0/16
```

```
# declarative: desired end state
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Birinchi buyruqni ikki marta ishlatsangiz ikkita VPC bo'ladi. Ikkinchi ta'rifni ikki marta `apply` qilsangiz bitta VPC qoladi, chunki asbob avval "bu VPC allaqachon bormi" degan savolga javob topadi.

Chegara qat'iy emas. Ansible playbook'i tartib bilan bajariladigan task'lar ro'yxati (imperative shakl), lekin har task deklarativ: `state: present` "o'rnat" emas, "o'rnatilgan bo'lsin" degani. Pulumi'da kod umumiy maqsadli tilda yoziladi, lekin kod bajarilishi natijasida deklarativ resurs grafi hosil bo'ladi.

## 3. Idempotency

Operatsiya idempotent bo'ladi, agar uni bir marta va ko'p marta bajarish natijasi bir xil bo'lsa. HTTP'dan tanish: `PUT` idempotent, `POST` yo'q.

| Idempotent emas | Idempotent |
|-----------------|-----------|
| `useradd deploy` (ikkinchi safar xato) | `id -u deploy >/dev/null 2>&1 \|\| useradd deploy` |
| `echo "line" >> file` (har safar yangi qator) | `grep -qxF "line" file \|\| echo "line" >> file` |
| `mkdir /opt/app` | `mkdir -p /opt/app` |
| `ln -s a b` | `ln -sfn a b` |

Idempotent bash yozish mumkin, lekin har qadam "tekshir, keyin bajar" juftligiga aylanadi va tekshiruvning to'g'riligi sizning zimmangizda. Masalan `id -u deploy` foydalanuvchi borligini tekshiradi, lekin uning shell'i, guruhlari va home papkasi kerakli holatda ekanini emas. IaC asboblari shu juftlikni har resurs turi uchun tayyor beradi (Ansible moduli, Terraform provider'i).

Idempotency ikki narsani beradi: skriptni yarmida uzilgandan keyin qayta ishga tushirish xavfsiz bo'ladi, va uni muntazam ishga tushirib drift'ni tuzatish mumkin bo'ladi (convergence).

**Tuzoq: "xatosiz qayta ishga tushdi" idempotent degani emas.** `echo >> file` xato bermaydi, lekin har safar faylni o'zgartiradi. Mezon: ikkinchi ishga tushirishda hech narsa o'zgarmasligi va asbob buni aniq aytishi (`changed=0`, `No changes`).

## 4. Provisioning va configuration management

| | Provisioning | Configuration management |
|---|-------------|--------------------------|
| Savol | qanday resurslar mavjud bo'lsin? | resurs ichida nima bo'lsin? |
| Obyektlar | VPC, subnet, VM, disk, DNS yozuvi, bucket, IAM | paket, fayl, foydalanuvchi, servis, firewall qoidasi |
| Muloqot qiladi | cloud API bilan | server bilan (SSH yoki agent) |
| Asboblar | Terraform, OpenTofu, Pulumi, CloudFormation | Ansible, Chef, Puppet, Salt |

Asboblar chegaradan o'ta oladi: Ansible'da cloud modullari bor, Terraform'da `user_data` va provisioner'lar bor. Lekin har biri o'z sohasida kuchli. Terraform resurslarning hayot siklini (yaratish, o'zgartirish, o'chirish, bog'liqlik tartibi) state orqali kuzatadi, Ansible buni qilmaydi. Ansible server ichidagi yuzlab mayda holatni modullar bilan boshqaradi, Terraform buni qilmaydi. Keng tarqalgan bo'linish: Terraform serverni yaratadi, Ansible (yoki cloud-init, yoki oldindan pishirilgan image) uni sozlaydi. 5-darsda ikkalasini birlashtirasiz.

Uchinchi qatlam: ilovani yetkazish (deploy). Bu cicd modulida edi va odatda infratuzilma kodidan alohida, tezroq siklda yuradi.

## 5. Mutable va immutable infratuzilma

- **Mutable**: server uzoq yashaydi, o'zgarishlar uning ustiga qo'llanadi (paket yangilanadi, config almashtiriladi). Ansible'ning klassik ishlatilishi. Kamchilik: har server o'z tarixiga ega, drift to'planadi, "bo'sh serverdan qurish" yo'li kam sinaladi.
- **Immutable**: server yaratilgandan keyin o'zgartirilmaydi. O'zgarish kerak bo'lsa yangi image quriladi (Packer yoki Docker build), yangi server undan ko'tariladi, eskisi o'chiriladi. Drift bo'lmaydi, rollback bu oldingi image'ga qaytish.

Docker modulida immutable modelni allaqachon ishlatgansiz: ishlab turgan konteynerga kirib paket o'rnatmaysiz, yangi image qurasiz. VM darajasida ham xuddi shu g'oya. Immutable model narxi: image qurish pipeline'i kerak, holat (ma'lumotlar bazasi, yuklangan fayllar) serverdan tashqariga chiqarilgan bo'lishi kerak.

Amalda aralash ishlatiladi: asosiy qatlam image'da (OS, Docker), o'zgaruvchan qism cloud-init yoki Ansible bilan birinchi yuklanishda.

## 6. State

Asbob "nimani o'zgartirish kerak" ni hisoblash uchun uchta narsani biladi yoki bilmaydi:

1. **Kerakli holat**: sizning kodingiz.
2. **Real holat**: API yoki serverdan o'qiladi.
3. **Oldin nimani o'zim yaratganman**: state.

Uchinchisi bo'lmasa asbob ikki savolga javob bera olmaydi. Birinchisi: koddan olib tashlangan resursni o'chirish kerakmi? Koddan `aws_s3_bucket` blokini o'chirsangiz, Terraform state'da "bu bucket'ni men yaratganman" yozuvini ko'radi va uni o'chirishni rejalashtiradi. Ansible'da state yo'q: playbook'dan paket o'rnatish task'ini olib tashlasangiz paket serverda qoladi, uni o'chirish uchun `state: absent` deb aniq yozish kerak. Ikkinchisi: koddagi nom bilan real resurs identifikatori (`aws_instance.web` va `i-0abc...`) qanday bog'lanadi.

| Yondashuv | Asboblar | Oqibat |
|-----------|----------|--------|
| State fayli asbobda | Terraform, OpenTofu, Pulumi | o'chirishni biladi; state'ni saqlash, qulflash va himoyalash kerak |
| State servis ichida | CloudFormation (stack) | saqlash tashvishi yo'q, faqat o'sha cloud |
| State yo'q, har safar real holatni tekshiradi | Ansible, bash | sodda; koddan olib tashlangan narsa "yetim" qoladi |

State narxi 4–5-darslarda: u secret'larni ochiq saqlaydi, yo'qolsa asbob resurslarni "tanimaydi", ikki kishi bir vaqtda yozsa buziladi.

## 7. Push va pull

- **Push**: markaziy joydan (noutbuk, CI runner) buyruq nishonlarga yuboriladi. Ansible (SSH orqali), Terraform (API chaqiruvlari). Oddiy, agent kerak emas; o'zgarish faqat kimdir ishga tushirganda qo'llanadi, o'sha paytda o'chiq turgan server o'tkazib yuboriladi.
- **Pull**: har nishonda agent bor, u muntazam ravishda markazdan kerakli holatni olib o'zini moslaydi. Puppet agent, Chef client. Drift o'zi tuzaladi va yangi server o'zi sozlanadi; narxi agent va markaziy serverni boshqarish.

Ansible'da `ansible-pull` rejimi ham bor (server git'dan playbook'ni o'zi tortadi), cloud-init esa bir martalik pull (server birinchi yuklanishda user-data'ni metadata servisdan oladi). Kubernetes modulida GitOps pull modelining zamonaviy ko'rinishini ko'rasiz.

## 8. Asboblar xaritasi

| Asbob | Vazifasi | Til | Model | State | Nishonda agent |
|-------|----------|-----|-------|-------|----------------|
| Terraform / OpenTofu | provisioning, ko'p cloud | HCL | declarative | fayl (lokal yoki remote backend) | yo'q (API) |
| Pulumi | provisioning, ko'p cloud | TypeScript, Python, Go va boshqalar | declarative graf, umumiy til bilan | Pulumi Cloud yoki o'z backend'ingiz | yo'q (API) |
| CloudFormation | provisioning, faqat AWS | YAML/JSON | declarative | AWS ichida (stack) | yo'q |
| Ansible | configuration management, orkestratsiya | YAML + Jinja2 | task'lar tartibli, modullar deklarativ | yo'q | yo'q (SSH + Python) |
| Puppet | configuration management | o'z DSL'i | declarative | yo'q (agent hisobot beradi) | bor, pull |
| Chef | configuration management | Ruby DSL | tartibli retseptlar | yo'q | bor, pull |
| Salt | configuration management, masofadan bajarish | YAML + Jinja2 | declarative state'lar | yo'q | bor (minion), `salt-ssh` bilan agentsiz ham |
| Packer | machine image qurish (AMI va boshqalar) | HCL | bir martalik build | yo'q | yo'q |
| cloud-init | birinchi yuklanishda sozlash | YAML (`#cloud-config`) | declarative modullar + `runcmd` | instans ichida "bajarildi" belgisi | image ichida o'rnatilgan |

Sizning fon uchun eslatma: Pulumi TypeScript'da yozilgani uchun jozibali ko'rinadi. Bu kursda Terraform tanlangan, chunki bozorda eng ko'p uchraydi va state, plan, provider tushunchalari Pulumi'da ham deyarli bir xil.

### cloud-init
Deyarli barcha cloud image'larda (shu jumladan Multipass ishlatadigan Ubuntu image'larida) o'rnatilgan. Instans yaratilayotganda berilgan user-data ni birinchi yuklanishda o'qiydi:

```
#cloud-config
package_update: true
packages:
  - nginx
users:
  - default
  - name: deploy
    groups: sudo
    shell: /bin/bash
runcmd:
  - systemctl enable --now nginx
```

Multipass'da: `multipass launch 24.04 --name iac2 --cloud-init cloud-init.yaml`. Holat: VM ichida `cloud-init status --wait`, log'lar `/var/log/cloud-init.log` va `/var/log/cloud-init-output.log`. Sxemani tekshirish: VM ichida `cloud-init schema --config-file cloud-init.yaml`.

Cheklovi: ko'pchilik modullar instans umrida bir marta ishlaydi. Faylni keyin o'zgartirsangiz ishlab turgan serverga ta'sir qilmaydi. Shuning uchun cloud-init "day 0" asbobi: serverni boshqaruvga yaroqli holatga keltiradi (foydalanuvchi, SSH kalit, bazaviy paketlar), keyingi o'zgarishlar boshqa asbob yoki yangi server orqali.

**Tuzoq: `users:` ro'yxatida `default` yozilmasa image'ning standart foydalanuvchisi (`ubuntu`) yaratilmaydi.** Multipass'ning `shell` va `exec` buyruqlari aynan shu foydalanuvchi bilan ishlaydi.

### Terraform litsenziyasi va OpenTofu
- 2023-yil avgustda HashiCorp Terraform (va boshqa mahsulotlari) litsenziyasini kelgusi relizlar uchun MPL 2.0 dan Business Source License (BUSL) 1.1 ga o'zgartirishini e'lon qildi. 1.5.x versiyalar MPL 2.0 ostida qoldi.
- BUSL OSI ta'rifi bo'yicha open source emas ("source-available"). Kod ochiq, lekin litsenziyada HashiCorp bilan raqobatlashuvchi mahsulot taklif qilishni cheklovchi shart bor. O'z kompaniyangiz infratuzilmasini Terraform bilan boshqarish bu cheklovga tushmaydi, lekin aniq holat uchun litsenziya matni va HashiCorp FAQ'ini o'zingiz o'qing, bu dars yuridik maslahat emas.
- OpenTofu bu Terraform'ning MPL 2.0 davridagi kodidan olingan fork, Linux Foundation boshqaruvida, MPL 2.0 litsenziyasida. CLI `tofu`, buyruqlar va HCL asosiy qismda mos (`tofu init`, `tofu plan`).
- Ikki loyiha fork'dan keyin mustaqil rivojlanmoqda: har birida ikkinchisida yo'q imkoniyatlar bor (masalan OpenTofu'da state shifrlash). Yangi versiyalarda yozilgan kod va state ikkinchisiga har doim ham o'tavermaydi.

Bu kursda buyruqlar `terraform` deb yoziladi. OpenTofu tanlasangiz `tofu` deb o'qing; farq qiladigan joylar darsda aytiladi.

## 9. Qaysi asbob qachon

| Vazifa | To'g'ri keladigan asbob |
|--------|--------------------------|
| Cloud resurslarini yaratish va o'chirish | Terraform/OpenTofu (yoki Pulumi, CloudFormation) |
| Yangi serverni boshqaruvga tayyorlash (foydalanuvchi, kalit) | cloud-init |
| Uzoq yashaydigan serverlar konfiguratsiyasi, bir nechta serverda tartibli amal | Ansible |
| Tayyor image (immutable model) | Packer, ichida Ansible yoki shell |
| Bir martalik tezkor amal 20 ta serverda | Ansible ad-hoc |
| Konteyner ichidagi narsa | Dockerfile, bu yerga Ansible kerak emas |

## Tuzoqlar

- IaC bilan yaratilgan resursni konsoldan "tezgina" o'zgartirish. Keyingi `apply` uni qaytarib yuboradi yoki kutilmagan diff chiqadi. O'zgarish faqat kod orqali.
- Idempotent bo'lmagan skriptni cron yoki CI'da takror ishlatish: `>>` bilan config fayl har safar uzayadi, bir kun servis ishga tushmay qoladi.
- "Skript xatosiz o'tdi" ni "server kerakli holatda" deb qabul qilish. Tekshiruv faqat siz yozgan narsani tekshiradi, ortiqcha narsalarni (qo'lda qo'shilgan foydalanuvchi, ochilgan port) ko'rmaydi.
- cloud-init faylini o'zgartirib, ishlab turgan server ham o'zgaradi deb kutish. U birinchi yuklanishda ishlaydi.
- State'siz asbobda (Ansible, bash) koddan qatorni o'chirish resursni o'chiradi deb o'ylash. Resurs qoladi.
- Bitta asbob bilan hamma narsani qilishga urinish: Terraform provisioner'lari bilan server sozlash yoki Ansible bilan butun cloud hayot siklini yuritish. Ishlaydi, lekin har biri o'z sohasidan tashqarida mo'rt.
- Secret'ni IaC kodiga yoki user-data'ga ochiq yozish. User-data instans metadata'sidan o'qiladi, repo tarixidan esa o'chmaydi.
- Review'siz `apply`. IaC xatoni ham avtomatlashtiradi: bitta noto'g'ri qator hamma muhitga bir necha soniyada tarqaladi.

## Manbalar

- https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html – AWS: IaC tushunchasi
- https://martinfowler.com/bliki/InfrastructureAsCode.html – Fowler: IaC ta'rifi va amaliyotlari
- https://martinfowler.com/bliki/SnowflakeServer.html – snowflake server
- https://martinfowler.com/bliki/ImmutableServer.html – immutable server
- https://cloudinit.readthedocs.io/en/latest/reference/examples.html – cloud-config misollari
- https://cloudinit.readthedocs.io/en/latest/reference/modules.html – cloud-init modullari va ularning ishlash chastotasi
- https://documentation.ubuntu.com/multipass/ – Multipass hujjatlari
- https://www.hashicorp.com/license-faq – HashiCorp litsenziya FAQ
- https://github.com/hashicorp/terraform/blob/main/LICENSE – Terraform litsenziya matni
- https://opentofu.org/faq/ – OpenTofu FAQ
- https://www.shellcheck.net/ – ShellCheck
- Kief Morris, "Infrastructure as Code" (3-nashr), 1–4 boblar

---

## Vazifalar

Ish papkasi: `iac/01-intro/` (`make new m=iac n=01 name=intro`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`provision_v1.sh`, `provision_v2.sh`, `cloud-init.yaml`) shu papkada saqlanadi. Skriptlar faqat VM ichida bajariladi.

### A. Tahlil

1. **Manual build inventory.** Cloud modulida qo'lda qurgan muhitingizni eslatmalarga qaramasdan, xotiradan ro'yxat qiling: har resurs va uning muhim parametrlari (CIDR, portlar, instans tipi, server ichidagi paketlar va fayllar). Keyin eslatmalaringiz va AWS CLI chiqishi bilan solishtiring. Nimani unutdingiz yoki noto'g'ri esladingiz? Xuddi shu muhitni ertaga qayta qurish qancha vaqt olardi?

2. **Declarative or imperative.** Quyidagilarning har birini declarative, imperative yoki aralash deb tasniflang va bir gap bilan asoslang: `Dockerfile`, `compose.yaml`, `package.json` dagi `dependencies`, `package.json` dagi `scripts`, SQL migratsiya fayli, GitHub Actions workflow, `crontab` yozuvi, `aws ec2 run-instances` buyrug'i, CSS, `git rebase` buyruqlari ketma-ketligi.

3. **Provisioning or configuration.** Cloud modulidagi ro'yxatingizni (1-vazifa) ikki ustunga ajrating: provisioning va configuration management. Chegarada turgan kamida ikkita narsani toping (masalan security group va host firewall) va qaysi asbob zimmasiga berishni asoslang.

4. **Mutable vs immutable.** Docker modulidagi tajribangizga tayanib yozing: ishlab turgan konteynerga `docker exec` bilan kirib tuzatish nima uchun yomon amaliyot? Xuddi shu mantiqni EC2 serverga qo'llang: immutable modelga o'tish uchun app serveringizda nima o'zgarishi kerak (holat qayerda saqlanadi, image qanday quriladi)?

5. **Tool selection.** Har holat uchun asbob (yoki asboblar juftligi) tanlang va asoslang: (a) 3 ta muhit uchun bir xil VPC va serverlar; (b) 40 ta mavjud serverda `sshd` sozlamasini o'zgartirish; (c) autoscaling group uchun tayyor AMI; (d) yangi EC2 birinchi yuklanishda deploy foydalanuvchisiga ega bo'lishi; (e) barcha serverlarda hozir qaysi kernel versiyasi turganini bilish.

6. **License check.** `hashicorp/terraform` va `opentofu/opentofu` GitHub repolaridagi `LICENSE` fayllarini oching. Har biri qaysi litsenziya? Terraform litsenziyasidagi "Additional Use Grant" bandini toping va o'z so'zingiz bilan yozing: nima ruxsat etiladi, nima cheklanadi, "Change Date" va "Change License" nimani anglatadi.

### B. Bash bilan provisioning

7. **Naive script.** `provision_v1.sh` yozing (`set -euo pipefail` bilan), u VM'da quyidagi holatni hosil qilsin: `deploy` foydalanuvchisi; `/opt/app` papkasi, egasi `deploy`; `nginx` va `curl` paketlari; `/etc/motd` oxirida `Managed by provision script` qatori; `/opt/app/app.env` fayli, ichida `APP_ENV=dev`, mode `0640`. Eng sodda buyruqlar bilan yozing, hech qanday tekshiruvsiz. VM'da ikki marta ishga tushiring. Ikkinchi ishga tushirishda nima sindi, qaysi qadamlar "jimgina" noto'g'ri ishladi?

8. **Idempotent script.** `provision_v2.sh`: xuddi shu yakuniy holat, lekin har qadam "tekshir, keyin bajar" shaklida. Uch marta ketma-ket ishga tushiring: har safar exit code `0`, `/etc/motd` da qator bitta. Har qadam uchun tekshiruv aynan nimani tekshirishini va nimani tekshirmasligini yozing.

9. **Changed reporting.** `provision_v2.sh` ga hisobot qo'shing: har qadam `changed` yoki `ok` chop etsin, oxirida jami (`ok=N changed=M`). Toza VM'da birinchi ishga tushirish `changed=5` atrofida, ikkinchisi `changed=0` bo'lsin. Buning uchun qancha qo'shimcha kod yozdingiz?

10. **Drift repair.** VM'da qo'lda drift yarating: `/opt/app` egasini `root` ga o'zgartiring, `app.env` mode'ini `0644` qiling, `app.env` ichidagi qiymatni `APP_ENV=prod` ga almashtiring, `deploy` ning shell'ini `/bin/sh` qiling, `htop` paketini o'rnating. Skriptni qayta ishga tushiring. Qaysi drift tuzaldi, qaysi biri sezilmadi? Sezilmaganlarini tuzatish uchun skriptga nima qo'shish kerak bo'lardi?

11. **Dry run.** Skriptga `--check` flag'ini qo'shing: hech narsani o'zgartirmasdan, nima o'zgarishini chop etsin. Yuqoridagi drift'lardan birini qayta yaratib sinang. Bu flag har qadamda qanday qo'shimcha tarmoqlanishni talab qildi?

12. **Removal problem.** Talab o'zgardi: `curl` paketi endi kerak emas va `/opt/app/app.env` o'chirilishi kerak. Skriptdan tegishli qatorlarni shunchaki olib tashlasangiz serverda nima bo'ladi? Buni to'g'ri hal qilish uchun skript nimani "eslab qolishi" kerak? 6-bo'limdagi state tushunchasi bilan bog'lang.

13. **Second host.** Ikkinchi VM (`iac2`) yarating. `provision_v2.sh` ni ikkala VM'da ketma-ket ishga tushiradigan `run_all.sh` yozing (ish mashinasida ishlaydi, ichida `multipass transfer` va `multipass exec`). `iac1` ni `multipass stop` qilib ishga tushiring: skript nima qildi, `iac2` ga yetib bordimi? Har host uchun natijani alohida ko'rsatadigan xulosa chiqaring.

### C. cloud-init

14. **cloud-init file.** 7-vazifadagi yakuniy holatni `cloud-init.yaml` (`#cloud-config`) bilan ifodalang: `users`, `packages`, `write_files`, kerak bo'lsa `runcmd`. Yangi VM'ni `--cloud-init` bilan ko'taring. `cloud-init status --wait` va `/var/log/cloud-init-output.log` orqali tugaganini tekshiring, keyin har talabni qo'lda tasdiqlang. Bash variantiga nisbatan necha qator?

15. **cloud-init schema error.** Faylda kalit nomini ataylab buzing (masalan `packages` o'rniga `pakages`) va VM ichida `cloud-init schema --config-file` bilan tekshiring. Keyin shu buzilgan fayl bilan yangi VM ko'taring: VM ishga tushdimi, paketlar o'rnatildimi, `cloud-init status --long` nima deydi? Xato qanchalik "baland ovozda" bildirildi?

16. **cloud-init runs once.** Ishlab turgan VM uchun `cloud-init.yaml` ga yangi paket qo'shdingiz deylik. Uni VM'ga qanday qo'llaysiz? `multipass restart` dan keyin `runcmd` qayta ishladimi, buni qaysi log yoki fayl orqali isbotladingiz? cloud-init modullarining ishlash chastotasi (per-instance, per-boot) haqida hujjatdan topib yozing.

17. **Pain summary.** Jadval tuzing. Qatorlar: idempotency, dry-run, diff ko'rsatish, bir nechta host, qisman muvaffaqiyatsizlik, olib tashlash (removal), secret'lar, xatoni o'qish qulayligi. Ustunlar: bash, cloud-init. Har katakka o'z tajribangizdan bir jumla. Bu jadvalga 2-dars va 4-dars oxirida Ansible va Terraform ustunlarini qo'shasiz.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza (skriptlar ShellCheck'dan o'tadi).
2. `provision_v1.sh`, `provision_v2.sh`, `run_all.sh`, `cloud-init.yaml` ish papkasida.
3. Barcha VM'lar o'chirilgan: `multipass list` bo'sh.
4. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Drift nima va qo'lda boshqariladigan muhitda nima uchun uni payqash qiyin?
- Idempotent operatsiya nima? "Ikkinchi marta xatosiz ishladi" nima uchun yetarli mezon emas?
- Declarative asbob joriy holatni hisobga olishni kimning zimmasiga oladi va bu nimani osonlashtiradi?
- Provisioning va configuration management chegarasi qayerda, nima uchun bitta asbob ikkalasini ham yaxshi qilmaydi?
- State nima uchun kerak? Usiz asbob qaysi savolga javob bera olmaydi?
- Push va pull modellarining har biri qaysi holatda qulayroq?
- Immutable infratuzilma drift muammosini qanday yechadi va buning narxi nima?
- cloud-init nima uchun "day 0" asbobi deyiladi?
- Terraform va OpenTofu litsenziyalari orasidagi farq amalda kimga ta'sir qiladi?
