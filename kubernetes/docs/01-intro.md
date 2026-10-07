# 1-dars: Kubernetes'ga kirish

Maqsad: Kubernetes nima uchun kerakligini, klaster qanday qismlardan tuzilganini va uning markaziy g'oyasi bo'lgan deklarativ model hamda reconciliation loop qanday ishlashini noldan tushunish. Docker modulining 5-darsida Swarm bilan orkestratsiyani qo'lda ko'rdingiz va bitta kind vazifasida Kubernetes'ga "tegib" chiqdingiz. Bu darsda o'sha tanishuv tizimli bilimga aylanadi: har komponent nima qiladi va qaysi jarayon sifatida ishlaydi, obyekt YAML'i qanday o'qiladi, `kubectl` aslida nima yuboradi, kubeconfig, context, namespace va label'lar bilan qanday ishlanadi. Keyingi barcha darslar shu poydevorga tayanadi: 2-darsda klasterni turli usullar bilan o'zingiz yig'asiz, 3-darsda birinchi ilovani deploy qilasiz.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh, ikkinchi kun 4–5 bo'limlar, B va C guruhlar, uchinchi kun 6–8 bo'limlar, "Birga bajaramiz", D, E, F guruhlar va README. Buyruqlarni yodlashga emas, mexanizmga e'tibor bering: so'rov `kubectl` dan konteynergacha qaysi komponentlardan o'tadi, `spec` va `status` farqi, controller nima uchun "voqea"ga emas, "holat"ga qaraydi, label selector obyektlarni qanday bog'laydi.

Qanday o'qish kerak: har bo'limdagi misolni o'z klasteringizda ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Pod nomlaridagi tasodifiy qo'shimchalar (`hello-6c8b9d7f5b-4kzq2`), IP'lar, port raqamlari, `AGE` va versiyalar sizda boshqacha bo'ladi; bunday joylar ba'zan `<...>` bilan belgilangan. Ustunlar tarkibi `kubectl` versiyasiga qarab biroz o'zgarishi mumkin, ma'nosi bir xil. Misollar uchun `httpd:2.4-alpine` image'i ishlatiladi (Apache veb-server, kichik), vazifalar esa `nginx:1.28` bilan: shunday qilib misol va vazifa aralashmaydi.

## Laboratoriya

Bu darsda hamma narsa host'dagi Docker ustida, kind klasterida bajariladi. kind (Kubernetes IN Docker) har Kubernetes node'ini bitta Docker konteyneri sifatida ishga tushiradi: konteyner ichida haqiqiy Linux jarayonlari (systemd, containerd, kubelet) ishlaydi. Tizimga ikki binary'dan boshqa hech narsa o'rnatilmaydi, klaster bitta buyruq bilan o'chiriladi. `lab` VM bu darsda ishlatilmaydi (unga ajratilgan 2 GB xotira klaster uchun kichik); Multipass VM'lar 2-darsdan, haqiqiy node kerak bo'lganda (k3s, kubeadm) paydo bo'ladi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `kubectl` | rasmiy binary, `linux/amd64`, `~/.local/bin` ga | `brew install kubectl` (`arm64`) |
| `kind` | rasmiy binary, `kind-linux-amd64`, `~/.local/bin` ga | `brew install kind` (`arm64`) |
| Node konteynerlari | host'dagi Docker Engine'da, host kernel'ida | Docker Desktop'ning yashirin Linux VM'ida |
| Node IP'si (`172.18.0.x`) | host'dan ochiladi | Mac'dan ochilmaydi, faqat `docker exec` va publish qilingan port orqali |
| API server | `https://127.0.0.1:<port>` | `https://127.0.0.1:<port>`, Docker Desktop port'ni Mac'ga uzatadi, bir xil ishlaydi |
| `get nodes -o wide` dagi kernel | Zorin kernel'i (`6.x.x-<...>-generic`) | Docker Desktop VM kernel'i (`6.x.x-linuxkit`) |
| Node arxitekturasi | `amd64` | `arm64` |
| Xotira | 8 GB bo'sh RAM yetarli | Docker Desktop, Settings, Resources: kamida 4 GB |

Ikkala binary Docker modulining 5-darsida o'rnatilgan. Versiyani tekshiring va eskirgan bo'lsa yangilang. Zorin uchun rasmiy yo'riqnoma (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) checksum tekshiruvini ham o'z ichiga oladi:

```
# Zorin, amd64
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
chmod +x kubectl && mkdir -p ~/.local/bin && mv ./kubectl ~/.local/bin/kubectl
rm kubectl.sha256

# kind: take <version> from https://github.com/kubernetes-sigs/kind/releases
curl -Lo ./kind https://kind.sigs.k8s.io/dl/<version>/kind-linux-amd64
chmod +x ./kind && mv ./kind ~/.local/bin/kind
```

```
# macOS, arm64
brew install kubectl kind
which -a kubectl        # Docker Desktop may ship its own kubectl; the first one wins
```

`~/.local/bin` `PATH` da bo'lmasa, uni `~/.bashrc` (Zorin) yoki `~/.zshrc` (macOS) ga qo'shing.

Asosiy klaster (vazifalar shu nom bilan yozilgan):

```
kind create cluster --name dev
kubectl cluster-info --context kind-dev
```

- **Tozalash**: `kind delete cluster --name dev`. `docker system prune` kabi umumiy tozalash ishlatilmaydi, mashinada boshqa loyihalar bor.
- **Secret'lar**: kind kubeconfig'ni `~/.kube/config` ga yozadi. Bu fayl klaster admin kaliti: ish papkasiga ko'chirilmaydi, commit qilinmaydi, README'ga uning maxfiy maydonlari yozilmaydi.
- **Ikkinchi mashinada tiklash**: klaster mashinalar orasida ko'chmaydi, javoblar git orqali ko'chadi. Boshqa mashinada `git pull`, `kind create cluster --name dev`, keyin vazifa tayangan obyektlarni README'dagi buyruqlar bilan qayta yarating: 8-vazifadagi `probe` pod'i, 10-vazifadagi `web` Deployment'i. Pod nomlari, IP'lar va `resourceVersion` boshqacha bo'ladi, bu normal; qaysi natija qaysi mashinada olinganini yozing.

---

## 1. Kubernetes nima uchun kerak

### Bu nima

Kubernetes (qisqacha K8s: "K", 8 harf, "s") bu orkestrator: bir nechta mashinani bitta hisoblash resursi deb ko'rib, konteynerlarni ularga joylashtiradigan, o'lganini qayta ko'taradigan va yangilashni boshqaradigan tizim. Siz unga "nima bo'lishi kerak"ni (masalan "shu image'dan 3 nusxa, 80-portda") API orqali yozasiz, u esa buni node'lar ustida amalga oshiradi va doimiy ushlab turadi. Node bu klasterdagi bitta mashina (fizik server, VM yoki kind'dagidek konteyner), unda konteynerlar ishlaydi.

### Mexanizm: qaysi muammolarni yechadi

Docker bitta host'da konteyner ishga tushiradi, Compose bir nechta konteynerni bitta host'da tasvirlaydi (Docker 4-dars). Production'da esa boshqa savollar paydo bo'ladi:

| Muammo | Bitta host + Compose | Kubernetes |
|--------|----------------------|------------|
| Host o'ldi | ilova to'xtaydi | pod'lar boshqa node'da qayta yaratiladi |
| Konteyner osilib qoldi | `restart` faqat jarayon chiqsa ishlaydi | liveness probe qayta ishga tushiradi (4-dars) |
| Yuklama oshdi | qo'lda yangi host va balanser | `replicas` soni, autoscaling (14-dars) |
| Yangi versiya | to'xtat, yangila, ishga tushir | rolling update, rollback (3-dars) |
| Konteynerlar bir-birini topishi | Compose tarmog'i, bitta host | Service va klaster DNS, barcha node'larda (6-dars) |
| Konfiguratsiya va secret | `.env` fayllar | ConfigMap, Secret obyektlari |
| Kim nima qila oladi | host'ga SSH | API darajasida RBAC (13-dars) |

Pod bu Kubernetes'dagi eng kichik ishga tushirish birligi: bitta yoki bir nechta konteyner, umumiy tarmoq nomlari maydoni (bitta IP) va umumiy volume'lar bilan. Kubernetes konteynerni to'g'ridan-to'g'ri emas, pod ichida boshqaradi.

### Misol

Bitta node'li `dev` klasteri yaratilgandan keyin:

```
$ kubectl get nodes
NAME                STATUS   ROLES           AGE   VERSION
dev-control-plane   Ready    control-plane   2m    v1.<NN>.<n>
```

Qatorma-qator: `NAME` node nomi (kind uni `<klaster>-control-plane` qilib beradi). `STATUS Ready` node'dagi agent (kubelet, 2-bo'lim) API server'ga muntazam "tirikman" deb xabar beryapti va pod qabul qila oladi. `ROLES control-plane` bu node'da boshqaruv komponentlari ham ishlaydi; kind'ning bitta node'li klasterida u oddiy pod'larni ham qabul qiladi. `VERSION` kubelet versiyasi, uni kind'ning node image'i belgilaydi. Docker 5-darsdagi Swarm'dagi `docker node ls` bilan solishtiring: g'oya bir xil, "klasterdagi mashinalar va ularning holati".

