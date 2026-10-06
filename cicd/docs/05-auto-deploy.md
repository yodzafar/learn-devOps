# 5-dars: Dasturlarni serverga avtomatik deploy

Maqsad: pipeline'ning oxirgi bo'g'inini qurish: `main` ga merge qilingan commit hech kim serverga qo'lda kirmasdan production'ga chiqadi, tekshiriladi va kerak bo'lsa bir buyruq bilan qaytariladi. Vercel yoki Netlify'da bu bitta tugma edi: "merge qildim, sayt yangilandi, yoqmasa Instant Rollback". Bu darsda o'sha tugmaning ichini qo'lda yig'asiz. Cloud 4-darsda konteynerlangan ilovani AWS VM'ga qo'lda deploy qilgansiz (SSH bilan kirib `docker compose pull` va `up`). Endi shu qadamlarni cicd 2-darsdagi GitHub Actions pipeline'iga ko'chirasiz va qo'lda qilganda yashirin qolgan savollarga javob berasiz: pipeline serverga qanday huquq bilan kiradi, yangi versiya buzuq chiqsa nima bo'ladi, deploy paytida foydalanuvchi xato ko'radimi, database sxemasi qachon o'zgaradi, cloud kalitlari CI'da saqlanishi shartmi. Kubernetes modulida deploy mexanizmi o'zgaradi, lekin shu yerdagi tushunchalar (immutable tag, health check, strategiya, rollback) o'zgarishsiz qoladi.

Taxminiy vaqt: 7 kun (siz uchun). 1-kun: 1–2 bo'limlar va A guruh (server va kirish). 2–3-kunlar: 3, 4, 7-bo'limlar va B guruh (avtomatik deploy, smoke test, rollback, xabarnoma). 4-kun: 5-bo'lim, "Birga bajaramiz" va 13–15-vazifalar (blue-green lokal va skript). 5-kun: 6-bo'lim va 16–17-vazifalar (migratsiyalar), 8-bo'lim va 18-vazifa (OIDC). 6–7-kunlar: mini-loyiha (19–21), tozalash va README. Diqqatni quyidagilarga qarating: deploy kalitining huquqini cheklash, `known_hosts`, SHA tag va rollback aloqasi, exit code'ning serverdan pipeline'gacha yetib kelishi, migratsiyalarning orqaga mos bo'lishi, blue-green almashtirish qayerda sodir bo'lishi, trust policy'dagi `sub` sharti.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz bajaring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Misollar ataylab vazifalardagi holatdan boshqa (boshqa servis nomi, boshqa skript), ularni o'z vazifangizga o'zingiz moslaysiz. IP manzil, account ID, SHA, fingerprint kabi qiymatlar sizda boshqa bo'ladi, darsda ular `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsda to'rtta "joy" bor va har buyruq qaysi birida bajarilishini bilish shart:

| Joy | Nima | Bu darsda nima bajariladi |
|-----|------|---------------------------|
| Host (Zorin yoki macOS) | ish mashinangiz | `git`, `gh`, `aws`, `ssh`, `docker compose` (lokal blue-green mashqi), `make check` |
| GitHub-hosted runner | GitHub har job uchun beradigan bir martalik Ubuntu VM (cicd 2), `x86_64` | test, image build va push, serverga SSH, smoke test, xabarnoma |
| AWS VM | cloud 3–4-darslardagi EC2 instans (Ubuntu, Docker va Compose plugin) | deploy nishoni: `deploy` user, `authorized_keys`, `/opt/app`, `deploy.sh`, konteynerlar |
| GHCR | GitHub Container Registry (cicd 2) | SHA bilan teglangan image'lar |

- **Deploy nishoni**: VM'ni cloud 3–4-darslardagi qadamlar bilan qayta ko'taring. Oldin budget alert yoqilganini tekshiring (cloud 2). Eng kichik instans tipi, bitta region, hamma resursda `project=devops-course` tag'i. Narx va free tier shartlarini dars emas, https://aws.amazon.com/pricing/ aytadi.
- **Arxitektura**: image'ni pipeline yig'adi, runner `x86_64`, demak image `linux/amd64` bo'ladi, `git push` qaysi mashinadan qilinganidan qat'i nazar. VM ham `x86_64` instans tipida bo'lishi kerak. Graviton (`arm64`) instans tanlasangiz, image'ni multi-platform yig'ish kerak bo'ladi (docker 2 va cloud 4), aks holda konteyner `exec format error` bilan yiqiladi.
- **Tizim o'zgarishlari** (deploy user, `authorized_keys`, papkalar, Docker) faqat VM'da bajariladi, ish mashinasida emas. `deploy.sh` VM'da (Linux) ishlaydi, unda GNU utilitalar bor.
- **Security group** (cloud 3: instans oldidagi firewall qoidalari): 80 (va TLS bo'lsa 443) hammaga ochiq. 22-port sizning shaxsiy kirishingiz uchun faqat hozirgi IP'ingizga (`/32`) ochiladi, `0.0.0.0/0` ga emas. Pipeline uchun 22-portni qanday ochish alohida muammo, 2-bo'limdagi "Tarmoq" qismida.
- **Blue-green mashqi** avval host'da Docker Compose bilan lokal qilinadi (bepul, tez), keyin VM'ga ko'chiriladi.
- **Ish papkasi** `cicd/05-auto-deploy/`: `README.md`, `deploy.sh`, `compose.yaml`, proxy konfiguratsiyasi, workflow nusxalari (asl workflow'lar `cicd-demo` reposida yashaydi).
- **Har mashg'ulot oxirida** instansni to'xtating: `aws ec2 stop-instances --instance-ids <instance-id>`. Elastic IP ishlatmasangiz, qayta yoqilganda public IP o'zgaradi: `DEPLOY_HOST` kabi variable'lar va `known_hosts` yozuvidagi manzilni yangilash kerak bo'ladi (host key'ning o'zi diskda qoladi, o'zgarmaydi). Elastic IP esa ajratilgan holda turgani uchun pul olishi mumkin.
- **Tozalash (majburiy)**: dars oxirida VM, Elastic IP, OIDC uchun yaratilgan IAM role va identity provider, GitHub'dagi deploy secret'lari o'chiriladi va buyruq bilan tekshiriladi ("Topshirish" bo'limi).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host `amd64`. Lokal blue-green mashqida konteyner IP'lariga host'dan to'g'ridan-to'g'ri yetish mumkin, lekin darsda bunga tayanilmaydi, faqat `localhost` dagi published port ishlatiladi. Security group'dagi shaxsiy SSH qoidasida ofis IP'si turadi. |
| macOS (uy) | Host `arm64`, zsh va BSD userland. Docker yashirin Linux VM ichida: konteyner IP'lari host'dan ko'rinmaydi, published port `localhost` da ishlaydi. Stock image'lar (`nginx`) multi-arch, mashq bir xil o'tadi. `ip`, `ss`, `systemctl` host'da yo'q, ular kerak bo'lsa AWS VM ichida ishlatiladi. Security group'da uy IP'si turadi. |

Ikkinchi mashinada nima takrorlanadi. AWS akkaunt, VM, `cicd-demo` reposi, uning environment'lari, secret va variable'lari cloud'da yashaydi va ikkala mashinadan bir xil ko'rinadi. Mashinaga xos va git orqali hech qachon ko'chmaydigan uch narsa bor: AWS CLI profili (`aws configure`, cloud 2), `gh auth login`, va VM'ni boshqarish uchun shaxsiy SSH kalitingiz (har mashinada o'z juftligi, ikkalasining public qismi VM'dagi `ubuntu` foydalanuvchisining `authorized_keys` ida). Joy almashtirganda security group'dagi shaxsiy SSH qoidasini yangi IP'ga almashtiring:

```
$ curl -s https://checkip.amazonaws.com
<your-public-ip>
$ aws ec2 authorize-security-group-ingress --group-id <sg-id> \
    --protocol tcp --port 22 --cidr <your-public-ip>/32
$ aws ec2 revoke-security-group-ingress --group-id <sg-id> \
    --protocol tcp --port 22 --cidr <old-ip>/32
```

Birinchi buyruq AWS'ning "sizning tashqi IP'ingiz" xizmati, ikkinchisi yangi manzilni qo'shadi, uchinchisi eskisini olib tashlaydi. Deploy kaliti (pipeline uchun) bu ro'yxatda yo'q: u bir marta yaratiladi, private qismi faqat GitHub secret'ida turadi va hech bir mashinangizda qolmaydi (2-bo'lim).

---

## 1. Push-based va pull-based deploy

### Bu nima

Deploy bu yangi versiyani serverda ishga tushirish. Buni kim boshlashiga qarab ikki model bor. **Push-based**: pipeline serverga o'zi ulanadi va "shu versiyani chiqar" deb buyruq beradi. **Pull-based**: serverda doimiy ishlaydigan agent (kichik dastur) registry yoki git repo'ni kuzatadi va yangi versiyani o'zi tortib oladi.

| | Push-based | Pull-based |
|-|------------|------------|
| Kim boshlaydi | pipeline serverga ulanadi | serverdagi agent o'zi tekshiradi |
| Credential qayerda | CI tizimida serverga kirish kaliti | serverda registry yoki repo'ni o'qish huquqi |
| Tarmoq | server CI'dan kiruvchi ulanishni qabul qiladi | faqat chiquvchi ulanish |
| Natija | pipeline deploy natijasini darhol biladi | pipeline bilmaydi, alohida kuzatish kerak |
| Misollar | SSH + Compose, Ansible, CI'dan `kubectl apply` | Argo CD, Flux (GitOps), Watchtower, cron + `docker compose pull` |

### Mexanizm: kim qaysi kalitni ushlab turadi

Credential bu kirish huquqini isbotlaydigan narsa: parol, token, SSH private key. Ikki modelning asosiy farqi shu credential qaysi tomonda turishida.

