# 3-dars: IP manzillar

Maqsad: IP manzillashni hisob darajasida egallash: IPv4 manzil va prefiks (CIDR), subnet mask'ni qo'lda hisoblash, network va broadcast manzil, private va public diapazonlar (RFC 1918), maxsus diapazonlar (loopback, link-local), subnetting va VLSM, DHCP manzilni qanday tarqatishi, IPv6 asoslari. 1-darsda host "manzil o'z LAN'imdami yoki gateway'ga yuboraymi" degan qarorni qiladi deb aytilgan edi: bu qaror aynan subnet mask bilan hisoblanadi. Cloud modulida VPC va subnet yaratish, Kubernetes'da pod va service CIDR tanlash, 5-darsda routing table o'qish, 6-darsda firewall qoidasi yozish shu hisobga tayanadi. CIDR'ni kalkulyatorsiz o'qiy olmaslik DevOps'da doimiy to'siq.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va 1–3-vazifalar (faqat qog'oz va qalam). Ikkinchi kun 4–5 bo'limlar va 4–6-vazifalar. Uchinchi kun 6–7 bo'limlar, B guruh va 13–17-vazifalar (VM ichida). To'rtinchi kun 8-bo'lim, C guruh, "Birga bajaramiz" va 18-vazifa. Beshinchi kun 9-bo'lim va E guruh (manzil rejasi). Hisobni asbob bilan tekshiring, lekin avval qog'ozda bajaring: maqsad `/20` ni ko'rganda block size'ni xayolda ayta olish.

Qanday o'qish kerak: har hisob misolini avval o'zingiz qog'ozda yechib, keyin darsdagi qadamlar bilan solishtiring. Buyruqli misollarni `lab` VM ichida terib ko'ring. Sizdagi interfeys nomi, VM manzili va lease vaqtlari farq qiladi, darsda bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" qoidaning sababini aytadi.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` VM (Multipass, Ubuntu 24.04) kerak. `ip`, `ss`, `networkctl`, `tcpdump` buyruqlari macOS'da yo'q, Zorin'da esa host tarmog'ini buzish xavfi bor, shuning uchun hammasi VM ichida bajariladi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Qog'oz | | A guruh va har hisobning birinchi yechimi |
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `make`, `git`, `multipass`, `python3 -c` bilan hisobni tekshirish, ixtiyoriy kuzatuv |
| `lab` VM | `ubuntu@lab:~$` | B, C, D guruhlar: `ip`, `ss`, `networkctl`, `tcpdump`, `ipcalc`, VM ichidagi Docker |

VM ichida bir marta o'rnatiladi (host'da emas):

```
multipass shell lab
sudo apt update
sudo apt install -y ipcalc tcpdump
docker --version || sudo apt install -y docker.io   # Docker was installed in lesson 1
```

- `ipcalc` subnet kalkulyatori, faqat tekshirish uchun (4-bo'lim). Host'da o'rnatish shart emas: Python'ning standart `ipaddress` moduli ikkala host'da ham bor.
- Docker 1-darsdagidek **VM ichida** ishlatiladi. macOS'da host'dagi Docker yashirin Linux VM ichida ishlaydi, uning bridge'i va konteyner manzillari host'da ko'rinmaydi; VM ichidagi Docker'da ikkala mashinada bir xil ko'rinadi. 1-darsda `sudo usermod -aG docker ubuntu` qilinmagan bo'lsa, `docker` oldiga `sudo` qo'ying.
- Bu dars oldingi dars holatiga tayanmaydi. Mashinani almashtirsangiz, ikkinchi mashinadagi `lab` da yuqoridagi `apt install` ni qayta bajaring; javoblar git orqali ko'chadi.
- **Tozalash**: `sudo ip link del dummy0`, `docker rm -f` va `docker network rm tiny` (Topshirish bo'limida). VM buzilsa: `multipass stop lab && multipass restore lab.clean`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`, interfeysi odatda `ens3`, manzili odatda `10.x.x.x/24` (sizda boshqa bo'lishi mumkin). Host ham Linux: `ip -br addr` va `nmcli device show <iface>` ni host'da faqat o'qish uchun ishlatish mumkin (ixtiyoriy). Host'da manzil qo'shilmaydi va o'chirilmaydi. |
| macOS (uy) | VM `arm64`, interfeysi odatda `enp0s1`, manzili odatda `192.168.64.x/24` (sizda boshqa bo'lishi mumkin). Host'da `ip`, `ss`, `nmcli` yo'q. Ixtiyoriy kuzatuv uchun: `ifconfig en0` (manzil va mask, mask hex ko'rinishida: `0xffffff00`), `ipconfig getifaddr en0` (faqat IPv4 manzil), `ipconfig getpacket en0` (DHCP bergan sozlamalar). `en0` odatda Wi-Fi. |

VM manzili ikki host'da har xil diapazondan keladi, chunki Multipass har host'da o'z private tarmog'ini yaratadi. Shuning uchun darsda VM manzili `<VM IP>` deb yoziladi va vazifalarda "avval o'zingizdagini aniqlang" deyiladi.

---

## 1. IPv4 manzil: 32 bit

### Bu nima

IP manzil bu tarmoq qatlamida (2-dars, L3) hostning interfeysini aniqlaydigan son. 1-darsdagi MAC manzil faqat bitta LAN ichida ishlaydi, IP manzil esa paketni butun internet bo'ylab yetkazish uchun kerak. IPv4 manzil 32 bitli bitta son. Odam o'qishi uchun u to'rtta **oktet**ga (8 bitli bo'lak) bo'linib, har biri o'nlik sonda nuqta bilan yoziladi (dotted decimal):

```
192      .168      .10       .77
11000000  10101000  00001010  01001101
```

Har oktet 0–255 oralig'ida, chunki 8 bit bilan `2^8 = 256` ta qiymat yoziladi.

### Mexanizm: o'nlik va ikkilik orasida o'tish

Oktetdagi bitlarning og'irligi chapdan o'ngga: `128 64 32 16 8 4 2 1`. O'nlikdan ikkilikka: eng katta og'irlikdan boshlab "sig'adimi" deb so'raysiz, sig'sa 1 yozib ayirasiz.

```
200:  128 fits (rest 72) -> 1
       64 fits (rest 8)  -> 1
       32 no             -> 0
       16 no             -> 0
        8 fits (rest 0)  -> 1
        4, 2, 1 no       -> 0 0 0
200 = 11001000
```

Teskari yo'nalish: 1 turgan joylarning og'irliklarini qo'shasiz. `01001101 = 64 + 8 + 4 + 1 = 77`. JS'da tekshirish: `(200).toString(2)` va `parseInt('01001101', 2)`.

Kernel uchun nuqtalar yo'q: `192.168.10.77` bu bitta son, `3232238157`. Shuning uchun `ping 3232238157` ham ishlaydi, nuqtali yozuv faqat odam uchun.

### Ikki qism: network va host

Manzil ikki qismdan iborat: chapdagi bitlar **network** qismi (qaysi tarmoq), o'ngdagilari **host** qismi (shu tarmoq ichidagi qaysi qurilma). Bu telefon raqamidagi shahar kodi va abonent raqamiga o'xshaydi. Chegara qayerda ekanini manzilning o'zi aytmaydi, uni alohida son, **prefiks uzunligi** aytadi (2-bo'lim).

### Misol: VM'dagi manzil

```
ubuntu@lab:~$ ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
<iface>          UP             <VM IP>/24 metric 100 fe80::<...>/64
docker0          DOWN           172.17.0.1/16
```

