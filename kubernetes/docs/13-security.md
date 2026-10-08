# 13-dars: Xavfsizlik: Secret, RBAC, NetworkPolicy

Maqsad: default sozlamalardagi klaster ichkaridan deyarli ochiq ekanini o'z ko'zingiz bilan ko'rish va uni qatlamma-qatlam yopish. Default holatda Secret'lar etcd'da shifrlanmagan, har pod har pod'ga ulana oladi, konteyner root sifatida ishlaydi, har pod'da API token yotadi. Bu darsda to'rt qatlam ko'riladi: Secret'larni saqlash va git'da ushlash (10-darsda ochiq qoldirilgan muammo: Sealed Secrets, SOPS, External Secrets Operator), kim nima qila oladi (RBAC va ServiceAccount, 9-darsdagi `deployer` Role'ining nazariyasi), kim kim bilan gaplasha oladi (NetworkPolicy) va pod node'da nima qila oladi (Pod Security Standards, `securityContext`). Oxirida image supply chain va audit. 15-darsdagi yakuniy loyihada bularning hammasi yoqilgan bo'ladi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun Laboratoriya, 1–2 bo'limlar va A guruh (Sealed Secrets, SOPS va ESO o'rnatish vaqt oladi). Ikkinchi kun 3-bo'lim va B guruh. Uchinchi kun 4-bo'lim, "Birga bajaramiz" va C guruh. To'rtinchi kun 5–7 bo'limlar, D va E guruhlar. Diqqatni quyidagilarga qarating: base64 nima uchun shifrlash emas, RBAC'da huquqni kengaytiradigan yashirin yo'llar (ayniqsa "pod yaratish"), NetworkPolicy'ning qo'shiluvchi (additive) mantig'i va DNS egress tuzog'i, `restricted` profil ilovadan aynan nimani talab qiladi.

Qanday o'qish kerak: xavfsizlik darsida "ishladi" yetarli emas, "ishlamasligi kerak bo'lgan narsa ishlamadi" ham isbotlanadi. Shuning uchun har bo'limda ikki tomonlama tekshiruv bor: ruxsat etilgan amal o'tadi, taqiqlangani rad etiladi. Nazariyadagi misollar `demo` namespace'ida, vazifalardan boshqa obyektlar bilan (`mailer` Secret'i, `reporter` ServiceAccount'i, `client`/`server` pod'lari). Ularni terib ko'ring, chiqishni izoh bilan solishtiring. Pod nomlari, IP, UID, vaqt va token qiymatlari sizda boshqa bo'ladi, bunday joylar `<...>` bilan belgilangan. Har bo'lim oxiridagi "Nima uchun shunday" dizayn sababini aytadi.

## Laboratoriya

Asosiy muhit host'dagi Docker ustidagi kind klasteri `sec` (1 control-plane + 2 worker). Bitta tajriba (encryption at rest, 3-vazifa) Multipass VM'dagi k3s'da: k3s o'rnatish va server flag'larini o'zgartirish tizim holatini o'zgartiradi (systemd unit, `/etc`, `/var/lib`), shuning uchun faqat VM ichida (CLAUDE.md, "Laboratoriya xavfsizligi").

Klaster 2-darsdagi `kind-multi.yaml` bilan yaratiladi:

```bash
kind create cluster --name sec --config kubernetes/02-cluster-setup/kind-multi.yaml
kubectl config current-context        # must print: kind-sec
kubectl create namespace demo
```

