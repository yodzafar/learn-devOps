# 6-dars: Firewall, NAT, VPN

Maqsad: paket yo'lida turadigan uch mexanizmni Linux misolida egallash. Firewall: stateful filtrlash, kernel'dagi netfilter va uning ustidagi asboblar (nftables, iptables, ufw, firewalld). NAT: manba manzilni almashtirish (SNAT, MASQUERADE) va manzilni almashtirish (DNAT, port forwarding), Docker bularni qanday ishlatishi. VPN: ikki host orasida WireGuard tunnel, OpenVPN va IPsec sharhi, site-to-site va remote access farqi. 5-darsda Linux router paketni o'zgartirmasdan uzatar edi; bu darsda router paketni tashlaydi, qayta yozadi va shifrlaydi. Uchala mavzu bitta kernel quyi tizimiga (netfilter va conntrack) va routing'ga tayanadi. Cloud'dagi security group, NAT gateway va site-to-site VPN, Kubernetes'dagi Service va NetworkPolicy shu mexanizmlarning boshqariladigan ko'rinishi. Dars modul mini-loyihasi bilan tugaydi.

Taxminiy vaqt: 5 kun (siz uchun). 1-kun netfilter modeli va nftables. 2-kun ufw, firewalld sharhi, Docker bilan o'zaro ta'sir. 3-kun NAT. 4-kun WireGuard. 5-kun mini-loyiha. Diqqatni quyidagilarga qarating: paket qaysi hook'lardan o'tadi (input va forward farqi), conntrack holatlari, qoida tartibi, NAT'da javob paketi qanday qaytishi, WireGuard'dagi `AllowedIPs` ning ikki vazifasi.

## Laboratoriya

- **Ish mashinasi**: faqat o'qish (`sudo nft list ruleset`, `sudo iptables -S`, `sudo iptables -t nat -S`) va Docker konteynerlari. Ish mashinasida `ufw enable`, `nft -f`, `iptables -A`, WireGuard o'rnatish bajarilmaydi.
- **Multipass VM** `net1` va `net2`: barcha firewall, NAT va WireGuard vazifalari.

```
multipass start net1 net2
multipass exec net1 -- sudo apt update
multipass exec net1 -- sudo apt install -y nftables conntrack wireguard tcpdump
multipass exec net2 -- sudo apt update
multipass exec net2 -- sudo apt install -y nftables conntrack wireguard tcpdump
```

WireGuard o'rnatish bo'yicha rasmiy sahifa: https://www.wireguard.com/install/.

