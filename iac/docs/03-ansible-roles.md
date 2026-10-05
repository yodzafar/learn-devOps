# 3-dars: Ansible role'lar, Vault va app server

Maqsad: bitta fayldagi playbook'dan qayta ishlatiladigan, tekshiriladigan loyiha tuzilishiga o'tish: role'lar, `group_vars`/`host_vars`, collection'lar va `requirements.yml`, Ansible Vault, tag'lar, `ansible-lint`. Dynamic inventory va Molecule bilan tanishuv darajasida. Dars oxirida cloud modulida qo'lda sozlagan app serveringizni (Docker, foydalanuvchilar, firewall, reverse proxy, compose stack) bo'sh VM'dan bitta buyruq bilan tayyorlaydigan role'lar to'plamini yozasiz. 5-darsda aynan shu role'lar Terraform yaratgan EC2 ustida ishlaydi.

Taxminiy vaqt: 4 kun (siz uchun): 1.5 kun role, o'zgaruvchilar va Vault, 0.5 kun lint va tag'lar, 2 kun app server loyihasi. Diqqatni quyidagilarga qarating: `defaults` va `vars` farqi, secret qayerlarda ochiq holda paydo bo'ladi (log, nishondagi fayl, diff), firewall va SSH sozlamalarini o'zgartirishda o'zingizni tashqarida qoldirmaslik, Docker va UFW o'zaro ta'siri.

## Laboratoriya

2-darsdagi muhit: control node ish mashinasi, nishon Multipass VM. Bu darsda bitta VM yetarli (`app1`), lekin u ko'p marta o'chirib qayta yaratiladi, shuning uchun yaratishni bir qatorli buyruq yoki kichik skriptga oling:

```
multipass launch 24.04 --name app1 --cpus 2 --memory 2G --disk 10G --cloud-init lab-init.yaml
multipass list
```

Qo'shimcha asboblar (foydalanuvchi darajasida, hujjat: https://docs.ansible.com/projects/lint/installing/):

```
pipx install ansible-lint
ansible-lint --version
```

