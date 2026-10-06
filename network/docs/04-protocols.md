# 4-dars: Protokollar

Maqsad: DevOps har kuni duch keladigan protokollarni noldan, mexanizm darajasida tushunish. Protokol bu ikki dastur bir-birini tushunishi uchun kelishilgan qoidalar to'plami: kim birinchi gapiradi, xabar qanday shaklda, xato qanday bildiriladi. Transport qatlami: TCP (handshake, portlar, holatlar, retransmission) va UDP. Ilova qatlami: DNS (yozuv turlari, resolution yo'li, Linux'da resolver sozlamalari), SSH (kalitlar, mijoz konfiguratsiyasi, port forwarding, `sshd` ni qattiqlashtirish), SMTP (pochta yo'li, MX, SPF, DKIM, DMARC), HTTP va TLS (qisqa, chunki HTTP'ning mijoz tomoni sizga frontend'dan tanish). 2-darsda bu protokollar qatlamlarga joylashtirilgan edi, endi har birining ichiga kiramiz. Deploy muammolarining katta qismi shu yerda: "port band", "DNS hali yangilanmadi", "SSH kalit qabul qilinmadi", "xatlar spam'ga tushyapti", "sertifikat muddati o'tgan". 6-darsdagi firewall qoidalari port va TCP holatlari tilida yoziladi.

Taxminiy vaqt: 8 kun (siz uchun). 1-kun 1–2 bo'limlar (TCP, UDP) va 1–3 vazifalar. 2-kun 4–6 vazifalar. 3-kun 3-bo'lim (DNS) va 7–9 vazifalar. 4-kun 10–12 vazifalar. 5-kun 4-bo'lim (SSH) va 13–15 vazifalar. 6-kun 16–18 vazifalar. 7-kun 5–6 bo'limlar (SMTP, HTTP, TLS), "Birga bajaramiz" va 19–21 vazifalar. 8-kun 22-vazifa va README. HTTP semantikasini (metodlar, status kodlar, header'lar) takrorlamaymiz, diqqat ostidagi qatlamlarga: ulanish, TLS handshake, sertifikat zanjiri.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi qatorma-qator izoh bilan solishtiring. Sizdagi IP, port, PID va vaqtlar farq qiladi, bunday joylar `<...>` bilan belgilangan. Brauzer sizdan shu darsdagi hamma narsani yashirgan: `fetch()` chaqirganingizda DNS so'rovi, TCP handshake va TLS handshake siz ko'rmagan holda bajarilgan. Bu darsda ularni birma-bir qo'lda bajarasiz.

## Laboratoriya

`SETUP.md` bo'yicha yaratilgan `lab` VM kerak. Bu dars qo'shimcha ikkita VM yaratadi: `net1` va `net2` (Ubuntu 24.04). Ular 6-darsda ham ishlatiladi (5-dars faqat `lab` VM ichidagi namespace'larda o'tadi), dars oxirida o'chirmang. Host'da (ikkala mashinada bir xil):

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass launch 24.04 --name net2 --cpus 1 --memory 1G --disk 5G
multipass list        # note the IPv4 of each VM
```

`multipass list` dagi `IPv4` ustuni har VM manzilini beradi. Subnet va interfeys nomi host'ga bog'liq: Zorin'da odatda `10.x.x.x`, macOS'da odatda `192.168.x.x`. Darsda ular `<net1 IP>`, `<net2 IP>` deb yoziladi, o'zingiznikini `multipass list` va VM ichida `ip -br addr` bilan toping.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `multipass`, `docker`, SSH mijozi (`ssh`, `ssh-keygen`, `~/.ssh/config`), `make` |
| `lab` VM | `ubuntu@lab:~$` | bitta mashina yetadigan hamma narsa: `ss`, `dig`, `resolvectl`, `openssl`, `curl -v`, `probe.sh` sinovi |
| `net1`, `net2` VM | `ubuntu@net1:~$` | ikki mashina kerak bo'lgan tajribalar: `nc`, `tcpdump`, `sshd`, `/etc/hosts` |
| Konteyner | host'da `docker run` | Mailpit (xatlarni hech qayerga yubormaydigan test SMTP server) |

- **VM**: `ss`, `ip`, `tcpdump`, `resolvectl`, `sshd_config` o'zgarishlari faqat VM ichida. `tcpdump` yoki `dig` topilmasa VM ichida `sudo apt install tcpdump bind9-dnsutils`.
- **SSH mijoz tomoni host'da**: alohida laboratoriya kaliti (`~/.ssh/lab_ed25519`) va `~/.ssh/config` ga `Host net1`, `Host net2` yozuvlari. Bu ikkala host'da bir xil ishlaydi (OpenSSH mijozi Zorin'da ham, macOS'da ham bor). Mavjud kalit va yozuvlaringizga tegmang.
- `multipass shell` ham ichkarida SSH orqali (`ubuntu` foydalanuvchisi, Multipass'ning o'z kaliti) ulanadi. `sshd` yoki `~/.ssh` ni buzadigan vazifalarda ochiq sessiyani yopmang, undan qaytarasiz. Butunlay qulflanib qolsangiz VM'ni o'chirib qayta yarating (`multipass delete net1 && multipass purge`, keyin `launch`): laboratoriyaning afzalligi shu.
- **Docker** (host'da), SMTP sinovi uchun. `axllent/mailpit` image'i `amd64` va `arm64` uchun chiqadi, tekshirish: `docker manifest inspect axllent/mailpit | grep architecture`.

```
docker run -d --name mailpit -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 axllent/mailpit
```

SMTP `127.0.0.1:1025` da, web interfeys `http://localhost:8025` da.

- **Ikkinchi mashinada tiklash**: laboratoriya holati git orqali ko'chmaydi. Ikkinchi mashinada `net1`, `net2` ni yuqoridagi buyruqlar bilan yarating, o'sha mashinada yangi `~/.ssh/lab_ed25519` kalit yarating (private kalitni mashinalar orasida ko'chirmang), public kalitni VM'larga qo'shing va `~/.ssh/config` ga o'sha mashinadagi IP'lar bilan yozuv qo'shing (13-vazifa qadamlari). Javoblar (`README.md`, `probe.sh` va boshqalar) `git pull` bilan keladi.
- **Tozalash**: `docker rm -f mailpit`; `~/.ssh/config` dan laboratoriya yozuvlarini va `~/.ssh/lab_ed25519*` ni o'chirish; VM'lar 6-darsda kerak, `multipass stop net1 net2`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM'lar `amd64`, Multipass tarmog'i odatda `10.x.x.x`. Host'da `ss`, `ip`, `resolvectl` bor, lekin vazifalar baribir VM'da bajariladi, host'dagi natija ixtiyoriy taqqoslash. |
| macOS (uy) | VM'lar `arm64`, Multipass tarmog'i odatda `192.168.x.x`. Host'da `ssh`, `dig`, `curl`, `nc`, `traceroute` bor; `ss`, `ip`, `mtr`, `resolvectl` yo'q. `openssl` aslida LibreSSL va ba'zi flag'lari boshqacha, `timeout` buyrug'i yo'q, `date` BSD varianti. Shuning uchun TLS tekshiruvi va `probe.sh` sinovi `lab` VM'da. Host'ning DNS sozlamasini `scutil --dns` ko'rsatadi (ixtiyoriy). |

---

## 1. TCP

### Bu nima

**TCP (Transmission Control Protocol)** ikki jarayon orasida ishonchli, tartiblangan bayt oqimi beradi. 3-darsda ko'rgan IP faqat paketni manzilga yetkazishga harakat qiladi: paket yo'qolishi, ikki marta kelishi, tartibsiz kelishi mumkin. TCP buni yashiradi: ilova faqat "yozdim" va "o'qidim" ni ko'radi. Node'dagi `net.Socket`, `fetch()`, PostgreSQL driver'i ostida aynan shu oqim turadi. **Socket** bu jarayonning tarmoq ulanishiga tutqichi: kernel ichidagi obyekt, jarayon unga fayl kabi yozadi va undan o'qiydi.

### Portlar va ulanish identifikatori

IP manzil mashinani topadi, **port** esa mashina ichida qaysi jarayonga yetkazishni aniqlaydi. Port 16 bitli son (0–65535).

| Diapazon | Nomi | Izoh |
|----------|------|------|
| 0–1023 | well-known | tinglash uchun root yoki `CAP_NET_BIND_SERVICE` kerak: 22 SSH, 25 SMTP, 53 DNS, 80 HTTP, 443 HTTPS |
| 1024–49151 | registered | 3306 MySQL, 5432 PostgreSQL, 6379 Redis, 8080 |
| 32768–60999 (Linux) | ephemeral | mijoz tomoni uchun kernel tanlaydi: `cat /proc/sys/net/ipv4/ip_local_port_range` |

Ulanish to'rtlik bilan aniqlanadi: `(src IP, src port, dst IP, dst port)`. Shuning uchun bitta server 443-portda minglab ulanishni ushlaydi: har birining mijoz IP yoki porti boshqa. Brauzerdan bir saytga ochilgan ikki tab ham ikki xil ephemeral port oladi. Port nomlari ro'yxati: `/etc/services`.

### Mexanizm: three-way handshake

Ma'lumot yuborishdan oldin ikki tomon ulanish o'rnatadi. TCP header'ida bir bitli bayroqlar (flag) bor: `SYN` (boshlash), `ACK` (tasdiq), `FIN` (yopish), `RST` (darhol uzish), `PSH` (ma'lumotni ilovaga darhol ber).

```
client                         server (LISTEN)
  | ---- SYN, seq=x ----------> |
  | <--- SYN-ACK, seq=y, ack=x+1 |
  | ---- ACK, ack=y+1 --------> |
  |        ESTABLISHED           |
```

Uch qadam nima uchun: har tomon o'z boshlang'ich **sequence** raqamini (baytlarni sanash boshlanadigan son) e'lon qiladi va ikkinchi tomon uni tasdiqlaydi. Handshake'da MSS (bir segmentdagi maksimal ma'lumot hajmi), window scaling, SACK kabi opsiyalar ham kelishiladi. Bu bitta round trip (**RTT**, paket borib-qaytish vaqti) oladi, TLS undan keyin yana qo'shadi: uzoq serverga yangi ulanish shuning uchun qimmat va connection pool, keep-alive shuning uchun kerak.

Yopilish: har tomon o'z yo'nalishini `FIN` bilan yopadi, ikkinchisi `ACK` beradi (odatda to'rt paket). `RST` esa darhol uzish: port yopiq, jarayon o'ldi, yoki firewall `reject` qildi.

### Misol: tinglovchi, ulanish va handshake'ni ko'rish

`lab` VM'da ikki terminal oching (ikkalasida `multipass shell lab`). Birinchisida oddiy HTTP server:

```
ubuntu@lab:~$ python3 -m http.server 8080
Serving HTTP on 0.0.0.0 port 8080 (http://0.0.0.0:8080/) ...
```

Ikkinchisida tinglovchilar ro'yxati (`-t` TCP, `-l` faqat tinglovchilar, `-n` raqam ko'rinishida, `-p` jarayon):

```
ubuntu@lab:~$ sudo ss -tlnp
State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port  Process
LISTEN  0       4096    127.0.0.53%lo:53     0.0.0.0:*          users:(("systemd-resolve",pid=<PID>,fd=<N>))
LISTEN  0       5       0.0.0.0:8080         0.0.0.0:*          users:(("python3",pid=<PID>,fd=3))
LISTEN  0       4096    *:22                 *:*                users:(("sshd",pid=<PID>,fd=3),("systemd",pid=1,fd=<N>))
```

Qatorma-qator: birinchi qator systemd-resolved'ning lokal DNS stub'i, `127.0.0.53%lo` faqat loopback interfeysida, ya'ni tashqaridan yetib bo'lmaydi (3-bo'lim; sizda `127.0.0.54:53` qatori ham bo'lishi mumkin). Ikkinchi qator bizning server: `0.0.0.0:8080` barcha IPv4 interfeyslarda, `Send-Q` ustunidagi `5` tinglovchi uchun navbat (backlog) sig'imi, `fd=3` jarayon ichidagi socket'ning fayl deskriptori. Uchinchi qator SSH: `*:22` IPv4 va IPv6 ikkalasi, `systemd` ham ko'rinadi, chunki Ubuntu 24.04 da portni systemd ochib `sshd` ga beradi (4-bo'lim). `Local Address:Port` ni o'qish qoidasi: `127.0.0.1:5432` faqat lokal, `0.0.0.0:80` barcha IPv4, `[::]:22` barcha IPv6 (va odatda IPv4 ham), `*:8080` ikkalasi.

Endi handshake. Ikkinchi terminalda paket ushlagichni ishga tushiring, uchinchisida `curl -s http://127.0.0.1:8080/ -o /dev/null` ni bajaring:

```
ubuntu@lab:~$ sudo tcpdump -i lo -nn tcp port 8080
IP 127.0.0.1.<P> > 127.0.0.1.8080: Flags [S], seq <x>, win 65495, options [mss 65495,sackOK,TS val <...>,nop,wscale 7], length 0
IP 127.0.0.1.8080 > 127.0.0.1.<P>: Flags [S.], seq <y>, ack <x+1>, win 65483, options [...], length 0
IP 127.0.0.1.<P> > 127.0.0.1.8080: Flags [.], ack 1, win 512, options [...], length 0
IP 127.0.0.1.<P> > 127.0.0.1.8080: Flags [P.], seq 1:<N>, ack 1, win 512, options [...], length <N-1>: HTTP: GET / HTTP/1.1
...
IP 127.0.0.1.<P> > 127.0.0.1.8080: Flags [F.], seq <...>, ack <...>, win 512, options [...], length 0
```

`<P>` mijozning ephemeral porti. `Flags [S]` bu SYN, `[S.]` SYN-ACK (nuqta ACK belgisi), `[.]` yolg'iz ACK: birinchi uch qator handshake. Handshake'dan keyin tcpdump raqamlarni nisbiy ko'rsatadi (`ack 1`). `[P.]` ma'lumotli segment: `length` noldan katta va ichida HTTP so'rovi. `[F.]` FIN, yopilish boshlandi. `options` ichidagi `mss`, `sackOK`, `wscale` handshake'da kelishilgan opsiyalar. `Ctrl+C` bilan to'xtating.

### Holatlar va ss

| Holat (`ss` da) | Ma'nosi |
|-----------------|---------|
| `LISTEN` | server socket ulanish kutmoqda |
| `SYN-SENT` | mijoz SYN yubordi, javob kutmoqda. Ko'p bo'lsa: manzil javob bermayapti (firewall, route) |
| `SYN-RECV` | server SYN oldi, oxirgi ACK'ni kutmoqda |
| `ESTAB` | ulanish ochiq |
| `FIN-WAIT-1`, `FIN-WAIT-2` | biz yopdik, qarshi tomonni kutmoqdamiz |
| `CLOSE-WAIT` | qarshi tomon yopdi, bizning ilova hali `close()` chaqirmadi. Ko'p bo'lsa: ilovada socket leak |
| `LAST-ACK` | oxirgi tasdiqni kutmoqda |
| `TIME-WAIT` | yopilgan, kechikkan paketlar uchun 60 soniya kutiladi (faol yopgan tomonda) |

```
ss -tlnp                      # TCP listeners with process (sudo to see other users' processes)
ss -ulnp                      # UDP listeners
ss -tan                       # all TCP sockets, numeric
ss -tan state established     # filter by state
ss -tn dst 1.1.1.1            # filter by peer
ss -ti dst 1.1.1.1            # internals: rto, rtt, cwnd, retrans
ss -s                         # summary counters
```

**Tuzoq: `Address already in use`.** Portni boshqa jarayon tinglayapti: `sudo ss -tlnp 'sport = :8080'` egasini ko'rsatadi (Node'dagi `EADDRINUSE` aynan shu xato). Ikkinchi sabab: server endigina to'xtatilgan va eski ulanishlar `TIME-WAIT` da. Serverlar buning uchun `SO_REUSEADDR` socket opsiyasini qo'yadi.