### Real ishda qachon kerak

- Ko'p servis, ko'p jamoa, bir necha server: har jamoa o'z ilovasini bir xil API orqali deploy qiladi.
- Cloud'da managed klaster (EKS, GKE, AKS): control plane'ni provayder boshqaradi, siz faqat manifest yozasiz.
- Avtomatik scaling, uzilishsiz yangilash, ekotizim (Helm, GitOps, operator'lar) kerak bo'lganda.

Narxi ham bor: Kubernetes murakkab. Bitta VM'da turgan bitta ilova uchun u ortiqcha; tanlov har doim "qanday muammo bor" degan savoldan boshlanadi (Docker 5-darsdagi taqqos jadvali).

### Nima uchun shunday

Kubernetes Google'ning ichki Borg tizimi tajribasidan kelib chiqqan va 2014-yilda ochiq kod sifatida e'lon qilingan, hozir CNCF (Cloud Native Computing Foundation) loyihasi. Swarm ham xuddi shu g'oyada qurilgan, lekin Kubernetes uch sababga ko'ra de-fakto standartga aylangan: API'ni kengaytirish mumkin (yangi obyekt turi, CRD, va uni boshqaradigan controller, operator), barcha cloud provayderlarda managed xizmat bor, ekotizim juda katta. Muqobili: oddiy Compose yoki Swarm (kam tushuncha), Nomad (HashiCorp, konteyner bo'lmagan ishlarni ham ishlatadi), serverless platformalar (klasterni umuman ko'rmaysiz).

## 2. Arxitektura

### Bu nima

Klaster ikki qismdan iborat: **control plane** (qaror qabul qiladi va holatni saqlaydi) va **node'lar** (konteynerlarni haqiqatda ishlatadi). Production'da control plane alohida mashinalarda, kind'ning bitta node'li klasterida esa hammasi bitta konteyner ichida.

### Control plane

| Komponent | Vazifasi |
|-----------|----------|
| `kube-apiserver` | Klasterning yagona kirish nuqtasi. REST API, autentifikatsiya (kimsiz), avtorizatsiya (ruxsatingiz bormi), admission (so'rovni tekshirish yoki to'ldirish), validatsiya. etcd bilan faqat u gaplashadi |
| `etcd` | Barcha obyektlar saqlanadigan distributed key-value store (Raft konsensus algoritmi bilan bir necha nusxa). Klaster holati shu yerda: etcd yo'qolsa, klaster "nima bo'lishi kerak"ligini unutadi |
| `kube-scheduler` | `nodeName` maydoni bo'sh pod'larni kuzatadi va har biriga node tanlaydi (avval mos kelmaydigan node'larni filtrlaydi, keyin qolganlarini baholaydi). O'zi hech narsa ishga tushirmaydi, faqat pod'ga node nomini yozadi |
| `kube-controller-manager` | O'nlab controller bitta jarayonda: Deployment, ReplicaSet, Job, Node, EndpointSlice, Namespace va boshqalar. Har biri o'z obyektlarini kuzatib, holatni keraklisiga keltiradi (3-bo'lim) |
| `cloud-controller-manager` | Cloud API bilan bog'liq controller'lar (LoadBalancer, node'lar, route'lar). kind'da yo'q |

### Node komponentlari

| Komponent | Vazifasi |
|-----------|----------|
| `kubelet` | Har node'dagi agent. Node'ning oddiy jarayoni (odatda systemd servisi), pod emas. API server'dan o'z node'iga tayinlangan pod'larni oladi, container runtime orqali ishga tushiradi, probe'larni bajaradi, holatni API'ga yozadi |
| container runtime | Konteynerni haqiqatda ishlatadigan dastur (`containerd`, CRI-O). kubelet u bilan CRI (Container Runtime Interface, gRPC protokoli) orqali gaplashadi |
| `kube-proxy` | Service'larning virtual IP'larini node'da tarmoq qoidalariga (iptables yoki nftables) aylantiradi. 6-darsda chuqur |

Qo'shimcha (addon) sifatida deyarli har klasterda: CNI plugin (Container Network Interface, pod'larga IP beradi va node'lar orasida pod tarmog'ini quradi; kind'da `kindnet`) va CoreDNS (klaster ichidagi DNS server, Service nomlarini IP'ga yechadi).

Control plane komponentlari kubeadm asosidagi klasterlarda (kind ham shunday) **static pod** sifatida ishlaydi: ularni API server emas, kubelet node'dagi papkadagi manifest fayllardan to'g'ridan-to'g'ri ishga tushiradi. Bu nima uchun kerakligini 4-vazifada o'zingiz aniqlaysiz.

### Mexanizm: Kubernetes Docker'ni ishlatmaydi

kubelet'dagi Docker Engine adapteri (dockershim) 1.24 versiyada olib tashlangan. Node'larda odatda `containerd` turadi (Docker Engine ham ichida containerd ishlatadi, ya'ni ular "qarindosh"). Docker bilan build qilingan image'lar OCI formatida (Open Container Initiative standarti) bo'lgani uchun o'zgarishsiz ishlayveradi. Lekin node ichida `docker ps` emas, `crictl ps` ishlatiladi: `crictl` CRI'ga mos har qanday runtime bilan gaplashadigan debug klienti.

### Mexanizm: so'rov yo'li

`kubectl create deployment web --image=nginx:1.28 --replicas=2` buyrug'idan keyin:

1. `kubectl` kubeconfig'dan server manzili va credential'ni olib, API server'ga HTTPS `POST` yuboradi.
2. API server so'rovni autentifikatsiya, avtorizatsiya va admission'dan o'tkazib, Deployment obyektini etcd'ga yozadi. Shu bilan `kubectl` ishi tugaydi.
3. Deployment controller yangi obyektni ko'radi va ReplicaSet yaratadi.
4. ReplicaSet controller 2 ta Pod obyekti yaratadi (`nodeName` bo'sh).
5. Scheduler har pod'ga node tanlab, `nodeName` ni yozadi.
6. O'sha node'dagi kubelet pod'ni ko'radi, runtime orqali image'ni tortib konteynerni ishga tushiradi va `status` ni yangilaydi.

Komponentlar bir-biriga to'g'ridan-to'g'ri buyruq bermaydi. Hammasi API server'dagi obyektlarni kuzatadi (`watch`: o'zgarishlar oqimiga obuna bo'lish) va o'z qismini bajaradi. Shuning uchun bitta komponent vaqtincha o'chsa, qolganlari ishlashda davom etadi, u qaytgach ish to'xtagan joyidan davom etadi (12-vazifada buni sinaysiz).

### Misol

API server'ning o'z sog'lig'i haqidagi endpoint'ini to'g'ridan-to'g'ri chaqiramiz:

```
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:41235
CoreDNS is running at https://127.0.0.1:41235/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
$ kubectl get --raw='/readyz?verbose'
[+]ping ok
[+]log ok
[+]etcd ok
[+]etcd-readiness ok
[+]informer-sync ok
[+]poststarthook/start-apiextensions-controllers ok
<...>
readyz check passed
```

Birinchi buyruq: control plane (aniqrog'i API server) host'ning `127.0.0.1` dagi tasodifiy portida. Bu port kind node konteynerining ichki 6443-portiga Docker orqali ulangan; macOS'da ham xuddi shu manzil ishlaydi, chunki Docker Desktop publish qilingan portni Mac'ga uzatadi. Ikkinchi qator: CoreDNS addon'i ham Service sifatida mavjud. `get --raw` esa API server'ga xom HTTP `GET` yuboradi va javobni o'zgartirmasdan chiqaradi. `[+]` bilan boshlangan har qator bitta ichki tekshiruv: `ping` server javob beryapti, `etcd ok` API server etcd'ga ulana oladi (bu tekshiruv yiqilsa, klaster hech narsa yoza olmaydi), `informer-sync` ichki keshlar to'ldirilgan. Oxirgi qator umumiy xulosa. Ro'yxat tarkibi versiyaga qarab biroz farq qiladi.

### Real ishda qachon kerak

- Nosozlikni qidirishda: "pod `Pending` da qoldi" bo'lsa, savol "scheduler node topa olmadimi?", "pod ishga tushdi, lekin konteyner yiqildi" bo'lsa, savol "kubelet va runtime nima deydi?". Qaysi komponent qaysi qadamni bajarishini bilmasangiz, qayerga qarashni ham bilmaysiz.
- Managed klasterda control plane ko'rinmaydi (provayder boshqaradi), lekin node komponentlari va addon'lar sizniki.

### Nima uchun shunday

Hamma narsa bitta API server orqali o'tishi uchta narsani beradi: yagona tekshiruv nuqtasi (har so'rov autentifikatsiya va RBAC'dan o'tadi, audit log bitta joyda), etcd'ni himoya qilish (uni faqat bitta komponent biladi, sxemani ham u tekshiradi), komponentlarning mustaqilligi (ular bir-birini emas, faqat API'ni biladi). Muqobili, komponentlar bir-biriga to'g'ridan-to'g'ri buyruq beradigan tizim, bitta bo'g'in o'lganda butun zanjirni to'xtatadi. Static pod mexanizmi esa "API server o'zi pod bo'lsa, uni kim ko'taradi" degan muammoning amaliy yechimi.

## 3. Deklarativ model va reconciliation loop

### Bu nima

Imperativ yondashuv: "3 ta konteyner ishga tushir" (buyruq, bir marta bajariladi). Deklarativ: "3 ta replika bo'lishi kerak" (holat, doimiy ushlab turiladi). Farq nosozlikda ko'rinadi: imperativ buyruq bajarilib bo'lgach, keyin o'lgan konteyner bilan hech kim qiziqmaydi; deklarativ holat esa har doim tekshirib turiladi.

Har obyektda ikki qism bor:

- `spec`: kerakli holat (desired state). Siz yozasiz.
- `status`: joriy holat (actual state). Controller'lar va kubelet yozadi.

Frontend tajribasidan haqiqiy o'xshashlik: React'da siz "UI shu state'dan qanday ko'rinishi kerak"ni yozasiz, React esa DOM'ni o'zi solishtirib farqini qo'llaydi va buni ham "reconciliation" deb ataydi. Kubernetes'da DOM o'rnida haqiqiy konteynerlar, render o'rnida controller sikli.

### Mexanizm

Controller bu cheksiz siklda ishlaydigan dastur: kuzat (obyekt va uning atrofidagi haqiqiy holatni o'qi), solishtir (`spec` bilan), harakat qil (farqni yo'qot). Bu reconciliation loop deyiladi.

Muhim xususiyat: controller'lar **level-triggered**, ya'ni "nima sodir bo'ldi" degan voqeaga emas, "hozir holat qanday" degan faktga qaraydi. Muqobili **edge-triggered**: faqat voqea kelganda harakat qilish (masalan "pod o'ldi" xabari). Controller bir soat o'chib tursa va shu vaqtda 5 ta pod o'lsa, u qaytgach voqealarni "o'tkazib yuborgani" muhim emas: hozir 3 ta o'rniga 1 ta borligini ko'radi va 2 ta yaratadi. Shu tufayli tizim o'zini tiklaydi (self-healing).

Zanjir: Deployment controller ReplicaSet'ni boshqaradi (har image versiyasi uchun bitta), ReplicaSet controller esa pod'lar sonini ushlab turadi. Har bo'g'in faqat o'zidan bir pastdagi obyektni biladi.

### Misol

```
$ kubectl create deployment hello --image=httpd:2.4-alpine --replicas=2
deployment.apps/hello created
$ kubectl get deployment,replicaset,pod
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello   2/2     2            2           20s

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-6c8b9d7f5b   2         2         2       20s

NAME                         READY   STATUS    RESTARTS   AGE
pod/hello-6c8b9d7f5b-4kzq2   1/1     Running   0          20s
pod/hello-6c8b9d7f5b-x7w9p   1/1     Running   0          20s
```

Birinchi qator: `kubectl` faqat obyekt yaratilganini aytadi (`created`), konteyner haqida hech narsa demaydi. Uchta jadval uch bo'g'in. Deployment: `READY 2/2` tayyor pod'lar / kerakli son, `UP-TO-DATE` joriy shablondagi pod'lar, `AVAILABLE` foydalanishga tayyor pod'lar. ReplicaSet: nomi Deployment nomi va pod shablonining hash'i, `DESIRED` uning `spec` idagi son, `CURRENT` mavjud pod'lar. Pod'lar: nomi ReplicaSet nomi va tasodifiy 5 belgi, `READY 1/1` pod'dagi tayyor konteynerlar soni, `RESTARTS` konteyner necha marta qayta ishga tushgani.

Endi kerakli holatni o'zgartiramiz va kim nima qilganini event'lardan ko'ramiz:

```
$ kubectl scale deployment hello --replicas=3
deployment.apps/hello scaled
$ kubectl get events --sort-by=.metadata.creationTimestamp | tail -6
LAST SEEN   TYPE     REASON              OBJECT                        MESSAGE
5s          Normal   ScalingReplicaSet   deployment/hello              Scaled up replica set hello-6c8b9d7f5b from 2 to 3
5s          Normal   SuccessfulCreate    replicaset/hello-6c8b9d7f5b   Created pod: hello-6c8b9d7f5b-p2m8d
4s          Normal   Scheduled           pod/hello-6c8b9d7f5b-p2m8d    Successfully assigned default/hello-6c8b9d7f5b-p2m8d to dev-control-plane
4s          Normal   Pulled              pod/hello-6c8b9d7f5b-p2m8d    Container image "httpd:2.4-alpine" already present on machine
4s          Normal   Created             pod/hello-6c8b9d7f5b-p2m8d    Created container: httpd
4s          Normal   Started             pod/hello-6c8b9d7f5b-p2m8d    Started container httpd
```

Event bu komponentlar API'ga yozadigan qisqa yozuv: "kim, qaysi obyekt bilan, nima qildi" (`tail` sarlavha qatorini qirqib yuborishi mumkin, bu yerda tushunarli bo'lishi uchun qoldirilgan). `ScalingReplicaSet`: Deployment controller ReplicaSet'dagi sonni 2 dan 3 ga o'zgartirdi. `SuccessfulCreate`: ReplicaSet controller yangi Pod obyektini yaratdi. `Scheduled`: scheduler pod'ni `dev-control-plane` node'iga tayinladi. `Pulled`, `Created`, `Started`: kubelet image'ni tekshirdi (u allaqachon node'da bor), konteynerni yaratdi va ishga tushirdi. `scale` buyrug'i faqat bitta raqamni o'zgartirdi; qolgan hamma ishni controller'lar shu raqamga qarab bajardi. Tozalash: `kubectl delete deployment hello`.

### Real ishda qachon kerak

- Obyektni qo'lda "tuzatsangiz" (masalan Deployment pod'idagi faylni `kubectl exec` bilan o'zgartirsangiz), controller pod'ni qayta yaratganda o'zgarish yo'qoladi. Tuzatish har doim `spec` orqali qilinadi.
- `kubectl apply` muvaffaqiyatli qaytishi ilova ishlayotganini anglatmaydi, faqat kerakli holat qabul qilinganini bildiradi. Natijani `status`, `kubectl get` va event'lardan ko'rasiz. CI pipeline'larida shu sabab `kubectl rollout status` bilan kutiladi (3-dars).

### Nima uchun shunday

Taqsimlangan tizimda xabarlar yo'qoladi, komponentlar qayta ishga tushadi, tarmoq uziladi. Voqealarga tayangan (edge-triggered) tizimda bitta yo'qolgan xabar abadiy noto'g'ri holat degani. Holatga tayangan tizim esa har siklda haqiqatni qaytadan tekshiradi, shuning uchun xatodan o'zi chiqadi. Narxi: natija darhol emas, "oxir-oqibat" (eventually) keladi, va siz buyruq emas, holat bilan fikrlashga o'rganishingiz kerak. Bu g'oya keyin GitOps'ga (10-dars) ham ko'chadi: kerakli holat git'da, controller klasterni unga moslaydi.

## 4. Obyektlar va YAML anatomiyasi

### Bu nima

Kubernetes'dagi har narsa (Pod, Deployment, Namespace, Node) API obyekti: API server saqlaydigan, nomi va turi bor yozuv. Manifest bu obyektni tavsiflovchi YAML (yoki JSON) fayl.

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

### Mexanizm: tizim boshqaradigan maydonlar

- `uid`: obyektning butun hayoti davomidagi yagona ID. Bir xil nomli obyekt o'chirilib qayta yaratilsa, `uid` boshqa bo'ladi.
- `resourceVersion`: obyektning har o'zgarishida yangilanadigan versiya belgisi. Optimistic locking (qulfsiz bir vaqtda yozishni nazorat qilish) uchun ishlatiladi: eskirgan nusxa ustidan yozish `Conflict` xatosini beradi. `watch` ham "shu versiyadan keyingi o'zgarishlarni ber" deb ishlaydi.
- `generation`: faqat `spec` o'zgarganda oshadigan hisoblagich. Controller qaysi `generation` ni ko'rib chiqqanini `status.observedGeneration` ga yozadi (13-vazifa).
- `ownerReferences`: obyektning egasi (Pod egasi ReplicaSet, uning egasi Deployment). Ega o'chirilsa, garbage collector (egasi yo'q bolalarni tozalaydigan controller) bolalarini ham o'chiradi.
- `finalizers`: obyekt o'chirilishidan oldin bajarilishi kerak bo'lgan ishlar ro'yxati. Ro'yxat bo'shamaguncha obyekt `Terminating` holatida qoladi.

