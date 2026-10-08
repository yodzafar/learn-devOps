# 10-dars: GitOps: Argo CD va Flux

Maqsad: 9-darsda pipeline cluster'ga tashqaridan kirib deploy qildi va bu modelning chegaralari ko'rindi: cluster credential'i CI'da yotadi, qo'lda qilingan o'zgarish (drift) keyingi pipeline'gacha ko'rinmaydi, "hozir cluster'da nima bor" savoliga javob pipeline log'ida. GitOps'da bu munosabat teskari bo'ladi: cluster ichidagi controller git repo'ni o'zi kuzatadi va cluster holatini unga moslab turadi. Bu darsda GitOps tamoyillari, Argo CD (Application, sync policy, wave va hook'lar, app-of-apps, ApplicationSet, AppProject) va Flux (bootstrap, GitRepository, Kustomization, HelmRelease, `dependsOn`, image automation) qo'lda sinaladi. Keyingi darslardagi hamma narsa (HA sozlamalari, operator'lar, NetworkPolicy, autoscaler'lar) va yakuniy loyiha shu usulda deploy qilinadi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–4 bo'limlar, "Birga bajaramiz" va A guruh, 3–5 vazifalar; ikkinchi kun 5–6 bo'limlar va B guruhning qolgani (6–12); uchinchi kun 7–9 bo'limlar va C guruh; to'rtinchi kun 10–11 bo'limlar, D guruh va README. Sintaksis oddiy YAML, diqqatni semantikaga qarating: reconciliation sikli qachon va nimani qaytaradi, `prune` va `selfHeal` har biri nimani boshqaradi, GitOps'da rollback nima degani, CI qayerda tugab CD qayerda boshlanadi.

## Qanday o'qish kerak

Bu darsda "buyruq ishlatdim, natija chiqdi" degan oddiy sikl yo'q: siz git'ga commit qilasiz, natija esa bir necha soniya yoki daqiqadan keyin cluster'da paydo bo'ladi. Shuning uchun har tajribada uchta oyna ochiq tursin: git (commit va push), `kubectl get ... -w` (`-w` o'zgarishni jonli ko'rsatadi) va Argo CD UI yoki `flux get ...`. Har o'zgarishdan keyin o'zingizga ikki savol bering: "istalgan holat qayerda yozilgan?" (git'da) va "kim uni cluster'ga olib keldi?" (controller). Chiqishlardagi commit SHA, vaqt, pod suffiksi va versiya raqamlari sizda boshqa bo'ladi, darsda bunday joylar `<...>` bilan belgilangan. Har `## N.` bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker ustidagi kind'da (2-dars) va GitHub'da. Multipass VM kerak emas: GitOps controller'lari node xulqiga bog'liq emas, oddiy bir node'li kind cluster yetarli.

- **Config repo**: GitHub'da yangi `k8s-gitops` repo (config repo, ya'ni cluster'ning istalgan holati yoziladigan repo). Sodda bo'lishi uchun public, ichida hech qanday secret bo'lmaydi. 9-darsdagi ilova kodi repo'si alohida qoladi.
- **Ikki cluster**: Argo CD qismi uchun `kind create cluster --name argo`, Flux qismi uchun `kind create cluster --name flux`. Context nomlari `kind-argo` va `kind-flux`, har buyruqdan oldin `kubectl config current-context` ga qarang. Ikki controller'ni bitta cluster'da bir xil resurslarga qo'ymang: ular bir-birining o'zgarishini navbat bilan qaytarib turadi. RAM tejash uchun ularni ketma-ket ishlating: B guruh tugagach `argo` ni o'chirib, keyin `flux` ni yarating (D guruh uchun ikkalasi kerak bo'lsa, git'dan bir necha daqiqada tiklanadi, quyida).

CLI'larni o'rnatish (versiyani releases sahifasidan oling va ikki mashinada bir xil qiling; quyidagi `v3.1.0` faqat misol):

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| `argocd` CLI | GitHub release'dan `argocd-linux-amd64` binary'si (pastda) | `brew install argocd` (`arm64`) |
| `flux` CLI | `curl -s https://fluxcd.io/install.sh \| sudo bash` yoki release'dagi `linux_amd64` arxivi | `brew install fluxcd/tap/flux` (`arm64`) |
| kind node'lari | host Docker Engine'ida, `docker ps` da `argo-control-plane` | Docker Desktop'ning yashirin Linux VM'ida, `docker ps` da xuddi shu nom |
| Controller image'lari | `amd64` varianti | `arm64` varianti (Argo CD va Flux image'lari multi-arch) |
| UI'ga kirish | `kubectl port-forward`, brauzerda `https://localhost:8080` | xuddi shunday: port-forward API server orqali ishlaydi, Docker VM farq qilmaydi |
| RAM | Argo CD taxminan 1–1.5 GB oladi | Docker Desktop'ga kamida 6 GB bering (Settings, Resources) |

Zorin'da `argocd` CLI (rasmiy hujjatdagi usul, versiya o'zgaruvchida):

```bash
ARGOCD_VERSION=v3.1.0   # replace with the current stable release
curl -sSL -o argocd-linux-amd64 \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

**GitHub token (Flux bootstrap uchun).** Flux bootstrap repo'ga commit qiladi va deploy key qo'shadi, buning uchun personal access token (PAT, GitHub'ga parol o'rniga ishlatiladigan cheklangan kalit) kerak. Token faqat bootstrap paytida shell o'zgaruvchisida yashaydi, faylga, README'ga va shell tarixiga tushmaydi:

```bash
read -rs GITHUB_TOKEN    # paste the token, nothing is echoed
export GITHUB_TOKEN
```

`read -s` bash'da ham, zsh'da ham kiritilganni ekranga chiqarmaydi va buyruq tarixiga token yozilmaydi (`export GITHUB_TOKEN=ghp_...` dan farqli).

**Ikkinchi mashinada tiklash.** Bu dars boshqalardan farqli: tiklashning o'zi GitOps'ning isboti. Cluster holati mashinalar orasida ko'chmaydi, lekin istalgan holat to'liq `k8s-gitops` repo'sida. Uyda: `kind create cluster --name argo`, 2-bo'limdagidek Argo CD'ni o'rnating, keyin ish papkangizda saqlangan bootstrap manifestini (root Application, 10-vazifa) `kubectl apply -f` qiling; qolgan hamma narsani Argo CD git'dan o'zi tortadi. Flux uchun `flux bootstrap github` ni o'sha `--path` bilan qayta ishga tushiring: buyruq idempotent (necha marta bajarilsa ham natija bir xil), repo'dagi mavjud fayllarni ishlatadi. Ko'chmaydigan narsalar: Argo CD admin paroli (har cluster'da yangi), sync tarixi, Flux deploy key'i (yangi cluster yangi kalit yaratadi, eskisini GitHub'dan o'chiring).

**Tozalash**: `kind delete cluster --name argo`, `kind delete cluster --name flux`; GitHub'da token'ni revoke qiling (Settings, Developer settings) va `k8s-gitops` repo'sidagi deploy key'larni o'chiring (repo Settings, Deploy keys).

---

## 1. GitOps tamoyillari

### Bu nima

GitOps bu tizimning istalgan holati git'da deklarativ yoziladigan va cluster ichidagi agent uni uzluksiz cluster'ga qo'llab turadigan yetkazib berish usuli. CNCF qoshidagi OpenGitOps guruhi uni to'rt tamoyil bilan ta'riflaydi:

1. **Declarative.** Istalgan holat buyruqlar ketma-ketligi emas, natija sifatida yoziladi (manifest, Kustomize overlay, Helm values; 3 va 9-darslar).
2. **Versioned and immutable.** Istalgan holat o'zgarmas versiyalar bilan to'liq tarixda saqlanadi. Amalda git: har o'zgarish commit, PR va review.
3. **Pulled automatically.** Agent istalgan holatni manbadan o'zi tortib oladi. Hech kim cluster'ga tashqaridan push qilmaydi.
4. **Continuously reconciled.** Agent haqiqiy holatni uzluksiz kuzatadi va farqni yo'qotadi.

Frontend tajribasidan haqiqiy o'xshatish: Vercel yoki Netlify. Siz serverga hech narsa yuklamaysiz, `main` ga push qilasiz, platforma repo'ni o'zi oladi va deploy qiladi. GitOps shu g'oyani butun cluster'ga, va bir qadam oldinga olib boradi: platforma faqat push'da emas, doimiy ravishda "cluster git'ga mosmi" deb tekshiradi.

### Mexanizm: reconciliation va drift

1-darsdagi controller modelini eslang: controller `spec` (istalgan) va `status` (haqiqiy) farqini kuzatib uni yopadi. GitOps controller'i xuddi shu siklni bir qavat yuqorida aylantiradi, faqat "spec" endi git'da:

1. Git'dan belgilangan branch yoki tag'ning oxirgi commit'ini oladi.
2. Manifestlarni render qiladi (Kustomize build, Helm template yoki oddiy YAML): bu istalgan holat.
3. Cluster'dagi mos obyektlarni API server'dan o'qiydi: bu haqiqiy holat.
4. Farqni hisoblaydi va farq bo'lsa obyektlarni qo'llaydi (`kubectl apply` ga o'xshash amal).
5. Natijani o'z status'iga yozadi va qayta 1-qadamga qaytadi (vaqt oralig'ida yoki git webhook kelganda).

Drift (ajralish) bu cluster holatining git'dagidan farq qilib qolishi. Uch manbasi bor:

- odam: incident paytida `kubectl edit` yoki `kubectl scale` bilan shoshilinch tuzatish;
- boshqa controller: HPA Deployment'ning `replicas` maydonini o'zgartiradi (14-dars);
- mutating webhook (API server'ga kelgan obyektni saqlashdan oldin o'zgartiradigan plagin): masalan sidecar yoki default label qo'shadi.

Birinchisi yo'qotilishi kerak bo'lgan drift. Qolgan ikkitasi "kutilgan farq", ularni e'tiborsiz qoldirish sozlanadi (Argo CD'da `ignoreDifferences`, Flux'da manifestdan maydonni olib tashlash).

### Ishlaydigan misol: drift'ni qo'lda ko'rish

GitOps controller'i bo'lmasa ham drift'ni `kubectl diff` bilan ko'rsa bo'ladi. U lokal fayl va cluster'dagi obyektni solishtiradi. Faraz qiling `web.yaml` da `replicas: 2` yozilgan va qo'llangan:

```
$ kubectl scale deployment web --replicas=5
deployment.apps/web scaled
$ kubectl diff -f web.yaml
diff -u -N /tmp/LIVE-<...>/apps.v1.Deployment.default.web /tmp/MERGED-<...>/apps.v1.Deployment.default.web
--- /tmp/LIVE-<...>/apps.v1.Deployment.default.web
+++ /tmp/MERGED-<...>/apps.v1.Deployment.default.web
@@ -10,7 +10,7 @@
 spec:
