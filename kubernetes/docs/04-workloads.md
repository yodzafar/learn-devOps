# 4-dars: Workload turlari, Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet

Maqsad: Kubernetes'dagi asosiy workload obyektlarini (ilovani ishga tushiradigan obyektlar) mexanizm darajasida tushunish: Pod hayot sikli va to'xtash jarayoni, bir nechta konteynerli pod'lar (init va sidecar), probe'lar, resurs so'rovlari va limitlari, ReplicaSet egaligi, Deployment strategiyalari, DaemonSet va StatefulSet'ning o'ziga xos xulqi, ConfigMap va Secret'ni iste'mol qilish. 3-darsda Deployment'ni "ishlaydigan quti" sifatida ishlatdingiz; bu darsda quti ochiladi. Bu yerdagi probe va resurs bilimlari 11-dars (high availability) va 14-dars (autoscaling) uchun shart, StatefulSet esa 12-darsda chuqur davom etadi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A, B guruhlar; ikkinchi kun 4–5 bo'limlar va C, D guruhlar; uchinchi kun 6–9 bo'limlar, "Birga bajaramiz" va E guruh; to'rtinchi kun 10-bo'lim, F va G guruhlar, README. Eng ko'p vaqtni uch mavzuga bering: pod to'xtash ketma-ketligi (zero-downtime deploy shu yerda yutiladi yoki yutqaziladi), uch probe farqi, requests va limits'ning scheduler va kernel darajasidagi ta'siri.

## Qanday o'qish kerak

Har bo'limdagi manifestni vaqtinchalik papkada (`~/k4-scratch`, repo'dan tashqarida) o'zingiz yozib `kubectl apply -f` qiling va chiqishni darsdagi izoh bilan solishtiring. Pod nomlaridagi tasodifiy qism, IP, vaqt va node nomi sizda boshqacha bo'ladi, bunday joylar `<...>` bilan belgilangan. Natijani o'qishda ustun nomlariga e'tibor bering: `STATUS`, `READY`, `RESTARTS` uchta har xil narsani aytadi. Har buyruqdan keyin "bu holatni qaysi komponent yaratdi" deb so'rang (API server, scheduler, controller yoki kubelet, 1-dars). Workload'larni tushunishning kaliti shu savol.

## Laboratoriya

Hamma narsa host'dagi kind `dev` klasterida (1 control-plane + 2 worker, 2-darsdagi `kind-multi.yaml`, 3-darsda shu nom bilan qayta yaratilgan). kind node'lari oddiy Docker konteynerlari, shuning uchun `kubectl` va `docker` buyruqlari ikkala mashinada bir xil. Multipass VM'lar bu darsda kerak emas: haqiqiy node o'chishi 1-vazifada kind node konteynerini to'xtatish bilan imitatsiya qilinadi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `kind`, `kubectl` | 2-darsda rasmiy binary (`linux-amd64`) | 2-darsda `brew install kind kubectl` (`arm64`) |
| kind node'lari qayerda | host Docker Engine'ida, `docker ps` da `dev-control-plane`, `dev-worker`, `dev-worker2` | Docker Desktop'ning yashirin Linux VM'ida, `docker ps` da xuddi shu nomlar |
| Node resurslari (`kubectl describe node`) | har node host'ning barcha CPU va RAM'ini ko'rsatadi | har node Docker Desktop VM'iga ajratilgan CPU va RAM'ni ko'rsatadi (Settings, Resources). Kamida 6 GB bering |
| `docker stop dev-worker` (1-vazifa) | ishlaydi | ishlaydi, bir xil |
| `time kubectl ...` (3-vazifa) | bash formati: `real 0m31.2s` | zsh formati: qator oxirida `31.234 total` |
| Image'lar | `nginx:1.28`, `busybox:1.36`, `agnhost:2.39` `amd64` varianti | xuddi shu tag'lar, `arm64` varianti (uchalasi multi-arch) |
| Pod IP'lari | host'dan `curl` qilib bo'lmaydi (kind tarmog'i ichida) | xuddi shunday; har ikkalasida klaster ichidagi vaqtinchalik pod yoki `port-forward` ishlating |

Klaster ishlab turganini tekshiring va alohida namespace yarating:

```
$ kubectl config current-context
kind-dev
$ kubectl get nodes
NAME                STATUS   ROLES           AGE   VERSION
dev-control-plane   Ready    control-plane   <..>  v1.<..>
dev-worker          Ready    <none>          <..>  v1.<..>
dev-worker2         Ready    <none>          <..>  v1.<..>
$ kubectl create namespace workloads
namespace/workloads created
$ kubectl config set-context --current --namespace=workloads
Context "kind-dev" modified.
```

