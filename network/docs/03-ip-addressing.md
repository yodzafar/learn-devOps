# 3-dars: IP manzillar

Maqsad: IP manzillashni hisob darajasida egallash: IPv4 manzil va prefiks (CIDR), subnet mask'ni qo'lda hisoblash, network va broadcast manzil, private va public diapazonlar (RFC 1918), maxsus diapazonlar (loopback, link-local), subnetting, DHCP manzilni qanday tarqatishi, IPv6 asoslari. 1-darsda host "manzil o'z LAN'imdami yoki gateway'ga yuboraymi" degan qarorni qiladi deb aytilgan edi: bu qaror aynan subnet mask bilan hisoblanadi. Cloud modulida VPC va subnet yaratish, Kubernetes'da pod va service CIDR tanlash, 5-darsda routing table o'qish, 6-darsda firewall qoidasi yozish shu hisobga tayanadi. CIDR'ni kalkulyatorsiz o'qiy olmaslik DevOps'da doimiy to'siq.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun to'liq qo'lda hisobga: /24 dan kichik va katta prefikslar, block size usuli. Ikkinchi kun maxsus diapazonlar, DHCP va `ip addr` amaliyoti. Uchinchi kun IPv6 va subnet rejalash. Hisobni `ipcalc` bilan tekshiring, lekin avval qog'ozda bajaring.

## Laboratoriya

