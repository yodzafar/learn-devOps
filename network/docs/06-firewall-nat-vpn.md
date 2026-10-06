# 6-dars: Firewall, NAT, VPN

Maqsad: paket yo'lida turadigan uch mexanizmni Linux misolida noldan tushunish. Firewall: paketni qoidalar bo'yicha o'tkazish yoki tashlash, kernel'dagi netfilter va uning ustidagi asboblar (nftables, iptables, ufw, firewalld). NAT: paket header'idagi manzilni yo'lda qayta yozish (SNAT, MASQUERADE, DNAT, port forwarding) va Docker buni qanday ishlatishi. VPN: ikki host orasida shifrlangan tunnel, WireGuard misolida, OpenVPN va IPsec sharhi bilan. 5-darsda Linux router paketni o'zgartirmasdan uzatar edi; bu darsda router paketni tashlaydi, qayta yozadi va shifrlaydi. Uchala mavzu bitta kernel quyi tizimiga (netfilter va conntrack) va routing'ga tayanadi. Cloud'dagi security group, NAT gateway va site-to-site VPN, Kubernetes'dagi Service va NetworkPolicy shu mexanizmlarning boshqariladigan ko'rinishi. Dars modul mini-loyihasi bilan tugaydi.

Taxminiy vaqt: 8 kun (siz uchun). 1-kun: 1–2 bo'limlar va 1-vazifa. 2-kun: 3-bo'lim, "Birga bajaramiz", 2–5 vazifalar. 3-kun: 4-bo'lim, 6–8 vazifalar. 4-kun: 5-bo'lim va B guruh. 5-kun: 6-bo'lim, C guruh, 7-bo'limni o'qish. 6-kun: D guruh (WireGuard). 7 va 8-kunlar: mini-loyiha (21) va runbook (22). Diqqatni quyidagilarga qarating: paket qaysi hook'lardan o'tadi (input va forward farqi), conntrack holatlari, qoida tartibi, NAT'da javob paketi qanday qaytishi, WireGuard'dagi `AllowedIPs` ning ikki vazifasi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Interfeys nomi, IP manzillar, portlar, hisoblagichlar sizda boshqa bo'ladi; darsda ular `<...>` bilan belgilangan. Bu darsdagi qoidalar noto'g'ri qo'llansa mashinaga kirishni uzadi, shuning uchun "Laboratoriya" bo'limidagi xavfsizlik qoidalarini avval o'qing.

## Laboratoriya

Bu darsda firewall, NAT va WireGuard'ga tegishli hamma narsa faqat VM ichida bajariladi. Zorin host'ida `ufw enable`, `nft -f`, `iptables -A`, WireGuard o'rnatish bajarilmaydi: ish mashinasining tarmog'i va Docker'i buzilishi mumkin. macOS'da netfilter umuman yo'q (uning firewall'i `pf`, boshqa tizim), unga ham tegilmaydi.

| Joy | Prompt | Bu darsda nima uchun |
|-----|--------|----------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `multipass`, `make`, `git`; hech narsa o'zgartirilmaydi |
| `net1`, `net2` VM (4-darsda yaratilgan) | `ubuntu@net1:~$` | barcha `nft`, `ufw`, `conntrack`, `ip netns`, WireGuard ishlari |
| `lab` VM | `ubuntu@lab:~$` | C guruh: Docker yaratgan NAT qoidalarini o'qish (Docker 1-darsda `lab` ichiga o'rnatilgan) |

`net1` va `net2` 4-darsda yaratilgan. Yo'q bo'lsa yoki 4 va 5-darslardan qolgan o'zgarishlar (qattiqlashtirilgan `sshd`, static route) xalaqit bersa, o'chirib qaytadan yarating. Ikkinchi mashinada ham xuddi shu: laboratoriya holati mashinalar orasida ko'chmaydi, javob fayllari (`.nft`, `.sh`, `README.md`) `git pull` bilan keladi. Host'da (ikkalasida bir xil):

```
multipass launch 24.04 --name net1 --cpus 1 --memory 1G --disk 5G
multipass launch 24.04 --name net2 --cpus 1 --memory 1G --disk 5G
multipass exec net1 -- sudo apt update
multipass exec net1 -- sudo apt install -y nftables conntrack wireguard tcpdump
multipass exec net2 -- sudo apt update
multipass exec net2 -- sudo apt install -y nftables conntrack wireguard tcpdump
multipass list
```

Bu yerda paketlar VM ichiga o'rnatiladi, shuning uchun Zorin va macOS uchun alohida ko'rsatma yo'q: ikkalasida bir xil Ubuntu 24.04 va bir xil `apt`. `multipass list` dagi `IPv4` ustuni VM manzillarini beradi; darsda ular `<net1 IP>`, `<net2 IP>`, VM'ning asosiy interfeysi `<iface>` deb yoziladi (`ip -br addr` dan oling).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | VM `amd64`, interfeys odatda `ens3`, manzil `10.x.x.x`. Host Linux, unda ham netfilter bor: o'qiydigan buyruqlar (`sudo nft list ruleset`, `sudo iptables -t nat -S`) ixtiyoriy ravishda ishlaydi, o'zgartiradigan buyruq bajarilmaydi. Host'dagi Docker Engine qoidalari host'da ko'rinadi. |
| macOS (uy) | VM `arm64`, interfeys odatda `enp0s1`, manzil `192.168.64.x`. Host'da `nft`, `iptables`, `ip`, `ss`, `conntrack`, `wg-quick` yo'q. Docker Desktop yashirin Linux VM ichida ishlaydi: uning NAT qoidalari, konteyner IP'lari va `docker0` host'da ko'rinmaydi. Shuning uchun C guruh `lab` VM ichidagi Docker'da bajariladi. |

### Qulflanib qolish xavfi va qaytish yo'li

`multipass shell net1` va `multipass exec net1 -- ...` VM'ga SSH orqali kiradi (4-dars): host'dan VM manzilining TCP 22-portiga, VM'ning asosiy interfeysi orqali. Demak siz qoidalarni aynan o'sha qoidalar filtrlaydigan ulanish ustidan qo'llaysiz. Kiruvchi trafikni "sukut bo'yicha tashla" qilib, SSH'ga ruxsat bermasangiz, terminal xato chiqarmaydi: shunchaki qotib qoladi, yangi `multipass shell` esa timeout bilan tugaydi. Haqiqiy serverda bu "serverga boshqa kirib bo'lmaydi" degani.

Qoidalar:

- Default-drop qo'llashdan oldin ruleset'da `ct state established,related accept` va `tcp dport 22 accept` borligini ko'zdan kechiring (3-bo'lim).
- Ikkinchi terminalda zaxira `multipass shell net1` sessiyasini ochiq saqlang.
- Xavfli yuklashdan oldin avtomatik qaytarish qo'ying: `sudo sh -c 'sleep 120; nft flush ruleset' &`. Hammasi joyida bo'lsa uni `sudo pkill sleep` bilan bekor qilasiz, qulflansangiz ikki daqiqadan keyin qoidalar o'zi tozalanadi.

Qulflanib qolsangiz, host'dan:

| Holat | Qaytish yo'li |
|-------|---------------|
| Qoidalar `nft -f` yoki `nft add` bilan yuklangan, faylga saqlanmagan | ular faqat kernel xotirasida: `multipass restart net1`, VM toza ruleset bilan ko'tariladi |
| Qoidalar doimiy qilingan (`/etc/nftables.conf` va yoqilgan `nftables` servisi, yoki `ufw enable`) | restart yordam bermaydi: `multipass delete net1 && multipass purge`, keyin yuqoridagi `launch` qatori |
| Oldindan snapshot olingan (`multipass stop net1 && multipass snapshot net1 --name clean`) | `multipass stop net1 && multipass restore net1.clean` |

Shu sababli A–D guruhlarda qoidalarni doimiy qilmang: `systemctl enable nftables` bu darsda kerak emas.

**Tozalash** (modul oxiri): `multipass delete net1 net2 && multipass purge`; `lab` ichida `docker rm -f web`.

---

## 1. Firewall: stateless, stateful va conntrack

### Bu nima

**Firewall** bu paketni header maydonlari (qaysi interfeysdan keldi, manba va manzil IP, protokol, port) bo'yicha qoidalar bilan solishtirib, o'tkazadigan yoki tashlaydigan mexanizm. U paket ichidagi ma'lumotni (HTTP so'rov matnini) o'qimaydi, faqat 3 va 4-qatlam header'lariga (2-dars) qaraydi. Maqsad: mashinada tinglayotgan har bir port (4-dars, `ss -tlnp`) tarmoqdagi hammaga ochiq bo'lmasligi.

Ikki xil yondashuv bor:

| Tur | Nimaga qaraydi | Oqibat |
|-----|----------------|--------|
| Stateless | har paketga alohida, oldingi paketlarni eslamaydi | javob paketlari uchun teskari qoida kerak: mijoz portlari tasodifiy (4-dars, ephemeral port) bo'lgani uchun yuqori portlarning hammasini ochishga to'g'ri keladi |
| Stateful | paket qaysi ulanishga tegishli ekaniga | "men boshlagan ulanishlarning javoblari o'tsin" degan bitta qoida yetadi |

