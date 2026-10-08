# 9-dars: CI/CD bilan integratsiya

Maqsad: commit'dan klasterdagi yangi Pod'gacha bo'lgan yo'lni avtomatlashtirish. CI/CD modulida pipeline image'ni build qilib registry'ga push qilgan edi (cicd 2-dars, 10-bo'lim) va VM'ga SSH orqali deploy qilgan edi (cicd 5-dars). Kubernetes modulining 3–8-darslarida esa manifestlarni qo'lda `kubectl apply` qildingiz. Bu darsda ikkalasi ulanadi: image'ni commit SHA va digest bilan belgilash, bir nechta muhit uchun Kustomize overlay va o'z Helm chart'ingizni yozish, manifestni klasterga yetmasdan oldin validatsiya qilish, pipeline'ga klasterda eng kam huquq berish va rollout natijasini pipeline holatiga (yashil yoki qizil) bog'lash. Oxirida push-based deploy'ning chegaralari chiqadi, 10-dars (GitOps) aynan shu chegaralarga javob.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–4 bo'limlar va A, B guruhlar; ikkinchi kun 5–8 bo'limlar, "Birga bajaramiz", C va D guruhlar; uchinchi kun 9–10 bo'limlar, E guruh va README. GitHub Actions sintaksisi cicd modulidan tanish, diqqatni quyidagilarga qarating: tag va digest farqi Kubernetes darajasida (Pod template va pull policy), Kustomize va Helm qachon qaysi biri, deploy uchun ServiceAccount'ning aniq RBAC'i, `--dry-run=server` va kubeconform nimani ushlaydi va nimani ushlamaydi, `rollout status` exit code'i.

## Qanday o'qish kerak

Har bo'limdagi misolni vaqtinchalik papkada (`~/k9-scratch`, repo'dan tashqarida) o'zingiz takrorlang va chiqishni darsdagi izoh bilan solishtiring. Digest'lar, pod nomlaridagi tasodifiy qism, port va vaqt sizda boshqacha bo'ladi, bunday joylar `<...>` bilan belgilangan. Asbob chiqishidagi xato matni versiyaga qarab biroz farq qilishi mumkin (ayniqsa kubeconform va Helm), ma'nosi bir xil qoladi. Har bo'limda bitta savolni ushlab turing: "bu qadam zanjirning qaysi bo'g'inini kafolatlaydi va qaysi xatoni o'tkazib yuboradi?" Pipeline qatlamlardan iborat, har qatlam boshqasi ushlay olmaydigan xatoni ushlaydi.

## Laboratoriya

Lokal ish host'dagi alohida kind klasterida: `kind create cluster --name cicd` (bitta node yetarli; 4-darsdagi `dev` klasterini parallel ishlatmang, RAM tejang). Pipeline ichidagi ish GitHub-hosted runner'da: runner sizning noutbukingizdagi kind'ga yeta olmaydi, shuning uchun pipeline o'z ichida vaqtinchalik kind klaster yaratadi (`helm/kind-action`) va deploy'ni shu klasterga qiladi. Bu haqiqiy muhitga deploy'ning barcha qadamlarini (auth, RBAC, rollout gate) takrorlaydi, klaster esa job bilan birga yo'qoladi. Cloud kerak emas.

