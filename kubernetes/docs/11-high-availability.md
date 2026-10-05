# 11-dars: Production High Availability

Maqsad: hozirgacha "3 replica" yozish yetarli tuyulgan edi. Lekin uchala Pod bitta node'ga tushsa, o'sha node o'chganda servis ham o'chadi; node drain qilinsa hamma replica bir vaqtda evict bo'lishi mumkin; rollout paytida so'rovlarning bir qismi 502 oladi. Bu darsda replica'larni node va zona bo'ylab yoyish (affinity, anti-affinity, topology spread), rejali uzilishlardan himoya (PodDisruptionBudget, drain), ustuvorlik (PriorityClass, preemption) va Pod'ni so'rov yo'qotmasdan to'xtatish (graceful shutdown) ko'riladi. Hammasi ko'p node'li kind cluster'da node'ni drain qilib va o'chirib sinaladi. 12-darsdagi ma'lumotlar bazasi va 14-darsdagi autoscaling shu asosga tayanadi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqat: `required` va `preferred` farqi va har birining narxi, PDB aynan nimadan himoya qiladi va nimadan yo'q, node o'chganda Pod'lar nima uchun 5 daqiqa kutadi, SIGTERM va endpoint yangilanishi orasidagi poyga.

## Laboratoriya

Ish mashinasidagi Docker'da 1 control-plane va 3 worker'li kind cluster. Worker'larga zona label'lari qo'yiladi:

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

`kind create cluster --name ha --config kind-ha.yaml`. Node'lar Docker konteynerlari: `ha-control-plane`, `ha-worker`, `ha-worker2`, `ha-worker3`. Node "o'chishi" `docker stop ha-worker2`, qaytishi `docker start ha-worker2` bilan taqlid qilinadi. Tozalash: `kind delete cluster --name ha`. Control-plane HA qismi (2-bo'lim) nazariy, xohlasangiz 2-darsdagi Multipass VM'larda k3s bilan sinaysiz.

---

## 1. Uzilish turlari

| Tur | Misollar | Nima himoya qiladi |
|-----|----------|--------------------|
| Voluntary (rejali) | `kubectl drain`, node upgrade, cluster autoscaler node'ni olib tashlashi, rollout | PodDisruptionBudget, rolling update sozlamalari, graceful shutdown |
| Involuntary (kutilmagan) | node apparat nosozligi, kernel panic, OOM, zona uzilishi, tarmoq bo'linishi | ortiqcha replica, node/zona bo'ylab yoyish |

Bu ajratish muhim: PDB faqat birinchi qatorga ta'sir qiladi. Node yonib ketsa PDB hech narsa qila olmaydi.

HA arifmetikasi sodda: N ta replica'dan bir vaqtda nechta yo'qolishi mumkin va qolgani yukni ko'tara oladimi. Uch zonaga yoyilgan 3 replica bitta zona yo'qolganda quvvatning 1/3 qismini yo'qotadi, demak qolgan ikkitasi 150% yukni ko'tara olishi kerak. Requests va autoscaling (14-dars) shu hisobdan kelib chiqadi.

## 2. Control plane HA

Ilova Pod'lari control plane'siz ham ishlayveradi (kubelet mavjud Pod'larni ushlab turadi), lekin hech narsa o'zgarmaydi: yangi Pod yo'q, o'chgan Pod qayta yaratilmaydi, Service endpoint'lari yangilanmaydi.

- **etcd** Raft konsensusi bilan ishlaydi, yozish uchun ko'pchilik (quorum) kerak: `floor(N/2)+1`. 3 a'zo 1 ta yo'qotishga chidaydi, 5 a'zo 2 taga. Juft son foyda bermaydi: 4 a'zo ham faqat 1 taga chidaydi. Quorum yo'qolsa cluster faqat o'qiladi.
- **kube-apiserver** stateless, bir nechta nusxa load balancer ortida turadi. Kubeconfig va kubelet'lar LB manziliga qaraydi.
- **controller-manager, scheduler** bir nechta nusxa ishlaydi, lekin bir vaqtda bittasi faol (leader election, `Lease` obyekti orqali).
- **Topologiya**: stacked (etcd control-plane node'larida, kubeadm default'i) yoki external etcd (alohida node'larda, ko'proq mashina, mustaqil nosozlik domeni).
- k3s'da server'lar embedded etcd bilan HA qilinadi (birinchi server `--cluster-init`, kamida uchta server).
- Managed Kubernetes (EKS, GKE, AKS) control plane HA'ni o'zi beradi. Bu managed xizmat uchun to'lashning asosiy sababi.

etcd backup'i (snapshot) HA'ning o'rnini bosmaydi va aksincha: HA nosozlikka, backup xatoga (noto'g'ri o'chirish) qarshi.