### Ishonchlilik: ACK, retransmission, oqim nazorati

- Har bayt raqamlangan (sequence number). Qabul qiluvchi "shu raqamgacha oldim" deb ACK beradi.
- ACK **RTO** (retransmission timeout, RTT asosida hisoblanadi) ichida kelmasa segment qayta yuboriladi, har urinishda kutish ikki barobar oshadi (exponential backoff).
- Uchta takroriy ACK kelsa RTO'ni kutmasdan qayta yuboriladi (fast retransmit).
- **Flow control**: qabul qiluvchi `window` maydonida bufer'ida qancha joy borligini aytadi. Ilova o'qimasa window nolga tushadi va yuboruvchi to'xtaydi. Node stream'laridagi backpressure shu mexanizmning ilova darajasidagi davomi.
- **Congestion control**: yuboruvchi tarmoq sig'imini o'zi baholaydi, yo'qotish bo'lsa tezlikni kamaytiradi. Linux'da sukut bo'yicha `cubic` (`sysctl net.ipv4.tcp_congestion_control`).

Yangi ulanishda SYN'ga javob kelmasa kernel uni `net.ipv4.tcp_syn_retries` marta (sukut bo'yicha 6) qayta yuboradi: 1, 2, 4, 8, 16, 32 soniya oraliq bilan, jami ikki daqiqadan ortiq. `Connection timed out` shuncha kechikib chiqadi.

**Tuzoq: timeout qo'yilmagan mijoz.** Firewall paketni jim tashlasa (`drop`), timeout'siz HTTP mijoz yoki DB driver ikki daqiqa osilib turadi va shu vaqt ichida thread yoki connection pool tugaydi. Har tashqi chaqiruvda connect va read timeout aniq qo'yiladi. `curl` da: `--connect-timeout 5 --max-time 20`.

**Tuzoq: bo'sh turgan ulanishni o'rtadagi qurilma unutadi.** NAT va load balancer'lar ulanish holatini cheklangan vaqt saqlaydi (cloud load balancer'larda idle timeout odatda bir necha daqiqa). Bo'sh turgan DB ulanishi keyingi so'rovda `connection reset` beradi. Yechim: TCP keepalive yoki ilova darajasidagi ping, pool'da ulanish umrini cheklash.

### nc: qo'lda TCP

`nc` (netcat) bu TCP yoki UDP ulanishni qo'lda ochadigan asbob: klaviaturadan yozganingiz qarshi tomonga ketadi. Port ochiqligini tekshirishning eng oddiy usuli.

```
nc -l 9000                 # listen on TCP 9000 (OpenBSD netcat, default on Ubuntu)
nc 127.0.0.1 9000          # connect; stdin goes to the peer
nc -vz 10.0.0.5 22         # port check without sending data
nc -vz -w 3 10.0.0.5 5432  # with a 3 second timeout
nc -u -l 9001              # UDP listener
```

Uch xil natija uch xil tashxis: `succeeded` port ochiq; `Connection refused` mashina tirik, lekin portda tinglovchi yo'q (kernel `RST` qaytardi); `timed out` paket yo'lda tashlanmoqda yoki mashina yo'q.

### Real ishda qachon kerak

- "Servis ishlamayapti" degan shikoyatda birinchi savol: jarayon tinglayaptimi va qaysi manzilda (`ss -tlnp`). `127.0.0.1` da tinglayotgan servisga tashqaridan yetib bo'lmaydi.
- `refused` va `timed out` farqi muammoni ikkiga bo'ladi: birinchisida ilova tomoni, ikkinchisida tarmoq yoki firewall tomoni qidiriladi.
- Ko'p `CLOSE-WAIT` ilova socket'larni yopmayotganini, ko'p `SYN-SENT` qaramlik javob bermayotganini ko'rsatadi.

### Nima uchun shunday

TCP 1970-yillarda ishonchsiz tarmoqlar ustida ishlash uchun yaratilgan: tarmoq "ahmoq" (faqat paket tashiydi), aql chekkalarda (hostlarda). Shu sabab ishonchlilik har routerda emas, faqat ikki uchida amalga oshiriladi va tarmoq o'rtasidagi qurilma buzilsa ulanish boshqa yo'ldan davom eta oladi. Narxi: handshake kechikishi va bitta yo'qolgan segment butun oqimni kutdirishi (head-of-line blocking). Muqobili UDP ustiga qurilgan QUIC (6-bo'lim), u shu ikki kamchilikni yopadi.

