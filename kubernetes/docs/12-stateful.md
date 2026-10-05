# 12-dars: Stateful workload'lar

Maqsad: 4-darsda StatefulSet bilan tanishdingiz, 7-darsda PV/PVC va CSI'ni ko'rdingiz. Bu darsda ular birlashadi: ma'lumotlar bazasini Kubernetes'da ishlatish nimani talab qiladi. StatefulSet'ning barqaror identifikatsiya, tartibli rollout va partition mexanizmlari, PostgreSQL'ni qo'lda StatefulSet bilan va operator (CloudNativePG) bilan ishga tushirish farqi, operator pattern va CRD, VolumeSnapshot orqali snapshot va restore, backup strategiyasi, hamda ma'lumotlar bazasi uchun ajratilgan node'lar (taint, toleration, nodeSelector) ko'riladi. 11-darsdagi anti-affinity va PDB shu yerda stateful ilovaga qo'llanadi, yakuniy loyihadagi backup/restore mashqi shu darsga tayanadi.

Taxminiy vaqt: 4 kun (siz uchun). Diqqat: StatefulSet nima beradi va nima bermaydi (replikatsiya, failover, backup uning ishi emas), PVC'larning hayot sikli, operator aynan qaysi "odam bilimi"ni kodga aylantiradi, snapshot backup emasligi, tekshirilmagan restore mavjud emasligi.

## Laboratoriya

- **Cluster**: kind, 1 control-plane va 3 worker (11-darsdagi config, nomi `stateful`). Bitta worker keyin ma'lumotlar bazasi uchun ajratiladi.
- **Snapshot uchun CSI driver**: kind'ning default StorageClass'i (`standard`, local-path) snapshot'ni qo'llamaydi. Sinov uchun `csi-driver-host-path` o'rnatiladi: https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/docs/deploy-1.17-and-later.md . Tartib: avval snapshot CRD'lari va snapshot controller (external-snapshotter repo'sidan), keyin driver:

```bash
git clone https://github.com/kubernetes-csi/external-snapshotter
kubectl kustomize external-snapshotter/client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize external-snapshotter/deploy/kubernetes/snapshot-controller | kubectl create -f -
git clone https://github.com/kubernetes-csi/csi-driver-host-path
csi-driver-host-path/deploy/kubernetes-latest/deploy.sh
kubectl apply -f csi-driver-host-path/examples/csi-storageclass.yaml
```

  Natijada `csi-hostpath-sc` StorageClass va `csi-hostpath-snapclass` VolumeSnapshotClass bo'lishi kerak (`kubectl get sc,volumesnapshotclass`). Bu driver faqat test uchun: ma'lumot bitta node'ning diskida yotadi. Klonlangan repo'larni ish papkasidan tashqarida saqlang yoki `.gitignore` ga qo'shing.
- **CloudNativePG**: Helm bilan (8-dars), o'rnatish hujjati: https://cloudnative-pg.io/docs/ (Installation and upgrades).
- Tozalash: `kind delete cluster --name stateful`. Parollar faqat Secret'da, manifest fayllarida ochiq yozilmaydi (sinov parollari ham commit qilinmaydi).

---

## 1. Stateless va stateful

Deployment Pod'lari almashtiriladigan: nomi tasodifiy, IP o'zgaradi, disk yo'q yoki umumiy. Ma'lumotlar bazasi uchun bu ishlamaydi:

| Talab | Nima uchun | Deployment | StatefulSet |
|-------|-----------|------------|-------------|
| Barqaror nom | replica'lar bir-birini nomi bilan topadi (primary qaysi) | yo'q | `db-0`, `db-1` |
| Har nusxaga o'z diski | har replica o'z ma'lumot nusxasini saqlaydi | bitta PVC hammaga | `volumeClaimTemplates` |
| Tartib | avval primary, keyin replica | parallel | ordinal bo'yicha |
| "Ko'pi bilan bitta" kafolati | bir xil identifikatsiyali ikki Pod ma'lumotni buzadi | yo'q | bor |

## 2. StatefulSet chuqur

### Barqaror identifikatsiya

- Pod nomi `<statefulset>-<ordinal>`, ordinal 0 dan. Pod qayta yaratilsa nomi o'sha, IP esa o'zgaradi.
- **Headless Service** (`clusterIP: None`, 6-dars) har Pod'ga DNS yozuvi beradi: `db-0.db.default.svc.cluster.local`. StatefulSet'ning `serviceName` maydoni shu Service'ga ishora qiladi. Headless Service'ning o'z nomi esa barcha Pod IP'larini qaytaradi.
- Odatda ikki Service bo'ladi: headless (a'zolar bir-birini topishi uchun) va oddiy ClusterIP (mijozlar uchun).

