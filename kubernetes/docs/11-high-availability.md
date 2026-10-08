# 11-dars: Production High Availability

Maqsad: hozirgacha "3 replica" yozish yetarli tuyulgan edi. Lekin uchala Pod bitta node'ga tushsa, o'sha node o'chganda servis ham o'chadi; node drain qilinsa hamma replica bir vaqtda evict bo'lishi mumkin; rollout paytida so'rovlarning bir qismi 502 oladi. Bu darsda replica'larni node va zona bo'ylab yoyish (affinity, anti-affinity, topology spread), rejali uzilishlardan himoya (PodDisruptionBudget, drain), ustuvorlik (PriorityClass, preemption) va Pod'ni so'rov yo'qotmasdan to'xtatish (graceful shutdown) ko'riladi. Control plane'ning o'zi qanday qilib bardoshli qilinishi (etcd quorum, bir nechta API server, leader election) ham alohida bo'lim. Hammasi ko'p node'li kind klasterida node'ni drain qilib va o'chirib sinaladi. 12-darsdagi ma'lumotlar bazasi va 14-darsdagi autoscaling shu asosga tayanadi.

High availability (HA, "yuqori mavjudlik") bu tizimning bir qismi ishdan chiqqanda ham xizmat ko'rsatishda davom eta olishi. Bu "hech qachon buzilmaydi" degani emas, "bitta narsa buzilganda foydalanuvchi sezmaydi yoki kam sezadi" degani.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun Laboratoriya, 1–4 bo'limlar va A, B guruhlar. Ikkinchi kun 5–6 bo'limlar va C, D guruhlar (node o'chirib kutish vaqt oladi, har sinov 6–8 daqiqa). Uchinchi kun 7–8 bo'limlar, "Birga bajaramiz", E va F guruhlar. Diqqat: `required` va `preferred` farqi va har birining narxi, PDB aynan nimadan himoya qiladi va nimadan yo'q, node o'chganda Pod'lar nima uchun 5 daqiqa kutadi, `SIGTERM` va endpoint yangilanishi orasidagi poyga.

Qanday o'qish kerak: har bo'limdagi manifestni o'qing, keyin `ha` klasterida shunga o'xshash (aynan o'zi emas) narsani ishga tushirib, chiqishni darsdagi izoh bilan solishtiring. Pod nomlaridagi tasodifiy suffiks, vaqt va `AGE` sizda boshqa bo'ladi, darsda bunday joylar `<...>` bilan belgilangan. Bu darsda vaqt asosiy o'lchov: ikkita yoki uchta terminal oching, birida `kubectl get pods -o wide -w`, ikkinchisida `kubectl get nodes -w`, uchinchisida buyruqlar. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Asosiy muhit: host'dagi Docker ustida 1 control-plane va 3 worker'li kind klasteri `ha`. Worker'larga zona label'lari qo'yiladi, shunda bitta mashinada "uch zonali" klaster taqlid qilinadi. Zona (availability zone) bu cloud provayderdagi alohida elektr, sovutish va tarmoqqa ega ma'lumotlar markazi; bir zona butunlay o'chsa ham qo'shnisi ishlaydi. Kubernetes zonani node'dagi standart `topology.kubernetes.io/zone` label'idan biladi; cloud'da uni provayder qo'yadi, bizda kind konfiguratsiyasi.

```yaml
# kind-ha.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
    labels: { topology.kubernetes.io/zone: zone-a }
  - role: worker
    labels: { topology.kubernetes.io/zone: zone-b }
  - role: worker
    labels: { topology.kubernetes.io/zone: zone-c }
```

```bash
kind create cluster --name ha --config kind-ha.yaml
kubectl config current-context        # must print: kind-ha
```

Node'lar Docker konteynerlari: `ha-control-plane`, `ha-worker`, `ha-worker2`, `ha-worker3` (2-dars). Node "o'chishi" `docker stop ha-worker2`, qaytishi `docker start ha-worker2` bilan taqlid qilinadi. Bu haqiqiy elektr uzilishiga yaqin: kubelet birdaniga to'xtaydi, API server'ga xabar bermaydi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Klaster | Docker Engine ustida kind, node'lar `amd64` | Docker Desktop ustida kind, node'lar `arm64` |
| Node konteynerlari | host'dagi oddiy konteynerlar, `docker stop`/`start` bilan boshqariladi | Docker Desktop'ning yashirin Linux VM'i ichida, `docker stop`/`start` xuddi shunday ishlaydi |
| Node IP'lari (`172.18.0.x`) | host'dan ko'rinadi | Mac'dan ko'rinmaydi; trafikni klaster ichidagi Pod'dan yuboring |
| Resurs | `ha` klasteri taxminan 3–4 GB RAM | Docker Desktop'ga kamida 6 GB RAM (Settings, Resources) |
| `time` buyrug'i (19-vazifa) | bash formati: `real 0m31.2s` | zsh formati: `... 31.20s user ... total` |
| Multipass VM'lar (ixtiyoriy, 2-bo'lim) | `10.x` tarmog'ida, `amd64` | odatda `192.168.64.x` tarmog'ida, `aarch64` |

Uzilishni o'lchash uchun trafik har doim klaster ichidagi alohida Pod'dan yuboriladi: shunda ikkala mashinada natija bir xil va Mac'dagi Docker VM tarmog'i aralashmaydi. Image'lar: `nginx:1.28` (sinov servisi), `busybox:1.36` (so'rov sikli, `wget` va `sh` bor). Ikkalasi multi-arch, ikkala mashinada bir xil tag.

Xotira: `dev` klasteri (3-dars) va `ha` bir vaqtda kerak emas. Joy yetmasa `kind delete cluster --name dev`: u git'dagi manifestlardan qayta tiklanadi. "Birga bajaramiz" bo'limidagi `cp3` klasteri `ha` dan keyin, alohida ishga tushiriladi.

