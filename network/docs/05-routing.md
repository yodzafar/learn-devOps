# 5-dars: Routing, Gateway

Maqsad: paket bir tarmoqdan boshqasiga qanday yo'l topishini noldan tushunish va Linux'da buni boshqarish: routing table tuzilishi, default gateway, `ip route`, longest prefix match qoidasi, yo'lni `traceroute` va `mtr` bilan kuzatish, static route qo'shish, IP forwarding, va network namespace hamda veth juftliklari yordamida Linux'ni haqiqiy router sifatida yig'ish. Oxirida internet miqyosidagi routing (BGP, AS) haqida umumiy tushuncha. 1-darsda "boshqa tarmoqqa paket gateway'ga yuboriladi" deyilgan, 3-darsda "boshqa tarmoq" mask bilan aniqlanishi ko'rsatilgan edi. Endi gateway o'zi nima qilishini ko'ramiz. Docker va Kubernetes tarmog'i aynan shu darsdagi bloklardan (namespace, veth, bridge, route, forwarding) yig'ilgan, cloud'dagi VPC route table ham shu jadvalning o'zi, 6-darsdagi NAT va VPN esa routing ustiga quriladi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh vazifalari (jadvalni o'qish, `ip route get`, `traceroute`, `mtr`). Ikkinchi kun 4–6 bo'limlar, "Birga bajaramiz" va B guruhi (namespace, veth, bridge). Uchinchi kun C guruhi (router, forwarding, qaytish yo'li). To'rtinchi kun 7-bo'lim va D guruhi (uchinchi tarmoq, buzish va tashxis). Beshinchi kun 21-vazifadagi skript va README. Diqqatni quyidagilarga qarating: longest prefix match, qaytish yo'li (javob paketi ham route talab qiladi), `Network is unreachable` va `No route to host` farqi, forwarding nima ekani va u har namespace'da alohida ekani.

Qanday o'qish kerak: har bo'limdagi misolni `lab` VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi maydonma-maydon izoh bilan solishtiring. Interfeys nomi, VM manzili va gateway har mashinada boshqa, darsda ular `<IF>`, `<VM_IP>`, `<GW>` kabi belgilangan; o'z qiymatlaringizni 1-bo'limdagi buyruq bilan aniqlaysiz. Har bo'lim oxiridagi "Nima uchun shunday" qoidaning sababini aytadi.

## Laboratoriya

Hamma narsa `SETUP.md` dagi `lab` VM (Multipass, Ubuntu 24.04) ichida bajariladi. Bu darsda routing holati o'zgartiriladi (qo'shimcha route, namespace, veth, `ip_forward`), shuning uchun host'ga (Zorin yoki macOS) umuman tegilmaydi: Zorin host'ida `ip route add` yoki `sysctl -w` bajarish ofis tarmog'idagi ulanishingizni uzishi mumkin, macOS'da esa `ip` buyrug'ining o'zi yo'q.

