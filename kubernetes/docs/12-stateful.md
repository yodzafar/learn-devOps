# 12-dars: Stateful workload'lar

Maqsad: ma'lumotlar bazasini Kubernetes'da ishlatish nimani talab qilishini mexanizm darajasida tushunish. 4-darsda StatefulSet bilan tanishdingiz, 7-darsda PV, PVC va CSI'ni ko'rdingiz, 11-darsda anti-affinity, PodDisruptionBudget (PDB) va node o'chganda nima bo'lishini o'rgandingiz. Bu darsda ular birlashadi: StatefulSet'ning barqaror identifikatsiya, tartibli rollout va partition mexanizmlari, PostgreSQL'ni qo'lda StatefulSet bilan va operator (CloudNativePG) bilan ishga tushirish farqi, operator pattern va CRD, VolumeSnapshot orqali snapshot va restore, backup strategiyasi, hamda ma'lumotlar bazasi uchun ajratilgan node'lar (taint, toleration, nodeSelector). Yakuniy loyihadagi (15-dars) backup va restore mashqi shu darsga tayanadi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruhi, ikkinchi kun 3–4 bo'limlar, B va C guruhlari (CloudNativePG o'rnatish va failover eng ko'p vaqt oladi), uchinchi kun 5–6 bo'limlar, "Birga bajaramiz" va D guruhi, to'rtinchi kun 7-bo'lim va E guruhi. Diqqat qaratadigan joylar: StatefulSet nima beradi va nima bermaydi (replikatsiya, failover, backup uning ishi emas), PVC'larning hayot sikli, operator aynan qaysi "odam bilimi"ni kodga aylantiradi, snapshot nima uchun backup emas, va tekshirilmagan restore nima uchun mavjud emas deb hisoblanadi.

Qanday o'qish kerak: har bo'limdagi misolni o'qing, keyin o'z klasteringizda shunga o'xshash (aynan o'zi emas) narsani ishga tushirib, chiqishni darsdagi izoh bilan solishtiring. Pod IP'lari, PV nomlaridagi UID, vaqt va `AGE` qiymatlari sizda boshqa bo'ladi, darsda bunday joylar `<...>` bilan belgilangan. Stateful ishda tartib va vaqt muhim, shuning uchun `kubectl get pods -w` ni alohida terminalda ochib qo'ying. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi: aynan shu qismlar savol-javobda so'raladi.

## Laboratoriya

Asosiy muhit host'dagi Docker ustidagi kind klasteri: 1 control-plane va 3 worker, nomi `stateful`. Uchta worker kerak, chunki 3 instance'li baza har node'da bittadan turishi va E guruhida bitta yoki ikkita worker bazaga ajratilishi kerak. 11-darsdagi `kind-ha.yaml` ga o'xshash config, lekin zona label'lari shart emas:

```yaml
# kind-stateful.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
```

```bash
kind create cluster --name stateful --config kind-stateful.yaml
kubectl config current-context        # must print: kind-stateful
kubectl create namespace st
kubectl config set-context --current --namespace=st
```

Node'lar Docker konteynerlari: `stateful-control-plane`, `stateful-worker`, `stateful-worker2`, `stateful-worker3`. Node "o'chishi" 11-darsdagidek `docker stop stateful-worker2`, qaytishi `docker start stateful-worker2` bilan taqlid qilinadi. Multipass VM bu darsda shart emas: StatefulSet, operator va snapshot mexanizmlari kind node'larida to'liq ishlaydi. Haqiqiy diskli node'larda sinab ko'rmoqchi bo'lsangiz, 2-darsdagi Multipass'dagi k3s klasteri ixtiyoriy muqobil.

