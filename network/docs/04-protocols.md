# 4-dars: Protokollar

Maqsad: DevOps har kuni duch keladigan protokollarni mexanizm darajasida tushunish. Transport qatlami: TCP (handshake, portlar, holatlar, retransmission) va UDP. Ilova qatlami: DNS (yozuv turlari, resolution yo'li, Linux'da resolver sozlamalari), SSH (kalitlar, mijoz konfiguratsiyasi, port forwarding, `sshd` ni qattiqlashtirish), SMTP (pochta yo'li, MX, SPF, DKIM, DMARC), HTTP va TLS (qisqa, chunki mijoz tomoni sizga tanish). 2-darsda bu protokollar qatlamlarga joylashtirilgan edi, endi har birining ichiga kiramiz. Deploy muammolarining katta qismi shu yerda: "port band", "DNS hali yangilanmadi", "SSH kalit qabul qilinmadi", "xatlar spam'ga tushyapti", "sertifikat muddati o'tgan". 6-darsdagi firewall qoidalari port va TCP holatlari tilida yoziladi.

Taxminiy vaqt: 5 kun (siz uchun). 1-kun TCP va UDP (`ss`, `nc`, `tcpdump`). 2-kun DNS. 3-kun SSH. 4-kun SMTP, HTTP, TLS. 5-kun yig'uvchi vazifalar. HTTP semantikasini (metodlar, status kodlar, header'lar) takrorlamaymiz, diqqat ostidagi qatlamlarga: ulanish, TLS handshake, sertifikat zanjiri.

## Laboratoriya

