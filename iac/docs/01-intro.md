# 1-dars: Infrastructure as Code, umumiy ma'lumot

Maqsad: Infrastructure as Code (IaC) qanday muammoni yechishini va asboblar qaysi o'qlar bo'yicha farqlanishini noldan tushunish: declarative va imperative, provisioning va configuration management, mutable va immutable, push va pull, state bor yoki yo'q. Infratuzilma deganda ilova ishlashi uchun kerak bo'lgan hamma narsa tushuniladi: serverlar, tarmoqlar, disklar, ularning ichidagi paketlar, foydalanuvchilar va sozlamalar. Cloud modulida muhitni konsol va CLI bilan qo'lda qurdingiz, cicd modulida ilovani pipeline orqali yetkazdingiz; infratuzilmaning o'zi hali qo'lda. Bu darsda IaC asbobi o'rnatilmaydi: avval oddiy bash skript va cloud-init bilan serverni tayyorlab, idempotency, dry-run va "o'chirish" muammolarini o'z qo'lingiz bilan his qilasiz. 2–3-darslardagi Ansible va 4–5-darslardagi Terraform aynan shu og'riqlarga javob.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–7 bo'limlar va A guruh vazifalari (tahlil), ikkinchi kun "Birga bajaramiz" va B guruh (bash bilan provisioning), uchinchi kun 8–9 bo'limlar, C guruh (cloud-init) va README'ni tartibga solish. Diqqatni quyidagilarga qarating: idempotency aniq nimani anglatadi, state nima uchun kerak va usiz asbob nimani bila olmaydi, provisioning bilan configuration management chegarasi, drift qayerdan paydo bo'ladi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ko'ring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi qiymatlar (IP, UID, paket versiyasi, vaqt) farq qiladi, bunday joylar `<...>` bilan belgilangan. Bu darsdagi tushunchalar butun modulning lug'ati: keyingi to'rt darsda "idempotent", "state", "drift" so'zlari izohsiz ishlatiladi.

## Laboratoriya

Barcha vazifalar Multipass VM ichida bajariladi. Skriptlar foydalanuvchi yaratadi, paket o'rnatadi, `/etc` ga yozadi, shuning uchun ularni host'da (Zorin yoki macOS) hech qachon ishga tushirmang. Multipass va `lab` VM `SETUP.md` bo'yicha allaqachon o'rnatilgan; bu darsda `lab` ishlatilmaydi, chunki skriptlarni toza mashinada sinash va mashinani tez-tez o'chirib qayta yaratish kerak. Dars o'z VM'larini yaratadi:

| VM | Qayerda kerak | O'lcham |
|----|---------------|---------|
| `iac1` | B guruh, bash skriptlar | 1 CPU, 1G RAM, 5G disk |
| `iac2` | 13-vazifa, ikkinchi host | 1 CPU, 1G RAM, 5G disk |
| `iac-ci` | 14 va 16-vazifalar, cloud-init | 1 CPU, 1G RAM, 5G disk |
| `iac-bad` | 15-vazifa, buzilgan cloud-init | 1 CPU, 1G RAM, 5G disk |
| `demo1`, `demo2` | "Birga bajaramiz" | 1 CPU, 1G RAM, 5G disk |

```
multipass launch 24.04 --name iac1 --cpus 1 --memory 1G --disk 5G
multipass transfer provision_v1.sh iac1:
multipass exec iac1 -- sudo bash provision_v1.sh
multipass shell iac1
```

Qatorma-qator: `launch` Ubuntu 24.04 image'idan VM yaratadi; `transfer` host'dagi faylni VM'dagi `ubuntu` foydalanuvchisining home papkasiga ko'chiradi (`iac1:` dan keyingi bo'sh yo'l home degani); `exec ... --` VM ichida bitta buyruq bajaradi, `--` dan keyingi hamma narsa VM'ga tegishli; `shell` interaktiv kirish.

Ish tartibi: skript faylini host'da, ish papkasida (`iac/01-intro/`) yozasiz, VM'ga ko'chirib o'sha yerda bajarasiz. Shunda fayl git'da qoladi, VM esa bir martalik.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | fayllarni yozish, `multipass`, `make check`, `git` |
| Dars VM'lari | `ubuntu@iac1:~$` | skriptlarni bajarish, natijani tekshirish, `cloud-init` buyruqlari |

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM'lar `x86_64` (`amd64`). ShellCheck: `sudo apt install shellcheck`. Host'dagi `bash` 5.x. |
| macOS (uy) | VM'lar `aarch64` (`arm64`). ShellCheck: `brew install shellcheck`. Host'dagi `/bin/bash` 3.2 (eski), standart shell zsh. Host'da ishlaydigan yagona skript `run_all.sh` (13-vazifa): uni `#!/usr/bin/env bash` bilan boshlang va bash 4+ imkoniyatlarini (associative array, `mapfile`) ishlatmang. Host'da `useradd`, `apt`, `systemctl` yo'q, lekin ular kerak ham emas: provisioning skriptlari faqat VM ichida ishlaydi. |

- Skriptlar faqat `apt` paketlarini o'rnatadi va binary yuklab olmaydi, shuning uchun arxitektura farqi natijaga ta'sir qilmaydi.
- Xotira: har VM 1G oladi. Mac'da RAM tor bo'lsa, bu dars davomida `multipass stop lab` qiling va bir vaqtda ikkitadan ortiq dars VM'ini ishlatmang.
- Bu dars oldingi laboratoriya holatiga tayanmaydi. Mashinani dars o'rtasida almashtirsangiz: ikkinchi mashinada `git pull`, VM'ni yuqoridagi `launch` buyrug'i bilan qayta yarating va skriptingizni bir marta ishga tushiring. Aynan shu "noldan tiklash" IaC'ning mohiyati, uni ataylab his qiling.
- A guruhdagi 1 va 3-vazifalar cloud modulidagi AWS muhitingizga tayanadi. AWS akkaunt mashinaga bog'liq emas, lekin CLI kalitlari har mashinada alohida sozlanadi. Bu darsda cloud resurs yaratilmaydi, faqat o'qiydigan buyruqlar (`describe-*`) ishlatiladi.

Tozalash: `multipass delete --purge iac1 iac2 iac-ci iac-bad demo1 demo2` (mavjudlarini yozing), keyin `multipass list` da faqat `lab` qolganini tekshiring.

---

## 1. Muammo: qo'lda boshqariladigan infratuzilma

### Manba sifatida nima bor

Cloud modulidagi muhitingizni eslang: VPC, subnet, security group, EC2, uning ichida Docker, foydalanuvchi, firewall, reverse proxy. Uni qayta qurish kerak bo'lsa, manba sifatida sizda nima bor? Xotira, `README` dagi eslatmalar va shell tarixi. Frontend'dagi o'xshash holat: loyihada `package.json` yo'q, kutubxonalar `node_modules` ga qo'lda ko'chirilgan va qaysi versiya nima uchun turganini hech kim bilmaydi. Qo'lda boshqariladigan infratuzilma aynan shunday. Bu uch muammoni tug'diradi.

### Drift

Drift bu real holatning kutilgan (hujjatlashtirilgan) holatdan asta-sekin uzoqlashishi. Manbalari:

- Tunda incident paytida konsoldan ochilgan security group qoidasi, keyin unutilgan.
- Bir serverda qo'lda yangilangan paket, ikkinchisida yo'q.
- "Vaqtincha" o'zgartirilgan config fayl.

Qo'lda boshqariladigan muhitda drift ko'rinmaydi, chunki solishtiradigan etalon yo'q. Ikki "bir xil" server oylar o'tib har xil bo'lib qoladi. Bunday, faqat o'ziga xos va qayta qurib bo'lmaydigan server **snowflake server** deyiladi (qor parchasi: ikkitasi bir xil bo'lmaydi). Belgisi: birida ishlagan deploy ikkinchisida sinadi.

### Misol: ikki "bir xil" serverni solishtirish

