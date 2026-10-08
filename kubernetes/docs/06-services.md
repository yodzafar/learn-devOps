# 6-dars: Service turlari, ClusterIP, NodePort, LoadBalancer, ExternalName

Maqsad: Kubernetes'da trafik pod'ga qanday yetib borishini to'liq tushunish: Service virtual IP'si aslida nima, kube-proxy uni qanday amalga oshiradi, EndpointSlice va klaster DNS qanday ishlaydi, to'rt Service turi va headless Service qachon kerak, tashqi trafik uchun LoadBalancer bulutsiz muhitda qanday olinadi, Ingress va Gateway API qayerda turadi. Network modulidagi DNS, NAT va iptables bilimlari shu yerda bevosita ishlatiladi. Darsning ikkinchi yarmi debug'ga bag'ishlangan: "Service ishlamayapti" production'dagi eng ko'p uchraydigan shikoyat, va uni qatlamma-qatlam tekshirish tartibi kerak. Bu bilimlar 8-dars (TLS), 11-dars (high availability) va 13-dars (NetworkPolicy) uchun asos.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A, B guruhlar; ikkinchi kun 3–4 bo'limlar va C guruh; uchinchi kun 5–6 bo'limlar, D va E guruhlar; to'rtinchi kun 7-bo'lim, "Birga bajaramiz" va F guruh. Diqqat: ClusterIP hech bir interfeysda yo'qligi va bu nimani anglatishi, selector va EndpointSlice bog'lanishi, DNS nomlari va `ndots`, `externalTrafficPolicy` ning manba IP'ga ta'siri, va debug ketma-ketligi.

## Qanday o'qish kerak

Har bo'limdagi buyruqni o'z klasteringizda shunga o'xshash obyekt bilan ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. IP manzillar, pod nomlaridagi tasodifiy suffiks, port raqamlari va `AGE` sizda boshqa bo'ladi; darsda ular `<...>` bilan belgilangan yoki misol sifatida berilgan. Bu darsda ayniqsa muhim savol: "bu paketni hozir kim ko'ryapti va manzilni kim o'zgartirdi?" Har buyruqdan keyin paket yo'lini (klient pod, node kernel'i, pod) xayolan chizing. kind node'lari Docker konteyneri bo'lgani uchun node ichini `docker exec dev-worker ...` bilan ko'rasiz (2-dars).

## Laboratoriya

Hamma narsa host'dagi Docker ustidagi kind `dev` klasterida (1 control-plane + 2 worker, 2-darsdagi `kind-multi.yaml`). LoadBalancer va Gateway API uchun 3-darsda tanishgan `cloud-provider-kind` kerak: u host'da oddiy jarayon sifatida ishlaydi, kind klasterlarini kuzatadi va har LoadBalancer Service yoki Gateway uchun Docker'da proxy konteyner ko'taradi. Uni alohida terminalda ishlab turgan holda qoldiring (13-vazifada ataylab to'xtatasiz). Multipass VM bu darsda kerak emas: node ichidagi `iptables` va `ip` buyruqlari kind node konteynerining ichida ishlaydi, ikkala mashinada bir xil.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `cloud-provider-kind` | releases sahifasidan `linux_amd64` arxivi, `~/.local/bin` ga | `brew install cloud-provider-kind` yoki releases'dagi `darwin_arm64` arxivi |
| Ishga tushirish | alohida terminalda `cloud-provider-kind` | alohida terminalda `cloud-provider-kind`; loyiha README'siga ko'ra macOS'da `sudo` talab qilinishi mumkin |
| kind tarmog'i (`kind` nomli Docker network, odatda `172.18.0.0/16`) | host'dan to'g'ridan-to'g'ri ko'rinadi: node IP, NodePort va LoadBalancer IP'siga `curl` ishlaydi | Docker Desktop'ning yashirin Linux VM'i ichida: Mac'dan `172.18.x.y` ga `curl` javobsiz qoladi |
| Tashqi IP'ga yetish | `curl http://<EXTERNAL-IP>/` | `kind` tarmog'idagi vaqtinchalik konteynerdan (pastda) yoki `docker ps` dagi `127.0.0.1:<port>` mapping orqali |
| `docker exec dev-worker iptables-save` | ishlaydi | ishlaydi, bir xil (node konteyneri ichida) |
| Image'lar | `agnhost:2.39`, `busybox:1.36`, `nicolaka/netshoot:v0.13`, `curlimages/curl:8.10.1`, `amd64` | xuddi shu tag'lar, `arm64` varianti (hammasi multi-arch) |

macOS'da tashqi kirishni sinashning ikki yo'li bor, ikkalasi Zorin'da ham ishlaydi, shuning uchun README'da buyruqlar bir xil bo'lishi uchun birinchisini ikkala mashinada ishlatish tavsiya:

1. **`kind` tarmog'idagi konteyner.** Docker'da `kind` nomli network bor, node'lar ham, `cloud-provider-kind` ning proxy konteynerlari ham shunda. Shu tarmoqqa ulangan bir martalik konteyner ular bilan bevosita gaplasha oladi: `docker run --rm --network kind curlimages/curl:8.10.1 -s http://<ip>:<port>/hostname`. Bu klasterdan tashqaridagi klient, ya'ni haqiqiy "tashqi" trafik.
2. **Port mapping.** macOS'da `cloud-provider-kind` `--enable-lb-port-mapping` flag'i bilan ishga tushirilsa (3-dars, Laboratoriya jadvali), LoadBalancer proxy konteynerining portini host'ga map qiladi. `docker ps` ning `PORTS` ustunida `127.0.0.1:<host-port>->80/tcp` kabi yozuvni toping va `curl http://127.0.0.1:<host-port>/` qiling.

`kubectl port-forward` ham ishlaydi, lekin u Service mexanizmini chetlab o'tadi (API server orqali bitta pod'ga tunnel ochadi), shuning uchun NodePort, LoadBalancer va balanslashni sinash uchun yaramaydi.

Namespace va test ilovasi:

```
$ kubectl config current-context
kind-dev
$ kubectl create namespace net
namespace/net created
$ kubectl config set-context --current --namespace=net
Context "kind-dev" modified.
$ kubectl create deployment echo --image=registry.k8s.io/e2e-test-images/agnhost:2.39 --replicas=3 -- /agnhost netexec --http-port=8080
deployment.apps/echo created
$ kubectl run client --image=busybox:1.36 --restart=Never -- sleep 86400
pod/client created
```

