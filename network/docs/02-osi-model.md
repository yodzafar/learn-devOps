# 2-dars: OSI modeli

Maqsad: tarmoqdagi har bir narsani (kabel, MAC, IP, port, TLS, HTTP) bitta xaritaga joylash. Bu xarita OSI modeli: 7 qatlam, har biri bitta savolga javob beradi. Dars oxirida istalgan xato matnini ("Connection refused", "Network is unreachable", "certificate has expired") ko'rib, muammo qaysi qatlamda ekanini va uni qaysi asbob bilan tekshirishni ayta olasiz, `tcpdump` bilan paket ushlab uni qatlamma-qatlam o'qiy olasiz.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–4 bo'limlar va A guruh vazifalari, ikkinchi kun 5–7 bo'limlar, "Birga bajaramiz" va B guruh, uchinchi kun C va D guruhlari hamda README. Diqqatni quyidagilarga qarating: har qatlamning PDU nomi va manzil turi, encapsulation (header ichida header), yo'l davomida nima o'zgaradi va nima o'zgarmaydi, xato matnidan qatlamni topish, tcpdump flag belgilari.

Qanday o'qish kerak: HTTP sizga tanish, lekin undan pastdagi hamma narsa (TCP, IP, frame) bu darsda noldan tushuntiriladi. Har misolni o'zingiz ishga tushiring; sizdagi IP, MAC, port va vaqt qiymatlari farq qiladi, bunday joylar `<...>` bilan belgilangan yoki "sizda boshqacha" deyilgan. 1-darsdagi frame, MAC, ARP va gateway tushunchalari bu yerda takrorlanmaydi, faqat eslatiladi.

## Laboratoriya

Asosiy ish joyi host'dagi Docker'da ishlaydigan `nicolaka/netshoot` konteyneri (`linux/amd64` va `linux/arm64` uchun chiqadi). Konteyner ichida siz root, shuning uchun `tcpdump` ga `sudo` kerak emas va u faqat konteynerning o'z trafigini ko'radi, host trafigini emas. Repo ildizidan:

```
mkdir -p network/02-osi-model/pcap
docker run --rm -it --name shoot --cap-add NET_ADMIN \
  -v "$PWD/network/02-osi-model/pcap:/pcap" nicolaka/netshoot
```

Ikkinchi terminal: `docker exec -it shoot bash`. Bir terminalda `tcpdump`, ikkinchisida so'rov yuboriladi. `-v` bind mount: konteynerdagi `/pcap` ga yozilgan fayllar host'dagi ish papkasida qoladi.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `docker run`, `make`, `git`, ixtiyoriy Wireshark |
| `shoot` konteyneri | `shoot:~#` yoki `<id>:~#` | 5–13 va 16–18-vazifalar: `tcpdump`, `curl`, `dig`, `nc`, `ping` |
| `lab` VM | `ubuntu@lab:~$` | 14 va 15-vazifalar (TTL va path MTU) |

- **`lab` VM** (`SETUP.md`): TTL va MTU tajribalari shu yerda, chunki u ikkala mashinada bir xil ishlaydi (pastdagi jadvalga qarang). `tcpdump` 1-darsda o'rnatilgan; VM qayta yaratilgan bo'lsa: `sudo apt update && sudo apt install -y tcpdump`.
- **Wireshark (ixtiyoriy)**: `.pcap` faylni grafik ko'rish uchun, faqat fayl ochishga ishlatiladi. Zorin: `sudo apt install wireshark` (o'rnatishdagi "non-superusers capture" savoliga "No" yetarli). macOS: `brew install --cask wireshark`. O'rnatmasangiz ham hamma vazifa `tcpdump -r` bilan bajariladi.
- **Tozalash**: konteynerdan `exit` (`--rm` uni o'chiradi). `pcap/*.pcap` fayllarini commit qilmang (ichida real trafik bor), `.gitignore` ga qo'shing.
- Bu dars oldingi holatga tayanmaydi. Mashinani almashtirsangiz, konteynerni qayta ishga tushirish yetarli; pcap fayllar ko'chmaydi (ular git'da emas), kerak bo'lsa qayta yozib olinadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Konteyner host kernel'ining `docker0` bridge'iga ulangan, gateway odatda `172.17.0.1`. Konteynerdan chiqqan ICMP va TTL tajribalari haqiqiy yo'lni ko'rsatadi. VM interfeysi odatda `ens3`. |
| macOS (uy) | Konteyner Docker Desktop'ning yashirin Linux VM'i ichida; uning tashqi dunyoga chiqishi user-space proxy orqali o'tadi, shuning uchun konteyner ichidagi TTL (`ping -t`) va path MTU tajribalari haqiqiy yo'lni ko'rsatmasligi mumkin. Shu sababli 14 va 15-vazifalar ikkala mashinada ham `lab` VM'da bajariladi. VM interfeysi odatda `enp0s1`. Host'da `tcpdump`, `curl`, `dig` bor, lekin vazifalar konteynerda bajariladi, chiqish bir xil bo'lishi uchun. |

Interfeys nomini doim o'zingiz aniqlang: konteynerda `ip -br addr` (odatda `eth0`), VM'da ham `ip -br addr`.

---

## 1. Nima uchun qatlamlar

### Bu nima

Tarmoq orqali bitta HTTP so'rov yuborish uchun o'nlab masala yechilishi kerak: signalni simga chiqarish, qo'shni qurilmani topish, dunyoning narigi chetidagi serverga yo'l topish, yo'qolgan bo'laklarni qayta yuborish, shifrlash, so'rov formatini kelishish. Bularni bitta ulkan dastur emas, **qatlamlar** (layers) yechadi: har qatlam bitta masalani hal qiladi, pastki qatlam xizmatidan foydalanadi va yuqori qatlamga xizmat ko'rsatadi.

### Mexanizm

Ikki qoida bor:

1. Har qatlam faqat o'zining qo'shnilari bilan (bir pog'ona yuqori va past) gaplashadi.
2. Har qatlam narigi kompyuterdagi **o'z tengdoshi** bilan protokol orqali "gaplashadi": brauzer HTTP'si server HTTP'si bilan, sizning TCP'ingiz server TCP'si bilan. Pastki qatlamlar buni ko'rinmas tashuvchi sifatida ta'minlaydi.

Frontend o'xshatishi haqiqiy: `fetch('/api/users')` yozganingizda TCP qayta yuborishi, IP routing yoki Wi-Fi haqida o'ylamaysiz. `fetch` HTTP qatlamida ishlaydi va pastdagilarga ishonadi. Xuddi shunday, Wi-Fi'dan simga o'tsangiz, kodingiz o'zgarmaydi: pastki qatlam almashdi, yuqoridagilar buni sezmadi.

### Misol: bitta buyruq, to'rt qatlam

`shoot` konteynerida:

```
shoot:~# curl -s -o /dev/null -w '%{remote_ip}:%{remote_port} http=%{http_code}\n' http://example.com/
<IP>:80 http=200
```

Bitta qator ortida: nom IP'ga aylandi (DNS), o'sha IP'ning 80-portiga TCP ulanish ochildi, paketlar gateway orqali yo'l topdi, HTTP so'rov ketdi va `200` javob keldi. Dars davomida shu bosqichlarning har birini alohida ko'rasiz.

### Real ishda qachon kerak

Model amalda ikki narsa uchun ishlatiladi:

1. **Tashxis**: qatlamlar tartib beradi. Pastdan yuqoriga tekshirasiz va birinchi buzilgan qatlamda to'xtaysiz; undan yuqoridagilarni tekshirish befoyda.
2. **Umumiy til**: hamkasb "bu L4 load balancer", "L7 firewall" yoki "L2 da muammo" desa, gap aynan shu qatlam raqamlari haqida.

### Nima uchun shunday

Qatlamlarga bo'lish har qismni mustaqil almashtirish imkonini beradi: Ethernet o'rniga Wi-Fi, IPv4 o'rniga IPv6, HTTP/1.1 o'rniga HTTP/2 keldi, qolgan qatlamlar o'zgarmadi. Muqobili (hammasi bitta protokolda) 1970-yillarda sinab ko'rilgan: har ishlab chiqaruvchining o'z yopiq tarmog'i bo'lgan va ular bir-biri bilan gaplasha olmagan.

---

## 2. OSI 7 qatlami

### Bu nima

OSI (Open Systems Interconnection) bu ISO 1984-yilda e'lon qilgan etalon model. U protokol emas, lug'at: hamma bir xil raqam va nomlardan foydalanadi. Qatlamlar pastdan sanaladi.

| # | Qatlam | Qaysi savolga javob beradi | PDU | Manzil | Misollar |
|---|--------|----------------------------|-----|--------|----------|
| 7 | Application | dastur nima demoqchi | data | URL, nom | HTTP, DNS, SSH, SMTP |
| 6 | Presentation | ma'lumot qanday kodlangan, shifrlangan | data | | TLS, UTF-8, gzip |
| 5 | Session | suhbat qanday ochiladi, davom etadi, yopiladi | data | | TLS session, RPC sessiyalari |
| 4 | Transport | qaysi dasturga, ishonchli yoki yo'q | segment (TCP), datagram (UDP) | port | TCP, UDP |
| 3 | Network | qaysi tarmoqdagi qaysi hostga, qaysi yo'l bilan | packet | IP manzil | IPv4, IPv6, ICMP |
| 2 | Data Link | shu LAN ichida qaysi qurilmaga | frame | MAC manzil | Ethernet, Wi-Fi, ARP |
| 1 | Physical | bitlar qanday signalga aylanadi | bit | | kabel, optika, radio |

**PDU** (Protocol Data Unit) bu qatlamning ma'lumot bo'lagi nomi. "Paket yo'qoldi" va "frame yo'qoldi" turli qatlamdagi gaplar. **Port** bu bitta host ichidagi dasturni ajratadigan 0–65535 oralig'idagi raqam (4-dars): IP uyning manzili bo'lsa, port xonadon raqami.

### Mexanizm: qaysi qatlam qayerda yashaydi

| Qatlam | Kim amalga oshiradi |
|--------|---------------------|
| 7, 6, 5 | dastur va uning kutubxonalari (brauzer, `curl`, nginx, OpenSSL) |
| 4, 3 | kernel (TCP/IP steki) |
| 2 | kernel drayveri va tarmoq kartasi |
| 1 | tarmoq kartasi va kabel yoki radio |

Shu sabab 5–7 qatlamlar amalda bitta bo'lib ketadi: ularni bitta dastur bajaradi. "L7" deganda odatda uchalasi birga tushuniladi. Ba'zi protokollar bitta katakka sig'maydi: ARP L2 va L3 chegarasida, TLS 5 va 6 orasida, ICMP IP ichida yuradi, lekin L3 hisoblanadi.

### Misol: bitta paketda to'rt qatlam

`tcpdump -e` bitta qatorda bir nechta qatlamni ko'rsatadi (`shoot` ichida, ikkinchi terminalda `curl http://example.com/`):

```
shoot:~# tcpdump -i eth0 -nn -e -c 1 'tcp port 80'
<vaqt> <src MAC> > <dst MAC>, ethertype IPv4 (0x0800), length 74: 172.17.0.2.51734 > <server IP>.80: Flags [S], seq 2071549380, win 64240, options [mss 1460,sackOK,TS val 1 ecr 0,nop,wscale 7], length 0
```

- `<src MAC> > <dst MAC>, ethertype IPv4`: L2. Dst MAC gateway'niki (1-dars).
- `172.17.0.2 > <server IP>`: L3, IP manzillar.
- `.51734 > .80`, `Flags [S]`, `seq`, `win`: L4, TCP portlar va holat.
- `length 0`: L7 ma'lumot hali yo'q, bu faqat ulanish ochish paketi.

### Real ishda qachon kerak

- Hujjat va suhbatlarda: "L2 da muammo", "L3 switch", "L7 routing". Raqamlarni yoddan bilish kerak.
- AWS'da NLB (L4) va ALB (L7) tanlovi, Kubernetes'da Service (L4) va Ingress (L7) farqi.

### Nima uchun shunday

OSI protokollarining o'zi (X.25, CLNP) yutqazdi, internet TCP/IP ustiga qurildi. Lekin OSI'ning lug'ati qoldi, chunki u aniqroq: 7 ta raqam har xil ishlab chiqaruvchi va jamoalar orasida umumiy til beradi. Shuning uchun amalda "TCP/IP protokollari, OSI raqamlari" ishlatiladi.

---

## 3. TCP/IP modeli va moslik

### Bu nima

Internet haqiqatda TCP/IP modeli bo'yicha qurilgan. U 4 qatlamli va OSI'dan oldin, ishlaydigan kod asosida paydo bo'lgan.

| TCP/IP qatlami | OSI qatlamlari | Protokollar |
|----------------|----------------|-------------|
| Application | 7, 6, 5 | HTTP, DNS, TLS, SSH |
| Transport | 4 | TCP, UDP |
| Internet | 3 | IP, ICMP |
| Link | 2, 1 | Ethernet, Wi-Fi, ARP |

### Mexanizm

TCP/IP'ning markazida IP turadi ("qum soati" shakli): pastda istalgan texnologiya (sim, radio, optika), tepada istalgan dastur, o'rtada yagona IP. Har qanday yangi tarmoq texnologiyasi faqat IP paket tashiy olsa bo'ldi, tepadagi hamma narsa o'zgarishsiz ishlaydi.

### Misol: kernel qaysi yo'lni tanlaydi

L3 qarorini kernel'dan to'g'ridan-to'g'ri so'rash mumkin:

```
shoot:~# ip route get 1.1.1.1
1.1.1.1 via 172.17.0.1 dev eth0 src 172.17.0.2 uid 0
```

- `via 172.17.0.1`: keyingi hop, ya'ni gateway (manzil boshqa tarmoqda).
- `dev eth0`: Link qatlamida qaysi interfeysdan chiqadi.
- `src 172.17.0.2`: paketga jo'natuvchi sifatida yoziladigan IP.
- `uid 0`: so'ragan foydalanuvchi (root).

Bu buyruq hech narsa yubormaydi, faqat "yuborsam nima bo'lardi" degan savolga javob beradi. Sizda manzillar boshqa bo'lishi mumkin.

### Real ishda qachon kerak

- RFC'lar va kernel hujjatlari TCP/IP atamalarida yozilgan ("link layer", "internet layer").
- `ip route get` tashxisda birinchi L3 tekshiruvi: paket umuman qayerga ketmoqchi.

### Nima uchun shunday

TCP/IP amaliyotdan chiqqan: avval ishlaydigan kod, keyin hujjat. Session va presentation alohida qatlam qilinmagan, chunki har dasturning ehtiyoji har xil va ularni dastur o'zi hal qilgani ma'qul. OSI esa qo'mita tomonidan oldindan loyihalangan va joriy qilish qiyin bo'lgan.

---

## 4. Encapsulation

### Bu nima

Yuborishda har qatlam yuqoridan kelgan ma'lumotga o'z **header**'ini (sarlavha: shu qatlamga kerakli xizmat ma'lumoti) qo'shadi va natijani pastga beradi. Bu **encapsulation**. Qabul qilishda teskari tartibda yechiladi (decapsulation).

