# 1-dars: Tarmoq turlari

Maqsad: tarmoq nimadan tuzilganini eng pastki amaliy darajada tushunish: LAN va WAN farqi, internet qanday tarmoqlar yig'indisi ekani, NIC, switch, router va access point har biri aynan nima ish qilishi, MAC manzil va Ethernet frame tuzilishi, Linux'da interfeyslarni `ip link` va `ip addr` bilan o'qish, IP manzilni MAC manzilga bog'laydigan ARP. Frontend'da tarmoq `fetch()` dan boshlanardi, bu yerda esa kabeldan boshlanadi. Bu dars 2-darsdagi qatlamlar modeli va 5-darsdagi routing uchun lug'at: "bir tarmoq ichida" va "boshqa tarmoqqa" degan farq shu yerda paydo bo'ladi. Docker modulidagi bridge va veth ham aynan shu tushunchalarning virtual nusxasi.

Taxminiy vaqt: 2 kun (siz uchun). Diqqatni quyidagilarga qarating: switch va router farqi (MAC bo'yicha va IP bo'yicha uzatish), broadcast domain tushunchasi, `ip addr` chiqishidagi har bir so'z (`UP`, `LOWER_UP`, `NO-CARRIER`, `mtu`, `scope`), ARP jadvali holatlari, Docker'ning `docker0` va `veth` interfeyslari.

## Laboratoriya

- **Ish mashinasi**: faqat o'qiydigan buyruqlar (`ip link`, `ip addr`, `ip neigh`, `bridge`, `ethtool` o'qish rejimida). Interfeysni o'chirish, MTU yoki MAC o'zgartirish ish mashinasida bajarilmaydi.
- **Docker**: ikki konteyner va bitta user-defined bridge tarmoq, ARP va frame'larni ko'rish uchun:

```
docker network create lab-net
docker run -d --name h1 --network lab-net --cap-add NET_ADMIN nicolaka/netshoot sleep infinity
docker run -d --name h2 --network lab-net --cap-add NET_ADMIN nicolaka/netshoot sleep infinity
docker exec -it h1 bash
```

`--cap-add NET_ADMIN` faqat shu konteynerning o'z network namespace'ida interfeys va ARP jadvalini o'zgartirishga ruxsat beradi, host tarmog'iga ta'sir qilmaydi.

- **Tozalash**: `docker rm -f h1 h2 && docker network rm lab-net`.

---

## 1. Tarmoq turlari: LAN, WAN, internet

| Tur | Ko'lami | Kimniki | Misol |
|-----|---------|---------|-------|
| LAN (Local Area Network) | xona, bino, ofis | o'zingizniki | uy Wi-Fi tarmog'i, ofis, data markazdagi bitta rack |
| WAN (Wide Area Network) | shahar, mamlakat, qit'a | provayder yoki ijaraga olingan kanal | ofislar orasidagi kanal, ISP tarmog'i |
| Internet | global | hech kimniki, minglab mustaqil tarmoqlar birlashmasi | |

Amaliy ta'rif muhimroq: **LAN bu bitta broadcast domain**, ya'ni bitta host yuborgan broadcast frame yetib boradigan hostlar to'plami. LAN ichida hostlar bir-biriga to'g'ridan-to'g'ri, routersiz, MAC manzil orqali yetkazadi. LAN chegarasidan chiqish uchun router kerak.

Boshqa uchraydigan atamalar: WLAN (simsiz LAN), VLAN (bitta fizik switch'da mantiqan ajratilgan bir nechta LAN, 802.1Q tag bilan), VPC (cloud'dagi virtual xususiy tarmoq, cloud modulida).

### Internet tuzilishi

Internet bu "tarmoqlar tarmog'i". Har bir yirik tarmoq (provayder, cloud, universitet) **Autonomous System (AS)** deb ataladi va o'z raqamiga (ASN) ega. AS'lar bir-biri bilan ikki yo'l bilan ulanadi:

- **Transit**: kichik provayder kattasiga pul to'lab butun internetga chiqish oladi.
- **Peering**: ikki tarmoq trafikni bepul almashadi, odatda **IXP** (Internet Exchange Point) da.