- **Ish mashinasi**: `ss`, `dig`, `curl -v`, `openssl s_client`, `resolvectl status` (faqat o'qish). SSH mijoz tomoni: alohida laboratoriya kaliti (`~/.ssh/lab_ed25519`) va `~/.ssh/config` ga `Host net1`, `Host net2` yozuvlari. Mavjud kalit va yozuvlaringizga tegmang.
- **Multipass VM**: `net1` va `net2` (Ubuntu 24.04). `sshd_config` o'zgarishlari, `/etc/hosts` va resolver tajribalari faqat VM ichida.

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass launch 24.04 --name net2 --cpus 1 --memory 1G --disk 5G
multipass list        # note the IPv4 of each VM
```

`multipass shell` ham ichkarida SSH orqali (`ubuntu` foydalanuvchisi, Multipass'ning o'z kaliti) ulanadi. `sshd` yoki `~/.ssh` ni buzadigan vazifalarda ochiq sessiyani yopmang, undan qaytarasiz. Butunlay qulflanib qolsangiz VM'ni o'chirib qayta yarating: laboratoriyaning afzalligi shu.

- **Docker**: SMTP sinovi uchun Mailpit (xatlarni hech qayerga yubormaydigan test server):

```
docker run -d --name mailpit -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 axllent/mailpit
```

SMTP `localhost:1025` da, web interfeys `http://localhost:8025` da.

- **Tozalash**: `docker rm -f mailpit`; `~/.ssh/config` dan laboratoriya yozuvlarini va `~/.ssh/lab_ed25519*` ni o'chirish; VM'lar 5 va 6-darslarda kerak, `multipass stop net1 net2`.

---

## 1. TCP

**TCP (Transmission Control Protocol)** ikki jarayon orasida ishonchli, tartiblangan bayt oqimi beradi. IP paketlar yo'qolishi, takrorlanishi, tartibsiz kelishi mumkin; TCP buni yashiradi. Ilova faqat "yozdim" va "o'qidim" ni ko'radi.

### Portlar va ulanish identifikatori

Port 16 bitli son (0–65535), host ichida qaysi jarayonga yetkazishni aniqlaydi.

| Diapazon | Nomi | Izoh |
|----------|------|------|
| 0–1023 | well-known | bog'lash (bind) uchun root yoki `CAP_NET_BIND_SERVICE` kerak: 22 SSH, 25 SMTP, 53 DNS, 80 HTTP, 443 HTTPS |
| 1024–49151 | registered | 3306 MySQL, 5432 PostgreSQL, 6379 Redis, 8080 |
| 32768–60999 (Linux) | ephemeral | mijoz tomoni uchun kernel tanlaydi: `cat /proc/sys/net/ipv4/ip_local_port_range` |

Ulanish to'rtlik bilan aniqlanadi: `(src IP, src port, dst IP, dst port)`. Shuning uchun bitta server 443-portda minglab ulanishni ushlaydi: har birining mijoz IP yoki porti boshqa. Port nomlari ro'yxati: `/etc/services`.

### Three-way handshake

```
client                         server (LISTEN)
  | ---- SYN, seq=x ----------> |
  | <--- SYN-ACK, seq=y, ack=x+1 |
  | ---- ACK, ack=y+1 --------> |
  |        ESTABLISHED           |
```

Uch qadam nima uchun: har tomon o'z boshlang'ich sequence raqamini e'lon qiladi va ikkinchi tomon uni tasdiqlaydi. Handshake'da MSS, window scaling, SACK kabi opsiyalar ham kelishiladi. Bitta round trip (RTT) vaqt oladi, TLS undan keyin yana qo'shadi: uzoq serverga yangi ulanish shuning uchun qimmat va connection pool, keep-alive shuning uchun kerak.

Yopilish: har tomon o'z yo'nalishini `FIN` bilan yopadi, ikkinchisi `ACK` beradi (odatda to'rt paket). `RST` esa darhol uzish: port yopiq, jarayon o'ldi, yoki firewall `reject` qildi.

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

`ss -tlnp` dagi `Local Address:Port` ustunini o'qish: `127.0.0.1:5432` faqat lokal, `0.0.0.0:80` barcha IPv4 interfeyslar, `[::]:22` barcha IPv6 (va odatda IPv4 ham), `*:8080` ikkalasi.

**Tuzoq: `Address already in use`.** Portni boshqa jarayon tinglayapti: `sudo ss -tlnp 'sport = :8080'` egasini ko'rsatadi. Ikkinchi sabab: server endigina to'xtatilgan va eski ulanishlar `TIME-WAIT` da. Serverlar buning uchun `SO_REUSEADDR` qo'yadi.

### Ishonchlilik: ACK, retransmission, oqim nazorati

- Har bayt raqamlangan (sequence number). Qabul qiluvchi "shu raqamgacha oldim" deb ACK beradi.
- ACK **RTO** (retransmission timeout, RTT asosida hisoblanadi) ichida kelmasa segment qayta yuboriladi, har urinishda kutish ikki barobar oshadi (exponential backoff).
- Uchta takroriy ACK kelsa RTO'ni kutmasdan qayta yuboriladi (fast retransmit).
- **Flow control**: qabul qiluvchi `window` maydonida bufer'ida qancha joy borligini aytadi. Ilova o'qimasa window nolga tushadi va yuboruvchi to'xtaydi.
- **Congestion control**: yuboruvchi tarmoq sig'imini o'zi baholaydi, yo'qotish bo'lsa tezlikni kamaytiradi. Linux'da sukut bo'yicha `cubic` (`sysctl net.ipv4.tcp_congestion_control`).

Yangi ulanishda SYN'ga javob kelmasa kernel uni `net.ipv4.tcp_syn_retries` marta (sukut bo'yicha 6) qayta yuboradi: 1, 2, 4, 8, 16, 32 soniya oraliq bilan, jami ikki daqiqadan ortiq. `Connection timed out` shuncha kechikib chiqadi.

**Tuzoq: timeout qo'yilmagan mijoz.** Firewall paketni jim tashlasa (`drop`), timeout'siz HTTP mijoz yoki DB driver ikki daqiqa osilib turadi va shu vaqt ichida thread yoki connection pool tugaydi. Har tashqi chaqiruvda connect va read timeout aniq qo'yiladi. `curl` da: `--connect-timeout 5 --max-time 20`.

**Tuzoq: bo'sh turgan ulanishni o'rtadagi qurilma unutadi.** NAT va load balancer'lar ulanish holatini cheklangan vaqt saqlaydi (cloud load balancer'larda idle timeout odatda bir necha daqiqa). Bo'sh turgan DB ulanishi keyingi so'rovda `connection reset` beradi. Yechim: TCP keepalive yoki ilova darajasidagi ping, pool'da ulanish umrini cheklash.

### nc: qo'lda TCP

```
nc -l 9000                 # listen on TCP 9000 (OpenBSD netcat, default on Ubuntu)
nc 127.0.0.1 9000          # connect; stdin goes to the peer
nc -vz 10.0.0.5 22         # port check without sending data
nc -vz -w 3 10.0.0.5 5432  # with a 3 second timeout
nc -u -l 9001              # UDP listener
```

## 2. UDP