**Snapshot uchun CSI driver.** kind'ning default StorageClass'i (`standard`, local-path provisioner, 7-dars) snapshot'ni qo'llamaydi. Sinov uchun `csi-driver-host-path` o'rnatiladi. Tartib muhim: avval snapshot CRD'lari va snapshot controller (`external-snapshotter` repo'sidan), keyin driver. Ikkala repo'ning Releases sahifasidan joriy reliz tag'ini tanlang va shu tag'ni klonlang (`main` emas):

```bash
cd ~/src                                   # outside the learn-devOps repo
git clone --depth 1 --branch <release-tag> https://github.com/kubernetes-csi/external-snapshotter
kubectl kustomize external-snapshotter/client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize external-snapshotter/deploy/kubernetes/snapshot-controller | kubectl create -f -
git clone --depth 1 --branch <release-tag> https://github.com/kubernetes-csi/csi-driver-host-path
bash csi-driver-host-path/deploy/kubernetes-latest/deploy.sh
kubectl apply -f csi-driver-host-path/examples/csi-storageclass.yaml
kubectl get sc,volumesnapshotclass
```

Natijada `csi-hostpath-sc` StorageClass va `csi-hostpath-snapclass` VolumeSnapshotClass bo'lishi kerak. Bu driver faqat test uchun: u bitta `csi-hostpathplugin` Pod'i bilan ishlaydi va hamma volume shu Pod turgan node'ning diskida yotadi. Shuning uchun `csi-hostpath-sc` dagi PVC'ni ishlatadigan har Pod o'sha bitta node'ga tushadi (PV'da node affinity bor). Bu E guruhidagi taint'lar bilan to'qnashmasligi uchun 19–21 vazifalarda `csi-hostpath-sc` emas, `standard` ishlatiladi.

**CloudNativePG** Helm bilan (8-dars) o'rnatiladi, rasmiy hujjatdagi "Installation and upgrades" bo'limi bo'yicha. Chart versiyasini `helm search repo cnpg --versions` bilan ko'rib, `--version` bilan qotiring.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Klaster | Docker Engine ustida kind, node'lar `amd64` | Docker Desktop ustida kind, node'lar `arm64` |
| Node'lar qayerda | host'dagi oddiy konteynerlar, `docker ps` da ko'rinadi | Docker Desktop'ning yashirin Linux VM'i ichidagi konteynerlar |
| Volume ma'lumoti fizik qayerda | node konteyneri ichida (local-path va hostpath driver kataloglari) | o'sha joyda, lekin VM ichida: Mac fayl tizimida ko'rinmaydi |
| Image'lar | `postgres:17`, `busybox:1.36`, `redis:7.4`, CNPG va CSI sidecar image'lari: hammasi multi-arch | xuddi shu tag'lar, `arm64` varianti avtomatik tortiladi |
| Node o'chirish | `docker stop stateful-worker2` | xuddi shunday, Docker Desktop'da ham ishlaydi |
| Resurs | 3 instance'li PostgreSQL bilan 6 GB bo'sh RAM | Docker Desktop'ga kamida 8 GB RAM ajrating (Settings → Resources) |
| `deploy.sh` | `bash` bilan ishga tushadi | `bash` bilan ishga tushiring (zsh emas); skript faqat `kubectl` ni chaqiradi |

Ikkinchi mashinada tiklash: klaster holati mashinalar orasida ko'chmaydi, manifestlar git orqali keladi. Uyda `kind get clusters` da `stateful` bo'lmasa: klasterni yarating, namespace, snapshot CRD'lari, controller, hostpath driver va CNPG'ni yuqoridagi tartibda qayta o'rnating, keyin `kubectl apply -f`. Git orqali kelmaydigan narsalar: Secret'lar, PVC ichidagi ma'lumot, snapshot'lar va backup fayllari. Secret'ni har mashinada qayta yarating (quyidagi usulda), test qatorlarini SQL skript bilan qayta yozing. Failover va restore vaqt o'lchovlarini qaysi mashinada olganingizni README'da yozing: Mac'dagi VM qatlami vaqtni biroz uzaytiradi.

Xavfsizlik va tartib:

- Parol hech qachon manifestga, README'ga yoki `--from-literal` orqali shell tarixiga yozilmaydi. Repo'dan tashqarida tasodifiy fayl yaratib, Secret'ni fayldan oling: `umask 077; printf '%s' "$(openssl rand -hex 16)" > ~/.secrets/pg-pass`, keyin `kubectl create secret generic pg-auth --from-file=password=$HOME/.secrets/pg-pass`. `printf '%s'` oxirgi yangi qatorni olib tashlaydi, aks holda u parolning bir qismi bo'lib qoladi.
- Klonlangan `external-snapshotter` va `csi-driver-host-path` repo'lari ish papkasiga tushmaydi.
- Tozalash: `kind delete cluster --name stateful`. Bu klaster ichidagi hamma PV, snapshot va CNPG ma'lumotini ham o'chiradi.

---

## 1. Stateless va stateful

### Bu nima

Stateless (holatsiz) ilova so'rovlar orasida o'zida hech narsa saqlamaydi: istalgan nusxa istalgan so'rovga javob bera oladi, nusxani o'ldirib yangisini ko'tarish hech narsani yo'qotmaydi. Express yoki Next.js server'ingiz sessiyani Redis'da, ma'lumotni bazada saqlasa, aynan shunday. Stateful (holatli) ilova esa o'z diskida yoki xotirasida ma'lumot saqlaydi va har nusxa boshqasidan farq qiladi: PostgreSQL primary'si va replica'si bir xil emas, Kafka broker'lari har biri o'z partition'larini saqlaydi.

### Mexanizm: Deployment nimani buzadi

Deployment Pod'lari almashtiriladigan: nomi tasodifiy suffiksli, qayta yaratilganda IP ham, nom ham o'zgaradi, ular hech qanday tartibda emas, va PVC (7-dars) berilsa, hammasi bitta PVC'ni ulashadi. Ma'lumotlar bazasi uchun har biri muammo:

| Talab | Nima uchun | Deployment | StatefulSet |
|-------|-----------|------------|-------------|
| Barqaror nom | replica'lar bir-birini nomi bilan topadi (primary qaysi) | yo'q, `web-7c9f-x2k` | `db-0`, `db-1` |
| Har nusxaga o'z diski | har replica o'z ma'lumot nusxasini saqlaydi | bitta PVC hammaga | `volumeClaimTemplates` |
| Tartib | avval primary, keyin replica | parallel | ordinal bo'yicha |
| "Ko'pi bilan bitta" kafolati | bir xil identifikatsiyali ikki Pod bitta diskka yozsa ma'lumot buziladi | yo'q, rollout'da eski va yangi birga | bor |

Oxirgi qator eng nozik. Deployment rollout'da yangi Pod'ni eskisi o'chmasidan ko'taradi (`maxSurge`, 4-dars). Ikkalasi bitta `ReadWriteOnce` diskka ulanmoqchi bo'ladi: boshqa node'da bo'lsa yangisi `ContainerCreating` da `Multi-Attach error` bilan qotadi, bir node'da bo'lsa ikki PostgreSQL jarayoni bitta katalogga yozishga urinadi.

### Ishlaydigan misol

Deployment va StatefulSet Pod nomlarini yonma-yon ko'rish:

```
$ kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
api-6d8f7b9c4d-2xq9m    1/1     Running   0          5m
api-6d8f7b9c4d-kp7tz    1/1     Running   0          5m
cache-0                 1/1     Running   0          4m
cache-1                 1/1     Running   0          4m
```

- `api-6d8f7b9c4d-2xq9m`: Deployment nomi, ReplicaSet'ning pod template hash'i (`6d8f7b9c4d`) va tasodifiy suffiks. O'chirilsa yangi suffiks bilan qaytadi.
- `cache-0`, `cache-1`: StatefulSet nomi va ordinal (tartib raqami). O'chirilsa aynan shu nom bilan qaytadi.

### Real ishda qachon kerak

Ma'lumotlar bazasi, navbat (Kafka, RabbitMQ), qidiruv (Elasticsearch, OpenSearch), konsensus tizimlari (etcd, ZooKeeper). Ilovangizning o'zi esa stateless bo'lishi kerak: holat tashqariga, bazaga chiqariladi. Ko'p jamoalar bazani umuman klasterga qo'ymay, managed xizmatda (RDS, Cloud SQL) saqlaydi. Bu darsdagi bilim ikkala holatda ham kerak: qachon klasterda ishlatish o'zini oqlashini bilish uchun.

### Nima uchun shunday

Kubernetes avval stateless ilovalar uchun qurilgan: "chorva, uy hayvoni emas" (cattle, not pets) tamoyili. Stateful ilovalar boshida PetSet nomli obyekt bilan qo'llangan, 1.5 versiyada u StatefulSet deb qayta nomlangan. Muqobil, ya'ni Deployment'ga "maxsus rejim" qo'shish, uning soddaligini buzardi, shuning uchun boshqa kafolatlar bilan alohida controller tanlangan.

## 2. StatefulSet chuqur

### Bu nima

StatefulSet Pod'larga uchta narsa beradi: barqaror tarmoq identifikatsiyasi (nom va DNS), har Pod uchun o'z barqaror storage'i va tartibli yaratish, o'chirish va yangilash. Boshqa hech narsa bermaydi.

### Mexanizm: barqaror identifikatsiya

- Pod nomi `<statefulset>-<ordinal>`, ordinal 0 dan boshlanadi. Pod qayta yaratilsa nomi o'sha, IP esa o'zgaradi.
- **Headless Service** (`clusterIP: None`, 6-dars) virtual IP bermaydi, DNS so'roviga to'g'ridan-to'g'ri Pod IP'larini qaytaradi va har Pod'ga alohida DNS yozuvi beradi: `db-0.db.st.svc.cluster.local` (`<pod>.<service>.<namespace>.svc.cluster.local`). StatefulSet'ning `serviceName` maydoni shu Service'ga ishora qiladi.
- Odatda ikki Service bo'ladi: headless (a'zolar bir-birini topishi uchun) va oddiy ClusterIP (mijozlar uchun).
- Har Pod'ga `statefulset.kubernetes.io/pod-name` va `apps.kubernetes.io/pod-index` label'lari qo'yiladi: bitta aniq Pod'ga Service yo'naltirish shular bilan qilinadi.

DNS'ni vaqtinchalik Pod'dan tekshirish (`cache` StatefulSet'i va shu nomli headless Service misolida):

```
$ kubectl run dns --rm -it --image=busybox:1.36 --restart=Never -- nslookup cache-1.cache
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	cache-1.cache.st.svc.cluster.local
Address: 10.244.2.7

pod "dns" deleted
```

- `Server 10.96.0.10`: klaster DNS'i (CoreDNS) Service IP'si, 6-darsda ko'rgansiz.
- `Name`: qisqa nom `search` domenlari orqali to'liq nomga kengaydi.
- `Address`: Service IP emas, aynan `cache-1` Pod'ining IP'si. Pod qayta yaratilsa nom o'sha qoladi, bu qator esa yangi IP'ni ko'rsatadi.
- `pod "dns" deleted`: `--rm` vaqtinchalik Pod'ni buyruq tugagach o'chirdi.

### Mexanizm: volumeClaimTemplates

```yaml
volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: csi-hostpath-sc
      resources: { requests: { storage: 1Gi } }
```

Controller har Pod uchun `<template>-<pod>` nomli PVC yaratadi: `data-db-0`, `data-db-1`. Pod qayta yaratilganda aynan o'z PVC'siga ulanadi, chunki controller PVC'ni nom bo'yicha qidiradi. Shu sabab `db-1` har doim `db-1` ning ma'lumotini ko'radi. Bu muhim natija beradi: kutilgan nomdagi PVC oldindan mavjud bo'lsa, controller yangisini yaratmaydi, borini ishlatadi (5-bo'limda restore aynan shunga tayanadi).

```
$ kubectl get pvc
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
data-cache-0   Bound    pvc-<uid0>    1Gi        RWO            standard       <unset>                 4m
data-cache-1   Bound    pvc-<uid1>    1Gi        RWO            standard       <unset>                 4m
```

- `NAME`: template nomi (`data`) va Pod nomi.
- `STATUS Bound`: PVC haqiqiy PV'ga bog'langan (7-dars).
- `VOLUME pvc-<uid>`: dinamik yaratilgan PV nomi.
- `RWO`: `ReadWriteOnce`, bir vaqtda faqat bitta node ulay oladi.
- `VOLUMEATTRIBUTESCLASS <unset>`: yangi `kubectl` versiyalaridagi ustun, bu darsda ishlatilmaydi.

**PVC'lar StatefulSet bilan birga o'chmaydi.** Scale-down yoki `kubectl delete statefulset` dan keyin PVC va ma'lumot qoladi. Bu ataylab: ma'lumotni tasodifan yo'qotishdan himoya. Xatti-harakat `persistentVolumeClaimRetentionPolicy` bilan o'zgartiriladi:

```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain     # StatefulSet deleted: keep PVCs
    whenScaled: Delete      # scaled down: delete PVCs of removed Pods
```

Ikkala maydon `Retain` (default) yoki `Delete` qabul qiladi. Qolgan PVC'lar pul turadi (15-dars) va scale-up'da eski ma'lumot bilan qaytadi, bu replikatsiya uchun kutilmagan holat bo'lishi mumkin: eski replica ma'lumoti bilan qaytgan Pod'ni baza "yangi" deb qabul qilmaydi.

`volumeClaimTemplates` o'zgarmas: mavjud StatefulSet'da hajmni o'zgartirib bo'lmaydi. Kengaytirish PVC'larning o'zida qilinadi (StorageClass `allowVolumeExpansion: true` bo'lsa, 7-dars).

### Mexanizm: tartib

| `podManagementPolicy` | Yaratish | O'chirish (scale-down) |
|-----------------------|----------|------------------------|
| `OrderedReady` (default) | 0, 1, 2 navbat bilan, har biri `Running` va `Ready` bo'lgach keyingisi | teskari: 2, 1, 0, har biri to'liq o'chgach keyingisi |
| `Parallel` | hammasi birdan | hammasi birdan |

Bu faqat scale uchun. Yangilanish tartibi `updateStrategy` da.

```
$ kubectl get pods -l app=cache -w
NAME      READY   STATUS              RESTARTS   AGE
cache-0   0/1     Pending             0          0s
cache-0   0/1     ContainerCreating   0          1s
cache-0   1/1     Running             0          4s
cache-1   0/1     Pending             0          0s
cache-1   0/1     ContainerCreating   0          1s
cache-1   1/1     Running             0          3s
```

- `cache-1` faqat `cache-0` `1/1` (`Ready`) bo'lgandan keyin `Pending` bo'lib paydo bo'ldi. `cache-0` ning readiness probe'i hech qachon o'tmasa, `cache-1` umuman yaratilmaydi.
- `AGE 0s` har yangi Pod uchun qayta boshlanadi: bu ketma-ketlikning dalili.

### Mexanizm: rolling update va partition

`updateStrategy.type`: `RollingUpdate` (default) yoki `OnDelete` (template o'zgaradi, lekin Pod faqat siz uni o'chirganingizda yangi versiya bilan qaytadi; yangilanishni to'liq qo'lda boshqarish uchun).

`RollingUpdate` eng katta ordinal'dan boshlaydi (2, 1, 0), har Pod'ni o'chiradi, yangi versiyada qayta yaratadi va u `Ready` bo'lishini kutadi. Deployment'dan farqi: yangi nusxa eskisi bilan birga turmaydi (bir xil nom va disk), shuning uchun har qadamda bitta Pod vaqtincha yo'q. Primary odatda `-0` bo'lgani uchun oxirida yangilanadi.

`rollingUpdate.partition: N` ordinal'i N dan **katta yoki teng** Pod'larnigina yangilaydi, qolganlari eski versiyada qoladi va hatto o'chirilsa ham eski versiyada qaytadi. Bu canary (yangi versiyani avval kichik qismda sinash): faqat yuqori ordinal'dagi bitta Pod yangi versiyaga o'tadi, tekshirasiz, keyin partition'ni bosqichma-bosqich 0 gacha tushirasiz.

```
$ kubectl patch statefulset cache -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'
statefulset.apps/cache patched
$ kubectl set image statefulset/cache main=redis:7.4.2
statefulset.apps/cache image updated
$ kubectl rollout status statefulset/cache
partitioned roll out complete: 1 new pods have been updated...
$ kubectl get statefulset cache -o jsonpath='{.status.currentRevision}{"\n"}{.status.updateRevision}{"\n"}'
cache-5d7c9b8f6
cache-7f4b6c5d9
```

- `patch` StatefulSet'ga partition'ni qo'ydi, hali hech narsa yangilanmadi.
- `set image` template'ni o'zgartirdi, controller ordinal'i 1 dan katta yoki teng Pod'nigina (`cache-1`) yangiladi.
- `partitioned roll out complete`: rollout "partition chegarasigacha" tugadi.
- `currentRevision` va `updateRevision` farq qiladi: klasterda ikki versiya yonma-yon. Revision bu template'ning ControllerRevision obyektidagi nusxasi (Deployment'dagi ReplicaSet'ga o'xshash rol).

**Buzuq rollout o'zi tuzalmaydi.** `OrderedReady` bilan yangi versiya `Ready` bo'lmasa rollout to'xtaydi. Template'ni to'g'rilab qo'ysangiz ham controller buzuq Pod `Ready` bo'lishini kutaveradi. Hujjat buni "forced rollback" deb ataydi: template tuzatilgandan keyin buzuq Pod'larni qo'lda o'chirish kerak. Nima uchun aynan shunday ekanini 5-vazifada o'zingiz tushuntirasiz.

### StatefulSet nimani bermaydi

Replikatsiyani sozlash, primary tanlash, failover, backup, major versiya upgrade'i, ulanish pool'i. StatefulSet faqat nom, disk va tartib beradi, qolgani ilovaning yoki operatorning ishi. 11-darsdan eslang: node `NotReady` bo'lsa StatefulSet Pod'i o'zi boshqa node'ga ko'chmaydi. Controller eski Pod haqiqatan to'xtaganini bila olmaydi, va bir xil identifikatsiyali ikki nusxa bitta diskka yozishi ma'lumotni buzadi. Node haqiqatan o'chganini odam tasdiqlashi uchun `node.kubernetes.io/out-of-service` taint'i bor (non-graceful node shutdown): uni qo'ysangiz Pod'lar majburan o'chiriladi va volume ajratiladi. `ReadWriteOnce` disk boshqa node'ga ulanishi uchun eski ulanish uzilishi shart.

### Real ishda qachon kerak

Klasterda o'zi replikatsiyani boshqara oladigan tizimni (Kafka KRaft, etcd, Redis Sentinel) Helm chart bilan o'rnatganda, ichida StatefulSet bo'ladi va siz partition, retention policy va PVC'lar bilan ishlaysiz. Partition'li canary bazaning yangi minor versiyasini bitta replica'da sinash uchun ishlatiladi.

### Nima uchun shunday

StatefulSet'ning har kafolati "xavfsizlik birinchi" tanlovi: PVC'lar o'chmaydi (ma'lumot qimmat), tartib bor (ko'p klaster tizimlari a'zolarni birma-bir qo'shishni talab qiladi), node o'chganda Pod ko'chmaydi (ikki nusxa bitta nusxaning yo'qligidan yomonroq). Har birini yumshatish mumkin (`Parallel`, `whenDeleted: Delete`, `out-of-service`), lekin buni siz ongli ravishda qilasiz.

