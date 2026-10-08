# Kubernetes o'quv rejasi (konteyner orkestratsiyasi)

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. `docker`, `linux`, `network`, `cicd` va `observability` modullari o'tilgan deb olinadi; Kubernetes'ning o'zi (deklarativ model, controller'lar, Service mexanizmi, storage, RBAC) har darsda noldan, mexanizmi va ishlaydigan misoli bilan tushuntiriladi.

Ishlash tartibi: men nazariya va vazifalar beraman, siz klasterda bajarib natijani ish papkasidagi `README.md` ga yozasiz, men tekshirib xato va tuzoqlarni ko'rsataman.
Har dars uchun alohida papka: `kubernetes/01-intro/`, `kubernetes/02-cluster-setup/` va hokazo. Yaratish: `make new m=kubernetes n=01 name=intro`. Topshirishdan oldin `make check` toza bo'lishi shart.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har darsning muddati o'sha darsning `Taxminiy vaqt` qatorida, bu jadval ularning yig'indisi. Hafta 5 o'quv kuni deb olinadi.

| Bosqich | Darslar | Dars bo'yicha (kun) | Siz uchun | Sabab |
|---------|---------|---------------------|-----------|-------|
| I - Asoslar va klaster | 3 | 1-dars: 3, 2-dars: 4, 3-dars: 3 | 10 kun | Deklarativ model, arxitektura, kind, k3s va kubeadm bilan klaster yig'ish yangi. 2-darsda Multipass VM'lar |
| II - Workload, tarmoq, storage, TLS | 5 | 4-dars: 4, 5-dars: 3, 6-dars: 4, 7-dars: 3, 8-dars: 3 | 17 kun | Probe, graceful shutdown, DNS, TLS oldingi modullardan tanish. Service mexanizmi, storage modeli va Helm yangi, qisqartirilmaydi |
| III - Yetkazib berish | 2 | 9-dars: 3, 10-dars: 4 | 7 kun | CI/CD moduli o'tilgan. RBAC orqali pipeline kirishi va GitOps yangi |
| IV - Production | 5 | 11-dars: 3, 12-dars: 4, 13-dars: 4, 14-dars: 3, 15-dars: 2 + yakuniy loyiha 5–6 | 21–22 kun | Butunlay yangi soha: HA, stateful, xavfsizlik, autoscaling, xarajat. Yakuniy loyiha shu yerda |
| **Jami** | **15** | | **55–56 kun (taxminan 11 hafta)** | |

Muhim izohlar:
- Bir mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz mavzuni o'z so'zingiz bilan tushuntira olasiz.
- I va II bosqichdan keyin (taxminan 5–6 hafta) tayyor klasterda ilovani mustaqil deploy qilib, nosozlikni debug qila olasiz. Bu ilova dasturchisi uchun yetarli daraja.
- III va IV bosqich klasterni ekspluatatsiya qilish darajasi: yetkazib berish zanjiri, bardoshlilik, xavfsizlik, xarajat.
- Kubernetes tez o'zgaradi (yiliga uch minor reliz). Darslar yozilgan paytdagi joriy versiya 1.37. API versiyasi yoki loyiha holati haqida shubha bo'lsa, manba har doim kubernetes.io hujjati va `kubectl explain`.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS 18 (`amd64`), uyda macOS (Apple Silicon, `arm64`). Docker va Multipass ikkalasida `SETUP.md` bo'yicha o'rnatilgan. Har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.

