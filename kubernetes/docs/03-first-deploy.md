# 3-dars: Birinchi ilova, nginx deploy

Maqsad: bitta oddiy ilovani (nginx) Kubernetes'ga to'liq yo'l bilan olib chiqish: avval imperativ buyruqlar bilan, keyin deklarativ manifestlar bilan; Deployment, Service, ConfigMap va Ingress'ni birga ishlatish; yangilash va orqaga qaytarish; buzilgan deploy'ni tizimli debug qilish. 1-darsda obyektlar nazariyasini, 2-darsda klaster qurishni ko'rdingiz. Bu dars kundalik ish siklini beradi: yoz, `diff`, `apply`, kuzat, tuzat. 4–8 darslar shu yerda yuzaki tekkan har obyektni (workload'lar, Service, storage, TLS) alohida chuqurlashtiradi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqatni quyidagilarga qarating: `apply` qanday ishlaydi va drift nima, rollout paytida ReplicaSet'lar bilan nima bo'ladi, ConfigMap o'zgarishi pod'ga qachon yetadi, va eng muhimi debug tartibi: `get`, `describe`, `logs`, event'lar.

## Laboratoriya

kind klasteri, uch node bilan. 1-darsdagi `dev` klasterini o'chirib, 2-darsdagi `kind-multi.yaml` konfiguratsiyasi bilan qayta yarating:

```bash
kind delete cluster --name dev
kind create cluster --name dev --config kind-multi.yaml
kubectl create namespace web && kubectl config set-context --current --namespace=web
```

Ingress qismi uchun `cloud-provider-kind` kerak. U ish mashinasida oddiy jarayon sifatida ishlaydi, kind klasterlarini kuzatadi va LoadBalancer hamda Ingress uchun Docker'da proxy konteyner ko'taradi. Binary'ni loyihaning releases sahifasidan yuklab oling (https://github.com/kubernetes-sigs/cloud-provider-kind/releases, `linux_amd64` arxivi), `~/.local/bin` ga qo'ying va alohida terminalda ishlatib qo'ying:

```bash
cloud-provider-kind
```

Jarayon ishlab turgan vaqtdagina LoadBalancer va Ingress manzil oladi. Tozalash: jarayonni `Ctrl+C` bilan to'xtating, `kubectl delete namespace web`, kerak bo'lsa `kind delete cluster --name dev`.

---

## 1. Imperativ yo'l

Tez sinov uchun uchta buyruq yetarli:

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=2
kubectl expose deployment web --port=80
kubectl port-forward service/web 8080:80     # then: curl localhost:8080
```

Imperativ buyruqlarning muammosi: ular tarixda qoladi, holatda emas. Bir oydan keyin klasterda nima uchun aynan shu sozlama turgani noma'lum, boshqa muhitda takrorlash uchun buyruqlarni eslash kerak.

Foydali ko'prik: imperativ buyruqdan manifest generatsiya qilish.

```bash
kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml > deployment.yaml
```

`--dry-run=client` hech narsa yaratmaydi, faqat obyektni chiqaradi. `--dry-run=server` so'rovni API server'ga yuboradi (validatsiya va admission ishlaydi), lekin saqlamaydi.

## 2. Deklarativ yo'l

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels: {app: web}
spec:
  replicas: 2
  selector:
    matchLabels: {app: web}      # which pods belong to this Deployment
  template:                      # pod template
    metadata:
      labels: {app: web}         # must match the selector
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

Uch joyda label bor va ular uch xil vazifa bajaradi: `metadata.labels` Deployment'ning o'z label'i, `spec.selector` qaysi pod'lar uniki ekanini aytadi, `spec.template.metadata.labels` yaratiladigan pod'larga qo'yiladi. Selector va template label'lari mos kelmasa API server manifestni rad etadi. `spec.selector` yaratilgandan keyin o'zgartirilmaydi.

### apply qanday ishlaydi

`kubectl apply -f` obyekt yo'q bo'lsa yaratadi, bor bo'lsa farqini qo'llaydi. Farqni hisoblash uchun uch narsa solishtiriladi: fayldagi yangi holat, klasterdagi joriy holat va oxirgi marta qo'llangan holat (client-side apply'da u `kubectl.kubernetes.io/last-applied-configuration` annotation'ida saqlanadi). Shu sabab fayldan olib tashlangan maydon klasterdan ham olib tashlanadi, siz boshqarmagan maydonlarga (masalan, autoscaler yozgan `replicas`) esa tegilmaydi.

Server-side apply (`kubectl apply --server-side`) shu hisobni API server'ga ko'chiradi va har maydonning "egasini" (`managedFields`) kuzatadi: ikki asbob bitta maydonni boshqarmoqchi bo'lsa konflikt xatosi chiqadi.

```bash
kubectl diff -f deployment.yaml      # what would change, exit code 1 if there is a diff
kubectl apply -f deployment.yaml
kubectl apply -f ./manifests/        # a whole directory
```

**Tuzoq: drift.** Kimdir `kubectl edit` yoki `kubectl scale` bilan klasterni qo'lda o'zgartirsa, fayl va klaster ajralib qoladi. Keyingi `apply` qo'lda qilingan o'zgarishning bir qismini bekor qiladi, bir qismini yo'q. Qoida: manba fayl, klasterga faqat fayl orqali yoziladi. `kubectl diff` CI'da drift'ni ko'rsatadi, 10-darsda GitOps buni avtomatlashtiradi.

## 3. Service va port-forward

Pod IP'lari vaqtinchalik: pod qayta yaratilsa IP o'zgaradi. Service selector bo'yicha pod'lar to'plamiga barqaror nom va virtual IP beradi (6-darsda mexanizmi).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector: {app: web}
  ports:
  - port: 80          # service port
    targetPort: 80    # container port
```

Standart tur `ClusterIP`: faqat klaster ichidan ko'rinadi. Tashqaridan tekshirish uchun `kubectl port-forward` ishlatiladi: u ish mashinangizdagi portdan API server va kubelet orqali pod'gacha tunnel ochadi.

**Tuzoq: `port-forward` bu debug vositasi.** `port-forward service/web` Service orqali balanslamaydi: u Service'ning bitta pod'ini tanlab, faqat o'shanga ulanadi. Pod o'lsa tunnel uziladi. Foydalanuvchi trafigi uchun Service turlari va Ingress ishlatiladi.

## 4. Kuzatish va tekshirish

| Buyruq | Qachon |
|--------|--------|
| `kubectl get pods -o wide` | umumiy holat: `STATUS`, `READY`, `RESTARTS`, node |
| `kubectl describe pod NAME` | sabab qidirish: `Events` bo'limi, konteyner `State` va `Last State` |
| `kubectl logs NAME` | ilova chiqishi (stdout, stderr) |
| `kubectl logs NAME --previous` | qayta ishga tushgan konteynerning oldingi nusxasi log'i |
| `kubectl logs -l app=web --tail=20 -f` | label bo'yicha bir nechta pod, oqim |
| `kubectl logs deploy/web -c nginx` | Deployment'ning bitta pod'i, aniq konteyner |
| `kubectl exec -it NAME -- sh` | konteyner ichida buyruq |
| `kubectl debug -it NAME --image=busybox:1.36 --target=nginx` | shell'i yo'q image uchun vaqtinchalik (ephemeral) konteyner |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | namespace bo'yicha voqealar |

Event'lar taxminan bir soat saqlanadi, keyin o'chadi. Kechagi nosozlik sababini event'lardan topa olmaysiz, buning uchun observability modulidagi log va metrika yig'ish kerak.

## 5. Rollout va rollback

Deployment pod template'i (`spec.template`) o'zgarsa yangi rollout boshlanadi: Deployment yangi ReplicaSet yaratadi, uni bosqichma-bosqich kattalashtiradi va eskisini kichraytiradi. Eski ReplicaSet o'chirilmaydi, 0 replika bilan qoladi: rollback aynan unga qaytish. `replicas` o'zgarishi rollout emas, faqat masshtablash.

```bash
kubectl set image deployment/web nginx=nginx:1.28   # imperative; or edit the file and apply
kubectl rollout status deployment/web               # blocks until done, non-zero on failure
kubectl rollout history deployment/web
kubectl rollout undo deployment/web                 # back to the previous revision
kubectl rollout undo deployment/web --to-revision=2
kubectl rollout restart deployment/web              # new pods with the same spec
```

- Saqlanadigan eski ReplicaSet'lar soni `spec.revisionHistoryLimit` bilan belgilanadi (standart 10).
- `rollout history` dagi `CHANGE-CAUSE` ustuni `kubernetes.io/change-cause` annotation'idan olinadi.
- Yangi versiya pod'lari tayyor bo'lmasa (`Ready` emas), rollout to'xtab qoladi va eski pod'lar xizmat ko'rsatishda davom etadi. Bu himoya faqat readiness probe to'g'ri yozilganda ishlaydi (4-dars).
- `rollout status` CI/CD'da "deploy muvaffaqiyatli bo'ldimi" degan savolga javob beradi (9-dars).

**Tuzoq: `rollout undo` va git.** Imperativ rollback klasterni orqaga qaytaradi, lekin fayl yangi versiyada qoladi. Keyingi `apply` buzuq versiyani qaytarib qo'yadi. To'g'ri rollback: git'da `revert`, keyin `apply`.

## 6. ConfigMap bilan nginx konfiguratsiyasi

Image ichiga konfiguratsiyani "pishirish" har o'zgarish uchun qayta build talab qiladi. ConfigMap konfiguratsiyani image'dan ajratadi.

```bash
kubectl create configmap web-conf --from-file=default.conf --dry-run=client -o yaml > configmap.yaml
```

Pod'ga volume sifatida ulash (nginx `/etc/nginx/conf.d/*.conf` fayllarini o'qiydi):

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        volumeMounts:
        - name: conf
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: conf
        configMap: {name: web-conf}
