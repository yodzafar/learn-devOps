# Kompyuter tarmoqlari o'quv rejasi (DevOps uchun)

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. Tarmoq bo'yicha boshlang'ich bilim "brauzer HTTP so'rov yuboradi" darajasida deb olinadi: MAC, IP, port, TCP, DNS, routing va firewall noldan, mexanizmi va ishlaydigan misoli bilan tushuntiriladi. Oldindan bilish talab qilinadigan narsa faqat terminalda ishlash (`linux` moduli) va `SETUP.md` bo'yicha tayyor laboratoriya.

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni bajarib natija va izohni `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `network/01-network-types/`, `network/02-osi-model/` va hokazo. Yaratish: `make new m=network n=01 name=network-types`.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har darsning muddati o'sha darsning `Taxminiy vaqt` qatorida, bu jadval ularning yig'indisi. Hafta 5 o'quv kuni deb olinadi.

| Bosqich | Darslar | Dars bo'yicha (kun) | Siz uchun | Sabab |
|---------|---------|---------------------|-----------|-------|
| I - Asos: qurilmalar, qatlamlar, manzillar | 3 | 1-dars: 3, 2-dars: 3, 3-dars: 5 | 11 kun | HTTP'dan pastdagi hamma qatlam yangi: frame, MAC, ARP, paket, port. Subnet hisobi qo'lda mashq talab qiladi, qisqartirilmaydi |
| II - Protokollar | 1 | 4-dars: 8 | 8 kun | Bitta darsda oltita protokol (TCP, UDP, DNS, SSH, SMTP, HTTP/TLS). HTTP'ning brauzer tomoni tanish bo'lsa ham, server va tarmoq tomoni noldan o'tiladi |
| III - Paket yo'li: routing, firewall, NAT, VPN | 2 | 5-dars: 5, 6-dars: 8 | 13 kun | Butunlay yangi soha, namespace, firewall va ikki VM'li laboratoriya vaqt oladi |
| **Jami** | **6** | | **32 kun (6 hafta va 2 kun)** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz "paket A dan B ga qanday yetib boradi" savoliga shu dars qatlamida o'z so'zingiz bilan javob bera olasiz.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS (Linux, `amd64`), uyda macOS (Apple Silicon, `arm64`). Har dars ikkalasida bir xil bajariladi. Asboblarni o'rnatish va `lab` VM'ni yaratish `SETUP.md` da (Multipass: Zorin'da snap, macOS'da Homebrew); darslar ularni qayta o'rnatmaydi. macOS'da `ip`, `ss`, `bridge`, `nft` yo'q, Zorin'da esa host tarmog'ini buzish xavfi bor, shuning uchun Linux tarmoq buyruqlari host'da emas, VM yoki konteynerda bajariladi. Har dars "Laboratoriya" bo'limida qaysi muhit ekanini va "Zorin (ofis) / macOS (uy)" farqlarini aytadi.

| Muhit | Nima uchun | Qoidasi |
|-------|-----------|---------|
| Host (Zorin yoki macOS) | `make`, `git`, `multipass`, `docker` buyruqlari; ixtiyoriy kuzatuv (Zorin: `ip -br addr`, macOS: `ifconfig`, `arp -a`, `netstat -rn`, `networksetup`) | hech narsa o'zgartirilmaydi: interfeys, route, firewall, sysctl'ga tegilmaydi |
| `lab` VM (Multipass, Ubuntu 24.04, `SETUP.md`) | barcha `ip`, `bridge`, `ss`, `tcpdump` kuzatuvlari, `ip netns`, VM ichidagi Docker (1-dars) | buzilsa `multipass restore lab.clean`; interfeys nomi va manzillar har mashinada boshqa, doim o'zingiz aniqlaysiz |
| Docker konteyner (`nicolaka/netshoot`, `amd64` va `arm64`) | tayyor tarmoq asboblari to'plami: `tcpdump`, `dig`, `nc`, `mtr`, `nmap` | `docker run --rm`, dars oxirida konteyner va tarmoqlar o'chiriladi |
| Multipass VM `net1`, `net2` (Ubuntu 24.04) | ikki alohida host kerak bo'lgan va holatni o'zgartiradigan ishlar (4 va 6-darslar): `nft`, `ufw`, `sshd_config`, WireGuard | modul oxirida `multipass delete net1 net2 && multipass purge` |

VM'ning tarmog'i host'ga qarab farq qiladi: Zorin'da VM interfeysi odatda `ens3`, manzil `10.x.x.x/24`, host tomonda `mpqemubr0`; macOS'da odatda `enp0s1`, `192.168.64.x/24`, host tomonda `bridge100`. Darslar bu qiymatlarga tayanmaydi. macOS'da host'dagi Docker yashirin Linux VM ichida ishlaydi: uning bridge, veth va NAT qoidalari host'da ko'rinmaydi, shuning uchun ularni ko'rish kerak bo'lgan darslarda Docker `lab` VM ichida ishlatiladi.

Qo'shimcha ikki VM kerak bo'lgan darsda (ikkala mashinada bir xil) shunday yaratiladi:

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass launch 24.04 --name net2 --cpus 1 --memory 1G --disk 5G
multipass list
multipass shell net1
```

Network namespace (`ip netns`) bitta VM ichida bir nechta "virtual host" va router yaratish imkonini beradi, shuning uchun 5-darsdagi routing laboratoriyasi bitta VM'da bajariladi. Ikki VM faqat SSH (4-dars) va WireGuard (6-dars) uchun kerak. Laboratoriya holati mashinalar orasida ko'chmaydi: ikkinchi mashinada VM'lar qaytadan yaratiladi, javoblar git orqali ko'chadi. Wireshark ixtiyoriy (Zorin: `sudo apt install wireshark`, macOS: `brew install --cask wireshark`), asosiy yo'l `tcpdump`.

