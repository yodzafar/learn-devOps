# 5-dars: Orkestratsiyaga kirish (Docker Swarm va Kubernetes)

Maqsad: orkestrator qaysi muammolarni yechishini noldan tushunish va ularni amalda ko'rish. Orkestrator bu konteynerlarni bir necha mashinaga joylashtiradigan, o'lganini qayta ko'taradigan va yangilashni boshqaradigan dastur. 4-darsda Compose bitta hostda stack ko'tardi, lekin host o'lsa hamma narsa o'ladi, yangilash paytida uzilish bo'ladi, nusxalar orasida trafikni o'zingiz taqsimlaysiz. Bu darsda shu bo'shliqlarni Docker Swarm bilan qo'lda yopasiz (u Docker Engine ichida, o'rnatish kerak emas, Compose fayl formati bilan ishlaydi), keyin xuddi shu tushunchalarni Kubernetes atamalarida xarita sifatida ko'rasiz. Kubernetes amaliyoti alohida modulda, bu yerda faqat arxitektura, uchta asosiy obyekt va bitta `kind` vazifasi. Dars modul mini-loyihasi bilan tugaydi.

Taxminiy vaqt: 7 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh; ikkinchi kun 4–5 bo'limlar va 6–7-vazifalar; uchinchi kun 6-bo'lim va 8–10-vazifalar; to'rtinchi kun "Birga bajaramiz" va C guruh; beshinchi kun 7–8 bo'limlar va D guruh; oltinchi va yettinchi kun E guruh (mini-loyiha, runbook, tozalash). Mavzu yangi, shoshilmang. Diqqatni quyidagilarga qarating: desired state va reconciliation, service va task (konteyner) farqi, routing mesh va VIP orqali service discovery, rolling update parametrlari va healthcheck bilan bog'liqligi, secret'larning o'zgarmasligi, Compose fayl bilan stack fayl orasidagi farqlar.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi maydonma-maydon izoh bilan solishtiring. ID, IP, token va versiyalar sizda boshqa bo'ladi, darsda ular `<...>` bilan belgilangan. Misollar ataylab vazifalardagidan boshqa servis (`l5-demo`, `httpd`) ustida, vazifaga o'zingiz moslaysiz. Swarm rejimini har mashg'ulot oxirida o'chiring (Laboratoriya bo'limi), ertaga qayta yoqish bir buyruq.

## Laboratoriya

