# 14-dars: Autoscaling: HPA, Cluster Autoscaler, KEDA

Maqsad: hozirgacha replica sonini qo'lda yozdingiz. Yuk esa o'zgaradi: kunduzi ko'p, kechasi kam, kampaniya paytida keskin. Bu darsda uch darajadagi avtomatik masshtablash ko'riladi: Pod'lar soni (HorizontalPodAutoscaler, metrics-server, `behavior`), Pod hajmi (VerticalPodAutoscaler, umumiy ko'rinish), node'lar soni (Cluster Autoscaler va Karpenter, tushuncha darajasida), va hodisaga asoslangan masshtablash (KEDA: navbat uzunligi yoki Prometheus so'rovi bo'yicha, nolgacha tushish bilan). 4-darsdagi requests bu yerda markaziy rolga chiqadi: hamma autoscaler requests'ga tayanadi. 11-darsdagi PDB va graceful shutdown scale-down xavfsiz bo'lishi uchun kerak, 15-darsda xarajat aynan shu mexanizmlar bilan kamaytiriladi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqat: HPA formulasi va "utilization requests'ga nisbatan" ekanligi, scale-up va scale-down nima uchun har xil tezlikda, CPU qachon noto'g'ri signal, HPA, VPA va node autoscaler bir-biri bilan qanday bog'lanadi.

## Laboratoriya

- **kind cluster** `scale`: 1 control-plane, 2 worker.
- **metrics-server**: kind'da kubelet sertifikatlari o'z-o'zidan imzolangan, shuning uchun qo'shimcha flag kerak:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes
```

  `--kubelet-insecure-tls` faqat lab uchun. k3s'da metrics-server oldindan o'rnatilgan.
- **KEDA**: Helm bilan (https://keda.sh/docs/latest/deploy/):

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

- **Yuk generatori**: k6 (`grafana/k6` image, https://grafana.com/docs/k6/latest/) yoki hey (https://github.com/rakyll/hey). Yukni cluster ichidan, Service nomiga yuboring. `kubectl port-forward` bitta Pod'ga ulanadi va yukni taqsimlamaydi, HPA sinovi uchun yaramaydi.
- Node autoscaling kind'da ishlamaydi (node'lar qo'lda yaratilgan konteynerlar), u qism nazariy va `Pending` Pod'lar orqali taqlid qilinadi.
- Tozalash: `kind delete cluster --name scale`.

---

## 1. Uch o'q

| Nima o'zgaradi | Asbob | Signal | Tezlik |
|----------------|-------|--------|--------|
| Pod'lar soni | HPA, KEDA | metrika (CPU, navbat, RPS) | soniyalar, daqiqalar |
| Pod hajmi (requests) | VPA | tarixiy iste'mol | soatlar, kunlar |
| Node'lar soni | Cluster Autoscaler, Karpenter | joylashmay qolgan (`Pending`) Pod'lar | daqiqalar |

Zanjir: yuk ortadi -> HPA Pod qo'shadi -> Pod'larga joy yetmaydi, `Pending` -> node autoscaler node qo'shadi -> Pod'lar joylashadi. Teskari yo'nalishda: HPA Pod'larni kamaytiradi -> node'lar bo'shaydi -> node autoscaler ularni olib tashlaydi. Zanjirning har bo'g'ini **requests** ga qaraydi: HPA utilization'ni requests'ga nisbatan hisoblaydi, scheduler va node autoscaler requests bo'yicha joy hisoblaydi. Requests noto'g'ri bo'lsa hammasi noto'g'ri ishlaydi.

## 2. metrics-server va Metrics API

HPA metrikani o'zi yig'maydi, API'dan o'qiydi:

| API | Kim beradi | Nima |
|-----|-----------|------|
| `metrics.k8s.io` | metrics-server | Pod va node'ning joriy CPU va xotirasi (`kubectl top`) |
| `custom.metrics.k8s.io` | adapter (prometheus-adapter, KEDA) | cluster obyektlariga bog'liq metrikalar (Pod'dagi RPS) |
| `external.metrics.k8s.io` | adapter (KEDA) | cluster'dan tashqaridagi metrikalar (navbat uzunligi) |

metrics-server kubelet'lardan joriy qiymatni oladi va xotirada ushlaydi, tarix saqlamaydi. U monitoring emas (bu Prometheus ishi, observability moduli), faqat autoscaling va `kubectl top` uchun.

## 3. HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: web }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: web }
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 60 }
```

### Algoritm

Controller har 15 soniyada (default) hisoblaydi:

```
desiredReplicas = ceil( currentReplicas * currentMetricValue / targetMetricValue )
```

- `Utilization` foiz, **requests'ga nisbatan**: Pod'ning CPU request'i 200m, iste'moli 180m bo'lsa utilization 90%. Limit bu yerda ishtirok etmaydi.
- Request'i yo'q konteyner uchun utilization hisoblab bo'lmaydi, HPA `<unknown>` ko'rsatadi va ishlamaydi.
- Nisbat 1.0 ga yaqin bo'lsa (default tolerance 10%) hech narsa qilinmaydi, bu tebranishni kamaytiradi.
- Bir nechta metrika berilsa har biri uchun hisoblanadi va **eng kattasi** olinadi.
- Hali `Ready` bo'lmagan Pod'lar va metrikasi yo'q Pod'lar hisobda ehtiyotkorlik bilan inobatga olinadi: scale-up'da ular 0% deb, scale-down'da 100% deb qaraladi.

Misol: 4 Pod, target 60%, joriy o'rtacha 90%: `ceil(4 * 90 / 60) = 6`.

### Metrika turlari

| `type` | Manba | Misol |
|--------|-------|-------|
| `Resource` | metrics-server | Pod bo'yicha o'rtacha CPU yoki xotira |
| `ContainerResource` | metrics-server | faqat bitta konteyner (sidecar hisobni buzmasin) |
| `Pods` | custom metrics | har Pod'dagi o'rtacha `http_requests_per_second` |
| `Object` | custom metrics | boshqa obyekt metrikasi (Ingress RPS) |
| `External` | external metrics | navbat uzunligi, cloud metrikasi |