Control plane HA (2-bo'lim) asosan kind'da ko'rsatiladi. Haqiqiy VM'larda sinamoqchi bo'lsangiz, 2-darsdagidek uchta Multipass VM'da k3s bilan qilinadi. k3s o'rnatish paket va systemd unit qo'shadi, shuning uchun faqat VM ichida (CLAUDE.md, "Laboratoriya xavfsizligi").

Ikkinchi mashinada tiklash: klaster holati ko'chmaydi, git orqali `kind-ha.yaml`, manifestlar va README keladi. Ikkinchi mashinada `kind create cluster --name ha --config kubernetes/11-high-availability/kind-ha.yaml`, keyin `kubectl apply -f` bilan kerakli manifestlarni qo'llang. Qo'lda qilingan o'zgarishlar (`kubectl label node`, `cordon`, `docker stop`) ko'chmaydi, ularni qayta bajarasiz. Har vazifa boshida klaster "toza" bo'lsin: barcha node'lar `Ready`, cordon yo'q (`kubectl get nodes` da `SchedulingDisabled` yo'q).

Tozalash: `kind delete cluster --name ha` (va `cp3` yaratgan bo'lsangiz uni ham), `docker ps` da kind konteynerlari qolmasin. Multipass VM'lar: `multipass delete --purge <name>`.

---

## 1. Uzilish turlari va HA arifmetikasi

### Bu nima

Disruption (uzilish) bu Pod'ning o'z xohishisiz ishlashdan to'xtashi. Kubernetes ularni ikki turga ajratadi:

| Tur | Misollar | Nima himoya qiladi |
|-----|----------|--------------------|
| Voluntary (rejali) | `kubectl drain`, node upgrade, cluster autoscaler node'ni olib tashlashi, rollout | PodDisruptionBudget, rolling update sozlamalari, graceful shutdown |
| Involuntary (kutilmagan) | node apparat nosozligi, kernel panic, OOM, zona uzilishi, tarmoq bo'linishi | ortiqcha replica, node va zona bo'ylab yoyish |

Bu ajratish muhim: PDB (5-bo'lim) faqat birinchi qatorga ta'sir qiladi. Node yonib ketsa PDB hech narsa qila olmaydi.

### Mexanizm

Ikki tushuncha hamma narsaning asosi:

- **Failure domain** (nosozlik domeni) bu bitta sababdan birga ishdan chiqadigan narsalar to'plami. Node bitta domen (uning ustidagi hamma Pod birga o'ladi), zona kattaroq domen, region undan ham katta.
- **Redundancy** (ortiqchalik) bu bir domen yo'qolganda qolganlari ishni ko'tarishi uchun zaxira. Replica'lar faqat turli domenlarda bo'lsagina ortiqchalik beradi.

HA arifmetikasi sodda: N ta replica'dan bir vaqtda nechtasi yo'qolishi mumkin va qolgani yukni ko'tara oladimi. Uch zonaga yoyilgan 3 replica bitta zona yo'qolganda quvvatning 1/3 qismini yo'qotadi, demak qolgan ikkitasi 150% yukni ko'tara olishi kerak. Requests (4-dars) va autoscaling (14-dars) shu hisobdan kelib chiqadi. Rejali uzilish bilan kutilmagani ustma-ust tushishi ham mumkin: siz node'ni drain qilayotganda boshqa node o'lsa, ikki domen birdaniga yo'q. Shuning uchun zaxira "N+1" emas, ko'pincha "N+2" hisoblanadi.

Rejali uzilishlar bitta yo'ldan o'tadi: Eviction API (Pod'ni "qoidalarga rioya qilib" chiqarishni so'raydigan maxsus API, 5-bo'lim). Kutilmaganlari hech qanday API'dan o'tmaydi: node shunchaki javob bermay qoladi va controller'lar buni keyinroq sezadi (6-bo'lim).

### Misol

Hech qanday qoidasiz 3 replica'li Deployment'ning joylashuvi (`-o wide` qo'shimcha ustunlar, jumladan `NODE` ni ko'rsatadi):

```
$ kubectl create deployment demo --image=nginx:1.28 --replicas=3
deployment.apps/demo created
$ kubectl get pods -l app=demo -o wide
NAME                    READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
demo-<hash>-<a1>        1/1     Running   0          12s   10.244.1.4   ha-worker    <none>           <none>
demo-<hash>-<b2>        1/1     Running   0          12s   10.244.1.5   ha-worker    <none>           <none>
demo-<hash>-<c3>        1/1     Running   0          12s   10.244.3.2   ha-worker3   <none>           <none>
```

- `NODE` ustuni HA uchun eng muhim ustun: ikki replica `ha-worker` da, ya'ni bitta domenda.
- `IP` Pod IP'si; `10.244.1.x` va `10.244.3.x` turli node'larning Pod tarmog'i (har node o'z subnet'ini oladi, 6-dars).
- `NOMINATED NODE` preemption paytida to'ldiriladi (7-bo'lim), hozir bo'sh.

Bu taqsimot har safar boshqacha chiqishi mumkin: scheduler yoyishga intiladi, lekin kafolat bermaydi (3-bo'lim). `ha-worker` o'chsa servis quvvatining uchdan ikkisi birdaniga yo'qoladi.

### Real ishda qachon kerak

Har production servis uchun loyihalash boshida ikki savol: "qaysi domen yo'qolishiga chidashimiz kerak" (node, zona, region) va "o'sha paytda qolgan replica'lar yukni ko'taradimi". Javob replica soni, joylashtirish qoidalari va requests qiymatiga aylanadi. Incident tahlilida (observability moduli) ham birinchi savol: bu uzilish rejalimi yoki yo'q.

### Nima uchun shunday

Kubernetes ikki turni ajratadi, chunki faqat rejali uzilishni boshqarish mumkin: drain'ni kutdirish, rollout'ni sekinlatish mumkin, lekin o'lgan node'ni kutdirib bo'lmaydi. Shuning uchun himoya ham ikki qatlam: rejali uchun "shartnoma" (PDB), kutilmagani uchun "geometriya" (yoyish va ortiqchalik). Muqobil yondashuv, har servisga alohida "maintenance" jadvalini qo'lda kelishish, katta klasterda ishlamaydi: yuzlab servis va o'nlab node bor.

## 2. Control plane HA

### Bu nima

1-darsdan eslang: control plane bu API server, etcd, scheduler va controller-manager. Ilova Pod'lari control plane'siz ham ishlayveradi (kubelet mavjud Pod'larni ushlab turadi, kube-proxy oxirgi bilgan qoidalarni saqlaydi), lekin hech narsa o'zgarmaydi: yangi Pod yo'q, o'lgan Pod qayta yaratilmaydi, Service endpoint'lari yangilanmaydi, `kubectl` ishlamaydi. Control plane HA bu komponentlarning har birini bir nechta nusxada ishlatish.

### Mexanizm: etcd va quorum

etcd (1-dars) klasterning yagona haqiqat manbai, Raft konsensus algoritmi bilan ishlaydi. Konsensus bu bir nechta server bitta qiymatga kelishib olishi; Raft'da a'zolardan biri leader (yozuvlarni qabul qiladi), qolganlari follower. Yozuv faqat ko'pchilik a'zo (quorum) uni saqlagandan keyin "qabul qilingan" hisoblanadi. Quorum formulasi: `floor(N/2)+1`.

- 3 a'zo: quorum 2, ya'ni 1 ta a'zo yo'qolishiga chidaydi.
- 5 a'zo: quorum 3, 2 ta a'zo yo'qolishiga chidaydi.
- Juft son qo'shimcha chidamlilik bermaydi, faqat quorum'ni oshiradi. Buni 3-vazifada jadval bilan o'zingiz ko'rasiz.

Quorum yo'qolsa etcd yozuvni rad etadi (va standart holatda o'qishni ham, chunki API server "linearizable" o'qish so'raydi). Amalda klaster "muzlaydi": `kubectl` xato beradi, mavjud Pod'lar ishlashda davom etadi.

Nima uchun ko'pchilik? Tarmoq bo'linganda (network partition) klaster ikki guruhga ajraladi. Agar ikkala guruh ham yozishni davom ettirsa, ikki xil "haqiqat" paydo bo'ladi (split-brain). Ko'pchilik qoidasi bilan faqat bitta guruh ko'pchilik bo'la oladi.

### Mexanizm: qolgan komponentlar

- **kube-apiserver** stateless (o'zida holat saqlamaydi, hammasi etcd'da), shuning uchun bir nechta nusxa bir vaqtda faol ishlaydi va load balancer ortida turadi. Kubeconfig va har node'dagi kubelet LB manziliga qaraydi, alohida API server'ga emas.
- **controller-manager va scheduler** ham bir nechta nusxa ishlaydi, lekin bir vaqtda faqat bittasi faol (leader election). Ikki scheduler bitta Pod'ni ikki joyga qo'ymasligi uchun. Leader `kube-system` dagi `Lease` obyektini (qisqa muddatli "qulf" yozuvi) muntazam yangilab turadi; yangilash to'xtasa, boshqa nusxa Lease'ni egallaydi.
- **Topologiya**: stacked (etcd control-plane node'larida, kubeadm standarti, kam mashina) yoki external etcd (etcd alohida node'larda, ko'proq mashina, lekin control plane node'ining o'limi etcd a'zosini olib ketmaydi).
- **k3s** embedded etcd bilan: birinchi server `--cluster-init`, qolganlari `--server` bilan unga qo'shiladi, kamida uchta server.
- **Managed Kubernetes** (EKS, GKE, AKS) control plane HA'ni o'zi beradi, siz uni ko'rmaysiz ham. Bu managed xizmat uchun to'lashning asosiy sababi.

etcd backup'i (snapshot) HA'ning o'rnini bosmaydi va aksincha: HA apparat nosozligidan, backup inson xatosidan (noto'g'ri o'chirish, buzilgan ma'lumot) himoya qiladi. HA klasterda `kubectl delete namespace prod` darhol uchala etcd a'zosiga ham yoziladi.

### Misol: leader election'ni ko'rish

Bitta control plane'li `ha` klasterida ham Lease'lar bor, faqat raqobatchi yo'q:

```
$ kubectl -n kube-system get lease
NAME                      HOLDER                          AGE
apiserver-<id>            apiserver-<id>_<uuid>           25m
kube-controller-manager   ha-control-plane_<uuid>         25m
kube-scheduler            ha-control-plane_<uuid>         25m
```

- `kube-controller-manager` va `kube-scheduler` qatorlari leader election Lease'lari. `HOLDER` hozirgi leader: node nomi va jarayonning tasodifiy identifikatori.
- `apiserver-<id>` har API server nusxasining o'z Lease'i, nechta API server tirikligini bilish uchun. Sizda yana bir nechta qator (boshqa komponentlar Lease'lari) bo'lishi mumkin.

Kubelet heartbeat'lari (6-bo'lim) alohida namespace'da, har node uchun bittadan:

```
$ kubectl -n kube-node-lease get lease
NAME               HOLDER             AGE
ha-control-plane   ha-control-plane   25m
ha-worker          ha-worker          25m
ha-worker2         ha-worker2         25m
ha-worker3         ha-worker3         25m
```

Har kubelet o'z Lease'ini taxminan har 10 soniyada yangilaydi; yangilanish to'xtasa node controller buni sezadi.

Uch control-plane'li klasterda xuddi shu jadvalda `HOLDER` uchtadan bittasini ko'rsatadi va leader node o'chirilsa, bir necha soniyada boshqasiga o'tadi. Buni "Birga bajaramiz" bo'limida ko'rasiz.

### Misol: k3s HA, Multipass VM'larda (ixtiyoriy)

2-darsdagidek uchta VM (`k1`, `k2`, `k3`, har biri 2 GB). Token tasodifiy generatsiya qilinadi va hech qayerga yozilmaydi:

```bash
# on k1: first server, initializes embedded etcd
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> K3S_TOKEN=<token> sh -s - server --cluster-init
# on k2 and k3: join as additional servers
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> K3S_TOKEN=<token> sh -s - server --server https://<k1-ip>:6443
```

```
$ sudo k3s kubectl get nodes
NAME   STATUS   ROLES                AGE   VERSION
k1     Ready    control-plane,etcd   5m    <version>
k2     Ready    control-plane,etcd   2m    <version>
k3     Ready    control-plane,etcd   1m    <version>
```

`ROLES` da `etcd` har server etcd a'zosi ekanini bildiradi (versiyaga qarab `master` ham qo'shilishi mumkin). Bu sxemada ham kubeconfig bitta server IP'siga qaraydi: haqiqiy HA uchun oldida LB yoki DNS nomi kerak, aks holda `k1` o'lsa `kubectl` ham o'ladi, garchi klaster ishlayotgan bo'lsa ham. Sinovdan keyin `multipass delete --purge k1 k2 k3`.

### Real ishda qachon kerak

O'zingiz boshqaradigan klasterda (kubeadm, k3s, on-premise) production uchun 3 control plane node standart. Managed klasterda bu sizning ishingiz emas, lekin tushunish kerak: API server qisqa vaqtga mavjud bo'lmasa (provayder upgrade qilganda) ilovangiz ishlaydi, faqat deploy va autoscaling to'xtaydi. Klasterni ixtiyoriy "control plane siz ham ishlashi" uchun loyihalash shu.

### Nima uchun shunday

Kubernetes holatni bitta joyda (etcd) saqlaydi va qolgan hamma narsani stateless qiladi: shunda HA muammosi faqat etcd'da qoladi, u esa yaxshi o'rganilgan Raft bilan hal qilingan. Leader election'ning muqobili, bir nechta faol scheduler va ular orasida qulflash, ancha murakkab bo'lardi; bitta faol va bir nechta kutib turgan nusxa sodda va bir necha soniyalik o'tish vaqti yetarli. Data plane'ning control plane'siz ishlay olishi ham ataylab: control plane'ning qisqa uzilishi foydalanuvchiga ko'rinmasligi kerak.

## 3. Pod'larni joylashtirish: affinity va anti-affinity

### Bu nima

Scheduler (1-dars) standart holatda Pod'larni node'lar bo'ylab yoyishga harakat qiladi, lekin bu ko'p mezonlardan biri, kafolat emas. Kafolat yoki aniq afzallik kerak bo'lsa, Pod spec'da qoida yoziladi:

- **nodeSelector va node affinity**: node label'iga qarab (qaysi node'larga tushishi mumkin).
- **Pod affinity va anti-affinity**: o'sha joyda allaqachon ishlab turgan boshqa Pod'larga qarab.

### Mexanizm: ikki bosqichli scheduling

Scheduler har Pod uchun ikki bosqichdan o'tadi: **filter** (qaysi node'lar umuman mos keladi, mos kelmagani chiqarib tashlanadi) va **score** (qolganlariga ball beriladi, eng yuqori ball olgan tanlanadi). `required` qoidalar filter bosqichida ishlaydi: mos node bo'lmasa Pod `Pending`. `preferred` qoidalar score bosqichida: mos node bo'lmasa ham Pod boshqasiga tushadi.

`nodeSelector` eng sodda: Pod faqat shu label'li node'ga tushadi. Node affinity shuning ifodali varianti:

| Tur | Scheduling paytida | Ma'nosi |
|-----|--------------------|---------|
| `requiredDuringSchedulingIgnoredDuringExecution` | qat'iy shart (filter) | mos node bo'lmasa Pod `Pending` |
| `preferredDuringSchedulingIgnoredDuringExecution` | `weight` (1–100) bilan afzallik (score) | mos node bo'lmasa boshqasiga tushadi |

`IgnoredDuringExecution`: Pod joylashgandan keyin node label'i o'zgarsa Pod ko'chirilmaydi. Qoidalar faqat joylashtirish paytida tekshiriladi. Operator'lar: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.

Pod affinity va anti-affinity node label'iga emas, Pod'larga qaraydi. `topologyKey` "joy" nimaligini belgilaydi: `kubernetes.io/hostname` (har node alohida joy) yoki `topology.kubernetes.io/zone` (bir zonadagi hamma node bitta joy).

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels: { app: web }
        topologyKey: kubernetes.io/hostname
```

Bu "`app=web` Pod'i bor node'ga boshqa `app=web` Pod tushmasin" degani. Narxi: replica soni mos node sonidan oshsa ortiqchasi `Pending`. Rolling update'da ham xuddi shu muammo bor (4-darsdagi `maxSurge` ni eslang); qanday ko'rinishini 5-vazifada o'zingiz topasiz. `preferred` varianti hech narsani bloklamaydi, lekin kafolat ham bermaydi.

Pod affinity (anti'siz) teskari maqsad uchun: ilova va uning cache'ini bitta node yoki zonaga yaqin qo'yish (zonalar orasidagi trafik sekinroq va cloud'da pullik).

### Misol: nodeSelector va mos node yo'qligi

Vazifadagidan boshqa label bilan:

```
$ kubectl label node ha-worker3 pool=batch
node/ha-worker3 labeled
$ kubectl get nodes -L pool
NAME               STATUS   ROLES           AGE   VERSION     POOL
ha-control-plane   Ready    control-plane   30m   <version>
ha-worker          Ready    <none>          30m   <version>
ha-worker2         Ready    <none>          30m   <version>
ha-worker3         Ready    <none>          30m   <version>   batch
```

`-L pool` label qiymatini alohida ustun qilib chiqaradi (sarlavha label kalitining katta harflardagi oxirgi qismi). Endi `nodeSelector: { pool: gpu }` (hech qaysi node'da yo'q label) bilan Pod yaratilsa:

```
$ kubectl get pod selector-demo
NAME            READY   STATUS    RESTARTS   AGE
selector-demo   0/1     Pending   0          20s
$ kubectl describe pod selector-demo | tail -3
Events:
  Type     Reason            Age   From               Message
  Warning  FailedScheduling  20s   default-scheduler  0/4 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 3 node(s) didn't match Pod's node affinity/selector. preemption: <...>
```

- `0/4 nodes are available` filter bosqichidan birorta ham node o'tmadi.
- `1 node(s) had untolerated taint` control-plane node'ini taint chiqarib tashladi (4-dars; taint va toleration 12-darsda chuqur).
- `3 node(s) didn't match Pod's node affinity/selector` uchta worker label bo'yicha mos kelmadi.
- `preemption: ...` scheduler boshqa Pod'larni chiqarib joy ocha oladimi deb ham tekshirgan (7-bo'lim), bu yerda foydasiz.

Scheduler xabari doim shu shaklda: "nechta node, qaysi sabab bilan" ro'yxati. `Pending` Pod'ni debug qilishda birinchi qaraladigan joy.

### Real ishda qachon kerak

- Node affinity: GPU'li, SSD'li, `arm64` yoki maxsus node pool'ga yo'naltirish; spot node'lardan uzoqlashtirish (`preferred` bilan).
- `required` pod anti-affinity: har node'da bittadan bo'lishi qat'iy kerak bo'lgan kam sonli replica (masalan, 3 a'zoli klasterli baza, 12-dars).
- `preferred` pod anti-affinity: oddiy stateless servis, replica soni node sonidan ko'p bo'lishi mumkin.
- Pod affinity: tez-tez gaplashadigan ikki komponentni bir zonada saqlash.

### Nima uchun shunday

Uzun nomlar (`requiredDuringSchedulingIgnoredDuringExecution`) ataylab: nom qoida qachon ishlashini aytadi. Kelajak uchun `RequiredDuringExecution` varianti ham rejalashtirilgan edi (label o'zgarsa Pod ko'chirilsin), shuning uchun "Ignored" aniq yozilgan. Qoidani faqat scheduling paytida tekshirish arzon va oldindan aytib bo'ladigan: ishlab turgan Pod'larni avtomatik ko'chirish kutilmagan uzilishlarga olib kelardi. Anti-affinity har Pod uchun boshqa Pod'larni sanashni talab qiladi, shuning uchun katta klasterda u scheduler uchun qimmat; topology spread (4-bo'lim) ko'p holatda arzonroq muqobil.

## 4. Topology spread constraints

### Bu nima

Anti-affinity "bir joyda bittadan ko'p bo'lmasin" deydi. Topology spread constraint esa "domenlar orasidagi farq `maxSkew` dan oshmasin" deydi. 3 zonada 6 yoki 9 replica uchun to'g'ri model shu: har zonada teng, lekin bittadan ko'p.

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels: { app: web }
```

| Maydon | Ma'nosi |
|--------|---------|
| `maxSkew` | eng to'la va eng bo'sh domen orasidagi ruxsat etilgan farq |
| `topologyKey` | domenni belgilaydigan node label'i |
| `whenUnsatisfiable` | `DoNotSchedule` (qat'iy, `Pending`) yoki `ScheduleAnyway` (yumshoq, faqat score'ga ta'sir qiladi) |
| `labelSelector` | qaysi Pod'lar sanaladi |
| `matchLabelKeys` | masalan `pod-template-hash`: rollout paytida faqat shu revision'ning Pod'lari sanaladi |
| `minDomains` | kamida nechta domen bo'lishi kutiladi (faqat `DoNotSchedule` bilan) |

### Mexanizm

Yangi Pod uchun scheduler har domendagi mos Pod'larni sanaydi (`labelSelector` bo'yicha), keyin "Pod shu domenga tushsa, eng katta va eng kichik son orasidagi farq qancha bo'ladi" deb hisoblaydi. Farq `maxSkew` dan oshadigan domenlar `DoNotSchedule` da filter'dan chiqariladi, `ScheduleAnyway` da past ball oladi. Domenlar ro'yxati `topologyKey` label'i bor node'lardan olinadi: label'i yo'q node hech qaysi domenga kirmaydi va `DoNotSchedule` da unga Pod tushmaydi.

Hisob faqat yangi Pod joylashtirilayotganda bajariladi. Bu ikki muhim oqibat beradi:

**Tuzoq: spread faqat scheduling paytida ishlaydi.** Node qaytgandan yoki scale-down'dan keyin mavjud Pod'lar qayta taqsimlanmaydi: ReplicaSet controller qaysi Pod'ni o'chirishni spread'ga qarab tanlamaydi. Muvozanatni tiklash uchun alohida descheduler loyihasi yoki `kubectl rollout restart` kerak.

**Tuzoq: `labelSelector` rollout'da.** `matchLabelKeys` siz eski va yangi ReplicaSet Pod'lari birga sanaladi, rollout oxirida yangi Pod'lar taqsimoti noto'g'ri chiqishi mumkin.

Bir nechta constraint birga ishlatiladi va hammasi bajarilishi kerak: masalan zona bo'yicha qat'iy, node bo'yicha yumshoq.

### Misol

Vazifadagidan boshqa son bilan: zona bo'yicha `maxSkew: 1` li 4 replica'li `spread-demo`. Pod va node'ni yonma-yon ko'rish uchun `custom-columns` (o'zingiz tanlagan maydonlardan jadval):

```
$ kubectl get pods -l app=spread-demo -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
POD                           NODE
spread-demo-<hash>-<a1>       ha-worker
spread-demo-<hash>-<b2>       ha-worker2
spread-demo-<hash>-<c3>       ha-worker3
spread-demo-<hash>-<d4>       ha-worker2
```

- Har node bizda alohida zona, shuning uchun bu taqsimot zona bo'yicha 1/2/1.
- Eng to'la domen (2) va eng bo'sh (1) farqi 1, ya'ni `maxSkew` ga teng: ruxsat etilgan.
- To'rtinchi Pod uchun uch zona ham teng nomzod edi (har birida 1 tadan), scheduler ulardan birini score bo'yicha tanladi.

Zonalar soni o'zgarsa yoki node cordon qilinsa nima bo'lishini 7-vazifada o'zingiz ko'rasiz. Ishora: cordon qilingan node domen sifatida yo'qolmaydi, unda Pod'lar hali ham sanaladi.

### Real ishda qachon kerak

Cloud'da ko'p zonali klasterdagi har stateless servis: zona bo'yicha `maxSkew: 1` va node bo'yicha yumshoq constraint deyarli standart naqsh. Klaster darajasida ham standart spread qoidalarini scheduler konfiguratsiyasida berish mumkin (managed klasterlarda ko'pincha allaqachon bor), lekin servisning o'z manifestida aniq yozilgani ishonchliroq.

### Nima uchun shunday

Anti-affinity faqat "0 yoki 1" ni ifodalay oladi, ko'p replica'li servis uchun bu yetarli emas. Spread constraint bitta son (`maxSkew`) bilan "teng taqsimot" ni ifodalaydi va istalgan replica soniga ishlaydi. Pod'larni avtomatik qayta taqsimlamaslik ataylab: har qayta taqsimlash bu Pod o'ldirish, ya'ni uzilish. Buni xohlaganlar alohida, sozlanadigan descheduler'ni o'rnatadi.

## 5. PodDisruptionBudget va drain

### Bu nima

PodDisruptionBudget (PDB) bu "shu Pod'lar to'plamidan rejali ravishda bir vaqtda nechtasi yo'q bo'lishi mumkin" degan shartnoma. Uni ilova egasi yozadi, klaster operatori (node'larni yangilaydigan odam yoki avtomatika) unga rioya qiladi.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: api }
spec:
  maxUnavailable: 1
  selector:
    matchLabels: { app: api }
```

- `minAvailable` yoki `maxUnavailable` (faqat bittasi), son yoki foiz. `maxUnavailable` replica soni o'zgarganda o'zi moslashadi, shuning uchun odatda afzal.
- `selector` Deployment'ning Pod label'lari bilan mos bo'lishi kerak.

### Mexanizm: Eviction API

PDB **Eviction API** orqali ishlaydi. Eviction bu Pod'ni to'g'ridan-to'g'ri o'chirish emas, "ruxsat bo'lsa o'chir" degan so'rov (Pod'ning `eviction` subresource'iga POST). API server so'ralgan Pod'ga mos PDB'ni topadi va budget'ni tekshiradi:

1. Budget yetarli bo'lsa, PDB'ning `status.disruptionsAllowed` kamaytiriladi va Pod odatdagi tartibda o'chiriladi (graceful shutdown bilan, 8-bo'lim).
2. Budget tugagan bo'lsa, API server `429 Too Many Requests` qaytaradi. Chaqiruvchi (masalan `kubectl drain`) kutib qayta urinadi.

Budget'ni disruption controller hisoblaydi: Ready (4-dars) Pod'lar soni va kerakli son asosida. Shuning uchun Ready bo'lmagan Pod'lar budget'ni "yeydi".

PDB himoya **qilmaydi**: node nosozligi (involuntary), `kubectl delete pod` (bu eviction emas, to'g'ridan-to'g'ri o'chirish), Deployment rollout (uni `maxUnavailable`/`maxSurge` boshqaradi), preemption (faqat best-effort hisobga olinadi, 7-bo'lim).

### Drain

```bash
kubectl cordon <node>        # mark unschedulable, existing pods stay
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>      # allow scheduling again
```

`cordon` faqat yangi Pod'larni to'xtatadi (node'ga `unschedulable` belgisi). `drain` cordon qiladi va har Pod uchun eviction so'raydi. DaemonSet (4-dars) Pod'lari evict qilinmaydi (controller baribir o'sha node'da qayta yaratadi), shuning uchun `--ignore-daemonsets`. `emptyDir` ma'lumoti Pod bilan yo'qoladi, shuning uchun aniq rozilik flag'i talab qilinadi. Controller'siz yalang'och Pod bo'lsa drain rad etadi (`--force` bilan o'chiriladi va qayta yaratilmaydi). Drain uncordon qilmaydi: ish tugagach buni o'zingiz qilasiz.

### Misol

`api` Deployment'i (4 replica) va yuqoridagi PDB:

```
$ kubectl get pdb
NAME   MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
api    N/A             1                 1                     40s
```

- `MIN AVAILABLE N/A` biz `minAvailable` emas, `maxUnavailable` berdik.
- `ALLOWED DISRUPTIONS 1` hozir bitta Pod'ni evict qilish mumkin. Bitta Pod Ready bo'lmasa bu 0 ga tushadi.

Ikki `api` Pod'i bor node drain qilinganda chiqishning muhim qismi:

```
$ kubectl drain ha-worker --ignore-daemonsets --delete-emptydir-data
node/ha-worker cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/kindnet-<x>, kube-system/kube-proxy-<y>
evicting pod default/api-<hash>-<a1>
evicting pod default/api-<hash>-<b2>
error when evicting pods/"api-<hash>-<b2>" -n "default" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.
pod/api-<hash>-<a1> evicted
evicting pod default/api-<hash>-<b2>
pod/api-<hash>-<b2> evicted
node/ha-worker drained
```

- `cordoned` drain avval node'ni yangi Pod'larga yopdi.
- `ignoring DaemonSet-managed Pods` kindnet (CNI, 2-dars) va kube-proxy o'z joyida qoldi.
- Ikkala eviction so'rovi parallel ketdi. Birinchisi budget'ni oldi, ikkinchisi 429 oldi: `Cannot evict pod as it would violate the pod's disruption budget`.
- Birinchi Pod'ning o'rnini bosuvchi boshqa node'da Ready bo'lgach, budget qaytdi va ikkinchi urinish o'tdi.
- `drained` node bo'shadi, endi uni upgrade qilish yoki o'chirish mumkin.

**Tuzoq: drain'ni bloklaydigan PDB.** `maxUnavailable: 0`, yoki `minAvailable` replica soniga teng: budget doim 0, drain abadiy kutadi, node upgrade osilib qoladi. Xuddi shunday, Pod'lar o'zi Ready bo'lmasa budget nolga tushadi va buzuq ilova node'ni ushlab turadi. Buning uchun `unhealthyPodEvictionPolicy: AlwaysAllow` bor: Ready bo'lmagan Pod'ni budget'dan qat'i nazar evict qilishga ruxsat beradi (standart `IfHealthyBudget`).

### Real ishda qachon kerak

Har production Deployment'ga PDB. Managed klasterlarda node upgrade'lari va cluster autoscaler (14-dars) drain'ni avtomatik qiladi va PDB'ga rioya qiladi: PDB'siz upgrade bir servisning hamma Pod'larini birdaniga olib ketishi mumkin, noto'g'ri PDB esa upgrade'ni to'xtatib qo'yadi (provayder ma'lum vaqtdan keyin majburan davom ettirishi ham mumkin).

### Nima uchun shunday

Klaster operatori va ilova egasi ko'pincha turli odamlar. Operator har servisning ichini bilmaydi, ilova egasi esa node upgrade jadvalini bilmaydi. PDB ularni ajratadi: ilova egasi chegarani deklarativ yozadi, har qanday avtomatika (drain, autoscaler, upgrade) shu chegarani bitta API orqali hurmat qiladi. `kubectl delete` ning PDB'ni chetlab o'tishi ham ataylab: administrator Pod'ni majburan o'chira olishi kerak, eviction esa "muloyim" yo'l.

## 6. Node o'chganda nima bo'ladi

### Bu nima

Node to'satdan o'chsa (elektr, kernel panic, tarmoq), uni hech kim "rejalashtirilgan" deb belgilamaydi. Kubernetes buni heartbeat to'xtaganidan biladi va bir necha bosqichda reaksiya qiladi. Har bosqichning vaqt chegarasi bor va ular yig'ilib bir necha daqiqa bo'ladi.

### Mexanizm

1. Kubelet heartbeat'i (`kube-node-lease` namespace'idagi node `Lease`) yangilanishdan to'xtaydi. Node controller (controller-manager ichida) `node-monitor-grace-period` (versiyaga qarab 40–50 soniya) o'tgach node'ni `NotReady` (aniqrog'i `Ready` sharti `Unknown`) qiladi.
2. Node'ga `node.kubernetes.io/unreachable:NoExecute` (kubelet "tayyor emasman" desa `not-ready`) taint qo'yiladi. Shu node'dagi Pod'larning `Ready` sharti `False` qilinadi, EndpointSlice'larda ular tayyor emas deb belgilanadi va Service ularga trafik yubormaydi.
3. Har Pod'da standart toleration bor (DefaultTolerationSeconds admission plugin qo'shadi): shu ikki taint'ga `tolerationSeconds: 300`. 5 daqiqadan keyin Pod'lar o'chirishga belgilanadi va Deployment boshqa node'da yangisini yaratadi.
4. Eski Pod `Terminating` holatida qoladi: uni tasdiqlaydigan kubelet yo'q. Node qaytganda kubelet uni tozalaydi.

Demak standart holatda node o'limidan to'liq quvvat tiklanguncha taxminan 6 daqiqa. Shu vaqt ichida servis qolgan replica'larda ishlaydi, shuning uchun yoyish (3–4 bo'limlar) muhim. 1–2 qadamlar orasida (40–50 soniya) o'lgan Pod'lar hali endpoint'da: bu oyna ichidagi so'rovlar xato oladi yoki timeout bo'ladi.