## I bosqich - Asos
1. **Tarmoq turlari**: LAN, WAN, internet tuzilishi (ISP, IXP), NIC, switch, router, access point, MAC manzil, Ethernet frame, MTU, Linux interfeyslari (`ip link`, `ip addr`), ARP va `ip neigh`, Docker bridge va veth
2. **OSI modeli**: 7 qatlam, TCP/IP 4 qatlam, encapsulation, PDU nomlari, qaysi asbob va qaysi muammo qaysi qatlamda, bitta HTTP so'rovni qatlamlar bo'ylab kuzatish, `tcpdump` va Wireshark asoslari, MTU va fragmentatsiya
3. **IP manzillar**: IPv4 va IPv6, CIDR, subnet mask hisobi qo'lda, network va broadcast manzil, private diapazonlar (RFC 1918), maxsus diapazonlar (loopback, link-local, CGNAT), subnetting va VPC rejalash, DHCP (DORA, lease), `ipcalc`

## II bosqich - Protokollar
4. **Protokollar**: TCP (handshake, portlar, holatlar, retransmission, `ss`, `nc`), UDP, DNS (yozuv turlari, resolution yo'li, TTL, `dig`, `/etc/resolv.conf`, `/etc/hosts`, systemd-resolved), SSH (kalitlar, `~/.ssh/config`, port forwarding, `sshd` hardening), SMTP (MX, SPF, DKIM, DMARC), HTTP va TLS (`curl -v`, `openssl s_client`)

## III bosqich - Paket yo'li
5. **Routing, Gateway**: routing table, default gateway, `ip route`, longest prefix match, `traceroute`, `mtr`, static route, IP forwarding, network namespace va veth bilan Linux router, BGP va AS haqida umumiy tushuncha
6. **Firewall, NAT, VPN**: stateful filtering, netfilter hook'lari, conntrack, nftables va iptables asoslari, ufw, firewalld, SNAT/MASQUERADE, DNAT va port forwarding, Docker NAT'ni qanday ishlatishi, WireGuard ikki host orasida, OpenVPN va IPsec sharhi, site-to-site va remote access, modul mini-loyihasi

## Yakuniy natija

Moduldan keyin siz:

- "Servisga ulanib bo'lmayapti" muammosini qatlamma-qatlam tashxislay olasiz: link, IP, route, DNS, port, firewall, TLS, ilova. Har qadamda qaysi buyruq ishlatilishini bilasiz.
- `connection refused`, `connection timed out`, `no route to host`, `name resolution failed` xatolari orasidagi farqni mexanizm darajasida tushuntirasiz.
- `/22` ni to'rtta `/24` ga bo'lish, manzil qaysi subnet'ga tegishli ekanini aniqlash kabi hisoblarni kalkulyatorsiz bajarasiz va VPC uchun manzil rejasini tuza olasiz.
- `tcpdump` bilan TCP handshake, DNS so'rov va ARP almashinuvini ushlab, chiqishini o'qiysiz.
- SSH'ni kalit bilan sozlaysiz, `ProxyJump` va port forwarding ishlatasiz, `sshd` ni qattiqlashtira olasiz.
- Linux'ni router va firewall sifatida sozlaysiz: forwarding, masquerade, port forwarding, default-drop qoidalar to'plami.
- Ikki host orasida WireGuard tunnel ko'tarasiz.
- Docker va Kubernetes tarmog'i (bridge, veth, NAT, DNS) keyingi modullarda "sehr" bo'lib ko'rinmaydi, chunki ularning qurilish bloklarini qo'lda yig'ib ko'rgansiz.

## Ataylab kiritilmagan

- Tarmoq uskunalari konfiguratsiyasi (Cisco IOS, Juniper), CCNA darajasidagi switching (STP, VLAN trunking, EtherChannel): DevOps uchun tushuncha yetarli, 1-darsda qisqa sharh bor.
- Dinamik routing protokollarini sozlash (OSPF, BGP daemon'lari: FRR, BIRD). 5-darsda faqat BGP nima ekani.
- Load balancer va reverse proxy (nginx, HAProxy): docker va cloud modullarida.
- Kubernetes tarmog'i (CNI, Service, Ingress, NetworkPolicy): kubernetes modulida.
- Cloud tarmog'i amaliyoti (VPC, security group, NAT gateway): cloud modulida, bu yerda faqat mos keladigan tushunchalar aytiladi.
- eBPF, XDP, service mesh, Wi-Fi xavfsizligi, tarmoq hujumlari va pentest.

## Manbalar

- Kurose, Ross, "Computer Networking: A Top-Down Approach" (asosiy darslik, I–II bosqich)
- Stevens, Fall, "TCP/IP Illustrated, Volume 1" (2-nashr; TCP va IP mexanizmlari bo'yicha ma'lumotnoma)
- Julia Evans, "Networking zines" va blog: https://jvns.ca/categories/networking/ (qisqa, amaliy tushuntirishlar)
- Cloudflare Learning Center: https://www.cloudflare.com/learning/ (DNS, TLS, BGP bo'yicha kirish maqolalari)
- `man ip`, `man ip-address`, `man ip-route`, `man ip-netns`, `man ss`, `man tcpdump`, `man pcap-filter`, `man dig`, `man ssh_config`, `man sshd_config`, `man nft`, `man wg`
- iproute2 qo'llanmasi: https://baturin.org/docs/iproute2/
- nftables wiki: https://wiki.nftables.org/
- WireGuard: https://www.wireguard.com/
- RFC 1918 (private manzillar), RFC 9293 (TCP), RFC 1034 va RFC 1035 (DNS): https://www.rfc-editor.org/