Sizning paketingiz yo'li: uy routeri, mahalliy ISP, bir yoki bir nechta transit provayder yoki IXP, manzil tarmog'i (masalan cloud provayder AS'i), uning ichki tarmog'i, server. AS'lar orasida yo'lni BGP protokoli tanlaydi (5-darsda).

## 2. Qurilmalar

| Qurilma | Qaysi manzil bilan ishlaydi | Nima qiladi |
|---------|-----------------------------|-------------|
| NIC (Network Interface Card) | o'z MAC manzili | hostni tarmoqqa ulaydi, frame yuboradi va qabul qiladi |
| Hub (eskirgan) | hech qaysi | kelgan signalni barcha portlarga takrorlaydi |
| Switch | MAC | frame'ni faqat kerakli portga uzatadi, bitta LAN ichida |
| Router | IP | paketni bir tarmoqdan boshqasiga uzatadi |
| Access point (AP) | MAC | simsiz mijozlarni simli LAN'ga ko'prik (bridge) qilib ulaydi |

### Switch qanday ishlaydi

Switch **MAC address table** yuritadi: qaysi MAC qaysi portda. Mexanizm:

1. **Learning**: frame kelganda manba MAC va kelgan portni jadvalga yozadi.
2. **Forwarding**: manzil MAC jadvalda bo'lsa, frame faqat o'sha portga yuboriladi.
3. **Flooding**: manzil MAC noma'lum yoki broadcast (`ff:ff:ff:ff:ff:ff`) bo'lsa, kelgan portdan tashqari barcha portlarga yuboriladi.

Switch IP manzilga qaramaydi. Linux'da dasturiy switch bu **bridge** interfeysi: Docker'ning `docker0` aynan shu. Uning MAC jadvalini `bridge fdb show` ko'rsatadi.

### Router qanday ishlaydi

Router kamida ikki tarmoqqa ulangan qurilma (har birida o'z interfeysi va IP manzili). Paket kelganda manzil IP'ni routing table bilan solishtirib, qaysi interfeysdan chiqarishni tanlaydi. Har o'tishda (hop) Ethernet frame qaytadan yasaladi: manba va manzil MAC o'zgaradi, IP manzillar o'zgarmaydi (NAT bo'lmasa, 6-darsda).

**Tuzoq: uy "router"i bitta qurilma emas.** Uy Wi-Fi routeri ichida router, switch (LAN portlari), access point, DHCP server, DNS forwarder, NAT va firewall bor. Data markazda bular alohida qurilmalar yoki alohida dasturiy rollar. "Router ishlamayapti" degan tashxis shuning uchun noaniq: aynan qaysi rol?

## 3. MAC manzil va Ethernet frame

### MAC manzil

48 bit, olti bayt hex ko'rinishida: `9c:b6:d0:12:34:56`.

- Birinchi 3 bayt **OUI**: ishlab chiqaruvchi identifikatori. Qolgan 3 bayt qurilma raqami.
- Birinchi baytning ikkinchi eng kichik biti 1 bo'lsa manzil **locally administered** (zavod bergan emas, dasturiy tayinlangan). Amalda: birinchi baytning ikkinchi hex raqami `2`, `6`, `a` yoki `e` (masalan `02:42:...`, `9a:0d:...`). Docker konteynerlari, VM'lar va telefonlarning "private Wi-Fi address" funksiyasi shunday manzil ishlatadi.
- `ff:ff:ff:ff:ff:ff` broadcast: LAN'dagi hamma qabul qiladi.
- MAC faqat bitta LAN ichida ma'noga ega. Router'dan o'tgan paketda sizning MAC manzilingiz qolmaydi, server uni hech qachon ko'rmaydi.

### Ethernet frame

| Maydon | Hajm | Mazmuni |
|--------|------|---------|
| Destination MAC | 6 bayt | qabul qiluvchi |
| Source MAC | 6 bayt | yuboruvchi |
| EtherType | 2 bayt | ichida nima bor: `0x0800` IPv4, `0x0806` ARP, `0x86DD` IPv6 |
| Payload | 46–1500 bayt | odatda IP paket |
| FCS | 4 bayt | CRC32 nazorat yig'indisi, buzilgan frame tashlab yuboriladi |

**MTU (Maximum Transmission Unit)**: payload'ning maksimal hajmi, Ethernet'da standart 1500 bayt. `ip link` chiqishidagi `mtu 1500` shu. Tunnel va VPN'lar o'z header'ini qo'shgani uchun ularda MTU kichikroq bo'ladi (6-darsda WireGuard: 1420). MTU mos kelmasligi "kichik so'rovlar ishlaydi, kattalari osilib qoladi" ko'rinishidagi muammo beradi (2-darsda).

VLAN ishlatilsa, Source MAC va EtherType orasiga 4 baytli 802.1Q tag qo'shiladi, ichida 12 bitli VLAN ID.

## 4. Linux'da interfeyslar

Barcha zamonaviy tarmoq buyruqlari `iproute2` paketidagi `ip` asbobida. `ifconfig`, `route`, `arp`, `netstat` (net-tools) eskirgan, Ubuntu 24.04 da sukut bo'yicha o'rnatilmagan.

```
ip link show            # L2: interfaces, state, MAC, MTU
ip addr show            # L2 + L3: also IP addresses
ip -br addr             # brief, one line per interface
ip -c -br link          # colored
ip -s link show eth0    # RX/TX counters, errors, drops
ip -d link show docker0 # details: interface type (bridge, veth, ...)
```

### ip addr chiqishini o'qish

```
2: enp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 9c:b6:d0:12:34:56 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.23/24 brd 192.168.1.255 scope global dynamic noprefixroute enp2s0
       valid_lft 85012sec preferred_lft 85012sec
    inet6 fe80::9eb6:d0ff:fe12:3456/64 scope link
```

| Qism | Ma'nosi |
|------|---------|
| `2:` | interfeys indeksi |
| `UP` | administrativ yoqilgan (`ip link set dev X up`) |
| `LOWER_UP` | fizik link bor (kabel ulangan, Wi-Fi bog'langan) |
| `NO-CARRIER` | yoqilgan, lekin link yo'q (kabel uzilgan) |
| `state UP/DOWN/UNKNOWN` | operatsion holat; `lo` uchun `UNKNOWN` normal |
| `link/ether` | MAC manzil, `brd` broadcast MAC |
| `inet` / `inet6` | IPv4 / IPv6 manzil va prefiks uzunligi (3-darsda) |
| `scope global/link/host` | manzil qayerda yaroqli: hamma joyda, faqat shu LAN'da, faqat shu hostda |
| `dynamic` | DHCP orqali olingan, `valid_lft` lease qolgan vaqti |

**Tuzoq: `UP` bu "ishlayapti" degani emas.** `<UP>` faqat administrativ holat. `LOWER_UP` yo'q bo'lsa yoki `NO-CARRIER` tursa, interfeys yoqilgan, lekin sim yoki Wi-Fi aloqasi yo'q. Tashxisda birinchi qaraladigan narsa shu.

### Interfeys nomlari va turlari

| Nom | Nima |
|-----|------|
| `lo` | loopback, host o'zi bilan gaplashadi (`127.0.0.1`, `::1`) |
| `enp2s0`, `eno1`, `ens3` | simli Ethernet: `en` + joylashuv (PCI bus 2, slot 0). systemd "predictable names" |
| `wlp0s20f3` | Wi-Fi (`wl`) |
| `enx<mac>` | USB tarmoq adapteri, nomi MAC'dan |
| `eth0` | eski uslub nom, konteyner va ba'zi VM'larda |
| `docker0`, `br-<id>` | Linux bridge (Docker tarmoqlari) |
| `veth...@ifN` | virtual Ethernet juftligining bir uchi |
| `wg0`, `tun0` | VPN tunnel interfeyslari (6-darsda) |

**veth** bu virtual kabel: har doim juft yaratiladi, bir uchiga kirgan frame ikkinchi uchidan chiqadi. Docker har konteyner uchun juftlik yaratadi: bir uchi konteyner ichida `eth0` bo'ladi, ikkinchisi hostda `vethXXXX` nomi bilan bridge'ga ulanadi. `veth8ff182c@if2` dagi `@if2` juftning narigi uchi boshqa namespace'dagi 2-indeksli interfeys ekanini bildiradi.

Qo'shimcha o'qish joylari: `/sys/class/net/<iface>/` (`address`, `mtu`, `operstate`, `carrier` fayllari), `ethtool <iface>` (tezlik, duplex, link holati; fizik karta uchun).

### Holatni o'zgartirish (faqat konteyner yoki VM'da)

```
ip link set dev eth0 down
ip link set dev eth0 up
ip link set dev eth0 mtu 1400
```

Bu o'zgarishlar qayta yuklashda yo'qoladi. Doimiy sozlama Ubuntu server'da netplan (`/etc/netplan/*.yaml`), desktop'da NetworkManager orqali qilinadi.

## 5. ARP: IP dan MAC ga

Host `192.168.1.50` ga paket yubormoqchi. Frame yasash uchun manzil MAC kerak, lekin faqat IP ma'lum. **ARP (Address Resolution Protocol)** shu bo'shliqni yopadi:

1. Yuboruvchi broadcast frame yuboradi (`ff:ff:ff:ff:ff:ff`, EtherType `0x0806`): "Who has 192.168.1.50? Tell 192.168.1.23".
2. LAN'dagi hamma oladi, faqat `192.168.1.50` egasi unicast javob beradi: "192.168.1.50 is at aa:bb:cc:dd:ee:ff".
3. Yuboruvchi juftlikni **neighbour table** (ARP cache) ga yozadi va frame'ni yuboradi.

Muhim qoida: ARP faqat **o'z LAN'idagi** manzillar uchun ishlaydi. Manzil boshqa tarmoqda bo'lsa, host uning MAC'ini emas, **default gateway** ning MAC'ini so'raydi va frame'ni gateway'ga yuboradi (IP manzil esa oxirgi manzilniki bo'lib qoladi). "O'z tarmog'imi yoki yo'q" degan qaror subnet mask bilan qilinadi (3-darsda).

```
ip neigh show
# 192.168.1.1 dev enp2s0 lladdr 50:c7:bf:11:22:33 REACHABLE
# 192.168.1.50 dev enp2s0 lladdr aa:bb:cc:dd:ee:ff STALE
# 192.168.1.77 dev enp2s0 FAILED
```

| Holat | Ma'nosi |
|-------|---------|
| `REACHABLE` | yaqinda tasdiqlangan, ishlatilmoqda |
| `STALE` | yozuv bor, lekin muddati o'tgan; keyingi ishlatishda qayta tekshiriladi |
| `DELAY`, `PROBE` | qayta tekshirish jarayonida |
| `INCOMPLETE` | ARP so'rov yuborilgan, javob hali yo'q |
| `FAILED` | javob kelmadi: bu IP LAN'da yo'q yoki o'chiq |
| `PERMANENT` | qo'lda kiritilgan statik yozuv |

`FAILED` yoki `INCOMPLETE` kuchli tashxis signali: muammo IP yoki firewall darajasida emas, undan pastda. Host shu LAN'da umuman javob bermayapti.

IPv6 da ARP yo'q, uning o'rnida ICMPv6 asosidagi **NDP** (Neighbor Discovery) ishlaydi, lekin `ip neigh` ikkalasini ham ko'rsatadi (`ip -6 neigh`).

**Tuzoq: ARP'da autentifikatsiya yo'q.** LAN'dagi istalgan host "bu IP menda" deb javob bera oladi (ARP spoofing). Shuning uchun umumiy LAN'ga (kafe Wi-Fi) ishonilmaydi va trafik TLS yoki VPN bilan himoyalanadi. Xuddi shu mexanizmning foydali qo'llanishi ham bor: failover'da zaxira server virtual IP'ni o'ziga olib, "gratuitous ARP" yuboradi (keepalived shunday ishlaydi).

**Tuzoq: bir xil IP ikki hostda.** Ikki host bir IP'ni da'vo qilsa, qo'shnilarning ARP jadvalida MAC goh biri, goh ikkinchisi bo'ladi. Belgisi: aloqa "ba'zan ishlaydi", SSH host key ogohlantirishi chiqadi. `ip neigh` ni bir necha marta ko'rib, `lladdr` o'zgarayotganini tekshiring.

## 6. Docker tarmog'i shu bloklardan yig'ilgan

Sukut bo'yicha Docker:

- hostda `docker0` bridge yaratadi (dasturiy switch), unga IP beradi (odatda `172.17.0.1/16`), bu konteynerlar uchun default gateway;
- har konteyner uchun veth juftligi: bir uchi konteynerning network namespace'ida `eth0`, ikkinchisi hostda bridge portida;
- `docker network create` har yangi tarmoq uchun alohida `br-<id>` bridge yaratadi, ya'ni alohida LAN.

Shuning uchun bitta Docker tarmog'idagi konteynerlar bir-birini ARP bilan topadi va to'g'ridan-to'g'ri gaplashadi, turli tarmoqdagilar esa yo'q. Tashqariga chiqish host orqali routing va NAT bilan (5 va 6-darslar).

## Tuzoqlar

- `ip addr` da `UP` ni ko'rib "interfeys ishlayapti" deb xulosa qilish. `LOWER_UP` va `state` ni ham o'qing.
- Switch va router rolini aralashtirish: bir LAN ichidagi muammoni routing'dan, LAN'lar orasidagi muammoni ARP'dan qidirish.
- Server MAC manzilingizni ko'radi deb o'ylash. MAC birinchi router'dan nariga o'tmaydi.
- `ifconfig` va `arp` ga tayangan eski qo'llanmalar: yangi tizimlarda bu buyruqlar yo'q, ikkilamchi manzillarni to'liq ko'rsatmaydi. `ip` ishlating.
- `ip link set` va `ip addr add` o'zgarishlari qayta yuklashda yo'qoladi. Production'da "tuzatdim" deb ketib, reboot'dan keyin muammo qaytishi.
- Masofadagi serverda SSH ulangan interfeysni `down` qilish: o'zingizni serverdan uzib qo'yasiz. Bunday amallar konsol kirishi bo'lganda yoki avtomatik qaytarish (`at`, `netplan try`) bilan qilinadi.
- MTU'ni faqat bir tomonda o'zgartirish: katta paketlar jimgina yo'qoladi.
- `ip neigh` dagi `FAILED` ni e'tiborsiz qoldirib, firewall qoidalarini titkilash.

## Manbalar

- https://man7.org/linux/man-pages/man8/ip-link.8.html – `ip link`
- https://man7.org/linux/man-pages/man8/ip-address.8.html – `ip address`
- https://man7.org/linux/man-pages/man8/ip-neighbour.8.html – `ip neigh`, holatlar ro'yxati
- https://man7.org/linux/man-pages/man4/veth.4.html – veth juftliklari
- https://baturin.org/docs/iproute2/ – iproute2 amaliy qo'llanma
- https://www.rfc-editor.org/rfc/rfc826 – ARP
- https://docs.docker.com/engine/network/ – Docker networking umumiy sharh
- https://www.cloudflare.com/learning/network-layer/what-is-an-autonomous-system/ – AS nima
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 1-bob (internet tuzilishi) va 6-bob (link layer, switch, ARP)

---

## Vazifalar

Ish papkasi: `network/01-network-types/` (`make new m=network n=01 name=network-types`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. A va B guruhlar ish mashinasida (faqat o'qish), C va D guruhlar Laboratoriya bo'limidagi `h1`, `h2` konteynerlarida.

### A. Interfeyslar (ish mashinasi)

1. **Interface inventory.** `ip -br link` va `ip -br addr` ni ishga tushiring. Har interfeys uchun jadval tuzing: nomi, turi (loopback, Ethernet, Wi-Fi, bridge, veth), holati, MAC, IP. Turini aniqlashda `ip -d link show <iface>` dan foydalaning.

2. **Reading flags.** Faol interfeysingiz uchun `ip addr show <iface>` chiqishidagi `<...>` ichidagi har bir flag, `mtu`, `state`, `scope`, `dynamic`, `valid_lft` nimani anglatishini yozing. Sizda `NO-CARRIER` holatidagi interfeys bormi, nima uchun?

3. **MAC anatomy.** Fizik kartangiz MAC manzilining OUI qismini ajrating va ishlab chiqaruvchini aniqlang (IEEE yoki Wireshark OUI lookup sahifasi orqali). `docker0` ning MAC manzili universally yoki locally administered ekanini birinchi bayt bitidan aniqlang, hisobni ko'rsating.

4. **Interface statistics.** `ip -s link show <iface>` chiqishidagi RX va TX qatorlaridagi `errors`, `dropped` ustunlarini yozing. Bir necha megabayt yuklab (`curl -o /dev/null <katta fayl URL>`) hisoblagichlar qanday o'zgarganini ko'rsating.

5. **sysfs.** `/sys/class/net/<iface>/` ichidan `address`, `mtu`, `operstate`, `carrier` fayllarini o'qing va `ip link` chiqishi bilan solishtiring. `lo` uchun `operstate` nima va nima uchun bu normal?

### B. Qo'shnilar va gateway (ish mashinasi)

6. **Neighbour table.** `ip neigh show` chiqishini yozing. Har yozuv qaysi qurilma ekanini aniqlashga harakat qiling (router, telefon, konteyner). Holatlar ustunini izohlang.

7. **Gateway MAC.** `ip route show default` dan default gateway IP'sini toping, keyin uning MAC'ini `ip neigh` dan toping. `ping -c 3 1.1.1.1` qilganingizda frame'ning manzil MAC'i kimniki bo'ladi, manzil IP'si kimniki? Nima uchun `1.1.1.1` `ip neigh` da ko'rinmaydi?

8. **Failed neighbour.** O'z LAN'ingizdagi band bo'lmagan IP'ga (masalan oxirgi oktetni o'zgartirib) `ping -c 2` qiling, keyin darhol `ip neigh show` ni ko'ring. Yangi yozuv holatini va `ping` xato matnini yozing. Bu xato boshqa tarmoqdagi mavjud bo'lmagan IP'ga ping qilgandagi natijadan nimasi bilan farq qiladi?

9. **Home network map.** Uy yoki ofis tarmog'ingiz sxemasini matn (ASCII) ko'rinishida chizing: qurilmalar, ular orasidagi bog'lanish turi (sim, Wi-Fi), har birining IP va MAC'i (bilganingizcha), qaysi qurilma qaysi rollarni bajaradi (router, switch, AP, DHCP, NAT). Public IP'ingizni `curl -s https://ifconfig.me` bilan aniqlang va u qaysi qurilmaga tegishli ekanini yozing.

### C. Bridge va veth (Docker)

10. **Two hosts one LAN.** Laboratoriya bo'limidagi `lab-net`, `h1`, `h2` ni yarating. Har ikkala konteynerda `ip -br addr` ni ko'ring. Hostda `ip -br link` da qanday yangi interfeyslar paydo bo'lganini yozing (bridge va veth'lar).

11. **Veth pairs.** `h1` ichidagi `eth0@ifN` va hostdagi `vethXXXX@ifM` indekslari orqali qaysi host veth qaysi konteynerga tegishli ekanini aniqlang. Usulni tushuntiring.

12. **Bridge FDB.** Hostda `bridge link show` va `bridge fdb show br <lab-net bridge nomi>` ni ishga tushiring. `h1` dan `h2` ga ping qilgandan keyin jadvalda konteynerlar MAC'lari qaysi portda ko'rinishini yozing. Bu jadval switch'ning qaysi funksiyasiga mos keladi?

13. **Network isolation.** Ikkinchi tarmoq `lab-net2` va unda `h3` konteynerini yarating. `h1` dan `h3` ning IP'siga ping qiling. Natijani va sababini "broadcast domain" atamasi bilan izohlang. `h1` ning `ip neigh` jadvalida nima paydo bo'ldi?

### D. ARP va frame'lar (Docker)

14. **Watch ARP.** `h1` da `ip neigh flush dev eth0` qiling. Bir terminalda `h2` ichida `tcpdump -i eth0 -n -e arp or icmp` ni ishga tushiring, ikkinchisida `h1` dan `h2` ga `ping -c 2`. tcpdump chiqishidan ARP request va reply qatorlarini ko'chiring va har birida manba MAC, manzil MAC va EtherType ni ko'rsating.

15. **ARP only once.** 14-vazifani flush qilmasdan takrorlang. Bu safar ARP so'rov bormi? Sababini neighbour holati bilan izohlang. Bir necha daqiqadan keyin `ip neigh` holati qanday o'zgaradi?

16. **Link down.** `h2` da `ip link set dev eth0 down` qiling. `h2` da `ip addr show eth0` chiqishi qanday o'zgardi? `h1` dan ping natijasi va `h1` dagi `ip neigh` holatini yozing. `up` qilib qaytaring va aloqa tiklanganini ko'rsating. Default route nima bo'lganini `ip route` bilan tekshiring va kuzatganingizni izohlang.

17. **MTU mismatch.** `h1` da `ip link set dev eth0 mtu 1000` qiling. `h2` dan `h1` ga `ping -c 2 -s 500 <h1>` va `ping -c 2 -s 1400 <h1>` natijalarini solishtiring. Keyin `ping -M do -s 1400` (fragmentatsiyani taqiqlash) bilan `h1` dan `h2` ga yuboring va xato matnini yozing. MTU'ni 1500 ga qaytaring.

18. **Duplicate IP.** `h3` ni `lab-net` ga `h2` bilan bir xil IP bilan ulashga urinib ko'ring (`docker network connect --ip <h2 IP> lab-net h3`). Docker nima deydi? Agar real LAN'da ikki host bir IP'ni olgan bo'lsa, qo'shnining `ip neigh` jadvalida nima kuzatilardi va foydalanuvchi buni qanday alomat sifatida ko'rardi?

### E. Yig'ish

19. **Troubleshooting checklist.** "Ikki host bir LAN'da, lekin bir-biriga ping bormayapti" holati uchun 5–7 qadamli tekshiruv ro'yxati yozing: har qadamda aniq buyruq, qaysi chiqish "yaxshi", qaysi chiqish "muammo shu yerda" degani. Faqat shu darsdagi qatlam (link, MAC, ARP) doirasida.

20. **Cleanup.** Yaratilgan barcha konteyner va tarmoqlarni o'chiring. `docker ps -a`, `docker network ls` va hostdagi `ip -br link` chiqishi bilan veth va bridge'lar yo'qolganini tasdiqlang.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 20 ta vazifaning hammasi `## N. Title` sarlavhasi bilan bor.
2. `make check` toza.
3. Laboratoriya konteynerlari va tarmoqlari o'chirilgan (20-vazifa).
4. README'da public IP, to'liq MAC manzillar kabi shaxsiy ma'lumotlarni qisman yashiring (masalan oxirgi baytlarni `xx` bilan).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- LAN'ning amaliy ta'rifi nima va uning chegarasini qaysi qurilma belgilaydi?
- Switch frame'ni qaysi portga yuborishni qayerdan biladi? Bilmasa nima qiladi?
- Paket router'dan o'tganda frame'ning qaysi maydonlari o'zgaradi, IP paketning qaysi maydonlari o'zgarmaydi?
- `UP` va `LOWER_UP` farqi nima? `NO-CARRIER` qachon chiqadi?
- Host boshqa tarmoqdagi IP'ga paket yuborganda kimning MAC manzilini ARP bilan so'raydi va nima uchun?
- `ip neigh` da `FAILED` holati nimani bildiradi va bu tashxisni qayerga yo'naltiradi?
- veth juftligi nima va Docker undan qanday foydalanadi?
- Nima uchun ikki xil Docker tarmog'idagi konteynerlar bir-birini ARP bilan topa olmaydi?
