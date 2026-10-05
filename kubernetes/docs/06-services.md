# 6-dars: Service turlari, ClusterIP, NodePort, LoadBalancer, ExternalName

Maqsad: Kubernetes'da trafik pod'ga qanday yetib borishini to'liq tushunish: Service virtual IP'si aslida nima, kube-proxy uni qanday amalga oshiradi, EndpointSlice va klaster DNS qanday ishlaydi, to'rt Service turi va headless Service qachon kerak, tashqi trafik uchun LoadBalancer bulutsiz muhitda qanday olinadi, Ingress va Gateway API qayerda turadi. Network modulidagi DNS, NAT va iptables bilimlari shu yerda bevosita ishlatiladi. Darsning ikkinchi yarmi debug'ga bag'ishlangan: "Service ishlamayapti" production'dagi eng ko'p uchraydigan shikoyat, va uni qatlamma-qatlam tekshirish tartibi kerak. Bu bilimlar 8-dars (TLS), 11-dars (high availability) va 13-dars (NetworkPolicy) uchun asos.

Taxminiy vaqt: 4 kun (siz uchun). Diqqat: ClusterIP hech bir interfeysda yo'qligi va bu nimani anglatishi, selector va EndpointSlice bog'lanishi, DNS nomlari va `ndots`, `externalTrafficPolicy` ning manba IP'ga ta'siri, va debug ketma-ketligi.

## Laboratoriya

kind `dev` klasteri (1 control-plane + 2 worker) va 3-darsda o'rnatilgan `cloud-provider-kind` (LoadBalancer va Gateway API uchun, alohida terminalda ishlab tursin). Namespace:

```bash
kubectl create namespace net
kubectl config set-context --current --namespace=net
```

Asosiy test image'i `registry.k8s.io/e2e-test-images/agnhost:2.39`. Uning `netexec` rejimi HTTP server ko'taradi: `/hostname` pod nomini, `/clientip` so'rov kelgan manba manzilni qaytaradi.

```bash
kubectl create deployment echo --image=registry.k8s.io/e2e-test-images/agnhost:2.39 --replicas=3 -- /agnhost netexec --http-port=8080
kubectl run client --image=busybox:1.36 --restart=Never -- sleep 86400
```

kind node'lari Docker konteyneri bo'lgani uchun node ichidagi tarmoq qoidalarini `docker exec dev-worker ...` bilan ko'rasiz. Tozalash: `kubectl delete namespace net`.

---

## 1. Service nima uchun kerak

Pod IP'si vaqtinchalik: har qayta yaratishda o'zgaradi, replikalar soni ham o'zgarib turadi. Klient pod'larni to'g'ridan-to'g'ri bilishi mumkin emas. Service uch narsa beradi: barqaror virtual IP (ClusterIP), barqaror DNS nomi va shu manzilga kelgan ulanishlarni sog'lom pod'lar orasida taqsimlash.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector: {app: echo}
  ports:
  - name: http
    port: 80            # port on the Service IP
    targetPort: 8080    # port on the pod (number or named container port)