Firewall, SSH sozlamalari va Docker faqat VM ichida o'zgartiriladi. SSH'ni buzib qo'ysangiz VM'ga `multipass shell app1` orqali kirish mumkin (u SSH kalitingizga bog'liq emas), eng yomon holatda VM'ni o'chirib qayta yarating. Dynamic inventory vazifasi (15) AWS'ga faqat o'qish so'rovlari yuboradi, resurs yaratmaydi.

Tozalash: `multipass delete --purge app1`, `multipass list` bo'sh.

---

## 1. Role

Role bu bitta vazifaga oid task, handler, template, fayl va o'zgaruvchilarning standart papka tuzilishidagi to'plami. Ansible fayllarni nomiga qarab o'zi topadi:

```
roles/
  nginx/
    tasks/main.yml        # task list, entry point
    handlers/main.yml     # handlers
    templates/            # *.j2, used by template module without path
    files/                # static files, used by copy module without path
    defaults/main.yml     # low-priority variables (the role's public API)
    vars/main.yml         # high-priority variables (internal constants)
    meta/main.yml         # metadata, dependencies
```

Skelet: `ansible-galaxy role init roles/nginx`. Kerak bo'lmagan papkalarni o'chiring, bo'sh `main.yml` lar shovqin.

### defaults va vars
Ikkalasi ham o'zgaruvchi, farq precedence'da (2-dars, 6-bo'lim):
- `defaults/main.yml` eng past daraja. Bu role'ning "parametrlari": foydalanuvchi `group_vars` yoki play `vars` orqali ustidan yozadi.
- `vars/main.yml` yuqori daraja, inventory o'zgaruvchilaridan ustun. Bu role ichki konstantalari (paket nomlari, yo'llar), ularni tashqaridan faqat `-e` yoki role parametri bilan o'zgartirish mumkin.

Role o'zgaruvchilari global nomlar fazosida yashaydi, shuning uchun role nomi bilan prefiks qo'yiladi: `nginx_http_port`, `docker_users`. `port` degan nom ikki role'da to'qnashadi.

### Role'ni ishlatish

```
- name: Configure app servers
  hosts: app
  become: true
  roles:
    - base
    - role: nginx
      vars:
        nginx_http_port: 8080
```

Task ichidan: `ansible.builtin.import_role` (statik, playbook o'qilayotganda joylanadi) yoki `ansible.builtin.include_role` (dinamik, bajarilish paytida; `when` va `loop` butun role'ga qo'llanadi).

Play ichidagi bajarilish tartibi: `pre_tasks`, `roles`, `tasks`, `post_tasks`. Handler'lar uch joyda ishlaydi: `pre_tasks` oxirida, `roles` va `tasks` tugagach, `post_tasks` oxirida. Handler nomlari butun play uchun umumiy: bir role boshqa role handler'iga `notify` qila oladi, shuning uchun nomlar noyob bo'lsin (`Reload nginx`, shunchaki `reload` emas).

`meta/main.yml` dagi `dependencies` ro'yxati role'dan oldin avtomatik bajariladigan role'larni belgilaydi. Yashirin bog'liqlik o'qishni qiyinlashtiradi; kichik loyihada tartibni play'ning `roles:` ro'yxatida ochiq yozish afzal.

## 2. Loyiha tuzilishi, group_vars va host_vars

```
ansible.cfg
requirements.yml
site.yml
inventory/
  hosts.yml
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

- `group_vars/<group>.yml` yoki `group_vars/<group>/` papkasi (ichidagi barcha fayllar o'qiladi) shu guruh hostlariga qo'llanadi. `host_vars/<host>` bitta hostga.
- Bu papkalar inventory fayli yonida yoki playbook yonida bo'lishi mumkin. Bitta joyni tanlang.
- Host bir nechta guruhda bo'lsa: `all` eng past, ota guruh boladan past, `host_vars` hammasidan ustun.
- Yakuniy qiymatlarni ko'rish: `ansible-inventory --host app1`.

Muhitlar (dev, prod) odatda alohida inventory papkalari bilan ajratiladi: `inventory/dev/`, `inventory/prod/`, har birida o'z `group_vars`. Role'lar umumiy, faqat qiymatlar farq qiladi.

## 3. Galaxy va collection'lar

- **Collection**: modullar, plugin'lar va role'lar paketi, nomi `namespace.name` (`community.docker`). Modul FQCN'ining birinchi ikki qismi shu.
- **Ansible Galaxy** (https://galaxy.ansible.com): collection va role'lar ombori. `ansible-galaxy` CLI undan yoki git'dan o'rnatadi.

`ansible` paketi bilan ko'p collection birga keladi (`ansible-galaxy collection list`), lekin loyiha bog'liqliklarini aniq yozish takrorlanuvchanlik uchun kerak, xuddi `package.json` kabi:

```
# requirements.yml
collections:
  - name: community.docker
    version: ">=5.0.0,<6.0.0"
  - name: community.general
  - name: ansible.posix
```

```
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list community.docker
```

Versiya oralig'ini Galaxy sahifasidagi joriy relizga qarab o'zingiz belgilang, yuqoridagi raqamlar faqat sintaksis namunasi. Role'lar ham shu faylda `roles:` kaliti ostida yoziladi va `ansible-galaxy role install -r requirements.yml` bilan o'rnatiladi.

Galaxy'dagi role bu begona kod, u serveringizda `root` sifatida ishlaydi. Ishlatishdan oldin `tasks/` ni o'qing, versiyani qat'iy belgilang. Tayyor role ko'pincha siz xohlagandan ko'p narsa qiladi; kichik vazifa uchun o'z role'ingiz tushunarliroq.

## 4. Ansible Vault

Vault fayl yoki alohida qiymatni parol bilan shifrlaydi (AES-256), shifrlangan matn repoda saqlanadi.

```
ansible-vault create inventory/group_vars/all/vault.yml
ansible-vault edit inventory/group_vars/all/vault.yml
ansible-vault view inventory/group_vars/all/vault.yml
ansible-vault encrypt_string 's3cr3t' --name 'vault_db_password'
ansible-vault rekey inventory/group_vars/all/vault.yml
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file ~/.config/iac-lab/vault-pass
```

Tavsiya etilgan pattern: shifrlangan `vault.yml` da `vault_` prefiksli o'zgaruvchilar, ochiq `vars.yml` da ularga havola:

```
# vars.yml (plain)
app_db_password: "{{ vault_app_db_password }}"
# vault.yml (encrypted)
vault_app_db_password: "..."
```

Shunda `grep` bilan o'zgaruvchi qayerda aniqlanganini topish mumkin, shifrlangan faylni ochmasdan.

Vault faqat repodagi faylni himoya qiladi. Secret ochiq holda paydo bo'ladigan boshqa joylar:
- **Chiqish va log**: `-v` rejimida task argumentlari, `debug`, `--diff` (template ichidagi parol diff'da ko'rinadi). Himoya: task'da `no_log: true`, template task'ida `diff: false`.
- **Nishondagi fayl**: `.env` yoki config serverda ochiq matn. Himoya: `mode: "0600"`, to'g'ri `owner`.
- **Vault paroli**: parol fayli repodan tashqarida, CI'da secret sifatida.

**Tuzoq: `no_log: true` xatoni ham yashiradi.** Task muvaffaqiyatsiz bo'lsa sababini ko'rmaysiz. Debug paytida vaqtincha o'chirib, sinov qiymati bilan ishlating.

## 5. Tag'lar

```
- name: Deploy compose file
  ansible.builtin.template:
    src: compose.yaml.j2
    dest: /opt/app/compose.yaml
  tags: [app, config]
```

- `--tags app` faqat shu tegli task'lar, `--skip-tags docker` ulardan tashqari hammasi, `--list-tags` mavjud teglar.
- Role'ga teg berilsa (`- role: docker` va `tags: docker`) uning barcha task'lari meros oladi.
- Maxsus teglar: `always` (har doim ishlaydi, `--skip-tags always` bundan mustasno), `never` (faqat aniq so'ralganda).

**Tuzoq: `--tags` bilan qisman ishga tushirish kerakli oldingi qadamlarni tashlab ketadi** (masalan o'zgaruvchi `set_fact` qiladigan yoki paket o'rnatadigan task). Teglar tezlik uchun, to'liq ishga tushirish esa har doim to'g'ri ishlashi kerak.

## 6. Dynamic inventory

Cloud'da serverlar paydo bo'lib yo'qoladi, statik IP ro'yxati tez eskiradi. Inventory plugin ro'yxatni har ishga tushirishda API'dan oladi. AWS uchun `amazon.aws.aws_ec2`:

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

- `filters` EC2 API filtrlari (`aws ec2 describe-instances --filters` dagi nomlar bilan bir xil).
- `keyed_groups` teg qiymatidan guruh yasaydi: `Role=app` tegli instans `role_app` guruhiga tushadi.
- Plugin control node'da `boto3` va `botocore` talab qiladi (`pipx inject ansible boto3 botocore`) va AWS CLI bilan bir xil credential zanjirini ishlatadi.
- Tekshirish: `ansible-inventory -i inventory/lab.aws_ec2.yml --graph`.

Bu Terraform bilan tabiiy bog'lanish nuqtasi: Terraform resursga teg qo'yadi, Ansible shu teg bo'yicha hostni topadi (5-dars).

## 7. ansible-lint va Molecule

### ansible-lint
Playbook va role'larni yaxshi amaliyotlar bo'yicha tekshiradi: `ansible-lint` (joriy papka) yoki `ansible-lint site.yml`. Qoidalar profillarga guruhlangan, yengilidan qat'iysiga: `min`, `basic`, `moderate`, `safety`, `shared`, `production`. Sozlama `.ansible-lint` faylida:

```
profile: production
exclude_paths:
  - collections/
```

Ko'p uchraydigan qoidalar: `fqcn` (to'liq modul nomi), `name[missing]` (nomsiz task), `no-changed-when` (`command` da `changed_when` yo'q), `risky-file-permissions` (`mode` berilmagan), `yaml[...]` (formatlash). Bitta qatorni asosli ravishda o'tkazib yuborish: qator oxirida `# noqa: <rule-id>`.

### Molecule
Role'ni vaqtinchalik muhitda sinash freymvorki. `molecule test` standart ketma-ketligining mazmuni: vaqtinchalik instans yaratish (odatda konteyner), role'ni qo'llash (`converge`), ikkinchi marta qo'llab `changed=0` ekanini tekshirish (`idempotence`), tekshiruv playbook'ini ishlatish (`verify`), instansni o'chirish (`destroy`). Bu siz qo'lda qiladigan "toza VM, ikki marta ishga tushirish, tekshirish" siklining avtomatlashtirilgani. Bu darsda faqat tanishuv; role'lar jamoada qayta ishlatila boshlaganda CI'ga qo'shiladi.

## 8. App server loyihasi

Cloud modulidagi app serverni role'larga ajratamiz. Har role bitta mas'uliyat:

| Role | Mas'uliyat | Asosiy modullar |
|------|------------|-----------------|
| `base` | bazaviy paketlar, `deploy` foydalanuvchisi, SSH kalit, sudoers, sshd sozlamasi | `apt`, `user`, `ansible.posix.authorized_key`, `template` + `validate` |
| `firewall` | UFW: standart deny, 22/80/443 ochiq | `community.general.ufw` |
| `docker` | Docker Engine rasmiy repodan, compose plugin, servis | `ansible.builtin.deb822_repository`, `apt`, `service`, `user` |
| `reverse_proxy` | nginx, ilovaga `proxy_pass` | `apt`, `template`, handler |
| `app` | `/opt/app`, `compose.yaml`, `.env` (Vault'dan), stack'ni ko'tarish | `file`, `template`, `community.docker.docker_compose_v2` |

Har modulning "Requirements" bo'limini hujjatdan o'qing: ba'zilari nishonda qo'shimcha Python paketi yoki CLI plugin talab qiladi (masalan `docker_compose_v2` nishonda Docker Compose plugin'i bo'lishini kutadi).

### O'zingizni tashqarida qoldirmaslik
- **Firewall tartibi**: avval SSH portiga ruxsat, keyin standart siyosat `deny` va UFW'ni yoqish. Teskari tartibda ulanish uziladi va play yarmida qoladi.
- **sshd**: Ubuntu 24.04 da sozlamani `/etc/ssh/sshd_config.d/` ichidagi alohida faylga yozing va joylashdan oldin tekshiring: `validate: "sshd -t -f %s"`. sshd har kalit uchun birinchi uchragan qiymatni oladi, shuning uchun fayl nomi tartibi muhim. Amaldagi qiymat: `sudo sshd -T | grep -i passwordauthentication`.
- **sudoers**: `/etc/sudoers.d/` ga fayl faqat `validate: "visudo -cf %s"` bilan. Buzilgan sudoers `sudo` ni butunlay ishdan chiqaradi.

### Docker va UFW
Docker publish qilingan portlar uchun iptables qoidalarini o'zi yozadi va ular UFW qoidalaridan oldin ishlaydi. `ports: ["8080:80"]` bilan publish qilingan konteyner UFW'da `deny` bo'lsa ham tashqaridan ochiq bo'ladi. Reverse proxy ortidagi ilova uchun to'g'ri yo'l: faqat loopback'ga publish qilish (`127.0.0.1:8080:80`), tashqariga faqat nginx chiqadi. Cloud'da qo'shimcha qatlam security group.

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

## Manbalar

- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html – role'lar
- https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html – namunaviy loyiha tuzilishi
- https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables – `group_vars`, `host_vars`
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
- Jeff Geerling, "Ansible for DevOps", 6–8 boblar

---

## Vazifalar

Ish papkasi: `iac/03-ansible-roles/` (`make new m=iac n=03 name=ansible-roles`). Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Loyiha fayllari (2-bo'limdagi tuzilish) shu papkada. Vault paroli fayli repodan tashqarida saqlanadi. Barcha playbook'lar faqat Multipass VM'ga qarshi ishlaydi.

### A. Role va o'zgaruvchilar

1. **Role skeleton.** `ansible-galaxy role init roles/nginx` bilan skelet yarating. Har papka nima uchun ekanini bir jumla bilan yozing. Kerak bo'lmaganlarini o'chiring va nima uchun o'chirganingizni ayting.

2. **Extract a role.** 2-darsdagi nginx playbook'ini (`web.yml`: o'rnatish, template, handler) `nginx` role'iga ko'chiring. `site.yml` da faqat `hosts`, `become` va `roles` qolsin. Template va handler qaysi papkaga tushdi, `src` yo'li qanday o'zgardi? Natija 2-darsdagi bilan bir xil ekanini tekshiring.

3. **defaults vs vars.** Role'da `nginx_http_port` ni `defaults/main.yml` da aniqlang va `group_vars` dan ustidan yozing: ishladimi? Keyin uni `vars/main.yml` ga ko'chirib takrorlang. Endi qaysi usullar bilan ustidan yozish mumkin? Qoida chiqaring: nima `defaults` ga, nima `vars` ga yoziladi.

4. **group_vars and host_vars.** 2-bo'limdagi papka tuzilishini yarating. Bitta o'zgaruvchini `group_vars/all`, `group_vars/app` va `host_vars/app1` da har xil qiymat bilan aniqlang. `ansible-inventory --host app1` nima ko'rsatadi? Tartibni bittalab o'chirib tasdiqlang.

5. **Execution order.** Bitta play'da `pre_tasks`, `roles`, `tasks`, `post_tasks` ning har biriga `debug` qo'ying va ulardan biri handler'ga `notify` qilsin (`changed_when: true` bilan). Bajarilish tartibini va handler aynan qayerda ishlaganini yozing.

### B. Collection'lar

6. **requirements.yml.** Loyihaga kerakli collection'larni (`community.docker`, `community.general`, `ansible.posix`) versiya oralig'i bilan `requirements.yml` ga yozing va o'rnating. `ansible-galaxy collection list` da qaysi yo'lda qaysi versiya turganini ko'rsating. Bir xil collection ikki joyda (pipx bilan kelgan va siz o'rnatgan) bo'lsa qaysi biri ishlatiladi?

7. **Galaxy role review.** Galaxy'dan mashhur Docker o'rnatish role'ini toping va GitHub'dagi manbasini o'qing (o'rnatmasdan): `defaults` da nechta parametr, `tasks` qaysi OS oilalarini qo'llaydi, `root` sifatida nimalarni qiladi. Uni ishlatish va o'zingiz yozish orasidagi tanlovni 3–4 jumla bilan asoslang.

### C. Vault

8. **Vault file.** `vault.yml` yarating (`vault_app_db_password`), `vars.yml` da unga havola qiling, playbook'da `debug` bilan (vaqtincha) qiymat o'qilishini tekshiring. `cat vault.yml` va `git diff` nima ko'rsatadi? `--ask-vault-pass` siz ishga tushirib xatoni o'qing.

9. **Secret leaks.** Secret'ni template orqali nishondagi `.env` fayliga yozing. Uch joyda sizib chiqishini ko'rsating va har birini yoping: `--diff` chiqishi, `-v` bilan task natijasi, nishondagi fayl huquqlari. `no_log: true` qo'yilgan task'ni ataylab buzing: xato xabari qanday ko'rinadi?

10. **Vault password file.** Parolni repodan tashqaridagi faylga (mode `0600`) qo'ying va `ansible.cfg` dagi `vault_password_file` sozlamasi orqali ulang. `ansible-vault rekey` bilan parolni almashtiring. `encrypt_string` bilan bitta qiymatni oddiy `vars.yml` ichida shifrlang va fayl darajasidagi shifrlash bilan solishtiring: qaysi biri review uchun qulay?

### D. Tag, lint, inventory

11. **Tags.** Role va task'larga teg qo'ying (`base`, `docker`, `app`, `config`). `--list-tags`, `--tags config`, `--skip-tags docker` natijalarini yozing. `always` tegli bitta task qo'shing. Qisman ishga tushirish noto'g'ri natija beradigan bitta holatni o'z loyihangizdan toping yoki yarating.

12. **ansible-lint.** 2-darsdagi playbook'lar va shu darsdagi role'larni `ansible-lint` bilan `production` profilida tekshiring. Topilgan qoida buzilishlarini turlarga ajratib yozing, har turdan bittasini tuzatishdan oldin va keyin ko'rsating. Yakunda toza o'tsin; `# noqa` ishlatgan bo'lsangiz har birini asoslang.

13. **Lint in CI.** cicd modulidagi bilimingiz bilan `ansible-lint` va `ansible-playbook --syntax-check` ni PR'da ishga tushiradigan workflow yozing. Vault bilan shifrlangan fayllar bor loyihada `--syntax-check` parolsiz ishlaydimi? Tekshirib, yechimni yozing.

14. **Molecule overview.** Molecule hujjatidan o'qib yozing (o'rnatmasdan): `molecule test` qaysi bosqichlardan o'tadi, `converge` va `idempotence` nimani tekshiradi, instans sifatida konteyner ishlatilganda qaysi turdagi role'larni sinash qiyin (ishoralar: systemd, firewall). Siz 21-vazifada qo'lda qiladigan ish bilan solishtiring.

