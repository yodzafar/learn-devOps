# 3-dars: Birinchi ilova, nginx deploy

Maqsad: bitta oddiy ilovani Kubernetes'ga to'liq yo'l bilan olib chiqish: avval imperativ buyruqlar bilan, keyin deklarativ manifestlar bilan; Deployment, Service, ConfigMap va Ingress'ni birga ishlatish; yangilash va orqaga qaytarish; buzilgan deploy'ni tizimli debug qilish. 1-darsda obyektlar nazariyasini (`spec`, `status`, label, reconciliation loop), 2-darsda klaster qurishni ko'rdingiz. Bu dars kundalik ish siklini beradi: yoz, `diff`, `apply`, kuzat, tuzat. 4–8 darslar shu yerda yuzaki tekkan har obyektni (workload'lar, Service, storage, TLS) alohida chuqurlashtiradi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–4 bo'limlar va A, B guruhlar; ikkinchi kun 5–7 bo'limlar, C, D, E guruhlar; uchinchi kun 8–9 bo'limlar, "Birga bajaramiz", F, G, H guruhlar va README. Diqqatni quyidagilarga qarating: `apply` farqni qanday hisoblaydi va drift nima, rollout paytida ReplicaSet'lar bilan nima bo'ladi, ConfigMap o'zgarishi pod'ga qachon yetadi, va eng muhimi debug tartibi: `get`, `describe`, `logs`, event'lar.

Qanday o'qish kerak: nazariyadagi misollar ataylab nginx emas, `httpd:2.4-alpine` (Apache web server'ining kichik image'i) bilan va `demo` namespace'ida yozilgan, vazifalar esa nginx bilan `web` namespace'ida. Har misolni o'zingiz terib ko'ring va chiqishni darsdagi izoh bilan solishtiring. Pod nomlaridagi tasodifiy qo'shimchalar, IP'lar, yosh (`AGE`) va versiyalar sizda boshqacha bo'ladi; bunday joylar `<...>` bilan belgilangan yoki shunchaki farq qiladi. Ustunlar soni va nomlari bir xil.

## Laboratoriya

Hamma narsa host'da, Docker ustidagi kind klasterida bajariladi. `lab` VM va Multipass bu darsda kerak emas: biz tizimni o'zgartirmaymiz, faqat klaster ichida obyekt yaratamiz va klaster bitta buyruq bilan o'chadi.

| Joy | Nima uchun |
|-----|------------|
| Host terminali | `kubectl`, `kind`, `curl`, `git`, `make check` |
| Ikkinchi terminal | `cloud-provider-kind` jarayoni (F guruh va "Birga bajaramiz"), `kubectl get -w` kuzatuvlari |
| Pod ichi (`kubectl exec`, `kubectl run ... --rm -it`) | klaster ichidan DNS va Service'ga murojaat |

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `kubectl`, `kind` | 1-darsdagi binary'lar, `~/.local/bin`, `amd64` | `brew install kubectl kind` (`arm64`) |
| `cloud-provider-kind` | releases sahifasidan `linux_amd64` arxivi: https://github.com/kubernetes-sigs/cloud-provider-kind/releases, binary `~/.local/bin` ga | `brew install cloud-provider-kind` |
| `cloud-provider-kind` ni ishga tushirish | `cloud-provider-kind` (foydalanuvchi `docker` guruhida bo'lsa yetarli; ruxsat xatosi chiqsa `sudo` bilan) | `sudo cloud-provider-kind --enable-lb-port-mapping` (loyiha hujjati macOS'da `sudo` ni talab qiladi) |
| Ingress `ADDRESS` dagi IP | host'dan to'g'ridan-to'g'ri ochiladi: kind tarmog'i host'da | host'dan ochilmaydi: Docker yashirin Linux VM ichida. Kirish `docker ps` dagi `kindccm-...` konteynerining `localhost:<port>` mapping'i orqali yoki pastdagi universal usul bilan |
| `kubectl port-forward` | `localhost:<port>`, bir xil | `localhost:<port>`, bir xil |
| Node image va pod'lar | `linux/amd64` | `linux/arm64`; darsdagi barcha image'lar (`nginx`, `httpd`, `busybox`, `curlimages/curl`, `agnhost`) ikkala arxitektura uchun bor |
| Resurs | kind uchun ~4 GB RAM bo'sh bo'lsin | Docker Desktop sozlamalarida VM'ga kamida 6 GB RAM bering |

Ingress IP'sini ikkala mashinada bir xil tekshirishning universal usuli: `curl` ni kind node'lari turgan `kind` Docker tarmog'iga ulangan vaqtinchalik konteynerdan ishlatish. Bu konteyner Ingress IP'sini to'g'ridan-to'g'ri ko'radi, macOS'da ham:

```bash
docker run --rm --network kind curlimages/curl:8.10.1 -s -H 'Host: web.example.test' http://<ADDRESS>/
```

Klasterni tayyorlash. 2-darsdagi `kind-multi.yaml` (1 control-plane, 2 worker) git orqali ikkala mashinada `kubernetes/02-cluster-setup/` papkasida bor:

```bash
kind delete cluster --name dev            # if the lesson 1 cluster still exists
kind create cluster --name dev --config kubernetes/02-cluster-setup/kind-multi.yaml
kubectl get nodes
kubectl create namespace web
kubectl config set-context --current --namespace=web
```

`config set-context --current --namespace=web` joriy context'ning standart namespace'ini o'zgartiradi (1-dars): bundan keyin `-n web` yozish shart emas. Nazariya misollari uchun `kubectl create namespace demo` qiling va ularni `-n demo` bilan bajaring yoki vaqtincha context'ni `demo` ga o'tkazing.

- **Ikkinchi mashinada tiklash**: klaster holati mashinalar orasida ko'chmaydi. Git orqali keladigani: `kind-multi.yaml`, `kubernetes/03-first-deploy/manifests/` va `README.md`. Ikkinchi mashinada yuqoridagi uch buyruq bilan klasterni yarating, keyin `kubectl apply -f kubernetes/03-first-deploy/manifests/` bilan oxirgi holatga qayting. Deklarativ yondashuvning foydasi aynan shu yerda ko'rinadi. Imperativ (A guruh) va qo'lda qilingan (6-vazifa) o'zgarishlar ko'chmaydi, ularni qayta bajarasiz.
- **Tozalash**: `cloud-provider-kind` ni `Ctrl+C` bilan to'xtating, `kubectl delete namespace web site demo`, kerak bo'lsa `kind delete cluster --name dev`. `cloud-provider-kind` to'xtagach `docker ps` da `kindccm-...` konteynerlari qolmaganini tekshiring.
- **Secret'lar**: bu darsda secret yo'q. kubeconfig (`~/.kube/config`) ish papkasiga ko'chirilmaydi va commit qilinmaydi.

---

## 1. Imperativ va deklarativ yo'l

### Bu nima

Kubernetes'ga ikki uslubda buyruq berish mumkin. **Imperativ**: "shuni qil" (`kubectl create`, `kubectl expose`, `kubectl scale`). **Deklarativ**: "holat shunday bo'lsin" degan YAML fayl (manifest) yoziladi va `kubectl apply` bilan klasterga beriladi, qolganini controller'lar bajaradi. Ikkalasi ham oxirida bir xil narsani qiladi: API server'ga obyekt yuboradi. Farq shundaki, imperativ yo'lda holatning manbai sizning terminal tarixingiz, deklarativ yo'lda git'dagi fayl.

### Mexanizm

`kubectl create deployment` mijoz tomonida Deployment obyektini yasaydi (standart label `app=<nom>`, selector va pod template bilan) va uni API server'ga `POST` qiladi. `kubectl expose` mavjud obyektning selector'ini o'qib, shu selector bilan Service yaratadi. `--dry-run` flag'i yuborishni to'xtatadi:

- `--dry-run=client`: obyekt faqat `kubectl` ichida yasaladi, API server'ga hech narsa ketmaydi. Maydon nomi xato bo'lsa ham ko'pincha sezilmaydi.
- `--dry-run=server`: so'rov API server'ga boradi, schema validatsiyasi va admission (1-darsda: obyekt saqlanishidan oldingi tekshiruv va o'zgartirish bosqichi) ishlaydi, lekin etcd'ga yozilmaydi.

`-o yaml` bilan birga `--dry-run=client` manifest generatori bo'ladi: imperativ buyruq sizga YAML qolipini yozib beradi.

### Misol

```
$ kubectl -n demo create deployment hello --image=httpd:2.4-alpine --replicas=2
deployment.apps/hello created
$ kubectl -n demo expose deployment hello --port=80
service/hello exposed
$ kubectl -n demo port-forward service/hello 8080:80
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
```

Ikkinchi terminalda:

```
$ curl -s localhost:8080
<html><body><h1>It works!</h1></body></html>
```

`deployment.apps/hello created`: obyekt turi (`deployment`), API guruhi (`apps`) va nomi; API server uni saqladi. `service/hello exposed`: Service yaratildi, nomi Deployment nomi bilan bir xil (`--name` berilmagan). `Forwarding from 127.0.0.1:8080 -> 80` va `[::1]:8080`: host'ning IPv4 va IPv6 loopback'idagi 8080 port tinglanyapti, ulanishlar konteynerning 80 portiga ketadi. `Handling connection for 8080`: `curl` ulanganida chiqadi, har ulanish uchun bitta qator. `It works!` httpd image'ining standart sahifasi.

Generator sifatida:

```
$ kubectl create configmap greeting --from-literal=lang=uz --dry-run=client -o yaml
apiVersion: v1
data:
  lang: uz
kind: ConfigMap
metadata:
  name: greeting
```

Hech narsa yaratilmadi, faqat YAML chiqdi. Kalitlar alifbo tartibida, chunki `kubectl` obyektni Go strukturasidan YAML'ga o'giradi. Deployment uchun ham xuddi shunday ishlaydi, chiqishda esa "bo'sh" maydonlar ham bo'ladi (2-vazifada ularni o'zingiz ko'rasiz).

### Real ishda qachon kerak

- Imperativ: tez sinov, "image umuman ishga tushadimi" degan savol, incident paytida vaqtinchalik `scale`, `kubectl run` bilan debug pod'i.
- `--dry-run=client -o yaml`: yangi manifestni noldan yozmaslik uchun qolip.
- `--dry-run=server`: CI'da manifest klaster qabul qiladimi degan tekshiruv (9-dars).

### Nima uchun shunday

Imperativ buyruqlarning muammosi: ular tarixda qoladi, holatda emas. Bir oydan keyin klasterda nima uchun aynan shu sozlama turgani noma'lum, boshqa muhitda takrorlash uchun buyruqlarni eslash kerak. Docker modulida `docker run` skriptidan `compose.yaml` ga o'tganingiz (docker 4-dars) xuddi shu sabab bilan edi. Kubernetes imperativ buyruqlarni olib tashlamagan, chunki ular o'rganish va tezkor ish uchun qulay; lekin hamjamiyat odati aniq: muhitda yashaydigan hamma narsa faylda.

## 2. Deployment manifesti va label'lar

### Bu nima

Deployment "shu pod'dan N nusxa doim ishlab tursin va uni xavfsiz yangilab tur" degan obyekt. U pod'larni o'zi yaratmaydi: ReplicaSet (aniq bir pod template'idan N nusxa ushlab turuvchi obyekt) yaratadi, ReplicaSet esa pod'larni. 1-darsda bu egalik zanjirini (`ownerReferences`) ko'rgansiz.

### Mexanizm: uch joydagi label

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  labels:
    app.kubernetes.io/name: hello      # label of the Deployment itself
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: hello    # which pods belong to this Deployment
  template:                            # pod template
    metadata:
      labels:
        app.kubernetes.io/name: hello  # put on every pod, must match the selector
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          ports:
            - containerPort: 80
```

Uch joyda label bor va ular uch xil vazifa bajaradi:

| Joy | Vazifasi |
|-----|----------|
| `metadata.labels` | Deployment obyektining o'z label'i, uni qidirish uchun (`kubectl get deploy -l ...`) |
| `spec.selector.matchLabels` | qaysi pod'lar shu Deployment'niki ekanini aniqlaydi |
| `spec.template.metadata.labels` | yaratiladigan har pod'ga qo'yiladi |

API server ikki qoidani tekshiradi: template label'lari selector'ga mos kelishi shart (aks holda Deployment o'zi yaratgan pod'larni "tanimaydi"), va `apps/v1` da `spec.selector` yaratilgandan keyin o'zgarmas (immutable). `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/part-of` Kubernetes hujjatida tavsiya etilgan umumiy label'lar: asboblar (Helm, dashboard'lar) ularni taniydi.

### Misol

```
$ kubectl -n demo get deploy,rs,pods -l app.kubernetes.io/name=hello
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello   2/2     2            2           40s

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-6d8f7c9b54   2         2         2       40s

NAME                         READY   STATUS    RESTARTS   AGE
pod/hello-6d8f7c9b54-k2lmx   1/1     Running   0          40s
pod/hello-6d8f7c9b54-vq8zt   1/1     Running   0          40s
```

Deployment qatori: `READY 2/2` tayyor pod'lar / kerakli son, `UP-TO-DATE` joriy template'dan yaratilgan pod'lar, `AVAILABLE` foydalanuvchiga xizmat qila oladiganlari. ReplicaSet nomidagi `6d8f7c9b54` pod template'ining hash'i: template o'zgarsa yangi hash, yangi ReplicaSet (6-bo'lim). Pod nomi `<replicaset>-<tasodifiy 5 belgi>`. Bu yerda `-l` ishlashining sababi: template label'i ReplicaSet'ga ham, pod'larga ham ko'chadi.

**Tuzoq: `kubectl create deployment` va manifest label'lari farqi.** Imperativ buyruq `app=<nom>` label'ini qo'yadi, qo'lda yozgan manifestingiz esa boshqa label ishlatishi mumkin. Bir nomdagi Deployment'ni avval imperativ, keyin manifest bilan yaratmoqchi bo'lsangiz, selector o'zgarmas bo'lgani uchun `apply` rad etiladi. Avval eskisini o'chiring.

### Real ishda qachon kerak

Har stateless (holatini o'zida saqlamaydigan) ilova: web server, API, worker. Label'lar esa hamma joyda: Service pod'larni, monitoring metrikalarni, NetworkPolicy trafikni label orqali tanlaydi. Noto'g'ri label bitta obyektni emas, butun zanjirni uzadi.

### Nima uchun shunday

Kubernetes obyektlarni nomi bilan emas, label selector bilan bog'laydi: bu bo'sh bog'lanish (loose coupling). Deployment "mening pod'larim ro'yxati" ni saqlamaydi, har safar selector bilan so'raydi, xuddi Compose label'lar bo'yicha o'z konteynerlarini topgani kabi (docker 4-dars). Selector'ning o'zgarmasligi esa eski selector'ga mos pod'lar "egasiz" qolib, yangi pod'lar ustiga yaratilishining oldini oladi. `extensions/v1beta1` davrida selector o'zgartirish mumkin edi va bu aynan shunday nosozliklarga olib kelgan.

## 3. `kubectl apply`, `diff` va drift

### Bu nima

`kubectl apply -f <fayl yoki papka>` obyekt yo'q bo'lsa yaratadi, bor bo'lsa faqat farqini qo'llaydi. Uni necha marta bajarsangiz ham natija bir xil: bu idempotent (takroriy bajarilishi natijani o'zgartirmaydigan) amal. `kubectl diff -f` esa "apply qilsam nima o'zgaradi" degan savolga javob beradi va hech narsani o'zgartirmaydi.

### Mexanizm: uch tomonlama solishtirish

Client-side apply (standart rejim) uch narsani solishtiradi:

| Manba | Qayerda |
|-------|---------|
| Yangi holat | siz bergan fayl |
| Joriy holat | klasterdagi obyekt |
| Oxirgi qo'llangan holat | obyektning `kubectl.kubernetes.io/last-applied-configuration` annotation'i (annotation: label'ga o'xshash, lekin tanlash uchun emas, ma'lumot saqlash uchun kalit-qiymat) |

Qoidalar: faylda bor maydon klasterga yoziladi; oxirgi qo'llangan holatda bor, yangi faylda yo'q maydon klasterdan o'chiriladi; hech qachon faylda bo'lmagan maydonga (masalan, boshqa controller yozgan qiymatga) tegilmaydi.

Server-side apply (`kubectl apply --server-side`) shu hisobni API server'ga ko'chiradi. Har maydonning "egasi" `metadata.managedFields` da yoziladi (`manager: kubectl`, `manager: kube-controller-manager` va hokazo). Ikki asbob bitta maydonni boshqarmoqchi bo'lsa, konflikt xatosi chiqadi. `managedFields` standart chiqishda yashirin, ko'rish uchun `kubectl get deploy hello -o yaml --show-managed-fields`.

`kubectl diff` serverdan "agar apply qilinsa natija qanday bo'lardi" degan holatni oladi va joriy holat bilan `diff -u` qiladi. Exit code: `0` farq yo'q, `1` farq bor, `1` dan katta bo'lsa xato.

### Misol

Faylda `replicas: 2` ni `3` ga o'zgartirgandan keyin:

```
$ kubectl -n demo diff -f hello.yaml
diff -u -N /tmp/LIVE-<...>/apps.v1.Deployment.demo.hello /tmp/MERGED-<...>/apps.v1.Deployment.demo.hello
--- /tmp/LIVE-<...>/apps.v1.Deployment.demo.hello	<sana>
+++ /tmp/MERGED-<...>/apps.v1.Deployment.demo.hello	<sana>
@@ -6,7 +6,7 @@
-  generation: 1
+  generation: 2
@@ -15,7 +15,7 @@
-  replicas: 2
+  replicas: 3
$ echo $?
1
$ kubectl -n demo apply -f hello.yaml
deployment.apps/hello configured
$ kubectl -n demo apply -f hello.yaml
deployment.apps/hello unchanged
```

`LIVE` klasterdagi joriy obyekt, `MERGED` apply'dan keyingi taxminiy obyekt; fayl nomi `<guruh>.<versiya>.<tur>.<namespace>.<nom>`. `-` bilan boshlangan qator ketadi, `+` keladi. `generation` `spec` har o'zgarganda API server oshiradigan hisoblagich (1-darsdagi `spec` va `status` farqiga qarang: `status.observedGeneration` controller qaysi `generation` ni ko'rib chiqqanini aytadi). Exit code `1`: farq bor. Birinchi `apply` `configured` (o'zgartirildi), ikkinchisi `unchanged`: idempotentlik.

### Drift

Drift: klasterdagi holat fayldagidan ajralib ketishi. Sababi deyarli har doim qo'lda o'zgartirish: `kubectl edit`, `kubectl scale`, `kubectl set image`. Keyingi `apply` uch tomonlama qoidaga ko'ra ishlaydi, shuning uchun qo'lda qilingan o'zgarishning faylda ham bor maydonlari qaytariladi, faylda yo'q maydonlari esa qoladi. Natija oldindan aytib bo'lmaydigandek ko'rinadi, aslida mexanizm aniq: 6-vazifada uni o'zingiz isbotlaysiz.

### Real ishda qachon kerak

- `diff` har `apply` dan oldin, ayniqsa production'da: kod review'dagi `git diff` ning klaster versiyasi.
- CI'da `kubectl diff` ning exit code'i "klaster git bilan mos" degan tekshiruvga aylanadi (9-dars), GitOps (10-dars) esa drift'ni doimiy kuzatib, avtomatik tuzatadi.
- Server-side apply: bir obyektni bir nechta asbob boshqarganda (masalan, `replicas` ni HPA, qolganini pipeline).

### Nima uchun shunday

Oddiy "faylni klasterga yoz" (`kubectl replace`) controller'lar va boshqa asboblar qo'shgan maydonlarni o'chirib yuborardi. Uch tomonlama birlashtirish "men nimani boshqaraman" ni eslab qoladi, shuning uchun faqat o'z maydonlariga tegadi. Annotation'da saqlash esa kamchilikka ega edi (katta obyektlarda annotation hajm limiti, bir nechta asbob o'rtasida egalik noma'lum), shu sabab Kubernetes 1.22 da server-side apply GA bo'ldi. Frontend'dagi o'xshatish haqiqiy: `package.json` (xohlangan holat) va `node_modules` (haqiqiy holat), `npm install` ularni moslaydi; `node_modules` ni qo'lda tahrirlash drift.

## 4. Service va `port-forward`

### Bu nima

Pod IP'lari vaqtinchalik: pod qayta yaratilsa IP o'zgaradi, rollout paytida esa pod'lar umuman almashadi. Service selector bo'yicha pod'lar to'plamiga barqaror nom (DNS) va virtual IP beradi. Standart tur `ClusterIP`: faqat klaster ichidan ko'rinadi. 6-darsda Service turlari va kube-proxy mexanizmi chuqur o'tiladi.

### Mexanizm

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  selector:
    app.kubernetes.io/name: hello
  ports:
    - port: 80          # port of the Service
      targetPort: 80    # port of the container
```

Service selector'iga mos va tayyor (`Ready`) pod'larning IP'lari EndpointSlice obyektiga yoziladi. Har node'dagi kube-proxy (1-dars) Service IP'siga kelgan ulanishni shu ro'yxatdagi pod'lardan biriga yo'naltiradi. Klaster DNS'i `hello` nomini (to'liq nomi `hello.demo.svc.cluster.local`) Service IP'siga yechadi.

`kubectl port-forward` boshqa yo'l bilan ishlaydi: `kubectl` API server'ga ulanadi, API server pod turgan node'dagi kubelet'ga, kubelet esa pod tarmog'idagi portga. `port-forward service/hello` yozilsa ham, `kubectl` Service'dan bitta pod'ni tanlaydi va tunnel faqat shu pod'ga ochiladi.

### Misol

```
$ kubectl -n demo get svc hello
NAME    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
hello   ClusterIP   10.96.41.207   <none>        80/TCP    2m
$ kubectl -n demo get endpointslices -l kubernetes.io/service-name=hello
NAME          ADDRESSTYPE   PORTS   ENDPOINTS               AGE
hello-x7k2p   IPv4          80      10.244.1.5,10.244.2.4   2m
$ kubectl -n demo run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://hello
<html><body><h1>It works!</h1></body></html>
pod "tmp" deleted
```

`TYPE ClusterIP`, `CLUSTER-IP 10.96.41.207` virtual IP (kind'da Service diapazoni `10.96.0.0/16`), `EXTERNAL-IP <none>` tashqi manzil yo'q, `PORT(S) 80/TCP`. EndpointSlice'da `ENDPOINTS` ikki pod IP'si: `10.244.1.x` va `10.244.2.x` ikki xil worker node'ning pod tarmog'i. `kubectl run tmp --rm -it --restart=Never` bitta vaqtinchalik pod yaratadi, buyruq tugagach o'chiradi (`pod "tmp" deleted`). Pod ichidan `http://hello` qisqa nom bilan yetdik, chunki pod `demo` namespace'ida va DNS qidiruv ro'yxatida `demo.svc.cluster.local` bor.

**Tuzoq: `port-forward` debug vositasi.** U Service orqali balanslamaydi, tanlangan pod o'lsa tunnel uziladi va `kubectl` xato bilan chiqadi. Foydalanuvchi trafigi uchun Service turlari (6-dars) va Ingress (8-bo'lim) ishlatiladi.

### Real ishda qachon kerak

- `port-forward`: klasterdagi ichki servisni (baza, admin panel, metrika endpoint'i) vaqtincha o'z brauzeringizda ochish, uni internetga chiqarmasdan.
- `kubectl run --rm -it`: "Service ishlayaptimi, klaster ichidan qanday ko'rinadi" degan savolga tezkor javob.

### Nima uchun shunday

Service'ning o'zi jarayon emas, u qoida: hech qanday proxy pod'i yo'q, trafikni har node'dagi kube-proxy yozgan kernel qoidalari yo'naltiradi. Shuning uchun Service bitta nosozlik nuqtasi emas. `port-forward` esa API server orqali o'tadi, ya'ni autentifikatsiya va RBAC (13-dars) himoyasida va tashqariga port ochmasdan ishlaydi; to'lovi: tezlik past, bitta pod, uzilishga chidamsiz.

## 5. Kuzatish va tekshirish

### Bu nima

Klasterda nima bo'layotganini ko'rishning to'rt darajasi bor: `get` (holat jadvali), `describe` (obyekt tafsiloti va unga tegishli event'lar), `logs` (ilovaning o'z chiqishi), `exec` va `debug` (konteyner ichiga kirish). Event (voqea): controller yoki kubelet obyekt bilan nima qilganini yozadigan qisqa yozuv, alohida `Event` obyekti.

### Mexanizm

| Buyruq | Qachon |
|--------|--------|
| `kubectl get pods -o wide` | umumiy holat: `STATUS`, `READY`, `RESTARTS`, node, pod IP |
| `kubectl describe pod NAME` | sabab qidirish: `Events`, konteyner `State` va `Last State` |
| `kubectl logs NAME` | ilova chiqishi (stdout, stderr) |
| `kubectl logs NAME --previous` | qayta ishga tushgan konteynerning oldingi nusxasi log'i |
| `kubectl logs -l KEY=VALUE --prefix --tail=20 -f` | label bo'yicha bir nechta pod, har qator oldida pod nomi, oqim |
| `kubectl logs deploy/NAME -c CONTAINER` | Deployment'ning bitta pod'i, aniq konteyner |
| `kubectl exec -it NAME -- sh` | konteyner ichida buyruq |
| `kubectl debug -it NAME --image=busybox:1.36 --target=CONTAINER` | shell'i yo'q image uchun vaqtinchalik (ephemeral) konteyner |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | namespace bo'yicha voqealar, vaqt tartibida |

`kubectl logs` konteyner runtime'i yozgan fayllarni kubelet orqali o'qiydi. Runtime faqat konteyner jarayonining stdout va stderr'ini yig'adi: ilova log'ni konteyner ichidagi faylga yozsa, `kubectl logs` bo'sh qoladi. Shuning uchun konteyner image'lari log'ni stdout'ga yo'naltiradi (har image o'z usuli bilan; nginx'nikini 8-vazifada topasiz). Event'lar API server'da standart bo'yicha bir soat saqlanadi, keyin o'chadi.

### Misol

```
$ kubectl -n demo describe pod hello-6d8f7c9b54-k2lmx
Name:             hello-6d8f7c9b54-k2lmx
Namespace:        demo
Node:             dev-worker/172.18.0.3
Labels:           app.kubernetes.io/name=hello
                  pod-template-hash=6d8f7c9b54
Status:           Running
IP:               10.244.1.5
Controlled By:    ReplicaSet/hello-6d8f7c9b54
Containers:
  httpd:
    Image:          httpd:2.4-alpine
    Image ID:       docker.io/library/httpd@sha256:<...>
    State:          Running
      Started:      <sana>
    Ready:          True
    Restart Count:  0
QoS Class:        BestEffort
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  3m    default-scheduler  Successfully assigned demo/hello-6d8f7c9b54-k2lmx to dev-worker
  Normal  Pulling    3m    kubelet            Pulling image "httpd:2.4-alpine"
  Normal  Pulled     3m    kubelet            Successfully pulled image "httpd:2.4-alpine" in <...>
  Normal  Created    3m    kubelet            Created container: httpd
  Normal  Started    3m    kubelet            Started container httpd
```

(Chiqish qisqartirilgan.) `Node: dev-worker/172.18.0.3`: pod qaysi node'da va node'ning IP'si (kind'da node Docker konteyneri, IP `kind` Docker tarmog'idan). `Labels` da siz qo'ymagan `pod-template-hash`: ReplicaSet uni qo'shib, o'z pod'larini boshqa ReplicaSet'nikidan ajratadi. `Controlled By`: egasi. `Image ID`: tag'dan yechilgan aniq digest (docker 2-dars), ya'ni haqiqatda qaysi image ishlayapti. `QoS Class: BestEffort`: `resources` yozilmagani uchun (4-darsda). `Events` jadvali zanjirni ko'rsatadi: scheduler node tanladi, kubelet image tortdi, konteyner yaratdi va ishga tushirdi. `From` ustuni voqeani kim yozganini aytadi: muammo scheduler bosqichidami yoki kubelet bosqichidami, shu ustundan ko'rinadi.

`exec` va vaqtinchalik pod:

```
$ kubectl -n demo exec deploy/hello -- httpd -v
Server version: Apache/2.4.<...> (Unix)
Server built:   <...>
```

`exec deploy/hello` Deployment'ning bitta pod'ini tanlaydi. `--` dan keyingi hamma narsa konteyner ichida bajariladigan buyruq.

### Real ishda qachon kerak

Har incident shu buyruqlardan boshlanadi. `describe` dagi `Image ID` "aynan qaysi versiya ishlayapti" savolini yopadi, event zanjiri esa "qayerda to'xtadi" ni. `kubectl debug` minimal image'larda (distroless: ichida shell ham yo'q image) yagona yo'l.

### Nima uchun shunday

`exec` orqali qilingan o'zgarish konteynerning yoziladigan qatlamida qoladi va pod bilan birga yo'qoladi (docker 1-darsdagi qatlamlar). Bu ataylab: pod "chorva", "uy hayvoni" emas, uni qo'lda tuzatish emas, almashtirish kerak. Event'larning qisqa umri esa etcd'ni to'ldirib yubormaslik uchun; uzoq tarix observability modulidagi log va metrika yig'ish vazifasi.

## 6. Rollout va rollback

### Bu nima

Rollout: Deployment pod template'i (`spec.template`) o'zgarganda eski pod'larni yangisiga bosqichma-bosqich almashtirish. Rollback: oldingi template'ga qaytish. `replicas` o'zgarishi rollout emas, faqat masshtablash (scaling): template bir xil, faqat nusxalar soni o'zgaradi.

### Mexanizm

Template o'zgarganda Deployment controller yangi hash bilan yangi ReplicaSet yaratadi va standart `RollingUpdate` strategiyasida uni asta-sekin kattalashtiradi, eskisini kichraytiradi. Qadam o'lchami `maxSurge` (kerakli sondan ortiq nechta pod bo'lishi mumkin, standart 25%, yuqoriga yaxlitlanadi) va `maxUnavailable` (nechta pod tayyor bo'lmasligi mumkin, standart 25%, pastga yaxlitlanadi) bilan belgilanadi; 4-darsda batafsil. Yangi pod `Ready` bo'lmaguncha keyingi qadam qo'yilmaydi.

Eski ReplicaSet o'chirilmaydi, 0 replika bilan qoladi. Rollback aynan unga qaytish: eski ReplicaSet kattalashadi, yangisi kichrayadi. Saqlanadigan eski ReplicaSet'lar soni `spec.revisionHistoryLimit` (standart 10). Har ReplicaSet'da `deployment.kubernetes.io/revision` annotation'i bor, `rollout history` shu raqamlarni ko'rsatadi, `CHANGE-CAUSE` ustuni esa `kubernetes.io/change-cause` annotation'idan olinadi.

| Buyruq | Nima qiladi |
|--------|-------------|
| `kubectl set image deployment/NAME CONTAINER=IMAGE` | imperativ image almashtirish (yoki faylni o'zgartirib `apply`) |
| `kubectl rollout status deployment/NAME` | tugashini kutadi, muvaffaqiyatsiz bo'lsa nol bo'lmagan exit code |
| `kubectl rollout history deployment/NAME` | reviziyalar ro'yxati |
| `kubectl rollout undo deployment/NAME [--to-revision=N]` | oldingi yoki aniq reviziyaga qaytish |
| `kubectl rollout restart deployment/NAME` | template'ga vaqt annotation'i qo'shib, bir xil spec bilan yangi pod'lar |

### Misol

```
$ kubectl -n demo set image deployment/hello httpd=httpd:2.4.62-alpine
deployment.apps/hello image updated
$ kubectl -n demo rollout status deployment/hello
Waiting for deployment "hello" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "hello" rollout to finish: 1 old replicas are pending termination...
deployment "hello" successfully rolled out
$ kubectl -n demo get rs
NAME               DESIRED   CURRENT   READY   AGE
hello-6d8f7c9b54   0         0         0       20m
hello-7f5b8d6c49   2         2         2       30s
$ kubectl -n demo rollout history deployment/hello
deployment.apps/hello
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

`set image` konteyner nomi (`httpd`) bo'yicha image'ni almashtirdi. `rollout status` qadamlarni ko'rsatadi: avval yangi pod'lar yaratiladi, keyin eskilari tugatiladi, oxirgi qator muvaffaqiyat (exit code `0`). `get rs`: eski ReplicaSet `DESIRED 0` bilan qoldi, yangisi 2 pod ushlab turibdi. `history` da ikki reviziya, `CHANGE-CAUSE` bo'sh, chunki annotation qo'yilmagan (`kubectl annotate deployment/hello kubernetes.io/change-cause="..."` bilan qo'yiladi).

Yangi versiya pod'lari `Ready` bo'lmasa, rollout to'xtab qoladi va eski pod'lar xizmat ko'rsatishda davom etadi. `spec.progressDeadlineSeconds` (standart 600) o'tgach Deployment `Progressing=False` holatiga o'tadi; `rollout status` shuni xato sifatida qaytaradi, `--timeout` bilan esa kamroq kutadi. Bu himoya faqat readiness probe to'g'ri yozilganda to'liq ishlaydi (4-dars): probe bo'lmasa "jarayon ishga tushdi" "tayyor" deb hisoblanadi.

**Tuzoq: `rollout undo` va git.** Imperativ rollback klasterni orqaga qaytaradi, lekin fayl yangi (buzuq) versiyada qoladi. Keyingi `apply` buzuq versiyani qaytarib qo'yadi. Barqaror yechim: git'da `revert`, keyin `apply`.

### Real ishda qachon kerak

- Har deploy rollout. CI/CD'da `kubectl rollout status --timeout=...` "deploy muvaffaqiyatli bo'ldimi" degan savolga exit code bilan javob beradi (9-dars).
- `rollout undo`: incident paytida eng tez tiklanish, keyin git'ni moslash.
- `rollout restart`: Secret yoki ConfigMap yangilangach pod'larni qayta o'qitish (7-bo'lim).

### Nima uchun shunday

ReplicaSet'ni o'zgartirish o'rniga yangisini yaratish rollback'ni arzon qiladi: kerakli template allaqachon klasterda turibdi, faqat sonlarni almashtirish qoladi. `package-lock.json` va image digest o'xshatishi shu yerda ham to'g'ri: reviziya aniq bir template'ga bog'langan, tag emas digest bo'lsa, qaytish ham aniq bo'ladi. Muqobil strategiya `Recreate` (hammasini o'chirib, keyin yangisini yaratish) qisqa uzilish beradi va faqat ikki versiya birga ishlay olmaganda kerak.

## 7. ConfigMap

### Bu nima

ConfigMap: konfiguratsiyani kalit-qiymat ko'rinishida saqlaydigan obyekt. Qiymat qisqa satr ham, butun fayl matni ham bo'lishi mumkin (limit 1 MiB). U konfiguratsiyani image'dan ajratadi: bir image, turli muhitlar, turli ConfigMap'lar. Maxfiy qiymatlar uchun emas, ular uchun Secret (4 va 13-darslar).

### Mexanizm: pod'ga ikki yo'l

Muhit o'zgaruvchisi (`env.valueFrom.configMapKeyRef` yoki `envFrom`) yoki volume (fayllar). Volume sifatida ulanganda har kalit katalogdagi bitta fayl bo'ladi:

```yaml
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          volumeMounts:
            - name: html
              mountPath: /usr/local/apache2/htdocs   # httpd document root
      volumes:
        - name: html
          configMap:
            name: hello-html
```

kubelet ConfigMap'ni o'qib, fayllarni node diskidagi vaqtinchalik katalogga yozadi va konteynerga mount qiladi. Katalog ichida fayllar `..data` simlink'i orqali ko'rsatiladi: yangilanishda kubelet yangi katalog yozib, simlink'ni bir harakatda almashtiradi, shuning uchun ilova hech qachon yarim yozilgan faylni ko'rmaydi.

ConfigMap o'zgarganda nima bo'ladi:

| Iste'mol usuli | Yangilanadimi |
|----------------|---------------|
| volume | ha, kubelet sinxronlash davri va kesh tufayli odatda bir daqiqa ichida |
| volume, `subPath` bilan | yo'q |
| env (`configMapKeyRef`, `envFrom`) | yo'q, faqat yangi pod'da |

Fayl yangilansa ham, ilova uni qayta o'qishi shart emas: ko'p server'lar konfiguratsiyani faqat ishga tushganda o'qiydi. ConfigMap o'zgarishi Deployment rollout'ini boshlamaydi, chunki pod template o'zgarmagan. Amaliy yechimlar: `kubectl rollout restart`; Helm'da template annotation'iga konfiguratsiya checksum'ini yozish; Kustomize'ning `configMapGenerator` i ConfigMap nomiga kontent hash'ini qo'shadi, nom o'zgargani uchun template ham o'zgaradi (9-dars).

### Misol

```
$ echo '<h1>hello v1</h1>' > index.html
$ kubectl -n demo create configmap hello-html --from-file=index.html
configmap/hello-html created
$ kubectl -n demo exec deploy/hello -- ls -la /usr/local/apache2/htdocs
total 0
drwxrwxrwx    3 root  root   80 <...> .
drwxr-xr-x    1 root  root   <...> ..
drwxr-xr-x    2 root  root   60 <...> ..2026_10_08_09_12_44.123456789
lrwxrwxrwx    1 root  root   32 <...> ..data -> ..2026_10_08_09_12_44.123456789
lrwxrwxrwx    1 root  root   17 <...> index.html -> ..data/index.html
```

`--from-file=index.html`: kalit fayl nomi, qiymat fayl matni. (Volume Deployment'ga yuqoridagi fragment bilan qo'shilgandan keyin.) `ls -la` mexanizmni ko'rsatadi: vaqt belgili yashirin katalog, unga `..data` simlink'i, `index.html` esa `..data` ichidagi faylga simlink. `kubectl edit configmap` yoki `apply` bilan matnni o'zgartirsangiz, bir daqiqa ichida yangi vaqt belgili katalog paydo bo'ladi va `..data` unga o'tadi; httpd statik faylni har so'rovda diskdan o'qigani uchun yangi matn darhol ko'rinadi. Server konfiguratsiyasida esa holat boshqa: uni jarayon faqat ishga tushganda o'qiydi (13–15 vazifalarda nginx bilan ko'rasiz).

**Tuzoq: buzuq konfiguratsiya va ishlab turgan pod'lar.** Noto'g'ri konfiguratsiya ConfigMap'ga yozilsa, ishlab turgan pod'lar eskisi bilan ishlayveradi va hammasi joyida ko'rinadi. Xato keyingi restart, masshtablash yoki node almashuvida, eng noqulay paytda chiqadi.

### Real ishda qachon kerak

Server konfiguratsiyasi (nginx, Envoy, Prometheus), feature flag'lar, muhitga xos URL'lar. Frontend'dagi o'xshatish: build vaqtida bundle'ga "pishiriladigan" `process.env` va runtime'da yuklanadigan `config.json`. ConfigMap ikkinchisiga o'xshaydi: bir artefakt, har muhitda o'z konfiguratsiyasi.

### Nima uchun shunday

Image ichiga konfiguratsiyani pishirish har o'zgarish uchun qayta build talab qiladi va "staging'da sinalgan image" bilan "production'dagi image" ni ajratadi. 12-factor tamoyili (konfiguratsiya muhitda, kodda emas) shu sababdan. Kubernetes ConfigMap o'zgarishini avtomatik rollout qilmaydi, chunki konfiguratsiya o'zgarishi xavfli bo'lishi mumkin va qachon qo'llashni foydalanuvchi hal qilsin degan tanlov qilingan.

## 8. Ingress va uning ekotizimi

### Bu nima

Service L4 darajada ishlaydi (IP va port). Ingress L7 (HTTP darajasi) qoidalarini tasvirlaydi: `Host` header'i va URL path bo'yicha trafikni turli Service'larga yo'naltirish, TLS. Ingress obyektining o'zi hech narsa qilmaydi: uni o'qib, haqiqiy proxy'ni sozlaydigan **ingress controller** kerak va u Kubernetes bilan birga kelmaydi.

### Mexanizm

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello
spec:
  rules:
    - host: hello.lab.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello
                port:
                  number: 80
```

Controller Ingress obyektlarini kuzatadi, ulardan proxy konfiguratsiyasini yig'adi va proxy'ga tashqi manzil kelganda uni Ingress'ning `status.loadBalancer` maydoniga yozadi (`kubectl get ingress` dagi `ADDRESS`). Bir klasterda bir nechta controller bo'lsa, qaysi biri qaysi Ingress'ni olishini `spec.ingressClassName` va IngressClass obyekti hal qiladi (`kubectl get ingressclass`).

`pathType` qiymatlari: `Prefix` (path `/` bo'yicha segmentlarga bo'linib, segmentlar prefiks sifatida solishtiriladi), `Exact` (aniq mos kelish), `ImplementationSpecific` (controller'ga bog'liq). Annotation'lar orqali beriladigan sozlamalar (rewrite, timeout) controller'ga xos va boshqasiga ko'chmaydi: bu Ingress API'ning asosiy zaifligi.

kind'da alohida controller o'rnatish shart emas: `cloud-provider-kind` v0.9.0 dan boshlab Ingress'ni o'zi amalga oshiradi. U host'da oddiy jarayon sifatida ishlaydi, kind klasterlarini kuzatadi va LoadBalancer Service, Ingress yoki Gateway uchun Docker'da `kindccm-...` nomli Envoy proxy konteynerini ko'taradi. Proxy'ning IP'si `kind` Docker tarmog'idan beriladi.

### Misol

```
$ kubectl -n demo get ingress hello
NAME    CLASS    HOSTS            ADDRESS      PORTS   AGE
hello   <none>   hello.lab.test   172.18.0.5   80      40s
$ docker run --rm --network kind curlimages/curl:8.10.1 -s -H 'Host: hello.lab.test' http://172.18.0.5/
<html><body><h1>It works!</h1></body></html>
```

`CLASS <none>`: `ingressClassName` yozilmagan (kind hujjatidagi misol ham shunday). `HOSTS` qoidadagi host, `ADDRESS` proxy konteynerining IP'si; u `cloud-provider-kind` ishlab turgandagina paydo bo'ladi. `PORTS 80`: TLS yo'q (TLS 8-darsda). `curl -H 'Host: ...'`: DNS yozuvi yo'q, shuning uchun to'g'ridan-to'g'ri IP'ga borib, host nomini header'da beramiz; proxy aynan shu header bo'yicha qoidani tanlaydi. Zorin'da `curl -H 'Host: hello.lab.test' http://172.18.0.5/` host'dan ham ishlaydi, macOS'da esa yo'q (Laboratoriya jadvaliga qarang).

### Ekotizimning hozirgi holati

Buni bilish muhim, chunki internetdagi aksariyat qo'llanmalar eskirgan:

- **ingress-nginx to'xtatilgan.** Kubernetes hamjamiyati yuritgan, eng ko'p tarqalgan controller (`kubernetes/ingress-nginx`) 2026-yil martidan boshlab qo'llab-quvvatlanmaydi: yangi reliz, bugfix va xavfsizlik yangilanishlari yo'q. Mavjud o'rnatmalar ishlayveradi, lekin yangi klasterga uni o'rnatmang, ishlab turganini migratsiya qilish kerak. F5 yuritadigan "NGINX Ingress Controller" (`nginx/kubernetes-ingress`) boshqa loyiha, ularni adashtirmang.
- **Ingress API muzlatilgan.** `networking.k8s.io/v1` Ingress barqaror va olib tashlanmaydi, lekin unga yangi imkoniyat qo'shilmaydi. Kubernetes loyihasi yangi ishlar uchun Gateway API'ni tavsiya qiladi.
- **Gateway API** Ingress'ning vorisi: rollar bo'yicha ajratilgan obyektlar (GatewayClass, Gateway, HTTPRoute), trafikni vazn bo'yicha bo'lish, header bo'yicha yo'naltirish kabi imkoniyatlar standartda. U CRD (Custom Resource Definition: API'ga yangi obyekt turi qo'shish usuli) sifatida o'rnatiladi. `cloud-provider-kind` uni ham qo'llaydi (GatewayClass nomi `cloud-provider-kind`), 6-darsda amalda ishlatamiz.
- Ingress'ni qo'llaydigan boshqa controller'lar ko'p: Traefik, HAProxy, Contour, Cilium, cloud provayderlarniki. Ularning ko'pi Gateway API'ni ham qo'llaydi.

### Real ishda qachon kerak

Bitta tashqi IP ortida bir nechta sayt yoki API: `shop.example.com` bir Service'ga, `api.example.com` boshqasiga, `/static` uchinchisiga. Ingress hali juda ko'p klasterda ishlaydi, shuning uchun uni o'qish va migratsiya qilish ko'nikmasi kerak, tushunchalari esa Gateway API'ga to'g'ridan-to'g'ri ko'chadi.

### Nima uchun shunday

Kubernetes ataylab faqat interfeysni (Ingress obyekti) belgiladi va amalga oshirishni controller'larga qoldirdi: har muhit o'z proxy'sini tanlasin. Bu Ingress'ni tez tarqatdi, lekin API juda tor qolgani uchun har controller imkoniyatlarni annotation'larga yashirdi va manifestlar ko'chmas bo'lib qoldi. Gateway API shu xatodan xulosa: imkoniyatlar API'ning o'zida, rollar (klaster operatori, ilova jamoasi) alohida obyektlarda.

## 9. Buzilgan deploy'ni debug qilish

### Bu nima

Pod ishlamasa, sabab bir necha joyning birida: scheduler (node topilmadi), kubelet va runtime (image tortilmadi, konteyner sozlanmadi), ilovaning o'zi (ishga tushib yiqildi) yoki tayyorlik tekshiruvi. Har biri o'z holat nomi bilan chiqadi.

### Mexanizm: tartib

Tartib har doim bir xil: `kubectl get pods` (holat), `kubectl describe pod` (event'lar va `Last State`), `kubectl logs` va `logs --previous` (ilova), oxirida `kubectl get events` (namespace bo'yicha). Debug'ni `logs` dan boshlash xato: konteyner hali yaratilmagan bo'lsa log yo'q.

| Holat | Ma'nosi | Odatiy sabablar | Qayerga qarash |
|-------|---------|-----------------|----------------|
| `Pending` | scheduler node topa olmadi | resurs yetmaydi, `nodeSelector` yoki taint mos emas, PVC bog'lanmagan | `describe pod`, `FailedScheduling` event'i |
| `ErrImagePull`, `ImagePullBackOff` | image tortib bo'lmadi | tag yoki nom xato, private registry uchun credential yo'q, tarmoq | `describe pod` event'lari |
| `CrashLoopBackOff` | konteyner ishga tushib, qayta-qayta chiqib ketyapti | ilova xatosi, noto'g'ri konfiguratsiya, liveness probe o'ldiryapti | `logs --previous`, `Last State` dagi exit code |
| `CreateContainerConfigError` | konteynerni sozlab bo'lmadi | ko'rsatilgan ConfigMap, Secret yoki kalit yo'q | `describe pod` |
| `Running`, lekin `READY 0/1` | konteyner ishlayapti, readiness o'tmayapti | probe yo'li yoki porti xato | `describe pod` dagi probe xatolari |
| `OOMKilled` (`Last State`) | xotira limiti oshdi | limit past yoki memory leak | `describe pod`, exit code 137 |

`BackOff` so'zi holat emas, kutish: kubelet qayta urinishlar orasidagi vaqtni eksponensial oshiradi (konteyner restartida 5 daqiqagacha). Pod'lar umuman yo'q bo'lsa, muammo bir pog'ona yuqorida: `kubectl describe deployment`, `kubectl describe replicaset` va ularning event'lari (masalan, quota oshgan yoki admission rad etgan).

### Misol: `Pending`

Pod'ga mavjud bo'lmagan node label'i bilan `nodeSelector: {disk: nvme}` berilgan:

```
$ kubectl -n demo get pods -l app.kubernetes.io/name=picky
NAME                     READY   STATUS    RESTARTS   AGE
picky-5c7d9f8b6-p4wq2    0/1     Pending   0          45s
$ kubectl -n demo describe pod picky-5c7d9f8b6-p4wq2 | tail -3
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  45s   default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 node(s) didn't match Pod's node affinity/selector. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

`0/3 nodes are available`: scheduler uchala node'ni tekshirdi, birortasi mos kelmadi. Keyin har sabab va u nechta node'ga tegishli: control-plane'da taint bor (2-darsda ko'rgansiz), ikki worker'da kerakli label yo'q. `preemption` qismi: past prioritetli pod'larni chiqarib joy ochish ham yordam bermaydi. `Node:` maydoni bo'sh, `From` scheduler: muammo kubelet'gacha yetmagan.

### Misol: `CrashLoopBackOff`

`busybox:1.36` konteyneri `sh -c 'echo starting; exit 3'` buyrug'i bilan:

```
$ kubectl -n demo get pods -l app.kubernetes.io/name=crashy
NAME                      READY   STATUS             RESTARTS      AGE
crashy-6b8d4c7f9-zt5mn    0/1     CrashLoopBackOff   3 (25s ago)   80s
$ kubectl -n demo describe pod crashy-6b8d4c7f9-zt5mn | grep -A4 'Last State'
    Last State:     Terminated
      Reason:       Error
      Exit Code:    3
      Started:      <sana>
      Finished:     <sana>
$ kubectl -n demo logs crashy-6b8d4c7f9-zt5mn --previous
starting
```

`RESTARTS 3 (25s ago)`: konteyner uch marta qayta ishga tushgan, oxirgisi 25 soniya oldin. `Last State: Terminated`, `Exit Code: 3`: jarayon o'zi 3 kodi bilan chiqdi (signal bilan o'ldirilganda 128+signal: 137 SIGKILL, 143 SIGTERM). `logs --previous` yiqilgan nusxaning chiqishi. Haqiqiy ilovada shu yerda stack trace yoki "config not found" turadi.

### Real ishda qachon kerak

Deploy'dan keyingi birinchi besh daqiqa. Kim debug qilsa ham shu jadval va tartib bir xil: bu jamoa uchun umumiy til. 6-darsdagi "ulanishni qatlamma-qatlam debug qilish" shu tartibni tarmoqqa kengaytiradi.

### Nima uchun shunday

Kubernetes har bosqichni alohida komponentga topshiradi (scheduler, kubelet, runtime), shuning uchun xabarlar ham shu komponentlardan, `From` ustunida nomi bilan keladi. Eksponensial backoff esa yiqilayotgan ilova node'ni va registry'ni cheksiz qayta urinishlar bilan bosib qo'ymasligi uchun. `CrashLoopBackOff` da pod'ni o'chirib qayta yaratish sababni yo'qotmaydi, faqat dalilni (`--previous` log'ini) yo'qotadi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Imperativ | "shuni qil" buyruqlari bilan boshqarish (`create`, `scale`, `set image`) |
| Deklarativ | kerakli holatni faylda yozib, `apply` bilan klasterga berish |
| Manifest | Kubernetes obyektini tavsiflovchi YAML fayl |
| Deployment | stateless pod'lardan N nusxani ushlab turuvchi va yangilovchi obyekt |
| ReplicaSet | aniq bir pod template'idan N nusxani ushlab turuvchi obyekt, Deployment yaratadi |
| Pod template | Deployment ichidagi yaratiladigan pod'larning qolipi (`spec.template`) |
| Selector | label bo'yicha obyektlar to'plamini tanlash qoidasi |
| Annotation | tanlash uchun emas, ma'lumot saqlash uchun kalit-qiymat |
| Idempotent | necha marta bajarilsa ham natijasi bir xil amal |
| Drift | klasterdagi holatning manba fayldan ajralib ketishi |
| Server-side apply | apply hisobini API server bajaradi, maydon egalari `managedFields` da |
| Service | pod'lar to'plamiga barqaror nom va virtual IP beruvchi obyekt |
| EndpointSlice | Service'ga mos va tayyor pod IP'lari ro'yxati |
| `port-forward` | host portidan API server orqali bitta pod'ga tunnel |
| Event | komponent obyekt bilan nima qilganini yozadigan qisqa umrli yozuv |
| Rollout | pod template o'zgarganda pod'larni bosqichma-bosqich almashtirish |
| Rollback | oldingi reviziya ReplicaSet'iga qaytish |
| Reviziya | Deployment template'ining raqamlangan versiyasi |
| ConfigMap | maxfiy bo'lmagan konfiguratsiyani saqlovchi obyekt |
| Ingress | host va path bo'yicha HTTP marshrutlash qoidalari obyekti |
| Ingress controller | Ingress'ni o'qib haqiqiy proxy'ni sozlaydigan dastur |
| IngressClass | Ingress'ni qaysi controller bajarishini belgilovchi obyekt |
| Gateway API | Ingress'ning vorisi, rollar bo'yicha ajratilgan L7 API |
| `cloud-provider-kind` | kind uchun LoadBalancer, Ingress va Gateway'ni Docker konteynerlari bilan amalga oshiruvchi jarayon |
| BackOff | qayta urinishlar orasidagi eksponensial oshuvchi kutish |

## Tuzoqlar

- `image: nginx` yoki `:latest`: qaysi versiya ishlayotgani noma'lum, rollback imkonsiz, node'lar turli versiyani tortishi mumkin. Har doim aniq tag, production'da digest.
- Klasterni qo'lda o'zgartirish (`edit`, `scale`, `set image`) va faylni yangilamaslik: keyingi `apply` kutilmagan natija beradi.
- `rollout undo` dan keyin git'ni orqaga qaytarmaslik.
- ConfigMap'ni o'zgartirib, rollout qilmaslik: xato keyingi restart'gacha yashirin qoladi.
- `subPath` bilan ulangan ConfigMap faylining yangilanishini kutish: u hech qachon yangilanmaydi.
- `port-forward` ni doimiy kirish usuli sifatida ishlatish.
- ingress-nginx'ni eski qo'llanma bo'yicha yangi klasterga o'rnatish: xavfsizlik yangilanishi yo'q komponent internetga qaragan bo'ladi.
- Ingress yaratib, controller ishlayotganini va `ingressClassName` ni tekshirmaslik: obyekt bor, `ADDRESS` bo'sh, hech narsa ishlamaydi. kind'da eng ko'p sabab: `cloud-provider-kind` to'xtatilgan.
- macOS'da Ingress IP'sini host'dan `curl` qilish: Docker VM ichida, IP ko'rinmaydi. Port mapping yoki `--network kind` konteyner ishlating.
- Debug'ni `logs` dan boshlash. Konteyner hali yaratilmagan bo'lsa log yo'q; avval `describe`.
- `CrashLoopBackOff` da pod'ni o'chirib qayta yaratish: sabab yo'qolmaydi, faqat dalil yo'qoladi.
- Imperativ yaratilgan Deployment'ni boshqa label'li manifest bilan `apply` qilish: selector o'zgarmas, xato.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ – Deployment, rollout, rollback
- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/ – deklarativ boshqaruv, apply mexanizmi
- https://kubernetes.io/docs/reference/using-api/server-side-apply/ – server-side apply
- https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/ – tavsiya etilgan label'lar
- https://kubernetes.io/docs/concepts/services-networking/service/ – Service
- https://kubernetes.io/docs/concepts/configuration/configmap/ – ConfigMap
- https://kubernetes.io/docs/concepts/services-networking/ingress/ – Ingress
- https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/ – ingress-nginx to'xtatilishi haqida rasmiy e'lon
- https://gateway-api.sigs.k8s.io/ – Gateway API
- https://kind.sigs.k8s.io/docs/user/ingress/ – kind'da Ingress
- https://github.com/kubernetes-sigs/cloud-provider-kind – cloud-provider-kind, macOS bo'limi
- https://kubernetes.io/docs/tasks/debug/debug-application/ – ilovani debug qilish

---

## Birga bajaramiz

Vazifalardagidan boshqa ilovani boshidan oxirigacha olib chiqamiz: `agnhost` (Kubernetes o'z testlarida ishlatadigan kichik yordamchi server, `netexec` rejimida `/hostname` yo'lida pod nomini qaytaradi). Hammasi alohida `walk` namespace'ida va repo'dan tashqaridagi `~/k3-walk` papkasida, hech narsa commit qilinmaydi.

1. Namespace va papka:

```
$ mkdir ~/k3-walk && cd ~/k3-walk
$ kubectl create namespace walk
namespace/walk created
```

2. Manifest. Bitta faylda bir nechta obyekt `---` bilan ajratiladi. Muhit o'zgaruvchisi ConfigMap'dan olinadi:

```
$ cat app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: echo-settings
  namespace: walk
data:
  GREETING: salom
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: walk
  labels:
    app.kubernetes.io/name: echo
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: echo
  template:
    metadata:
      labels:
        app.kubernetes.io/name: echo
    spec:
      containers:
        - name: agnhost
          image: registry.k8s.io/e2e-test-images/agnhost:2.39
          args: ["netexec", "--http-port=8080"]
          envFrom:
            - configMapRef:
                name: echo-settings
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: walk
spec:
  selector:
    app.kubernetes.io/name: echo
  ports:
    - port: 80
      targetPort: 8080
```

Service `port: 80` ni konteynerning `8080` portiga bog'laydi: mijozlar standart portni ko'radi, ilova esa imtiyozsiz portda tinglaydi.

3. Avval `diff`, keyin `apply`:

```
$ kubectl diff -f app.yaml > /dev/null; echo $?
1
$ kubectl apply -f app.yaml
configmap/echo-settings created
deployment.apps/echo created
service/echo created
$ kubectl -n walk rollout status deployment/echo
deployment "echo" successfully rolled out
```

Obyektlar hali yo'q, shuning uchun `diff` ularning hammasini "qo'shiladi" deb ko'rsatdi (exit code `1`). `apply` fayldagi tartibda yaratdi.

4. Klaster ichidan va `port-forward` orqali tekshirish:

```
$ kubectl -n walk run probe --rm -it --image=busybox:1.36 --restart=Never -- sh -c 'for i in 1 2 3 4; do wget -qO- http://echo/hostname; echo; done'
echo-5f9c8d7b6-2xk4q
echo-5f9c8d7b6-9wl7m
echo-5f9c8d7b6-9wl7m
echo-5f9c8d7b6-2xk4q
pod "probe" deleted
$ kubectl -n walk exec deploy/echo -- env | grep GREETING
GREETING=salom
```

Klaster ichidan Service orqali so'rovlar ikki pod'ga tarqaldi. `env` ConfigMap qiymati muhit o'zgaruvchisi bo'lib kelganini ko'rsatadi.

5. ConfigMap'ni o'zgartirish. `app.yaml` da `GREETING: salom` ni `GREETING: assalomu alaykum` ga o'zgartiring:

```
$ kubectl apply -f app.yaml
configmap/echo-settings configured
deployment.apps/echo unchanged
service/echo unchanged
$ kubectl -n walk exec deploy/echo -- env | grep GREETING
GREETING=salom
$ kubectl -n walk rollout restart deployment/echo
deployment.apps/echo restarted
$ kubectl -n walk rollout status deployment/echo
deployment "echo" successfully rolled out
$ kubectl -n walk exec deploy/echo -- env | grep GREETING
GREETING=assalomu alaykum
```

Deployment `unchanged`: template o'zgarmagan, rollout yo'q, env eski qiymatda. `rollout restart` yangi pod'lar yaratdi va ular yangi qiymatni oldi.

6. Buzuq image va rollback. `image:` ni `registry.k8s.io/e2e-test-images/agnhost:0.0.0-nope` ga o'zgartirib `apply` qiling:

```
$ kubectl -n walk rollout status deployment/echo --timeout=30s
Waiting for deployment "echo" rollout to finish: 1 out of 2 new replicas have been updated...
error: timed out waiting for the condition
$ kubectl -n walk get pods
NAME                    READY   STATUS             RESTARTS   AGE
echo-6c4f7d9b8-mx2rp    0/1     ImagePullBackOff   0          35s
echo-7b9d6c5f4-hk8tz    1/1     Running            0          3m
echo-7b9d6c5f4-ws4nb    1/1     Running            0          3m
$ kubectl -n walk rollout undo deployment/echo
deployment.apps/echo rolled back
$ kubectl -n walk get pods
NAME                    READY   STATUS    RESTARTS   AGE
echo-7b9d6c5f4-hk8tz    1/1     Running   0          3m
echo-7b9d6c5f4-ws4nb    1/1     Running   0          3m
```

2 replikada `maxSurge` 1, `maxUnavailable` 0 bo'ladi: bitta yangi pod yaratildi, u `Ready` bo'lmagani uchun eskilariga tegilmadi va servis ishlashda davom etdi. `undo` dan keyin buzuq pod o'chdi. Faylda esa buzuq tag hali turibdi: uni o'zingiz qaytaring va `kubectl diff -f app.yaml` bo'sh (exit code `0`) ekanini tekshiring. Aynan shu qadam esdan chiqsa keyingi `apply` buzuq versiyani qaytaradi.

7. Ingress. Ikkinchi terminalda `cloud-provider-kind` ni Laboratoriya jadvalidagidek ishga tushiring, keyin:

```
$ kubectl -n walk create ingress echo --rule='echo.lab.test/*=echo:80'
ingress.networking.k8s.io/echo created
$ kubectl -n walk get ingress echo
NAME   CLASS    HOSTS           ADDRESS      PORTS   AGE
echo   <none>   echo.lab.test   172.18.0.6   80      30s
$ docker run --rm --network kind curlimages/curl:8.10.1 -s -H 'Host: echo.lab.test' http://172.18.0.6/hostname
echo-7b9d6c5f4-ws4nb
$ docker ps --filter name=kindccm --format '{{.Names}} {{.Ports}}'
kindccm-<...> <...>
```

`kubectl create ingress --rule='HOST/PATH=SERVICE:PORT'` tez sinov uchun imperativ yo'l (`/*` `Prefix` turini bildiradi). `ADDRESS` paydo bo'lgach so'rov Envoy proxy orqali pod'ga yetdi. `docker ps` dagi `kindccm-...` aynan shu proxy; macOS'da `Ports` ustunida `localhost` ga mapping ko'rinadi.

8. Tozalash:

```
$ kubectl delete namespace walk
namespace "walk" deleted
$ rm -r ~/k3-walk
```

`cloud-provider-kind` ni hozircha to'xtatmang, agar F guruhga o'tsangiz.

---

## Vazifalar

Barchasini `kubernetes/03-first-deploy/` papkasida bajaring (`make new m=kubernetes n=03 name=first-deploy`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar shu papkadagi `manifests/` ichiga saqlanadi. Hammasi `web` namespace'ida (21-vazifadan tashqari). Har javob boshida qaysi mashinada bajarilganini (`uname -s`) yozing: Ingress va `docker ps` natijalari Zorin va macOS'da farq qiladi.

### A. Imperativ

1. **Imperative deployment.** `kubectl create deployment`, `expose` va `port-forward` bilan nginx'ni ishga tushirib, `curl` bilan javob oling. Yaratilgan barcha obyektlarni (`kubectl get all`) sanab, har biri qaysi buyruqdan paydo bo'lganini yozing. Keyin hammasini o'chiring.

2. **Generate manifests.** `--dry-run=client -o yaml` bilan Deployment va Service manifestlarini generatsiya qiling. Generatsiya qilingan faylda keraksiz maydonlar bormi (`creationTimestamp: null`, `status: {}`, `resources: {}`)? Ularni tozalang. `--dry-run=client` va `--dry-run=server` farqini noto'g'ri maydon nomi yozilgan manifestda sinab ko'rsating.

### B. Deklarativ

3. **Deployment manifest.** `manifests/deployment.yaml` ni qo'lda yozing: 3 replika, `nginx:1.27`, tavsiya etilgan `app.kubernetes.io/*` label'laridan kamida ikkitasi. `apply` qiling. Keyin template label'ini selector'ga mos kelmaydigan qilib ko'ring va API server xatosini yozing. Mavjud Deployment'da selector'ni o'zgartirib ko'ring: qanday xato chiqdi va nima uchun bunday cheklov bor?

4. **Service and port-forward.** `manifests/service.yaml` yozing va qo'llang. `kubectl port-forward service/web 8080:80` orqali 10 marta `curl` qiling, so'ng `kubectl logs -l app=web --prefix` (label'ni o'z manifestingizdagiga moslang, yoki har pod uchun alohida) bilan so'rovlar nechta pod'ga tushganini aniqlang. Natijani izohlang. Tunnel ulangan pod'ni o'chirsangiz nima bo'ladi?

5. **kubectl diff.** Faylda replikalar sonini va image tag'ini o'zgartiring. `kubectl diff -f` natijasini va uning exit code'ini (`echo $?`) ko'rsating. Bu exit code CI pipeline'da qanday ishlatilishi mumkin? Keyin `apply` qiling va `diff` endi bo'sh ekanini tekshiring.

6. **Drift.** `kubectl scale deployment web --replicas=5` va `kubectl set image` bilan klasterni qo'lda o'zgartiring, faylga tegmang. `kubectl diff` nimani ko'rsatadi? `apply` dan keyin qaysi qo'lda qilingan o'zgarishlar bekor bo'ldi? Keyin fayldan `replicas` qatorini butunlay olib tashlab `apply` qiling va yana `scale` qiling: endi `apply` replikalar soniga tegadimi? `metadata.managedFields` (`--show-managed-fields` bilan) yoki `last-applied-configuration` annotation'i yordamida izohlang.

### C. Kuzatish

7. **Describe and events.** Bitta pod uchun `kubectl describe pod` natijasidan toping: qaysi node, IP, image digest, konteyner qachon ishga tushgan, QoS class, event'lar ketma-ketligi. `kubectl get events` ni vaqt bo'yicha saralab, Deployment yaratilishidan pod `Started` bo'lgunicha zanjirni ko'rsating.

8. **Logs.** Bir nechta `curl` so'rov yuboring va log'larni uch usulda oling: bitta pod, label bo'yicha barcha pod'lar, `deploy/web` orqali. `--tail`, `--since`, `-f` va `--timestamps` flag'larini sinang. nginx access log nima uchun `kubectl logs` da ko'rinadi (image ichida log fayli qayerga yo'naltirilgan)?

9. **Exec and debug.** `kubectl exec` bilan pod ichida `nginx -T` ni bajaring va joriy konfiguratsiyani ko'ring. Vaqtinchalik pod (`kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh`) ichidan `wget -qO- http://web` bilan Service'ga nom orqali murojaat qiling. `exec` orqali `index.html` ni o'zgartiring va pod'ni o'chiring: o'zgarish qayerga ketdi? Xulosa yozing.

### D. Rollout

10. **Rolling update.** Bitta terminalda `kubectl get rs -w`, ikkinchisida `kubectl get pods -w` qoldiring. Faylda image'ni `nginx:1.28` ga o'zgartirib `apply` qiling. ReplicaSet'lar soni qanday o'zgardi? Bir vaqtda eng ko'pi va eng kami nechta pod bor edi? Eski ReplicaSet nima uchun o'chirilmadi? `kubernetes.io/change-cause` annotation'ini qo'shib, `rollout history` da ko'rinishini tekshiring.

11. **Failed rollout.** Image tag'ini mavjud bo'lmagan qiymatga (`nginx:9.99`) o'zgartirib `apply` qiling. `kubectl rollout status --timeout=60s` nima qaytardi (exit code bilan)? Pod'lar qaysi holatda? Shu paytda `port-forward` orqali sayt ishlayaptimi va nima uchun? `describe pod` dan aniq xato matnini yozing.

12. **Rollback.** 11-vazifadagi holatdan `rollout undo` bilan chiqing. `rollout history` da reviziya raqamlari qanday o'zgardi? Aniq reviziyaga (`--to-revision`) qaytishni ham sinang. Endi `kubectl diff -f` nimani ko'rsatadi va bu nimadan ogohlantiradi? To'g'ri rollback tartibini (git bilan) yozing.

### E. ConfigMap

13. **nginx config from ConfigMap.** `default.conf` yozing: `/healthz` yo'li `200` va `ok` matnini qaytarsin, barcha javoblarga `X-Served-By` header'i `$hostname` qiymati bilan qo'shilsin. Undan ConfigMap manifestini yarating va Deployment'ga volume sifatida ulang (nginx `/etc/nginx/conf.d/*.conf` fayllarini o'qiydi). `curl -i` bilan header va `/healthz` ni tekshiring. Header qiymati nimaga teng va nima uchun?

14. **Config update.** ConfigMap'dagi `/healthz` javob matnini o'zgartirib `apply` qiling. Pod ichidagi fayl qachon yangilandi (`kubectl exec ... cat` bilan kuzating)? nginx yangi matnni qaytaryaptimi? Nima uchun? Muammoni `rollout restart` bilan hal qiling. ConfigMap o'zgarishi avtomatik rollout boshlashi uchun qanday yondashuvlar borligini yozing.

15. **Broken config.** ConfigMap'ga sintaktik xato nginx konfiguratsiyasi yozing va `apply` qiling. Ishlab turgan pod'larga nima bo'ldi? Endi `rollout restart` qiling: yangi pod'lar qaysi holatda, eski pod'lar-chi? `kubectl logs` va `logs --previous` dan nginx xatosini toping. Bu vaziyat production'da nima uchun xavfli ekanini va qanday oldini olishni yozing. Konfiguratsiyani tuzating.

### F. Ingress

16. **Ingress routing.** `cloud-provider-kind` ni ishga tushiring (Laboratoriya jadvalidagi mashinangizga mos buyruq). Ikkinchi Deployment va Service yarating (`api`, boshqa `index.html` yoki boshqa image). Bitta Ingress yozing: `web.example.test` host'i `web` ga, `api.example.test` host'i `api` ga borsin. `kubectl get ingress` da `ADDRESS` paydo bo'lishini kuting va `curl -H 'Host: ...'` bilan ikkala yo'nalishni tekshiring (macOS'da port mapping yoki `--network kind` usuli). Noma'lum host bilan so'rov nima qaytaradi? `docker ps` da qanday yangi konteyner paydo bo'ldi?

17. **Path routing.** Ingress'ni o'zgartiring: bitta host, `/` yo'li `web` ga, `/api` yo'li `api` ga. `pathType: Prefix` va `Exact` farqini `/api`, `/api/`, `/api/v1`, `/apiv2` so'rovlari bilan sinab, natijani jadvalda ko'rsating. Backend `/api/v1` yo'lini qanday ko'ryapti (uning access log'idan) va bu qanday muammo tug'dirishi mumkin?

18. **Ingress ecosystem status.** Rasmiy manbalarni o'qing: ingress-nginx to'xtatilishi haqidagi e'lon va Ingress hujjatining boshidagi eslatma. O'z so'zingiz bilan yozing: nima to'xtatildi va nima to'xtatilmadi (controller va API farqi), mavjud o'rnatmalarga nima bo'ladi, yangi klaster uchun siz nimani tanlagan bo'lardingiz va nima uchun. `kubectl get ingressclass` sizning klasteringizda nimani ko'rsatadi?

### G. Debug

19. **Pending pod.** Konteynerga `resources.requests.cpu: "100"` (100 yadro) bilan alohida Deployment yarating. Pod holati va `describe pod` dagi event matnini yozing. Xabardagi har qismni izohlang (nechta node tekshirildi, har biri nima uchun mos kelmadi). Tuzating.

20. **Config error.** Deployment'da mavjud bo'lmagan ConfigMap'ga volume orqali va boshqa variantda `env.valueFrom.configMapKeyRef` orqali murojaat qiling. Ikki holatda pod holati bir xilmi? Har birining event'ini yozing. 9-bo'limdagi jadvaldan foydalanib, to'rtta holatni (`Pending`, `ImagePullBackOff`, `CrashLoopBackOff`, `CreateContainerConfigError`) shu darsda ko'rgan misollaringiz bilan to'ldirilgan o'z jadvalingizni tuzing: alomat, qaysi buyruq sababni ko'rsatdi.

### H. Yakuniy

21. **Static site.** Alohida `site` namespace'ida to'liq deklarativ loyiha yig'ing, hammasi `manifests/site/` papkasida va bitta `kubectl apply -f manifests/site/` bilan ko'tarilsin: Namespace, ConfigMap (`index.html` va nginx konfiguratsiyasi), Deployment (3 replika, aniq tag), Service, Ingress. Tekshiring: Ingress orqali sahifa ochiladi; `index.html` ni o'zgartirib yangi versiyani chiqaring va chiqarish paytida `while true; do curl ...; sleep 0.2; done` sikli bitta ham xato ko'rmasligini ko'rsating (macOS'da siklni port mapping manziliga qarating); buzuq image bilan rollout qilib, foydalanuvchi buni sezmasligini va qanday qaytarganingizni yozing. Oxirida namespace'ni o'chiring.

## Topshirish

Tayyor bo'lgach:

1. `README.md` da barcha 21 vazifa yozilgan, manifestlar `manifests/` da.
2. `make check` toza o'tadi (`yamllint`).
3. `kubectl apply --dry-run=server -f manifests/site/` xatosiz (Namespace hali yo'q bo'lsa, namespace'li obyektlar uchun xato chiqishi mumkin: unda avval faqat Namespace faylini qo'llang, buni README'da qayd eting).
4. `web` va `site` namespace'lari o'chirilgan, `cloud-provider-kind` to'xtatilgan, `docker ps` da `kindccm-...` konteynerlari yo'q.
5. Ish papkasida kubeconfig yoki boshqa maxfiy fayl yo'q.
6. Menga xabar bering, tekshiraman.

## O'zini tekshirish savollari

Kodsiz, o'z so'zingiz bilan javob bering:

- `kubectl apply` farqni qanday hisoblaydi va fayldan olib tashlangan maydon bilan nima bo'ladi?
- Deployment manifestidagi uch joydagi label'ning har biri nima qiladi va selector nima uchun o'zgarmas?
- Rollout paytida ReplicaSet'lar bilan nima sodir bo'ladi va rollback nimaga tayanadi?
- Yangi versiya ishga tushmasa, eski pod'lar nima uchun xizmat ko'rsatishda davom etadi?
- ConfigMap o'zgarganda pod'ga nima yetib boradi, nima yetib bormaydi?
- Ingress obyekti va ingress controller farqi nima? kind'da bu rolni kim bajaradi?
- ingress-nginx bilan nima bo'ldi, Ingress API bilan nima bo'ldi, Gateway API bu yerda qanday o'rin tutadi?
- macOS'da Ingress IP'si nima uchun host'dan ochilmaydi va qanday aylanib o'tiladi?
- `ImagePullBackOff`, `CrashLoopBackOff` va `Pending` holatlarida birinchi qaysi buyruqni ishlatasiz va nimani qidirasiz?
- `port-forward` nima uchun production kirish usuli emas?
- `rollout undo` dan keyin nima uchun git'ni ham orqaga qaytarish kerak?