**Muhim**: `multipass shell` VM'ga SSH (TCP 22) orqali kiradi. Firewall'ni default-drop qilishdan oldin 22-portga ruxsat bering va ochiq sessiyani yopmang. Qulflanib qolsangiz: `multipass restart net1` (faylga saqlanmagan qoidalar yo'qoladi) yoki VM'ni o'chirib qayta yarating.

- **Tozalash** (modul oxiri): `multipass delete net1 net2 && multipass purge`, Docker konteynerlarini `docker rm -f`.

---

## 1. Firewall tushunchalari

Firewall paketni header maydonlari (interfeys, manba va manzil IP, protokol, port, ulanish holati) bo'yicha qoidalar bilan solishtirib, o'tkazadi yoki tashlaydi.

| Tur | Nimaga qaraydi | Kamchilik yoki afzallik |
|-----|----------------|-------------------------|
| Stateless | har paket alohida | javob paketlari uchun teskari qoida kerak (yuqori portlarni ochish), xatoga moyil |
| Stateful | paket qaysi ulanishga tegishli | "ichkaridan boshlangan ulanishning javoblari o'tadi" degan bitta qoida yetadi |

Linux firewall stateful: kernel'dagi **conntrack** har ulanishni (TCP, UDP "oqimi", ICMP) jadvalda kuzatadi va har paketga holat beradi:

| Holat | Ma'nosi |
|-------|---------|
| `new` | yangi ulanishning birinchi paketi (TCP SYN) |
| `established` | ikkala yo'nalishda paket ko'rilgan ulanishga tegishli |
| `related` | mavjud ulanish bilan bog'liq (masalan unga tegishli ICMP xato xabari) |
| `invalid` | hech qaysi ulanishga to'g'ri kelmaydi |

Standart tuzilma: **default deny**. Kiruvchi hamma narsa taqiqlangan, `established,related` ga ruxsat, keyin kerakli portlar birma-bir ochiladi. Chiquvchi trafik odatda ochiq qoldiriladi.

**drop va reject**: `drop` paketni jim tashlaydi (mijoz timeout'gacha kutadi), `reject` rad javobini qaytaradi (TCP uchun RST, mijoz darhol `Connection refused` oladi). Internetga qaragan interfeysda odatda `drop`, ichki tarmoqda `reject` tashxisni osonlashtiradi.

Cloud'dagi mos tushunchalar: **security group** stateful va faqat ruxsat qoidalaridan iborat (instans darajasida); AWS **network ACL** stateless (subnet darajasida), javob trafigi uchun alohida qoida talab qiladi.

## 2. netfilter: paket yo'li

**netfilter** kernel'dagi framework: paket yo'lida beshta **hook** bor, qoidalar shu nuqtalarga ilinadi.

```
                 +--> input --> [local process] --> output --+
                 |                                           v
NIC --> prerouting --> (routing decision) --> forward --> postrouting --> NIC
```

| Hook | Qaysi paketlar | Tipik ish |
|------|----------------|-----------|
| `prerouting` | kelgan hamma paket, routing qaroridan oldin | DNAT |
| `input` | shu hostning o'ziga mo'ljallangan | hostdagi servislarni himoyalash |
| `forward` | host orqali boshqa joyga o'tayotgan (router, konteynerlar) | tarmoqlar orasida filtrlash |
| `output` | hostning o'zi yaratgan | chiquvchi trafikni cheklash |
| `postrouting` | chiqayotgan hamma paket | SNAT, MASQUERADE |

**Tuzoq: `input` va `forward` ni aralashtirish.** Konteyner yoki router ortidagi hostga ketayotgan paket `input` dan **o'tmaydi**, u `forward` dan o'tadi. `input` zanjirida portni yopish hostning o'z servislarini himoyalaydi, konteynerlarni emas. Docker va ufw o'rtasidagi mashhur muammoning ildizi shu (4-bo'lim).

Asboblar ierarxiyasi:

| Asbob | Nima |
|-------|------|
| netfilter, conntrack | kernel mexanizmi |
| `nft` (nftables) | zamonaviy boshqaruv asbobi va qoida formati |
| `iptables` | eski asbob. Ubuntu 24.04 da `iptables-nft`: buyruq sintaksisi eski, qoidalar nftables ichiga yoziladi (`iptables -V` chiqishida `(nf_tables)`) |
| `ufw` | Ubuntu'dagi sodda frontend |
| `firewalld` | RHEL oilasidagi (Fedora, Rocky, Alma) zonalarga asoslangan frontend |

Bir hostda bitta frontend ishlating. `ufw`, qo'lda `nft` va Docker qoidalari aralashsa natijani faqat `sudo nft list ruleset` to'liq ko'rsatadi.

## 3. nftables

Tuzilma: **table** (konteyner, oilasi bilan: `ip`, `ip6`, `inet` ikkalasi uchun), ichida **chain** (hook'ka ilingan qoidalar ro'yxati), ichida **rule**. Minimal host firewall:

```
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif "lo" accept
        meta l4proto { icmp, ipv6-icmp } accept
        tcp dport 22 accept
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
}
```

O'qish qoidalari:

- Qoidalar yuqoridan pastga tekshiriladi, birinchi mos kelgan hukm (`accept`, `drop`, `reject`) paket taqdirini shu zanjirda hal qiladi. Hech biri mos kelmasa `policy` ishlaydi.
- `ct state established,related accept` birinchi turadi: trafikning asosiy qismi shu qatorda hal bo'ladi va chiquvchi ulanishlarning javoblari o'tadi.
- `iif "lo" accept`: lokal servislar o'zaro `127.0.0.1` orqali gaplashadi, uni yopish ko'p narsani buzadi.
- ICMP to'liq yopilmaydi (2-dars: PMTUD). IPv6 da ICMPv6 siz tarmoq umuman ishlamaydi (NDP).

```
sudo nft list ruleset                         # everything, all tables
sudo nft -c -f fw.nft                         # check syntax only
sudo nft -f fw.nft                            # load atomically
sudo nft add rule inet filter input tcp dport 443 counter accept
sudo nft -a list chain inet filter input      # show rule handles
sudo nft delete rule inet filter input handle 9
```

Foydali ifodalar: `ip saddr 10.0.0.0/8 tcp dport 5432 accept` (manba bo'yicha), `tcp dport { 80, 443 } accept` (to'plam), `iifname "wg0" accept` (interfeys bo'yicha), `counter` (hisoblagich), `log prefix "fw-drop: "` (kernel log'iga, `journalctl -k` da ko'rinadi), `reject` (rad javobi bilan).

Doimiylik: Ubuntu'da `/etc/nftables.conf` va `sudo systemctl enable --now nftables`. `nft add rule` bilan qo'shilgan qoidalar faylga yozilmaguncha reboot'da yo'qoladi.

**Tuzoq: `flush ruleset` Docker o'rnatilgan hostda.** U barcha jadvallarni, shu jumladan Docker yaratgan NAT va forward qoidalarini o'chiradi: konteynerlar tarmoqsiz qoladi, toki Docker qayta ishga tushirilmaguncha. Bunday hostda faqat o'z jadvalingizni tozalang (`flush table inet filter`).

### iptables bilan moslik

Eski qo'llanmalar, Docker va Kubernetes (kube-proxy) hanuz iptables tilida gapiradi, o'qiy olish kerak:

| iptables | nftables'dagi ma'nosi |
|----------|-----------------------|
| `iptables -L -n -v`, `iptables -S` | `filter` jadvalini ko'rish |
| `iptables -t nat -S` | `nat` jadvalini ko'rish |
| `iptables -P INPUT DROP` | `policy drop` |
| `iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | `ct state established,related accept` |
| `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` | `tcp dport 22 accept` |
| `iptables -I INPUT 1 ...` | zanjir boshiga qo'shish (`-A` oxiriga) |

### ufw va firewalld

`ufw` bir serverli holatlar uchun yetarli:

```
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow from 10.0.0.0/8 to any port 5432 proto tcp
sudo ufw limit 22/tcp            # deny if 6+ connections in 30 seconds from one IP
sudo ufw enable
sudo ufw status verbose
sudo ufw status numbered         # then: sudo ufw delete N
```

ufw sukut bo'yicha `forward` trafigini taqiqlaydi (`/etc/default/ufw` dagi `DEFAULT_FORWARD_POLICY="DROP"`), router yoki VPN server uchun buni hisobga olish kerak.

`firewalld` (RHEL oilasi): interfeyslar **zona** larga biriktiriladi (`public`, `internal`, `trusted`), har zonada ruxsat etilgan servis va portlar ro'yxati. O'zgarishlar ikki qatlamli: runtime va `--permanent`.

```
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

**Tuzoq: SSH'ni ochmasdan `enable`.** `ufw enable` yoki `policy drop` ni 22-port qoidasidan oldin qo'llash masofadagi serverdan o'zingizni uzadi. Tartib: avval ruxsat, keyin siyosat; qoidalarni fayldan atomik yuklash (`nft -f`); zaxira sessiyani ochiq saqlash.

## 4. NAT

**NAT (Network Address Translation)** paket header'idagi manzil yoki portni yo'lda qayta yozadi. Sababi: private manzillar (3-dars) internetda route qilinmaydi.

| Tur | Nimani o'zgartiradi | Hook | Ishlatilishi |
|-----|---------------------|------|--------------|
| SNAT | manba IP (va port) ni berilgan manzilga | `postrouting` | ichki tarmoq internetga bitta public IP orqali chiqadi |
| MASQUERADE | SNAT, lekin manzil chiqish interfeysining joriy IP'si | `postrouting` | interfeys IP'si dinamik bo'lganda (uy routeri, Docker) |
| DNAT | manzil IP (va port) | `prerouting` | port forwarding: tashqi port ichki hostga |

Mexanizm conntrack'ka tayanadi. Ichki `10.0.1.2:51000` dan `1.1.1.1:443` ga paket chiqadi:

1. Router `postrouting` da manbani o'z tashqi manziliga almashtiradi (`203.0.113.5:51000`, port band bo'lsa boshqasiga) va bu moslikni conntrack jadvaliga yozadi.
2. Server javobni `203.0.113.5:51000` ga yuboradi.
3. Router javobni conntrack yozuvi bo'yicha taniydi va manzilni `10.0.1.2:51000` ga qaytarib yozadi. Javob uchun alohida qoida kerak emas.

NAT qoidalari faqat ulanishning **birinchi** paketida tekshiriladi, qolganlari conntrack yozuvi bo'yicha tarjima qilinadi.

```
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "ens3" tcp dport 8080 dnat to 10.0.1.2:80
    }
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 10.0.1.0/24 oifname "ens3" masquerade
    }
}
```

NAT ishlashi uchun uch shart birga: (1) `ip_forward=1` (5-dars); (2) `forward` zanjiri paketni o'tkazadi; (3) NAT qoidasi. Ko'rish: `sudo conntrack -L` (faol tarjimalar), `sudo nft list table ip nat`.

**Tuzoq: DNAT'dan keyin filtr qoidasi qaysi portni ko'radi.** `prerouting` `forward` dan oldin bajariladi, demak `forward` zanjiridagi qoida allaqachon tarjima qilingan manzilni ko'radi: tashqi `8080` emas, `10.0.1.2` va `80` ga ruxsat yoziladi.

**Tuzoq: DNAT hostning o'zidan ishlamaydi.** `prerouting` faqat tashqaridan kelgan paketlarga taalluqli. Hostning o'zida `curl localhost:8080` qilsangiz paket `output` hook'idan chiqadi va DNAT qoidasiga tushmaydi. Buning uchun `output` zanjirida alohida qoida kerak.

NAT oqibatlari: server haqiqiy mijoz IP'sini ko'rmaydi (log'da router IP'si; shuning uchun L7 proxy `X-Forwarded-For` qo'shadi), tashqaridan ichkariga ulanishni boshlash mumkin emas (DNAT'siz), bitta public IP ortidagi bir vaqtdagi ulanishlar soni portlar soni bilan cheklangan (cloud NAT gateway'da "port exhaustion").

### Docker va NAT

Docker 1 va 5-darslardagi bloklar ustiga ikki NAT qoidasini qo'shadi:

- **Chiqish**: bridge subnet'idan chiqqan va bridge'ga qaytmayotgan trafik uchun `MASQUERADE` (`iptables -t nat -S POSTROUTING`).
- **`-p 8080:80`**: `DOCKER` zanjirida `DNAT`: hostning 8080-portiga kelgan paket konteyner IP'sining 80-portiga. Paket keyin `forward` dan o'tadi.

**Tuzoq: Docker publish qilgan port ufw'ni chetlab o'tadi.** `ufw deny 8080` `input` zanjiriga yoziladi, publish qilingan portga kelgan paket esa DNAT'dan keyin `forward` ga ketadi, u yerda Docker'ning o'z ruxsat qoidalari bor. Natija: `ufw status` port yopiq deydi, internet esa konteynerga ulanadi. Yechimlar: faqat lokal kerak bo'lsa `-p 127.0.0.1:8080:80`; tashqi cheklovlar `DOCKER-USER` zanjiriga; yoki port umuman publish qilinmaydi va oldida reverse proxy turadi.

## 5. VPN

**VPN (Virtual Private Network)** ishonchsiz tarmoq (internet) ustida shifrlangan tunnel: asl IP paket shifrlanib, boshqa paketning ichiga joylanadi (encapsulation) va qarshi tomonda ochiladi. Hostda bu virtual interfeys (`wg0`, `tun0`) va unga yo'naltirilgan route'lar ko'rinishida namoyon bo'ladi: VPN aslida routing va shifrlash.

| Topologiya | Kim ulanadi | Misol |
|------------|-------------|-------|
| Remote access | bitta qurilma tarmoqqa | xodim noutbuki ofis yoki VPC'ga |
| Site-to-site | tarmoq tarmoqqa, gateway'lar orasida | ofis va cloud VPC, ikki data markaz |

| Rejim | Route'lar | Oqibat |
|-------|-----------|--------|
| Full tunnel | default route tunnel'ga | butun trafik VPN orqali, VPN server NAT qiladi |
| Split tunnel | faqat ichki prefikslar tunnel'ga | internet trafik to'g'ridan-to'g'ri |

### WireGuard

Kernel ichidagi zamonaviy VPN: UDP ustida, kichik kod bazasi, sozlamasi SSH kalitlariga o'xshaydi. Sertifikat, foydalanuvchi nomi, "ulanish" tushunchasi yo'q: faqat kalit juftliklari va peer'lar ro'yxati.

```
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
```

`/etc/wireguard/wg0.conf` (A tomon):

```
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <A private key>

[Peer]
PublicKey = <B public key>
AllowedIPs = 10.8.0.2/32
Endpoint = <B address>:51820
PersistentKeepalive = 25
```

```
sudo wg-quick up wg0          # create interface, set keys, add addresses and routes
sudo wg show                  # peers, latest handshake, transfer counters
sudo wg-quick down wg0
sudo systemctl enable --now wg-quick@wg0   # persistent
```

| Kalit | Ma'nosi |
|-------|---------|
| `Address` | tunnel ichidagi o'z manzili |
| `ListenPort` | UDP port (51820 odat bo'yicha); firewall'da ochiq bo'lishi kerak |
| `PublicKey` | peer'ning identifikatori |
| `AllowedIPs` | **ikki vazifa**: chiqishda "shu manzillarga ketayotgan paketni shu peer'ga shifrlab yubor" (routing), kirishda "shu peer'dan faqat shu manba manzilli paketni qabul qil" (filtr) |
| `Endpoint` | peer'ning haqiqiy (tashqi) manzili va porti. Faqat bir tomonda bo'lsa ham yetadi: ikkinchi tomon uni kelgan paketdan o'rganadi |
| `PersistentKeepalive` | NAT ortidagi tomonda: har N soniyada paket yuborib NAT yozuvini tirik saqlaydi |

Mexanizm nozikliklari:

- **Jim protokol**: to'g'ri kalit bilan imzolanmagan paketga WireGuard hech qanday javob bermaydi. Port skanerida ko'rinmaydi, lekin tashxis ham qiyin: kalit xato bo'lsa xato xabari yo'q, faqat `latest handshake` paydo bo'lmaydi.
- Handshake faqat trafik bo'lganda bajariladi. `wg show` da handshake yo'qligi ping yubormaguningizcha normal.
- **Site-to-site** uchun `AllowedIPs` ga qarshi tomon ortidagi subnet qo'shiladi (`10.8.0.2/32, 10.20.0.0/16`), gateway'larda `ip_forward=1` va `forward` qoidalari kerak, ikkala saytdagi hostlar esa qarshi subnet'ga route'ni o'z gateway'i orqali bilishi kerak (5-dars: qaytish yo'li).
- `AllowedIPs = 0.0.0.0/0` full tunnel: `wg-quick` buni alohida routing table va `ip rule` bilan amalga oshiradi (5-dars, policy routing).
- Interfeys MTU'si sukut bo'yicha 1420: tashqi IP, UDP va WireGuard header'lari uchun joy (2-dars).

### OpenVPN va IPsec

| | WireGuard | OpenVPN | IPsec (IKEv2) |
|---|-----------|---------|---------------|
| Qayerda ishlaydi | kernel | user space | kernel + IKE daemon (strongSwan) |
| Transport | UDP | UDP (odatda 1194) yoki TCP (443 orqali firewall'dan o'tish uchun) | UDP 500 va 4500 (IKE, NAT-T), ESP |
| Autentifikatsiya | statik kalit juftliklari | TLS: sertifikatlar (PKI), ixtiyoriy login va parol | pre-shared key yoki sertifikatlar |
| Sozlash | sodda | o'rtacha, ko'p opsiya | murakkab, ko'p parametr mos kelishi kerak |
| Qayerda uchraydi | zamonaviy o'rnatmalar, Tailscale va shu kabi mesh VPN'lar asosi | eski korporativ remote access | cloud site-to-site VPN (AWS, GCP, Azure), tarmoq uskunalari |

Amaliy xulosa: o'zingiz qursangiz WireGuard; cloud VPC'ni ofis uskunasiga ulasangiz IPsec bilan ishlaysiz, chunki cloud VPN gateway'lar shuni taklif qiladi.

**Tuzoq: tunnel ko'tarildi, lekin ichki tarmoq ko'rinmaydi.** `wg show` da handshake bor, tunnel manzillari ping bo'ladi, ortidagi subnet esa yo'q. Deyarli doim uchtadan biri: `AllowedIPs` da subnet yo'q, gateway'da forwarding yoki `forward` qoidasi yo'q, yoki narigi saytdagi hostlar javobni tunnel'ga emas, o'z default gateway'iga yuboryapti.

## Tuzoqlar

- Masofadagi serverda SSH ruxsatisiz default-drop qo'llash. Avval ruxsat, keyin siyosat, zaxira sessiya ochiq.
- `established,related` qoidasi yo'q yoki ro'yxat oxirida: chiquvchi ulanishlarning javoblari (DNS, `apt`, API chaqiruvlari) tashlanadi.
- Faqat IPv4 qoidalari: servis IPv6 orqali ochiq qoladi. `inet` oilasi ikkalasini qamraydi.
- Barcha ICMP'ni taqiqlash: PMTUD va tashxis buziladi.
- Qoidalarni `nft add` yoki `iptables -A` bilan qo'shib, faylga saqlamaslik: reboot'dan keyin firewall yo'q yoki eski.
- Docker publish qilgan port `ufw` ni chetlab o'tishi. Ma'lumotlar bazasi konteyneri `-p 5432:5432` bilan butun internetga ochiq qolishi.
- Bir hostda `ufw`, qo'lda `nft` va `iptables` ni aralashtirish; Docker bor hostda `flush ruleset`.
- NAT sozlab, `ip_forward` yoki `forward` ruxsatini unutish; DNAT'dan keyingi filtrda tashqi portni yozish.
- NAT ortidagi serverda log'dagi mijoz IP'siga ishonib rate limit yoki ban qo'yish: hamma mijoz bitta IP bo'lib ko'rinadi.
- WireGuard private kalitini repo'ga qo'shish yoki `wg0.conf` ni hamma o'qiy oladigan ruxsat bilan qoldirish (600 bo'lishi kerak).
- VPN subnet'i mijozning uy tarmog'i yoki Docker diapazoni bilan kesishishi (3-dars, manzil rejasi).

## Manbalar

- https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes – nftables qisqa ma'lumotnoma
- https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks – hook'lar va prioritetlar sxemasi
- https://www.netfilter.org/projects/nftables/manpage.html – `nft` man sahifasi
- https://man7.org/linux/man-pages/man8/iptables.8.html – `iptables`
- https://documentation.ubuntu.com/server/how-to/security/firewalls/ – Ubuntu Server: ufw
- https://firewalld.org/documentation/ – firewalld
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker va iptables, `DOCKER-USER` zanjiri
- https://www.wireguard.com/quickstart/ – WireGuard quick start
- https://www.wireguard.com/#cryptokey-routing – cryptokey routing (`AllowedIPs`)
- https://man7.org/linux/man-pages/man8/wg.8.html va https://man7.org/linux/man-pages/man8/wg-quick.8.html – `wg`, `wg-quick`
- https://openvpn.net/community-resources/how-to/ – OpenVPN HOWTO
- https://docs.strongswan.org/ – strongSwan (IPsec)
- https://www.rfc-editor.org/rfc/rfc3022 – an'anaviy NAT

---

## Vazifalar

Ish papkasi: `network/06-firewall-nat-vpn/` (`make new m=network n=06 name=firewall-nat-vpn`). Javoblarni shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yozing: bajarilgan buyruqlar, chiqishning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`.nft`, `.sh`, `wg0.conf.example`) shu papkaga saqlang. WireGuard private kalitlari papkaga ko'chirilmaydi. C guruh ish mashinasida (faqat o'qish va Docker konteynerlari), qolgan hammasi VM'larda.

### A. Firewall asoslari (VM)

1. **Baseline.** `net1` da `sudo nft list ruleset`, `sudo iptables -S`, `sudo ufw status verbose` va `iptables -V` chiqishini yozing. Toza Ubuntu 24.04 da firewall holati qanday? `ss -tlnp` bo'yicha hozir tarmoqdan qaysi portlar yetib bo'ladi?

2. **First ruleset.** `net1` da `python3 -m http.server 8000` va `nc -lk 9000` ni ishga tushiring. `host.nft` faylini yozing: `inet` jadval, `input` default drop, `established,related`, loopback, ICMP, SSH va 8000-portga ruxsat. `nft -c -f` bilan tekshirib, yuklang. `net2` dan 22, 8000 va 9000-portlarni `nc -vz -w 3` bilan sinab, natijalarni jadvalga yozing.

3. **Drop vs reject.** 9000-port uchun avval `drop`, keyin `reject` qoidasini qo'llang. Har holatda `net2` dagi `nc` xato matni, javob vaqti va `net1` dagi `tcpdump -nn tcp port 9000` chiqishini solishtiring. Qaysi holatda `SYN` takrorlanadi?

4. **Why established matters.** `ct state established,related accept` qatorini olib tashlab qoidalarni qayta yuklang (SSH qoidasi qolsin, sessiyani yopmang). `net1` dan `curl -m 5 https://example.com` va `dig example.com` natijalarini yozing. Chiquvchi so'rov ketdi, javob nima uchun kelmadi? `tcpdump` bilan tasdiqlang va qatorni qaytaring.

5. **Rule order and counters.** `tcp dport 8000 drop` qoidasini avval mavjud `accept` dan keyin, so'ng undan oldin qo'ying (`insert` yoki handle bilan). Har holatda natijani va `counter` qiymatlarini (`nft list chain`) yozing. Qoidani handle bo'yicha o'chiring.

6. **Source restriction and logging.** 8000-portni faqat `net2` IP'sidan ochiq qiling va tashlangan paketlarni `log prefix` bilan log qiling. Ish mashinasidan va `net2` dan sinab ko'ring. `sudo journalctl -k -n 20` dagi log qatoridan `IN=`, `SRC=`, `DPT=` maydonlarini izohlang.

7. **IPv6 gap.** `host.nft` ni `inet` o'rniga `ip` oilasiga o'zgartirib yuklang. `net1` ning IPv6 manzili bo'lsa (link-local ham yetadi) `net2` dan `nc -6 -vz <fe80 manzil>%<iface> 9000` bilan sinang. Natija nimani ko'rsatadi? `inet` ga qaytaring.

8. **ufw.** `net2` da xuddi 2-vazifadagi siyosatni `ufw` bilan quring (22 ochiq, 8000 faqat `net1` dan, qolgani yopiq). `ufw status numbered` va `sudo nft list ruleset | head -60` (yoki `iptables -S`) chiqishini solishtiring: ufw nechta zanjir yaratdi? Bitta qoidani raqami bo'yicha o'chiring. Xuddi shu siyosat `firewall-cmd` buyruqlari bilan qanday yozilishini (bajarmasdan) README'ga yozing. Oxirida `sudo ufw disable`.

### B. NAT (VM)

9. **Namespace behind NAT.** `net1` da `app` namespace'ini yarating, veth bilan VM'ning asosiy namespace'iga ulang (`10.0.1.1/24` VM tomonda, `10.0.1.2/24` `app` da, default route `10.0.1.1`). `app` dan `ping 1.1.1.1` qiling va VM'ning tashqi interfeysida `tcpdump -n icmp` bilan kuzating: paket chiqdimi, manba IP'si qanday, javob nima uchun kelmaydi?

10. **Masquerade.** `ip_forward` ni yoqing va `nat.nft` da `postrouting` masquerade qoidasini yozing. 9-vazifadagi tcpdump'ni takrorlang: manba IP endi nima? `sudo conntrack -L -p icmp` va TCP ulanish uchun (`app` dan `curl`) `conntrack -L -p tcp` yozuvidagi ikki yo'nalish manzillarini izohlang. `forward` zanjiringiz default drop bo'lsa, qanday qoida qo'shish kerak bo'ldi?

11. **Port forwarding.** `app` namespace'ida `python3 -m http.server 80` ni ishga tushiring. `nat.nft` ga DNAT qo'shing: VM'ning 8080-porti `10.0.1.2:80` ga. `net2` dan `curl http://<net1 IP>:8080/` ishlashini ko'rsating. `app` ichidagi server log'ida mijoz IP'si kim? `forward` zanjirida qaysi manzil va portga ruxsat berdingiz va nima uchun 8080 emas?

12. **DNAT from the host itself.** `net1` ning o'zidan `curl -m 3 http://localhost:8080/` va `curl -m 3 http://<net1 IP>:8080/` ni sinang. Natijani netfilter hook'lari bilan tushuntiring. `output` hook'ida qoida qo'shib kamida ikkinchi variantni ishlating.

13. **Missing pieces.** Ishlab turgan NAT'dan navbat bilan bittadan olib tashlang va har safar alomatni yozing (xato matni, tcpdump'da paket qayergacha yetdi): (a) `ip_forward=0`; (b) `forward` ruxsati; (c) masquerade qoidasi (DNAT qolgan holda `net2` dan so'rov: javob qaytadimi, nima uchun?).

### C. Docker (ish mashinasi, faqat o'qish va konteynerlar)

14. **Docker NAT rules.** `docker run -d --name web -p 8080:80 nginx:alpine` ni ishga tushiring. `sudo iptables -t nat -S` chiqishidan konteyner tarmog'i uchun `MASQUERADE` va 8080-port uchun `DNAT` qatorlarini toping va har flag'ini izohlang. `sudo iptables -S FORWARD` va `DOCKER-USER` zanjirini ko'ring. Bularni 10 va 11-vazifalarda o'zingiz yozgan qoidalar bilan yonma-yon qo'ying.

15. **Published port exposure.** `ss -tlnp | grep 8080` chiqishida kim va qaysi manzilda tinglayapti? LAN'dagi boshqa qurilmadan (telefon) `http://<ish mashinasi IP>:8080` ochiladimi? Konteynerni `-p 127.0.0.1:8080:80` bilan qayta yarating va farqni `ss` hamda `iptables -t nat -S` da ko'rsating. Nima uchun `ufw deny 8080` birinchi holatda yordam bermasligini hook'lar bilan tushuntiring (bajarmasdan). Konteynerni o'chiring.

### D. WireGuard (VM)

16. **Tunnel between two hosts.** `net1` (`10.8.0.1/24`) va `net2` (`10.8.0.2/24`) orasida WireGuard tunnel quring: kalitlar, `/etc/wireguard/wg0.conf`, `wg-quick up`. Tunnel manzillari orasida ping o'tishini, `sudo wg show` dagi `latest handshake` va `transfer` ni ko'rsating. `ip addr show wg0`, `ip route` da nima paydo bo'ldi, MTU nechchi? Private kalitsiz nusxani `wg0.conf.example` ga saqlang.

17. **What is on the wire.** `net1` da ikki tcpdump: biri `-i wg0`, ikkinchisi tashqi interfeysda `udp port 51820`. `net2` dan tunnel orqali `curl http://10.8.0.1:8000/` qiling. Har interfeysda nima ko'rinadi (protokol, manzillar, o'qiladigan mazmun)? Tashqi paket hajmi ichki paketdan necha bayt katta va bu MTU 1420 ni qanday tushuntiradi?

18. **Break the tunnel.** Uch nosozlikni navbat bilan yarating va har birida `wg show`, `ping` xatosi va tcpdump kuzatuvini yozing: (a) bir tomonda peer'ning public kaliti noto'g'ri; (b) `net1` firewall'ida UDP 51820 yopiq; (c) `net2` dagi `AllowedIPs` da `10.8.0.1` yo'q (boshqa manzil yozilgan). Qaysi holatda xato xabari umuman yo'q va tashxisni qanday qildingiz?

19. **Firewall on the tunnel.** `net1` da 9000-portni faqat `wg0` interfeysidan ochiq qiling (`iifname`). `net2` dan `10.8.0.1:9000` va `<net1 tashqi IP>:9000` ga ulanishni solishtiring. Bu naqsh real hayotda qaysi servislar uchun ishlatiladi?

20. **Site-to-site.** Tunnel'ni kengaytiring: `net2` `net1` ortidagi `app` namespace'iga (`10.0.1.2`) tunnel orqali yetsin. Qaysi tomonda `AllowedIPs` ni o'zgartirish, qayerda forwarding va `forward` qoidasi, qayerda route kerakligini avval yozing, keyin bajaring. `net2` dan `curl http://10.0.1.2/` ishlashini va `app` server log'ida ko'ringan mijoz IP'sini ko'rsating. Bu yerda NAT kerak bo'ldimi, nima uchun?

### E. Modul mini-loyihasi

21. **Secure gateway.** Hammasini bitta takrorlanadigan o'rnatmaga yig'ing. `net1` gateway, uning ortida `app` namespace'i (80-portda "public" web, 9000-portda "admin" servis); `net2` masofadagi administrator. Talablar:
    - `net1` da `input` va `forward` default drop, qoidalar bitta `gateway.nft` faylida, `flush ruleset` bilan atomik yuklanadi.
    - Tashqaridan faqat: SSH, UDP 51820, va 8080-port (DNAT orqali `app:80`).
    - `app` internetga masquerade orqali chiqadi.
    - `app:9000` ga faqat WireGuard tunnel orqali `net2` dan yetib bo'ladi; tashqi interfeysdan hech qanday yo'l bilan emas.
    - `gateway.sh up|down|status`: namespace, veth, sysctl, nftables va WireGuard'ni ko'taradi va tozalaydi; idempotent; `shellcheck` toza.
    - `verify.sh` (`net2` da ishlaydi): kamida 8 ta tekshiruv (ruxsat etilgan va taqiqlangan yo'llar) bajarib, har biri uchun kutilgan va haqiqiy natijani jadval qilib chiqaradi, biror nomuvofiqlikda nol bo'lmagan exit code qaytaradi.
    - README'da: topologiya sxemasi (ASCII), manzil jadvali, bitta tashqi so'rov (`net2` dan `net1:8080`) va bitta tunnel so'rovi (`net2` dan `app:9000`) uchun paketning hook'lar bo'ylab to'liq yo'li (qaysi hook'da qaysi qoida ishladi, manzillar qayerda o'zgardi).

22. **Module retrospective.** "`net2` dan `http://<net1 IP>:8080/` ochilmayapti" shikoyati uchun modulning barcha olti darsiga tayangan tashxis runbook'ini yozing: link va ARP, IP va mask, route va qaytish yo'li, DNS (agar nom ishlatilsa), TCP port va holat, firewall hook'lari, NAT va conntrack, ilova. Har qadam: qaysi hostda qaysi buyruq, nimani isbotlaydi. Mini-loyihangizda kamida ikki nosozlikni ataylab yaratib, runbook bo'yicha topilishini ko'rsating.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa; `host.nft`, `nat.nft`, `gateway.nft`, `gateway.sh`, `verify.sh`, `wg0.conf.example` papkada.
2. `make check` toza (`shellcheck`, `make secrets`): papkada WireGuard private kaliti yo'q.
3. `verify.sh` toza VM'larda `gateway.sh up` dan keyin to'liq o'tadi, `gateway.sh down` dan keyin `nft list ruleset`, `ip netns list`, `wg show` bo'sh.
4. Ish mashinasida Docker `web` konteyneri o'chirilgan, firewall qoidalari o'zgarmagan.
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
