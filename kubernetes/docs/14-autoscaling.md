# 14-dars: Autoscaling: HPA, Cluster Autoscaler, KEDA

Maqsad: hozirgacha replica sonini manifestga qo'lda yozdingiz (`replicas: 3`). Real yuk esa o'zgaradi: kunduzi ko'p, kechasi kam, kampaniya paytida keskin. Bu darsda avtomatik masshtablash (autoscaling, yukka qarab resursni o'zi ko'paytirish va kamaytirish) uch o'q bo'yicha ko'riladi: Pod'lar soni (HorizontalPodAutoscaler, metrics-server, `behavior`), Pod hajmi (VerticalPodAutoscaler, umumiy ko'rinish), node'lar soni (Cluster Autoscaler va Karpenter, tushuncha darajasida), hamda hodisaga asoslangan masshtablash (KEDA: navbat uzunligi yoki Prometheus so'rovi bo'yicha, nolgacha tushish bilan). 4-darsdagi requests bu yerda markaziy rolga chiqadi: hamma autoscaler requests'ga tayanadi. 11-darsdagi PDB va graceful shutdown scale-down xavfsiz bo'lishi uchun kerak, 15-darsda xarajat aynan shu mexanizmlar bilan kamaytiriladi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–5 bo'limlar, "Birga bajaramiz" va A, B guruhlar (1–6); ikkinchi kun B guruh oxiri (7–10), 6–7 bo'limlar va C guruh; uchinchi kun 8–9 bo'limlar, D va E guruhlar, README. Diqqat: HPA formulasi va "utilization requests'ga nisbatan" ekanligi, scale-up va scale-down nima uchun har xil tezlikda, CPU qachon noto'g'ri signal, HPA, VPA va node autoscaler bir-biri bilan qanday bog'lanadi.

## Qanday o'qish kerak

Autoscaling statik narsa emas, vaqt ichida sodir bo'ladigan jarayon. Shuning uchun har bo'limdagi misolni ishga tushirganda kamida ikki terminal oching: birida yuk, ikkinchisida `kubectl get hpa -w` yoki `kubectl get pods -w`. Har qatorga vaqt qo'shib yozib boring, aks holda "qachon" degan savolga javob bera olmaysiz:

```bash
kubectl get hpa -w | while read -r line; do echo "$(date +%T) $line"; done
```

Bu sikl bash va zsh'da bir xil ishlaydi. Darsdagi natijalarda Pod nomlarining tasodifiy qismi, vaqt, foizlar va node nomlari sizda boshqacha bo'ladi, bunday joylar `<...>` bilan belgilangan. Raqamlar ham taxminan mos keladi: kind node'lari bitta mashina CPU'sini bo'lishadi, shuning uchun bir xil yuk ikki mashinada har xil utilization beradi. Har natijadan keyin "bu qarorni kim qabul qildi va qaysi raqamga qarab" deb so'rang: HPA controller, scheduler, KEDA operator yoki node autoscaler.

## Laboratoriya

Hammasi host'dagi kind klasterida, alohida `scale` nomi bilan (1 control-plane + 2 worker, 2-darsdagi `kind-multi.yaml`). Alohida klaster kerak, chunki darsda metrics-server, VPA va KEDA o'rnatiladi va bular boshqa darslar klasterini ifloslamasin. Multipass VM'lar kerak emas: tizimga hech narsa o'rnatilmaydi, faqat klaster ichiga.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `kind`, `kubectl`, `helm` | 2- va 8-darsda o'rnatilgan, `linux-amd64` binary'lar | 2- va 8-darsda `brew install` bilan, `arm64` |
| kind node'lari qayerda | host Docker Engine'ida | Docker Desktop'ning yashirin Linux VM'ida |
| `kubectl top nodes` dagi CPU | har node host'ning barcha yadrolarini "o'ziniki" deb ko'rsatadi | har node Docker Desktop VM'iga berilgan yadrolarni ko'rsatadi (Settings, Resources). Kamida 4 CPU va 6 GB bering |
| Yuk generatori | klaster ichidagi Pod (`busybox:1.36`, `grafana/k6:1.0.0`) | xuddi shu, ikkala image `arm64` uchun ham bor |
| `registry.k8s.io/hpa-example` | `amd64` varianti bor | `docker manifest inspect registry.k8s.io/hpa-example` bilan `arm64` borligini tekshiring; bo'lmasa o'z ilovangizni ishlating |
| `watch` buyrug'i | o'rnatilgan | yo'q, `brew install watch` yoki `kubectl ... -w` |
| Node autoscaling | kind'da yo'q (node'lar qo'lda yaratilgan konteynerlar) | xuddi shunday |

Klasterni yaratish va metrics-server o'rnatish:

```bash
kind create cluster --name scale --config kubernetes/02-cluster-setup/kind-multi.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.0/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes
```

