# 3-dars: Ansible role'lar, Vault va app server

Maqsad: bitta fayldagi playbook'dan qayta ishlatiladigan, tekshiriladigan loyiha tuzilishiga o'tish. Noldan o'rganasiz: role nima va uning papkalari (`tasks`, `handlers`, `templates`, `files`, `defaults`, `vars`, `meta`), `group_vars` va `host_vars`, collection'lar va `requirements.yml`, Ansible Vault (nima shifrlanadi va secret qayerda baribir ochiq ko'rinadi), tag'lar, `ansible-lint`. Dynamic inventory va Molecule bilan tanishuv darajasida. Dars oxirida cloud modulida qo'lda sozlagan app serveringizni (Docker, foydalanuvchilar, firewall, reverse proxy, compose stack) bo'sh VM'dan bitta buyruq bilan tayyorlaydigan role'lar to'plamini yozasiz. 5-darsda aynan shu role'lar Terraform yaratgan EC2 ustida ishlaydi. Frontend tajribangizga eng yaqin o'xshatish: role bu qayta ishlatiladigan komponent yoki paket, uning `defaults` fayli esa props'ning standart qiymatlari.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun 1-2 bo'limlar va A guruh vazifalari, ikkinchi kun 3-4 bo'limlar va B, C guruhlari, uchinchi kun 5-7 bo'limlar va D guruhi, to'rtinchi kun 8-bo'lim, "Birga bajaramiz" va 16-17 vazifalar, beshinchi kun 18-20 vazifalar, oltinchi kun 21-vazifa, lint'ni tozalash va README. Diqqatni quyidagilarga qarating: `defaults` va `vars` farqi, secret qayerlarda ochiq holda paydo bo'ladi (log, nishondagi fayl, diff), firewall va SSH sozlamalarini o'zgartirishda o'zingizni tashqarida qoldirmaslik, Docker va UFW o'zaro ta'siri, ikki mashinada VM arxitekturasi va IP'si farq qilishi.

Qanday o'qish kerak: har bo'limdagi misolni o'z ish papkangizda terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi IP, yo'l, versiya va vaqtlar farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi. Nazariyadagi misollar vazifalardagidan boshqa holatda, ularni o'z vazifangizga o'zingiz moslaysiz.

## Laboratoriya

Muhit 2-darsdagidek. **Control node** (Ansible o'rnatilgan va buyruq beradigan mashina) bu host: Zorin yoki macOS. **Managed node** (Ansible sozlaydigan server, "nishon") bu Multipass VM. Bu darsda bitta yangi VM yetarli, nomi `app1`. U 2-darsdan qolgan `lab-init.yaml` cloud-init fayli bilan yaratiladi (cloud-init: VM birinchi yuklanishda bajaradigan sozlash fayli, bizda u `~/.ssh/iac_lab.pub` public kalitini `ubuntu` foydalanuvchisiga qo'yadi). `SETUP.md` dagi `lab` VM bu darsda ishlatilmaydi, unga tegmang.

```
multipass launch 24.04 --name app1 --cpus 2 --memory 2G --disk 10G --cloud-init lab-init.yaml
multipass list
```

`app1` ko'p marta o'chirib qayta yaratiladi, shuning uchun yaratishni bir qatorli buyruq yoki kichik skriptga oling. Bu buyruq ikkala host'da bir xil ishlaydi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | control node: `ansible-playbook`, `ansible-vault`, `ansible-lint`, `git`, `make`, `multipass`, tashqaridan `curl` va `nc` |
| `app1` VM | `ubuntu@app1:~$` | managed node: tekshiruv buyruqlari (`sudo ufw status`, `docker ps`, `sshd -T`, `iptables -S`) |

Qo'shimcha asbob: `ansible-lint` (hujjat: https://docs.ansible.com/projects/lint/installing/).

```
# Zorin
pipx install ansible-lint
# macOS (either one)
brew install ansible-lint
pipx install ansible-lint
# both
ansible-lint --version
```

15-vazifadagi `aws_ec2` plugin Ansible ishlayotgan Python muhitida `boto3` va `botocore` kutubxonalarini talab qiladi. Avval bor-yo'qligini tekshiring: `ansible --version` chiqishidagi `python version = ... (<yo'l>)` qatoridan interpreter yo'lini oling va `<yo'l> -c "import boto3; print(boto3.__version__)"` ni bajaring. Versiya chiqsa hech narsa kerak emas. `ModuleNotFoundError` chiqsa:

```
# Ansible installed with pipx (Zorin, or macOS with pipx)
pipx inject ansible boto3 botocore
```

`pipx inject` faqat pipx bilan o'rnatilgan Ansible'ga ta'sir qiladi. Mac'da Ansible Homebrew bilan o'rnatilgan va tekshiruv xato bergan bo'lsa, Homebrew muhitiga paket qo'shishning barqaror yo'li yo'q: 15-vazifa uchun Ansible'ni pipx'ga ko'chiring (`brew uninstall ansible`, `brew install pipx`, `pipx install --include-deps ansible`, keyin yuqoridagi `inject`).

Xavfsizlik: firewall, SSH sozlamalari va Docker faqat `app1` ichida o'zgartiriladi, host'da emas. SSH'ni buzib qo'ysangiz VM'ga `multipass shell app1` orqali kirish mumkin (u sizning SSH kalitingiz va UFW qoidalaringizga bog'liq emas), eng yomon holatda VM'ni o'chirib qayta yarating. Dynamic inventory vazifasi (15) AWS'ga faqat o'qish so'rovlari yuboradi, resurs yaratmaydi, shuning uchun xarajat yo'q; AWS credential'lari har mashinada alohida sozlanadi va repoga hech qachon tushmaydi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | `app1` arxitekturasi `x86_64` (apt tilida `amd64`). VM IP'si odatda `10.x.x.x`. Host Linux, lekin UFW va Docker tajribalari baribir faqat VM ichida. |
| macOS (uy) | `app1` arxitekturasi `aarch64` (apt tilida `arm64`). VM IP'si odatda `192.168.x.x`. Host'da `ip`, `ss`, `ufw`, `systemctl` yo'q: bu buyruqlar `multipass exec app1 -- ...` yoki `multipass shell app1` orqali VM ichida bajariladi. `curl`, `nc -zv`, `ssh` host'da bor. Host shell zsh, BSD userland: `sed -i` va `grep -P` kerak bo'lsa VM'da ishlating. |

Ikkinchi mashinada tiklash. Git orqali faqat kod ko'chadi: role'lar, `site.yml`, `ansible.cfg`, shifrlangan `vault.yml`. Ko'chmaydigan va qo'lda qayta yaratiladigan narsalar:

1. SSH kaliti `~/.ssh/iac_lab` har mashinada o'ziniki. Yo'q bo'lsa 2-dars "Laboratoriya" bo'limi bo'yicha yarating, `lab-init.yaml` shu mashinaning public kalitini o'z ichiga olishi kerak.
2. `app1` VM: yuqoridagi `multipass launch` buyrug'i.
3. `inventory/hosts.local.yml`: shu mashinadagi `app1` IP'si bilan (2-bo'lim).
4. Vault parol fayli `~/.config/iac-lab/vault-pass`: birinchi mashinadagi **aynan o'sha parol** bilan qo'lda yarating va `chmod 600` qiling. Parol boshqa bo'lsa `vault.yml` ochilmaydi.
5. Collection'lar: `ansible-galaxy collection install -r requirements.yml`.
6. `ansible-playbook site.yml`: VM holati kod orqali tiklanadi, bu darsning asosiy g'oyasi ham shu.

Tozalash: `multipass delete --purge app1`. Keyin `multipass list` da `app1` yo'q, `lab` joyida.

---

## 1. Role

### Bu nima

2-darsda hamma narsa bitta `web.yml` faylida edi: task'lar, handler, o'zgaruvchilar, yonida template. Ikkinchi server turi paydo bo'lganda bu fayl ko'chirib ko'paytiriladi va nusxalar ajralib ketadi. **Role** bu bitta mas'uliyatga (masalan "nginx o'rnatish va sozlash") oid task, handler, template, fayl va o'zgaruvchilarning standart papka tuzilishidagi to'plami. Uni istalgan playbook bitta qator bilan ulaydi. Frontend'dagi haqiqiy o'xshashi: qayta ishlatiladigan komponent yoki npm paket. Papka tuzilishi bu konvensiya (Next.js'dagi `app/` papkasi kabi: fayl nomi va joyi ma'no beradi), `defaults` esa props'ning standart qiymatlari.

### Mexanizm: papkalar va qidiruv

```
roles/
  nginx/
    tasks/main.yml        # task list, the entry point
    handlers/main.yml     # handlers
    templates/            # *.j2, found by the template module without a path
    files/                # static files, found by the copy module without a path
    defaults/main.yml     # low-priority variables (the role's public API)
    vars/main.yml         # high-priority variables (internal constants)
    meta/main.yml         # metadata, dependencies
```

Play'da `roles: [nginx]` yozilganda Ansible quyidagilarni qiladi. Role'ni playbook yonidagi `roles/` papkasidan, keyin `~/.ansible/roles`, `/usr/share/ansible/roles`, `/etc/ansible/roles` dan qidiradi. Topilgan papkada `defaults/main.yml` va `vars/main.yml` ni o'zgaruvchi sifatida yuklaydi, `handlers/main.yml` ni play'ning handler ro'yxatiga qo'shadi, `tasks/main.yml` dagi task'larni play'ga joylaydi. Role ichidagi `template` moduli `src: site.conf.j2` ni avval shu role'ning `templates/` papkasidan, `copy` moduli `src` ni `files/` dan qidiradi. Shuning uchun role ichida yo'l yozilmaydi, faqat fayl nomi. Mavjud bo'lmagan papka xato emas: Ansible faqat bor narsani o'qiydi.

### defaults va vars

