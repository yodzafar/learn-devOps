# 5-dars: Routing, Gateway

Maqsad: paket bir tarmoqdan boshqasiga qanday yo'l topishini tushunish va Linux'da buni boshqarish: routing table tuzilishi, default gateway, `ip route`, longest prefix match qoidasi, yo'lni `traceroute` va `mtr` bilan kuzatish, static route qo'shish, IP forwarding, va network namespace hamda veth juftliklari yordamida Linux'ni haqiqiy router sifatida yig'ish. Oxirida internet miqyosidagi routing (BGP, AS) haqida umumiy tushuncha. 1-darsda "boshqa tarmoqqa paket gateway'ga yuboriladi" deyilgan, 3-darsda "boshqa tarmoq" mask bilan aniqlanishi ko'rsatilgan edi. Endi gateway o'zi nima qilishini ko'ramiz. Docker va Kubernetes tarmog'i aynan shu darsdagi bloklardan (namespace, veth, bridge, route, forwarding) yig'ilgan, 6-darsdagi NAT va VPN esa routing ustiga quriladi.

Taxminiy vaqt: 3 kun (siz uchun). 1-kun routing table o'qish, `ip route get`, `traceroute`, `mtr`. 2-kun namespace laboratoriyasi: ikki tarmoq va router. 3-kun buzish va tuzatish vazifalari, skript. Diqqatni quyidagilarga qarating: longest prefix match, qaytish yo'li (javob paketi ham route talab qiladi), `Network is unreachable` va `No route to host` farqi, forwarding sukut bo'yicha o'chiq ekani.

## Laboratoriya

- **Ish mashinasi**: `ip route`, `ip route get`, `ip rule`, `tracepath`, `mtr` (faqat o'qish). Route qo'shish, `sysctl` o'zgartirish ish mashinasida bajarilmaydi.
- **Multipass VM** `net1`: barcha namespace, static route va forwarding vazifalari. Namespace'lar VM ichida yaratiladi, shuning uchun VM'ning o'z tarmog'iga ham ta'sir qilmaydi.

```
multipass start net1 && multipass shell net1
sudo apt update && sudo apt install -y traceroute mtr-tiny tcpdump
```

- **Tozalash**: namespace o'chirilganda ichidagi veth'lar va route'lar ham yo'qoladi: `sudo ip -all netns delete`. VM qayta yuklansa barcha `ip` o'zgarishlari yo'qoladi.

---

## 1. Routing table

Har host (faqat router emas) routing table'ga ega. Har chiquvchi paket uchun kernel bitta savolga javob beradi: "bu manzilga qaysi interfeysdan va kimga (next hop) yuboraman?"

```
$ ip route
default via 192.168.1.1 dev enp2s0 proto dhcp src 192.168.1.23 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
192.168.1.0/24 dev enp2s0 proto kernel scope link src 192.168.1.23 metric 100
```

| Qism | Ma'nosi |
|------|---------|
| `192.168.1.0/24` | manzil prefiksi: qaysi manzillar uchun |
| `default` | `0.0.0.0/0`, boshqa hech narsa mos kelmaganda |
| `via 192.168.1.1` | next hop: paket shu router'ga beriladi (gateway) |
| `dev enp2s0` | chiqish interfeysi |
| `scope link` | manzillar shu interfeysda to'g'ridan-to'g'ri yetib bo'ladi (`via` yo'q), ARP bilan |
| `proto kernel` / `dhcp` / `static` | yozuvni kim qo'shgan: manzil berilganda kernel, DHCP mijoz, administrator |
| `src 192.168.1.23` | shu route bo'yicha chiqadigan paketlar uchun afzal manba IP |
| `metric 100` | bir xil prefiksli route'lar orasida ustuvorlik, kichigi yutadi |

Ikki xil route bor:

- **Connected (on-link)**: `scope link`, `via` siz. Interfeysga manzil berilganda avtomatik paydo bo'ladi (3-dars). Manzil shu LAN'da, frame to'g'ridan-to'g'ri uning MAC'iga yuboriladi.
- **Gateway orqali**: `via X`. Frame `X` ning MAC'iga yuboriladi, IP header'dagi manzil esa oxirgi manzil bo'lib qoladi. `X` o'zi connected tarmoqda bo'lishi shart, aks holda `Error: Nexthop has invalid gateway`.

**Default gateway** bu default route'ning next hop'i: "bilmaganimning hammasini shunga beraman". Oddiy hostda odatda bitta connected route va bitta default route bor.

### Longest prefix match

Bir nechta route mos kelsa, **eng uzun prefiksli** (eng aniq) route yutadi. Metric faqat prefiks uzunligi teng bo'lganda solishtiriladi.

| Route'lar | Manzil | Tanlanadi |
|-----------|--------|-----------|
| `default`, `10.0.0.0/8 via A`, `10.1.0.0/16 via B`, `10.1.2.0/24 via C` | `10.1.2.3` | `/24`, C orqali |
| | `10.1.9.9` | `/16`, B orqali |
| | `10.200.0.1` | `/8`, A orqali |
| | `8.8.8.8` | `default` |

Jadvaldagi tartib ahamiyatsiz. VPN'lar shu qoidaga tayanadi: default route'ni o'chirmasdan `0.0.0.0/1` va `128.0.0.0/1` qo'shadi, ikkalasi `/0` dan aniqroq bo'lgani uchun butun trafik tunnel'ga ketadi.

Kernel qarorini so'rash (hisoblamasdan):

```
ip route get 8.8.8.8
# 8.8.8.8 via 192.168.1.1 dev enp2s0 src 192.168.1.23 uid 1000
ip route get 172.17.0.5
# 172.17.0.5 dev docker0 src 172.17.0.1 uid 1000
```

Tashxisda eng foydali buyruqlardan biri: jadvalni ko'z bilan tahlil qilish o'rniga aniq manzil uchun natijani beradi.

### Xato matnlari