Push'da zanjir: GitHub secret'ida SSH private key → runner uni job davomida faylga yozadi → `ssh` serverga ulanadi → server buyruqni bajaradi → natija (exit code va log) o'sha ulanish orqali job'ga qaytadi. CI tizimi production'ning kalitini saqlaydi, demak CI'ni buzgan odam (masalan buzilgan uchinchi tomon action'i, cicd 2) production'ga ham yetadi. Evaziga pipeline deploy tugaganini va qanday tugaganini shu zahoti biladi.

Pull'da server tashqariga hech narsa ochmaydi. Agent davriy ravishda "kerakli holat" ni (image tag yoki git'dagi manifest) o'qiydi, hozirgi holat bilan solishtiradi va farqni yo'qotadi. CI'da production kaliti yo'q, serverda faqat o'qish huquqi bor. Kamchiligi: pipeline "deploy bo'ldimi" degan savolga javobni o'zi bilmaydi, uni alohida so'rash yoki kuzatish kerak. GitOps shu g'oyaning to'liq shakli: git'dagi fayl yagona haqiqat manbai, uni kubernetes modulida ko'rasiz.

Oraliq variant: serverning o'zidagi self-hosted runner (cicd 2). Runner GitHub'ga chiquvchi ulanish ochib job kutadi va deploy'ni lokal bajaradi. Kiruvchi SSH kerak emas, lekin cicd 2-darsdagi xavf to'liq amal qiladi: runner workflow'dagi istalgan kodni production serverida bajaradi.

### Misol: eng sodda pull

Eng sodda pull agenti bu cron (linux modulidagi rejalashtiruvchi) va ikki buyruq. Serverdagi `crontab` qatori:

```
*/5 * * * * cd /srv/site && docker compose pull --quiet && docker compose up -d
```

Chapdan o'ngga: `*/5 * * * *` har 5 daqiqada; `cd /srv/site` compose fayl turgan papka; `pull --quiet` registry'dan fayldagi tag'ning hozirgi image'ini oladi; `&&` faqat oldingisi muvaffaqiyatli bo'lsa davom etadi; `up -d` image o'zgargan bo'lsa konteynerni qayta yaratadi, o'zgarmagan bo'lsa hech narsa qilmaydi. Bu ishlaydi, lekin faqat o'zgaruvchan tag (`latest`) bilan, natijani hech kim tekshirmaydi va 5 daqiqagacha kechikadi. Shu uch kamchilik 3 va 4-bo'limlarning mavzusi.

### Real ishda qachon kerak

- Bitta yoki bir nechta VM, kichik jamoa: push-based SSH yoki Ansible. Sodda, har qadami log'da ko'rinadi.
- Kubernetes va ko'p muhit: pull-based GitOps, chunki cluster'ga tashqaridan kirish kalitini CI'ga berish xavfli va holat doim git bilan solishtiriladi.
- Server yopiq tarmoqda (kiruvchi ulanish taqiqlangan): pull yoki ichkaridagi self-hosted runner.

Bu darsda push-based SSH deploy quriladi, chunki uning har qadami ko'rinadi va Vercel'dagi "Deploy" tugmasi ortida nima borligini to'liq ochadi.

### Nima uchun shunday

Push tarixan birinchi paydo bo'lgan: administrator serverga kirib qilgan ishni skript, keyin CI takrorlagan. Pull modeli serverlar soni ko'payib, "hamma joyga kirish kalitini bitta CI'da saqlash" xavfli bo'lib qolganda va Kubernetes "kerakli holatni e'lon qil, tizim o'zi yetkazadi" degan yondashuvni olib kelganda ommalashdi. Vercel va Netlify ichkarida o'z platformasiga push qiladi: sizdan faqat git'ga kirish so'raydi, serverlar esa ularniki, shuning uchun sizda kalit muammosi ko'rinmagan.

## 2. Pipeline'dan SSH: kalit, known_hosts, deploy user

### Workflow serverga SSH qilganda nima sodir bo'ladi

SSH (linux va network modullari) bu shifrlangan kanal orqali uzoq mashinada buyruq bajarish protokoli. `ssh user@host 'buyruq'` ishlaganda to'rt narsa ketma-ket sodir bo'ladi:

1. **Server o'zini isbotlaydi.** Server o'zining host key'ini (har serverda bir marta yaratiladigan kalit juftligi, `/etc/ssh/ssh_host_*_key`) ko'rsatadi. Mijoz uni `~/.ssh/known_hosts` faylidagi yozuv bilan solishtiradi. Mos kelmasa ulanish uziladi.
2. **Mijoz o'zini isbotlaydi.** Mijoz private key bilan imzo qo'yadi, server `~/.ssh/authorized_keys` dagi public key bilan tekshiradi.
3. **Buyruq bajariladi.** Server foydalanuvchining shell'ida berilgan buyruqni ishga tushiradi, stdout va stderr kanal orqali mijozga oqadi (job log'ida ko'rasiz).
4. **Exit code qaytadi.** Uzoqdagi buyruqning exit code'i (linux 1: 0 muvaffaqiyat, boshqasi xato) `ssh` ning o'z exit code'iga aylanadi. SSH'ning o'zi ulana olmasa, kod `255`.

To'rtinchi qadam butun deploy'ning tayanchi: GitHub Actions step'i oxirgi buyruqning kodi nol bo'lmasa qizil bo'ladi, demak serverdagi xato job'gacha yetib keladi. Tekshirish (istalgan SSH serverda, masalan VM'ga shaxsiy kalitingiz bilan):

```
$ ssh ubuntu@<vm-ip> 'exit 3'; echo "ssh exit: $?"
ssh exit: 3
$ ssh ubuntu@<vm-ip> 'false; echo done'; echo "ssh exit: $?"
done
ssh exit: 0
```

Birinchi buyruqda uzoqdagi `exit 3` aynan `3` bo'lib qaytdi. Ikkinchisida `false` yiqildi, lekin `;` undan keyin `echo` ni baribir ishlatdi va oxirgi buyruqning kodi (`0`) qaytdi: xato yo'qoldi. Step'da log'ning oxirgi qatori `Error: Process completed with exit code 3.` bo'lsa, uch raqami serverdan kelgan.

### Ikki xil kalit

Bu darsda ikki SSH juftligi bor va ularni aralashtirmaslik kerak:

| | Shaxsiy kalit | Deploy kaliti |
|-|---------------|---------------|
| Kim ishlatadi | siz, VM'ni boshqarish uchun | faqat pipeline |
| Nechta | har mashinada bittadan | bitta, bir marta yaratiladi |
| Private qismi qayerda | `~/.ssh/` da, passphrase bilan | faqat GitHub environment secret'ida |
| Serverda kim sifatida kiradi | `ubuntu` (`sudo` bor) | `deploy` (cheklangan) |

Deploy kaliti parolsiz (`-N ""`) yaratiladi, chunki pipeline passphrase kirita olmaydi. Uni repo'dan tashqaridagi vaqtinchalik papkada yaratish, secret'ga quvur orqali yozish va lokal nusxani darhol o'chirish kerak. Boshqa loyiha (masalan backup serveri) misolida:

```
$ tmp=$(mktemp -d)
$ ssh-keygen -t ed25519 -N "" -C "backup-ci" -f "$tmp/key"
Generating public/private ed25519 key pair.
Your identification has been saved in <tmp>/key
Your public key has been saved in <tmp>/key.pub
The key fingerprint is:
SHA256:<fingerprint> backup-ci
$ gh secret set BACKUP_SSH_KEY --env production < "$tmp/key"
✓ Set Actions secret BACKUP_SSH_KEY for <owner>/<repo>
$ cat "$tmp/key.pub"
ssh-ed25519 AAAA<...> backup-ci
$ rm -r "$tmp"
```

`mktemp -d` tasodifiy nomli bo'sh papka yaratadi (ikkala host'da ishlaydi), shu sabab kalit hech qachon git ko'radigan joyga tushmaydi. `-t ed25519` kalit turi, `-C` izoh (serverdagi `authorized_keys` da kalit kimniki ekanini aytadi), `-f` fayl nomi. `gh secret set ... < fayl` qiymatni stdin'dan o'qiydi: private key terminal tarixiga ham, ekranga ham chiqmaydi. `key.pub` ochiq qism, uni serverga qo'yasiz. `rm -r` dan keyin private key faqat GitHub'da qoladi; GitHub secret'ni qayta o'qishga bermaydi, yo'qolsa yangi juftlik yaratiladi, bu arzon. `--env production` secret'ni environment darajasiga yozadi (cicd 2): uni faqat `environment: production` deb e'lon qilgan va environment qoidalaridan (branch cheklovi, reviewer) o'tgan job oladi.

### known_hosts

