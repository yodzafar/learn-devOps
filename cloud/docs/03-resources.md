# 3-dars: Virtual mashina, tarmoq, S3

Maqsad: cloud'ning uchta asosiy qurilish blokini qo'lda yaratish, bog'lash va o'chirishni noldan o'rganish: EC2 (virtual mashina), VPC (tarmoq) va S3 (object storage), hamda ularni bog'laydigan IAM role. Linux modulidagi server va network modulidagi subnet, routing, firewall bilimlari bu yerda API orqali boshqariladigan resurslarga aylanadi: VPC bu o'sha tushunchalar, faqat kabel va konfiguratsiya fayli o'rnida API obyektlari. Har narsani avval konsolda bir marta (nima borligini ko'rish uchun), keyin CLI'da (takrorlash va skript qilish uchun) bajarasiz. Vercel yoki Netlify sizdan aynan shu qatlamni yashirgan: u yerda `git push` dan keyin server, tarmoq va fayl ombori o'zi paydo bo'ladi, bu yerda esa har birini o'zingiz yaratasiz. 4-darsdagi deploy shu resurslar ustiga quriladi, Terraform modulida esa shu qadamlarni kod bilan yozasiz.

Taxminiy vaqt: 6 kun (siz uchun). 1-kun 1-bo'lim va 1–4 vazifalar, 2-kun 5–8 vazifalar, 3-kun 2-bo'lim va 9–12 vazifalar, 4-kun 13–15 vazifalar va 3-bo'lim boshi (16–17), 5-kun 18–20 vazifalar, 6-kun 4-bo'lim, "Birga bajaramiz", 21–22 vazifalar. Diqqatni quyidagilarga qarating: subnet'ni nima "public" qiladi, security group'ning stateful ekani, instans to'xtatilgach yoki o'chirilgach nimalar qolib pul oladi, S3 da kirish qaysi qatlamlarda hal qilinadi, o'chirish tartibi (bog'liqliklar).

Qanday o'qish kerak: har bo'limdagi buyruqni o'z akkauntingizda terib ko'ring va chiqishni darsdagi maydonma-maydon izoh bilan solishtiring. Sizdagi ID, IP va sanalar boshqa bo'ladi, darsda ular `<...>` bilan belgilangan (`i-<...>`, `vpc-<...>`, `<ACCOUNT_ID>`, `<AMI_ID>`). Narx va free tier chegaralari darsda yozilmagan, chunki ular o'zgaradi: har safar rasmiy sahifadan o'qiysiz. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Uchta "joy" bor, har buyruq qaysi birida bajarilishini bilib turing:

| Joy | Nima bajariladi |
|-----|-----------------|
| Host (Zorin yoki macOS) | `aws` CLI buyruqlari, `ssh`, `curl`, `dig`, `make`, `git`, skriptlar (`task_*.sh`, `leftovers.sh`) |
| EC2 instans (Ubuntu 24.04) | server ichidagi hamma narsa: paket o'rnatish, disk formatlash, `ip`, `lsblk`, `cloud-init`, metadata so'rovlari |
| `lab` VM (Multipass) | bu darsda shart emas; faqat portable bo'lmagan Linux buyrug'ini sinash kerak bo'lsa |

