# 15-dars: Xarajatni optimallashtirish va yakuniy loyiha

Maqsad: Kubernetes'da xarajat ko'rinmas tarzda o'sadi: har jamoa "zaxira bilan" requests yozadi, node'lar yarim bo'sh ishlaydi, unutilgan PVC va load balancer'lar oylab to'lanadi, hisob esa bitta qator bo'lib keladi: "compute". Bu darsda xarajat qayerdan kelishi, requests va haqiqiy iste'mol orasidagi farq (right-sizing), namespace darajasidagi chegaralar (ResourceQuota, LimitRange), xarajatni ko'rsatish (OpenCost), spot node'lar, bin-packing, non-prod'ni nolga tushirish, storage va tarmoq xarajati, FinOps asoslari ko'riladi. Dars modul va kursning yakuniy loyihasi bilan tugaydi: oldingi modullardagi ilova GitOps orqali ko'p node'li cluster'ga TLS, autoscaling, NetworkPolicy, observability, backup/restore mashqi va yozma xarajat bahosi bilan joylashtiriladi.

Taxminiy vaqt: 2 kun dars, 5–6 kun yakuniy loyiha (siz uchun). Darsda diqqat: "to'lov requests uchun, iste'mol uchun emas" tamoyili, quota va LimitRange'ning o'zaro bog'liqligi, tejash va ishonchlilik orasidagi savdo. Loyihada yangi mavzu yo'q, 9–14-darslar va oldingi modullar bitta tizimga yig'iladi.

## Laboratoriya

- **Dars qismi**: kind cluster `cost` (1 control-plane, 2 worker), metrics-server (14-dars). OpenCost uchun Prometheus kerak (observability moduli); o'rnatish: https://opencost.io/docs/installation/install . kind'da cloud narxlari yo'q, OpenCost default yoki siz bergan narxlar bilan hisoblaydi, raqamlar shartli, lekin nisbatlar haqiqiy.
- **Yakuniy loyiha**: ko'p node'li cluster, ikki variantdan biri: kind (1 control-plane, 3 worker) yoki Multipass VM'larda k3s (1 server, 2 agent; 2-dars). Pullik cloud cluster talab qilinmaydi. Xarajat bahosi uchun AWS Pricing Calculator (https://calculator.aws/) ishlatiladi, resurs yaratilmaydi.
- Ish mashinasi resursi cheklangan: observability stack, baza va ilova birga 8 GB atrofida xotira so'rashi mumkin. Yetmasa retention va replica'larni kamaytiring, lekin nima kamaytirilganini yozing.
- Tozalash: `kind delete cluster --name cost`; loyihadan keyin cluster yoki VM'lar, GitHub token'lari, registry'dagi sinov image'lari.

---

## 1. Xarajat qayerdan keladi