-  replicas: 5
+  replicas: 2
$ echo $?
1
```

- `LIVE` cluster'dagi joriy obyekt, `MERGED` "fayl qo'llansa nima bo'lardi". `-` qatorlar hozirgi holat, `+` qatorlar fayl bergan holat.
- `replicas: 5` dan `2` ga: drift aynan shu.
- Exit code 1 "farq bor" degani (0 farq yo'q, 1 dan katta xato). GitOps controller'i mohiyatan shu diff'ni har necha daqiqada o'zi hisoblab, farq bo'lsa `apply` qiladi.

### Push va pull

| | Push (9-dars) | Pull (GitOps) |
|---|---------------|---------------|
| Cluster credential | CI tizimida | cluster ichida, tashqariga chiqmaydi |
| Tarmoq yo'nalishi | CI -> API server (API server tashqaridan ochiq bo'lishi kerak) | cluster -> git (faqat chiquvchi ulanish) |
| Drift | keyingi pipeline'gacha ko'rinmaydi | daqiqalar ichida aniqlanadi |
| Haqiqat manbai | oxirgi muvaffaqiyatli job | git commit |
| Rollback | eski pipeline'ni qayta ishga tushirish | `git revert` |
| Audit | CI log'lari (muddati o'tib o'chadi) | git tarixi |

### CI va CD chegarasi

GitOps'da CI cluster'ga tegmaydi. CI'ning oxirgi qadami: config repo'da image tag yoki digest'ni yangilaydigan commit (to'g'ridan-to'g'ri yoki PR orqali). Qolganini cluster ichidagi controller qiladi:

```
app repo:    push -> test -> build -> push image (ghcr.io/<user>/app@sha256:9b1e...)
config repo: commit "app: sha256:9b1e..."   (by CI, by a human PR, or by image automation)
cluster:     controller pulls -> diff -> apply -> health check
```

### Real ishda qachon kerak

Bir nechta muhit (dev, staging, prod) yoki bir nechta cluster bo'lganda; audit talab qilinganda ("kim, qachon, nima uchun prod'ni o'zgartirdi" savoliga git tarixi javob beradi); cluster API'sini internetga ochib bo'lmaydigan joyda (private cluster); cluster'ni noldan tez qayta qurish kerak bo'lganda (disaster recovery: yangi cluster + bitta bootstrap = hammasi qaytadi).

### Nima uchun shunday

Kubernetes'ning o'zi allaqachon deklarativ va reconciliation'ga qurilgan, lekin uning `spec` i etcd'da yashaydi: kim qachon o'zgartirgani, nima uchun, review bo'lganmi, hech qayerda yozilmaydi. GitOps manbani git'ga ko'chirib, deploy'ga dasturchilar allaqachon ishonadigan jarayonni (PR, review, revert) beradi. "GitOps" atamasi 2017-yilda Weaveworks tomonidan kiritilgan, Flux shu kompaniyaning loyihasi edi. Muqobil, push model, sodda va hali keng tarqalgan (9-dars); GitOps uning o'rniga emas, qo'shimcha cluster ichidagi komponent (controller) narxiga keladi.

## 2. Argo CD: arxitektura va o'rnatish

### Bu nima

Argo CD Kubernetes uchun GitOps controller'i va uning ustidagi UI, CLI va API. U cluster'ga bir nechta Deployment va StatefulSet sifatida o'rnatiladi va o'z CRD'lari (Custom Resource Definition, Kubernetes API'ga yangi obyekt turini qo'shadigan ta'rif; 8-darsda cert-manager'ning `Certificate` i shunday edi) orqali boshqariladi: `Application`, `ApplicationSet`, `AppProject`.

### Mexanizm: komponentlar

| Komponent | Turi | Vazifasi |
|-----------|------|----------|
| `argocd-server` | Deployment | API server: UI, CLI va SSO shu orqali kiradi |
| `argocd-repo-server` | Deployment | git repo'ni clone qiladi va manifestni render qiladi (Kustomize, Helm, YAML) |
| `argocd-application-controller` | StatefulSet | render qilingan va cluster'dagi holatni solishtiradi, sync qiladi, health hisoblaydi |
| `argocd-redis` | Deployment | render natijalari va cluster holati uchun cache |
| `argocd-applicationset-controller` | Deployment | ApplicationSet'lardan Application yaratadi (6-bo'lim) |

Ro'yxatdagi qolgan ikki komponent (`dex-server`, `notifications-controller`) nima qilishini 3-vazifada o'zingiz topasiz. Muhim kuzatuv: repo server faqat o'qiydi va render qiladi, cluster'ga yozadigan yagona komponent application controller. Shuning uchun u keng RBAC huquqiga ega (odatda cluster-admin darajasida).

### Ishlaydigan misol: o'rnatish

```bash
kubectl config current-context        # must print: kind-argo
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
```

- `${ARGOCD_VERSION}` Laboratoriya bo'limida o'rnatilgan o'zgaruvchi. Hujjatdagi `stable` branch o'rniga aniq versiya: `latest` tag'idan qochish sababi bilan bir xil (9-dars), ertaga xuddi shu buyruq boshqa narsa o'rnatmasligi uchun.
- `--server-side` server-side apply (SSA): o'zgarishni API server hisoblaydi. Kerak, chunki Argo CD CRD'lari katta va client-side apply ular uchun `last-applied-configuration` annotation'ining 262144 baytlik chegarasidan oshib ketadi. `--force-conflicts` boshqa field manager (maydonga egalik qilgan yozuvchi) bilan to'qnashuvda o'zgarishni majburlaydi. Qayta o'rnatish va upgrade paytida kerak.

`kubectl -n argocd get deploy,sts` da oltita Deployment va bitta StatefulSet (`argocd-application-controller`) ko'rinadi, ya'ni jadvaldagi beshta komponent va `argocd-dex-server`, `argocd-notifications-controller`. Hammasi `1/1` bo'lgach UI va CLI'ga kirish:

```
$ kubectl -n argocd port-forward svc/argocd-server 8080:443
Forwarding from 127.0.0.1:8080 -> 8080
$ argocd admin initial-password -n argocd      # in another terminal
<random-password>
$ argocd login localhost:8080 --username admin --insecure
Password:
'admin:login' logged in successfully
Context 'localhost:8080' updated
```

- `port-forward` 6-darsdagi kabi: lokal 8080 portni Service'ning 443 portiga ulaydi. `443 -> 8080` Service porti pod'dagi 8080 ga yo'naltirilganini ko'rsatadi.
- `initial-password` `argocd-initial-admin-secret` Secret'idagi tasodifiy parolni o'qiydi. U har o'rnatishda yangi.
- `--insecure` Argo CD self-signed sertifikat bilan ishlaydi (8-dars), lokal laboratoriyada uni tasdiqlab bo'lmaydi. Production'da Ingress/Gateway va haqiqiy sertifikat qo'yiladi va bu flag kerak emas.

Keyin `argocd account update-password` bilan parolni almashtiring va hujjat tavsiyasiga ko'ra `argocd-initial-admin-secret` ni o'chiring.

### Real ishda qachon kerak

Jamoada dasturchilar deploy holatini o'zi ko'rishi kerak bo'lganda (UI'da resurs daraxti, diff, pod log'lari), bitta markaziy Argo CD bir nechta cluster'ga deploy qilganda (hub modeli), SSO va jamoalar bo'yicha ruxsatlar kerak bo'lganda.

### Nima uchun shunday

Argo CD bitta mahsulot sifatida qurilgan: UI va API birinchi kundan asosiy qism. Bu dasturchilar uchun qulay, lekin narxi bor: `argocd-server` ga kirish huquqi amalda cluster'ga yozish huquqi, chunki u controller orqali istalgan manifestni qo'llatishi mumkin. Shuning uchun admin parolini almashtirish va UI'ni autentifikatsiyasiz ochmaslik ixtiyoriy emas. Repo server'ning alohida jarayon bo'lishi esa xavfsizlik qarori: render paytida Helm va Kustomize begona kodni (chart'lar, plugin'lar) ishlatadi, uni cluster'ga yozish huquqi bor jarayondan ajratish kerak.

## 3. Application: sync status va health

### Bu nima

`Application` Argo CD'ning asosiy CRD'si: "shu git repo'ning shu yo'lini, shu revision'da, shu cluster'ning shu namespace'iga joylashtir" degan bog'lanish.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shop-staging
  namespace: argocd            # Application objects live in Argo CD's namespace
spec:
  project: default
  source:
    repoURL: https://github.com/<user>/shop-config.git
    targetRevision: main       # branch, tag or commit SHA
    path: shop/overlays/staging
  destination:
    server: https://kubernetes.default.svc   # the cluster Argo CD runs in
    namespace: shop-staging
  syncPolicy:
    syncOptions: ["CreateNamespace=true"]
```