## 3. PostgreSQL qo'lda

### Bu nima

PostgreSQL'ni o'zingiz StatefulSet manifesti bilan ishga tushirish: rasmiy `postgres` image'i, parol Secret'dan, PVC, readiness va liveness probe sifatida `pg_isready` (server ulanish qabul qilayotganini tekshiradigan kichik klient), headless Service. Bitta nusxa uchun bu yetarli va tushunarli.

### Mexanizm: bitta nusxa

- `postgres` image'i birinchi ishga tushishda bo'sh katalogni ko'rsa, `initdb` bilan yangi klaster yaratadi va `POSTGRES_PASSWORD` dagi parolni superuser'ga qo'yadi. Katalog bo'sh bo'lmasa, bor ma'lumot bilan ishga tushadi va bu o'zgaruvchilarni e'tiborsiz qoldiradi.
- Ma'lumot katalogi `PGDATA` o'zgaruvchisida. Uning yo'li image'ning major versiyasiga bog'liq (18-versiyada o'zgargan), shuning uchun mount yo'lini Docker Hub'dagi image sahifasidan tekshiring. Ba'zi storage'larda yangi volume ildizida `lost+found` katalogi bo'ladi va `initdb` "katalog bo'sh emas" deb rad etadi: shuning uchun `PGDATA` odatda mount nuqtasining ichidagi pastki katalogga qo'yiladi.
- Resurs: bazaga `requests` = `limits` (Guaranteed QoS, 4-dars), aks holda node bosimida birinchi bo'lib evict yoki OOM bo'ladi.

```
$ kubectl exec db-0 -- pg_isready -U postgres
/var/run/postgresql:5432 - accepting connections
$ kubectl exec db-0 -- psql -U postgres -Atc "select pg_is_in_recovery();"
f
```

- `pg_isready`: Unix socket (`/var/run/postgresql`) va port, holat `accepting connections`. Exit code 0, probe uchun aynan shu kerak.
- `pg_is_in_recovery()` `f` (false): bu server primary, replica emas. `-A` tekislashsiz, `-t` faqat qiymat chiqaradi.

### Mexanizm: HA uchun nima qo'shiladi

HA (high availability, bitta nusxa o'lsa ham xizmat davom etishi) kerak bo'lganda ro'yxat uzayadi:

1. Replica'ni `pg_basebackup` (primary'dan to'liq fizik nusxa oladigan asbob) bilan boshlash.
2. Streaming replication sozlamasi: primary WAL'ni (write-ahead log, har o'zgarish avval yoziladigan jurnal) replica'larga oqim qilib uzatadi.
3. Primary o'lganini aniqlash va bu tarmoq uzilishi emasligiga ishonch hosil qilish.
4. Eng yangi replica'ni promote qilish (primary'ga aylantirish).
5. Eski primary qaytsa uni replica sifatida qayta ulash, aks holda split-brain (ikki primary, ikki xil tarix).
6. Mijozlarni yangi primary'ga yo'naltirish.
7. WAL arxivi va backup jadvali, sertifikatlar, minor va major upgrade.

Bularning har biri init container, sidecar va skriptlar demak. `replicas: 3` qilish esa uchta mustaqil, bir-birini bilmaydigan bazani beradi.

### Real ishda qachon kerak

Bitta nusxali qo'lda StatefulSet: dev va test muhitlari, CI'dagi vaqtinchalik baza, bu darsdagi kabi o'qish. Production HA uchun qo'lda yozilgan StatefulSet deyarli hech qachon to'g'ri tanlov emas: operator yoki managed xizmat.

### Nima uchun shunday

