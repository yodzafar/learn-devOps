# Infrastructure as Code o'quv rejasi (Ansible, Terraform)

Ishlash tartibi: men nazariya va vazifalar beraman, siz playbook, role va `.tf` fayllarni o'zingiz yozasiz, men tekshirib xatolar va idiomalarni ko'rsataman.
Har dars uchun alohida papka: `iac/01-intro/`, `iac/02-ansible-basics/` va hokazo. Yaratish: `make new m=iac n=01 name=intro`.

Bu modul `linux`, `git`, `network`, `docker`, `cloud` va `cicd` modullaridan keyin keladi. Cloud modulida konsol va CLI bilan qo'lda qurgan muhitingizni (VPC, subnet, security group, EC2, S3, app server) endi kod bilan quramiz: Ansible server ichini, Terraform server tashqarisini boshqaradi.

## Vaqt hisobi

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. Darslar hech narsani oldindan ma'lum deb hisoblamaydi: idempotency, state, inventory, modul, handler, Jinja2, role va Vault noldan tushuntiriladi. Haqiqiy ko'prik bo'lgan joylarda frontend tajribasiga bog'lanadi (React reconciliation va declarative model, lockfile va state).

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har dars muddati shu darsning `Taxminiy vaqt` qatoridan olingan.

| Bosqich | Dars | Siz uchun |
|---------|------|-----------|
| I - Tushunchalar | 1. Umumiy ma'lumot | 3 kun |
| **I jami** | | **3 kun** |
| II - Ansible | 2. Ansible asoslari | 6 kun |
| II - Ansible | 3. Ansible role'lar | 6 kun |
| **II jami** | | **12 kun** |
| III - Terraform | 4. Terraform asoslari | 8 kun |
| III - Terraform | 5. State va modullar | 8 kun |
| **III jami** | | **16 kun** |
| **Modul jami** | **5 dars** | **31 kun, haftasiga 5 o'quv kuni bilan 6 hafta va 1 kun** |

Qayerga vaqt ketadi: I bosqichda idempotent bash yozish va cloud-init; II bosqichda SSH, privilege escalation, handler, o'zgaruvchi precedence va Vault; III bosqichda state, drift va import amaliyoti, ularni qisqartirib bo'lmaydi.

Muhim izohlar:
- Terraform AWS vazifalari pul sarflashi mumkin. Har mashg'ulot `terraform destroy` va o'chirilganini tekshirish bilan tugaydi. Resurs yoqilgan holda kunni tugatmang.
- Mavzuni "o'rgandim" deyish mezoni: bo'sh VM yoki bo'sh AWS akkauntdan bitta buyruq bilan ishlaydigan muhit ko'tariladi, ikkinchi ishga tushirish hech narsani o'zgartirmaydi (Ansible'da `changed=0`, Terraform'da `No changes`), va siz buni nima uchun shunday ekanini tushuntira olasiz.
- Kubernetes manifestlari, Helm va GitOps ham "kod sifatida infratuzilma", lekin ular Kubernetes modulida o'tiladi.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS 18 (`amd64`), uyda macOS (Apple Silicon, `arm64`). Multipass, Docker va `lab` VM ildizdagi `SETUP.md` bo'yicha har mashinada bir marta o'rnatiladi; bu modul darslari ularni qayta o'rnatmaydi, faqat o'ziga kerakli qo'shimcha VM'larni nomi bilan yaratadi.