Versiya ataylab qotirilgan (`v0.8.0`), `latest` emas: release sahifasida (https://github.com/kubernetes-sigs/metrics-server/releases) yangisi bo'lsa, shuni aniq yozing. `--kubelet-insecure-tls` nima uchun kerakligini 2-bo'lim va 1-vazifada ko'rasiz; u faqat lab uchun. k3s'da metrics-server oldindan o'rnatilgan (2-dars).

KEDA (D guruhdan oldin, Helm 8-darsda o'tilgan, rasmiy yo'riqnoma https://keda.sh/docs/latest/deploy/):

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm search repo kedacore/keda --versions | head -5
helm install keda kedacore/keda --namespace keda --create-namespace --version <CHART_VERSION>
```

`<CHART_VERSION>` o'rniga `helm search` chiqargan eng yangi barqaror versiyani yozing va README'da qaysi versiya ekanini qayd qiling.

- **Yuk qayerdan beriladi**: har doim klaster ichidagi Pod'dan, Service nomiga. `kubectl port-forward` bitta Pod'ga ulanadi va yukni taqsimlamaydi (6-dars), HPA sinovi uchun yaramaydi.
- **Node autoscaling**: kind'da ishlamaydi, u qism nazariy va `Pending` Pod'lar orqali taqlid qilinadi (7-bo'lim).
- **Ikkinchi mashinada tiklash**: klaster holati git orqali ko'chmaydi. Boshqa mashinada yuqoridagi bloklarni qayta bajaring, keyin ish papkasidagi manifestlarni `kubectl apply -f` qiling. HPA tarixi, VPA tavsiyalari va KEDA holati noldan boshlanadi: VPA tavsiyasi (11-vazifa) yuk ostida kamida 15–20 daqiqa yig'ilishi kerak, shuning uchun C guruhni bitta mashinada boshlab tugating.
- **Tozalash**: `kind delete cluster --name scale`. Klaster ichidagi hamma narsa (VPA, KEDA, Prometheus) u bilan birga o'chadi.

---

## 1. Uch o'q va requests zanjiri

### Bu nima

"Masshtablash" uch xil narsani anglatishi mumkin, va har biri uchun alohida asbob bor:

| Nima o'zgaradi | Asbob | Signal | Tezlik |
|----------------|-------|--------|--------|
| Pod'lar soni (horizontal) | HPA, KEDA | metrika (CPU, navbat, RPS) | soniyalar, daqiqalar |
| Pod hajmi, ya'ni requests (vertical) | VPA | tarixiy iste'mol | soatlar, kunlar |
| Node'lar soni | Cluster Autoscaler, Karpenter | joylashmay qolgan (`Pending`) Pod'lar | daqiqalar |

Horizontal masshtablash bir xil nusxalarni ko'paytirish, vertical esa bitta nusxaga ko'proq CPU va xotira berish. Node.js tajribangizdan: `pm2 start app.js -i 4` to'rtta jarayonni qo'lda belgilaydi; HPA aynan shu raqamni yukka qarab o'zi o'zgartiradi.

### Mexanizm: zanjir

Yuk ortadi -> HPA Pod qo'shadi -> yangi Pod'larga node'larda joy yetmaydi, ular `Pending` -> node autoscaler node qo'shadi -> Pod'lar joylashadi. Teskari yo'nalishda: HPA Pod'larni kamaytiradi -> node'lar bo'shaydi -> node autoscaler ularni olib tashlaydi.

Zanjirning har bo'g'ini **requests** ga (4-dars: scheduler hisoblaydigan kafolatlangan resurs buyurtmasi) qaraydi:

- HPA utilization'ni requests'ga nisbatan hisoblaydi;
- scheduler Pod'ni requests sig'adigan node'ga qo'yadi;
- node autoscaler "Pod requests'i hech qaysi node'ga sig'madi" degan faktdan node qo'shadi;
- VPA requests'ning o'zini tuzatadi.

Requests noto'g'ri bo'lsa, zanjirning hamma bo'g'ini noto'g'ri ishlaydi.

### Misol

```
$ kubectl describe node scale-worker | grep -A 8 'Allocated resources'
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                100m (1%)    100m (1%)
  memory             50Mi (0%)    50Mi (0%)
  ephemeral-storage  0 (0%)       0 (0%)
  hugepages-1Gi      0 (0%)       0 (0%)
```

`Requests` ustuni shu node'dagi barcha Pod'lar requests'ining yig'indisi; foiz `Allocatable` ga (4-dars) nisbatan. Bu raqamni scheduler va node autoscaler ko'radi. Haqiqiy iste'mol bu yerda yo'q: u `kubectl top` da (2-bo'lim). `100m` bu worker'dagi kindnet DaemonSet Pod'ining request'i. Foizning kichikligi kind xususiyati: node butun mashina CPU'sini o'ziniki deb hisoblaydi.

### Real ishda qachon kerak

- "Nima uchun scale bo'lmadi?" degan savolda birinchi navbatda requests tekshiriladi.
- Yangi servisni production'ga chiqarishda: avval to'g'ri requests (yuk sinovi yoki VPA tavsiyasi), keyin HPA, keyin node autoscaler limitlari.

### Nima uchun shunday

Kubernetes haqiqiy iste'molni emas, deklaratsiyani (requests) asos qilib oladi, chunki iste'mol har soniyada o'zgaradi, deklaratsiya esa barqaror va oldindan ma'lum. Joylashtirish qarori barqaror raqamga tayanmasa, scheduler bitta tebranish bilan node'ni to'ldirib yuborardi. Muqobil yondashuv (iste'molga qarab joylashtirish) Borg va ba'zi HPC tizimlarida sinab ko'rilgan, lekin u murakkab va oldindan aytib bo'lmaydigan xatti-harakat beradi.

## 2. metrics-server va Metrics API

### Bu nima

HPA metrikani o'zi yig'maydi, Kubernetes API'dan o'qiydi. API server'ga qo'shimcha API guruhlari APIService (API server so'rovni boshqa servisga uzatishini bildiradigan obyekt) orqali ulanadi:

| API | Kim beradi | Nima |
|-----|-----------|------|
| `metrics.k8s.io` | metrics-server | Pod va node'ning joriy CPU va xotirasi (`kubectl top`) |
| `custom.metrics.k8s.io` | adapter (prometheus-adapter va boshqalar) | klaster obyektlariga bog'liq metrikalar (Pod'dagi RPS) |
| `external.metrics.k8s.io` | adapter (KEDA) | klasterdan tashqaridagi metrikalar (navbat uzunligi) |

### Mexanizm

metrics-server har node'dagi kubelet'ning `/metrics/resource` endpoint'idan (port 10250) har 15 soniyada joriy qiymatni oladi va xotirada ushlaydi. Tarix saqlamaydi: faqat oxirgi qiymat. Kubelet o'z sertifikati bilan HTTPS beradi. kind'da kubelet sertifikati o'z-o'zidan imzolangan va metrics-server uni tasdiqlay olmaydi, shuning uchun lab'da `--kubelet-insecure-tls` bilan tekshiruv o'chiriladi. Production klasterda buning o'rniga kubelet sertifikatlari klaster CA'si bilan imzolanadi.

`kubectl top` va HPA metrics-server'ga to'g'ridan-to'g'ri emas, API server orqali murojaat qiladi: `kubectl` -> API server -> APIService -> metrics-server Service.

### Misol

```
$ kubectl api-resources --api-group=metrics.k8s.io
NAME    SHORTNAMES   APIVERSION               NAMESPACED   KIND
nodes                metrics.k8s.io/v1beta1   false        NodeMetrics
pods                 metrics.k8s.io/v1beta1   true         PodMetrics
$ kubectl top pods -n kube-system --sort-by=cpu | head -4
NAME                                          CPU(cores)   MEMORY(bytes)
kube-apiserver-scale-control-plane            <45>m        <260>Mi
etcd-scale-control-plane                      <20>m        <40>Mi
kube-controller-manager-scale-control-plane   <15>m        <50>Mi
```

Birinchi buyruq: `metrics.k8s.io` guruhida ikki resurs bor, `NodeMetrics` (namespace'siz) va `PodMetrics` (namespace'li). Ular etcd'da saqlanmaydi, har so'rovda metrics-server javob beradi. Ikkinchi buyruq: `CPU(cores)` millicore'da (`45m` = yadroning 4.5%), `MEMORY(bytes)` working set (jarayon haqiqatda ushlab turgan xotira). Bu yerda foiz yo'q: Pod uchun foizni faqat HPA hisoblaydi, requests'ga nisbatan.

### Real ishda qachon kerak

- `kubectl top` tezkor diagnostika: qaysi Pod ko'p yeyapti.
- metrics-server ishlamasa hamma CPU/xotira HPA'lari bir vaqtda "ko'r" bo'ladi. Shuning uchun uning o'zi ham monitoring qilinadi.
- metrics-server monitoring emas: tarix, grafik va alert Prometheus ishi (observability moduli).

### Nima uchun shunday

Ilgari Kubernetes'da Heapster bor edi, u metrikalarni yig'ib, saqlab, tashqi bazalarga yozardi va har backend uchun alohida kod talab qilardi. Uni ikkiga bo'lishdi: kichik va tarixsiz metrics-server (faqat autoscaling uchun "hozir qancha") va ixtiyoriy monitoring tizimi. API'larning uchga bo'linishi esa HPA'ni manbadan mustaqil qildi: HPA faqat API'ni biladi, orqasida kim turgani muhim emas.

## 3. HorizontalPodAutoscaler: algoritm

### Bu nima

HPA (HorizontalPodAutoscaler) bu obyekt va controller: obyekt maqsadni yozadi (qaysi Deployment, qaysi metrika, qaysi qiymat), kube-controller-manager ichidagi HPA controller esa davriy ravishda replica sonini hisoblab, Deployment'ning `scale` subresource'iga yozadi.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: api}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: api}
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 70}
```

### Mexanizm

Controller har 15 soniyada (default) hisoblaydi:

```
desiredReplicas = ceil( currentReplicas * currentMetricValue / targetMetricValue )
```

- `Utilization` foiz, **requests'ga nisbatan**: Pod'ning CPU request'i 200m, iste'moli 180m bo'lsa utilization 90%. Limit bu yerda ishtirok etmaydi.
- `currentMetricValue` barcha Pod'lar bo'yicha o'rtacha.
- Request'i yo'q konteyner uchun utilization hisoblab bo'lmaydi, HPA `<unknown>` ko'rsatadi va ishlamaydi.
- Nisbat (`current / target`) 1.0 ga yaqin bo'lsa (default tolerance 10%, ya'ni 0.9–1.1) hech narsa qilinmaydi, bu tebranishni kamaytiradi.
- Bir nechta metrika berilsa har biri uchun hisoblanadi va **eng kattasi** olinadi.
- Hali `Ready` bo'lmagan Pod'lar va metrikasi yo'q Pod'lar ehtiyotkorlik bilan hisoblanadi: scale-up'da ular 0% deb (qaror bo'rttirilmasin), scale-down'da metrikasi yo'qlari 100% deb (keraksiz kamaytirilmasin) qaraladi.
- Natija `minReplicas` va `maxReplicas` oralig'iga qisiladi.

Hisoblash misoli: 4 Pod, target 60%, joriy o'rtacha 90%: `ceil(4 * 90 / 60) = 6`. Xuddi shu 4 Pod 63% bo'lsa: `63 / 60 = 1.05`, tolerance ichida, hech narsa o'zgarmaydi.

### Misol

```
$ kubectl get hpa api
NAME   REFERENCE        TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
api    Deployment/api   cpu: 84%/70%   2         8         3          6m
```

`REFERENCE` qaysi obyekt boshqarilayotgani. `TARGETS` `joriy/maqsad`: o'rtacha 84%, maqsad 70%. `REPLICAS` hozirgi son, keyingi siklda `ceil(3 * 84 / 70) = ceil(3.6) = 4` bo'ladi. Metrika olinmasa `TARGETS` da `cpu: <unknown>/70%` ko'rinadi. kubectl'ning eski versiyalari ustunni `84%/70%` shaklida, metrika nomisiz chiqaradi.

### Real ishda qachon kerak

- HPA nima uchun shuncha Pod qilganini tushuntirish uchun formulani qo'lda takrorlash kerak bo'ladi (4-vazifa).
- `maxReplicas` ni hisoblashda: eng yomon holatda o'rtacha utilization qancha bo'lishi mumkin va bunda qancha Pod kerak.

### Nima uchun shunday