`known_hosts` bu mijozdagi "men ishonadigan serverlar va ularning host key'lari" ro'yxati. Birinchi ulanishda `ssh` notanish kalitni ko'rsatib "ishonasizmi?" deb so'raydi. Runner har job'da toza VM, unda bu fayl bo'sh va savolga javob beradigan odam yo'q. Keng tarqalgan va noto'g'ri yechim `-o StrictHostKeyChecking=no`: u birinchi qadamni (server o'zini isbotlashi) o'chiradi. Tarmoq yo'lidagi hujumchi o'zini server qilib ko'rsatsa, pipeline unga ulanadi va buyruqlarini yuboradi (man-in-the-middle).

To'g'ri yo'l **pinning**: host key bir marta, tekshirilgan holda olinadi va CI'da saqlanadi, job uni `known_hosts` ga yozadi.

```
$ ssh-keyscan -t ed25519 <host> > /tmp/hostkey
# <host>:22 SSH-2.0-OpenSSH_<version>
$ cat /tmp/hostkey
<host> ssh-ed25519 AAAA<...>
$ ssh-keygen -lf /tmp/hostkey
256 SHA256:<fingerprint> <host> (ED25519)
```

`ssh-keyscan` serverga ulanib faqat host key'ni so'raydi; `#` bilan boshlangan qator stderr'ga chiqadigan izoh (server versiyasi), faylga tushmaydi. Fayldagi qator `known_hosts` formati: manzil, kalit turi, kalit. `ssh-keygen -lf` uning fingerprint'ini (kalitning qisqa xeshi) chiqaradi: `256` bit uzunlik, `SHA256:...` xesh, `(ED25519)` tur. Lekin `ssh-keyscan` ham tarmoq orqali oladi, demak o'zi ham aldanishi mumkin. Shuning uchun fingerprint ishonchli kanal orqali (allaqachon tekshirilgan sessiyada yoki cloud konsolidan) serverning o'zida hisoblangan qiymat bilan solishtiriladi:

```
ubuntu@<vm>:~$ ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
256 SHA256:<fingerprint> root@<hostname> (ED25519)
```

Ikki `SHA256:` qiymati bir xil bo'lsa, yozuv to'g'ri. Host key ochiq ma'lumot, shuning uchun secret emas, variable (`gh variable set`, cicd 2) sifatida saqlanadi. Job'da u faylga yoziladi:

```yaml
- name: Trust the backup host
  env:
    KNOWN_HOSTS: ${{ vars.BACKUP_KNOWN_HOSTS }}
  run: |
    install -m 700 -d ~/.ssh
    printf '%s\n' "$KNOWN_HOSTS" > ~/.ssh/known_hosts
```

`install -m 700 -d` papkani kerakli ruxsat bilan yaratadi, `printf` qiymatni faylga yozadi. Private key ham shunga o'xshab faylga yoziladi, lekin uning ruxsatlari haqida o'zingiz o'ylaysiz (7-vazifa; `ssh` boshqalar o'qiy oladigan kalit faylni ishlatishdan bosh tortadi). Yozuv mos kelmasa job shunday yiqiladi:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
...
Host key verification failed.
Error: Process completed with exit code 255.
```

`255` SSH'ning o'z xatosi (buyruq bajarilmadi). Bu xato VM'ni qayta yaratganingizda ham chiqadi (yangi disk, yangi host key): variable'ni yangilash kerak, tekshiruvni o'chirish emas.

**Tuzoq: `ssh-keyscan` ni job ichida ishlatish.** Har run'da tarmoqdan olingan kalitga ishonish `StrictHostKeyChecking=no` bilan bir xil natija beradi.

### Least-privilege deploy user va forced command

Least privilege bu "har kimga faqat ishi uchun kerakli eng kam huquq" tamoyili (cloud 2, IAM). Deploy kaliti `ubuntu` yoki `root` ga kirish bermaydi. VM'da alohida `deploy` foydalanuvchisi yaratiladi: `sudo` siz, parolsiz, faqat kalit bilan (linux modulidagi user boshqaruvi).

Nozik joy: `deploy` Docker bilan ishlashi kerak. Docker daemon `root` sifatida ishlaydi va `docker` guruhidagi har kim unga istalgan host papkasini konteynerga ulashni buyura oladi (docker 1 va 3), demak guruh a'zoligi amalda root huquqi. Foydalanuvchini cheklab bo'lmagach, kalitning o'zi cheklanadi. `authorized_keys` da har kalit oldiga variantlar yoziladi. Boshqa holat misolida, faqat disk hisobotini ola oladigan kalit:

```
restrict,command="/usr/local/bin/disk-report.sh" ssh-ed25519 AAAA<...> monitoring-ci
```

- `command="..."` (forced command): bu kalit bilan kirilganda mijoz nima so'rasa ham faqat shu dastur bajariladi. Mijoz yuborgan asl buyruq satri dasturga `SSH_ORIGINAL_COMMAND` environment variable'ida keladi.
- `restrict`: port forwarding, agent forwarding, X11 forwarding va PTY (interaktiv terminal) ajratishni o'chiradi, kelajakda qo'shiladigan cheklovlarni ham o'z ichiga oladi.

Forced command ortidagi skript `SSH_ORIGINAL_COMMAND` ni ishonchsiz kiritish deb qabul qiladi va faqat oq ro'yxatdagi qiymatni o'tkazadi. O'sha `disk-report.sh` ning boshi:

```bash
#!/usr/bin/env bash
set -euo pipefail
case "${SSH_ORIGINAL_COMMAND:-}" in
  root|data) target="$SSH_ORIGINAL_COMMAND" ;;
  *) echo "rejected: unknown argument" >&2; exit 64 ;;
esac
```

`set -euo pipefail` (linux modulidagi shell darsi): xatoda to'xta, e'lon qilinmagan o'zgaruvchida to'xta, pipe ichidagi xatoni yo'qotma. `case` faqat ikki aniq so'zni qabul qiladi, qolgan hamma narsa (jumladan `root; id` kabi urinish) rad etiladi va `64` kodi `ssh` orqali mijozga qaytadi. Sizning deploy skriptingizda qiymat so'z emas, commit SHA bo'ladi: uning formatini qat'iy tekshirish usulini o'zingiz tanlaysiz (5-vazifa).

Natija: kalit o'g'irlansa ham u bilan shell ochib bo'lmaydi, faqat skript ruxsat bergan amalni so'rash mumkin. Deploy mantiqi serverda turadi, pipeline faqat "shu versiyani chiqar" deydi.

**Tuzoq: `SSH_ORIGINAL_COMMAND` ni tekshirmasdan ishlatish.** Uni `eval` qilish yoki `docker` buyrug'iga to'g'ridan qo'yish forced command'ni ma'nosiz qiladi.

### Tarmoq: runner'ning doimiy IP'si yo'q

GitHub-hosted runner'lar keng va o'zgarib turadigan IP diapazonlaridan chiqadi, shuning uchun security group'da 22-portni "faqat pipeline" ga toraytirib bo'lmaydi. Halol variantlar:

| Variant | Qanday | Narxi |
|---------|--------|-------|
| 22-port ochiq, kirish faqat kalit bilan, kalit forced command bilan cheklangan | qoida `0.0.0.0/0`, lekin parol bilan kirish o'chiq | port internetdan ko'rinadi, skanerlar log'ni to'ldiradi |
| Workflow portni vaqtincha ochadi | job OIDC (8-bo'lim) bilan AWS'ga kirib, o'z IP'siga qoida qo'shadi va oxirida olib tashlaydi | qo'shimcha IAM huquqi va murakkablik |
| Self-hosted runner serverda yoki uning tarmog'ida | kiruvchi SSH umuman kerak emas | runner xavfi (cicd 2) |
| Pull-based agent | 1-bo'lim | pipeline natijani bilmaydi |
| SSH o'rniga AWS Systems Manager | buyruq AWS API orqali yuboriladi, port ochilmaydi | AWS'ga bog'lanish, OIDC kerak |

Bu darsda birinchi variant ishlatiladi, chunki u eng ko'rinadigan, lekin tartib bilan: pipeline uchun `0.0.0.0/0` qoidasi faqat mashg'ulot davomida turadi (boshida qo'shing, oxirida `revoke-security-group-ingress` bilan olib tashlang va instansni to'xtating), va oldin VM'da parol bilan kirish o'chiqligini tekshiring: `sudo sshd -T | grep -i passwordauthentication` javobi `passwordauthentication no` bo'lishi kerak. Sizning shaxsiy qoidangiz har doim `/32`. "22-port butun internetga ochiq va parol bilan kirish yoqilgan" hech qachon variant emas. Mini-loyihada ikkinchi variantga o'tishni sinab ko'rishingiz mumkin.

### Real ishda qachon kerak

- Har qanday "CI serverga kiradi" sxemasida: alohida kalit, pinned host key, cheklangan user. Shu uchligi yo'q pipeline xavfsizlik tekshiruvidan o'tmaydi.
- Forced command backup, monitoring, git hosting'da ham ishlatiladi: `git@github.com` ga SSH qilganingizda shell ochilmasligi aynan shu mexanizm.
- "Deploy yashil, sayt eski" degan shikoyatda birinchi tekshiriladigan narsa exit code zanjiri.

### Nima uchun shunday

SSH ikki tomonlama tekshiruvni ataylab ajratgan: server kalitini bilmagan mijoz parolini yoki buyrug'ini begonaga berib qo'yishi mumkin. `authorized_keys` variantlari SSH'ning dastlabki yillaridan beri bor, chunki "avtomat uchun kalit" ehtiyoji CI'dan ancha oldin (backup, rsync) paydo bo'lgan. Muqobil yondashuv: uzoq yashaydigan kalit o'rniga qisqa muddatli SSH sertifikatlari yoki umuman SSH'siz (Systems Manager, pull). Ular kalitni saqlash muammosini yo'qotadi, lekin qo'shimcha infratuzilma talab qiladi. Vercel'da bu bo'lim butunlay yo'q edi, chunki server sizniki emas edi.

## 3. Image tag: commit SHA, hech qachon latest

### Bu nima

Tag bu registry'dagi image'ga qo'yilgan nom (docker 2), u istalgan payt boshqa image'ga ko'chirilishi mumkin. **Immutable tag** deb bir marta qo'yilib qayta yozilmaydigan tag'ga aytiladi; amalda bu commit SHA (git 1: commit'ning 40 belgili xeshi). Deploy buyrug'i "qaysi versiya" ni aniq aytishi kerak, `latest` esa buni aytmaydi.

### Mexanizm: latest nimani buzadi

- `docker compose up -d` lokal image bor bo'lsa registry'ni tekshirmaydi: yangi `latest` push qilingan, serverda esa eskisi ishlayveradi.
- Serverda hozir qaysi commit ishlayotganini bilib bo'lmaydi (audit yo'q).
- Rollback uchun "oldingi `latest`" degan narsa yo'q, u ustidan yozilgan.
- Ikki server turli vaqtda pull qilsa turli versiyalarni ishlatadi.

SHA tag bilan zanjir shunday: commit → pipeline shu commit'dan image yig'adi va `:<sha>` deb push qiladi (cicd 1: build once, deploy many) → deploy buyrug'i aynan shu SHA'ni oladi → ilova `/version` da shu SHA'ni qaytaradi. Har bo'g'inda bitta identifikator. Compose fayl versiyani o'zgaruvchidan oladi. Boshqa servis misolida:

```yaml
services:
  docs:
    image: nginx:${DOCS_TAG:?DOCS_TAG is required}
```

`${VAR:?msg}` Compose interpolatsiyasi: o'zgaruvchi berilmagan yoki bo'sh bo'lsa Compose fayl o'qilishidayoq xato bilan to'xtaydi va `msg` ni chiqaradi, tasodifan bo'sh tag bilan deploy bo'lmaydi. Qiymat berilganda `docker compose config` to'liq hal qilingan faylni ko'rsatadi:

```
$ DOCS_TAG=1.27-alpine docker compose config | grep image
    image: nginx:1.27-alpine