**UDP (User Datagram Protocol)**: header 8 bayt, handshake yo'q, tasdiq yo'q, tartib kafolati yo'q, qayta yuborish yo'q. Har datagram mustaqil. Ishonchlilik kerak bo'lsa ilova o'zi qiladi.

| Xususiyat | TCP | UDP |
|-----------|-----|-----|
| Ulanish | bor (handshake) | yo'q |
| Yetkazish kafolati, tartib | bor | yo'q |
| Birlik | bayt oqimi | alohida datagram |
| Qo'shimcha kechikish | 1 RTT + qayta yuborishlar | yo'q |
| Qayerda | HTTP/1.1, HTTP/2, SSH, SMTP, ma'lumotlar bazalari | DNS, DHCP, NTP, QUIC (HTTP/3), WireGuard, VoIP |

**Tuzoq: UDP portni `nc -vz -u` bilan tekshirish.** UDP'da "ulanish" yo'q, shuning uchun "ochiq" va "paket tashlandi" ni ajratib bo'lmaydi: javob kelmasligi ikkala holatda ham bir xil. Yopiq port ICMP "port unreachable" qaytarishi mumkin, lekin firewall uni ham tashlaydi. UDP servisni faqat protokolning o'z so'rovi bilan tekshiring (`dig @server`, `wg show`).

## 3. DNS

**DNS (Domain Name System)** nomlarni yozuvlarga aylantiradigan taqsimlangan, ierarxik ma'lumotlar bazasi. Odatda UDP 53; javob katta bo'lsa yoki zone transfer'da TCP 53.

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

**Tuzoq: CNAME boshqa yozuvlar bilan birga yashamaydi.** Nomda `CNAME` bo'lsa, o'sha nomda boshqa tur yozuv bo'lishi mumkin emas. Zona apex'ida (`example.com.`) doim `SOA` va `NS` bor, demak u yerga `CNAME` qo'yib bo'lmaydi. Provayderlar buni `ALIAS`/`ANAME` yoki "CNAME flattening" bilan aylanib o'tadi.

### Resolution yo'li

```
app  ->  stub resolver  ->  recursive resolver  ->  root (.)        "ask .com servers"
        (libc, systemd-     (ISP, 1.1.1.1,      ->  TLD (.com)      "ask example.com NS"
         resolved)           8.8.8.8, VPC DNS)   ->  authoritative   "A 203.0.113.10"
```

1. Ilova `getaddrinfo()` chaqiradi. libc `/etc/nsswitch.conf` dagi `hosts:` qatoriga qaraydi: odatda avval `files` (`/etc/hosts`), keyin DNS.
2. Stub resolver so'rovni `/etc/resolv.conf` dagi `nameserver` ga yuboradi.
3. Recursive resolver kesh'da bo'lmasa ierarxiya bo'ylab yuradi: root, TLD, authoritative. Javobni **TTL** soniya davomida kesh'laydi.

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

Ubuntu'da `/etc/resolv.conf` odatda `/run/systemd/resolve/stub-resolv.conf` ga symlink va ichida `nameserver 127.0.0.53`: bu systemd-resolved'ning lokal stub'i. Haqiqiy upstream serverlarni `resolvectl status` ko'rsatadi. Faylni qo'lda tahrirlash foydasiz, u qayta yoziladi.

**Tuzoq: `dig` ishladi, ilova ishlamadi (yoki aksincha).** `dig` va `nslookup` to'g'ridan-to'g'ri DNS serverga boradi: `/etc/hosts` va `nsswitch.conf` ni o'qimaydi, `search` domenlarini sukut bo'yicha qo'llamaydi. Ilova nimani ko'rishini `getent hosts` ko'rsatadi.

`ndots:N`: nomda nuqtalar soni N dan kam bo'lsa, avval `search` domenlari qo'shib sinab ko'riladi. Kubernetes pod'larida `ndots:5`: `api.example.com` uchun bir necha keraksiz so'rov ketadi. Nom oxiriga nuqta qo'yish (`api.example.com.`) uni to'liq (FQDN) deb belgilaydi.

### dig

```
dig example.com                    # full answer: header, QUESTION, ANSWER, query time, SERVER
dig +short example.com AAAA        # just the value
dig example.com MX +noall +answer  # only the ANSWER section
dig @1.1.1.1 example.com           # ask a specific resolver
dig +trace example.com             # walk from the root yourself
dig -x 1.1.1.1                     # reverse lookup (PTR)
dig example.com NS +short          # authoritative servers
```