`tolerationSeconds` ni Pod spec'da kamaytirish mumkin (taint va toleration 12-darsda chuqur), lekin juda kichik qiymat qisqa tarmoq uzilishida keraksiz ko'chishlarga olib keladi.

StatefulSet Pod'lari (4-dars, 12-dars) boshqacha: node javob bermasa Pod `Terminating` da qoladi va yangisi yaratilmaydi, chunki controller eski nusxa haqiqatan to'xtaganiga ishonch hosil qila olmaydi (bir xil identifikatsiyali ikki Pod ma'lumotni buzadi).

### Misol

Standart toleration'larni ko'rish (har oddiy Pod'da bor, siz yozmagan bo'lsangiz ham):

```
$ kubectl describe pod demo-<hash>-<a1> | grep -A2 Tolerations
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
```

- `op=Exists` taint qiymatidan qat'i nazar, kalit bo'lsa yetarli.
- `NoExecute` taint effekti: nafaqat yangi Pod'lar tushmaydi, mavjudlari ham chiqariladi.
- `for 300s` chiqarishdan oldin kutish vaqti, shu 5 daqiqa.

Node holatining vaqt bo'yicha o'zgarishi, `docker stop ha-worker3` dan keyin boshqa terminalda (vaqtlar taxminiy):

```
$ kubectl get nodes -w
NAME               STATUS     ROLES           AGE   VERSION
ha-worker3         Ready      <none>          50m   <version>
ha-worker3         NotReady   <none>          51m   <version>
$ kubectl describe node ha-worker3 | grep Taints -A1
Taints:             node.kubernetes.io/unreachable:NoExecute
                    node.kubernetes.io/unreachable:NoSchedule
```

- `-w` faqat o'zgarishlarni qo'shimcha qator qilib chiqaradi; `NotReady` qatori `docker stop` dan taxminan 40–50 soniya keyin keladi.
- Ikki taint: `NoSchedule` yangi Pod'larni to'xtatadi, `NoExecute` 300 soniyalik hisobni boshlaydi.

Aniq vaqt chizig'ini (endpoint qachon chiqdi, yangi Pod qachon paydo bo'ldi) 13-vazifada o'zingiz o'lchaysiz.

