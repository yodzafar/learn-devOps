# 3-dars: Volume va tarmoqlar

Maqsad: konteynerning ikki tashqi bog'lanishini mexanizm darajasida, noldan tushunish: ma'lumot qayerda yashaydi (volume, bind mount, tmpfs) va konteynerlar bir-birini hamda tashqi dunyoni qanday topadi (bridge, DNS, NAT). Dars oxirida healthcheck: "jarayon ishlayapti" bilan "servis javob beryapti" orasidagi farq. 1-darsdagi `-p` va 2-darsdagi yoziladigan layer shu yerda ochiladi; 4-darsdagi Compose shu uch narsani (volumes, networks, healthcheck) YAML'da tavsiflaydi. Frontend ishida ma'lumot bazasi va tarmoq "kimdir sozlab qo'ygan" narsa edi; bu darsdan keyin `docker run postgres` ortida ma'lumot qayerga yozilishini va `localhost:5432` nima uchun ba'zan ishlamasligini o'zingiz tushuntira olasiz.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh (1–7), ikkinchi kun 3-bo'lim va B guruh (8–11), uchinchi kun 4-bo'lim va 12–15-vazifalar, to'rtinchi kun 5–6 bo'limlar, 16–20-vazifalar, beshinchi kun "Birga bajaramiz", 21–22-vazifalar va README. Diqqatni quyidagilarga qarating: volume qachon o'chadi va qachon o'chmaydi, bo'sh volume'ning image mazmuni bilan to'ldirilishi, bind mount'dagi UID muammosi, default bridge'da DNS yo'qligi, konteyner ichidagi `localhost`, publish qilingan port bilan konteyner porti farqi, `unhealthy` konteynerni Docker o'zi qayta ishga tushirmasligi.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. ID, IP manzil, sana va interfeys nomlari sizda boshqacha bo'ladi, bunday joylar `<...>` bilan belgilangan. `docker run -d`, `docker network create` va `docker volume create` chiqaradigan ID yoki nom qatori misollarda tushirib qoldirilgan. Bu dars ikki mashina eng ko'p farq qiladigan dars: har misol va vazifa oldida qayerda bajarilishi (host yoki `lab` VM) yozilgan, shunga rioya qiling.

## Laboratoriya

Docker bu darsda ikki joyda ishlatiladi:

| Joy | Prompt | Nima bajariladi |
|-----|--------|-----------------|
| Host'dagi Docker (Zorin yoki macOS) | `user@host:~$` yoki `%` | volume, user-defined tarmoq, DNS, healthcheck, `localhost` da publish qilingan port: ikkala mashinada bir xil ishlaydigan hamma narsa |
| `lab` VM ichidagi Docker Engine | `ubuntu@lab:~$` | Docker'ning host tomoni ko'rinishi kerak bo'lgan hamma narsa: `/var/lib/docker`, `docker0`, veth, iptables qoidalari, `--network host`, bind mount'dagi UID va egalik |
| Konteyner | `/ #` (alpine) | tarmoq asboblari (`ping`, `nslookup`, `ip`, `wget`): alpine'dagi BusyBox'da tayyor, qo'shimcha o'rnatish kerak emas |

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker Engine host kernel'ida ishlaydi (`amd64`). `lab` uchun yozilgan narsalarni host'da ham ko'rish mumkin (`ip addr show docker0`, `sudo iptables -t nat -S`, faqat o'qiydigan buyruqlar), lekin bu ixtiyoriy: vazifa `lab` da bajariladi, host'ga qoida, paket yoki user qo'shilmaydi. |
| macOS (uy) | Docker Desktop engine'ni yashirin Linux VM ichida ishlatadi (`arm64`). Mac terminalida `/var/lib/docker`, `docker0`, veth, iptables yo'q; konteyner IP'siga host'dan `ping` yoki `curl` qilib bo'lmaydi (faqat publish qilingan port ishlaydi); `--network host` Mac'ning emas, yashirin VM'ning tarmog'ini beradi. Bind mount fayl almashish qatlami orqali o'tadi: faqat ulashilgan yo'llar (default: uy papkangiz osti) ulanadi, fayl egasi va ruxsatlari Linux'dagidek ko'rinmaydi, ko'p faylli papkalar sekinroq. Shuning uchun bu narsalarga tayanadigan vazifalar `lab` da. |

`lab` VM ichidagi Docker `network` modulining 1-darsida o'rnatilgan. Laboratoriya holati mashinalar orasida ko'chmaydi: ikkinchi mashinada (yoki VM qayta yaratilgan bo'lsa) shunday tiklang:

```
multipass shell lab
sudo apt update && sudo apt install -y docker.io    # Docker Engine from the Ubuntu archive
sudo usermod -aG docker ubuntu                      # run docker without sudo
exit                                                # group membership applies on next login
multipass shell lab
docker run --rm hello-world
```

Ubuntu arxivi VM arxitekturasiga mos paketni o'zi tanlaydi (Zorin'da `amd64`, Mac'da `arm64`). VM kichik (2 CPU, 2G RAM, 10G disk): unda bir vaqtda 2–3 tadan ortiq konteyner ushlamang va dars oxirida image'larni ham tozalang (22-vazifa). Host'da yangi asbob o'rnatilmaydi.

Image'lar: `alpine:3.22`, `nginx:1.28-alpine`, `postgres:17-alpine`, misollarda `redis:7-alpine`. Hammasi `amd64` va `arm64` uchun chiqadi.

Ikkala mashinangizda boshqa loyihalarning konteyner va volume'lari bor. Shu darsdagi barcha resurslarni `l3-` prefiksi bilan nomlang va faqat shularni o'chiring:

```
docker ps -a --filter name=l3-
docker volume ls --filter name=l3-
docker network ls --filter name=l3-
docker rm -f $(docker ps -aq --filter name=l3-)
docker volume rm $(docker volume ls -q --filter name=l3-)
docker network rm $(docker network ls -q --filter name=l3-)
```

`docker volume prune -a`, `docker system prune` va `docker rm -f $(docker ps -aq)` bu kursda ishlatilmaydi: ular boshqa loyihalarning resurslarini ham o'chiradi.

---

## 1. Ma'lumot qayerda yashaydi: yoziladigan layer va uch xil mount

### Yoziladigan layer va uning uch kamchiligi

2-darsda ko'rdingiz: image faqat o'qiladigan layer'lar to'plami, konteyner ishga tushganda ularning ustiga bitta yupqa **yoziladigan layer** (writable layer) qo'yiladi. Konteyner ichida yaratilgan yoki o'zgartirilgan har fayl shu layer'ga tushadi. Uning uch kamchiligi bor:

- **Konteyner bilan birga o'chadi.** `docker rm` layer'ni o'chiradi. `docker stop` va `docker start` orasida saqlanadi, lekin yangi image versiyasiga o'tish har doim "eski konteynerni o'chir, yangisini yarat" degani.
- **Sekinroq.** Yozish copy-on-write orqali o'tadi (2-dars): image'dagi faylni o'zgartirish uchun u avval butunligicha yuqori layer'ga nusxalanadi. Baza kabi ko'p yozadigan dastur uchun bu ortiqcha yuk.
- **Bo'lishilmaydi.** Boshqa konteyner bu layer'ni ko'rmaydi.

Shuning uchun saqlanishi kerak bo'lgan har narsa **mount** orqali konteyner fayl tizimidan tashqariga chiqariladi. Mount (`linux` moduli, 13-dars) bu fayl tizimini daraxtdagi biror papkaga ulash; konteynerda u mount namespace ichida bajariladi, ya'ni faqat shu konteyner ko'radi.

### Uch tur

| | Named volume | Bind mount | tmpfs |
|---|--------------|------------|-------|
| Bu nima | Docker boshqaradigan nomli papka | host'dagi siz ko'rsatgan fayl yoki papka | RAM'dagi vaqtinchalik fayl tizimi |
| Qayerda yotadi | `/var/lib/docker/volumes/<nom>/_data` (engine ishlayotgan Linux'da) | host'dagi istalgan yo'l | xotirada, diskka yozilmaydi |
| Kim yaratadi | Docker (`docker volume create` yoki birinchi ishlatishda) | siz, oldindan | Docker, har startda bo'sh holda |
| Konteyner o'chganda | qoladi | qoladi (bu host fayli) | yo'qoladi (to'xtaganda ham) |
| Host yo'liga bog'liqlik | yo'q | bor | yo'q |
| Qachon | baza ma'lumoti, yuklangan fayllar | dev'da manba kodi, config fayl | vaqtinchalik va maxfiy fayllar, `--read-only` bilan |

Mexanizm uchalasida bir xil: konteyner yaratilayotganda Docker uning mount namespace'ida ko'rsatilgan yo'lga boshqa manbani ulaydi. Volume va bind mount texnik jihatdan bitta narsa (host'dagi papka konteyner ichiga ulanadi), farq faqat papkani kim boshqarishida: volume papkasini Docker o'zi yaratadi, nomlaydi, ro'yxatda ko'rsatadi; bind mount'da yo'lni siz berasiz va Docker u haqida hech narsa bilmaydi (`docker volume ls` da ko'rinmaydi).

### Sintaksis

```
docker run -v l3-data:/data ...                              # named volume
docker run -v "$PWD/conf":/etc/app:ro ...                    # bind mount, read-only
docker run --mount type=volume,src=l3-data,dst=/data ...     # explicit form
docker run --mount type=bind,src="$PWD",dst=/app,readonly ...
docker run --tmpfs /tmp:size=64m ...
```

`-v` uch qismdan iborat: `manba:konteynerdagi_yo'l[:opsiyalar]`. Manba `/` yoki `.` bilan boshlansa bind mount, aks holda volume nomi. Manba umuman bo'lmasa (`-v /data`) Docker tasodifiy nomli **anonim volume** yaratadi (2-bo'lim). `--mount` xuddi shu ishni `kalit=qiymat` juftliklari bilan qiladi: uzunroq, lekin tur aniq yozilgan.