Hamma narsa host'dagi Docker'da bajariladi, `lab` VM bu darsda ishlatilmaydi (2G xotira `kind` va uch node'li klaster uchun kichik). Uch muhit bor:

| Muhit | Qayerda | Vazifalar |
|-------|---------|-----------|
| Bir node'li Swarm | host'dagi Docker Engine (macOS'da Docker Desktop VM'i) | A, B, E guruhlar |
| Uch node'li Swarm | `docker:29-dind` konteynerlari (Docker ichida Docker) | C guruh |
| `kind` klasteri | Docker konteynerlari ichidagi Kubernetes | D guruh |

**Bir node'li Swarm.** `docker swarm init` host'dagi engine'ni Swarm rejimiga o'tkazadi: `ingress` va `docker_gwbridge` tarmoqlari paydo bo'ladi, 2377-port tinglanadi. Oddiy konteynerlaringiz va Compose project'laringiz ishlashda davom etadi. Manzilni aniq bering, shunda klaster boshqaruvi tashqi tarmoq interfeysiga chiqmaydi:

```
docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
docker info --format '{{.Swarm.LocalNodeState}}'     # active
```

Qaytarish (har mashg'ulot oxirida majburiy, tunga yoqiq qoldirilmaydi):

```
docker stack rm <stack>            # for every stack of this lesson
docker service ls                  # must be empty before leaving
docker swarm leave --force
docker network rm docker_gwbridge
docker info --format '{{.Swarm.LocalNodeState}}'     # inactive
```

`docker swarm leave --force` klaster holatini butunlay o'chiradi: service'lar, secret'lar, overlay tarmoqlar yo'qoladi. Named volume'lar va image'lar qoladi. Shuning uchun ertasi kuni davom ettirish uchun kerak bo'lgan hamma narsa fayllarda (`stack.yaml`, skriptlar) bo'lishi kerak, qo'lda terilgan buyruqlarda emas.

**Diqqat:** Swarm'da publish qilingan port barcha interfeyslarda ochiladi, `127.0.0.1` ga bog'lab bo'lmaydi (4-bo'lim). Vazifalarni ishonchli tarmoqda bajaring va ishdan keyin servislarni o'chiring.

**dind klasteri.** dind (Docker-in-Docker) bu ichida o'z `dockerd` daemon'i ishlaydigan konteyner. Har "node" bitta shunday `--privileged` konteyner. Host'dagi Swarm holatiga bog'liq emas: host `inactive` bo'lsa ham ishlaydi. Barcha resurslar `l5-` prefiksi bilan. `--privileged` konteyner izolyatsiyasi deyarli yo'q (1-dars), ularni mashg'ulot tugashi bilan o'chiring. `docker:29-dind` image'i `amd64` va `arm64` uchun bor. Tag'dagi major raqam host engine'ingiznikiga mos bo'lsin: `docker version --format '{{.Server.Version}}'` bilan tekshiring, farq qilsa o'zingizdagi major raqamli `-dind` tag'ini oling.

**kind va kubectl.** `kind` (Kubernetes in Docker) node'lari konteyner bo'lgan lokal Kubernetes klasterini yaratadi, `kubectl` Kubernetes'ning CLI'si. Ikkalasi bittadan binary. Joriy relizlar: https://github.com/kubernetes-sigs/kind/releases va https://kubernetes.io/releases/.

Zorin (`amd64`, `sudo` siz, `~/.local/bin` ga; bu papka `PATH` da bo'lishi kerak, `echo $PATH` bilan tekshiring):

```
# kind: replace <version> with the current release tag from the releases page, e.g. v0.NN.N
curl -Lo ./kind https://kind.sigs.k8s.io/dl/<version>/kind-linux-amd64
chmod +x ./kind && mv ./kind ~/.local/bin/kind

# kubectl: latest stable
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl && mv ./kubectl ~/.local/bin/kubectl
```

macOS (`arm64`, Homebrew):

```
brew install kind kubectl
```

Ikkalasida tekshirish: `kind version` va `kubectl version --client`. Mac'da Docker Desktop o'z `kubectl` ini ham olib kelishi mumkin, `which -a kubectl` qaysi biri birinchi turganini ko'rsatadi.

Xotira: kind node image'i katta (1 GB atrofida), birinchi `kind create cluster` yuklash tufayli bir necha daqiqa oladi. Bir node'li klaster bo'sh holatda ham sezilarli xotira band qiladi, aniq qiymatni `docker stats --no-stream` bilan o'zingiz o'lchang. Mac'da Docker Desktop VM'iga kamida 4 GB ajratilgan bo'lsin (Settings, Resources). kind klasteri, dind klasteri va mini-loyiha stack'ini bir vaqtda ushlab turmang. Tozalash: `kind delete cluster --name l5`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Engine host kernel'ida, `amd64`. Swarm node'i host'ning o'zi: `docker_gwbridge` interfeysi `ip addr` da, 2377-port `ss -ltn` da, overlay'ning VXLAN interfeyslari ko'rinadi. dind node'larining IP'lariga host'dan to'g'ridan-to'g'ri `curl` qilish mumkin. Publish qilingan service porti host'ning barcha interfeyslarida, shu jumladan ofis tarmog'ida ochiladi. `kind`, `kubectl` release binary sifatida `~/.local/bin` da. |
| macOS (uy) | Engine Docker Desktop'ning yashirin Linux VM'ida, `arm64`. Swarm node'i o'sha VM: node IP'si, `ingress` tarmog'i, `docker_gwbridge`, VXLAN interfeyslari Mac'dan ko'rinmaydi, `ip` va `ss` buyruqlari ham yo'q. Publish qilingan service porti `localhost:<port>` da ishlaydi. dind node'larining IP'lariga Mac'dan yetib bo'lmaydi, faqat publish qilingan port (`127.0.0.1:8088`) va `docker exec` orqali ishlaysiz; vazifalar shunga moslab yozilgan. `kind`, `kubectl` Homebrew'dan. |

`docker` CLI buyruqlari va ularning chiqishi ikkala mashinada bir xil. dind ichidagi Swarm (overlay tarmoq bilan) ikkalasida ishlashi kerak; Mac'da overlay bo'yicha xato chiqsa, xabarni README'ga yozing va C guruhni ofisda bajaring.

**Ikkinchi mashinada tiklash.** Swarm holati, secret'lar, dind va kind klasterlari mashinalar orasida ko'chmaydi: ofisda `swarm init` qilingan klaster uyda mavjud emas. Ko'chadiganlar: git'dagi fayllar (`stack.yaml`, `cluster-up.sh`, README) va registry'dagi image'lar. Ikkinchi mashinada: `git pull`, `docker login` (2-dars), `docker swarm init ...`, secret'larni qayta yarating (qiymat git'da yo'q, yangi mashinada volume ham yangi, shuning uchun yangi qiymat bersangiz bo'ladi), `docker stack deploy`. 10-vazifa 4-darsdagi `docker/04-compose/stack/` fayllariga tayanadi, ular git'da. Image'lar ikkala arxitektura uchun kerak: 2-darsdagi `buildx --platform linux/amd64,linux/arm64` bilan push qiling, aks holda ofisda build qilingan image uyda `exec format error` beradi.

---

## 1. Nima uchun orkestratsiya

### Bitta host yetmaydigan nuqtalar

4-darsdagi `docker compose up` bitta mashinada bir necha konteynerni ko'taradi. Production'da bu yetmaydigan joylar:

| Muammo | Qo'lda | Orkestrator |
|--------|--------|-------------|
| **Scheduling**: konteyner qaysi mashinada ishlasin | o'zingiz tanlaysiz, SSH qilasiz | bo'sh resurs, cheklov va label'larga qarab o'zi joylashtiradi |
| **Self-healing**: konteyner yoki host o'ldi | kimdir uyg'onadi, qo'lda restart | holatni kuzatadi, yetishmayotgan nusxani boshqa node'da ko'taradi |
| **Scaling**: 3 nusxadan 10 ga | 7 marta `run`, proxy config'ni yangilash | bitta son o'zgaradi |
| **Service discovery va load balancing**: nusxalar IP'si doim o'zgaradi | nginx reload (4-dars, stale upstream) | barqaror nom va virtual IP, trafik sog'lom nusxalarga |
| **Rolling update va rollback** | to'xtat, yangila, ishga tushir: uzilish | nusxalarni navbat bilan almashtiradi, xato bo'lsa qaytaradi |
| **Config va secret** | fayllarni har hostga nusxalash | markaziy saqlanadi, kerakli konteynerga yetkaziladi |

Bu yerda: **node** klasterdagi bitta mashina, **klaster** birga boshqariladigan node'lar to'plami, **service discovery** servis boshqa servisning manzilini nom orqali topishi, **load balancing** so'rovlarni nusxalar orasida taqsimlash.

### Mexanizm: desired state va reconciliation

Asosiy g'oya imperativ emas, deklarativ. Imperativ buyruq "3 ta nusxa ishga tushir" deydi va bajarilgach unutiladi. Deklarativ tavsif "3 ta nusxa **bo'lishi kerak**" deydi va saqlanib qoladi. Bu saqlangan tavsif **desired state** (kerakli holat), klasterda haqiqatan ishlab turgan narsa **actual state**. Orkestrator cheksiz siklda ishlaydi:

```
observe actual state -> compare with desired state -> act to remove the difference -> repeat
```

Bu sikl **reconciliation** (moslashtirish) deyiladi. Nusxa o'lsa farq paydo bo'ladi (kerak 3, bor 2) va sikl uni yopadi. Siz sonni 5 ga o'zgartirsangiz ham farq paydo bo'ladi (kerak 5, bor 3). Image tag'ini o'zgartirsangiz, farq "eski versiyali 3 ta bor, yangi versiyali 3 ta kerak". Self-healing, scaling va rolling update shu bitta mexanizmning uch ko'rinishi. Swarm'da bu ishni manager ichidagi orchestrator, Kubernetes'da controller'lar bajaradi.

React bilan o'xshashlik bu yerda haqiqiy: siz DOM'ga "shu elementni qo'sh" demaysiz, `render` da UI qanday **bo'lishi kerakligini** qaytarasiz, React esa oldingi daraxt bilan solishtirib (reconciliation) faqat farqni DOM'ga qo'llaydi. Orkestratorda "state" bu stack fayl, "DOM" bu klasterdagi konteynerlar. Farqi: DOM o'zi buzilmaydi, klaster esa buziladi (node o'ladi, jarayon yiqiladi), shuning uchun orkestrator solishtirishni faqat siz o'zgartirganda emas, doim takrorlaydi.

### Misol: farqni Swarm'siz ko'rish

1-darsdagi restart policy ham "o'lsa qayta ko'tar" deydi, lekin u desired state emas. Solishtiring:

```
$ docker run -d --name l5-pet --restart always httpd:2.4-alpine
<container id>
$ docker rm -f l5-pet
l5-pet
$ docker ps -a --filter name=l5-pet --format '{{.Names}}'
$
```

Birinchi buyruq konteyner yaratdi va ID'sini chiqardi. `docker rm -f` uni o'chirdi. Uchinchi buyruq bo'sh qaytdi: hech kim uni qayta yaratmadi. Restart policy **mavjud konteyner** jarayoni tugaganda uni qayta start qiladi, lekin "shu nomli konteyner bo'lishi kerak" degan yozuv hech qayerda yo'q. Konteyner o'chsa yoki host yo'qolsa, tiklaydigan hech kim qolmaydi. Orkestratorda tavsif konteynerdan alohida saqlanadi (xuddi shu tajribani service bilan 3-vazifada qilasiz).

### Oqibat: cattle, not pets

Orkestrator ostida konteynerlar "cattle, not pets" (poda, uy hayvoni emas): ularga nom qo'yib parvarish qilinmaydi, istalgan payt o'ldirilishi va boshqa node'da qayta yaratilishi mumkin. Ilova shunga tayyor bo'lishi kerak: holat tashqarida (baza, volume), `SIGTERM` da toza to'xtash (1-dars), aniq healthcheck (3-dars), tez start, bog'liqliklarni qayta urinib kutish (4-dars).

### Real ishda qachon kerak

- Servis bitta serverga sig'may qolganda yoki bitta serverning o'lishi qabul qilib bo'lmaydigan bo'lganda.
- Deploy paytidagi uzilish (hatto 5 sekund) foydalanuvchiga ko'rinadigan bo'lganda.
- "Tunda konteyner yiqilib qoldi, ertalab bildik" takrorlanganda: bu self-healing yo'qligi.
- Incident tahlilida birinchi savol: desired state nima edi va actual state undan qayerda farq qildi.

### Nima uchun shunday

Imperativ skriptlar ("serverga kir, eski konteynerni to'xtat, yangisini ishga tushir") faqat hamma narsa kutilgandek bo'lganda ishlaydi: skript o'rtasida uzilsa tizim yarim holatda qoladi va uni kim tuzatishi aniq emas. Deklarativ modelda yarim holat oddiy holat: sikl keyingi aylanishda farqni ko'radi va davom etadi. Bu g'oya Google'ning ichki Borg tizimidan keladi, Kubernetes uning ochiq davomchisi. Muqobili (Ansible kabi vositalar bilan imperativ deploy, keyingi modullarda) kichik va kam o'zgaradigan tizimlarda yetarli, lekin node o'lganda o'zi hech narsa qilmaydi.

## 2. Swarm klasteri: node, manager, worker, Raft

### Bu nima

Docker Swarm (rasmiy nomi "Swarm mode") Docker Engine ichiga qurilgan orkestrator. Alohida o'rnatilmaydi: `docker swarm init` oddiy engine'ni bir node'li klasterga aylantiradi, `docker swarm join` boshqa engine'ni unga qo'shadi.

| Tushuncha | Ma'nosi |
|-----------|---------|
| **node** | klasterga qo'shilgan bitta Docker Engine |
| **manager** | klaster holatini saqlaydigan va qaror qiladigan node (qaysi task qayerda ishlaydi) |
| **worker** | faqat o'ziga tayinlangan task'larni bajaradigan node |
| **leader** | manager'lardan biri, hozir qarorlarni aynan u yozadi |

Default holatda manager ham task bajaradi, ya'ni u bir vaqtda worker vazifasini ham o'taydi. Bir node'li klaster shuning uchun ishlaydi.

### Misol: klasterni yaratish

```
$ docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
Swarm initialized: current node (<node id>) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token <token> 127.0.0.1:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

Birinchi qator: engine Swarm rejimiga o'tdi, bu node'ga ID berildi va u manager. Ikkinchi blok: boshqa mashinani worker sifatida qo'shish buyrug'i. `<token>` **join token**: klasterga qo'shilish uchun parol vazifasini bajaradigan satr, worker va manager uchun alohida. U secret hisoblanadi, README'ga yozilmaydi. `127.0.0.1:2377` manager'ning manzili: `--advertise-addr` boshqa node'larga "meni shu manzildan toping" degani, `--listen-addr` engine qaysi manzilda tinglashi. Loopback bergani uchun bu klasterga boshqa mashina qo'shila olmaydi, bir node'li laboratoriya uchun aynan shu kerak. Tokenni keyin qayta ko'rish: `docker swarm join-token worker`.

Ko'p node'li klasterda `docker node ls` (faqat manager'da ishlaydi) shunday ko'rinadi:

```
$ docker node ls
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
<id> *                        mgr-a      Ready     Active         Leader           <version>
<id>                          mgr-b      Ready     Active         Reachable        <version>
<id>                          mgr-c      Ready     Active         Reachable        <version>
<id>                          wrk-a      Ready     Active                          <version>
```

`ID` yonidagi `*` buyruq qaysi node'da bajarilganini ko'rsatadi. `STATUS` node tirikligi: `Ready` yoki `Down` (manager undan xabar olmay qo'ygan). `AVAILABILITY` scheduler unga task bera oladimi: `Active` (ha), `Pause` (yangi task yo'q, eskilar qoladi), `Drain` (yangi task yo'q, eskilar boshqa node'ga ko'chiriladi). `MANAGER STATUS`: `Leader` hozirgi yetakchi, `Reachable` boshqa sog'lom manager, bo'sh katak worker. Bu yerda uchta manager va bitta worker bor.

### Mexanizm: Raft va quorum

Klaster holati (service'lar, secret'lar, node'lar ro'yxati) manager'larda saqlanadi. Bir necha manager bir xil ma'lumotni saqlashi uchun ular **Raft** konsensus algoritmidan foydalanadi. Konsensus bu bir necha mashina bitta qiymat ustida kelishishi. Ishlash tartibi:

1. Manager'lar o'zaro ovoz berib bittasini leader qilib saylaydi.
2. Har o'zgarish (masalan "service yaratildi") leader'ga boradi, u yozuvni jurnalga (Raft log) qo'shadi va boshqa manager'larga yuboradi.
3. Yozuv manager'larning **ko'pchiligi** tasdiqlagandagina qabul qilingan hisoblanadi.
4. Leader yo'qolsa, qolganlar yangi leader saylaydi, bunga ham ko'pchilik ovozi kerak.

Ko'pchilik **quorum** deyiladi: N ta manager uchun `N/2` ning butun qismi plyus 1. Masalan 7 manager uchun quorum 4, demak 3 tasi yo'qolsa ham klaster qaror qabul qila oladi, 4 tasi yo'qolsa yo'q. "Ko'pchilik" talabi nima uchun: tarmoq ikkiga bo'linib qolsa (network partition), ikki tomon bir-biridan bexabar ikki xil qaror qabul qilmasligi kerak. Ko'pchilik faqat bir tomonda bo'la oladi, shuning uchun faqat o'sha tomon yoza oladi. Shu formuladan manager soni nima uchun toq tanlanishi kelib chiqadi (14-vazifada o'zingiz hisoblaysiz).

Muhim ajratish: manager'lar **control plane** (boshqaruv tekisligi: qaror qilish, holatni saqlash), task'lar ishlaydigan qism **data plane** (foydalanuvchi trafigi o'tadigan qism). Ular alohida: konteynerni manager emas, o'sha node'dagi engine ushlab turadi.

Node'lar orasida ochiq bo'lishi kerak bo'lgan portlar: `2377/tcp` (boshqaruv, Raft), `7946/tcp+udp` (node'lar bir-birini topishi, gossip), `4789/udp` (overlay tarmoq trafigi, VXLAN).

### Real ishda qachon kerak

- Klaster loyihalashda: nechta manager, ular qaysi availability zone'larda (bitta zonadagi 3 manager zona o'lganda quorum'ni yo'qotadi).
- Firewall qoidalarida yuqoridagi uch port (network moduli, 6-dars).
- Rejali xizmat ko'rsatishda `drain`: node'ni yangilashdan oldin undagi task'larni ko'chirish.
- Manager'ni backup qilishda: Raft holati yo'qolsa service ta'riflari va secret'lar ham yo'qoladi.

### Nima uchun shunday

Bitta manager eng sodda, lekin u yagona nosozlik nuqtasi (single point of failure). Ikki nusxa saqlash o'zi yetmaydi: ikki nusxa bir-biriga zid bo'lib qolsa qaysi biri to'g'ri ekanini hal qilish kerak, konsensus algoritmi aynan shuni hal qiladi. Raft ataylab tushunarli qilib loyihalangan algoritm, Kubernetes'ning holat ombori `etcd` ham uni ishlatadi. Muqobili: holatni tashqi bazada saqlash (eski "Docker Swarm standalone" Consul yoki etcd talab qilardi); Swarm mode buni engine ichiga olib, o'rnatishni bitta buyruqqa tushirdi.

## 3. Service, task va konteyner

### Bu nima

| Tushuncha | Ma'nosi |
|-----------|---------|
| **service** | desired state tavsifi: image, nusxalar soni, portlar, tarmoqlar, yangilash qoidalari. O'zi hech narsa ishlatmaydi |
| **task** | service'ning bitta nusxasi uchun "ish birligi": scheduler uni bitta node'ga tayinlaydi, node uni bitta konteyner sifatida ishga tushiradi |
| **konteyner** | task'ning amaldagi jarayoni (1-dars) |
| **slot** | replicated service'dagi o'rin raqami (`.1`, `.2`). Task almashadi, slot qoladi |

### Mexanizm

`docker service create` manager'ga faqat tavsifni yozadi. Keyin uch bosqich ishlaydi: **orchestrator** tavsifni o'qib kerakli sondagi task yozuvlarini yaratadi; **scheduler** har task uchun node tanlaydi (node `Active` mi, resurs yetadimi, constraint'larga mosmi, task'lar node'larga teng tarqalsin); o'sha node'dagi engine konteynerni yaratadi va holatini manager'ga xabar qiladi. Task bir yo'nalishda yashaydi: `New`, `Pending`, `Assigned`, `Preparing` (image pull), `Starting`, `Running`, oxirida `Complete`, `Failed`, `Shutdown` yoki `Rejected`. O'lgan task hech qachon qayta tirilmaydi: orchestrator o'sha slot uchun **yangi** task (yangi ID, yangi konteyner) yaratadi.

### Misol

```
$ docker service create --name l5-demo --replicas 2 -p 8085:80 httpd:2.4-alpine
<service id>
overall progress: 2 out of 2 tasks
1/2: running   [==================================================>]
2/2: running   [==================================================>]
verify: Service <service id> converged
```

Birinchi qator service ID. `overall progress` nechta task `Running` ga yetgani. `converged` actual state desired state'ga tenglashganini bildiradi (reconciliation tugadi).

```
$ docker service ls
ID             NAME      MODE         REPLICAS   IMAGE              PORTS
<id>           l5-demo   replicated   2/2        httpd:2.4-alpine   *:8085->80/tcp
```

`MODE` rejim (pastda). `REPLICAS` kasr ko'rinishida: chapda hozir ishlayotgan, o'ngda kerakli son. `1/2` yoki `0/2` bo'lsa farq hali yopilmagan. `PORTS` dagi `*` port har node'ning barcha interfeyslarida ochiqligini bildiradi.

```
$ docker service ps l5-demo
ID             NAME        IMAGE              NODE     DESIRED STATE   CURRENT STATE            ERROR     PORTS
<task id>      l5-demo.1   httpd:2.4-alpine   <host>   Running         Running 20 seconds ago
<task id>      l5-demo.2   httpd:2.4-alpine   <host>   Running         Running 20 seconds ago
```

Har qator bitta task. `NAME` service nomi va slot raqami. `NODE` scheduler tanlagan node. `DESIRED STATE` manager bu task uchun nima xohlaydi, `CURRENT STATE` node nima xabar qilgan va qachondan beri. Bu ikki ustun 1-bo'limdagi desired va actual state'ning task darajasidagi ko'rinishi. Task almashtirilganda eski qator o'chmaydi: uning `DESIRED STATE` i `Shutdown` bo'ladi, nomi oldida `\_` belgisi bilan yangi task ostida tarix sifatida qoladi, `ERROR` ustunida sabab yoziladi. To'liq xato matni uchun `--no-trunc`.

Qolgan kundalik buyruqlar:

```
docker service logs -f l5-demo            # logs of all tasks, prefixed with task name
docker service inspect --pretty l5-demo   # human-readable spec
docker service scale l5-demo=4            # change desired replica count
docker service rm l5-demo
```

### Rejimlar va joylashtirish

- `replicated` (default): N nusxa, scheduler node'larga tarqatadi.
- `global` (`--mode global`): har `Active` node'da aynan bittadan. Node qo'shilsa unda ham avtomatik paydo bo'ladi. Log yig'uvchi va monitoring agentlari uchun.

Scheduler'ga ta'sir qilish yo'llari: `--constraint` (qat'iy shart, masalan `node.labels.disk==ssd`; mos node bo'lmasa task `Pending` da kutadi), `--reserve-cpu` va `--reserve-memory` (node'da shuncha bo'sh resurs bo'lmasa task u yerga qo'yilmaydi), `--limit-cpu` va `--limit-memory` (konteynerga cgroup limiti, 1-dars). Reservation scheduling uchun hisob, limit esa ishlash paytidagi chegara.

`pm2` cluster mode bilan solishtirish: `pm2 start app.js -i 4` ham bitta mashinada 4 nusxa ko'taradi, yiqilganini qayta ishga tushiradi va portni ular orasida bo'lishadi. O'xshashlik shu yerda tugaydi: `pm2` faqat bitta mashina va faqat Node jarayonlari bilan ishlaydi, mashina o'lsa `pm2` ham o'ladi. Swarm service nusxalarni bir necha mashinaga tarqatadi va holatni mashinalardan tashqarida (Raft) saqlaydi.

### Real ishda qachon kerak

- "Servis ishlamayapti" tekshiruvining tartibi: `docker service ls` (REPLICAS kasri), `docker service ps --no-trunc <svc>` (qaysi task, qaysi node, qanday xato), keyin `docker service logs`.
- Task `Pending` da qolsa sabab deyarli doim scheduling: constraint mos emas, resurs yetmaydi, node `Drain`.
- Task qayta-qayta `Failed` bo'lsa sabab ilovada: exit code va loglar (1-dars).

### Nima uchun shunday

Service va task ajratilgani tufayli tavsif konteynerdan uzoq yashaydi: konteyner ham, node ham yo'qolishi mumkin, tavsif manager'larda qoladi. Task'ning qayta tirilmasligi tarixni saqlaydi: `docker service ps` da nima qachon va nima uchun o'lganini ko'rasiz. Muqobili (konteynerni joyida restart qilish, 1-darsdagi restart policy) tarixsiz va faqat bitta node ichida ishlaydi.

## 4. Tarmoq: overlay, VIP va routing mesh

### Bu nima

3-darsdagi bridge tarmoq bitta host ichida ishlaydi. Klasterda konteynerlar turli mashinalarda, shuning uchun uch narsa qo'shiladi:

| Tushuncha | Ma'nosi |
|-----------|---------|
| **overlay network** | bir necha node ustidan yagona virtual tarmoq: turli node'dagi konteynerlar bir-birini xuddi bitta bridge'da turgandek ko'radi |
| **VIP** (virtual IP) | service'ga beriladigan barqaror IP, hech bir konteynerga tegishli emas |
| **routing mesh** | publish qilingan portni klasterning har node'ida ochib, so'rovni istalgan node'dagi task'ga yetkazish |

### Mexanizm

**Overlay.** Har node'dagi konteynerlar lokal bridge'ga ulanadi, node'lar orasida esa paketlar **VXLAN** bilan o'raladi: konteynerning Ethernet freymi UDP paket ichiga solinib (port 4789) boshqa node'ga yuboriladi va u yerda ochiladi. Konteyner buni sezmaydi. Swarm ikkita tarmoqni o'zi yaratadi: `ingress` (overlay, routing mesh uchun) va `docker_gwbridge` (har node'dagi lokal bridge, overlay'dagi konteynerlarni tashqi dunyo bilan bog'laydi). Overlay tarmoqqa default holatda faqat service task'lari ulanadi; `--attachable` bilan yaratilsa oddiy `docker run --network` konteynerlari ham ulana oladi (debug uchun).

**Service discovery.** 3-darsdagi ichki DNS (`127.0.0.11`) bu yerda ham ishlaydi, lekin service nomi konteyner IP'siga emas, VIP'ga yechiladi. VIP'ga kelgan ulanishni kernel'dagi **IPVS** (kernel ichidagi L4 load balancer) sog'lom task'lardan biriga yo'naltiradi. Task'lar almashganda VIP o'zgarmaydi, Swarm faqat IPVS orqasidagi ro'yxatni yangilaydi. Shuning uchun 4-darsdagi nginx stale upstream muammosi yo'qoladi: nginx bir marta yechgan IP doim to'g'ri. Alohida task IP'lari kerak bo'lsa `tasks.<service>` nomi ularning ro'yxatini qaytaradi.

**Routing mesh.** `-p 8085:80` portni klasterdagi har node'da ochadi. So'rov task'i yo'q node'ga kelsa ham `ingress` overlay orqali task'i bor node'ga yetkaziladi. Bu IP darajasida ishlaydi, shuning uchun portni `127.0.0.1` ga bog'lab bo'lmaydi.

Healthcheck (3-dars) shu yerda haqiqiy kuchga kiradi: yolg'iz Docker'da `unhealthy` faqat belgi edi, Swarm'da `unhealthy` task trafikdan chiqariladi va almashtiriladi, yangi task esa `healthy` bo'lmaguncha trafik olmaydi.

### Misol

```
$ docker network ls --filter driver=overlay
NETWORK ID     NAME      DRIVER    SCOPE
<id>           ingress   overlay   swarm
$ docker service inspect --format '{{json .Endpoint.VirtualIPs}}' l5-demo
[{"NetworkID":"<id>","Addr":"<vip>/24"}]
$ curl -s localhost:8085
<html><body><h1>It works!</h1></body></html>
```

Birinchi chiqish: `SCOPE` ustunidagi `swarm` tarmoq butun klasterga tegishliligini bildiradi (bridge tarmoqlarda `local`). Ikkinchi chiqish: `l5-demo` ga `ingress` tarmog'ida bitta VIP berilgan, `NetworkID` yuqoridagi `ingress` ID'si bilan bir xil. Ikki task bor, lekin VIP bitta. Uchinchi chiqish: `localhost:8085` ga kelgan so'rov routing mesh orqali ikki task'dan biriga yetdi va `httpd` ning standart sahifasi qaytdi.

Zorin'da qo'shimcha ko'rish mumkin: `ip -br addr show docker_gwbridge` host'dagi bridge interfeysini ko'rsatadi. macOS'da bu interfeys Docker Desktop VM'i ichida, Mac'dan ko'rinmaydi; `curl localhost:8085` esa ishlaydi, chunki Docker Desktop publish qilingan portni Mac'ga uzatadi.

### Real ishda qachon kerak

- Servislar bir-biriga doim service nomi bilan murojaat qiladi (`http://api:3000`), IP bilan emas.
- Tashqi load balancer (cloud LB) klasterning istalgan node'lariga yo'naltiriladi, task qaysi node'da ekanini bilishi shart emas.
- Node'lar orasida `4789/udp` yopiq bo'lsa DNS ishlaydi, lekin ulanish timeout bo'ladi: overlay nosozligining klassik belgisi.
- Mijozning haqiqiy IP'si kerak bo'lsa: routing mesh orqali kelgan so'rovda manba IP almashadi, buning uchun `mode=host` publish yoki tashqi proxy ishlatiladi.

### Nima uchun shunday

VIP mijozni task'lar ro'yxatidan ajratadi: mijoz bitta barqaror manzilni biladi, orqasida nima almashayotgani uning ishi emas. Muqobili DNS round-robin (`--endpoint-mode dnsrr`): DNS har task IP'sini qaytaradi, lekin mijozlar DNS javobini cache qiladi va o'lgan task'ga murojaat qilishda davom etadi. Routing mesh esa tashqi load balancer'ni soddalashtiradi; narxi bitta ortiqcha tarmoq sakrashi va manba IP'ning yo'qolishi.

## 5. Stack fayl, rolling update va rollback

### Stack bu nima

**Stack** bitta fayldan yaratilgan service'lar, tarmoqlar, secret va config'lar guruhi. Fayl formati Compose formati (4-dars), unga har servis uchun `deploy:` bo'limi qo'shiladi. Compose project'ning Swarm'dagi o'xshashi.

```
docker stack config -c stack.yaml          # validate and print the resolved file, no deploy
docker stack deploy -c stack.yaml <stack>  # create or update
docker stack services <stack>
docker stack ps <stack>
docker stack rm <stack>
```

Service nomlari `<stack>_<service>` ko'rinishida bo'ladi, default tarmoq `<stack>_default` va uning driver'i `overlay`. `docker stack deploy` idempotent: bir xil faylni qayta bersangiz hech narsa o'zgarmaydi, o'zgargan faylni bersangiz faqat farq qo'llanadi (1-bo'limdagi reconciliation).

### Compose fayl va stack fayl farqi

`docker stack deploy` faylni `docker compose` dan boshqa kod bilan, o'zining eskiroq sxemasi bo'yicha o'qiydi. Farqlar uch turga bo'linadi:

| Tur | Nima bo'ladi | Misollar |
|-----|--------------|----------|
| E'tiborsiz qoldiriladi | ogohlantirish chiqadi yoki jim o'tadi | `build`, `container_name`, `restart` |
| Sxemada yo'q | xato, deploy to'xtaydi | Compose'ning yangi kalitlari va uzun shakllari (masalan `depends_on` ning `condition` li shakli) |
| Faqat Swarm'da ishlaydi | `docker compose up` buni to'liq qo'llamaydi | `deploy.update_config`, `deploy.placement`, `deploy.mode` |

Muhim oqibatlar: `build` yo'q, chunki klasterning har node'i image'ni o'zi olishi kerak, demak image registry'da tayyor turishi shart (private bo'lsa `docker stack deploy --with-registry-auth`). `restart` o'rniga `deploy.restart_policy`. Ishga tushish tartibi kafolatlanmaydi, ilova bog'liqliklarini o'zi qayta urinib kutishi shart. Aniq qaysi kalit xato berishini yodlamang: `docker stack config` har birini o'zi aytadi (10-vazifa).

`deploy:` bo'limining ko'rinishi (boshqa servis misolida, fragment):

```
services:
  sessions:
    image: memcached:1.6-alpine
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
      resources:
        limits: { cpus: "0.50", memory: 128M }
        reservations: { memory: 64M }
```

### Mexanizm: rolling update

Service tavsifi o'zgarganda (`docker service update --image <new> <svc>` yoki o'zgargan fayl bilan `docker stack deploy`) orchestrator task'larni partiyalab almashtiradi: partiyadagi eski task'larni to'xtatadi, yangilarini ko'taradi, ular `Running` (healthcheck bo'lsa `healthy`) bo'lishini kutadi, `monitor` vaqti davomida yiqilmasligini kuzatadi, `delay` kutadi va keyingi partiyaga o'tadi.

| Parametr (`deploy.update_config`) | CLI flag | Ma'nosi |
|-----------------------------------|----------|---------|
| `parallelism` | `--update-parallelism` | bir partiyada nechta task almashtiriladi |
| `delay` | `--update-delay` | partiyalar orasidagi kutish |
| `order` | `--update-order` | `stop-first`: avval eskisi to'xtaydi (sig'im vaqtincha kamayadi). `start-first`: avval yangisi ko'tariladi (sig'im kamaymaydi, vaqtincha ortiqcha resurs kerak) |
| `failure_action` | `--update-failure-action` | yangi task ko'tarilmasa: `pause`, `continue` yoki `rollback` |
| `monitor` | `--update-monitor` | har partiyadan keyin xatoni kuzatish vaqti |
| `max_failure_ratio` | `--update-max-failure-ratio` | qancha ulush yiqilsa yangilash muvaffaqiyatsiz sanaladi |