Ikki VM'da o'rnatilgan paketlar ro'yxatini olib, farqini ko'rish mumkin. `dpkg-query` paket bazasidan so'raydi, `diff` ikki faylni solishtiradi:

```
$ multipass exec demo1 -- dpkg-query -W -f '${Package}\n' > demo1.txt
$ multipass exec demo2 -- dpkg-query -W -f '${Package}\n' > demo2.txt
$ diff demo1.txt demo2.txt
<N>a<N+1>
> htop
```

`>` bilan boshlangan qator faqat ikkinchi faylda bor: `demo2` da kimdir `htop` o'rnatgan. Bu drift'ning eng sodda ko'rinishi. E'tibor bering: farqni topdik, lekin qaysi biri "to'g'ri" ekanini bilmaymiz, chunki etalon yo'q. IaC'da etalon bu koddagi ta'rif.

### Takrorlanuvchanlik (reproducibility)

Muhitni noldan qayta qurish kerak bo'ladigan holatlar: staging yaratish, region almashtirish, serverning buzilishi, yangi jamoa a'zosi uchun sandbox. Qo'lda bu soatlar va har safar biroz boshqacha natija. Kod bilan bu bitta buyruq va har safar bir xil natija. Siz buni shu kursning o'zida ko'rasiz: laboratoriya ikki mashinada, va holat mashinalar orasida ko'chmaydi, uni faqat koddan tiklash mumkin.

### Review va tarix

Konsoldagi o'zgarishni hech kim review qilmaydi, `git blame` ham yo'q. Infratuzilma kodda bo'lsa, unga dasturiy kod bilan bir xil jarayon qo'llanadi: pull request, review, CI tekshiruvi, tarix, revert. Bu IaC ning asosiy g'oyasi: infratuzilma ta'rifi versiyalanadigan matn fayllarida, uni asbob bajaradi, odam emas.