```

Eng qat'iy variant tag o'rniga **digest** (docker 2: image mazmunining `sha256` xeshi, `image@sha256:...`): tag nazariy jihatdan qayta yozilishi mumkin, digest yo'q. Serverda aslida nima ishlayotganini digest aytadi:

```
$ docker image inspect --format '{{index .RepoDigests 0}}' nginx:1.27-alpine
nginx@sha256:<digest>
```

Private GHCR image'ni serverdan pull qilish uchun serverda alohida, faqat o'qish huquqli (`read:packages`) token bilan `docker login ghcr.io` qilinadi, yoki package public qilinadi. Pipeline'ning `GITHUB_TOKEN` i (cicd 2) serverga berilmaydi, u baribir job tugashi bilan o'ladi.

### Real ishda qachon kerak

- Incident paytida birinchi savol "production'da hozir nima ishlayapti?". SHA tag bilan javob bitta `curl /version` yoki `docker ps`.
- Rollback (7-bo'lim) faqat oldingi image aniq nom bilan registry'da turgan bo'lsa mumkin.
- Registry tozalash siyosati (eski tag'larni o'chirish) rollback uchun kerakli oxirgi N ta SHA'ni saqlashi shart.

### Nima uchun shunday

`latest` Docker'ning standart tag'i, "eng yangi" degan kafolat emas, shunchaki tag ko'rsatilmaganda qo'yiladigan nom. U lokal tajriba uchun qulay, production uchun emas. `package-lock.json` bilan o'xshashlik haqiqiy: `"react": "latest"` deb yozilgan `package.json` har o'rnatishda boshqa natija beradi, lock fayl esa aniq versiya va integrity xeshini qotiradi. SHA tag aniq versiya, digest integrity xeshi. Vercel'da har deployment'ning o'z o'zgarmas URL'i borligi ham shu g'oya.

## 4. Health check, readiness va smoke test

### Bu nima

"Konteyner ishga tushdi" va "ilova ishlayapti" turli narsalar. Qoida: **deploy tekshirilmaguncha tugamagan**. Tekshiruv uch darajada:

| Daraja | Nima tekshiradi | Qayerda |
|--------|-----------------|---------|
| Konteyner healthcheck | jarayon ichkaridan javob beradimi | `Dockerfile` `HEALTHCHECK` yoki Compose `healthcheck` (docker 4) |
| Deploy kutishi | yangi konteyner `healthy` bo'ldimi | `docker compose up -d --wait` |
| Smoke test | tashqaridan, foydalanuvchi yo'li bilan ishlaydimi va **kutilgan versiya** javob beradimi | pipeline'ning deploy'dan keyingi step'i |

Health endpoint dizaynida ikki savol ajratiladi. **Liveness**: jarayon tirikmi (yo'q bo'lsa qayta ishga tushirish kerak). **Readiness**: so'rov qabul qilishga tayyormi (bazaga ulangan, migratsiya tugagan; yo'q bo'lsa trafik berilmaydi, lekin o'ldirilmaydi). Proxy trafikni faqat ready nusxaga yuboradi. Bu ajratish kubernetes modulida probe'lar sifatida qaytadi.

### Mexanizm va misol

Compose `healthcheck` konteyner ichida buyruqni davriy ishlatadi; kod 0 bo'lsa holat `healthy`, ketma-ket `retries` marta yiqilsa `unhealthy`. O'sha `docs` servisi uchun:

```yaml
    healthcheck:
      test: ["CMD", "wget", "-qO", "/dev/null", "http://127.0.0.1/"]
      interval: 5s
      timeout: 2s
      retries: 5
      start_period: 5s
```

`test` bajariladigan buyruq (image ichida `wget` bo'lishi shart), `interval` oraliq, `timeout` bitta tekshiruvga chegara, `start_period` ishga tushish davri (bu vaqtdagi xatolar hisobga olinmaydi). `docker compose up -d --wait` servislar `running` yoki `healthy` bo'lguncha kutadi, bo'lmasa nol bo'lmagan kod bilan qaytadi (`--wait-timeout <soniya>` bilan cheklanadi):

```
$ DOCS_TAG=1.27-alpine docker compose up -d --wait; echo "exit: $?"
 ✔ Container <project>-docs-1  Healthy
exit: 0
$ docker compose ps --format '{{.Name}} {{.Status}}'
<project>-docs-1 Up <N> seconds (healthy)
```

`Healthy` Compose healthcheck natijasini kutganini bildiradi, `exit: 0` deploy skriptiga "davom et" degani. `--wait` siz `up -d` konteyner yaratilishi bilanoq 0 qaytaradi, ilova bir soniyadan keyin yiqilsa ham.

Smoke test tashqaridan, ommaviy manzilga boradi:

```
curl --fail --silent --show-error --retry 10 --retry-delay 3 --retry-all-errors \
  "https://docs.example.com/"
```

`--fail` 4xx va 5xx javobda nol bo'lmagan kod qaytaradi (usiz `curl` 500 javobni ham "muvaffaqiyat" deb hisoblaydi), `--silent --show-error` progressni yashirib xatoni qoldiradi, `--retry` va `--retry-delay` qayta urinish soni va oralig'i, `--retry-all-errors` ulanish rad etilgan holatni ham qayta urinadi (ilova hali ko'tarilayotgan bo'lishi mumkin).

Smoke test 200 kodni emas, javobda aynan deploy qilingan versiya turganini tekshirishi kerak. Aks holda eski versiya ishlab turgan va yangisi umuman ko'tarilmagan holatda ham test yashil bo'ladi.

### Real ishda qachon kerak

- Har deploy'dan keyin avtomatik; yiqilsa rollback (7-bo'lim) ishga tushadi.
- Healthcheck'ga og'ir tekshiruv (tashqi API'ga so'rov) qo'yilsa, tashqi xizmat sekinlashganda sizning barcha nusxalaringiz "unhealthy" bo'lib qoladi. Liveness yengil, readiness faqat o'z bog'liqliklari.

### Nima uchun shunday

Vercel'da deployment "Ready" bo'lishidan oldin platforma build va ishga tushishni o'zi tekshiradi, keyin domenni yangi deployment'ga ulaydi. O'z serveringizda bu tekshiruvni hech kim qilmaydi: jarayon tirik bo'lishi so'rovga javob berishini anglatmaydi, ichkaridan javob berishi esa tashqaridan (DNS, firewall, proxy, TLS orqali) yetib borishini anglatmaydi. Uch daraja shu uch bo'shliqni yopadi.

## 5. Deploy strategiyalari

### Bu nima

Strategiya bu eski versiyadan yangisiga o'tish tartibi.

| Strategiya | Qanday ishlaydi | Downtime | Rollback | Infratuzilmadan nima talab qiladi |
|------------|-----------------|----------|----------|-----------------------------------|
| Recreate | eskisini to'xtat, yangisini ko'tar | bor | qayta deploy | hech narsa |
| Rolling | nusxalar birin-ketin yangilanadi | yo'q (2+ nusxa) | teskari rolling | bir nechta nusxa va ular oldida load balancer |
| Blue-green | yangi versiya to'liq parallel ko'tariladi, trafik bir zumda almashtiriladi | yo'q | trafikni qaytarish | vaqtincha ikki barobar resurs, almashtiriladigan proxy |
| Canary | trafikning kichik qismi (1–5%) yangisiga, metrikalar yaxshi bo'lsa oshiriladi | yo'q | canary'ni o'chirish | trafikni ulushlab bo'ladigan proxy va metrika tahlili (monitoring moduli) |

Bitta VM'da oddiy `docker compose up -d` bu recreate. Qolgan uchtasining umumiy sharti: bir vaqtda ikki versiya ishlaydi, demak ular bir-biriga va bitta database sxemasiga mos bo'lishi kerak (6-bo'lim).

### Mexanizm: almashtirish qayerda sodir bo'ladi

Almashtirish ilovada emas, uning oldidagi reverse proxy'da (network moduli va cloud 4: so'rovni qabul qilib orqadagi servisga uzatadigan server) sodir bo'ladi. nginx'da orqadagi manzillar ro'yxati **upstream** deyiladi:

```nginx
upstream app {
    server app-green:3000;
}
```

Blue-green qadamlari: (1) `blue` jonli, yangi versiya `green` sifatida ko'tariladi, `blue` ga tegilmaydi; (2) `green` ichki tarmoq orqali tekshiriladi, yiqilsa o'chiriladi va foydalanuvchi hech narsa sezmaydi; (3) proxy konfiguratsiyasi `green` ga yo'naltiriladi va **reload** qilinadi; (4) tashqaridan smoke test, yiqilsa proxy `blue` ga qaytariladi; (5) kuzatuv oynasidan keyin `blue` to'xtatiladi yoki zaxira sifatida qoldiriladi. Qaysi rang jonli ekani serverda faylda saqlanadi.

Reload va restart farqi. `nginx -s reload` master jarayonga signal yuboradi: u yangi konfiguratsiya bilan yangi worker'lar ochadi, eski worker'lar yangi ulanish olmaydi, ochiq so'rovlarini tugatib yopiladi. Bu **connection draining**: ulanishlar uzilmaydi. Restart esa jarayonni o'ldirib qayta ochadi, orada port yopiq. Reload'dan oldin konfiguratsiya tekshiriladi:

```
$ docker compose exec proxy nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
$ docker compose exec proxy nginx -s reload
<sana> [notice] <pid>#<pid>: signal process started
```

Birinchi ikki qator sintaksis va to'liq tekshiruv o'tganini aytadi (xato bo'lsa fayl va qator raqami chiqadi, kod nol emas, reload qilinmaydi). `signal process started` signal master'ga yuborilganini bildiradi.

**Tuzoq: graceful shutdown.** Eski nusxa `SIGTERM` (linux 1: "iltimos tugat" signali) olganda ochiq so'rovlarni tugatmasdan o'lsa, bir nechta foydalanuvchi baribir xato oladi. Ilova `SIGTERM` ni ushlab yangi ulanish qabul qilishni to'xtatishi va joriylarini tugatishi kerak (docker modulidagi PID 1 va signal mavzusi; Node'da `process.on('SIGTERM', ...)` va `server.close()`). Compose'da `stop_grace_period` Docker `SIGKILL` yuborguncha qancha kutishini belgilaydi.

### Real ishda qachon kerak

- Ichki asbob, tungi deploy mumkin: recreate yetarli, murakkablik qo'shmang.
- Bitta VM, downtime mumkin emas: blue-green (shu dars). Bir nechta nusxa yoki Kubernetes: rolling (kubernetes moduli, standart strategiya).
- Katta trafik va xavfli o'zgarish: canary, metrikalar bilan.

### Nima uchun shunday

Hamma strategiya bitta savolga javob: xatoni necha foydalanuvchi va qancha vaqt ko'radi. Recreate'da hamma, deploy davomida; blue-green'da smoke test ushlamagan xatoni hamma, lekin qaytish soniyalar; canary'da faqat kichik ulush. Vercel'da har deployment alohida ko'tariladi va domen unga ko'chiriladi, ya'ni bu blue-green; "Instant Rollback" domenni oldingi deployment'ga qaytarishdir. Siz o'sha domen ko'chirishni nginx upstream bilan qilasiz.

## 6. Database migratsiyalari

### Bu nima

Migratsiya bu database sxemasini (jadvallar, ustunlar, indekslar) bir versiyadan keyingisiga o'tkazadigan skript. Kod stateless (holatsiz): image'ni almashtirsangiz eski holat to'liq qaytadi. Database esa holat: o'chirilgan ustundagi ma'lumot qaytib kelmaydi. Shuning uchun migratsiyalar deploy'ning eng xavfli qismi.

### Mexanizm

- Migratsiyalar kod bilan birga repo'da, raqamlangan va tartibli. Migration tool (`node-pg-migrate`, Prisma Migrate, Flyway, `golang-migrate`) qaysilari qo'llanganini bazadagi maxsus jadvalda saqlaydi va faqat yangilarini bajaradi.
- Migratsiya pipeline'da **alohida qadam**, yangi kod trafik olishidan oldin, **bir marta** bajariladi. Ilovaning start kodida ishlatilsa, bir nechta nusxa bir vaqtda migratsiya qilishga urinadi.
- Har migratsiya **orqaga mos** (backward compatible): eski kod yangi sxema bilan ishlay oladi. Chunki blue-green paytida va rollback'dan keyin eski kod yangi sxemaga duch keladi. Mos bo'lishi kerak bo'lgan masofa: kamida bitta reliz.

Buzuvchi o'zgarish **expand/contract** usulida bir nechta deploy'ga bo'linadi: avval kengaytir (yangisini qo'sh), keyin ko'chir, oxirida toraytir (eskisini o'chir). Misol: `orders.status` matn ustunini `status_id` raqam ustuniga almashtirish.

| Deploy | Sxema | Kod |
|--------|-------|-----|
| 1. Expand | `status_id` qo'shiladi (nullable) | ikkalasiga yozadi, eskisidan o'qiydi |
| 2. Migrate | eski qatorlar uchun `status_id` to'ldiriladi | yangisidan o'qiydi, ikkalasiga yozadi |
| 3. Contract | `status` o'chiriladi | faqat yangisi bilan ishlaydi |

Birinchi deploy'ning migratsiyasi faqat qo'shadi:

```sql
ALTER TABLE orders ADD COLUMN status_id integer;
```

Eski kod bu ustun haqida bilmaydi va unga tegmaydi, shuning uchun u yangi sxemada ham ishlaydi. Har qadamdan keyin bir qadam orqaga qaytish xavfsiz. Hammasini bitta deploy'da qilsangiz, eski kod darhol yiqiladi va rollback ham yordam bermaydi.

**Tuzoq: uzoq lock.** Katta jadvalda ba'zi `ALTER TABLE` amallari jadvalni bloklaydi va migratsiya davomida ilova kutib qoladi. Production migratsiyalari real hajmdagi ma'lumotda sinaladi, oldin zaxira nusxa (snapshot) olinadi.

### Real ishda qachon kerak

Ustun nomini o'zgartirish, turini almashtirish, jadvalni bo'lish, `NOT NULL` qo'shish: har biri expand/contract bilan. Faqat qo'shadigan (additive) migratsiya bitta deploy'da xavfsiz.

### Nima uchun shunday

Bu frontend'dan ma'lum qoidaning aynan o'zi: backend API'dagi maydonni frontend hali ishlatib turganda o'chirib bo'lmaydi, avval yangi maydon qo'shiladi, mijozlar o'tadi, keyin eskisi olib tashlanadi, chunki foydalanuvchi brauzerida eski bundle hali yashayapti. Bu yerda "eski mijoz" o'rnida eski kod versiyasi, "API" o'rnida sxema turadi. Muqobili (deploy vaqtida saytni yopib, hammasini birdan o'zgartirish) downtime'ga rozi bo'lgan tizimlarda hali ham ishlatiladi.

## 7. Rollback va xabarnomalar

### Bu nima

Rollback alohida mexanizm emas, "oldingi ma'lum yaxshi versiyani deploy qilish". Deploy `<sha>` ni chiqarish bo'lsa, rollback `<previous-sha>` ni chiqarishdir, xuddi shu yo'l bilan.

### Mexanizm

Buning uchun uch narsa kerak. Oldingi image registry'da turibdi (tozalash siyosati uni o'chirmagan). Kimdir oldingi muvaffaqiyatli SHA'ni biladi: server faylda saqlaydi yoki pipeline GitHub'ning deployment tarixidan oladi (`environment:` ishlatgan har job deployment yozuvi qoldiradi, cicd 2). Rollback yo'li oddiy deploy bilan bir xil koddan o'tadi va muntazam sinaladi: sinalmagan rollback mavjud emas deb hisoblanadi. Tarixni host'dan ko'rish:

```
$ gh api "repos/<owner>/<repo>/deployments?environment=production&per_page=3" \
    --jq '.[] | "\(.created_at) \(.sha)"'