API versiyalari eskiradi: `v1beta1` kabi versiyalar keyingi relizlarda olib tashlanadi. Internetdagi eski manifestdagi `apiVersion` hozirgi klasterda bo'lmasligi mumkin.

### Misol

Har obyektda `spec` va `status` bo'lishi shart emas. ConfigMap (konfiguratsiya juftliklari saqlanadigan obyekt) ma'lumotni `data` da saqlaydi:

```
$ kubectl create configmap demo --from-literal=color=blue
configmap/demo created
$ kubectl get configmap demo -o yaml
apiVersion: v1
data:
  color: blue
kind: ConfigMap
metadata:
  creationTimestamp: "2026-10-08T09:14:02Z"
  name: demo
  namespace: default
  resourceVersion: "4182"
  uid: 3f0c9a51-<...>
```

`apiVersion: v1` group'siz, ya'ni core group. `data` bu yerda `spec` o'rnida: ConfigMap "holat"ga ega emas, u shunchaki ma'lumot, shuning uchun uni hech qanday controller reconcile qilmaydi va `status` yo'q. `metadata` da siz faqat `name` bergansiz; `namespace` joriy context'dan olindi, `creationTimestamp`, `resourceVersion`, `uid` ni API server qo'ydi. `kubectl` maydonlarni alifbo tartibida chiqaradi, siz yozgan tartibni saqlamaydi.

