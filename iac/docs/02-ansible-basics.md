# 2-dars: Ansible asoslari

Maqsad: Ansible bilan serverlarni kod orqali sozlashni o'rganish: inventory, ad-hoc buyruqlar, modullar, playbook, handler, o'zgaruvchilar, facts, Jinja2 template, loop va shartlar, check mode. 1-darsda idempotent bash yozib, har qadam uchun "tekshir, keyin bajar" juftligini, hisobotni va dry-run'ni o'zingiz yozdingiz. Ansible moduli aynan shu juftlikning tayyor, sinalgan ko'rinishi. Bu dars 3-darsdagi role'lar va 5-darsdagi Terraform + Ansible birikmasining asosi.

Taxminiy vaqt: 4 kun (siz uchun). YAML va template sintaksisi tanish, diqqatni quyidagilarga qarating: modul nishonda qanday bajariladi (SSH + Python), `changed` va `ok` farqi nimadan kelib chiqadi, handler qachon ishlaydi va qachon ishlamay qoladi, o'zgaruvchi precedence'i, `command`/`shell` nima uchun idempotent emas, check mode nimani ko'rsata olmaydi.

## Laboratoriya

- **Control node**: ish mashinangiz. Ansible shu yerda o'rnatiladi va ishga tushadi. Foydalanuvchi darajasida (`pipx`) o'rnatiladi, tizim Python'iga tegmaydi.
- **Nishonlar (managed nodes)**: ikkita Multipass VM, `web1` va `db1`. Paket, foydalanuvchi va servis o'zgarishlari faqat shularda. Playbook'larni hech qachon `localhost` ga qarata ishga tushirmang.

O'rnatish (hujjat: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html):

```
sudo apt install pipx
pipx ensurepath
pipx install --include-deps ansible
ansible --version
```

Nishonlarga SSH kalit bilan kirish kerak. Alohida laboratoriya kaliti yarating (`ssh-keygen -t ed25519 -f ~/.ssh/iac_lab -C iac-lab`) va uni cloud-init orqali VM'ga joylang. `lab-init.yaml` (1-darsdagi `#cloud-config` formati) ichida yuqori darajadagi `ssh_authorized_keys:` ro'yxatiga `~/.ssh/iac_lab.pub` mazmunini yozing, u standart `ubuntu` foydalanuvchisiga qo'shiladi.

```
multipass launch 24.04 --name web1 --cpus 1 --memory 1G --disk 5G --cloud-init lab-init.yaml
multipass launch 24.04 --name db1 --cpus 1 --memory 1G --disk 5G --cloud-init lab-init.yaml
multipass list
ssh -i ~/.ssh/iac_lab ubuntu@<web1-IP> hostname
```

Tozalash: `multipass delete --purge web1 db1`. 3-darsda shu VM'lar kerak bo'ladi, lekin har doim noldan qayta yaratish mumkin bo'lishi kerak (bu IaC ning mazmuni).

---

## 1. Arxitektura

Ansible agentless: nishonda doimiy ishlaydigan dastur yo'q. Talab: SSH kirish va Python interpretatori (Ubuntu 24.04 da bor).

Bitta task bajarilganda nima bo'ladi:
1. Control node task parametrlaridan Python dasturini (modul + argumentlar) yig'adi.
2. SSH orqali nishonga ulanadi va uni vaqtinchalik papkaga (`~/.ansible/tmp`) ko'chiradi.
3. Nishondagi Python uni bajaradi. Modul joriy holatni tekshiradi, kerak bo'lsa o'zgartiradi.
4. Modul natijani JSON sifatida qaytaradi (`changed`, `failed`, `msg` va modulga xos maydonlar), vaqtinchalik fayl o'chiriladi.

Bundan kelib chiqadigan xulosalar:
- Mantiq nishonda bajariladi, control node'da emas. `ansible.builtin.copy` ning `src` yo'li control node'dagi fayl, `dest` nishondagi yo'l. Bu chalkashlik eng ko'p uchraydigan xatolardan.
- Har task har host uchun alohida SSH amali, shuning uchun Ansible bash skriptdan sekinroq. Parallellik `forks` bilan (standart 5 ta host bir vaqtda).
- Standart strategiya `linear`: birinchi task hamma hostda tugaydi, keyin ikkinchi task boshlanadi.

