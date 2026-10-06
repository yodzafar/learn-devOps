# 1-dars: Tarmoq turlari

Maqsad: "brauzer HTTP so'rov yuboradi" degan bilimdan bir qavat pastga tushish: kompyuterlar bir-biriga jismonan qanday ulanadi, LAN va WAN nima, switch va router nima ish qiladi, MAC manzil va Ethernet frame nima, Linux tarmoq kartasini (interfeysni) qanday ko'rsatadi va ARP IP manzildan MAC manzilni qanday topadi. Oxirida Docker tarmog'i aynan shu bloklardan (bridge, veth) yig'ilganini o'z ko'zingiz bilan ko'rasiz. Keyingi darslar (OSI modeli, IP manzillash, routing, firewall) shu poydevorga quriladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh vazifalari, ikkinchi kun 4–5 bo'limlar, "Birga bajaramiz" va B guruh, uchinchi kun 6-bo'lim, C, D, E guruhlari va README'ni tartibga solish. Diqqatni quyidagilarga qarating: switch va router farqi (MAC bo'yicha va IP bo'yicha), frame bilan paket farqi, `ip addr` chiqishini qatorma-qator o'qish, ARP qachon va kimni so'raydi.

Qanday o'qish kerak: har bo'limdagi misolni `lab` VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi interfeys nomlari, IP va MAC manzillar farq qiladi, bu normal; darsda bunday joylar `<...>` bilan belgilangan yoki "sizda boshqacha" deb aytilgan. Bu modulda hech qachon interfeys nomini yoki manzilni darsdan ko'chirmang, avval o'zingizdagi qiymatni toping.

## Laboratoriya

Bu dars uchun `SETUP.md` bo'yicha yaratilgan `lab` virtual mashinasi kerak (Multipass, Ubuntu 24.04). Barcha Linux tarmoq buyruqlari (`ip`, `bridge`, `tcpdump`) shu VM ichida bajariladi, chunki macOS'da bu buyruqlar yo'q, Zorin'da esa host tarmog'ini buzib qo'yish xavfi bor. VM ikkala mashinada bir xil Ubuntu, shuning uchun dars ham bir xil.

| Joy | Prompt | Nima uchun kerak |
|-----|--------|------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | repo (`make`, `git`), `multipass` buyruqlari, ixtiyoriy host kuzatuvlari |
| `lab` VM | `ubuntu@lab:~$` | A, B guruhlar va barcha `ip`, `bridge`, `docker` buyruqlari |
| Konteyner (`h1`, `h2`, `h3`) | `h1:~#` | C va D guruhlar: ikki "host" bitta LAN'da |

Bu darsda Docker **VM ichida** ishlatiladi, host'dagi Docker emas. Sababi: C guruhda konteynerlar ulanadigan bridge va veth interfeyslarini "tashqaridan" ko'rish kerak. Zorin'da ular host'da ko'rinadi, macOS'da esa Docker Desktop'ning yashirin VM'i ichida qolib, ko'rinmaydi. VM ichidagi Docker'da ikkala mashinada ham ko'rinadi. Bir marta o'rnatiladi (VM ichida, host'da emas):

```
multipass shell lab
sudo apt update
sudo apt install -y docker.io tcpdump
sudo usermod -aG docker ubuntu     # allow the ubuntu user to run docker without sudo
exit                               # leave and enter again so the new group applies
multipass shell lab
docker run --rm hello-world
```

C va D guruhlar uchun stend (VM ichida):

```
docker network create lab-net
docker run -d --name h1 --network lab-net --cap-add NET_ADMIN nicolaka/netshoot sleep infinity
docker run -d --name h2 --network lab-net --cap-add NET_ADMIN nicolaka/netshoot sleep infinity
docker exec -it h1 bash
```

- `nicolaka/netshoot` bu tarmoq asboblari (`ip`, `tcpdump`, `ping`, `dig`, `nc`) oldindan o'rnatilgan image. U `linux/amd64` va `linux/arm64` uchun chiqadi, ya'ni ikkala mashinada emulyatsiyasiz ishlaydi.
- `--cap-add NET_ADMIN` faqat shu konteynerning o'z network namespace'ida (6-bo'lim) interfeys va ARP jadvalini o'zgartirishga ruxsat beradi, VM yoki host tarmog'iga ta'sir qilmaydi.
- **Tozalash**: `docker rm -f h1 h2 h3 && docker network rm lab-net lab-net2` (20-vazifa). VM'ni butunlay toza holatga qaytarish: `multipass stop lab && multipass restore lab.clean` (unda Docker ham yo'qoladi).
- Bu dars oldingi holatga tayanmaydi. Mashinani almashtirsangiz, ikkinchi mashinadagi `lab` da yuqoridagi `apt install` va stend buyruqlarini qayta bajaring; javoblar (README) git orqali ko'chadi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`. VM'ning tarmoq kartasi odatda `ens3` deb nomlanadi va `10.x.x.x/24` manzil oladi; host tomonda Multipass `mpqemubr0` bridge'ini yaratadi. Host ham Linux, shuning uchun `ip -br addr` ni host'da faqat o'qish uchun ishlatish mumkin (ixtiyoriy). Host'da interfeys holatini o'zgartirmang. |
| macOS (uy) | VM `arm64`. VM'ning kartasi odatda `enp0s1`, manzil odatda `192.168.64.x/24`; host tomonda `bridge100` paydo bo'ladi. Host'da `ip`, `bridge`, `ss` yo'q. Ixtiyoriy host kuzatuvlari uchun o'xshashlari: `ifconfig` (interfeyslar), `arp -a` (qo'shnilar jadvali), `netstat -rn` (routing jadvali), `networksetup -listallhardwareports` (kartalar va MAC'lar). |

Interfeys nomi va manzil diapazoni Multipass versiyasi va drayveriga qarab boshqacha bo'lishi mumkin. Shuning uchun vazifalarda "avval o'zingizdagi nomni toping" deyiladi. Paketlarni grafik ko'rishni xohlasangiz, Wireshark ixtiyoriy (Zorin: `sudo apt install wireshark`, macOS: `brew install --cask wireshark`); asosiy yo'l VM ichidagi `tcpdump`.

---

## 1. Tarmoq turlari: LAN, WAN, internet

### Bu nima

Tarmoq (network) bu ma'lumot almashish uchun bir-biriga ulangan qurilmalar to'plami. Qurilma deganda kompyuter, telefon, server, printer, router tushuniladi; tarmoq tilida ma'lumot yuboruvchi yoki qabul qiluvchi har bir qurilma **host** deyiladi. Tarmoqlar qamroviga qarab ikki katta turga bo'linadi.

| Tur | To'liq nomi | Qamrovi | Kim egalik qiladi | Misol |
|-----|-------------|---------|-------------------|-------|
| LAN | Local Area Network | bir xona, bino, ofis | o'zingiz yoki kompaniya | uydagi Wi-Fi, ofis tarmog'i, data-markazdagi bitta rack |
| WAN | Wide Area Network | shahar, davlat, qit'a | provayder (ISP) | provayderning tarmog'i, ofislar orasidagi ijaraga olingan kanal |

Internet bu bitta tarmoq emas, minglab mustaqil tarmoqlarning (provayderlar, universitetlar, cloud kompaniyalari) o'zaro ulanishi, "tarmoqlar tarmog'i". ISP (Internet Service Provider) bu sizni shu umumiy tarmoqqa ulaydigan kompaniya.

### Mexanizm: LAN'ning amaliy ta'rifi

"Bir bino" degan ta'rif noaniq. Amaliy ta'rif shunday: **LAN bu router'dan o'tmasdan, to'g'ridan-to'g'ri bir-biriga frame yubora oladigan hostlar to'plami**. Frame bu LAN ichida yuriladigan ma'lumot bo'lagi (3-bo'lim). Shu to'plam ichida bitta host "hammaga" deb yuborgan xabar (broadcast) barcha a'zolarga yetadi, shuning uchun LAN **broadcast domain** deb ham ataladi. Broadcast domain chegarasini router belgilaydi: router broadcast'ni narigi tomonga o'tkazmaydi.