## 2. UDP

### Bu nima

**UDP (User Datagram Protocol)**: header 8 bayt, handshake yo'q, tasdiq yo'q, tartib kafolati yo'q, qayta yuborish yo'q. Har **datagram** (bitta mustaqil xabar) alohida yuboriladi. Ishonchlilik kerak bo'lsa ilova o'zi qiladi. UDP IP ustiga faqat portni qo'shadi.

| Xususiyat | TCP | UDP |
|-----------|-----|-----|
| Ulanish | bor (handshake) | yo'q |
| Yetkazish kafolati, tartib | bor | yo'q |
| Birlik | bayt oqimi | alohida datagram |
| Qo'shimcha kechikish | 1 RTT + qayta yuborishlar | yo'q |
| Qayerda | HTTP/1.1, HTTP/2, SSH, SMTP, ma'lumotlar bazalari | DNS, DHCP, NTP, QUIC (HTTP/3), WireGuard, VoIP |

### Misol: UDP tinglovchilar

```
ubuntu@lab:~$ sudo ss -ulnp
State   Recv-Q  Send-Q  Local Address:Port        Peer Address:Port  Process
UNCONN  0       0       127.0.0.53%lo:53          0.0.0.0:*          users:(("systemd-resolve",pid=<PID>,fd=<N>))
UNCONN  0       0       <VM IP>%<iface>:68        0.0.0.0:*          users:(("systemd-network",pid=<PID>,fd=<N>))
```

Holat `LISTEN` emas, `UNCONN` (unconnected): UDP'da ulanish tushunchasi yo'q, socket shunchaki portga bog'langan. Birinchi qator DNS stub (DNS asosan UDP 53), ikkinchisi DHCP mijozi (port 68, 3-darsda ko'rilgan): VM o'z IP'sini shu orqali olgan. `<iface>` sizdagi interfeys nomi.

**Tuzoq: UDP portni `nc -vz -u` bilan tekshirish.** UDP'da "ulanish" yo'q, shuning uchun "ochiq" va "paket tashlandi" ni ajratib bo'lmaydi: javob kelmasligi ikkala holatda ham bir xil. Yopiq port ICMP "port unreachable" qaytarishi mumkin, lekin firewall uni ham tashlaydi. UDP servisni faqat protokolning o'z so'rovi bilan tekshiring (`dig @server`, `wg show`).

### Real ishda qachon kerak

- DNS, NTP, WireGuard (6-dars) va HTTP/3 UDP'da. Firewall'da faqat TCP ochilgan bo'lsa bular jim ishlamaydi.
- UDP servis "javob bermayapti" bo'lsa, tashxis `tcpdump` bilan qilinadi: paket yetib keldimi, javob chiqdimi.

### Nima uchun shunday

Hamma ilovaga ham TCP kafolatlari kerak emas. Bitta so'rov va bitta javobdan iborat DNS uchun handshake ortiqcha kechikish; ovozli qo'ng'iroqda kechikkan paketni qayta yuborishdan ko'ra tashlab yuborish yaxshi. UDP ilovaga "men o'zim hal qilaman" deyish imkonini beradi. QUIC aynan shunday: ishonchlilikni UDP ustida, kernel'da emas user space'da quradi.

## 3. DNS

### Bu nima

**DNS (Domain Name System)** nomlarni yozuvlarga aylantiradigan taqsimlangan, ierarxik ma'lumotlar bazasi. `fetch('https://api.example.com')` yozganingizda brauzer avval shu nomning IP manzilini DNS'dan so'raydi, chunki IP paket faqat raqamli manzilga yuboriladi. Odatda UDP 53; javob katta bo'lsa yoki zone transfer'da TCP 53.

### Yozuv turlari

| Tur | Mazmuni | Misol |
|-----|---------|-------|
| `A` | nom, IPv4 | `app.example.com. 300 IN A 203.0.113.10` |
| `AAAA` | nom, IPv6 | |
| `CNAME` | nom boshqa nomning taxallusi | `www IN CNAME app.example.com.` |
| `MX` | domen pochtasini qabul qiluvchi server, prioritet bilan | `example.com. IN MX 10 mail.example.com.` |
| `TXT` | ixtiyoriy matn: SPF, DKIM, domen egaligini tasdiqlash | |
| `NS` | zona uchun authoritative serverlar | |
| `SOA` | zona haqida: asosiy server, serial, negative cache TTL | |
| `PTR` | IP, nom (reverse DNS) | `10.113.0.203.in-addr.arpa. IN PTR app.example.com.` |
| `SRV` | servis uchun host va port | Kubernetes, SIP, LDAP |
| `CAA` | qaysi CA shu domenga sertifikat bera oladi | |

**Zona** bu bitta tashkilot boshqaradigan nomlar bo'lagi (masalan `example.com` va uning ostidagilar). Vercel yoki Netlify'ga domen ulaganda qo'ygan `CNAME` va `A` yozuvlaringiz shu jadvaldagi turlar.

**Tuzoq: CNAME boshqa yozuvlar bilan birga yashamaydi.** Nomda `CNAME` bo'lsa, o'sha nomda boshqa tur yozuv bo'lishi mumkin emas. Zona apex'ida (`example.com.`) doim `SOA` va `NS` bor, demak u yerga `CNAME` qo'yib bo'lmaydi. Provayderlar buni `ALIAS`/`ANAME` yoki "CNAME flattening" bilan aylanib o'tadi.

### Mexanizm: resolution yo'li

```
app  ->  stub resolver  ->  recursive resolver  ->  root (.)        "ask .com servers"
        (libc, systemd-     (ISP, 1.1.1.1,      ->  TLD (.com)      "ask example.com NS"
         resolved)           8.8.8.8, VPC DNS)   ->  authoritative   "A 203.0.113.10"
```

