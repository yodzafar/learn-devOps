# 10-dars: GitOps: Argo CD va Flux

Maqsad: 9-darsda pipeline cluster'ga tashqaridan kirib deploy qildi va bu modelning chegaralari ko'rindi: credential CI'da, drift ko'rinmaydi, haqiqat manbai pipeline log'i. GitOps'da cluster ichidagi controller git repo'ni kuzatadi va cluster holatini unga moslab turadi. Bu darsda GitOps tamoyillari, Argo CD (Application, sync policy, app-of-apps, ApplicationSet, wave va hook'lar, project'lar) va Flux (GitRepository, Kustomization, HelmRelease, bootstrap, image automation) ko'riladi. Keyingi darslardagi hamma narsa (HA sozlamalari, operator'lar, NetworkPolicy, autoscaler'lar) va yakuniy loyiha shu usulda deploy qilinadi.

Taxminiy vaqt: 4 kun (siz uchun). Ikki asbobni ham qo'lda sinaysiz: 2 kun Argo CD, 1.5 kun Flux, yarim kun taqqoslash va repo tuzilishi. Diqqat: reconciliation sikli, `prune` va `selfHeal` semantikasi, GitOps'da rollback nima degani, CI va CD orasidagi chegara.

## Laboratoriya

- **Git repo**: GitHub'da yangi `k8s-gitops` repo (config repo). Sodda bo'lishi uchun public, ichida secret bo'lmaydi. Ilova kodi repo'si alohida qoladi.
- **Cluster**: kind. Argo CD qismi uchun `kind create cluster --name argo`, Flux qismi uchun alohida `kind create cluster --name flux`. Ikkalasini bitta cluster'da bir xil resurslarga qo'ymang: ikki controller bir-birining o'zgarishini qaytarib turadi.
- **Argo CD CLI**: https://argo-cd.readthedocs.io/en/stable/cli_installation/
- **Flux CLI**: https://fluxcd.io/flux/installation/#install-the-flux-cli
- Flux bootstrap uchun GitHub personal access token kerak (repo'ga yozish huquqi bilan). Uni faqat `export GITHUB_TOKEN=...` orqali shell'da saqlang, faylga yozmang.
- Tozalash: `kind delete cluster --name argo`, `kind delete cluster --name flux`, GitHub'dagi token'ni revoke qiling. Flux bootstrap repo'ga deploy key qo'shadi, uni ham o'chiring.

---

## 1. GitOps tamoyillari

OpenGitOps (CNCF) to'rt tamoyili:

1. **Declarative.** Tizimning istalgan holati deklarativ yoziladi (manifest, chart, overlay), buyruqlar ketma-ketligi sifatida emas.
2. **Versioned and immutable.** Istalgan holat to'liq tarixi bilan versiyalangan joyda saqlanadi. Amalda git: har o'zgarish commit, PR, review.
3. **Pulled automatically.** Agent istalgan holatni manbadan o'zi tortib oladi. Hech kim cluster'ga tashqaridan push qilmaydi.
4. **Continuously reconciled.** Agent haqiqiy holatni uzluksiz kuzatadi va farqni yo'qotadi.

### Push va pull

| | Push (9-dars) | Pull (GitOps) |
|---|---------------|---------------|
| Cluster credential | CI tizimida | cluster ichida, tashqariga chiqmaydi |
| Tarmoq yo'nalishi | CI -> API server (kirish ochiq bo'lishi kerak) | cluster -> git (faqat chiqish) |
| Drift | keyingi pipeline'gacha ko'rinmaydi | daqiqalar ichida aniqlanadi |
| Haqiqat manbai | oxirgi muvaffaqiyatli job | git commit |
| Rollback | pipeline'ni qayta ishga tushirish | `git revert` |
| Audit | CI log'lari | git tarixi |

### Reconciliation va drift

Controller siklda ishlaydi: git'dan manifestlarni oladi va render qiladi (istalgan holat), cluster'dagi obyektlarni o'qiydi (haqiqiy holat), farqni hisoblaydi, farq bo'lsa qo'llaydi. Bu Kubernetes'ning o'z controller modeli (1-dars), faqat "spec" endi git'da.

Drift: cluster holati git'dan ajralishi. Manbalari: `kubectl edit` bilan shoshilinch tuzatish, boshqa controller yozgan maydonlar (HPA `replicas` ni o'zgartiradi, 14-dars), mutating webhook'lar. Birinchisi yo'qotilishi kerak, qolgan ikkitasi "kutilgan farq" va ularni e'tiborsiz qoldirish sozlanadi (Argo CD'da `ignoreDifferences`).