### volumeClaimTemplates

```yaml
volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: csi-hostpath-sc
      resources: { requests: { storage: 1Gi } }
```

Har Pod uchun `<template>-<pod>` nomli PVC yaratiladi: `data-db-0`, `data-db-1`. Pod qayta yaratilganda aynan o'z PVC'siga ulanadi, shuning uchun `db-1` har doim `db-1` ning ma'lumotini ko'radi.

**PVC'lar StatefulSet bilan birga o'chmaydi.** Scale-down yoki `kubectl delete statefulset` dan keyin PVC va ma'lumot qoladi. Bu ataylab: ma'lumotni tasodifan yo'qotishdan himoya. Xatti-harakat `persistentVolumeClaimRetentionPolicy` (`whenDeleted`, `whenScaled`: `Retain` yoki `Delete`) bilan o'zgartiriladi. Qolgan PVC'lar pul turadi (15-dars) va scale-up'da eski ma'lumot bilan qaytadi, bu replikatsiya uchun kutilmagan holat bo'lishi mumkin.

`volumeClaimTemplates` o'zgarmas: mavjud StatefulSet'da hajmni o'zgartirib bo'lmaydi. Kengaytirish PVC'larning o'zida qilinadi (StorageClass `allowVolumeExpansion: true` bo'lsa).

### Tartib

| `podManagementPolicy` | Yaratish | O'chirish (scale-down) |
|-----------------------|----------|------------------------|
| `OrderedReady` (default) | 0, 1, 2 navbat bilan, har biri `Ready` bo'lgach keyingisi | teskari: 2, 1, 0 |
| `Parallel` | hammasi birdan | hammasi birdan |

Bu faqat scale uchun. Yangilanish tartibi `updateStrategy` da.

### Rolling update va partition

`updateStrategy.type`: `RollingUpdate` (default) yoki `OnDelete` (Pod'ni o'zingiz o'chirganingizda yangilanadi).

`RollingUpdate` eng katta ordinal'dan boshlaydi (2, 1, 0), har Pod `Ready` bo'lishini kutadi. Primary odatda `-0` bo'lgani uchun oxirida yangilanadi.

`rollingUpdate.partition: N` ordinal'i N dan **katta yoki teng** Pod'larnigina yangilaydi. Bu canary: `partition: 2` bilan faqat `db-2` yangi versiyaga o'tadi, tekshirasiz, keyin partition'ni 0 gacha tushirasiz.

**Tuzoq: buzuq rollout o'zi tuzalmaydi.** `OrderedReady` bilan yangi versiya `Ready` bo'lmasa rollout to'xtaydi. Template'ni to'g'rilab qo'ysangiz ham controller buzuq Pod `Ready` bo'lishini kutaveradi. Template tuzatilgandan keyin buzuq Pod'ni qo'lda o'chirish kerak (hujjatdagi "forced rollback").

### StatefulSet nimani bermaydi

Replikatsiyani sozlash, primary tanlash, failover, backup, versiya upgrade'i (major), ulanish pool'i. StatefulSet faqat nom, disk va tartib beradi. Qolgani ilovaning yoki operatorning ishi. 11-darsdan: node o'chsa StatefulSet Pod'i o'zi boshqa node'ga ko'chmaydi (bir xil identifikatsiyali ikki nusxa xavfi), va `ReadWriteOnce` disk boshqa node'ga ulanishi uchun eski ulanish uzilishi kerak.

## 3. PostgreSQL: qo'lda va operator bilan

### Qo'lda

Bitta nusxali PostgreSQL uchun StatefulSet yetarli: rasmiy `postgres` image'i, parol Secret'dan, PVC, probe sifatida `pg_isready`, headless Service. Ma'lumot katalogining mount yo'li va `PGDATA` image versiyasiga bog'liq, Docker Hub'dagi image sahifasidan tekshiring.

HA kerak bo'lganda ro'yxat uzayadi: replica'ni `pg_basebackup` bilan boshlash, streaming replication sozlamasi, primary o'lganini aniqlash, replica'ni promote qilish, eski primary qaytsa uni replica sifatida qayta ulash (aks holda split-brain), mijozlarni yangi primary'ga yo'naltirish, WAL arxivi, backup jadvali, sertifikatlar, minor/major upgrade. Bularning har biri init container, sidecar va skriptlar demak. Shu bilimni kod sifatida yozgan dastur operator deyiladi.

### Operator pattern va CRD

- **CRD** (CustomResourceDefinition) API server'ga yangi obyekt turini qo'shadi: `kubectl get clusters.postgresql.cnpg.io`. Schema (OpenAPI), versiyalar, `status` subresource bilan.
- **Controller** shu obyektlarni kuzatadi va reconcile qiladi: istalgan holat (`spec`) va haqiqiy holat orasidagi farqni yo'qotadi. Bu Deployment controller bilan bir xil model (1-dars), faqat domen bilimi bilan: "3 instance" degani Pod, PVC, Service, Secret, replikatsiya sozlamasi va failover mantig'i.
- **Operator = CRD + controller + domen bilimi.** cert-manager (8-dars), Argo CD va Flux (10-dars) ham shu pattern.

Operator tanlashda savollar: kim qo'llab-quvvatlaydi va qancha faol, failover va backup haqiqatan sinovdan o'tganmi, upgrade yo'li, CRD versiyalari barqarormi. Operator cluster'da keng huquq bilan ishlaydi, uning xatosi hamma bazalarga ta'sir qiladi.

### CloudNativePG

CNCF loyihasi, PostgreSQL uchun operator. StatefulSet ishlatmaydi: Pod va PVC'larni o'zi to'g'ridan-to'g'ri boshqaradi, chunki failover va tartib ustidan to'liq nazorat kerak.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: pg }
spec:
  instances: 3
  storage:
    size: 1Gi
```

Shu manifestdan operator yaratadi:

| Resurs | Nom | Vazifasi |
|--------|-----|----------|
| Pod'lar | `pg-1`, `pg-2`, `pg-3` | bitta primary, qolgani streaming replica |
| Service | `pg-rw` | har doim joriy primary'ga (yozish) |
| Service | `pg-ro` | faqat replica'larga (o'qish) |
| Service | `pg-r` | istalgan instance'ga |
| Secret | `pg-app` | ilova foydalanuvchisi, parol, ulanish URI |

Primary o'lsa operator eng yangi replica'ni promote qiladi va `pg-rw` ni unga buradi, ilova faqat qayta ulanadi. `kubectl get pods -l cnpg.io/cluster=pg` va `kubectl cnpg status pg` (alohida o'rnatiladigan kubectl plugin) holatni ko'rsatadi. Backup uch usulda: plugin orqali object storage'ga (Barman Cloud Plugin, WAL arxivi va PITR bilan), CSI volume snapshot orqali, va eskirgan o'rnatilgan `barmanObjectStore`. `ScheduledBackup` dagi `schedule` olti maydonli (soniya bilan), oddiy crontab'dan farqli.

## 4. VolumeSnapshot

Snapshot bu diskning ma'lum bir lahzadagi nusxasi, storage tizimi darajasida. Kubernetes'da uchta CRD (asosiy API'ning qismi emas, alohida o'rnatiladi):

| Obyekt | O'xshashi | Vazifasi |
|--------|-----------|----------|
| `VolumeSnapshotClass` | StorageClass | qaysi driver, `deletionPolicy` |
| `VolumeSnapshot` | PVC | "shu PVC'dan snapshot ol" so'rovi, namespace ichida |
| `VolumeSnapshotContent` | PV | haqiqiy snapshot'ga ishora, cluster-scoped |

Ishlashi uchun uchta narsa kerak: snapshot CRD'lari, snapshot controller, va CSI driver'ning snapshot'ni qo'llashi (uning `csi-snapshotter` sidecar'i). Birortasi yo'q bo'lsa `VolumeSnapshot` yaratiladi, lekin `READYTOUSE` hech qachon `true` bo'lmaydi.

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: { name: data-db-0-snap1 }
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: data-db-0
```

Restore mavjud PVC'ni orqaga qaytarmaydi, snapshot'dan **yangi PVC** yaratadi:

```yaml
spec:
  storageClassName: csi-hostpath-sc
  dataSource:
    name: data-db-0-snap1
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 1Gi } }
```

- `deletionPolicy: Delete` bo'lsa `VolumeSnapshot` o'chirilganda storage'dagi snapshot ham o'chadi, `Retain` bo'lsa qoladi.
- Snapshot **crash-consistent**: disk elektr o'chgan paytdagidek holatda. PostgreSQL bundan WAL orqali tiklanadi (ma'lumot va WAL bitta volume'da bo'lsa), lekin har ilova ham emas. Ilova darajasida izchillik uchun snapshot'dan oldin yozishni to'xtatish yoki bazaning o'z backup rejimini ishlatish kerak.
- StatefulSet'ni snapshot'dan tiklash: kutilgan nomdagi PVC'ni (`data-db-0`) snapshot'dan oldindan yaratasiz, keyin StatefulSet uni topib ishlatadi.

## 5. Backup strategiyasi

| Usul | Nima | Kuchli tomoni | Zaif tomoni |
|------|------|---------------|-------------|
| Logical (`pg_dump`) | SQL yoki arxiv fayl | versiyalar orasida ko'chadi, bitta jadvalni tiklash mumkin | katta bazada sekin, PITR yo'q |
| Physical + WAL arxivi | base backup va WAL oqimi | point-in-time recovery, kichik RPO | bir xil major versiya, sozlash murakkabroq |
| Volume snapshot | disk nusxasi | tez, katta hajmda ham | storage'ga bog'liq, odatda o'sha tizimda yotadi |

- **Snapshot backup emas**, agar u asl disk bilan bir storage tizimida va bir akkauntda yotsa. Cluster, akkaunt yoki region yo'qolsa ikkalasi birga yo'qoladi. Backup boshqa joyga (object storage, boshqa region) ko'chirilgan nusxa.
- **Replica backup emas.** `DROP TABLE` replica'larga bir soniyada tarqaladi.
- **RPO** (qancha ma'lumot yo'qotishga rozimiz) va **RTO** (qancha vaqtda tiklaymiz) raqam bilan yoziladi. Kunlik `pg_dump` RPO'si 24 soat. WAL arxivi bilan daqiqalar.
- **3-2-1**: uch nusxa, ikki xil tashuvchi, bittasi boshqa joyda.
- **Tekshirilmagan backup mavjud emas.** Restore mashqi jadval bo'yicha o'tkaziladi va vaqti o'lchanadi, bu RTO'ning yagona halol manbai.
- Kubernetes obyektlari (manifestlar) GitOps bilan git'da (10-dars). Backup kerak bo'ladigani: ma'lumot va git'da bo'lmagan Secret'lar. Cluster darajasidagi backup uchun Velero kabi asboblar bor.

## 6. Taint, toleration va ajratilgan node'lar

Affinity (11-dars) Pod'ni node'ga **tortadi**. Taint teskarisi: node Pod'larni **itaradi**, faqat toleration'i bor Pod tusha oladi.

```bash
kubectl taint nodes stateful-worker3 dedicated=db:NoSchedule
kubectl taint nodes stateful-worker3 dedicated=db:NoSchedule-   # remove
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
    value: db
    effect: NoSchedule
nodeSelector:
  workload: db
```

`operator: Exists` qiymatni tekshirmaydi; `key` siz `Exists` hamma taint'ga toleration (DaemonSet agentlari uchun).

**Toleration ruxsat, yo'naltirish emas.** Toleration'li Pod taint'li node'ga tusha oladi, lekin boshqa node'ga ham tushishi mumkin. Ajratilgan node uchun ikkalasi kerak: taint (boshqalar kirmasin) va nodeSelector yoki node affinity (baza faqat shu yerga tushsin).

O'rnatilgan taint'lar: `node-role.kubernetes.io/control-plane:NoSchedule` (control-plane'ga oddiy Pod tushmasligi sababi), `node.kubernetes.io/not-ready` va `unreachable` (11-darsdagi 300 soniya), `memory-pressure`, `disk-pressure`, `unschedulable` (cordon).

Bazani ajratilgan node'larga qo'yish sabablari: shovqinli qo'shnilardan izolyatsiya (disk I/O, page cache), boshqa mashina turi (ko'p xotira, tez disk), autoscaler bu node'larni olib tashlamasligi, alohida upgrade jadvali. 15-darsda xuddi shu mexanizm spot node'lar uchun ishlatiladi.

## Tuzoqlar

- StatefulSet'ni o'chirib "tozaladim" deb o'ylash: PVC'lar va ma'lumot qoladi, to'lov davom etadi. Yoki aksincha: `whenDeleted: Delete` qo'yib, StatefulSet'ni qayta yaratish uchun o'chirish va ma'lumotni yo'qotish.
- `replicas: 3` StatefulSet'ni "HA PostgreSQL" deb hisoblash. Bu uchta mustaqil, bir-birini bilmaydigan baza.
- Bazaga Deployment va bitta `ReadWriteOnce` PVC: rollout'da yangi Pod eski Pod diskni bo'shatishini kutadi yoki ikki jarayon bitta katalogga yozadi.
- Snapshot'ni yagona backup deb hisoblash, restore'ni hech qachon sinamaslik.
- Parolni manifestda `env.value` sifatida yozish va git'ga qo'yish.
- `NotReady` node'dagi StatefulSet Pod'ini `--force --grace-period=0` bilan o'chirish: node aslida tirik bo'lsa ikki nusxa bitta diskka yozadi.
- Faqat toleration qo'yib, nodeSelector'ni unutish: baza ajratilgan node'ga emas, istalgan joyga tushadi.
- Baza Pod'larida PDB va anti-affinity yo'q: drain primary va replica'ni birga olib ketadi.
- Operator CRD'larini o'chirish: CRD o'chsa uning barcha custom resource'lari, ular bilan birga bazalar ham o'chadi.
- Memory limit'siz yoki requests'dan ancha katta limit'li baza: node bosimida birinchi bo'lib evict yoki OOM bo'ladi (QoS, 4-dars). Baza uchun Guaranteed QoS.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ – StatefulSet
- https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/ – StatefulSet amaliy qo'llanma
- https://kubernetes.io/docs/concepts/extend-kubernetes/operator/ – operator pattern
- https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/ – CRD
- https://cloudnative-pg.io/docs/ – CloudNativePG hujjati (Quickstart, Backup, Recovery)
- https://kubernetes.io/docs/concepts/storage/volume-snapshots/ – VolumeSnapshot
- https://kubernetes.io/docs/concepts/storage/volume-snapshot-classes/ – VolumeSnapshotClass
- https://github.com/kubernetes-csi/external-snapshotter – snapshot CRD'lari va controller
- https://github.com/kubernetes-csi/csi-driver-host-path – sinov CSI driver'i
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ – taint va toleration
- https://www.postgresql.org/docs/current/backup.html – PostgreSQL backup usullari

---

## Vazifalar

Barchasini `kubernetes/12-stateful/` da bajaring (`make new m=kubernetes n=12 name=stateful`). Javoblar shu papkadagi `README.md` da `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Manifestlar shu papkada, parollar faqat `kubectl create secret` bilan (buyruqni README'ga parolsiz yozing).

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

### Topshirish

Tayyor bo'lgach:
1. `make check` toza.
2. README'da failover va restore mashqlarining vaqt o'lchovlari bor.
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
