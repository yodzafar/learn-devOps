# 15-dars: Xarajatni optimallashtirish va yakuniy loyiha

Maqsad: Kubernetes'da xarajat ko'rinmas tarzda o'sadi. Har jamoa "zaxira bilan" requests yozadi, node'lar yarim bo'sh ishlaydi, unutilgan PVC va load balancer'lar oylab to'lanadi, hisob esa bitta qator bo'lib keladi: "compute". Bu darsda xarajat qayerdan kelishi, requests va haqiqiy iste'mol orasidagi farq (right-sizing), namespace darajasidagi chegaralar (ResourceQuota, LimitRange), xarajatni ko'rsatish (OpenCost), spot node'lar, bin-packing, non-prod'ni nolga tushirish, storage va tarmoq xarajati, FinOps asoslari ko'riladi. Dars modul va kursning yakuniy loyihasi bilan tugaydi: oldingi modullardagi ilova GitOps orqali ko'p node'li cluster'ga TLS, autoscaling, NetworkPolicy, observability, backup/restore mashqi va yozma xarajat bahosi bilan joylashtiriladi.

Taxminiy vaqt: 2 kun dars, 5–6 kun yakuniy loyiha (siz uchun). Birinchi kun 1–3 bo'limlar, A va B guruhlar; ikkinchi kun 4–7 bo'limlar, "Birga bajaramiz" va C guruhi. Darsda diqqat: "to'lov requests uchun, iste'mol uchun emas" tamoyili, quota va LimitRange'ning o'zaro bog'liqligi, tejash va ishonchlilik orasidagi savdo. Loyihada yangi mavzu yo'q: 8–14-darslar va oldingi modullar bitta tizimga yig'iladi.