`ansible` paketi ikki qismdan iborat: `ansible-core` (dvigatel va `ansible.builtin` modullari) va tanlangan collection'lar to'plami (`community.general`, `ansible.posix`, `community.docker`, `amazon.aws` va boshqalar). Modul nomlari to'liq yoziladi (FQCN): `ansible.builtin.apt`, shunchaki `apt` emas.

## 2. Inventory

Inventory bu hostlar va guruhlar ro'yxati. Ikki format bor, INI:

```
# inventory.ini
[web]
web1 ansible_host=10.20.30.11

[db]
db1 ansible_host=10.20.30.12

[app:children]
web
db

[all:vars]
ansible_user=ubuntu
```

YAML formatida xuddi shu tuzilish ichma-ich kalitlar bilan yoziladi: `all` ostida `vars` va `children`, har guruh ostida `hosts`, har host ostida uning o'zgaruvchilari (`web1:` va ichida `ansible_host: 10.20.30.11`).

- `web1` bu inventory nomi (alias), `ansible_host` haqiqiy manzil. Playbook'larda faqat nom ishlatiladi.
- Ikkita yashirin guruh har doim bor: `all` va `ungrouped`.
- Ulanish o'zgaruvchilari: `ansible_user`, `ansible_port`, `ansible_ssh_private_key_file`, `ansible_python_interpreter`.
- Tekshirish: `ansible-inventory --graph` (daraxt), `ansible-inventory --list` (JSON, barcha o'zgaruvchilar bilan), `ansible-inventory --host web1`.

**Tuzoq: INI formatida tiplar.** Host qatoridagi `key=value` Python literal sifatida o'qiladi (`port=8080` son bo'ladi), `[group:vars]` bo'limidagi qiymatlar esa har doim string. YAML inventory'da bu noaniqlik yo'q, shuning uchun jiddiy loyihalarda YAML afzal.

Host pattern'lari: `all`, `web`, `web:db` (birlashma), `web:&prod` (kesishma), `all:!db` (istisno), `web1`. `--limit` flag'i ham shu sintaksisni qabul qiladi.

## 3. ansible.cfg

Sozlamalar fayli quyidagi tartibda qidiriladi, birinchi topilgani ishlatiladi (birlashtirilmaydi): `ANSIBLE_CONFIG` muhit o'zgaruvchisi, joriy papkadagi `ansible.cfg`, `~/.ansible.cfg`, `/etc/ansible/ansible.cfg`. Loyiha ildizida saqlash odat, shunda sozlamalar repo bilan birga yuradi.

```
[defaults]
inventory = inventory.yml
remote_user = ubuntu
private_key_file = ~/.ssh/iac_lab
host_key_checking = False
interpreter_python = auto_silent

[ssh_connection]
pipelining = True
```

- `host_key_checking = False` faqat laboratoriya uchun: Multipass VM'lar qayta yaratilganda IP takrorlanadi va `known_hosts` to'qnashadi. Production'da yoqilgan bo'lishi kerak.
- `pipelining` modulni faylga ko'chirmasdan SSH kanali orqali uzatadi, task'lar sezilarli tezlashadi.
- Qaysi sozlama qayerdan kelganini ko'rish: `ansible-config dump --only-changed`. `ansible --version` ishlatilayotgan config fayl yo'lini ko'rsatadi.

## 4. Ad-hoc buyruqlar va modullar

Ad-hoc bu playbook'siz bitta modulni ishga tushirish: `ansible <pattern> -m <module> -a "<args>"`.