- `metadata.namespace: argocd` Application obyekti ilova namespace'ida emas, Argo CD namespace'ida yashaydi. Ilova resurslari esa `destination.namespace` ga tushadi.
- `source` qayerdan: `repoURL`, `targetRevision`, `path`. Papkada `kustomization.yaml` bo'lsa Argo CD uni Kustomize sifatida, `Chart.yaml` bo'lsa Helm sifatida render qiladi.
- `destination.server: https://kubernetes.default.svc` cluster ichidan API server'ning ichki manzili (6-darsdagi `kubernetes` Service).
- `syncPolicy` da `automated` yo'q: sync faqat qo'lda. `CreateNamespace=true` namespace yo'q bo'lsa yaratadi.

### Mexanizm: ikki mustaqil holat

Application ikki savolga alohida javob beradi:

| Holat | Qiymatlar | Savol |
|-------|-----------|-------|
| Sync status | `Synced`, `OutOfSync`, `Unknown` | cluster'dagi obyektlar git'dan render qilinganiga tengmi? |
| Health status | `Healthy`, `Progressing`, `Degraded`, `Suspended`, `Missing`, `Unknown` | resurslar ishlayaptimi? (Deployment rollout tugadimi, Pod tayyormi) |

Health har resurs turi uchun alohida qoida bilan hisoblanadi: Deployment uchun `status` dagi replica sonlari va rollout holati (4-dars), Service uchun LoadBalancer IP'si bormi, PVC uchun `Bound` mi. Application health'i eng yomon resurs health'iga teng.

Argo CD qaysi obyekt qaysi Application'niki ekanini resursga qo'yadigan tracking annotation'i bilan biladi (3.x versiyalarda default: `argocd.argoproj.io/tracking-id`). Shu sababli bitta resursni ikki Application boshqarsa, ular uni navbat bilan "o'ziniki" qilib qayta yozadi.

### Ishlaydigan misol

```
$ argocd app get shop-staging
Name:               argocd/shop-staging
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          shop-staging
URL:                https://localhost:8080/applications/shop-staging
Source:
- Repo:             https://github.com/<user>/shop-config.git
  Target:           main
  Path:             shop/overlays/staging
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        OutOfSync from main (4c1d2e7)
Health Status:      Missing

GROUP  KIND        NAMESPACE     NAME  STATUS     HEALTH   HOOK  MESSAGE
       Service     shop-staging  shop  OutOfSync  Missing
apps   Deployment  shop-staging  shop  OutOfSync  Missing
```

- `Sync Policy: <none>` avtomatik sync yo'q.
- `OutOfSync from main (4c1d2e7)` git'dagi `main` ning `4c1d2e7` commit'i render qilingan, cluster unga mos emas.
- `Health Status: Missing` resurslar cluster'da umuman yo'q.
- Pastki jadval har resurs uchun alohida: `STATUS` sync, `HEALTH` health. `HOOK` ustuni 5-bo'limdagi hook'lar uchun.

Qo'lda sync va natija:

```
$ argocd app sync shop-staging
...
GROUP  KIND        NAMESPACE     NAME  STATUS  HEALTH       HOOK  MESSAGE
       Service     shop-staging  shop  Synced  Healthy            service/shop created
apps   Deployment  shop-staging  shop  Synced  Progressing        deployment.apps/shop created
```

`Synced` + `Progressing` normal oraliq holat: manifest qo'llangan, pod'lar hali tayyor emas. `argocd app wait --health` health `Healthy` bo'lguncha kutadi (9-darsdagi `kubectl rollout status` ning Argo CD'dagi o'xshashi). Agar Pod `CrashLoopBackOff` ga tushsa, holat `Synced` + `Degraded` bo'lib qoladi: git'dagi narsa to'liq qo'llangan, lekin ilova ishlamayapti.

### Real ishda qachon kerak

`argocd app get` va `argocd app diff` incident paytidagi birinchi ikki buyruq: "cluster git'ga mosmi" va "farq aniq qayerda". UI'dagi resurs daraxti esa qaysi Pod qaysi ReplicaSet'dan kelganini (4-dars) bir qarashda ko'rsatadi.

### Nima uchun shunday

Sync va health'ni bitta "OK" ga birlashtirish qulay bo'lardi, lekin ma'lumot yo'qolardi: "git'dagi narsa qo'llanmadi" (sync muammosi, odatda manifest xatosi yoki RBAC) va "qo'llandi, lekin ishlamayapti" (health muammosi, odatda image, probe yoki resurs) butunlay boshqa joyda qidiriladi. Kubernetes'ning o'zida ham `kubectl apply` muvaffaqiyati Pod tayyorligini anglatmaydi (3-dars), Argo CD shu ikkilikni ochiq ko'rsatadi.

## 4. Sync policy: automated, prune, selfHeal va rollback

### Bu nima

Sync policy Argo CD farqni ko'rganda o'zi nima qilishini belgilaydi:

| Sozlama | Yo'q bo'lsa | Bor bo'lsa |
|---------|-------------|------------|
| `automated` | farq ko'rsatiladi, sync qo'lda (`argocd app sync`) | git'da yangi commit paydo bo'lsa avtomatik sync |
| `automated.prune` | git'dan o'chirilgan resurs cluster'da qoladi va `OutOfSync` ko'rinadi | cluster'dan ham o'chiriladi |
| `automated.selfHeal` | cluster'dagi qo'lda o'zgarish qoladi, faqat git o'zgarganda sync | cluster'dagi drift ham bir necha soniyada qaytariladi |

```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions: ["CreateNamespace=true"]
```

### Mexanizm

- **Git'ni kuzatish.** Default holatda Argo CD repo'ni taxminan har 3 daqiqada tekshiradi (`timeout.reconciliation` 120 soniya va tasodifiy jitter, `argocd-cm` ConfigMap'ida). Tezroq kerak bo'lsa git webhook sozlanadi yoki `argocd app get --refresh` qo'lda chaqiriladi.
- **Faqat git o'zgarganda.** `automated` yolg'iz bo'lsa, Argo CD faqat yangi commit (yoki parametr) uchun sync qiladi. Cluster'da kimdir `kubectl scale` qilsa, Application `OutOfSync` bo'ladi, lekin qaytarilmaydi, chunki git'da yangi narsa yo'q.
- **selfHeal.** Drift'ni ko'rgach qisqa kutishdan keyin (bir necha soniya) qayta sync qiladi.
- **Qayta urinmaslik.** Avtomatik sync bir xil commit va parametrlar bilan muvaffaqiyatsiz bo'lsa, Argo CD uni qayta urinmaydi; `syncPolicy.retry` alohida sozlanadi.
- **Bo'sh ro'yxatdan himoya.** `prune: true` bilan git'dagi papka tasodifan bo'shatilsa hamma narsa o'chishi mumkin edi. Shuning uchun render natijasi butunlay bo'sh bo'lsa avtomatik sync rad etiladi (`allowEmpty: true` bu himoyani o'chiradi). Qisman o'chirishdan himoya yo'q.

### Ishlaydigan misol: rollback urinishi

```
$ argocd app history shop-staging
SOURCE  https://github.com/<user>/shop-config.git
ID      DATE                           REVISION
0       2026-10-08 10:12:31 +0500 +05  main (4c1d2e7)
1       2026-10-08 10:40:05 +0500 +05  main (9a7f3b1)
```

- Har qator bitta muvaffaqiyatli sync: `ID`, vaqt va qaysi commit qo'llangani. Format versiyaga qarab biroz farq qiladi.
- `argocd app rollback shop-staging 0` qo'lda sync'li Application'da cluster'ni 0-yozuvdagi commit holatiga qaytaradi, lekin git o'zgarmaydi: Application darhol `OutOfSync` bo'ladi, chunki `main` hali `9a7f3b1` da.
- `automated` yoqilgan Application'da `argocd app rollback` umuman rad etiladi: controller baribir darhol git'dagi holatga qaytarar edi. Xato matnini 8-vazifada o'zingiz ko'rasiz.

GitOps'da rollback bu `git revert <sha>` va odatiy sync. Tarix git'da qoladi: kim, qachon va nima uchun qaytargani commit xabarida ko'rinadi.

### Real ishda qachon kerak

`automated` + `prune` + `selfHeal` uchalasi production'da keng tarqalgan standart: git yagona haqiqat manbai bo'ladi. Faqat `automated` (selfHeal'siz) ko'pincha migratsiya davrida qo'llanadi, jamoa hali qo'lda o'zgartirishga o'rganib qolgan bo'lsa. Incident paytida qo'lda tuzatish kerak bo'lsa, avval Application'da avtomatik sync o'chiriladi (`argocd app set shop-staging --sync-policy none`), keyin tuzatiladi, keyin tuzatish git'ga commit qilinadi va avtomatik sync qaytariladi. Buni incident'dan oldin bilib qo'ying.

### Nima uchun shunday

`prune` va `selfHeal` default'da o'chiq, chunki ikkalasi ham ma'lumot yo'qotishi mumkin bo'lgan amal: `prune` resursni (PVC bo'lsa diskini ham) o'chiradi, `selfHeal` esa odamning ataylab qilgan o'zgarishini jim qaytaradi. Argo CD xavfsiz default'ni tanlagan va ularni ongli ravishda yoqishni kutadi. Flux esa teskari falsafada (8-bo'lim): u har intervalda qayta qo'llaydi, ya'ni self-heal har doim yoqilgan.

## 5. Tartib: sync wave va hook'lar