## 3. Pod'larni joylashtirish

Scheduler default'da Pod'larni node'lar bo'ylab yoyishga harakat qiladi, lekin kafolat bermaydi. Kafolat uchun quyidagilar.

### nodeSelector va node affinity

`nodeSelector` eng sodda: Pod faqat shu label'li node'ga tushadi. Node affinity shuning ifodali varianti:

| Tur | Scheduling paytida | Ma'nosi |
|-----|--------------------|---------|
| `requiredDuringSchedulingIgnoredDuringExecution` | qat'iy shart | mos node bo'lmasa Pod `Pending` |
| `preferredDuringSchedulingIgnoredDuringExecution` | `weight` (1–100) bilan afzallik | mos node bo'lmasa boshqasiga tushadi |

`IgnoredDuringExecution`: Pod joylashgandan keyin node label'i o'zgarsa Pod ko'chirilmaydi. Operator'lar: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.

### Pod affinity va anti-affinity

Node label'iga emas, o'sha joyda ishlab turgan boshqa Pod'larga qarab qaror qiladi. `topologyKey` "joy" nimaligini belgilaydi: `kubernetes.io/hostname` (node) yoki `topology.kubernetes.io/zone` (zona).

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels: { app: web }
        topologyKey: kubernetes.io/hostname
```

Bu "`app=web` Pod'i bor node'ga boshqa `app=web` Pod tushmasin" degani. Narxi: replica soni node sonidan oshsa ortiqchasi `Pending`. Rolling update'da ham: 3 node, 3 replica, `maxSurge: 1` bo'lsa yangi Pod uchun joy yo'q va rollout to'xtab qoladi (`maxSurge: 0`, `maxUnavailable: 1` bilan yechiladi). `preferred` varianti bunday bloklamaydi, lekin kafolat ham bermaydi.

Pod affinity (anti'siz) teskari maqsad uchun: ilova va uning cache'ini bitta node yoki zonaga yaqin qo'yish.

### topologySpreadConstraints

Anti-affinity "bir joyda bittadan ko'p bo'lmasin" deydi. Spread constraint esa "domenlar orasidagi farq `maxSkew` dan oshmasin" deydi, bu 3 zonada 6 yoki 9 replica uchun to'g'ri model.

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
| `whenUnsatisfiable` | `DoNotSchedule` (qat'iy, `Pending`) yoki `ScheduleAnyway` (yumshoq) |
| `labelSelector` | qaysi Pod'lar sanaladi |
| `matchLabelKeys` | masalan `pod-template-hash`: rollout paytida faqat shu revision'ning Pod'lari sanaladi |

Bir nechta constraint birga ishlatiladi: zona bo'yicha qat'iy, node bo'yicha yumshoq.

**Tuzoq: spread faqat scheduling paytida ishlaydi.** Node qaytgandan yoki scale-down'dan keyin mavjud Pod'lar qayta taqsimlanmaydi: deployment controller qaysi Pod'ni o'chirishni spread'ga qarab tanlamaydi. Muvozanatni tiklash uchun alohida descheduler loyihasi yoki `kubectl rollout restart` kerak.

**Tuzoq: `labelSelector` rollout'da.** `matchLabelKeys` siz eski va yangi ReplicaSet Pod'lari birga sanaladi, rollout oxirida taqsimot noto'g'ri chiqishi mumkin.

## 4. PodDisruptionBudget va drain

PDB "shu Pod'lar to'plamidan ixtiyoriy ravishda bir vaqtda nechta yo'q bo'lishi mumkin" degan shartnoma.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: web }
spec:
  maxUnavailable: 1
  selector:
    matchLabels: { app: web }
```