| Muhit | Nima uchun | Zorin (ofis) | macOS (uy) | Narx |
|-------|------------|--------------|------------|------|
| Host (control node) | `ansible`, `terraform` (yoki `tofu`) CLI shu yerda ishlaydi, fayllar shu yerda yoziladi | Ansible `pipx` bilan, Terraform rasmiy apt repo'dan (o'rnatish birinchi kerak bo'lgan darsda) | Ansible `brew install ansible` yoki `pipx`, Terraform Homebrew orqali | bepul |
| Multipass VM'lar (Ubuntu 24.04) | Ansible nishonlari, bash va cloud-init tajribalari. Tizimni o'zgartiradigan hamma narsa shu yerda | VM'lar `x86_64` | VM'lar `aarch64` | bepul |
| Lokal Docker | Terraform asoslari Docker provider bilan: state, plan, drift, `count`/`for_each` pulsiz o'rganiladi | Docker Engine, to'g'ridan-to'g'ri host kernel'ida | Docker yashirin Linux VM ichida, image'lar `arm64` | bepul |
| AWS akkaunt | Terraform AWS vazifalari: VPC, subnet, security group, EC2, S3, remote state | CLI kalitlari har mashinada alohida | CLI kalitlari har mashinada alohida | pullik bo'lishi mumkin |

Ikki mashina qoidalari (har dars "Laboratoriya" bo'limida aniq yo'l beriladi):
- VM IP manzillari har mashinada va har qayta yaratishda boshqa. Commit qilinadigan inventory fayllarida IP yozilmaydi: manzillar git-ignore qilingan lokal faylda turadi yoki `multipass` chiqishidan generatsiya qilinadi, repoda faqat namuna (`*.example`) bo'ladi.
- SSH kalitlari, Vault parol fayli, `terraform.tfstate` va AWS kalitlari git orqali ko'chmaydi, ikkinchi mashinada qayta yaratiladi. Shifrlangan `vault.yml`, playbook, role va `.tf` fayllar git orqali ko'chadi.
- Nishon arxitekturasi farq qiladi (`amd64` va `arm64`): binary yuklaydigan yoki apt repo qo'shadigan har qanday task arxitekturani qattiq yozmaydi, uni nishondan aniqlaydi.
- Laboratoriya holati (VM, konteyner, cloud resurs) mashinalar orasida ko'chmaydi. Bu modulda bu kamchilik emas, mashq: muhit koddan bitta buyruq bilan qayta tiklanishi kerak.

AWS qoidalari (cloud modulidagi bilan bir xil):
- Budget alert yoqilgan bo'lsin, AWS vazifasini boshlashdan oldin tekshiring.
- Root emas, IAM user yoki SSO profili; kalitlar `.tf` fayllarga yozilmaydi.
- Eng kichik instans tipi, NAT gateway va load balancer yaratilmaydi (soatbay pullik).
- Hamma resursga `Project = iac-lab` tegi qo'yiladi, tozalik shu teg bo'yicha tekshiriladi.
- `terraform.tfstate`, `*.tfvars` ichidagi secret, vault paroli va SSH kalitlari commit qilinmaydi.

## I bosqich - Tushunchalar

1. **Umumiy ma'lumot**: nima uchun IaC (drift, takrorlanuvchanlik, review), declarative va imperative, provisioning va configuration management, mutable va immutable infratuzilma, idempotency, state, push va pull, asboblar xaritasi (Terraform/OpenTofu, Pulumi, CloudFormation, Ansible, Chef/Puppet/Salt, Packer, cloud-init), Terraform litsenziyasi va OpenTofu. Amaliyot: idempotent bash provisioning skripti va cloud-init fayli, ya'ni asboblar yechadigan og'riqni qo'lda his qilish

## II bosqich - Ansible (configuration management)

2. **Ansible asoslari**: o'rnatish, agentless arxitektura (SSH + Python), inventory (INI, YAML), ad-hoc buyruqlar, modullar, playbook, task, handler, o'zgaruvchilar va precedence, facts, Jinja2 template, loop va `when`, check mode va diff, idempotency va `changed_when`, `ansible.cfg`
3. **Ansible role'lar**: role tuzilishi, Galaxy va collection'lar, `requirements.yml`, `group_vars`/`host_vars`, Ansible Vault, tag'lar, dynamic inventory (`aws_ec2`) ko'rinishi, `ansible-lint`, Molecule ko'rinishi. Amaliyot: cloud modulidagi app serverni tayyorlaydigan role'lar (Docker, foydalanuvchilar, firewall, reverse proxy, compose stack)