### Bu nima

Bitta sync ichida ba'zan tartib kerak: avval Namespace va CRD, keyin operator, keyin uning custom resource'lari; ma'lumotlar bazasi migratsiyasi yangi versiya Pod'laridan oldin; smoke test (deploy'dan keyingi tez sinov) hammasidan keyin.

- **Sync wave**: resursdagi `argocd.argoproj.io/sync-wave: "N"` annotation'i. Kichik son avval, default `0`, manfiy bo'lishi mumkin (`"-1"`).
- **Hook**: `argocd.argoproj.io/hook` annotation'i bor resurs (odatda Job, 5-dars). Qiymatlari: `PreSync` (manifestlar qo'llanishidan oldin), `Sync` (ular bilan birga), `PostSync` (hammasi `Healthy` bo'lgandan keyin), `SyncFail` (sync muvaffaqiyatsiz bo'lsa).
- **Hook delete policy**: `argocd.argoproj.io/hook-delete-policy` tugagan hook'ni qachon o'chirish: `HookSucceeded`, `HookFailed`, `BeforeHookCreation` (keyingi sync'dan oldin eskisini o'chirish).

### Mexanizm

Sync bosqichlarga (phase) bo'linadi: `PreSync`, `Sync`, `PostSync`. Har bosqich ichida resurslar wave bo'yicha tartiblanadi, bir wave ichida esa tur bo'yicha (Namespace, CRD, ServiceAccount oldin, Deployment keyin). Keyingi wave oldingisidagi hamma resurs `Healthy` bo'lgandan keyin boshlanadi. Hook Job'i uchun "Healthy" degani Job `Complete` bo'ldi (5-dars). Job `Failed` bo'lsa sync shu yerda to'xtaydi va keyingi bosqichga o'tmaydi.

### Ishlaydigan misol

Vazifadagidan boshqa holat: sync muvaffaqiyatsiz bo'lsa xabar yuboradigan `SyncFail` hook va hamma narsadan oldin qo'llanadigan ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
  annotations:
    argocd.argoproj.io/sync-wave: "-1"     # before everything in wave 0
data:
  NEW_CHECKOUT: "false"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: notify-failure
  annotations:
    argocd.argoproj.io/hook: SyncFail
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - { name: notify, image: busybox:1.36, command: ["sh", "-c", "echo 'sync failed, paging on-call'"] }
```

- ConfigMap `-1` wave'da: Deployment'lar (wave `0`) uni o'qishidan oldin mavjud bo'ladi.
- Job oddiy resurs emas, hook: sync muvaffaqiyatli bo'lsa u umuman yaratilmaydi.
- `BeforeHookCreation` keyingi muvaffaqiyatsiz sync'da eski Job'ni o'chirib yangisini yaratadi. Busiz ikkinchi marta `field is immutable` yoki "already exists" muammosi chiqardi (5-darsdagi Job template cheklovi).

Sync paytida `argocd app get` jadvalidagi `HOOK` ustunida `SyncFail`, `PreSync` kabi qiymat ko'rinadi, tartibni esa `kubectl get events --sort-by=.lastTimestamp` dagi `Created` vaqtlaridan o'qish mumkin.

### Real ishda qachon kerak

DB migratsiyasi (`PreSync`), deploy'dan keyingi smoke test yoki cache tozalash (`PostSync`), operator va uning CR'lari bitta Application'da bo'lganda (CRD wave `-1`, operator `0`, CR `1`).

### Nima uchun shunday

Kubernetes'ning o'zida "bu obyektni anavi tayyor bo'lgandan keyin yarat" degan tushuncha yo'q: hamma narsa eventual consistency (oxir-oqibat mos kelish) bilan ishlaydi, Pod ConfigMap paydo bo'lguncha kutib, qayta urinadi. Ko'p hollarda bu yetarli, shuning uchun wave'lar default'da kerak emas. Lekin migratsiya kabi "bir marta, aniq vaqtda" ishlar uchun tartib kerak, Argo CD buni Helm hook'lariga o'xshash g'oya bilan beradi (Helm chart'dagi `helm.sh/hook` annotation'lari Argo CD hook'lariga map qilinadi).

## 6. Ko'p Application: app-of-apps, ApplicationSet, AppProject

### Bu nima

O'nlab Application'ni qo'lda `kubectl apply` qilish GitOps emas: Application'larning o'zi ham git'da bo'lishi kerak. Ikki yechim va bitta chegara:

- **App-of-apps**: bitta "root" Application git'dagi papkaga qaraydi, u papkada boshqa Application manifestlari yotadi. Cluster'ga qo'lda faqat root qo'yiladi (bootstrap, ya'ni tizimni ishga tushiradigan birinchi qadam).
- **ApplicationSet**: generator (ma'lumot manbai: ro'yxat, git papkalari yoki fayllari, cluster'lar ro'yxati, ularning kombinatsiyasi) va template'dan Application'lar yaratadigan CRD.
- **AppProject**: Application'lar uchun chegara: qaysi repo'lardan (`sourceRepos`), qaysi cluster va namespace'larga (`destinations`), qaysi resurs turlari bilan (`clusterResourceWhitelist`, `namespaceResourceBlacklist`) deploy qilish mumkin.

### Mexanizm

App-of-apps'da root Application uchun Application manifestlari oddiy resurs: root ularni `argocd` namespace'iga qo'llaydi, application controller esa yangi Application obyektini ko'rib uni ham sync qiladi. Ya'ni bu alohida mexanizm emas, Argo CD o'zini o'zi boshqaradi.

ApplicationSet controller generator'ni ishga tushiradi (masalan git repo'dagi papkalarni sanaydi), har natija uchun template'ni to'ldiradi va Application yaratadi, yangilaydi yoki o'chiradi. Generator natijasidan element yo'qolsa, unga mos Application ham o'chiriladi (default siyosat), va Application'ning resurslari ham. Bu kuch ham, xavf ham.

### Ishlaydigan misol: list generator

Vazifadagi git directory generator'dan boshqa, eng sodda list generator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: docs-sites
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - team: payments
          - team: search
  template:
    metadata:
      name: 'docs-{{.team}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/<user>/docs-config.git
        targetRevision: main
        path: 'sites/{{.team}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'docs-{{.team}}'
```

- `goTemplate: true` template'da Go template sintaksisi (`{{.team}}`) ishlatiladi. Usiz eski sintaksis (`{{team}}`) ishlaydi; ikkisini aralashtirmang.
- Ikki element, ikki Application: `argocd app list` da `argocd/docs-payments` va `argocd/docs-search` paydo bo'ladi, ikkalasi `OutOfSync` va `Missing` (sync policy yo'q). Ro'yxatga uchinchi element qo'shib commit qilsangiz, uchinchi Application o'zi paydo bo'ladi.

AppProject'da `sourceRepos` ro'yxat, `destinations` esa `server` va `namespace` juftliklari (namespace'da `docs-*` kabi wildcard mumkin). Application `spec.project` orqali project'ga bog'lanadi. Project chegarasidan chiqadigan Application sync bo'lmaydi va `argocd app get` dagi condition'larda sababi yoziladi.

### Real ishda qachon kerak

App-of-apps: cluster'ni noldan tiklash (bitta `kubectl apply`), infratuzilma komponentlari to'plami (cert-manager, monitoring, ingress). ApplicationSet: "har muhit papkasi uchun Application", "har cluster'ga shu ilova", "har PR uchun preview muhiti". AppProject: bir nechta jamoa bitta Argo CD'dan foydalanganda. Argo CD'ning o'z RBAC'i (`argocd-rbac-cm` ConfigMap) esa kim qaysi project'dagi Application'ni ko'rishi va sync qilishini belgilaydi; bu Kubernetes RBAC'dan (13-dars) alohida qatlam.

### Nima uchun shunday

`default` project hamma narsaga ruxsat beradi, chunki birinchi kun tajribasi sodda bo'lishi kerak. Lekin controller cluster-admin darajasida ishlagani uchun Application yozish huquqi bor odam cheklovsiz holatda istalgan narsani (masalan `kube-system` ga DaemonSet yoki ClusterRoleBinding) qo'ya oladi. AppProject shu kuchni toraytirish uchun: Kubernetes RBAC "kim API'ga nima yoza oladi" ni boshqaradi, AppProject esa "Argo CD kimning nomidan nima yoza oladi" ni.

## 7. Flux: arxitektura va bootstrap

### Bu nima

Flux (Flux v2) mustaqil controller'lar to'plami (GitOps Toolkit), har biri o'z CRD'lari bilan. O'rnatilgan UI yo'q, hamma narsa `kubectl` va `flux` CLI orqali.

| Controller | CRD'lar | Vazifasi |
|------------|---------|----------|
| source-controller | `GitRepository`, `OCIRepository`, `HelmRepository`, `Bucket` | manbani yuklab olib, versiyalangan artefakt (arxiv) qiladi |
| kustomize-controller | `Kustomization` | artefaktdagi manifestni render qilib qo'llaydi, prune, health check |
| helm-controller | `HelmRelease` | haqiqiy Helm release'ni boshqaradi |
| notification-controller | `Provider`, `Alert`, `Receiver` | Slack va boshqalarga xabar, git webhook qabul qilish |
| image-reflector, image-automation (ixtiyoriy) | `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` | registry'dagi tag'larni kuzatib git'ni yangilaydi (9-bo'lim) |

### Mexanizm: bootstrap

`flux bootstrap github` bir buyruqda quyidagilarni qiladi:

1. Repo'ni (yo'q bo'lsa yaratib) clone qiladi.
2. Controller manifestlarini generatsiya qilib `--path` papkasidagi `flux-system/` ga commit va push qiladi.
3. Controller'larni cluster'ga o'rnatadi.
4. SSH kalit juftligini yaratadi: yopiq kalit cluster'da `flux-system` Secret'ida qoladi, ochiq kalit GitHub repo'ga **deploy key** (bitta repo'ga cheklangan SSH kalit) sifatida qo'shiladi. Default'da faqat o'qish huquqi bilan.
5. O'zini kuzatadigan `GitRepository` va `Kustomization` ni commit qilib qo'llaydi.

Natija: Flux birinchi kundan o'zini GitOps bilan boshqaradi. Flux versiyasini yangilash ham git'dagi `flux-system/` papkasini yangilash orqali bo'ladi. PAT faqat 1, 2 va 4-qadamlar (GitHub API) uchun kerak, keyin Flux git'ni deploy key bilan o'qiydi, shuning uchun token'ni bootstrap'dan keyin revoke qilish mumkin. `--token-auth` flag'i bilan esa deploy key o'rniga PAT'ning o'zi cluster Secret'iga yoziladi: soddaroq, lekin uzoq yashaydigan kengroq huquqli token cluster ichida qoladi. Bu darsda default (deploy key) yo'li ishlatiladi.

### Ishlaydigan misol

```
$ kubectl config current-context
kind-flux
$ flux check --pre
► checking prerequisites
✔ Kubernetes 1.37.<...> >=1.<...>
✔ prerequisites checks passed
```

`--pre` faqat o'rnatishdan oldingi talablarni (cluster versiyasi, ulanish) tekshiradi. O'rnatishdan keyin `flux check` (flag'siz) controller'lar sog'ligini ham ko'rsatadi.

Namuna uchun boshqa repo va yo'l bilan (sizning 13-vazifangizda `k8s-gitops` va `clusters/flux-lab`):

```
$ flux bootstrap github --owner=<user> --repository=demo-fleet \
    --branch=main --path=clusters/demo --personal
► connecting to github.com
✔ repository "https://github.com/<user>/demo-fleet" created
✔ committed component manifests to "main" ("<sha>")
► installing components in "flux-system" namespace
✔ installed components
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAA<...>
✔ configured deploy key "flux-system-main-flux-system-./clusters/demo" for "https://github.com/<user>/demo-fleet"
✔ committed sync manifests to "main" ("<sha>")
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
✔ all components are healthy
```

- `--personal` repo shaxsiy akkauntda (tashkilotda emas). Repo bo'lmasa bootstrap uni yaratadi (default'da private).
- `committed component manifests` birinchi commit: controller'lar manifesti.
- `public key` va `configured deploy key` 4-qadam: GitHub'da repo Settings, Deploy keys bo'limida shu nom bilan kalit paydo bo'ladi.
- `committed sync manifests` ikkinchi commit: Flux o'zini kuzatishi uchun `GitRepository` va `Kustomization`.
- Oxirgi qatorlar har obyekt `Ready` bo'lguncha kutganini ko'rsatadi.

Chiqish qisqartirilgan. Repo'da aynan qaysi fayllar paydo bo'lganini 13-vazifada o'zingiz ko'rasiz.

### Real ishda qachon kerak

Platforma jamoasi cluster'larni to'liq git orqali boshqarganda; har cluster o'z Flux'iga ega bo'lgan ko'p cluster muhitida (har biri faqat o'z papkasini o'qiydi); UI kerak bo'lmaganda yoki cluster'da ortiqcha komponent istalmaganda.

### Nima uchun shunday

Flux v2 ataylab "kichik controller'lar to'plami" qilib qayta yozilgan: manbani olish, Kustomize qo'llash va Helm boshqarish alohida jarayonlar, alohida CRD'lar. Bu Kubernetes'ning o'z dizayniga yaqin (har controller bitta ish qiladi) va keraksiz qismni o'rnatmaslik mumkin. Bootstrap'ning "o'zini git'ga yozishi" esa tovuq va tuxum muammosini hal qiladi: GitOps controller'ining o'zi ham GitOps bilan boshqariladi.

## 8. Flux obyektlari: GitRepository, Kustomization, HelmRelease

### Bu nima

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: blog-staging
  namespace: flux-system
spec:
  interval: 10m
  sourceRef: { kind: GitRepository, name: flux-system }   # created by bootstrap
  path: ./blog/overlays/staging
  prune: true
  wait: true
  timeout: 3m
```

- `GitRepository` (`source.toolkit.fluxcd.io/v1`): `url`, `ref.branch`, `interval`. Bootstrap `flux-system` nomlisini o'zi yaratadi, odatda shu bitta yetarli.
- Flux `Kustomization` (`kustomize.toolkit.fluxcd.io`) va Kustomize'ning `kustomization.yaml` fayli (`kustomize.config.k8s.io`, 9-dars) ikki xil narsa. Birinchisi "shu yo'lni shu cluster'ga qo'lla" degan CRD, ikkinchisi overlay ta'rifi. Nomlari bir xil bo'lgani uchun eng ko'p chalkashlik shu yerda.
- `interval` drift'ni tuzatish davri: Flux har intervalda render qilib qayta qo'llaydi, ya'ni self-heal har doim yoqilgan.
- `prune: true` git'dan o'chirilganni cluster'dan o'chiradi. `wait: true` qo'llangan resurslar tayyor bo'lguncha kutadi, `timeout` ichida tayyor bo'lmasa `Ready=False`.
- `dependsOn` boshqa Kustomization `Ready` bo'lishini kutadi (Argo CD wave'larining o'rnini bosadi): masalan avval `infrastructure`, keyin `apps`.

### Mexanizm

Ikki sikl bor va ular mustaqil: source-controller `GitRepository.spec.interval` da git'ni tekshirib, yangi commit bo'lsa artefakt yaratadi; kustomize-controller esa yangi artefakt kelganda darhol, aks holda `Kustomization.spec.interval` da qayta qo'llaydi. Qo'llash server-side apply bilan bo'ladi (2-bo'lim), Flux maydonlarga `kustomize-controller` nomli field manager sifatida egalik qiladi. Flux qaytaradigan narsa aynan git'dagi manifestda yozilgan maydonlar.

Incident uchun ikki buyruq: `flux suspend kustomization <nom>` reconciliation'ni to'xtatadi (Argo CD'dagi avtomatik sync'ni o'chirishga teng), `flux resume kustomization <nom>` qaytaradi.

### Ishlaydigan misol

```
$ flux get sources git
NAME         REVISION             SUSPENDED  READY  MESSAGE
flux-system  main@sha1:5e1c9a20   False      True   stored artifact for revision 'main@sha1:5e1c9a20'
$ flux get kustomizations
NAME          REVISION             SUSPENDED  READY  MESSAGE
blog-staging  main@sha1:5e1c9a20   False      True   Applied revision: main@sha1:5e1c9a20
flux-system   main@sha1:5e1c9a20   False      True   Applied revision: main@sha1:5e1c9a20
```

- `REVISION` qaysi branch va commit: ikkala obyekt bir xil commit'da bo'lishi kerak, aks holda kustomize-controller hali eskisini qo'llayapti.
- `SUSPENDED False` reconciliation ishlayapti. `READY True` va `MESSAGE` oxirgi urinish natijasi. Xato bo'lsa `READY False` va xabar matni shu yerda (masalan YAML parse xatosi yoki `dependency 'flux-system/infra' is not ready`).

Intervalni kutmasdan darhol qo'llash: `flux reconcile kustomization blog-staging --with-source`. Bu nima uchun `--with-source` siz yetarli emasligini 14-vazifada izohlaysiz.

### HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: redis
  namespace: cache
spec:
  interval: 30m
  chart:
    spec:
      chart: redis
      version: "21.x"
      sourceRef: { kind: HelmRepository, name: bitnami, namespace: flux-system }
  values:
    replica: { replicaCount: 1 }
```

`version: "21.x"` semver oralig'i: helm-controller oraliqdagi eng yangi versiyani tanlaydi va yangisi chiqsa o'zi upgrade qiladi. Shu sababli production'da oraliq tor qilinadi yoki aniq versiya yoziladi. Helm-controller haqiqiy Helm release yaratadi (`helm list -A` da ko'rinadi, 8-dars), upgrade muvaffaqiyatsiz bo'lsa remediation (rollback yoki retry) sozlanadi. Argo CD esa chart'ni `helm template` qilib oddiy manifest sifatida qo'llaydi: Helm release yaratilmaydi, `helm list` bo'sh.

### Real ishda qachon kerak

Bitta `GitRepository` va bir nechta `Kustomization` (infratuzilma, ilovalar, har muhit) Flux'dagi eng keng tarqalgan tuzilish. `HelmRelease` uchinchi tomon chart'lari (cert-manager, ingress, monitoring) uchun.

### Nima uchun shunday

Manba va qo'llashning alohida obyekt bo'lishi bitta repo'ni o'nlab Kustomization ishlatishiga, bitta git clone'ni qayta-qayta qilmaslikka imkon beradi. Self-heal'ning har doim yoqilganligi Flux'ning qat'iy pozitsiyasi: git yagona haqiqat, istisno kerak bo'lsa ochiq `suspend` qilinadi va bu `flux get` da ko'rinib turadi.

## 9. Image yangilash: kim config repo'ga yozadi

### Bu nima

CI image'ni registry'ga push qildi. Endi config repo'dagi tag yoki digest kimdir tomonidan yangilanishi kerak. Uch yo'l:

- **CI o'zi commit qiladi** yoki PR ochadi: ilova repo'sidagi pipeline config repo'ga yozadi (alohida token yoki deploy key bilan).
- **Flux image automation**: `ImageRepository` registry'ni skanerlaydi, `ImagePolicy` qaysi tag eng yangi ekanini tanlaydi (semver, alifbo yoki raqam tartibi), `ImageUpdateAutomation` manifestdagi marker qo'yilgan qatorni yangilab commit qiladi.
- **Argo CD Image Updater**: Argo CD uchun xuddi shu vazifani bajaradigan alohida loyiha.