Sxemani hujjat saytisiz o'qish:

```
$ kubectl explain deployment.spec.replicas
GROUP:      apps
KIND:       Deployment
VERSION:    v1

FIELD: replicas <integer>


DESCRIPTION:
    Number of desired pods. This is a pointer to distinguish between explicit
    zero and not specified. Defaults to 1.
```

`GROUP`, `KIND`, `VERSION` qaysi sxema o'qilayotganini aytadi. `FIELD` maydon nomi va turi. `DESCRIPTION` API server'dagi rasmiy tavsif: bu yerda standart qiymat ham yozilgan (`Defaults to 1`). Ma'lumot klasterning o'zidan keladi, shuning uchun aynan sizning versiyangizga mos. Butun daraxt: `kubectl explain pod.spec --recursive`.

Qaysi turlar bor:

```
$ kubectl api-resources --api-group=''
NAME                     SHORTNAMES   APIVERSION   NAMESPACED   KIND
configmaps               cm           v1           true         ConfigMap
<...>
pods                     po           v1           true         Pod
<...>
services                 svc          v1           true         Service
```

`--api-group=''` faqat core group'ni ko'rsatadi. `SHORTNAMES` qisqa nom (`kubectl get po`), `NAMESPACED` obyekt namespace ichida yashaydimi (7-bo'lim), `KIND` YAML'da yoziladigan tur nomi. Flag'siz buyruq barcha group'larni chiqaradi.

### Real ishda qachon kerak

- Internetdan olingan manifestni qo'llashdan oldin `apiVersion` hali mavjudligini `kubectl api-resources` bilan tekshirish (klasterni yangilashdan oldin ham shu).
- Maydon nomini yoki standart qiymatini eslash uchun `kubectl explain`: CKA va CKAD imtihonlarida ham asosiy ma'lumotnoma.
- `-o yaml` chiqishidan manifest yasashda tizim maydonlarini (`status`, `uid`, `resourceVersion`, `creationTimestamp`) olib tashlash kerakligini bilish.

### Nima uchun shunday

Barcha obyektlar bir xil qolipda (`apiVersion`, `kind`, `metadata`, `spec`, `status`) bo'lgani uchun bitta asbob (`kubectl`, Helm, Argo CD) har qanday turni, hatto o'zingiz qo'shgan CRD'ni ham, bir xil yo'l bilan o'qiy va yoza oladi. Versiyalash (`v1alpha1`, `v1beta1`, `v1`) API'ni buzmasdan rivojlantirish uchun: yangi maydonlar avval alpha'da sinaladi, keyin barqaror versiyaga o'tadi, eskisi ogohlantirish bilan olib tashlanadi.

## 5. kubectl asoslari

### Bu nima

`kubectl` bu API server uchun HTTP klient. U o'zi hech narsani ishga tushirmaydi va klaster holatini saqlamaydi: buyruqni REST so'roviga aylantiradi, javobni jadval yoki YAML qilib chiqaradi. Buyruq shakli: `kubectl <verb> <resource> [name] [flags]`.

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

### Mexanizm: chiqish formatlari va verbosity

Chiqish formatlari: `-o yaml`, `-o json`, `-o name`, `-o jsonpath='{...}'`, `-o custom-columns=...`. Jadval ko'rinishi inson uchun; skriptlarda jadvalni `grep` qilmang, `jsonpath` ishlating, chunki ustunlar versiyadan versiyaga o'zgaradi. JSONPath bu JSON ichidagi yo'lni ko'rsatish tili (`.items[*].metadata.name` = "har elementning nomi"), `jq` ga o'xshash, lekin soddaroq.

`-v` flag'i (verbosity, 0 dan 9 gacha) `kubectl` ichida nima bo'layotganini ko'rsatadi: `-v=6` qaysi URL'ga so'rov ketgani va javob kodini, `-v=8` so'rov va javob tanasini ham.

### Misol

```
$ kubectl get nodes -o jsonpath='{.items[*].metadata.name}{"\n"}'
dev-control-plane
$ kubectl get pods -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName | head -3
NS                   NAME                                         NODE
kube-system          coredns-<hash>-<id>                          dev-control-plane
kube-system          coredns-<hash>-<id>                          dev-control-plane
$ kubectl get namespaces -v=6 2>&1 | grep 'namespaces?limit'
I1008 09:20:11.512304   48211 round_trippers.go:<n>] <...> GET https://127.0.0.1:41235/api/v1/namespaces?limit=500 200 OK in 6 milliseconds
```

Birinchi buyruq: barcha node'lar nomi bitta qatorda (`{"\n"}` oxiriga yangi qator qo'shadi). Ikkinchisi: o'zingiz tanlagan uch ustun, `NODE` qiymati pod'ning `spec.nodeName` maydoni, ya'ni scheduler yozgan maydon. Uchinchisi: `-v=6` log'i stderr'ga chiqadi, shuning uchun `2>&1`. Qatorda: `I1008 09:20:11` log darajasi (`I` = info) va vaqt, keyin manba fayl, keyin asosiysi: `GET` metodi, URL (`/api/v1/namespaces`: core group, `v1` versiya, `namespaces` resurs; `limit=500` `kubectl` ro'yxatni bo'laklab olishi uchun) va `200 OK`. Log qatorining ko'rinishi `kubectl` versiyasiga qarab o'zgaradi (yangi versiyalarda `verb="GET" url="..." status="200 OK"` shaklida), metod, URL va status har doim bor.

