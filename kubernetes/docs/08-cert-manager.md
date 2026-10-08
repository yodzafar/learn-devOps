# 8-dars: Sertifikatlarni boshqarish, cert-manager

Maqsad: Kubernetes'da TLS sertifikatlarini qo'lda emas, deklarativ va avtomatik boshqarish. Network modulida TLS, sertifikat zanjiri va Let's Encrypt bilan tanishgansiz; qo'lda `certbot` ishlatib sertifikat olish va uni cron bilan yangilash bitta serverda ishlaydi, lekin o'nlab servisli klasterda yo'q. cert-manager sertifikatni Kubernetes obyektiga aylantiradi: siz "shu nom uchun sertifikat kerak" deysiz, u oladi, Secret'ga yozadi va muddati tugashidan oldin yangilaydi. Bu darsda Helm ham birinchi marta ishlatiladi, chunki cert-manager va shunga o'xshash klaster addon'lari (addon bu klasterga qo'shimcha imkoniyat beradigan tizim komponenti: ingress controller, cert-manager, monitoring) amalda Helm chart sifatida o'rnatiladi. Helm asoslari shu yerda beriladi, 9 va 10-darslarda (CI/CD, GitOps) davom etadi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruhi (Helm), ikkinchi kun 4–8 bo'limlar, B va C guruhlari, uchinchi kun 9–10 bo'limlar, "Birga bajaramiz", D, E va F guruhlari. Diqqat: Helm'da chart, release va values munosabati; cert-manager'da Certificate'dan Secret'gacha bo'lgan obyektlar zanjiri; HTTP-01 va DNS-01 qachon ishlaydi va qachon ishlamaydi; muammoni zanjir bo'ylab qanday qidirish.

Qanday o'qish kerak: har bo'limdagi manifest va buyruqni o'qing, keyin o'z klasteringizda shunga o'xshash (aynan o'zi emas) narsani ishlatib, chiqishni darsdagi izoh bilan solishtiring. Chart versiyalari, sana, IP manzil, serial raqam va pod suffikslari sizda boshqa bo'ladi; darsda ular `<...>` bilan belgilangan. Sertifikat bilan ishlaganda ikkita odat shakllantiring: (1) yopiq kalit hech qachon ish papkasiga, README'ga yoki terminal chiqishiga tushmaydi; (2) har natijani ikki tomondan tekshiring: Kubernetes obyekti nima deydi (`kubectl get certificate`) va simda haqiqatda nima berilyapti (`openssl s_client`, `curl -v`). Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker ustidagi kind `dev` klasterida (1 control-plane + 2 worker, 3-darsda `kind-multi.yaml` bilan yaratilgan). Multipass VM bu darsda kerak emas: sertifikatlar va Helm haqiqiy node xulqiga bog'liq emas. Faqat ixtiyoriy 20-vazifa cloud VM talab qiladi.

Klasterga Helm bilan ikki narsa o'rnatiladi: Traefik (ingress controller) va cert-manager. `cloud-provider-kind` (3-dars) alohida terminalda ishlab tursin: u Traefik'ning `LoadBalancer` Service'iga IP beradi.

Asboblarni o'rnatish (rasmiy yo'riqnoma: https://helm.sh/docs/intro/install/):

```bash
# Zorin (amd64): official script; read it before running, it asks for sudo
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
less get_helm.sh
chmod 700 get_helm.sh && ./get_helm.sh

# macOS (arm64)
brew install helm

# both
helm version
```

Zorin'da `sudo` siz muqobil: releases sahifasidan `helm-<version>-linux-amd64.tar.gz` arxivini yuklab, ichidagi `helm` binary'sini `~/.local/bin` ga qo'yish (1-darsda `kubectl` va `kind` bilan shunday qilgansiz). `openssl` ikkala mashinada bor, lekin har xil: Zorin'da OpenSSL 3, macOS'da LibreSSL. Bu darsdagi buyruqlar ikkalasida ishlaydi, faqat chiqish formati biroz farq qiladi (masalan, `subject=CN=x` va `subject= /CN=x`). `cmctl` (cert-manager CLI) 14-vazifada o'rnatiladi: macOS'da `brew install cmctl`, Zorin'da https://github.com/cert-manager/cmctl/releases sahifasidan `linux` `amd64` arxivi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Klaster | Docker Engine ustida kind, node'lar `amd64` | Docker Desktop ustida kind, node'lar `arm64` |
| Traefik LB IP (`172.18.0.x`) | host'dan to'g'ridan-to'g'ri `curl` qilinadi | Docker Desktop'ning yashirin VM'i ichida, host'dan yetib bo'lmaydi |
| Host'dan HTTPS so'rov | LB IP yoki `kubectl port-forward` | faqat `kubectl port-forward` (pastda) |

Ikkala mashinada bir xil ishlaydigan yo'l `port-forward` (3-dars): Traefik Service'ining 443-portini host'ning 8443-portiga ulaysiz va `curl --resolve` bilan nomni `127.0.0.1` ga bog'laysiz.

```bash
kubectl port-forward -n traefik svc/traefik 8443:443     # keep running in a separate terminal
curl --cacert ca.crt --resolve app.example.test:8443:127.0.0.1 https://app.example.test:8443/
```

`--resolve HOST:PORT:IP` curl'ga "shu host va port uchun DNS so'rama, shu IP'ga ulan" deydi. Muhimi: curl baribir `app.example.test` nomini TLS'dagi SNI (1-bo'lim) va `Host` sarlavhasida yuboradi, shuning uchun Traefik to'g'ri sertifikat va to'g'ri route'ni tanlaydi. `/etc/hosts` ni tahrirlash kerak emas.

Ikkinchi mashinada tiklash: klaster holati mashinalar orasida ko'chmaydi, git orqali values fayllari, manifestlar va `install.sh` keladi. Uyda `kind get clusters` da `dev` bo'lmasa `kind create cluster --name dev --config kubernetes/02-cluster-setup/kind-multi.yaml`, `cloud-provider-kind` ni ishga tushiring, keyin `values/` dagi fayllar bilan ikkala chart'ni qayta o'rnating va `task_N.yaml` larni `apply` qiling. Git orqali kelmaydigan narsalar: root CA kaliti (har klasterda yangisi yaratiladi, shuning uchun eski `ca.crt` fayli yangi klaster sertifikatlariga ishonmaydi, uni qayta chiqarib oling), ACME akkaunt kaliti (yangi akkaunt ochiladi, staging uchun bu muammo emas), Helm release tarixi (revision'lar 1 dan boshlanadi). 19-vazifadagi `install.sh` aynan shu tiklashni bitta buyruqqa aylantiradi.

Xavfsizlik va tartib:

- `ca.crt`, `tls.crt`, `tls.key` ni faqat `mktemp -d` bilan yaratilgan vaqtinchalik katalogga chiqaring, ish papkasiga emas. `tls.key` ni umuman chiqarmaslikka harakat qiling: ko'pchilik tekshiruv uchun faqat sertifikat kerak.
- Chart'larni har doim versiyasi qotirilgan holda o'rnating (`--version`), image tag'larida `latest` yo'q.
- Let's Encrypt bilan faqat staging serveri ishlatiladi (6-bo'lim).
- Tozalash: `helm uninstall` har release uchun, `demo`, `team-a`, `team-b` va boshqa namespace'larni o'chirish, cert-manager CRD'lari bilan nima qilishni ongli tanlash (2-bo'limdagi tuzoq), `port-forward` va `cloud-provider-kind` ni to'xtatish.

---

## 1. TLS eslatma va muammo

### Bu nima

TLS (Transport Layer Security) bu TCP ulanishni shifrlaydigan va server shaxsini tasdiqlaydigan protokol; HTTPS bu HTTP'ning TLS ichida ketishi. Sertifikat bu ochiq kalit (public key) va shaxs (domen nomlari) birikmasi, ustiga CA (Certificate Authority, "bu kalit shu domenga tegishli" deb imzo qo'yadigan tashkilot) qo'ygan imzo. Domen nomlari sertifikatning SAN (Subject Alternative Name) maydonida yoziladi; zamonaviy klientlar faqat SAN'ga qaraydi, eski `CN` (Common Name) maydoniga emas.