| Joy | Bu darsda nima qilinadi |
|-----|-------------------------|
| Host (Zorin yoki macOS) | `multipass`, `make`, `git`. Ixtiyoriy, faqat o'qish: route jadvalini ko'rish. Hech narsa o'zgartirilmaydi |
| `lab` VM, asosiy tarmoq | A guruh: `ip route`, `ip route get`, `ip rule`, `tracepath`, `traceroute`, `mtr` (faqat o'qish) |
| `lab` VM, network namespace'lar | B–E guruhlar: veth, bridge, static route, forwarding. Namespace bu VM ichidagi alohida tarmoq stack'i (6-bo'lim), shuning uchun VM'ning o'z ulanishi ham buzilmaydi |

Asboblar VM ichida o'rnatiladi (paket nomlari `amd64` va `arm64` da bir xil, `apt` arxitekturani o'zi tanlaydi):

```
multipass shell lab
sudo apt update
sudo apt install -y traceroute mtr-tiny iputils-tracepath tcpdump
```

`ip`, `bridge` va `sysctl` Ubuntu'da oldindan bor (`iproute2` va `procps` paketlari). `python3` ham bor (16-vazifa).

- **Oldingi dars holati**: A guruhdagi 1 va 2-vazifalar VM'da Docker'ning `docker0` interfeysi borligini kutadi (1-darsda `sudo apt install -y docker.io` bilan o'rnatilgan). Ikkinchi mashinada yoki `lab.clean` ga qaytgan VM'da u yo'q bo'lsa, shu buyruqni VM ichida qayta bajaring. Boshqa hech qanday oldingi holat kerak emas.
- **Tozalash**: `sudo ip -all netns delete` barcha namespace'larni o'chiradi; namespace bilan birga ichidagi veth uchlari va route'lar ham yo'qoladi. VM'ning asosiy tarmog'ida qolgan bridge alohida o'chiriladi: `sudo ip link del br0`.
- **Qayta yuklash ham tozalaydi**: `ip` bilan qo'shilgan hamma narsa (namespace, veth, route) va `sysctl -w` qiymatlari faqat xotirada turadi. Host'da `multipass restart lab` dan keyin VM toza tarmoq holatida ko'tariladi. Bu nuqson emas, laboratoriya uchun qulay "reset" tugmasi.
- **Oxirgi chora**: VM'ning o'zi ulanmay qolsa, host'da `multipass stop lab && multipass restore lab.clean` (`SETUP.md`). Bunda o'rnatilgan paketlar ham yo'qoladi, yuqoridagi `apt install` qatorlarini qayta bajarasiz.
- **Ikki mashina**: namespace'lar git orqali ko'chmaydi. Ikkinchi mashinada topologiyani qaytadan yig'asiz; 21-vazifadagi `netlab.sh` yozilgach bu bitta buyruq bo'ladi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM interfeysi odatda `ens3`, manzili `10.x.x.x/24`, gateway host'dagi `mpqemubr0` bridge'i. Host'ning o'zi Linux: ixtiyoriy ravishda `ip route` va `ip route get 1.1.1.1` ni host'da ham ko'rish mumkin (faqat o'qish). `traceroute` da VM'dan keyingi hop'lar ofis tarmog'i |
| macOS (uy) | VM interfeysi odatda `enp0s1`, manzili `192.168.64.x/24`, gateway host'dagi `bridge100`. Host'da `ip` yo'q, o'qish uchun muqobillar: `netstat -rn` (butun jadval) va `route -n get 1.1.1.1` (bitta manzil uchun qaror). `traceroute` macOS'da bor. Host'dagi Docker yashirin Linux VM ichida ishlaydi, uning `docker0` va route'lari Mac'da ko'rinmaydi, shuning uchun Docker bu darsda ham faqat `lab` VM ichida |

---

## 1. Routing table: har host'da bor jadval

### Bu nima

**Routing** bu paketni manzil IP'siga qarab keyingi qadamga yo'naltirish. **Routing table** (yo'nalish jadvali) kernel ichidagi ro'yxat: har qatori (**route**) "shu prefiksdagi manzillarga paketni shu interfeysdan, shu qo'shniga ber" degan qoida. Prefiks bu 3-darsdagi CIDR yozuvi (`10.0.1.0/24`): manzilning boshidagi nechta bit mos kelishi kerakligi. Jadval faqat router'da emas, har host'da bor: noutbukda, VM'da, konteynerda. Dastur `connect()` qilganda yoki `ping` paket yuborganda kernel har chiquvchi paket uchun bitta savolga javob beradi: "bu manzilga qaysi interfeysdan va kimga (next hop) yuboraman?"

### Misol: `lab` VM jadvali

```
ubuntu@lab:~$ ip route
default via <GW> dev <IF> proto dhcp src <VM_IP> metric 100
<NET>/24 dev <IF> proto kernel scope link src <VM_IP> metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
```

Sizda `<GW>` ga `/32` li yana bir `proto dhcp scope link` qatori bo'lishi mumkin (DHCP mijoz gateway yoki DNS server uchun qo'shadi), `docker0` qatori esa faqat Docker o'rnatilgan bo'lsa chiqadi. Qatorma-qator:

- 1-qator: `default` bu `0.0.0.0/0`, ya'ni "istalgan manzil". `via <GW>`: paket shu router'ga beriladi. `dev <IF>`: shu interfeysdan chiqadi. `proto dhcp`: bu qatorni DHCP mijoz qo'shgan (3-dars: DHCP javobida gateway ham keladi).
- 2-qator: VM'ning o'z tarmog'i. `via` yo'q, `scope link` bor: bu manzillar shu kabelning (bu yerda virtual bridge'ning) narigi uchida, vositachisiz. `proto kernel`: interfeysga manzil berilganda kernel o'zi qo'shgan.
- 3-qator: Docker bridge tarmog'i (1-dars, 6-bo'lim). `linkdown`: hozir `docker0` ga hech qanday konteyner ulanmagan, interfeysda signal yo'q.

| Maydon | Ma'nosi |
|--------|---------|
| `<NET>/24`, `default` | prefiks: qator qaysi manzillar uchun |
| `via <GW>` | **next hop**: paket topshiriladigan keyingi router. Shu router **gateway** deyiladi |
| `dev <IF>` | chiqish interfeysi |
| `scope link` | manzillar shu interfeysda to'g'ridan-to'g'ri yetib bo'ladi, next hop kerak emas |
| `proto kernel` / `dhcp` / `static` | qatorni kim qo'shgan: kernel, DHCP mijoz, administrator. Faqat belgi, tanlovga ta'sir qilmaydi |
| `src <VM_IP>` | shu route bo'yicha chiqadigan paketga qo'yiladigan manba IP (dastur o'zi tanlamagan bo'lsa) |
| `metric 100` | bir xil prefiksli route'lar orasida ustuvorlik, kichigi yutadi |

O'z qiymatlaringiz: `<IF>` va `<VM_IP>` ni `ip -br addr`, `<GW>` ni `ip route show default` ko'rsatadi.

### Uch xil route

| Tur | Belgisi | Qanday paydo bo'ladi |
|-----|---------|----------------------|
| **Connected** (on-link) | `scope link`, `via` yo'q | interfeysga prefiksli manzil berilganda kernel avtomatik qo'shadi |
| **Static** | odatda `via X` | administrator qo'lda yoki konfiguratsiya fayli orqali qo'shadi (4-bo'lim) |
| **Default** | `default via X` | DHCP'dan keladi yoki qo'lda qo'shiladi; "boshqa hech narsa mos kelmasa" |

**Default gateway** bu default route'ning next hop'i: "bilmaganimning hammasini shunga beraman". Oddiy host'da odatda bitta connected va bitta default route bor, shu ikkitasi butun internetga yetadi, chunki qolgan qarorni gateway va undan keyingi router'lar qabul qiladi.

### Mexanizm: next hop'ga qanday yetkaziladi

Route tanlangach kernel frame yasashi kerak, frame'ga esa MAC manzil kerak (1-dars: Ethernet frame). Ikki holat:

- **Connected route**: manzil shu LAN'da. Kernel manzil IP'sining o'zi uchun ARP so'raydi (1-dars, 5-bo'lim: "bu IP kimda?") va frame'ni o'sha MAC'ga yuboradi.
- **Gateway orqali**: kernel `via` dagi IP uchun ARP so'raydi va frame'ni **gateway'ning MAC'iga** yuboradi. IP header'dagi manzil esa o'zgarmaydi, u oxirgi manzil bo'lib qoladi.

Ya'ni `via` dagi IP paketning ichiga hech qachon yozilmaydi, u faqat "qaysi MAC'ga" savoliga javob topish uchun kerak. Shundan qoida: gateway o'zi connected tarmoqda bo'lishi shart, aks holda uning MAC'ini topib bo'lmaydi va kernel bunday route'ni qabul qilmaydi (18-vazifa). Buni `ip neigh` da ko'rasiz: internetga ping qilgandan keyin neighbour jadvalida `1.1.1.1` emas, `<GW>` paydo bo'ladi.

```
ubuntu@lab:~$ ping -c 1 1.1.1.1 > /dev/null; ip neigh
<GW> dev <IF> lladdr <GW_MAC> REACHABLE
```

Har router shu ishni takrorlaydi: frame'ni ochadi, IP manzilni o'z jadvalidan qidiradi, yangi frame'ga o'raydi. 2-darsdagi qoida shu yerdan: MAC manzillar har hop'da almashadi, IP manzillar boshidan oxirigacha o'sha.

### macOS host'da o'sha jadval (ixtiyoriy)

```
% netstat -rn -f inet
Destination        Gateway            Flags     Netif Expire
default            192.168.1.1        UGScg       en0
192.168.64         link#<N>           UC      bridge100      !
```

Ustunlar boshqacha nomlangan, ma'no o'sha: `Destination` prefiks (`192.168.64` qisqartirilgan `192.168.64.0/24`), `Gateway` next hop yoki connected uchun `link#<N>`, `Netif` interfeys. `Flags` dagi `U` route ishlayapti, `G` gateway orqali degani. `route -n get 1.1.1.1` esa bitta manzil uchun `gateway:` va `interface:` qatorlarini beradi, bu Linux'dagi `ip route get` ning o'xshashi.

### Real ishda qachon kerak

- "Server internetga chiqmayapti": birinchi buyruq `ip route`, default route bormi va to'g'ri interfeysdami.
- Cloud'da VPC **route table** aynan shu jadval, faqat konsolda: "`0.0.0.0/0` → internet gateway" qatori bor subnet public, yo'q subnet private deyiladi.
- Docker host'ida har bridge tarmog'i uchun bittadan connected route turadi; Kubernetes node'ida har qo'shni node'ning pod tarmog'i uchun bittadan route (yoki tunnel interfeysi) bo'ladi.

### Nima uchun shunday

Jadval har host'da bo'lishi IP'ning asosiy g'oyasidan keladi: hech kim butun yo'lni bilmaydi, har tugun faqat keyingi qadamni biladi (hop-by-hop). Muqobili yuboruvchi butun yo'lni paketga yozib qo'yishi (source routing) edi; u IP'da bor, lekin xavfsizlik sababli deyarli hamma joyda o'chirilgan, chunki yuboruvchiga tarmoqni aylanib o'tish imkonini beradi. Hop-by-hop sxemada yo'ldagi kanal uzilsa faqat qo'shni router'lar jadvalini yangilaydi, yuboruvchi buni bilmaydi ham.

## 2. Longest prefix match va `ip route get`

### Qoida

Bitta manzilga bir nechta route mos kelishi mumkin: `10.1.2.3` ham `10.0.0.0/8` ga, ham `10.1.2.0/24` ga, ham `default` ga kiradi. Kernel **eng uzun prefiksli** (eng aniq, eng tor) route'ni tanlaydi. Bu **longest prefix match**. Jadvaldagi qatorlar tartibi ahamiyatsiz. **Metric** faqat prefiks uzunligi ham, prefiksning o'zi ham bir xil bo'lgan route'lar orasida solishtiriladi: `/24` metric 500 bilan ham `/16` metric 1 dan ustun.

| Route'lar | Manzil | Tanlanadi | Sabab |
|-----------|--------|-----------|-------|
| `default`, `10.0.0.0/8 via A`, `10.1.0.0/16 via B`, `10.1.2.0/24 via C` | `10.1.2.3` | `/24`, C | to'rttasi ham mos, eng uzuni `/24` |
| | `10.1.9.9` | `/16`, B | uchinchi oktet `9`, `/24` ga mos emas |
| | `10.200.0.1` | `/8`, A | ikkinchi oktet `200`, `/16` ga mos emas |
| | `8.8.8.8` | `default` | faqat `/0` mos |

"Mos keladi" degani 3-darsdagi hisob: manzilning birinchi N biti prefiksning birinchi N biti bilan bir xil. Prefiks oktet chegarasiga tushmasa (`/22`, `/20`) hisobni ikkilik ko'rinishda qilish kerak, ko'z bilan chamalash xato beradi.

### Misol: kernel'dan qarorni so'rash

Jadvalni ko'z bilan tahlil qilish o'rniga `ip route get <manzil>` kernel'ning o'zidan "bu manzilga paket yuborsam nima qilasan?" deb so'raydi. Paket yuborilmaydi, faqat qaror ko'rsatiladi.

```
ubuntu@lab:~$ ip route get 8.8.8.8
8.8.8.8 via <GW> dev <IF> src <VM_IP> uid 1000
    cache
ubuntu@lab:~$ ip route get 172.17.0.5
172.17.0.5 dev docker0 src 172.17.0.1 uid 1000
    cache
ubuntu@lab:~$ ip route get 127.0.0.1
local 127.0.0.1 dev lo src 127.0.0.1 uid 1000
    cache <local>
```

Birinchi natija: `via <GW>` bor, demak default route tanlandi; `src <VM_IP>` paketga qo'yiladigan manba manzil; `uid 1000` so'rov qaysi foydalanuvchi nomidan hisoblangani (qoidalar foydalanuvchiga ham bog'lanishi mumkin, 4-bo'lim). Ikkinchi natija: `via` yo'q, manzil `docker0` da on-link, manba IP ham shu interfeysniki. Uchinchi natija `local` so'zi bilan boshlanadi: manzil shu host'ning o'ziniki, paket tarmoqqa chiqmaydi, `lo` orqali o'ziga qaytadi. `cache` qatori tarixiy qoldiq, e'tibor bermang.

### Mos route bo'lmasa: xato matnlari

Xato matni muammo qayerdaligini aytadi. Farqlash tashxisning yarmi:

| Xato | Kim aytadi | Ma'nosi |
|------|-----------|---------|
| `Network is unreachable` | o'z kernel'ingiz, darhol | jadvalda mos route yo'q (default ham yo'q). Paket umuman chiqmagan |
| `Destination Host Unreachable` (`ping` da `From <o'z IP>`) | o'z kernel'ingiz, bir necha soniyadan keyin | route bor, lekin next hop yoki on-link manzil ARP'ga javob bermadi. Dasturlarda shu holat `No route to host` deb chiqadi |
| `No route to host` | o'z kernel'ingiz yoki yo'ldagi qurilmadan kelgan ICMP | yuqoridagi ARP holati, yoki firewall paketni `reject` qildi (6-dars) |
| `Destination Net Unreachable` (`ping` da `From X`) | yo'ldagi router `X` | paket `X` gacha yetdi, lekin `X` ning jadvalida manzilga route yo'q |
| javob yo'q, timeout | hech kim | paket yoki uning javobi yo'lda jim tashlanmoqda (forwarding o'chiq, qaytish yo'li yo'q, firewall `drop`) |

**ICMP** (2-dars) IP'ning xizmat protokoli: `ping` ham, router'larning "yetkaza olmadim" xabarlari ham ICMP paketlar. Jadvaldagi 4-qator shunday xabar.

### Real ishda qachon kerak

- VPN ulangach "ichki servis ochilmayapti": `ip route get <servis IP>` paket tunnel'ga ketyaptimi yoki oddiy interfeysgami, bir qatorda ko'rsatadi.
- VPN'lar default route'ni o'chirmasdan butun trafikni o'ziga olish uchun `0.0.0.0/1` va `128.0.0.0/1` qo'shadi: ikkalasi birgalikda hamma manzilni qamraydi va `/0` dan aniqroq, shuning uchun yutadi.
- Docker tarmog'i `172.17.0.0/16` korporativ tarmoqdagi shu diapazon bilan kesishsa (3-dars), connected route aniqroq bo'lib, o'sha serverlarga ketishi kerak bo'lgan trafik `docker0` ga buriladi.

### Nima uchun shunday

Longest prefix match jadvalni ixcham qiladi: "hammasi u yoqqa, faqat mana shu kichik bo'lak bu yoqqa" degan istisnoni bitta qo'shimcha qator bilan yozish mumkin. Muqobili firewall qoidalaridagi kabi "birinchi mos kelgan yutadi" tartibi bo'lardi; unda natija qatorlar tartibiga bog'liq bo'lib, million prefiksli internet jadvallarini router'lar orasida birlashtirish imkonsiz edi. Aniqlik bo'yicha tanlashda tartib kerak emas, har router jadvalni istalgan ketma-ketlikda yig'adi va natija bir xil.

## 3. Yo'lni kuzatish: TTL, traceroute, mtr

### TTL nima

IP header'da **TTL** (Time To Live) degan bir baytli maydon bor. Yuboruvchi unga boshlang'ich qiymat qo'yadi (Linux'da 64), har router paketni uzatishdan oldin uni bittaga kamaytiradi. Nolga tushsa router paketni tashlaydi va yuboruvchiga ICMP "Time exceeded" xabarini qaytaradi. Maqsad: jadvallardagi xato tufayli aylanaga tushib qolgan paket tarmoqda abadiy yurmasin.

### traceroute mexanizmi

`traceroute` shu himoya mexanizmidan ataylab foydalanadi. U TTL=1 bilan zond yuboradi: birinchi router uni tashlaydi va "Time exceeded" qaytaradi, xabarning manba manzili birinchi router'ning IP'si. Keyin TTL=2, 3 va hokazo. Har javobning manbasi yo'ldagi navbatdagi router. Zond manzilga yetganda manzil boshqa turdagi javob beradi (UDP zondga ICMP "Port unreachable", chunki zond ataylab hech kim tinglamaydigan yuqori portga yuboriladi) va `traceroute` to'xtaydi.

```
ubuntu@lab:~$ traceroute -n 1.1.1.1
traceroute to 1.1.1.1 (1.1.1.1), 30 hops max, 60 byte packets
 1  <GW>  0.412 ms  0.380 ms  0.351 ms
 2  192.168.1.1  2.104 ms  1.987 ms  2.250 ms
 3  * * *
 4  <ISP router>  6.310 ms  6.122 ms  7.045 ms
 ...
 9  1.1.1.1  18.420 ms  18.377 ms  18.501 ms
```

Sarlavha: eng ko'pi 30 hop sinab ko'riladi. Har qator bitta TTL qiymati: tartib raqami, javob bergan router manzili, uchta zondning borib kelish vaqti. 1-hop Multipass host'idagi gateway, 2-hop uy yoki ofis router'i (private manzil), keyin provayder. `-n` nomlarni DNS'dan qidirmaydi, natija tez chiqadi. `* * *`: shu TTL uchun uch zondga ham javob kelmadi.

```
traceroute -n 1.1.1.1                  # UDP probes by default, 3 per hop
sudo traceroute -n -I 1.1.1.1          # ICMP echo probes
sudo traceroute -n -T -p 443 1.1.1.1   # TCP SYN to port 443
tracepath -n 1.1.1.1                   # no root needed, also reports path MTU
mtr -n 1.1.1.1                         # live view, quit with q
mtr -rwn -c 10 1.1.1.1                 # report mode, 10 cycles, suitable for pasting
```

`mtr` traceroute va ping'ni birlashtiradi: har hop'ga qayta-qayta zond yuborib statistika yig'adi.

```
ubuntu@lab:~$ mtr -rwn -c 10 1.1.1.1
Start: <sana va vaqt>
HOST: lab        Loss%   Snt   Last   Avg  Best  Wrst StDev
  1.|-- <GW>      0.0%    10    0.4   0.4   0.3   0.6   0.1
  2.|-- 192.168.1.1  0.0%    10    2.1   2.2   1.9   3.0   0.3
  3.|-- ???      100.0%   10    0.0   0.0   0.0   0.0   0.0
  ...
  9.|-- 1.1.1.1   0.0%    10   18.4  18.6  18.1  19.9   0.5
```

`Loss%` javobsiz qolgan zondlar ulushi, `Snt` yuborilgan zondlar soni, `Last`/`Avg`/`Best`/`Wrst` oxirgi, o'rtacha, eng yaxshi va eng yomon kechikish (ms), `StDev` tarqoqlik. `???` javob bermagan hop.

### Chiqishni to'g'ri o'qish

- `* * *` yoki `???` oraliq hop'da, keyingi hop'lar ko'rinadi: muammo emas. Ko'p router ICMP javob bermaydi yoki cheklaydi, tranzit paketlarni esa uzataveradi.
- mtr'da oraliq hop'da yo'qotish bor, oxirgi hop'da 0%: o'sha router faqat o'z ICMP javoblarini cheklayapti (rate limit). Haqiqiy yo'qotish o'sha hop'dan boshlab **oxirigacha** davom etadi.
- Kechikish bir hop'da keskin oshib, keyingilarda ham saqlansa: o'sha kanal uzun (masalan qit'alararo). Bitta hop'da baland, keyin yana past bo'lsa: router ICMP'ga sekin javob beryapti, xolos.
- Bir hop'da bir nechta har xil manzil: yuk bir nechta teng yo'lga taqsimlangan (ECMP, Equal-Cost Multi-Path).

**Tuzoq: traceroute faqat borish yo'lini ko'rsatadi.** Internetda javob ko'pincha boshqa yo'ldan qaytadi (asymmetric routing, 5-bo'lim). Muammo qaytish yo'lida bo'lsa, sizning traceroute'ingiz toza ko'rinadi. To'liq tashxis uchun ikkala tomondan o'lchash kerak.

**Tuzoq: sukut bo'yicha UDP zondlar.** Firewall yuqori UDP portlarni tashlasa, yo'l oxirida faqat yulduzchalar chiqadi, garchi TCP 443 ishlab tursa ham. Servis portiga `-T -p <port>` bilan tekshiring.

macOS host'da `traceroute -n 1.1.1.1` shu ko'rinishda ishlaydi (faqat o'qish, ixtiyoriy); farqi: 1-hop darhol uy router'i, chunki oraliqda Multipass gateway'i yo'q.

### Real ishda qachon kerak

- "Sayt sekin": `mtr` kechikish qaysi hop'dan boshlanishini ko'rsatadi: sizning tarmog'ingiz, provayder yoki manzil tomoni.
- Provayder yoki cloud support'iga murojaatda birinchi so'raladigan narsa ikkala tomondan olingan `mtr -rwn` hisoboti.
- Kubernetes'da pod'dan tashqi servisga yo'l: node, NAT gateway va undan keyingi hop'lar shu asbob bilan ko'rinadi.

### Nima uchun shunday

TTL dastlab soniyalarda o'lchanadigan "yashash vaqti" sifatida o'ylangan, amalda hop hisoblagichiga aylangan (IPv6'da maydon nomi ham `Hop Limit`). traceroute protokolga keyin qo'shilgan hiyla: yo'lni so'raydigan maxsus xabar yo'q, shuning uchun u xato xabarlaridan foydalanadi. Zaifligi ham shundan: router javob berishga majbur emas, natija har doim taxminiy.

## 4. Static route, doimiy sozlama, policy routing

### Route qo'shish va o'chirish

**Static route** bu qo'lda yozilgan qoida: "shu prefiks shu gateway orqali". Sintaksis (misollar umumiy, manzillar ixtiyoriy; faqat namespace ichida bajaring):

```
sudo ip route add 10.20.0.0/16 via 192.168.1.254        # via a gateway
sudo ip route add 10.30.0.0/24 dev wg0                  # on-link through an interface
sudo ip route replace 10.20.0.0/16 via 192.168.1.253    # add, or change if it exists
sudo ip route del 10.20.0.0/16
sudo ip route add blackhole 10.99.0.0/16                # drop silently
```

`add` mavjud prefiks uchun `RTNETLINK answers: File exists` xatosini beradi, `replace` esa bermaydi; skriptlarda shu farq muhim (21-vazifa). `blackhole` turidagi route paketni hech qayerga yubormaydi, jim tashlaydi: hujum ostidagi manzilni vaqtincha "o'chirish" uchun ishlatiladi.

### Doimiy qilish

`ip route` o'zgarishlari faqat kernel xotirasida: reboot'da ham, interfeys `down` bo'lib qayta `up` bo'lganda ham yo'qoladi ("Birga bajaramiz", 7-qadam). Ubuntu server'da doimiy route **netplan** faylida (`/etc/netplan/*.yaml`) yoziladi; netplan bu Ubuntu'ning tarmoq konfiguratsiya qatlami, YAML'ni o'qib tarmoq servisiga uzatadi:

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

Qo'llash: `sudo netplan try` (ma'lum vaqt ichida tasdiqlamasangiz eski holatga o'zi qaytaradi), keyin `sudo netplan apply`. Bu darsda netplan fayli o'zgartirilmaydi, faqat qayerda turishini biling.

### Policy routing

Aslida jadval bitta emas, bir nechta, va qaysi biridan qidirilishini **qoidalar** (rule) hal qiladi:

```
ubuntu@lab:~$ ip rule show
0:      from all lookup local
32766:  from all lookup main
32767:  from all lookup default
ubuntu@lab:~$ ip route show table local
local 127.0.0.0/8 dev lo proto kernel scope host src 127.0.0.1
local 127.0.0.1 dev lo proto kernel scope host src 127.0.0.1
broadcast 127.255.255.255 dev lo proto kernel scope link src 127.0.0.1
local <VM_IP> dev <IF> proto kernel scope host src <VM_IP>
broadcast <BROADCAST> dev <IF> proto kernel scope link src <VM_IP>
```

Chapdagi raqam qoidaning ustuvorligi, kichigi birinchi tekshiriladi. `from all` shart (istalgan manba), `lookup <jadval>` qaysi jadvalga qarash. Mos route topilmasa keyingi qoidaga o'tiladi. `ip route` sukut bo'yicha `main` jadvalini ko'rsatadi. `local` jadvalini kernel o'zi yuritadi: unda host'ning o'z manzillari (`local`) va broadcast manzillar turadi; 2-bo'limdagi `ip route get 127.0.0.1` javobi shu yerdan chiqqan. `default` jadvali odatda bo'sh.

Qo'shimcha qoida bilan "manba IP shunday bo'lsa boshqa jadvalga qara" deyish mumkin. Buni ikki provayderli host'lar, WireGuard (`wg-quick`) va ba'zi Kubernetes CNI plugin'lari ishlatadi. Docker o'rnatilgan VM'da ham qo'shimcha qoida ko'rmasligingiz normal, Docker `ip rule` ishlatmaydi.

### Real ishda qachon kerak

- Ofis va cloud orasidagi VPN: cloud prefiksi uchun tunnel interfeysiga static route.
- `ip route` to'g'ri ko'rinadi, paket esa boshqa yoqqa ketadi: `ip rule show` ni ko'ring. `ip route get` esa qoidalarni ham hisobga olgan yakuniy javobni beradi.
- Masofadagi serverda tarmoq sozlamasini o'zgartirish: har doim `netplan try` yoki konsol kirishi bilan, aks holda SSH uzilib qaytib kira olmaysiz.

### Nima uchun shunday

`ip` buyruqlari vaqtinchalik ekani ataylab: xato route reboot bilan tuzaladi, konfiguratsiya fayli esa yagona haqiqat manbai bo'lib qoladi. Bir nechta jadval esa "manzilga qarab" tanlash yetmaydigan holatlar uchun qo'shilgan: bitta `main` jadvali faqat manzil IP'ga qaraydi, qoidalar esa manba IP, kirish interfeysi yoki paket belgisiga qarab boshqa jadvalni tanlash imkonini beradi.

## 5. Linux router: forwarding, qaytish yo'li, rp_filter

### Forwarding nima

Host'ga uning o'ziga tegishli bo'lmagan manzilli paket kelsa (frame uning MAC'iga yuborilgan, lekin IP manzil boshqa), sukut bo'yicha kernel uni **tashlaydi**. **Forwarding** yoqilsa kernel bunday paketni o'z routing table'idan qidirib, boshqa interfeysdan uzatadi. Router bilan oddiy host'ning butun farqi shu bitta sozlama: **router** bu kamida ikki tarmoqqa ulangan va forwarding yoqilgan host.

```
ubuntu@lab:~$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 0
```

`0` host rejimi, `1` router rejimi. `sysctl` kernel parametrlarini o'qiydi va yozadi (`/proc/sys/` ostidagi fayllar). VM'da Docker o'rnatilgan bo'lsa qiymat `1` chiqadi: Docker ishga tushganda uni o'zi yoqadi, chunki host konteynerlar uchun router.

```
sudo sysctl -w net.ipv4.ip_forward=1    # until reboot; run it inside a namespace in this lesson
# persistent: /etc/sysctl.d/99-forward.conf with "net.ipv4.ip_forward = 1", then: sudo sysctl --system
```

IPv6 uchun alohida parametr: `net.ipv6.conf.all.forwarding`.

### Mexanizm: router paket bilan nima qiladi

1. Frame keladi, manzil MAC router'niki. Router frame'ni ochadi.
2. Manzil IP router'ning o'z manzillaridan birimi? Ha bo'lsa bu **local delivery**: paket router'ning o'ziga, forwarding kerak emas. Linux o'zining istalgan interfeysidagi manzilga kelgan paketni qaysi interfeysdan kirganidan qat'i nazar qabul qiladi.
3. Yo'q bo'lsa va forwarding `0`: paket jim tashlanadi, hech qanday xato qaytmaydi.
4. Forwarding `1`: routing table'dan route qidiriladi (longest prefix match), TTL bittaga kamaytiriladi, chiqish interfeysida next hop MAC'i ARP bilan topiladi, yangi frame yasab yuboriladi.

IP manzillarga tegilmaydi. Manzilni almashtirish NAT deyiladi va alohida mexanizm (6-dars).

### Qaytish yo'li

Ping, TCP, HTTP: hammasi ikki tomonlama. A dan B ga yo'l borligi yetmaydi: B javob paketini yuborganda **o'z** jadvalidan A ning manziliga route qidiradi, yo'ldagi har router ham shunday. Biror joyda route yo'q bo'lsa javob yo'qoladi yoki default gateway orqali noto'g'ri yoqqa ketadi. A tomondan bu "paket bormayapti" kabi ko'rinadi, aslida boryapti. Alomati: B dagi `tcpdump` so'rov kelganini ko'rsatadi, javob esa chiqmaydi yoki boshqa interfeysdan chiqadi. Shuning uchun tashxisda har ikki tomonda `ip route get <qarshi tomon IP>` tekshiriladi.

### Asymmetric routing va reverse path filtering

Borish va qaytish yo'li har xil bo'lishi **asymmetric routing** deyiladi. Internetda bu oddiy holat, lekin bir nechta interfeysli host'da bitta himoya bilan to'qnashadi. **Reverse path filtering** (`rp_filter`): kernel kelgan paketning manba manzilini tekshiradi: "shu manbaga javob yuborsam, qaysi interfeysdan chiqardi?"

| Qiymat | Rejim | Qoida |
|--------|-------|-------|
| `0` | o'chiq | tekshiruv yo'q |
| `1` | strict | javob aynan paket kirgan interfeysdan chiqadigan bo'lsagina qabul qilinadi |
| `2` | loose | manba IP istalgan interfeys orqali yetib bo'ladigan bo'lsa yetarli |

```
ubuntu@lab:~$ sysctl net.ipv4.conf.all.rp_filter net.ipv4.conf.default.rp_filter
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
```

Ubuntu'da odatda `2` (sizda boshqa bo'lsa o'z qiymatingizni yozing). Har interfeys uchun amaldagi qiymat `conf.all` va `conf.<iface>` dan kattasi. Strict rejimda asymmetric yo'ldan kelgan paket jim tashlanadi: xato yo'q, log yo'q (`log_martians` yoqilmagan bo'lsa), `tcpdump` paket kelganini ko'rsatadi, dastur esa uni olmaydi.

### Real ishda qachon kerak

- Docker host: konteyner `172.17.0.x` dan internetga chiqqanda host aynan shu ishni bajaradi (forwarding, ustiga NAT).
- Kubernetes node'i pod'lar uchun router: `ip_forward=0` bo'lsa pod'lar o'z node'idan tashqariga chiqa olmaydi, shuning uchun o'rnatish qo'llanmalari uni yoqishni talab qiladi.
- Cloud'da NAT instans yoki VPN server vazifasidagi VM: forwarding yoqilishi shart; AWS'da qo'shimcha "source/destination check" ham o'chiriladi, u `rp_filter` ga o'xshash tekshiruv, faqat cloud tarmog'i tomonida.
- "Ping bormayapti" shikoyatlarining katta qismi borish emas, qaytish yo'lida.

### Nima uchun shunday

Forwarding sukut bo'yicha o'chiq, chunki ikki tarmoqqa ulangan oddiy server (masalan public va ichki interfeysli) bilmagan holda ular orasida ko'prik bo'lib qolmasligi kerak: bu ichki tarmoqni tashqariga ochib qo'yadi. `rp_filter` esa soxta manba manzilli (spoofed) paketlarga qarshi: "bu manba bu interfeysdan kelishi mumkin emas" degan paket tashlanadi. Strict rejim xavfsizroq, lekin asymmetric yo'llarni buzadi, loose rejim shu ikki talab orasidagi murosa.

## 6. Network namespace va veth bilan laboratoriya

### Bu nima

**Network namespace** kernel ichidagi alohida tarmoq stack'i: o'z interfeyslari, o'z routing table'i va qoidalari, o'z neighbour (ARP) jadvali, o'z firewall qoidalari, o'z `ip_forward` sozlamasi, o'z portlari. Jarayon qaysi namespace'da ishlasa, faqat o'shaning tarmog'ini ko'radi. VM yuklanganda bitta asosiy namespace bor, hamma jarayon shunda. Konteynerning "o'z tarmog'i" deganimiz aynan alohida network namespace. Bitta VM ichida bir nechta namespace yaratib, ularni **veth** juftliklari (1-dars: ikki uchli virtual kabel, bir uchiga kirgan frame ikkinchisidan chiqadi) bilan ulasak, har biri alohida host yoki router kabi ishlaydigan to'liq topologiya hosil bo'ladi.

### Misol: bo'sh namespace

```
ubuntu@lab:~$ sudo ip netns add demo
ubuntu@lab:~$ sudo ip netns list
demo
ubuntu@lab:~$ sudo ip -n demo -br link
lo               DOWN           00:00:00:00:00:00 <LOOPBACK>
ubuntu@lab:~$ sudo ip -n demo route
ubuntu@lab:~$ sudo ip netns exec demo sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = <0 yoki 1>
ubuntu@lab:~$ sudo ip netns delete demo
```

Yangi namespace'da faqat `lo` bor va u `DOWN`; routing table bo'sh (ikkinchi buyruq hech narsa chiqarmadi), VM'ning `<IF>` interfeysi bu yerdan ko'rinmaydi. `ip -n <ns> ...` namespace ichida `ip` buyrug'ini bajarishning qisqa shakli; istalgan boshqa buyruq uchun `ip netns exec <ns> <buyruq>` (masalan `ping`, `tcpdump`, `sysctl`, `python3`).

**Diqqat: `ip_forward` ning boshlang'ich qiymati.** Yangi namespace IPv4 sozlamalarining boshlang'ich qiymatini yaratilish paytida VM'ning asosiy namespace'idan ko'chirib oladi (kernel'ning `devconf_inherit_init_net` parametri, sukut bo'yicha shunday). VM'da Docker bo'lsa asosiy namespace'da `ip_forward = 1`, demak yangi namespace ham `1` bilan tug'iladi. Yaratilgandan keyin qiymatlar mustaqil: birini o'zgartirish ikkinchisiga ta'sir qilmaydi. Shuning uchun "forwarding'siz" tajribalarda (10, 11-vazifalar) taxmin qilmang: router namespace'ida qiymatni tekshiring va kerak bo'lsa `0` ga qo'ying.

### Ikki namespace'ni kabel bilan ulash (namuna)

```
sudo ip link add veth-a type veth peer name veth-b    # create the pair in the main namespace
sudo ip link set veth-a netns ns1                     # move one end into ns1
sudo ip link set veth-b netns ns2
sudo ip -n ns1 addr add 10.0.0.1/24 dev veth-a        # the prefix creates the connected route
sudo ip -n ns1 link set veth-a up
sudo ip -n ns1 link set lo up
```

Qoidalar:

- `127.0.0.1` ishlashi uchun har namespace'da `lo` ni ham `up` qiling.
- veth'ning ikkala uchi ham `up` bo'lishi kerak, aks holda holat `NO-CARRIER` (kabelning bir uchi uzilgan).
- Manzil prefiks bilan beriladi (`/24`): connected route shu prefiksdan yasaladi (1-bo'lim).
- Namespace o'chirilsa ichidagi veth uchi yo'qoladi, juftning ikkinchi uchi ham u bilan birga.
- `ip_forward` har namespace'da alohida: `sudo ip netns exec router sysctl -w net.ipv4.ip_forward=1`.
- Ikkidan ortiq host'ni bitta LAN'ga ulash uchun switch kerak. Linux'da bu **bridge** (1-dars): `sudo ip link add br0 type bridge`, `sudo ip link set br0 up`, keyin har veth'ning bridge tomondagi uchi `sudo ip link set <veth> master br0` bilan port qilib ulanadi. Docker'ning `docker0` i shu.

### Maqsad topologiya (vazifalarda yig'asiz)

```
[client]                    [router]                    [server]
10.0.1.2/24 ---veth--- 10.0.1.1/24  10.0.2.1/24 ---veth--- 10.0.2.2/24
```

Uchta namespace, ikkita veth juftligi, ikkita `/24` tarmoq. `router` ikkala tarmoqqa ulangan, `client` va `server` bittadan.

### Real ishda qachon kerak

- Docker aynan shuni qiladi: har konteynerga namespace, veth juftligi, bir uchi `docker0` bridge'ga, host'da forwarding va NAT (1-dars 6-bo'lim, 6-dars).
- Kubernetes CNI plugin'lari ham shu primitivlardan foydalanadi, faqat node'lar orasidagi route'larni qo'shimcha boshqaradi. "Pod boshqa node'dagi pod'ni ko'rmayapti" tashxisi shu darsdagi buyruqlar bilan qilinadi: `ip route`, `ip route get`, `tcpdump`.
- Tarmoq o'zgarishini (yangi route, firewall qoidasi) production'ga tegmasdan sinash: namespace'da bir daqiqada model yig'iladi.

### Nima uchun shunday

Namespace konteynerlar uchun yaratilgan: bitta kernel ustida bir-birini ko'rmaydigan tarmoqlar kerak edi. VM bilan solishtirganda u juda arzon: yangi kernel yuklanmaydi, faqat kernel ichidagi jadvallarning yangi nusxasi ochiladi, shuning uchun o'nlab "host" bitta kichik VM'ga sig'adi. Muqobili har host uchun alohida VM (modul rejasidagi `net1`, `net2`): ular haqiqiy alohida mashina kerak bo'lgan joyda (SSH, WireGuard) ishlatiladi, routing uchun esa namespace yetarli.

## 7. Internet miqyosida: AS va BGP

### Muammo

`lab` VM jadvalida uch qator bor. Internet magistralidagi router'da esa milliondan ortiq IPv4 prefiks. Ularni qo'lda yozib bo'lmaydi, va ular doim o'zgarib turadi. Router'lar jadvalni **dinamik routing protokollari** orqali bir-biridan o'rganadi:

- **Tashkilot ichida** (IGP, Interior Gateway Protocol): OSPF, IS-IS. Maqsad: eng qisqa yo'l.
- **Tashkilotlar orasida** (EGP): **BGP** (Border Gateway Protocol). Maqsad: siyosat, ya'ni kim bilan va qanday shartnoma asosida trafik almashish.

**Autonomous System (AS)** bu bitta ma'muriyat ostidagi tarmoqlar to'plami (provayder, yirik kompaniya, universitet), o'z raqami (**ASN**) bilan. Private ASN diapazoni 64512–65534, private IP'larning o'xshashi.

### BGP qanday ishlaydi (eng sodda ko'rinishda)

1. Har AS qo'shnilariga "menda shu prefikslar bor" deb e'lon qiladi (announce), masalan `203.0.113.0/24`.
2. Qo'shni bu e'lonni o'z ASN'ini yo'l ro'yxatiga (**AS path**) qo'shib, o'z qo'shnilariga uzatadi.
3. Bir prefiksga bir nechta yo'l kelsa, router avval mahalliy siyosatni (local preference: mijozdan kelgan yo'l tekin peer'dan, u esa pullik transit'dan afzal), keyin eng qisqa AS path'ni tanlaydi.
4. Paketni uzatishda baribir longest prefix match amal qiladi (2-bo'lim): aniqroq prefiks e'lon qilgan tarmoq trafikni oladi.

Oxirgi band BGP'ning zaif joyi: kimdir sizning `/22` ingiz ichidan `/24` ni e'lon qilsa (xato bilan yoki ataylab), trafik unga ketadi. Bu **route leak** va **BGP hijack**, yirik global uzilishlarning takrorlanadigan sababi. Himoya: RPKI (e'lonlarni kriptografik tasdiqlash tizimi).

### Misol: yo'ldagi AS'larni ko'rish

```
ubuntu@lab:~$ mtr -rwzn -c 5 1.1.1.1
Start: <sana va vaqt>
HOST: lab                 Loss%   Snt   Last   Avg  Best  Wrst StDev
  1. AS???    <GW>         0.0%     5    0.4   0.4   0.3   0.5   0.1
  2. AS???    192.168.1.1  0.0%     5    2.0   2.1   1.9   2.4   0.2
  ...
  6. AS<N>    <ISP router> 0.0%     5    6.1   6.3   6.0   7.0   0.4
  9. AS13335  1.1.1.1      0.0%     5   18.2  18.4  18.1  19.0   0.3
```

`-z` har hop manzili qaysi AS'ga tegishli ekanini qidiradi. `AS???` private manzillar: ular hech qaysi AS'ga tegishli emas, internetda e'lon qilinmaydi. `AS13335` Cloudflare. Ustun o'zgargan joy trafik bir tashkilotdan boshqasiga o'tgan chegara. Prefiks kimga tegishli va kim bilan qo'shni ekanini https://bgp.he.net va https://bgp.tools ko'rsatadi.

### Real ishda qachon kerak

| Joy | Nima |
|-----|------|
| Cloud bilan ofis yoki data markaz ulanishi (VPN, AWS Direct Connect) | route'lar BGP orqali avtomatik almashinadi |
| Anycast | bitta IP (masalan `1.1.1.1`) dunyoning ko'p joyidan e'lon qilinadi, trafik BGP bo'yicha eng yaqiniga boradi: CDN va DNS shunday ishlaydi |
| Bare-metal Kubernetes | MetalLB (BGP rejimi) va Calico pod yoki service prefikslarini router'larga BGP bilan e'lon qiladi |
| Incident tahlili | "provayder X da route leak" degan xabarni o'qiy olish |

BGP daemon'larini sozlash bu modulga kirmaydi (modul rejasi, "Ataylab kiritilmagan").

### Nima uchun shunday

Internet yagona egasi yo'q tarmoqlar federatsiyasi. Har tashkilot ichida "eng qisqa yo'l" mantiqiy, lekin tashkilotlar orasida pul va shartnoma aralashadi: provayder raqobatchisining trafigini tekinga tashimaydi. Shuning uchun BGP eng tez yo'lni emas, siyosatga mos yo'lni tanlaydi. U ishonchga qurilgan (qo'shnining e'loni to'g'ri deb olinadi), hijack muammosi shu tarixiy qarorning oqibati.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Routing | paketni manzil IP'siga qarab keyingi qadamga yo'naltirish |
| Routing table | "qaysi prefiks, qaysi interfeys, qaysi next hop" qoidalari ro'yxati; har host'da bor |
| Route | routing table'ning bitta qatori |
| Prefiks | CIDR ko'rinishidagi manzillar to'plami (`10.0.1.0/24`) |
| Next hop | paket topshiriladigan keyingi router'ning IP'si (`via`) |
| Gateway | boshqa tarmoqqa chiqish uchun ishlatiladigan router |
| Default route | `0.0.0.0/0`, boshqa hech bir route mos kelmaganda ishlatiladi |
| Default gateway | default route'ning next hop'i |
| Connected (on-link) route | interfeysga manzil berilganda kernel qo'shadigan, next hop'siz route |
| Static route | administrator qo'lda qo'shgan route |
| Longest prefix match | mos kelgan route'lardan eng uzun prefikslisini tanlash qoidasi |
| Metric | bir xil prefiksli route'lar orasidagi ustuvorlik, kichigi yutadi |
| TTL | IP header'dagi hisoblagich, har router bittaga kamaytiradi, nolda paket tashlanadi |
| Hop | yo'ldagi bitta router'dan o'tish |
| ICMP Time exceeded | TTL nolga tushganda router yuboruvchiga qaytaradigan xabar |
| ECMP | bir manzilga bir nechta teng qiymatli yo'l orasida yukni taqsimlash |
| Blackhole route | mos kelgan paketni jim tashlaydigan route |
| netplan | Ubuntu'ning YAML asosidagi tarmoq konfiguratsiya qatlami |
| Policy routing | manzildan tashqari belgilarga (manba IP va boshqa) qarab routing table tanlash, `ip rule` |
| Forwarding | o'ziga tegishli bo'lmagan manzilli paketni boshqa interfeysdan uzatish (`ip_forward`) |
| Router | kamida ikki tarmoqqa ulangan va forwarding yoqilgan qurilma yoki host |
| Local delivery | manzili host'ning o'ziniki bo'lgan paketni qabul qilish, forwarding talab qilmaydi |
| Qaytish yo'li | javob paketining yo'li; har tugunda alohida route talab qiladi |
| Asymmetric routing | borish va qaytish yo'llari har xil bo'lgan holat |
| Reverse path filtering | kelgan paketning manba manzili shu interfeysdan kelishi mumkinligini tekshirish (`rp_filter`) |
| sysctl | kernel parametrlarini o'qish va yozish buyrug'i va mexanizmi |
| Network namespace | alohida interfeyslar, route'lar va firewall'ga ega tarmoq stack'i nusxasi |
| veth | ikki uchli virtual kabel, odatda ikki namespace'ni ulaydi |
| Bridge | Linux ichidagi virtual switch |
| AS, ASN | bitta ma'muriyat ostidagi tarmoqlar to'plami va uning raqami |
| BGP | AS'lar bir-biriga prefikslarni e'lon qiladigan routing protokoli |
| AS path | prefiks e'loni o'tgan AS'lar ro'yxati |
| Anycast | bitta IP'ni bir nechta joydan e'lon qilish, trafik eng yaqiniga boradi |

## Tuzoqlar

- Faqat borish yo'lini tekshirish. Qarshi tomonda sizning tarmog'ingizga route yo'q bo'lsa, javob default gateway orqali boshqa yoqqa ketadi.
- Router bo'lishi kerak bo'lgan host'da `ip_forward=0`: paketlar keladi va jim yo'qoladi. Yoki `sysctl -w` bilan yoqib, reboot'dan keyin yo'qotish.
- Yangi namespace'da forwarding "albatta o'chiq" deb o'ylash: boshlang'ich qiymat asosiy namespace'dan ko'chiriladi (6-bo'lim), har doim `sysctl` bilan tekshiring.
- Static route'ni `ip route add` bilan qo'shib, netplan'ga yozmaslik: reboot yoki interfeys qayta ko'tarilishi bilan yo'qoladi.
- Masofadagi serverda default route'ni o'chirish yoki almashtirish: SSH sessiyangiz uziladi va qaytib kira olmaysiz. `netplan try` yoki konsol kirishi bilan ishlang. Shu sababli bu darsda VM'ning asosiy jadvaliga ham tegilmaydi, faqat namespace'lar.
- Kesishadigan CIDR'lar (3-dars): Docker tarmog'i korporativ diapazon bilan to'qnashsa, connected route aniqroq bo'lib trafikni `docker0` ga buradi.
- mtr'dagi oraliq hop yo'qotishini "provayder paket yo'qotyapti" deb talqin qilish, oxirgi hop'ga qaramasdan.
- `ping` o'tmaganini routing muammosi deb hisoblash: ICMP filtrlangan bo'lishi mumkin. `ip route get`, `tcpdump` va TCP zond bilan tasdiqlang.
- VPN ulangach "internet yo'qoldi" yoki "ichki servislar ko'rinmayapti": VPN qo'shgan route'lar nimani qamrashini `ip route` va `ip rule` da ko'rmaslik.
- Namespace'da `lo` ni ko'tarishni unutish: `localhost` ga tayangan dasturlar ishlamaydi.
- Buyruqni noto'g'ri joyda bajarish: `sudo ip route add ...` da `-n <ns>` tushib qolsa route VM'ning asosiy jadvaliga yoziladi. Prompt yordam bermaydi, har buyruqda namespace nomini tekshiring.
- macOS host'da `ip` qidirish yoki Linux flag'larini `netstat`, `route` ga berish: host'da faqat o'qing, o'zgartirishlar VM'da.

## Manbalar

- https://man7.org/linux/man-pages/man8/ip-route.8.html – `ip route`
- https://man7.org/linux/man-pages/man8/ip-netns.8.html – `ip netns`
- https://man7.org/linux/man-pages/man8/ip-rule.8.html – `ip rule`
- https://man7.org/linux/man-pages/man7/network_namespaces.7.html – network namespace'lar
- https://man7.org/linux/man-pages/man4/veth.4.html – veth
- https://man7.org/linux/man-pages/man8/traceroute.8.html – `traceroute`
- https://www.kernel.org/doc/html/latest/networking/ip-sysctl.html – `ip_forward`, `rp_filter`, `devconf_inherit_init_net` va boshqa sysctl'lar
- https://netplan.readthedocs.io/en/stable/netplan-yaml/ – netplan YAML, `routes`
- https://baturin.org/docs/iproute2/ – iproute2 amaliy qo'llanma
- https://www.rfc-editor.org/rfc/rfc791 – IP, TTL maydoni
- https://www.rfc-editor.org/rfc/rfc792 – ICMP, "Time exceeded" va "Destination unreachable"
- https://www.rfc-editor.org/rfc/rfc1812 – IPv4 router'larga talablar (forwarding qoidalari)
- https://www.rfc-editor.org/rfc/rfc3704 – reverse path filtering (strict va loose rejimlar)
- https://www.rfc-editor.org/rfc/rfc4271 – BGP-4
- https://www.rfc-editor.org/rfc/rfc6996 – private ASN diapazonlari
- https://www.cloudflare.com/learning/security/glossary/what-is-bgp/ – BGP sharhi
- Kurose, Ross, "Computer Networking: A Top-Down Approach", 4–5-boblar (forwarding, routing algoritmlari, BGP)

---

## Birga bajaramiz

Bitta host'ga ikkita provayder ulaymiz va kernel qaysi paketni qaysi biriga berishini kuzatamiz. Uchta namespace: `pc` (host), `isp1` va `isp2` (ikki provayder router'i). "Internet" o'rnida har provayderning `lo` interfeysiga ikkita test manzil qo'yamiz: `198.51.100.1` va `203.0.113.1` (ikkalasi hujjatlar uchun ajratilgan diapazonlardan, haqiqiy tarmoqda uchramaydi). Bu yerda forwarding ham, vazifalardagi client/router/server zanjiri ham yo'q: mavzu faqat `pc` ning jadvali. Hamma narsa `lab` VM ichida.

```
            10.9.1.2/24        10.9.1.1/24
[pc] to-isp1 ---------------- isp1-pc [isp1]  lo: 198.51.100.1, 203.0.113.1
[pc] to-isp2 ---------------- isp2-pc [isp2]  lo: 198.51.100.1, 203.0.113.1
            10.9.2.2/24        10.9.2.1/24
```

1. Topologiyani yig'ing. Avval `isp1` tomoni, keyin xuddi shu qatorlarni `1` o'rniga `2` qo'yib `isp2` uchun takrorlang (`ip netns add pc` bir marta):

```
sudo ip netns add pc
sudo ip netns add isp1
sudo ip link add to-isp1 type veth peer name isp1-pc
sudo ip link set to-isp1 netns pc
sudo ip link set isp1-pc netns isp1
sudo ip -n pc addr add 10.9.1.2/24 dev to-isp1
sudo ip -n isp1 addr add 10.9.1.1/24 dev isp1-pc
sudo ip -n pc link set to-isp1 up
sudo ip -n isp1 link set isp1-pc up
sudo ip -n isp1 link set lo up
sudo ip -n isp1 addr add 198.51.100.1/32 dev lo
sudo ip -n isp1 addr add 203.0.113.1/32 dev lo
```

2. `pc` jadvaliga qarang va hali route yo'q manzilni so'rang:

```
ubuntu@lab:~$ sudo ip -n pc route
10.9.1.0/24 dev to-isp1 proto kernel scope link src 10.9.1.2
10.9.2.0/24 dev to-isp2 proto kernel scope link src 10.9.2.2
ubuntu@lab:~$ sudo ip -n pc route get 203.0.113.1
RTNETLINK answers: Network is unreachable
ubuntu@lab:~$ sudo ip netns exec pc ping -c 1 203.0.113.1
ping: connect: Network is unreachable
```

Ikki connected route'ni hech kim qo'shmadi: manzil `/24` bilan berilganda kernel yasadi (`proto kernel`). `203.0.113.1` ikkala prefiksga ham kirmaydi, default route yo'q, shuning uchun kernel darhol rad etdi: paket umuman chiqmadi (2-bo'limdagi jadvalning birinchi qatori).

3. Ikkala provayderni default gateway qilib qo'shing, har xil metric bilan:

```
ubuntu@lab:~$ sudo ip -n pc route add default via 10.9.1.1 metric 100
ubuntu@lab:~$ sudo ip -n pc route add default via 10.9.2.1 metric 200
ubuntu@lab:~$ sudo ip -n pc route get 203.0.113.1
203.0.113.1 via 10.9.1.1 dev to-isp1 src 10.9.1.2 uid 0
    cache
ubuntu@lab:~$ sudo ip netns exec pc ping -c 1 203.0.113.1
64 bytes from 203.0.113.1: icmp_seq=1 ttl=64 time=0.060 ms
```

Ikki route bir xil prefiksli (`/0`), shuning uchun bu safar metric hal qildi: kichigi, `isp1`. `dev` ni yozmadik: kernel `10.9.1.1` qaysi connected tarmoqda ekanidan interfeysni o'zi topdi. `uid 0` chunki buyruq `sudo` bilan bajarildi. Ping javobi `isp1` ning `lo` sidagi manzildan keldi (ping chiqishining faqat javob qatori ko'rsatilgan).

4. Bitta prefiks uchun istisno qo'shing: `203.0.113.0/24` ikkinchi provayder orqali ketsin.

```
ubuntu@lab:~$ sudo ip -n pc route add 203.0.113.0/24 via 10.9.2.1
ubuntu@lab:~$ sudo ip -n pc route get 203.0.113.1
203.0.113.1 via 10.9.2.1 dev to-isp2 src 10.9.2.2 uid 0
    cache
ubuntu@lab:~$ sudo ip -n pc route get 198.51.100.1
198.51.100.1 via 10.9.1.1 dev to-isp1 src 10.9.1.2 uid 0
    cache
```

Yangi route'ning metric'i berilmagan, default route'larniki esa 100 va 200, baribir `/24` yutdi: prefiks uzunligi metric'dan oldin solishtiriladi. `198.51.100.1` uchun hech narsa o'zgarmadi. `src` ga ham qarang: chiqish interfeysi almashgani uchun manba manzil ham `10.9.2.2` bo'ldi. Ikki provayderli host'da "javob boshqa manzildan ketyapti" muammolari shu yerdan chiqadi.

5. Ikkala test manzilga bittadan ping yuboring, keyin neighbour jadvalini ko'ring:

```
ubuntu@lab:~$ sudo ip -n pc neigh
10.9.1.1 dev to-isp1 lladdr <MAC1> REACHABLE
10.9.2.1 dev to-isp2 lladdr <MAC2> REACHABLE
```

Jadvalda `203.0.113.1` ham, `198.51.100.1` ham yo'q, faqat ikki gateway. Frame gateway'ning MAC'iga yuboriladi, oxirgi manzil esa faqat IP header'da turadi (1-bo'lim, "Mexanizm").

6. Qaytish yo'lini provayder tomonidan tekshiring:

```
ubuntu@lab:~$ sudo ip -n isp2 route get 10.9.2.2
10.9.2.2 dev isp2-pc src 10.9.2.1 uid 0
    cache
```

`isp2` da hech qanday static route yo'q, lekin javob yo'lini topadi: `pc` so'rovni `10.9.2.2` manbasi bilan yuborgan, u esa `isp2` ning connected tarmog'ida. Agar `pc` shu interfeysdan `10.9.1.2` manbasi bilan paket chiqarganida `isp2` unga route topa olmas edi.

7. Birinchi provayder "uzildi": `pc` dagi interfeysni o'chirib, qayta yoqing.

```
ubuntu@lab:~$ sudo ip -n pc link set to-isp1 down
ubuntu@lab:~$ sudo ip -n pc route
default via 10.9.2.1 dev to-isp2 metric 200
10.9.2.0/24 dev to-isp2 proto kernel scope link src 10.9.2.2
203.0.113.0/24 via 10.9.2.1 dev to-isp2
ubuntu@lab:~$ sudo ip -n pc route get 198.51.100.1
198.51.100.1 via 10.9.2.1 dev to-isp2 src 10.9.2.2 uid 0
    cache
ubuntu@lab:~$ sudo ip -n pc link set to-isp1 up
ubuntu@lab:~$ sudo ip -n pc route
default via 10.9.2.1 dev to-isp2 metric 200
10.9.1.0/24 dev to-isp1 proto kernel scope link src 10.9.1.2
10.9.2.0/24 dev to-isp2 proto kernel scope link src 10.9.2.2
203.0.113.0/24 via 10.9.2.1 dev to-isp2
```

Interfeys `down` bo'lganda kernel unga bog'liq barcha route'larni o'chirdi va metric'i 200 bo'lgan zaxira default o'z-o'zidan ishga tushdi. Interfeys qaytgach connected route tiklandi (manzil joyida turgan edi), lekin qo'lda qo'shilgan `default ... metric 100` qaytmadi. `ip route add` bilan qo'shilgan narsa faqat xotirada yashashining ko'rinishi shu (4-bo'lim, "Doimiy qilish").

8. Tozalang va tekshiring:

```
ubuntu@lab:~$ sudo ip netns delete pc
ubuntu@lab:~$ sudo ip netns delete isp1
ubuntu@lab:~$ sudo ip netns delete isp2
ubuntu@lab:~$ sudo ip netns list
ubuntu@lab:~$ ip route
```

Namespace'lar bilan veth'lar ham ketdi, VM'ning o'z jadvali dars boshidagidek qoldi: unga umuman tegmadik.

Shu 8 qadamda ko'rganingiz: connected route manzildan o'zi paydo bo'ladi va route yo'qligi `Network is unreachable` beradi (1 va 2-bo'limlar), bir xil prefiksda metric, har xil prefiksda uzunlik hal qiladi (2-bo'lim), frame gateway MAC'iga ketadi (1-bo'lim), javob uchun qarshi tomonda ham route kerak (5-bo'lim), `ip` bilan qo'shilgan route doimiy emas (4-bo'lim), namespace esa bularning hammasini VM'ga tegmasdan sinash joyi (6-bo'lim).

---

## Vazifalar

Ish papkasi: `network/05-routing/` (`make new m=network n=05 name=routing` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan skriptlarni shu papkaga saqlang. Barcha vazifalar `lab` VM ichida bajariladi: A guruh VM'ning asosiy tarmog'ida va faqat o'qiydi (sarlavhadagi "ish mashinasi" endi `lab` VM degani), B–E guruhlar namespace'larda. Host'da (Zorin yoki macOS) hech qanday route, sysctl yoki interfeys o'zgartirilmaydi. "Zorin'da" yoki "macOS'da" deb belgilangan qismlar ixtiyoriy.

### A. Routing table o'qish (ish mashinasi)

1. **Read my table.** VM'da `ip route` chiqishining har qatorini izohlang: prefiks, next hop bor yoki yo'qligi, interfeys, `proto`, `scope`, `src`, `metric`. Har qatorni kim qo'shganini ayting (kernel, DHCP, Docker). Ixtiyoriy: host jadvalini ham ko'ring (Zorin'da `ip route`, macOS'da `netstat -rn -f inet`) va VM tarmog'iga tegishli qatorni toping. Yo'nalish: 1-bo'lim, "Misol: `lab` VM jadvali".

2. **Route lookup.** `ip route get` ni kamida besh manzil uchun bajaring: public IP, o'z LAN'ingizdagi host (VM uchun bu `<GW>`), Docker tarmog'idagi manzil, `127.0.0.1`, o'z IP'ingiz. Har natijada qaysi route tanlangani va `src` nima uchun shunday ekanini yozing. Ixtiyoriy, macOS'da: `route -n get <public IP>` natijasi bilan solishtiring. Yo'nalish: 2-bo'lim, "Misol: kernel'dan qarorni so'rash".

3. **Longest prefix by hand.** Jadval berilgan: `default via 10.0.0.1`, `10.0.0.0/24 dev eth0`, `10.8.0.0/16 via 10.0.0.2`, `10.8.4.0/22 via 10.0.0.3`, `10.8.5.0/24 via 10.0.0.4`, `192.168.0.0/16 via 10.0.0.5`. Har manzil uchun next hop'ni qo'lda aniqlang va asoslang: `10.8.5.200`, `10.8.6.1`, `10.8.8.1`, `10.9.0.1`, `10.0.0.77`, `192.168.255.1`, `172.16.0.1`. Yo'nalish: 2-bo'lim, "Qoida".

4. **Tables and rules.** `ip rule show` va `ip route show table local` chiqishini yozing. `local` jadvalidagi `local` va `broadcast` turidagi yozuvlar nima uchun kerak? `ping 127.0.0.1` qaysi jadval orqali hal bo'ladi? Yo'nalish: 4-bo'lim, "Policy routing".

5. **Trace a path.** `tracepath -n` va `mtr -rwn -c 10` ni ikki manzilga bajaring: `1.1.1.1` va geografik uzoq bir sayt. Har hop'ni tasniflang (Multipass gateway, uy yoki ofis routeri, ISP, tranzit, manzil tarmog'i), private manzilli hop'lar qayerda tugaydi, kechikish qaysi hop'da keskin oshadi. Javob bermagan yoki yo'qotish ko'rsatgan oraliq hop bormi va u haqiqiy muammomi? Yo'nalish: 3-bo'lim, "Chiqishni to'g'ri o'qish".

6. **AS path.** `mtr -rwz -c 5` bilan xuddi shu ikki manzilga yo'ldagi ASN'larni oling. Yo'l nechta AS orqali o'tdi? Ulardan ikkitasining kimga tegishli ekanini https://bgp.he.net orqali aniqlang. `1.1.1.1` anycast ekanini qanday bilsa bo'ladi? Yo'nalish: 7-bo'lim, "Misol: yo'ldagi AS'larni ko'rish".

### B. Namespace va veth (VM)

7. **Two namespaces.** `ns1` va `ns2` namespace'larini yarating, veth juftligi bilan ulang, `10.0.0.1/24` va `10.0.0.2/24` bering. Bir-biriga ping o'tishini ko'rsating. Har namespace'da `ip addr`, `ip route` va pingdan keyingi `ip neigh` chiqishini yozing. VM'ning o'zidan (`ip route get 10.0.0.1`) bu manzillar ko'rinadimi, nima uchun? Yo'nalish: 6-bo'lim, "Ikki namespace'ni kabel bilan ulash".

8. **Forgotten steps.** 7-vazifani noldan takrorlang, lekin har safar bitta qadamni ataylab tashlab keting va alomatni yozing: (a) bir veth uchi `up` qilinmagan; (b) manzil prefikssiz berilgan; (c) `lo` ko'tarilmagan holda `ping 127.0.0.1`. Har biri uchun: xato matni, `ip addr` yoki `ip route` dagi belgi. Yo'nalish: 6-bo'lim, "Qoidalar" ro'yxati va 2-bo'lim, "Mos route bo'lmasa: xato matnlari".

9. **Bridge as a switch.** Uchta namespace'ni (`h1`, `h2`, `h3`) VM'dagi `br0` bridge orqali bitta LAN'ga ulang (`10.0.5.0/24`). Hammasi bir-biriga ping qila olishini ko'rsating. `bridge fdb show br br0` va `bridge link` chiqishini izohlang. Bu topologiya Docker'ning qaysi qismiga mos keladi? Yo'nalish: 6-bo'lim, "Qoidalar" ro'yxatining oxirgi bandi; 1-dars, 6-bo'lim.

### C. Linux router (VM)

10. **Build the router.** 6-bo'limdagi topologiyani yig'ing: `client` (`10.0.1.2/24`), `router` (`10.0.1.1/24` va `10.0.2.1/24`), `server` (`10.0.2.2/24`). Hali default route qo'shmang va forwarding o'chiq bo'lsin: `router` ichida `sysctl net.ipv4.ip_forward` ni tekshiring, `1` chiqsa `0` ga qo'ying va nima uchun `1` bo'lganini yozing. `client` dan `10.0.1.1`, `10.0.2.1` va `10.0.2.2` ga ping qiling. Har natijaning xato matnini va sababini yozing. Yo'nalish: 6-bo'lim, "Maqsad topologiya" va "Diqqat: `ip_forward` ning boshlang'ich qiymati".

11. **Default gateway.** `client` ga default route qo'shing. 10-vazifadagi uch pingni takrorlang. Endi qaysi biri o'tadi, qaysi biri yo'q? `10.0.2.1` ga ping nima uchun forwarding'siz ham ishlashini tushuntiring. Yo'nalish: 5-bo'lim, "Mexanizm: router paket bilan nima qiladi".

12. **Return path.** `router` da forwarding'ni yoqing, lekin `server` ga hali route qo'shmang. `client` dan `server` ga ping qiling va bir vaqtda `server` ichida `tcpdump -i <veth> -n icmp` ni kuzating (ikkinchi terminal: host'da yana bir `multipass shell lab`). Echo request keldimi? Reply ketdimi? `server` da `ip route get 10.0.1.2` nima deydi? Keyin `server` ga route qo'shib muammoni tuzating. Bu tajribadan chiqadigan umumiy qoidani bir gap bilan yozing. Yo'nalish: 5-bo'lim, "Qaytish yo'li".

13. **Forwarding off.** Hammasi ishlab turgan holatda `router` da `ip_forward` ni `0` qiling. `client` dan ping natijasi qanday, `router` ning ikkala interfeysida tcpdump nimani ko'rsatadi (paket kirdi, chiqdimi)? Qaytadan yoqing. VM'ning o'zidagi `sysctl net.ipv4.ip_forward` qiymati namespace'dagisidan mustaqilligini ko'rsating. Yo'nalish: 5-bo'lim, "Forwarding nima".

14. **Watch the hop.** `client` dan `server` ga ping ketayotganda `router` ning har ikki interfeysida `tcpdump -n -e icmp` bilan bitta paketni ushlang. Ikki tomondagi manba va manzil MAC, manba va manzil IP hamda TTL ni jadvalga yozing (TTL ko'rinishi uchun `-v` qo'shing). Nima o'zgardi, nima o'zgarmadi (2-darsdagi jadval bilan solishtiring)? Yo'nalish: 1-bo'lim, "Mexanizm: next hop'ga qanday yetkaziladi"; 3-bo'lim, "TTL nima".

15. **Traceroute in the lab.** `client` dan `traceroute -n 10.0.2.2` va `mtr -rn -c 5 10.0.2.2` ni bajaring. Nechta hop va ular kim? `tcpdump` bilan `client` interfeysida zondlar va qaytgan ICMP xabarlarni ushlab, TTL mexanizmini o'z kuzatuvingiz bilan tushuntiring. Yo'nalish: 3-bo'lim, "traceroute mexanizmi".

16. **Service through the router.** `server` namespace'ida `python3 -m http.server 8080` ni ishga tushiring va `client` dan `curl` bilan oling. Keyin server'ni `--bind 127.0.0.1` bilan qayta ishga tushirib takrorlang: `client` dagi xato matni qanday va u routing muammosidan qanday farqlanadi? Yo'nalish: 2-bo'lim, "Mos route bo'lmasa: xato matnlari"; 4-dars, 1-bo'lim (TCP).

### D. Static route va tashxis (VM)

17. **Third network.** Topologiyaga `router2` va uning ortida `10.0.3.0/24` tarmog'i hamda `db` (`10.0.3.2`) hostini qo'shing; `router2` `10.0.2.0/24` tarmog'iga `10.0.2.3` manzili bilan ulanadi (buning uchun `10.0.2.0/24` da bridge kerak bo'ladi). `client` dan `db` ga ping o'tishi uchun qaysi hostlarga qanday static route kerakligini avval qog'ozda aniqlang, keyin qo'shing. Har hostning yakuniy `ip route` chiqishini va `client` dan `traceroute` natijasini yozing. Yo'nalish: 4-bo'lim, "Route qo'shish va o'chirish"; 5-bo'lim, "Qaytish yo'li".

18. **Wrong gateway.** `client` da `ip route add 10.0.3.0/24 via 10.0.9.9` ni bajarib ko'ring. Xato matni nima va kernel nima uchun bunday route'ni qabul qilmaydi? Keyin mavjud, lekin noto'g'ri next hop (`10.0.1.77`, hech kim yo'q) bilan qo'shing: `ping` xatosi va `ip neigh` holati qanday? Yo'nalish: 1-bo'lim, "Mexanizm: next hop'ga qanday yetkaziladi".

19. **Blackhole and prefix order.** `router` da `10.0.3.0/24` uchun to'g'ri route turgan holda `blackhole 10.0.3.2/32` qo'shing. `client` dan `db` ga va shu tarmoqdagi boshqa manzilga ping natijalarini solishtiring va longest prefix match bilan izohlang. Route'ni o'chiring. Yo'nalish: 2-bo'lim, "Qoida"; 4-bo'lim, "Route qo'shish va o'chirish".

20. **Find the fault.** Topologiyani buzadigan to'rt xil o'zgarishdan birini o'zingiz bilmagan holda qo'llash uchun kichik skript yozing (tasodifiy tanlaydi: forwarding o'chirish, bitta route'ni o'chirish, bitta interfeysni `down` qilish, noto'g'ri mask). Skript faqat namespace'lar ichida ishlaydi, VM'ning asosiy tarmog'iga tegmaydi. Skriptni ishga tushiring va nosozlikni faqat tashxis buyruqlari bilan toping. README'ga tashxis qadamlaringizni tartib bilan yozing: har buyruq nimani isbotladi yoki istisno qildi. Kamida ikki marta takrorlang. Yo'nalish: butun dars; 2-bo'limdagi xato matnlari jadvali.

### E. Yig'ish

21. **Lab script.** `netlab.sh up` va `netlab.sh down` buyruqlari bilan 17-vazifadagi to'liq topologiyani yaratadigan va o'chiradigan skript yozing. Talablar: `set -euo pipefail`, takroran ishga tushirilganda xato bermaydi (idempotent), `netlab.sh test` barcha juftliklar orasida ping va `client` dan `server` ga HTTP tekshiruvini bajarib natijani jadval qilib chiqaradi, `shellcheck` toza. Skript host'da yoziladi (repo ichida), VM'da ishga tushiriladi: `multipass transfer` bilan ko'chiring yoki repo papkasini `multipass mount` bilan ulang. README'ga topologiya sxemasini (ASCII) va manzil jadvalini qo'shing. Yo'nalish: butun dars; `linux` modulidagi bash darslari.

### Topshirish

Tayyor bo'lgach:
1. `network/05-routing/README.md` da 21 ta vazifaning har biri `## N. Title` sarlavhasi ostida; `netlab.sh` va 20-vazifadagi buzuvchi skript shu papkada.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; qaysi namespace'da bajarilgani ko'rinadi.
3. `make check` toza o'tadi (host'da, `shellcheck`).
4. VM'da `sudo ip netns list` bo'sh, `ip -br link` da ortiqcha bridge va veth yo'q, `ip route` dars boshidagi bilan bir xil.
5. Host'da (Zorin yoki macOS) hech qanday route yoki sysctl o'zgarmagan.
6. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Routing table'dagi connected route va gateway orqali route farqi nima? Har birida frame kimning MAC'iga yuboriladi?
- Longest prefix match nima va metric qachon ahamiyat kasb etadi?
- `Network is unreachable` va `No route to host` nimasi bilan farq qiladi? Qaysi birida paket host'dan chiqqan?
- A dan B ga ping o'tishi uchun nechta hostda qanday route'lar bo'lishi kerak? "Qaytish yo'li" muammosi qanday ko'rinadi?
- `ip_forward=0` bo'lgan host ikki tarmoqqa ulangan bo'lsa nima qiladi? O'ziga tegishli manzilga kelgan paket bilan-chi?
- Yangi namespace'dagi `ip_forward` qiymati qayerdan keladi va keyin nimaga bog'liq?
- traceroute qanday mexanizmga tayanadi? mtr'da oraliq hop'dagi yo'qotish qachon haqiqiy muammo?
- `rp_filter` ning strict va loose rejimi nimani tekshiradi va asymmetric routing bilan qanday to'qnashadi?
- `ip route add` bilan qo'shilgan route qaysi hodisalarda yo'qoladi va uni doimiy qilish uchun nima kerak?
- Network namespace nimalarni ajratadi? Docker konteyneri tarmog'i qaysi bloklardan yig'ilgan?
- Docker tarmog'i CIDR'i korporativ tarmoq bilan kesishsa nima bo'ladi va nima uchun?
- AS va BGP nima? Kimdir sizning prefiksingizdan aniqroq prefiks e'lon qilsa nima bo'ladi?