<sana>T<vaqt>Z <sha-3>
<sana>T<vaqt>Z <sha-2>
<sana>T<vaqt>Z <sha-1>
```

Har qator bitta deployment: qachon va qaysi commit; eng yangisi tepada. Bu yozuv deploy boshlanganini bildiradi, muvaffaqiyatli tugaganini emas (holati alohida saqlanadi), shuning uchun "oxirgi yaxshi" ni serverdagi fayl aniqroq aytadi.

Ikki xil rollback: **avtomatik** (smoke test yiqilsa pipeline o'zi oldingi versiyaga qaytaradi va run'ni baribir qizil qiladi) va **qo'lda** (`workflow_dispatch`, cicd 2: qo'lda ishga tushiriladigan trigger, input bilan). Blue-green'da avtomatik rollback proxy'ni qaytarishdan iborat.

Nimani qaytarib bo'lmaydi: ma'lumot. Yangi versiya yozgan qatorlar, yuborilgan email'lar, o'chirilgan ustun rollback bilan qaytmaydi. Shuning uchun **roll forward** (tuzatishni yangi commit sifatida chiqarish) ba'zan yagona yo'l. Qoida: avval xizmatni tikla, keyin sababni qidir.

### Xabarnomalar

Jamoa deploy tugaganini va ayniqsa yiqilganini bilishi kerak. Step holat sharti bilan ishlaydi (`if: failure()`, `if: success()`, `if: always()`, cicd 2). Umumiy webhook misolida:

```yaml
- name: Notify on failure
  if: failure()
  env:
    WEBHOOK_URL: ${{ secrets.CHAT_WEBHOOK_URL }}
  run: |
    curl --fail --silent --show-error -X POST "$WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\"Job failed: ${GITHUB_REPOSITORY} run ${GITHUB_RUN_ID}\"}"
```

`if: failure()` step'ni faqat oldingi step'lardan biri yiqilganda ishlatadi (shartsiz step yiqilgan job'da o'tkazib yuboriladi). URL secret'dan `env` orqali keladi, `run` matniga to'g'ridan yozilmaydi. `GITHUB_REPOSITORY` va `GITHUB_RUN_ID` runner'dagi standart o'zgaruvchilar. JSON tanasining formati xizmatga bog'liq (Slack, Telegram Bot API `sendMessage`), hujjatidan oling. Yaxshi xabarda: environment, SHA, kim boshlagan, run havolasi. Muvaffaqiyatlilar uchun shovqin kam, yiqilganlar uchun aniq.

### Real ishda qachon kerak

DORA metrikalaridagi (cicd 1) "time to restore" aynan shu yo'lning tezligi. Incident paytida hech kim yangi skript yozmaydi: tayyor, sinalgan rollback bor yoki yo'q.

### Nima uchun shunday

Alohida "rollback skripti" kamdan-kam ishlatiladi, demak kamdan-kam sinaladi va kerak paytda buzuq chiqadi. Rollback'ni oddiy deploy'ning xususiy holi qilish uni har kuni sinalgan yo'lga aylantiradi. Vercel'ning "Instant Rollback" i ham yangi build qilmaydi, oldingi tayyor deployment'ga qaytadi: "build once" ning mukofoti.

## 8. OIDC: uzoq yashaydigan kalitlarsiz cloud'ga kirish

### Bu nima

Pipeline cloud API bilan ishlashi kerak bo'lsa (S3'ga yuklash, security group'ni o'zgartirish), eski usul IAM user access key'ini (cloud 2) CI secret'iga yozish edi. Kalit uzoq yashaydi, sizib chiqsa bekor qilinguncha ishlaydi, aylantirish qo'lda. **OIDC** (OpenID Connect: bir tizim boshqasiga "bu kim" ekanini imzolangan token bilan isbotlaydigan standart) bilan saqlanadigan kalit umuman yo'q. Bu **federation**: AWS GitHub bergan guvohnomaga ishonadi.

### Mexanizm

1. Job `permissions: id-token: write` bilan GitHub'ning OIDC provayderidan (`https://token.actions.githubusercontent.com`) token so'raydi. Bu **JWT** (JSON Web Token: imzolangan JSON, frontend'dagi auth token'lar bilan bir xil format), bir necha daqiqa yashaydi.
2. Token ichidagi maydonlar **claim** deyiladi: `iss` (kim bergan), `aud` (kim uchun, AWS uchun `sts.amazonaws.com`), `sub` (kim haqida), `repository`, `ref`, `sha`, `environment`, `exp` (muddat). `sub` formati job'ga bog'liq: environment ishlatgan job'da `repo:<owner>/<repo>:environment:<name>`, branch'dagi oddiy job'da `repo:<owner>/<repo>:ref:refs/heads/<branch>`, PR'da `repo:<owner>/<repo>:pull_request`.
3. Job token'ni AWS **STS** ga (Security Token Service: vaqtinchalik credential beruvchi xizmat, cloud 2–3) `AssumeRoleWithWebIdentity` chaqiruvi bilan beradi.
4. STS imzoni GitHub'ning ochiq kalitlari bilan tekshiradi (IAM'da ro'yxatdan o'tgan **OIDC identity provider** shu ishonchni e'lon qiladi), keyin role'ning **trust policy** sidagi (cloud 3: "bu role'ni kim ola oladi" hujjati) shartlarni claim'lar bilan solishtiradi.
5. Mos kelsa vaqtinchalik credential qaytaradi (standart 1 soat), ular o'zi o'ladi.