Sertifikat olish jarayoni uch qadam: yopiq kalit (private key) yaratiladi, undan CSR (Certificate Signing Request, "shu ochiq kalit va shu nomlar uchun imzo bering" degan so'rov) tuziladi, CA domen egaligini tekshirib imzolaydi. Yopiq kalit hech qachon serverdan chiqmaydi, CA'ga faqat CSR boradi.

### Mexanizm

Brauzer `https://app.example.com` ga ulanganda:

1. TCP ulanish o'rnatiladi, klient TLS `ClientHello` yuboradi. Unda SNI (Server Name Indication) bor: klient qaysi nomga ulanmoqchi ekanini ochiq yozadi. Bitta IP va 443-portda yuzlab sayt bo'lishi mumkin, proxy SNI'ga qarab qaysi sertifikatni berishni tanlaydi.
2. Server sertifikat zanjirini yuboradi: leaf (sayt sertifikati) va oraliq (intermediate) CA sertifikatlari. Root CA sertifikati yuborilmaydi, u klientning o'zida bo'lishi kerak.
3. Klient tekshiradi: zanjir ishonchli root'gacha uzilmasdan imzolanganmi, sertifikat muddati amaldami, SAN'da ulanilgan nom bormi. Bittasi o'tmasa ulanish uziladi.
4. Server sertifikatdagi ochiq kalitga mos yopiq kalitga ega ekanini isbotlaydi, keyin sessiya kalitlari kelishiladi va HTTP shifrlangan holda ketadi.

Kubernetes'da sertifikat `kubernetes.io/tls` turidagi Secret'da saqlanadi (Secret 4-darsda): `tls.crt` (leaf va oraliq zanjir, PEM formatida) va `tls.key` (yopiq kalit). Ingress yoki Gateway unga nom orqali ishora qiladi:

```yaml
spec:
  tls:
    - hosts: [app.example.test]
      secretName: app-tls
```

Ingress controller (bu darsda Traefik) Secret'ni o'qiydi va SNI `app.example.test` bo'lgan ulanishlarga shu sertifikatni beradi.

### Ishlaydigan misol

Ommaviy saytning sertifikatini o'qish (ikkala mashinada ishlaydi):

```
$ echo | openssl s_client -connect kubernetes.io:443 -servername kubernetes.io 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates
subject=CN=kubernetes.io
issuer=C=US, O=Let's Encrypt, CN=<R10 or similar>
notBefore=<date> GMT
notAfter=<date + 90 days> GMT
```

- `s_client -connect HOST:443` TLS ulanish ochadi, `-servername` SNI'ni yuboradi. `echo |` ulanishni darhol yopish uchun, `2>/dev/null` diagnostik matnni yashiradi.
- Ikkinchi `openssl x509` birinchi chiqishdagi leaf sertifikatni o'qiydi.
- `subject`: sertifikat egasi. `issuer`: kim imzolagan, bu yerda Let's Encrypt'ning oraliq CA'si. Root CA bu yerda yo'q, u sizning operatsion tizimingiz ishonch omborida.
- `notBefore` va `notAfter` orasidagi farq taxminan 90 kun: bu Let's Encrypt sertifikatining umri.

### Real ishda qachon kerak

Har bir HTTPS endpoint, har servislararo shifrlangan ulanish (mTLS, ya'ni ikki tomon ham sertifikat ko'rsatadigan TLS), webhook'lar (Kubernetes API server admission webhook'larga faqat TLS orqali murojaat qiladi). Qo'lda boshqarishning muammolari: Let's Encrypt sertifikatlari 90 kun yashaydi va CA/Browser Forum qarori bilan ommaviy sertifikatlar umri bosqichma-bosqich yanada qisqarmoqda; har servis, har muhit uchun alohida sertifikat; muddati o'tgan sertifikat eng ko'p uchraydigan va eng uyatli uzilish sabablaridan biri.

### Nima uchun shunday