Header'dagi `status`: `NOERROR` (nom bor; ANSWER bo'sh bo'lsa shu turdagi yozuv yo'q), `NXDOMAIN` (nom yo'q), `SERVFAIL` (resolver javob ololmadi: authoritative ishlamayapti yoki DNSSEC xatosi), `REFUSED`. `flags` dagi `aa` javob authoritative serverning o'zidan kelganini bildiradi. Tashxisda asosiy usul: recursive resolver javobini (`dig @1.1.1.1`) authoritative javobi (`dig @<NS nomi>`) bilan solishtirish. Farq bo'lsa bu kesh.

## 4. SSH

**SSH (Secure Shell)**: TCP 22 ustida shifrlangan kanal. Masofaviy shell, fayl uzatish (`scp`, `sftp`, `rsync`), port forwarding, git transport, Ansible transporti.

### Ikki tomonlama autentifikatsiya

1. **Server o'zini isbotlaydi** (host key). Birinchi ulanishda mijoz fingerprint'ni ko'rsatadi va `~/.ssh/known_hosts` ga yozadi (TOFU, trust on first use). Keyin kalit o'zgarsa `REMOTE HOST IDENTIFICATION HAS CHANGED` xatosi chiqadi: server qayta o'rnatilgan, IP boshqa hostga o'tgan, yoki o'rtada kimdir bor. Sababini bilsangiz eski yozuv `ssh-keygen -R <host>` bilan o'chiriladi.
2. **Foydalanuvchi o'zini isbotlaydi**. Public key usuli: serverda `~/.ssh/authorized_keys` da public kalit turadi, mijoz private kalit bilan imzo qo'yib egaligini isbotlaydi. Private kalit tarmoqqa chiqmaydi.

```
ssh-keygen -t ed25519 -C "lab key" -f ~/.ssh/lab_ed25519
ssh-copy-id -i ~/.ssh/lab_ed25519.pub user@host   # needs password login to be enabled
ssh -i ~/.ssh/lab_ed25519 user@host
ssh -v user@host                                  # debug: which keys are offered, why rejected
```

- Private kalitga passphrase qo'yiladi, qayta-qayta termaslik uchun `ssh-agent` (`ssh-add ~/.ssh/lab_ed25519`).
- **Tuzoq: ruxsatlar.** `sshd` sukut bo'yicha (`StrictModes yes`) egasidan boshqa yoza oladigan `~`, `~/.ssh` yoki `authorized_keys` ni rad etadi va kalit jimgina qabul qilinmaydi. To'g'ri holat: `~/.ssh` 700, `authorized_keys` 600, private kalit 600. Sabab serverda `journalctl -u ssh` da ko'rinadi, mijozda emas.

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

`ssh net1` endi barcha parametrlarni shu yerdan oladi; `scp`, `rsync`, `git`, Ansible ham shu faylni ishlatadi. `IdentitiesOnly yes` agent'dagi barcha kalitlarni ketma-ket taklif qilishni to'xtatadi (`Too many authentication failures` ning sababi). `ProxyJump` (buyruqda `-J`) ichki hostga bastion orqali ulanadi: shifrlash oxirgi hostgacha, bastion faqat TCP'ni uzatadi.

### Port forwarding

| Tur | Buyruq | Nima qiladi |
|-----|--------|-------------|
| Local | `ssh -L 8080:127.0.0.1:80 net1` | mening `localhost:8080` im, `net1` nuqtai nazaridan `127.0.0.1:80` ga |
| Remote | `ssh -R 9000:127.0.0.1:3000 net1` | `net1` dagi `localhost:9000`, mening `localhost:3000` imga |
| Dynamic | `ssh -D 1080 net1` | menda SOCKS proxy, trafik `net1` dan chiqadi |

`-N` shell ochmasdan faqat tunnel. Local forward'ning tipik ishi: faqat `127.0.0.1` da tinglayotgan yoki private subnet'dagi ma'lumotlar bazasiga vaqtincha ulanish, portni internetga ochmasdan.

### sshd ni qattiqlashtirish

Server sozlamasi `/etc/ssh/sshd_config` va `/etc/ssh/sshd_config.d/*.conf`. Minimal to'plam:

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

## 5. SMTP va pochta DNS yozuvlari

**SMTP (Simple Mail Transfer Protocol)** xatni serverdan serverga yetkazadi. Matnli protokol:

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

`MAIL FROM` (envelope sender) va xat ichidagi `From:` header alohida narsalar va bir-biriga mos kelishi shart emas. Spoofing shunga asoslanadi, quyidagi uch mexanizm shuni yopadi.

| Port | Vazifa |
|------|--------|
| 25 | serverdan serverga (MTA). Cloud provayderlar chiquvchi 25-portni odatda bloklaydi |
| 587 | submission: ilova yoki pochta mijozi o'z provayderiga, STARTTLS va autentifikatsiya bilan |
| 465 | submission, boshidan TLS |

Yetkazish yo'li: yuboruvchi server qabul qiluvchi domenning `MX` yozuvlarini so'raydi, prioriteti eng kichik (eng afzal) serverga 25-portda ulanadi.

| Mexanizm | DNS yozuvi | Nimani tekshiradi |
|----------|-----------|-------------------|
| SPF | domenda `TXT`: `v=spf1 include:_spf.example.net ip4:203.0.113.0/24 -all` | ulangan IP shu domen (envelope sender) nomidan yuborishga ruxsatlimi |
| DKIM | `<selector>._domainkey.example.com` da `TXT` (public kalit) | xatdagi `DKIM-Signature` imzosi: header va tana yo'lda o'zgarmagan, imzolovchi domen kalit egasi |
| DMARC | `_dmarc.example.com` da `TXT`: `v=DMARC1; p=quarantine; rua=mailto:...` | SPF yoki DKIM o'tgan domen `From:` dagi domenga mos keladimi (alignment); o'tmasa nima qilish (`none`, `quarantine`, `reject`) va hisobot qayerga |

DevOps amaliyoti: ilova xatlari (parol tiklash, bildirishnoma) odatda o'z serveringizdan emas, tranzaksion pochta xizmati (Amazon SES, Postmark va shu kabi) orqali 587-portda yuboriladi. Sizning ishingiz: domenga SPF `include`, DKIM `CNAME`/`TXT` va DMARC yozuvlarini to'g'ri qo'yish. O'z serveringizdan yuborsangiz IP'ning `PTR` yozuvi ham kerak.

**Tuzoq: bir domenda ikkita SPF yozuvi.** `v=spf1` bilan boshlanadigan `TXT` faqat bitta bo'lishi kerak; ikkinchi xizmat qo'shilsa mavjud yozuvga `include:` qo'shiladi, yangi yozuv yaratilmaydi. Ikkitasi bo'lsa SPF xato (`permerror`) beradi.

## 6. HTTP va TLS: ostidagi qatlam

HTTP semantikasi sizga tanish. Ops nuqtai nazaridan transport:

| Versiya | Transport | Xususiyat |
|---------|-----------|-----------|
| HTTP/1.1 | TCP | bir ulanishda bir vaqtda bitta so'rov, brauzer hostga bir nechta ulanish ochadi |
| HTTP/2 | TCP + TLS | bitta ulanishda ko'p oqim (multiplexing); bitta yo'qolgan TCP segment hamma oqimni to'xtatadi |
| HTTP/3 | QUIC (UDP 443) | oqimlar mustaqil, handshake tezroq; firewall'da UDP 443 ochiq bo'lishi kerak |

TLS TCP handshake'dan keyin bajariladi (TLS 1.3 da bir RTT):

1. **ClientHello**: qo'llab-quvvatlanadigan versiya va shifrlar, **SNI** (qaysi host nomi so'ralmoqda, ochiq matnda), **ALPN** (`h2`, `http/1.1`).
2. **ServerHello + Certificate**: server sertifikat zanjirini yuboradi (leaf va intermediate).
3. Mijoz tekshiradi: zanjir ishonchli root CA gacha boradimi, muddat (`notBefore`, `notAfter`), nom sertifikatning SAN (Subject Alternative Name) ro'yxatida bormi.