- `minAvailable` yoki `maxUnavailable` (bittasi), son yoki foiz. `maxUnavailable` replica soni o'zgarganda o'zi moslashadi, shuning uchun odatda afzal.
- PDB **Eviction API** orqali ishlaydi. `kubectl drain` har Pod uchun eviction so'raydi, API server PDB'ni tekshiradi, budget tugagan bo'lsa 429 qaytaradi va drain kutib qayta urinadi.
- PDB himoya **qilmaydi**: node nosozligi, `kubectl delete pod` (bu eviction emas, to'g'ridan-to'g'ri o'chirish), Deployment rollout (uni `maxUnavailable`/`maxSurge` boshqaradi), preemption (best-effort hisobga olinadi).
- `kubectl get pdb` dagi `ALLOWED DISRUPTIONS` ustuni hozir nechta evict mumkinligini ko'rsatadi.

### Drain

```bash
kubectl cordon ha-worker2      # mark unschedulable, existing pods stay
kubectl drain ha-worker2 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon ha-worker2
```

`cordon` faqat yangi Pod'larni to'xtatadi. `drain` cordon qiladi va Pod'larni evict qiladi. DaemonSet Pod'lari evict qilinmaydi (controller baribir qayta yaratadi), shuning uchun `--ignore-daemonsets`. `emptyDir` ma'lumoti yo'qoladi, shuning uchun aniq flag talab qilinadi. Controller'siz yalang'och Pod bo'lsa drain rad etadi (`--force` bilan o'chiriladi va qayta yaratilmaydi).

**Tuzoq: drain'ni bloklaydigan PDB.** `replicas: 1` va `minAvailable: 1`, yoki `maxUnavailable: 0`: hech qachon evict qilib bo'lmaydi, node upgrade abadiy osilib qoladi. Xuddi shunday, Pod'lar o'zi `Ready` bo'lmasa budget nolga tushadi. Buning uchun `unhealthyPodEvictionPolicy: AlwaysAllow` bor: ready bo'lmagan Pod'ni budget'dan qat'i nazar evict qilishga ruxsat beradi.

## 5. Node o'chganda nima bo'ladi

1. Kubelet heartbeat (node `Lease`) to'xtaydi. Node controller taxminan 40–50 soniyadan keyin node'ni `NotReady` qiladi (`node-monitor-grace-period`).
2. Node'ga `node.kubernetes.io/unreachable:NoExecute` (yoki `not-ready`) taint qo'yiladi. Endpoint'lardan shu node'dagi Pod'lar darhol olib tashlanadi, ya'ni Service ularga trafik yubormaydi.
3. Har Pod'da default toleration bor: shu taint'larga `tolerationSeconds: 300`. 5 daqiqadan keyin Pod'lar o'chirishga belgilanadi va Deployment boshqa node'da yangisini yaratadi.

Demak default'da node o'limidan to'liq quvvat tiklanguncha taxminan 6 daqiqa. Shu vaqt ichida servis qolgan replica'larda ishlaydi, shuning uchun yoyish muhim. `tolerationSeconds` ni Pod spec'da kamaytirish mumkin (taint va toleration 12-darsda chuqur), lekin juda kichik qiymat qisqa tarmoq uzilishida keraksiz ko'chishlarga olib keladi.

StatefulSet Pod'lari (12-dars) boshqacha: node `NotReady` bo'lsa Pod `Terminating` da qoladi va yangisi yaratilmaydi, chunki controller eski nusxa haqiqatan to'xtaganiga ishonch hosil qila olmaydi (bir xil identifikatsiyali ikki Pod ma'lumotni buzadi).

## 6. PriorityClass va preemption

Resurs yetmaganda scheduler kimni qurbon qilishini bilishi kerak.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: business-critical }
value: 100000
globalDefault: false
description: "Customer-facing services"
```

- Pod `priorityClassName` bilan bog'lanadi. Katta `value` yuqoriroq.
- **Preemption**: yuqori ustuvor Pod `Pending` qolsa, scheduler past ustuvor Pod'larni evict qilib joy ochadi. PDB best-effort hisobga olinadi, lekin kafolatlanmaydi.
- `preemptionPolicy: Never`: navbatda oldinda turadi, lekin hech kimni siqib chiqarmaydi (batch uchun).
- O'rnatilgan class'lar: `system-cluster-critical`, `system-node-critical` (CoreDNS, kube-proxy kabi tizim Pod'lari uchun).
- Priority node bosimi ostidagi eviction tartibiga ham ta'sir qiladi (QoS bilan birga, 4-dars).

**Tuzoq: hamma narsaga yuqori priority.** Hamma muhim bo'lsa hech kim muhim emas. 3–4 class yetarli: tizim, production servis, default, batch.

## 7. Graceful shutdown

Pod o'chirilganda (rollout, drain, scale-down) ikki jarayon **parallel** boshlanadi:

```
delete Pod
 ├─ kubelet: preStop hook -> SIGTERM -> (wait up to terminationGracePeriodSeconds) -> SIGKILL
 └─ endpoints controller: remove Pod from EndpointSlice -> kube-proxy/ingress update rules
