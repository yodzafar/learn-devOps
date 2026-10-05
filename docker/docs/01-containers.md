# 1-dars: Konteynerlar

Maqsad: konteyner nima ekanini kernel darajasida tushunish (namespaces, cgroups) va uni VM dan ajrata bilish, Docker'ning ichki zanjirini (CLI, dockerd, containerd, shim, runc) bilish, konteyner hayot siklini buyruqlar bilan boshqarish va ishlamayotgan konteynerni diagnostika qilish. Linux modulidagi jarayonlar, signallar va tarmoq bilimlari shu yerda qo'llanadi. Keyingi darslar (image, volume, tarmoq, Compose) shu darsdagi `run` flag'lari va `inspect` ustiga quriladi.

Taxminiy vaqt: 3 kun (siz uchun). `docker run` tanish, diqqatni quyidagilarga qarating: konteyner bu oddiy Linux jarayoni ekani, PID 1 va signal muammosi, exit code'larni o'qish (137, 143), `-p` ning host firewall'ni chetlab o'tishi, limit qo'yilmagan konteyner xavfi, restart policy'lar farqi, `inspect --format`.

## Laboratoriya

Ish mashinasidagi Docker Engine. Tekshirish:

```
docker version
docker info | grep -E "Cgroup|Storage Driver|Default Runtime"
```

Kutiladigan natija: `Cgroup Version: 2`, `Cgroup Driver: systemd`, `Default Runtime: runc`. Dars `nginx:1.28-alpine` va `alpine:3.22` image'laridan foydalanadi. Vazifalar konteyner ichida istalgan narsani o'zgartirishi mumkin, ish mashinasida paket o'rnatilmaydi. `/sys/fs/cgroup` va `/proc` dan o'qish `sudo` talab qilmaydi; `lsns` ning to'liq ro'yxati uchun `sudo lsns` kerak, bu faqat o'qiydi.

Mashinangizda boshqa loyihalarning konteyner va volume'lari bor, shuning uchun shu darsdagi har konteynerni `--label lesson=01` bilan yarating va faqat shularni o'chiring. `docker container prune` va `docker system prune` barcha to'xtagan konteynerlarni o'chiradi, bu yerda ishlatmang.

Tozalash (dars oxirida):

```
docker ps -a --filter label=lesson=01                     # review first
docker rm -f $(docker ps -aq --filter label=lesson=01)
docker image rm nginx:1.28-alpine alpine:3.22             # only if no other project uses them
```

---

## 1. Konteyner nima

Konteyner alohida "yengil VM" emas. Bu host kernelida ishlayotgan oddiy Linux jarayoni (yoki jarayonlar guruhi), unga uchta cheklov qo'yilgan:

| Mexanizm | Nima beradi | Savol |
|----------|-------------|-------|
| namespaces | izolyatsiya | jarayon nimani **ko'ra oladi** |
| cgroups | resurs limiti va hisobi | jarayon qancha **ishlata oladi** |
| union filesystem (image) | o'z root fayl tizimi | jarayon qaysi **fayllarni ko'radi** (2-dars) |

Bunga xavfsizlik qatlamlari qo'shiladi: capabilities (root huquqlarining kesilgan to'plami), seccomp (ruxsat etilgan syscall'lar ro'yxati), AppArmor.

### Namespaces

Har namespace turi kernel resursining bir ko'rinishini ajratadi:

| Namespace | Ajratadi | Konteynerdagi natija |
|-----------|----------|----------------------|
| `pid` | jarayon ID'lari | ilova PID 1, host jarayonlari ko'rinmaydi |
| `net` | interfeyslar, routing, portlar, iptables | o'z `eth0` va `lo`, o'z port maydoni |
| `mnt` | mount nuqtalari | o'z `/` (image'dan) |
| `uts` | hostname | hostname konteyner ID'si |
| `ipc` | shared memory, semaphore | boshqa konteyner bilan IPC yo'q |
| `user` | UID/GID mapping | Docker'da default o'chiq: konteyner root'i hostdagi root (UID 0) |
| `cgroup` | cgroup daraxti ko'rinishi | konteyner o'z cgroup'ini `/` deb ko'radi |