NetworkPolicy obyektini API server har doim qabul qiladi, lekin uni CNI plugin (pod tarmog'ini quradigan plugin, 2-dars) bajaradi. kind'ning default CNI'si kindnet; uning yangi versiyalari NetworkPolicy'ni qo'llaydi, eskilari qo'llamaydi. Qaysi holatda ekaningizni 12-vazifada tajriba bilan aniqlaysiz. Qo'llamasa klaster kind config'ining `networking` blokida `disableDefaultCNI: true` va Calico'ning default pod CIDR'i `podSubnet: 192.168.0.0/16` bilan qayta yaratilib, Calico o'rnatiladi: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind (CNI o'rnatilguncha node'lar `NotReady`, 2-dars). Cilium ham mos keladi.

k3s VM (faqat 3-vazifa uchun, ish tugashi bilan o'chiriladi):

```bash
multipass launch 24.04 --name k3s-sec --cpus 2 --memory 2G --disk 10G
```

Asboblar (`kubectl`, `kind`, `helm` oldingi darslardan bor):

| Asbob | Zorin (ofis), `amd64` | macOS (uy), `arm64` |
|-------|-----------------------|----------------------|
| `kubeseal` | releases sahifasidan `kubeseal-<version>-linux-amd64.tar.gz`, binary `~/.local/bin` ga: https://github.com/bitnami-labs/sealed-secrets/releases | `brew install kubeseal` |
| `sops` | releases sahifasidan `sops-v<version>.linux.amd64` binary'si: https://github.com/getsops/sops/releases | `brew install sops` |
| `age` | `sudo apt install age` | `brew install age` |
| `trivy` | releases sahifasidan `trivy_<version>_Linux-64bit.tar.gz`: https://github.com/aquasecurity/trivy/releases | `brew install trivy` |

Ikki mashina farqlari:

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| kind node'lari | host'dagi oddiy konteynerlar (`sec-control-plane`, `sec-worker`, `sec-worker2`) | Docker Desktop'ning yashirin Linux VM'i ichidagi konteynerlar |
| `hostPath: /` (17-vazifa) nimani ko'rsatadi | node konteynerining fayl tizimi, Zorin host'ining `/` emas | node konteynerining fayl tizimi, Mac'niki ham, Docker VM'iniki ham emas |
| etcd ma'lumoti | `sec-control-plane` konteyneri ichida `/var/lib/etcd` | o'sha joyda, lekin VM ichidagi konteynerda |
| k3s VM | Multipass, `amd64` Ubuntu | Multipass, `arm64` Ubuntu; buyruqlar bir xil |
| SOPS age kaliti default joyi | `~/.config/sops/age/keys.txt` | `~/Library/Application Support/sops/age/keys.txt` |

Oxirgi qator amaliy: SOPS kalitni operatsion tizimning "config papkasi"dan qidiradi, u Linux va macOS'da har xil. Ikkala mashinada bir xil yo'l bo'lsin desangiz `SOPS_AGE_KEY_FILE` muhit o'zgaruvchisini o'zingiz belgilang.

**Ikkinchi mashinada tiklash.** Klaster va VM ko'chmaydi, git orqali manifestlar, README va shifrlangan fayllar keladi. Uyda: `kind create cluster` (yuqoridagidek), keyin vazifa guruhingizga qarab `helm install` (Sealed Secrets, ESO) va `kubectl apply -f`. Uch narsa ko'chmaydi va har biri alohida hal qilinadi:

- Sealed Secrets controller kaliti har klasterda yangi yaratiladi, shuning uchun ofisda seal qilingan `SealedSecret` uyda ochilmaydi. Uyda qayta seal qilasiz yoki kalitni xavfsiz kanal orqali ko'chirasiz (git emas). Bu 4-vazifadagi backup savolining amaliy tomoni.
- `age` private key: git'ga hech qachon tushmaydi. Ikkinchi mashinada alohida kalit yaratib uning public key'ini `.sops.yaml` ga qo'shish mumkin: SOPS bitta faylni bir nechta recipient uchun shifrlay oladi.
- k3s VM: 3-vazifani bitta mashinada boshidan oxirigacha bajaring.

**Xavfsizlik va tartib:**

- Ish papkasiga birinchi bo'lib `.gitignore` yozing: private key, ochiq Secret manifesti, token va kubeconfig fayllari uchun naqshlar. `make secrets` `.key`, `.pem`, `kubeconfig` kabi nomlarni ushlaydi, lekin `secret.yaml` ichidagi parolni ushlamaydi.
- Ochiq qiymatli Secret manifestlari repo'dan tashqarida (masalan `~/lab-secrets/`) yoki faqat pipe ichida yaratiladi.
- Token'larni jwt.io kabi saytlarga joylamang: token u yerda ham token. Dekod lokal qilinadi (3-bo'lim).
- Tozalash: `kind delete cluster --name sec`, `multipass delete --purge k3s-sec`. AWS Secrets Manager ishlatgan bo'lsangiz, secret'ni o'chirib, o'chirilganini tekshiring.

---

## 1. Secret: base64 shifrlash emas

### Bu nima

Secret (4-dars, 10-bo'lim) bu ConfigMap'ga o'xshash obyekt, faqat maxfiy qiymatlar uchun. Uning `data` maydonidagi qiymatlar base64'da. Base64 bu kodlash (encoding): istalgan baytlarni 64 ta "xavfsiz" belgi bilan yozish usuli, kalitsiz, bir buyruq bilan qaytariladi. Frontend'dan tanish: `btoa("hello")` va `atob(...)`. Base64 Secret'da binary qiymatlarni (sertifikat, kalit fayli) YAML va JSON'ga sig'dirish uchun turibdi, himoya uchun emas.

### Mexanizm

Secret ConfigMap'dan quyidagilar bilan farq qiladi, boshqa hech narsa bilan:

- RBAC'da alohida resurs (`secrets`), ConfigMap'ga ruxsat Secret'ga ruxsat bermaydi.
- Node'da volume sifatida `tmpfs` (RAM'dagi fayl tizimi) da turadi, diskka yozilmaydi.
- kubelet node'ga faqat o'sha node'dagi pod'larga kerakli Secret'larni oladi.
- `kubectl describe` qiymatni emas, faqat hajmini ko'rsatadi.
- etcd'da at-rest shifrlashni faqat Secret'lar uchun yoqish mumkin (pastda).

Secret'ga kim yeta oladi:

| Yo'l | Izoh |
|------|------|
| Namespace'da `secrets` ga `get`/`list` huquqi | to'g'ridan-to'g'ri |
| Namespace'da pod yaratish huquqi | pod'ga istalgan Secret'ni mount qilib o'qiydi (3-bo'lim) |
| `pods/exec` huquqi | ishlab turgan pod ichidan env yoki fayl |
| etcd'ga yoki uning backup'iga kirish | shifrlanmagan bo'lsa hammasi ochiq |
| Node'da root | kubelet o'sha node pod'lari uchun olgan Secret'lar |
| Git tarixi, CI log'i | manifest yoki `echo` orqali |

### Ishlaydigan misol

Qiymat shell tarixiga tushmasligi uchun fayldan yaratamiz (`--from-literal` buyruq satrida qoladi, 5-dars):

```
$ printf 'demo-only' > ~/lab-secrets/mailer-key.txt
$ kubectl -n demo create secret generic mailer --from-file=api-key=$HOME/lab-secrets/mailer-key.txt
secret/mailer created
$ kubectl -n demo get secret mailer -o yaml
apiVersion: v1
data:
  api-key: ZGVtby1vbmx5
kind: Secret
metadata:
  name: mailer
  namespace: demo
  ...
type: Opaque
```

- `data.api-key` fayl mazmuni base64'da. Kalit nomi `--from-file=<kalit>=<fayl>` dan olingan.
- `type: Opaque` "ichida nima borligini Kubernetes bilmaydi" degani. Boshqa turlar (`kubernetes.io/tls`, `kubernetes.io/dockerconfigjson`) majburiy kalitlarni tekshiradi.

```
$ echo ZGVtby1vbmx5 | base64 -d
demo-only
```

Kalit kerak bo'lmadi. Shuning uchun "Secret'ni o'qiy olish" va "parolni bilish" bir narsa.

Env va fayl farqi (4-darsda ko'rgansiz, bu yerda xavfsizlik tomoni): env orqali berilgan qiymat jarayonning butun umri davomida o'zgarmaydi, child process'larga meros o'tadi (Node'da `child_process.spawn` default holatda `process.env` ni beradi) va crash dump, debug endpoint, "print all env" log'larida ko'rinib qoladi. Volume orqali fayl sifatida berilgan qiymat faqat o'qilganda ko'rinadi va Secret o'zgarsa kubelet faylni bir necha o'n soniya ichida yangilaydi (symlink almashinuvi, 4-dars). `subPath` bilan mount qilingan fayl bundan mustasno, u yangilanmaydi.

### Encryption at rest

API server obyektlarni etcd'ga yozadi (1-dars). Default holatda Secret etcd'ga shifrlanmasdan yoziladi: etcd kaliti `/registry/secrets/<namespace>/<nom>`, qiymati protobuf ko'rinishidagi obyekt, uning ichida parol ochiq matn. etcd'ni to'g'ridan-to'g'ri o'qish uchun `etcdctl` kerak, u kind'dagi etcd pod'ining image'ida bor va ulanish uchun `--endpoints`, `--cacert`, `--cert`, `--key` flag'larini talab qiladi (sertifikatlar control-plane node'ida `/etc/kubernetes/pki/etcd/`).

Encryption at rest bu API server'ning "etcd'ga yozishdan oldin shifrla, o'qigandan keyin och" rejimi. U `--encryption-provider-config` flag'iga berilgan `EncryptionConfiguration` fayli bilan yoqiladi:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64 of a random 32-byte key>
      - identity: {}
```

- `resources` qaysi obyekt turlari shifrlanadi.
- `providers` ro'yxatidagi **birinchisi** yozish uchun ishlatiladi, qolganlari faqat o'qish uchun sinab ko'riladi. `identity` (shifrlamaslik) oxirida turgani uchun avval ochiq yozilgan eski Secret'lar ham o'qilaveradi.
- Shifrlangan qiymat etcd'da `k8s:enc:aescbc:v1:key1:` prefiksi bilan boshlanadi: provider, versiya va kalit nomi, keyin shifrlangan baytlar.

| Provider | Kalit qayerda | Nimadan himoya qiladi |
|----------|---------------|------------------------|
| `identity` | yo'q | hech narsadan (default) |
| `aescbc`, `aesgcm`, `secretbox` | config faylida, control-plane diskida | etcd backup'i yoki etcd diski o'g'irlanishidan; control-plane node buzilishidan emas (kalit yonida) |
| `kms` (v2) | tashqi KMS (cloud KMS, Vault) | envelope encryption: har obyekt o'z kaliti bilan, u kalit esa klasterdan tashqaridagi asosiy kalit bilan shifrlanadi |

Ikki muhim xulq. Birinchisi: yoqilgandan keyin mavjud Secret'lar o'zi qayta shifrlanmaydi, ular qayta yozilgandagina shifrlanadi. Hujjatdagi usul hammasini bir marta qayta yozish:

```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

Ikkinchisi: at-rest shifrlash API orqali o'qishdan himoya qilmaydi. `kubectl get secret` har doim ochiq qiymat qaytaradi, chunki API server uni o'zi ochib beradi. API orqali o'qishni RBAC cheklaydi.

k3s'da buning hammasi bitta server flag'i: `--secrets-encryption`. Holat `sudo k3s secrets-encrypt status` bilan ko'riladi: u shifrlash yoqilganmi, kalit almashtirish (rotation) qaysi bosqichda va qaysi kalit turi faol ekanini chiqaradi. k3s default holatda etcd o'rniga SQLite ishlatadi (2-dars), fayli `/var/lib/rancher/k3s/server/db/` ostida. Managed klasterlarda (EKS, GKE, AKS) bu provayder KMS'i bilan sozlama darajasida yoqiladi.

### Real ishda qachon kerak

Har doim. Production klasterda encryption at rest (yaxshisi KMS bilan) yoqilgan bo'ladi, Secret'ga RBAC orqali faqat kerakli ServiceAccount'lar kiradi, ilova esa Secret'ni fayl sifatida o'qiydi. etcd backup'lari (12-dars) Secret'lar bilan birga ketadi, shuning uchun backup ham maxfiy ma'lumot sifatida saqlanadi.

### Nima uchun shunday

Kubernetes Secret'ni ataylab "kichik" qilib loyihalagan: u qiymatni pod'ga yetkazish mexanizmi, xavfsiz saqlash tizimi emas. Haqiqiy himoya qatlamlari (RBAC, etcd shifrlash, tashqi secret menejeri) alohida va almashtiriladigan qilib qo'yilgan, chunki har tashkilotda kalit boshqaruvi har xil (cloud KMS, Vault, HSM). Muqobil yondashuv, ilova Secret'ni umuman ishlatmay to'g'ridan-to'g'ri Vault'dan o'qishi, ham mavjud, lekin ilova kodini tashqi tizimga bog'laydi.

## 2. Secret'ni git'da ushlash

### Bu nima

10-darsdagi GitOps'da klaster holati git'dan olinadi, Secret manifesti esa git'ga tushmasligi kerak. Bu ziddiyatni uch xil yondashuv hal qiladi, uchalasida ham git'da ochiq qiymat yo'q:

| | Sealed Secrets | SOPS | External Secrets Operator |
|---|----------------|------|---------------------------|
| Git'da nima | shifrlangan `SealedSecret` CR | qiymatlari shifrlangan YAML | faqat havola (`ExternalSecret`) |
| Kalit qayerda | klasterdagi controller'da (private key) | age/PGP kalit yoki cloud KMS | tashqi secret manager'da (AWS Secrets Manager, Vault va boshqalar) |
| Kim ochadi | controller klaster ichida | Flux (o'rnatilgan), Argo CD (plugin) yoki CI | operator qiymatni tashqaridan olib Secret yaratadi |
| Rotatsiya | qayta seal va commit | qayta shifrlash va commit | secret manager'da o'zgartiriladi, operator `refreshInterval` bo'yicha oladi |
| Bog'liqlik | controller kaliti backup'i | kalit boshqaruvi | tashqi xizmat va unga autentifikatsiya |

CR (Custom Resource) bu CRD (3-dars) orqali qo'shilgan obyekt turining bitta nusxasi. Uchala holatda ham klaster ichida oxir-oqibat oddiy Secret paydo bo'ladi va 1-bo'limdagi hamma narsa unga tegishli.

### Mexanizm: Sealed Secrets

Asimmetrik shifrlash: public key bilan shifrlangan narsani faqat mos private key ochadi. Sealed Secrets controller'i klasterda o'rnatilganda kalit juftligini yaratadi va private key'ni `kube-system` dagi oddiy Secret sifatida saqlaydi. `kubeseal` controller'dan public key'ni oladi, oddiy Secret manifestini lokal shifrlaydi va `SealedSecret` chiqaradi. Uni git'ga qo'yish xavfsiz. Klasterga apply qilinganda controller uni ochib, xuddi shu nomdagi oddiy Secret yaratadi va uning egasi (`ownerReferences`, 5-dars) bo'ladi.

```
$ helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
$ helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system \
    --set-string fullnameOverride=sealed-secrets-controller
$ kubectl -n demo create secret generic mailer --from-file=api-key=$HOME/lab-secrets/mailer-key.txt \
    --dry-run=client -o yaml | kubeseal --format yaml > mailer-sealed.yaml
```

- `fullnameOverride=sealed-secrets-controller`: `kubeseal` default holatda aynan shu nomdagi controller'ni `kube-system` da qidiradi.
- `--dry-run=client -o yaml` Secret'ni klasterga yubormay, faqat manifestini chiqaradi. Ochiq manifest diskka umuman yozilmaydi, pipe ichida qoladi.

`mailer-sealed.yaml` ichida `spec.encryptedData.api-key` uzun shifrlangan satr. Shifrga Secret nomi va namespace qo'shib shifrlanadi (scope `strict`, default), shuning uchun boshqa nom yoki namespace bilan apply qilingan `SealedSecret` ochilmaydi. Bo'shroq scope'lar `--scope namespace-wide` va `--scope cluster-wide`. Controller kaliti yo'qolsa (klaster qayta yaratilsa) barcha `SealedSecret` foydasiz bo'ladi, shuning uchun kalitni klasterdan tashqarida xavfsiz saqlash shart. Kalit Secret'lari `sealedsecrets.bitnami.com/sealed-secrets-key` label'i bilan belgilangan.

### Mexanizm: SOPS

SOPS faylni butunlay emas, faqat qiymatlarini shifrlaydi: YAML kalitlari ochiq qoladi, shuning uchun `git diff` da qaysi maydon o'zgargani ko'rinadi. Kalit sifatida `age` (zamonaviy, sodda fayl shifrlash vositasi), PGP yoki cloud KMS ishlatiladi. `age-keygen` kalit juftligini yaratadi: public key `age1...` bilan boshlanadi va bemalol ulashiladi, private key faylda qoladi.

```
$ age-keygen -o ~/lab-secrets/age-demo.txt
Public key: age1<...>
$ sops --encrypt --age age1<...> --encrypted-regex '^(data|stringData)$' mailer-plain.yaml > mailer.enc.yaml
```

Natija fayl tuzilishi (qisqartirilgan):

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: mailer
data:
    api-key: ENC[AES256_GCM,data:<...>,iv:<...>,tag:<...>,type:str]
sops:
    age:
        - recipient: age1<...>
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            <...>
    mac: ENC[AES256_GCM,data:<...>,type:str]
    encrypted_regex: ^(data|stringData)$
```

- `--encrypted-regex` faqat mos kalitlar ostidagi qiymatlar shifrlanadi; `metadata.name` ochiq qoladi, aks holda Kubernetes ham, odam ham faylni tanimaydi.
- `ENC[AES256_GCM,...]` qiymat tasodifiy "data key" bilan AES-GCM'da shifrlangan.
- `sops.age[].enc` o'sha data key, recipient'ning public key'i bilan shifrlangan. Recipient bir nechta bo'lishi mumkin (ikki mashina, jamoa a'zolari, CI).
- `mac` butun fayl yaxlitligi: kimdir shifrlangan qiymatni qo'lda almashtirsa, ochishda xato chiqadi.

Har safar `--age` va regex yozmaslik uchun repo ildizida `.sops.yaml` faylidagi `creation_rules` yo'l naqshi bo'yicha qoidalar beradi. Ochish uchun `sops --decrypt`, u private key'ni `SOPS_AGE_KEY_FILE` dan yoki default joydan (Laboratoriya jadvali) oladi. `mailer-plain.yaml` repo'dan tashqarida turishi kerak.

### Mexanizm: External Secrets Operator

ESO'da git'da qiymat umuman yo'q. Ikki obyekt (ikkalasi `external-secrets.io/v1`):

- `SecretStore` (yoki klaster miqyosidagi `ClusterSecretStore`): qayerdan va qanday autentifikatsiya bilan olish. `spec.provider` ostida provayderga xos blok (`aws`, `vault`, `gcpsm` va boshqalar; sinov uchun `fake`).
- `ExternalSecret`: qaysi tashqi kalitni qaysi Secret'ga, qancha vaqtda bir yangilab.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: mailer, namespace: demo }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: team-store, kind: SecretStore }
  target: { name: mailer }        # Secret to create
  data:
    - secretKey: api-key           # key inside the Secret
      remoteRef: { key: prod/mailer/api-key }
```

Operator `refreshInterval` da bir tashqi qiymatni o'qiydi va Secret'ni yangilaydi. Holatni `kubectl get externalsecret` dagi `STATUS` (`SecretSynced` yoki xato sababi) va `READY` ustunlari ko'rsatadi. Nozik joy: operatorning o'zi secret manager'ga qanday kiradi. Statik access key bersangiz muammo bir qadam orqaga suriladi xolos; cloud'da eng toza yo'l workload identity (3-bo'lim oxiri).

### Real ishda qachon kerak

Kichik jamoa, bitta klaster, tashqi secret manager yo'q: Sealed Secrets eng oddiy. Flux ishlatiladi yoki secret'lar bir nechta klaster va muhitga bir xil ko'rinishda ketadi: SOPS, ayniqsa cloud KMS bilan. Kompaniyada allaqachon AWS Secrets Manager yoki Vault bor, rotatsiya va audit o'sha yerda: ESO.

### Nima uchun shunday

GitOps "git yagona haqiqat manbai" deydi, xavfsizlik esa "maxfiy qiymat git'da bo'lmasin" deydi. Uch yondashuv bu ikki talabni turlicha murosaga keltiradi: Sealed Secrets va SOPS shifrlangan qiymatni git'da saqlaydi (haqiqat manbai git, kalit boshqa joyda), ESO esa haqiqat manbaini butunlay tashqi tizimga ko'chiradi (git'da faqat havola). Tanlov kalitni kim boshqarishi va rotatsiya qanchalik tez-tez bo'lishiga bog'liq.

## 3. RBAC va ServiceAccount

### Bu nima

API server har so'rovni uch bosqichdan o'tkazadi:

1. **Authentication** (kim): klient sertifikati, token yoki OIDC orqali foydalanuvchi aniqlanadi.
2. **Authorization** (ruxsat bormi): RBAC (Role-Based Access Control, rolga asoslangan ruxsat) shu yerda.
3. **Admission** (so'rovni o'zgartirish yoki rad etish): Pod Security (5-bo'lim) shu yerda.

RBAC faqat ruxsat **qo'shadi**, "deny" qoidasi yo'q: hech qaysi qoida mos kelmasa so'rov rad etiladi (default deny).

| Obyekt | Qamrov | Vazifasi |
|--------|--------|----------|
| `Role` | namespace | qoidalar: `apiGroups`, `resources`, `verbs`, ixtiyoriy `resourceNames` |
| `ClusterRole` | klaster | xuddi shu, plus klaster miqyosidagi resurslar (node, PV, namespace) va `nonResourceURLs` (`/healthz` kabi) |
| `RoleBinding` | namespace | subject'larni Role **yoki ClusterRole** ga shu namespace ichida bog'laydi |
| `ClusterRoleBinding` | klaster | subject'larni ClusterRole'ga hamma namespace'da bog'laydi |

Subject (huquq beriladigan tomon) uch xil: `User`, `Group`, `ServiceAccount`. User va Group Kubernetes obyekti emas, ular authentication qatlamidan keladi (sertifikatdagi CN va O maydonlari, OIDC claim'lari). ServiceAccount esa namespace'dagi oddiy obyekt: pod'lar va avtomatlashtirish (CI, controller) uchun identifikatsiya.

### Mexanizm

Qoida "qaysi API guruhidagi qaysi resursga qaysi verb" ko'rinishida. Verb'lar: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`. Subresource'lar alohida yoziladi: `pods/log`, `pods/exec`, `deployments/scale`. `kubectl rollout restart` aslida Deployment'ni `patch` qiladi (pod template'ga annotatsiya qo'shadi), shuning uchun "restart huquqi" alohida verb emas.

RoleBinding + ClusterRole kombinatsiyasi eng ko'p ishlatiladi: qoidalar bir marta ClusterRole'da yoziladi (masalan o'rnatilgan `view`, `edit`, `admin`), har namespace'da RoleBinding bilan alohida bog'lanadi va huquq faqat shu namespace'da amal qiladi.

RBAC o'zini o'zi kengaytirishdan himoyalangan: Role yoki ClusterRole yaratayotganda unga o'zingizda yo'q huquqni yoza olmaysiz (rolda `escalate` verb'i bo'lmasa), RoleBinding yaratayotganda esa bog'lanayotgan roldagi barcha huquqlar sizda shu qamrovda bo'lishi kerak (yoki o'sha rolga `bind` verb'i). Bu tekshiruv aynan `roles`, `rolebindings` va ularning klaster versiyalari uchun ishlaydi.

### Ishlaydigan misol

`demo` da `reporter` ServiceAccount, ConfigMap'larni faqat o'qiy oladi:

```
$ kubectl -n demo create serviceaccount reporter
serviceaccount/reporter created
$ kubectl -n demo create role cm-reader --verb=get,list,watch --resource=configmaps
role.rbac.authorization.k8s.io/cm-reader created
$ kubectl -n demo create rolebinding reporter-cm --role=cm-reader --serviceaccount=demo:reporter
rolebinding.rbac.authorization.k8s.io/reporter-cm created
```

`--serviceaccount=<namespace>:<nom>` formati. Endi tekshiruv. `--as` impersonation (boshqa subject nomidan so'rov): admin sifatida "u bunga haqli bo'larmidi" deb so'raymiz.

```
$ kubectl auth can-i list configmaps -n demo --as=system:serviceaccount:demo:reporter
yes
$ kubectl auth can-i delete configmaps -n demo --as=system:serviceaccount:demo:reporter
no
$ kubectl auth can-i list configmaps -n default --as=system:serviceaccount:demo:reporter
no
$ kubectl auth can-i --list -n demo --as=system:serviceaccount:demo:reporter
Resources                                       Non-Resource URLs   Resource Names   Verbs
selfsubjectreviews.authentication.k8s.io        []                  []               [create]
configmaps                                      []                  []               [get list watch]
                                                [/api/*]            []               [get]
...
```

- ServiceAccount'ning foydalanuvchi nomi `system:serviceaccount:<namespace>:<nom>`, RBAC'da shu satr tekshiriladi.
- Uchinchi so'rov `no`: RoleBinding faqat `demo` da amal qiladi.
- `--list` dagi `selfsubject...` qatorlari (bu yerda bittasi ko'rsatilgan) va `/api/*` kabi non-resource URL'lar har autentifikatsiyalangan subject'ga o'rnatilgan `system:basic-user` va `system:discovery` ClusterRole'lari orqali beriladi. Ular "o'zim haqimda so'rash" va API discovery uchun.

O'zingiz kimligingiz:

```
$ kubectl auth whoami
ATTRIBUTE                                           VALUE
Username                                            kubernetes-admin
Groups                                              [kubeadm:cluster-admins system:authenticated]
```

kind kubeconfig'idagi sertifikat `kubeadm:cluster-admins` guruhida, bu guruh `cluster-admin` ClusterRole'ga ClusterRoleBinding bilan bog'langan. Ya'ni siz hamma narsaga haqlisiz va `can-i` ni `--as` siz ishlatsangiz har doim `yes` olasiz.

### Huquqni kengaytiradigan yo'llar

| Huquq | Nima uchun xavfli |
|-------|-------------------|
| `secrets` ga `get`/`list` | boshqa ServiceAccount token'lari, parollar. `list` ham qiymatlarni to'liq qaytaradi |
| Pod (yoki Deployment, Job, CronJob) yaratish | pod spec'ida istalgan Secret mount qilinadi va istalgan `serviceAccountName` yoziladi; RBAC pod qaysi ServiceAccount'dan foydalanishini tekshirmaydi |
| `pods/exec` | ishlab turgan pod'ning token'i, env'i va fayllariga kirish |
| `rolebindings` yaratish, `bind`, `escalate` | o'ziga yangi huquq berish (yuqoridagi himoya chegarasida) |
| `impersonate` | boshqa user, guruh yoki ServiceAccount nomidan harakat |
| `*` verb yoki resource | kelajakda qo'shiladigan resurslar va subresource'lar ham kiradi |
| `nodes/proxy`, PV yaratish, `hostPath` bilan pod | kubelet API, node fayl tizimi (5-bo'lim) |

### ServiceAccount token

- Har namespace'da `default` ServiceAccount bor, pod spec'da boshqasi ko'rsatilmasa u ishlatiladi. Uning RBAC huquqi yo'q, lekin token baribir mount qilinadi.
- Token pod'ga **projected volume** (bir nechta manbani bitta papkaga yig'adigan volume turi) orqali beriladi: `/var/run/secrets/kubernetes.io/serviceaccount/` ichida `token`, `ca.crt` va `namespace` fayllari.
- Token JWT (JSON Web Token): nuqta bilan ajratilgan uch qism (header, payload, imzo), har biri base64url'da. Frontend'da login token'i sifatida ko'rgan narsangizning aynan o'zi. Pod'dagi token o'sha pod'ga bog'langan (pod o'chsa yaroqsiz), muddati cheklangan, kubelet uni muddati tugashidan oldin yangilaydi, `aud` (audience, "kim uchun mo'ljallangan") claim'iga ega.
- API'ga murojaat qilmaydigan ilova uchun `automountServiceAccountToken: false` (pod yoki ServiceAccount darajasida). Ilova buzilsa hujumchi qo'lida token bo'lmaydi.
- Har ilovaga o'z ServiceAccount'i. Bir necha ilova `default` ni bo'lishsa, biriga berilgan huquq hammasiga beriladi.

Token'ni klasterdan tashqarida qisqa muddatga olish va payload'ini lokal o'qish (jwt.io kabi saytga emas):

```
$ TOKEN=$(kubectl -n demo create token reporter --duration=10m)
$ node -e 'const p=process.argv[1].split(".")[1]; console.log(JSON.stringify(JSON.parse(Buffer.from(p,"base64url")),null,2))' "$TOKEN"
{
  "aud": ["https://kubernetes.default.svc.cluster.local"],
  "exp": <unix time, 10 minutes ahead>,
  "iat": <unix time, now>,
  "iss": "https://kubernetes.default.svc.cluster.local",
  "jti": "<...>",
  "kubernetes.io": {
    "namespace": "demo",
    "serviceaccount": { "name": "reporter", "uid": "<...>" }
  },
  "nbf": <unix time, now>,
  "sub": "system:serviceaccount:demo:reporter"
}
```

- `sub` RBAC tekshiradigan foydalanuvchi nomi.
- `aud` va `iss` token kim tomonidan, kim uchun chiqarilgani; API server boshqa `aud` li token'ni qabul qilmaydi.
- `exp - iat` 600 soniya: `--duration` ga mos. `kubernetes.io` ichida pod nomi yo'q, chunki bu token pod'ga bog'lanmagan; pod ichidagi token'da u bo'ladi (10-vazifa).
- `Buffer.from(p, "base64url")`: oddiy `base64 -d` padding'siz base64url'ni har doim ham to'g'ri ochmaydi, Node buni o'zi hal qiladi.

Cloud'da shu token OIDC (OpenID Connect, token'lar asosidagi standart autentifikatsiya protokoli) orqali cloud IAM role'ga almashtiriladi: bu **workload identity**. Pod'ga cloud access key berish kerak bo'lmaydi.

### Real ishda qachon kerak

CI pipeline'ning klasterga kirishi (9-dars): faqat o'z namespace'ida, faqat kerakli resurslarga. Controller va operator'lar (Sealed Secrets, ESO, Argo CD) o'z ServiceAccount'i bilan ishlaydi va ularning huquqi ko'pincha keng, shuning uchun audit qilinadi (11-vazifa). Jamoa a'zolari OIDC guruhlari orqali namespace'larga `view` yoki `edit` oladi.

### Nima uchun shunday

"Faqat allow, deny yo'q" modeli qoidalar tartibi va ziddiyatlari muammosini yo'q qiladi: ikki qoida hech qachon bir-biriga zid kelmaydi, natija doim ruxsatlar birlashmasi. RBAC 1.6–1.8 versiyalarida asosiy usulga aylanguncha ABAC (fayldagi siyosatlar, o'zgartirish uchun API server qayta ishga tushirilardi) ishlatilgan; RBAC API obyektlari bo'lgani uchun boshqa obyektlar kabi `kubectl apply` va GitOps bilan boshqariladi. Token'lar ilgari muddatsiz Secret sifatida saqlanardi; ular sizib chiqqanda abadiy ishlagani sababli 1.22 dan boshlab projected, muddatli token'larga o'tildi.

## 4. NetworkPolicy

### Bu nima

Default holatda klaster tarmog'i tekis: istalgan pod istalgan namespace'dagi istalgan pod'ga ulana oladi (6-dars). NetworkPolicy bu L3/L4 darajasidagi (IP manzil va port) firewall qoidasi, pod'larni IP bilan emas, label bilan tanlaydi.

### Mexanizm

- NetworkPolicy'ni API server har doim qabul qiladi, lekin uni **CNI plugin** bajaradi (iptables, nftables yoki eBPF qoidalariga aylantiradi). Qo'llamaydigan CNI'da policy jim e'tiborsiz qoladi: xato ham, ogohlantirish ham yo'q.
- Pod'ni hech qaysi policy tanlamasa, u ochiq. Kamida bitta policy uni ma'lum yo'nalishda (`Ingress` kiruvchi yoki `Egress` chiquvchi) tanlasa, shu yo'nalishda faqat ruxsat berilgan trafik o'tadi.
- Policy'lar **qo'shiladi**: deny qoidasi yo'q, bir nechta policy ruxsatlarining birlashmasi amal qiladi, tartib yo'q. RBAC bilan bir xil mantiq.
- Javob trafigi avtomatik ruxsat etiladi (stateful): `client` dan `server` ga ulanish ruxsat etilgan bo'lsa, javob uchun alohida qoida kerak emas.
- Qoidalar Service'ga emas, pod'ga qo'llanadi va Service IP'si pod IP'siga almashtirilgandan (DNAT, 6-dars) keyin tekshiriladi. Shuning uchun `ports` da Service porti emas, konteyner porti (`targetPort`) yoziladi.

`from` (ingress) va `to` (egress) manbalari uch xil:

| Manba | Nimani tanlaydi |
|-------|-----------------|
| `podSelector` | shu namespace'dagi label'li pod'lar |
| `namespaceSelector` | label'li namespace'lardagi barcha pod'lar; har namespace'da avtomatik `kubernetes.io/metadata.name: <nom>` label'i bor |
| `ipBlock` | CIDR, klasterdan tashqari manzillar uchun |

**AND va OR.** Bitta ro'yxat elementi ichida `namespaceSelector` va `podSelector` birga bo'lsa, bu AND. Ikki alohida element (har biri `-` bilan) bo'lsa, bu OR:

```yaml
# one element: pods labelled role=backup IN namespace ops (AND)
- namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: ops } }
  podSelector: { matchLabels: { role: backup } }
# two elements: ANY pod in ops, OR role=backup pods in my own namespace
- namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: ops } }
- podSelector: { matchLabels: { role: backup } }
```

Farq bitta `-` belgisi, natija esa butun boshqa namespace'ga eshik ochish.

### Ishlaydigan misol

`demo` da ikki pod va bitta Service:

```
$ kubectl -n demo run server --image=nginx:1.28 --labels=app=server --port=80
pod/server created
$ kubectl -n demo expose pod server --port=80
service/server exposed
$ kubectl -n demo run client --image=busybox:1.36 --labels=app=client -- sleep 3600
pod/client created
$ kubectl -n demo exec client -- wget -q -T 3 -O- http://server | head -n 4
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

Ulanish ishlaydi. `-T 3` busybox `wget` uchun 3 soniyalik timeout. Endi namespace'dagi barcha pod'larga default deny ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: deny-ingress, namespace: demo }
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
```

`podSelector: {}` "hamma pod", `ingress` ro'yxati yo'q, ya'ni hech qanday kiruvchi trafik ruxsat etilmagan.

```
$ kubectl apply -f deny-ingress.yaml
networkpolicy.networking.k8s.io/deny-ingress created
$ kubectl -n demo exec client -- wget -q -T 3 -O- http://server
wget: download timed out
command terminated with exit code 1
```

- `download timed out`: paket jim tashlab yuborildi (drop), "connection refused" emas. Policy bloklagan trafik deyarli har doim timeout ko'rinishida chiqadi.
- `command terminated with exit code 1` bu `kubectl exec` ning o'z qatori: konteyner ichidagi buyruq 0 dan farqli kod qaytardi.

Agar shu yerda HTML yana kelsa, CNI'ingiz policy'ni bajarmayapti. Qaysi CNI ishlayotganini `kube-system` dagi DaemonSet'lardan ko'rasiz (`kindnet-...`, `calico-node-...`, `cilium-...`). Ruxsat qaytarish uchun `server` ga faqat `app=client` dan 80 portga ingress beradigan ikkinchi policy qo'shiladi; birinchisi o'chirilmaydi, ikkalasining birlashmasi amal qiladi.

### Egress va DNS

Egress'ni default deny qilsangiz DNS ham yopiladi: pod CoreDNS'ga (`kube-system` dagi `k8s-app: kube-dns` label'li pod'lar) so'rov yubora olmaydi, hech qaysi Service nomi resolve bo'lmaydi va ilova "timeout" yoki "bad address" deydi, garchi asl manzilga ruxsat bo'lsa ham. DNS UDP 53 da, katta javoblarda TCP 53 da ishlaydi, shuning uchun ikkalasiga ruxsat kerak. Eng keng ko'rinishi:

```yaml
egress:
  - ports:
      - { protocol: UDP, port: 53 }
      - { protocol: TCP, port: 53 }
```

`to` yo'q, demak 53 port istalgan manzilga ochiq. Uni faqat CoreDNS'ga toraytirish 14-vazifada.

### Chegaralar

Standart NetworkPolicy L7 ni (HTTP path, method), DNS nomi bo'yicha egress'ni (`api.stripe.com` ga ruxsat) va klaster miqyosidagi qoidalarni bilmaydi. Bular CNI'ning o'z CRD'larida (`CiliumNetworkPolicy`, Calico `GlobalNetworkPolicy`) yoki service mesh'da. Ingress controller va monitoring (Prometheus scrape) uchun ruxsatlarni unutmang: ular boshqa namespace'dan keladi.

### Real ishda qachon kerak

Ko'p jamoali klaster (jamoalar bir-birining bazasiga kira olmasin), PCI DSS kabi talablar (karta ma'lumoti bilan ishlaydigan qism ajratilgan bo'lsin), va eng muhimi "blast radius" (buzilgan bitta pod'dan hujumchi qanchalik uzoqqa bora oladi). Baza pod'iga faqat backend'dan ingress, ilovalarga faqat kerakli tashqi manzillarga egress.

### Nima uchun shunday

Kubernetes tarmoq modeli "har pod har pod'ga NAT'siz yeta oladi" degan talabdan boshlangan: bu ilovalarni ko'chirishni osonlashtiradi, lekin xavfsizlikni keyinga qoldiradi. NetworkPolicy API faqat interfeys, bajarilishi CNI'ga topshirilgan, chunki CNI'lar paket filtrlashni turlicha qiladi (iptables, eBPF). "Faqat allow" modeli RBAC'dagi sababdan tanlangan: tartib va ziddiyat yo'q. Kamchiligi "hamma joyda shu taqiqlansin" degan admin qoidasini yozib bo'lmasligi edi; buning uchun alohida `AdminNetworkPolicy` API ishlab chiqilmoqda.

## 5. Pod Security

### Bu nima

Konteyner izolyatsiyasi kernel namespace'lari va cgroup'larga tayanadi (docker moduli), kernel esa node'dagi hamma konteyner uchun bitta. Pod spec'dagi ba'zi maydonlar bu izolyatsiyani buzadi: `privileged: true` (konteynerga deyarli barcha kernel huquqlari), `hostNetwork`, `hostPID` (node'ning tarmoq va jarayonlar namespace'i), `hostPath` volume (node fayl tizimi). Bularni yarata oladigan foydalanuvchi amalda node'da root. `securityContext` esa teskari yo'nalishda ishlaydi: konteynerni default'dan ham torroq qiladi.

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
| `runAsNonRoot`, `runAsUser` | konteynerdan chiqish zaifligida host'da root bo'lish; `runAsNonRoot: true` da image `USER` root (UID 0) bo'lsa va `runAsUser` berilmagan bo'lsa pod ishga tushmaydi (`CreateContainerConfigError`) |
| `allowPrivilegeEscalation: false` | setuid binary (masalan `sudo`) orqali root olish; kernel'dagi `no_new_privs` bayrog'ini yoqadi |
| `readOnlyRootFilesystem` | hujumchi konteynerga binary yoki skript yoza olmaydi; yozish kerak joylarga `emptyDir` mount qilinadi (`/tmp`, cache) |
| `capabilities.drop: ALL` | Linux capability'lari (root huquqining bo'laklari: `NET_RAW`, `CHOWN`, `SYS_ADMIN`...) olib tashlanadi; 1024 dan past port kerak bo'lsa faqat `NET_BIND_SERVICE` qo'shiladi |
| `seccompProfile: RuntimeDefault` | container runtime'ning default ro'yxatidagi xavfli syscall'larni (tizim chaqiruvlari) bloklaydi |

Pod darajasidagi `securityContext` da `runAsUser`, `runAsGroup`, `runAsNonRoot`, `seccompProfile` hamma konteynerlar uchun default bo'ladi, `fsGroup` esa volume'dagi fayllar guruhini belgilaydi (non-root jarayon PVC'ga yoza olishi uchun, 7-dars). `capabilities`, `allowPrivilegeEscalation` va `readOnlyRootFilesystem` faqat konteyner darajasida.

Konteynerdagi capability'larni `/proc/1/status` dagi `CapEff` (amaldagi capability'lar) qatori o'n oltilik bitmask sifatida ko'rsatadi. Uni `lab` VM'da `capsh --decode=<hex>` bilan nomlarga ochish mumkin (`capsh` Linux'ga xos, macOS'da yo'q).

### Ishlaydigan misol

```yaml
apiVersion: v1
kind: Pod
metadata: { name: tight, namespace: demo }
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: main
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      volumeMounts:
        - { name: tmp, mountPath: /tmp }
  volumes:
    - name: tmp
      emptyDir: {}
```

```
$ kubectl -n demo exec tight -- id
uid=10001 gid=10001 groups=10001
$ kubectl -n demo exec tight -- touch /x
touch: /x: Read-only file system
command terminated with exit code 1
$ kubectl -n demo exec tight -- touch /tmp/x
$ kubectl -n demo exec tight -- grep -E 'CapEff|CapBnd' /proc/1/status
CapEff:	0000000000000000
CapBnd:	0000000000000000
```

- `id`: UID va GID 10001, nomsiz, chunki image'ning `/etc/passwd` ida bunday foydalanuvchi yo'q. Bu xato emas.
- `touch /x` root fayl tizimi faqat o'qish uchun; `/tmp` esa `emptyDir`, unga yozish mumkin.
- `CapEff` nol, chunki jarayon root emas: root bo'lmagan jarayonda amaldagi capability'lar default'da ham bo'sh. `CapBnd` (bounding set, jarayon kelajakda olishi mumkin bo'lgan capability'lar chegarasi) ham nol, buni `drop: ["ALL"]` qildi: setuid binary ham endi capability ololmaydi.

busybox `sleep` hech narsaga yozmaydi va port ochmaydi, shuning uchun hammasi birdan ishladi. Haqiqiy ilovada (nginx, Node server) shu to'plam odatda bir nechta joyni buzadi: root'ga mo'ljallangan image, `/var/cache` yoki `/run` ga yozish, 80 port. 18-vazifa aynan shu buzilishlarni birma-bir tuzatish haqida. Ko'p mashhur image'larning non-root varianti bor.

### Pod Security Standards va admission

Pod Security Standards (PSS) uch profil:

- `privileged`: cheklovsiz.
- `baseline`: ma'lum xavfli sozlamalar taqiqlangan (privileged, host namespace'lar, `hostPath`, xavfli capability'lar).
- `restricted`: baseline plus yuqoridagi `securityContext` to'plami majburiy (`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `seccompProfile`). `readOnlyRootFilesystem` talab qilinmaydi.

Ularni o'rnatilgan Pod Security Admission (PSA) controller namespace label'lari orqali qo'llaydi:

```bash
kubectl label ns demo \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted
```

Rejimlar: `enforce` (pod rad etiladi), `audit` (audit log'ga yoziladi, 7-bo'lim), `warn` (`kubectl` da ogohlantirish). Rejimlar bir-biridan mustaqil, shuning uchun "baseline'ni majburla, restricted haqida ogohlantir" degan kombinatsiya mumkin. Har rejim uchun `...-version` label'i ham bor (default `latest`, ya'ni klaster versiyasidagi qoidalar).

`demo` da yuqoridagi label'lar bilan oddiy busybox pod yaratsangiz:

```
$ kubectl -n demo run plain --image=busybox:1.36 -- sleep 3600
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "plain" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "plain" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "plain" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "plain" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
pod/plain created
```

- `would violate PodSecurity "restricted:latest"`: `warn` rejimi; profil va versiya.
- Har buzilish alohida: qaysi tekshiruv (`allowPrivilegeEscalation != false`) va nimani qo'yish kerak (`must set ...`).
- `pod/plain created`: `enforce=baseline` ga mos, shuning uchun yaratildi. `enforce=restricted` bo'lsa xuddi shu matn `Error from server (Forbidden): ... violates PodSecurity ...` ko'rinishida chiqardi va pod yaratilmasdi.

Muhim nuqta: PSA **pod** darajasida ishlaydi. Deployment yaratilganda u qabul qilinadi (Deployment'da pod spec bor, lekin u pod emas), pod'larni esa ReplicaSet controller yaratishga urinadi va rad javobini o'zi oladi. Xato siz ko'radigan joyda emas, ReplicaSet event'larida turadi. PSA `warn` rejimi esa qulaylik uchun workload obyektlarida ham ogohlantiradi.

Joriy qilish tartibi: avval `warn` va `audit`, buzilishlarni tuzatish, keyin `enforce`. Mavjud namespace'ga label qo'yishdan oldin `kubectl label --dry-run=server` qaysi ishlab turgan pod'lar buzilishini ogohlantirish sifatida ko'rsatadi.

Nozikroq qoidalar ("faqat shu registry'dan image", "har pod'da resource limits") uchun o'rnatilgan `ValidatingAdmissionPolicy` (CEL ifodalari bilan) yoki Kyverno, OPA Gatekeeper kabi policy engine'lar.

### Real ishda qachon kerak

Ilova namespace'larida `restricted` enforce standart bo'lishi kerak. `baseline` dan pastga faqat haqiqatan node'ga kirishi kerak bo'lgan tizim komponentlari (CNI, log agent, monitoring DaemonSet'lari) tushadi va ular alohida namespace'da turadi. Dockerfile yozayotganda (docker moduli) `USER` qo'yish shu talabning boshlanishi.

### Nima uchun shunday

Avval PodSecurityPolicy (PSP) bor edi: klaster miqyosidagi obyekt, RBAC orqali foydalanuvchiga bog'lanardi va qaysi policy qo'llanishini tushunish juda qiyin edi. U 1.21 da deprecated, 1.25 da olib tashlandi. PSA ataylab sodda qilingan: uch qat'iy profil, namespace label'i, sozlanadigan hech narsa yo'q. Moslashuvchanlik kerak bo'lsa, u alohida policy engine'ga topshirilgan.

## 6. Image va supply chain

### Bu nima

Supply chain (ta'minot zanjiri) bu kodingizdan ishlab turgan konteynergacha bo'lgan hamma narsa: base image, kutubxonalar, build pipeline, registry. npm'dagi buzilgan paketlar (`event-stream` voqeasi) frontend'dagi supply chain hujumining tanish misoli; konteyner dunyosida xuddi shu narsa base image va CI action'lari orqali sodir bo'ladi.

### Mexanizm

- **Skanerlash**: `trivy image <image>` image ichidagi OS paketlari va kutubxonalar versiyalarini CVE (ommaviy ro'yxatga olingan zaiflik) bazasi bilan solishtiradi. `trivy config <dir>` manifest va Dockerfile'dagi xato sozlamalarni (root, `latest`, limit yo'q) topadi. CI'da `--severity HIGH,CRITICAL --exit-code 1` bilan "gate" bo'ladi: topilsa pipeline yiqiladi. Skaner faqat ma'lum zaifliklarni biladi va hali tuzatishi chiqmagan CVE'lar uchun siyosat kerak (kutish, istisno, base image almashtirish). `--ignore-unfixed` faqat tuzatishi bor zaifliklarni ko'rsatadi.
- **Kichik base image**: distroless yoki minimal image'da shell va paket menejeri yo'q, CVE soni ham, hujumchining asboblari ham kam (docker moduli).
- **Digest bilan pin** (9-dars): tag o'zgarishi mumkin, digest o'zgarmaydi. `package-lock.json` dagi `integrity` hash'iga o'xshaydi.
- **Imzo**: cosign (Sigstore loyihasi) image'ni imzolaydi, admission policy (Kyverno, Sigstore policy-controller) imzosiz yoki begona imzoli image'ni rad etadi.
- **SBOM** (Software Bill of Materials): image ichidagi barcha komponentlar ro'yxati. Yangi CVE chiqqanda "bizda bormi" savoliga qayta skanerlamasdan javob beradi. `trivy image --format cyclonedx` SBOM chiqaradi.
- CI action'larini ham SHA bilan pin qiling: build pipeline'ning o'zi supply chain'ning bir qismi.

### Ishlaydigan misol

```
$ trivy image --severity HIGH,CRITICAL redis:7.4
<...> INFO  Detected OS  family="debian" version="<...>"
<...>
Report Summary
┌───────────────────────────┬────────┬─────────────────┬─────────┐
│          Target           │  Type  │ Vulnerabilities │ Secrets │
├───────────────────────────┼────────┼─────────────────┼─────────┤
│ redis:7.4 (debian <...>)  │ debian │       <N>       │    -    │
└───────────────────────────┴────────┴─────────────────┴─────────┘
```

- Birinchi ishga tushirishda (`INFO` qatorlaridan oldin) trivy zaifliklar bazasini yuklab oladi (bir necha o'n MB), keyingi safar keshdan.
- `Detected OS` image qaysi distributivga asoslangani; bazadagi qaysi ro'yxat bilan solishtirilishini shu belgilaydi.
- `Report Summary` har "target" (OS qatlami, `package-lock.json`, `go.sum` kabi fayllar) bo'yicha topilganlar soni, undan keyin har CVE uchun jadval: kutubxona, o'rnatilgan va tuzatilgan versiya, darajasi. Sonlar baza yangilangani sari o'zgaradi, shuning uchun README'da skanerlash sanasini yozing.

### Real ishda qachon kerak

Har image build'ida CI'da skanerlash, registry'da muntazam qayta skanerlash (yangi CVE eski image'larga ham tegishli), production namespace'larida imzo tekshiruvi. Tuzatish base image'ni yangilash bilan boshlanadi: CVE'larning katta qismi ilovangizda emas, OS paketlarida.

### Nima uchun shunday

Image bir marta build qilinib oylab ishlaydi, CVE bazasi esa har kuni o'sadi, shuning uchun skanerlash bir martalik emas. Imzo va SBOM SolarWinds va Codecov kabi build tizimi orqali hujumlardan keyin standartga aylandi: "bu image'ni kim, qaysi koddan build qildi" degan savolga isbotli javob kerak bo'ldi.

## 7. Audit

### Bu nima

Audit log bu API server'ning har so'rov haqidagi yozuvi: kim, qachon, qaysi resursga, qaysi verb, natija. Incident tekshiruvida "bu Secret'ni kim o'qidi", "bu RoleBinding'ni kim yaratdi" savollariga yagona ishonchli manba.

### Mexanizm

Audit API server flag'lari bilan yoqiladi: `--audit-policy-file` (nimani yozish) va backend (`--audit-log-path` fayl yoki webhook). Policy (`audit.k8s.io/v1`, `kind: Policy`) qoidalar ro'yxati, so'rovga **birinchi mos kelgan** qoida darajani belgilaydi (RBAC va NetworkPolicy'dan farqli, bu yerda tartib muhim):

| Daraja | Nima yoziladi |
|--------|---------------|
| `None` | hech narsa |
| `Metadata` | kim, qachon, qaysi resurs va verb, javob kodi; tanasiz |
| `Request` | plus so'rov tanasi |
| `RequestResponse` | plus javob tanasi |

Har so'rov bosqichlardan o'tadi (`RequestReceived`, `ResponseStarted`, `ResponseComplete`, `Panic`), `omitStages` ortiqcha bosqichlarni tashlaydi. Kichik misol:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: None
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["events"]
  - level: RequestResponse
    verbs: ["delete"]
    resources:
      - group: ""
        resources: ["configmaps"]
  - level: Metadata
```

Bir audit yozuvi (JSON, bitta qator, bu yerda qisqartirilib formatlangan):

```json
{
  "kind": "Event", "level": "RequestResponse", "stage": "ResponseComplete", "verb": "delete",
  "user": { "username": "system:serviceaccount:demo:reporter", "groups": ["system:serviceaccounts", "..."] },
  "sourceIPs": ["10.244.1.7"], "userAgent": "kubectl/<version> (linux/amd64)",
  "objectRef": { "resource": "configmaps", "namespace": "demo", "name": "app-config", "apiVersion": "v1" },
  "responseStatus": { "code": 403 }, "requestReceivedTimestamp": "<...>"
}
```

`code: 403` so'rov RBAC'da rad etilganini ko'rsatadi: audit muvaffaqiyatsiz urinishlarni ham yozadi, bu hujumni payqashda muhim.

Secret'lar uchun `Metadata` dan yuqori daraja qo'yilmaydi: `Request` yoki `RequestResponse` da qiymatlar log'ga tushadi va log o'zi maxfiy ma'lumotga aylanadi. kind'da audit'ni yoqish uchun klaster config'iga policy faylini mount qilish va API server flag'larini qo'shish kerak, yo'li kind hujjatida (Manbalar). Managed klasterlarda audit log cloud log xizmatiga yoqiladi.

### Real ishda qachon kerak

Compliance talablari (SOC 2, PCI DSS) audit log'ni talab qiladi. Log klasterdan tashqarida saqlanadi (observability moduli), chunki klasterga kirgan hujumchi node'dagi log faylini o'chira oladi. Hajmni `None` qoidalari bilan nazorat qilish kerak: `get`/`watch` so'rovlari soniyasiga yuzlab.

### Nima uchun shunday

Audit API server'da, chunki klasterdagi har o'zgarish undan o'tadi (1-dars): bitta nazorat nuqtasi. "Birinchi mos qoida" tartibi ataylab: aniq istisnolar (`None` shovqinli so'rovlar uchun) yuqorida, umumiy qoida pastda, firewall qoidalari kabi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Encryption at rest | ma'lumotni diskka (etcd'ga) shifrlab yozish |
| KMS | Key Management Service, kalitlarni saqlaydigan va ular bilan shifrlaydigan tashqi xizmat |
| Sealed Secrets | public key bilan shifrlangan Secret'ni klaster ichidagi controller ochadigan vosita |
| SOPS | fayldagi qiymatlarni kalitlarni ochiq qoldirib shifrlaydigan vosita |
| External Secrets Operator | tashqi secret manager'dagi qiymatni klasterga Secret sifatida sinxronlaydigan operator |
| RBAC | rollarga asoslangan, faqat ruxsat qo'shadigan avtorizatsiya modeli |
| Role / ClusterRole | namespace / klaster qamrovidagi ruxsatlar to'plami |
| RoleBinding / ClusterRoleBinding | subject'ni rolga bog'lash, namespace / klaster qamrovida |
| ServiceAccount | pod va avtomatlashtirish uchun namespace'dagi identifikatsiya obyekti |
| Workload identity | ServiceAccount token'ini cloud IAM role'ga almashtirish |
| NetworkPolicy | pod'lar orasidagi L3/L4 trafikni label bo'yicha cheklaydigan obyekt |
| `securityContext` | pod yoki konteyner qaysi user, capability va cheklovlar bilan ishlashini belgilaydigan maydon |
| seccomp | jarayon chaqira oladigan syscall'larni cheklaydigan kernel mexanizmi |
| Pod Security Standards | `privileged`, `baseline`, `restricted` profillari |
| Pod Security Admission | PSS'ni namespace label'i orqali qo'llaydigan o'rnatilgan admission controller |
| Audit policy | qaysi so'rov qaysi darajada audit log'ga yozilishini belgilaydigan qoidalar |

## Tuzoqlar

- Secret manifestini (base64 bilan) git'ga commit qilish. Tarixdan o'chirish yetarli emas, secret'ni almashtirish (rotate) kerak.
- Qulaylik uchun `cluster-admin` ClusterRoleBinding (CI, dashboard, "vaqtincha").
- Hamma ilova `default` ServiceAccount'da, token hamma pod'ga mount qilingan.
- `secrets` ga `list` berib "faqat ro'yxat" deb o'ylash: `list` qiymatlarni ham qaytaradi.
- Pod yaratish huquqini "xavfsiz" deb hisoblash: u namespace'dagi barcha Secret va ServiceAccount'larga yo'l.
- `kubectl auth can-i` ni `--as` siz tekshirish: admin sifatida doim `yes`.
- NetworkPolicy yozib, CNI uni bajarishini tekshirmaslik. Policy bor, himoya yo'q.
- Default deny'siz faqat "allow" policy'lar: tanlanmagan pod'lar ochiq qoladi.
- NetworkPolicy `ports` da Service portini yozish: tekshiruv konteyner portida.
- Egress deny'da DNS'ni unutish; ingress deny'da ingress controller va Prometheus'ni unutish.
- `from` ro'yxatida bitta ortiqcha `-`: AND o'rniga OR.
- `enforce=restricted` ni birdaniga yoqish: mavjud pod'lar ishlayveradi, lekin keyingi restart yoki scale'da yaratilmaydi, muammo kechasi node almashganda chiqadi.
- `readOnlyRootFilesystem` ni sinovsiz yoqish: ilova `/tmp` ga yoza olmay runtime'da yiqiladi.
- Sealed Secrets controller kalitini backup qilmaslik.
- Encryption at rest'ni yoqib, mavjud Secret'larni qayta yozmaslik: ular etcd'da ochiq qoladi.

## Manbalar

- https://kubernetes.io/docs/concepts/configuration/secret/ – Secret
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/ – Secret bo'yicha amaliyotlar
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/ – encryption at rest
- https://docs.k3s.io/security/secrets-encryption – k3s secrets encryption
- https://github.com/bitnami-labs/sealed-secrets – Sealed Secrets
- https://getsops.io/docs/ – SOPS
- https://github.com/FiloSottile/age – age
- https://external-secrets.io/latest/ – External Secrets Operator
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/ – RBAC
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/ – RBAC amaliyotlari, huquqni kengaytirish yo'llari
- https://kubernetes.io/docs/concepts/security/service-accounts/ – ServiceAccount
- https://kubernetes.io/docs/concepts/services-networking/network-policies/ – NetworkPolicy
- https://kubernetes.io/docs/concepts/security/pod-security-standards/ – Pod Security Standards
- https://kubernetes.io/docs/concepts/security/pod-security-admission/ – Pod Security Admission
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ – securityContext
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/ – ValidatingAdmissionPolicy
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ – audit
- https://kind.sigs.k8s.io/docs/user/auditing/ – kind'da audit'ni yoqish
- https://trivy.dev/ – Trivy

---

## Birga bajaramiz

Vazifalardan boshqa misol: Redis keshini "faqat o'z mijoziga" ochiq qilib ishga tushirish. Yo'l davomida uchta qatlamni birga ko'ramiz: PSA `restricted` namespace'i, unga mos `securityContext`, va bitta mijozga ruxsat beradigan NetworkPolicy. Har qadamda ham ruxsat etilgan, ham taqiqlangan holat tekshiriladi. Hammasi kind `sec` klasterida, ikkala mashinada bir xil. Agar 12-vazifada CNI'ingiz policy'ni bajarmasligi aniqlangan bo'lsa, 4-qadamdan oldin klasterni Calico bilan qayta yarating.

1. Namespace va PSA. Label'larni namespace yaratilishi bilanoq qo'yamiz, ichida hali hech narsa yo'q:

```
$ kubectl create namespace cache-demo
namespace/cache-demo created
$ kubectl label ns cache-demo pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted
namespace/cache-demo labeled
$ kubectl -n cache-demo run probe --image=busybox:1.36 -- sleep 60
Error from server (Forbidden): pods "probe" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "probe" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "probe" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "probe" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "probe" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

Bu safar `Warning` emas, `Forbidden`: pod yaratilmadi. Namespace'ning "eshigi" ishlayapti.

2. Redis Deployment va Service, `cache.yaml`. Rasmiy `redis:7.4` image'ida `redis` foydalanuvchisi UID 999; entrypoint skripti root bo'lmasa to'g'ridan-to'g'ri `redis-server` ni ishga tushiradi. Redis ma'lumotni joriy papka `/data` ga yozadi, shuning uchun u `emptyDir`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: cache, namespace: cache-demo }
spec:
  replicas: 1
  selector: { matchLabels: { app: cache } }
  template:
    metadata: { labels: { app: cache } }
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: redis
          image: redis:7.4
          ports: [{ containerPort: 6379 }]
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          volumeMounts: [{ name: data, mountPath: /data }]
      volumes: [{ name: data, emptyDir: {} }]
---
apiVersion: v1
kind: Service
metadata: { name: cache, namespace: cache-demo }
spec:
  selector: { app: cache }
  ports: [{ port: 6379, targetPort: 6379 }]
```

Tanlovlar: `automountServiceAccountToken: false` chunki Redis Kubernetes API'ga murojaat qilmaydi; `fsGroup: 999` `emptyDir` ga yozish huquqi uchun; port 6379 > 1024, shuning uchun `NET_BIND_SERVICE` kerak emas.

```
$ kubectl apply -f cache.yaml
deployment.apps/cache created
service/cache created
$ kubectl -n cache-demo rollout status deployment/cache
deployment "cache" successfully rolled out
```

`Warning` qatori chiqmadi: manifest `restricted` ga to'liq mos.

3. Ikki mijoz, `clients.yaml`. Ikkalasi ham shu namespace'da, demak ular ham `restricted` ga mos bo'lishi shart. Farq faqat label'da: `client-ok` da `role: cache-client` bor, `client-other` da yo'q. Ikkalasi `redis:7.4` image'ida `sleep` bilan turadi (ichida `redis-cli` bor), pod spec'i 2-qadamdagi bilan bir xil `securityContext` va `automountServiceAccountToken: false` oladi.

```
$ kubectl apply -f clients.yaml
pod/client-ok created
pod/client-other created
$ kubectl -n cache-demo exec client-ok -- redis-cli -h cache ping
PONG
$ kubectl -n cache-demo exec client-other -- redis-cli -h cache ping
PONG
```

Hozircha ikkalasi ham kira oladi: policy yo'q, tarmoq tekis.

4. NetworkPolicy, `netpol.yaml`. Ikki obyekt: namespace bo'yicha default deny ingress va `cache` ga faqat `role: cache-client` dan 6379 portga ruxsat. Egress yopilmaydi, shuning uchun DNS muammosi yo'q:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: deny-ingress, namespace: cache-demo }
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: cache-from-clients, namespace: cache-demo }
spec:
  podSelector: { matchLabels: { app: cache } }
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector: { matchLabels: { role: cache-client } }
      ports:
        - { protocol: TCP, port: 6379 }
```

```
$ kubectl apply -f netpol.yaml
networkpolicy.networking.k8s.io/deny-ingress created
networkpolicy.networking.k8s.io/cache-from-clients created
$ kubectl -n cache-demo exec client-ok -- redis-cli -h cache ping
PONG
$ kubectl -n cache-demo exec client-other -- timeout 5 redis-cli -h cache ping
command terminated with exit code 124
```

- `client-ok` hali ham ishlaydi: ikki policy birlashmasi uning trafigiga ruxsat beradi.
- `client-other`: `redis-cli` ulanishni kutib qoladi, `timeout 5` uni 5 soniyada to'xtatadi. 124 bu `timeout` buyrug'ining "vaqt tugadi" kodi. Javob "connection refused" emas, jimlik: policy paketni tashladi.

5. Label'ni o'zgartirish bilan ruxsat. NetworkPolicy IP emas, label bilan ishlaydi:

```
$ kubectl -n cache-demo label pod client-other role=cache-client
pod/client-other labeled
$ kubectl -n cache-demo exec client-other -- redis-cli -h cache ping
PONG
```

Bir necha soniya ichida CNI qoidani yangiladi. Bu kuch ham, xavf ham: pod'ga label qo'ya oladigan (`pods` ga `patch` huquqi bor) har kim tarmoq ruxsatini ham o'zgartira oladi. RBAC va NetworkPolicy bir-biriga bog'liq.

6. Tozalash: `kubectl delete namespace cache-demo`.

Nima ko'rdik: PSA "noto'g'ri pod" ni eshikdayoq to'xtatdi; `securityContext` real image bilan qanday moslashtirilishini (UID, yoziladigan papka, port); NetworkPolicy'ning qo'shiluvchi mantig'i, timeout ko'rinishidagi blok va label'ga bog'liqlik. Vazifalardagi ilovalar boshqa (nginx, uch qatlamli `web`/`api`/`db`, `team-a`/`team-b`), xato va tuzatishlari ham boshqacha bo'ladi.

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
1. `README.md` da barcha 22 vazifa yozilgan, manifestlar papkada, secret qiymatlari README'da yo'q.
2. `make check` toza (`yamllint`, `shellcheck`, `secrets`).
3. Repo'da ochiq Secret, `age` private key, token va kubeconfig yo'q (`git status` va `git log -p` bilan tekshiring). Shifrlangan `SealedSecret` va SOPS fayllari bo'lishi mumkin.
4. `kind delete cluster --name sec` bajarilgan, `multipass list` da `k3s-sec` yo'q; AWS Secrets Manager ishlatgan bo'lsangiz secret o'chirilgan va o'chirilgani tekshirilgan.
5. Menga "tekshir" deb xabar bering.

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
