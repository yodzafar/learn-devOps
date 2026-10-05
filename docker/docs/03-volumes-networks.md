# 3-dars: Volume va tarmoqlar

Maqsad: konteynerning ikki tashqi bog'lanishini mexanizm darajasida tushunish: ma'lumot qayerda yashaydi (volume, bind mount, tmpfs) va konteynerlar bir-birini hamda tashqi dunyoni qanday topadi (bridge, DNS, NAT). Dars oxirida healthcheck: "jarayon ishlayapti" bilan "servis javob beryapti" orasidagi farq. 1-darsdagi `-p` va 2-darsdagi yoziladigan layer shu yerda ochiladi; 4-darsdagi Compose shu uch narsani (volumes, networks, healthcheck) YAML'da tavsiflaydi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqatni quyidagilarga qarating: volume qachon o'chadi va qachon o'chmaydi, bo'sh volume'ning image mazmuni bilan to'ldirilishi, bind mount'dagi UID muammosi, default bridge'da DNS yo'qligi, konteyner ichidagi `localhost`, publish qilingan port bilan konteyner porti farqi, `unhealthy` konteynerni Docker o'zi qayta ishga tushirmasligi.

## Laboratoriya

Ish mashinasidagi Docker Engine. Image'lar: `alpine:3.22`, `nginx:1.28-alpine`, `postgres:17-alpine`. iptables qoidalarini ko'rish uchun `sudo iptables -t nat -S` kerak bo'ladi, bu faqat o'qiydi. Hostda hech narsa o'rnatilmaydi; tarmoq asboblari kerak bo'lsa konteyner ichida `apk add` bilan o'rnatiladi.

Mashinangizda boshqa loyihalarning volume va konteynerlari bor. Shu darsdagi barcha resurslarni `l3-` prefiksi bilan nomlang va faqat shularni o'chiring:

```
docker ps -a --filter name=l3-
docker volume ls --filter name=l3-
docker network ls --filter name=l3-
docker rm -f $(docker ps -aq --filter name=l3-)
docker volume rm $(docker volume ls -q --filter name=l3-)
docker network rm $(docker network ls -q --filter name=l3-)
```

`docker volume prune -a` va `docker system prune --volumes` bu mashinada ishlatilmaydi: ular boshqa loyihalarning ishlatilmayotgan volume'larini ham o'chiradi.

---

## 1. Ma'lumot qayerda yashaydi

Konteynerning yoziladigan layer'i (2-dars) konteyner bilan birga o'chadi, copy-on-write tufayli sekin va boshqa konteyner bilan bo'lishilmaydi. Saqlanishi kerak bo'lgan har narsa mount orqali tashqariga chiqariladi.

| | Volume | Bind mount | tmpfs |
|---|--------|------------|-------|
| Qayerda | `/var/lib/docker/volumes/<name>/_data`, Docker boshqaradi | hostdagi istalgan yo'l | RAM |
| Kim yaratadi | Docker (`volume create` yoki birinchi ishlatishda) | siz, oldindan | Docker, har startda |
| Konteyner o'chganda | qoladi | qoladi (host fayli) | yo'qoladi |
| Host yo'liga bog'liqlik | yo'q | bor | yo'q |
| Qachon | baza ma'lumotlari, yuklangan fayllar | dev'da manba kodi, config fayl, socket | vaqtinchalik va maxfiy fayllar, `--read-only` bilan |

### Sintaksis

```
docker run -v l3-data:/var/lib/postgresql/data ...          # named volume
docker run -v "$PWD/conf":/etc/nginx/conf.d:ro ...          # bind mount, read-only
docker run --mount type=volume,src=l3-data,dst=/data ...    # explicit form
docker run --mount type=bind,src="$PWD",dst=/app,readonly ...
docker run --tmpfs /tmp:size=64m ...
```

`-v` ning birinchi qismi `/` yoki `.` bilan boshlansa bind mount, aks holda volume nomi. Birinchi qism umuman bo'lmasa (`-v /data`) anonim volume.

**Tuzoq: `-v` mavjud bo'lmagan host yo'lini jimgina papka sifatida yaratadi (root egaligida).** Fayl nomida xato qilsangiz (`-v ./ngnix.conf:/etc/nginx/nginx.conf`) konteyner ichida fayl o'rnida bo'sh papka paydo bo'ladi. `--mount type=bind` bunday holatda `bind source path does not exist` xatosini beradi, shuning uchun skript va hujjatda `--mount` afzal.