```
curl -v https://example.com/ -o /dev/null
curl -sv --resolve example.com:443:203.0.113.10 https://example.com/   # bypass DNS, keep SNI and Host
openssl s_client -connect example.com:443 -servername example.com </dev/null
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

**Tuzoq: intermediate sertifikat serverda yo'q.** Server faqat leaf sertifikatni yuborsa, brauzer ko'pincha ishlaydi (intermediate'ni kesh'dan oladi yoki o'zi yuklab oladi), `curl`, Node, Go va Python mijozlari esa `unable to get local issuer certificate` beradi. `openssl s_client` chiqishidagi `Certificate chain` bo'limida zanjir to'liqligini tekshiring.

**Tuzoq: `-servername` siz tekshirish.** Bitta IP'da ko'p sayt bo'lsa, server SNI bo'yicha sertifikat tanlaydi. Eski `openssl` versiyalari SNI yubormaydi va siz default sertifikatni ko'rib noto'g'ri xulosa qilasiz. Doim `-servername` yozing.

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

## Manbalar

- https://www.rfc-editor.org/rfc/rfc9293 – TCP (zamonaviy spetsifikatsiya)
- https://man7.org/linux/man-pages/man8/ss.8.html – `ss`
- https://man7.org/linux/man-pages/man7/tcp.7.html – Linux TCP sysctl'lari
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
- Stevens, Fall, "TCP/IP Illustrated, Volume 1" (2-nashr), 12–17-boblar (TCP)

---

## Vazifalar

Ish papkasi: `network/04-protocols/` (`make new m=network n=04 name=protocols`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`ssh_config.example`, `sshd_hardening.conf`, `mail.txt`, `probe.sh`) shu papkaga saqlang. Private kalit va haqiqiy `~/.ssh/config` papkaga ko'chirilmaydi.

### A. TCP va UDP

1. **Listening sockets.** Ish mashinasida `sudo ss -tlnp` va `sudo ss -ulnp` chiqishini jadvalga aylantiring: port, tinglash manzili, jarayon, tarmoqdan yetib bo'ladimi yoki faqat lokal. Kutilmagan ochiq port bormi?

2. **Handshake by hand.** `net1` da `nc -l 9000`, `net2` dan `nc <net1 IP> 9000` bilan ulanib matn almashing. Uchinchi sessiyada `net1` da `sudo tcpdump -i any -nn tcp port 9000` bilan handshake, ma'lumot va yopilish paketlarini ushlang. Ulanish ochiq paytda ikkala VM'da `ss -tan | grep 9000` chiqishini yozing va to'rtlikni (IP va portlar) ko'rsating. Mijoz porti qaysi diapazondan?

3. **TCP states.** 2-vazifadagi ulanishda mijozni `Ctrl+C` bilan yoping va darhol ikkala tomonda `ss -tan | grep 9000` ni ko'ring. Qaysi tomonda `TIME-WAIT` paydo bo'ldi va nima uchun aynan o'sha tomonda? Qancha vaqtdan keyin yo'qoladi?

4. **Refused, timeout, reset.** Uch holatni yarating va har birida mijoz xato matni hamda tcpdump'dagi paketlarni yozing: (a) tinglovchisiz portga ulanish; (b) `ss -ti` bilan kuzatib turib, hech qachon javob bermaydigan manzilga (`nc -v 10.255.255.1 80`) ulanish: `SYN-SENT` holati va `rto` qiymati qanday o'zgaradi; (c) ochiq ulanish paytida server jarayonini `kill -9` qilish va mijozdan yana yozish.

5. **Address in use.** `net1` da bitta portda ikki marta `nc -l 9000` ishga tushiring. Xato matnini yozing va port egasini `ss` filtri bilan toping. 80-portda oddiy foydalanuvchi sifatida tinglashga urinib ko'ring (`nc -l 80`): xato nima va `sysctl net.ipv4.ip_unprivileged_port_start` qiymati buni qanday tushuntiradi?

6. **UDP is different.** `net1` da `nc -u -l 9001`, `net2` dan `nc -u <net1 IP> 9001`. Tcpdump'da handshake bormi? Server'ni to'xtatib mijozdan yana yuboring: mijoz xato ko'radimi, tcpdump'da qanday ICMP paket ko'rindi? Bundan "UDP portni tekshirish" haqida xulosa chiqaring.

### B. DNS

7. **Record types.** O'zingiz tanlagan real domen (masalan `github.com`) uchun `A`, `AAAA`, `MX`, `NS`, `TXT`, `SOA`, `CAA` yozuvlarini `dig +noall +answer` bilan oling. Har yozuvning TTL'i va ma'nosini yozing. `www` nomi `CNAME` mi yoki `A`?

8. **Trace the hierarchy.** `dig +trace` chiqishini bosqichlarga bo'ling: root serverlar, TLD serverlar, authoritative serverlar. Har bosqichda kim kimga yo'naltirdi? Oxirgi javobni `dig @<authoritative NS>` bilan to'g'ridan-to'g'ri oling va `flags` dagi `aa` ni recursive resolver javobi bilan solishtiring.

9. **Caching and TTL.** Bir nomni `dig` bilan ketma-ket uch marta, 5 soniya oraliq bilan so'rang: TTL va `Query time` qanday o'zgaradi? Xuddi shuni `@1.1.1.1` va `@8.8.8.8` da takrorlang. Mavjud bo'lmagan nom uchun `status` va AUTHORITY bo'limidagi `SOA` ni toping: negative javob qancha vaqt kesh'lanadi?

10. **Resolver config.** Ish mashinasida `ls -l /etc/resolv.conf`, uning mazmuni, `resolvectl status` va `grep hosts /etc/nsswitch.conf` chiqishini izohlang: `127.0.0.53` nima, haqiqiy upstream DNS kim va u qayerdan kelgan (3-darsdagi DHCP)?

11. **hosts vs DNS.** `net1` da `/etc/hosts` ga `203.0.113.99 example.com` qatorini qo'shing. `getent hosts example.com`, `dig +short example.com`, `ping -c 1 example.com` va `curl -sv --connect-timeout 3 http://example.com/` natijalarini solishtiring. Nima uchun farq qiladi? Qatorni o'chiring.