Test image'lari: `nginx:1.28`, `busybox:1.36` va Kubernetes test image'i `registry.k8s.io/e2e-test-images/agnhost:2.39` (bitta binary ichida ko'p rejim: `netexec` HTTP server, `serve-hostname` pod nomini qaytaradi). Uchalasi `amd64` va `arm64` uchun mavjud.

- **Ikkinchi mashinada tiklash**: klaster holati git orqali ko'chmaydi. Boshqa mashinada `kind get clusters` da `dev` yo'q bo'lsa `kind create cluster --name dev --config kubernetes/02-cluster-setup/kind-multi.yaml`, keyin yuqoridagi namespace buyruqlari va kerakli `task_N.yaml` larni qayta `apply` qiling. Pod'lar, event'lar va restart hisoblagichlari yangidan boshlanadi, bu normal.
- **Tozalash**: `kubectl delete namespace workloads`. 1-vazifada to'xtatilgan node'ni `docker start dev-worker` bilan albatta qaytaring.

---

## 1. Pod: eng kichik birlik va uning hayot sikli

### Bu nima

Pod Kubernetes'dagi eng kichik deploy birligi: bir yoki bir nechta konteyner, ular umumiy network namespace (bitta IP, bir-biriga `localhost` orqali murojaat qiladi), umumiy volume'lar va bitta hayot sikliga ega. Pod "bitta mantiqiy host" modeli: asosiy ilova va unga yopishgan yordamchilar. Docker modulida ko'rgan konteyner (Docker 1-dars) pod ichidagi bitta qism.

Pod o'lmas emas. U bitta node'ga tayinlanadi va o'sha node'da yashab o'ladi; "ko'chirish" degan narsa yo'q, controller (1-darsdagi reconciliation loop'ni bajaruvchi jarayon) yangisini yaratadi. Shuning uchun yalang'och (controller'siz) pod production'da ishlatilmaydi.

### Mexanizm: faza, konteyner holati, condition'lar

Pod holati uch qatlamda yoziladi. Birinchisi `status.phase`, umumiy faza:

| `status.phase` | Ma'nosi |
|----------------|---------|
| `Pending` | qabul qilingan, lekin konteynerlar hali ishga tushmagan (schedule kutish, image tortish) |
| `Running` | node'ga bog'langan, kamida bitta konteyner ishlayapti yoki ishga tushyapti |
| `Succeeded` | barcha konteynerlar 0 kod bilan tugagan, qayta ishga tushmaydi |
| `Failed` | barcha konteynerlar tugagan, kamida bittasi xato bilan |
| `Unknown` | node bilan aloqa yo'q |

Ikkinchisi har konteynerning o'z holati: `Waiting` (sabab bilan, masalan `ImagePullBackOff`), `Running`, `Terminated` (sabab va exit code bilan). Uchinchisi pod `conditions`: `PodScheduled`, `Initialized`, `ContainersReady`, `Ready`. Service trafikni faqat `Ready` condition'i `True` bo'lgan pod'larga yuboradi.

`kubectl get pods` dagi `STATUS` ustuni faza emas: kubectl uchala qatlamdan eng foydali qisqa xulosani chiqaradi (`CrashLoopBackOff`, `Init:0/1`, `Terminating`, `Completed`).

`restartPolicy` pod darajasidagi maydon: `Always` (standart, Deployment uchun yagona ruxsat etilgan qiymat), `OnFailure`, `Never` (Job'larda, 5-dars). Restart'ni kubelet o'sha node'da, o'sha pod ichida bajaradi: pod nomi va IP'si o'zgarmaydi, faqat `RESTARTS` oshadi. Ketma-ket qulashlar orasidagi kutish eksponensial oshadi (10 s, 20 s, 40 s va hokazo, 5 daqiqagacha), shu kutish `CrashLoopBackOff` deb ko'rinadi.

### Misol

```
$ kubectl run once --image=busybox:1.36 --restart=Never -- sh -c 'echo hi; exit 3'
pod/once created
$ kubectl get pod once
NAME   READY   STATUS   RESTARTS   AGE
once   0/1     Error    0          6s
$ kubectl get pod once -o jsonpath='{.status.phase}{"\n"}'
Failed
$ kubectl get pod once -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}{"\n"}'
3
```

`kubectl run ... --restart=Never` controller'siz yalang'och pod yaratadi. `STATUS Error` bu kubectl xulosasi, haqiqiy faza `Failed` (ikkinchi buyruq). `READY 0/1`: bitta konteynerdan nolta tayyor. `RESTARTS 0`, chunki `Never`. Uchinchi buyruq konteyner holatidan exit code'ni oldi: aynan `exit 3`. `--restart=Always` bilan yaratilsa xuddi shu buyruq `CrashLoopBackOff` va o'sib boruvchi `RESTARTS` beradi. Tozalash: `kubectl delete pod once`.

### Real ishda qachon kerak

- Nosozlikda birinchi qadam: `STATUS` qisqa xulosa, aniq sabab esa `describe pod` dagi konteyner `State` va `Last State` da (3-dars, 8-bo'lim).
- Monitoring'da faza emas, `Ready` condition va restart soni kuzatiladi (observability moduli).
- `restartPolicy` ni to'g'ri tanlash Job dizaynining asosi (5-dars).

### Nima uchun shunday

Kubernetes pod'ni "qoramol, uy hayvoni emas" deb ko'radi: alohida pod'ni davolash o'rniga uni tashlab, yangisini yaratish arzonroq va oldindan aytib bo'ladi. Shu sabab pod node'ga bog'langan va ko'chmaydi; ko'chirish murakkab (xotira, ochiq ulanishlar) va kamdan-kam to'g'ri ishlaydi. Bir nechta konteynerni pod'ga birlashtirish Google'ning Borg tizimidagi "alloc" g'oyasidan keladi: ba'zi jarayonlar bitta mashinada, umumiy disk va tarmoq bilan yashashi shart.

## 2. Pod to'xtash ketma-ketligi

### Bu nima

Pod o'chirilganda (rollout, drain, scale down, `kubectl delete`) Kubernetes uni darhol o'ldirmaydi: ilovaga ochiq ishlarini tugatish uchun vaqt beradi. Bu vaqt ichida nima bo'lishini bilish zero-downtime deploy'ning asosi.

### Mexanizm

1. API server pod'ga `deletionTimestamp` qo'yadi, `STATUS` `Terminating` bo'ladi.
2. Parallel ravishda ikki narsa boshlanadi: EndpointSlice controller (Service ortidagi pod manzillari ro'yxatini yurituvchi controller, 6-dars) pod'ni Service backend'laridan chiqaradi, kubelet esa to'xtatishni boshlaydi.
3. kubelet `preStop` hook (konteyner to'xtashidan oldin bajariladigan amal) bo'lsa uni bajaradi, keyin konteynerning 1-jarayoniga `SIGTERM` yuboradi.
4. `terminationGracePeriodSeconds` (standart 30 soniya, `preStop` vaqti ham shunga kiradi) ichida jarayon chiqmasa `SIGKILL`.

**Tuzoq: 2-qadamdagi poyga.** Pod `SIGTERM` olgan paytda barcha node'lardagi kube-proxy va ingress controller hali uni backend ro'yxatidan chiqarib ulgurmagan bo'lishi mumkin: bu ma'lumot API server'dan watch orqali, kechikish bilan tarqaladi. Ilova darhol to'xtasa, yo'lda kelayotgan so'rovlar xato oladi. Standart yechim: `preStop` da bir necha soniya kutish va ilovada graceful shutdown (yangi ulanish olmaslik, ochiqlarini tugatish).

```yaml
        lifecycle:
          preStop:
            sleep: {seconds: 5}
```

`sleep` amali image'da `sleep` binary'si bo'lishini talab qilmaydi, uni kubelet o'zi bajaradi. Eski manifestlarda xuddi shu narsa `exec: {command: ["sleep", "5"]}` bilan yozilgan, u image ichida `sleep` bo'lishini talab qiladi.

**Tuzoq: `SIGTERM` yetib bormaydi.** Image `CMD` shell shaklida yozilgan bo'lsa (`CMD npm start`), 1-jarayon `sh` bo'ladi va signal ilovaga uzatilmaydi; pod har safar 30 soniya kutib `SIGKILL` oladi. Docker 2-darsdagi exec shakli va PID 1 mavzusi (signallar: Linux 9-dars) aynan shu yerda kerak. Node.js'da `process.on('SIGTERM', ...)` ichida `server.close()` chaqirish shu ketma-ketlikning ilova tomonidagi qismi.

### Misol

```
$ kubectl run sleeper --image=busybox:1.36 -- sleep 3600
pod/sleeper created
$ time kubectl delete pod sleeper
pod "sleeper" deleted

real    0m31.6s
```

`sleep` 1-jarayon (PID 1) bo'lib ishlayapti. Linux kernel PID 1 ga, u o'zi handler o'rnatmagan bo'lsa, `SIGTERM` ni yetkazmaydi, shuning uchun `sleep` signalga e'tibor bermadi. kubelet 30 soniya kutdi va `SIGKILL` yubordi. `kubectl delete` standart holatda obyekt butunlay yo'qolguncha kutadi, shuning uchun `real` vaqt grace period'ga teng chiqdi (macOS'dagi zsh'da `... 31.6 total` ko'rinishida). Signalni ushlaydigan jarayon bilan bu vaqt 1 soniyaga tushadi, buni 3-vazifada o'zingiz o'lchaysiz.

### Real ishda qachon kerak

- Har deploy'da bir nechta 502 yoki "connection reset" ko'rinsa, birinchi gumon shu ketma-ketlik: `preStop` yo'q yoki ilova `SIGTERM` ni olmaydi.
- Uzun so'rovli ilovalar (fayl yuklash, WebSocket, navbat iste'molchisi) uchun `terminationGracePeriodSeconds` ni ish davomiyligidan katta qilish.
- Node drain (11-dars) aynan shu ketma-ketlik bilan pod'larni ko'chiradi.

### Nima uchun shunday

Kubernetes taqsimlangan tizim: "pod endi yo'q" degan xabar API server'dan yuzlab node va proxy'ga bir lahzada yetib bormaydi, global sinxron to'xtash esa juda qimmat bo'lardi. Shuning uchun dizayn "eventually consistent": endpoint olib tashlash va jarayonni to'xtatish parallel, oraliqdagi bo'shliqni ilova va `preStop` yopadi. `SIGTERM` keyin `SIGKILL` sxemasi Unix an'anasi (`docker stop` ham shunday, Docker 1-dars).

## 3. Bir nechta konteynerli pod'lar: init va sidecar

### Bu nima

| Tur | Qayerda yoziladi | Xulqi |
|-----|------------------|-------|
| App container | `spec.containers` | parallel ishga tushadi, pod umri davomida ishlaydi |
| Init container | `spec.initContainers` | asosiylardan oldin, ketma-ket, har biri muvaffaqiyatli tugashi shart |
| Sidecar container | `spec.initContainers` + `restartPolicy: Always` | init tartibida ishga tushadi, lekin tugashi kutilmaydi, pod bilan birga yashaydi |

Init container ishlatiladi: bog'liqlikni kutish, migratsiya, konfiguratsiya generatsiya qilish, volume'ga fayl tayyorlash. `package.json` dagi `prestart` skripti bilan o'xshashlik haqiqiy: u asosiy jarayondan oldin ishlaydi va xato bilan tugasa asosiysi boshlanmaydi. Sidecar asosiy ilovaga xizmat qiladigan yordamchi: log jo'natuvchi, proxy, sertifikat yangilovchi.

### Mexanizm

kubelet init container'larni ro'yxat tartibida bittalab ishga tushiradi. Oddiy init container tugashini (exit 0) kutadi va keyingisiga o'tadi; xato bilan tugasa pod `restartPolicy` ga ko'ra uni qayta ishga tushiradi va pod `Init:Error` yoki `Init:CrashLoopBackOff` da qoladi, asosiy konteynerlar boshlanmaydi. `restartPolicy: Always` li init container (native sidecar) uchun kubelet tugashni emas, ishga tushishni (startup probe bo'lsa, uning o'tishini) kutadi va keyingisiga o'tadi. Pod to'xtaganda asosiy konteynerlar avval, sidecar'lar keyin, teskari tartibda to'xtatiladi.

Barcha konteynerlar pod'ning network namespace'ini bo'lishadi; fayl tizimi esa har konteynerda o'ziniki (o'z image'i), umumiy fayl faqat ikkalasiga ulangan volume (masalan `emptyDir`, pod bilan yaratilib pod bilan o'chadigan bo'sh papka, 7-dars) orqali.

```yaml
    spec:
      initContainers:
      - name: logshipper
        image: busybox:1.36
        restartPolicy: Always           # this makes it a sidecar
        command: ['sh', '-c', 'tail -F /var/log/app/app.log']
        volumeMounts: [{name: logs, mountPath: /var/log/app}]
```

### Misol

Init container 20 soniya kutadigan pod (`init-demo.yaml`: `initContainers` da `busybox:1.36` `sleep 20`, `containers` da `nginx:1.28`):

```
$ kubectl apply -f init-demo.yaml && kubectl get pod init-demo -w
pod/init-demo created
NAME        READY   STATUS     RESTARTS   AGE
init-demo   0/1     Init:0/1   0          1s
init-demo   0/1     PodInitializing   0          22s
init-demo   1/1     Running           0          24s
```

`-w` (watch) har o'zgarishda yangi qator chiqaradi. `Init:0/1`: bitta init container'dan nolta tugagan. 22-soniyada init tugadi, `PodInitializing`: asosiy konteyner yaratilmoqda. `READY 1/1`: `READY` faqat `spec.containers` ni sanaydi, init container hisobga kirmaydi. Native sidecar esa `READY` da sanaladi (6-vazifada ko'rasiz).

### Real ishda qachon kerak

- Baza migratsiyasini ilova pod'idan oldin bajarish (ko'p replikada ehtiyot bo'ling: migratsiya parallel ishlashi mumkin, Job yaxshiroq, 5-dars).
- Service mesh proxy'si (Istio, Linkerd), log agent, secret'ni fayl qilib yangilab turuvchi agent sidecar sifatida.
- Qoida: bitta pod'ga faqat birga masshtablanadigan va birga yashab o'ladigan konteynerlar qo'yiladi. Frontend va backend alohida pod'lar, chunki ular mustaqil masshtablanadi va yangilanadi.

### Nima uchun shunday

Uzoq vaqt sidecar oddiy ikkinchi konteyner sifatida yozilgan va uchta muammo bor edi: asosiy konteynerdan oldin ishga tushishi kafolatlanmagan, to'xtashda tartib yo'q (proxy ilovadan oldin o'lib, oxirgi so'rovlar yo'qolgan), Job'da sidecar tugamagani uchun pod hech qachon `Completed` bo'lmagan. Native sidecar (1.33 dan stable) yangi maydon qo'shish o'rniga mavjud `initContainers` ga `restartPolicy` qo'shish bilan hal qilindi: tartib mexanizmi allaqachon bor edi.

## 4. Probe'lar

### Bu nima

Probe kubelet konteynerni davriy tekshiradigan sinov. Uch tur, uch xil oqibat:

| Probe | Savol | Muvaffaqiyatsiz bo'lsa |
|-------|-------|------------------------|
| `startupProbe` | ilova ishga tushib bo'ldimi? | muvaffaqiyatli bo'lguncha boshqa probe'lar ishlamaydi; limit tugasa konteyner o'ldiriladi |
| `livenessProbe` | ilova tirikmi yoki osilib qolganmi? | konteyner qayta ishga tushiriladi |
| `readinessProbe` | ilova hozir trafik qabul qila oladimi? | pod `Ready` emas, Service backend'laridan chiqariladi, konteynerga tegilmaydi |

Docker 3-darsdagi `HEALTHCHECK` bilan farq: Docker'da bitta tekshiruv va u faqat holat yozadi; Kubernetes uni uchta savolga ajratgan va har biriga harakat bog'lagan.

### Mexanizm

Tekshirish usullari: `httpGet` (200–399 muvaffaqiyat), `tcpSocket` (port ochilsa muvaffaqiyat), `exec` (konteyner ichida buyruq, exit code 0 muvaffaqiyat), `grpc`. `httpGet` va `tcpSocket` ni kubelet node'dan pod IP'siga yuboradi, `exec` konteyner ichida ishlaydi.

| Parametr | Standart | Ma'nosi |
|----------|----------|---------|
| `initialDelaySeconds` | 0 | birinchi tekshiruvgacha kutish |
| `periodSeconds` | 10 | tekshiruvlar oralig'i |
| `timeoutSeconds` | 1 | javob kutish vaqti |
| `failureThreshold` | 3 | ketma-ket nechta xatodan keyin harakat |
| `successThreshold` | 1 | ketma-ket nechta muvaffaqiyatdan keyin tiklangan hisoblanadi (liveness va startup'da faqat 1) |

Harakatgacha vaqtning taxminiy hisobi: `periodSeconds × failureThreshold`. Startup probe ilovaga beradigan eng uzun vaqt ham shu formula bilan.

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

### Misol

agnhost `netexec` rejimi `/healthz` endpoint'iga ega. Readiness probe'ni ataylab mavjud bo'lmagan yo'lga (`/nope`) qaratilgan pod:

```
$ kubectl get pod probe-demo
NAME         READY   STATUS    RESTARTS   AGE
probe-demo   0/1     Running   0          40s
$ kubectl describe pod probe-demo | tail -3
  Normal   Started    38s                kubelet  Started container app
  Warning  Unhealthy  3s (x8 over 38s)   kubelet  Readiness probe failed: HTTP probe failed with statuscode: 404
```

`STATUS Running`: jarayon ishlayapti. `READY 0/1`: readiness o'tmayapti, Service bu pod'ga trafik yubormaydi. `RESTARTS 0`: readiness hech qachon restart qilmaydi. Event'dagi `(x8 over 38s)`: bir xil event 38 soniyada 8 marta takrorlangan, `statuscode: 404` sababni aniq aytadi. Xuddi shu xato liveness'da bo'lganda `Killing ... failed liveness probe, will be restarted` event'i va o'sib boruvchi `RESTARTS` ko'rinadi.

**Tuzoq: liveness probe tashqi bog'liqlikni tekshiradi.** Liveness endpoint'i ma'lumotlar bazasiga murojaat qilsa, baza sekinlashganda barcha pod'lar bir vaqtda "o'lik" deb topilib qayta ishga tushadi va kichik muammo to'liq uzilishga aylanadi. Liveness faqat jarayonning o'zini tekshiradi ("men osilib qolmadimmi"). Bog'liqliklar readiness'da, uni ham ehtiyotkorlik bilan.

**Tuzoq: probe'siz Deployment.** Probe yo'q bo'lsa konteyner jarayoni boshlangan zahoti pod `Ready` hisoblanadi. Rolling update eski pod'larni yangi ilova hali so'rov qabul qila olmayotgan paytda o'chiradi.

### Real ishda qachon kerak

- Readiness har Service ortidagi Deployment'da: rolling update va vaqtinchalik yuklamada trafikni to'g'ri yo'naltirish.
- Liveness faqat ilova haqiqatan osilib qolishi mumkin bo'lsa (deadlock, event loop bloklanishi); kerak bo'lmasa qo'ymaslik ham to'g'ri tanlov.
- Startup sekin ishga tushadigan ilovalar uchun (JVM, katta keshni yuklash).

### Nima uchun shunday

Bitta "health" tushunchasi ikki xil savolni aralashtirib yuboradi: "trafik bermang" va "meni qayta ishga tushiring". Birinchisi vaqtinchalik va xavfsiz, ikkinchisi buzuvchi. Ularni ajratish noto'g'ri harakatning narxini kamaytiradi. Startup probe keyinroq (1.20 da stable) qo'shilgan: undan oldin sekin ilovalar uchun katta `initialDelaySeconds` yozilardi va u har restartda ham, tez ishga tushganda ham bir xil kutardi.

## 5. Resurslar: requests, limits, QoS

### Bu nima

```yaml
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits:   {memory: 256Mi}
```

`requests` konteyner uchun "menga kamida shuncha kerak" degan buyurtma, `limits` "bundan oshirma" degan chegara.

### Mexanizm

| | `requests` | `limits` |
|---|------------|----------|
| Kim ishlatadi | scheduler: node'da shuncha bo'sh joy bormi | kubelet va kernel (cgroup, Docker 1-dars) |
| CPU | raqobat paytida kafolatlangan ulush | oshsa throttling: jarayon sekinlashadi, o'ldirilmaydi |
| Memory | scheduler hisobi | oshsa konteyner OOM kill qilinadi (exit code 137, `OOMKilled`) |

Birliklar: CPU `1` bu bitta yadro, `100m` (millicore) bu 0.1 yadro. Memory `Mi`, `Gi` (ikkilik) yoki `M`, `G` (o'nlik). `128m` memory bu 0.128 bayt, klassik xato. Konteynerda `limits` yozilib `requests` yozilmasa, API server request'ni limit'ga teng qilib to'ldiradi.

Scheduler haqiqiy iste'molga emas, `requests` yig'indisiga qaraydi. Node "bo'sh" ko'rinsa ham requests to'lgan bo'lsa pod `Pending` qoladi; aksincha, requests'siz pod'lar node'ni haqiqatda to'ldirib yuborishi mumkin.

### QoS class

Kubernetes pod'ga requests va limits asosida sinf beradi (`status.qosClass`). Node'da xotira tugaganda kubelet shu tartibda evict qiladi (eviction: pod'ni node'dan majburan chiqarish):

| Sinf | Sharti | Eviction navbati |
|------|--------|------------------|
| `BestEffort` | hech bir konteynerda requests ham, limits ham yo'q | birinchi |
| `Burstable` | qolgan barcha holatlar | ikkinchi, request'idan ko'p ishlatayotganlari oldin |
| `Guaranteed` | har konteynerda CPU va memory uchun requests = limits | oxirgi |

### Misol

```
$ kubectl describe node dev-worker | sed -n '/Allocatable:/,/pods:/p'
Allocatable:
  cpu:                8
  ephemeral-storage:  <..>
  memory:             16248528Ki
  pods:               110
$ kubectl describe node dev-worker | sed -n '/Allocated resources:/,/memory/p'
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests    Limits
  --------           --------    ------
  cpu                100m (1%)   100m (1%)
  memory             50Mi (0%)   50Mi (0%)
```

`Allocatable`: scheduler shu node'ga taqsimlashi mumkin bo'lgan resurs. kind'da bu Zorin'da host'ning, macOS'da Docker Desktop VM'ining butun CPU va RAM'i, va har uchala node bir xil sonni ko'rsatadi: ular bitta mashinani bo'lishgan holda har biri "hammasi meniki" deydi. `Allocated resources`: shu node'dagi pod'larning requests va limits yig'indisi, foiz Allocatable'ga nisbatan. Bu yerdagi 100m va 50Mi kube-system'dagi DaemonSet pod'lari (8-bo'lim). Ikkinchi qatordagi "overcommitted" ogohlantirishi: limits yig'indisi 100% dan oshishi mumkin, requests esa oshmaydi. `sed` buyrug'i bu yerda faqat chiqishni qirqadi, u ikkala mashinada bir xil ishlaydi.

### Real ishda qachon kerak

- Memory uchun har doim request va limit qo'ying (ko'pincha teng). Node.js'da `--max-old-space-size` ni limit'dan pastroq qo'ymasangiz, heap limit'gacha o'sib, V8 o'zi tozalash o'rniga kernel OOM kill qiladi.
- CPU request har doim; CPU limit bahsli (throttling latency'ni buzadi, ko'p jamoalar CPU limit qo'ymaydi).
- Namespace darajasida standart qiymatlar LimitRange, umumiy chegara ResourceQuota bilan (15-dars). Ishlab turgan pod'ning qiymatlarini qayta yaratmasdan o'zgartirish (in-place resize, `kubectl patch --subresource=resize`) 1.35 dan stable, autoscaling'da (14-dars) kerak bo'ladi.

### Nima uchun shunday

CPU "siqiladigan" resurs: ulushni kamaytirsangiz jarayon sekinlashadi, lekin yashaydi. Memory "siqilmaydigan": berilgan xotirani tortib olishning yagona yo'li jarayonni o'ldirish. Ikki xil oqibat shundan. Scheduler'ning haqiqiy iste'molga emas, e'lon qilingan requests'ga qarashi qarorlarni oldindan aytib bo'ladigan qiladi: metrika lahzalik va shovqinli, requests esa shartnoma.

## 6. ReplicaSet va egalik

### Bu nima

ReplicaSet bitta ishni qiladi: selector'ga (1-dars, label selector) mos pod'lar soni `replicas` ga teng bo'lishini ta'minlaydi. Kam bo'lsa template'dan yaratadi, ko'p bo'lsa o'chiradi. pm2'dagi "N ta instance'ni ushlab tur" bilan o'xshash, farqi: ReplicaSet jarayonni emas, pod'ni sanaydi va bu hisobni label orqali qiladi.

### Mexanizm

- Egalik `metadata.ownerReferences` orqali belgilanadi: pod'da "meni falon ReplicaSet yaratgan" degan yozuv. Ega o'chirilsa garbage collector (egasi yo'q obyektlarni tozalovchi controller) bolalarni ham o'chiradi; `--cascade=orphan` buni to'xtatadi.
- Selector'ga mos, lekin egasiz pod uchrasa ReplicaSet uni "asrab oladi" (adoption) va o'z hisobiga qo'shadi.
- ReplicaSet template o'zgarishini mavjud pod'larga qo'llamaydi: u faqat sonni kuzatadi. Shuning uchun uni to'g'ridan-to'g'ri ishlatmaysiz, yangilashni Deployment boshqaradi.
- Deployment har pod template uchun alohida ReplicaSet yaratadi va uni `pod-template-hash` label'i bilan ajratadi. Shu label tufayli eski va yangi ReplicaSet'lar bir-birining pod'larini olib qo'ymaydi.

### Misol

```
$ kubectl create deployment chain --image=nginx:1.28 --replicas=2
deployment.apps/chain created
$ kubectl get rs -l app=chain
NAME               DESIRED   CURRENT   READY   AGE
chain-5c8d7f9b46   2         2         2       12s
$ kubectl get pod -l app=chain -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name,HASH:.metadata.labels.pod-template-hash
NAME                     OWNER              HASH
chain-5c8d7f9b46-7kq2x   chain-5c8d7f9b46   5c8d7f9b46
chain-5c8d7f9b46-wz8rn   chain-5c8d7f9b46   5c8d7f9b46
```

Zanjir ko'rinadi: Deployment `chain`, ReplicaSet `chain-<hash>`, pod `chain-<hash>-<tasodifiy>`. `DESIRED`, `CURRENT`, `READY`: kerakli, mavjud va tayyor pod soni. Har pod'ning egasi ReplicaSet (Deployment emas), `pod-template-hash` label'i ReplicaSet nomidagi hash bilan bir xil. `custom-columns` ustunni `NOM:jsonpath` ko'rinishida oladi. Tozalash: `kubectl delete deployment chain`.

### Real ishda qachon kerak

- `kubectl get rs` rollout tarixini ko'rsatadi: 0 replikali eski ReplicaSet'lar `rollout undo` uchun saqlangan (3-dars, 5-bo'lim).
- Pod'ga qo'lda label qo'shish yoki olib tashlash uni ReplicaSet'dan "chiqarib" yuboradi: debug uchun foydali hiyla (pod qoladi, ReplicaSet o'rniga yangisini yaratadi).
- Bir xil label'li ikki xil Deployment yozish xavfli: selector'lar ustma-ust tushadi.

### Nima uchun shunday

Kubernetes'da controller'lar bir-birini chaqirmaydi, ular label va ownerReferences orqali bog'langan obyektlarni kuzatadi. Bu bo'shashgan bog'lanish: har controller kichik, alohida qayta ishga tushirilishi mumkin va holatni faqat API server'dan oladi. ReplicaSet oldidan ReplicationController bo'lgan, unda faqat tenglik selector'i bor edi; ReplicaSet to'plam selector'larini (`matchExpressions`) qo'shdi.

## 7. Deployment strategiyalari

### Bu nima

Deployment pod template o'zgarganda eski ReplicaSet'dan yangisiga qanday o'tishni boshqaradi.

| `strategy.type` | Xulqi | Qachon |
|-----------------|-------|--------|
| `RollingUpdate` (standart) | yangi pod'lar bosqichma-bosqich qo'shiladi, eskilari olib tashlanadi | ikki versiya bir vaqtda ishlay oladigan stateless ilovalar |
| `Recreate` | avval barcha eskilari o'chiriladi, keyin yangilari yaratiladi | ikki versiya birga ishlay olmasa, yoki volume faqat bitta pod'ga ulanadigan bo'lsa. Uzilish bo'ladi |

### Mexanizm

Deployment controller ikki ReplicaSet'ning `replicas` sonini qadam-baqadam o'zgartiradi va har qadamda ikki chegaraga rioya qiladi:

- `maxSurge`: kerakli sondan nechta ortiq pod bo'lishi mumkin (standart 25%, yuqoriga yaxlitlanadi).
- `maxUnavailable`: nechta pod mavjud bo'lmasligi mumkin (standart 25%, pastga yaxlitlanadi).
- `minReadySeconds`: pod `Ready` bo'lgach necha soniya barqaror tursa "available" hisoblanadi.
- `progressDeadlineSeconds` (standart 600): shu vaqtda oldinga siljish bo'lmasa rollout `ProgressDeadlineExceeded` bilan belgilanadi. Avtomatik rollback yo'q.

Masalan 10 replikada standart qiymatlar: surge 2.5 dan 3 ga, unavailable 2.5 dan 2 ga yaxlitlanadi, ya'ni rollout davomida pod'lar soni 13 dan oshmaydi va available pod'lar 8 dan kamaymaydi. `maxSurge: 1, maxUnavailable: 0` sig'imni hech qachon kamaytirmaydi, lekin qo'shimcha resurs talab qiladi. `maxSurge: 0, maxUnavailable: 1` qo'shimcha resurssiz, lekin vaqtincha sig'im kamayadi.

### Misol

```
$ kubectl set image deployment/roll nginx=nginx:1.29
deployment.apps/roll image updated
$ kubectl rollout status deployment/roll
Waiting for deployment "roll" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "roll" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "roll" rollout to finish: 1 old replicas are pending termination...
deployment "roll" successfully rolled out
$ kubectl get rs -l app=roll
NAME              DESIRED   CURRENT   READY   AGE
roll-6b9f8d7c55   4         4         4       25s
roll-7d4c9b8f6d   0         0         0       6m
```

`rollout status` har qadamda nechta yangi pod tayyor bo'lganini va eskilarning o'chishini aytadi; tugaganda exit 0, xatoda nol emas (CI uchun, 9-dars). `get rs`: yangi ReplicaSet 4 da, eskisi 0 da, lekin o'chirilmagan. Qadamlar soni va tartibi strategiya parametrlariga bog'liq, sizdagi chiqish boshqacha bo'lishi mumkin.

### Real ishda qachon kerak

- Ko'p servislarda `maxUnavailable: 0` bilan sig'imni saqlash va readiness probe bilan birga xavfsiz rollout.
- `Recreate` eski sxemali baza migratsiyasi yoki `ReadWriteOnce` volume (7-dars) bilan.
- Blue-green va canary Deployment'ning o'zida yo'q. Ular ikki Deployment va Service selector'i (yoki Gateway API vaznlari, yoki Argo Rollouts kabi vosita) bilan quriladi (10-dars).

### Nima uchun shunday

Rollout ikki xavf orasidagi kelishuv: sig'imni vaqtincha kamaytirish yoki vaqtincha ortiqcha resurs talab qilish. Kubernetes bitta "to'g'ri" javob bermaydi, ikki tutqich beradi. Avtomatik rollback yo'qligi ham ataylab: "rollout to'xtadi" degan xulosa kontekstga bog'liq (sekin image pull ham bo'lishi mumkin), qaror CI yoki GitOps vositasiga qoldirilgan.

## 8. DaemonSet

### Bu nima

DaemonSet har (mos) node'da aynan bitta pod bo'lishini ta'minlaydi. Node qo'shilsa pod avtomatik paydo bo'ladi, node olib tashlansa pod ham ketadi. `replicas` maydoni yo'q.

### Mexanizm

- DaemonSet controller har node uchun pod'ni o'zi tayinlaydi (`nodeAffinity` orqali aniq node'ga bog'lab), keyin scheduler uni tasdiqlaydi.
- Qaysi node'larda ishlashi `nodeSelector` yoki affinity bilan cheklanadi.
- Control plane node'larida taint bor (`node-role.kubernetes.io/control-plane:NoSchedule`): taint node'dagi "bu yerga tushmang" belgisi, toleration esa pod'dagi "men bu belgiga chidayman" degan ruxsat. DaemonSet control plane'da ham ishlashi uchun mos `tolerations` kerak (taint va toleration 12-darsda chuqur).
- `updateStrategy`: `RollingUpdate` (standart, `maxUnavailable: 1`) yoki `OnDelete` (pod qo'lda o'chirilgandagina yangilanadi).

### Misol

```
$ kubectl get ds -n kube-system -o custom-columns=NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,READY:.status.numberReady
NAME         DESIRED   READY
kindnet      3         3
kube-proxy   3         3
$ kubectl get pod -n kube-system -l k8s-app=kube-proxy -o wide | awk '{print $1, $7}'
NAME NODE
kube-proxy-4m7xd dev-control-plane
kube-proxy-9rqtz dev-worker
kube-proxy-hk2fw dev-worker2
```

kind'ning o'zida ikki DaemonSet bor: `kindnet` (CNI, pod tarmog'i) va `kube-proxy` (Service qoidalari, 6-dars). `DESIRED 3`: uchala node, control plane ham. Ikkinchi buyruq har node'da bittadan kube-proxy pod'ini ko'rsatadi. Ular control plane'ga tusha olgani tizim DaemonSet'larida toleration borligini bildiradi: `kubectl get ds kube-proxy -n kube-system -o yaml` dagi `tolerations` ni o'qib ko'ring.

### Real ishda qachon kerak

Node darajasidagi agentlar: log yig'uvchi (Fluent Bit, Promtail), monitoring exporter (`node-exporter`, observability moduli), CNI plugin, kube-proxy, storage plugin'ning node qismi (7-dars).

### Nima uchun shunday

Bu agentlar "N nusxa" emas, "har node'da bitta" bo'lishi kerak: ular node'ning o'z fayllari, tarmog'i va metrikalari bilan ishlaydi. Deployment bilan buni ta'minlab bo'lmaydi: node qo'shilganda replika soni o'zgarmaydi va ikki pod bitta node'ga tushishi mumkin. Docker 5-darsdagi Swarm'ning `mode: global` servisi xuddi shu g'oya.

## 9. StatefulSet asoslari

### Bu nima

Deployment pod'lari bir xil va almashtiriladigan: nomi tasodifiy, tartib yo'q. Ma'lumotlar bazasi, navbat tizimi kabi ilovalarda har nusxaning o'z shaxsi kerak. StatefulSet shuni beradi:

| Xususiyat | Deployment | StatefulSet |
|-----------|------------|-------------|
| Pod nomi | `web-7d4b9c-x2k8p` | `web-0`, `web-1`, `web-2` |
| Qayta yaratilganda | yangi nom | o'sha nom |
| Tartib | parallel | `0` dan boshlab ketma-ket, oldingisi `Ready` bo'lgach (o'chirish teskari tartibda) |
| Tarmoq shaxsi | faqat Service orqali | har pod uchun barqaror DNS nomi (headless Service orqali) |
| Storage | hamma pod bitta PVC'ni bo'lishadi | `volumeClaimTemplates`: har pod'ga o'z PVC'si |

PVC (PersistentVolumeClaim) pod'ning doimiy disk uchun so'rovi, 7-darsda.

### Mexanizm

StatefulSet `spec.serviceName` da headless Service (`clusterIP: None`, virtual IP'siz Service, DNS to'g'ridan-to'g'ri pod IP'larini qaytaradi) nomini talab qiladi; pod DNS nomi `web-0.<service>.<namespace>.svc.cluster.local` ko'rinishida bo'ladi (6-dars). StatefulSet controller standart `podManagementPolicy: OrderedReady` da navbatdagi pod'ni oldingisi `Running` va `Ready` bo'lmaguncha yaratmaydi. Pod o'chsa, xuddi shu nom va (bo'lsa) xuddi shu PVC bilan qayta yaratiladi; IP esa yangi bo'lishi mumkin, shuning uchun mijozlar IP'ga emas, DNS nomiga tayanadi.

### Misol

```
$ kubectl get pod -l app=db -w
NAME   READY   STATUS              RESTARTS   AGE
db-0   0/1     ContainerCreating   0          1s
db-0   1/1     Running             0          3s
db-1   0/1     Pending             0          0s
db-1   0/1     ContainerCreating   0          0s
db-1   1/1     Running             0          2s
```

`db-1` faqat `db-0` `Running 1/1` bo'lgandan keyin paydo bo'ldi: tartibli yaratish. Nomlar indeks bilan, tasodifiy qism yo'q.

**Tuzoq: StatefulSet replikatsiya qilmaydi.** U faqat barqaror nom, tartib va storage beradi. Ma'lumotlar bazasi nusxalari orasidagi replikatsiya, failover, zaxira ilovaning yoki operator'ning (bitta ilovani boshqarishni avtomatlashtirgan controller) ishi. Bu 12-darsning mavzusi.

### Real ishda qachon kerak

PostgreSQL, MySQL, Kafka, ZooKeeper, etcd, Elasticsearch kabi o'z ma'lumotini saqlaydigan va nusxalari bir-birini nomi bilan topishi kerak bo'lgan tizimlar. Amalda ularni ko'pincha qo'lda emas, operator yoki Helm chart orqali o'rnatasiz, lekin ichida baribir StatefulSet bo'ladi.

### Nima uchun shunday

Klasterli baza "birinchi nusxa lider, qolganlari unga ulanadi" kabi qoidalarga tayanadi, buning uchun barqaror nom va tartib kerak. Kubernetes bu talablarni umumiy mexanizm sifatida berdi, lekin har bazaning replikatsiya mantig'ini o'ziga olmadi: u bazaga xos va operator'larga qoldirilgan. Obyekt avval PetSet deb atalgan ("uy hayvoni", 1-bo'limdagi qoramol o'xshatishining teskarisi).

## 10. ConfigMap va Secret'ni iste'mol qilish

### Bu nima

ConfigMap (3-dars) va Secret konfiguratsiyani image'dan ajratadi. Bu bo'lim ularni pod'ga yetkazish usullari va farqlari haqida.

| Usul | Sintaksis | Yangilanadimi |
|------|-----------|---------------|
| Bitta kalit env sifatida | `env[].valueFrom.configMapKeyRef` yoki `secretKeyRef` | yo'q, faqat yangi pod'da |
| Barcha kalitlar env sifatida | `envFrom[].configMapRef` yoki `secretRef` | yo'q |
| Fayllar sifatida | `volumes[].configMap` yoki `secret` | ha, kechikish bilan (`subPath` bundan mustasno) |

### Mexanizm

Env o'zgaruvchilari konteyner jarayoni yaratilayotganda bir marta beriladi, keyin ularni tashqaridan o'zgartirib bo'lmaydi: Node.js'da `process.env` ham start paytidagi nusxa. Volume'dagi fayllarni esa kubelet davriy sinxronlaydi: yangi tarkibni yashirin vaqt tamg'ali papkaga yozadi va `..data` symlink'ini unga qaratadi, kalit fayllari esa `..data` ichiga ko'rsatuvchi symlink'lar. Ilova faylni o'zi qayta o'qishi kerak.

Secret tuzilishi ConfigMap bilan deyarli bir xil, farqlari: qiymatlar `data` da base64 ko'rinishida (yoki `stringData` da oddiy matn), node'da volume `tmpfs` (RAM'dagi fayl tizimi) da saqlanadi, RBAC (13-dars) bilan alohida cheklanadi. Mavjud bo'lmagan ConfigMap yoki kalitga murojaat pod'ni `CreateContainerConfigError` da qoldiradi (3-dars, 8-bo'lim), agar murojaat `optional: true` deb belgilanmagan bo'lsa.

### Misol

```
$ printf 'demo-only-value' > /tmp/token.txt
$ kubectl create secret generic demo --from-file=token=/tmp/token.txt
secret/demo created
$ rm /tmp/token.txt
$ kubectl get secret demo -o jsonpath='{.data.token}'; echo
ZGVtby1vbmx5LXZhbHVl
$ kubectl get secret demo -o jsonpath='{.data.token}' | base64 -d; echo
demo-only-value
```

Qiymat fayldan olindi, shuning uchun u shell tarixiga tushmadi (`--from-literal` tarixda qoladi). `data.token` da base64 qator, keyingi buyruq uni hech qanday kalitsiz ochdi. `base64 -d` Zorin'da (GNU) ham, macOS'da ham ishlaydi. Tozalash: `kubectl delete secret demo`.

**Tuzoq: base64 shifrlash emas.** Secret'ni o'qiy olgan har kim uni `base64 -d` bilan ochadi. Standart holatda Secret etcd'da ham shifrlanmagan saqlanadi (encryption at rest alohida yoqiladi). Secret manifestini git'ga commit qilish parolni commit qilish bilan teng. To'g'ri boshqaruv (Sealed Secrets, External Secrets, Vault) 13-darsda.

### Real ishda qachon kerak

- Env sodda, lekin `kubectl describe`, crash dump va bola jarayonlarga oqib chiqishi oson, va yangilanmaydi. Maxfiy ma'lumot uchun fayl afzal.
- Konfiguratsiyani o'zgartirmasdan qayta yuklay oladigan ilovalar (nginx reload, Prometheus) uchun volume.
- `immutable: true` ConfigMap va Secret'ni o'zgarmas qiladi: tasodifiy o'zgarishdan himoya va kubelet uchun kamroq yuk (kuzatish kerak emas). Yangi qiymat yangi nom bilan beriladi.

### Nima uchun shunday

Base64 xavfsizlik uchun emas, binary qiymatlarni (sertifikat, kalit fayl) YAML va JSON'ga sig'dirish uchun. Secret'ning haqiqiy himoyasi RBAC, etcd shifrlash va tashqi secret menejeri. Symlink orqali yangilash ataylab: ilova hech qachon yarim yozilgan faylni ko'rmaydi, chunki bitta symlink almashinuvi atomar amal. `subPath` bu mexanizmni chetlab o'tadi, shuning uchun u yangilanmaydi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Workload | ilovani ishga tushiradigan obyekt: Pod, Deployment, DaemonSet, StatefulSet, Job |
| Pod | umumiy tarmoq va volume'li bir yoki bir nechta konteyner, eng kichik deploy birligi |
| Phase | pod'ning umumiy fazasi (`Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`) |
| Condition | pod holatining alohida belgisi (`PodScheduled`, `Ready` va boshqalar) |
| `restartPolicy` | konteyner tugaganda kubelet uni qayta ishga tushirish qoidasi |
| CrashLoopBackOff | qayta-qayta qulayotgan konteyner restartlari orasidagi kutish holati |
| Grace period | `SIGTERM` dan `SIGKILL` gacha beriladigan vaqt |
| `preStop` | konteyner to'xtashidan oldin bajariladigan hook |
| Init container | asosiy konteynerlardan oldin ketma-ket ishlab tugaydigan konteyner |
| Native sidecar | `restartPolicy: Always` li init container, pod bilan birga yashaydi |
| `emptyDir` | pod bilan yaratilib pod bilan o'chadigan umumiy papka |
| Probe | kubelet bajaradigan davriy tekshiruv |
| Readiness | pod trafik qabul qila oladimi degan tekshiruv |
| Liveness | konteyner osilib qolmaganmi degan tekshiruv, xato restart beradi |
| Startup probe | ilova ishga tushib bo'lguncha boshqa probe'larni to'xtatib turadigan tekshiruv |
| Requests | scheduler hisoblaydigan kafolatlangan resurs buyurtmasi |
| Limits | kernel cgroup orqali qo'yadigan yuqori chegara |
| Throttling | CPU limitidan oshgan jarayonni sekinlashtirish |
| OOMKilled | memory limitidan oshgani uchun kernel o'ldirgan konteyner holati |
| QoS class | requests va limits'dan kelib chiqadigan pod sinfi, eviction tartibini belgilaydi |
| Eviction | pod'ni node'dan majburan chiqarish |
| Allocatable | node'da pod'larga taqsimlash mumkin bo'lgan resurs |
| ReplicaSet | selector'ga mos pod'lar sonini ushlab turadigan controller obyekti |
| ownerReferences | obyektning egasini ko'rsatuvchi metadata maydoni |
| Adoption | egasiz mos pod'ni ReplicaSet o'z hisobiga olishi |
| `pod-template-hash` | Deployment ReplicaSet'larini ajratuvchi label |
| `maxSurge` / `maxUnavailable` | rollout paytida ortiqcha va yetishmaydigan pod chegaralari |
| DaemonSet | har mos node'da bitta pod ushlab turuvchi obyekt |
| Taint / toleration | node'dagi rad belgisi va pod'dagi unga ruxsat |
| StatefulSet | barqaror nom, tartib va shaxsiy storage beradigan workload |
| Headless Service | virtual IP'siz, DNS'da pod IP'larini qaytaradigan Service |
| ConfigMap | maxfiy bo'lmagan konfiguratsiya kalit-qiymatlari |
| Secret | maxfiy qiymatlar uchun obyekt, base64 bilan saqlanadi, shifrlanmaydi |
| `immutable` | ConfigMap yoki Secret'ni o'zgarmas qiladigan maydon |

## Tuzoqlar

- Probe'siz yoki noto'g'ri probe'li Deployment: rolling update paytida so'rovlar yo'qoladi.
- Liveness probe'da tashqi bog'liqlikni tekshirish: kaskadli restart.
- `preStop` va graceful shutdown yo'qligi: har deploy'da bir nechta 502.
- Shell shaklidagi `CMD`: `SIGTERM` ilovaga yetmaydi, har to'xtash 30 soniya.
- Requests'siz pod'lar: scheduler ko'r, node haddan tashqari to'ladi, birinchi bo'lib sizning pod'ingiz evict qilinadi.
- Memory limit'ni ilovaning haqiqiy ehtiyojidan past qo'yish (JVM, Node.js heap sozlamalarini hisobga olmasdan): tushunarsiz `OOMKilled`.
- `128m` memory yozish (`128Mi` o'rniga).
- kind'da node resurslarini haqiqiy deb o'ylash: uchala node bitta mashinaning resursini "o'ziniki" deb ko'rsatadi.
- Bitta volume'li ilovada `RollingUpdate`: yangi pod volume bo'shashini kutib osilib qoladi.
- `progressDeadlineSeconds` dan keyin Kubernetes o'zi rollback qiladi deb kutish.
- StatefulSet'ni "tayyor klasterlangan baza" deb o'ylash.
- ConfigMap'ni env sifatida berib, o'zgarish pod'ga o'zi yetadi deb kutish.
- Secret manifestini git'ga qo'yish, parolni env orqali berib log'ga chiqarib yuborish, `--from-literal` bilan parolni shell tarixida qoldirish.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/ – pod hayot sikli, to'xtash, probe'lar
- https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ – init container
- https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/ – sidecar container
- https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/ – probe'lar
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ – probe'larni sozlash amaliyoti
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ – requests va limits
- https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/ – QoS class
- https://kubernetes.io/docs/concepts/workloads/controllers/ – ReplicaSet, Deployment, DaemonSet, StatefulSet
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ – rollout strategiyalari va `progressDeadlineSeconds`
- https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/ – ownerReferences va garbage collection
- https://kubernetes.io/docs/concepts/configuration/configmap/ – ConfigMap
- https://kubernetes.io/docs/concepts/configuration/secret/ – Secret
- https://github.com/kubernetes/kubernetes/tree/master/test/images/agnhost – agnhost rejimlari
- Lukša, "Kubernetes in Action" (2-nashr), pod va controller boblari

## Birga bajaramiz

Vazifalardagidan boshqa misol: `echo` nomli kichik HTTP servis (agnhost `netexec`) va uning ortidagi butun zanjir. Maqsad: bitta Deployment'dan pod'gacha bo'lgan zanjirni, readiness'ning Service'ga ta'sirini va konteyner qulashini bir joyda ko'rish. Hammasi host'da, `~/k4-walk` papkasida, hech narsa commit qilinmaydi.

1. Manifest. Deployment va Service bitta faylda (`---` bilan ajratilgan):

```
$ mkdir ~/k4-walk && cd ~/k4-walk
$ cat echo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
spec:
  replicas: 2
  selector:
    matchLabels: {app: echo}
  template:
    metadata:
      labels: {app: echo}
    spec:
      containers:
      - name: app
        image: registry.k8s.io/e2e-test-images/agnhost:2.39
        args: ["netexec", "--http-port=8080"]
        ports: [{containerPort: 8080}]
        readinessProbe:
          httpGet: {path: /healthz, port: 8080}
          periodSeconds: 3
        resources:
          requests: {cpu: 50m, memory: 32Mi}
          limits: {memory: 64Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector: {app: echo}
  ports: [{port: 80, targetPort: 8080}]
```

agnhost image'ining `ENTRYPOINT` i `/agnhost`, shuning uchun `args` faqat rejim va flag'larni beradi. Faqat readiness va resurslar bor, boshqa narsa ataylab yo'q.

2. Qo'llash va zanjirni ko'rish:

```
$ kubectl apply -f echo.yaml
deployment.apps/echo created
service/echo created
$ kubectl get deploy,rs,pod -l app=echo
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/echo   2/2     2            2           15s

NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/echo-59d6c8b7f4   2         2         2       15s

NAME                        READY   STATUS    RESTARTS   AGE
pod/echo-59d6c8b7f4-bx9tq   1/1     Running   0          15s
pod/echo-59d6c8b7f4-r2mzk   1/1     Running   0          15s
```

Uch qatlam bitta buyruqda (6-bo'lim). Deployment'dagi `UP-TO-DATE`: joriy template'dagi pod'lar soni, `AVAILABLE`: `minReadySeconds` dan o'tgan tayyor pod'lar.

3. QoS sinfi:

```
$ kubectl get pod -l app=echo -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
NAME                    QOS
echo-59d6c8b7f4-bx9tq   Burstable
echo-59d6c8b7f4-r2mzk   Burstable
```

Request bor, lekin CPU limit yo'q va memory request limit'ga teng emas: `Burstable` (5-bo'lim jadvali).

4. Service orqali so'rov. Pod IP'lari host'dan ochilmaydi (ikkala mashinada), shuning uchun klaster ichidan vaqtinchalik pod:

```
$ kubectl run client --rm -it --image=busybox:1.36 --restart=Never -- sh -c 'for i in 1 2 3 4; do wget -qO- http://echo/hostname; echo; done'
echo-59d6c8b7f4-r2mzk
echo-59d6c8b7f4-bx9tq
echo-59d6c8b7f4-bx9tq
echo-59d6c8b7f4-r2mzk
pod "client" deleted
```

`/hostname` javob bergan pod nomini qaytaradi: Service so'rovlarni ikkala pod'ga taqsimladi. `--rm` pod'ni tugagach o'chiradi (oxirgi qator).

5. Konteyner qulashi. netexec'ning `/exit?code=N` endpoint'i jarayonni shu kod bilan to'xtatadi:

```
$ POD=$(kubectl get pod -l app=echo -o jsonpath='{.items[0].metadata.name}')
$ kubectl run client --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- "http://$(kubectl get pod $POD -o jsonpath='{.status.podIP}'):8080/exit?code=3"
$ kubectl get pod $POD
NAME                    READY   STATUS    RESTARTS      AGE
echo-59d6c8b7f4-bx9tq   1/1     Running   1 (8s ago)    3m
$ kubectl describe pod $POD | grep -A4 'Last State'
    Last State:     Terminated
      Reason:       Error
      Exit Code:    3
      Started:      <..>
      Finished:     <..>
```

So'rov aniq pod IP'siga yuborildi (`$(...)` host'da hisoblanadi, busybox tayyor IP'ni oladi). `wget` javob kutmay uzilishi mumkin, bu normal. `RESTARTS 1 (8s ago)`: kubelet `restartPolicy: Always` bo'yicha konteynerni o'sha pod ichida qayta ishga tushirdi, pod nomi o'zgarmadi (1-bo'lim). `Last State` oldingi konteynerning tugash sababi va kodi: biz so'ragan 3. Restart vaqtida readiness o'tmagani uchun pod qisqa vaqt `0/1` bo'ldi va Service unga trafik yubormadi.

6. Readiness va EndpointSlice:

```
$ kubectl get endpointslices -l kubernetes.io/service-name=echo
NAME         ADDRESSTYPE   PORTS   ENDPOINTS                 AGE
echo-k7x2p   IPv4          8080    10.244.1.5,10.244.2.4     4m
```

`ENDPOINTS` da faqat `Ready` pod'larning IP'lari. 5-qadamni takrorlab, darhol shu buyruqni ishlatsangiz, restart bo'layotgan pod IP'si bir necha soniya ro'yxatdan yo'qolganini ko'rasiz.

7. Tozalash:

```
$ kubectl delete -f echo.yaml
deployment.apps "echo" deleted
service "echo" deleted
$ cd ~ && rm -rf ~/k4-walk
```

Shu 7 qadamda ko'rganingiz: Deployment, ReplicaSet va Pod zanjiri (6-bo'lim), QoS sinfi (5-bo'lim), Service'ning faqat tayyor pod'larga yuborishi (4-bo'lim), konteyner restart'i va `Last State` (1-bo'lim). Probe turlarini almashtirish, `preStop`, strategiyalar va controller'lar bilan tajribalar vazifalarda.

---

## Vazifalar

Barchasini `kubernetes/04-workloads/` papkasida bajaring (`make new m=kubernetes n=04 name=workloads`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Har vazifaning manifesti `task_N.yaml` nomi bilan saqlanadi. Hammasi `workloads` namespace'ida, host'dagi kind `dev` klasterida; vaqtga yoki node resursiga bog'liq natijalarda qaysi mashinada olinganini (Zorin yoki macOS) yozing.

### A. Pod

1. **Bare pod.** Controller'siz bitta nginx pod'i yarating va uni o'chiring: qayta yaratildimi? Keyin pod ishlab turgan node'ni toping va `docker stop` bilan o'sha kind node konteynerini to'xtating (worker bo'lsin). Bir necha daqiqa kuzating: pod bilan nima bo'ldi? Node'ni `docker start` bilan qaytaring. Xuddi shu tajribani Deployment pod'i bilan solishtiring va xulosa yozing. Yo'nalish: 1-bo'lim, "Bu nima".

2. **Pod phases.** `busybox` pod'ini `sh -c 'sleep 15; exit 1'` buyrug'i bilan uch marta ishga tushiring: `restartPolicy` `Always`, `OnFailure` va `Never`. Har birida `kubectl get pod -w` natijasini, yakuniy `phase` ni va `RESTARTS` ni yozing. `exit 0` bilan `OnFailure` qanday tugaydi? Yo'nalish: 1-bo'lim, "Mexanizm".

3. **Graceful shutdown.** Ikki pod yozing. Birinchisi `sh -c 'trap "echo got TERM; exit 0" TERM; while true; do sleep 1; done'`, ikkinchisi `SIGTERM` ni e'tiborsiz qoldiradi (oddiy `sleep 3600` ni shell orqali ishga tushirish yetarli). Har birini `time kubectl delete pod` bilan o'chiring. Vaqt farqini izohlang. Ikkinchisiga `terminationGracePeriodSeconds: 5` qo'yib qayta o'lchang. Yo'nalish: 2-bo'lim, "Misol" (zsh'da `time` formati boshqacha).

4. **Shared namespaces.** Ikki konteynerli pod: nginx va `busybox` (`sleep 3600`). busybox ichidan `wget -qO- localhost` ishlashini ko'rsating. Ikkalasiga umumiy `emptyDir` ulang, busybox'dan `index.html` yozing va nginx uni qaytarishini tekshiring. Konteynerlar nimani bo'lishadi, nimani bo'lishmaydi (fayl tizimi, jarayonlar ro'yxati, tarmoq)? Yo'nalish: 3-bo'lim, "Mexanizm".

### B. Init va sidecar

5. **Init container.** Pod yozing: init container `nslookup backend` muvaffaqiyatli bo'lguncha siklda kutadi, asosiy konteyner nginx. Pod'ni yarating va `STATUS` ustunini kuzating. `kubectl logs POD -c <init>` ni ko'ring. Keyin `backend` nomli Service yarating va pod qanday davom etishini yozing. Init container xato bilan tugasa nima bo'lishini alohida sinang. Yo'nalish: 3-bo'lim, "Misol".

6. **Native sidecar.** Deployment yozing: asosiy konteyner har soniyada umumiy `emptyDir` dagi faylga qator yozadi, sidecar (`initContainers` + `restartPolicy: Always`) uni `tail -F` qiladi. `kubectl logs -c` bilan sidecar chiqishini ko'rsating. `kubectl get pod` da `READY` ustuni nechta konteyner ko'rsatyapti? Sidecar buyrug'ini vaqtincha 20 soniyadan keyin xato bilan chiqadigan qilib o'zgartiring (`sleep 20; exit 1`): sidecar tugaganda pod'ga va asosiy konteynerga nima bo'ldi? Oddiy "ikkinchi konteyner" usulidan uchta farqini yozing. Yo'nalish: 3-bo'lim, "Nima uchun shunday".

### C. Probe'lar

7. **Readiness probe.** 3 replikali nginx Deployment'iga `/ready` fayli mavjudligini tekshiradigan `exec` yoki `httpGet` readiness probe qo'shing va Service yarating. Bitta pod'da faylni o'chiring. `kubectl get pods`, `kubectl get endpointslices` va pod `RESTARTS` qiymatini ko'rsating. Pod qayta ishga tushdimi? Faylni qaytaring va tiklanishni kuzating. Yo'nalish: 4-bo'lim, "Misol".

8. **Liveness probe.** Xuddi shunday tajribani liveness probe bilan qiling. Natija 7-vazifadan nimasi bilan farq qiladi? `describe pod` dagi event'larni yozing. `periodSeconds` va `failureThreshold` qiymatlaringizdan kelib chiqib, nosozlikdan restart'gacha qancha vaqt o'tishi kerakligini hisoblang va o'lchangan vaqt bilan solishtiring. Yo'nalish: 4-bo'lim, "Mexanizm".

9. **Startup probe.** Sekin ishga tushadigan ilovani imitatsiya qiling: konteyner 40 soniyadan keyingina `/healthz` ga javob bersin (masalan, `sleep 40` dan keyin nginx'ni ishga tushiradigan buyruq). Faqat liveness probe (standart parametrlar) bilan nima bo'lishini ko'rsating. Keyin `initialDelaySeconds` bilan va `startupProbe` bilan ikki xil tuzating. Qaysi yechim yaxshiroq va nima uchun? Yo'nalish: 4-bo'lim, "Nima uchun shunday".

### D. Resurslar

10. **QoS classes.** Uchta pod yozing, har biri boshqa QoS sinfiga tushsin. `kubectl get pod -o jsonpath='{.status.qosClass}'` bilan tasdiqlang. Faqat `limits` berilgan (requests'siz) pod qaysi sinfga tushadi va nima uchun? Node xotirasi tugaganda ular qaysi tartibda evict qilinadi? Yo'nalish: 5-bo'lim, "Mexanizm" va "QoS class".

11. **OOMKilled.** `polinux/stress` image'i bilan pod yozing: memory limit `100Mi`, buyruq `stress --vm 1 --vm-bytes 250M --vm-hang 1`. Pod holatini, `describe pod` dagi `Last State`, `Reason` va exit code'ni yozing. 137 raqami qayerdan kelishini izohlang. `--vm-bytes` ni limitdan past qilib ishlashini ko'rsating. Image'ga Docker Hub'dagi aniq tag'ni yozing (`latest` emas) va `docker buildx imagetools inspect` bilan sizning arxitekturangiz (`amd64` yoki `arm64`) uchun varianti borligini tekshiring; macOS'da `arm64` varianti topilmasa, `python:3.13-alpine` da `bytearray` bilan 250 MB ajratadigan bir qatorli buyruq bilan xuddi shu tajribani qiling va README'da qaysi yo'lni tanlaganingizni yozing. Yo'nalish: 5-bo'lim, "Mexanizm".

12. **Requests and scheduling.** `kubectl describe node` dagi `Allocatable` va `Allocated resources` bo'limlarini o'qing. Bitta worker'ning bo'sh CPU'sidan biroz kam `requests.cpu` bilan pod yarating, keyin xuddi shunday ikkinchi va uchinchisini. Qaysi biri `Pending` qoldi? Shu paytda node'lar haqiqatda band emasligini qanday izohlaysiz? Requests'siz pod shu holatda joylasha oladimi? Yo'nalish: 5-bo'lim, "Misol" (kind node'lari bitta mashina resursini bo'lishadi).

### E. Controller'lar

13. **ReplicaSet ownership.** `app=rs-demo` selector'li 3 replikali ReplicaSet yarating. Keyin xuddi shu label'li yalang'och pod yarating: nima bo'ldi va nima uchun? ReplicaSet template'idagi image'ni o'zgartirib `apply` qiling: mavjud pod'lar yangilandimi? `kubectl delete rs --cascade=orphan` bilan ReplicaSet'ni o'chiring va pod'lar holati hamda `ownerReferences` ni ko'rsating. Yo'nalish: 6-bo'lim, "Mexanizm".

14. **Rollout math.** 4 replikali Deployment'ni uch konfiguratsiyada yangilang va har birida `kubectl get pods -w` orqali bir vaqtdagi eng ko'p va eng kam `Ready` pod sonini yozing: `maxSurge: 1, maxUnavailable: 0`; `maxSurge: 0, maxUnavailable: 1`; `strategy.type: Recreate`. Standart 25%/25% da 4 replika uchun bu sonlar nechaga teng bo'ladi? Ikkalasini 0 qilib ko'ring va xatoni yozing. Yo'nalish: 7-bo'lim, "Mexanizm".

15. **Stuck rollout.** Readiness probe'li Deployment'ni (`maxUnavailable: 0`) readiness'i hech qachon o'tmaydigan versiyaga yangilang. Rollout qayerda to'xtadi, nechta eski va yangi pod bor, Service ishlayaptimi? `progressDeadlineSeconds: 60` qo'yib, `kubectl rollout status` va Deployment `conditions` ida nima paydo bo'lishini ko'rsating. Kubernetes o'zi rollback qildimi? Yo'nalish: 7-bo'lim, "Nima uchun shunday".

16. **DaemonSet.** `busybox` (`sleep`) bilan DaemonSet yarating. Nechta pod paydo bo'ldi va qaysi node'larda? Control plane node'ida nima uchun yo'q? Toleration qo'shib u yerda ham ishga tushiring. Keyin `nodeSelector` bilan faqat `disk=ssd` label'li node'larga cheklang va bitta worker'ga shu label'ni qo'ying, olib tashlang: pod'lar qanday o'zgardi? Yo'nalish: 8-bo'lim, "Misol".

17. **StatefulSet identity.** Headless Service va 3 replikali nginx StatefulSet yarating (storage'siz). Pod'lar qanday tartibda va qanday nomlar bilan paydo bo'ldi? `web-1` ni o'chiring: yangi pod'ning nomi va IP'si qanday? Vaqtinchalik pod'dan `nslookup web-0.<service>` ni tekshiring. 2 ga scale down qilganda qaysi pod o'chdi? Deployment bilan uchta farqni yozing. Yo'nalish: 9-bo'lim, "Mexanizm".

### F. Konfiguratsiya

18. **ConfigMap as env and volume.** Bitta ConfigMap'ni bitta pod'ga ikki usulda bering: `envFrom` va volume. ConfigMap qiymatini o'zgartiring va 2 daqiqa davomida pod ichida env (`kubectl exec ... env`) va faylni kuzating. Qaysi biri yangilandi? Volume ichidagi fayllar aslida nima ekanini (`ls -la` bilan symlink zanjiri) ko'rsating va bu atomar yangilanishni qanday ta'minlashini izohlang. Yo'nalish: 10-bo'lim, "Mexanizm".

19. **Secret.** `kubectl create secret generic` bilan Secret yarating (qiymatni README'ga yozmang). `kubectl get secret -o yaml` dagi qiymatni dekodlang va bu nimani isbotlashini yozing. Secret'ni volume sifatida ulab, pod ichida fayl ruxsatlarini va `mount` chiqishidagi fayl tizimi turini ko'ring. `defaultMode: 0400` qo'shing. Nima uchun Secret manifesti bu papkaga commit qilinmaydi va uning o'rniga nimani saqlaysiz? Yo'nalish: 10-bo'lim, "Misol" va "Tuzoq".

20. **Missing key.** Pod'da ConfigMap'ning mavjud bo'lmagan kalitiga `configMapKeyRef` bilan murojaat qiling. Pod holati va event'ini yozing. `optional: true` qo'shsangiz nima o'zgaradi? Bu flag qachon o'rinli va qachon xavfli? Yo'nalish: 10-bo'lim, "Mexanizm".

### G. Yakuniy

21. **Production-ready Deployment.** `task_21.yaml` yozing: nginx (yoki `agnhost`) Deployment'i, 3 replika, uchala probe (o'rinli parametrlar bilan), requests va limits (`Burstable` yoki `Guaranteed`, tanlovni asoslang), `preStop` kutish va mos `terminationGracePeriodSeconds`, `maxSurge: 1, maxUnavailable: 0`, konfiguratsiya ConfigMap'dan volume sifatida, plus Service. Isbot: (a) `kubectl port-forward` o'rniga klaster ichidagi vaqtinchalik pod'dan Service'ga har 100 ms da so'rov yuboradigan sikl ishlatib, rollout paytida bitta ham xato bo'lmasligini ko'rsating; (b) `preStop` ni olib tashlab tajribani takrorlang va natijani solishtiring; (c) README'da har sozlama qaysi nosozlikdan himoya qilishini bir qatordan yozing. Yo'nalish: butun dars, ayniqsa 2, 4, 5 va 7-bo'limlar.

## Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar `task_N.yaml` ko'rinishida papkada.
2. `make check` toza o'tadi (`yamllint`, host'da).
3. Papkada Secret manifesti yoki maxfiy qiymat yo'q (`git status` va `make secrets` bilan tekshiring).
4. `workloads` namespace'i o'chirilgan, to'xtatilgan kind node'lari qayta yoqilgan (`kubectl get nodes` da uchalasi `Ready`).
5. Menga xabar bering, tekshiraman.

## O'zini tekshirish savollari

Kodsiz, o'z so'zingiz bilan javob bering.

- Pod o'chirilganda qanday qadamlar sodir bo'ladi va `preStop` kutish qaysi muammoni yechadi?
- `STATUS` ustuni, `status.phase` va `Ready` condition qanday farq qiladi?
- Uch probe'ning har biri muvaffaqiyatsiz bo'lganda nima bo'ladi?
- Liveness probe'da ma'lumotlar bazasini tekshirish nima uchun xavfli?
- `requests` va `limits` ni kim ishlatadi? CPU limiti oshsa nima bo'ladi, memory limiti oshsa-chi?
- Uch QoS sinfi qanday aniqlanadi va nimaga ta'sir qiladi?
- kind'da `Allocatable` nima uchun haqiqiy bo'sh resursni ko'rsatmaydi?
- Deployment, ReplicaSet va Pod orasidagi munosabat qanday? `pod-template-hash` nima uchun kerak?
- `maxSurge` va `maxUnavailable` qanday kelishuvni (trade-off) boshqaradi?
- DaemonSet va StatefulSet qaysi muammolar uchun yaratilgan?
- Init container va sidecar container farqi nima?
- Secret ConfigMap'dan nimasi bilan farq qiladi va nimasi bilan farq qilmaydi?