```
ansible all -m ansible.builtin.ping
ansible web -a "uptime"
ansible web -m ansible.builtin.apt -a "name=htop state=present update_cache=true" --become
ansible all -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

- `ping` ICMP emas: SSH ulanish va nishonda Python ishlashini tekshiradi, `pong` qaytaradi.
- `-m` berilmasa `ansible.builtin.command` ishlatiladi.
- `--become` (`-b`) privilege escalation, standart usul `sudo`, standart foydalanuvchi `root`. Multipass'dagi `ubuntu` parolsiz sudo'ga ega. Parol kerak bo'lsa `-K`.
- Modul hujjati terminalda: `ansible-doc ansible.builtin.user`, ro'yxat: `ansible-doc -l`.

Ko'p ishlatiladigan `ansible.builtin` modullari:

| Modul | Vazifa | Asosiy parametrlar |
|-------|--------|--------------------|
| `apt` | paket | `name`, `state` (`present`/`absent`/`latest`), `update_cache`, `cache_valid_time` |
| `copy` | faylni control node'dan nishonga | `src` yoki `content`, `dest`, `owner`, `group`, `mode` |
| `template` | Jinja2 dan fayl | `src`, `dest`, `mode`, `validate` |
| `file` | papka, symlink, huquqlar | `path`, `state` (`directory`/`link`/`absent`/`touch`), `mode` |
| `lineinfile` | fayldagi bitta qator | `path`, `regexp`, `line`, `state` |
| `user`, `group` | foydalanuvchi, guruh | `name`, `groups`, `append`, `shell`, `state` |
| `service`, `systemd_service` | servis | `name`, `state` (`started`/`restarted`/`reloaded`), `enabled` |
| `command`, `shell` | ixtiyoriy buyruq | `cmd`, `creates`, `removes`, `chdir` |

`command` shell'siz bajaradi (pipe, `>`, `&&`, `$VAR` ishlamaydi), `shell` esa `/bin/sh` orqali. Ikkalasi ham oxirgi chora: tegishli modul bo'lsa o'shani ishlating.

**Tuzoq: `mode: 644` (qo'shtirnoqsiz, boshida nolsiz).** YAML buni o'nlik son 644 deb o'qiydi va huquqlar kutilmagan bo'ladi. Har doim string yozing: `mode: "0644"`.

## 5. Playbook

```
- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Ensure nginx is running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

- Playbook bu play'lar ro'yxati. Play hostlar guruhini task'lar ro'yxati bilan bog'laydi.
- Ishga tushirish: `ansible-playbook site.yml`. Foydali flag'lar: `--limit web1`, `--list-hosts`, `--list-tasks`, `--syntax-check`, `--start-at-task "Install nginx"`, `-v` dan `-vvv` gacha.
- Har play boshida yashirin `Gathering Facts` task'i ishlaydi (7-bo'lim).
- Task bir hostda muvaffaqiyatsiz bo'lsa, o'sha host play'ning qolgan qismidan chiqariladi, boshqa hostlar davom etadi.