**Tuzoq: `-v` mavjud bo'lmagan host yo'lini jimgina papka sifatida yaratadi.** Fayl nomida imlo xatosi qilsangiz, konteyner ichida fayl o'rnida bo'sh papka paydo bo'ladi va dastur tushunarsiz xato beradi. `--mount type=bind` bunday holatda `bind source path does not exist` xatosi bilan to'xtaydi. Shuning uchun skript va hujjatda `--mount` afzal. Buni 5-vazifada o'zingiz ko'rasiz.

### Misol: bind mount, read-only va tmpfs

Host'da (ikkala mashinada bir xil), ish papkangizda:

```
$ mkdir -p site && echo "hello from host" > site/hello.txt
$ docker run --rm -v "$PWD/site":/site:ro alpine:3.22 \
    sh -c 'cat /site/hello.txt; echo changed > /site/hello.txt'
hello from host
sh: can't create /site/hello.txt: Read-only file system
```

Birinchi qator: konteyner host faylini o'qidi, nusxa emas, aynan o'sha fayl. Ikkinchi qator: `:ro` mount'ni faqat o'qish rejimida uladi, yozishga urinishni kernel `Read-only file system` (EROFS) xatosi bilan rad etdi. Bu ruxsat (`rwx`) masalasi emas: root ham yoza olmaydi.

```
$ docker run --rm --read-only --tmpfs /scratch:size=16m alpine:3.22 \
    sh -c 'touch /x; touch /scratch/ok; df -h /scratch'
touch: /x: Read-only file system
Filesystem                Size      Used Available Use% Mounted on
tmpfs                    16.0M         0     16.0M   0% /scratch
```

`--read-only` konteynerning butun root fayl tizimini (yoziladigan layer'ni ham) faqat o'qiladigan qiladi, shuning uchun `touch /x` rad etildi. `/scratch` esa tmpfs: `df` chiqishida `Filesystem` ustunida disk emas `tmpfs`, `Size` biz bergan 16 MB chegara. Unga yozilgan fayl diskka tushmaydi va konteyner to'xtashi bilan yo'qoladi.

### Real ishda qachon kerak

- Baza, navbat, yuklangan fayllar: har doim named volume. Volume'siz baza konteyneri birinchi yangilanishda ma'lumotni yo'qotadi.
- Dev muhitda manba kodi: bind mount, host'dagi tahrir konteynerda darhol ko'rinadi (hot reload shu orqali ishlaydi).
- Config fayl: bind mount `:ro` bilan. Konteyner o'z config'ini o'zgartira olmasligi kerak.
- Production'da `--read-only` va kerakli yo'llarga tmpfs: hujumchi konteyner ichiga kirsa ham fayl tizimiga o'z dasturini yoza olmaydi (6-vazifa).

### Nima uchun shunday

Konteyner ataylab "bir martalik" qilib yaratilgan: image o'zgarmaydi, konteyner istalgan payt o'chirilib o'sha image'dan qayta yaratiladi. Bu faqat holat (state) konteynerdan tashqarida turganda ishlaydi. Shu sababli Docker ma'lumotni alohida obyektga (volume) ajratadi va uning hayot siklini konteynernikidan mustaqil qiladi. Muqobili, ya'ni hamma narsani konteyner ichida saqlab `docker commit` bilan image'ga aylantirish, takrorlanmaydigan va kattalashib boradigan image'larga olib keladi. Bind mount Docker'dan oldin ham bor bo'lgan oddiy Linux imkoniyati (`mount --bind`), volume esa uning ustidagi boshqaruv qatlami: host yo'liga bog'lanmagani uchun bir xil buyruq istalgan serverda ishlaydi.

## 2. Mount image mazmunini yopadi; volume hayot sikli

### Mount ostidagi fayllar ko'rinmay qoladi

Mount nuqtasi bu oddiy papka. Unga biror narsa ulanganda papkaning avvalgi mazmuni o'chmaydi, lekin mount turgan paytda ko'rinmaydi (`linux` 13-dars). Konteynerda bu shuni anglatadi: image'dagi `/app` ichida fayllar bo'lsa va siz `/app` ga biror narsa ulasangiz, image fayllari yopiladi.

Bitta istisno bor: **bo'sh named volume** konteynerga birinchi marta ulanganda Docker image'dagi shu papka mazmunini (egalik va ruxsatlari bilan) volume'ga nusxalaydi. Bu faqat volume bo'sh bo'lganda, faqat bir marta sodir bo'ladi. Bind mount'da bunday nusxalash yo'q.

```
$ docker run --rm alpine:3.22 ls /etc/apk
arch
keys
protected_paths.d
repositories
world
$ docker run --rm -v l3-apk:/etc/apk alpine:3.22 ls /etc/apk
arch
keys
protected_paths.d
repositories
world
$ mkdir empty && docker run --rm -v "$PWD/empty":/etc/apk alpine:3.22 ls /etc/apk
$
```

Birinchi buyruq: image'dagi papka mazmuni. Ikkinchi: bo'sh `l3-apk` volume ulandi, Docker image mazmunini unga nusxaladi, shuning uchun ro'yxat bir xil (endi bu fayllar volume ichida yashaydi va keyingi konteynerlarda ham shu volume'dan o'qiladi). Uchinchi: bo'sh host papkasi ulandi, nusxalash bo'lmadi, image fayllari yopildi, chiqish bo'sh.

### Frontend ishidagi ko'rinishi: `node_modules`

Dev'da manba kodini `-v "$PWD":/app` bilan ulasangiz, image ichida `npm ci` yaratgan `/app/node_modules` ham yopiladi. Host'da `node_modules` yo'q bo'lsa `Cannot find module` chiqadi; bor bo'lsa undan ham yomon: Mac'da o'rnatilgan native modul (masalan `esbuild` binary'si) Linux konteynerida ishlamaydi. Keng tarqalgan yechim ikkinchi, ichkariroq mount:

```
docker run -v "$PWD":/app -v /app/node_modules my-dev-image
```

`-v /app/node_modules` anonim volume: u bo'sh, demak image'dagi `node_modules` unga nusxalanadi va bind mount ustidan ko'rinadi. Aniqroq mount nuqtasi umumiyrog'ining ustiga tushadi.

### Anonim volume va `VOLUME` instruksiyasi

Image muallifi `Dockerfile` da `VOLUME /path` yozishi mumkin. Bu "shu yo'ldagi ma'lumot konteynerdan tashqarida yashashi kerak" degan belgi: `-v` bilan shu yo'lga hech narsa berilmasa, Docker har `docker run` da yangi anonim volume yaratib ulaydi. Image'da bunday yo'l bor-yo'qligini metadata'dan ko'rasiz:

```
$ docker image inspect -f '{{json .Config.Volumes}}' redis:7-alpine
{"/data":{}}
$ docker run -d --name l3-r1 redis:7-alpine
$ docker volume ls
DRIVER    VOLUME NAME
local     <64 belgili hex nom>
$ docker inspect -f '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{"\n"}}{{end}}' l3-r1
volume <64 belgili hex nom> -> /data
```

`Config.Volumes` da `/data` kaliti: image shu yo'lni volume deb e'lon qilgan. `docker volume ls` dagi nomi uzun hex satr bo'lgan qator anonim volume, `DRIVER` ustunidagi `local` uning shu mashina diskida yotishini bildiradi. `docker inspect` dagi `.Mounts` konteynerga nima ulanganining yagona ishonchli manbasi: tur, nom va konteynerdagi yo'l. Tozalash: `docker rm -f -v l3-r1` (`-v` anonim volume'ni ham o'chiradi).

### Hayot sikli

| Harakat | Named volume | Anonim volume |
|---------|--------------|---------------|
| `docker rm <c>` | qoladi | qoladi (yetim bo'lib) |
| `docker rm -v <c>` yoki konteyner `--rm` bilan yaratilgan | qoladi | o'chadi |
| `docker volume prune` | qoladi | ishlatilmayotgani o'chadi |
| `docker volume prune -a` | ishlatilmayotgani **o'chadi** | o'chadi |
| `docker volume rm <v>` | o'chadi (ishlatilayotgan bo'lsa xato) | o'chadi |