- **Ish mashinasi**: `ip addr`, `ip route`, `nmcli device show`, `python3 -c` (faqat o'qish va hisob).
- **Multipass VM**: manzil qo'shish va o'chirish, dummy interfeys, DHCP kuzatish, `ipcalc` o'rnatish. Multipass linux modulida o'rnatilgan; yo'q bo'lsa `sudo snap install multipass` (https://documentation.ubuntu.com/multipass/).

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass shell net1
sudo apt update && sudo apt install -y ipcalc
```

- **Docker**: o'z subnet'i bilan tarmoqlar yaratish (`docker network create --subnet`).
- **Tozalash**: `multipass delete net1 && multipass purge` (keyingi darslarda ham kerak bo'ladi, modul oxirigacha qoldirishingiz mumkin: `multipass stop net1`), Docker tarmoqlarini `docker network rm` bilan.

---

## 1. IPv4 manzil tuzilishi

IPv4 manzil 32 bit, o'qish uchun to'rt oktetga (8 bitdan) bo'linib o'nlik sonlarda yoziladi:

```
192      .168      .10       .77
11000000  10101000  00001010  01001101
```

Har oktet 0–255. Bitlarning og'irligi chapdan o'ngga: 128, 64, 32, 16, 8, 4, 2, 1. `77 = 64 + 8 + 4 + 1 = 01001101`.

Manzil ikki qismdan iborat: **network** (tarmoqni aniqlaydi) va **host** (tarmoq ichidagi qurilmani). Chegara qayerda ekanini manzilning o'zi aytmaydi, uni **prefiks uzunligi** aytadi.

### CIDR va subnet mask

`192.168.10.77/26` yozuvida `/26` chapdan 26 bit network qismi, qolgan `32 - 26 = 6` bit host qismi degani. Bu **CIDR** (Classless Inter-Domain Routing) notatsiyasi. Xuddi shu ma'lumotning eski ko'rinishi **subnet mask**: network bitlari 1, host bitlari 0.

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

Formulalar: manzillar soni `2^(32 - prefiks)`, hostlar soni undan 2 ta kam. Ikki manzil band:

- **Network address**: host bitlari hammasi 0. Tarmoqning o'zini bildiradi, routing table'da yoziladi.
- **Broadcast address**: host bitlari hammasi 1. Shu subnet'dagi barcha hostlarga.

Prefiks bittaga oshsa tarmoq ikkiga bo'linadi, bittaga kamaysa ikki qo'shni tarmoq birlashadi. `/24` = ikkita `/25` = to'rtta `/26`.

Eski "A, B, C sinflari" (classful) tizimi 1993 yilda CIDR bilan almashtirilgan. "C class tarmoq" iborasini eshitsangiz, `/24` nazarda tutilgan.

## 2. Qo'lda hisoblash

### Block size usuli

Prefiks qaysi oktetga tushishini aniqlang (/1–8 birinchi, /9–16 ikkinchi, /17–24 uchinchi, /25–32 to'rtinchi). O'sha oktetdagi **block size** = `256 - mask okteti`. Network manzil shu oktetda block size'ning karralisi bo'ladi.

**Misol 1: `192.168.10.77/26`**

1. /26 to'rtinchi oktetda, mask okteti 192, block size `256 - 192 = 64`.
2. Bloklar: 0, 64, 128, 192. 77 qaysi blokda? 64–127.
3. Network: `192.168.10.64`. Broadcast: keyingi blokdan bitta oldin, `192.168.10.127`.
4. Hostlar: `192.168.10.65` – `192.168.10.126`, 62 ta.

**Misol 2: `10.20.37.200/20`**

1. /20 uchinchi oktetda (16 + 4 bit), mask `255.255.240.0`, block size `256 - 240 = 16`.
2. Uchinchi oktet bloklari: 0, 16, 32, 48, ... 37 qaysi blokda? 32–47.
3. Network: `10.20.32.0`. Broadcast: `10.20.47.255` (uchinchi oktet blok oxiri, to'rtinchi oktet to'liq 1).
4. Hostlar: `10.20.32.1` – `10.20.47.254`, `2^12 - 2 = 4094` ta.

### Bitlar bilan tekshirish

Network manzil = IP `AND` mask. Misol 1 ning to'rtinchi okteti:

```
77   = 01001101
192  = 11000000
AND  = 01000000 = 64
```

Host aynan shu amalni bajaradi: manzil IP'ni o'z mask'i bilan `AND` qilib, natija o'z network manziliga teng bo'lsa "bir LAN'da, ARP qilaman", aks holda "gateway'ga yuboraman" deydi.

**Tuzoq: ikki hostda mask har xil.** `192.168.1.10/24` va `192.168.1.200/25` bir kabelda. Birinchisi ikkinchisini o'z tarmog'ida deb hisoblab to'g'ridan-to'g'ri yuboradi, ikkinchisi esa birinchisini boshqa tarmoqda (`.0/25`) deb gateway'ga yuboradi. Natija: bir tomonga ishlaydi, javob boshqa yo'ldan ketadi yoki yo'qoladi. Belgisi: "ping ba'zi hostlarga boradi, ba'zilariga yo'q".

### Subnetting: tarmoqni bo'lish

Vazifa: `10.0.0.0/22` ni to'rtta teng subnet'ga bo'lish. To'rtta = `2^2`, demak prefiksga 2 bit qo'shiladi: `/24`. Natija: `10.0.0.0/24`, `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24`.

Teskari amal (**supernetting**, summarization): shu to'rtta `/24` ni routing table'da bitta `10.0.0.0/22` yozuvi bilan ifodalash mumkin. Bu faqat bloklar qo'shni va chegarasi to'g'ri kelganda ishlaydi: `10.0.1.0/24` va `10.0.2.0/24` ni `/23` ga birlashtirib bo'lmaydi, chunki `/23` bloklari 0–1 va 2–3.

Tekshirish asboblari:

```
ipcalc 192.168.10.77/26
python3 -c "import ipaddress as i; n=i.ip_interface('10.20.37.200/20').network; print(n, n.broadcast_address, n.num_addresses)"
python3 -c "import ipaddress as i; print(list(i.ip_network('10.0.0.0/22').subnets(new_prefix=24)))"
```

## 3. Maxsus diapazonlar

### Private manzillar (RFC 1918)

Internetda route qilinmaydi, istalgan tashkilot ichkarida erkin ishlatadi. Tashqariga chiqish NAT orqali (6-darsda).

| Diapazon | Manzillar | Odatda qayerda |
|----------|-----------|----------------|
| `10.0.0.0/8` | 16.7 mln | korporativ tarmoq, cloud VPC, Kubernetes pod tarmoqlari |
| `172.16.0.0/12` | 1 mln (`172.16.0.0` – `172.31.255.255`) | Docker sukut bo'yicha (`172.17.0.0/16`), AWS default VPC (`172.31.0.0/16`) |
| `192.168.0.0/16` | 65 536 | uy routerlari (`192.168.0.0/24`, `192.168.1.0/24`) |

**Tuzoq: `172.16.0.0/12` chegarasi.** `172.32.0.1` private emas, public manzil. /12 ikkinchi oktetda block size 16: 16–31. Firewall qoidasida `172.0.0.0/8` yozish xato.

### Boshqa maxsus diapazonlar

| Diapazon | Nomi | Ma'nosi |
|----------|------|---------|
| `127.0.0.0/8` | loopback | host o'zi bilan. `127.0.0.1` gina emas, butun /8 |
| `169.254.0.0/16` | link-local (APIPA) | DHCP javob bermaganda avtomatik; cloud'da `169.254.169.254` instance metadata xizmati |
| `100.64.0.0/10` | CGNAT (RFC 6598) | provayder ichki NAT'i; Tailscale ham shu diapazonni ishlatadi |
| `0.0.0.0/0` | default route | "hamma manzil". Bitta manzil sifatida `0.0.0.0`: tinglashda "barcha interfeyslar" |
| `255.255.255.255` | limited broadcast | shu LAN'dagi hamma, DHCP discover shunga ketadi |
| `224.0.0.0/4` | multicast | guruhga yuborish |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | documentation (RFC 5737) | misol va hujjatlar uchun, real ishlatilmaydi |

**Tuzoq: `127.0.0.1` va `0.0.0.0` da tinglash.** Servis `127.0.0.1:8080` da tinglasa, unga faqat shu hostning o'zidan ulanish mumkin. `0.0.0.0:8080` barcha interfeyslarda, ya'ni tarmoqdan ham. Konteyner ichida `localhost` da tinglagan ilovaga port publish qilingan bo'lsa ham tashqaridan ulanib bo'lmaydi: frontend dev server'larning `--host 0.0.0.0` flag'i aynan shu sabab. Teskarisi xavfsizlik muammosi: ma'lumotlar bazasini bilmasdan `0.0.0.0` da ochib qo'yish.

Public manzillar qolgan hamma narsa. Ularni IANA, mintaqaviy registrlar (RIPE NCC, ARIN va boshqalar) va provayderlar taqsimlaydi. IPv4 manzillar tugagan, shuning uchun cloud'da public IPv4 uchun alohida haq olinadi.

## 4. Linux'da manzillar

```
ip -br addr                      # overview
ip -4 addr show dev eth0         # IPv4 only
ip addr add 10.10.10.1/24 dev dummy0
ip addr del 10.10.10.1/24 dev dummy0
ip link add dummy0 type dummy    # virtual interface for experiments
```

- Bitta interfeysda bir nechta manzil bo'lishi mumkin (ikkinchisi `secondary` deb belgilanadi).
- Manzil qo'shilganda kernel avtomatik **connected route** yaratadi: `10.10.10.0/24 dev dummy0 proto kernel scope link`. Ya'ni "bu subnet shu interfeysda, to'g'ridan-to'g'ri yetib bo'ladi". Routing table'ning asosi shu (5-darsda).
- **Tuzoq: prefikssiz `ip addr add 10.10.10.1 dev eth0`.** Prefiks ko'rsatilmasa `/32` olinadi: connected route yaratilmaydi va host qo'shnilarini ko'rmaydi. Doim `/N` bilan yozing.
- `ip addr add` vaqtinchalik. Ubuntu server'da doimiy sozlama netplan'da (`/etc/netplan/*.yaml`, qo'llash `sudo netplan apply`, xavfsiz sinov `sudo netplan try`), desktop'da NetworkManager'da (`nmcli`).

## 5. DHCP

**DHCP (Dynamic Host Configuration Protocol)** hostga manzil va sozlamalarni avtomatik beradi. UDP ustida: server 67-port, mijoz 68-port. Mijozda hali IP yo'q, shuning uchun almashinuv broadcast bilan boshlanadi (**DORA**):

| Qadam | Kimdan | Mazmuni |
|-------|--------|---------|
| Discover | mijoz, `0.0.0.0` dan `255.255.255.255` ga | "DHCP server bormi?" |
| Offer | server | "sizga `192.168.1.23` ni taklif qilaman" |
| Request | mijoz, broadcast | "`192.168.1.23` ni olaman" (boshqa serverlar ham eshitsin) |
| Ack | server | "tasdiqlandi, lease 24 soat" |

Server manzil bilan birga beradi: subnet mask, default gateway (router), DNS serverlar, lease muddati, ba'zan domen nomi, NTP, MTU.

**Lease** vaqtinchalik ijara. Muddatning 50 foizida (T1) mijoz o'sha serverdan unicast bilan uzaytirishni so'raydi, 87.5 foizida (T2) javob bo'lmasa istalgan serverdan broadcast bilan. Muddat tugasa manzil qaytariladi. `ip addr` dagi `dynamic` va `valid_lft` shu lease.

DHCP broadcast'ga tayanadi, demak faqat o'z LAN'ida ishlaydi. Boshqa subnet'dagi serverga yetkazish uchun router'da **DHCP relay** sozlanadi.

Qayerda ko'riladi:

```
networkctl status eth0           # Ubuntu server (systemd-networkd): address, gateway, DNS, lease
nmcli device show wlp0s20f3      # desktop (NetworkManager): IP4.ADDRESS, IP4.GATEWAY, IP4.DNS
sudo tcpdump -i eth0 -n -e 'udp port 67 or udp port 68'
```

Server muhitida: cloud VM'lar manzilni DHCP orqali oladi, lekin manzil VPC'da instansga biriktirilgan va o'zgarmaydi. Statik manzil kerak bo'lsa ham uni odatda qo'lda emas, DHCP reservation (MAC bo'yicha doimiy manzil) yoki cloud API orqali beriladi.

**Tuzoq: LAN'da ikkinchi DHCP server.** Kimdir tarmoqqa o'z routerini ulasa, mijozlarning bir qismi undan noto'g'ri gateway va DNS oladi. Belgisi: ba'zi qurilmalarda internet yo'q, `ip route` da notanish gateway. `169.254.x.x` manzil esa teskari holat: hech qaysi DHCP server javob bermagan.

## 6. IPv6

128 bit, sakkizta 16 bitli guruh hex ko'rinishida: `2001:0db8:0000:0000:0000:ff00:0042:8329`.

Qisqartirish qoidalari:

1. Guruh boshidagi nollar tashlanadi: `0db8` bu `db8`, `0042` bu `42`.
2. Ketma-ket nol guruhlar bir marta `::` bilan almashtiriladi: `2001:db8::ff00:42:8329`.
3. `::` manzilda faqat bir marta ishlatiladi, aks holda nechta guruh tashlangani noaniq.

| Diapazon | Nomi | IPv4 dagi o'xshashi |
|----------|------|---------------------|
| `::1/128` | loopback | `127.0.0.1` |
| `fe80::/10` | link-local, har interfeysda avtomatik bor | `169.254.0.0/16`, lekin doim mavjud |
| `fc00::/7` (amalda `fd00::/8`) | unique local (ULA) | RFC 1918 private |
| `2000::/3` | global unicast | public |
| `ff00::/8` | multicast | `224.0.0.0/4` |
| `2001:db8::/32` | documentation | `192.0.2.0/24` |
| `::/0` | default route | `0.0.0.0/0` |

Asosiy farqlar:

- **Subnet hajmi deyarli doim /64**: 64 bit network, 64 bit interfeys identifikatori. Subnet hisobi IPv4 dagidek tejash uchun emas, faqat tuzilma uchun.
- **Broadcast yo'q**, o'rnida multicast. ARP o'rnida NDP (ICMPv6).
- **SLAAC**: host router e'lon qilgan /64 prefiksga o'zi interfeys identifikatorini qo'shib manzil yasaydi, DHCP shart emas.
- **NAT odatda yo'q**: har qurilma global manzil oladi, himoya firewall bilan.
- Link-local manzilga murojaat qilganda interfeys ko'rsatiladi: `ping fe80::1%eth0`.
- URL'da manzil kvadrat qavsda: `http://[2001:db8::1]:8080/`.

```
ip -6 addr
ip -6 route
ping -6 -c 2 ::1
```

**Tuzoq: IPv6 ni "ishlatmaymiz" deb firewall'da unutish.** Host IPv6 manzilga ega bo'lsa va firewall faqat IPv4 qoidalarini o'z ichiga olsa, servis IPv6 orqali ochiq qoladi. `ss -tlnp` da `[::]:22` ko'rinsa, servis IPv6 da ham tinglayapti.

## 7. Manzil rejasini tuzish

VPC, Kubernetes klasteri yoki ofis tarmog'ini loyihalashda:

1. **Kesishmaslik**: bir-biri bilan ulanadigan tarmoqlar (VPC peering, VPN, ofis) diapazonlari kesishmasligi kerak. Kesishsa routing imkonsiz, keyin o'zgartirish esa butun tarmoqni qayta qurish demak.
2. **Zaxira**: hozirgi ehtiyojdan kamida 2–4 barobar katta oling. VPC uchun `/16`, subnet uchun `/20`–`/24` odatiy.
3. **Tuzilma**: muhit va zona bo'yicha tekis bo'ling, masalan `10.<muhit>.<zona va rol>.0/24`. Summarization imkonini saqlang.
4. **Mashhur diapazonlardan qoching**: `192.168.0.0/24`, `192.168.1.0/24`, `10.0.0.0/24` uy routerlarida va `172.17.0.0/16` Docker'da band. Xodim uydan VPN orqali ulansa to'qnashuv bo'ladi.
5. **Provayder zaxirasi**: cloud har subnet'da bir nechta manzilni o'ziga oladi (AWS'da 5 ta: birinchi to'rtta va oxirgi). `/28` da 16 emas, 11 ta ishlatiladigan manzil qoladi.
6. **Kubernetes**: node, pod va service uchun uchta alohida, kesishmaydigan diapazon kerak. Pod tarmog'i katta bo'ladi (har node uchun odatda /24).

## Tuzoqlar

- VPC yoki ofis tarmoqlarini kesishadigan CIDR bilan yaratish. Peering yoki VPN kerak bo'lgan kuni tuzatib bo'lmaydi.
- `172.16.0.0/12` ni `/16` yoki `/8` deb o'ylash, firewall qoidasiga noto'g'ri diapazon yozish.
- Network yoki broadcast manzilni hostga berish, yoki subnet hajmini hisoblaganda bu ikki manzil va provayder zaxirasini unutish.
- Bir LAN'dagi hostlarda har xil mask: qisman ishlaydigan, tashxisi qiyin aloqa.
- Servisni `0.0.0.0` da tinglatib, "ichki tarmoqda turibdi" deb himoyasiz qoldirish. Yoki teskarisi: konteynerda `127.0.0.1` da tinglatib, nega ulanib bo'lmasligini qidirish.
- `ip addr add` ni prefikssiz yozish (`/32` bo'lib qoladi).
- Subnet'ni tor olish: `/28` dagi Kubernetes node guruhi yoki load balancer manzillari tugab, scale to'xtaydi.
- IPv6 mavjudligini unutish: firewall va `ss` tekshiruvida faqat IPv4 ga qarash.
- Statik manzilni DHCP pool ichidan qo'lda berish: ertami-kechmi DHCP o'sha manzilni boshqa qurilmaga beradi.

## Manbalar

- https://www.rfc-editor.org/rfc/rfc1918 – private manzillar
- https://www.rfc-editor.org/rfc/rfc4632 – CIDR
- https://www.rfc-editor.org/rfc/rfc2131 – DHCP
- https://www.rfc-editor.org/rfc/rfc4291 – IPv6 manzil arxitekturasi
- https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml – maxsus IPv4 diapazonlar reyestri
- https://man7.org/linux/man-pages/man8/ip-address.8.html – `ip address`
- https://docs.python.org/3/library/ipaddress.html – Python `ipaddress` moduli
- https://netplan.readthedocs.io/ – netplan hujjatlari
- https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html – AWS subnet hajmi va band manzillar
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 4.3-bo'lim (IPv4 addressing, DHCP, IPv6)

---

## Vazifalar

Ish papkasi: `network/03-ip-addressing/` (`make new m=network n=03 name=ip-addressing`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. A va B guruhlarda avval qo'lda hisoblang (hisob qadamlarini yozing), keyin `ipcalc` yoki Python bilan tekshiring. D guruh `net1` VM ichida.

### A. Qo'lda hisob

1. **Binary conversion.** `172.20.150.9` ni ikkilik ko'rinishga, `11000000.10101000.00000101.10000010` ni o'nlik ko'rinishga o'tkazing. `/19` va `/27` uchun mask'ni o'nlik va ikkilik ko'rinishda yozing.

2. **Subnet facts.** Har biri uchun network, broadcast, birinchi va oxirgi host, hostlar sonini block size usuli bilan toping: (a) `192.168.5.130/25`; (b) `10.1.1.77/28`; (c) `172.16.45.200/21`; (d) `10.200.13.1/12`; (e) `192.168.100.255/23`. (e) dagi manzil hostga berilishi mumkinmi?

3. **Same subnet or not.** Har juftlik bir subnet'dami? Bit darajasida `AND` bilan asoslang: (a) `10.0.5.10/23` va `10.0.4.200/23`; (b) `192.168.1.126/26` va `192.168.1.129/26`; (c) `172.16.31.5/20` va `172.16.32.5/20`.

4. **Private or public.** Har manzil turini (private, public, loopback, link-local, CGNAT, multicast, documentation) aniqlang va diapazonini yozing: `172.15.0.1`, `172.31.255.254`, `172.32.0.1`, `192.169.1.1`, `10.255.255.255`, `100.72.3.4`, `169.254.169.254`, `127.8.8.8`, `224.0.0.251`, `203.0.113.7`, `8.8.8.8`.

5. **Split a network.** `10.50.0.0/22` ni (a) to'rtta teng subnet'ga; (b) biri 500 host, ikkitasi 100 hostdan, biri 50 host sig'adigan har xil hajmli subnet'larga (VLSM) bo'ling. Har subnet uchun CIDR, diapazon va bo'sh qolgan joyni yozing.

6. **Summarize.** `192.168.8.0/24`, `192.168.9.0/24`, `192.168.10.0/24`, `192.168.11.0/24` ni bitta yozuvga birlashtiring. `192.168.9.0/24` va `192.168.10.0/24` ni nima uchun bitta `/23` ga birlashtirib bo'lmasligini bit darajasida ko'rsating.

### B. O'z tarmog'ingiz

7. **My addresses.** Ish mashinasida `ip -br addr` dagi har bir IPv4 va IPv6 manzil uchun yozing: turi (private, link-local, global, loopback), `scope`, qayerdan kelgan (DHCP, SLAAC, Docker, kernel). Faol interfeysning network va broadcast manzilini qo'lda hisoblab, `ip addr` dagi `brd` bilan solishtiring.

8. **DHCP lease.** `nmcli device show <iface>` chiqishidan DHCP bergan barcha sozlamalarni yozing (manzil, gateway, DNS). `ip addr` dagi `valid_lft` bo'yicha lease qachon tugashini va T1 qachon bo'lishini hisoblang. Public IP'ingiz (`curl -s https://ifconfig.me`) `ip addr` dagi manzildan nima uchun farq qiladi?

9. **Docker subnets.** `docker network inspect bridge` dan subnet va gateway'ni toping. `docker network create --subnet 10.77.0.0/29 tiny` yarating va unga ketma-ket konteynerlar ulang (`docker run -d --network tiny alpine sleep 600`). Nechanchi konteynerda xato chiqdi, xato matni qanday, va bu son hisobingizga mos keladimi? Tozalang.

10. **Listen address.** `python3 -m http.server 8000 --bind 127.0.0.1` ni ishga tushiring va `ss -tlnp | grep 8000` ni ko'ring. `curl` bilan `127.0.0.1:8000` va o'z LAN IP'ingiz orqali ulanib ko'ring. `--bind 0.0.0.0` bilan takrorlang. Natijalar farqini va xato matnini izohlang. Server'ni to'xtating.

### C. IPv6

11. **IPv6 notation.** To'liq yozing: `2001:db8::1`, `fe80::1`, `::1`. Qisqartiring: `2001:0db8:0000:0000:0000:0000:0000:0001`, `fd00:0000:0000:0010:0000:0000:0a00:0001`. `2001:db8::1::5` nima uchun noto'g'ri?

12. **IPv6 on my host.** `ip -6 addr` va `ip -6 route` chiqishini yozing. Har manzilning turini aniqlang. Sizda global IPv6 bormi? `ping -6 -c 2 ::1` va o'z link-local manzilingizga `%iface` bilan va usiz ping qilib, farqni izohlang.

### D. VM ichida

13. **Dummy interface.** `net1` da `dummy0` interfeysi yarating, `up` qiling va `10.10.10.1/24` bering. `ip route` da qanday yangi qator paydo bo'ldi va uni kim yaratdi? `ping -c 2 10.10.10.1` va `ping -c 2 10.10.10.2` natijalarini izohlang.

14. **Missing prefix.** `dummy0` ga `10.20.20.1` ni prefikssiz qo'shing. `ip addr` va `ip route` da nima ko'rindi? `/24` bilan qo'shilgan holatdan farqini va bu nima uchun real interfeysda aloqani buzishini yozing. Manzilni o'chiring.

15. **Secondary address.** `dummy0` ga `10.10.10.2/24` va `10.10.10.3/24` ni ham qo'shing. `ip addr` da ular qanday belgilangan? Avval birinchi (primary) manzilni o'chirib ko'ring: qolganlariga nima bo'ldi? Bir interfeysda bir nechta manzil real hayotda qayerda kerak bo'lishiga bitta misol yozing.

16. **Watch DORA.** VM'ning asosiy interfeysi nomini aniqlang (`ip -br link`). Bir sessiyada `sudo tcpdump -i <iface> -n -e 'udp port 67 or udp port 68'`, ikkinchisida `sudo networkctl renew <iface>` ni ishga tushiring. Qaysi DHCP xabarlari ko'rindi, to'liq DORA'dan nimasi bilan farq qiladi va nima uchun? Manba va manzil IP hamda MAC'larni yozing.

17. **Lease details.** `networkctl status <iface>` va `cat /etc/netplan/*.yaml` (kerak bo'lsa `sudo`) chiqishidan VM manzilni qanday olayotganini tushuntiring: DHCP server kim (qaysi IP, u hostdagi qaysi interfeys), lease muddati, DNS server.

18. **ipcalc check.** 2 va 5-vazifalardagi barcha javoblaringizni `ipcalc` bilan tekshiring. Farq chiqqan joylarni README'da tuzatmasdan, xato sababini yozing (qaysi qadamda adashdingiz).

### E. Yig'ish

19. **Address plan.** Kompaniya uchun manzil rejasini tuzing: uch muhit (dev, staging, prod), har birida alohida VPC; har VPC'da 3 availability zone, har zonada public va private subnet; prod'da qo'shimcha Kubernetes pod va service diapazonlari; ofis tarmog'i va VPN mijozlari uchun diapazon. Talablar: hech narsa kesishmaydi, har muhit bitta summary prefiks bilan ifodalanadi, private subnet'da kamida 1000 host. Natijani jadval ko'rinishida `plan.md` ga yozing va har tanlov sababini izohlang.

20. **Validate the plan.** `plan.md` dagi barcha CIDR'larni o'qib, kesishma yo'qligini tekshiradigan qisqa skript yozing (`check_plan.py`, Python `ipaddress` moduli, `overlaps()` metodi). Ataylab bitta kesishadigan diapazon qo'shib skript uni topishini ko'rsating, keyin olib tashlang.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 20 ta vazifa, qo'lda hisob qadamlari bilan (faqat natija emas).
2. `plan.md` va `check_plan.py` papkada, skript xatosiz ishlaydi.
3. `make check` toza.
4. VM'dagi `dummy0` o'chirilgan (`sudo ip link del dummy0`), Docker `tiny` tarmog'i va konteynerlari o'chirilgan.
5. Menga xabar bering, tekshiraman.

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