### Mexanizm: conntrack

Linux firewall stateful. Kernel'dagi **conntrack** (connection tracking) moduli o'tayotgan har ulanishni jadvalga yozadi: protokol, ikki tomonning IP va portlari, holat va timeout. TCP uchun bu haqiqiy ulanish (4-dars), UDP va ICMP uchun "oqim": bir xil manzil va portlar orasidagi paketlar, oxirgi paketdan keyin timeout bilan o'chadi. Har paket kelganda conntrack uni jadvaldan qidiradi va holat beradi:

| Holat | Ma'nosi |
|-------|---------|
| `new` | jadvalda yo'q ulanishning birinchi paketi (TCP'da SYN) |
| `established` | ikkala yo'nalishda paket ko'rilgan ulanishga tegishli |
| `related` | mavjud ulanish bilan bog'liq boshqa oqim, masalan unga javoban kelgan ICMP xato xabari |
| `invalid` | hech qaysi ulanishga to'g'ri kelmaydi (masalan SYN'siz kelgan ACK) |

Firewall qoidasi shu holatga qarab qaror qiladi. Jadvalni ko'rish (`net1` da, `conntrack` paketi):

```
ubuntu@net1:~$ sudo conntrack -L -p tcp --dport 22
tcp      6 431997 ESTABLISHED src=<host IP> dst=<net1 IP> sport=<port> dport=22 src=<net1 IP> dst=<host IP> sport=22 dport=<port> [ASSURED] mark=0 use=1
conntrack v1.4.8 (conntrack-tools): 1 flow entries have been shown.
```

Maydonlar: `tcp 6` protokol nomi va raqami; `431997` yozuv o'chishigacha qolgan soniya (established TCP uchun 5 kun, har paketda yangilanadi); `ESTABLISHED` TCP holati; birinchi `src= dst= sport= dport=` to'rtligi asl yo'nalish (host sizning SSH sessiyangizni ochgan); ikkinchi to'rtlik kutilayotgan javob yo'nalishi (manzillar o'rin almashgan); `[ASSURED]` ikkala yo'nalishda trafik ko'rilgan, jadval to'lganda bu yozuv birinchi bo'lib o'chirilmaydi. Bu sizning `multipass shell` sessiyangiz. Agar chiqish bo'sh bo'lsa, conntrack hali yuklanmagan: u `ct state` ishlatadigan birinchi qoida yoki NAT qoidasi paydo bo'lganda yoqiladi.

### Default deny, drop va reject

Standart tuzilma **default deny**: kiruvchi hamma narsa taqiqlangan, `established,related` ga ruxsat, keyin kerakli portlar birma-bir ochiladi. Chiquvchi trafik odatda ochiq qoldiriladi.

Paketni rad etishning ikki usuli bor. `drop` paketni jim tashlaydi: mijoz javob olmaydi va timeout'gacha kutadi (4-dars, `Connection timed out`). `reject` rad javobini qaytaradi: nftables'da sukut bo'yicha ICMP "port unreachable", `reject with tcp reset` yozilsa TCP RST; ikkala holatda mijoz darhol `Connection refused` oladi. Internetga qaragan interfeysda odatda `drop` (skanerga hech narsa aytilmaydi), ichki tarmoqda `reject` tashxisni osonlashtiradi.

### Real ishda qachon kerak

- Har serverda: SSH, web va monitoring portlaridan boshqasi yopiq.
- Ma'lumotlar bazasi porti faqat ilova serverlari subnet'idan ochiq.
- Cloud'da shu tushuncha **security group** deb ataladi: stateful, faqat ruxsat qoidalaridan iborat, instans darajasida. AWS **network ACL** esa stateless va subnet darajasida, javob trafigi uchun alohida qoida talab qiladi. Amaliyoti cloud modulida.

### Nima uchun shunday

Dastlabki paket filtrlari stateless edi: sodda va tez, lekin "javoblarni o'tkaz" degan talabni faqat "1024 dan yuqori portlarga kelgan hamma narsani o'tkaz" deb yozish mumkin edi, bu esa katta teshik. Stateful filtr xotira sarflaydi (har ulanish uchun yozuv, jadval hajmi `sysctl net.netfilter.nf_conntrack_max` bilan cheklangan), lekin qoidalar qisqa va aniq bo'ladi. Muqobili hanuz ishlatiladi: juda katta trafikli routerlar va cloud network ACL'lar stateless, chunki ularda har ulanishni eslab qolish qimmat.

## 2. netfilter: paket yo'li va beshta hook

### Bu nima

**netfilter** kernel tarmoq stekidagi framework: paket yo'lining beshta aniq nuqtasida **hook** (ilgak) bor va firewall, NAT, conntrack o'z funksiyalarini shu nuqtalarga ro'yxatdan o'tkazadi. Frontend'dagi middleware zanjiriga o'xshaydi (Express'da `app.use`): so'rov belgilangan tartibda bir nechta funksiyadan o'tadi va istalgan biri uni to'xtata oladi. Farqi: bu yerda zanjir bitta emas, paket qayerga ketayotganiga qarab turli hook'lardan o'tadi.

```
                 +--> input --> [local process] --> output --+
                 |                                           v
NIC --> prerouting --> (routing decision) --> forward --> postrouting --> NIC
```

| Hook | Qaysi paketlar | Tipik ish |
|------|----------------|-----------|
| `prerouting` | interfeysdan kelgan hamma paket, routing qaroridan oldin | DNAT |
| `input` | shu hostning o'ziga mo'ljallangan | hostdagi servislarni himoyalash |
| `forward` | host orqali boshqa joyga o'tayotgan (router, konteynerlar, namespace'lar) | tarmoqlar orasida filtrlash |
| `output` | hostning o'z jarayonlari yaratgan | chiquvchi trafikni cheklash |
| `postrouting` | chiqayotgan hamma paket, interfeysga berilishidan oldin | SNAT, MASQUERADE |

### Mexanizm: uch xil yo'l

Paket kelganda kernel `prerouting` dan keyin routing qarorini qiladi (5-dars): manzil IP shu hostning manzillaridan birimi?

1. Hostning o'ziga (masalan `net2` dan `net1` dagi `sshd` ga): `prerouting` → `input` → jarayon.
2. Host orqali o'tayotgan (manzil boshqa host, `ip_forward=1`, 5-dars): `prerouting` → `forward` → `postrouting`. `input` va `output` ga umuman kirmaydi.
3. Hostning o'zi yuborgan (`net1` dagi `curl`): `output` → `postrouting`. `prerouting` ga kirmaydi.

Bitta hook'ka bir nechta funksiya ilinishi mumkin, tartibni **priority** soni belgilaydi (kichigi oldin). `prerouting` da: conntrack (`-200`), keyin DNAT (`dstnat`, `-100`); `input` va `forward` da filtr (`filter`, `0`); `postrouting` da SNAT (`srcnat`, `100`). Shuning uchun filtr qoidasi paketni conntrack holati aniqlangandan va DNAT manzilni almashtirgandan keyin ko'radi.

Misol: uchta yo'lni hisoblagich bilan ko'rish. `net1` da vaqtinchalik jadval (hech narsani tashlamaydi, faqat sanaydi):

```
ubuntu@net1:~$ sudo nft add table inet probe
ubuntu@net1:~$ sudo nft add chain inet probe in '{ type filter hook input priority filter; }'
ubuntu@net1:~$ sudo nft add chain inet probe fwd '{ type filter hook forward priority filter; }'
ubuntu@net1:~$ sudo nft add chain inet probe out '{ type filter hook output priority filter; }'
ubuntu@net1:~$ sudo nft add rule inet probe in counter
ubuntu@net1:~$ sudo nft add rule inet probe fwd counter
ubuntu@net1:~$ sudo nft add rule inet probe out counter
ubuntu@net1:~$ ping -c 3 1.1.1.1 > /dev/null
ubuntu@net1:~$ sudo nft list table inet probe
table inet probe {
	chain in {
		type filter hook input priority filter; policy accept;
		counter packets <N> bytes <N>
	}

	chain fwd {
		type filter hook forward priority filter; policy accept;
		counter packets 0 bytes 0
	}

	chain out {
		type filter hook output priority filter; policy accept;
		counter packets <N> bytes <N>
	}
}
ubuntu@net1:~$ sudo nft delete table inet probe
```