### Mexanizm: marker va tartib

Flux image automation manifestdagi maxsus izohni qidiradi:

```yaml
image: ghcr.io/<user>/web:1.4.2 # {"$imagepolicy": "flux-system:web"}
```

Izoh "bu qatorni `flux-system` namespace'idagi `web` ImagePolicy natijasi bilan almashtir" degani. Policy esa tag'larni tartiblay olishi kerak: semver (`1.4.2 < 1.10.0`) yoki raqamli. Faqat commit SHA (`3f2c1ab`) tartib bermaydi, "eng yangi"ni aniqlab bo'lmaydi; shuning uchun `main-<run_number>-<sha>` kabi tag va undan raqamni ajratib oladigan filtr ishlatiladi.

Bu controller'lar default o'rnatilmaydi: bootstrap'ga `--components-extra=image-reflector-controller,image-automation-controller` qo'shiladi. Flux git'ga yozishi uchun deploy key yozish huquqi bilan bo'lishi kerak (`--read-write-key`).

### Ishlaydigan misol: kim nimani yozadi

```
$ git log --oneline -3 -- apps/web/overlays/dev/kustomization.yaml
a91c0de (HEAD -> main) web: ghcr.io/<user>/web@sha256:9b1e<...> (ci run 214)
7d2e113 web: ghcr.io/<user>/web@sha256:44fa<...> (ci run 213)
c03b8f2 dev overlay: add resource limits
```

- Har qator config repo'dagi bitta o'zgarish. Muallif va xabardan qaysi yo'l ishlatilgani ko'rinadi: CI bot, Flux (`fluxcdbot` nomi bilan) yoki odam.
- `-- <fayl>` faqat shu faylga tegadigan commit'larni ko'rsatadi: "dev'da qachon qaysi image bo'lgan" savolining javobi.

### Real ishda qachon kerak

Eng sodda va eng shaffof variant: CI'ning o'zi config repo'ga PR ochishi; dev uchun avto-merge, prod uchun majburiy review. Image automation ko'p servisli dev muhitlarda qulay, lekin cluster ichidagi controller'ga git'ga yozish huquqini beradi.

### Nima uchun shunday

GitOps "cluster faqat git'ni o'qiydi" deydi, lekin kimdir git'ga yozishi kerak. Savol yozish huquqini qayerda saqlash: CI'da (har ilova repo'si config repo'ga yoza oladi) yoki cluster'da (Flux deploy key'i). Har ikkisida ham push modelidagidan yaxshiroq: cluster API'siga hech kim tashqaridan kirmaydi, o'zgarish esa har doim commit sifatida qoladi.

## 10. Repo tuzilishi va git'dagi secret muammosi

### Bu nima

```
k8s-gitops/
  apps/
    app/
      base/
      overlays/{dev,staging,prod}/
  infrastructure/          # ingress/gateway, cert-manager, monitoring
  clusters/
    lab/                   # what this cluster deploys (Applications or Kustomizations)
```

- **Ilova kodi va config alohida repo'da.** Aks holda har image tag commit'i CI'ni qayta ishga tushiradi (cheksiz sikl xavfi), kod review bilan deploy review aralashadi va config repo'ga yozish huquqi bor bot ilova kodiga ham yoza oladi.
- **Muhit = papka, branch emas.** `dev` va `prod` branch'lari orasidagi merge vaqt o'tishi bilan cherry-pick va conflict'ga aylanadi, muhitlar farqini bitta `diff` bilan ko'rib bo'lmaydi. Papkalarda farq overlay faylida ochiq yotadi.
- **Promotion** (versiyani keyingi muhitga ko'chirish): dev overlay'dagi image digest'ni prod overlay'ga ko'chiradigan PR. Review va approval shu yerda.
- `main` ga to'g'ridan-to'g'ri push cluster'ga to'g'ridan-to'g'ri deploy. Branch protection (GitHub'da branch'ga to'g'ridan-to'g'ri push'ni taqiqlash) va majburiy review GitOps'ning xavfsizlik chegarasi.

### Mexanizm: secret muammosi

GitOps "hamma narsa git'da" deydi, lekin Secret manifesti faqat base64 bilan kodlangan (4-dars), shifrlanmagan. Uni git'ga qo'yish parolni ochiq yozish bilan teng, git tarixidan esa o'chirish deyarli mumkin emas (har clone'da qoladi). Yechimlar ikki turda:

- git'da shifrlangan holda saqlash: Sealed Secrets (cluster'dagi controller'gina ocha oladigan shifr), SOPS (Flux uni o'zi ocha oladi);
- git'da faqat havola, qiymat tashqi secret manager'da: External Secrets Operator.

13-darsda uchalasini qo'lda sinaysiz. Bu darsda qoida qat'iy: config repo'ga hech qanday Secret manifesti, token yoki kubeconfig tushmaydi.

### Ishlaydigan misol: repo'ni tekshirish

```
$ git grep -n -E '^kind: Secret' -- '*.yaml' '*.yml'
$ echo $?
1
$ git log --all --oneline -S 'kind: Secret'
$
```

- `git grep` joriy fayllarda qidiradi. Chiqish bo'sh va exit code 1: hech narsa topilmadi (bu yerda 1 yaxshi natija).
- `git log -S '<matn>'` ("pickaxe") shu matn qo'shilgan yoki o'chirilgan commit'larni butun tarix bo'yicha qidiradi. Bo'sh chiqish: tarixda ham Secret bo'lmagan. Joriy faylda yo'qligi yetarli emas, chunki o'chirilgan secret tarixda yashashda davom etadi.

### Real ishda qachon kerak

Har GitOps repo'sida birinchi kundan: tuzilish keyin o'zgartirilsa, `prune` tufayli resurslar o'chib qayta yaratiladi. Secret tekshiruvi esa CI'da avtomatik bo'ladi (gitleaks kabi skanerlar, 13-dars).

### Nima uchun shunday

Branch'lar kod uchun yaratilgan: vaqtinchalik o'zgarish, keyin `main` ga birlashadi. Muhitlar esa doimiy va parallel yashaydi, ular uchun papka tabiiyroq. Flux va Argo CD hujjatlari ham papkaga asoslangan tuzilishni tavsiya qiladi.

## 11. Argo CD va Flux taqqoslash

### Bu nima