Workflow tomoni, boshqa repo misolida:

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v<N>
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/<role-name>
      aws-region: <region>
  - run: aws sts get-caller-identity
```

`@v<N>` o'rniga action'ning joriy relizini tekshirib, commit SHA bo'yicha pin qiling (cicd 2). Oxirgi step chiqishi:

```
{
    "UserId": "<role-id>:<session-name>",
    "Account": "<account-id>",
    "Arn": "arn:aws:sts::<account-id>:assumed-role/<role-name>/<session-name>"
}
```

`assumed-role` job IAM user emas, vaqtinchalik role sessiyasi ekanini ko'rsatadi. Trust policy'ning hal qiluvchi qismi `Condition` (to'liq hujjatni AWS qo'llanmasidan olib o'zingiz yig'asiz). Statik sayt reposining `main` branch'i uchun:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:<owner>/static-site:ref:refs/heads/main"
  }
}
```

Ikkala shart ham bajarilishi kerak: token AWS uchun berilgan va aynan shu repo'ning shu branch'idan kelgan. Mos kelmagan job'da STS chaqiruvni rad etadi va step yiqiladi.

**Tuzoq: keng trust policy.** `sub` sharti `repo:<owner>/*` yoki umuman yo'q bo'lsa, o'sha owner'ning (yoki GitHub'dagi har qanday) reposidagi workflow sizning role'ingizni oladi. Role'ning o'ziga ham faqat minimal huquq beriladi.

Thumbprint haqida: eski qo'llanmalar provider yaratishda GitHub sertifikatining thumbprint'ini qo'lda kiritishni talab qiladi. AWS bu provayder uchun sertifikatni o'zining ishonchli CA ro'yxati orqali tekshiradi; internetdan ko'chirilgan thumbprint qiymatiga tayanmang, joriy AWS hujjatidagi tartibga amal qiling.

### Real ishda qachon kerak

CI'dan cloud'ga har qanday kirishda: registry'ga push, Terraform (iac modulida bu role'ni Terraform bilan yaratasiz), 2-bo'limdagi "portni vaqtincha ochish". Xuddi shu mexanizm GitLab CI'da (`id_tokens`), boshqa cloud'larda va Vault'da ishlaydi.

### Nima uchun shunday

Saqlangan sir har doim sizib chiqishi mumkin; eng xavfsiz sir bu mavjud bo'lmagani. OIDC'da GitHub "bu job shu repo'dan" deb kafolat beradi, AWS esa shu kafolatga qarab qaror qiladi, o'rtada o'g'irlanadigan uzoq muddatli narsa qolmaydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Push-based deploy | pipeline serverga o'zi ulanib yangi versiyani chiqaradigan model |
| Pull-based deploy | serverdagi agent yangi versiyani o'zi kuzatib tortib oladigan model |
| Credential | kirish huquqini isbotlaydigan narsa: parol, token, private key |
| Deploy key | faqat pipeline ishlatadigan, shaxsiy kalitdan alohida SSH juftligi |
| Host key | serverning o'zini isbotlaydigan SSH kaliti |
| `known_hosts` | mijoz ishonadigan serverlar va ularning host key'lari ro'yxati |
| Fingerprint | kalitning solishtirish uchun qisqa xeshi (`SHA256:...`) |
| Pinning | qiymatni (host key, action SHA) oldindan tekshirib qotirib qo'yish |
| Least privilege | har kimga faqat ishi uchun kerakli eng kam huquq |
| Forced command | `authorized_keys` dagi `command=`: kalit faqat bitta dasturni ishga tushira oladi |
| `SSH_ORIGINAL_COMMAND` | forced command'ga mijoz so'ragan asl buyruq keladigan o'zgaruvchi |
| Immutable tag | qayta yozilmaydigan image tag'i, amalda commit SHA |
| Digest | image mazmunining `sha256` xeshi, o'zgarmas manzil |
| Healthcheck | konteyner ichida davriy bajariladigan "ilova javob beryaptimi" tekshiruvi |
| Liveness / readiness | jarayon tirikmi / so'rov qabul qilishga tayyormi |
| Smoke test | deploy'dan keyin tashqaridan qilinadigan qisqa "asosiy yo'l ishlaydimi" tekshiruvi |
| Recreate | eskisini to'xtatib yangisini ko'taradigan strategiya, downtime bilan |
| Rolling | nusxalarni birin-ketin yangilaydigan strategiya |
| Blue-green | yangi versiyani parallel ko'tarib trafikni bir zumda almashtiradigan strategiya |
| Canary | trafikning kichik ulushini yangi versiyaga beradigan strategiya |
| Upstream | reverse proxy so'rov uzatadigan orqadagi manzillar ro'yxati |
| Reload | nginx'ni to'xtatmasdan yangi konfiguratsiyaga o'tkazish |
| Connection draining | eski nusxaga yangi ulanish bermay, ochiqlarini tugatishga ruxsat berish |
| Graceful shutdown | `SIGTERM` olgan ilovaning joriy so'rovlarni tugatib yopilishi |
| Migratsiya | database sxemasini keyingi versiyaga o'tkazadigan versiyalangan skript |
| Expand/contract | buzuvchi sxema o'zgarishini qo'shish, ko'chirish, o'chirish qadamlariga bo'lish |
| Rollback / roll forward | oldingi yaxshi versiyani qayta deploy qilish / tuzatishni yangi versiya qilib chiqarish |
| OIDC | bir tizim boshqasiga shaxsni imzolangan token bilan isbotlaydigan standart |
| JWT / claim | imzolangan JSON token / uning ichidagi maydon (`sub`, `aud`) |
| STS | AWS'ning vaqtinchalik credential beruvchi xizmati |
| OIDC identity provider | IAM'dagi "shu tashqi token beruvchiga ishonaman" yozuvi |
| Trust policy | role'ni kim va qaysi shart bilan ola olishini belgilaydigan hujjat |

## Tuzoqlar

- `latest` bilan deploy: nima ishlab turganini ham, nimaga qaytishni ham bilmaysiz.
- `StrictHostKeyChecking=no` yoki job ichida `ssh-keyscan`.
- Deploy kalitini shaxsiy kalit bilan bir xil qilish, `root`/`sudo` huquqli foydalanuvchiga berish, forced command'siz qoldirish.
- Smoke test faqat 200 kodni tekshiradi, versiyani emas. Deploy bo'lmagan holatda ham yashil.
- Rollback hech qachon sinalmagan. Incident paytida birinchi marta sinab ko'riladi va ishlamaydi.
- Orqaga mos bo'lmagan migratsiya bitta deploy'da kod bilan birga. Rollback imkonsiz.
- Migratsiyani ilova start'ida, har nusxada ishga tushirish.
- Ikki deploy bir vaqtda (concurrency yo'q): server yarim yangi, yarim eski holatda.
- Deploy yiqilganda pipeline yashil (`|| true`, `continue-on-error`, SSH ichidagi buyruqning exit code'i yo'qolishi).
- Eski image'lar va to'xtatilgan konteynerlar serverda to'planib disk to'lishi, yoki aksincha, registry cleanup rollback uchun kerakli tag'ni o'chirib yuborishi.
- Deploy secret'larini repo darajasida saqlash: har branch'dagi workflow ularni oladi. Environment darajasida va deployment branch cheklovi bilan saqlang.
- GitHub Actions `run` step'ida `shell` ko'rsatilmasa bash `pipefail` siz ishlaydi: `deploy | tee log` da chapdagi xato yo'qoladi. `shell: bash` ni aniq yozing yoki `set -o pipefail` qo'shing.
- Image arxitekturasi VM'ga mos emas (`exec format error`): runner `amd64` yig'adi, VM ham `x86_64` bo'lsin.
- Bitta faylni bind mount qilib host'da qayta yozish: ba'zi muharrirlar faylni yangi inode bilan almashtiradi va konteyner eskisini ko'rib turadi. Papkani mount qiling.
- Instans to'xtatib yoqilganda public IP o'zgaradi: `known_hosts` yozuvi va host variable'i eskirib qoladi.
- Mashg'ulotdan keyin 22-port `0.0.0.0/0` ga ochiq qolishi va instans ishlab turishi.
- Deploy kalitini repo papkasida yaratish: bitta `git add .` bilan commit'ga tushadi.

## Manbalar

- https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT – `authorized_keys` formati: `command=`, `restrict`
- https://man.openbsd.org/ssh-keyscan – `ssh-keyscan`
- https://man.openbsd.org/ssh_config – `StrictHostKeyChecking`, `UserKnownHostsFile`
- https://docs.docker.com/reference/cli/docker/compose/up/ – `docker compose up`, `--wait`
- https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ – compose'da `${VAR:?}` interpolatsiyasi
- https://nginx.org/en/docs/control.html – nginx reload mexanizmi
- https://martinfowler.com/bliki/BlueGreenDeployment.html – blue-green deployment
- https://martinfowler.com/bliki/CanaryRelease.html – canary release
- https://martinfowler.com/bliki/ParallelChange.html – expand/contract (parallel change)
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect – GitHub Actions OIDC
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services – AWS bilan OIDC
- https://github.com/aws-actions/configure-aws-credentials – AWS credentials action
- https://core.telegram.org/bots/api#sendmessage – Telegram Bot API
- Humble, Farley, "Continuous Delivery", 10-bob (Deploying and Releasing Applications) va 12-bob (Managing Data)
- https://man7.org/linux/man-pages/man1/ssh.1.html – `ssh(1)`, exit status va host key tekshiruvi
- https://docs.docker.com/reference/compose-file/services/#healthcheck – Compose `healthcheck`
- https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment – environment'lar, secret va himoya qoidalari
- https://docs.github.com/en/rest/deployments/deployments – deployment tarixi API
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html – IAM OIDC identity provider yaratish
- https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html – STS `AssumeRoleWithWebIdentity`

## Birga bajaramiz

Cloud'siz va pipeline'siz, host'da: stock `nginx` image'ining ikki versiyasi proxy ortida turadi, tekshirilgan almashtirish va rollback qo'lda bajariladi. Ikkala mashinada bir xil ishlaydi (image'lar multi-arch, faqat `localhost:8080` ishlatiladi). Repo'dan tashqarida ishlang.