Bundan muhim xulosa chiqadi: host boshqa hostga paket yuborishdan oldin har doim bitta savolga javob beradi: "manzil mening LAN'imdami?". Ha bo'lsa, to'g'ridan-to'g'ri yuboradi. Yo'q bo'lsa, LAN'dan chiqish eshigi bo'lgan router'ga beradi. Bu router hostning **default gateway**'i deyiladi. "Mening LAN'imdami" savoliga qanday javob berilishi 3-darsda (subnet mask).

### Internet tuzilishi

Uydan `google.com` gacha yo'l taxminan shunday:

```
laptop --Wi-Fi--> home router --fiber--> ISP --> bigger ISP / IX --> Google network --> server
  LAN (yours)       |<-------------------- WAN (not yours) ---------------------->|
```

- Uy router'i sizning LAN'ingiz bilan provayder tarmog'i orasidagi chegara.
- Provayderlar bir-biri bilan **IX** (Internet Exchange, provayderlar o'zaro trafik almashadigan nuqta) orqali yoki kattaroq provayderdan tranzit sotib olib ulanadi.
- Yo'ldagi har bir router paketni keyingi router'ga uzatadi; har bir shunday uzatish **hop** deyiladi. Yo'lni 5-darsda `traceroute` bilan ko'rasiz.

### Misol: mening LAN'im qayerda tugaydi

VM ichida default gateway'ni ko'ramiz:

```
ubuntu@lab:~$ ip route show default
default via 10.118.52.1 dev ens3 proto dhcp src 10.118.52.87 metric 100
```

O'qilishi:

- `default`: "boshqa hech bir qoidaga tushmagan barcha manzillar uchun".
- `via 10.118.52.1`: shu manzildagi router'ga ber. Bu VM'ning default gateway'i. Sizda boshqa manzil (macOS'da odatda `192.168.64.1`).
- `dev ens3`: paket shu interfeysdan chiqadi (macOS'da odatda `enp0s1`).
- `proto dhcp`: bu qoidani qo'lda emas, DHCP qo'ygan. DHCP bu hostga manzil va gateway'ni avtomatik beradigan protokol (4-dars).
- `src 10.118.52.87`: jo'natuvchi manzili sifatida VM'ning shu IP'si ishlatiladi.

Bu yerda VM'ning LAN'i bu Multipass yaratgan virtual tarmoq: a'zolari VM'lar va host. Gateway rolini host o'ynaydi. Ya'ni VM uchun sizning laptopingiz "uy router'i".

### Real ishda qachon kerak

- "Server A server B ni ko'rmayapti" degan muammoda birinchi savol: ular bitta LAN'dami yoki orada router bormi. Tashxis yo'li shunga qarab ikki xil.
- Cloud'da VPC va subnet (aws moduli) aynan shu tushunchalar: subnet bu LAN, route table bu router.
- Docker va Kubernetes'da har bir "tarmoq" bu kichik virtual LAN.

### Nima uchun shunday

Nega hamma kompyuterni bitta ulkan LAN'ga ulamaymiz? Chunki broadcast hamma a'zoga boradi: million hostli LAN'da tarmoq faqat "kim bor?" savollari bilan band bo'lardi, bitta buzuq qurilma esa hammasini to'xtatardi. Shuning uchun tarmoq kichik LAN'larga bo'linadi va ular router'lar bilan ulanadi. Bu dizayn internetni markazsiz ham qiladi: har tashkilot o'z LAN'ini o'zi boshqaradi, tashqi dunyo bilan faqat chegaradagi router orqali kelishadi.

---

## 2. Qurilmalar

### Bu nima

| Qurilma | Nimaga qarab qaror qiladi | Vazifasi |
|---------|---------------------------|----------|
| Switch | MAC manzil | bitta LAN ichidagi hostlarni ulaydi, frame'ni kerakli portga uzatadi |
| Router | IP manzil | turli LAN'larni ulaydi, paketni keyingi tarmoqqa uzatadi |
| Access point (AP) | MAC manzil | switch'ning simsiz varianti: Wi-Fi qurilmalarni LAN'ga ulaydi |
| Modem / ONT | hech narsa, signalni o'zgartiradi | provayder liniyasini (optika, telefon simi) Ethernet'ga aylantiradi |
| Hub | qaror qilmaydi | eskirgan: kelgan signalni barcha portlarga takrorlaydi |

Uydagi "Wi-Fi router" aslida bitta qutidagi bir nechta qurilma: router, 4 portli switch, access point, DHCP server va NAT (manzil almashtirish, 6-dars). Shuning uchun uyda switch va router farqi sezilmaydi, serverxonada esa ular alohida qutilar.

### Switch qanday ishlaydi

Switch ichida **MAC address table** (FDB, forwarding database) bor: "qaysi MAC qaysi portda" degan jadval. U uch qoida bilan ishlaydi:

1. **Learning**: frame kelganda switch jo'natuvchi MAC'ni va kelgan portni jadvalga yozadi.
2. **Forwarding**: manzil MAC jadvalda bo'lsa, frame faqat o'sha portga chiqadi.
3. **Flooding**: manzil MAC jadvalda bo'lmasa yoki broadcast bo'lsa, frame kelgan portdan boshqa barcha portlarga chiqadi.

```
port1: A (aa:aa)     port2: B (bb:bb)     port3: C (cc:cc)

A -> B, table is empty:   learn aa:aa=port1, flood to port2 and port3
B -> A (reply):           learn bb:bb=port2, forward only to port1
A -> B again:             forward only to port2
```

Switch frame ichidagi IP manzilga qaramaydi va frame'ni o'zgartirmaydi. Hostlar uchun u "ko'rinmas": o'z IP manzili ham bo'lmasligi mumkin.

### Router qanday ishlaydi

Router'ning kamida ikkita interfeysi bor va har biri boshqa LAN'da. Paket kelganda router:

1. Frame'ni ochadi (frame o'ziga, router'ning MAC'iga yuborilgan bo'ladi).
2. Ichidagi IP paketning manzil IP'siga qaraydi va **routing table** dan qaysi interfeysdan chiqarishni topadi.
3. Paketni **yangi frame**'ga o'raydi: jo'natuvchi MAC endi router'niki, manzil MAC keyingi hop'niki.

Ya'ni yo'l davomida IP manzillar o'zgarmaydi (NAT bo'lmasa), MAC manzillar esa har hop'da yangilanadi. MAC faqat "shu LAN ichida kimga", IP esa "oxirgi manzil kim" degan savolga javob beradi.

### Misol: VM ichida switch bormi

Linux kernel'i dasturiy switch bo'la oladi, u **bridge** deyiladi. Docker o'rnatilgan `lab` VM'da:

```
ubuntu@lab:~$ ip -br link show type bridge
docker0          DOWN           02:42:5c:1b:9a:07 <NO-CARRIER,BROADCAST,MULTICAST,UP>
```

- `docker0`: Docker o'rnatilganda yaratilgan standart bridge. Bu VM ichidagi virtual switch.
- `DOWN` va `NO-CARRIER`: unga hozir hech bir konteyner ulanmagan, ya'ni "switch'ga birorta kabel tiqilmagan". Xato emas.
- MAC sizda boshqa bo'ladi.