```

### Selector'dan EndpointSlice'gacha

Service o'zi pod'larni bilmaydi. EndpointSlice controller selector'ga mos pod'larni kuzatadi va ularning IP hamda portlarini EndpointSlice obyektlariga yozadi. Har endpoint'ning `ready` sharti bor: readiness probe o'tmagan pod ro'yxatda turadi, lekin trafik olmaydi.

```bash
kubectl get endpointslices -l kubernetes.io/service-name=echo
kubectl get endpointslices -l kubernetes.io/service-name=echo -o yaml
```

Eski Endpoints API (`kubectl get endpoints`) 1.33 dan deprecated; yangi asboblar va skriptlarda EndpointSlice ishlatiladi.

Selector'siz Service ham bo'ladi: EndpointSlice'ni qo'lda yozib, klasterdan tashqaridagi manzilga (masalan, tashqi bazaga) klaster ichidagi nom berasiz.

## 2. kube-proxy Service'ni qanday amalga oshiradi

ClusterIP hech bir tarmoq interfeysiga biriktirilmagan. U faqat har node'dagi paket filtrlash qoidalarida mavjud bo'lgan "xayoliy" manzil.

kube-proxy har node'da ishlaydi, API'dan Service va EndpointSlice'larni kuzatadi va ularni node kernel'idagi qoidalarga aylantiradi: "manzil `10.96.x.y:80` bo'lgan paketni shu pod IP'laridan biriga DNAT qil". Pod'dan chiqqan paket shu node'dayoq, tarmoqqa chiqmasdan oldin qayta manzillanadi. Javob paketlari conntrack orqali teskari o'zgartiriladi. kube-proxy trafik yo'lida turgan proxy emas, u faqat qoidalarni yozadi.

| Rejim | Holati | Izoh |
|-------|--------|------|
| `iptables` | hozirgi standart | har Service uchun qoidalar zanjiri, backend tasodifiy tanlanadi |
| `nftables` | 1.33 dan stable, kelajakdagi standart | kernel 5.13+ talab qiladi, katta klasterlarda tezroq |
| `ipvs` | 1.35 dan deprecated | yangi klasterda tanlanmaydi |

Rejim almashishi yangilanishda kutilmagan bo'lmasligi uchun uni kube-proxy konfiguratsiyasida aniq ko'rsatish tavsiya etiladi. Ba'zi CNI'lar (Cilium) kube-proxy'ni butunlay eBPF bilan almashtiradi; tushuncha o'zgarmaydi, amalga oshirish boshqa.

Oqibatlari:

- Balanslash ulanish (connection) darajasida, so'rov darajasida emas. HTTP keep-alive yoki gRPC bilan bitta uzoq ulanish doim bitta pod'ga boradi; yangi pod'lar qo'shilsa ham mavjud ulanishlar ko'chmaydi.
- ClusterIP'ga `ping` odatda ishlamaydi: qoidalar faqat Service portlari uchun yozilgan, ICMP uchun emas. Bu nosozlik belgisi emas.
- Tanlangan pod javob bermasa kube-proxy boshqasiga qayta urinmaydi. Sog'lom bo'lmagan pod'ni ro'yxatdan chiqarish readiness probe'ning ishi.

## 3. Service turlari

| Tur | Kim ulana oladi | Qanday |
|-----|-----------------|--------|
| `ClusterIP` (standart) | klaster ichidagilar | virtual IP |
| `NodePort` | node IP'siga yeta oladigan har kim | ClusterIP + har node'da bir xil port (standart oraliq 30000–32767) |
| `LoadBalancer` | tashqi klientlar | NodePort + tashqi load balancer, uni cloud yoki boshqa controller yaratadi |
| `ExternalName` | klaster ichidagilar | hech qanday proxy yo'q, DNS `CNAME` qaytaradi |

Turlar bir-birining ustiga quriladi: LoadBalancer odatda NodePort'ni, NodePort esa ClusterIP'ni o'z ichiga oladi.

### LoadBalancer bulutsiz muhitda

`type: LoadBalancer` bu so'rov: "kimdir menga tashqi manzil bersin". Cloud'da buni cloud controller bajaradi (AWS'da NLB yaratiladi). Bunday controller yo'q klasterda `EXTERNAL-IP` abadiy `<pending>` turadi.

| Muhit | Yechim |
|-------|--------|
| kind | `cloud-provider-kind`: har Service uchun Docker'da proxy konteyner ko'taradi va unga IP beradi |
| k3s | ichki ServiceLB: node IP'larini tashqi manzil sifatida ishlatadi |
| Bare metal, kubeadm | MetalLB: berilgan IP pool'idan manzil ajratadi va uni L2 (ARP) yoki BGP orqali tarmoqqa e'lon qiladi |

**Tuzoq: har Service uchun alohida LoadBalancer.** Cloud'da har LoadBalancer Service alohida pullik resurs. O'nta HTTP servis uchun o'nta balanser o'rniga bitta balanser va uning orqasida Ingress yoki Gateway ishlatiladi.

### ExternalName

```yaml
spec:
  type: ExternalName
  externalName: db.example.com
```

Klaster ichida `mydb` nomi `db.example.com` ga `CNAME` bo'ladi. Cheklovi: bu faqat DNS darajasida. HTTP klient `Host: mydb` header'i yuboradi, TLS'da esa sertifikat `mydb` nomiga mos kelmaydi; shuning uchun HTTP va HTTPS servislar bilan muammo chiqadi, baza kabi protokollarga ko'proq mos.

## 4. Klaster DNS

CoreDNS (`kube-system` da) Service va pod'lar uchun DNS yozuvlarini beradi. Har pod'ning `/etc/resolv.conf` fayli kubelet tomonidan yoziladi:

```
nameserver 10.96.0.10
search net.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