1. Papka va fayllar:

```
$ mkdir -p ~/bg-walk/v1 ~/bg-walk/v2 ~/bg-walk/proxy && cd ~/bg-walk
$ echo "release-1" > v1/index.html
$ echo "release-2" > v2/index.html
$ printf 'server {\n  listen 80;\n  location / { proxy_pass http://rel1:80; }\n}\n' > proxy/default.conf
```

Har "reliz" o'z sahifasiga ega, proxy konfiguratsiyasi hozircha `rel1` ga uzatadi.

2. `compose.yaml` (matn muharririda yozing):

```yaml
services:
  rel1:
    image: nginx:${REL1_TAG:?REL1_TAG is required}
    volumes: ["./v1:/usr/share/nginx/html:ro"]
  rel2:
    image: nginx:${REL2_TAG:?REL2_TAG is required}
    volumes: ["./v2:/usr/share/nginx/html:ro"]
    profiles: ["next"]
  proxy:
    image: nginx:1.27-alpine
    ports: ["8080:80"]
    volumes: ["./proxy:/etc/nginx/conf.d:ro"]
```

Tag'lar o'zgaruvchidan (3-bo'lim). `profiles: ["next"]` `rel2` ni oddiy `up` da ko'tarmaydi, faqat so'ralganda. Proxy papkani mount qiladi, bitta faylni emas (Tuzoqlar).

3. Birinchi reliz jonli:

```
$ export REL1_TAG=1.26-alpine REL2_TAG=1.27-alpine
$ docker compose up -d --wait; echo "exit: $?"
exit: 0
$ curl -fsS localhost:8080
release-1
```

4. Yangi relizni jonliga tegmasdan ko'taring va ichki tarmoqdan tekshiring:

```
$ docker compose --profile next up -d --wait rel2
$ docker compose exec proxy wget -qO- http://rel2:80
release-2
$ curl -fsS localhost:8080
release-1
```

`wget` proxy konteyneri ichidan, Compose tarmog'idagi servis nomi bilan so'radi (docker 3): yangi reliz javob beryapti, foydalanuvchi esa hali eskisini ko'ryapti (5-bo'limning 2-qadami).

5. Almashtirish: konfiguratsiyani qayta yozing, tekshiring, reload qiling:

```
$ printf 'server {\n  listen 80;\n  location / { proxy_pass http://rel2:80; }\n}\n' > proxy/default.conf
$ docker compose exec proxy nginx -t && docker compose exec proxy nginx -s reload
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
<sana> [notice] <pid>#<pid>: signal process started
$ curl -fsS localhost:8080
release-2
```

`&&` tufayli `nginx -t` yiqilsa reload bajarilmaydi. Tashqi tekshiruv kutilgan relizni ko'rsatdi: bu smoke test (4-bo'lim).

6. Rollback: `rel1` hali ishlab turibdi, shuning uchun qaytish 5-qadamning teskarisi (`proxy_pass` ni `rel1` ga yozib `nginx -t` va reload). `curl` yana `release-1` qaytaradi. Hech narsa qayta yig'ilmadi va pull qilinmadi (7-bo'lim).

7. Tag bo'yicha qaytish: `rel2` ni oldingi image versiyasiga tushiring va nima ishlayotganini tekshiring:

```
$ REL2_TAG=1.26-alpine docker compose --profile next up -d --wait rel2
$ docker compose --profile next ps --format '{{.Service}} {{.Image}}'
proxy nginx:1.27-alpine
rel1 nginx:1.26-alpine
rel2 nginx:1.26-alpine
```

Faqat o'zgaruvchi o'zgardi, fayl emas: Compose `rel2` ni qayta yaratdi (recreate, shuning uchun bu ishni jonli bo'lmagan tomonda qildik).

8. Tozalash: `docker compose --profile next down` va `cd ~ && rm -r ~/bg-walk`. `docker ps -a` da shu mashqdan konteyner qolmasligi kerak.

Ko'rganingiz: versiya o'zgaruvchidan keladi va aniq nomlanadi (3-bo'lim), `--wait` va ichki, tashqi tekshiruv (4-bo'lim), almashtirish proxy'da va reload bilan (5-bo'lim), rollback oldingi versiyaga qaytish xolos (7-bo'lim). Bu yerda o'lchov, holat fayli, skript va haqiqiy ilova yo'q: ular vazifalarda.

---

## Vazifalar

Pipeline `cicd-demo` reposida, server qismi AWS VM'da bajariladi, 13–15-vazifalar host'da (ikkala mashinada bir xil, faqat `localhost` dagi published port orqali). Javoblar `cicd/05-auto-deploy/` da (yaratish: `make new m=cicd n=05 name=auto-deploy`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi, run havolasi, qayerda bajarilgani (host, runner, VM) va o'z so'zingiz bilan izoh. `deploy.sh`, `compose.yaml`, proxy konfiguratsiyasi va workflow nusxalari shu papkada saqlanadi. Private key, token va `.env` commit qilinmaydi; README'da IP, account ID va fingerprint'dan boshqa maxfiy narsa bo'lmasin. VM'ni ko'tarishdan oldin budget alert'ni tekshiring, har mashg'ulot oxirida instansni to'xtating va pipeline uchun ochilgan 22-port qoidasini olib tashlang.

### A. Server va kirish

1. **Deploy target.** Cloud modulidagi VM'ni ko'taring (yoki mavjudini tekshiring): Docker va Compose versiyalari, security group qoidalari, budget alert. `cicd-demo` image'ini qo'lda, SHA tag bilan pull qilib ishga tushiring va tashqaridan `/version` ni tekshiring. Bu avtomatlashtiriladigan qo'l jarayonining bazaviy o'lchovi: qadamlar soni va ketgan vaqtni yozing. Yo'nalish: Laboratoriya va 3-bo'lim, "Mexanizm: latest nimani buzadi".

2. **Deploy user.** VM'da `deploy` foydalanuvchisini yarating: `sudo` siz, parol bilan kirish imkonisiz, `/opt/app` egasi. Unga Docker bilan ishlash huquqini bering va bu nima uchun "amalda root" ekanini bitta buyruq bilan namoyish qiling (VM'da, zararsiz misol). Bu xavfni keyingi vazifalar qanday kamaytirishini oldindan yozing. Yo'nalish: 2-bo'lim, "Least-privilege deploy user va forced command".

3. **Deploy key.** Alohida ed25519 juftlik yarating, public qismini `deploy` ning `authorized_keys` iga qo'ying, `ssh -i` bilan kirishni tekshiring. Private kalitni `production` environment secret'i sifatida `gh secret set` bilan yozing va lokal faylni o'chiring. Nima uchun shaxsiy kalitingizni ishlatmadingiz va nima uchun secret repo emas, environment darajasida? Yo'nalish: 2-bo'lim, "Ikki xil kalit".

4. **known_hosts.** VM host key'ini `ssh-keyscan` bilan oling va fingerprint'ini VM'ning o'zidagi kalit fingerprint'i bilan solishtiring (ikkala buyruq va natijani yozing). Uni environment variable sifatida saqlang. `StrictHostKeyChecking=no` qanday hujumga yo'l ochishini aniq ssenariy bilan tasvirlang. Yo'nalish: 2-bo'lim, "known_hosts".

5. **Forced command.** VM'da `/opt/app/deploy.sh` yozing: `SSH_ORIGINAL_COMMAND` dan SHA'ni oladi, formatini qat'iy tekshiradi, noto'g'ri bo'lsa rad etadi (hozircha faqat `echo`). `authorized_keys` da kalitni `restrict,command=...` bilan cheklang. Tekshiring: `ssh deploy@host` (shell), `ssh deploy@host 'cat /etc/passwd'`, `ssh deploy@host '<sha>; id'`, `scp`, port forwarding. Har birida nima bo'ldi? Yo'nalish: 2-bo'lim, "Least-privilege deploy user va forced command".

### B. Avtomatik deploy

6. **Compose with SHA tag.** VM'dagi `/opt/app/compose.yaml`: image tag `${APP_TAG:?}` dan, `healthcheck` bilan, `APP_VERSION` ilovaga uzatiladi. `deploy.sh` ni to'ldiring: pull, `up -d --wait`, muvaffaqiyatli SHA'ni faylga yozish, oldingisini saqlash. `APP_TAG` siz `docker compose config` nima deydi? Private package uchun serverdagi registry login'ini qanday hal qilganingizni yozing. Yo'nalish: 3-bo'lim va 4-bo'lim, "Mexanizm va misol".

7. **Deploy job.** `ci.yml` ga `deploy-production` job'ini qo'shing: `build` dan keyin, faqat `main` da, `environment: production`, `concurrency` (`cancel-in-progress: false`), minimal `permissions`. Job SSH kalit va `known_hosts` ni sozlab, serverga faqat `github.sha` ni yuboradi. Merge qiling va `/version` yangi SHA'ni qaytarishini tekshiring. Kalit fayliga qanday permission berdingiz va nima uchun? Yo'nalish: 2-bo'lim, "Workflow serverga SSH qilganda nima sodir bo'ladi" va "known_hosts".

8. **Smoke test.** Deploy'dan keyin tashqaridan `/healthz` va `/version` ni retry bilan tekshiradigan step qo'shing, `/version` aynan `github.sha` ga teng bo'lishi shart. Testni sinash: serverdagi `deploy.sh` ni vaqtincha hech narsa qilmaydigan qilib qo'ying va pipeline qizil bo'lishini ko'rsating. Faqat 200 kodni tekshiradigan smoke test bu holatda nima deyardi? Yo'nalish: 4-bo'lim, "Mexanizm va misol".

9. **Broken release.** Start'da yiqiladigan (yoki `/healthz` 500 qaytaradigan) versiyani merge qiling. Kuzating: `--wait` nima qaytardi, pipeline qayerda to'xtadi, sayt shu paytda ishlayaptimi (recreate strategiyasi)? Downtime'ni `while` sikli ichidagi `curl` bilan o'lchang. Bu natija keyingi guruh uchun motivatsiya. Yo'nalish: 4-bo'lim va 5-bo'lim, "Bu nima" (recreate).

10. **Exit code propagation.** `deploy.sh` ichida bir buyruq yiqilganda SSH va pipeline step'i ham yiqilishini isbotlang. Keyin skriptdan `set -e` ni olib tashlab (yoki `|| true` qo'shib) "deploy yiqildi, pipeline yashil" holatini hosil qiling, kuzating va qaytaring. Yana qaysi yo'llar bilan exit code yo'qolishi mumkin (pipe, `ssh` ichidagi `;`)? Yo'nalish: 2-bo'lim, "Workflow serverga SSH qilganda nima sodir bo'ladi".