| Muhit | Zorin (ofis) | macOS (uy) | Qaysi darslarda |
|-------|--------------|------------|-----------------|
| kind klasteri (node'lar Docker konteyneri) | host'dagi Docker Engine'da, host kernel'ida, `amd64` | Docker Desktop'ning yashirin Linux VM'ida, `arm64` | deyarli hamma darslar (asosiy klaster nomi `dev`) |
| Multipass VM'lar (k3s, kubeadm) | Ubuntu 24.04, `x86_64` | Ubuntu 24.04, `aarch64` | 2-dars, kerak bo'lganda 11 va 12-darslar |

- **Asboblar** (faqat foydalanuvchi darajasidagi binary'lar): `kubectl`, `kind` (1-dars), `minikube` (2-dars), `helm` (8-dars), `cloud-provider-kind` (3 va 6-darslar), keyingi darslarda `argocd`, `flux` kabi CLI'lar. Zorin'da rasmiy `linux-amd64` binary `~/.local/bin` ga `sudo` siz, macOS'da Homebrew orqali. Har darsda o'rnatish ikki shaklda yozilgan.
- **Node va LoadBalancer IP'lari**: Zorin'da kind node'larining `172.18.0.x` IP'lari va LoadBalancer IP'lari host'dan to'g'ridan-to'g'ri ochiladi. macOS'da ular Docker Desktop VM'i ichida, Mac'dan ko'rinmaydi. API server ikkalasida `https://127.0.0.1:<port>` orqali ishlaydi. Service'ga Mac'dan ikki yo'l bilan boriladi: `docker run --rm --network kind curlimages/curl:<tag> ...` (ikkala mashinada bir xil) yoki `cloud-provider-kind` port mapping (3 va 6-darslar).
- **`cloud-provider-kind`**: Zorin'da foydalanuvchi `docker` guruhida bo'lsa `sudo` siz ishlaydi, ruxsat xatosi chiqsa `sudo` bilan. macOS'da loyiha hujjati bo'yicha `sudo cloud-provider-kind --enable-lb-port-mapping` (3-dars, Laboratoriya jadvali).
- **Arxitektura**: ishlatiladigan image'lar multi-arch (`amd64` va `arm64`) bo'lishi kerak. Ishonch bo'lmasa `docker buildx imagetools inspect <image>:<tag>` bilan tekshiriladi; `arm64` versiyasi bo'lmagan image uchun dars muqobil beradi. `latest` tag ishlatilmaydi.
- **Multipass VM'lar**: paket, sysctl, kernel modul va systemd unit'ni o'zgartiradigan hamma narsa (k3s, kubeadm, containerd sozlash) faqat VM ichida, host'da emas. `lab` VM bu modulda ishlatilmaydi, xotirani bo'shatish uchun `multipass stop lab`. Zorin'da Docker va Multipass bitta host'da: VM'lar internetga chiqmasa, sababi Docker'ning iptables `FORWARD` qoidalari bo'lishi mumkin (2-dars, Tuzoqlar).
- **Resurs**: kind `dev` klasteri (1 control-plane + 2 worker) uchun 8 GB RAM yetarli; uchta Multipass VM uchun qo'shimcha 6–8 GB; 11-darsdagi uch control-plane'li klaster 4–5 GB. macOS'da Docker Desktop'ga ajratilgan xotira chegarasi bor (`docker info` dagi `Total Memory`). Klasterlarni bir vaqtda emas, ketma-ket ishlating.
- **Ikkinchi mashinada tiklash**: klasterlar, VM'lar va ulardagi holat mashinalar orasida ko'chmaydi. Ko'chadigan narsa faqat git'dagi fayllar (kind config'lari, manifestlar, values fayllari, skriptlar, README). Ikkinchi mashinada `git pull`, keyin `kind create cluster --name dev` (yoki darsdagi config bilan) va kerakli addon'larni darsdagi buyruqlar bilan qayta o'rnatish. Ko'p qadamli klaster (kubeadm, HA) kerak bo'lgan guruhni bitta mashinada boshidan oxirigacha tugatgan ma'qul.
- **Cloud**: majburiy emas. Managed klaster (EKS va boshqalar) va ommaviy Let's Encrypt sertifikati ixtiyoriy vazifalar; bajarilsa budget alert, eng kichik resurs, shu kunning o'zida o'chirish va o'chirilganini tekshirish shart.
- **Maxfiy ma'lumot**: kubeconfig, join token, Secret manifesti, yopiq kalit va sertifikatlar ish papkasiga yozilmaydi va commit qilinmaydi. Secret qiymatlari fayldan yoki stdin'dan beriladi, shell history'ga yozilmaydi.
- **Tozalash**: har dars oxirida yaratilgan klaster, VM va namespace'lar o'chiriladi va tekshiriladi (`kind get clusters`, `multipass list`, `kubectl get ns`). Ikkala mashinada boshqa loyihalarning konteynerlari bor: `docker system prune` ishlatilmaydi.

## I bosqich - Asoslar va klaster
1. **Kubernetes'ga kirish**: nima uchun kerak, arxitektura (API server, etcd, scheduler, controller manager, kubelet, kube-proxy, container runtime), deklarativ model va reconciliation loop, obyektlar va YAML anatomiyasi (`apiVersion`, `kind`, `metadata`, `spec`, `status`), `kubectl` asoslari, kubeconfig va context, namespace, label va selector
2. **Klaster o'rnatish, single node va multi node**: kind (bir va ko'p node), minikube, Multipass VM'larda k3s, kubeadm bilan qo'lda multi-node o'rnatish, CNI tanlash, managed klasterlar (EKS, GKE, AKS) sharhi, klaster sog'ligini tekshirish, kubeconfig'larni birlashtirish
3. **Birinchi ilova, nginx**: imperativ va deklarativ yo'l, Deployment + Service + `port-forward`, `kubectl apply`, `diff`, `describe`, `logs`, `exec`, rollout va rollback, ConfigMap bilan nginx konfiguratsiyasi, Ingress va uning ekotizimi (ingress-nginx to'xtatilishi, Gateway API), buzilgan deploy'ni debug qilish (`ImagePullBackOff`, `CrashLoopBackOff`, `Pending`)

## II bosqich - Workload, tarmoq, storage, TLS
4. **Workload turlari**: Pod hayot sikli va to'xtash ketma-ketligi, init va sidecar container, liveness, readiness va startup probe, requests, limits va QoS, ReplicaSet egaligi, Deployment strategiyalari (`maxSurge`, `maxUnavailable`), DaemonSet, StatefulSet asoslari, ConfigMap va Secret'ni iste'mol qilish
5. **Job va CronJob**: `completions`, `parallelism`, `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`, Indexed Job, `restartPolicy`, CronJob jadvali, `timeZone`, `concurrencyPolicy`, `startingDeadlineSeconds`, idempotent ish dizayni, ma'lumotlar bazasi zaxirasi CronJob'i
6. **Service turlari**: ClusterIP, NodePort, LoadBalancer, ExternalName, kube-proxy mexanizmi, EndpointSlice, klaster DNS, headless Service, bulutsiz muhitda LoadBalancer (cloud-provider-kind, MetalLB), session affinity, `externalTrafficPolicy`, Ingress va Gateway API, ulanishni qatlamma-qatlam debug qilish
7. **Storage**: `emptyDir`, `hostPath`, PV, PVC, StorageClass, statik va dinamik provisioning, access mode, reclaim policy, `volumeBindingMode`, kengaytirish, CSI arxitekturasi, local-path provisioner
8. **Sertifikatlarni boshqarish, cert-manager**: Helm asoslari (chart, release, values, upgrade, rollback), Issuer va ClusterIssuer, selfSigned va CA issuer, ACME HTTP-01 va DNS-01, Certificate obyekti, Ingress annotation'lari, yangilanish, Order va Challenge orqali muammo qidirish

## III bosqich - Yetkazib berish
9. **CI/CD bilan integratsiya**: commit'dan pod'gacha zanjir, image tag va digest, Kustomize va Helm chart, CI'da manifest validatsiyasi, pipeline'ning klasterga kirishi (ServiceAccount, RBAC, OIDC), rollout gate, push-based deploy chegaralari
10. **GitOps, Argo CD va Flux**: GitOps tamoyillari, Argo CD, Flux, git'da secret muammosi, repo tuzilishi, ikki asbobni solishtirish

## IV bosqich - Production
11. **Production High Availability**: uzilish turlari, control plane HA, pod anti-affinity va topology spread, PodDisruptionBudget va drain, node o'chganda nima bo'ladi, PriorityClass, graceful shutdown
12. **Stateful workload'lar**: StatefulSet chuqur, operator'lar (PostgreSQL misolida), VolumeSnapshot, zaxira strategiyasi, taint va toleration, ajratilgan node'lar
13. **Xavfsizlik**: Secret boshqaruvi, RBAC, NetworkPolicy, Pod Security, image va supply chain, audit
14. **Autoscaling**: metrics-server, HPA, VPA, Cluster Autoscaler va node autoscaling, KEDA, yuk sinovi
15. **Xarajatni optimallashtirish va yakuniy loyiha**: xarajat manbalari, right-sizing, ResourceQuota va LimitRange, OpenCost, arzon compute, FinOps asoslari; yakuniy loyiha butun modulni birlashtiradi

## Yakuniy natija

Modul oxirida siz:
- Kubernetes arxitekturasini va so'rovning `kubectl` dan konteynergacha yo'lini tushuntira olasiz;
- klasterni kind, k3s va kubeadm bilan qura olasiz, managed klasterda nima sizning zimmangizda ekanini bilasiz;
- ilovani production talablariga mos manifestlar bilan deploy qilasiz: probe, resurslar, graceful shutdown, zero-downtime rollout;
- Service, DNS, Gateway va storage muammolarini qatlamma-qatlam debug qilasiz;
- TLS sertifikatlarini cert-manager bilan avtomatlashtirasiz, addon'larni Helm bilan boshqarasiz;
- CI/CD pipeline va GitOps orqali yetkazib berishni yo'lga qo'yasiz;
- bardoshlilik (anti-affinity, PDB), stateful workload'lar, RBAC va NetworkPolicy, autoscaling va xarajat nazoratini amalda qo'llaysiz.

Bu daraja CKA va CKAD imtihonlari mavzularining asosiy qismini qoplaydi, lekin modul imtihonga emas, ekspluatatsiya ko'nikmasiga qaratilgan.

## Ataylab kiritilmagan

Service mesh (Istio, Linkerd), o'z operator'ingizni yozish (controller-runtime, kubebuilder: bu Go rejasida), multi-cluster va federation, Windows node'lar, klasterni versiyadan versiyaga yangilash amaliyoti (faqat tushuncha darajasida), etcd'ni chuqur administratsiya qilish, eBPF ichki tuzilishi, Kubernetes'ni noldan qo'lda yig'ish ("the hard way"), cloud provayderga xos chuqur sozlamalar (EKS add-on'lar, IAM integratsiyasi nozikliklari). Kerak bo'lsa alohida so'rang.

## Manbalar

- Lukša, "Kubernetes in Action" (2-nashr): I va II bosqich uchun asosiy kitob
- Burns, Beda, Hightower, Evenson, "Kubernetes: Up and Running" (3-nashr): tez umumiy sharh
- Rice, "Container Security": 13-dars uchun
- Ibryam, Huß, "Kubernetes Patterns" (2-nashr): II va IV bosqich, dizayn naqshlari
- kubernetes.io/docs: Concepts va Tasks bo'limlari, har dars oxiridagi havolalar
- kubernetes.io/blog va har reliz uchun release notes: API o'zgarishlari va loyihalar holati
- gateway-api.sigs.k8s.io, helm.sh/docs, cert-manager.io/docs, kind.sigs.k8s.io, docs.k3s.io
- Kubernetes Failure Stories (k8s.af): production'dagi haqiqiy nosozliklar tahlili
