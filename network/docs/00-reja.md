# Kompyuter tarmoqlari o'quv rejasi (DevOps uchun)

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni bajarib natija va izohni `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `network/01-network-types/`, `network/02-osi-model/` va hokazo. Yaratish: `make new m=network n=01 name=network-types`.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Asos: qurilmalar, qatlamlar, manzillar | 3 | 9–10 kun | 7 kun | HTTP darajasidan pastdagi qatlamlar yangi, lekin terminal va JSON/hex o'qish tajribasi bor. Subnet hisobi qo'lda mashq talab qiladi, qisqartirilmaydi |
| II - Protokollar | 1 | 6–7 kun | 5 kun | HTTP, TLS, DNS'ning mijoz tomoni tanish. TCP holatlari, SSH sozlash va pochta yozuvlari yangi |
| III - Paket yo'li: routing, firewall, NAT, VPN | 2 | 9–10 kun | 8 kun | Butunlay yangi soha, namespace va firewall laboratoriyasi vaqt oladi |
| **Jami** | **6** | **24–27 kun** | **20 kun (4 hafta)** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz "paket A dan B ga qanday yetib boradi" savoliga shu dars qatlamida o'z so'zingiz bilan javob bera olasiz.

## Laboratoriya

Uch muhit ishlatiladi, har dars "Laboratoriya" bo'limida qaysi biri ekanini aytadi:

| Muhit | Nima uchun | Qoidasi |
|-------|-----------|---------|
| Ish mashinasi (Zorin OS 18) | faqat o'qiydigan buyruqlar: `ip addr`, `ip route`, `ss`, `dig`, `curl -v`, `mtr` | hech narsa o'zgartirilmaydi: interfeys, route, firewall, sysctl'ga tegilmaydi |
| Docker konteyner (`nicolaka/netshoot`) | tayyor tarmoq asboblari to'plami: `tcpdump`, `dig`, `nc`, `mtr`, `nmap` | `docker run --rm`, dars oxirida konteyner va tarmoqlar o'chiriladi |
| Multipass VM (Ubuntu 24.04) | holatni o'zgartiradigan hamma narsa: `ip netns`, static route, `nft`, `ufw`, `sshd_config`, WireGuard | VM linux modulida o'rnatilgan Multipass bilan yaratiladi, dars oxirida `multipass delete --purge` |

Multipass o'rnatilmagan bo'lsa: `sudo snap install multipass` (https://documentation.ubuntu.com/multipass/). Modul uchun ikkita VM yetadi:

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass launch 24.04 --name net2 --cpus 1 --memory 1G --disk 5G
multipass list
multipass shell net1
```

Network namespace (`ip netns`) bitta VM ichida bir nechta "virtual host" va router yaratish imkonini beradi, shuning uchun 5-darsdagi routing laboratoriyasi bitta VM'da bajariladi. Ikki VM faqat SSH (4-dars) va WireGuard (6-dars) uchun kerak.

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