### CI va CD chegarasi

GitOps'da CI cluster'ga tegmaydi. CI'ning oxirgi qadami: config repo'da image tag yoki digest'ni yangilaydigan commit (to'g'ridan-to'g'ri yoki PR). Qolganini cluster ichidagi controller qiladi.

```
app repo:    push -> test -> build -> push image
config repo: commit "app: sha256:9b1e..." (CI yoki image automation)
cluster:     controller pull -> diff -> apply -> health
```

## 2. Argo CD

Argo CD cluster'da ishlaydigan bir nechta komponent: API server (UI, CLI, SSO), repo server (git clone va render: Kustomize, Helm, oddiy YAML), application controller (diff va sync), Redis (cache), ApplicationSet controller.

### O'rnatish

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd admin initial-password -n argocd
argocd login localhost:8080
```

`--server-side` kerak, chunki CRD'lar client-side apply'ning annotation hajmi chegarasidan katta. Parolni birinchi kirishdan keyin almashtiring.

### Application

Asosiy CRD: "shu git yo'lini shu cluster'ning shu namespace'iga joylashtir".

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: app-dev, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/me/k8s-gitops.git
    targetRevision: main
    path: apps/app/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: app-dev
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: ["CreateNamespace=true"]
```

Ikki mustaqil holat:

| Holat | Qiymatlar | Ma'nosi |
|-------|-----------|---------|
| Sync status | `Synced`, `OutOfSync` | cluster git'ga mosmi |
| Health status | `Healthy`, `Progressing`, `Degraded`, `Missing` | resurslar ishlayaptimi (Deployment rollout, Pod holati) |

`Synced` + `Degraded` odatiy holat: manifest qo'llangan, lekin Pod `CrashLoopBackOff` da. Sync muvaffaqiyati ilova ishlayotganini anglatmaydi.

### Sync policy

| Sozlama | Yo'q bo'lsa | Bor bo'lsa |
|---------|-------------|------------|
| `automated` | farq ko'rsatiladi, sync qo'lda (`argocd app sync`) | git o'zgarsa avtomatik sync |
| `prune` | git'dan o'chirilgan resurs cluster'da qoladi (`OutOfSync` ko'rinadi) | cluster'dan ham o'chiriladi |
| `selfHeal` | cluster'dagi qo'lda o'zgarish qoladi, faqat git o'zgarganda sync | cluster'dagi drift ham qaytariladi |