O'qish: `in` va `out` hisoblagichlari o'sgan (ping so'rovlari `output` dan chiqdi, javoblar va sizning SSH paketlaringiz `input` dan kirdi), `fwd` nol: bu VM hozircha hech kimning paketini uzatmayapti. B guruhda namespace qo'shilgach aynan `fwd` o'sadi. `policy accept` yozilmagan bo'lsa ham sukut bo'yicha shu.

**Tuzoq: `input` va `forward` ni aralashtirish.** Konteyner, namespace yoki router ortidagi hostga ketayotgan paket `input` dan o'tmaydi, u `forward` dan o'tadi. `input` zanjirida portni yopish hostning o'z servislarini himoyalaydi, konteynerlarni emas. Docker va ufw o'rtasidagi mashhur muammoning ildizi shu (6-bo'lim).

### Real ishda qachon kerak

- "Qoida yozdim, ishlamayapti" tashxisining birinchi savoli: paket umuman shu hook'dan o'tadimi?
- Kubernetes node'i aslida router: pod'lar trafigi `forward` dan o'tadi, node'ning o'z servislari (`kubelet`, `sshd`) `input` dan.
- NAT qoidasini qaysi hook'ka yozishni tanlash (5-bo'lim).

### Nima uchun shunday

Hook'lar routing qaroriga nisbatan joylashgan, chunki har biri boshqa savolga javob beradi: manzilni routing'dan oldin almashtirish kerak (`prerouting`, aks holda paket noto'g'ri yo'lga ketadi), manbani esa chiqish interfeysi ma'lum bo'lgandan keyin (`postrouting`). `input` va `forward` ajratilgani hostni va uning ortidagi tarmoqni alohida siyosat bilan himoyalash imkonini beradi. Bu tuzilma 2001-yilda Linux 2.4 bilan kelgan va shundan beri o'zgarmagan; o'zgargani faqat ustidagi asboblar (`ipchains` → `iptables` → `nftables`). Muqobil yondashuv eBPF (Cilium): paketni hook'lardan ham oldin ushlaydi, kubernetes modulida uchraydi.

## 3. nftables: table, chain, rule, set

### Bu nima

**nftables** netfilter'ni boshqaradigan zamonaviy quyi tizim, buyrug'i `nft`. Tuzilma to'rt tushunchadan iborat:

| Tushuncha | Nima |
|-----------|------|
| **table** | qoidalar konteyneri, **oila** si bilan: `ip` (faqat IPv4), `ip6` (faqat IPv6), `inet` (ikkalasi). Nomi ixtiyoriy |
| **chain** | qoidalar ro'yxati. **Base chain** hook'ka ilingan (`type ... hook ... priority ...`) va `policy` ga ega; oddiy chain'ga boshqa chain'dan `jump` qilinadi |
| **rule** | chapdan o'ngga o'qiladigan shartlar va oxirida hukm: `accept`, `drop`, `reject` |
| **set** | qiymatlar to'plami (portlar, manzillar), qoidada `@nom` bilan ishlatiladi va qoidalarni qayta yuklamasdan o'zgartiriladi |

### Mexanizm: qoidalar qanday o'qiladi

Paket base chain'ga kirganda qoidalar yuqoridan pastga tekshiriladi. Qoidaning barcha shartlari mos kelsa hukm bajariladi: `accept` paketni shu chain'dan o'tkazadi, `drop` butunlay tashlaydi, tekshiruv to'xtaydi. Hech bir qoida hukm chiqarmasa chain'ning `policy` si ishlaydi. Demak tartib muhim: yuqoridagi keng qoida pastdagi tor qoidani "soya" qiladi.

Web server uchun `input` chain'i (bu misol, vazifadagi holat emas):

```
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif "lo" accept
        tcp dport 22 accept
        tcp dport { 80, 443 } accept
    }
}
```

Qatorma-qator:

- `type filter hook input priority filter; policy drop;`: bu chain `input` hook'iga ilingan, hech bir qoida mos kelmagan paket tashlanadi.
- `ct state established,related accept` birinchi turadi. U ikki ish qiladi: host o'zi boshlagan ulanishlarning (DNS, `apt`, API chaqiruvlari) javoblari kiradi va allaqachon ochiq SSH sessiyangiz uzilmaydi. Trafikning asosiy qismi shu qatorda hal bo'ladi.
- `ct state invalid drop`: hech qaysi ulanishga tegishli bo'lmagan paketlar.
- `iif "lo" accept`: lokal jarayonlar `127.0.0.1` orqali gaplashadi (masalan DNS uchun `127.0.0.53`, 4-dars), uni yopish ko'p narsani buzadi.
- `tcp dport 22 accept`: yangi SSH ulanishlar. Bu qatorsiz hozirgi sessiya ishlayveradi, lekin keyingisi ochilmaydi.
- `tcp dport { 80, 443 } accept`: figurali qavs ichida nomsiz set.

ICMP alohida qaror talab qiladi: `meta l4proto { icmp, ipv6-icmp } accept`. To'liq yopilsa PMTUD (2-dars) va `ping` tashxisi buziladi, IPv6 da esa ICMPv6 siz tarmoq umuman ishlamaydi (qo'shni topish, IPv4'dagi ARP o'rnida, shu protokolda).

### Buyruqlar

```
sudo nft list ruleset                         # everything, all tables
sudo nft -c -f fw.nft                         # check syntax only, load nothing
sudo nft -f fw.nft                            # load the file as one transaction
sudo nft add rule inet filter input tcp dport 8443 counter accept      # append
sudo nft insert rule inet filter input tcp dport 8443 counter accept   # put first
sudo nft -a list chain inet filter input      # show rule handles
sudo nft delete rule inet filter input handle <N>
sudo nft delete table inet filter
```

`nft -f` atomik: fayl to'liq qabul qilinadi yoki umuman qo'llanmaydi, "yarmi yuklangan" holat bo'lmaydi. Fayl boshiga `flush ruleset` yozilsa eski qoidalar va yangilari bitta tranzaksiyada almashadi. Har qoidaning **handle** raqami bor, o'chirish shu raqam bilan:

```
ubuntu@net1:~$ sudo nft -a list chain inet filter input
table inet filter {
	chain input { # handle 1
		type filter hook input priority filter; policy drop;
		ct state established,related accept # handle 2
		...
		tcp dport 8443 counter packets 0 bytes 0 accept # handle <N>
	}
}
```

`counter packets 0 bytes 0` shu qoidaga mos kelgan paketlar soni va hajmi: "qoidam umuman ishlayaptimi" savoliga javob. Yana foydali ifodalar: `ip saddr 10.0.0.0/8 tcp dport 5432 accept` (manba bo'yicha), `iifname "wg0" accept` (interfeys nomi bo'yicha; `iif` dan farqi, interfeys hali mavjud bo'lmasa ham yuklanadi), `log prefix "fw-drop: "` (kernel log'iga yozadi, `journalctl -k` da ko'rinadi), `reject`.

Doimiylik: Ubuntu'da `/etc/nftables.conf` fayli va `nftables` servisi (`systemctl enable nftables`) boot'da shu faylni yuklaydi. `nft add rule` bilan qo'shilgan qoida faylga yozilmaguncha reboot'da yo'qoladi. Laboratoriyada bu xususiyat sizning sug'urtangiz ("Qulflanib qolish xavfi").

**Tuzoq: SSH'ni ochmasdan default-drop.** `policy drop` ni `established,related` va 22-port qoidalarisiz qo'llash sizni uzadi. Tartib: qoidalarni faylga yozing, `nft -c -f` bilan tekshiring, avtomatik qaytarishni qo'ying, keyin `nft -f` bilan yuklang, zaxira sessiyadan yangi ulanish ochilishini sinang.

**Tuzoq: `flush ruleset` Docker o'rnatilgan hostda.** U barcha jadvallarni, shu jumladan Docker yaratgan NAT va forward qoidalarini o'chiradi: konteynerlar Docker qayta ishga tushirilmaguncha tarmoqsiz qoladi. Bunday hostda faqat o'z jadvalingizni tozalang (`flush table inet filter`). `net1` va `net2` da Docker yo'q, u yerda `flush ruleset` xavfsiz.

### Real ishda qachon kerak

- Bitta serverning firewall'ini kod sifatida saqlash: `.nft` fayl repo'da, Ansible uni serverga qo'yadi.
- Tashxis: `counter` va `log` vaqtincha qo'shiladi, paket qaysi qoidada to'xtagani ko'rinadi.
- Bloklangan IP ro'yxatini (`fail2ban` kabi asboblar) set orqali, qoidalarga tegmasdan yangilash.

### Nima uchun shunday

`iptables` da IPv4, IPv6, ARP va bridge uchun to'rtta alohida asbob bor edi, har qoida o'zgarishida butun jadval kernel'dan o'qilib qayta yozilardi, ko'p portni bitta qoidaga yig'ish uchun alohida `ipset` kerak edi. nftables (Linux 3.13, 2014) bularni bitta asbobga yig'di: `inet` oilasi ikkala IP versiyani qamraydi, yuklash atomik, set'lar tilning o'zida. Hech qanday oldindan belgilangan jadval yo'q: toza tizimda ruleset bo'sh va faqat siz yaratgan chain'lar hook'ka ilinadi.

## 4. Frontend'lar: iptables, ufw, firewalld

### Bu nima

Kernel mexanizmi bitta (netfilter), uni boshqaradigan asboblar ko'p. Qaysi asbob bilan yozilganidan qat'i nazar, qoidalar oxirida kernel'dagi bitta ruleset'ga tushadi.

| Asbob | Nima |
|-------|------|
| netfilter, conntrack | kernel mexanizmi |
| `nft` | nftables'ning o'z buyrug'i va qoida formati |
| `iptables` | eski asbob. Ubuntu 24.04 da `iptables-nft`: buyruq sintaksisi eski, qoidalar nftables ichiga yoziladi (`iptables -V` chiqishida `(nf_tables)`) |
| `ufw` | Ubuntu'dagi sodda frontend, ichkarida `iptables` qoidalarini yaratadi |
| `firewalld` | RHEL oilasidagi (Fedora, Rocky, Alma) zonalarga asoslangan frontend |

### iptables'ni o'qish

Eski qo'llanmalar, Docker va Kubernetes (`kube-proxy`) hanuz iptables tilida gapiradi, uni o'qiy olish kerak. iptables'da jadvallar oldindan belgilangan (`filter`, `nat`), chain nomlari katta harfda (`INPUT`, `FORWARD`, `POSTROUTING`).

| iptables | nftables'dagi ma'nosi |
|----------|-----------------------|
| `iptables -S`, `iptables -L -n -v` | `filter` jadvalini ko'rish |
| `iptables -t nat -S` | `nat` jadvalini ko'rish |
| `iptables -P INPUT DROP` | `policy drop` |
| `iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | `ct state established,related accept` |
| `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` | `tcp dport 22 accept` |
| `iptables -I INPUT 1 ...` | chain boshiga qo'shish (`-A` oxiriga) |

### ufw

`ufw` (Uncomplicated Firewall) bitta serverli holatlar uchun yetarli. U qoidalarni `/etc/ufw/` da saqlaydi, shuning uchun `ufw enable` reboot'dan keyin ham amal qiladi (laboratoriyada: restart qutqarmaydi).

```
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow from 10.0.0.0/8 to any port 5432 proto tcp
sudo ufw limit 22/tcp            # deny if 6+ connections in 30 seconds from one IP
sudo ufw enable
sudo ufw status numbered         # then: sudo ufw delete N
```

```
ubuntu@net2:~$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

O'qish: `Default` qatori uch siyosat: kiruvchi (`input`), chiquvchi (`output`) va `routed` (`forward`; forwarding yoqilmagan bo'lsa `disabled`). Har qoida ikki marta: IPv4 va `(v6)`. `established,related`, loopback va ICMP qoidalari ro'yxatda ko'rinmaydi, lekin ufw ularni o'zi qo'shadi: to'liq manzarani faqat `sudo nft list ruleset` beradi. ufw sukut bo'yicha `forward` trafigini taqiqlaydi (`/etc/default/ufw` dagi `DEFAULT_FORWARD_POLICY="DROP"`), router yoki VPN server uchun buni hisobga olish kerak.

### firewalld

RHEL oilasida interfeyslar **zona** larga biriktiriladi (`public`, `internal`, `trusted`), har zonada ruxsat etilgan servis va portlar ro'yxati. O'zgarishlar ikki qatlamli: runtime va `--permanent`.

```
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### Real ishda qachon kerak

- Bitta Ubuntu server: `ufw`. Router, NAT, murakkab siyosat: to'g'ridan-to'g'ri `nft`. RHEL oilasi: `firewalld`.
- Bir hostda bitta frontend ishlating. `ufw`, qo'lda `nft` va Docker qoidalari aralashsa natijani faqat `sudo nft list ruleset` to'liq ko'rsatadi.

### Nima uchun shunday

Frontend'lar eng ko'p uchraydigan holatni (bir server, bir nechta ochiq port) bir qatorga tushirish uchun yaratilgan, evaziga hook va tartib ustidan nazoratni yashiradi. `iptables-nft` moslik qatlami esa o'tish davri uchun: minglab skript va asbob eski sintaksisda yozilgan, kernel'da esa ikki parallel tizimni ushlab turish o'rniga bittasi qoldi.

## 5. NAT: manzilni yo'lda qayta yozish

### Bu nima

**NAT (Network Address Translation)** paket header'idagi IP manzil yoki portni yo'lda qayta yozadi. Sababi: private manzillar (3-dars, RFC 1918) internetda route qilinmaydi, public IPv4 manzillar esa yetishmaydi.

| Tur | Nimani o'zgartiradi | Hook | Ishlatilishi |
|-----|---------------------|------|--------------|
| SNAT | manba IP (va port) ni berilgan manzilga | `postrouting` | ichki tarmoq internetga bitta public IP orqali chiqadi |
| MASQUERADE | SNAT, lekin manzil chiqish interfeysining joriy IP'si | `postrouting` | interfeys IP'si dinamik bo'lganda (uy routeri, Docker, VM) |
| DNAT | manzil IP (va port) | `prerouting` | **port forwarding**: tashqi port ichki hostga |

### Mexanizm: conntrack yozuvi javobni qaytaradi

Ichki `192.168.50.10:51000` dan `1.1.1.1:443` ga paket chiqadi, router'ning tashqi manzili `203.0.113.5`:

1. Router `postrouting` da manbani `203.0.113.5:51000` ga almashtiradi (port band bo'lsa boshqasiga) va moslikni conntrack yozuviga qo'shadi.
2. Server javobni `203.0.113.5:51000` ga yuboradi: u ichki manzilni umuman ko'rmagan.
3. Router javobni `prerouting` da conntrack yozuvi bo'yicha taniydi va manzilni `192.168.50.10:51000` ga qaytarib yozadi. Javob uchun alohida qoida kerak emas.

NAT qoidalari faqat ulanishning birinchi paketida (`new`) tekshiriladi, qolganlari conntrack yozuvi bo'yicha tarjima qilinadi. Yozuvda tarjima ochiq ko'rinadi:

```
$ sudo conntrack -L -p tcp --dport 443
tcp      6 431990 ESTABLISHED src=192.168.50.10 dst=1.1.1.1 sport=51000 dport=443 src=1.1.1.1 dst=203.0.113.5 sport=443 dport=51000 [ASSURED] mark=0 use=1
```

Birinchi to'rtlik asl paket (ichki manba), ikkinchisi kutilayotgan javob: `dst=203.0.113.5`, ya'ni javob router manziliga keladi. Ikki to'rtlik bir-birining ko'zgusi bo'lmasa, o'rtada NAT bor. NAT'siz ulanishda (1-bo'limdagi SSH yozuvi) ular aynan ko'zgu edi.

Qoidalar (boshqa manzillar bilan misol: ichki tarmoq chiqishi va tashqi 2222-portni ichki hostning SSH'iga ulash):

```
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "<iface>" tcp dport 2222 dnat to 192.168.50.10:22
    }
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 192.168.50.0/24 oifname "<iface>" masquerade
    }
}
```

NAT ishlashi uchun uch shart birga: (1) `net.ipv4.ip_forward=1` (5-dars); (2) `forward` chain'i paketni o'tkazadi; (3) NAT qoidasi. Ko'rish: `sudo conntrack -L`, `sudo nft list table ip nat`.

**Tuzoq: DNAT'dan keyin filtr qaysi portni ko'radi.** `prerouting` `forward` dan oldin bajariladi (2-bo'lim, priority), demak `forward` dagi qoida allaqachon tarjima qilingan manzil va portni ko'radi, tashqi portni emas.

**Tuzoq: DNAT hostning o'zidan ishlamaydi.** `prerouting` faqat interfeysdan kelgan paketlarga taalluqli. Hostning o'z jarayoni yuborgan paket `output` dan chiqadi va `prerouting` dagi qoidaga tushmaydi; buning uchun `type nat hook output` chain'ida alohida qoida kerak.

### Real ishda qachon kerak

- Uy routeri, Docker bridge, Multipass VM'ingiz (host uni NAT qiladi), cloud **NAT gateway**: hammasi masquerade.
- Private subnet'dagi servisni tashqariga chiqarish: DNAT. Cloud load balancer va Kubernetes `Service` shu g'oyaning boshqariladigan shakli.
- Oqibatlar: server haqiqiy mijoz IP'sini ko'rmaydi (log'da router IP'si, shuning uchun L7 proxy `X-Forwarded-For` header'ini qo'shadi); tashqaridan ichkariga ulanish DNAT'siz boshlanmaydi; bitta public IP ortidagi bir vaqtdagi ulanishlar soni portlar soni bilan cheklangan (cloud'da "port exhaustion").

### Nima uchun shunday

NAT 1990-yillarda IPv4 manzillari tugashini kechiktirish uchun vaqtinchalik yechim sifatida paydo bo'ldi (RFC 1631, keyin RFC 3022) va doimiy bo'lib qoldi. U "har host har hostga to'g'ridan-to'g'ri yeta oladi" degan asl internet tamoyilini buzadi; muqobili IPv6, unda manzil yetarli va NAT kerak emas, filtrlashni faqat firewall bajaradi. Tarjima conntrack'ka tayangani uchun NAT doim stateful: router qayta yuklansa barcha ulanishlar uziladi.

## 6. Docker va firewall

### Bu nima va mexanizm

Docker 1 va 5-darslardagi bloklar (bridge, veth, forwarding) ustiga netfilter qoidalarini o'zi yozadi, `iptables` buyrug'i orqali:

- **Chiqish**: bridge subnet'idan chiqib, bridge'ga qaytmayotgan trafik uchun `POSTROUTING` da `MASQUERADE`.
- **`-p 8080:80`**: `nat` jadvalidagi `DOCKER` chain'ida `DNAT`: hostning 8080-portiga kelgan paket konteyner IP'sining 80-portiga. Paket keyin `forward` dan o'tadi, u yerda Docker'ning o'z ruxsat qoidalari bor.
- `DOCKER-USER`: `FORWARD` boshida chaqiriladigan, Docker tegmaydigan chain; foydalanuvchi cheklovlari shu yerga yoziladi.

**Tuzoq: Docker publish qilgan port ufw'ni chetlab o'tadi.** `ufw deny 8080` `input` ga yoziladi, publish qilingan portga kelgan paket esa DNAT'dan keyin `forward` ga ketadi. Natija: `ufw status` port yopiq deydi, internet esa konteynerga ulanadi. Yechimlar: faqat lokal kerak bo'lsa `-p 127.0.0.1:8080:80`; tashqi cheklovlar `DOCKER-USER` ga; yoki port publish qilinmaydi va oldida reverse proxy turadi.

Ikki mashina farqi: Zorin'da bu qoidalar host'ning o'z netfilter'ida (`sudo iptables -t nat -S` ko'rsatadi). macOS'da Docker Desktop'ning yashirin Linux VM'i ichida, host'dan ko'rinmaydi; publish qilingan port Mac'ga alohida proxy jarayoni orqali chiqariladi. Shuning uchun C guruh ikkala mashinada `lab` VM ichidagi Docker'da bajariladi, u yerda manzara Linux serverdagi bilan bir xil.

### Real ishda qachon kerak

- `-p 5432:5432` bilan ishga tushirilgan ma'lumotlar bazasi konteyneri butun internetga ochiq qolishi: eng ko'p uchraydigan xato. Tekshiruv doim tashqaridan (`nc -vz`), `ufw status` dan emas.
- Docker bor hostda firewall'ni qayta yuklash konteyner tarmog'ini uzishi (3-bo'lim, `flush ruleset`).

### Nima uchun shunday

Docker konteynerni "bitta buyruq bilan tarmoqqa chiqarish" uchun NAT va forward qoidalarini o'zi boshqarishi kerak, aks holda har `docker run` dan keyin qo'lda qoida yozilardi. Evaziga host firewall'i bilan ikki xo'jayin paydo bo'ladi. Batafsil docker modulida (tarmoq darsi); Kubernetes'da xuddi shu ishni `kube-proxy` bajaradi.

## 7. VPN va WireGuard

### Bu nima

**VPN (Virtual Private Network)** ishonchsiz tarmoq (internet) ustidagi shifrlangan tunnel: asl IP paket shifrlanib, boshqa paketning ichiga joylanadi (encapsulation, 2-dars) va qarshi tomonda ochiladi. Hostda bu virtual interfeys (`wg0`, `tun0`) va unga yo'naltirilgan route'lar ko'rinishida namoyon bo'ladi: VPN aslida routing va shifrlash.

| Topologiya | Kim ulanadi | Misol |
|------------|-------------|-------|
| Remote access | bitta qurilma tarmoqqa | xodim noutbuki ofis yoki VPC'ga |
| Site-to-site | tarmoq tarmoqqa, gateway'lar orasida | ofis va cloud VPC |

| Rejim | Route'lar | Oqibat |
|-------|-----------|--------|
| Full tunnel | default route tunnel'ga | butun trafik VPN orqali, VPN server NAT qiladi |
| Split tunnel | faqat ichki prefikslar tunnel'ga | internet trafik to'g'ridan-to'g'ri |

### Mexanizm: WireGuard

**WireGuard** kernel ichidagi VPN, UDP ustida ishlaydi. Sertifikat, login, "ulanish" tushunchasi yo'q: har tomonda kalit juftligi (SSH kalitlari kabi, 4-dars) va **peer** lar ro'yxati (qarshi tomonlarning public kalitlari).

```
umask 077                                        # new files readable by owner only
wg genkey | tee privatekey | wg pubkey > publickey
```

Bir tomonning `/etc/wireguard/wg0.conf` fayli (misol manzillar; fayl ruxsati 600, repo'ga hech qachon qo'shilmaydi):

```
[Interface]
Address = 10.99.0.1/24
ListenPort = 51820
PrivateKey = <own private key>

