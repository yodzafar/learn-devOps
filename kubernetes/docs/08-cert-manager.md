# 8-dars: Sertifikatlarni boshqarish, cert-manager

Maqsad: Kubernetes'da TLS sertifikatlarini qo'lda emas, deklarativ va avtomatik boshqarish. Network modulida TLS, sertifikat zanjiri va Let's Encrypt bilan tanishgansiz; qo'lda `certbot` ishlatib sertifikat olish va uni cron bilan yangilash bitta serverda ishlaydi, lekin o'nlab servisli klasterda yo'q. cert-manager sertifikatni Kubernetes obyektiga aylantiradi: siz "shu nom uchun sertifikat kerak" deysiz, u oladi, Secret'ga yozadi va muddati tugashidan oldin yangilaydi. Bu darsda Helm ham birinchi marta ishlatiladi, chunki cert-manager va shunga o'xshash klaster addon'lari amalda Helm chart sifatida o'rnatiladi; Helm asoslari shu yerda beriladi, 9 va 10-darslarda (CI/CD, GitOps) davom etadi.

Taxminiy vaqt: 3 kun (siz uchun). Diqqat: Helm'da chart, release va values munosabati; cert-manager'da Certificate'dan Secret'gacha bo'lgan obyektlar zanjiri; HTTP-01 va DNS-01 qachon ishlaydi va qachon ishlamaydi; muammoni zanjir bo'ylab qanday qidirish.

## Laboratoriya

kind `dev` klasteri va ishlab turgan `cloud-provider-kind` (LoadBalancer IP uchun). Ustiga Helm bilan ikki narsa o'rnatiladi: Traefik (ingress controller) va cert-manager.

Helm o'rnatish (rasmiy yo'riqnoma: https://helm.sh/docs/intro/install/). Skriptni ishga tushirishdan oldin o'qib chiqing:

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh && ./get_helm.sh
helm version
```

Skript binary'ni `/usr/local/bin` ga qo'yadi va `sudo` so'raydi. Muqobil: releases sahifasidan arxivni yuklab, binary'ni `~/.local/bin` ga qo'yish.

Sertifikatlarning ko'p qismi lokal CA bilan chiqariladi, internetdan ko'rinadigan domen shart emas. ACME (Let's Encrypt) qismi lokal klasterda atayin "muvaffaqiyatsiz" tajriba sifatida o'tiladi: haqiqiy sertifikat olish uchun klaster internetdan ko'rinishi kerak, bu ixtiyoriy vazifa.

Tozalash: `helm uninstall` har release uchun, namespace'larni o'chirish, cert-manager CRD'larini tekshirish (ular `uninstall` dan keyin ham qoladi).

---

## 1. TLS eslatma va muammo

Sertifikat bu ochiq kalit va shaxs (domen nomlari, SAN) ustiga CA qo'ygan imzo. Klient zanjirni ishonchli root CA'gacha tekshiradi. Sertifikat olish jarayoni: yopiq kalit yaratiladi, CSR (Certificate Signing Request) tuziladi, CA domen egaligini tekshiradi va imzolaydi.

Kubernetes'da sertifikat `kubernetes.io/tls` turidagi Secret'da saqlanadi: `tls.crt` (sertifikat va oraliq zanjir) va `tls.key` (yopiq kalit). Ingress yoki Gateway unga nom orqali ishora qiladi:

```yaml
spec:
  tls:
  - hosts: [app.example.test]
    secretName: app-tls
```

Qo'lda boshqarishning muammolari: Let's Encrypt sertifikatlari 90 kun yashaydi va tendensiya yanada qisqa muddatlarga qarab ketmoqda; har servis, har muhit uchun alohida sertifikat; muddati o'tgan sertifikat eng ko'p uchraydigan va eng uyatli uzilish sabablaridan biri. Yechim avtomatlashtirish, va Kubernetes'da uning standart vositasi cert-manager.

## 2. Helm asoslari

Helm bu Kubernetes uchun paket menejeri. Uch asosiy tushuncha:

| Tushuncha | Ma'nosi | O'xshatish (npm) |
|-----------|---------|------------------|
| Chart | manifest shablonlari va standart qiymatlar to'plami, versiyalangan | paket |
| Values | shablonlarga beriladigan parametrlar (`values.yaml` va sizning o'zgartirishlaringiz) | konfiguratsiya |
| Release | chart'ning klasterga o'rnatilgan, nomlangan nusxasi. Har o'zgarish yangi revision | o'rnatilgan nusxa |
| Repository | chart'lar saqlanadigan joy: HTTP repo yoki OCI registry | registry |

Bitta chart'dan bir klasterda bir nechta release o'rnatish mumkin (turli nom va values bilan).

```bash
helm repo add traefik https://traefik.github.io/charts    # classic HTTP repository
helm repo update
helm show values traefik/traefik | less                   # all configurable values
helm install traefik traefik/traefik -n traefik --create-namespace -f traefik-values.yaml
helm list -A
```

OCI registry'dagi chart uchun `repo add` kerak emas, manzil to'g'ridan-to'g'ri beriladi: `helm install NAME oci://registry/path/chart --version X`.