Host tomonidan konteyner jarayoni oddiy `ps` da ko'rinadi, faqat PID boshqa. Jarayonning namespace'lari `/proc/<pid>/ns/` da.

**Tuzoq: konteyner root'i bu host root'i.** User namespace default yoqilmagan. Konteyner ichidagi UID 0 hostda ham UID 0, faqat capabilities va seccomp bilan cheklangan. `--privileged` yoki `/var/run/docker.sock` ni mount qilish bu cheklovni amalda olib tashlaydi.

### cgroups

cgroup (control group) jarayonlar guruhiga CPU, xotira, PID soni, I/O bo'yicha limit qo'yadi va sarfni hisoblaydi. cgroup v2 da bu `/sys/fs/cgroup` ostidagi yagona daraxt. systemd driver bilan har konteyner o'z scope'iga tushadi:

```
/sys/fs/cgroup/system.slice/docker-<full-container-id>.scope/
    memory.max      # --memory
    cpu.max         # --cpus  ("50000 100000" = 0.5 CPU)
    pids.max        # --pids-limit
    memory.current  # current usage
```

Konteyner ichidan xuddi shu fayllar `/sys/fs/cgroup/` da ko'rinadi. Limit qo'yilmasa `memory.max` qiymati `max`, ya'ni konteyner hostning butun xotirasini yeyishi mumkin.

### Konteyner va VM

| | Konteyner | VM |
|---|-----------|----|
| Kernel | host kerneli, umumiy | o'z kerneli |
| Izolyatsiya | kernel mexanizmlari (namespaces) | hypervisor, apparat virtualizatsiyasi |
| Ishga tushish | millisekundlar (jarayon start) | sekundlar, OS boot |
| Hajm | megabaytlar | gigabaytlar |
| Hujum yuzasi | butun kernel syscall interfeysi | hypervisor interfeysi (torroq) |
| Boshqa OS | faqat Linux userspace | istalgan OS |

Xulosa: konteyner ilovani qadoqlash va zich joylashtirish uchun, VM kuchli izolyatsiya uchun. Cloud'da odatda ikkalasi birga: VM ichida konteynerlar. Konteyner ichida `uname -r` host kernel versiyasini ko'rsatadi, image qaysi distributiv bo'lishidan qat'i nazar.

## 2. Docker arxitekturasi

```
docker (CLI)  --REST API-->  dockerd  --gRPC-->  containerd  -->  containerd-shim-runc-v2  -->  runc  -->  your process
              /var/run/docker.sock
```

| Komponent | Vazifasi |
|-----------|----------|
| `docker` CLI | buyruqni HTTP so'rovga aylantiradi, o'zi hech narsa ishga tushirmaydi |
| `dockerd` | API, build, network, volume, restart policy mantig'i |
| `containerd` | image pull va saqlash, konteyner hayot sikli. Kubernetes ham to'g'ridan-to'g'ri shuni ishlatadi |
| `containerd-shim-runc-v2` | har konteynerga bitta. Konteyner jarayonining ota jarayoni, stdout/stderr va exit code'ni ushlab turadi |
| `runc` | OCI runtime: namespaces va cgroups yaratadi, jarayonni `exec` qiladi va o'zi chiqib ketadi |

Shim borligi uchun `dockerd` va `containerd` ni konteynerlarni o'ldirmasdan qayta ishga tushirish arxitektura jihatidan mumkin (buning uchun daemon'da `live-restore` yoqilgan bo'lishi kerak, default o'chiq).

OCI (Open Container Initiative) ikki standartni belgilaydi: image format va runtime spec. Shuning uchun Docker bilan qurilgan image Podman, containerd, Kubernetes'da ham ishlaydi.

**Tuzoq: `docker` guruhi root'ga teng.** Socket'ga yoza oladigan har kim `docker run -v /:/host` bilan hostning butun fayl tizimini root sifatida o'qiy va yoza oladi. Serverda bu guruhga kim kirganini `sudo` guruhidek nazorat qiling.