[Peer]
PublicKey = <peer public key>
AllowedIPs = 10.99.0.2/32
Endpoint = <peer address>:51820
PersistentKeepalive = 25
```

| Kalit | Ma'nosi |
|-------|---------|
| `Address` | tunnel ichidagi o'z manzili |
| `ListenPort` | UDP port (odatda 51820), firewall'da ochiq bo'lishi kerak |
| `PublicKey` | peer'ning identifikatori |
| `AllowedIPs` | ikki vazifa: chiqishda "shu manzillarga ketayotgan paketni shu peer'ga shifrlab yubor" (route), kirishda "shu peer'dan faqat shu manba manzilli paketni qabul qil" (filtr) |
| `Endpoint` | peer'ning haqiqiy manzili va porti. Bir tomonda bo'lsa yetadi: ikkinchisi uni kelgan paketdan o'rganadi |
| `PersistentKeepalive` | NAT ortidagi tomonda: har N soniyada paket yuborib NAT'dagi conntrack yozuvini tirik saqlaydi |

```
sudo wg-quick up wg0          # create interface, set keys, add address and routes
sudo wg-quick down wg0
ubuntu@net1:~$ sudo wg show
interface: wg0
  public key: <own public key>
  private key: (hidden)
  listening port: 51820

peer: <peer public key>
  endpoint: <peer address>:51820
  allowed ips: 10.99.0.2/32
  latest handshake: 12 seconds ago
  transfer: 1.24 KiB received, 1.18 KiB sent
  persistent keepalive: every 25 seconds
