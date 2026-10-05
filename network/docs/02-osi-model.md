# 2-dars: OSI modeli

Maqsad: tarmoqni qatlamlarga bo'lib fikrlashni o'rganish. Kurs roadmap'ida mavzu "OCI modeli" deb yozilgan, bu OSI (Open Systems Interconnection) modeli. OSI 7 qatlami va amalda ishlatiladigan TCP/IP 4 qatlami, encapsulation (har qatlam o'z header'ini qo'shishi), qaysi asbob va qaysi nosozlik qaysi qatlamga tegishli ekani, bitta HTTP so'rovning qatlamlar bo'ylab to'liq yo'li, `tcpdump` va Wireshark bilan paketlarni o'qish. Model o'zi yodlash uchun emas, tashxis uchun kerak: "ishlamayapti" degan shikoyatni "qaysi qatlamda ishlamayapti" savoliga aylantiradi. 1-darsdagi frame va ARP bu modelning 2-qatlami, 3-darsdagi IP 3-qatlam, 4-darsdagi TCP, DNS, HTTP 4 va 7-qatlamlar.

Taxminiy vaqt: 2 kun (siz uchun). HTTP va TLS tanish, diqqatni quyidagilarga qarating: har qatlamning PDU nomi va manzil turi, encapsulation'da header hajmlari (MTU va MSS qayerdan chiqadi), pastdan yuqoriga tashxis tartibi, `tcpdump` filtrlari va chiqishidagi TCP flag belgilari, "L4 va L7 load balancer" kabi iboralarning ma'nosi.

## Laboratoriya