Oxiridagi `PLAY RECAP` har host uchun hisoblagichlar beradi: `ok=3 changed=1 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0`. `ok` holat allaqachon to'g'ri edi (yoki o'zgartirildi, `changed` ham `ok` ga kiradi), `changed` modul nimanidir o'zgartirdi. Yaxshi yozilgan playbook ikkinchi ishga tushirishda `changed=0` beradi. Bu 1-darsda o'zingiz yozgan hisobotning aynan o'zi.

### Handler
Handler bu faqat xabar (notify) kelganda ishlaydigan task. Odatiy holat: config o'zgarsa servisni qayta yuklash.

```
  tasks:
    - name: Deploy nginx site config
      ansible.builtin.template:
        src: site.conf.j2
        dest: /etc/nginx/sites-available/default
        mode: "0644"
      notify: Reload nginx

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

Qoidalar:
- Handler faqat task `changed` bo'lsa xabar oladi. Config o'zgarmasa reload ham bo'lmaydi.
- Handler'lar play'dagi barcha task'lar tugagach ishlaydi, bir necha marta xabar berilgan bo'lsa ham bir marta.
- Ishlash tartibi `handlers:` bo'limida yozilgan tartib, `notify` tartibi emas.
- Darhol ishlatish kerak bo'lsa: `- ansible.builtin.meta: flush_handlers`.

**Tuzoq: yo'qolgan handler.** Config task'i `changed` bo'ldi, handler navbatga tushdi, keyingi task xato berdi va play to'xtadi. Handler ishlamadi. Xatoni tuzatib qayta ishga tushirsangiz config task'i endi `ok` (fayl allaqachon joyida), handler xabar olmaydi. Natija: yangi config diskda, servis eski config bilan ishlayapti. Himoya: `--force-handlers` flag'i (yoki play'da `force_handlers: true`), muhim joylarda `flush_handlers`.

## 6. O'zgaruvchilar va precedence

O'zgaruvchi ko'p joyda aniqlanishi mumkin. Bir xil nom bir nechta joyda bo'lsa, ustunroq manba yutadi. To'liq ro'yxat 22 darajali (Manbalar), amalda eslab qolish kerak bo'lgan soddalashtirilgan tartib, pastdan yuqoriga:

| Daraja | Manba |
|--------|-------|
| eng past | role `defaults/main.yml` |
| | inventory `group_vars/all`, keyin aniqroq guruh `group_vars/<group>` |
| | inventory `host_vars/<host>` |
| | facts |
| | play `vars:`, `vars_files:` |
| | role `vars/main.yml` |
| | block va task `vars:` |
| | `set_fact`, `register` |
| eng yuqori | `-e` / `--extra-vars` |

Amaliy qoida: har o'zgaruvchini bitta joyda aniqlang. Standart qiymat role `defaults` da, muhitga xos qiymat `group_vars` da, bir martalik ustun yozish `-e` bilan.

- Murojaat: `"{{ http_port }}"`. Qiymat `{{` bilan boshlansa YAML uni dict deb o'ylamasligi uchun qo'shtirnoq majburiy.
- `register` task natijasini o'zgaruvchiga yozadi: `register: result`, keyin `result.rc`, `result.stdout`, `result.changed`.
- Aniqlanmagan o'zgaruvchiga murojaat xato beradi (jimgina bo'sh string emas). Standart qiymat: `{{ http_port | default(80) }}`.

## 7. Facts

Play boshida `ansible.builtin.setup` moduli nishondan ma'lumot yig'adi: OS, tarmoq, xotira, disklar. Ular `ansible_facts` dict'ida, murojaat: `{{ ansible_facts['distribution'] }}`.

Ko'p ishlatiladiganlari: `distribution`, `distribution_release`, `os_family`, `hostname`, `default_ipv4.address`, `memtotal_mb`, `processor_vcpus`. Fact yig'ish har host uchun bir necha soniya oladi; kerak bo'lmasa play'da `gather_facts: false`.

## 8. Template, loop, shartlar

### Jinja2 template
`ansible.builtin.template` fayl `src` ni control node'da render qiladi va natijani nishonga yozadi. Fayl kengaytmasi odatda `.j2`.

```
server {
    listen {{ http_port }};
    server_name {{ ansible_facts['hostname'] }};
{% for loc in locations %}
    location {{ loc.path }} { proxy_pass {{ loc.upstream }}; }
{% endfor %}
}
```

`{{ }}` ifoda, `{% %}` boshqaruv (`for`, `if`), `{# #}` komment. Filtrlar: `default`, `upper`, `join(", ")`, `to_nice_yaml`, `length`. `validate` parametri faylni joyiga qo'yishdan oldin tekshiradi (`%s` vaqtinchalik fayl yo'li): `validate: "visudo -cf %s"`.

### Loop

```
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    append: true
  loop:
    - { name: alice, groups: sudo }
    - { name: bob, groups: adm }
  loop_control:
    label: "{{ item.name }}"
```

`loop_control.label` chiqishda butun `item` o'rniga faqat kerakli qismni ko'rsatadi (parol bor dict'lar uchun muhim). Paket modullariga ro'yxatni loop'siz bering: `name: [nginx, curl]` bitta tranzaksiyada o'rnatadi.

### when

Task'ga shart: `when: ansible_facts['os_family'] == "Debian"`. `when` qiymati tayyor Jinja2 ifoda, `{{ }}` yozilmaydi. Ro'yxat berilsa shartlar `and` bilan bog'lanadi. `loop` bilan birga `when` har element uchun alohida tekshiriladi.

## 9. Idempotency, changed_when, check mode

Modullar idempotent, `command` va `shell` esa yo'q: Ansible buyruq nima qilganini bilmaydi, shuning uchun har safar `changed` deb hisobot beradi. Uch xil yechim:

```
- name: Initialize app data
  ansible.builtin.command: /opt/app/bin/init
  args:
    creates: /opt/app/data/.initialized
```

- `changed_when: false` faqat o'qiydigan buyruqlar uchun (`nginx -v`, `cat`), odatda `register` bilan birga.
- `creates` (yoki `removes`): fayl mavjud bo'lsa buyruq umuman bajarilmaydi.
- `changed_when: "'created' in result.stdout"` chiqishga qarab aniqlash.
- `failed_when` muvaffaqiyatsizlik mezonini qayta aniqlaydi, masalan `grep` ning `rc == 1` (topilmadi) xato emas: `failed_when: result.rc > 1`.

### Check mode va diff
- `--check`: hech narsani o'zgartirmaydi, har modul "o'zgartirgan bo'lardim" deb hisobot beradi (1-darsdagi `--check` flag'ingiz).
- `--diff`: fayl o'zgarishlarini unified diff ko'rinishida ko'rsatadi. Ikkalasi birga: `ansible-playbook site.yml --check --diff`.

Cheklovlar:
- `command`/`shell` check mode'da o'tkazib yuboriladi (`skipped`), demak ularning natijasiga tayangan keyingi task'lar noto'g'ri ishlashi mumkin. Faqat o'qiydigan buyruqqa `check_mode: false` qo'yib, uni check mode'da ham bajartirish mumkin.
- Zanjirli bog'liqlik: check mode'da paket o'rnatilmaydi, keyingi "servisni ishga tushir" task'i "bunday servis yo'q" deb xato berishi mumkin. Bu playbook xatosi emas, check mode'ning tabiati.

## Tuzoqlar

- `command`/`shell` bilan `apt-get install`, `useradd`, `echo >> file` yozish. Bu Ansible ichidagi bash: idempotency, check mode va diff yo'qoladi. Avval modul qidiring.
- `mode: 644` qo'shtirnoqsiz. Har doim `"0644"`.
- `state: latest` ni paketlar uchun odat qilish. Har ishga tushirishda versiya o'zgarishi mumkin, playbook takrorlanuvchan bo'lmay qoladi. `present` yoki aniq versiya.
- Yo'qolgan handler (5-bo'lim): play yarmida uzilsa servis eski config bilan qoladi.
- `user` modulida `groups` ni `append: true` siz berish: foydalanuvchi ro'yxatda yo'q boshqa barcha qo'shimcha guruhlardan chiqariladi (masalan `sudo` dan).
- Bir xil o'zgaruvchini bir nechta joyda aniqlash va "nima uchun qiymat o'zgarmayapti" deb izlash. `ansible-inventory --host <name>` va `debug` bilan tekshiring.
- `--check` toza o'tdi, demak haqiqiy ishga tushirish ham o'tadi deb ishonish. Check mode `command` task'larini va zanjirli bog'liqliklarni ko'rmaydi.
- `ignore_errors: true` bilan xatoni yashirish. To'g'ri yo'l `failed_when` bilan aniq mezon.

## Manbalar

- https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html – o'rnatish (pipx)
- https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html – inventory, INI va YAML
- https://docs.ansible.com/ansible/latest/reference_appendices/config.html – ansible.cfg sozlamalari va qidiruv tartibi
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html – handler'lar
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html – o'zgaruvchilar va to'liq precedence ro'yxati
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html – check mode va diff
- https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html – `changed_when`, `failed_when`
- https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html – `ansible.builtin` modullari
- https://jinja.palletsprojects.com/en/stable/templates/ – Jinja2 template sintaksisi
- Jeff Geerling, "Ansible for DevOps", 1–5 boblar

---

## Vazifalar

Ish papkasi: `iac/02-ansible-basics/` (`make new m=iac n=02 name=ansible-basics`). Javoblarni `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi (`PLAY RECAP`, xato matni) va o'z so'zingiz bilan izoh. `ansible.cfg`, inventory, playbook va template fayllari shu papkada saqlanadi. Barcha playbook'lar faqat Multipass VM'larga qarshi ishlaydi.

### A. O'rnatish va inventory

1. **Install and version.** Ansible'ni `pipx` bilan o'rnating. `ansible --version` chiqishidan yozing: `ansible-core` versiyasi, ishlatilayotgan config fayl, Python versiyasi. `ansible` paketi va `ansible-core` farqini izohlang. `ansible-galaxy collection list` bilan nechta collection birga kelganini ko'ring.

2. **INI inventory.** `inventory.ini` yozing: `web` guruhida `web1`, `db` guruhida `db1`, ikkalasini birlashtiruvchi `app` ota guruh, `ansible_user` barcha uchun. `ansible-inventory -i inventory.ini --graph` va `--list` chiqishini o'qing. `all` va `ungrouped` qayerdan paydo bo'ldi?

3. **YAML inventory.** Xuddi shu inventory'ni `inventory.yml` ga o'tkazing. Ikkalasining `--list` chiqishi bir xil ekanini isbotlang (masalan `diff` bilan). INI'da host qatoriga `http_port=8080`, `[web:vars]` ga ham `http_port=8080` yozib, `--list` da tiplar farqini ko'rsating.

4. **ansible.cfg.** Loyiha papkasida `ansible.cfg` yarating: inventory yo'li, `remote_user`, kalit fayli. Endi `-i` flag'isiz ishlashini tekshiring. `ansible-config dump --only-changed` chiqishini yozing. Boshqa papkadan ishga tushirsangiz nima bo'ladi va nima uchun?

### B. Ad-hoc va modullar

5. **Ping module.** `ansible all -m ansible.builtin.ping`. Bu modul aynan nimani tekshiradi? Uch xil buzing va xatolarni o'qing: noto'g'ri `ansible_user`, noto'g'ri kalit fayli, `multipass stop db1`. `UNREACHABLE` va `FAILED` farqi nima?

6. **Ad-hoc idempotency.** `ansible web -a "whoami"` ni `--become` bilan va usiz ishga tushiring. `htop` ni `apt` moduli bilan (`--become`) ikki marta o'rnating: birinchi va ikkinchi natija rangi va `changed` qiymatini yozing. Keyin `ansible web -a "touch /tmp/marker"` ni ikki marta ishga tushiring. Nima uchun modul ikkinchi safar `changed: false`, buyruq esa har safar `CHANGED`?

7. **Facts.** `setup` moduli bilan `web1` dan oling: distributiv va versiyasi, umumiy xotira, asosiy IPv4 manzil, vCPU soni. `filter` parametrini ishlating. To'liq chiqish necha qator? Fact yig'ish qancha vaqt oladi (`time` bilan o'lchang)?

### C. Playbook

8. **First playbook.** `web.yml` yozing: `web` guruhida nginx o'rnatilgan, ishlab turgan va `enabled`. Ikki marta ishga tushiring, ikkala `PLAY RECAP` ni yozing. Ish mashinasidan `curl http://<web1-IP>` bilan tekshiring. `--syntax-check` va `--list-tasks` ni sinang.

9. **Check and diff.** Playbook'ga `copy` moduli bilan (`content` parametri) `/var/www/html/index.html` ni boshqaradigan task qo'shing. Avval `--check --diff` bilan ishga tushiring: nima ko'rsatdi, serverda nimadir o'zgardimi? Keyin haqiqiy ishga tushiring. Faylni VM'da qo'lda o'zgartirib (drift), yana `--check --diff` qiling.

10. **Jinja2 template.** `templates/site.conf.j2` yozing: `listen` porti o'zgaruvchidan, `server_name` fact'dan, `locations` ro'yxati ustida `{% for %}`, kamida bitta `default` filtri. `template` moduli bilan joylang. Render natijasini VM'da o'qib tekshiring.

11. **Handler.** Template task'iga `notify` bilan nginx reload handler'ini ulang. Isbotlang: (a) template o'zgarmasa handler ishlamaydi; (b) ikkita task bitta handler'ga xabar bersa u bir marta ishlaydi; (c) handler barcha task'lardan keyin ishlaydi. Portni o'zgartirib, `curl` bilan yangi portda javob berishini tekshiring.

12. **Lost handler.** Template task'idan keyin ataylab xato beradigan task qo'ying (`ansible.builtin.command: /bin/false`). Portni o'zgartirib ishga tushiring: handler ishladimi? Xato task'ni olib tashlab qayta ishga tushiring: endi-chi? nginx qaysi portda tinglayapti (`ss -tlnp`), diskdagi config nima deydi? Ikki xil yechimni qo'llab ko'ring va farqini yozing.

13. **Variable precedence.** `http_port` ni to'rt joyda har xil qiymat bilan aniqlang: inventory'da `all` guruh darajasida, `web` guruh darajasida, play `vars:` da va `-e` bilan. `debug` bilan qaysi biri yutganini ko'rsating, keyin eng ustunini bittalab olib tashlab tartibni tasdiqlang. Natijani jadval qilib yozing.

14. **Loops and conditionals.** O'zgaruvchida foydalanuvchilar ro'yxatini (dict'lar: `name`, `groups`, `state`) aniqlang va `loop` bilan yarating, `loop_control.label` ishlating. Bitta foydalanuvchini `state: absent` qilib o'chiring. `when` bilan faqat `db` guruhidagi hostlarda bajariladigan task qo'shing (`group_names` o'zgaruvchisini `ansible-doc` yoki hujjatdan toping).

15. **groups without append.** `ansible-doc ansible.builtin.user` dan `append` ning standart qiymatini toping. VM'da qo'lda `sudo` guruhiga kiritilgan sinov foydalanuvchisini yarating. Keyin `user` moduli bilan unga `groups: adm` ni `append` siz bering. `id <user>` oldin va keyin nima ko'rsatadi? `--check --diff` buni oldindan ko'rsatarmidi?

16. **changed_when and creates.** Uchta `command` task yozing: (a) faqat o'qiydigan (`nginx -v`), `register` + `changed_when: false`; (b) bir marta bajarilishi kerak bo'lgan, `creates` bilan; (c) chiqishiga qarab `changed` aniqlanadigan. Har biri ikkinchi ishga tushirishda `changed` bermasligini ko'rsating. Ularni `--check` da ishga tushirsangiz nima bo'ladi?

17. **failed_when.** `/etc/nginx/nginx.conf` da `server_tokens off` qatori bor yoki yo'qligini `grep` bilan tekshiradigan task yozing. `grep` topmaganida task `FAILED` bo'lmasin, lekin fayl mavjud bo'lmasa (`rc == 2`) bo'lsin. Natijaga qarab keyingi task'da `debug` xabar chiqaring.

18. **Undefined variable.** Template'da aniqlanmagan o'zgaruvchini ishlating va xato matnini to'liq o'qing: qaysi fayl, qaysi qator ko'rsatilgan? Uni ikki usulda tuzating: `default` filtri va play boshida `ansible.builtin.assert` bilan majburiy o'zgaruvchilarni tekshirish. Qaysi holatda qaysi biri to'g'ri?

### D. Kichik loyiha

19. **Bash to playbook.** 1-darsdagi `provision_v2.sh` ning yakuniy holatini `provision.yml` playbook'i sifatida qayta yozing (`command`/`shell` ishlatmasdan). Yangi VM'da uch marta ishga tushiring: birinchi `changed>0`, keyingilari `changed=0`. 1-dars 10-vazifadagi drift'larni qayta yarating va `--check --diff` nimani ko'rsatishini, haqiqiy ishga tushirish nimani tuzatishini yozing. 1-darsdagi "Pain summary" jadvaliga Ansible ustunini qo'shing. Ansible ham yecha olmagan muammo qaysi?

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. Barcha playbook'lar `ansible-playbook --syntax-check` dan o'tadi va ikkinchi ishga tushirishda `changed=0` beradi (12-vazifadagi ataylab buzilgan variant bundan mustasno, uni alohida faylda saqlang).
3. Repoda private kalit yo'q, inventory'da parol yo'q.
4. VM'lar: 3-darsga darhol o'tmasangiz `multipass delete --purge web1 db1`.
5. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Ansible bitta task'ni nishonda qanday bajaradi? Nishonda nima o'rnatilgan bo'lishi kerak?
- `ok` va `changed` farqi nima va modul buni qanday aniqlaydi?
- `command` moduli nima uchun har safar `changed` beradi va buni qanday uch usulda tuzatish mumkin?
- Handler qachon ishlaydi? Qanday holatda u "yo'qoladi" va oqibati nima?
- Bir xil o'zgaruvchi `group_vars`, play `vars` va `-e` da bo'lsa qaysi biri yutadi? Role `defaults` nima uchun eng pastda?
- `--check` nimani ko'rsata olmaydi?
- `copy` va `template` da `src` qayerdagi fayl?
- `user` modulida `append: true` yozilmasa nima bo'ladi?