Default qiymatlarni 2-vazifada `docker service inspect --pretty` dan o'zingiz o'qiysiz.

Healthcheck bilan bog'liqlik: Swarm yangi task'ni healthcheck `healthy` bo'lgandan keyingina tayyor deb hisoblaydi. Healthcheck yo'q bo'lsa "jarayon start bo'ldi" yetarli sanaladi va ishga tushib, lekin so'rovlarga javob bermaydigan versiya barcha nusxalarga "muvaffaqiyatli" tarqaladi.

**Rollback.** Swarm service'ning oldingi tavsifini (`PreviousSpec`) saqlaydi. `docker service rollback <svc>` unga qaytadi, bu ham rolling update, faqat teskari yo'nalishda va `rollback_config` parametrlari bilan. Faqat bitta oldingi tavsif saqlanadi: ikki marta ketma-ket rollback sizni yana yangi versiyaga qaytaradi. Yangilash holati: `docker service inspect --format '{{json .UpdateStatus}}' <svc>`.

**Tuzoq: uzilishsiz yangilash faqat orkestratorga bog'liq emas.** Eski task `SIGTERM` oladi (1-dars); ilova uni ushlamasa yoki ochiq so'rovlarni tugatmasa mijozlar xato ko'radi. `stop_grace_period` (SIGTERM va SIGKILL orasidagi vaqt), graceful shutdown va healthcheck uchalasi birga kerak.