15. **Dynamic inventory.** `aws_ec2` plugin uchun inventory fayli yozing: region, `Project=iac-lab` teg filtri, `Role` tegi bo'yicha `keyed_groups`. `ansible-inventory -i <file> --graph` ni ishga tushiring (akkauntda mos instans bo'lmasa bo'sh natija ham to'g'ri). Fayl nomini `ec2.yml` ga o'zgartirib ko'ring: nima bo'ldi? Plugin qaysi credential'lardan foydalanganini yozing.

### E. App server loyihasi

16. **Base role.** `base` role: bazaviy paketlar; `deploy` foydalanuvchisi, sizning public kalitingiz bilan; `/etc/sudoers.d/deploy` (`validate` bilan); `sshd_config.d` ga parol bilan kirishni o'chiradigan fayl (`validate` va handler bilan). Ataylab sintaktik xato sudoers template'ini joylashga urinib ko'ring: `validate` nima qildi, nishondagi fayl o'zgardimi? `ssh deploy@<IP>` bilan kirishni tekshiring.

17. **Firewall role.** `firewall` role: SSH, 80 va 443 ga ruxsat, kiruvchi standart siyosat `deny`, UFW yoqilgan. Task tartibini asoslang. Ish mashinasidan `nc -zv <IP> 22`, `80` va ochilmagan port (masalan `5432`) bilan tekshiring, VM'da `sudo ufw status verbose`.