## III bosqich - Terraform (provisioning)

4. **Terraform asoslari**: Terraform yoki OpenTofu o'rnatish, HCL, provider, resource, data source, variable/output/local, `init`/`plan`/`apply`/`destroy`, state fayli ichida nima bor, dependency graph, lifecycle, `count` va `for_each`, `fmt`/`validate`. Avval Docker provider (bepul), keyin AWS: VPC + subnet + security group + EC2 + S3
5. **State va modullar**: S3 remote backend va locking, state buyruqlari (`list`/`show`/`mv`/`rm`/`import`), drift detection, workspace va directory-per-environment, modul yozish va versiyalash, registry modullari, state ichidagi secret'lar, tflint va config skanerlash (trivy/checkov), CI'da Terraform (PR'da plan, merge'da apply), Terraform + Ansible birga. Mini-loyiha: bitta buyruq butun muhitni quradi, bitta buyruq o'chiradi

## Yakuniy natija

Moduldan keyin siz:
- Serverni qo'lda sozlash o'rniga playbook va role yozasiz, uni `ansible-lint` dan o'tkazasiz va takroriy ishga tushirishda `changed=0` bo'lishini ta'minlaysiz.
- Secret'larni Ansible Vault bilan shifrlab repoda saqlaysiz va ular log'ga chiqmasligini nazorat qilasiz.
- AWS tarmog'i va serverini Terraform bilan yaratasiz, `plan` chiqishini o'qib "in-place update" va "replace" ni ajratasiz.
- State nima ekanini, nima uchun remote va lock'li bo'lishi kerakligini bilasiz; resurs nomini o'zgartirish, import qilish va drift'ni aniqlashni state'ni buzmasdan bajarasiz.
- Takrorlanadigan qismni modulga ajratasiz, dev va stage muhitlarini bir xil koddan turli parametr bilan ko'tarasiz.
- Pipeline'da PR uchun `plan`, merge uchun `apply` ishlaydigan oqim qurasiz.
- Qaysi vazifa uchun qaysi asbob (Terraform, Ansible, cloud-init, Packer) to'g'ri kelishini asoslab tanlaysiz.

## Ataylab kiritilmagan

- Pulumi, CloudFormation/CDK, Chef, Puppet, Salt: 1-darsda faqat xaritada. Tushunchalar bir xil, sintaksis boshqa.
- Packer bilan image qurish amaliyoti: 1-darsda tushuncha sifatida, amaliyot kerak bo'lsa alohida so'rang.
- Terragrunt, Terraform Cloud/HCP, Atlantis, Sentinel/OPA policy: jamoa miqyosidagi asboblar, asosiy mexanizmlarni bilgach o'rganish oson.
- O'z Terraform provider'ingizni yozish: `learn-golang` rejasida (cloud-native bosqichi).
- Ansible AWX/Automation Platform, Windows nishonlari, tarmoq uskunalari modullari.
- Kubernetes resurslarini Terraform bilan boshqarish, Helm, GitOps (Argo CD, Flux): Kubernetes modulida.

## Manbalar

- Kief Morris, "Infrastructure as Code" (3-nashr, O'Reilly): tushunchalar va patternlar, I bosqich uchun
- Yevgeniy Brikman, "Terraform: Up & Running" (3-nashr, O'Reilly): III bosqich uchun asosiy kitob
- Jeff Geerling, "Ansible for DevOps": II bosqich uchun amaliy kitob
- Ansible hujjatlari: https://docs.ansible.com/ansible/latest/
- Terraform hujjatlari: https://developer.hashicorp.com/terraform/docs
- OpenTofu hujjatlari: https://opentofu.org/docs/
- Terraform Registry (provider va modul hujjatlari): https://registry.terraform.io/
- cloud-init hujjatlari: https://cloudinit.readthedocs.io/en/latest/
- Multipass hujjatlari: https://documentation.ubuntu.com/multipass/
