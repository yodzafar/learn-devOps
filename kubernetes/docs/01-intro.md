# 1-dars: Kubernetes'ga kirish

Maqsad: Kubernetes nima uchun kerakligini, klaster qanday qismlardan tuzilganini va uning asosiy g'oyasi bo'lgan deklarativ model hamda reconciliation loop qanday ishlashini tushunish. Docker modulida Swarm va bitta kind vazifasi orqali orkestratsiya bilan tanishgansiz; bu darsda o'sha tanishuv tizimli bilimga aylanadi: har komponent nima qiladi, obyekt YAML'i qanday o'qiladi, `kubectl`, kubeconfig, namespace va label'lar bilan qanday ishlanadi. Keyingi barcha darslar shu poydevorga tayanadi: 2-darsda klasterni o'zingiz qurasiz, 3-darsda birinchi ilovani deploy qilasiz.

Taxminiy vaqt: 3 kun (siz uchun). Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: so'rov `kubectl` dan konteynergacha qaysi komponentlardan o'tadi, `spec` va `status` farqi, controller nima uchun "voqea"ga emas, "holat"ga qaraydi, label selector obyektlarni qanday bog'laydi.

## Laboratoriya

Ish mashinasida Docker ustida kind klasteri. kind har Kubernetes node'ini Docker konteyneri sifatida ishga tushiradi, shuning uchun tizimga hech narsa o'rnatilmaydi (ikki binary'dan tashqari) va klaster bitta buyruq bilan o'chiriladi.

`kubectl` (rasmiy yo'riqnoma: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/):

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
chmod +x kubectl && mkdir -p ~/.local/bin && mv ./kubectl ~/.local/bin/kubectl
kubectl version --client
```

`kind` (rasmiy yo'riqnoma: https://kind.sigs.k8s.io/docs/user/quick-start/#installation). Joriy versiya raqamini shu sahifadan oling, quyidagi `v0.33.0` dars yozilgan paytdagi misol:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
chmod +x ./kind && mv ./kind ~/.local/bin/kind
kind create cluster --name dev
kubectl cluster-info --context kind-dev
```

`~/.local/bin` `PATH` da bo'lmasa, uni `~/.zshrc` yoki `~/.bashrc` ga qo'shing. Tozalash: `kind delete cluster --name dev`. kind kubeconfig'ni `~/.kube/config` ga yozadi, bu fayl hech qachon commit qilinmaydi.

---

## 1. Kubernetes nima uchun kerak

Docker bitta host'da konteyner ishga tushiradi. Compose bir nechta konteynerni bitta host'da tasvirlaydi. Production'da esa boshqa savollar paydo bo'ladi:

| Muammo | Bitta host + Compose | Kubernetes |
|--------|----------------------|------------|
| Host o'ldi | ilova to'xtaydi | pod'lar boshqa node'da qayta yaratiladi |
| Konteyner osilib qoldi | `restart` faqat jarayon chiqsa ishlaydi | liveness probe qayta ishga tushiradi |
| Yuklama oshdi | qo'lda yangi host va balanser | `replicas` soni, autoscaling |
| Yangi versiya | to'xtat, yangila, ishga tushir | rolling update, rollback |
| Konteynerlar bir-birini topishi | Compose tarmog'i, bitta host | Service va klaster DNS, barcha node'larda |
| Konfiguratsiya va secret | `.env` fayllar | ConfigMap, Secret obyektlari |
| Kim nima qila oladi | host'ga SSH | API darajasida RBAC |

Kubernetes bu "mashinalar to'plamini bitta kompyuterdek boshqarish" tizimi: siz kerakli holatni API'ga yozasiz, tizim uni node'lar ustida amalga oshiradi va ushlab turadi. Swarm ham shu g'oyada qurilgan, lekin Kubernetes kengaytiriladigan API (CRD, operator), katta ekotizim va barcha cloud'larda managed xizmat borligi sababli de-fakto standartga aylangan.

Narxi ham bor: Kubernetes murakkab. Bitta VM'da turgan bitta ilova uchun u ortiqcha; tanlov har doim "muammo bormi" degan savoldan boshlanadi.

## 2. Arxitektura

Klaster ikki qismdan iborat: control plane (qaror qabul qiladi) va node'lar (konteynerlarni ishlatadi).

### Control plane

| Komponent | Vazifasi |
|-----------|----------|
| `kube-apiserver` | Klasterning yagona kirish nuqtasi. REST API, autentifikatsiya, avtorizatsiya, admission, validatsiya. etcd bilan faqat u gaplashadi |
| `etcd` | Barcha obyektlar saqlanadigan distributed key-value store (Raft konsensus). Klaster holati shu yerda, etcd yo'qolsa klaster yo'qoladi |
| `kube-scheduler` | `nodeName` bo'sh pod'larni kuzatadi va har biriga node tanlaydi (filter, keyin score). O'zi hech narsa ishga tushirmaydi, faqat pod'ga node nomini yozadi |
| `kube-controller-manager` | O'nlab controller bitta jarayonda: Deployment, ReplicaSet, Job, Node, EndpointSlice va boshqalar. Har biri o'z obyektlarini kuzatib, holatni keraklisiga keltiradi |
| `cloud-controller-manager` | Cloud API bilan bog'liq controller'lar (LoadBalancer, node'lar, route'lar). Lokal klasterda bo'lmasligi mumkin |

### Node komponentlari

| Komponent | Vazifasi |
|-----------|----------|
| `kubelet` | Har node'dagi agent. API server'dan o'z node'iga tayinlangan pod'larni oladi, container runtime orqali ishga tushiradi, probe'larni bajaradi, holatni API'ga yozadi |
| container runtime | Konteynerni haqiqatda ishlatadigan dastur (`containerd`, CRI-O). kubelet u bilan CRI (Container Runtime Interface) orqali gaplashadi |
| `kube-proxy` | Service'larning virtual IP'larini node'da tarmoq qoidalariga (iptables yoki nftables) aylantiradi. 6-darsda chuqur |

Qo'shimcha (addon) sifatida deyarli har klasterda: CNI plugin (pod tarmog'i) va CoreDNS (klaster DNS).

**Tuzoq: Kubernetes Docker'ni ishlatmaydi.** kubelet'dagi Docker Engine adapteri (dockershim) 1.24 versiyada olib tashlangan. Node'larda odatda `containerd` turadi. Docker bilan build qilingan image'lar OCI formatda bo'lgani uchun o'zgarishsiz ishlayveradi, lekin node ichida `docker ps` emas, `crictl ps` ishlatiladi.

### So'rov yo'li

`kubectl create deployment web --image=nginx --replicas=2` buyrug'idan keyin:

1. `kubectl` kubeconfig'dan server manzili va credential'ni olib, API server'ga HTTPS `POST` yuboradi.
2. API server so'rovni autentifikatsiya, avtorizatsiya va admission'dan o'tkazib, Deployment obyektini etcd'ga yozadi. Shu bilan `kubectl` ishi tugaydi.
3. Deployment controller yangi obyektni ko'radi va ReplicaSet yaratadi.
4. ReplicaSet controller 2 ta Pod obyekti yaratadi (`nodeName` bo'sh).
5. Scheduler har pod'ga node tanlab, `nodeName` ni yozadi.
6. O'sha node'dagi kubelet pod'ni ko'radi, runtime orqali image'ni tortib konteynerni ishga tushiradi va `status` ni yangilaydi.

Komponentlar bir-biriga to'g'ridan-to'g'ri buyruq bermaydi. Hammasi API server'dagi obyektlarni kuzatadi (`watch`) va o'z qismini bajaradi. Shu sabab bitta komponent vaqtincha o'chsa, qolganlari ishlashda davom etadi va u qaytgach ish davom ettiriladi.

## 3. Deklarativ model va reconciliation loop

Imperativ yondashuv: "3 ta konteyner ishga tushir". Deklarativ: "3 ta replika bo'lishi kerak". Farq nosozlikda ko'rinadi: imperativ buyruq bir marta bajariladi, deklarativ holat esa doimiy ushlab turiladi.

Har obyektda ikki qism bor:

- `spec`: kerakli holat (desired state). Siz yozasiz.
- `status`: joriy holat (actual state). Controller'lar va kubelet yozadi.

Controller cheksiz siklda ishlaydi: kuzat (`status` ni o'qi), solishtir (`spec` bilan), harakat qil (farqni yo'qot). Bu reconciliation loop deyiladi.

Muhim xususiyat: controller'lar level-triggered, ya'ni "nima sodir bo'ldi" degan voqeaga emas, "hozir holat qanday" degan faktga qaraydi. Controller bir soat o'chib tursa va shu vaqtda 5 ta pod o'lsa, u qaytgach voqealarni "o'tkazib yuborgani" muhim emas: hozir 3 ta o'rniga 1 ta borligini ko'radi va 2 ta yaratadi. Shu sabab tizim o'zini tiklaydi (self-healing).

Amaliy oqibatlari:

- Obyektni qo'lda o'zgartirsangiz (masalan Deployment pod'ini o'chirsangiz), controller uni qaytaradi. "Tuzatish" har doim `spec` orqali qilinadi.
- `kubectl apply` muvaffaqiyatli qaytishi ilova ishlayotganini anglatmaydi, faqat kerakli holat qabul qilinganini bildiradi. Natijani `status` va event'lardan ko'rasiz.

## 4. Obyektlar va YAML anatomiyasi

```yaml
apiVersion: apps/v1          # API group and version
kind: Deployment             # object type
metadata:
  name: web
  namespace: default
  labels: {app: web}
spec:                        # desired state, depends on kind
  replicas: 2
status: {}                   # written by the system, never by you
```

| Maydon | Ma'nosi |
|--------|---------|
| `apiVersion` | `group/version`. Core group'da faqat versiya: `v1` (Pod, Service, ConfigMap). Boshqalarda group bor: `apps/v1`, `batch/v1`, `networking.k8s.io/v1` |
| `kind` | Obyekt turi. `apiVersion` + `kind` birga sxemani aniqlaydi |
| `metadata` | `name` (namespace ichida, shu tur uchun unikal), `namespace`, `labels`, `annotations`, tizim to'ldiradigan `uid`, `resourceVersion`, `generation`, `creationTimestamp`, `ownerReferences`, `finalizers` |
| `spec` | Kerakli holat. Tarkibi `kind` ga bog'liq |
| `status` | Joriy holat. Qo'lda yozilgan qiymat e'tiborga olinmaydi |

- `resourceVersion` har o'zgarishda yangilanadi va optimistic locking uchun ishlatiladi: eskirgan nusxa ustidan yozish `Conflict` xatosini beradi.
- `ownerReferences` obyektning egasini ko'rsatadi (Pod egasi ReplicaSet, uning egasi Deployment). Ega o'chirilsa, garbage collector bolalarini ham o'chiradi.
- API versiyalari eskiradi: `v1beta1` kabi versiyalar keyingi relizlarda olib tashlanadi. Internetdagi eski manifestdagi `apiVersion` hozirgi klasterda bo'lmasligi mumkin. Tekshirish: `kubectl api-resources` va `kubectl explain`.

Sxemani hujjatsiz o'qish:

```bash
kubectl api-resources                      # all kinds, short names, namespaced or not
kubectl explain deployment.spec.strategy   # field documentation from the API server
kubectl explain pod.spec --recursive | less
```

## 5. kubectl asoslari

Buyruq shakli: `kubectl <verb> <resource> [name] [flags]`.

| Buyruq | Nima qiladi |
|--------|-------------|
| `kubectl get pods -o wide` | ro'yxat, qo'shimcha ustunlar (IP, node) |
| `kubectl get deploy web -o yaml` | obyektning to'liq holati, `status` bilan |
| `kubectl get pods -w` | o'zgarishlarni kuzatish (`watch`) |
| `kubectl get pods -A` | barcha namespace'lar |
| `kubectl describe pod NAME` | inson o'qiydigan xulosa va event'lar |
| `kubectl apply -f file.yaml` | deklarativ: yarat yoki farqini qo'lla |
| `kubectl delete -f file.yaml` | fayldagi obyektlarni o'chirish |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | so'nggi voqealar |

Chiqish formatlari: `-o yaml`, `-o json`, `-o name`, `-o jsonpath='{.items[*].metadata.name}'`, `-o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName`. Skriptlarda jadval ko'rinishini `grep` qilmang, `jsonpath` ishlating: ustunlar versiyadan versiyaga o'zgaradi.

`kubectl` shunchaki HTTP klient. `-v=6` flag'i qaysi URL'ga qanday so'rov ketganini ko'rsatadi, `kubectl get --raw /version` esa API'ni to'g'ridan-to'g'ri chaqiradi.

Imperativ buyruqlar (`kubectl create`, `run`, `scale`, `edit`) o'rganish va tezkor tekshiruv uchun qulay. Production'da holat fayllarda turadi va `apply` bilan qo'llanadi, chunki fayl review qilinadi, git'da saqlanadi va qayta qo'llash mumkin (3-dars, keyin 10-darsda GitOps).

## 6. kubeconfig va context

`kubectl` qaysi klasterga, kim sifatida ulanishini kubeconfig faylidan biladi. Standart joyi `~/.kube/config`, `KUBECONFIG` muhit o'zgaruvchisi yoki `--kubeconfig` flag'i bilan o'zgartiriladi. Uch ro'yxatdan iborat:

| Bo'lim | Tarkibi |
|--------|---------|
| `clusters` | API server manzili va CA sertifikati |
| `users` | credential: klient sertifikati, token yoki tashqi buyruq (`exec`) |
| `contexts` | uchlik: cluster + user + standart namespace |

`current-context` hozir faol context'ni ko'rsatadi.

```bash
kubectl config get-contexts
kubectl config use-context kind-dev
kubectl config set-context --current --namespace=team-a
kubectl config view --minify        # only the current context, secrets redacted
kubectl --context kind-dev get nodes   # one-off, without switching
```

**Tuzoq: noto'g'ri context.** Eng qimmat xatolardan biri `kubectl delete` ni production context'ida bajarish. Skriptlarda har doim `--context` ni aniq yozing, terminal prompt'ida joriy context'ni ko'rsatib qo'ying.

kubeconfig ichida klaster admin credential'i bor. U parol bilan teng: git'ga, chatga, CI log'iga tushmasligi kerak.

## 7. Namespace

Namespace bitta klaster ichida obyekt nomlarini ajratadigan mantiqiy bo'lim: jamoa, muhit yoki ilova bo'yicha. Yangi klasterda: `default`, `kube-system` (tizim komponentlari), `kube-public`, `kube-node-lease` (node heartbeat obyektlari).

- Ko'pchilik obyektlar namespaced (Pod, Deployment, Service, ConfigMap, Secret). Ba'zilari cluster-scoped: Node, Namespace, PersistentVolume, StorageClass, ClusterRole. Farqni `kubectl api-resources --namespaced=false` ko'rsatadi.
- Namespace'ga ResourceQuota, LimitRange, RBAC va NetworkPolicy bog'lanadi (13-dars).
- Namespace o'chirilsa, ichidagi barcha obyektlar o'chadi.

**Tuzoq: namespace xavfsizlik chegarasi emas.** Standart holatda bir namespace'dagi pod boshqa namespace'dagi pod'ga tarmoq orqali bemalol ulanadi. Izolyatsiya NetworkPolicy va RBAC bilan alohida quriladi.

## 8. Label, selector va annotation

Label bu obyektga yopishtirilgan `kalit: qiymat` juftligi. Kubernetes'da obyektlar bir-biriga nom orqali emas, label selector orqali bog'lanadi: ReplicaSet o'z pod'larini, Service o'z backend'larini selector bilan topadi. Bu bog'lanish "bo'sh" (loosely coupled): pod label'ini o'zgartirsangiz, u egasidan uzilib qoladi.

```bash
kubectl get pods -l app=web,tier!=cache        # equality-based
kubectl get pods -l 'env in (dev,stage)'       # set-based
kubectl get pods --show-labels
kubectl label pod web-abc env=dev --overwrite  # add or change
kubectl label pod web-abc env-                 # remove
```

Manifestlarda selector ikki shaklda uchraydi: `matchLabels` (aniq tenglik) va `matchExpressions` (`In`, `NotIn`, `Exists`, `DoesNotExist`).

Tavsiya etilgan umumiy label'lar: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`. Ular asboblar (Helm, dashboard'lar) o'rtasida umumiy til.

Annotation ham `kalit: qiymat`, lekin tanlash uchun emas, ma'lumot biriktirish uchun: asboblar konfiguratsiyasi, build ma'lumoti, tavsif. Annotation bo'yicha selector yo'q, qiymati esa label'nikidan ancha uzun bo'lishi mumkin.

## Tuzoqlar

- `kubectl apply` muvaffaqiyatli qaytdi degani ilova ishladi degani emas. Har doim `status`, `kubectl get pods` va event'larni tekshiring.
- Noto'g'ri context yoki namespace'da buyruq bajarish. O'chirish buyruqlaridan oldin `kubectl config current-context` ni ko'ring.
- Deployment pod'ini qo'lda "tuzatish" (`kubectl exec` bilan fayl o'zgartirish, pod'ni `edit` qilish). Controller keyingi qayta yaratishda hammasini yo'qotadi.
- Label'ni o'ylamasdan o'zgartirish: pod Service va ReplicaSet'dan uzilib, trafik olmaydigan "yetim"ga aylanadi.
- Namespace'ni izolyatsiya deb o'ylash. Tarmoq va huquqlar alohida sozlanmaguncha ochiq.
- Internetdan olingan eski manifestlardagi olib tashlangan `apiVersion` lar (`extensions/v1beta1` va shunga o'xshash).
- kubeconfig'ni commit qilish yoki boshqalarga yuborish. Bu klaster admin kaliti.
- etcd'ni zaxirasiz qoldirish: klasterning butun holati shu yerda (11-darsda qaytamiz).

## Manbalar

- https://kubernetes.io/docs/concepts/overview/ – Kubernetes nima va nima emas
- https://kubernetes.io/docs/concepts/architecture/ – klaster arxitekturasi va komponentlar
- https://kubernetes.io/docs/concepts/architecture/controller/ – controller va reconciliation
- https://kubernetes.io/docs/concepts/overview/working-with-objects/ – obyektlar, nomlar, namespace, label, annotation
- https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/ – kubeconfig
- https://kubernetes.io/docs/reference/kubectl/quick-reference/ – kubectl qisqa ma'lumotnoma
- https://kind.sigs.k8s.io/docs/user/quick-start/ – kind
- Lukša, "Kubernetes in Action" (2-nashr), 1–3 boblar

---

## Vazifalar

Barchasini `kubernetes/01-intro/` papkasida bajaring (`make new m=kubernetes n=01 name=intro` bilan yarating). Javoblar shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yoziladi: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (YAML, skript) shu papkaga saqlanadi.

### A. Klaster va komponentlar

1. **Install tools.** `kubectl` va `kind` ni o'rnating. `kubectl version --client` va `kind version` natijasini yozing. `kubectl` uchun shell completion'ni yoqing (`kubectl completion`). Checksum tekshiruvi nima uchun kerakligini bir gapda izohlang.

2. **Create a cluster.** `kind create cluster --name dev` bilan klaster yarating. `docker ps` da nima paydo bo'ldi? `kubectl get nodes -o wide` natijasidagi har ustunni izohlang. Node qaysi container runtime'ni ishlatyapti?

3. **Control plane pods.** `kubectl get pods -n kube-system -o wide` natijasidagi har pod'ni 2-bo'limdagi jadval bilan moslang: qaysi biri control plane, qaysi biri node komponenti, qaysi biri addon. Ro'yxatda `kubelet` nima uchun yo'qligini tushuntiring.

4. **Static pods.** `docker exec dev-control-plane ls /etc/kubernetes/manifests` ni bajaring. Bu fayllar nima va ularni kim o'qiydi? API server hali ishga tushmagan paytda API server pod'ini kim ishga tushiradi, degan "tovuq va tuxum" muammosi qanday yechilganini izohlang.

5. **Container runtime.** `docker exec dev-control-plane crictl ps` va `crictl pods` ni bajaring. Natijani `kubectl get pods -A` bilan solishtiring. Node ichida `docker` buyrug'i bormi? Nima uchun yo'q?

### B. API va obyektlar

6. **API resources.** `kubectl api-resources` dan foydalanib toping: Deployment, CronJob va Ingress qaysi API group'da, qisqa nomlari nima, qaysi obyektlar namespaced emas (kamida 5 ta misol). `kubectl api-versions` nimani ko'rsatadi?

7. **kubectl explain.** Hujjat saytiga kirmasdan, faqat `kubectl explain` bilan aniqlang: Pod'ning `restartPolicy` maydoni qanday qiymatlarni qabul qiladi, Deployment'da `revisionHistoryLimit` ning standart qiymati nechchi, konteynerda `imagePullPolicy` qanday tanlanadi.

8. **Object anatomy.** `kubectl run probe --image=nginx:1.28` bilan pod yarating va `kubectl get pod probe -o yaml` ni oling. Siz bermagan, tizim qo'shgan maydonlarni toping (kamida 8 ta) va har biri qayerdan kelganini izohlang: API server default'i, scheduler, kubelet. `spec` va `status` chegarasini ko'rsating.

9. **Raw API.** `kubectl get pods -v=6` qaysi URL'ga so'rov yuborganini yozing. Xuddi shu ro'yxatni `kubectl get --raw` bilan oling. `kubectl get pod probe -o yaml` dagi `resourceVersion` ni yozib oling, pod'ga label qo'shing va qayta qarang. Nima o'zgardi va bu maydon nima uchun kerak?

### C. Reconciliation

10. **Self-healing.** `kubectl create deployment web --image=nginx:1.28 --replicas=3` yarating. Bitta terminalda `kubectl get pods -w` qoldirib, boshqasida bitta pod'ni o'chiring. Nima bo'ldi? Yangi pod'ning nomi va IP'si eskisi bilan bir xilmi? Qaysi controller buni qildi va u buni qayerdan bildi?

11. **Ownership chain.** `web` Deployment'i uchun Deployment, ReplicaSet va Pod'larning `metadata.ownerReferences` ni ko'rib, egalik zanjirini chizing. Keyin 8-vazifadagi `probe` pod'ini o'chiring. U qayta yaratildimi? Farq nimada?

12. **Scheduler down.** `docker exec dev-control-plane mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/` bilan scheduler'ni to'xtating. Scheduler pod'i yo'qolganini tekshiring, so'ng `kubectl scale deployment web --replicas=5` qiling. Yangi pod'lar qaysi holatda va nima uchun? Mavjud pod'lar ishlayaptimi? Faylni joyiga qaytaring va nima bo'lishini kuzating. Bu tajriba "level-triggered" tushunchasini qanday ko'rsatadi?

13. **Spec vs status.** `kubectl get deployment web -o yaml` da `spec.replicas`, `status.replicas`, `status.readyReplicas`, `metadata.generation` va `status.observedGeneration` ni toping. `kubectl scale` dan darhol keyin va bir necha soniyadan so'ng bu qiymatlar qanday o'zgarishini yozing. `observedGeneration` nimani bildiradi?

### D. kubeconfig va namespace

14. **kubeconfig anatomy.** `kubectl config view` natijasida `clusters`, `users`, `contexts` bo'limlarini ko'rsating (maxfiy qiymatlarni README'ga yozmang). kind foydalanuvchini qanday autentifikatsiya qilyapti: token, sertifikat yoki boshqa usul? API server manzili qaysi port va u Docker'da qanday e'lon qilingan?

15. **Two clusters.** Ikkinchi klaster yarating: `kind create cluster --name lab`. `kubectl config get-contexts` natijasini ko'rsating. Context'ni almashtirmasdan (`--context` bilan) ikkala klasterdagi node'larni chiqaring. Keyin `use-context` bilan almashtiring. Oxirida `lab` klasterini o'chiring va kubeconfig'dan nima yo'qolganini tekshiring.

16. **Namespaces.** `team-a` namespace'ini yarating va ichida `web` nomli Deployment yarating (`default` da ham shu nomli bor). Nima uchun nom to'qnashuvi yo'q? Joriy context'ning standart namespace'ini `team-a` ga o'zgartiring, `kubectl get pods` nimani ko'rsatishini tekshiring va qaytarib qo'ying. Namespace'ni o'chirganda ichidagi obyektlar bilan nima bo'ldi?

### E. Label va selector

17. **Labels and selectors.** `default` dagi pod'larga turli label'lar qo'ying (`env=dev`, `env=prod`, `tier=frontend`). Uchta so'rov yozing: tenglik bo'yicha, `in` operatori bilan, va label mavjud emasligi bo'yicha. `-L` va `--show-labels` flag'lari farqini ko'rsating.

18. **Break the selector.** `web` Deployment pod'laridan birining `app` label qiymatini `kubectl label --overwrite` bilan o'zgartiring. Pod'lar soni nechta bo'ldi? O'zgartirilgan pod'ning `ownerReferences` iga nima bo'ldi? Bu usul production'da nosoz pod'ni trafikdan chiqarib, debug uchun saqlab qolishda qanday ishlatilishini izohlang. "Yetim" pod'ni o'chiring.

19. **Labels vs annotations.** Bitta pod'ga annotation qo'shing (`kubectl annotate`) va annotation bo'yicha `-l` bilan qidirib ko'ring. Natijani izohlang. Uchta ma'lumot uchun qaysi biri mos: jamoa nomi, git commit SHA, 2 KB hajmli JSON konfiguratsiya? Sababini yozing.

### F. Yakuniy

20. **Request trace.** `kubectl create deployment trace --image=nginx:1.28 --replicas=2` ni bajaring va `kubectl get events --sort-by=.metadata.creationTimestamp` natijasidan foydalanib, buyruqdan konteyner ishga tushgunicha bo'lgan zanjirni README'da qadam-baqadam yozing: har event'ni qaysi komponent yaratgan (`SOURCE` yoki `REPORTING` ustuni), 2-bo'limdagi 6 qadamning qaysi biriga to'g'ri keladi. Oxirida matnli diagramma chizing: komponentlar va ular orasidagi o'qlar.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 20 vazifa `## N. Title` sarlavhasi bilan yozilgan.
2. `make check` toza o'tadi.
3. Papkada kubeconfig yoki boshqa maxfiy ma'lumot yo'q.
4. Ortiqcha klasterlar o'chirilgan (`kind get clusters` faqat `dev` ni ko'rsatadi yoki bo'sh).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `kubectl apply` dan konteyner ishga tushgunicha qaysi komponentlar qaysi tartibda ishlaydi?
- etcd bilan qaysi komponent gaplashadi va bu cheklov nima uchun foydali?
- Scheduler o'chib qolsa ishlab turgan ilovalarga nima bo'ladi? kubelet o'chsa-chi?
- `spec` va `status` farqi nima, har birini kim yozadi?
- "Level-triggered" controller "edge-triggered" dan nimasi bilan ishonchliroq?
- Service o'z pod'larini qanday topadi va bu bog'lanish nima uchun nom orqali emas?
- Context nimalardan tashkil topgan?
- Namespace nimani ajratadi va nimani ajratmaydi?
- Label va annotation qachon ishlatiladi?