| Nom | Qayerdan ishlaydi |
|-----|-------------------|
| `echo` | faqat o'sha namespace ichidan |
| `echo.net` | istalgan namespace'dan |
| `echo.net.svc.cluster.local` | to'liq nom (FQDN) |

Oddiy Service uchun `A` yozuvi ClusterIP'ni qaytaradi. Nomlangan portlar uchun `SRV` yozuvi ham bor: `_http._tcp.echo.net.svc.cluster.local`.

**Tuzoq: `ndots:5`.** Nomda 5 tadan kam nuqta bo'lsa, resolver avval `search` ro'yxatidagi har suffiksni qo'shib ko'radi. `api.github.com` uchun avval `api.github.com.net.svc.cluster.local` va yana ikkita mavjud bo'lmagan nom so'raladi, shundan keyingina asl nom. Tashqi API'larga ko'p murojaat qiladigan ilovada bu DNS yukini bir necha barobar oshiradi. Yechim: nom oxiriga nuqta qo'yish (`api.github.com.`) yoki pod'da `dnsConfig` orqali `ndots` ni kamaytirish.

### Headless Service

`clusterIP: None` bo'lsa virtual IP ajratilmaydi va kube-proxy ishtirok etmaydi. DNS so'rovi to'g'ridan-to'g'ri barcha tayyor pod'lar IP'larini qaytaradi. Ishlatilishi: klient o'zi balanslashni xohlasa (gRPC), yoki har pod'ga alohida murojaat kerak bo'lsa (StatefulSet: `web-0.web.net.svc.cluster.local`).

## 5. Trafik siyosatlari

| Maydon | Qiymatlar | Ta'siri |
|--------|-----------|---------|
| `sessionAffinity` | `None` (standart), `ClientIP` | `ClientIP`: bitta manba IP'dan kelgan ulanishlar bitta pod'ga boradi (standart muddat 10800 soniya) |
| `externalTrafficPolicy` | `Cluster` (standart), `Local` | tashqi trafik (NodePort, LoadBalancer) qaysi pod'larga borishi |
| `internalTrafficPolicy` | `Cluster` (standart), `Local` | klaster ichidagi trafik faqat shu node'dagi pod'larga borsinmi |

`externalTrafficPolicy` ning ikki qiymati:

| | `Cluster` | `Local` |
|---|-----------|---------|
| Trafik qaysi pod'ga | istalgan node'dagi | faqat paket kelgan node'dagi |
| Klient manba IP'si | yo'qoladi (node SNAT qiladi) | saqlanadi |
| Pod'siz node'ga kelgan paket | boshqa node'ga yo'naltiriladi | tashlab yuboriladi; balanser `healthCheckNodePort` orqali bunday node'larni chetlab o'tadi |
| Taqsimot | tekis | node'lardagi pod soniga qarab notekis bo'lishi mumkin |

Ilovaga klientning haqiqiy IP'si kerak bo'lsa (audit, rate limit, geolokatsiya) `Local` tanlanadi, yoki L7 proxy'ning `X-Forwarded-For` header'iga tayaniladi.

## 6. Ingress va Gateway API

Service L4: IP va port. HTTP darajasidagi yo'naltirish (host, path, header), TLS termination va bitta kirish nuqtasi orqali ko'p servis uchun L7 qatlam kerak.

| | Ingress | Gateway API |
|---|---------|-------------|
| Holati | barqaror, lekin muzlatilgan: yangi imkoniyat qo'shilmaydi | faol rivojlanmoqda, Kubernetes loyihasi tavsiya qiladi |
| O'rnatilishi | API ichki, controller alohida | CRD'lar va controller alohida |
| Obyektlar | bitta `Ingress` | `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute` (hammasi `gateway.networking.k8s.io/v1`) |
| Rollar | bitta obyektda hammasi | infratuzilma (GatewayClass), klaster operatori (Gateway), ilova jamoasi (HTTPRoute) |
| Kengaytma | controller'ga xos annotation'lar | standart maydonlar: vaznli taqsimot, header bo'yicha yo'naltirish, redirect, rewrite |
| Namespace'lararo | cheklangan | `allowedRoutes` va `ReferenceGrant` bilan nazorat qilinadi |

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo
spec:
  parentRefs:
  - name: main-gw              # the Gateway this route attaches to
  rules:
  - matches:
    - path: {type: PathPrefix, value: /}
    backendRefs:
    - {name: echo, port: 80, weight: 100}