Har qator: interfeys nomi, holati, manzillari (1-darsda `ip -br` ko'rilgan). `lo` da `127.0.0.1/8` va IPv6 `::1/128` (5 va 8-bo'limlar). Asosiy interfeysda `/24` prefiksli IPv4 manzil, `metric 100` (systemd-networkd DHCP manziliga qo'ygan ustuvorlik, 5-darsda) va `fe80::` bilan boshlanuvchi IPv6 link-local manzil. `docker0` da `172.17.0.1/16`: Docker'ning standart bridge'i, konteyner ishlamayotgani uchun `DOWN`. E'tibor bering: har manzil `/N` bilan birga yozilgan, prefiksiz manzil to'liq ma'lumot emas.

### Real ishda qachon kerak

- Firewall qoidasi, security group, `pg_hba.conf`, nginx `allow` direktivasi: hammasi manzil va prefiks ko'rinishida yoziladi.
- Log'dagi manzil qaysi subnet'dan (qaysi muhit, qaysi zona) kelganini aniqlash.

### Nima uchun shunday

32 bit 1981-yilda (RFC 791) tanlangan: taxminan 4.3 milliard manzil o'sha paytdagi bir necha yuz kompyuterli tarmoq uchun cheksiz ko'ringan. Nuqtali o'nlik yozuv bitlarni yashiradi, lekin subnet chegaralari bitlar bo'yicha o'tadi, shuning uchun bu darsda doim ikkilik ko'rinishga qaytamiz. Muqobili IPv6 (128 bit, hex yozuv), 8-bo'limda.

## 2. Prefiks, CIDR va subnet mask

### Bu nima

`192.168.10.77/26` yozuvida `/26` chapdan 26 bit network qismi, qolgan `32 - 26 = 6` bit host qismi degani. Bu yozuv **CIDR** (Classless Inter-Domain Routing) notatsiyasi deyiladi. Xuddi shu ma'lumotning eski ko'rinishi **subnet mask**: network bitlari 1, host bitlari 0 bo'lgan 32 bitli son.

```
address  192.168.10.77    11000000.10101000.00001010.01 001101
mask /26 255.255.255.192  11111111.11111111.11111111.11 000000
                          |<------ network 26 ------->| |host 6|
```

Mask'da birlar doim chapda uzluksiz turadi, shuning uchun mask oktetida faqat 9 ta qiymat uchraydi: `0, 128, 192, 224, 240, 248, 252, 254, 255` (0 dan 8 tagacha bir). Shu qatorni yodlash foydali.

### Mexanizm: ikki band manzil va sonlar

Subnet (subnetwork, bitta prefiks ostidagi manzillar to'plami) ichida ikki manzil hostga berilmaydi:

- **Network address**: host bitlari hammasi 0. Tarmoqning o'zini bildiradi, routing table'da shu yoziladi.
- **Broadcast address**: host bitlari hammasi 1. Shu subnet'dagi barcha hostlarga yuboriladigan paket manzili (1-darsdagi broadcast MAC `ff:ff:ff:ff:ff:ff` ning L3 dagi juftligi).

Formulalar: manzillar soni `2^(32 - prefiks)`, ishlatiladigan hostlar soni undan 2 ta kam.

| Prefiks | Mask | Host bitlari | Manzillar soni | Ishlatiladigan hostlar |
|---------|------|--------------|----------------|------------------------|
| /8 | 255.0.0.0 | 24 | 16 777 216 | 16 777 214 |
| /16 | 255.255.0.0 | 16 | 65 536 | 65 534 |
| /20 | 255.255.240.0 | 12 | 4 096 | 4 094 |
| /22 | 255.255.252.0 | 10 | 1 024 | 1 022 |
| /24 | 255.255.255.0 | 8 | 256 | 254 |
| /25 | 255.255.255.128 | 7 | 128 | 126 |
| /26 | 255.255.255.192 | 6 | 64 | 62 |
| /27 | 255.255.255.224 | 5 | 32 | 30 |
| /28 | 255.255.255.240 | 4 | 16 | 14 |
| /29 | 255.255.255.248 | 3 | 8 | 6 |
| /30 | 255.255.255.252 | 2 | 4 | 2 |
| /32 | 255.255.255.255 | 0 | 1 | bitta host |

Ikki istisno: `/32` bitta aniq hostni bildiradi (firewall qoidasida "faqat shu manzil"), `/31` esa ikki router orasidagi nuqtadan-nuqtaga link uchun (RFC 3021), unda network va broadcast ajratilmaydi.

Prefiks bittaga oshsa tarmoq teng ikkiga bo'linadi, bittaga kamaysa ikki qo'shni tarmoq birlashadi: `/24` = ikkita `/25` = to'rtta `/26`. Prefiks katta bo'lsa tarmoq kichik, bu boshida chalkashtiradi.

### Real ishda qachon kerak

- AWS'da VPC `10.0.0.0/16`, ichidagi subnet `10.0.1.0/24`: nechta instans sig'ishini shu jadval aytadi.
- `ifconfig` (macOS) va eski konfiguratsiyalar mask'ni `255.255.255.0` yoki `0xffffff00` deb ko'rsatadi, `ip` va cloud konsollari `/24` deb. Ikkalasini bir-biriga o'gira olish kerak.

### Nima uchun shunday

1993-yilgacha chegara manzilning birinchi bitlaridan aniqlangan (**classful** tizim): A sinf `/8`, B sinf `/16`, C sinf `/24`. 300 hostli tashkilotga C kam, B (65 534 host) esa isrof edi, manzillar tez tugay boshladi. CIDR chegarani istalgan bitga qo'yishga ruxsat berdi. "C class tarmoq" iborasini eshitsangiz, `/24` nazarda tutilgan, sinflarning o'zi endi ishlatilmaydi.

## 3. Qo'lda hisoblash: block size va AND

### Block size usuli

Savol har doim bir xil: manzil va prefiks berilgan, network, broadcast, birinchi va oxirgi host, hostlar soni topilsin. Ikkilikka o'tmasdan yechish usuli:

1. Prefiks qaysi oktetga tushishini aniqlang: /1–8 birinchi, /9–16 ikkinchi, /17–24 uchinchi, /25–32 to'rtinchi. Bu "qiziq oktet".
2. Qiziq oktetdagi mask qiymatini toping (2-bo'limdagi 9 ta qiymatdan) va **block size** = `256 - mask okteti` ni hisoblang. Bu shu oktetda subnet'lar necha qadam bilan boshlanishini aytadi ("magic number").
3. Network manzil: qiziq oktet block size'ning manzildagi qiymatdan oshmaydigan eng katta karralisi, undan o'ngdagi oktetlar 0, chapdagilar o'zgarmaydi.
4. Broadcast: qiziq oktet `network + block size - 1`, undan o'ngdagi oktetlar 255.
5. Birinchi host `network + 1`, oxirgi host `broadcast - 1`.

**Misol 1: `192.168.10.77/26`**

1. /26 to'rtinchi oktetda, mask okteti 192, block size `256 - 192 = 64`.
2. Bloklar: 0, 64, 128, 192. 77 qaysi blokda? 64–127.
3. Network `192.168.10.64`, broadcast `192.168.10.127`.
4. Hostlar `192.168.10.65` – `192.168.10.126`, `2^6 - 2 = 62` ta.

**Misol 2: `10.20.37.200/20`**

1. /20 uchinchi oktetda (16 + 4 bit), mask `255.255.240.0`, block size `256 - 240 = 16`.
2. Uchinchi oktet bloklari: 0, 16, 32, 48, ... 37 qaysi blokda? 32–47.
3. Network `10.20.32.0`, broadcast `10.20.47.255` (uchinchi oktet blok oxiri, to'rtinchi oktet to'liq 1).
4. Hostlar `10.20.32.1` – `10.20.47.254`, `2^12 - 2 = 4094` ta. E'tibor bering: `10.20.40.255` va `10.20.41.0` bu subnet'da oddiy host manzillari, chunki host bitlari 12 ta va ular hammasi 0 yoki hammasi 1 emas.

**Misol 3: `172.19.200.14/14`**

1. /14 ikkinchi oktetda (8 + 6 bit), mask `255.252.0.0`, block size `256 - 252 = 4`.
2. Ikkinchi oktet bloklari: ..., 12, 16, 20, ... 19 qaysi blokda? 16–19.
3. Network `172.16.0.0`, broadcast `172.19.255.255`, hostlar `172.16.0.1` – `172.19.255.254`, `2^18 - 2 = 262 142` ta.

### Bitlar bilan: AND

Block size usuli aslida bitta bit amalining qisqartmasi: network manzil = manzil `AND` mask. `AND` ikkala bit 1 bo'lgandagina 1 beradi, ya'ni mask'dagi 0 lar host bitlarini o'chiradi. Misol 1 ning to'rtinchi okteti:

```
77   = 01001101
192  = 11000000
AND  = 01000000 = 64
```

Bu JS'dagi `&` operatori bilan aynan bir xil amal. Node'da butun manzil uchun (`>>> 0` natijani ishorasiz 32 bitli songa aylantiradi, chunki JS bit amallari ishorali `int32` qaytaradi):

```
$ node -e 'const ip=(192<<24|168<<16|10<<8|77)>>>0, mask=(~0<<(32-26))>>>0, net=(ip&mask)>>>0; console.log(ip, mask, net, [24,16,8,0].map(s=>(net>>>s)&255).join("."))'
3232238157 4294967232 3232238144 192.168.10.64
```

Chiqish: manzil son sifatida, mask (`4294967232 = 0xFFFFFFC0`), ularning `AND` i va o'sha son nuqtali ko'rinishda.

### Host bu hisobni har paketda qiladi

Host paket yuborishdan oldin manzil IP'ni o'z mask'i bilan `AND` qiladi. Natija o'z network manziliga teng bo'lsa "bir LAN'da" deb ARP bilan MAC so'raydi (1-dars) va to'g'ridan-to'g'ri yuboradi, aks holda paketni gateway'ga (boshqa tarmoqlarga chiqish routeri, 5-darsda) beradi. `192.168.10.77/26` uchun `192.168.10.130` qo'shnimi?

```
192.168.10.130  last octet 10000010
mask /26                   11000000
AND                        10000000 = 128   -> network 192.168.10.128, not 192.168.10.64
```

Qo'shni emas: birinchi uchta oktet bir xil bo'lsa ham, paket gateway orqali ketadi.

**Tuzoq: ikki hostda mask har xil.** `192.168.1.10/24` va `192.168.1.200/25` bir kabelda. Birinchisi ikkinchisini o'z tarmog'ida deb to'g'ridan-to'g'ri yuboradi, ikkinchisi esa o'zini `192.168.1.128/25` da, birinchisini boshqa tarmoqda deb hisoblab javobni gateway'ga yuboradi. Natija: javob boshqa yo'ldan ketadi yoki yo'qoladi. Belgisi: "ping ba'zi hostlarga boradi, ba'zilariga yo'q".

### Real ishda qachon kerak

- "Bu ikki server bir subnet'dami?" savoli: bir subnet'da bo'lsa orada router va (odatda) firewall yo'q, bo'lmasa bor.
- Security group'ga `10.20.32.0/20` yozilgan: `10.20.48.5` dan kelgan so'rov o'tadimi? Block size bilan 5 soniyada javob beriladi.

### Nima uchun shunday

Chegara bit bo'yicha o'tgani uchun router yoki host bitta `AND` va bitta taqqoslash bilan qaror qiladi, bu har paketda bajariladigan eng arzon amal. Muqobili (manzillar ro'yxatini saqlash) millionlab paket uchun juda sekin bo'lardi. Block size faqat odam uchun qulaylik: `256 - mask` aslida host bitlari sig'diradigan qiymatlar soni.

## 4. Subnetting, VLSM va summarization

### Teng bo'lish

**Subnetting** bu berilgan blokni prefiksni uzaytirib kichikroq subnet'larga bo'lish. Prefiksga `n` bit qo'shilsa `2^n` ta teng subnet chiqadi. `172.30.64.0/23` ni to'rtta teng qismga bo'lish: to'rtta = `2^2`, yangi prefiks `/25`, block size to'rtinchi oktetda 128:

```
172.30.64.0/25     172.30.64.0   - 172.30.64.127
172.30.64.128/25   172.30.64.128 - 172.30.64.255
172.30.65.0/25     172.30.65.0   - 172.30.65.127
172.30.65.128/25   172.30.65.128 - 172.30.65.255
```

### VLSM: har xil hajmli subnet'lar

**VLSM** (Variable Length Subnet Mask) bitta blokni har xil prefiksli subnet'larga bo'lish. Qoida: ehtiyojlarni kattadan kichikka tartiblang va har biriga sig'adigan eng kichik blokni ketma-ket bering. Kattadan boshlash shart, chunki katta blok faqat o'z block size'ining karralisidan boshlana oladi.

`192.168.40.0/24` ni 100, 50, 20 hostli tarmoqlar va ikki router orasidagi linkka bo'lish:

| Ehtiyoj | Sig'adigan blok | CIDR | Diapazon | Hostlar |
|---------|-----------------|------|----------|---------|
| 100 host | 128 manzil (`/25`, 126 host) | `192.168.40.0/25` | `.0` – `.127` | `.1` – `.126` |
| 50 host | 64 manzil (`/26`, 62 host) | `192.168.40.128/26` | `.128` – `.191` | `.129` – `.190` |
| 20 host | 32 manzil (`/27`, 30 host) | `192.168.40.192/27` | `.192` – `.223` | `.193` – `.222` |
| 2 host | 4 manzil (`/30`, 2 host) | `192.168.40.224/30` | `.224` – `.227` | `.225` – `.226` |
| bo'sh | | | `.228` – `.255` | 28 manzil |

"Sig'adigan blok" ni tanlashda 2 band manzilni unutmang: 62 host kerak bo'lsa `/26` yetadi, 63 host uchun `/25` kerak.

### Summarization (supernetting)

Teskari amal: bir nechta qo'shni subnet'ni routing table'da bitta qisqaroq prefiks bilan ifodalash. `10.8.6.0/24` va `10.8.7.0/24` birlashadi: `10.8.6.0/23`. `10.8.5.0/24` va `10.8.6.0/24` esa qo'shni bo'lsa ham birlashmaydi. Sababi uchinchi oktet bitlarida:

```
5 = 0000010 1
6 = 0000011 0     first 7 bits differ (0000010 vs 0000011): not one /23
7 = 0000011 1     6 and 7 share the first 7 bits: one /23
```

`/23` uchinchi oktetda block size 2, bloklar juft sondan boshlanadi: 4–5, 6–7. Umumiy qoida: birlashtiriladigan bloklar soni 2 ning darajasi, qo'shni bo'lishi va birinchisi yangi block size'ning karralisidan boshlanishi kerak.

### Asbob bilan tekshirish

Qo'lda yechgandan keyin (oldin emas) tekshirasiz. VM'da `ipcalc`:

```
ubuntu@lab:~$ ipcalc 192.168.10.77/26
Address:   192.168.10.77        11000000.10101000.00001010.01 001101
Netmask:   255.255.255.192 = 26 11111111.11111111.11111111.11 000000
Wildcard:  0.0.0.63             00000000.00000000.00000000.00 111111
=>
Network:   192.168.10.64/26     11000000.10101000.00001010.01 000000
HostMin:   192.168.10.65        11000000.10101000.00001010.01 000001
HostMax:   192.168.10.126       11000000.10101000.00001010.01 111110
Broadcast: 192.168.10.127       11000000.10101000.00001010.01 111111
Hosts/Net: 62                    Class C, Private Internet
```

`Address` va `Netmask` kiritilgan qiymat, o'ngda ikkilik ko'rinish, bo'shliq network va host bitlari chegarasida turadi. `Wildcard` mask'ning teskarisi (host bitlari 1), ba'zi router va firewall sintaksislarida ishlatiladi. `=>` dan keyin natija: `Network`, `HostMin` (birinchi host), `HostMax` (oxirgi host), `Broadcast`, `Hosts/Net` va eslatma (eski sinf nomi, RFC 1918 diapazoni ekani). Hammasi Misol 1 bilan mos.

Ikkala host'da ham ishlaydigan yo'l, Python:

```
$ python3 -c "import ipaddress as i; n=i.ip_interface('10.20.37.200/20').network; print(n, n.broadcast_address, n.num_addresses)"
10.20.32.0/20 10.20.47.255 4096
$ python3 -c "import ipaddress as i; print(list(i.ip_network('172.30.64.0/23').subnets(new_prefix=25)))"
[IPv4Network('172.30.64.0/25'), IPv4Network('172.30.64.128/25'), IPv4Network('172.30.65.0/25'), IPv4Network('172.30.65.128/25')]
```

Birinchi buyruq: network, broadcast va manzillar soni (hostlar emas, 2 ta ko'p). Ikkinchisi teng bo'lish natijasi.

### Real ishda qachon kerak

- VPC `/16` ni zonalar va rollar bo'yicha `/20` yoki `/24` subnet'larga bo'lish (cloud moduli, 9-bo'lim).
- VPN yoki peering'da narigi tomonga o'nlab subnet o'rniga bitta summary prefiks e'lon qilish.

### Nima uchun shunday

Subnet chegaralari faqat 2 ning darajalarida bo'lishi `AND` mexanizmining narxi: 100 hostli tarmoqqa aynan 100 manzil berib bo'lmaydi, eng yaqini 128. Evaziga istalgan blok bitta "manzil + prefiks" jufti bilan yoziladi va routing table kichik qoladi. Internetning global routing jadvali aynan summarization tufayli boshqariladigan hajmda.

## 5. Maxsus diapazonlar

### Private manzillar (RFC 1918)

**Private** manzillar internetda route qilinmaydi: istalgan tashkilot ularni ichkarida erkin ishlatadi, shuning uchun dunyoda millionlab `192.168.1.10` bor. **Public** manzil esa internetda yagona. Private manzilli host tashqariga NAT orqali chiqadi (manzilni almashtirish, 6-darsda).

| Diapazon | Manzillar | Odatda qayerda |
|----------|-----------|----------------|
| `10.0.0.0/8` | 16.7 mln | korporativ tarmoq, cloud VPC, Kubernetes pod tarmoqlari |
| `172.16.0.0/12` | 1 048 576 (`172.16.0.0` – `172.31.255.255`) | Docker standart bridge'i (`172.17.0.0/16`), AWS default VPC (`172.31.0.0/16`) |
| `192.168.0.0/16` | 65 536 | uy routerlari (`192.168.0.0/24`, `192.168.1.0/24`) |

**Tuzoq: `172.16.0.0/12` chegarasi.** /12 ikkinchi oktetda block size 16, blok 16–31. Undan tashqaridagi `172.x` manzillar public. Firewall qoidasida `172.0.0.0/8` yozish xato: bu boshqalarning public manzillarini ham qamraydi.

### Boshqa maxsus diapazonlar

| Diapazon | Nomi | Ma'nosi |
|----------|------|---------|
| `127.0.0.0/8` | loopback | host o'zi bilan gaplashadi, paket tarmoq kartasiga chiqmaydi. `127.0.0.1` gina emas, butun /8 |
| `169.254.0.0/16` | link-local | DHCP javob bermaganda host o'zi tanlaydigan manzil, routerdan o'tmaydi. Cloud'da `169.254.169.254` instance metadata xizmati |
| `100.64.0.0/10` | CGNAT (RFC 6598) | provayderning ichki NAT'i uchun (`100.64.0.0` – `100.127.255.255`). Tailscale ham shu diapazonni ishlatadi |
| `0.0.0.0/0` | default route | "hamma manzil" (5-darsda). Bitta manzil sifatida `0.0.0.0`: "hali manzilim yo'q" yoki tinglashda "barcha interfeyslar" |
| `255.255.255.255` | limited broadcast | shu LAN'dagi hamma, routerdan o'tmaydi. DHCP Discover shunga ketadi |
| `224.0.0.0/4` | multicast | obuna bo'lgan hostlar guruhiga yuborish |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | documentation (RFC 5737) | misol va hujjatlar uchun, real tarmoqda ishlatilmaydi |

Qolgan hamma narsa public. Ularni IANA (global reyestr), mintaqaviy registrlar (RIPE NCC, ARIN va boshqalar) va provayderlar taqsimlaydi. Bo'sh IPv4 bloklar tugagan, shuning uchun cloud'da public IPv4 uchun alohida haq olinadi.

### Misol: loopback butun /8

```
ubuntu@lab:~$ ping -c 1 127.45.6.7
PING 127.45.6.7 (127.45.6.7) 56(84) bytes of data.
64 bytes from 127.45.6.7: icmp_seq=1 ttl=64 time=<N> ms
```

`lo` da `127.0.0.1/8` turibdi, demak butun `127.0.0.0/8` shu hostning o'zi: javob o'zingizdan keladi, `ttl=64` paket hech qaysi routerdan o'tmaganini bildiradi. Ubuntu'da DNS uchun `127.0.0.53` ishlatilishi (4-darsda) shu xususiyatga tayanadi.

### Real ishda qachon kerak

- Log'dagi manzil private bo'lsa so'rov ichki tarmoqdan yoki proxy/load balancer'dan kelgan, public bo'lsa internetdan.
- `169.254.x.x` olgan host: DHCP ishlamayapti (7-bo'lim). `100.64.x.x` ko'rsatgan uy routeri: provayder CGNAT ishlatadi, uyga tashqaridan port ochib bo'lmaydi.
- Hujjat va test yozganda real birovning manzili o'rniga `192.0.2.0/24` yoki `203.0.113.0/24` yoziladi.

### Nima uchun shunday

RFC 1918 (1996) IPv4 tanqisligiga javob: har qurilmaga public manzil yetmaydi, lekin ko'pchilik qurilmaga tashqaridan murojaat qilish kerak emas. Narxi: private diapazonlar yagona emas, ikki tashkilot bir xil `10.0.0.0/24` ni ishlatsa ularni to'g'ridan-to'g'ri ulab bo'lmaydi (9-bo'lim). Muqobili IPv6: manzil yetarli, har qurilma global manzil oladi.

## 6. Linux'da manzillar va tinglash manzili

### `ip addr` ni o'qish

```
ubuntu@lab:~$ ip addr show dev <iface>
2: <iface>: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc <qdisc> state UP group default qlen 1000
    link/ether 52:54:00:<...> brd ff:ff:ff:ff:ff:ff
    inet <VM IP>/24 metric 100 brd <VM tarmog'i>.255 scope global dynamic <iface>
       valid_lft <N>sec preferred_lft <N>sec
    inet6 fe80::<...>/64 scope link
       valid_lft forever preferred_lft forever
```

Birinchi ikki qator L2 (1-dars): interfeys holati va MAC. `inet` qatori IPv4: manzil va prefiks; `brd` shu subnet'ning broadcast manzili (qo'lda hisobingiz bilan solishtirsa bo'ladi); `scope global` manzil istalgan joyga yuborish uchun yaroqli (`scope link` faqat shu LAN, `scope host` faqat shu host, `lo` dagi kabi); `dynamic` manzil DHCP'dan olingan. `valid_lft` lease tugashiga qolgan soniyalar (7-bo'lim), qo'lda qo'shilgan manzilda `forever`. `inet6` qatori IPv6 link-local manzil (8-bo'lim).

### Manzil qo'shish va connected route

Tajriba uchun **dummy interfeys** qulay: u hech qayerga ulanmagan virtual interfeys, real tarmoqqa ta'sir qilmaydi.

```
ubuntu@lab:~$ sudo ip link add demo0 type dummy
ubuntu@lab:~$ sudo ip link set demo0 up
ubuntu@lab:~$ sudo ip addr add 10.99.5.1/24 brd + dev demo0
ubuntu@lab:~$ ip -4 -br addr show dev demo0
demo0            UNKNOWN        10.99.5.1/24
ubuntu@lab:~$ ip route | grep demo0
10.99.5.0/24 dev demo0 proto kernel scope link src 10.99.5.1
ubuntu@lab:~$ sudo ip link del demo0
```

`brd +` broadcast manzilni prefiksdan hisoblab qo'yishni so'raydi. `UNKNOWN` holati dummy uchun normal (kabel tushunchasi yo'q). Oxirgi qatordan oldingi chiqish muhim: manzil qo'shilganda kernel o'zi (`proto kernel`) **connected route** yaratadi. O'qilishi: "`10.99.5.0/24` subnet'i `demo0` da, to'g'ridan-to'g'ri yetib bo'ladi (`scope link`), manba manzil `10.99.5.1`". Network qismini kernel 3-bo'limdagi `AND` bilan hisoblagan. Routing table'ning asosi shu (5-darsda).

- Bitta interfeysda bir nechta manzil bo'lishi mumkin; bir subnet'dan ikkinchisi `secondary` deb belgilanadi.
- **Tuzoq: prefikssiz `ip addr add 10.99.5.1 dev demo0`.** Prefiks ko'rsatilmasa `/32` olinadi: subnet uchun connected route yaratilmaydi va host qo'shnilarini ko'rmaydi. Doim `/N` bilan yozing.
- `ip addr add` vaqtinchalik, reboot'dan keyin yo'q. Ubuntu server'da doimiy sozlama netplan'da (`/etc/netplan/*.yaml`; qo'llash `sudo netplan apply`, xavfsiz sinov `sudo netplan try`), desktop'da NetworkManager'da (`nmcli`).

### Tinglash manzili: `127.0.0.1` va `0.0.0.0`

Server dasturi portni ochganda qaysi manzilda tinglashini ham aytadi. VM'da tinglayotgan TCP socket'lar (`ss` batafsil 4-darsda):

```
ubuntu@lab:~$ ss -tln
State   Recv-Q  Send-Q   Local Address:Port    Peer Address:Port
LISTEN  0       4096     127.0.0.53%lo:53           0.0.0.0:*
LISTEN  0       4096        127.0.0.54:53           0.0.0.0:*
...
```

`Local Address:Port` ustuni muhim. `127.0.0.53%lo:53` va `127.0.0.54:53` lokal DNS xizmati: loopback manzilda tinglaydi, unga faqat shu VM ichidan ulanish mumkin. SSH qatori esa `0.0.0.0:22`, `[::]:22` yoki `*:22` ko'rinishida bo'ladi (versiyaga qarab): "barcha manzillarda", ya'ni tarmoqdan ham ulanib bo'ladi, `multipass shell` shu tufayli ishlaydi.

Bu Node'dan ma'lum narsa: `server.listen(3000, '127.0.0.1')` faqat o'sha mashinadan, `server.listen(3000, '0.0.0.0')` tarmoqdan ham ochadi. Vite va boshqa dev server'larning `--host` flag'i aynan shuni almashtiradi.

**Tuzoq: konteyner ichida `localhost` da tinglash.** Konteynerning o'z loopback'i bor (1-dars, network namespace). Ilova konteyner ichida `127.0.0.1` da tinglasa, port publish qilingan bo'lsa ham tashqaridan ulanib bo'lmaydi. Teskarisi xavfsizlik muammosi: ma'lumotlar bazasini bilmasdan `0.0.0.0` da ochib qo'yish.

### Real ishda qachon kerak

- "Servis ishlayapti, lekin ulanib bo'lmayapti": birinchi tekshiruv `ss -tln` da qaysi manzilda tinglayotgani.
- Serverga ikkinchi manzil (masalan, floating IP) qo'shish va uni kim e'lon qilayotganini ko'rish.

### Nima uchun shunday

Manzil hostga emas, interfeysga tegishli: router bir nechta tarmoqqa ulanadi va har birida o'z manzili bo'ladi. Shuning uchun dastur "qaysi manzilda tinglay" deb tanlay oladi, `0.0.0.0` esa "hammasida" degan qisqartma. Connected route'ni kernel o'zi yaratishi mantiqiy: manzil va prefiks berilgan bo'lsa, qo'shnilar qayerdaligi allaqachon ma'lum.

## 7. DHCP

### Bu nima

**DHCP** (Dynamic Host Configuration Protocol) hostga manzil va tarmoq sozlamalarini avtomatik beradi. U UDP ustida ishlaydi (ulanish o'rnatmaydigan transport, 4-darsda): server 67-port, mijoz 68-port. VM'ingiz ham manzilini shunday olgan: Multipass host'da kichik DHCP server ishlatadi.

### Mexanizm: DORA

Mijozda hali IP yo'q, server manzilini ham bilmaydi. Shuning uchun almashinuv broadcast bilan boshlanadi:

| Qadam | Kimdan kimga | Mazmuni |
|-------|--------------|---------|
| Discover | mijoz, `0.0.0.0` dan `255.255.255.255` ga | "DHCP server bormi?" |
| Offer | server mijozga | "sizga `<manzil>` ni taklif qilaman" |
| Request | mijoz, yana broadcast | "`<manzil>` ni olaman" (boshqa serverlar ham eshitib, o'z taklifini bo'shatsin) |
| Ack | server mijozga | "tasdiqlandi, lease muddati `<N>` soniya" |

Server manzil bilan birga beradi: subnet mask, default gateway, DNS serverlar, lease muddati, ba'zan domen nomi, NTP server, MTU.

**Lease** bu vaqtinchalik ijara. Muddatning 50 foizida (T1) mijoz o'sha serverdan unicast bilan (to'g'ridan-to'g'ri, broadcast'siz) uzaytirishni so'raydi, 87.5 foizida (T2) javob bo'lmagan bo'lsa istalgan serverdan broadcast bilan. Muddat tugasa mijoz manzildan foydalanishni to'xtatadi. `ip addr` dagi `dynamic` va `valid_lft` shu lease.

DHCP broadcast'ga tayanadi, broadcast esa routerdan o'tmaydi, demak DHCP faqat o'z LAN'ida ishlaydi. Boshqa subnet'dagi serverga yetkazish uchun router'da **DHCP relay** sozlanadi.

### Misol: tcpdump DHCP'ni qanday ko'rsatadi

`tcpdump` (2-dars) DHCP paketini shu ko'rinishda chiqaradi (`-e` MAC'larni, `-n` raqamli manzillarni ko'rsatadi):

```
ubuntu@lab:~$ sudo tcpdump -i <iface> -n -e 'udp port 67 or udp port 68'
<vaqt> <mijoz MAC> > ff:ff:ff:ff:ff:ff, ethertype IPv4 (0x0800), length <N>: 0.0.0.0.68 > 255.255.255.255.67: BOOTP/DHCP, Request from <mijoz MAC>, length <N>
<vaqt> <server MAC> > <mijoz MAC>, ethertype IPv4 (0x0800), length <N>: <server IP>.67 > <mijoz IP>.68: BOOTP/DHCP, Reply, length <N>
```

Birinchi qator mijozdan: L2 da broadcast MAC'ga, L3 da `0.0.0.0` dan `255.255.255.255` ga, portlar `68 > 67`. Ikkinchisi serverdan javob, portlar teskari. `BOOTP/DHCP, Request` va `Reply` bu eski BOOTP protokolidan qolgan yo'nalish belgisi: mijozdan chiqqan har xabar (Discover ham) `Request`, serverdan kelgani `Reply` deb yoziladi. Aniq xabar turini (`Discover`, `Offer`, `Request`, `ACK`) ko'rish uchun `-v` qo'shing: `DHCP-Message` qatorida chiqadi.

Lease tafsilotlari VM'da: `networkctl status <iface>` (manzil, gateway, DNS), systemd-networkd lease faylni `/run/systemd/netif/leases/` ichida saqlaydi. Zorin desktop'da `nmcli device show <iface>` (`IP4.ADDRESS`, `IP4.GATEWAY`, `IP4.DNS`), macOS'da `ipconfig getpacket en0`.

**Tuzoq: LAN'da ikkinchi DHCP server.** Kimdir tarmoqqa o'z routerini ulasa, mijozlarning bir qismi undan noto'g'ri gateway va DNS oladi. Belgisi: ba'zi qurilmalarda internet yo'q, `ip route` da notanish gateway. `169.254.x.x` manzil esa teskari holat: hech qaysi server javob bermagan.

### Real ishda qachon kerak

- Cloud VM'lar manzilni DHCP orqali oladi, lekin manzil VPC'da instansga biriktirilgan va o'zgarmaydi.
- Statik manzil kerak bo'lsa, odatda hostda qo'lda emas, DHCP reservation (MAC bo'yicha doimiy manzil) yoki cloud API orqali beriladi.

### Nima uchun shunday

Har hostga manzil, mask, gateway va DNS'ni qo'lda yozish xato va takroriy manzil manbai. Lease muddatli bo'lgani uchun tarmoqdan ketgan qurilmaning manzili o'zi bo'shaydi. Muqobillari: statik sozlama (kichik, o'zgarmas server tarmoqlarida) va IPv6'dagi SLAAC (8-bo'lim).

## 8. IPv6

### Yozuv

IPv6 manzil 128 bit: sakkizta 16 bitli guruh, har biri to'rtta hex raqam, ikki nuqta bilan ajratiladi: `2001:0db8:0000:0000:0000:ff00:0042:8329`. Qisqartirish qoidalari:

1. Guruh boshidagi nollar tashlanadi: `0db8` bu `db8`, `0042` bu `42`, `0000` bu `0`.
2. Ketma-ket nol guruhlar bir marta `::` bilan almashtiriladi: `2001:db8::ff00:42:8329`.
3. `::` manzilda faqat bir marta ishlatiladi, aks holda nechta guruh tashlangani noaniq. Yoyish: mavjud guruhlarni sanang, 8 ga yetmaganini `::` o'rniga nol guruh qilib qo'ying (yuqorida 5 ta guruh bor, demak `::` uchta nol guruh).

Prefiks IPv4 dagidek yoziladi: `2001:db8:0:1::/64`, mask tushunchasi yo'q.

| Diapazon | Nomi | IPv4 dagi o'xshashi |
|----------|------|---------------------|
| `::1/128` | loopback | `127.0.0.1` |
| `fe80::/10` | link-local, har interfeysda avtomatik bor | `169.254.0.0/16`, lekin doim mavjud |
| `fc00::/7` (amalda `fd00::/8`) | unique local (ULA) | RFC 1918 private |
| `2000::/3` | global unicast | public |
| `ff00::/8` | multicast | `224.0.0.0/4` |
| `2001:db8::/32` | documentation | `192.0.2.0/24` |
| `::/0` | default route | `0.0.0.0/0` |

### IPv4 dan asosiy farqlar

- **Subnet deyarli doim /64**: 64 bit network, 64 bit interfeys identifikatori. Subnet hisobi tejash uchun emas, faqat tuzilma uchun.
- **Broadcast yo'q**, o'rnida multicast. ARP o'rnida NDP (Neighbor Discovery Protocol, ICMPv6 ustida).
- **SLAAC**: host router e'lon qilgan /64 prefiksga o'zi interfeys identifikatorini qo'shib manzil yasaydi, DHCP shart emas.
- **NAT odatda yo'q**: har qurilma global manzil oladi, himoya firewall bilan.
- Link-local manzil har interfeysda bir xil `fe80::/10` dan, shuning uchun unga murojaatda interfeys ko'rsatiladi: `ping fe80::1%<iface>`.
- URL'da manzil kvadrat qavsda (port ikki nuqtasi bilan aralashmasligi uchun): `http://[2001:db8::1]:8080/`.

### Misol

```
ubuntu@lab:~$ ip -6 -br addr
lo               UNKNOWN        ::1/128
<iface>          UP             fe80::<...>/64
ubuntu@lab:~$ ping -6 -c 1 ::1
PING ::1 (::1) 56 data bytes
64 bytes from ::1: icmp_seq=1 ttl=64 time=<N> ms
```

`lo` da loopback `::1`, asosiy interfeysda faqat link-local: uni kernel o'zi yaratgan, hech kim bermagan. Global manzil (`2xxx:` bilan boshlanadi) bo'lsa shu yerda uchinchi manzil bo'lib ko'rinardi; bor-yo'qligi provayder va Multipass tarmog'iga bog'liq.

**Tuzoq: IPv6 ni "ishlatmaymiz" deb firewall'da unutish.** Host IPv6 manzilga ega bo'lsa va firewall faqat IPv4 qoidalarini o'z ichiga olsa, servis IPv6 orqali ochiq qoladi. `ss -tln` da `[::]:22` ko'rinsa, servis IPv6 da ham tinglayapti.

### Real ishda qachon kerak

- Cloud load balancer va CDN'lar dual-stack (IPv4 va IPv6 birga); log va firewall qoidalarida IPv6 manzillarni o'qish kerak.
- Kubernetes va Docker'da IPv6 yoqilgan bo'lsa pod va konteyner ikkita manzil oladi.

### Nima uchun shunday

IPv4 tugagani uchun 1990-yillarda yangi protokol ishlab chiqildi: 128 bit bilan manzilni tejash muammosi butunlay yo'qoladi, shuning uchun subnet hajmi qat'iy /64 va host o'z manzilini o'zi yasay oladi. Hex yozuv bitlarga yaqin (bitta raqam 4 bit). O'tish sekin, chunki IPv4 va IPv6 bir-biri bilan to'g'ridan-to'g'ri gaplasha olmaydi, tarmoqlar ikkalasini parallel yuritadi.

## 9. Manzil rejasini tuzish

### Qoidalar

**VPC** (Virtual Private Cloud) bu cloud'dagi sizning izolyatsiyalangan private tarmog'ingiz, yaratishda unga CIDR beriladi va keyin o'zgartirish qiyin. VPC, Kubernetes klasteri yoki ofis tarmog'ini loyihalashda:

1. **Kesishmaslik**: bir-biri bilan ulanadigan tarmoqlar (VPC peering, VPN, ofis) diapazonlari kesishmasligi kerak.
2. **Zaxira**: hozirgi ehtiyojdan kamida 2–4 barobar katta oling. VPC uchun `/16`, subnet uchun `/20`–`/24` odatiy.
3. **Tuzilma**: muhit va zona bo'yicha tekis bo'ling, masalan `10.<muhit>.<zona va rol>.0/24`, shunda har muhit bitta summary prefiks bilan ifodalanadi (4-bo'lim).
4. **Mashhur diapazonlardan qoching**: `192.168.0.0/24`, `192.168.1.0/24`, `10.0.0.0/24` uy routerlarida, `172.17.0.0/16` Docker'da band. Xodim uydan VPN orqali ulansa to'qnashuv bo'ladi.
5. **Provayder zaxirasi**: cloud har subnet'da bir nechta manzilni o'ziga oladi (AWS'da 5 ta: birinchi to'rtta va oxirgi). `/28` da 16 emas, 11 ta ishlatiladigan manzil qoladi.
6. **Kubernetes**: node, pod va service uchun uchta alohida, kesishmaydigan diapazon kerak. Pod tarmog'i katta bo'ladi (har node uchun odatda /24).

### Mexanizm: kesishma nima uchun routing'ni buzadi

Ofis `10.1.0.0/16`, VPC ham `10.1.0.0/16` bo'lsin. Ofisdagi host `10.1.5.20` ga paket yubormoqchi. U 3-bo'limdagi `AND` ni bajaradi, natija o'z network manziliga teng chiqadi, demak "qo'shnim" deb ARP qiladi va paketni hech qachon VPN gateway'ga bermaydi. VPC'dagi `10.1.5.20` ga yetib bo'lmaydi, garchi tunnel ishlab tursa ham. Qisman kesishma ham xuddi shunday: kesishgan qism uchun ikki xil javob bor va tarmoq ulardan faqat bittasini tanlaydi.

### Misol: kesishmani tekshirish

```
$ python3 -c "import ipaddress as i; print(i.ip_network('10.1.0.0/16').overlaps(i.ip_network('10.1.128.0/20')), i.ip_network('10.1.0.0/16').overlaps(i.ip_network('10.2.0.0/16')))"
True False
```

`overlaps()` ikki tarmoqda umumiy manzil bor-yo'qligini aytadi: `10.1.128.0/20` birinchisining ichida (`True`), `10.2.0.0/16` alohida (`False`). Qo'lda: ikkala tarmoqning birinchi va oxirgi manzilini block size bilan toping va oraliqlar ustma-ust tushadimi qarang.

### Real ishda qachon kerak

- Yangi VPC, klaster yoki VPN ochishdan oldin: mavjud barcha diapazonlar ro'yxati (IPAM, oddiy holatda jadval) bilan solishtirish.
- `docker compose` tarmog'i ofis VPN diapazoniga to'g'ri kelib, konteyner ishlaganda VPN "uzilib" qolganda: Docker tarmog'iga boshqa subnet beriladi.

### Nima uchun shunday

Private diapazonlar hammada bir xil bo'lgani uchun to'qnashuv ehtimoli katta, tuzatish esa butun tarmoqni qayta manzillash demak: har instans, har firewall qoidasi, har DNS yozuvi. Shuning uchun reja birinchi resursdan oldin tuziladi. Muqobili (kesishgan tarmoqlar orasida NAT) ishlaydi, lekin har ulanishni murakkablashtiradi va tashxisni qiyinlashtiradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| IPv4 manzil | interfeysni tarmoq qatlamida aniqlaydigan 32 bitli son, to'rt oktet ko'rinishida yoziladi |
| Oktet | manzilning 8 bitli bo'lagi, 0–255 |
| Prefiks uzunligi | manzilning chapdan necha biti network qismi ekanini aytadigan son (`/26`) |
| CIDR | manzil va prefiksni `a.b.c.d/N` ko'rinishida yozish va chegarani istalgan bitga qo'yish tizimi |
| Subnet mask | prefiksning 32 bitli ko'rinishi: network bitlari 1, host bitlari 0 |
| Subnet | bitta prefiks ostidagi manzillar to'plami, bitta LAN |
| Network address | host bitlari hammasi 0 bo'lgan manzil, subnet'ning nomi |
| Broadcast address | host bitlari hammasi 1 bo'lgan manzil, subnet'dagi barcha hostlarga |
| Block size | qiziq oktetda subnet'lar orasidagi qadam, `256 - mask okteti` |
| Subnetting | blokni prefiksni uzaytirib kichik subnet'larga bo'lish |
| VLSM | bitta blokni har xil prefiksli subnet'larga bo'lish |
| Summarization (supernetting) | qo'shni subnet'larni bitta qisqaroq prefiks bilan ifodalash |
| Private manzil | RFC 1918 diapazonlaridagi, internetda route qilinmaydigan manzil |
| Public manzil | internetda yagona va route qilinadigan manzil |
| Loopback | host o'zi bilan gaplashadigan manzillar (`127.0.0.0/8`, `::1`) |
| Link-local | faqat bitta LAN ichida amal qiladigan manzil (`169.254.0.0/16`, `fe80::/10`) |
| CGNAT | provayder ko'p mijozni bitta public manzil ortiga yashiradigan NAT, diapazoni `100.64.0.0/10` |
| Dummy interfeys | hech qayerga ulanmagan virtual interfeys, tajriba uchun |
| Connected route | manzil qo'shilganda kernel o'zi yaratadigan "bu subnet shu interfeysda" yozuvi |
| Tinglash manzili | server socket bog'langan manzil: `127.0.0.1` faqat lokal, `0.0.0.0` barcha interfeyslar |
| DHCP | hostga manzil, mask, gateway va DNS'ni avtomatik beradigan protokol |
| DORA | DHCP'ning to'rt qadami: Discover, Offer, Request, Ack |
| Lease | DHCP bergan manzilning ijara muddati, T1 (50%) va T2 (87.5%) da uzaytiriladi |
| DHCP relay | DHCP so'rovini boshqa subnet'dagi serverga yetkazadigan router funksiyasi |
| IPv6 | 128 bitli manzilli protokol, hex guruhlar bilan yoziladi |
| SLAAC | IPv6 host router e'lon qilgan prefiksdan o'z manzilini o'zi yasashi |
| NDP | IPv6'da ARP o'rnini bosadigan qo'shni topish protokoli |
| ULA | IPv6'ning private manzillari (`fd00::/8`) |
| VPC | cloud'dagi o'z CIDR'iga ega izolyatsiyalangan private tarmoq |

## Tuzoqlar

- VPC yoki ofis tarmoqlarini kesishadigan CIDR bilan yaratish. Peering yoki VPN kerak bo'lgan kuni tuzatib bo'lmaydi.
- `172.16.0.0/12` ni `/16` yoki `/8` deb o'ylash, firewall qoidasiga noto'g'ri diapazon yozish.
- Network yoki broadcast manzilni hostga berish, yoki subnet hajmini hisoblaganda bu ikki manzil va provayder zaxirasini unutish.
- "Oxirgi oktet 0 yoki 255 bo'lsa hostga berilmaydi" deb o'ylash: bu faqat `/24` da to'g'ri. `/20` da `10.20.40.255` oddiy host, `/26` da esa `.64` network manzil.
- Prefiks katta bo'lsa tarmoq katta deb o'ylash: aksincha, `/28` `/24` dan 16 marta kichik.
- Bir LAN'dagi hostlarda har xil mask: qisman ishlaydigan, tashxisi qiyin aloqa.
- Servisni `0.0.0.0` da tinglatib, "ichki tarmoqda turibdi" deb himoyasiz qoldirish. Yoki teskarisi: konteynerda `127.0.0.1` da tinglatib, nega ulanib bo'lmasligini qidirish.
- `ip addr add` ni prefikssiz yozish (`/32` bo'lib qoladi).
- Subnet'ni tor olish: `/28` dagi Kubernetes node guruhi yoki load balancer manzillari tugab, scale to'xtaydi.
- IPv6 mavjudligini unutish: firewall va `ss` tekshiruvida faqat IPv4 ga qarash.
- Statik manzilni DHCP pool ichidan qo'lda berish: ertami-kechmi DHCP o'sha manzilni boshqa qurilmaga beradi.
- VM manzilini README yoki skriptga qotirib yozish: ikkinchi mashinada `lab` boshqa diapazondan manzil oladi.

## Manbalar

- https://www.rfc-editor.org/rfc/rfc791 – IPv4
- https://www.rfc-editor.org/rfc/rfc1918 – private manzillar
- https://www.rfc-editor.org/rfc/rfc4632 – CIDR
- https://www.rfc-editor.org/rfc/rfc3021 – nuqtadan-nuqtaga linklarda `/31`
- https://www.rfc-editor.org/rfc/rfc5737 – documentation diapazonlari
- https://www.rfc-editor.org/rfc/rfc6598 – CGNAT diapazoni
- https://www.rfc-editor.org/rfc/rfc2131 – DHCP
- https://www.rfc-editor.org/rfc/rfc4291 – IPv6 manzil arxitekturasi
- https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml – maxsus IPv4 diapazonlar reyestri
- https://man7.org/linux/man-pages/man8/ip-address.8.html – `ip address`
- https://docs.python.org/3/library/ipaddress.html – Python `ipaddress` moduli
- https://netplan.readthedocs.io/ – netplan hujjatlari
- https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html – AWS subnet hajmi va band manzillar
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 4.3-bo'lim (IPv4 addressing, DHCP, IPv6)

## Birga bajaramiz

Ssenariy: staging stend uchun sizga `10.88.64.0/21` bloki ajratildi. Uni o'qiymiz, ikki manzil unga tegishli yoki yo'qligini tekshiramiz, to'rt xil hajmli subnet'ga bo'lamiz, asbob bilan tekshiramiz va bitta manzilni VM'da interfeysga qo'yib kernel bizning hisobimiz bilan rozi ekanini ko'ramiz.

1. Blokni qo'lda o'qish. /21 uchinchi oktetda (16 + 5 bit), mask okteti `11111000 = 248`, mask `255.255.248.0`, block size `256 - 248 = 8`. Uchinchi oktet bloklari 0, 8, ..., 64, 72: 64 karrali, demak `10.88.64.0` haqiqatan network manzil. Broadcast `10.88.71.255`, hostlar `10.88.64.1` – `10.88.71.254`, `2^11 - 2 = 2046` ta.

2. Tegishlilikni `AND` bilan tekshirish. `10.88.69.250` va `10.88.72.1` shu blokdami? Uchinchi oktetlar:

```
69  = 01000101          72  = 01001000
248 = 11111000          248 = 11111000
AND = 01000000 = 64     AND = 01001000 = 72
```

Birinchisi `10.88.64.0/21` ichida, ikkinchisi keyingi blokda (`10.88.72.0/21`). Block size bilan ham shu: 69 blok 64–71 ichida, 72 esa yo'q.

3. VLSM bilan bo'lish. Ehtiyoj: ilova serverlari 1000 host, ma'lumotlar bazalari 200 host, monitoring 50 host, ikki router orasidagi link 2 host. Kattadan kichikka:

| Ehtiyoj | Blok | CIDR | Diapazon |
|---------|------|------|----------|
| 1000 host | 1024 manzil, `/22` (1022 host) | `10.88.64.0/22` | `10.88.64.0` – `10.88.67.255` |
| 200 host | 256 manzil, `/24` (254 host) | `10.88.68.0/24` | `10.88.68.0` – `10.88.68.255` |
| 50 host | 64 manzil, `/26` (62 host) | `10.88.69.0/26` | `10.88.69.0` – `10.88.69.63` |
| 2 host | 4 manzil, `/30` (2 host) | `10.88.69.64/30` | `10.88.69.64` – `10.88.69.67` |

Har keyingi blok oldingisi tugagan joydan boshlanadi va o'z block size'ining karralisiga tushadi (`/22` uchun 64, `/26` uchun 0, `/30` uchun 64). Bo'sh qoldi: `10.88.69.68` dan `10.88.71.255` gacha, jumladan butun `10.88.70.0/23`.

4. Asbob bilan tekshirish (host'da, ikkala mashinada ishlaydi):

```
$ python3 -c "import ipaddress as i; b=i.ip_network('10.88.64.0/21'); print(b.netmask, b.broadcast_address, b.num_addresses - 2)"
255.255.248.0 10.88.71.255 2046
$ python3 -c "
import ipaddress as i
nets = [i.ip_network(x) for x in ['10.88.64.0/22', '10.88.68.0/24', '10.88.69.0/26', '10.88.69.64/30']]
print(all(n.subnet_of(i.ip_network('10.88.64.0/21')) for n in nets))
print(any(a.overlaps(b) for a in nets for b in nets if a != b))
"
True
False
```

Birinchi buyruq 1-qadamni tasdiqlaydi. Ikkinchisida `True`: to'rtala subnet blok ichida, `False`: hech qaysi ikkitasi kesishmaydi. Agar `10.88.69.0/26` o'rniga adashib `10.88.68.128/26` yozilganda, ikkinchi qator `True` bo'lardi.

5. Monitoring subnet'ining birinchi hostini VM'da interfeysga qo'yamiz:

```
ubuntu@lab:~$ sudo ip link add plan0 type dummy
ubuntu@lab:~$ sudo ip link set plan0 up
ubuntu@lab:~$ sudo ip addr add 10.88.69.1/26 brd + dev plan0
ubuntu@lab:~$ ip -4 addr show dev plan0
<N>: plan0: <BROADCAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 10.88.69.1/26 brd 10.88.69.63 scope global plan0
       valid_lft forever preferred_lft forever
ubuntu@lab:~$ ip route | grep plan0
10.88.69.0/26 dev plan0 proto kernel scope link src 10.88.69.1
```

`brd 10.88.69.63` kernel prefiksdan hisoblagan broadcast, 3-qadamdagi jadval bilan bir xil. `valid_lft forever`: manzil DHCP'dan emas, qo'lda qo'yilgan. Route qatoridagi `10.88.69.0/26` kernel `AND` bilan topgan network manzil.

6. `ipcalc 10.88.69.1/26` ni ishga tushirib `Network`, `HostMin`, `HostMax`, `Broadcast` qatorlarini jadval bilan solishtiring, keyin tozalang:

```
ubuntu@lab:~$ sudo ip link del plan0
```

Shu 6 qadamda ko'rganingiz: prefiksdan mask va block size (2 va 3-bo'limlar), `AND` bilan tegishlilik (3-bo'lim), VLSM va kesishmani tekshirish (4 va 9-bo'limlar), manzil, `brd` va connected route (6-bo'lim), private diapazon tanlovi (5-bo'lim: `10.88.x.x` RFC 1918 ichida va mashhur uy diapazonlaridan uzoq).

---

## Vazifalar

Ish papkasi: `network/03-ip-addressing/` (`make new m=network n=03 name=ip-addressing`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. A guruhda avval qo'lda hisoblang (hisob qadamlarini yozing), keyin Python yoki `ipcalc` bilan tekshiring; tekshiruvda xato chiqsa javobni o'chirmang (18-vazifa). B, C va D guruhlar `lab` VM ichida bajariladi, aksi aytilgan joylarda host'da. "Zorin'da" yoki "macOS'da" deb belgilangan qismlar ixtiyoriy, o'sha mashinada bo'lsangiz qo'shing. Sizdagi interfeys nomi va VM manzili darsdagidan farq qiladi, avval `ip -br addr` bilan aniqlang.

### A. Qo'lda hisob

1. **Binary conversion.** `172.20.150.9` ni ikkilik ko'rinishga, `11000000.10101000.00000101.10000010` ni o'nlik ko'rinishga o'tkazing. `/19` va `/27` uchun mask'ni o'nlik va ikkilik ko'rinishda yozing. Yo'nalish: 1-bo'lim, "Mexanizm: o'nlik va ikkilik orasida o'tish" va 2-bo'lim.

2. **Subnet facts.** Har biri uchun network, broadcast, birinchi va oxirgi host, hostlar sonini block size usuli bilan toping: (a) `192.168.5.130/25`; (b) `10.1.1.77/28`; (c) `172.16.45.200/21`; (d) `10.200.13.1/12`; (e) `192.168.100.255/23`. (e) dagi manzil hostga berilishi mumkinmi? Yo'nalish: 3-bo'lim, "Block size usuli".

3. **Same subnet or not.** Har juftlik bir subnet'dami? Bit darajasida `AND` bilan asoslang: (a) `10.0.5.10/23` va `10.0.4.200/23`; (b) `192.168.1.126/26` va `192.168.1.129/26`; (c) `172.16.31.5/20` va `172.16.32.5/20`. Yo'nalish: 3-bo'lim, "Bitlar bilan: AND".

4. **Private or public.** Har manzil turini (private, public, loopback, link-local, CGNAT, multicast, documentation) aniqlang va diapazonini yozing: `172.15.0.1`, `172.31.255.254`, `172.32.0.1`, `192.169.1.1`, `10.255.255.255`, `100.72.3.4`, `169.254.169.254`, `127.8.8.8`, `224.0.0.251`, `203.0.113.7`, `8.8.8.8`. Yo'nalish: 5-bo'lim.

5. **Split a network.** `10.50.0.0/22` ni (a) to'rtta teng subnet'ga; (b) biri 500 host, ikkitasi 100 hostdan, biri 50 host sig'adigan har xil hajmli subnet'larga (VLSM) bo'ling. Har subnet uchun CIDR, diapazon va bo'sh qolgan joyni yozing. Yo'nalish: 4-bo'lim, "Teng bo'lish" va "VLSM".

6. **Summarize.** `192.168.8.0/24`, `192.168.9.0/24`, `192.168.10.0/24`, `192.168.11.0/24` ni bitta yozuvga birlashtiring. `192.168.9.0/24` va `192.168.10.0/24` ni nima uchun bitta `/23` ga birlashtirib bo'lmasligini bit darajasida ko'rsating. Yo'nalish: 4-bo'lim, "Summarization (supernetting)".

### B. O'z tarmog'ingiz

7. **My addresses.** `lab` VM'da `ip -br addr` dagi har bir IPv4 va IPv6 manzil uchun yozing: turi (private, link-local, global, loopback), `scope`, qayerdan kelgan (DHCP, SLAAC, Docker, kernel). Faol interfeysning network va broadcast manzilini qo'lda hisoblab, `ip addr` dagi `brd` bilan solishtiring. Ixtiyoriy: host'ning faol interfeysi uchun ham shu hisobni bajaring (Zorin'da `ip -br addr`, macOS'da `ifconfig en0`, mask hex ko'rinishida chiqadi). Yo'nalish: 6-bo'lim, "`ip addr` ni o'qish".

8. **DHCP lease.** Host'da DHCP bergan barcha sozlamalarni yozing (manzil, gateway, DNS): Zorin'da `nmcli device show <iface>`, macOS'da `ipconfig getpacket en0` chiqishidan. `lab` VM'da `ip addr` dagi `valid_lft` bo'yicha VM'ning lease'i qachon tugashini va T1 qachon bo'lishini hisoblang. Public IP'ingiz (`curl -s https://ifconfig.me`) `ip addr` dagi manzildan nima uchun farq qiladi? Yo'nalish: 7-bo'lim, "Mexanizm: DORA" (lease, T1) va 5-bo'lim.

9. **Docker subnets.** `lab` VM ichidagi Docker'da `docker network inspect bridge` dan subnet va gateway'ni toping. `docker network create --subnet 10.77.0.0/29 tiny` yarating va unga ketma-ket konteynerlar ulang (`docker run -d --network tiny alpine sleep 600`). Nechanchi konteynerda xato chiqdi, xato matni qanday, va bu son hisobingizga mos keladimi? Tozalang. Yo'nalish: 2-bo'lim, "Mexanizm: ikki band manzil va sonlar".

10. **Listen address.** `lab` VM'da `python3 -m http.server 8000 --bind 127.0.0.1` ni ishga tushiring va `ss -tlnp | grep 8000` ni ko'ring. Ikkinchi sessiyada `curl` bilan `127.0.0.1:8000` va VM'ning o'z manzili (`<VM IP>:8000`) orqali VM ichidan, keyin host'dan ulanib ko'ring. `--bind 0.0.0.0` bilan takrorlang. Natijalar farqini va xato matnini izohlang. Server'ni to'xtating. Yo'nalish: 6-bo'lim, "Tinglash manzili".

### C. IPv6

11. **IPv6 notation.** To'liq yozing: `2001:db8::1`, `fe80::1`, `::1`. Qisqartiring: `2001:0db8:0000:0000:0000:0000:0000:0001`, `fd00:0000:0000:0010:0000:0000:0a00:0001`. `2001:db8::1::5` nima uchun noto'g'ri? Yo'nalish: 8-bo'lim, "Yozuv".

12. **IPv6 on my host.** `lab` VM'da `ip -6 addr` va `ip -6 route` chiqishini yozing. Har manzilning turini aniqlang. Sizda global IPv6 bormi? `ping -6 -c 2 ::1` va o'z link-local manzilingizga `%iface` bilan va usiz ping qilib, farqni izohlang. Yo'nalish: 8-bo'lim, "IPv4 dan asosiy farqlar".

### D. VM ichida

13. **Dummy interface.** `lab` VM'da `dummy0` interfeysi yarating, `up` qiling va `10.10.10.1/24` bering. `ip route` da qanday yangi qator paydo bo'ldi va uni kim yaratdi? `ping -c 2 10.10.10.1` va `ping -c 2 10.10.10.2` natijalarini izohlang. Yo'nalish: 6-bo'lim, "Manzil qo'shish va connected route".

14. **Missing prefix.** `dummy0` ga `10.20.20.1` ni prefikssiz qo'shing. `ip addr` va `ip route` da nima ko'rindi? `/24` bilan qo'shilgan holatdan farqini va bu nima uchun real interfeysda aloqani buzishini yozing. Manzilni o'chiring. Yo'nalish: 6-bo'lim, "Manzil qo'shish va connected route".

15. **Secondary address.** `dummy0` ga `10.10.10.2/24` va `10.10.10.3/24` ni ham qo'shing. `ip addr` da ular qanday belgilangan? Avval birinchi (primary) manzilni o'chirib ko'ring: qolganlariga nima bo'ldi? Bir interfeysda bir nechta manzil real hayotda qayerda kerak bo'lishiga bitta misol yozing. Yo'nalish: 6-bo'lim; `man ip-address`.

16. **Watch DORA.** VM'ning asosiy interfeysi nomini aniqlang (`ip -br link`). Bir sessiyada `sudo tcpdump -i <iface> -n -e 'udp port 67 or udp port 68'`, ikkinchisida `sudo networkctl renew <iface>` ni ishga tushiring. Qaysi DHCP xabarlari ko'rindi, to'liq DORA'dan nimasi bilan farq qiladi va nima uchun? Manba va manzil IP hamda MAC'larni yozing. Yo'nalish: 7-bo'lim, "Misol: tcpdump DHCP'ni qanday ko'rsatadi" (`-v` bilan xabar turi ko'rinadi).

17. **Lease details.** `networkctl status <iface>` va `cat /etc/netplan/*.yaml` (kerak bo'lsa `sudo`) chiqishidan VM manzilni qanday olayotganini tushuntiring: DHCP server kim (qaysi IP, u host'dagi qaysi interfeys: Zorin'da `ip -br addr`, macOS'da `ifconfig` bilan toping), lease muddati, DNS server. Yo'nalish: 7-bo'lim.

18. **ipcalc check.** `lab` VM'da 2 va 5-vazifalardagi barcha javoblaringizni `ipcalc` bilan tekshiring. Farq chiqqan joylarni README'da tuzatmasdan, xato sababini yozing (qaysi qadamda adashdingiz). Yo'nalish: 4-bo'lim, "Asbob bilan tekshirish".

### E. Yig'ish

19. **Address plan.** Kompaniya uchun manzil rejasini tuzing: uch muhit (dev, staging, prod), har birida alohida VPC; har VPC'da 3 availability zone, har zonada public va private subnet; prod'da qo'shimcha Kubernetes pod va service diapazonlari; ofis tarmog'i va VPN mijozlari uchun diapazon. Talablar: hech narsa kesishmaydi, har muhit bitta summary prefiks bilan ifodalanadi, private subnet'da kamida 1000 host. Natijani jadval ko'rinishida `plan.md` ga yozing va har tanlov sababini izohlang. Yo'nalish: 9-bo'lim, "Qoidalar".

20. **Validate the plan.** `plan.md` dagi barcha CIDR'larni o'qib, kesishma yo'qligini tekshiradigan qisqa skript yozing (`check_plan.py`, Python `ipaddress` moduli, `overlaps()` metodi). Ataylab bitta kesishadigan diapazon qo'shib skript uni topishini ko'rsating, keyin olib tashlang. Yo'nalish: 9-bo'lim, "Misol: kesishmani tekshirish".

### Topshirish

Tayyor bo'lgach:
1. `network/03-ip-addressing/README.md` da 20 ta vazifaning har biri `## N. Title` sarlavhasi ostida, qo'lda hisob qadamlari bilan (faqat natija emas); VM yoki host'da bajarilgani aniq ko'rinadi.
2. `plan.md` va `check_plan.py` papkada, skript ikkala host'da xatosiz ishlaydi (`python3 check_plan.py`).
3. `make check` toza o'tadi (host'da).
4. `lab` VM'dagi `dummy0` o'chirilgan (`sudo ip link del dummy0`), 8000-portdagi server to'xtatilgan, Docker `tiny` tarmog'i va konteynerlari o'chirilgan (`docker ps -a`, `docker network ls`).
5. Menga xabar bering, README'ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `/26` nimani bildiradi? Undagi manzillar va hostlar sonini qanday topasiz?
- Host manzil o'z tarmog'ida yoki yo'qligini qanday aniqlaydi va natijaga qarab nima qiladi?
- RFC 1918 ning uch diapazoni qaysilar? `172.32.0.1` private'mi?
- Network va broadcast manzil nima uchun hostga berilmaydi?
- `127.0.0.1` va `0.0.0.0` da tinglash farqi nima, har biri qachon to'g'ri tanlov?
- DHCP'ning to'rt qadami nima uchun broadcast bilan boshlanadi? `169.254.x.x` manzil nimadan dalolat?
- Ikki VPC CIDR'i kesishsa nima uchun ularni ulab bo'lmaydi?
- IPv6 da subnet hajmi nima uchun deyarli doim /64 va broadcast o'rnida nima ishlatiladi?
- `ip addr add` ni prefikssiz yozsangiz nima bo'ladi?
- VLSM'da nima uchun eng katta subnet'dan boshlanadi? Ikki qo'shni `/24` qachon bitta `/23` ga birlashadi?
- VM manzili Zorin'da va macOS'da nima uchun har xil diapazondan va bu vazifa javoblariga qanday ta'sir qiladi?