| Buyruq | Nima qiladi |
|--------|-------------|
| `helm template NAME CHART -f values.yaml` | klasterga tegmasdan manifestlarni render qiladi |
| `helm upgrade --install NAME CHART -f values.yaml` | bor bo'lsa yangilaydi, yo'q bo'lsa o'rnatadi (idempotent, CI uchun) |
| `helm get values NAME` / `helm get manifest NAME` | release'ga berilgan values / qo'llangan manifestlar |
| `helm history NAME` | revision'lar tarixi |
| `helm rollback NAME REVISION` | oldingi revision'ga qaytish (yangi revision sifatida) |
| `helm uninstall NAME` | release'ni o'chirish |

Release holati klasterning o'zida, release namespace'idagi Secret'larda saqlanadi (`sh.helm.release.v1.<name>.v<revision>`). Helm'ning klasterda ishlaydigan server qismi yo'q, u `kubectl` kabi kubeconfig bilan ishlaydigan klient.

Qoidalar:

- **Chart versiyasini qotiring** (`--version`). Versiyasiz o'rnatish har safar boshqa narsa beradi.
- **Values faylda, git'da.** `--set` bilan berilgan qiymat faqat terminal tarixida qoladi. Har `upgrade` da o'sha values faylini bering.
- **O'rnatishdan oldin o'qing.** `helm template` chiqishini ko'rib chiqing: chart klaster darajasidagi RBAC, CRD, webhook o'rnatishi mumkin. Begona chart bu begona kodni klaster admin huquqi bilan ishlatish.