```

Gateway obyekti "qaysi portda, qaysi protokolda tinglash va qaysi namespace'lardan route qabul qilish"ni aytadi; `gatewayClassName` qaysi controller uni amalga oshirishini belgilaydi. kind'da `cloud-provider-kind` Gateway API CRD'larini o'zi o'rnatadi va `cloud-provider-kind` nomli GatewayClass beradi.

3-darsda aytilgani esda tursin: ingress-nginx 2026-yil martdan qo'llab-quvvatlanmaydi. Yangi loyihada tanlov Gateway API'ni qo'llaydigan controller'lar orasidan qilinadi; Ingress'ni bilish esa mavjud klasterlarni tushunish va migratsiya uchun kerak.

## 7. Service ulanishini qatlamma-qatlam debug qilish

"Servisga ulanib bo'lmayapti" shikoyatida ichkaridan tashqariga qarab yuring. Har qadam oldingisi to'g'ri bo'lgandagina ma'noli:

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

Eng ko'p uchraydigan uch sabab: selector va label mos emas (4-qadam, endpoint'lar bo'sh), `targetPort` xato (3-qadam, `connection refused`), pod'lar `Ready` emas (1-qadam). `connection refused` va `timeout` farqiga e'tibor bering: birinchisi "manzilga yetdim, portda hech kim yo'q", ikkinchisi "paket yo'lda yo'qoldi" (firewall, NetworkPolicy, yo'q manzil).

Debug uchun qulay image: `nicolaka/netshoot` (ichida `dig`, `curl`, `tcpdump`, `ss` va boshqalar). Ilova pod'ining tarmoq namespace'iga ulanish: `kubectl debug -it POD --image=nicolaka/netshoot`.

## Tuzoqlar

- Selector'dagi bitta harf xatosi: Service bor, endpoint'lar bo'sh, hech qanday xato xabari yo'q.
- `port` va `targetPort` ni adashtirish.
- Ilova faqat `127.0.0.1` da tinglaydi: pod ichidan ishlaydi, Service orqali `connection refused`.
- Readiness probe'siz pod'lar: Service ishga tushib ulgurmagan pod'ga trafik yuboradi.
- Uzoq yashaydigan ulanishlar (gRPC, HTTP/2, baza pool'i) bilan Service balanslashiga ishonish: bitta pod hamma yukni oladi.
- `ndots:5` tufayli tashqi nomlarga ortiqcha DNS so'rovlari.
- Bulutsiz klasterda `type: LoadBalancer` yaratib, `<pending>` ni kutish.
- `externalTrafficPolicy: Cluster` bilan klient IP'siga tayanadigan mantiq (rate limit, allowlist): hamma so'rov node IP'sidan kelgandek ko'rinadi.
- Har servis uchun alohida cloud load balancer: ortiqcha xarajat.
- NodePort'ni internetga ochiq qoldirish: 30000–32767 oralig'idagi har port har node'da ochiq bo'ladi.

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
- https://metallb.io/concepts/ – MetalLB tushunchalari

---

## Vazifalar

Barchasini `kubernetes/06-services/` papkasida bajaring (`make new m=kubernetes n=06 name=services`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml` nomi bilan saqlanadi. Hammasi `net` namespace'ida, laboratoriya bo'limidagi `echo` Deployment'i va `client` pod'i bilan.

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

12. **NodePort.** `echo` ni NodePort Service bilan oching. Berilgan port qaysi oraliqda? `docker inspect` bilan kind node'larining IP'larini toping va ish mashinasidan har uchala node IP'siga `curl <node-ip>:<nodePort>/hostname` qiling. Pod'i yo'q node orqali ham javob keldimi va nima uchun? `nodePort` ni oraliqdan tashqari qiymatga qo'yib ko'ring.

13. **LoadBalancer.** `cloud-provider-kind` ni to'xtatib, `type: LoadBalancer` Service yarating: `EXTERNAL-IP` nima ko'rsatadi va Service qolgan jihatdan ishlaydimi? `cloud-provider-kind` ni ishga tushiring: nima o'zgardi, `docker ps` da nima paydo bo'ldi? Tashqi IP orqali `curl` qiling. `kubectl get svc -o yaml` da LoadBalancer Service'da ham `nodePort` va `clusterIP` borligini ko'rsating va izohlang.

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

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar papkada.
2. `make check` toza o'tadi (`yamllint`).
3. `net` va `shop` namespace'lari o'chirilgan, `cloud-provider-kind` to'xtatilgan, `docker ps` da undan qolgan proxy konteynerlar yo'q.
4. Menga xabar bering, tekshiraman.

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
