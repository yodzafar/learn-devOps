# 9-dars: CI/CD bilan integratsiya

Maqsad: cicd modulida pipeline image'ni build qilib registry'ga push qilgan edi, 3–8-darslarda esa manifestlarni qo'lda `kubectl apply` qildingiz. Bu darsda ikkalasi ulanadi: commit'dan cluster'dagi yangi Pod'gacha bo'lgan yo'l avtomatlashadi. Image'ni SHA va digest bilan belgilash, muhitlar uchun Kustomize overlay va Helm chart yozish, manifestni CI'da validatsiya qilish, pipeline'ga cluster'da eng kam huquq berish va rollout natijasini pipeline holatiga bog'lash ko'riladi. Oxirida push-based deploy'ning chegaralari chiqadi, 10-dars (GitOps) aynan shu chegaralarga javob.

Taxminiy vaqt: 3 kun (siz uchun). GitHub Actions sintaksisi tanish, diqqatni quyidagilarga qarating: tag va digest farqi, Kustomize va Helm qachon qaysi biri, deploy uchun ServiceAccount'ning aniq RBAC'i, `--dry-run=server` va kubeconform nimani ushlaydi va nimani ushlamaydi, `rollout status` exit code'i.

## Laboratoriya

- **GitHub repo**: cicd modulidagi ilovangiz (Dockerfile'i bor har qanday HTTP servis). Image GitHub Container Registry'ga (`ghcr.io/<user>/<repo>`) push qilinadi.
- **Lokal cluster**: kind (2-darsda o'rnatilgan). `kind create cluster --name cicd`, oxirida `kind delete cluster --name cicd`.
- **Pipeline ichidagi cluster**: GitHub-hosted runner sizning noutbukingizdagi kind'ga yeta olmaydi. Shuning uchun pipeline o'z ichida vaqtinchalik kind cluster yaratadi (`helm/kind-action`) va deploy'ni shu cluster'ga qiladi. Bu haqiqiy muhitga deploy'ning barcha qadamlarini (auth, RBAC, rollout gate) takrorlaydi, cluster esa job bilan birga yo'qoladi.
- **Asboblar**: `kubectl` va `helm` bor (2 va 8-darslar). `ubuntu-latest` runner'da `kubectl`, `helm`, `kustomize` va `kind` oldindan o'rnatilgan. Lokal kubeconform: https://github.com/yannh/kubeconform#installation (yoki `docker run --rm -i ghcr.io/yannh/kubeconform:latest`).
- Kubeconfig va token fayllari ish papkasiga tushsa `.gitignore` ga qo'shing, commit qilmang.

---

## 1. Commit'dan Pod'gacha: zanjir

```
git push -> CI: test -> build image -> push registry
         -> render manifests (Kustomize/Helm) -> validate
         -> deploy (kubectl/helm) -> rollout status -> smoke test
```

Har bo'g'in o'z savoliga javob beradi: qaysi kod (commit SHA), qaysi artefakt (image digest), qaysi konfiguratsiya (render qilingan manifest), kim deploy qildi (pipeline identifikatsiyasi), muvaffaqiyatli bo'ldimi (rollout holati). Bittasi noaniq bo'lsa, "production'da hozir nima ishlayapti" savoliga javob yo'q.

## 2. Image tag: SHA va digest

| Belgi | Misol | O'zgaruvchanmi | Qachon |
|-------|-------|----------------|--------|
| `latest` | `app:latest` | ha | hech qachon deploy uchun |
| semver | `app:1.4.2` | ha (qayta push mumkin) | release'lar, odam o'qishi uchun |
| commit SHA | `app:3f2c1ab` | amalda yo'q | har commit, kodga izlanadi |
| digest | `app@sha256:9b1e...` | yo'q (kontent hash) | production manifest |

- Tag registry'dagi ko'rsatkich, uni boshqa image'ga ko'chirish mumkin. Digest image manifestining SHA-256 hash'i, bitta bayt o'zgarsa digest o'zgaradi.
- `image: app:1.4.2` yozilgan Deployment'da node'lar har xil vaqtda pull qilsa va tag orada ko'chirilgan bo'lsa, bitta ReplicaSet ichida ikki xil kod ishlaydi. Digest bilan bu mumkin emas.
- `imagePullPolicy` default'i: tag `latest` yoki tag yo'q bo'lsa `Always`, aks holda `IfNotPresent`. Shuning uchun bir xil tag'ni qayta push qilish node cache'idagi eski image'ni yangilamaydi.
- Deployment'da tag o'zgarmasa Pod template o'zgarmaydi, demak rollout bo'lmaydi. `latest` ni qayta push qilib `kubectl apply` qilish hech narsa qilmaydi.

Build qadamidan digest olish (`docker/build-push-action` `digest` output beradi):

```yaml
- id: push
  uses: docker/build-push-action@v6
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
- run: echo "IMAGE=ghcr.io/${{ github.repository }}@${{ steps.push.outputs.digest }}" >> "$GITHUB_ENV"
```

Action major versiyalari o'zgarib turadi, yozishdan oldin action sahifasidagi joriy versiyani tekshiring. Supply chain uchun action'lar tag emas, commit SHA bilan pin qilinadi (GitHub'ning o'z misollari shunday).

`GITHUB_TOKEN` bilan GHCR'ga push uchun job'da `permissions: packages: write` kerak. Private image'ni cluster pull qilishi uchun namespace'da `kubectl create secret docker-registry` bilan yaratilgan Secret va Pod'da `imagePullSecrets` bo'lishi shart, aks holda `ImagePullBackOff`.

## 3. Muhitlar uchun manifest: Kustomize

Dev, staging va prod manifestlari 90% bir xil: farq replica soni, image, resurslar, hostname. Nusxa ko'chirish drift'ga olib keladi. Kustomize `kubectl` ichiga o'rnatilgan (`kubectl apply -k`, `kubectl kustomize`), template tili yo'q, oddiy YAML ustiga patch qo'yadi.

```
deploy/
  base/            deployment.yaml service.yaml kustomization.yaml
  overlays/
    dev/           kustomization.yaml
    prod/          kustomization.yaml replicas-patch.yaml
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: app-prod
resources:
  - ../../base
images:
  - name: ghcr.io/me/app
    digest: sha256:9b1e...
patches:
  - path: replicas-patch.yaml
```

| Kalit | Vazifasi |
|-------|----------|
| `resources` | base yoki fayllar ro'yxati |
| `namespace`, `namePrefix`, `labels` | hamma resursga bir xil o'zgarish |
| `images` | image nomi, `newTag` yoki `digest` almashtirish |
| `patches` | strategic merge yoki JSON 6902 patch |
| `replicas` | Deployment replica sonini almashtirish |
| `configMapGenerator`, `secretGenerator` | fayldan ConfigMap/Secret, nomiga kontent hash qo'shiladi |

`configMapGenerator` ning hash suffiksi muhim mexanizm: ConfigMap kontenti o'zgarsa nomi o'zgaradi, Deployment'dagi havola ham o'zgaradi, natijada rollout boshlanadi. Oddiy ConfigMap'ni o'zgartirish Pod'larni qayta ishga tushirmaydi (4-darsdagi kuzatuv).

Render: `kubectl kustomize deploy/overlays/prod`. CI'da image'ni almashtirish uchun alohida `kustomize` binary'sining `kustomize edit set image` buyrug'i ishlatiladi (https://kubectl.docs.kubernetes.io/installation/kustomize/).

## 4. Ilova uchun Helm chart

8-darsda tayyor chart'larni o'rnatdingiz. Endi o'zingiznikini yozasiz. `helm create app` skelet beradi:

```
app/
  Chart.yaml        # apiVersion: v2, name, version (chart), appVersion (app)
  values.yaml       # default qiymatlar
  templates/        # Go template'li manifestlar, _helpers.tpl, NOTES.txt
```

```yaml
# templates/deployment.yaml (fragment)
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}@{{ .Values.image.digest }}"
          resources: {{- toYaml .Values.resources | nindent 12 }}
```

- `version` chart'ning versiyasi, `appVersion` ilovaniki. Ikkalasi mustaqil o'zgaradi.
- Qiymat ustunligi: `values.yaml` < `-f values-prod.yaml` < `--set key=value`.
- `helm lint ./app`: chart tuzilishi va template xatolari. `helm template rel ./app -f values-prod.yaml`: cluster'siz to'liq render, CI'da validatsiya uchun asosiy kirish.
- `helm upgrade --install rel ./app -n ns --wait --timeout 3m`: release yo'q bo'lsa o'rnatadi, bor bo'lsa yangilaydi, resurslar tayyor bo'lguncha kutadi. Muvaffaqiyatsiz bo'lsa avtomatik orqaga qaytarish flag'i Helm 3'da `--atomic`, Helm 4'da `--rollback-on-failure` (`helm upgrade --help` bilan o'z versiyangizni tekshiring).
- `helm history rel`, `helm rollback rel <revision>`: release tarixi cluster'dagi Secret'larda saqlanadi.

| | Kustomize | Helm |
|---|-----------|------|
| Model | YAML ustiga patch | template + values |
| O'rganish | past | template tili, helper'lar |
| Tarqatish | git papka | versiyalangan paket (OCI registry) |
| Release tarixi, rollback | yo'q | bor |
| Qachon | o'z ilovangiz, bir necha muhit | boshqalarga beriladigan yoki ko'p parametrli ilova |

**Tuzoq: template ichidagi YAML indentatsiyasi.** `toYaml` dan keyin `nindent` soni noto'g'ri bo'lsa `helm lint` o'tishi, lekin manifest noto'g'ri joyga tushishi mumkin. Har doim `helm template` natijasini o'qing va validatsiyadan o'tkazing.

## 5. CI'da validatsiya

Xato qanchalik erta ushlansa shuncha arzon. Qatlamlar:

| Tekshiruv | Cluster kerakmi | Nimani ushlaydi | Nimani ushlamaydi |
|-----------|-----------------|-----------------|-------------------|
| `helm lint`, `kubectl kustomize` | yo'q | render xatosi | noto'g'ri maydon nomi |
| `kubeconform -strict` | yo'q | schema: noma'lum maydon, noto'g'ri tip, eski `apiVersion` | admission, quota, mavjud resurs bilan ziddiyat |
| `kubectl apply --dry-run=client` | yo'q | sintaksis | deyarli hech narsa, schema'ni to'liq tekshirmaydi |
| `kubectl apply --dry-run=server` | ha | API server validatsiyasi, admission webhook'lar, immutable maydonlar | image mavjudmi, Pod ishga tushadimi |
| `kubectl diff` | ha | cluster bilan farq (exit code 1 = farq bor) | |

```bash
helm template rel ./app -f values-prod.yaml \
  | kubeconform -strict -summary -kubernetes-version 1.33.0 -
```

- `-strict` schema'da yo'q maydonni xato deb oladi (masalan `replcas` typo'si, usiz jim o'tib ketadi).
- `-kubernetes-version` ni maqsad cluster versiyasiga qo'ying: upgrade'dan oldin o'chirilgan API'larni shu yerda ushlaysiz.
- CRD'lar (cert-manager `Certificate`, Argo CD `Application`) default schema'larda yo'q. `-ignore-missing-schemas` ularni o'tkazib yuboradi, `-schema-location` bilan CRD katalogi ulanadi (README'da misol bor).

`--dry-run=server` so'rovni API server'ga to'liq yuboradi, faqat etcd'ga yozmaydi. Shuning uchun u namespace mavjudligi, RBAC va Pod Security admission (13-dars) rad etishini ham ko'rsatadi.

## 6. Pipeline cluster'ga qanday kiradi

### ServiceAccount token

Cluster'da deploy uchun alohida ServiceAccount, uning token'i CI secret'ida:

- `kubectl create token deployer -n app --duration=24h` qisqa muddatli token beradi (TokenRequest API). Muddatsiz token faqat `kubernetes.io/service-account-token` tipidagi Secret'ni qo'lda yaratib olinadi, 1.24 dan beri avtomatik yaratilmaydi.
- Kubeconfig uch qismdan yig'iladi: cluster (server URL, CA), user (token), context (namespace bilan). `kubectl config set-cluster`, `set-credentials --token`, `set-context`, `--kubeconfig=fayl` bilan.
- Kamchilik: uzoq yashaydigan secret CI tizimida saqlanadi, sizib chiqsa muddati tugaguncha amal qiladi, rotatsiya qo'lda.

### OIDC (secret'siz)

GitHub Actions har job'ga imzolangan JWT bera oladi (`permissions: id-token: write`). Issuer `https://token.actions.githubusercontent.com`, `sub` claim'i `repo:<owner>/<repo>:ref:refs/heads/main` yoki `repo:<owner>/<repo>:environment:prod` ko'rinishida. Ikki yo'l:

- **Cloud orqali**: AWS'da IAM role shu OIDC provider'ga ishonadi (cloud modulida ko'rgansiz), `aws-actions/configure-aws-credentials` vaqtinchalik credential oladi, `aws eks update-kubeconfig` kubeconfig yozadi, EKS access entry esa IAM role'ni Kubernetes guruhiga bog'laydi.
- **To'g'ridan-to'g'ri API server'ga**: kube-apiserver `--authentication-config` faylidagi `AuthenticationConfiguration` (`apiserver.config.k8s.io/v1`, 1.34 dan stable) orqali tashqi JWT issuer'ga ishonadi. Token'dagi claim'lar username va guruhga map qilinadi, keyin oddiy RBAC.

Ikkalasida ham saqlanadigan secret yo'q, token bir necha daqiqa yashaydi va faqat aniq repo/branch/environment uchun beriladi.

### Least-privilege RBAC

Pipeline'ga `cluster-admin` berish eng ko'p uchraydigan xato. Deploy uchun faqat o'z namespace'ida, faqat o'zi boshqaradigan resurslarga huquq kerak (RBAC chuqur 13-darsda):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: deployer, namespace: app }
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
```

- `rollout status` uchun `deployments` ga `get/list/watch` yetmaydi, `replicasets` ga ham `get/list/watch` kerak bo'lishi mumkin. Buni taxmin qilmang, `kubectl auth can-i --list --as=system:serviceaccount:app:deployer -n app` va haqiqiy xato xabari bilan aniqlang.
- Helm release tarixini Secret'da saqlaydi, demak Helm bilan deploy qiladigan identifikatsiyaga namespace'dagi `secrets` ga yozish huquqi kerak. Bu o'sha namespace'dagi barcha Secret'larni o'qiy olish demak.
- `secrets` ni o'qish, `pods/exec`, `rolebindings` yaratish, `*` verb: bularning har biri amalda huquqni kengaytirish yo'li.

## 7. Rollout gate

`kubectl apply` muvaffaqiyati faqat "API server obyektni qabul qildi" degani. Pod'lar ishga tushdimi, readiness probe o'tdimi, bu alohida savol.

```bash
kubectl -n app rollout status deployment/app --timeout=120s
```

- Rollout tugasa exit code 0, timeout yoki `progressDeadlineSeconds` (default 600) oshsa noldan farqli. Pipeline shu yerda qizil bo'lishi kerak.
- Gate'ning sifati readiness probe sifatiga teng (4-dars). Probe yo'q bo'lsa konteyner start bo'lishi bilan "ready", gate har doim yashil.
- Muvaffaqiyatsiz rollout o'zi orqaga qaytmaydi: eski ReplicaSet ishlab turadi (`maxUnavailable` tufayli), yangi Pod'lar `CrashLoopBackOff` da qoladi. Pipeline `kubectl rollout undo` qilishi yoki Helm'ning avtomatik rollback flag'ini ishlatishi kerak.
- Gate'dan keyin smoke test: Service orqali `/healthz` ga so'rov. Rollout status faqat probe'ni ko'radi, biznes mantiqni emas.

## 8. Push-based deploy'ning chegaralari

Yuqoridagi model "push": CI cluster'ga tashqaridan kirib o'zgartiradi. Kichik jamoada ishlaydi, lekin:

1. **Credential tashqarida.** Cluster'ga yozish huquqi CI tizimida yashaydi. CI buzilsa cluster ham buziladi.
2. **Tarmoq.** API server CI runner'dan ochiq bo'lishi kerak. Private cluster uchun self-hosted runner yoki VPN.
3. **Drift ko'rinmaydi.** Kimdir `kubectl edit` qilsa, git va cluster ajraladi, keyingi pipeline ishga tushguncha hech kim bilmaydi.
4. **"Hozir nima deploy qilingan" pipeline log'ida.** Git'dagi manifest emas, oxirgi muvaffaqiyatli job haqiqat manbai bo'lib qoladi.
5. **Ko'p cluster.** Har cluster uchun credential, har biriga alohida deploy job.
6. **Rollback.** Eski pipeline'ni qayta ishga tushirish yoki qo'lda `rollout undo`, ikkalasi ham git tarixidan tashqarida.

GitOps bu modelni teskari qiladi: cluster ichidagi agent git'ni o'qiydi va o'zini unga moslaydi. CI'ning ishi image build va git'dagi manifestni yangilash bilan tugaydi. 10-dars.

## Tuzoqlar

- `latest` yoki qayta yoziladigan tag bilan deploy: rollout bo'lmaydi yoki node'larda har xil kod ishlaydi. Digest yoki commit SHA ishlating.
- Pipeline'ga `cluster-admin` kubeconfig berish. Bitta zararli PR butun cluster'ni oladi.
- Fork'dan kelgan PR'da deploy secret'lari bilan job ishga tushirish (`pull_request_target` tuzog'i, cicd modulidan).
- `kubectl apply` yashil bo'lgani uchun deploy muvaffaqiyatli deb hisoblash. `rollout status` siz pipeline hech narsani bilmaydi.
- Readiness probe'siz rollout gate: har doim o'tadi.
- `--dry-run=client` ni validatsiya deb o'ylash. U schema'ni ham to'liq tekshirmaydi.
- kubeconform'ni `-strict` siz ishlatish: typo maydonlar jim o'tadi.
- Muddatsiz ServiceAccount token'ni CI secret'ida yillab saqlash, rotatsiyasiz.
- Helm `--set` bilan pipeline'da o'nlab qiymat berish: haqiqiy konfiguratsiya git'da emas, workflow faylida qoladi. Qiymatlar `values-<env>.yaml` da bo'lsin.
- Kubeconfig yoki token'ni `echo` bilan log'ga chiqarish. GitHub secret'ni maskalaydi, lekin base64 qilingan nusxasini emas.

## Manbalar

- https://kubernetes.io/docs/concepts/containers/images/ – image nomlari, digest, pull policy
- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ – Kustomize rasmiy qo'llanma
- https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/ – kustomization.yaml kalitlari
- https://helm.sh/docs/chart_template_guide/ – chart template qo'llanmasi
- https://helm.sh/docs/topics/charts/ – Chart.yaml va chart tuzilishi
- https://github.com/yannh/kubeconform – kubeconform
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/ – rollout status
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/ – ServiceAccount token, structured authentication
- https://docs.github.com/en/actions/concepts/security/openid-connect – GitHub Actions OIDC
- https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images – GHCR'ga push workflow
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/ – RBAC

---

## Vazifalar

Barchasini `kubernetes/09-cicd-integration/` da bajaring (`make new m=kubernetes n=09 name=cicd-integration`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar, chart va overlay'lar shu papkada (`deploy/`, `chart/`), workflow fayli ilova repo'sida, uning nusxasi yoki havolasi README'da.

### A. Image va tag

1. **Tag vs digest.** Ilovangiz image'ini lokal build qilib GHCR'ga ikki tag bilan push qiling (commit SHA va `dev`). `docker buildx imagetools inspect` bilan digest'ni oling. Kodni o'zgartirib `dev` tag'ini qayta push qiling. Qaysi biri o'zgardi, qaysi biri yo'q? Jadval qilib yozing.

2. **Mutable tag trap.** kind cluster'da Deployment'ni `:dev` tag bilan deploy qiling. `dev` ni yangi kod bilan qayta push qilib `kubectl apply` ni takrorlang. Rollout bo'ldimi? `kubectl rollout history` va Pod'ning `imageID` maydoni bilan isbotlang va sababini ikki mexanizm (Pod template, pull policy) orqali izohlang.

3. **Pipeline build by SHA.** Ilova repo'sida workflow yozing: `main` ga push'da image build, tag `github.sha`, GHCR'ga push, digest'ni job output'iga chiqarish. `permissions` blokini minimal qiling va har bir ruxsat nima uchun kerakligini yozing.

4. **Private image pull.** GHCR package'ni private qoldirib kind'da deploy qiling. `ImagePullBackOff` xabarini `kubectl describe pod` dan o'qing. `imagePullSecrets` bilan tuzating. Token'ga qaysi scope yetarli ekanini yozing.

### B. Kustomize va Helm

5. **Kustomize base and overlays.** Ilovangiz uchun `deploy/base` (Deployment, Service) va `dev`, `prod` overlay'larini yozing: namespace, replica soni, resurslar, image har xil. `kubectl kustomize` natijalarini `diff` bilan solishtiring va farqlar faqat kutilgan joyda ekanini ko'rsating.

6. **ConfigMap hash rollout.** Overlay'ga `configMapGenerator` qo'shing va Deployment'da env sifatida ishlating. Qiymatni o'zgartirib `kubectl apply -k` qiling. ConfigMap nomi va rollout bilan nima bo'ldi? Xuddi shu tajribani generator'siz oddiy ConfigMap bilan takrorlab farqni izohlang.

7. **Write a Helm chart.** `helm create` skeletidan boshlab keraksizini o'chiring va ilovangiz uchun chart yozing: image repository va digest, replica soni, resurslar, probe'lar, Service porti values orqali. `values-dev.yaml` va `values-prod.yaml` yarating.

8. **helm lint and template.** Chart'da ataylab uch xil xato qiling: yopilmagan `{{`, noto'g'ri `nindent`, mavjud bo'lmagan `.Values` kaliti. Har biri uchun `helm lint` va `helm template` nima deydi, qaysi birini ikkalasi ham ushlamaydi? Jadval qilib yozing.

9. **Kustomize or Helm.** Bir xil ilovaning ikki variantini yonma-yon qo'yib yozing: har birida "prod'da replica sonini o'zgartirish" va "yangi muhit qo'shish" necha fayl va necha qator o'zgarish. O'z loyihangiz uchun qaysi birini tanlaysiz va nima uchun (5–6 gap)?

### C. Validatsiya

10. **kubeconform strict.** Render qilingan manifestga ataylab `replcas: 3` typo'sini va eski, o'chirilgan `apiVersion` ni kiriting. kubeconform'ni `-strict` bilan va usiz ishga tushiring. Har holatda nima chiqdi? `-kubernetes-version` ni o'zgartirish natijaga qanday ta'sir qiladi?

11. **Server dry-run.** Uch holatni `--dry-run=client` va `--dry-run=server` bilan sinang: mavjud bo'lmagan namespace, Deployment'ning `selector` ini mavjud obyektda o'zgartirish, noto'g'ri tipdagi maydon. Qaysi tekshiruv qaysi birini ushladi va nima uchun?

12. **kubectl diff gate.** Cluster'dagi Deployment'ni `kubectl scale` bilan qo'lda o'zgartiring, keyin `kubectl diff -k` ni ishga tushiring. Chiqish va exit code'ni yozing. Buni PR'da "nima o'zgaradi" kommenti sifatida qanday ishlatish mumkin?

### D. Auth va RBAC

13. **Deployer ServiceAccount.** `app` namespace'ida `deployer` ServiceAccount, Role va RoleBinding yarating. Huquqlarni eng kamdan boshlang va deploy ishlaguncha faqat xato xabari talab qilganini qo'shing. Yakuniy Role'ni va har bir qoida nima uchun kerakligini yozing.

14. **Kubeconfig from token.** `kubectl create token` bilan 1 soatlik token oling va noldan alohida kubeconfig fayli yig'ing. Shu fayl bilan `app` da deploy qilib ko'ring, keyin `kube-system` dagi Pod'larni va `app` dagi Secret'larni o'qib ko'ring. Xato xabarlarini yozing.

15. **can-i audit.** `kubectl auth can-i --list` ni `deployer` nomidan ishga tushiring. Keyin Role'ga `secrets` uchun `get` va `pods/exec` uchun `create` qo'shilsa hujumchi nima qila olishini aniq qadamlar bilan yozing (bajarmasdan).

16. **OIDC design.** Kodsiz, README'da: GitHub Actions'dan EKS cluster'ga OIDC orqali deploy sxemasini chizing (kim kimga ishonadi, qaysi token qayerda almashadi, `sub` claim'i qanday cheklanadi). ServiceAccount token variantiga nisbatan nima yaxshilanadi, nima murakkablashadi?

### E. Pipeline

17. **Validate job.** Workflow'ga PR uchun `validate` job qo'shing: `helm lint`, render, kubeconform, vaqtinchalik kind cluster'da (`helm/kind-action`) `--dry-run=server`. Ataylab buzilgan manifest bilan PR ochib job qizil bo'lishini ko'rsating.

18. **Deploy with rollout gate.** `main` uchun `deploy` job: vaqtinchalik kind cluster yaratadi, 13-vazifadagi RBAC'ni admin sifatida qo'yadi, keyin faqat `deployer` kubeconfig'i bilan build job'dan kelgan digest'ni deploy qiladi va `rollout status --timeout` bilan kutadi. Oxirida smoke test.

19. **Break the rollout.** Readiness probe yo'lini mavjud bo'lmagan path'ga o'zgartirib push qiling. Pipeline qayerda va qancha vaqtdan keyin qizil bo'ldi? Shu paytda eski Pod'lar bilan nima bo'lgan (job ichida `kubectl get rs,pods` chiqaring)? Probe'ni butunlay o'chirsangiz gate nima qiladi?

20. **Automatic rollback.** Deploy qadamini Helm'ga o'tkazing va muvaffaqiyatsiz rollout'da avtomatik orqaga qaytishni yoqing. 19-vazifadagi buzilishni takrorlab `helm history` chiqishini yozing. `deployer` Role'iga nima qo'shishga to'g'ri keldi va bu xavfsizlik uchun nimani anglatadi?

21. **Push model limits.** O'z pipeline'ingiz misolida 8-bo'limdagi olti chegaraning har biri uchun aniq ssenariy yozing: sizning setup'ingizda u qanday namoyon bo'ladi. Qaysi biri sizni eng ko'p xavotirga soladi?

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. Workflow'ning oxirgi `main` run'i yashil, buzilgan PR'niki qizil (havolalar README'da).
3. Repo'da token, kubeconfig va secret yo'q (`git log -p` ni tekshiring).
4. `kind delete cluster --name cicd` bajarilgan, GHCR'dagi sinov package'lari kerak bo'lmasa o'chirilgan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Tag va digest farqi nima, nima uchun production manifestida digest afzal?
- `latest` ni qayta push qilib `kubectl apply` qilish nima uchun rollout boshlamaydi?
- `configMapGenerator` ning hash suffiksi qaysi muammoni yechadi?
- `--dry-run=client`, `--dry-run=server` va kubeconform har biri nimani tekshiradi?
- `kubectl apply` muvaffaqiyatli, lekin deploy muvaffaqiyatsiz bo'lishi qanday mumkin? Pipeline buni qanday biladi?
- Helm bilan deploy qiladigan ServiceAccount'ga nima uchun Secret'larga yozish huquqi kerak va bu nimaga olib keladi?
- OIDC bilan auth'da qayerda secret saqlanadi?
- Push-based deploy'da drift nima uchun ko'rinmaydi?