PostgreSQL o'zi klaster menejeri emas: replikatsiya mexanizmini beradi, lekin "kim primary" qarorini tashqi asboblarga (Patroni, repmgr, operator) qoldiradi. Kubernetes ham bu qarorni bilmaydi. Shu bo'shliqni to'ldiradigan dastur keyingi bo'limning mavzusi.

## 4. Operator pattern, CRD va CloudNativePG

### Bu nima

- **CRD** (CustomResourceDefinition) API server'ga yangi obyekt turini qo'shadi: o'z schema'si (OpenAPI), versiyalari va `status` subresource'i bilan. CRD qo'shilgach `kubectl get`, `apply`, `explain` va RBAC u bilan oddiy obyekt kabi ishlaydi.
- **Controller** shu obyektlarni kuzatadi va reconcile qiladi: istalgan holat (`spec`) va haqiqiy holat orasidagi farqni yo'qotadi. Bu Deployment controller bilan bir xil model (1-dars), faqat domen bilimi bilan.
- **Operator = CRD + controller + domen bilimi.** cert-manager (8-dars), Argo CD va Flux (10-dars) ham shu pattern. Helm chart'dan farqi: chart o'rnatish paytida bir marta manifest yaratadi, operator esa doim ishlab turib, vaziyatga javob beradi (failover, backup jadvali, sertifikat yangilash).

### Mexanizm

1. Siz `Cluster` obyektini yaratasiz, API server uni etcd'ga yozadi.
2. Operator Pod'i watch orqali o'zgarishni oladi.
3. U haqiqiy holatni o'qiydi: qaysi Pod, PVC, Service, Secret bor, qaysi instance primary, replikatsiya kechikishi qancha.
4. Farqni yopadi: yetishmayotgan obyektni yaratadi, ortiqchasini o'chiradi, primary o'lgan bo'lsa failover qiladi.
5. Natijani `Cluster` ning `status` iga yozadi va yana kutadi.

Operator yaratgan har obyektda `ownerReferences` (5-dars) `Cluster` ga ishora qiladi: kimdir uni qo'lda o'chirsa, operator keyingi reconcile'da qayta yaratadi.

CRD'lar ro'yxatini ko'rish, snapshot CRD'lari misolida (Laboratoriyada o'rnatdingiz):

```
$ kubectl get crd | grep snapshot.storage
volumesnapshotclasses.snapshot.storage.k8s.io    2026-10-08T07:12:31Z
volumesnapshotcontents.snapshot.storage.k8s.io   2026-10-08T07:12:31Z
volumesnapshots.snapshot.storage.k8s.io          2026-10-08T07:12:31Z
```

- Nom shakli `<plural>.<group>`: `volumesnapshots` resurs nomi, `snapshot.storage.k8s.io` API guruhi.
- Ikkinchi ustun CRD yaratilgan vaqt. Yangi `external-snapshotter` reliz'larida `groupsnapshot` CRD'lari ham ko'rinishi mumkin.

Operator tanlashda savollar: kim qo'llab-quvvatlaydi va qancha faol, failover va backup haqiqatan sinovdan o'tganmi, upgrade yo'li, CRD versiyalari barqarormi. Operator klasterda keng huquq bilan ishlaydi, uning xatosi hamma bazalarga ta'sir qiladi.

### CloudNativePG

CloudNativePG (CNPG) CNCF loyihasi, PostgreSQL uchun operator. U StatefulSet ishlatmaydi: Pod va PVC'larni o'zi to'g'ridan-to'g'ri boshqaradi, chunki failover va yangilanish tartibi ustidan to'liq nazorat kerak (masalan, rollout'da avval replica'larni, keyin switchover bilan primary'ni yangilash).

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: orders }
spec:
  instances: 2
  storage:
    size: 1Gi
```

Shu qisqa manifestdan operator yaratadi:

| Resurs | Nom | Vazifasi |
|--------|-----|----------|
| Pod'lar va PVC'lar | `orders-1`, `orders-2` | bitta primary, qolgani streaming replica |
| Service | `orders-rw` | har doim joriy primary'ga (yozish) |
| Service | `orders-ro` | faqat replica'larga (o'qish) |
| Service | `orders-r` | istalgan instance'ga |
| Secret | `orders-app` | ilova foydalanuvchisi, parol, ulanish URI |

```
$ kubectl get cluster orders
NAME     AGE   INSTANCES   READY   STATUS                     PRIMARY
orders   3m    2           2       Cluster in healthy state   orders-1
```

- `INSTANCES` va `READY`: so'ralgan va tayyor instance'lar.
- `STATUS`: operator `status` ga yozgan matn. O'rnatish paytida `Setting up primary`, failover paytida `Failing over` kabi qiymatlar ko'rinadi.
- `PRIMARY`: joriy primary Pod nomi. Failover'dan keyin shu ustun o'zgaradi.

```
$ kubectl get secret orders-app -o jsonpath='{.data.username}' | base64 -d; echo
app
```

Secret'dagi qiymatlar base64'da (shifrlash emas, faqat kodlash, 4-dars). Parolni shu yo'l bilan terminalga chiqarmang, ilovaga `secretKeyRef` orqali bering.

Primary o'lsa operator eng yangi replica'ni promote qiladi va `-rw` Service'ni unga buradi, ilova faqat qayta ulanadi. Holatni `kubectl cnpg status <cluster>` ham ko'rsatadi: bu alohida o'rnatiladigan kubectl plugin (`kubectl krew install cnpg`, ixtiyoriy). Backup uch usulda: plugin orqali object storage'ga (Barman Cloud Plugin, WAL arxivi va PITR bilan), CSI volume snapshot orqali, va eskirgan o'rnatilgan `barmanObjectStore`. Tuzoq: `ScheduledBackup` dagi `schedule` olti maydonli (birinchisi soniya), 5-darsdagi oddiy crontab'dan farqli.

### Real ishda qachon kerak

Klasterda production PostgreSQL ishlatishga qaror qilinganda: CNPG, Zalando postgres-operator, Crunchy PGO. Boshqa tizimlar uchun ham operator'lar bor (Strimzi Kafka uchun, ECK Elasticsearch uchun). Har birida bir xil savol: siz endi bazani emas, operator'ni ekspluatatsiya qilasiz, va uning upgrade'i ham sizning ishingiz.

### Nima uchun shunday

Kubernetes API'si kengaytiriladigan qilib qurilgan: yangi tur qo'shish uchun API server kodini o'zgartirish shart emas. Natijada "Kubernetes'ni qanday boshqarish" bilimi (deklarativ manifest, `kubectl`, RBAC, GitOps) har qanday domenga ko'chadi. Muqobili, ya'ni bazani tashqi skriptlar bilan boshqarish, holatni klasterdan tashqarida saqlaydi va reconcile'ni yo'qotadi.

## 5. VolumeSnapshot

### Bu nima

Snapshot bu diskning ma'lum bir lahzadagi nusxasi, storage tizimi darajasida olingan (fayl nusxalash emas). Kubernetes'da u uchta CRD bilan ifodalanadi. Ular asosiy API'ning qismi emas, alohida o'rnatiladi (Laboratoriyada shuni qildingiz):

| Obyekt | O'xshashi (7-dars) | Vazifasi |
|--------|-----------|----------|
| `VolumeSnapshotClass` | StorageClass | qaysi driver, `deletionPolicy` |
| `VolumeSnapshot` | PVC | "shu PVC'dan snapshot ol" so'rovi, namespace ichida |
| `VolumeSnapshotContent` | PV | haqiqiy snapshot'ga ishora, cluster-scoped |

### Mexanizm

1. Siz `VolumeSnapshot` yaratasiz.
2. Snapshot controller (kube-system'dagi alohida Deployment) uni ko'rib, `VolumeSnapshotContent` yaratadi.
3. CSI driver yonidagi `csi-snapshotter` sidecar'i shu Content'ni ko'rib, driver'ga CSI `CreateSnapshot` chaqiruvini yuboradi.
4. Driver snapshot olgach, Content va Snapshot'ning `readyToUse` maydoni `true` bo'ladi.

Uchta narsa kerak: snapshot CRD'lari, snapshot controller, va CSI driver'ning snapshot'ni qo'llashi (uning `csi-snapshotter` sidecar'i). Birortasi yo'q bo'lsa `VolumeSnapshot` yaratiladi, lekin `READYTOUSE` hech qachon `true` bo'lmaydi. Sababni `kubectl describe volumesnapshot` dagi Events'dan o'qiysiz.

### Ishlaydigan misol

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: { name: data-cache-0-snap }
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: data-cache-0
```

```
$ kubectl get volumesnapshot
NAME                READYTOUSE   SOURCEPVC      SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS            SNAPSHOTCONTENT              CREATIONTIME   AGE
data-cache-0-snap   true         data-cache-0                           1Gi           csi-hostpath-snapclass   snapcontent-<uid>            8s             9s
```