Ikkalasi ham o'zgaruvchi fayli, farq precedence'da (2-dars: o'zgaruvchilar ustunligi tartibi). Soddalashtirilgan zanjir, pastdan yuqoriga:

```
role defaults  <  group_vars/all  <  group_vars/<group>  <  host_vars/<host>
               <  play vars  <  role vars  <  task vars  <  extra vars (-e)
```

- `defaults/main.yml` eng past daraja. Bu role'ning "parametrlari": foydalanuvchi `group_vars`, `host_vars` yoki play `vars` orqali ustidan yozadi.
- `vars/main.yml` yuqori daraja, inventory o'zgaruvchilaridan va play `vars` dan ustun. Bu role'ning ichki konstantalari (paket nomi, config yo'li). Ularni tashqaridan faqat role parametri (`- role: x` ostidagi `vars:`) yoki `-e` bilan o'zgartirish mumkin.

Role o'zgaruvchilari global nomlar fazosida yashaydi: role'ning o'z "scope"i yo'q. Shuning uchun nomga role nomi prefiks qilib qo'yiladi: `nginx_http_port`, `docker_users`. `port` degan nom ikki role'da jimgina to'qnashadi.

### Misol: skelet yaratish

Boshqa bir role uchun, masalan vaqt sinxronizatsiyasi (`chrony`):

```
$ ansible-galaxy role init --init-path roles chrony
- Role chrony was created successfully
$ ls roles/chrony
README.md  defaults  files  handlers  meta  tasks  templates  tests  vars
$ cat roles/chrony/tasks/main.yml
#SPDX-License-Identifier: MIT-0
---
# tasks file for chrony
```

Qatorma-qator: `ansible-galaxy role init` hech narsa yuklab olmaydi, faqat mahalliy papkalar yasaydi; `--init-path roles` qayerga yasashni aytadi. `ls` sakkizta papka va `README.md` ni ko'rsatadi. `tests/` Galaxy'ga nashr qilinadigan role'lar uchun namuna test, bizga kerak emas. Har `main.yml` deyarli bo'sh: faqat `---` (YAML hujjat boshi) va komment (birinchi qator litsenziya belgisi, sizdagi versiyada bo'lmasligi mumkin). Kerak bo'lmagan papkalarni o'chiring, bo'sh `main.yml` lar shovqin.

### Role'ni ishlatish va bajarilish tartibi

```
- name: Configure app servers
  hosts: app
  become: true
  roles:
    - base
    - role: chrony
      vars:
        chrony_pool: "pool.ntp.org"
```

`roles:` ro'yxati yuqoridan pastga bajariladi. `- role: chrony` ostidagi `vars:` bu role parametri, u `defaults` va hatto `vars/main.yml` dan ham ustun. Task ichidan ulash ham mumkin: `ansible.builtin.import_role` (statik: playbook o'qilayotganda joylanadi) yoki `ansible.builtin.include_role` (dinamik: bajarilish paytida, `when` va `loop` butun role'ga qo'llanadi).

Play ichidagi tartib qat'iy: `pre_tasks`, `roles`, `tasks`, `post_tasks`, faylda qanday ketma-ketlikda yozilganidan qat'i nazar. Handler'lar (2-dars: `notify` qilingan va faqat o'zgarish bo'lganda ishlaydigan task) uch nuqtada ishga tushadi: `pre_tasks` oxirida, `roles` va `tasks` tugagach, `post_tasks` oxirida. Handler nomlari butun play uchun umumiy: bir role boshqa role handler'iga `notify` qila oladi, shuning uchun nomlar noyob bo'lsin (`Reload nginx`, shunchaki `reload` emas). Chiqishda role task'lari `TASK [chrony : Install chrony]` ko'rinishida, role nomi prefiksi bilan chiqadi.

`meta/main.yml` dagi `dependencies` ro'yxati role'dan oldin avtomatik bajariladigan role'larni belgilaydi. Yashirin bog'liqlik o'qishni qiyinlashtiradi; kichik loyihada tartibni play'ning `roles:` ro'yxatida ochiq yozish afzal.

### Real ishda qachon kerak

Ikkinchi playbook paydo bo'lgan zahoti. Bitta `docker` role'i app serverda ham, CI runner'da ham, monitoring serverida ham ishlatiladi; farq faqat `group_vars` dagi qiymatlarda. Yangi hamkasb loyihani ochganda `roles/` papkasidagi nomlardan server nimalardan tashkil topganini bir qarashda ko'radi.

### Nima uchun shunday

Ansible'ning ilk versiyalarida qayta ishlatish faqat `include` orqali edi va har jamoa o'z papka tuzilishini o'ylab topardi. Role konvensiyasi buni standartlashtirdi: fayl joyi ma'no bergani uchun konfiguratsiya yozish kerak emas va begona role'ni ochganda nima qayerda ekanini bilasiz. `defaults` va `vars` ning ikki darajaga ajratilishi ataylab: role muallifi "buni o'zgartiring" va "bunga tegmang" degan ikki xil niyatni fayl joyi bilan ifodalaydi. Muqobili: bitta katta playbook va `include_tasks`. Kichik bir martalik ish uchun bu yetarli, lekin parametrlar va fayllar bilan birga ko'chirib bo'lmaydi.

## 2. Loyiha tuzilishi, group_vars va host_vars

### Bu nima

Loyiha tuzilishi bu `site.yml` (asosiy playbook), inventory, o'zgaruvchilar va role'lar qaysi papkada yotishi haqidagi kelishuv. `group_vars` va `host_vars` esa o'zgaruvchilarni playbook'dan ajratib, "qaysi guruh yoki host uchun" degan savol bo'yicha fayllarga joylash usuli. Shunda role'lar umumiy bo'lib qoladi, faqat qiymatlar farq qiladi.

```
ansible.cfg
requirements.yml
site.yml
.gitignore
inventory/
  hosts.yml                    # committed: names, groups, connection vars, NO addresses
  hosts.local.yml              # git-ignored: this machine's real IPs
  hosts.local.yml.example      # committed: same shape, placeholders
  group_vars/
    all/
      vars.yml
      vault.yml
    app.yml
  host_vars/
    app1.yml
roles/
  base/  firewall/  docker/  reverse_proxy/  app/
```

### Mexanizm: Ansible o'zgaruvchi fayllarini qanday topadi

Ansible inventory manbasi yonidagi `group_vars/` va `host_vars/` papkalarini o'zi o'qiydi, hech qayerda ulash kerak emas. `group_vars/<group>.yml` yoki `group_vars/<group>/` papkasi (ichidagi barcha fayllar o'qiladi va birlashtiriladi) shu guruh hostlariga qo'llanadi, `host_vars/<host>` bitta hostga. `all` har doim mavjud bo'lgan, barcha hostlarni o'z ichiga olgan guruh. Host bir nechta guruhda bo'lsa: `all` eng past, ota guruh boladan past, `host_vars` hammasidan ustun. Bu papkalar playbook yonida ham bo'lishi mumkin; bitta joyni tanlang, bizda inventory yoni.

### Ikki mashina: IP repoga yozilmaydi

`app1` ning IP'si Zorin'da bitta, Mac'da boshqa, VM qayta yaratilganda yana o'zgaradi. Shuning uchun 2-darsdagi konvensiya davom etadi: commit qilinadigan `hosts.yml` da nomlar, guruhlar va ulanish o'zgaruvchilari bor, haqiqiy manzil yo'q. Manzil nomida `.local.` bo'lgan, git ko'rmaydigan faylda yashaydi. Frontend'dagi `.env.local` va `.env.example` juftligi bilan aynan bir xil g'oya.

```
# inventory/hosts.yml (committed)
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/iac_lab
  children:
    app:
      hosts:
        app1:
```

```
# inventory/hosts.local.yml (git-ignored) and hosts.local.yml.example (committed, with <APP1_IP>)
all:
  hosts:
    app1:
      ansible_host: 10.123.45.67
```

```
# ansible.cfg
[defaults]
inventory = inventory/hosts.yml,inventory/hosts.local.yml
roles_path = roles
```

```
# .gitignore in iac/03-ansible-roles/
*.local.*
!*.example
```

`inventory` sozlamasi vergul bilan ajratilgan bir nechta manbani qabul qiladi; Ansible ularni tartib bilan o'qib, bitta inventory'ga birlashtiradi: birinchi fayl `app1` ni `app` guruhiga qo'yadi, ikkinchisi unga `ansible_host` qo'shadi. Butun `inventory/` papkasini manba qilmaymiz, chunki u holda `.example` fayli va 6-bo'limdagi `aws_ec2` fayli ham har ishga tushirishda o'qilardi. `.gitignore` dagi ikkinchi qator kerak, chunki `hosts.local.yml.example` nomi ham `*.local.*` ga mos keladi.

IP'ni qo'lda ko'chirmaslik uchun Multipass'ning mashina o'qiydigan chiqishidan foydalaning:

```
$ multipass list --format csv
Name,State,IPv4,IPv6,Release,AllIPv4
app1,Running,10.123.45.67,,Ubuntu 24.04 LTS,10.123.45.67
lab,Running,10.123.45.12,,Ubuntu 24.04 LTS,10.123.45.12
$ multipass list --format csv | awk -F, '$1=="app1"{print $3}'
10.123.45.67
```

Birinchi qator ustun nomlari, keyin har VM bitta qator. `awk -F,` vergulni ajratuvchi qiladi, birinchi ustuni `app1` bo'lgan qatorning uchinchi ustunini (asosiy IPv4) chiqaradi; bu forma GNU va BSD `awk` da bir xil ishlaydi. Docker o'rnatilgach `AllIPv4` ustunida `172.17.0.1` kabi qo'shimcha manzillar paydo bo'ladi, sizga uchinchi ustun kerak. Muqobil: `multipass info app1 --format json`. Shu buyruq asosida `hosts.local.yml` ni yozadigan kichik skriptni o'zingiz tuzing.

### Misol: yakuniy qiymatni ko'rish

```
$ ansible-inventory --graph
@all:
  |--@ungrouped:
  |--@app:
  |  |--app1
$ ansible-inventory --host app1
{
    "ansible_host": "10.123.45.67",
    "ansible_ssh_private_key_file": "~/.ssh/iac_lab",
    "ansible_user": "ubuntu",
    "chrony_pool": "pool.ntp.org"
}
```

`--graph`: `@` belgisi guruhni bildiradi; `all` ildiz, `ungrouped` hech bir guruhga kirmagan hostlar uchun (bo'sh), `app` ichida `app1`. `--host app1`: shu host uchun barcha manbalardan yig'ilgan va precedence bo'yicha hal qilingan qiymatlar. `ansible_host` `hosts.local.yml` dan, keyingi ikkitasi `hosts.yml` dagi `all.vars` dan, `chrony_pool` `group_vars` dan keldi. Role `defaults` bu yerda ko'rinmaydi: ular inventory'ga emas, role'ga tegishli va faqat play paytida yuklanadi. `hosts.local.yml` yo'q bo'lsa Ansible ogohlantirish beradi va `app1` nomini DNS orqali topishga urinadi: `UNREACHABLE`.

VM qayta yaratilganda IP takrorlansa SSH "REMOTE HOST IDENTIFICATION HAS CHANGED" deydi, chunki yangi VM'ning host kaliti boshqa. Eski yozuvni o'chirish: `ssh-keygen -R <IP>` (ikkala host'da ishlaydi).

### Real ishda qachon kerak

Muhitlar (dev, staging, prod) odatda alohida inventory papkalari bilan ajratiladi: `inventory/dev/`, `inventory/prod/`, har birida o'z `group_vars`. Role'lar umumiy, `-i inventory/prod` bilan faqat qiymatlar almashadi. "Prod'da port nima uchun boshqa" degan savolga javob bitta `git diff` da ko'rinadi.

### Nima uchun shunday

Qiymatlar playbook ichida yozilsa, har muhit uchun playbook nusxasi kerak bo'ladi. Ansible "kod" (role, playbook) va "ma'lumot" (inventory, o'zgaruvchilar) ni ajratadi, bu React'da komponent va props'ni ajratish bilan bir xil sabab. Fayl nomi orqali avtomatik yuklash esa ortiqcha `import` qatorlarini yo'q qiladi, narxi: qiymat qayerdan kelganini bilish uchun precedence'ni bilish kerak, shuning uchun `ansible-inventory --host` ni odat qiling. Manzilni alohida `.local.` faylga chiqarish ikki mashina sababli: commit qilingan IP ikkinchi mashinada har doim noto'g'ri bo'lardi.

## 3. Galaxy va collection'lar

### Bu nima

- **Collection**: modullar, plugin'lar va role'lar paketi, nomi `namespace.name` (`community.docker`). Modulning to'liq nomi (FQCN, masalan `community.docker.docker_compose_v2`) ning birinchi ikki qismi shu collection.
- **Ansible Galaxy** (https://galaxy.ansible.com): collection va role'lar ombori, Ansible uchun npm registry. `ansible-galaxy` CLI undan yoki git'dan o'rnatadi.

### Mexanizm

`ansible` paketi (pipx yoki Homebrew bilan o'rnatganingiz) ikki qismdan iborat: `ansible-core` (dvigatel va `ansible.builtin` modullari) va o'nlab collection'lar to'plami. Ular Ansible'ning Python muhitidagi `ansible_collections/` papkasida yotadi. `ansible-galaxy collection install` esa standart holda `~/.ansible/collections/ansible_collections/` ga o'rnatadi. Modul chaqirilganda Ansible collection'ni sozlangan yo'llar ro'yxatidan tartib bilan qidiradi; ro'yxatni `ansible-config dump | grep COLLECTIONS_PATHS` ko'rsatadi.

Loyiha bog'liqliklari `requirements.yml` da yoziladi. Bu `package.json` ning haqiqiy o'xshashi: nom va versiya oralig'i. Farqi: lock fayl yo'q, shuning uchun takrorlanuvchanlik uchun oraliqni tor yoki aniq versiya bilan yozasiz.

```
# requirements.yml
collections:
  - name: community.docker
    version: ">=5.0.0,<6.0.0"
  - name: community.general
  - name: ansible.posix
```

Versiya oralig'ini Galaxy sahifasidagi joriy relizga qarab o'zingiz belgilang, yuqoridagi raqamlar faqat sintaksis namunasi. Collection'lar semantic versioning'ga amal qiladi: major reliz modul parametrlarini olib tashlashi mumkin.

### Misol

```
$ ansible-galaxy collection install -r requirements.yml
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Downloading https://galaxy.ansible.com/api/v3/<...>/community-docker-<X.Y.Z>.tar.gz to <tmp>
Installing 'community.docker:<X.Y.Z>' to '/home/<user>/.ansible/collections/ansible_collections/community/docker'
community.docker:<X.Y.Z> was installed successfully
<...>
$ ansible-galaxy collection list community.docker

# /home/<user>/.ansible/collections/ansible_collections
Collection       Version
---------------- -------
community.docker <X.Y.Z>

# <ansible python env>/site-packages/ansible_collections
Collection       Version
---------------- -------
community.docker <A.B.C>
```

Qatorma-qator: "dependency map" bosqichida Galaxy'dan versiyalar ro'yxati olinadi va oraliqqa mos eng yangisi tanlanadi; `Downloading` arxivni yuklaydi; `Installing ... to` qayerga ochilganini aytadi (`namespace/name` papka tuzilishiga e'tibor bering). `collection list` ikki bo'lim ko'rsatdi: `#` bilan boshlangan qator yo'l, ostida o'sha yo'ldagi versiya. Demak bir xil collection ikki joyda, ikki xil versiyada turibdi. Mac'da birinchi yo'l `/Users/<user>/.ansible/...`, ikkinchisi pipx yoki Homebrew papkasi.

Role'lar ham shu faylda `roles:` kaliti ostida yoziladi va `ansible-galaxy role install -r requirements.yml` bilan o'rnatiladi.

### Real ishda qachon kerak

Har loyihada: CI runner va hamkasbning noutbuki siz bilan bir xil modul versiyasini ishlatishi uchun. Ikkinchi mashinangizda ham birinchi qadam shu fayldan o'rnatish. Galaxy'dagi tayyor role'ga kelsak: u begona kod va serveringizda `root` sifatida ishlaydi. Ishlatishdan oldin `tasks/` ni o'qing, versiyani qat'iy belgilang. Tayyor role ko'pincha siz xohlagandan ko'p narsa qiladi (o'nlab OS, yuzlab parametr); kichik vazifa uchun o'z role'ingiz tushunarliroq.

### Nima uchun shunday

Ansible 2.9 gacha barcha modullar bitta repoda va bitta relizda edi: AWS moduli tuzatilishi uchun butun Ansible relizini kutish kerak bo'lardi. 2.10 dan modullar collection'larga ajratildi, har biri o'z jadvalida chiqadi. FQCN shundan kelib chiqqan: `docker_container` degan qisqa nom ikki collection'da bo'lishi mumkin, to'liq nom esa bir ma'noli. Narxi: bog'liqliklarni endi o'zingiz boshqarasiz, `requirements.yml` shu uchun.

## 4. Ansible Vault

### Bu nima

App serverga ma'lumotlar bazasi paroli kerak, parol o'zgaruvchi sifatida repoda turishi kerak (aks holda "bitta buyruq bilan qurish" ishlamaydi), lekin ochiq matnda commit qilib bo'lmaydi. **Ansible Vault** fayl yoki alohida qiymatni parol bilan shifrlaydi; repoda shifrlangan matn saqlanadi, Ansible ishga tushganda uni xotirada ochadi.

### Mexanizm

Vault parolingizdan kalit hosil qiladi (PBKDF2, tasodifiy salt bilan), ma'lumotni AES-256 bilan shifrlaydi va butunlikni HMAC bilan himoyalaydi. Natija oddiy matn fayli: birinchi qator sarlavha, qolgani hex raqamlar. Ansible o'zgaruvchi fayllarini o'qiyotganda sarlavhani ko'rsa, berilgan parol bilan faylni **control node xotirasida** ochadi; diskdagi fayl shifrlangan holicha qoladi. Parol uch usulda beriladi: `--ask-vault-pass` (so'raydi), `--vault-password-file <fayl>`, yoki `ansible.cfg` dagi sozlama.

```
ansible-vault create inventory/group_vars/all/vault.yml     # new encrypted file, opens $EDITOR
ansible-vault edit inventory/group_vars/all/vault.yml       # decrypt to temp file, edit, re-encrypt
ansible-vault view inventory/group_vars/all/vault.yml       # print decrypted content
ansible-vault encrypt_string 's3cr3t' --name 'vault_db_password'   # encrypt a single value
ansible-vault rekey inventory/group_vars/all/vault.yml      # change the password
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file ~/.config/iac-lab/vault-pass
```

### Misol

```
$ ansible-vault create inventory/group_vars/all/vault.yml
New Vault password:
Confirm New Vault password:
$ cat inventory/group_vars/all/vault.yml
$ANSIBLE_VAULT;1.1;AES256
38656438643163356466653832363137623762336332646132353731356136383132656136326538
3539613136306631306166366166343063<...>
$ ansible-vault view inventory/group_vars/all/vault.yml
Vault password:
vault_api_token: "demo-token-123"
```

Qatorma-qator: `create` parolni ikki marta so'raydi va `$EDITOR` dagi muharrirni ochadi (o'rnatilmagan bo'lsa `vi`; `EDITOR=nano ansible-vault create ...` deb berish mumkin). `cat` diskdagi haqiqiy holatni ko'rsatadi: `$ANSIBLE_VAULT` format belgisi, `1.1` format versiyasi, `AES256` shifr; keyingi qatorlar salt, HMAC va shifrlangan matnning hex ko'rinishi. Fayl ichida nechta o'zgaruvchi borligini, hatto ularning nomlarini ham bilib bo'lmaydi. `view` parolni so'rab, ochilgan YAML'ni ekranga chiqaradi, diskka yozmaydi. Har `edit` dan keyin butun fayl qaytadan shifrlanadi (yangi salt), shuning uchun `git diff` hamma qatorni o'zgargan deb ko'rsatadi.

Tavsiya etilgan pattern: shifrlangan `vault.yml` da `vault_` prefiksli o'zgaruvchilar, ochiq `vars.yml` da ularga havola:

```
# vars.yml (plain)
app_db_password: "{{ vault_app_db_password }}"
# vault.yml (encrypted)
vault_app_db_password: "..."
```

Shunda `grep -r app_db_password` o'zgaruvchi qayerda aniqlanganini shifrlangan faylni ochmasdan topadi, role'lar esa `vault_` nomlarini bilmaydi.

### Vault nimani himoya qilmaydi

Vault faqat **repodagi faylni** himoya qiladi. Ansible qiymatni ochgandan keyin u oddiy o'zgaruvchi. Secret ochiq holda paydo bo'ladigan joylar:

- **Chiqish va log**: `-v` rejimida task natijasi va argumentlari, `debug` moduli, `--diff` (template ichidagi parol diff'da yangi qator sifatida ko'rinadi). CI'da bu log saqlanadi va ko'pchilik o'qiy oladi. Himoya: task'da `no_log: true` (natija va argumentlar yashiriladi), template task'ida `diff: false`.
- **Nishondagi fayl**: `.env` yoki config serverda ochiq matn, chunki ilova uni o'qishi kerak. Himoya: `mode: "0600"`, to'g'ri `owner`.
- **Vault paroli**: zanjirning eng zaif halqasi. Parol fayli repodan tashqarida (`~/.config/iac-lab/vault-pass`, mode `0600`), CI'da secret sifatida. Kursning ildiz `.gitignore` fayli `.vault_pass*` nomlarini e'tiborsiz qoldiradi, lekin eng ishonchlisi faylni umuman repo papkasida saqlamaslik.

**Tuzoq: `no_log: true` xatoni ham yashiradi.** Task muvaffaqiyatsiz bo'lsa sababi o'rnida "censored" yozuvini ko'rasiz. Debug paytida vaqtincha o'chirib, sinov qiymati bilan ishlating.

Ikki mashina: shifrlangan `vault.yml` git orqali ko'chadi, parol fayli ko'chmaydi. Ikkinchi mashinada uni qo'lda, aynan o'sha parol bilan yarating (parolni parol menejerida saqlang). `rekey` qilsangiz ikkinchi mashinadagi faylni ham yangilang.

### Real ishda qachon kerak

Kichik jamoada va tashqi secret menejer (AWS Secrets Manager, HashiCorp Vault) hali yo'q bo'lganda: DB parollari, API tokenlari, TLS private kalitlari. Jamoa o'sgach Ansible Vault o'rniga yoki uning yoniga tashqi menejer keladi, chunki bitta umumiy parol kimdir ketganda hamma secret'ni almashtirishni talab qiladi.

### Nima uchun shunday

Muqobillar: secret'ni repoga umuman qo'ymaslik (har ishga tushirishda `-e` bilan berish, unutiladi va shell tarixida qoladi) yoki tashqi servis (qo'shimcha infratuzilma). Vault o'rtacha yo'l: secret kod bilan birga versiyalanadi, review'da "o'zgardi" degan fakt ko'rinadi, lekin mazmuni emas. Ansible Vault va HashiCorp Vault nomdosh, lekin boshqa-boshqa mahsulot: birinchisi fayl shifrlash, ikkinchisi tarmoq servisi. Fayl darajasida shifrlashning narxi: diff o'qib bo'lmaydi; `encrypt_string` buni yumshatadi (faqat qiymat shifrlanadi, kalit nomi ochiq), evaziga har qiymat alohida boshqariladi.

## 5. Tag'lar

### Bu nima

To'liq `site.yml` bir necha daqiqa ishlaydi, siz esa faqat bitta config faylni o'zgartirdingiz. **Tag** bu task, block, role yoki play'ga yopishtiriladigan yorliq; ishga tushirishda yorliq bo'yicha task'larni tanlash yoki tashlab ketish mumkin.

```
- name: Deploy chrony config
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony/chrony.conf
    mode: "0644"
  tags: [chrony, config]
```

### Mexanizm

Ansible avval playbook'ni to'liq o'qib task ro'yxatini tuzadi, keyin har task uchun uning teglarini `--tags` va `--skip-tags` bilan solishtiradi. Mos kelmagan task umuman bajarilmaydi va chiqishda ko'rinmaydi (`skipping` ham yozilmaydi). Teglar meros bo'ladi: role'ga teg berilsa (`- role: docker` va `tags: docker`) uning barcha task'lari shu tegni oladi. Ikki maxsus teg bor: `always` (har doim ishlaydi, faqat `--skip-tags always` to'xtatadi) va `never` (faqat aniq so'ralganda ishlaydi).

### Misol

```
$ ansible-playbook site.yml --list-tags

playbook: site.yml

  play #1 (app): Configure app servers	TAGS: []
      TASK TAGS: [base, chrony, config, packages]
$ ansible-playbook site.yml --tags config --list-tasks

playbook: site.yml

  play #1 (app): Configure app servers	TAGS: []
    tasks:
      chrony : Deploy chrony config	TAGS: [chrony, config]
```

`--list-tags` hech narsa bajarmaydi: har play uchun undagi barcha teglarni alifbo tartibida chiqaradi. `play #1 (app)` dagi `app` bu `hosts:` qiymati, `TAGS: []` play'ning o'zida teg yo'qligini bildiradi. `--list-tasks` tanlov natijasini oldindan ko'rsatadi: `--tags config` bilan faqat bitta task qoldi, formati `role : task nomi`. Haqiqiy ishga tushirishdan oldin shu ikki buyruq bilan nimani ishga tushirayotganingizni tekshiring.

### Real ishda qachon kerak

Katta playbook'da tez iteratsiya uchun (`--tags nginx`) va xavfli yoki sekin qadamni tashlab o'tish uchun (`--skip-tags upgrade`). `never` tegi kam ishlatiladigan operatsiyalar uchun: masalan ma'lumotlar bazasini tiklash task'i faqat `--tags restore` bilan ishlaydi.

**Tuzoq: `--tags` bilan qisman ishga tushirish kerakli oldingi qadamlarni tashlab ketadi** (masalan o'zgaruvchini `set_fact` yoki `register` qiladigan, yoki paket o'rnatadigan task). Teglar tezlik uchun, to'liq ishga tushirish esa har doim to'g'ri ishlashi kerak.

### Nima uchun shunday

Idempotent playbook'ni har doim to'liq ishga tushirish nazariy jihatdan to'g'ri, amalda yuzlab serverda bu sekin. Teglar shu tezlik muammosiga javob. Muqobili: playbook'ni mayda fayllarga bo'lish (`web.yml`, `db.yml`), ko'pincha ikkalasi birga ishlatiladi. npm'dagi `scripts` ga o'xshash joyi bor (bitta loyihadan qismni ishga tushirish), lekin muhim farq: script'lar mustaqil, teglangan task'lar esa bir-biriga bog'liq bo'lishi mumkin va Ansible bu bog'liqlikni tekshirmaydi.

## 6. Dynamic inventory

### Bu nima

Shu paytgacha inventory statik fayl edi: hostlar ro'yxatini siz yozgansiz. Cloud'da serverlar paydo bo'lib yo'qoladi, IP'lar o'zgaradi, statik ro'yxat tez eskiradi. **Dynamic inventory** ro'yxatni har ishga tushirishda tashqi manbadan (cloud API) oladi. Buni **inventory plugin** qiladi: YAML sozlama faylini o'qib, API'ga so'rov yuborib, javobdan host va guruhlar yasaydigan kod. AWS uchun `amazon.aws.aws_ec2`.

```
# inventory/lab.aws_ec2.yml  (file name must end with aws_ec2.yml or aws_ec2.yaml)
plugin: amazon.aws.aws_ec2
regions:
  - eu-central-1
filters:
  tag:Project: iac-lab
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
compose:
  ansible_host: public_ip_address
```

### Mexanizm

`-i inventory/lab.aws_ec2.yml` berilganda Ansible faylni har inventory plugin'iga ko'rsatadi; `aws_ec2` plugin'i faylni nomining oxiri bo'yicha "meniki" deb taniydi. Keyin u control node'da `boto3` kutubxonasi orqali EC2 API'ning `DescribeInstances` so'rovini yuboradi (faqat o'qish). Credential'lar AWS CLI bilan bir xil zanjirdan olinadi: environment o'zgaruvchilari, `~/.aws/credentials` va `~/.aws/config` profillari, EC2 ichida esa instance role.

- `filters` EC2 API filtrlari (`aws ec2 describe-instances --filters` dagi nomlar bilan bir xil): bu yerda faqat `Project=iac-lab` tegli va ishlab turgan instanslar.
- `keyed_groups` instans xususiyatidan guruh yasaydi: `Role=app` tegli instans `role_app` guruhiga tushadi (`prefix` + `_` + qiymat).
- `compose` host o'zgaruvchisini ifoda bilan hisoblaydi: ulanish manzili sifatida public IP.

### Misol

```
$ ansible-inventory -i inventory/lab.aws_ec2.yml --graph
@all:
  |--@ungrouped:
  |--@aws_ec2:
  |  |--ec2-<a-b-c-d>.eu-central-1.compute.amazonaws.com
  |--@role_app:
  |  |--ec2-<a-b-c-d>.eu-central-1.compute.amazonaws.com
```

`aws_ec2` guruhini plugin o'zi yaratadi va topilgan barcha instanslarni unga qo'yadi. Host nomi standart holda instansning public DNS nomi. `role_app` guruhi `keyed_groups` dan keldi: playbook'da `hosts: role_app` deb yozish mumkin va yangi instans qo'shilganda inventory'ga tegish kerak emas. Akkauntda mos instans bo'lmasa `aws_ec2` va `role_*` guruhlari bo'sh chiqadi yoki umuman chiqmaydi, bu xato emas. Bu darsda instans yaratmaysiz, ular 5-darsda Terraform bilan paydo bo'ladi.

Ikki mashina: `boto3` tekshiruvi va o'rnatilishi "Laboratoriya" bo'limida. AWS credential'lari har mashinada alohida sozlanadi (cloud modulidagi `aws configure` yoki SSO profili), repoga yozilmaydi.

### Real ishda qachon kerak

Autoscaling, tez-tez qayta yaratiladigan serverlar, Terraform bilan birga ishlash: Terraform resursga teg qo'yadi, Ansible shu teg bo'yicha hostni topadi (5-dars). Statik fayl o'zgarmas, kam sonli serverlar uchun yetarli (bizning `app1` kabi).

### Nima uchun shunday

Avval dynamic inventory JSON chiqaradigan bajariladigan skript (`ec2.py`) edi, har kim o'zinikini yozardi. Plugin'lar buni deklarativ YAML bilan almashtirdi: filtr va guruhlash qoidalari kod emas, sozlama. Fayl nomiga qo'yilgan talab (`aws_ec2.yml` bilan tugashi) plugin oddiy YAML inventory faylini adashib o'ziniki deb o'qimasligi uchun. Muqobili: Terraform output'idan statik inventory generatsiya qilish; u oddiyroq, lekin Terraform'dan tashqarida o'zgargan narsani ko'rmaydi.

## 7. ansible-lint va Molecule

### Bu nima

**ansible-lint** playbook va role'larni ishga tushirmasdan, yaxshi amaliyotlar qoidalari bo'yicha tekshiradigan statik analizator: Ansible uchun ESLint. **Molecule** esa role'ni vaqtinchalik muhitda haqiqatan ishga tushirib sinaydigan freymvork: unit test emas, ko'proq integratsion test.

### Mexanizm: ansible-lint

`ansible-lint` (joriy papka) yoki `ansible-lint site.yml`. U fayllarni topadi, YAML'ni tahlil qiladi, role va playbook'larni Ansible'ning o'z parser'i bilan yuklaydi (shuning uchun ishlatilgan modullarning collection'lari control node'da mavjud bo'lishi kerak, avval 3-bo'limdagi o'rnatishni bajaring) va har qoidani qo'llaydi. Qoidalar profillarga guruhlangan, yengilidan qat'iysiga: `min`, `basic`, `moderate`, `safety`, `shared`, `production`. Har keyingi profil oldingilarini o'z ichiga oladi. Sozlama loyiha ildizidagi `.ansible-lint` faylida:

```
profile: production
exclude_paths:
  - collections/
```

Ko'p uchraydigan qoidalar: `fqcn` (to'liq modul nomi), `name[missing]` (nomsiz task), `no-changed-when` (`command` da `changed_when` yo'q), `risky-file-permissions` (`mode` berilmagan), `yaml[...]` (formatlash). Bitta qatorni asosli ravishda o'tkazib yuborish: qator oxirida `# noqa: <rule-id>` (ESLint'dagi `// eslint-disable-line` kabi).

### Misol

```
$ ansible-lint
WARNING  Listing 2 violation(s) that are fatal
fqcn[action-core]: Use FQCN for builtin module actions (apt).
roles/chrony/tasks/main.yml:2 Use `ansible.builtin.apt` or `ansible.legacy.apt` instead.

risky-file-permissions: File permissions unset or incorrect.
roles/chrony/tasks/main.yml:7 Task/Handler: Deploy chrony config

<...>
Failed: 2 failure(s), 0 warning(s) on <N> files. Last profile that met the validation criteria was 'min'.
```

Har topilma ikki qator: birinchisida qoida identifikatori (kvadrat qavsda kichik turi) va tavsif, ikkinchisida `fayl:qator` va kontekst. Birinchi topilma: `apt` qisqa nomi o'rniga `ansible.builtin.apt` yozilsin. Ikkinchisi: `template` task'ida `mode` yo'q, fayl huquqlari tizim umask'iga bog'liq bo'lib qoladi. Oxirgi qator xulosa: nechta xato, nechta fayl va loyiha hozir qaysi profilga javob beradi. Exit code noldan farqli, shuning uchun CI'da qadam yiqiladi. Toza holatda `Passed: 0 failure(s), 0 warning(s) on <N> files.` chiqadi. Aniq matn versiyaga qarab biroz farq qiladi.

`ansible-playbook site.yml --syntax-check` boshqa narsa: u faqat playbook Ansible tomonidan o'qila olishini tekshiradi (YAML to'g'ri, modul va role mavjud), uslubni emas.

### Molecule

`molecule test` standart ketma-ketligining mazmuni: vaqtinchalik instans yaratish (odatda konteyner), role'ni qo'llash (`converge`), ikkinchi marta qo'llab `changed=0` ekanini tekshirish (`idempotence`), tekshiruv playbook'ini ishlatish (`verify`), instansni o'chirish (`destroy`). Bu siz qo'lda qiladigan "toza VM, ikki marta ishga tushirish, tekshirish" siklining avtomatlashtirilgani. Bu darsda faqat tanishuv, o'rnatilmaydi.

### Real ishda qachon kerak

`ansible-lint` birinchi kundan: muharrirda va PR'da. U `mode` siz yaratilgan secret fayli yoki idempotent bo'lmagan `command` kabi xatolarni serverga yetmasdan ushlaydi. Molecule role'lar jamoada qayta ishlatila boshlaganda yoki bir necha OS'ni qo'llaganda CI'ga qo'shiladi.

### Nima uchun shunday

YAML juda erkin format: bitta ishni o'n xil yozish mumkin va ko'p xato (noto'g'ri indent, qo'shtirnoqsiz `0644`) sintaktik jihatdan to'g'ri. Lint jamoa uslubini bahsdan qoidaga aylantiradi. Profillar bosqichma-bosqich qat'iylashish uchun: eski loyihani `min` dan boshlab `production` ga ko'tarish mumkin. Statik tekshiruv role haqiqatan ishlashini isbotlamaydi, buning uchun uni ishga tushirish kerak: Molecule yoki bizdagi 21-vazifa.

## 8. App server loyihasi

### Bu nima

Cloud modulida qo'lda sozlagan app serverni role'larga ajratamiz. Har role bitta mas'uliyat:

| Role | Mas'uliyat | Asosiy modullar |
|------|------------|-----------------|
| `base` | bazaviy paketlar, `deploy` foydalanuvchisi, SSH kalit, sudoers, sshd sozlamasi | `apt`, `user`, `ansible.posix.authorized_key`, `template` + `validate` |
| `firewall` | UFW: standart deny, 22/80/443 ochiq | `community.general.ufw` |
| `docker` | Docker Engine rasmiy repodan, compose plugin, servis | `ansible.builtin.deb822_repository`, `apt`, `service`, `user` |
| `reverse_proxy` | nginx, ilovaga `proxy_pass` | `apt`, `template`, handler |
| `app` | `/opt/app`, `compose.yaml`, `.env` (Vault'dan), stack'ni ko'tarish | `file`, `template`, `community.docker.docker_compose_v2` |

Atamalar: **UFW** (Uncomplicated Firewall) Ubuntu'dagi firewall boshqaruv asbobi, ichida kernel'ning paket filtri (iptables/nftables) qoidalarini yozadi. **Reverse proxy** tashqi so'rovni qabul qilib ichkaridagi ilovaga uzatadigan server (bizda nginx). **sudoers** kim `sudo` ishlata olishini belgilaydigan fayllar. Har modulning "Requirements" bo'limini hujjatdan o'qing: ba'zilari nishonda qo'shimcha narsa talab qiladi (masalan `docker_compose_v2` nishonda Docker Compose plugin'i bo'lishini kutadi).

### Mexanizm 1: o'zingizni tashqarida qoldirmaslik

Ansible nishonga SSH orqali kiradi va `sudo` bilan ishlaydi. Firewall, sshd va sudoers'ni o'zgartirayotgan task aynan o'zi o'tirgan shoxni kesishi mumkin.

- **Firewall tartibi**: avval SSH portiga ruxsat, keyin standart siyosat `deny` va UFW'ni yoqish. Teskari tartibda yoqilgan zahoti yangi SSH ulanishlar uziladi va play yarmida qoladi.
- **sshd**: Ubuntu 24.04 da sozlamani `/etc/ssh/sshd_config.d/` ichidagi alohida faylga yozing va joylashdan oldin tekshiring: `validate: "sshd -t -f %s"`. sshd har kalit uchun **birinchi uchragan** qiymatni oladi va bu papkadagi fayllar nom tartibida o'qiladi, shuning uchun fayl nomi muhim (papkada cloud image'dan qolgan fayllar bo'lishi mumkin, `ls` bilan ko'ring). Ubuntu'da servis nomi `ssh`, `sshd` emas. Amaldagi qiymat: `sudo sshd -T | grep -i passwordauthentication`.
- **sudoers**: `/etc/sudoers.d/` ga fayl faqat `validate: "visudo -cf %s"` bilan. Buzilgan sudoers `sudo` ni butunlay ishdan chiqaradi.

`validate` qanday ishlaydi: modul yangi mazmunni nishonda vaqtinchalik faylga yozadi, `%s` o'rniga shu fayl yo'lini qo'yib buyruqni bajaradi va faqat exit code `0` bo'lsa faylni joyiga ko'chiradi. Aks holda task `failed`, eski fayl tegilmagan.

Bularning biri buzilsa: `multipass shell app1` SSH kalitingizga bog'liq emas, VM ichidan tuzatasiz. Haqiqiy cloud serverda bunday "orqa eshik" har doim ham bo'lmaydi, shuning uchun tartib va `validate` odat bo'lishi kerak.

### Mexanizm 2: nishon arxitekturasi

`app1` Zorin'da `x86_64`, Mac'da `aarch64`. Role ikkalasida ishlashi shart, 5-darsdagi EC2 esa yana boshqa bo'lishi mumkin. Shuning uchun apt repo qo'shadigan yoki binary yuklaydigan task'da arxitektura hech qachon literal (`amd64`) yozilmaydi. Chalkashlik manbai: bitta arxitekturaning ikki xil nomi bor.

```
$ ansible app1 -m ansible.builtin.setup -a 'filter=ansible_architecture'
app1 | SUCCESS => {
    "ansible_facts": {
        "ansible_architecture": "x86_64",
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false
}
$ multipass exec app1 -- dpkg --print-architecture
amd64
```

Birinchi buyruq fact (2-dars: Ansible nishondan yig'adigan ma'lumot) ni ko'rsatadi: `ansible_architecture` kernel aytgan nom, Mac'dagi VM'da `aarch64`. Ikkinchi buyruq Debian paket tizimining nomi: Mac'da `arm64`. apt repo va ko'p binary relizlar ikkinchi nomlashni ishlatadi. Uch to'g'ri yo'l bor: `dpkg --print-architecture` natijasini o'qib olish; fact'ni lug'at orqali o'girish; yoki deb822 formatidagi repo ta'rifida arxitektura maydonini umuman bermaslik, shunda apt tizimning o'z arxitekturasini oladi. Lug'at usuli, umumiy ko'rinishda:

```
# vars/main.yml of some role: internal constant, not a user parameter
tool_arch_map:
  x86_64: amd64
  aarch64: arm64
# usage in a task argument
#   url: "https://example.com/tool_{{ tool_arch_map[ansible_architecture] }}.tar.gz"
```

### Mexanizm 3: Docker va UFW

Docker publish qilingan portlar uchun kernel paket filtriga o'z qoidalarini yozadi. Tashqaridan `8080` portga kelgan paket konteyner manziliga yo'naltiriladi (DNAT) va endi u host'ning o'ziga emas, host **orqali o'tayotgan** paket hisoblanadi: `FORWARD` zanjiridan o'tadi. UFW'ning "kiruvchi ulanishlar" qoidalari esa `INPUT` zanjirida, ya'ni host'ning o'ziga kelgan paketlar uchun. Natija: `ports: ["8080:80"]` bilan publish qilingan konteyner UFW'da `deny` bo'lsa ham tashqaridan ochiq. Reverse proxy ortidagi ilova uchun to'g'ri yo'l: faqat loopback'ga publish qilish (`127.0.0.1:8080:80`), tashqariga faqat nginx chiqadi. Cloud'da qo'shimcha qatlam security group. macOS host'ida bu qoidalarni ko'ra olmaysiz (host Linux emas), tekshiruv faqat `app1` ichida.

### Real ishda qachon kerak

Bu aynan haqiqiy ish: yangi server buyurtma qilindi va u bir soat ichida trafik qabul qilishi kerak. Qo'lda sozlangan server hujjatlashtirilmagan qarorlar to'plami; role'lar bilan sozlangani esa o'qiladigan, review qilinadigan va takrorlanadigan kod. Server buzilsa tuzatilmaydi, qayta yaratiladi.

### Nima uchun shunday

Role'lar mas'uliyat bo'yicha bo'lingan, chunki ular alohida qayta ishlatiladi: `base` va `firewall` har serverga, `docker` faqat konteyner ishlaydiganiga. `validate` parametri aynan sshd va sudoers kabi "xato bo'lsa qaytib kira olmaysan" fayllari uchun qo'shilgan. Docker'ning UFW'ni chetlab o'tishi xato emas, dizayn oqibati: Docker tarmoqni o'zi boshqarishi uchun paket filtrini to'g'ridan-to'g'ri yozadi va UFW haqida bilmaydi; Docker hujjati buni ochiq aytadi. Arxitektura nomlarining ikki xilligi tarixiy: `x86_64` va `aarch64` protsessor ishlab chiqaruvchilar nomi, `amd64` va `arm64` Debian port nomlari.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Control node | Ansible o'rnatilgan va buyruq yuboradigan mashina, bizda host |
| Managed node | Ansible SSH orqali sozlaydigan server ("nishon"), bizda `app1` |
| Role | bitta mas'uliyatga oid task, handler, template va o'zgaruvchilarning standart papkadagi to'plami |
| `defaults` | role'ning eng past ustunlikdagi o'zgaruvchilari, foydalanuvchi o'zgartiradigan parametrlar |
| `vars` (role) | role'ning yuqori ustunlikdagi ichki konstantalari |
| `group_vars` / `host_vars` | guruh yoki bitta host uchun o'zgaruvchi fayllari, inventory yonidan avtomatik yuklanadi |
| Precedence | bir nomli o'zgaruvchi bir necha joyda bo'lsa qaysi biri yutishini belgilaydigan tartib |
| Collection | modul, plugin va role'lar paketi, nomi `namespace.name` |
| FQCN | modulning to'liq nomi: `namespace.collection.module` |
| Ansible Galaxy | collection va role'lar ombori va uning `ansible-galaxy` CLI'si |
| `requirements.yml` | loyiha bog'liq bo'lgan collection va role'lar ro'yxati, versiyalari bilan |
| Ansible Vault | o'zgaruvchi fayli yoki qiymatni parol bilan shifrlash vositasi |
| `no_log` | task natijasi va argumentlarini chiqish va logdan yashiradigan kalit so'z |
| Tag | task yoki role'ga qo'yiladigan yorliq, `--tags` va `--skip-tags` bilan tanlash uchun |
| Dynamic inventory | hostlar ro'yxatini har ishga tushirishda tashqi API'dan olish |
| Inventory plugin | sozlama faylini o'qib, manbadan host va guruhlar yasaydigan kod |
| `keyed_groups` | host xususiyati (masalan teg) qiymatidan guruh yasash qoidasi |
| ansible-lint | playbook va role'lar uchun statik analizator |
| Molecule | role'ni vaqtinchalik muhitda ishga tushirib sinaydigan freymvork |
| Idempotentlik | qayta ishga tushirish holatni o'zgartirmasligi, amalda ikkinchi run `changed=0` |
| `validate` | faylni joylashdan oldin vaqtinchalik nusxasini buyruq bilan tekshirish parametri |
| UFW | Ubuntu'dagi firewall boshqaruv asbobi |
| Reverse proxy | tashqi so'rovni qabul qilib ichki ilovaga uzatadigan server |
| cloud-init | VM birinchi yuklanishda bajaradigan boshlang'ich sozlash mexanizmi |

## Tuzoqlar

- Vault parolini yoki ochilgan `vault.yml` ni commit qilish. `git diff --cached` da `$ANSIBLE_VAULT;` sarlavhasini ko'rmasangiz to'xtang.
- Secret template orqali `--diff` chiqishida yoki CI log'ida ochiq ko'rinishi. `no_log`, `diff: false`.
- Role o'zgaruvchisini `vars/main.yml` ga yozib, keyin `group_vars` dan ustidan yoza olmaslik. Sozlanadigan narsa `defaults` da.
- Prefikssiz o'zgaruvchi nomlari (`port`, `user`, `packages`): role'lar bir-birining qiymatini jimgina almashtiradi.
- UFW'ni SSH ruxsatisiz yoqish yoki sshd config'ini `validate` siz joylash.
- Docker publish qilgan port UFW'ni chetlab o'tishini unutish: "firewall yopiq" deb o'ylagan ma'lumotlar bazasi porti internetga ochiq.
- `requirements.yml` da versiyasiz collection: bugun ishlagan playbook yangi major relizdan keyin sinadi.
- Faqat `--tags` bilan ishlashga o'rganib, to'liq ishga tushirishni oylab sinamaslik. Bo'sh serverdan qurish yo'li chirishga boshlaydi.
- Galaxy'dan role'ni o'qimasdan `root` bilan ishga tushirish.
- `ansible-lint` ogohlantirishlarini ommaviy `# noqa` bilan o'chirish. Har istisno asoslangan bo'lsin.
- VM IP'sini commit qilinadigan faylga yozish: ikkinchi mashinada va VM qayta yaratilganda noto'g'ri. Manzil faqat `hosts.local.yml` da.
- Repo yoki task'da literal `amd64`: Zorin'da ishlaydi, Mac'dagi `arm64` VM'da paket topilmaydi.
- Ikkinchi mashinada vault parol faylini boshqa parol bilan yaratish: "Decryption failed" xatosi.
- `multipass list` dagi IP'ni VM qayta yaratilgandan keyin yangilamaslik va eski `known_hosts` yozuvi sababli SSH xatosini Ansible xatosi deb o'ylash.

## Manbalar

- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html – role'lar
- https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html – namunaviy loyiha tuzilishi
- https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables – `group_vars`, `host_vars`
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence – o'zgaruvchilar ustunligi tartibi
- https://docs.ansible.com/ansible/latest/galaxy/user_guide.html – Galaxy, `requirements.yml`
- https://docs.ansible.com/ansible/latest/vault_guide/index.html – Ansible Vault
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html – tag'lar
- https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html – `aws_ec2` inventory plugin
- https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html – `docker_compose_v2`
- https://docs.ansible.com/ansible/latest/collections/community/general/ufw_module.html – `ufw`
- https://docs.ansible.com/projects/lint/ – ansible-lint, qoidalar va profillar
- https://docs.ansible.com/projects/molecule/ – Molecule
- https://docs.docker.com/engine/install/ubuntu/ – Docker Engine'ni Ubuntu'ga o'rnatish
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker va iptables, UFW bilan o'zaro ta'sir
- https://documentation.ubuntu.com/multipass/ – Multipass hujjati (`launch`, `list --format`, `info`)
- Jeff Geerling, "Ansible for DevOps", 6–8 boblar

---

## Birga bajaramiz

Bitta kichik role'ni boshidan oxirigacha yuritamiz: `labinfo`. U nishonda `/etc/lab/` papkasini yaratadi, ichiga oddiy sozlama fayli (`info.conf`, qiymatlar `defaults` va `group_vars` dan) va secret fayl (`token.env`, qiymat Vault'dan) yozadi. Yo'lda role, precedence, Vault, sizib chiqish, teg, lint va idempotentlikni ko'ramiz. Bu vazifalardagi role'larning hech biri emas. Vaqtinchalik papkada ishlang (masalan `~/tmp/labinfo-demo`), ish papkangizga aralashtirmang.

1. VM, inventory va ulanish. `app1` yaratilgan, 2-bo'limdagi `ansible.cfg`, `hosts.yml` va `hosts.local.yml` joyida:

```
$ ansible app -m ansible.builtin.ping
app1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

`app` guruhi `hosts.yml` dan, manzil `hosts.local.yml` dan keldi; `pong` SSH, kalit va nishondagi Python ishlayotganini bildiradi.

2. Skelet va ortiqchasini olib tashlash:

```
$ ansible-galaxy role init --init-path roles labinfo
- Role labinfo was created successfully
$ rm -r roles/labinfo/tests roles/labinfo/files roles/labinfo/handlers roles/labinfo/vars roles/labinfo/meta
```

Bu role'da statik fayl, handler, ichki konstanta va bog'liqlik yo'q, shuning uchun to'rt papka va `tests` ketdi. Qoldi: `defaults`, `tasks`, `templates`.

3. Parametrlar, task'lar va template'lar:

```
# roles/labinfo/defaults/main.yml
labinfo_env: dev
labinfo_owner: root
```

```
# roles/labinfo/tasks/main.yml
- name: Create config directory
  ansible.builtin.file:
    path: /etc/lab
    state: directory
    owner: "{{ labinfo_owner }}"
    mode: "0755"
  tags: [labinfo]

- name: Deploy info file
  ansible.builtin.template:
    src: info.conf.j2
    dest: /etc/lab/info.conf
    owner: "{{ labinfo_owner }}"
    mode: "0644"
  tags: [labinfo, config]

- name: Deploy token file
  ansible.builtin.template:
    src: token.env.j2
    dest: /etc/lab/token.env
    owner: "{{ labinfo_owner }}"
    mode: "0600"
  tags: [labinfo, config]
```

`templates/info.conf.j2` ichida bitta qator: `env={{ labinfo_env }} arch={{ ansible_architecture }}`. `templates/token.env.j2` ichida: `API_TOKEN={{ labinfo_api_token }}`. E'tibor bering: `src` da yo'l yo'q, hamma o'zgaruvchi `labinfo_` prefiksli, `labinfo_api_token` uchun default ataylab berilmagan (secret'ning standart qiymati bo'lmasligi kerak).

4. `group_vars` bilan ustidan yozish va Vault. `inventory/group_vars/app.yml` ga `labinfo_env: staging` yozamiz. Secret uchun:

```
$ mkdir -p ~/.config/iac-lab && chmod 700 ~/.config/iac-lab
$ $EDITOR ~/.config/iac-lab/vault-pass        # one line: the password
$ chmod 600 ~/.config/iac-lab/vault-pass
$ ansible-vault create --vault-password-file ~/.config/iac-lab/vault-pass inventory/group_vars/all/vault.yml
$ head -c 40 inventory/group_vars/all/vault.yml
$ANSIBLE_VAULT;1.1;AES256
38656438643163
```

Muharrirda `vault_labinfo_api_token: "demo-token-123"` yozildi; `head` diskda faqat shifr borligini tasdiqlaydi. Ochiq `inventory/group_vars/all/vars.yml` ga havola: `labinfo_api_token: "{{ vault_labinfo_api_token }}"`. Tekshiruv:

```
$ ansible-inventory --host app1 --vault-password-file ~/.config/iac-lab/vault-pass
{
    "ansible_host": "<IP>",
    <...>
    "labinfo_api_token": "{{ vault_labinfo_api_token }}",
    "labinfo_env": "staging",
    "vault_labinfo_api_token": "demo-token-123"
}
```

`labinfo_env` endi `staging`: `group_vars/app` role default'idan ustun (default bu yerda ko'rinmaydi ham). Havola hali ochilmagan shablon ko'rinishida, u task ishlaganda hisoblanadi. Oxirgi qatorga qarang: `ansible-inventory` secret'ni ekranga ochiq chiqardi. Bu birinchi sizib chiqish nuqtasi, bu buyruq chiqishini README yoki CI log'iga ko'chirmang.

5. Playbook va birinchi ishga tushirish. `site.yml` da faqat `name`, `hosts: app`, `become: true`, `roles: [labinfo]`:

```
$ ansible-playbook site.yml --vault-password-file ~/.config/iac-lab/vault-pass

PLAY [Configure app servers] ***************************************************

TASK [Gathering Facts] *********************************************************
ok: [app1]

TASK [labinfo : Create config directory] ***************************************
changed: [app1]

TASK [labinfo : Deploy info file] **********************************************
changed: [app1]

TASK [labinfo : Deploy token file] *********************************************
changed: [app1]

PLAY RECAP *********************************************************************
app1                       : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Task nomlari `labinfo :` prefiksi bilan. `ok=4` bajarilgan task'lar soni (fact yig'ish ham kiradi), `changed=3` shulardan holatni o'zgartirganlari. Darhol ikkinchi marta ishga tushirsangiz uch task ham `ok`, recap'da `changed=0`: role idempotent.

6. Sizib chiqishni ko'rish va yopish. Vault'dagi tokenni `ansible-vault edit` bilan `demo-token-456` ga o'zgartirib, quruq ishga tushiramiz:

```
$ ansible-playbook site.yml --vault-password-file ~/.config/iac-lab/vault-pass --check --diff --tags config
<...>
TASK [labinfo : Deploy token file] *********************************************
--- before: /etc/lab/token.env
+++ after: /home/<user>/.ansible/tmp/<...>/token.env.j2
@@ -1 +1 @@
-API_TOKEN=demo-token-123
+API_TOKEN=demo-token-456
changed: [app1]
```

`--check` hech narsani o'zgartirmaydi, `--diff` nima o'zgarishini ko'rsatadi, `--tags config` papka yaratish task'ini tashlab ketdi. Diff'da eski va yangi secret ochiq matnda: ikkinchi sizib chiqish nuqtasi. Token task'iga `no_log: true` va `diff: false` qo'shsak, o'sha buyruqda diff bloki yo'qoladi, faqat `changed: [app1]` qoladi. `info.conf` task'iga bularni qo'ymaymiz: unda secret yo'q, diff esa foydali.

7. Nishonda tekshirish (uchinchi nuqta: fayl huquqlari):

```
$ multipass exec app1 -- sudo ls -l /etc/lab
total 8
-rw-r--r-- 1 root root 24 <sana> info.conf
-rw------- 1 root root 25 <sana> token.env
$ multipass exec app1 -- cat /etc/lab/info.conf
env=staging arch=x86_64
$ multipass exec app1 -- cat /etc/lab/token.env
cat: /etc/lab/token.env: Permission denied
```

`info.conf` hamma o'qiy oladi (`0644`), `token.env` faqat `root` (`0600`): `ubuntu` foydalanuvchisi `sudo` siz o'qiy olmadi, kerak bo'lgani shu. `arch=x86_64` Zorin'da, Mac'da `arch=aarch64`: bitta role, ikki arxitektura, kodda farq yo'q.

8. Lint va tozalash:

```
$ ansible-lint
<...>
Passed: 0 failure(s), 0 warning(s) on <N> files. Last profile that met the validation criteria was 'production'.
$ multipass exec app1 -- sudo rm -r /etc/lab
```

Topilma chiqsa (masalan `site.yml` da play nomi yo'q), qoida nomini hujjatdan qidirib tuzating. Oxirida `/etc/lab` ni o'chiring yoki VM'ni qayta yarating, vaqtinchalik papkani ham o'chiring. Yurishdan olinadigan ketma-ketlik: skelet, `defaults`, task va template, `group_vars`, Vault, to'liq run, ikkinchi run `changed=0`, `--check --diff`, nishonda tekshirish, lint. Vazifalardagi har role shu sikldan o'tadi.

---

## Vazifalar

Ish papkasi: `iac/03-ansible-roles/` (`make new m=iac n=03 name=ansible-roles` bilan host'da yarating). Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Loyiha fayllari (2-bo'limdagi tuzilish) shu papkada. Birinchi ish: papkada `.gitignore` yarating (2-bo'lim) va `hosts.local.yml` commit'ga tushmasligini `git status` bilan tekshiring; `hosts.local.yml.example` esa commit qilinadi. README'da ham haqiqiy IP o'rniga `<IP>` yozing. Vault paroli fayli repodan tashqarida saqlanadi. Barcha playbook'lar faqat Multipass VM `app1` ga qarshi ishlaydi; `ansible-*` buyruqlari host'da, tekshiruv buyruqlari (`ufw`, `iptables`, `sshd -T`, `docker`) VM ichida bajariladi. Vazifalardagi `<IP>` bu shu mashinadagi `app1` manzili.

### A. Role va o'zgaruvchilar

1. **Role skeleton.** `ansible-galaxy role init roles/nginx` bilan skelet yarating. Har papka nima uchun ekanini bir jumla bilan yozing. Kerak bo'lmaganlarini o'chiring va nima uchun o'chirganingizni ayting. Yo'nalish: 1-bo'lim, "Mexanizm: papkalar va qidiruv" va "Misol: skelet yaratish".

2. **Extract a role.** 2-darsdagi nginx playbook'ini (`web.yml`: o'rnatish, template, handler) `nginx` role'iga ko'chiring va `app1` ga qarshi ishga tushiring (2-darsdagi `web1` shart emas). `site.yml` da faqat `hosts`, `become` va `roles` qolsin. Template va handler qaysi papkaga tushdi, `src` yo'li qanday o'zgardi? Natija 2-darsdagi bilan bir xil ekanini tekshiring. Yo'nalish: 1-bo'lim, "Mexanizm: papkalar va qidiruv".

3. **defaults vs vars.** Role'da `nginx_http_port` ni `defaults/main.yml` da aniqlang va `group_vars` dan ustidan yozing: ishladimi? Keyin uni `vars/main.yml` ga ko'chirib takrorlang. Endi qaysi usullar bilan ustidan yozish mumkin? Qoida chiqaring: nima `defaults` ga, nima `vars` ga yoziladi. Yo'nalish: 1-bo'lim, "defaults va vars".

4. **group_vars and host_vars.** 2-bo'limdagi papka tuzilishini yarating (jumladan `hosts.yml`, `hosts.local.yml`, `hosts.local.yml.example` va `.gitignore`). Bitta o'zgaruvchini `group_vars/all`, `group_vars/app` va `host_vars/app1` da har xil qiymat bilan aniqlang. `ansible-inventory --host app1` nima ko'rsatadi? Tartibni bittalab o'chirib tasdiqlang. Yo'nalish: 2-bo'lim, "Mexanizm" va "Misol: yakuniy qiymatni ko'rish".

5. **Execution order.** Bitta play'da `pre_tasks`, `roles`, `tasks`, `post_tasks` ning har biriga `debug` qo'ying va ulardan biri handler'ga `notify` qilsin (`changed_when: true` bilan). Bajarilish tartibini va handler aynan qayerda ishlaganini yozing. Yo'nalish: 1-bo'lim, "Role'ni ishlatish va bajarilish tartibi".

### B. Collection'lar

6. **requirements.yml.** Loyihaga kerakli collection'larni (`community.docker`, `community.general`, `ansible.posix`) versiya oralig'i bilan `requirements.yml` ga yozing va o'rnating. `ansible-galaxy collection list` da qaysi yo'lda qaysi versiya turganini ko'rsating. Bir xil collection ikki joyda (`ansible` paketi bilan kelgan va siz o'rnatgan) bo'lsa qaysi biri ishlatiladi? Yo'llar Zorin va Mac'da farq qiladi, README'ga qaysi mashinada olinganini yozing. Yo'nalish: 3-bo'lim, "Mexanizm" va "Misol".

7. **Galaxy role review.** Galaxy'dan mashhur Docker o'rnatish role'ini toping va GitHub'dagi manbasini o'qing (o'rnatmasdan): `defaults` da nechta parametr, `tasks` qaysi OS oilalarini qo'llaydi, `root` sifatida nimalarni qiladi. Uni ishlatish va o'zingiz yozish orasidagi tanlovni 3–4 jumla bilan asoslang. Yo'nalish: 3-bo'lim, "Real ishda qachon kerak".

### C. Vault

8. **Vault file.** `vault.yml` yarating (`vault_app_db_password`), `vars.yml` da unga havola qiling, playbook'da `debug` bilan (vaqtincha) qiymat o'qilishini tekshiring. `cat vault.yml` va `git diff` nima ko'rsatadi? `--ask-vault-pass` siz ishga tushirib xatoni o'qing. Yo'nalish: 4-bo'lim, "Mexanizm" va "Misol".

9. **Secret leaks.** Secret'ni template orqali nishondagi `.env` fayliga yozing. Uch joyda sizib chiqishini ko'rsating va har birini yoping: `--diff` chiqishi, `-v` bilan task natijasi, nishondagi fayl huquqlari. `no_log: true` qo'yilgan task'ni ataylab buzing: xato xabari qanday ko'rinadi? README'ga haqiqiy secret emas, sinov qiymati tushsin. Yo'nalish: 4-bo'lim, "Vault nimani himoya qilmaydi".

10. **Vault password file.** Parolni repodan tashqaridagi faylga (mode `0600`) qo'ying va `ansible.cfg` dagi `vault_password_file` sozlamasi orqali ulang. `ansible-vault rekey` bilan parolni almashtiring. `encrypt_string` bilan bitta qiymatni oddiy `vars.yml` ichida shifrlang va fayl darajasidagi shifrlash bilan solishtiring: qaysi biri review uchun qulay? Parol fayli ikkinchi mashinaga qanday yetib boradi, bir jumla bilan yozing. Yo'nalish: 4-bo'lim, "Mexanizm" va "Nima uchun shunday".

### D. Tag, lint, inventory

11. **Tags.** Role va task'larga teg qo'ying (`base`, `docker`, `app`, `config`). `--list-tags`, `--tags config`, `--skip-tags docker` natijalarini yozing. `always` tegli bitta task qo'shing. Qisman ishga tushirish noto'g'ri natija beradigan bitta holatni o'z loyihangizdan toping yoki yarating. Yo'nalish: 5-bo'lim.

12. **ansible-lint.** 2-darsdagi playbook'lar va shu darsdagi role'larni `ansible-lint` bilan `production` profilida tekshiring. Topilgan qoida buzilishlarini turlarga ajratib yozing, har turdan bittasini tuzatishdan oldin va keyin ko'rsating. Yakunda toza o'tsin; `# noqa` ishlatgan bo'lsangiz har birini asoslang. Yo'nalish: 7-bo'lim, "Mexanizm: ansible-lint" va "Misol".

13. **Lint in CI.** cicd modulidagi bilimingiz bilan `ansible-lint` va `ansible-playbook --syntax-check` ni PR'da ishga tushiradigan workflow yozing. Vault bilan shifrlangan fayllar bor loyihada `--syntax-check` parolsiz ishlaydimi? Tekshirib, yechimni yozing. CI runner'da `hosts.local.yml` yo'qligini ham hisobga oling. Yo'nalish: 7-bo'lim va 4-bo'lim, "Mexanizm".

14. **Molecule overview.** Molecule hujjatidan o'qib yozing (o'rnatmasdan): `molecule test` qaysi bosqichlardan o'tadi, `converge` va `idempotence` nimani tekshiradi, instans sifatida konteyner ishlatilganda qaysi turdagi role'larni sinash qiyin (ishoralar: systemd, firewall). Siz 21-vazifada qo'lda qiladigan ish bilan solishtiring. Yo'nalish: 7-bo'lim, "Molecule".

15. **Dynamic inventory.** `aws_ec2` plugin uchun inventory fayli yozing: region, `Project=iac-lab` teg filtri, `Role` tegi bo'yicha `keyed_groups`. `ansible-inventory -i <file> --graph` ni ishga tushiring (akkauntda mos instans bo'lmasa bo'sh natija ham to'g'ri). Fayl nomini `ec2.yml` ga o'zgartirib ko'ring: nima bo'ldi? Plugin qaysi credential'lardan foydalanganini yozing. Bu vazifa AWS'da hech narsa yaratmaydi; `boto3` shu mashinada bo'lishi kerak ("Laboratoriya"), credential'lar va akkaunt ID README'ga tushmasin. Yo'nalish: 6-bo'lim.

### E. App server loyihasi

16. **Base role.** `base` role: bazaviy paketlar; `deploy` foydalanuvchisi, sizning public kalitingiz bilan; `/etc/sudoers.d/deploy` (`validate` bilan); `sshd_config.d` ga parol bilan kirishni o'chiradigan fayl (`validate` va handler bilan). Ataylab sintaktik xato sudoers template'ini joylashga urinib ko'ring: `validate` nima qildi, nishondagi fayl o'zgardimi? `ssh deploy@<IP>` bilan kirishni tekshiring. Public kalit har mashinada boshqa (`~/.ssh/iac_lab.pub`), shuning uchun kalit matnini role ichiga yozmang, control node'dagi fayldan o'qiladigan qiling. Yo'nalish: 8-bo'lim, "Mexanizm 1: o'zingizni tashqarida qoldirmaslik".

17. **Firewall role.** `firewall` role: SSH, 80 va 443 ga ruxsat, kiruvchi standart siyosat `deny`, UFW yoqilgan. Task tartibini asoslang. Ish mashinasidan `nc -zv <IP> 22`, `80` va ochilmagan port (masalan `5432`) bilan tekshiring, VM'da `sudo ufw status verbose` (Mac'da ham `ufw` faqat VM ichida: `multipass exec app1 -- sudo ufw status verbose`). Yo'nalish: 8-bo'lim, "Mexanizm 1".

18. **Docker role.** `docker` role: Docker Engine va compose plugin'ini rasmiy Docker apt repozitoriysidan o'rnatish (Docker hujjatidagi qadamlarni modullarga o'giring, `command`/`shell` siz), servis `enabled` va `started`, `deploy` foydalanuvchisi `docker` guruhida (`append` ni unutmang). Repo ta'rifida arxitektura literal yozilmasin: role Zorin'dagi `amd64` va Mac'dagi `arm64` VM'da o'zgarishsiz ishlashi shart. Tekshirish: `deploy` sifatida `docker run --rm hello-world`. `docker` guruhiga a'zolik xavfsizlik nuqtai nazaridan nimaga teng? Yo'nalish: 8-bo'lim, "Mexanizm 2: nishon arxitekturasi".

19. **App stack role.** `reverse_proxy` va `app` role'lari: `/opt/app` da template'dan `compose.yaml` va Vault'dagi secret bilan `.env` (mode `0600`); stack `community.docker.docker_compose_v2` bilan ko'tariladi; ilova faqat `127.0.0.1` ga publish qilinadi; nginx 80-portda unga `proxy_pass` qiladi. Ilova sifatida docker modulidagi o'z image'ingiz yoki istalgan kichik HTTP image; image `linux/amd64` va `linux/arm64` uchun mavjudligini `docker manifest inspect <image>` bilan tekshiring. Ish mashinasidan `curl http://<IP>/` javob bersin. Config o'zgarganda nginx reload, compose fayl o'zgarganda stack yangilanishini ko'rsating. Yo'nalish: 8-bo'lim, "Bu nima" jadvali va "Mexanizm 3: Docker va UFW"; 4-bo'lim, "Vault nimani himoya qilmaydi".

20. **Docker bypasses UFW.** Compose'da publish'ni vaqtincha `8080:80` ga (barcha interfeyslar) o'zgartiring. UFW'da 8080 ochilmagan. Ish mashinasidan `curl http://<IP>:8080` nima qaytardi? Sababini `sudo iptables -S` yoki `sudo nft list ruleset` chiqishidan (VM ichida) Docker zanjirlarini topib izohlang. `127.0.0.1` ga qaytarib, yopilganini tekshiring. Yo'nalish: 8-bo'lim, "Mexanizm 3: Docker va UFW".

21. **Fresh VM proof.** VM'ni o'chirib qayta yarating (`hosts.local.yml` ni yangilashni va kerak bo'lsa `ssh-keygen -R <IP>` ni unutmang) va bitta buyruq bilan (`ansible-playbook site.yml`) to'liq tayyorlang. Vaqtni o'lchang. Darhol ikkinchi marta ishga tushiring: `changed=0` bo'lishi shart, bo'lmasa qaysi task va nima uchun ekanini toping va tuzating. Uchinchi marta `--check --diff` bilan: toza. Cloud modulida shu serverni qo'lda sozlashga ketgan vaqt bilan solishtiring. Imkon bo'lsa ikkinchi mashinada ham takrorlang: boshqa arxitekturada ham `changed=0` chiqishi role'larning haqiqiy isboti. Yo'nalish: "Laboratoriya" (ikkinchi mashinada tiklash) va "Birga bajaramiz", 5-7 qadamlar.

### Topshirish

Tayyor bo'lgach:
1. `iac/03-ansible-roles/README.md` da 21 ta vazifaning har biri `## N. Title` sarlavhasi ostida; `make check` toza, `ansible-lint` `production` profilida toza.
2. Toza VM'da `ansible-playbook site.yml` xatosiz, ikkinchi ishga tushirish `changed=0`.
3. Repoda ochiq secret va haqiqiy IP yo'q: `vault.yml` shifrlangan, `hosts.local.yml` git'da yo'q (`git ls-files | grep local` faqat `.example` ni ko'rsatadi), vault parol fayli va private kalit repodan tashqarida.
4. VM o'chirilgan: `multipass list` da `app1` yo'q (`lab` qoladi).
5. Menga xabar bering, `README.md`, role'lar va workflow'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Role `defaults` va `vars` farqi nima? Sozlanadigan parametr qayerga yoziladi va nima uchun?
- Role o'zgaruvchilariga nima uchun prefiks qo'yiladi?
- Role ichidagi `template` task'ida `src` ga nima uchun yo'l yozilmaydi?
- `group_vars/all`, `group_vars/app` va `host_vars/app1` dan qaysi biri yutadi? Yakuniy qiymatni qaysi buyruq ko'rsatadi?
- Nima uchun VM IP'si commit qilinadigan inventory faylida turmaydi va ikkinchi mashinada nimalarni qo'lda tiklaysiz?
- `requirements.yml` `package.json` ga nimasi bilan o'xshaydi va nimasi bilan farq qiladi?
- Vault secret'ni qayerda himoya qiladi va qayerda himoya qilmaydi?
- `no_log: true` ning narxi nima?
- `--tags` bilan ishlash qanday xavf tug'diradi?
- Dynamic inventory statik fayldan nimasi bilan yaxshi, `keyed_groups` nima qiladi?
- `ansible-lint` va `--syntax-check` farqi nima? Lint nimani isbotlay olmaydi?
- UFW'ni yoqishdan oldin nima qilinishi shart? sshd va sudoers fayllarida `validate` nima uchun kerak va u ichida qanday ishlaydi?
- Nima uchun role'da `amd64` so'zini literal yozib bo'lmaydi? `x86_64` va `amd64` qanday bog'langan?
- Docker publish qilgan port nima uchun UFW qoidasiga bo'ysunmaydi va bunga qarshi nima qilasiz?
- "Ikkinchi ishga tushirish `changed=0`" talabi amalda nimani kafolatlaydi?
