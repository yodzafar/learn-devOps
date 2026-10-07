# 2-dars: Klaster o'rnatish, single node va multi node

Maqsad: Kubernetes klasterini turli usullar bilan o'zingiz qurish va har usul qachon mos kelishini tushunish. Usullar to'rt xil: kind va minikube (lokal ishlab chiqish uchun), k3s (yengil, lekin haqiqiy multi-node), kubeadm (Kubernetes loyihasining standart "qo'lda" o'rnatish vositasi) va managed xizmatlar (EKS, GKE, AKS). 1-darsda tayyor kind klasterini ichidan ko'rdingiz: API server, etcd, scheduler, kubelet. Bu darsda o'sha komponentlarni o'zingiz ishga tushirasiz va shu orqali uchta narsani qo'lda ko'rasiz: control plane qanday paydo bo'ladi, yangi node klasterga qanday qo'shiladi va CNI (pod tarmog'ini quradigan plugin) o'rnatilmaguncha klaster nima uchun ishlamaydi. Keyingi darslar asosan kind'da o'tadi, lekin 11-dars (high availability) va production'dagi nosozliklarni tushunish uchun kubeadm tajribasi kerak.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun Laboratoriya, 1–3 bo'limlar va A, B guruhlar (kind va minikube tez o'tadi). Ikkinchi kun 4-bo'lim va C guruh (k3s). Uchinchi kun 5–6 bo'limlar va D guruh (kubeadm): `kubeadm init` chiqishini qatorma-qator o'qing, CNI o'rnatilguncha node nima uchun `NotReady` ekanini, join token nima ekanini tushuning. To'rtinchi kun 7–9 bo'limlar, "Birga bajaramiz" va E guruh. Diqqatni quyidagilarga qarating: "node" har usulda aslida nima (konteyner, VM, cloud VM), klasterni kim yig'adi va kim nimani o'rnatmaydi, `Ready` holati nimani kafolatlaydi va nimani kafolatlamaydi, kubeconfig va token nima uchun parol bilan teng.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib, chiqishni darsdagi qatorma-qator izoh bilan solishtiring. IP, versiya, token, hash va vaqtlar sizda boshqacha bo'ladi, darsda bunday joylar `<...>` bilan belgilangan. Misollar ataylab vazifalardagidan boshqa nomlar (`walk`, `demo`) ustida, vazifaga o'zingiz moslaysiz. Har bo'lim oxiridagi "Nima uchun shunday" qismi usulning tarixi va muqobilini beradi, uni o'tkazib yubormang: aynan shu qism "qaysi birini tanlayman" degan savolga javob beradi.

## Laboratoriya

Ikki muhit bor:

| Muhit | Nima ishlaydi | Vazifalar |
|-------|---------------|-----------|
| Host'dagi Docker | kind va minikube klasterlari (node'lar Docker konteyneri) | A, B, E guruhlar |
| Multipass VM'lar | k3s va kubeadm klasterlari (node'lar haqiqiy Ubuntu 24.04 VM) | C, D guruhlar |

k3s va kubeadm o'rnatish paket qo'shadi, sysctl va kernel modullarini o'zgartiradi, systemd unit yaratadi. Shuning uchun ular host'da emas, faqat Multipass VM'lar ichida bajariladi (CLAUDE.md, "Laboratoriya xavfsizligi"). SETUP.md dagi `lab` VM bu darsda ishlatilmaydi, xotirani bo'shatish uchun uni to'xtating: `multipass stop lab`.

**Asboblar.** `kubectl` va `kind` 1-darsda o'rnatilgan (`kubectl version --client`, `kind version` bilan tekshiring). Yangilari: `minikube` va Multipass (Multipass SETUP.md bo'yicha allaqachon bor).

Zorin (`amd64`, `sudo` siz, `~/.local/bin` ga):

```
# minikube: replace <version> with the current tag from https://github.com/kubernetes/minikube/releases
curl -LO https://github.com/kubernetes/minikube/releases/download/<version>/minikube-linux-amd64
install -m 0755 minikube-linux-amd64 ~/.local/bin/minikube && rm minikube-linux-amd64
minikube version
```

macOS (`arm64`, Homebrew):

```
brew install minikube
minikube version
```

**Multipass VM'lar.** Har VM bir xil buyruq bilan yaratiladi, ikkala mashinada bir xil:

```
multipass launch 24.04 --name <name> --cpus 2 --memory 2G --disk 10G
multipass list
multipass shell <name>                 # interactive shell inside the VM
multipass exec <name> -- uname -m      # one command, x86_64 on Zorin, aarch64 on the Mac
multipass delete --purge <name>        # remove completely
```

Xotira: uchta VM 6 GB oladi, ustiga host'ning o'zi. Bo'sh xotirani tekshiring: Zorin'da `free -h`, Mac'da `sysctl hw.memsize` (umumiy hajm baytda) va Activity Monitor. k3s va kubeadm klasterlarini bir vaqtda emas, ketma-ket quring: k3s'ni tugatib VM'larini o'chiring (11-vazifa oxiri), keyin kubeadm'ni boshlang. kind va minikube klasterlarini ham kerak bo'lmaganda o'chirib turing.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Docker host kernel'ida, `amd64`. kind node konteynerlarining IP'lari (`172.18.0.x`) host'dan to'g'ridan-to'g'ri ko'rinadi. Multipass VM'lari `10.` bilan boshlanadigan bridge tarmog'ida, host'dan ham, bir-biridan ham yetib boriladi. Docker va Multipass bitta host'da: VM'lar internetga chiqmasa, sababi Docker'ning iptables `FORWARD` qoidalari bo'lishi mumkin (Tuzoqlar bo'limi). `minikube` release binary sifatida `~/.local/bin` da. |
| macOS (uy) | Docker Desktop'ning yashirin Linux VM'ida, `arm64`. kind node'larining `172.18.0.x` IP'lari Mac'dan ko'rinmaydi, API server'ga faqat `127.0.0.1:<port>` orqali ulanasiz (kind buni o'zi sozlaydi). kind node'idagi `KERNEL-VERSION` Mac'niki emas, Docker Desktop VM'iniki. Multipass VM'lari odatda `192.168.64.x` tarmog'ida, Mac'dan va bir-biridan yetib boriladi, ichida `aarch64`. `minikube` Homebrew'dan. |

kind, k3s va kubeadm `arm64` ni rasman qo'llab-quvvatlaydi: `kindest/node` image'i, k3s binary'si, `pkgs.k8s.io` dagi deb paketlar va Flannel image'lari ikkala arxitektura uchun chiqadi. Shuning uchun buyruqlar ikkala mashinada bir xil.

**Ikkinchi mashinada tiklash.** Klasterlar va VM'lar mashinalar orasida ko'chmaydi: ofisda qurilgan k3s klasteri uyda yo'q. Ko'chadigan narsa faqat git'dagi fayllar (`kind-multi.yaml`, `cluster-health.sh`, README). Tavsiya: bitta guruhni (masalan C yoki D) bitta mashinada boshidan oxirigacha tugating, chunki kubeadm klasterini qayta qurish 30–40 daqiqa oladi. Ikkinchi mashinada kerak bo'lsa: `git pull`, keyin kind klasterlari `kind create cluster --config ...` bilan, VM'lar yuqoridagi `multipass launch` bilan noldan yaratiladi. Keyingi darslar uchun ikkala mashinada kind `dev` klasteri bo'lishi kerak: `kind create cluster --name dev`.

**Tozalash** (dars oxirida, 21-vazifa): har VM uchun `multipass delete --purge <name>`, `kind delete cluster --name <name>`, `minikube delete --all`. Managed klaster (EKS va boshqalar) bu darsda yaratilmaydi. Ixtiyoriy sinab ko'rsangiz, cloud qoidalari amal qiladi: budget alert, eng kichik node, shu kunning o'zida o'chirish va o'chirilganini tekshirish.

---

## 1. Klaster qurish nima degani: usullar xaritasi

### Bu nima

1-darsdan eslang: klaster ikki qismdan iborat, control plane (API server, etcd, scheduler, controller-manager) va node'lar (kubelet, container runtime, kube-proxy). "Klaster o'rnatish" (bootstrap) shu komponentlarni ishga tushirib, bir-biriga ishonadigan qilib bog'lash degani. Har usul quyidagi ishlarni boshqacha taqsimlaydi:

1. Mashinani tayyorlash: kernel sozlamalari, container runtime.
2. Sertifikatlar: komponentlar bir-birini TLS orqali taniydi, ularga umumiy CA (sertifikat beruvchi markaz) kerak.
3. Control plane'ni ishga tushirish.
4. Node'larni qo'shish: yangi kubelet API server'ga o'zini tanishtirishi kerak.
5. Addon'lar: CNI (pod tarmog'i), CoreDNS (klaster DNS), kube-proxy.
6. kubeconfig berish: siz `kubectl` bilan kira olishingiz uchun.