- **Ish mashinasi**: `curl -v`, `dig`, `ping`, `ip route get` (faqat o'qish).
- **Docker**: paket ushlash uchun `nicolaka/netshoot` konteyneri. Konteyner ichida siz root, `tcpdump` hostga `sudo` siz ishlaydi va faqat konteynerning o'z trafigini ko'radi:

```
mkdir -p network/02-osi-model/pcap
docker run --rm -it --name shoot --cap-add NET_ADMIN \
  -v "$PWD/network/02-osi-model/pcap:/pcap" nicolaka/netshoot
```

Ikkinchi terminal: `docker exec -it shoot bash`. Bir terminalda `tcpdump`, ikkinchisida so'rov yuboriladi. `/pcap` ga yozilgan fayllar hostda qoladi.

- **Wireshark (ixtiyoriy)**: `.pcap` faylni grafik ko'rish uchun. O'rnatish: `sudo apt install wireshark` (https://www.wireshark.org/docs/). Faqat fayl ochish uchun ishlatiladi, shuning uchun o'rnatishdagi "non-superusers capture" savoliga "No" yetarli.
- **Tozalash**: konteynerdan `exit` (`--rm` uni o'chiradi). `pcap/*.pcap` fayllarini commit qilmang (ichida real trafik bor), `.gitignore` ga qo'shing.

---

## 1. Nima uchun qatlamlar

Tarmoq dasturiy ta'minoti qatlamlarga bo'lingan, har qatlam bitta vazifani hal qiladi va faqat qo'shni qatlam bilan gaplashadi. Natija: HTTP Wi-Fi yoki optik tola ustida ekanini bilmaydi, Ethernet esa ichida HTTP yoki SSH borligini bilmaydi. Bu frontend'dagi abstraksiya qatlamlariga o'xshaydi: komponent `fetch` ni chaqiradi, `fetch` ostida nima borligi uni qiziqtirmaydi.

Muhandis uchun foyda ikki xil:

1. **Tashxis**: har qatlamni alohida tekshirish mumkin. 3-qatlam ishlayotgani isbotlansa (`ping` o'tdi), 1–2-qatlamlarni tekshirishga hojat yo'q.
2. **Umumiy til**: "L4 load balancer", "L7 firewall", "L2 segment", "L3 switch" iboralari aynan shu raqamlarga ishora qiladi.

## 2. OSI 7 qatlami

| # | Qatlam | Vazifa | PDU | Manzil | Misollar |
|---|--------|--------|-----|--------|----------|
| 7 | Application | ilova protokoli | data | URL, email manzil | HTTP, DNS, SSH, SMTP |
| 6 | Presentation | kodlash, shifrlash, siqish | data | | TLS (shartli), UTF-8, gzip |
| 5 | Session | sessiyani ochish, saqlash, yopish | data | | TLS session, RPC |
| 4 | Transport | jarayondan jarayonga yetkazish, ishonchlilik | segment (TCP), datagram (UDP) | port | TCP, UDP, QUIC |
| 3 | Network | hostdan hostga, tarmoqlar orasida yo'l tanlash | packet | IP manzil | IPv4, IPv6, ICMP |
| 2 | Data Link | bitta LAN ichida qo'shnidan qo'shniga | frame | MAC manzil | Ethernet, Wi-Fi (802.11), ARP |
| 1 | Physical | bitlarni signalga aylantirish | bit | | mis kabel, optika, radio |

Eslab qolish uchun inglizcha ibora (1 dan 7 ga): "Please Do Not Throw Sausage Pizza Away".

**Tuzoq: 5 va 6-qatlamlarni real protokollarga majburlab joylash.** OSI nazariy model, internet esa TCP/IP modeli bo'yicha qurilgan. TLS ni "5 yoki 6-qatlam" deb bahslashish foydasiz. Amalda 1, 2, 3, 4 va 7 raqamlari ishlatiladi, 5–6 deyarli tilga olinmaydi.

## 3. TCP/IP modeli va moslik

| TCP/IP qatlami | OSI qatlamlari | Protokollar | Linux'da qayerda |
|----------------|----------------|-------------|------------------|
| Application | 5, 6, 7 | HTTP, DNS, SSH, TLS, SMTP | user space: nginx, curl, brauzer |
| Transport | 4 | TCP, UDP | kernel, socket API |
| Internet | 3 | IP, ICMP | kernel, routing table |
| Link | 1, 2 | Ethernet, Wi-Fi, ARP | kernel driver, NIC |

Chegara muhim: transport va undan past qatlamlar **kernel** da, ilova qatlami **user space** da. Ilova `socket()` ochadi va bayt oqimi yozadi, segmentlarga bo'lish, qayta yuborish, routing, frame yasash kernel ishi. `tcpdump` kernel'dan frame'larning nusxasini oladi, shuning uchun u ilova hech narsa log qilmasa ham haqiqatni ko'rsatadi.

## 4. Encapsulation

Yuborishda har qatlam yuqoridan kelgan ma'lumotga o'z header'ini qo'shadi, qabul qilishda teskari tartibda yechadi:

```
[ HTTP request                                   ]   L7 data
[ TCP hdr | HTTP request                         ]   L4 segment
[ IP hdr | TCP hdr | HTTP request                ]   L3 packet
[ Eth hdr | IP hdr | TCP hdr | HTTP request | FCS ]  L2 frame
```

| Header | Minimal hajm | Asosiy maydonlar |
|--------|--------------|------------------|
| Ethernet | 14 bayt (+4 FCS) | dst MAC, src MAC, EtherType |
| IPv4 | 20 bayt | src IP, dst IP, TTL, protocol (6 TCP, 17 UDP, 1 ICMP), flags (DF) |
| IPv6 | 40 bayt | src IP, dst IP, hop limit, next header |
| TCP | 20 bayt | src port, dst port, seq, ack, flags, window |
| UDP | 8 bayt | src port, dst port, length, checksum |

Bundan ikki amaliy son chiqadi:

- **MTU 1500**: frame payload'i, ya'ni butun IP paket (header bilan) shu hajmga sig'ishi kerak.
- **MSS (Maximum Segment Size) 1460**: bitta TCP segmentdagi ma'lumot hajmi. `1500 - 20 (IP) - 20 (TCP) = 1460`. Tomonlar MSS'ni handshake'da e'lon qiladi.

Yo'l davomida nima o'zgaradi:

| Qatlam | Har hop'da | Butun yo'l davomida |
|--------|-----------|---------------------|
| L2 frame | qaytadan yasaladi, MAC'lar o'zgaradi | |
| L3 packet | TTL bittaga kamayadi | src va dst IP saqlanadi (NAT bo'lmasa) |
| L4 segment | tegilmaydi | portlar saqlanadi (NAT bo'lmasa) |
| L7 data | tegilmaydi (proxy bo'lmasa) | |

### MTU, fragmentatsiya va PMTUD

Paket keyingi kanalning MTU'sidan katta bo'lsa, IPv4 router uni bo'laklaydi (fragmentation), agar header'da **DF (Don't Fragment)** biti qo'yilmagan bo'lsa. Zamonaviy TCP DF'ni doim qo'yadi. U holda router paketni tashlab, yuboruvchiga ICMP "Fragmentation needed" (type 3, code 4) xabarini keyingi hop MTU'si bilan qaytaradi va yuboruvchi segment hajmini kamaytiradi. Bu **Path MTU Discovery**.

**Tuzoq: ICMP'ni to'liq bloklash PMTUD'ni buzadi.** Firewall barcha ICMP'ni tashlasa, "Fragmentation needed" yetib kelmaydi. Belgisi: TCP ulanish o'rnatiladi, kichik javoblar keladi, katta javob (yoki TLS sertifikati) kelganda ulanish osilib qoladi. VPN va tunnel ortida tez-tez uchraydi. Tekshirish: `ping -M do -s 1472 <host>` (1472 + 8 ICMP + 20 IP = 1500).

## 5. Qaysi asbob, qaysi muammo qaysi qatlamda

| Qatlam | Savol | Asbob | Tipik nosozlik |
|--------|-------|-------|----------------|
| 1 Physical | link bormi? | `ip link` (`LOWER_UP`), `ethtool` | kabel uzilgan, Wi-Fi signali yo'q, `NO-CARRIER` |
| 2 Data Link | qo'shni MAC'i ma'lummi? | `ip neigh`, `bridge fdb`, `tcpdump -e arp` | `FAILED` neighbour, IP ziddiyati, noto'g'ri VLAN |
| 3 Network | IP bor va yo'l bormi? | `ip addr`, `ip route get`, `ping`, `mtr` | IP yo'q, noto'g'ri mask, route yo'q, `Network is unreachable`, `No route to host` |
| 4 Transport | port ochiqmi? | `ss -tlnp`, `nc -vz`, `tcpdump` | `Connection refused` (hech kim tinglamayapti), `Connection timed out` (firewall tashlayapti) |
| 5–6 | TLS o'rnatiladimi? | `openssl s_client`, `curl -v` | sertifikat muddati, hostname mos emas, protokol versiyasi |
| 7 Application | ilova to'g'ri javob beradimi? | `curl -v`, `dig`, ilova log'lari | 502, 503, noto'g'ri `Host` header, DNS `NXDOMAIN` |

DNS alohida eslatma: u 7-qatlam protokoli, lekin deyarli har ulanishdan **oldin** bajariladi. Shuning uchun tashxisda u ko'pincha IP tekshiruvidan keyin, port tekshiruvidan oldin turadi: avval IP bilan sinab ko'riladi, keyin nom bilan.

### Tashxis tartibi

Pastdan yuqoriga, har qadamda bitta savol:

```
ip -br link                 # L1-2: is the interface up, carrier present?
ip -br addr                 # L3: do I have an address?
ip route get 203.0.113.10   # L3: which route and source address would be used?
ping -c 3 203.0.113.10      # L3: is the host reachable? (ICMP may be filtered)
nc -vz 203.0.113.10 443     # L4: does the port accept connections?
dig +short app.example.com  # L7 (DNS): does the name resolve to that address?
curl -v https://app.example.com/health   # L5-7: TLS and application
```

Tajribali muhandis ko'pincha yuqoridan boshlaydi (`curl -v`), chunki bitta buyruq DNS, TCP, TLS va HTTP bosqichlarini ko'rsatadi va qayerda to'xtaganiga qarab pastga tushadi. Ikkala yo'nalish ham to'g'ri, muhimi qatlamlarni sakrab o'tmaslik.

**Tuzoq: `ping` o'tmadi demak host o'chiq emas.** Ko'p firewall va cloud security group ICMP echo'ni bloklaydi. `ping` o'tsa 3-qatlam ishlaydi, o'tmasa bu hech narsani isbotlamaydi: `nc -vz host port` bilan 4-qatlamni tekshiring.

### L4 va L7 qurilmalar

| Atama | Nimaga qaraydi | Nima qila oladi |
|-------|----------------|-----------------|
| L2 switch | MAC | bitta LAN ichida uzatish |
| L3 router | IP | tarmoqlar orasida uzatish |
| L4 load balancer, L4 firewall | IP + port | ulanishni backend'ga taqsimlash, port bo'yicha filtrlash; HTTP mazmunini ko'rmaydi |
| L7 load balancer, reverse proxy, WAF | HTTP: host, path, header | path bo'yicha routing, TLS termination, so'rov mazmuniga qarab bloklash |

Cloud'da bu to'g'ridan-to'g'ri mahsulot tanlovi: AWS NLB bu L4, ALB bu L7. Kubernetes'da Service L4, Ingress L7.

## 6. Bitta HTTP so'rovning yo'li

`curl http://example.com/` bajarilganda:

1. **L7, DNS**: `example.com` IP'ga aylantiriladi. Bu o'zi alohida to'liq sayohat: UDP 53-port orqali resolver'ga so'rov (4-darsda).
2. **L4, TCP handshake**: kernel tasodifiy manba port tanlaydi (masalan 51734) va `SYN` yuboradi. `SYN`, `SYN-ACK`, `ACK` dan keyin ulanish ochiq.
3. **L3, routing**: har paket uchun kernel routing table'dan chiqish interfeysi va keyingi hop'ni topadi. Manzil boshqa tarmoqda, demak keyingi hop default gateway.
4. **L2, ARP va frame**: gateway MAC'i neighbour table'dan olinadi (bo'lmasa ARP), frame yasaladi: dst MAC gateway'niki, dst IP serverniki.
5. **L1**: frame signalga aylanib kabel yoki radioga chiqadi.
6. **Yo'lda**: har router frame'ni yechadi, IP header'ga qaraydi, TTL'ni kamaytiradi, yangi frame yasab keyingi hop'ga yuboradi. Uy routeri manba IP'ni o'z public IP'siga almashtiradi (NAT, 6-darsda).
7. **Serverda**: teskari tartib. NIC frame'ni oladi, kernel IP va TCP header'larni yechib, 80-portni tinglayotgan jarayon socket'iga baytlarni beradi. nginx faqat `GET / HTTP/1.1 ...` matnini ko'radi.
8. **Javob** xuddi shu yo'lni teskari bosib o'tadi, oxirida `FIN` lar bilan ulanish yopiladi.

HTTPS bo'lsa 2 va 7-qadamlar orasida TLS handshake qo'shiladi va HTTP baytlari shifrlangan holda TCP ichida ketadi. `tcpdump` unda faqat header'larni o'qiy oladi, mazmunni emas.

## 7. tcpdump va Wireshark asoslari

`tcpdump` interfeysdan o'tayotgan frame'larni ushlaydi. Asosiy flag'lar:

| Flag | Vazifa |
|------|--------|
| `-i eth0`, `-i any` | interfeys |
| `-n` | IP'larni nomga aylantirmaslik; `-nn` portlarni ham |
| `-e` | Ethernet header'ni (MAC, EtherType) ko'rsatish |
| `-c 20` | 20 paketdan keyin to'xtash |
| `-v`, `-vv` | batafsil (TTL, flags, checksum) |
| `-A` | payload'ni ASCII ko'rinishda |
| `-X` | payload'ni hex va ASCII ko'rinishda |
| `-w file.pcap` | faylga yozish (Wireshark uchun) |
| `-r file.pcap` | fayldan o'qish |

**Tuzoq: `-n` siz tcpdump har IP uchun reverse DNS so'rov yuboradi.** Chiqish sekinlashadi va ushlangan trafikka o'zining DNS so'rovlari aralashadi. Doim `-n` yoki `-nn` yozing.

Filtr (pcap-filter sintaksisi) buyruq oxirida:

```
tcpdump -i eth0 -nn host 93.184.215.14
tcpdump -i eth0 -nn tcp port 80
tcpdump -i eth0 -nn udp port 53
tcpdump -i eth0 -nn 'icmp or arp'
tcpdump -i eth0 -nn 'src net 172.17.0.0/16 and not port 22'
tcpdump -i eth0 -nn 'tcp[tcpflags] & (tcp-syn|tcp-rst) != 0'
```

Chiqish qatorini o'qish:

```
14:02:11.120 IP 172.17.0.2.51734 > 93.184.215.14.80: Flags [S], seq 311, win 64240, options [mss 1460,...], length 0
14:02:11.250 IP 93.184.215.14.80 > 172.17.0.2.51734: Flags [S.], seq 877, ack 312, win 65535, options [mss 1460,...], length 0
14:02:11.250 IP 172.17.0.2.51734 > 93.184.215.14.80: Flags [.], ack 1, win 502, length 0
14:02:11.251 IP 172.17.0.2.51734 > 93.184.215.14.80: Flags [P.], seq 1:75, ack 1, win 502, length 74: HTTP: GET / HTTP/1.1
```

Format: vaqt, protokol, `manba.port > manzil.port`, flag'lar, `length` (TCP payload hajmi).

| Belgi | Flag | Ma'nosi |
|-------|------|---------|
| `[S]` | SYN | ulanish ochish so'rovi |
| `[S.]` | SYN + ACK | qabul qilindi |
| `[.]` | ACK | tasdiq |
| `[P.]` | PSH + ACK | ma'lumot bor |
| `[F.]` | FIN + ACK | yopish |
| `[R]`, `[R.]` | RST | ulanish rad etildi yoki uzildi |

Tashxis namunalari: faqat `[S]` lar takrorlanib, javob yo'q bo'lsa paket yo'lda tashlanmoqda (firewall, route). `[S]` ga `[R.]` kelsa host bor, lekin portni hech kim tinglamayapti.

Wireshark xuddi shu ma'lumotni qatlamlarga ajratib ko'rsatadi: o'rta panelda Frame, Ethernet II, Internet Protocol, Transmission Control Protocol, Hypertext Transfer Protocol bo'limlari encapsulation'ning aynan o'zi. Foydali display filtrlar: `http`, `dns`, `tcp.port == 80`, `ip.addr == 1.2.3.4`, `tcp.flags.syn == 1`. "Follow, TCP Stream" butun suhbatni yig'ib beradi. Production'da odatda serverda `tcpdump -w` bilan yozib, faylni ish mashinasida Wireshark'da ochiladi.

## Tuzoqlar

- Tashxisni qatlamlarni sakrab boshlash: ilova konfiguratsiyasini soatlab o'zgartirish, vaholanki port firewall'da yopiq.
- `ping` natijasiga ortiqcha ishonish: ICMP bloklangan bo'lishi mumkin, o'tgani esa port ochiqligini bildirmaydi.
- `Connection refused` va `Connection timed out` ni bir xil deb o'qish. Birinchisi host yetib bo'ladi, port yopiq; ikkinchisi paket yo'qolmoqda. Tuzatish joyi butunlay boshqa.
- Barcha ICMP'ni "xavfsizlik uchun" bloklash: PMTUD buziladi, katta paketlar osilib qoladi.
- Production serverda filtrsiz `tcpdump -w`: disk bir necha daqiqada to'ladi. Doim filtr va `-c` yoki hajm cheklovi bilan.
- pcap faylni commit qilish yoki chatga tashlash: ichida cookie, token, parol bo'lishi mumkin.
- `tcpdump` ko'rsatgan paketni "yetib bordi" deb hisoblash. Chiquvchi paket firewall'dan keyin, kiruvchi paket firewall'dan oldin ushlanadi: kiruvchi paket tcpdump'da ko'rinib, keyin `nft` qoidasi bilan tashlanishi mumkin.
- L4 load balancer'dan HTTP header yoki path bo'yicha routing kutish.

## Manbalar

- https://www.cloudflare.com/learning/ddos/glossary/open-systems-interconnection-model-osi/ – OSI modeli sharhi
- https://www.rfc-editor.org/rfc/rfc1122 – internet hostlari uchun talablar, TCP/IP qatlamlari
- https://www.tcpdump.org/manpages/tcpdump.1.html – `tcpdump` man sahifasi
- https://www.tcpdump.org/manpages/pcap-filter.7.html – filtr sintaksisi
- https://www.wireshark.org/docs/wsug_html_chunked/ – Wireshark User's Guide
- https://github.com/nicolaka/netshoot – netshoot konteyneri va undagi asboblar
- https://jvns.ca/blog/2016/03/16/tcpdump-is-amazing/ – tcpdump'ga amaliy kirish
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 1.5-bo'lim (protocol layers, encapsulation)

---

## Vazifalar

Ish papkasi: `network/02-osi-model/` (`make new m=network n=02 name=osi-model`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. Paket ushlash vazifalari Laboratoriya bo'limidagi `shoot` konteynerida. Birinchi ishingiz: papkaga `pcap/` ni e'tiborsiz qoldiradigan `.gitignore` qo'shish.

### A. Model

1. **Layer table.** O'z so'zingiz bilan jadval tuzing: 7 qatlam, har birining bitta gaplik vazifasi, PDU nomi, manzil turi va siz kundalik ishlatgan kamida bitta protokol yoki asbob. Yonida TCP/IP modelining mos qatlamini ko'rsating.

2. **Classify protocols.** Quyidagilarni qatlamlarga joylang va har biriga bir gap asos yozing: Ethernet, ARP, IPv4, ICMP, TCP, UDP, TLS, DNS, HTTP, SSH, DHCP, Wi-Fi, WebSocket, gRPC, QUIC. Qaysilarini bitta qatlamga joylash qiyin va nima uchun?

3. **Classify failures.** Har bir alomat uchun eng ehtimoliy qatlamni va uni tasdiqlaydigan bitta buyruqni yozing: (a) `NO-CARRIER`; (b) `ip neigh` da gateway `FAILED`; (c) `Network is unreachable`; (d) `Connection refused`; (e) `Connection timed out`; (f) `certificate has expired`; (g) `Could not resolve host`; (h) `502 Bad Gateway`.

4. **Header math.** 1500 baytli MTU'da bitta TCP segmentga necha bayt HTTP ma'lumot sig'ishini IPv4 va IPv6 uchun hisoblang. 1 MB faylni yuborish uchun taxminan nechta segment kerak? WireGuard interfeysida MTU 1420 bo'lsa IPv4 uchun MSS nechaga teng?

### B. tcpdump

5. **First capture.** `shoot` konteynerida `tcpdump -i eth0 -nn -c 10` ni ishga tushirib, ikkinchi terminaldan `ping -c 3 1.1.1.1` qiling. Chiqishdan bitta echo request va bitta echo reply qatorini ko'chiring va har bir maydonini izohlang. `-e` qo'shib takrorlang: manzil MAC kimniki?

6. **The -n flag.** Xuddi shu ushlashni `-n` siz bajaring. Chiqishda nima o'zgardi va qanday qo'shimcha trafik paydo bo'ldi? Nima uchun tashxis paytida `-n` majburiy deb hisoblanadi?

7. **Three-way handshake.** `tcpdump -i eth0 -nn tcp port 80` ishlab turganda `curl -s -o /dev/null http://example.com/` qiling. Chiqishdan handshake'ning uch qatorini, HTTP so'rov qatorini va yopilish (`FIN`) qatorlarini ajrating. Har qatordagi flag belgisini va `length` ni izohlang. Ikki tomon e'lon qilgan `mss` qiymatlari nechchi?

8. **Read the payload.** 7-vazifani `-A` bilan takrorlang va HTTP so'rov hamda javob header'larini paket ichida toping. Keyin `tcp port 443` filtri va `curl https://example.com/` bilan takrorlang. Nimani o'qiy olasiz, nimani yo'q? TLS handshake'dagi qaysi ma'lumot ochiq ko'rinadi?

9. **DNS on the wire.** `tcpdump -i eth0 -nn udp port 53` ishlab turganda `dig example.com` va `curl -s -o /dev/null http://example.org/` qiling. Har biri uchun nechta so'rov va javob ketdi, qaysi yozuv turlari so'raldi (`A`, `AAAA`), DNS server manzili qanday? `curl` nima uchun ikkita so'rov yubordi?

10. **Refused vs timeout.** Uch holatni ushlang va har birida tcpdump chiqishi hamda `curl` yoki `nc` xato matnini yozing: (a) `nc -vz example.com 80`; (b) `nc -vz -w 5 example.com 81`; (c) `nc -vz 127.0.0.1 9999` (`-i lo` da ushlang). Qaysi holatda `[R.]` keldi, qaysi birida `[S]` takrorlandi? Takrorlanishlar orasidagi vaqt qanday o'zgaradi?

11. **Filters.** Quyidagilarning har biri uchun filtr yozing va ishlashini bitta sinov bilan ko'rsating: (a) faqat `1.1.1.1` bilan trafik; (b) DNS'dan boshqa hamma narsa; (c) faqat SYN flag'i bor paketlar; (d) faqat ICMP va ARP; (e) manba porti 1024 dan katta bo'lgan TCP.

12. **Write and read pcap.** `tcpdump -i eth0 -nn -w /pcap/http.pcap 'tcp port 80 or udp port 53'` bilan `curl http://example.com/` ni yozib oling. `tcpdump -nn -r /pcap/http.pcap` bilan qayta o'qing, keyin `-r` ga qo'shimcha filtr berib faqat DNS paketlarni chiqaring. Fayl hajmi va paketlar sonini yozing.

### C. Qatlamlar bo'ylab

13. **Wireshark layers.** `http.pcap` ni Wireshark'da oching (o'rnatmagan bo'lsangiz `tcpdump -nn -e -v -X -r` chiqishi bilan bajaring). HTTP GET paketini tanlab, har qatlam header'idan bittadan maydon qiymatini yozing: Ethernet (EtherType), IP (TTL, protocol), TCP (seq, window), HTTP (Host). Frame'ning umumiy hajmi va har header hajmini qo'shib chiqing.

14. **TTL on the path.** `ping -c 1 -t 1 1.1.1.1`, `-t 2`, `-t 3` ni ketma-ket bajaring va `tcpdump -nn icmp` da nima kelishini kuzating. Javob beruvchi manzillar kimniki? Bu qaysi asbobning ishlash prinsipi (5-darsda)?

15. **Path MTU.** `ping -c 2 -M do -s 1472 1.1.1.1` va `-s 1473` natijalarini solishtiring. Xato matnini yozing va 1472 soni qayerdan kelganini hisob bilan ko'rsating. `tracepath 1.1.1.1` chiqishidagi `pmtu` qiymatini toping.

16. **curl as a layer probe.** `curl -v https://example.com/` chiqishini bosqichlarga bo'ling va har qator guruhini qatlamga bog'lang: DNS, TCP connect, TLS handshake, HTTP so'rov, HTTP javob. Keyin `curl -s -o /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' https://example.com/` natijasidan har bosqich qancha vaqt olganini hisoblang.

17. **Break each layer.** Bitta `curl` buyrug'ini to'rt xil sindiring va har xato matnini qatlami bilan yozing: (a) mavjud bo'lmagan domen; (b) mavjud host, yopiq port; (c) `curl --connect-timeout 5 http://10.255.255.1/`; (d) `curl https://expired.badssl.com/`. Har biri uchun: xato qaysi bosqichda chiqdi va undan pastdagi qaysi qatlamlar ishlagani isbotlandi?

### D. Yig'ish

18. **Request journey.** `curl http://example.com/` ning to'liq yo'lini o'z konteyneringiz misolida, haqiqiy qiymatlar bilan yozing: konteyner IP va MAC'i, gateway IP va MAC'i (`ip route`, `ip neigh`), DNS server, manba va manzil portlari, pcap'dagi mos paket raqamlari. Har qadamda qaysi qatlam ishlayotganini ko'rsating. Paket konteynerdan chiqqandan keyin manba IP qayerda o'zgarishini taxmin qiling (tasdig'i 6-darsda).

19. **Runbook.** "Foydalanuvchi `https://app.example.com` ochilmayapti deydi" holati uchun pastdan yuqoriga 8–10 qadamli runbook yozing. Har qadam: buyruq, kutilgan natija, natija boshqacha bo'lsa xulosa va keyingi harakat. Faqat mijoz tomonidan tekshirish mumkin deb hisoblang.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 19 ta vazifaning hammasi `## N. Title` sarlavhasi bilan bor.
2. `pcap/` papkasi `.gitignore` da, `git status` da pcap fayllar ko'rinmaydi.
3. `make check` toza.
4. `shoot` konteyneri to'xtatilgan (`docker ps` da yo'q).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Har qatlamning PDU nomi va manzil turi nima (2, 3, 4-qatlamlar)?
- Paket uchta router orqali o'tdi. Qaysi header'lar necha marta qayta yozildi, qaysilari o'zgarmadi?
- MSS 1460 qayerdan chiqadi? MTU kichraysa nima bo'ladi?
- `Connection refused` va `Connection timed out` paket darajasida nimasi bilan farq qiladi?
- Nima uchun `ping` o'tmasligi host o'chiqligini isbotlamaydi?
- Barcha ICMP bloklansa qaysi mexanizm buziladi va foydalanuvchi buni qanday ko'radi?
- L4 va L7 load balancer farqi nima, har biri nimani ko'ra oladi?
- `tcpdump` HTTPS trafikda nimani ko'rsata oladi, nimani yo'q?
- Kernel va user space chegarasi TCP/IP modelining qaysi qatlamlari orasidan o'tadi?