- `READYTOUSE true`: snapshot tayyor, undan restore qilish mumkin.
- `SOURCEPVC`: qaysi PVC'dan olingan. `SOURCESNAPSHOTCONTENT` bo'sh: bu dinamik snapshot, oldindan mavjud snapshot'ni import qilish emas.
- `RESTORESIZE 1Gi`: undan tiklanadigan PVC kamida shuncha hajm so'rashi kerak.
- `SNAPSHOTCONTENT snapcontent-<uid>`: bog'langan cluster-scoped obyekt (PVC va PV juftligi kabi).
- `CREATIONTIME`: storage'da snapshot olingan vaqt.

Restore mavjud PVC'ni orqaga qaytarmaydi, snapshot'dan **yangi PVC** yaratadi:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: cache-restored }
spec:
  storageClassName: csi-hostpath-sc
  dataSource:
    name: data-cache-0-snap
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 1Gi } }
```

- `dataSource` provisioner'ga "bo'sh disk emas, shu snapshot mazmuni bilan disk yarat" deydi.
- `deletionPolicy: Delete` (VolumeSnapshotClass'da) bo'lsa `VolumeSnapshot` o'chirilganda storage'dagi snapshot ham o'chadi, `Retain` bo'lsa qoladi.
- Snapshot **crash-consistent**: disk elektr o'chgan paytdagidek holatda. PostgreSQL bundan WAL orqali tiklanadi (ma'lumot va WAL bitta volume'da bo'lsa), lekin har ilova ham emas. Ilova darajasida izchillik (application-consistent) uchun snapshot'dan oldin yozishni to'xtatish yoki bazaning o'z backup rejimini ishlatish kerak.
- StatefulSet'ni snapshot'dan tiklash 2-bo'limdagi qoidaga tayanadi: kutilgan nomdagi PVC oldindan mavjud bo'lsa controller uni ishlatadi.

### Real ishda qachon kerak

Katta bazadan tez nusxa olish (terabaytli `pg_dump` soatlab ketadi, snapshot soniyalarda), xavfli migratsiyadan oldingi "qaytish nuqtasi", production ma'lumotidan test muhitini klonlash. Cloud'da EBS, Persistent Disk kabi disklarning CSI driver'lari snapshot'ni qo'llaydi.

### Nima uchun shunday

Snapshot storage'ga xos operatsiya, Kubernetes uni faqat standart interfeys (CSI) orqali chaqiradi. Shuning uchun u PV/PVC modelini takrorlaydi: foydalanuvchi namespace ichida so'rov yozadi, administrator class'ni belgilaydi, haqiqiy resurs cluster-scoped. Restore'ning "yangi PVC" ekani ham xavfsizlik tanlovi: mavjud diskni ustidan yozish xato snapshot'da qaytarib bo'lmaydigan yo'qotish bo'lardi.

## 6. Backup strategiyasi

### Bu nima

Backup bu asl tizim to'liq yo'qolganda ham ma'lumotni tiklash imkonini beradigan, asldan mustaqil joyda saqlangan nusxa. Uch asosiy usul:

| Usul | Nima | Kuchli tomoni | Zaif tomoni |
|------|------|---------------|-------------|
| Logical (`pg_dump`, 5-dars) | SQL yoki arxiv fayl | versiyalar orasida ko'chadi, bitta jadvalni tiklash mumkin | katta bazada sekin, PITR yo'q |
| Physical + WAL arxivi | base backup va WAL oqimi | point-in-time recovery (PITR, istalgan soniyaga tiklash), kichik RPO | bir xil major versiya, sozlash murakkabroq |
| Volume snapshot | disk nusxasi | tez, katta hajmda ham | storage'ga bog'liq, odatda o'sha tizimda yotadi |

### Mexanizm: o'lchovlar va qoidalar

- **RPO** (Recovery Point Objective): qancha ma'lumot yo'qotishga rozimiz, vaqt bilan. Kunlik `pg_dump` RPO'si 24 soatgacha. WAL arxivi bilan daqiqalar yoki soniyalar.
- **RTO** (Recovery Time Objective): qancha vaqtda tiklaymiz. 100 GB dump'ni tiklash soatlab, snapshot'dan tiklash daqiqalar.
- **Snapshot backup emas**, agar u asl disk bilan bir storage tizimida va bir akkauntda yotsa. Klaster, akkaunt yoki region yo'qolsa ikkalasi birga yo'qoladi. Backup boshqa joyga (object storage, boshqa region) ko'chirilgan nusxa.
- **Replica backup emas.** `DROP TABLE` replica'larga bir soniyada tarqaladi.
- **3-2-1**: uch nusxa, ikki xil tashuvchi, bittasi boshqa joyda.
- **Tekshirilmagan backup mavjud emas.** Restore mashqi jadval bo'yicha o'tkaziladi va vaqti o'lchanadi: bu RTO'ning yagona halol manbai.
- Kubernetes obyektlari (manifestlar) GitOps bilan git'da (10-dars). Backup kerak bo'ladigani: ma'lumot va git'da bo'lmagan Secret'lar. Klaster darajasidagi backup uchun Velero kabi asboblar bor.

### Ishlaydigan misol: RPO'ni hisoblash

Faraz qiling, `pg_dump` CronJob'i har kuni 02:00 da ishlaydi, baza 15:30 da yo'qoldi. Oxirgi yaxshi nusxa 02:00 dagisi, 13.5 soatlik yozuvlar yo'qoladi. Eng yomon holat esa 01:59 dagi nosozlik: deyarli 24 soat. Shuning uchun RPO "o'rtacha" emas, eng yomon holat bo'yicha yoziladi. WAL arxivida segment odatda to'lganda yoki `archive_timeout` tugaganda yuboriladi, RPO shu oraliq bilan chegaralanadi.

PostgreSQL'da WAL arxivlash holatini ko'rish:

```
$ kubectl exec orders-1 -- psql -Atc "select archived_count, last_archived_wal, failed_count from pg_stat_archiver;"
0||0
```

- `archived_count 0`, `last_archived_wal` bo'sh: bu klasterda WAL arxivi sozlanmagan, demak PITR imkoni yo'q.
- Arxivlash sozlangan klasterda `archived_count` o'sib boradi va `failed_count` 0 bo'lishi kerak: o'sayotgan `failed_count` jim yo'qolayotgan backup belgisi.

### Real ishda qachon kerak

Har production bazada. Odatiy kombinatsiya: object storage'ga WAL arxivi va haftalik base backup (PITR uchun), migratsiyadan oldin snapshot (tez qaytish uchun), kunlik logical dump boshqa akkauntga (operator yoki storage'ning o'zi buzilsa), va oylik restore mashqi.

### Nima uchun shunday

Har usul boshqa xavfdan himoya qiladi: snapshot tezlik beradi, WAL arxivi aniqlik, logical dump mustaqillik. Bittasi hammasini qoplamaydi. "Ishlaydigan" backup jarayoni yillab jim xato qilishi mumkin (bo'sh fayllar, eskirgan parol), shuning uchun faqat muvaffaqiyatli restore backup borligini isbotlaydi.

## 7. Taint, toleration va ajratilgan node'lar

### Bu nima

Affinity (11-dars) Pod'ni node'ga **tortadi**. Taint teskarisi: node Pod'larni **itaradi**, faqat mos toleration'i bor Pod tusha oladi. Taint node'dagi `key=value:effect` yozuvi, toleration Pod spec'idagi "men shu taint'ga chidayman" degan e'lon.

### Mexanizm

```bash
kubectl taint nodes stateful-worker2 dedicated=batch:NoSchedule
kubectl taint nodes stateful-worker2 dedicated=batch:NoSchedule-   # trailing minus removes it
kubectl label nodes stateful-worker2 workload=batch
```

| Effect | Yangi Pod'lar | Ishlab turgan Pod'lar |
|--------|---------------|------------------------|
| `NoSchedule` | toleration'siz tushmaydi | qoladi |
| `PreferNoSchedule` | iloji bo'lsa tushmaydi | qoladi |
| `NoExecute` | tushmaydi | toleration'siz evict qilinadi (`tolerationSeconds` bilan kechiktiriladi) |

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: batch
    effect: NoSchedule
nodeSelector:
  workload: batch
```

`operator: Exists` qiymatni tekshirmaydi; `key` siz `Exists` hamma taint'ga toleration (DaemonSet agentlari, masalan log yig'uvchi, shu bilan har node'ga tushadi).

**Toleration ruxsat, yo'naltirish emas.** Toleration'li Pod taint'li node'ga tusha oladi, lekin boshqa node'ga ham tushishi mumkin. Ajratilgan node uchun ikkalasi kerak: taint (boshqalar kirmasin) va nodeSelector yoki node affinity (bu workload faqat shu yerga tushsin).

### Ishlaydigan misol

```
$ kubectl describe node stateful-worker2 | grep Taints
Taints:             dedicated=batch:NoSchedule
$ kubectl get pods -o wide
NAME         READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
report-0     0/1     Pending   0          40s   <none>   <none>   <none>           <none>
$ kubectl describe pod report-0 | tail -3
Events:
  Type     Reason            Age   From               Message
  Warning  FailedScheduling  40s   default-scheduler  0/4 nodes are available: 1 node(s) had untolerated taint {dedicated: batch}, 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 node(s) didn't match Pod's node affinity/selector. preemption: 0/4 nodes are available: 4 Preemption is not helpful for scheduling.
```

