# 13-dars: Xavfsizlik: Secret, RBAC, NetworkPolicy

Maqsad: default sozlamalardagi cluster ichkaridan deyarli ochiq: Secret'lar etcd'da shifrlanmagan, har Pod har Pod'ga ulana oladi, konteyner root sifatida ishlaydi, har Pod'da API token yotadi. Bu darsda to'rt qatlam ko'riladi: Secret'larni saqlash va git'da ushlash (10-darsda qoldirilgan muammo: Sealed Secrets, External Secrets Operator, SOPS), kim nima qila oladi (RBAC, ServiceAccount, 9-darsdagi deployer Role'ining nazariyasi), kim kim bilan gaplasha oladi (NetworkPolicy), va Pod node'da nima qila oladi (Pod Security Standards, securityContext). Oxirida image supply chain va audit qisqacha. Yakuniy loyihada bularning hammasi yoqilgan bo'ladi.

Taxminiy vaqt: 4 kun (siz uchun). Diqqat: base64 shifrlash emasligi, RBAC'da huquqni kengaytiradigan yashirin yo'llar, NetworkPolicy'ning qo'shiluvchi (additive) mantig'i va DNS egress, `restricted` profil ilovadan nimani talab qiladi.

## Laboratoriya

- **kind cluster** `sec`: 1 control-plane, 2 worker. NetworkPolicy'ni CNI plugin bajaradi. kind'ning default CNI'si (kindnet) yangi versiyalarda NetworkPolicy'ni qo'llaydi, eskilarida yo'q; birinchi vazifada o'z versiyangizni tekshirasiz. Qo'llamasa cluster'ni `disableDefaultCNI: true` bilan qayta yaratib Calico o'rnating: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind (Cilium ham mos keladi).
- **k3s VM** (Multipass, 2-dars): encryption at rest tajribasi uchun. k3s'ni o'rnatish va server flag'larini o'zgartirish tizim holatini o'zgartiradi, shuning uchun faqat VM'da.
- **Asboblar** (ish mashinasida binary sifatida yoki Docker orqali):
  - `kubeseal`: https://github.com/bitnami-labs/sealed-secrets#kubeseal
  - `sops`: https://getsops.io/docs/ va `age`: https://github.com/FiloSottile/age
  - `trivy`: https://trivy.dev/ (yoki `docker run --rm aquasec/trivy image <image>`)
- `age` private key, SOPS kalitlari, kubeconfig va ochiq Secret manifestlari hech qachon commit qilinmaydi. Ish papkasiga `.gitignore` yozishdan boshlang.
- Tozalash: `kind delete cluster --name sec`, VM'ni `multipass delete --purge`.

---

## 1. Secret: base64 shifrlash emas

```bash
kubectl create secret generic db --from-literal=password=s3cr3t
kubectl get secret db -o jsonpath='{.data.password}' | base64 -d
```

`data` maydoni base64, chunki qiymat binary bo'lishi mumkin. Bu kodlash, himoya emas. Secret'ning ConfigMap'dan farqlari: alohida RBAC resursi, kubelet uni node'da tmpfs'da saqlaydi, `kubectl describe` qiymatni ko'rsatmaydi, at-rest shifrlashni alohida yoqish mumkin. Boshqa hech narsa.

Secret'ga kim yeta oladi:

| Yo'l | Izoh |
|------|------|
| Namespace'da `secrets` ga `get`/`list` huquqi | to'g'ridan-to'g'ri |
| Namespace'da Pod yaratish huquqi | Pod'ga istalgan Secret'ni mount qilib o'qiydi |
| `pods/exec` huquqi | ishlab turgan Pod ichidan env yoki fayl |
| etcd'ga yoki uning backup'iga kirish | shifrlanmagan bo'lsa hammasi ochiq |
| Node'da root | kubelet o'sha node Pod'lari uchun olgan Secret'lar |
| Git tarixi, CI log'i | manifest yoki `echo` orqali |

Env orqali berilgan Secret child process'larga meros o'tadi va crash dump, debug endpoint'larda ko'rinadi. Fayl sifatida mount qilish afzal, yangilanish ham Pod restart'siz yetib keladi (env'da yo'q).

### Encryption at rest

Default'da API server Secret'ni etcd'ga ochiq yozadi. `--encryption-provider-config` fayli (`EncryptionConfiguration`, `apiserver.config.k8s.io/v1`) qaysi resurslar qaysi provider bilan shifrlanishini belgilaydi:

| Provider | Kalit qayerda | Izoh |
|----------|---------------|------|
| `identity` | yo'q | shifrlamaydi (default) |
| `aescbc`, `secretbox`, `aesgcm` | config faylida, control-plane diskida | etcd backup'i o'g'irlanishidan himoya, node buzilishidan emas |
| `kms` (v2) | tashqi KMS (cloud KMS, Vault) | envelope encryption, kalit cluster'dan tashqarida |

Ro'yxatdagi birinchi provider yozish uchun, qolganlari o'qish uchun. Yoqilgandan keyin mavjud Secret'lar o'zi qayta shifrlanmaydi, ularni qayta yozish kerak. Managed cluster'larda (EKS, GKE) bu KMS bilan sozlama darajasida yoqiladi. k3s'da server `--secrets-encryption` flag'i bilan, holat `k3s secrets-encrypt status` bilan ko'riladi.

At-rest shifrlash API orqali o'qishdan himoya qilmaydi: `kubectl get secret` har doim ochiq qiymat qaytaradi. Buni RBAC cheklaydi.

## 2. Secret'ni git'da ushlash

10-darsdagi muammo: GitOps'da hamma narsa git'da, Secret manifesti esa git'ga tushmasligi kerak.

| | Sealed Secrets | SOPS | External Secrets Operator |
|---|----------------|------|---------------------------|
| Git'da nima | shifrlangan `SealedSecret` CR | shifrlangan YAML (qiymatlar) | faqat havola (`ExternalSecret`) |
| Kalit qayerda | cluster'dagi controller'da (private key) | age/PGP kalit yoki cloud KMS | secret manager'da (AWS Secrets Manager, Vault va boshqalar) |
| Kim ochadi | controller cluster ichida | Flux (o'rnatilgan), Argo CD (plugin), yoki CI | operator qiymatni tashqaridan olib Secret yaratadi |
| Rotatsiya | qayta seal va commit | qayta shifrlash va commit | secret manager'da o'zgartiriladi, operator `refreshInterval` bo'yicha oladi |
| Bog'liqlik | cluster kaliti backup'i | kalit boshqaruvi | tashqi xizmat |

- **Sealed Secrets**: `kubeseal` cluster'dagi controller'ning public key'i bilan shifrlaydi, faqat o'sha controller ocha oladi. Default scope `strict`: nom va namespace shifrga bog'langan, boshqa namespace'ga ko'chirib bo'lmaydi. Controller kaliti yo'qolsa (cluster qayta yaratilsa) barcha `SealedSecret` foydasiz, kalitni backup qilish shart.
- **SOPS**: faylning faqat qiymatlarini shifrlaydi, kalit nomlari ochiq qoladi, shuning uchun `git diff` o'qiladi. `--encrypted-regex '^(data|stringData)$'` bilan faqat shu maydonlar.
- **External Secrets Operator**: `SecretStore` (qayerdan, qanday auth) va `ExternalSecret` (qaysi kalit, qaysi Secret'ga), ikkalasi `external-secrets.io/v1`. Git'da hech qanday maxfiy qiymat yo'q, lekin operator secret manager'ga qanday autentifikatsiya qilishi alohida masala (cloud'da workload identity eng toza yo'l).

Uchala holatda ham cluster ichida oxir-oqibat oddiy Secret paydo bo'ladi, 1-bo'limdagi hamma narsa unga tegishli.

## 3. RBAC

API server har so'rovda uch bosqichdan o'tadi: authentication (kim), authorization (ruxsat bormi, RBAC shu yerda), admission (so'rovni o'zgartirish yoki rad etish). RBAC faqat ruxsat **qo'shadi**, "deny" qoidasi yo'q: hech qaysi qoida mos kelmasa so'rov rad etiladi.

| Obyekt | Qamrov | Vazifasi |
|--------|--------|----------|
| `Role` | namespace | qoidalar: `apiGroups`, `resources`, `verbs`, ixtiyoriy `resourceNames` |
| `ClusterRole` | cluster | xuddi shu, plus cluster-scoped resurslar (node, PV, namespace) va `nonResourceURLs` |
| `RoleBinding` | namespace | subject'larni Role **yoki ClusterRole** ga shu namespace ichida bog'laydi |
| `ClusterRoleBinding` | cluster | subject'larni ClusterRole'ga hamma namespace'da bog'laydi |

- Subject'lar: `User`, `Group`, `ServiceAccount`. User va Group Kubernetes obyekti emas, ular authentication qatlamidan keladi (sertifikatdagi CN/O, OIDC claim'lari). ServiceAccount obyekt.
- RoleBinding + ClusterRole foydali kombinatsiya: qoidalar bir marta yoziladi (masalan o'rnatilgan `view`, `edit`, `admin`), har namespace'da alohida bog'lanadi.
- Verb'lar: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`. Subresource'lar alohida: `pods/log`, `pods/exec`, `deployments/scale`.

```bash
kubectl auth can-i create deployments -n app --as=system:serviceaccount:app:deployer
kubectl auth can-i --list -n app --as=system:serviceaccount:app:deployer
kubectl auth whoami
```

### Huquqni kengaytiradigan yo'llar

| Huquq | Nima uchun xavfli |
|-------|-------------------|
| `secrets` ga `get`/`list` | boshqa ServiceAccount token'lari, parollar. `list` ham qiymatlarni qaytaradi |
| Pod (yoki Deployment, Job) yaratish | istalgan ServiceAccount nomidan ishlaydigan, istalgan Secret mount qilingan Pod |
| `pods/exec` | ishlab turgan Pod'ning identifikatsiyasi va ma'lumotiga kirish |
| `rolebindings` yaratish, `bind`, `escalate` | o'ziga yangi huquq berish |
| `impersonate` | boshqa user/guruh nomidan harakat |
| `*` verb yoki resource | kelajakda qo'shiladigan resurslar ham kiradi |
| `nodes/proxy`, PV yaratish | kubelet API, host fayl tizimi |

### ServiceAccount va token

- Har namespace'da `default` ServiceAccount bor, Pod spec'da boshqasi ko'rsatilmasa u ishlatiladi. Huquqi yo'q, lekin token baribir mount qilinadi.
- Token Pod'ga **projected volume** orqali beriladi: `/var/run/secrets/kubernetes.io/serviceaccount/token`. U Pod'ga bog'langan (Pod o'chsa yaroqsiz), muddati cheklangan va kubelet uni avtomatik yangilab turadi, audience'ga ega.
- API'ga murojaat qilmaydigan ilova uchun `automountServiceAccountToken: false` (Pod yoki ServiceAccount darajasida). Ilova buzilsa hujumchi qo'lida token bo'lmaydi.
- Har ilovaga o'z ServiceAccount'i. Bir necha ilova `default` ni bo'lishsa, biriga berilgan huquq hammasiga beriladi.
- Cloud'da shu token OIDC orqali cloud IAM role'ga almashtiriladi (workload identity), Pod'ga cloud access key berish kerak emas.

## 4. NetworkPolicy

Default'da cluster tarmog'i tekis: istalgan Pod istalgan namespace'dagi istalgan Pod'ga ulana oladi. NetworkPolicy L3/L4 darajasidagi firewall: Pod'larni label bilan tanlaydi.

- NetworkPolicy obyektini API server har doim qabul qiladi, lekin uni **CNI plugin** bajaradi. Qo'llamaydigan CNI'da policy jim e'tiborsiz qoladi. Calico, Cilium qo'llaydi; k3s'da o'rnatilgan network policy controller bor.
- Pod'ni hech qaysi policy tanlamasa, u ochiq. Kamida bitta policy tanlasa, shu yo'nalishda (`Ingress` yoki `Egress`) faqat ruxsat berilgan trafik o'tadi.
- Policy'lar **qo'shiladi**: deny qoidasi yo'q, bir nechta policy ruxsatlarining birlashmasi amal qiladi. Tartib yo'q.
- Javob trafigi avtomatik ruxsat etiladi (stateful).

Default deny (namespace'dagi hamma Pod, ikkala yo'nalish):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: app }
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

Ruxsat: `api` Pod'lariga faqat `web` Pod'laridan 8080 portga:

```yaml
spec:
  podSelector:
    matchLabels: { app: api }
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels: { app: web }
      ports:
        - { protocol: TCP, port: 8080 }
```

`from`/`to` manbalari: `podSelector` (shu namespace), `namespaceSelector` (har namespace'da avtomatik `kubernetes.io/metadata.name` label'i bor), `ipBlock` (CIDR, cluster'dan tashqari manzillar uchun).

**Tuzoq: AND va OR.** Bitta ro'yxat elementi ichida `namespaceSelector` va `podSelector` birga bo'lsa AND ("shu namespace'dagi shu Pod'lar"). Ikki alohida element (`-` bilan) bo'lsa OR ("shu namespace'dagi hamma" yoki "o'z namespace'imdagi shu Pod'lar"). Bitta chiziqcha farqi policy'ni butunlay ochib yuboradi.

**Tuzoq: egress deny va DNS.** Egress'ni yopsangiz DNS ham yopiladi, ilova hech qaysi Service nomini resolve qila olmaydi va xato "timeout" ko'rinishida chiqadi. `kube-system` dagi CoreDNS'ga UDP va TCP 53 ga ruxsat default deny bilan birga yoziladi.

Chegaralar: standart NetworkPolicy L7 (HTTP path, method) ni, DNS nomi bo'yicha egress'ni va cluster miqyosidagi qoidalarni bilmaydi. Bular CNI'ning o'z CRD'larida (Cilium, Calico) yoki service mesh'da. Ingress controller va monitoring (Prometheus scrape) uchun ruxsatlarni unutmang: ular boshqa namespace'dan keladi.

## 5. Pod Security

Konteyner izolyatsiyasi namespace va cgroup'larga tayanadi (docker moduli), kernel umumiy. Pod spec'dagi ba'zi maydonlar bu izolyatsiyani buzadi: `privileged: true`, `hostNetwork`, `hostPID`, `hostPath` volume. Bularni yarata oladigan foydalanuvchi amalda node'da root.

### securityContext

```yaml
securityContext:              # container level
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: ["ALL"] }
  seccompProfile: { type: RuntimeDefault }
```

| Maydon | Nimadan himoya qiladi |
|--------|------------------------|
| `runAsNonRoot`, `runAsUser` | konteynerdan chiqish zaifligida host'da root bo'lish; image `USER` root bo'lsa Pod ishga tushmaydi |
| `allowPrivilegeEscalation: false` | setuid binary orqali root olish (`no_new_privs`) |
| `readOnlyRootFilesystem` | hujumchi binary yoza olmaydi; yozish kerak joylarga `emptyDir` mount qilinadi (`/tmp`, cache) |
| `capabilities.drop: ALL` | root'ning bo'laklangan huquqlari (`NET_RAW`, `SYS_ADMIN`...); 1024 dan past port kerak bo'lsa faqat `NET_BIND_SERVICE` qo'shiladi |
| `seccompProfile: RuntimeDefault` | xavfli syscall'larni bloklaydi |

Pod darajasidagi `securityContext` da `fsGroup` volume'dagi fayllar guruhini belgilaydi (non-root jarayon PVC'ga yoza olishi uchun).

### Pod Security Standards va admission

Uch profil: `privileged` (cheklovsiz), `baseline` (ma'lum xavfli sozlamalar taqiqlangan: privileged, host namespace'lar, hostPath), `restricted` (baseline plus yuqoridagi securityContext to'plami majburiy). O'rnatilgan Pod Security Admission namespace label'i bilan yoqiladi:

```bash
kubectl label ns app \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

Rejimlar: `enforce` (Pod rad etiladi), `audit` (audit log'ga yoziladi), `warn` (kubectl'da ogohlantirish). Joriy qilish tartibi: avval `warn` va `audit`, buzilishlarni tuzatish, keyin `enforce`. Admission **Pod** darajasida ishlaydi: Deployment qabul qilinadi, lekin uning Pod'lari yaratilmaydi, xato ReplicaSet event'larida ko'rinadi.

Nozikroq qoidalar (masalan "faqat shu registry'dan image", "har Pod'da resource limits") uchun o'rnatilgan `ValidatingAdmissionPolicy` (CEL ifodalari) yoki Kyverno, OPA Gatekeeper kabi policy engine'lar.

## 6. Image va supply chain

- **Skanerlash**: `trivy image <image>` ma'lum CVE'larni, `trivy config <dir>` manifest va Dockerfile'dagi xato sozlamalarni topadi. CI'da `--severity HIGH,CRITICAL --exit-code 1` bilan gate. Skaner faqat ma'lum zaifliklarni biladi, va tuzatish mavjud bo'lmagan CVE'lar uchun siyosat kerak (kutish, istisno, base image almashtirish).
- **Kichik base image**: distroless yoki minimal image'da shell va paket menejeri yo'q, CVE soni ham, hujumchining asboblari ham kam (docker moduli).
- **Digest bilan pin** (9-dars) va **imzo**: cosign (Sigstore) image'ni imzolaydi, admission policy imzosiz image'ni rad etadi. **SBOM** image ichida nima borligining ro'yxati, yangi CVE chiqqanda "bizda bormi" savoliga javob.
- CI action'larini ham SHA bilan pin qiling: build pipeline'ning o'zi supply chain'ning bir qismi.

## 7. Audit

API server har so'rovni audit log'ga yozishi mumkin: kim, qachon, qaysi resursga, qaysi verb, natija. Audit policy (`audit.k8s.io/v1`, `--audit-policy-file`) har qoida uchun daraja belgilaydi: `None`, `Metadata` (so'rov meta-ma'lumoti), `Request` (so'rov tanasi bilan), `RequestResponse`. Secret'lar uchun `Metadata` dan yuqori qo'yilmaydi, aks holda qiymatlar log'ga tushadi. Managed cluster'larda audit log cloud log xizmatiga yoqiladi. Incident tekshiruvida "bu Secret'ni kim o'qidi", "bu RoleBinding'ni kim yaratdi" savollariga yagona manba shu, shuning uchun log cluster'dan tashqarida saqlanadi (observability moduli).

## Tuzoqlar

- Secret manifestini (base64 bilan) git'ga commit qilish. Tarixdan o'chirish emas, secret'ni almashtirish kerak.
- Qulaylik uchun `cluster-admin` ClusterRoleBinding (CI, dashboard, "vaqtincha").
- Hamma ilova `default` ServiceAccount'da, token hamma Pod'ga mount qilingan.
- `secrets` ga `list` berib, "faqat ro'yxat" deb o'ylash: `list` qiymatlarni ham qaytaradi.
- NetworkPolicy yozib, CNI uni bajarishini tekshirmaslik. Policy bor, himoya yo'q.
- Default deny'siz faqat "allow" policy'lar: tanlanmagan Pod'lar ochiq qoladi.
- Egress deny'da DNS'ni unutish; ingress deny'da ingress controller va Prometheus'ni unutish.
- `from` ro'yxatida bitta ortiqcha `-`: AND o'rniga OR.
- `enforce=restricted` ni birdaniga yoqish: mavjud Pod'lar ishlayveradi, lekin keyingi restart yoki scale'da yaratilmaydi, muammo kechasi node almashganda chiqadi.
- `readOnlyRootFilesystem` ni sinovsiz yoqish: ilova `/tmp` ga yoza olmay runtime'da yiqiladi.
- Sealed Secrets controller kalitini backup qilmaslik.
- Encryption at rest'ni yoqib, mavjud Secret'larni qayta yozmaslik: ular etcd'da ochiq qoladi.

## Manbalar

- https://kubernetes.io/docs/concepts/configuration/secret/ – Secret
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/ – Secret bo'yicha amaliyotlar
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/ – encryption at rest
- https://docs.k3s.io/security/secrets-encryption – k3s secrets encryption
- https://github.com/bitnami-labs/sealed-secrets – Sealed Secrets
- https://external-secrets.io/latest/ – External Secrets Operator
- https://getsops.io/docs/ – SOPS
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/ – RBAC
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/ – RBAC amaliyotlari, huquqni kengaytirish yo'llari
- https://kubernetes.io/docs/concepts/security/service-accounts/ – ServiceAccount
- https://kubernetes.io/docs/concepts/services-networking/network-policies/ – NetworkPolicy
- https://kubernetes.io/docs/concepts/security/pod-security-standards/ – Pod Security Standards
- https://kubernetes.io/docs/concepts/security/pod-security-admission/ – Pod Security Admission
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ – securityContext
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ – audit
- https://trivy.dev/ – Trivy

---

## Vazifalar

Barchasini `kubernetes/13-security/` da bajaring (`make new m=kubernetes n=13 name=security`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar shu papkada. Ochiq Secret manifestlari, private key'lar va token'lar papkaga tushsa ham commit qilinmaydi; README'da secret qiymatlari ko'rsatilmaydi.

### A. Secret

1. **base64 is not encryption.** Secret yarating va uch yo'l bilan ochiq qiymatini oling: `kubectl get -o jsonpath` + `base64 -d`, Pod ichidagi mount qilingan fayl, Pod ichidagi env. Keyin Secret qiymatini o'zgartiring: fayl va env qachon yangilandi? Qaysi usul nima uchun afzal?

2. **Secret in etcd.** kind cluster'da etcd Pod'i ichidagi `etcdctl` bilan (`/etc/kubernetes/pki/etcd/` dagi sertifikatlar) `/registry/secrets/<ns>/<name>` kalitini o'qing. Parol ochiq ko'rinadimi? Bu etcd backup'i va control-plane diski uchun nimani anglatadi?

3. **Encryption at rest on k3s.** Multipass VM'da k3s'ni secrets encryption bilan o'rnating, `k3s secrets-encrypt status` chiqishini yozing. Secret yarating va uning qiymatini k3s datastore fayllaridan (`/var/lib/rancher/k3s/server/db/`) `strings` va `grep` bilan qidiring. Shifrlash'siz o'rnatilgan variant bilan solishtiring. `kubectl get secret` natijasi o'zgardimi va nima uchun?

4. **Sealed Secrets.** Controller'ni Helm bilan o'rnating, `kubeseal` bilan Secret'ni seal qiling va faqat `SealedSecret` ni apply qiling. Oddiy Secret paydo bo'ldimi? `SealedSecret` ni boshqa namespace'ga yoki boshqa nom bilan apply qilib ko'ring va controller log'idagi xatoni yozing. Controller kalitini qanday backup qilasiz?

5. **SOPS with age.** `age` kalit juftligini yarating, Secret manifestining faqat `data`/`stringData` qiymatlarini SOPS bilan shifrlang. Shifrlangan faylda nima ochiq, nima yopiq? Bitta qiymatni o'zgartirib `git diff` qanday ko'rinishini yozing. Private key qayerda saqlanadi va GitOps controller unga qanday yetadi?

6. **External Secrets Operator.** ESO'ni o'rnating va `SecretStore` + `ExternalSecret` bilan Secret yarating. Manba sifatida ESO'ning sinov uchun `fake` provider'ini yoki (cloud modulidagi akkauntingiz bo'lsa) AWS Secrets Manager'ni ishlating. Manbadagi qiymatni o'zgartiring: cluster'dagi Secret qachon yangilandi? Uch yondashuvdan (4, 5, 6) yakuniy loyiha uchun qaysi birini tanlaysiz va nima uchun?

### B. RBAC

7. **Read-only user.** `dev` namespace'ida `viewer` ServiceAccount yarating va o'rnatilgan `view` ClusterRole'ni RoleBinding bilan bog'lang. `kubectl auth can-i` bilan tekshiring: `dev` da Pod'larni ko'rish, Secret'larni o'qish, Pod o'chirish, boshqa namespace'da Pod'larni ko'rish. `view` nima uchun Secret'larni o'z ichiga olmaydi?

8. **Role from scratch.** "Faqat `web` nomli Deployment'ni restart va scale qila oladi, log o'qiy oladi, boshqa hech narsa" degan Role yozing. `resourceNames` va subresource'lar kerak bo'ladi. Token olib (`kubectl create token`), shu identifikatsiya bilan ruxsat etilgan va etilmagan to'rt amalni sinang.

9. **Privilege escalation paths.** Uchta ServiceAccount yarating, har biriga bittadan huquq: (a) `dev` da Pod yaratish, (b) `pods/exec`, (c) `rolebindings` yaratish. Har biri bilan `dev` dagi Secret'ni o'qishga erishib bo'ladimi? Sinab ko'ring, ishlagan yo'lni qadamma-qadam yozing. (c) da API server nima uchun rad etadi yoki etmaydi?

10. **ServiceAccount token.** Pod ichidan token faylini o'qing va JWT payload'ini dekod qiling: `sub`, `aud`, `exp`, Pod nomi. Shu token bilan Pod ichidan `curl` orqali API server'ga murojaat qiling (o'z namespace'idagi Pod'lar ro'yxati): javob nima? Keyin `automountServiceAccountToken: false` qo'yib fayl bor-yo'qligini tekshiring.

11. **RBAC audit.** Cluster'dagi barcha ClusterRoleBinding'larni chiqaring va `cluster-admin` ga bog'langan subject'larni toping. Sealed Secrets, ESO yoki Argo CD controller'i qanday huquqqa ega (`kubectl auth can-i --list --as=...`)? Bu controller buzilsa nima yo'qotiladi?

### C. NetworkPolicy

12. **Does my CNI enforce.** Ikki Pod yarating, biridan ikkinchisiga `curl`/`wget` ishlashini ko'rsating. Default deny ingress policy qo'ying va takrorlang. Bloklandimi? Bloklanmagan bo'lsa cluster'ni Calico yoki Cilium bilan qayta yarating va farqni yozing. Qaysi CNI ishlayotganini qanday aniqladingiz?

13. **Three-tier policy.** `app` namespace'ida `web`, `api`, `db` Pod'lari va Service'lari (istalgan image). Default deny (ingress va egress), keyin ruxsatlar: `web` -> `api` 8080, `api` -> `db` 5432, hammaga DNS. Ruxsat etilgan va etilmagan har yo'lni sinab matritsa (kimdan, kimga, natija) tuzing.

14. **DNS egress trap.** 13-vazifada DNS ruxsatini olib tashlang. `web` dan `api` ga nom bilan va IP bilan ulaning. Xato qanday ko'rinadi va uni tarmoq muammosidan qanday ajratasiz? DNS policy'sini `kube-system` namespace'iga va CoreDNS Pod'lariga aniq cheklab qayta yozing.

15. **AND vs OR.** `monitoring` namespace'idagi faqat `app=prometheus` Pod'lariga `api` ning metrics portiga ruxsat bering. Avval to'g'ri (AND) variantni, keyin bitta `-` qo'shib OR variantini yozing. Ikkinchisida kimlar kira oladi? Uchinchi namespace'dagi Pod bilan isbotlang.

16. **Cross-namespace isolation.** `team-a` va `team-b` namespace'lari: har biri ichida erkin trafik, orasida hech narsa, faqat ingress controller (yoki uni taqlid qiluvchi alohida namespace) ikkalasiga kira oladi. Policy'larni yozing va sinang. Yangi namespace yaratilganda u default'da qanday holatda bo'ladi va bu muammoni qanday hal qilasiz?

### D. Pod Security

17. **Root by default.** Oddiy `nginx` Pod'ida `id`, `cat /proc/1/status | grep Cap`, `/` ga fayl yozish natijalarini yozing. Keyin `hostPath: /` mount qilingan privileged Pod yarating (faqat kind'da) va node fayl tizimini ko'ring. Bu Pod yaratish huquqi haqida nimani anglatadi?

18. **Harden a pod.** Ilovangiz (yoki `nginx`) Pod'iga 5-bo'limdagi to'liq securityContext'ni qo'ying. Nima buzildi? Har xatoni birma-bir tuzating (non-root image yoki `runAsUser`, yozish kerak joylarga `emptyDir`, port). Yakuniy manifest va har o'zgarish sababini yozing.

19. **Pod Security Admission.** Namespace'ga `warn=restricted` qo'yib 17-vazifadagi oddiy Deployment'ni apply qiling va ogohlantirishni yozing. `enforce=restricted` ga o'tkazing: Deployment yaratildimi, Pod'lar-chi? Xato qayerda ko'rinadi? 18-vazifadagi manifest o'tadimi? Mavjud namespace'ni tekshirish uchun `kubectl label --dry-run=server` ni sinang.

### E. Supply chain va yig'ma

20. **Scan an image.** O'z image'ingizni va uning base image'ini `trivy image` bilan skanerlang, HIGH va CRITICAL sonini yozing. Base image'ni kichikrog'iga almashtirib qayta skanerlang. `trivy config` ni manifest papkangizda ishga tushiring va topilganlardan uchtasini izohlang. Buni 9-darsdagi pipeline'ga qaysi qadam sifatida qo'shasiz?

21. **Audit policy design.** Kodsiz: yakuniy loyiha cluster'i uchun audit policy'ni loyihalang. Qaysi resurs va verb'lar qaysi darajada yoziladi, nima `None`, Secret'lar uchun nima uchun `Metadata`? "Kim `prod` dagi Secret'ni o'qidi" savoliga javob berish uchun qaysi maydonlar kerak?

22. **Secure namespace baseline.** Yangi namespace uchun "qutidan chiqqan" xavfsiz to'plamni Kustomize base sifatida yig'ing: PSA label'lari, default deny NetworkPolicy va DNS ruxsati, ilova uchun alohida ServiceAccount (`automountServiceAccountToken: false`), minimal Role. Ilovangizni shu namespace'ga deploy qilib ishlashini va 13-vazifadagi kabi taqiqlangan yo'llar yopiqligini ko'rsating.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. Repo'da ochiq Secret, `age` private key, token va kubeconfig yo'q (`git status` va `git log -p` bilan tekshiring).
3. `kind delete cluster --name sec` bajarilgan, k3s VM o'chirilgan; AWS Secrets Manager ishlatgan bo'lsangiz secret o'chirilgan.
4. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Secret ConfigMap'dan nimasi bilan farq qiladi va nimasi bilan farq qilmaydi?
- Encryption at rest nimadan himoya qiladi, nimadan yo'q?
- Sealed Secrets, SOPS va External Secrets Operator: har birida git'da nima yotadi va kalit qayerda?
- RoleBinding ClusterRole'ga bog'lansa huquq qayerda amal qiladi?
- Pod yaratish huquqi nima uchun Secret o'qish huquqiga teng kuchli?
- Pod'ni hech qaysi NetworkPolicy tanlamasa u qanday holatda? Bitta ingress policy tanlasa-chi?
- Egress default deny'dan keyin ilova nima uchun "hamma narsa timeout" beradi?
- `enforce=restricted` namespace'da Deployment qabul qilinib, Pod'lar paydo bo'lmasa xatoni qayerdan qidirasiz?
- `readOnlyRootFilesystem` va `capabilities.drop: ALL` har biri hujumchining qaysi qadamini qiyinlashtiradi?