```

ConfigMap o'zgarganda nima bo'ladi:

- Volume sifatida ulangan fayllar pod ichida bir necha o'n soniya ichida yangilanadi (kubelet sinxronlash davri). Lekin nginx faylni qayta o'qimaydi: jarayonni reload qilish yoki pod'ni qayta yaratish kerak.
- `subPath` bilan ulangan fayl yangilanmaydi.
- Muhit o'zgaruvchisi sifatida olingan qiymat hech qachon yangilanmaydi, faqat yangi pod'da.
- ConfigMap o'zgarishi Deployment rollout'ini boshlamaydi, chunki pod template o'zgarmagan. Amaliy yechimlar: `kubectl rollout restart`, yoki pod template annotation'iga konfiguratsiya hash'ini yozish (Helm va Kustomize shunday qiladi).

**Tuzoq: buzuq konfiguratsiya va ishlab turgan pod'lar.** Noto'g'ri nginx konfiguratsiyasi ConfigMap'ga yozilsa, ishlab turgan pod'lar eski konfiguratsiya bilan ishlayveradi va hammasi joyida ko'rinadi. Xato keyingi restart yoki masshtablashda, eng noqulay paytda chiqadi. Konfiguratsiyani o'zgartirgach darhol rollout qiling.

## 7. Ingress

Service L4 darajada ishlaydi (IP va port). Ingress L7 qoidalarni tasvirlaydi: host va path bo'yicha HTTP trafikni Service'larga yo'naltirish, TLS.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  rules:
  - host: web.example.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: {name: web, port: {number: 80}}
```