Konteyner ishga tushsa, holat `UP` ga o'tadi (6-bo'lim).

### Real ishda qachon kerak

- "Ping bormayapti" muammosida savol: paket switch darajasida yo'qolyaptimi (MAC, ARP, kabel) yoki router darajasida (IP, route). Bu darsdagi asboblar birinchisi uchun.
- Cloud'da switch'ni ko'rmaysiz, lekin security group va route table router mantiqida ishlaydi.
- Kubernetes node'ida har pod bridge yoki shunga o'xshash virtual qurilmaga ulanadi.

### Nima uchun shunday

Nega ikki xil qurilma, ikki xil manzil? Switch tez va sodda: jadvaldan bitta qidiruv, sozlash shart emas. Lekin MAC manzillar tartibsiz (ular zavodda beriladi, joylashuvga bog'liq emas), shuning uchun butun dunyo MAC'larini bitta jadvalda saqlab bo'lmaydi. IP manzillar esa ierarxik: bitta qoida ("`10.1.0.0/16` ana u tomonda") minglab hostni qamraydi. Shu sababli LAN ichida MAC, LAN'lar orasida IP ishlatiladi. Hub'lar yo'qolib ketdi, chunki hamma frame hammaga borardi: sekin va xavfsiz emas.

---

## 3. MAC manzil va Ethernet frame

### MAC manzil

MAC (Media Access Control) manzil bu tarmoq kartasining LAN ichidagi manzili: 48 bit, 6 bayt, o'n oltilik sanoqda ikki nuqta bilan yoziladi.

```
52:54:00:a1:b2:c3
|______| |______|
  OUI     device part
```

- Birinchi 3 bayt **OUI** (Organizationally Unique Identifier): ishlab chiqaruvchi kodi, IEEE beradi. Masalan `52:54:00` QEMU/KVM virtual kartalari ishlatadigan prefiks.
- Oxirgi 3 baytni ishlab chiqaruvchi o'zi tanlaydi.
- `ff:ff:ff:ff:ff:ff` maxsus manzil: **broadcast**, "LAN'dagi hammaga".

Birinchi baytning ikki past biti alohida ma'noga ega:

| Bit (birinchi baytda) | 0 | 1 |
|-----------------------|---|---|
| eng past bit (qiymati 1) | unicast: bitta qabul qiluvchi | multicast yoki broadcast: guruh |
| ikkinchi bit (qiymati 2) | universally administered: zavod bergan | locally administered: dasturiy berilgan |

Hisob misoli, `52:54:00:a1:b2:c3`: birinchi bayt `0x52` = `0101 0010`. Eng past bit 0, demak unicast. Ikkinchi bit 1, demak locally administered: bu manzilni zavod emas, virtualizatsiya dasturi bergan. Tez qoida: birinchi baytning ikkinchi o'n oltilik raqami `2`, `6`, `a` yoki `e` bo'lsa, manzil locally administered.

Telefonlar va zamonaviy OS'lar Wi-Fi'da maxfiylik uchun tasodifiy (locally administered) MAC ishlatadi, shuning uchun MAC'ga qarab qurilmani tanish har doim ham ishlamaydi.

### Ethernet frame

Ethernet bu simli LAN'ning asosiy texnologiyasi. LAN ichida ma'lumot **frame** deb ataladigan bo'laklarda yuriladi:

```
| dst MAC | src MAC | EtherType | payload (46..1500 bytes) | FCS |
|  6 B    |  6 B    |   2 B     |   IP packet or ARP       | 4 B |
```

- **dst MAC**, **src MAC**: kimga va kimdan (shu LAN ichida).
- **EtherType**: payload ichida nima borligini aytadi. `0x0800` IPv4, `0x0806` ARP, `0x86dd` IPv6.
- **payload**: yuqori qatlam ma'lumoti, odatda IP paket.
- **FCS** (Frame Check Sequence): nazorat yig'indisi. Qabul qiluvchi qayta hisoblaydi, mos kelmasa frame tashlanadi.

**MTU** (Maximum Transmission Unit) bu payload'ning maksimal hajmi, Ethernet'da standart 1500 bayt. Kattaroq IP paket bo'laklarga bo'linadi (fragmentatsiya) yoki rad etiladi. Frame va paket farqini eslab qoling: **frame** LAN ichidagi konvert (MAC manzillar), **paket** uning ichidagi xat (IP manzillar). Frontend o'xshatishi: HTTP body ichidagi JSON kabi, har qatlam o'zidan yuqoridagini "payload" deb ko'radi va ichiga qaramaydi.

### Misol: frame sarlavhasini ko'rish

`tcpdump` tarmoq kartasidan o'tayotgan frame'larni ko'rsatadigan asbob. `-e` flag'i Ethernet sarlavhasini ham chiqaradi, `-n` nomlarni emas raqamli manzillarni ko'rsatadi, `-c 2` ikki frame'dan keyin to'xtaydi. VM ichida bir terminalda tcpdump, ikkinchisida `ping -c 1 1.1.1.1`:

```
ubuntu@lab:~$ sudo tcpdump -i ens3 -n -e -c 2 icmp
14:02:11.401210 52:54:00:a1:b2:c3 > 52:54:00:9e:11:f0, ethertype IPv4 (0x0800), length 98: 10.118.52.87 > 1.1.1.1: ICMP echo request, id 3, seq 1, length 64
14:02:11.419377 52:54:00:9e:11:f0 > 52:54:00:a1:b2:c3, ethertype IPv4 (0x0800), length 98: 1.1.1.1 > 10.118.52.87: ICMP echo reply, id 3, seq 1, length 64
```

Birinchi qatorni o'qiymiz:

- `52:54:00:a1:b2:c3 > 52:54:00:9e:11:f0`: frame'ning src va dst MAC'i. Src bu VM'ning kartasi. Dst esa `1.1.1.1` ning MAC'i **emas**, gateway'ning MAC'i, chunki `1.1.1.1` boshqa tarmoqda.
- `ethertype IPv4 (0x0800)`: payload IP paket.
- `length 98`: frame uzunligi (FCS'siz): 14 bayt Ethernet sarlavha + 84 bayt IP paket.
- `10.118.52.87 > 1.1.1.1`: paket ichidagi IP manzillar. Manzil IP oxirgi nuqta, manzil MAC esa faqat birinchi hop.

Sizda `ens3` o'rniga o'z interfeysingiz, manzillar boshqa.

### Real ishda qachon kerak

- `tcpdump -e` chiqishida kutilmagan MAC ko'rinsa, trafik boshqa qurilmaga ketayotgan bo'ladi (noto'g'ri gateway, IP to'qnashuvi).
- MTU muammolari VPN va tunnel'larda tez-tez uchraydi: kichik so'rovlar o'tadi, katta javoblar "osilib qoladi" (6-dars).
- Cloud'da instansga MAC emas, ENI (virtual karta) beriladi, lekin ichida o'sha Ethernet.

### Nima uchun shunday

Nega IP ustiga yana MAC kerak? Tarixan Ethernet IP'dan mustaqil yaratilgan va boshqa protokollarni ham tashigan; EtherType maydoni shuning uchun bor. Amaliy sabab ham bor: karta zavoddan chiqqanda hali hech qanday IP'si yo'q, lekin u LAN'da gaplasha olishi kerak (masalan DHCP'dan IP so'rash uchun). MAC shu "tug'ma" manzil. MTU nega 1500? 1980-yillardagi xotira narxi va xato ehtimoli orasidagi murosa; o'shandan beri butun internet shu songa moslashgan.

---

## 4. Linux'da interfeyslar

### Bu nima

**Interfeys** (network interface) bu kernel'ning tarmoq kartasi uchun ob'ekti. U fizik karta (Ethernet, Wi-Fi) yoki to'liq dasturiy (loopback, bridge, veth) bo'lishi mumkin. Barcha ishlar `iproute2` paketidagi `ip` buyrug'i bilan qilinadi. Eski `ifconfig` Linux'da eskirgan (macOS'da esa hali asosiy asbob).

```
ip link            # layer 2 view: name, state, MAC, MTU
ip addr            # same plus IP addresses
ip -br addr        # brief: one line per interface
ip -d link show <iface>    # details, including the interface type
ip -s link show <iface>    # RX/TX counters
```

### ip addr chiqishini o'qish

```
ubuntu@lab:~$ ip addr show ens3
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:a1:b2:c3 brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.118.52.87/24 metric 100 brd 10.118.52.255 scope global dynamic ens3
       valid_lft 85012sec preferred_lft 85012sec
    inet6 fe80::5054:ff:fea1:b2c3/64 scope link
       valid_lft forever preferred_lft forever
```

Qatorma-qator:

- `2: ens3:` interfeys indeksi va nomi. Indeks kernel bergan tartib raqami (veth juftlarini topishda kerak bo'ladi).
- `<BROADCAST,MULTICAST,UP,LOWER_UP>` flag'lar. `UP`: administrator interfeysni yoqqan (`ip link set up`). `LOWER_UP`: pastki qatlam tirik, ya'ni kabel ulangan, signal bor. `BROADCAST`, `MULTICAST`: karta shu turdagi frame'larni qo'llaydi.
- `mtu 1500`: maksimal payload (3-bo'lim).
- `qdisc fq_codel`: chiqish navbati algoritmi. Hozircha e'tiborsiz qoldiring.
- `state UP`: yakuniy holat. `DOWN` bo'lsa interfeys o'chiq yoki kabel yo'q.
- `link/ether 52:54:00:a1:b2:c3`: MAC manzil. `brd ff:ff:ff:ff:ff:ff`: shu LAN'ning broadcast MAC'i.
- `inet 10.118.52.87/24`: IPv4 manzil va prefiks uzunligi (`/24` nimaligi 3-darsda). `brd 10.118.52.255`: IP broadcast manzili.
- `scope global`: manzil hamma joyda yaroqli. `scope link`: faqat shu LAN ichida. `scope host`: faqat shu mashina ichida.
- `dynamic`: manzil DHCP'dan olingan. `valid_lft 85012sec`: ijara muddati tugashiga qolgan soniyalar; DHCP uni yangilab turadi. Qo'lda berilgan manzilda `forever` bo'ladi.
- `inet6 fe80::.../64 scope link`: IPv6 link-local manzil, kernel uni MAC'dan avtomatik yasaydi.

`UP` bor, `LOWER_UP` yo'q bo'lsa, flag'lar orasida `NO-CARRIER` chiqadi: "yoqilgan, lekin narigi uchida hech kim yo'q" (kabel tiqilmagan, Wi-Fi ulanmagan, bridge'ga a'zo qo'shilmagan).

### Interfeys nomlari va turlari

| Nom namunasi | Turi | Izoh |
|--------------|------|------|
| `lo` | loopback | mashinaning o'zi bilan gaplashishi uchun, `127.0.0.1` |
| `ens3`, `enp0s1`, `eno1` | Ethernet | `en` = Ethernet, qolgani shina va slot raqami |
| `wlp3s0`, `wlo1` | Wi-Fi | `wl` = wireless LAN |
| `docker0`, `br-<id>`, `mpqemubr0` | bridge | dasturiy switch |
| `veth<id>@if<N>` | veth | virtual kabelning bir uchi (6-bo'lim) |
| `tun0`, `wg0` | tunnel | VPN interfeyslari (6-dars) |

Nomlar "predictable" sxemada: `enp0s1` degani Ethernet, PCI shina 0, slot 1. Shuning uchun bir xil Ubuntu VM Zorin'da `ens3`, macOS'da `enp0s1` bo'lib chiqadi: virtual "temir" boshqacha joylashgan.

Kernel har interfeys haqidagi ma'lumotni fayl ko'rinishida ham beradi (`linux` 1-dars, "hamma narsa fayl"):

```
ubuntu@lab:~$ cat /sys/class/net/lo/mtu
65536
ubuntu@lab:~$ ls /sys/class/net/
docker0  ens3  lo
```

`lo` ning MTU'si 65536: loopback'da haqiqiy sim yo'q, shuning uchun 1500 chegarasi ham yo'q.

### Holatni o'zgartirish (faqat konteyner yoki VM'da)

```
ip link set dev <iface> down       # administratively disable
ip link set dev <iface> up
ip link set dev <iface> mtu 1400
```

Bu buyruqlar darhol ta'sir qiladi va qayta yuklashda yo'qoladi. VM'ning asosiy interfeysini `down` qilsangiz `multipass shell` ham uziladi (u SSH orqali ishlaydi) va VM'ni `multipass restart lab` bilan tiklashga to'g'ri keladi. Shuning uchun bu darsda holat faqat `h1`, `h2` konteynerlari ichida o'zgartiriladi.

### Real ishda qachon kerak

- Yangi serverga kirganda birinchi buyruqlardan biri `ip -br addr`: qaysi interfeyslar bor, qaysi biri `UP`, manzillari nima.
- `ip -s link` dagi `errors` va `dropped` o'sib borsa, muammo kabel, karta yoki bufer to'lishida.
- `NO-CARRIER` ko'rsangiz, IP yoki firewall'ni tekshirishga hojat yo'q: muammo fizik qatlamda.

### Nima uchun shunday

Nega `ifconfig` emas `ip`? `ifconfig` kernel bilan eski interfeys (ioctl) orqali gaplashadi va bitta interfeysdagi bir nechta manzil, namespace, policy routing kabi yangi imkoniyatlarni to'liq ko'rsata olmaydi. `ip` netlink orqali ishlaydi va link, addr, route, neigh ob'ektlarini bitta sintaksisda boshqaradi. Nega `eth0` o'rniga `ens3`? Eski `ethN` nomlari kernel kartani qaysi tartibda topganiga bog'liq edi va qayta yuklashda almashib qolardi; ikki kartali serverda bu firewall qoidalarini noto'g'ri interfeysga qo'llashni anglatardi. Konteyner ichida esa hali ham `eth0`, chunki u yerda karta bitta va uni Docker o'zi nomlaydi.

---

## 5. ARP: IP dan MAC ga

### Bu nima

Dastur manzilni IP ko'rinishida beradi (`ping 10.118.52.1`), lekin frame'ga MAC kerak. **ARP** (Address Resolution Protocol) shu bo'shliqni to'ldiradi: "shu IP kimda? MAC'ingni ayt". Natijalar kernel'ning **neighbour table** (ARP cache, qo'shnilar jadvali) ida saqlanadi.

### Mexanizm

1. Host A manzil IP o'z LAN'ida ekanini aniqlaydi va neighbour table'ga qaraydi. Yozuv bo'lmasa:
2. A **ARP request** yuboradi: dst MAC `ff:ff:ff:ff:ff:ff` (broadcast), mazmuni "who-has `<IP>` tell `<A IP>`". Switch uni barcha portlarga tarqatadi.
3. Faqat shu IP egasi **ARP reply** qaytaradi, endi unicast: "`<IP>` is-at `<MAC>`".
4. A javobni jadvalga yozadi va kutib turgan paketni frame'ga o'rab yuboradi.

Manzil IP **boshqa tarmoqda** bo'lsa, A manzilning o'zini emas, **default gateway**'ning MAC'ini ARP bilan so'raydi. Shuning uchun neighbour table'da faqat o'z LAN'ingizdagi qo'shnilar bo'ladi, `1.1.1.1` hech qachon ko'rinmaydi.

### Misol: neighbour table

```
ubuntu@lab:~$ ip neigh show
10.118.52.1 dev ens3 lladdr 52:54:00:9e:11:f0 REACHABLE
```

- `10.118.52.1`: qo'shnining IP'si (bu yerda gateway).
- `dev ens3`: u qaysi interfeys orqali ko'rinadi.
- `lladdr 52:54:00:9e:11:f0`: link-layer address, ya'ni MAC.
- `REACHABLE`: holat.

| Holat | Ma'nosi |
|-------|---------|
| `REACHABLE` | yaqinda tasdiqlangan, ishlatsa bo'ladi |
| `STALE` | yozuv bor, lekin anchadan beri tasdiqlanmagan; birinchi ishlatishda qayta tekshiriladi |
| `DELAY`, `PROBE` | qayta tekshirish jarayonida |
| `INCOMPLETE` | ARP request yuborilgan, javob hali yo'q |
| `FAILED` | javob kelmadi: bu IP'da hech kim yo'q yoki u LAN'da ko'rinmaydi |
| `PERMANENT` | qo'lda kiritilgan, eskirmaydi |

macOS host'da shu jadvalning o'xshashi `arp -a` (ixtiyoriy).

### Misol: mavjud bo'lmagan qo'shni

O'z LAN'ingizdagi band bo'lmagan manzilga ping qilsangiz, xato router'dan emas, o'zingizning kernel'ingizdan keladi:

```
ubuntu@lab:~$ ping -c 2 <unused IP in your LAN>
From 10.118.52.87 icmp_seq=1 Destination Host Unreachable
```

`From` dan keyin o'z IP'ingiz turibdi: ARP javobsiz qoldi, kernel frame yasay olmadi va buni o'zi xabar qildi. Bu "paket ketdi, lekin javob kelmadi" (timeout) dan farq qiladi va tashxisni aniq joyga yo'naltiradi: muammo shu LAN ichida.

### Real ishda qachon kerak

- "Ping yo'q" da `ip neigh` ga qarang: `FAILED` bo'lsa muammo L2'da (host o'chiq, noto'g'ri VLAN, noto'g'ri tarmoq), firewall yoki route'da emas.
- Bitta IP'ning MAC'i vaqti-vaqti bilan almashib tursa, ikki qurilma bir xil IP olgan (IP conflict).
- Failover tizimlari (keepalived, cloud'dagi floating IP) IP'ni boshqa serverga ko'chirganda ataylab ARP e'lon yuboradi (gratuitous ARP), qo'shnilar jadvalini yangilash uchun.

### Nima uchun shunday

Nega IP va MAC bog'lanishi qo'lda yozilmaydi? Chunki hostlar keladi-ketadi, kartalar almashadi; dinamik so'rov sozlashsiz ishlaydi. Narxi: ARP'da autentifikatsiya yo'q, LAN'dagi istalgan host "bu IP menda" deb yolg'on javob bera oladi (ARP spoofing). Shuning uchun LAN ishonchli hudud deb hisoblanmaydi va shifrlash (TLS) yuqori qatlamda qilinadi. Cache nega eskiradi? Qo'shni o'chgan yoki MAC'i o'zgargan bo'lishi mumkin; `STALE` holati "ishlat, lekin tekshirib ol" degan murosa. IPv6'da ARP yo'q, uning ishini NDP (Neighbor Discovery) bajaradi, `ip neigh` ikkalasini ham ko'rsatadi.

---

## 6. Docker tarmog'i shu bloklardan yig'ilgan

### Bu nima

Konteyner bu alohida kompyuter emas, kernel'ning ajratilgan ko'rinishlari (namespace) ichida ishlaydigan oddiy jarayon. **Network namespace** bu tarmoq stekining alohida nusxasi: o'z interfeyslari, o'z routing va neighbour jadvallari. Docker konteynerga tarmoq berish uchun uchta narsani yig'adi:

| Blok | Haqiqiy dunyodagi o'xshashi | Qayerda |
|------|------------------------------|---------|
| network namespace | alohida kompyuter | har konteynerga bittadan |
| bridge (`docker0`, `br-<id>`) | switch | Docker ishlayotgan Linux'da (bizda `lab` VM) |
| veth juftligi | patch kabel | bir uchi konteynerda (`eth0`), ikkinchisi bridge'da (`veth<id>`) |

**veth** (virtual Ethernet) har doim juft yaratiladi: bir uchiga kirgan frame ikkinchi uchidan chiqadi, xuddi kabel kabi.

```
 container h1 (netns)        lab VM (root netns)         container h2 (netns)
   eth0 172.18.0.2  <--veth-->  [ br-<id> 172.18.0.1 ]  <--veth-->  eth0 172.18.0.3
                                      |
                                 ens3 / enp0s1  --> host --> internet
```

Bridge'ning o'zida ham IP bor (`172.18.0.1`): VM shu manzil bilan konteynerlar LAN'ining a'zosi va ularning default gateway'i, ya'ni router. Har `docker network create` yangi bridge, ya'ni yangi alohida LAN yaratadi.

### Misol: juftni topish

Konteyner ichidagi interfeys nomida `@if<N>` bor: bu juftning narigi uchi indeksi.

```
ubuntu@lab:~$ docker run --rm nicolaka/netshoot ip -br link show eth0
eth0@if7         UP             <MAC> <BROADCAST,MULTICAST,UP,LOWER_UP>
```

`eth0@if7`: bu kabelning narigi uchi konteyner tashqarisida, indeksi 7 bo'lgan interfeys. VM'da `ip link` chiqishida `7:` bilan boshlanadigan qator o'sha veth bo'ladi, uning nomidagi `@if<M>` esa konteyner ichidagi `eth0` indeksini ko'rsatadi. Sizda raqamlar boshqa.

Bridge'ning MAC jadvali (2-bo'limdagi FDB) `bridge fdb show br <bridge>` bilan, portlari `bridge link show` bilan ko'riladi.

### macOS va Docker Desktop

Mac host'idagi Docker'da bu bridge va veth'lar Docker Desktop'ning yashirin Linux VM'i ichida, `ifconfig` ularni ko'rsatmaydi. Shuning uchun bu darsda Docker `lab` VM ichida ishlatiladi: u yerda Zorin'da ham, Mac'da ham hammasi `ip link` da ko'rinadi.

### Real ishda qachon kerak

- "Konteyner A konteyner B ni ko'rmayapti": birinchi tekshiruv, ular bitta Docker tarmog'idami (bitta bridge, bitta broadcast domain).
- Kubernetes CNI plaginlari (k8s moduli) xuddi shu veth va bridge g'oyasidan foydalanadi.
- Host'da `veth...` interfeyslari ko'payib ketganini ko'rsangiz, bu ishlayotgan konteynerlar soni.

### Nima uchun shunday

Docker yangi tarmoq texnologiyasi o'ylab topmagan, kernel'da allaqachon bor bloklarni avtomatlashtirgan. Afzalligi: oddiy Linux asboblari (`ip`, `bridge`, `tcpdump`) konteyner tarmog'ida ham ishlaydi, fizik tarmoq haqidagi bilim to'g'ridan-to'g'ri ko'chadi. Muqobili ham bor: `--network host` konteynerga alohida namespace bermaydi (tezroq, lekin izolyatsiya yo'q), overlay tarmoqlar bir nechta mashinadagi konteynerlarni bitta virtual LAN'ga ulaydi (docker moduli).

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| host | tarmoqda ma'lumot yuboradigan yoki qabul qiladigan har qanday qurilma |
| LAN | router'dan o'tmasdan bir-biriga frame yubora oladigan hostlar to'plami |
| WAN | katta hududni qamraydigan, odatda provayderga tegishli tarmoq |
| ISP | internetga ulaydigan provayder kompaniya |
| broadcast | LAN'dagi barcha hostlarga yuboriladigan frame (`ff:ff:ff:ff:ff:ff`) |
| broadcast domain | bitta broadcast yetib boradigan hostlar to'plami, amalda LAN |
| switch | frame'ni MAC manzilga qarab kerakli portga uzatadigan qurilma |
| FDB | switch yoki bridge'ning "MAC qaysi portda" jadvali |
| router | paketni IP manzilga qarab boshqa tarmoqqa uzatadigan qurilma |
| default gateway | host o'z LAN'idan tashqaridagi manzillar uchun paket beradigan router |
| hop | paketning bir router'dan keyingisiga bitta o'tishi |
| MAC manzil | tarmoq kartasining 48 bitli LAN ichidagi manzili |
| OUI | MAC'ning birinchi 3 bayti, ishlab chiqaruvchi kodi |
| frame | LAN ichida yuriladigan ma'lumot bo'lagi, MAC sarlavhali |
| paket | frame ichidagi IP sarlavhali ma'lumot bo'lagi |
| EtherType | frame payload'i qaysi protokol ekanini aytadigan maydon |
| MTU | bitta frame payload'ining maksimal hajmi, odatda 1500 bayt |
| interfeys | kernel'ning tarmoq kartasi (fizik yoki virtual) uchun ob'ekti |
| loopback | mashinaning o'zi bilan gaplashadigan virtual interfeys (`lo`) |
| ARP | IP manzil bo'yicha MAC manzilni topadigan protokol |
| neighbour table | kernel'dagi "IP qaysi MAC'da" jadvali (ARP cache) |
| bridge | Linux kernel'idagi dasturiy switch |
| veth | juft yaratiladigan virtual Ethernet interfeysi, virtual kabel |
| network namespace | tarmoq stekining ajratilgan nusxasi (interfeyslar, route, neigh) |

## Tuzoqlar

- **Interfeys nomini ko'chirish.** Darsdagi `ens3` sizda `enp0s1` yoki boshqa bo'lishi mumkin. Avval `ip -br link`.
- **`UP` degani "ishlayapti" emas.** `UP` administrator bayrog'i. Kabel yoki signal bor-yo'qligini `LOWER_UP` va `state` ko'rsatadi.
- **Boshqa tarmoqdagi hostni `ip neigh` dan qidirish.** U yerda faqat o'z LAN'ingiz. Uzoq manzil uchun gateway'ning yozuvi ishlatiladi.
- **Asosiy interfeysni `down` qilish.** VM'da `multipass shell` uziladi, haqiqiy serverda SSH uziladi va konsolsiz qaytib bo'lmaydi. Tajribalarni konteynerda qiling.
- **Mac host'ida veth qidirish.** Docker Desktop tarmog'i yashirin VM ichida. Bu darsda Docker `lab` VM ichida.
- **`ifconfig` chiqishiga ishonish (Linux'da).** U ikkilamchi manzillarni ko'rsatmasligi mumkin. Linux'da `ip` ishlating.
- **MAC'ni doimiy identifikator deb hisoblash.** Virtual kartalar va telefonlarda MAC dasturiy va o'zgaruvchan.
- **README'ga public IP va to'liq MAC yozish.** Oxirgi baytlarni `xx` bilan yashiring.

## Manbalar

- `ip-link(8)`, `ip-address(8)`, `ip-neighbour(8)`, `bridge(8)`, `tcpdump(8)`: VM ichida `man ip-link` va hokazo
- iproute2 man sahifalari: https://man7.org/linux/man-pages/man8/ip.8.html
- Linux kernel hujjati, sysfs net: https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-net
- RFC 826 (ARP): https://www.rfc-editor.org/rfc/rfc826
- IEEE OUI qidiruvi: https://standards-oui.ieee.org/
- Wireshark OUI lookup: https://www.wireshark.org/tools/oui-lookup.html
- Docker networking: https://docs.docker.com/engine/network/
- Docker bridge driver: https://docs.docker.com/engine/network/drivers/bridge/
- Predictable interface names: https://systemd.io/PREDICTABLE_INTERFACE_NAMES/
- Multipass hujjati: https://documentation.ubuntu.com/multipass/
- netshoot: https://github.com/nicolaka/netshoot

---

## Birga bajaramiz

Docker'siz, faqat kernel bloklari bilan eng kichik "tarmoq" quramiz: `lab` VM va bitta network namespace orasida virtual kabel (veth). Maqsad: 3–6 bo'limlardagi hamma narsani (interfeys holati, MAC, ARP, frame) bitta joyda ko'rish. Hammasi VM ichida, `sudo` bilan; oxirida hammasi o'chiriladi. Vazifalardagi stend boshqa (Docker bridge va konteynerlar).

**1-qadam: namespace va kabel.** Namespace bu "ichida hali hech narsa yo'q kompyuter":

```
ubuntu@lab:~$ sudo ip netns add demo
ubuntu@lab:~$ sudo ip link add veth-vm type veth peer name veth-demo
ubuntu@lab:~$ ip -br link show type veth
veth-demo@veth-vm DOWN           6e:0c:11:5a:90:21 <BROADCAST,MULTICAST,M-DOWN>
veth-vm@veth-demo DOWN           b2:7f:3c:44:d8:02 <BROADCAST,MULTICAST,M-DOWN>
```

Kabelning ikkala uchi hozircha VM'da va ikkalasi `DOWN`. MAC'larning birinchi baytiga qarang (`6e`, `b2`): ikkinchi raqam `e` va `2`, ya'ni locally administered, kernel ularni tasodifiy bergan.

**2-qadam: bir uchini namespace ichiga o'tkazamiz.**

```
ubuntu@lab:~$ sudo ip link set veth-demo netns demo
ubuntu@lab:~$ ip -br link show type veth
veth-vm@if8      DOWN           b2:7f:3c:44:d8:02 <BROADCAST,MULTICAST>
ubuntu@lab:~$ sudo ip netns exec demo ip -br link
lo               DOWN           00:00:00:00:00:00 <LOOPBACK>
veth-demo@if9    DOWN           6e:0c:11:5a:90:21 <BROADCAST,MULTICAST>
```

VM'da endi faqat bitta uch qoldi va nomi `veth-vm@if8` ga aylandi: narigi uch boshqa namespace'da, shuning uchun nom o'rniga indeks ko'rsatiladi. `ip netns exec demo <buyruq>` buyruqni o'sha namespace ichida bajaradi. Docker'ning `eth0@if<N>` yozuvi aynan shu.

**3-qadam: manzil beramiz va yoqamiz.**

```
ubuntu@lab:~$ sudo ip addr add 10.99.0.1/24 dev veth-vm
ubuntu@lab:~$ sudo ip link set veth-vm up
ubuntu@lab:~$ ip -br addr show veth-vm
veth-vm@if8      LOWERLAYERDOWN 10.99.0.1/24
```

Holat `LOWERLAYERDOWN` (flag'larda `NO-CARRIER`): biz o'z uchimizni yoqdik, lekin narigi uch hali o'chiq. Bu "kabelning narigi tomoni tiqilmagan" holati. Narigi uchni yoqamiz:

```
ubuntu@lab:~$ sudo ip netns exec demo ip addr add 10.99.0.2/24 dev veth-demo
ubuntu@lab:~$ sudo ip netns exec demo ip link set veth-demo up
ubuntu@lab:~$ ip -br addr show veth-vm
veth-vm@if8      UP             10.99.0.1/24 fe80::b07f:3cff:fe44:d802/64
```

Endi `UP`: ikkala uch tirik.

**4-qadam: ARP'ni jonli ko'ramiz.** Ikkinchi terminalda (`multipass shell lab`) tcpdump'ni ishga tushiramiz, birinchisida ping:

```
# terminal 2
ubuntu@lab:~$ sudo tcpdump -i veth-vm -n -e -c 4 arp or icmp

# terminal 1
ubuntu@lab:~$ ping -c 1 10.99.0.2
64 bytes from 10.99.0.2: icmp_seq=1 ttl=64 time=0.071 ms
```

tcpdump chiqishi (vaqt belgilari qisqartirilgan):

```
b2:7f:3c:44:d8:02 > ff:ff:ff:ff:ff:ff, ethertype ARP (0x0806), length 42: Request who-has 10.99.0.2 tell 10.99.0.1, length 28
6e:0c:11:5a:90:21 > b2:7f:3c:44:d8:02, ethertype ARP (0x0806), length 42: Reply 10.99.0.2 is-at 6e:0c:11:5a:90:21, length 28
b2:7f:3c:44:d8:02 > 6e:0c:11:5a:90:21, ethertype IPv4 (0x0800), length 98: 10.99.0.1 > 10.99.0.2: ICMP echo request, id 5, seq 1, length 64
6e:0c:11:5a:90:21 > b2:7f:3c:44:d8:02, ethertype IPv4 (0x0800), length 98: 10.99.0.2 > 10.99.0.1: ICMP echo reply, id 5, seq 1, length 64
```

- 1-qator: ARP request. Dst MAC broadcast, EtherType `0x0806`. "10.99.0.2 kimda, 10.99.0.1 ga ayt."
- 2-qator: ARP reply. Endi unicast, to'g'ridan-to'g'ri so'ragan MAC'ga.
- 3–4-qatorlar: MAC ma'lum bo'lgach, ping'ning o'zi. EtherType `0x0800` (IPv4), dst MAC endi aniq.

**5-qadam: jadvalda nima qoldi.**

```
ubuntu@lab:~$ ip neigh show dev veth-vm
10.99.0.2 lladdr 6e:0c:11:5a:90:21 REACHABLE
```

Pingni takrorlasangiz, tcpdump'da ARP qatorlari chiqmaydi: javob cache'da. Bir muddatdan keyin holat `STALE` ga o'tadi.

**6-qadam: yo'q qo'shni.**

```
ubuntu@lab:~$ ping -c 1 10.99.0.77
From 10.99.0.1 icmp_seq=1 Destination Host Unreachable
ubuntu@lab:~$ ip neigh show dev veth-vm
10.99.0.2 lladdr 6e:0c:11:5a:90:21 STALE
10.99.0.77 FAILED
```

`10.99.0.77` uchun `lladdr` yo'q va holat `FAILED`: ARP request'ga hech kim javob bermadi.

**7-qadam: tozalash.** Namespace o'chirilganda ichidagi veth uchi yo'qoladi, juftning ikkinchi uchi ham u bilan birga o'chadi:

```
ubuntu@lab:~$ sudo ip netns del demo
ubuntu@lab:~$ ip -br link show type veth
ubuntu@lab:~$
```

Xulosa: "ikki host bitta LAN'da" uchun kerak bo'lgan hamma narsa bu ikki interfeys, ular orasidagi kabel, bir tarmoqdagi ikki IP va ARP. Docker shu ishni har konteyner uchun avtomatik qiladi va o'rtaga bridge qo'yadi.

---

## Vazifalar

Ish papkasi: `network/01-network-types/` (`make new m=network n=01 name=network-types`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. A va B guruhlar `lab` VM ichida (faqat o'qish), C va D guruhlar VM ichidagi Docker stendida (Laboratoriya bo'limi). Har vazifada interfeys nomi va manzillarni o'zingiz toping. README boshida qaysi mashinada (Zorin yoki macOS) bajarganingizni yozing.

### A. Interfeyslar (`lab` VM)

1. **Interface inventory.** VM ichida `ip -br link` va `ip -br addr` ni ishga tushiring. Har interfeys uchun jadval tuzing: nomi, turi (loopback, Ethernet, bridge, veth), holati, MAC, IP. Turini aniqlashda `ip -d link show <iface>` dan foydalaning. Ixtiyoriy: host'dagi ro'yxatni ham qo'shing (Zorin: `ip -br addr`, macOS: `ifconfig` va `networksetup -listallhardwareports`) va Multipass host tomonda qaysi interfeysni yaratganini toping.
   Yo'nalish: 4-bo'lim, "Interfeys nomlari va turlari" jadvali.

2. **Reading flags.** VM'ning asosiy interfeysi uchun `ip addr show <iface>` chiqishidagi `<...>` ichidagi har bir flag, `mtu`, `state`, `scope`, `dynamic`, `valid_lft` nimani anglatishini yozing. VM'da `NO-CARRIER` holatidagi interfeys bormi, nima uchun?
   Yo'nalish: 4-bo'lim, "ip addr chiqishini o'qish"; 2-bo'limdagi `docker0` misoli.

3. **MAC anatomy.** VM asosiy interfeysi MAC manzilining OUI qismini ajrating va u kimga tegishli ekanini aniqlang (IEEE yoki Wireshark OUI lookup sahifasi orqali; topilmasa nima uchun topilmasligini tushuntiring). Shu MAC va `docker0` ning MAC manzili universally yoki locally administered ekanini birinchi bayt bitidan aniqlang, hisobni ko'rsating. Ixtiyoriy: host'ning fizik kartasi (Wi-Fi yoki Ethernet) uchun ham shuni qiling.
   Yo'nalish: 3-bo'lim, "MAC manzil" dagi bit jadvali va hisob misoli.

4. **Interface statistics.** `ip -s link show <iface>` chiqishidagi RX va TX qatorlaridagi `errors`, `dropped` ustunlarini yozing. Bir necha megabayt yuklab (`curl -o /dev/null <katta fayl URL>`) hisoblagichlar qanday o'zgarganini ko'rsating.
   Yo'nalish: 4-bo'lim buyruqlar ro'yxati; `man ip-link` da `-s` ni qidiring.

5. **sysfs.** `/sys/class/net/<iface>/` ichidan `address`, `mtu`, `operstate`, `carrier` fayllarini o'qing va `ip link` chiqishi bilan solishtiring. `lo` uchun `operstate` nima va nima uchun bu normal?
   Yo'nalish: 4-bo'limdagi `/sys/class/net` misoli va Manbalar'dagi sysfs-class-net hujjati.

### B. Qo'shnilar va gateway (`lab` VM)

6. **Neighbour table.** VM ichida `ip neigh show` chiqishini yozing. Har yozuv qaysi qurilma ekanini aniqlashga harakat qiling (gateway, host, konteyner). Holatlar ustunini izohlang. Ixtiyoriy: host'dagi jadvalni ham ko'ring (Zorin: `ip neigh`, macOS: `arp -a`) va unda router, telefon kabi qurilmalarni toping.
   Yo'nalish: 5-bo'lim, holatlar jadvali.

7. **Gateway MAC.** `ip route show default` dan default gateway IP'sini toping, keyin uning MAC'ini `ip neigh` dan toping. `ping -c 3 1.1.1.1` qilganingizda frame'ning manzil MAC'i kimniki bo'ladi, manzil IP'si kimniki? Nima uchun `1.1.1.1` `ip neigh` da ko'rinmaydi? Bu gateway aslida qaysi qurilma (Zorin va macOS'da host tomondagi qaysi interfeys)?
   Yo'nalish: 1-bo'limdagi `ip route` misoli, 3-bo'limdagi tcpdump misoli, 5-bo'lim "Mexanizm".

8. **Failed neighbour.** VM'ning LAN'idagi band bo'lmagan IP'ga (masalan oxirgi oktetni o'zgartirib) `ping -c 2` qiling, keyin darhol `ip neigh show` ni ko'ring. Yangi yozuv holatini va `ping` xato matnini yozing. Bu xato boshqa tarmoqdagi mavjud bo'lmagan IP'ga ping qilgandagi natijadan nimasi bilan farq qiladi?
   Yo'nalish: 5-bo'lim, "mavjud bo'lmagan qo'shni"; ikkinchi holatni o'zingiz sinab solishtiring.

9. **Home network map.** Uy yoki ofis tarmog'ingiz sxemasini matn (ASCII) ko'rinishida chizing: qurilmalar, ular orasidagi bog'lanish turi (sim, Wi-Fi), har birining IP va MAC'i (bilganingizcha), qaysi qurilma qaysi rollarni bajaradi (router, switch, AP, DHCP, NAT). Sxemaga `lab` VM va Multipass virtual tarmog'ini ham qo'shing. Public IP'ingizni `curl -s https://ifconfig.me` bilan aniqlang va u sxemadagi qaysi qurilmaga tegishli ekanini yozing. Host ma'lumotlari uchun Zorin'da `ip -br addr`, `ip route`, `ip neigh`; macOS'da `ifconfig`, `netstat -rn`, `arp -a`.
   Yo'nalish: 1-bo'lim "Internet tuzilishi" sxemasi, 2-bo'lim qurilmalar jadvali.

### C. Bridge va veth (VM ichidagi Docker)

10. **Two hosts one LAN.** Laboratoriya bo'limidagi `lab-net`, `h1`, `h2` ni yarating. Har ikkala konteynerda `ip -br addr` ni ko'ring. VM'da `ip -br link` da qanday yangi interfeyslar paydo bo'lganini yozing (bridge va veth'lar). `docker0` ning holati o'zgardimi, nima uchun?
    Yo'nalish: 6-bo'lim sxemasi; stendni yaratishdan oldin va keyin `ip -br link` ni solishtiring.

11. **Veth pairs.** `h1` ichidagi `eth0@ifN` va VM'dagi `vethXXXX@ifM` indekslari orqali qaysi veth qaysi konteynerga tegishli ekanini aniqlang. Usulni tushuntiring.
    Yo'nalish: 6-bo'lim "juftni topish" va "Birga bajaramiz" 2-qadam.

12. **Bridge FDB.** VM'da `bridge link show` va `bridge fdb show br <lab-net bridge nomi>` ni ishga tushiring. `h1` dan `h2` ga ping qilgandan keyin jadvalda konteynerlar MAC'lari qaysi portda ko'rinishini yozing. Bu jadval switch'ning qaysi funksiyasiga mos keladi?
    Yo'nalish: 2-bo'lim "Switch qanday ishlaydi"; bridge nomini `ip -br link show type bridge` dan toping.

13. **Network isolation.** Ikkinchi tarmoq `lab-net2` va unda `h3` konteynerini yarating. `h1` dan `h3` ning IP'siga ping qiling. Natijani va sababini "broadcast domain" atamasi bilan izohlang. `h1` ning `ip neigh` jadvalida nima paydo bo'ldi?
    Yo'nalish: 1-bo'lim "LAN'ning amaliy ta'rifi", 5-bo'lim (boshqa tarmoq uchun kim so'raladi).

### D. ARP va frame'lar (VM ichidagi Docker)

14. **Watch ARP.** `h1` da `ip neigh flush dev eth0` qiling. Bir terminalda `h2` ichida `tcpdump -i eth0 -n -e arp or icmp` ni ishga tushiring, ikkinchisida `h1` dan `h2` ga `ping -c 2`. tcpdump chiqishidan ARP request va reply qatorlarini ko'chiring va har birida manba MAC, manzil MAC va EtherType ni ko'rsating.
    Yo'nalish: "Birga bajaramiz" 4-qadam; ikkinchi terminal uchun yana bir `multipass shell lab` oching.

15. **ARP only once.** 14-vazifani flush qilmasdan takrorlang. Bu safar ARP so'rov bormi? Sababini neighbour holati bilan izohlang. Bir necha daqiqadan keyin `ip neigh` holati qanday o'zgaradi?
    Yo'nalish: 5-bo'lim holatlar jadvali.

16. **Link down.** `h2` da `ip link set dev eth0 down` qiling. `h2` da `ip addr show eth0` chiqishi qanday o'zgardi? `h1` dan ping natijasi va `h1` dagi `ip neigh` holatini yozing. `up` qilib qaytaring va aloqa tiklanganini ko'rsating. Default route nima bo'lganini `ip route` bilan tekshiring va kuzatganingizni izohlang.
    Yo'nalish: 4-bo'lim "Holatni o'zgartirish"; `down` dan oldin `h2` dagi `ip route` ni saqlab qo'ying.

17. **MTU mismatch.** `h1` da `ip link set dev eth0 mtu 1000` qiling. `h2` dan `h1` ga `ping -c 2 -s 500 <h1>` va `ping -c 2 -s 1400 <h1>` natijalarini solishtiring. Keyin `ping -M do -s 1400` (fragmentatsiyani taqiqlash) bilan `h1` dan `h2` ga yuboring va xato matnini yozing. MTU'ni 1500 ga qaytaring.
    Yo'nalish: 3-bo'lim, MTU ta'rifi; `man ping` da `-s` va `-M` ni o'qing.

18. **Duplicate IP.** `h3` ni `lab-net` ga `h2` bilan bir xil IP bilan ulashga urinib ko'ring (`docker network connect --ip <h2 IP> lab-net h3`). Docker nima deydi? Agar real LAN'da ikki host bir IP'ni olgan bo'lsa, qo'shnining `ip neigh` jadvalida nima kuzatilardi va foydalanuvchi buni qanday alomat sifatida ko'rardi?
    Yo'nalish: 5-bo'lim "Real ishda qachon kerak" (IP conflict).

### E. Yig'ish

19. **Troubleshooting checklist.** "Ikki host bir LAN'da, lekin bir-biriga ping bormayapti" holati uchun 5–7 qadamli tekshiruv ro'yxati yozing: har qadamda aniq buyruq, qaysi chiqish "yaxshi", qaysi chiqish "muammo shu yerda" degani. Faqat shu darsdagi qatlam (link, MAC, ARP) doirasida.
    Yo'nalish: 16, 8 va 13-vazifalarda ko'rgan alomatlaringizni pastdan yuqoriga tartiblang.

20. **Cleanup.** Yaratilgan barcha konteyner va tarmoqlarni o'chiring. `docker ps -a`, `docker network ls` va VM'dagi `ip -br link` chiqishi bilan veth va bridge'lar yo'qolganini tasdiqlang.
    Yo'nalish: Laboratoriya bo'limidagi "Tozalash".

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 20 ta vazifaning hammasi `## N. Title` sarlavhasi bilan bor, boshida qaysi mashinada bajarilgani yozilgan.
2. `make check` toza.
3. Laboratoriya konteynerlari va tarmoqlari o'chirilgan (20-vazifa), `demo` namespace'i qolmagan (`ip netns list` bo'sh).
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
- Nima uchun bu darsda Docker host'da emas, `lab` VM ichida ishlatildi? macOS'da host'dagi Docker bilan nima ko'rinmas edi?