IaC nimani bermaydi: yomon arxitekturani tuzatmaydi va xatoni tezroq, hamma serverga birdan tarqatishga ham imkon beradi. Shuning uchun dry-run (o'zgarishni qo'llamasdan oldindan ko'rish) va review jarayonning majburiy qismi.

### Real ishda qachon kerak

- "Staging'da ishlaydi, prod'da yo'q": birinchi gumon drift.
- Server o'ldi va uni kim, qanday sozlaganini hech kim eslamaydi.
- Audit: "bu port qachon va kim tomonidan ochilgan?" degan savolga `git log` javob beradi, konsol tarixi esa cheklangan.

### Nima uchun shunday

Serverlar kam va uzoq yashagan davrda qo'lda sozlash arzon edi. Cloud bilan server yaratish API chaqiruviga aylandi: daqiqada o'nlab mashina paydo bo'ladi va yo'qoladi, odam bunga ulgurmaydi. API bor joyda uni chaqiradigan kod yozish tabiiy qadam. Muqobili, batafsil runbook (qadamma-qadam qo'llanma) yozish, ishlaydi, lekin hujjat va real holat orasida yana drift paydo bo'ladi, chunki hujjatni hech narsa bajarmaydi.

## 2. Declarative va imperative

### Ikki uslub

Imperative uslubda siz qadamlarni yozasiz: "buni qil, keyin buni". Declarative uslubda natijani yozasiz: "shunday bo'lsin", unga qanday yetishni asbob hal qiladi.

| | Imperative | Declarative |
|---|-----------|-------------|
| Nima yoziladi | qadamlar | yakuniy holat |
| Joriy holatni kim hisobga oladi | siz (`if` lar bilan) | asbob (joriy va kerakli holatni solishtiradi) |
| Qayta ishga tushirish | xavfli, agar maxsus yozilmagan bo'lsa | xavfsiz, farq bo'lmasa hech narsa qilmaydi |
| Misol | bash skript, `aws ec2 run-instances` | Terraform, Kubernetes manifest, `compose.yaml` |

Bu farq sizga frontend'dan tanish va o'xshatish haqiqiy. jQuery davrida DOM'ni qadamlar bilan o'zgartirgansiz (`append`, `remove`, `addClass`) va joriy holatni o'zingiz kuzatgansiz. React'da kerakli UI'ni tasvirlaysiz, joriy DOM bilan farqni hisoblash va minimal o'zgarishni qo'llash (reconciliation) runtime zimmasida. Declarative IaC asboblari infratuzilma uchun aynan shu ishni qiladi.

### Mexanizm: solishtirish sikli

Har declarative asbob ichida bir xil uch qadam bor:

1. Kerakli holatni o'qish (sizning fayllaringiz).
2. Real holatni o'qish (cloud API'dan yoki serverdan so'rash).
3. Farqni hisoblash va faqat farqni yo'qotadigan amallarni bajarish.

Farq bo'sh bo'lsa, amal ham bo'sh. Xavfsiz qayta ishga tushirish shundan kelib chiqadi.

### Misol

```
# imperative: a step
aws ec2 create-vpc --cidr-block 10.0.0.0/16
```

```
# declarative: desired end state (Terraform, lesson 4)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Birinchi buyruqni ikki marta ishlatsangiz ikkita VPC bo'ladi: buyruq "yarat" deydi va joriy holatga qaramaydi. Ikkinchi ta'rifni ikki marta qo'llasangiz bitta VPC qoladi, chunki asbob avval "bu VPC allaqachon bormi" degan savolga javob topadi va ikkinchi safar "o'zgarish yo'q" deydi.

Chegara qat'iy emas. Ansible playbook'i (2-dars) tartib bilan bajariladigan task'lar ro'yxati, ya'ni shakli imperative, lekin har task deklarativ: `state: present` "o'rnat" emas, "o'rnatilgan bo'lsin" degani. `Dockerfile` ham aralash: qadamlar ketma-ketligi, lekin natija (image) aniq va takrorlanadigan.

### Real ishda qachon kerak

- Asbob tanlashda: uzoq yashaydigan, ko'p marta qayta qo'llanadigan narsa uchun declarative; bir martalik migratsiya yoki tartibi muhim amal (bazani backup qil, keyin yangila) uchun imperative qadamlar o'rinli.
- Code review'da: declarative faylda diff "nima o'zgaradi" ni ko'rsatadi, skriptda esa "qaysi buyruq qo'shildi" ni, oqibatini o'zingiz hisoblaysiz.

### Nima uchun shunday

Declarative model joriy holatni hisobga olish yukini har skript muallifidan olib, bitta asbobga yuklaydi: tekshiruv mantig'i bir marta yoziladi va hamma foydalanadi. Narxi: asbob bilmaydigan holatni ifodalab bo'lmaydi va "aynan shu tartibda" degan talabni aytish qiyinroq. Shuning uchun deyarli har declarative asbobda imperative "qochish yo'li" bor (Ansible'da `command`, Terraform'da provisioner), va ulardan foydalanish idempotency'ni yana sizning zimmangizga qaytaradi.

## 3. Idempotency

### Ta'rif

Operatsiya idempotent bo'ladi, agar uni bir marta va ko'p marta bajarish natijasi bir xil bo'lsa. HTTP'dan tanish: `PUT /users/7` (shu holatga keltir) idempotent, `POST /users` (yangi yarat) idempotent emas. Tarmoq uzilganda `PUT` ni xotirjam qayta yuborasiz, `POST` ni esa yo'q. Provisioning'da ham xuddi shu: skript yarmida uzilsa, uni boshidan qayta ishga tushirish xavfsiz bo'lishi kerak.

### Misol: ikkinchi ishga tushirish

VM ichida, eng sodda buyruqlar:

```
ubuntu@demo1:~$ sudo useradd metrics; echo "exit=$?"
exit=0
ubuntu@demo1:~$ sudo useradd metrics; echo "exit=$?"
useradd: user 'metrics' already exists
exit=9
ubuntu@demo1:~$ echo "TZ=UTC" | sudo tee -a /etc/environment; echo "exit=$?"
TZ=UTC
exit=0
ubuntu@demo1:~$ echo "TZ=UTC" | sudo tee -a /etc/environment; echo "exit=$?"
TZ=UTC
exit=0
ubuntu@demo1:~$ grep -c '^TZ=UTC$' /etc/environment
2
```

Ikki xil buzilish ko'rinadi. `useradd` ikkinchi safar "baland ovozda" sinadi: xato matni va exit code `9` (exit code bu buyruq tugaganda qaytaradigan son, `0` muvaffaqiyat, `linux` 1-dars). `set -e` bilan yozilgan skript shu yerda to'xtaydi. `tee -a` (faylga qo'shib yozish) esa "jimgina" buziladi: exit code `0`, lekin faylda qator ikkita. Ikkinchi tur xavfliroq, chunki uni hech narsa bildirmaydi.

### Tekshir, keyin bajar

| Idempotent emas | Idempotent |
|-----------------|-----------|
| `useradd deploy` (ikkinchi safar xato) | `id -u deploy >/dev/null 2>&1 \|\| useradd deploy` |
| `echo "line" >> file` (har safar yangi qator) | `grep -qxF "line" file \|\| echo "line" >> file` |
| `mkdir /opt/app` | `mkdir -p /opt/app` |
| `ln -s a b` | `ln -sfn a b` |

`A || B` shell'da "A muvaffaqiyatsiz bo'lsa B ni bajar" degani. `grep -qxF`: `-q` hech narsa chop etmaydi (faqat exit code), `-x` butun qator mos kelishi kerak, `-F` matnni regex emas, oddiy satr deb oladi.

Idempotent bash yozish mumkin, lekin har qadam "tekshir, keyin bajar" juftligiga aylanadi va tekshiruvning to'g'riligi sizning zimmangizda. Masalan `id -u deploy` foydalanuvchi borligini tekshiradi, lekin uning shell'i, guruhlari va home papkasi kerakli holatda ekanini emas. IaC asboblari shu juftlikni har resurs turi uchun tayyor beradi (Ansible moduli, Terraform provider'i).

Idempotency ikki narsani beradi: skriptni yarmida uzilgandan keyin qayta ishga tushirish xavfsiz bo'ladi, va uni muntazam ishga tushirib drift'ni tuzatish mumkin bo'ladi. Ikkinchisi **convergence** deyiladi: har ishga tushirish tizimni kerakli holatga yaqinlashtiradi.

**Tuzoq: "xatosiz qayta ishga tushdi" idempotent degani emas.** Yuqoridagi `tee -a` xato bermadi, lekin faylni o'zgartirdi. Mezon: ikkinchi ishga tushirishda hech narsa o'zgarmasligi va asbob buni aniq aytishi (Ansible'da `changed=0`, Terraform'da `No changes`).

### Real ishda qachon kerak

- CI yoki cron'da takror ishlaydigan har qanday skript.
- 40 ta serverning 3 tasida amal uzilib qoldi: idempotent bo'lsa hammasida qayta ishga tushirasiz, bo'lmasa qaysi server qaysi qadamda qolganini qo'lda aniqlaysiz.

### Nima uchun shunday

Taqsimlangan tizimda "aniq bir marta bajarish" kafolatini berib bo'lmaydi: tarmoq uziladi, SSH sessiya tushadi, API javobi yo'qoladi. Kafolat berish mumkin bo'lgan narsa "kamida bir marta". Kamida bir marta bajarish xavfsiz bo'lishi uchun amalning o'zi takrorga chidamli bo'lishi kerak. Muqobili, tranzaksiya va rollback, ma'lumotlar bazasida bor, lekin operatsion tizim darajasida (paket, fayl, foydalanuvchi) yo'q.

## 4. Provisioning va configuration management

### Ikki savol

| | Provisioning | Configuration management |
|---|-------------|--------------------------|
| Savol | qanday resurslar mavjud bo'lsin? | resurs ichida nima bo'lsin? |
| Obyektlar | VPC, subnet, VM, disk, DNS yozuvi, bucket, IAM | paket, fayl, foydalanuvchi, servis, firewall qoidasi |
| Muloqot qiladi | cloud API bilan (HTTPS) | server bilan (SSH yoki agent) |
| Asboblar | Terraform, OpenTofu, Pulumi, CloudFormation | Ansible, Chef, Puppet, Salt |

Agent bu serverda doimiy ishlab turadigan va markaziy tizimdan buyruq oladigan kichik dastur.

### Mexanizm: nima uchun ikki xil asbob

Provisioning asbobi cloud API'ga so'rov yuboradi: "shunday VM yarat". U VM ichiga kirmaydi, VM hali mavjud ham emas. Uning qiyin ishi resurslar orasidagi bog'liqlik: subnet VPC'dan keyin, VM subnet'dan keyin yaratiladi, o'chirish esa teskari tartibda. Configuration management asbobi tayyor serverga ulanadi va ichidagi yuzlab mayda holatni tekshiradi: paket bormi, fayl mazmuni to'g'rimi, servis ishlayaptimi. Uning qiyin ishi har holat turi uchun "tekshir, keyin bajar" mantig'i.

Bu darsdagi laboratoriyada bo'linish shunday ko'rinadi: `multipass launch` provisioning (mashina paydo bo'ladi), `provision_v1.sh` configuration management (mashina ichi sozlanadi).

Asboblar chegaradan o'ta oladi: Ansible'da cloud modullari bor, Terraform'da `user_data` va provisioner'lar bor. Lekin har biri o'z sohasida kuchli. Terraform resurslarning hayot siklini state orqali kuzatadi, Ansible buni qilmaydi. Ansible server ichidagi mayda holatni modullar bilan boshqaradi, Terraform buni qilmaydi. Keng tarqalgan bo'linish: Terraform serverni yaratadi, Ansible (yoki cloud-init, yoki oldindan tayyorlangan image) uni sozlaydi. 5-darsda ikkalasini birlashtirasiz.

Uchinchi qatlam: ilovani yetkazish (deploy). Bu cicd modulida edi va odatda infratuzilma kodidan alohida, tezroq siklda yuradi.

### Real ishda qachon kerak

- Vazifa kelganda birinchi savol: "bu resursning o'zi haqidami yoki ichi haqidami?" Javob asbobni belgilaydi.
- Chegaradagi narsalar (security group va host firewall, DNS va `/etc/hosts`) uchun jamoa bitta egani tanlaydi, aks holda ikki asbob bir-birining ishini buzadi.

### Nima uchun shunday

Ikki soha tarixan alohida paydo bo'lgan: configuration management (CFEngine, Puppet, Chef) jismoniy serverlar davrida, provisioning asboblari cloud API'lar paydo bo'lgach. Hamma narsani bitta asbobga yig'ishga urinishlar bo'lgan, lekin ikki xil muloqot kanali (API va SSH) va ikki xil holat modeli bitta asbobni ikkala sohada ham o'rtacha qiladi.

## 5. Mutable va immutable infratuzilma

### Ikki model

- **Mutable** (o'zgaruvchan): server uzoq yashaydi, o'zgarishlar uning ustiga qo'llanadi (paket yangilanadi, config almashtiriladi). Ansible'ning klassik ishlatilishi. Kamchilik: har server o'z tarixiga ega, drift to'planadi, "bo'sh serverdan qurish" yo'li kam sinaladi.
- **Immutable** (o'zgarmas): server yaratilgandan keyin o'zgartirilmaydi. O'zgarish kerak bo'lsa yangi image quriladi (image bu tayyor disk nusxasi, undan istalgancha bir xil server ko'tariladi), yangi server undan ko'tariladi, eskisi o'chiriladi. Drift bo'lmaydi, rollback bu oldingi image'ga qaytish.

### Mexanizm

Docker modulida immutable modelni allaqachon ishlatgansiz: ishlab turgan konteynerga kirib paket o'rnatmaysiz, `Dockerfile` ni o'zgartirib yangi image qurasiz va konteynerni almashtirasiz. VM darajasida ham xuddi shu g'oya: Packer kabi asbob vaqtinchalik VM ko'taradi, uni skript yoki Ansible bilan sozlaydi, diskidan image (AWS'da AMI) oladi va VM'ni o'chiradi.

Bu darsda ikkala modelni his qilasiz. `iac1` ustida skriptni qayta-qayta ishlatish mutable yo'l. `iac-ci` ni cloud-init bilan ko'tarish va o'zgarish kerak bo'lganda uni o'chirib qayta yaratish immutable yo'lga yaqin.

Immutable model narxi: image qurish pipeline'i kerak, va holat (ma'lumotlar bazasi, yuklangan fayllar) serverdan tashqariga chiqarilgan bo'lishi kerak, aks holda server bilan birga o'chadi. Amalda aralash ishlatiladi: asosiy qatlam image'da (OS, Docker), o'zgaruvchan qism birinchi yuklanishda cloud-init yoki Ansible bilan.

### Real ishda qachon kerak

- Autoscaling: yangi server daqiqa ichida tayyor bo'lishi kerak, 10 daqiqalik sozlashga vaqt yo'q, demak tayyor image.
- Ma'lumotlar bazasi serveri: holati ichida, uni har o'zgarishda almashtirib bo'lmaydi, demak mutable va ehtiyotkor Ansible.

### Nima uchun shunday

Immutable model server yaratish arzon va tez bo'lgandagina mantiqiy, ya'ni cloud va konteynerlar davrida. U "o'zgarishni sinash" muammosini soddalashtiradi: sinovdan o'tgan image aynan o'zi prod'ga boradi, serverning oldingi tarixi natijaga ta'sir qilmaydi. Sizga tanish o'xshashi: lockfile bilan `npm ci` har safar toza `node_modules` quradi, mavjudini yamab chiqmaydi.

## 6. State

### Uchta bilim

Asbob "nimani o'zgartirish kerak" ni hisoblash uchun uchta narsani biladi yoki bilmaydi:

1. **Kerakli holat**: sizning kodingiz.
2. **Real holat**: API yoki serverdan o'qiladi.
3. **Oldin nimani o'zim yaratganman**: state. Bu asbobning xotirasi, odatda fayl.

### Mexanizm: uchinchisi bo'lmasa nima bo'ladi

State bo'lmasa asbob ikki savolga javob bera olmaydi.

Birinchisi: koddan olib tashlangan narsani o'chirish kerakmi? Serverda 600 ta paket bor, kodingizda 3 tasi yozilgan edi, endi 2 tasi. Qolgan 598 tasidan qaysi biri "avval siz so'ragan, endi kerak emas", qaysilari tizimniki? Real holatga qarab buni bilib bo'lmaydi. Terraform state'da "bu bucket'ni men yaratganman" yozuvini ko'radi va koddan o'chirilgan resursni o'chirishni rejalashtiradi. Ansible'da state yo'q: playbook'dan paket o'rnatish task'ini olib tashlasangiz paket serverda qoladi, uni o'chirish uchun `state: absent` deb aniq yozish kerak.

Ikkinchisi: koddagi nom bilan real resurs identifikatori (`aws_instance.web` va `i-0abc...`) qanday bog'lanadi.

### Misol: bash'da "yetim" resurs

```
ubuntu@demo1:~$ cat setup.sh
apt-get install -y jq tree
ubuntu@demo1:~$ sudo bash setup.sh >/dev/null && dpkg -s tree | grep Status
Status: install ok installed
ubuntu@demo1:~$ sed -i 's/ tree//' setup.sh && cat setup.sh
apt-get install -y jq
ubuntu@demo1:~$ sudo bash setup.sh >/dev/null && dpkg -s tree | grep Status
Status: install ok installed
```

Skriptdan `tree` olib tashlandi, skript xatosiz o'tdi, paket esa joyida: `Status: install ok installed`. Skript `tree` haqida hech narsa "eslamaydi". Lockfile bilan solishtiring: `package.json` dan qatorni o'chirib `npm install` qilsangiz paket `node_modules` dan ham o'chadi, chunki npm oldingi holatni `package-lock.json` da saqlagan. Lockfile bu yerda state rolini o'ynaydi.

| Yondashuv | Asboblar | Oqibat |
|-----------|----------|--------|
| State fayli asbobda | Terraform, OpenTofu, Pulumi | o'chirishni biladi; state'ni saqlash, qulflash va himoyalash kerak |
| State servis ichida | CloudFormation (stack) | saqlash tashvishi yo'q, faqat o'sha cloud |
| State yo'q, har safar real holatni tekshiradi | Ansible, bash | sodda; koddan olib tashlangan narsa "yetim" qoladi |

State narxi 4–5-darslarda: u secret'larni ochiq saqlaydi, yo'qolsa asbob resurslarni "tanimaydi", ikki kishi bir vaqtda yozsa buziladi.

### Real ishda qachon kerak

- "Koddan o'chirdim, nega hali ham turibdi?" degan savol: asbobda state yo'q.
- "Terraform bor resursni qaytadan yaratmoqchi": state yo'qolgan yoki resurs state'ga kiritilmagan.

### Nima uchun shunday

State'siz asbob sodda va uni buzib bo'lmaydi, lekin faqat "bor bo'lsin" ni ishonchli bajaradi. State'li asbob to'liq hayot siklini (yaratish, o'zgartirish, o'chirish) boshqaradi, evaziga state'ning o'zi himoya qilinadigan qimmatli faylga aylanadi. Cloud resurslari pul turadi va "yetim" qolsa hisob keladi, shuning uchun provisioning'da state deyarli majburiy; server ichidagi ortiqcha paket esa kam zarar, shuning uchun configuration management'da usiz yashash mumkin.

## 7. Push va pull

### Ikki yo'nalish

- **Push**: markaziy joydan (noutbuk, CI runner) buyruq nishonlarga yuboriladi. Ansible (SSH orqali), Terraform (API chaqiruvlari). Oddiy, agent kerak emas. O'zgarish faqat kimdir ishga tushirganda qo'llanadi, o'sha paytda o'chiq turgan server o'tkazib yuboriladi.
- **Pull**: har nishonda agent bor, u muntazam ravishda (masalan har 30 daqiqada) markazdan kerakli holatni olib o'zini moslaydi. Puppet agent, Chef client. Drift o'zi tuzaladi va yangi server o'zi sozlanadi; narxi agent va markaziy serverni boshqarish.

### Mexanizm va misol

Bu darsda push modelini qo'lda qurasiz: 13-vazifadagi `run_all.sh` host'dan har VM'ga faylni yuboradi va bajaradi. Bitta VM to'xtatilgan bo'lsa nima bo'lishini o'sha yerda ko'rasiz: push o'chiq nishonga yeta olmaydi va buni kimdir payqashi kerak.

Pull'ning eng sodda ko'rinishi cloud-init (8-bo'lim): server birinchi yuklanishda o'z sozlamasini o'zi oladi va qo'llaydi, hech kim unga ulanmaydi. Ansible'da `ansible-pull` rejimi ham bor (server git'dan playbook'ni o'zi tortadi). Kubernetes modulida GitOps pull modelining zamonaviy ko'rinishini ko'rasiz.

### Real ishda qachon kerak

- Kichik va o'rta park, CI'dan boshqariladi: push yetarli.
- Serverlar o'zi paydo bo'lib yo'qoladigan muhit (autoscaling) yoki tashqaridan SSH yopiq tarmoq: pull, chunki nishon o'zi tashqariga chiqadi.

### Nima uchun shunday

Push'da "kim, qachon, nimani qo'lladi" aniq va bitta joyda ko'rinadi, lekin markaz hamma nishonga kirish huquqiga (SSH kalitlari) ega bo'lishi kerak, bu xavfsizlik uchun katta nishon. Pull'da markaz hech kimga ulanmaydi, lekin "hozir hamma server yangi holatdami" degan savolga javob olish uchun agentlar hisobotini yig'ish kerak.

## 8. cloud-init

### Nima

cloud-init deyarli barcha cloud image'larda (shu jumladan Multipass ishlatadigan Ubuntu image'larida) oldindan o'rnatilgan dastur. U instans yaratilayotganda berilgan matnni (**user-data**) birinchi yuklanishda o'qiydi va bajaradi. `#cloud-config` qatori bilan boshlangan user-data YAML formatida bo'ladi. YAML bu JSON bilan bir xil ma'lumot tuzilmalarini (obyekt, ro'yxat, satr) qavssiz, chekinish (indentation) orqali yozadigan format: `kalit: qiymat` obyekt maydoni, `- element` ro'yxat elementi, chekinish faqat probel bilan.

### Mexanizm

1. Siz `multipass launch --cloud-init fayl.yaml` deysiz. Multipass faylni VM'ga virtual disk orqali uzatadi (AWS'da xuddi shu rolni metadata servisi o'ynaydi).
2. VM yuklanadi, systemd (init tizimi, `linux` 1-dars) cloud-init servislarini ishga tushiradi.
3. cloud-init user-data'ni o'qiydi va modullarni tartib bilan bajaradi: foydalanuvchilar, fayllar, paketlar, oxirida `runcmd`.
4. Tugagach `/var/lib/cloud/instance/` ostiga "bajarildi" belgilarini yozadi. Keyingi yuklanishlarda ko'pchilik modullar shu belgini ko'rib qayta ishlamaydi.

### Misol

Host'da `demo.yaml`:

```
#cloud-config
package_update: true
packages:
  - jq
groups:
  - ops
users:
  - default
  - name: metrics
    groups: ops
    shell: /bin/bash
write_files:
  - path: /etc/profile.d/lab.sh
    content: |
      export LAB_ENV=demo
    permissions: '0644'
runcmd:
  - touch /var/tmp/first-boot-done
```

Qatorma-qator: `package_update: true` paket ro'yxatini yangilaydi (`apt-get update`); `packages` o'rnatiladigan paketlar; `groups` yaratiladigan guruhlar; `users` foydalanuvchilar, `default` image'ning standart foydalanuvchisi (`ubuntu`); `write_files` berilgan mazmunli fayl yaratadi, `|` belgisi ko'p qatorli matnni boshlaydi, `permissions` qo'shtirnoqda, chunki YAML `0644` ni son deb o'qib yuborishi mumkin; `runcmd` eng oxirida bajariladigan buyruqlar.

```
$ multipass launch 24.04 --name demo2 --cpus 1 --memory 1G --disk 5G --cloud-init demo.yaml
Launched: demo2
$ multipass exec demo2 -- cloud-init status --wait
status: done
$ multipass exec demo2 -- id metrics
uid=1001(metrics) gid=1002(metrics) groups=1002(metrics),1001(ops)
$ multipass exec demo2 -- cat /etc/profile.d/lab.sh
export LAB_ENV=demo
$ multipass exec demo2 -- ls /var/tmp/first-boot-done
/var/tmp/first-boot-done
```

`cloud-init status --wait` cloud-init tugaguncha kutadi va yakuniy holatni chop etadi: `done` hammasi o'tdi, `error` biror modul sindi, `running` hali ishlayapti (`--wait` siz so'ralganda). `id metrics` foydalanuvchi va uning `ops` guruhiga a'zoligini ko'rsatadi (UID va GID raqamlari sizda boshqacha bo'lishi mumkin). Oxirgi ikki buyruq fayl va `runcmd` natijasini tasdiqlaydi.

Tekshirish va diagnostika (VM ichida):

| Buyruq yoki fayl | Nima beradi |
|------------------|-------------|
| `cloud-init status --long` | holat va xato bo'lsa tafsiloti |
| `cloud-init schema --config-file <fayl>` | faylni sxema bo'yicha tekshiradi, VM yaratishdan oldin |
| `/var/log/cloud-init.log` | cloud-init'ning o'z jurnali, qaysi modul qachon ishlagani |
| `/var/log/cloud-init-output.log` | modullar va `runcmd` buyruqlarining chiqishi (masalan `apt` matni) |

Sxemani tekshirish uchun faylni mavjud VM'ga ko'chiring: `multipass transfer demo.yaml demo2:` va `multipass exec demo2 -- cloud-init schema --config-file demo.yaml`. Bu ikkala host'da bir xil ishlaydi, chunki `cloud-init` buyrug'i VM ichida.

Cheklovi: ko'pchilik modullar instans umrida bir marta ishlaydi. Faylni keyin o'zgartirsangiz ishlab turgan serverga ta'sir qilmaydi. Shuning uchun cloud-init "day 0" asbobi: serverni boshqaruvga yaroqli holatga keltiradi (foydalanuvchi, SSH kalit, bazaviy paketlar), keyingi o'zgarishlar boshqa asbob yoki yangi server orqali.

**Tuzoq: `users:` ro'yxatida `default` yozilmasa image'ning standart foydalanuvchisi (`ubuntu`) yaratilmaydi.** Multipass'ning `shell` va `exec` buyruqlari aynan shu foydalanuvchi bilan ishlaydi.

### Real ishda qachon kerak

- Har yangi EC2 uchun deploy foydalanuvchisi va SSH kaliti: Terraform `user_data` maydoniga cloud-init faylini beradi (4-dars).
- 2 va 3-darslarda Ansible nishonlarini tayyorlash: VM'ga SSH kalitni aynan cloud-init joylaydi.

### Nima uchun shunday

Yangi serverga hali hech kim ulana olmaydi: foydalanuvchi ham, kalit ham yo'q. Bu "tovuq va tuxum" muammosini serverning o'zi ichkaridan yechishi kerak, cloud-init shu uchun image ichida turadi. U bir marta ishlaydi, chunki maqsadi boshlang'ich holat, doimiy boshqaruv emas; har yuklanishda foydalanuvchi va fayllarni qayta yozish qo'lda kiritilgan qonuniy o'zgarishlarni o'chirib yuborar edi.

## 9. Asboblar xaritasi va tanlash

### Xarita

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

HCL bu HashiCorp'ning konfiguratsiya tili (4-dars), Jinja2 bu Python dunyosidagi template tili (2-dars), DSL bu bitta soha uchun yaratilgan maxsus til.

Sizning fon uchun eslatma: Pulumi TypeScript'da yozilgani uchun jozibali ko'rinadi. Bu kursda Terraform tanlangan, chunki bozorda eng ko'p uchraydi va state, plan, provider tushunchalari Pulumi'da ham deyarli bir xil.

### Qaysi asbob qachon

| Vazifa | To'g'ri keladigan asbob |
|--------|--------------------------|
| Cloud resurslarini yaratish va o'chirish | Terraform/OpenTofu (yoki Pulumi, CloudFormation) |
| Yangi serverni boshqaruvga tayyorlash (foydalanuvchi, kalit) | cloud-init |
| Uzoq yashaydigan serverlar konfiguratsiyasi, bir nechta serverda tartibli amal | Ansible |
| Tayyor image (immutable model) | Packer, ichida Ansible yoki shell |
| Bir martalik tezkor amal 20 ta serverda | Ansible ad-hoc |
| Konteyner ichidagi narsa | Dockerfile, bu yerga Ansible kerak emas |

### Terraform litsenziyasi va OpenTofu

- 2023-yil avgustda HashiCorp Terraform (va boshqa mahsulotlari) litsenziyasini kelgusi relizlar uchun MPL 2.0 dan Business Source License (BUSL) 1.1 ga o'zgartirishini e'lon qildi. 1.5.x versiyalar MPL 2.0 ostida qoldi.
- BUSL OSI ta'rifi bo'yicha open source emas ("source-available"). Kod ochiq, lekin litsenziyada HashiCorp bilan raqobatlashuvchi mahsulot taklif qilishni cheklovchi shart bor. O'z kompaniyangiz infratuzilmasini Terraform bilan boshqarish bu cheklovga tushmaydi, lekin aniq holat uchun litsenziya matni va HashiCorp FAQ'ini o'zingiz o'qing, bu dars yuridik maslahat emas.
- OpenTofu bu Terraform'ning MPL 2.0 davridagi kodidan olingan fork (mustaqil davom ettirilgan nusxa), Linux Foundation boshqaruvida, MPL 2.0 litsenziyasida. CLI `tofu`, buyruqlar va HCL asosiy qismda mos (`tofu init`, `tofu plan`).
- Ikki loyiha fork'dan keyin mustaqil rivojlanmoqda: har birida ikkinchisida yo'q imkoniyatlar bor (masalan OpenTofu'da state shifrlash). Yangi versiyalarda yozilgan kod va state ikkinchisiga har doim ham o'tavermaydi.

Bu kursda buyruqlar `terraform` deb yoziladi. OpenTofu tanlasangiz `tofu` deb o'qing; farq qiladigan joylar darsda aytiladi.

### Real ishda qachon kerak

- Yangi loyihada "nimani nima bilan boshqaramiz" jadvali birinchi haftada tuziladi va keyin kam o'zgaradi.
- Vakansiya matnlarida "Terraform + Ansible" juftligi shu bo'linishni anglatadi: biri resurslar, ikkinchisi ularning ichi.

### Nima uchun shunday

Bitta universal asbob yo'q, chunki o'qlar (API yoki SSH, state bor yoki yo'q, push yoki pull) bir-biriga zid talablar qo'yadi. Asboblar xilma-xilligi tarixiy tasodif emas, har biri shu o'qlarda boshqa nuqtani tanlagan. Amaliy xulosa: asbobni o'rganishdan oldin uning shu o'qlardagi o'rnini aniqlang, shunda nimani kutish va nimani kutmaslikni bilasiz.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Infrastructure as Code (IaC) | infratuzilma ta'rifini versiyalanadigan matn fayllarida saqlash va uni asbob orqali qo'llash |
| Drift | real holatning koddagi yoki kutilgan holatdan uzoqlashishi |
| Snowflake server | qo'lda sozlangan, o'ziga xos va qayta qurib bo'lmaydigan server |
| Reproducibility | muhitni noldan bir xil natija bilan qayta qurish imkoniyati |
| Imperative | qadamlar ketma-ketligini yozish uslubi |
| Declarative | yakuniy holatni yozish uslubi, yo'lni asbob topadi |
| Idempotency | amalni bir marta va ko'p marta bajarish natijasi bir xil bo'lishi |
| Convergence | har ishga tushirishda tizimni kerakli holatga yaqinlashtirish |
| Dry-run | o'zgarishni qo'llamasdan nima o'zgarishini ko'rsatish (Ansible'da check mode, Terraform'da `plan`) |
| Provisioning | resurslarning o'zini yaratish va o'chirish (VM, tarmoq, disk) |
| Configuration management | mavjud server ichidagi holatni boshqarish (paket, fayl, servis) |
| Mutable infratuzilma | server uzoq yashaydi va ustidan o'zgartiriladi |
| Immutable infratuzilma | server o'zgartirilmaydi, yangi image'dan almashtiriladi |
| Image | tayyor disk nusxasi, undan bir xil serverlar ko'tariladi |
| State | asbob o'zi yaratgan resurslar haqida saqlaydigan yozuv |
| Push | markaz nishonlarga ulanib o'zgarishni yuboradi |
| Pull | nishondagi agent kerakli holatni markazdan o'zi oladi |
| Agent | nishonda doimiy ishlaydigan, markazdan buyruq oladigan dastur |
| cloud-init | image ichidagi, birinchi yuklanishda user-data'ni bajaradigan dastur |
| User-data | instans yaratilayotganda unga beriladigan boshlang'ich sozlama matni |
| YAML | chekinishga asoslangan ma'lumot formati, JSON'ning odam o'qishi uchun qulay shakli |
| Fork | loyiha kodidan olingan va mustaqil rivojlanadigan nusxa |

## Tuzoqlar

- IaC bilan yaratilgan resursni konsoldan "tezgina" o'zgartirish. Keyingi qo'llash uni qaytarib yuboradi yoki kutilmagan diff chiqadi. O'zgarish faqat kod orqali.
- Idempotent bo'lmagan skriptni cron yoki CI'da takror ishlatish: `>>` bilan config fayl har safar uzayadi, bir kun servis ishga tushmay qoladi.
- "Skript xatosiz o'tdi" ni "server kerakli holatda" deb qabul qilish. Tekshiruv faqat siz yozgan narsani tekshiradi, ortiqcha narsalarni (qo'lda qo'shilgan foydalanuvchi, ochilgan port) ko'rmaydi.
- cloud-init faylini o'zgartirib, ishlab turgan server ham o'zgaradi deb kutish. U birinchi yuklanishda ishlaydi.
- `cloud-init status --wait` ni kutmasdan tekshirishni boshlash: paketlar hali o'rnatilayotgan bo'ladi va "yo'q" degan noto'g'ri xulosa chiqadi.
- State'siz asbobda (Ansible, bash) koddan qatorni o'chirish resursni o'chiradi deb o'ylash. Resurs qoladi.
- Bitta asbob bilan hamma narsani qilishga urinish: Terraform provisioner'lari bilan server sozlash yoki Ansible bilan butun cloud hayot siklini yuritish. Ishlaydi, lekin har biri o'z sohasidan tashqarida mo'rt.
- Secret'ni IaC kodiga yoki user-data'ga ochiq yozish. User-data instans ichidan o'qiladi, repo tarixidan esa o'chmaydi.
- Review'siz qo'llash. IaC xatoni ham avtomatlashtiradi: bitta noto'g'ri qator hamma muhitga bir necha soniyada tarqaladi.
- Provisioning skriptini host'da ishga tushirish. Zorin'da u ish kompyuteringizga foydalanuvchi va paket qo'shadi, macOS'da esa `useradd` va `apt` yo'qligi sababli birinchi qatorda sinadi. Skriptlar faqat VM ichida.
- Host skriptida (`run_all.sh`) faqat Linux'da ishlaydigan narsaga tayanish: macOS'da `sed -i` boshqacha, `grep -P` yo'q, `/bin/bash` 3.2.

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

## Birga bajaramiz

Bitta kichik holatni uch yo'l bilan hosil qilamiz: sodda skript, idempotent skript, cloud-init. Kerakli holat (vazifalardagidan boshqa): `ops` guruhi mavjud; `/srv/reports` papkasi, guruhi `ops`, mode `2775`; `/etc/environment` da `LAB_ENV=demo` qatori aynan bitta. Fayllar host'da vaqtinchalik papkada yoziladi, VM `demo1`.

1. VM yarating va toza ekanini tekshiring:

```
$ multipass launch 24.04 --name demo1 --cpus 1 --memory 1G --disk 5G
Launched: demo1
$ multipass exec demo1 -- getent group ops; echo "exit=$?"
exit=2
```

`getent group ops` guruhlar bazasidan `ops` ni so'raydi. Chiqish bo'sh va exit code `2`: bunday guruh yo'q.

2. Sodda variant, host'da `naive.sh`:

```
#!/usr/bin/env bash
set -euo pipefail
groupadd ops
mkdir /srv/reports
chgrp ops /srv/reports
chmod 2775 /srv/reports
echo "LAB_ENV=demo" >> /etc/environment
```

`set -euo pipefail`: `-e` birinchi xatoda to'xta, `-u` e'lon qilinmagan o'zgaruvchi xato, `pipefail` pipe ichidagi xato ham hisobga olinadi (`linux` moduli, bash skriptlar darsi).

```
$ multipass transfer naive.sh demo1:
$ multipass exec demo1 -- sudo bash naive.sh; echo "exit=$?"
exit=0
$ multipass exec demo1 -- sudo bash naive.sh; echo "exit=$?"
groupadd: group 'ops' already exists
exit=9
```

Birinchi ishga tushirish toza. Ikkinchisi birinchi qatorda sindi va `set -e` tufayli to'xtadi. Bu yerda yashirin xavf bor: agar birinchi ishga tushirish `chgrp` dan oldin uzilganida, qayta ishga tushirish `groupadd` da sinardi va papka hech qachon to'g'ri guruhga o'tmasdi. Skript "yarim holat" dan chiqa olmaydi.

3. Idempotent variant, `safe.sh`. Har qadam avval tekshiradi:

```
#!/usr/bin/env bash
set -euo pipefail
getent group ops >/dev/null || groupadd ops
install -d -g ops -m 2775 /srv/reports
grep -qxF "LAB_ENV=demo" /etc/environment || echo "LAB_ENV=demo" >> /etc/environment
```

`install -d` papkani yaratadi va egasi, guruhi, mode'ini berilgan qiymatga keltiradi, papka mavjud bo'lsa ham. Bu "tekshir, keyin bajar" ni bitta buyruq ichiga olgan asbobga misol.

```
$ multipass transfer safe.sh demo1:
$ multipass exec demo1 -- sudo bash safe.sh; echo "exit=$?"
exit=0
$ multipass exec demo1 -- sudo bash safe.sh; echo "exit=$?"
exit=0
$ multipass exec demo1 -- grep -c '^LAB_ENV=demo$' /etc/environment
2
```

Skript ikki marta xatosiz o'tdi, lekin qator ikkita. Sabab skriptda emas: bittasi 2-qadamdagi `naive.sh` dan qolgan. `safe.sh` "kamida bitta bor" ni tekshiradi, "aynan bitta" ni emas. Bu darsning muhim kuzatuvi: tekshiruv faqat siz o'ylagan holatni ko'radi, oldingi tarix qoldirgan holatni emas.

4. Drift yarating va skript uni tuzatadimi, ko'ring:

```
$ multipass exec demo1 -- sudo chmod 0700 /srv/reports
$ multipass exec demo1 -- sudo bash safe.sh
$ multipass exec demo1 -- stat -c '%a %G' /srv/reports
2775 ops
$ multipass exec demo1 -- sudo touch /srv/reports/extra.txt
$ multipass exec demo1 -- sudo bash safe.sh
$ multipass exec demo1 -- ls /srv/reports
extra.txt
```

`stat -c '%a %G'` mode va guruh nomini chop etadi: mode drift'i tuzaldi, chunki `install -d` har safar mode'ni qo'yadi. Ortiqcha fayl esa joyida: skript u haqida hech narsa bilmaydi. Yana bir kamchilik: skript nimani o'zgartirganini aytmadi, ikkala ishga tushirish ham jim. 9-vazifada aynan shu hisobotni o'zingiz qo'shasiz.

5. Xuddi shu holat cloud-init bilan, `ops.yaml`:

```
#cloud-config
groups:
  - ops
write_files:
  - path: /etc/environment
    content: |
      LAB_ENV=demo
    append: true
runcmd:
  - install -d -g ops -m 2775 /srv/reports
```

```
$ multipass launch 24.04 --name demo2 --cpus 1 --memory 1G --disk 5G --cloud-init ops.yaml
Launched: demo2
$ multipass exec demo2 -- cloud-init status --wait
status: done
$ multipass exec demo2 -- stat -c '%a %G' /srv/reports
2775 ops
$ multipass exec demo2 -- grep -c '^LAB_ENV=demo$' /etc/environment
1
```

Toza mashinada natija to'g'ri va qator bitta, chunki cloud-init bir marta ishladi. Guruh uchun tayyor modul bor (`groups`), papka uchun esa `runcmd` ga, ya'ni yana shell'ga tushdik: declarative asbobda modul yetmagan joyda imperative qochish yo'li.

6. Xulosa va tozalash. `demo1` ning tarixi bor (ikki skript, drift, ortiqcha fayl), `demo2` toza tug'ilgan. Ikkalasi "kerakli holat" tekshiruvidan o'tadi, lekin bir xil emas: bu mutable va immutable farqining kichik modeli.

```
$ multipass delete --purge demo1 demo2
$ multipass list
```

## Vazifalar

Ish papkasi: `iac/01-intro/` (`make new m=iac n=01 name=intro` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`provision_v1.sh`, `provision_v2.sh`, `run_all.sh`, `cloud-init.yaml`) shu papkada saqlanadi. Provisioning skriptlari faqat VM ichida bajariladi; host'da faqat `run_all.sh` ishlaydi va u ikkala mashinada (Zorin bash 5, macOS bash 3.2) ishlashi kerak.

### A. Tahlil

1. **Manual build inventory.** Cloud modulida qo'lda qurgan muhitingizni eslatmalarga qaramasdan, xotiradan ro'yxat qiling: har resurs va uning muhim parametrlari (CIDR, portlar, instans tipi, server ichidagi paketlar va fayllar). Keyin eslatmalaringiz va AWS CLI chiqishi bilan solishtiring. Nimani unutdingiz yoki noto'g'ri esladingiz? Xuddi shu muhitni ertaga qayta qurish qancha vaqt olardi? Yo'nalish: 1-bo'lim, "Manba sifatida nima bor" va "Takrorlanuvchanlik".

2. **Declarative or imperative.** Quyidagilarning har birini declarative, imperative yoki aralash deb tasniflang va bir gap bilan asoslang: `Dockerfile`, `compose.yaml`, `package.json` dagi `dependencies`, `package.json` dagi `scripts`, SQL migratsiya fayli, GitHub Actions workflow, `crontab` yozuvi, `aws ec2 run-instances` buyrug'i, CSS, `git rebase` buyruqlari ketma-ketligi. Yo'nalish: 2-bo'lim, "Ikki uslub".

3. **Provisioning or configuration.** Cloud modulidagi ro'yxatingizni (1-vazifa) ikki ustunga ajrating: provisioning va configuration management. Chegarada turgan kamida ikkita narsani toping (masalan security group va host firewall) va qaysi asbob zimmasiga berishni asoslang. Yo'nalish: 4-bo'lim, "Ikki savol".

4. **Mutable vs immutable.** Docker modulidagi tajribangizga tayanib yozing: ishlab turgan konteynerga `docker exec` bilan kirib tuzatish nima uchun yomon amaliyot? Xuddi shu mantiqni EC2 serverga qo'llang: immutable modelga o'tish uchun app serveringizda nima o'zgarishi kerak (holat qayerda saqlanadi, image qanday quriladi)? Yo'nalish: 5-bo'lim, "Mexanizm".

5. **Tool selection.** Har holat uchun asbob (yoki asboblar juftligi) tanlang va asoslang: (a) 3 ta muhit uchun bir xil VPC va serverlar; (b) 40 ta mavjud serverda `sshd` sozlamasini o'zgartirish; (c) autoscaling group uchun tayyor AMI; (d) yangi EC2 birinchi yuklanishda deploy foydalanuvchisiga ega bo'lishi; (e) barcha serverlarda hozir qaysi kernel versiyasi turganini bilish. Yo'nalish: 9-bo'lim, "Qaysi asbob qachon".

6. **License check.** `hashicorp/terraform` va `opentofu/opentofu` GitHub repolaridagi `LICENSE` fayllarini oching. Har biri qaysi litsenziya? Terraform litsenziyasidagi "Additional Use Grant" bandini toping va o'z so'zingiz bilan yozing: nima ruxsat etiladi, nima cheklanadi, "Change Date" va "Change License" nimani anglatadi. Yo'nalish: 9-bo'lim, "Terraform litsenziyasi va OpenTofu".

### B. Bash bilan provisioning

7. **Naive script.** `provision_v1.sh` yozing (`set -euo pipefail` bilan), u `iac1` VM'da quyidagi holatni hosil qilsin: `deploy` foydalanuvchisi; `/opt/app` papkasi, egasi `deploy`; `nginx` va `curl` paketlari; `/etc/motd` oxirida `Managed by provision script` qatori; `/opt/app/app.env` fayli, ichida `APP_ENV=dev`, mode `0640`. Eng sodda buyruqlar bilan yozing, hech qanday tekshiruvsiz. VM'da ikki marta ishga tushiring. Ikkinchi ishga tushirishda nima sindi, qaysi qadamlar "jimgina" noto'g'ri ishladi? Yo'nalish: 3-bo'lim, "Misol: ikkinchi ishga tushirish".

8. **Idempotent script.** `provision_v2.sh`: xuddi shu yakuniy holat, lekin har qadam "tekshir, keyin bajar" shaklida. Toza holatdan boshlash uchun `iac1` ni o'chirib qayta yarating. Uch marta ketma-ket ishga tushiring: har safar exit code `0`, `/etc/motd` da qator bitta. Har qadam uchun tekshiruv aynan nimani tekshirishini va nimani tekshirmasligini yozing. Yo'nalish: 3-bo'lim, "Tekshir, keyin bajar"; "Birga bajaramiz" 3-qadam.

9. **Changed reporting.** `provision_v2.sh` ga hisobot qo'shing: har qadam `changed` yoki `ok` chop etsin, oxirida jami (`ok=N changed=M`). Toza VM'da birinchi ishga tushirish `changed=5` atrofida, ikkinchisi `changed=0` bo'lsin. Buning uchun qancha qo'shimcha kod yozdingiz? Yo'nalish: 3-bo'lim, "Tuzoq" va "Birga bajaramiz" 4-qadam.

10. **Drift repair.** VM'da qo'lda drift yarating: `/opt/app` egasini `root` ga o'zgartiring, `app.env` mode'ini `0644` qiling, `app.env` ichidagi qiymatni `APP_ENV=prod` ga almashtiring, `deploy` ning shell'ini `/bin/sh` qiling, `htop` paketini o'rnating. Skriptni qayta ishga tushiring. Qaysi drift tuzaldi, qaysi biri sezilmadi? Sezilmaganlarini tuzatish uchun skriptga nima qo'shish kerak bo'lardi? Yo'nalish: 1-bo'lim, "Drift"; "Birga bajaramiz" 4-qadam.

11. **Dry run.** Skriptga `--check` flag'ini qo'shing: hech narsani o'zgartirmasdan, nima o'zgarishini chop etsin. Yuqoridagi drift'lardan birini qayta yaratib sinang. Bu flag har qadamda qanday qo'shimcha tarmoqlanishni talab qildi? Yo'nalish: 1-bo'lim, "Review va tarix" (dry-run ta'rifi) va Atamalar.

12. **Removal problem.** Talab o'zgardi: `curl` paketi endi kerak emas va `/opt/app/app.env` o'chirilishi kerak. Skriptdan tegishli qatorlarni shunchaki olib tashlasangiz serverda nima bo'ladi? Buni to'g'ri hal qilish uchun skript nimani "eslab qolishi" kerak? 6-bo'limdagi state tushunchasi bilan bog'lang. Yo'nalish: 6-bo'lim, "Misol: bash'da yetim resurs".

13. **Second host.** Ikkinchi VM (`iac2`) yarating. `provision_v2.sh` ni ikkala VM'da ketma-ket ishga tushiradigan `run_all.sh` yozing (host'da ishlaydi, ichida `multipass transfer` va `multipass exec`; `#!/usr/bin/env bash`, macOS'dagi bash 3.2 da ham ishlashi kerak). `iac1` ni `multipass stop` qilib ishga tushiring: skript nima qildi, `iac2` ga yetib bordimi? Har host uchun natijani alohida ko'rsatadigan xulosa chiqaring. Yo'nalish: 7-bo'lim, "Mexanizm va misol"; Laboratoriya jadvalidagi macOS qatori.

### C. cloud-init

14. **cloud-init file.** 7-vazifadagi yakuniy holatni `cloud-init.yaml` (`#cloud-config`) bilan ifodalang: `users`, `packages`, `write_files`, kerak bo'lsa `runcmd`. Yangi VM'ni (`iac-ci`) `--cloud-init` bilan ko'taring. `cloud-init status --wait` va `/var/log/cloud-init-output.log` orqali tugaganini tekshiring, keyin har talabni qo'lda tasdiqlang. Bash variantiga nisbatan necha qator? Yo'nalish: 8-bo'lim, "Misol".

15. **cloud-init schema error.** Faylda kalit nomini ataylab buzing (masalan `packages` o'rniga `pakages`) va VM ichida `cloud-init schema --config-file` bilan tekshiring (faylni `multipass transfer` bilan `iac-ci` ga ko'chiring). Keyin shu buzilgan fayl bilan yangi VM (`iac-bad`) ko'taring: VM ishga tushdimi, paketlar o'rnatildimi, `cloud-init status --long` nima deydi? Xato qanchalik "baland ovozda" bildirildi? Buzilgan nusxani alohida faylda saqlang, `cloud-init.yaml` to'g'ri holatda qolsin. Yo'nalish: 8-bo'lim, "Tekshirish va diagnostika" jadvali.

16. **cloud-init runs once.** Ishlab turgan VM uchun `cloud-init.yaml` ga yangi paket qo'shdingiz deylik. Uni VM'ga qanday qo'llaysiz? `multipass restart` dan keyin `runcmd` qayta ishladimi, buni qaysi log yoki fayl orqali isbotladingiz? cloud-init modullarining ishlash chastotasi (per-instance, per-boot) haqida hujjatdan topib yozing. Yo'nalish: 8-bo'lim, "Mexanizm" 4-band va Manbalardagi modullar sahifasi.

17. **Pain summary.** Jadval tuzing. Qatorlar: idempotency, dry-run, diff ko'rsatish, bir nechta host, qisman muvaffaqiyatsizlik, olib tashlash (removal), secret'lar, xatoni o'qish qulayligi. Ustunlar: bash, cloud-init. Har katakka o'z tajribangizdan bir jumla. Bu jadvalga 2-dars va 4-dars oxirida Ansible va Terraform ustunlarini qo'shasiz. Yo'nalish: butun dars, ayniqsa 3, 6 va 8-bo'limlar.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza (skriptlar ShellCheck'dan o'tadi; ShellCheck o'rnatilishi Laboratoriya jadvalida).
2. `provision_v1.sh`, `provision_v2.sh`, `run_all.sh`, `cloud-init.yaml` ish papkasida. Fayllarda parol, kalit yoki IP manzil yo'q.
3. Dars VM'lari o'chirilgan: `multipass list` da faqat `lab` qolgan. Darsni ikkala mashinada bajargan bo'lsangiz, ikkalasida ham tekshiring.
4. Menga xabar bering, `README.md` va fayllarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Drift nima va qo'lda boshqariladigan muhitda nima uchun uni payqash qiyin?
- Idempotent operatsiya nima? "Ikkinchi marta xatosiz ishladi" nima uchun yetarli mezon emas?
- Declarative asbob joriy holatni hisobga olishni kimning zimmasiga oladi va bu nimani osonlashtiradi? React'dagi reconciliation bilan o'xshashligi nimada?
- Provisioning va configuration management chegarasi qayerda, nima uchun bitta asbob ikkalasini ham yaxshi qilmaydi?
- State nima uchun kerak? Usiz asbob qaysi savolga javob bera olmaydi? Lockfile bilan o'xshashligi nimada?
- Push va pull modellarining har biri qaysi holatda qulayroq?
- Immutable infratuzilma drift muammosini qanday yechadi va buning narxi nima?
- cloud-init nima uchun "day 0" asbobi deyiladi?
- Terraform va OpenTofu litsenziyalari orasidagi farq amalda kimga ta'sir qiladi?
- Bu darsdagi qaysi fayllar ikkinchi mashinaga git orqali ko'chadi, nima ko'chmaydi va uni qanday tiklaysiz?