12. **Search and ndots.** `net1` da `resolvectl status` dan search domenlarini toping. `sudo tcpdump -i any -nn udp port 53` ishlab turganda `getent hosts web`, `getent hosts web.internal` va `getent hosts web.internal.` ni bajaring. Har biri uchun qanday nomlar so'raldi? Kubernetes'dagi `ndots:5` nima uchun tashqi domenlar uchun ortiqcha so'rov tug'dirishini shu kuzatuv bilan tushuntiring.

### C. SSH

13. **Key-based login.** Ish mashinasida `~/.ssh/lab_ed25519` kalitini passphrase bilan yarating. Public kalitni `net1` va `net2` dagi `ubuntu` foydalanuvchisining `authorized_keys` iga qo'shing (`multipass exec` orqali). `~/.ssh/config` ga ikkala host uchun yozuv qo'shing, shunda `ssh net1` qo'shimcha flag'siz ishlasin. Birinchi ulanishdagi fingerprint savolini va `known_hosts` da paydo bo'lgan qatorni izohlang. Yozuvlarni (real IP'siz) `ssh_config.example` ga saqlang.

14. **Debug a rejected key.** `net1` da ochiq sessiyani yopmasdan (u orqali qaytarasiz) `chmod 777 ~/.ssh` qiling va ish mashinasidan qaytadan ulanishga urining. Mijozda `ssh -v` chiqishining tegishli qatorlarini, serverda `sudo journalctl -u ssh -n 20` dagi sababni yozing. Ruxsatni tuzating. Keyin `ssh -i` ga boshqa (yangi yaratilgan, ro'yxatda yo'q) kalit berib xato matnini solishtiring.