### Real ishda qachon kerak

Incident paytida "node o'ldi, nega Pod'lar 5 daqiqa ko'chmadi" degan savol tez-tez chiqadi: javob shu zanjir. Replica sonini rejalashtirishda ham: 6 daqiqa davomida bir node'ning Pod'larisiz yashay olishingiz kerak. Cloud'da node to'liq o'lganini provayder integratsiyasi (cloud controller manager) tezroq aniqlab Node obyektini o'chirishi mumkin, shunda Pod'lar ham tezroq ko'chadi.

### Nima uchun shunday

Heartbeat'ning yo'qligi "node o'ldi" degani emas, "node bilan aloqa yo'q" degani: node tirik bo'lishi va Pod'lari ishlashi mumkin, faqat tarmoq bo'lingan. Agar Kubernetes darhol yangi Pod yaratsa, aloqa tiklanganda bir xil ishning ikki nusxasi chiqadi va qisqa tarmoq "sakrashlari" butun klasterda Pod ko'chishlar to'lqinini keltiradi. 300 soniya tez reaksiya va barqarorlik o'rtasidagi murosaviy standart, uni har servis o'zi o'zgartira oladi.

## 7. PriorityClass va preemption

### Bu nima

Resurs yetmaganda scheduler kimni qurbon qilishni bilishi kerak. PriorityClass bu nom va sonli ustuvorlik juftligi, klaster darajasidagi (namespace'siz) obyekt:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: customer-facing }
value: 100000
globalDefault: false
description: "Customer-facing services"
```

- Pod spec'da `priorityClassName: customer-facing` bilan bog'lanadi; admission bosqichida son `spec.priority` ga yoziladi. Katta `value` yuqoriroq.
- `globalDefault: true` bo'lsa `priorityClassName` siz Pod'lar shu qiymatni oladi (faqat bitta class shunday bo'lishi mumkin). Hech qaysi bo'lmasa standart priority 0.
- `preemptionPolicy: Never`: navbatda oldinda turadi, lekin hech kimni siqib chiqarmaydi (batch ishlar uchun).
- O'rnatilgan class'lar: `system-cluster-critical`, `system-node-critical` (CoreDNS, kube-proxy kabi tizim Pod'lari uchun).

### Mexanizm: preemption

1. Scheduler navbatida Pod'lar priority bo'yicha tartiblanadi: yuqorisi birinchi.
2. Yuqori priority'li Pod hech qaysi node'ga sig'masa, scheduler har node uchun "qaysi past priority'li Pod'larni chiqarsam bu Pod sig'adi" deb hisoblaydi, PDB'ni buzmaydigan variantni afzal ko'radi (lekin kafolatlamaydi).
3. Tanlangan node Pod'ning `status.nominatedNodeName` ga yoziladi (`kubectl get pod -o wide` dagi `NOMINATED NODE`), qurbonlar graceful shutdown bilan o'chiriladi (event reason `Preempted`).
4. Joy bo'shagach Pod o'sha node'ga joylanadi. Qurbon Pod'lar Deployment'ga tegishli bo'lsa, ularning o'rinbosarlari endi `Pending` da kutadi.

Priority node bosimi ostidagi eviction tartibiga ham ta'sir qiladi (kubelet xotira tugaganda Pod chiqarishi, QoS bilan birga, 4-dars). Bu boshqa mexanizm: preemption scheduler qarori (yangi Pod uchun joy), node-pressure eviction esa kubelet qarori (node'ni o'zini qutqarish).

### Misol

```
$ kubectl get priorityclass
NAME                      VALUE        GLOBAL-DEFAULT   AGE
customer-facing           100000       false            10s
system-cluster-critical   2000000000   false            60m
system-node-critical      2000001000   false            60m
```

- `VALUE` ustuvorlik soni. Tizim class'lari milliardlarda: oddiy foydalanuvchi class'lari 1 milliarddan oshmasligi kerak, shuning uchun hech qachon ulardan yuqori bo'lolmaydi.
- `GLOBAL-DEFAULT` qaysi class standart ekanini ko'rsatadi; bu yerda hech qaysi.
- `kubectl` versiyasiga qarab `PREEMPTIONPOLICY` ustuni ham chiqishi mumkin.

Pod qaysi priority olganini tekshirish:

```
$ kubectl get pod <pod> -o jsonpath='{.spec.priorityClassName} {.spec.priority}{"\n"}'
customer-facing 100000
```

### Real ishda qachon kerak

Klaster to'la bo'lganda (ayniqsa autoscaling yangi node qo'shguncha, 14-dars) mijozga ko'rinadigan servis batch hisobotdan oldin joy olishi kerak. Monitoring va log agent'lari kabi DaemonSet'lar yuqori priority oladi, aks holda ular yangi node'da joy topolmay qoladi.

**Tuzoq: hamma narsaga yuqori priority.** Hamma muhim bo'lsa hech kim muhim emas. 3–4 class yetarli: tizim, production servis, default, batch. Yangi yuqori priority'li Deployment esa boshqa servislarning Pod'larini jimgina chiqarib yuborishi mumkin, shuning uchun class'larni yaratish huquqi cheklangan bo'lsin (RBAC, 13-dars).

### Nima uchun shunday

Muqobil, klasterni har doim bo'sh joy bilan ushlab turish, qimmat. Priority va preemption "to'la klaster" ni xavfsiz qiladi: past ustuvor ish bo'sh joyni to'ldiradi, muhim ish kelganda joyni bo'shatadi. `preemptionPolicy: Never` keyinroq qo'shilgan: ba'zi ishlar navbatda oldinda bo'lishi kerak, lekin boshqalarni o'ldirishi kerak emas.

## 8. Graceful shutdown va zero-downtime rollout

### Bu nima

4-darsda Pod to'xtash ketma-ketligini va `preStop` ni ko'rdingiz. Bu bo'limda u HA nuqtai nazaridan: rollout, drain, scale-down, preemption, hammasi Pod o'chirish bilan tugaydi. Pod so'rov yo'qotmasdan to'xtamasa, yuqoridagi hamma himoya har deploy'da bir nechta 502 bilan tugaydi. Zero-downtime rollout bu yangilash paytida birorta ham so'rov xato olmasligi.

### Mexanizm: poyga

Pod o'chirilganda ikki jarayon **parallel** boshlanadi:

```
delete Pod
 |- kubelet: preStop hook -> SIGTERM -> (wait up to terminationGracePeriodSeconds) -> SIGKILL
 |- endpoints controller: remove Pod from EndpointSlice -> kube-proxy/ingress update rules
```

Ikkinchi shox bir necha soniya olishi mumkin (ayniqsa ingress controller yoki tashqi load balancer). Agar ilova `SIGTERM` olgan zahoti port'ni yopsa, hali yangilanmagan proxy'lar unga so'rov yuboradi va mijoz `connection refused` yoki 502 oladi.

Yechim uch qismdan:

1. **preStop kechikishi.** `SIGTERM` dan oldin bir necha soniya kutish, shu vaqtda endpoint olib tashlanadi:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sleep", "10"]
terminationGracePeriodSeconds: 45
```

Yangi Kubernetes versiyalarida `exec` o'rniga o'rnatilgan `preStop.sleep.seconds` ham bor (image'da `sleep` binary'si bo'lmasa qulay, masalan distroless image).

2. **Ilova `SIGTERM` ni to'g'ri qabul qiladi**: yangi ulanish qabul qilmaydi, jarayondagi so'rovlarni tugatadi, keyin chiqadi (Node'da `process.on('SIGTERM', ...)` ichida `server.close()`). PID 1 muammosi: shell wrapper (`sh -c "node app.js"`) signal'ni uzatmaydi, Dockerfile'da exec shaklidagi `CMD ["node", "app.js"]` kerak (Docker 2-dars, 4-dars).

3. **`terminationGracePeriodSeconds`** (standart 30) preStop vaqtini ham o'z ichiga oladi. Muddat tugasa `SIGKILL`. Qiymat `preStop + eng uzun so'rov + zaxira` dan katta bo'lsin.

### Mexanizm: rollout paytida readiness

Yangi Pod readiness probe o'tgandan keyingina endpoint'ga qo'shiladi (4-dars), eski Pod esa yuqoridagi tartibda chiqadi. Zero-downtime uchun to'rttasi birga kerak: to'g'ri readiness probe, `maxUnavailable: 0` (yoki yetarli zaxira), preStop kechikishi, `SIGTERM` ni to'g'ri qayta ishlash. `minReadySeconds` yangi Pod'ni "available" deb hisoblashdan oldin qo'shimcha kutadi va darhol yiqiladigan versiyani rollout boshida to'xtatadi.

### Misol: uzilishni o'lchash

Bu darsning asosiy o'lchov asbobi: klaster ichida Service'ga sikl bilan so'rov yuboradigan Pod. Bu yerda `demo` Service'iga (avval `kubectl expose deployment demo --port=80` bilan yaratilgan):

```bash
kubectl run probe --image=busybox:1.36 --restart=Never -- sh -c '
while true; do
  if wget -q -T 1 -O /dev/null http://demo; then echo "$(date +%T) ok"; else echo "$(date +%T) FAIL"; fi
  sleep 0.2
done'
kubectl logs -f probe
```

`-T 1` har so'rovga 1 soniyalik timeout, `-O /dev/null` javob tanasini tashlaydi, `-q` ortiqcha chiqishni o'chiradi. `wget` muvaffaqiyatsiz bo'lsa 0 dan farqli kod qaytaradi va `FAIL` yoziladi. Rollout paytidagi log parchasi (preStop'siz servisda):

```
12:04:10 ok
12:04:10 ok
12:04:11 FAIL
12:04:12 ok
12:04:12 FAIL
12:04:13 ok
```

- Har qator bitta so'rov, soniyada taxminan 4–5 ta.
- `FAIL` qatorlari eski Pod'lar jarayoni to'xtagan, lekin hali endpoint'da turgan lahzalar.
- Natijani sanash: `kubectl logs probe | grep -c FAIL`.

Bu asbobni o'zingizga moslang: so'rov tezligini oshiring (17-vazifa sekundiga 20 so'rov so'raydi), xato turini ham yozing. Ish tugagach `kubectl delete pod probe`.

### Real ishda qachon kerak

Har kuni bir necha marta deploy qiladigan jamoada preStop'siz har deploy kichik incident. Past trafikda sezilmaydi, yuqori trafikda va uzun ulanishlarda (WebSocket, gRPC stream) sezilarli. Frontend tomondan tanish holat: deploy paytida foydalanuvchida bir lahza "network error" chiqib, refresh'dan keyin yo'qolishi.

### Nima uchun shunday

Kubernetes taqsimlangan tizim: "Pod endi yo'q" degan xabar yuzlab node va proxy'ga bir lahzada yetib bormaydi, global sinxron to'xtash esa juda qimmat bo'lardi. Shuning uchun dizayn "eventually consistent" (oxir-oqibat izchil): endpoint olib tashlash va jarayonni to'xtatish parallel, oraliqdagi bo'shliqni ilova va `preStop` yopadi. `SIGTERM` keyin `SIGKILL` sxemasi Unix an'anasi (`docker stop` ham shunday).

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| High availability (HA) | tizimning bir qismi ishdan chiqqanda ham xizmat ko'rsatishda davom etishi |
| Disruption | Pod'ning o'z xohishisiz ishlashdan to'xtashi |
| Voluntary / involuntary disruption | rejali (drain, upgrade) / kutilmagan (node o'limi) uzilish |
| Failure domain | bitta sababdan birga ishdan chiqadigan narsalar: node, zona, region |
| Availability zone | alohida elektr va tarmoqli ma'lumotlar markazi; node label'i `topology.kubernetes.io/zone` |
| Redundancy | bir domen yo'qolganda ishni ko'taradigan zaxira |
| Raft | etcd ishlatadigan konsensus algoritmi, leader va follower'lar bilan |
| Quorum | yozuv qabul qilinishi uchun kerak bo'lgan ko'pchilik, `floor(N/2)+1` |
| Split-brain | tarmoq bo'linganda ikki guruhning alohida "haqiqat" yozishi |
| Leader election | bir nechta nusxadan faqat bittasi faol bo'lishi uchun tanlov |
| Lease | leader yoki node heartbeat'i uchun qisqa muddatli yozuv |
| Stacked / external etcd | etcd control plane node'larida / alohida node'larda |
| Filter / score | scheduler'ning mos node'larni tanlash va baholash bosqichlari |
| nodeSelector | Pod'ni aniq label'li node'larga cheklash |
| Node affinity | node label'iga qarab `required` yoki `preferred` qoida |
| Pod affinity / anti-affinity | boshqa Pod'larga yaqin yoki ulardan uzoq joylashish qoidasi |
| `topologyKey` | "joy" ni belgilaydigan node label'i |
| Topology spread constraint | domenlar orasidagi Pod soni farqini `maxSkew` bilan cheklash |
| `maxSkew` | eng to'la va eng bo'sh domen orasidagi ruxsat etilgan farq |
| Descheduler | qoidalarni buzayotgan Pod'larni chiqarib, qayta joylashtiradigan qo'shimcha loyiha |
| PodDisruptionBudget (PDB) | rejali ravishda bir vaqtda nechta Pod yo'q bo'lishi mumkinligi |
| Eviction API | PDB'ni tekshirib Pod'ni chiqaradigan "muloyim" o'chirish |
| Cordon / uncordon | node'ni yangi Pod'larga yopish / ochish |
| Drain | cordon va node'dagi Pod'larni evict qilish |
| `unhealthyPodEvictionPolicy` | Ready bo'lmagan Pod'larni budget'dan qat'i nazar evict qilish siyosati |
| Heartbeat | kubelet'ning muntazam "tirikman" xabari |
| `NoExecute` taint | mavjud Pod'larni ham chiqaradigan taint effekti |
| `tolerationSeconds` | `NoExecute` taint qo'yilgandan keyin Pod chiqarilguncha kutish |
| PriorityClass | nom va sonli ustuvorlik juftligi |
| Preemption | yuqori ustuvor Pod uchun past ustuvorlarni chiqarish |
| Node-pressure eviction | kubelet resurs tugaganda Pod'larni chiqarishi |
| Graceful shutdown | jarayondagi ishni tugatib, keyin chiqish |
| `preStop` | konteyner to'xtashidan oldin bajariladigan hook |
| `terminationGracePeriodSeconds` | o'chirish boshidan `SIGKILL` gacha bo'lgan umumiy muddat |
| Zero-downtime rollout | birorta so'rov xato olmaydigan yangilash |
| `minReadySeconds` | yangi Pod "available" hisoblanishidan oldingi qo'shimcha kutish |

## Tuzoqlar

- Uchta replica, hammasi bitta node'da. `kubectl get pods -o wide` bilan tekshirilmagan HA mavjud emas.
- `required` anti-affinity va replica soni node sonidan ko'p: Pod'lar `Pending`, rollout to'xtaydi.
- `replicas: 1` ga `minAvailable: 1` PDB: node drain va klaster upgrade bloklanadi.
- PDB node nosozligidan himoya qiladi deb o'ylash.
- PDB `selector` i Pod label'lariga mos emas: PDB bor, lekin hech narsani himoya qilmaydi (`ALLOWED DISRUPTIONS` ga va `kubectl describe pdb` ga qarang).
- Topology spread scale-down va node qaytgandan keyin muvozanatni tiklaydi deb kutish.
- Zona label'isiz klasterda zona bo'yicha spread yozish: `DoNotSchedule` bilan hamma Pod `Pending`.
- Drain'dan keyin `uncordon` ni unutish: node bo'sh turadi, klaster sig'imi jimgina kamayadi.
- preStop'siz rollout: har deploy'da bir necha 502. Past trafikda sezilmaydi, yuqorida sezilarli.
- `terminationGracePeriodSeconds` preStop'dan kichik: Pod `SIGTERM` olmasdan `SIGKILL` bilan o'ladi.
- Shell wrapper ortidagi jarayon `SIGTERM` olmaydi, har Pod 30 soniya kutib `SIGKILL` bo'ladi, rollout va drain sekinlashadi.
- Ikki a'zoli etcd: bitta a'zodan yomonroq, chunki istalgan biri o'chsa quorum yo'qoladi.
- Kubeconfig HA control plane'ning bitta node'iga qaraydi: o'sha node o'lsa `kubectl` ham o'ladi.
- `tolerationSeconds` ni juda kichik qilish: qisqa tarmoq uzilishida Pod'lar keraksiz ko'chadi.
- Hamma Deployment'ga eng yuqori PriorityClass: preemption tartibsiz bo'ladi.
- Sinovdan keyin `docker stop` qilingan node'ni qaytarmaslik: keyingi vazifa boshqacha klasterda o'tadi.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ – voluntary va involuntary disruption, PDB
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/ – PDB sozlash, `unhealthyPodEvictionPolicy`
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/ – drain
- https://kubernetes.io/docs/concepts/scheduling-eviction/api-eviction/ – Eviction API
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ – nodeSelector, affinity, anti-affinity
- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ – topology spread
- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ – PriorityClass, preemption
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ – taint-based eviction, `tolerationSeconds`
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination – Pod to'xtash tartibi
- https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/ – preStop
- https://kubernetes.io/docs/concepts/architecture/nodes/ – node holati, heartbeat
- https://kubernetes.io/docs/concepts/architecture/leases/ – Lease, leader election
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/ – control plane HA topologiyalari
- https://docs.k3s.io/datastore/ha-embedded – k3s embedded etcd bilan HA
- https://kind.sigs.k8s.io/docs/user/configuration/ – kind konfiguratsiyasi, ko'p node va node label'lari
- https://etcd.io/docs/latest/faq/ – quorum va a'zolar soni
- https://raft.github.io/ – Raft algoritmi, interaktiv vizualizatsiya
- https://github.com/kubernetes-sigs/descheduler – descheduler

---

## Birga bajaramiz

Vazifalardan boshqa misol: kind'da **uch control-plane'li** klaster `cp3` quramiz, etcd a'zolari va leader'larni ko'ramiz, control plane node'larini birma-bir o'chirib, quorum qachon yo'qolishini kuzatamiz. Vazifalar bitta control plane'li `ha` klasterida, bu esa control plane HA'ning o'zi. Taxminan 4–5 GB RAM kerak: avval `ha` klasterini o'chiring yoki uning bilan ishni tugating. Ikkala mashinada bir xil, faqat Mac'da hamma konteyner Docker Desktop VM'i ichida.

1. Konfiguratsiya `kind-cp3.yaml` (ish papkasidan tashqarida, masalan scratch papkada):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: control-plane
  - role: control-plane
  - role: worker
```

```
$ kind create cluster --name cp3 --config kind-cp3.yaml
Creating cluster "cp3" ...
 ✓ Ensuring node image (kindest/node:<version>)
 ✓ Preparing nodes
 ✓ Configuring the external load balancer
 ...
 ✓ Joining more control-plane nodes
 ✓ Joining worker nodes
```

Bitta control plane'li klasterdan farqi ikki qatorda: `Configuring the external load balancer` va `Joining more control-plane nodes`. kind ikki va undan ortiq control-plane bo'lsa API server'lar oldiga alohida load balancer konteyneri qo'yadi.

2. Konteynerlar va kubeconfig:

```
$ docker ps --format '{{.Names}}' | grep cp3
cp3-external-load-balancer
cp3-control-plane
cp3-control-plane2
cp3-control-plane3
cp3-worker
$ kubectl cluster-info --context kind-cp3 | head -1
Kubernetes control plane is running at https://127.0.0.1:<port>
```

`cp3-external-load-balancer` bu 2-bo'limdagi "API server'lar oldidagi LB". Kubeconfig uning host'dagi port'iga qaraydi, alohida control-plane'ga emas. `kind create cluster` joriy context'ni `kind-cp3` ga almashtirdi, buni `kubectl config current-context` bilan tekshiring.

3. etcd a'zolari. kind (kubeadm) etcd'ni har control-plane'da static Pod qilib ishga tushiradi; image ichida `etcdctl` bor, sertifikatlar node'dagi `/etc/kubernetes/pki/etcd/` da:

```
$ kubectl -n kube-system exec etcd-cp3-control-plane2 -- etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    member list -w table
+------------------+---------+--------------------+-------------------------+-------------------------+------------+
|        ID        | STATUS  |        NAME        |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
+------------------+---------+--------------------+-------------------------+-------------------------+------------+
| <id1>            | started | cp3-control-plane  | https://172.18.0.4:2380 | https://172.18.0.4:2379 |      false |
| <id2>            | started | cp3-control-plane2 | https://172.18.0.5:2380 | https://172.18.0.5:2379 |      false |
| <id3>            | started | cp3-control-plane3 | https://172.18.0.3:2380 | https://172.18.0.3:2379 |      false |
+------------------+---------+--------------------+-------------------------+-------------------------+------------+
```

- Uch a'zo, hammasi `started`: quorum 2.
- `PEER ADDRS` port 2380, a'zolar o'zaro Raft xabarlari uchun; `CLIENT ADDRS` port 2379, API server shu yerga ulanadi.
- `IS LEARNER false` hamma ovoz beruvchi a'zo (learner yangi qo'shilayotgan, hali ovoz bermaydigan a'zo).

Xuddi shu flag'lar bilan `endpoint status --cluster -w table` qaysi a'zo leader ekanini `IS LEADER` ustunida ko'rsatadi.

4. Leader'lar:

```
$ kubectl -n kube-system get lease kube-controller-manager kube-scheduler
NAME                      HOLDER                          AGE
kube-controller-manager   cp3-control-plane_<uuid>        6m
kube-scheduler            cp3-control-plane2_<uuid>       6m
```

Leader'lar turli node'larda bo'lishi mumkin: har komponent o'z Lease'i uchun alohida "saylanadi".

5. Controller-manager leader'i turgan node'ni o'chiramiz (sizda boshqa node bo'lishi mumkin, `HOLDER` dan oling) va 30 soniya kutib qayta qaraymiz:

```
$ docker stop cp3-control-plane
cp3-control-plane
$ kubectl -n kube-system get lease kube-controller-manager
NAME                      HOLDER                          AGE
kube-controller-manager   cp3-control-plane3_<uuid>       7m
$ kubectl get nodes
NAME                 STATUS     ROLES           AGE   VERSION
cp3-control-plane    NotReady   control-plane   8m    <version>
cp3-control-plane2   Ready      control-plane   7m    <version>
cp3-control-plane3   Ready      control-plane   7m    <version>
cp3-worker           Ready      <none>          7m    <version>
```

- `kubectl` ishlayapti: LB so'rovni tirik API server'ga yubordi, etcd'da 2 a'zo bor, quorum saqlangan.
- `HOLDER` boshqa node'ga o'tdi: eski leader Lease'ni yangilamadi, muddati tugadi va kutib turgan nusxa uni egalladi.
- `NotReady` qatori 40–50 soniyadan keyin paydo bo'ladi (6-bo'lim); undan oldin `Ready` ko'rinishi normal.

6. Ikkinchi control-plane'ni ham o'chiramiz: endi 3 a'zodan 1 tasi qoldi, quorum (2) yo'q.

```
$ docker stop cp3-control-plane2
cp3-control-plane2
$ kubectl get nodes --request-timeout=10s
Error from server: etcdserver: request timed out
```

