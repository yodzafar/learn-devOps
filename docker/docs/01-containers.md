# 1-dars: Konteynerlar

Maqsad: konteyner nima ekanini kernel darajasida tushunish (namespaces, cgroups, alohida root fayl tizimi) va uni VM dan ajrata bilish, Docker'ning ichki zanjirini (CLI, dockerd, containerd, shim, runc) bilish, konteyner hayot siklini buyruqlar bilan boshqarish va ishlamayotgan konteynerni diagnostika qilish. Bu dars linux modulidagi jarayonlar va signallar (linux 9), systemd va cgroup (linux 11) hamda network modulidagi namespace va NAT (network 5, 6) bilimlarini bitta joyga yig'adi. Keyingi darslar (image, volume, tarmoq, Compose) shu darsdagi `run` flag'lari va `inspect` ustiga quriladi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruhi, ikkinchi kun 3–4 bo'limlar va B guruhi, uchinchi kun 5-bo'lim va C guruhi, to'rtinchi kun 6–7 bo'limlar, "Birga bajaramiz", D va E guruhlari. Diqqatni mexanizmga qarating: konteyner bu oddiy Linux jarayoni ekani, PID 1 va signal qoidasi, exit code'larni o'qish (137, 143), `-p` ning barcha interfeyslarga ochishi, limit qo'yilmagan konteyner xavfi, restart policy'lar farqi, `inspect --format`.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi ID, PID, port va versiyalar farq qiladi, darsda bunday joylar `<...>` bilan belgilangan. Har misol qayerda bajarilishi prompt'dan ko'rinadi: `$` host, `ubuntu@lab:~$` VM. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsda Docker ikki joyda ishlatiladi:

| Joy | Prompt | Nima bajariladi |
|-----|--------|-----------------|
| Host'dagi Docker (Zorin yoki macOS) | `$` | oddiy `docker` CLI ishi: `run`, `ps`, `logs`, `exec`, `stop`, `inspect`, publish qilingan port `localhost` da. Ikkala mashinada bir xil. Vazifalar 6–10, 12–15, 18–22 |
| `lab` VM ichidagi Docker | `ubuntu@lab:~$` | engine ishlayotgan mashinaning ichki tomoniga qaraydigan hamma narsa: `ps` da konteyner jarayoni, `/proc/<PID>/ns`, `/sys/fs/cgroup`, `ss`, `journalctl -k`. Vazifalar 1–5, 11, 16, 17 |

Sabab: macOS'da Docker Desktop engine'ni yashirin Linux VM ichida ishlatadi, shuning uchun Mac'dagi `ps`, `/proc`, `/sys/fs/cgroup`, `/var/lib/docker` konteynerlarni ko'rsatmaydi. `lab` VM (Ubuntu 24.04, `SETUP.md`) ikkala mashinada bir xil, shuning uchun "engine tomoni" vazifalari o'sha yerda. Bunday vazifalardagi "host" so'zi engine ishlayotgan mashinani, ya'ni `lab` VM'ni bildiradi.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker Engine to'g'ridan-to'g'ri host kernel'ida, `amd64`. Konteyner jarayonlari host `ps` da ko'rinadi, shuning uchun VM vazifalarini ixtiyoriy ravishda host'da ham kuzatish mumkin (majburiy emas). Konteyner ichidagi `uname -r` Zorin kernel'ini ko'rsatadi. |
| macOS (uy) | Docker Desktop, `arm64`. Konteyner ichidagi `uname -r` yashirin VM kernel'ini (`<versiya>-linuxkit`) ko'rsatadi. Mac'da `ss`, `/proc`, `journalctl` yo'q; `.State.Pid` va `.LogPath` Mac'dagi emas, yashirin VM ichidagi qiymat. Publish qilingan port Mac'ga iptables bilan emas, Docker Desktop'ning o'z proxy'si orqali yetkaziladi. |

Host'da tekshirish (Docker `SETUP.md` bo'yicha o'rnatilgan: Zorin'da Docker Engine, macOS'da Docker Desktop; bu darsda host'ga hech narsa o'rnatilmaydi):

```
docker version
docker info | grep -E "Cgroup|Storage Driver|Default Runtime|Operating System"
```

`lab` VM'da Docker'ni tiklash. Uni network moduli o'rnatgan; laboratoriya holati mashinalar orasida ko'chmaydi, shuning uchun ikkinchi mashinada yoki yangi VM'da qayta bajaring:

```
multipass shell lab
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker ubuntu     # then: exit, and enter the VM again
docker info | grep -E "Cgroup|Default Runtime"
```

Kutiladigan natija VM'da: `Cgroup Driver: systemd`, `Cgroup Version: 2`, `Default Runtime: runc`. `usermod -aG` foydalanuvchini `docker` guruhiga qo'shadi (linux 10), guruh yangi login'dan keyin kuchga kiradi. VM kichik: 2 CPU, 2G RAM, 10G disk. VM'dagi Docker host'dagidan butunlay alohida: o'z image'lari va o'z konteynerlari bor, image'lar u yerda qayta `pull` qilinadi.

Dars `nginx:1.28-alpine`, `alpine:3.22` va `postgres:17-alpine` image'laridan foydalanadi, uchalasi `amd64` va `arm64` uchun chiqadi. Ikkala mashinada boshqa loyihalarning konteyner va volume'lari bor, shuning uchun shu darsdagi har konteynerni `--label lesson=01` bilan yarating va faqat shularni o'chiring. `docker container prune`, `docker system prune`, `docker rm -f $(docker ps -aq)` bu modulda ishlatilmaydi.

Tozalash (dars oxirida, host'da va VM'da alohida):

```
docker ps -a --filter label=lesson=01                     # review first
docker rm -f $(docker ps -aq --filter label=lesson=01)
docker image rm nginx:1.28-alpine alpine:3.22             # only if no other project uses them
```

---

## 1. Konteyner nima

### Uchta mexanizm

Konteyner alohida "yengil VM" emas. Bu host kernel'ida ishlayotgan oddiy Linux jarayoni (yoki jarayonlar guruhi), unga kernel uchta narsani qo'llagan:

| Mexanizm | Nima beradi | Savol |
|----------|-------------|-------|
| namespaces | izolyatsiya | jarayon nimani **ko'ra oladi** |
| cgroups | resurs limiti va hisobi | jarayon qancha **ishlata oladi** |
| alohida root fayl tizimi (image) | o'z `/` daraxti | jarayon qaysi **fayllarni ko'radi** (2-dars) |

Kernel bitta va umumiy (linux 1): konteynerda o'z kernel'i yo'q, uning jarayonlari system call'larni to'g'ridan-to'g'ri host kernel'iga qiladi. Bunga xavfsizlik qatlamlari qo'shiladi: capabilities (root huquqlarining bo'laklarga ajratilgan to'plami, linux 10; Docker ularning ko'pini olib tashlaydi), seccomp (jarayonga ruxsat etilgan system call'lar ro'yxati) va AppArmor (dastur qaysi fayl va amallarga yeta olishini cheklaydigan kernel moduli).

### Namespaces: mexanizm

Namespace bu kernel resursining alohida nusxasi yoki ko'rinishi; har jarayon har turdan bittasiga tegishli (network 5 da `net` turi bilan ishlagansiz). Jarayon yaratilganda ota jarayonning namespace'larini meros oladi. `unshare` va `clone` system call'lari jarayonni yangi namespace'ga ko'chiradi; runtime (2-bo'lim) konteyner uchun aynan shuni qiladi.

| Namespace | Ajratadi | Konteynerdagi natija |
|-----------|----------|----------------------|
| `pid` | jarayon ID'lari | ilova PID 1, host jarayonlari ko'rinmaydi |
| `net` | interfeyslar, routing, portlar, firewall qoidalari | o'z `eth0` va `lo`, o'z port maydoni |
| `mnt` | mount nuqtalari | o'z `/` (image'dan) |
| `uts` | hostname | hostname konteyner ID'si |
| `ipc` | shared memory, semaphore | boshqa konteyner bilan IPC yo'q |
| `user` | UID/GID mapping | Docker'da default yoqilmagan: konteyner root'i host'dagi root (UID 0) |
| `cgroup` | cgroup daraxti ko'rinishi | konteyner o'z cgroup'ini `/` deb ko'radi |

Jarayonning namespace'lari `/proc/<PID>/ns/` da symlink sifatida turadi:

```
ubuntu@lab:~$ ls -l /proc/$$/ns/ | grep -E 'pid ->|net|uts'
lrwxrwxrwx 1 ubuntu ubuntu 0 <sana> net -> 'net:[<N>]'
lrwxrwxrwx 1 ubuntu ubuntu 0 <sana> pid -> 'pid:[<N>]'
lrwxrwxrwx 1 ubuntu ubuntu 0 <sana> uts -> 'uts:[<N>]'
```