15. **Host key changed.** `net1` da host kalitlarni qayta yarating (`sudo rm /etc/ssh/ssh_host_*`, `sudo ssh-keygen -A`, `sudo systemctl restart ssh`). Ish mashinasidan ulanishdagi ogohlantirishni yozing. Real hayotda bu qaysi uch holatni anglatishi mumkin va qaysi birida davom etish xavfli? `ssh-keygen -R` bilan tuzating.

16. **ProxyJump.** `net2` ga faqat `net1` orqali ulaning: avval `ssh -J net1 net2`, keyin `~/.ssh/config` da `ProxyJump` bilan. `net2` da `ss -tn sport = :22` yoki `who` chiqishida ulanish qaysi IP'dan kelgani ko'rinadi? Agent forwarding'dan farqi va afzalligini yozing.

17. **Local port forward.** `net1` da `python3 -m http.server 8000 --bind 127.0.0.1` ni ishga tushiring. Ish mashinasidan `curl http://<net1 IP>:8000/` ishlamasligini ko'rsating, keyin `ssh -N -L` bilan tunnel ochib `curl http://localhost:<port>/` orqali yeting. Bu usul private subnet'dagi ma'lumotlar bazasiga ulanishda qanday qo'llanishini 2–3 gapda yozing.

18. **Harden sshd.** `net2` da `/etc/ssh/sshd_config.d/` ga o'z drop-in faylingizni yozing: root login yo'q, parol yo'q, faqat `ubuntu` foydalanuvchisi, `MaxAuthTries 3`. `sshd -t` bilan tekshiring, `sshd -T` bilan har sozlamaning amaldagi qiymatini ko'rsating, joriy sessiyani yopmasdan yangi terminaldan sinang. `ssh -o PubkeyAuthentication=no ubuntu@<net2 IP>` va `ssh root@<net2 IP>` natijalarini yozing. Fayl nomi tartibi (`10-...` yoki `99-...`) natijaga qanday ta'sir qilishini bitta tajriba bilan ko'rsating. Faylni `sshd_hardening.conf` nomi bilan papkaga saqlang.