Ingress obyektining o'zi hech narsa qilmaydi. Uni o'qib, haqiqiy proxy'ni sozlaydigan ingress controller kerak, va u Kubernetes bilan birga kelmaydi. Bir klasterda bir nechta controller bo'lsa, qaysi biri qaysi Ingress'ni olishini `spec.ingressClassName` va IngressClass obyekti hal qiladi (`kubectl get ingressclass`).

### Ekotizimning hozirgi holati

Buni bilish muhim, chunki internetdagi aksariyat qo'llanmalar eskirgan:

- **ingress-nginx to'xtatilgan.** Kubernetes hamjamiyati yuritgan, eng ko'p tarqalgan controller (`kubernetes/ingress-nginx`) 2026-yil martdan boshlab qo'llab-quvvatlanmaydi: yangi reliz, bugfix va xavfsizlik yangilanishlari yo'q, repozitoriy arxivlangan. Mavjud o'rnatmalar ishlayveradi, lekin yangi klasterga uni o'rnatmang, ishlab turganini esa migratsiya qilish kerak. (F5 yuritadigan `nginx-ingress` boshqa loyiha, uni adashtirmang.)
- **Ingress API muzlatilgan.** `networking.k8s.io/v1` Ingress barqaror va olib tashlanmaydi, lekin unga yangi imkoniyat qo'shilmaydi. Kubernetes loyihasi yangi ishlar uchun Gateway API'ni tavsiya qiladi.
- **Gateway API** Ingress'ning vorisi: rollar bo'yicha ajratilgan obyektlar (GatewayClass, Gateway, HTTPRoute), trafikni vazn bo'yicha bo'lish, header bo'yicha yo'naltirish kabi imkoniyatlar standartda. U Kubernetes'ga ichki o'rnatilmagan, CRD sifatida qo'shiladi. 6-darsda amalda ishlatamiz.
- Ingress'ni qo'llaydigan boshqa controller'lar ko'p: Traefik, HAProxy, Contour, Cilium, cloud provayderlarniki. Ularning ko'pi Gateway API'ni ham qo'llaydi.