### Real ishda qachon kerak

- Har release: yangi tag bilan `docker stack deploy`, parametrlar faylda turadi va review'dan o'tadi.
- `parallelism` va `delay` tanlovi: tez yangilash va xavfni cheklash orasidagi murosa (bitta nusxa buzilsa qolganlari hali eski versiyada).
- Buzilgan release: `failure_action: rollback` bo'lsa tizim o'zi qaytadi, bo'lmasa `docker service rollback`.

### Nima uchun shunday

Stack Compose formatini qayta ishlatadi, chunki dasturchi uni allaqachon biladi: lokal `compose.yaml` dan production tavsifiga yo'l qisqa. Narxi: ikki vosita bitta formatni ikki xil o'qiydi va farqlar chalkashtiradi. Rolling update'ning muqobillari: blue-green (yangi versiyaning to'liq ikkinchi nusxasi ko'tariladi va trafik bir zumda o'tkaziladi, ikki barobar resurs talab qiladi) va canary (yangi versiyaga trafikning kichik ulushi beriladi). Swarm ularni to'g'ridan-to'g'ri bermaydi, Kubernetes modulida va CI/CD modulida uchraydi.

## 6. Secrets va configs

### Bu nima

**Swarm secret** klasterda markaziy saqlanadigan maxfiy qiymat (parol, token, TLS kaliti), faqat uni so'ragan service'ning konteynerlariga fayl sifatida yetkaziladi. **Config** xuddi shu mexanizm, lekin maxfiy bo'lmagan fayllar uchun (masalan nginx konfiguratsiyasi). 4-darsdagi Compose `secrets:` host'dagi faylni bind mount qilardi; Swarm secret esa host fayl tizimida umuman turmaydi.

### Mexanizm

1. `docker secret create` qiymatni manager'ga yuboradi, u Raft log'ida shifrlangan holda saqlanadi.
2. Service secret'ni so'rasa, manager uni faqat shu service task'i ishlayotgan node'larga yuboradi (boshqa node'lar uni hech qachon ko'rmaydi).
3. Node uni konteyner ichida `/run/secrets/<name>` faylida ko'rsatadi. Fayl xotirada saqlanadi, node diskiga yozilmaydi (aniq fayl tizimi turi va ruxsatlarni 8-vazifada o'zingiz ko'rasiz).
4. Task to'xtaganda qiymat o'sha node'dan o'chiriladi.