Ilova: cicd modulidagi o'z repo'ngiz (Dockerfile'i va `/healthz` ga o'xshash HTTP endpoint'i bor har qanday servis). Image GitHub Container Registry'ga (GHCR, `ghcr.io/<user>/<repo>`) push qilinadi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `kind`, `kubectl`, `helm` | 2 va 8-darslarda rasmiy binary (`linux-amd64`) | 2 va 8-darslarda Homebrew (`arm64`) |
| `kustomize` (alohida binary, faqat `edit set image` uchun) | GitHub release'dagi `kustomize_<versiya>_linux_amd64.tar.gz`, `~/.local/bin` ga | `brew install kustomize` |
| `kubeconform` | GitHub release'dagi `kubeconform-linux-amd64.tar.gz`, `~/.local/bin` ga | `brew install kubeconform` |
| kind node'lari | host Docker Engine'ida, `docker ps` da `cicd-control-plane` | Docker Desktop'ning yashirin Linux VM'ida, `docker ps` da xuddi shu nom |
| Lokal build qilingan image | `linux/amd64` | `linux/arm64`. CI runner'da (`amd64`) ishlashi uchun ko'p platformali build kerak (docker 2-dars, 8-bo'lim) |
| GHCR login | `docker login ghcr.io --password-stdin`; credential helper bo'lmasa token `~/.docker/config.json` da base64 ko'rinishida yotadi | xuddi shu buyruq, token macOS Keychain'da saqlanadi |
| CI'da yaratilgan image'ni lokal kind'da ishlatish | to'g'ridan ishlaydi (ikkalasi `amd64`) | faqat image ko'p platformali bo'lsa; aks holda Pod `exec format error` bilan qulaydi |

GHCR uchun `write:packages` huquqli classic personal access token kerak (docker 2-dars). Token faqat `docker login --password-stdin` ga va klasterdagi Secret'ga beriladi, faylga yozilmaydi va commit qilinmaydi.

```
$ kind create cluster --name cicd
Creating cluster "cicd" ...
 ✓ Ensuring node image (kindest/node:v1.<..>) 🖼
 ✓ Preparing nodes 📦
 ...
Set kubectl context to "kind-cicd"
$ kubectl config current-context
kind-cicd
```

- **Ikkinchi mashinada tiklash**: klaster holati git orqali ko'chmaydi. Manifestlar, chart va workflow git'da. Boshqa mashinada `kind create cluster --name cicd`, keyin kerakli namespace va manifestlarni qayta `apply` qiling. GHCR'ga login va pull Secret'ini har mashinada alohida yarating (token ko'chmaydi). CI qismi mashinaga bog'liq emas: u GitHub'da ishlaydi.
- **Maxfiy fayllar**: deployer kubeconfig'i, token fayli va CA sertifikati ish papkasiga tushsa ularni `.gitignore` ga qo'shing. Yaxshisi ularni umuman `~/k9-scratch` da saqlang.
- **Tozalash**: `kind delete cluster --name cicd`; GHCR'dagi sinov package'lari kerak bo'lmasa GitHub'dagi package sozlamalaridan o'chiriladi.

---

## 1. Commit'dan Pod'gacha: zanjir

### Bu nima

Deploy zanjiri bu kod o'zgarishi klasterdagi ishlayotgan Pod'ga aylanguncha bosib o'tadigan qadamlar ketma-ketligi. Frontend'da Vercel yoki Netlify buni bitta tugma qilib berardi: merge qildingiz, sayt yangilandi. Kubernetes'da har bo'g'inni o'zingiz yig'asiz.

```
git push -> CI: test -> build image -> push registry (digest)
         -> render manifests (Kustomize/Helm) -> validate
         -> deploy (kubectl/helm) -> rollout status -> smoke test
```

### Mexanizm

Har bo'g'in bitta savolga javob beradi va keyingisiga bitta identifikator uzatadi:

| Bo'g'in | Savol | Identifikator |
|---------|-------|---------------|
| Commit | qaysi kod? | commit SHA (git 1-dars) |
| Build va push | qaysi artefakt? | image digest |
| Render | qaysi konfiguratsiya? | render qilingan manifest (git'dagi fayl + muhit qiymatlari) |
| Deploy | kim, qachon? | pipeline identifikatsiyasi (ServiceAccount yoki OIDC subject) |
| Rollout | muvaffaqiyatli bo'ldimi? | `rollout status` exit code'i |

Bo'g'inlardan biri noaniq bo'lsa, "production'da hozir aynan nima ishlayapti" savoliga javob yo'qoladi. Masalan image `latest` tag bilan deploy qilinsa, 2-bo'g'indagi identifikator yo'q: qaysi commit'dan qurilgani noma'lum.

Bu cicd 1-darsdagi "build once, deploy many" tamoyilining Kubernetes'dagi ko'rinishi: image bir marta quriladi, keyin dev, staging, prod faqat manifest farqi bilan bir xil digest'ni oladi.

### Misol

Klasterdagi istalgan Pod uchun zanjirni teskari tomondan tiklash mumkin: Pod qaysi image va qaysi digest'ni ishlatyapti.

```
$ kubectl -n kube-system get pod -l k8s-app=kube-dns \
    -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}{.items[0].status.containerStatuses[0].imageID}{"\n"}'
registry.k8s.io/coredns/coredns:v1.<..>
sha256:<..>
```

Birinchi qator `spec` dan: manifestda nima so'ralgan (tag). Ikkinchisi `status` dan: kubelet haqiqatda qaysi image'ni ishga tushirgan. kind node image'ida oldindan yuklangan image'lar uchun bu faqat lokal ID bo'ladi; registry'dan tortilgan image'da `ghcr.io/<user>/<repo>@sha256:<..>` ko'rinishida registry digest'i chiqadi (2-bo'limda ko'rasiz). Pipeline to'g'ri ishlasa, shu digest'dan commit SHA'gacha teskari yo'l bor.

### Real ishda qachon kerak

- Incident paytida birinchi savol: "oxirgi deploy'da nima o'zgardi?" Javob shu zanjirdan olinadi.
- Audit va compliance: production'dagi har image qaysi commit va qaysi pipeline run'dan kelganini ko'rsatish.

### Nima uchun shunday

Kubernetes zanjirning faqat oxirgi qismini (manifestdan Pod'gacha) biladi, oldingi qismlar sizning pipeline'ingizda. Shuning uchun identifikatorlarni bog'lash sizning vazifangiz: Kubernetes image qaysi commit'dan ekanini bilmaydi. Muqobili, qo'lda deploy, kichik loyihada ishlaydi, lekin "kim nimani qachon qo'ydi" degan izni qoldirmaydi.

## 2. Image tag va digest Kubernetes'da

### Bu nima

Tag (`app:1.4.2`) registry'dagi ko'rsatkich, uni istalgan payt boshqa image'ga ko'chirish mumkin. Digest (`app@sha256:9b1e...`) image manifestining SHA-256 hash'i (docker 2-dars, 3-bo'lim): bitta bayt o'zgarsa digest o'zgaradi.

| Belgi | Misol | O'zgaruvchanmi | Qachon |
|-------|-------|----------------|--------|
| `latest` | `app:latest` | ha | hech qachon deploy uchun |
| semver | `app:1.4.2` | ha (qayta push mumkin) | release'lar, odam o'qishi uchun |
| commit SHA | `app:3f2c1ab` | kelishuv bo'yicha yo'q | har commit, kodga izlanadi |
| digest | `app@sha256:9b1e...` | yo'q (kontent hash) | production manifest |

### Mexanizm: ikki narsa tag'ga tayanadi

**Pod template.** Deployment controller (4-dars, 7-bo'lim) yangi ReplicaSet faqat Pod template o'zgarganda yaratadi. Template ichida `image:` satri bor. Siz bir xil tag'ni qayta push qilsangiz satr o'zgarmaydi, demak `kubectl apply` "unchanged" deydi va rollout bo'lmaydi.

**`imagePullPolicy`.** Bu maydon kubelet image'ni registry'dan qachon qayta so'rashini belgilaydi. Default: tag `latest` yoki tag yo'q bo'lsa `Always`, boshqa har qanday tag yoki digest bo'lsa `IfNotPresent` (node'da shu nomli image bo'lsa tortmaydi). Natija: qayta push qilingan `:1.4.2` node cache'idagi eski image'ni almashtirmaydi. Yangi node qo'shilsa u yangisini tortadi, eski node'lar eskisida qoladi: bitta ReplicaSet ichida ikki xil kod.

Digest bilan ikkalasi ham hal bo'ladi: har yangi build yangi digest, demak yangi template va yangi rollout; node digest bo'yicha tortgani uchun hamma joyda bir xil baytlar.

### Private registry va `imagePullSecrets`

GHCR'da yangi package standart holatda private (cicd 2-dars). Klaster uni tortish uchun registry credential'iga muhtoj: `kubernetes.io/dockerconfigjson` tipidagi Secret va Pod'da (yoki ServiceAccount'da) `imagePullSecrets` havolasi. Credential bo'lmasa kubelet `401 Unauthorized` oladi, Pod `ErrImagePull`, keyin `ImagePullBackOff` holatiga o'tadi (3-dars, 8-bo'lim).

```
$ read -rs GHCR_TOKEN          # token is typed, not echoed, not in history
$ kubectl -n demo create secret docker-registry ghcr-pull \
    --docker-server=ghcr.io --docker-username=<user> --docker-password="$GHCR_TOKEN"
secret/ghcr-pull created
$ unset GHCR_TOKEN
```

`read -rs` bash'da ham, zsh'da ham ishlaydi: kiritilgan matn ekranga chiqmaydi va shell tarixiga tushmaydi. Token'ga qaysi minimal scope yetarli ekanini 4-vazifada o'zingiz aniqlaysiz.

### Misol

Bir xil tag, ikki xil manba. `nginx:1.28` ni digest bilan almashtiramiz:

```
$ kubectl create namespace demo
namespace/demo created
$ kubectl -n demo create deployment web --image=nginx:1.28
deployment.apps/web created
$ docker buildx imagetools inspect nginx:1.28 | head -3
Name:      docker.io/library/nginx:1.28
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:<D>
$ kubectl -n demo set image deployment/web nginx=nginx@sha256:<D>
deployment.apps/web image updated
$ kubectl -n demo rollout history deployment/web
deployment.apps/web
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

`imagetools inspect` registry'dan faqat manifestni o'qiydi, hech narsa tortmaydi. `MediaType` da `image.index` bu ko'p platformali index ekanini aytadi, `Digest` index'ning digest'i: Zorin'da ham, Mac'da ham bir xil, node o'z arxitekturasini o'zi tanlaydi. `set image` template'dagi satrni o'zgartirdi, shuning uchun `rollout history` da ikkinchi revision paydo bo'ldi, garchi baytlar aynan o'sha bo'lsa ham. Teskari tajriba (tag o'zgarmay, baytlar o'zgarsa) 2-vazifada.

### Real ishda qachon kerak

- Pipeline build qadamidan digest olib, uni manifestga yozadi. `docker/build-push-action` buni `digest` output sifatida beradi:

```yaml
- id: build
  uses: docker/build-push-action@v<N>
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
- run: echo "Pushed ${{ steps.build.outputs.digest }}"
```

- Action'lar xavfsizlik uchun tag emas, commit SHA bilan pin qilinadi (cicd 2-dars, 3-bo'lim). `v<N>` o'rniga action sahifasidagi joriy versiyani qo'ying.
- `GITHUB_TOKEN` bilan GHCR'ga push uchun job'ga `packages: write` kerak (cicd 2-dars, 8-bo'lim).

### Nima uchun shunday

Tag odam uchun, digest mashina uchun. Registry tag'ni o'zgaruvchan qilib yaratgan, chunki `nginx:1.28` ostida xavfsizlik patch'lari chiqib turishi kerak. Kubernetes esa `imagePullPolicy` default'larini tarmoq va registry yukini kamaytirish uchun shunday tanlagan: har Pod start'ida registry'ga borish qimmat. Ikkala qaror alohida to'g'ri, birgalikda esa o'zgaruvchan tag bilan deploy'ni ishonchsiz qiladi. Frontend'dagi o'xshashlik haqiqiy: `package.json` dagi `^1.4.0` tag'ga o'xshaydi, `package-lock.json` dagi `integrity` hash'i esa digest'ga.

## 3. Muhitlar uchun manifest: Kustomize

### Bu nima

Kustomize bu oddiy YAML manifestlar ustiga o'zgarish (patch) qo'yib, har muhit uchun yakuniy manifest chiqaradigan asbob. U `kubectl` ichiga o'rnatilgan (`kubectl kustomize`, `kubectl apply -k`), template tili yo'q: base fayllar o'zi to'g'ri Kubernetes YAML.

Dev, staging va prod manifestlari 90% bir xil: farq replica soni, image, resurslar, namespace. Nusxa ko'chirish drift'ga (nusxalar vaqt o'tishi bilan bir-biridan ajralib ketishi) olib keladi.

### Mexanizm

```
deploy/
  base/            deployment.yaml service.yaml kustomization.yaml
  overlays/
    dev/           kustomization.yaml
    prod/          kustomization.yaml resources-patch.yaml
```

`kustomization.yaml` har papkaning "kirish nuqtasi": qaysi fayllar va qaysi o'zgarishlar. Overlay base'ni `resources` orqali chaqiradi, ustiga o'zinikini qo'yadi. Kustomize hammasini xotirada yig'ib, natijani stdout'ga chiqaradi; diskdagi fayllarni o'zgartirmaydi.

| Kalit | Vazifasi |
|-------|----------|
| `resources` | base yoki fayllar ro'yxati |
| `namespace`, `namePrefix`, `labels` | hamma resursga bir xil o'zgarish |
| `images` | image nomi, `newName`, `newTag` yoki `digest` almashtirish |
| `replicas` | Deployment replica sonini almashtirish |
| `patches` | strategic merge yoki JSON 6902 patch |
| `configMapGenerator`, `secretGenerator` | fayl yoki literal'dan ConfigMap/Secret, nomiga kontent hash qo'shiladi |

`configMapGenerator` ning hash suffiksi muhim mexanizm: ConfigMap kontenti o'zgarsa nomi o'zgaradi (`app-config-<hash>`), Kustomize Deployment'dagi havolani ham yangi nomga almashtiradi, Pod template o'zgaradi va rollout boshlanadi. Oddiy ConfigMap'ni o'zgartirish env orqali ishlatilgan qiymatni Pod'larga yetkazmaydi (4-dars, 10-bo'lim). Buni 6-vazifada o'zingiz solishtirasiz.

### Misol

Vazifadagidan boshqa misol: `nginx` uchun bitta `staging` overlay.

```
$ cat overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: staging
resources:
  - ../../base
images:
  - name: nginx
    newTag: "1.28"
replicas:
  - name: web
    count: 2
$ kubectl kustomize overlays/staging | grep -E '^kind:|namespace:|replicas:|image:'
kind: Service
  namespace: staging
kind: Deployment
  namespace: staging
  replicas: 2
        image: nginx:1.28
```

Natija qatorma-qator: Service birinchi chiqdi, chunki Kustomize resurslarni turi bo'yicha tartiblaydi (Namespace, ConfigMap, Service kabi bog'liqliklar Deployment'dan oldin). Ikkala resursga `namespace: staging` qo'shildi, garchi base'da namespace yo'q edi. `replicas: 2` base'dagi qiymatni almashtirdi. `images` bo'limi base'dagi `nginx` nomli har qanday image satrini topib tag'ini almashtirdi: qaysi konteynerda ekanini bilish shart emas.

CI'da image'ni almashtirish uchun alohida `kustomize` binary'sining buyrug'i ishlatiladi, u `kustomization.yaml` ning `images` bo'limini joyida yozadi:

```
$ kustomize edit set image ghcr.io/<user>/<repo>@sha256:<digest>
```

### Real ishda qachon kerak

- O'z ilovangiz va 2–4 ta muhit: Kustomize eng kam murakkablik bilan ishlaydi.
- Begona chart'ni (8-dars) render qilib, ustiga o'z patch'ingizni qo'yish kerak bo'lganda ham Kustomize ishlatiladi.
- `kubectl kustomize` natijasini PR'da `diff` qilish "prod'da aynan nima o'zgaradi" savoliga javob beradi.

### Nima uchun shunday

Kustomize "template'siz" g'oyasidan chiqqan: base fayl o'zi yaroqli manifest bo'lsa, uni `kubectl apply -f` bilan ham ishlatish, schema bilan tekshirish va IDE'da avtoto'ldirish mumkin. Template tilli yondashuvda (Helm) base fayl render qilinmaguncha YAML ham emas. Narxi: Kustomize'da shart va sikl yo'q, "agar prod bo'lsa sidecar qo'sh" kabi mantiqni faqat patch bilan ifodalaysiz.

## 4. Ilova uchun Helm chart

### Bu nima

8-darsda tayyor chart'larni (Traefik, cert-manager) o'rnatdingiz. Endi o'zingiznikini yozasiz. Chart bu Go template'li manifestlar, default qiymatlar (`values.yaml`) va metadata (`Chart.yaml`) to'plami; release esa chart'ning klasterga ma'lum qiymatlar bilan o'rnatilgan nusxasi (8-dars).

### Mexanizm

`helm create app` skelet beradi:

```
app/
  Chart.yaml        # apiVersion: v2, name, version (chart), appVersion (app)
  values.yaml       # default values
  templates/        # deployment.yaml, service.yaml, _helpers.tpl, NOTES.txt and more
  .helmignore
```

Skeletda sizga kerak bo'lmagan narsalar ko'p (Ingress, HPA, ServiceAccount, test Pod'i), ularni o'chirish 7-vazifaning bir qismi.

```yaml
# templates/deployment.yaml (fragment)
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

- `{{ ... }}` Go template ifodasi, `.Values` values fayllaridan yig'ilgan obyekt.
- `toYaml` obyektni YAML matnga aylantiradi, `nindent 12` boshiga yangi qator qo'yib har qatorni 12 bo'sh joyga suradi. `{{-` chap tomondagi bo'sh joy va qator ko'chishini o'chiradi.
- `version` chart'ning versiyasi, `appVersion` ilovaniki. Ikkalasi mustaqil o'zgaradi: template tuzatilsa `version` oshadi, ilova kodi o'zgarsa `appVersion`.
- Qiymat ustunligi: `values.yaml` < `-f values-prod.yaml` < `--set key=value`.

Asosiy buyruqlar:

| Buyruq | Nima qiladi |
|--------|-------------|
| `helm lint ./app` | chart tuzilishi va template sintaksisini tekshiradi |
| `helm template rel ./app -f values-prod.yaml` | klastersiz to'liq render, CI'da validatsiyaga kirish |
| `helm upgrade --install rel ./app -n ns -f values-prod.yaml` | release yo'q bo'lsa o'rnatadi, bor bo'lsa yangilaydi |
| `helm history rel -n ns` | revision'lar tarixi (8-dars) |
| `helm rollback rel <revision> -n ns` | oldingi revision'ga qaytish |

Resurslar tayyor bo'lguncha kutish `--wait` va `--timeout`, muvaffaqiyatsiz bo'lsa avtomatik orqaga qaytarish flag'i Helm 3'da `--atomic`, Helm 4'da `--rollback-on-failure`. 8-darsda Helm 4 o'rnatgansiz; flag'larning aniq ko'rinishini `helm upgrade --help` dan tekshiring.

### Misol

```
$ helm create demo
Creating demo
$ helm lint ./demo
==> Linting ./demo
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
$ helm template rel ./demo --set replicaCount=3 | grep -E '^# Source|replicas:'
# Source: demo/templates/serviceaccount.yaml
# Source: demo/templates/service.yaml
# Source: demo/templates/deployment.yaml
  replicas: 3
# Source: demo/templates/tests/test-connection.yaml
```

`helm lint` faqat `[INFO]` darajadagi tavsiya berdi (ikonka yo'q), xato yo'q. `helm template` klasterga umuman murojaat qilmadi: har manifest oldida `# Source:` izohi qaysi template fayldan chiqqanini aytadi, bu xatoni topishda kerak. `--set replicaCount=3` default qiymatni bosib o'tdi. Skelet chart nimalar yaratishini shu ro'yxatdan ko'rasiz (Helm versiyasiga qarab ro'yxat biroz farq qiladi).

### Kustomize yoki Helm

| | Kustomize | Helm |
|---|-----------|------|
| Model | YAML ustiga patch | template + values |
| O'rganish | past | template tili, helper'lar |
| Tarqatish | git papka | versiyalangan paket (OCI registry) |
| Release tarixi, rollback | yo'q | bor (namespace'dagi Secret'larda) |
| Qachon | o'z ilovangiz, bir necha muhit | boshqalarga beriladigan yoki ko'p parametrli ilova |

### Real ishda qachon kerak

- Ilovani boshqa jamoalar o'rnatadigan bo'lsa (ichki platforma, open source) Helm amalda standart.
- Helm release tarixi va `rollback` pipeline'da avtomatik qaytarish uchun qulay (20-vazifa).

### Nima uchun shunday

Helm Kubernetes uchun "paket menejer" sifatida yaratilgan (apt yoki npm kabi): versiya, bog'liqlik, o'rnatish va olib tashlash. Template tili shu maqsadga xizmat qiladi: bitta chart minglab har xil o'rnatishga moslanadi. Narxi: render qilinmaguncha xatoni ko'rmaysiz, va YAML ichidagi matn template'i indentatsiya xatosiga moyil. Shuning uchun Helm'da `helm template` natijasini o'qish va validatsiyadan o'tkazish majburiy odat.

## 5. CI'da validatsiya

### Bu nima

Validatsiya manifestni klasterga qo'llashdan oldin tekshirish. Xato qanchalik erta ushlansa shuncha arzon: PR'da qizil check, production'dagi buzilgan rollout'dan ko'ra ancha arzon.

### Mexanizm: qatlamlar

| Tekshiruv | Klaster kerakmi | Nimani ushlaydi | Nimani ushlamaydi |
|-----------|-----------------|-----------------|-------------------|
| `helm lint`, `kubectl kustomize` | yo'q | render xatosi | noto'g'ri maydon nomi |
| `kubeconform -strict` | yo'q | schema: noma'lum maydon, noto'g'ri tip, versiyada yo'q `apiVersion` | admission, quota, mavjud obyekt bilan ziddiyat |
| `kubectl apply --dry-run=client` | yo'q | YAML sintaksisi, obyekt tuzilishi | ko'p narsa, schema'ni to'liq tekshirmaydi |
| `kubectl apply --dry-run=server` | ha | API server validatsiyasi, admission, immutable maydonlar, RBAC | image mavjudmi, Pod ishga tushadimi |
| `kubectl diff` | ha | klasterdagi holat bilan farq (exit code 1 = farq bor) | to'g'ri yoki noto'g'riligini emas |

**kubeconform** bu manifestni Kubernetes OpenAPI'dan olingan JSON schema'larga solishtiradigan asbob. Klaster kerak emas, schema'larni internetdan (yoki lokal katalogdan) oladi.

- `-strict` schema'da yo'q maydonni xato deb oladi. Usiz typo maydon jim o'tib ketadi, chunki Kubernetes schema'lari standart holatda qo'shimcha maydonlarga ruxsat beradi.
- `-kubernetes-version` maqsad klaster versiyasiga qo'yiladi: upgrade'dan oldin o'chirilgan API'larni shu yerda ushlaysiz (ro'yxat: Deprecated API Migration Guide, Manbalar'da).
- CRD'lar (cert-manager `Certificate`, Argo CD `Application`) default schema'larda yo'q. `-ignore-missing-schemas` ularni o'tkazib yuboradi, `-schema-location` bilan CRD katalogi ulanadi.

**`--dry-run=server`** so'rovni API server'ga to'liq yuboradi: autentifikatsiya, RBAC, validatsiya, mutating va validating admission (1-dars, 3-bo'lim), faqat etcd'ga yozmaydi. Shuning uchun u namespace mavjudligini, huquqni va Pod Security admission (13-dars) rad etishini ham ko'rsatadi. `--dry-run=client` esa API server'ga bormaydi.

### Misol

Vazifadagidan boshqa holat: NodePort Service'da ruxsat etilmagan port.

```
$ cat bad-svc.yaml
apiVersion: v1
kind: Service
metadata: {name: web, namespace: demo}
spec:
  type: NodePort
  selector: {app: web}
  ports: [{port: 80, nodePort: 40000}]
$ kubeconform -strict -summary bad-svc.yaml
Summary: 1 resource found in 1 file - Valid: 1, Invalid: 0, Errors: 0, Skipped: 0
$ kubectl apply -f bad-svc.yaml --dry-run=client
service/web created (dry run)
$ kubectl apply -f bad-svc.yaml --dry-run=server
The Service "web" is invalid: spec.ports[0].nodePort: Invalid value: 40000: provided port is not in the valid range. The range of valid ports is 30000-32767
$ echo $?
1
```

kubeconform `Valid: 1` dedi: schema uchun `nodePort` shunchaki butun son, diapazon schema'da yo'q. Client dry-run ham `created (dry run)` dedi, u API server'ga bormadi. Faqat server dry-run haqiqiy validatsiyani ishga tushirdi: diapazon (30000–32767) API server sozlamasi, uni faqat server biladi. Exit code 1, pipeline shu yerda to'xtaydi. Klasterda hech narsa yaratilmadi.

`kubectl diff` ning chiqishi oddiy unified diff, exit code'i esa gate uchun ishlatiladi:

```
$ kubectl -n demo diff -f web.yaml
diff -u -N /tmp/LIVE-<..>/apps.v1.Deployment.demo.web /tmp/MERGED-<..>/apps.v1.Deployment.demo.web
--- /tmp/LIVE-<..>/apps.v1.Deployment.demo.web	<..>
+++ /tmp/MERGED-<..>/apps.v1.Deployment.demo.web	<..>
@@ -6,7 +6,7 @@
-  generation: 2
+  generation: 3
...
-        image: nginx:1.28
+        image: nginx:1.29
$ echo $?
1
```

`LIVE` klasterdagi joriy obyekt, `MERGED` siz qo'llasangiz bo'ladigan holat (server dry-run natijasi). `generation` ham o'zgaradi, chunki spec o'zgaryapti. Exit code 0 farq yo'q, 1 farq bor, 1 dan katta esa xato degani.

### Real ishda qachon kerak

- PR'da: render, kubeconform, server dry-run (vaqtinchalik klasterga). Bu 17-vazifa.
- Klaster upgrade'idan oldin: barcha manifestlarni yangi `-kubernetes-version` bilan kubeconform'dan o'tkazish.
- `kubectl diff` natijasini PR kommentiga qo'yish reviewer'ga "aynan nima o'zgaradi" ni ko'rsatadi.

### Nima uchun shunday

Har qatlam boshqa manbaga tayanadi: kubeconform statik schema'ga, server dry-run jonli klaster sozlamasiga. Statik tekshiruv tez va klastersiz, lekin klasterga xos qoidalarni (admission webhook, port diapazoni, quota) bilmaydi. Server dry-run hammasini biladi, lekin klaster va huquq talab qiladi. Shuning uchun ikkalasi birga ishlatiladi. Bu frontend'dagi `tsc` (statik tekshiruv) va integratsion test (haqiqiy muhit) bo'linishiga o'xshaydi.

## 6. Pipeline klasterga qanday kiradi

### Bu nima

Pipeline klasterga yozishi uchun API server'ga o'zini tanitishi kerak (autentifikatsiya) va keyin huquqqa ega bo'lishi kerak (avtorizatsiya, RBAC, 7-bo'lim). Ikki asosiy yo'l: ServiceAccount token va OIDC.

### Mexanizm: ServiceAccount token

ServiceAccount bu odam emas, dastur uchun Kubernetes identifikatsiyasi; u namespace ichida yashaydi va to'liq nomi `system:serviceaccount:<namespace>:<name>`.

- `kubectl create token <sa> -n <ns> --duration=1h` TokenRequest API orqali qisqa muddatli, imzolangan JWT (JSON Web Token: imzolangan va muddati yozilgan matn) beradi. Token hech qayerda saqlanmaydi, muddati tugashi bilan yaroqsiz.
- Muddatsiz token faqat `kubernetes.io/service-account-token` tipidagi Secret'ni qo'lda yaratib olinadi; 1.24 dan beri avtomatik yaratilmaydi.

Kubeconfig (1-dars) uch qismdan yig'iladi:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: target
    cluster: {server: "https://<api-server>", certificate-authority-data: "<base64 CA>"}
users:
  - name: ci-bot
    user: {token: "<jwt>"}
contexts:
  - name: ci
    context: {cluster: target, user: ci-bot, namespace: <ns>}
current-context: ci
```

Faylni qo'lda yozish shart emas: `kubectl config set-cluster`, `set-credentials --token`, `set-context`, `use-context` buyruqlari `--kubeconfig=<fayl>` flag'i bilan alohida faylga yozadi. kind'da server manzili `https://127.0.0.1:<port>`, CA esa joriy kubeconfig'ingizda bor (`kubectl config view --raw --minify`). 14-vazifada shuni noldan yig'asiz.

Kamchilik: token CI secret'ida yashaydi. Qisqa muddatli bo'lsa har run'dan oldin kimdir uni yangilashi kerak, uzoq muddatli bo'lsa sizib chiqqanda muddati tugaguncha amal qiladi.

### Mexanizm: OIDC (secret'siz)

cicd 5-darsda (8-bo'lim) GitHub Actions'dan AWS'ga OIDC bilan kirdingiz. Mexanizm bir xil: job `permissions: id-token: write` bilan GitHub'dan imzolangan JWT oladi. Issuer `https://token.actions.githubusercontent.com`, `sub` claim'i `repo:<owner>/<repo>:ref:refs/heads/main` yoki `repo:<owner>/<repo>:environment:prod` ko'rinishida. Ikki yo'l:

- **Cloud orqali**: AWS'da IAM role shu OIDC provider'ga ishonadi, `aws-actions/configure-aws-credentials` vaqtinchalik credential oladi, `aws eks update-kubeconfig` kubeconfig yozadi, EKS access entry esa IAM role'ni Kubernetes guruhi yoki policy'siga bog'laydi.
- **To'g'ridan-to'g'ri API server'ga**: kube-apiserver `--authentication-config` faylidagi `AuthenticationConfiguration` (`apiserver.config.k8s.io/v1`) orqali tashqi JWT issuer'ga ishonadi. Token claim'lari username va guruhga map qilinadi, keyin oddiy RBAC.

Ikkalasida ham saqlanadigan secret yo'q, token bir necha daqiqa yashaydi va faqat aniq repo, branch yoki environment uchun beriladi.

### Misol

```
$ kubectl -n demo create serviceaccount viewer
serviceaccount/viewer created
$ kubectl -n demo create token viewer --duration=10m
eyJhbGciOiJSUzI1NiIsImtpZCI6Ij<..>
$ kubectl -n demo get pods --as=system:serviceaccount:demo:viewer
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:demo:viewer" cannot list resource "pods" in API group "" in the namespace "demo"
```

Ikkinchi buyruq uch qismli (nuqta bilan ajratilgan) JWT chiqardi; uni hech qayerga yozmang. Uchinchi buyruq `--as` (impersonation: admin sifatida boshqa identifikatsiya nomidan so'rov) bilan ServiceAccount nomidan so'radi. Xato xabari qatorma-qator: kim (`User "system:serviceaccount:demo:viewer"`), qaysi amal (`list`), qaysi resurs va API guruhi (`pods`, `""` ya'ni core guruh), qayerda (`namespace "demo"`). Autentifikatsiya o'tdi, avtorizatsiya rad etdi: yangi ServiceAccount'ning hech qanday huquqi yo'q. Bu xabar 13-vazifada sizning asosiy qurolingiz.

### Real ishda qachon kerak

- Cloud'dagi managed klasterga (EKS, GKE, AKS) deploy: OIDC standart yo'l.
- O'z klasteringiz yoki on-prem: ko'pincha ServiceAccount token, yaxshisi self-hosted runner klaster ichida (cicd 2-dars, 12-bo'lim).

### Nima uchun shunday

Kubernetes odamlar uchun o'z user bazasini saqlamaydi: autentifikatsiya tashqariga (sertifikat, OIDC, cloud IAM) berilgan, faqat ServiceAccount'lar ichki. 1.24 dagi o'zgarish (muddatsiz token'larni avtomatik yaratmaslik) sizib chiqqan eski token'lar muammosiga javob edi. OIDC esa cicd 2-darsdagi tamoyilni davom ettiradi: eng yaxshi secret bu mavjud bo'lmagan secret.

## 7. Least-privilege RBAC

### Bu nima

RBAC (Role-Based Access Control) Kubernetes'ning avtorizatsiya modeli: kim (subject) qaysi resursda (resource) qaysi amalni (verb) bajara oladi. Least privilege (eng kam huquq) esa identifikatsiyaga faqat ishi uchun shart bo'lgan huquqni berish tamoyili. RBAC chuqur 13-darsda; bu yerda faqat deploy uchun kerakli qism.

### Mexanizm

To'rt obyekt:

| Obyekt | Doirasi | Nima |
|--------|---------|------|
| Role | namespace | qoidalar ro'yxati: `apiGroups`, `resources`, `verbs` |
| RoleBinding | namespace | Role'ni subject'ga (user, group, ServiceAccount) bog'laydi |
| ClusterRole | butun klaster | Role kabi, lekin namespace'siz resurslar ham |
| ClusterRoleBinding | butun klaster | ClusterRole'ni butun klaster bo'yicha bog'laydi |

RBAC faqat ruxsat beradi, taqiqlovchi qoida yo'q: hech bir qoida mos kelmasa so'rov rad etiladi. Verb'lar HTTP amallariga mos: `get` (bitta obyekt), `list` va `watch` (ro'yxat va o'zgarishlar oqimi), `create`, `update`, `patch`, `delete`.

Deploy identifikatsiyasi uchun tamoyil: faqat o'z namespace'ida (Role, ClusterRole emas), faqat o'zi boshqaradigan resurs turlariga, faqat kerakli verb'lar. Qaysi verb kerakligini taxmin qilmang: eng kamdan boshlang va har `Forbidden` xabari nima so'raganini qo'shing (13-vazifa).

Ba'zi huquqlar ko'rinishidan kichik, amalda katta:

- `secrets` ni o'qish: namespace'dagi barcha parol va token'lar.
- `pods/exec`: istalgan Pod ichida buyruq, demak Pod'ning ServiceAccount token'i va mount qilingan Secret'lar.
- `rolebindings` yaratish yoki `roles` ni o'zgartirish: o'ziga huquq qo'shish yo'li.
- `*` verb yoki resurs: kelajakda qo'shiladigan narsalar ham.
- Helm release tarixini Secret'larda saqlaydi, demak Helm bilan deploy qiladigan identifikatsiyaga `secrets` ga yozish kerak bo'ladi (20-vazifada ko'rasiz).

### Misol

6-bo'limdagi `viewer` ga faqat Pod'larni o'qish huquqi:

```
$ kubectl -n demo create role pod-reader --verb=get,list,watch --resource=pods
role.rbac.authorization.k8s.io/pod-reader created
$ kubectl -n demo create rolebinding viewer-pod-reader --role=pod-reader --serviceaccount=demo:viewer
rolebinding.rbac.authorization.k8s.io/viewer-pod-reader created
$ kubectl -n demo auth can-i list pods --as=system:serviceaccount:demo:viewer
yes
$ kubectl -n demo auth can-i delete pods --as=system:serviceaccount:demo:viewer
no
$ kubectl -n kube-system auth can-i list pods --as=system:serviceaccount:demo:viewer
no
$ kubectl -n demo auth can-i --list --as=system:serviceaccount:demo:viewer
Resources                                       Non-Resource URLs   Resource Names   Verbs
selfsubjectreviews.authentication.k8s.io        []                  []               [create]
selfsubjectaccessreviews.authorization.k8s.io   []                  []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                  []               [create]
pods                                            []                  []               [get list watch]
                                                [/api/*]            []               [get]
...
```

Imperativ `create role` va `create rolebinding` tez sinov uchun; deploy uchun Role'ni YAML qilib git'da saqlang. `can-i` uch savolga uch javob: o'z namespace'ida o'qish mumkin, o'chirish mumkin emas, boshqa namespace'da hech narsa mumkin emas (Role namespace bilan chegaralangan). `--list` ning yuqori qatorlari har autentifikatsiyalangan identifikatsiyaga berilgan standart huquqlar (o'z huquqini so'rash), `pods` qatori bizning Role'dan. `Non-Resource URLs` ustuni API server'ning resurs bo'lmagan yo'llari (`/healthz`, `/version` kabi). Tozalash: `kubectl -n demo delete rolebinding viewer-pod-reader; kubectl -n demo delete role pod-reader`.

### Real ishda qachon kerak

- Har pipeline va har klaster ichidagi agent (Argo CD, 10-dars) uchun alohida ServiceAccount va alohida Role.
- Xavfsizlik auditida birinchi so'raladigan narsa: "CI qaysi huquq bilan kiradi?" `cluster-admin` javobi auditdan o'tmaydi.

### Nima uchun shunday

Pipeline'ga `cluster-admin` berish eng ko'p uchraydigan xato, chunki u "darhol ishlaydi". Lekin pipeline eng ko'p hujumga ochiq tizimlardan biri: har PR, har action, har bog'liqlik uning ichida kod bajaradi (cicd 2-dars, 8-bo'lim). Faqat ruxsat beruvchi (deny'siz) model tanlangan, chunki uni o'qish va audit qilish oson: kimga nima berilgani ro'yxatdan ko'rinadi, qoidalar orasidagi ustunlik muammosi yo'q.

## 8. Rollout gate

### Bu nima

Rollout gate bu pipeline'ni Deployment haqiqatan yangilanib bo'lguncha kutdiradigan va muvaffaqiyatsizlikda qizil qiladigan qadam. `kubectl apply` muvaffaqiyati faqat "API server obyektni qabul qildi" degani; Pod'lar ishga tushdimi va readiness probe o'tdimi, bu alohida savol.

### Mexanizm

`kubectl rollout status` Deployment'ning `status` maydonlarini watch qiladi: `updatedReplicas`, `readyReplicas`, `availableReplicas` va `observedGeneration`. Yangi ReplicaSet'ning barcha Pod'lari ready bo'lib, eskilari o'chirilganda u exit code 0 bilan chiqadi.

- `--timeout` tugasa yoki Deployment `progressDeadlineSeconds` (default 600 soniya, 4-dars) dan oshib `Progressing=False` bo'lsa, exit code noldan farqli. Pipeline shu yerda qizil bo'ladi.
- Gate'ning sifati readiness probe sifatiga teng (4-dars, 4-bo'lim). Probe yo'q bo'lsa konteyner start bo'lishi bilan "ready", gate har doim yashil.
- Muvaffaqiyatsiz rollout o'zi orqaga qaytmaydi: eski ReplicaSet'ning Pod'lari `maxUnavailable` chegarasi tufayli ishlab turadi, yangilari `CrashLoopBackOff` yoki `0/1 Running` da qoladi. Qaytarish pipeline'ning ishi: `kubectl rollout undo` yoki Helm'ning avtomatik rollback flag'i.
- Gate'dan keyin smoke test (cicd 5-dars, 4-bo'lim): Service orqali haqiqiy so'rov. Rollout status faqat probe'ni ko'radi, biznes mantiqni emas.

### Misol

2-bo'limdagi `web` Deployment'ida yangi versiya:

```
$ kubectl -n demo set image deployment/web nginx=nginx:1.29
deployment.apps/web image updated
$ kubectl -n demo rollout status deployment/web --timeout=120s
Waiting for deployment "web" rollout to finish: 0 of 1 updated replicas are available...
deployment "web" successfully rolled out
$ echo $?
0
```

Birinchi qator: yangi ReplicaSet yaratildi, uning Pod'i hali available emas. Ikkinchi qator: yangi Pod ready, eskisi o'chirildi. Exit code 0. Muvaffaqiyatsiz holatda oxirgi qator `error: timed out waiting for the condition` (o'z `--timeout` ingiz tugadi) yoki `error: deployment "web" exceeded its progress deadline` bo'ladi va exit code 1. Buzilish ssenariylarini 19-vazifada pipeline ichida ko'rasiz.

### Real ishda qachon kerak

- Har deploy job'ining oxirgi majburiy qadami. Usiz pipeline yashil, production esa buzilgan bo'lishi mumkin.
- `--timeout` ni `progressDeadlineSeconds` dan kichik qo'ying: pipeline 10 daqiqa bekor kutmasin.

### Nima uchun shunday

Kubernetes API asinxron: `apply` istak (spec) yozadi, controller'lar uni keyinroq bajaradi (1-dars, reconciliation loop). Shuning uchun "bajarildimi" degan savolga javob har doim alohida kuzatuv bilan olinadi. Avtomatik rollback Kubernetes'ga qo'shilmagan, chunki "muvaffaqiyatsiz" ta'rifi ilovaga bog'liq (ba'zan sekin start normal); bu qaror tashqi asbobga (pipeline, Helm, Argo Rollouts) qoldirilgan.

## 9. Pipeline ichidagi vaqtinchalik klaster

### Bu nima

GitHub-hosted runner har job uchun toza VM (cicd 2-dars, 1-bo'lim) va u sizning lokal kind klasteringizga yeta olmaydi. `helm/kind-action` runner ichida Docker'da kind klaster yaratadi va kubeconfig'ni job'ga tayyorlab qo'yadi. Job tugasa VM bilan birga klaster ham yo'qoladi.

### Mexanizm

- `ubuntu-latest` runner'da `docker`, `kubectl`, `helm`, `kind` va `kustomize` oldindan o'rnatilgan (runner image'i ro'yxati Manbalar'da). kubeconform yo'q, uni job ichida yuklab olasiz.
- Action yaratgan klasterning admin kubeconfig'i `~/.kube/config` da. Deploy'ni haqiqiy muhitga o'xshatish uchun admin faqat RBAC'ni o'rnatadi, deploy esa alohida, kam huquqli kubeconfig bilan bajariladi (18-vazifa).
- Image'ni kind'ga yetkazishning ikki yo'li: GHCR'dan tortish (private bo'lsa job ichida `GITHUB_TOKEN` bilan pull Secret) yoki shu job'da qurilgan image'ni `kind load docker-image` bilan node'ga yuklash. Birinchisi haqiqiy oqimga yaqinroq.
- Job'lar `needs` va `outputs` orqali bog'lanadi (cicd 2-dars, 2-bo'lim): build job digest'ni output qiladi, deploy job uni oladi.

### Misol

Faqat klaster ko'tarilishini tekshiradigan minimal workflow (vazifalardagi job'lar emas):

```yaml
name: kind-smoke
on: workflow_dispatch
permissions:
  contents: read
jobs:
  kind:
    runs-on: ubuntu-latest
    steps:
      - uses: helm/kind-action@v<N>
        with:
          cluster_name: ci
      - run: kubectl get nodes -o wide
```

Run log'idagi oxirgi step chiqishi:

```
NAME               STATUS   ROLES           AGE   VERSION    INTERNAL-IP   ...
ci-control-plane   Ready    control-plane   <..>  v1.<..>    172.18.0.2    ...
```

`workflow_dispatch` workflow'ni Actions sahifasidagi tugma bilan qo'lda ishga tushirish imkonini beradi. `permissions` ni minimal qoldirdik: bu job repo'ga yozmaydi, package push qilmaydi. Node nomi `cluster_name` dan olingan, `INTERNAL-IP` runner ichidagi Docker tarmog'i manzili. Klaster bir daqiqa atrofida ko'tariladi, bu PR job'ining vaqtiga qo'shiladi.

### Real ishda qachon kerak

- PR'da server dry-run va hatto to'liq deploy sinovi (ephemeral environment) uchun.
- Helm chart'lar uchun `chart-testing` asbobi bilan birga: chart'ni har PR'da haqiqiy klasterga o'rnatib ko'rish.

### Nima uchun shunday

Vaqtinchalik klaster haqiqiy klasterga kirish huquqini PR'ga bermasdan haqiqiy API server bilan tekshirish imkonini beradi. Fork'dan kelgan PR'ga production credential'i berilmaydi (cicd 2-dars, `pull_request_target` tuzog'i), lekin unga o'zining bir martalik klasteri berilishi xavfsiz. Narxi: vaqt va haqiqiy klasterdagi admission, CRD va quota'larning yo'qligi.

## 10. Push-based deploy'ning chegaralari

### Bu nima

Yuqoridagi model "push": CI klasterga tashqaridan kirib o'zgartiradi (cicd 5-dars, 1-bo'lim). Kichik jamoada yaxshi ishlaydi, lekin klaster va jamoa o'sganda quyidagi chegaralar chiqadi.

### Mexanizm: olti chegara

1. **Credential tashqarida.** Klasterga yozish huquqi CI tizimida yashaydi. CI buzilsa klaster ham buziladi.
2. **Tarmoq.** API server CI runner'dan ochiq bo'lishi kerak. Private klaster uchun self-hosted runner yoki VPN.
3. **Drift ko'rinmaydi.** Kimdir `kubectl edit` yoki `kubectl scale` qilsa, git va klaster ajraladi, keyingi pipeline ishga tushguncha hech kim bilmaydi.
4. **"Hozir nima deploy qilingan" pipeline log'ida.** Git'dagi manifest emas, oxirgi muvaffaqiyatli job haqiqat manbai bo'lib qoladi.
5. **Ko'p klaster.** Har klaster uchun credential, har biriga alohida deploy job.
6. **Rollback.** Eski pipeline'ni qayta ishga tushirish yoki qo'lda `rollout undo`, ikkalasi ham git tarixidan tashqarida.

### Misol

Drift'ni o'zingiz yarating va pipeline buni bilmasligini ko'ring:

```
$ kubectl -n demo scale deployment/web --replicas=4
deployment.apps/web scaled
$ kubectl -n demo get deployment web
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    4/4     4            4           <..>
```

Agar `web` git'dagi faylda `replicas: 1` bilan yozilgan bo'lsa, fayl o'zgarmadi. Klaster bu o'zgarishni hech kimga xabar qilmaydi; uni faqat keyingi `kubectl diff` yoki `apply` ko'rsatadi (va jim qaytarib yuboradi). 12-vazifada shu drift'ni `kubectl diff` bilan ushlaysiz.

### Real ishda qachon kerak

O'z pipeline'ingiz uchun ushbu ro'yxatni ochiq yozish (21-vazifa) GitOps'ga qachon o'tish kerakligini asoslashning yo'li.

### Nima uchun shunday

GitOps bu modelni teskari qiladi: klaster ichidagi agent git'ni o'qiydi va o'zini unga moslaydi (pull). CI'ning ishi image build va git'dagi manifestni yangilash bilan tugaydi, klasterga yozish huquqi CI'dan chiqib ketadi, drift esa agent tomonidan doimiy ko'rinadi. Bu 10-darsning mavzusi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Deploy zanjiri | commit'dan ishlayotgan Pod'gacha bo'lgan qadamlar ketma-ketligi |
| Tag | registry'dagi image'ga qo'yilgan, ko'chirilishi mumkin bo'lgan nom |
| Digest | image manifestining SHA-256 hash'i, o'zgarmas identifikator |
| Image index | har platforma uchun manifestga ishora qiluvchi ro'yxat (docker 2-dars) |
| `imagePullPolicy` | kubelet image'ni registry'dan qachon qayta so'rashini belgilovchi maydon |
| `imageID` | Pod status'idagi, kubelet haqiqatda ishga tushirgan image identifikatori |
| `imagePullSecrets` | private registry credential'ini Pod'ga bog'lovchi havola |
| GHCR | GitHub Container Registry, `ghcr.io` |
| Kustomize | YAML manifestlar ustiga patch qo'yib muhit variantlarini chiqaruvchi asbob |
| Base / overlay | Kustomize'dagi umumiy qism va muhitga xos o'zgarishlar |
| `configMapGenerator` | kontent hash'li nom bilan ConfigMap yaratuvchi Kustomize kaliti |
| Helm chart | template'li manifestlar, values va metadata paketi |
| `values.yaml` | chart'ning default qiymatlari |
| `appVersion` / `version` | ilova versiyasi / chart versiyasi |
| kubeconform | manifestni Kubernetes JSON schema'lariga solishtiruvchi statik tekshiruvchi |
| Server dry-run | so'rovni API server'da to'liq tekshirib, etcd'ga yozmaslik |
| `kubectl diff` | klasterdagi holat va qo'llanadigan manifest orasidagi farq |
| ServiceAccount | dasturlar uchun namespace ichidagi Kubernetes identifikatsiyasi |
| TokenRequest | ServiceAccount uchun qisqa muddatli token beruvchi API |
| JWT | imzolangan, claim va muddat yozilgan token formati |
| OIDC | tashqi issuer imzolagan token orqali identifikatsiya protokoli |
| `sub` claim | token kim uchun berilganini aytuvchi maydon |
| RBAC | subject, resurs va verb asosidagi avtorizatsiya modeli |
| Role / RoleBinding | namespace ichidagi qoidalar va ularni subject'ga bog'lash |
| Least privilege | faqat ish uchun shart bo'lgan huquqni berish tamoyili |
| Impersonation (`--as`) | admin boshqa identifikatsiya nomidan so'rov yuborishi |
| Rollout gate | rollout tugaguncha kutib, natijani pipeline holatiga aylantiruvchi qadam |
| Smoke test | deploy'dan keyingi minimal haqiqiy so'rov |
| Ephemeral cluster | job bilan yaratilib job bilan yo'qoladigan klaster |
| Push-based deploy | CI klasterga tashqaridan yozadigan model |
| Drift | git'dagi holat va klasterdagi haqiqiy holat orasidagi farq |

## Tuzoqlar

- `latest` yoki qayta yoziladigan tag bilan deploy: rollout bo'lmaydi yoki node'larda har xil kod ishlaydi. Digest yoki commit SHA ishlating.
- Mac'da qurilgan bitta arxitekturali (`arm64`) image'ni `amd64` runner'dagi kind'ga deploy qilish: `exec format error`. Push'dan keyin `imagetools inspect` bilan platformalarni tekshiring.
- Pipeline'ga `cluster-admin` kubeconfig berish. Bitta zararli PR butun klasterni oladi.
- Fork'dan kelgan PR'da deploy secret'lari bilan job ishga tushirish (`pull_request_target` tuzog'i, cicd 2-dars).
- `kubectl apply` yashil bo'lgani uchun deploy muvaffaqiyatli deb hisoblash. `rollout status` siz pipeline hech narsani bilmaydi.
- Readiness probe'siz rollout gate: har doim o'tadi.
- `--dry-run=client` ni validatsiya deb o'ylash: u API server'ga bormaydi.
- kubeconform'ni `-strict` siz ishlatish: typo maydonlar jim o'tadi.
- `helm lint` o'tdi, demak manifest to'g'ri deb o'ylash. `helm template` natijasini o'qing va validatsiyadan o'tkazing.
- Muddatsiz ServiceAccount token'ni CI secret'ida yillab saqlash, rotatsiyasiz.
- Helm `--set` bilan pipeline'da o'nlab qiymat berish: haqiqiy konfiguratsiya git'da emas, workflow faylida qoladi. Qiymatlar `values-<env>.yaml` da bo'lsin.
- Kubeconfig yoki token'ni `echo` bilan log'ga chiqarish. GitHub secret'ni maskalaydi, lekin base64 qilingan nusxasini emas.
- Pull Secret'ni `--docker-password=<token>` deb to'g'ridan yozish: token shell tarixida qoladi.
- `rollout status` ni `--timeout` siz chaqirish: buzilgan rollout'da job 10 daqiqa (`progressDeadlineSeconds`) bekor kutadi.

## Manbalar

- https://kubernetes.io/docs/concepts/containers/images/ – image nomlari, digest, pull policy, `imagePullSecrets`
- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ – private registry'dan pull
- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ – Kustomize rasmiy qo'llanma
- https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/ – kustomization.yaml kalitlari
- https://kubectl.docs.kubernetes.io/installation/kustomize/ – alohida `kustomize` binary'sini o'rnatish
- https://helm.sh/docs/chart_template_guide/ – chart template qo'llanmasi
- https://helm.sh/docs/topics/charts/ – Chart.yaml va chart tuzilishi
- https://github.com/yannh/kubeconform – kubeconform, o'rnatish va CRD schema'lari
- https://kubernetes.io/docs/reference/using-api/deprecation-guide/ – o'chirilgan API'lar ro'yxati
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/ – rollout status
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_diff/ – kubectl diff va exit code'lar
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/ – ServiceAccount token, structured authentication
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/ – RBAC
- https://docs.github.com/en/actions/concepts/security/openid-connect – GitHub Actions OIDC
- https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images – GHCR'ga push workflow
- https://github.com/helm/kind-action – kind-action input'lari
- https://github.com/actions/runner-images – runner image'larida o'rnatilgan asboblar

## Birga bajaramiz

Vazifalardagidan boshqa misol: agnhost `netexec` servisi (4-darsdagi `echo`) uchun lokal "mini pipeline": Kustomize render, kubeconform, server dry-run, diff, apply, rollout gate, smoke test, keyin ataylab buzilgan deploy va qo'lda qaytarish. Hammasi host'da, `kind-cicd` klasterida, `~/k9-walk` papkasida; hech narsa commit qilinmaydi. Bu yerda pipeline yo'q, siz o'zingiz pipeline vazifasini bajarasiz va har qadam qaysi qatlam ekanini ko'rasiz.

1. Base. Deployment va Service, readiness probe bilan:

```
$ mkdir -p ~/k9-walk/base ~/k9-walk/overlays/qa && cd ~/k9-walk
$ cat base/echo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
spec:
  replicas: 1
  selector:
    matchLabels: {app: echo}
  template:
    metadata:
      labels: {app: echo}
    spec:
      containers:
      - name: app
        image: registry.k8s.io/e2e-test-images/agnhost:2.39
        args: ["netexec", "--http-port=8080"]
        ports: [{containerPort: 8080}]
        readinessProbe:
          httpGet: {path: /healthz, port: 8080}
          periodSeconds: 3
        resources:
          requests: {cpu: 50m, memory: 32Mi}
          limits: {memory: 64Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector: {app: echo}
  ports: [{port: 80, targetPort: 8080}]
$ cat base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - echo.yaml
```

2. Digest'ni olish va `qa` overlay'i. Tag o'rniga index digest'i yoziladi, shuning uchun Zorin'da ham, Mac'da ham node o'z arxitekturasini oladi:

```
$ docker buildx imagetools inspect registry.k8s.io/e2e-test-images/agnhost:2.39 | grep -m1 Digest
Digest:    sha256:<A>
$ cat overlays/qa/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: qa
resources:
  - ../../base
images:
  - name: registry.k8s.io/e2e-test-images/agnhost
    digest: sha256:<A>
$ kubectl kustomize overlays/qa | grep image:
        image: registry.k8s.io/e2e-test-images/agnhost@sha256:<A>
```

`images` bo'limi tag'ni olib tashlab, o'rniga `@sha256:` qo'ydi. Base o'zgarmadi.

3. Statik tekshiruv (klastersiz qatlam):

```
$ kubectl kustomize overlays/qa | kubeconform -strict -summary -
Summary: 2 resources found parsing stdin - Valid: 2, Invalid: 0, Errors: 0, Skipped: 0
```

`-` kubeconform'ga stdin'dan o'qishni aytadi. Ikki resurs, ikkalasi ham schema bo'yicha to'g'ri.

4. Server dry-run (klasterli qatlam). Namespace'ni oldin admin sifatida yaratamiz:

```
$ kubectl create namespace qa
namespace/qa created
$ kubectl apply -k overlays/qa --dry-run=server
service/echo created (server dry run)
deployment.apps/echo created (server dry run)
```

`(server dry run)` belgisi so'rov API server'ning to'liq validatsiya va admission zanjiridan o'tganini, lekin etcd'ga yozilmaganini aytadi: `kubectl -n qa get all` hozir bo'sh. Namespace'ni overlay ichiga qo'yish yoki pipeline'da alohida yaratish sizning dizayn qaroringiz (kim namespace yaratish huquqiga ega bo'lishi kerak, 7-bo'lim).

5. Diff, apply va gate:

```
$ kubectl diff -k overlays/qa > /dev/null; echo "diff exit: $?"
diff exit: 1
$ kubectl apply -k overlays/qa
service/echo created
deployment.apps/echo created
$ kubectl -n qa rollout status deployment/echo --timeout=60s; echo "gate exit: $?"
Waiting for deployment "echo" rollout to finish: 0 of 1 updated replicas are available...
deployment "echo" successfully rolled out
gate exit: 0
$ kubectl diff -k overlays/qa; echo "diff exit: $?"
diff exit: 0
```

Birinchi diff 1 qaytardi: klasterda hali hech narsa yo'q, hammasi "farq". Apply'dan keyingi diff 0: git (papka) va klaster bir xil. Gate exit 0.

6. Smoke test: Service orqali haqiqiy so'rov, klaster ichidagi vaqtinchalik Pod'dan:

```
$ kubectl -n qa run smoke --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- http://echo/hostname
echo-<hash>-<id>
pod "smoke" deleted
```

`netexec` ning `/hostname` endpoint'i javob bergan Pod nomini qaytaradi. Javob kelgani Service, EndpointSlice va DNS (6-dars) ham ishlayotganini bildiradi, bu rollout status ko'rmaydigan narsa.

7. Buzilgan deploy. Overlay'dagi digest'ni mavjud bo'lmagan qiymatga almashtiring (masalan oxirgi belgisini o'zgartiring) va gate'ni qisqa timeout bilan qayta ishga tushiring:

```
$ kubectl apply -k overlays/qa
service/echo unchanged
deployment.apps/echo configured
$ kubectl -n qa rollout status deployment/echo --timeout=45s; echo "gate exit: $?"
Waiting for deployment "echo" rollout to finish: 1 old replicas are pending termination...
error: timed out waiting for the condition
gate exit: 1
$ kubectl -n qa get rs,pods
NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/echo-<old>        1         1         1       <..>
replicaset.apps/echo-<new>        1         1         0       <..>

NAME                   READY   STATUS             RESTARTS   AGE
pod/echo-<old>-<id>    1/1     Running            0          <..>
pod/echo-<new>-<id>    0/1     ImagePullBackOff   0          <..>
```

Qatorma-qator: `service/echo unchanged`, chunki Service'da hech narsa o'zgarmadi; `configured`, chunki template'dagi image satri o'zgardi. Gate 45 soniyadan keyin exit 1 berdi, pipeline'da bu qizil job. Eski ReplicaSet `READY 1`: foydalanuvchilar hali eski versiyaga xizmat olyapti. Yangi Pod `ImagePullBackOff`: registry bunday digest'ni bilmaydi.

8. Qo'lda qaytarish va natijani tekshirish:

```
$ kubectl -n qa rollout undo deployment/echo
deployment.apps/echo rolled back
$ kubectl -n qa rollout status deployment/echo --timeout=60s
deployment "echo" successfully rolled out
$ kubectl diff -k overlays/qa > /dev/null; echo "diff exit: $?"
diff exit: 1
```

Oxirgi qator muhim: klaster qaytdi, lekin papkadagi (git'dagi) overlay hali buzilgan digest'ni saqlaydi, diff 1. Bu 10-bo'limdagi 6-chegara: rollback git tarixidan tashqarida bo'ldi. Keyingi `apply` buzilishni qaytaradi.

9. Tozalash: `kubectl delete namespace qa`, `rm -r ~/k9-walk`. Klaster vazifalar uchun qoladi.

## Vazifalar

Barchasini `kubernetes/09-cicd-integration/` da bajaring (`make new m=kubernetes n=09 name=cicd-integration`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar, chart va overlay'lar shu papkada (`deploy/`, `chart/`), workflow fayli ilova repo'sida, uning nusxasi yoki havolasi README'da. Lokal qismlar `kind-cicd` klasterida; qaysi mashinada bajarganingizni (Zorin yoki macOS) README'da ko'rsating.

### A. Image va tag

1. **Tag vs digest.** Ilovangiz image'ini lokal build qilib GHCR'ga ikki tag bilan push qiling (commit SHA va `dev`). `docker buildx imagetools inspect` bilan digest'ni oling. Kodni o'zgartirib `dev` tag'ini qayta push qiling. Qaysi biri o'zgardi, qaysi biri yo'q? Jadval qilib yozing. Mac'da ishlasangiz image keyin `amd64` runner'da ham ishlatilishini hisobga oling (ko'p platformali build). Yo'nalish: 2-bo'lim.

2. **Mutable tag trap.** kind klasterda Deployment'ni `:dev` tag bilan deploy qiling. `dev` ni yangi kod bilan qayta push qilib `kubectl apply` ni takrorlang. Rollout bo'ldimi? `kubectl rollout history` va Pod'ning `imageID` maydoni bilan isbotlang va sababini ikki mexanizm (Pod template, pull policy) orqali izohlang. Yo'nalish: 2-bo'lim, "Mexanizm".

3. **Pipeline build by SHA.** Ilova repo'sida workflow yozing: `main` ga push'da image build, tag `github.sha`, GHCR'ga push, digest'ni job output'iga chiqarish. `permissions` blokini minimal qiling va har bir ruxsat nima uchun kerakligini yozing. Yo'nalish: 2-bo'lim, cicd 2-dars 2 va 8-bo'limlar.

4. **Private image pull.** GHCR package'ni private qoldirib kind'da deploy qiling. `ImagePullBackOff` xabarini `kubectl describe pod` dan o'qing. `imagePullSecrets` bilan tuzating. Token'ga qaysi scope yetarli ekanini yozing. Token shell tarixida qolmasin.

### B. Kustomize va Helm

5. **Kustomize base and overlays.** Ilovangiz uchun `deploy/base` (Deployment, Service) va `dev`, `prod` overlay'larini yozing: namespace, replica soni, resurslar, image har xil. `kubectl kustomize` natijalarini `diff` bilan solishtiring va farqlar faqat kutilgan joyda ekanini ko'rsating.

6. **ConfigMap hash rollout.** Overlay'ga `configMapGenerator` qo'shing va Deployment'da env sifatida ishlating. Qiymatni o'zgartirib `kubectl apply -k` qiling. ConfigMap nomi va rollout bilan nima bo'ldi? Xuddi shu tajribani generator'siz oddiy ConfigMap bilan takrorlab farqni izohlang.

7. **Write a Helm chart.** `helm create` skeletidan boshlab keraksizini o'chiring va ilovangiz uchun chart yozing: image repository va digest, replica soni, resurslar, probe'lar, Service porti values orqali. `values-dev.yaml` va `values-prod.yaml` yarating.

8. **helm lint and template.** Chart'da ataylab uch xil xato qiling: yopilmagan `{{`, noto'g'ri `nindent`, mavjud bo'lmagan `.Values` kaliti. Har biri uchun `helm lint` va `helm template` nima deydi, qaysi birini ikkalasi ham ushlamaydi? Jadval qilib yozing.

9. **Kustomize or Helm.** Bir xil ilovaning ikki variantini yonma-yon qo'yib yozing: har birida "prod'da replica sonini o'zgartirish" va "yangi muhit qo'shish" necha fayl va necha qator o'zgarish. O'z loyihangiz uchun qaysi birini tanlaysiz va nima uchun (5–6 gap)?

### C. Validatsiya

10. **kubeconform strict.** Render qilingan manifestga ataylab `replcas: 3` typo'sini va eski, o'chirilgan `apiVersion` ni kiriting. kubeconform'ni `-strict` bilan va usiz ishga tushiring. Har holatda nima chiqdi? `-kubernetes-version` ni o'zgartirish natijaga qanday ta'sir qiladi?

11. **Server dry-run.** Uch holatni `--dry-run=client` va `--dry-run=server` bilan sinang: mavjud bo'lmagan namespace, Deployment'ning `selector` ini mavjud obyektda o'zgartirish, noto'g'ri tipdagi maydon. Qaysi tekshiruv qaysi birini ushladi va nima uchun?

12. **kubectl diff gate.** Klasterdagi Deployment'ni `kubectl scale` bilan qo'lda o'zgartiring, keyin `kubectl diff -k` ni ishga tushiring. Chiqish va exit code'ni yozing. Buni PR'da "nima o'zgaradi" kommenti sifatida qanday ishlatish mumkin?

### D. Auth va RBAC

13. **Deployer ServiceAccount.** `app` namespace'ida `deployer` ServiceAccount, Role va RoleBinding yarating. Huquqlarni eng kamdan boshlang va deploy ishlaguncha faqat xato xabari talab qilganini qo'shing. Yakuniy Role'ni va har bir qoida nima uchun kerakligini yozing.

14. **Kubeconfig from token.** `kubectl create token` bilan 1 soatlik token oling va noldan alohida kubeconfig fayli yig'ing. Shu fayl bilan `app` da deploy qilib ko'ring, keyin `kube-system` dagi Pod'larni va `app` dagi Secret'larni o'qib ko'ring. Xato xabarlarini yozing. Kubeconfig fayli va token commit qilinmaydi.

15. **can-i audit.** `kubectl auth can-i --list` ni `deployer` nomidan ishga tushiring. Keyin Role'ga `secrets` uchun `get` va `pods/exec` uchun `create` qo'shilsa hujumchi nima qila olishini aniq qadamlar bilan yozing (bajarmasdan).

16. **OIDC design.** Kodsiz, README'da: GitHub Actions'dan EKS klasterga OIDC orqali deploy sxemasini chizing (kim kimga ishonadi, qaysi token qayerda almashadi, `sub` claim'i qanday cheklanadi). ServiceAccount token variantiga nisbatan nima yaxshilanadi, nima murakkablashadi?

### E. Pipeline

17. **Validate job.** Workflow'ga PR uchun `validate` job qo'shing: `helm lint`, render, kubeconform, vaqtinchalik kind klasterda (`helm/kind-action`) `--dry-run=server`. Ataylab buzilgan manifest bilan PR ochib job qizil bo'lishini ko'rsating.

18. **Deploy with rollout gate.** `main` uchun `deploy` job: vaqtinchalik kind klaster yaratadi, 13-vazifadagi RBAC'ni admin sifatida qo'yadi, keyin faqat `deployer` kubeconfig'i bilan build job'dan kelgan digest'ni deploy qiladi va `rollout status --timeout` bilan kutadi. Oxirida smoke test.

19. **Break the rollout.** Readiness probe yo'lini mavjud bo'lmagan path'ga o'zgartirib push qiling. Pipeline qayerda va qancha vaqtdan keyin qizil bo'ldi? Shu paytda eski Pod'lar bilan nima bo'lgan (job ichida `kubectl get rs,pods` chiqaring)? Probe'ni butunlay o'chirsangiz gate nima qiladi?

20. **Automatic rollback.** Deploy qadamini Helm'ga o'tkazing va muvaffaqiyatsiz rollout'da avtomatik orqaga qaytishni yoqing. 19-vazifadagi buzilishni takrorlab `helm history` chiqishini yozing. `deployer` Role'iga nima qo'shishga to'g'ri keldi va bu xavfsizlik uchun nimani anglatadi?

21. **Push model limits.** O'z pipeline'ingiz misolida 10-bo'limdagi olti chegaraning har biri uchun aniq ssenariy yozing: sizning setup'ingizda u qanday namoyon bo'ladi. Qaysi biri sizni eng ko'p xavotirga soladi?

## Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 21 vazifa yozilgan, manifestlar, overlay'lar va chart papkada.
2. `make check` toza (`yamllint` chart'ning `templates/` papkasini tekshirmaydi, ular YAML emas, Go template).
3. Workflow'ning oxirgi `main` run'i yashil, buzilgan PR'niki qizil (havolalar README'da).
4. Repo'da token, kubeconfig va secret yo'q (`git log -p` va `make secrets` bilan tekshiring).
5. `kind delete cluster --name cicd` bajarilgan, GHCR'dagi sinov package'lari kerak bo'lmasa o'chirilgan.
6. Menga xabar bering, tekshiraman.

## O'zini tekshirish savollari

Kodsiz, o'z so'zingiz bilan javob bering.

- Tag va digest farqi nima, nima uchun production manifestida digest afzal?
- `latest` ni qayta push qilib `kubectl apply` qilish nima uchun rollout boshlamaydi?
- `imagePullPolicy` ning default qiymati qanday tanlanadi va qayta push qilingan tag'ga qanday ta'sir qiladi?
- `configMapGenerator` ning hash suffiksi qaysi muammoni yechadi?
- Kustomize va Helm'ning modeli qanday farq qiladi? Har biri qachon to'g'ri tanlov?
- `--dry-run=client`, `--dry-run=server` va kubeconform har biri nimani tekshiradi?
- `kubectl apply` muvaffaqiyatli, lekin deploy muvaffaqiyatsiz bo'lishi qanday mumkin? Pipeline buni qanday biladi?
- Muvaffaqiyatsiz rollout paytida eski Pod'lar bilan nima bo'ladi va nima uchun?
- Helm bilan deploy qiladigan ServiceAccount'ga nima uchun Secret'larga yozish huquqi kerak va bu nimaga olib keladi?
- OIDC bilan auth'da qayerda secret saqlanadi?
- Push-based deploy'da drift nima uchun ko'rinmaydi?