## 3. Ishga tushirish: docker run

`docker run` aslida to'rt qadam: image yo'q bo'lsa `pull`, `create`, `start`, va (foreground bo'lsa) `attach`.

```
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

| Flag | Ma'nosi |
|------|---------|
| `-d` | detached: fonda ishlaydi, ID chop etiladi |
| `-i` | stdin ochiq qoladi |
| `-t` | pseudo-TTY ajratadi (rang, prompt, `Ctrl+C` signal sifatida) |
| `--rm` | konteyner to'xtagach avtomatik o'chiriladi (anonim volume'lari bilan) |
| `--name web` | nom. Berilmasa tasodifiy (`quirky_morse`) |
| `-p 8080:80` | port publishing, `HOST:CONTAINER` |
| `-e KEY=val`, `--env-file f` | environment o'zgaruvchilari |
| `--label k=v` | metadata, `--filter label=k=v` bilan tanlash uchun |

`-it` interaktiv shell uchun (`docker run --rm -it alpine:3.22 sh`), `-d` servis uchun. `-t` ni pipe yoki skript ichida ishlatmang: TTY chiqishga `\r` qo'shadi va stdout bilan stderr'ni birlashtiradi.

`COMMAND` berilsa image'dagi `CMD` ni almashtiradi (2-dars, `ENTRYPOINT` bilan farqi).

### Port publishing

Konteyner o'z network namespace'ida, uning 80-porti hostdan to'g'ridan-to'g'ri ko'rinmaydi. `-p` hostdagi portni konteyner portiga yo'naltiradi (mexanizmi: NAT, 3-darsda).

| Yozuv | Natija |
|-------|--------|
| `-p 8080:80` | hostning **barcha** interfeyslarida 8080 |
| `-p 127.0.0.1:8080:80` | faqat localhost |
| `-p 80` | host porti tasodifiy, `docker port <name>` bilan ko'ring |
| `-P` | image'dagi barcha `EXPOSE` portlar tasodifiy host portlariga |

**Tuzoq: `-p 8080:80` butun dunyoga ochadi va `ufw` ni chetlab o'tadi.** Docker o'z iptables qoidalarini `ufw` qoidalaridan oldin ishlaydigan zanjirlarga yozadi. `ufw deny 8080` yozilgan bo'lsa ham port tashqaridan ochiq qoladi. Faqat lokal kerak bo'lsa har doim `127.0.0.1:` yozing. Ma'lumotlar bazasi portini shu tarzda internetga ochib qo'yish eng ko'p uchraydigan xato.

### Environment

`-e NAME=value` yoki `--env-file app.env` (har qatorda `KEY=value`, qo'shtirnoqlar qiymatning bir qismi bo'lib qoladi). `-e NAME` (qiymatsiz) shell'dagi qiymatni uzatadi. Environment `docker inspect` da ochiq ko'rinadi va child jarayonlarga meros o'tadi, shuning uchun parol uchun yaxshi joy emas (4-dars va 5-darsda secrets).

## 4. Hayot sikli va holatlar

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
| `paused` | jarayonlar cgroup freezer bilan muzlatilgan |
| `restarting` | restart policy qayta ishga tushirmoqda |
| `exited` | PID 1 tugagan, fayl tizimi va loglar saqlanib turibdi |
| `dead` | o'chirish yarim yo'lda qolgan, resurs band |

Asosiy qoida: **konteyner PID 1 jarayoni yashagan vaqtgacha yashaydi.** PID 1 tugasa konteyner `exited` bo'ladi, boshqa jarayonlar o'ldiriladi. Shuning uchun servis foreground'da ishlashi kerak (`nginx -g 'daemon off;'`), fonga o'tib ketadigan (daemonize) jarayon konteynerni darhol tugatadi.

| Buyruq | Vazifa |
|--------|--------|
| `docker ps` / `docker ps -a` | ishlayotgan / barcha konteynerlar |
| `docker stop <c>` | `SIGTERM`, 10 sekund kutadi, keyin `SIGKILL` |
| `docker kill <c>` | darhol `SIGKILL` (`-s` bilan boshqa signal) |
| `docker start <c>` | `exited` konteynerni o'sha fayl tizimi bilan qayta boshlaydi |
| `docker rm <c>` | o'chiradi. `-f` ishlayotganini ham (`SIGKILL`) |
| `docker pause` / `unpause` | muzlatish |

### Exit code'lar

`docker ps -a` ning `STATUS` ustunida `Exited (N)`. `docker inspect -f '{{.State.ExitCode}}' <c>` ham beradi.

| Kod | Ma'nosi |
|-----|---------|
| 0 | muvaffaqiyatli tugadi |
| 1 | ilova xatosi |
| 125 | `docker run` ning o'zi xato berdi (noto'g'ri flag) |
| 126 | buyruq topildi, lekin bajarib bo'lmadi (ruxsat yo'q) |
| 127 | buyruq topilmadi |
| 137 | 128 + 9: `SIGKILL` (OOM yoki `stop` timeout) |
| 143 | 128 + 15: `SIGTERM` bilan tugadi |

### PID 1 va signallar

Kernel PID 1 ga maxsus munosabatda: handler o'rnatilmagan signallarning default harakati (shu jumladan `SIGTERM` da tugash) PID 1 uchun ishlamaydi. Natijada `SIGTERM` handler yozilmagan ilova `docker stop` ni e'tiborsiz qoldiradi, Docker 10 sekund kutib `SIGKILL` yuboradi: har deploy 10 sekund sekinlashadi va ilova ulanishlarni toza yopa olmaydi (exit 137).

Yechimlar: ilovada `SIGTERM` ni ushlash (Node'da `process.on('SIGTERM', ...)`), yoki `--init` flag'i: Docker PID 1 sifatida kichik init (`docker-init`, tini) qo'yadi, u signallarni ilovaga uzatadi va zombie jarayonlarni yig'adi. Kutish vaqti: `docker stop -t 30` yoki `--stop-timeout`.

## 5. Kuzatish va diagnostika

| Buyruq | Nima beradi |
|--------|-------------|
| `docker logs <c>` | PID 1 ning stdout va stderr'i. `-f` kuzatish, `--tail 50`, `--since 10m`, `-t` vaqt belgisi |
| `docker exec -it <c> sh` | ishlayotgan konteynerda **yangi** jarayon (o'sha namespace'larda) |
| `docker top <c>` | konteyner jarayonlari (host PID'lari bilan) |
| `docker stats` | CPU, xotira, tarmoq, PID soni jonli. `--no-stream` bir marta |
| `docker inspect <c>` | to'liq konfiguratsiya va holat, JSON |
| `docker diff <c>` | image'ga nisbatan o'zgargan fayllar (A/C/D) |
| `docker cp <c>:/path ./local` | fayl nusxalash (to'xtagan konteynerdan ham) |
| `docker events` | daemon hodisalari oqimi |

`exec` faqat `running` konteynerda ishlaydi. Darhol yiqilayotgan konteynerni tekshirish uchun: `docker logs`, yoki buyruqni almashtirib ishga tushirish (`docker run --rm -it --entrypoint sh IMAGE`).

**Tuzoq: loglar faqat stdout/stderr dan.** Ilova faylga yozsa `docker logs` bo'sh. Konteynerda log faylga emas, stdout'ga yoziladi. Default `json-file` log driver'ida rotatsiya yo'q, fayl cheksiz o'sadi va diskni to'ldiradi. Cheklash: `--log-opt max-size=10m --log-opt max-file=3` yoki daemon sozlamasida.

### inspect va format

`--format` (`-f`) Go template qabul qiladi:

```
docker inspect -f '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}' web
docker inspect -f '{{.State.Pid}}' web
docker inspect -f '{{json .Config.Env}}' web
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' web
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
```

`.State.Pid` bu konteyner PID 1 ining hostdagi PID'i, u orqali `/proc/<pid>/ns/` va cgroup yo'liga chiqiladi.

## 6. Resurs limitlari

Default: limit yo'q. Bitta xotira oqishi (memory leak) bor konteyner butun hostni OOM'ga olib boradi va kernel istalgan jarayonni, shu jumladan boshqa servislarni o'ldirishi mumkin.

| Flag | cgroup fayli | Limitga yetganda |
|------|--------------|------------------|
| `--memory 256m` (`-m`) | `memory.max` | kernel OOM killer konteyner jarayonini o'ldiradi, exit 137, `OOMKilled: true` |
| `--memory-swap` | `memory.swap.max` | `--memory` bilan teng qo'yilsa swap ishlatilmaydi |
| `--cpus 0.5` | `cpu.max` | o'ldirilmaydi, **throttle** qilinadi (sekinlashadi) |
| `--pids-limit 100` | `pids.max` | `fork` xato qaytaradi (fork bomb'dan himoya) |

Xotira siqilmaydigan resurs (yetmasa o'ldiriladi), CPU siqiladigan (yetmasa kutadi). Bu farq Kubernetes'dagi requests/limits mavzusining asosi.

**Tuzoq: runtime limitni ko'rmasligi mumkin.** Konteyner ichida `free` va `/proc/meminfo` hostning xotirasini ko'rsatadi. Zamonaviy Node.js, Go, JVM cgroup limitini o'qiydi, eski versiyalar va ayrim kutubxonalar o'qimaydi va heap'ni host xotirasiga qarab o'lchaydi, natija OOM kill. Node'da `--max-old-space-size` ni limitdan pastroq aniq berish xavfsiz.

## 7. Restart policy

| Policy | Xatti-harakat |
|--------|---------------|
| `no` (default) | qayta ishga tushirilmaydi |
| `on-failure[:N]` | faqat exit code nol bo'lmaganda, ixtiyoriy N martagacha |
| `always` | har doim. Qo'lda `stop` qilingan bo'lsa ham daemon qayta ishga tushganda start bo'ladi |
| `unless-stopped` | `always` kabi, lekin qo'lda to'xtatilgan konteyner daemon restart'idan keyin to'xtagan holda qoladi |

- Qo'lda `docker stop` qilingan konteynerni hech bir policy darhol qayta ko'tarmaydi.
- Qayta urinishlar orasidagi kutish har safar ikki barobar oshadi (100 ms dan boshlab, 1 minutgacha), konteyner 10 sekunddan ko'p yashasa hisob qaytadan boshlanadi.
- `--restart` va `--rm` birga ishlatilmaydi.
- Mavjud konteynerda o'zgartirish: `docker update --restart unless-stopped web`.

Restart policy bitta hostdagi oddiy self-healing. U konteyner "ishlayapti, lekin javob bermayapti" holatini ko'rmaydi (healthcheck, 3-dars) va host o'lsa yordam bermaydi (orkestrator, 5-dars).

## Tuzoqlar

- `-p 5432:5432` bazani barcha interfeyslarga ochadi va `ufw` buni to'smaydi. Lokal uchun `127.0.0.1:5432:5432`.
- Xotira limiti yo'q konteyner hostni OOM'ga olib boradi. Production'da har konteynerda `--memory` bo'lsin.
- `SIGTERM` ni ushlamaydigan PID 1: har to'xtatish 10 sekund va `SIGKILL`, tugallanmagan so'rovlar uziladi.
- `json-file` log rotatsiyasiz: bir necha haftada `/var/lib/docker` to'ladi, barcha konteynerlar to'xtaydi.
- Konteyner ichida qo'lda qilingan o'zgarish (`exec` bilan paket o'rnatish, config tahrirlash) `rm` dan keyin yo'qoladi. O'zgarish image yoki volume'da bo'lishi kerak.
- `docker` guruhi va `docker.sock` mount qilish root berishga teng. CI agent yoki monitoring konteyneriga socket berishdan oldin o'ylang.
- `--privileged` deyarli barcha izolyatsiyani o'chiradi. Kerakli bitta capability'ni `--cap-add` bilan bering.
- Parolni `-e` bilan berish: `docker inspect`, `/proc/<pid>/environ` va shell history'da ochiq qoladi.
- `restart: always` bilan darhol yiqiladigan konteyner cheksiz restart siklida qoladi va muammoni yashiradi. `docker ps` dagi `Restarting` va `RestartCount` ga qarang.
- `-it` ni skriptda ishlatish: `the input device is not a TTY` xatosi yoki buzilgan chiqish.

## Manbalar

- https://docs.docker.com/get-started/docker-overview/ – arxitektura umumiy ko'rinishi
- https://docs.docker.com/reference/cli/docker/container/run/ – `docker run` barcha flag'lari
- https://docs.docker.com/engine/containers/resource_constraints/ – xotira va CPU limitlari
- https://docs.docker.com/engine/containers/start-containers-automatically/ – restart policy
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker va iptables, ufw bilan munosabati
- https://docs.docker.com/engine/logging/configure/ – log driver'lar va rotatsiya
- https://docs.docker.com/engine/security/ – namespaces, cgroups, capabilities, daemon hujum yuzasi
- https://man7.org/linux/man-pages/man7/namespaces.7.html – `man 7 namespaces`
- https://man7.org/linux/man-pages/man7/cgroups.7.html – `man 7 cgroups`
- https://github.com/opencontainers/runtime-spec – OCI runtime spetsifikatsiyasi
- Rice, "Container Security", 3–4-boblar (cgroups, namespaces)

---

## Vazifalar

Barchasini `docker/01-containers/` da bajaring (`make new m=docker n=01 name=containers`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Vazifa so'ragan fayllar (skript, env fayl) shu papkada saqlanadi.

### A. Konteyner bu jarayon

1. **Architecture chain.** `docker version` va `docker info` dan client, server, containerd, runc versiyalarini, cgroup versiyasi va driver'ini yozib oling. `nginx:1.28-alpine` ni `-d` bilan ishga tushirib, hostda `ps -ef --forest | grep -B2 nginx` orqali `containerd-shim-runc-v2` va uning ostidagi nginx jarayonlarini toping. Nima uchun nginx'ning otasi `dockerd` emas, shim ekanini izohlang.

2. **Same kernel.** Hostda va `alpine:3.22` konteynerida `uname -r` hamda `cat /etc/os-release` ni solishtiring. Qaysi biri bir xil, qaysi biri farq qiladi va nima uchun?

3. **PID namespace.** Ishlayotgan nginx konteynerida `docker exec <c> ps` va hostda `docker top <c>` ni solishtiring. Bitta jarayonning ikki xil PID'ini yozing. `docker inspect -f '{{.State.Pid}}'` qaysi biriga mos?

4. **Namespace IDs.** Konteyner PID 1 ining host PID'i uchun `sudo ls -l /proc/<pid>/ns/` va o'z shell'ingiz uchun `ls -l /proc/$$/ns/` ni solishtiring. Qaysi namespace'lar farq qiladi, qaysilari bir xil (`user` ga e'tibor bering) va bu nimani anglatadi?

5. **cgroup files.** Konteynerni `--memory 128m --cpus 0.5 --pids-limit 50` bilan ishga tushiring. Hostda `/sys/fs/cgroup/system.slice/docker-<id>.scope/` ichidan `memory.max`, `cpu.max`, `pids.max` ni o'qing, keyin xuddi shu qiymatlarni konteyner ichidagi `/sys/fs/cgroup/` dan o'qing. `cpu.max` dagi ikki son nimani bildiradi? Limitsiz konteynerda `memory.max` nima?

### B. Hayot sikli

6. **Run modes.** `alpine:3.22` ni uch usulda ishga tushiring: `docker run alpine:3.22 echo hi`, `docker run -it alpine:3.22 sh`, `docker run -d alpine:3.22 sleep 300`. Har biridan keyin `docker ps -a` holatini yozing. Keyin `docker run -d alpine:3.22 sh` nima uchun darhol `Exited (0)` bo'lishini, `-dit` bilan esa ishlab turishini izohlang.

7. **Lifecycle states.** Bitta konteynerni `create`, `start`, `pause`, `unpause`, `stop`, `start`, `rm` bosqichlaridan o'tkazing, har qadamdan keyin `docker inspect -f '{{.State.Status}}'` ni yozing. `stop` dan keyingi `start` da konteyner ichida avval yaratilgan fayl saqlanganmi? `rm` dan keyin-chi?

8. **Exit codes.** Uchta konteyner ishga tushiring: `sh -c 'exit 3'`, mavjud bo'lmagan buyruq (`nosuchcmd`), va `sleep 300` ni `docker kill` bilan o'ldiring. Uchala exit code'ni yozing va har birini izohlang.

9. **PID 1 and SIGTERM.** `docker run -d --name s1 alpine:3.22 sleep 300` ni `time docker stop s1` bilan to'xtating, vaqt va exit code'ni yozing. Xuddi shuni `--init` bilan (`s2`) takrorlang. Farqni PID 1 ning signal qoidasi orqali tushuntiring. `docker stop -t 2` nimani o'zgartiradi?

10. **The --rm flag.** `--rm` bilan va `--rm` siz bittadan qisqa konteyner ishga tushiring, `docker ps -a` da farqni ko'rsating. `--rm` bilan `--restart always` ni birga berib ko'ring, xatoni yozing.

### C. Port, env, diagnostika

11. **Port publishing.** nginx'ni uch marta ishga tushiring: `-p 8081:80`, `-p 127.0.0.1:8082:80`, `-p 80` (host porti tasodifiy). `docker port` va `ss -tlnp` bilan har biri qaysi manzilda tinglayotganini ko'rsating. Qaysi biri tarmoqdagi boshqa mashinadan ochiq? Band portga ikkinchi konteynerni ulab ko'ring va xatoni yozing.

12. **Environment variables.** `app.env` fayl yarating (2–3 o'zgaruvchi) va konteynerni `--env-file app.env -e EXTRA=1` bilan ishga tushiring. `docker exec <c> env` va `docker inspect -f '{{json .Config.Env}}'` natijasini solishtiring. Nima uchun bu parol saqlash uchun yomon joy ekanini 2 gapda yozing. `app.env` ni commit qilmang.

13. **Logs.** nginx konteyneriga `curl` bilan bir necha so'rov yuboring (mavjud bo'lmagan sahifaga ham). `docker logs` ni `--tail`, `--since`, `-t`, `-f` bilan ishlating. `docker logs <c> 2>/dev/null` va `docker logs <c> >/dev/null` bilan access log va error log qaysi oqimga ketayotganini aniqlang. `docker inspect -f '{{.LogPath}}'` qayerni ko'rsatadi?

14. **Exec and diff.** Ishlayotgan nginx'da `docker exec` orqali `/usr/share/nginx/html/index.html` ni o'zgartiring va `curl` bilan tekshiring. `docker diff` nimani ko'rsatadi? Konteynerni `rm -f` qilib, xuddi shu buyruq bilan qayta yarating: o'zgarish qani va nima uchun?

15. **Inspect format.** Bitta `docker inspect -f` buyrug'i bilan (jq'siz) quyidagilarni oling: holat, exit code, restart soni, IP manzil, image nomi, publish qilingan portlar. Keyin `docker ps --format` bilan faqat nom, holat va portlardan iborat jadval chiqaring.

### D. Limit va restart

16. **OOM kill.** `docker run --name oom -m 64m alpine:3.22 sh -c 'tail /dev/zero'` ni ishga tushiring. Exit code va `docker inspect -f '{{.State.OOMKilled}}'` ni yozing. `journalctl -k --since "5 min ago" | grep -i oom` da kernel yozuvini toping. Limit bo'lmaganda bu buyruq hostga nima qilar edi (ishlatib ko'rmang, izohlang)?

17. **CPU throttling.** `docker run -d --name burn --cpus 0.5 alpine:3.22 sh -c 'while :; do :; done'` ni ishga tushiring. `docker stats --no-stream` da CPU foizini, konteyner cgroup'idagi `cpu.stat` faylidan `nr_throttled` qiymatining o'sishini ko'rsating. Nima uchun CPU limitidan oshgan konteyner o'ldirilmaydi, xotiradan oshgani esa o'ldiriladi?

18. **Fork limit.** `--pids-limit 20` bilan `alpine:3.22` shell'ini oching va sikl ichida 30 ta `sleep 100 &` ishga tushirishga urining. Xato matnini yozing. `docker stats` ning `PIDS` ustuni nimani ko'rsatadi?

19. **Restart policies.** `sh -c 'sleep 3; exit 1'` buyrug'i bilan uchta konteyner: `--restart no`, `--restart on-failure:3`, `--restart always`. 40 sekunddan keyin har birining holati va `{{.RestartCount}}` ini yozing. `always` konteynerida restartlar orasidagi vaqt qanday o'zgarishini `docker events --filter container=<c>` yoki `docker ps` orqali kuzating va izohlang. Keyin `always` ni `docker stop` qiling: qayta ko'tariladimi?

### E. Yakuniy

20. **Break and diagnose.** Quyidagi uchta buzilgan holatni yarating va har birida faqat `docker ps -a`, `docker logs`, `docker inspect` yordamida sababni toping, README'ga "alomat, qanday topdim, sabab" shaklida yozing: (a) `docker run -d nginx:1.28-alpine nginx -g 'daemon on;'`; (b) `docker run -d -m 16m nginx:1.28-alpine tail /dev/zero`; (c) hech qanday `-e` siz ishga tushirilgan `postgres:17-alpine`.

21. **Container report script.** `report.sh` yozing: argument sifatida konteyner nomini oladi va bitta ekranda chiqaradi: holat, exit code, OOMKilled, restart soni va policy, host PID, IP, portlar, xotira limiti (bayt), oxirgi 5 qator log. Faqat `docker inspect -f`, `docker logs`, `docker port` ishlating. Mavjud bo'lmagan konteyner uchun tushunarli xabar va nol bo'lmagan exit code. `shellcheck report.sh` toza bo'lsin.

22. **Cleanup.** Dars davomida yaratilgan barcha konteynerlarni label filtri orqali o'chiring (label qo'yilmaganlarini nomi bilan). `docker ps -a` va `docker system df` natijasini yozing. `docker container prune`, `docker rm -f $(docker ps -aq)` va label filtri bilan o'chirish farqini, birinchi ikkitasi nima uchun umumiy serverda xavfli ekanini izohlang.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. `shellcheck docker/01-containers/report.sh` hech narsa chiqarmaydi.
3. `docker ps -a` da shu darsdan qolgan konteyner yo'q, `app.env` commit qilinmagan.
4. Menga xabar bering, `README.md` va skriptni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Namespace va cgroup har biri qaysi savolga javob beradi? Konteyner VM dan nimasi bilan farq qiladi?
- `docker run` bosilgandan nginx jarayoni paydo bo'lguncha qaysi komponentlar ishlaydi va shim nima uchun kerak?
- Konteyner qachon `exited` holatiga o'tadi? Nima uchun servis foreground'da ishlashi kerak?
- `docker stop` nima qiladi va PID 1 `SIGTERM` ni ushlamasa nima bo'ladi?
- Exit code 137 ning ikki xil sababi qanday va ularni qanday ajratasiz?
- `-p 8080:80` va `-p 127.0.0.1:8080:80` farqi nima, `ufw` bu yerda nima uchun yordam bermaydi?
- Xotira limiti va CPU limitiga yetganda nima sodir bo'ladi, farq nimada?
- `always` va `unless-stopped` qaysi vaziyatda turlicha ishlaydi?
- `docker exec` va `docker run` farqi nima? Darhol yiqilayotgan konteynerni qanday tekshirasiz?
- Nima uchun `docker` guruhi a'zoligi root huquqiga teng?