**Tuzoq: CRD'lar va Helm.** Helm chart'ning maxsus `crds/` katalogidagi CRD'larni faqat birinchi o'rnatishda qo'yadi, `upgrade` da yangilamaydi va `uninstall` da o'chirmaydi. Shu sabab ko'p chart'lar (cert-manager ham) CRD'larni oddiy shablon sifatida, alohida flag bilan beradi. CRD o'chirilsa undan yaratilgan barcha obyektlar (barcha Certificate'lar) ham o'chadi, shuning uchun ular atayin himoyalangan.

## 3. cert-manager arxitekturasi

O'rnatish (rasmiy yo'riqnoma: https://cert-manager.io/docs/installation/helm/; versiyani shu sahifadan oling):

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version <version> \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

Uch komponent ishga tushadi:

| Komponent | Vazifasi |
|-----------|----------|
| `cert-manager` (controller) | Certificate va boshqa obyektlarni reconcile qiladi, CA'lar bilan gaplashadi |
| `cert-manager-webhook` | obyektlarni validatsiya qiladi (admission webhook) |
| `cert-manager-cainjector` | webhook va CRD'larga CA bundle'ni joylaydi |

CRD'lar va ular orasidagi zanjir:

| Obyekt | Kim yaratadi | Ma'nosi |
|--------|--------------|---------|
| `Issuer`, `ClusterIssuer` | siz | sertifikat qayerdan olinadi (CA konfiguratsiyasi) |
| `Certificate` | siz yoki ingress-shim | "shu nomlar uchun sertifikat shu Secret'da bo'lsin" degan kerakli holat |
| `CertificateRequest` | cert-manager | bitta aniq CSR va uning natijasi |
| `Order` | cert-manager (faqat ACME) | ACME serveridagi buyurtma |
| `Challenge` | cert-manager (faqat ACME) | bitta domen uchun egalik tekshiruvi |

Oqim: Certificate yaratiladi, cert-manager yopiq kalit va CertificateRequest yaratadi, ACME bo'lsa undan Order va Challenge'lar hosil bo'ladi, imzolangan sertifikat qaytgach kalit bilan birga Secret'ga yoziladi. Bu 1-darsdagi reconciliation: Certificate `spec`, Secret va `status` esa joriy holat. Secret'ni o'chirsangiz cert-manager uni qayta chiqaradi.

## 4. Issuer va ClusterIssuer

| | `Issuer` | `ClusterIssuer` |
|---|----------|-----------------|
| Scope | namespaced | cluster-scoped |
| Kim ishlata oladi | faqat o'z namespace'idagi Certificate'lar | istalgan namespace |
| U ishora qiladigan Secret'lar | o'z namespace'ida | cert-manager namespace'ida |
| Qachon | jamoa o'z CA'sini yoki o'z ACME akkauntini boshqarsa | platforma jamoasi butun klasterga bitta manba bersa |

Asosiy issuer turlari: `selfSigned`, `ca`, `acme`, `vault`, va tashqi issuer'lar (masalan, AWS Private CA uchun).

## 5. selfSigned va CA issuer: lokal PKI

`selfSigned` issuer sertifikatni o'zining kaliti bilan imzolaydi. Bunday sertifikatga hech kim ishonmaydi, uning asosiy vazifasi root CA yaratish. Standart naqsh uch qadamdan iborat:

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

Endi `lab-ca` istalgan namespace'dagi Certificate'ni root CA bilan imzolaydi. Klient (curl, brauzer, boshqa servis) bu sertifikatlarga ishonishi uchun root CA sertifikatini (`ca.crt`) ishonchli deb qo'shishi kerak. Ichki servislararo TLS va mTLS uchun aynan shunday xususiy PKI ishlatiladi.

**Tuzoq: root CA kaliti Secret'da.** Kim `cert-manager` namespace'idagi Secret'larni o'qiy olsa, istalgan nom uchun ishonchli sertifikat chiqara oladi. Production'da root kalit klasterdan tashqarida (HSM, Vault, cloud CA) turadi, klasterda faqat oraliq CA.

## 6. ACME: HTTP-01 va DNS-01

ACME bu Let's Encrypt ishlatadigan protokol: klient akkaunt ochadi, domenlar uchun buyurtma (order) beradi, har domen uchun egalikni isbotlaydi (challenge), keyin CSR yuborib sertifikat oladi.

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

| | HTTP-01 | DNS-01 |
|---|---------|--------|
| Isbot | `http://<domen>/.well-known/acme-challenge/<token>` manzilida fayl | `_acme-challenge.<domen>` nomli `TXT` yozuvi |
| cert-manager nima qiladi | vaqtinchalik solver pod, Service va Ingress (yoki HTTPRoute) yaratadi | DNS provayder API'si orqali yozuv qo'shadi |
| Talab | domen klasterning 80-portiga internetdan yetib borishi | DNS provayder API credential'i |
| Wildcard (`*.example.com`) | yo'q | ha |
| Ichki, internetdan yopiq klaster | ishlamaydi | ishlaydi |

**Staging va production.** Let's Encrypt production muhitida qattiq rate limit'lar bor (domen bo'yicha haftalik limitlar, muvaffaqiyatsiz urinishlar limiti). Sozlash va sinov har doim staging serverida bajariladi; uning sertifikatlari brauzerda ishonchli emas, lekin jarayon bir xil. Hammasi ishlagach issuer production manziliga almashtiriladi.

cert-manager challenge'ni ACME serveriga topshirishdan oldin o'zi tekshirib ko'radi (self-check): manzil kutilgan javobni qaytaryaptimi. Self-check o'tmasa Challenge `pending` holatida qoladi va sababi uning `status` ida yoziladi.

## 7. Certificate obyekti

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

- `duration` berilmasa 90 kun so'raladi (ACME'da muddatni CA belgilaydi). Yangilash vaqti standart holatda sertifikat umrining 2/3 qismi o'tganda.
- `status` da: `conditions` (`Ready`, `Issuing`), `notBefore`, `notAfter`, `renewalTime`, `revision`.
- Yangi versiyalarda har qayta chiqarishda yopiq kalit ham yangilanadi (`privateKey.rotationPolicy: Always` standart).
- Secret'da `tls.crt`, `tls.key` va (issuer bersa) `ca.crt` bo'ladi.

Qo'lda tekshirish va yangilash uchun `cmctl` CLI bor (o'rnatish: https://cert-manager.io/docs/reference/cmctl/): `cmctl status certificate NAME`, `cmctl renew NAME`. Hujjat Secret'ni o'chirish orqali yangilashni tavsiya qilmaydi.

**Tuzoq: yangilangan sertifikat va ilova.** cert-manager Secret'ni yangilaydi, lekin uni ishlatayotgan jarayon yangi faylni o'qishi kerak. Ingress controller'lar Secret'ni kuzatib, o'zi qayta yuklaydi. O'z ilovangiz sertifikatni volume'dan bir marta o'qib xotirada ushlasa, muddati o'tguncha eski sertifikat bilan ishlaydi.

## 8. Ingress annotation'lari

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

Certificate nomi `tls.secretName` dan olinadi, `dnsNames` esa `tls.hosts` dan. Ingress o'chirilsa Certificate ham o'chadi (`ownerReferences`).

Gateway API uchun ham xuddi shunday mexanizm bor (Gateway obyektidagi annotation va listener'ning TLS sozlamasi), u cert-manager konfiguratsiyasida alohida yoqiladi. Ingress API muzlatilgani sababli (3-dars) yangi loyihalarda shu yo'l asosiy bo'lib bormoqda.

Bu darsda ingress controller sifatida Traefik ishlatiladi: u faol yuritiladi, Ingress va Gateway API'ni qo'llaydi, k3s'da standart keladi. To'xtatilgan ingress-nginx uchun yozilgan eski cert-manager qo'llanmalaridagi `ingressClassName: nginx` ni ko'r-ko'rona ko'chirmang.

## 9. Yangilanish va kuzatuv

Avtomatik yangilanish ishlaydi, lekin "avtomatik" degani "kuzatilmaydi" degani emas. Yangilanish quyidagi sabablarga ko'ra sinishi mumkin: DNS o'zgargan, firewall 80-portni yopgan, DNS API credential'i eskirgan, rate limit, issuer o'chirilgan. Natija bir xil: 60-kunda boshlangan muvaffaqiyatsiz yangilash 90-kunda uzilishga aylanadi.

Kuzatish:

- `kubectl get certificate -A`: `READY` ustuni `False` bo'lganlar.
- cert-manager Prometheus metrikalari: `certmanager_certificate_expiration_timestamp_seconds` va `certmanager_certificate_ready_status`. Alert: "sertifikat muddati N kundan kam qoldi" va "Certificate uzoq vaqt Ready emas" (observability moduli).
- Tashqi tekshiruv (blackbox): tashqaridan haqiqatda qaysi sertifikat berilayotgani va uning muddati. Bu Secret yangilangan, lekin proxy uni yuklamagan holatni ham ushlaydi.

## 10. Muammoni qidirish

Zanjir bo'ylab yuqoridan pastga yuring, har obyektning `describe` chiqishidagi `Status` va `Events` ni o'qing:

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

## Tuzoqlar

- Sozlashni Let's Encrypt production serverida boshlash: bir necha xato urinishdan keyin rate limit va bir hafta kutish.
- Internetdan ko'rinmaydigan klasterda HTTP-01 kutish.
- Wildcard sertifikatni HTTP-01 bilan olishga urinish.
- `Issuer` ni boshqa namespace'dagi Certificate'dan ishlatishga urinish.
- CA yoki ACME akkaunt Secret'larini himoyasiz qoldirish, root CA kalitini klasterda saqlash.
- Yangilanishni kuzatmaslik: avtomatika jim sinadi, uzilish 30 kundan keyin keladi.
- Chart versiyasini qotirmaslik va values'ni `--set` bilan berib git'da saqlamaslik.
- cert-manager CRD'larini o'ylamay o'chirish: barcha Certificate obyektlari ham o'chadi.
- Staging sertifikatini production'da qoldirish: brauzerlar ishonmaydi.
- Ilova sertifikatni bir marta o'qiydi va yangilanganini bilmaydi.

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
- https://letsencrypt.org/docs/staging-environment/ – Let's Encrypt staging
- https://letsencrypt.org/docs/challenge-types/ – challenge turlari
- https://doc.traefik.io/traefik/ – Traefik hujjatlari

---

## Vazifalar

Barchasini `kubernetes/08-cert-manager/` papkasida bajaring (`make new m=kubernetes n=08 name=cert-manager`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml`, Helm values fayllari `values/` ichida saqlanadi. Yopiq kalitlar, Secret tarkibi va ACME akkaunt kaliti hech qayerga yozilmaydi.

### A. Helm

1. **Install Helm.** Helm'ni o'rnating, `helm version` ni ko'rsating. Klasterga hech narsa o'rnatmasdan o'rganing: `helm show chart` va `helm show values` bilan cert-manager chart'ini (OCI manzili orqali) ko'ring. Chart versiyasi va `appVersion` farqi nima? `helm template` bilan chart'ni render qilib, nechta va qanday turdagi obyekt yaratilishini sanang (`grep '^kind:' | sort | uniq -c`). Ular orasida klaster darajasidagi qaysi huquqlar bor?

2. **Install Traefik.** Traefik repozitoriysini qo'shing va chart'ni `traefik` namespace'iga, versiyasi qotirilgan holda, `values/traefik.yaml` fayli bilan o'rnating (boshida fayl bo'sh bo'lishi mumkin). `helm list -A`, `kubectl get all -n traefik` va `kubectl get ingressclass` natijasini ko'rsating. Service qanday turda va `cloud-provider-kind` unga qanday IP berdi? Shu IP'ga `curl` nima qaytaradi va nima uchun?

3. **Release internals.** `helm get manifest`, `helm get values` (`--all` bilan va usiz) natijalarini solishtiring. `traefik` namespace'ida Helm release ma'lumoti saqlangan Secret'ni toping: nomi va turi qanday? Helm'ning klasterda server qismi yo'qligini qanday tekshirasiz? `helm template` chiqishi bilan `helm get manifest` farq qiladimi?

4. **Upgrade and rollback.** `values/traefik.yaml` da replikalar sonini 2 ga o'zgartiring (to'g'ri kalit nomini `helm show values` dan toping) va `helm upgrade` qiling. `helm history` ni ko'rsating. Keyin atayin buzuq qiymat bering (masalan, mavjud bo'lmagan image tag'i) va upgrade qiling: release holati qanday, pod'lar qanday, eski pod'lar xizmat qilyaptimi? `helm rollback` bilan qaytaring. Rollback'dan keyin revision raqami nechchi va nima uchun? Git'dagi values fayli bilan klaster orasidagi farqqa e'tibor bering (3-darsdagi `rollout undo` tuzog'i bilan solishtiring).

### B. cert-manager

5. **Install cert-manager.** 3-bo'limdagi buyruq bilan, versiyasi qotirilgan holda o'rnating. Uchala Deployment tayyor bo'lishini kuting. `kubectl get crd | grep cert-manager` va `kubectl api-resources --api-group=cert-manager.io` natijasini ko'rsating. `crds.enabled=true` bermasangiz nima bo'lardi? `kubectl get validatingwebhookconfigurations` da nima paydo bo'ldi va webhook pod'i o'chiq bo'lsa Certificate yaratishga nima bo'ladi (sinab ko'ring: webhook Deployment'ini 0 ga scale qilib, keyin qaytaring)?

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

19. **TLS platform.** Hammasini deklarativ yig'ing, `platform/` papkasida: `values/traefik.yaml`, `values/cert-manager.yaml`, issuer manifestlari, va ikki namespace'dagi ikki ilova (har biri o'z host'i bilan, TLS annotation orqali). `install.sh` yozing: `helm upgrade --install` bilan ikkala chart (versiyalari qotirilgan), CRD va webhook tayyor bo'lishini kutish (`kubectl wait`), keyin manifestlar. Skript ikki marta ketma-ket ishlaganda xatosiz o'tishi kerak (idempotent). Isbot: ikkala host uchun `curl --cacert` muvaffaqiyatli; `kubectl get certificate -A` da hammasi `Ready`. README'da yozing: bu yechimni production'ga olib chiqish uchun nima o'zgaradi (issuer, challenge turi, root kalit joyi, monitoring), va Ingress o'rniga Gateway API ishlatilsa qaysi qismlar o'zgaradi. `shellcheck` toza bo'lsin.

20. **Public issuance (optional).** Faqat sizda domen va internetdan ko'rinadigan server bo'lsa. Cloud modulidagi qoidalar bilan (budget alert, eng kichik instans, shu kuni o'chirish) bitta VM'da k3s ko'taring, domenning `A` yozuvini unga qarating, cert-manager o'rnating va Let's Encrypt staging'dan HTTP-01 bilan haqiqiy sertifikat oling. 16-vazifa bilan solishtiring: Order va Challenge qaysi holatlardan o'tdi? Sertifikat zanjirini `openssl s_client` bilan ko'rsating. VM'ni o'chiring va o'chirilganini tekshiring. Bajarmasangiz, README'da "o'tkazib yuborildi" deb yozing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha vazifalar yozilgan (20-vazifa ixtiyoriy), manifestlar, values fayllari va `install.sh` papkada.
2. `make check` toza o'tadi (`yamllint`, `shellcheck`).
3. Papkada yopiq kalit, sertifikat fayli, Secret manifesti yoki akkaunt kaliti yo'q.
4. Release'lar `helm uninstall` qilingan, namespace'lar o'chirilgan, cert-manager CRD'lari bilan nima qilganingiz yozilgan; cloud resurs yaratilgan bo'lsa o'chirilgan.
5. Menga xabar bering, tekshiraman.

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