Formula proporsional: "Pod'lar ikki barobar ko'p ishlayapti, demak ikki barobar ko'p Pod kerak". Bu chiziqli masshtablanadigan stateless servislar uchun yaxshi taxmin. Tolerance va ehtiyotkor hisob controller'ni "shovqin" ustida harakat qilishdan saqlaydi: 15 soniyalik metrika tabiatan tebranadi, va har tebranishga reaksiya flapping (replica sonining to'xtovsiz o'zgarishi) beradi. Limit emas request asos qilingani 1-bo'limdagi bilan bir xil sabab: request barqaror va har Pod'da ma'lum.

## 4. HPA: metrika turlari va signal tanlash

### Bu nima

`metrics` ro'yxatidagi har element `type` ga ega. Signal (masshtablash qaroriga asos bo'ladigan metrika) to'g'ri tanlanmasa, eng yaxshi sozlangan HPA ham foydasiz.

| `type` | Manba | Misol |
|--------|-------|-------|
| `Resource` | metrics-server | Pod bo'yicha o'rtacha CPU yoki xotira |
| `ContainerResource` | metrics-server | faqat bitta konteyner (sidecar hisobni buzmasin) |
| `Pods` | custom metrics | har Pod'dagi o'rtacha `http_requests_per_second` |
| `Object` | custom metrics | boshqa obyekt metrikasi (Ingress RPS) |
| `External` | external metrics | navbat uzunligi, cloud metrikasi |

### Mexanizm

`Resource` turida Pod utilization'i Pod'dagi **barcha** konteynerlar yig'indisi bo'yicha hisoblanadi: iste'mol yig'indisi / requests yig'indisi. Pod'da sidecar (4-dars) bo'lsa, uning iste'moli asosiy ilova signaliga aralashadi. `ContainerResource` bitta konteyner nomini beradi:

```yaml
  - type: ContainerResource
    containerResource:
      name: cpu
      container: app
      target: {type: Utilization, averageUtilization: 70}
```

**CPU har doim ham to'g'ri signal emas.**

- I/O kutadigan servis (bazaga so'rov, tashqi API) yuk ostida CPU'ni kam ishlatadi, latency esa o'sadi. Node.js'dagi `await fetch(...)` aynan shunday: event loop kutadi, CPU bo'sh.
- Navbatdan o'qiydigan worker uchun to'g'ri signal navbat uzunligi yoki navbatdagi xabarning yoshi.
- Xotira odatda yomon signal: ko'p runtime'lar (V8, JVM) xotirani operatsion tizimga qaytarishga shoshilmaydi, scale-up bo'ladi, scale-down deyarli hech qachon.
- Node.js asosiy oqimi bitta yadroni ishlatadi. Konteynerga `cpu: 2` request berilsa, utilization 50% dan oshmaydi va 70% target'ga hech qachon yetmaydi.

### Misol

```
$ kubectl get hpa api -o jsonpath='{.status.currentMetrics[0].resource.current}{"\n"}'
{"averageUtilization":84,"averageValue":"168m"}
```

`status.currentMetrics` HPA ko'rgan oxirgi qiymat: foizda (`averageUtilization: 84`) va absolyut qiymatda (`averageValue: 168m`, bitta Pod o'rtacha 168 millicore). Bundan request'ni ham chiqarish mumkin: `168 / 0.84 = 200m`. Bu jsonpath barcha metrika turlari uchun bir xil joyda yotmaydi: `Pods` turida `.pods.current`, `External` da `.external.current`.

### Real ishda qachon kerak

- Yangi servisga HPA qo'yishdan oldin: yuk sinovida qaysi resurs birinchi tugaydi va latency qaysi metrika bilan birga o'sadi.
- Service mesh yoki log agent sidecar'i bor Pod'larda `ContainerResource`.
- I/O-bound API uchun RPS yoki in-flight so'rovlar soni (8-bo'lim, KEDA Prometheus scaler).

### Nima uchun shunday

CPU default signal bo'lib qolgani tarixiy: u har klasterda metrics-server bilan tayyor, qo'shimcha infratuzilma talab qilmaydi. `autoscaling/v1` faqat CPU'ni bilardi; `autoscaling/v2` (hozirgi barqaror versiya) bir nechta metrika va custom/external turlarni qo'shdi, chunki amalda ko'p servislar uchun CPU yaxshi proxy emasligi ayon bo'ldi. Hozir ham `kubectl autoscale` buyrug'i faqat CPU HPA yaratadi, shuning uchun manifest bilan yozish odat.

## 5. HPA: behavior va atrofidagi shartlar

### Bu nima

`spec.behavior` HPA qanchalik tez va qancha qadam bilan o'zgarishini belgilaydi. Formula "qancha kerak" deydi, `behavior` "qanchalik tez u yerga borish mumkin" deydi.

### Mexanizm

Yuk tebransa replica soni ham tebranadi. Default'lar assimetrik:

- **scale-up**: stabilization window 0, ya'ni darhol; har 15 soniyada ko'pi bilan 100% yoki 4 Pod (qaysi biri ko'p bo'lsa) qo'shiladi;
- **scale-down**: stabilization window 300 soniya, ya'ni oxirgi 5 daqiqadagi **eng yuqori** tavsiya olinadi; shu davr ichida bitta keskin cho'qqi bo'lsa, kamaytirish kechikadi.

```yaml
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 600
      policies:
      - {type: Pods, value: 1, periodSeconds: 120}
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - {type: Percent, value: 100, periodSeconds: 60}
```

`policies` bir davr (`periodSeconds`) ichida qancha o'zgarish mumkinligini cheklaydi, `Pods` (dona) yoki `Percent` (joriy sondan foiz). Bir nechta policy bo'lsa `selectPolicy` tanlaydi: `Max` (default, eng katta o'zgarishga ruxsat beradigani), `Min` yoki `Disabled` (shu yo'nalishda umuman o'zgartirmaslik). Yuqoridagi misol: kamaytirish 10 daqiqa barqarorlikdan keyin, har 2 daqiqada bittadan; oshirish 30 soniya kutib, daqiqasiga ko'pi bilan ikki barobar.

Mantiq: tez o'sish (mijoz kutmasin), sekin kamayish (yuk qaytsa Pod'lar tayyor tursin).

### HPA atrofidagi shartlar

- **Ishga tushish vaqti.** Yangi Pod image pull, start va readiness'dan (4-dars) o'tguncha yuk ko'tarmaydi. Start 60 soniya bo'lsa HPA har doim bir daqiqa kechikadi. Target'ni 100% emas, 60–70% qo'yish shu zaxira uchun.
- **`replicas` maydoni.** HPA boshqaradigan Deployment manifestida `replicas` bo'lmasin: har `kubectl apply` yoki GitOps sync (10-dars) uni manifestdagi songa qaytaradi.
- **`minReplicas`** HA uchun kamida 2 (11-dars). `maxReplicas` byudjet va quyi tizimlar (baza ulanishlari soni) chegarasi.
- **Scale-down ham uzilish.** Pod'lar o'chiriladi; graceful shutdown (4- va 11-dars) bo'lmasa har scale-down'da xato so'rovlar.

### Misol

```
$ kubectl describe hpa api
...
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  recommended size matches current size
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  True    TooManyReplicas   the desired replica count is more than the maximum replica count
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  4m    horizontal-pod-autoscaler  New size: 8; reason: cpu resource utilization (percentage of request) above target
```

Uchta condition qatorma-qator: `AbleToScale True` controller hozir o'zgartira oladi (policy yoki stabilization uni to'xtatsa bu yerda `BackoffBoth`, `BackoffDownscale` kabi sabab chiqadi). `ScalingActive True` metrika olindi va hisob ishladi; `False` bo'lsa xabar sababni aytadi (metrika yo'q, request yo'q). `ScalingLimited True TooManyReplicas`: formula 8 dan ko'p so'radi, lekin `maxReplicas` cheklab qo'ydi. Bu signal: yo `maxReplicas` past, yo Pod'lar samarasiz. Event'da har o'zgarish va uning sababi yoziladi.

### Real ishda qachon kerak

- Har kuni kechqurun bir oz 502 bo'lsa: scale-down va graceful shutdown.
- Replica soni har bir necha daqiqada sakrab tursa: `scaleDown.stabilizationWindowSeconds` va policy.
- Keskin kampaniya trafigida: `scaleUp` policy'si yetarlicha agressivmi.

### Nima uchun shunday

Asimmetriya xatolar narxining asimmetriyasidan kelib chiqadi: ortiqcha Pod bir necha daqiqa pul turadi, yetishmagan Pod esa mijozga xato yoki sekin javob. `behavior` `autoscaling/v2` da paydo bo'lgan; undan oldin bu sozlamalar butun klaster uchun bitta kube-controller-manager flag'i edi va har servis uchun alohida tanlab bo'lmasdi.