```

O'qish: `private key: (hidden)` kalit hech qachon chiqarilmaydi; `endpoint` paketlar hozir qayerga yuborilayotgani; `latest handshake` oxirgi muvaffaqiyatli kalit almashinuvi, bu qator yo'q bo'lsa tunnel hali bir marta ham ishlamagan; `transfer` hisoblagichlari: `sent` o'sib `received` nol bo'lsa paketlar ketyapti, javob kelmayapti.

Nozikliklar:

- **Jim protokol**: to'g'ri kalit bilan imzolanmagan paketga WireGuard javob bermaydi. Port skanerida ko'rinmaydi, lekin kalit xato bo'lsa xato xabari ham yo'q, faqat `latest handshake` paydo bo'lmaydi.
- Handshake faqat trafik bo'lganda bajariladi: ping yubormaguningizcha `latest handshake` yo'qligi normal.
- Site-to-site uchun `AllowedIPs` ga qarshi tomon ortidagi subnet qo'shiladi, gateway'larda `ip_forward=1` va `forward` qoidalari, ikkala saytdagi hostlarda qarshi subnet'ga qaytish yo'li kerak (5-dars).
- `AllowedIPs = 0.0.0.0/0` full tunnel: `wg-quick` buni alohida routing table va `ip rule` bilan amalga oshiradi (5-dars, policy routing).
- `wg0` MTU'si sukut bo'yicha 1420: tashqi IP, UDP va WireGuard header'lari uchun joy qoldiriladi (2-dars; aniq farqni 17-vazifada o'lchaysiz).

### OpenVPN va IPsec

| | WireGuard | OpenVPN | IPsec (IKEv2) |
|---|-----------|---------|---------------|
| Qayerda ishlaydi | kernel | user space | kernel + IKE daemon (strongSwan) |
| Transport | UDP | UDP (odatda 1194) yoki TCP | UDP 500 va 4500, ESP |
| Autentifikatsiya | statik kalit juftliklari | TLS sertifikatlari, ixtiyoriy login | pre-shared key yoki sertifikatlar |
| Qayerda uchraydi | yangi o'rnatmalar, Tailscale kabi mesh VPN'lar asosi | eski korporativ remote access | cloud site-to-site VPN, tarmoq uskunalari |

**Tuzoq: tunnel ko'tarildi, ichki tarmoq ko'rinmaydi.** Handshake bor, tunnel manzillari ping bo'ladi, ortidagi subnet yo'q. Deyarli doim uchtadan biri: `AllowedIPs` da subnet yo'q; gateway'da forwarding yoki `forward` qoidasi yo'q; narigi saytdagi hostlar javobni tunnel'ga emas, o'z default gateway'iga yuboryapti.

### Real ishda qachon kerak

- Admin servislarni (ma'lumotlar bazasi, monitoring paneli) internetga ochmasdan, faqat VPN interfeysidan yetib bo'ladigan qilish.
- O'zingiz qursangiz WireGuard; cloud VPC'ni ofis uskunasiga ulasangiz IPsec, chunki cloud VPN gateway'lar shuni taklif qiladi (cloud moduli).

### Nima uchun shunday

IPsec va OpenVPN o'nlab shifr va rejim tanlovini beradi, noto'g'ri sozlash oson. WireGuard (2015, Linux 5.6 dan kernel tarkibida) ataylab tanlovsiz: bitta shifrlar to'plami, kichik kod bazasi, holat faqat kalitlar va `AllowedIPs`. "Ulanish" yo'qligi tufayli mijoz IP'si o'zgarsa (Wi-Fi'dan mobil tarmoqqa) tunnel uzilmaydi. Evazi: foydalanuvchilarni boshqarish, kalit tarqatish va dinamik manzil berish protokolda yo'q, ularni ustidagi asboblar bajaradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Firewall | paketni header maydonlari bo'yicha qoidalar bilan solishtirib o'tkazadigan yoki tashlaydigan mexanizm |
| Stateful / stateless | ulanish holatini eslaydigan / har paketga alohida qaraydigan filtr |
| conntrack | kernel'dagi ulanishlarni kuzatuvchi jadval, holatlari `new`, `established`, `related`, `invalid` |
| netfilter | kernel'dagi paket yo'liga hook'lar beradigan framework |
| Hook | paket yo'lidagi nuqta: `prerouting`, `input`, `forward`, `output`, `postrouting` |
| Priority | bitta hook'dagi chain'lar tartibini belgilaydigan son |
| nftables / `nft` | netfilter'ni boshqaradigan zamonaviy tizim va uning buyrug'i |
| Table, chain, rule | qoidalar konteyneri, hook'ka ilingan qoidalar ro'yxati, shartlar va hukm |
| Policy | hech bir qoida mos kelmaganda base chain qo'llaydigan hukm |
| Set | qoidada ishlatiladigan qiymatlar to'plami |
| Handle | qoidaning raqami, o'chirishda ishlatiladi |
| Default deny | hamma narsa taqiqlangan, kerakligi birma-bir ochiladigan siyosat |
| drop / reject | paketni jim tashlash / rad javobi bilan tashlash |
| ufw, firewalld | Ubuntu va RHEL oilasidagi firewall frontend'lari |
| NAT | paket header'idagi manzil yoki portni yo'lda qayta yozish |
| SNAT / MASQUERADE | manba manzilni almashtirish: berilgan manzilga / chiqish interfeysi manziliga |
| DNAT / port forwarding | manzil IP va portni almashtirish, tashqi portni ichki hostga ulash |
| VPN | ishonchsiz tarmoq ustidagi shifrlangan tunnel |
| Tunnel interfeysi | paketlarni shifrlab boshqa paket ichida yuboradigan virtual interfeys (`wg0`) |
| Peer | WireGuard'da qarshi tomon, public kaliti bilan aniqlanadi |
| AllowedIPs | peer uchun route ham, manba filtri ham bo'lgan prefikslar ro'yxati |
| Site-to-site / remote access | tarmoqni tarmoqqa / bitta qurilmani tarmoqqa ulaydigan VPN |
| Full / split tunnel | butun trafik / faqat ichki prefikslar VPN orqali |
| Security group | cloud'dagi stateful, instans darajasidagi firewall |

## Tuzoqlar

- SSH ruxsatisiz default-drop qo'llash. Avval ruxsat, keyin siyosat, zaxira sessiya va avtomatik qaytarish.
- `established,related` qoidasi yo'q yoki oxirida: chiquvchi ulanishlarning javoblari (DNS, `apt`) tashlanadi.
- Faqat IPv4 qoidalari (`ip` oilasi): servis IPv6 orqali ochiq qoladi. `inet` ikkalasini qamraydi.
- Barcha ICMP'ni taqiqlash: PMTUD va tashxis buziladi.
- Qoidani `nft add` bilan qo'shib faylga saqlamaslik: reboot'dan keyin yo'q. Laboratoriyada esa aksincha, doimiy qilingan xato qoida restart bilan ketmaydi.
- Docker publish qilgan port `ufw` ni chetlab o'tadi; Docker bor hostda `flush ruleset`.
- Bir hostda `ufw`, qo'lda `nft` va `iptables` ni aralashtirish.
- NAT sozlab `ip_forward` yoki `forward` ruxsatini unutish; DNAT'dan keyingi filtrda tashqi portni yozish.
- NAT ortidagi serverda log'dagi mijoz IP'siga qarab rate limit yoki ban qo'yish: hamma mijoz bitta IP.
- WireGuard private kalitini repo'ga qo'shish yoki `wg0.conf` ni 600 dan keng ruxsat bilan qoldirish.
- VPN subnet'i mijozning uy tarmog'i yoki Docker diapazoni bilan kesishishi (3-dars).
- Firewall buyruqlarini Zorin host'ida yoki macOS'da sinash: faqat VM'da.

## Manbalar

- https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes – nftables qisqa ma'lumotnoma
- https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks – hook'lar va prioritetlar sxemasi
- https://www.netfilter.org/projects/nftables/manpage.html – `nft` man sahifasi
- https://man7.org/linux/man-pages/man8/iptables.8.html – `iptables(8)`
- https://documentation.ubuntu.com/server/how-to/security/firewalls/ – Ubuntu Server: ufw
- https://firewalld.org/documentation/ – firewalld
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker va iptables, `DOCKER-USER`
- https://www.wireguard.com/quickstart/ va https://www.wireguard.com/#cryptokey-routing – WireGuard, `AllowedIPs`
- https://man7.org/linux/man-pages/man8/wg.8.html va https://man7.org/linux/man-pages/man8/wg-quick.8.html – `wg`, `wg-quick`
- https://openvpn.net/community-resources/how-to/ va https://docs.strongswan.org/ – OpenVPN, IPsec
- https://www.rfc-editor.org/rfc/rfc3022 – an'anaviy NAT
- https://documentation.ubuntu.com/multipass/ – Multipass (`net1`, `net2`)

## Birga bajaramiz

Vazifalar kiruvchi trafikni filtrlaydi. Bu yerda teskarisini qilamiz: `net1` ning o'zi chiqaradigan TCP ulanishlarni cheklaymiz (egress filtri, `output` hook'i). SSH sessiyangiz kiruvchi ulanish, shuning uchun qulflanish xavfi yo'q, lekin tartibni baribir to'liq bajaramiz.

1. `net2` da nishon server, `net1` dan tekshiruv:

```
ubuntu@net2:~$ python3 -m http.server 8080
ubuntu@net1:~$ nc -vz -w 3 <net2 IP> 8080
Connection to <net2 IP> 8080 port [tcp/http-alt] succeeded!
```

2. `net1` da `egress.nft` faylini yozing:

```
table inet egress {
    set allowed_tcp {
        type inet_service
        elements = { 80, 443 }
    }
    chain output {
        type filter hook output priority filter; policy accept;
        ct state established,related accept
        oif "lo" accept
        tcp dport @allowed_tcp counter accept
        meta l4proto tcp counter log prefix "egress-block: " reject with tcp reset
    }
}
```

`policy accept` qoladi: faqat TCP cheklanadi, UDP (DNS) va ICMP o'tadi. `established,related` SSH sessiyangizning javob paketlarini o'tkazadi: ular `output` dan chiqadi, lekin ulanishni host boshlagan.

3. Tekshirish, sug'urta, yuklash:

```
ubuntu@net1:~$ sudo nft -c -f egress.nft
ubuntu@net1:~$ sudo sh -c 'sleep 120; nft delete table inet egress' &
ubuntu@net1:~$ sudo nft -f egress.nft
ubuntu@net1:~$ nc -vz -w 3 <net2 IP> 8080
nc: connect to <net2 IP> port 8080 (tcp) failed: Connection refused
```

`nft -c` jim o'tdi: sintaksis to'g'ri. `Connection refused` darhol keldi: `reject with tcp reset` jarayonga RST qaytardi. `net2` da `sudo tcpdump -nn tcp port 8080` hech narsa ko'rsatmaydi: SYN `net1` dan chiqmagan. Sessiya tirik ekaniga ishongach `sudo pkill sleep`.

4. Qaysi qoida ishladi:

```
ubuntu@net1:~$ sudo nft list chain inet egress output | grep counter
		tcp dport @allowed_tcp counter packets 0 bytes 0 accept
		meta l4proto tcp counter packets 1 bytes 60 log prefix "egress-block: " reject with tcp reset