`$$` hozirgi shell PID'i. Har qator: tur nomi va kvadrat qavsda namespace'ning raqami (inode raqami, odatda `4026531840` atrofidagi son). Qoida: ikki jarayonda shu raqam bir xil bo'lsa, ular o'sha turdagi bitta namespace'da; farq qilsa, alohida. Boshqa foydalanuvchi jarayonining `ns` papkasini o'qish uchun `sudo` kerak. Tizimdagi barcha namespace'lar ro'yxati: `sudo lsns` (faqat o'qiydi).

### Misol: Docker'siz namespace

Namespace Docker'ning emas, kernel'ning imkoniyati. `unshare` buyrug'i (util-linux paketi) dasturni yangi namespace'da ishga tushiradi:

```
ubuntu@lab:~$ sudo unshare --uts sh -c 'hostname demo; hostname'
demo
ubuntu@lab:~$ hostname
lab
ubuntu@lab:~$ sudo unshare --pid --fork --mount-proc ps -ef
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 <vaqt> pts/0    00:00:00 ps -ef
```

Birinchi buyruq yangi `uts` namespace'da hostname'ni `demo` ga o'zgartirdi; ikkinchi qator VM'ning o'z hostname'i o'zgarmaganini ko'rsatadi. Uchinchi buyruq yangi `pid` namespace yaratdi (`--fork` yangi namespace'da bola jarayon ochadi, `--mount-proc` unga mos yangi `/proc` ulaydi): `ps -ef` faqat o'zini ko'radi va uning PID'i 1, `PPID` 0, ya'ni bu namespace ichida otasi ko'rinmaydi. VM'dagi yuzlab jarayon shu namespace'dan ko'rinmaydi, lekin VM tomonidan bu `ps` oddiy, katta PID'li jarayon edi. Konteynerdagi jarayonning ikki xil PID'i shundan.

**Tuzoq: konteyner root'i bu host root'i.** User namespace default yoqilmagan. Konteyner ichidagi UID 0 host'da ham UID 0, faqat capabilities va seccomp bilan cheklangan. `--privileged` yoki `/var/run/docker.sock` ni konteynerga mount qilish bu cheklovni amalda olib tashlaydi.

### cgroups: mexanizm

cgroup (control group, linux 11) jarayonlar guruhiga CPU, xotira, jarayon soni, I/O bo'yicha limit qo'yadi va sarfni hisoblaydi. cgroup v2 da bu `/sys/fs/cgroup` ostidagi yagona papkalar daraxti: har papka bitta guruh, ichidagi fayllar orqali limit yoziladi va sarf o'qiladi. Jarayon qaysi guruhda ekani `/proc/<PID>/cgroup` da. Docker systemd driver bilan ishlasa (VM'da va Zorin'da), har konteyner o'z scope'iga tushadi (scope bu systemd tashqaridan ishga tushirilgan jarayonlar uchun ochadigan cgroup, linux 11):

```
/sys/fs/cgroup/system.slice/docker-<full-container-id>.scope/
    memory.max      # --memory
    cpu.max         # --cpus
    pids.max        # --pids-limit
    memory.current  # current usage, bytes
```

Konteyner ichidan xuddi shu fayllar `/sys/fs/cgroup/` ning o'zida ko'rinadi (`cgroup` namespace tufayli). Limit qo'yilmasa `memory.max` qiymati `max`, ya'ni konteyner engine ishlayotgan mashinaning butun xotirasini yeyishi mumkin. Limitlar va fayl formatlari 6-bo'limda, jonli misol "Birga bajaramiz" da.

### Konteyner va VM

| | Konteyner | VM |
|---|-----------|----|
| Kernel | host kernel'i, umumiy | o'z kernel'i |
| Izolyatsiya | kernel mexanizmlari (namespaces) | hypervisor (VM'larni ishlatadigan dastur), apparat virtualizatsiyasi |
| Ishga tushish | millisekundlar (jarayon start) | sekundlar, OS boot |
| Hajm | megabaytlar | gigabaytlar |
| Hujum yuzasi | butun kernel syscall interfeysi | hypervisor interfeysi (torroq) |
| Boshqa OS | faqat Linux user space | istalgan OS |

Konteyner ichida `uname -r` image qaysi distributiv bo'lishidan qat'i nazar o'zi ishlayotgan kernel'ni ko'rsatadi: `lab` VM'da VM kernel'ini, Zorin'da Zorin kernel'ini, macOS'da Docker Desktop VM'ining `linuxkit` kernel'ini (Mac kernel'i Linux emas, Linux jarayonini ishlata olmaydi).

### Real ishda qachon kerak

- "Konteynerda ishlayapti, serverda `ps` da ko'rinmayapti" degan gap noto'g'ri: ko'rinadi, faqat PID boshqa. Serverda yuqori CPU yeyayotgan jarayon qaysi konteynerniki ekanini `/proc/<PID>/cgroup` aytadi.
- Xavfsizlik bahosi: konteyner ichidagi root va host root orasida faqat capabilities va seccomp turadi, shuning uchun ilova non-root ishlatiladi (2-dars).
- Cloud'da odatda ikkalasi birga: VM kuchli chegara, ichida konteynerlar zich joylashadi.

### Nima uchun shunday

Namespace'lar kernel'ga 2002-yildan (`mnt`) boshlab bittadan qo'shilgan, cgroups 2007-yilda Google muhandislari tomonidan kiritilgan. Docker (2013) yangi kernel mexanizmi ixtiro qilmadi: mavjudlarini image formati va qulay CLI bilan bitta asbobga yig'di. Kernel'da "konteyner" degan obyekt yo'q, bu faqat shu mexanizmlar birikmasining nomi. Muqobili VM: izolyatsiya kuchliroq, lekin har nusxa o'z kernel'i va xotirasini talab qiladi. Oraliq yechimlar (gVisor, Kata Containers) bu modulda faqat tilga olinadi.

## 2. Docker arxitekturasi

### Zanjir

```
docker (CLI)  --HTTP API-->  dockerd  --gRPC-->  containerd  -->  containerd-shim-runc-v2  -->  runc  -->  your process
              /var/run/docker.sock
```

| Komponent | Vazifasi |
|-----------|----------|
| `docker` CLI | buyruqni HTTP so'rovga aylantiradi, o'zi hech narsa ishga tushirmaydi |
| `dockerd` | daemon (fonda doimiy ishlaydigan servis jarayoni): API, build, network, volume, restart policy mantig'i |
| `containerd` | image pull va saqlash, konteyner hayot sikli. Kubernetes ham to'g'ridan-to'g'ri shuni ishlatadi |
| `containerd-shim-runc-v2` | har konteynerga bitta. Konteyner jarayonining ota jarayoni, stdout/stderr va exit code'ni ushlab turadi |
| `runc` | OCI runtime: namespace va cgroup'larni yaratadi, jarayonni `exec` qiladi va o'zi chiqib ketadi |

gRPC bu servislar orasidagi so'rov-javob protokoli. OCI (Open Container Initiative) ikki standartni belgilaydi: image formati va runtime spetsifikatsiyasi. Shuning uchun Docker bilan qurilgan image Podman, containerd, Kubernetes'da ham ishlaydi.

### Misol: CLI faqat HTTP klient

`/var/run/docker.sock` bu Unix socket: tarmoq porti o'rniga fayl orqali ishlaydigan, faqat shu mashina ichidagi aloqa kanali. VM'da:

```
ubuntu@lab:~$ ls -l /var/run/docker.sock
srw-rw---- 1 root docker 0 <sana> /var/run/docker.sock
ubuntu@lab:~$ curl -s --unix-socket /var/run/docker.sock http://localhost/_ping; echo
OK
ubuntu@lab:~$ ps -e -o pid,ppid,comm | grep -E 'dockerd|containerd'
  <PID>       1 containerd
  <PID>       1 dockerd
```

Birinchi qatorda `s` fayl turi socket; egasi `root`, guruhi `docker`, ruxsat `rw-rw----`: faqat root va `docker` guruhi a'zolari yoza oladi (shuning uchun `usermod -aG docker` kerak bo'ldi). `curl` `docker` buyrug'isiz daemon'ning `/_ping` manziliga HTTP so'rov yubordi va `OK` oldi: CLI qiladigan ish shu. Oxirgi buyruq ikki daemon'ni ko'rsatadi, ikkalasining otasi PID 1 (`systemd`), ya'ni ular alohida systemd servislari. Konteyner ishga tushganda har biriga bittadan shim jarayoni qo'shiladi (1-vazifa).

`docker version` ikki qism chiqaradi: `Client:` (CLI) va `Server:` (daemon), har birida `Version` va `OS/Arch`. macOS'da client `darwin/arm64`, server esa `linux/arm64`: CLI Mac'da, daemon yashirin VM'da va ular socket orqali gaplashadi.

**Tuzoq: `docker` guruhi root'ga teng.** Socket'ga yoza oladigan har kim `docker run -v /:/host` bilan engine mashinasining butun fayl tizimini root sifatida o'qiy va yoza oladi. Serverda bu guruhga kim kirganini `sudo` guruhidek nazorat qiling.

### Real ishda qachon kerak

- `Cannot connect to the Docker daemon` xatosi: CLI bor, daemon ishlamayapti yoki socket'ga ruxsat yo'q. Qaysi qism buzilganini zanjir aytadi.
- Kubernetes node'larida `dockerd` yo'q, faqat `containerd` va shim'lar bor; jarayonlar daraxti tanish ko'rinadi.
- CI agentga `docker.sock` ni berish unga root berish degani.

### Nima uchun shunday

Dastlab Docker bitta katta daemon edi va uni qayta ishga tushirish barcha konteynerlarni o'ldirar edi. Keyin u qatlamlarga bo'lindi: `runc` va `containerd` alohida loyihalarga chiqarildi, OCI standarti (2015) esa runtime'ni almashtirish imkonini berdi. Shim borligi uchun `dockerd` va `containerd` ni konteynerlarni o'ldirmasdan qayta ishga tushirish arxitektura jihatidan mumkin (buning uchun daemon'da `live-restore` yoqilgan bo'lishi kerak, default o'chiq). Muqobili daemon'siz model: Podman har konteynerni to'g'ridan-to'g'ri CLI'dan ishga tushiradi.

## 3. Ishga tushirish: docker run

### To'rt qadam

`docker run` aslida to'rt qadam: image lokal bo'lmasa `pull`, `create`, `start` va (fonda bo'lmasa) `attach`, ya'ni terminalingizni konteyner jarayonining stdin/stdout/stderr'iga ulash.

```
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

```
$ docker run --rm --label lesson=01 alpine:3.22 cat /etc/alpine-release
Unable to find image 'alpine:3.22' locally
3.22: Pulling from library/alpine
<hash>: Pull complete
Digest: sha256:<...>
Status: Downloaded newer image for alpine:3.22
3.22.<N>
```

Birinchi qator: image lokal topilmadi. `3.22: Pulling from library/alpine`: tag `3.22`, `library/` Docker Hub'dagi rasmiy image'lar nomlar maydoni. `Pull complete` har layer uchun bitta qator (2-dars). `Digest` image tarkibining hash'i; `package-lock.json` dagi `integrity` kabi, aynan qaysi baytlar olinganini aniqlaydi (2-dars). Oxirgi qator konteyner jarayonining (`cat`) stdout'i. `cat` tugadi, demak konteyner ham tugadi, `--rm` uni o'chirdi. Ikkinchi marta ishga tushirsangiz faqat oxirgi qator chiqadi.

| Flag | Ma'nosi |
|------|---------|
| `-d` | detached: fonda ishlaydi, terminalga faqat ID chop etiladi |
| `-i` | konteyner jarayonining stdin'i ochiq qoladi (aks holda u yopiq va o'qigan dastur darhol EOF oladi) |
| `-t` | pseudo-TTY ajratadi (linux 1): dastur o'zini terminalda deb biladi, prompt va rang chiqaradi, `Ctrl+C` signalga aylanadi |
| `--rm` | konteyner to'xtagach avtomatik o'chiriladi (anonim volume'lari bilan) |
| `--name web` | nom. Berilmasa tasodifiy (`quirky_morse`) |
| `-p 8080:80` | port publishing, `HOST:CONTAINER` |
| `-e KEY=val`, `--env-file f` | environment o'zgaruvchilari |
| `--label k=v` | metadata, `--filter label=k=v` bilan tanlash uchun |

`-it` interaktiv shell uchun (`docker run --rm -it alpine:3.22 sh`), `-d` servis uchun. `-t` ni pipe yoki skript ichida ishlatmang: TTY chiqishga `\r` qo'shadi va stdout bilan stderr'ni birlashtiradi. `COMMAND` berilsa image'dagi `CMD` ni almashtiradi (`ENTRYPOINT` bilan farqi 2-darsda).

### Port publishing

Konteyner o'z `net` namespace'ida, uning 80-porti tashqaridan to'g'ridan-to'g'ri ko'rinmaydi. `-p` engine mashinasidagi portni konteyner portiga yo'naltiradi. Linux'da mexanizm NAT qoidalari (network 6; Docker'dagi tafsiloti 3-darsda), macOS'da bundan tashqari Docker Desktop Mac'dagi portni yashirin VM'ga uzatadi.

| Yozuv | Natija |
|-------|--------|
| `-p 8080:80` | **barcha** interfeyslarda 8080 |
| `-p 127.0.0.1:8080:80` | faqat localhost |
| `-p 80` | host porti tasodifiy, `docker port <name>` bilan ko'ring |
| `-P` | image'dagi barcha `EXPOSE` portlar tasodifiy host portlariga |

```
$ docker run -d --name l1-web --label lesson=01 -P nginx:1.28-alpine
<id>
$ docker port l1-web
80/tcp -> 0.0.0.0:<port>
80/tcp -> [::]:<port>
$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:<port>
200
$ docker rm -f l1-web
```

`docker port` qatori: chapda konteyner porti va protokol, o'ngda host manzili. `0.0.0.0` barcha IPv4 interfeyslar, `[::]` barcha IPv6 interfeyslar, `<port>` Docker tanlagan bo'sh port (odatda 32768 dan yuqori). `curl` HTTP status kodini chop etdi: `200`, nginx javob berdi.

**Tuzoq: `-p 8080:80` barcha interfeyslarga ochadi va `ufw` ni chetlab o'tadi.** Linux'da Docker o'z qoidalarini `ufw` qoidalaridan oldin ishlaydigan zanjirlarga yozadi; `ufw deny 8080` bo'lsa ham port tashqaridan ochiq qoladi. Faqat lokal kerak bo'lsa har doim `127.0.0.1:` yozing. Ma'lumotlar bazasi portini shu tarzda internetga ochib qo'yish eng ko'p uchraydigan xato.

### Environment

`-e NAME=value` yoki `--env-file app.env` (har qatorda `KEY=value`, qo'shtirnoqlar qiymatning bir qismi bo'lib qoladi). `-e NAME` (qiymatsiz) shell'dagi qiymatni uzatadi.

```
$ docker run --rm --label lesson=01 -e APP_MODE=dev alpine:3.22 env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=<id>
APP_MODE=dev
HOME=/root
```

`PATH` image'dan keladi, `HOSTNAME` ni Docker qo'yadi (konteyner ID'sining boshi, `uts` namespace), `APP_MODE` sizniki, `HOME` foydalanuvchiga (root) qarab qo'yiladi. Host shell'ingizdagi o'zgaruvchilar bu yerda yo'q: konteyner ularni meros olmaydi. Environment `docker inspect` da ochiq ko'rinadi va bola jarayonlarga meros o'tadi, shuning uchun parol uchun yaxshi joy emas (secrets 4 va 5-darslarda).

### Real ishda qachon kerak

- Lokal ishda baza yoki Redis'ni bitta buyruq bilan ko'tarish: `-d`, `--name`, `-p 127.0.0.1:...`, `-e`.
- CI'da bir martalik buyruq: `--rm`, `-t` siz.
- `docker run` satri uzayib ketsa, u `compose.yaml` ga ko'chiriladi (4-dars); flag'lar o'sha yerda kalitlarga aylanadi.

### Nima uchun shunday

Default holatda hech narsa ochiq emas: port publish qilinmaydi, host env uzatilmaydi, fayllar ulanmaydi. Har ulanish aniq flag bilan yoziladi, shuning uchun buyruq satri konteynerning tashqi dunyo bilan to'liq shartnomasi bo'ladi va boshqa mashinada bir xil natija beradi. Konfiguratsiyani env orqali berish "bitta image, har muhitda boshqa sozlama" tamoyilidan keladi (Twelve-Factor App); muqobili har muhit uchun alohida image qurish, bu sekin va xatoga moyil.

## 4. Hayot sikli va holatlar

### Holatlar

```
create -> created --start--> running --stop/exit--> exited --rm--> (gone)
                               |  ^
                         pause |  | unpause
                               v  |
                              paused
```

| Holat | Ma'nosi |
|-------|---------|
| `created` | yaratilgan, hali start bo'lmagan |
| `running` | PID 1 ishlayapti |
| `paused` | jarayonlar cgroup freezer bilan muzlatilgan (CPU berilmaydi, xotira saqlanadi) |
| `restarting` | restart policy qayta ishga tushirmoqda |
| `exited` | PID 1 tugagan, fayl tizimi va loglar saqlanib turibdi |
| `dead` | o'chirish yarim yo'lda qolgan, resurs band |

Asosiy qoida: **konteyner PID 1 jarayoni yashagan vaqtgacha yashaydi.** PID 1 tugasa konteyner `exited` bo'ladi, namespace'dagi boshqa jarayonlar o'ldiriladi. Shuning uchun servis foreground'da ishlashi kerak (`nginx -g 'daemon off;'`); fonga o'tib ketadigan (daemonize) jarayon konteynerni darhol tugatadi. `pm2` yoki systemd bu yerda kerak emas: jarayonni kuzatish Docker'ning ishi.

| Buyruq | Vazifa |
|--------|--------|
| `docker ps` / `docker ps -a` | ishlayotgan / barcha konteynerlar |
| `docker stop <c>` | `SIGTERM`, 10 sekund kutadi, keyin `SIGKILL` (`-t N` kutish vaqtini o'zgartiradi) |
| `docker kill <c>` | darhol `SIGKILL` (`-s` bilan boshqa signal) |
| `docker start <c>` | `exited` konteynerni o'sha fayl tizimi bilan qayta boshlaydi |
| `docker rm <c>` | o'chiradi. `-f` ishlayotganini ham (`SIGKILL`) |
| `docker pause` / `unpause` | muzlatish |

### Misol: ps -a ni o'qish

```
$ docker run -d --name l1-a --label lesson=01 alpine:3.22 sleep 600
$ docker run --name l1-b --label lesson=01 alpine:3.22 false
$ docker ps -a --filter label=lesson=01
CONTAINER ID   IMAGE         COMMAND       CREATED          STATUS                      PORTS     NAMES
<id>           alpine:3.22   "false"       <N> seconds ago  Exited (1) <N> seconds ago            l1-b
<id>           alpine:3.22   "sleep 600"   <N> seconds ago  Up <N> seconds                        l1-a
```

Ustunlar: `CONTAINER ID` to'liq 64 belgili ID'ning birinchi 12 tasi; `COMMAND` PID 1 bo'lgan buyruq; `STATUS` holat: `Up` bu `running`, `Exited (1)` bu `exited` va qavsda exit code (`false` buyrug'i har doim 1 qaytaradi); `PORTS` publish qilingan portlar; `NAMES` nom. `l1-b` tugagan, lekin o'chmagan: `--rm` berilmagan edi, uning loglari va fayl tizimi hali turibdi.

### Exit code'lar

Exit code (linux 1, linux 9) PID 1 tugaganda qaytargan son. `docker inspect -f '{{.State.ExitCode}}' <c>` ham beradi.

| Kod | Ma'nosi |
|-----|---------|
| 0 | muvaffaqiyatli tugadi |
| 1 va boshqa kichik sonlar | ilova xatosi, ma'nosini ilova belgilaydi |
| 125 | `docker run` ning o'zi xato berdi (noto'g'ri flag) |
| 126 | buyruq topildi, lekin bajarib bo'lmadi (ruxsat yo'q) |
| 127 | buyruq topilmadi |
| 137 | 128 + 9: `SIGKILL` (OOM yoki `stop` timeout) |
| 143 | 128 + 15: `SIGTERM` bilan tugadi |

### PID 1 va signallar

Signal bu kernel orqali jarayonga yuboriladigan qisqa xabar (linux 9). Odatda handler (signalni ushlaydigan funksiya) o'rnatmagan jarayon `SIGTERM` olganda default harakat bilan tugaydi. PID 1 uchun kernel qoidasi boshqa: o'z namespace'i ichidan kelgan signal faqat PID 1 unga handler o'rnatgan bo'lsa yetkaziladi, aks holda tashlab yuboriladi. Tashqaridan (ota namespace'dan) faqat `SIGKILL` va `SIGSTOP` majburan ishlaydi.

```
$ docker exec l1-a kill -TERM 1
$ docker exec l1-a kill -KILL 1
$ docker ps --filter name=l1-a --format '{{.Names}} {{.Status}}'
l1-a Up <N> seconds
$ docker rm -f l1-a l1-b
```

`docker exec` konteyner namespace'lari ichida `kill` ni ishga tushirdi. `sleep` handler o'rnatmagan, u PID 1, shuning uchun ichkaridan kelgan `SIGTERM` ham, hatto `SIGKILL` ham hech narsa qilmadi: konteyner hali `Up`. `docker rm -f` esa tashqaridan `SIGKILL` yuboradi va u ishlaydi.

Amaliy oqibat: `SIGTERM` handler yozilmagan ilova PID 1 bo'lsa, `docker stop` ni e'tiborsiz qoldiradi, Docker kutish vaqti tugagach `SIGKILL` yuboradi, ilova ulanishlarni toza yopa olmaydi. Yechimlar: ilovada `SIGTERM` ni ushlash (Node'da `process.on('SIGTERM', ...)`), yoki `--init` flag'i: Docker PID 1 sifatida kichik init (`docker-init`, tini) qo'yadi, u signallarni ilovaga uzatadi va zombie jarayonlarni (linux 9) yig'adi. Image boshqa to'xtatish signalini belgilashi mumkin (`STOPSIGNAL`), ilova qanday qilib PID 1 bo'lishi yoki bo'lmasligi esa Dockerfile'dagi exec va shell form'ga bog'liq (ikkalasi 2-darsda).

### Real ishda qachon kerak

- Deploy har safar 10 sekund osilib turadi va so'rovlar uziladi: PID 1 `SIGTERM` ni ushlamayapti.
- `Exited (137)` ko'rsangiz ikki sabab bor: OOM yoki majburiy to'xtatish; `.State.OOMKilled` ajratadi (6-bo'lim).
- `Exited (0)` darhol: jarayon o'z ishini tugatdi yoki fonga o'tib ketdi, xato emas, noto'g'ri buyruq.

### Nima uchun shunday

PID 1 himoyasi oddiy tizimda `init` ni tasodifan o'ldirib butun tizimni yiqitmaslik uchun qilingan; konteynerda ilova shu rolga tushib qoladi va qoidani meros oladi. `docker stop` ning ikki bosqichi (avval so'rash, keyin majburlash) systemd'ning servisni to'xtatishi bilan bir xil tamoyil: ilovaga ishni yakunlash imkoni beriladi, lekin osilib qolgan jarayon tizimni cheksiz ushlab turmaydi. `exited` konteynerning saqlanishi diagnostika uchun: loglar va fayllar tekshirilguncha turadi.

## 5. Kuzatish va diagnostika

### Buyruqlar

| Buyruq | Nima beradi |
|--------|-------------|
| `docker logs <c>` | PID 1 ning stdout va stderr'i. `-f` kuzatish, `--tail 50`, `--since 10m`, `-t` vaqt belgisi |
| `docker exec -it <c> sh` | ishlayotgan konteynerda **yangi** jarayon (o'sha namespace'larda) |
| `docker top <c>` | konteyner jarayonlari (engine mashinasidagi PID'lari bilan) |
| `docker stats` | CPU, xotira, tarmoq, PID soni jonli. `--no-stream` bir marta |
| `docker inspect <c>` | to'liq konfiguratsiya va holat, JSON |
| `docker diff <c>` | image'ga nisbatan o'zgargan fayllar (A qo'shilgan, C o'zgargan, D o'chirilgan) |
| `docker cp <c>:/path ./local` | fayl nusxalash (to'xtagan konteynerdan ham) |
| `docker events` | daemon hodisalari oqimi |

Mexanizm: shim konteyner jarayonining stdout va stderr'ini ushlab daemon'ga beradi, daemon ularni log driver orqali saqlaydi (default `json-file`: engine mashinasidagi fayl, har qator bitta JSON obyekt). `docker logs` shu faylni o'qiydi, oqim farqini saqlab: stdout sizning stdout'ingizga, stderr stderr'ga chiqadi. `exec` esa `run` dan farqli yangi konteyner yaratmaydi: mavjud konteyner namespace'lariga qo'shimcha jarayon kiritadi.

```
$ docker run -d --name l1-log --label lesson=01 alpine:3.22 sh -c 'echo started; echo warn >&2; sleep 600'
$ docker logs -t l1-log
<sana>T<vaqt>Z started
<sana>T<vaqt>Z warn
$ docker logs l1-log 2>/dev/null
started
```

`-t` har qator oldiga daemon yozib olgan vaqtni (UTC) qo'shdi. Ikkinchi buyruqda stderr tashlab yuborildi va faqat stdout'ga yozilgan qator qoldi.

`exec` faqat `running` konteynerda ishlaydi. Darhol yiqilayotgan konteynerni tekshirish uchun: `docker logs`, yoki buyruqni almashtirib ishga tushirish (`docker run --rm -it --entrypoint sh IMAGE`).

**Tuzoq: loglar faqat stdout/stderr dan.** Ilova faylga yozsa `docker logs` bo'sh. Default `json-file` driver'ida rotatsiya yo'q, fayl cheksiz o'sadi va diskni to'ldiradi. Cheklash: `--log-opt max-size=10m --log-opt max-file=3` yoki daemon sozlamasida.

### inspect va format

`docker inspect` katta JSON qaytaradi. Yuqori darajadagi kalitlar: `Id`, `Created`, `State` (holat, PID, exit code), `Config` (image, buyruq, env, label), `HostConfig` (limitlar, restart policy, port bog'lanishlari), `NetworkSettings`, `Mounts`. Kerakli maydon yo'lini avval to'liq chiqishdan toping (`docker inspect l1-log | less`), keyin `--format` (`-f`) ga Go template sifatida yozing:

```
$ docker inspect -f '{{.Name}} {{.Config.Image}} {{.HostConfig.Memory}}' l1-log
/l1-log alpine:3.22 0
$ docker inspect -f '{{json .Config.Cmd}}' l1-log
["sh","-c","echo started; echo warn >&2; sleep 600"]
$ docker inspect -f '{{range $k, $v := .Config.Labels}}{{$k}}={{$v}} {{end}}' l1-log
lesson=01
$ docker ps --filter label=lesson=01 --format 'table {{.Names}}\t{{.Image}}'
NAMES     IMAGE
l1-log    alpine:3.22
$ docker rm -f l1-log
```

`{{.A.B}}` JSON'dagi yo'l; bir nechta maydon bitta template'da bo'shliq bilan yoziladi. `.HostConfig.Memory` `0`, ya'ni limit yo'q (bayt). `{{json ...}}` qiymatni JSON qilib chiqaradi (massiv va obyektlar uchun). `{{range}}...{{end}}` map yoki massiv ustida sikl: `.NetworkSettings.Networks` ham map, u xuddi shunday aylanib chiqiladi. `docker ps --format` da maydon nomlari boshqa (`.Names`, `.Status`, `.Ports`), `table` so'zi sarlavha qatorini qo'shadi. `.State.Pid` konteyner PID 1 ining engine mashinasidagi PID'i: u orqali `/proc/<PID>/ns/` va cgroup yo'liga chiqiladi.

### Real ishda qachon kerak

- Yiqilgan servis: tartib `docker ps -a` (holat va kod), `docker logs --tail`, `docker inspect` (`State`), keyin `exec`.
- Skript va monitoringda `inspect -f` JSON'ni `jq` siz bitta qiymatga aylantiradi.
- "Kim bu faylni o'zgartirdi" savoliga `docker diff` javob beradi.

### Nima uchun shunday

Log'ni stdout'ga yozish konteynerni log saqlash joyidan mustaqil qiladi: ilova fayl yo'li, rotatsiya va yuborishni bilmaydi, buni platforma hal qiladi (Docker log driver, Kubernetes, log agentlar). Node'da `console.log` ning o'zi yetadi. Muqobili (ilova o'zi faylga yozadi) konteyner o'chganda logni yo'qotadi va har ilovaga alohida rotatsiya talab qiladi. `inspect` ning JSON bo'lishi ham shundan: daemon API javobini o'zgartirmasdan beradi, formatlash klient ishi.

## 6. Resurs limitlari

### Mexanizm

Default: limit yo'q. Xotira oqishi (memory leak) bor bitta konteyner butun mashinani xotirasiz qoldiradi va kernel istalgan jarayonni, shu jumladan boshqa servislarni o'ldirishi mumkin. Limit flag'lari konteyner cgroup'idagi fayllarga yoziladi:

| Flag | cgroup fayli | Limitga yetganda |
|------|--------------|------------------|
| `--memory 256m` (`-m`) | `memory.max` (bayt) | kernel OOM killer shu cgroup'dagi jarayonni `SIGKILL` bilan o'ldiradi, exit 137, `OOMKilled: true` |
| `--memory-swap` | `memory.swap.max` | `--memory` bilan teng qo'yilsa swap ishlatilmaydi |
| `--cpus 1.5` | `cpu.max` | o'ldirilmaydi, **throttle** qilinadi (davr oxirigacha to'xtatib turiladi) |
| `--pids-limit 100` | `pids.max` | `fork` xato qaytaradi (fork bomb'dan himoya) |

OOM (out of memory) killer bu xotira tugaganda qurbon tanlab o'ldiradigan kernel mexanizmi; cgroup limiti bilan u faqat shu guruh ichidan tanlaydi va kernel jurnaliga (`journalctl -k`) qurbon nomi va PID'i bilan yozuv qoldiradi. `cpu.max` formati `<quota> <period>`, ikkalasi mikrosekundda: guruh har `period` ichida ko'pi bilan `quota` CPU vaqti oladi. `--cpus 1.5` uchun `150000 100000` (har 100 ms da 150 ms, ya'ni bir yarim yadro), limitsiz konteynerda `max 100000`. Throttle hisobi shu papkadagi `cpu.stat` da (`nr_throttled`, `throttled_usec`).

### Misol: stats

```
$ docker run -d --name l1-lim --label lesson=01 --memory 200m --cpus 1.5 alpine:3.22 sleep 600
$ docker stats --no-stream l1-lim
CONTAINER ID   NAME     CPU %     MEM USAGE / LIMIT   MEM %     NET I/O       BLOCK I/O   PIDS
<id>           l1-lim   0.00%     <N>KiB / 200MiB     <N>%      <N> / <N>     <N> / <N>   1
$ docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' l1-lim
209715200 1500000000
$ docker rm -f l1-lim
```

`CPU %` bitta yadroning foizi (ikki yadro to'liq band bo'lsa 200%); `MEM USAGE / LIMIT` `memory.current` va `memory.max` dan olinadi, limitsiz konteynerda `LIMIT` o'rnida mashinaning (macOS'da yashirin VM'ning) butun xotirasi turadi; `NET I/O` qabul qilingan va yuborilgan baytlar; `BLOCK I/O` diskdan o'qilgan va yozilgan. `inspect` limitni baytda (`200 * 1024 * 1024`) va CPU'ni nano-birlikda (1.5 yadro) saqlaydi.

Xotira siqilmaydigan resurs (yetmasa o'ldiriladi), CPU siqiladigan (yetmasa kutadi). Bu farq Kubernetes'dagi requests/limits mavzusining asosi.

**Tuzoq: runtime limitni ko'rmasligi mumkin.** Konteyner ichida `free` va `/proc/meminfo` butun mashina xotirasini ko'rsatadi. Zamonaviy Node.js, Go, JVM cgroup limitini o'qiydi, eski versiyalar va ayrim kutubxonalar o'qimaydi va heap'ni mashina xotirasiga qarab o'lchaydi, natija OOM kill. Node'da `--max-old-space-size` ni limitdan pastroq aniq berish xavfsiz.

### Real ishda qachon kerak

- Production'da har konteynerda `--memory` (Compose va Kubernetes'da uning ekvivalenti) bo'ladi.
- "Ilova sekin, lekin CPU 100% emas": `cpu.stat` dagi `nr_throttled` o'sayotgan bo'lsa limit past.
- Bir mashinada bir nechta mijoz yoki muhit: limitlar "shovqinli qo'shni" muammosini cheklaydi.

### Nima uchun shunday

Limitni ilova emas, kernel ushlab turadi, shuning uchun ilova uni chetlab o'ta olmaydi va tilga bog'liq emas. Default limitsiz, chunki Docker ilovaga qancha kerakligini bilmaydi; noto'g'ri default ishlayotgan dasturlarni o'ldirar edi. cgroup v1 da har resurs alohida daraxt edi va sozlash chalkash edi, v2 (yagona daraxt) hozirgi standart. Muqobili har ilovani alohida VM'ga qo'yish: limit qat'iy, lekin zichlik past.

## 7. Restart policy

### Mexanizm

Restart policy konteyner sozlamasida saqlanadi (`HostConfig.RestartPolicy`) va uni `dockerd` bajaradi: PID 1 tugaganini shim'dan bilib, qoidaga qarab konteynerni qayta `start` qiladi.

| Policy | Xatti-harakat |
|--------|---------------|
| `no` (default) | qayta ishga tushirilmaydi |
| `on-failure[:N]` | faqat exit code nol bo'lmaganda, ixtiyoriy N martagacha |
| `always` | har doim. Qo'lda `stop` qilingan bo'lsa ham daemon qayta ishga tushganda start bo'ladi |
| `unless-stopped` | `always` kabi, lekin qo'lda to'xtatilgan konteyner daemon restart'idan keyin to'xtagan holda qoladi |

- Qo'lda `docker stop` qilingan konteynerni hech bir policy darhol qayta ko'tarmaydi.
- Qayta urinishlar orasidagi kutish har safar ikki barobar oshadi (100 ms dan boshlab, 1 minutgacha); konteyner 10 sekunddan ko'p yashasa hisob qaytadan boshlanadi.
- `--restart` va `--rm` birga ishlatilmaydi.
- Mavjud konteynerda o'zgartirish: `docker update --restart unless-stopped <c>`.

### Misol: jarayon o'lsa nima bo'ladi

VM'da (engine tomonidan jarayonni o'ldirish kerak, Mac host'ida buning iloji yo'q):

```
ubuntu@lab:~$ docker run -d --name l1-rs --label lesson=01 alpine:3.22 sleep 600
ubuntu@lab:~$ docker update --restart unless-stopped l1-rs
ubuntu@lab:~$ docker inspect -f '{{json .HostConfig.RestartPolicy}}' l1-rs
{"Name":"unless-stopped","MaximumRetryCount":0}
ubuntu@lab:~$ sudo kill -9 $(docker inspect -f '{{.State.Pid}}' l1-rs); sleep 2
ubuntu@lab:~$ docker inspect -f '{{.State.Status}} {{.RestartCount}} {{.State.Pid}}' l1-rs
running 1 <yangi PID>
ubuntu@lab:~$ docker rm -f l1-rs
```

`docker update` policy'ni ishlayotgan konteynerda o'zgartirdi, `inspect` uni JSON ko'rinishida tasdiqladi (`MaximumRetryCount` faqat `on-failure:N` da noldan farq qiladi). `sudo kill -9` VM tomonidan konteyner PID 1 iga `SIGKILL` yubordi: bu ilovaning to'satdan o'lishini taqlid qiladi. `sleep 2` daemon qayta boshlashini kutadi. Daemon buni qo'lda to'xtatish deb emas, yiqilish deb ko'radi va konteynerni qayta boshlaydi: holat `running`, `RestartCount` 1, PID yangi (jarayon boshqa, konteyner o'sha).

Restart policy bitta mashinadagi oddiy self-healing. U konteyner "ishlayapti, lekin javob bermayapti" holatini ko'rmaydi (healthcheck, 3-dars) va mashina o'lsa yordam bermaydi (orkestrator, 5-dars).

### Real ishda qachon kerak

- Yakka serverdagi servislar: `unless-stopped`, server reboot'idan keyin o'zi ko'tariladi.
- Bir martalik ish (migratsiya, skript): `no` yoki `on-failure:N`, aks holda muvaffaqiyatli ish ham qayta-qayta ishlaydi.

### Nima uchun shunday

Bu systemd'dagi `Restart=` (linux 11) va `pm2` ning qayta ishga tushirishi bilan bir xil g'oya, faqat nazoratchi `dockerd`. Kutishning ikki barobar o'sishi (exponential backoff) darhol yiqiladigan konteyner CPU va logni to'ldirib yubormasligi uchun. `always` va `unless-stopped` farqi operator niyatini saqlash uchun: ataylab to'xtatilgan narsa reboot'dan keyin o'zi turmasligi kerak.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Konteyner | host kernel'ida namespace, cgroup va o'z root fayl tizimi bilan ishlaydigan jarayon(lar) |
| Namespace | kernel resursining (PID, tarmoq, mount, hostname) jarayonga ko'rinadigan alohida nusxasi |
| cgroup | jarayonlar guruhiga resurs limiti qo'yadigan va sarfni hisoblaydigan kernel mexanizmi |
| Scope | systemd tashqaridan ishga tushirilgan jarayonlar uchun ochadigan cgroup |
| Capabilities | root huquqlarining alohida beriladigan bo'laklari |
| seccomp | jarayonga ruxsat etilgan system call'lar filtri |
| Daemon | fonda doimiy ishlaydigan servis jarayoni (`dockerd`, `containerd`) |
| Unix socket | fayl orqali ishlaydigan, bitta mashina ichidagi aloqa kanali (`/var/run/docker.sock`) |
| containerd | image va konteyner hayot siklini boshqaradigan daemon |
| Shim | har konteynerning ota jarayoni, stdout/stderr va exit code'ni ushlaydi |
| runc | namespace va cgroup yaratib jarayonni ishga tushiradigan OCI runtime |
| OCI | image formati va runtime uchun ochiq standartlar |
| Image | konteynerning boshlang'ich fayl tizimi va standart sozlamalari |
| Digest | image tarkibining hash'i (`sha256:...`) |
| Detached (`-d`) | konteyner fonda, terminalga ulanmagan |
| Port publishing | engine mashinasidagi portni konteyner portiga yo'naltirish |
| PID 1 | konteynerdagi birinchi jarayon, u tugasa konteyner tugaydi |
| Handler | jarayonning signalni ushlaydigan funksiyasi |
| Exit code | PID 1 tugaganda qaytargan son, `128 + N` signal `N` dan o'lganini bildiradi |
| OOM killer | xotira tugaganda jarayonni o'ldiradigan kernel mexanizmi |
| Throttle | CPU kvotasi tugagan guruhni davr oxirigacha to'xtatib turish |
| Log driver | daemon konteyner chiqishini saqlaydigan usul (default `json-file`) |
| Restart policy | konteyner tugaganda daemon uni qayta boshlash qoidasi |
| linuxkit | Docker Desktop yashirin VM'ining Linux kernel'i va tizimi |

## Tuzoqlar

- `-p 5432:5432` bazani barcha interfeyslarga ochadi va `ufw` buni to'smaydi. Lokal uchun `127.0.0.1:5432:5432`.
- Xotira limiti yo'q konteyner mashinani OOM'ga olib boradi. Production'da har konteynerda `--memory` bo'lsin.
- `SIGTERM` ni ushlamaydigan PID 1: har to'xtatish 10 sekund va `SIGKILL`, tugallanmagan so'rovlar uziladi.
- `json-file` log rotatsiyasiz: bir necha haftada `/var/lib/docker` to'ladi, barcha konteynerlar to'xtaydi.
- Konteyner ichida qo'lda qilingan o'zgarish (`exec` bilan paket o'rnatish, config tahrirlash) `rm` dan keyin yo'qoladi. O'zgarish image yoki volume'da bo'lishi kerak.
- `docker` guruhi va `docker.sock` mount qilish root berishga teng.
- `--privileged` deyarli barcha izolyatsiyani o'chiradi. Kerakli bitta capability'ni `--cap-add` bilan bering.
- Parolni `-e` bilan berish: `docker inspect`, `/proc/<PID>/environ` va shell history'da ochiq qoladi.
- `--restart always` bilan darhol yiqiladigan konteyner cheksiz restart siklida qoladi va muammoni yashiradi. `docker ps` dagi `Restarting` va `RestartCount` ga qarang.
- `-it` ni skriptda ishlatish: `the input device is not a TTY` xatosi yoki buzilgan chiqish.
- macOS'da `.State.Pid`, `.LogPath`, `/sys/fs/cgroup`, `/var/lib/docker` Mac'da emas, Docker Desktop VM'ida. Mac'da `ps` konteyner jarayonini ko'rsatmaydi; bunday tekshiruvni `lab` VM'da qiling.
- VM'dagi Docker va host'dagi Docker alohida: birida yaratilgan konteyner va image ikkinchisida yo'q, tozalash ham ikkalasida alohida.
- Mac'da `pull` qilingan image `linux/arm64`, Zorin'da `linux/amd64`; tag bir xil, baytlar boshqa.

## Manbalar

- https://docs.docker.com/get-started/docker-overview/ – arxitektura umumiy ko'rinishi
- https://docs.docker.com/reference/cli/docker/container/run/ – `docker run` barcha flag'lari
- https://docs.docker.com/reference/cli/docker/container/stop/ – `docker stop`, signal va timeout
- https://docs.docker.com/engine/cli/formatting/ – `--format` va Go template
- https://docs.docker.com/engine/containers/resource_constraints/ – xotira va CPU limitlari
- https://docs.docker.com/engine/containers/start-containers-automatically/ – restart policy
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker va iptables, ufw bilan munosabati
- https://docs.docker.com/engine/logging/configure/ – log driver'lar va rotatsiya
- https://docs.docker.com/engine/security/ – namespaces, cgroups, capabilities, daemon hujum yuzasi
- https://man7.org/linux/man-pages/man7/namespaces.7.html – `namespaces(7)`
- https://man7.org/linux/man-pages/man7/pid_namespaces.7.html – `pid_namespaces(7)`, PID 1 va signal qoidasi
- https://man7.org/linux/man-pages/man7/cgroups.7.html – `cgroups(7)`
- https://docs.kernel.org/admin-guide/cgroup-v2.html – cgroup v2 fayllari (`memory.max`, `cpu.max`, `pids.max`)
- https://github.com/opencontainers/runtime-spec – OCI runtime spetsifikatsiyasi
- Rice, "Container Security", 3–4-boblar (cgroups, namespaces)

## Birga bajaramiz

Bitta konteynerni tug'ilishidan o'limigacha engine tomonidan kuzatamiz. Misol: har sekundda vaqtni chop etadigan va `SIGTERM` ni o'zi ushlaydigan shell sikli. Hammasi `lab` VM ichida.

1. VM'ga kiring va konteynerni limit, hostname va label bilan ishga tushiring:

```
$ multipass shell lab
ubuntu@lab:~$ docker run -d --name l1-walk --label lesson=01 --hostname ticker --memory 96m --cpus 1.5 \
    alpine:3.22 sh -c 'trap "echo bye; exit 0" TERM; while true; do date; sleep 1; done'
<id>
ubuntu@lab:~$ docker ps --filter name=l1-walk --format '{{.Names}}\t{{.Status}}'
l1-walk	Up <N> seconds
```

`trap` shell'da signal handler o'rnatadi: `SIGTERM` kelsa `bye` chop etib 0 kodi bilan chiqadi. `docker run -d` to'liq ID'ni qaytardi, konteyner `Up`.

2. Engine mashinasida bu oddiy jarayon ekanini ko'ring:

```
ubuntu@lab:~$ docker inspect -f '{{.State.Pid}}' l1-walk
<PID>
ubuntu@lab:~$ ps -o pid,ppid,user,comm -p <PID>
    PID    PPID USER     COMMAND
  <PID>  <PPID> root     sh
ubuntu@lab:~$ ps -o pid,comm -p <PPID>
    PID COMMAND
 <PPID> containerd-shim
```

Konteyner ichidagi PID 1 VM'da `<PID>` raqamli oddiy `sh` jarayoni, egasi `root` (user namespace yo'q). Uning otasi `dockerd` emas, shim (`comm` ustuni nomni 15 belgigacha qisqartiradi).

3. Namespace'ni solishtiring:

```
ubuntu@lab:~$ sudo readlink /proc/<PID>/ns/uts
uts:[<N1>]
ubuntu@lab:~$ readlink /proc/$$/ns/uts
uts:[<N2>]
ubuntu@lab:~$ docker exec l1-walk hostname
ticker
```

`readlink` symlink nishonini chiqaradi. Ikki raqam farq qiladi: konteyner jarayoni va sizning shell'ingiz boshqa `uts` namespace'da, shuning uchun konteyner hostname'i `ticker`, VM'niki `lab`.

4. cgroup'ni toping va limitlarni o'qing:

```
ubuntu@lab:~$ cat /proc/<PID>/cgroup
0::/system.slice/docker-<full-id>.scope
ubuntu@lab:~$ cat /sys/fs/cgroup/system.slice/docker-<full-id>.scope/memory.max
100663296
ubuntu@lab:~$ cat /sys/fs/cgroup/system.slice/docker-<full-id>.scope/cpu.max
150000 100000
```

`/proc/<PID>/cgroup` da `0::` cgroup v2 belgisi, keyin `/sys/fs/cgroup` ga nisbatan yo'l. `memory.max` baytda: `96 * 1024 * 1024`. `cpu.max` 6-bo'limdagi format: har 100 ms da 150 ms.

5. Loglarni o'qing va konteynerni to'xtating:

```
ubuntu@lab:~$ docker logs --tail 2 l1-walk
<sana> <vaqt> UTC <yil>
<sana> <vaqt> UTC <yil>
ubuntu@lab:~$ time docker stop l1-walk
l1-walk
real	0m<N>s
user	0m<N>s
sys	0m<N>s
ubuntu@lab:~$ docker logs --tail 1 l1-walk
bye
ubuntu@lab:~$ docker inspect -f '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}' l1-walk
exited 0 false
ubuntu@lab:~$ ls /proc/<PID>
ls: cannot access '/proc/<PID>': No such file or directory
ubuntu@lab:~$ docker rm l1-walk
```

`docker stop` `SIGTERM` yubordi, shell joriy `sleep 1` tugashini kutib handler'ni bajardi: to'xtash 10 sekund emas, bir-ikki sekund oldi, oxirgi log `bye`, exit code `0`. Holat `exited`: jarayon yo'q (`/proc/<PID>` yo'qoldi), lekin loglar `docker rm` gacha o'qiladi.

Shu 5 qadamda ko'rganingiz: `run` flag'lari (3-bo'lim), konteyner oddiy jarayon va uning otasi shim (1 va 2-bo'limlar), namespace raqamlari (1-bo'lim), limit cgroup faylida (6-bo'lim), log va `inspect` (5-bo'lim), signal handler bilan toza to'xtash va `exited` holati (4-bo'lim).

---

## Vazifalar

Ish papkasi: `docker/01-containers/` (`make new m=docker n=01 name=containers` bilan host'da yarating). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Vazifa so'ragan fayllar (skript, env fayl) shu papkada saqlanadi. Har vazifa oxirida qayerda bajarilishi yozilgan: "host" o'zingiz turgan mashinadagi Docker (Zorin yoki macOS), "`lab` VM" VM ichidagi Docker. VM vazifalari matnidagi "host" so'zi engine ishlayotgan mashinani, ya'ni VM'ning o'zini bildiradi; natijani README'ga qo'lda ko'chiring yoki `multipass exec lab -- <buyruq>` bilan oling. Zorin'da VM vazifalarini ixtiyoriy ravishda host'da ham takrorlash mumkin. Har konteynerga `--label lesson=01` qo'ying, vazifa matnidagi buyruqlarga ham.

### A. Konteyner bu jarayon

1. **Architecture chain.** `docker version` va `docker info` dan client, server, containerd, runc versiyalarini, cgroup versiyasi va driver'ini yozib oling. `nginx:1.28-alpine` ni `-d` bilan ishga tushirib, hostda `ps -ef --forest | grep -B2 nginx` orqali `containerd-shim-runc-v2` va uning ostidagi nginx jarayonlarini toping. Nima uchun nginx'ning otasi `dockerd` emas, shim ekanini izohlang. Qayerda: `lab` VM (image VM'da qayta `pull` qilinadi). Yo'nalish: 2-bo'lim, "Zanjir".

2. **Same kernel.** Hostda va `alpine:3.22` konteynerida `uname -r` hamda `cat /etc/os-release` ni solishtiring. Qaysi biri bir xil, qaysi biri farq qiladi va nima uchun? Qayerda: `lab` VM (bu yerda "host" VM'ning o'zi), keyin o'zingiz turgan mashinada ham takrorlang: macOS'da host `uname -r` Darwin versiyasini, konteyner esa `linuxkit` kernel'ini ko'rsatadi, sababini yozing. Yo'nalish: 1-bo'lim, "Konteyner va VM".

3. **PID namespace.** Ishlayotgan nginx konteynerida `docker exec <c> ps` va hostda `docker top <c>` ni solishtiring. Bitta jarayonning ikki xil PID'ini yozing. `docker inspect -f '{{.State.Pid}}'` qaysi biriga mos? Qayerda: `lab` VM. Yo'nalish: 1-bo'lim, "Misol: Docker'siz namespace".

4. **Namespace IDs.** Konteyner PID 1 ining host PID'i uchun `sudo ls -l /proc/<pid>/ns/` va o'z shell'ingiz uchun `ls -l /proc/$$/ns/` ni solishtiring. Qaysi namespace'lar farq qiladi, qaysilari bir xil (`user` ga e'tibor bering) va bu nimani anglatadi? Qayerda: `lab` VM. Yo'nalish: 1-bo'lim, "Namespaces: mexanizm".

5. **cgroup files.** Konteynerni `--memory 128m --cpus 0.5 --pids-limit 50` bilan ishga tushiring. Hostda `/sys/fs/cgroup/system.slice/docker-<id>.scope/` ichidan `memory.max`, `cpu.max`, `pids.max` ni o'qing, keyin xuddi shu qiymatlarni konteyner ichidagi `/sys/fs/cgroup/` dan o'qing. `cpu.max` dagi ikki son nimani bildiradi? Limitsiz konteynerda `memory.max` nima? Qayerda: `lab` VM. Yo'nalish: 1-bo'lim, "cgroups: mexanizm" va 6-bo'lim, "Mexanizm".

### B. Hayot sikli

6. **Run modes.** `alpine:3.22` ni uch usulda ishga tushiring: `docker run alpine:3.22 echo hi`, `docker run -it alpine:3.22 sh`, `docker run -d alpine:3.22 sleep 300`. Har biridan keyin `docker ps -a` holatini yozing. Keyin `docker run -d alpine:3.22 sh` nima uchun darhol `Exited (0)` bo'lishini, `-dit` bilan esa ishlab turishini izohlang. Qayerda: host. Yo'nalish: 3-bo'lim, "To'rt qadam" (flag'lar jadvali).

7. **Lifecycle states.** Bitta konteynerni `create`, `start`, `pause`, `unpause`, `stop`, `start`, `rm` bosqichlaridan o'tkazing, har qadamdan keyin `docker inspect -f '{{.State.Status}}'` ni yozing. `stop` dan keyingi `start` da konteyner ichida avval yaratilgan fayl saqlanganmi? `rm` dan keyin-chi? Qayerda: host. Yo'nalish: 4-bo'lim, "Holatlar".

8. **Exit codes.** Uchta konteyner ishga tushiring: `sh -c 'exit 3'`, mavjud bo'lmagan buyruq (`nosuchcmd`), va `sleep 300` ni `docker kill` bilan o'ldiring. Uchala exit code'ni yozing va har birini izohlang. Qayerda: host. Yo'nalish: 4-bo'lim, "Exit code'lar".

9. **PID 1 and SIGTERM.** `docker run -d --name s1 alpine:3.22 sleep 300` ni `time docker stop s1` bilan to'xtating, vaqt va exit code'ni yozing. Xuddi shuni `--init` bilan (`s2`) takrorlang. Farqni PID 1 ning signal qoidasi orqali tushuntiring. `docker stop -t 2` nimani o'zgartiradi? Qayerda: host. Yo'nalish: 4-bo'lim, "PID 1 va signallar".

10. **The --rm flag.** `--rm` bilan va `--rm` siz bittadan qisqa konteyner ishga tushiring, `docker ps -a` da farqni ko'rsating. `--rm` bilan `--restart always` ni birga berib ko'ring, xatoni yozing. Qayerda: host. Yo'nalish: 3-bo'lim (flag'lar jadvali) va 7-bo'lim, "Mexanizm".

### C. Port, env, diagnostika

11. **Port publishing.** nginx'ni uch marta ishga tushiring: `-p 8081:80`, `-p 127.0.0.1:8082:80`, `-p 80` (host porti tasodifiy). `docker port` va `ss -tlnp` bilan har biri qaysi manzilda tinglayotganini ko'rsating. Qaysi biri tarmoqdagi boshqa mashinadan ochiq? Band portga ikkinchi konteynerni ulab ko'ring va xatoni yozing. Qayerda: `lab` VM (`ss` macOS'da yo'q). "Boshqa mashina" sifatida host'dan VM IP'siga (`multipass info lab`) `curl` qiling. Yo'nalish: 3-bo'lim, "Port publishing".

12. **Environment variables.** `app.env` fayl yarating (2–3 o'zgaruvchi) va konteynerni `--env-file app.env -e EXTRA=1` bilan ishga tushiring. `docker exec <c> env` va `docker inspect -f '{{json .Config.Env}}'` natijasini solishtiring. Nima uchun bu parol saqlash uchun yomon joy ekanini 2 gapda yozing. `app.env` ni commit qilmang. Qayerda: host. Yo'nalish: 3-bo'lim, "Environment".

13. **Logs.** nginx konteyneriga `curl` bilan bir necha so'rov yuboring (mavjud bo'lmagan sahifaga ham). `docker logs` ni `--tail`, `--since`, `-t`, `-f` bilan ishlating. `docker logs <c> 2>/dev/null` va `docker logs <c> >/dev/null` bilan access log va error log qaysi oqimga ketayotganini aniqlang. `docker inspect -f '{{.LogPath}}'` qayerni ko'rsatadi? Qayerda: host. macOS'da `LogPath` Mac'dagi emas, Docker Desktop VM'i ichidagi yo'l; faylning o'zini ko'rmoqchi bo'lsangiz shu qismni `lab` VM'da takrorlang (`sudo ls -l`). Yo'nalish: 5-bo'lim, "Buyruqlar".

14. **Exec and diff.** Ishlayotgan nginx'da `docker exec` orqali `/usr/share/nginx/html/index.html` ni o'zgartiring va `curl` bilan tekshiring. `docker diff` nimani ko'rsatadi? Konteynerni `rm -f` qilib, xuddi shu buyruq bilan qayta yarating: o'zgarish qani va nima uchun? Qayerda: host. Yo'nalish: 5-bo'lim, "Buyruqlar".

15. **Inspect format.** Bitta `docker inspect -f` buyrug'i bilan (jq'siz) quyidagilarni oling: holat, exit code, restart soni, IP manzil, image nomi, publish qilingan portlar. Keyin `docker ps --format` bilan faqat nom, holat va portlardan iborat jadval chiqaring. Qayerda: host. Yo'nalish: 5-bo'lim, "inspect va format".

### D. Limit va restart

16. **OOM kill.** `docker run --name oom -m 64m alpine:3.22 sh -c 'tail /dev/zero'` ni ishga tushiring. Exit code va `docker inspect -f '{{.State.OOMKilled}}'` ni yozing. `journalctl -k --since "5 min ago" | grep -i oom` da kernel yozuvini toping. Limit bo'lmaganda bu buyruq hostga nima qilar edi (ishlatib ko'rmang, izohlang)? Qayerda: `lab` VM. Yo'nalish: 6-bo'lim, "Mexanizm".

17. **CPU throttling.** `docker run -d --name burn --cpus 0.5 alpine:3.22 sh -c 'while :; do :; done'` ni ishga tushiring. `docker stats --no-stream` da CPU foizini, konteyner cgroup'idagi `cpu.stat` faylidan `nr_throttled` qiymatining o'sishini ko'rsating. Nima uchun CPU limitidan oshgan konteyner o'ldirilmaydi, xotiradan oshgani esa o'ldiriladi? Qayerda: `lab` VM (2 CPU). Ishni tugatgach konteynerni darhol o'chiring. Yo'nalish: 6-bo'lim, "Mexanizm".

18. **Fork limit.** `--pids-limit 20` bilan `alpine:3.22` shell'ini oching va sikl ichida 30 ta `sleep 100 &` ishga tushirishga urining. Xato matnini yozing. `docker stats` ning `PIDS` ustuni nimani ko'rsatadi? Qayerda: host. Yo'nalish: 6-bo'lim, "Mexanizm" va "Misol: stats".

19. **Restart policies.** `sh -c 'sleep 3; exit 1'` buyrug'i bilan uchta konteyner: `--restart no`, `--restart on-failure:3`, `--restart always`. 40 sekunddan keyin har birining holati va `{{.RestartCount}}` ini yozing. `always` konteynerida restartlar orasidagi vaqt qanday o'zgarishini `docker events --filter container=<c>` yoki `docker ps` orqali kuzating va izohlang. Keyin `always` ni `docker stop` qiling: qayta ko'tariladimi? Qayerda: host. Yo'nalish: 7-bo'lim, "Mexanizm".

### E. Yakuniy

20. **Break and diagnose.** Quyidagi uchta buzilgan holatni yarating va har birida faqat `docker ps -a`, `docker logs`, `docker inspect` yordamida sababni toping, README'ga "alomat, qanday topdim, sabab" shaklida yozing: (a) `docker run -d nginx:1.28-alpine nginx -g 'daemon on;'`; (b) `docker run -d -m 16m nginx:1.28-alpine tail /dev/zero`; (c) hech qanday `-e` siz ishga tushirilgan `postgres:17-alpine`. Qayerda: host. Yo'nalish: 4-bo'lim, "Exit code'lar" va 5-bo'lim.

21. **Container report script.** `report.sh` yozing: argument sifatida konteyner nomini oladi va bitta ekranda chiqaradi: holat, exit code, OOMKilled, restart soni va policy, host PID, IP, portlar, xotira limiti (bayt), oxirgi 5 qator log. Faqat `docker inspect -f`, `docker logs`, `docker port` ishlating. Mavjud bo'lmagan konteyner uchun tushunarli xabar va nol bo'lmagan exit code. `shellcheck report.sh` toza bo'lsin. Qayerda: host, skript ish papkasida; "host PID" bu engine mashinasidagi PID (macOS'da yashirin VM ichidagi). Yo'nalish: 5-bo'lim, "inspect va format".

22. **Cleanup.** Dars davomida yaratilgan barcha konteynerlarni label filtri orqali o'chiring (label qo'yilmaganlarini nomi bilan). `docker ps -a` va `docker system df` natijasini yozing. `docker container prune`, `docker rm -f $(docker ps -aq)` va label filtri bilan o'chirish farqini, birinchi ikkitasi nima uchun umumiy serverda xavfli ekanini izohlang. Qayerda: host'da va `lab` VM'da, ikkalasida alohida (uchta buyruqdan faqat label filtri ishlatiladi, qolgan ikkitasi faqat izohlanadi). Yo'nalish: "Laboratoriya".

### Topshirish

Tayyor bo'lgach:
1. `docker/01-containers/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida; har javobda buyruq, natijaning muhim qismi, o'z so'zingiz bilan izoh va qayerda bajarilgani (host yoki `lab` VM, qaysi mashina) bor.
2. `docker/01-containers/report.sh` bor va `shellcheck docker/01-containers/report.sh` hech narsa chiqarmaydi.
3. `make check` toza o'tadi (host'da).
4. `docker ps -a --filter label=lesson=01` host'da ham, `lab` VM'da ham bo'sh; `app.env` commit qilinmagan.
5. `multipass list` da `lab` `Running` yoki `Stopped` holatda (o'chirilmagan), undagi Docker keyingi darslar uchun qoladi.
6. Menga xabar bering, `README.md` va skriptni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Namespace va cgroup har biri qaysi savolga javob beradi? Konteyner VM dan nimasi bilan farq qiladi?
- Bitta jarayon nima uchun ikki xil PID'ga ega bo'la oladi? Ikki jarayon bitta namespace'da ekanini qanday bilasiz?
- macOS'da konteyner jarayoni nima uchun Mac'dagi `ps` da ko'rinmaydi va konteyner ichidagi `uname -r` nimani ko'rsatadi?
- `docker run` bosilgandan nginx jarayoni paydo bo'lguncha qaysi komponentlar ishlaydi va shim nima uchun kerak?
- Konteyner qachon `exited` holatiga o'tadi? Nima uchun servis foreground'da ishlashi kerak?
- `docker stop` nima qiladi va PID 1 `SIGTERM` ni ushlamasa nima bo'ladi? `--init` nimani o'zgartiradi?
- Exit code 137 ning ikki xil sababi qanday va ularni qanday ajratasiz?
- `-p 8080:80` va `-p 127.0.0.1:8080:80` farqi nima, `ufw` bu yerda nima uchun yordam bermaydi?
- Xotira limiti va CPU limitiga yetganda nima sodir bo'ladi, farq nimada? `cpu.max` qanday o'qiladi?
- `always` va `unless-stopped` qaysi vaziyatda turlicha ishlaydi?
- `docker exec` va `docker run` farqi nima? Darhol yiqilayotgan konteynerni qanday tekshirasiz?
- Nima uchun `docker` guruhi a'zoligi root huquqiga teng?