11. **Manual rollback.** `rollback.yml` (`workflow_dispatch`, input: SHA, bo'sh bo'lsa serverdagi oldingi muvaffaqiyatli SHA) yozing. U oddiy deploy bilan bir xil yo'ldan o'tsin (o'sha `deploy.sh`, o'sha smoke test). `gh workflow run` bilan ishga tushirib vaqtini o'lchang. Registry'da mavjud bo'lmagan SHA bersangiz nima bo'ladi va sayt shu paytda qanday holatda qoladi? Yo'nalish: 7-bo'lim, "Mexanizm".

12. **Notifications.** Deploy natijasi haqida xabar yuboradigan step'lar qo'shing (Telegram bot yoki boshqa webhook): muvaffaqiyat va xato uchun alohida matn, ichida environment, qisqa SHA, actor va run havolasi. Token secret'da. Xabar step'ining o'zi yiqilsa deploy natijasi qanday ko'rinishi kerakligini hal qiling va asoslang. Yo'nalish: 7-bo'lim, "Xabarnomalar".

### C. Downtime'siz deploy

13. **Blue-green locally.** Ish mashinasida `compose.yaml`: `app-blue`, `app-green` va nginx. Qo'lda bajaring: blue jonli, green'ni yangi versiya bilan ko'tarish, ichki tarmoqdan tekshirish, upstream'ni almashtirish, `nginx -t`, reload. Almashtirish davomida boshqa terminalda `while` sikli bilan sekundiga bir necha so'rov yuborib, nechta xato bo'lganini sanang. Xuddi shu o'lchovni `nginx` ni restart qilib takrorlang va farqni izohlang. Yo'nalish: 5-bo'lim, "Mexanizm: almashtirish qayerda sodir bo'ladi".

14. **Blue-green script.** `deploy.sh` ni blue-green'ga o'tkazing: jonli rangni fayldan o'qish, bo'sh rangni yangi SHA bilan ko'tarish, health va versiya tekshiruvi, proxy'ni almashtirish, tashqi tekshiruv yiqilsa proxy'ni qaytarish, eski rangni to'xtatish. Lokal sinang: yaxshi versiya, keyin buzuq versiya (9-vazifadagi). Buzuq versiyada foydalanuvchi nechta xato ko'rdi? Yo'nalish: 5-bo'lim va 7-bo'lim, "Mexanizm".

15. **Graceful shutdown.** Ilovaga sun'iy sekin endpoint (`/slow`, 5 soniya) qo'shing. So'rov ketayotgan paytda rangni almashtiring va eski nusxani to'xtating. So'rov tugadimi? Ilovada `SIGTERM` ishlovchisi yo'q va bor holatlarni taqqoslang, `stop_grace_period` rolini izohlang. Yo'nalish: 5-bo'lim, "Tuzoq: graceful shutdown".

16. **Migration design.** Kodsiz, yozma: `users.name` ustunini `full_name` ga o'zgartirish kerak, ilova blue-green bilan deploy qilinadi. Expand/contract bo'yicha har deploy'da sxema va kod nima qilishini jadval qilib yozing. Har qadamdan keyin oldingi versiyaga rollback xavfsizmi? Migratsiya qadami pipeline'da qayerda turadi va nima uchun ilova start'ida emas? Yo'nalish: 6-bo'lim, "Mexanizm".

17. **Migration step.** Ixtiyoriy chuqurlashtirish, lekin tavsiya etiladi: compose'ga `postgres` qo'shing, ilovaga bitta jadval va migration tool. Deploy'ga migratsiya qadamini qo'shing (alohida bir martalik konteyner, ilova almashtirilishidan oldin). Bitta additive migratsiyani to'liq pipeline orqali chiqaring va rollback'dan keyin eski kod yangi sxema bilan ishlashini ko'rsating. Yo'nalish: 6-bo'lim, "Mexanizm".

### D. OIDC va mini-loyiha

18. **OIDC to AWS.** AWS'da GitHub OIDC identity provider va faqat `sts:GetCallerIdentity` uchun yetarli (yoki bitta S3 bucket'ni o'qish huquqli) IAM role yarating, trust policy `cicd-demo` reposi va `production` environment'iga toraytirilgan. Workflow'da `id-token: write` bilan role'ni olib `aws sts get-caller-identity` chiqaring. Repo'da hech qanday AWS kaliti yo'qligini ko'rsating. Keyin trust policy'ga mos kelmaydigan joydan (boshqa branch yoki environment'siz job) urinib ko'ring va xatoni yozing. Yo'nalish: 8-bo'lim, "Mexanizm".

19. **Mini-project: full pipeline.** Hammasini birlashtiring. PR: lint, test, image build (push'siz). `main` ga merge: test, build, GHCR'ga SHA tag bilan push, VM'ga blue-green deploy (approval bilan yoki avtomatik, tanlovingizni asoslang), tashqi smoke test, yiqilsa avtomatik qaytish, xabarnoma. `README.md` ga: pipeline grafi, har job'ning permissions va secret'lari jadvali, commit'dan production'gacha vaqt (lead time), 1-vazifadagi qo'l jarayoni bilan taqqos. Yo'nalish: butun dars.

20. **Rollback drill.** Uch ssenariyni ketma-ket o'tkazing va har biri uchun vaqt jadvalini (aniqlash, qaror, tiklanish) yozing: (a) health'i yiqiladigan versiya, avtomatik qaytish ishladimi; (b) health'i yashil, lekin `/version` dan boshqa endpoint buzuq versiya, uni kim va qanday aniqladi, qo'lda rollback qancha vaqt oldi; (c) rollback o'rniga roll forward (tuzatish commit'i), qaysi biri tezroq chiqdi. Xulosa: sizning pipeline'ingiz uchun time to restore qancha va uni nima cheklaydi? Yo'nalish: 7-bo'lim, "Bu nima" va "Mexanizm".

21. **Threat review.** Yakuniy pipeline uchun qisqa tahlil: hujumchi (a) repo'ga PR ocha oladi, (b) bitta uchinchi tomon action'ini buzgan, (c) deploy private kalitini qo'lga kiritgan, (d) VM'dagi `deploy` foydalanuvchisi bo'lib olgan. Har holatda u nima qila oladi, qaysi himoya chorasi uni to'xtatadi yoki cheklaydi, qanday qoldiq xavf bor? Yo'nalish: 1, 2 va 8-bo'limlar.

### Topshirish

Tayyor bo'lgach:
1. `cicd/05-auto-deploy/README.md` da 21 ta vazifaning har biri `## N. Title` sarlavhasi ostida; papkada `deploy.sh`, `compose.yaml`, proxy konfiguratsiyasi, `ci.yml` va `rollback.yml` nusxalari bor.
2. `main` ga merge qilingan commit qo'l tekkizmasdan production'ga chiqadi va `/version` shu SHA'ni qaytaradi.
3. Buzuq versiya foydalanuvchiga ko'rinmasdan qaytariladi, pipeline qizil bo'ladi, xabarnoma keladi.
4. `rollback.yml` ishlaydi va vaqti o'lchangan.
5. Repo'da, log'larda va ish papkasida hech qanday private key, token yoki `.env` yo'q. `actionlint` va `shellcheck` toza, `make check` toza (host'da).
6. Cloud resurslari o'chirilgan va buyruq bilan isbotlangan (chiqishlarni README oxiriga qo'shing): `aws ec2 describe-instances --filters "Name=tag:project,Values=devops-course" --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text` (bo'sh yoki faqat `terminated`), `aws ec2 describe-addresses --query 'Addresses[].PublicIp'` (bo'sh), `aws iam list-open-id-connect-providers` (GitHub provider yo'q), `aws iam get-role --role-name <role-name>` (`NoSuchEntity` xatosi).
7. GitHub tomoni tozalangan: `gh secret list --env production` va `gh variable list --env production` da deploy kaliti, host yozuvlari va xabarnoma token'i yo'q (`gh secret delete <NAME> --env production`). VM yo'q bo'lgach deploy kaliti baribir yaroqsiz, lekin secret o'chiriladi. Host'da `docker ps -a` da 13–15-vazifalardan konteyner qolmagan.
8. Menga xabar bering, repo havolasi va oxirgi muvaffaqiyatli hamda yiqilgan run havolalarini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Push-based va pull-based deploy farqi nima? Credential qaysi tomonda turadi?
- Nima uchun `StrictHostKeyChecking=no` va job ichidagi `ssh-keyscan` xavfli?
- Forced command va `restrict` deploy kalitini qanday cheklaydi? `docker` guruhidagi foydalanuvchi nima uchun baribir xavfli?
- Nima uchun `latest` bilan deploy qilinmaydi? SHA tag rollback'ni qanday soddalashtiradi?
- Smoke test nima uchun versiyani ham tekshirishi kerak?
- Recreate, rolling, blue-green va canary farqi nima? Blue-green'da rollback nima uchun tez?
- `nginx` reload va restart farqi nima?
- Migratsiya nima uchun orqaga mos bo'lishi kerak? Expand/contract qadamlarini ayting.
- Rollback va roll forward qachon qaysi biri tanlanadi?
- OIDC uzoq yashaydigan access key'ga nisbatan nimani yaxshilaydi? Trust policy'dagi `sub` sharti nima uchun muhim?
- Uzoqdagi skriptning xatosi pipeline step'igacha qanday yetib keladi va qaysi joylarda yo'qolishi mumkin?
- Shaxsiy SSH kalitingiz va deploy kaliti qayerda yashaydi, qaysi biri ikkinchi mashinada takrorlanadi?
- Liveness va readiness farqi nima? `--wait` siz `up -d` nimani kafolatlamaydi?
- Rollback nimani qaytara olmaydi?
- Vercel'dagi "merge qildim, chiqdi" va "Instant Rollback" ning har biri shu darsdagi qaysi mexanizmga to'g'ri keladi?
