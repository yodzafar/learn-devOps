# 5-dars: Orkestratsiyaga kirish (Docker Swarm va Kubernetes)

Maqsad: orkestrator qaysi muammolarni yechishini tushunish va ularni amalda ko'rish. 4-darsda Compose bitta hostda stack ko'tardi, lekin host o'lsa hamma narsa o'ladi, yangilash paytida uzilish bo'ladi, nusxalar orasida trafikni o'zingiz taqsimlaysiz. Bu darsda shu bo'shliqlarni Docker Swarm bilan qo'lda yopasiz (u Docker Engine ichida, o'rnatish kerak emas, Compose fayl formati bilan ishlaydi), keyin xuddi shu tushunchalarni Kubernetes atamalarida ko'rasiz. Kubernetes amaliyoti alohida modulda, bu yerda faqat arxitektura, asosiy obyektlar va bitta `kind` vazifasi. Dars modul mini-loyihasi bilan tugaydi.

Taxminiy vaqt: 4–5 kun (siz uchun). Mavzu yangi, shoshilmang. Diqqatni quyidagilarga qarating: desired state va reconciliation tushunchasi, service va task (konteyner) farqi, routing mesh va VIP orqali service discovery, rolling update parametrlari va healthcheck bilan bog'liqligi, secret'larning o'zgarmasligi, Compose fayl bilan stack fayl orasidagi farqlar, Swarm tushunchalarining Kubernetes'dagi mos keluvchilari.

## Laboratoriya

Uch muhit ishlatiladi:

| Muhit | Qayerda | Vazifalar |
|-------|---------|-----------|
| Bir node'li Swarm | ish mashinasidagi Docker Engine | A, B, E guruhlar |
| Uch node'li Swarm | `docker:29-dind` konteynerlari (Docker ichida Docker) | C guruh |
| `kind` klasteri | Docker konteynerlari ichidagi Kubernetes | D guruh |

**Bir node'li Swarm.** `docker swarm init` ish mashinasidagi daemon'ni Swarm rejimiga o'tkazadi: `ingress` va `docker_gwbridge` tarmoqlari paydo bo'ladi, 2377-port tinglanadi. Oddiy konteynerlaringiz va Compose project'laringiz ishlashda davom etadi. Mashinangizda bir necha tarmoq interfeysi bor, shuning uchun manzilni aniq bering:

```
docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
docker info | grep -A3 "Swarm:"
```

Qaytarish (dars oxirida majburiy):

```
docker stack rm <stack>            # for every stack
docker swarm leave --force
docker network rm docker_gwbridge
docker info | grep "Swarm:"        # Swarm: inactive
```

**Diqqat:** Swarm'da publish qilingan port barcha interfeyslarda ochiladi, `127.0.0.1` ga bog'lab bo'lmaydi. Vazifalarni ishonchli tarmoqda bajaring va ishdan keyin servislarni o'chiring.

**dind klasteri.** Har "node" `--privileged` konteyner, ichida o'z `dockerd` si bor. Ish mashinasidagi Swarm holatiga bog'liq emas. Barcha resurslar `l5-` prefiksi bilan. `--privileged` konteyner izolyatsiyasi kuchsiz (1-dars), ularni dars tugashi bilan o'chiring.

**kind va kubectl.** Ikkalasi bitta binary, `~/.local/bin` ga `sudo` siz o'rnatiladi (bu papka sizning `PATH` ingizda bor):

- kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation (release binary yoki `go install`)
- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/ ("Install kubectl binary with curl" bo'limi, lekin `sudo install` o'rniga faylni `~/.local/bin/kubectl` ga ko'chiring)

kind node image'i katta (1 GB atrofida), birinchi `kind create cluster` yuklash tufayli bir necha daqiqa oladi. Tozalash: `kind delete cluster --name l5`.

---

## 1. Nima uchun orkestratsiya

Bitta host va `docker compose up` yetmaydigan nuqtalar:

| Muammo | Qo'lda | Orkestrator |
|--------|--------|-------------|
| **Scheduling**: konteyner qaysi mashinada ishlasin | o'zingiz tanlaysiz, SSH qilasiz | bo'sh resurs, cheklov va label'larga qarab o'zi joylashtiradi |
| **Self-healing**: konteyner yoki host o'ldi | pager, qo'lda restart | holatni kuzatadi, yetishmayotgan nusxani boshqa node'da ko'taradi |
| **Scaling**: 3 nusxadan 10 ga | 7 marta `run`, proxy config'ni yangilash | bitta son o'zgaradi |
| **Service discovery va load balancing**: nusxalar IP'si doim o'zgaradi | nginx reload (4-dars, stale upstream) | barqaror nom va virtual IP, trafik sog'lom nusxalarga |
| **Rolling update va rollback** | to'xtat, yangila, ishga tushir: uzilish | nusxalarni navbat bilan almashtiradi, xato bo'lsa qaytaradi |
| **Config va secret** | fayllarni har hostga nusxalash | markaziy saqlanadi, kerakli konteynerga yetkaziladi |

### Desired state va reconciliation

Asosiy g'oya imperativ emas, deklarativ: siz "3 ta nusxa ishga tushir" demaysiz, "3 ta nusxa **bo'lishi kerak**" deysiz. Orkestrator cheksiz siklda ishlaydi:

```
observe actual state -> compare with desired state -> act to remove the difference -> repeat
```

Nusxa o'lsa farq paydo bo'ladi va sikl uni yopadi. Self-healing, scaling va rolling update shu bitta mexanizmning turli ko'rinishlari. Kubernetes'da buni controller, Swarm'da orchestrator bajaradi.

Oqibat: orkestrator ostida konteynerlar **cattle, not pets**. Ular istalgan payt o'ldirilishi va boshqa node'da qayta yaratilishi mumkin. Ilova shunga tayyor bo'lishi kerak: holat tashqarida (baza, volume), `SIGTERM` da toza to'xtash (1-dars), aniq healthcheck (3-dars), tez start.

## 2. Docker Swarm: tushunchalar

| Tushuncha | Ma'nosi |
|-----------|---------|
| **node** | klasterdagi Docker Engine. **manager** (holatni saqlaydi, qaror qiladi) yoki **worker** (faqat task bajaradi) |
| **service** | desired state tavsifi: image, nusxalar soni, portlar, yangilash qoidalari |
| **task** | service'ning bitta nusxasi, bitta konteynerga mos. O'lgan task tiklanmaydi, o'rniga yangisi yaratiladi |
| **stack** | compose fayldan yaratilgan service, tarmoq va secret'lar guruhi |
| **overlay network** | node'lar ustidan yagona virtual tarmoq (VXLAN) |

Manager'lar holatni Raft konsensus algoritmi bilan saqlaydi. Qaror qabul qilish uchun ko'pchilik (quorum) kerak: 3 manager 1 ta yo'qotishga, 5 manager 2 ta yo'qotishga chidaydi. Shuning uchun manager soni toq. Quorum yo'qolsa ishlayotgan task'lar ishlashda davom etadi, lekin klasterni boshqarib bo'lmaydi.

Node'lar orasidagi portlar: `2377/tcp` (boshqaruv), `7946/tcp+udp` (node'lar aloqasi), `4789/udp` (overlay trafigi).

### Service buyruqlari

```
docker service create --name web --replicas 3 -p 8080:80 nginx:1.28-alpine
docker service ls
docker service ps web                 # tasks, their nodes and history
docker service logs -f web
docker service scale web=5
docker service inspect --pretty web
docker service rm web
```

`docker service ps` task tarixini ko'rsatadi: o'lgan task `Shutdown` yoki `Failed` holatida qoladi, yonida yangisi `Running`. Konteynerni `docker kill` qilsangiz Swarm bir necha sekundda o'rnini to'ldiradi.

Rejimlar: `replicated` (N nusxa, default) va `global` (har node'da bittadan: log yig'uvchi, monitoring agenti).

### Tarmoq: routing mesh va service discovery

- **Routing mesh**: `-p 8080:80` portni klasterdagi **har node'da** ochadi. So'rov istalgan node'ga kelsa, task o'sha node'da bo'lmasa ham, `ingress` overlay tarmog'i orqali sog'lom task'ga yetkaziladi.
- **VIP**: har service overlay tarmoqda barqaror virtual IP oladi. Service nomi DNS'da shu VIP'ga yechiladi, kernel (IPVS) trafikni task'lar orasida taqsimlaydi. Task'lar almashganda VIP o'zgarmaydi: 4-darsdagi stale upstream muammosi yo'qoladi.
- `tasks.<service>` nomi alohida task IP'lari ro'yxatini qaytaradi.

Healthcheck bu yerda ishga tushadi: `unhealthy` task trafikdan chiqariladi va almashtiriladi (yolg'iz Docker'da u faqat belgi edi).

## 3. Stack, rolling update, secrets

### Stack deploy

```
docker stack deploy -c stack.yaml shop
docker stack services shop
docker stack ps shop
docker stack rm shop
```

`docker stack deploy` Compose fayl formatini o'qiydi, lekin o'z (eski, v3) sxemasi bilan. Asosiy farqlar:

| Compose'da | Stack'da |
|------------|----------|
| `build` | e'tiborsiz. Image registry'da tayyor bo'lishi kerak |
| `container_name`, `restart` | e'tiborsiz. Qayta ishga tushirish `deploy.restart_policy` da |
| `depends_on` | faqat ro'yxat shakli qabul qilinadi (`condition` li uzun shakl xato), tartib baribir kafolatlanmaydi |
| `name:` (yuqori daraja) | xato: `additional property 'name' is not allowed`. Nom buyruqda beriladi |
| `profiles`, `develop` | ishlatilmaydi |
| `deploy:` (`replicas`, `update_config`, `placement`) | to'liq ishlaydi |
| tarmoq | default driver `overlay` |

Deploy qilmasdan tekshirish: `docker stack config -c stack.yaml`. Ishga tushish tartibi yo'qligi sababli ilova bog'liqliklarini o'zi kutishi (retry) shart.

```
services:
  app:
    image: ghcr.io/<user>/l4-app:1.0.0
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
        failure_action: rollback
      restart_policy:
        condition: on-failure
      resources:
        limits: { cpus: "0.50", memory: 128M }
```

### Rolling update

`docker service update --image <new> web` (yoki yangi tag bilan qayta `stack deploy`) task'larni partiyalab almashtiradi:

| Parametr | Default | Ma'nosi |
|----------|---------|---------|
| `parallelism` | 1 | bir vaqtda nechta task almashtiriladi |
| `delay` | 0s | partiyalar orasidagi kutish |
| `order` | `stop-first` | `stop-first`: avval eskisi to'xtaydi. `start-first`: avval yangisi ko'tariladi (sig'im kamaymaydi, vaqtincha ortiqcha resurs kerak) |
| `failure_action` | `pause` | yangi task ko'tarilmasa: `pause`, `continue`, `rollback` |
| `monitor` | 5s | har task'dan keyin xatoni kuzatish vaqti |

Swarm yangi task'ni healthcheck `healthy` bo'lgandan keyingina tayyor deb hisoblaydi. Healthcheck yo'q bo'lsa "konteyner start bo'ldi" yetarli sanaladi va buzilgan versiya barcha nusxalarga tarqaladi. Qo'lda qaytarish: `docker service rollback web`.

**Tuzoq: uzilishsiz yangilash faqat orkestratorga bog'liq emas.** Eski task `SIGTERM` oladi; ilova uni ushlamasa yoki ochiq so'rovlarni tugatmasa mijozlar xato ko'radi. `stop_grace_period`, graceful shutdown va healthcheck uchalasi birga kerak.

### Secrets

```
printf '%s' "$DB_PASSWORD" | docker secret create db_password -
docker secret ls
docker service create --name db --secret db_password \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/db_password postgres:17-alpine
```

Secret Raft log'ida shifrlangan saqlanadi, faqat uni so'ragan service'ning task'lari ishlayotgan node'larga yuboriladi va konteynerda `/run/secrets/<name>` da xotiradagi (tmpfs) fayl bo'lib ko'rinadi. `docker secret inspect` qiymatni ko'rsatmaydi.

Secret **o'zgarmas**: qiymatni yangilab bo'lmaydi. Rotatsiya: yangi nomli secret yaratish (`db_password_v2`), service'ni `--secret-rm` va `--secret-add` bilan yangilash (bu rolling update), eskisini o'chirish. Stack faylda `file:` orqali berilgan secret o'zgarsa qayta deploy xato beradi, shu sababli nomga versiya qo'shiladi. Maxfiy bo'lmagan fayllar uchun xuddi shunday `docker config`.

**Tuzoq: volume node'ga bog'langan.** Named volume har node'da alohida. Baza task'i boshqa node'ga ko'chsa bo'sh volume bilan ko'tariladi. Holatli servis `deploy.placement.constraints` bilan bitta node'ga bog'lanadi yoki tashqi storage ishlatiladi.

## 4. Kubernetes: umumiy ko'rinish

Kubernetes (K8s) xuddi shu g'oyani (desired state, reconciliation) ancha umumiy va kengaytiriladigan ko'rinishda amalga oshiradi. Amalda sanoat standarti: barcha yirik cloud'larda managed xizmat sifatida bor (EKS, GKE, AKS).

### Arxitektura

| Komponent | Qayerda | Vazifasi |
|-----------|---------|----------|
| `kube-apiserver` | control plane | yagona kirish nuqtasi (REST API). Hamma narsa faqat u orqali gaplashadi |
| `etcd` | control plane | klaster holati saqlanadigan key-value baza (Raft) |
| `kube-scheduler` | control plane | yangi Pod uchun node tanlaydi |
| `kube-controller-manager` | control plane | reconciliation sikllari (Deployment, ReplicaSet, Node va boshqa controller'lar) |
| `kubelet` | har node | API'dan o'ziga tayinlangan Pod'larni olib, container runtime orqali ishga tushiradi, holatni qaytaradi |
| `kube-proxy` | har node | Service'lar uchun tarmoq qoidalari |
| container runtime | har node | containerd yoki CRI-O. Docker Engine kerak emas; Docker'da qurilgan OCI image o'zgarishsiz ishlaydi |

`kubectl` CLI apiserver'ga so'rov yuboradi, xuddi `docker` CLI `dockerd` ga yuborgandek.

### Asosiy obyektlar

| Obyekt | Ma'nosi |
|--------|---------|
| **Pod** | eng kichik birlik: bitta yoki bir necha konteyner, umumiy network namespace (bitta IP) va volume'lar bilan |
| **ReplicaSet** | N ta bir xil Pod bo'lishini ta'minlaydi |
| **Deployment** | ReplicaSet'larni boshqaradi: rolling update, rollback |
| **Service** | Pod'lar to'plami uchun barqaror nom va virtual IP (`ClusterIP`, `NodePort`, `LoadBalancer`) |
| **Ingress** | HTTP darajasidagi tashqi kirish: host va path bo'yicha yo'naltirish |
| **ConfigMap**, **Secret** | konfiguratsiya va maxfiy qiymatlar, env yoki fayl sifatida ulanadi |
| **Namespace** | obyektlarni mantiqiy guruhlash |
| **StatefulSet**, **DaemonSet**, **Job**, **CronJob** | holatli ilovalar, har node'da bittadan, bir martalik va jadvalli ishlar |
| **PersistentVolume**, **PersistentVolumeClaim** | node'dan mustaqil storage |

Obyektlar YAML manifest bilan tavsiflanadi va `kubectl apply -f` bilan yuboriladi. Obyektlar bir-biriga **label va selector** orqali bog'lanadi: Service "label'i `app=web` bo'lgan barcha Pod'lar" deydi, aniq Pod nomini emas.

### Swarm va Kubernetes

| | Docker Swarm | Kubernetes |
|---|--------------|------------|
| O'rnatish | Docker Engine ichida, `swarm init` | alohida klaster (managed xizmat, kubeadm, k3s, lokal uchun kind) |
| Eng kichik birlik | task (bitta konteyner) | Pod (bir yoki bir necha konteyner) |
| Nusxalar | service `replicas` | Deployment, ReplicaSet |
| Service discovery | service nomi, VIP | Service, ClusterIP, klaster DNS |
| Tashqi kirish | routing mesh | Service `NodePort`/`LoadBalancer`, Ingress |
| Konfiguratsiya formati | Compose fayl (`deploy:` bilan) | YAML manifestlar, Helm, Kustomize |
| Rolling update | `update_config` | Deployment `strategy` (`maxSurge`, `maxUnavailable`) |
| Sog'liq tekshiruvi | bitta `healthcheck` | uch alohida probe: liveness, readiness, startup |
| Holat ombori | manager'lardagi Raft | etcd |
| Avtomatik scaling | yo'q (qo'lda `scale`) | HorizontalPodAutoscaler, cluster autoscaler |
| Storage | node-lokal volume, plugin'lar | PV/PVC, StorageClass, CSI driver'lar |
| Kengaytirish | cheklangan | CRD va operator'lar, katta ekotizim |
| O'rganish narxi | past | yuqori |
| Qachon | kichik jamoa, bir necha server, Compose'dan tabiiy keyingi qadam | katta yoki o'sayotgan tizim, cloud, ekotizim kerak bo'lganda |

Swarm o'rganish uchun qulay: orkestratsiya tushunchalari ortiqcha obyektlarsiz ko'rinadi. Ish bozorida va cloud'da talab Kubernetes'ga, shuning uchun kurs unga alohida modul ajratadi.

## Tuzoqlar

- Healthcheck'siz rolling update: buzilgan versiya "muvaffaqiyatli" tarqaladi, chunki konteyner start bo'lgani yetarli sanaladi.
- `SIGTERM` ni ushlamaydigan ilova: har yangilashda uzilgan so'rovlar, orkestrator buni yecha olmaydi.
- Holatni konteyner ichida yoki node-lokal volume'da saqlab, servisni bir necha node'ga tarqatish: task ko'chganda ma'lumot "yo'qoladi".
- Juft sonli yoki bitta manager: bitta manager'ning yo'qolishi klaster boshqaruvini to'xtatadi. Manager'lar holati (Raft) backup qilinmasa klasterni tiklab bo'lmaydi.
- Stack faylda `latest` tag: har node har xil vaqtda pull qiladi va turli versiyalar ishlaydi. Aniq tag yoki digest.
- Compose faylni o'zgarishsiz stack sifatida deploy qilish: `build`, `depends_on` shartlari, `restart` jimgina yoki xato bilan tushib qoladi. `docker stack config` bilan tekshiring.
- Swarm'da publish qilingan port har node'ning barcha interfeyslarida ochiq. Firewall'ni klaster darajasida rejalashtiring.
- Resurs limiti va reservation'siz scheduling: orkestrator node'ni to'ldirib yuboradi va OOM killer tasodifiy task'larni o'ldiradi.
- Lokal build qilingan image'ni ko'p node'li klasterga deploy qilish: boshqa node'larda image yo'q, task `Pending` yoki `Rejected`. Image registry'da bo'lishi kerak, private bo'lsa `--with-registry-auth`.
- Orkestratorni "kerak bo'lib qolar" deb erta kiritish: bitta server va Compose ko'p kichik loyihalar uchun yetarli, murakkablikning narxi bor.

## Manbalar

- https://docs.docker.com/engine/swarm/ – Swarm mode umumiy ko'rinishi
- https://docs.docker.com/engine/swarm/key-concepts/ – node, service, task tushunchalari
- https://docs.docker.com/engine/swarm/swarm-tutorial/ – rasmiy qo'llanma (init, service, rolling update, drain)
- https://docs.docker.com/engine/swarm/ingress/ – routing mesh
- https://docs.docker.com/engine/swarm/secrets/ – Swarm secrets
- https://docs.docker.com/engine/swarm/stack-deploy/ – stack deploy
- https://docs.docker.com/reference/compose-file/deploy/ – `deploy` kaliti
- https://docs.docker.com/engine/swarm/admin_guide/ – manager soni, quorum, backup
- https://kubernetes.io/docs/concepts/overview/components/ – Kubernetes komponentlari
- https://kubernetes.io/docs/concepts/workloads/ – Pod, Deployment va boshqa workload'lar
- https://kubernetes.io/docs/concepts/services-networking/service/ – Service
- https://kind.sigs.k8s.io/docs/user/quick-start/ – kind
- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/ – kubectl o'rnatish
- Burns, Beda, Hightower, "Kubernetes: Up and Running" (O'Reilly), 1–2-boblar: keyingi modulga tayyorgarlik

---

## Vazifalar

Barchasini `docker/05-orchestration-intro/` da bajaring (`make new m=docker n=05 name=orchestration-intro`). Javoblar shu papkadagi `README.md` da, har vazifa `## N. Title` sarlavhasi ostida: ishlatilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. `stack.yaml`, skriptlar va `RUNBOOK.md` shu papkada saqlanadi. Secret qiymatlari, join token'lar va kubeconfig README'ga yozilmaydi va commit qilinmaydi.

### A. Swarm asoslari (bir node)

1. **Swarm init.** Avval `docker swarm init` ni flag'siz ishlatib xatoni o'qing va izohlang. Keyin Laboratoriya bo'limidagi buyruq bilan yarating. `docker node ls`, `docker info` ning Swarm qismi va `docker network ls` da nima yangi paydo bo'lganini yozing. Bu node manager'mi, worker'mi, ikkalasimi?

2. **Service and tasks.** `nginx:1.28-alpine` dan 3 nusxali `l5-web` service yarating (port publish bilan). `docker service ls`, `docker service ps`, `docker ps` chiqishlarini solishtiring: service, task va konteyner nomlari qanday bog'langan? `docker service inspect --pretty` dan update va restart sozlamalarining default qiymatlarini yozing.

3. **Self-healing.** Task konteynerlaridan birini `docker kill` qiling. `docker service ps l5-web` da nima ko'rindi, o'rnini to'ldirish qancha vaqt oldi? 1-darsdagi `--restart always` dan farqi nimada (kim qaror qiladi, konteyner o'shami yoki yangimi)?

4. **Scaling.** `docker service scale l5-web=6`, keyin `=2` qiling. Qaysi task'lar o'chirilgani va tartibini kuzating. Keyin `docker service update --reserve-memory` ni host xotirasidan aniq katta qiymatga qo'ying: yangi task qaysi holatda qoldi va `docker service ps --no-trunc` nima deydi? Qiymatni qaytaring.

5. **VIP and service DNS.** `--attachable` overlay tarmoq yarating, unda `traefik/whoami:v1.10` dan 3 nusxali `l5-whoami` service ishga tushiring. Shu tarmoqqa ulangan `alpine` konteyneridan: `nslookup l5-whoami`, `nslookup tasks.l5-whoami`, va 6 marta `wget -qO- http://l5-whoami` qilib javobdagi `Hostname` larni sanang. VIP va task IP'lari farqini, 4-darsdagi nginx upstream muammosi bu yerda nima uchun yo'qligini izohlang.

### B. Yangilash va secrets

6. **Rolling update.** Boshqa terminalda `while true; do curl -s -o /dev/null -w "%{http_code}\n" localhost:<port>; sleep 0.2; done` ni ishga tushiring. `l5-web` ni `nginx:1.29-alpine` ga `--update-parallelism 1 --update-delay 5s` bilan yangilang. `docker service ps` da ketma-ketlikni yozing. `200` bo'lmagan javoblar bo'ldimi? `--update-order start-first` bilan orqaga (1.28) yangilab solishtiring.

7. **Failed update and rollback.** Service'ga healthcheck qo'shing (`--health-cmd`, qisqa interval). Keyin mavjud bo'lmagan tag'ga yoki healthcheck'i hech qachon o'tmaydigan konfiguratsiyaga yangilang: default `failure_action` da nima bo'ldi, nechta task zarar ko'rdi? `docker service rollback` qiling. Xuddi shuni `--update-failure-action rollback` bilan takrorlab avtomatik qaytishni ko'rsating.

8. **Secrets.** `printf` va stdin orqali `l5_db_password` secret yarating (qiymat shell history'ga tushmasin, qanday qilganingizni yozing). `postgres:17-alpine` service'ini `POSTGRES_PASSWORD_FILE` bilan ishga tushiring. Konteyner ichida `/run/secrets/` dagi fayl ruxsatlari va `mount` chiqishidagi fayl tizimi turini ko'rsating. `docker secret inspect` va `docker service inspect` da qiymat ko'rinadimi?

9. **Secret rotation.** Ishlatilayotgan secret'ni o'chirishga urining, xatoni yozing. Yangi `l5_db_password_v2` yarating va `--secret-rm`/`--secret-add` (`source` va `target` bilan, konteynerdagi fayl nomi o'zgarmasin) orqali almashtiring. Bu nima uchun rolling update'ni ishga tushirdi? Postgres uchun fayldagi yangi parol haqiqatan ham baza parolini o'zgartirdimi (3-dars, 2-vazifani eslang)?

10. **Compose to stack.** 4-darsdagi `compose.yaml` ni o'zgarishsiz `docker stack config -c` ga bering va xatolarni bittalab o'qib tuzating, har birini README'ga yozing. Natijani `stack.yaml` sifatida saqlang: registry'dagi image'lar (2-darsdagi usul bilan push qiling), `deploy` bo'limlari, overlay tarmoqlar, secret'lar. `docker stack deploy` qilib `docker stack services` va `curl` bilan ishlashini ko'rsating. `depends_on` shartlari yo'qligini ilova qanday ko'tardi?

### C. Ko'p node (dind)

11. **Three-node cluster.** `l5-swarm` bridge tarmog'ida uchta `docker:29-dind` konteyner (`l5-m1`, `l5-w1`, `l5-w2`, `--privileged`, hostname bilan) ishga tushiring; `l5-m1` ning 8080-portini hostga `127.0.0.1:8088` sifatida publish qiling. `docker exec l5-m1 docker swarm init`, token bilan ikki worker'ni qo'shing. `docker exec l5-m1 docker node ls` ni yozing. Buyruqlarni `cluster-up.sh` va `cluster-down.sh` ga yig'ing (token faylga yozilmasin).

12. **Scheduling and routing mesh.** `l5-m1` da `traefik/whoami:v1.10` dan 4 nusxali service'ni `-p 8080:80` bilan yarating. Task'lar node'larga qanday taqsimlandi? Hostdan `curl 127.0.0.1:8088` ni 8 marta chaqiring: javob beradigan task'lar faqat `l5-m1` dagilarmi? Routing mesh buni qanday ta'minlaydi? `--constraint node.role==worker` bilan qayta yaratib taqsimotni solishtiring.

13. **Node failure and drain.** `docker stop l5-w2` qiling. `docker node ls` va `docker service ps` da node va task holatlari qanday o'zgardi, qancha vaqtda? `l5-w2` ni qayta `start` qiling: task'lar unga o'zi qaytdimi? Keyin `docker node update --availability drain l5-w1` qilib rejali xizmat ko'rsatish ssenariysini ko'rsating va `active` ga qaytaring. Oxirida `cluster-down.sh` bilan hammasini o'chiring.

14. **Quorum reasoning.** Amaliyotsiz, yozma: 1, 2, 3, 4, 5 manager'li klaster nechta manager yo'qolishiga chidaydi (jadval)? Nima uchun 4 manager 3 dan yaxshi emas? Quorum yo'qolganda ishlayotgan servislar va `docker service update` bilan nima bo'ladi?

### D. Kubernetes bilan tanishuv

15. **Concept mapping.** Jadval tuzing: shu modulda ishlatgan har Docker va Swarm tushunchasi (container, image, service, task, replicas, published port va routing mesh, overlay DNS nomi, secret, config, healthcheck, stack fayl, `docker service update`, node drain, placement constraint) uchun Kubernetes'dagi eng yaqin tushuncha va bir qatorlik farq. Manba: `kubernetes.io/docs/concepts`.

16. **kind taste.** `kind` va `kubectl` ni `~/.local/bin` ga o'rnating (versiyalarni yozing). `kind create cluster --name l5`. Ko'rsating: `docker ps` da klaster nima ko'rinishda, `kubectl get nodes -o wide`, `kubectl get pods -A` (control plane komponentlarini 4-bo'limdagi jadval bilan moslang). Keyin: `kubectl create deployment web --image=nginx:1.28-alpine --replicas=3`, bitta Pod'ni `kubectl delete pod` qilib self-healing'ni, `kubectl scale` ni, `kubectl expose deployment web --port=80` va `kubectl port-forward service/web 8089:80` orqali `curl` ni, `kubectl set image deployment/web nginx=nginx:1.29-alpine` va `kubectl rollout status` ni, `kubectl rollout undo` ni bajaring. Har qadam uchun Swarm'dagi mos buyruqni yonma-yon yozing. Oxirida `kind delete cluster --name l5`.

17. **Read a manifest.** `kind` klasteri o'chirilishidan oldin `kubectl get deployment web -o yaml` ni faylga saqlang (commit qilish mumkin, unda secret yo'q). `spec.replicas`, `spec.selector`, `spec.template`, `spec.strategy`, `status` qismlarini topib har birini bir gapda izohlang. `spec` va `status` ajratilishi 1-bo'limdagi qaysi g'oyaning ko'rinishi?

### E. Modul mini-loyihasi

18. **Stack hardening.** 10-vazifadagi `stack.yaml` ni yakuniy holatga keltiring: `app` 3 nusxa, `start-first` va `failure_action: rollback`, barcha servislarda healthcheck va resurs limiti, `stop_grace_period`, secret'lar versiyali nom bilan, baza `placement` bilan bog'langan va named volume'da, faqat nginx publish qilingan, barcha image'lar aniq tag bilan registry'dan. `docker stack config` toza.

19. **Zero-downtime release.** Ilovaga ko'rinadigan o'zgarish kiritib `1.1.0` tag bilan build va push qiling. 6-vazifadagi `curl` sikli ishlab turganida stack'ni yangi tag bilan qayta deploy qiling. Natija: jami so'rovlar soni, `200` bo'lmaganlar soni (maqsad: nol), yangilash davomiyligi. Nol bo'lmasa sababini toping (graceful shutdown, healthcheck, `order`) va tuzatib takrorlang.

20. **Bad release drill.** `/healthz` i `500` qaytaradigan `1.2.0-bad` versiyasini build va push qilib deploy qiling. Swarm avtomatik rollback qilganini `docker service ps` va `docker service inspect` (`UpdateStatus`) orqali ko'rsating. Mijozlar bu vaqtda xato ko'rdimi?

21. **Runbook.** `RUNBOOK.md` yozing (1–2 sahifa, o'z so'zingiz bilan): arxitektura sxemasi (matnli), deploy, yangi versiya chiqarish, rollback, secret rotatsiyasi, baza backup va restore (3-dars), "servis javob bermayapti" holatida tekshirish ketma-ketligi (qaysi buyruq, nimaga qarash), ma'lum cheklovlar (bitta node, volume lokal). Har buyruq siz haqiqatan ishlatgan buyruq bo'lsin.

22. **Cleanup.** `docker stack rm`, secret va overlay tarmoqlarni o'chiring, `docker swarm leave --force`, `docker network rm docker_gwbridge`. dind konteynerlari va `l5-swarm` tarmog'i, `kind` klasteri o'chirilganini tekshiring. Registry'dagi test tag'larni o'chiring yoki private qoldiring, `docker logout`. Yakuniy `docker info | grep Swarm`, `docker ps -a`, `docker volume ls`, `docker network ls`, `kind get clusters` chiqishini yozing va boshqa loyiha resurslari joyida ekanini tasdiqlang.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza, `shellcheck` barcha skriptlar uchun hech narsa chiqarmaydi.
2. `docker stack config -c stack.yaml` xatosiz.
3. `Swarm: inactive`, dind konteynerlari va `kind` klasteri yo'q, `docker_gwbridge` o'chirilgan.
4. Secret qiymatlari, token'lar, kubeconfig commit qilinmagan.
5. Menga xabar bering: `stack.yaml`, `RUNBOOK.md` va `README.md` ni o'qib chiqaman. Bu modulning yakuniy tekshiruvi.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Desired state va reconciliation nima? Self-healing, scaling va rolling update shu g'oyaga qanday bog'lanadi?
- Service, task va konteyner farqi nima? O'lgan task bilan nima bo'ladi?
- Routing mesh va service VIP har biri qaysi trafikni boshqaradi?
- Rolling update'da healthcheck qanday rol o'ynaydi? Usiz nima bo'ladi?
- `stop-first` va `start-first` farqi, har birining narxi nima?
- Swarm secret env o'zgaruvchidan nimasi bilan yaxshi? Nima uchun uni yangilab bo'lmaydi va rotatsiya qanday qilinadi?
- Compose faylni stack sifatida deploy qilganda qaysi kalitlar ishlamaydi va nima uchun `build` yo'q?
- Nima uchun manager soni toq bo'lishi kerak?
- Kubernetes'da Pod, Deployment va Service har biri nima uchun javob beradi? Control plane qaysi komponentlardan iborat?
- Qaysi vaziyatda Compose, qaysida Swarm, qaysida Kubernetes tanlaysiz?