## 6. VerticalPodAutoscaler

### Bu nima

VPA (VerticalPodAutoscaler) replica sonini emas, Pod'ning requests'ini (va proporsional ravishda limits'ini) o'zgartiradi. U Kubernetes tarkibida emas, `kubernetes/autoscaler` repo'sidan alohida o'rnatiladi va o'z CRD'si (CustomResourceDefinition, Kubernetes'ga yangi obyekt turini qo'shadigan ta'rif) bilan keladi.

### Mexanizm

Uch komponent:

- **recommender**: metrics-server'dan iste'molni kuzatib, tarixiy taqsimot asosida tavsiya hisoblaydi;
- **updater**: tavsiyadan juda uzoqlashgan Pod'larni evict qiladi (yoki in-place o'zgartiradi);
- **admission controller**: yangi yaratilayotgan Pod'ga tavsiya etilgan requests'ni yozadi (mutating webhook, API server so'rovni saqlashdan oldin o'zgartirishga ruxsat beradigan mexanizm).

| `updateMode` | Xatti-harakat |
|--------------|---------------|
| `Off` | faqat tavsiya (`kubectl describe vpa`), hech narsa o'zgarmaydi |
| `Initial` | faqat Pod yaratilganda qo'llaydi |
| `Recreate` | Pod'ni evict qilib yangi requests bilan qayta yaratadi |
| `InPlaceOrRecreate` | avval Pod'ni restart'siz o'zgartirishga urinadi (VPA'ning yangi versiyalarida) |

Kubernetes'da Pod resurslarini restart'siz o'zgartirish (in-place resize, `kubectl patch --subresource=resize`) 1.35 dan stable, VPA shundan foydalanadi.

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata: {name: api}
spec:
  targetRef: {apiVersion: apps/v1, kind: Deployment, name: api}
  updatePolicy: {updateMode: "Off"}
```

### Misol

```
$ kubectl describe vpa api
...
  Recommendation:
    Container Recommendations:
      Container Name:  app
      Lower Bound:
        Cpu:     <25m>
        Memory:  <48Mi>
      Target:
        Cpu:     <63m>
        Memory:  <96Mi>
      Uncapped Target:
        Cpu:     <63m>
        Memory:  <96Mi>
      Upper Bound:
        Cpu:     <410m>
        Memory:  <520Mi>
```

`Target` VPA qo'yadigan requests. `Lower Bound` va `Upper Bound` ishonch oralig'i: request shu oraliqdan chiqsa updater Pod'ni yangilaydi (`Off` rejimda faqat ko'rsatadi). Tarix kam bo'lganda oraliq keng, kuzatish ko'paygan sari torayadi. `Uncapped Target` VPA'ga qo'yilgan cheklovlarsiz (`resourcePolicy` dagi `minAllowed`, `maxAllowed`) tavsiya; cheklov bo'lmasa `Target` bilan bir xil.

### Real ishda qachon kerak

- Eng xavfsiz va eng foydali rejim `Off`: right-sizing (requests'ni haqiqiy iste'molga moslashtirish) uchun tavsiya manbai (15-dars).
- Masshtablab bo'lmaydigan bitta nusxali komponentlar (ichki asboblar, ba'zi operator'lar) uchun `InPlaceOrRecreate`.

### Nima uchun shunday

**HPA va VPA bir xil metrika (CPU yoki xotira) ustida birga ishlatilmaydi**: VPA request'ni oshirsa HPA'ning utilization'i tushadi va u Pod'larni kamaytiradi; Pod kam bo'lsa har biri ko'proq yeydi va VPA yana request'ni oshiradi. Ikkalasi bir-birini quvlaydi. HPA custom metrika bilan, VPA CPU/xotira bilan ishlasa mumkin. VPA'ning Kubernetes'ga kiritilmay alohida loyiha bo'lib qolishining sababi ham shu: Pod'ni o'zgartirish uzoq vaqt faqat qayta yaratish orqali mumkin edi, bu esa ko'p workload'lar uchun qabul qilib bo'lmaydigan uzilish edi.

## 7. Node autoscaling: Cluster Autoscaler va Karpenter

### Bu nima

Node autoscaler klasterdagi node'lar (cloud'da VM'lar) sonini o'zgartiradi. Ikki asosiy implementatsiya: Cluster Autoscaler (eski, ko'p provider'li) va Karpenter (yangiroq). kind'da ikkalasi ham yo'q, chunki node'lar Docker konteynerlari va ularni yaratadigan "cloud API" yo'q.

### Mexanizm: Cluster Autoscaler

Cloud'dagi node group'lar (AWS Auto Scaling Group va o'xshashlari: bir xil turdagi VM'lar guruhi) hajmini o'zgartiradi.

- **Scale-up**: resurs yetmagani uchun joylashmagan `Pending` Pod paydo bo'lsa, qaysi node group'ga node qo'shilsa u joylashishini simulyatsiya qiladi va guruhni kattalashtiradi. Signal CPU yuklanishi emas, **requests bo'yicha joy yetmasligi**. Node'lar 90% yuklangan, lekin hamma Pod joylashgan bo'lsa hech narsa bo'lmaydi.
- **Scale-down**: node'dagi requests yig'indisi chegaradan (default 50%) past bo'lib, bir muddat (default 10 daqiqa) shunday tursa va uning Pod'lari boshqa node'larga sig'sa, node drain (11-dars) qilinib o'chiriladi.
- Scale-down'ni to'xtatadigan narsalar: PDB (11-dars) ruxsat bermasa, controller'siz Pod, local storage ishlatadigan Pod, `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` annotation.
- Yangi node bir necha daqiqada tayyor bo'ladi (VM yaratish, boot, klasterga qo'shilish, image pull). HPA soniyalarda javob bersa ham, node yetmasa Pod'lar shu vaqt `Pending` turadi.

### Mexanizm: Karpenter

Node group'lar bilan emas, to'g'ridan-to'g'ri instance'lar bilan ishlaydi: `Pending` Pod'larning talablariga (requests, nodeSelector, affinity, toleration) qarab eng mos instance turini o'zi tanlaydi va yaratadi. `NodePool` qanday node'lar yaratish mumkinligini (instance turlari, zonalar, spot yoki on-demand, umumiy limit), provider'ga xos NodeClass (AWS'da `EC2NodeClass`) esa image va tarmoq sozlamalarini belgilaydi. Consolidation: Pod'larni zichroq joylash mumkin bo'lsa, node'larni arzonrog'iga almashtiradi yoki olib tashlaydi. AWS'da boshlangan, hozir Kubernetes SIG Autoscaling loyihasi, provider'lar alohida.

Ikkalasi uchun umumiy: requests'siz Pod'lar autoscaler uchun "nol joy" egallaydi, node'lar haddan tashqari to'ladi. Overprovisioning usuli: past priority'li (PriorityClass, 11-dars) "pause" Pod'lar zaxira joyni ushlab turadi; haqiqiy Pod kelganda ular preempt (siqib chiqarilib) bo'ladi, o'zlari `Pending` bo'lib yangi node'ni chaqiradi. Shunda haqiqiy Pod node kutmaydi.

### Misol (kind'da taqlid)

kind'da `Pending` holatini ko'rish oson: node sig'imidan katta requests so'raladi.

```
$ kubectl create deployment big --image=busybox:1.36 -- sleep 3600
deployment.apps/big created
$ kubectl set resources deployment big --requests=cpu=3
deployment.apps/big resource requirements updated
$ kubectl scale deployment big --replicas=6
deployment.apps/big scaled
$ kubectl get pods -l app=big
NAME                   READY   STATUS    RESTARTS   AGE
big-<hash>-<a>         1/1     Running   0          20s
big-<hash>-<b>         1/1     Running   0          20s
big-<hash>-<c>         0/1     Pending   0          20s
...
$ kubectl describe pod big-<hash>-<c> | tail -3
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  20s   default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
```

Natija mashinaga bog'liq: 8 yadroli Zorin'da har worker'ga ikkitadan `3` CPU'li Pod sig'adi, 4 CPU berilgan Docker Desktop'da bittadan. Event qatorma-qator: `0/3 nodes are available` uch node'dan hech biri mos emas; control-plane taint (4-dars) tufayli, ikkala worker `Insufficient cpu`, ya'ni requests yig'indisi `Allocatable` dan oshadi. `preemption` qismi: scheduler past priority'li Pod'larni siqib chiqarib joy ochishga urindi, lekin qurbon topilmadi. Aynan shu event Cluster Autoscaler va Karpenter uchun trigger. Tozalash: `kubectl delete deployment big`.

### Real ishda qachon kerak

- Managed klasterda (EKS, GKE, AKS) node autoscaler deyarli har doim yoqiladi; uning `max` limiti byudjetning oxirgi himoyasi.
- `Pending` Pod'lar uzoq tursa: node group limiti tugaganmi, instance turi bu Pod'ga sig'adimi (masalan 16 CPU so'ragan Pod 8 CPU'li node group'ga hech qachon sig'maydi).
- Node'lar hech qachon kamaymasa: tor PDB va `safe-to-evict: "false"` (15-darsda xarajat sifatida qaytadi).

### Nima uchun shunday

Node autoscaler CPU yuklanishiga emas, scheduling'ga qaraydi, chunki node qo'shishning yagona maqsadi Pod'ni joylashtirish. Node'lar qizib ketgan bo'lsa, bu HPA'ning ishi (ko'proq Pod), node autoscaler esa shu Pod'larga joy topadi. Vazifalarning bunday bo'linishi ikki tizimni bir-biriga bog'lamaydi. Karpenter node group abstraksiyasini olib tashladi, chunki group'lar oldindan tanlangan instance turiga bog'lanadi va har xil talabli Pod'lar uchun ko'p group yaratishga majbur qiladi.

## 8. KEDA

### Bu nima

HPA'ning ikki chegarasi: (1) CPU/xotiradan boshqa metrika uchun adapter o'rnatish va sozlash kerak, (2) `minReplicas` kamida 1, nolga tusha olmaydi. KEDA (Kubernetes Event-driven Autoscaling, CNCF loyihasi) ikkalasini yechadi. Scale to zero (hodisa yo'q paytda Pod'larni butunlay o'chirish) serverless funksiyalarga o'xshash xatti-harakat beradi: frontend dunyosidagi Vercel yoki Lambda funksiyasi so'rov kelmasa hech narsa ishlatmaydi.

### Mexanizm

KEDA HPA'ni almashtirmaydi, uni boshqaradi:

- **0 <-> 1**: KEDA operator'i manbani `pollingInterval` (default 30 s) bilan tekshiradi. Hodisa bor bo'lsa Deployment'ni 0 dan `minReplicaCount` ga (0 bo'lsa 1 ga) ko'taradi, oxirgi faol holatdan `cooldownPeriod` (default 300 s) o'tgach 0 ga tushiradi.
- **1 <-> N**: KEDA `keda-hpa-<name>` nomli oddiy HPA yaratadi va unga external metrics API (2-bo'lim) orqali metrika beradi. Qolganini HPA controller qiladi, 3–5-bo'limlardagi formula va `behavior` bilan.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: mailer}
spec:
  scaleTargetRef: {name: mailer}
  minReplicaCount: 0
  maxReplicaCount: 15
  triggers:
  - type: rabbitmq
    metadata:
      queueName: emails
      mode: QueueLength
      value: "20"
    authenticationRef: {name: rabbitmq-auth}
```