### D. SMTP, HTTP, TLS

19. **SMTP by hand.** Mailpit'ni ishga tushiring. `nc localhost 1025` orqali qo'lda SMTP dialogini yozib xat yuboring (`EHLO` dan `QUIT` gacha) va serverning har javob kodini izohlang. Keyin xuddi shu xatni `mail.txt` faylidan `curl smtp://localhost:1025 --mail-from ... --mail-rcpt ... --upload-file mail.txt` bilan yuboring. Web interfeysda ikkala xatni toping. Envelope'dagi `MAIL FROM` va header'dagi `From:` ni ataylab har xil qilib yuboring: Mailpit nimani ko'rsatadi?

20. **Mail DNS audit.** Bitta yirik domen (masalan `github.com`) uchun `MX`, SPF (`TXT`), DMARC (`_dmarc.` da `TXT`) yozuvlarini oling va har birini o'qing: xatni kim qabul qiladi, kim shu domen nomidan yuborishi mumkin, DMARC siyosati qanday. DKIM yozuvini nima uchun selector'ni bilmasdan topib bo'lmaydi?

21. **TLS inspection.** `openssl s_client` bilan o'zingiz tanlagan saytning sertifikat zanjirini oling: zanjirdagi har sertifikatning subject va issuer'i, leaf sertifikatning muddati va SAN ro'yxati, kelishilgan TLS versiyasi va ALPN. `curl -v` chiqishidagi mos qatorlarni toping. Keyin `https://expired.badssl.com/`, `https://wrong.host.badssl.com/`, `https://self-signed.badssl.com/` va `https://incomplete-chain.badssl.com/` ga `curl` qilib, har xato matnini TLS tekshiruvining qaysi qadamiga tegishli ekanini yozing.

### E. Yig'ish

22. **Endpoint probe script.** `probe.sh <host> <port>` skriptini yozing: (1) nomni resolve qiladi va IP'larni chiqaradi; (2) TCP portni 3 soniyalik timeout bilan tekshiradi va "open", "refused" yoki "timeout" ni ajratadi; (3) port 443 bo'lsa sertifikat muddati tugashiga necha kun qolganini chiqaradi; (4) birinchi muvaffaqiyatsiz qadamda mos exit code bilan to'xtaydi. `shellcheck` toza bo'lsin. Kamida to'rt holatda sinang: ishlaydigan HTTPS sayt, mavjud bo'lmagan domen, yopiq port, javob bermaydigan IP. Chiqishlarni README'ga qo'shing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa; `ssh_config.example`, `sshd_hardening.conf`, `mail.txt`, `probe.sh` papkada.
2. `make check` toza (`shellcheck` va `make secrets` ham): papkada private kalit, haqiqiy IP'li config yo'q.
3. Mailpit o'chirilgan, `net1` dagi `/etc/hosts` o'zgarishi va `chmod 777` qaytarilgan, ish mashinasida ochiq tunnel va `nc` jarayonlari yo'q.
4. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- TCP ulanishni nima yagona aniqlaydi? Bitta server porti qanday qilib minglab mijozga xizmat qiladi?
- Handshake nima uchun uch qadam va u so'rov kechikishiga qanday ta'sir qiladi?
- `ss` da ko'p `CLOSE-WAIT` va ko'p `SYN-SENT` har biri nimadan dalolat?
- UDP'da port "ochiq" ekanini nima uchun `nc` bilan ishonchli tekshirib bo'lmaydi?
- `app.example.com` birinchi marta so'ralganda so'rov qaysi serverlar orqali o'tadi? Kesh qayerlarda bor?
- `dig` va `getent hosts` nima uchun har xil javob berishi mumkin?
- DNS yozuvini o'zgartirishdan oldin TTL bilan nima qilinadi va nima uchun?
- SSH'da host key va user key har biri kimni kimga isbotlaydi?
- `sshd_config` da bir sozlama ikki faylda har xil yozilgan bo'lsa qaysi biri amal qiladi va buni qanday tekshirasiz?
- SPF, DKIM va DMARC har biri aynan nimani tekshiradi?