### Real ishda qachon kerak

- `jsonpath` va `custom-columns`: skript va CI'da obyekt maydonini aniq olish.
- `-v=6`: `kubectl` "sekin" yoki "Forbidden" degan paytda qaysi so'rov va qaysi javob ekanini ko'rish.
- Imperativ buyruqlar (`kubectl create`, `run`, `scale`, `edit`) o'rganish va tezkor tekshiruv uchun qulay. Production'da holat fayllarda turadi va `apply` bilan qo'llanadi, chunki fayl review qilinadi, git'da saqlanadi va qayta qo'llash mumkin (3-dars, keyin 10-darsda GitOps).

### Nima uchun shunday

Hamma narsa oddiy HTTP API orqali bo'lgani uchun `kubectl` maxsus emas: xuddi shu API'ni Go klient kutubxonasi (`client-go`), Python klienti, Helm, Argo CD, hatto `curl` ham chaqiradi. `kubectl` faqat qulay interfeys. Frontend tajribasidan: bu REST API ustidagi CLI, `gh` GitHub API ustida qanday bo'lsa, shunday.

## 6. kubeconfig va context

### Bu nima

kubeconfig bu `kubectl` qaysi klasterga, kim sifatida ulanishini aytadigan YAML fayl. Standart joyi `~/.kube/config`; `KUBECONFIG` muhit o'zgaruvchisi (bir nechta fayl `:` bilan ajratiladi va birlashtiriladi) yoki `--kubeconfig` flag'i bilan o'zgartiriladi. Uch ro'yxatdan iborat:

| Bo'lim | Tarkibi |
|--------|---------|
| `clusters` | API server manzili va CA sertifikati (server sertifikatini tekshirish uchun) |
| `users` | credential: klient sertifikati, token yoki tashqi buyruq (`exec`) |
| `contexts` | uchlik: cluster + user + standart namespace |

`current-context` hozir faol context'ni ko'rsatadi.

### Mexanizm

`kubectl` har buyruqda: `current-context` ni (yoki `--context` qiymatini) oladi, undagi `cluster` va `user` nomlarini topadi, server manziliga TLS ulanish ochib, server sertifikatini `clusters` dagi CA bilan tekshiradi va `users` dagi credential bilan o'zini tanishtiradi. Namespace flag'i berilmasa, context'dagi `namespace` ishlatiladi, u ham bo'lmasa `default`.

kind `create cluster` qilganda shu faylga `kind-<nom>` nomli cluster, user va context qo'shadi va uni `current-context` qiladi; `delete cluster` ularni olib tashlaydi.

### Misol

```
$ kubectl config get-contexts
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         kind-dev   kind-dev   kind-dev
$ kubectl config view --minify
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://127.0.0.1:41235
  name: kind-dev
contexts:
- context:
    cluster: kind-dev
    user: kind-dev
  name: kind-dev
current-context: kind-dev
kind: Config
<...>
```

`get-contexts`: `*` faol context, `AUTHINFO` user nomi (eski atama), `NAMESPACE` bo'sh, ya'ni `default`. `view --minify` faqat joriy context'ga tegishli qismni chiqaradi; `DATA+OMITTED` sertifikat ma'lumoti yashirilganini bildiradi (`--raw` qo'shilsa ochiq chiqadi, buni ekranga yoki README'ga chiqarmang). `server` 2-bo'limdagi manzil. `users` qismini 14-vazifada o'zingiz o'qib, kind qaysi usulda autentifikatsiya qilishini aniqlaysiz.

Kundalik buyruqlar:

```
kubectl config current-context
kubectl config use-context kind-dev
kubectl config set-context --current --namespace=<ns>
kubectl --context kind-dev get nodes      # one-off, without switching
```

### Real ishda qachon kerak

- Bir kunda bir necha klaster (dev, staging, production) bilan ishlash. Skriptlarda va CI'da har doim `--context` yoki alohida `KUBECONFIG` fayl aniq beriladi.
- Cloud klasterlarida `users` odatda `exec` bo'ladi (masalan `aws eks get-token`): kubeconfig'da doimiy parol emas, qisqa muddatli token oladigan buyruq turadi.

### Nima uchun shunday

Cluster, user va context'ning ajratilgani bitta odamga bitta klasterga turli huquqlar bilan (admin va oddiy user) yoki bitta credential bilan bir nechta namespace'ga ulanish imkonini beradi. Narxi: "hozir qaysi context'daman" savoli doim ochiq. Eng qimmat xatolardan biri `kubectl delete` ni production context'ida bajarish; shuning uchun ko'p jamoalar terminal prompt'ida joriy context'ni ko'rsatadi va production uchun alohida kubeconfig fayl ishlatadi. kubeconfig ichida klaster admin credential'i bor: u parol bilan teng, git'ga, chatga, CI log'iga tushmasligi kerak.

## 7. Namespace

### Bu nima

Namespace bu bitta klaster ichida obyekt nomlarini ajratadigan mantiqiy bo'lim: jamoa, muhit yoki ilova bo'yicha. Ikki xil namespace'da bir xil nomli Deployment bo'lishi mumkin, bitta namespace ichida esa yo'q.

### Mexanizm

- Ko'pchilik obyektlar namespaced (Pod, Deployment, Service, ConfigMap, Secret). Ba'zilari cluster-scoped, ya'ni butun klasterga bitta: Node, Namespace, PersistentVolume, StorageClass, ClusterRole. Farqni `kubectl api-resources` ning `NAMESPACED` ustuni va `--namespaced=false` flag'i ko'rsatadi.
- Namespace'ga ResourceQuota (resurs chegarasi), LimitRange, RBAC va NetworkPolicy bog'lanadi (13, 15-darslar).
- Namespace o'chirilsa, ichidagi barcha obyektlar o'chadi. Namespace controller ularni birma-bir o'chiradi, shu vaqt davomida namespace `Terminating` holatida turadi.
- Service DNS nomi namespace'ni o'z ichiga oladi (`<service>.<namespace>.svc.cluster.local`), 6-darsda.

### Misol

```
$ kubectl get namespaces
NAME                 STATUS   AGE
default              Active   25m
kube-node-lease      Active   25m
kube-public          Active   25m
kube-system          Active   25m
local-path-storage   Active   25m
```

`default`: namespace ko'rsatilmagan obyektlar shu yerga tushadi. `kube-node-lease`: har node uchun bitta Lease obyekti, kubelet uni bir necha soniyada yangilab "tirikman" deydi (yengil heartbeat). `kube-public`: hamma o'qiy oladigan kichik ma'lumot. `kube-system`: Kubernetes'ning o'z komponentlari va addon'lari. `local-path-storage`: kind qo'shgan, node diskida volume yaratadigan provisioner (7-dars); boshqa klasterlarda bo'lmaydi. `STATUS Active` namespace ishlatishga tayyor.

```
$ kubectl create namespace sandbox
namespace/sandbox created
$ kubectl -n sandbox create configmap demo --from-literal=color=green
configmap/demo created
$ kubectl get configmap demo -o jsonpath='{.data.color}{"\n"}'
blue
$ kubectl -n sandbox get configmap demo -o jsonpath='{.data.color}{"\n"}'
green
$ kubectl delete namespace sandbox
namespace "sandbox" deleted
```

Bir xil `demo` nomi ikki namespace'da yashaydi (birinchisi 4-bo'limdan `default` da). `-n` flag'isiz `kubectl` context'dagi namespace'ga, ya'ni `default` ga qaradi. Namespace o'chirilganda ichidagi ConfigMap ham ketdi. Tozalash: `kubectl delete configmap demo`.

### Real ishda qachon kerak

- Bitta klasterni bir nechta jamoa yoki muhit (dev, staging) bo'lishganda: har biriga o'z namespace'i, quota va RBAC.
- Addon'larni ajratish: cert-manager, monitoring, ingress controller odatda o'z namespace'ida (8-dars).
- Vaqtinchalik muhit: PR uchun namespace yaratib, ish tugagach bitta buyruq bilan hammasini o'chirish.