| Usul | Node nima | Qachon ishlatiladi | Cheklovi |
|------|-----------|--------------------|----------|
| kind | Docker konteyneri | lokal ishlab chiqish, CI'da test klaster | production emas, hamma node bitta host'da, bitta kernel |
| minikube | VM yoki konteyner (driver'ga qarab) | lokal o'rganish, addon'lar bilan tez sinov | production emas |
| k3s | istalgan Linux host | edge, kichik server, homelab, CI, yengil production | ba'zi komponentlar standartdan farq qiladi |
| kubeadm | istalgan Linux host | o'z serverlarida standart klaster | hammasini o'zingiz boshqarasiz: yangilash, etcd, sertifikatlar |
| EKS, GKE, AKS | cloud VM'lar | cloud'dagi production | pullik, cloud provayderga bog'lanish |

### Mexanizm: kim nimani qiladi

| Ish | kind | minikube | k3s | kubeadm | Managed |
|-----|------|----------|-----|---------|---------|
| Mashina tayyorlash | node image ichida tayyor | driver qiladi | install skript | siz | provayder (node image) |
| Sertifikatlar | ichkaridagi kubeadm | o'zi | o'zi | kubeadm | provayder |
| Control plane | ichkaridagi kubeadm | o'zi | bitta jarayon | kubeadm, static pod'lar | provayder, sizga ko'rinmaydi |
| CNI | kindnet | o'zi tanlaydi | Flannel ichida | **siz** | provayder CNI'si |
| kubeconfig | `~/.kube/config` ga yozadi | `~/.kube/config` ga yozadi | VM ichidagi faylda | VM ichidagi faylda | CLI orqali olinadi |

Jadvaldagi asosiy kuzatuv: kind ichida aslida kubeadm ishlaydi. Ya'ni kubeadm'ni tushunsangiz, kind ham, ko'p on-premise yechimlar ham ochiq kitob bo'ladi.

### Real ishda qachon kerak

- Lokal ishlab chiqish va CI testlari: kind (tez, bir buyruq, iz qoldirmaydi).
- Kichik server, Raspberry Pi, do'kon yoki zavoddagi edge qurilma: k3s.
- O'z data center'ingiz yoki to'liq nazorat kerak bo'lganda: kubeadm (yoki uning ustiga qurilgan vosita).
- Cloud'dagi production: managed. Control plane'ni o'zingiz boshqarishga aniq sabab bo'lmasa, production'da managed tanlanadi. Lekin managed klasterda ham node'lar, tarmoq va workload'lar muammosi sizniki, shuning uchun ichki tuzilishni bilish shart.

### Nima uchun shunday

Kubernetes loyihasi ataylab "to'liq distributiv" emas, qurilish bloklari to'plami sifatida chiqadi: runtime, CNI, storage interfeys orqali almashtiriladi (CRI, CNI, CSI). Bu moslashuvchanlik beradi, lekin kimdir bloklarni yig'ishi kerak. Shu sababli bootstrap vositalari ko'p: har biri "kim yig'adi" degan savolga boshqacha javob beradi. Muqobil yondashuv (Docker Swarm, docker moduli 5-dars) hammasini bitta Engine ichiga qo'ygan: o'rnatish oson, lekin almashtirib bo'lmaydi.

## 2. kind

### Bu nima

kind (Kubernetes IN Docker) har node'ni bitta Docker konteyneri sifatida ishga tushiradi. Konteyner ichida systemd, containerd va kubelet ishlaydi, klaster esa ichkarida kubeadm bilan yig'iladi. Ya'ni kind bu "konteyner ichidagi kubeadm klasteri". Loyiha asli Kubernetes'ning o'zini test qilish uchun yaratilgan.

### Mexanizm

1. kind `kindest/node:<tag>` image'idan konteyner yaratadi. Image ichida Kubernetes binary'lari, containerd va kerakli image'lar oldindan joylashgan. Tag Kubernetes versiyasini belgilaydi.
2. Konteyner `--privileged` rejimda ishlaydi (izolyatsiya deyarli yo'q, docker moduli 1-dars), chunki ichidagi containerd o'z konteynerlarini yaratishi, cgroup va tarmoq sozlashi kerak.
3. Control plane konteynerida `kubeadm init`, worker'larda `kubeadm join` bajariladi.
4. kind o'zining CNI'si (kindnet) va local-path storage provisioner'ini o'rnatadi.
5. API server porti (6443) host'ning `127.0.0.1:<tasodifiy port>` ga publish qilinadi va bu manzil `~/.kube/config` ga `kind-<name>` context'i bilan yoziladi.

Node konteynerlari host kernel'ini ishlatadi (Mac'da Docker Desktop VM kernel'ini). Barcha node'lar bitta kernel'da, shuning uchun kernel darajasidagi nosozlikni (masalan node'ning o'zi o'lishi) kind bilan to'liq taqlid qilib bo'lmaydi.

### Misol

Multi-node klaster konfiguratsiya fayli bilan yaratiladi:

```yaml
# kind-demo.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
```

```
$ kind create cluster --name demo --config kind-demo.yaml
Creating cluster "demo" ...
 ✓ Ensuring node image (kindest/node:<tag>)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing CNI
 ✓ Installing StorageClass
 ✓ Joining worker nodes
Set kubectl context to "kind-demo"
...
```

(kind chiqishida emoji'lar ham bor, bu yerda olib tashlangan.) Qatorlar 1-bo'limdagi bootstrap qadamlariga mos: image tekshiriladi (birinchi marta 1 GB atrofida yuklanadi), node konteynerlari yaratiladi, kubeadm konfiguratsiyasi yoziladi, control plane `kubeadm init` bilan ko'tariladi, CNI va StorageClass o'rnatiladi, worker'lar `kubeadm join` qiladi. Oxirgi qator: `kubectl` endi shu klasterga qaraydi.

```
$ docker ps --filter name=demo --format '{{.Names}}\t{{.Ports}}'
demo-control-plane	127.0.0.1:<port>->6443/tcp
demo-worker
```

Ikkita konteyner, nomi `<cluster>-<role>`. Faqat control plane'da port bor: bu API server, `kubectl` shu manzilga boradi. Worker ikkinchisi bo'lsa `demo-worker2` deb nomlanadi.

Muhim imkoniyatlar:

- **Node image**: Kubernetes versiyasi `--image kindest/node:<tag>` bilan tanlanadi. Har kind relizi uchun mos tag'lar release notes'da `@sha256:` digest bilan beriladi. Digest bu image tarkibining hash'i: tag ko'chirilishi mumkin, digest o'zgarmaydi. `package-lock.json` dagi `integrity` maydoni bilan o'xshashlik haqiqiy: ikkalasi ham "aynan shu baytlar" degan kafolat.
- **Lokal image yuklash**: node'lar host'dagi Docker image'larini ko'rmaydi, ularning o'z containerd'i bor. `kind load docker-image <image>:<tag> --name <cluster>` image'ni barcha node'larga ko'chiradi.
- **Port mapping**: `extraPortMappings` node konteyneri portini host portiga ulaydi (NodePort Service'lar uchun, 6-dars).

**Tuzoq: `kind load` va `imagePullPolicy`.** `imagePullPolicy` kubelet image'ni qachon registry'dan tortishini belgilaydi. Image tag'i `latest` bo'lsa yoki tag ko'rsatilmasa, u standart holatda `Always` bo'ladi va kubelet yuklangan lokal image o'rniga registry'ga murojaat qiladi, natija `ErrImagePull`. Lokal image'ga aniq tag bering.

### Real ishda qachon kerak

- CI'da Helm chart yoki operator'ni haqiqiy API server'ga qarshi test qilish: har job o'z klasterini yaratib o'chiradi.
- Lokal ishlab chiqish: manifestlarni production'ga yuborishdan oldin sinash.
- Kubernetes versiyasini yangilashdan oldin ilovani yangi versiyada tekshirish (node image tag'ini almashtirib).

### Nima uchun shunday

VM o'rniga konteyner tanlangani tezlik uchun: klaster bir daqiqada ko'tariladi va bir buyruqda iz qoldirmay o'chadi. Narxi: izolyatsiya yo'q (privileged), barcha node bitta kernel'da, LoadBalancer va haqiqiy disk yo'q. Muqobili minikube (VM driver bilan haqiqiyroq izolyatsiya) va k3d (k3s'ni Docker ichida ishlatadi).

## 3. minikube

### Bu nima

minikube ham lokal klaster, lekin node qanday yaratilishini "driver" belgilaydi: Docker konteyneri, KVM yoki QEMU VM va boshqalar. Bundan tashqari tayyor addon'lar to'plami bor: dashboard, metrics-server, ingress va boshqalarni bitta buyruq bilan yoqish mumkin.

### Mexanizm

Har klaster minikube'da "profile" deyiladi: nomlangan klaster va uning sozlamalari (`~/.minikube/profiles/` da). Standart profile nomi `minikube`, `-p <name>` bilan boshqasini yaratasiz. Context nomi profile nomi bilan bir xil. `--driver=docker` da minikube kind'ga o'xshab node'ni konteyner qiladi, shuning uchun ikkala mashinada ishlaydi.

### Misol

```
$ minikube start --driver=docker -p demo
* [demo] minikube <version> on <OS>
* Using the docker driver based on user configuration
...
* Done! kubectl is now configured to use "demo" cluster and "default" namespace by default
$ minikube profile list
```

Birinchi qator: qaysi profile va qaysi OS'da. Ikkinchisi: driver tanlovi. Oxirgisi: `~/.kube/config` dagi joriy context `demo` ga o'tdi. `minikube profile list` barcha profile'lar, driver'i, IP'si, Kubernetes versiyasi va holatini jadval qilib chiqaradi.

```
minikube start --driver=docker --nodes 2 -p two   # separate profile, two nodes
minikube addons list -p demo
minikube stop -p demo
minikube delete --all
```

### Real ishda qachon kerak

kind bilan farqi: kind tezroq va CI'ga qulay, konfiguratsiyasi fayl orqali; minikube'da addon'lar bitta buyruq bilan yoqiladi va VM driver'lari bor. Bu kursda asosiy vosita kind, minikube'ni bilish yetarli: ko'p qo'llanma va jamoalarning README'lari minikube'ga tayanadi.

### Nima uchun shunday

minikube kind'dan oldin paydo bo'lgan va boshida faqat VM ishlatgan: o'sha paytda "lokal Kubernetes" VM'siz tasavvur qilinmagan. Docker driver keyin qo'shilgan. Addon'lar g'oyasi o'rganuvchi uchun qulaylikdan kelib chiqqan, lekin production'ga ko'chmaydi: haqiqiy klasterda addon'lar Helm yoki manifest bilan o'rnatiladi (8-dars).

## 4. k3s, Multipass VM'larda

### Bu nima

k3s bu CNCF sertifikatidan o'tgan Kubernetes distributivi, bitta binary ko'rinishida. "Sertifikatlangan" degani: standart conformance testlaridan o'tadi, ya'ni oddiy manifestlar unda o'zgarishsiz ishlaydi. Distributiv bu Kubernetes'ning o'zi plyus tanlangan qo'shimchalar, birga sinovdan o'tkazilgan to'plam (Linux distributivi Ubuntu kabi).

Multipass VM bu yerda "haqiqiy" node rolini o'ynaydi: o'z kernel'i, o'z systemd'si, o'z tarmoq interfeysi bor. kind node'i esa host kernel'idagi konteyner.

### Mexanizm

- Control plane komponentlari (API server, scheduler, controller-manager) alohida jarayon emas, bitta `k3s server` jarayoni ichida ishlaydi.
- Standart holatda etcd o'rniga SQLite ishlatiladi (kine qatlami orqali); HA uchun embedded etcd yoqiladi.
- Ichida tayyor keladi: containerd, Flannel (CNI), CoreDNS, Traefik (ingress controller), ServiceLB (LoadBalancer), local-path provisioner (storage), metrics-server. Keraksizlari server'ning `--disable` flag'i bilan o'chiriladi.
- Terminologiya: control plane node'i `server`, worker node'i `agent`. Agent server'ga `K3S_URL` va `K3S_TOKEN` bilan ulanadi.

### Misol: server

Install skript `https://get.k3s.io` binary'ni yuklaydi va systemd unit yaratadi. Versiyani qotirish uchun `INSTALL_K3S_VERSION` (qiymat https://github.com/k3s-io/k3s/releases dan):

```
$ curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> sh -
[INFO]  Using <version> as release
[INFO]  Downloading hash https://github.com/k3s-io/k3s/releases/download/<version>/sha256sum-<arch>.txt
[INFO]  Downloading binary https://github.com/k3s-io/k3s/releases/download/<version>/k3s<suffix>
[INFO]  Verifying binary download
[INFO]  Installing k3s to /usr/local/bin/k3s
[INFO]  Creating /usr/local/bin/kubectl symlink to k3s
[INFO]  Creating /usr/local/bin/crictl symlink to k3s
[INFO]  Creating /usr/local/bin/ctr symlink to k3s
[INFO]  Creating killall script /usr/local/bin/k3s-killall.sh
[INFO]  Creating uninstall script /usr/local/bin/k3s-uninstall.sh
[INFO]  systemd: Creating service file /etc/systemd/system/k3s.service
[INFO]  systemd: Enabling k3s unit
[INFO]  systemd: Starting k3s
```

Qatorma-qator: skript versiyani aniqladi; checksum faylini va arxitekturaga mos binary'ni yukladi (`<arch>` Zorin VM'ida `amd64`, Mac VM'ida `arm64`); hash'ni tekshirdi; binary'ni `/usr/local/bin/k3s` ga qo'ydi. Keyingi uch qator muhim: `kubectl`, `crictl`, `ctr` alohida dastur emas, `k3s` ga symlink. Binary qaysi nom bilan chaqirilganiga qarab o'zini o'sha dastur sifatida tutadi. So'ng tozalash skriptlari va systemd unit yaratildi va ishga tushirildi (systemd, linux moduli).

```
$ sudo k3s kubectl get nodes
NAME         STATUS   ROLES           AGE   VERSION
demo-srv     Ready    control-plane   40s   <version>
```

Node nomi VM hostname'i. `ROLES` k3s versiyasiga qarab `control-plane,master` ham bo'lishi mumkin. Join uchun token server'da:

```
sudo cat /var/lib/rancher/k3s/server/node-token
```

Agent'ni qo'shish (har agent VM ichida, `<server-ip>` va `<token>` o'rniga haqiqiy qiymatlar; token'ni terminal tarixiga tushirmaslik uchun uni VM ichida o'zgaruvchiga o'qish yaxshiroq):

```
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<token> sh -
```

kubeconfig server'da `/etc/rancher/k3s/k3s.yaml` da turadi, faqat root o'qiy oladi, ichidagi manzil `https://127.0.0.1:6443`. Host'dan ulanish uchun faylni host'ga olib, manzilni VM IP'siga almashtirasiz (`multipass info <name>` IP'ni ko'rsatadi). Root'ga tegishli faylni `multipass transfer` o'qiy olmaydi; `multipass exec <name> -- sudo cat <file>` chiqishini host'dagi faylga yo'naltirish mumkin. Manzilni almashtirishda esda tuting: Zorin'da `sed -i`, Mac'da `sed -i ''` (BSD sed).

**Tuzoq: `curl | sh`.** Internetdan skriptni to'g'ridan-to'g'ri root sifatida ishlatish laboratoriya VM'ida maqbul. Production'da skriptni avval yuklab o'qing yoki versiyasi qotirilgan paket va konfiguratsiya boshqaruvi (Ansible) ishlating. Node'dagi `npx <paket>` yoki `postinstall` skripti bilan o'xshashlik haqiqiy: begona kod sizning huquqlaringiz bilan ishlaydi.

**Tuzoq: node token.** Token bilan istalgan mashina klasterga node sifatida qo'shila oladi. U secret: README'ga yozilmaydi, commit qilinmaydi.

### Real ishda qachon kerak

- 1–2 GB RAM'li kichik server yoki edge qurilma: standart kubeadm klasteri uchun resurs yetmaydi.
- Homelab va CI: haqiqiy multi-node, lekin bitta buyruq bilan.
- Bir xil konfiguratsiyali ko'p kichik klaster (do'konlar tarmog'i): bitta binary va bitta unit yangilash oson.

### Nima uchun shunday

Standart Kubernetes'da har komponent alohida binary va alohida jarayon, bu kengaytirish va mustaqil yangilash uchun qulay, lekin xotira va boshqaruv narxi bor. k3s (Rancher, hozir SUSE) bularni bitta jarayonga birlashtirib, eski va cloud'ga xos kodni olib tashlagan. Narxi: standartdan farqlar bor (SQLite, Traefik, ServiceLB), bilmasangiz "kubeadm'da boshqacha ishladi" degan holatlar chiqadi. Muqobillari: MicroK8s (Canonical, snap paketi), k0s.

## 5. kubeadm

### Bu nima

kubeadm Kubernetes loyihasining rasmiy bootstrap vositasi. U klaster yig'adi (sertifikatlar, control plane, token, kubeconfig), lekin mashinalarni tayyorlamaydi, CNI o'rnatmaydi va infratuzilmani boshqarmaydi. kind, ko'p managed va on-premise yechimlar ichida aynan kubeadm ishlaydi.

### Mexanizm: har node'da tayyorgarlik

Rasmiy yo'riqnomalar: https://kubernetes.io/docs/setup/production-environment/container-runtimes/ va https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/. Hammasi VM ichida (Ubuntu 24.04, GNU userland):

1. **Swap**: kubelet standart holatda swap yoqilgan bo'lsa ishga tushmaydi (xotira hisobi buziladi). Multipass Ubuntu image'ida swap yo'q, `swapon --show` bo'sh chiqishi kerak.

2. **Tarmoq**: `ip_forward` kernel'ga bir interfeysdan kelgan paketni boshqasiga uzatishga ruxsat beradi (linux modulidagi tarmoq darslarini eslang). `br_netfilter` kernel moduli bridge orqali o'tgan trafikni iptables qoidalariga ko'rsatadi; Flannel kabi bridge ishlatadigan CNI'lar unga tayanadi.

```
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system
echo br_netfilter | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe br_netfilter
sysctl net.ipv4.ip_forward          # net.ipv4.ip_forward = 1
lsmod | grep br_netfilter           # one line with br_netfilter
```

`/etc/sysctl.d/` va `/etc/modules-load.d/` dagi fayllar reboot'dan keyin ham amal qiladi; `sysctl --system` va `modprobe` hozir qo'llaydi.

3. **Container runtime**: containerd o'rnatiladi va systemd cgroup driver'ga o'tkaziladi. cgroup driver bu kubelet va runtime konteynerlar uchun cgroup'larni (resurs cheklovlari, docker moduli 1-dars) qanday boshqarishi. systemd'li tizimda systemd ham cgroup boshqaradi; ikkita boshqaruvchi bo'lsa, ular bir-birining ishini ko'rmaydi. kubeadm kubelet'ni `systemd` driver bilan sozlaydi, containerd ham shunday bo'lishi shart.

```
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
grep -n SystemdCgroup /etc/containerd/config.toml
```

`grep` `SystemdCgroup = false` qatorini va uning raqamini ko'rsatadi. Bu qator runc options bo'limida turadi; bo'lim nomi containerd 1.x va 2.x da farq qiladi (`containerd --version` bilan tekshiring), shuning uchun qatorni nomi bo'yicha topib `true` ga o'zgartiring (VM ichida `sudo sed -i` yoki `sudo nano`) va `sudo systemctl restart containerd` qiling.

4. **Paketlar**: `kubelet`, `kubeadm`, `kubectl`. `pkgs.k8s.io` repozitoriysi har minor versiya uchun alohida. Quyidagi `v1.37` dars yozilgan paytdagi joriy versiya, o'rnatish sahifasidagi qiymatni oling:

```
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

`signed-by` apt'ga shu repozitoriy paketlarini faqat shu kalit bilan tekshirishni aytadi. `apt-mark hold` tasodifiy `apt upgrade` klaster versiyasini o'zgartirib yubormasligi uchun: Kubernetes faqat rejali, bittadan minor versiyaga yangilanadi. `package.json` da `^` siz aniq versiya yozish bilan o'xshash. O'rnatilgandan keyin kubelet har bir necha sekundda qayta ishga tushib turadi: u kubeadm konfiguratsiya yozishini kutyapti, bu normal.

### Misol: control plane'ni ishga tushirish

```
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

`--pod-network-cidr` pod'lar IP oladigan diapazon; uni CNI bilan kelishib tanlaysiz (6-bo'lim). Chiqishdan qisqartirilgan parcha:

```
[init] Using Kubernetes version: <version>
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
...
[kubeconfig] Writing "admin.conf" kubeconfig file
...
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
...
[bootstrap-token] Using token: <token>
...
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!
```

Har qator kvadrat qavsdagi bosqich nomi bilan boshlanadi. `[preflight]` dagi `WARNING` qatorlarini ham o'qing: ular xato emas, lekin ko'pincha keyingi muammoning sababi.

| Bosqich | Nima qiladi |
|---------|-------------|
| `preflight` | tizim talablarini tekshiradi (swap, portlar, runtime, kernel sozlamalari, CPU va xotira), image'larni oldindan tortadi |
| `certs` | klaster CA va komponent sertifikatlarini `/etc/kubernetes/pki` da yaratadi |
| `kubeconfig` | admin, kubelet, controller-manager, scheduler uchun kubeconfig fayllari `/etc/kubernetes/` da |
| `etcd`, `control-plane` | static pod manifestlarini `/etc/kubernetes/manifests` ga yozadi |
| `kubelet-start` | kubelet konfiguratsiyasini yozib uni ishga tushiradi |
| `mark-control-plane` | node'ni control plane sifatida belgilaydi (label va taint) |
| `bootstrap-token` | node'lar qo'shilishi uchun vaqtinchalik token yaratadi |
| `addons` | CoreDNS va kube-proxy'ni o'rnatadi |

**Static pod** bu API server orqali emas, kubelet to'g'ridan-to'g'ri diskdagi manifest fayldan ishga tushiradigan pod. Bu "tovuq va tuxum" muammosini yechadi: API server pod bo'lib ishlaydi, lekin uni ishga tushirish uchun API server kerak emas. kubelet `/etc/kubernetes/manifests` papkasini kuzatadi, fayl paydo bo'lsa pod ishga tushadi, fayl o'chirilsa to'xtaydi. Taint esa node'ga qo'yiladigan "bu yerga pod qo'yma" belgisi (12-darsda chuqur).

`init` oxirida kubeadm sizga kubeconfig'ni nusxalashni aytadi:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

`admin.conf` klasterga cheksiz huquq beradi (`cluster-admin`), u bilan ehtiyot bo'ling. `init` tugagach node `NotReady` holatida bo'ladi va CoreDNS pod'lari `Pending` turadi. Nima uchun ekanini 13-vazifada `kubectl describe node` dan o'zingiz topasiz.

### Misol: CNI va worker'lar

Flannel misolida (uning standart pod CIDR'i `10.244.0.0/16`, shuning uchun `init` da shu qiymat berildi). Manifest versiyasini https://github.com/flannel-io/flannel/releases dan oling, `latest` havolasini emas:

```
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/<version>/kube-flannel.yml
kubectl get nodes -w
```

Worker qo'shish: control plane'da join buyrug'ini oling va worker'da `sudo` bilan bajaring.

```
$ kubeadm token create --print-join-command        # on the control plane
kubeadm join <cp-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Chiqish uch qismdan iborat: API server manzili; `--token` (worker o'zini tanishtiradigan vaqtinchalik parol, standart holatda 24 soat yashaydi); `--discovery-token-ca-cert-hash` (klaster CA sertifikatining hash'i). Ikkinchisi worker'ning API server'ga ishonch tekshiruvi; u aynan nimadan himoya qilishini 15-vazifada yozasiz. Buyruq ham, token ham secret: README'ga `<token>` ko'rinishida yoziladi.

Node'ni tozalash: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` (pod'larni ko'chirish), `kubectl delete node <node>`, node'ning o'zida `sudo kubeadm reset`.

### Real ishda qachon kerak

- O'z serverlaringizda (on-premise) standart klaster: bank, davlat tashkiloti, cloud ishlatib bo'lmaydigan joy.
- Production nosozligini tushunish: managed klasterda ham kubelet, sertifikat va CNI muammolari xuddi shunday ko'rinadi.
- CKA imtihoni kubeadm klasterida o'tadi.

### Nima uchun shunday

kubeadm ataylab "faqat bootstrap" qilib loyihalangan: mashina tayyorlash Ansible yoki Terraform ishi, CNI esa tanlov. Shu sababli u boshqa vositalarning qurilish bloki bo'la oldi (kind, Cluster API, ko'p distributivlar). Undan oldin klaster "the hard way" usulida qo'lda yoki har kompaniyaning o'z skriptlari bilan yig'ilgan. Muqobili k3s kabi "hammasi ichida" distributivlar: tezroq, lekin kamroq tanlov.

## 6. CNI tanlash

### Bu nima

Kubernetes tarmoq modeli uch talab qo'yadi: har pod o'z IP'siga ega; barcha pod'lar bir-biriga NAT'siz (manzil almashtirmasdan) ulana oladi, hatto boshqa node'da bo'lsa ham; node'dagi agentlar o'sha node pod'lariga ulana oladi. Buni Kubernetes'ning o'zi amalga oshirmaydi, CNI (Container Network Interface) plugin bajaradi. CNI bu kubelet (runtime orqali) pod yaratilganda chaqiradigan dasturlar uchun standart interfeys.

### Mexanizm

Pod yaratilganda runtime pod uchun network namespace (alohida tarmoq steki, docker moduli 3-dars) yaratadi va CNI plugin'ni chaqiradi. Plugin pod'ga interfeys va IP beradi (har node o'z bo'lagini oladi, masalan `10.244.1.0/24`) va boshqa node'lardagi pod'larga yo'l (route) sozlaydi. Flannel buni VXLAN overlay bilan qiladi: boshqa node'ga ketayotgan paket UDP ichiga o'ralib node IP'siga yuboriladi. Plugin fayllari odatda `/etc/cni/net.d/` (konfiguratsiya) va `/opt/cni/bin/` (binary'lar) da turadi. Konfiguratsiya fayli yo'q ekan, kubelet node'ning tarmog'i tayyor emas deb hisoblaydi.

| CNI | Xususiyati | NetworkPolicy |
|-----|------------|---------------|
| Flannel | eng sodda, VXLAN overlay | yo'q |
| Calico | BGP yoki overlay, keng tarqalgan | bor |
| Cilium | eBPF asosida, kube-proxy'ni almashtira oladi, kuzatuv vositalari | bor, L7 gacha |
| Cloud CNI (AWS VPC CNI va boshqalar) | pod'lar VPC IP'sini oladi | cloud'ga qarab |

NetworkPolicy bu pod'lar orasidagi trafikni cheklovchi Kubernetes obyekti (13-dars); uni CNI bajaradi, CNI qo'llab-quvvatlamasa obyekt jimgina hech narsa qilmaydi.

### Misol

```
$ ls /etc/cni/net.d/
10-flannel.conflist
```

Bu buyruq kubeadm node'ida Flannel o'rnatilgandan keyin (VM ichida). Bitta fayl: kubelet shu fayl orqali qaysi plugin chaqirilishini biladi. Flannel o'rnatilishidan oldin papka bo'sh yoki mavjud emas. Pod CIDR'ni ko'rish: `kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'` har node'ga ajratilgan bo'lakni chiqaradi.

### Real ishda qachon kerak

Tanlov mezonlari: NetworkPolicy kerakmi (13-dars: production'da kerak), cloud bilan integratsiya, kuzatuv talablari, jamoaning ekspluatatsiya tajribasi. Pod CIDR node'lar tarmog'i, VPN yoki ofis tarmog'i bilan kesishmasligi kerak. CNI'ni ishlab turgan klasterda almashtirish og'ir operatsiya, boshida o'ylab tanlanadi.

### Nima uchun shunday

Tarmoq har muhitda boshqacha (data center, cloud, edge), shuning uchun Kubernetes uni interfeys orqali chiqarib tashlagan. "Har pod o'z IP'si, NAT yo'q" modeli Docker'ning port mapping modelidan (docker moduli 3-dars) farqli tanlangan: ilova port to'qnashuvi haqida o'ylamaydi va pod oddiy host kabi ko'rinadi. Narxi: kimdir bu yassi tarmoqni qurishi kerak, bu CNI.

## 7. Managed klasterlar

### Bu nima

Managed klasterda control plane'ni cloud provayder ishlatadi: siz API server manzilini olasiz, lekin uning VM'larini, etcd'ni ko'rmaysiz.

| | EKS (AWS) | GKE (Google Cloud) | AKS (Azure) |
|---|-----------|--------------------|-------------|
| Control plane | AWS boshqaradi | Google boshqaradi | Azure boshqaradi |
| Node'lar | managed node group, Fargate, yoki avtomatik rejim | node pool yoki Autopilot | node pool |
| CLI | `aws eks`, `eksctl` | `gcloud container` | `az aks` |
| Identity | IAM bilan integratsiya | Google IAM | Entra ID |

### Mexanizm

Provayder zimmasida: API server, etcd, ularning zaxirasi, yangilanishi va yuqori mavjudligi. Sizning zimmangizda: node'lar (yoki ularning sozlamasi), workload'lar, tarmoq siyosatlari, RBAC (kim nima qila oladi, 13-dars), addon'lar, versiya yangilash rejasi, xarajat. `kubectl` odatda statik sertifikat bilan emas, cloud CLI chiqaradigan qisqa muddatli token bilan autentifikatsiya qiladi: kubeconfig'da `exec` bo'limi cloud CLI'ni chaqiradi.

### Misol

Bu darsda managed klaster yaratilmaydi. Hujjatni o'qish yo'li (20-vazifa uchun): provayderning "pricing" sahifasi (control plane narxi), "versions" yoki "release calendar" sahifasi (qo'llab-quvvatlash muddati), "networking" bo'limi (standart CNI).

**Tuzoq: narx.** Managed klasterda odatda control plane uchun soatbay to'lov, node VM'lari, load balancer'lar, disklar va chiquvchi trafik alohida hisoblanadi. "Faqat sinab ko'rdim" degan klaster o'chirilmasa oy oxirida sezilarli hisob keladi. O'chirganda LoadBalancer Service va PVC'lar yaratgan cloud resurslari ham o'chganini tekshiring (15-dars).

### Real ishda qachon kerak

Cloud'dagi deyarli har production klaster. Kichik jamoa uchun etcd zaxirasi va control plane yangilanishini o'zi boshqarishi asoslanmagan xarajat.

### Nima uchun shunday

Control plane'ni ishlatish (etcd zaxirasi, sertifikat yangilash, uch zonada HA) har kompaniyada bir xil va zerikarli ish, provayder uni minglab klasterlar uchun bir marta avtomatlashtiradi. Narxi: vendor lock-in (identity, LoadBalancer, storage cloud'ga bog'lanadi) va provayder versiya jadvaliga bo'ysunish.

## 8. Klaster sog'ligini tekshirish

### Bu nima

Yangi klasterni "tayyor" deyishdan oldin ikki darajada tekshiriladi: komponentlar o'zini sog'lom deb biladimi (status) va klaster haqiqatan ishlaydimi (funksional sinov).

### Mexanizm

- `kubectl get nodes`: `Ready` faqat kubelet o'z node'ini sog'lom deb hisoblashini va API server'ga vaqtida xabar berib turishini anglatadi.
- `kubectl get pods -A`: control plane va addon pod'lari.
- API server'ning `/readyz` va `/livez` endpoint'lari: ichki tekshiruvlar ro'yxati (etcd'ga ulanish va boshqalar).
- Funksional sinov: pod boshqa node'dagi pod'ga ulana oladimi, DNS javob beradimi. `Ready` node'lar orasidagi pod tarmog'i ishlashini kafolatlamaydi.

### Misol

```
$ kubectl get --raw='/readyz?verbose'
[+]ping ok
[+]log ok
[+]etcd ok
[+]etcd-readiness ok
[+]informer-sync ok
...
readyz check passed
```

Har qator bitta ichki tekshiruv: `[+]` o'tdi, `[-]` o'tmadi. `etcd ok` API server ma'lumotlar bazasiga ulana olishini bildiradi. Oxirgi qator umumiy natija; tekshiruv o'tmasa API server HTTP 500 qaytaradi va `kubectl` noldan farqli exit code bilan chiqadi, bu skriptda tekshirish uchun qulay.

```
kubectl get nodes -o wide                 # all Ready, expected versions
kubectl get pods -A                       # nothing Pending or CrashLoopBackOff
kubectl cluster-info
```

Node o'chib qolganda `NotReady` bir zumda emas, controller-manager node'dan xabar kelmay qo'yganini kutgandan keyin qo'yiladi; pod'lar esa undan ham keyinroq ko'chiriladi. Bu kechikish qayerdan kelishini 11-vazifada o'zingiz topasiz.

**Tuzoq: `kubectl get componentstatuses`.** Eski qo'llanmalarda uchraydi, bu API ancha oldin deprecated qilingan. O'rniga `/readyz` va `/livez` ishlatiladi.

### Real ishda qachon kerak

Klaster yangilangandan, node qo'shilgandan, CNI o'zgartirilgandan keyin; monitoring'da (observability moduli) API server'ning `/readyz` i va node holati doimiy kuzatiladi; incident paytida birinchi qadam.

### Nima uchun shunday

`componentstatuses` API server control plane komponentlariga o'zi ulanib tekshirishiga tayangan, bu komponentlar boshqa mashinada yoki boshqa portda bo'lsa buzilardi. Har komponent o'z holatini o'zi e'lon qiladigan endpoint (`/readyz`, `/livez`) modeli soddaroq va Kubernetes'ning probe'lari (4-dars) bilan bir xil g'oya.

## 9. kubeconfig'larni birlashtirish

### Bu nima

kubeconfig (1-dars) uch ro'yxatdan iborat: `clusters` (manzil va CA), `users` (credential), `contexts` (cluster + user + namespace jufti). Har yangi klaster o'z kubeconfig'ini beradi: kind va minikube `~/.kube/config` ga qo'shadi, k3s va kubeadm esa VM ichidagi faylni beradi.

### Mexanizm

`KUBECONFIG` muhit o'zgaruvchisida `:` bilan ajratilgan bir nechta fayl bo'lsa, `kubectl` ularni xotirada birlashtiradi. `PATH` bilan o'xshashlik haqiqiy: ro'yxat chapdan o'ngga o'qiladi va bir xil nomli yozuvda birinchi uchragani yutadi. Fayllar diskda o'zgarmaydi. k3s kubeconfig'ida cluster, user va context nomi `default` bo'lgani uchun birlashtirishdan oldin nomlarni o'zgartirish kerak, aks holda yozuvlar to'qnashadi va ikkinchi fayldagi `default` jimgina yashirinadi.

### Misol

```
$ export KUBECONFIG=~/.kube/config:~/demo.yaml
$ kubectl config get-contexts
CURRENT   NAME        CLUSTER     AUTHINFO    NAMESPACE
*         kind-dev    kind-dev    kind-dev
          default     default     default
```

Ikki fayldagi context'lar bitta ro'yxatda. `CURRENT` dagi `*` joriy context (birinchi fayldagi `current-context`). `AUTHINFO` user yozuvining nomi. Ikkinchi qatordagi `default` nomi hech narsa demaydi, uni nomlash kerak:

```
kubectl config rename-context default demo-lab
kubectl config view --flatten > ~/.kube/merged    # one self-contained file
```

`export` faqat joriy terminal sessiyasiga amal qiladi (zsh'da ham, bash'da ham bir xil). Doimiy qilish uchun `~/.zshrc` yoki `~/.bashrc` ga yoziladi.

### Real ishda qachon kerak

Bir nechta klaster (dev, staging, prod) bilan ishlaganda har kuni. Eng xavfli xato noto'g'ri context'da buyruq bajarish: `kubectl config current-context` ni odat qiling, prod uchun alohida fayl va alohida terminal ishlatish mumkin.

### Nima uchun shunday

Bitta katta fayl o'rniga fayllar ro'yxati klasterlarni mustaqil qo'shish va olib tashlash imkonini beradi: klaster o'chsa uning fayli o'chadi. Muqobil vositalar (`kubectx`, `kubie`) shu mexanizm ustiga qurilgan.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Bootstrap | klaster komponentlarini noldan ishga tushirib, bir-biriga ishonadigan qilib bog'lash |
| Distributiv | Kubernetes plyus birga sinovdan o'tgan qo'shimchalar to'plami (k3s, MicroK8s) |
| kind | node'lari Docker konteyneri bo'lgan lokal klaster |
| Node image | kind node konteyneri yaratiladigan image, tag'i Kubernetes versiyasini belgilaydi |
| Digest | image tarkibining `sha256` hash'i, o'zgarmas identifikator |
| minikube profile | minikube'dagi nomlangan klaster va uning sozlamalari |
| Driver | minikube node'ni qanday yaratishi (Docker, VM) |
| k3s server, agent | k3s'dagi control plane node'i va worker node'i |
| Multipass | bitta buyruq bilan Ubuntu VM yaratadigan vosita |
| kubeadm | Kubernetes'ning rasmiy bootstrap vositasi |
| Preflight | kubeadm'ning tizim talablarini oldindan tekshirishi |
| CA | klasterdagi barcha sertifikatlarni imzolaydigan markaziy sertifikat |
| Static pod | kubelet diskdagi manifestdan to'g'ridan-to'g'ri ishga tushiradigan pod |
| Taint | node'ga qo'yiladigan "bu yerga pod qo'yma" belgisi (12-dars) |
| Bootstrap token | yangi node klasterga qo'shilish uchun ishlatadigan vaqtinchalik parol |
| CA cert hash | worker'ga API server haqiqiyligini tekshirish uchun beriladigan CA hash'i |
| cgroup driver | kubelet va runtime cgroup'larni boshqarish usuli (`systemd` yoki `cgroupfs`) |
| `ip_forward` | kernel'ning paketlarni interfeyslar orasida uzatishiga ruxsat |
| `br_netfilter` | bridge trafigini iptables'ga ko'rsatadigan kernel moduli |
| `apt-mark hold` | paketni avtomatik yangilanishdan qotirish |
| CNI | pod'ga IP va tarmoq beradigan plugin'lar uchun standart interfeys |
| Pod CIDR | pod IP'lari olinadigan manzillar diapazoni |
| Overlay, VXLAN | node'lar ustidan virtual tarmoq; paketni UDP ichiga o'rab tashish usuli |
| NetworkPolicy | pod'lar orasidagi trafikni cheklovchi obyekt, CNI bajaradi |
| Managed klaster | control plane'ni cloud provayder ishlatadigan klaster |
| `/readyz`, `/livez` | API server'ning tayyorlik va tiriklik tekshiruv endpoint'lari |
| `admin.conf` | kubeadm yaratgan cheksiz huquqli kubeconfig |
| `KUBECONFIG` | `kubectl` o'qiydigan kubeconfig fayllar ro'yxati |
| `--flatten` | kubeconfig'dagi fayl havolalarini ichiga joylab, mustaqil fayl qilish |

## Tuzoqlar

- kubelet va container runtime cgroup driver'i mos kelmasligi: kubelet ishga tushmaydi yoki node beqaror bo'ladi.
- CNI o'rnatilmagan klasterda `NotReady` node va `Pending` CoreDNS'ni "klaster buzildi" deb o'ylash. Avval CNI.
- Pod CIDR node'lar tarmog'i yoki boshqa tarmoqlar (Multipass bridge, VPN, ofis tarmog'i) bilan kesishishi: tushunarsiz ulanish xatolari.
- Join token va `admin.conf` ni ochiq joyda qoldirish. Ikkalasi ham klasterga to'liq kirish beradi. Ish papkasiga, README'ga, chat'ga yozilmaydi.
- `kubelet`, `kubeadm` paketlarini `hold` qilmaslik: oddiy `apt upgrade` klasterni yarim yangilangan holatga keltiradi.
- Bitta control plane node'li klasterni production deb hisoblash: u node o'lsa API ham, etcd ham yo'q (11-dars).
- kind yoki minikube'da ishlagan narsa production'da ham xuddi shunday ishlaydi deb o'ylash: LoadBalancer, storage va tarmoq u yerda boshqacha.
- `kind load` qilingan image'ga `latest` tag: kubelet registry'dan tortishga urinadi.
- Flannel yoki boshqa manifestni `releases/latest` havolasi bilan qo'llash: ertaga boshqa versiya keladi. Versiyani qotiring.
- Zorin'da Docker va Multipass bitta host'da: Docker `FORWARD` zanjirining standart siyosatini `DROP` qilishi mumkin va VM'lar internetga chiqa olmay qoladi (`apt-get update` osilib qoladi). Belgisi va yechimi Multipass hujjatining troubleshooting bo'limida; host firewall'ini o'zgartirishdan oldin menga yozing.
- Mac'da kind node IP'siga (`172.18.0.x`) yoki pod IP'siga host'dan ulanishga urinish: ular Docker Desktop VM'i ichida. Port mapping yoki `kubectl port-forward` (3-dars) ishlating.
- Uch VM va kind klasterini bir vaqtda yoqiq qoldirish: host xotirasi tugaydi, hammasi sekinlashadi va `NotReady` lar "o'z-o'zidan" paydo bo'ladi.
- Managed klasterni o'chirmay qoldirish yoki o'chirgandan keyin qolgan load balancer va disklarni tekshirmaslik.
- O'chirilgan klasterning context'ini kubeconfig'da qoldirish: keyinroq `kubectl` tushunarsiz timeout beradi.

## Manbalar

- https://kind.sigs.k8s.io/docs/user/quick-start/ – kind o'rnatish va asosiy buyruqlar
- https://kind.sigs.k8s.io/docs/user/configuration/ – kind konfiguratsiyasi (node'lar, label'lar, port mapping)
- https://github.com/kubernetes-sigs/kind/releases – node image tag'lari va digest'lari
- https://minikube.sigs.k8s.io/docs/start/ – minikube
- https://docs.k3s.io/quick-start – k3s tez boshlash
- https://docs.k3s.io/architecture – k3s arxitekturasi
- https://docs.k3s.io/installation/configuration – k3s install skripti va flag'lari
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/ – kubeadm o'rnatish
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/ – kubeadm bilan klaster yaratish
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/ – container runtime va cgroup driver talablari
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/ – kubeadm sertifikatlari
- https://kubernetes.io/releases/version-skew-policy/ – version skew siyosati
- https://kubernetes.io/docs/concepts/cluster-administration/networking/ – tarmoq modeli
- https://github.com/flannel-io/flannel – Flannel
- https://kubernetes.io/docs/reference/using-api/health-checks/ – `/readyz` va `/livez`
- https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/ – bir nechta klasterga kirish
- https://documentation.ubuntu.com/multipass/ – Multipass

---

## Birga bajaramiz

Bitta yaxlit misol: alohida kubeconfig faylga yoziladigan ikki node'li `walk` kind klasterini quramiz, worker'ga label beramiz, klaster sog'ligini status va funksional sinov bilan tekshiramiz, keyin o'chirib, iz qolmaganini isbotlaymiz. Bu vazifalardagi klaster ham, yechim ham emas: vazifalarda boshqa konfiguratsiya, boshqa usullar va skript kerak. Hammasi host'da, ikkala mashinada bir xil.

1. Vaqtinchalik papka (repo'dan tashqarida) va konfiguratsiya:

```
$ mkdir -p ~/k2-walk && cd ~/k2-walk
$ cat kind-walk.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  labels:
    tier: demo
```

`labels` kind'ning node konfiguratsiyasidagi maydon: node yaratilganda unga Kubernetes label'i qo'yiladi (1-dars, label va selector).

2. Klasterni asosiy `~/.kube/config` ga emas, alohida faylga yozib yarating:

```
$ kind create cluster --name walk --config kind-walk.yaml --kubeconfig ~/k2-walk/walk.kubeconfig
Creating cluster "walk" ...
...
Set kubectl context to "kind-walk"
$ export KUBECONFIG=~/k2-walk/walk.kubeconfig
$ kubectl config get-contexts
CURRENT   NAME        CLUSTER     AUTHINFO    NAMESPACE
*         kind-walk   kind-walk   kind-walk
```

`--kubeconfig` kind'ga yozish manzilini beradi. `export` dan keyin shu terminaldagi `kubectl` faqat shu faylni ko'radi, ro'yxatda bitta context. Boshqa klasterlaringizga tasodifan tegib ketish imkoni yo'q.

3. Node'lar:

```
$ kubectl get nodes -o wide -L tier
NAME                 STATUS   ROLES           AGE   VERSION     INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME    TIER
walk-control-plane   Ready    control-plane   60s   <version>   172.18.0.3    <none>        Debian GNU/Linux <n> (<name>)    <kernel>         containerd://<ver>
walk-worker          Ready    <none>          40s   <version>   172.18.0.2    <none>        Debian GNU/Linux <n> (<name>)    <kernel>         containerd://<ver>   demo
```

`-L tier` `tier` label'ini alohida ustun qiladi: u faqat worker'da. `ROLES` ustunidagi `<none>` worker'da rol label'i yo'qligini bildiradi, bu normal. `INTERNAL-IP` kind Docker tarmog'idagi manzil (Mac'da host'dan ko'rinmaydi). `OS-IMAGE` node image ichidagi distributiv, host'niki emas. `KERNEL-VERSION` esa host'niki (Zorin'da `-generic` bilan tugaydigan Ubuntu kernel'i, Mac'da Docker Desktop VM'ining `linuxkit` kernel'i): kind node'lari kernel'ni ulashadi.

4. Status darajasidagi tekshiruv:

```
$ kubectl get pods -A
NAMESPACE            NAME                                         READY   STATUS    RESTARTS   AGE
kube-system          coredns-<hash>-<id>                          1/1     Running   0          60s
kube-system          coredns-<hash>-<id>                          1/1     Running   0          60s
kube-system          etcd-walk-control-plane                      1/1     Running   0          70s
kube-system          kindnet-<id>                                 1/1     Running   0          60s
kube-system          kindnet-<id>                                 1/1     Running   0          45s
kube-system          kube-apiserver-walk-control-plane            1/1     Running   0          70s
...
local-path-storage   local-path-provisioner-<hash>-<id>           1/1     Running   0          60s
$ kubectl get --raw='/readyz' ; echo
ok
```

Nomida node nomi bor pod'lar (`etcd-walk-control-plane`, `kube-apiserver-walk-control-plane`) static pod'lar: kubelet ularga node nomini qo'shadi. `kindnet` ikkita, har node'da bittadan. Hammasi `Running` va `READY` to'liq. `?verbose` siz `/readyz` faqat `ok` qaytaradi; `echo` qator oxirini qo'shish uchun.

5. Funksional sinov: node'lar orasidagi tarmoq va DNS. Avval CoreDNS qayerda ekanini ko'ring:

```
$ kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP           NODE                 ...
coredns-<hash>-<id>   1/1     Running   0          2m    10.244.0.3   walk-control-plane   ...
coredns-<hash>-<id>   1/1     Running   0          2m    10.244.0.2   walk-control-plane   ...
```

CoreDNS odatda control plane'da: klaster yaratilganda boshqa node hali yo'q edi. IP'lar `10.244.0.x`, ya'ni control plane'ga ajratilgan pod CIDR bo'lagi. Endi oddiy pod ishga tushiring; u worker'ga tushadi va DNS so'rovi boshqa node'dagi CoreDNS'ga boradi, ya'ni bitta sinov ham DNS'ni, ham node'lar orasidagi pod tarmog'ini tekshiradi:

```
$ kubectl run walk-dns --image=busybox:1.36 --restart=Never --rm -i -- nslookup kubernetes.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	kubernetes.default.svc.cluster.local
Address: 10.96.0.1

pod "walk-dns" deleted
```

`Server` klaster DNS Service'ining IP'si (Service'lar 6-darsda). `Name` va `Address`: `kubernetes` Service'i (API server) `10.96.0.1` ga yechildi. Oxirgi qator `--rm` pod'ni o'chirganini bildiradi (kubectl versiyasiga qarab matni biroz farq qiladi). CoreDNS sizda worker'da bo'lsa, sinov node'lar orasini tekshirmaydi: buni `-o wide` dan ko'rib, natijani shunga qarab talqin qiling.

6. O'chirish va iz qolmaganini isbotlash:

```
$ kind delete cluster --name walk --kubeconfig ~/k2-walk/walk.kubeconfig
Deleting cluster "walk" ...
Deleted nodes: ["walk-control-plane" "walk-worker"]
$ kind get clusters
dev
$ docker ps -a --filter name=walk --format '{{.Names}}'
$ unset KUBECONFIG
$ kubectl config get-contexts -o name | grep walk
$ cd ~ && rm -r ~/k2-walk
```

`--kubeconfig` o'chirishda ham beriladi, shunda kind yozuvni to'g'ri fayldan olib tashlaydi. `kind get clusters` faqat 1-darsdagi `dev` ni ko'rsatadi (u sizda yo'q bo'lsa, "No kind clusters found."). `docker ps -a` va `grep` bo'sh chiqdi: na konteyner, na asosiy kubeconfig'da yozuv qoldi, chunki `walk` u yerga umuman yozilmagan edi.

Shu 6 qadamda ko'rganingiz: kind konfiguratsiya fayli klasterning desired state'i (2-bo'lim); alohida kubeconfig va `KUBECONFIG` klasterlarni bir-biridan ajratadi (9-bo'lim); `Ready` va `Running` status darajasi, DNS sinovi esa funksional daraja (8-bo'lim); kind node'lari kernel'ni host bilan ulashadi (2-bo'lim va 6-vazifadagi savol).

---

## Vazifalar

Barchasini `kubernetes/02-cluster-setup/` papkasida bajaring (`make new m=kubernetes n=02 name=cluster-setup`, host'da). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh; qaysi mashinada (Zorin yoki macOS) bajarilgani yozilsin. kind konfiguratsiyalari va skriptlar shu papkaga saqlanadi. Token, kubeconfig va sertifikatlar README'ga ham, papkaga ham yozilmaydi (`<token>` kabi belgilang).

### A. kind

1. **Multi-node kind.** `kind-multi.yaml` yozing: 1 ta control-plane va 2 ta worker. Klasterni `multi` nomi bilan yarating. `kubectl get nodes -o wide` va `docker ps` natijasini solishtiring. 4 replikali Deployment yarating: pod'lar qaysi node'larga tushdi? Control plane'ga tushdimi? `kubectl describe node multi-control-plane` dagi `Taints` qatoridan sababini toping. Yo'nalish: 2-bo'lim, "Misol"; 5-bo'lim, `mark-control-plane` bosqichi.

2. **Node internals.** `docker exec -it multi-worker bash` bilan node ichiga kiring. `ps aux` da kubelet va containerd'ni toping, `systemctl status kubelet` ni ko'ring, `crictl ps` bilan konteynerlarni chiqaring. kubelet konfiguratsiya fayli qayerda? Worker node'da `/etc/kubernetes/manifests` da nima bor va nima uchun? (Node konteyner ichida systemd bor, shuning uchun bu buyruqlar Mac'da ham ishlaydi.) Yo'nalish: 2-bo'lim, "Mexanizm"; 5-bo'lim, static pod.

3. **Pinned node image.** kind release notes'dan joriy versiyadan bitta oldingi Kubernetes minor versiyasi uchun `kindest/node` image'ini toping va shu versiyada `old` nomli klaster yarating. `kubectl version` natijasida client va server versiyalarini ko'rsating. `kubectl` va API server orasidagi ruxsat etilgan versiya farqi (version skew) qancha? Klasterni o'chiring. Yo'nalish: 2-bo'lim, "Node image"; Manbalar, version skew siyosati.

4. **Load a local image.** Ish mashinasida oddiy image build qiling (masalan, `index.html` i o'zgartirilgan nginx) va unga `web:dev` tag'ini bering. Uni `kind load` siz Deployment'da ishlatib ko'ring va xatoni yozing. Keyin `kind load docker-image` bilan yuklab, ishlashini ko'rsating. Tag'ni `latest` ga o'zgartirsangiz nima bo'ladi va nima uchun? (Mac'da image `arm64` bo'ladi, kind node'lari ham `arm64`, shuning uchun mos keladi.) Yo'nalish: 2-bo'lim, "Tuzoq: `kind load` va `imagePullPolicy`".

### B. minikube

5. **minikube cluster.** minikube o'rnating va Docker driver bilan klaster yarating. `minikube addons list` dan uchta addon nima qilishini yozing. kind va minikube'ni uch mezon bo'yicha solishtiring: ishga tushish vaqti, multi-node, addon'lar. `minikube delete --all` bilan o'chiring va `kubectl config get-contexts` da yozuvi qolmaganini tekshiring. Yo'nalish: Laboratoriya (o'rnatish), 3-bo'lim.

### C. k3s, Multipass VM'larda

6. **Multipass VMs.** Multipass o'rnating va uchta VM yarating: `k3s-server`, `k3s-agent1`, `k3s-agent2` (har biri 2 CPU, 2 GB). `multipass list` natijasini ko'rsating. VM'lar bir-birini IP orqali `ping` qila olishini tekshiring. Bu VM'lar kind node'laridan nimasi bilan farq qiladi (kernel, izolyatsiya)? Yo'nalish: Laboratoriya, "Multipass VM'lar"; 4-bo'lim, "Bu nima"; "Birga bajaramiz", 3-qadam.

7. **k3s server.** `k3s-server` da k3s o'rnating. `sudo k3s kubectl get nodes` va `get pods -A` natijasini ko'rsating. `systemctl status k3s` ni ko'ring. `ps aux` da alohida `kube-apiserver`, `etcd`, `kube-scheduler` jarayonlari bormi? Topganingizni 4-bo'limdagi "bitta binary" tushunchasi bilan izohlang. Yo'nalish: 4-bo'lim, "Mexanizm" va "Misol: server".

8. **Join agents.** Ikkala agent'ni klasterga qo'shing. Uchala node `Ready` ekanini ko'rsating. Agent'da qaysi systemd unit ishlaydi? Node'lardan birining `ROLES` ustuni nima uchun boshqacha? Yo'nalish: 4-bo'lim, agent qo'shish.

9. **Remote kubeconfig.** k3s kubeconfig'ini ish mashinangizga ko'chiring (papkaga emas, `~/` ga), server manzilini VM IP'siga almashtiring va `kubectl --kubeconfig` bilan ish mashinasidan `get nodes` qiling. Manzil `127.0.0.1` qolganda qanday xato chiqdi? Fayl ruxsatlarini (`chmod`) qanday qo'ydingiz va nima uchun? Yo'nalish: 4-bo'lim, kubeconfig haqidagi paragraf (Mac'da `sed -i ''`).

10. **Bundled components.** k3s klasterida `kube-system` dagi pod'lar va `kubectl get storageclass,ingressclass` natijasini ko'ring. Har komponent nima vazifa bajarishini yozing va kind klasteridagi mos komponent bilan solishtiring (CNI, DNS, storage, ingress, LoadBalancer). k3s'ni Traefik'siz o'rnatish uchun qaysi flag kerak? Yo'nalish: 4-bo'lim, "Mexanizm"; Manbalar, k3s konfiguratsiyasi.

11. **Node failure.** k3s klasterida 3 replikali Deployment yarating va pod'lar qaysi node'larda ekanini yozing. `multipass stop k3s-agent1` qiling va `kubectl get nodes -w` hamda `get pods -o wide -w` ni kuzating. Node qancha vaqtdan keyin `NotReady` bo'ldi? Undagi pod'lar qancha vaqtdan keyin boshqa node'da qayta yaratildi? Bu kechikish qayerdan kelishini pod'ning `tolerations` maydonidan toping. VM'ni qayta yoqing va nima bo'lishini yozing. Oxirida k3s VM'larini o'chiring. Yo'nalish: 8-bo'lim, "Misol" oxiri; `kubectl get pod <name> -o yaml`.

### D. kubeadm, Multipass VM'larda

12. **Prepare nodes.** Ikkita yangi VM yarating: `kubeadm-cp` va `kubeadm-w1`. Ikkalasida 5-bo'limdagi tayyorgarlikni bajaring. README'da har qadam nima uchun kerakligini yozing: `ip_forward`, `br_netfilter`, `SystemdCgroup = true`, `apt-mark hold`. `containerd` konfiguratsiyasida o'zgartirgan qatoringizni ko'rsating. Yo'nalish: 5-bo'lim, "Mexanizm: har node'da tayyorgarlik".

13. **kubeadm init.** `kubeadm-cp` da `kubeadm init` ni bajaring. Chiqishdagi bosqichlarni (`[preflight]`, `[certs]`, ...) 5-bo'limdagi jadval bilan moslang. `kubectl get nodes` va `get pods -A` natijasini ko'rsating: node qaysi holatda, qaysi pod'lar `Pending`? `kubectl describe node` dagi `Conditions` dan aniq sababni toping. Yo'nalish: 5-bo'lim, "Misol: control plane'ni ishga tushirish"; 6-bo'lim, "Mexanizm".

14. **Install CNI.** Flannel'ni o'rnating va node `Ready` ga o'tishini, CoreDNS pod'lari ishga tushishini kuzating. Flannel qaysi turdagi workload sifatida o'rnatildi (Deployment, DaemonSet, boshqa) va nima uchun aynan shunday? `--pod-network-cidr` boshqa qiymat bilan berilganida nima buzilgan bo'lardi? Yo'nalish: 5-bo'lim, "Misol: CNI va worker'lar"; 6-bo'lim.

15. **Join a worker.** Join buyrug'ini yarating va `kubeadm-w1` ni klasterga qo'shing. Ikkala node `Ready` ekanini ko'rsating. `kubeadm token list` natijasida token muddati qancha? Buyruqdagi `--discovery-token-ca-cert-hash` nimadan himoya qiladi? 2 replikali Deployment pod'lari qaysi node'ga tushdi va nima uchun? Yo'nalish: 5-bo'lim, join buyrug'i izohi.

16. **Certificates and manifests.** Control plane'da `/etc/kubernetes/pki` va `/etc/kubernetes/manifests` tarkibini ko'ring. `sudo kubeadm certs check-expiration` natijasini ko'rsating: sertifikatlar va CA qancha muddatga berilgan? Muddati o'tsa nima bo'ladi va bu managed klasterda kimning muammosi? Yo'nalish: 5-bo'lim, bosqichlar jadvali; 7-bo'lim, "Mexanizm"; Manbalar, kubeadm sertifikatlari.

17. **Break the kubelet.** `kubeadm-w1` da `sudo systemctl stop kubelet` qiling. Node holati va undagi pod'lar qanday o'zgarishini kuzating. Konteynerlar (`sudo crictl ps`) to'xtadimi? Bu "control plane yo'qolsa ham ishlab turgan workload'lar ishlayveradi" degan gapni qanday tasdiqlaydi yoki rad etadi? kubelet'ni qayta yoqing. Yo'nalish: 1-darsdagi kubelet roli; 8-bo'lim, "Mexanizm".

### E. Tekshirish va boshqarish

18. **Health check script.** `cluster-health.sh` yozing: berilgan context uchun node'lar `Ready` ekanini, `kube-system` da `Running` yoki `Completed` bo'lmagan pod yo'qligini, `/readyz` javobini tekshirsin, test pod yaratib DNS (`kubernetes.default`) ishlashini sinab, o'zidan keyin tozalasin. Muammo topilsa noldan farqli exit code qaytarsin. `shellcheck` toza bo'lsin. Uni kind va kubeadm klasterlarida ishlating. Skript ikkala mashinada ishlashi kerak: GNU'ga xos flag'lar ishlatmang, ma'lumotni `kubectl` ning `-o jsonpath` yoki `--no-headers` chiqishidan oling. Yo'nalish: 8-bo'lim; "Birga bajaramiz", 4–5 qadamlar.

19. **Merge kubeconfigs.** kubeadm klasterining `admin.conf` ini ish mashinasiga (`~/` ga) ko'chiring. `KUBECONFIG` orqali uni kind kubeconfig'i bilan birlashtiring, context'ga tushunarli nom bering (`rename-context`) va `get-contexts` natijasini ko'rsating. `--flatten` nima qiladi? Birlashtirilgan faylni qayerda saqladingiz va nima uchun ish papkasida emas? Yo'nalish: 9-bo'lim.

20. **Managed cluster comparison.** Klaster yaratmasdan, rasmiy hujjatlar asosida EKS, GKE va AKS'dan birini tanlab yozing: control plane uchun to'lov bormi, node'lar qanday boshqariladi, qaysi CNI standart, `kubectl` qanday autentifikatsiya qilinadi, Kubernetes versiyasi qancha muddat qo'llab-quvvatlanadi. O'zingiz kubeadm bilan qurgan klasterda shu ishlarning qaysi birini qo'lda qilgan edingiz? Har fakt yonida manba havolasi bo'lsin. Yo'nalish: 7-bo'lim.

21. **Teardown audit.** Barcha laboratoriya resurslarini o'chiring va isbotlang: `multipass list`, `kind get clusters`, `docker ps -a`, `kubectl config get-contexts` natijalari. kubeconfig'da o'chirilgan klasterlarning qoldiq yozuvlari bo'lsa, ularni `kubectl config delete-context`, `delete-cluster`, `delete-user` bilan tozalang. Keyingi darslar uchun faqat kind `dev` klasteri qolsin. `lab` VM'ga tegmang (`multipass list` da `Stopped` bo'lib turadi). Ikkinchi mashinada ham shu dars resurslari qolmaganini tekshiring. Yo'nalish: Laboratoriya, "Tozalash"; "Birga bajaramiz", 6-qadam.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa `## N. Title` sarlavhasi ostida yozilgan, qaysi mashinada bajarilgani ko'rinadi; `kind-multi.yaml` va `cluster-health.sh` papkada.
2. `make check` toza o'tadi (`shellcheck`, `yamllint`).
3. Papkada token, kubeconfig, `admin.conf`, sertifikat yo'q; README'da ular `<...>` bilan almashtirilgan.
4. Multipass VM'lar (`lab` dan tashqari) va ortiqcha klasterlar o'chirilgan (21-vazifa), kind `dev` klasteri bor.
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- kind node'i bilan haqiqiy VM node'i orasidagi asosiy farqlar nima? Mac'da kind node'i aslida qayerda ishlaydi?
- Klaster bootstrap'ining olti qadami nima va kubeadm ulardan qaysilarini qilmaydi?
- `kubeadm init` dan keyin node nima uchun `NotReady` va buni nima tuzatadi?
- Static pod nima va control plane nima uchun aynan shu usulda ishga tushadi?
- kubelet va containerd cgroup driver'i nima uchun bir xil bo'lishi kerak?
- Join token va CA cert hash nima vazifa bajaradi?
- k3s standart Kubernetes'dan nimalari bilan farq qiladi va qachon uni tanlagan bo'lardingiz?
- CNI tanlashda qaysi savollarga javob berish kerak?
- Managed klasterda provayder nimaga javob beradi, siz nimaga?
- Node o'chib qolganda pod'lar nima uchun darhol emas, bir necha daqiqadan keyin ko'chiriladi?
- `Ready` node va `Running` pod'lar nima uchun klaster ishlayotganini to'liq isbotlamaydi?
- `KUBECONFIG` da bir nechta fayl bo'lsa `kubectl` ularni qanday birlashtiradi?