| Xato | Qayerdan | Ma'nosi |
|------|----------|---------|
| `Network is unreachable` | o'z kernel'ingiz, darhol | routing table'da mos route yo'q (default ham yo'q) |
| `No route to host` | o'z kernel'ingiz yoki yo'ldagi router'dan ICMP | route bor, lekin next hop yoki manzil ARP'ga javob bermadi; yoki firewall `reject` qildi |
| `Destination Net Unreachable` (ping chiqishida `From X`) | yo'ldagi router `X` | o'sha router'da manzilga route yo'q |
| javob yo'q, timeout | | paket yoki javobi yo'lda jim tashlanmoqda |

## 2. Yo'lni kuzatish

### traceroute mexanizmi

IP header'dagi **TTL** har router'da bittaga kamayadi. Nolga tushsa router paketni tashlab, yuboruvchiga ICMP "Time exceeded" qaytaradi. `traceroute` TTL=1, 2, 3, ... bilan zondlar yuboradi va har javobning manba manzilini yozib boradi: shu tarzda yo'ldagi router'lar birma-bir ko'rinadi.

```
traceroute -n 1.1.1.1          # UDP probes by default, 3 per hop
sudo traceroute -n -I 1.1.1.1  # ICMP echo probes
sudo traceroute -n -T -p 443 1.1.1.1   # TCP SYN to port 443, passes most firewalls
tracepath -n 1.1.1.1           # no root needed, also reports path MTU
mtr -n 1.1.1.1                 # live view: traceroute + ping combined
mtr -rwn -c 20 1.1.1.1         # report mode, 20 cycles, suitable for pasting
```

Chiqishni o'qish:

- `* * *`: shu hop javob bermadi. Ko'p router ICMP javoblarini cheklaydi yoki umuman bermaydi. Keyingi hop'lar ko'rinsa bu muammo emas.
- **mtr'da oraliq hop'da yo'qotish, oxirgi hop'da 0%**: o'sha router ICMP javobini cheklayapti (rate limit), tranzit trafikni esa normal uzatmoqda. Haqiqiy yo'qotish o'sha hop'dan boshlab **oxirigacha** davom etadi.
- Kechikish keskin oshib, keyingi hop'larda ham saqlansa, o'sha kanal sekin (masalan qit'alararo). Bitta hop'da baland, keyin yana past bo'lsa bu router'ning ICMP'ga sekin javob berishi.
- Bir hop'da bir nechta har xil manzil: yuk bir nechta yo'lga taqsimlangan (ECMP).

**Tuzoq: traceroute faqat borish yo'lini ko'rsatadi.** Internetda qaytish yo'li ko'pincha boshqa (asymmetric routing). Muammo qaytish yo'lida bo'lsa, sizning traceroute'ingiz toza ko'rinadi. To'liq tashxis uchun ikkala tomondan mtr kerak.

**Tuzoq: sukut bo'yicha UDP zondlar.** Firewall yuqori UDP portlarni tashlasa, traceroute yo'l oxirida faqat yulduzchalar ko'rsatadi, garchi TCP 443 ishlab tursa ham. Servis portiga `-T -p <port>` bilan tekshiring.

## 3. Static route va doimiy sozlama

```
sudo ip route add 10.20.0.0/16 via 192.168.1.254          # via a gateway
sudo ip route add 10.30.0.0/24 dev wg0                    # on-link through an interface
sudo ip route replace 10.20.0.0/16 via 192.168.1.253      # add or change
sudo ip route del 10.20.0.0/16
sudo ip route add blackhole 10.99.0.0/16                  # silently drop
```

`ip route` o'zgarishlari qayta yuklashda yo'qoladi. Ubuntu server'da doimiy route netplan'da:

```
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      routes:
        - to: 10.20.0.0/16
          via: 192.168.1.254
```

Qo'llash: `sudo netplan try` (tasdiqlanmasa o'zi qaytaradi), keyin `sudo netplan apply`.

### Policy routing (qisqa)

Aslida bitta emas, bir nechta routing table bor va qaysi biri ishlatilishini qoidalar hal qiladi:

```
ip rule show
# 0:      from all lookup local
# 32766:  from all lookup main
# 32767:  from all lookup default
ip route show table local
```

`ip route` sukut bo'yicha `main` jadvalini ko'rsatadi. `local` jadvalida hostning o'z manzillari va broadcast'lar turadi. Qo'shimcha qoidalar bilan "manba IP shunday bo'lsa boshqa jadvalga qara" deyish mumkin: ikki provayderli hostlar, WireGuard (`wg-quick`) va ba'zi Kubernetes CNI'lar shuni ishlatadi. Tashxisda `ip route` kutilmagan natija bersa `ip rule` ni ham ko'ring; `ip route get` esa qoidalarni hisobga olgan yakuniy javobni beradi.

## 4. Linux router: forwarding

Host o'ziga tegishli bo'lmagan manzilga kelgan paketni sukut bo'yicha **tashlaydi**. Uni router'ga aylantiradigan bitta sozlama:

```
sysctl net.ipv4.ip_forward              # 0 = host, 1 = router
sudo sysctl -w net.ipv4.ip_forward=1    # until reboot
# persistent: /etc/sysctl.d/99-forward.conf with "net.ipv4.ip_forward = 1", then: sudo sysctl --system
```

IPv6 uchun alohida: `net.ipv6.conf.all.forwarding`. Docker o'rnatilganda `ip_forward` ni o'zi yoqadi, chunki host konteynerlar uchun router.

Forwarding yoqilgan router paket bilan nima qiladi: manzil IP'ni o'z routing table'idan qidiradi, TTL'ni kamaytiradi, chiqish interfeysida next hop MAC'ini ARP bilan topadi, yangi frame yasab yuboradi. IP manzillarga tegmaydi (NAT bu alohida, 6-darsda).

**Tuzoq: qaytish yo'li.** A dan B ga yo'l borligi yetmaydi: B javob yuborishi uchun A ning tarmog'iga **o'z** route'iga ega bo'lishi kerak. Belgisi: `tcpdump` B da so'rovni ko'rsatadi, javob esa noto'g'ri interfeysdan chiqadi yoki umuman chiqmaydi. "Ping bormayapti" muammolarining yarmi borish emas, qaytish yo'lida. Shuning uchun har ikki tomonda `ip route get <qarshi tomon IP>` tekshiriladi.

**Reverse path filtering** (`net.ipv4.conf.<iface>.rp_filter`): kernel kelgan paketning manba manzilini tekshiradi. `1` (strict): manba IP'ga javob aynan shu interfeysdan ketadigan bo'lsagina qabul qilinadi. `2` (loose): manba IP istalgan interfeys orqali yetib bo'ladigan bo'lsa yetarli. `0`: tekshiruv yo'q. Asymmetric routing'da strict rejim paketlarni jim tashlaydi.

## 5. Network namespace va veth bilan laboratoriya

**Network namespace** alohida tarmoq stack'i: o'z interfeyslari, o'z routing table'i, o'z neighbour jadvali, o'z firewall qoidalari, o'z `ip_forward` sozlamasi. Konteynerning "o'z tarmog'i" aynan shu. Bitta VM ichida bir nechta namespace yaratib, ularni veth juftliklari (1-dars: virtual kabel) bilan ulab, to'liq tarmoq topologiyasini yig'ish mumkin.

```
sudo ip netns add client
sudo ip netns list
sudo ip netns exec client ip addr          # run a command inside the namespace
sudo ip -n client addr                     # shorthand for ip commands
sudo ip netns delete client
```

Ikki namespace'ni kabel bilan ulash namunasi:

```
sudo ip link add veth-a type veth peer name veth-b
sudo ip link set veth-a netns ns1
sudo ip link set veth-b netns ns2
sudo ip -n ns1 addr add 10.0.0.1/24 dev veth-a
sudo ip -n ns1 link set veth-a up
sudo ip -n ns1 link set lo up
```

Qoidalar:

- Yangi namespace'da faqat `lo` bor va u `DOWN`. `127.0.0.1` ishlashi uchun `lo` ni ham `up` qiling.
- veth'ning ikkala uchi ham `up` bo'lishi kerak, aks holda `NO-CARRIER`.
- Namespace o'chirilsa ichidagi veth uchi yo'qoladi va juftning ikkinchi uchi ham.
- `ip_forward` har namespace'da alohida: router namespace'ida `sudo ip netns exec router sysctl -w net.ipv4.ip_forward=1`.
- Ikkidan ortiq hostni bitta LAN'ga ulash uchun switch kerak: `sudo ip link add br0 type bridge`, veth uchlarini `sudo ip link set veth-x master br0` bilan port qilib ulash. Docker'ning `docker0` i shu.

Maqsad topologiya (vazifalarda yig'asiz):

```
[client]                    [router]                    [server]
10.0.1.2/24 ---veth--- 10.0.1.1/24  10.0.2.1/24 ---veth--- 10.0.2.2/24
```

Docker aynan shuni qiladi: konteyner namespace'i, veth, bridge, hostda forwarding va NAT. Kubernetes CNI plugin'lari ham shu primitivlardan foydalanadi, faqat node'lar orasidagi route'larni qo'shimcha boshqaradi.

## 6. Internet miqyosida: AS va BGP

Sizning routing table'ingizda uch qator bor. Internet magistralidagi router'da esa milliondan ortiq IPv4 prefiks. Ularni qo'lda yozib bo'lmaydi, router'lar **dinamik routing protokollari** orqali almashadi:

- **Tashkilot ichida** (IGP): OSPF, IS-IS. Maqsad: eng qisqa yo'l.
- **Tashkilotlar orasida** (EGP): **BGP (Border Gateway Protocol)**. Maqsad: siyosat (kim bilan, qanday shartnoma asosida).

**Autonomous System (AS)**: bitta ma'muriyat ostidagi tarmoqlar to'plami, o'z raqami (ASN) bilan. Private ASN diapazoni 64512–65534.

BGP qanday ishlaydi (eng sodda ko'rinishda):

1. Har AS qo'shnilariga "menda shu prefikslar bor" deb e'lon qiladi (announce), masalan `203.0.113.0/24`.
2. Qo'shni bu e'lonni o'z ASN'ini yo'lga (**AS path**) qo'shib, o'z qo'shnilariga uzatadi.
3. Bir prefiksga bir nechta yo'l kelsa, router avval mahalliy siyosatni (local preference: mijoz, peer, transit), keyin eng qisqa AS path'ni tanlaydi.
4. Uzatishda baribir longest prefix match amal qiladi: aniqroq prefiks e'lon qilgan tarmoq trafikni oladi.

Oxirgi band BGP'ning zaif joyi: kimdir sizning `/22` ingiz ichidan `/24` ni e'lon qilsa (xato yoki ataylab), trafik unga ketadi. Bu **route leak** va **BGP hijack**, yirik global uzilishlarning takrorlanadigan sababi. Himoya: RPKI (e'lonlarni kriptografik tasdiqlash).

DevOps BGP bilan qayerda uchrashadi:

| Joy | Nima |
|-----|------|
| Cloud bilan ofis yoki data markaz ulanishi (VPN, Direct Connect) | route'lar BGP orqali avtomatik almashinadi |
| Anycast | bitta IP (masalan `1.1.1.1`) ko'p joydan e'lon qilinadi, trafik eng yaqiniga boradi: CDN va DNS shunday ishlaydi |
| Bare-metal Kubernetes | MetalLB (BGP rejimi) va Calico pod yoki service prefikslarini router'larga BGP bilan e'lon qiladi |
| Incident tahlili | "provayder X da route leak" degan xabarni o'qiy olish |

Ko'rish asboblari: `mtr -rwz -c 5 1.1.1.1` (har hop uchun ASN), https://bgp.he.net va https://bgp.tools (prefiks kimga tegishli, kim bilan peering).

## Tuzoqlar

- Faqat borish yo'lini tekshirish. Qarshi tomonda sizning tarmog'ingizga route yo'q bo'lsa, javob default gateway orqali boshqa yoqqa ketadi.
- Router bo'lishi kerak bo'lgan hostda `ip_forward=0`: paketlar keladi va jim yo'qoladi. Yoki `sysctl -w` bilan yoqib, reboot'dan keyin yo'qotish.
- Static route'ni `ip route add` bilan qo'shib, netplan'ga yozmaslik.
- Masofadagi serverda default route'ni o'chirish yoki almashtirish: SSH sessiyangiz uziladi va qaytib kira olmaysiz. `netplan try` yoki konsol kirishi bilan ishlang.
- Kesishadigan CIDR'lar (3-dars): Docker tarmog'i `172.17.0.0/16` korporativ tarmoqdagi shu diapazon bilan to'qnashsa, connected route aniqroq bo'lib, o'sha serverlarga trafik `docker0` ga ketadi.
- mtr'dagi oraliq hop yo'qotishini "provayder paket yo'qotyapti" deb talqin qilish, oxirgi hop'ga qaramasdan.
- `ping` o'tmaganini routing muammosi deb hisoblash: ICMP filtrlangan bo'lishi mumkin. `ip route get`, `tcpdump` va TCP zond bilan tasdiqlang.
- VPN ulangach "internet yo'qoldi" yoki "ichki servislar ko'rinmayapti": VPN qo'shgan route'lar (aniqroq prefikslar yoki yangi default) nimani qamrashini `ip route` va `ip rule` da ko'rmaslik.
- Namespace'da `lo` ni ko'tarishni unutish: `localhost` ga tayangan dasturlar ishlamaydi.

## Manbalar

- https://man7.org/linux/man-pages/man8/ip-route.8.html – `ip route`
- https://man7.org/linux/man-pages/man8/ip-netns.8.html – `ip netns`
- https://man7.org/linux/man-pages/man8/ip-rule.8.html – `ip rule`
- https://man7.org/linux/man-pages/man7/network_namespaces.7.html – network namespace'lar
- https://man7.org/linux/man-pages/man8/traceroute.8.html – `traceroute`
- https://www.kernel.org/doc/html/latest/networking/ip-sysctl.html – `ip_forward`, `rp_filter` va boshqa sysctl'lar
- https://netplan.readthedocs.io/en/stable/netplan-yaml/ – netplan YAML, `routes`
- https://baturin.org/docs/iproute2/ – iproute2 amaliy qo'llanma
- https://www.cloudflare.com/learning/security/glossary/what-is-bgp/ – BGP sharhi
- https://www.rfc-editor.org/rfc/rfc4271 – BGP-4
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 4–5-boblar (forwarding, routing algoritmlari, BGP)

---

## Vazifalar

Ish papkasi: `network/05-routing/` (`make new m=network n=05 name=routing`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptni shu papkaga saqlang. A guruh ish mashinasida (faqat o'qish), qolganlari `net1` VM ichida.

### A. Routing table o'qish (ish mashinasi)

1. **Read my table.** `ip route` chiqishining har qatorini izohlang: prefiks, next hop bor yoki yo'qligi, interfeys, `proto`, `scope`, `src`, `metric`. Har qatorni kim qo'shganini ayting (kernel, DHCP, Docker).

2. **Route lookup.** `ip route get` ni kamida besh manzil uchun bajaring: public IP, o'z LAN'ingizdagi host, Docker tarmog'idagi manzil, `127.0.0.1`, o'z IP'ingiz. Har natijada qaysi route tanlangani va `src` nima uchun shunday ekanini yozing.

3. **Longest prefix by hand.** Jadval berilgan: `default via 10.0.0.1`, `10.0.0.0/24 dev eth0`, `10.8.0.0/16 via 10.0.0.2`, `10.8.4.0/22 via 10.0.0.3`, `10.8.5.0/24 via 10.0.0.4`, `192.168.0.0/16 via 10.0.0.5`. Har manzil uchun next hop'ni qo'lda aniqlang va asoslang: `10.8.5.200`, `10.8.6.1`, `10.8.8.1`, `10.9.0.1`, `10.0.0.77`, `192.168.255.1`, `172.16.0.1`.

4. **Tables and rules.** `ip rule show` va `ip route show table local` chiqishini yozing. `local` jadvalidagi `local` va `broadcast` turidagi yozuvlar nima uchun kerak? `ping 127.0.0.1` qaysi jadval orqali hal bo'ladi?

5. **Trace a path.** `tracepath -n` va `mtr -rwn -c 10` ni ikki manzilga bajaring: `1.1.1.1` va geografik uzoq bir sayt. Har hop'ni tasniflang (uy routeri, ISP, tranzit, manzil tarmog'i), private manzilli hop'lar qayerda tugaydi, kechikish qaysi hop'da keskin oshadi. Javob bermagan yoki yo'qotish ko'rsatgan oraliq hop bormi va u haqiqiy muammomi?

6. **AS path.** `mtr -rwz -c 5` bilan xuddi shu ikki manzilga yo'ldagi ASN'larni oling. Yo'l nechta AS orqali o'tdi? Ulardan ikkitasining kimga tegishli ekanini https://bgp.he.net orqali aniqlang. `1.1.1.1` anycast ekanini qanday bilsa bo'ladi?

### B. Namespace va veth (VM)

7. **Two namespaces.** `ns1` va `ns2` namespace'larini yarating, veth juftligi bilan ulang, `10.0.0.1/24` va `10.0.0.2/24` bering. Bir-biriga ping o'tishini ko'rsating. Har namespace'da `ip addr`, `ip route` va pingdan keyingi `ip neigh` chiqishini yozing. VM'ning o'zidan (`ip route get 10.0.0.1`) bu manzillar ko'rinadimi, nima uchun?

8. **Forgotten steps.** 7-vazifani noldan takrorlang, lekin har safar bitta qadamni ataylab tashlab keting va alomatni yozing: (a) bir veth uchi `up` qilinmagan; (b) manzil prefikssiz berilgan; (c) `lo` ko'tarilmagan holda `ping 127.0.0.1`. Har biri uchun: xato matni, `ip addr` yoki `ip route` dagi belgi.

9. **Bridge as a switch.** Uchta namespace'ni (`h1`, `h2`, `h3`) VM'dagi `br0` bridge orqali bitta LAN'ga ulang (`10.0.5.0/24`). Hammasi bir-biriga ping qila olishini ko'rsating. `bridge fdb show br br0` va `bridge link` chiqishini izohlang. Bu topologiya Docker'ning qaysi qismiga mos keladi?

### C. Linux router (VM)

10. **Build the router.** 5-bo'limdagi topologiyani yig'ing: `client` (`10.0.1.2/24`), `router` (`10.0.1.1/24` va `10.0.2.1/24`), `server` (`10.0.2.2/24`). Hali default route va forwarding sozlamang. `client` dan `10.0.1.1`, `10.0.2.1` va `10.0.2.2` ga ping qiling. Har natijaning xato matnini va sababini yozing.

11. **Default gateway.** `client` ga default route qo'shing. 10-vazifadagi uch pingni takrorlang. Endi qaysi biri o'tadi, qaysi biri yo'q? `10.0.2.1` ga ping nima uchun forwarding'siz ham ishlashini tushuntiring.

12. **Return path.** `router` da forwarding'ni yoqing, lekin `server` ga hali route qo'shmang. `client` dan `server` ga ping qiling va bir vaqtda `server` ichida `tcpdump -i <veth> -n icmp` ni kuzating. Echo request keldimi? Reply ketdimi? `server` da `ip route get 10.0.1.2` nima deydi? Keyin `server` ga route qo'shib muammoni tuzating. Bu tajribadan chiqadigan umumiy qoidani bir gap bilan yozing.

13. **Forwarding off.** Hammasi ishlab turgan holatda `router` da `ip_forward` ni `0` qiling. `client` dan ping natijasi qanday, `router` ning ikkala interfeysida tcpdump nimani ko'rsatadi (paket kirdi, chiqdimi)? Qaytadan yoqing. VM'ning o'zidagi `sysctl net.ipv4.ip_forward` qiymati namespace'dagisidan mustaqilligini ko'rsating.

14. **Watch the hop.** `client` dan `server` ga ping ketayotganda `router` ning har ikki interfeysida `tcpdump -n -e icmp` bilan bitta paketni ushlang. Ikki tomondagi manba va manzil MAC, manba va manzil IP hamda TTL ni jadvalga yozing. Nima o'zgardi, nima o'zgarmadi (2-darsdagi jadval bilan solishtiring)?

15. **Traceroute in the lab.** `client` dan `traceroute -n 10.0.2.2` va `mtr -rn -c 5 10.0.2.2` ni bajaring. Nechta hop va ular kim? `tcpdump` bilan `client` interfeysida zondlar va qaytgan ICMP xabarlarni ushlab, TTL mexanizmini o'z kuzatuvingiz bilan tushuntiring.

16. **Service through the router.** `server` namespace'ida `python3 -m http.server 8080` ni ishga tushiring va `client` dan `curl` bilan oling. Keyin server'ni `--bind 127.0.0.1` bilan qayta ishga tushirib takrorlang: `client` dagi xato matni qanday va u routing muammosidan qanday farqlanadi?

### D. Static route va tashxis (VM)

17. **Third network.** Topologiyaga `router2` va uning ortida `10.0.3.0/24` tarmog'i hamda `db` (`10.0.3.2`) hostini qo'shing; `router2` `10.0.2.0/24` tarmog'iga `10.0.2.3` manzili bilan ulanadi (buning uchun `10.0.2.0/24` da bridge kerak bo'ladi). `client` dan `db` ga ping o'tishi uchun qaysi hostlarga qanday static route kerakligini avval qog'ozda aniqlang, keyin qo'shing. Har hostning yakuniy `ip route` chiqishini va `client` dan `traceroute` natijasini yozing.

18. **Wrong gateway.** `client` da `ip route add 10.0.3.0/24 via 10.0.9.9` ni bajarib ko'ring. Xato matni nima va kernel nima uchun bunday route'ni qabul qilmaydi? Keyin mavjud, lekin noto'g'ri next hop (`10.0.1.77`, hech kim yo'q) bilan qo'shing: `ping` xatosi va `ip neigh` holati qanday?

19. **Blackhole and prefix order.** `router` da `10.0.3.0/24` uchun to'g'ri route turgan holda `blackhole 10.0.3.2/32` qo'shing. `client` dan `db` ga va shu tarmoqdagi boshqa manzilga ping natijalarini solishtiring va longest prefix match bilan izohlang. Route'ni o'chiring.

20. **Find the fault.** Topologiyani buzadigan to'rt xil o'zgarishdan birini o'zingiz bilmagan holda qo'llash uchun kichik skript yozing (tasodifiy tanlaydi: forwarding o'chirish, bitta route'ni o'chirish, bitta interfeysni `down` qilish, noto'g'ri mask). Skriptni ishga tushiring va nosozlikni faqat tashxis buyruqlari bilan toping. README'ga tashxis qadamlaringizni tartib bilan yozing: har buyruq nimani isbotladi yoki istisno qildi. Kamida ikki marta takrorlang.

### E. Yig'ish

21. **Lab script.** `netlab.sh up` va `netlab.sh down` buyruqlari bilan 17-vazifadagi to'liq topologiyani yaratadigan va o'chiradigan skript yozing. Talablar: `set -euo pipefail`, takroran ishga tushirilganda xato bermaydi (idempotent), `netlab.sh test` barcha juftliklar orasida ping va `client` dan `server` ga HTTP tekshiruvini bajarib natijani jadval qilib chiqaradi, `shellcheck` toza. README'ga topologiya sxemasini (ASCII) va manzil jadvalini qo'shing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 21 ta vazifa; `netlab.sh` va 20-vazifadagi buzuvchi skript papkada.
2. `make check` toza (`shellcheck`).
3. VM'da `sudo ip netns list` bo'sh, `ip -br link` da ortiqcha bridge va veth yo'q.
4. Ish mashinasida hech qanday route yoki sysctl o'zgarmagan (`ip route` dars boshidagi bilan bir xil).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Routing table'dagi connected route va gateway orqali route farqi nima? Har birida frame kimning MAC'iga yuboriladi?
- Longest prefix match nima va metric qachon ahamiyat kasb etadi?
- `Network is unreachable` va `No route to host` nimasi bilan farq qiladi?
- A dan B ga ping o'tishi uchun nechta hostda qanday route'lar bo'lishi kerak? "Qaytish yo'li" muammosi qanday ko'rinadi?
- `ip_forward=0` bo'lgan host ikki tarmoqqa ulangan bo'lsa nima qiladi?
- traceroute qanday mexanizmga tayanadi? mtr'da oraliq hop'dagi yo'qotish qachon haqiqiy muammo?
- Network namespace nimalarni ajratadi? Docker konteyneri tarmog'i qaysi bloklardan yig'ilgan?
- Docker tarmog'i CIDR'i korporativ tarmoq bilan kesishsa nima bo'ladi va nima uchun?
- AS va BGP nima? Kimdir sizning prefiksingizdan aniqroq prefiks e'lon qilsa nima bo'ladi?