- `Taints`: node'dagi hamma taint'lar, bittadan ko'p bo'lsa keyingi qatorlarda.
- `report-0` nodeSelector `workload=batch` bilan, lekin toleration'siz: `Pending`, `NODE <none>`.
- Scheduler xabari har node'ni nima uchun rad etganini sanaydi: 1 node (worker2) taint tufayli, 1 node (control-plane) o'z taint'i tufayli, 2 node selector'ga mos emas. Jami 4 = klasterdagi node'lar soni.
- `preemption ... not helpful`: kamroq muhim Pod'larni chiqarib yuborish (11-dars, PriorityClass) ham yordam bermaydi, chunki muammo joyda emas, qoidada.

O'rnatilgan taint'lar: `node-role.kubernetes.io/control-plane:NoSchedule` (control-plane'ga oddiy Pod tushmasligi sababi, yuqoridagi xabarda ko'rindi), `node.kubernetes.io/not-ready` va `unreachable` (11-darsdagi 300 soniya: har Pod'ga avtomatik `tolerationSeconds: 300` li toleration qo'shiladi), `memory-pressure`, `disk-pressure`, `unschedulable` (cordon), `out-of-service` (2-bo'lim).

### Real ishda qachon kerak

Bazani ajratilgan node'larga qo'yish sabablari: shovqinli qo'shnilardan izolyatsiya (disk I/O, page cache), boshqa mashina turi (ko'p xotira, tez lokal disk), autoscaler bu node'larni olib tashlamasligi, alohida upgrade jadvali. GPU node'lari ham shu usul bilan faqat GPU workload'lariga ajratiladi. 15-darsda xuddi shu mexanizm spot node'lar uchun ishlatiladi.

### Nima uchun shunday

Taint va affinity ikki tomonlama nazoratni ajratadi: taint node egasining qoidasi ("bu yerga hamma kelmasin"), affinity va nodeSelector workload egasining istagi ("men u yerga borishni xohlayman"). Bitta mexanizm ikkalasini qila olmaydi: faqat affinity bo'lsa, boshqa jamoalarning Pod'lari ajratilgan node'ni egallab oladi; faqat taint bo'lsa, toleration'li Pod istalgan joyga tushadi.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Stateless / stateful | so'rovlar orasida o'zida holat saqlamaydigan / saqlaydigan ilova |
| StatefulSet | Pod'larga barqaror nom, shaxsiy storage va tartib beradigan workload |
| Ordinal | StatefulSet Pod'ining 0 dan boshlanadigan tartib raqami |
| Headless Service | `clusterIP: None`, DNS to'g'ridan-to'g'ri Pod IP'larini qaytaradi |
| `volumeClaimTemplates` | har Pod uchun alohida PVC yaratiladigan shablon |
| `persistentVolumeClaimRetentionPolicy` | StatefulSet o'chirilganda yoki scale-down'da PVC'lar o'chadimi |
| `podManagementPolicy` | scale paytida Pod'lar navbat bilan (`OrderedReady`) yoki birdan (`Parallel`) |
| `partition` | faqat ordinal'i shundan katta yoki teng Pod'larni yangilaydigan chegara |
| `OnDelete` | Pod faqat qo'lda o'chirilganda yangi versiyada qaytadigan strategiya |
| ControllerRevision | template versiyasining saqlangan nusxasi, StatefulSet revision'lari |
| Forced rollback | buzuq rollout'dan keyin Pod'larni qo'lda o'chirib tiklash |
| WAL | PostgreSQL'da har o'zgarish avval yoziladigan jurnal |
| Streaming replication | primary WAL'ni replica'larga uzluksiz uzatishi |
| Promote / failover | replica'ni primary'ga aylantirish / primary o'lganda shuni avtomatik qilish |
| Split-brain | bir vaqtda ikki primary, ma'lumot tarixi ikkiga bo'linadi |
| CRD | API server'ga yangi obyekt turi qo'shadigan ta'rif |
| Operator | CRD, controller va domen bilimidan iborat dastur |
| Reconcile | istalgan va haqiqiy holat farqini yopish sikli |
| CloudNativePG | PostgreSQL uchun CNCF operator'i |
| VolumeSnapshotClass / VolumeSnapshot / VolumeSnapshotContent | snapshot uchun class / so'rov / haqiqiy snapshot'ga ishora |
| Crash-consistent | elektr o'chgan paytdagi holatga teng nusxa |
| PITR | point-in-time recovery, istalgan lahzaga tiklash |
| RPO / RTO | yo'qotish mumkin bo'lgan ma'lumot vaqti / tiklash vaqti |
| 3-2-1 | uch nusxa, ikki tashuvchi, bittasi boshqa joyda |
| Taint / toleration | node'ning Pod'larni itarishi / Pod'ning shunga chidashi |
| `NoSchedule` / `NoExecute` | yangi Pod'ni to'sish / ishlab turganini ham evict qilish |
| `tolerationSeconds` | `NoExecute` taint'da Pod node'da yana qancha qolishi |

## Tuzoqlar

- StatefulSet'ni o'chirib "tozaladim" deb o'ylash: PVC'lar va ma'lumot qoladi, to'lov davom etadi. Yoki aksincha: `whenDeleted: Delete` qo'yib, StatefulSet'ni qayta yaratish uchun o'chirish va ma'lumotni yo'qotish.
- `replicas: 3` StatefulSet'ni "HA PostgreSQL" deb hisoblash. Bu uchta mustaqil, bir-birini bilmaydigan baza.
- Bazaga Deployment va bitta `ReadWriteOnce` PVC: rollout'da yangi Pod eski Pod diskni bo'shatishini kutadi yoki ikki jarayon bitta katalogga yozadi.
- `PGDATA` ni volume ildiziga qo'yish: `lost+found` tufayli `initdb` rad etadi.
- Buzuq StatefulSet rollout'ini template'ni tuzatib "tuzaldi" deb kutish: buzuq Pod qo'lda o'chirilmaguncha hech narsa bo'lmaydi.
- Snapshot'ni yagona backup deb hisoblash, restore'ni hech qachon sinamaslik.
- Parolni manifestda `env.value` sifatida yozish va git'ga qo'yish, yoki `--from-literal` bilan shell tarixida qoldirish.
- `NotReady` node'dagi StatefulSet Pod'ini `--force --grace-period=0` bilan o'chirish: node aslida tirik bo'lsa ikki nusxa bitta diskka yozadi.
- Faqat toleration qo'yib, nodeSelector'ni unutish: baza ajratilgan node'ga emas, istalgan joyga tushadi.
- Baza Pod'larida PDB va anti-affinity yo'q: drain primary va replica'ni birga olib ketadi.
- Operator CRD'larini o'chirish: CRD o'chsa uning barcha custom resource'lari, ular bilan birga bazalar ham o'chadi. Helm bilan operator'ni `uninstall` qilishdan oldin chart CRD'lar bilan nima qilishini o'qing.
- Memory limit'siz yoki requests'dan ancha katta limit'li baza: node bosimida birinchi bo'lib evict yoki OOM bo'ladi (QoS, 4-dars).
- CNPG `ScheduledBackup` jadvalini 5 maydonli crontab deb yozish: birinchi maydon soniya.
- `csi-hostpath-sc` ni "haqiqiy" storage deb o'ylash: hamma volume bitta node'da, u node o'chsa hammasi yo'qoladi.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ – StatefulSet (partition, retention policy, forced rollback)
- https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/ – StatefulSet amaliy qo'llanma
- https://kubernetes.io/docs/concepts/cluster-administration/node-shutdown/ – graceful va non-graceful node shutdown, `out-of-service` taint
- https://kubernetes.io/docs/concepts/extend-kubernetes/operator/ – operator pattern
- https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/ – CRD
- https://cloudnative-pg.io/docs/ – CloudNativePG hujjati (Installation, Quickstart, Backup, Recovery, Scheduling)
- https://github.com/cloudnative-pg/charts – CNPG Helm chart'lari
- https://kubernetes.io/docs/concepts/storage/volume-snapshots/ – VolumeSnapshot
- https://kubernetes.io/docs/concepts/storage/volume-snapshot-classes/ – VolumeSnapshotClass
- https://github.com/kubernetes-csi/external-snapshotter – snapshot CRD'lari va controller
- https://github.com/kubernetes-csi/csi-driver-host-path – sinov CSI driver'i
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ – taint va toleration
- https://www.postgresql.org/docs/current/backup.html – PostgreSQL backup usullari
- https://www.postgresql.org/docs/current/continuous-archiving.html – WAL arxivi va PITR
- https://hub.docker.com/_/postgres – rasmiy image, `PGDATA` va muhit o'zgaruvchilari
- https://velero.io/docs/ – klaster darajasidagi backup

---

## Birga bajaramiz