Qanday o'qish kerak: bu darsning yarmi buyruq emas, hisob-kitob. Har bo'limdagi misolni o'z cluster'ingizda ishga tushiring, lekin raqamlarga emas, nisbatlarga qarang: kind'da hech kim pul to'lamaydi, va node'lar host'ning butun resursini "ko'radi" (1-bo'lim). Nazariyadagi misollar `httpd:2.4-alpine` image'i bilan va `demo` namespace'ida, vazifalar boshqa nomlar bilan. Pod nomlari, millicore va megabayt qiymatlari sizda boshqa bo'ladi, ustunlar tarkibi bir xil. Narxlar (dollar) misol uchun berilgan, ularni sana bilan rasmiy kalkulyatordan tekshiring.

## Laboratoriya

- **Dars qismi**: kind cluster `cost` (1 control-plane, 2 worker, 2-darsdagi `kind-multi.yaml`), metrics-server (14-dars). OpenCost uchun Prometheus kerak (observability moduli); o'rnatish rasmiy hujjat bo'yicha: https://opencost.io/docs/installation/install . kind'da cloud narxlari yo'q, OpenCost default yoki siz bergan narxlar bilan hisoblaydi: raqamlar shartli, lekin nisbatlar haqiqiy.
- **Yakuniy loyiha**: ko'p node'li cluster, ikki variantdan biri: kind (1 control-plane, 3 worker) yoki Multipass VM'larda k3s (1 server, 2 agent; 2-dars). Pullik cloud cluster talab qilinmaydi. Xarajat bahosi uchun AWS Pricing Calculator (https://calculator.aws/) ishlatiladi, hech qanday resurs yaratilmaydi.
- Ish mashinasi resursi cheklangan: observability stack, baza va ilova birga 8 GB atrofida xotira so'rashi mumkin. Yetmasa retention va replica'larni kamaytiring, lekin nima kamaytirilganini yozing.

Cluster'ni tayyorlash (ikkala mashinada bir xil):

```bash
kind create cluster --name cost --config kubernetes/02-cluster-setup/kind-multi.yaml
kubectl config current-context        # must print: kind-cost
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.0/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl create namespace demo
```

`--kubelet-insecure-tls` faqat lab uchun (14-dars). metrics-server versiyasi ataylab qotirilgan: `latest` havolasi bugun bir narsa, ertaga boshqa narsa o'rnatadi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Cluster | Docker Engine ustida kind, node'lar `amd64` | Docker Desktop ustida kind, node'lar `arm64` |
| Node `capacity` nimani ko'rsatadi | host'ning butun CPU va RAM'ini, har uchala node'da bir xil | Docker Desktop VM'iga ajratilgan CPU va RAM'ni, har uchala node'da bir xil |
| Resurs | dars qismi uchun 4 GB, OpenCost va Prometheus bilan 6 GB bo'sh RAM | Docker Desktop Settings → Resources'da kamida 8 GB RAM |
| Spot taqlidi (10-vazifa) | `docker stop cost-worker2` host'da | xuddi shu buyruq, konteyner yashirin VM ichida, lekin `docker` CLI uni boshqaradi |
| k3s varianti (loyiha) | Multipass VM'lar, `amd64` | Multipass VM'lar, `arm64` |
| AWS Pricing Calculator | brauzerda, bir xil | brauzerda, bir xil |

Ikkinchi mashinada tiklash: cluster holati ko'chmaydi, manifestlar git orqali keladi. Uyda `kind get clusters` da `cost` bo'lmasa yuqoridagi blokni qayta bajaring, keyin kerakli `task_N.yaml` larni `apply` qiling. Prometheus va OpenCost Helm bilan qayta o'rnatiladi; ularning yig'gan tarixi (metrikalar, allocation) ko'chmaydi, shuning uchun 3 va 9-vazifalarni bitta mashinada boshlab, o'sha mashinada tugating. Yakuniy loyiha bu muammoni o'zi hal qiladi: hamma narsa config repo'da, 15-vazifadagi bootstrap ikkinchi mashinada ham aynan shu tizimni ko'taradi. Baza ma'lumoti esa faqat backup orqali ko'chadi (21-vazifa).

Tozalash: `kind delete cluster --name cost`; loyihadan keyin cluster yoki VM'lar, GitHub token'lari, registry'dagi sinov image'lari.

---

## 1. Xarajat qayerdan keladi

### Bu nima

Cloud provayder Kubernetes obyektlari uchun emas, ularning ostidagi infratuzilma uchun pul oladi: VM (node), disk, load balancer, tarmoq trafigi, managed control plane. Pod, Deployment yoki namespace hisobda umuman ko'rinmaydi. Shuning uchun "bu servis qancha turadi" degan savolga javob berish uchun Kubernetes darajasidagi ma'lumotni (kim qancha so'radi) cloud darajasidagi narx bilan qo'lda yoki asbob bilan bog'lash kerak.

| Manba | Nima uchun to'lanadi | Ko'p uchraydigan isrof |
|-------|----------------------|------------------------|
| Compute (node'lar) | VM soati, ishlatilsa ham ishlatilmasa ham | oshirilgan requests, bo'sh node'lar, non-prod 24/7 |
| Control plane | managed cluster uchun soatlik to'lov | har jamoa va muhitga alohida cluster |
| Storage | PV hajmi (ajratilgan, to'ldirilgan emas), snapshot'lar | egasiz PVC, `Retain` bilan qolgan PV'lar, eski snapshot'lar |
| Load balancer | har biri soatlik va trafik uchun | har Service'ga `type: LoadBalancer` |
| Tarmoq | zonalararo trafik, NAT gateway, internetga egress | gapdon servislar turli zonada, image pull NAT orqali |
| Observability | metrika, log, trace saqlash | yuqori cardinality, debug log'lar production'da |

### Mexanizm

Hisob vaqt bo'yicha yuritiladi: node yoqilgan har soat (ko'p cloud'da har soniya) to'lanadi, ichida nechta Pod ishlashidan qat'i nazar. Disk ajratilgan GB va oy bo'yicha, load balancer soat va o'tgan trafik bo'yicha. Demak xarajatni kamaytirishning faqat ikki yo'li bor: kamroq resurs ushlab turish (kamroq node, kichikroq disk) yoki o'sha resursni arzonroq sotib olish (spot, majburiyat chegirmasi). Kubernetes ichidagi har optimallashtirish oxir-oqibat shu ikkisidan biriga olib kelishi kerak, aks holda hisobda hech narsa o'zgarmaydi.

Odatda eng katta qator compute, va uning ichida eng katta isrof: so'ralgan, lekin ishlatilmagan resurs (2-bo'lim).

### Ishlaydigan misol

Node qancha resurs "sotishini" ko'ramiz. `capacity` bu node'dagi jami resurs, `allocatable` esa kubelet va tizim rezervidan keyin Pod'larga qolgani (4-dars):

```
$ kubectl get nodes -o custom-columns='NAME:.metadata.name,CPU:.status.capacity.cpu,MEM:.status.capacity.memory,ALLOC_CPU:.status.allocatable.cpu,ALLOC_MEM:.status.allocatable.memory'
NAME                 CPU   MEM          ALLOC_CPU   ALLOC_MEM
cost-control-plane   8     16303344Ki   8           16303344Ki
cost-worker          8     16303344Ki   8           16303344Ki
cost-worker2         8     16303344Ki   8           16303344Ki
```

- `-o custom-columns` har ustun uchun nom va JSON yo'lini beradi: `kubectl get` chiqishini o'zingiz loyihalaysiz.
- `CPU 8` node 8 ta CPU borligini aytadi. Lekin bu kind: uchala node bitta host'ning (Zorin'da noutbukning, Mac'da Docker Desktop VM'ining) bir xil 8 yadrosini ko'radi. Haqiqiy cluster'da har node alohida VM va o'z resursiga ega.
- `MEM 16303344Ki` kibibaytda (taxminan 15.5 GiB). Yana: uchala node bir xil xotirani "ko'radi", jami 46 GiB emas.
- `ALLOC_*` kind'da `capacity` bilan teng, chunki kind node'larida rezerv sozlanmagan. Managed cluster'larda `allocatable` sezilarli kichik bo'ladi (5-bo'lim, "node soligi").

Xulosa: kind'da "node to'ldi" degan gap requests yig'indisi bo'yicha to'g'ri, lekin haqiqiy jismoniy resurs uchala node orasida bo'lingan. Shuning uchun darsdagi raqamlar shartli, nisbatlar esa haqiqiy.

### Real ishda qachon kerak

Hisob o'sganda birinchi savol "qaysi qator o'sdi" bo'ladi. Cloud billing konsoli (AWS Cost Explorer va shunga o'xshashlar) xizmat bo'yicha bo'ladi: EC2, EBS, ELB, NAT, Data Transfer. Shu jadvalni bilsangiz, har qatorni Kubernetes'dagi sababiga bog'lay olasiz: EBS o'sdi, demak PVC'lar; ELB, demak `LoadBalancer` Service'lar.

### Nima uchun shunday

Kubernetes ataylab infratuzilmadan abstraksiya qiladi: ilova "menga 500m CPU kerak" deydi, qaysi VM'da ekanini bilmaydi. Bu abstraksiyaning narxi: hisob va workload orasidagi bog'liqlik yo'qoladi. Muqobili, har servisga alohida VM (Kubernetes'gacha bo'lgan dunyo), hisobni oson qiladi, lekin har VM'ning bo'sh qismi umuman bo'linmaydi. Kubernetes zichlikni oshiradi, evaziga xarajatni taqsimlash alohida muammoga aylanadi (4-bo'lim).

## 2. Requests, iste'mol va right-sizing

### Bu nima

Cloud node uchun to'laysiz. Node'ga nechta Pod sig'ishini esa **requests** belgilaydi: scheduler iste'molga emas, requests'ga qaraydi (4-dars). Demak Pod 1 CPU so'rab 100m ishlatsa, qolgan 900m boshqa hech kimga berilmaydi, lekin to'lanadi. **Right-sizing** bu requests va limits'ni o'lchangan haqiqiy iste'molga moslash jarayoni.

```
Pod cost  ~ max(requests, usage) * resource price * time
idle cost = allocatable but unrequested capacity
waste     = requested - used
```

- Birinchi qator: Pod requests'dan ko'p ishlatsa (limit ruxsat bersa), u ko'proq joy egallaydi; kam ishlatsa ham requests'ni to'laydi.
- Ikkinchi qator: **idle** bu node'da hech kim so'ramagan bo'sh joy. U ham to'lanadi, lekin hech bir jamoaga tegishli emas.
- Uchinchi qator: **waste** so'ralgan, lekin ishlatilmagan joy. U jamoaga tegishli va eng ko'p tejash shu yerda.

| Holat | Belgi | Oqibat |
|-------|-------|--------|
| Requests iste'moldan ancha katta | node'lar "to'la" (requests bo'yicha), `kubectl top` da bo'sh | ortiqcha node'lar, pul |
| Requests iste'moldan kichik | node overcommit, CPU throttling, OOM, eviction | ishonchsizlik |
| Requests yo'q | BestEffort, autoscaler ko'rmaydi | ikkalasi ham |

### Mexanizm

Ikki xil hisob bir vaqtda yuritiladi va ular bir-birini bilmaydi:

1. Scheduler hisobi: har node uchun `allocatable` dan shu node'dagi Pod'larning requests yig'indisi ayriladi. Yangi Pod faqat qolgan joyga sig'sa joylanadi. Iste'mol bu hisobga umuman kirmaydi.
2. Kernel hisobi: konteyner haqiqatda qancha CPU vaqti va xotira ishlatayotgani. Bu cgroup orqali o'lchanadi (Docker modulidagi cgroup'lar), kubelet uni yig'adi, metrics-server esa API orqali `kubectl top` ga beradi.

CPU va xotira bu ikki hisob o'rtasida turlicha o'zini tutadi. CPU **siqiladigan** (compressible) resurs: yetmasa konteyner sekinlashadi (throttling, ya'ni kernel uni navbat kuttiradi), lekin o'lmaydi. Xotira **siqilmaydigan**: limitdan oshsa kernel jarayonni OOM kill qiladi, node'da xotira tugasa kubelet Pod'larni evict qiladi (4-dars, QoS).

### Ishlaydigan misol

`demo` namespace'ida 1 CPU so'raydigan, lekin deyarli hech narsa qilmaydigan Deployment:

```bash
kubectl -n demo create deployment idle --image=httpd:2.4-alpine
kubectl -n demo set resources deployment idle --requests=cpu=1,memory=256Mi
```

```
$ kubectl describe node cost-worker | grep -A 6 'Allocated resources'
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests      Limits
  --------           --------      ------
  cpu                1100m (13%)   100m (1%)
  memory             306Mi (1%)    50Mi (0%)
  ephemeral-storage  0 (0%)        0 (0%)
```

- `Allocated resources` bu scheduler hisobi: shu node'dagi barcha Pod'lar requests va limits yig'indisi.
- `cpu 1100m (13%)`: bizning 1000m va DaemonSet'lar (kindnet, kube-proxy) 100m. Foiz `allocatable` ga nisbatan.
- `Limits` ustuni requests'dan kichik bo'lishi mumkin: limit yozmagan Pod'lar limit yig'indisiga kirmaydi.
- "Total limits may be over 100 percent" eslatmasi: limitlar yig'indisi node'dan katta bo'lishi mumkin (overcommit), requests yig'indisi esa hech qachon.

```
$ kubectl -n demo top pods
NAME                    CPU(cores)   MEMORY(bytes)
idle-<hash>-<suffix>    1m           5Mi
```

- `CPU(cores) 1m`: Pod oxirgi o'lchov oynasida 1 millicore ishlatgan. So'ragani 1000m. Samaradorlik (iste'mol / requests) 0.1%.
- `MEMORY(bytes) 5Mi` bu working set (faol ishlatilayotgan xotira), so'ralgani 256Mi.

Scheduler nuqtai nazaridan bu Pod bitta CPU'ni to'liq band qilgan; kernel nuqtai nazaridan u deyarli yo'q. Cloud'da siz scheduler hisobi bo'yicha to'laysiz, chunki node soni shunga qarab o'sadi.

### Right-sizing tartibi

1. Kamida bir-ikki haftalik iste'mol ma'lumoti (Prometheus: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`), cho'qqi kunlarini qamrab olsin. `kubectl top` faqat hozirgi lahzani ko'rsatadi, tarix saqlamaydi.
2. CPU request: odatiy iste'molning yuqori foizi (masalan p90–p95; **p95** degani o'lchovlarning 95% shu qiymatdan past). CPU siqiladi, yetmasa throttle bo'ladi, o'lmaydi.
3. Memory request: cho'qqi iste'mol plus zaxira. Xotira siqilmaydi, yetmasa OOM kill. Ko'p hollarda memory request = limit.
4. VPA `Off` rejimida (14-dars) shu hisobni o'zi qiladi va tavsiya beradi.
5. O'zgartirish, kuzatish, takrorlash. Right-sizing bir martalik ish emas: kod va yuk o'zgaradi.

HPA bilan bog'liqligi: HPA utilization'ni requests'ga nisbatan hisoblaydi (14-dars). Request kamaysa, o'sha iste'mol katta foiz bo'lib ko'rinadi va HPA ko'proq replica qo'shadi. Right-sizing'dan keyin HPA target'ini qayta ko'ring.

Frontend tajribasidan haqiqiy o'xshatish: bundle size budget. Lighthouse yoki `size-limit` bilan o'lchamasdan "kattaroq qo'yib qo'yamiz" desangiz, budget ma'nosini yo'qotadi; o'lchab qattiq qo'ysangiz, birinchi katta kutubxona build'ni sindiradi. Requests ham xuddi shunday: o'lchovsiz son yo isrof, yo xavf.

### Real ishda qachon kerak

Cluster node soni o'sib borayotganda, lekin `kubectl top nodes` da node'lar 20–30% yuklangan bo'lsa: bu klassik "requests shishgan" belgisi. Yangi servis production'ga chiqqanidan bir-ikki hafta o'tib requests'ni haqiqiy ma'lumot bo'yicha qayta ko'rish yaxshi odat.

### Nima uchun shunday

Scheduler iste'molga qarab joylashtirsa, bo'sh ko'ringan node'ga Pod qo'yiladi va bir daqiqadan keyin cho'qqi kelganda hammasi bir-birini siqadi. Requests bu **kafolat**: "shu Pod uchun shuncha joy har doim bo'ladi". Kafolat sotib olinadi, ishlatilsa ham ishlatilmasa ham. Muqobil yondashuv (iste'molga asoslangan overcommit) Borg kabi ichki tizimlarda bor, lekin u aniq prioritet va eviction siyosatini talab qiladi; Kubernetes oddiy va bashorat qilinadigan modelni tanlagan.

## 3. ResourceQuota va LimitRange

### Bu nima

Namespace xarajat chegarasining tabiiy birligi: jamoa yoki muhit = namespace. **ResourceQuota** namespace'ning umumiy shiftini belgilaydi (jami requests, Pod soni, PVC soni va hokazo). **LimitRange** har bitta konteyner, Pod yoki PVC uchun default qiymatlar va chegaralar beradi.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: team-x, namespace: team-x }
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.memory: 16Gi
    pods: "30"
    persistentvolumeclaims: "10"
    requests.storage: 50Gi
    services.loadbalancers: "1"
```

```yaml
apiVersion: v1
kind: LimitRange
metadata: { name: defaults, namespace: team-x }
spec:
  limits:
    - type: Container
      defaultRequest: { cpu: 100m, memory: 128Mi }
      default: { memory: 256Mi }
      max: { cpu: "2", memory: 2Gi }
```

- `defaultRequest` requests yozmagan konteynerga qo'yiladi, `default` esa limit yozmaganiga.
- `max` (va `min`) chegaradan tashqaridagi qiymat rad etiladi.

### Mexanizm

Ikkalasi ham **admission** bosqichida ishlaydi: API server so'rovni etcd'ga yozishdan oldin uni admission plugin'lardan o'tkazadi (13-darsdagi Pod Security ham shu bosqichda). Tartib muhim:

1. LimitRanger (mutating, ya'ni obyektni o'zgartiradigan) avval ishlaydi: bo'sh requests va limits'ni default qiymatlar bilan to'ldiradi, keyin `min`/`max` ni tekshiradi.
2. ResourceQuota (validating) keyin ishlaydi: to'ldirilgan Pod'ning qiymatlarini namespace'dagi ishlatilgan miqdorga qo'shib, `hard` bilan solishtiradi. Oshsa, so'rov rad etiladi.

Bundan uch muhim xulosa:

- Quota Pod yaratilayotganda tekshiriladi. Deployment'ni o'zi qabul qilinadi, uning ReplicaSet'i esa Pod yarata olmaydi: xato `kubectl apply` da emas, ReplicaSet event'ida ko'rinadi.
- `requests.cpu` kabi quota qo'yilgan namespace'da shu qiymatni ko'rsatmagan Pod **rad etiladi**: quota qiymatsiz Pod'ni hisoblay olmaydi. Shuning uchun quota deyarli har doim LimitRange bilan birga keladi.
- LimitRange faqat yangi obyektlarga ta'sir qiladi; mavjud Pod'lar o'zgarmaydi.

### Ishlaydigan misol

Vazifalardagidan boshqa holat: `demo` namespace'iga faqat Pod soni bo'yicha quota, imperativ buyruq bilan:

```
$ kubectl -n demo create quota pod-cap --hard=pods=3
resourcequota/pod-cap created
$ kubectl -n demo scale deployment idle --replicas=5
deployment.apps/idle scaled
$ kubectl -n demo get deployment idle
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
idle   3/5     3            3           12m
```

- `kubectl create quota NAME --hard=...` oddiy quota uchun qisqa yo'l; manifest bilan bir xil obyekt yaratadi.
- `scale` muvaffaqiyatli: Deployment'ning `replicas` maydoni 5 bo'ldi, quota buni to'xtatmaydi.
- `READY 3/5`: atigi 3 ta Pod bor. Qolgan ikkitasi umuman yaratilmagan, `Pending` ham emas.

```
$ kubectl -n demo describe quota pod-cap
Name:       pod-cap
Namespace:  demo
Resource    Used  Hard
--------    ----  ----
pods        3     3
$ kubectl -n demo get events --field-selector reason=FailedCreate | tail -1
<age>   Warning   FailedCreate   replicaset/idle-<hash>   Error creating: pods "idle-<hash>-<suffix>" is forbidden: exceeded quota: pod-cap, requested: pods=1, used: pods=3, limited: pods=3
```

- `Used 3, Hard 3`: shift to'lgan.
- Event `replicaset/...` nomidan keladi, Deployment'dan emas: Pod'ni ReplicaSet yaratadi (4-dars).
- `exceeded quota: pod-cap, requested: pods=1, used: pods=3, limited: pods=3`: qaysi quota, nima so'raldi, qancha ishlatilgan, shift qancha. Xuddi shu format CPU va xotira quota'larida ham.

Tozalash: `kubectl -n demo delete quota pod-cap`. ReplicaSet bir oz kutib qolgan ikki Pod'ni o'zi yaratadi.

### Real ishda qachon kerak

Bir cluster'da bir nechta jamoa yoki muhit yashaganda. Quota jarima emas, signal: jamoa shiftga yetsa, suhbat boshlanadi (right-sizing yoki shiftni asosli oshirish). LimitRange esa requests'siz yozilgan workload'ni "BestEffort" bo'lib qolishdan saqlaydi. Obyekt soni quota'lari (`services.loadbalancers`, `count/<resurs>.<guruh>`) to'g'ridan-to'g'ri pul turadigan obyektlarni cheklaydi.

### Nima uchun shunday

Quota cluster'ning umumiy resursini adolatli bo'lish vositasi sifatida yaratilgan: bitta jamoaning xatosi (cheksiz scale) boshqalarning Pod'larini `Pending` qilmasin. Admission'da tekshirish eng arzon joy: obyekt hali yaratilmagan, rad etish hech narsani buzmaydi. Muqobili, ishlab turgan Pod'larni shiftdan oshganda o'ldirish, ancha xavfli bo'lardi. LimitRange'ning alohida obyekt ekani esa "chegaralar" va "default'lar"ni namespace egasi o'zi sozlashi uchun.

## 4. Ko'rinish: OpenCost

### Bu nima

Cloud hisobi node'lar bo'yicha keladi, savol esa "qaysi jamoa, qaysi servis" bo'yicha. **OpenCost** (CNCF loyihasi) Prometheus metrikalari va cloud narxlaridan har Pod'ning ulushini hisoblaydi va namespace, label, controller bo'yicha yig'adi. Kubecost shu asosdagi tijorat mahsuloti. Bu jarayon **allocation** (ajratish) deyiladi: umumiy hisobni egalarga bo'lish.

### Mexanizm

1. OpenCost node narxini oladi: cloud'da provayder API'sidan (instance turi bo'yicha), kind yoki on-prem'da sozlangan default narxlardan (1 vCPU-soat, 1 GiB-soat).
2. Node narxi CPU va xotira qismlariga bo'linadi.
3. Har Pod uchun Prometheus'dan requests va iste'mol olinadi; Pod narxi ikkalasidan kattasiga, node narxining resurs ulushiga ko'paytirib hisoblanadi (2-bo'limdagi `max(requests, usage)` formula).
4. Node'da hech kimga tegishli bo'lmagan qism **idle** sifatida alohida ko'rsatiladi.
5. Natija namespace, controller, label bo'yicha yig'iladi va UI hamda HTTP API orqali beriladi.

Xarajatni egasiga bog'lash uchun izchil label'lar kerak: `team`, `app`, `env`. Label'siz workload "noma'lum" qatoriga tushadi. Cloud tomonida node va disk tag'lari ham shunday (iac moduli).

### Ishlaydigan misol

O'rnatish rasmiy hujjat bo'yicha (9-vazifa), bu yerda faqat foydalanish shakli. UI va API port-forward orqali:

```bash
kubectl port-forward -n opencost service/opencost 9003 9090
# UI:  http://localhost:9090
# API: http://localhost:9003
```

Bitta `port-forward` bir nechta portni uzatadi: 9090 UI, 9003 API. Ikkala mashinada `localhost` ishlaydi (macOS'da ham, port-forward `kubectl` jarayoni orqali o'tadi).

```
$ curl -sG http://localhost:9003/allocation/compute -d window=60m -d aggregate=namespace | jq '.data[0] | keys'
[
  "__idle__",
  "demo",
  "kube-system",
  "opencost",
  "prometheus-system"
]
```

- `-G` va `-d` `curl` ga parametrlarni query string sifatida qo'shishni aytadi (`?window=60m&aggregate=namespace`).
- `window=60m` oxirgi 60 daqiqa; `aggregate=namespace` namespace bo'yicha yig'ish (label bo'yicha yig'ish ham bor, hujjatga qarang).
- `jq` JSON'dan kalitlarni ajratadi. Har namespace alohida yozuv, `__idle__` esa hech kimga tegishli bo'lmagan bo'sh joy.

Har yozuv ichida `cpuCost`, `ramCost`, `totalCost`, `cpuEfficiency` kabi maydonlar bor. kind'da dollar qiymatlari shartli (default narxlar), lekin `demo` va `__idle__` orasidagi nisbat haqiqiy.

### Real ishda qachon kerak

Showback (7-bo'lim) uchun, right-sizing nomzodlarini topish uchun (eng past samaradorlik va eng katta summa kesishmasi), va "bu oy nima o'sdi" savoliga javob berish uchun. Kichik jamoada OpenCost'siz ham ishlash mumkin ("Birga bajaramiz" shuni qo'lda qiladi), lekin bir nechta jamoa bo'lganda qo'lda hisob tez eskiradi.

### Nima uchun shunday

OpenCost xarajatni requests va iste'molning kattasi bo'yicha hisoblaydi, chunki ikkalasi ham joyni band qiladi: requests boshqalarga joy bermaydi, ortiqcha iste'mol esa qo'shnilardan oladi. Idle'ni alohida ko'rsatish ataylab: uni jamoalarga yashirincha taqsimlasangiz, hech kim bo'sh node uchun javob bermaydi. Muqobil standart ham bor: FinOps Foundation'ning FOCUS formati cloud hisoblarini bir xil sxemaga keltiradi, OpenCost esa Kubernetes ichidagi taqsimotga qaratilgan.

## 5. Compute'ni arzonlashtirish

### Spot node'lar

**Spot** (GCP'da ham spot, Azure'da spot VM) bu cloud bo'sh quvvatini katta chegirma bilan sotishi; evaziga u quvvatni istalgan paytda qisqa ogohlantirish bilan qaytarib oladi (AWS'da 2 daqiqa, GCP'da 30 soniya). Bu 11-darsdagi "node o'chishi" ssenariysi, faqat tez-tez va ogohlantirish bilan.

Spot'da ishlashi mumkin bo'lgan workload: stateless, bir nechta replica, tez start, graceful shutdown bor. Ishlamasligi kerak: yagona nusxali baza, uzoq va uzib bo'lmaydigan job'lar, quorum a'zolari (bir vaqtda bir nechta node ketishi mumkin).

Mexanika (12-darsdagi ajratilgan node'lar bilan bir xil):

- Spot node'larga **taint** (node'ga "bu yerga faqat ruxsati borlar" degan belgi, 12-dars) va label. Faqat chidamli workload'larda **toleration** (taint'ga ruxsat).
- Kamida bir qism replica on-demand node'larda: topology spread yoki node affinity `preferred` bilan aralash joylash (11-dars).
- PDB: bir vaqtda nechta Pod ketishi mumkinligini cheklaydi. U drain (ixtiyoriy chiqarish) uchun ishlaydi; node majburan olinsa PDB kutmaydi.
- Ogohlantirishni tutib node'ni drain qiladigan komponent (cloud'ning managed node group'i, Karpenter yoki termination handler).
- `terminationGracePeriodSeconds` ogohlantirish muddatidan kichik bo'lsin.
- Bir nechta instance turi va zona: bitta turdagi spot birdaniga tugashi mumkin.

Taint sintaksisi (boshqa misol, `pool=batch`):

```
$ kubectl taint nodes cost-worker pool=batch:NoSchedule
node/cost-worker tainted
$ kubectl describe node cost-worker | grep Taints
Taints:             pool=batch:NoSchedule
$ kubectl taint nodes cost-worker pool=batch:NoSchedule-
node/cost-worker untainted
```

- `key=value:Effect` shakli; `NoSchedule` yangi Pod'larni to'sadi, mavjudlariga tegmaydi.
- Oxiridagi `-` taint'ni olib tashlaydi.

### Bin-packing va node o'lchami

**Bin-packing** bu Pod'larni iloji boricha kam node'ga zich joylash (qutilarga narsa terish masalasi nomidan).

- Scheduler default'da Pod'larni yoyadi, zich joylamaydi. Zichlikni node autoscaler tiklaydi: Cluster Autoscaler kam yuklangan node'ni olib tashlaydi, Karpenter consolidation node'larni arzonroq to'plamga almashtiradi (14-dars).
- Har node'da qat'iy "soliq" bor: kubelet va tizim uchun rezerv (`capacity` va `allocatable` farqi, 1-bo'lim), DaemonSet'lar (CNI, log agenti, monitoring). Ko'p mayda node'da bu ulush katta. Bir necha yirik node'da esa bitta node yo'qolishi quvvatning katta qismi.
- Shakl mos kelmasligi: Pod'lar xotiraga och, node'lar CPU'ga boy bo'lsa, CPU doim bo'sh qoladi. Instance turi workload profiliga mos tanlanadi.
- Scale-down'ni to'sadigan narsalar (tor PDB, `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`, controller'siz Pod) bin-packing'ni ham to'sadi.

Soliqqa raqamli misol: har node'da DaemonSet'lar jami 300m CPU so'raydi. 2 vCPU'li 10 ta node'da bu 3 vCPU (15%), 8 vCPU'li 3 ta node'da esa 0.9 vCPU (taxminan 4%). Yirik node'lar arzonroq, lekin bittasi yo'qolsa quvvatning uchdan biri ketadi.

### Non-prod'ni nolga tushirish

Dev va staging haftasiga 168 soatdan taxminan 45 soat (kuniga 9 soat, 5 kun) ishlatiladi. Qolgan 123 soatda replica'larni nolga tushirish compute'ning taxminan 73% ini tejaydi, **agar** node autoscaler bo'sh node'larni ham olib tashlasa. Node qolsa, u baribir to'lanadi.

Usullar: KEDA `cron` scaler'i (ish vaqtida N replica, qolgan vaqtda 0), `kubectl scale` qiladigan CronJob (5-dars), navbat worker'lari uchun KEDA scale-to-zero (14-dars). GitOps bilan to'qnashmasligi kerak (10-dars: `replicas` ni kim boshqaradi). Baza va PVC'lar nolga tushmaydi: disk to'lovi davom etadi.

Qo'lda butun namespace'ni nolga tushirish (sinov uchun):

```
$ kubectl -n demo scale deployment --all --replicas=0
deployment.apps/idle scaled
```

`--all` namespace'dagi shu turdagi hamma obyektni tanlaydi. Qaytarish uchun har Deployment'ning avvalgi replica soni kerak, va bu buyruq uni eslab qolmaydi: avtomatlashtirishda shu ma'lumot qayerda saqlanishini o'ylash kerak.

### Real ishda qachon kerak

Spot odatda stateless veb va worker'lar uchun birinchi katta tejash (on-demand narxidan ko'p hollarda yarmidan ham arzon). Bin-packing va node o'lchami cluster dizaynida bir marta, keyin har chorakda qayta ko'riladi. Non-prod'ni nolga tushirish deyarli bepul g'alaba, faqat jamoa "kechasi staging ishlamaydi" ga rozi bo'lishi kerak.

### Nima uchun shunday

Cloud provayder quvvatni cho'qqiga qarab quradi va qolgan vaqtda bo'sh turgan quvvatni spot sifatida sotadi: u bo'sh turgandan ko'ra arzon sotgani foydali. Kubernetes spot'ni alohida tushuncha sifatida bilmaydi, u faqat taint, toleration va PDB beradi; bu kichik bloklardan har qanday siyosat yig'iladi. Muqobili, cloud'ning o'z "spot-aware" scheduler'i, provayderga bog'lanib qolishga olib keladi.

## 6. Storage, load balancer, tarmoq

### Bu nima

Compute'dan keyingi uch qator: disklar, load balancer'lar va trafik. Ularning umumiy xususiyati: workload o'chirilgandan keyin ham yashab qolishi mumkin.

- **PVC**: to'lov ajratilgan hajm uchun, ichi bo'sh bo'lsa ham. StatefulSet o'chirilgandan keyin qolgan PVC'lar (12-dars), `Released` holatidagi `Retain` PV'lar (7-dars), hech qaysi Pod ishlatmayotgan PVC'lar davriy tekshiriladi. Snapshot'lar uchun saqlash muddati siyosati kerak.
- **StorageClass**: disk turi narxni bir necha barobar o'zgartiradi. Default class eng qimmati bo'lmasin; log va cache uchun arzonroq class.
- **Load balancer**: har `type: LoadBalancer` Service alohida cloud LB. Bitta ingress controller yoki Gateway orqasida o'nlab servis bitta LB'ni bo'lishadi (3 va 6-darslar).
- **Zonalararo trafik**: ko'p cloud'da zonalar orasidagi trafik pullik (AWS'da har yo'nalishda GB uchun). HA uchun zonalarga yoyish (11-dars) va trafik narxi orasida savdo bor. Service'ning `trafficDistribution` maydoni (`PreferSameZone`, eski nomi `PreferClose`) trafikni iloji boricha o'sha zonadagi endpoint'larga yo'naltiradi.
- **NAT va egress**: private subnet'dagi node'larning tashqi trafigi NAT gateway orqali GB uchun to'lanadi. Image pull va cloud API chaqiruvlari uchun VPC endpoint'lar (cloud moduli) buni kamaytiradi.
- **Observability**: metrika cardinality va log hajmi (observability moduli). Ba'zan monitoring hisobi kuzatilayotgan servisnikidan oshadi.

### Mexanizm

Kubernetes obyekti va cloud resursi orasida controller turadi. PVC yaratilsa CSI driver disk yaratadi (7-dars), `LoadBalancer` Service yaratilsa cloud controller LB yaratadi (6-dars). O'chirishda esa bog'lanish uziladi: StatefulSet o'chirilganda uning PVC'lari ataylab qoladi (ma'lumotni saqlash uchun), `Retain` siyosatli PV PVC o'chgandan keyin ham disk bilan birga qoladi. Namespace yoki cluster butunlay o'chirilsa, cloud controller ishlamay qolishi mumkin va LB yoki disk cloud'da "yetim" bo'lib qoladi: Kubernetes uni endi ko'rmaydi, hisob esa keladi.

### Ishlaydigan misol

```
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  40m
```

- `(default)` StorageClass'siz PVC shu class'ni oladi. Cloud'da default class qaysi disk turi ekani xarajatni belgilaydi.
- `RECLAIMPOLICY Delete`: PVC o'chirilsa disk ham o'chadi. `Retain` bo'lsa disk qoladi va qo'lda o'chirilmaguncha to'lanadi.
- `VOLUMEBINDINGMODE WaitForFirstConsumer`: disk birinchi Pod paydo bo'lgandagina yaratiladi (7-dars); cloud'da bu diskni Pod bilan bir zonada yaratish uchun ham kerak, aks holda zonalararo muammo.
- `ALLOWVOLUMEEXPANSION false`: hajmni keyin oshirib bo'lmaydi. Kengaytirish mumkin bo'lgan class'da diskni "har ehtimolga qarshi" katta qilish shart emas: kichik boshlab keyin oshiriladi.

### Real ishda qachon kerak

Muhit yoki servis o'chirilganda (yetim resurslar), oylik hisob ko'rib chiqilganda (EBS, ELB, NAT, Data Transfer qatorlari), va arxitektura qarorida (bitta LB orqali ingress, zonalarga yoyish darajasi).

### Nima uchun shunday

Ma'lumot xavfsizligi tejashdan ustun: Kubernetes PVC'ni o'z-o'zidan o'chirmaydi, chunki noto'g'ri o'chirilgan disk qaytmaydi, ortiqcha to'langan disk esa faqat pul. Shuning uchun tozalash ongli jarayon bo'lishi kerak, avtomatik "hamma narsani o'chir" emas. Zonalararo trafik narxi esa cloud'ning fizik tarmoq xarajatini aks ettiradi: HA va arzonlik orasida tanlovni provayder emas, siz qilasiz.

## 7. FinOps asoslari

### Bu nima

**FinOps**: muhandislik, moliya va biznes xarajat uchun birga javob beradigan amaliyot. Uch takrorlanuvchi faza: **Inform** (ko'rinish: kim nimaga sarflaydi), **Optimize** (right-sizing, chegirmalar, isrofni yo'qotish), **Operate** (jarayon: byudjet, alert, muntazam ko'rib chiqish).

- **Showback**: har jamoaga uning xarajati ko'rsatiladi, pul harakati yo'q. **Chargeback**: xarajat jamoa byudjetidan yechiladi. Showback bilan boshlanadi: ajratish modeli aniq va ishonchli bo'lmaguncha chargeback janjal keltiradi.
- **Umumiy xarajat** (control plane, monitoring, ingress, idle) qanday taqsimlanishi oldindan kelishiladi: teng, ulushga mutanosib yoki platforma byudjetida.
- **Unit economics** (birlik iqtisodi): mutlaq summa emas, birlik narxi: bitta so'rov, bitta mijoz, bitta buyurtma qancha turadi.
- **Majburiyat chegirmalari** (Savings Plans, reserved instance'lar: 1 yoki 3 yilga ma'lum hajmni ishlatishga va'da berib chegirma olish): barqaror bazaviy yuk uchun, right-sizing'dan **keyin**. Avval isrofni yo'qotish, keyin qolganiga chegirma.
- Byudjet alert'i (cloud moduli) va xarajat anomaliyasi alert'i texnik alert'lar bilan bir qatorda turadi.

### Mexanizm

Inform → Optimize → Operate aylana, bir martalik loyiha emas. Inform OpenCost yoki cloud billing ma'lumotidan hisobot beradi; Optimize shu hisobotdagi eng katta qatorlardan boshlaydi; Operate natijani jarayonga aylantiradi (oylik ko'rib chiqish, quota, byudjet alert'i), keyin yana Inform. Har aylanishda ko'rinish aniqroq, tejash kichikroq, lekin barqarorroq.

### Ishlaydigan misol

Unit economics hisob-kitobi (kodsiz, raqamlar shartli):

```
            month 1        month 2        change
bill        $4,000         $4,800         +20%
requests    200M           300M           +50%
cost / 1M   $20.00         $16.00         -20%
```

- `bill` o'sdi, va faqat shu qatorga qarasa, moliya bo'limi xavotirga tushadi.
- `requests` (HTTP so'rovlar) tezroq o'sdi.
- `cost / 1M` = hisob / (so'rovlar / 1M). Birlik narxi tushdi: tizim samaraliroq ishlayapti. 22-vazifadagi "million so'rovga narx" aynan shu.

### Real ishda qachon kerak

Cloud hisobi sezilarli bo'lgan har kompaniyada, odatda bir nechta jamoa bitta platformani ishlatganda. Dasturchi sifatida sizga eng yaqin qismi: o'z servisingizning birlik narxini bilish va requests yozganda ularning pulga aylanishini tushunish.

### Nima uchun shunday

Cloud'da sotib olish qarori moliyadan muhandisga o'tgan: bitta `replicas: 20` yoki `instanceType` qatori oyiga minglab dollar degani. Xarajat ko'rinmasa, uni yaratganlar natijani ko'rmaydi. FinOps bu ko'rinishni qaytaradi. Eng muhim tamoyil: tejash ishonchlilik hisobiga bo'lmasin. Har optimallashtirish uchun "bu nimani xavf ostiga qo'yadi" savoli yoziladi.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Requests | scheduler Pod uchun kafolatlab band qiladigan resurs, to'lov shunga bog'liq |
| Iste'mol (usage) | konteyner haqiqatda ishlatayotgan CPU va xotira, cgroup orqali o'lchanadi |
| Right-sizing | requests va limits'ni o'lchangan iste'molga moslash |
| Waste | so'ralgan, lekin ishlatilmagan resurs |
| Idle | node'da hech kim so'ramagan, lekin to'lanayotgan bo'sh joy |
| Capacity / allocatable | node'dagi jami resurs / rezervdan keyin Pod'larga qolgani |
| Throttling | CPU limitiga yetgan konteynerni kernel navbat kuttirishi |
| OOM kill | xotira limitidan oshgan jarayonni kernel o'ldirishi |
| p95 | o'lchovlarning 95% shu qiymatdan past bo'lgan nuqta |
| ResourceQuota | namespace uchun umumiy resurs va obyekt soni shifti |
| LimitRange | konteyner, Pod yoki PVC uchun default qiymatlar va min/max chegaralar |
| Admission | API server obyektni saqlashdan oldin uni tekshirish va o'zgartirish bosqichi |
| Allocation | umumiy hisobni workload va jamoalarga bo'lib berish |
| OpenCost | Kubernetes xarajatini Pod, namespace va label bo'yicha hisoblaydigan CNCF loyihasi |
| Spot | cloud'ning bo'sh quvvati, arzon, lekin ogohlantirish bilan qaytarib olinadi |
| On-demand | oddiy narxdagi, qaytarib olinmaydigan VM |
| Bin-packing | Pod'larni kam node'ga zich joylash |
| Consolidation | node to'plamini arzonroq va zichroq to'plamga almashtirish (Karpenter) |
| Taint / toleration | node'dagi "ruxsatsiz kirma" belgisi / Pod'dagi shu belgiga ruxsat |
| Yetim resurs | egasi o'chirilgan, lekin to'lanayotgan disk, LB yoki snapshot |
| `trafficDistribution` | Service trafigini yaqin (bir zonadagi) endpoint'larga afzal yo'naltirish maydoni |
| FinOps | xarajat uchun muhandislik, moliya va biznesning birgalikdagi amaliyoti |
| Showback / chargeback | xarajatni jamoaga ko'rsatish / jamoa byudjetidan yechish |
| Unit economics | bitta so'rov, mijoz yoki buyurtmaning narxi |
| Savings Plans / reserved | ma'lum hajmga uzoq muddatli va'da evaziga chegirma |

## Tuzoqlar

- "Har ehtimolga qarshi" katta requests. Cluster'ning yarmi so'ralgan va ishlatilmagan.
- Xarajatni kamaytirish uchun requests'ni o'lchamasdan kesish: throttling, OOM, eviction.
- O'rtacha qiymatga qarab kesish. O'rtacha iste'mol 100m, cho'qqi 800m bo'lgan servisga 150m request qo'yilsa, cho'qqida u qo'shnilar bilan CPU uchun kurashadi. Foizlarga va cho'qqiga qarang.
- `kubectl top` ning bitta o'lchoviga qarab right-sizing qilish: u tarix emas, lahza.
- ResourceQuota'ni LimitRange'siz qo'yish: requests'siz Pod'lar rad etiladi, jamoa sababini tushunmaydi.
- Quota xatosini `kubectl apply` chiqishida qidirish: u ReplicaSet event'ida.
- LimitRange'da past default CPU limit: hamma servis jim throttle bo'ladi.
- kind node'larining `capacity` sini haqiqiy deb hisoblash: uchala node bitta host'ni bo'lishadi.
- Spot'da yagona nusxali baza yoki hamma replica bir xil instance turida.
- Non-prod'ni nolga tushirish, lekin node'lar qolishi: tejash yo'q.
- Nolga tushirish va GitOps bir-birini bekor qilishi: controller `replicas` ni git'dagi qiymatga qaytaradi.
- O'chirilgan muhitdan qolgan PVC, snapshot va load balancer'lar.
- Har servisga alohida `LoadBalancer`.
- Label'siz workload'lar: xarajatning katta qismi "noma'lum".
- Right-sizing'dan oldin uch yillik majburiyat sotib olish.
- Xarajat hisobotini faqat platforma jamoasi ko'rishi: requests yozadiganlar natijani ko'rmaydi.

## Manbalar

- https://kubernetes.io/docs/concepts/policy/resource-quotas/ – ResourceQuota
- https://kubernetes.io/docs/concepts/policy/limit-range/ – LimitRange
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/ – namespace uchun CPU va xotira quota'si, amaliy
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ – requests va limits
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ – taint va toleration
- https://kubernetes.io/docs/concepts/services-networking/service/#traffic-distribution – `trafficDistribution`
- https://kubernetes.io/docs/concepts/cluster-administration/node-autoscaling/ – node autoscaling va consolidation
- https://opencost.io/docs/ – OpenCost
- https://opencost.io/docs/installation/install – OpenCost o'rnatish
- https://www.finops.org/framework/ – FinOps Framework
- https://www.finops.org/introduction/what-is-finops/ – FinOps nima
- https://keda.sh/docs/latest/scalers/cron/ – KEDA cron scaler
- https://docs.aws.amazon.com/eks/latest/best-practices/cost-opt.html – EKS cost optimization best practices
- https://aws.amazon.com/ec2/spot/ – spot instance'lar
- https://aws.amazon.com/eks/pricing/ – EKS narxlari
- https://calculator.aws/ – AWS Pricing Calculator

---

## Birga bajaramiz

Vazifalardan boshqa misol: OpenCost'siz, qo'lda **showback** hisoboti. `shop` namespace'ida ikki jamoaning servislari bor; har jamoa oyiga qancha "to'lashini", qancha qismi isrof ekanini va idle qancha ekanini hisoblaymiz. Bu OpenCost ichida nima bo'layotganini qo'lda takrorlash: 9-vazifada asbob bergan raqamlarni shu mantiq bilan tekshira olasiz. Narxlar shartli. Hammasi ikkala mashinada bir xil.

1. Namespace va ikki jamoaning workload'lari. `shop.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cart
  namespace: shop
  labels: { team: checkout, app: cart }
spec:
  replicas: 2
  selector: { matchLabels: { app: cart } }
  template:
    metadata:
      labels: { team: checkout, app: cart }
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          resources:
            requests: { cpu: 500m, memory: 512Mi }
            limits: { memory: 512Mi }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: search
  namespace: shop
  labels: { team: catalog, app: search }
spec:
  replicas: 1
  selector: { matchLabels: { app: search } }
  template:
    metadata:
      labels: { team: catalog, app: search }
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          resources:
            requests: { cpu: 250m, memory: 256Mi }
            limits: { memory: 256Mi }
```

Label `team` Pod shablonida ham bor: xarajat Pod'ga tegishli, Deployment'ning o'z label'lari Pod'larga ko'chmaydi.

```
$ kubectl create namespace shop
namespace/shop created
$ kubectl apply -f shop.yaml
deployment.apps/cart created
deployment.apps/search created
```

2. Kim qancha so'radi. `custom-columns` bilan label va requests bitta jadvalda:

```
$ kubectl -n shop get pods -o custom-columns='NAME:.metadata.name,TEAM:.metadata.labels.team,CPU:.spec.containers[*].resources.requests.cpu,MEM:.spec.containers[*].resources.requests.memory'
NAME                      TEAM       CPU    MEM
cart-<hash>-<a>           checkout   500m   512Mi
cart-<hash>-<b>           checkout   500m   512Mi
search-<hash>-<c>         catalog    250m   256Mi
```

- `.spec.containers[*]` har konteynerning qiymatini oladi; ko'p konteynerli Pod'da vergul bilan bir nechta qiymat chiqadi va ularni qo'shish kerak bo'ladi.
- Jami: `checkout` 1000m CPU va 1024Mi, `catalog` 250m va 256Mi.

3. Kim qancha ishlatadi. Bir-ikki daqiqa kuting (metrics-server o'lchov yig'sin):

```
$ kubectl -n shop top pods -l team=checkout
NAME                      CPU(cores)   MEMORY(bytes)
cart-<hash>-<a>           1m           6Mi
cart-<hash>-<b>           1m           6Mi
$ kubectl -n shop top pods -l team=catalog
NAME                      CPU(cores)   MEMORY(bytes)
search-<hash>-<c>         1m           6Mi
```

`-l` label selector bilan filtrlaydi. Yuksiz httpd deyarli hech narsa ishlatmaydi; haqiqiy servisda bu raqamlar Prometheus'dan haftalik p95 sifatida olinadi.

4. Narx modeli. Shartli narx: 1 vCPU-soat $0.03, 1 GiB-soat $0.004, oyda 730 soat. Har jamoaning oylik narxi requests bo'yicha (iste'mol requests'dan kichik, shuning uchun `max` requests'ni tanlaydi):

```
checkout: 1.00 vCPU * 0.03 * 730 = $21.90   + 1.00 GiB * 0.004 * 730 = $2.92   => $24.82
catalog:  0.25 vCPU * 0.03 * 730 = $5.48    + 0.25 GiB * 0.004 * 730 = $0.73   => $6.21
```

5. Samaradorlik va isrof. `checkout`: 2m / 1000m = 0.2% CPU, 12Mi / 1024Mi taxminan 1% xotira. Ya'ni oylik $24.82 dan deyarli hammasi waste. Bu jamoaga "sizning servisingiz yomon" degan xabar emas: yuksiz lab'da kutilgan natija. Haqiqiy hisobotda xuddi shu jadval right-sizing suhbatining boshlanishi bo'ladi.

6. Idle. Idle uchun node'ning `allocatable` qismidan hamma requests ayriladi:

```
$ kubectl describe node cost-worker | grep -A 5 'Allocated resources' | grep cpu
  cpu                750m (9%)    100m (1%)
```

Raqam Pod'lar qaysi node'ga tushganiga bog'liq, sizda boshqacha bo'ladi. Bu misolda worker'da 9% so'ralgan, qolgan 91% idle. kind'da bu raqam ma'nosiz katta (node host'ning hamma yadrosini ko'radi), lekin haqiqiy cluster'da xuddi shu hisob "node'larimizning qancha qismi hech kimga tegishli emas" savoliga javob beradi. Kim to'laydi: uni platforma byudjetiga yozish yoki jamoalarga requests ulushiga qarab bo'lish (7-bo'lim, umumiy xarajat).

7. Hisobot. Bunday jadval showback'ning minimal shakli:

| Team | Requested CPU | Used CPU | Efficiency | Monthly cost |
|------|---------------|----------|------------|--------------|
| checkout | 1000m | 2m | 0.2% | $24.82 |
| catalog | 250m | 1m | 0.4% | $6.21 |
| idle (cost-worker) | 91% of node | | | platform |

8. Tozalash:

```
$ kubectl delete namespace shop
namespace "shop" deleted
```

Bu yurishda qo'llangan bo'limlar:

| Qadam | Bo'lim |
|-------|--------|
| 1 | 4-bo'lim: label'lar xarajat egasini belgilaydi |
| 2, 3 | 2-bo'lim: requests va iste'mol ikki xil hisob |
| 4 | 2 va 4-bo'limlar: `max(requests, usage)` modeli |
| 5 | 2-bo'lim: waste va samaradorlik |
| 6 | 1 va 7-bo'limlar: idle, kind `capacity` tuzog'i, umumiy xarajat |
| 7 | 7-bo'lim: showback |

---

## Vazifalar

Dars vazifalarini (1–13) `kubernetes/15-cost-optimization/` da bajaring (`make new m=kubernetes n=15 name=cost-optimization`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh; manifestlar `task_N.yaml`, skriptlar `task_N.sh` nomi bilan shu papkada. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozing: kind node `capacity` si ikkalasida turlicha. Yakuniy loyiha (14–22) manifestlari config repo'da (`k8s-gitops`) yashaydi, hujjati esa shu papkadagi `PROJECT.md` da.

### A. Requests va iste'mol

1. **Requested vs used.** Uch Deployment yarating: requests iste'moldan ancha katta, mos, va requests'siz. Har biriga yengil yuk bering. `kubectl top pods` va `kubectl describe node` dagi `Allocated resources` dan jadval tuzing: so'ralgan, ishlatilgan, farq. Node "to'la"mi va kimning nuqtai nazaridan?

2. **Waste blocks scheduling.** Birinchi Deployment'ni node'lar requests bo'yicha to'lguncha scale qiling. Yangi Pod `Pending` bo'lgan paytda `kubectl top nodes` nimani ko'rsatadi? Cloud'da bu holat qanday xarajatga aylanadi?

3. **Right-size from data.** Sinov ilovasiga 10 daqiqa o'zgaruvchan yuk bering (k6). Prometheus yoki `kubectl top` namunalaridan CPU va xotiraning o'rtacha, p95 va cho'qqi qiymatlarini oling. Requests va limits tavsiyangizni asosi bilan yozing. VPA `Off` tavsiyasi (14-dars) bilan solishtiring.

4. **Cutting too far.** CPU limit'ni cho'qqi iste'moldan past qo'ying va yukni takrorlang: latency bilan nima bo'ldi? Memory limit'ni ishchi hajmdan past qo'ying: Pod bilan nima bo'ldi (`kubectl describe pod` dagi sabab)? Ikki resursning farqini shu tajribada izohlang.

### B. Quota va LimitRange

5. **ResourceQuota.** `team-a` namespace'iga CPU, xotira, Pod soni va PVC uchun quota qo'ying. Shiftdan oshadigan Deployment yarating: nechta Pod paydo bo'ldi, xato qayerda ko'rinadi? `kubectl describe quota` chiqishini yozing.

6. **Quota without defaults.** Shu namespace'da requests'siz Pod yarating. Xato xabarini yozing. LimitRange qo'shib takrorlang va Pod'ga qanday qiymatlar yozilganini `kubectl get pod -o yaml` dan ko'rsating.

7. **LimitRange bounds.** LimitRange'ga `min` va `max` qo'shing. `max` dan katta request'li, va request'i `default` limit'dan katta bo'lgan Pod yarating. Har holatdagi xatoni izohlang. Mavjud Pod'larga LimitRange o'zgarishi ta'sir qildimi?

8. **Object count quota.** `services.loadbalancers` va `count/deployments.apps` kabi obyekt soni quota'larini qo'ying va sinang. Qaysi obyekt turlarini xarajat nuqtai nazaridan cheklash mantiqli va nima uchun?

### C. Ko'rinish va tejash

9. **OpenCost.** Prometheus va OpenCost'ni rasmiy hujjat bo'yicha o'rnating. Workload'laringizga `team` va `app` label'larini qo'ying. UI va `/allocation/compute` API'dan namespace va label bo'yicha taqsimotni oling. Idle ulushi qancha? Qaysi workload eng past samaradorlikka (iste'mol / requests) ega?

10. **Spot simulation.** Bitta worker'ga `spot=true:NoSchedule` taint va label qo'ying. Stateless ilovani shunday joylangki: toleration bor, replica'larning bir qismi oddiy node'da qolsin, PDB bor, graceful shutdown bor. Yuk ostida "spot" node'ni drain qiling (ogohlantirishli holat), keyin `docker stop` qiling (ogohlantirishsiz). Har holatda xato so'rovlar sonini yozing.

11. **Scale non-prod to zero.** `dev` namespace'idagi Deployment'ni jadval bo'yicha nolga tushiring: KEDA `cron` scaler'i yoki CronJob bilan (sinov uchun bir necha daqiqalik oyna). Ikkinchi usulni qog'ozda loyihalang. Haftalik tejashni hisoblang: nima uchun u node autoscaler'siz nolga teng? GitOps bilan to'qnashuv qayerda chiqadi?

12. **Orphaned resources.** Cluster'da egasiz resurslarni topadigan buyruqlar to'plamini yozing: hech qaysi Pod ishlatmayotgan PVC'lar, `Released` PV'lar, `LoadBalancer` tipidagi Service'lar, 0 replica'li Deployment'lar. Sinash uchun bir nechtasini ataylab yarating. Buni muntazam ishga tushirishni qanday tashkil qilasiz?

13. **Cost tradeoffs.** Kodsiz, jadval: kamida sakkiz tejash chorasi (requests'ni kesish, spot, kam yirik node, bitta zona, non-prod nolga, bitta LB, arzon disk, qisqa retention). Har biri uchun: nimani tejaydi, nimani xavf ostiga qo'yadi, qaysi holatda qabul qilasiz.

### D. Yakuniy loyiha

Loyiha modul va kursni yakunlaydi. Yangi asbob o'rganilmaydi, mavjud bilim bitta ishlaydigan tizimga yig'iladi. Har vazifa natijasi `PROJECT.md` da hujjatlashtiriladi: arxitektura, qarorlar va sabablari, isbotlar (buyruq chiqishi, skrinshot yoki grafik). Loyihani bitta mashinada boshlash qulay, lekin 15-vazifadagi bootstrap ikkinchi mashinada ham sinalsa, "noldan tiklash" talabi o'z-o'zidan isbotlanadi. k3s variantida `kubectl` host'da ishlaydi, kubeconfig esa VM'dan olinadi va commit qilinmaydi (2-dars).

14. **Architecture and repo.** Ilovani tanlang: oldingi modullardagi servis (HTTP API, PostgreSQL, ixtiyoriy navbat worker'i). `PROJECT.md` da arxitektura sxemasi va qarorlar ro'yxatini yozing: cluster varianti, GitOps asbobi, secret yondashuvi, ingress yoki Gateway, namespace'lar. Config repo tuzilishini (10-dars) yarating: `apps/`, `infrastructure/`, `clusters/`.

15. **Cluster and GitOps bootstrap.** Ko'p node'li cluster'ni yarating (node'larga zona label'lari bilan) va GitOps controller'ni bootstrap qiling. Shu nuqtadan keyin cluster'ga qo'lda `kubectl apply` qilinmaydi: hamma narsa config repo orqali. Bootstrap qadamlarini shunday yozingki, cluster'ni o'chirib noldan tiklash mumkin bo'lsin, va buni bir marta amalda bajaring.

16. **Platform layer.** GitOps orqali infratuzilma qatlamini o'rnating: ingress controller yoki Gateway, cert-manager (8-dars), metrics-server, KEDA, CloudNativePG operator'i, secret yechimi (13-dars). Tartib bog'liqliklarini (CRD avval, CR keyin) wave yoki `dependsOn` bilan hal qiling.

17. **Application with TLS.** Ilovani `staging` va `prod` namespace'lariga deploy qiling: image digest bilan, CI (9-dars) config repo'ni yangilaydi. HTTPS cert-manager bergan sertifikat bilan (lab'da o'z CA'ngiz). Baza CloudNativePG `Cluster` sifatida, parollar git'da ochiq emas. `staging` dan `prod` ga promotion PR orqali.

18. **Resilience and scaling.** Ilovaga 11 va 14-darslarni qo'llang: zona bo'yicha spread, PDB, probe'lar, graceful shutdown, HPA yoki KEDA (`replicas` GitOps bilan to'qnashmasin), to'g'ri requests. Yuk sinovi ostida scale bo'lishini va node drain paytida xato so'rovlar yo'qligini ko'rsating.

19. **Security baseline.** Har ilova namespace'ida: Pod Security `restricted` enforce, default deny NetworkPolicy va faqat kerakli ruxsatlar (ingress, ilova -> baza, DNS, monitoring scrape), alohida ServiceAccount, minimal RBAC, non-root va read-only root filesystem. Taqiqlangan uch yo'lni sinab yopiqligini isbotlang. Image'lar pipeline'da skanerlanadi.

20. **Observability.** Observability modulidagi stack'ni GitOps orqali o'rnating (Prometheus, Grafana, log yig'ish; trace ixtiyoriy). Ilova metrikalari scrape qilinadi. Bitta dashboard: so'rovlar tezligi, xato foizi, p95 latency, replica soni, Pod restart'lari, baza holati. Kamida uchta alert qoidasi (xato foizi, Pod crash loop, sertifikat muddati) va ulardan birini ataylab ishga tushirish.

21. **Backup and restore drill.** Baza uchun backup'ni sozlang (12-dars: usul va jadval), RPO va RTO maqsadlarini yozing. Mashq: ma'lumot yozing, backup oling, yana yozing, bazani (yoki butun namespace'ni) yo'q qiling, tiklang. Tiklash vaqtini o'lchang, qaysi ma'lumot qaytgani va qaytmaganini maqsadlar bilan solishtiring. Keyin butun cluster'ni o'chirib, 15-vazifadagi bootstrap va shu backup'dan to'liq tiklashni bajaring.

22. **Cost estimate.** Shu tizimni AWS'da (EKS) ishlatishning oylik bahosini yozing: control plane, node'lar (tur, son, on-demand va spot ulushi), disklar, load balancer, NAT va trafik taxmini, observability saqlash. Raqamlar AWS Pricing Calculator'dan, manba va sana bilan. Uch variant: minimal, tavsiya etilgan HA, tejamkor (spot, non-prod nolga). Har variantda nima qurbon qilingani va birlik narxi (masalan million so'rovga) ko'rsatilsin.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. Dars vazifalari `README.md` da, loyiha `PROJECT.md` da; config repo va ilova repo havolalari bor.
3. Config repo'da ochiq secret yo'q; cluster'ni noldan tiklash qadamlari yozilgan va bir marta sinalgan.
4. Backup/restore mashqi natijalari (vaqt, yo'qotilgan ma'lumot) va xarajat bahosi hujjatda.
5. Tekshiruvdan keyin: cluster'lar va VM'lar o'chirilgan, GitHub token'lari revoke qilingan, cloud'da hech qanday resurs qolmagan.
6. Menga xabar bering: avval hujjatni o'qiyman, keyin ishlab turgan tizimni birga ko'rib chiqamiz.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Cloud'da Pod uchun nima asosida to'lanadi: iste'molmi, requests'mi? Nima uchun?
- CPU va xotira requests'ini kesishning oqibati nima uchun har xil?
- ResourceQuota nima uchun LimitRange bilan birga qo'yiladi?
- Quota tufayli yaratilmagan Pod haqidagi xatoni qayerdan qidirasiz va nima uchun aynan u yerda?
- Idle xarajat nima va uni kim to'lashi kerak?
- Qaysi workload'ni spot node'ga qo'yib bo'lmaydi va nima uchun?
- Non-prod replica'larini nolga tushirish qaysi shartda haqiqatan pul tejaydi?
- Zonalarga yoyish va tarmoq xarajati orasidagi savdo nimadan iborat?
- Showback va chargeback farqi nima, nima uchun birinchisidan boshlanadi?
- Yakuniy loyihangizda bitta node, bitta zona va butun cluster yo'qolsa har birida nima bo'ladi?