### Nima uchun shunday

Namespace yengil ajratish: yangi klaster qurmasdan nomlar, huquqlar va resurs chegaralarini bo'lish imkonini beradi. Lekin u xavfsizlik chegarasi emas: standart holatda bir namespace'dagi pod boshqa namespace'dagi pod'ga tarmoq orqali bemalol ulanadi, hammasi bitta kernel'li node'larda ishlaydi. Izolyatsiya NetworkPolicy va RBAC bilan alohida quriladi (13-dars); kuchli izolyatsiya kerak bo'lsa (masalan ishonchsiz mijozlar) alohida klaster tanlanadi.

## 8. Label, selector va annotation

### Bu nima

Label bu obyektga yopishtirilgan `kalit: qiymat` juftligi. Selector bu label'lar bo'yicha obyektlarni tanlaydigan ifoda. Kubernetes'da obyektlar bir-biriga nom orqali emas, label selector orqali bog'lanadi: ReplicaSet o'z pod'larini, Service o'z backend'larini selector bilan topadi. Frontend'dan haqiqiy o'xshashlik: label HTML elementidagi `class`, selector esa CSS selector'i; qoida elementni nomi bilan emas, belgisi bilan topadi.

Annotation ham `kalit: qiymat`, lekin tanlash uchun emas, ma'lumot biriktirish uchun: asboblar konfiguratsiyasi, build ma'lumoti, tavsif. Annotation bo'yicha selector yo'q, qiymati esa label'nikidan ancha uzun bo'lishi mumkin (label qiymati 63 belgigacha).

### Mexanizm

Bog'lanish "bo'sh" (loosely coupled): ReplicaSet doimiy ravishda "label'i selector'imga mos pod'lar nechta?" deb sanaydi. Pod label'ini o'zgartirsangiz, u to'plamdan chiqadi va controller o'rniga yangisini yaratadi (18-vazifa).

Selector ikki turda:

```
kubectl get pods -l app=web,tier!=cache        # equality-based
kubectl get pods -l 'env in (dev,stage)'       # set-based
kubectl get pods -l '!env'                     # label does not exist
kubectl label pod NAME env=dev --overwrite     # add or change
kubectl label pod NAME env-                    # remove
```

Manifestlarda selector `matchLabels` (aniq tenglik) va `matchExpressions` (`In`, `NotIn`, `Exists`, `DoesNotExist`) shaklida yoziladi. Vergul "va" ma'nosini beradi.

Tavsiya etilgan umumiy label'lar: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`. Ular asboblar (Helm, dashboard'lar) o'rtasida umumiy til.

### Misol

3-bo'limdagi `hello` Deployment'ini qayta yarating (`--replicas=2`) va:

```
$ kubectl get deployment hello -o jsonpath='{.spec.selector}{"\n"}'
{"matchLabels":{"app":"hello"}}
$ kubectl get pods --show-labels
NAME                     READY   STATUS    RESTARTS   AGE   LABELS
hello-6c8b9d7f5b-9tq4n   1/1     Running   0          15s   app=hello,pod-template-hash=6c8b9d7f5b
hello-6c8b9d7f5b-m2kxr   1/1     Running   0          15s   app=hello,pod-template-hash=6c8b9d7f5b
$ kubectl get pods -l app=hello -o name
pod/hello-6c8b9d7f5b-9tq4n
pod/hello-6c8b9d7f5b-m2kxr
```

Birinchi chiqish: `kubectl create deployment` Deployment'ga `app=hello` selector'ini o'zi qo'ygan. Ikkinchisi: har pod'da ikki label. `app=hello` pod shablonidan keldi, `pod-template-hash` ni Deployment controller qo'shgan: u ReplicaSet nomidagi hash bilan bir xil va eski hamda yangi versiyadagi pod'larni ajratish uchun kerak (rolling update paytida ikki ReplicaSet birga yashaydi). Uchinchisi: selector bilan tanlangan pod'lar, faqat nomlari (`-o name` skript uchun qulay). Tozalash: `kubectl delete deployment hello`.

### Real ishda qachon kerak

- Service'ni pod'larga ulash (3, 6-darslar), NetworkPolicy qaysi pod'larga tegishli ekanini aytish (13-dars), monitoring qaysi pod'lardan metrika olishini tanlash.
- Ko'p obyekt bilan bir vaqtda ishlash: `kubectl delete pods -l env=dev`, `kubectl get all -l app.kubernetes.io/instance=shop`.
- Annotation: git commit SHA, "kim deploy qildi", asbob sozlamalari (masalan cert-manager, 8-dars).

### Nima uchun shunday