"Ishlatilmayotgan" degani hech bir konteynerga (to'xtatilganiga ham) ulanmagan. Yetim (dangling) volume bu egasi o'chirilgan anonim volume: ma'lumot "yo'qolgandek" ko'rinadi, aslida diskda yotadi va joy egallaydi. Kuzatish buyruqlari: `docker volume ls`, `docker volume inspect <nom>`, `docker system df -v`.

**Tuzoq: ma'lumot volume'da yashaydi, konteynerda emas.** Baza konteynerini boshqa volume nomi bilan qayta yaratsangiz bo'sh baza ko'tariladi. Teskarisi ham to'g'ri: ko'p rasmiy baza image'lari faqat bo'sh ma'lumot papkasida boshlang'ich sozlashni (user, parol, baza yaratish) bajaradi; mavjud volume'da environment o'zgaruvchilarini o'zgartirish eski ma'lumotga ta'sir qilmaydi (2-vazifa).

### Real ishda qachon kerak

"Baza yangilangandan keyin bo'sh chiqdi" hodisasining deyarli har doim sababi: volume berilmagan (ma'lumot yetim anonim volume'da) yoki nomi o'zgargan. Birinchi tekshiruv `docker inspect` dagi `.Mounts`. "Disk to'ldi" hodisasida `docker system df -v` yetim volume'larni ko'rsatadi.

### Nima uchun shunday

`VOLUME` instruksiyasi himoya chorasi sifatida kiritilgan: foydalanuvchi `-v` ni unutsa ham baza yoziladigan layer'ga emas, tezroq va konteynerdan mustaqil joyga yozadi. Narxi: har `run` da ko'rinmas volume. Bo'sh volume'ni image mazmuni bilan to'ldirish ham qulaylik uchun: image o'zining boshlang'ich fayllarini (va to'g'ri egalikni) volume'ga o'tkazadi. Bind mount'da bu qilinmaydi, chunki host papkasi sizniki: Docker unga so'ramasdan fayl to'kishi xavfli bo'lardi. `docker volume prune` ning `-a` siz named volume'larga tegmasligi ham shu mantiq: nom berilgan narsa ataylab saqlangan deb hisoblanadi.

## 3. Backup, restore va UID

### Volume backup: yordamchi konteyner

Volume papkasiga host'dan to'g'ridan-to'g'ri kirish yomon yo'l: Linux'da `/var/lib/docker` faqat root'ga ochiq va Docker'ning ichki tuzilishi, macOS'da esa bu yo'l umuman ko'rinmaydi (yashirin VM ichida). Ikkala mashinada ishlaydigan standart usul: volume'ni va host'dagi backup papkasini bir martalik yordamchi konteynerga birga ulab, arxivni konteyner ichida yaratish.

```
$ docker run --rm -v l3-apk:/data:ro -v "$PWD":/backup alpine:3.22 \
    tar czf /backup/l3-apk.tgz -C /data .
$ tar tzf l3-apk.tgz | head -4
./
./arch
./keys/
./protected_paths.d/
```

Birinchi buyruqda ikki mount bor: volume `/data` ga faqat o'qish uchun (`:ro`, backup manbani buzmasligi kerak) va joriy host papkasi `/backup` ga. `tar` ning `-C /data .` qismi "avval `/data` ga o't, keyin undagi hamma narsani arxivla" degani, shuning uchun arxiv ichidagi yo'llar `./` bilan boshlanadi va istalgan joyga ochiladi. `--rm` yordamchi konteynerni ish tugashi bilan o'chiradi. Ikkinchi buyruq host'da arxiv mazmunini ochmasdan ko'rsatadi (`t` list); fayllar tartibi sizda boshqacha bo'lishi mumkin. Restore buning ko'zgusi: yangi volume yoziladigan, backup papkasi `:ro` ulanadi va `tar xzf` arxivni `-C /data` ga ochadi.

**Tuzoq: ishlayotgan bazaning fayllarini `tar` qilish izchil (consistent) backup bermaydi.** Baza bitta tranzaksiyani bir nechta faylga bosqichma-bosqich yozadi; `tar` fayllarni ketma-ket o'qiydi va yarmi eski, yarmi yangi holatni arxivlaydi. Ikki to'g'ri yo'l: konteynerni to'xtatib fayl darajasida arxivlash (fizik backup) yoki bazaning o'z vositasi bilan ishlayotgan holda dump olish (mantiqiy backup: `pg_dump`, `redis-cli --rdb`). Tekshirilmagan backup backup emas: har doim restore qilib ko'ring.

### UID: kernel nomni emas raqamni saqlaydi

`linux` modulining 6 va 10-darslarida ko'rdingiz: fayl egasi diskda raqam (UID/GID) sifatida saqlanadi, `ls -l` dagi nom esa `/etc/passwd` dan o'qib ko'rsatiladi. Konteyner va host bitta kernelda ishlaydi va default sozlamada user namespace ishlatilmaydi, demak konteynerdagi UID 0 host'dagi root'ning o'zi, konteynerdagi UID 1000 host'dagi UID 1000 ning o'zi. Nomlar har tomonning o'z `/etc/passwd` idan olinadi va mos kelmasligi mumkin: bitta raqam host'da `ubuntu`, konteynerda nomsiz bo'ladi.

| Holat | Natija |
|-------|--------|
| Konteyner root, bind mount'ga yozadi | host'da UID 0 egaligidagi fayllar, siz ularni `sudo` siz o'chira olmaysiz |
| Konteyner non-root (image'da o'z UID'i bilan), host papkasi sizniki | konteynerda `Permission denied` |
| `--user "$(id -u):$(id -g)"` | fayllar sizning egaligingizda, lekin bu UID image ichida nomsiz va home papkasiz |

Misol `lab` VM'da (macOS host'ida fayl almashish qatlami egalikni boshqacha ko'rsatadi, natija mos kelmaydi):

```
ubuntu@lab:~$ mkdir -p ~/l3/out && cd ~/l3
ubuntu@lab:~/l3$ docker run --rm -v "$PWD/out":/out alpine:3.22 ls -ldn /out
drwxrwxr-x    2 1000     1000          4096 <sana> /out
ubuntu@lab:~/l3$ docker run --rm --user 1001:1001 -v "$PWD/out":/out alpine:3.22 touch /out/a
touch: /out/a: Permission denied
ubuntu@lab:~/l3$ docker run --rm --user 1001:1001 alpine:3.22 id
uid=1001 gid=1001 groups=1001
```

`ls -ldn` dagi `-n` nom o'rniga raqam ko'rsatadi: papka egasi UID 1000, GID 1000 (VM'dagi `ubuntu`), ruxsat `rwxrwxr-x`, ya'ni "boshqalar" yoza olmaydi. Ikkinchi buyruqda jarayon UID 1001 bilan ishladi: u egasi ham, guruh a'zosi ham emas, kernel yozishni rad etdi. Uchinchi buyruq: `id` da nom yo'q, faqat raqam, chunki alpine'ning `/etc/passwd` ida 1001 yozilmagan. Jarayon baribir ishlaydi: kernel'ga nom kerak emas.

Named volume'da bu kamroq og'riqli: bo'sh volume to'ldirilganda image'dagi papkaning egasi va ruxsatlari ham ko'chiriladi (2-bo'lim). Shuning uchun non-root image'da ma'lumot papkasi `Dockerfile` da to'g'ri egalik bilan oldindan yaratiladi.

**Tuzoq: muammoni `chmod 777` bilan "yechish".** Bu host'dagi barcha foydalanuvchi va jarayonlarga yozish huquqini beradi. To'g'ri yo'l UID'ni moslash: `--user` bilan jarayonni papka egasining UID'ida ishlatish yoki papka egaligini jarayonning aniq UID'iga berish.

### Real ishda qachon kerak

CI'da konteyner build natijasini bind mount'ga yozsa va keyingi qadam uni o'chira olmasa, sabab root egaligi. Server ko'chirishda volume backup va restore asosiy usul. Baza uchun kundalik backup har doim mantiqiy dump, fizik arxiv faqat to'xtatilgan holatda.

### Nima uchun shunday

Kernel'da "konteyner" degan tushuncha yo'q, faqat namespace'lar bor (`network` 5-dars). Mount va PID namespace ajratilgan, user namespace esa default holda ajratilmagan, chunki u bind mount egaligini yanada chalkashtiradi va ba'zi image'larni buzadi. Muqobillari mavjud: rootless Docker va `userns-remap` konteyner UID'larini host'dagi imtiyozsiz diapazonga suradi, lekin sozlash talab qiladi. Xulosa: default Docker'da "konteynerda root" bu "host'da root, faqat namespace va capability cheklovlari bilan" (1-dars).

## 4. Tarmoq: bridge, DNS, host, none

### Driver'lar

Docker tarmog'i bu konteynerlar ulanadigan virtual tarmoq obyekti; **driver** uning qanday amalga oshirilishini belgilaydi.

| Driver | Nima qiladi | Qachon |
|--------|-------------|--------|
| `bridge` | host'da virtual switch, konteynerlar xususiy subnet'da, tashqariga NAT | bitta host'dagi default |
| `host` | konteyner host'ning network namespace'ini ishlatadi | maksimal tarmoq unumdorligi, ko'p portli asboblar |
| `none` | faqat `lo` | tarmoq kerak bo'lmagan batch ishlar, izolyatsiya |
| `overlay` | bir necha host ustidan virtual tarmoq | Swarm (5-dars) |
| `macvlan`, `ipvlan` | konteynerga fizik tarmoqdan manzil | maxsus holatlar |

### Bridge qanday ishlaydi

`network` modulining 1-darsida `lab` ichida ko'rgansiz: Linux bridge bu kernel ichidagi virtual switch, veth esa ikki uchli virtual kabel. Docker har bridge tarmog'i uchun bitta bridge interfeysi yaratadi (default tarmoq uchun `docker0`, odatda `172.17.0.0/16`; user-defined uchun `br-<tarmoq ID>`). Har konteynerga veth juftligi beriladi: bir uchi konteynerning network namespace'ida `eth0` nomi bilan, ikkinchisi host'da `veth<...>` nomi bilan bridge'ga ulangan. Bridge'ning o'z manzili (`172.17.0.1`) konteynerning default gateway'i (`network` 5-dars). Bularning hammasi engine ishlayotgan Linux'da ko'rinadi: `lab` da va Zorin host'ida, macOS terminalida emas.

```
ubuntu@lab:~$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
<id>           bridge    bridge    local
<id>           host      host      local
<id>           none      null      local
ubuntu@lab:~$ docker network inspect -f '{{json .IPAM.Config}}' bridge
[{"Subnet":"172.17.0.0/16","Gateway":"172.17.0.1"}]
```

Docker o'rnatilishi bilan uchta tarmoq mavjud: `bridge` (default, `--network` berilmagan konteynerlar shu yerga tushadi), `host` va `none`. `SCOPE` ustunidagi `local` tarmoq faqat shu mashinada ekanini bildiradi. `IPAM` (IP address management) qismi subnet va gateway'ni ko'rsatadi; sizda subnet boshqa bo'lishi mumkin.

### Default bridge va user-defined bridge

| | Default `bridge` | User-defined (`docker network create`) |
|---|------------------|----------------------------------------|
| Nom bo'yicha DNS | yo'q, faqat IP | bor: konteyner nomi va `--network-alias` |
| `/etc/resolv.conf` | host'dan olingan DNS serverlar | `nameserver 127.0.0.11` (Docker embedded DNS) |
| Izolyatsiya | `--network` berilmagan barcha konteynerlar shu yerda | faqat ulangan konteynerlar bir-birini ko'radi |
| Ishlayotgan konteynerni ulash | qayta yaratish kerak | `docker network connect` / `disconnect` |

**Embedded DNS** bu Docker daemon'ining ichidagi kichik DNS server (`network` 4-dars: DNS nomni IP'ga aylantiradi). User-defined tarmoqdagi konteynerda `/etc/resolv.conf` `127.0.0.11` ni ko'rsatadi; Docker shu manzilga kelgan so'rovlarni konteyner namespace'i ichida ushlab o'ziga yo'naltiradi. Tarmoqdagi konteyner nomi yoki alias so'ralsa joriy IP'ni qaytaradi, boshqa nomlarni host'ning DNS serveriga uzatadi. Host'da (ikkala mashinada bir xil):

```
$ docker network create l3-demo-net
$ docker run -d --name l3-cache --network l3-demo-net redis:7-alpine
$ docker run --rm --network l3-demo-net alpine:3.22 ping -c 1 l3-cache
PING l3-cache (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=<N> ms
...
$ docker run --rm alpine:3.22 ping -c 1 l3-cache
ping: bad address 'l3-cache'
```

Birinchi `ping` konteyneri `l3-demo-net` da: `PING l3-cache (172.18.0.2)` qatori nom IP'ga yechilganini ko'rsatadi (IP sizda boshqa bo'lishi mumkin), ikkinchi qator javob keldi degani. Oxirgi buyruqda `--network` yo'q, konteyner default bridge'ga tushdi: u yerda embedded DNS yo'q va boshqa tarmoqqa yo'l ham yo'q, `bad address` nom yechilmaganini bildiradi.

Qoida: default bridge'ni ishlatmang, har ilova uchun o'z tarmog'ini yarating (Compose buni avtomatik qiladi, 4-dars). Konteyner qayta yaratilganda IP o'zgarishi mumkin, shuning uchun konfiguratsiyada har doim nom yoziladi. Bitta konteyner bir necha tarmoqqa ulanishi mumkin: masalan, proxy `frontend` va `backend` tarmoqlarida, baza faqat `backend` da.

**Tuzoq: konteyner ichidagi `localhost` bu konteynerning o'zi.** Har konteynerning o'z network namespace'i va o'z `lo` interfeysi bor. Ilova `localhost:5432` ga ulansa o'z namespace'idagi portni qidiradi, host yoki qo'shni konteynerni emas. Node'da `.env` dagi `DATABASE_URL=postgres://localhost:5432/...` konteynerga ko'chirilganda aynan shu sababdan `ECONNREFUSED` beradi. Qo'shni konteynerga nomi bilan (`db:5432`), host'dagi servisga `host.docker.internal` nomi orqali murojaat qilinadi: Docker Desktop'da bu nom tayyor, Linux'dagi Docker Engine'da `--add-host=host.docker.internal:host-gateway` bilan qo'shiladi.

### host va none

`--network host`: konteynerga alohida network namespace yaratilmaydi, u host'ning interfeyslari va portlarini to'g'ridan-to'g'ri ishlatadi. `-p` ma'nosiz bo'lib qoladi (Docker ogohlantirish chiqaradi), port to'qnashuvi host'dagi kabi, tarmoq izolyatsiyasi yo'q. macOS'da "host" bu yashirin VM, shuning uchun bu rejim `lab` da sinaladi. `--network none`: namespace bor, lekin ichida faqat loopback; tashqi so'rov ham, DNS ham ishlamaydi.

### Real ishda qachon kerak

"Ilova bazaga ulana olmayapti" tekshiruvi tartibi: ikkalasi bitta user-defined tarmoqdami (`docker network inspect <tarmoq>` dagi `Containers`), ilova nom bilan ulanyaptimi (`localhost` yoki IP emas), port konteyner portimi. Tarmoqlarga ajratish xavfsizlik chorasi ham: internetga qaragan proxy bazani umuman ko'rmasligi mumkin.

### Nima uchun shunday

Default bridge Docker'ning eng birinchi tarmoq modeli; unda nomlar eskirgan `--link` flag'i bilan bog'lanar edi. User-defined tarmoqlar va embedded DNS keyinroq qo'shilgan, default bridge esa eski skriptlar buzilmasligi uchun avvalgi xulqida qoldirilgan. DNS'ning daemon ichida bo'lishi sababi: konteynerlar har soniyada paydo bo'lib yo'qoladi, `/etc/hosts` fayllarini hamma konteynerda yangilab chiqishdan ko'ra bitta markaziy jadvaldan javob berish ishonchliroq.

## 5. Port publishing va NAT

### Ikki yo'nalish

Bridge subnet'i xususiy (`network` 3-dars): tashqi tarmoq u haqida bilmaydi. Shuning uchun ikki yo'nalishda NAT (`network` 6-dars: paket manzilini yo'lda almashtirish) ishlaydi.

| Yo'nalish | Mexanizm | Qoida |
|-----------|----------|-------|
| Konteyner -> tashqariga | source NAT | `nat` jadvali, `POSTROUTING` zanjirida `MASQUERADE`: manba manzil host IP'siga almashadi |
| Tashqaridan -> konteynerga (`-p`) | destination NAT | `nat` jadvali, `DOCKER` zanjirida `DNAT`: `host:port` manzili `konteyner_IP:port` ga almashadi |

`lab` da (qoidalar engine ishlayotgan Linux'da yashaydi; buyruq faqat o'qiydi):

```
ubuntu@lab:~$ docker run -d --name l3-pub -p 8090:80 nginx:1.28-alpine
ubuntu@lab:~$ sudo iptables -t nat -S | grep -E 'MASQUERADE|8090'
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A DOCKER ! -i docker0 -p tcp -m tcp --dport 8090 -j DNAT --to-destination 172.17.0.2:80
ubuntu@lab:~$ docker port l3-pub
80/tcp -> 0.0.0.0:8090
80/tcp -> [::]:8090
```

Birinchi qoida: manbasi `172.17.0.0/16` bo'lgan va `docker0` dan boshqa interfeysga chiqayotgan (`! -o docker0`) paketning manba manzili host manziliga almashtiriladi. Ikkinchisi: `docker0` dan boshqa interfeysdan kelgan, TCP 8090-portga mo'ljallangan paketning manzili `172.17.0.2:80` ga almashtiriladi. `docker port` shu moslikni Docker tilida ko'rsatadi: konteynerning 80-porti host'ning barcha IPv4 (`0.0.0.0`) va IPv6 (`[::]`) manzillarida 8090 da. Qoidalarning aniq ko'rinishi Docker versiyasiga qarab biroz farq qilishi mumkin, `grep` boshqa tarmoqlarning `MASQUERADE` qatorlarini ham chiqarishi mumkin. Tozalash: `docker rm -f l3-pub`.

Qo'shimcha ravishda har publish qilingan port uchun host'da `docker-proxy` jarayoni tinglaydi (userland proxy): u DNAT qoidasi qamramaydigan holatlarni, masalan host'ning o'zidan `localhost` orqali murojaatni bajaradi. Shuning uchun `sudo ss -tlnp` da portni `docker-proxy` ushlab turgani ko'rinadi.

### `-p 8080:80` va `-p 127.0.0.1:8080:80`

To'liq shakl `-p [host_IP:]host_port:konteyner_port`. Host IP berilmasa Docker `0.0.0.0` ga, ya'ni mashinaning barcha interfeyslariga bog'laydi: port Wi-Fi va ofis tarmog'idagi har kimga ochiq bo'ladi. `127.0.0.1` berilsa faqat shu mashinaning o'zidan yetiladi. Bu frontend'dan ma'lum: dev server `127.0.0.1` da tinglasa faqat siz ko'rasiz, `0.0.0.0` da tinglasa (Vite'da `--host`) telefondan ham ochiladi. Linux'da `0.0.0.0` ga publish qilingan port `ufw` qoidalarini ham chetlab o'tadi: DNAT paketni `ufw` tekshiradigan `INPUT` zanjiriga yetmasdan `FORWARD` yo'liga buradi (`network` 6-dars, 1-darsdagi tuzoqning sababi).

Xuddi shu farq konteyner ichida ham bor: DNAT paketni konteynerning `eth0` manziliga yetkazadi. Ichkaridagi dastur faqat `127.0.0.1` da tinglasa (ko'p dev serverlarning default'i), `-p` to'g'ri bo'lsa ham ulanish rad etiladi. Konteyner ichida servis `0.0.0.0` da tinglashi kerak.

Oqibatlar:

- Konteynerlar bir-biriga **konteyner porti** bilan murojaat qiladi (`db:5432`). `-p` faqat tarmoq tashqarisidan kirish uchun, tarmoq ichidagi aloqaga kerak emas.
- Baza portini publish qilmaslik eng oddiy himoya.
- `EXPOSE` hech qanday qoida yaratmaydi, u faqat metadata (2-dars).
- macOS'da `localhost:8090` ishlaydi, lekin u iptables bilan emas, Docker Desktop'ning yashirin VM'ga port uzatishi bilan ta'minlanadi.

### Real ishda qachon kerak

Serverda "nima uchun baza internetdan ko'rinib qoldi" savolining javobi deyarli har doim `-p 5432:5432`. Tekshiruv: `docker ps` ning `PORTS` ustuni (`0.0.0.0:...` yoki `127.0.0.1:...`) va `docker port <c>`.

### Nima uchun shunday

IPv4 manzillar yetishmaydi, har konteynerga tashqi manzil berib bo'lmaydi; shuning uchun uy routeri qilgan ishni (`network` 6-dars) Docker bitta host ichida takrorlaydi. Muqobili `host` tarmog'i (NAT yo'q, izolyatsiya ham yo'q) yoki har konteynerga route qilinadigan manzil (Kubernetes modeli, keyingi modul). `0.0.0.0` default bo'lgani tarixiy qulaylik: "ishga tushirdim, ochildi". Xavfsiz odat: har doim `127.0.0.1:` ni aniq yozish, tashqariga faqat reverse proxy orqali chiqish.

## 6. Healthcheck

### Jarayon tirik, servis-chi?

Docker default holda faqat PID 1 tirikligini biladi. Deadlock'ga tushgan, bazaga ulana olmayotgan yoki hali yuklanayotgan ilova `running` ko'rinadi. **Healthcheck** bu konteyner **ichida** Docker davriy bajaradigan buyruq: exit code 0 sog'lom, 1 nosog'lom.

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

`docker run` da ham beriladi: `--health-cmd`, `--health-interval`, `--health-timeout`, `--health-retries`, `--health-start-period`; o'chirish `--no-healthcheck`.

### Holatlar

Uch holat bor: `starting` (birinchi muvaffaqiyatli tekshiruvgacha), `healthy`, `unhealthy` (`retries` marta ketma-ket xato). Host'da:

```
$ docker run -d --name l3-hc --health-cmd 'test -f /tmp/ok' \
    --health-interval 5s --health-retries 2 alpine:3.22 sleep 600
$ docker ps --filter name=l3-hc --format '{{.Names}}: {{.Status}}'
l3-hc: Up 3 seconds (health: starting)
$ docker ps --filter name=l3-hc --format '{{.Names}}: {{.Status}}'
l3-hc: Up 14 seconds (unhealthy)
$ docker inspect -f '{{.State.Health.Status}} {{.State.Health.FailingStreak}}' l3-hc
unhealthy <N>
$ docker exec l3-hc touch /tmp/ok
$ docker ps --filter name=l3-hc --format '{{.Names}}: {{.Status}}'
l3-hc: Up 30 seconds (healthy)
```

Tekshiruv buyrug'i `test -f /tmp/ok`: fayl bo'lsa 0, bo'lmasa 1 qaytaradi. Boshida fayl yo'q: holat `starting`, ikki xato tekshiruvdan keyin (taxminan 10 soniya) `unhealthy`. `FailingStreak` ketma-ket xatolar soni. E'tibor bering: konteyner `Up` holatida qoldi, `sleep` ishlayapti, Docker uni qayta ishga tushirmadi. Faylni yaratgach keyingi tekshiruv 0 qaytardi va holat `healthy` bo'ldi. `docker inspect -f '{{json .State.Health}}' l3-hc` oxirgi tekshiruvlarning `ExitCode` va `Output` maydonlarini ham beradi: healthcheck ishlamasa sababi shu yerda yozilgan. Tozalash: `docker rm -f l3-hc`.

Tekshiruv asbobi image ichida bo'lishi kerak: alpine'da BusyBox `wget` bor, `curl` yo'q; distroless'da (2-dars) hech biri yo'q, tekshiruvni ilova binary'sining o'zi bajaradi. Ko'p bazalarda tayyor buyruq bor (Redis'da `redis-cli ping`).

**Tuzoq: Docker `unhealthy` konteynerni qayta ishga tushirmaydi.** Restart policy (1-dars) faqat PID 1 tugaganda ishlaydi. Yolg'iz Docker Engine'da `unhealthy` faqat holat belgisi va `docker events` dagi hodisa. Unga boshqalar tayanadi: Compose'dagi `depends_on: condition: service_healthy` (4-dars) va Swarm, u nosog'lom task'ni almashtiradi (5-dars).

### Real ishda qachon kerak

Ilova bazadan oldin ko'tarilib yiqilmasligi uchun (4-dars), deploy paytida yangi versiya haqiqatan javob berayotganini bilish uchun. Yaxshi `/healthz`: tez, arzon, tashqi servislarga zanjir bo'lib bog'lanmagan. Agar har servisning healthcheck'i bazani tekshirsa, baza bir lahza sekinlashganda barcha servislar bir vaqtda `unhealthy` bo'ladi.

### Nima uchun shunday

Docker Engine ataylab qaror qabul qilmaydi: nosog'lom konteynerni o'ldirish to'g'rimi yoki yo'qmi, bu ilovaga bog'liq (o'ldirish debug imkonini ham yo'qotadi). Engine faqat faktni e'lon qiladi, siyosatni orkestrator belgilaydi. Kubernetes shu g'oyani uchta alohida probe'ga ajratgan (keyingi modul). `--start-period` sekin yuklanadigan ilova (migratsiya, kesh isitish) hali ko'tarilmasidan `unhealthy` deb belgilanmasligi uchun kerak.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Yoziladigan layer (writable layer) | Image layer'lari ustidagi, faqat shu konteynerga tegishli va u bilan birga o'chadigan yupqa qatlam. |
| Mount | Fayl tizimi yoki papkani konteyner daraxtidagi biror yo'lga ulash. |
| Named volume | Docker yaratadigan va boshqaradigan, nomi bor, konteynerdan mustaqil yashaydigan ma'lumot papkasi. |
| Anonim volume | Nomsiz (tasodifiy hex nomli) volume; `-v /path` yoki image'dagi `VOLUME` tufayli paydo bo'ladi. |
| Yetim (dangling) volume | Hech bir konteynerga ulanmagan volume. |
| Bind mount | Host'dagi aniq fayl yoki papkani konteyner ichiga ulash. |
| tmpfs | RAM'da yashaydigan, diskka yozilmaydigan vaqtinchalik fayl tizimi. |
| Pre-population | Bo'sh named volume birinchi ulanishda image'dagi papka mazmuni bilan to'ldirilishi. |
| Fizik backup | Ma'lumot fayllarining o'zini nusxalash; faqat to'xtatilgan bazada izchil. |
| Mantiqiy backup | Bazaning o'z vositasi chiqargan dump (`pg_dump`); ishlayotgan bazada xavfsiz. |
| UID/GID | Kernel fayl egasi va jarayon egasini belgilaydigan raqamlar; nom faqat `/etc/passwd` dagi yorliq. |
| Bridge tarmoq | Host'dagi virtual switch orqali konteynerlarni xususiy subnet'da bog'laydigan tarmoq. |
| User-defined bridge | `docker network create` bilan yaratilgan, ichida nom bo'yicha DNS ishlaydigan bridge tarmoq. |
| Embedded DNS | Docker daemon'idagi, konteyner ichida `127.0.0.11` da ko'rinadigan DNS server. |
| Network alias | Konteynerga shu tarmoq ichida berilgan qo'shimcha DNS nomi. |
| veth juftligi | Ikki uchli virtual kabel: bir uchi konteynerda `eth0`, ikkinchisi host'da bridge'ga ulangan. |
| Port publishing | Host portiga kelgan ulanishni konteyner portiga yo'naltirish (`-p`). |
| DNAT / MASQUERADE | Paketning manzil (kiruvchi) yoki manba (chiquvchi) IP'sini almashtiradigan NAT qoidalari. |
| `docker-proxy` | Publish qilingan portni host'da tinglab, konteynerga uzatadigan yordamchi jarayon. |
| Healthcheck | Konteyner ichida davriy bajarilib, servis javob berayotganini tekshiradigan buyruq. |
| `start-period` | Konteyner startidan keyingi, xato tekshiruvlar hisobga olinmaydigan davr. |

## Tuzoqlar

- Baza ma'lumotini volume'siz saqlash: `docker rm` yoki `compose down` dan keyin ma'lumot yo'q (yoki yetim anonim volume'da).
- `docker volume prune -a` va `docker system prune --volumes`: ishlatilmayotgan (konteyneri o'chirilgan) named volume'lar ham o'chadi. Qaytarib bo'lmaydi.
- Ishlayotgan bazani fayl darajasida nusxalash: backup bor, lekin restore'da baza ochilmaydi.
- Bind mount bilan image mazmunini yopib qo'yish (`node_modules`, build natijasi) va "nima uchun image'dagi kod ishlamayapti" deb qidirish.
- `-v` dagi imlo xatosi: fayl o'rnida bo'sh papka.
- Host papkasiga `chmod 777`: UID nomuvofiqligi yashiriladi, xavfsizlik teshigi ochiladi.
- Default bridge'da nom bilan ulanishga urinish, keyin IP'ni config'ga yozib qo'yish: konteyner qayta yaratilganda IP o'zgaradi.
- Konteynerda `localhost` ga ulanish: host yoki qo'shni konteyner emas, o'zi.
- Konteyner ichida servis `127.0.0.1` da tinglaydi: `-p` to'g'ri, lekin ulanish yo'q.
- `-p 5432:5432`: baza barcha interfeyslarda ochiq, Linux'da `ufw` ham to'smaydi. Qo'shni konteynerga `-p` umuman kerak emas.
- macOS'da konteyner IP'siga host'dan `ping` qilish, `docker0` ni yoki `/var/lib/docker` ni qidirish: ular yashirin VM ichida. `lab` ga o'ting.
- Healthcheck'da image ichida yo'q asbob (`curl`): konteyner abadiy `unhealthy`, sababi `State.Health.Log` da yozilgan.
- `--start-period` siz sekin yuklanadigan ilova: orkestrator uni hali ko'tarilmasidan almashtiradi va cheksiz restart sikli boshlanadi.

## Manbalar

- https://docs.docker.com/engine/storage/ – volume, bind mount, tmpfs umumiy ko'rinishi
- https://docs.docker.com/engine/storage/volumes/ – volume'lar, backup va restore
- https://docs.docker.com/engine/storage/bind-mounts/ – bind mount, `-v` bilan `--mount` farqi
- https://docs.docker.com/engine/storage/tmpfs/ – tmpfs mount
- https://docs.docker.com/engine/network/ – tarmoq umumiy ko'rinishi, embedded DNS
- https://docs.docker.com/engine/network/drivers/bridge/ – default va user-defined bridge farqlari
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – iptables qoidalari, port publishing
- https://docs.docker.com/desktop/features/networking/ – Docker Desktop tarmog'i (macOS'dagi cheklovlar, `host.docker.internal`)
- https://docs.docker.com/reference/dockerfile/#healthcheck – `HEALTHCHECK` instruksiyasi
- https://hub.docker.com/_/postgres – rasmiy Postgres image hujjati (`PGDATA`, initsializatsiya, env)
- https://man7.org/linux/man-pages/man4/veth.4.html – `man 4 veth`
- https://man7.org/linux/man-pages/man5/tmpfs.5.html – `man 5 tmpfs`
- Kane, Matthias, "Docker: Up & Running", tarmoq va storage boblari

---

## Birga bajaramiz

Bitta yaxlit misol: Redis (xotiradagi kalit-qiymat bazasi) ni ma'lumoti saqlanadigan, nom bilan topiladigan, sog'ligi tekshiriladigan va tashqariga ochilmagan holda ko'taramiz. Hammasi host'da, ikkala mashinada bir xil ishlaydi.

1. Tarmoq va volume yarating, keyin konteynerni ishga tushiring:

```
$ docker network create l3-walk-net
$ docker volume create l3-walk-data
$ docker run -d --name l3-walk-redis --network l3-walk-net -v l3-walk-data:/data \
    --health-cmd 'redis-cli ping' --health-interval 5s --health-retries 3 redis:7-alpine
```

`-p` yo'q: bu bazaga faqat shu tarmoqdagi konteynerlar yetadi. `-v l3-walk-data:/data` image `VOLUME` deb e'lon qilgan yo'lga nomli volume beradi, demak anonim volume yaratilmaydi.

2. Nima ulangani va holatni tekshiring:

```
$ docker inspect -f '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{end}}' l3-walk-redis
volume l3-walk-data -> /data
$ docker inspect -f '{{.State.Health.Status}}' l3-walk-redis
healthy
$ docker port l3-walk-redis
$
```

Mount turi `volume`, nomi biz bergan. Holat bir necha soniyada `starting` dan `healthy` ga o'tadi: `redis-cli ping` konteyner ichida `PONG` olib 0 qaytardi. `docker port` bo'sh: host'da hech qanday port ochilmagan.

3. Boshqa konteynerdan nom bilan ulaning:

```
$ docker run --rm --network l3-walk-net redis:7-alpine redis-cli -h l3-walk-redis incr visits
1
$ docker run --rm --network l3-walk-net redis:7-alpine redis-cli -h l3-walk-redis incr visits
2
$ docker run --rm redis:7-alpine redis-cli -h l3-walk-redis incr visits
Could not connect to Redis at l3-walk-redis:6379: <DNS xatosi matni>
```

Mijoz konteyneri `l3-walk-redis` nomini embedded DNS orqali IP'ga yechdi va konteyner porti 6379 ga ulandi; `incr` hisoblagichni oshirib yangi qiymatni qaytardi. Uchinchi buyruqda `--network` yo'q: default bridge'da nom yechilmaydi, ulanish bo'lmadi.

4. Ma'lumotni diskka yozdiring va konteynerni o'chiring:

```
$ docker exec l3-walk-redis redis-cli save
OK
$ docker rm -f l3-walk-redis
$ docker volume ls --filter name=l3-walk
DRIVER    VOLUME NAME
local     l3-walk-data
```

Redis ma'lumotni xotirada ushlaydi va diskka vaqti-vaqti bilan yozadi; `save` uni hozir `/data/dump.rdb` ga yozdiradi (`rm -f` jarayonni SIGKILL bilan o'ldiradi, u xayrlashib ulgurmaydi). Konteyner o'chdi, named volume qoldi.

5. Xuddi shu volume ustida yangi konteyner yarating (1-qadamdagi `docker run` ni aynan takrorlang) va qiymatni o'qing:

```
$ docker run --rm --network l3-walk-net redis:7-alpine redis-cli -h l3-walk-redis get visits
2
```

Konteyner yangi (IP'si ham boshqa bo'lishi mumkin), nom va ma'lumot o'sha: mijoz hech narsani o'zgartirmadi.

6. Fizik backup: avval to'xtating, keyin yordamchi konteyner bilan arxivlang:

```
$ docker stop l3-walk-redis
$ docker run --rm -v l3-walk-data:/data:ro -v "$PWD":/backup alpine:3.22 \
    tar czf /backup/l3-walk.tgz -C /data .
$ tar tzf l3-walk.tgz
./
./dump.rdb
```

To'xtatilgan bazaning fayllari o'zgarmaydi, arxiv izchil. Ichida bitta fayl: Redis'ning dump'i.

7. Tozalang:

```
$ docker rm -f l3-walk-redis l3-cache
$ docker volume rm l3-walk-data l3-apk
$ docker network rm l3-walk-net l3-demo-net
$ rm -r l3-walk.tgz l3-apk.tgz site empty
```

Ikkinchi nomlar (`l3-cache`, `l3-apk`, `l3-demo-net`, `site`, `empty`) nazariya misollaridan qolgan; bajarmagan bo'lsangiz "No such ..." xabarini e'tiborsiz qoldiring.

Shu 7 qadamda ko'rganingiz: ma'lumot konteynerda emas volume'da yashaydi va konteyner almashganda saqlanadi (1 va 2-bo'limlar), `VOLUME` e'lon qilingan yo'lga nom berish anonim volume'ning oldini oladi (2-bo'lim), fizik backup to'xtatilgan holatda yordamchi konteyner bilan olinadi (3-bo'lim), user-defined tarmoqda konteynerlar bir-birini nom va konteyner porti bilan topadi, default bridge'da topa olmaydi (4-bo'lim), `-p` siz baza tashqariga ochilmaydi (5-bo'lim), healthcheck servis haqiqatan javob berayotganini ko'rsatadi (6-bo'lim).

---

## Vazifalar

Ish papkasi: `docker/03-volumes-networks/` (`make new m=docker n=03 name=volumes-networks` bilan host'da yarating). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh, qayerda bajarilgani (host yoki `lab`) ko'rsatilgan holda. Vazifa so'ragan fayllar (skript, config) shu papkada saqlanadi. Barcha resurs nomlari `l3-` bilan boshlansin.

Har vazifa oxirida "Qayerda" yozilgan. **host**: o'zingiz o'tirgan mashinadagi Docker (Zorin yoki macOS), bind mount qilinadigan papkalar ish papkangiz ichida bo'lsin. **`lab`**: `multipass shell lab` ichidagi Docker Engine, fayllar `~/l3/` da; bunday vazifa matnidagi "host" so'zi `lab` VM'ni anglatadi (Docker Engine shu yerda ishlaydi), natijani README'ga qo'lda ko'chirasiz. `sudo` faqat `lab` da va faqat vazifa aytgan joyda ishlatiladi. Zorin'da `lab` vazifalarini qo'shimcha ravishda host'da ham kuzatish mumkin (faqat o'qiydigan buyruqlar), bu ixtiyoriy.

### A. Volume va mount

1. **Writable layer is ephemeral.** `postgres:17-alpine` ni volume'siz ishga tushiring, jadval yaratib qator qo'shing, konteynerni `rm -f` qilib qayta yarating. Ma'lumot qani? `docker volume ls` da nima paydo bo'lganini toping va `docker image inspect -f '{{json .Config.Volumes}}' postgres:17-alpine` orqali sababini tushuntiring. Qayerda: host. Yo'nalish: 2-bo'lim, "Anonim volume va `VOLUME` instruksiyasi".

2. **Named volume.** Xuddi shuni `l3-pgdata` named volume bilan takrorlang: konteynerni o'chirib qayta yaratgandan keyin ma'lumot saqlanganini ko'rsating. `docker volume inspect l3-pgdata` dan `Mountpoint` ni yozing. Keyin shu volume ustida konteynerni boshqa `POSTGRES_PASSWORD` bilan yarating: qaysi parol ishlaydi va nima uchun? Qayerda: host. macOS'da `Mountpoint` yashirin VM ichidagi yo'l: Mac terminalida `ls` bilan ochib ko'ring va natijani izohlang. Yo'nalish: 2-bo'lim, "Hayot sikli".

3. **Volume pre-population.** Bo'sh `l3-html` volume'ni `nginx:1.28-alpine` ning `/usr/share/nginx/html` iga ulang va ichini ko'ring. Keyin bo'sh host papkasini xuddi shu yo'lga bind mount qiling. Ikki holatda `ls` va `curl` natijasini solishtiring va farqni izohlang. Qayerda: host. `curl` uchun portni `127.0.0.1` da publish qiling. Yo'nalish: 2-bo'lim, "Mount ostidagi fayllar ko'rinmay qoladi".

4. **Bind mount config.** O'zingiz yozgan `default.conf` (bitta `location /` matn qaytaradi) ni nginx'ga `:ro` bilan bind mount qiling. Konteyner ichidan faylga yozishga urinib xatoni yozing. Hostda faylni o'zgartiring: nginx nima uchun darhol yangi config'ni ishlatmaydi va uni qayta yaratmasdan qanday qo'llaysiz? Qayerda: host. Yo'nalish: 1-bo'lim, "Misol: bind mount, read-only va tmpfs".

5. **-v vs --mount.** Mavjud bo'lmagan host yo'lini avval `-v`, keyin `--mount type=bind` bilan ulang. Har birida nima sodir bo'ldi? `-v` yaratgan narsaning egasi kim (`ls -ld`) va uni qanday o'chirasiz? Qayerda: `lab` (macOS host'ida egalik fayl almashish qatlami tufayli boshqacha ko'rinadi). Yo'nalish: 1-bo'lim, "Sintaksis".

6. **tmpfs and read-only.** nginx'ni `--read-only` bilan ishga tushiring, xatoni loglardan o'qing. Kerakli yo'llarni `--tmpfs` bilan berib ishlating. Konteyner ichida `df -h` yoki `mount` bilan tmpfs'ni ko'rsating. Read-only root fayl tizimi hujumchi uchun nimani qiyinlashtiradi? Qayerda: host. Yo'nalish: 1-bo'lim, "Misol: bind mount, read-only va tmpfs".

7. **Volume lifecycle.** Uch konteyner yarating: anonim volume bilan (`-v /data`), named volume bilan, anonim volume va `--rm` bilan. Har birini to'xtatib o'chiring va `docker volume ls` da nima qolganini yozing. Yetim volume'larni `docker volume ls -f dangling=true` bilan toping va faqat o'zingiznikini nomi (ID'si) bilan o'chiring. `docker volume prune` ni ishga tushirib ogohlantirish matnini o'qing va `N` deb javob bering: u nimani o'chirgan bo'lar edi va `-a` bilan nima qo'shiladi? Qayerda: host. Yo'nalish: 2-bo'lim, "Hayot sikli".

### B. Backup va ruxsatlar

8. **Backup and restore.** `backup.sh <volume> <file.tgz>` va `restore.sh <file.tgz> <volume>` skriptlarini yozing (vaqtinchalik `alpine` konteyner bilan). `l3-pgdata` ni to'xtatilgan baza holatida arxivlang, `l3-pgdata-restored` ga tiklang va yangi Postgres konteynerida ma'lumot borligini ko'rsating. `shellcheck` toza bo'lsin. Arxivni commit qilmang. Qayerda: host. Skriptlar Zorin'da ham, macOS'da ham o'zgarishsiz ishlashi kerak. Yo'nalish: 3-bo'lim, "Volume backup: yordamchi konteyner".

9. **Logical backup.** Ishlayotgan bazadan `docker exec ... pg_dump` bilan dump oling (hostdagi faylga) va toza volume'li yangi konteynerga `psql` orqali tiklang. 8-vazifadagi usul bilan solishtiring: qaysi biri ishlayotgan bazada xavfsiz va nima uchun, qaysi biri tezroq tiklanadi? Qayerda: host. Yo'nalish: 3-bo'lim, "Volume backup: yordamchi konteyner" dagi tuzoq.

10. **Root-owned files.** `alpine:3.22` da bind mount qilingan papkaga fayl yarating, hostda `ls -ln` bilan egasini ko'ring va `sudo` siz o'chirishga urining. Keyin `--user "$(id -u):$(id -g)"` bilan takrorlang. Konteyner ichida `id` va `whoami` nima deydi va nima uchun? Qayerda: `lab`, `~/l3` ichida. Yo'nalish: 3-bo'lim, "UID: kernel nomni emas raqamni saqlaydi".

11. **Permission denied.** Bo'sh host papkasini `postgres:17-alpine` ning data papkasiga bind mount qilib `--user 12345:12345` bilan ishga tushiring, xatoni o'qing. Postgres jarayoni image'da qaysi UID bilan ishlashini aniqlang. Muammoni `chmod 777` siz yechishning ikki yo'lini yozing va bittasini bajaring. Oxirida host papkasini tozalang. Qayerda: `lab`, `~/l3` ichida. Yo'nalish: 3-bo'lim, "UID: kernel nomni emas raqamni saqlaydi".

### C. Tarmoq

12. **Default bridge.** `--network` siz ikkita `alpine:3.22` konteyner ishga tushiring. Bir-birini nom bilan va IP bilan `ping` qiling. `/etc/resolv.conf`, `ip addr`, `ip route` ni yozing. Hostda `ip addr show docker0` va `docker network inspect bridge` dan subnet va gateway'ni toping. Qayerda: `lab` (konteynerlar ham, `docker0` ham). Ixtiyoriy: macOS host'ida default bridge'dagi konteynerning `/etc/resolv.conf` ini `lab` dagisi bilan solishtiring. Yo'nalish: 4-bo'lim, "Bridge qanday ishlaydi" va "Default bridge va user-defined bridge".

13. **User-defined bridge DNS.** `l3-net` tarmog'ini yarating, ikkita konteynerni ulang, biriga `--network-alias db` bering. Nom va alias bilan `ping`, `nslookup` qiling, `/etc/resolv.conf` ni 12-vazifadagi bilan solishtiring. Konteynerlardan birini o'chirib qayta yarating: IP o'zgardimi, nom-chi? Qayerda: host. Yo'nalish: 4-bo'lim, "Default bridge va user-defined bridge".

14. **Network isolation.** `l3-front` va `l3-back` tarmoqlarini yarating. `web` ikkalasida, `db` faqat `l3-back` da, `client` faqat `l3-front` da bo'lsin. Kim kimni ko'rishini `ping` bilan jadvalga yozing. `docker network connect` bilan `client` ni `l3-back` ga ulab natija qanday o'zgarganini ko'rsating. Qayerda: host. Yo'nalish: 4-bo'lim, "Default bridge va user-defined bridge".

15. **veth pairs.** Bitta konteyner uchun ichkaridagi `eth0` va hostdagi mos veth interfeysini toping (konteynerda `cat /sys/class/net/eth0/iflink`, hostda `ip link` chiqishidagi shu indeksli interfeys). Hostda `bridge link` yoki `ip link show master <bridge>` bilan u qaysi bridge'ga ulanganini ko'rsating. Qayerda: `lab`. Yo'nalish: 4-bo'lim, "Bridge qanday ishlaydi"; `network` moduli, 1-dars.

16. **localhost trap.** Hostda `python3 -m http.server 8000 --bind 0.0.0.0` ni ishga tushiring. Konteyner ichidan `wget -qO- http://localhost:8000` qiling, xatoni izohlang. Keyin `--add-host=host.docker.internal:host-gateway` bilan hostga yeting. `/etc/hosts` da nima paydo bo'ldi? Ulanish timeout bersa `sudo ufw status` ni ko'ring va sababini izohlang (qoida qo'shmang). Oxirida serverni to'xtating. Qayerda: `lab` (`python3` VM'da tayyor, `ufw` ham VM'niki). Ixtiyoriy, macOS'da: Docker Desktop'da `host.docker.internal` `--add-host` siz ham ishlashini tekshiring. Yo'nalish: 4-bo'lim, "Tuzoq: konteyner ichidagi `localhost`".

17. **host and none.** nginx'ni `--network host` bilan (hostda 80-port bo'sh bo'lsa) yoki `alpine` ni `--network host` bilan ishga tushirib `ip addr` ni host bilan solishtiring; `-p` qo'shilganda chiqadigan ogohlantirishni yozing. `--network none` da `ip addr` va tashqi `ping` natijasini ko'rsating. Qayerda: `lab`. Yo'nalish: 4-bo'lim, "host va none".

18. **NAT rules.** nginx'ni `l3-net` da `-p 127.0.0.1:8085:80` bilan ishga tushiring. `sudo iptables -t nat -S | grep -E "DOCKER|MASQUERADE"` dan shu portga tegishli `DNAT` qoidasini va tarmoq subnet'i uchun `MASQUERADE` qoidasini toping, har birini bir gapda izohlang. `ss -tlnp | grep 8085` da portni kim tinglayapti? Shu tarmoqdagi boshqa konteynerdan nginx'ga qaysi port bilan murojaat qilinadi: 80 yoki 8085, va nima uchun? Qayerda: `lab` (`l3-net` ni u yerda ham yarating; `ss` jarayon nomini ko'rsatishi uchun `sudo` bilan ishlating). Yo'nalish: 5-bo'lim, "Ikki yo'nalish".

### D. Healthcheck

19. **Healthcheck states.** nginx'ni `--health-cmd`, `--health-interval 5s`, `--health-retries 2` bilan ishga tushiring (tekshiruv: `wget` bilan `127.0.0.1`). `starting` dan `healthy` ga o'tishni kuzating. Keyin `docker exec` bilan `index.html` ni o'chirib yoki nginx config'ni buzib `unhealthy` qiling. `docker inspect -f '{{json .State.Health}}'` dagi logni o'qing. Konteyner qayta ishga tushdimi? `docker events --filter event=health_status` nimani ko'rsatadi? Qayerda: host. Yo'nalish: 6-bo'lim, "Holatlar".

20. **Broken healthcheck.** `postgres:17-alpine` ni `--health-cmd "curl -f http://localhost:5432"` bilan ishga tushiring. Holat nima va `State.Health.Log` da qaysi xato? To'g'ri tekshiruvga (`pg_isready`) almashtiring. Nima uchun TCP port ochiqligi "baza tayyor" degani emas? Qayerda: host. Yo'nalish: 6-bo'lim, "Holatlar".

### E. Yakuniy

21. **Two-tier app by hand.** Compose'siz, faqat `docker` buyruqlari bilan (`up.sh` va `down.sh` skriptlari): 2-darsdagi Node yoki Go image'ingiz (yoki `nginx`) va Postgres. Talablar: user-defined tarmoq, baza named volume'da, baza porti publish qilinmagan, ilova faqat `127.0.0.1` da publish qilingan, ikkalasida healthcheck, xotira limiti va `--restart unless-stopped`, ilova bazaga nom bilan ulanadi. `down.sh` volume'ni default saqlaydi, `--purge` argumenti bilan o'chiradi. Ishlashini `curl` va `docker ps` bilan ko'rsating. Bu skript 4-darsda `compose.yaml` ga aylanadi. Qayerda: host. Skriptlar ikkala mashinada o'zgarishsiz ishlashi kerak. Yo'nalish: butun dars va "Birga bajaramiz".

22. **Cleanup.** Barcha `l3-` konteyner, volume va tarmoqlarni o'chiring, host papkalaridagi qoldiqlarni (root egaligidagilarni ham) tozalang. `docker ps -a`, `docker volume ls`, `docker network ls`, `docker system df` natijasini yozing va boshqa loyiha resurslari joyida ekanini tasdiqlang. Qayerda: host va `lab`. `lab` da `~/l3` papkasini va shu darsda tortilgan image'larni ham o'chirib diskni bo'shating (`docker image ls`, `df -h /`). Yo'nalish: "Laboratoriya" bo'limi.

### Topshirish

Tayyor bo'lgach:
1. `docker/03-volumes-networks/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida; har javobda host yoki `lab` da bajarilgani ko'rinadi.
2. Ish papkasida `default.conf` (4), `backup.sh` va `restore.sh` (8), `up.sh` va `down.sh` (21) bor.
3. `make check` toza (host'da), `shellcheck` barcha skriptlar uchun hech narsa chiqarmaydi.
4. Host'da ham, `lab` da ham `l3-` prefiksli konteyner, volume, tarmoq qolmagan; boshqa loyihalar resurslari joyida; `lab` VM o'chirilmagan.
5. Arxiv (`*.tgz`) va dump fayllar, parollar commit qilinmagan.
6. Menga xabar bering, skriptlar va `README.md` ni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Yoziladigan layer'da saqlangan ma'lumotga `docker stop`, `docker rm` va image yangilanishida nima bo'ladi?
- Volume, bind mount va tmpfs: har birini qachon tanlaysiz?
- Bo'sh named volume va bo'sh host papkasi image'dagi papkaga ulanganda nima farq qiladi? `node_modules` muammosi shunga qanday bog'liq?
- Anonim volume qachon paydo bo'ladi va qachon o'chadi?
- Ishlayotgan bazaning volume'ini `tar` qilish nima uchun yomon backup? Fizik va mantiqiy backup farqi nima?
- Bind mount'da `Permission denied` qayerdan kelib chiqadi va `chmod 777` nima uchun yechim emas?
- Default bridge va user-defined bridge orasidagi uch farqni ayting. `127.0.0.11` nima?
- Konteyner ichidagi `localhost` nima? Host'dagi servisga qanday yetiladi?
- `-p 8080:80` berilganda paket host'dan konteynergacha qanday yo'l bosadi? `-p 127.0.0.1:8080:80` dan farqi nima? Konteynerlar o'zaro qaysi port bilan gaplashadi?
- Bu darsdagi qaysi narsalar macOS terminalida ko'rinmaydi va nima uchun? Ularni qayerda kuzatasiz?
- Healthcheck restart policy'dan nimasi bilan farq qiladi? `unhealthy` konteynerga yolg'iz Docker nima qiladi?
- `--start-period` nima uchun kerak?