ubuntu@net1:~$ sudo journalctl -k -n 1 --no-pager
<sana> net1 kernel: egress-block: IN= OUT=<iface> SRC=<net1 IP> DST=<net2 IP> LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=<N> DF PROTO=TCP SPT=<port> DPT=8080 WINDOW=<N> RES=0x00 SYN URGP=0
```

Bitta paket (60 baytli SYN) oxirgi qoidaga tushdi. Log'da `IN=` bo'sh, `OUT=<iface>`: paket shu hostda yaratilgan va chiqayotgan edi (`output` hook'i); `SYN` yangi ulanishning birinchi paketi; `DPT=8080` set'da yo'q port.

5. Qoidalarga tegmasdan set'ni o'zgartirish:

```
ubuntu@net1:~$ sudo nft add element inet egress allowed_tcp '{ 8080 }'
ubuntu@net1:~$ nc -vz -w 3 <net2 IP> 8080
Connection to <net2 IP> 8080 port [tcp/http-alt] succeeded!
ubuntu@net1:~$ sudo conntrack -L -p tcp --dport 22 2>/dev/null | wc -l
1
```

Port set'ga qo'shildi, chain qayta yuklanmadi. Oxirgi buyruq: jadval `ct state` ishlatgani uchun conntrack yoqilgan va SSH sessiyangiz unda bitta yozuv.

6. Tozalash: `sudo nft delete table inet egress`, `sudo nft list ruleset` bo'sh; `net2` da serverni `Ctrl+C` bilan to'xtating.

Ko'rganingiz: `output` hook'i faqat hostning o'z paketlarini ushlaydi (2-bo'lim); conntrack holati tufayli mavjud sessiya uzilmadi (1-bo'lim); table, chain, set, `counter`, `log`, atomik yuklash va tekshiruv tartibi (3-bo'lim); `reject` mijozda `Connection refused` bo'lib ko'rinadi (1-bo'lim).

---

## Vazifalar

Ish papkasi: `network/06-firewall-nat-vpn/` (`make new m=network n=06 name=firewall-nat-vpn`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`.nft`, `.sh`, `wg0.conf.example`) shu papkaga saqlang. WireGuard private kalitlari papkaga ko'chirilmaydi. A, B, D, E guruhlar `net1` va `net2` VM'larida, C guruh `lab` VM ichidagi Docker'da bajariladi (Zorin'da ixtiyoriy ravishda host'da ham, faqat o'qiydigan buyruqlar bilan). Host'ning o'z firewall'iga (Zorin'da netfilter, macOS'da `pf`) tegilmaydi. Har javobda qaysi VM'da bajarilgani ko'rinsin. Default-drop yuklashdan oldin "Qulflanib qolish xavfi va qaytish yo'li" qoidalariga amal qiling.

### A. Firewall asoslari (VM)

1. **Baseline.** `net1` da `sudo nft list ruleset`, `sudo iptables -S`, `sudo ufw status verbose` va `iptables -V` chiqishini yozing. Toza Ubuntu 24.04 da firewall holati qanday? `ss -tlnp` bo'yicha hozir tarmoqdan qaysi portlar yetib bo'ladi? Yo'nalish: 4-bo'lim, asboblar jadvali.

2. **First ruleset.** `net1` da `python3 -m http.server 8000` va `nc -lk 9000` ni ishga tushiring. `host.nft` faylini yozing: `inet` jadval, `input` default drop, `established,related`, loopback, ICMP, SSH va 8000-portga ruxsat. `nft -c -f` bilan tekshirib, yuklang. `net2` dan 22, 8000 va 9000-portlarni `nc -vz -w 3` bilan sinab, natijalarni jadvalga yozing. Yo'nalish: 3-bo'lim, "Mexanizm: qoidalar qanday o'qiladi" va Laboratoriya, "Qulflanib qolish xavfi va qaytish yo'li".

3. **Drop vs reject.** 9000-port uchun avval `drop`, keyin `reject` qoidasini qo'llang. Har holatda `net2` dagi `nc` xato matni, javob vaqti va `net1` dagi `tcpdump -nn tcp port 9000` chiqishini solishtiring. Qaysi holatda `SYN` takrorlanadi? Yo'nalish: 1-bo'lim, "Default deny, drop va reject".

4. **Why established matters.** `ct state established,related accept` qatorini olib tashlab qoidalarni qayta yuklang (SSH qoidasi qolsin, sessiyani yopmang). `net1` dan `curl -m 5 https://example.com` va `dig example.com` natijalarini yozing. Chiquvchi so'rov ketdi, javob nima uchun kelmadi? `tcpdump` bilan tasdiqlang va qatorni qaytaring. Yo'nalish: 1-bo'lim, "Mexanizm: conntrack".