### Mount image mazmunini yopadi

Mount nuqtasidagi image fayllari mount ostida ko'rinmay qoladi. Bitta istisno: **bo'sh named volume** birinchi marta ulanganda Docker image'dagi shu papka mazmunini volume'ga nusxalaydi. Bind mount'da bunday nusxalash yo'q: bo'sh host papkasi image'dagi fayllarni yashiradi.

Shu sababli dev'dagi mashhur muammo: `-v "$PWD":/app` image ichidagi `/app/node_modules` ni hostdagi (yo'q yoki boshqa platformadagi) bilan almashtiradi.

### Hayot sikli

| Harakat | Named volume | Anonim volume |
|---------|--------------|---------------|
| `docker rm <c>` | qoladi | qoladi (yetim bo'lib) |
| `docker rm -v <c>` yoki `--rm` | qoladi | o'chadi |
| `docker volume prune` | qoladi | ishlatilmayotgani o'chadi |
| `docker volume prune -a` | ishlatilmayotgani **o'chadi** | o'chadi |
| `docker volume rm <v>` | o'chadi (ishlatilayotgan bo'lsa xato) | o'chadi |

Image'da `VOLUME /path` instruksiyasi bo'lsa (masalan `postgres`), `-v` berilmagan har `run` yangi anonim volume yaratadi: ma'lumot "yo'qoladi" (aslida yetim volume'da yotadi) va disk to'ladi. Buyruqlar: `docker volume ls`, `docker volume inspect`, `docker system df -v`.

**Tuzoq: ma'lumot volume'da, lekin volume nomi konteynerga bog'langan emas.** Baza konteynerini boshqa volume nomi bilan qayta yaratsangiz bo'sh baza ko'tariladi. Rasmiy `postgres` image'i faqat bo'sh data papkasida initsializatsiya qiladi: mavjud volume'da `POSTGRES_PASSWORD` ni o'zgartirish parolni o'zgartirmaydi.

## 2. Backup, restore, ruxsatlar

### Volume backup va restore

Volume'ga hostdan to'g'ridan-to'g'ri kirish root talab qiladi va Docker ichki tuzilishiga bog'liq. Standart usul: volume'ni va backup papkasini vaqtinchalik konteynerga ulash.

```
docker run --rm -v l3-data:/data:ro -v "$PWD":/backup alpine:3.22 \
  tar czf /backup/l3-data.tgz -C /data .

docker run --rm -v l3-restored:/data -v "$PWD":/backup:ro alpine:3.22 \
  tar xzf /backup/l3-data.tgz -C /data
```

**Tuzoq: ishlayotgan bazaning fayllarini `tar` qilish izchil (consistent) backup bermaydi.** Baza yozish o'rtasida bo'lishi mumkin. Yo konteynerni to'xtatib arxivlang, yo bazaning o'z vositasini ishlating (`pg_dump`, `redis-cli --rdb`). Tekshirilmagan backup backup emas: har doim restore qilib ko'ring.

### UID va ruxsatlar

Kernel fayl egasini raqam (UID/GID) bilan saqlaydi, nom emas. Konteyner va host bitta kernelda, user namespace yo'q, demak konteynerdagi UID 1000 hostdagi UID 1000 ning o'zi. Nomlar har tomonning o'z `/etc/passwd` idan olinadi va mos kelmasligi mumkin.

| Holat | Natija |
|-------|--------|
| Konteyner root, bind mount'ga yozadi | hostda `root` egaligidagi fayllar, siz ularni `sudo` siz o'chira olmaysiz |
| Konteyner non-root (masalan `postgres:17-alpine` da UID 70), host papkasi sizniki (UID 1000) | konteynerda `Permission denied` |
| `--user "$(id -u):$(id -g)"` | fayllar sizning egaligingizda, lekin bu UID image ichida nomsiz va home papkasiz |

Named volume'da bu kamroq og'riqli: bo'sh volume to'ldirilganda image'dagi papkaning egasi va ruxsatlari ham ko'chiriladi. Shuning uchun non-root image'da ma'lumot papkasi `Dockerfile` da to'g'ri egalik bilan oldindan yaratiladi.

