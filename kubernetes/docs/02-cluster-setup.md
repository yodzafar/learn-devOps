# 2-dars: Klaster o'rnatish, single node va multi node

Maqsad: Kubernetes klasterini turli usullar bilan qurish va har usul qachon mos kelishini tushunish: kind va minikube (lokal ishlab chiqish), k3s (yengil, haqiqiy multi-node), kubeadm (standart "qo'lda" o'rnatish), managed xizmatlar (EKS, GKE, AKS). 1-darsda tayyor klasterni ichidan ko'rdingiz; bu darsda uni o'zingiz yig'asiz, shu orqali komponentlar qanday ishga tushishi, node qanday qo'shilishi va CNI nima uchun majburiy ekanini qo'lda ko'rasiz. Keyingi darslar asosan kind'da o'tadi, lekin 11-dars (high availability) va production'dagi nosozliklarni tushunish uchun kubeadm tajribasi kerak.

Taxminiy vaqt: 4 kun (siz uchun). kind va minikube tez o'tadi. Asosiy vaqt k3s va kubeadm'ga: `kubeadm init` chiqishini qatorma-qator o'qing, CNI o'rnatilguncha node nima uchun `NotReady` ekanini, join token nima ekanini tushuning.

## Laboratoriya

Ikki muhit:

1. **Ish mashinasi, Docker ustida**: kind va minikube klasterlari. Faqat binary o'rnatiladi.
2. **Multipass VM'lar**: k3s va kubeadm. Bu o'rnatishlar paket qo'shadi, sysctl va kernel modullarni o'zgartiradi, shuning uchun ish mashinasida emas, faqat VM ichida bajariladi.

Multipass o'rnatish (rasmiy yo'riqnoma: https://canonical.com/multipass/docs):

```bash
sudo snap install multipass
multipass launch 24.04 --name k3s-server --cpus 2 --memory 2G --disk 10G
multipass list
multipass shell k3s-server            # interactive shell
multipass exec k3s-server -- uname -a # one command
```

Resurs: uchta VM (har biri 2 CPU, 2 GB RAM) uchun kamida 8 GB bo'sh xotira kerak. k3s va kubeadm klasterlarini bir vaqtda emas, ketma-ket quring: birini tugatib o'chiring, keyin ikkinchisini boshlang.

Tozalash: `multipass delete --purge <nom>` har VM uchun, `kind delete cluster --name <nom>`, `minikube delete --all`. Managed klaster (EKS va boshqalar) bu darsda yaratilmaydi; ixtiyoriy sinab ko'rsangiz, cloud modulidagi qoidalar amal qiladi: budget alert, eng kichik node, shu kunning o'zida o'chirish va o'chirilganini tekshirish.

---

## 1. Usullar xaritasi

| Usul | Node nima | Qachon ishlatiladi | Cheklovi |
|------|-----------|--------------------|----------|
| kind | Docker konteyneri | lokal ishlab chiqish, CI'da test klaster | production emas, node'lar bitta host'da |
| minikube | VM yoki konteyner | lokal o'rganish, addon'lar bilan tez sinov | production emas |
| k3s | istalgan Linux host | edge, kichik server, homelab, CI, yengil production | ba'zi komponentlar standartdan farq qiladi |
| kubeadm | istalgan Linux host | o'z serverlarida standart klaster | hammasini o'zingiz boshqarasiz: yangilash, etcd, sertifikatlar |
| EKS, GKE, AKS | cloud VM'lar | cloud'dagi production | pullik, cloud'ga bog'lanish |

Qoida: control plane'ni o'zingiz boshqarishga aniq sabab bo'lmasa, production'da managed xizmat tanlanadi. Lekin managed klasterda ham node'lar, tarmoq va workload'lar muammosi sizniki, shuning uchun ichki tuzilishni bilish shart.

## 2. kind

kind (Kubernetes IN Docker) har node'ni bitta Docker konteyneri sifatida ishga tushiradi. Konteyner ichida systemd, containerd va kubelet ishlaydi, klaster esa ichkarida kubeadm bilan yig'iladi. Ya'ni kind bu "konteyner ichidagi kubeadm klasteri".

Multi-node klaster konfiguratsiya fayli bilan yaratiladi:

```yaml
# kind-multi.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

```bash
kind create cluster --name multi --config kind-multi.yaml
kind get clusters
kind get nodes --name multi
```

Muhim imkoniyatlar:

- **Node image**: Kubernetes versiyasi `kindest/node` image tag'i bilan tanlanadi: `kind create cluster --image kindest/node:<tag>`. Har kind relizi uchun mos tag'lar release notes'da digest bilan beriladi.
- **Lokal image yuklash**: node'lar ish mashinangizdagi Docker image'larini ko'rmaydi (ularning o'z containerd'i bor). `kind load docker-image myapp:dev --name multi` image'ni barcha node'larga ko'chiradi.
- **Port mapping**: `extraPortMappings` node konteyneri portini host portiga ulaydi (NodePort servislar uchun, 6-dars).

**Tuzoq: `kind load` va `imagePullPolicy`.** Image tag'i `latest` bo'lsa yoki tag ko'rsatilmasa, `imagePullPolicy` standart holatda `Always` bo'ladi va kubelet yuklangan lokal image o'rniga registry'ga murojaat qiladi, natija `ErrImagePull`. Lokal image'ga aniq tag bering.

## 3. minikube

minikube ham lokal klaster, lekin "driver" tanlash mumkin (Docker, KVM, QEMU va boshqalar) va tayyor addon'lar to'plami bor. O'rnatish: https://minikube.sigs.k8s.io/docs/start/

```bash
minikube start --driver=docker
minikube start --driver=docker --nodes 2 -p two   # separate profile, two nodes
minikube addons list
minikube stop
minikube delete --all
```

kind bilan farqi: kind tezroq va CI'ga qulay, konfiguratsiyasi fayl orqali; minikube'da addon'lar (`dashboard`, `metrics-server` va boshqalar) bitta buyruq bilan yoqiladi. Bu kursda asosiy vosita kind, minikube'ni bilish yetarli.

## 4. k3s

k3s bu sertifikatlangan Kubernetes distributivi, bitta binary ko'rinishida. Control plane komponentlari bitta jarayonda ishlaydi, standart holatda etcd o'rniga SQLite ishlatiladi (HA uchun embedded etcd yoqiladi). Ichida tayyor keladi: containerd, Flannel (CNI), CoreDNS, Traefik (ingress controller), ServiceLB (LoadBalancer), local-path provisioner (storage), metrics-server. Keraksizlari `--disable` flag'i bilan o'chiriladi.

Terminologiya: control plane node'i `server`, worker node'i `agent`.

Server'ni o'rnatish (VM ichida):

```bash
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes
sudo cat /var/lib/rancher/k3s/server/node-token
```

Agent'ni qo'shish (har agent VM ichida, `<server-ip>` va `<token>` o'rniga haqiqiy qiymatlar):

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<token> sh -
```

kubeconfig server'da `/etc/rancher/k3s/k3s.yaml` da turadi, ichidagi manzil `https://127.0.0.1:6443`. Ish mashinasidan ulanish uchun faylni ko'chirib, manzilni VM IP'siga almashtirasiz (`multipass info k3s-server` IP'ni ko'rsatadi).

**Tuzoq: `curl | sh`.** Internetdan skriptni to'g'ridan-to'g'ri root sifatida ishlatish laboratoriya VM'ida maqbul, production'da skriptni avval yuklab o'qing yoki versiyasi qotirilgan paket va konfiguratsiya boshqaruvi (Ansible) ishlating.

**Tuzoq: node token.** Token bilan istalgan mashina klasterga node sifatida qo'shila oladi. U secret: README'ga yozilmaydi, commit qilinmaydi.

## 5. kubeadm

kubeadm bu Kubernetes loyihasining rasmiy bootstrap vositasi. U klaster yig'adi, lekin mashinalarni tayyorlamaydi, CNI o'rnatmaydi va infratuzilmani boshqarmaydi. kind, ko'p managed va on-premise yechimlar ichida aynan kubeadm ishlaydi.

### Har node'da tayyorgarlik

Rasmiy yo'riqnomalar: https://kubernetes.io/docs/setup/production-environment/container-runtimes/ va https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

1. **Swap**: kubelet standart holatda swap yoqilgan bo'lsa ishga tushmaydi. Multipass Ubuntu image'ida swap yo'q, `swapon --show` bilan tekshiring.
2. **Tarmoq**: paket forwarding va bridge trafigi uchun kernel moduli.

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system
echo br_netfilter | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe br_netfilter
```

3. **Container runtime**: containerd o'rnatiladi va systemd cgroup driver'ga o'tkaziladi. kubelet va runtime bir xil cgroup driver ishlatishi shart; systemd'li tizimda bu `systemd`.

```bash
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# in config.toml set: SystemdCgroup = true  (runc options section)
sudo systemctl restart containerd
```

4. **Paketlar**: `kubelet`, `kubeadm`, `kubectl`. Repozitoriy har minor versiya uchun alohida, quyidagi `v1.37` dars yozilgan paytdagi joriy versiya, o'rnatish sahifasidagi qiymatni oling:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

`apt-mark hold` tasodifiy `apt upgrade` klaster versiyasini o'zgartirib yubormasligi uchun: Kubernetes faqat rejali, bittadan minor versiyaga yangilanadi.

### Control plane'ni ishga tushirish

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

`kubeadm init` bosqichlari (chiqishda `[preflight]`, `[certs]` kabi prefikslar bilan ko'rinadi):

| Bosqich | Nima qiladi |
|---------|-------------|
| `preflight` | tizim talablarini tekshiradi: swap, portlar, runtime, kernel sozlamalari |
| `certs` | klaster CA va komponent sertifikatlarini `/etc/kubernetes/pki` da yaratadi |
| `kubeconfig` | admin, kubelet, controller-manager, scheduler uchun kubeconfig fayllari |
| `control-plane`, `etcd` | static pod manifestlarini `/etc/kubernetes/manifests` ga yozadi, kubelet ularni ishga tushiradi |
| `bootstrap-token` | node'lar qo'shilishi uchun vaqtinchalik token yaratadi |
| `addons` | CoreDNS va kube-proxy'ni o'rnatadi |

`init` tugagach node `NotReady` holatida bo'ladi va CoreDNS pod'lari `Pending` turadi: pod tarmog'i hali yo'q. kubeadm CNI o'rnatmaydi, bu sizning tanlovingiz.

### CNI va worker'lar

Flannel misolida (uning standart pod CIDR'i `10.244.0.0/16`, shuning uchun `init` da shu qiymat berildi):

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl get nodes -w
```

Worker qo'shish: control plane'da join buyrug'ini oling va worker'da `sudo` bilan bajaring.

```bash
kubeadm token create --print-join-command   # on the control plane
# on the worker: sudo kubeadm join <ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Token standart holatda 24 soat yashaydi. `--discovery-token-ca-cert-hash` worker'ga u haqiqiy control plane bilan gaplashayotganini tekshirish imkonini beradi (aks holda soxta API server'ga ulanib qolishi mumkin).

Node'ni tozalash: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`, `kubectl delete node <node>`, node'ning o'zida `sudo kubeadm reset`.

## 6. CNI tanlash

Kubernetes tarmoq modeli uch talab qo'yadi: har pod o'z IP'siga ega, barcha pod'lar bir-biriga NAT'siz ulana oladi, node'dagi agentlar o'sha node pod'lariga ulana oladi. Buni Kubernetes'ning o'zi amalga oshirmaydi, CNI plugin bajaradi.

| CNI | Xususiyati | NetworkPolicy |
|-----|------------|---------------|
| Flannel | eng sodda, VXLAN overlay | yo'q |
| Calico | BGP yoki overlay, keng tarqalgan | bor |
| Cilium | eBPF asosida, kube-proxy'ni almashtira oladi, kuzatuv vositalari | bor, L7 gacha |
| Cloud CNI (AWS VPC CNI va boshqalar) | pod'lar VPC IP'sini oladi | cloud'ga qarab |

Tanlov mezonlari: NetworkPolicy kerakmi (13-dars: ha, production'da kerak), cloud bilan integratsiya, jamoaning ekspluatatsiya tajribasi. CNI'ni ishlab turgan klasterda almashtirish og'ir operatsiya, boshida o'ylab tanlanadi.

## 7. Managed klasterlar

| | EKS (AWS) | GKE (Google Cloud) | AKS (Azure) |
|---|-----------|--------------------|-------------|
| Control plane | AWS boshqaradi | Google boshqaradi | Azure boshqaradi |
| Node'lar | managed node group, Fargate, yoki avtomatik rejim | node pool yoki Autopilot | node pool |
| CLI | `aws eks`, `eksctl` | `gcloud container` | `az aks` |
| Identity | IAM bilan integratsiya | Google IAM | Entra ID |

Provayder zimmasida: API server, etcd, ularning zaxirasi, yangilanishi va yuqori mavjudligi. Sizning zimmangizda: node'lar (yoki ularning sozlamasi), workload'lar, tarmoq siyosatlari, RBAC, addon'lar, versiya yangilash rejasi, xarajat.

**Tuzoq: narx.** Managed klasterda odatda control plane uchun soatbay to'lov, node VM'lari, load balancer'lar, disklar va chiquvchi trafik alohida hisoblanadi. "Faqat sinab ko'rdim" degan klaster o'chirilmasa oy oxirida sezilarli hisob keladi. O'chirganda LoadBalancer Service va PVC'lar yaratgan cloud resurslari ham o'chganini tekshiring (15-dars shu haqda).

## 8. Klaster sog'ligini tekshirish

Yangi klasterni "tayyor" deyishdan oldin:

```bash
kubectl get nodes -o wide                 # all Ready, expected versions
kubectl get pods -A                       # nothing Pending or CrashLoopBackOff
kubectl get --raw='/readyz?verbose'       # API server internal checks
kubectl cluster-info
```

Keyin funksional sinov: test Deployment yarating, pod'lar turli node'larga tushganini, pod'dan pod'ga (boshqa node'dagi) tarmoq ishlashini va DNS (`nslookup kubernetes.default`) javob berishini tekshiring. `Ready` holati faqat kubelet o'zini sog'lom deb bilishini anglatadi, node'lar orasidagi pod tarmog'i ishlashini kafolatlamaydi.

**Tuzoq: `kubectl get componentstatuses`.** Eski qo'llanmalarda uchraydi, bu API ancha oldin deprecated qilingan. O'rniga `/readyz` va `/livez` endpoint'lari ishlatiladi.

## 9. kubeconfig'larni birlashtirish

Har klaster o'z kubeconfig'ini beradi. Bir nechta faylni bitta ko'rinishga keltirish:

```bash
export KUBECONFIG=~/.kube/config:~/k3s.yaml       # merged view, in memory
kubectl config get-contexts
kubectl config view --flatten > ~/.kube/merged    # write one self-contained file
kubectl config rename-context default k3s-lab
```

`KUBECONFIG` da bir nechta fayl bo'lsa, `kubectl` ularni xotirada birlashtiradi; bir xil nomli yozuvlarda birinchi uchragani yutadi. k3s kubeconfig'ida cluster, user va context nomi `default` bo'lgani uchun birlashtirishdan oldin nomlarni o'zgartirish kerak, aks holda yozuvlar to'qnashadi.

## Tuzoqlar

- kubelet va container runtime cgroup driver'i mos kelmasligi: kubelet ishga tushmaydi yoki node beqaror bo'ladi.
- CNI o'rnatilmagan klasterda `NotReady` node va `Pending` CoreDNS'ni "klaster buzildi" deb o'ylash. Avval CNI.
- Pod CIDR node'lar tarmog'i yoki boshqa tarmoqlar bilan kesishishi: tushunarsiz ulanish xatolari.
- Join token va `admin.conf` ni ochiq joyda qoldirish. Ikkalasi ham klasterga to'liq kirish beradi.
- `kubelet`, `kubeadm` paketlarini `hold` qilmaslik: oddiy `apt upgrade` klasterni yarim yangilangan holatga keltiradi.
- Bitta control plane node'li klasterni production deb hisoblash: u node o'lsa API ham, etcd ham yo'q (11-dars).
- kind yoki minikube'da ishlagan narsa production'da ham xuddi shunday ishlaydi deb o'ylash: LoadBalancer, storage va tarmoq u yerda boshqacha.
- Managed klasterni o'chirmay qoldirish yoki o'chirgandan keyin qolgan load balancer va disklarni tekshirmaslik.

## Manbalar

- https://kind.sigs.k8s.io/docs/user/configuration/ – kind konfiguratsiyasi
- https://minikube.sigs.k8s.io/docs/start/ – minikube
- https://docs.k3s.io/quick-start – k3s tez boshlash
- https://docs.k3s.io/architecture – k3s arxitekturasi
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/ – kubeadm o'rnatish
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/ – kubeadm bilan klaster yaratish
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/ – container runtime talablari
- https://kubernetes.io/docs/concepts/cluster-administration/networking/ – tarmoq modeli
- https://github.com/flannel-io/flannel – Flannel
- https://canonical.com/multipass/docs – Multipass
- https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/ – bir nechta klasterga kirish

---

## Vazifalar

Barchasini `kubernetes/02-cluster-setup/` papkasida bajaring (`make new m=kubernetes n=02 name=cluster-setup`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. kind konfiguratsiyalari va skriptlar shu papkaga saqlanadi. Token, kubeconfig va sertifikatlar README'ga ham, papkaga ham yozilmaydi.

### A. kind

1. **Multi-node kind.** `kind-multi.yaml` yozing: 1 ta control-plane va 2 ta worker. Klasterni `multi` nomi bilan yarating. `kubectl get nodes -o wide` va `docker ps` natijasini solishtiring. 4 replikali Deployment yarating: pod'lar qaysi node'larga tushdi? Control plane'ga tushdimi? `kubectl describe node multi-control-plane` dagi `Taints` qatoridan sababini toping.

2. **Node internals.** `docker exec -it multi-worker bash` bilan node ichiga kiring. `ps aux` da kubelet va containerd'ni toping, `systemctl status kubelet` ni ko'ring, `crictl ps` bilan konteynerlarni chiqaring. kubelet konfiguratsiya fayli qayerda? Worker node'da `/etc/kubernetes/manifests` da nima bor va nima uchun?

3. **Pinned node image.** kind release notes'dan joriy versiyadan bitta oldingi Kubernetes minor versiyasi uchun `kindest/node` image'ini toping va shu versiyada `old` nomli klaster yarating. `kubectl version` natijasida client va server versiyalarini ko'rsating. `kubectl` va API server orasidagi ruxsat etilgan versiya farqi (version skew) qancha? Klasterni o'chiring.

4. **Load a local image.** Ish mashinasida oddiy image build qiling (masalan, `index.html` i o'zgartirilgan nginx) va unga `web:dev` tag'ini bering. Uni `kind load` siz Deployment'da ishlatib ko'ring va xatoni yozing. Keyin `kind load docker-image` bilan yuklab, ishlashini ko'rsating. Tag'ni `latest` ga o'zgartirsangiz nima bo'ladi va nima uchun?

### B. minikube

5. **minikube cluster.** minikube o'rnating va Docker driver bilan klaster yarating. `minikube addons list` dan uchta addon nima qilishini yozing. kind va minikube'ni uch mezon bo'yicha solishtiring: ishga tushish vaqti, multi-node, addon'lar. `minikube delete --all` bilan o'chiring va `kubectl config get-contexts` da yozuvi qolmaganini tekshiring.

### C. k3s, Multipass VM'larda

6. **Multipass VMs.** Multipass o'rnating va uchta VM yarating: `k3s-server`, `k3s-agent1`, `k3s-agent2` (har biri 2 CPU, 2 GB). `multipass list` natijasini ko'rsating. VM'lar bir-birini IP orqali `ping` qila olishini tekshiring. Bu VM'lar kind node'laridan nimasi bilan farq qiladi (kernel, izolyatsiya)?

7. **k3s server.** `k3s-server` da k3s o'rnating. `sudo k3s kubectl get nodes` va `get pods -A` natijasini ko'rsating. `systemctl status k3s` ni ko'ring. `ps aux` da alohida `kube-apiserver`, `etcd`, `kube-scheduler` jarayonlari bormi? Topganingizni 4-bo'limdagi "bitta binary" tushunchasi bilan izohlang.

8. **Join agents.** Ikkala agent'ni klasterga qo'shing. Uchala node `Ready` ekanini ko'rsating. Agent'da qaysi systemd unit ishlaydi? Node'lardan birining `ROLES` ustuni nima uchun boshqacha?

9. **Remote kubeconfig.** k3s kubeconfig'ini ish mashinangizga ko'chiring (papkaga emas, `~/` ga), server manzilini VM IP'siga almashtiring va `kubectl --kubeconfig` bilan ish mashinasidan `get nodes` qiling. Manzil `127.0.0.1` qolganda qanday xato chiqdi? Fayl ruxsatlarini (`chmod`) qanday qo'ydingiz va nima uchun?

10. **Bundled components.** k3s klasterida `kube-system` dagi pod'lar va `kubectl get storageclass,ingressclass` natijasini ko'ring. Har komponent nima vazifa bajarishini yozing va kind klasteridagi mos komponent bilan solishtiring (CNI, DNS, storage, ingress, LoadBalancer). k3s'ni Traefik'siz o'rnatish uchun qaysi flag kerak?

11. **Node failure.** k3s klasterida 3 replikali Deployment yarating va pod'lar qaysi node'larda ekanini yozing. `multipass stop k3s-agent1` qiling va `kubectl get nodes -w` hamda `get pods -o wide -w` ni kuzating. Node qancha vaqtdan keyin `NotReady` bo'ldi? Undagi pod'lar qancha vaqtdan keyin boshqa node'da qayta yaratildi? Bu kechikish qayerdan kelishini pod'ning `tolerations` maydonidan toping. VM'ni qayta yoqing va nima bo'lishini yozing. Oxirida k3s VM'larini o'chiring.

### D. kubeadm, Multipass VM'larda

12. **Prepare nodes.** Ikkita yangi VM yarating: `kubeadm-cp` va `kubeadm-w1`. Ikkalasida 5-bo'limdagi tayyorgarlikni bajaring. README'da har qadam nima uchun kerakligini yozing: `ip_forward`, `br_netfilter`, `SystemdCgroup = true`, `apt-mark hold`. `containerd` konfiguratsiyasida o'zgartirgan qatoringizni ko'rsating.

13. **kubeadm init.** `kubeadm-cp` da `kubeadm init` ni bajaring. Chiqishdagi bosqichlarni (`[preflight]`, `[certs]`, ...) 5-bo'limdagi jadval bilan moslang. `kubectl get nodes` va `get pods -A` natijasini ko'rsating: node qaysi holatda, qaysi pod'lar `Pending`? `kubectl describe node` dagi `Conditions` dan aniq sababni toping.

14. **Install CNI.** Flannel'ni o'rnating va node `Ready` ga o'tishini, CoreDNS pod'lari ishga tushishini kuzating. Flannel qaysi turdagi workload sifatida o'rnatildi (Deployment, DaemonSet, boshqa) va nima uchun aynan shunday? `--pod-network-cidr` boshqa qiymat bilan berilganida nima buzilgan bo'lardi?

15. **Join a worker.** Join buyrug'ini yarating va `kubeadm-w1` ni klasterga qo'shing. Ikkala node `Ready` ekanini ko'rsating. `kubeadm token list` natijasida token muddati qancha? Buyruqdagi `--discovery-token-ca-cert-hash` nimadan himoya qiladi? 2 replikali Deployment pod'lari qaysi node'ga tushdi va nima uchun?

16. **Certificates and manifests.** Control plane'da `/etc/kubernetes/pki` va `/etc/kubernetes/manifests` tarkibini ko'ring. `sudo kubeadm certs check-expiration` natijasini ko'rsating: sertifikatlar va CA qancha muddatga berilgan? Muddati o'tsa nima bo'ladi va bu managed klasterda kimning muammosi?

17. **Break the kubelet.** `kubeadm-w1` da `sudo systemctl stop kubelet` qiling. Node holati va undagi pod'lar qanday o'zgarishini kuzating. Konteynerlar (`sudo crictl ps`) to'xtadimi? Bu "control plane yo'qolsa ham ishlab turgan workload'lar ishlayveradi" degan gapni qanday tasdiqlaydi yoki rad etadi? kubelet'ni qayta yoqing.

### E. Tekshirish va boshqarish

18. **Health check script.** `cluster-health.sh` yozing: berilgan context uchun node'lar `Ready` ekanini, `kube-system` da `Running` yoki `Completed` bo'lmagan pod yo'qligini, `/readyz` javobini tekshirsin, test pod yaratib DNS (`kubernetes.default`) ishlashini sinab, o'zidan keyin tozalasin. Muammo topilsa noldan farqli exit code qaytarsin. `shellcheck` toza bo'lsin. Uni kind va kubeadm klasterlarida ishlating.

19. **Merge kubeconfigs.** kubeadm klasterining `admin.conf` ini ish mashinasiga (`~/` ga) ko'chiring. `KUBECONFIG` orqali uni kind kubeconfig'i bilan birlashtiring, context'ga tushunarli nom bering (`rename-context`) va `get-contexts` natijasini ko'rsating. `--flatten` nima qiladi? Birlashtirilgan faylni qayerda saqladingiz va nima uchun ish papkasida emas?

20. **Managed cluster comparison.** Klaster yaratmasdan, rasmiy hujjatlar asosida EKS, GKE va AKS'dan birini tanlab yozing: control plane uchun to'lov bormi, node'lar qanday boshqariladi, qaysi CNI standart, `kubectl` qanday autentifikatsiya qilinadi, Kubernetes versiyasi qancha muddat qo'llab-quvvatlanadi. O'zingiz kubeadm bilan qurgan klasterda shu ishlarning qaysi birini qo'lda qilgan edingiz?

21. **Teardown audit.** Barcha laboratoriya resurslarini o'chiring va isbotlang: `multipass list`, `kind get clusters`, `docker ps -a`, `kubectl config get-contexts` natijalari. kubeconfig'da o'chirilgan klasterlarning qoldiq yozuvlari bo'lsa, ularni `kubectl config delete-context`, `delete-cluster`, `delete-user` bilan tozalang. Keyingi darslar uchun faqat kind `dev` klasteri qolsin.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, `kind-multi.yaml` va `cluster-health.sh` papkada.
2. `make check` toza o'tadi (`shellcheck`, `yamllint`).
3. Papkada token, kubeconfig, `admin.conf` yo'q.
4. Multipass VM'lar va ortiqcha klasterlar o'chirilgan (21-vazifa).
5. Menga xabar bering, tekshiraman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- kind node'i bilan haqiqiy VM node'i orasidagi asosiy farqlar nima?
- `kubeadm init` dan keyin node nima uchun `NotReady` va buni nima tuzatadi?
- kubelet va containerd cgroup driver'i nima uchun bir xil bo'lishi kerak?
- Join token va CA cert hash nima vazifa bajaradi?
- k3s standart Kubernetes'dan nimalari bilan farq qiladi va qachon uni tanlagan bo'lardingiz?
- CNI tanlashda qaysi savollarga javob berish kerak?
- Managed klasterda provayder nimaga javob beradi, siz nimaga?
- Node o'chib qolganda pod'lar nima uchun darhol emas, bir necha daqiqadan keyin ko'chiriladi?
- `KUBECONFIG` da bir nechta fayl bo'lsa `kubectl` ularni qanday birlashtiradi?