**CPU har doim ham to'g'ri signal emas.** I/O kutadigan servis (bazaga so'rov, tashqi API) yuk ostida CPU'ni kam ishlatadi, latency esa o'sadi. Navbatdan o'qiydigan worker uchun to'g'ri signal navbat uzunligi. Xotira odatda yomon signal: ko'p runtime'lar (Node, JVM) xotirani qaytarmaydi, scale-up bo'ladi, scale-down hech qachon.

### behavior va stabilization

Yuk tebransa replica soni ham tebranadi (flapping). Default'lar assimetrik: scale-up darhol, scale-down oxirgi 5 daqiqadagi eng yuqori tavsiya bo'yicha (stabilization window 300 soniya).

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
      - { type: Percent, value: 50, periodSeconds: 60 }
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
      - { type: Pods, value: 4, periodSeconds: 60 }
```

`policies` bir davrda qancha o'zgarish mumkinligini cheklaydi (`Pods` yoki `Percent`), bir nechta bo'lsa `selectPolicy` (`Max` default, `Min`, `Disabled`) tanlaydi. Mantiq: tez o'sish (mijoz kutmasin), sekin kamayish (yuk qaytsa Pod'lar tayyor tursin).

### HPA atrofidagi shartlar

- **Ishga tushish vaqti.** Yangi Pod image pull, start, readiness'dan o'tguncha yuk ko'tarmaydi. Start 60 soniya bo'lsa HPA har doim bir daqiqa kechikadi. Target'ni pastroq qo'yish (60–70%) shu zaxira uchun.
- **`replicas` maydoni.** HPA boshqaradigan Deployment manifestida `replicas` bo'lmasin: har `kubectl apply` yoki GitOps sync uni manifestdagi songa qaytaradi (10-dars).
- **`minReplicas`** HA uchun kamida 2 (11-dars). `maxReplicas` byudjet va quyi tizimlar (baza ulanishlari soni) chegarasi.
- **Scale-down ham uzilish.** Pod'lar o'chiriladi, graceful shutdown (11-dars) bo'lmasa har scale-down'da xato so'rovlar.
- `kubectl describe hpa` dagi `Conditions` va `Events` nima uchun scale bo'lgani yoki bo'lmaganini aytadi: `AbleToScale`, `ScalingActive`, `ScalingLimited`.

## 4. VerticalPodAutoscaler

VPA replica sonini emas, requests'ni o'zgartiradi. Kubernetes tarkibida emas, alohida o'rnatiladi (kubernetes/autoscaler repo'si). Uch komponent: recommender (iste'mol tarixidan tavsiya hisoblaydi), updater (tavsiyadan uzoq Pod'larni yangilaydi), admission controller (yangi Pod'ga tavsiya etilgan requests'ni yozadi).

| `updateMode` | Xatti-harakat |
|--------------|---------------|
| `Off` | faqat tavsiya (`kubectl describe vpa`), hech narsa o'zgarmaydi |
| `Initial` | faqat Pod yaratilganda qo'llaydi |
| `Recreate` | Pod'ni evict qilib yangi requests bilan qayta yaratadi |
| `InPlaceOrRecreate` | avval Pod'ni restart'siz o'zgartirishga urinadi (yangi versiyalarda) |

- Eng xavfsiz va eng foydali rejim `Off`: right-sizing uchun tavsiya manbai (15-dars).
- **HPA va VPA bir xil metrika (CPU yoki xotira) ustida birga ishlatilmaydi**: VPA requests'ni o'zgartirsa HPA'ning utilization'i o'zgaradi va ikkalasi bir-birini quvlaydi. HPA custom metrika bilan, VPA CPU/xotira bilan ishlasa mumkin.
- Kubernetes'da Pod resurslarini restart'siz o'zgartirish (in-place resize, `kubectl patch --subresource=resize`) 1.35 dan stable, VPA shundan foydalanadi.

## 5. Node autoscaling

### Cluster Autoscaler

Cloud'dagi node group'lar (AWS Auto Scaling Group va o'xshashlar) hajmini o'zgartiradi.

- **Scale-up**: resurs yetmagani uchun joylashmagan `Pending` Pod paydo bo'lsa, qaysi node group'ga node qo'shilsa u joylashishini simulyatsiya qiladi va guruhni kattalashtiradi. Signal CPU yuklanishi emas, **requests bo'yicha joy yetmasligi**. Node'lar 90% yuklangan, lekin hamma Pod joylashgan bo'lsa hech narsa bo'lmaydi.
- **Scale-down**: node'dagi requests yig'indisi chegaradan (default 50%) past bo'lib, bir muddat (default 10 daqiqa) shunday tursa va uning Pod'lari boshqa node'larga sig'sa, node drain qilinib o'chiriladi.
- Scale-down'ni to'xtatadigan narsalar: PDB ruxsat bermasa, controller'siz Pod, local storage ishlatadigan Pod, `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` annotation.
- Yangi node bir necha daqiqada tayyor bo'ladi (VM yaratish, boot, cluster'ga qo'shilish, image pull). HPA soniyalarda javob bersa ham, node yetmasa Pod'lar shu vaqt `Pending` turadi.

### Karpenter

Node group'lar bilan emas, to'g'ridan-to'g'ri instance'lar bilan ishlaydi: `Pending` Pod'larning talablariga (requests, nodeSelector, affinity, toleration) qarab eng mos instance turini o'zi tanlaydi va yaratadi. `NodePool` qanday node'lar yaratish mumkinligini (instance turlari, zonalar, spot yoki on-demand, limit), provider'ga xos NodeClass esa AMI va tarmoq sozlamalarini belgilaydi. Consolidation: Pod'larni zichroq joylash mumkin bo'lsa node'larni almashtiradi yoki olib tashlaydi. AWS'da boshlangan, hozir Kubernetes SIG Autoscaling loyihasi, provider'lar alohida.

Ikkalasi uchun umumiy: requests'siz Pod'lar autoscaler uchun "nol joy" egallaydi, node'lar haddan tashqari to'ladi. Va overprovisioning usuli: past priority'li (11-dars) "pause" Pod'lar zaxira joyni ushlab turadi, haqiqiy Pod kelganda preempt bo'ladi va o'zi yangi node'ni chaqiradi.

## 6. KEDA

HPA'ning ikki chegarasi: (1) CPU/xotiradan boshqa metrika uchun adapter o'rnatish va sozlash kerak, (2) `minReplicas` kamida 1, nolga tusha olmaydi. KEDA (Kubernetes Event-driven Autoscaling, CNCF) ikkalasini yechadi.

KEDA HPA'ni almashtirmaydi, uni boshqaradi:

- **0 <-> 1**: KEDA operator'i manbani `pollingInterval` (default 30 s) bilan tekshiradi. Hodisa bor bo'lsa Deployment'ni 0 dan `minReplicaCount` ga ko'taradi, oxirgi faol holatdan `cooldownPeriod` (default 300 s) o'tgach 0 ga tushiradi.
- **1 <-> N**: KEDA `keda-hpa-<name>` nomli oddiy HPA yaratadi va unga external metrics API orqali metrika beradi. Qolganini HPA controller qiladi.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: { name: worker }
spec:
  scaleTargetRef: { name: worker }
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
    - type: redis
      metadata:
        address: redis.default.svc.cluster.local:6379
        listName: jobs
        listLength: "10"
```

- `listLength: "10"`: har replica'ga o'rtacha 10 ta xabar maqsad. Navbatda 95 ta bo'lsa `ceil(95/10) = 10` replica.
- **Scaler'lar**: o'nlab manba (Redis, RabbitMQ, Kafka, AWS SQS, Prometheus, cron va boshqalar). Prometheus scaler: `serverAddress`, `query` (PromQL), `threshold`. Bu mavjud metrikalaringiz (observability moduli) bo'yicha masshtablashning eng qisqa yo'li.
- `activation...` qiymatlari (masalan `activationListLength`) 0 dan 1 ga o'tish chegarasini alohida belgilaydi.
- Parol va token'lar `TriggerAuthentication` obyekti orqali Secret'dan beriladi, `ScaledObject` ichida ochiq yozilmaydi.
- `advanced.horizontalPodAutoscalerConfig.behavior` HPA `behavior` ni uzatadi.
- `ScaledJob`: har hodisa uchun Deployment emas, Job yaratadi (uzoq, uzib bo'lmaydigan ishlar uchun).
- Bitta workload'ga `ScaledObject` va o'zingiz yozgan HPA birga qo'yilmaydi.

**Scale to zero narxi**: birinchi so'rov yoki xabar cold start'ni kutadi (Pod yaratish, image pull, start). Navbat worker'lari uchun bu muammo emas, xabar navbatda kutadi. Sinxron HTTP uchun nolga tushganda so'rovni ushlab turadigan proxy kerak (KEDA HTTP add-on kabi), aks holda mijoz xato oladi.

## 7. Yuk sinovi

Autoscaling'ni yuk ostida ko'rmasdan sozlab bo'lmaydi. k6 skripti bosqichlar bilan (ramp-up, plato, ramp-down) yuk beradi va latency foizlarini chiqaradi. Kuzatish uchun parallel terminallar:

```bash
kubectl get hpa web -w
kubectl get pods -l app=web -w
kubectl top pods -l app=web
```

Qaraladigan narsalar: yuk boshlanganidan birinchi yangi Pod `Ready` bo'lguncha qancha vaqt, shu oraliqda latency va xato darajasi, yuk tugagach replica'lar qachon kamaydi, kamayish paytida xato bo'ldimi. Grafana'da (observability moduli) replica soni, CPU va p95 latency'ni bitta panelda ko'rish eng ko'p narsa o'rgatadi.

## Tuzoqlar

- Requests'siz Deployment'ga HPA: `<unknown>`, hech narsa ishlamaydi.
- Requests haqiqiy iste'moldan ancha katta: utilization doim past, HPA hech qachon scale qilmaydi. Juda kichik: doim maksimal replica.
- HPA boshqaradigan Deployment'da `replicas` git'da: har sync replica sonini qaytaradi.
- I/O-bound servisni CPU bo'yicha masshtablash: latency o'sadi, CPU past, HPA jim.
- Xotira bo'yicha HPA: faqat yuqoriga.
- `maxReplicas` ni baza ulanish limiti yoki node sig'imini o'ylamasdan qo'yish: autoscaling nosozlikni kuchaytiradi.
- HPA va VPA'ni bir xil resurs metrikasida birga ishlatish.
- Node autoscaler bor deb `Pending` Pod'larni e'tiborsiz qoldirish: node'ning tayyor bo'lishi daqiqalar, keskin yukda bu juda uzoq.
- Sinxron HTTP servisni proxy'siz nolga tushirish.
- Scale-down'da graceful shutdown yo'q: har kechqurun bir oz 502.
- Tor PDB va `safe-to-evict: "false"` annotation'lari tufayli node'lar hech qachon bo'shamaydi va to'lov davom etadi.

## Manbalar

- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/ – HPA, algoritm tafsilotlari
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/ – HPA amaliy qo'llanma
- https://github.com/kubernetes-sigs/metrics-server – metrics-server
- https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler – VPA
- https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/ – in-place resize
- https://kubernetes.io/docs/concepts/cluster-administration/node-autoscaling/ – node autoscaling umumiy
- https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md – Cluster Autoscaler FAQ
- https://karpenter.sh/docs/ – Karpenter
- https://keda.sh/docs/latest/concepts/ – KEDA tushunchalari
- https://keda.sh/docs/latest/reference/scaledobject-spec/ – ScaledObject spec
- https://keda.sh/docs/latest/scalers/ – scaler'lar ro'yxati
- https://grafana.com/docs/k6/latest/ – k6

---

## Vazifalar

Barchasini `kubernetes/14-autoscaling/` da bajaring (`make new m=kubernetes n=14 name=autoscaling`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar va yuk skriptlari (`load.js`) shu papkada. Sinov ilovasi: CPU yuklaydigan endpoint'i bor o'z ilovangiz yoki HPA qo'llanmasidagi `registry.k8s.io/hpa-example` image'i.

### A. Metrikalar

1. **metrics-server.** metrics-server'ni o'rnating. Patch'dan oldin Pod log'idagi xatoni yozing, keyin tuzating. `kubectl top nodes`, `kubectl top pods -A` va `kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes` chiqishini ko'ring. `kubectl get apiservices | grep metrics` nimani ko'rsatadi?

2. **Requests as the basis.** Sinov ilovasini CPU request 200m bilan deploy qiling va doimiy yuk bering. `kubectl top pod` dagi qiymatdan utilization'ni qo'lda hisoblang. Request'ni 100m va 500m ga o'zgartirib, o'sha yuk ostida utilization qanday o'zgarishini jadvalga yozing.

### B. HPA

3. **First HPA.** CPU 50% target, min 1, max 10 bilan `autoscaling/v2` HPA yozing (`kubectl autoscale` emas, manifest). Cluster ichidan yuk bering va `kubectl get hpa -w` chiqishini vaqt bilan yozing: `TARGETS` va `REPLICAS` qanday o'zgardi?

4. **Verify the formula.** 3-vazifadagi kuzatuvdan uch lahzani oling va har birida `desiredReplicas` ni formula bilan qo'lda hisoblang. HPA qarori bilan mos keldimi? Mos kelmagan joyda sababini (tolerance, ready bo'lmagan Pod'lar, policy) toping.

5. **Scale-down timing.** Yukni to'xtating va replica'lar qachon kamaya boshlaganini o'lchang. Nima uchun darhol emas? `kubectl describe hpa` event'larini yozing.

6. **HPA without requests.** Deployment'dan `resources.requests` ni olib tashlang. HPA holati va `describe` dagi xabar qanday? Ikki konteynerli Pod'da faqat bittasida request bo'lsa-chi? `ContainerResource` metrika turi bu yerda nimani yechadi?

7. **Tune behavior.** `behavior` bilan ikki profil yozing: (a) agressiv: scale-up cheklovsiz, scale-down 60 soniya window; (b) ehtiyotkor: scale-up daqiqasiga ko'pi bilan 2 Pod, scale-down 10 daqiqada 10%. Bir xil "30 soniya yuk, 30 soniya tinch" tebranuvchi yuk ostida ikkalasining replica grafigini solishtiring.

8. **replicas conflict.** Manifestda `replicas: 2` qoldirib, HPA 6 ga ko'targan paytda `kubectl apply` ni takrorlang. Nima bo'ldi? Buni GitOps'da (10-dars) qanday hal qilasiz? Ikki usulni yozing.

9. **Wrong signal.** Har so'rovda 200 ms `sleep` qiladigan (CPU ishlatmaydigan) endpoint'ga yuk bering. Latency va CPU utilization bilan nima bo'ldi, HPA nima qildi? Bu servis uchun qaysi metrika to'g'ri bo'lar edi?

10. **Load test with k6.** k6 skripti yozing: 1 daqiqa ramp-up, 3 daqiqa plato, 1 daqiqa ramp-down. Cluster ichida Pod sifatida ishga tushiring. HPA'siz (1 replica) va HPA bilan p95 latency va xato foizini solishtiring. Birinchi yangi Pod `Ready` bo'lguncha qancha vaqt o'tdi va shu oraliqda latency qanday edi?

### C. VPA va node'lar

11. **VPA recommendations.** VPA'ni rasmiy repo bo'yicha o'rnating va sinov ilovasiga `updateMode: "Off"` bilan VPA qo'ying. Yuk ostida bir muddat ishlatib, `kubectl describe vpa` dagi `Target`, `Lower Bound`, `Upper Bound` ni yozing. Joriy requests bilan solishtiring. Nima uchun shu Deployment'ga CPU HPA va `Recreate` rejimli VPA'ni birga qo'yib bo'lmaydi?

12. **Pending pods.** HPA `maxReplicas` ni worker'lar sig'imidan katta qiling va yuk bering. `Pending` Pod'larning event'ini yozing. Cluster Autoscaler shu holatda nima qilar edi va nimaga qarab? `kubectl describe node` dagi `Allocated resources` dan qaysi resurs tugaganini ko'rsating.

13. **Node autoscaling on paper.** Kodsiz: 3 node, har biri 4 CPU; har Pod 500m request; HPA 6 dan 30 ga ko'tarmoqchi. Nechta Pod sig'adi (tizim Pod'lari uchun har node'da 500m ajrating), nechta node qo'shiladi, yangi node tayyor bo'lguncha nima bo'ladi? Yuk tushgach node'lar qaysi shartlarda olib tashlanadi, nimalar to'sqinlik qiladi? Cluster Autoscaler va Karpenter bu ssenariyda qanday har xil yo'l tutadi?

### D. KEDA

14. **Install KEDA.** KEDA'ni o'rnating. `keda` namespace'idagi komponentlar va `kubectl get apiservices | grep external.metrics` chiqishini yozing. Bu 2-bo'limdagi jadvalning qaysi qatoriga mos keladi?

15. **Queue-driven scaling.** Redis Deployment va Service, hamda navbatdan bittadan xabar olib 2 soniya "ishlaydigan" worker Deployment (shell sikli yoki o'z kodingiz) yarating. Redis list trigger'li `ScaledObject` yozing (min 0, max 10). 200 ta xabar qo'shing (`LPUSH`) va replica'lar, navbat uzunligi (`LLEN`) qanday o'zgarishini vaqt bilan yozing.

16. **Scale to zero.** Navbat bo'shagach worker qachon nolga tushdi? Bu qaysi parametrga bog'liq? Bitta xabar qo'shing: birinchi Pod'gacha qancha vaqt o'tdi va u nimalardan tashkil topgan? `kubectl get hpa` da KEDA yaratgan HPA'ni toping: undagi `minReplicas` nechaga teng va 0 ga kim tushiradi?

17. **TriggerAuthentication.** Redis'ga parol qo'ying (Secret'dan). Worker va `ScaledObject` ulanishini tuzating: parol `TriggerAuthentication` orqali berilsin. Noto'g'ri parol bilan `ScaledObject` holati va KEDA operator log'ida nima ko'rinadi?

18. **Prometheus scaler.** Cluster'ga Prometheus o'rnating (observability modulidagi usulda) va HTTP servisingizni so'rovlar tezligi (`rate(http_requests_total[1m])` yoki ilovangizdagi mos metrika) bo'yicha Prometheus trigger'i bilan masshtablang. 9-vazifadagi "noto'g'ri signal" servisi endi to'g'ri scale bo'ladimi?

19. **HTTP and zero.** 18-vazifadagi servisga `minReplicaCount: 0` qo'ying va tinch turgandan keyin so'rov yuboring. Nima bo'ldi va nima uchun bu navbat worker'idan farq qiladi? Yechim variantlarini yozing (o'rnatmasdan).

### E. Yig'ma

20. **Autoscaling design.** Ilovangizning uch qismi uchun (HTTP API, navbat worker'i, PostgreSQL) masshtablash rejasini yozing: har biri uchun qaysi asbob, qaysi signal, min va max, `behavior`, PDB va graceful shutdown bilan bog'liqligi, va nima uchun bazani HPA bilan masshtablab bo'lmaydi. API va worker qismlarini amalda sozlab, bitta k6 sinovi ostida ikkalasining ham scale bo'lishini ko'rsating.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. README'da har sinov uchun vaqt chizig'i (yuk, replica soni, latency) bor.
3. `kind delete cluster --name scale` bajarilgan.
4. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- HPA utilization'ni nimaga nisbatan hisoblaydi? Request yo'q bo'lsa nima bo'ladi?
- 5 Pod, target 50%, joriy 80%: HPA nechta replica xohlaydi?
- Scale-up va scale-down nima uchun default'da har xil tezlikda?
- CPU qaysi turdagi servis uchun noto'g'ri masshtablash signali?
- HPA va VPA'ni qachon birga ishlatib bo'lmaydi va nima uchun?
- Cluster Autoscaler node qo'shish qarorini nimaga qarab qabul qiladi? Node'lar CPU bo'yicha to'la, lekin `Pending` Pod yo'q bo'lsa nima qiladi?
- KEDA HPA bilan qanday munosabatda? 0 dan 1 ga kim ko'taradi?
- Scale to zero qaysi workload uchun xavfsiz, qaysi biri uchun qo'shimcha komponent kerak?
- HPA boshqaradigan Deployment manifestida `replicas` nima uchun bo'lmasligi kerak?