```
[ HTTP request                                    ]   L7 data
[ TCP hdr | HTTP request                          ]   L4 segment
[ IP hdr | TCP hdr | HTTP request                 ]   L3 packet
[ Eth hdr | IP hdr | TCP hdr | HTTP request | FCS ]   L2 frame
```

Har qatlam o'zidan yuqoridagini shunchaki baytlar (payload) deb ko'radi va ichiga qaramaydi.

### Mexanizm: header'lar va hajmlar

| Header | Minimal hajm | Asosiy maydonlar |
|--------|--------------|------------------|
| Ethernet | 14 bayt (+4 FCS) | dst MAC, src MAC, EtherType |
| IPv4 | 20 bayt | src IP, dst IP, TTL, protocol (6 TCP, 17 UDP, 1 ICMP), flags (DF) |
| IPv6 | 40 bayt | src IP, dst IP, hop limit, next header |
| TCP | 20 bayt | src port, dst port, seq, ack, flags, window |
| UDP | 8 bayt | src port, dst port, length, checksum |
| ICMP | 8 bayt | type, code, checksum |

**TTL** (Time To Live) bu IP header'dagi hisoblagich: har router uni bittaga kamaytiradi, nolga yetsa paketni tashlaydi va jo'natuvchiga ICMP "time exceeded" xabarini qaytaradi. Maqsadi: adashgan paket tarmoqda abadiy aylanib yurmasligi.

Bundan ikki amaliy son chiqadi:

- **MTU 1500**: frame payload'i, ya'ni butun IP paket (header bilan) shu hajmga sig'ishi kerak (1-dars).
- **MSS** (Maximum Segment Size) **1460**: bitta TCP segmentdagi ma'lumot hajmi. `1500 - 20 (IP) - 20 (TCP) = 1460`. Tomonlar MSS'ni ulanish ochilishida e'lon qiladi (2-bo'limdagi misolda `mss 1460`).

Yo'l davomida nima o'zgaradi:

| Qatlam | Har hop'da | Butun yo'l davomida |
|--------|-----------|---------------------|
| L2 frame | qaytadan yasaladi, MAC'lar o'zgaradi | |
| L3 packet | TTL bittaga kamayadi | src va dst IP saqlanadi (NAT bo'lmasa) |
| L4 segment | tegilmaydi | portlar saqlanadi (NAT bo'lmasa) |
| L7 data | tegilmaydi (proxy bo'lmasa) | |

### MTU, fragmentatsiya va PMTUD

Paket yo'ldagi biror liniyaning MTU'sidan katta bo'lsa, ikki yo'l bor. IPv4 router uni bo'laklarga bo'lishi mumkin (fragmentatsiya), lekin bu sekin va mo'rt. Shuning uchun zamonaviy hostlar IP header'ga **DF** (Don't Fragment) bayrog'ini qo'yadi: sig'masa router paketni tashlaydi va ICMP "fragmentation needed" xabarini qaytaradi, jo'natuvchi hajmni kichraytiradi. Bu jarayon **PMTUD** (Path MTU Discovery). Yo'ldagi firewall ICMP'ni to'sib qo'ysa, PMTUD buziladi: kichik so'rovlar o'tadi, katta javoblar osilib qoladi.

### Misol: 1472 soni qayerdan

`ping -s N` ICMP ma'lumot hajmini beradi, `-M do` DF bayrog'ini qo'yadi. `lab` VM'da:

```
ubuntu@lab:~$ ping -c 1 -M do -s 1400 <gateway IP>
1408 bytes from <gateway IP>: icmp_seq=1 ttl=64 time=0.412 ms
```

- `-s 1400`: 1400 bayt ma'lumot.
- `1408 bytes`: 1400 + 8 bayt ICMP header. Ustiga 20 bayt IP header qo'shilsa, IP paket 1428 bayt, MTU 1500 ga sig'adi.
- Eng katta sig'adigan `-s` qiymati: `1500 - 20 - 8 = 1472`. Undan kattasi bilan nima bo'lishini 15-vazifada ko'rasiz.

### Real ishda qachon kerak

- VPN va tunnel'lar o'z header'ini qo'shadi va MTU'ni kichraytiradi (WireGuard'da 1420). "SSH ishlaydi, lekin katta fayl ko'chmaydi" alomati shu yerdan.
- Kubernetes overlay tarmoqlarida pod MTU'si node MTU'sidan kichik bo'ladi.

### Nima uchun shunday

Header ichida header isrofgarchilikdek ko'rinadi (har paketda kamida 54 bayt), lekin shu tufayli router TCP'ni, switch IP'ni bilishi shart emas: har qurilma faqat o'z qatlami header'ini o'qiydi. Muqobili, bitta umumiy header, har yangi protokolda barcha qurilmalarni yangilashni talab qilardi.

---

## 5. Qaysi asbob, qaysi muammo qaysi qatlamda

### Bu nima

Har qatlamning o'z asboblari va o'ziga xos xato matnlari bor. Xato matni odatda qatlamni aniq aytadi, faqat o'qishni bilish kerak.

| Qatlam | Asboblar | Tipik alomat |
|--------|----------|--------------|
| L1 | `ip link` (`LOWER_UP`), `ethtool` | `NO-CARRIER`, `state DOWN` |
| L2 | `ip neigh`, `bridge fdb`, `tcpdump -e arp` | neighbour `FAILED`, `Destination Host Unreachable` (o'z IP'ingizdan) |
| L3 | `ip addr`, `ip route get`, `ping`, `traceroute` | `Network is unreachable`, ping'ga javob yo'q |
| L4 | `ss`, `nc -vz`, `tcpdump` (flag'lar) | `Connection refused`, `Connection timed out` |
| L5–6 | `openssl s_client`, `curl -v` | `certificate has expired`, `SSL handshake` xatolari |
| L7 | `curl -v`, `dig`, dastur loglari | `Could not resolve host`, HTTP `404`, `502` |

### Mexanizm: eng ko'p uchraydigan to'rt xato

| Xato matni | Aslida nima bo'ldi | Qatlam |
|------------|--------------------|--------|
| `Could not resolve host` | nom IP'ga aylanmadi, hali hech qanday ulanish yo'q | L7 (DNS) |
| `Network is unreachable` | kernel routing table'da bu manzilga yo'l topmadi, paket chiqmadi | L3 |
| `Connection refused` | paket hostga yetdi, lekin o'sha portni hech kim tinglamayapti; host TCP `RST` qaytardi | L4 |
| `Connection timed out` | `SYN` ketdi, hech qanday javob kelmadi: firewall jimgina tashlagan yoki host yo'q | L3 yoki L4 |

`refused` yaxshi xabar: L1–L3 ishlayapti, host tirik. `timed out` da esa paket qayerda yo'qolganini izlash kerak.

### Tashxis tartibi

Pastdan yuqoriga, har qadam oldingisiga tayanadi:

```
ip -br link                 # L1: is the interface UP, LOWER_UP?
ip -br addr                 # L3: do I have an address?
ip route get <dst>          # L3: which gateway and interface?
ip neigh                    # L2: is the gateway resolved to a MAC?
ping -c 2 <gateway>         # L3: can I reach the gateway?
ping -c 2 <dst IP>          # L3: can I reach the destination?
nc -vz <dst IP> <port>      # L4: is the port open?
curl -v <url>               # L5-L7: TLS and HTTP
```

Ba'zan tezroq yo'l yuqoridan boshlash: `curl -v` ishlasa, pastdagi hammasi ishlayapti.

### L4 va L7 qurilmalar

| Qurilma | Nimaga qaraydi | Nima qila oladi |
|---------|----------------|-----------------|
| L4 load balancer, oddiy firewall | IP va port | ulanishni backend'ga uzatish, portni ochish yoki yopish |
| L7 load balancer, reverse proxy, WAF | HTTP yo'l, header, cookie | `/api` ni bir servisga, `/static` ni boshqasiga yuborish, TLS'ni yechish |

L7 qurilma ulanishni o'zida tugatadi va backend'ga yangi ulanish ochadi, L4 qurilma esa paketlarni shunchaki uzatadi.

### Misol: refused'ni ko'rish

```
shoot:~# nc -vz 127.0.0.1 8081
nc: connect to 127.0.0.1 port 8081 (tcp) failed: Connection refused
```

`127.0.0.1` mashinaning o'zi, L1–L3 da muammo bo'lishi mumkin emas. Xato faqat bitta narsani aytadi: 8081-portni hech kim tinglamayapti. Node'da `ECONNREFUSED` xuddi shu xato, kernel'dan keladigan bir xil kod.

### Real ishda qachon kerak

- On-call paytida: xato matnini ko'rib, 30 soniyada "bu DNS", "bu firewall" yoki "servis o'chgan" deya olish.
- Hamkasbga muammoni aniq yetkazish: "L4 gacha ishlayapti, TLS handshake'da uzilyapti".

### Nima uchun shunday

Pastdan yuqoriga tartib mantiqiy bog'liqlikdan kelib chiqadi: L3 ishlamasa L7 ni tekshirish befoyda. Xato matnlari turlicha, chunki ularni turli qatlamlar hosil qiladi: `unreachable` ni kernel'ning routing kodi, `refused` ni narigi tomon TCP'si, sertifikat xatosini TLS kutubxonasi.

---

## 6. Bitta HTTP so'rovning yo'li

### Bu nima

`curl http://example.com/` bajarilganda barcha qatlamlar ketma-ket ishlaydi. Bu bo'lim oldingi beshtasini bitta hikoyaga yig'adi.

### Mexanizm

1. **L7, DNS**: `example.com` IP'ga aylantiriladi. Bu o'zi alohida sayohat: UDP 53-port orqali resolver'ga so'rov (4-dars).
2. **L4, TCP handshake**: kernel tasodifiy manba port tanlaydi (masalan 51734) va `SYN` yuboradi. `SYN`, `SYN-ACK`, `ACK` dan keyin ulanish ochiq. Bu uch qadam **three-way handshake** deyiladi.
3. **L3, routing**: har paket uchun kernel routing table'dan chiqish interfeysi va keyingi hop'ni topadi. Manzil boshqa tarmoqda, demak keyingi hop default gateway.
4. **L2, ARP va frame**: gateway MAC'i neighbour table'dan olinadi (bo'lmasa ARP), frame yasaladi: dst MAC gateway'niki, dst IP serverniki.
5. **L1**: frame signalga aylanib kabel yoki radioga chiqadi.
6. **Yo'lda**: har router frame'ni yechadi, IP header'ga qaraydi, TTL'ni kamaytiradi, yangi frame yasab keyingi hop'ga yuboradi. Uy router'i manba IP'ni o'z public IP'siga almashtiradi (NAT, 6-dars).
7. **Serverda**: teskari tartib. Karta frame'ni oladi, kernel IP va TCP header'larni yechib, 80-portni tinglayotgan jarayonga baytlarni beradi. nginx faqat `GET / HTTP/1.1 ...` matnini ko'radi.
8. **Javob** xuddi shu yo'lni teskari bosib o'tadi, oxirida `FIN` lar bilan ulanish yopiladi.

HTTPS bo'lsa 2 va 7-qadamlar orasida TLS handshake qo'shiladi va HTTP baytlari shifrlangan holda TCP ichida ketadi. `tcpdump` unda faqat header'larni o'qiy oladi, mazmunni emas.

### Misol: curl -v bosqichlari

```
shoot:~# curl -v http://example.com/ -o /dev/null
* Host example.com:80 was resolved.
*   Trying <IP>:80...
* Connected to example.com (<IP>) port 80
> GET / HTTP/1.1
> Host: example.com
< HTTP/1.1 200 OK
```

(Qisqartirilgan; aniq matn `curl` versiyasiga qarab biroz farq qiladi.)

- `was resolved`: 1-qadam, DNS tugadi.
- `Trying <IP>:80...`: 2-qadam boshlandi, `SYN` ketdi.
- `Connected`: handshake tugadi. 3–6 qadamlar shu ikki qator orasida, ko'rinmas holda o'tdi.
- `>` bilan boshlangan qatorlar: yuborilgan HTTP so'rov (L7).
- `<` bilan boshlangan qatorlar: kelgan javob.

### Real ishda qachon kerak

- Sekinlik tashxisi: vaqt qaysi bosqichda ketyapti (DNS, connect, TLS, server javobi). `curl -w` har bosqich vaqtini beradi (16-vazifa).
- Brauzer DevTools'dagi Timing bo'limi (DNS Lookup, Initial connection, SSL, Waiting) aynan shu bosqichlar.

### Nima uchun shunday

Bitta so'rov uchun shuncha qadam ko'p tuyuladi, lekin har biri alohida kafolat beradi: DNS nomlarni IP'dan mustaqil qiladi, TCP yo'qolgan paketlarni tiklaydi, IP istalgan tarmoqdan o'tadi. Narxi kechikish; shuning uchun keep-alive (ulanishni qayta ishlatish), HTTP/2 va QUIC (handshake'larni birlashtirish) paydo bo'ldi.

---

## 7. tcpdump va Wireshark asoslari

### Bu nima

`tcpdump` interfeysdan o'tayotgan paketlarni ushlab, header'larini matn ko'rinishida chiqaradi. Wireshark xuddi shu ishni grafik oynada qiladi va har qatlamni alohida daraxt qilib ko'rsatadi. Ikkalasi bir xil **pcap** fayl formatini o'qiydi, shuning uchun serverda `tcpdump -w` bilan yozib, laptopda Wireshark'da ochish odatiy usul.

### Mexanizm: flag'lar va filtrlar

| Flag | Vazifasi |
|------|----------|
| `-i <iface>` | qaysi interfeys (`any` hammasi) |
| `-n`, `-nn` | IP'ni nomga (`-n`), portni ham servis nomiga (`-nn`) aylantirmaslik |
| `-c N` | N paketdan keyin to'xtash |
| `-e` | Ethernet header'ni ko'rsatish |
| `-v` | batafsilroq (TTL, IP flag'lar, uzunlik) |
| `-A`, `-X` | payload'ni ASCII (`-A`) yoki hex va ASCII (`-X`) ko'rinishida |
| `-w <fayl>`, `-r <fayl>` | pcap faylga yozish, fayldan o'qish |

Filtr (BPF sintaksisi) buyruq oxirida yoziladi:

```
host 1.1.1.1            # src or dst is this address
port 53                 # src or dst port
tcp, udp, icmp, arp     # by protocol
src host X, dst port Y  # by direction
A and B, A or B, not A  # combine
'tcp[tcpflags] & tcp-syn != 0'    # by TCP flag
```

TCP flag belgilari:

| Belgi | Flag | Ma'nosi |
|-------|------|---------|
| `[S]` | SYN | ulanish ochish so'rovi |
| `[S.]` | SYN+ACK | rozilik (nuqta ACK degani) |
| `[.]` | ACK | tasdiq |
| `[P.]` | PSH+ACK | ma'lumot bor |
| `[F.]` | FIN+ACK | ulanishni tartibli yopish |
| `[R]`, `[R.]` | RST | ulanishni darhol uzish yoki rad etish |

### Misol: bitta qatorni o'qish

```
14:03:22.118734 IP 172.17.0.2.51734 > <server IP>.80: Flags [P.], seq 1:75, ack 1, win 502, options [nop,nop,TS val 2 ecr 1], length 74: HTTP: GET / HTTP/1.1
```

- `14:03:22.118734`: vaqt, mikrosoniyagacha.
- `IP`: L3 protokol.
- `172.17.0.2.51734 > <server IP>.80`: manba IP va port, manzil IP va port. Oxirgi nuqtadan keyingi son port.
- `Flags [P.]`: PSH+ACK, ichida ma'lumot bor.
- `seq 1:75`: bu segment oqimning 1-baytidan 74-baytigacha (75 kirmaydi). tcpdump nisbiy raqamlarni ko'rsatadi.
- `ack 1`: narigi tomondan keyingi kutilayotgan bayt raqami.
- `win 502`: qabul oynasi, "yana shuncha qabul qila olaman" (masshtab bilan).
- `length 74`: TCP payload hajmi, ya'ni HTTP so'rov 74 bayt.
- `HTTP: GET / HTTP/1.1`: tcpdump payload boshini tanidi.

### Real ishda qachon kerak

- "So'rov serverga yetib keldimi?" degan savolga yagona ishonchli javob: serverda `tcpdump`. Log bo'lmasa ham paket ko'rinadi.
- Firewall tashxisi: `SYN` kelyapti, `SYN-ACK` ketmayapti, yoki umuman hech narsa kelmayapti.
- Production'da doim filtr va `-c` yoki `-w` bilan ishlating: filtrsiz chiqish terminalni to'ldiradi va SSH sessiyaning o'z trafigini ham ushlaydi.

### Nima uchun shunday

Nega `-n` deyarli majburiy? Usiz tcpdump har IP uchun teskari DNS so'rov yuboradi: chiqish sekinlashadi, o'zi qo'shimcha trafik hosil qiladi, DNS buzilgan paytda esa osilib qoladi. Nega pcap formati? U 1980-yillardan beri standart, deyarli barcha tarmoq asboblari o'qiydi. Wireshark qulayroq, lekin serverlarda grafik muhit yo'q, shuning uchun asosiy ko'nikma tcpdump.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| OSI modeli | tarmoq vazifalarini 7 qatlamga bo'ladigan etalon model |
| TCP/IP modeli | internet haqiqatda qurilgan 4 qatlamli model |
| qatlam (layer) | bitta masalani yechadigan va qo'shnilariga xizmat ko'rsatadigan pog'ona |
| PDU | qatlamning ma'lumot bo'lagi nomi: frame, packet, segment |
| header | qatlam ma'lumot oldiga qo'shadigan xizmat maydonlari |
| payload | header'dan keyingi, yuqori qatlamga tegishli baytlar |
| encapsulation | har qatlamning yuqoridan kelgan ma'lumotni o'z header'i bilan o'rashi |
| port | host ichidagi dasturni ajratadigan 0–65535 raqam |
| TCP | ishonchli, tartibli bayt oqimini beradigan transport protokoli |
| UDP | kafolatsiz, ulanishsiz transport protokoli |
| ICMP | IP'ning xizmat xabarlari protokoli (`ping`, xato xabarlari) |
| three-way handshake | TCP ulanishni ochadigan `SYN`, `SYN-ACK`, `ACK` almashinuvi |
| RST | TCP'ning ulanishni rad etish yoki darhol uzish bayrog'i |
| TTL | har router bittaga kamaytiradigan IP header hisoblagichi |
| MSS | bitta TCP segmentdagi ma'lumotning maksimal hajmi |
| DF | "bo'laklama" degan IP bayrog'i |
| PMTUD | yo'ldagi eng kichik MTU'ni ICMP yordamida aniqlash jarayoni |
| pcap | ushlangan paketlar saqlanadigan fayl formati |
| BPF filtr | tcpdump va Wireshark'da paketlarni tanlash ifodasi |
| L4 / L7 load balancer | trafikni port bo'yicha yoki HTTP mazmuni bo'yicha taqsimlaydigan qurilma |

## Tuzoqlar

- **`-n` siz ushlash.** Chiqish sekin, ichida o'zingiz hosil qilgan DNS trafik paydo bo'ladi.
- **Filtrsiz `tcpdump` SSH sessiyada.** Har chiqarilgan qator yangi SSH paket hosil qiladi va u ham ushlanadi. Kamida `not port 22` qo'shing.
- **`ping` ishlamadi, demak host o'chiq.** Ko'p firewall'lar ICMP'ni to'sadi, TCP port esa ochiq bo'lishi mumkin. `nc -vz` bilan tekshiring.
- **`refused` va `timed out` ni bir xil deb o'ylash.** Birinchisi "host tirik, port yopiq", ikkinchisi "javob umuman yo'q".
- **Filtrni qo'shtirnoqsiz yozish.** `(`, `&`, `[` belgilarini shell o'zi talqin qiladi. Murakkab filtrni `'...'` ichiga oling.
- **pcap'ni commit qilish.** Ichida cookie, token, ichki manzillar bo'lishi mumkin.
- **macOS'da konteyner ichidan TTL yoki MTU'ni o'lchash.** Docker Desktop tarmog'i orada proxy qo'yadi. Bu tajribalar `lab` VM'da.
- **HTTPS trafikda payload qidirish.** `-A` faqat shifrlangan baytlarni ko'rsatadi; ochiq ko'rinadigani TLS handshake'dagi server nomi (SNI) va header'lar.

## Manbalar

- `tcpdump(8)`: https://www.tcpdump.org/manpages/tcpdump.1.html
- `pcap-filter(7)`: https://www.tcpdump.org/manpages/pcap-filter.7.html
- Wireshark User's Guide: https://www.wireshark.org/docs/wsug_html_chunked/
- RFC 1122 (TCP/IP qatlamlari): https://www.rfc-editor.org/rfc/rfc1122
- RFC 791 (IPv4): https://www.rfc-editor.org/rfc/rfc791
- RFC 9293 (TCP): https://www.rfc-editor.org/rfc/rfc9293
- RFC 1191 (Path MTU Discovery): https://www.rfc-editor.org/rfc/rfc1191
- curl man sahifasi (`-v`, `-w`): https://curl.se/docs/manpage.html
- Cloudflare Learning, OSI model: https://www.cloudflare.com/learning/ddos/glossary/open-systems-interconnection-model-osi/
- netshoot: https://github.com/nicolaka/netshoot

---

## Birga bajaramiz

Tashqi tarmoqsiz, bitta konteyner ichida eng sodda TCP suhbatni quramiz va uni qatlamma-qatlam o'qiymiz: `nc` (netcat) bilan 9000-portda tinglovchi, unga bitta so'z yuboradigan mijoz, hammasi loopback (`lo`) interfeysida. Vazifalarda esa haqiqiy tashqi saytlar va `eth0` bo'ladi. Uchta terminal kerak: biri `docker run ...` (Laboratoriya), qolgan ikkitasi `docker exec -it shoot bash`.

**1-qadam: tinglovchi (terminal 1).** `nc -l 9000` 9000-portda bitta ulanishni kutadi va kelgan baytlarni ekranga chiqaradi:

```
shoot:~# nc -l 9000
```

**2-qadam: ushlash (terminal 2).**

```
shoot:~# tcpdump -i lo -nn 'tcp port 9000'
listening on lo, link-type EN10MB (Ethernet), snapshot length 262144 bytes
```

**3-qadam: mijoz (terminal 3).** `-w 1` bir soniya harakatsizlikdan keyin chiqadi:

```
shoot:~# echo salom | nc -w 1 127.0.0.1 9000
```

Terminal 1 da `salom` paydo bo'ladi. Terminal 2 da (vaqt va `options` qisqartirilgan):

```
IP 127.0.0.1.40822 > 127.0.0.1.9000: Flags [S], seq 3052117760, win 65495, options [mss 65495,...], length 0
IP 127.0.0.1.9000 > 127.0.0.1.40822: Flags [S.], seq 1187204033, ack 3052117761, win 65483, options [mss 65495,...], length 0
IP 127.0.0.1.40822 > 127.0.0.1.9000: Flags [.], ack 1, win 512, length 0
IP 127.0.0.1.40822 > 127.0.0.1.9000: Flags [P.], seq 1:7, ack 1, win 512, length 6
IP 127.0.0.1.9000 > 127.0.0.1.40822: Flags [.], ack 7, win 512, length 0
IP 127.0.0.1.40822 > 127.0.0.1.9000: Flags [F.], seq 7, ack 1, win 512, length 0
IP 127.0.0.1.9000 > 127.0.0.1.40822: Flags [F.], seq 1, ack 8, win 512, length 0
IP 127.0.0.1.40822 > 127.0.0.1.9000: Flags [.], ack 2, win 512, length 0
```

Qatorma-qator:

- 1–3: three-way handshake. Mijoz porti `40822` (kernel tasodifiy tanlagan, sizda boshqa), server porti `9000`. Uchala paketda `length 0`: hali ma'lumot yo'q.
- `mss 65495`: loopback'ning MTU'si 65536 (1-dars), shuning uchun MSS ham katta. `eth0` da bu yerda 1460 ko'rinardi.
- 4: `[P.]`, `seq 1:7`, `length 6`. Olti bayt: `s`, `a`, `l`, `o`, `m` va qator oxiri belgisi.
- 5: server tasdiqladi: `ack 7`, ya'ni "6 baytni oldim, 7-chisini kutyapman".
- 6–8: ulanish yopilishi. Har tomon o'z `FIN` ini yuboradi va narigisi tasdiqlaydi. `FIN` ham bitta tartib raqamini egallaydi, shuning uchun `ack 8` va `ack 2`.

**4-qadam: payload'ni ko'ramiz.** 1 va 3-qadamlarni takrorlang, tcpdump'ni esa `-A -c 4` bilan ishga tushiring. To'rtinchi paket ostida ochiq matn chiqadi:

```
shoot:~# tcpdump -i lo -nn -A -c 4 'tcp port 9000'
...
E..:..@.@.<...............#(....F.....       ....salom
```

Boshidagi tushunarsiz belgilar IP va TCP header baytlari (ular matn emas), oxirida esa L7 ma'lumot. Shifrlash yo'q, shuning uchun yo'ldagi istalgan kuzatuvchi buni o'qiy oladi. TLS aynan shu muammoni hal qiladi.

**5-qadam: L2 ni ko'ramiz.** `-e` bilan takrorlasangiz, MAC o'rnida nollar chiqadi:

```
00:00:00:00:00:00 > 00:00:00:00:00:00, ethertype IPv4 (0x0800), length 74: 127.0.0.1.40830 > 127.0.0.1.9000: Flags [S], ...
```

Loopback'da haqiqiy sim ham, qo'shni ham yo'q, ARP kerak emas. `length 74`: 14 (Ethernet) + 20 (IP) + 40 (TCP header, option'lar bilan) + 0 ma'lumot.

**6-qadam: tinglovchisiz.** Terminal 1 da hech narsa ishlamayotgan paytda mijozni yana ishga tushiring:

```
shoot:~# echo salom | nc -w 1 127.0.0.1 9000
shoot:~# echo $?
1
```

tcpdump'da endi faqat ikki qator: `[S]` va unga javoban `[R.]`. Kernel "bu portda hech kim yo'q" deb `RST` qaytardi. `Connection refused` xatosining paket darajasidagi ko'rinishi shu.

Xulosa: bitta `salom` so'zi uchun 8 paket ketdi, shundan faqat bittasida ma'lumot bor. Qolgani TCP'ning ishonchlilik narxi. Tozalash kerak emas, `nc` va `tcpdump` ni `Ctrl+C` bilan to'xtating.

---

## Vazifalar

Ish papkasi: `network/02-osi-model/` (`make new m=network n=02 name=osi-model`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. Paket ushlash vazifalari Laboratoriya bo'limidagi `shoot` konteynerida, 14 va 15-vazifalar `lab` VM'da bajariladi (VM'da `tcpdump` va `ping` oldiga `sudo` kerak bo'lishi mumkin, interfeys nomini `ip -br addr` dan oling). README boshida qaysi mashinada bajarganingizni yozing.

### A. Model

1. **Layer table.** O'z so'zingiz bilan jadval tuzing: 7 qatlam, har birining bitta gaplik vazifasi, PDU nomi, manzil turi va siz kundalik ishlatgan kamida bitta protokol yoki asbob. Yonida TCP/IP modelining mos qatlamini ko'rsating.
   Yo'nalish: 2 va 3-bo'limlardagi jadvallar; ko'chirmang, o'z so'zingiz bilan.

2. **Classify protocols.** Quyidagilarni qatlamlarga joylang va har biriga bir gap asos yozing: Ethernet, ARP, IPv4, ICMP, TCP, UDP, TLS, DNS, HTTP, SSH, DHCP, Wi-Fi, WebSocket, gRPC, QUIC. Qaysilarini bitta qatlamga joylash qiyin va nima uchun?
   Yo'nalish: 2-bo'lim "qaysi qatlam qayerda yashaydi"; notanish protokol uchun "u nimaning ichida yuradi" deb so'rang.

3. **Classify failures.** Har bir alomat uchun eng ehtimoliy qatlamni va uni tasdiqlaydigan bitta buyruqni yozing: (a) `NO-CARRIER`; (b) `ip neigh` da gateway `FAILED`; (c) `Network is unreachable`; (d) `Connection refused`; (e) `Connection timed out`; (f) `certificate has expired`; (g) `Could not resolve host`; (h) HTTP `502 Bad Gateway`.
   Yo'nalish: 5-bo'limdagi ikki jadval.

4. **Header math.** 1500 baytli MTU'da bitta TCP segmentga necha bayt HTTP ma'lumot sig'ishini IPv4 va IPv6 uchun hisoblang. 1 MB faylni yuborish uchun taxminan nechta segment kerak? WireGuard interfeysida MTU 1420 bo'lsa IPv4 uchun MSS nechaga teng?
   Yo'nalish: 4-bo'lim, header hajmlari jadvali va MSS formulasi.

### B. tcpdump

5. **First capture.** `shoot` konteynerida `tcpdump -i eth0 -nn -c 10` ni ishga tushirib, ikkinchi terminaldan `ping -c 3 1.1.1.1` qiling. Chiqishdan bitta echo request va bitta echo reply qatorini ko'chiring va har bir maydonini izohlang. `-e` qo'shib takrorlang: manzil MAC kimniki?
   Yo'nalish: 7-bo'lim "bitta qatorni o'qish"; MAC egasini `ip route` va `ip neigh` dan toping.

6. **The -n flag.** Xuddi shu ushlashni `-n` siz bajaring. Chiqishda nima o'zgardi va qanday qo'shimcha trafik paydo bo'ldi? Nima uchun tashxis paytida `-n` majburiy deb hisoblanadi?
   Yo'nalish: 7-bo'lim "Nima uchun shunday".

7. **Three-way handshake.** `tcpdump -i eth0 -nn tcp port 80` ishlab turganda `curl -s -o /dev/null http://example.com/` qiling. Chiqishdan handshake'ning uch qatorini, HTTP so'rov qatorini va yopilish (`FIN`) qatorlarini ajrating. Har qatordagi flag belgisini va `length` ni izohlang. Ikki tomon e'lon qilgan `mss` qiymatlarini toping.
   Yo'nalish: "Birga bajaramiz" 3-qadam; farqlarni (MSS, portlar) alohida qayd eting.

8. **Read the payload.** 7-vazifani `-A` bilan takrorlang va HTTP so'rov hamda javob header'larini paket ichida toping. Keyin `tcp port 443` filtri va `curl https://example.com/` bilan takrorlang. Nimani o'qiy olasiz, nimani yo'q? TLS handshake'dagi qaysi ma'lumot ochiq ko'rinadi?
   Yo'nalish: "Birga bajaramiz" 4-qadam; Tuzoqlar'dagi oxirgi band.

9. **DNS on the wire.** `tcpdump -i eth0 -nn udp port 53` ishlab turganda `dig example.com` va `curl -s -o /dev/null http://example.org/` qiling. Har biri uchun nechta so'rov va javob ketdi, qaysi yozuv turlari so'raldi (`A`, `AAAA`), DNS server manzili qanday? `curl` nima uchun ikkita so'rov yubordi?
   Yo'nalish: 6-bo'lim 1-qadam; DNS server manzilini `cat /etc/resolv.conf` bilan solishtiring. Sizda bu manzil Zorin va macOS'da farq qilishi mumkin.

10. **Refused vs timeout.** Uch holatni ushlang va har birida tcpdump chiqishi hamda `curl` yoki `nc` xato matnini yozing: (a) `nc -vz example.com 80`; (b) `nc -vz -w 5 example.com 81`; (c) `nc -vz 127.0.0.1 9999` (`-i lo` da ushlang). Qaysi holatda `[R.]` keldi, qaysi birida `[S]` takrorlandi? Takrorlanishlar orasidagi vaqt qanday o'zgaradi?
    Yo'nalish: 5-bo'lim "to'rt xato" jadvali, "Birga bajaramiz" 6-qadam.

11. **Filters.** Quyidagilarning har biri uchun filtr yozing va ishlashini bitta sinov bilan ko'rsating: (a) faqat `1.1.1.1` bilan trafik; (b) DNS'dan boshqa hamma narsa; (c) faqat SYN flag'i bor paketlar; (d) faqat ICMP va ARP; (e) manba porti 1024 dan katta bo'lgan TCP.
    Yo'nalish: 7-bo'limdagi filtr namunalari va Manbalar'dagi `pcap-filter(7)`.

12. **Write and read pcap.** `tcpdump -i eth0 -nn -w /pcap/http.pcap 'tcp port 80 or udp port 53'` bilan `curl http://example.com/` ni yozib oling. `tcpdump -nn -r /pcap/http.pcap` bilan qayta o'qing, keyin `-r` ga qo'shimcha filtr berib faqat DNS paketlarni chiqaring. Fayl hajmi va paketlar sonini yozing. Fayl host'da qayerda paydo bo'ldi?
    Yo'nalish: 7-bo'lim flag'lar jadvali (`-w`, `-r`); Laboratoriya'dagi bind mount.

### C. Qatlamlar bo'ylab

13. **Wireshark layers.** `http.pcap` ni Wireshark'da oching (o'rnatmagan bo'lsangiz `tcpdump -nn -e -v -X -r` chiqishi bilan bajaring). HTTP GET paketini tanlab, har qatlam header'idan bittadan maydon qiymatini yozing: Ethernet (EtherType), IP (TTL, protocol), TCP (seq, window), HTTP (Host). Frame'ning umumiy uzunligini header hajmlari yig'indisi bilan tekshiring.
    Yo'nalish: 4-bo'lim header jadvali; "Birga bajaramiz" 5-qadamdagi uzunlik hisobi.

14. **TTL on the path.** `lab` VM'da `ping -c 1 -t 1 1.1.1.1`, `-t 2`, `-t 3` ni ketma-ket bajaring va ikkinchi terminalda `sudo tcpdump -i <iface> -nn icmp` da nima kelishini kuzating. Javob beruvchi manzillar kimniki? Bu qaysi asbobning ishlash prinsipi (5-darsda)? Birinchi hop Zorin va macOS'da nima bo'lishini taxmin qiling (1-dars, gateway).
    Yo'nalish: 4-bo'lim, TTL ta'rifi.

15. **Path MTU.** `lab` VM'da `ping -c 2 -M do -s 1472 1.1.1.1` va `-s 1473` natijalarini solishtiring. Xato matnini yozing va 1472 soni qayerdan kelganini hisob bilan ko'rsating. `tracepath 1.1.1.1` chiqishidagi `pmtu` qiymatini toping.
    Yo'nalish: 4-bo'lim "1472 soni qayerdan"; avval `ip link` dan VM interfeysining MTU'sini tekshiring.

16. **curl as a layer probe.** `curl -v https://example.com/` chiqishini bosqichlarga bo'ling va har qator guruhini qatlamga bog'lang: DNS, TCP connect, TLS handshake, HTTP so'rov, HTTP javob. Keyin `curl -s -o /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' https://example.com/` ni ishga tushirib, har bosqich qancha vaqt olganini ayirma bilan hisoblang.
    Yo'nalish: 6-bo'lim "curl -v bosqichlari"; `-w` o'zgaruvchilari yig'ma vaqt beradi, bosqich vaqti qo'shni qiymatlar ayirmasi.

17. **Break each layer.** Bitta `curl` buyrug'ini to'rt xil sindiring va har xato matnini qatlami bilan yozing: (a) mavjud bo'lmagan domen; (b) mavjud host, yopiq port; (c) `curl --connect-timeout 5 http://10.255.255.1/`; (d) `curl https://expired.badssl.com/`. Har biri uchun: xato qaysi bosqichda chiqdi, `curl` exit code'i (`echo $?`) va undan oldingi qaysi qatlamlar ishlagani.
    Yo'nalish: 5-bo'lim jadvallari; exit code ma'nolari `man curl` ning "EXIT CODES" bo'limida.

### D. Yig'ish

18. **Request journey.** `curl http://example.com/` ning to'liq yo'lini o'z konteyneringiz misolida, haqiqiy qiymatlar bilan yozing: konteyner IP va MAC'i, gateway IP va MAC'i (`ip route`, `ip neigh`), DNS server, manba va manzil portlari, pcap'dagi mos paket raqamlari. Har qadamda qaysi qatlam ishlayotganini ko'rsating. Konteynerdan keyingi yo'l Zorin va macOS'da nimasi bilan farq qilishini bir-ikki gap bilan qo'shing.
    Yo'nalish: 6-bo'lim "Mexanizm" dagi 8 qadam, Laboratoriya'dagi mashinalar jadvali.

19. **Runbook.** "Foydalanuvchi `https://app.example.com` ochilmayapti deydi" holati uchun pastdan yuqoriga 8–10 qadamli runbook yozing. Har qadam: buyruq, kutilgan natija, natija boshqacha bo'lsa xulosa va keyingi harakat. Faqat mijoz tomonidan tekshirish mumkin deb hisoblang.
    Yo'nalish: 5-bo'lim "Tashxis tartibi"; 17-vazifadagi xatolarni tarmoqlanish nuqtalari sifatida ishlating.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 19 ta vazifaning hammasi `## N. Title` sarlavhasi bilan bor, boshida qaysi mashinada bajarilgani yozilgan.
2. `make check` toza.
3. `pcap/` papkasi `.gitignore` da, `.pcap` fayllar commit qilinmagan.
4. `shoot` konteyneri to'xtatilgan (`docker ps` da yo'q).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Nima uchun tarmoq qatlamlarga bo'lingan? Wi-Fi'dan simga o'tganda qaysi qatlamlar o'zgaradi, qaysilari o'zgarmaydi?
- Frame, packet va segment farqi nima? Har biri qaysi manzil turidan foydalanadi?
- Paket uchta router'dan o'tdi. MAC manzillar, IP manzillar, TTL va portlar bilan nima bo'ldi?
- MSS 1460 qayerdan keladi? MTU kichrayganda nima o'zgaradi?
- `Connection refused` va `Connection timed out` paket darajasida nimasi bilan farq qiladi va har biri tashxisni qayerga yo'naltiradi?
- `[S]`, `[S.]`, `[.]`, `[P.]`, `[F.]`, `[R.]` belgilari nimani anglatadi?
- Nima uchun `tcpdump` HTTPS so'rov mazmunini o'qiy olmaydi, lekin qaysi serverga ketayotganini ko'rsata oladi?
- L4 va L7 load balancer farqi nima? Qaysi biri URL yo'liga qarab qaror qila oladi?
- Nima uchun TTL va path MTU vazifalari macOS'da konteynerda emas, `lab` VM'da bajariladi?