| Manba | Nima uchun to'lanadi | Ko'p uchraydigan isrof |
|-------|----------------------|------------------------|
| Compute (node'lar) | VM soati, ishlatilsa ham ishlatilmasa ham | oshirilgan requests, bo'sh node'lar, non-prod 24/7 |
| Control plane | managed cluster uchun soatlik to'lov | har jamoa va muhitga alohida cluster |
| Storage | PV hajmi (ajratilgan, to'ldirilgan emas), snapshot'lar | egasiz PVC, `Retain` bilan qolgan PV'lar, eski snapshot'lar |
| Load balancer | har biri soatlik va trafik uchun | har Service'ga `type: LoadBalancer` |
| Tarmoq | zonalararo trafik, NAT gateway, internetga egress | gapdon servislar turli zonada, image pull NAT orqali |
| Observability | metrika, log, trace saqlash | yuqori cardinality, debug log'lar production'da |

Odatda eng katta qator compute, va uning ichida eng katta isrof: so'ralgan, lekin ishlatilmagan resurs.

## 2. Requests, iste'mol va right-sizing

Cloud node uchun to'laysiz. Node'ga nechta Pod sig'ishini esa **requests** belgilaydi (scheduler iste'molga emas, requests'ga qaraydi, 4-dars). Demak Pod 1 CPU so'rab 100m ishlatsa, qolgan 900m boshqa hech kimga berilmaydi, lekin to'lanadi.

```
Pod cost  ~ max(requests, usage) * resource price * time
idle cost = allocatable but unrequested capacity
waste     = requested - used
```

| Holat | Belgi | Oqibat |
|-------|-------|--------|
| Requests iste'moldan ancha katta | node'lar "to'la" (requests bo'yicha), `kubectl top` da bo'sh | ortiqcha node'lar, pul |
| Requests iste'moldan kichik | node overcommit, CPU throttling, OOM, eviction | ishonchsizlik |
| Requests yo'q | BestEffort, autoscaler ko'rmaydi | ikkalasi ham |

### Right-sizing tartibi

1. Kamida bir-ikki haftalik iste'mol ma'lumoti (Prometheus: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`), cho'qqi kunlarini qamrab olsin.
2. CPU request: odatiy iste'molning yuqori foizi (masalan p90–p95). CPU siqiladigan resurs, yetmasa throttle bo'ladi, o'lmaydi.
3. Memory request: cho'qqi iste'mol plus zaxira. Xotira siqilmaydi, yetmasa OOM kill. Ko'p hollarda memory request = limit.
4. VPA `Off` rejimida (14-dars) shu hisobni o'zi qiladi va tavsiya beradi.
5. O'zgartirish, kuzatish, takrorlash. Right-sizing bir martalik ish emas: kod va yuk o'zgaradi.

HPA bilan bog'liqligi: request o'zgarsa utilization o'zgaradi (14-dars), right-sizing'dan keyin HPA target'ini qayta ko'ring.

**Tuzoq: o'rtacha qiymatga qarab kesish.** O'rtacha iste'mol 100m, cho'qqi 800m bo'lgan servisga 150m request qo'yilsa, cho'qqida u qo'shnilar bilan CPU uchun kurashadi. Foizlarga va cho'qqiga qarang.

## 3. ResourceQuota va LimitRange

Namespace xarajat chegarasining tabiiy birligi: jamoa yoki muhit = namespace.

**ResourceQuota** namespace'ning umumiy shiftini belgilaydi:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: team-a, namespace: team-a }
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

- Quota admission paytida tekshiriladi: shiftdan oshadigan Pod yaratilmaydi (Deployment qabul qilinadi, xato ReplicaSet event'ida).
- `requests.cpu` yoki `limits.memory` kabi quota qo'yilgan namespace'da shu qiymatni ko'rsatmagan Pod **rad etiladi**. Shuning uchun quota deyarli har doim LimitRange bilan birga keladi.
- `kubectl describe quota` ishlatilgan va shiftni ko'rsatadi.

**LimitRange** har bir konteyner (yoki Pod, PVC) uchun default va chegaralar:

```yaml
apiVersion: v1
kind: LimitRange
metadata: { name: defaults, namespace: team-a }
spec:
  limits:
    - type: Container
      defaultRequest: { cpu: 100m, memory: 128Mi }
      default: { memory: 256Mi }
      max: { cpu: "2", memory: 2Gi }
```

`defaultRequest` va `default` (limit) ko'rsatilmagan konteynerga admission paytida yoziladi, `min`/`max` dan tashqaridagisi rad etiladi. LimitRange mavjud Pod'larga ta'sir qilmaydi.

Quota jarima emas, signal: jamoa shiftga yetsa, suhbat boshlanadi (right-sizing yoki shiftni asosli oshirish).

## 4. Ko'rinish: OpenCost

Cloud hisobi node'lar bo'yicha keladi, savol esa "qaysi jamoa, qaysi servis" bo'yicha. OpenCost (CNCF loyihasi) Prometheus metrikalari va cloud narxlaridan har Pod'ning ulushini hisoblaydi va namespace, label, controller bo'yicha yig'adi. Kubecost shu asosdagi tijorat mahsuloti.

- Ajratish (allocation) modeli: Pod narxi uning requests va iste'molidan kattasiga, node narxining resurs ulushiga ko'paytirib hisoblanadi. Hech kimga tegishli bo'lmagan qism **idle** sifatida alohida ko'rsatiladi.
- Xarajatni egasiga bog'lash uchun izchil label'lar kerak: `team`, `app`, `env`. Label'siz workload "noma'lum" qatoriga tushadi. Cloud tomonida node va disk tag'lari ham shunday (iac moduli).
- UI: `kubectl port-forward -n opencost service/opencost 9003 9090`, keyin `http://localhost:9090`. API: `http://localhost:9003/allocation/compute?window=60m`.

## 5. Compute'ni arzonlashtirish

### Spot node'lar

Cloud bo'sh quvvatini katta chegirma bilan sotadi, evaziga istalgan paytda qisqa ogohlantirish bilan (AWS'da 2 daqiqa) qaytarib oladi. Bu 11-darsdagi "node o'chishi" ssenariysi, faqat tez-tez va ogohlantirish bilan.

Spot'da ishlashi mumkin bo'lgan workload: stateless, bir nechta replica, tez start, graceful shutdown bor. Ishlamasligi kerak: yagona nusxali baza, uzoq va uzib bo'lmaydigan job'lar, quorum a'zolari (bir vaqtda bir nechta node ketishi mumkin).

Mexanika (12-darsdagi ajratilgan node'lar bilan bir xil):

- Spot node'larga taint (`spot=true:NoSchedule`) va label. Faqat chidamli workload'larda toleration.
- Kamida bir qism replica on-demand node'larda: topology spread yoki node affinity `preferred` bilan aralash joylash.
- PDB: bir vaqtda nechta Pod ketishi mumkinligini cheklaydi (drain uchun; node majburan olinsa PDB kutmaydi).
- Ogohlantirishni tutib node'ni drain qiladigan komponent (cloud'ning node group'i, Karpenter yoki termination handler).
- `terminationGracePeriodSeconds` ogohlantirish muddatidan kichik bo'lsin.
- Bir nechta instance turi va zona: bitta turdagi spot birdaniga tugashi mumkin.

### Bin-packing va node o'lchami

- Scheduler default'da Pod'larni yoyadi, zich joylamaydi. Zichlikni node autoscaler tiklaydi: Cluster Autoscaler kam yuklangan node'ni olib tashlaydi, Karpenter consolidation node'larni arzonroq to'plamga almashtiradi (14-dars).
- Har node'da qat'iy "soliq" bor: kubelet va tizim uchun rezerv, DaemonSet'lar (CNI, log agenti, monitoring). Ko'p mayda node'da bu ulush katta. Bir necha yirik node'da esa bitta node yo'qolishi quvvatning katta qismi.
- Shakl mos kelmasligi: Pod'lar xotiraga och, node'lar CPU'ga boy bo'lsa, CPU doim bo'sh qoladi. Instance turi workload profiliga mos tanlanadi.
- Scale-down'ni to'sadigan narsalar (tor PDB, `safe-to-evict: "false"`, controller'siz Pod) bin-packing'ni ham to'sadi.

### Non-prod'ni nolga tushirish

Dev va staging haftasiga 168 soatdan taxminan 45 soat ishlatiladi. Ish vaqtidan tashqari replica'larni nolga tushirish compute'ning uchdan ikki qismini tejaydi, agar node autoscaler bo'sh node'larni ham olib tashlasa.

Usullar: KEDA `cron` scaler'i (ish vaqtida N replica, qolgan vaqtda 0), `kubectl scale` qiladigan CronJob (5-dars), navbat worker'lari uchun KEDA scale-to-zero (14-dars). GitOps bilan to'qnashmasligi kerak (10-dars: `replicas` ni kim boshqaradi). Baza va PVC'lar nolga tushmaydi: disk to'lovi davom etadi.

## 6. Storage, load balancer, tarmoq

- **PVC**: to'lov ajratilgan hajm uchun. StatefulSet o'chirilgandan keyin qolgan PVC'lar (12-dars), `Released` holatidagi `Retain` PV'lar, hech qaysi Pod ishlatmayotgan PVC'lar davriy tekshiriladi. Snapshot'lar uchun saqlash muddati siyosati.
- **StorageClass**: disk turi narxni bir necha barobar o'zgartiradi. Default class eng qimmati bo'lmasin; log va cache uchun arzonroq class.
- **Load balancer**: har `type: LoadBalancer` Service alohida cloud LB. Bitta ingress controller yoki Gateway orqasida o'nlab servis bitta LB'ni bo'lishadi (3 va 6-darslar).
- **Zonalararo trafik**: ko'p cloud'da zonalar orasidagi trafik pullik. HA uchun zonalarga yoyish (11-dars) va trafik narxi orasida savdo bor. Service'ning `trafficDistribution` maydoni trafikni iloji boricha o'sha zonadagi endpoint'larga yo'naltiradi.
- **NAT va egress**: private subnet'dagi node'larning tashqi trafigi NAT gateway orqali GB uchun to'lanadi. Image pull va cloud API chaqiruvlari uchun VPC endpoint'lar (cloud moduli) buni kamaytiradi.
- **Observability**: metrika cardinality va log hajmi (observability moduli). Ba'zan monitoring hisobi kuzatilayotgan servisnikidan oshadi.

## 7. FinOps asoslari

FinOps: muhandislik, moliya va biznes xarajat uchun birga javob beradigan amaliyot. Uch takrorlanuvchi faza: **Inform** (ko'rinish: kim nimaga sarflaydi), **Optimize** (right-sizing, chegirmalar, isrofni yo'qotish), **Operate** (jarayon: byudjet, alert, muntazam ko'rib chiqish).

- **Showback**: har jamoaga uning xarajati ko'rsatiladi, pul harakati yo'q. **Chargeback**: xarajat jamoa byudjetidan yechiladi. Showback bilan boshlanadi: ajratish modeli aniq va ishonchli bo'lmaguncha chargeback janjal keltiradi.
- **Umumiy xarajat** (control plane, monitoring, ingress, idle) qanday taqsimlanishi oldindan kelishiladi: teng, ulushga mutanosib yoki platforma byudjetida.
- **Unit economics**: mutlaq summa emas, birlik narxi: bitta so'rov, bitta mijoz, bitta buyurtma qancha turadi. Hisob 20% o'sdi, lekin mijozlar 50% o'sdi, bu yaxshilanish.
- **Majburiyat chegirmalari** (Savings Plans, reserved): barqaror bazaviy yuk uchun, right-sizing'dan **keyin**. Avval isrofni yo'qotish, keyin qolganiga chegirma.
- Byudjet alert'i (cloud moduli) va xarajat anomaliyasi alert'i texnik alert'lar bilan bir qatorda turadi.

Eng muhim tamoyil: tejash ishonchlilik hisobiga bo'lmasin. Har optimallashtirish uchun "bu nimani xavf ostiga qo'yadi" savoli yoziladi.

## Tuzoqlar

- "Har ehtimolga qarshi" katta requests. Cluster'ning yarmi so'ralgan va ishlatilmagan.
- Xarajatni kamaytirish uchun requests'ni o'lchamasdan kesish: throttling, OOM, eviction.
- ResourceQuota'ni LimitRange'siz qo'yish: requests'siz Pod'lar rad etiladi, jamoa sababini tushunmaydi.
- LimitRange'da past default CPU limit: hamma servis jim throttle bo'ladi.
- Spot'da yagona nusxali baza yoki hamma replica bir xil instance turida.
- Non-prod'ni nolga tushirish, lekin node'lar qolishi: tejash yo'q.
- O'chirilgan muhitdan qolgan PVC, snapshot va load balancer'lar.
- Har servisga alohida `LoadBalancer`.
- Label'siz workload'lar: xarajatning katta qismi "noma'lum".
- Right-sizing'dan oldin uch yillik majburiyat sotib olish.
- Xarajat hisobotini faqat platforma jamoasi ko'rishi: requests yozadiganlar natijani ko'rmaydi.

## Manbalar

- https://kubernetes.io/docs/concepts/policy/resource-quotas/ – ResourceQuota
- https://kubernetes.io/docs/concepts/policy/limit-range/ – LimitRange
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ – requests va limits
- https://opencost.io/docs/ – OpenCost
- https://www.finops.org/framework/ – FinOps Framework
- https://kubernetes.io/docs/concepts/cluster-administration/node-autoscaling/ – node autoscaling va consolidation
- https://keda.sh/docs/latest/scalers/cron/ – KEDA cron scaler
- https://docs.aws.amazon.com/eks/latest/best-practices/cost-opt.html – EKS cost optimization best practices
- https://aws.amazon.com/ec2/spot/ – spot instance'lar
- https://calculator.aws/ – AWS Pricing Calculator

---

## Vazifalar

Dars vazifalarini (1–13) `kubernetes/15-cost-optimization/` da bajaring (`make new m=kubernetes n=15 name=cost-optimization`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh; manifestlar shu papkada. Yakuniy loyiha (14–22) manifestlari config repo'da (`k8s-gitops`) yashaydi, hujjati esa shu papkadagi `PROJECT.md` da.

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

Loyiha modul va kursni yakunlaydi. Yangi asbob o'rganilmaydi, mavjud bilim bitta ishlaydigan tizimga yig'iladi. Har vazifa natijasi `PROJECT.md` da hujjatlashtiriladi: arxitektura, qarorlar va sabablari, isbotlar (buyruq chiqishi, skrinshot yoki grafik).

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
- Idle xarajat nima va uni kim to'lashi kerak?
- Qaysi workload'ni spot node'ga qo'yib bo'lmaydi va nima uchun?
- Non-prod replica'larini nolga tushirish qaysi shartda haqiqatan pul tejaydi?
- Zonalarga yoyish va tarmoq xarajati orasidagi savdo nimadan iborat?
- Showback va chargeback farqi nima, nima uchun birinchisidan boshlanadi?
- Yakuniy loyihangizda bitta node, bitta zona va butun cluster yo'qolsa har birida nima bo'ladi?