5. **Rule order and counters.** `tcp dport 8000 drop` qoidasini avval mavjud `accept` dan keyin, so'ng undan oldin qo'ying (`insert` yoki handle bilan). Har holatda natijani va `counter` qiymatlarini (`nft list chain`) yozing. Qoidani handle bo'yicha o'chiring. Yo'nalish: 3-bo'lim, "Buyruqlar".

6. **Source restriction and logging.** 8000-portni faqat `net2` IP'sidan ochiq qiling va tashlangan paketlarni `log prefix` bilan log qiling. Host'dan (`nc -vz -w 3 <net1 IP> 8000`, Zorin'da ham, macOS'da ham ishlaydi) va `net2` dan sinab ko'ring. `sudo journalctl -k -n 20` dagi log qatoridan `IN=`, `SRC=`, `DPT=` maydonlarini izohlang. Yo'nalish: 3-bo'lim, "Buyruqlar" va "Birga bajaramiz" ning 4-qadami.

7. **IPv6 gap.** `host.nft` ni `inet` o'rniga `ip` oilasiga o'zgartirib yuklang. `net1` ning IPv6 manzili bo'lsa (link-local ham yetadi) `net2` dan `nc -6 -vz <fe80 manzil>%<iface> 9000` bilan sinang. Natija nimani ko'rsatadi? `inet` ga qaytaring. Yo'nalish: 3-bo'lim, table oilalari (`ip`, `ip6`, `inet`).

8. **ufw.** `net2` da xuddi 2-vazifadagi siyosatni `ufw` bilan quring (22 ochiq, 8000 faqat `net1` dan, qolgani yopiq). `ufw status numbered` va `sudo nft list ruleset | head -60` (yoki `iptables -S`) chiqishini solishtiring: ufw nechta zanjir yaratdi? Bitta qoidani raqami bo'yicha o'chiring. Xuddi shu siyosat `firewall-cmd` buyruqlari bilan qanday yozilishini (bajarmasdan) README'ga yozing. Oxirida `sudo ufw disable`. Yo'nalish: 4-bo'lim, "ufw" va "firewalld".

### B. NAT (VM)

9. **Namespace behind NAT.** `net1` da `app` namespace'ini yarating, veth bilan VM'ning asosiy namespace'iga ulang (`10.0.1.1/24` VM tomonda, `10.0.1.2/24` `app` da, default route `10.0.1.1`). `app` dan `ping 1.1.1.1` qiling va VM'ning tashqi interfeysida `tcpdump -n icmp` bilan kuzating: paket chiqdimi, manba IP'si qanday, javob nima uchun kelmaydi? Yo'nalish: 5-dars (namespace, veth) va 5-bo'lim, "Bu nima".

10. **Masquerade.** `ip_forward` ni yoqing va `nat.nft` da `postrouting` masquerade qoidasini yozing. 9-vazifadagi tcpdump'ni takrorlang: manba IP endi nima? `sudo conntrack -L -p icmp` va TCP ulanish uchun (`app` dan `curl`) `conntrack -L -p tcp` yozuvidagi ikki yo'nalish manzillarini izohlang. `forward` zanjiringiz default drop bo'lsa, qanday qoida qo'shish kerak bo'ldi? Yo'nalish: 5-bo'lim, "Mexanizm: conntrack yozuvi javobni qaytaradi".

11. **Port forwarding.** `app` namespace'ida `python3 -m http.server 80` ni ishga tushiring. `nat.nft` ga DNAT qo'shing: VM'ning 8080-porti `10.0.1.2:80` ga. `net2` dan `curl http://<net1 IP>:8080/` ishlashini ko'rsating. `app` ichidagi server log'ida mijoz IP'si kim? `forward` zanjirida qaysi manzil va portga ruxsat berdingiz va nima uchun 8080 emas? Yo'nalish: 5-bo'lim, "Tuzoq: DNAT'dan keyin filtr qaysi portni ko'radi".

12. **DNAT from the host itself.** `net1` ning o'zidan `curl -m 3 http://localhost:8080/` va `curl -m 3 http://<net1 IP>:8080/` ni sinang. Natijani netfilter hook'lari bilan tushuntiring. `output` hook'ida qoida qo'shib kamida ikkinchi variantni ishlating. Yo'nalish: 5-bo'lim, "Tuzoq: DNAT hostning o'zidan ishlamaydi" va 2-bo'lim, "Mexanizm: uch xil yo'l".