Xabar matni versiya va vaqtga qarab boshqacha bo'lishi mumkin (timeout yoki `the server was unable to return a response`), mazmuni bitta: tirik API server bor, lekin etcd ko'pchiliksiz hech narsani tasdiqlay olmaydi. `--request-timeout` `kubectl` ning uzoq kutishini cheklaydi.

7. Tiklash: bitta a'zoni qaytarish quorum'ni tiklaydi.

```
$ docker start cp3-control-plane2
cp3-control-plane2
$ kubectl get nodes
NAME                 STATUS     ROLES           AGE   VERSION
cp3-control-plane    NotReady   control-plane   12m   <version>
cp3-control-plane2   Ready      control-plane   11m   <version>
...
```

Bir necha soniya o'tib (etcd yangi leader saylaguncha) `kubectl` yana javob beradi, `cp3-control-plane` esa hali o'chiq. `docker start cp3-control-plane` bilan uni ham qaytaring va hamma node `Ready` bo'lishini kuting.

8. Tozalash va context'ni qaytarish:

```bash
kind delete cluster --name cp3
kubectl config use-context kind-ha     # or kind-dev, whichever you use next
```

Bu yurishda ko'rganingiz va qaysi bo'limga bog'liqligi:

| Qadam | Bo'lim |
|-------|--------|
| 1–2 | 2-bo'lim: API server'lar oldidagi LB, kubeconfig LB'ga qaraydi |
| 3, 6–7 | 2-bo'lim: Raft, quorum, juft bo'lmagan a'zolar soni |
| 4–5 | 2-bo'lim: leader election va Lease |
| 5 | 6-bo'lim: heartbeat va `NotReady` kechikishi |