Nima uchun env o'zgaruvchi emas: env qiymati `docker inspect` da, `/proc/<pid>/environ` da, crash dump va loglarda ko'rinadi va bola jarayonlarga meros o'tadi. Image ichidagi secret esa image'ni olgan har kimga ko'rinadi (2-dars, layer'lar). Fayl faqat uni ochgan jarayonga ko'rinadi. Ko'p rasmiy image'lar shuning uchun `*_FILE` o'zgaruvchilarini qo'llaydi: qiymat o'rniga fayl yo'li beriladi.

Secret **o'zgarmas** (immutable): yaratilgandan keyin qiymatini yangilab bo'lmaydi. Rotatsiya (qiymatni almashtirish) uch qadam: yangi nomli secret yaratish (nomga versiya qo'shiladi), service'ni eski secret o'rniga yangisini ishlatadigan qilib yangilash (bu service tavsifini o'zgartiradi, demak rolling update), eskisini o'chirish. Stack faylda `file:` orqali berilgan secret'ning mazmuni o'zgarsa qayta deploy xato beradi, sabab shu.

### Misol

```
$ openssl rand -base64 24 | docker secret create l5_demo_token -
<secret id>
$ docker secret ls
ID            NAME            DRIVER    CREATED          UPDATED
<secret id>   l5_demo_token             5 seconds ago    5 seconds ago
$ docker service create -d --name l5-reader --secret l5_demo_token alpine:3 sleep 3600
<service id>
$ docker exec $(docker ps -q -f name=l5-reader) sh -c 'wc -c < /run/secrets/l5_demo_token'
33
```

Birinchi buyruq: `openssl rand` tasodifiy qiymat yaratdi va uni pipe orqali berdi, oxiridagi `-` "qiymatni stdin'dan o'qi" degani. Qiymat ekranga ham, shell history'ga ham tushmadi; chiqish faqat secret ID'si. `docker secret ls` da `DRIVER` bo'sh (ichki ombor). `--secret l5_demo_token` service'ga shu secret'ni ulaydi, `-d` progress chiqishini kutmaydi (shuning uchun keyingi buyruqdan oldin bir necha sekund kuting, konteyner hali yaratilmagan bo'lishi mumkin). Oxirgi buyruq konteyner ichida fayl borligini qiymatni ko'rsatmasdan tekshiradi: 33 bayt, ya'ni 32 belgi va `openssl` qo'shgan qator oxiri. Bu ortiqcha `\n` parollarda xato manbai, shuning uchun aniq qiymat `printf '%s'` bilan beriladi. Tozalash: `docker service rm l5-reader && docker secret rm l5_demo_token`.

### Real ishda qachon kerak

- Baza paroli, API token, TLS private key: stack faylda faqat secret nomi turadi, qiymat git'ga tushmaydi.
- Parol sizib chiqqanda yoki xodim ketganda rotatsiya.
- nginx yoki ilova konfiguratsiyasini har node'ga qo'lda nusxalamaslik uchun `docker config`.

### Nima uchun shunday