1. Ilova `getaddrinfo()` chaqiradi (Node'da `dns.lookup()` shuni ishlatadi). libc `/etc/nsswitch.conf` dagi `hosts:` qatoriga qaraydi: odatda avval `files` (`/etc/hosts`), keyin DNS.
2. Keyin **stub resolver** (o'zi ierarxiya bo'ylab yurmaydigan, faqat so'rovni uzatadigan mijoz) so'rovni `/etc/resolv.conf` dagi `nameserver` ga yuboradi.
3. So'ng **recursive resolver** kesh'da bo'lmasa ierarxiya bo'ylab yuradi: root, TLD (top-level domain, `.com`), **authoritative** (zona yozuvlarining asl egasi bo'lgan server). Javobni **TTL** (time to live) soniya davomida kesh'laydi.

Kesh bir necha joyda: brauzer, OS (systemd-resolved), recursive resolver. "DNS propagation" degani aslida turli kesh'larda eski TTL tugashini kutish.

**Tuzoq: yozuvni o'zgartirishdan oldin TTL tushirilmagan.** TTL 86400 bo'lgan `A` yozuvni o'zgartirsangiz, mijozlarning bir qismi bir sutkagacha eski IP'ga boradi. Migratsiyadan kamida bir eski TTL muddati oldin TTL'ni 60–300 ga tushiring, keyin o'zgartiring, keyin qaytaring. Mavjud bo'lmagan nomga javob ham (`NXDOMAIN`) kesh'lanadi (negative caching, muddati `SOA` dan): yozuvni yaratishdan oldin so'rab ko'rsangiz, yaratgandan keyin ham bir muddat "yo'q" degan javob olasiz.

### Linux'da resolver

| Fayl yoki asbob | Vazifa |
|-----------------|--------|
| `/etc/hosts` | statik nom, IP juftliklari; DNS'dan oldin o'qiladi |
| `/etc/nsswitch.conf` | `hosts:` qatori manbalar tartibini belgilaydi |
| `/etc/resolv.conf` | `nameserver` (3 tagacha), `search` (qisqa nomga qo'shiladigan domenlar), `options ndots:N timeout:N attempts:N` |
| `resolvectl status` | systemd-resolved: har interfeys uchun haqiqiy DNS serverlar |
| `resolvectl query name` | systemd-resolved orqali so'rov |
| `getent hosts name` | libc yo'li bilan (xuddi ilova kabi, `/etc/hosts` ni ham hisobga oladi) |

Ubuntu'da `/etc/resolv.conf` odatda `/run/systemd/resolve/stub-resolv.conf` ga symlink va ichida `nameserver 127.0.0.53`: bu systemd-resolved'ning lokal stub'i. Haqiqiy upstream serverlarni `resolvectl status` ko'rsatadi. Faylni qo'lda tahrirlash foydasiz, u qayta yoziladi. macOS host'da bu fayllar boshqacha ishlaydi, u yerda `scutil --dns` ishlatiladi; serverlar Linux bo'lgani uchun VM'dagi yo'lni o'rganing.

**Tuzoq: `dig` ishladi, ilova ishlamadi (yoki aksincha).** `dig` va `nslookup` to'g'ridan-to'g'ri DNS serverga boradi: `/etc/hosts` va `nsswitch.conf` ni o'qimaydi, `search` domenlarini sukut bo'yicha qo'llamaydi. Ilova nimani ko'rishini `getent hosts` ko'rsatadi.

`ndots:N`: nomda nuqtalar soni N dan kam bo'lsa, avval `search` domenlari qo'shib sinab ko'riladi. Kubernetes pod'larida `ndots:5`: `api.example.com` uchun bir necha keraksiz so'rov ketadi. Nom oxiriga nuqta qo'yish (`api.example.com.`) uni to'liq (FQDN, fully qualified domain name) deb belgilaydi.

### Misol: dig chiqishini o'qish

```
ubuntu@lab:~$ dig ubuntu.com

; <<>> DiG 9.18.<N>-Ubuntu <<>> ubuntu.com
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: <N>
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; QUESTION SECTION:
;ubuntu.com.                    IN      A

;; ANSWER SECTION:
ubuntu.com.             <TTL>   IN      A       <IP>
...

;; Query time: <N> msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
```

`status: NOERROR` so'rov muvaffaqiyatli. `flags`: `qr` bu javob, `rd` biz rekursiya so'radik, `ra` server rekursiyani qo'llaydi; `aa` yo'q, demak javob kesh'dan, authoritative serverning o'zidan emas. `QUESTION` nima so'ralgani (`A` yozuv). `ANSWER` qatori maydonlari: nom, TTL (soniya, kesh'da qancha qolgani), sinf (`IN`, internet), tur, qiymat. `Query time` javob vaqti: ikkinchi so'rovda kesh tufayli `0 msec` ga yaqin bo'ladi. `SERVER` kim javob bergani: lokal stub `127.0.0.53`.

```
dig +short example.com AAAA        # just the value
dig example.com MX +noall +answer  # only the ANSWER section
dig @1.1.1.1 example.com           # ask a specific resolver
dig +trace example.com             # walk from the root yourself
dig -x 1.1.1.1                     # reverse lookup (PTR)
dig example.com NS +short          # authoritative servers
```

Boshqa `status` qiymatlari: `NOERROR` va ANSWER bo'sh (nom bor, shu turdagi yozuv yo'q), `NXDOMAIN` (nom yo'q), `SERVFAIL` (resolver javob ololmadi: authoritative ishlamayapti yoki DNSSEC xatosi), `REFUSED`. Tashxisda asosiy usul: recursive resolver javobini (`dig @1.1.1.1`) authoritative javobi (`dig @<NS nomi>`) bilan solishtirish. Farq bo'lsa bu kesh.

### Real ishda qachon kerak

- Domenni yangi serverga ko'chirish: TTL'ni oldindan tushirish, o'zgarishni authoritative va recursive'da alohida tekshirish.
- "Menda ishlayapti, mijozda yo'q": turli resolver'larda turli kesh. `dig @1.1.1.1` va `dig @8.8.8.8` solishtiriladi.
- Konteyner yoki pod ichida nom topilmasa: `cat /etc/resolv.conf` va `getent hosts`, `dig` emas.

### Nima uchun shunday

DNS'dan oldin barcha hostlar bitta `HOSTS.TXT` faylida edi (bugungi `/etc/hosts` uning merosi), fayl markazdan tarqatilardi va tarmoq o'sgach bu ishlamay qoldi. DNS boshqaruvni ierarxiya bo'ylab taqsimladi: har zona egasi faqat o'z yozuvlariga javob beradi, root faqat TLD'larni biladi. Kesh va TTL tizimni tez va arzon qiladi, narxi esa o'zgarish darhol ko'rinmasligi. UDP tanlangani sababi: bir so'rov, bir javob, handshake ortiqcha.

## 4. SSH

### Bu nima

**SSH (Secure Shell)**: TCP 22 ustida shifrlangan kanal. Masofaviy shell, fayl uzatish (`scp`, `sftp`, `rsync`), port forwarding, git transport (`git@github.com:...`), Ansible transporti. Serverda `sshd` daemon (fon servisi) tinglaydi, sizda `ssh` mijozi. `multipass shell` ham ichkarida shuni ishlatadi.

### Mexanizm: ikki tomonlama autentifikatsiya

1. **Server o'zini isbotlaydi** (host key). Birinchi ulanishda mijoz serverning kalit fingerprint'ini (kalitning qisqa hash'i) ko'rsatadi va `~/.ssh/known_hosts` ga yozadi (TOFU, trust on first use). Keyin kalit o'zgarsa `REMOTE HOST IDENTIFICATION HAS CHANGED` xatosi chiqadi: server qayta o'rnatilgan, IP boshqa hostga o'tgan, yoki o'rtada kimdir bor. Sababini bilsangiz eski yozuv `ssh-keygen -R <host>` bilan o'chiriladi.
2. **Foydalanuvchi o'zini isbotlaydi**. Public key usuli: kalit juftligi yaratiladi, public qismi serverda `~/.ssh/authorized_keys` da turadi, mijoz private kalit bilan imzo qo'yib egaligini isbotlaydi. Private kalit tarmoqqa chiqmaydi. GitHub'ga SSH kalit qo'shganingizda xuddi shu ish bo'lgan: public kalit GitHub'da, private sizda.

```
ssh-keygen -t ed25519 -C "lab key" -f ~/.ssh/lab_ed25519
ssh-copy-id -i ~/.ssh/lab_ed25519.pub user@host   # needs password login to be enabled
ssh -i ~/.ssh/lab_ed25519 user@host
ssh -v user@host                                  # debug: which keys are offered, why rejected
```

`-t ed25519` kalit algoritmi (zamonaviy, qisqa va tez), `-C` izoh, `-f` fayl nomi: `lab_ed25519` private, `lab_ed25519.pub` public.

- Private kalitga passphrase qo'yiladi, qayta-qayta termaslik uchun `ssh-agent` (`ssh-add ~/.ssh/lab_ed25519`): kalitni xotirada ochiq holda ushlab turadigan fon jarayoni.
- **Tuzoq: ruxsatlar.** `sshd` sukut bo'yicha (`StrictModes yes`) egasidan boshqa yoza oladigan `~`, `~/.ssh` yoki `authorized_keys` ni rad etadi va kalit jimgina qabul qilinmaydi. To'g'ri holat: `~/.ssh` 700, `authorized_keys` 600, private kalit 600. Sabab serverda `journalctl -u ssh` da ko'rinadi, mijozda emas.

### Misol: ssh -v ni o'qish

Muvaffaqiyatli ulanishda `ssh -v` chiqishining muhim qatorlari (qolgani qisqartirilgan):

```
$ ssh -v -i ~/.ssh/<key> ubuntu@<VM IP>
debug1: Connecting to <VM IP> [<VM IP>] port 22.
debug1: Connection established.
debug1: Server host key: ssh-ed25519 SHA256:<fingerprint>
debug1: Host '<VM IP>' is known and matches the ED25519 host key.
debug1: Offering public key: <path> ED25519 SHA256:<fingerprint> explicit
debug1: Server accepts key: <path> ED25519 SHA256:<fingerprint> explicit
Authenticated to <VM IP> ([<VM IP>]:22) using "publickey".
```

Tartib bilan: TCP ulanish o'rnatildi (1-bo'limdagi handshake); server host key'ini ko'rsatdi; mijoz uni `known_hosts` dagi bilan solishtirdi (birinchi qadam, server isboti); mijoz o'z public kalitini taklif qildi; server uni `authorized_keys` da topdi; imzo tekshirildi (ikkinchi qadam, foydalanuvchi isboti). Kalit rad etilsa `Server accepts key` qatori bo'lmaydi va oxirida `Permission denied (publickey)` chiqadi: mijoz faqat "rad etildi" ni biladi, sababini server logi aytadi.

### Mijoz konfiguratsiyasi: ~/.ssh/config

```
Host net1
    HostName 10.84.12.31
    User ubuntu
    IdentityFile ~/.ssh/lab_ed25519
    IdentitiesOnly yes

Host db-private
    HostName 10.0.2.15
    User ubuntu
    ProxyJump bastion
```

`ssh net1` endi barcha parametrlarni shu yerdan oladi; `scp`, `rsync`, `git`, Ansible ham shu faylni ishlatadi. `HostName` dagi IP misol, o'zingizniki `multipass list` dan. `IdentitiesOnly yes` agent'dagi barcha kalitlarni ketma-ket taklif qilishni to'xtatadi (`Too many authentication failures` ning sababi). `ProxyJump` (buyruqda `-J`) ichki hostga **bastion** (tashqaridan ochiq yagona kirish serveri) orqali ulanadi: shifrlash oxirgi hostgacha, bastion faqat TCP'ni uzatadi.

### Port forwarding

| Tur | Buyruq | Nima qiladi |
|-----|--------|-------------|
| Local | `ssh -L 8080:127.0.0.1:80 net1` | mening `localhost:8080` im, `net1` nuqtai nazaridan `127.0.0.1:80` ga |
| Remote | `ssh -R 9000:127.0.0.1:3000 net1` | `net1` dagi `localhost:9000`, mening `localhost:3000` imga |
| Dynamic | `ssh -D 1080 net1` | menda SOCKS proxy, trafik `net1` dan chiqadi |

`-N` shell ochmasdan faqat tunnel. Local forward'ning tipik ishi: faqat `127.0.0.1` da tinglayotgan yoki private subnet'dagi ma'lumotlar bazasiga vaqtincha ulanish, portni internetga ochmasdan. Remote forward `ngrok` kabi asboblar qiladigan ishning qo'lda varianti: lokal dev serverni masofadagi mashina orqali ko'rsatish.

### sshd ni qattiqlashtirish

Server sozlamasi `/etc/ssh/sshd_config` va `/etc/ssh/sshd_config.d/*.conf` (drop-in fayllar: asosiy faylga tegmasdan qo'shiladigan bo'laklar). Minimal to'plam:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers ubuntu deploy
MaxAuthTries 3
```

```
sudo sshd -t                                # validate syntax before reloading
sudo sshd -T | grep -i passwordauth         # effective value after all includes
sudo systemctl reload ssh                   # the unit is "ssh" on Ubuntu, "sshd" on RHEL
```

**Tuzoq: birinchi uchragan qiymat yutadi.** `sshd_config` da har kalit so'z uchun birinchi topilgan qiymat ishlatiladi, `Include /etc/ssh/sshd_config.d/*.conf` esa fayl boshida turadi. Cloud image'lardagi drop-in fayl `PasswordAuthentication` ni allaqachon belgilagan bo'lsa, asosiy fayldagi qatoringiz e'tiborsiz qoladi. Haqiqatni faqat `sshd -T` ko'rsatadi.

**Tuzoq: o'zingizni qulflab qo'yish.** `sshd` ni o'zgartirganda joriy sessiyani yopmang: `reload` mavjud ulanishlarni uzmaydi. Yangi terminalda ulanib tekshiring, ishlamasa eski sessiyadan qaytaring.

**Tuzoq: Ubuntu 24.04 da portni o'zgartirish.** `sshd` socket activation orqali ishga tushadi (`ssh.socket`), tinglash portini systemd ochadi. `Port` ni o'zgartirgandan keyin `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket` kerak, `reload ssh` yetmaydi. Portni o'zgartirish xavfsizlik chorasi emas, faqat log shovqinini kamaytiradi.

Agent forwarding (`ssh -A`) ishonchsiz serverda xavfli: o'sha serverdagi root sizning agent'ingiz orqali boshqa hostlarga kira oladi. O'rniga `ProxyJump`.

### Real ishda qachon kerak

- Har serverga kirish, CI'dan deploy, Ansible, `git push`: hammasi SSH kalit bilan. `Permission denied (publickey)` eng ko'p uchraydigan deploy xatolaridan.
- Private subnet'dagi bazaga vaqtincha ulanish: `-L` tunnel va bastion.
- Yangi serverning birinchi sozlamasi: parol va root login'ni o'chirish.

### Nima uchun shunday

SSH 1995-yilda parolni ochiq matnda yuboradigan `telnet` va `rsh` o'rniga yaratilgan. Public key usulida serverga sir berilmaydi: server buzilsa ham u yerda faqat public kalitlar bor, ular bilan boshqa joyga kirib bo'lmaydi. Parolda esa sir har ulanishda serverga boradi va internetdagi botlar uni tinimsiz taxmin qiladi. TOFU murosali yechim: sertifikat markazi (CA) talab qilmaydi, lekin birinchi ulanishga ishonadi; katta tashkilotlar buning o'rniga SSH sertifikatlaridan foydalanadi.

## 5. SMTP va pochta DNS yozuvlari

### Bu nima

**SMTP (Simple Mail Transfer Protocol)** xatni serverdan serverga yetkazadi. Ilovangiz yuboradigan "parolni tiklash" xati ham shu protokol bilan ketadi. HTTP/1.1 kabi matnli protokol, shuning uchun `nc` bilan qo'lda gaplashish mumkin:

```
S: 220 mail.example.org ESMTP
C: EHLO client.example.com
C: MAIL FROM:<alice@example.com>
C: RCPT TO:<bob@example.org>
C: DATA
C: Subject: hello
C:
C: body text
C: .
S: 250 OK
C: QUIT
```

`S:` server, `C:` mijoz qatorlari (misolda server javoblarining bir qismi tushirib qoldirilgan, aslida har buyruqqa javob keladi). `220` server tayyor; `EHLO` mijoz o'zini tanishtiradi; `MAIL FROM` va `RCPT TO` konvert (envelope): kimdan va kimga; `DATA` dan keyin xatning o'zi (header'lar, bo'sh qator, tana), yolg'iz nuqtali qator oxirini bildiradi. Javob kodlari HTTP statuslariga o'xshash sinflarga bo'linadi: `2xx` qabul qilindi, `3xx` davom eting (`354` ma'lumotni yuboring), `4xx` vaqtinchalik xato (keyinroq urinib ko'r), `5xx` doimiy rad.

`MAIL FROM` (envelope sender) va xat ichidagi `From:` header alohida narsalar va bir-biriga mos kelishi shart emas. Spoofing (birovning nomidan yuborish) shunga asoslanadi, quyidagi uch mexanizm shuni yopadi.

| Port | Vazifa |
|------|--------|
| 25 | serverdan serverga (MTA, mail transfer agent). Cloud provayderlar chiquvchi 25-portni odatda bloklaydi |
| 587 | submission: ilova yoki pochta mijozi o'z provayderiga, STARTTLS va autentifikatsiya bilan |
| 465 | submission, boshidan TLS |

### Mexanizm: yetkazish va tekshiruv

Yetkazish yo'li: yuboruvchi server qabul qiluvchi domenning `MX` yozuvlarini so'raydi (3-bo'lim), prioriteti eng kichik (eng afzal) serverga 25-portda ulanadi. Qabul qiluvchi server yuboruvchini uchta DNS yozuvi orqali tekshiradi:

| Mexanizm | DNS yozuvi | Nimani tekshiradi |
|----------|-----------|-------------------|
| SPF | domenda `TXT`: `v=spf1 include:_spf.example.net ip4:203.0.113.0/24 -all` | ulangan IP shu domen (envelope sender) nomidan yuborishga ruxsatlimi |
| DKIM | `<selector>._domainkey.example.com` da `TXT` (public kalit) | xatdagi `DKIM-Signature` imzosi: header va tana yo'lda o'zgarmagan, imzolovchi domen kalit egasi |
| DMARC | `_dmarc.example.com` da `TXT`: `v=DMARC1; p=quarantine; rua=mailto:...` | SPF yoki DKIM o'tgan domen `From:` dagi domenga mos keladimi (alignment); o'tmasa nima qilish (`none`, `quarantine`, `reject`) va hisobot qayerga |

### Misol: SPF yozuvini o'qish

```
ubuntu@lab:~$ dig +short example.net TXT
"v=spf1 include:_spf.example.net ip4:203.0.113.0/24 -all"
```

Bu darsdagi shartli misol, real domen natijasi boshqacha bo'ladi. Chapdan o'ngga: `v=spf1` bu SPF yozuvi ekanini bildiradi; `include:_spf.example.net` o'sha nomdagi SPF ro'yxatini ham qo'sh (pochta xizmati provayderining IP'lari); `ip4:203.0.113.0/24` shu subnet'dan yuborish mumkin; `-all` qolgan hammasi rad etilsin (`~all` bo'lsa "shubhali deb belgila").

DevOps amaliyoti: ilova xatlari odatda o'z serveringizdan emas, tranzaksion pochta xizmati (Amazon SES, Postmark va shu kabi) orqali 587-portda yuboriladi. Sizning ishingiz: domenga SPF `include`, DKIM `CNAME`/`TXT` va DMARC yozuvlarini to'g'ri qo'yish. O'z serveringizdan yuborsangiz IP'ning `PTR` yozuvi ham kerak.

**Tuzoq: bir domenda ikkita SPF yozuvi.** `v=spf1` bilan boshlanadigan `TXT` faqat bitta bo'lishi kerak; ikkinchi xizmat qo'shilsa mavjud yozuvga `include:` qo'shiladi, yangi yozuv yaratilmaydi. Ikkitasi bo'lsa SPF xato (`permerror`) beradi.

### Real ishda qachon kerak

- "Xatlar spam'ga tushyapti" shikoyati: `MX`, SPF, DKIM, DMARC yozuvlari `dig` bilan tekshiriladi.
- Lokal va CI muhitida haqiqiy xat yubormaslik uchun Mailpit kabi test server, ilova `SMTP_HOST` ni unga qaratadi.
- Cloud serverdan 25-port bloklangani uchun "xat ketmayapti": 587 va pochta xizmati ishlatiladi.

### Nima uchun shunday

SMTP 1982-yilda, tarmoqdagi hamma bir-biriga ishongan davrda yozilgan: yuboruvchini tekshirish umuman yo'q edi. Protokolni almashtirish imkonsiz (butun dunyo pochtasi unda), shuning uchun himoya keyinroq DNS orqali ustiga qo'shildi: SPF, DKIM, DMARC uch alohida davrda paydo bo'lgan uch yamoq. Shu sabab ular uch xil narsani tekshiradi va uchalasi birga kerak.

## 6. HTTP va TLS: ostidagi qatlam

### Bu nima

HTTP semantikasi sizga tanish. Ops nuqtai nazaridan muhimi uning ostidagi transport:

| Versiya | Transport | Xususiyat |
|---------|-----------|-----------|
| HTTP/1.1 | TCP | bir ulanishda bir vaqtda bitta so'rov, brauzer hostga bir nechta ulanish ochadi |
| HTTP/2 | TCP + TLS | bitta ulanishda ko'p oqim (multiplexing); bitta yo'qolgan TCP segment hamma oqimni to'xtatadi |
| HTTP/3 | QUIC (UDP 443) | oqimlar mustaqil, handshake tezroq; firewall'da UDP 443 ochiq bo'lishi kerak |

**TLS (Transport Layer Security)** TCP ustidagi shifrlash va server shaxsini tasdiqlash qatlami: HTTPS bu TLS ichidagi HTTP. **Sertifikat** bu "shu public kalit shu domen nomiga tegishli" degan, **CA** (certificate authority, sertifikat markazi) imzolagan hujjat.

### Mexanizm: TLS handshake

TLS TCP handshake'dan keyin bajariladi (TLS 1.3 da bir RTT):

1. **ClientHello**: qo'llab-quvvatlanadigan versiya va shifrlar, **SNI** (qaysi host nomi so'ralmoqda, ochiq matnda), **ALPN** (qaysi HTTP versiyasi: `h2`, `http/1.1`).
2. **ServerHello + Certificate**: server sertifikat zanjirini yuboradi: leaf (saytning o'zi) va intermediate (oraliq CA).
3. Mijoz tekshiradi: zanjir tizimdagi ishonchli root CA gacha boradimi, muddat (`notBefore`, `notAfter`), nom sertifikatning SAN (Subject Alternative Name) ro'yxatida bormi.

### Misol: sertifikatni o'qish

`lab` VM'da (macOS host'idagi `openssl` LibreSSL bo'lib, `-ext` flag'i farq qilishi mumkin):

```
ubuntu@lab:~$ openssl s_client -connect ubuntu.com:443 -servername ubuntu.com </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
subject=CN = ubuntu.com
issuer=C = <...>, O = <CA nomi>, CN = <intermediate nomi>
notBefore=<sana>
notAfter=<sana>
X509v3 Subject Alternative Name:
    DNS:ubuntu.com, DNS:<...>
```

Birinchi buyruq TLS ulanish ochadi (`-servername` SNI yuboradi, `</dev/null` ulanishni darhol yopadi), ikkinchisi olingan leaf sertifikatni tahlil qiladi. `subject` sertifikat kimga berilgan; `issuer` kim imzolagan (intermediate CA); `notBefore`, `notAfter` amal qilish oralig'i; `Subject Alternative Name` sertifikat yaroqli bo'lgan nomlar ro'yxati, mijoz URL'dagi nomni aynan shu ro'yxatdan qidiradi.

```
curl -v https://example.com/ -o /dev/null
curl -sv --resolve example.com:443:203.0.113.10 https://example.com/   # bypass DNS, keep SNI and Host
openssl s_client -connect example.com:443 -servername example.com </dev/null
```

`--resolve` DNS'ni chetlab o'tib aniq IP'ga boradi, lekin SNI va `Host` header to'g'ri qoladi: DNS'ni almashtirishdan oldin yangi serverni sinashning usuli.

**Tuzoq: intermediate sertifikat serverda yo'q.** Server faqat leaf sertifikatni yuborsa, brauzer ko'pincha ishlaydi (intermediate'ni kesh'dan oladi yoki o'zi yuklab oladi), `curl`, Node, Go va Python mijozlari esa `unable to get local issuer certificate` beradi. `openssl s_client` chiqishidagi `Certificate chain` bo'limida zanjir to'liqligini tekshiring.

**Tuzoq: `-servername` siz tekshirish.** Bitta IP'da ko'p sayt bo'lsa, server SNI bo'yicha sertifikat tanlaydi. Eski `openssl` versiyalari SNI yubormaydi va siz default sertifikatni ko'rib noto'g'ri xulosa qilasiz. Doim `-servername` yozing.

### Real ishda qachon kerak

- Sertifikat muddati monitoringi: `notAfter` ni skript bilan tekshirish (22-vazifa).
- "Brauzerda ishlaydi, backend'dan `fetch` xato beradi": deyarli har doim to'liq bo'lmagan zanjir.
- Load balancer yoki reverse proxy ortidagi serverni DNS'siz sinash: `curl --resolve`.

### Nima uchun shunday

HTTP dastlab ochiq matnda edi: yo'ldagi har qurilma o'qiy va o'zgartira olardi. TLS ikki muammoni yechadi: shifrlash va "men haqiqatan shu sayt bilan gaplashyapmanmi". Ikkinchisi uchun CA zanjiri tanlangan: mijoz millionlab saytni emas, bir necha o'nlab root CA'ni biladi. SSH'dagi TOFU bilan solishtiring: u yerda birinchi ulanishga ishoniladi, bu yerda uchinchi tomonga. SNI ochiq matnda bo'lishi sababi: server qaysi sertifikatni berishni shifrlash boshlanishidan oldin bilishi kerak.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Protokol | ikki dastur muloqoti uchun kelishilgan qoidalar: xabar shakli va tartibi |
| Port | host ichida jarayonni aniqlaydigan 16 bitli son |
| Socket | jarayonning tarmoq ulanishiga tutqichi, kernel ichidagi obyekt |
| Ephemeral port | mijoz tomoni uchun kernel vaqtincha tanlaydigan port |
| Handshake | ma'lumot almashishdan oldin ulanish o'rnatadigan paketlar ketma-ketligi |
| SYN, ACK, FIN, RST | TCP bayroqlari: boshlash, tasdiq, yopish, darhol uzish |
| RTT | paketning borib-qaytish vaqti |
| RTO | tasdiq kelmasa segment qayta yuborilgunicha kutiladigan vaqt |
| Datagram | UDP'dagi bitta mustaqil xabar |
| Stub resolver | so'rovni recursive resolver'ga uzatadigan lokal DNS mijozi |
| Recursive resolver | javobni ierarxiya bo'ylab yurib topadigan va kesh'laydigan DNS server |
| Authoritative server | zona yozuvlarining asl manbai bo'lgan DNS server |
| TTL (DNS) | javob kesh'da saqlanishi mumkin bo'lgan soniyalar |
| FQDN | oxirigacha to'liq yozilgan domen nomi |
| Host key | SSH serverining o'zini isbotlaydigan kaliti |
| `authorized_keys` | serverda kirishga ruxsat berilgan public kalitlar ro'yxati |
| Bastion | ichki tarmoqqa kirish uchun yagona ochiq SSH server |
| Port forwarding | SSH kanali ichidan TCP portni uzatish (tunnel) |
| Envelope sender | SMTP `MAIL FROM` dagi manzil, `From:` header'dan alohida |
| MX | domen pochtasini qabul qiluvchi serverni ko'rsatadigan DNS yozuvi |
| SPF, DKIM, DMARC | yuboruvchi IP'ni, xat imzosini va `From:` mosligini tekshiradigan uch mexanizm |
| TLS | TCP ustidagi shifrlash va server shaxsini tasdiqlash qatlami |
| Sertifikat zanjiri | leaf, intermediate va root CA sertifikatlari ketma-ketligi |
| SNI | TLS ClientHello'dagi so'ralayotgan host nomi |
| SAN | sertifikat yaroqli bo'lgan nomlar ro'yxati |

## Tuzoqlar

- `refused` va `timed out` ni farqlamaslik: birinchisi port yopiq, ikkinchisi paket yo'lda tashlanmoqda.
- Mijozlarda timeout yo'q: bitta qora tuynuk butun servisning connection pool'ini egallaydi.
- Servis `127.0.0.1` da tinglayapti, lekin tashqaridan kutilmoqda. Yoki ma'lumotlar bazasi `0.0.0.0` da va firewall yo'q.
- DNS o'zgarishidan oldin TTL tushirilmagan; yoki yangi nom yaratilishidan oldin so'ralib, negative cache'ga tushgan.
- `dig` natijasi bilan ilova ko'rgan natijani bir xil deb hisoblash (`/etc/hosts`, `search`, `ndots`).
- `/etc/resolv.conf` ni qo'lda tahrirlash: systemd-resolved yoki DHCP uni qayta yozadi.
- SSH private kalitni repo'ga, Docker image'ga yoki CI log'iga tushirish. Kalit oshkor bo'lsa uni barcha `authorized_keys` dan o'chirish kerak, yangisini yaratish yetmaydi.
- `sshd_config` ni tekshirmasdan (`sshd -t`, `sshd -T`) va zaxira sessiyasiz o'zgartirish.
- Host key ogohlantirishini o'ylamasdan `StrictHostKeyChecking no` bilan o'chirish.
- Sertifikat muddatini kuzatmaslik: avtomatik yangilash ishlamay qolganini muddat tugagan kuni bilish.
- SPF, DKIM, DMARC sozlanmagan domendan tranzaksion xat yuborish: xatlar spam'ga tushadi yoki rad etiladi.
- macOS host'ida sinab ko'rilgan `openssl`, `date`, `nc` flag'lari Linux serverda boshqacha bo'lishi mumkin. Skript va TLS tekshiruvlarini `lab` VM'da bajaring.
- VM IP'lari mashinaga bog'liq va VM qayta yaratilsa o'zgaradi: `~/.ssh/config` dagi `HostName` va `known_hosts` eskirib qoladi.

## Manbalar

- https://www.rfc-editor.org/rfc/rfc9293 – TCP (zamonaviy spetsifikatsiya)
- https://man7.org/linux/man-pages/man8/ss.8.html – `ss`
- https://man7.org/linux/man-pages/man7/tcp.7.html – Linux TCP sysctl'lari
- https://www.tcpdump.org/manpages/tcpdump.1.html – `tcpdump`, chiqish formati
- https://www.rfc-editor.org/rfc/rfc1034 va https://www.rfc-editor.org/rfc/rfc1035 – DNS
- https://www.cloudflare.com/learning/dns/what-is-dns/ – DNS resolution yo'li sharhi
- https://man7.org/linux/man-pages/man5/resolv.conf.5.html – `resolv.conf`
- https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html – systemd-resolved
- https://man.openbsd.org/ssh_config va https://man.openbsd.org/sshd_config – SSH mijoz va server sozlamalari
- https://www.rfc-editor.org/rfc/rfc5321 – SMTP
- https://www.cloudflare.com/learning/email-security/dmarc-dkim-spf/ – SPF, DKIM, DMARC sharhi
- https://mailpit.axllent.org/docs/ – Mailpit
- https://www.rfc-editor.org/rfc/rfc8446 – TLS 1.3
- https://docs.openssl.org/master/man1/openssl-s_client/ – `openssl s_client`
- https://curl.se/docs/manpage.html – `curl`
- https://documentation.ubuntu.com/multipass/ – Multipass (`net1`, `net2` VM'lari)
- Stevens, Fall, "TCP/IP Illustrated, Volume 1" (2-nashr), 12–17-boblar (TCP)

## Birga bajaramiz

Bitta HTTPS so'rovni qatlamlarga ajratamiz: DNS, TCP, TLS, HTTP har biri qancha vaqt oldi va har biri buzilganda xato qanday ko'rinadi. Misol `lab` VM'dan `https://www.kernel.org/` ga so'rov. Vazifalardagi holatlar (nc, SSH, Mailpit, `probe.sh`) bu yerda ishlatilmaydi.

1. Nomni ilova ko'radigan yo'l bilan resolve qiling:

```
ubuntu@lab:~$ getent ahosts www.kernel.org | head -3
<IP>   STREAM <nom>
<IP>   DGRAM
<IP>   RAW
```

`getent ahosts` libc'ning `getaddrinfo()` yo'lidan o'tadi: `/etc/hosts`, keyin DNS. Birinchi ustun IP, ikkinchisi socket turi (`STREAM` TCP uchun), uchinchisi kanonik nom: so'ralgan nom `CNAME` bo'lsa bu yerda boshqa nom chiqadi.

2. So'rovni bosqichlarga bo'lib o'lchang. `curl -w` yakunda ichki taymerlarini chiqaradi:

```
ubuntu@lab:~$ curl -s -o /dev/null -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n' https://www.kernel.org/
dns=<0.0NN> tcp=<0.0NN> tls=<0.NNN> total=<0.NNN>
```

Har qiymat so'rov boshidan o'sha bosqich tugaguncha o'tgan soniya. `dns` nom topilgan payt; `tcp` minus `dns` bu TCP handshake, ya'ni taxminan bir RTT; `tls` minus `tcp` TLS handshake; `total` minus `tls` HTTP so'rov va javob. Buyruqni ikkinchi marta bajaring: `dns` keskin kamayadi (systemd-resolved keshi), qolganlari deyarli o'zgarmaydi, chunki har safar yangi ulanish ochiladi.

3. O'sha bosqichlarni `curl -v` matnida toping:

```
ubuntu@lab:~$ curl -sv -o /dev/null https://www.kernel.org/ 2>&1 | grep -E 'Trying|Connected|ALPN|SSL connection|subject:|expire|HTTP/'
*   Trying <IP>:443...
* Connected to www.kernel.org (<IP>) port 443
* ALPN: curl offers h2,http/1.1
* SSL connection using TLSv1.3 / <shifr nomi> / <...>
*  subject: CN=<nom>
*  expire date: <sana>
> GET / HTTP/2
< HTTP/2 200
```

`Trying` DNS tugadi va SYN yuborildi; `Connected` TCP handshake tugadi; `ALPN` mijoz taklif qilgan HTTP versiyalari; `SSL connection using TLSv1.3` TLS handshake tugadi va versiya kelishildi; `subject` va `expire date` leaf sertifikatdan; `>` bilan boshlangan qator mijoz so'rovi, `<` server javobi. Sizda qatorlar matni curl versiyasiga qarab biroz farq qilishi mumkin.

4. Handshake paytida socket holatini ushlang. Bir terminalda `curl -s --limit-rate 1k -o /dev/null https://www.kernel.org/` (sekinlashtirilgan yuklash), ikkinchisida:

```
ubuntu@lab:~$ ss -tn state established '( dport = :443 )'
Recv-Q  Send-Q   Local Address:Port    Peer Address:Port
<N>     0        <VM IP>:<P>           <IP>:443
```

To'rtlik ko'rinib turibdi: VM IP va ephemeral port `<P>`, server IP va 443. `Recv-Q` noldan katta bo'lsa, kernel ma'lumotni olgan, lekin `curl` hali o'qimagan (`--limit-rate` tufayli): flow control aynan shu navbat to'lganda ishga tushadi.

5. Endi har qatlamni alohida buzing va xatoni o'qing:

```
ubuntu@lab:~$ curl -s -S https://no-such-name.invalid/ ; echo "exit=$?"
curl: (6) Could not resolve host: no-such-name.invalid
exit=6
ubuntu@lab:~$ curl -s -S http://127.0.0.1:81/ ; echo "exit=$?"
curl: (7) Failed to connect to 127.0.0.1 port 81 after 0 ms: Couldn't connect to server
exit=7
ubuntu@lab:~$ curl -s -S --connect-timeout 3 http://10.255.255.1/ ; echo "exit=$?"
curl: (28) Failed to connect to 10.255.255.1 port 80 after 3002 ms: Timeout was reached
exit=28
```

Uch xil exit code uch xil qatlam: `6` DNS (nom topilmadi, TCP boshlangani ham yo'q); `7` TCP rad etildi (mashina javob berdi, portda tinglovchi yo'q, darhol: `0 ms`); `28` timeout (SYN'ga javob yo'q, `--connect-timeout` bo'lmaganida ikki daqiqa kutardi). Xato matni curl versiyasiga qarab farq qilishi mumkin, exit code'lar barqaror. `.invalid` hech qachon mavjud bo'lmasligi kafolatlangan maxsus TLD.

6. Xulosa jadvalini tuzing: qatlam, sog'lom holatda qaysi buyruq ko'rsatadi, buzilganda qanday xato. Tashxis doim pastdan yuqoriga: nom topildimi, port ochildimi, TLS o'tdimi, HTTP nima dedi.

---

## Vazifalar

Ish papkasi: `network/04-protocols/` (`make new m=network n=04 name=protocols` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh, qayerda bajarilgani (`lab`, `net1`, `net2`, host) bilan. So'ralgan fayllarni (`ssh_config.example`, `sshd_hardening.conf`, `mail.txt`, `probe.sh`) shu papkaga saqlang. Private kalit va haqiqiy `~/.ssh/config` papkaga ko'chirilmaydi. "Host'da" deyilgan qismlar Zorin'da ham, macOS'da ham bir xil ishlaydi; "ixtiyoriy" qismlarni o'sha mashinada bo'lsangiz qo'shing.

### A. TCP va UDP

1. **Listening sockets.** `lab` VM'da `sudo ss -tlnp` va `sudo ss -ulnp` chiqishini jadvalga aylantiring: port, tinglash manzili, jarayon, tarmoqdan yetib bo'ladimi yoki faqat lokal. Kutilmagan ochiq port bormi? Ixtiyoriy: host'da ham ko'ring (Zorin'da xuddi shu buyruq; macOS'da `ss` yo'q, o'rniga `sudo lsof -iTCP -sTCP:LISTEN -n -P`) va VM bilan solishtiring. Yo'nalish: 1-bo'lim, "Misol: tinglovchi, ulanish va handshake'ni ko'rish"; 2-bo'lim misoli.

2. **Handshake by hand.** `net1` da `nc -l 9000`, `net2` dan `nc <net1 IP> 9000` bilan ulanib matn almashing. Uchinchi sessiyada `net1` da `sudo tcpdump -i any -nn tcp port 9000` bilan handshake, ma'lumot va yopilish paketlarini ushlang. Ulanish ochiq paytda ikkala VM'da `ss -tan | grep 9000` chiqishini yozing va to'rtlikni (IP va portlar) ko'rsating. Mijoz porti qaysi diapazondan? Yo'nalish: 1-bo'lim, "Mexanizm: three-way handshake" va tcpdump misoli.

3. **TCP states.** 2-vazifadagi ulanishda mijozni `Ctrl+C` bilan yoping va darhol ikkala tomonda `ss -tan | grep 9000` ni ko'ring. Qaysi tomonda `TIME-WAIT` paydo bo'ldi va nima uchun aynan o'sha tomonda? Qancha vaqtdan keyin yo'qoladi? Yo'nalish: 1-bo'lim, "Holatlar va ss".

4. **Refused, timeout, reset.** `net1` va `net2` da uch holatni yarating va har birida mijoz xato matni hamda tcpdump'dagi paketlarni yozing: (a) tinglovchisiz portga ulanish; (b) `ss -ti` bilan kuzatib turib, hech qachon javob bermaydigan manzilga (`nc -v 10.255.255.1 80`) ulanish: `SYN-SENT` holati va `rto` qiymati qanday o'zgaradi; (c) ochiq ulanish paytida server jarayonini `kill -9` qilish va mijozdan yana yozish. Yo'nalish: 1-bo'lim, "Ishonchlilik" va "nc: qo'lda TCP".

5. **Address in use.** `net1` da bitta portda ikki marta `nc -l 9000` ishga tushiring. Xato matnini yozing va port egasini `ss` filtri bilan toping. 80-portda oddiy foydalanuvchi sifatida tinglashga urinib ko'ring (`nc -l 80`): xato nima va `sysctl net.ipv4.ip_unprivileged_port_start` qiymati buni qanday tushuntiradi? Yo'nalish: 1-bo'lim, "Portlar va ulanish identifikatori" va "Tuzoq: `Address already in use`".

6. **UDP is different.** `net1` da `nc -u -l 9001`, `net2` dan `nc -u <net1 IP> 9001`. Tcpdump'da handshake bormi? Server'ni to'xtatib mijozdan yana yuboring: mijoz xato ko'radimi, tcpdump'da qanday ICMP paket ko'rindi? Bundan "UDP portni tekshirish" haqida xulosa chiqaring. Yo'nalish: 2-bo'lim.

### B. DNS

7. **Record types.** `lab` VM'da (yoki host'da, `dig` ikkalasida bor) o'zingiz tanlagan real domen (masalan `github.com`) uchun `A`, `AAAA`, `MX`, `NS`, `TXT`, `SOA`, `CAA` yozuvlarini `dig +noall +answer` bilan oling. Har yozuvning TTL'i va ma'nosini yozing. `www` nomi `CNAME` mi yoki `A`? Yo'nalish: 3-bo'lim, "Yozuv turlari".

8. **Trace the hierarchy.** `dig +trace` chiqishini bosqichlarga bo'ling: root serverlar, TLD serverlar, authoritative serverlar. Har bosqichda kim kimga yo'naltirdi? Oxirgi javobni `dig @<authoritative NS>` bilan to'g'ridan-to'g'ri oling va `flags` dagi `aa` ni recursive resolver javobi bilan solishtiring. `+trace` VM'da ishlamasa (ba'zi tarmoqlar tashqi DNS'ni to'sadi) host'da sinang va farqni yozing. Yo'nalish: 3-bo'lim, "Mexanizm: resolution yo'li" va "Misol: dig chiqishini o'qish".

9. **Caching and TTL.** Bir nomni `dig` bilan ketma-ket uch marta, 5 soniya oraliq bilan so'rang: TTL va `Query time` qanday o'zgaradi? Xuddi shuni `@1.1.1.1` va `@8.8.8.8` da takrorlang. Mavjud bo'lmagan nom uchun `status` va AUTHORITY bo'limidagi `SOA` ni toping: negative javob qancha vaqt kesh'lanadi? Yo'nalish: 3-bo'lim, TTL tuzog'i va `dig` misoli.

10. **Resolver config.** `lab` VM'da `ls -l /etc/resolv.conf`, uning mazmuni, `resolvectl status` va `grep hosts /etc/nsswitch.conf` chiqishini izohlang: `127.0.0.53` nima, haqiqiy upstream DNS kim va u qayerdan kelgan (3-darsdagi DHCP)? Upstream manzil host'ingizga bog'liq: Multipass tarmog'idagi qaysi qurilma ekanini `ip route` bilan solishtirib aniqlang. Ixtiyoriy: host'ning o'z resolver'i (Zorin'da `resolvectl status`, macOS'da `scutil --dns`). Yo'nalish: 3-bo'lim, "Linux'da resolver".

11. **hosts vs DNS.** `net1` da `/etc/hosts` ga `203.0.113.99 example.com` qatorini qo'shing. `getent hosts example.com`, `dig +short example.com`, `ping -c 1 example.com` va `curl -sv --connect-timeout 3 http://example.com/` natijalarini solishtiring. Nima uchun farq qiladi? Qatorni o'chiring. Yo'nalish: 3-bo'lim, "Tuzoq: `dig` ishladi, ilova ishlamadi".

12. **Search and ndots.** `net1` da `resolvectl status` dan search domenlarini toping (bo'sh bo'lsa shuni yozing va tajriba uchun vaqtincha `sudo resolvectl domain <iface> lab.test` bilan qo'shing, `<iface>` ni `ip -br addr` dan oling). `sudo tcpdump -i any -nn udp port 53` ishlab turganda `getent hosts web`, `getent hosts web.internal` va `getent hosts web.internal.` ni bajaring. Har biri uchun qanday nomlar so'raldi? Kubernetes'dagi `ndots:5` nima uchun tashqi domenlar uchun ortiqcha so'rov tug'dirishini shu kuzatuv bilan tushuntiring. Yo'nalish: 3-bo'lim, `ndots` haqidagi xatboshi.

### C. SSH

13. **Key-based login.** Host'da `~/.ssh/lab_ed25519` kalitini passphrase bilan yarating. Public kalitni `net1` va `net2` dagi `ubuntu` foydalanuvchisining `authorized_keys` iga qo'shing (`multipass exec` orqali, mavjud qatorlarni o'chirmasdan). `~/.ssh/config` ga ikkala host uchun yozuv qo'shing, shunda `ssh net1` qo'shimcha flag'siz ishlasin. Birinchi ulanishdagi fingerprint savolini va `known_hosts` da paydo bo'lgan qatorni izohlang. Yozuvlarni (real IP'siz) `ssh_config.example` ga saqlang. Yo'nalish: 4-bo'lim, "Mexanizm: ikki tomonlama autentifikatsiya" va "Mijoz konfiguratsiyasi".

14. **Debug a rejected key.** `net1` da ochiq sessiyani yopmasdan (u orqali qaytarasiz) `chmod 777 ~/.ssh` qiling va host'dan qaytadan ulanishga urining. Mijozda `ssh -v` chiqishining tegishli qatorlarini, serverda `sudo journalctl -u ssh -n 20` dagi sababni yozing. Ruxsatni tuzating. Keyin `ssh -i` ga boshqa (yangi yaratilgan, ro'yxatda yo'q) kalit berib xato matnini solishtiring. Yo'nalish: 4-bo'lim, "Misol: ssh -v ni o'qish" va "Tuzoq: ruxsatlar".

15. **Host key changed.** `net1` da host kalitlarni qayta yarating (`sudo rm /etc/ssh/ssh_host_*`, `sudo ssh-keygen -A`, `sudo systemctl restart ssh`). Host'dan ulanishdagi ogohlantirishni yozing. Real hayotda bu qaysi uch holatni anglatishi mumkin va qaysi birida davom etish xavfli? `ssh-keygen -R` bilan tuzating. Yo'nalish: 4-bo'lim, autentifikatsiyaning 1-qadami.

16. **ProxyJump.** `net2` ga faqat `net1` orqali ulaning: avval `ssh -J net1 net2`, keyin `~/.ssh/config` da `ProxyJump` bilan. `net2` da `ss -tn sport = :22` yoki `who` chiqishida ulanish qaysi IP'dan kelgani ko'rinadi? Agent forwarding'dan farqi va afzalligini yozing. Yo'nalish: 4-bo'lim, "Mijoz konfiguratsiyasi" va agent forwarding haqidagi eslatma.

17. **Local port forward.** `net1` da `python3 -m http.server 8000 --bind 127.0.0.1` ni ishga tushiring. Host'dan `curl http://<net1 IP>:8000/` ishlamasligini ko'rsating, keyin `ssh -N -L` bilan tunnel ochib `curl http://localhost:<port>/` orqali yeting. Bu usul private subnet'dagi ma'lumotlar bazasiga ulanishda qanday qo'llanishini 2–3 gapda yozing. Yo'nalish: 4-bo'lim, "Port forwarding".

18. **Harden sshd.** `net2` da `/etc/ssh/sshd_config.d/` ga o'z drop-in faylingizni yozing: root login yo'q, parol yo'q, faqat `ubuntu` foydalanuvchisi, `MaxAuthTries 3`. `sshd -t` bilan tekshiring, `sshd -T` bilan har sozlamaning amaldagi qiymatini ko'rsating, joriy sessiyani yopmasdan yangi terminaldan sinang. `ssh -o PubkeyAuthentication=no ubuntu@<net2 IP>` va `ssh root@<net2 IP>` natijalarini yozing. Fayl nomi tartibi (`10-...` yoki `99-...`) natijaga qanday ta'sir qilishini bitta tajriba bilan ko'rsating. Faylni `sshd_hardening.conf` nomi bilan papkaga saqlang (`multipass transfer net2:<fayl> .`). Yo'nalish: 4-bo'lim, "sshd ni qattiqlashtirish".

### D. SMTP, HTTP, TLS

19. **SMTP by hand.** Host'da Mailpit'ni ishga tushiring. `nc localhost 1025` orqali qo'lda SMTP dialogini yozib xat yuboring (`EHLO` dan `QUIT` gacha) va serverning har javob kodini izohlang (`localhost` ulanmasa `127.0.0.1` yozing: port faqat IPv4 loopback'ga chiqarilgan). Keyin xuddi shu xatni `mail.txt` faylidan `curl smtp://localhost:1025 --mail-from ... --mail-rcpt ... --upload-file mail.txt` bilan yuboring. Web interfeysda ikkala xatni toping. Envelope'dagi `MAIL FROM` va header'dagi `From:` ni ataylab har xil qilib yuboring: Mailpit nimani ko'rsatadi? Yo'nalish: 5-bo'lim, "Bu nima" dagi dialog va javob kodlari.

20. **Mail DNS audit.** Bitta yirik domen (masalan `github.com`) uchun `MX`, SPF (`TXT`), DMARC (`_dmarc.` da `TXT`) yozuvlarini oling va har birini o'qing: xatni kim qabul qiladi, kim shu domen nomidan yuborishi mumkin, DMARC siyosati qanday. DKIM yozuvini nima uchun selector'ni bilmasdan topib bo'lmaydi? Yo'nalish: 5-bo'lim, "Mexanizm: yetkazish va tekshiruv" va "Misol: SPF yozuvini o'qish".

21. **TLS inspection.** `lab` VM'da `openssl s_client` bilan o'zingiz tanlagan saytning sertifikat zanjirini oling: zanjirdagi har sertifikatning subject va issuer'i, leaf sertifikatning muddati va SAN ro'yxati, kelishilgan TLS versiyasi va ALPN. `curl -v` chiqishidagi mos qatorlarni toping. Keyin `https://expired.badssl.com/`, `https://wrong.host.badssl.com/`, `https://self-signed.badssl.com/` va `https://incomplete-chain.badssl.com/` ga `curl` qilib, har xato matnini TLS tekshiruvining qaysi qadamiga tegishli ekanini yozing. Yo'nalish: 6-bo'lim, "Mexanizm: TLS handshake" va "Misol: sertifikatni o'qish".

### E. Yig'ish

22. **Endpoint probe script.** `probe.sh <host> <port>` skriptini yozing: (1) nomni resolve qiladi va IP'larni chiqaradi; (2) TCP portni 3 soniyalik timeout bilan tekshiradi va "open", "refused" yoki "timeout" ni ajratadi; (3) port 443 bo'lsa sertifikat muddati tugashiga necha kun qolganini chiqaradi; (4) birinchi muvaffaqiyatsiz qadamda mos exit code bilan to'xtaydi. `shellcheck` toza bo'lsin. Kamida to'rt holatda sinang: ishlaydigan HTTPS sayt, mavjud bo'lmagan domen, yopiq port, javob bermaydigan IP. Chiqishlarni README'ga qo'shing. Skript Linux server uchun: faylni ish papkasida yozing, `multipass transfer probe.sh lab:` bilan ko'chirib `lab` VM'da sinang (macOS'dagi BSD `date` va LibreSSL boshqacha ishlaydi). Yo'nalish: "Birga bajaramiz" 5-qadam (qatlam bo'yicha xatolar), 1-bo'lim "nc: qo'lda TCP", 6-bo'lim sertifikat misoli.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa; `ssh_config.example`, `sshd_hardening.conf`, `mail.txt`, `probe.sh` papkada.
2. `make check` toza (`shellcheck` va `make secrets` ham): papkada private kalit, haqiqiy IP'li config yo'q.
3. Mailpit o'chirilgan, `net1` dagi `/etc/hosts` o'zgarishi, `chmod 777` va vaqtinchalik search domeni qaytarilgan, host'da ochiq tunnel, VM'larda qolgan `nc` va `python3` jarayonlari yo'q.
4. `multipass list` da `net1`, `net2` bor (6-dars uchun kerak), `ssh net1` va `ssh net2` ishlaydi.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- TCP ulanishni nima yagona aniqlaydi? Bitta server porti qanday qilib minglab mijozga xizmat qiladi?
- Handshake nima uchun uch qadam va u so'rov kechikishiga qanday ta'sir qiladi?
- `Connection refused` va `Connection timed out` har biri qaysi qatlamdagi muammoni ko'rsatadi?
- `ss` da ko'p `CLOSE-WAIT` va ko'p `SYN-SENT` har biri nimadan dalolat?
- UDP'da port "ochiq" ekanini nima uchun `nc` bilan ishonchli tekshirib bo'lmaydi?
- `app.example.com` birinchi marta so'ralganda so'rov qaysi serverlar orqali o'tadi? Kesh qayerlarda bor?
- `dig` va `getent hosts` nima uchun har xil javob berishi mumkin?
- DNS yozuvini o'zgartirishdan oldin TTL bilan nima qilinadi va nima uchun?
- SSH'da host key va user key har biri kimni kimga isbotlaydi?
- `sshd_config` da bir sozlama ikki faylda har xil yozilgan bo'lsa qaysi biri amal qiladi va buni qanday tekshirasiz?
- SPF, DKIM va DMARC har biri aynan nimani tekshiradi?
- TLS mijozi sertifikatda qaysi uch narsani tekshiradi? Brauzerda ishlab, `curl` da ishlamaydigan sayt nimadan dalolat?
- Bu darsning qaysi qismlari macOS host'ida bajarilmaydi va nima uchun VM'da qilinadi?