- Git polling default taxminan har 2–3 daqiqada. Tezroq bo'lishi uchun git webhook sozlanadi.
- Avtomatik sync bir xil commit va parametrlar bilan muvaffaqiyatsiz bo'lsa qayta urinmaydi, `retry` alohida sozlanadi.
- `prune: true` bilan git'dagi papkani tasodifan bo'shatish hamma narsani o'chirishi mumkin edi. Himoya bor: resurslar ro'yxati butunlay bo'sh bo'lsa sync rad etiladi (`allowEmpty` bilan o'chiriladi). Qisman o'chirishdan himoya yo'q.

**Tuzoq: `selfHeal` va shoshilinch tuzatish.** Incident paytida `kubectl scale` yoki `kubectl edit` qilsangiz, o'zgarish bir necha soniyada qaytariladi. To'g'ri yo'l: git'ga commit. Favqulodda holatda avval Application'da auto-sync'ni o'chirish kerak, buni incident'dan oldin bilib qo'ying.

### Rollback

`argocd app history` va `argocd app rollback` oldingi sync qilingan revision'ga qaytaradi, lekin avtomatik sync yoqilgan Application'da rollback bajarib bo'lmaydi: controller darhol git'dagi holatga qaytarar edi. GitOps'da rollback bu `git revert` va odatiy sync. Tarix git'da qoladi, kim va nima uchun qaytargani ko'rinadi.

### Sync wave va hook'lar

Bir sync ichida tartib kerak bo'ladi: avval namespace va CRD, keyin operator, keyin uning custom resource'lari; migratsiya Job'i yangi versiyadan oldin.

- **Wave**: `argocd.argoproj.io/sync-wave: "N"` annotation. Kichik son avval, default 0, manfiy bo'lishi mumkin. Keyingi wave oldingisi `Healthy` bo'lgandan keyin boshlanadi.
- **Hook**: `argocd.argoproj.io/hook: PreSync | Sync | PostSync | SyncFail` annotation'li resurs (odatda Job, 5-dars). `PreSync` DB migratsiyasi, `PostSync` smoke test uchun. `argocd.argoproj.io/hook-delete-policy` bilan tugagan hook tozalanadi.

### App-of-apps va ApplicationSet

O'nlab Application'ni qo'lda `kubectl apply` qilish GitOps emas. Ikki yechim:

- **App-of-apps**: bitta "root" Application git'dagi papkaga qaraydi, u papkada boshqa Application manifestlari yotadi. Cluster'ga qo'lda faqat root qo'yiladi (bootstrap).
- **ApplicationSet**: generator'dan (list, git papkalari yoki fayllari, cluster'lar ro'yxati, matrix) template orqali Application'lar yaratadigan CRD. "Har overlay papkasi uchun bitta Application" yoki "har cluster uchun shu ilova" kabi holatlar uchun.

### Project va RBAC

`AppProject` Application'lar uchun chegara: qaysi repo'lardan (`sourceRepos`), qaysi cluster va namespace'larga (`destinations`), qaysi resurs turlarini (`clusterResourceWhitelist`) deploy qilish mumkin. `default` project hammasiga ruxsat beradi, jamoalar uchun alohida project yaratiladi. Argo CD'ning o'z RBAC'i (`argocd-rbac-cm` ConfigMap) kim qaysi project'dagi Application'ni ko'rishi va sync qilishi mumkinligini belgilaydi. Bu Kubernetes RBAC'dan alohida qatlam: Argo CD controller cluster'da keng huquqqa ega, shuning uchun Argo CD'ga kirish huquqi amalda cluster'ga kirish huquqi.

## 3. Flux

Flux alohida controller'lar to'plami (GitOps Toolkit), har biri o'z CRD'lari bilan. UI yo'q, hamma narsa `kubectl` va `flux` CLI orqali.

| Controller | CRD'lar | Vazifasi |
|------------|---------|----------|
| source-controller | `GitRepository`, `OCIRepository`, `HelmRepository`, `Bucket` | manbani olib artefakt qiladi |
| kustomize-controller | `Kustomization` | manifest/Kustomize'ni qo'llaydi, prune, health check |
| helm-controller | `HelmRelease` | Helm release'ni boshqaradi |
| notification-controller | `Provider`, `Alert`, `Receiver` | xabarnoma va webhook |
| image-reflector, image-automation (ixtiyoriy) | `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` | image tag'larini kuzatib git'ni yangilaydi |

### Bootstrap

```bash
export GITHUB_TOKEN=<token>
flux check --pre
flux bootstrap github --token-auth --owner=<user> --repository=k8s-gitops \
  --branch=main --path=clusters/lab --personal
```

Bootstrap controller'larni o'rnatadi, ularning manifestlarini repo'ning `clusters/lab/flux-system/` papkasiga commit qiladi va Flux'ni shu repo'dan o'zini ham yangilaydigan qilib sozlaydi. Ya'ni Flux birinchi kundan o'zini GitOps bilan boshqaradi. Buyruq idempotent, qayta ishga tushirish xavfsiz.

### GitRepository va Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: { name: app-dev, namespace: flux-system }
spec:
  interval: 10m
  sourceRef: { kind: GitRepository, name: flux-system }
  path: ./apps/app/overlays/dev
  prune: true
  wait: true
  timeout: 3m
```

- `GitRepository` (`source.toolkit.fluxcd.io/v1`): `url`, `ref.branch`, `interval`. Bootstrap `flux-system` nomlisini o'zi yaratadi.
- Flux `Kustomization` (`kustomize.toolkit.fluxcd.io`) va Kustomize'ning `kustomization.yaml` fayli (`kustomize.config.k8s.io`) ikki xil narsa. Birinchisi "shu yo'lni qo'lla" degan CRD, ikkinchisi overlay ta'rifi.
- `interval` drift'ni tuzatish davri: Flux har intervalda qayta qo'llaydi, ya'ni self-heal har doim yoqilgan.
- `prune: true` git'dan o'chirilganni cluster'dan o'chiradi. `wait: true` qo'llangan resurslar tayyor bo'lguncha kutadi, aks holda `Ready=False`.
- `dependsOn` boshqa Kustomization tayyor bo'lishini kutadi (Argo CD wave'larining o'rnini bosadi): avval `infrastructure`, keyin `apps`.

### HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata: { name: podinfo, namespace: apps }
spec:
  interval: 30m
  chart:
    spec:
      chart: podinfo
      version: "6.x"
      sourceRef: { kind: HelmRepository, name: podinfo, namespace: flux-system }
  values: { replicaCount: 2 }
```

Helm-controller haqiqiy Helm release yaratadi (`helm list` da ko'rinadi), upgrade muvaffaqiyatsiz bo'lsa remediation (rollback, retry) sozlanadi. Argo CD esa chart'ni faqat `helm template` qilib manifest sifatida qo'llaydi, Helm release yaratmaydi, Helm hook'lari Argo CD hook'lariga map qilinadi.

### Kundalik buyruqlar

`flux get kustomizations`, `flux get sources git`, `flux reconcile kustomization app-dev --with-source` (intervalni kutmasdan), `flux suspend` va `flux resume` (incident paytida reconciliation'ni to'xtatish), `flux logs`, `flux uninstall`.

### Image update automation

CI image push qiladi, config repo'ni kim yangilaydi? Flux'da ixtiyoriy ikki controller (`flux bootstrap ... --components-extra=image-reflector-controller,image-automation-controller`): `ImageRepository` registry'ni skanerlaydi, `ImagePolicy` qaysi tag eng yangi ekanini tanlaydi (semver, alifbo, raqam tartibi), `ImageUpdateAutomation` manifestdagi marker qo'yilgan qatorni yangilab commit qiladi:

```yaml
image: ghcr.io/me/app:1.4.2 # {"$imagepolicy": "flux-system:app"}
```

Buning uchun Flux'ga git'ga yozish huquqi kerak. Tag'lar tartiblanadigan bo'lishi shart: faqat commit SHA tartib bermaydi, shuning uchun `main-<run_number>-<sha>` kabi tag yoki semver ishlatiladi. Argo CD'da shu vazifani alohida loyiha Argo CD Image Updater bajaradi. Eng sodda va eng shaffof variant esa CI'ning o'zi config repo'ga commit yoki PR ochishi.

## 4. Git'da secret muammosi

GitOps "hamma narsa git'da" deydi, lekin Secret manifesti faqat base64 (13-dars), uni git'ga qo'yish parolni ochiq yozish bilan teng. Yechimlar ikki turga bo'linadi: git'da shifrlangan holda saqlash (Sealed Secrets, SOPS; Flux SOPS'ni o'zi ochadi) yoki git'da faqat havola saqlab, qiymatni tashqi secret manager'dan olish (External Secrets Operator). 13-darsda uchalasini qo'lda sinaysiz. Bu darsda qoida: config repo'ga hech qanday Secret manifesti tushmaydi.

## 5. Argo CD va Flux

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
| Image yangilash | alohida Image Updater | o'rnatilgan controller'lar |
| Secret | plugin yoki tashqi operator | SOPS o'rnatilgan |
| CNCF | Graduated | Graduated |

Tanlov odatda texnik emas, tashkiliy: dasturchilarga ko'rinadigan UI va markaziy boshqaruv kerak bo'lsa Argo CD, platforma jamoasi hamma narsani CRD va git orqali boshqarsa Flux. Ikkalasi ham bir xil tamoyilni amalga oshiradi.

## 6. Repo tuzilishi

```
k8s-gitops/
  apps/
    app/
      base/
      overlays/{dev,staging,prod}/
  infrastructure/          # ingress/gateway, cert-manager, monitoring
  clusters/
    lab/                   # shu cluster nimani deploy qiladi (Application yoki Kustomization'lar)
```

- **Ilova kodi va config alohida repo'da.** Aks holda har image tag commit'i CI'ni qayta ishga tushiradi (cheksiz sikl), va kod review bilan deploy review aralashadi.
- **Muhit = papka, branch emas.** `dev`, `prod` branch'lari orasida merge vaqt o'tishi bilan cherry-pick va conflict'ga aylanadi, muhitlar orasidagi farqni `diff` bilan ko'rib bo'lmaydi. Papkalarda farq overlay faylida ochiq yotadi.
- **Promotion**: dev overlay'dagi image digest'ni prod overlay'ga ko'chiradigan PR. Review va approval shu yerda.
- `main` ga to'g'ridan-to'g'ri push cluster'ga to'g'ridan-to'g'ri deploy. Branch protection va majburiy review GitOps'ning xavfsizlik chegarasi.

## Tuzoqlar

- Config repo'ga Secret manifestini (yoki `.env`, kubeconfig) commit qilish. Git tarixidan o'chirish qiyin, secret'ni almashtirish shart.
- `selfHeal`/Flux reconciliation yoqilgan cluster'da qo'lda tuzatish: o'zgarish jim qaytariladi, incident cho'ziladi.
- `prune` ni yoqib, resursni git'da boshqa papkaga ko'chirish yoki nomini o'zgartirish: eski obyekt o'chiriladi, PVC bo'lsa ma'lumot bilan birga.
- HPA boshqaradigan Deployment'da `replicas` ni git'da qoldirish: GitOps controller va HPA bir-biri bilan kurashadi. `replicas` manifestdan olib tashlanadi yoki farq e'tiborga olinmaydi.
- `Synced` ni "ishlayapti" deb o'qish. Health holatiga va alert'larga qarang.
- Muhitlar uchun uzoq yashaydigan branch'lar.
- `targetRevision: HEAD` va `main` ga himoyasiz push: review'siz production deploy.
- Argo CD UI'ni autentifikatsiyasiz yoki default admin paroli bilan ochiq qoldirish. Argo CD admin = cluster admin.
- Bitta resursni ikki Application yoki ikki Kustomization boshqarishi: ular navbat bilan bir-birini qayta yozadi.
- Image automation uchun tartiblanmaydigan tag'lar (faqat SHA): policy "eng yangi" ni aniqlay olmaydi.

## Manbalar

- https://opengitops.dev/ – GitOps tamoyillari
- https://argo-cd.readthedocs.io/en/stable/getting_started/ – Argo CD o'rnatish
- https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ – automated sync, prune, self-heal
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ – sync wave va hook'lar
- https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/ – app-of-apps
- https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/ – ApplicationSet
- https://argo-cd.readthedocs.io/en/stable/user-guide/projects/ – AppProject
- https://fluxcd.io/flux/concepts/ – Flux asosiy tushunchalari
- https://fluxcd.io/flux/installation/bootstrap/github/ – bootstrap
- https://fluxcd.io/flux/components/kustomize/kustomizations/ – Kustomization CRD
- https://fluxcd.io/flux/components/helm/helmreleases/ – HelmRelease CRD
- https://fluxcd.io/flux/guides/image-update/ – image update automation
- https://fluxcd.io/flux/guides/repository-structure/ – repo tuzilishi variantlari

---

## Vazifalar

Barchasini `kubernetes/10-gitops/` da hujjatlashtiring (`make new m=kubernetes n=10 name=gitops`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlarning o'zi `k8s-gitops` repo'sida yashaydi, README'da commit havolalari bo'lsin. Cluster'ga qo'lda qo'yilgan bootstrap manifestlarining nusxasini ish papkasiga saqlang.

### A. Tamoyillar va repo

1. **Config repo layout.** `k8s-gitops` repo'sini yarating va 9-darsdagi ilovangizning Kustomize base va `dev`, `prod` overlay'larini 6-bo'limdagi tuzilishga joylang. Image digest bilan ko'rsatilsin. Nima uchun ilova repo'siga emas, alohida repo'ga qo'yganingizni 3–4 gapda yozing.

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

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. `k8s-gitops` repo'sida Secret manifesti, token va kubeconfig yo'q (tarixda ham).
3. Ikkala kind cluster o'chirilgan, GitHub token revoke qilingan, deploy key o'chirilgan.
4. README'da config repo havolasi va asosiy commit'lar.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- GitOps'ning to'rt tamoyili qaysi va push-based deploy qaysi birlarini buzadi?
- Sync status va health status farqi nima? `Synced` + `Degraded` qanday holat?
- `prune` va `selfHeal` har biri nimani boshqaradi? Ikkalasi o'chiq bo'lsa nima avtomatik qoladi?
- Avtomatik sync yoqilgan Application'da `argocd app rollback` nima uchun ishlamaydi?
- Flux `Kustomization` va Kustomize `kustomization.yaml` farqi nima?
- Argo CD va Flux Helm chart bilan qanday har xil ishlaydi?
- Muhitlar uchun nima uchun branch emas, papka?
- GitOps'da CI'ning mas'uliyati qayerda tugaydi?
- HPA va GitOps controller `replicas` ustida nima uchun to'qnashadi?
