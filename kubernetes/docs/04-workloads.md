# 4-dars: Workload turlari, Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet

Maqsad: Kubernetes'dagi asosiy workload obyektlarini mexanizm darajasida tushunish: Pod hayot sikli va to'xtash jarayoni, bir nechta konteynerli pod'lar (init va sidecar), probe'lar, resurs so'rovlari va limitlari, ReplicaSet egalik qilishi, Deployment strategiyalari, DaemonSet va StatefulSet'ning o'ziga xos xulqi, ConfigMap va Secret'ni iste'mol qilish. 3-darsda Deployment'ni "ishlaydigan quti" sifatida ishlatdingiz; bu darsda quti ochiladi. Bu yerdagi probe va resurs bilimlari 11-dars (high availability) va 14-dars (autoscaling) uchun shart, StatefulSet esa 12-darsda chuqur davom etadi.

Taxminiy vaqt: 4 kun (siz uchun). Eng ko'p vaqtni uch mavzuga bering: pod to'xtash ketma-ketligi (zero-downtime deploy shu yerda yutiladi yoki yutqaziladi), uch probe farqi, requests va limits'ning scheduler va kernel darajasidagi ta'siri.

## Laboratoriya

kind `dev` klasteri (1 control-plane + 2 worker, 3-darsdagi konfiguratsiya). Alohida namespace:

```bash
kubectl create namespace workloads
kubectl config set-context --current --namespace=workloads
```

Test image'lari: `nginx:1.28`, `busybox:1.36`, va Kubernetes test image'i `registry.k8s.io/e2e-test-images/agnhost:2.39` (`serve-hostname`, `netexec` rejimlari bor). Tozalash: `kubectl delete namespace workloads`.

---

## 1. Pod

Pod bu Kubernetes'dagi eng kichik deploy birligi: bir yoki bir nechta konteyner, ular umumiy network namespace (bitta IP, `localhost` orqali gaplashadi), umumiy volume'lar va bitta hayot sikliga ega. Pod "bitta mantiqiy host" modeli: asosiy ilova va unga yopishgan yordamchilar.

Pod o'lmas emas. U bir node'ga tayinlanadi va o'sha node'da yashab o'ladi; "ko'chirish" degan narsa yo'q, controller yangisini yaratadi. Shuning uchun yalang'och (controller'siz) pod production'da ishlatilmaydi.

### Faza va holatlar

| `status.phase` | Ma'nosi |
|----------------|---------|
| `Pending` | qabul qilingan, lekin konteynerlar hali ishga tushmagan (schedule kutish, image tortish) |
| `Running` | node'ga bog'langan, kamida bitta konteyner ishlayapti yoki ishga tushyapti |
| `Succeeded` | barcha konteynerlar 0 kod bilan tugagan, qayta ishga tushmaydi |
| `Failed` | barcha konteynerlar tugagan, kamida bittasi xato bilan |
| `Unknown` | node bilan aloqa yo'q |

`kubectl get pods` dagi `STATUS` ustuni faza emas, undan batafsilroq xulosa (`CrashLoopBackOff`, `Init:0/1`, `Terminating`). Har konteynerning o'z holati bor: `Waiting`, `Running`, `Terminated` (sabab va exit code bilan). Pod `conditions` i: `PodScheduled`, `Initialized`, `ContainersReady`, `Ready`. Service trafikni faqat `Ready` pod'larga yuboradi.