**Tuzoq: muammoni `chmod 777` bilan "yechish".** Bu hostdagi barcha foydalanuvchilarga yozish huquqini beradi. To'g'ri yo'l: UID'ni moslash (`--user`, yoki papka egaligini aniq UID'ga berish).

## 3. Tarmoq driver'lari

| Driver | Nima qiladi | Qachon |
|--------|-------------|--------|
| `bridge` | hostda virtual switch, konteynerlar xususiy subnet'da, tashqariga NAT | bitta hostdagi default |
| `host` | konteyner hostning network namespace'ini ishlatadi | maksimal tarmoq unumdorligi, ko'p portli asboblar |
| `none` | faqat `lo` | tarmoq kerak bo'lmagan batch ishlar, izolyatsiya |
| `overlay` | bir necha host ustidan virtual tarmoq | Swarm (5-dars) |
| `macvlan`, `ipvlan` | konteynerga fizik tarmoqdan manzil | maxsus holatlar |

### Bridge qanday ishlaydi

Har bridge tarmog'i uchun hostda Linux bridge interfeysi (default tarmoq uchun `docker0`, `172.17.0.0/16`) yaratiladi. Har konteynerga veth juftligi: bir uchi konteyner namespace'ida `eth0`, ikkinchisi hostda bridge'ga ulangan. Bridge manzili (`172.17.0.1`) konteynerning default gateway'i.

### Default bridge va user-defined bridge

| | Default `bridge` | User-defined (`docker network create`) |
|---|------------------|----------------------------------------|
| Nom bo'yicha DNS | yo'q, faqat IP | bor: konteyner nomi va `--network-alias` |
| `/etc/resolv.conf` | host DNS serverlari | `nameserver 127.0.0.11` (Docker embedded DNS) |
| Izolyatsiya | `--network` berilmagan barcha konteynerlar shu yerda | faqat ulangan konteynerlar bir-birini ko'radi |
| Ishlayotgan konteynerni ulash | qayta yaratish kerak | `docker network connect` / `disconnect` |

Qoida: default bridge'ni ishlatmang, har ilova uchun o'z tarmog'ini yarating. Compose buni avtomatik qiladi.

Embedded DNS (`127.0.0.11`) tarmoqdagi konteyner nomlarini joriy IP'ga yechadi, boshqa nomlarni host DNS'iga uzatadi. IP konteyner qayta yaratilganda o'zgaradi, shuning uchun konfiguratsiyada har doim nom yoziladi, IP emas. Bitta konteyner bir necha tarmoqqa ulanishi mumkin (masalan, proxy `frontend` va `backend` tarmoqlarida, baza faqat `backend` da).

**Tuzoq: konteyner ichidagi `localhost` bu konteynerning o'zi.** Ilova `localhost:5432` ga ulansa o'z namespace'idagi portni qidiradi, host yoki boshqa konteynerni emas. Boshqa konteynerga nomi bilan (`db:5432`), hostdagi servisga `--add-host=host.docker.internal:host-gateway` qo'shib `host.docker.internal` orqali murojaat qilinadi.

### host va none

`--network host`: konteyner hostning interfeyslari va portlarini to'g'ridan-to'g'ri ishlatadi. `-p` e'tiborsiz qoladi (ogohlantirish bilan), port to'qnashuvi hostdagidek. Tarmoq izolyatsiyasi yo'q.

`--network none`: faqat loopback. Tashqi so'rov ham, DNS ham ishlamaydi.

## 4. Port publishing va NAT

Bridge subnet'i xususiy, tashqaridan route qilinmaydi. Ikki yo'nalishda NAT ishlaydi:

| Yo'nalish | Mexanizm | Qoida |
|-----------|----------|-------|
| Konteyner -> tashqariga | source NAT | `nat` jadvali `POSTROUTING` zanjirida `MASQUERADE`: manba manzil host IP'siga almashadi |
| Tashqaridan -> konteynerga (`-p 8080:80`) | destination NAT | `nat` jadvali `DOCKER` zanjirida `DNAT`: `host:8080` manzili `172.x.x.x:80` ga almashadi |

Sizning daemon'ingizda `Firewall Backend: iptables`. Qo'shimcha ravishda har publish qilingan port uchun hostda `docker-proxy` jarayoni tinglaydi (userland proxy): u DNAT qoidasi ishlamaydigan holatlarni (masalan, hostning o'zidan `localhost` orqali murojaat) qamraydi. Shuning uchun `ss -tlnp` da portni `docker-proxy` ushlab turgani ko'rinadi.

Oqibatlar:

- Konteynerlar bir-biriga **konteyner porti** bilan murojaat qiladi (`db:5432`), publish qilingan port bilan emas. `-p` faqat tarmoq tashqarisidan kirish uchun.
- Bitta tarmoqdagi konteynerlar orasidagi aloqa uchun `-p` umuman kerak emas. Baza portini publish qilmaslik eng oddiy himoya.
- DNAT paketni `ufw` ko'radigan `INPUT` zanjiriga yetmasdan `FORWARD` yo'liga buradi. 1-darsdagi "`ufw` to'smaydi" tuzog'ining sababi shu.
- `EXPOSE` hech qanday qoida yaratmaydi, u faqat metadata.

## 5. Healthcheck

Docker default bo'yicha faqat PID 1 tirikligini biladi. Deadlock'ga tushgan, bazaga ulana olmayotgan yoki hali yuklanayotgan ilova `running` ko'rinadi. Healthcheck konteyner **ichida** davriy bajariladigan buyruq: exit 0 sog'lom, exit 1 nosog'lom.

```
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD ["wget", "-qO-", "http://127.0.0.1:3000/healthz"]
```

| Parametr | Default | Ma'nosi |
|----------|---------|---------|
| `--interval` | 30s | tekshiruvlar orasidagi vaqt |
| `--timeout` | 30s | shu vaqtdan oshsa muvaffaqiyatsiz |
| `--retries` | 3 | ketma-ket nechta xatodan keyin `unhealthy` |
| `--start-period` | 0s | start davri: bu vaqtdagi xatolar hisobga olinmaydi |
| `--start-interval` | 5s | start davridagi tekshiruv oralig'i |

Holatlar: `starting`, `healthy`, `unhealthy`. `docker ps` ning `STATUS` ustunida va `docker inspect -f '{{json .State.Health}}'` da (oxirgi tekshiruvlarning chiqishi bilan) ko'rinadi. `run` da ham berish mumkin: `--health-cmd`, `--health-interval`, `--health-retries`, `--health-start-period`, o'chirish `--no-healthcheck`.

Tayyor tekshiruvlar: Postgres `pg_isready -U <user>`, Redis `redis-cli ping`. HTTP uchun asbob image ichida bo'lishi kerak: alpine'da busybox `wget` bor, `curl` yo'q; distroless'da hech biri yo'q, tekshiruvni ilova binary'sining o'zi bajaradi (masalan, alohida `healthcheck` subcommand).

**Tuzoq: Docker `unhealthy` konteynerni qayta ishga tushirmaydi.** Yolg'iz Docker Engine'da bu faqat holat belgisi. Unga Compose'dagi `depends_on: condition: service_healthy` (4-dars) va Swarm (nosog'lom task'ni almashtiradi, 5-dars) tayanadi.

Yaxshi `/healthz`: tez, arzon, tashqi servislarga zanjir bo'lib bog'lanmagan. Agar har servisning healthcheck'i bazani tekshirsa, baza bir lahza sekinlashganda barcha servislar bir vaqtda `unhealthy` bo'ladi.

## Tuzoqlar

- Baza ma'lumotini volume'siz saqlash: `docker rm` yoki `compose down` dan keyin hammasi yo'q.
- `docker volume prune -a` va `docker system prune --volumes`: ishlatilmayotgan (konteyneri to'xtatib o'chirilgan) named volume'lar ham o'chadi. Qaytarib bo'lmaydi.
- Ishlayotgan bazani fayl darajasida nusxalash: backup bor, lekin restore'da baza ochilmaydi.
- Bind mount bilan image mazmunini yopib qo'yish (`node_modules`, build natijasi) va "nima uchun image'dagi kod ishlamayapti" deb qidirish.
- `-v` dagi imlo xatosi: fayl o'rnida root egaligidagi bo'sh papka.
- Host papkasiga `chmod 777`: UID nomuvofiqligi yashiriladi, xavfsizlik teshigi ochiladi.
- Default bridge'da nom bilan ulanishga urinish, keyin IP'ni config'ga yozib qo'yish: konteyner qayta yaratilganda IP o'zgaradi.
- Konteynerda `localhost` ga ulanish: host yoki qo'shni konteyner emas, o'zi.
- Bazaning portini `-p` bilan publish qilish, garchi unga faqat qo'shni konteyner murojaat qilsa ham.
- Healthcheck'da image ichida yo'q asbob (`curl`): konteyner abadiy `unhealthy`, sababi `State.Health.Log` da yozilgan.
- `--start-period` siz sekin yuklanadigan ilova: orkestrator uni hali ko'tarilmasidan o'ldiradi va cheksiz restart sikli boshlanadi.

## Manbalar

- https://docs.docker.com/engine/storage/ – volume, bind mount, tmpfs umumiy ko'rinishi
- https://docs.docker.com/engine/storage/volumes/ – volume'lar, backup va restore
- https://docs.docker.com/engine/storage/bind-mounts/ – bind mount va `-v` bilan `--mount` farqi
- https://docs.docker.com/engine/network/ – tarmoq umumiy ko'rinishi, embedded DNS
- https://docs.docker.com/engine/network/drivers/bridge/ – default va user-defined bridge farqlari
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – iptables qoidalari, port publishing
- https://docs.docker.com/reference/dockerfile/#healthcheck – `HEALTHCHECK` instruksiyasi
- https://hub.docker.com/_/postgres – rasmiy Postgres image hujjati (`PGDATA`, initsializatsiya, env)
- https://man7.org/linux/man-pages/man4/veth.4.html – `man 4 veth`
- Kane, Matthias, "Docker: Up & Running", tarmoq va storage boblari

---

## Vazifalar

Barchasini `docker/03-volumes-networks/` da bajaring (`make new m=docker n=03 name=volumes-networks`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Vazifa so'ragan fayllar (skript, config, `Dockerfile`) shu papkada saqlanadi. Barcha resurs nomlari `l3-` bilan boshlansin.

### A. Volume va mount

1. **Writable layer is ephemeral.** `postgres:17-alpine` ni volume'siz ishga tushiring, jadval yaratib qator qo'shing, konteynerni `rm -f` qilib qayta yarating. Ma'lumot qani? `docker volume ls` da nima paydo bo'lganini toping va `docker image inspect -f '{{json .Config.Volumes}}' postgres:17-alpine` orqali sababini tushuntiring.

2. **Named volume.** Xuddi shuni `l3-pgdata` named volume bilan takrorlang: konteynerni o'chirib qayta yaratgandan keyin ma'lumot saqlanganini ko'rsating. `docker volume inspect l3-pgdata` dan `Mountpoint` ni yozing. Keyin shu volume ustida konteynerni boshqa `POSTGRES_PASSWORD` bilan yarating: qaysi parol ishlaydi va nima uchun?

3. **Volume pre-population.** Bo'sh `l3-html` volume'ni `nginx:1.28-alpine` ning `/usr/share/nginx/html` iga ulang va ichini ko'ring. Keyin bo'sh host papkasini xuddi shu yo'lga bind mount qiling. Ikki holatda `ls` va `curl` natijasini solishtiring va farqni izohlang.

4. **Bind mount config.** O'zingiz yozgan `default.conf` (bitta `location /` matn qaytaradi) ni nginx'ga `:ro` bilan bind mount qiling. Konteyner ichidan faylga yozishga urinib xatoni yozing. Hostda faylni o'zgartiring: nginx nima uchun darhol yangi config'ni ishlatmaydi va uni qayta yaratmasdan qanday qo'llaysiz?

5. **-v vs --mount.** Mavjud bo'lmagan host yo'lini avval `-v`, keyin `--mount type=bind` bilan ulang. Har birida nima sodir bo'ldi? `-v` yaratgan narsaning egasi kim (`ls -ld`) va uni qanday o'chirasiz?

6. **tmpfs and read-only.** nginx'ni `--read-only` bilan ishga tushiring, xatoni loglardan o'qing. Kerakli yo'llarni `--tmpfs` bilan berib ishlating. Konteyner ichida `df -h` yoki `mount` bilan tmpfs'ni ko'rsating. Read-only root fayl tizimi hujumchi uchun nimani qiyinlashtiradi?

7. **Volume lifecycle.** Uch konteyner yarating: anonim volume bilan (`-v /data`), named volume bilan, anonim volume va `--rm` bilan. Har birini to'xtatib o'chiring va `docker volume ls` da nima qolganini yozing. Yetim volume'larni `docker volume ls -f dangling=true` bilan toping va faqat o'zingiznikini nomi (ID'si) bilan o'chiring. `docker volume prune` ni ishga tushirib ogohlantirish matnini o'qing va `N` deb javob bering: u nimani o'chirgan bo'lar edi va `-a` bilan nima qo'shiladi?

### B. Backup va ruxsatlar

8. **Backup and restore.** `backup.sh <volume> <file.tgz>` va `restore.sh <file.tgz> <volume>` skriptlarini yozing (vaqtinchalik `alpine` konteyner bilan). `l3-pgdata` ni to'xtatilgan baza holatida arxivlang, `l3-pgdata-restored` ga tiklang va yangi Postgres konteynerida ma'lumot borligini ko'rsating. `shellcheck` toza bo'lsin. Arxivni commit qilmang.

9. **Logical backup.** Ishlayotgan bazadan `docker exec ... pg_dump` bilan dump oling (hostdagi faylga) va toza volume'li yangi konteynerga `psql` orqali tiklang. 8-vazifadagi usul bilan solishtiring: qaysi biri ishlayotgan bazada xavfsiz va nima uchun, qaysi biri tezroq tiklanadi?

10. **Root-owned files.** `alpine:3.22` da bind mount qilingan papkaga fayl yarating, hostda `ls -ln` bilan egasini ko'ring va `sudo` siz o'chirishga urining. Keyin `--user "$(id -u):$(id -g)"` bilan takrorlang. Konteyner ichida `id` va `whoami` nima deydi va nima uchun?

11. **Permission denied.** Bo'sh host papkasini `postgres:17-alpine` ning data papkasiga bind mount qilib `--user 12345:12345` bilan ishga tushiring, xatoni o'qing. Postgres jarayoni image'da qaysi UID bilan ishlashini aniqlang. Muammoni `chmod 777` siz yechishning ikki yo'lini yozing va bittasini bajaring. Oxirida host papkasini tozalang.

### C. Tarmoq

12. **Default bridge.** `--network` siz ikkita `alpine:3.22` konteyner ishga tushiring. Bir-birini nom bilan va IP bilan `ping` qiling. `/etc/resolv.conf`, `ip addr`, `ip route` ni yozing. Hostda `ip addr show docker0` va `docker network inspect bridge` dan subnet va gateway'ni toping.

13. **User-defined bridge DNS.** `l3-net` tarmog'ini yarating, ikkita konteynerni ulang, biriga `--network-alias db` bering. Nom va alias bilan `ping`, `nslookup` qiling, `/etc/resolv.conf` ni 12-vazifadagi bilan solishtiring. Konteynerlardan birini o'chirib qayta yarating: IP o'zgardimi, nom-chi?

14. **Network isolation.** `l3-front` va `l3-back` tarmoqlarini yarating. `web` ikkalasida, `db` faqat `l3-back` da, `client` faqat `l3-front` da bo'lsin. Kim kimni ko'rishini `ping` bilan jadvalga yozing. `docker network connect` bilan `client` ni `l3-back` ga ulab natija qanday o'zgarganini ko'rsating.

15. **veth pairs.** Bitta konteyner uchun ichkaridagi `eth0` va hostdagi mos veth interfeysini toping (konteynerda `cat /sys/class/net/eth0/iflink`, hostda `ip link` chiqishidagi shu indeksli interfeys). Hostda `bridge link` yoki `ip link show master <bridge>` bilan u qaysi bridge'ga ulanganini ko'rsating.

16. **localhost trap.** Hostda `python3 -m http.server 8000 --bind 0.0.0.0` ni ishga tushiring. Konteyner ichidan `wget -qO- http://localhost:8000` qiling, xatoni izohlang. Keyin `--add-host=host.docker.internal:host-gateway` bilan hostga yeting. `/etc/hosts` da nima paydo bo'ldi? Ulanish timeout bersa `sudo ufw status` ni ko'ring va sababini izohlang (qoida qo'shmang). Oxirida serverni to'xtating.

17. **host and none.** nginx'ni `--network host` bilan (hostda 80-port bo'sh bo'lsa) yoki `alpine` ni `--network host` bilan ishga tushirib `ip addr` ni host bilan solishtiring; `-p` qo'shilganda chiqadigan ogohlantirishni yozing. `--network none` da `ip addr` va tashqi `ping` natijasini ko'rsating.

18. **NAT rules.** nginx'ni `l3-net` da `-p 127.0.0.1:8085:80` bilan ishga tushiring. `sudo iptables -t nat -S | grep -E "DOCKER|MASQUERADE"` dan shu portga tegishli `DNAT` qoidasini va tarmoq subnet'i uchun `MASQUERADE` qoidasini toping, har birini bir gapda izohlang. `ss -tlnp | grep 8085` da portni kim tinglayapti? Shu tarmoqdagi boshqa konteynerdan nginx'ga qaysi port bilan murojaat qilinadi: 80 yoki 8085, va nima uchun?

### D. Healthcheck

19. **Healthcheck states.** nginx'ni `--health-cmd`, `--health-interval 5s`, `--health-retries 2` bilan ishga tushiring (tekshiruv: `wget` bilan `127.0.0.1`). `starting` dan `healthy` ga o'tishni kuzating. Keyin `docker exec` bilan `index.html` ni o'chirib yoki nginx config'ni buzib `unhealthy` qiling. `docker inspect -f '{{json .State.Health}}'` dagi logni o'qing. Konteyner qayta ishga tushdimi? `docker events --filter event=health_status` nimani ko'rsatadi?

20. **Broken healthcheck.** `postgres:17-alpine` ni `--health-cmd "curl -f http://localhost:5432"` bilan ishga tushiring. Holat nima va `State.Health.Log` da qaysi xato? To'g'ri tekshiruvga (`pg_isready`) almashtiring. Nima uchun TCP port ochiqligi "baza tayyor" degani emas?

### E. Yakuniy

21. **Two-tier app by hand.** Compose'siz, faqat `docker` buyruqlari bilan (`up.sh` va `down.sh` skriptlari): 2-darsdagi Node yoki Go image'ingiz (yoki `nginx`) va Postgres. Talablar: user-defined tarmoq, baza named volume'da, baza porti publish qilinmagan, ilova faqat `127.0.0.1` da publish qilingan, ikkalasida healthcheck, xotira limiti va `--restart unless-stopped`, ilova bazaga nom bilan ulanadi. `down.sh` volume'ni default saqlaydi, `--purge` argumenti bilan o'chiradi. Ishlashini `curl` va `docker ps` bilan ko'rsating. Bu skript 4-darsda `compose.yaml` ga aylanadi.

22. **Cleanup.** Barcha `l3-` konteyner, volume va tarmoqlarni o'chiring, host papkalaridagi qoldiqlarni (root egaligidagilarni ham) tozalang. `docker ps -a`, `docker volume ls`, `docker network ls`, `docker system df` natijasini yozing va boshqa loyiha resurslari joyida ekanini tasdiqlang.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza, `shellcheck` barcha skriptlar uchun hech narsa chiqarmaydi.
2. `l3-` prefiksli konteyner, volume, tarmoq qolmagan; arxiv va dump fayllar commit qilinmagan.
3. Menga xabar bering, skriptlar va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Volume, bind mount va tmpfs: har birini qachon tanlaysiz?
- Bo'sh named volume va bo'sh host papkasi image'dagi papkaga ulanganda nima farq qiladi?
- Anonim volume qachon paydo bo'ladi va qachon o'chadi?
- Ishlayotgan bazaning volume'ini `tar` qilish nima uchun yomon backup?
- Bind mount'da `Permission denied` qayerdan kelib chiqadi va `chmod 777` nima uchun yechim emas?
- Default bridge va user-defined bridge orasidagi uch farqni ayting.
- Konteyner ichidagi `localhost` nima? Hostdagi servisga qanday yetiladi?
- `-p 8080:80` berilganda paket hostdan konteynergacha qanday yo'l bosadi? Konteynerlar o'zaro qaysi port bilan gaplashadi?
- Healthcheck restart policy'dan nimasi bilan farq qiladi? `unhealthy` konteynerga yolg'iz Docker nima qiladi?
- `--start-period` nima uchun kerak?