| | Argo CD | Flux |
|---|---------|------|
| Arxitektura | bitta mahsulot: API server, UI, controller | mustaqil controller'lar to'plami |
| UI | o'rnatilgan, kuchli (resurs daraxti, diff, log) | yo'q (uchinchi tomon UI'lar bor) |
| Asosiy obyekt | `Application` | `Kustomization`, `HelmRelease` |
| Helm | `helm template` qilib qo'llaydi | haqiqiy Helm release |
| Tartib | sync wave, hook | `dependsOn`, health check |
| Self-heal | ixtiyoriy (`selfHeal`) | har doim, `interval` bo'yicha |
| Ko'p cluster | markaziy Argo CD ko'p cluster'ga deploy qiladi (hub) | odatda har cluster'da o'z Flux'i |
| Ko'p jamoa | `AppProject`, o'z RBAC'i, SSO | Kubernetes RBAC, ServiceAccount impersonation |
| Image yangilash | alohida Image Updater | o'rnatilgan (ixtiyoriy) controller'lar |
| Secret | plugin yoki tashqi operator | SOPS o'rnatilgan |
| CNCF | Graduated | Graduated |

### Mexanizm: bir savol, ikki javob

"Cluster git'ning qaysi commit'ida va hammasi joyidami?" Argo CD'da `argocd app list` sync va health'ni ikki alohida ustunda (`STATUS`, `HEALTH`) beradi, commit esa `argocd app get` da. Flux'da `flux get kustomizations` commit'ni `REVISION` da, natijani bitta `READY` va `MESSAGE` da beradi (8-bo'limdagi chiqish); `wait: true` bo'lsa `READY` health'ni ham o'z ichiga oladi. Bir xil savol, ikki xil model: Argo CD holatlarni ajratadi, Flux ularni bitta Kubernetes condition'iga yig'adi.

### Real ishda qachon kerak

Tanlov odatda texnik emas, tashkiliy: dasturchilarga ko'rinadigan UI va markaziy boshqaruv kerak bo'lsa Argo CD, platforma jamoasi hamma narsani CRD va git orqali boshqarsa Flux. 19-vazifada o'z tajribangizdan solishtirasiz.

### Nima uchun shunday

Ikkalasi bir xil tamoyilni amalga oshiradi va ikkalasi CNCF'da graduated (yetuk) maqomida. Farq dizayn falsafasida: Argo CD "foydalanuvchi uchun mahsulot", Flux "Kubernetes'ning davomi bo'lgan qurilish bloklari".

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| GitOps | istalgan holat git'da, cluster ichidagi agent uni uzluksiz qo'llaydigan yetkazib berish usuli |
| Reconciliation | istalgan va haqiqiy holatni solishtirib farqni yopish sikli |
| Drift | cluster holatining git'dagidan farq qilib qolishi |
| Server-side apply | o'zgarishni API server hisoblaydigan va maydon egaligini yuritadigan apply rejimi |
| `Application` | Argo CD'da git yo'li va cluster namespace'i orasidagi bog'lanish |
| Sync status | cluster obyektlari git'dan render qilinganiga tengmi (`Synced`/`OutOfSync`) |
| Health status | resurslar ishlayaptimi (`Healthy`/`Progressing`/`Degraded`/`Missing`) |
| `prune` | git'dan o'chirilgan resursni cluster'dan ham o'chirish |
| `selfHeal` | git o'zgarmasa ham cluster'dagi drift'ni qaytarish |
| Sync wave | sync ichidagi tartib raqami, kichigi avval |
| Hook | sync'ning ma'lum bosqichida ishlaydigan resurs (`PreSync`, `PostSync`, `SyncFail`) |
| App-of-apps | boshqa Application manifestlarini qo'llaydigan root Application |
| ApplicationSet | generator va template'dan Application'lar yaratadigan CRD |
| AppProject | Application'lar uchun repo, manzil va resurs turi chegarasi |
| Deploy key | bitta repo'ga cheklangan SSH kalit |
| Flux `Kustomization` | "shu yo'lni qo'lla" degan Flux CRD'si (Kustomize fayli emas) |
| `HelmRelease` | Flux'da haqiqiy Helm release'ni boshqaradigan CRD |
| Image automation | registry'dagi yangi tag bo'yicha git'dagi image qatorini yangilaydigan controller'lar |

## Tuzoqlar

- Config repo'ga Secret manifestini, `.env`, token yoki kubeconfig'ni commit qilish. Git tarixidan o'chirish deyarli imkonsiz, secret'ni almashtirish shart.
- `selfHeal` yoki Flux reconciliation yoqilgan cluster'da qo'lda tuzatish: o'zgarish jim qaytariladi, incident cho'ziladi. Avval `argocd app set ... --sync-policy none` yoki `flux suspend`.
- `prune` ni yoqib resursni git'da boshqa papkaga ko'chirish yoki nomini o'zgartirish: eski obyekt o'chiriladi, PVC bo'lsa ma'lumot bilan birga.
- HPA boshqaradigan Deployment'da `replicas` ni git'da qoldirish: GitOps controller va HPA bir-biri bilan kurashadi. `replicas` manifestdan olib tashlanadi yoki farq e'tiborga olinmaydi.
- `Synced` ni "ishlayapti" deb o'qish. Health holatiga va alert'larga qarang.
- Muhitlar uchun uzoq yashaydigan branch'lar.
- `targetRevision: HEAD` va `main` ga himoyasiz push: review'siz production deploy.
- Argo CD UI'ni autentifikatsiyasiz yoki default admin paroli bilan ochiq qoldirish. Argo CD admin amalda cluster admin.
- Bitta resursni ikki Application yoki ikki Kustomization boshqarishi: ular navbat bilan bir-birini qayta yozadi.
- Image automation uchun tartiblanmaydigan tag'lar (faqat SHA): policy "eng yangi"ni aniqlay olmaydi.
- ApplicationSet generator'idan element (papka) o'chirilsa Application va uning resurslari ham o'chadi.
- GitHub token'ni `export GITHUB_TOKEN=...` bilan yozish: shell tarixida qoladi. Bootstrap'dan keyin revoke qilmaslik.

## Manbalar

- https://opengitops.dev/ – GitOps tamoyillari
- https://argo-cd.readthedocs.io/en/stable/getting_started/ – Argo CD o'rnatish
- https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ – automated sync, prune, self-heal
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ – sync wave va hook'lar
- https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/ – app-of-apps
- https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/ – ApplicationSet
- https://argo-cd.readthedocs.io/en/stable/user-guide/projects/ – AppProject
- https://fluxcd.io/flux/installation/#install-the-flux-cli – Flux CLI o'rnatish
- https://fluxcd.io/flux/concepts/ – Flux asosiy tushunchalari
- https://fluxcd.io/flux/installation/bootstrap/github/ – bootstrap
- https://fluxcd.io/flux/components/kustomize/kustomizations/ – Kustomization CRD
- https://fluxcd.io/flux/components/helm/helmreleases/ – HelmRelease CRD
- https://fluxcd.io/flux/guides/image-update/ – image update automation
- https://fluxcd.io/flux/guides/repository-structure/ – repo tuzilishi variantlari

---

## Birga bajaramiz

Vazifalardan boshqa misol: alohida `gitops-demo` repo'sidagi statik sahifa (nginx va HTML'li ConfigMap) Argo CD orqali deploy qilinadi. Application manifest bilan emas, `argocd app create` CLI'si bilan yaratiladi, sync qo'lda. Yo'l davomida git'dan cluster'gacha zanjir, diff, tarix va Application'ni o'chirish ko'rinadi. Argo CD 2-bo'limdagidek `kind-argo` cluster'ida o'rnatilgan va siz `argocd login` qilgansiz deb faraz qilinadi. Hammasi ikkala mashinada bir xil.

1. GitHub'da public `gitops-demo` repo yarating va clone qiling. Ichida `site/` papkasi va uchta fayl. `site/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: site-html
data:
  index.html: |
    <h1>demo v1</h1>
```

`site/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: site
spec:
  replicas: 1
  selector:
    matchLabels: { app: site }
  template:
    metadata:
      labels: { app: site }
    spec:
      containers:
        - name: nginx
          image: nginx:1.28          # multi-arch: amd64 and arm64
          volumeMounts: [{ name: html, mountPath: /usr/share/nginx/html }]
      volumes: [{ name: html, configMap: { name: site-html } }]
```

`site/service.yaml` 3-darsdagidek `site` nomli ClusterIP Service, port 80, selector `app: site`. Commit va push:

```
$ git add site && git commit -m "site: initial v1" && git push
[main 4b7e0c2] site: initial v1
 3 files changed, 38 insertions(+)
```

2. Application yaratish (namespace `site` ga, sync policy'siz):

```
$ argocd app create site \
    --repo https://github.com/<user>/gitops-demo.git \
    --path site --revision main \
    --dest-server https://kubernetes.default.svc --dest-namespace site \
    --sync-option CreateNamespace=true
application 'site' created
```

`argocd app create` ham cluster'da xuddi 3-bo'limdagi `Application` obyektini yaratadi: `kubectl -n argocd get applications` da `site` `OutOfSync` va `Missing` holatida ko'rinadi. Farqi: bu obyekt git'da yo'q, ya'ni Application'ning o'zi GitOps bilan boshqarilmayapti. O'rganish uchun mayli, vazifalarda manifest ishlatiladi.

3. Diff va sync:

```
$ argocd app diff site
===== /ConfigMap site/site-html ======
0a1,8
> apiVersion: v1
...
$ argocd app sync site
...
Sync Status:        Synced to main (4b7e0c2)
Health Status:      Progressing
$ argocd app wait site --health --timeout 120
...
Health Status:      Healthy
```

`argocd app diff` farq bo'lsa 1 bilan chiqadi (`kubectl diff` kabi). Resurs cluster'da yo'q bo'lgani uchun diff butun obyektni "qo'shiladi" (`>`) sifatida ko'rsatadi.

4. Natijani tekshirish:

```
$ kubectl -n site port-forward svc/site 8081:80
$ curl -s localhost:8081        # in another terminal
<h1>demo v1</h1>
```

5. Git orqali o'zgartirish. `configmap.yaml` da `v1` ni `v2` ga almashtiring, commit va push. Keyin pollingni kutmasdan:

```
$ argocd app get site --refresh | grep -E 'Sync Status|Health'
Sync Status:        OutOfSync from main (e19a6d4)
Health Status:      Healthy
$ argocd app diff site
===== /ConfigMap site/site-html ======
4c4
<     <h1>demo v1</h1>
---
>     <h1>demo v2</h1>
```

- `--refresh` Argo CD'ni git'ni darhol qayta o'qishga majbur qiladi. `OutOfSync` + `Healthy`: cluster'dagi eski versiya sog'lom ishlayapti, faqat git'dan orqada. Sync va health mustaqilligining yana bir ko'rinishi.
- Diff'da `<` cluster'dagi, `>` git'dagi qator.

6. `argocd app sync site`, keyin `curl` ni takrorlang. Javob bir daqiqagacha eski bo'lishi mumkin: ConfigMap volume'i pod ichida kubelet tomonidan davriy yangilanadi (4-dars), Pod qayta yaratilmaydi, chunki Deployment template'i o'zgarmadi. Bu GitOps xatosi emas, ConfigMap iste'mol qilish xulqi.

7. Tarix: `argocd app history site` ikki qator ko'rsatadi (`4b7e0c2` va `e19a6d4`, 4-bo'limdagi format). Git'dagi tarix (`git log --oneline`) bilan solishtiring: Argo CD tarixi faqat sync qilingan commit'larni ko'rsatadi, git esa hammasini.

8. Tozalash:

```
$ argocd app delete site --cascade
Are you sure you want to delete 'site' and all its resources? [y/n] y
application 'site' deleted
$ kubectl get ns site
NAME   STATUS   AGE
site   Active   <...>
```

- `--cascade` Application bilan birga u yaratgan resurslarni ham o'chiradi (Application'dagi `resources-finalizer.argocd.argoproj.io` finalizer'i, ya'ni obyekt o'chishidan oldin bajarilishi shart bo'lgan tozalash belgisi, shuni ta'minlaydi).
- Namespace qoldi: `CreateNamespace=true` yaratgan namespace Application resurslari ro'yxatiga kirmaydi. `kubectl delete ns site` bilan qo'lda o'chiring. `gitops-demo` repo'sini GitHub'da o'chirishingiz mumkin.

---

## Vazifalar

Barchasini `kubernetes/10-gitops/` da hujjatlashtiring (`make new m=kubernetes n=10 name=gitops`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlarning o'zi `k8s-gitops` repo'sida yashaydi, README'da commit havolalari bo'lsin. Cluster'ga qo'lda qo'yilgan bootstrap manifestlarining nusxasini (masalan root Application) ish papkasiga saqlang. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozib qo'ying. Vaqt o'lchanadigan vazifalarda (6, 7, 15) alohida terminalda `kubectl get ... -w` ochib qo'ying.

### A. Tamoyillar va repo

1. **Config repo layout.** `k8s-gitops` repo'sini yarating va 9-darsdagi ilovangizning Kustomize base va `dev`, `prod` overlay'larini 10-bo'limdagi tuzilishga joylang. Image digest bilan ko'rsatilsin. Nima uchun ilova repo'siga emas, alohida repo'ga qo'yganingizni 3–4 gapda yozing.

2. **Push vs pull.** 9-darsdagi pipeline va shu darsdagi model uchun: cluster'ga yozish huquqi qayerda saqlanadi, tarmoq ulanishi qaysi yo'nalishda ochiladi, CI tizimi buzilsa hujumchi nima qila oladi. Jadval qilib yozing.

### B. Argo CD

3. **Install Argo CD.** `argo` kind cluster'iga Argo CD'ni o'rnating, UI va CLI bilan kiring, admin parolini almashtiring. `argocd` namespace'idagi har bir Deployment/StatefulSet nima ish qilishini bir qatordan yozing.

4. **First Application.** `dev` overlay uchun Application manifestini yozing (sync policy'siz) va `kubectl apply` qiling. UI va `argocd app get` da `OutOfSync` holatini ko'ring, `argocd app diff` chiqishini yozing, keyin qo'lda sync qiling.

5. **Sync vs health.** Git'da image'ni mavjud bo'lmagan tag'ga o'zgartirib sync qiling. Sync status va health status nima bo'ldi? Nima uchun ikkalasi alohida ekanini shu misolda izohlang, keyin `git revert` bilan tuzating.

6. **Automated sync.** `automated` ni `prune` va `selfHeal` siz yoqing. Git'da replica sonini o'zgartirib, qancha vaqtda qo'llanganini o'lchang. Keyin cluster'da `kubectl scale` qiling: qaytarildimi? Git'dan Service manifestini o'chirib commit qiling: cluster'da nima bo'ldi?

7. **Prune and selfHeal.** `prune: true` va `selfHeal: true` ni yoqib 6-vazifadagi ikki tajribani takrorlang. Natijalarni 6-vazifa bilan jadvalda solishtiring. Deployment'ni `kubectl delete` qilsangiz nima bo'ladi?

8. **Rollback the GitOps way.** Buzuq commit deploy qiling (readiness probe noto'g'ri). `argocd app rollback` ni sinab ko'ring va xato xabarini yozing. Keyin `git revert` bilan qaytaring. `argocd app history` chiqishini yozing va ikki usulning audit jihatidan farqini izohlang.

9. **Sync waves and hook.** Ilovaga uchta narsa qo'shing: alohida Namespace manifesti, `PreSync` hook Job (migratsiyani taqlid qiladi: 10 soniya `sleep`, log'ga yozadi) va `PostSync` smoke test Job. Wave'lar bilan tartibni belgilang. Sync paytidagi tartibni UI yoki `kubectl get events` dan isbotlang. `PreSync` Job'ni `exit 1` qilsangiz sync nima bo'ladi?

10. **App of apps.** `clusters/lab/` papkasiga `dev` va `prod` Application manifestlarini qo'ying va bitta root Application yarating. Cluster'dagi hamma Application'ni o'chirib, faqat root'ni `kubectl apply` qilish orqali hammasini tiklang.

11. **ApplicationSet.** 10-vazifadagi ikki Application'ni git directory generator'li bitta ApplicationSet bilan almashtiring. `staging` overlay papkasini qo'shib commit qiling: yangi Application o'zi paydo bo'ldimi? App-of-apps ga nisbatan afzalligi va xavfi nima?

12. **AppProject boundary.** Faqat sizning repo'ngizdan, faqat `app-*` namespace'lariga, cluster-scoped resurslarsiz deploy qilishga ruxsat beradigan `AppProject` yarating. Application'ni unga o'tkazing. Keyin Application'ga `kube-system` ga deploy qiladigan yoki ClusterRole yaratadigan manifest qo'shib ko'ring va xatoni yozing.

### C. Flux

13. **Bootstrap Flux.** `flux` kind cluster'ida `flux check --pre`, keyin `flux bootstrap github` (`--path=clusters/flux-lab`). Repo'da qanday fayllar va GitHub'da qanday kalit paydo bo'ldi? `flux-system` dagi controller'larni sanab chiqing.

14. **Flux Kustomization.** `dev` overlay uchun Flux `Kustomization` yozib `clusters/flux-lab/` ga commit qiling (cluster'ga `kubectl apply` qilmang). `flux get kustomizations` da `Ready` bo'lishini kuzating. `flux reconcile ... --with-source` nima qiladi va qachon kerak?

15. **Drift and prune in Flux.** Cluster'da Deployment'ni `kubectl scale` va `kubectl edit` bilan o'zgartiring. Qancha vaqtda qaytdi va bu qaysi maydonga bog'liq? Git'dan resursni o'chirib `prune` ni kuzating. Keyin `flux suspend` qilib yana drift yarating: nima o'zgardi?

16. **HelmRelease.** `HelmRepository` va `HelmRelease` orqali `podinfo` chart'ini (https://stefanprodan.github.io/podinfo) deploy qiling, values'da replica sonini bering. `helm list -A` da ko'rinadimi? Chart versiyasi oralig'ini toraytirib commit qiling va upgrade'ni kuzating.

17. **dependsOn ordering.** `infrastructure` (namespace va bitta ConfigMap) va `apps` Kustomization'larini ajrating, `apps` `infrastructure` ga `dependsOn` bo'lsin. `infrastructure` ni ataylab buzing (noto'g'ri YAML). `apps` holati nima bo'ldi, xabar qayerda ko'rinadi?

18. **Image automation.** Ikki variantdan birini amalga oshiring va ikkinchisini qog'ozda loyihalang: (a) Flux image automation controller'lari bilan tag'ni avtomatik yangilash, (b) ilova repo'sidagi CI config repo'ga image digest'ni yangilaydigan PR ochadi. Har birida git'ga kim yozadi, qanday huquq bilan, review qayerda?

### D. Taqqoslash

19. **Argo CD vs Flux.** O'z tajribangizdan (hujjatdan emas) kamida olti mezon bo'yicha jadval tuzing: o'rnatish, birinchi deploy'gacha qadamlar, xatoni topish qulayligi, drift bilan ishlash, tartib (wave/dependsOn), rollback. Yakuniy loyiha uchun qaysi birini tanlaysiz va nima uchun?

20. **Incident runbook.** Tanlagan asbobingiz uchun yarim sahifalik runbook yozing: production'da noto'g'ri versiya deploy bo'ldi. Qadamlar: aniqlash, reconciliation'ni to'xtatish kerakmi, qaytarish (git orqali), tekshirish, qo'lda qilingan o'zgarishlarni git'ga qaytarish. Har qadamda aniq buyruq.

Yo'nalishlar (yechim emas, qayerga qarash kerakligi):

- 1–2: 10-bo'lim; digest'ni Kustomize'ning `images:` bloki orqali berish 9-darsda bor. 1-bo'limdagi push/pull jadvali boshlanish nuqtasi, "hujumchi nima qila oladi" ustunini o'zingiz o'ylang.
- 3–5: 2–3 bo'limlar va "Birga bajaramiz". `dex` va `notifications` uchun Argo CD hujjatidagi "Architecture" sahifasi.
- 6–8: 4-bo'lim. Vaqtni o'lchashda polling oralig'ini hisobga oling; `--refresh` ishlatsangiz README'da yozing.
- 9: 5-bo'lim; hook Job'lari uchun 5-darsdagi `backoffLimit` va delete policy.
- 10–12: 6-bo'lim. 10-vazifada root Application'ning nusxasi ish papkasida qoladi (Laboratoriya, tiklash).
- 13: 7-bo'lim; `--token-auth` ishlatmang, deploy key yo'lini ko'ring. Token Laboratoriyadagidek `read -rs` bilan.
- 14–17: 8-bo'lim. 15 uchun 8-bo'limdagi "Mexanizm" va server-side apply field manager'lari; `kubectl get deploy <nom> --show-managed-fields -o yaml` foydali.
- 18: 9-bo'lim. (a) uchun bootstrap'ni `--components-extra` va `--read-write-key` bilan qayta ishga tushirish kerak bo'ladi.
- 19–20: 4 va 8-bo'limlardagi `suspend` va auto-sync'ni o'chirish yo'llari; 11-bo'lim.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 20 vazifa yozilgan, bootstrap manifestlari nusxasi papkada.
2. `make check` toza.
3. `k8s-gitops` repo'sida Secret manifesti, token va kubeconfig yo'q (tarixda ham, 10-bo'limdagi `git log -S` bilan tekshiring).
4. Ikkala kind cluster o'chirilgan, GitHub token revoke qilingan, deploy key'lar o'chirilgan.
5. README'da config repo havolasi va asosiy commit'lar.
6. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- GitOps'ning to'rt tamoyili qaysi va push-based deploy qaysi birlarini buzadi?
- Sync status va health status farqi nima? `Synced` + `Degraded` qanday holat?
- `prune` va `selfHeal` har biri nimani boshqaradi? Ikkalasi o'chiq bo'lsa nima avtomatik qoladi?
- Avtomatik sync yoqilgan Application'da `argocd app rollback` nima uchun ishlamaydi?
- Flux `Kustomization` va Kustomize `kustomization.yaml` farqi nima?
- Argo CD va Flux Helm chart bilan qanday har xil ishlaydi?
- Flux bootstrap'dan keyin GitHub token nima uchun endi kerak emas (deploy key yo'lida)?
- Muhitlar uchun nima uchun branch emas, papka?
- GitOps'da CI'ning mas'uliyati qayerda tugaydi?
- HPA va GitOps controller `replicas` ustida nima uchun to'qnashadi?