- **Cloud akkaunt**: 2-darsda sozlangan AWS akkaunt va admin profil. Bitta region tanlang (1-darsdagi latency o'lchovingiz bo'yicha) va butun dars davomida faqat shunda ishlang: `export AWS_REGION=<region>`. Bu o'zgaruvchi faqat joriy terminal oynasida yashaydi, yangi oynada qayta bering.
- **Boshlashdan oldin (har mashg'ulotda)**: `aws sts get-caller-identity` (kim nomidan ishlayapman), `aws budgets describe-budgets --account-id <ACCOUNT_ID>` (2-darsda yaratilgan budget alert joyidami). Budget bo'lmasa bu darsni boshlamang.
- **Instans tipi**: faqat eng kichigi. Tanlash usuli 1-bo'limda. Narxlar: https://aws.amazon.com/ec2/pricing/on-demand/, free tier shartlari (ular akkaunt ochilgan sanaga bog'liq): https://aws.amazon.com/free/.
- **Tag**: har resursga `project=devops-course`. Tag bu resursga yopishtiriladigan kalit-qiymat yorlig'i, oxirida "bu darsdan nima qoldi" degan savolga shu orqali javob olinadi.
- **Nima pul oladi**: ishlab turgan instans; EBS volume va snapshot (instans to'xtatilgan bo'lsa ham); public IPv4 manzil (avtomatik berilgani ham, Elastic IP ham, ulanmagan bo'lsa ham); NAT gateway (bu darsda **yaratilmaydi**); S3 dagi ma'lumot va uning eski versiyalari. Aniq narxni har birining pricing sahifasidan o'qing.
- **Har mashg'ulot oxirida**: instanslarni terminate qiling (stop emas), Elastic IP ni release qiling, qo'shimcha volume va snapshot'larni o'chiring. VPC, subnet, route table, internet gateway, security group, key pair bepul, ular keyingi kungacha qolishi mumkin.
- **Dars oxirida**: hammasi o'chiriladi, 22-vazifadagi skript barcha regionlarda hech narsa qolmaganini ko'rsatadi.
- **Server ichidagi ishlar** (paket, disk, firewall) faqat EC2 instansda bajariladi, ish mashinasida emas.
- **SSH qoidasi**: security group'da 22-port hech qachon `0.0.0.0/0` ga ochilmaydi, faqat joriy public IP'ingizga (`/32`).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host `amd64`. `dig` yo'q bo'lsa `sudo apt install dnsutils`. Ofis tarmog'ining public IP'si uynikidan boshqa: security group qoidasi ofis IP'siga yoziladi. SSH kaliti shu mashinaning `~/.ssh/` katalogida, key pair nomi `lab-zorin`. |
| macOS (uy) | Host `arm64`, lekin bu instans tanloviga ta'sir qilmaydi: `aws` va `ssh` faqat mijoz. BSD userland: `sed -i ''`, `grep -P` yo'q, `date -d` yo'q, bash 3.2. Skriptlaringiz shularsiz yozilsin. Uy IP'si boshqa (va provayder uni o'zgartirib turishi mumkin). Key pair nomi `lab-mac`. |

### Ikkinchi mashinada nimani takrorlash kerak

AWS akkaunt va undagi resurslar umumiy: ofisda yaratilgan bucket yoki VPC uyda xuddi shunday ko'rinadi. Uch narsa esa mashinaga xos va git orqali ko'chmaydi:

1. CLI profili (2-dars): har mashinada alohida sozlangan.
2. SSH private key: har mashinaning o'z kaliti bor (linux 10-dars), private qism mashinadan chiqmaydi. Har mashinaning public key'ini alohida nom bilan import qiling (`lab-zorin`, `lab-mac`, 1-bo'lim). Public key sir emas, lekin private key (`.pem`, `id_ed25519`) repoga hech qachon tushmaydi: `chmod 600`, joyi `~/.ssh/`, `make secrets` tekshiruvi `.pem` va `.key` fayllarni rad etadi.
3. Security group'dagi IP qoidasi: ofis IP'si uchun ochilgan 22-port uydan ishlamaydi. Uyda `curl -s https://checkip.amazonaws.com` bilan IP'ni bilib, shu IP uchun qoida qo'shasiz, eskisini olib tashlaysiz.

Instans yaratilayotganda faqat bitta key pair oladi, shuning uchun ofis kaliti bilan yaratilgan instansga uydan kirib bo'lmaydi. Toza yechim: instanslar bir martalik. Har mashg'ulot oxirida terminate qilasiz, keyingi mashg'ulotda (qaysi mashinada bo'lsangiz, o'shaning key pair'i bilan) yangisini yaratasiz. Instans ikkala mashinadan ham ochiq bo'lishi kerak bo'lgan kamdan-kam holatda, kirish bor mashinadan ikkinchi public key'ni instansdagi `~/.ssh/authorized_keys` ga qo'shasiz (linux 10-dars). Private key'ni mashinalar orasida ko'chirish yoki xabar orqali yuborish yechim emas.

---

## 1. EC2: virtual mashina

EC2 (Elastic Compute Cloud) bu AWS'ning virtual mashina ijarasi xizmati. Bitta ijaraga olingan VM **instans** deyiladi. Instans yaratish uchun olti narsa tanlanadi:

| Parametr | Nima | Izoh |
|----------|------|------|
| AMI | Disk image: OS va oldindan o'rnatilgan dasturlar | ID region bo'yicha har xil (`ami-...`), vaqt o'tishi bilan yangilanadi |
| Instance type | vCPU, xotira, tarmoq, arxitektura | `t3.micro`: oila `t`, avlod `3`, o'lcham `micro`. `g` qo'shimchasi (`t4g`) Graviton, ya'ni ARM protsessor |
| Key pair | SSH public key | AWS public qismni instansga joylaydi, private qism faqat sizda |
| Subnet | Qaysi tarmoq va AZ | Instans bitta AZ ga bog'lanadi |
| Security group | Tarmoq firewall qoidalari | Bir nechta bo'lishi mumkin |
| Storage | Root volume hajmi va turi | EBS, standart `gp3` |

### Mexanizm: instans aslida nima

AWS data markazidagi jismoniy serverda hypervisor ishlaydi: bu bitta jismoniy mashinani bir nechta izolyatsiya qilingan VM'ga bo'lib beradigan dastur (`lab` VM'ni Multipass yaratgani kabi, linux 1-dars). `run-instances` API chaqiruvi kelganda AWS tanlangan AZ da (availability zone, regiondagi alohida data markaz, 1-dars) bo'sh joyi bor serverni topadi va to'rt ish qiladi: AMI'dan root disk nusxasini oladi (EBS volume), instansga virtual tarmoq kartasi (ENI, elastic network interface) yaratib unga subnet'dan private IP beradi, hypervisor'da VM'ni yoqadi, birinchi yuklanishda esa instans ichidagi cloud-init dasturi key pair va user data'ni qo'llaydi. Disk serverning ichida emas, tarmoq orqali ulangan: shuning uchun instansni to'xtatib boshqa jismoniy serverda qayta yoqish mumkin, disk esa instansdan mustaqil yashaydi va alohida pul oladi.

### Instance type va arxitektura

Tip nomi protsessor arxitekturasini ham belgilaydi: `t3` oilasi `x86_64` (Docker tilida `amd64`), `t4g` oilasi `arm64`. AMI shu arxitekturaga mos bo'lishi shart, aks holda instans yaratilmaydi. Bu darsda qaysi birini tanlasangiz ham bo'ladi; 4-darsda Mac'da yig'ilgan `arm64` image bilan `amd64` instans orasidagi nomuvofiqlik alohida ko'riladi. Free tier'ga kiradigan tiplarni taxmin qilmay, akkauntdan so'rang:

```
$ aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
    --query 'InstanceTypes[].InstanceType' --output text
<tip-1>    <tip-2>    ...
$ aws ec2 describe-instance-types --instance-types t3.micro t4g.micro \
    --query 'InstanceTypes[].[InstanceType,ProcessorInfo.SupportedArchitectures[0],VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB]' \
    --output text
t3.micro     x86_64    2    1024
t4g.micro    arm64     2    1024
```

Birinchi buyruq: `--filters` server tomonda saralaydi (faqat free tier belgisi borlar), `--query` javob JSON'idan kerakli maydonni ajratadi (2-dars). Ro'yxat akkaunt va regionga bog'liq, shuning uchun darsda yozilmagan. Ikkinchi buyruq chiqishi ustunma-ustun: tip nomi, arxitektura, vCPU soni (virtual CPU, jismoniy yadroning bitta oqimi), xotira MiB da. Ikkala tip bir xil o'lchamda, farq faqat protsessorda.

`t` oilasi **burstable**: instans bo'sh turganda CPU krediti to'playdi, yuklama kelganda sarflaydi. Kredit tugasa nima bo'lishi rejimga bog'liq: `standard` rejimda unumdorlik pasayadi, `unlimited` rejimda pasaymaydi, lekin ortiqcha sarflangan CPU uchun qo'shimcha haq yoziladi. Qaysi rejimdaligini `aws ec2 describe-instance-credit-specifications --instance-ids i-<...>` ko'rsatadi. O'rganish uchun yetarli, doimiy CPU yuklamasi uchun emas.

### AMI

AMI (Amazon Machine Image) bu root disk nusxasi va uni qanday yuklash haqidagi ma'lumot. AMI ID ni qo'lda nusxalamang: u har regionda boshqa va har yangilanishda o'zgaradi. Canonical (Ubuntu ishlab chiqaruvchisi) joriy AMI'larni SSM public parameter sifatida e'lon qiladi, ya'ni AWS'ning Systems Manager xizmatidagi hamma o'qiy oladigan kalit-qiymat yozuvi:

```
$ aws ssm get-parameters \
    --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query 'Parameters[0].Value' --output text
ami-<...>
```

Yo'ldagi `24.04` reliz, `amd64` arxitektura (`t4g` uchun `arm64` yoziladi), `ebs-gp3` root disk turi. Chiqish bitta qator: shu region uchun bugungi AMI ID. Uni o'zgaruvchiga oling (`AMI=$(aws ssm ...)`), skriptga qotirib yozmang. Muqobil: `aws ec2 describe-images --owners 099720109477` (Canonical'ning AWS akkaunti) va nom bo'yicha filtr. Ubuntu AMI'da standart foydalanuvchi `ubuntu`, u `sudo` ni parolsiz ishlatadi; `root` bilan SSH yopiq.

### Key pair

Key pair bu AWS'da saqlanadigan SSH public key (linux 10-dars: public key qulf, private key kalit). Private key hech qachon serverga yoki AWS'ga yuborilmaydi. Eng toza yo'l mavjud public key'ni import qilish:

```
$ aws ec2 import-key-pair --key-name lab-demo \
    --public-key-material fileb://~/.ssh/id_ed25519.pub \
    --query '[KeyName,KeyPairId]' --output text
lab-demo    key-<...>
```

`fileb://` faylni baytma-bayt o'qish degani (CLI v2 da binary parametrlar uchun shart). Chiqish: nom va AWS bergan ID. `aws ec2 create-key-pair` ishlatilsa AWS juftlikni o'zi yaratadi va private qismni bir marta qaytaradi; uni `~/.ssh/` ga saqlab `chmod 600` qilish kerak, yo'qotsangiz qayta olib bo'lmaydi. Shuning uchun import afzal: private key umuman tarmoqqa chiqmaydi. Key pair faqat birinchi yuklanishda cloud-init tomonidan `~ubuntu/.ssh/authorized_keys` ga yoziladi: keyin AWS'dagi key pair'ni o'chirish instansga kirishni bekor qilmaydi, yangi key pair biriktirish ham ishlab turgan instansga ta'sir qilmaydi.

### Security group

Security group (SG) instansning tarmoq interfeysiga biriktiriladigan firewall. U instans ichidagi `ufw` yoki `nftables` emas (network 6-dars), AWS tarmog'ida, paket instansga yetib kelmasidan oldin ishlaydi.

- Faqat `allow` qoidalar bor, `deny` yo'q. Yozilmagan hamma narsa taqiqlangan.
- **Stateful** (network 6-dars): ruxsat berilgan ulanish eslab qolinadi, uning javob paketlari teskari yo'nalishda qoidasiz o'tadi.
- Yangi SG: kiruvchi (inbound) hamma narsa yopiq, chiquvchi (outbound) hamma narsa ochiq. VPC'ning `default` nomli SG si bundan farq qiladi: u shu SG a'zolaridan kiruvchi trafikka ruxsat beradi.
- Manba sifatida CIDR yoki boshqa SG ko'rsatiladi: "database SG ga faqat app SG dan 5432-port". Bu IP'larga bog'lanmagan qoida yozish imkonini beradi.

Misol: mavjud SG da HTTPS portini faqat o'z IP'ingizga ochish. SSH uchun ham shakl aynan shu, faqat port boshqa.

```
$ MYIP=$(curl -s https://checkip.amazonaws.com)
$ aws ec2 authorize-security-group-ingress --group-id sg-<...> \
    --protocol tcp --port 443 --cidr "$MYIP/32"
{
    "Return": true,
    "SecurityGroupRules": [
        {
            "SecurityGroupRuleId": "sgr-<...>",
            "GroupId": "sg-<...>",
            "IsEgress": false,
            "IpProtocol": "tcp",
            "FromPort": 443,
            "ToPort": 443,
            "CidrIpv4": "203.0.113.7/32"
        }
    ]
}
```

`checkip.amazonaws.com` sizni internet qaysi IP bilan ko'rayotganini qaytaradi (uy router'ingiz NAT qilgandan keyingi manzil, network 6-dars). `/32` bitta manzil degani (network 3-dars). Javobda `Return: true` qoida qabul qilindi, `SecurityGroupRuleId` qoidaning o'z ID si (keyin `revoke-security-group-ingress` bilan olib tashlanadi), `IsEgress: false` kiruvchi yo'nalish, `FromPort`/`ToPort` port oralig'i, `CidrIpv4` manba. Qoida bir necha soniyada kuchga kiradi, instansni qayta yoqish kerak emas. Mavjud qoidalar: `aws ec2 describe-security-group-rules --filters Name=group-id,Values=sg-<...>`.

**Tuzoq: `0.0.0.0/0` ga ochiq 22-port.** Internetdagi har bir public IP doimiy skanerlanadi, ochilgan SSH portiga daqiqalar ichida parol tanlash urinishlari keladi. SSH faqat o'z IP'ingizdan. IP o'zgarsa (boshqa mashina, provayder almashtirdi) qoidani yangilaysiz.

### User data va cloud-init

**cloud-init** bu cloud image'lar ichida oldindan o'rnatilgan dastur: birinchi yuklanishda u provayderdan sozlamalarni olib tizimni tayyorlaydi (hostname, SSH kalit, disk o'lchami). **User data** esa siz instans yaratishda beradigan matn, cloud-init uni birinchi yuklanishda `root` nomidan bir marta bajaradi. Shu bilan "toza AMI dan tayyor server" olinadi. Ikki shakli bor: `#!` bilan boshlansa oddiy shell skript, `#cloud-config` bilan boshlansa YAML deklaratsiya:

```
#cloud-config
package_update: true
packages:
  - tree
write_files:
  - path: /etc/motd
    content: "provisioned by cloud-init\n"
```

Bu misol paket ro'yxatini yangilaydi, `tree` ni o'rnatadi va bitta fayl yozadi. Instans ichida natijani tekshirish:

```
ubuntu@ip-<...>:~$ cloud-init status
status: done
ubuntu@ip-<...>:~$ tail -n 1 /var/log/cloud-init-output.log
Cloud-init v. <versiya> finished at <sana>. Datasource DataSourceEc2Local.  Up <N> seconds
```

`status: done` hamma bosqich tugaganini bildiradi (`running` hali ishlayapti, `error` xato bilan tugadi). Log'ning oxirgi qatori cloud-init versiyasi, tugagan vaqti, sozlamalar manbai (`DataSourceEc2Local`, ya'ni EC2 metadata xizmati) va yuklanishdan beri o'tgan soniyalar. Skript va paket o'rnatishning butun chiqishi shu log'da, xato ham o'sha yerda qidiriladi.

- Standart holatda faqat birinchi yuklanishda ishlaydi, reboot yoki stop/start da qayta ishlamaydi.
- Instans `running` bo'lgani user data tugaganini anglatmaydi: paket o'rnatish yana bir necha daqiqa davom etishi mumkin. Skriptda kutish: `cloud-init status --wait`.
- User data shifrlanmagan, instans ichidan va API orqali o'qiladi: unga secret yozilmaydi.

### Instance metadata (IMDS)

Instans o'zi haqidagi ma'lumotni (ID, tip, AZ, IP, user data) **instance metadata service** dan oladi: bu `169.254.169.254` manzilidagi HTTP xizmat, unga faqat instans ichidan yetib boriladi. cloud-init ham key pair va user data'ni aynan shu yerdan o'qiydi. IMDSv2 da avval `PUT` so'rovi bilan vaqtinchalik token olinadi, keyin har so'rovga header sifatida qo'shiladi:

```
ubuntu@ip-<...>:~$ TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
ubuntu@ip-<...>:~$ curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/ami-id
ami-<...>
ubuntu@ip-<...>:~$ curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4
172.31.<...>
```

Birinchi buyruq 300 soniya yashaydigan token so'raydi, keyingi ikkitasi shu token bilan instans yaratilgan AMI ID sini va private IP'sini oladi. `meta-data/` ning o'zini so'rasangiz mavjud kalitlar ro'yxati chiqadi. Token nega kerak: eski IMDSv1 oddiy `GET` ga javob berardi, va instansdagi web dasturni "mana shu URL'ni menga olib ber" deb aldash (SSRF hujumi) orqali metadata'ni, u bilan birga IAM role credential'larini o'g'irlash mumkin edi. `PUT` va maxsus header talabi bunday aldashni ancha qiyinlashtiradi. Instans IMDSv2 ni majburiy qilganmi: `aws ec2 describe-instances --instance-ids i-<...> --query 'Reservations[].Instances[].MetadataOptions.HttpTokens'` (`required` yoki `optional`).

### Hayot sikli va EBS

| Holat | Hisoblash haqi | Disk haqi | Public IP (avtomatik) |
|-------|----------------|-----------|------------------------|
| running | bor | bor | bor |
| stopped | yo'q | **bor** | qaytarib olinadi, start'da yangisi beriladi |
| terminated | yo'q | root volume o'chsa yo'q | yo'q |

Stop bu kompyuterni o'chirib qo'yish: VM yo'q, disk joyida. Terminate bu instansni butunlay yo'q qilish, qaytarib bo'lmaydi. EBS (Elastic Block Store) volume bu tarmoq orqali ulangan blok disk (linux 13-dars: blok qurilma, fayl tizimi, mount):

- Bitta AZ ga tegishli, faqat o'sha AZ dagi instansga ulanadi.
- Root volume'da `DeleteOnTermination` standart `true`. Qo'shimcha ulangan volume'larda standart `false`: instans o'chgach ular `available` holatida qolib pul oladi.
- Snapshot: volume'ning S3 da (sizga ko'rinmaydigan joyda) saqlanadigan nusxasi. U region darajasida, undan boshqa AZ da yangi volume yaratish mumkin. Alohida haq olinadi.
- Yangi bo'sh volume instansda blok qurilma bo'lib ko'rinadi (`lsblk`), fayl tizimi va mount o'zingizdan.

```
$ aws ec2 describe-volumes \
    --query 'Volumes[].[VolumeId,Size,State,AvailabilityZone,Attachments[0].InstanceId]' --output text
vol-<...>    8    in-use       <region>a    i-<...>
vol-<...>    2    available    <region>a    None
```

Ustunlar: volume ID, hajm GiB da, holat, AZ, ulangan instans. Birinchi qator ishlab turgan yoki to'xtatilgan instansning root diski (`in-use`). Ikkinchi qator hech narsaga ulanmagan (`available`, instans `None`): aynan shunday volume'lar unutiladi va oylar davomida pul oladi.

**Tuzoq: stop qilingan instans bepul emas.** Disk va (bo'lsa) Elastic IP uchun to'lov davom etadi. Laboratoriyada terminate qiling.

### Real ishda qachon kerak

- Har qanday "o'z serverimiz" shu olti tanlovdan boshlanadi: 4-darsdagi deploy, CI runner, bastion, database serveri.
- User data va cloud-init: autoscaling guruhidagi har yangi instans odam qo'lisiz tayyor bo'lishi kerak.
- Metadata: instansdagi skript o'z regionini, ID sini va IAM role credential'larini shu yerdan biladi (3-bo'lim).
- Stop va terminate farqi: tungi va dam olish kunlari to'xtatiladigan test muhitlari xarajatni kamaytiradi, lekin disk haqi qoladi.

### Nima uchun shunday

Disk va hisoblashning ajratilgani tasodif emas: jismoniy server buzilsa instansni boshqa serverda yoqish, tipni kattalashtirish (stop, tipni o'zgartirish, start) va snapshot olish shu tufayli mumkin. Narxi: disk tarmoq orqali ishlaydi va alohida hisoblanadi. Muqobil (instance store, serverning o'z lokal diski) tezroq, lekin instans to'xtaganda ma'lumot yo'qoladi. Key pair'ning faqat birinchi yuklanishda qo'llanishi ham shu mantiqdan: AWS instans ichiga kirmaydi, u faqat metadata orqali ma'lumot beradi, ichkarida nima qilishni cloud-init hal qiladi. cloud-init esa ochiq standart: deyarli hamma provayder shuni ishlatadi, shuning uchun bitta user data fayli boshqa cloud'da ham ishlaydi.

## 2. Tarmoq: VPC

VPC (Virtual Private Cloud) bu akkauntingizdagi izolyatsiya qilingan virtual tarmoq, o'z CIDR bloki bilan (masalan `10.20.0.0/16`; CIDR va private oraliqlar network 3-darsda). Har regionda tayyor **default VPC** bor (`172.31.0.0/16`, har AZ da bittadan public subnet), shuning uchun birinchi instans tarmoq sozlamasdan ishga tushadi. Production'da o'z VPC'ingiz quriladi.

| Komponent | Vazifasi | Doira |
|-----------|----------|-------|
| VPC | Manzil maydoni va izolyatsiya chegarasi | Region |
| Subnet | VPC CIDR'ining bir qismi | Bitta AZ |
| Route table | Subnet'dan chiqadigan trafik qayerga borishi | Subnet'ga biriktiriladi |
| Internet gateway (IGW) | VPC va internet orasidagi eshik | VPC'ga bitta |
| NAT gateway | Private subnet'dan internetga faqat chiquvchi ulanish | Public subnet'da turadi |
| Security group | Instans darajasidagi stateful firewall | VPC |
| Network ACL | Subnet darajasidagi stateless firewall | Subnet |
| Elastic IP | O'zgarmas public IPv4 | Region |

### Mexanizm: o'sha tarmoq, faqat API obyektlari

Network modulida router, routing table va firewall alohida qurilma yoki Linux konfiguratsiyasi edi. VPC'da ularning har biri API obyekti: `create-subnet`, `create-route-table`, `create-route`. Jismoniy switch va kabel yo'q, paketlarni AWS'ning dasturiy tarmog'i tashiydi va har paket uchun shu obyektlarga qaraydi. Har subnet'da ko'rinmas router bor: subnet'ning tarmoq manzilidan keyingi birinchi manzili (`10.20.1.0/24` da `10.20.1.1`) instans uchun default gateway (network 5-dars). Instans ichidagi `ip route` faqat "hammasini gateway'ga ber" deydi, paket keyin qayerga borishini esa subnet'ga biriktirilgan route table hal qiladi. AWS har subnet'da 5 ta manzilni o'zi uchun band qiladi (birinchi to'rtta va oxirgisi): `/24` da 256 emas, 251 ta ishlatiladigan manzil.

Subnet bitta AZ da yashaydi, shuning uchun bir nechta AZ ga tarqalgan tizim kamida shuncha subnet talab qiladi. Har VPC'da bitta **main route table** bor: alohida route table biriktirilmagan subnet'lar shuni ishlatadi.

### Public va private subnet

"Public" degan belgi yo'q. Subnet public bo'lishi uchun uch shart birga bajarilishi kerak:

1. VPC'ga internet gateway ulangan.
2. Subnet'ning route table'ida `0.0.0.0/0` yo'li IGW ga qaragan.
3. Instansda public IPv4 bor (subnet'da "auto-assign public IP" yoki Elastic IP).

Bittasi yetishmasa instansga internetdan kirib bo'lmaydi. Private subnet'da `0.0.0.0/0` yo'li yo'q yoki NAT gateway'ga qaragan. O'z VPC'ingizdagi public subnet'ning route table'i shunday ko'rinadi:

```
$ aws ec2 describe-route-tables --route-table-ids rtb-<...> \
    --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,State]' --output text
10.20.0.0/16    local        active
0.0.0.0/0       igw-<...>    active
```

Birinchi qator `local` yo'li: VPC CIDR'iga boradigan hamma narsa VPC ichida qoladi. U har route table'da bor va o'chirilmaydi, shu sababli VPC ichidagi barcha subnet'lar bir-birini ko'radi (to'siqni SG va NACL qo'yadi, routing emas). Ikkinchi qator default route (network 5-dars): qolgan hamma manzil internet gateway'ga. Qoida o'sha: eng aniq (eng uzun prefiksli) yo'l yutadi. Ikkinchi qator shunday qo'shiladi:

```
aws ec2 create-route --route-table-id rtb-<...> \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-<...>
aws ec2 associate-route-table --route-table-id rtb-<...> --subnet-id subnet-<...>
```

Instans ichida public IP ko'rinmaydi: interfeysda faqat private manzil turadi. Public IP internet gateway'da yashaydi, u private va public manzilni birga-bir almashtiradi (network 6-darsdagi NAT'ning 1:1 ko'rinishi). Shuning uchun uchinchi shart ham kerak: public IP'siz instansning paketi IGW gacha boradi, lekin almashtiradigan manzil yo'q.

Odatiy tuzilma: public subnet'da load balancer va bastion (ichki serverlarga kirish uchun yagona SSH eshigi bo'lgan kichik instans), private subnet'da dastur va database. Private instansga kirish: bastion orqali `ssh -J ubuntu@<bastion-ip> ubuntu@10.20.2.15` (`-J` oraliq host orqali sakrash, kalit sizning mashinangizda qoladi) yoki AWS Systems Manager Session Manager.

### NAT gateway

Private subnet'dagi instans paket yangilash yoki tashqi API chaqirish uchun internetga chiqishi kerak, lekin internetdan unga kirib bo'lmasligi kerak. NAT gateway shuni qiladi: bu public subnet'da turadigan, o'z Elastic IP'siga ega boshqariladigan xizmat, private subnet'ning `0.0.0.0/0` yo'li unga qaratiladi va u chiquvchi paketlarning manba manzilini o'zinikiga almashtiradi (network 6-darsdagi source NAT, uy router'ingiz qiladigan ish).

**Tuzoq: NAT gateway eng ko'p unutiladigan xarajat.** U mavjud bo'lgan har soat uchun va o'tgan har GB uchun haq oladi, ustiga public IPv4 ham kerak; trafik bo'lmasa ham hisob ketadi. Bu darsda yaratilmaydi: private instansning internetga chiqa olmasligini ko'rasiz, narxini esa https://aws.amazon.com/vpc/pricing/ dan o'zingiz hisoblaysiz.

### Security group va Network ACL

| | Security group | Network ACL |
|---|----------------|-------------|
| Daraja | Instans (tarmoq interfeysi) | Subnet |
| Holat | Stateful | Stateless: javob trafigi uchun alohida qoida kerak |
| Qoidalar | Faqat allow | Allow va deny |
| Baholash | Hamma qoidalar birga | Raqam tartibida, birinchi mos kelgani |
| Standart | Kiruvchi yopiq, chiquvchi ochiq | Default NACL hammasiga ruxsat beradi |

Stateless degani NACL ulanishni eslamaydi, har paketni alohida baholaydi (network 6-dars). Mijoz serverga ulanayotganda o'z tomonida tasodifiy yuqori portni (ephemeral port) ochadi va javob o'sha portga qaytadi; NACL uchun bu javob "ruxsat berilgan ulanishning davomi" emas, oddiy yangi paket. Kundalik ish SG bilan qilinadi. NACL kam hollarda kerak: butun subnet uchun aniq IP oralig'ini bloklash (SG da `deny` yo'q).

### Elastic IP va public IPv4

Avtomatik berilgan public IP instans stop/start qilinganda o'zgaradi. Elastic IP (EIP) akkauntingizga tegishli o'zgarmas manzil: `allocate-address` bilan olinadi, `associate-address` bilan instansga ulanadi, `release-address` bilan qaytariladi. DNS yozuvi qaratiladigan server uchun kerak (4-dars).

```
$ aws ec2 describe-addresses \
    --query 'Addresses[].[PublicIp,AllocationId,AssociationId,InstanceId]' --output text
198.51.100.24    eipalloc-<...>    None    None
```

Ustunlar: manzil, ajratish ID si, ulanish ID si, instans. Oxirgi ikkitasi `None`: manzil ajratilgan, lekin hech narsaga ulanmagan. Public IPv4 manzillar pullik resurs, ishlatilayotgani ham, bo'sh turgani ham; `None` li qator unutilgan xarajatning klassik ko'rinishi.

### Real ishda qachon kerak

- "Sayt ochilmayapti" degan muammoning yarmi shu yerda: route yo'q, public IP yo'q yoki SG yopiq. Uch shartni tartib bilan tekshirish odatga aylanishi kerak.
- Database'ni internetdan yashirish: private subnet va "faqat app SG dan" qoidasi.
- Terraform modulida yozadigan birinchi kodingiz aynan shu obyektlar bo'ladi.

### Nima uchun shunday

Public va private subnet'ning alohida "turi" yo'qligi dizayn qarori: subnet shunchaki manzillar oralig'i, xatti-harakatni route table belgilaydi, xuddi haqiqiy tarmoqdagi kabi. Bu moslashuvchan (bitta yo'lni almashtirib subnet'ni yopasiz), lekin xatoga ham yo'l ochadi: hech narsa "bu subnet endi public" deb ogohlantirmaydi. Ikki qatlamli firewall tarixiy: SG instansga yopishib yuradi va dastur egasi boshqaradi, NACL tarmoq chegarasida turadi va uni odatda tarmoq jamoasi boshqaradi. Default VPC esa yangi foydalanuvchi birinchi instansni tez ishga tushirsin deb qo'shilgan; uning hamma subnet'i public bo'lgani uchun production'da ishlatilmaydi.

## 3. S3: object storage

S3 (Simple Storage Service) fayl tizimi emas, HTTP orqali ishlaydigan kalit-qiymat ombori: **bucket** (idish) ichida **object** lar, har biri kalit (`logs/2026/app.log`), ma'lumot va metadata (`Content-Type`, hajm, sana). Katalog yo'q, `/` shunchaki kalitning bir qismi, konsol uni papka qilib ko'rsatadi. Netlify yoki Vercel'ga chiqaradigan `dist/` katalogingiz ham aslida shunday object storage'da yotadi va CDN orqali beriladi.

- Bucket nomi butun dunyoda noyob (hamma AWS akkauntlari uchun bitta nomlar maydoni, chunki nom DNS manzilning qismi: `<bucket>.s3.<region>.amazonaws.com`), qoidalari DNS'niki: kichik harf, raqam, defis.
- Bucket bitta regionda yaratiladi, ma'lumot o'sha regionda bir nechta AZ ga tarqatiladi.
- Obyekt qisman o'zgartirilmaydi, faqat butunlay qayta yoziladi. Shuning uchun database fayli yoki log'ga "append" qilish uchun yaramaydi.
- `mount` qilinmaydi: har amal HTTP so'rov (`PUT`, `GET`, `DELETE`), har so'rov imzolanadi.

Ikki xil CLI: `aws s3` (yuqori darajali: `ls`, `cp`, `mv`, `rm`, `sync`, `mb`, `rb`, `presign`) va `aws s3api` (har bir API amali, to'liq nazorat).

```
$ aws s3 mb s3://demo-<suffix>
make_bucket: demo-<suffix>
$ aws s3 cp notes.txt s3://demo-<suffix>/docs/notes.txt
upload: ./notes.txt to s3://demo-<suffix>/docs/notes.txt
$ aws s3 ls s3://demo-<suffix> --recursive
<sana> <vaqt>         42 docs/notes.txt
```

`mb` (make bucket) joriy regionda bucket yaratadi. `cp` lokal faylni `docs/notes.txt` kaliti bilan yuklaydi; `docs/` katalog yaratilmadi, u kalitning boshi xolos. `ls --recursive` qatori: oxirgi o'zgarish sanasi va vaqti, hajm baytda, kalit.

### Storage class

Class obyekt darajasida belgilanadi. G'oya: kam o'qiladigan ma'lumot arzonroq saqlanadi, lekin o'qish qimmatroq yoki sekinroq.

| Class | Qachon | Savdolashuv |
|-------|--------|-------------|
| Standard | Tez-tez o'qiladigan | Saqlash eng qimmat, GB uchun o'qish (retrieval) haqi yo'q |
| Standard-IA, One Zone-IA | Kam o'qiladigan, lekin darhol kerak | Saqlash arzon, o'qilgan har GB uchun haq, minimal saqlash muddati; One Zone bitta AZ da |
| Intelligent-Tiering | O'qilish chastotasi noma'lum | Avtomatik ko'chiradi, kuzatuv haqi bor |
| Glacier Instant Retrieval | Arxiv, kamdan-kam, lekin darhol | Saqlash yanada arzon, o'qish qimmat |
| Glacier Flexible Retrieval, Deep Archive | Uzoq muddatli arxiv | Eng arzon saqlash, o'qish uchun avval tiklash kerak (daqiqalardan soatlargacha) |

So'rovlar soni (`PUT`, `GET`, `LIST`) uchun haq hamma class'da bor. Aniq narx va minimal muddatlar: https://aws.amazon.com/s3/pricing/.

### Versioning va lifecycle

Versioning yoqilganda har yozish yangi versiya yaratadi, o'chirish esa obyektni yo'q qilmay ustiga **delete marker** (bu kalit o'chirilgan degan belgi-versiya) qo'yadi. Tasodifiy o'chirish va ustidan yozishdan himoya. Yoqilgandan keyin o'chirib bo'lmaydi, faqat to'xtatiladi (suspend).

```
$ aws s3api put-bucket-versioning --bucket demo-<suffix> \
    --versioning-configuration Status=Enabled
$ aws s3api list-object-versions --bucket demo-<suffix> --prefix docs/notes.txt \
    --query 'Versions[].[VersionId,IsLatest,Size]' --output text
<version-id-2>    True     57
<version-id-1>    False    42
```

Birinchi buyruq muvaffaqiyatda hech narsa chiqarmaydi. Ikkinchisi bitta kalitning ikki versiyasini ko'rsatadi: ID, joriy versiyami, hajm. `aws s3 ls` faqat `True` qatorini ko'radi. Eski versiya `aws s3api get-object --version-id <version-id-1> ...` bilan olinadi.

**Tuzoq: versiyalar ko'rinmaydi, lekin pul oladi.** Eski versiyalar to'planadi va saqlash haqi oladi. Versioning doim lifecycle qoidasi bilan birga yoqiladi.

Lifecycle qoidalari obyektlarni yoshiga qarab boshqa class'ga o'tkazadi yoki o'chiradi: "30 kundan keyin Standard-IA, 365 kundan keyin o'chir", "joriy bo'lmagan versiyalarni 30 kundan keyin o'chir", "tugallanmagan multipart upload'larni 7 kundan keyin tozala" (multipart upload: katta fayl bo'laklab yuklanadi, uzilib qolgan bo'laklar ko'rinmay joy egallaydi).

### Kirish nazorati

S3 da kirish bir nechta qatlamda hal qilinadi, har so'rov hammasidan o'tishi kerak:

1. **Block Public Access (BPA)**: akkaunt va bucket darajasidagi to'rtta kalit. Yoqilgan bo'lsa policy nima desa ham public kirish bloklanadi. Yangi bucket'larda standart yoqilgan.
2. **IAM policy** (identity-based, 2-dars): bu identifikatsiya (user, role) nima qila oladi.
3. **Bucket policy** (resource-based): bu bucket'ga kim kira oladi, `Principal` maydoni bilan. Farq yo'nalishda: IAM policy odamga yopishadi va "u nimalarga kiradi" deydi, bucket policy bucket'ga yopishadi va "unga kimlar kiradi" deydi. Bir akkaunt ichida ikkalasidan biri ruxsat bersa (va hech qayerda explicit deny bo'lmasa) so'rov o'tadi.
4. ACL: eski mexanizm, yangi bucket'larda standart o'chirilgan. Ishlatmang.

```
$ aws s3api get-public-access-block --bucket demo-<suffix>
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
```

To'rt kalit: `BlockPublicAcls` yangi public ACL qo'yishni rad etadi, `IgnorePublicAcls` mavjud public ACL'larni hisobga olmaydi, `BlockPublicPolicy` public kirish beradigan bucket policy'ni qabul qilmaydi, `RestrictPublicBuckets` public policy'li bucket'ga begona kirishni kesadi. Hammasi `true`: bucket xato policy bilan ham ochilib qolmaydi.

Bucket policy'ning shakli (misol: so'rov ofis tarmog'idan kelmasa hamma amal rad etiladi):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::demo-<suffix>", "arn:aws:s3:::demo-<suffix>/*"],
    "Condition": {"NotIpAddress": {"aws:SourceIp": "203.0.113.0/24"}}
  }]
}
```

`Principal: "*"` hamma (shu jumladan admin). `Resource` da ikki ARN: birinchisi bucket'ning o'zi (`ListBucket` kabi bucket amallari uchun), `/*` lisi ichidagi obyektlar (`GetObject`, `PutObject` uchun); bittasini unutish eng ko'p uchraydigan xato. `Condition` shartni beradi, boshqa kalitlar ham bor (masalan `aws:SecureTransport`: so'rov HTTPS orqali kelganmi). 2-darsdagi qoida bu yerda ham ishlaydi: explicit deny g'olib.

### Presigned URL

Private obyektni AWS credential'i yo'q odamga vaqtincha berish usuli: URL ichida imzo va muddat bor, URL egasi imzolagan identifikatsiya nomidan aynan shu bitta amalni (shu kalit, shu HTTP metod) bajaradi.

```
$ aws s3 presign s3://demo-<suffix>/docs/notes.txt --expires-in 300
https://demo-<suffix>.s3.<region>.amazonaws.com/docs/notes.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=<...>&X-Amz-Date=<...>&X-Amz-Expires=300&X-Amz-SignedHeaders=host&X-Amz-Signature=<...>
```

Buyruq AWS'ga so'rov yubormaydi: imzo lokal, sizning secret key'ingiz bilan hisoblanadi. S3 so'rov kelganda imzoni qayta hisoblab solishtiradi. Frontend'dan fayl yuklashda shu pattern ishlatiladi: brauzer backend'dan `PUT` uchun presigned URL so'raydi va faylni to'g'ridan-to'g'ri S3 ga yuklaydi, katta fayl backend orqali o'tmaydi. Brauzer boshqa origin'ga so'rov yuborgani uchun bucket'da CORS konfiguratsiyasi kerak bo'ladi (`aws s3api put-bucket-cors`), aks holda brauzer so'rovni bloklaydi. URL'ni kim bilsa o'sha kira oladi, muddatni qisqa qo'ying. Imzolagan credential muddati tugasa (masalan role sessiyasi) URL ham ishlamay qoladi.

### Static website hosting

Bucket statik saytni to'g'ridan-to'g'ri bera oladi: `aws s3 website s3://<bucket> --index-document index.html --error-document error.html`. Buning uchun bucket'da BPA o'chiriladi va public o'qishga ruxsat beruvchi bucket policy qo'yiladi. Website endpoint faqat HTTP; HTTPS va o'z domen uchun oldiga CloudFront (AWS'ning CDN xizmati) qo'yiladi, o'shanda bucket private qoladi. Netlify va Vercel statik sayt uchun aynan shu juftlikni (object storage va CDN) tayyor holda beradi. Bu darsda mexanizmni ko'rish uchun public variantni qilasiz va darhol yopasiz.

**Tuzoq: bucket'ni "ishlamayapti" deb public qilish.** Ochiq bucket'lar ma'lumot sizishining eng mashhur sababi. Public faqat ataylab public bo'lishi kerak bo'lgan statik kontent uchun, alohida bucket'da.

### Instansdan S3 ga: IAM role va instance profile

Instansdagi dastur S3 ga yozishi kerak bo'lsa, access key'ni serverga nusxalash xato yo'l: kalit muddatsiz, diskda ochiq yotadi, server buzilsa birga ketadi. To'g'ri yo'l IAM role (2-dars: kimdir vaqtincha "kiyib oladigan" ruxsatlar to'plami). Zanjir to'rt bo'g'indan iborat:

1. Role, uning trust policy'sida "meni EC2 xizmati kiyishi mumkin" deyilgan (`"Principal": {"Service": "ec2.amazonaws.com"}`, amal `sts:AssumeRole`).
2. Role'ga biriktirilgan **permission policy**: nima qilish mumkin.
3. Instance profile: role'ni instansga ulaydigan o'ram-obyekt (`aws iam create-instance-profile`, `add-role-to-instance-profile`, keyin `aws ec2 associate-iam-instance-profile --instance-id i-<...> --iam-instance-profile Name=<nom>`). Konsol uni role bilan birga ko'rinmas yaratadi, CLI da o'zingiz yaratasiz.
4. Instans ichida metadata xizmati `meta-data/iam/security-credentials/<role-nomi>` yo'lida vaqtinchalik credential (access key, secret key, session token, tugash vaqti) beradi va muddati tugashidan oldin o'zi yangilaydi. AWS CLI va SDK'lar uni o'zi topadi, sozlash kerak emas.

Natijada instansdagi `aws sts get-caller-identity` ning `Arn` maydoni `arn:aws:sts::<ACCOUNT_ID>:assumed-role/<role-nomi>/i-<...>` ko'rinishida bo'ladi: user emas, role sessiyasi.

### Real ishda qachon kerak

- Foydalanuvchi yuklagan fayllar, backup'lar, loglar arxivi, build artefaktlari, Terraform state: hammasi S3 da.
- Presigned URL: avatar yoki hujjat yuklash, to'lovdan keyin vaqtinchalik yuklab olish havolasi.
- Instance role: serverdagi backup skripti S3 ga kalitsiz yozadi (4-dars).

### Nima uchun shunday

S3 fayl tizimining qulayliklaridan (qisman yozish, rename, lock) ataylab voz kechgan: obyekt butun yoziladi va kaliti bo'yicha o'qiladi. Shu soddalik tufayli uni cheksiz masshtablash va bir nechta AZ da nusxalash mumkin; blok disk (EBS) esa bitta instansga ulanadi va hajmi oldindan belgilanadi. Kirish qatlamlarining ko'pligi tarixiy: avval ACL bo'lgan, keyin policy'lar, eng oxirida, ochiq bucket'lar orqali ko'p ma'lumot sizgach, hammasining ustidan "baribir yopiq" degan BPA qo'shilgan. Instance role'ning muqobili serverdagi uzoq muddatli access key; role'da esa o'g'irlanadigan doimiy sir yo'q, credential soatlar ichida eskiradi.

## 4. O'chirish tartibi va tekshirish

### Bog'liqliklar va tartib

Resurslar bir-biriga bog'liq: subnet ichida instans bor ekan subnet o'chmaydi, VPC'ga IGW ulangan ekan VPC o'chmaydi. Shuning uchun o'chirish yaratishning teskari tartibida:

1. Instanslar: `terminate-instances`, keyin tugashini kuting (`aws ec2 wait instance-terminated --instance-ids i-<...>`), chunki instans `shutting-down` holatida ham SG va subnet'ni band qilib turadi.
2. Elastic IP (`release-address`), qo'shimcha EBS volume va snapshot'lar.
3. Internet gateway: avval `detach-internet-gateway`, keyin `delete-internet-gateway`.
4. Subnet'lar, o'zingiz yaratgan route table'lar, NACL va security group'lar.
5. VPC, eng oxirida key pair, IAM role va instance profile.

Noto'g'ri tartibda AWS rad etadi:

```
$ aws ec2 delete-vpc --vpc-id vpc-<...>
An error occurred (DependencyViolation) when calling the DeleteVpc operation: The vpc 'vpc-<...>' has dependencies and cannot be deleted.
```

Qavs ichidagi so'z xato kodi (`DependencyViolation`), undan keyin qaysi API amali rad etilgani (`DeleteVpc`) va sabab. Xabar aynan nima to'sayotganini har doim ham aytmaydi; unda VPC ichida nima qolganini `describe-*` buyruqlari bilan `--filters Name=vpc-id,Values=vpc-<...>` qo'yib qidirasiz. Default VPC'ni o'chirmang: u bepul va keyingi darslarda kerak.

### S3 ni bo'shatish

Bucket faqat bo'sh bo'lsa o'chadi. Versioning yoqilgan bucket'da `aws s3 rm --recursive` faqat delete marker qo'yadi, eski versiyalar qoladi va bucket "bo'sh ko'rinib" turib o'chmaydi. Hamma versiya va delete marker'lar o'chirilishi kerak: konsoldagi "Empty" tugmasi yoki joriy bo'lmagan versiyalarni o'chiradigan lifecycle qoidasi shuni qiladi, CLI da esa `list-object-versions` chiqishidagi har juftlik (`Key`, `VersionId`) `aws s3api delete-object --version-id` ga beriladi.

### Qolmaganini tekshirish

"O'chirdim" degan his isbot emas. Tekshirish uchun buyruqlar: `aws ec2 describe-instances`, `describe-volumes`, `describe-snapshots --owner-ids self` (bu filtrsiz hamma ochiq snapshot'lar chiqadi), `describe-addresses`, `describe-nat-gateways`, `describe-vpcs`, `aws s3 ls`, va tag bo'yicha: `aws resourcegroupstaggingapi get-resources --tag-filters Key=project,Values=devops-course`. Ikki nozik joy bor. Birinchisi: EC2 buyruqlari faqat bitta regionni ko'rsatadi, to'liq tekshiruv yoqilgan barcha regionlarni aylanadi. Regionlar ro'yxati va aylanish shakli (misol key pair'lar uchun):

```
for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  echo "== $r"
  aws ec2 describe-key-pairs --region "$r" --query 'KeyPairs[].KeyName' --output text
done
```

`describe-regions` akkauntda yoqilgan regionlarni qaytaradi, `--region` bitta buyruq uchun regionni almashtiradi. Bu sikl bash 3.2 da ham ishlaydi. Ikkinchisi: terminate qilingan instans ro'yxatda yana taxminan bir soat `terminated` holatida ko'rinadi (pul olmaydi), shuning uchun tekshiruvda holat bo'yicha filtr kerak: `--filters Name=instance-state-name,Values=pending,running,stopping,stopped`.

### Boshqa provayderlardagi mosliklar

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| VM | EC2 instance | Compute Engine VM | Virtual Machine | Droplet | Server |
| Image | AMI | Image | Image | Image, Snapshot | Image, Snapshot |
| Birinchi yuklanish skripti | User data (cloud-init) | Startup script, cloud-init | Custom data (cloud-init) | User data (cloud-init) | User data (cloud-init) |
| Blok disk | EBS | Persistent Disk | Managed Disk | Volume | Volume |
| Tarmoq | VPC (region) | VPC (global, subnet region) | VNet (region) | VPC (region) | Network |
| Firewall | Security group | Firewall rules | Network Security Group | Cloud Firewall | Firewall |
| Statik IP | Elastic IP | Static external IP | Public IP (static) | Reserved IP | Primary IP, Floating IP |
| Object storage | S3 | Cloud Storage | Blob Storage | Spaces (S3 API) | Object Storage (S3 API) |

cloud-init deyarli hamma joyda bir xil ishlaydi, S3 API esa ko'p provayderda qo'llab-quvvatlanadi: `aws s3 --endpoint-url ...` bilan boshqa provayder omboriga ham ulanish mumkin.

### Real ishda qachon kerak

- Har test muhiti, har demo, har "bir sinab ko'ray" oxirida. Unutilgan resurslar cloud hisobining eng oddiy va eng ko'p uchraydigan sababi.
- Terraform (`terraform destroy`) shu tartibni o'zi hisoblaydi, lekin u faqat o'zi yaratgan narsani biladi: qo'lda yaratilganini baribir shu buyruqlar bilan topasiz.

### Nima uchun shunday

AWS bog'liq resurslarni zanjir qilib o'zi o'chirmaydi (VPC bilan birga ichidagi hamma narsani), chunki noto'g'ri bitta buyruq production'ni yo'q qilishi mumkin edi: har resurs alohida, ongli ravishda o'chiriladi. Tag va regionlar bo'ylab aylanish esa "bitta umumiy ro'yxat" yo'qligining o'rnini bosadi: har xizmat va har region o'z API'siga ega, shu sabab tozalikni isbotlaydigan skript har loyihada yoziladi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| EC2 instans | AWS'da ijaraga olingan bitta virtual mashina |
| AMI | instansning root diski yaratiladigan image, ID si regionga xos |
| Instance type | instansning vCPU, xotira va arxitekturasini belgilaydigan o'lcham nomi |
| Burstable | CPU kreditini to'plab, yuklamada sarflaydigan instans oilasi (`t`) |
| Key pair | AWS'da saqlanadigan SSH public key, birinchi yuklanishda instansga yoziladi |
| User data | instans yaratishda beriladigan, birinchi yuklanishda bajariladigan skript yoki cloud-config |
| cloud-init | cloud image ichidagi, birinchi yuklanishda tizimni sozlaydigan dastur |
| IMDS | instans ichidan `169.254.169.254` da ochiladigan metadata xizmati; IMDSv2 token talab qiladi |
| EBS volume | tarmoq orqali ulangan, bitta AZ ga tegishli blok disk |
| Snapshot | volume'ning region darajasida saqlanadigan nusxasi |
| Stop / terminate | instansni o'chirib qo'yish (disk qoladi) / butunlay yo'q qilish |
| VPC | akkauntdagi o'z CIDR blokiga ega izolyatsiya qilingan virtual tarmoq |
| Subnet | VPC CIDR'ining bitta AZ da yashaydigan qismi |
| Route table | subnet'dan chiqqan paket qayerga borishini belgilaydigan yo'llar ro'yxati |
| Internet gateway | VPC'ni internetga ulaydigan va public IP'ni private'ga almashtiradigan obyekt |
| NAT gateway | private subnet'ga faqat chiquvchi internet beradigan pullik xizmat |
| Security group | instans darajasidagi stateful, faqat allow qoidali firewall |
| Network ACL | subnet darajasidagi stateless, raqamlangan allow va deny qoidali firewall |
| Elastic IP | akkauntga tegishli o'zgarmas public IPv4 manzil |
| Bastion | private serverlarga kirish uchun public subnet'dagi oraliq SSH hosti |
| Bucket / object | S3 dagi idish / undagi kalit, ma'lumot va metadata uchligi |
| Storage class | obyektning saqlash narxi va o'qish sharti darajasi |
| Versioning | har yozishda yangi versiya saqlaydigan bucket sozlamasi |
| Delete marker | versioning'li bucket'da "o'chirilgan" degan belgi-versiya |
| Lifecycle | obyektlarni yoshiga qarab ko'chiradigan yoki o'chiradigan qoidalar |
| Block Public Access | policy va ACL'dan ustun turadigan public kirish to'sig'i |
| Bucket policy | bucket'ga yopishtirilgan, kim kira olishini aytadigan resource-based policy |
| Presigned URL | ichida imzo va muddat bo'lgan, bitta amalga ruxsat beradigan vaqtinchalik URL |
| Instance profile | IAM role'ni EC2 instansga ulaydigan obyekt |
| Tag | resursga yopishtiriladigan kalit-qiymat yorlig'i |

## Tuzoqlar

- SSH portini `0.0.0.0/0` ga ochish yoki "vaqtincha" hamma portni ochib unutish.
- Instansni stop qilib "o'chirdim" deb o'ylash: disk va Elastic IP pul olishda davom etadi.
- Qo'shimcha EBS volume va snapshot'larni instans bilan birga o'chadi deb o'ylash.
- Bo'sh turgan Elastic IP va unutilgan NAT gateway.
- Boshqa regionda yaratilgan resursni ko'rmaslik: konsol va CLI faqat joriy regionni ko'rsatadi.
- User data'ga secret yozish: u instans ichidan va API orqali o'qiladi.
- AMI ID ni skriptga qotirib yozish: boshqa regionda ishlamaydi, vaqt o'tib eskiradi.
- Private key'ni (`.pem`) repozitoriyga yoki ish papkasiga qo'yish.
- Versioning'ni lifecycle'siz yoqish: ko'rinmas eski versiyalar yillar davomida to'planadi.
- Kirish muammosini Block Public Access'ni o'chirib yoki `"Principal": "*"` bilan "hal qilish".
- Ofisda ochilgan SSH qoidasi uyda ishlamaydi (IP boshqa); "tezroq bo'lsin" deb `0.0.0.0/0` yozish o'rniga yangi IP uchun qoida qo'shing va eskisini olib tashlang.
- `AWS_REGION` yangi terminal oynasida yo'q: buyruq boshqa (profildagi) regionga ketadi va "resurs yo'qolib qoldi" degan taassurot beradi.
- Instans `running` bo'ldi degani user data tugadi degani emas; xatoni `/var/log/cloud-init-output.log` dan qidiring.
- Bucket policy'da `Resource` ga faqat bucket ARN'ini yoki faqat `/*` ni yozish: amallarning yarmi jimgina mos kelmaydi.
- Private key'ni ikkinchi mashinaga xabar yoki bulutli disk orqali ko'chirish: har mashinaga o'z kaliti.

## Manbalar

- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html – EC2 User Guide
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html – user data va cloud-init
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html – instance metadata, IMDSv2
- https://cloudinit.readthedocs.io/en/latest/ – cloud-init hujjati
- https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html – VPC qanday ishlaydi (majburiy)
- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html va https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html – security group va NACL
- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html – NAT gateway
- https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html – EBS
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html – S3 User Guide
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html – Block Public Access
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html – lifecycle
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html – static website hosting
- https://docs.aws.amazon.com/cli/latest/reference/ec2/ va https://docs.aws.amazon.com/cli/latest/reference/s3/ – CLI reference
- https://aws.amazon.com/ec2/pricing/, https://aws.amazon.com/vpc/pricing/, https://aws.amazon.com/s3/pricing/ – narxlar
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html – EC2 uchun IAM role va instance profile
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html – presigned URL
- https://aws.amazon.com/free/ – free tier shartlari

## Birga bajaramiz

Bitta yaxlit misol: hech qanday porti ochilmagan, kalitsiz "bir martalik ishchi" instans. U birinchi yuklanishda cloud-config bo'yicha ish bajaradi, biz esa unga umuman kirmasdan, natijani tashqaridan API orqali kuzatamiz, keyin hammasini o'chirib, qolmaganini isbotlaymiz. Yo'lda bitta bucket ham yaratiladi. Hamma buyruqlar host'da, default VPC'da; fayllar repodan tashqarida (`~/walk/`).

1. Tekshiruv va o'zgaruvchilar. Region berilgan, kim ekanim ma'lum, budget joyida:

```
$ export AWS_REGION=<region>
$ aws sts get-caller-identity --query Arn --output text
arn:aws:iam::<ACCOUNT_ID>:user/<admin>
$ aws budgets describe-budgets --account-id <ACCOUNT_ID> --query 'Budgets[].BudgetName' --output text
<budget-nomi>
$ TAGS='Tags=[{Key=project,Value=devops-course}]'
$ AMI=$(aws ssm get-parameters \
    --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query 'Parameters[0].Value' --output text)
```

Tipni 1-bo'limdagi buyruq bilan tanlang; `arm64` tip tanlasangiz yo'ldagi `amd64` ham `arm64` bo'ladi.

2. Kiruvchi qoidasi yo'q security group. `--vpc-id` berilmagani uchun u default VPC'da yaratiladi:

```
$ SG=$(aws ec2 create-security-group --group-name walk-closed \
    --description "no inbound rules" \
    --tag-specifications "ResourceType=security-group,$TAGS" \
    --query GroupId --output text)
$ echo "$SG"
sg-<...>
```

3. User data. `~/walk/walk.yaml` fayli, `runcmd` birinchi yuklanish oxirida buyruq bajaradi:

```
#cloud-config
runcmd:
  - echo "walk-marker boot finished on $(hostname)"
```

4. Instans. Key pair berilmaydi (kirmaymiz), tag instansga ham, uning root volume'iga ham qo'yiladi:

```
$ IID=$(aws ec2 run-instances --image-id "$AMI" --instance-type <tip> \
    --security-group-ids "$SG" --user-data file://walk.yaml \
    --tag-specifications "ResourceType=instance,$TAGS" "ResourceType=volume,$TAGS" \
    --query 'Instances[0].InstanceId' --output text)
$ aws ec2 wait instance-running --instance-ids "$IID"
$ aws ec2 describe-instances --instance-ids "$IID" --output text \
    --query 'Reservations[].Instances[].[State.Name,PublicIpAddress,PrivateIpAddress,Placement.AvailabilityZone]'
running    <public-ip>    172.31.<...>    <region>b
```

`wait` holat `running` bo'lguncha qaytmaydi. Chiqish: holat, avtomatik public IP (default subnet'da "auto-assign" yoqilgan), default VPC oralig'idagi private IP va AWS o'zi tanlagan AZ. Public IP bor, lekin SG da kiruvchi qoida yo'q: unga `ssh` ham, `ping` ham yetib bormaydi.

5. Ichkariga kirmasdan kuzatish. Instansning serial konsoliga chiqqan matnni API beradi (matn bir necha daqiqa kechikishi mumkin; `--latest` faqat Nitro avlodidagi tiplarda, masalan `t3` va `t4g` da ishlaydi, xato bersa olib tashlang):

```
$ aws ec2 get-console-output --instance-id "$IID" --latest --output text | grep -E 'walk-marker|finished at'
[   <N>] cloud-init[<PID>]: walk-marker boot finished on ip-172-31-<...>
[   <N>] cloud-init[<PID>]: Cloud-init v. <versiya> finished at <sana>. Datasource DataSourceEc2Local.  Up <N> seconds
```

Har qator boshidagi `[   <N>]` yuklanishdan beri o'tgan soniyalar, `cloud-init[<PID>]` esa qatorni konsolga yozgan jarayon (old qo'shimchaning aniq ko'rinishi image versiyasiga qarab farq qilishi mumkin, muhimi qatorning oxiri). Birinchi qator bizning `runcmd` ning chiqishi: user data bajarilgan, hostname private IP'dan yasalgan. Ikkinchisi cloud-init tugaganini bildiradi. Hech narsa chiqmasa bir-ikki daqiqa kutib buyruqni takrorlang. Kiruvchi port yopiq bo'lsa ham instans metadata'dan user data'ni oldi, chunki SG chiquvchi trafikni cheklamaydi va metadata xizmati instansning o'z ichidan ochiladi.

6. Bucket va obyekt metadata'si:

```
$ B=walk-<suffix>
$ aws s3 mb "s3://$B"
make_bucket: walk-<suffix>
$ aws s3 cp walk.yaml "s3://$B/configs/walk.yaml"
upload: ./walk.yaml to s3://walk-<suffix>/configs/walk.yaml
$ aws s3api head-object --bucket "$B" --key configs/walk.yaml \
    --query '[ContentLength,ContentType,ServerSideEncryption]' --output text
<N>    <content-type>    AES256
```

`head-object` ma'lumotni yuklamay faqat metadata'ni oladi: hajm baytda, `Content-Type` (CLI fayl kengaytmasidan taxmin qiladi) va shifrlash turi (`AES256`: S3 yangi obyektlarni standart holatda o'zi shifrlaydi).

7. Tozalash, teskari tartibda:

```
$ aws ec2 terminate-instances --instance-ids "$IID" --query 'TerminatingInstances[].CurrentState.Name' --output text
shutting-down
$ aws ec2 wait instance-terminated --instance-ids "$IID"
$ aws ec2 delete-security-group --group-id "$SG"
$ aws s3 rm "s3://$B" --recursive
delete: s3://walk-<suffix>/configs/walk.yaml
$ aws s3 rb "s3://$B"
remove_bucket: walk-<suffix>
```

SG ni `wait` dan oldin o'chirishga urinsangiz `DependencyViolation` chiqadi: instans hali uni ushlab turibdi. Bucket'da versioning yoqilmagan, shuning uchun `rm --recursive` yetarli.

8. Isbot. Uchala buyruq ham bo'sh chiqish berishi kerak:

```
$ aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text \
    --filters Name=tag:project,Values=devops-course Name=instance-state-name,Values=pending,running,stopping,stopped
$ aws ec2 describe-volumes --filters Name=tag:project,Values=devops-course --query 'Volumes[].VolumeId' --output text
$ aws s3 ls | grep walk-
```

Root volume instans bilan birga o'chdi (`DeleteOnTermination`), public IP qaytarib olindi, key pair yaratilmagan edi.

Shu 8 qadamda ko'rganingiz: AMI ID qotirilmay so'raldi, user data va cloud-init serverni odam qo'lisiz sozladi, metadata ichkaridan ochildi (1-bo'lim); default subnet'ning uch sharti bajarilgan bo'lsa ham SG yopiq instansga yo'l yo'q, SG faqat kiruvchini to'sdi (2-bo'lim); obyekt kalit, ma'lumot va metadata'dan iborat, `/` kalitning qismi (3-bo'lim); o'chirish tartibi bog'liqlikka bo'ysunadi va tozalik buyruq bilan isbotlanadi (4-bo'lim).

---

## Vazifalar

Ish papkasi: `cloud/03-resources/` (`make new m=cloud n=03 name=resources` bilan host'da yarating). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar yoki konsol qadamlari, natijaning muhim qismi va o'z so'zingiz bilan izoh; buyruq host'da yoki instans ichida bajarilgani ko'rinib tursin. So'ralgan fayllar (skript, policy JSON, user data) shu papkada saqlanadi. Private key, access key, account ID va public IP'laringizni yozmang (`<ACCOUNT_ID>`, `<MY_IP>` deb almashtiring). Har mashg'ulot boshida identifikatsiya, region va budget'ni tekshiring, oxirida instanslarni terminate qiling. Vazifani qaysi mashinada boshlagan bo'lsangiz ham davom ettira olasiz: resurslar umumiy, faqat key pair va SSH qoidasidagi IP mashinaga xos ("Ikkinchi mashinada nimani takrorlash kerak").

### A. EC2

1. **Preflight.** `aws sts get-caller-identity`, budget'lar ro'yxati va `AWS_REGION` ni tekshiring. Akkauntingizda free tier'ga kiradigan instans tiplarini buyruq bilan aniqlang va bittasini tanlang. EC2 narx sahifasidan shu tipning tanlangan regiondagi soatlik narxini, EBS va public IPv4 narxini sana bilan yozing: bu dars eng yomon holatda (hammasi 4 kun ishlab qolsa) qanchaga tushadi? Yo'nalish: Laboratoriya va 1-bo'lim, "Instance type va arxitektura".

2. **Launch from the console.** Konsolda default VPC'da bitta Ubuntu 24.04 instans yarating: eng kichik tip, o'z key pair'ingiz, yangi security group (SSH faqat sizning IP'dan), `project=devops-course` tag. SSH bilan kiring. Launch wizard'dagi har bo'lim 1-bo'limdagi jadvalning qaysi qatoriga mos keladi? Instans ichida `lsblk`, `ip -4 addr`, `ip route` natijalarini yozing: public IP interfeysda ko'rinadimi, nima uchun? Yo'nalish: 1-bo'lim boshidagi jadval va 2-bo'lim, "Public va private subnet".

3. **Instance metadata.** Instans ichidan IMDSv2 orqali `instance-id`, `instance-type`, `placement/availability-zone` va `public-ipv4` ni oling. Token'siz so'rov yuborsangiz qanday HTTP status qaytadi? Bu xizmatga instansdan tashqaridan kirib bo'ladimi, `169.254.0.0/16` qanday manzil oralig'i (network moduli)? Yo'nalish: 1-bo'lim, "Instance metadata (IMDS)".

4. **Stop and start.** Instansni stop qiling, keyin start qiling. Public IP, private IP va instans ID dan qaysilari o'zgardi? Stop holatida `aws ec2 describe-volumes` nima ko'rsatadi va shu paytda nima uchun pul olinadi? Instansni terminate qiling va root volume taqdirini tekshiring. Yo'nalish: 1-bo'lim, "Hayot sikli va EBS".

5. **Launch from the CLI.** Xuddi shunday instansni faqat CLI bilan yarating: AMI ID ni SSM parametridan oling, public key'ni `import-key-pair` bilan yuklang, security group yarating va faqat o'z IP'ingizga 22-portni oching, `run-instances` da tag bering, `aws ec2 wait instance-running` dan keyin public IP ni `--query` bilan oling va SSH qiling. Buyruqlarni `task_5.sh` ga yozing (ID'lar o'zgaruvchilarda, qotirib yozilmagan). Yo'nalish: 1-bo'lim, "AMI", "Key pair", "Security group". Key pair nomi shu mashinaniki (`lab-zorin` yoki `lab-mac`), skript ikkala mashinada ishlaydigan portable bash bo'lsin.

6. **Security group behavior.** Instansda `python3 -m http.server 8080` ishga tushiring. Ish mashinasidan `curl` qiling: nima bo'ladi, timeout yoki "connection refused"? SG ga 8080 ni o'z IP'ingiz uchun oching, takrorlang. Serverni to'xtatib yana `curl` qiling. Uch holatdagi xato turini izohlang (network modulidagi DROP va REJECT farqi). Instansdan tashqariga `curl https://example.com` ishlaydi, kiruvchi qoidasiz ham javob qaytadi: nima uchun? Yo'nalish: 1-bo'lim, "Security group"; network 6-dars.

7. **User data.** `task_7.sh` user data skripti yozing: nginx o'rnatib, sahifada instans ID va AZ ni (metadata'dan) ko'rsatsin. Instansni shu user data bilan CLI orqali yarating (`--user-data file://task_7.sh`), SG da 80-portni oching, SSH qilmasdan `curl` bilan tekshiring. Keyin instansga kirib `/var/log/cloud-init-output.log` va `cloud-init status` ni ko'ring. Skriptga ataylab xato buyruq qo'shib yangi instans yarating: xatoni qayerdan topdingiz? Yo'nalish: 1-bo'lim, "User data va cloud-init" va "Instance metadata (IMDS)".

8. **EBS volume.** Instans AZ sida 1 GB `gp3` volume yarating va ulang. Instansda uni toping, `ext4` qilib formatlang, mount qiling, fayl yozing. Volume'dan snapshot oling. Instansni terminate qiling: volume qaysi holatda qoldi? Boshqa AZ da volume yaratishga urinib uni instansga ulab ko'ring va xatoni yozing. Oxirida volume va snapshot'ni o'chiring. Yo'nalish: 1-bo'lim, "Hayot sikli va EBS"; linux 13-dars. Formatlash va mount faqat instans ichida.

### B. Tarmoq

9. **Inspect the default VPC.** Default VPC'ning CIDR'ini, subnet'larini (AZ va CIDR bilan), route table'ini va internet gateway'ini CLI bilan chiqaring. 2-bo'limdagi "public subnet uch sharti" ning har biri default VPC'da qayerda bajarilganini ko'rsating. Yo'nalish: 2-bo'lim, "Public va private subnet".

10. **Build a VPC.** CLI bilan o'z VPC'ingizni quring: `10.0.0.0/16`, bitta public subnet (`10.0.1.0/24`) va bitta private subnet (`10.0.2.0/24`), internet gateway, public subnet uchun alohida route table (`0.0.0.0/0` IGW ga), private subnet main route table'da qoladi. Hammasiga tag. Buyruqlarni `task_10.sh` ga yozing va tuzilmani matnli diagramma bilan `README.md` da chizing. Yo'nalish: 2-bo'lim, "Mexanizm: o'sha tarmoq, faqat API obyektlari".

11. **Break the public subnet.** Public subnet'da instans yarating (public IP bilan) va SSH ishlashini tekshiring. Keyin uch shartni navbat bilan buzing va har safar nima bo'lishini yozing, so'ng tiklang: (a) route table'dan `0.0.0.0/0` yo'lini o'chirish, (b) public IP'siz instans yaratish, (c) SG dan SSH qoidasini olib tashlash. Uchala holatda ish mashinasidagi alomat bir xilmi? Qaysi qatlam buzilganini qanday buyruqlar bilan aniqlash mumkin? Yo'nalish: 2-bo'lim, "Public va private subnet".

12. **Private instance.** Private subnet'da ikkinchi instans yarating. Uning SG sida SSH manbasi sifatida CIDR emas, public instansning security group ID sini ko'rsating. `ssh -J` bilan public instans orqali kiring (private key'ni bastion'ga nusxalamang). Private instansda `sudo apt-get update` ishlating: nima bo'ladi va nima uchun? `ip route` instans ichida va VPC route table orasidagi farqni izohlang. Yo'nalish: 2-bo'lim, "Public va private subnet" va "NAT gateway".

13. **NAT gateway cost.** NAT gateway yaratmang. VPC narx sahifasidan tanlangan region uchun NAT gateway'ning soatlik va GB narxini, public IPv4 narxini oling va hisoblang: bir oy davomida unutilgan, 50 GB trafik o'tkazgan bitta NAT gateway qanchaga tushadi (manba va sana bilan). Kichik loyihada private instanslarga internet berishning ikkita arzonroq muqobilini toping va kamchiliklarini yozing. Yo'nalish: 2-bo'lim, "NAT gateway".

14. **NACL is stateless.** Public subnet uchun yangi network ACL yarating va biriktiring (yangi NACL standart hammasini rad etadi). Faqat kiruvchi 22-portga ruxsat bering: SSH ishlaydimi? Nima yetishmayotganini aniqlang va minimal qoidalar to'plamini yozing. SG bilan xuddi shu natija uchun nechta qoida kerak bo'lgan edi? Oxirida subnet'ni default NACL ga qaytaring va o'zingiznikini o'chiring. Yo'nalish: 2-bo'lim, "Security group va Network ACL".

15. **Elastic IP.** Elastic IP ajrating va public instansga ulang. Instansni stop/start qiling: manzil saqlandimi? EIP ni uzing (disassociate), `aws ec2 describe-addresses` da ulanmagan holatini ko'rsating, keyin release qiling. Ulanmagan EIP nima uchun pul oladi? Yo'nalish: 2-bo'lim, "Elastic IP va public IPv4".

### C. S3

16. **Bucket basics.** Konsolda `devops-course-<noyob-qo'shimcha>` nomli bucket yarating, bitta fayl yuklang. Keyin CLI bilan: ikkinchi bucket yarating (`aws s3 mb`), `aws s3 sync` bilan kichik katalogni yuklang, `ls --recursive`, bitta faylni o'zgartirib qayta `sync` qiling (nima yuklandi?), `sync --delete` nima qilishini `--dryrun` bilan ko'rsating. Band nom bilan (masalan `test`) bucket yaratishga urinib xatoni yozing. Yo'nalish: 3-bo'lim boshi.

17. **Versioning and lifecycle.** Bucket'da versioning yoqing. Bitta faylni uch marta turli mazmun bilan yuklang, keyin `aws s3 rm` bilan o'chiring. `aws s3 ls` va `aws s3api list-object-versions` natijalarini solishtiring: delete marker qayerda? Ikkinchi versiyani `--version-id` bilan tiklang (yuklab oling). `task_17.json` lifecycle konfiguratsiyasi yozing: joriy bo'lmagan versiyalar 7 kundan keyin o'chsin, tugallanmagan multipart upload'lar 1 kundan keyin tozalansin. Uni qo'llang va `get-bucket-lifecycle-configuration` bilan tekshiring. Yo'nalish: 3-bo'lim, "Versioning va lifecycle".

18. **Access layers.** 2-darsdagi kabi policy'siz `lab-s3` IAM user va profil yarating. (a) Shu profil bilan bucket'ni o'qishga uringing. (b) `task_18.json` bucket policy yozing: faqat shu user'ga faqat `reports/` prefiksidagi obyektlarni o'qish va ro'yxatini ko'rish. Qo'llang, `reports/a.txt` va `private/b.txt` ni o'qib ko'ring. (c) Bucket policy'ga `aws:SecureTransport` sharti bilan `Deny` qo'shing va `aws s3api get-object ... --endpoint-url http://s3.<region>.amazonaws.com` bilan tekshiring. Har bosqichdagi xato va muvaffaqiyatni baholash mantiqi bilan izohlang. Yo'nalish: 3-bo'lim, "Kirish nazorati"; 2-dars (policy baholanishi).

19. **Presigned URL.** Private obyekt uchun 60 soniyalik presigned URL yarating. `curl` bilan darhol va 2 daqiqadan keyin so'rov yuboring, ikkinchi javobdagi xato kodini yozing. URL parametrlarini (`X-Amz-Expires`, `X-Amz-Credential`, `X-Amz-Signature`) izohlang. URL'dagi obyekt kalitini o'zgartirib so'rov yuboring: nima bo'ladi va nima uchun? Frontend'dan to'g'ridan-to'g'ri yuklash uchun bu mexanizm qanday ishlatiladi? Yo'nalish: 3-bo'lim, "Presigned URL".

20. **Static website.** Alohida bucket'da statik sayt joylang: `index.html` va `error.html`, website hosting'ni yoqing, website endpoint'ni `curl` qiling (hali 403). Bucket uchun Block Public Access'ni o'chiring va public o'qish bucket policy'sini (`task_20.json`) qo'ying, yana `curl` qiling. Mavjud bo'lmagan yo'lni so'rang. `curl -I https://...` website endpoint'da ishlaydimi? Tugagach darhol BPA ni qayta yoqing va policy'ni o'chiring. Production'da HTTPS va private bucket uchun nima qilinadi? Yo'nalish: 3-bo'lim, "Static website hosting".

### D. Integratsiya va tozalash

21. **Instance role to S3.** Mini-loyiha. Access key'siz ishlaydigan zanjir quring: faqat bitta bucket'ning `uploads/` prefiksiga yozish va o'qishga ruxsat beruvchi policy (`task_21.json`) bilan IAM role, uni instance profile orqali o'z VPC'ingizdagi public instansga biriktiring. Instansda AWS CLI o'rnating (rasmiy qo'llanma bo'yicha) va `aws sts get-caller-identity` natijasidagi `Arn` ni ko'rsating, `~/.aws/credentials` yo'qligini tekshiring. Instansdan `uploads/` ga fayl yozing, `reports/` ga yozishga urinib xatoni ko'ring. Credential qayerdan kelyapti (3-vazifani eslang) va uning muddati bormi? Yo'nalish: 3-bo'lim, "Instansdan S3 ga: IAM role va instance profile".

22. **Teardown and proof.** Hamma narsani 4-bo'limdagi tartibda o'chiring: instanslar, EIP, volume va snapshot'lar, o'z VPC'ingiz (IGW, subnet, route table, SG, NACL), key pair, IAM role, instance profile, `lab-s3` user, barcha bucket'lar (versiyalari bilan). Yo'lda uchragan `DependencyViolation` va `BucketNotEmpty` xatolarini yozing. Keyin `leftovers.sh` yozing: **barcha yoqilgan regionlarni** aylanib instans (terminated emas), volume, snapshot (o'zingizniki), Elastic IP, NAT gateway, default bo'lmagan VPC larni, hamda bir marta S3 bucket'lar va `project=devops-course` tag'li resurslarni chiqaradigan skript. Uning natijasi bo'sh bo'lishi kerak. Ertasi kuni Billing konsolidagi Bills sahifasini ko'rib, qaysi xizmatlar bo'yicha xarajat yozilganini qo'shing. Yo'nalish: 4-bo'lim. `leftovers.sh` portable bash bo'lsin: macOS'dagi bash 3.2 va BSD utilitalarida ham ishlashi kerak.

### Topshirish

Tayyor bo'lgach:
1. `cloud/03-resources/README.md` da 22 ta vazifa, har biri `## N. Title` ostida; papkada `task_5.sh`, `task_7.sh`, `task_10.sh`, `task_17.json`, `task_18.json`, `task_20.json`, `task_21.json` va `leftovers.sh`.
2. `leftovers.sh` natijasi bo'sh, natija `README.md` ga qo'yilgan. Default VPC joyida.
3. Budget alert kelmagan yoki kelgan bo'lsa sababi yozilgan. Bills sahifasidagi summa yozilgan.
4. Fayllarda private key, access key, account ID, public IP yo'q. `make check` toza (host'da).
5. Ikkala mashinada ham bu dars uchun import qilingan key pair'lar (`lab-zorin`, `lab-mac`) AWS'dan o'chirilgan; lokal `~/.ssh/` dagi kalitlar joyida.
6. Menga xabar bering, javoblaringizni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Subnet'ni public qiladigan uch shart nima? Bittasi yo'q bo'lsa alomat qanday?
- Security group stateful, NACL stateless degani amalda nimani anglatadi?
- Instans stop va terminate qilinganda nimalar qoladi va pul oladi?
- User data qachon va kim nomidan ishlaydi, unga nima yozilmaydi?
- EBS volume nima uchun boshqa AZ dagi instansga ulanmaydi, ma'lumotni qanday ko'chirasiz?
- NAT gateway nima uchun kerak va nima uchun laboratoriyada yaratilmadi?
- S3 nima uchun fayl tizimi emas? Bu qaysi yuklamalarga mos kelmasligini anglatadi?
- S3 da so'rov qaysi qatlamlardan o'tadi? Block Public Access bucket policy'dan qanday farq qiladi?
- Versioning yoqilgan bucket'da `rm` nima qiladi va bucket'ni to'liq bo'shatish uchun nima kerak?
- Presigned URL kimning nomidan ishlaydi va qachon o'z kuchini yo'qotadi?
- Instansdagi dastur S3 ga access key'siz qanday kiradi? Zanjirning to'rt bo'g'inini ayting.
- Ofisda yaratilgan instansga uydan kirish uchun nimalar yetishmaydi va toza yechim qanday?
- IAM policy va bucket policy orasidagi farq nima, `Resource` da nima uchun ikki ARN yoziladi?