```

Ikkinchi shox bir necha soniya olishi mumkin (ayniqsa ingress controller yoki tashqi load balancer). Agar ilova SIGTERM olgan zahoti port'ni yopsa, hali yangilanmagan proxy'lar unga so'rov yuboradi va mijoz connection refused yoki 502 oladi.

Yechim uch qismdan:

1. **preStop kechikishi.** SIGTERM'dan oldin bir necha soniya kutish, shu vaqtda endpoint olib tashlanadi:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sleep", "10"]
terminationGracePeriodSeconds: 45
```

Yangi Kubernetes versiyalarida `exec` o'rniga o'rnatilgan `preStop.sleep.seconds` ham bor (image'da `sleep` binary'si bo'lmasa qulay).

2. **Ilova SIGTERM'ni to'g'ri qabul qiladi**: yangi ulanish qabul qilmaydi, jarayondagi so'rovlarni tugatadi, keyin chiqadi (Node'da `server.close()`). PID 1 muammosi: shell wrapper (`sh -c "node app.js"`) signal'ni uzatmaydi, Dockerfile'da exec shaklidagi `CMD ["node", "app.js"]` kerak (docker moduli).

3. **`terminationGracePeriodSeconds`** (default 30) preStop vaqtini ham o'z ichiga oladi. Muddat tugasa SIGKILL. Qiymat `preStop + eng uzun so'rov + zaxira` dan katta bo'lsin.

### Rollout paytida readiness

Yangi Pod readiness probe o'tgandan keyingina endpoint'ga qo'shiladi (4-dars), eski Pod esa yuqoridagi tartibda chiqadi. Zero-downtime uchun to'rttasi birga kerak: to'g'ri readiness probe, `maxUnavailable: 0` (yoki yetarli zaxira), preStop kechikishi, SIGTERM'ni to'g'ri qayta ishlash. `minReadySeconds` yangi Pod'ni "available" deb hisoblashdan oldin qo'shimcha kutadi va darhol yiqiladigan versiyani rollout'ning boshida to'xtatadi.

## Tuzoqlar

- Uchta replica, hammasi bitta node'da. `kubectl get pods -o wide` bilan tekshirilmagan HA mavjud emas.
- `required` anti-affinity va replica soni node sonidan ko'p: Pod'lar `Pending`, rollout to'xtaydi.
- `replicas: 1` ga `minAvailable: 1` PDB: node drain va cluster upgrade bloklanadi.
- PDB node nosozligidan himoya qiladi deb o'ylash.
- Topology spread scale-down va node qaytgandan keyin muvozanatni tiklaydi deb kutish.
- preStop'siz rollout: har deploy'da bir necha 502. Past trafikda sezilmaydi, yuqorida sezilarli.
- `terminationGracePeriodSeconds` preStop'dan kichik: Pod SIGTERM olmasdan SIGKILL bilan o'ladi.
- Shell wrapper ortidagi jarayon SIGTERM olmaydi, har Pod 30 soniya kutib SIGKILL bo'ladi, rollout va drain sekinlashadi.
- Ikki a'zoli etcd: bitta a'zodan yomonroq, chunki istalgan biri o'chsa quorum yo'qoladi.
- Zona label'isiz cluster'da zona bo'yicha spread yozish: `DoNotSchedule` bilan hamma Pod `Pending`.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ – voluntary va involuntary disruption, PDB
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/ – PDB sozlash
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/ – drain
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ – nodeSelector, affinity, anti-affinity
- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ – topology spread
- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ – PriorityClass, preemption
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination – Pod to'xtash tartibi
- https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/ – preStop
- https://kubernetes.io/docs/concepts/architecture/nodes/ – node holati, heartbeat
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/ – control plane HA topologiyalari
- https://etcd.io/docs/latest/faq/ – quorum va a'zolar soni
- https://github.com/kubernetes-sigs/descheduler – descheduler

---

## Vazifalar

Barchasini `kubernetes/11-high-availability/` da bajaring (`make new m=kubernetes n=11 name=high-availability`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. `kind-ha.yaml` va barcha manifestlar shu papkada. Sinov ilovasi sifatida o'z image'ingiz yoki `nginx` ishlatiladi; uzilishni o'lchash uchun cluster ichida alohida Pod'dan sikl bilan so'rov yuboring (`curl` yoki `wget`, har so'rov natijasini vaqt bilan yozadi).

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

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. README'da har sinov uchun vaqt o'lchovlari va xato so'rovlar soni bor.
3. `kind delete cluster --name ha` bajarilgan, `docker ps` da kind konteynerlari yo'q.
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