Muddatli sertifikat xavfni cheklaydi: kalit o'g'irlansa ham, u cheksiz ishlamaydi, bekor qilish (revocation) mexanizmlari esa amalda ishonchsiz. Qisqa umr esa qo'lda boshqarishni imkonsiz qiladi, shuning uchun sanoat avtomatlashtirishga o'tdi: ACME protokoli (6-bo'lim) va Kubernetes'da uning standart klienti cert-manager. Frontend tajribasidan: Vercel yoki Netlify sizga sertifikatni "o'zi" bergan, ortida aynan shu ACME avtomatikasi ishlaydi. Klasterda bu ishni o'zingiz yo'lga qo'yasiz.

## 2. Helm asoslari

### Bu nima

Helm bu Kubernetes uchun paket menejeri: bir to'plam manifestni parametrlar bilan shablonlab, versiyalab, bitta buyruq bilan o'rnatish, yangilash va qaytarish imkonini beradi.

| Tushuncha | Ma'nosi | npm'dagi o'xshashi |
|-----------|---------|--------------------|
| Chart | manifest shablonlari va standart qiymatlar to'plami, versiyalangan | paket |
| Release | chart'ning klasterga o'rnatilgan, nomlangan nusxasi. Har o'zgarish yangi revision | `node_modules` dagi o'rnatilgan nusxa |
| Repository | chart'lar saqlanadigan joy: HTTP repo yoki OCI registry | npm registry |

O'xshatish to'liq emas: npm paketi kod beradi, chart esa klasterga qo'llanadigan obyektlar beradi, va release holati klasterda yashaydi. Bitta chart'dan bir klasterda bir nechta release o'rnatish mumkin (turli nom va values bilan).

### Mexanizm

`helm install` yoki `helm upgrade` da quyidagilar bo'ladi:

1. Chart yuklab olinadi (repo yoki OCI registry'dan) va lokal keshga qo'yiladi.
2. Values birlashtiriladi: chart'dagi `values.yaml`, ustiga `-f` bilan berilgan fayllar (tartib bo'yicha), ustiga `--set` qiymatlari.
3. Go template dvigateli `templates/` dagi fayllarni shu values bilan render qiladi. Natija oddiy YAML manifestlar.
4. Helm manifestlarni API server'ga yuboradi (`kubectl apply` bilan bir xil API orqali, kubeconfig bilan).
5. Release ma'lumoti (chart, values, render qilingan manifest, holat) release namespace'idagi Secret'ga yoziladi: `sh.helm.release.v1.<name>.v<revision>`, turi `helm.sh/release.v1`.

Helm'ning klasterda ishlaydigan server qismi yo'q (eski Helm 2'dagi Tiller 2019 yilda olib tashlangan), u `kubectl` kabi kubeconfig bilan ishlaydigan klient. Huquqlari ham sizning kubeconfig'ingizdagi foydalanuvchi huquqlari.

### Ishlaydigan misol

Vazifalardagidan boshqa chart: `podinfo`, Go'da yozilgan kichik demo ilova, OCI registry'da.

```
$ helm show chart oci://ghcr.io/stefanprodan/charts/podinfo --version <chart-version>
apiVersion: v1
appVersion: <app-version>
description: Podinfo Helm chart for Kubernetes
name: podinfo
version: <chart-version>
...
```

`version` chart'ning o'z versiyasi (shablonlar o'zgarsa oshadi), `appVersion` chart ichidagi ilova versiyasi. Ular mustaqil.

```
$ cat podinfo-values.yaml
replicaCount: 2
$ helm install demo oci://ghcr.io/stefanprodan/charts/podinfo --version <chart-version> \
    -n helm-demo --create-namespace -f podinfo-values.yaml
NAME: demo
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 1
$ helm list -A
NAME   NAMESPACE   REVISION   UPDATED   STATUS     CHART                     APP VERSION
demo   helm-demo   1          <date>    deployed   podinfo-<chart-version>   <app-version>
```

- `NAME: demo` release nomi, siz tanlaysiz (chiqishda `LAST DEPLOYED` va `NOTES` ham bo'ladi, bu yerda qisqartirilgan). Chart ichidagi obyektlar nomi odatda shundan yasaladi (`demo-podinfo`).
- `STATUS: deployed`: manifestlar qabul qilindi. Bu pod'lar tayyor degani emas, Helm standart holatda pod'larni kutmaydi; tayyorlikni `kubectl rollout status` bilan tekshiring.
- `REVISION: 1`: birinchi revision. Har `upgrade` va `rollback` uni bittaga oshiradi.

`replicaCount: 3` qilib `helm upgrade demo ... -f podinfo-values.yaml`, keyin:

```
$ helm history demo -n helm-demo
REVISION   UPDATED   STATUS       CHART                     APP VERSION   DESCRIPTION
1          <date>    superseded   podinfo-<chart-version>   <app-version> Install complete
2          <date>    deployed     podinfo-<chart-version>   <app-version> Upgrade complete
$ kubectl get secret -n helm-demo -l owner=helm
NAME                         TYPE                 DATA   AGE
sh.helm.release.v1.demo.v1   helm.sh/release.v1   1      3m
sh.helm.release.v1.demo.v2   helm.sh/release.v1   1      40s
```

- `superseded`: eski revision, endi amalda emas. `deployed`: joriy. Har revision o'z Secret'ida. Revision soni chegarasi `helm upgrade --history-max` bilan boshqariladi.

Asosiy buyruqlar:

| Buyruq | Nima qiladi |
|--------|-------------|
| `helm repo add NAME URL`, `helm repo update` | klassik HTTP repo qo'shish va indeksini yangilash (OCI uchun kerak emas) |
| `helm show chart CHART`, `helm show values CHART` | chart metama'lumoti va barcha sozlanadigan values |
| `helm template NAME CHART -f values.yaml` | klasterga tegmasdan manifestlarni render qiladi |
| `helm upgrade --install NAME CHART -f values.yaml` | bor bo'lsa yangilaydi, yo'q bo'lsa o'rnatadi (idempotent, CI uchun) |
| `helm get values NAME` / `helm get manifest NAME` | release'ga berilgan values / qo'llangan manifestlar |
| `helm history NAME` | revision'lar tarixi |
| `helm rollback NAME REVISION` | oldingi revision'ga qaytish (yangi revision sifatida) |
| `helm uninstall NAME` | release'ni o'chirish |

Barcha buyruqlarga `-n NAMESPACE` kerak, chunki release namespace'ga bog'langan. Tozalash: `helm uninstall demo -n helm-demo && kubectl delete namespace helm-demo`.

Qoidalar:

- **Chart versiyasini qotiring** (`--version`). Versiyasiz o'rnatish har safar boshqa narsa beradi. Bu `package-lock.json` siz `npm install` bilan bir xil muammo.
- **Values faylda, git'da.** `--set` bilan berilgan qiymat faqat terminal tarixida qoladi. Har `upgrade` da o'sha values faylini bering: `upgrade` oldingi `--set` larni eslab qolmaydi.
- **O'rnatishdan oldin o'qing.** `helm template` chiqishini ko'rib chiqing: chart klaster darajasidagi RBAC, CRD, webhook o'rnatishi mumkin. Begona chart bu begona kodni klaster admin huquqi bilan ishlatish, xuddi `npm install` dagi `postinstall` skript kabi, faqat oqibati kattaroq.

### Tuzoq: CRD'lar va Helm

CRD (CustomResourceDefinition, 1-dars) API'ga yangi obyekt turini qo'shadi. Helm chart'ning maxsus `crds/` katalogidagi CRD'larni faqat birinchi o'rnatishda qo'yadi, `upgrade` da yangilamaydi va `uninstall` da o'chirmaydi. Shu sabab ko'p chart'lar (cert-manager ham) CRD'larni oddiy shablon sifatida, alohida flag bilan beradi. CRD o'chirilsa undan yaratilgan barcha obyektlar (barcha Certificate'lar) ham o'chadi, shuning uchun ular atayin himoyalangan.

### Real ishda qachon kerak

Uchinchi tomon addon'larini o'rnatishda deyarli har doim: ingress controller, cert-manager, Prometheus stack, Argo CD, ma'lumotlar bazasi operator'lari. O'z ilovangiz uchun Helm chart yozish yoki Kustomize (9-dars) tanlash esa jamoa qarori.

### Nima uchun shunday

Xom YAML'ni nusxa ko'chirib tahrirlash har muhit (dev, staging, prod) uchun alohida faylga va o'zgarishlarni qo'lda kuzatishga olib keladi. Helm buni "shablon + parametrlar + tarix" ga ajratdi. Holatni klasterdagi Secret'da saqlash (Helm 3'dan beri) server komponenti va uning huquqlari muammosini yo'qotdi: kim release'ni o'zgartira oladi degan savolga RBAC javob beradi. Muqobillari: Kustomize (shablonsiz, patch asosida, `kubectl` ichida), xom manifest va GitOps (10-dars).

## 3. cert-manager arxitekturasi

### Bu nima

cert-manager bu CRD'lar va controller'lar to'plami: sertifikat, uning manbai (issuer) va olish jarayonini Kubernetes obyektlari sifatida ifodalaydi va 1-darsdagi reconciliation orqali boshqaradi. CNCF loyihasi, Kubernetes'da sertifikat avtomatikasining amaldagi standarti.

O'rnatish (rasmiy yo'riqnoma: https://cert-manager.io/docs/installation/helm/; versiyani shu sahifadan oling):

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version <version> \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

### Mexanizm

Uch komponent ishga tushadi:

| Komponent | Vazifasi |
|-----------|----------|
| `cert-manager` (controller) | Certificate va boshqa obyektlarni reconcile qiladi, CA'lar bilan gaplashadi |
| `cert-manager-webhook` | obyektlarni API server'ga yozilishidan oldin validatsiya qiladi (admission webhook) |
| `cert-manager-cainjector` | webhook va CRD konfiguratsiyalariga CA bundle'ni joylaydi, API server webhook'ga TLS bilan ishonishi uchun |

Admission webhook bu API server obyektni etcd'ga yozishdan oldin chaqiradigan tashqi HTTPS servis: u obyektni rad etishi yoki o'zgartirishi mumkin. Webhook ishlamasa, unga bog'langan obyektlarni yaratib bo'lmaydi (5-vazifada sinaysiz).

CRD'lar va ular orasidagi zanjir:

| Obyekt | Kim yaratadi | Ma'nosi |
|--------|--------------|---------|
| `Issuer`, `ClusterIssuer` | siz | sertifikat qayerdan olinadi (CA konfiguratsiyasi) |
| `Certificate` | siz yoki ingress-shim | "shu nomlar uchun sertifikat shu Secret'da bo'lsin" degan kerakli holat |
| `CertificateRequest` | cert-manager | bitta aniq CSR va uning natijasi |
| `Order` | cert-manager (faqat ACME) | ACME serveridagi buyurtma |
| `Challenge` | cert-manager (faqat ACME) | bitta domen uchun egalik tekshiruvi |

Oqim: Certificate yaratiladi. Controller Secret yo'qligini yoki yangilash vaqti kelganini ko'radi, yopiq kalit yaratadi (avval vaqtinchalik Secret'da) va CertificateRequest yaratadi. Ichki "approver" so'rovni tasdiqlaydi (`Approved` sharti). Issuer turiga mos controller so'rovni imzolatadi: CA issuer darhol o'zi imzolaydi, ACME bo'lsa Order va Challenge'lar hosil bo'ladi. Imzolangan sertifikat qaytgach u kalit bilan birga Certificate'dagi `secretName` Secret'iga yoziladi. Bu 1-darsdagi reconciliation: Certificate `spec` kerakli holat, Secret va `status` haqiqiy holat. Secret'ni o'chirsangiz cert-manager uni qayta chiqaradi.

### Ishlaydigan misol

```
$ kubectl get pods -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-<hash>-<s1>                   1/1     Running   0          60s
cert-manager-cainjector-<hash>-<s2>        1/1     Running   0          60s
cert-manager-webhook-<hash>-<s3>           1/1     Running   0          60s
$ kubectl api-resources --api-group=cert-manager.io
NAME                  SHORTNAMES   APIVERSION           NAMESPACED   KIND
certificaterequests   cr,crs       cert-manager.io/v1   true         CertificateRequest
certificates          cert,certs   cert-manager.io/v1   true         Certificate
clusterissuers        ciss         cert-manager.io/v1   false        ClusterIssuer
issuers               iss          cert-manager.io/v1   true         Issuer
```

- Uchta Deployment, har biri bitta pod. `RESTARTS 0` muhim: webhook sertifikati tayyor bo'lguncha controller bir-ikki marta qayta ishga tushishi mumkin, lekin keyin barqaror bo'lishi kerak.
- `api-resources` CRD'lar API'ga qo'shilganini ko'rsatadi. `NAMESPACED false` faqat `ClusterIssuer` da: u klaster darajasidagi obyekt (4-bo'lim). `SHORTNAMES` `kubectl get cert` kabi qisqa yozish uchun.
- `Order` va `Challenge` bu ro'yxatda yo'q: ular boshqa API guruhida, `acme.cert-manager.io`.

Skriptda tayyorlikni kutish: `kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=180s`.

### Real ishda qachon kerak

Ingress orqali HTTPS beriladigan har klasterda, ichki mTLS uchun, webhook va operator'larning o'z sertifikatlari uchun (ko'p operator'lar cert-manager'ni talab qiladi).

### Nima uchun shunday

cert-manager "sertifikat olish skripti" emas, balki operator naqshi (1-dars, CRD + controller): kerakli holat obyektda, controller uni doim yetkazib turadi. Shu sabab yangilash alohida cron emas, oddiy reconciliation'ning natijasi. Bitta katta Certificate o'rniga zanjir (Certificate, CertificateRequest, Order, Challenge) qilingani har qadamni alohida kuzatish va debug qilish imkonini beradi (10-bo'lim).

## 4. Issuer va ClusterIssuer

### Bu nima

Issuer cert-manager'ga "sertifikatni qayerdan va qanday olish kerak" deydi: qaysi CA, qaysi kalit, qaysi ACME server. Ikki varianti bor, farqi faqat ko'rinish doirasida (scope):

| | `Issuer` | `ClusterIssuer` |
|---|----------|-----------------|
| Scope | namespaced | cluster-scoped |
| Kim ishlata oladi | faqat o'z namespace'idagi Certificate'lar | istalgan namespace |
| U ishora qiladigan Secret'lar | o'z namespace'ida | cert-manager namespace'ida (standart sozlama) |
| Qachon | jamoa o'z CA'sini yoki o'z ACME akkauntini boshqarsa | platforma jamoasi butun klasterga bitta manba bersa |

Asosiy issuer turlari: `selfSigned`, `ca`, `acme`, `vault`, va tashqi issuer'lar (masalan, AWS Private CA yoki Google CAS uchun alohida o'rnatiladigan controller'lar).

### Mexanizm

Certificate'dagi `issuerRef` ikki maydon bilan issuer'ni topadi: `name` va `kind` (`Issuer` yoki `ClusterIssuer`). `kind` berilmasa `Issuer` deb olinadi va u faqat Certificate'ning o'z namespace'ida qidiriladi. ClusterIssuer o'zi namespace'siz bo'lgani uchun, u ishora qiladigan Secret'lar (CA kaliti, ACME akkaunt kaliti) "cluster resource namespace" da qidiriladi, standart holatda bu `cert-manager`.

### Ishlaydigan misol

```
$ kubectl get issuers -A
NAMESPACE   NAME          READY   AGE
shop        shop-ca       True    5m
$ kubectl get clusterissuers
NAME          READY   AGE
selfsigned    True    10m
```

- `get issuers -A` da har Issuer o'z namespace'iga bog'langan, `get clusterissuers` da esa `NAMESPACE` ustuni yo'q.
- `READY True`: issuer tekshirildi (masalan, CA Secret'i topildi yoki ACME akkaunt ro'yxatdan o'tdi). `False` bo'lsa sababi `describe` dagi `Status.Conditions` da.

### Real ishda qachon kerak

Odatiy kelishuv: platforma jamoasi `letsencrypt-prod` va `internal-ca` ClusterIssuer'larini beradi, ilova jamoalari faqat Certificate yoki Ingress annotation yozadi. Namespaced Issuer esa jamoa o'z PKI'siga ega bo'lganda yoki ko'p ijarali (multi-tenant) klasterda bir jamoa boshqasining CA'sidan foydalanmasligi kerak bo'lganda.

### Nima uchun shunday

Bu Kubernetes'dagi umumiy naqsh: Role va ClusterRole (13-dars) ham xuddi shunday ikkiga bo'lingan. Namespace izolyatsiya chegarasi, va ruxsat chegaradan oshishi uchun cluster-scoped obyekt kerak; uni yaratish uchun esa klaster darajasidagi huquq kerak, ya'ni oddiy jamoa a'zosi buni o'zi qila olmaydi.

## 5. selfSigned va CA issuer: lokal PKI

### Bu nima

PKI (Public Key Infrastructure) bu CA'lar, ular chiqargan sertifikatlar va ishonch qoidalari tizimi. `selfSigned` issuer sertifikatni o'zining kaliti bilan imzolaydi (issuer va subject bir xil). Bunday sertifikatga hech kim ishonmaydi, uning asosiy vazifasi root CA yaratish. `ca` issuer esa Secret'dagi CA kaliti bilan boshqa sertifikatlarni imzolaydi.

### Mexanizm

Standart naqsh uch qadamdan iborat:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: selfsigned}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: lab-root-ca, namespace: cert-manager}
spec:
  isCA: true
  commonName: lab-root-ca
  secretName: lab-root-ca
  privateKey: {algorithm: ECDSA, size: 256}
  issuerRef: {name: selfsigned, kind: ClusterIssuer}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: lab-ca}
spec:
  ca: {secretName: lab-root-ca}
```

1. `selfsigned` ClusterIssuer: "o'zing imzola".
2. `lab-root-ca` Certificate: `isCA: true` sertifikatga "boshqa sertifikatlarni imzolash mumkin" (`CA:TRUE` basic constraint) belgisini qo'yadi. U `selfsigned` bilan imzolanadi, natija `cert-manager` namespace'idagi `lab-root-ca` Secret'ida.
3. `lab-ca` ClusterIssuer: o'sha Secret'dagi kalit bilan imzolaydi.

Endi `lab-ca` istalgan namespace'dagi Certificate'ni root CA bilan imzolaydi. Klient (curl, brauzer, boshqa servis) bu sertifikatlarga ishonishi uchun root CA sertifikatini (`ca.crt`) ishonchli deb qo'shishi kerak. Ichki servislararo TLS va mTLS uchun aynan shunday xususiy PKI ishlatiladi.

### Ishlaydigan misol

Yuqoridagini qo'llagandan keyin:

```
$ kubectl get clusterissuers
NAME         READY   AGE
lab-ca       True    8s
selfsigned   True    8s
$ kubectl get certificate -n cert-manager
NAME          READY   SECRET        AGE
lab-root-ca   True    lab-root-ca   8s
$ kubectl get secret lab-root-ca -n cert-manager
NAME          TYPE                DATA   AGE
lab-root-ca   kubernetes.io/tls   3      8s
```

- `lab-ca` ning `READY True` bo'lishi uchun `lab-root-ca` Secret'i mavjud va ichida CA sertifikati bo'lishi kerak. Agar ClusterIssuer Secret'dan oldin tekshirilsa, bir necha soniya `False` turadi, keyin o'zi `True` ga o'tadi: reconciliation.
- `DATA 3`: `tls.crt`, `tls.key`, `ca.crt`. Self-signed root uchun `ca.crt` va `tls.crt` bir xil sertifikat.

Sertifikat tarkibini kalitga tegmasdan o'qish (`go-template` ichidagi `base64decode` ikkala mashinada bir xil ishlaydi, `base64 -d` farqlari bilan ovora bo'lmaysiz):

```
$ kubectl get secret lab-root-ca -n cert-manager -o go-template='{{index .data "tls.crt" | base64decode}}' \
    | openssl x509 -noout -subject -issuer
subject=CN=lab-root-ca
issuer=CN=lab-root-ca
```

`subject` va `issuer` bir xil: self-signed belgisi.

### Real ishda qachon kerak

Ichki servislar (ma'lumotlar bazasi, ichki API, message broker) uchun TLS, mTLS, webhook sertifikatlari, test va dev muhitlar. Ommaviy saytlar uchun emas: brauzerlar sizning root'ingizni bilmaydi.

### Tuzoq: root CA kaliti Secret'da

Kim `cert-manager` namespace'idagi Secret'larni o'qiy olsa, istalgan nom uchun ishonchli sertifikat chiqara oladi. Production'da root kalit klasterdan tashqarida (HSM, Vault, cloud CA) turadi, klasterda faqat oraliq CA.

### Nima uchun shunday

cert-manager'da "root CA yarat" degan alohida buyruq yo'q: root ham oddiy Certificate, faqat `isCA: true` va o'z-o'zini imzolaydigan issuer bilan. Bitta abstraksiya (Certificate) hamma narsani qoplaydi, root CA ham avtomatik yangilanadi. Muqobil, `openssl` bilan qo'lda CA yasash, Network modulida ko'rgansiz: ishlaydi, lekin yangilash va tarqatish yana qo'lda.

## 6. ACME: HTTP-01 va DNS-01

### Bu nima

ACME (Automatic Certificate Management Environment, RFC 8555) bu Let's Encrypt ishlatadigan protokol: klient akkaunt ochadi, domenlar uchun buyurtma (order) beradi, har domen uchun egalikni isbotlaydi (challenge), keyin CSR yuborib sertifikat oladi.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: letsencrypt-staging}
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: you@example.com
    privateKeySecretRef: {name: letsencrypt-staging-account}
    solvers:
      - http01:
          ingress: {ingressClassName: traefik}
```

- `server`: ACME serverining "directory" manzili. Bu staging; production manzili `acme-v02` bilan boshlanadi.
- `email`: muddat haqida ogohlantirishlar uchun (Let's Encrypt bu xizmatni qisqartirgan, shuning uchun o'z monitoringingiz shart, 9-bo'lim).
- `privateKeySecretRef`: ACME akkaunt kaliti shu Secret'ga yoziladi. Bu kalit akkauntning o'zi, uni yo'qotsangiz yangi akkaunt ochiladi.
- `solvers`: egalik qanday isbotlanadi.

### Mexanizm

| | HTTP-01 | DNS-01 |
|---|---------|--------|
| Isbot | `http://<domen>/.well-known/acme-challenge/<token>` manzilida fayl | `_acme-challenge.<domen>` nomli `TXT` yozuvi |
| cert-manager nima qiladi | vaqtinchalik solver pod, Service va Ingress (yoki HTTPRoute) yaratadi | DNS provayder API'si orqali yozuv qo'shadi |
| Talab | domen klasterning 80-portiga internetdan yetib borishi | DNS provayder API credential'i |
| Wildcard (`*.example.com`) | yo'q | ha |
| Ichki, internetdan yopiq klaster | ishlamaydi | ishlaydi |

HTTP-01 qadamlari: cert-manager Order yaratadi, ACME server har domen uchun token beradi. cert-manager token'ni qaytaradigan kichik solver pod ko'taradi va uni Ingress orqali `/.well-known/acme-challenge/<token>` yo'liga ulaydi. Avval o'zi tekshiradi (self-check): DNS bo'yicha domenga borib, kutilgan javob kelyaptimi. O'tsa ACME serveriga "tayyor" deydi, Let's Encrypt o'z serverlaridan internet orqali shu manzilni so'raydi. Javob to'g'ri bo'lsa Challenge `valid`, Order `valid`, sertifikat imzolanadi va vaqtinchalik obyektlar o'chiriladi.

Self-check o'tmasa Challenge `pending` holatida qoladi va sababi uning `status` ida yoziladi; cert-manager ACME serveriga hali murojaat qilmaydi, bu muvaffaqiyatsiz urinishlar limitini behuda sarflashdan saqlaydi.

### Ishlaydigan misol

Issuer'ni yaratgandan keyin akkaunt ro'yxatdan o'tishi (klaster internetga chiqa olsa, kirishi shart emas):

```
$ kubectl get clusterissuer letsencrypt-staging
NAME                  READY   AGE
letsencrypt-staging   True    15s
$ kubectl describe clusterissuer letsencrypt-staging | grep -A3 'Acme:'
  Acme:
    Last Private Key Hash:  <hash>
    Last Registered Email:  you@example.com
    Uri:                    https://acme-staging-v02.api.letsencrypt.org/acme/acct/<id>
```

- `READY True`: ACME server akkauntni qabul qildi. Bu faqat chiquvchi HTTPS so'rov talab qiladi.
- `Uri`: akkaunt manzili ACME serverida, `<id>` sizning akkaunt raqamingiz.

Staging va production. Let's Encrypt production muhitida qattiq rate limit'lar bor (domen bo'yicha haftalik limitlar, muvaffaqiyatsiz urinishlar limiti). Sozlash va sinov har doim staging serverida bajariladi; uning sertifikatlari brauzerda ishonchli emas, lekin jarayon bir xil. Hammasi ishlagach issuer production manziliga almashtiriladi.

### Real ishda qachon kerak

Internetga ochiq har domen uchun bepul, avtomatik yangilanadigan ommaviy sertifikat. HTTP-01 eng sodda, chunki faqat 80-port ochiq bo'lishi kerak. DNS-01 wildcard, ichki klaster yoki bir domen bir nechta klasterda bo'lganda.

### Nima uchun shunday

CA'ning asosiy savoli: "so'rovchi bu domenni haqiqatan boshqaradimi?". HTTP-01 "domen ko'rsatgan serverni boshqaraman" deb isbotlaydi, DNS-01 esa "domen zonasini boshqaraman" deb. Ikkinchisi kuchliroq (shuning uchun wildcard faqat u bilan), lekin DNS API credential'ini klasterga berishni talab qiladi, bu esa o'z xavfi.

## 7. Certificate obyekti

### Bu nima

Certificate bu "shu nomlar uchun, shu issuer'dan, shu parametrlar bilan sertifikat shu Secret'da doim amalda bo'lsin" degan kerakli holat.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: app-tls, namespace: demo}
spec:
  secretName: app-tls              # where the key pair is stored
  dnsNames: [app.example.test]
  duration: 2160h                  # 90 days
  renewBefore: 720h                # renew 30 days before expiry
  privateKey: {algorithm: ECDSA, size: 256}
  issuerRef: {name: lab-ca, kind: ClusterIssuer}
```

### Mexanizm

- `duration` berilmasa 90 kun so'raladi (ACME'da muddatni CA belgilaydi). `renewBefore` berilmasa yangilash sertifikat umrining 2/3 qismi o'tganda boshlanadi.
- `status` da: `conditions` (`Ready`, `Issuing`), `notBefore`, `notAfter`, `renewalTime`, `revision`. `revision` har muvaffaqiyatli chiqarishda bittaga oshadi va CertificateRequest nomiga qo'shiladi (`app-tls-1`, `app-tls-2`).
- Yangi versiyalarda har qayta chiqarishda yopiq kalit ham yangilanadi (`privateKey.rotationPolicy: Always` standart).
- Secret'da `tls.crt`, `tls.key` va (issuer bersa) `ca.crt` bo'ladi.
- Certificate `spec` o'zgarsa (yangi `dnsNames`), cert-manager Secret'dagi sertifikat endi spec'ga mos emasligini ko'radi va darhol qayta chiqaradi.

### Ishlaydigan misol

```
$ kubectl describe certificate app-tls -n demo
...
Status:
  Conditions:
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               <date + 90d>
  Not Before:              <date>
  Renewal Time:            <date + 60d>
  Revision:                1
Events:
  Type    Reason     Age   From                                       Message
  Normal  Issuing    12s   cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  12s   cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "app-tls-<s>"
  Normal  Requested  12s   cert-manager-certificates-request-manager  Created new CertificateRequest resource "app-tls-1"
  Normal  Issuing    11s   cert-manager-certificates-issuing          The certificate has been successfully issued
```

- `Ready True` va xabar: sertifikat amalda va spec'ga mos.
- `Renewal Time`: `Not After` minus `renewBefore`. Shu paytda controller o'zi yangi CertificateRequest yaratadi.
- Event'lar zanjirni qadam-baqadam ko'rsatadi: nima uchun chiqarish boshlandi (Secret yo'q), kalit yaratildi, CertificateRequest yaratildi, sertifikat yozildi. `From` ustunidagi nomlar cert-manager controller'ining ichki qismlari.

Qo'lda tekshirish va yangilash uchun `cmctl` CLI bor (https://cert-manager.io/docs/reference/cmctl/): `cmctl status certificate NAME`, `cmctl renew NAME`. Hujjat Secret'ni o'chirish orqali yangilashni tavsiya qilmaydi.

### Tuzoq: yangilangan sertifikat va ilova

cert-manager Secret'ni yangilaydi, lekin uni ishlatayotgan jarayon yangi faylni o'qishi kerak. Ingress controller'lar Secret'ni API orqali kuzatib, o'zi qayta yuklaydi. Volume sifatida ulangan Secret fayli kubelet tomonidan biroz kechikish bilan yangilanadi (`subPath` bilan ulangan bo'lsa umuman yangilanmaydi), lekin o'z ilovangiz sertifikatni ishga tushganda bir marta o'qib xotirada ushlasa, muddati o'tguncha eski sertifikat bilan ishlaydi.

### Real ishda qachon kerak

Ingress'siz joylarda to'g'ridan-to'g'ri Certificate yoziladi: ichki servis TLS'i, mTLS klient sertifikati, Gateway (agar annotation ishlatilmasa), ma'lumotlar bazasi serveri. Ingress uchun odatda annotation yetarli (8-bo'lim).

### Nima uchun shunday

Secret'ni "mahsulot", Certificate'ni "buyurtma" qilib ajratish iste'molchilarni o'zgartirmaydi: Ingress, pod va boshqa har narsa oddiy `kubernetes.io/tls` Secret'ni o'qiydi va cert-manager borligini bilmaydi. cert-manager'ni olib tashlasangiz ham Secret'lar ishlashda davom etadi (faqat yangilanmaydi).

## 8. Ingress annotation'lari

### Bu nima

Har Ingress uchun Certificate'ni qo'lda yozmaslik mumkin. cert-manager'ning ingress-shim qismi Ingress'larni kuzatadi va annotation bo'lsa Certificate'ni o'zi yaratadi:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: lab-ca    # or cert-manager.io/issuer for a namespaced Issuer
spec:
  ingressClassName: traefik
  tls:
    - hosts: [app.example.test]
      secretName: app-tls
```

### Mexanizm

ingress-shim har Ingress o'zgarishini ko'radi. Annotation bor bo'lsa, har `tls` elementi uchun Certificate yaratadi: nomi `tls.secretName` dan, `dnsNames` esa `tls.hosts` dan olinadi, `issuerRef` annotation'dan. Certificate'ning `ownerReferences` ida Ingress turadi, shuning uchun Ingress o'chirilsa Certificate ham o'chadi (garbage collection, 4-dars). Keyin oddiy zanjir: CertificateRequest, Secret. Ingress controller Secret paydo bo'lishini kuzatadi va sertifikatni beradi. Secret paydo bo'lguncha controller o'zining standart (odatda self-signed) sertifikatini beradi.

### Ishlaydigan misol

```
$ kubectl get ingress,certificate -n shop
NAME                             CLASS     HOSTS              ADDRESS      PORTS     AGE
ingress.networking.k8s.io/shop   traefik   shop.example.test  172.18.0.5   80, 443   30s

NAME                                    READY   SECRET     AGE
certificate.cert-manager.io/shop-tls    True    shop-tls   30s
```

- `PORTS 80, 443`: `tls` bo'limi borligi uchun controller 443'da ham tinglaydi. Certificate'ni siz yaratmadingiz, nomi `secretName` bilan bir xil: ingress-shim belgisi.

Gateway API uchun ham xuddi shunday mexanizm bor (Gateway obyektidagi annotation va listener'ning TLS sozlamasi), u cert-manager konfiguratsiyasida alohida yoqiladi. Ingress API muzlatilgani sababli (3-dars) yangi loyihalarda shu yo'l asosiy bo'lib bormoqda.

Bu darsda ingress controller sifatida Traefik ishlatiladi: u faol yuritiladi, Ingress va Gateway API'ni qo'llaydi, k3s'da standart keladi (2-dars). To'xtatilgan ingress-nginx uchun yozilgan eski cert-manager qo'llanmalaridagi `ingressClassName: nginx` ni ko'r-ko'rona ko'chirmang.

### Real ishda qachon kerak

Ingress orqali chiqadigan ilovalarning aksariyati: ilova jamoasi bitta annotation qo'shadi, qolganini platforma hal qiladi. Maxsus parametr (`duration`, kalit algoritmi) kerak bo'lsa qo'shimcha annotation'lar bor yoki Certificate qo'lda yoziladi.

### Nima uchun shunday

Ilova jamoasi uchun "minimal yuza": u PKI'ni bilishi shart emas, faqat qaysi issuer'ni ishlatishni. Kamchiligi: konfiguratsiya annotation qatorlariga yashiringan va xato yozilsa validatsiya yo'q, xato faqat event'larda ko'rinadi.

## 9. Yangilanish va kuzatuv

### Bu nima

Avtomatik yangilanish ishlaydi, lekin "avtomatik" degani "kuzatilmaydi" degani emas. Yangilanish quyidagi sabablarga ko'ra sinishi mumkin: DNS o'zgargan, firewall 80-portni yopgan, DNS API credential'i eskirgan, rate limit, issuer o'chirilgan. Natija bir xil: 60-kunda boshlangan muvaffaqiyatsiz yangilash 90-kunda uzilishga aylanadi.

### Mexanizm

Controller har Certificate uchun `renewalTime` ni hisoblaydi va o'sha paytga taymer qo'yadi. Vaqt kelganda yangi CertificateRequest (`revision + 1`) yaratadi. Muvaffaqiyatsiz bo'lsa Certificate `Ready` holati darhol `False` ga o'tmaydi (eski sertifikat hali amalda), lekin `Issuing` sharti va event'larda xato paydo bo'ladi va qayta urinishlar orasidagi kutish oshib boradi. Shu sabab `READY` ustunining o'zi yetarli signal emas.

### Ishlaydigan misol

```
$ kubectl get certificate -A
NAMESPACE      NAME          READY   SECRET        AGE
cert-manager   lab-root-ca   True    lab-root-ca   2d
shop           shop-tls      True    shop-tls      2d
billing        billing-tls   False   billing-tls   40d
```

`billing-tls` `False`: e'tibor kerak. Lekin `True` bo'lganlar ham yangilashda qiynalayotgan bo'lishi mumkin, buni metrikalar ko'rsatadi.

Kuzatish:

- `kubectl get certificate -A`: `READY` ustuni `False` bo'lganlar.
- cert-manager Prometheus metrikalari: `certmanager_certificate_expiration_timestamp_seconds` va `certmanager_certificate_ready_status`. Alert: "sertifikat muddati N kundan kam qoldi" va "Certificate uzoq vaqt Ready emas" (observability moduli).
- Tashqi tekshiruv (blackbox): tashqaridan haqiqatda qaysi sertifikat berilayotgani va uning muddati. Bu Secret yangilangan, lekin proxy uni yuklamagan holatni ham ushlaydi.

### Real ishda qachon kerak

Har production klasterda kamida bitta alert: "berilayotgan sertifikat muddati 14 kundan kam". 90 kunlik sertifikat 30 kun oldin yangilanadigan bo'lsa, bu alert yonsa demak 16 kun davomida yangilash sinib turgan.

### Nima uchun shunday

`renewBefore` ning keng oralig'i (umrning uchdan biri) aynan xato bo'lganda odamga reaksiya qilish vaqti berish uchun. Avtomatika uzilishni yo'qotmaydi, uni kechiktiradi va xabar beradi, agar siz xabarni eshitadigan qilib qo'ysangiz.

## 10. Muammoni qidirish

### Bu nima

Sertifikat `Ready` bo'lmasa, xato zanjirning qaysidir bo'g'inida. Usul: zanjir bo'ylab yuqoridan pastga yuring, har obyektning `describe` chiqishidagi `Status` va `Events` ni o'qing. Bu 3-darsdagi `ImagePullBackOff` qidirish bilan bir xil fikrlash: Deployment, ReplicaSet, Pod, Events.

### Mexanizm

```bash
kubectl get certificate,certificaterequest,order,challenge -n demo
kubectl describe certificate app-tls -n demo
kubectl describe certificaterequest -n demo
kubectl describe order -n demo
kubectl describe challenge -n demo
kubectl logs -n cert-manager deploy/cert-manager
```

| Qayerda to'xtagan | Odatiy sabab |
|-------------------|--------------|
| Certificate `Ready=False`, CertificateRequest yo'q | issuer topilmadi (nom, `kind`, yoki Issuer boshqa namespace'da) |
| Issuer yoki ClusterIssuer `Ready=False` | ACME akkaunt ro'yxatdan o'tmadi, CA Secret'i topilmadi |
| Order `invalid` | ACME server rad etdi: sababi Order va Challenge `status` ida |
| Challenge `pending`, HTTP-01 | self-check o'tmayapti: DNS boshqa IP'ga qaraydi, 80-port yopiq, solver Ingress'i boshqa class'da, HTTP'dan HTTPS'ga majburiy redirect |
| Challenge `pending`, DNS-01 | DNS API credential'i xato, noto'g'ri zona, yozuv hali tarqalmagan |
| Sertifikat bor, brauzer eski sertifikatni ko'rsatadi | proxy Secret'ni qayta yuklamagan, yoki Ingress boshqa `secretName` ga qaraydi |

### Ishlaydigan misol

ACME zanjiri ko'rinishi (Challenge yopishib qolgan holat):

```
$ kubectl get certificate,certificaterequest,order,challenge -n shop
NAME                                   READY   SECRET     AGE
certificate.cert-manager.io/shop-tls   False   shop-tls   4m

NAME                                            APPROVED   DENIED   READY   ISSUER                REQUESTER                                         AGE
certificaterequest.cert-manager.io/shop-tls-1   True                False   letsencrypt-staging   system:serviceaccount:cert-manager:cert-manager   4m

NAME                                                  STATE     AGE
order.acme.cert-manager.io/shop-tls-1-<hash>          pending   4m

NAME                                                         STATE     DOMAIN              AGE
challenge.acme.cert-manager.io/shop-tls-1-<hash>-<hash2>     pending   shop.example.com    4m
```

- Har obyekt nomi oldingisidan yasalgan: zanjirni nomdan ko'rasiz.
- CertificateRequest `APPROVED True`, `READY False`: so'rov tasdiqlangan, lekin imzo hali yo'q. `REQUESTER` uni kim yaratganini ko'rsatadi (cert-manager'ning ServiceAccount'i).
- Order va Challenge `pending`: eng pastki bo'g'in Challenge, sabab uning `describe` chiqishidagi `Reason` maydonida (masalan, self-check'da qanday HTTP javob kelgani).

Qoida: eng pastdagi muammoli obyektdan boshlab o'qing, chunki yuqoridagilar faqat "pastda kutyapman" deydi.

### Real ishda qachon kerak

Har yangi domen, har yangi klaster va har issuer o'zgarishida. Runbook (18-vazifa) shu jadvalning sizning muhitingizga moslangan versiyasi bo'ladi.

### Nima uchun shunday

Zanjirni alohida obyektlarga bo'lish (3-bo'lim) aynan shu debug uchun foydali: har bo'g'inning o'z `status` i va event'lari bor, va siz qaysi bo'g'in, demak qaysi tizim (issuer konfiguratsiyasi, ACME server, DNS, tarmoq, ingress) aybdor ekanini tez topasiz.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| TLS | TCP ulanishni shifrlaydigan va server shaxsini tasdiqlaydigan protokol |
| Sertifikat | ochiq kalit va domen nomlari, ustida CA imzosi |
| CA | sertifikatlarni imzolaydigan, klientlar ishonadigan tashkilot yoki kalit |
| SAN | sertifikatdagi domen nomlari ro'yxati, klient aynan shuni tekshiradi |
| SNI | klient TLS boshida yuboradigan, ulanmoqchi bo'lgan host nomi |
| Helm chart | versiyalangan manifest shablonlari va standart values to'plami |
| Release / revision | chart'ning klasterdagi nomlangan nusxasi / uning har o'zgarishi |
| Admission webhook | API server obyektni yozishdan oldin chaqiradigan validatsiya servisi |
| Issuer / ClusterIssuer | sertifikat manbai, namespace ichida / butun klaster uchun |
| Certificate | "shu nomlar uchun sertifikat shu Secret'da bo'lsin" degan kerakli holat |
| CertificateRequest | bitta aniq CSR va uning natijasi |
| ACME | sertifikatni avtomatik olish protokoli (Let's Encrypt) |
| Order / Challenge | ACME buyurtmasi / bitta domen uchun egalik tekshiruvi |
| HTTP-01 / DNS-01 | egalikni HTTP fayl / DNS `TXT` yozuvi orqali isbotlash |
| ingress-shim | annotation'li Ingress'dan Certificate yaratadigan cert-manager qismi |
| Staging | Let's Encrypt'ning sinov serveri, sertifikatlari ishonchsiz, limitlari yumshoq |

## Tuzoqlar

- Sozlashni Let's Encrypt production serverida boshlash: bir necha xato urinishdan keyin rate limit va bir hafta kutish.
- Internetdan ko'rinmaydigan klasterda HTTP-01 kutish.
- Wildcard sertifikatni HTTP-01 bilan olishga urinish.
- `Issuer` ni boshqa namespace'dagi Certificate'dan ishlatishga urinish, yoki `issuerRef` da `kind: ClusterIssuer` ni yozishni unutish.
- CA yoki ACME akkaunt Secret'larini himoyasiz qoldirish, root CA kalitini klasterda saqlash.
- Yangilanishni kuzatmaslik: avtomatika jim sinadi, uzilish 30 kundan keyin keladi.
- Chart versiyasini qotirmaslik va values'ni `--set` bilan berib git'da saqlamaslik.
- `helm rollback` dan keyin git'dagi values faylini tuzatmaslik: keyingi `upgrade` buzuq qiymatni qaytaradi.
- cert-manager CRD'larini o'ylamay o'chirish: barcha Certificate obyektlari ham o'chadi.
- Staging sertifikatini production'da qoldirish: brauzerlar ishonmaydi.
- Ilova sertifikatni bir marta o'qiydi va yangilanganini bilmaydi; Secret'ni `subPath` bilan ulash (fayl umuman yangilanmaydi).
- macOS'da LB IP'ga host'dan `curl` qilib "ishlamayapti" deb o'ylash: Docker yashirin VM'da, `port-forward` ishlating.

## Manbalar

- https://helm.sh/docs/intro/using_helm/ – Helm'dan foydalanish
- https://helm.sh/docs/topics/charts/ – chart tuzilishi
- https://cert-manager.io/docs/concepts/ – cert-manager tushunchalari
- https://cert-manager.io/docs/installation/helm/ – Helm bilan o'rnatish
- https://cert-manager.io/docs/configuration/ – issuer turlari (selfSigned, CA, ACME)
- https://cert-manager.io/docs/configuration/acme/ – ACME, HTTP-01 va DNS-01
- https://cert-manager.io/docs/usage/certificate/ – Certificate obyekti
- https://cert-manager.io/docs/usage/ingress/ – Ingress annotation'lari
- https://cert-manager.io/docs/troubleshooting/acme/ – ACME muammolarini qidirish
- https://cert-manager.io/docs/reference/cmctl/ – cmctl
- https://letsencrypt.org/docs/staging-environment/ – Let's Encrypt staging
- https://letsencrypt.org/docs/challenge-types/ – challenge turlari
- https://doc.traefik.io/traefik/ – Traefik hujjatlari
- https://github.com/traefik/whoami – "Birga bajaramiz" dagi whoami servisi

## Birga bajaramiz

Vazifalardan boshqa misol: klaster ichidagi servisga, Ingress'siz, namespaced PKI bilan TLS berish va uni klaster ichidagi klientdan tekshirish. Yo'l davomida Issuer zanjirini, Certificate'dan Secret'gacha bo'lgan oqimni, Secret'ni pod'ga ulashni va klientga faqat `ca.crt` ni berishni ko'ramiz. Bu 5-vazifadan keyin bajariladi (cert-manager o'rnatilgan bo'lishi kerak), hammasi `wt` namespace'ida, ikkala mashinada bir xil.

1. Namespace va namespaced PKI. Bu safar hammasi `Issuer`, ClusterIssuer emas: CA kaliti `wt` namespace'ida yashaydi va faqat shu namespace'ga xizmat qiladi.

```yaml
# wt-pki.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: wt-selfsigned, namespace: wt}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: wt-root, namespace: wt}
spec:
  isCA: true
  commonName: wt-root
  secretName: wt-root
  duration: 8760h                  # 1 year
  privateKey: {algorithm: ECDSA, size: 256}
  issuerRef: {name: wt-selfsigned, kind: Issuer}
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: wt-ca, namespace: wt}
spec:
  ca: {secretName: wt-root}
```

```
$ kubectl create namespace wt && kubectl apply -f wt-pki.yaml
$ kubectl get issuers,certificates -n wt
NAME                                   READY   AGE
issuer.cert-manager.io/wt-ca           True    6s
issuer.cert-manager.io/wt-selfsigned   True    6s

NAME                                  READY   SECRET    AGE
certificate.cert-manager.io/wt-root   True    wt-root   6s
```

Uchala obyekt `Ready`. `wt-ca` bir lahza `False` bo'lishi mumkin (Secret hali yo'q), keyin o'zi tuzaladi.

2. Servis sertifikati. Klaster ichidagi DNS nomlari (6-dars): `whoami.wt.svc` va to'liq `whoami.wt.svc.cluster.local`.

```yaml
# whoami-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: whoami-tls, namespace: wt}
spec:
  secretName: whoami-tls
  dnsNames: [whoami.wt.svc, whoami.wt.svc.cluster.local]
  duration: 720h                   # 30 days
  privateKey: {algorithm: ECDSA, size: 256}
  issuerRef: {name: wt-ca, kind: Issuer}
```

```
$ kubectl apply -f whoami-cert.yaml
$ kubectl get certificate,certificaterequest -n wt
NAME                                     READY   SECRET       AGE
certificate.cert-manager.io/whoami-tls   True    whoami-tls   4s
certificate.cert-manager.io/wt-root      True    wt-root      2m

NAME                                              APPROVED   DENIED   READY   ISSUER          REQUESTER                                         AGE
certificaterequest.cert-manager.io/whoami-tls-1   True                True    wt-ca           system:serviceaccount:cert-manager:cert-manager   4s
certificaterequest.cert-manager.io/wt-root-1      True                True    wt-selfsigned   system:serviceaccount:cert-manager:cert-manager   2m
```

Har Certificate uchun bitta CertificateRequest, nomida `-1` (revision). `ISSUER` ustuni zanjirni ko'rsatadi: root o'zini o'zi, servis sertifikati root bilan.

3. Sertifikatni kalitga tegmasdan tekshirish:

```
$ kubectl get secret whoami-tls -n wt -o go-template='{{index .data "tls.crt" | base64decode}}' \
    | openssl x509 -noout -subject -issuer -dates
subject=
issuer=CN=wt-root
notBefore=<date> GMT
notAfter=<date + 30d> GMT
```

`subject` bo'sh: `commonName` bermadik, nomlar faqat SAN'da, bu zamonaviy amaliyot. `issuer=CN=wt-root`: zanjir to'g'ri. `-text` bilan SAN'da ikkala DNS nomi borligini ko'ring.

4. TLS servis. `traefik/whoami` kichik HTTP servis, so'rov haqidagi ma'lumotni qaytaradi va `--cert`/`--key` bilan TLS'da ishlay oladi. Secret volume sifatida ulanadi (4-dars), `subPath` siz:

```yaml
# whoami.yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: whoami, namespace: wt}
spec:
  replicas: 1
  selector: {matchLabels: {app: whoami}}
  template:
    metadata: {labels: {app: whoami}}
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10.1
          args: ["--port", "8443", "--cert", "/certs/tls.crt", "--key", "/certs/tls.key"]
          ports: [{containerPort: 8443}]
          volumeMounts: [{name: tls, mountPath: /certs, readOnly: true}]
      volumes:
        - name: tls
          secret: {secretName: whoami-tls}
---
apiVersion: v1
kind: Service
metadata: {name: whoami, namespace: wt}
spec:
  selector: {app: whoami}
  ports: [{port: 443, targetPort: 8443}]
```

```
$ kubectl apply -f whoami.yaml
$ kubectl rollout status deployment/whoami -n wt
deployment "whoami" successfully rolled out
```

5. Klient. Unga faqat `ca.crt` kerak, `tls.key` emas. Secret volume'ning `items` maydoni Secret'dan faqat tanlangan kalitni faylga aylantiradi:

```yaml
# client.yaml
apiVersion: v1
kind: Pod
metadata: {name: client, namespace: wt}
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["sleep", "3600"]
      volumeMounts: [{name: ca, mountPath: /ca, readOnly: true}]
  volumes:
    - name: ca
      secret:
        secretName: whoami-tls
        items: [{key: ca.crt, path: ca.crt}]
```

```
$ kubectl apply -f client.yaml
$ kubectl exec -n wt client -- ls /ca
ca.crt
$ kubectl exec -n wt client -- curl -sS --cacert /ca/ca.crt https://whoami.wt.svc/
Hostname: whoami-<hash>-<s>
IP: 127.0.0.1
IP: 10.244.<x>.<y>
RemoteAddr: 10.244.<a>.<b>:<port>
GET / HTTP/1.1
Host: whoami.wt.svc
User-Agent: curl/8.10.1
Accept: */*
```

- `ls /ca` da faqat `ca.crt`: klient pod'iga servisning yopiq kaliti tushmadi.
- `curl --cacert` muvaffaqiyatli: zanjir `wt-root` gacha tekshirildi, `whoami.wt.svc` SAN'da bor.
- `Host: whoami.wt.svc`: so'rov qaysi nom bilan kelgani.

6. Nom SAN'da bo'lmasa nima bo'lishini ko'ramiz (qisqa `whoami` nomi ham ishlaydi, chunki pod `wt` ichida, lekin sertifikatda u yo'q):

```
$ kubectl exec -n wt client -- curl -sS --cacert /ca/ca.crt https://whoami/
curl: (60) SSL: no alternative certificate subject name matches target host name 'whoami'
command terminated with exit code 60
```

DNS ishladi, TCP va TLS boshlandi, lekin klient SAN'da `whoami` ni topmadi va ulanishni uzdi. Tuzatish yo'li klientni o'zgartirish emas, Certificate'ga nom qo'shish: `dnsNames` ga `whoami` qo'shib `apply` qiling va `kubectl get certificate whoami-tls -n wt -o jsonpath='{.status.revision}'` 2 ga o'tganini ko'ring. Keyin `kubectl rollout restart deployment/whoami -n wt` va so'rovni takrorlang. Restart nima uchun kerak bo'lishi mumkinligi (7-bo'limdagi tuzoq) 13-vazifa mavzusi, bu yerda uni ochmaymiz.

7. Tozalash: `kubectl delete namespace wt`. Namespace bilan Issuer'lar, Certificate'lar, Secret'lar va root kaliti ham o'chdi. Shu klasterda `wt-root` ga ishonadigan hech narsa qolmadi: namespaced PKI'ning afzalligi ham, xavfi ham shu.

---

## Vazifalar

Barchasini `kubernetes/08-cert-manager/` papkasida bajaring (`make new m=kubernetes n=08 name=cert-manager`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml`, Helm values fayllari `values/` ichida saqlanadi. Yopiq kalitlar, Secret tarkibi va ACME akkaunt kaliti hech qayerga yozilmaydi. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozib qo'ying.

`<LB-IP>` bilan yozilgan buyruqlar (2, 9, 10, 13 vazifalar) Zorin'da shu ko'rinishda ishlaydi. macOS'da LB IP host'dan ko'rinmaydi: Laboratoriya bo'limidagi `kubectl port-forward -n traefik svc/traefik 8443:443` ni ishlating va `--resolve app.example.test:8443:127.0.0.1`, `openssl s_client -connect 127.0.0.1:8443` ko'rinishiga o'tkazing. 16-vazifadagi `sslip.io` nomi uchun esa LB IP'ning o'zi kerak, uni `kubectl get svc -n traefik` dan oling, u ikkala mashinada mavjud (macOS'da faqat VM ichida).

### A. Helm

1. **Install Helm.** Helm'ni o'rnating, `helm version` ni ko'rsating. Klasterga hech narsa o'rnatmasdan o'rganing: `helm show chart` va `helm show values` bilan cert-manager chart'ini (OCI manzili orqali) ko'ring. Chart versiyasi va `appVersion` farqi nima? `helm template` bilan chart'ni render qilib, nechta va qanday turdagi obyekt yaratilishini sanang (`grep '^kind:' | sort | uniq -c`). Ular orasida klaster darajasidagi qaysi huquqlar bor?

2. **Install Traefik.** Traefik repozitoriysini qo'shing va chart'ni `traefik` namespace'iga, versiyasi qotirilgan holda, `values/traefik.yaml` fayli bilan o'rnating (boshida fayl bo'sh bo'lishi mumkin). `helm list -A`, `kubectl get all -n traefik` va `kubectl get ingressclass` natijasini ko'rsating. Service qanday turda va `cloud-provider-kind` unga qanday IP berdi? Shu IP'ga `curl` nima qaytaradi va nima uchun?

3. **Release internals.** `helm get manifest`, `helm get values` (`--all` bilan va usiz) natijalarini solishtiring. `traefik` namespace'ida Helm release ma'lumoti saqlangan Secret'ni toping: nomi va turi qanday? Helm'ning klasterda server qismi yo'qligini qanday tekshirasiz? `helm template` chiqishi bilan `helm get manifest` farq qiladimi?

4. **Upgrade and rollback.** `values/traefik.yaml` da replikalar sonini 2 ga o'zgartiring (to'g'ri kalit nomini `helm show values` dan toping) va `helm upgrade` qiling. `helm history` ni ko'rsating. Keyin atayin buzuq qiymat bering (masalan, mavjud bo'lmagan image tag'i) va upgrade qiling: release holati qanday, pod'lar qanday, eski pod'lar xizmat qilyaptimi? `helm rollback` bilan qaytaring. Rollback'dan keyin revision raqami nechchi va nima uchun? Git'dagi values fayli bilan klaster orasidagi farqqa e'tibor bering (3-darsdagi `rollout undo` tuzog'i bilan solishtiring).

### B. cert-manager

5. **Install cert-manager.** 3-bo'limdagi buyruq bilan, versiyasi qotirilgan holda o'rnating (`--set` o'rniga `values/cert-manager.yaml` fayli bilan). Uchala Deployment tayyor bo'lishini kuting. `kubectl get crd | grep cert-manager` va `kubectl api-resources --api-group=cert-manager.io` natijasini ko'rsating. `crds.enabled=true` bermasangiz nima bo'lardi? `kubectl get validatingwebhookconfigurations` da nima paydo bo'ldi va webhook pod'i o'chiq bo'lsa Certificate yaratishga nima bo'ladi (sinab ko'ring: webhook Deployment'ini 0 ga scale qilib, keyin qaytaring)?

6. **Self-signed certificate.** `demo` namespace'ida `selfSigned` turidagi `Issuer` va undan `test.example.test` uchun Certificate yarating. Yaratilgan Secret'ning turi va kalitlarini ko'rsating (qiymatlarini emas). Sertifikatni `kubectl get secret -o jsonpath` va `openssl x509 -noout -text` bilan o'qing: `Issuer` va `Subject` maydonlari, SAN, amal qilish muddati. Self-signed ekanini qaysi belgidan bilasiz? `kubectl get certificaterequest` da nima bor?

7. **CA chain.** 5-bo'limdagi naqsh bo'yicha root CA va `lab-ca` ClusterIssuer yarating. `demo` namespace'ida `lab-ca` dan sertifikat oling. `openssl verify -CAfile ca.crt tls.crt` bilan zanjirni tekshiring (fayllarni vaqtinchalik katalogga chiqaring, ish papkasiga emas). Leaf sertifikatdagi `Issuer` maydoni nimaga teng? Secret'dagi `ca.crt` qayerdan keldi? Root CA Secret'i nima uchun aynan `cert-manager` namespace'ida bo'lishi kerak?

8. **Issuer scope.** `team-a` namespace'ida `Issuer` yarating va unga `team-b` namespace'idagi Certificate'dan murojaat qiling. Certificate holati, `describe` dagi event va xabarni yozing. CertificateRequest yaratildimi? Ikki usul bilan tuzating (`ClusterIssuer`, yoki `team-b` da o'z `Issuer` i) va qaysi biri qachon to'g'ri ekanini yozing.

### C. Ingress va TLS

9. **TLS Ingress.** `demo` da oddiy ilova (nginx yoki `agnhost`), Service va Ingress yarating: `ingressClassName` Traefik'niki, host `app.example.test`, `tls` bo'limi va `cert-manager.io/cluster-issuer: lab-ca` annotation'i. Certificate avtomatik paydo bo'lganini ko'rsating. Tekshiring: `curl --cacert ca.crt --resolve app.example.test:443:<LB-IP> https://app.example.test/`. `curl -v` chiqishidan sertifikat `subject`, `issuer` va muddatini yozing.

10. **Trust.** 9-vazifadagi so'rovni `--cacert` siz bajaring va xatoni to'liq yozing. `-k` bilan nima o'zgaradi va bu nima uchun yechim emas? Annotation'ni olib tashlab, `tls.secretName` ni mavjud bo'lmagan Secret'ga qaratsangiz Traefik qanday sertifikat beradi (`openssl s_client -connect <LB-IP>:443 -servername app.example.test` bilan ko'ring)? Ichki CA'ga ishonchni tashkilotdagi barcha servis va ishchi mashinalarga tarqatishning qanday yo'llari bor?

11. **Ownership chain.** Annotation orqali yaratilgan Certificate, CertificateRequest va Secret'ning `ownerReferences` ni ko'rib, egalik zanjirini chizing. Ingress'ni o'chiring: Certificate bilan nima bo'ldi? Secret bilan-chi? Secret nima uchun standart holatda qoladi va bu xulqni qaysi sozlama o'zgartiradi (hujjatdan toping)? Faqat Secret'ni o'chirsangiz nima bo'ladi?

### D. Yangilanish

12. **Short-lived certificate.** `duration: 1h` va `renewBefore: 55m` bilan Certificate yarating. `status.notAfter`, `status.renewalTime` va `status.revision` ni yozing. 10 daqiqa kuzating (`kubectl get certificate -w`, `kubectl get certificaterequest`): yangilanish qachon bo'ldi, nechta CertificateRequest bor, sertifikat serial raqami va yopiq kalit o'zgardimi (`openssl x509 -noout -serial`, kalit uchun ochiq kalit hash'ini solishtiring)? Ruxsat etilgan eng kichik `duration` qancha ekanini undan kichik qiymat berib toping.

13. **Reload behaviour.** 12-vazifadagi qisqa umrli sertifikatni 9-vazifadagi Ingress'ga ulang. Yangilanishdan keyin Traefik yangi sertifikatni qachon bera boshladi (`openssl s_client` bilan serial raqamni kuzating)? Endi shu Secret'ni oddiy nginx pod'iga volume sifatida ulang va nginx'ni shu sertifikat bilan 443-portda ishlatadigan qilib sozlang: yangilanishdan keyin pod ichidagi fayl va nginx berayotgan sertifikat bir xilmi? Muammoni va uning yechimlarini yozing.

14. **Manual renewal.** `cmctl` ni o'rnating. `cmctl status certificate` chiqishini 10-bo'limdagi zanjir bilan solishtiring. `cmctl renew` bilan sertifikatni muddatidan oldin yangilang va `revision` o'zgarishini ko'rsating. Qo'lda yangilash qachon kerak bo'ladi (kamida ikki holat)?

### E. ACME

15. **ACME staging issuer.** 6-bo'limdagi kabi `letsencrypt-staging` ClusterIssuer yarating (o'z email'ingiz bilan). `kubectl describe clusterissuer` da `Ready` holati va ACME akkaunt URI'sini ko'rsating. Akkaunt kaliti qayerda saqlandi? Klaster internetdan ko'rinmasa ham bu qadam nima uchun muvaffaqiyatli bo'ldi?

16. **Failing challenge.** Traefik LoadBalancer IP'siga ishora qiluvchi nom tuzing: `app.<LB-IP>.sslip.io` (sslip.io nom ichidagi IP'ni qaytaradigan ochiq DNS xizmati). Shu nom uchun `letsencrypt-staging` dan Certificate so'rang. 10-bo'limdagi zanjir bo'ylab yurib har obyektning holatini yozing: Certificate, CertificateRequest, Order, Challenge. Challenge paytida `demo` namespace'ida qanday vaqtinchalik pod, Service va Ingress paydo bo'ldi? cert-manager'ning self-check'i o'tdimi? Let's Encrypt nima deb javob berdi yoki nima uchun javob bera olmadi? Xulosa: bu tajriba HTTP-01 uchun qanday tarmoq talabini isbotlaydi? Oxirida Certificate'ni o'chiring (cheksiz qayta urinmasligi uchun).

17. **HTTP-01 vs DNS-01.** To'rt holat uchun challenge turini tanlang va asoslang: (a) internetga ochiq klasterdagi bitta sayt; (b) `*.apps.example.com` wildcard; (c) faqat VPN orqali kiriladigan ichki klaster, lekin ommaviy domen nomi bilan; (d) bitta domen bir nechta klasterga DNS orqali balanslanadi. DNS-01 uchun AWS Route 53 ishlatilsa, cert-manager'ga qanday IAM huquqlari kerakligini hujjatdan toping va minimal huquq tamoyili nuqtai nazaridan izohlang.

### F. Yakuniy

18. **Troubleshooting runbook.** Uchta nosozlikni atayin yarating va har birini 10-bo'limdagi zanjir bo'ylab qidirib, qaysi obyekt va qaysi maydon sababni ko'rsatganini hujjatlang: (a) Certificate'da mavjud bo'lmagan issuer nomi; (b) `lab-ca` ClusterIssuer ishora qilgan Secret nomini xato yozing; (c) Ingress `tls.hosts` va `rules.host` mos kelmaydi. Oxirida bir sahifali runbook tuzing: alomat, tekshirish buyrug'i, ehtimoliy sabab.

19. **TLS platform.** Hammasini deklarativ yig'ing, `platform/` papkasida: `values/traefik.yaml`, `values/cert-manager.yaml`, issuer manifestlari, va ikki namespace'dagi ikki ilova (har biri o'z host'i bilan, TLS annotation orqali). `install.sh` yozing: `helm upgrade --install` bilan ikkala chart (versiyalari qotirilgan), CRD va webhook tayyor bo'lishini kutish (`kubectl wait`), keyin manifestlar. Skript ikki marta ketma-ket ishlaganda xatosiz o'tishi kerak (idempotent). Isbot: ikkala host uchun `curl --cacert` muvaffaqiyatli; `kubectl get certificate -A` da hammasi `Ready`. README'da yozing: bu yechimni production'ga olib chiqish uchun nima o'zgaradi (issuer, challenge turi, root kalit joyi, monitoring), va Ingress o'rniga Gateway API ishlatilsa qaysi qismlar o'zgaradi. `shellcheck` toza bo'lsin. Skript ikkala mashinada (bash va macOS) ishlashi kerak; uni ikkinchi mashinada toza klasterda ishga tushirib ko'ring.

20. **Public issuance (optional).** Faqat sizda domen va internetdan ko'rinadigan server bo'lsa. Cloud modulidagi qoidalar bilan (budget alert, eng kichik instans, shu kuni o'chirish) bitta VM'da k3s ko'taring, domenning `A` yozuvini unga qarating, cert-manager o'rnating va Let's Encrypt staging'dan HTTP-01 bilan haqiqiy sertifikat oling. 16-vazifa bilan solishtiring: Order va Challenge qaysi holatlardan o'tdi? Sertifikat zanjirini `openssl s_client` bilan ko'rsating. VM'ni o'chiring va o'chirilganini tekshiring. Bajarmasangiz, README'da "o'tkazib yuborildi" deb yozing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha vazifalar yozilgan (20-vazifa ixtiyoriy), manifestlar, values fayllari va `install.sh` papkada.
2. `make check` toza o'tadi (`yamllint`, `shellcheck`).
3. Papkada yopiq kalit, sertifikat fayli, Secret manifesti yoki akkaunt kaliti yo'q (`git status` va `grep -r 'PRIVATE KEY' .` bilan tekshiring).
4. Release'lar `helm uninstall` qilingan, namespace'lar o'chirilgan, cert-manager CRD'lari bilan nima qilganingiz yozilgan; `port-forward` va `cloud-provider-kind` to'xtatilgan; cloud resurs yaratilgan bo'lsa o'chirilgan.
5. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Chart, release va values qanday bog'langan? Release holati qayerda saqlanadi?
- `helm rollback` dan keyin nima uchun git'dagi values faylini ham tuzatish kerak?
- Certificate yaratilgandan Secret paydo bo'lgunicha qaysi obyektlar qanday tartibda yaratiladi?
- `Issuer` va `ClusterIssuer` farqi nima va qaysi birini qachon tanlaysiz?
- selfSigned issuer nima uchun kerak, agar unga hech kim ishonmasa?
- HTTP-01 va DNS-01 qanday isbot talab qiladi? Qaysi biri wildcard beradi, qaysi biri yopiq klasterda ishlaydi?
- Let's Encrypt staging nima uchun kerak?
- Sertifikat avtomatik yangilanadi. Unda nimani va nima uchun kuzatish kerak?
- Sertifikat `Ready` emas. Qaysi tartibda nimani tekshirasiz?
- Secret yangilandi, lekin ilova eski sertifikatni beryapti. Nima uchun va qanday tuzatiladi?
