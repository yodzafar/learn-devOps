# 7-dars: Storage, Volume, PV, PVC, StorageClass, CSI

Maqsad: Kubernetes'da ma'lumot qayerda yashashini va pod o'limidan qanday omon qolishini mexanizm darajasida tushunish. Konteyner fayl tizimi vaqtinchalik; Docker modulining 3-darsida buni volume va bind mount bilan hal qilgansiz. Kubernetes'da masala murakkabroq, chunki pod istalgan node'ga tushishi mumkin: disk pod ortidan "yurishi" yoki pod disk yoniga borishi kerak. Bu darsda vaqtinchalik volume turlari, PersistentVolume va PersistentVolumeClaim modeli, statik va dinamik provisioning, access mode, reclaim policy, binding mode, kengaytirish va bularning ortida turgan CSI arxitekturasi ko'riladi. 5-darsdagi zaxira CronJob'ida PVC'ni "ishlaydigan narsa" sifatida ishlatdingiz, endi uning ichini ochamiz. Bu dars 12-dars (StatefulSet, operator, VolumeSnapshot) uchun bevosita asos.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–2 bo'limlar va A guruh, ikkinchi kun 3–6 bo'limlar, "Birga bajaramiz", B va C guruhlar, uchinchi kun 7–9 bo'limlar, D va E guruhlar (PostgreSQL vazifasi eng ko'p vaqt oladi). Diqqat: PV va PVC ning hayot sikli va ularni kim yaratishi, reclaim policy ma'lumotni qachon o'chirishi, `WaitForFirstConsumer` nima uchun kerakligi, `ReadWriteOnce` aslida nimani cheklashi, va lokal storage'ning production'dagi tarmoq diskidan farqi.

## Qanday o'qish kerak

Har bo'limdagi manifestni vaqtinchalik papkada (`~/k7-scratch`, repo'dan tashqarida) o'zingiz yozib `kubectl apply -f` qiling va chiqishni darsdagi izoh bilan solishtiring. PV nomlaridagi UID, pod suffikslari, node nomi (`dev-worker` yoki `dev-worker2`) va `AGE` sizda boshqacha bo'ladi, bunday joylar `<...>` bilan belgilangan. Storage'da hodisalar ketma-ketligi muhim: alohida terminalda `kubectl get pvc,pv -w` ni ochib qo'ying (`-w` o'zgarishlarni jonli ko'rsatadi, 5-dars). Ko'p savolga javob `kubectl describe pvc` ning `Events` qismida turadi, uni o'qishni odat qiling. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker ustidagi kind `dev` klasterida (1 control-plane + 2 worker, 2-darsdagi `kind-multi.yaml`, 3-darsda shu nom bilan qayta yaratilgan). Multipass VM'lar bu darsda kerak emas: storage mexanikasi (PV, PVC, StorageClass, binding, node affinity) kind'da to'liq ishlaydi. Haqiqiy tarmoq diski (AWS EBS) yaratilmaydi; EBS haqidagi savollar hujjat asosida yoziladi.

kind'da standart StorageClass tayyor keladi: u `local-path` provisioner orqali node konteynerining ichidagi katalogdan joy ajratadi. Bu haqiqiy disk emas, lekin Kubernetes tomonidagi hamma narsa productiondagidek ishlaydi.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| kind node'lari | host Docker Engine'idagi konteynerlar, `amd64` | Docker Desktop'ning yashirin Linux VM'idagi konteynerlar, `arm64` |
| PV ma'lumoti fizik qayerda | node konteyneri ichida (`/var/local-path-provisioner/...`) | xuddi shu yo'l, lekin VM ichidagi konteynerda; Mac fayl tizimida (Finder, `ls`) ko'rinmaydi |
| `hostPath` qaysi "host" | kind node konteyneri, Zorin'ning o'zi emas | kind node konteyneri, Mac ham, Docker Desktop VM'i ham emas |
| Node ichiga qarash | `docker exec dev-worker ls /var/local-path-provisioner` | xuddi shu buyruq, Docker CLI uni VM'ga yo'naltiradi |
| Image'lar | `busybox:1.36`, `nginx:1.28`, `postgres:17` `amd64` varianti | xuddi shu tag'lar, `arm64` varianti (uchalasi multi-arch) |
| Resurs | 4 GB bo'sh RAM yetarli | Docker Desktop'ga kamida 6 GB RAM (Settings, Resources) |

Muhim nuqta: kind'da "node" bu Docker konteyneri. Shuning uchun `hostPath: /tmp/x` Zorin'ning `/tmp` iga emas, `dev-worker` konteynerining `/tmp` iga tushadi. Bu ikkala mashinada bir xil, va bu darsdagi hamma `docker exec` buyruqlari ikkala mashinada aynan bir xil ishlaydi.

Tayyorlash:

```bash
kubectl config current-context        # must print: kind-dev
kubectl create namespace storage
kubectl config set-context --current --namespace=storage
kubectl get storageclass
```

- **Ikkinchi mashinada tiklash**: klaster holati va PV ichidagi ma'lumot mashinalar orasida ko'chmaydi, faqat manifestlar (`task_N.yaml`) va README git orqali keladi. Boshqa mashinada `kind get clusters` da `dev` bo'lmasa `kind create cluster --name dev --config kubernetes/02-cluster-setup/kind-multi.yaml`, keyin namespace va kerakli manifestlarni `apply` qiling. Volume'lardagi test fayllari va PostgreSQL qatorlari qaytadan yoziladi. 18-vazifadagi parol Secret'ini har mashinada repo'dan tashqaridagi fayldan qayta yarating.
- **Tozalash**: `kubectl delete namespace storage`, keyin `kubectl get pv` bilan qolgan PersistentVolume'larni tekshiring. PV namespace'ga tegishli emas, `Retain` siyosatidagi va qo'lda yaratilgan PV'lar namespace bilan birga o'chmaydi, ularni qo'lda o'chirasiz. `cordon` qilingan node'larni `uncordon` qiling.
- **Xavfsizlik**: `hostPath: /` kabi xavfli manifestlar faqat tushuntiriladi, ishga tushirilmaydi. Parol manifestga, README'ga va `--from-literal` orqali shell tarixiga yozilmaydi (4-dars).

---

## 1. Vaqtinchalik volume'lar

### Bu nima