`agnhost netexec` (4-darsda tanishgan test image'i) HTTP server ko'taradi: `/hostname` pod nomini, `/clientip` so'rov kelgan manba manzilni `ip:port` ko'rinishida qaytaradi. `client` pod'i so'rov yuboradigan "klaster ichidagi klient".

- **Ikkinchi mashinada tiklash**: klaster holati git orqali ko'chmaydi. `kind get clusters` da `dev` bo'lmasa `kind create cluster --name dev --config kubernetes/02-cluster-setup/kind-multi.yaml`, keyin yuqoridagi namespace, `echo` va `client` buyruqlari va kerakli `task_N.yaml` larni qayta `apply` qiling. ClusterIP, NodePort raqamlari va LoadBalancer IP'lari boshqacha chiqadi, README'da ularni qaysi mashinada olganingizni yozing.
- **Tozalash**: `kubectl delete namespace net`, `cloud-provider-kind` ni `Ctrl+C` bilan to'xtating, `docker ps` da undan qolgan proxy konteyner yo'qligini tekshiring.

---

## 1. Service nima uchun kerak

### Bu nima

Pod IP'si vaqtinchalik: pod qayta yaratilsa yangi IP oladi, replikalar soni ham o'zgarib turadi (4-dars). Klient pod IP'larini yodlab ishlay olmaydi. Service bu "selector'ga mos pod'lar to'plamiga barqaror kirish nuqtasi" beradigan obyekt. U uch narsa beradi:

- barqaror virtual IP (ClusterIP): Service o'chirilmaguncha o'zgarmaydi;
- barqaror DNS nomi (`echo`, `echo.net.svc.cluster.local`, 4-bo'lim);
- shu manzilga kelgan ulanishlarni tayyor pod'lar orasida taqsimlash.

Frontend'dan haqiqiy o'xshatish: brauzer kodida backend'ga `http://api.example.com` deb murojaat qilasiz, uning ortida nechta server turgani va ularning IP'lari sizni qiziqtirmaydi. Service klaster ichida xuddi shu vazifani bajaradi.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector:
    app: echo           # pods with this label are backends
  ports:
    - name: http
      port: 80          # port on the Service IP
      targetPort: 8080  # port on the pod (number or named container port)
```

- `selector` 1-darsdagi label selector: `app: echo` label'i bor har pod nomzod.
- `port` klient murojaat qiladigan port, `targetPort` pod'dagi konteyner tinglayotgan port. Ular har xil bo'lishi mumkin, Service ularni bir-biriga bog'laydi.
- `name: http` portga nom beradi. Bir nechta portli Service'da nom majburiy, DNS `SRV` yozuvlari ham shu nomdan quriladi.
- `type` yozilmagan, standart qiymat `ClusterIP`.

### Mexanizm: selector'dan EndpointSlice'gacha

Service o'zi pod'larni bilmaydi. Bog'lovchi qism EndpointSlice: Service'ning hozirgi backend'lari (IP, port, holat) yozilgan alohida obyekt. Uni kube-controller-manager ichidagi EndpointSlice controller boshqaradi:

1. Controller Service'lar va pod'larni kuzatadi (1-darsdagi watch mexanizmi).
2. Har Service uchun selector'ga mos pod'larni topadi va ularning IP hamda portlarini bir yoki bir nechta EndpointSlice'ga yozadi. Har slice'da standart bo'yicha ko'pi bilan 100 endpoint.
3. Har endpoint'ning `conditions.ready` maydoni bor. Readiness probe (4-dars) o'tmagan pod ro'yxatda turadi, lekin `ready: false`, va trafik olmaydi.
4. Pod qo'shilsa, o'chsa yoki holati o'zgarsa, slice yangilanadi; 2-bo'limdagi kube-proxy shu o'zgarishni ko'rib node qoidalarini yangilaydi.

Muhim nuqta: selector'ga hech qaysi pod mos kelmasa, bu xato emas. Service yaratiladi, ClusterIP oladi, faqat EndpointSlice bo'sh. Hech qayerda qizil yozuv chiqmaydi.

### Ishlaydigan misol

```
$ kubectl apply -f echo-svc.yaml
service/echo created
$ kubectl get svc echo
NAME   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
echo   ClusterIP   10.96.142.17   <none>        80/TCP    5s
```

- `TYPE ClusterIP`: faqat klaster ichidan ochiq.
- `CLUSTER-IP` Service CIDR'dan (Service IP'lari uchun ajratilgan oraliq, kind'da standart `10.96.0.0/16`) olingan manzil. Pod IP'lari boshqa oraliqdan keladi (kind'da `10.244.0.0/16`).
- `EXTERNAL-IP <none>`: tashqi manzil yo'q va kerak ham emas.
- `PORT(S) 80/TCP`: faqat Service porti ko'rsatiladi, `targetPort` bu yerda ko'rinmaydi.

```
$ kubectl get endpointslices -l kubernetes.io/service-name=echo
NAME         ADDRESSTYPE   PORTS   ENDPOINTS                          AGE
echo-<x7k>   IPv4          8080    10.244.1.5,10.244.2.4,10.244.1.6   5s
```

- Slice nomi Service nomi va tasodifiy suffiks. Service'ga bog'lanish nom orqali emas, `kubernetes.io/service-name` label'i orqali, shuning uchun qidiruvda `-l` ishlatiladi.
- `PORTS 8080`: bu `targetPort`, pod'dagi haqiqiy port.
- `ENDPOINTS` uchta pod IP'si. `kubectl get pods -o wide` dagi `IP` ustuni bilan solishtirsangiz bir xil bo'ladi.

Klaster ichidan sinov:

```
$ kubectl exec client -- wget -qO- http://echo/hostname
echo-<5d9f7c>-<k2m4x>
```

`-q` jim rejim, `-O-` javobni ekranga chiqarish. Bir necha marta takrorlasangiz, javobdagi pod nomi o'zgarib turadi.

Eski Endpoints API (`kubectl get endpoints`) 1.33 dan deprecated: u bitta obyektda barcha manzillarni saqlaydi va katta Service'larda har o'zgarishda butun obyekt qayta yoziladi. Yangi skript va asboblarda EndpointSlice ishlatiladi.

Selector'siz Service ham bo'ladi: EndpointSlice'ni o'zingiz yozasiz va klasterdan tashqaridagi manzilga (masalan, VM'dagi bazaga) klaster ichidagi nom berasiz. Bunda controller slice'ga tegmaydi.

### Real ishda qachon kerak

Klaster ichidagi har bir servisdan servisga murojaat (frontend → API → baza) Service orqali. Debug'da birinchi savollardan biri: "Service'ning endpoint'lari bormi?" Bo'sh EndpointSlice production'dagi eng ko'p uchraydigan sabab (7-bo'lim).

### Nima uchun shunday

Kubernetes'ning hamma joyidagi naqsh: mas'uliyat kichik controller'larga bo'lingan. Service "nima kerak"ni aytadi (selector, port), EndpointSlice controller "hozir kim mos"ni hisoblaydi, kube-proxy "paketni qayerga yuborish"ni amalga oshiradi. Ular bir-birini chaqirmaydi, API orqali obyektlarni kuzatadi. Endpoints'dan EndpointSlice'ga o'tish esa masshtab sababli: 5000 pod'li Service'da bitta pod o'zgarsa, eski usulda butun ro'yxat har node'ga qayta yuborilardi, yangi usulda faqat bitta kichik slice.

## 2. kube-proxy Service'ni qanday amalga oshiradi

### Bu nima

ClusterIP hech bir tarmoq interfeysiga biriktirilmagan. Uni hech qaysi node'ning `ip addr` chiqishida topmaysiz. U faqat har node kernel'idagi paket filtrlash qoidalarida mavjud bo'lgan "xayoliy" manzil. Bu qoidalarni kube-proxy yozadi: u har node'da ishlaydigan agent (kind'da `kube-system` dagi DaemonSet, 4-dars).

### Mexanizm

kube-proxy API'dan Service va EndpointSlice'larni kuzatadi va ularni kernel qoidalariga aylantiradi: "manzili `10.96.142.17:80` bo'lgan TCP paketni shu pod IP'laridan biriga DNAT qil". DNAT (destination NAT, network modulidan) paketning manzil qismini almashtirish. Paket yo'li:

1. `client` pod'i `10.96.142.17:80` ga ulanish ochadi. Paket pod'dan chiqib, o'sha node kernel'iga tushadi.
2. Kernel'dagi qoida paketni tanib, backend'lardan birini tasodifiy tanlaydi va manzilni masalan `10.244.2.4:8080` ga almashtiradi. Bu shu node'dayoq, tarmoqqa chiqishdan oldin bo'ladi.
3. Paket CNI (2-dars, pod'lar orasidagi tarmoqni quradigan plagin) orqali kerakli node'dagi pod'ga yetadi.
4. Javob paketi qaytayotganda conntrack (kernel'ning ulanishlar jadvali) uning manba manzilini teskari almashtiradi: `client` javobni `10.96.142.17:80` dan kelgandek ko'radi.

Shuning uchun kube-proxy trafik yo'lida turgan proxy emas: u faqat qoidalarni yozadi, paketlarni kernel o'zi yo'naltiradi. kube-proxy o'chib qolsa ham mavjud qoidalar ishlayveradi, faqat yangilanmay qoladi.

| Rejim | Holati | Izoh |
|-------|--------|------|
| `iptables` | hozirgi standart | har Service uchun qoidalar zanjiri, backend tasodifiy tanlanadi |
| `nftables` | 1.33 dan stable, kelajakdagi standart | kernel 5.13+ talab qiladi, katta klasterlarda tezroq |
| `ipvs` | 1.35 dan deprecated | yangi klasterda tanlanmaydi |

Rejim almashishi yangilanishda kutilmagan bo'lmasligi uchun uni kube-proxy konfiguratsiyasida aniq ko'rsatish tavsiya etiladi. Ba'zi CNI'lar (Cilium) kube-proxy'ni butunlay eBPF bilan almashtiradi; tushuncha o'zgarmaydi, amalga oshirish boshqa.

### Ishlaydigan misol

Node ichidagi qoidalardan Service'ga tegishli kirish qatorini topamiz:

```
$ docker exec dev-worker iptables-save | grep 10.96.142.17
-A KUBE-SERVICES -d 10.96.142.17/32 -p tcp -m comment --comment "net/echo:http cluster IP" -m tcp --dport 80 -j KUBE-SVC-<HASH1>
-A KUBE-SVC-<HASH1> ! -s 10.244.0.0/16 -d 10.96.142.17/32 -p tcp -m comment --comment "net/echo:http cluster IP" -m tcp --dport 80 -j KUBE-MARK-MASQ
```

- `KUBE-SERVICES` barcha Service'lar uchun umumiy kirish zanjiri. Birinchi qator: "manzil `10.96.142.17`, protokol TCP, port 80 bo'lsa, `KUBE-SVC-<HASH1>` zanjiriga o't".
- `--comment "net/echo:http ..."` kube-proxy qo'ygan izoh: namespace, Service va port nomi. Qoidalarni o'qishda eng foydali qism.
- Ikkinchi qator: manba pod tarmog'idan tashqarida bo'lsa (`! -s 10.244.0.0/16`), paketga SNAT belgisi qo'yiladi. Bu 5-bo'limdagi manba IP mavzusiga bog'lanadi.

`KUBE-SVC-<HASH1>` zanjiri ichida har backend uchun bittadan qoida bor, ular `KUBE-SEP-...` (service endpoint) zanjirlariga olib boradi, oxirgisida esa haqiqiy DNAT:

```
$ docker exec dev-worker iptables-save | grep 'DNAT' | grep 'net/echo'
-A KUBE-SEP-<HASH2> -p tcp -m comment --comment "net/echo:http" -m tcp -j DNAT --to-destination 10.244.1.5:8080
...
```

`--to-destination 10.244.1.5:8080` paket manzili shunga almashtiriladi. Backend qanday ehtimollik bilan tanlanishini `KUBE-SVC-<HASH1>` zanjirini to'liq o'qib 6-vazifada o'zingiz topasiz. Klaster nftables rejimida bo'lsa, xuddi shu tuzilish `docker exec dev-worker nft list ruleset` da boshqa sintaksisda ko'rinadi.

ClusterIP interfeysda yo'qligini ham tekshirish oson: `docker exec dev-worker ip addr` chiqishida `10.96.` bilan boshlanadigan manzil topilmaydi.

### Oqibatlari

- Balanslash ulanish (connection) darajasida, so'rov darajasida emas. HTTP keep-alive yoki gRPC bilan bitta uzoq ulanish doim bitta pod'ga boradi; yangi pod'lar qo'shilsa ham mavjud ulanishlar ko'chmaydi. Node'dagi `http.Agent({ keepAlive: true })` aynan shunday uzoq ulanish yaratadi.
- ClusterIP'ga `ping` odatda ishlamaydi: qoidalar faqat Service portlari uchun yozilgan, ICMP uchun emas. Bu nosozlik belgisi emas.
- Tanlangan pod javob bermasa kube-proxy boshqasiga qayta urinmaydi. Sog'lom bo'lmagan pod'ni ro'yxatdan chiqarish readiness probe'ning ishi.

### Real ishda qachon kerak

"Service bor, endpoint'lar bor, lekin ulanib bo'lmayapti" holatida (7-bo'limdagi 5-qadam) node qoidalariga qarash kerak bo'ladi. gRPC yoki baza connection pool'li servislarda yuk notekisligini tushuntirish ham shu bo'limdan.

### Nima uchun shunday

Har node'da qoida yozish markaziy balanserga nisbatan ikki afzallik beradi: yagona nosozlik nuqtasi yo'q va qo'shimcha "hop" yo'q (paket to'g'ri pod'ga boradi). Narxi: balanslash L4'da va sodda (L7 qayta urinish, so'rov darajasidagi taqsimot yo'q). Bunday imkoniyatlar kerak bo'lsa ustiga L7 qatlam qo'yiladi: Gateway (6-bo'lim) yoki service mesh (bu modulga kirmaydi). iptables'dan nftables'ga o'tish ham masshtab sababli: iptables qoidalari ro'yxat bo'ylab ketma-ket tekshiriladi, minglab Service'da sekinlashadi.

## 3. Service turlari

### Bu nima

`spec.type` Service'ga kim va qanday ulana olishini belgilaydi.

| Tur | Kim ulana oladi | Qanday |
|-----|-----------------|--------|
| `ClusterIP` (standart) | klaster ichidagilar | virtual IP |
| `NodePort` | node IP'siga yeta oladigan har kim | ClusterIP + har node'da bir xil port (standart oraliq 30000–32767) |
| `LoadBalancer` | tashqi klientlar | NodePort + tashqi load balancer, uni cloud yoki boshqa controller yaratadi |
| `ExternalName` | klaster ichidagilar | hech qanday proxy yo'q, DNS `CNAME` qaytaradi |

### Mexanizm: turlar bir-birining ustiga quriladi

- `NodePort` Service yaratilganda unga ClusterIP ham beriladi. kube-proxy har node'da "shu node'ning `<nodePort>` portiga kelgan paketni Service backend'lariga DNAT qil" degan qo'shimcha qoida yozadi. Pod qaysi node'da bo'lishidan qat'i nazar, istalgan node'ning shu porti ishlaydi.
- `LoadBalancer` Service NodePort'ning hamma qismini oladi va ustiga "menga tashqi manzil kerak" degan so'rovni qo'shadi. Uni Kubernetes'ning o'zi bajarmaydi: cloud controller (yoki uning o'rnini bosuvchi) tashqi balanser yaratadi, uni node'larning NodePort'iga (yoki to'g'ridan-to'g'ri pod'larga) yo'naltiradi va manzilni Service'ning `status.loadBalancer.ingress` maydoniga yozadi.
- `ExternalName` umuman boshqa: ClusterIP yo'q, kube-proxy qoidasi yo'q, faqat DNS javobi.

### Ishlaydigan misol: NodePort

```yaml
spec:
  type: NodePort
  selector:
    app: echo
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080   # optional; omitted means "pick a free one from the range"
```

```
$ kubectl get svc echo-np
NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
echo-np   NodePort   10.96.77.201   <none>        80:30080/TCP   4s
$ kubectl get nodes -o wide
NAME                STATUS   ROLES           AGE   VERSION    INTERNAL-IP   ...
dev-control-plane   Ready    control-plane   <..>  v1.<..>    172.18.0.4    ...
dev-worker          Ready    <none>          <..>  v1.<..>    172.18.0.2    ...
dev-worker2         Ready    <none>          <..>  v1.<..>    172.18.0.3    ...
```

- `PORT(S) 80:30080/TCP`: chapda Service porti (ClusterIP uchun), o'ngda NodePort. ClusterIP ham berilganiga e'tibor bering.
- `INTERNAL-IP` node konteynerlarining `kind` Docker tarmog'idagi manzillari.

```
$ docker run --rm --network kind curlimages/curl:8.10.1 -s http://172.18.0.2:30080/hostname
echo-<5d9f7c>-<k2m4x>
```

Bu buyruq Zorin'da ham, macOS'da ham ishlaydi. Zorin'da `curl http://172.18.0.2:30080/hostname` host'ning o'zidan ham ishlaydi, macOS'da esa javobsiz qoladi (Laboratoriya bo'limi).

### LoadBalancer bulutsiz muhitda

`type: LoadBalancer` bu so'rov: "kimdir menga tashqi manzil bersin". Cloud'da buni cloud controller bajaradi (AWS'da NLB yaratiladi). Bunday controller yo'q klasterda `EXTERNAL-IP` abadiy `<pending>` turadi, lekin Service'ning ClusterIP va NodePort qismi ishlayveradi.

| Muhit | Yechim |
|-------|--------|
| kind | `cloud-provider-kind`: har Service uchun Docker'da proxy konteyner ko'taradi va unga `kind` tarmog'idan IP beradi |
| k3s | ichki ServiceLB: node IP'larini tashqi manzil sifatida ishlatadi |
| Bare metal, kubeadm | MetalLB: berilgan IP pool'idan manzil ajratadi va uni L2 (ARP) yoki BGP orqali tarmoqqa e'lon qiladi |

`cloud-provider-kind` ishlab turganda:

```
$ kubectl get svc echo-lb
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
echo-lb   LoadBalancer   10.96.31.90    172.18.0.5    80:31744/TCP   20s
$ docker ps --format '{{.Names}}\t{{.Ports}}' | grep kindccm
kindccm-<hash>	...
```

- `EXTERNAL-IP 172.18.0.5`: proxy konteynerning `kind` tarmog'idagi IP'si. Unga 80-portda ulangan trafik node'lar orqali pod'larga boradi.
- `PORT(S) 80:31744/TCP`: NodePort avtomatik ajratilgan, LoadBalancer uning ustiga qurilgani shu yerda ko'rinadi.
- `docker ps` dagi `kindccm-...` nomli konteyner shu Service'ning "tashqi balanseri". macOS'da uning `PORTS` ustunida `127.0.0.1:<host-port>->80/tcp` ham ko'rinadi.

**Tuzoq: har Service uchun alohida LoadBalancer.** Cloud'da har LoadBalancer Service alohida pullik resurs. O'nta HTTP servis uchun o'nta balanser o'rniga bitta balanser va uning orqasida Ingress yoki Gateway ishlatiladi (6-bo'lim).

### ExternalName

```yaml
spec:
  type: ExternalName
  externalName: db.example.com
```

Klaster ichida `mydb` nomi `db.example.com` ga `CNAME` bo'ladi (CNAME bu "bu nom aslida boshqa nomning taxallusi" degan DNS yozuvi, network moduli). Cheklovi: bu faqat DNS darajasida. HTTP klient `Host: mydb` header'i yuboradi, TLS'da esa sertifikat `mydb` nomiga mos kelmaydi; shuning uchun HTTP va HTTPS servislar bilan muammo chiqadi, baza kabi protokollarga ko'proq mos.

### Real ishda qachon kerak

ClusterIP: deyarli hamma ichki servislar. NodePort: o'zi alohida kam ishlatiladi; tashqi balanser (masalan on-prem F5 yoki HAProxy) node'larga yo'naltirilgan sxemalarda va laboratoriyada. LoadBalancer: klasterga kirish nuqtasi (odatda bittasi, Gateway controller oldida). ExternalName: tashqi servisni klaster ichidagi barqaror nom ortiga yashirish, keyinchalik uni klaster ichiga ko'chirish oson bo'lishi uchun.

### Nima uchun shunday

Turlarning qatlamli tuzilishi ataylab: har yangi tur oldingisiga bitta narsa qo'shadi, shuning uchun kube-proxy faqat ikkita mexanizmni bilsa yetadi (ClusterIP va NodePort qoidalari). Tashqi balanserni yaratish Kubernetes yadrosidan cloud controller'ga chiqarilgan, chunki har provayderning API'si har xil. Shu ajratish tufayli kind'da `cloud-provider-kind`, bare metal'da MetalLB xuddi shu Service obyektini "bajaradi".

## 4. Klaster DNS

### Bu nima

CoreDNS (`kube-system` dagi Deployment, uning oldida `kube-dns` nomli Service) klaster ichida Service va pod'lar uchun DNS javob beradi. U API'dan Service'larni kuzatadi va `<service>.<namespace>.svc.cluster.local` ko'rinishidagi nomlarga ClusterIP qaytaradi.

### Mexanizm

Har pod'ning `/etc/resolv.conf` fayli kubelet tomonidan yoziladi:

```
$ kubectl exec client -- cat /etc/resolv.conf
search net.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

- `nameserver 10.96.0.10` CoreDNS oldidagi `kube-dns` Service'ining ClusterIP'si. DNS so'rovi ham 2-bo'limdagi mexanizm orqali CoreDNS pod'iga boradi.
- `search` ro'yxati: qisqa nomga ketma-ket qo'shib ko'riladigan suffikslar. Birinchisi pod'ning o'z namespace'i (`net`).
- `options ndots:5`: nomda 5 tadan kam nuqta bo'lsa, avval `search` suffikslari sinab ko'riladi.

| Nom | Qayerdan ishlaydi |
|-----|-------------------|
| `echo` | faqat o'sha namespace ichidan |
| `echo.net` | istalgan namespace'dan |
| `echo.net.svc.cluster.local` | to'liq nom (FQDN) |

```
$ kubectl exec client -- nslookup echo
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	echo.net.svc.cluster.local
Address: 10.96.142.17
```

- `Server` va `Address` qaysi DNS server javob bergani.
- `Name` to'liq nom: resolver `echo` ga birinchi suffiksni qo'shdi va javob oldi.
- `Address` Service'ning ClusterIP'si, pod IP'si emas. busybox `nslookup` chiqishida AAAA (IPv6) so'rovi haqida qo'shimcha qatorlar ham bo'lishi mumkin.

Oddiy Service uchun `A` yozuvi ClusterIP'ni qaytaradi. Nomlangan portlar uchun `SRV` yozuvi ham bor: `_http._tcp.echo.net.svc.cluster.local` (port raqami va nomni qaytaradi).

### ndots tuzog'i

Nomda 5 tadan kam nuqta bo'lsa, resolver avval `search` ro'yxatidagi har suffiksni qo'shib ko'radi. `api.github.com` (2 nuqta) uchun avval `api.github.com.net.svc.cluster.local`, keyin yana ikkita mavjud bo'lmagan nom so'raladi, shundan keyingina asl nom. Tashqi API'larga ko'p murojaat qiladigan ilovada bu DNS yukini bir necha barobar oshiradi. Yechim: nom oxiriga nuqta qo'yish (`api.github.com.`, "bu allaqachon to'liq nom" degani) yoki pod'da `dnsConfig.options` orqali `ndots` ni kamaytirish.

### Headless Service

`clusterIP: None` bo'lsa virtual IP ajratilmaydi va kube-proxy ishtirok etmaydi. DNS so'rovi to'g'ridan-to'g'ri barcha tayyor pod'lar IP'larini qaytaradi (bir nechta `A` yozuv). Ishlatilishi: klient o'zi balanslashni xohlasa (gRPC klient kutubxonalari barcha IP'ni olib, har biriga ulanish ochadi), yoki har pod'ga alohida murojaat kerak bo'lsa (StatefulSet: `web-0.web.net.svc.cluster.local`, 4-dars va 12-dars).

### Real ishda qachon kerak

"Boshqa namespace'dagi servisga ulanmayapti" shikoyatining yarmi qisqa nom ishlatilganidan. Tashqi API'larga ko'p murojaat qiladigan servislarda CoreDNS yuki va DNS kechikishi `ndots` tufayli bo'ladi. StatefulSet va gRPC uchun headless Service odatiy.

### Nima uchun shunday

`ndots:5` qisqa nomlar har doim ishlashi uchun tanlangan: `echo.net` va hatto `_http._tcp.echo` kabi nuqtali nomlar ham `search` orqali to'g'ri hal bo'ladi. Narxi tashqi nomlar uchun ortiqcha so'rovlar. DNS'ni Service mexanizmidan ajratish ham muhim: klient oddiy DNS ishlatadi, hech qanday maxsus kutubxona kerak emas. Shu sababli istalgan tildagi ilova (Node, Go, Python) klasterga o'zgarishsiz ko'chadi.

## 5. Trafik siyosatlari

### Bu nima

Service'da trafik qaysi pod'ga borishini o'zgartiradigan uchta maydon bor:

| Maydon | Qiymatlar | Ta'siri |
|--------|-----------|---------|
| `sessionAffinity` | `None` (standart), `ClientIP` | `ClientIP`: bitta manba IP'dan kelgan ulanishlar bitta pod'ga boradi (standart muddat 10800 soniya) |
| `externalTrafficPolicy` | `Cluster` (standart), `Local` | tashqi trafik (NodePort, LoadBalancer) qaysi pod'larga borishi |
| `internalTrafficPolicy` | `Cluster` (standart), `Local` | klaster ichidagi trafik faqat shu node'dagi pod'larga borsinmi |

### Mexanizm: externalTrafficPolicy

Tashqi paket node'ning NodePort'iga keladi. `Cluster` rejimida kube-proxy istalgan node'dagi pod'ni tanlaydi. Agar pod boshqa node'da bo'lsa, paket o'sha node'ga uzatiladi, javob esa xuddi shu yo'l bilan qaytishi kerak. Buni ta'minlash uchun node paketning manba manzilini o'zinikiga almashtiradi (SNAT, network moduli). Natijada pod klientning haqiqiy IP'sini emas, node IP'sini ko'radi. `Local` rejimida kube-proxy faqat shu node'dagi pod'larni ishlatadi, uzatish yo'q, SNAT ham yo'q.

| | `Cluster` | `Local` |
|---|-----------|---------|
| Trafik qaysi pod'ga | istalgan node'dagi | faqat paket kelgan node'dagi |
| Klient manba IP'si | yo'qoladi (node SNAT qiladi) | saqlanadi |
| Pod'siz node'ga kelgan paket | boshqa node'ga yo'naltiriladi | tashlab yuboriladi; balanser `healthCheckNodePort` orqali bunday node'larni chetlab o'tadi |
| Taqsimot | tekis | node'lardagi pod soniga qarab notekis bo'lishi mumkin |

### Ishlaydigan misol

`/clientip` bilan, NodePort orqali, `kind` tarmog'idagi konteynerdan (uning IP'si masalan `172.18.0.6`):

```
$ docker run --rm --network kind curlimages/curl:8.10.1 -s http://172.18.0.2:30080/clientip
172.18.0.2:41873
```

`Cluster` rejimida pod klient konteynerining manzilini emas, node manzilini (yoki node'ning ichki manzilini) ko'rdi: SNAT ishlagan. Xuddi shu Service'ni `externalTrafficPolicy: Local` qilib, so'rovni pod'i bor node'ga yuborsangiz, javobda klient konteynerining o'z IP'si chiqadi; pod'i yo'q node'ga yuborsangiz, javob kelmaydi. Aniq qaysi manzil ko'rinishini va LoadBalancer orqali nima bo'lishini 14-vazifada o'zingiz o'lchaysiz: `cloud-provider-kind` ning proxy konteyneri ham o'z navbatida yangi ulanish ochadi, buni hisobga oling.

### Real ishda qachon kerak

Ilovaga klientning haqiqiy IP'si kerak bo'lsa (audit, rate limit, geolokatsiya) `Local` tanlanadi, yoki L7 proxy'ning `X-Forwarded-For` header'iga tayaniladi (Express'dagi `app.set('trust proxy', ...)` aynan shu header bilan ishlaydi). `sessionAffinity` eski, sessiyani xotirada saqlaydigan ilovalar uchun vaqtinchalik yechim. `internalTrafficPolicy: Local` har node'dagi DaemonSet agent'iga (masalan log yoki metrika yig'uvchi) murojaatda trafikni node ichida ushlab turish uchun.

### Nima uchun shunday

Standart `Cluster` "har doim ishlaydi" variant: qaysi node'ga paket kelsa ham javob bor. `Local` samaradorlik va manba IP uchun ishonchlilik va tekis taqsimotdan voz kechadi, shuning uchun u ongli tanlov sifatida alohida qo'yilgan. `healthCheckNodePort` bu ikkisini yarashtiradi: tashqi balanser har node'dan "sizda pod bormi?" deb so'raydi va pod'siz node'ga trafik yubormaydi.

## 6. Ingress va Gateway API

### Bu nima

Service L4: IP va port. HTTP darajasidagi yo'naltirish (host, path, header), TLS termination va bitta kirish nuqtasi orqali ko'p servis uchun L7 qatlam kerak. Uning uchun Kubernetes'da ikki API bor: 3-darsda ko'rgan Ingress va undan keyingi avlod Gateway API.

| | Ingress | Gateway API |
|---|---------|-------------|
| Holati | barqaror, lekin muzlatilgan: yangi imkoniyat qo'shilmaydi | faol rivojlanmoqda, Kubernetes loyihasi tavsiya qiladi |
| O'rnatilishi | API ichki, controller alohida | CRD'lar va controller alohida |
| Obyektlar | bitta `Ingress` | `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute` (hammasi `gateway.networking.k8s.io/v1`) |
| Rollar | bitta obyektda hammasi | infratuzilma (GatewayClass), klaster operatori (Gateway), ilova jamoasi (HTTPRoute) |
| Kengaytma | controller'ga xos annotation'lar | standart maydonlar: vaznli taqsimot, header bo'yicha yo'naltirish, redirect, rewrite |
| Namespace'lararo | cheklangan | `allowedRoutes` va `ReferenceGrant` bilan nazorat qilinadi |

CRD (CustomResourceDefinition) bu Kubernetes API'ga yangi obyekt turini qo'shadigan ta'rif: Gateway API obyektlari klasterga CRD sifatida o'rnatiladi.

### Mexanizm

Uch obyekt zanjiri:

1. **GatewayClass**: "qaysi controller Gateway'larni amalga oshiradi". kind'da `cloud-provider-kind` Gateway API CRD'larini o'zi o'rnatadi va `cloud-provider-kind` nomli GatewayClass beradi.
2. **Gateway**: "qaysi portda, qaysi protokolda tinglash va qaysi namespace'lardan route qabul qilish". Controller Gateway uchun haqiqiy proxy ko'taradi (kind'da yana Docker konteyneri) va unga manzil beradi.
3. **HTTPRoute**: "qaysi so'rov (host, path, header) qaysi Service'ga". `parentRefs` orqali Gateway'ga ulanadi, `backendRefs` orqali oddiy Service'larga ishora qiladi.

Muhim: Gateway proxy'si trafikni Service'ning ClusterIP'siga emas, odatda to'g'ridan-to'g'ri EndpointSlice'dagi pod IP'lariga yuboradi. Shuning uchun u so'rov darajasida balanslay oladi (2-bo'limdagi ulanish darajasidagi cheklov bu yerda yo'q).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gw
spec:
  gatewayClassName: cloud-provider-kind
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo
spec:
  parentRefs:
    - name: main-gw              # the Gateway this route attaches to
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: echo
          port: 80
```

### Ishlaydigan misol

```
$ kubectl get gatewayclass
NAME                  CONTROLLER                        ACCEPTED   AGE
cloud-provider-kind   kind.sigs.k8s.io/gateway-controller   True       <..>
$ kubectl get gateway
NAME      CLASS                 ADDRESS      PROGRAMMED   AGE
main-gw   cloud-provider-kind   172.18.0.7   True         25s
```

- `ACCEPTED True`: controller bu GatewayClass'ni o'ziniki deb qabul qilgan. `CONTROLLER` ustunidagi aniq qiymat versiyaga qarab farq qilishi mumkin.
- `ADDRESS` Gateway proxy'sining manzili, `PROGRAMMED True` esa proxy sozlanib trafik qabul qilishga tayyorligini bildiradi.

`kubectl describe httproute echo` ning `Status` qismida har `parentRefs` uchun shartlar bor, asosiylari `Accepted` (Gateway route'ni qabul qildimi) va `ResolvedRefs` (`backendRefs` dagi Service'lar topildimi). Route ishlamasa birinchi qaraladigan joy shu.

3-darsda aytilgani esda tursin: ingress-nginx 2026-yil martdan qo'llab-quvvatlanmaydi. Yangi loyihada tanlov Gateway API'ni qo'llaydigan controller'lar orasidan qilinadi; Ingress'ni bilish esa mavjud klasterlarni tushunish va migratsiya uchun kerak.

### Real ishda qachon kerak

Klasterga HTTP kirishning standart sxemasi: bitta LoadBalancer Service, uning ortida Gateway proxy'si, undan har ilovaning HTTPRoute'i. TLS (8-dars), canary deploy uchun vaznli taqsimot (17-vazifa) va host bo'yicha bir nechta saytni bitta IP'da ushlash shu qatlamda.

### Nima uchun shunday

Ingress'ning muammosi hamma narsa bitta obyektda va har controller o'z imkoniyatlarini annotation'larda bergani edi: manifest bir controller'dan boshqasiga ko'chmasdi. Gateway API rollarni ajratadi (platforma jamoasi Gateway'ni, ilova jamoasi faqat o'z HTTPRoute'ini boshqaradi) va keng tarqalgan imkoniyatlarni standart maydonlarga chiqaradi. Uni CRD qilib chiqarish esa API'ni Kubernetes reliz siklidan mustaqil rivojlantirish imkonini beradi.

## 7. Service ulanishini qatlamma-qatlam debug qilish

### Bu nima

"Servisga ulanib bo'lmayapti" shikoyatida taxmin bilan emas, tartib bilan, ichkaridan tashqariga qarab yuriladi. Har qadam oldingisi to'g'ri bo'lgandagina ma'noli: pod javob bermasa, DNS'ni tekshirish vaqtni behuda ketkazadi.

### Mexanizm: tekshirish zinapoyasi

| # | Savol | Buyruq | Noto'g'ri bo'lsa |
|---|-------|--------|------------------|
| 1 | Pod'lar ishlayaptimi va `Ready` mi? | `kubectl get pods -o wide` | 3–4 darslardagi pod debug |
| 2 | Ilova pod IP'sida javob beradimi? | klient pod'dan `wget -qO- http://<pod-ip>:<port>` | ilova boshqa portda yoki faqat `127.0.0.1` da tinglayapti |
| 3 | Service bormi, porti to'g'rimi? | `kubectl get svc`, `describe svc` | `targetPort` konteyner portiga mos emas |
| 4 | Service'ning endpoint'lari bormi? | `kubectl get endpointslices -l kubernetes.io/service-name=NAME` | selector pod label'lariga mos emas, yoki pod'lar `Ready` emas |
| 5 | ClusterIP javob beradimi? | klient pod'dan `wget -qO- http://<cluster-ip>:<port>` | kube-proxy yoki CNI muammosi, NetworkPolicy |
| 6 | DNS nom hal bo'ladimi? | klient pod'dan `nslookup NAME` | noto'g'ri namespace, CoreDNS muammosi |
| 7 | Tashqi kirish ishlaydimi? | NodePort, LoadBalancer IP, Gateway manzili | `EXTERNAL-IP` `<pending>`, firewall, `externalTrafficPolicy: Local` va pod'siz node |
| 8 | L7 qoidalar to'g'rimi? | `describe ingress`, `describe httproute` (`status` dagi shartlar) | host yoki path mos emas, class noto'g'ri, backend Service nomi xato |

Eng ko'p uchraydigan uch sabab: selector va label mos emas (4-qadam, endpoint'lar bo'sh), `targetPort` xato (3-qadam), pod'lar `Ready` emas (1-qadam).

### Xato matnini o'qish

| Alomat | Ma'nosi | Odatiy sabab |
|--------|---------|--------------|
| `Connection refused` | paket manzilga yetdi, lekin portda hech kim tinglamayapti yoki qoida rad etdi | port xato, ilova `127.0.0.1` da, Service'da endpoint yo'q |
| `timed out` | paket yo'lda yo'qoldi, hech kim javob bermadi | firewall, NetworkPolicy, mavjud bo'lmagan IP, `Local` siyosat va pod'siz node |
| `bad address`, `Name or service not known` | DNS nomni hal qilmadi | namespace xato, nom xato |
| HTTP `404` | L7 qatlamga yetdi, lekin mos route yoki path yo'q | HTTPRoute `matches`, host |
| HTTP `503`, `502` | proxy ishlayapti, lekin backend yo'q yoki javob bermadi | backend Service'da endpoint yo'q |

busybox `wget` da birinchisi `wget: can't connect to remote host (...): Connection refused`, ikkinchisi `wget: download timed out` ko'rinishida chiqadi.

### Asboblar

Debug uchun qulay image: `nicolaka/netshoot:v0.13` (ichida `dig`, `curl`, `tcpdump`, `ss` va boshqalar). Vaqtinchalik pod sifatida: `kubectl run tmp --rm -it --image=nicolaka/netshoot:v0.13 -- bash`. Ilova pod'ining tarmoq namespace'iga ulanish (pod ichida shell bo'lmasa ham): `kubectl debug -it POD --image=nicolaka/netshoot:v0.13`. U pod'ga vaqtinchalik "ephemeral" konteyner qo'shadi, u pod bilan bir xil IP va portlarni ko'radi.

### Real ishda qachon kerak

Har kuni. Production'da bu jadval incident vaqtida runbook bo'lib xizmat qiladi (20-vazifa). Tartibga rioya qilish "DNS'ni qayta ishga tushiramiz", "pod'larni o'chiramiz" kabi tasodifiy harakatlardan saqlaydi.

### Nima uchun shunday

Ichkaridan tashqariga yurish qatlamlar bog'liqligidan kelib chiqadi: har qatlam pastdagisiga tayanadi (Gateway Service'ga, Service endpoint'larga, endpoint'lar pod'larga). Pastki qatlam ishlashini isbotlamay turib yuqorisini tekshirish xatoning haqiqiy joyini yashiradi. Network modulidagi "ping, keyin port, keyin DNS, keyin HTTP" tartibining Kubernetes versiyasi shu.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Service | selector'ga mos pod'larga barqaror IP, DNS nomi va balanslash beradigan obyekt |
| ClusterIP | Service'ning faqat klaster ichida ishlaydigan virtual IP'si, hech qaysi interfeysda yo'q |
| `port` / `targetPort` | Service'dagi port / pod'dagi konteyner porti |
| EndpointSlice | Service'ning hozirgi backend'lari (IP, port, `ready`) yozilgan obyekt |
| kube-proxy | har node'da Service'larni kernel qoidalariga aylantiradigan agent |
| DNAT / SNAT | paketning manzil / manba qismini almashtirish |
| conntrack | kernel'ning ulanishlar jadvali, javob paketlarini teskari almashtirishda ishlatiladi |
| NodePort | har node'da bir xil portda Service'ni ochadigan tur |
| LoadBalancer | tashqi balanser so'raydigan tur; uni cloud controller yoki uning o'rnini bosuvchi bajaradi |
| `cloud-provider-kind` | kind uchun LoadBalancer va Gateway'ni Docker konteynerlari bilan amalga oshiradigan jarayon |
| MetalLB | bare metal klasterda LoadBalancer IP'larini ajratib, ARP yoki BGP bilan e'lon qiladigan controller |
| ExternalName | ClusterIP'siz, faqat DNS `CNAME` qaytaradigan Service |
| CoreDNS | klaster ichidagi DNS server |
| `ndots` | nomni to'liq deb hisoblash uchun kerak bo'lgan nuqtalar soni chegarasi |
| Headless Service | `clusterIP: None`, DNS to'g'ridan-to'g'ri pod IP'larini qaytaradi |
| `externalTrafficPolicy` | tashqi trafik istalgan node'dagi pod'ga (`Cluster`) yoki faqat shu node'dagisiga (`Local`) borishi |
| `sessionAffinity` | bitta klient IP'sini bitta pod'ga bog'lash |
| Ingress | eski, muzlatilgan L7 yo'naltirish API'si |
| Gateway API | GatewayClass, Gateway va Route'lardan iborat yangi L7 API |
| HTTPRoute | HTTP so'rovlarini mos qoidalar bo'yicha Service'larga yo'naltiradigan obyekt |
| CRD | Kubernetes API'ga yangi obyekt turini qo'shadigan ta'rif |

## Tuzoqlar

- Selector'dagi bitta harf xatosi: Service bor, endpoint'lar bo'sh, hech qanday xato xabari yo'q.
- `port` va `targetPort` ni adashtirish.
- Ilova faqat `127.0.0.1` da tinglaydi: pod ichidan ishlaydi, Service orqali `connection refused`. Node'da `server.listen(8080, '127.0.0.1')` yozilgan Express ilova aynan shunday; konteynerda `0.0.0.0` kerak.
- Readiness probe'siz pod'lar: Service ishga tushib ulgurmagan pod'ga trafik yuboradi.
- Uzoq yashaydigan ulanishlar (gRPC, HTTP/2, baza pool'i) bilan Service balanslashiga ishonish: bitta pod hamma yukni oladi.
- `ndots:5` tufayli tashqi nomlarga ortiqcha DNS so'rovlari.
- Bulutsiz klasterda `type: LoadBalancer` yaratib, `<pending>` ni kutish.
- `externalTrafficPolicy: Cluster` bilan klient IP'siga tayanadigan mantiq (rate limit, allowlist): hamma so'rov node IP'sidan kelgandek ko'rinadi.
- Har servis uchun alohida cloud load balancer: ortiqcha xarajat.
- NodePort'ni internetga ochiq qoldirish: 30000–32767 oralig'idagi har port har node'da ochiq bo'ladi.
- macOS'da host'dan `172.18.x.y` ga `curl` qilib, "LoadBalancer ishlamayapti" deb xulosa qilish: manzil Docker Desktop VM'i ichida (Laboratoriya bo'limi).
- `kubectl port-forward svc/...` bilan sinab, Service balanslashini tekshirdim deb o'ylash: port-forward bitta pod'ga tunnel, kube-proxy ishtirok etmaydi.
- `cloud-provider-kind` ni to'xtatib unutish: Gateway va LoadBalancer manzillari yangilanmaydi, yangi Service'lar `<pending>` qoladi.

## Manbalar

- https://kubernetes.io/docs/concepts/services-networking/service/ – Service (majburiy)
- https://kubernetes.io/docs/reference/networking/virtual-ips/ – virtual IP'lar va kube-proxy rejimlari
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/ – EndpointSlice
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ – Service va pod'lar uchun DNS
- https://kubernetes.io/docs/tutorials/services/source-ip/ – manba IP va `externalTrafficPolicy`
- https://kubernetes.io/docs/concepts/services-networking/gateway/ – Gateway API haqida
- https://gateway-api.sigs.k8s.io/ – Gateway API hujjatlari
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/ – Service'ni debug qilish (majburiy)
- https://kind.sigs.k8s.io/docs/user/loadbalancer/ – kind'da LoadBalancer
- https://github.com/kubernetes-sigs/cloud-provider-kind – `cloud-provider-kind`, macOS bo'limi bilan
- https://metallb.io/concepts/ – MetalLB tushunchalari
- https://github.com/nicolaka/netshoot – netshoot debug image'i

---

## Birga bajaramiz

Vazifalardan boshqa misol: HTTP emas, TCP servis. `cache` namespace'ida Redis ko'taramiz, unga boshqa namespace'dagi klientdan nom orqali ulanamiz, qasddan DNS xatosiga tushib zinapoya bo'yicha topamiz, keyin "Service balanslashi stateful servisni buzadi" holatini ko'ramiz. Ikkala mashinada bir xil, faqat klaster ichida. Redis image'i `redis:7.4` (multi-arch, ichida `redis-cli` ham bor). IP va suffikslar sizda boshqa bo'ladi.

1. Servis va Service:

```
$ kubectl create namespace cache
namespace/cache created
$ kubectl -n cache create deployment redis --image=redis:7.4 --port=6379
deployment.apps/redis created
$ kubectl -n cache expose deployment redis --port=6379
service/redis exposed
$ kubectl -n cache rollout status deployment/redis
deployment "redis" successfully rolled out
```

`kubectl expose` Deployment'ning pod shablonidagi label'lardan selector yasaydi (`app: redis`) va `--port` ni ham `port`, ham `targetPort` qiladi.

2. Endpoint'larni tekshiramiz (zinapoyaning 1 va 4-qadamlari):

```
$ kubectl -n cache get pods -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE
redis-<7c9d8>-<qq2lp>    1/1     Running   0          30s   10.244.2.9   dev-worker2
$ kubectl -n cache get endpointslices -l kubernetes.io/service-name=redis
NAME          ADDRESSTYPE   PORTS   ENDPOINTS    AGE
redis-<abcd>  IPv4          6379    10.244.2.9   30s
```

Pod IP'si slice'da bor: Service va pod bog'langan.

3. Klient boshqa namespace'da. `walk` namespace'ida vaqtinchalik pod'dan qisqa nom bilan ulanamiz:

```
$ kubectl create namespace walk
namespace/walk created
$ kubectl -n walk run rcli --rm -it --restart=Never --image=redis:7.4 -- redis-cli -h redis PING
Could not connect to Redis at redis:6379: Name or service not known
pod "rcli" deleted
```

Xato matni DNS haqida (`Name or service not known`), port yoki ulanish haqida emas. Zinapoyaning 6-qadami: `walk` dagi pod'ning `search` ro'yxati `walk.svc.cluster.local` bilan boshlanadi, `redis.walk.svc.cluster.local` esa mavjud emas.

4. Nomni namespace bilan beramiz:

```
$ kubectl -n walk run rcli --rm -it --restart=Never --image=redis:7.4 -- redis-cli -h redis.cache PING
PONG
pod "rcli" deleted
```

`redis.cache` ikki qismli nom, `search` dagi `svc.cluster.local` qo'shilib `redis.cache.svc.cluster.local` bo'ldi va ClusterIP'ga hal bo'ldi.

5. Endi stateful servisni ko'paytirib ko'ramiz. Ikki replika, har biri o'z xotirasida alohida ma'lumot saqlaydi:

```
$ kubectl -n cache scale deployment redis --replicas=2
deployment.apps/redis scaled
$ kubectl -n walk run rcli --rm -it --restart=Never --image=redis:7.4 -- redis-cli -h redis.cache SET greeting hello
OK
pod "rcli" deleted
```

Endi `GET` ni bir necha marta, har safar yangi pod (demak yangi TCP ulanish) bilan:

```
$ kubectl -n walk run rcli --rm -it --restart=Never --image=redis:7.4 -- redis-cli -h redis.cache GET greeting
"hello"
pod "rcli" deleted
$ kubectl -n walk run rcli --rm -it --restart=Never --image=redis:7.4 -- redis-cli -h redis.cache GET greeting
(nil)
pod "rcli" deleted
```

- Har `redis-cli` chaqiruvi yangi ulanish, kube-proxy har ulanish uchun backend'ni qayta tanlaydi (2-bo'lim).
- `(nil)`: bu ulanish `SET` bo'lmagan ikkinchi Redis pod'iga tushdi. Natija tasodifiy, sizda ketma-ketlik boshqa bo'lishi mumkin; bir necha marta takrorlang.
- Xulosa: Service pod'lar bir-biriga teng (stateless) deb faraz qiladi. O'z holatini saqlaydigan servisni shunchaki scale qilish ma'lumotni bo'lib tashlaydi. To'g'ri yo'l bitta yoziladigan instance, replikatsiya va StatefulSet bilan headless Service (12-dars).

6. Tozalash:

```
$ kubectl delete namespace cache walk
namespace "cache" deleted
namespace "walk" deleted
```

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 1 | 1-bo'lim: selector, `port`/`targetPort` |
| 2 | 1-bo'lim: EndpointSlice; 7-bo'lim: 1 va 4-qadamlar |
| 3–4 | 4-bo'lim: `search` ro'yxati va nom shakllari; 7-bo'lim: xato matnini o'qish |
| 5 | 2-bo'lim: ulanish darajasidagi tasodifiy tanlash; 4-bo'lim: headless Service nima uchun kerak |
| 6 | Laboratoriya: tozalash |

---

## Vazifalar

Barchasini `kubernetes/06-services/` papkasida bajaring (`make new m=kubernetes n=06 name=services`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml` nomi bilan saqlanadi. Hammasi `net` namespace'ida, laboratoriya bo'limidagi `echo` Deployment'i va `client` pod'i bilan. README boshida qaysi mashinada bajarganingizni (Zorin yoki macOS) yozing. "Ish mashinasidan" yoki "tashqaridan" deyilgan joylarda macOS'da Laboratoriya bo'limidagi `docker run --rm --network kind curlimages/curl:8.10.1 ...` yo'lini ishlating.

### A. ClusterIP va endpoint'lar

1. **ClusterIP Service.** `echo` uchun Service manifestini yozing (port 80, targetPort 8080). `client` pod'idan `wget -qO- http://echo/hostname` ni 10 marta chaqiring. Javoblar nimani ko'rsatadi? `kubectl get svc echo -o yaml` da siz yozmagan qaysi maydonlar paydo bo'ldi? ClusterIP qaysi oraliqdan berilgan va uni pod IP'lari oralig'i bilan solishtiring.

2. **EndpointSlices.** `echo` Service'ining EndpointSlice'ini `-o yaml` bilan ko'ring: har endpoint uchun qanday ma'lumot bor (manzil, `conditions`, `nodeName`, `targetRef`)? Bitta terminalda `kubectl get endpointslices -w` qoldirib, Deployment'ni 5 ga, keyin 1 ga scale qiling. Bitta pod'ni o'chiring. Har holatda nima o'zgardi va qancha tez?

3. **Readiness and endpoints.** `echo` Deployment'iga hech qachon o'tmaydigan readiness probe qo'shing (yangi rollout'da `maxUnavailable` tufayli eski pod'lar qolishi mumkin, toza tajriba uchun alohida Deployment va Service yarating). Pod'lar `Running` mi? EndpointSlice'da ular bormi va `ready` qiymati nima? `client` dan so'rov nima qaytaradi: `refused`, `timeout` yoki boshqa? Izohlang.

4. **Port mapping.** Konteyner portiga `name: http` bering va Service'da `targetPort: http` ishlating. Keyin `targetPort` ni noto'g'ri raqamga o'zgartiring: `client` dan qanday xato keladi? EndpointSlice'da port qanday ko'rinadi? Bu nosozlikni 7-bo'limdagi qaysi qadam ushlaydi?

5. **Selector mismatch.** Service selector'ida bitta harfni o'zgartiring. `kubectl get svc`, `describe svc` va EndpointSlice nimani ko'rsatadi? `client` dan qanday xato keladi? Xato xabari qayerda yo'qligiga e'tibor bering va bu nima uchun xavfli ekanini yozing.

### B. kube-proxy

6. **Virtual IP.** `docker exec dev-worker ip addr` natijasida ClusterIP bormi? `docker exec dev-worker iptables-save | grep <cluster-ip>` (yoki klasteringiz nftables rejimida bo'lsa `nft list ruleset`) bilan Service'ga tegishli qoidalarni toping va zanjirni Service'dan pod IP'larigacha kuzating. Backend tanlash qoidasida ehtimollik qanday berilgan? `client` dan ClusterIP'ga `ping` qiling va natijani izohlang. Klasteringizda kube-proxy qaysi rejimda ishlayotganini `kube-system` dagi `kube-proxy` ConfigMap'idan toping.

7. **Load distribution.** `client` dan `echo` ga 300 marta so'rov yuborib (`/hostname`), har pod nechta javob berganini sanang. Taqsimot tekismi? Keyin bitta uzoq ulanish bilan sinang: `kubectl debug` yoki `netshoot` pod'idan `curl` ga bitta buyruqda bir nechta URL berib (ulanish qayta ishlatiladi) javoblarni ko'ring. Farqni izohlang va bu gRPC servislar uchun nimani anglatishini yozing.

### C. DNS

8. **DNS names.** `client` pod'ida `/etc/resolv.conf` ni ko'ring. `nslookup` bilan `echo`, `echo.net`, `echo.net.svc.cluster.local` ni tekshiring. Boshqa namespace'da ikkinchi klient pod yarating: u yerdan qaysi nomlar ishlaydi? `nameserver` manzili qaysi Service'ga tegishli? Nomlangan port uchun `SRV` yozuvini so'rang.

9. **ndots.** `netshoot` pod'idan `dig +search +showsearch example.com` (yoki `nslookup -debug`) bilan tashqi nom uchun nechta so'rov ketishini ko'rsating. `example.com.` (oxirida nuqta) bilan takrorlang. Pod manifestiga `dnsConfig.options` orqali `ndots: 1` qo'yib natijani solishtiring. Bunda qaysi klaster ichidagi nomlar ishlamay qoladi?

10. **Headless Service.** `echo` uchun `clusterIP: None` bilan ikkinchi Service yarating. `nslookup` oddiy va headless Service uchun nima qaytaradi? Deployment'ni scale qilganda DNS javobi qanday o'zgaradi? Headless Service'ga kube-proxy qoidalari yozilganmi? Qaysi ikki holatda headless Service kerak bo'ladi?

11. **ExternalName.** `example.com` ga ishora qiluvchi ExternalName Service yarating. `nslookup` nimani qaytaradi? `wget -qO- http://<service-name>/` va `wget -qO- --header 'Host: example.com' http://<service-name>/` natijalarini solishtiring va farqni izohlang. HTTPS bilan nima bo'lardi?

### D. Tashqi kirish

12. **NodePort.** `echo` ni NodePort Service bilan oching. Berilgan port qaysi oraliqda? `docker inspect` (yoki `kubectl get nodes -o wide`) bilan kind node'larining IP'larini toping va ish mashinasidan har uchala node IP'siga `curl <node-ip>:<nodePort>/hostname` qiling (macOS'da `kind` tarmog'idagi konteynerdan). Pod'i yo'q node orqali ham javob keldimi va nima uchun? `nodePort` ni oraliqdan tashqari qiymatga qo'yib ko'ring.

13. **LoadBalancer.** `cloud-provider-kind` ni to'xtatib, `type: LoadBalancer` Service yarating: `EXTERNAL-IP` nima ko'rsatadi va Service qolgan jihatdan ishlaydimi? `cloud-provider-kind` ni ishga tushiring: nima o'zgardi, `docker ps` da nima paydo bo'ldi? Tashqi IP orqali `curl` qiling (macOS'da Laboratoriya bo'limidagi ikki yo'ldan biri, qaysi birini ishlatganingizni yozing). `kubectl get svc -o yaml` da LoadBalancer Service'da ham `nodePort` va `clusterIP` borligini ko'rsating va izohlang.

14. **externalTrafficPolicy.** LoadBalancer orqali `/clientip` ni chaqiring: ilova qaysi manba manzilni ko'ryapti? `externalTrafficPolicy: Local` ga o'zgartirib takrorlang. Service'da qanday yangi maydon (`healthCheckNodePort`) paydo bo'ldi va u nima uchun kerak? `echo` ni 1 replikaga tushirib, NodePort orqali har node'ga murojaat qiling: qaysi node javob beradi? 5-bo'limdagi jadvalni o'z kuzatuvlaringiz bilan tasdiqlang.

15. **Session affinity.** `sessionAffinity: ClientIP` qo'shing va 7-vazifadagi 300 so'rovni takrorlang. Taqsimot qanday o'zgardi? Bu mexanizm NAT ortidagi minglab foydalanuvchilar uchun nima uchun yomon ishlaydi? Stateful sessiya muammosini to'g'ri hal qilishning yo'li nima?

### E. L7

16. **Gateway and HTTPRoute.** `kubectl get gatewayclass` natijasini ko'rsating. Ikkinchi ilova (`echo-v2`, alohida Deployment va Service) yarating. Gateway (HTTP, port 80) va HTTPRoute yozing: `/v1` yo'li `echo` ga, `/v2` yo'li `echo-v2` ga borsin. `kubectl get gateway` da manzil paydo bo'lgach `curl` bilan tekshiring. `kubectl describe httproute` dagi `status` shartlarini o'qing. Backend nomini xato yozib, bu shartlar qanday o'zgarishini ko'rsating.

17. **Traffic split.** Bitta HTTPRoute qoidasida ikki `backendRefs` ni `weight: 90` va `weight: 10` bilan yozing. 300 so'rov yuborib haqiqiy nisbatni o'lchang. Bu canary deploy uchun qanday ishlatiladi? Xuddi shu natijaga faqat Deployment va Service bilan (Gateway'siz) qanday erishish mumkin va uning aniqligi nimaga bog'liq?

18. **Ingress vs Gateway.** 3-darsdagi Ingress manifestingizni (`host` va `path` bo'yicha yo'naltirish) Gateway + HTTPRoute ko'rinishida qayta yozing va ishlashini ko'rsating. Ikki manifestni yonma-yon qo'yib solishtiring: Ingress'dagi har maydon Gateway API'da qayerga ko'chdi? Ilova jamoasi va platforma jamoasi ajratilgan tashkilotda bu bo'linish nima beradi?

### F. Debug

19. **MetalLB concepts.** Hech narsa o'rnatmasdan, MetalLB hujjatining tushunchalar bo'limini o'qib yozing: L2 rejimida tashqi IP tarmoqda qanday "paydo bo'ladi" (ARP), bir vaqtda nechta node trafik qabul qiladi, node o'lsa nima bo'ladi; BGP rejimi nimasi bilan farq qiladi. 2-darsdagi kubeadm klasteringizga LoadBalancer kerak bo'lganda qaysi rejimni tanlagan bo'lardingiz?

20. **Debugging runbook.** `task_20.yaml` da atayin uchta xatosi bor ilova yozing (Deployment + Service + HTTPRoute): xatolar turli qatlamlarda bo'lsin (masalan label, port, route). Keyin 7-bo'limdagi jadval bo'yicha qadam-baqadam yurib, har xatoni qaysi buyruq ochib berganini README'da hujjatlang, go'yo manifestni boshqa odam yozgandek. Oxirida o'zingiz uchun bir sahifali runbook tuzing: alomat (`refused`, `timeout`, `404`, `503`), ehtimoliy sabab, tekshirish buyrug'i.

21. **Two-tier application.** `shop` namespace'ida yig'ing: `backend` (`agnhost netexec`, 3 replika, faqat ClusterIP), `frontend` (nginx, ConfigMap'dagi konfiguratsiya bilan `/api/` yo'lini `backend` Service'iga DNS nomi orqali proxy qiladi, 2 replika), Gateway va HTTPRoute orqali faqat `frontend` tashqariga ochiq. Barcha manifestlar `shop/` papkasida. README'da tashqi `curl` dan backend pod'gacha bo'lgan har hop'ni yozing: qaysi IP, qaysi komponent manzilni o'zgartirdi, DNS qayerda ishlatildi. `backend` ni 0 ga scale qilganda foydalanuvchi qanday javob oladi va uni kim qaytaradi? Oxirida namespace'ni o'chiring.

Yo'nalishlar (yechim emas, qayerga qarash kerakligi):

- 1–5: 1-bo'lim va 7-bo'limdagi "Xato matnini o'qish" jadvali. `-o yaml` da `spec` va `status` ni alohida o'qing.
- 6–7: 2-bo'lim. `iptables-save` chiqishi uzun, `grep` ni zanjir nomi bo'yicha zanjirlang. 300 so'rovni sanash uchun klient pod ichida shell sikli va `sort | uniq -c` yetarli.
- 8–11: 4-bo'lim va 3-bo'limdagi ExternalName. `dig` uchun `netshoot`, busybox'da yo'q.
- 12–15: 3 va 5-bo'limlar. macOS'da har tashqi so'rov `kind` tarmog'idagi konteyner orqali; manba IP o'lchashda klient konteynerning o'z IP'sini ham yozib qo'ying (`docker run ... --network kind` ichida `hostname -i` kabi usul bilan), aks holda nimani ko'rganingizni solishtira olmaysiz.
- 16–18: 6-bo'lim. `cloud-provider-kind` ishlab turishi shart. Gateway API maydonlari uchun `kubectl explain httproute.spec.rules` ishlaydi (CRD o'rnatilgan bo'lsa).
- 19: faqat o'qish, hech narsa o'rnatilmaydi.
- 20–21: 7-bo'lim va "Birga bajaramiz". nginx konfiguratsiyasi ConfigMap orqali 3-darsda ko'rilgan.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar papkada.
2. `make check` toza o'tadi (`yamllint`).
3. `net` va `shop` namespace'lari o'chirilgan, `cloud-provider-kind` to'xtatilgan, `docker ps` da undan qolgan proxy konteynerlar yo'q.
4. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- ClusterIP qayerda "yashaydi" va paket pod'ga qanday yetib boradi?
- Service o'z pod'larini qanday biladi? Readiness probe bu zanjirda qanday rol o'ynaydi?
- kube-proxy trafik yo'lida turadimi? U aslida nima qiladi?
- Nima uchun gRPC servisda bitta pod hamma yukni olishi mumkin va buni qanday hal qilasiz?
- `echo`, `echo.net` va `echo.net.svc.cluster.local` nomlari qanday hal bo'ladi? `ndots:5` nimaga ta'sir qiladi?
- NodePort, LoadBalancer va ClusterIP bir-biri bilan qanday bog'langan?
- Bulutsiz klasterda LoadBalancer Service nima uchun `<pending>` qoladi va qanday yechimlar bor?
- `externalTrafficPolicy: Local` nimani beradi va nimani oladi?
- Headless Service oddiy Service'dan nimasi bilan farq qiladi?
- "Service ishlamayapti" shikoyatida qaysi tartibda nimani tekshirasiz?
- macOS'da kind LoadBalancer IP'siga host'dan nima uchun to'g'ridan-to'g'ri yetib bo'lmaydi va qanday yo'l bilan yetasiz?