Nomga asoslangan bog'lanish qattiq: pod nomlari tasodifiy va doim o'zgaradi, ro'yxatni kimdir yangilab turishi kerak bo'lardi. Label bo'yicha tanlash esa dinamik: yangi pod kerakli label bilan tug'ilsa, u avtomatik to'plamga kiradi. Bu Borg tajribasidan kelgan qaror. Narxi: label'ni ehtiyotsiz o'zgartirish pod'ni Service va ReplicaSet'dan "jimgina" uzib qo'yadi, xato chiqmaydi. Label (tanlash, qisqa) va annotation (ma'lumot, uzun) ajratilgani esa API server'ga indekslanadigan va indekslanmaydigan ma'lumotni farqlash imkonini beradi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Orkestrator | konteynerlarni bir nechta mashinaga joylashtiradigan, kuzatadigan va yangilaydigan tizim |
| Klaster | bitta control plane boshqaradigan node'lar to'plami |
| Node | klasterdagi bitta mashina (server, VM yoki kind'da konteyner) |
| Control plane | API server, etcd, scheduler va controller manager: qaror qabul qiluvchi qism |
| Pod | bir yoki bir necha konteyner, umumiy IP va volume'lar bilan; eng kichik ishga tushirish birligi |
| `kube-apiserver` | klasterning yagona REST kirish nuqtasi, etcd bilan faqat u gaplashadi |
| etcd | klaster holati saqlanadigan distributed key-value store |
| Scheduler | pod'ga node tanlab, `nodeName` ni yozadigan komponent |
| Controller | obyektni kuzatib, haqiqiy holatni `spec` ga keltiradigan sikl |
| kubelet | node'dagi agent: pod'larni runtime orqali ishga tushiradi va holatini yozadi |
| Container runtime | konteynerni haqiqatda ishlatadigan dastur (`containerd`, CRI-O) |
| CRI | kubelet va runtime orasidagi gRPC interfeys |
| `crictl` | CRI runtime'lari uchun debug klienti |
| CNI | pod'larga IP beradigan va pod tarmog'ini quradigan plugin standarti |
| Static pod | API server orqali emas, kubelet node'dagi fayldan ishga tushiradigan pod |
| Desired state | `spec` da yozilgan kerakli holat |
| Reconciliation loop | kuzat, solishtir, harakat qil sikli |
| Level-triggered | voqeaga emas, joriy holatga qarab harakat qilish |
| Manifest | obyektni tavsiflovchi YAML yoki JSON fayl |
| API group | bog'liq obyekt turlari to'plami (`apps`, `batch`, core) |
| `resourceVersion` | obyektning har o'zgarishida yangilanadigan versiya belgisi |
| `generation` | `spec` o'zgarganda oshadigan hisoblagich |
| `ownerReferences` | obyektning egasiga havola, garbage collection uchun |
| Event | komponent yozadigan "kim, nimani, nima qildi" yozuvi |
| kubeconfig | klaster manzili, credential va context'lar saqlanadigan fayl |
| Context | cluster + user + standart namespace uchligi |
| Namespace | obyekt nomlarini ajratadigan mantiqiy bo'lim |
| Cluster-scoped | namespace'ga tegishli bo'lmagan, klasterga bitta obyekt |
| Label | tanlash uchun obyektga qo'yiladigan qisqa `kalit: qiymat` |
| Selector | label'lar bo'yicha obyektlarni tanlaydigan ifoda |
| Annotation | tanlanmaydigan, ma'lumot uchun `kalit: qiymat` |

## Tuzoqlar

- `kubectl apply` muvaffaqiyatli qaytdi degani ilova ishladi degani emas. Har doim `status`, `kubectl get pods` va event'larni tekshiring.
- Noto'g'ri context yoki namespace'da buyruq bajarish. O'chirish buyruqlaridan oldin `kubectl config current-context` ni ko'ring.
- Deployment pod'ini qo'lda "tuzatish" (`kubectl exec` bilan fayl o'zgartirish, pod'ni `edit` qilish). Controller keyingi qayta yaratishda hammasini yo'qotadi.
- Label'ni o'ylamasdan o'zgartirish: pod Service va ReplicaSet'dan uzilib, trafik olmaydigan "yetim"ga aylanadi.
- Namespace'ni izolyatsiya deb o'ylash. Tarmoq va huquqlar alohida sozlanmaguncha ochiq.
- Internetdan olingan eski manifestlardagi olib tashlangan `apiVersion` lar (`extensions/v1beta1` va shunga o'xshash).
- kubeconfig'ni commit qilish, `kubectl config view --raw` natijasini README'ga yoki chatga qo'yish. Bu klaster admin kaliti.
- Skriptda `kubectl get` jadvalini `grep`/`awk` bilan kesish: ustunlar versiyaga qarab o'zgaradi, `-o jsonpath` ishlating.
- `-o yaml` chiqishini o'zgartirmasdan manifest sifatida saqlash: `status`, `uid`, `resourceVersion` keyingi `apply` da chalkashlik keltiradi.
- Node ichida `docker ps` qidirish: runtime `containerd`, `crictl` ishlating.
- macOS'da kind node IP'siga (`172.18.0.x`) host'dan `curl` qilish: Docker yashirin VM'da, ishlamaydi.
- Tag'siz image (`nginx`): `latest` olinadi, keyingi pull'da boshqa versiya keladi. Har doim aniq tag yozing.
- etcd'ni zaxirasiz qoldirish: klasterning butun holati shu yerda (11-darsda qaytamiz).

## Manbalar

- https://kubernetes.io/docs/concepts/overview/ – Kubernetes nima va nima emas
- https://kubernetes.io/docs/concepts/overview/components/ – komponentlar ro'yxati
- https://kubernetes.io/docs/concepts/architecture/ – klaster arxitekturasi
- https://kubernetes.io/docs/concepts/architecture/controller/ – controller va reconciliation
- https://kubernetes.io/docs/concepts/overview/working-with-objects/ – obyektlar, nomlar, namespace, label, annotation
- https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/ – tavsiya etilgan label'lar
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/ – static pod'lar
- https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/ – kubeconfig
- https://kubernetes.io/docs/reference/kubectl/quick-reference/ – kubectl qisqa ma'lumotnoma
- https://kubernetes.io/docs/reference/kubectl/jsonpath/ – JSONPath
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/ – `crictl` bilan node'ni debug qilish
- https://kubernetes.io/blog/2022/02/17/dockershim-faq/ – dockershim olib tashlanishi haqida
- https://kind.sigs.k8s.io/docs/user/quick-start/ – kind
- Lukša, "Kubernetes in Action" (2-nashr), 1–4 boblar

## Birga bajaramiz

Vazifalardagidan boshqa klasterda va boshqa ilova bilan butun zanjirni boshidan oxirigacha o'tamiz: ikki node'li `walk` klasteri, `shop` namespace'i, manifest fayldan deklarativ deploy, natijani qatlamma-qatlam tekshirish va tozalash. Hamma narsa host'da, repo'dan tashqaridagi `~/k1-walk` papkasida, hech narsa commit qilinmaydi. `dev` klasteri bilan bir vaqtda xotira yetmasa, avval `dev` ni o'chiring (keyin qayta yaratasiz).

1. Klaster konfiguratsiyasi. kind bitta control-plane va bitta worker node bilan klasterni fayldan yaratadi (multi-node klaster 2-darsning asosiy mavzusi, bu yerda faqat oldindan ko'rish):

```
$ mkdir ~/k1-walk && cd ~/k1-walk
$ cat kind-walk.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
```

Bu fayl Kubernetes manifesti emas, kind'ning o'z formati, lekin qolipi tanish: `kind` va `apiVersion`.

2. Klasterni yarating:

```
$ kind create cluster --name walk --config kind-walk.yaml
Creating cluster "walk" ...
 ✓ Ensuring node image (kindest/node:v1.<NN>.<n>)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing CNI
 ✓ Installing StorageClass
 ✓ Joining worker nodes
Set kubectl context to "kind-walk"
<...>
```

Har qadam: node image (Kubernetes komponentlari oldindan joylangan Docker image; har kind relizi o'z standart image versiyasini biladi, `--image` bilan aniq versiya berish mumkin) tekshirildi, ikki konteyner yaratildi, ichida kubeadm bilan control plane ko'tarildi, CNI (`kindnet`) va StorageClass o'rnatildi, worker klasterga qo'shildi. Oxirgi qator muhim: kind `current-context` ni `kind-walk` ga o'zgartirdi. Haqiqiy chiqishda qatorlar oxirida belgi (emoji) ham bor.

3. Context va node'lar:

```
$ kubectl config current-context
kind-walk
$ kubectl get nodes -L kubernetes.io/arch
NAME                 STATUS   ROLES           AGE   VERSION       ARCH
walk-control-plane   Ready    control-plane   60s   v1.<NN>.<n>   arm64
walk-worker          Ready    <none>          40s   v1.<NN>.<n>   arm64
```

`-L` label qiymatini alohida ustun qilib chiqaradi: `kubernetes.io/arch` ni kubelet har node'ga o'zi qo'yadi. Bu chiqish Mac'dan (`arm64`); Zorin'da `amd64` bo'ladi, image'lar ikkala arxitektura uchun chiqqani uchun qolgan hamma narsa bir xil. Worker'ning `ROLES` i `<none>`: rol ham shunchaki label.

4. Manifest. Namespace va Deployment bitta faylda, `---` bilan ajratilgan:

```
$ cat shop.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shop
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: shop
  labels:
    app.kubernetes.io/name: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          ports:
            - containerPort: 80
```

O'qish tartibi 4-bo'limdagidek: tur va versiya, `metadata`, `spec`. Deployment `spec` ida uchta asosiy narsa: `replicas` (nechta), `selector` (qaysi pod'lar meniki), `template` (yangi pod qanday bo'lsin). `selector` dagi label `template` dagi label bilan mos kelishi shart, aks holda API server manifestni rad etadi.

5. Qo'llash va kutish:

```
$ kubectl apply -f shop.yaml
namespace/shop created
deployment.apps/catalog created
$ kubectl -n shop rollout status deployment/catalog
Waiting for deployment "catalog" rollout to finish: 0 of 2 updated replicas are available...
deployment "catalog" successfully rolled out
```

`apply` faqat ikki obyekt qabul qilinganini aytdi. `rollout status` esa `status` ni kuzatib, ikki pod tayyor bo'lguncha kutdi: 3-bo'limdagi "qabul qilindi" va "ishlayapti" farqi.

6. Pod'lar qayerda:

```
$ kubectl -n shop get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
catalog-5d7c9b8f6d-kq7tz   1/1     Running   0          30s   10.244.1.2   walk-worker   <none>           <none>
catalog-5d7c9b8f6d-zc4nm   1/1     Running   0          30s   10.244.1.3   walk-worker   <none>           <none>
```

Ikkala pod ham `walk-worker` da. Sabab: ko'p node'li kind klasterida control-plane node'ida taint (node'ga qo'yiladigan "bu yerga oddiy pod qo'ymang" belgisi, 12-dars) bor va scheduler uni filtrlaydi. `IP` pod tarmog'idagi manzil (`10.244.1.0/24` worker'ga ajratilgan bo'lak), Mac'dan unga yetib bo'lmaydi, Zorin'dan ham to'g'ridan-to'g'ri emas. Oxirgi ikki ustun keyingi darslar uchun.

7. Ilova javob beryaptimi. Pod ichidan o'ziga so'rov yuboramiz (Apache image'ida `wget` bor):

```
$ kubectl -n shop exec deploy/catalog -- wget -qO- http://localhost
<html><body><h1>It works!</h1></body></html>
```

`deploy/catalog` yozuvi "shu Deployment'ning istalgan pod'i" degani, pod nomini qidirish shart emas. Tashqaridan kirish (Service, `port-forward`) 3-darsda.

8. Deklarativ o'zgartirish. Fayldagi `replicas: 2` ni `3` qiling va qayta qo'llang:

```
$ kubectl apply -f shop.yaml
namespace/shop unchanged
deployment.apps/catalog configured
$ kubectl -n shop get deployment catalog
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
catalog   3/3     3            3           2m
```

`unchanged`: Namespace faylda o'zgarmagan, unga tegilmadi. `configured`: Deployment'ning farqi qo'llandi. Xuddi shu faylni yana necha marta qo'llasangiz ham natija bir xil (idempotent). Shu fayl git'da tursa, u klasterning "manba haqiqati" bo'ladi.

9. Tozalash va tekshirish:

```
$ kubectl delete -f shop.yaml
namespace "shop" deleted
deployment.apps "catalog" deleted
$ kind delete cluster --name walk
Deleting cluster "walk" ...
$ kind get clusters
dev
$ kubectl config current-context
error: current-context is not set
$ kubectl config use-context kind-dev
Switched to context "kind-dev".
```

`delete -f` fayldagi obyektlarni o'chirdi (namespace o'chirilganda ichidagi hammasi baribir ketardi). `kind get clusters` faqat `dev` ni ko'rsatdi (agar uni o'chirgan bo'lsangiz, bo'sh). `current-context` xatosi: kind o'chirilgan klasterning cluster, user va context yozuvlarini kubeconfig'dan olib tashladi va u joriy context bo'lgani uchun joriy context ham bo'shab qoldi. `kubectl` boshqa klasterga o'zi o'tmaydi, buni siz aniq qilasiz. Papkani o'chirish: `rm -r ~/k1-walk`.

---

## Vazifalar

Barchasini `kubernetes/01-intro/` papkasida bajaring (`make new m=kubernetes n=01 name=intro` bilan host'da yarating). Javoblar shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida yoziladi: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (YAML, skript) shu papkaga saqlanadi. Hamma buyruq host'da, `dev` klasterida; mashinaga bog'liq natijada (kernel, arxitektura, port) qaysi mashinada olinganini yozing. kubeconfig'ning maxfiy maydonlari (`*-data`, token) README'ga yozilmaydi.

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

12. **Scheduler down.** `docker exec dev-control-plane mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/` bilan scheduler'ni to'xtating. Scheduler pod'i yo'qolganini tekshiring, so'ng `kubectl scale deployment web --replicas=5` qiling. Yangi pod'lar qaysi holatda va nima uchun? Mavjud pod'lar ishlayaptimi? Faylni joyiga qaytaring va nima bo'lishini kuzating. Bu tajriba "level-triggered" tushunchasini qanday ko'rsatadi? (Bu buyruq faqat kind node konteyneri ichidagi faylni ko'chiradi, host'ga tegmaydi. Faylni qaytarishni unutmang, aks holda keyingi vazifalarda yangi pod'lar `Pending` da qoladi.)

13. **Spec vs status.** `kubectl get deployment web -o yaml` da `spec.replicas`, `status.replicas`, `status.readyReplicas`, `metadata.generation` va `status.observedGeneration` ni toping. `kubectl scale` dan darhol keyin va bir necha soniyadan so'ng bu qiymatlar qanday o'zgarishini yozing. `observedGeneration` nimani bildiradi?

### D. kubeconfig va namespace

14. **kubeconfig anatomy.** `kubectl config view` natijasida `clusters`, `users`, `contexts` bo'limlarini ko'rsating (maxfiy qiymatlarni README'ga yozmang). kind foydalanuvchini qanday autentifikatsiya qilyapti: token, sertifikat yoki boshqa usul? API server manzili qaysi port va u Docker'da qanday e'lon qilingan?

15. **Two clusters.** Ikkinchi klaster yarating: `kind create cluster --name lab`. `kubectl config get-contexts` natijasini ko'rsating. Context'ni almashtirmasdan (`--context` bilan) ikkala klasterdagi node'larni chiqaring. Keyin `use-context` bilan almashtiring. Oxirida `lab` klasterini o'chiring va kubeconfig'dan nima yo'qolganini tekshiring. (Bu `lab` kind klasteri, Multipass'dagi `lab` VM bilan aloqasi yo'q.)

16. **Namespaces.** `team-a` namespace'ini yarating va ichida `web` nomli Deployment yarating (`default` da ham shu nomli bor). Nima uchun nom to'qnashuvi yo'q? Joriy context'ning standart namespace'ini `team-a` ga o'zgartiring, `kubectl get pods` nimani ko'rsatishini tekshiring va qaytarib qo'ying. Namespace'ni o'chirganda ichidagi obyektlar bilan nima bo'ldi?

### E. Label va selector

17. **Labels and selectors.** `default` dagi pod'larga turli label'lar qo'ying (`env=dev`, `env=prod`, `tier=frontend`). Uchta so'rov yozing: tenglik bo'yicha, `in` operatori bilan, va label mavjud emasligi bo'yicha. `-L` va `--show-labels` flag'lari farqini ko'rsating.

18. **Break the selector.** `web` Deployment pod'laridan birining `app` label qiymatini `kubectl label --overwrite` bilan o'zgartiring. Pod'lar soni nechta bo'ldi? O'zgartirilgan pod'ning `ownerReferences` iga nima bo'ldi? Bu usul production'da nosoz pod'ni trafikdan chiqarib, debug uchun saqlab qolishda qanday ishlatilishini izohlang. "Yetim" pod'ni o'chiring.

19. **Labels vs annotations.** Bitta pod'ga annotation qo'shing (`kubectl annotate`) va annotation bo'yicha `-l` bilan qidirib ko'ring. Natijani izohlang. Uchta ma'lumot uchun qaysi biri mos: jamoa nomi, git commit SHA, 2 KB hajmli JSON konfiguratsiya? Sababini yozing.

### F. Yakuniy

20. **Request trace.** `kubectl create deployment trace --image=nginx:1.28 --replicas=2` ni bajaring va `kubectl get events --sort-by=.metadata.creationTimestamp` natijasidan foydalanib, buyruqdan konteyner ishga tushgunicha bo'lgan zanjirni README'da qadam-baqadam yozing: har event'ni qaysi komponent yaratgan (`SOURCE` yoki `REPORTING` ustuni), 2-bo'limdagi 6 qadamning qaysi biriga to'g'ri keladi. Oxirida matnli diagramma chizing: komponentlar va ular orasidagi o'qlar. (Standart jadvalda bu ustunlar yo'q: ularni `-o wide` yoki `-o custom-columns` bilan chiqaring.)

## Topshirish

Tayyor bo'lgach:
1. `kubernetes/01-intro/README.md` da barcha 20 vazifa `## N. Title` sarlavhasi bilan yozilgan; mashinaga bog'liq natijalar qaysi mashinada olingani bilan.
2. `make check` toza o'tadi.
3. Papkada kubeconfig, sertifikat ma'lumoti yoki boshqa maxfiy narsa yo'q (`git status` va `make secrets` bilan tekshiring).
4. 12-vazifadagi `kube-scheduler.yaml` joyiga qaytarilgan (`kubectl get pods -n kube-system` da scheduler `Running`).
5. Ortiqcha klasterlar o'chirilgan: `kind get clusters` faqat `dev` ni ko'rsatadi yoki bo'sh; `walk` va `lab` yo'q.
6. Menga xabar bering, tekshiraman.

## O'zini tekshirish savollari

Kodsiz, o'z so'zingiz bilan javob bering:

- `kubectl apply` dan konteyner ishga tushgunicha qaysi komponentlar qaysi tartibda ishlaydi?
- etcd bilan qaysi komponent gaplashadi va bu cheklov nima uchun foydali?
- Scheduler o'chib qolsa ishlab turgan ilovalarga nima bo'ladi? kubelet o'chsa-chi?
- `spec` va `status` farqi nima, har birini kim yozadi? Nima uchun ConfigMap'da `status` yo'q?
- "Level-triggered" controller "edge-triggered" dan nimasi bilan ishonchliroq?
- `resourceVersion` va `generation` farqi nima?
- Service o'z pod'larini qanday topadi va bu bog'lanish nima uchun nom orqali emas?
- `kubectl` aslida nima qiladi? Uni nima bilan almashtirish mumkin?
- Context nimalardan tashkil topgan? Noto'g'ri context'dan qanday himoyalanasiz?
- Namespace nimani ajratadi va nimani ajratmaydi?
- Label va annotation qachon ishlatiladi?
- macOS'da kind node'ining IP'siga host'dan nima uchun yetib bo'lmaydi, API server'ga esa nima uchun yetiladi?