Volume bu pod ichidagi konteynerlarga ulanadigan katalog. U pod darajasida e'lon qilinadi (`spec.volumes`) va har konteynerga alohida ulanadi (`volumeMounts`). Volume kerak bo'ladi, chunki konteynerning yozish qatlami (image ustidagi yupqa o'zgaruvchan qatlam, Docker 2-dars) konteyner bilan birga o'ladi: kubelet konteynerni restart qilsa, hatto o'sha pod ichida ham, yangi konteyner toza image'dan boshlanadi.

Vaqtinchalik (ephemeral) volume pod bilan birga yaratiladi va pod bilan birga yo'qoladi:

| Tur | Umri | Ishlatilishi |
|-----|------|--------------|
| `emptyDir` | pod bilan. Konteyner restart'idan omon qoladi, pod o'chirilsa yo'qoladi | konteynerlar orasida fayl almashish, kesh, vaqtinchalik fayllar |
| `configMap`, `secret` | manba obyekt bilan sinxron | konfiguratsiya va maxfiy fayllar (4-dars) |
| `downwardAPI` | pod bilan | pod metadata'sini (label, namespace, resurs limitlari) fayl sifatida berish |
| `projected` | pod bilan | bir nechta manbani bitta katalogga yig'ish (ServiceAccount token shunday ulanadi) |
| `hostPath` | node bilan | node fayl tizimidagi katalog. Faqat tizim agentlari uchun |

Qat'iy aytganda `hostPath` vaqtinchalik emas, u node yashagancha yashaydi. Lekin u doimiy storage ham emas, chunki bitta node'ga bog'langan. Shuning uchun u shu jadvalda turadi.

### Mexanizm

Pod node'ga tushganda kubelet unga katalog ochadi: `/var/lib/kubelet/pods/<pod-UID>/`. Pod'ning hamma volume'lari shu katalogning `volumes/` qismida tayyorlanadi, keyin container runtime ularni konteyner ichidagi `mountPath` ga bind mount qiladi (Docker 3-darsdagi bind mount bilan bir xil kernel mexanizmi). Konteyner restart bo'lganda kubelet yangi konteynerga xuddi shu katalogni ulaydi, shuning uchun `emptyDir` dagi fayllar qoladi. Pod o'chirilganda kubelet pod katalogini butunlay o'chiradi.

`emptyDir` standart holatda node diskida joylashadi. `medium: Memory` bilan u `tmpfs` (RAM ichidagi fayl tizimi) bo'ladi: tez, lekin yozilgan baytlar konteynerning memory hisobiga kiradi va memory limitiga yaqinlashtiradi (4-dars, OOMKilled). Diskdagi `emptyDir` da `sizeLimit` oshsa kubelet buni davriy tekshiruvda payqaydi va pod'ni evict qiladi (evict bu kubelet pod'ni majburan to'xtatib node'dan chiqarishi).

`hostPath` da `type` maydoni kubelet nimani tekshirishini aytadi: `Directory` (katalog bo'lishi shart), `DirectoryOrCreate` (bo'lmasa yaratiladi, root egaligida), `File`, `FileOrCreate`, `Socket` va boshqalar. Bo'sh qiymat hech narsani tekshirmaydi.

### Ishlaydigan misol

Vazifalardagidan boshqa misol: bitta pod'da ikki konteyner, biri `emptyDir` ga yozadi, ikkinchisi o'qiydi.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared
spec:
  volumes:
    - name: work
      emptyDir:
        sizeLimit: 50Mi
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date >> /out/log.txt; sleep 5; done"]
      volumeMounts:
        - {name: work, mountPath: /out}
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 12; tail -f /in/log.txt"]
      volumeMounts:
        - {name: work, mountPath: /in, readOnly: true}
```

- `volumes` pod darajasida bitta `emptyDir` e'lon qiladi, nomi `work`.
- Ikkala konteyner uni turli `mountPath` ga ulaydi; `reader` uchun `readOnly: true`, u yozolmaydi.

```
$ kubectl apply -f shared.yaml
pod/shared created
$ kubectl logs shared -c reader
Wed Oct  8 09:14:02 UTC 2026
Wed Oct  8 09:14:07 UTC 2026
Wed Oct  8 09:14:12 UTC 2026
$ kubectl exec shared -c reader -- touch /in/x
touch: /in/x: Read-only file system
```

- `-c reader` ko'p konteynerli pod'da qaysi konteyner log'i kerakligini aytadi.
- Uch qator `writer` yozgan vaqtlar: ikki konteyner bitta katalogni ko'radi.
- `Read-only file system` mount darajasidagi cheklov, fayl ruxsatlari emas.

### Real ishda qachon kerak

`emptyDir`: sidecar log yig'uvchi asosiy konteyner log fayllarini o'qishi, init container yuklab olgan faylni asosiy konteynerga berish (4-dars), `readOnlyRootFilesystem: true` bo'lgan konteynerga yoziladigan `/tmp` berish (13-dars). `hostPath`: faqat node darajasidagi agentlar, masalan DaemonSet ko'rinishidagi log kolektor `/var/log` ni o'qishi yoki CSI node plugin'i.

### Nima uchun shunday

Volume pod darajasida, chunki pod bu "bir joyda birga yashaydigan konteynerlar" (1-dars); umumiy katalog shu birlikka tegishli bo'lishi tabiiy. Konteyner restart'idan omon qolish esa ataylab: crash'dan keyin keshni yo'qotmaslik uchun. Generic ephemeral volume (`ephemeral.volumeClaimTemplate`) degan uchinchi yo'l ham bor: pod bilan yaratilib o'chadigan, lekin StorageClass orqali haqiqiy diskdan olinadigan volume; katta vaqtinchalik joy kerak bo'lganda ishlatiladi.

## 2. PersistentVolume va PersistentVolumeClaim

### Bu nima

Doimiy storage ikki obyektga ajratilgan, chunki ikki xil odam ikki xil savolga javob beradi:

| Obyekt | Kim yozadi | Savol | Scope |
|--------|------------|-------|-------|
| PersistentVolume (PV) | administrator yoki provisioner | disk qayerda, qanday turda, qancha | cluster-scoped |
| PersistentVolumeClaim (PVC) | ilova jamoasi | menga qancha joy va qanday kirish kerak | namespaced |
| StorageClass | administrator | disklar qanday "ishlab chiqariladi" | cluster-scoped |

Cluster-scoped degani obyekt hech qaysi namespace'ga tegishli emas (Node kabi, 1-dars). Pod PVC'ga murojaat qiladi, PVC PV'ga bog'lanadi (bind). Ilova manifesti diskning cloud'dagi ID'sini bilmaydi, shuning uchun bir xil manifest kind'da ham, EKS'da ham ishlaydi.

Frontend'dan haqiqiy o'xshatish: `package.json` dagi `"^4.2.0"` diapazoni va `package-lock.json` dagi aniq versiya. PVC diapazon kabi talab yozadi ("kamida 1Gi, RWO"), binder uni aniq PV'ga hal qiladi va natijani ikki tomonga yozib qo'yadi (PVC'da `spec.volumeName`, PV'da `spec.claimRef`), lockfile kabi: keyingi safar qayta tanlanmaydi.

### Mexanizm

kube-controller-manager ichidagi PV controller (binder) ikki ro'yxatni kuzatadi: bog'lanmagan PVC'lar va bo'sh PV'lar. Har PVC uchun u mos PV qidiradi: bir xil `storageClassName`, kerakli access mode bor, hajm so'raganidan kam emas, `selector` bo'lsa label'lar mos. Mos keladiganlar ichidan eng kichigini tanlaydi va ikkalasini `Bound` qiladi.

Bog'lanish bittaga-bitta: bitta PV faqat bitta PVC'ga tegishli. PVC so'raganidan katta PV'ga bog'lanishi mumkin, qolgan joy boshqa PVC'ga berilmaydi.

Fazalar:

| Obyekt | Faza | Ma'nosi |
|--------|------|---------|
| PV | `Available` | bo'sh, PVC kutmoqda |
| PV | `Bound` | PVC'ga bog'langan |
| PV | `Released` | PVC o'chirilgan, lekin PV hali tozalanmagan |
| PV | `Failed` | avtomatik tozalash muvaffaqiyatsiz |
| PVC | `Pending` | mos PV hali yo'q yoki yaratilmagan |
| PVC | `Bound` | PV'ga bog'langan |
| PVC | `Lost` | bog'langan PV yo'qolgan |

### Ishlaydigan misol

Qo'lda yozilgan PV va unga mos PVC (vazifadagidan boshqa hajm va class):

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-archive
spec:
  capacity: {storage: 2Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: archive
  hostPath: {path: /data/pv-archive, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: archive
spec:
  storageClassName: archive
  accessModes: [ReadWriteOnce]
  resources:
    requests: {storage: 500Mi}
```

```
$ kubectl get pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-archive   2Gi        RWO            Retain           Bound    storage/archive   archive        <unset>                          8s
$ kubectl get pvc
NAME      STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
archive   Bound    pv-archive   2Gi        RWO            archive        <unset>                 8s
```

- PV qatori: `CLAIM storage/archive` PV qaysi namespace'dagi qaysi PVC'ga bog'langanini ko'rsatadi; PV o'zi namespace'siz, shuning uchun namespace nom ichida yoziladi.
- `STORAGECLASS archive` bu yerda shunchaki moslash yorlig'i: `archive` nomli StorageClass obyekti mavjud bo'lishi shart emas, statik binding faqat nomni solishtiradi.
- `VOLUMEATTRIBUTESCLASS <unset>` disk parametrlarini (masalan IOPS) keyin o'zgartirish uchun nisbatan yangi mexanizm, bu darsda ishlatilmaydi.
- PVC qatori: `CAPACITY 2Gi`, garchi 500Mi so'ralgan bo'lsa ham. PVC olgan narsa PV'ning butun hajmi.

Pod PVC'ni nomi bilan ulaydi:

```yaml
  volumes:
    - name: data
      persistentVolumeClaim: {claimName: archive}
```

### Real ishda qachon kerak

PVC har kuni yoziladi: baza, fayl yuklash katalogi, Prometheus ma'lumoti. PV'ni qo'lda kamdan-kam yozasiz: mavjud diskni (eski NFS katalogi, avvaldan yaratilgan cloud disk) klasterga ulashda yoki `Retain` qilingan ma'lumotni tiklashda.

### Nima uchun shunday

Ajratish mas'uliyatni ajratadi: ilova jamoasi "nima kerak"ni, platforma jamoasi "qayerdan"ni hal qiladi. Bu Node va Pod ajratilishiga o'xshaydi: pod "menga 1 CPU kerak" deydi, qaysi mashina ekanini scheduler tanlaydi. PVC namespaced, chunki u ilovaga tegishli va RBAC (13-dars) bilan himoyalanadi; PV cluster-scoped, chunki disk klaster resursi.

## 3. Statik va dinamik provisioning

### Bu nima

Provisioning bu PV va uning ortidagi haqiqiy diskni paydo qilish.

**Statik**: administrator PV'larni oldindan qo'lda yaratadi (2-bo'lim misoli). PVC mos PV qidiradi; mos PV bo'lmasa PVC `Pending` qoladi, toki kimdir mosini yaratmaguncha.

**Dinamik**: PVC yaratilganda StorageClass'da ko'rsatilgan provisioner PV'ni va ortidagi diskni avtomatik yaratadi. Zamonaviy klasterlarda deyarli hamma narsa shunday ishlaydi. Docker 3-darsdagi `docker volume create` ga o'xshash: siz nom berasiz, driver joyni o'zi ajratadi.

### Mexanizm

StorageClass bu "disk retsepti":

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: rancher.io/local-path     # which driver creates volumes
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
parameters: {}                         # driver-specific: disk type, IOPS, encryption
```

Dinamik yo'l:

1. PVC yaratiladi, unda `storageClassName` (yoki standart class) bor.
2. Provisioner (alohida pod, controller) PVC'larni kuzatadi va o'z nomi yozilgan class'dagilarini oladi.
3. U haqiqiy joy ajratadi (cloud API chaqiruvi yoki, local-path'da, node'da katalog) va PV obyektini yozadi. PV nomi odatda `pvc-<PVC UID>`.
4. Binder PV va PVC'ni `Bound` qiladi.

Qoidalar:

- Standart StorageClass `storageclass.kubernetes.io/is-default-class: "true"` annotation'i bilan belgilanadi. PVC'da `storageClassName` yozilmasa shu ishlatiladi.
- `storageClassName: ""` (bo'sh satr) "hech qanday class, faqat class'siz statik PV" degani. Yozilmagan maydon va bo'sh satr boshqa-boshqa narsa.
- StorageClass'ning ko'p maydonlari yaratilgandan keyin o'zgartirilmaydi. Mavjud PV'lar class o'zgarishidan ta'sirlanmaydi: reclaim policy kabi qiymatlar PV yaratilgan paytda unga ko'chiriladi.

### Ishlaydigan misol

kind'dagi standart class:

```
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  6d
```

- `standard (default)` class nomi; `(default)` annotation'dan keladi.
- `PROVISIONER rancher.io/local-path` PVC'lar uchun kim disk yaratadi.
- Qolgan uch ustun 5, 6 va 7-bo'limlarda.

Provisioner'ning o'zi oddiy Deployment:

```
$ kubectl get deploy -n local-path-storage
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
local-path-provisioner   1/1     1            1           6d
```

Bu muhim kuzatish: dinamik provisioning Kubernetes yadrosining sehri emas, klasterda ishlayotgan oddiy controller pod'i. U o'lsa yangi PVC'lar `Pending` da qoladi.

### Real ishda qachon kerak

Managed klasterda (EKS, GKE, AKS) siz faqat PVC yozasiz, hammasi dinamik. Bir nechta class odatda bo'ladi: arzon HDD, tez SSD, shifrlangan, `Retain` siyosatli. Statik yo'l mavjud ma'lumotni klasterga olib kirish va tiklashda qoladi.

### Nima uchun shunday

Kubernetes'ning dastlabki versiyalarida faqat statik yo'l bor edi: administrator 50 ta PV'ni oldindan yaratib qo'yardi va ular bekor turardi yoki hajmi to'g'ri kelmasdi. StorageClass "talab bo'yicha ishlab chiqarish"ni berdi va storage turlarini nom ortiga yashirdi.

## 4. Access mode

### Bu nima

Access mode volume'ni qanday ulash mumkinligini aytadi:

| Rejim | Qisqa | Ma'nosi |
|-------|-------|---------|
| `ReadWriteOnce` | RWO | bitta node tomonidan o'qish-yozish uchun ulanadi |
| `ReadOnlyMany` | ROX | ko'p node faqat o'qish uchun |
| `ReadWriteMany` | RWX | ko'p node o'qish-yozish uchun |
| `ReadWriteOncePod` | RWOP | butun klasterda faqat bitta pod (faqat CSI volume'lar uchun) |

### Mexanizm

Access mode ikki joyda ishlatiladi: binding'da (PVC so'ragan rejim PV'da bo'lishi kerak) va attach paytida (volume qaysi node'ga ulanishi mumkin). RWO'ni Kubernetes "bitta node" darajasida nazorat qiladi: volume bir node'ga biriktirilgan bo'lsa, boshqa node'dagi pod uchun attach rad etiladi (`Multi-Attach error`). Bir node ichidagi bir nechta pod esa RWO volume'ni bemalol birga ishlatadi.

Access mode yozishdan himoya qilmaydi va fayl darajasida lock bermaydi. Ikki pod bitta faylga yozsa, natija ilova va fayl tizimiga bog'liq.

Qaysi rejim mumkinligi storage turiga bog'liq: blok disklar (AWS EBS, GCE PD) faqat RWO, chunki blok qurilmani (xom disk, ustiga fayl tizimi yoziladi) ikki mashinaga birga ulash fayl tizimini buzadi: har mashina keshni o'zicha saqlaydi va boshqasining yozganini bilmaydi. RWX uchun tarmoq fayl tizimi kerak (NFS, AWS EFS, CephFS), u yerda fayl tizimini server boshqaradi.

### Ishlaydigan misol

```
$ kubectl get pvc archive -o jsonpath='{.spec.accessModes}{"\n"}'
["ReadWriteOnce"]
$ kubectl explain pv.spec.accessModes
KIND:       PersistentVolume
VERSION:    v1

FIELD: accessModes <[]string>

DESCRIPTION:
    accessModes contains all ways the volume can be mounted. More info:
    https://kubernetes.io/docs/concepts/storage/persistent-volumes#access-modes
```

- Birinchi buyruq PVC so'ragan rejimlar ro'yxatini chiqaradi; ro'yxat, chunki PV bir nechta rejimni qo'llashi mumkin, lekin volume bir vaqtning o'zida bitta rejimda ulanadi.
- `kubectl explain` (1-dars) maydon hujjatini klasterning o'zidan oladi; tavsifdagi "all ways the volume can be mounted" ana shu ma'no.

### Real ishda qachon kerak

Amaliy xulosa: blok diskli Deployment'ni bir nechta node'ga yoyib bo'lmaydi. "Har replikaga o'z diski" kerak bo'lsa StatefulSet (12-dars), "umumiy fayllar" kerak bo'lsa RWX yoki, ko'pincha yaxshiroq, object storage (S3): frontend'dan tanish yuklangan rasmlar odatda diskda emas, S3'da turadi. RWOP "bu volume'ga ikkinchi yozuvchi hech qachon ulanmasin" kafolati kerak bo'lganda.

### Nima uchun shunday

Kubernetes storage'ni ichidan bilmaydi, shuning uchun u faqat ulash nuqtasini nazorat qila oladi, faylga yozishni emas. "Once" ning "bitta node" ekani tarixiy: cheklov blok qurilma darajasida paydo bo'lgan, u esa node'ga biriktiriladi. Pod darajasidagi kafolat kerak bo'lganda keyinroq alohida RWOP qo'shildi.

## 5. Reclaim policy

### Bu nima

PVC o'chirilganda PV va ortidagi ma'lumot bilan nima bo'lishini `persistentVolumeReclaimPolicy` hal qiladi:

| Qiymat | PVC o'chirilganda | Qachon |
|--------|-------------------|--------|
| `Delete` | PV va haqiqiy disk o'chiriladi | dinamik provisioning standarti |
| `Retain` | PV `Released` holatida qoladi, ma'lumot saqlanadi, qayta ishlatish uchun qo'lda aralashuv kerak | muhim ma'lumot |

Uchinchi qiymat `Recycle` (ichini `rm -rf` qilib qayta berish) deprecated, ishlatilmaydi.

### Mexanizm

`Delete` da PVC o'chgach binder PV'ni `Released` qiladi va provisioner'ga "o'chir" deydi; provisioner haqiqiy joyni (cloud disk yoki node'dagi katalog) o'chiradi, keyin PV obyektini. `Retain` da hech kim hech narsa o'chirmaydi.

`Released` PV yangi PVC'ga avtomatik bog'lanmaydi: unda eski PVC'ga ishora (`spec.claimRef`) qolgan, va ichida oldingi egasining ma'lumoti bor. Administrator ma'lumotni ko'rib chiqadi va `claimRef` ni tozalaydi yoki PV'ni qayta yaratadi.

Himoya mexanizmi: ishlatilayotgan PVC o'chirilsa, u `kubernetes.io/pvc-protection` finalizer'i tufayli `Terminating` holatida qoladi va pod'lar undan foydalanishni tugatgandagina haqiqatda o'chadi. Finalizer bu `metadata.finalizers` ro'yxatidagi yozuv: u bo'sh bo'lmaguncha API server obyektni o'chirmaydi, faqat `deletionTimestamp` qo'yadi. PV uchun xuddi shunday `kubernetes.io/pv-protection` bor.

### Ishlaydigan misol

Mavjud dinamik PV'ning siyosatini o'zgartirish (rasmiy hujjatdagi usul):

```
$ kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
persistentvolume/<pv-name> patched
$ kubectl get pv <pv-name>
NAME        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM            STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
<pv-name>   1Gi        RWO            Retain           Bound    storage/<pvc>    standard       <unset>                          4m
```

- `patch` (3-dars) PV'ning bitta maydonini o'zgartiradi; StorageClass'dagi `Delete` endi bu PV'ga ta'sir qilmaydi, chunki qiymat PV ichida saqlanadi.
- `RECLAIM POLICY Retain`: shu paytdan PVC o'chirilsa ham disk qoladi.

### Real ishda qachon kerak

**`kubectl delete namespace` tuzog'i.** Namespace o'chirilsa ichidagi PVC'lar o'chadi, `Delete` siyosatida esa disklar ham. Bitta buyruq bilan production bazasi yo'qoladi. Muhim ma'lumot uchun uchalasi birga kerak: `Retain` (yoki `Retain` li alohida StorageClass), RBAC cheklovi (13-dars) va zaxira (12-dars: VolumeSnapshot).

### Nima uchun shunday

Dinamik disklar uchun `Delete` standart, chunki aks holda har sinov PVC'si cloud hisobida "yetim" disk qoldirib, pul olib turardi. `Retain` ehtiyotkor tanlov: Kubernetes ma'lumotni o'chirmaydi, lekin qayta ishlatishni ham avtomatlashtirmaydi, chunki begona ma'lumotni yangi egaga berish xavfsizlik muammosi.

## 6. volumeBindingMode

### Bu nima

| Qiymat | PV qachon yaratiladi va bog'lanadi |
|--------|------------------------------------|
| `Immediate` | PVC yaratilgan zahoti |
| `WaitForFirstConsumer` | PVC'ni ishlatadigan birinchi pod schedule qilinganda |

### Mexanizm

Disk topologiyaga bog'langan: cloud blok diski bitta availability zone'da (cloud region ichidagi alohida ma'lumot markazi) yashaydi, lokal disk bitta node'da. `Immediate` da disk tasodifiy zonada yaratiladi, keyin scheduler pod'ni faqat o'sha zonaga joylashtira oladi; u yerda CPU yoki xotira yetmasa yoki pod'ning boshqa cheklovlari (affinity, taint, 11–12 darslar) to'g'ri kelmasa pod `Pending` qoladi.

`WaitForFirstConsumer` da tartib teskari:

1. PVC yaratiladi va `Pending` turadi, provisioner hali hech narsa qilmaydi.
2. PVC'ni ishlatadigan pod yaratiladi. Scheduler barcha cheklovlarni hisobga olib node tanlaydi va PVC'ga `volume.kubernetes.io/selected-node: <node>` annotation'ini yozadi.
3. Provisioner shu annotation'ni ko'rib, diskni aynan o'sha node yoki zonada yaratadi.
4. PV'ning `spec.nodeAffinity` maydoniga disk qayerdan foydalanish mumkinligi yoziladi. Bundan keyin scheduler bu PVC'li har qanday pod'ni faqat shu joyga qo'yadi.

### Ishlaydigan misol

Pod'siz PVC'ning event'i:

```
$ kubectl describe pvc <pvc>
...
Events:
  Type    Reason                Age               From                         Message
  ----    ------                ----              ----                         -------
  Normal  WaitForFirstConsumer  5s (x3 over 30s)  persistentvolume-controller  waiting for first consumer to be created before binding
```

- `Reason WaitForFirstConsumer` va `From persistentvolume-controller`: bu binder'ning ataylab kutishi, xato emas.
- `5s (x3 over 30s)` event takrorlanib turibdi: controller vaqti-vaqti bilan qayta tekshiradi.

Oqibati: `WaitForFirstConsumer` bilan PVC pod yaratilmaguncha `Pending` turadi. Bu nosozlik emas (5-darsda ham ko'rgansiz).

### Real ishda qachon kerak

Ko'p zonali cloud klasterlarda va har qanday lokal storage'da `WaitForFirstConsumer` deyarli majburiy. Pod `Pending` da qolib, `describe pod` da `volume node affinity conflict` yozuvi chiqsa, bu "pod tushishi mumkin bo'lgan node'lar disk turgan joyga mos emas" degani: disk bir zonada, bo'sh node'lar boshqasida.

### Nima uchun shunday

`Immediate` tarixan birinchi bo'lgan: storage hamma joydan ko'rinadi (NFS) deb faraz qilingan. Zonali disklar ommalashgach, storage va scheduling qarorlarini birlashtirish kerak bo'ldi; scheduler'ni disk haqida o'ylashga majburlashdan ko'ra, provisioner'ni scheduler qarorini kutishga majburlash soddaroq chiqdi.

## 7. Hajmni kengaytirish

### Bu nima

Expansion bu bog'langan PVC hajmini ma'lumotni yo'qotmasdan oshirish. StorageClass'da `allowVolumeExpansion: true` bo'lsa va driver buni qo'llasa, PVC'ning `spec.resources.requests.storage` qiymatini oshirish kifoya.

### Mexanizm

1. Siz PVC'dagi `requests.storage` ni oshirasiz. API server class'da expansion ruxsat etilganini tekshiradi.
2. Controller tomonda driver haqiqiy diskni kattalashtiradi (cloud API: "diskni 20Gi qil").
3. Node tomonda kubelet fayl tizimini yangi hajmgacha kengaytiradi; ko'p driver'larda pod ishlab turgan holda.
4. PVC `status.capacity` yangilanadi. Oraliq holatlar `status.conditions` da (`Resizing`, `FileSystemResizePending`) va event'larda ko'rinadi.

Qoidalar:

- Faqat kattalashtirish mumkin. Kichraytirish yo'q: yangi kichik PVC yaratib ma'lumotni ko'chirish kerak ("Birga bajaramiz" shu ko'chirishni ko'rsatadi).
- StatefulSet'ning `volumeClaimTemplates` i o'zgarmas: mavjud PVC'lar alohida tahrirlanadi (12-dars).
- local-path provisioner hajmni majburlamaydi ham, kengaytirmaydi ham (9-bo'lim).

### Ishlaydigan misol

Class expansion'ni qo'llaydimi:

```
$ kubectl get storageclass standard -o jsonpath='{.allowVolumeExpansion}{"\n"}'

$ kubectl get storageclass -o custom-columns=NAME:.metadata.name,EXPAND:.allowVolumeExpansion
NAME       EXPAND
standard   <none>
```

- Birinchi buyruq bo'sh qator qaytardi: maydon umuman yozilmagan, bu `false` bilan teng.
- `custom-columns` (5-dars) bir nechta class'ni bir ko'rishda solishtirishga qulay; `<none>` "maydon yo'q" degani.

### Real ishda qachon kerak

Baza diski to'lishi production'dagi eng ko'p uchraydigan storage hodisasi. Disk to'lsa baza yozishni to'xtatadi. Shuning uchun StorageClass yaratishda `allowVolumeExpansion: true` oldindan qo'yiladi va disk to'lishiga alert yoziladi (observability moduli: `kubelet_volume_stats_*` metrikalari).

### Nima uchun shunday

Kichraytirish ataylab yo'q: fayl tizimini kichraytirish ma'lumot qayerda yotganini bilishni talab qiladi, ko'p fayl tizimlari (masalan XFS) buni umuman qo'llamaydi, cloud disklar ham faqat kattalashadi. Xavfli va kam kerak bo'ladigan amalni API'ga qo'shmaslik oqilona.

## 8. CSI arxitekturasi

### Bu nima

Container Storage Interface (CSI) bu storage tizimlarini konteyner orkestratorlariga ulash standarti (gRPC API spetsifikatsiyasi). Avval storage drayverlari Kubernetes kodining ichida (in-tree) edi; endi ular alohida loyihalar, klasterga oddiy workload sifatida o'rnatiladi. Eski in-tree turlar (masalan `awsElasticBlockStore`) CSI drayverlariga ko'chirilgan: eski manifest yozilsa ham, ichkarida CSI driver ishlaydi.

### Mexanizm

CSI driver ikki qismdan iborat:

| Qism | Qanday ishlaydi | Vazifasi |
|------|-----------------|----------|
| Controller plugin | Deployment yoki StatefulSet, odatda 1–2 replika | storage API bilan gaplashadi: disk yaratish, o'chirish, node'ga biriktirish (attach), snapshot, kengaytirish |
| Node plugin | DaemonSet, har node'da (4-dars) | diskni node'da formatlash va pod katalogiga mount qilish |

Driver konteyneri yonida Kubernetes jamoasi yozgan standart yordamchi sidecar'lar ishlaydi:

| Sidecar | Nimani kuzatadi | Driver'dan nima so'raydi |
|---------|-----------------|--------------------------|
| `external-provisioner` | PVC | `CreateVolume`, `DeleteVolume` |
| `external-attacher` | VolumeAttachment | `ControllerPublishVolume` (attach) |
| `external-resizer` | PVC hajmi o'zgarishi | `ControllerExpandVolume` |
| `external-snapshotter` | VolumeSnapshot (12-dars) | `CreateSnapshot` |
| `node-driver-registrar` | node tomonda | driver'ni kubelet'ga tanitadi |

Sidecar'lar Kubernetes API'ni kuzatadi va driver bilan pod ichidagi Unix socket ustidan gRPC orqali gaplashadi. Shu tufayli driver muallifi Kubernetes API'ni bilishi shart emas, faqat CSI spetsifikatsiyasini amalga oshiradi.

Dinamik PVC'ning to'liq yo'li:

1. PVC yaratiladi, pod schedule qilinadi (`WaitForFirstConsumer`).
2. `external-provisioner` driver'dan disk yaratishni so'raydi va PV obyektini yozadi; PVC `Bound`.
3. Attach: attach-detach controller VolumeAttachment obyektini yaratadi, `external-attacher` diskni tanlangan node'ga biriktiradi.
4. Mount: o'sha node'dagi kubelet node plugin'ga murojaat qiladi, u diskni formatlab (kerak bo'lsa) pod katalogiga ulaydi.
5. Konteyner ishga tushadi.

Tegishli API obyektlari: `CSIDriver` (klasterda qaysi driver bor va uning xususiyatlari), `CSINode` (har node'da qaysi driver ro'yxatdan o'tgan), `VolumeAttachment` (qaysi volume qaysi node'ga biriktirilgan).

### Ishlaydigan misol

```
$ kubectl api-resources --api-group=storage.k8s.io
NAME                   SHORTNAMES   APIVERSION           NAMESPACED   KIND
csidrivers                          storage.k8s.io/v1    false        CSIDriver
csinodes                            storage.k8s.io/v1    false        CSINode
csistoragecapacities                storage.k8s.io/v1    true         CSIStorageCapacity
storageclasses         sc           storage.k8s.io/v1    false        StorageClass
volumeattachments                   storage.k8s.io/v1    false        VolumeAttachment
volumeattributesclasses             storage.k8s.io/v1    false        VolumeAttributesClass
```

- `NAMESPACED false` deyarli hammasida: storage infratuzilmasi klaster darajasida.
- `SHORTNAMES sc`: `kubectl get sc` qisqa yozuvi.
- `csistoragecapacities` namespaced: driver har topologiya bo'lagida qancha bo'sh joy borligini e'lon qiladi, scheduler buni hisobga olishi mumkin.

Ro'yxat klaster versiyasiga qarab biroz farq qilishi mumkin; muhimi CSI obyektlari nomini tanish.

### Real ishda qachon kerak

Pod `ContainerCreating` da osilib qolsa va event'larda `FailedAttachVolume` yoki `FailedMount` bo'lsa, muammo 3 yoki 4-qadamda. 3-qadam muammosi: `kubectl get volumeattachments` va controller plugin log'lari; 4-qadam muammosi: o'sha node'dagi node plugin log'lari. Managed klasterda driver ko'pincha add-on sifatida o'rnatiladi, uning cloud huquqlari (IAM) alohida sozlanadi.

### Nima uchun shunday

In-tree drayverlar Kubernetes relizlariga bog'langan edi: yangi storage turi yoki xato tuzatish keyingi Kubernetes versiyasini kutardi, va har drayver xatosi kubelet'ni yiqitishi mumkin edi. CSI storage'ni Kubernetes yadrosidan ajratdi: driver o'z sur'atida chiqadi, bitta driver turli orkestratorlarda ishlaydi.

## 9. local-path provisioner

### Bu nima

kind va k3s'dagi standart storage. U har PVC uchun pod tushgan node'ning fayl tizimida katalog yaratadi va PV'ga o'sha node'ga `nodeAffinity` yozadi.

### Mexanizm

1. Scheduler pod uchun node tanlaydi, PVC'ga `selected-node` yoziladi (6-bo'lim).
2. Provisioner `local-path-storage` namespace'ida o'sha node'ga qisqa umrli helper pod yaratadi, u katalogni ochadi (`/var/local-path-provisioner/pvc-<UID>_<namespace>_<pvc>`).
3. Provisioner PV yozadi: katalog yo'li (versiyaga qarab `spec.hostPath` yoki `spec.local` ichida) va `nodeAffinity` (`kubernetes.io/hostname In [<node>]`).
4. PVC o'chirilganda (`Delete`) yana helper pod ishga tushib katalogni o'chiradi.

Provisioner sozlamasi ConfigMap'da: `kubectl get configmap -n local-path-storage local-path-config -o yaml`.

| Xususiyat | local-path | Cloud blok disk (CSI) |
|-----------|------------|-----------------------|
| Ma'lumot qayerda | bitta node diskida | tarmoq diski, node'dan mustaqil |
| Node o'lsa | ma'lumot yo'qoladi yoki yetib bo'lmaydi, pod boshqa node'ga ko'cha olmaydi | disk boshqa node'ga (o'sha zonada) qayta biriktiriladi |
| Hajm chegarasi | majburlanmaydi: so'ralgan `1Gi` shunchaki raqam | haqiqiy disk hajmi |
| Kengaytirish, snapshot | yo'q | driver'ga qarab bor |

### Ishlaydigan misol

"Birga bajaramiz" bo'limida PV yaml'i va node ichidagi katalog to'liq ko'rsatiladi. Bu yerda faqat provisioner'ning o'zi:

```
$ kubectl get pods -n local-path-storage
NAME                                      READY   STATUS    RESTARTS   AGE
local-path-provisioner-<hash>-<suffix>    1/1     Running   0          6d
$ kubectl logs -n local-path-storage deploy/local-path-provisioner --tail=3
<time> ... pvc-<uid> ...
<time> ... pvc-<uid> ... dev-worker:/var/local-path-provisioner/pvc-<uid>_<ns>_<pvc>
```

- Bitta pod butun klaster uchun disk yaratadi.
- Log matni versiyaga qarab farq qiladi, lekin har PV uchun "qaysi node, qaysi katalog" yozuvi bor. PV `Pending` da qolsa birinchi qaraladigan joy shu log.

### Real ishda qachon kerak

Lokal diskning afzalligi tezlik (tarmoq yo'q) va narx. Production'da u faqat ilova o'zi replikatsiya qilgan holda ishlatiladi (masalan, uch nusxali baza klasteri: bitta node yo'qolsa ma'lumot boshqa nusxalarda bor). Bitta nusxali baza uchun lokal disk "node o'lsa ma'lumot o'ldi" degani.

**Laboratoriya xulosasini production'ga ko'chirish tuzog'i.** kind'da "pod'ni o'chirdim, ma'lumot joyida" tajribasi faqat pod o'sha node'ga qaytgani uchun ishlaydi. Storage tanlashda savol har doim: node butunlay yo'qolsa ma'lumot bilan nima bo'ladi?

### Nima uchun shunday

kind va k3s'ga oddiy, tashqi bog'liqliksiz storage kerak edi: Kubernetes'ning `local` PV turi faqat statik ishlaydi, local-path esa unga dinamik provisioning qo'shadi. Narxi: hajm, kengaytirish va bardoshlilik yo'q, bu kompromiss sinov muhiti uchun maqbul.

---

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Volume | pod ichidagi konteynerlarga ulanadigan katalog |
| Ephemeral volume | pod bilan yaratilib pod bilan yo'qoladigan volume |
| `emptyDir` | node'da (yoki RAM'da) pod uchun ochiladigan bo'sh katalog |
| `tmpfs` | RAM ichidagi fayl tizimi |
| `hostPath` | node fayl tizimidagi katalogni pod'ga ulash |
| Evict | kubelet pod'ni majburan to'xtatib node'dan chiqarishi |
| PersistentVolume (PV) | klasterdagi aniq disk bo'lagini ifodalovchi cluster-scoped obyekt |
| PersistentVolumeClaim (PVC) | ilovaning disk so'rovi, namespaced |
| StorageClass | disklar qanday va kim tomonidan yaratilishi retsepti |
| Binding | PVC va PV'ni bittaga-bitta bog'lash |
| `claimRef` / `volumeName` | PV'dagi PVC'ga va PVC'dagi PV'ga ishora |
| Provisioning | PV va uning ortidagi diskni paydo qilish (statik yoki dinamik) |
| Provisioner | dinamik PV yaratadigan controller |
| Access mode | volume'ni qanday ulash mumkinligi: RWO, ROX, RWX, RWOP |
| Blok qurilma | ustiga fayl tizimi yoziladigan xom disk |
| Reclaim policy | PVC o'chganda PV bilan nima qilish: `Delete` yoki `Retain` |
| Finalizer | obyekt o'chishini to'xtatib turuvchi `metadata.finalizers` yozuvi |
| Availability zone | region ichidagi alohida ma'lumot markazi |
| `volumeBindingMode` | PV qachon yaratiladi: `Immediate` yoki `WaitForFirstConsumer` |
| `nodeAffinity` (PV) | volume qaysi node yoki zonadan foydalanilishi mumkinligi |
| Expansion | PVC hajmini ma'lumotni yo'qotmasdan oshirish |
| CSI | storage driver'larini orkestratorga ulash standarti |
| Controller / node plugin | CSI driver'ning markaziy va har node'dagi qismi |
| Attach / mount | diskni node'ga biriktirish / pod katalogiga ulash |
| VolumeAttachment | qaysi volume qaysi node'ga biriktirilganini yozadigan obyekt |
| `fsGroup` | pod volume'laridagi fayllarga beriladigan guruh ID |

## Tuzoqlar

- Ma'lumotni konteyner fayl tizimiga yoki `emptyDir` ga yozib, uni doimiy deb o'ylash.
- Ilova ma'lumoti uchun `hostPath`. Uch muammo: ma'lumot bitta node'ga bog'lanadi (pod boshqa node'ga tushsa bo'sh katalog ko'radi); node fayl tizimiga kirish xavfsizlik teshigi (`/`, `/var/run`, container runtime socket'ini ulagan pod node'ni egallaydi); kubelet katalogni root sifatida yaratadi. Xavfsizlik siyosatlari odatda uni taqiqlaydi (13-dars).
- kind'da `hostPath` yo'lini host mashina (Zorin yoki Mac) ichida qidirish: u node konteyneri ichida.
- `Delete` reclaim policy bilan muhim ma'lumot turgan namespace'ni o'chirish.
- RWO'ni "bitta pod" deb tushunish va ikki pod'ning bir faylga yozishidan himoyalangan deb o'ylash.
- RWO diskli Deployment'ni `RollingUpdate` bilan yangilash yoki bir nechta replikaga scale qilish: yangi pod boshqa node'ga tushsa `Multi-Attach` xatosi bilan osiladi, eski pod esa yangisi tayyor bo'lmaguncha o'chmaydi.
- `WaitForFirstConsumer` dagi `Pending` PVC'ni nosozlik deb o'ylash, yoki aksincha, `Immediate` bilan zonalar bo'yicha `Pending` pod olish.
- `storageClassName` ni yozmaslik va `storageClassName: ""` ni bir narsa deb o'ylash.
- `Released` PV'ga yangi PVC avtomatik bog'lanadi deb kutish.
- Disk to'lishini kuzatmaslik: PVC to'lsa baza to'xtaydi. Kengaytirish imkoniyati (`allowVolumeExpansion`) oldindan tekshirilishi kerak.
- Konteyner root bo'lmagan foydalanuvchi bilan ishlaydi, volume esa root'ga tegishli: `permission denied`. `securityContext.fsGroup` bilan hal qilinadi (Docker 3-darsdagi UID muammosining Kubernetes versiyasi).
- PV va PVC'ni zaxira deb hisoblash. Doimiy disk o'chirib yuborish, `DROP TABLE` va buzilishdan himoya qilmaydi.
- Lokal storage'dagi tajribani tarmoq diskli production'ga to'g'ridan-to'g'ri ko'chirish.
- Dars oxirida `Retain` PV'larni o'chirmay ketish: kind'da joy, cloud'da pul.

## Manbalar

- https://kubernetes.io/docs/concepts/storage/volumes/ – volume turlari
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/ – PV va PVC (majburiy, to'liq)
- https://kubernetes.io/docs/concepts/storage/storage-classes/ – StorageClass
- https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/ – dinamik provisioning
- https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/ – vaqtinchalik volume'lar
- https://kubernetes.io/docs/tasks/administer-cluster/change-pv-reclaim-policy/ – reclaim policy'ni o'zgartirish
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/ – amaliy qo'llanma
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ – `fsGroup` va `securityContext`
- https://kubernetes-csi.github.io/docs/ – CSI hujjatlari, sidecar'lar tavsifi
- https://github.com/container-storage-interface/spec – CSI spetsifikatsiyasi
- https://github.com/kubernetes-sigs/aws-ebs-csi-driver – AWS EBS CSI driver (16-vazifa)
- https://github.com/rancher/local-path-provisioner – local-path provisioner
- https://hub.docker.com/_/postgres – PostgreSQL rasmiy image hujjati (`PGDATA`, 18-vazifa)

---

## Birga bajaramiz

Vazifalardan boshqa misol: PVC'dagi ma'lumotni kattaroq yangi PVC'ga ko'chirish. 7-bo'limda ko'rdik, local-path hajmni kengaytirmaydi; production'da ham kichraytirish yoki boshqa StorageClass'ga o'tish xuddi shunday ko'chirish bilan qilinadi. Yo'l davomida dinamik provisioning event'larini, PV'ning node affinity'si pod'ni qanday "tortishini" va 5-darsdagi Job'ni storage bilan birga ko'ramiz. Hammasi alohida `storage-demo` namespace'ida, ikkala mashinada bir xil. Node nomi va UID'lar sizda boshqa bo'ladi.

1. Namespace va eski PVC:

```
$ kubectl create namespace storage-demo
namespace/storage-demo created
$ kubectl config set-context --current --namespace=storage-demo
Context "kind-dev" modified.
```

```yaml
# notes-v1.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: notes-v1
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests: {storage: 200Mi}
```

```
$ kubectl apply -f notes-v1.yaml
persistentvolumeclaim/notes-v1 created
$ kubectl get pvc
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
notes-v1   Pending                                      standard       <unset>                 4s
```

`STORAGECLASS standard`: maydon yozilmagan, standart class qo'yildi. `Pending` kutilgan holat (6-bo'lim).

2. Ma'lumot yozuvchi pod. U PVC'ni ulaydi va bir nechta fayl yozadi:

```yaml
# writer.yaml
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  restartPolicy: Never
  volumes:
    - name: notes
      persistentVolumeClaim: {claimName: notes-v1}
  containers:
    - name: main
      image: busybox:1.36
      command: ["sh", "-c", "for i in 1 2 3; do echo \"note $i $(date -u)\" > /notes/n$i.txt; done; ls -l /notes"]
      volumeMounts:
        - {name: notes, mountPath: /notes}
```

```
$ kubectl apply -f writer.yaml
pod/writer created
$ kubectl get pvc,pod -o wide
NAME                             STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/notes-v1   Bound    pvc-<uid-1>     200Mi      RWO            standard       <unset>                 40s   Filesystem

NAME         READY   STATUS      RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
pod/writer   0/1     Completed   0          12s   10.244.1.7    dev-worker   <none>           <none>
```

- PVC endi `Bound`, PV nomi `pvc-` va PVC UID'idan tuzilgan.
- `VOLUMEMODE Filesystem`: volume fayl tizimi sifatida ulangan (muqobili `Block`, xom qurilma).
- Pod `dev-worker` ga tushdi; demak disk ham o'sha yerda yaratildi.

3. PVC event'larida provisioning tarixi:

```
$ kubectl describe pvc notes-v1 | sed -n '/Events/,$p'
Events:
  Type    Reason                 Age   From                                                       Message
  ----    ------                 ----  ----                                                       -------
  Normal  WaitForFirstConsumer   45s   persistentvolume-controller                                waiting for first consumer to be created before binding
  Normal  ExternalProvisioning   14s   persistentvolume-controller                                Waiting for a volume to be created either by the external provisioner 'rancher.io/local-path' or manually by the system administrator. ...
  Normal  Provisioning           14s   rancher.io/local-path_local-path-provisioner-<hash>_<id>   External provisioner is provisioning volume for claim "storage-demo/notes-v1"
  Normal  ProvisioningSucceeded  12s   rancher.io/local-path_local-path-provisioner-<hash>_<id>   Successfully provisioned volume pvc-<uid-1>
```

Qatorma-qator: binder pod'ni kutdi; pod paydo bo'lgach binder ishni tashqi provisioner'ga topshirdi; provisioner (`From` ustunida uning nomi) ishni boshladi; 2 soniyada tugatdi. Bu 3 va 6-bo'limlardagi ketma-ketlikning tirik ko'rinishi.

4. PV qayerga "qadalgan":

```
$ kubectl get pv pvc-<uid-1> -o yaml | sed -n '/^spec:/,/^status:/p'
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 200Mi
  claimRef:
    ...
    name: notes-v1
    namespace: storage-demo
  hostPath:
    path: /var/local-path-provisioner/pvc-<uid-1>_storage-demo_notes-v1
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - dev-worker
  persistentVolumeReclaimPolicy: Delete
  storageClassName: standard
  volumeMode: Filesystem
status:
```

- `claimRef` binding'ning PV tomondagi yozuvi.
- `hostPath.path` node ichidagi haqiqiy katalog (sizdagi versiyada `local.path` bo'lishi mumkin).
- `nodeAffinity` "bu volume'ni faqat `dev-worker` ishlata oladi". Bundan keyin `notes-v1` ni ulagan har qanday pod faqat shu node'ga tushadi.
- `Delete` class'dan ko'chirilgan.

Node ichida (ikkala mashinada bir xil, `docker exec` Docker daemon orqali ishlaydi):

```
$ docker exec dev-worker ls /var/local-path-provisioner/
pvc-<uid-1>_storage-demo_notes-v1
$ docker exec dev-worker sh -c 'ls /var/local-path-provisioner/pvc-*_storage-demo_notes-v1'
n1.txt
n2.txt
n3.txt
```

5. Yangi, kattaroq PVC (`notes-v2.yaml`, `notes-v1.yaml` bilan bir xil, faqat `name: notes-v2` va `storage: 1Gi`) va ko'chirish Job'i. Job ikkala PVC'ni ulaydi:

```yaml
# migrate.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-notes
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      volumes:
        - name: old
          persistentVolumeClaim: {claimName: notes-v1, readOnly: true}
        - name: new
          persistentVolumeClaim: {claimName: notes-v2}
      containers:
        - name: copy
          image: busybox:1.36
          command: ["sh", "-c", "set -eu; cp -a /old/. /new/; ls -l /new"]
          volumeMounts:
            - {name: old, mountPath: /old}
            - {name: new, mountPath: /new}
```

- `readOnly: true` eski ma'lumotni ko'chirish paytida tasodifan buzishdan saqlaydi.
- `cp -a /old/. /new/`: `-a` ruxsat va vaqt belgilarini saqlaydi, `/old/.` katalog ichidagilarni (yashirin fayllar bilan) oladi.
- `set -eu` 5-darsdagi "halol exit code" qoidasi: nusxa xato bo'lsa Job ham xato.

```
$ kubectl apply -f notes-v2.yaml -f migrate.yaml
persistentvolumeclaim/notes-v2 created
job.batch/migrate-notes created
$ kubectl wait --for=condition=complete job/migrate-notes --timeout=60s
job.batch/migrate-notes condition met
$ kubectl get pods -l job-name=migrate-notes -o wide
NAME                  READY   STATUS      RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
migrate-notes-<abc>   0/1     Completed   0          20s   10.244.1.9   dev-worker   <none>           <none>
```

Job pod'i ham `dev-worker` da. Tasodif emas: `notes-v1` ning PV affinity'si scheduler'ni shu node'ga majburladi, `notes-v2` esa `WaitForFirstConsumer` tufayli aynan shu tanlovdan keyin o'sha node'da yaratildi. Agar `notes-v2` ning class'i `Immediate` bo'lib, disk boshqa node'da yaratilganida, ikki shart to'qnashib pod `Pending` da qolardi.

6. Natijani tekshirish va eskisini o'chirish:

```
$ kubectl logs job/migrate-notes
total 12
-rw-r--r--    1 root     root            34 Oct  8 09:40 n1.txt
-rw-r--r--    1 root     root            34 Oct  8 09:40 n2.txt
-rw-r--r--    1 root     root            34 Oct  8 09:40 n3.txt
$ kubectl delete pod writer
pod "writer" deleted
$ kubectl delete job migrate-notes
job.batch "migrate-notes" deleted
$ kubectl delete pvc notes-v1
persistentvolumeclaim "notes-v1" deleted
$ kubectl get pv
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-<uid-2>   1Gi        RWO            Delete           Bound    storage-demo/notes-v2   standard       <unset>                          2m
```

- Vaqt belgilari (`Oct  8 09:40`) asl fayllarniki: `cp -a` ishladi.
- PVC o'chirishdan oldin uni ishlatgan pod va Job o'chirildi; aks holda PVC `pvc-protection` tufayli `Terminating` da turardi (5-bo'lim).
- `pvc-<uid-1>` ro'yxatda yo'q: `Delete` siyosati PV'ni ham, node'dagi katalogni ham o'chirdi.

7. Tozalash:

```
$ kubectl delete namespace storage-demo
namespace "storage-demo" deleted
$ kubectl get pv
No resources found
$ kubectl config set-context --current --namespace=storage
Context "kind-dev" modified.
```

Qaysi qadam qaysi bo'limga tayandi:

| Qadam | Bo'lim |
|-------|--------|
| 1 | 3-bo'lim: standart StorageClass |
| 2–3 | 3 va 6-bo'limlar: dinamik provisioning, `WaitForFirstConsumer` |
| 4 | 6 va 9-bo'limlar: `nodeAffinity`, local-path katalogi |
| 5 | 4 va 7-bo'limlar: RWO, kengaytirish o'rniga ko'chirish |
| 6 | 5-bo'lim: `Delete`, PVC protection |

Bu ko'chirishda ilova to'xtatilgan edi (`writer` tugagan). Production'da ishlab turgan baza fayllarini `cp` bilan ko'chirish izchil nusxa bermaydi: avval ilova to'xtatiladi yoki bazaning o'z vositasi (`pg_dump`, 5-dars) ishlatiladi.

---

## Vazifalar

Barchasini `kubernetes/07-storage/` papkasida bajaring (`make new m=kubernetes n=07 name=storage`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml` nomi bilan saqlanadi. Hammasi `storage` namespace'ida, host'dagi `kubectl` va `docker exec` orqali; ikkala mashinada bir xil. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozib qo'ying. `kubectl get pvc,pv -w` ni alohida terminalda ochib qo'ying.

### A. Vaqtinchalik storage

1. **Container filesystem.** nginx pod'i yarating va `kubectl exec` bilan `/usr/share/nginx/html/index.html` ni o'zgartiring. Konteynerni restart qildiring (pod'ni o'chirmasdan: masalan, liveness probe'ni atayin yiqitib yoki konteynerning asosiy jarayoniga `nginx -s stop` yuborib). `RESTARTS` ortganini va fayl holatini ko'rsating. Xulosa yozing.

2. **emptyDir.** Xuddi shu tajribani `emptyDir` ulangan katalog bilan takrorlang: konteyner restart'idan keyin fayl qoldimi? Pod'ni o'chirib qayta yaratgandan keyin-chi? `emptyDir` node'da qayerda joylashganini toping (`docker exec <node> ...` bilan kubelet katalogi ichidan pod UID bo'yicha).

3. **Memory-backed emptyDir.** `medium: Memory` va `sizeLimit: 64Mi` li `emptyDir` ga konteyner memory limiti `128Mi` bo'lgan pod'da `dd` bilan avval 32 MB, keyin 100 MB fayl yozing. Har holatda nima bo'ldi? `mount` chiqishida bu katalog qanday ko'rinadi? Diskdagi `emptyDir` bilan `sizeLimit` oshganda nima bo'lishini ham sinang va pod event'larini yozing.

4. **hostPath.** Bir replikali Deployment'ga `hostPath` (`/tmp/hostpath-demo`, `type: DirectoryOrCreate`) ulang va fayl yozing. Pod qaysi node'da? Shu node'ni `kubectl cordon` qilib pod'ni o'chiring: yangi pod qayerga tushdi va fayl bormi? `docker exec` bilan ikkala node'dagi katalogni ko'rsating. `hostPath: /` ulangan pod node'da nima qila olishini yozing (bajarmang, faqat tushuntiring). `uncordon` qiling.

### B. PV va PVC

5. **Static provisioning.** Qo'lda PV yarating: `hostPath`, `1Gi`, RWO, `storageClassName: manual`, `Retain`. `kubectl get pv` da fazasini ko'rsating. Mos PVC yarating va ikkalasi `Bound` bo'lishini kuzating. `kubectl get pv -o yaml` dagi `claimRef` ni toping. PVC'ni pod'ga ulab fayl yozing.

6. **Binding rules.** `manual` class'li uchta PVC yozib, har biri nima uchun `Pending` qolishini `describe pvc` event'lari bilan ko'rsating: (a) PV'dan katta hajm so'raydi; (b) boshqa access mode so'raydi; (c) `storageClassName` boshqa. Keyin 5Gi PV yaratib unga 1Gi PVC bog'lang: PVC `status.capacity` nima ko'rsatadi va qolgan 4Gi kimga tegishli?

7. **Dynamic provisioning.** `kubectl get storageclass -o yaml` dan standart class'ning provisioner'i, reclaim policy va binding mode'ini yozing. `storageClassName` siz PVC yarating: qaysi fazada va nima uchun (`describe pvc`)? Uni ishlatadigan pod yarating va PVC, PV paydo bo'lishini kuzating. PV nomi qanday tuzilgan? Shu paytda `local-path-storage` namespace'ida qanday vaqtinchalik pod paydo bo'lganini `kubectl get pods -A -w` bilan ushlang.

8. **Data survives pod deletion.** 7-vazifadagi PVC bilan bir replikali Deployment yarating, volume'ga vaqt belgisi bilan fayl yozing. Pod'ni 3 marta o'chiring: fayl har safar joyidami? Pod har safar qaysi node'ga tushdi? PV'ning `spec.nodeAffinity` ni va ma'lumotning node ichidagi haqiqiy yo'lini (`kubectl get pv -o yaml` dan topib, `docker exec` bilan) ko'rsating.

9. **Volume pins the pod.** 8-vazifadagi pod turgan node'ni `cordon` qilib pod'ni o'chiring. Yangi pod qaysi holatda? `describe pod` dagi scheduler xabarini to'liq yozing va har qismini izohlang. Agar bu AWS EBS diski bo'lganida natija qanday farq qilardi (bir zonadagi boshqa node, boshqa zonadagi node)? `uncordon` qiling.

### C. Siyosatlar

10. **Reclaim policy Delete.** Dinamik PVC'ga ma'lumot yozing, pod'ni va PVC'ni o'chiring. PV bilan nima bo'ldi? Node ichidagi katalog qoldimi? Shu jarayonda `local-path-storage` da nima ishga tushdi?

11. **Reclaim policy Retain.** Yangi dinamik PVC yarating, ma'lumot yozing, PV'ni `kubectl patch` bilan `Retain` ga o'tkazing. PVC'ni o'chiring: PV qaysi fazada, ma'lumot joyidami? Xuddi shu nomli yangi PVC yaratsangiz u eski PV'ga bog'lanadimi? Ma'lumotni qayta ishlatish uchun PV'da nimani o'zgartirish kerakligini toping, bajaring va yangi pod eski faylni ko'rishini ko'rsating.

12. **PVC protection.** Pod ishlatayotgan PVC'ni o'chiring (`kubectl delete pvc --wait=false`). PVC holati qanday? `metadata.finalizers` va `deletionTimestamp` ni ko'rsating. Pod ishlashda davom etyaptimi? Pod'ni o'chirgach nima bo'ldi? Bu mexanizm nimadan himoya qiladi va nimadan himoya qilmaydi?

13. **RWO semantics.** Bitta RWO PVC'ni ikki pod'ga ulang. Ikkalasi ham ishga tushdimi, qaysi node'larda? Ikkalasidan bir faylga yozib ko'ring. Keyin ikkinchi pod'ni `nodeName` yoki `nodeSelector` bilan boshqa node'ga majburlang: nima bo'ldi va sababi bu yerda access mode'mi yoki PV'ning node affinity'simi? Xuddi shu ssenariy EBS diskida qanday xato berardi?

14. **Expansion attempt.** Dinamik PVC'ning hajmini `kubectl patch` bilan oshirib ko'ring va API javobini to'liq yozing. Xabarga ko'ra kengaytirish uchun qaysi shartlar bajarilishi kerak? Hajmni kichraytirishga urinib ko'ring. local-path volume'da `1Gi` so'rab 2 GB fayl yozsangiz nima bo'ladi (sinab ko'ring, keyin faylni o'chiring) va bu nimani anglatadi?

### D. StorageClass va CSI

15. **Custom StorageClass.** Standart class asosida `retain-local` nomli yangi StorageClass yozing: o'sha provisioner, `reclaimPolicy: Retain`, `volumeBindingMode: Immediate`. Undan PVC yarating. `Immediate` bilan PVC pod'siz bog'landimi? Natijani (yoki xatoni) `describe pvc` event'lari bilan izohlang: lokal storage uchun `Immediate` nima uchun muammoli? Klasterda ikkita class'ni standart deb belgilasangiz nima bo'ladi?

16. **CSI architecture.** `kubectl get csidrivers,csinodes,volumeattachments` natijasini ko'rsating va kind'da nima uchun shunday ekanini izohlang (local-path CSI driver'mi?). Keyin AWS EBS CSI driver hujjatidan foydalanib yozing: controller va node qismlari qanday workload sifatida o'rnatiladi, qaysi sidecar nima qiladi, controller AWS API'ga qanday huquq bilan murojaat qiladi. 8-bo'limdagi 5 qadamni EBS misolida qayta yozing: har qadamda qaysi komponent qaysi AWS amalini bajaradi.

17. **Stuck volume debugging.** Mavjud bo'lmagan PVC'ga murojaat qiluvchi pod va mavjud bo'lmagan StorageClass'li PVC yarating. Har birida pod va PVC holati, event matni qanday? 3-darsdagi debug jadvalingizga storage qatorlarini qo'shing: `Pending` (PVC yo'q), `Pending` (PVC bog'lanmagan), `ContainerCreating` (attach yoki mount xatosi), har biri uchun qaysi buyruq sababni ko'rsatadi.

### E. Yakuniy

18. **PostgreSQL with persistent data.** `task_18.yaml`: PostgreSQL Deployment'i (1 replika), dinamik PVC, parol Secret'dan (manifestini commit qilmang), ClusterIP Service, readiness probe (`pg_isready`). Deployment strategiyasini tanlang va asoslang: RWO disk bilan `RollingUpdate` nima uchun muammo? `PGDATA` ni volume ildiziga emas, ichidagi kichik katalogga yo'naltirish nima uchun tavsiya etilishini image hujjatidan toping. Sinovlar: (a) jadval yaratib qator yozing, pod'ni o'chiring, ma'lumot joyida ekanini ko'rsating; (b) image'ni minor versiyaga yangilang, ma'lumot saqlanganini ko'rsating; (c) PV'ni `Retain` ga o'tkazib, namespace'ni o'chiring va ma'lumotni yangi namespace'da tiklang. README'da yozing: bu sxema qaysi nosozliklardan himoya qiladi (pod o'limi, node o'limi, disk buzilishi, tasodifiy `DROP TABLE`, namespace o'chirilishi) va qaysilaridan yo'q, hamda har biri uchun nima kerak.

Yo'nalishlar (yechim emas, qayerga qarash kerakligi):

- 1–4: 1-bo'lim. 2-vazifada pod UID'ini `kubectl get pod <nom> -o jsonpath='{.metadata.uid}'` bilan oling. 3-vazifada `kubectl describe pod` va `kubectl get events` ni birga o'qing. 4-vazifada `hostPath` ning qaysi "host" ekanini Laboratoriya jadvalidan eslang.
- 5–6: 2-bo'lim. `describe pvc` event'lari va binder tanlash qoidalari.
- 7–9: 3, 6 va 9-bo'limlar. Helper pod bir necha soniya yashaydi, `-w` ni oldindan oching. 9-vazifada node'lar orasidagi uch xil sabab (affinity, cordon, control-plane taint) bitta xabarda keladi.
- 10–12: 5-bo'lim. 11-vazifada `Released` PV'ning qaysi maydoni binding'ga to'sqinlik qilishini `-o yaml` da qidiring; 18-vazifa (c) qismi ham shunga tayanadi.
- 13: 4 va 6-bo'limlar. Sababni ajratish uchun ikki cheklovni alohida-alohida o'ylang.
- 14: 7 va 9-bo'limlar. API javobini so'zma-so'z ko'chiring, kalit so'zlar shu yerda.
- 15: 3, 6 va 9-bo'limlar. Standart class annotation'ini olib tashlashni unutmang.
- 16: 8-bo'lim va Manbalardagi EBS driver repo'si (o'rnatish va IAM bo'limlari).
- 17: 3-darsdagi debug jadvali, 8-bo'lim "Real ishda qachon kerak".
- 18: 4-dars (probe, strategiya), 5-dars (Secret'ni fayldan yaratish), 5-bo'lim (`Retain`), "Birga bajaramiz" 5-qadamidagi node affinity kuzatuvi. `postgres:17` image hujjatidagi `PGDATA` bo'limini o'qing.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 18 vazifa yozilgan, manifestlar papkada.
2. `make check` toza o'tadi (`yamllint`).
3. Papkada parol yoki Secret manifesti yo'q, README'da parol qiymati yo'q.
4. `storage` namespace'i o'chirilgan; `kubectl get pv` bo'sh (qo'lda yaratilgan va `Retain` qilingan PV'lar o'chirilgan); node'lar `uncordon` qilingan; node'lardagi `/tmp/hostpath-demo` tozalangan; 15-vazifadagi `retain-local` StorageClass o'chirilgan va `standard` yagona standart class.
5. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- `emptyDir` qachon yo'qoladi va qachon saqlanadi?
- PV, PVC va StorageClass nima uchun uchta alohida obyekt?
- Statik va dinamik provisioning farqi nima?
- `ReadWriteOnce` aniq nimani cheklaydi? Blok disk nima uchun RWX bo'la olmaydi?
- PVC o'chirilganda `Delete` va `Retain` siyosatlarida nima bo'ladi? `Released` PV nima uchun avtomatik qayta bog'lanmaydi?
- `WaitForFirstConsumer` qaysi muammoni yechadi?
- Dinamik PVC'dan konteynerdagi mount'gacha qaysi komponentlar qanday tartibda ishlaydi?
- local-path storage production'dagi tarmoq diskidan nimasi bilan farq qiladi?
- PVC ishlatilayotgan paytda o'chirilsa nima bo'ladi?
- Doimiy disk nima uchun zaxira o'rnini bosmaydi?