Vazifalardan boshqa misol: Redis'ni bitta nusxali StatefulSet sifatida ishga tushiramiz, ma'lumot yozamiz, snapshot olamiz, ma'lumotni "buzamiz" va snapshot'dan yangi PVC yaratib, uni alohida tekshiruv Pod'ida ochamiz. Yo'l davomida Secret'ni xavfsiz yaratish, headless Service, `volumeClaimTemplates`, snapshot va restore zanjiri, hamda PVC'larning StatefulSet'dan keyin qolishini ko'ramiz. Ish alohida `walk` namespace'ida, ikkala mashinada bir xil. Laboratoriyadagi snapshot komponentlari va hostpath driver o'rnatilgan bo'lishi kerak.

1. Namespace va Secret. Parol tasodifiy, repo'dan tashqaridagi faylda, shell tarixiga tushmaydi:

```
$ kubectl create namespace walk
namespace/walk created
$ mkdir -p ~/.secrets && umask 077 && printf '%s' "$(openssl rand -hex 16)" > ~/.secrets/redis-pass
$ kubectl -n walk create secret generic redis-auth --from-file=password=$HOME/.secrets/redis-pass
secret/redis-auth created
```

`umask 077` yangi faylni faqat sizga o'qiladigan qiladi (Linux moduli, ruxsatlar). `--from-file=password=...` Secret'dagi kalit nomini `password` qiladi.

2. Manifest `redis.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata: { name: redis, namespace: walk }
spec:
  clusterIP: None
  selector: { app: redis }
  ports: [{ name: redis, port: 6379 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: redis, namespace: walk }
spec:
  serviceName: redis
  replicas: 1
  selector: { matchLabels: { app: redis } }
  template:
    metadata: { labels: { app: redis } }
    spec:
      containers:
        - name: redis
          image: redis:7.4
          env:
            - name: REDISCLI_AUTH
              valueFrom: { secretKeyRef: { name: redis-auth, key: password } }
          command: ["sh", "-c", "exec redis-server --appendonly yes --requirepass \"$REDISCLI_AUTH\""]
          ports: [{ containerPort: 6379, name: redis }]
          readinessProbe:
            exec: { command: ["sh", "-c", "redis-cli ping | grep -q PONG"] }
            periodSeconds: 5
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { cpu: 100m, memory: 128Mi }
          volumeMounts: [{ name: data, mountPath: /data }]
  volumeClaimTemplates:
    - metadata: { name: data }
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: csi-hostpath-sc
        resources: { requests: { storage: 1Gi } }
```

Tanlovlar: `REDISCLI_AUTH` o'zgaruvchisini `redis-cli` o'zi o'qiydi, shuning uchun parol buyruq qatorida `-a` bilan ko'rinmaydi va probe ham autentifikatsiyadan o'tadi. `exec` shell'ni Redis jarayoni bilan almashtiradi: SIGTERM to'g'ridan-to'g'ri Redis'ga boradi (4-dars, graceful shutdown). `--appendonly yes` har yozuvni AOF (append-only file) jurnaliga yozadi, bu PostgreSQL'dagi WAL'ga o'xshash rol. `requests` = `limits`: Guaranteed QoS. `/data` rasmiy image'ning ma'lumot katalogi.

3. Qo'llash va kutish:

```
$ kubectl apply -f redis.yaml
service/redis created
statefulset.apps/redis created
$ kubectl -n walk rollout status statefulset/redis
partitioned roll out complete: 1 new pods have been updated...
$ kubectl -n walk get pods,pvc
NAME          READY   STATUS    RESTARTS   AGE
pod/redis-0   1/1     Running   0          25s

NAME                                 STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS      VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/data-redis-0   Bound    pvc-<uid>    1Gi        RWO            csi-hostpath-sc   <unset>                 25s
```

`rollout status` StatefulSet uchun ham `partitioned` so'zini ishlatadi, partition 0 bo'lsa ham: bu oddiy holat. PVC nomi `data-redis-0`: template nomi va Pod nomi.

4. Ma'lumot yozish. Kalitlarni yozib, `SAVE` bilan diskka majburan tushiramiz:

```
$ kubectl -n walk exec redis-0 -- redis-cli set order:1 paid
OK
$ kubectl -n walk exec redis-0 -- redis-cli set order:2 shipped
OK
$ kubectl -n walk exec redis-0 -- redis-cli save
OK
```

`SAVE` Redis'ning to'liq nusxasini (RDB fayl) sinxron yozadi. Snapshot crash-consistent bo'lgani uchun, oldin ilovaning o'zi diskka izchil holatni yozib qo'yishi foydali: bu 5-bo'limdagi "ilova darajasida izchillik" ning eng oddiy shakli.

5. Snapshot. `snap.yaml`:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: { name: redis-snap1, namespace: walk }
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: data-redis-0
```

```
$ kubectl apply -f snap.yaml
volumesnapshot.snapshot.storage.k8s.io/redis-snap1 created
$ kubectl -n walk get volumesnapshot redis-snap1 -o jsonpath='{.status.readyToUse}{"\n"}'
true
```

`true` chiqmaguncha bir necha soniya kuting. `false` da qotib qolsa, `kubectl -n walk describe volumesnapshot redis-snap1` dagi Events'ni o'qing.

6. "Halokat". Kalitni o'chiramiz:

```
$ kubectl -n walk exec redis-0 -- redis-cli del order:1
(integer) 1
$ kubectl -n walk exec redis-0 -- redis-cli get order:1

```

Bo'sh qator: kalit yo'q (`redis-cli` terminal bo'lmaganda `(nil)` o'rniga bo'sh qator chiqaradi).

7. Snapshot'dan yangi PVC va tekshiruv Pod'i. Ishlab turgan Redis'ga tegmaymiz: tiklangan nusxani yonida ochib, ichini ko'ramiz. `inspect.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: redis-restored, namespace: walk }
spec:
  storageClassName: csi-hostpath-sc
  dataSource: { name: redis-snap1, kind: VolumeSnapshot, apiGroup: snapshot.storage.k8s.io }
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 1Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: redis-inspect, namespace: walk }
spec:
  containers:
    - name: redis
      image: redis:7.4
      command: ["redis-server", "--appendonly", "yes", "--port", "6380"]
      volumeMounts: [{ name: data, mountPath: /data }]
  volumes:
    - name: data
      persistentVolumeClaim: { claimName: redis-restored }