- `value: "20"`: har replica'ga navbatda o'rtacha 20 ta xabar maqsad. Navbatda 130 ta bo'lsa `ceil(130/20) = 7` replica.
- **Scaler'lar**: o'nlab manba (Redis, RabbitMQ, Kafka, AWS SQS, Prometheus, cron va boshqalar). Har scaler'ning metadata maydonlari o'zgacha, scaler sahifasidan olinadi. Prometheus scaler: `serverAddress`, `query` (PromQL), `threshold`. Bu mavjud metrikalaringiz (observability moduli) bo'yicha masshtablashning eng qisqa yo'li.
- `activation...` qiymatlari (masalan Redis'da `activationListLength`, Prometheus'da `activationThreshold`) 0 dan 1 ga o'tish chegarasini alohida belgilaydi.
- Parol va token'lar `TriggerAuthentication` obyekti orqali Secret'dan beriladi (yuqoridagi `authenticationRef`), `ScaledObject` ichida ochiq yozilmaydi.
- `advanced.horizontalPodAutoscalerConfig.behavior` HPA `behavior` ni uzatadi.
- `ScaledJob`: har hodisa uchun Deployment emas, Job (5-dars) yaratadi (uzoq, uzib bo'lmaydigan ishlar uchun).
- Bitta workload'ga `ScaledObject` va o'zingiz yozgan HPA birga qo'yilmaydi.

### Misol

```
$ kubectl get scaledobject mailer
NAME     SCALETARGETKIND      SCALETARGETNAME   MIN   MAX   READY   ACTIVE   FALLBACK   PAUSED   TRIGGERS   AUTHENTICATIONS   AGE
mailer   apps/v1.Deployment   mailer            0     15    True    False    False      False    rabbitmq   rabbitmq-auth     12m
$ kubectl get deployment mailer
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
mailer   0/0     0            0           12m
```

`READY True` KEDA manbaga ulana oldi va metrika olyapti; `False` bo'lsa ulanish yoki autentifikatsiya muammosi, sababi `kubectl describe scaledobject` va operator log'ida. `ACTIVE False` hozir hodisa yo'q (activation chegarasidan past), shuning uchun Deployment `0/0`. `FALLBACK` manba ishlamay qolganda zaxira replica soni qo'llanyaptimi. `PAUSED` annotation bilan to'xtatilganmi. Ustunlar to'plami KEDA versiyasiga qarab biroz farq qilishi mumkin.

**Scale to zero narxi**: birinchi so'rov yoki xabar cold start'ni (Pod yaratish, image pull, start) kutadi. Navbat worker'lari uchun bu muammo emas, xabar navbatda kutadi. Sinxron HTTP uchun nolga tushganda so'rovni ushlab turadigan proxy kerak (KEDA HTTP add-on, Knative kabi), aks holda mijoz xato oladi.

### Real ishda qachon kerak

- Navbat worker'lari (email, rasm qayta ishlash, eksport): KEDA eng tabiiy yechim.
- Kechasi umuman ishlatilmaydigan dev/staging muhitlari: cron scaler bilan ish vaqtida 1, qolgan vaqtda 0 (15-dars).
- I/O-bound HTTP servislar: Prometheus scaler orqali RPS yoki latency bo'yicha.

### Nima uchun shunday

KEDA HPA'ni qayta yozmay, uning ustiga qurilgani ataylab qilingan: formula, `behavior` va condition'lar allaqachon sinalgan, KEDA esa faqat yetishmagan ikki narsani qo'shadi (metrika manbalari va nol holat). HPA'ning o'zi nolga tushmasligi ham sababli: metrika Pod'lardan olinadi, Pod yo'q bo'lsa metrika yo'q va qayta ko'tarish uchun signal ham yo'q. KEDA signalni Pod'lardan emas, tashqi manbadan (navbatdan) olgani uchun bu muammo unda yo'q.

## 9. Yuk sinovi

### Bu nima

Autoscaling'ni yuk ostida ko'rmasdan sozlab bo'lmaydi. Yuk sinovi (load test) servisga nazorat qilingan, bosqichli trafik berib, latency, xato darajasi va autoscaler reaksiyasini o'lchash.

### Mexanizm

k6 (Grafana'ning ochiq yuk generatori) skriptni JavaScript'da yozadi, frontend tajribangiz shu yerda to'g'ridan-to'g'ri ishlaydi. `stages` virtual foydalanuvchilar (VU, parallel ishlaydigan sikl) sonini vaqt bo'yicha o'zgartiradi: ramp-up, plato, ramp-down. Oxirida latency foizlari (p90, p95) va xato foizi chiqadi. p95 latency: so'rovlarning 95% shu vaqtdan tezroq javob olgan.

```javascript
import http from 'k6/http';
export const options = {
  stages: [{ duration: '30s', target: 20 }, { duration: '30s', target: 0 }],
};
export default function () { http.get('http://echo.default.svc.cluster.local/'); }
```

Skript klaster ichida ishlashi uchun uni ConfigMap'ga (4-dars) solib, `grafana/k6:1.0.0` Pod'iga volume sifatida ulaysiz va `k6 run <fayl>` buyrug'i bilan ishga tushirasiz. Yuk generatori va servis bir xil node'larning CPU'sini bo'lishadi; kind'da bu natijani buzadi, README'da shuni hisobga oling.

Oddiyroq yuk uchun HPA qo'llanmasidagi usul: busybox Pod'i ichida cheksiz `wget` sikli:

```bash
kubectl run load --rm -it --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://echo; done"
```

### Misol

k6 tugagach chiqadigan xulosadan muhim qatorlar:

```
    http_req_duration..............: avg=<38ms>  min=<2ms> med=<21ms> max=<1.2s> p(90)=<85ms> p(95)=<140ms>
    http_req_failed................: <0.12%> <14 out of 11520>
    http_reqs......................: <11520> <191/s>
    vus_max........................: 20
```

`http_req_duration` javob vaqti taqsimoti: o'rtacha, median va foizlar; autoscaling uchun eng muhimi `p(95)`, chunki o'rtacha qiymat sekin so'rovlarni yashiradi. `http_req_failed` xato javoblar ulushi (scale-down paytida graceful shutdown bo'lmasa shu yerda ko'rinadi). `http_reqs` umumiy so'rov va soniyadagi tezlik. `vus_max` eng ko'p parallel VU.

Kuzatish uchun parallel terminallar:

```bash
kubectl get hpa echo -w
kubectl get pods -l app=echo -w
kubectl top pods -l app=echo
```

### Real ishda qachon kerak

- Har yangi servis yoki HPA sozlamasi o'zgarganda: birinchi yangi Pod `Ready` bo'lguncha qancha vaqt, shu oraliqda latency va xato darajasi qanday, yuk tugagach replica'lar qachon kamaydi, kamayish paytida xato bo'ldimi.
- Grafana'da (observability moduli) replica soni, CPU va p95 latency'ni bitta panelda ko'rish eng ko'p narsa o'rgatadi.

### Nima uchun shunday

Autoscaling teskari aloqa (feedback) tizimi: kechikishi bor (metrika 15 s, HPA 15 s, Pod start, readiness) va bu kechikishlar faqat real yuk ostida ko'rinadi. Har kechikish halqasini qog'ozda hisoblash mumkin, lekin ularning yig'indisi va o'zaro ta'sirini faqat o'lchash beradi. Yukni klaster ichidan berish shart, chunki tashqaridan `port-forward` orqali berilgan yuk bitta Pod'ga tushadi va HPA qo'shgan Pod'lar hech narsa olmaydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Autoscaling | yukka qarab resursni avtomatik ko'paytirish va kamaytirish |
| Horizontal scaling | bir xil nusxalar (Pod'lar) sonini o'zgartirish |
| Vertical scaling | bitta nusxaning CPU va xotirasini o'zgartirish |
| metrics-server | kubelet'lardan joriy CPU/xotirani yig'ib `metrics.k8s.io` orqali beradigan komponent |
| APIService | API server'ga qo'shimcha API guruhini boshqa servisga uzatishni bildiradigan obyekt |
| Custom / External metrics API | adapter beradigan, klaster obyektiga bog'liq yoki tashqi metrikalar API'si |
| HPA | Pod'lar sonini metrika bo'yicha o'zgartiradigan obyekt va controller |
| Utilization | iste'molning requests'ga nisbatan foizi |
| Tolerance | HPA reaksiya qilmaydigan nisbat oralig'i (default 10%) |
| Stabilization window | HPA qarori uchun ko'rib chiqiladigan oxirgi tavsiyalar davri |
| Scaling policy | bir davrda ruxsat etilgan o'zgarish hajmi (`Pods` yoki `Percent`) |
| Flapping | replica sonining to'xtovsiz tebranishi |
| `ContainerResource` | bitta konteyner resursi bo'yicha HPA metrikasi |
| VPA | Pod requests'ini iste'mol tarixiga qarab o'zgartiradigan komponent |
| `updateMode` | VPA tavsiyani qanday qo'llashi (`Off`, `Initial`, `Recreate`, `InPlaceOrRecreate`) |
| In-place resize | Pod resurslarini restart'siz o'zgartirish |
| Right-sizing | requests'ni haqiqiy iste'molga moslashtirish |
| Cluster Autoscaler | `Pending` Pod'lar va bo'sh node'lar bo'yicha node group hajmini o'zgartiradigan komponent |
| Node group | bir xil turdagi node'lar guruhi (AWS Auto Scaling Group kabi) |
| Karpenter | Pod talablariga qarab instance'larni to'g'ridan-to'g'ri yaratadigan node autoscaler |
| Consolidation | Pod'larni zichroq joylab node'larni kamaytirish yoki arzonlashtirish |
| Overprovisioning | past priority'li Pod'lar bilan zaxira joy ushlab turish |
| KEDA | hodisa manbalari bo'yicha HPA'ni boshqaradigan va nolga tushira oladigan operator |
| ScaledObject | KEDA'da Deployment'ni qaysi trigger bo'yicha masshtablashni yozadigan obyekt |
| Scaler / trigger | KEDA'ning muayyan manbadan (Redis, Prometheus, cron) metrika oladigan qismi |
| TriggerAuthentication | KEDA scaler'iga Secret'dan maxfiy ma'lumot beradigan obyekt |
| Scale to zero | hodisa yo'q paytda replica sonini 0 ga tushirish |
| Cold start | noldan birinchi Pod tayyor bo'lguncha kechikish |
| Load test | nazorat qilingan bosqichli yuk berib tizim reaksiyasini o'lchash |
| p95 latency | so'rovlarning 95% undan tezroq javob olgan vaqt |

## Tuzoqlar

- Requests'siz Deployment'ga HPA: `<unknown>`, hech narsa ishlamaydi.
- Requests haqiqiy iste'moldan ancha katta: utilization doim past, HPA hech qachon scale qilmaydi. Juda kichik: doim maksimal replica.
- HPA boshqaradigan Deployment'da `replicas` git'da: har sync replica sonini qaytaradi.
- I/O-bound servisni CPU bo'yicha masshtablash: latency o'sadi, CPU past, HPA jim.
- Xotira bo'yicha HPA: faqat yuqoriga.
- Node.js kabi bir oqimli ilovaga 1 CPU'dan katta request: utilization target'ga hech qachon yetmaydi.
- `maxReplicas` ni baza ulanish limiti yoki node sig'imini o'ylamasdan qo'yish: autoscaling nosozlikni kuchaytiradi.
- HPA va VPA'ni bir xil resurs metrikasida birga ishlatish.
- Node autoscaler bor deb `Pending` Pod'larni e'tiborsiz qoldirish: node'ning tayyor bo'lishi daqiqalar, keskin yukda bu juda uzoq.
- Sinxron HTTP servisni proxy'siz nolga tushirish.
- Scale-down'da graceful shutdown yo'q: har kechqurun bir oz 502.
- Tor PDB va `safe-to-evict: "false"` annotation'lari tufayli node'lar hech qachon bo'shamaydi va to'lov davom etadi.
- Yukni `port-forward` orqali berish: hamma trafik bitta Pod'ga, HPA qo'shgan Pod'lar bo'sh turadi.
- kind'da yuk generatori va servis bir CPU'ni bo'lishadi: natijalar shovqinli, xulosani shunga qarab qiling.
- KEDA `ScaledObject` va qo'lda yozilgan HPA bitta Deployment'da: ikki controller bir-biriga qarshi ishlaydi.
- Redis yoki navbat parolini `ScaledObject` metadata'siga ochiq yozish.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/autoscaling/ – autoscaling umumiy ko'rinish
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
- https://keda.sh/docs/latest/scalers/cron/ – cron scaler
- https://grafana.com/docs/k6/latest/ – k6

## Birga bajaramiz

Vazifalardagidan boshqa misol: HTTP servis emas, o'z-o'zidan CPU yeydigan `burner` Deployment. Yuk generatori kerak emas, shuning uchun zanjirning faqat HPA qismi toza ko'rinadi: metrika, formula, `maxReplicas` cheklovi, scale-down kechikishi. Oxirida ixtiyoriy qadam: KEDA cron scaler bilan vaqt bo'yicha masshtablash. Hammasi `scale` klasterida, `walk` namespace'ida, `~/k14-walk` papkasida; hech narsa commit qilinmaydi.

**1-qadam. Namespace va manifest.**

```
$ mkdir ~/k14-walk && cd ~/k14-walk
$ kubectl create namespace walk
namespace/walk created
$ kubectl config set-context --current --namespace=walk
Context "kind-scale" modified.
$ cat burner.yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: burner}
spec:
  selector:
    matchLabels: {app: burner}
  template:
    metadata:
      labels: {app: burner}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        env: [{name: MODE, value: burn}]
        command: ["sh", "-c", "if [ \"$MODE\" = burn ]; then while :; do :; done; else sleep 1000000; fi"]
        resources:
          requests: {cpu: 100m, memory: 16Mi}
          limits: {cpu: 200m, memory: 32Mi}
```

`MODE=burn` bo'lsa shell bo'sh sikl aylantiradi va CPU'ni yeydi; boshqa qiymatda uxlaydi. CPU limit 200m: kernel (CFS throttling, 4-dars) jarayonni 200m dan oshirmaydi, request 100m. Demak har Pod utilization'i taxminan `200 / 100 = 200%` bo'ladi. `replicas` ataylab yozilmagan (5-bo'lim): yaratilganda default 1, keyin HPA boshqaradi.

**2-qadam. HPA.**

```
$ cat hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: burner}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: burner}
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 80}
$ kubectl apply -f burner.yaml -f hpa.yaml
deployment.apps/burner created
horizontalpodautoscaler.autoscaling/burner created
```

**3-qadam. Kuzatish.** Ikkinchi terminalda vaqt bilan:

```
$ kubectl get hpa burner -w | while read -r line; do echo "$(date +%T) $line"; done
10:02:01 NAME     REFERENCE           TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
10:02:01 burner   Deployment/burner   cpu: <unknown>/80%   1         4         0          3s
10:02:31 burner   Deployment/burner   cpu: 199%/80%        1         4         1          33s
10:02:46 burner   Deployment/burner   cpu: 199%/80%        1         4         3          48s
10:03:16 burner   Deployment/burner   cpu: 200%/80%        1         4         3          78s
10:03:31 burner   Deployment/burner   cpu: 200%/80%        1         4         4          93s
```

Qatorma-qator: birinchi soniyalarda `<unknown>`, chunki metrics-server yangi Pod'ni hali o'lchamagan (u har 15 soniyada yig'adi). 33-soniyada metrika keldi: 1 Pod, 199%. Formula `ceil(1 * 199 / 80) = 3`, keyingi siklda `REPLICAS 3`. Yangi Pod'lar ham darhol 200% yeydi: `ceil(3 * 200 / 80) = 8`, lekin `maxReplicas: 4` cheklaydi, natija 4. Sizda qadamlar boshqa bo'lishi mumkin: yangi Pod'larning birinchi metrikasi kechikib kelgani uchun HPA ularni bir sikl hisobga olmasligi mumkin (3-bo'lim, ehtiyotkor hisob).

**4-qadam. Nima uchun to'xtadi.**

```
$ kubectl describe hpa burner | grep -A 5 Conditions
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  recommended size matches current size
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  True    TooManyReplicas   the desired replica count is more than the maximum replica count
```

`ScalingLimited True TooManyReplicas`: formula 8 ni xohlaydi, chegara 4. Haqiqiy servisda bu "`maxReplicas` yoki Pod samaradorligini qayta ko'rib chiqing" degan signal. Bu yerda esa kutilgan: har bir burner Pod'i yuk qancha bo'lmasin to'liq yeydi, shuning uchun bunday servisni HPA hech qachon "qondira olmaydi".

**5-qadam. Yukni o'chirish va scale-down.**

```
$ kubectl set env deployment/burner MODE=idle
deployment.apps/burner env updated
```

Bu Pod template'ni o'zgartiradi, shuning uchun Deployment rollout qiladi (4-dars) va yangi Pod'lar uxlaydi. HPA terminalida `TARGETS` bir-ikki daqiqada `cpu: 0%/80%` ga tushadi, lekin `REPLICAS` 4 da qoladi. Taxminan 5 daqiqadan keyin:

```
10:11:02 burner   Deployment/burner   cpu: 0%/80%          1         4         1          9m
```

5 daqiqa bu default `scaleDown.stabilizationWindowSeconds: 300`: HPA oxirgi 5 daqiqadagi eng yuqori tavsiyani oldi, bu davrda hali 4 tavsiya qilingan edi. Default scale-down policy bir siklda 100% kamaytirishga ruxsat beradi, shuning uchun 4 dan to'g'ridan-to'g'ri 1 ga tushdi. `kubectl describe hpa burner` event'larida endi ikkinchi `SuccessfulRescale` ko'rinadi, sababi `All metrics below target`.

**6-qadam (ixtiyoriy, KEDA o'rnatilgan bo'lsa). Vaqt bo'yicha masshtablash.** Avval HPA'ni o'chiring: bitta Deployment'ga ikki autoscaler qo'yilmaydi.

```
$ kubectl delete hpa burner
horizontalpodautoscaler.autoscaling "burner" deleted
$ cat cron.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: {name: burner}
spec:
  scaleTargetRef: {name: burner}
  minReplicaCount: 0
  maxReplicaCount: 3
  cooldownPeriod: 60
  triggers:
  - type: cron
    metadata:
      timezone: Asia/Tashkent
      start: "*/10 * * * *"
      end: "5-59/10 * * * *"
      desiredReplicas: "2"
$ kubectl apply -f cron.yaml
scaledobject.keda.sh/burner created
$ kubectl get hpa
NAME              REFERENCE           TARGETS            MINPODS   MAXPODS   REPLICAS   AGE
keda-hpa-burner   Deployment/burner   <...>/<...> (avg)  1         3         2          40s
```

Cron trigger har 10 daqiqaning birinchi 5 daqiqasida (`:00–:05`, `:10–:15` va hokazo) 2 replica talab qiladi, qolgan vaqtda hech narsa. `kubectl get hpa` da siz yozmagan HPA paydo bo'ldi: `keda-hpa-burner`, uni KEDA yaratgan va `MINPODS 1`, chunki HPA nolga tusha olmaydi (8-bo'lim). Oyna yopilgach, `cooldownPeriod: 60` soniyadan keyin Deployment `0/0` bo'ladi: buni HPA emas, KEDA operator'ining o'zi qiladi. `kubectl get deployment burner -w` bilan bir oynani kuzatib, shuni o'z ko'zingiz bilan ko'ring.

**7-qadam. Tozalash.**

```
$ kubectl delete namespace walk
namespace "walk" deleted
$ kubectl config set-context --current --namespace=default
Context "kind-scale" modified.
```

Bu yurishdan olib qoladigan narsalar: utilization request'ga nisbatan va limit uni yuqoridan qisadi; HPA qarorini har doim formula bilan qayta tekshirish mumkin; `Conditions` HPA nima uchun to'xtaganini aytadi; scale-down default'da 5 daqiqa kechikadi; KEDA o'z HPA'sini yaratadi va 0 ni o'zi boshqaradi.

---

## Vazifalar

Barchasini `kubernetes/14-autoscaling/` da bajaring (`make new m=kubernetes n=14 name=autoscaling`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml`, yuk skriptlari (`load.js`) shu papkada. Sinov ilovasi: CPU yuklaydigan endpoint'i bor o'z ilovangiz yoki HPA qo'llanmasidagi `registry.k8s.io/hpa-example` image'i (macOS'da `arm64` variantini Laboratoriya bo'limidagidek tekshiring). Vaqtga va foizga bog'liq natijalarda qaysi mashinada olinganini (Zorin yoki macOS) yozing. Parollar faqat Secret orqali, Secret manifesti papkaga yozilmaydi.

### A. Metrikalar

1. **metrics-server.** metrics-server'ni o'rnating. Patch'dan oldin Pod log'idagi xatoni yozing, keyin tuzating. `kubectl top nodes`, `kubectl top pods -A` va `kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes` chiqishini ko'ring. `kubectl get apiservices | grep metrics` nimani ko'rsatadi? Yo'nalish: 2-bo'lim, "Mexanizm".

2. **Requests as the basis.** Sinov ilovasini CPU request 200m bilan deploy qiling va doimiy yuk bering. `kubectl top pod` dagi qiymatdan utilization'ni qo'lda hisoblang. Request'ni 100m va 500m ga o'zgartirib, o'sha yuk ostida utilization qanday o'zgarishini jadvalga yozing. Yo'nalish: 1- va 3-bo'lim.

### B. HPA

3. **First HPA.** CPU 50% target, min 1, max 10 bilan `autoscaling/v2` HPA yozing (`kubectl autoscale` emas, manifest). Klaster ichidan yuk bering va `kubectl get hpa -w` chiqishini vaqt bilan yozing: `TARGETS` va `REPLICAS` qanday o'zgardi? Yo'nalish: 3-bo'lim, 9-bo'lim (yuk).

4. **Verify the formula.** 3-vazifadagi kuzatuvdan uch lahzani oling va har birida `desiredReplicas` ni formula bilan qo'lda hisoblang. HPA qarori bilan mos keldimi? Mos kelmagan joyda sababini (tolerance, ready bo'lmagan Pod'lar, policy) toping. Yo'nalish: 3-bo'lim, "Mexanizm"; 5-bo'lim.

5. **Scale-down timing.** Yukni to'xtating va replica'lar qachon kamaya boshlaganini o'lchang. Nima uchun darhol emas? `kubectl describe hpa` event'larini yozing. Yo'nalish: 5-bo'lim.

6. **HPA without requests.** Deployment'dan `resources.requests` ni olib tashlang. HPA holati va `describe` dagi xabar qanday? Ikki konteynerli Pod'da faqat bittasida request bo'lsa-chi? `ContainerResource` metrika turi bu yerda nimani yechadi? Yo'nalish: 4-bo'lim, "Mexanizm".

7. **Tune behavior.** `behavior` bilan ikki profil yozing: (a) agressiv: scale-up cheklovsiz, scale-down 60 soniya window; (b) ehtiyotkor: scale-up daqiqasiga ko'pi bilan 2 Pod, scale-down 10 daqiqada 10%. Bir xil "30 soniya yuk, 30 soniya tinch" tebranuvchi yuk ostida ikkalasining replica grafigini solishtiring. Yo'nalish: 5-bo'lim.

8. **replicas conflict.** Manifestda `replicas: 2` qoldirib, HPA 6 ga ko'targan paytda `kubectl apply` ni takrorlang. Nima bo'ldi? Buni GitOps'da (10-dars) qanday hal qilasiz? Ikki usulni yozing. Yo'nalish: 5-bo'lim, "HPA atrofidagi shartlar".

9. **Wrong signal.** Har so'rovda 200 ms `sleep` qiladigan (CPU ishlatmaydigan) endpoint'ga yuk bering. Latency va CPU utilization bilan nima bo'ldi, HPA nima qildi? Bu servis uchun qaysi metrika to'g'ri bo'lar edi? Yo'nalish: 4-bo'lim.

10. **Load test with k6.** k6 skripti yozing: 1 daqiqa ramp-up, 3 daqiqa plato, 1 daqiqa ramp-down. Klaster ichida Pod sifatida ishga tushiring. HPA'siz (1 replica) va HPA bilan p95 latency va xato foizini solishtiring. Birinchi yangi Pod `Ready` bo'lguncha qancha vaqt o'tdi va shu oraliqda latency qanday edi? Yo'nalish: 9-bo'lim.

### C. VPA va node'lar

11. **VPA recommendations.** VPA'ni rasmiy repo bo'yicha o'rnating va sinov ilovasiga `updateMode: "Off"` bilan VPA qo'ying. Yuk ostida bir muddat ishlatib, `kubectl describe vpa` dagi `Target`, `Lower Bound`, `Upper Bound` ni yozing. Joriy requests bilan solishtiring. Nima uchun shu Deployment'ga CPU HPA va `Recreate` rejimli VPA'ni birga qo'yib bo'lmaydi? Yo'nalish: 6-bo'lim. O'rnatish skripti repo ichida, uni host'da ishga tushirasiz, u faqat klasterni o'zgartiradi.

12. **Pending pods.** HPA `maxReplicas` ni worker'lar sig'imidan katta qiling va yuk bering. `Pending` Pod'larning event'ini yozing. Cluster Autoscaler shu holatda nima qilar edi va nimaga qarab? `kubectl describe node` dagi `Allocated resources` dan qaysi resurs tugaganini ko'rsating. Yo'nalish: 7-bo'lim, "Misol"; kind'da worker sig'imi mashinaga bog'liq (Laboratoriya jadvali), shuning uchun request'ni sig'imga qarab tanlang.

13. **Node autoscaling on paper.** Kodsiz: 3 node, har biri 4 CPU; har Pod 500m request; HPA 6 dan 30 ga ko'tarmoqchi. Nechta Pod sig'adi (tizim Pod'lari uchun har node'da 500m ajrating), nechta node qo'shiladi, yangi node tayyor bo'lguncha nima bo'ladi? Yuk tushgach node'lar qaysi shartlarda olib tashlanadi, nimalar to'sqinlik qiladi? Cluster Autoscaler va Karpenter bu ssenariyda qanday har xil yo'l tutadi? Yo'nalish: 7-bo'lim.

### D. KEDA

14. **Install KEDA.** KEDA'ni o'rnating. `keda` namespace'idagi komponentlar va `kubectl get apiservices | grep external.metrics` chiqishini yozing. Bu 2-bo'limdagi jadvalning qaysi qatoriga mos keladi? Yo'nalish: Laboratoriya, 2- va 8-bo'lim.

15. **Queue-driven scaling.** Redis Deployment va Service, hamda navbatdan bittadan xabar olib 2 soniya "ishlaydigan" worker Deployment (shell sikli yoki o'z kodingiz) yarating. Redis list trigger'li `ScaledObject` yozing (min 0, max 10). 200 ta xabar qo'shing (`LPUSH`) va replica'lar, navbat uzunligi (`LLEN`) qanday o'zgarishini vaqt bilan yozing. Yo'nalish: 8-bo'lim; Redis scaler maydonlarini https://keda.sh/docs/latest/scalers/redis-lists/ dan oling. Image tag'ini qotiring (masalan `redis:7.4`), `latest` emas.

16. **Scale to zero.** Navbat bo'shagach worker qachon nolga tushdi? Bu qaysi parametrga bog'liq? Bitta xabar qo'shing: birinchi Pod'gacha qancha vaqt o'tdi va u nimalardan tashkil topgan? `kubectl get hpa` da KEDA yaratgan HPA'ni toping: undagi `minReplicas` nechaga teng va 0 ga kim tushiradi? Yo'nalish: 8-bo'lim, "Mexanizm".

17. **TriggerAuthentication.** Redis'ga parol qo'ying (Secret'dan). Worker va `ScaledObject` ulanishini tuzating: parol `TriggerAuthentication` orqali berilsin. Noto'g'ri parol bilan `ScaledObject` holati va KEDA operator log'ida nima ko'rinadi? Yo'nalish: 8-bo'lim, "Misol" (`READY` ustuni). Secret'ni `kubectl create secret` bilan yarating, manifestini papkaga yozmang.

18. **Prometheus scaler.** Klasterga Prometheus o'rnating (observability modulidagi usulda) va HTTP servisingizni so'rovlar tezligi (`rate(http_requests_total[1m])` yoki ilovangizdagi mos metrika) bo'yicha Prometheus trigger'i bilan masshtablang. 9-vazifadagi "noto'g'ri signal" servisi endi to'g'ri scale bo'ladimi? Yo'nalish: 8-bo'lim; https://keda.sh/docs/latest/scalers/prometheus/.

19. **HTTP and zero.** 18-vazifadagi servisga `minReplicaCount: 0` qo'ying va tinch turgandan keyin so'rov yuboring. Nima bo'ldi va nima uchun bu navbat worker'idan farq qiladi? Yechim variantlarini yozing (o'rnatmasdan). Yo'nalish: 8-bo'lim, "Scale to zero narxi".

### E. Yig'ma

20. **Autoscaling design.** Ilovangizning uch qismi uchun (HTTP API, navbat worker'i, PostgreSQL) masshtablash rejasini yozing: har biri uchun qaysi asbob, qaysi signal, min va max, `behavior`, PDB va graceful shutdown bilan bog'liqligi, va nima uchun bazani HPA bilan masshtablab bo'lmaydi. API va worker qismlarini amalda sozlab, bitta k6 sinovi ostida ikkalasining ham scale bo'lishini ko'rsating. Yo'nalish: butun dars; baza bo'yicha 12-dars.

## Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 20 vazifa `## N. Title` sarlavhasi ostida yozilgan, manifestlar va `load.js` papkada.
2. README'da har sinov uchun vaqt chizig'i (yuk, replica soni, latency) bor va qaysi mashinada olingani ko'rsatilgan.
3. `make check` toza (`yamllint`, host'da).
4. Papkada Secret manifesti yoki parol yo'q (`git status` bilan tekshiring).
5. `kind delete cluster --name scale` bajarilgan (`kind get clusters` da `scale` yo'q).
6. Menga xabar bering, tekshiraman.

## O'zini tekshirish savollari

Kodsiz, o'z so'zingiz bilan javob bering.

- HPA utilization'ni nimaga nisbatan hisoblaydi? Request yo'q bo'lsa nima bo'ladi?
- 5 Pod, target 50%, joriy 80%: HPA nechta replica xohlaydi?
- Scale-up va scale-down nima uchun default'da har xil tezlikda?
- CPU qaysi turdagi servis uchun noto'g'ri masshtablash signali?
- metrics-server nima uchun monitoring tizimi emas?
- HPA va VPA'ni qachon birga ishlatib bo'lmaydi va nima uchun?
- Cluster Autoscaler node qo'shish qarorini nimaga qarab qabul qiladi? Node'lar CPU bo'yicha to'la, lekin `Pending` Pod yo'q bo'lsa nima qiladi?
- KEDA HPA bilan qanday munosabatda? 0 dan 1 ga kim ko'taradi?
- Scale to zero qaysi workload uchun xavfsiz, qaysi biri uchun qo'shimcha komponent kerak?
- HPA boshqaradigan Deployment manifestida `replicas` nima uchun bo'lmasligi kerak?
- Yuk sinovini nima uchun klaster ichidan berish kerak?