13. **Missing pieces.** Ishlab turgan NAT'dan navbat bilan bittadan olib tashlang va har safar alomatni yozing (xato matni, tcpdump'da paket qayergacha yetdi): (a) `ip_forward=0`; (b) `forward` ruxsati; (c) masquerade qoidasi (DNAT qolgan holda `net2` dan so'rov: javob qaytadimi, nima uchun?). Yo'nalish: 5-bo'lim, NAT ishlashi uchun uch shart.

### C. Docker (ish mashinasi, faqat o'qish va konteynerlar)

14. **Docker NAT rules.** `lab` VM ichida `docker run -d --name web -p 8080:80 nginx:alpine` ni ishga tushiring (macOS host'ida bu qoidalar ko'rinmaydi, 6-bo'lim; keyingi buyruqlar ham `lab` ichida). `sudo iptables -t nat -S` chiqishidan konteyner tarmog'i uchun `MASQUERADE` va 8080-port uchun `DNAT` qatorlarini toping va har flag'ini izohlang. `sudo iptables -S FORWARD` va `DOCKER-USER` zanjirini ko'ring. Bularni 10 va 11-vazifalarda o'zingiz yozgan qoidalar bilan yonma-yon qo'ying. Yo'nalish: 6-bo'lim va 4-bo'lim, "iptables'ni o'qish".

15. **Published port exposure.** `ss -tlnp | grep 8080` chiqishida kim va qaysi manzilda tinglayapti? Host'dan `curl -m 3 http://<lab IP>:8080/` ochiladimi (`lab` uchun host tarmoqdagi boshqa qurilma; Zorin host'ida bajarayotgan bo'lsangiz LAN'dagi boshqa qurilmadan sinang)? Konteynerni `-p 127.0.0.1:8080:80` bilan qayta yarating va farqni `ss` hamda `iptables -t nat -S` da ko'rsating. Nima uchun `ufw deny 8080` birinchi holatda yordam bermasligini hook'lar bilan tushuntiring (bajarmasdan). Konteynerni o'chiring. Yo'nalish: 6-bo'lim, "Tuzoq: Docker publish qilgan port ufw'ni chetlab o'tadi".

### D. WireGuard (VM)

16. **Tunnel between two hosts.** `net1` (`10.8.0.1/24`) va `net2` (`10.8.0.2/24`) orasida WireGuard tunnel quring: kalitlar, `/etc/wireguard/wg0.conf`, `wg-quick up`. Tunnel manzillari orasida ping o'tishini, `sudo wg show` dagi `latest handshake` va `transfer` ni ko'rsating. `ip addr show wg0`, `ip route` da nima paydo bo'ldi, MTU nechchi? Private kalitsiz nusxani `wg0.conf.example` ga saqlang. Yo'nalish: 7-bo'lim, "Mexanizm: WireGuard".

17. **What is on the wire.** `net1` da ikki tcpdump: biri `-i wg0`, ikkinchisi tashqi interfeysda `udp port 51820`. `net2` dan tunnel orqali `curl http://10.8.0.1:8000/` qiling. Har interfeysda nima ko'rinadi (protokol, manzillar, o'qiladigan mazmun)? Tashqi paket hajmi ichki paketdan necha bayt katta va bu MTU 1420 ni qanday tushuntiradi? Yo'nalish: 7-bo'lim, "Nozikliklar" (MTU) va 2-dars (encapsulation).

18. **Break the tunnel.** Uch nosozlikni navbat bilan yarating va har birida `wg show`, `ping` xatosi va tcpdump kuzatuvini yozing: (a) bir tomonda peer'ning public kaliti noto'g'ri; (b) `net1` firewall'ida UDP 51820 yopiq; (c) `net2` dagi `AllowedIPs` da `10.8.0.1` yo'q (boshqa manzil yozilgan). Qaysi holatda xato xabari umuman yo'q va tashxisni qanday qildingiz? Yo'nalish: 7-bo'lim, "Nozikliklar" va `wg show` chiqishini o'qish.

19. **Firewall on the tunnel.** `net1` da 9000-portni faqat `wg0` interfeysidan ochiq qiling (`iifname`). `net2` dan `10.8.0.1:9000` va `<net1 tashqi IP>:9000` ga ulanishni solishtiring. Bu naqsh real hayotda qaysi servislar uchun ishlatiladi? Yo'nalish: 3-bo'lim (`iifname`) va 7-bo'lim, "Real ishda qachon kerak".

20. **Site-to-site.** Tunnel'ni kengaytiring: `net2` `net1` ortidagi `app` namespace'iga (`10.0.1.2`) tunnel orqali yetsin. Qaysi tomonda `AllowedIPs` ni o'zgartirish, qayerda forwarding va `forward` qoidasi, qayerda route kerakligini avval yozing, keyin bajaring. `net2` dan `curl http://10.0.1.2/` ishlashini va `app` server log'ida ko'ringan mijoz IP'sini ko'rsating. Bu yerda NAT kerak bo'ldimi, nima uchun? Yo'nalish: 7-bo'lim, site-to-site haqidagi noziklik va "Tuzoq: tunnel ko'tarildi, ichki tarmoq ko'rinmaydi".

### E. Modul mini-loyihasi

21. **Secure gateway.** Hammasini bitta takrorlanadigan o'rnatmaga yig'ing. `net1` gateway, uning ortida `app` namespace'i (80-portda "public" web, 9000-portda "admin" servis); `net2` masofadagi administrator. Yo'nalish: butun dars, ayniqsa 2, 5 va 7-bo'limlar. Talablar:
    - `net1` da `input` va `forward` default drop, qoidalar bitta `gateway.nft` faylida, `flush ruleset` bilan atomik yuklanadi.
    - Tashqaridan faqat: SSH, UDP 51820, va 8080-port (DNAT orqali `app:80`).
    - `app` internetga masquerade orqali chiqadi.
    - `app:9000` ga faqat WireGuard tunnel orqali `net2` dan yetib bo'ladi; tashqi interfeysdan hech qanday yo'l bilan emas.
    - `gateway.sh up|down|status`: namespace, veth, sysctl, nftables va WireGuard'ni ko'taradi va tozalaydi; idempotent; `shellcheck` toza.
    - `verify.sh` (`net2` da ishlaydi): kamida 8 ta tekshiruv (ruxsat etilgan va taqiqlangan yo'llar) bajarib, har biri uchun kutilgan va haqiqiy natijani jadval qilib chiqaradi, biror nomuvofiqlikda nol bo'lmagan exit code qaytaradi.
    - README'da: topologiya sxemasi (ASCII), manzil jadvali, bitta tashqi so'rov (`net2` dan `net1:8080`) va bitta tunnel so'rovi (`net2` dan `app:9000`) uchun paketning hook'lar bo'ylab to'liq yo'li (qaysi hook'da qaysi qoida ishladi, manzillar qayerda o'zgardi).

22. **Module retrospective.** "`net2` dan `http://<net1 IP>:8080/` ochilmayapti" shikoyati uchun modulning barcha olti darsiga tayangan tashxis runbook'ini yozing: link va ARP, IP va mask, route va qaytish yo'li, DNS (agar nom ishlatilsa), TCP port va holat, firewall hook'lari, NAT va conntrack, ilova. Har qadam: qaysi hostda qaysi buyruq, nimani isbotlaydi. Mini-loyihangizda kamida ikki nosozlikni ataylab yaratib, runbook bo'yicha topilishini ko'rsating. Yo'nalish: butun modul, 1–6 darslar.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa; `host.nft`, `nat.nft`, `gateway.nft`, `gateway.sh`, `verify.sh`, `wg0.conf.example` papkada.
2. `make check` toza (`shellcheck`, `make secrets`): papkada WireGuard private kaliti ham, haqiqiy `wg0.conf` ham yo'q (faqat `wg0.conf.example`).
3. `verify.sh` toza VM'larda `gateway.sh up` dan keyin to'liq o'tadi, `gateway.sh down` dan keyin `nft list ruleset`, `ip netns list`, `wg show` bo'sh.
4. `lab` da Docker `web` konteyneri o'chirilgan; host'ning (Zorin yoki macOS) firewall qoidalariga tegilmagan; `net1`, `net2` da hech bir qoida doimiy qilinmagan.
5. Modul tugagach VM'lar o'chiriladi: `multipass delete net1 net2 && multipass purge`, `multipass list` bo'sh.
6. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Stateful firewall stateless'dan nimasi bilan farq qiladi? `established,related` qoidasi bo'lmasa nima buziladi?
- Hostdagi servisga va host ortidagi konteynerga ketayotgan paket qaysi hook'lardan o'tadi?
- `drop` va `reject` mijoz tomonida qanday ko'rinadi, qaysi biri qayerda afzal?
- MASQUERADE qilingan ulanishning javob paketi ichki hostga qanday qaytadi? Buning uchun alohida qoida kerakmi?
- DNAT'dan keyin `forward` zanjiri qaysi manzil va portni ko'radi va nima uchun?
- Docker publish qilgan port nima uchun `ufw` qoidalarini chetlab o'tadi va uch yechim qaysilar?
- `AllowedIPs` ning ikki vazifasi nima? Site-to-site uchun unga nima qo'shiladi?
- WireGuard'da kalit noto'g'ri bo'lsa qanday xato ko'rasiz va muammoni qanday topasiz?
- Site-to-site va remote access, full tunnel va split tunnel farqlari nima?
- NAT ortidagi server mijoz IP'sini nima uchun ko'rmaydi va bu qayerda muammo tug'diradi?