Bu darsda Ingress'ni o'rganamiz, chunki u hali juda ko'p klasterda ishlatiladi va tushunchalari Gateway API'ga to'g'ridan-to'g'ri ko'chadi. kind'da alohida controller o'rnatish shart emas: `cloud-provider-kind` Ingress'ni (va Gateway API'ni) o'zi amalga oshiradi va Ingress'ga tashqi IP beradi.

```bash
kubectl get ingress web      # ADDRESS column gets an IP while cloud-provider-kind is running
curl -H 'Host: web.example.test' http://<ADDRESS>/
```

`pathType` qiymatlari: `Prefix` (path segmentlari bo'yicha prefiks), `Exact` (aniq mos kelish), `ImplementationSpecific` (controller'ga bog'liq). Annotation'lar orqali beriladigan sozlamalar (rewrite, timeout) controller'ga xos va boshqasiga ko'chmaydi, bu Ingress API'ning asosiy zaifligi.

## 8. Buzilgan deploy'ni debug qilish

Tartib har doim bir xil: avval `kubectl get pods` (holat), keyin `kubectl describe pod` (event'lar), keyin `kubectl logs` (ilova), oxirida `kubectl get events` (namespace bo'yicha).

| Holat | Ma'nosi | Odatiy sabablar | Qayerga qarash |
|-------|---------|-----------------|----------------|
| `Pending` | scheduler node topa olmadi yoki pod hali tayinlanmagan | resurs yetmaydi, `nodeSelector` yoki taint mos emas, PVC bog'lanmagan | `describe pod`, `FailedScheduling` event'i |
| `ErrImagePull`, `ImagePullBackOff` | image tortib bo'lmadi | tag yoki nom xato, private registry uchun credential yo'q, tarmoq | `describe pod` event'lari |
| `CrashLoopBackOff` | konteyner ishga tushib, qayta-qayta chiqib ketyapti | ilova xatosi, noto'g'ri konfiguratsiya, yetishmagan env, liveness probe o'ldiryapti | `logs --previous`, `Last State` dagi exit code |
| `CreateContainerConfigError` | konteynerni sozlab bo'lmadi | ko'rsatilgan ConfigMap, Secret yoki kalit yo'q | `describe pod` |
| `Running`, lekin `READY 0/1` | konteyner ishlayapti, readiness o'tmayapti | probe yo'li yoki porti xato, ilova hali tayyor emas | `describe pod` dagi probe xatolari |
| `OOMKilled` (`Last State`) | xotira limiti oshdi | limit past yoki memory leak | `describe pod`, exit code 137 |

`BackOff` so'zi holat emas, kutish: kubelet qayta urinishlar orasidagi vaqtni eksponensial oshiradi (konteyner restartida 5 daqiqagacha). `CrashLoopBackOff` da asosiy savol "nima uchun chiqib ketdi", javobi deyarli har doim `logs --previous` da.

Pod'lar umuman yo'q bo'lsa, muammo bir pog'ona yuqorida: `kubectl describe deployment`, `kubectl describe replicaset` va ularning event'lari (masalan, quota oshgan yoki admission rad etgan).

## Tuzoqlar

- `image: nginx` yoki `:latest`: qaysi versiya ishlayotgani noma'lum, rollback imkonsiz, node'lar turli versiyani tortishi mumkin. Har doim aniq tag, production'da digest.
- Klasterni qo'lda o'zgartirish (`edit`, `scale`, `set image`) va faylni yangilamaslik: keyingi `apply` kutilmagan natija beradi.
- `rollout undo` dan keyin git'ni orqaga qaytarmaslik.
- ConfigMap'ni o'zgartirib, rollout qilmaslik: xato keyingi restart'gacha yashirin qoladi.
- `port-forward` ni doimiy kirish usuli sifatida ishlatish.
- ingress-nginx'ni eski qo'llanma bo'yicha yangi klasterga o'rnatish: xavfsizlik yangilanishi yo'q komponent internetga qaragan bo'ladi.
- Ingress yaratib, controller yoki `ingressClassName` ni tekshirmaslik: obyekt bor, `ADDRESS` bo'sh, hech narsa ishlamaydi.
- Debug'ni `logs` dan boshlash. Konteyner hali yaratilmagan bo'lsa log yo'q; avval `describe`.
- `CrashLoopBackOff` da pod'ni o'chirib qayta yaratish: sabab yo'qolmaydi, faqat dalil yo'qoladi.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ – Deployment, rollout, rollback
- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/ – deklarativ boshqaruv, apply mexanizmi
- https://kubernetes.io/docs/reference/using-api/server-side-apply/ – server-side apply
- https://kubernetes.io/docs/concepts/configuration/configmap/ – ConfigMap
- https://kubernetes.io/docs/concepts/services-networking/ingress/ – Ingress
- https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/ – ingress-nginx to'xtatilishi haqida rasmiy e'lon
- https://gateway-api.sigs.k8s.io/ – Gateway API
- https://kind.sigs.k8s.io/docs/user/ingress/ – kind'da Ingress
- https://kubernetes.io/docs/tasks/debug/debug-application/ – ilovani debug qilish

---

## Vazifalar

Barchasini `kubernetes/03-first-deploy/` papkasida bajaring (`make new m=kubernetes n=03 name=first-deploy`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar shu papkadagi `manifests/` ichiga saqlanadi. Hammasi `web` namespace'ida.

### A. Imperativ

1. **Imperative deployment.** `kubectl create deployment`, `expose` va `port-forward` bilan nginx'ni ishga tushirib, `curl` bilan javob oling. Yaratilgan barcha obyektlarni (`kubectl get all`) sanab, har biri qaysi buyruqdan paydo bo'lganini yozing. Keyin hammasini o'chiring.

2. **Generate manifests.** `--dry-run=client -o yaml` bilan Deployment va Service manifestlarini generatsiya qiling. Generatsiya qilingan faylda keraksiz maydonlar bormi (`creationTimestamp: null`, `status: {}`, `resources: {}`)? Ularni tozalang. `--dry-run=client` va `--dry-run=server` farqini noto'g'ri maydon nomi yozilgan manifestda sinab ko'rsating.

### B. Deklarativ

3. **Deployment manifest.** `manifests/deployment.yaml` ni qo'lda yozing: 3 replika, `nginx:1.27`, tavsiya etilgan `app.kubernetes.io/*` label'laridan kamida ikkitasi. `apply` qiling. Keyin template label'ini selector'ga mos kelmaydigan qilib ko'ring va API server xatosini yozing. Mavjud Deployment'da selector'ni o'zgartirib ko'ring: qanday xato chiqdi va nima uchun bunday cheklov bor?

4. **Service and port-forward.** `manifests/service.yaml` yozing va qo'llang. `kubectl port-forward service/web 8080:80` orqali 10 marta `curl` qiling, so'ng `kubectl logs -l app=web --prefix` (yoki har pod uchun alohida) bilan so'rovlar nechta pod'ga tushganini aniqlang. Natijani izohlang. Tunnel ulangan pod'ni o'chirsangiz nima bo'ladi?

5. **kubectl diff.** Faylda replikalar sonini va image tag'ini o'zgartiring. `kubectl diff -f` natijasini va uning exit code'ini (`echo $?`) ko'rsating. Bu exit code CI pipeline'da qanday ishlatilishi mumkin? Keyin `apply` qiling va `diff` endi bo'sh ekanini tekshiring.

6. **Drift.** `kubectl scale deployment web --replicas=5` va `kubectl set image` bilan klasterni qo'lda o'zgartiring, faylga tegmang. `kubectl diff` nimani ko'rsatadi? `apply` dan keyin qaysi qo'lda qilingan o'zgarishlar bekor bo'ldi? Keyin fayldan `replicas` qatorini butunlay olib tashlab `apply` qiling va yana `scale` qiling: endi `apply` replikalar soniga tegadimi? `metadata.managedFields` yoki `last-applied-configuration` annotation'i yordamida izohlang.

### C. Kuzatish

7. **Describe and events.** Bitta pod uchun `kubectl describe pod` natijasidan toping: qaysi node, IP, image digest, konteyner qachon ishga tushgan, QoS class, event'lar ketma-ketligi. `kubectl get events` ni vaqt bo'yicha saralab, Deployment yaratilishidan pod `Started` bo'lgunicha zanjirni ko'rsating.

8. **Logs.** Bir nechta `curl` so'rov yuboring va log'larni uch usulda oling: bitta pod, label bo'yicha barcha pod'lar, `deploy/web` orqali. `--tail`, `--since`, `-f` va `--timestamps` flag'larini sinang. nginx access log nima uchun `kubectl logs` da ko'rinadi (image ichida log fayli qayerga yo'naltirilgan)?

9. **Exec and debug.** `kubectl exec` bilan pod ichida `nginx -T` ni bajaring va joriy konfiguratsiyani ko'ring. Vaqtinchalik pod (`kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh`) ichidan `wget -qO- http://web` bilan Service'ga nom orqali murojaat qiling. `exec` orqali `index.html` ni o'zgartiring va pod'ni o'chiring: o'zgarish qayerga ketdi? Xulosa yozing.

### D. Rollout

10. **Rolling update.** Bitta terminalda `kubectl get rs -w`, ikkinchisida `kubectl get pods -w` qoldiring. Faylda image'ni `nginx:1.28` ga o'zgartirib `apply` qiling. ReplicaSet'lar soni qanday o'zgardi? Bir vaqtda eng ko'pi va eng kami nechta pod bor edi? Eski ReplicaSet nima uchun o'chirilmadi? `kubernetes.io/change-cause` annotation'ini qo'shib, `rollout history` da ko'rinishini tekshiring.

11. **Failed rollout.** Image tag'ini mavjud bo'lmagan qiymatga (`nginx:9.99`) o'zgartirib `apply` qiling. `kubectl rollout status --timeout=60s` nima qaytardi (exit code bilan)? Pod'lar qaysi holatda? Shu paytda `port-forward` orqali sayt ishlayaptimi va nima uchun? `describe pod` dan aniq xato matnini yozing.

12. **Rollback.** 11-vazifadagi holatdan `rollout undo` bilan chiqing. `rollout history` da reviziya raqamlari qanday o'zgardi? Aniq reviziyaga (`--to-revision`) qaytishni ham sinang. Endi `kubectl diff -f` nimani ko'rsatadi va bu nimadan ogohlantiradi? To'g'ri rollback tartibini (git bilan) yozing.

### E. ConfigMap

13. **nginx config from ConfigMap.** `default.conf` yozing: `/healthz` yo'li `200` va `ok` matnini qaytarsin, barcha javoblarga `X-Served-By` header'i `$hostname` qiymati bilan qo'shilsin. Undan ConfigMap manifestini yarating va Deployment'ga volume sifatida ulang. `curl -i` bilan header va `/healthz` ni tekshiring. Header qiymati nimaga teng va nima uchun?

14. **Config update.** ConfigMap'dagi `/healthz` javob matnini o'zgartirib `apply` qiling. Pod ichidagi fayl qachon yangilandi (`kubectl exec ... cat` bilan kuzating)? nginx yangi matnni qaytaryaptimi? Nima uchun? Muammoni `rollout restart` bilan hal qiling. ConfigMap o'zgarishi avtomatik rollout boshlashi uchun qanday yondashuvlar borligini yozing.

15. **Broken config.** ConfigMap'ga sintaktik xato nginx konfiguratsiyasi yozing va `apply` qiling. Ishlab turgan pod'larga nima bo'ldi? Endi `rollout restart` qiling: yangi pod'lar qaysi holatda, eski pod'lar-chi? `kubectl logs` va `logs --previous` dan nginx xatosini toping. Bu vaziyat production'da nima uchun xavfli ekanini va qanday oldini olishni yozing. Konfiguratsiyani tuzating.

### F. Ingress

16. **Ingress routing.** `cloud-provider-kind` ni ishga tushiring. Ikkinchi Deployment va Service yarating (`api`, boshqa `index.html` yoki boshqa image). Bitta Ingress yozing: `web.example.test` host'i `web` ga, `api.example.test` host'i `api` ga borsin. `kubectl get ingress` da `ADDRESS` paydo bo'lishini kuting va `curl -H 'Host: ...'` bilan ikkala yo'nalishni tekshiring. Noma'lum host bilan so'rov nima qaytaradi? `docker ps` da qanday yangi konteyner paydo bo'ldi?

17. **Path routing.** Ingress'ni o'zgartiring: bitta host, `/` yo'li `web` ga, `/api` yo'li `api` ga. `pathType: Prefix` va `Exact` farqini `/api`, `/api/`, `/api/v1`, `/apiv2` so'rovlari bilan sinab, natijani jadvalda ko'rsating. Backend `/api/v1` yo'lini qanday ko'ryapti (uning access log'idan) va bu qanday muammo tug'dirishi mumkin?

18. **Ingress ecosystem status.** Rasmiy manbalarni o'qing: ingress-nginx to'xtatilishi haqidagi e'lon va Ingress hujjatining boshidagi eslatma. O'z so'zingiz bilan yozing: nima to'xtatildi va nima to'xtatilmadi (controller va API farqi), mavjud o'rnatmalarga nima bo'ladi, yangi klaster uchun siz nimani tanlagan bo'lardingiz va nima uchun. `kubectl get ingressclass` sizning klasteringizda nimani ko'rsatadi?

### G. Debug

19. **Pending pod.** Konteynerga `resources.requests.cpu: "100"` (100 yadro) bilan alohida Deployment yarating. Pod holati va `describe pod` dagi event matnini yozing. Xabardagi har qismni izohlang (nechta node tekshirildi, har biri nima uchun mos kelmadi). Tuzating.

20. **Config error.** Deployment'da mavjud bo'lmagan ConfigMap'ga volume orqali va boshqa variantda `env.valueFrom.configMapKeyRef` orqali murojaat qiling. Ikki holatda pod holati bir xilmi? Har birining event'ini yozing. 8-bo'limdagi jadvaldan foydalanib, to'rtta holatni (`Pending`, `ImagePullBackOff`, `CrashLoopBackOff`, `CreateContainerConfigError`) shu darsda ko'rgan misollaringiz bilan to'ldirilgan o'z jadvalingizni tuzing: alomat, qaysi buyruq sababni ko'rsatdi.

### H. Yakuniy

21. **Static site.** Alohida `site` namespace'ida to'liq deklarativ loyiha yig'ing, hammasi `manifests/site/` papkasida va bitta `kubectl apply -f manifests/site/` bilan ko'tarilsin: Namespace, ConfigMap (`index.html` va nginx konfiguratsiyasi), Deployment (3 replika, aniq tag), Service, Ingress. Tekshiring: Ingress orqali sahifa ochiladi; `index.html` ni o'zgartirib yangi versiyani chiqaring va chiqarish paytida `while true; do curl ...; sleep 0.2; done` sikli bitta ham xato ko'rmasligini ko'rsating; buzuq image bilan rollout qilib, foydalanuvchi buni sezmasligini va qanday qaytarganingizni yozing. Oxirida namespace'ni o'chiring.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar `manifests/` da.
2. `make check` toza o'tadi (`yamllint`).
3. `kubectl apply --dry-run=server -f manifests/site/` xatosiz.
4. `web` va `site` namespace'lari o'chirilgan, `cloud-provider-kind` to'xtatilgan.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `kubectl apply` farqni qanday hisoblaydi va fayldan olib tashlangan maydon bilan nima bo'ladi?
- Rollout paytida ReplicaSet'lar bilan nima sodir bo'ladi va rollback nimaga tayanadi?
- Yangi versiya ishga tushmasa, eski pod'lar nima uchun xizmat ko'rsatishda davom etadi?
- ConfigMap o'zgarganda pod'ga nima yetib boradi, nima yetib bormaydi?
- Ingress obyekti va ingress controller farqi nima?
- ingress-nginx bilan nima bo'ldi, Ingress API bilan nima bo'ldi, Gateway API bu yerda qanday o'rin tutadi?
- `ImagePullBackOff`, `CrashLoopBackOff` va `Pending` holatlarida birinchi qaysi buyruqni ishlatasiz va nimani qidirasiz?
- `port-forward` nima uchun production kirish usuli emas?
- `rollout undo` dan keyin nima uchun git'ni ham orqaga qaytarish kerak?