18. **Docker role.** `docker` role: Docker Engine va compose plugin'ini rasmiy Docker apt repozitoriysidan o'rnatish (Docker hujjatidagi qadamlarni modullarga o'giring, `command`/`shell` siz), servis `enabled` va `started`, `deploy` foydalanuvchisi `docker` guruhida (`append` ni unutmang). Tekshirish: `deploy` sifatida `docker run --rm hello-world`. `docker` guruhiga a'zolik xavfsizlik nuqtai nazaridan nimaga teng?

19. **App stack role.** `reverse_proxy` va `app` role'lari: `/opt/app` da template'dan `compose.yaml` va Vault'dagi secret bilan `.env` (mode `0600`); stack `community.docker.docker_compose_v2` bilan ko'tariladi; ilova faqat `127.0.0.1` ga publish qilinadi; nginx 80-portda unga `proxy_pass` qiladi. Ilova sifatida docker modulidagi o'z image'ingiz yoki istalgan kichik HTTP image. Ish mashinasidan `curl http://<IP>/` javob bersin. Config o'zgarganda nginx reload, compose fayl o'zgarganda stack yangilanishini ko'rsating.

20. **Docker bypasses UFW.** Compose'da publish'ni vaqtincha `8080:80` ga (barcha interfeyslar) o'zgartiring. UFW'da 8080 ochilmagan. Ish mashinasidan `curl http://<IP>:8080` nima qaytardi? Sababini `sudo iptables -S` yoki `sudo nft list ruleset` chiqishidan Docker zanjirlarini topib izohlang. `127.0.0.1` ga qaytarib, yopilganini tekshiring.

21. **Fresh VM proof.** VM'ni o'chirib qayta yarating va bitta buyruq bilan (`ansible-playbook site.yml`) to'liq tayyorlang. Vaqtni o'lchang. Darhol ikkinchi marta ishga tushiring: `changed=0` bo'lishi shart, bo'lmasa qaysi task va nima uchun ekanini toping va tuzating. Uchinchi marta `--check --diff` bilan: toza. Cloud modulida shu serverni qo'lda sozlashga ketgan vaqt bilan solishtiring.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza, `ansible-lint` `production` profilida toza.
2. Toza VM'da `ansible-playbook site.yml` xatosiz, ikkinchi ishga tushirish `changed=0`.
3. Repoda ochiq secret yo'q: `vault.yml` shifrlangan, vault parol fayli va private kalit repodan tashqarida.
4. VM o'chirilgan: `multipass list` bo'sh.
5. Menga xabar bering, `README.md`, role'lar va workflow'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Role `defaults` va `vars` farqi nima? Sozlanadigan parametr qayerga yoziladi va nima uchun?
- Role o'zgaruvchilariga nima uchun prefiks qo'yiladi?
- Vault secret'ni qayerda himoya qiladi va qayerda himoya qilmaydi?
- `no_log: true` ning narxi nima?
- `--tags` bilan ishlash qanday xavf tug'diradi?
- Dynamic inventory statik fayldan nimasi bilan yaxshi, `keyed_groups` nima qiladi?
- UFW'ni yoqishdan oldin nima qilinishi shart? sshd va sudoers fayllarida `validate` nima uchun kerak?
- Docker publish qilgan port nima uchun UFW qoidasiga bo'ysunmaydi va bunga qarshi nima qilasiz?
- "Ikkinchi ishga tushirish `changed=0`" talabi amalda nimani kafolatlaydi?