```

Tekshiruv nusxasi parolsiz va boshqa portda: u faqat Pod ichidan, qisqa muddat ishlatiladi va hech qanday Service unga ishora qilmaydi.

```
$ kubectl apply -f inspect.yaml
persistentvolumeclaim/redis-restored created
pod/redis-inspect created
$ kubectl -n walk wait --for=condition=Ready pod/redis-inspect --timeout=60s
pod/redis-inspect condition met
$ kubectl -n walk exec redis-inspect -- redis-cli -p 6380 mget order:1 order:2
paid
shipped
```

`order:1` qaytdi: tiklangan disk snapshot lahzasidagi holatda. Asl `redis-0` da u hali ham yo'q, ikki disk endi mustaqil. Haqiqiy tiklashda shu yerdan ikki yo'l bor: kerakli kalitlarni tekshiruv nusxasidan asliga ko'chirish, yoki 5-bo'limdagi qoida bo'yicha butun StatefulSet'ni tiklangan disk bilan qayta ko'tarish.

8. Tozalash va PVC hayot sikli:

```
$ kubectl -n walk delete pod redis-inspect
pod "redis-inspect" deleted
$ kubectl -n walk delete statefulset redis
statefulset.apps "redis" deleted
$ kubectl -n walk get pvc
NAME             STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS      VOLUMEATTRIBUTESCLASS   AGE
data-redis-0     Bound    pvc-<uid1>    1Gi        RWO            csi-hostpath-sc   <unset>                 9m
redis-restored   Bound    pvc-<uid2>    1Gi        RWO            csi-hostpath-sc   <unset>                 3m
```

StatefulSet o'chdi, `data-redis-0` esa qoldi (default `whenDeleted: Retain`). `redis.yaml` ni qayta `apply` qilsangiz, yangi `redis-0` shu PVC'ni topadi va `order:2` joyida bo'ladi. Butunlay tozalash:

```
$ kubectl delete namespace walk
namespace "walk" deleted
```

Namespace bilan PVC'lar, VolumeSnapshot va (`deletionPolicy: Delete` bo'lgani uchun) storage'dagi snapshot ham o'chadi. `rm ~/.secrets/redis-pass` ni ham unutmang.

---

## Vazifalar

Barchasini `kubernetes/12-stateful/` da bajaring (`make new m=kubernetes n=12 name=stateful`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar shu papkada, parollar faqat Laboratoriyadagi usul bilan fayldan yaratilgan Secret'da (buyruqni README'ga parolsiz yozing). Vazifalar `st` namespace'ida, CNPG o'z `cnpg-system` namespace'ida.

### A. StatefulSet

1. **Stable identity.** `nginx` (yoki `busybox`) bilan 3 replica'li StatefulSet va headless Service yarating, har Pod o'z hostname'ini PVC'dagi faylga yozsin. Yaratilish tartibini `kubectl get pods -w` bilan kuzating. Vaqtinchalik Pod'dan `nslookup` bilan headless Service nomini va bitta Pod'ning to'liq DNS nomini tekshiring.

2. **Pod replacement.** `web-1` ni o'chiring. Qaytgan Pod'ning nomi, IP'si, PVC'si va fayldagi yozuvini oldingi bilan solishtiring. Nima o'zgardi, nima saqlandi? Deployment'da shu tajriba nima berar edi?

3. **Scale and PVC lifecycle.** 3 dan 1 ga scale qiling: Pod'lar qaysi tartibda o'chdi, PVC'lar bilan nima bo'ldi? Yana 3 ga scale qiling: `web-2` eski ma'lumotini ko'radimi? StatefulSet'ni o'chirib `kubectl get pvc,pv` ni yozing. Keyin `persistentVolumeClaimRetentionPolicy` bilan takrorlab farqni ko'rsating.

4. **Partition canary.** `partition: 2` qo'yib image'ni o'zgartiring. Qaysi Pod'lar yangilandi (`kubectl get pods -o custom-columns` bilan image'larni chiqaring)? Partition'ni bosqichma-bosqich 0 ga tushiring va yangilanish tartibini yozing.

5. **Stuck rollout.** Image'ni mavjud bo'lmagan tag'ga o'zgartiring. Qaysi Pod buzildi, qolganlari qaysi versiyada? Image'ni to'g'rilab apply qiling: o'zi tuzaldimi? Tuzatish uchun nima qilish kerak bo'ldi va nima uchun controller shunday yo'l tutadi?

6. **Parallel policy.** `podManagementPolicy: Parallel` bilan yangi StatefulSet yarating va yaratilish va scale-down tartibini 1 va 3-vazifalar bilan solishtiring. Qaysi turdagi ilova uchun `Parallel` to'g'ri, qaysi biri uchun xavfli?

### B. PostgreSQL qo'lda

7. **Postgres StatefulSet.** Bitta nusxali PostgreSQL'ni StatefulSet sifatida yozing: parol Secret'dan, `csi-hostpath-sc` da PVC, `pg_isready` bilan readiness va liveness, requests = limits, headless Service. `psql` bilan ulanib jadval yarating va bir necha qator qo'shing.

8. **Data survives.** Pod'ni o'chiring, keyin StatefulSet'ni o'chirib qayta yarating. Ma'lumot joyidami? Qaysi obyekt ma'lumotni ushlab turganini PV, PVC va Pod zanjiri orqali izohlang.

9. **Why not just replicas 3.** 7-vazifadagi StatefulSet'ni 3 replica'ga scale qiling. `db-0` ga yozilgan qator `db-1` da ko'rinadimi? ClusterIP Service orqali bir necha marta ulanib o'qing: natija izchilmi? Haqiqiy HA uchun yetishmayotgan kamida olti narsani sanab chiqing. Keyin 1 ga qaytaring.

### C. Operator

10. **Install CloudNativePG.** Operator'ni rasmiy hujjat bo'yicha Helm bilan o'rnating. `kubectl get crd | grep cnpg` va `kubectl api-resources --api-group=postgresql.cnpg.io` chiqishini yozing. `kubectl explain cluster.spec --api-version=postgresql.cnpg.io/v1` dan uchta maydonni tanlab nima qilishini yozing.

11. **CNPG cluster.** 3 instance'li `Cluster` yarating (default `standard` StorageClass'da). Operator yaratgan Pod, PVC, Service va Secret'larni sanab chiqing. Qaysi Pod primary? `pg-app` Secret'idagi ma'lumot bilan `pg-rw` va `pg-ro` orqali ulaning va har birida yozishga urinib ko'ring.

12. **Failover drill.** `pg-rw` orqali har soniyada qator yozadigan sikl ishga tushiring. Primary Pod'ni o'chiring (keyin alohida: primary turgan node'ni `docker stop`). Yangi primary qachon tanlandi, nechta yozuv xato berdi, eski primary qanday rolda qaytdi? 9-vazifadagi qo'lda variant bilan solishtiring.

13. **Operator reconcile.** Operator yaratgan `pg-rw` Service'ni o'chiring, keyin `instances` ni 2 ga, yana 3 ga o'zgartiring. Har holatda operator nima qildi (operator log'idan dalil)? Bu "domen bilimi kod sifatida" degani nimani anglatishini shu misollarda 4–5 gapda yozing.

### D. Snapshot va backup

14. **VolumeSnapshot.** 7-vazifadagi bazaga ma'lumot yozing va `data-db-0` dan `VolumeSnapshot` oling. `kubectl get volumesnapshot,volumesnapshotcontent` chiqishini yozing, `READYTOUSE` ni kuting. Snapshot'dan keyin yana qatorlar qo'shing va jadvalni `DROP` qiling.

15. **Restore from snapshot.** Bazani snapshot'dan tiklang: snapshot'dan yangi PVC, StatefulSet shu PVC bilan ishga tushsin. Qaysi qatorlar qaytdi, qaysilari yo'q? Tiklashga ketgan vaqtni o'lchang. PostgreSQL log'ida tiklanish haqida nima yozilgan va bu "crash-consistent" bilan qanday bog'liq?

16. **Snapshot without the pieces.** `standard` StorageClass'dagi PVC'dan (CNPG instance'i) `csi-hostpath-snapclass` bilan snapshot olishga urinib ko'ring. `kubectl describe volumesnapshot` dagi xabarni yozing. Snapshot ishlashi uchun kerak bo'lgan uch komponentni va bu yerda qaysi biri yetishmayotganini ayting.

17. **Logical backup CronJob.** CNPG cluster'idan har 5 daqiqada `pg_dump` oladigan CronJob yozing (5-dars): ulanish ma'lumoti `pg-app` Secret'dan, natija alohida PVC'ga, eski fayllar tozalanadi. Bitta dump'dan yangi bo'sh bazaga restore qilib tekshiring. Bu usulning RPO'si qancha?

18. **Backup plan.** README'da ilovangiz bazasi uchun reja yozing: RPO va RTO raqamlari va ularning asosi, qaysi usullar kombinatsiyasi, backup qayerda saqlanadi (cluster'dan tashqarida), saqlash muddati, restore mashqi qanchalik tez-tez. CNPG hujjatidan object storage'ga backup va PITR qanday sozlanishini o'qib, kerakli resurslarni sanab chiqing (o'rnatmasdan).

### E. Taint va toleration

19. **Dedicated node.** Bitta worker'ga `dedicated=db:NoSchedule` taint va `workload=db` label qo'ying. Toleration'siz 6 replica'li Deployment yarating: taint'li node'ga tushdimi? Faqat toleration qo'shing: hammasi o'sha node'gami? nodeSelector qo'shing. Uch holatni jadvalda yozing.

20. **NoExecute.** Ishlab turgan Pod'lari bor node'ga `NoExecute` taint qo'ying. Pod'lar bilan nima bo'ldi? `tolerationSeconds: 60` li Pod bilan takrorlang va vaqtni o'lchang. 11-darsdagi node nosozligi mexanizmi bilan bog'lang.

21. **Database on dedicated nodes.** CNPG cluster'ini shunday sozlangki: instance'lar faqat `workload=db` node'larida (ikkita worker'ni ajrating), har node'da bittadan, boshqa ilovalar bu node'larga tushmaydi. `Cluster` spec'ida affinity va toleration qanday berilishini hujjatdan toping. Node'lardan birini drain qiling: operator va PDB qanday yo'l tutdi?

Eslatma: 20-vazifada `csi-hostpathplugin` turgan node'ga `NoExecute` qo'ysangiz, driver'ning o'zi ham evict bo'ladi va `csi-hostpath-sc` dagi hamma volume ishlamay qoladi. Avval `kubectl get pods -A -o wide | grep hostpath` bilan qaysi node ekanini tekshiring va boshqa worker'ni tanlang. Vazifalar oxirida hamma taint'larni olib tashlang.

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. README'da failover va restore mashqlarining vaqt o'lchovlari bor (qaysi mashinada o'lchangani bilan).
3. Repo'da parol, Secret manifesti va klonlangan tashqi repo'lar yo'q.
4. `kind delete cluster --name stateful` bajarilgan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- StatefulSet Deployment'ga nisbatan qaysi uch kafolatni beradi va nimani bermaydi?
- StatefulSet o'chirilganda PVC'lar nima uchun qoladi?
- `partition` qanday ishlaydi va nima uchun kerak?
- Node `NotReady` bo'lganda StatefulSet Pod'i nima uchun o'zi boshqa node'da qayta yaratilmaydi?
- Operator nima va oddiy Helm chart'dan qanday farq qiladi?
- CloudNativePG'da `-rw` va `-ro` Service'lari failover'da ilova uchun nimani yechadi?
- Snapshot nima uchun o'zi backup emas? Replica-chi?
- Snapshot'dan restore mavjud PVC bilan nima qiladi?
- Toleration va nodeSelector nima uchun birga kerak?