Control plane o'chganda ishlab turgan Pod'lar bilan nima bo'lishini bu yerda tekshirmadik: buni 3-vazifada bitta control plane'li `ha` klasterida o'zingiz ko'rasiz.

---

## Vazifalar

Barchasini `kubernetes/11-high-availability/` da bajaring (`make new m=kubernetes n=11 name=high-availability`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. `kind-ha.yaml` va barcha manifestlar shu papkada (`task_N.yaml`). README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozing. Sinov ilovasi sifatida o'z image'ingiz yoki `nginx:1.28` ishlatiladi; uzilishni o'lchash uchun klaster ichida alohida Pod'dan sikl bilan so'rov yuboring (`curl` yoki `wget`, har so'rov natijasini vaqt bilan yozadi; 8-bo'lim, "Misol: uzilishni o'lchash"). Node o'chiriladigan har vazifa oxirida `docker start` va `uncordon` bilan klasterni toza holatga qaytaring.

### A. Cluster va boshlang'ich holat

1. **Multi-node cluster.** `kind-ha.yaml` bilan cluster yarating. `kubectl get nodes -L topology.kubernetes.io/zone` chiqishini yozing. Control-plane node'da qanday taint bor va bu oddiy Pod'lar uchun nimani anglatadi?

2. **Default spreading.** Hech qanday qoidasiz 6 replica'li Deployment yarating va `-o wide` bilan taqsimotni yozing. Keyin 3 ga scale qiling va yana 6 ga. Taqsimot har doim tengmi? Scheduler nimani kafolatlaydi, nimani yo'q?

3. **etcd quorum math.** Kodsiz: 1, 2, 3, 4, 5 a'zoli etcd uchun quorum va chidaydigan nosozlik sonini jadvalga yozing. Nima uchun 2 va 4 yomon tanlov? `ha-control-plane` ni `docker stop` qilsangiz ishlab turgan Pod'lar va `kubectl` bilan nima bo'ladi? Sinab ko'ring va qayta yoqing.

### B. Joylashtirish

4. **Required anti-affinity.** 3 replica'ga `kubernetes.io/hostname` bo'yicha `required` pod anti-affinity qo'ying va har node'da bittadan ekanini ko'rsating. 4 ga scale qiling: to'rtinchi Pod holati va `kubectl describe pod` dagi scheduler xabarini yozing.

5. **Rollout deadlock.** 4-vazifadagi 3 replica bilan image'ni o'zgartiring (default rollout strategiyasi). Rollout nima uchun osilib qoldi? `maxSurge` va `maxUnavailable` ni qanday qo'yish kerak? Tuzating va isbotlang.

6. **Preferred anti-affinity.** `required` ni `preferred` ga almashtirib 5 replica qiling. Taqsimot qanday? Qaysi holatda `preferred`, qaysi holatda `required` to'g'ri tanlov? Ikki misol bilan yozing.

7. **Topology spread.** Anti-affinity'ni olib tashlab, zona bo'yicha `maxSkew: 1`, `DoNotSchedule` constraint yozing. 6 va 7 replica'da taqsimotni ko'rsating. Keyin bitta worker'ni `cordon` qilib 9 ga scale qiling: nima bo'ldi va nima uchun? `ScheduleAnyway` bilan takrorlang.

8. **Node affinity.** Bitta worker'ga `disktype=ssd` label qo'ying. Bir Deployment'ni `required` node affinity bilan faqat shu node'ga, ikkinchisini `preferred` bilan yo'naltiring. Label'ni olib tashlang: ishlab turgan Pod'lar bilan nima bo'ldi, yangi Pod'lar bilan-chi? `IgnoredDuringExecution` ni shu misolda izohlang.

### C. PDB va drain

9. **Drain without PDB.** 4 replica'li Deployment'ni shunday joylangki, ikki Pod bitta node'da bo'lsin. Tashqaridan sikl bilan so'rov yuborib turib o'sha node'ni drain qiling. Bir vaqtda nechta Pod yo'q bo'ldi (`kubectl get pods -w`)? Xato so'rovlar bo'ldimi?

10. **PDB in action.** `maxUnavailable: 1` PDB qo'shing, `ALLOWED DISRUPTIONS` ni yozing va 9-vazifani takrorlang. Drain chiqishida eviction qanday navbat bilan ketganini va kutish xabarini ko'rsating.

11. **PDB that blocks drain.** Bir replica'li Deployment'ga `minAvailable: 1` PDB qo'ying va node'ni drain qiling. Xabarni yozing. Buni to'g'ri hal qilishning ikki yo'lini ayting (`--force` yoki PDB'ni o'chirish yechim emas). Keyin `kubectl delete pod` qiling: PDB to'xtatdimi? Nima uchun?

12. **Unhealthy pods and PDB.** Readiness probe hech qachon o'tmaydigan 3 replica va `maxUnavailable: 1` PDB yarating. `ALLOWED DISRUPTIONS` nechaga teng? Drain nima qiladi? `unhealthyPodEvictionPolicy: AlwaysAllow` qo'shib takrorlang va farqni izohlang.

### D. Node nosozligi

13. **Kill a node.** Zona bo'ylab yoyilgan 3 replica va sikl bilan so'rov. `docker stop ha-worker2` qiling va vaqt bilan yozib boring: node qachon `NotReady` bo'ldi, Pod endpoint'dan qachon chiqdi (`kubectl get endpointslices -w`), Pod qachon o'chirishga belgilandi, yangi Pod qachon va qayerda paydo bo'ldi. Xato so'rovlar oynasi qancha?

14. **Tune tolerationSeconds.** Pod spec'ga `not-ready` va `unreachable` uchun `tolerationSeconds: 30` toleration qo'shib 13-vazifani takrorlang. Tiklanish vaqti qanday o'zgardi? Juda kichik qiymatning xavfi nima?

15. **Node returns.** `docker start ha-worker2` dan keyin Pod'lar taqsimotini yozing. Spread tiklandimi? Muvozanatni qaytarishning ikki usulini ayting va bittasini bajaring.

### E. Priority va graceful shutdown

16. **Preemption.** `low` va `high` PriorityClass yarating. `low` Deployment bilan worker'larning CPU requests'ini deyarli to'ldiring (`kubectl describe node` dagi `Allocated resources` ga qarab). Keyin `high` Deployment qo'ying. Event'lardan preemption'ni toping. `low` Pod'lar holati qanday? `preemptionPolicy: Never` bilan nima o'zgaradi?

17. **Rollout without preStop.** Ilovangizni (yoki SIGTERM'da darhol chiqadigan sodda HTTP serverni) 3 replica bilan deploy qiling. Sekundiga kamida 20 so'rov yuborib turib `kubectl rollout restart` qiling. Xato so'rovlar sonini va turini yozing.

18. **Zero-downtime rollout.** 17-vazifaga `preStop` kechikishi, mos `terminationGracePeriodSeconds`, readiness probe va `maxUnavailable: 0` qo'shing. Sinovni takrorlang: xato soni nolga tushdimi? Har bir sozlamani bittadan olib tashlab, qaysi biri qaysi xatoni yopayotganini ko'rsating.

19. **SIGTERM and PID 1.** Konteyner buyrug'ini shell wrapper orqali ishga tushiring (`sh -c "..."`). `kubectl delete pod` qancha vaqt oladi (`time`)? Exec shaklida takrorlang. Farqni signal uzatilishi orqali izohlang va Pod event'laridan dalil keltiring.

### F. Yig'ma

20. **HA checklist.** Ilovangiz uchun production manifest to'plamini yig'ing: zona va node bo'yicha spread, PDB, PriorityClass, probe'lar, graceful shutdown, to'g'ri rollout strategiyasi. Uch sinovni ketma-ket o'tkazing (drain, node o'chirish, rollout) va har birida xato so'rovlar soni va tiklanish vaqtini jadvalga yozing. Qaysi nosozlikdan hali ham himoyalanmagansiz?

Yo'nalishlar (yechim emas, qayerga qarash kerakligi):

- 1–2: Laboratoriya; 1-bo'lim, "Misol"; 3-bo'lim, "Mexanizm" (filter va score). Taint uchun `kubectl describe node ha-control-plane`.
- 3: 2-bo'lim, quorum formulasi. Sinovdan keyin `docker start ha-control-plane` va hamma node `Ready` bo'lishini kuting.
- 4–6: 3-bo'lim; 5 uchun 4-darsdagi rollout arifmetikasi (`maxSurge`, `maxUnavailable`).
- 7: 4-bo'lim, "Mexanizm" va "Misol"dagi cordon haqidagi ishora.
- 8: 3-bo'lim, `IgnoredDuringExecution`. Label o'chirish: `kubectl label node <node> disktype-`.
- 9–12: 5-bo'lim. 9 uchun Pod'larni kerakli joyga qo'yishning yo'lini 3-bo'limdan tanlang.
- 13–15: 6-bo'lim. Vaqtni yozish uchun `-w` chiqishiga `date` bilan belgi qo'yib boring yoki `--output-watch-events` dan foydalaning. 15 uchun 4-bo'lim, birinchi tuzoq.
- 16: 7-bo'lim; `kubectl get events --sort-by=.lastTimestamp`.
- 17–19: 8-bo'lim va 4-dars (Pod to'xtash ketma-ketligi, 3-vazifa). Mac'da `time` formati boshqacha (Laboratoriya jadvali).
- 20: hamma bo'limlar va "Tuzoqlar".

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. README'da har sinov uchun vaqt o'lchovlari va xato so'rovlar soni bor.
3. `kind delete cluster --name ha` bajarilgan (va `cp3` yaratilgan bo'lsa u ham), `docker ps` da kind konteynerlari yo'q. Multipass'da k3s sinagan bo'lsangiz VM'lar `multipass delete --purge` bilan o'chirilgan, token hech qayerga yozilmagan.
4. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Voluntary va involuntary disruption farqi nima, PDB qaysi biriga ta'sir qiladi?
- `required` anti-affinity qaysi holatda rollout'ni bloklaydi?
- Anti-affinity va topology spread constraint qaysi savolga javob beradi, farqi nimada?
- Node o'chgandan keyin yangi Pod paydo bo'lguncha nima uchun taxminan 5–6 daqiqa o'tadi?
- `kubectl delete pod` PDB'ni nima uchun chetlab o'tadi?
- Pod o'chirilganda SIGTERM va endpoint yangilanishi orasidagi poyga nimadan iborat va preStop uni qanday yechadi?
- `terminationGracePeriodSeconds` nimani o'z ichiga oladi?
- 4 a'zoli etcd nima uchun 3 a'zolidan yaxshi emas?
- Preemption va node bosimi ostidagi eviction farqi nima?
