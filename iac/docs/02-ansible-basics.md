# 2-dars: Ansible asoslari

Maqsad: Ansible bilan serverlarni kod orqali sozlashni noldan o'rganish: control node va nishon, inventory, ad-hoc buyruqlar, modullar, playbook, handler, o'zgaruvchilar va ularning ustunlik tartibi (precedence), facts, Jinja2 template, loop va shartlar, check mode. 1-darsda (iac 1) idempotent bash yozib, har qadam uchun "tekshir, keyin bajar" juftligini, `ok`/`changed` hisobotini va dry-run'ni o'zingiz yozdingiz. Ansible moduli aynan shu juftlikning tayyor, sinalgan ko'rinishi. Bu dars 3-darsdagi role'lar va 5-darsdagi Terraform + Ansible birikmasining asosi.

Taxminiy vaqt: 6 kun (siz uchun). Birinchi kun Laboratoriya, 1–3 bo'limlar va A guruh. Ikkinchi kun 4-bo'lim va B guruh. Uchinchi kun 5-bo'lim, 8–9 vazifalar. To'rtinchi kun 6–8 bo'limlar, "Birga bajaramiz" va 10–14 vazifalar. Beshinchi kun 9-bo'lim va 15–18 vazifalar. Oltinchi kun 19-vazifa (kichik loyiha) va README. Sintaksisni yodlashga emas, mexanizmga e'tibor bering: modul nishonda qanday bajariladi (SSH + Python), `changed` va `ok` farqi nimadan kelib chiqadi, handler qachon ishlaydi va qachon ishlamay qoladi, bir xil nomli o'zgaruvchilardan qaysi biri yutadi, `command`/`shell` nima uchun idempotent emas, check mode nimani ko'rsata olmaydi.

Qanday o'qish kerak: har bo'limdagi misolni o'z laboratoriyangizda terib ishga tushiring va chiqishni darsdagi "qatorma-qator" izoh bilan solishtiring. Sizdagi IP manzillar, versiyalar va vaqtlar farq qiladi, bunday joylar `<...>` bilan belgilangan. Darsdagi misollar ataylab vazifalardagidan boshqa holatlarda berilgan: ularni o'z vazifangizga o'zingiz moslaysiz.

## Laboratoriya

Ikki xil mashina qatnashadi. **Control node** bu Ansible o'rnatilgan va buyruq beradigan mashina: sizning host'ingiz (Zorin yoki macOS). **Managed node** (darsda "nishon") bu Ansible sozlaydigan server: ikkita Multipass VM, `web1` va `db1` (Ubuntu 24.04). Paket, foydalanuvchi, servis va `/etc` ostidagi fayl o'zgarishlari faqat shu VM'larda bo'ladi. Playbook'larni hech qachon `localhost` ga qarata `become` bilan ishga tushirmang. `SETUP.md` dagi `lab` VM bu darsda ishlatilmaydi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | control node: `ansible`, `ansible-playbook`, `ansible-inventory`, `git`, `make`, `multipass`, tashqaridan `curl` |
| `web1`, `db1` VM | `ubuntu@web1:~$` | nishon: natijani tekshirish (`systemctl status`, `ss -tlnp`, `id`, `cat`) |

### Ansible'ni o'rnatish (host'da, bir marta)

Ansible Python'da yozilgan. `pipx` bu Python CLI dasturlarini har birini alohida virtual muhitga o'rnatadigan asbob (`npx`/global `npm i -g` ning izolyatsiyalangan ko'rinishi), tizim Python'i va uning paketlariga tegmaydi. Hujjat: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

```
# Zorin (amd64)
sudo apt install pipx
pipx ensurepath
pipx install --include-deps ansible

# macOS (arm64), either one
brew install ansible
# or: brew install pipx && pipx ensurepath && pipx install --include-deps ansible

# both
ansible --version
```

`pipx ensurepath` `~/.local/bin` ni `PATH` ga qo'shadi (yangi terminal oching). `--include-deps` kerak, chunki `ansible` paketining o'zida buyruq yo'q: `ansible`, `ansible-playbook` kabi buyruqlar uning bog'liqligi `ansible-core` dan keladi. macOS'da pipx Homebrew Python'ini ishlatadi, tizimning `/usr/bin/python3` iga tayanmang. Versiya raqamini darsdan emas, `ansible --version` dan oling. Windows control node sifatida qo'llab-quvvatlanmaydi, Zorin va macOS ikkalasi to'liq ishlaydi.

### SSH kaliti va VM'lar

Ansible nishonga SSH orqali kiradi (kalitlar: linux 10 va git 3). Laboratoriya uchun alohida kalit juftligi yarating, u har mashinada o'ziniki va hech qachon commit qilinmaydi:

```
ssh-keygen -t ed25519 -f ~/.ssh/iac_lab -C iac-lab
cat ~/.ssh/iac_lab.pub
```

Public kalit VM'ga cloud-init orqali joylanadi (iac 1, 8-bo'lim: VM birinchi yuklanishda bajaradigan sozlash fayli). Ish papkasida `lab-init.yaml` yarating:

```
#cloud-config
ssh_authorized_keys:
  - <~/.ssh/iac_lab.pub mazmuni, bitta qator>
```

Yuqori darajadagi `ssh_authorized_keys` ro'yxati standart `ubuntu` foydalanuvchisining `~/.ssh/authorized_keys` fayliga qo'shiladi. Keyin VM'lar (ikkala host'da bir xil buyruq):

```
multipass launch 24.04 --name web1 --cpus 1 --memory 1G --disk 5G --cloud-init lab-init.yaml
multipass launch 24.04 --name db1 --cpus 1 --memory 1G --disk 5G --cloud-init lab-init.yaml
multipass list
ssh -i ~/.ssh/iac_lab ubuntu@<web1-IP> hostname
```

`multipass list` ning `IPv4` ustuni har VM manzilini beradi (bitta VM uchun: `multipass info web1`). Oxirgi buyruq `web1` deb javob bersa, Ansible uchun hamma narsa tayyor. Birinchi ulanishda SSH host kalitini tasdiqlashni so'raydi (`yes`).

### IP manzillar va git

VM IP'si har mashinada va har qayta yaratishda boshqa, shuning uchun IP yozilgan fayl commit qilinmaydi. Bu darsdagi tartib:

- `inventory.ini`, `inventory.yml`: haqiqiy IP bilan, faqat lokal. Ish papkasidagi `.gitignore` ga yoziladi.
- `inventory.ini.example`, `inventory.yml.example`: xuddi shu fayllar, IP o'rnida `<web1-IP>`, `<db1-IP>`. Commit qilinadi.
- `lab-init.yaml` ham shu mashinaning public kalitini saqlaydi: lokal qoladi, repoga `lab-init.yaml.example` (kalit o'rnida placeholder) tushadi.
- `ansible.cfg`, playbook'lar, `templates/` commit qilinadi: ularda IP ham, kalit ham yo'q.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Ansible `pipx` bilan. VM'lar `x86_64` (apt tilida `amd64`), IP odatda `10.x.x.x`. Host Linux, lekin paket va servis o'zgarishlari baribir faqat VM'da. |
| macOS (uy) | Ansible Homebrew yoki `pipx` bilan. VM'lar `aarch64` (apt tilida `arm64`), IP odatda `192.168.x.x`. Host'da `ss`, `systemctl`, `ip` yo'q: tekshiruv buyruqlari `multipass exec web1 -- ...` yoki ad-hoc Ansible orqali VM'da bajariladi. `ssh`, `curl`, `time`, `diff` host'da bor. |

Ikkinchi mashinada tiklash. Git orqali faqat kod ko'chadi. Qayta yaratiladiganlar: (1) Ansible o'rnatish; (2) `~/.ssh/iac_lab` kaliti; (3) `lab-init.yaml` ni `.example` dan shu mashinaning public kaliti bilan; (4) yuqoridagi ikkita `multipass launch`; (5) `inventory.*` ni `.example` dan shu mashinadagi IP'lar bilan; (6) playbook'larni qayta ishga tushirish. VM ichidagi holat (paketlar, config'lar) ko'chmaydi va ko'chishi kerak ham emas: uni playbook tiklaydi, bu darsning asosiy g'oyasi shu.

Tozalash: `multipass delete --purge web1 db1`, keyin `multipass list` da faqat `lab` qolganini tekshiring.

---

## 1. Arxitektura

### Agentless va push

Ansible bu configuration management asbobi (iac 1, 4-bo'lim: mavjud server ichini kerakli holatga keltiradigan asbob). Ikki xususiyati uni boshqalardan ajratadi. **Agentless**: nishonda doimiy ishlaydigan Ansible dasturi (agent) yo'q. Nishondan ikki narsa talab qilinadi: SSH orqali kirish va Python interpretatori (Ubuntu 24.04 da `/usr/bin/python3` bor). **Push** (iac 1, 7-bo'lim): o'zgarish siz buyruq bergan paytda control node'dan nishonlarga yuboriladi, nishon o'zi hech narsa so'ramaydi.

### Mexanizm: bitta task bajarilganda nima bo'ladi

**Task** bu "shu modulni shu parametrlar bilan bajar" degan bitta qadam. **Modul** bu bitta turdagi resursni (paket, fayl, foydalanuvchi, servis) boshqaradigan kichik dastur.

1. Control node task parametrlarini o'qiydi, o'zgaruvchilarni qiymatga almashtiradi va modul kodi bilan argumentlarni bitta Python fayliga yig'adi (nomi `AnsiballZ_<modul>.py`).
2. SSH orqali nishonga ulanadi va shu faylni vaqtinchalik papkaga ko'chiradi (`~/.ansible/tmp/...`).
3. Nishondagi Python faylni bajaradi. Modul avval joriy holatni tekshiradi (paket o'rnatilganmi, fayl mazmuni bir xilmi), farq bo'lsagina o'zgartiradi. Bu 1-darsdagi "tekshir, keyin bajar".
4. Modul natijani stdout'ga JSON sifatida chiqaradi: `changed`, `failed`, `msg` va modulga xos maydonlar. Control node uni o'qiydi, vaqtinchalik fayl o'chiriladi.

Python nishonda aynan shuning uchun kerak: modul control node'da emas, nishonda ishlaydi. Buni `-vvv` flag'i bilan o'z ko'zingiz bilan ko'rish mumkin: chiqishda SSH buyruqlari, vaqtinchalik papka yaratish va `AnsiballZ_ping.py` nomi ko'rinadi.

```
ansible web1 -m ansible.builtin.ping -vvv
```

Bundan kelib chiqadigan xulosalar:

- `ansible.builtin.copy` va `ansible.builtin.template` da `src` control node'dagi fayl, `dest` nishondagi yo'l. Bu chalkashlik eng ko'p uchraydigan xatolardan.
- Har task har host uchun alohida SSH amali, shuning uchun Ansible bitta bash skriptdan sekinroq. Parallellik `forks` sozlamasi bilan: standart holatda bir vaqtda 5 ta host.
- Standart strategiya `linear`: birinchi task hamma hostda tugaydi, keyin ikkinchi task boshlanadi.

### Paket tarkibi va FQCN

`ansible` paketi ikki qismdan iborat: `ansible-core` (dvigatel, CLI buyruqlar va `ansible.builtin` modullari) va tanlangan collection'lar to'plami. **Collection** bu modullar va plugin'larning nomlangan paketi (`community.general`, `ansible.posix`, `amazon.aws`), npm'dagi scope'li paketga o'xshaydi (batafsil 3-darsda). Modul nomi to'liq yoziladi: `ansible.builtin.apt`, shunchaki `apt` emas. Bu **FQCN** (fully qualified collection name): `namespace.collection.modul`. Qisqa nom ham ishlaydi, lekin ikki collection'da bir xil nomli modul bo'lsa qaysi biri chaqirilishi noaniq, shuning uchun `ansible-lint` FQCN talab qiladi.

### Real ishda qachon kerak

- "Ansible ishlamayapti" degan muammoning yarmi aslida SSH muammosi. Avval `ssh -i <kalit> <user>@<IP>` qo'lda ishlashini tekshiring, keyin Ansible'ga o'ting.
- Minimal image'larda (ba'zi konteyner va cloud image'lar) Python yo'q: modul ishlamaydi, bunday holda Python birinchi qadam sifatida o'rnatiladi.
- 100 ta server va 50 ta task sekin bo'lsa, sabab SSH amallari soni: `forks` va `pipelining` (3-bo'lim) shu yerda yordam beradi.

### Nima uchun shunday

Ansible'dan oldingi asboblar (Puppet, Chef) har serverga agent o'rnatishni va markaziy serverni talab qilardi: agentning o'zini o'rnatish, yangilash va himoyalash alohida ish edi. Ansible (2012) "SSH va Python har Linux serverda allaqachon bor" degan kuzatuvga tayandi: yangi serverni boshqarish uchun unga hech narsa o'rnatish kerak emas. Narxi: agent doimiy ishlamagani uchun drift (iac 1, 1-bo'lim: haqiqiy holatning koddan uzoqlashishi) o'z-o'zidan tuzalmaydi, kimdir playbook'ni qayta ishga tushirishi kerak, va SSH'li push minglab serverda pull modelidan sekinroq.

## 2. Inventory

### Bu nima

**Inventory** bu Ansible boshqaradigan hostlar va ularning guruhlari ro'yxati. Usiz Ansible hech kimni tanimaydi: `ansible all ...` dagi `all` aynan inventory'dagi hamma host. Ikki format bor. INI (bu misol vazifadagidan boshqa tuzilishda, manzillar hujjatlar uchun ajratilgan diapazondan):

```
# inventory.ini (example layout)
[frontend]
fe1 ansible_host=192.0.2.11
fe2 ansible_host=192.0.2.12 app_port=3000

[cache]
cache1 ansible_host=192.0.2.21

[prod:children]
frontend
cache

[prod:vars]
ansible_user=deployer
```

Xuddi shu tuzilish YAML formatida ichma-ich kalitlar bilan yoziladi:

```
all:
  children:
    prod:
      vars:
        ansible_user: deployer
      children:
        frontend:
          hosts:
            fe1:
              ansible_host: 192.0.2.11
```

Qatorma-qator: `[frontend]` guruh nomi; `fe1` **inventory nomi** (alias), playbook va buyruqlarda faqat shu ishlatiladi; `ansible_host` haqiqiy ulanish manzili; `app_port=3000` faqat `fe2` ga tegishli **host o'zgaruvchisi**; `[prod:children]` a'zolari host emas, guruh bo'lgan ota guruh; `[prod:vars]` guruhdagi barcha hostlarga beriladigan **guruh o'zgaruvchilari**. Ulanishni boshqaradigan maxsus o'zgaruvchilar: `ansible_host`, `ansible_user`, `ansible_port`, `ansible_ssh_private_key_file`, `ansible_python_interpreter`.

### Mexanizm: guruhlar va o'zgaruvchilar qanday yig'iladi

Ansible inventory'ni o'qib, har host uchun bitta yakuniy o'zgaruvchilar lug'atini yig'adi. Ikki guruh har doim mavjud, ularni yozish shart emas: `all` (hamma host) va `ungrouped` (hech bir guruhga kirmagan hostlar). Bir xil o'zgaruvchi bir nechta darajada bo'lsa aniqrog'i yutadi: `all` < ota guruh < bola guruh < host. Natijani uchta buyruq ko'rsatadi:

```
$ ansible-inventory -i inventory.ini --graph
@all:
  |--@ungrouped:
  |--@prod:
  |  |--@frontend:
  |  |  |--fe1
  |  |  |--fe2
  |  |--@cache:
  |  |  |--cache1
```

`@` bilan boshlangan qatorlar guruh, qolganlari host; chekinish kim kimning ichida ekanini ko'rsatadi. `ansible-inventory --list` butun inventory'ni JSON qilib chiqaradi (host o'zgaruvchilari `_meta.hostvars` ostida), `ansible-inventory --host fe2` bitta hostning yakuniy o'zgaruvchilarini beradi: `ansible_user` guruhdan, `app_port` host qatoridan kelganini shu yerda ko'rasiz.

O'zgaruvchilarni inventory faylidan tashqarida saqlash ham mumkin: inventory yonidagi `group_vars/<guruh>.yml` va `host_vars/<host>.yml` fayllari avtomatik o'qiladi. Bu darsda ular borligini bilish yetarli, loyiha tuzilishi sifatida 3-darsda ishlatiladi.

**Tuzoq: INI formatida tiplar.** Host qatoridagi `key=value` Python literal sifatida o'qiladi (`app_port=3000` son bo'ladi), `[group:vars]` bo'limidagi qiymatlar esa har doim string. `"3000"` va `3000` taqqoslashda teng emas. YAML inventory'da tip siz yozganingizdek, shuning uchun jiddiy loyihalarda YAML afzal.

### Host pattern

Buyruq qaysi hostlarga borishini pattern belgilaydi: `all`, `frontend` (guruh), `fe1` (host), `frontend:cache` (birlashma), `frontend:&prod` (kesishma), `all:!cache` (istisno). `ansible-playbook` ning `--limit` flag'i ham shu sintaksisni qabul qiladi: play'dagi `hosts:` ni yanada toraytiradi. Pattern kimni tanlashini hech narsa bajarmasdan ko'rish: `ansible 'all:!cache' --list-hosts`. zsh'da `!` va `&` bor pattern'ni bittalik qo'shtirnoqqa oling.

### Real ishda qachon kerak

- Bir xil playbook dev, stage va prod'ga ishlaydi: farq faqat inventory'da (har muhitga alohida inventory fayli).
- Deploy'ni avval bitta serverda sinash: `--limit fe1`, keyin hammasiga.
- Cloud'da serverlar ro'yxati doim o'zgaradi, statik fayl eskiradi: buning yechimi dynamic inventory (3-dars).

### Nima uchun shunday

Inventory "nima qilish" (playbook) va "kimda qilish" ni ajratadi, React komponenti va unga beriladigan props kabi: playbook bitta, ma'lumot har muhitda boshqa. INI format tarixan birinchi va qisqa, lekin tiplar noaniq va ichma-ich tuzilma noqulay; YAML uzunroq, lekin playbook'lar bilan bir tilda. Muqobili har buyruqda hostlarni qo'lda sanash (`-i 'host1,host2,'`) bo'lardi, u guruh va o'zgaruvchi tushunchasini bermaydi.

## 3. ansible.cfg

### Bu nima va qayerdan o'qiladi

`ansible.cfg` bu Ansible'ning sozlamalar fayli (INI format): standart inventory, ulanish foydalanuvchisi, kalit fayli va hokazo. U quyidagi tartibda qidiriladi va **birinchi topilgani** ishlatiladi, fayllar birlashtirilmaydi:

1. `ANSIBLE_CONFIG` muhit o'zgaruvchisi ko'rsatgan fayl
2. joriy papkadagi `ansible.cfg`
3. `~/.ansible.cfg`
4. `/etc/ansible/ansible.cfg`

Loyiha papkasida saqlash odat: sozlamalar repo bilan birga yuradi va ikkala mashinada bir xil bo'ladi. Bu `package.json` yonidagi `.npmrc` ga o'xshaydi, farqi: `.npmrc` darajalari birlashadi, `ansible.cfg` esa yo'q. Oqibati: buyruqni boshqa papkadan ishga tushirsangiz loyiha fayli topilmaydi va Ansible jimgina boshqa sozlamalar bilan ishlaydi.

### Qaysi sozlamalarni yozib qo'yishga arziydi

| Bo'lim va kalit | Nima qiladi |
|-----------------|-------------|
| `[defaults] inventory` | standart inventory yo'li, `-i` yozmaslik uchun |
| `[defaults] remote_user` | nishonga qaysi foydalanuvchi bilan kirish |
| `[defaults] private_key_file` | SSH private kalit yo'li (`~` ishlaydi, shuning uchun ikkala mashinada bir xil) |
| `[defaults] host_key_checking` | nishonning SSH host kaliti `known_hosts` bilan solishtirilsinmi |
| `[defaults] interpreter_python` | nishonda qaysi Python ishlatilsin |
| `[defaults] forks` | bir vaqtda nechta host (standart 5) |
| `[ssh_connection] pipelining` | modulni faylga ko'chirmasdan SSH kanali orqali uzatish |

Faqat laboratoriyaga xos qism shunday ko'rinadi (to'liq faylni 4-vazifada o'zingiz tuzasiz):

```
[defaults]
host_key_checking = False
interpreter_python = /usr/bin/python3

[ssh_connection]
pipelining = True
```

- `host_key_checking = False` faqat laboratoriya uchun: Multipass VM qayta yaratilganda IP takrorlanishi mumkin, host kaliti esa yangi bo'ladi va SSH "kalit o'zgargan" deb ulanishni rad etadi. Production'da bu tekshiruv yoqilgan bo'lishi shart, u "men haqiqatan o'sha serverga ulanyapmanmi" degan savolga javob beradi.
- `interpreter_python` berilmasa Ansible nishonda Python'ni o'zi qidiradi va topgan yo'li haqida ogohlantirish chiqarishi mumkin. Aniq yo'l yozilsa qidiruv ham, ogohlantirish ham yo'q.
- `pipelining` 1-bo'limdagi 2-qadamni (faylni ko'chirish) olib tashlaydi: har task'da SSH amallari kamayadi va playbook sezilarli tezlashadi.

### Misol: qaysi fayl va qaysi sozlama ishlayapti

```
$ ansible --version
ansible [core <versiya>]
  config file = /home/<user>/learn-devOps/iac/02-ansible-basics/ansible.cfg
  configured module search path = [...]
  ansible python module location = <yo'l>
  executable location = <yo'l>/ansible
  python version = <versiya> (...) (<interpreter yo'li>)
  jinja version = <versiya>
  ...
```

Birinchi qator `ansible-core` versiyasi (`ansible` paketi versiyasi emas, uni `pipx list` ko'rsatadi). `config file` hozir ishlatilayotgan fayl; `None` bo'lsa hech bir fayl topilmagan. `python version` bu control node'dagi Python, nishondagisi emas. `ansible-config dump --only-changed` faqat standartdan farq qiladigan sozlamalarni va har biri qayerdan kelganini chiqaradi.

### Real ishda qachon kerak

- "Mening mashinamda ishlaydi, CI'da yo'q": birinchi tekshiruv `ansible --version` dagi `config file` qatori.
- Jamoada hamma bir xil sozlama bilan ishlashi uchun `ansible.cfg` repoda turadi, shaxsiy narsalar (kalit yo'li boshqa bo'lsa) muhit o'zgaruvchisi bilan beriladi (`ANSIBLE_PRIVATE_KEY_FILE`).

### Nima uchun shunday

"Birinchi topilgan fayl yutadi" qoidasi oddiy va oldindan aytib bo'ladigan: qiymat qaysi fayldan kelganini bilish uchun bitta faylni o'qish kifoya. Narxi shuki, loyiha fayli `~/.ansible.cfg` dagi sozlamalarni meros qilib olmaydi. Xavfsizlik uchun yana bir qoida bor: joriy papka hamma yoza oladigan (world-writable) bo'lsa, undagi `ansible.cfg` ogohlantirish bilan e'tiborsiz qoldiriladi, chunki begona odam u yerga zararli sozlama qo'yishi mumkin.

## 4. Ad-hoc buyruqlar va modullar

### Bu nima

**Ad-hoc buyruq** bu playbook yozmasdan bitta modulni bir marta ishga tushirish: `ansible <pattern> -m <modul> -a "<argumentlar>"`. Tezkor tekshiruv va bir martalik ishlar uchun, `node -e` yoki REPL kabi. Takrorlanadigan ish playbook'ga yoziladi.

```
$ ansible all -m ansible.builtin.ping
web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
db1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Qatorma-qator: `web1` inventory nomi; `SUCCESS` modul xatosiz tugadi; `=>` dan keyin modul qaytargan JSON; `"changed": false` nishonda hech narsa o'zgarmadi; `"ping": "pong"` modulning o'z javobi. `ping` ICMP emas: u 1-bo'limdagi butun zanjirni (SSH ulanish, Python, modulni bajarish, JSON qaytarish) tekshiradi. Ansible versiyasi va sozlamaga qarab chiqishda `ansible_facts.discovered_interpreter_python` maydoni ham bo'lishi mumkin. Hostlar tartibi har safar boshqa bo'lishi mumkin, chunki ular parallel bajariladi.

### Flag'lar

- `-m` modul nomi. Berilmasa `ansible.builtin.command` ishlatiladi: `ansible web1 -a "uptime"`.
- `-a` modul argumentlari, `key=value` juftliklari (yoki `command` uchun buyruqning o'zi).
- `--become` (`-b`) **privilege escalation**: SSH bilan oddiy foydalanuvchi sifatida kirib, task'ni boshqa foydalanuvchi nomidan bajarish. Standart usul `sudo` (linux 10), standart maqsad `root`. Multipass'dagi `ubuntu` parolsiz sudo'ga ega; parol kerak bo'lgan serverda `-K` (`--ask-become-pass`) so'raydi.
- `-i` inventory, `--limit` hostlarni toraytirish, `-v` dan `-vvv` gacha batafsillik.
- Modul hujjati terminalda: `ansible-doc ansible.builtin.file` (parametrlar, standart qiymatlar, misollar), ro'yxat: `ansible-doc -l`.

### Mexanizm: modul va buyruq farqi

Xuddi shu ishni ikki yo'l bilan qilib, ikkinchi ishga tushirishni solishtiring. Modul bilan:

```
$ ansible web1 -m ansible.builtin.file -a "path=/tmp/lab-dir state=directory"
web1 | CHANGED => {
    "changed": true,
    "path": "/tmp/lab-dir",
    "state": "directory",
    ...
}
$ ansible web1 -m ansible.builtin.file -a "path=/tmp/lab-dir state=directory"
web1 | SUCCESS => {
    "changed": false,
    "path": "/tmp/lab-dir",
    ...
}
```

Birinchi safar papka yo'q edi, modul yaratdi: `CHANGED`. Ikkinchi safar modul holatni tekshirdi, papka bor, hech narsa qilmadi: `SUCCESS` va `changed: false`. Siz holatni tasvirladingiz (`state=directory`), amalni emas. Endi buyruq bilan:

```
$ ansible web1 -a "mkdir /tmp/lab-dir2"
web1 | CHANGED | rc=0 >>

$ ansible web1 -a "mkdir /tmp/lab-dir2"
web1 | FAILED | rc=1 >>
mkdir: cannot create directory ‘/tmp/lab-dir2’: File exists
non-zero return code
```

`command` moduli buyruq nima qilishini bilmaydi. U faqat exit code'ni ko'radi (`rc`, linux 1): `0` bo'lsa har doim `CHANGED` deydi (o'zgartirgan bo'lishi mumkin, deb), noldan farqli bo'lsa `FAILED`. Idempotency (iac 1, 3-bo'lim: qayta bajarish natijani o'zgartirmaydi) modulning ichidagi tekshiruvdan keladi, Ansible'ning o'zidan emas. `command` shell'siz bajaradi: pipe, `>`, `&&`, `$VAR` ishlamaydi. `ansible.builtin.shell` esa `/bin/sh` orqali bajaradi. Ikkalasi ham oxirgi chora.

### Ko'p ishlatiladigan `ansible.builtin` modullari

| Modul | Vazifa | Asosiy parametrlar |
|-------|--------|--------------------|
| `apt` | paket (linux 12) | `name`, `state` (`present`/`absent`/`latest`), `update_cache`, `cache_valid_time` |
| `copy` | faylni control node'dan nishonga | `src` yoki `content`, `dest`, `owner`, `group`, `mode` |
| `template` | Jinja2 dan fayl | `src`, `dest`, `mode`, `validate` |
| `file` | papka, symlink, huquqlar | `path`, `state` (`directory`/`link`/`absent`/`touch`), `mode` |
| `lineinfile` | fayldagi bitta qator | `path`, `regexp`, `line`, `state` |
| `user`, `group` | foydalanuvchi, guruh (linux 10) | `name`, `groups`, `append`, `shell`, `state` |
| `service`, `systemd_service` | servis (linux 11) | `name`, `state` (`started`/`restarted`/`reloaded`), `enabled` |
| `command`, `shell` | ixtiyoriy buyruq | `cmd`, `creates`, `removes`, `chdir` |
| `debug` | qiymatni ekranga chiqarish | `msg` yoki `var` |

**Tuzoq: `mode: 644` (qo'shtirnoqsiz, boshida nolsiz).** YAML buni o'nlik son 644 deb o'qiydi, modul esa sakkizlik huquq kutadi, natija kutilmagan huquqlar. Har doim string yozing: `mode: "0644"`.

### Real ishda qachon kerak

- "Barcha serverlarda disk qancha to'lgan?", "kimda eski kernel?": bitta ad-hoc buyruq, 50 ta SSH sessiya o'rniga.
- Incident paytida bir martalik amal (servisni qayta ishga tushirish). Lekin doimiy o'zgarish ad-hoc bilan qilinsa u kodda yo'q, ya'ni drift.

### Nima uchun shunday

Modullar "holatni tasvirla" modelini beradi: har modul o'z resursi uchun tekshirishni, o'zgartirishni va hisobotni biladi. Muqobili hamma narsani `shell` bilan yozish, ya'ni SSH ustidan bash: ishlaydi, lekin idempotency, `changed` hisoboti, check mode va diff'ni har qadam uchun o'zingiz yozasiz (1-darsda yozganingizdek).

## 5. Playbook

### Bu nima

**Playbook** bu YAML fayl, ichida **play**'lar ro'yxati. Play hostlar guruhini (`hosts:`) task'lar ro'yxati bilan bog'laydi. Misol (vazifadagidan boshqa holat: kichik asboblar va `cron` servisi):

```
# tools.yml
- name: Base tools on all lab hosts
  hosts: all
  become: true
  tasks:
    - name: Install tools
      ansible.builtin.apt:
        name: [tree, jq]
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Ensure cron is running
      ansible.builtin.service:
        name: cron
        state: started
        enabled: true
```

Qatorma-qator: fayl ro'yxat (`-`) bilan boshlanadi, har element bitta play; `name` chiqishda ko'rinadigan sarlavha; `hosts` pattern (2-bo'lim); `become: true` play'dagi barcha task'lar `sudo` orqali root nomidan (uni alohida task darajasida ham yozish mumkin, keraksiz joyda root bo'lmaslik uchun); har task'da `name` va bitta modul, modul ostida uning parametrlari. `cache_valid_time: 3600` apt indeksi bir soatdan eski bo'lsagina yangilanadi, aks holda `update_cache` har ishga tushirishda tarmoqqa chiqadi. Paketlar ro'yxat bilan berilgan: bitta apt tranzaksiyasi, loop'dan tez.

### Misol: chiqishni o'qish

```
$ ansible-playbook tools.yml

PLAY [Base tools on all lab hosts] *********************************************

TASK [Gathering Facts] *********************************************************
ok: [web1]
ok: [db1]

TASK [Install tools] ***********************************************************
changed: [web1]
changed: [db1]

TASK [Ensure cron is running] **************************************************
ok: [web1]
ok: [db1]

PLAY RECAP *********************************************************************
db1                        : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
web1                       : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`PLAY [...]` play boshlandi. `TASK [Gathering Facts]` siz yozmagan yashirin task: har play boshida nishon haqida ma'lumot yig'adi (7-bo'lim). Har task ostida har host uchun bitta natija: `ok` holat allaqachon to'g'ri edi, `changed` modul nimanidir o'zgartirdi (terminalda `ok` yashil, `changed` sariq, xato qizil). `cron` allaqachon ishlab turgan, shuning uchun `ok`. `PLAY RECAP` hisoblagichlari: `ok` muvaffaqiyatli task'lar soni (`changed` bo'lganlari ham shu songa kiradi), `changed` o'zgartirganlar, `unreachable` SSH bilan yetib bo'lmadi, `failed` task xato berdi, `skipped` shart bajarilmagani uchun o'tkazib yuborildi, `rescued` va `ignored` xatoni qayta ishlash bilan bog'liq (3-dars). Ikkinchi ishga tushirishda hamma qator `ok`, recap `changed=0`: bu 1-darsda o'zingiz yozgan hisobotning aynan o'zi va yaxshi playbook'ning asosiy mezoni.

Task bir hostda xato bersa (`fatal: [web1]: FAILED! => {...}`), o'sha host play'ning qolgan task'laridan chiqariladi, boshqa hostlar davom etadi, buyruq exit code'i noldan farqli bo'ladi.

Foydali flag'lar: `--syntax-check` (faqat sintaksis), `--list-hosts`, `--list-tasks` (hech narsa bajarmasdan ro'yxat), `--limit web1`, `--start-at-task "<task nomi>"`, `-v` (har task'ning JSON natijasi).

### Handler (tanishuv)

**Handler** bu faqat xabar (`notify`) kelganda ishlaydigan task. Odatiy holat: config fayli o'zgarsa servisni qayta yuklash, o'zgarmasa tegmaslik. Fragment (shartli `myapp` servisi):

```
  tasks:
    - name: Deploy app config
      ansible.builtin.template:
        src: app.conf.j2
        dest: /etc/myapp/app.conf
        mode: "0644"
      notify: Restart myapp

  handlers:
    - name: Restart myapp
      ansible.builtin.service:
        name: myapp
        state: restarted
```

Qoidalar:

- `notify` qiymati handler'ning `name` iga aynan teng bo'lishi kerak.
- Handler faqat task `changed` bo'lsa xabar oladi. Config o'zgarmasa restart ham yo'q.
- Handler'lar play'dagi barcha task'lar tugagach ishlaydi (chiqishda `RUNNING HANDLER [Restart myapp]`), bir necha task xabar bergan bo'lsa ham bir marta.
- Ishlash tartibi `handlers:` bo'limida yozilgan tartib, `notify` tartibi emas.
- Darhol ishlatish kerak bo'lsa task'lar orasiga: `- ansible.builtin.meta: flush_handlers`.

**Tuzoq: yo'qolgan handler.** Config task'i `changed` bo'ldi, handler navbatga tushdi, keyingi task xato berdi va play shu hostda to'xtadi: handler ishlamadi. Xatoni tuzatib qayta ishga tushirsangiz config task'i endi `ok` (fayl allaqachon joyida), handler xabar olmaydi. Natija: yangi config diskda, servis eski config bilan ishlayapti. Himoya: `--force-handlers` flag'i (yoki play'da `force_handlers: true`) va muhim joylarda `flush_handlers`. Handler'lar bilan chuqurroq ish (`listen`, role ichida) 3-darsda.

### Real ishda qachon kerak

- Yangi serverni tayyorlash, deploy, config o'zgartirish: hammasi playbook, u repoda turadi va pull request orqali review qilinadi.
- `changed=0` bo'lmagan ikkinchi ishga tushirish signal: yo task idempotent emas, yo serverda kimdir qo'lda o'zgartirgan.

### Nima uchun shunday

Playbook declarative (iac 1, 2-bo'lim): siz kerakli holatni yozasiz, unga qanday yetishni modul hal qiladi. Bu React'dagi fikrga yaqin: UI qanday ko'rinishini tasvirlaysiz, DOM amallarini emas. Farqi: Ansible task'larni yuqoridan pastga, yozilgan tartibda bajaradi, ya'ni tartib sizning zimmangizda (Terraform'dan farqli, 4-dars). Handler'ning play oxirida va bir marta ishlashi ham ataylab: beshta config o'zgarsa servis besh marta emas, bir marta qayta ishga tushadi. Muqobili har config task'idan keyin shartsiz restart, bu har ishga tushirishda keraksiz uzilish degani.

## 6. O'zgaruvchilar va precedence

### Bu nima

O'zgaruvchi playbook'ni ma'lumotdan ajratadi: port, paket nomi, muhit nomi kodga qattiq yozilmaydi. Murojaat Jinja2 ifodasi bilan: `{{ log_level }}`. Muammo shundaki, o'zgaruvchi ko'p joyda aniqlanishi mumkin, va bir xil nom bir nechta joyda bo'lsa Ansible ularni birlashtirmaydi: ustunroq manba to'liq yutadi. Bu tartib **precedence** deyiladi. To'liq ro'yxat 22 darajali (Manbalar), bu darsda uchraydigan darajalar pastdan yuqoriga:

| Daraja | Manba |
|--------|-------|
| eng past | role `defaults/main.yml` (3-dars) |
| | inventory guruh o'zgaruvchilari: avval `all`, keyin ota guruh, keyin bola guruh |
| | inventory host o'zgaruvchilari (`host_vars`, host qatori) |
| | facts (7-bo'lim) |
| | play `vars:`, keyin `vars_files:` |
| | role `vars/main.yml` (3-dars) |
| | block va task `vars:` |
| | `set_fact`, `register` |
| eng yuqori | `-e` / `--extra-vars` |

Eslab qolish uchun ikki qoida: "aniqroq va kodga yaqinroq manba yutadi" (guruh < host < play < task), va **extra vars har doim yutadi**: `-e` bilan berilgan qiymatni playbook ichidagi hech narsa bosib o'ta olmaydi.

### Misol

```
# vars-demo.yml
- name: Variable demo
  hosts: web1
  gather_facts: false
  vars:
    log_level: info
  tasks:
    - name: Show value
      ansible.builtin.debug:
        msg: "log_level is {{ log_level }}"
```

```
$ ansible-playbook vars-demo.yml
TASK [Show value] **************************************************************
ok: [web1] => {
    "msg": "log_level is info"
}
$ ansible-playbook vars-demo.yml -e log_level=debug
ok: [web1] => {
    "msg": "log_level is debug"
}
```

Birinchi safar qiymat play `vars:` dan, ikkinchisida `-e` dan keldi. `debug` moduli nishonga bormaydi va hech qachon `changed` bermaydi, u faqat control node'da qiymatni chop etadi. `-e key=value` shaklida qiymat har doim string; son yoki boolean kerak bo'lsa JSON bering: `-e '{"workers": 4}'`.

### YAML va `{{ }}` tuzog'i, register, default

- JS'dagi template literal (`${port}`) bilan o'xshashlik haqiqiy: `{{ }}` ichida ifoda hisoblanadi. Lekin YAML'da `{` belgisi lug'at boshlanishi. Shuning uchun qiymat `{{` bilan boshlansa butun qiymat qo'shtirnoqda bo'lishi shart: `port: "{{ app_port }}"` to'g'ri, `port: {{ app_port }}` sintaksis xatosi. Qiymat matn bilan boshlansa (`msg: value is {{ x }}`) qo'shtirnoq shart emas, lekin odat sifatida yozing.
- `register` task natijasini (modul qaytargan JSON'ni) o'zgaruvchiga yozadi: `register: result`, keyin `result.rc`, `result.stdout`, `result.changed`.
- Aniqlanmagan o'zgaruvchiga murojaat xato beradi (JS'dagi kabi jimgina `undefined` emas). Standart qiymat filtr bilan: `{{ log_level | default('info') }}`.

### Real ishda qachon kerak

- Bitta playbook, uch muhit: standart qiymat bitta joyda, muhitga xos qiymat shu muhit inventory'sining guruh o'zgaruvchilarida.
- CI'dan bir martalik qiymat: `-e app_version=<tag>`.
- "Nima uchun qiymat o'zgarmayapti" qidiruvi: `ansible-inventory --host <host>` inventory'dan nima kelganini, `debug` task'i yakuniy qiymatni ko'rsatadi.

### Nima uchun shunday

22 daraja ortiqcha ko'rinadi, lekin har biri real ehtiyojdan chiqqan: role muallifi standart beradi (`defaults`, eng past, chunki uni bosib o'tish oson bo'lishi kerak), muhit egasi uni inventory'da o'zgartiradi, operator bir martalik holat uchun `-e` bilan ustidan yozadi. Amaliy qoida: har o'zgaruvchini bitta joyda aniqlang. CSS'dagi specificity kabi: tartibni bilish kerak, lekin unga tayangan kodni o'qish qiyin.

## 7. Facts

### Bu nima va mexanizm

**Facts** bu Ansible nishonning o'zidan yig'adigan ma'lumot: OS, kernel, arxitektura, tarmoq, xotira, disklar. Play boshidagi `Gathering Facts` task'i aslida `ansible.builtin.setup` modulini ishga tushiradi: modul nishonda `/proc`, `/etc/os-release` (linux 1) va boshqa manbalarni o'qib, natijani JSON qilib qaytaradi. Playbook'da ular `ansible_facts` lug'atida: `{{ ansible_facts['distribution'] }}`. Xuddi shu qiymatlar `ansible_` prefiksli alohida o'zgaruvchi sifatida ham ko'rinadi (`ansible_distribution`), yangi kodda lug'at shakli tavsiya etiladi.

```
$ ansible web1 -m ansible.builtin.setup -a "filter=ansible_architecture"
web1 | SUCCESS => {
    "ansible_facts": {
        "ansible_architecture": "x86_64"
    },
    "changed": false
}
```

`filter` nomi mos kelgan fact'larnigina qoldiradi (`*` bilan naqsh berish mumkin), usiz chiqish yuzlab qator. Ad-hoc chiqishda nomlar `ansible_` prefiksi bilan, playbook'dagi `ansible_facts[...]` ichida prefikssiz. Mac'dagi VM'da qiymat `aarch64`.

Ko'p ishlatiladiganlari: `distribution`, `distribution_version`, `distribution_release`, `os_family`, `hostname`, `architecture`, `default_ipv4.address`, `memtotal_mb`, `processor_vcpus`. Fact yig'ish har host uchun vaqt oladi; fact kerak bo'lmagan play'da `gather_facts: false`.

### Arxitektura: qattiq yozmang

Sizning ikki laboratoriyangiz aynan shu bilan farq qiladi: Zorin'da nishon `x86_64`, Mac'da `aarch64`. Binary yuklaydigan URL yoki apt repo qatoriga `amd64` deb qattiq yozilgan playbook ikkinchi mashinada sinadi. Kernel nomlari (`x86_64`/`aarch64`) va Debian paket nomlari (`amd64`/`arm64`) boshqa-boshqa, shuning uchun fact'dan lug'at orqali o'tiladi:

```
vars:
  deb_arch_map:
    x86_64: amd64
    aarch64: arm64
  deb_arch: "{{ deb_arch_map[ansible_facts['architecture']] }}"
```

### Real ishda qachon kerak

- Bir playbook Ubuntu va Rocky'da ishlashi kerak: `os_family` bo'yicha shart (8-bo'lim).
- Config'ni serverga moslash: worker soni `processor_vcpus` dan, tinglash manzili `default_ipv4.address` dan.

### Nima uchun shunday

Fact'lar inventory'ni "qo'lda yozilgan haqiqat"dan qutqaradi: serverning xotirasi yoki arxitekturasini inventory'ga yozsangiz u eskiradi, nishondan so'ralgan qiymat esa har doim haqiqiy. Narxi vaqt: har play boshida qo'shimcha task. Muqobili har kerakli ma'lumot uchun alohida `command` yozib `register` qilish.

## 8. Template, loop, shartlar

### Jinja2 template

**Template** bu ichida o'zgaruvchi va boshqaruv konstruksiyalari bo'lgan matn fayli, undan har host uchun tayyor config hosil qilinadi. **Jinja2** Python dunyosining template tili (JSX yoki Handlebars vazifasida). `ansible.builtin.template` faylni **control node'da** render qiladi (shu host'ning o'zgaruvchi va fact'lari bilan), natijani nishondagi fayl bilan solishtiradi va faqat farq bo'lsa yozadi (`changed`). Kengaytma odatda `.j2`, fayllar playbook yonidagi `templates/` papkasida.

```
# templates/worker.conf.j2
host={{ ansible_facts['hostname'] }}
workers={{ ansible_facts['processor_vcpus'] * 2 }}
{% for d in backup_dirs %}
dir={{ d }}
{% endfor %}
{% if debug_mode | default(false) %}
debug=on
{% endif %}
```

`backup_dirs: [/srv/a, /srv/b]` va 1 vCPU'li `web1` uchun natija:

```
host=web1
workers=2
dir=/srv/a
dir=/srv/b
```

`{{ }}` ifoda (qiymat chiqaradi), `{% %}` boshqaruv (`for`, `if`, chiqishga hech narsa yozmaydi), `{# #}` komment. `|` filtr: qiymatni funksiyadan o'tkazadi (`default`, `upper`, `join(", ")`, `length`, `to_nice_yaml`). `debug_mode` aniqlanmagan, `default(false)` tufayli `if` bloki tushib qoldi. `{% %}` qatorlari o'rnida bo'sh qator qolmaganiga e'tibor bering: `template` moduli blok tegidan keyingi yangi qatorni o'zi olib tashlaydi. Template faylining o'zida YAML qo'shtirnoq tuzog'i yo'q, u faqat YAML ichida yozilgan `{{ }}` ga tegishli. `validate` parametri natijani joyiga qo'yishdan oldin tekshiradi (`%s` vaqtinchalik fayl yo'li): `validate: "visudo -cf %s"`.

### Loop

`loop` bitta task'ni ro'yxatning har elementi uchun takrorlaydi, joriy element `item` o'zgaruvchisida:

```
- name: Create data directories
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: directory
    mode: "{{ item.mode }}"
  loop:
    - { path: /srv/lab/in, mode: "0755" }
    - { path: /srv/lab/out, mode: "0750" }
  loop_control:
    label: "{{ item.path }}"
```

Chiqishda har element alohida qator: `changed: [web1] => (item=/srv/lab/in)`. `loop_control.label` qavs ichida butun `item` o'rniga faqat kerakli qismni ko'rsatadi (ichida parol bor lug'atlar uchun muhim). Paket modullariga ro'yxatni loop'siz bering (5-bo'limdagi `name: [tree, jq]`).

### when

`when` task'ga shart qo'yadi, bajarilmasa task shu hostda `skipping: [web1]` bo'ladi va recap'da `skipped` ortadi:

```
- name: Install tools on Debian family only
  ansible.builtin.apt:
    name: tree
  when: ansible_facts['os_family'] == "Debian"
```

`when` qiymati tayyor Jinja2 ifoda, ichida `{{ }}` yozilmaydi. Ro'yxat berilsa shartlar `and` bilan bog'lanadi. `loop` bilan birga `when` har element uchun alohida tekshiriladi.

### Real ishda qachon kerak

- Bitta template'dan o'nlab serverning har biriga o'z config'i (hostname, IP, worker soni).
- Foydalanuvchilar, papkalar, firewall qoidalari ro'yxati o'zgaruvchida, task bitta.

### Nima uchun shunday

Config fayllarni `lineinfile` bilan qator-qator tuzatish o'rniga butun faylni template'dan chiqarish declarative: fayl to'liq sizning nazoratingizda va diff aniq. Render control node'da bo'lgani uchun nishonda Jinja2 kerak emas. `when` va `loop` YAML'ga dasturlash tilining ikki konstruksiyasini qo'shadi; ko'payib ketsa playbook o'qilmaydigan bo'ladi, bu holda mantiq o'zgaruvchilar tuzilishiga yoki role'ga ko'chiriladi (3-dars).

## 9. Idempotency, changed_when, check mode

### `command` va `shell` ni idempotent qilish

4-bo'limda ko'rdingiz: `command` har safar `changed` deydi, chunki Ansible buyruq nima qilganini bilmaydi. Buni task'ning o'zida aytib berish mumkin:

```
- name: Initialize app data once
  ansible.builtin.command:
    cmd: /opt/app/bin/init
    creates: /opt/app/data/.initialized

- name: Check service state
  ansible.builtin.command: systemctl is-active cron
  register: svc
  changed_when: false
  failed_when: svc.rc not in [0, 3]
```

- `creates`: ko'rsatilgan fayl mavjud bo'lsa buyruq umuman bajarilmaydi (`ok`). `removes` teskarisi: fayl yo'q bo'lsa bajarilmaydi.
- `changed_when: false`: faqat o'qiydigan buyruq hech qachon `changed` emas. Odatda `register` bilan birga.
- `changed_when: "'created' in result.stdout"`: `changed` ni buyruq chiqishiga qarab aniqlash (buyruq nima qilganini o'zi yozsa).
- `failed_when` muvaffaqiyatsizlik mezonini qayta aniqlaydi. `systemctl is-active` servis faol bo'lmasa `3` qaytaradi, bu xato emas, javob; boshqa kodlar haqiqiy muammo. Keyingi task natijadan foydalanadi: `when: svc.rc == 0`.

### Check mode va diff

`--check` bu dry-run (1-darsdagi o'z `--check` flag'ingiz): modullar holatni tekshiradi, lekin o'zgartirmaydi, faqat "o'zgartirgan bo'lardim" (`changed`) deb hisobot beradi. `--diff` fayl o'zgarishlarini unified diff ko'rinishida ko'rsatadi (git 1 dagi `git diff` formati). Ikkalasi birga: `ansible-playbook site.yml --check --diff`. Misol chiqishi "Birga bajaramiz"da.

Cheklovlar:

- `command`/`shell` check mode'da bajarilmaydi va `skipping` bo'ladi (`creates`/`removes` berilgan bo'lsa modul faqat faylni tekshirib javob beradi). Demak ularning `register` natijasiga tayangan keyingi task'lar xato berishi mumkin. Faqat o'qiydigan buyruqqa `check_mode: false` qo'yib, uni check mode'da ham bajartirish mumkin.
- Zanjirli bog'liqlik: check mode'da paket o'rnatilmaydi, keyingi "servisni ishga tushir" task'i "bunday servis yo'q" deb xato berishi mumkin. Bu playbook xatosi emas, check mode'ning tabiati.
- `--diff` faqat diff'ni qo'llab-quvvatlaydigan modullar uchun ma'lumot beradi (fayl modullari yaxshi, boshqalari turlicha).

### Real ishda qachon kerak

- Production'ga chiqarishdan oldin `--check --diff`: "bu playbook aynan nimani o'zgartiradi" degan savolga javob, pull request'dagi diff kabi.
- Drift aniqlash: jadval bo'yicha `--check` ishga tushirib, `changed` noldan katta bo'lsa signal berish.

### Nima uchun shunday

Check mode har modul ichida alohida amalga oshirilgan: modul "tekshir" qismini bajarib, "bajar" qismini o'tkazib yuboradi. `command` uchun bunday ajratish yo'q, shuning uchun u ko'r nuqta. Terraform'da `plan` asosiy ish oqimi va to'liq (4-dars), Ansible'da check mode yordamchi va taxminiy: Ansible state saqlamaydi (iac 1, 6-bo'lim), har safar nishondan so'raydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Control node | Ansible o'rnatilgan va buyruq beradigan mashina (bu kursda host) |
| Managed node (nishon) | Ansible SSH orqali sozlaydigan server |
| Agentless | nishonda doimiy ishlaydigan boshqaruv dasturi yo'qligi |
| Modul | bitta turdagi resursni tekshirib, kerak bo'lsa o'zgartiradigan va JSON qaytaradigan dastur |
| FQCN | modulning to'liq nomi: `namespace.collection.modul` |
| Collection | modullar va plugin'larning nomlangan, alohida versiyalanadigan paketi |
| Inventory | hostlar, guruhlar va ularning o'zgaruvchilari ro'yxati |
| Host pattern | buyruq qaysi hostlarga borishini tanlaydigan ifoda (`web:!db`) |
| Ad-hoc buyruq | playbook'siz bitta modulni bir marta ishga tushirish |
| Task | bitta modul chaqiruvi va uning parametrlari |
| Play | hostlar guruhini task'lar ro'yxati bilan bog'laydigan playbook elementi |
| Playbook | play'lar ro'yxati yozilgan YAML fayl |
| Handler | faqat `changed` bo'lgan task `notify` qilganda, play oxirida bir marta ishlaydigan task |
| Privilege escalation (`become`) | task'ni boshqa foydalanuvchi (odatda root) nomidan `sudo` orqali bajarish |
| Precedence | bir xil nomli o'zgaruvchilardan qaysi manba yutishini belgilaydigan tartib |
| Extra vars | `-e` bilan berilgan, har doim yutadigan o'zgaruvchilar |
| Facts | `setup` moduli nishondan yig'adigan ma'lumot (`ansible_facts`) |
| Jinja2 | template tili: `{{ }}` ifoda, `{% %}` boshqaruv, `|` filtr |
| `register` | task natijasini o'zgaruvchiga saqlash |
| Check mode | hech narsani o'zgartirmaydigan dry-run (`--check`) |
| Pipelining | modulni faylga ko'chirmasdan SSH kanali orqali uzatish |
| `PLAY RECAP` | har host uchun `ok`/`changed`/`failed` hisoblagichlari |

## Tuzoqlar

- `command`/`shell` bilan `apt-get install`, `useradd`, `echo >> file` yozish. Bu Ansible ichidagi bash: idempotency, check mode va diff yo'qoladi. Avval modul qidiring (`ansible-doc -l`).
- `mode: 644` qo'shtirnoqsiz. Har doim `"0644"`.
- `port: {{ app_port }}` qo'shtirnoqsiz: YAML xatosi. `when:` ichida esa `{{ }}` yozilmaydi.
- `src` control node'dagi yo'l, `dest` nishondagi. Nishonda yotgan faylni `copy` ning `src` iga yozish "file not found" beradi.
- `state: latest` ni paketlar uchun odat qilish: har ishga tushirishda versiya o'zgarishi mumkin, playbook takrorlanuvchan bo'lmay qoladi. `present` yoki aniq versiya.
- Yo'qolgan handler (5-bo'lim): play yarmida uzilsa servis eski config bilan qoladi.
- `user` modulida `groups` ni `append: true` siz berish: foydalanuvchi ro'yxatda yo'q boshqa barcha qo'shimcha guruhlardan chiqariladi (masalan `sudo` dan).
- Bir xil o'zgaruvchini bir nechta joyda aniqlash va "nima uchun qiymat o'zgarmayapti" deb izlash. `ansible-inventory --host <name>` va `debug` bilan tekshiring.
- `--check` toza o'tdi, demak haqiqiy ishga tushirish ham o'tadi deb ishonish. Check mode `command` task'larini va zanjirli bog'liqliklarni ko'rmaydi.
- `ignore_errors: true` bilan xatoni yashirish. To'g'ri yo'l `failed_when` bilan aniq mezon.
- Buyruqni loyiha papkasidan tashqarida ishga tushirish: `ansible.cfg` topilmaydi, inventory va kalit "yo'qoladi" (3-bo'lim).
- Arxitekturani (`amd64`) yoki IP'ni playbook'ga qattiq yozish: ikkinchi mashinada sinadi. Arxitektura fact'dan, IP lokal inventory'dan.
- `become: true` bilan `hosts: localhost`: o'z ish mashinangizni root sifatida o'zgartirasiz. Bu kursda nishon faqat VM.
- IP yozilgan inventory yoki `~/.ssh/iac_lab` ni commit qilish. Commit'dan oldin `git status` ni o'qing.

## Manbalar

- https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html – o'rnatish (pipx), control node talablari
- https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html – inventory, INI va YAML, guruh o'zgaruvchilari
- https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html – host pattern'lari
- https://docs.ansible.com/ansible/latest/reference_appendices/config.html – ansible.cfg sozlamalari va qidiruv tartibi
- https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html – ad-hoc buyruqlar
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html – playbook, play, task
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html – handler'lar
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html – `become`
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html – o'zgaruvchilar va to'liq precedence ro'yxati
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_vars_facts.html – facts
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html – Jinja2 template'lar
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html – `loop`, `loop_control`
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html – `when`
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html – check mode va diff
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html – `changed_when`, `failed_when`
- https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html – `ansible.builtin` modullari
- https://jinja.palletsprojects.com/en/stable/templates/ – Jinja2 template sintaksisi
- Jeff Geerling, "Ansible for DevOps", 1–5 boblar

---

## Birga bajaramiz

Bitta yaxlit misol: `db1` da systemd journal'ining (linux 11: systemd'ning log ombori) diskdagi hajmini cheklaymiz. Buning uchun `/etc/systemd/journald.conf.d/` papkasiga drop-in fayl qo'yiladi va `systemd-journald` qayta ishga tushiriladi. Bu holat vazifalarda yo'q, lekin ulardagi deyarli barcha mexanizmlarni ko'rsatadi. Hammasi ish papkasida, host'da bajariladi; `ansible.cfg` va inventory tayyor deb hisoblanadi (A guruhdan keyin).

1. Aloqani tekshiring:

```
$ ansible db1 -m ansible.builtin.ping
db1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

`pong` kelmasa keyingi qadamlarga o'tmang: avval SSH va inventory'ni tuzating.

2. Template yozing, `templates/journald-lab.conf.j2`:

```
# Managed by Ansible on {{ ansible_facts['hostname'] }}
[Journal]
SystemMaxUse={{ journal_max_use }}
```

Birinchi qator fact'dan, uchinchisi o'zgaruvchidan. Serverda bu faylni ochgan odam uni qo'lda tahrirlash befoyda ekanini birinchi qatordan biladi.

3. Playbook yozing, `journald.yml`:

```
- name: Limit journal size on db hosts
  hosts: db
  become: true
  vars:
    journal_max_use: 100M
  tasks:
    - name: Ensure drop-in directory exists
      ansible.builtin.file:
        path: /etc/systemd/journald.conf.d
        state: directory
        mode: "0755"

    - name: Deploy journald limits
      ansible.builtin.template:
        src: journald-lab.conf.j2
        dest: /etc/systemd/journald.conf.d/50-lab.conf
        mode: "0644"
      notify: Restart journald

  handlers:
    - name: Restart journald
      ansible.builtin.systemd_service:
        name: systemd-journald
        state: restarted
```

`src` da papka yozilmagan: `template` moduli faylni playbook yonidagi `templates/` dan o'zi qidiradi. `become: true` kerak, chunki `/etc` ga faqat root yoza oladi.

4. Sintaksisni tekshiring va nima bajarilishini ko'ring (nishonga ulanmaydi):

```
$ ansible-playbook journald.yml --syntax-check

playbook: journald.yml
$ ansible-playbook journald.yml --list-tasks
```

5. Birinchi haqiqiy ishga tushirish:

```
$ ansible-playbook journald.yml

PLAY [Limit journal size on db hosts] ******************************************

TASK [Gathering Facts] *********************************************************
ok: [db1]

TASK [Ensure drop-in directory exists] *****************************************
changed: [db1]

TASK [Deploy journald limits] **************************************************
changed: [db1]

RUNNING HANDLER [Restart journald] *********************************************
changed: [db1]

PLAY RECAP *********************************************************************
db1                        : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Papka yaratildi, fayl yozildi, fayl task'i `changed` bo'lgani uchun handler xabar oldi va barcha task'lardan keyin ishladi. Handler ham hisobga kiradi: `ok=4`, `changed=3`. Sizda papka allaqachon mavjud bo'lsa ikkinchi task `ok` chiqadi va sonlar bittaga kam bo'ladi.

6. Ikkinchi ishga tushirish, idempotency:

```
$ ansible-playbook journald.yml
...
TASK [Ensure drop-in directory exists] *****************************************
ok: [db1]

TASK [Deploy journald limits] **************************************************
ok: [db1]

PLAY RECAP *********************************************************************
db1                        : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Modullar holatni tekshirdi, hammasi joyida. `RUNNING HANDLER` qatori yo'q: hech kim `notify` qilmadi, journald bekorga qayta ishga tushmadi. `ok=3`, chunki handler bajarilmadi.

7. O'zgarishni avval ko'rish. Qiymatni `-e` bilan vaqtincha almashtirib, check mode va diff:

```
$ ansible-playbook journald.yml -e journal_max_use=200M --check --diff
...
TASK [Deploy journald limits] **************************************************
--- before: /etc/systemd/journald.conf.d/50-lab.conf
+++ after: <control node'dagi vaqtinchalik yo'l>/journald-lab.conf.j2
@@ -1,3 +1,3 @@
 # Managed by Ansible on db1
 [Journal]
-SystemMaxUse=100M
+SystemMaxUse=200M

changed: [db1]
```

`-e` play `vars:` dagi `100M` ni bosib o'tdi (extra vars har doim yutadi). `---`/`+++` qatorlari eski va yangi mazmun manbai, `-` bilan boshlangan qator o'chadi, `+` bilan boshlangani qo'shiladi. `changed` deyilgan, lekin bu check mode: handler ham chiqishda ko'rinadi, ammo u ham hech narsani qayta ishga tushirmaydi.

8. Serverda hech narsa o'zgarmaganini isbotlang va natijani tekshiring:

```
$ multipass exec db1 -- cat /etc/systemd/journald.conf.d/50-lab.conf
# Managed by Ansible on db1
[Journal]
SystemMaxUse=100M
$ multipass exec db1 -- systemctl is-active systemd-journald
active
```

9. Drift. VM'da faylni qo'lda buzing (`multipass exec db1 -- sudo sed -i 's/100M/1G/' /etc/systemd/journald.conf.d/50-lab.conf`), keyin `ansible-playbook journald.yml --check --diff` ni ishga tushiring: diff `-SystemMaxUse=1G` va `+SystemMaxUse=100M` ni ko'rsatadi, ya'ni server koddan uzoqlashgan. `--check` siz ishga tushirsangiz fayl tiklanadi, handler yana bir marta ishlaydi, keyingi ishga tushirish yana `changed=0`.

Shu 9 qadamda ko'rganingiz: `ping` butun SSH + Python zanjirini tekshiradi (1 va 4-bo'limlar), `hosts: db` inventory guruhidan olinadi (2-bo'lim), play, task, `become` va handler birga ishlaydi (5-bo'lim), `-e` play `vars:` dan ustun (6-bo'lim), template fact va o'zgaruvchini control node'da render qiladi (7 va 8-bo'limlar), ikkinchi ishga tushirish `changed=0`, check mode va diff o'zgarishni ham, drift'ni ham oldindan ko'rsatadi (9-bo'lim).

---

## Vazifalar

Ish papkasi: `iac/02-ansible-basics/` (`make new m=iac n=02 name=ansible-basics` bilan host'da yarating). Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi (`PLAY RECAP`, xato matni) va o'z so'zingiz bilan izoh; README'da IP o'rniga `<web1-IP>` yozing. `ansible.cfg`, playbook va template fayllari shu papkada saqlanadi, inventory va `lab-init.yaml` esa "Laboratoriya" bo'limidagi tartibda (haqiqiy fayl lokal, repoga `.example`). Barcha buyruqlar host'dan, barcha playbook'lar faqat Multipass VM'larga qarshi ishlaydi. Qaysi mashinada (Zorin yoki macOS) bajarganingizni README boshida yozing.

### A. O'rnatish va inventory

1. **Install and version.** Ansible'ni host'ga "Laboratoriya" bo'limi bo'yicha o'rnating (Zorin'da `pipx`, macOS'da Homebrew yoki `pipx`). `ansible --version` chiqishidan yozing: `ansible-core` versiyasi, ishlatilayotgan config fayl, Python versiyasi. `ansible` paketi va `ansible-core` farqini izohlang. `ansible-galaxy collection list` bilan nechta collection birga kelganini ko'ring. Yo'nalish: Laboratoriya, "Ansible'ni o'rnatish"; 1-bo'lim, "Paket tarkibi va FQCN".

2. **INI inventory.** `inventory.ini` yozing: `web` guruhida `web1`, `db` guruhida `db1`, ikkalasini birlashtiruvchi `app` ota guruh, `ansible_user` barcha uchun. `ansible-inventory -i inventory.ini --graph` va `--list` chiqishini o'qing. `all` va `ungrouped` qayerdan paydo bo'ldi? Haqiqiy IP'li fayl lokal qoladi, repoga `inventory.ini.example` tushadi. Yo'nalish: 2-bo'lim, "Bu nima" va "Mexanizm: guruhlar va o'zgaruvchilar qanday yig'iladi".

3. **YAML inventory.** Xuddi shu inventory'ni `inventory.yml` ga o'tkazing (repoga `inventory.yml.example`). Ikkalasining `--list` chiqishi bir xil ekanini isbotlang (masalan `diff` bilan). INI'da host qatoriga `http_port=8080`, `[web:vars]` ga ham `http_port=8080` yozib, `--list` da tiplar farqini ko'rsating. Yo'nalish: 2-bo'lim, "Tuzoq: INI formatida tiplar".

4. **ansible.cfg.** Loyiha papkasida `ansible.cfg` yarating: inventory yo'li, `remote_user`, kalit fayli. Endi `-i` flag'isiz ishlashini tekshiring. `ansible-config dump --only-changed` chiqishini yozing. Boshqa papkadan ishga tushirsangiz nima bo'ladi va nima uchun? Yo'nalish: 3-bo'lim, "Bu nima va qayerdan o'qiladi".

### B. Ad-hoc va modullar

5. **Ping module.** `ansible all -m ansible.builtin.ping`. Bu modul aynan nimani tekshiradi? Uch xil buzing va xatolarni o'qing: noto'g'ri `ansible_user`, noto'g'ri kalit fayli, `multipass stop db1`. `UNREACHABLE` va `FAILED` farqi nima? Oxirida `multipass start db1` (IP o'zgargan bo'lsa lokal inventory'ni yangilang). Yo'nalish: 1-bo'lim, "Mexanizm: bitta task bajarilganda nima bo'ladi"; 4-bo'lim, "Bu nima".

6. **Ad-hoc idempotency.** `ansible web -a "whoami"` ni `--become` bilan va usiz ishga tushiring. `htop` ni `apt` moduli bilan (`--become`) ikki marta o'rnating: birinchi va ikkinchi natija rangi va `changed` qiymatini yozing. Keyin `ansible web -a "touch /tmp/marker"` ni ikki marta ishga tushiring. Nima uchun modul ikkinchi safar `changed: false`, buyruq esa har safar `CHANGED`? Yo'nalish: 4-bo'lim, "Flag'lar" va "Mexanizm: modul va buyruq farqi".

7. **Facts.** `setup` moduli bilan `web1` dan oling: distributiv va versiyasi, umumiy xotira, asosiy IPv4 manzil, vCPU soni, arxitektura. `filter` parametrini ishlating. To'liq chiqish necha qator? Fact yig'ish qancha vaqt oladi (`time` bilan o'lchang)? Yo'nalish: 7-bo'lim, "Bu nima va mexanizm".

### C. Playbook

8. **First playbook.** `web.yml` yozing: `web` guruhida nginx o'rnatilgan, ishlab turgan va `enabled`. Ikki marta ishga tushiring, ikkala `PLAY RECAP` ni yozing. Host'dan `curl http://<web1-IP>` bilan tekshiring. `--syntax-check` va `--list-tasks` ni sinang. Yo'nalish: 5-bo'lim, "Bu nima" va "Misol: chiqishni o'qish".

9. **Check and diff.** Playbook'ga `copy` moduli bilan (`content` parametri) `/var/www/html/index.html` ni boshqaradigan task qo'shing. Avval `--check --diff` bilan ishga tushiring: nima ko'rsatdi, serverda nimadir o'zgardimi? Keyin haqiqiy ishga tushiring. Faylni VM'da qo'lda o'zgartirib (drift), yana `--check --diff` qiling. Yo'nalish: 9-bo'lim, "Check mode va diff".

10. **Jinja2 template.** `templates/site.conf.j2` yozing: `listen` porti o'zgaruvchidan, `server_name` fact'dan, `locations` ro'yxati ustida `{% for %}`, kamida bitta `default` filtri. `template` moduli bilan joylang. Render natijasini VM'da o'qib tekshiring. Yo'nalish: 8-bo'lim, "Jinja2 template".

11. **Handler.** Template task'iga `notify` bilan nginx reload handler'ini ulang. Isbotlang: (a) template o'zgarmasa handler ishlamaydi; (b) ikkita task bitta handler'ga xabar bersa u bir marta ishlaydi; (c) handler barcha task'lardan keyin ishlaydi. Portni o'zgartirib, `curl` bilan yangi portda javob berishini tekshiring. Yo'nalish: 5-bo'lim, "Handler (tanishuv)".

12. **Lost handler.** Template task'idan keyin ataylab xato beradigan task qo'ying (`ansible.builtin.command: /bin/false`). Portni o'zgartirib ishga tushiring: handler ishladimi? Xato task'ni olib tashlab qayta ishga tushiring: endi-chi? nginx qaysi portda tinglayapti (VM ichida `ss -tlnp`, masalan `multipass exec web1 -- sudo ss -tlnp`), diskdagi config nima deydi? Ikki xil yechimni qo'llab ko'ring va farqini yozing. Yo'nalish: 5-bo'lim, "Tuzoq: yo'qolgan handler".

13. **Variable precedence.** `http_port` ni to'rt joyda har xil qiymat bilan aniqlang: inventory'da `all` guruh darajasida, `web` guruh darajasida, play `vars:` da va `-e` bilan. `debug` bilan qaysi biri yutganini ko'rsating, keyin eng ustunini bittalab olib tashlab tartibni tasdiqlang. Natijani jadval qilib yozing. Yo'nalish: 6-bo'lim, "Bu nima" va "Misol".

14. **Loops and conditionals.** O'zgaruvchida foydalanuvchilar ro'yxatini (dict'lar: `name`, `groups`, `state`) aniqlang va `loop` bilan yarating, `loop_control.label` ishlating. Bitta foydalanuvchini `state: absent` qilib o'chiring. `when` bilan faqat `db` guruhidagi hostlarda bajariladigan task qo'shing (`group_names` o'zgaruvchisini `ansible-doc` yoki hujjatdan toping). Yo'nalish: 8-bo'lim, "Loop" va "when".

15. **groups without append.** `ansible-doc ansible.builtin.user` dan `append` ning standart qiymatini toping. VM'da qo'lda `sudo` guruhiga kiritilgan sinov foydalanuvchisini yarating. Keyin `user` moduli bilan unga `groups: adm` ni `append` siz bering. `id <user>` oldin va keyin nima ko'rsatadi? `--check --diff` buni oldindan ko'rsatarmidi? Yo'nalish: "Tuzoqlar" bo'limi; 4-bo'lim, "Flag'lar" (`ansible-doc`).

16. **changed_when and creates.** Uchta `command` task yozing: (a) faqat o'qiydigan (`nginx -v`), `register` + `changed_when: false`; (b) bir marta bajarilishi kerak bo'lgan, `creates` bilan; (c) chiqishiga qarab `changed` aniqlanadigan. Har biri ikkinchi ishga tushirishda `changed` bermasligini ko'rsating. Ularni `--check` da ishga tushirsangiz nima bo'ladi? Yo'nalish: 9-bo'lim, "`command` va `shell` ni idempotent qilish" va "Check mode va diff".

17. **failed_when.** `/etc/nginx/nginx.conf` da `server_tokens off` qatori bor yoki yo'qligini `grep` bilan tekshiradigan task yozing. `grep` topmaganida task `FAILED` bo'lmasin, lekin fayl mavjud bo'lmasa (`rc == 2`) bo'lsin. Natijaga qarab keyingi task'da `debug` xabar chiqaring. `grep` ning exit code'larini VM'da `man grep` dan toping. Yo'nalish: 9-bo'lim, "`command` va `shell` ni idempotent qilish".

18. **Undefined variable.** Template'da aniqlanmagan o'zgaruvchini ishlating va xato matnini to'liq o'qing: qaysi fayl, qaysi qator ko'rsatilgan? Uni ikki usulda tuzating: `default` filtri va play boshida `ansible.builtin.assert` bilan majburiy o'zgaruvchilarni tekshirish. Qaysi holatda qaysi biri to'g'ri? Yo'nalish: 6-bo'lim, "YAML va `{{ }}` tuzog'i, register, default".

### D. Kichik loyiha

19. **Bash to playbook.** 1-darsdagi `provision_v2.sh` ning yakuniy holatini `provision.yml` playbook'i sifatida qayta yozing (`command`/`shell` ishlatmasdan). Yangi VM'da (uni ham `lab-init.yaml` bilan yarating va lokal inventory'ga qo'shing) uch marta ishga tushiring: birinchi `changed>0`, keyingilari `changed=0`. 1-dars 10-vazifadagi drift'larni qayta yarating va `--check --diff` nimani ko'rsatishini, haqiqiy ishga tushirish nimani tuzatishini yozing. 1-darsdagi "Pain summary" jadvaliga Ansible ustunini qo'shing. Ansible ham yecha olmagan muammo qaysi? Ikkinchi mashinada ham ishlashi uchun playbook'da IP va arxitektura qattiq yozilmagan bo'lsin. Yo'nalish: 4-bo'lim, "Ko'p ishlatiladigan `ansible.builtin` modullari"; 9-bo'lim; "Birga bajaramiz".

### Topshirish

Tayyor bo'lgach:
1. `iac/02-ansible-basics/README.md` da 19 ta vazifaning har biri `## N. Title` sarlavhasi ostida, qaysi mashinada bajarilgani yozilgan.
2. Ish papkasida: `ansible.cfg`, `inventory.ini.example`, `inventory.yml.example`, `lab-init.yaml.example`, `web.yml`, `provision.yml`, `templates/site.conf.j2` va boshqa vazifalar uchun yozgan playbook'laringiz.
3. `make check` toza (host'da).
4. Barcha playbook'lar `ansible-playbook --syntax-check` dan o'tadi va ikkinchi ishga tushirishda `changed=0` beradi (12-vazifadagi ataylab buzilgan variant bundan mustasno, uni alohida faylda saqlang).
5. Repoda private kalit, IP manzil va parol yo'q: `inventory.ini`, `inventory.yml` va `lab-init.yaml` `.gitignore` da, `git status` da ko'rinmaydi.
6. VM'lar: 3-darsga darhol o'tmasangiz `multipass delete --purge web1 db1` (19-vazifa VM'si bilan birga), `multipass list` da `lab` joyida.
7. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Ansible bitta task'ni nishonda qanday bajaradi? Nishonda nima o'rnatilgan bo'lishi kerak va nima uchun?
- Control node va managed node farqi nima? Sizning laboratoriyangizda qaysi biri qayerda?
- `ok` va `changed` farqi nima va modul buni qanday aniqlaydi?
- `command` moduli nima uchun har safar `changed` beradi va buni qanday uch usulda tuzatish mumkin?
- Handler qachon ishlaydi? Qanday holatda u "yo'qoladi" va oqibati nima?
- Bir xil o'zgaruvchi inventory guruhida, play `vars` da va `-e` da bo'lsa qaysi biri yutadi? Role `defaults` nima uchun eng pastda?
- `ansible.cfg` qaysi tartibda qidiriladi va boshqa papkadan ishga tushirilgan buyruq nima uchun boshqacha ishlaydi?
- Facts nima va ular qayerdan keladi? Arxitekturani playbook'ga nima uchun qattiq yozib bo'lmaydi?
- `port: {{ http_port }}` nima uchun xato, `when:` da esa `{{ }}` nima uchun yozilmaydi?
- `--check` nimani ko'rsata olmaydi?
- `copy` va `template` da `src` qayerdagi fayl? Template qayerda render qilinadi?
- `user` modulida `append: true` yozilmasa nima bo'ladi?
- Inventory'dagi IP'lar nima uchun commit qilinmaydi va ikkinchi mashinada laboratoriya qanday tiklanadi?