`restartPolicy`: `Always` (standart, Deployment uchun yagona variant), `OnFailure`, `Never` (Job'larda, 5-dars). Restart'ni kubelet o'sha node'da, o'sha pod ichida bajaradi.

### To'xtash ketma-ketligi

Pod o'chirilganda (rollout, drain, scale down):

1. API server pod'ga `deletionTimestamp` qo'yadi, `STATUS` `Terminating` bo'ladi.
2. Parallel ravishda ikki narsa boshlanadi: EndpointSlice controller pod'ni Service backend'laridan chiqaradi, kubelet esa to'xtatishni boshlaydi.
3. kubelet `preStop` hook bo'lsa uni bajaradi, keyin konteynerning 1-jarayoniga `SIGTERM` yuboradi.
4. `terminationGracePeriodSeconds` (standart 30 soniya, `preStop` vaqti ham shunga kiradi) ichida jarayon chiqmasa `SIGKILL`.

**Tuzoq: 2-qadamdagi poyga.** Pod `SIGTERM` olgan paytda barcha node'lardagi kube-proxy va ingress controller hali uni backend ro'yxatidan chiqarib ulgurmagan bo'lishi mumkin. Ilova darhol to'xtasa, yo'lda kelayotgan so'rovlar xato oladi. Standart yechim: `preStop` da bir necha soniya kutish va ilovada graceful shutdown (yangi ulanish olmaslik, ochiqlarini tugatish).

```yaml
        lifecycle:
          preStop:
            sleep: {seconds: 5}
```

**Tuzoq: `SIGTERM` yetib bormaydi.** Image `CMD` shell shaklida yozilgan bo'lsa (`CMD npm start`), 1-jarayon `sh` bo'ladi va signal ilovaga uzatilmaydi; pod har safar 30 soniya kutib `SIGKILL` oladi. Docker modulidagi exec shakli va PID 1 mavzusi aynan shu yerda kerak.

## 2. Bir nechta konteynerli pod'lar

| Tur | Qayerda yoziladi | Xulqi |
|-----|------------------|-------|
| App container | `spec.containers` | parallel ishga tushadi, pod umri davomida ishlaydi |
| Init container | `spec.initContainers` | asosiylardan oldin, ketma-ket, har biri muvaffaqiyatli tugashi shart |
| Sidecar container | `spec.initContainers` + `restartPolicy: Always` | init tartibida ishga tushadi, lekin tugashini kutilmaydi, pod bilan birga yashaydi |

Init container ishlatiladi: bog'liqlikni kutish, migratsiya, konfiguratsiya generatsiya qilish, volume'ga fayl tayyorlash. Init container muvaffaqiyatsiz bo'lsa pod `Init:Error` yoki `Init:CrashLoopBackOff` da qoladi, asosiy konteynerlar boshlanmaydi.

Native sidecar (1.33 dan stable) oddiy "ikkinchi konteyner" usulidan uch jihati bilan yaxshi: asosiy konteynerdan oldin ishga tushishi kafolatlanadi, pod to'xtaganda asosiy konteynerdan keyin to'xtaydi, va Job'da asosiy konteyner tugagach pod'ning tugashiga to'sqinlik qilmaydi.

```yaml
    spec:
      initContainers:
      - name: logshipper
        image: busybox:1.36
        restartPolicy: Always           # this makes it a sidecar
        command: ['sh', '-c', 'tail -F /var/log/app/app.log']
        volumeMounts: [{name: logs, mountPath: /var/log/app}]
```

Qoida: bitta pod'ga faqat birga masshtablanadigan va birga yashab o'ladigan konteynerlar qo'yiladi. Frontend va backend alohida pod'lar, chunki ular mustaqil masshtablanadi va yangilanadi.

## 3. Probe'lar

kubelet konteynerni davriy tekshiradi. Uch tur, uch xil oqibat:

| Probe | Savol | Muvaffaqiyatsiz bo'lsa |
|-------|-------|------------------------|
| `startupProbe` | ilova ishga tushib bo'ldimi? | muvaffaqiyatli bo'lguncha boshqa probe'lar ishlamaydi; limit tugasa konteyner o'ldiriladi |
| `livenessProbe` | ilova tirikmi yoki osilib qolganmi? | konteyner qayta ishga tushiriladi |
| `readinessProbe` | ilova hozir trafik qabul qila oladimi? | pod `Ready` emas, Service backend'laridan chiqariladi, konteynerga tegilmaydi |

Tekshirish usullari: `httpGet` (200–399 muvaffaqiyat), `tcpSocket`, `exec` (exit code 0), `grpc`.

| Parametr | Standart | Ma'nosi |
|----------|----------|---------|
| `initialDelaySeconds` | 0 | birinchi tekshiruvgacha kutish |
| `periodSeconds` | 10 | tekshiruvlar oralig'i |
| `timeoutSeconds` | 1 | javob kutish vaqti |
| `failureThreshold` | 3 | ketma-ket nechta xatodan keyin harakat |
| `successThreshold` | 1 | ketma-ket nechta muvaffaqiyatdan keyin tiklangan hisoblanadi |

```yaml
        readinessProbe:
          httpGet: {path: /healthz, port: 80}
          periodSeconds: 5
        livenessProbe:
          httpGet: {path: /healthz, port: 80}
          failureThreshold: 3
        startupProbe:
          httpGet: {path: /healthz, port: 80}
          failureThreshold: 30      # up to 30 * 10s to start
```

**Tuzoq: liveness probe tashqi bog'liqlikni tekshiradi.** Liveness endpoint'i ma'lumotlar bazasiga murojaat qilsa, baza sekinlashganda barcha pod'lar bir vaqtda "o'lik" deb topilib qayta ishga tushadi va kichik muammo to'liq uzilishga aylanadi. Liveness faqat jarayonning o'zini tekshiradi ("men osilib qolmadimmi"). Bog'liqliklar readiness'da, uni ham ehtiyotkorlik bilan.

**Tuzoq: probe'siz Deployment.** Probe yo'q bo'lsa konteyner jarayoni boshlangan zahoti pod `Ready` hisoblanadi. Rolling update eski pod'larni yangi ilova hali so'rov qabul qila olmayotgan paytda o'chiradi.

## 4. Resurslar: requests, limits, QoS

```yaml
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits:   {memory: 256Mi}
```

| | `requests` | `limits` |
|---|------------|----------|
| Kim ishlatadi | scheduler: node'da shuncha bo'sh joy bormi | kubelet va kernel (cgroup) |
| CPU | raqobat paytida kafolatlangan ulush | oshsa throttling: jarayon sekinlashadi, o'ldirilmaydi |
| Memory | scheduler hisobi | oshsa konteyner OOM kill qilinadi (exit code 137, `OOMKilled`) |

Birliklar: CPU `1` bu bitta yadro, `100m` bu 0.1 yadro. Memory `Mi`, `Gi` (ikkilik) yoki `M`, `G` (o'nlik). `128m` memory bu 0.128 bayt, klassik xato.

Scheduler haqiqiy iste'molga emas, `requests` yig'indisiga qaraydi. Node "bo'sh" ko'rinsa ham requests to'lgan bo'lsa pod `Pending` qoladi; aksincha, requests'siz pod'lar node'ni haqiqatda to'ldirib yuborishi mumkin.

### QoS class

Kubernetes pod'ga requests va limits asosida sinf beradi (`status.qosClass`). Node'da xotira tugaganda kubelet shu tartibda evict qiladi:

| Sinf | Sharti | Eviction navbati |
|------|--------|------------------|
| `BestEffort` | hech bir konteynerda requests ham, limits ham yo'q | birinchi |
| `Burstable` | qolgan barcha holatlar | ikkinchi, request'idan ko'p ishlatayotganlari oldin |
| `Guaranteed` | har konteynerda CPU va memory uchun requests = limits | oxirgi |

Amaliy tavsiyalar: memory uchun har doim request va limit qo'ying (ko'pincha teng); CPU request har doim, CPU limit esa bahsli (throttling latency'ni buzadi, ko'p jamoalar CPU limit qo'ymaydi). Namespace darajasida standart qiymatlar LimitRange, umumiy chegara ResourceQuota bilan beriladi.

Ishlab turgan pod'ning CPU va memory qiymatlarini pod'ni qayta yaratmasdan o'zgartirish (in-place resize, `kubectl patch --subresource=resize`) 1.35 dan stable.

## 5. ReplicaSet

ReplicaSet bitta ishni qiladi: selector'ga mos pod'lar soni `replicas` ga teng bo'lishini ta'minlaydi. Kam bo'lsa template'dan yaratadi, ko'p bo'lsa o'chiradi.

- Egalik `metadata.ownerReferences` orqali belgilanadi. Selector'ga mos, lekin egasiz pod uchrasa ReplicaSet uni "asrab oladi" (adoption).
- ReplicaSet template o'zgarishini mavjud pod'larga qo'llamaydi. Shuning uchun uni to'g'ridan-to'g'ri ishlatmaysiz: yangilashni Deployment boshqaradi.
- Deployment har pod template uchun alohida ReplicaSet yaratadi va uni `pod-template-hash` label'i bilan ajratadi. Shu label tufayli eski va yangi ReplicaSet'lar bir-birining pod'larini olib qo'ymaydi.

## 6. Deployment strategiyalari

| `strategy.type` | Xulqi | Qachon |
|-----------------|-------|--------|
| `RollingUpdate` (standart) | yangi pod'lar bosqichma-bosqich qo'shiladi, eskilari olib tashlanadi | ikki versiya bir vaqtda ishlay oladigan stateless ilovalar |
| `Recreate` | avval barcha eskilari o'chiriladi, keyin yangilari yaratiladi | ikki versiya birga ishlay olmasa, yoki volume faqat bitta pod'ga ulanadigan bo'lsa. Uzilish bo'ladi |

RollingUpdate parametrlari:

- `maxSurge`: kerakli sondan nechta ortiq pod bo'lishi mumkin (standart 25%, yuqoriga yaxlitlanadi).
- `maxUnavailable`: nechta pod mavjud bo'lmasligi mumkin (standart 25%, pastga yaxlitlanadi).
- `minReadySeconds`: pod `Ready` bo'lgach necha soniya barqaror tursa "available" hisoblanadi.
- `progressDeadlineSeconds` (standart 600): shu vaqtda oldinga siljish bo'lmasa rollout `ProgressDeadlineExceeded` bilan belgilanadi. Avtomatik rollback yo'q.

`maxSurge: 1, maxUnavailable: 0` sig'imni hech qachon kamaytirmaydi, lekin qo'shimcha resurs talab qiladi. `maxSurge: 0, maxUnavailable: 1` qo'shimcha resurssiz, lekin vaqtincha sig'im kamayadi. Ikkalasi bir vaqtda 0 bo'la olmaydi.

Blue-green va canary Deployment'ning o'zida yo'q. Ular ikki Deployment va Service selector'i (yoki Gateway API vaznlari, yoki Argo Rollouts kabi vosita) bilan quriladi.

## 7. DaemonSet

DaemonSet har (mos) node'da aynan bitta pod bo'lishini ta'minlaydi. Node qo'shilsa pod avtomatik paydo bo'ladi. `replicas` maydoni yo'q.

Ishlatilishi: node darajasidagi agentlar: log yig'uvchi, monitoring exporter (`node-exporter`), CNI plugin, kube-proxy, storage plugin'ning node qismi.

- Qaysi node'larda ishlashi `nodeSelector` yoki affinity bilan cheklanadi.
- Control plane node'larida taint bor (`node-role.kubernetes.io/control-plane:NoSchedule`). DaemonSet u yerda ham ishlashi uchun mos `tolerations` kerak (taint va toleration 12-darsda chuqur).
- `updateStrategy`: `RollingUpdate` (standart, `maxUnavailable: 1`) yoki `OnDelete` (pod qo'lda o'chirilgandagina yangilanadi).

## 8. StatefulSet asoslari

Deployment pod'lari bir xil va almashtiriladigan: nomi tasodifiy, tartib yo'q. Ma'lumotlar bazasi, navbat tizimi kabi ilovalarda har nusxaning o'z shaxsi kerak. StatefulSet shuni beradi:

| Xususiyat | Deployment | StatefulSet |
|-----------|------------|-------------|
| Pod nomi | `web-7d4b9c-x2k8p` | `web-0`, `web-1`, `web-2` |
| Qayta yaratilganda | yangi nom | o'sha nom |
| Tartib | parallel | `0` dan boshlab ketma-ket, oldingisi `Ready` bo'lgach (o'chirish teskari tartibda) |
| Tarmoq shaxsi | faqat Service orqali | har pod uchun barqaror DNS nomi (headless Service orqali) |
| Storage | hamma pod bitta PVC'ni bo'lishadi | `volumeClaimTemplates`: har pod'ga o'z PVC'si |

StatefulSet `spec.serviceName` da headless Service (`clusterIP: None`) nomini talab qiladi; pod DNS nomi `web-0.<service>.<namespace>.svc.cluster.local` ko'rinishida bo'ladi (6-dars).

**Tuzoq: StatefulSet replikatsiya qilmaydi.** U faqat barqaror nom, tartib va storage beradi. Ma'lumotlar bazasi nusxalari orasidagi replikatsiya, failover, zaxira ilovaning yoki operator'ning ishi. Bu 12-darsning mavzusi.

## 9. ConfigMap va Secret'ni iste'mol qilish

| Usul | Sintaksis | Yangilanadimi |
|------|-----------|---------------|
| Bitta kalit env sifatida | `env[].valueFrom.configMapKeyRef` yoki `secretKeyRef` | yo'q, faqat yangi pod'da |
| Barcha kalitlar env sifatida | `envFrom[].configMapRef` yoki `secretRef` | yo'q |
| Fayllar sifatida | `volumes[].configMap` yoki `secret` | ha, kechikish bilan (`subPath` bundan mustasno) |

Secret tuzilishi ConfigMap bilan deyarli bir xil, farqlari: qiymatlar `data` da base64 ko'rinishida (yoki `stringData` da oddiy matn), node'da volume `tmpfs` da saqlanadi, RBAC bilan alohida cheklanadi.

**Tuzoq: base64 shifrlash emas.** Secret'ni o'qiy olgan har kim uni `base64 -d` bilan ochadi. Standart holatda Secret etcd'da ham shifrlanmagan saqlanadi (encryption at rest alohida yoqiladi). Secret manifestini git'ga commit qilish parolni commit qilish bilan teng. To'g'ri boshqaruv (Sealed Secrets, External Secrets, Vault) 13-darsda.

Env yoki volume? Env sodda, lekin `kubectl describe`, crash dump va bola jarayonlarga oqib chiqishi oson, va yangilanmaydi. Maxfiy ma'lumot uchun fayl afzal. `immutable: true` ConfigMap va Secret'ni o'zgarmas qiladi: tasodifiy o'zgarishdan himoya va kubelet uchun kamroq yuk.

## Tuzoqlar

- Probe'siz yoki noto'g'ri probe'li Deployment: rolling update paytida so'rovlar yo'qoladi.
- Liveness probe'da tashqi bog'liqlikni tekshirish: kaskadli restart.
- `preStop` va graceful shutdown yo'qligi: har deploy'da bir nechta 502.
- Shell shaklidagi `CMD`: `SIGTERM` ilovaga yetmaydi, har to'xtash 30 soniya.
- Requests'siz pod'lar: scheduler ko'r, node haddan tashqari to'ladi, birinchi bo'lib sizning pod'ingiz evict qilinadi.
- Memory limit'ni ilovaning haqiqiy ehtiyojidan past qo'yish (JVM, Node.js heap sozlamalarini hisobga olmasdan): tushunarsiz `OOMKilled`.
- `128m` memory yozish (`128Mi` o'rniga).
- Bitta volume'li ilovada `RollingUpdate`: yangi pod volume bo'shashini kutib osilib qoladi.
- StatefulSet'ni "tayyor klasterlangan baza" deb o'ylash.
- Secret manifestini git'ga qo'yish, parolni env orqali berib log'ga chiqarib yuborish.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/ – pod hayot sikli, to'xtash, probe'lar
- https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ – init container
- https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/ – sidecar container
- https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/ – probe'lar
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ – requests va limits
- https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/ – QoS class
- https://kubernetes.io/docs/concepts/workloads/controllers/ – ReplicaSet, Deployment, DaemonSet, StatefulSet
- https://kubernetes.io/docs/concepts/configuration/secret/ – Secret
- Lukša, "Kubernetes in Action" (2-nashr), pod va controller boblari

---

## Vazifalar

Barchasini `kubernetes/04-workloads/` papkasida bajaring (`make new m=kubernetes n=04 name=workloads`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Har vazifaning manifesti `task_N.yaml` nomi bilan saqlanadi. Hammasi `workloads` namespace'ida.

### A. Pod

1. **Bare pod.** Controller'siz bitta nginx pod'i yarating va uni o'chiring: qayta yaratildimi? Keyin pod ishlab turgan node'ni toping va `docker stop` bilan o'sha kind node konteynerini to'xtating (worker bo'lsin). Bir necha daqiqa kuzating: pod bilan nima bo'ldi? Node'ni `docker start` bilan qaytaring. Xuddi shu tajribani Deployment pod'i bilan solishtiring va xulosa yozing.

2. **Pod phases.** `busybox` pod'ini `sh -c 'sleep 15; exit 1'` buyrug'i bilan uch marta ishga tushiring: `restartPolicy` `Always`, `OnFailure` va `Never`. Har birida `kubectl get pod -w` natijasini, yakuniy `phase` ni va `RESTARTS` ni yozing. `exit 0` bilan `OnFailure` qanday tugaydi?

3. **Graceful shutdown.** Ikki pod yozing. Birinchisi `sh -c 'trap "echo got TERM; exit 0" TERM; while true; do sleep 1; done'`, ikkinchisi `SIGTERM` ni e'tiborsiz qoldiradi (oddiy `sleep 3600` ni shell orqali ishga tushirish yetarli). Har birini `time kubectl delete pod` bilan o'chiring. Vaqt farqini izohlang. Ikkinchisiga `terminationGracePeriodSeconds: 5` qo'yib qayta o'lchang.

4. **Shared namespaces.** Ikki konteynerli pod: nginx va `busybox` (`sleep 3600`). busybox ichidan `wget -qO- localhost` ishlashini ko'rsating. Ikkalasiga umumiy `emptyDir` ulang, busybox'dan `index.html` yozing va nginx uni qaytarishini tekshiring. Konteynerlar nimani bo'lishadi, nimani bo'lishmaydi (fayl tizimi, jarayonlar ro'yxati, tarmoq)?

### B. Init va sidecar

5. **Init container.** Pod yozing: init container `nslookup backend` muvaffaqiyatli bo'lguncha siklda kutadi, asosiy konteyner nginx. Pod'ni yarating va `STATUS` ustunini kuzating. `kubectl logs POD -c <init>` ni ko'ring. Keyin `backend` nomli Service yarating va pod qanday davom etishini yozing. Init container xato bilan tugasa nima bo'lishini alohida sinang.

6. **Native sidecar.** Deployment yozing: asosiy konteyner har soniyada umumiy `emptyDir` dagi faylga qator yozadi, sidecar (`initContainers` + `restartPolicy: Always`) uni `tail -F` qiladi. `kubectl logs -c` bilan sidecar chiqishini ko'rsating. `kubectl get pod` da `READY` ustuni nechta konteyner ko'rsatyapti? Sidecar buyrug'ini vaqtincha 20 soniyadan keyin xato bilan chiqadigan qilib o'zgartiring (`sleep 20; exit 1`): sidecar tugaganda pod'ga va asosiy konteynerga nima bo'ldi? Oddiy "ikkinchi konteyner" usulidan uchta farqini yozing.

### C. Probe'lar

7. **Readiness probe.** 3 replikali nginx Deployment'iga `/ready` fayli mavjudligini tekshiradigan `exec` yoki `httpGet` readiness probe qo'shing va Service yarating. Bitta pod'da faylni o'chiring. `kubectl get pods`, `kubectl get endpointslices` va pod `RESTARTS` qiymatini ko'rsating. Pod qayta ishga tushdimi? Faylni qaytaring va tiklanishni kuzating.

8. **Liveness probe.** Xuddi shunday tajribani liveness probe bilan qiling. Natija 7-vazifadan nimasi bilan farq qiladi? `describe pod` dagi event'larni yozing. `periodSeconds` va `failureThreshold` qiymatlaringizdan kelib chiqib, nosozlikdan restart'gacha qancha vaqt o'tishi kerakligini hisoblang va o'lchangan vaqt bilan solishtiring.

9. **Startup probe.** Sekin ishga tushadigan ilovani imitatsiya qiling: konteyner 40 soniyadan keyingina `/healthz` ga javob bersin (masalan, `sleep 40` dan keyin nginx'ni ishga tushiradigan buyruq). Faqat liveness probe (standart parametrlar) bilan nima bo'lishini ko'rsating. Keyin `initialDelaySeconds` bilan va `startupProbe` bilan ikki xil tuzating. Qaysi yechim yaxshiroq va nima uchun?

### D. Resurslar

10. **QoS classes.** Uchta pod yozing, har biri boshqa QoS sinfiga tushsin. `kubectl get pod -o jsonpath='{.status.qosClass}'` bilan tasdiqlang. Faqat `limits` berilgan (requests'siz) pod qaysi sinfga tushadi va nima uchun? Node xotirasi tugaganda ular qaysi tartibda evict qilinadi?

11. **OOMKilled.** `polinux/stress` image'i bilan pod yozing: memory limit `100Mi`, buyruq `stress --vm 1 --vm-bytes 250M --vm-hang 1`. Pod holatini, `describe pod` dagi `Last State`, `Reason` va exit code'ni yozing. 137 raqami qayerdan kelishini izohlang. `--vm-bytes` ni limitdan past qilib ishlashini ko'rsating.

12. **Requests and scheduling.** `kubectl describe node` dagi `Allocatable` va `Allocated resources` bo'limlarini o'qing. Bitta worker'ning bo'sh CPU'sidan biroz kam `requests.cpu` bilan pod yarating, keyin xuddi shunday ikkinchi va uchinchisini. Qaysi biri `Pending` qoldi? Shu paytda node'lar haqiqatda band emasligini qanday izohlaysiz? Requests'siz pod shu holatda joylasha oladimi?

### E. Controller'lar

13. **ReplicaSet ownership.** `app=rs-demo` selector'li 3 replikali ReplicaSet yarating. Keyin xuddi shu label'li yalang'och pod yarating: nima bo'ldi va nima uchun? ReplicaSet template'idagi image'ni o'zgartirib `apply` qiling: mavjud pod'lar yangilandimi? `kubectl delete rs --cascade=orphan` bilan ReplicaSet'ni o'chiring va pod'lar holati hamda `ownerReferences` ni ko'rsating.

14. **Rollout math.** 4 replikali Deployment'ni uch konfiguratsiyada yangilang va har birida `kubectl get pods -w` orqali bir vaqtdagi eng ko'p va eng kam `Ready` pod sonini yozing: `maxSurge: 1, maxUnavailable: 0`; `maxSurge: 0, maxUnavailable: 1`; `strategy.type: Recreate`. Standart 25%/25% da 4 replika uchun bu sonlar nechaga teng bo'ladi? Ikkalasini 0 qilib ko'ring va xatoni yozing.

15. **Stuck rollout.** Readiness probe'li Deployment'ni (`maxUnavailable: 0`) readiness'i hech qachon o'tmaydigan versiyaga yangilang. Rollout qayerda to'xtadi, nechta eski va yangi pod bor, Service ishlayaptimi? `progressDeadlineSeconds: 60` qo'yib, `kubectl rollout status` va Deployment `conditions` ida nima paydo bo'lishini ko'rsating. Kubernetes o'zi rollback qildimi?

16. **DaemonSet.** `busybox` (`sleep`) bilan DaemonSet yarating. Nechta pod paydo bo'ldi va qaysi node'larda? Control plane node'ida nima uchun yo'q? Toleration qo'shib u yerda ham ishga tushiring. Keyin `nodeSelector` bilan faqat `disk=ssd` label'li node'larga cheklang va bitta worker'ga shu label'ni qo'ying, olib tashlang: pod'lar qanday o'zgardi?

17. **StatefulSet identity.** Headless Service va 3 replikali nginx StatefulSet yarating (storage'siz). Pod'lar qanday tartibda va qanday nomlar bilan paydo bo'ldi? `web-1` ni o'chiring: yangi pod'ning nomi va IP'si qanday? Vaqtinchalik pod'dan `nslookup web-0.<service>` ni tekshiring. 2 ga scale down qilganda qaysi pod o'chdi? Deployment bilan uchta farqni yozing.

### F. Konfiguratsiya

18. **ConfigMap as env and volume.** Bitta ConfigMap'ni bitta pod'ga ikki usulda bering: `envFrom` va volume. ConfigMap qiymatini o'zgartiring va 2 daqiqa davomida pod ichida env (`kubectl exec ... env`) va faylni kuzating. Qaysi biri yangilandi? Volume ichidagi fayllar aslida nima ekanini (`ls -la` bilan symlink zanjiri) ko'rsating va bu atomar yangilanishni qanday ta'minlashini izohlang.

19. **Secret.** `kubectl create secret generic` bilan Secret yarating (qiymatni README'ga yozmang). `kubectl get secret -o yaml` dagi qiymatni dekodlang va bu nimani isbotlashini yozing. Secret'ni volume sifatida ulab, pod ichida fayl ruxsatlarini va `mount` chiqishidagi fayl tizimi turini ko'ring. `defaultMode: 0400` qo'shing. Nima uchun Secret manifesti bu papkaga commit qilinmaydi va uning o'rniga nimani saqlaysiz?

20. **Missing key.** Pod'da ConfigMap'ning mavjud bo'lmagan kalitiga `configMapKeyRef` bilan murojaat qiling. Pod holati va event'ini yozing. `optional: true` qo'shsangiz nima o'zgaradi? Bu flag qachon o'rinli va qachon xavfli?

### G. Yakuniy

21. **Production-ready Deployment.** `task_21.yaml` yozing: nginx (yoki `agnhost`) Deployment'i, 3 replika, uchala probe (o'rinli parametrlar bilan), requests va limits (`Burstable` yoki `Guaranteed`, tanlovni asoslang), `preStop` kutish va mos `terminationGracePeriodSeconds`, `maxSurge: 1, maxUnavailable: 0`, konfiguratsiya ConfigMap'dan volume sifatida, plus Service. Isbot: (a) `kubectl port-forward` o'rniga klaster ichidagi vaqtinchalik pod'dan Service'ga har 100 ms da so'rov yuboradigan sikl ishlatib, rollout paytida bitta ham xato bo'lmasligini ko'rsating; (b) `preStop` ni olib tashlab tajribani takrorlang va natijani solishtiring; (c) README'da har sozlama qaysi nosozlikdan himoya qilishini bir qatordan yozing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar `task_N.yaml` ko'rinishida papkada.
2. `make check` toza o'tadi (`yamllint`).
3. Papkada Secret manifesti yoki maxfiy qiymat yo'q.
4. `workloads` namespace'i o'chirilgan, to'xtatilgan kind node'lari qayta yoqilgan.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Pod o'chirilganda qanday qadamlar sodir bo'ladi va `preStop` kutish qaysi muammoni yechadi?
- Uch probe'ning har biri muvaffaqiyatsiz bo'lganda nima bo'ladi?
- Liveness probe'da ma'lumotlar bazasini tekshirish nima uchun xavfli?
- `requests` va `limits` ni kim ishlatadi? CPU limiti oshsa nima bo'ladi, memory limiti oshsa-chi?
- Uch QoS sinfi qanday aniqlanadi va nimaga ta'sir qiladi?
- Deployment, ReplicaSet va Pod orasidagi munosabat qanday? `pod-template-hash` nima uchun kerak?
- `maxSurge` va `maxUnavailable` qanday kelishuvni (trade-off) boshqaradi?
- DaemonSet va StatefulSet qaysi muammolar uchun yaratilgan?
- Init container va sidecar container farqi nima?
- Secret ConfigMap'dan nimasi bilan farq qiladi va nimasi bilan farq qilmaydi?