O'zgarmaslik tasodifiy emas: qiymat joyida o'zgarsa, ishlab turgan task'larning yarmi eski, yarmi yangi qiymatni ko'rar va qaysi versiya qayerda ekanini hech kim bilmas edi. Versiyali nom bilan har o'zgarish oddiy, kuzatiladigan va rollback qilinadigan rolling update bo'ladi. Muqobili: tashqi secret manager (HashiCorp Vault, cloud'ning Secrets Manager xizmatlari), ular audit va avtomatik rotatsiya beradi; cloud modulida uchraydi.

**Tuzoq: volume node'ga bog'langan.** Named volume (3-dars) har node'da alohida. Baza task'i boshqa node'ga ko'chsa bo'sh volume bilan ko'tariladi. Holatli servis `deploy.placement.constraints` bilan bitta node'ga bog'lanadi yoki tashqi storage ishlatiladi.

## 7. Kubernetes: xarita

Bu bo'lim amaliyot emas, xarita: Kubernetes modulida uchraydigan nomlar qayerda turishini ko'rsatadi. Kubernetes (qisqacha K8s) 1-bo'limdagi g'oyani (desired state, reconciliation) ancha umumiy va kengaytiriladigan ko'rinishda amalga oshiradi. Amalda sanoat standarti: barcha yirik cloud'larda managed xizmat sifatida bor (EKS, GKE, AKS), ya'ni control plane'ni cloud provayder boshqaradi.

### Arxitektura

| Komponent | Qayerda | Vazifasi |
|-----------|---------|----------|
| `kube-apiserver` | control plane | yagona kirish nuqtasi (REST API). Barcha komponentlar faqat u orqali gaplashadi |
| `etcd` | control plane | klaster holati saqlanadigan key-value baza (Raft, 2-bo'lim) |
| `kube-scheduler` | control plane | yangi Pod uchun node tanlaydi |
| `kube-controller-manager` | control plane | reconciliation sikllari (controller'lar) |
| `kubelet` | har node | apiserver'dan o'ziga tayinlangan Pod'larni olib, container runtime orqali ishga tushiradi, holatni qaytaradi |
| `kube-proxy` | har node | Service'lar uchun tarmoq qoidalari |
| container runtime | har node | containerd yoki CRI-O. Docker Engine kerak emas; Docker'da qurilgan OCI image (2-dars) o'zgarishsiz ishlaydi |

Swarm'da manager ichida bitta dastur bo'lgan narsa bu yerda alohida komponentlarga bo'lingan. `kubectl` apiserver'ga so'rov yuboradi, xuddi `docker` CLI `dockerd` ga yuborgandek (1-dars).

### Uchta asosiy obyekt

- **Pod**: eng kichik ishga tushiriladigan birlik, bitta yoki bir necha konteyner, umumiy network namespace (bitta IP) bilan.
- **Deployment**: "shu Pod shablonidan N nusxa bo'lsin" degan desired state; rolling update va rollback uning ishi.
- **Service**: Pod'lar to'plami uchun barqaror nom va virtual IP.

Obyektlar YAML **manifest** bilan tavsiflanadi va `kubectl apply -f` bilan yuboriladi. Har obyektda `spec` (siz xohlagan holat) va `status` (klaster xabar qilgan holat) bor. Obyektlar bir-biriga nom bilan emas, **label va selector** orqali bog'lanadi: Service "label'i `app=web` bo'lgan barcha Pod'lar" deydi. Qolgan obyektlar (ReplicaSet, Ingress, ConfigMap, Secret, Namespace, StatefulSet, DaemonSet, Job, PersistentVolume) hozircha faqat nom sifatida: ular Kubernetes modulining "Workload, tarmoq, storage, TLS" bosqichida o'rganiladi, klaster ichki tuzilishi "Asoslar va klaster" bosqichida.

### kind bilan birinchi tegish

`kind create cluster --name <name>` bitta konteyner ishga tushiradi, uning ichida control plane komponentlari va kubelet ishlaydi, ya'ni node'ning o'zi konteyner. Buyruq tugagach `~/.kube/config` fayliga (**kubeconfig**: klaster manzili va kirish kalitlari) `kind-<name>` nomli context yozadi, `kubectl` shu fayl orqali klasterni topadi. Tekshirish:

```
$ kind get clusters
<name>
$ kubectl config current-context
kind-<name>
```

Birinchi chiqish mavjud kind klasterlari ro'yxati, ikkinchisi `kubectl` hozir qaysi klasterga gapirayotgani. Ish klasteri bilan ishlaganda ikkinchi buyruq odat bo'lishi kerak: noto'g'ri context'da `delete` qilish klassik avariya. Kubeconfig'da kalitlar bor, commit qilinmaydi. Qolganini 16-vazifada o'zingiz bajarasiz.

### Real ishda qachon kerak

- Vakansiyalar va cloud hujjatlari Kubernetes atamalarida yozilgan: Pod, Deployment, Service so'zlarini Swarm'dagi task, service, VIP bilan bog'lay olsangiz, o'qish osonlashadi.
- Lokal sinov: `kind` klasteri CI ichida ham ishlatiladi (CI/CD moduli).

### Nima uchun shunday

Kubernetes'da hamma narsa apiserver'dagi obyekt va uni kuzatadigan controller. Shu bir xil qolip tufayli uni kengaytirish mumkin: yangi obyekt turi (CRD) va unga controller (operator) yozilsa, baza klasteri yoki sertifikat ham `kubectl apply` bilan boshqariladi. Narxi: tushunchalar ko'p va oddiy ish uchun ham bir necha obyekt kerak. Swarm teskari tanlov qilgan: kam tushuncha, kam kengaytirish.

## 8. Compose, Swarm yoki Kubernetes

| | Compose (bitta VM) | Docker Swarm | Kubernetes |
|---|--------------------|--------------|------------|
| O'rnatish | Docker Engine bilan keladi | `docker swarm init` | alohida klaster: managed xizmat, kubeadm, k3s, lokal uchun kind |
| Host o'lsa | hamma narsa to'xtaydi | task'lar boshqa node'ga ko'chadi | Pod'lar boshqa node'ga ko'chadi |
| Uzilishsiz yangilash | yo'q (qo'lda yechimlar) | `update_config` | Deployment strategiyasi |
| Avtomatik scaling | yo'q | yo'q (qo'lda `scale`) | bor (HorizontalPodAutoscaler, cluster autoscaler) |
| Storage | lokal volume | node-lokal volume, plugin'lar | node'dan mustaqil storage abstraksiyasi (PV/PVC, CSI) |
| Sog'liq tekshiruvi | `healthcheck` | `healthcheck` | uch alohida probe: liveness, readiness, startup |
| Ekotizim va kengaytirish | kichik | cheklangan, rivojlanish sekin | juda katta (Helm, operator'lar, GitOps) |
| O'rganish va ishlatish narxi | past | past | yuqori |

Halol xulosa:

- **Compose bitta VM'da** ko'p kichik loyiha uchun to'g'ri javob: ichki vosita, kichik mijozli servis, staging. Bir necha daqiqalik uzilish qabul qilinsa va backup bo'lsa, orkestrator ortiqcha murakkablik.
- **Swarm**: bir necha server, kichik jamoa, Compose'dan tabiiy keyingi qadam, Kubernetes'ni boshqarishga odam yo'q. Kamchiligi: ekotizim kichik, yangi imkoniyatlar kam qo'shiladi, ish bozorida talab past.
- **Kubernetes**: ko'p servis va ko'p jamoa, cloud, autoscaling yoki ekotizim (service mesh, GitOps, operator'lar) kerak bo'lganda. Managed xizmat control plane yukini oladi, lekin tushunchalar yuki qoladi.

### Real ishda qachon kerak

Yangi loyihada infratuzilma tanlashda va mavjud tizimni "Kubernetes'ga ko'chiraylikmi" degan savolda. Savolni texnologiyadan emas, talabdan boshlang: qancha uzilish qabul qilinadi, nechta server, kim navbatchilik qiladi.

### Nima uchun shunday

Swarm o'rganish uchun qulay: orkestratsiya tushunchalari ortiqcha obyektlarsiz ko'rinadi, shuning uchun bu dars undan boshlaydi. Ish bozorida va cloud'da talab Kubernetes'ga, shuning uchun kurs unga alohida modul ajratadi. Bu darsdagi tushunchalar (desired state, quorum, VIP, rolling update, secret) ikkalasida bir xil, faqat nomlari boshqa.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Orkestrator | konteynerlarni node'larga joylashtiradigan, kuzatadigan va yangilaydigan dastur |
| Klaster | birga boshqariladigan node'lar to'plami |
| Desired state | tizim qanday bo'lishi kerakligining saqlangan tavsifi |
| Reconciliation | actual state'ni desired state bilan solishtirib farqni yopadigan cheksiz sikl |
| Node | klasterdagi bitta mashina (Swarm'da bitta Docker Engine) |
| Manager, worker | holatni saqlab qaror qiladigan node va faqat task bajaradigan node |
| Raft | manager'lar bitta holat ustida kelishadigan konsensus algoritmi |
| Quorum | qaror uchun kerak bo'lgan manager'lar ko'pchiligi |
| Control plane, data plane | boshqaruv qismi va foydalanuvchi trafigi o'tadigan qism |
| Service | Swarm'da desired state tavsifi: image, nusxalar soni, portlar |
| Task | service'ning bitta nusxasi, bitta node'da bitta konteyner |
| Slot | replicated service'dagi o'rin raqami (`.1`, `.2`) |
| Replicated, global | N nusxa rejimi va har node'da bittadan rejimi |
| Scheduling | task uchun node tanlash |
| Constraint | task qaysi node'larda ishlashi mumkinligini cheklovchi qat'iy shart |
| Drain | node'dan task'larni ko'chirib, yangisini bermaslik holati |
| Overlay network | bir necha node ustidan yagona virtual tarmoq |
| VXLAN | Ethernet freymni UDP ichiga o'rab node'lar orasida tashish usuli |
| VIP | service'ning barqaror virtual IP'si |
| IPVS | kernel ichidagi L4 load balancer |
| Routing mesh | publish qilingan portni har node'da ochib so'rovni task'ga yetkazish |
| Stack | bitta Compose formatidagi fayldan yaratilgan service'lar guruhi |
| Rolling update | nusxalarni partiyalab, navbat bilan almashtirish |
| Rollback | service'ni oldingi tavsifiga qaytarish |
| Secret, config | klasterda saqlanib konteynerga fayl sifatida beriladigan maxfiy va oddiy qiymat |
| Join token | node'ni klasterga qo'shish uchun maxfiy satr |
| dind | ichida o'z Docker daemon'i ishlaydigan konteyner |
| Pod | Kubernetes'dagi eng kichik birlik: umumiy IP'li bir yoki bir necha konteyner |
| Deployment | Pod nusxalari soni va yangilanishini boshqaradigan Kubernetes obyekti |
| Manifest | Kubernetes obyektining YAML tavsifi |
| kubeconfig | `kubectl` uchun klaster manzili va kirish ma'lumotlari fayli |

## Tuzoqlar

- Healthcheck'siz rolling update: buzilgan versiya "muvaffaqiyatli" tarqaladi, chunki jarayon start bo'lgani yetarli sanaladi.
- `SIGTERM` ni ushlamaydigan ilova: har yangilashda uzilgan so'rovlar, orkestrator buni yecha olmaydi.
- Holatni konteyner ichida yoki node-lokal volume'da saqlab, servisni bir necha node'ga tarqatish: task ko'chganda ma'lumot "yo'qoladi".
- Juft sonli yoki bitta manager: bitta manager'ning yo'qolishi klaster boshqaruvini to'xtatishi mumkin. Manager'lar holati (Raft) backup qilinmasa klasterni tiklab bo'lmaydi.
- Stack faylda `latest` tag: har node har xil vaqtda pull qiladi va turli versiyalar ishlaydi. Aniq tag yoki digest (2-dars).
- Compose faylni o'zgarishsiz stack sifatida deploy qilish: ba'zi kalitlar jimgina tushib qoladi, ba'zilari xato beradi. `docker stack config` bilan tekshiring.
- Swarm'da publish qilingan port har node'ning barcha interfeyslarida ochiq, `127.0.0.1` ga bog'lanmaydi. Firewall'ni klaster darajasida rejalashtiring.
- Resurs limiti va reservation'siz scheduling: orkestrator node'ni to'ldirib yuboradi va OOM killer (1-dars) tasodifiy task'larni o'ldiradi.
- Lokal build qilingan image'ni ko'p node'li klasterga deploy qilish: boshqa node'larda image yo'q, task `Rejected` bo'ladi. Image registry'da bo'lishi kerak.
- Bitta arxitektura uchun build qilingan image: ofisda (`amd64`) ishlaydi, uyda (`arm64`) `exec format error`. Multi-platform build (2-dars).
- Swarm'ni yoqiq qoldirish: ertasi kuni boshqa mashinada u yo'q, bu mashinada esa unutilgan service port ochiq turadi. Har mashg'ulot oxirida `docker swarm leave --force`.
- `docker swarm leave --force` secret va service'larni ham o'chiradi: faylda bo'lmagan narsa yo'qoladi.
- `kubectl` ni noto'g'ri context'da ishlatish. Har doim `kubectl config current-context`.
- Orkestratorni "kerak bo'lib qolar" deb erta kiritish: bitta server va Compose ko'p kichik loyihalar uchun yetarli, murakkablikning narxi bor.

## Manbalar

- https://docs.docker.com/engine/swarm/ – Swarm mode umumiy ko'rinishi
- https://docs.docker.com/engine/swarm/key-concepts/ – node, service, task tushunchalari
- https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/ – service, task va scheduler mexanizmi
- https://docs.docker.com/engine/swarm/swarm-tutorial/ – rasmiy qo'llanma (init, service, rolling update, drain)
- https://docs.docker.com/engine/swarm/ingress/ – routing mesh
- https://docs.docker.com/engine/swarm/secrets/ – Swarm secrets
- https://docs.docker.com/engine/swarm/stack-deploy/ – stack deploy
- https://docs.docker.com/reference/compose-file/deploy/ – `deploy` kaliti
- https://docs.docker.com/engine/swarm/admin_guide/ – manager soni, quorum, backup
- https://raft.github.io/ – Raft algoritmi, vizual tushuntirish bilan
- https://kubernetes.io/docs/concepts/overview/components/ – Kubernetes komponentlari
- https://kubernetes.io/docs/concepts/workloads/ – Pod, Deployment va boshqa workload'lar
- https://kubernetes.io/docs/concepts/services-networking/service/ – Service
- https://kind.sigs.k8s.io/docs/user/quick-start/ – kind o'rnatish va birinchi klaster
- https://kubernetes.io/docs/tasks/tools/ – kubectl o'rnatish (Linux va macOS)
- Burns, Beda, Hightower, "Kubernetes: Up and Running" (O'Reilly), 1–2-boblar: keyingi modulga tayyorgarlik

---

## Birga bajaramiz

Bitta yaxlit misol: `httpd` dan iborat kichik stack'ni fayldan ko'taramiz, faylni o'zgartirib qayta deploy qilamiz va Swarm faqat farqni qo'llaganini ko'ramiz, keyin hammasini tozalaymiz. Bu vazifalardagi servislar emas, yechim ham emas. Hammasi host'da, ikkala mashinada bir xil.

1. Swarm o'chiqligini tekshirib, yoqing:

```
$ docker info --format '{{.Swarm.LocalNodeState}}'
inactive
$ docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
Swarm initialized: current node (<node id>) is now a manager.
...
```

`inactive` engine oddiy rejimda ekanini bildiradi. `active` chiqsa oldingi mashg'ulotdan qolgan klaster bor: `docker service ls` bilan nima ishlab turganini ko'ring va Laboratoriya bo'limidagi tartibda o'chiring.

2. Vaqtinchalik papkada (repo'dan tashqarida) stack fayl yozing:

```
$ mkdir -p ~/l5-walk && cd ~/l5-walk
$ cat stack.yaml
services:
  hello:
    image: httpd:2.4-alpine
    ports:
      - "8086:80"
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 5s
      resources:
        limits: { memory: 64M }
```

Compose fayldan yagona farq `deploy:` bo'limi. `build`, `container_name`, `restart` yo'q.

3. Deploy qilmasdan tekshiring:

```
$ docker stack config -c stack.yaml > /dev/null; echo $?
0
```

Buyruq faylni o'qib, to'liq yechilgan ko'rinishini chiqaradi (bu yerda `/dev/null` ga yuborildi); exit code `0` sxema bo'yicha xato yo'qligini bildiradi (linux moduli, 1-dars). Xato bo'lsa matni qaysi kalit qabul qilinmaganini aytadi.

4. Deploy:

```
$ docker stack deploy -c stack.yaml l5-walk
Creating network l5-walk_default
Creating service l5-walk_hello
$ docker stack services l5-walk
ID             NAME            MODE         REPLICAS   IMAGE              PORTS
<id>           l5-walk_hello   replicated   2/2        httpd:2.4-alpine   *:8086->80/tcp
$ curl -s localhost:8086
<html><body><h1>It works!</h1></body></html>
```

Faylda tarmoq yozilmagan edi, Swarm `l5-walk_default` overlay tarmog'ini o'zi yaratdi. Service nomi `<stack>_<service>`. `REPLICAS` darhol `0/2` ko'rsatsa bir necha sekunddan keyin takrorlang: image pull va start vaqt oladi, bu reconciliation'ning ko'rinadigan izi. Docker versiyangizga qarab deploy buyrug'i qo'shimcha progress qatorlarini ham chiqarishi mumkin.

5. Desired state'ni **faylda** o'zgartiring: `replicas: 2` ni `3` ga, va `image:` qatoridan keyin (shu darajada) ikki qator qo'shing:

```
    environment:
      GREETING: v2
```

Xuddi o'sha buyruq bilan qayta deploy qiling:

```
$ docker stack deploy -c stack.yaml l5-walk
Updating service l5-walk_hello (id: <service id>)
```

`Creating` emas, `Updating`: Swarm faylni mavjud service bilan solishtirdi va farqni topdi. Tarmoq haqida qator yo'q, chunki u o'zgarmagan.

6. Farq qanday qo'llanganini ko'ring (bir necha sekund kutib):

```
$ docker service ps l5-walk_hello
ID          NAME                  IMAGE              NODE     DESIRED STATE   CURRENT STATE             ERROR     PORTS
<id>        l5-walk_hello.1       httpd:2.4-alpine   <host>   Running         Running 8 seconds ago
<id>         \_ l5-walk_hello.1   httpd:2.4-alpine   <host>   Shutdown        Shutdown 10 seconds ago
<id>        l5-walk_hello.2       httpd:2.4-alpine   <host>   Running         Running 20 seconds ago
<id>         \_ l5-walk_hello.2   httpd:2.4-alpine   <host>   Shutdown        Shutdown 22 seconds ago
<id>        l5-walk_hello.3       httpd:2.4-alpine   <host>   Running         Running 25 seconds ago
```

1 va 2-slotlarda ikkitadan qator: `\_` bilan boshlangani eski task (`Shutdown`), ustidagisi uning o'rniga kelgan yangi task. Env o'zgargani uchun eski task'lar yangi tavsifga mos emas edi va almashtirildi; vaqtlar farqi task'lar birdaniga emas, navbat bilan almashganini ko'rsatadi (`parallelism: 1`; oradagi kutish `delay: 5s`, `monitor` vaqti va start vaqtidan yig'iladi; qaysi slot birinchi bo'lishi sizda boshqacha bo'lishi mumkin). 3-slotda tarix yo'q: u oldin mavjud emas edi, darhol yangi tavsif bilan yaratildi. Image bir xil, lekin task'lar baribir yangi: service tavsifining istalgan o'zgarishi rolling update.

7. Yangi tavsif haqiqatan saqlanganini tekshiring:

```
$ docker service inspect --format '{{.Spec.TaskTemplate.ContainerSpec.Env}}' l5-walk_hello
[GREETING=v2]
$ docker service inspect --format '{{.Spec.Mode.Replicated.Replicas}}' l5-walk_hello
3
```

`.Spec` bu service'ning desired state'i. Siz `docker service scale` yoki `docker service update` ni umuman ishlatmadingiz: fayl o'zgardi, buyruq o'sha.

8. Tozalash va tekshirish:

```
$ docker stack rm l5-walk
Removing service l5-walk_hello
Removing network l5-walk_default
$ docker swarm leave --force
Node left the swarm.
$ docker network rm docker_gwbridge
docker_gwbridge
$ docker info --format '{{.Swarm.LocalNodeState}}'
inactive
$ cd ~ && rm -r ~/l5-walk
```

`docker network rm docker_gwbridge` "active endpoints" xatosini bersa, task konteynerlari hali to'xtab ulgurmagan: bir necha sekund kutib takrorlang.

Shu 8 qadamda ko'rganingiz: engine bir buyruq bilan manager'ga aylanadi (2-bo'lim); stack fayl desired state'ning o'zi va `docker stack deploy` uni klaster bilan solishtirib faqat farqni qo'llaydi (1 va 5-bo'limlar); service, slot va task alohida narsalar, tarix `docker service ps` da qoladi (3-bo'lim); publish qilingan port routing mesh orqali ishlaydi (4-bo'lim); tavsifning har o'zgarishi `update_config` bo'yicha rolling update (5-bo'lim).

---

## Vazifalar

Ish papkasi: `docker/05-orchestration-intro/` (`make new m=docker n=05 name=orchestration-intro` bilan host'da yarating). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh; qaysi mashinada (Zorin yoki macOS) bajarilgani yozilsin. `stack.yaml`, skriptlar va `RUNBOOK.md` shu papkada saqlanadi. Secret qiymatlari, join token'lar va kubeconfig README'ga yozilmaydi va commit qilinmaydi. Har mashg'ulot oxirida Laboratoriya bo'limidagi "Qaytarish" ni bajaring.

### A. Swarm asoslari (bir node)

1. **Swarm init.** Avval `docker swarm init` ni flag'siz ishlatib ko'ring. Xato chiqsa uni o'qing va izohlang; muvaffaqiyatli o'tsa (macOS'da shunday bo'lishi mumkin) nima uchun bu mashinada xato bo'lmaganini izohlang va `docker swarm leave --force` qiling. Keyin Laboratoriya bo'limidagi buyruq bilan yarating. `docker node ls`, `docker info` ning Swarm qismi va `docker network ls` da nima yangi paydo bo'lganini yozing. Bu node manager'mi, worker'mi, ikkalasimi? Yo'nalish: 2-bo'lim, "Misol: klasterni yaratish".

2. **Service and tasks.** `nginx:1.28-alpine` dan 3 nusxali `l5-web` service yarating (port publish bilan). `docker service ls`, `docker service ps`, `docker ps` chiqishlarini solishtiring: service, task va konteyner nomlari qanday bog'langan? `docker service inspect --pretty` dan update va restart sozlamalarining default qiymatlarini yozing. Yo'nalish: 3-bo'lim, "Misol".

3. **Self-healing.** Task konteynerlaridan birini `docker kill` qiling. `docker service ps l5-web` da nima ko'rindi, o'rnini to'ldirish qancha vaqt oldi? 1-darsdagi `--restart always` dan farqi nimada (kim qaror qiladi, konteyner o'shami yoki yangimi)? Yo'nalish: 1-bo'lim, "Misol: farqni Swarm'siz ko'rish" va 3-bo'lim, "Mexanizm".

4. **Scaling.** `docker service scale l5-web=6`, keyin `=2` qiling. Qaysi task'lar o'chirilgani va tartibini kuzating. Keyin `docker service update --reserve-memory` ni host xotirasidan (macOS'da Docker Desktop VM'i xotirasidan, `docker info --format '{{.MemTotal}}'`) aniq katta qiymatga qo'ying: yangi task qaysi holatda qoldi va `docker service ps --no-trunc` nima deydi? Qiymatni qaytaring. Yo'nalish: 3-bo'lim, "Rejimlar va joylashtirish".

5. **VIP and service DNS.** `--attachable` overlay tarmoq yarating, unda `traefik/whoami:v1.10` dan 3 nusxali `l5-whoami` service ishga tushiring. Shu tarmoqqa ulangan `alpine` konteyneridan: `nslookup l5-whoami`, `nslookup tasks.l5-whoami`, va 6 marta `wget -qO- http://l5-whoami` qilib javobdagi `Hostname` larni sanang. VIP va task IP'lari farqini, 4-darsdagi nginx upstream muammosi bu yerda nima uchun yo'qligini izohlang. Yo'nalish: 4-bo'lim, "Mexanizm".

### B. Yangilash va secrets

6. **Rolling update.** Boshqa terminalda `while true; do curl -s -o /dev/null -w "%{http_code}\n" localhost:<port>; sleep 0.2; done` ni ishga tushiring. `l5-web` ni `nginx:1.29-alpine` ga `--update-parallelism 1 --update-delay 5s` bilan yangilang. `docker service ps` da ketma-ketlikni yozing. `200` bo'lmagan javoblar bo'ldimi? `--update-order start-first` bilan orqaga (1.28) yangilab solishtiring. Yo'nalish: 5-bo'lim, "Mexanizm: rolling update".

7. **Failed update and rollback.** Service'ga healthcheck qo'shing (`--health-cmd`, qisqa interval). Keyin mavjud bo'lmagan tag'ga yoki healthcheck'i hech qachon o'tmaydigan konfiguratsiyaga yangilang: default `failure_action` da nima bo'ldi, nechta task zarar ko'rdi? `docker service rollback` qiling. Xuddi shuni `--update-failure-action rollback` bilan takrorlab avtomatik qaytishni ko'rsating. Yo'nalish: 5-bo'lim, "Rollback".

8. **Secrets.** `printf` va stdin orqali `l5_db_password` secret yarating (qiymat shell history'ga tushmasin, qanday qilganingizni yozing). `postgres:17-alpine` service'ini `POSTGRES_PASSWORD_FILE` bilan ishga tushiring. Konteyner ichida `/run/secrets/` dagi fayl ruxsatlari va `mount` chiqishidagi fayl tizimi turini ko'rsating. `docker secret inspect` va `docker service inspect` da qiymat ko'rinadimi? Yo'nalish: 6-bo'lim, "Misol".

9. **Secret rotation.** Ishlatilayotgan secret'ni o'chirishga urining, xatoni yozing. Yangi `l5_db_password_v2` yarating va `--secret-rm`/`--secret-add` (`source` va `target` bilan, konteynerdagi fayl nomi o'zgarmasin) orqali almashtiring. Bu nima uchun rolling update'ni ishga tushirdi? Postgres uchun fayldagi yangi parol haqiqatan ham baza parolini o'zgartirdimi (3-dars, 2-vazifani eslang)? Yo'nalish: 6-bo'lim, "Mexanizm".

10. **Compose to stack.** 4-darsdagi `compose.yaml` ni (`docker/04-compose/stack/`) o'zgarishsiz `docker stack config -c` ga bering va xatolarni bittalab o'qib tuzating, har birini README'ga yozing. Natijani `stack.yaml` sifatida saqlang: registry'dagi image'lar (2-darsdagi usul bilan push qiling, ikkala mashinada ishlashi uchun `linux/amd64` va `linux/arm64` platformalari bilan), `deploy` bo'limlari, overlay tarmoqlar, secret'lar. `docker stack deploy` qilib `docker stack services` va `curl` bilan ishlashini ko'rsating. `depends_on` shartlari yo'qligini ilova qanday ko'tardi? Yo'nalish: 5-bo'lim, "Compose fayl va stack fayl farqi".

### C. Ko'p node (dind)

11. **Three-node cluster.** `l5-swarm` bridge tarmog'ida uchta `docker:29-dind` konteyner (`l5-m1`, `l5-w1`, `l5-w2`, `--privileged`, hostname bilan) ishga tushiring; `l5-m1` ning 8080-portini hostga `127.0.0.1:8088` sifatida publish qiling. `docker exec l5-m1 docker swarm init`, token bilan ikki worker'ni qo'shing. `docker exec l5-m1 docker node ls` ni yozing. Buyruqlarni `cluster-up.sh` va `cluster-down.sh` ga yig'ing (token faylga yozilmasin); skriptlar ikkala mashinada ishlashi kerak (macOS'da `bash` eski va BSD utilitalari, GNU'ga xos flag ishlatmang). Yo'nalish: Laboratoriya, "dind klasteri" va 2-bo'lim.

12. **Scheduling and routing mesh.** `l5-m1` da `traefik/whoami:v1.10` dan 4 nusxali service'ni `-p 8080:80` bilan yarating. Task'lar node'larga qanday taqsimlandi? Hostdan `curl 127.0.0.1:8088` ni 8 marta chaqiring: javob beradigan task'lar faqat `l5-m1` dagilarmi? Routing mesh buni qanday ta'minlaydi? `--constraint node.role==worker` bilan qayta yaratib taqsimotni solishtiring. Ixtiyoriy, faqat Zorin'da: `l5-w1` ning IP'siga host'dan to'g'ridan-to'g'ri `curl <ip>:8080` qiling (Mac'da bu IP'ga yetib bo'lmaydi). Yo'nalish: 4-bo'lim, "Mexanizm".

13. **Node failure and drain.** `docker stop l5-w2` qiling. `docker node ls` va `docker service ps` da node va task holatlari qanday o'zgardi, qancha vaqtda? `l5-w2` ni qayta `start` qiling: task'lar unga o'zi qaytdimi? Keyin `docker node update --availability drain l5-w1` qilib rejali xizmat ko'rsatish ssenariysini ko'rsating va `active` ga qaytaring. Oxirida `cluster-down.sh` bilan hammasini o'chiring. Yo'nalish: 2-bo'lim, `docker node ls` ustunlari.

14. **Quorum reasoning.** Amaliyotsiz, yozma: 1, 2, 3, 4, 5 manager'li klaster nechta manager yo'qolishiga chidaydi (jadval)? Nima uchun 4 manager 3 dan yaxshi emas? Quorum yo'qolganda ishlayotgan servislar va `docker service update` bilan nima bo'ladi? Yo'nalish: 2-bo'lim, "Mexanizm: Raft va quorum".

### D. Kubernetes bilan tanishuv

15. **Concept mapping.** Jadval tuzing: shu modulda ishlatgan har Docker va Swarm tushunchasi (container, image, service, task, replicas, published port va routing mesh, overlay DNS nomi, secret, config, healthcheck, stack fayl, `docker service update`, node drain, placement constraint) uchun Kubernetes'dagi eng yaqin tushuncha va bir qatorlik farq. Manba: `kubernetes.io/docs/concepts`. Yo'nalish: 7-bo'lim (u faqat boshlanish nuqtasi, qolganini hujjatdan topasiz).

16. **kind taste.** `kind` va `kubectl` ni Laboratoriya bo'limi bo'yicha o'rnating: Zorin'da `~/.local/bin` ga, macOS'da Homebrew bilan (versiyalarni yozing). `kind create cluster --name l5`. Ko'rsating: `docker ps` da klaster nima ko'rinishda, `kubectl get nodes -o wide`, `kubectl get pods -A` (control plane komponentlarini 7-bo'limdagi jadval bilan moslang). Keyin: `kubectl create deployment web --image=nginx:1.28-alpine --replicas=3`, bitta Pod'ni `kubectl delete pod` qilib self-healing'ni, `kubectl scale` ni, `kubectl expose deployment web --port=80` va `kubectl port-forward service/web 8089:80` orqali `curl` ni, `kubectl set image deployment/web nginx=nginx:1.29-alpine` va `kubectl rollout status` ni, `kubectl rollout undo` ni bajaring. Har qadam uchun Swarm'dagi mos buyruqni yonma-yon yozing. Oxirida `kind delete cluster --name l5` (undan oldin 17-vazifani bajaring). Yo'nalish: 7-bo'lim, "kind bilan birinchi tegish".

17. **Read a manifest.** `kind` klasteri o'chirilishidan oldin `kubectl get deployment web -o yaml` ni faylga saqlang (commit qilish mumkin, unda secret yo'q). `spec.replicas`, `spec.selector`, `spec.template`, `spec.strategy`, `status` qismlarini topib har birini bir gapda izohlang. `spec` va `status` ajratilishi 1-bo'limdagi qaysi g'oyaning ko'rinishi? Yo'nalish: 7-bo'lim, "Uchta asosiy obyekt".

### E. Modul mini-loyihasi

18. **Stack hardening.** 10-vazifadagi `stack.yaml` ni yakuniy holatga keltiring: `app` 3 nusxa, `start-first` va `failure_action: rollback`, barcha servislarda healthcheck va resurs limiti, `stop_grace_period`, secret'lar versiyali nom bilan, baza `placement` bilan bog'langan va named volume'da, faqat nginx publish qilingan, barcha image'lar aniq tag bilan registry'dan. `docker stack config` toza. Yo'nalish: 5 va 6-bo'limlar.

19. **Zero-downtime release.** Ilovaga ko'rinadigan o'zgarish kiritib `1.1.0` tag bilan build va push qiling. 6-vazifadagi `curl` sikli ishlab turganida stack'ni yangi tag bilan qayta deploy qiling. Natija: jami so'rovlar soni, `200` bo'lmaganlar soni (maqsad: nol), yangilash davomiyligi. Nol bo'lmasa sababini toping (graceful shutdown, healthcheck, `order`) va tuzatib takrorlang. Yo'nalish: 5-bo'lim, "Tuzoq: uzilishsiz yangilash".

20. **Bad release drill.** `/healthz` i `500` qaytaradigan `1.2.0-bad` versiyasini build va push qilib deploy qiling. Swarm avtomatik rollback qilganini `docker service ps` va `docker service inspect` (`UpdateStatus`) orqali ko'rsating. Mijozlar bu vaqtda xato ko'rdimi? Yo'nalish: 5-bo'lim, "Rollback".

21. **Runbook.** `RUNBOOK.md` yozing (1–2 sahifa, o'z so'zingiz bilan): arxitektura sxemasi (matnli), deploy, yangi versiya chiqarish, rollback, secret rotatsiyasi, baza backup va restore (3-dars), "servis javob bermayapti" holatida tekshirish ketma-ketligi (qaysi buyruq, nimaga qarash), ma'lum cheklovlar (bitta node, volume lokal). Har buyruq siz haqiqatan ishlatgan buyruq bo'lsin. Ikkinchi mashinada noldan tiklash qadamlari ham kirsin (Laboratoriya, "Ikkinchi mashinada tiklash"). Yo'nalish: 3-bo'lim, "Real ishda qachon kerak".

22. **Cleanup.** `docker stack rm`, secret va overlay tarmoqlarni o'chiring, `docker swarm leave --force`, `docker network rm docker_gwbridge`. dind konteynerlari va `l5-swarm` tarmog'i, `kind` klasteri o'chirilganini tekshiring. Registry'dagi test tag'larni o'chiring yoki private qoldiring, `docker logout`. Yakuniy `docker info | grep Swarm`, `docker ps -a`, `docker volume ls`, `docker network ls`, `kind get clusters` chiqishini yozing va boshqa loyiha resurslari joyida ekanini tasdiqlang. Faqat `l5-` prefiksli resurslar o'chiriladi; `docker system prune`, `docker volume prune -a`, `docker rm -f $(docker ps -aq)` ishlatilmaydi. Tozalashni ikkala mashinada ham bajaring. Yo'nalish: Laboratoriya, "Qaytarish".

### Topshirish

Tayyor bo'lgach:
1. `docker/05-orchestration-intro/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida; qaysi mashinada bajarilgani ko'rinadi.
2. Papkada `stack.yaml`, `cluster-up.sh`, `cluster-down.sh`, `RUNBOOK.md` va 17-vazifadagi Deployment YAML fayli bor.
3. `make check` toza, `shellcheck` barcha skriptlar uchun hech narsa chiqarmaydi.
4. `docker stack config -c stack.yaml` xatosiz.
5. Ikkala mashinada: `Swarm: inactive`, dind konteynerlari va `kind` klasteri yo'q, `docker_gwbridge` o'chirilgan, `l5-` prefiksli volume va tarmoq qolmagan.
6. Secret qiymatlari, token'lar, kubeconfig commit qilinmagan.
7. Menga xabar bering: `stack.yaml`, `RUNBOOK.md` va `README.md` ni o'qib chiqaman. Bu modulning yakuniy tekshiruvi.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Desired state va reconciliation nima? Self-healing, scaling va rolling update shu g'oyaga qanday bog'lanadi?
- Restart policy bilan orkestratorning self-healing'i orasidagi farq nima?
- Service, task va konteyner farqi nima? O'lgan task bilan nima bo'ladi?
- Manager va worker farqi nima? Control plane ishlamay qolsa data plane bilan nima bo'ladi?
- Routing mesh va service VIP har biri qaysi trafikni boshqaradi?
- Rolling update'da healthcheck qanday rol o'ynaydi? Usiz nima bo'ladi?
- `stop-first` va `start-first` farqi, har birining narxi nima?
- Swarm secret env o'zgaruvchidan nimasi bilan yaxshi? Nima uchun uni yangilab bo'lmaydi va rotatsiya qanday qilinadi?
- Compose faylni stack sifatida deploy qilganda qaysi kalitlar ishlamaydi va nima uchun `build` yo'q?
- Nima uchun manager soni toq bo'lishi kerak?
- macOS'da Swarm node'i aslida qayerda ishlaydi va shu sababli nimalar Mac'dan ko'rinmaydi?
- Kubernetes'da Pod, Deployment va Service har biri nima uchun javob beradi? Control plane qaysi komponentlardan iborat?
- Qaysi vaziyatda Compose, qaysida Swarm, qaysida Kubernetes tanlaysiz?
