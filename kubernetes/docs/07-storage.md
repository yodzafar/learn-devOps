# 7-dars: Storage, Volume, PV, PVC, StorageClass, CSI

Maqsad: Kubernetes'da ma'lumot qayerda yashashini va pod o'limidan qanday omon qolishini tushunish. Konteyner fayl tizimi vaqtinchalik; Docker modulida buni volume bilan hal qilgansiz. Kubernetes'da masala murakkabroq, chunki pod istalgan node'ga tushishi mumkin: disk pod ortidan "yurishi" kerak. Bu darsda vaqtinchalik volume turlari, PersistentVolume va PersistentVolumeClaim modeli, statik va dinamik provisioning, access mode, reclaim policy, binding mode, kengaytirish va bularning ortida turgan CSI arxitekturasi ko'riladi. 5-darsdagi zaxira CronJob'ida PVC'ni "ishlaydigan narsa" sifatida ishlatdingiz, endi uning ichini ochamiz. Bu dars 12-dars (StatefulSet, operator, volume snapshot) uchun bevosita asos.

Taxminiy vaqt: 3 kun (siz uchun). Diqqat: PV va PVC ning hayot sikli va ularni kim yaratishi, reclaim policy ma'lumotni qachon o'chirishi, `WaitForFirstConsumer` nima uchun kerakligi, `ReadWriteOnce` aslida nimani cheklashi, va lokal storage'ning production'dagi storage'dan farqi.

## Laboratoriya

kind `dev` klasteri (1 control-plane + 2 worker). kind'da standart StorageClass tayyor keladi: u `local-path` provisioner orqali node konteynerining ichidagi katalogdan joy ajratadi. Bu haqiqiy tarmoq diski emas, lekin PV, PVC va StorageClass mexanikasi to'liq ishlaydi.

```bash
kubectl create namespace storage
kubectl config set-context --current --namespace=storage
kubectl get storageclass
```

Node ichidagi fayllarni `docker exec dev-worker ls ...` bilan ko'rasiz. Tozalash: `kubectl delete namespace storage`, keyin `kubectl get pv` bilan qolgan PersistentVolume'larni tekshiring (PV namespace'ga tegishli emas, namespace bilan birga o'chmaydi) va qo'lda yaratganlaringizni o'chiring. Haqiqiy cloud disk (EBS) bu darsda yaratilmaydi.

---

## 1. Vaqtinchalik volume'lar

Konteynerning yozish qatlami konteyner bilan birga o'ladi: konteyner restart bo'lsa (hatto o'sha pod ichida) fayllar yo'qoladi. Volume pod darajasida e'lon qilinadi (`spec.volumes`) va konteynerlarga ulanadi (`volumeMounts`).

| Tur | Umri | Ishlatilishi |
|-----|------|--------------|
| `emptyDir` | pod bilan birga. Konteyner restart'idan omon qoladi, pod o'chirilsa yo'qoladi | konteynerlar orasida fayl almashish, kesh, vaqtinchalik fayllar |
| `configMap`, `secret` | manba obyekt bilan sinxron | konfiguratsiya va maxfiy fayllar (4-dars) |
| `downwardAPI` | pod bilan | pod metadata'sini (label, namespace, resurs limitlari) fayl sifatida berish |
| `projected` | pod bilan | bir nechta manbani bitta katalogga yig'ish (service account token shunday ulanadi) |
| `hostPath` | node bilan | node fayl tizimidagi katalog. Faqat tizim agentlari uchun |

`emptyDir` standart holatda node diskida joylashadi. `medium: Memory` bilan `tmpfs` (RAM) da bo'ladi va konteynerning memory limitiga hisoblanadi. Diskdagi `emptyDir` da `sizeLimit` oshsa kubelet pod'ni evict qiladi.

```yaml
      volumes:
      - name: cache
        emptyDir: {sizeLimit: 500Mi}
```

**Tuzoq: `hostPath`.** Uch muammo: ma'lumot bitta node'ga bog'lanadi (pod boshqa node'ga tushsa bo'sh katalog ko'radi); node fayl tizimiga kirish xavfsizlik teshigi (`/`, `/var/run`, container runtime socket'ini ulagan pod node'ni egallaydi); kubelet katalogni root sifatida yaratadi. Ilova ma'lumoti uchun `hostPath` ishlatilmaydi, xavfsizlik siyosatlari odatda uni taqiqlaydi (13-dars).

## 2. PersistentVolume va PersistentVolumeClaim

Doimiy storage ikki obyektga ajratilgan, chunki ikki xil odam ikki xil savolga javob beradi:

| Obyekt | Kim yozadi | Savol | Scope |
|--------|------------|-------|-------|
| PersistentVolume (PV) | administrator yoki provisioner | disk qayerda, qanday turda, qancha | cluster-scoped |
| PersistentVolumeClaim (PVC) | ilova jamoasi | menga qancha joy va qanday kirish kerak | namespaced |
| StorageClass | administrator | disklar qanday "ishlab chiqariladi" | cluster-scoped |

Pod PVC'ga murojaat qiladi, PVC PV'ga bog'lanadi (bind). Ilova manifesti diskning cloud'dagi ID'sini bilmaydi, shu sabab bir xil manifest turli klasterlarda ishlaydi.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests: {storage: 1Gi}
  # storageClassName omitted: the default class is used
```

```yaml
      volumes:
      - name: data
        persistentVolumeClaim: {claimName: data}
```

Bog'lanish bittaga-bitta: bitta PV faqat bitta PVC'ga tegishli. PVC so'raganidan katta PV'ga bog'lanishi mumkin (10Gi PV'ga 1Gi PVC), qolgan joy boshqa PVC'ga berilmaydi.

PV fazalari: `Available` (bo'sh), `Bound` (PVC'ga bog'langan), `Released` (PVC o'chirilgan, lekin PV hali tozalanmagan), `Failed`. PVC fazalari: `Pending`, `Bound`, `Lost`.

## 3. Statik va dinamik provisioning

**Statik**: administrator PV'larni oldindan qo'lda yaratadi. PVC `storageClassName`, hajm, access mode (va ixtiyoriy selector) bo'yicha mos PV qidiradi. Mos PV bo'lmasa PVC `Pending` qoladi.

**Dinamik**: PVC yaratilganda StorageClass'da ko'rsatilgan provisioner PV'ni (va ortidagi haqiqiy diskni) avtomatik yaratadi. Zamonaviy klasterlarda deyarli hamma narsa shunday ishlaydi.

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

- Standart StorageClass `storageclass.kubernetes.io/is-default-class: "true"` annotation'i bilan belgilanadi. PVC'da `storageClassName` yozilmasa shu ishlatiladi.
- `storageClassName: ""` (bo'sh satr) "hech qanday class, faqat class'siz statik PV" degani. Yozilmagan va bo'sh satr boshqa-boshqa narsa.
- StorageClass'ning ko'p maydonlari yaratilgandan keyin o'zgartirilmaydi. Mavjud PV'lar class o'zgarishidan ta'sirlanmaydi.

## 4. Access mode

| Rejim | Qisqa | Ma'nosi |
|-------|-------|---------|
| `ReadWriteOnce` | RWO | bitta node tomonidan o'qish-yozish uchun ulanadi |
| `ReadOnlyMany` | ROX | ko'p node faqat o'qish uchun |
| `ReadWriteMany` | RWX | ko'p node o'qish-yozish uchun |
| `ReadWriteOncePod` | RWOP | butun klasterda faqat bitta pod (faqat CSI volume'lar uchun) |

**Tuzoq: RWO bu "bitta pod" emas, "bitta node".** Bir node'dagi bir nechta pod RWO volume'ni bemalol birga ishlatadi. Access mode disk qanday ulanishi mumkinligini aytadi, yozishdan himoya qilmaydi va fayl darajasida lock bermaydi.

Qaysi rejim mumkinligi storage turiga bog'liq: blok disklar (AWS EBS, GCE PD) faqat RWO, chunki blok qurilmani ikki mashinaga birga ulash fayl tizimini buzadi. RWX uchun tarmoq fayl tizimi kerak (NFS, AWS EFS, CephFS). Bundan amaliy xulosa: blok diskli Deployment'ni bir nechta node'ga yoyib bo'lmaydi; "har replikaga o'z diski" kerak bo'lsa StatefulSet (12-dars), "umumiy fayllar" kerak bo'lsa RWX yoki yaxshisi object storage.

## 5. Reclaim policy

PVC o'chirilganda PV va ortidagi ma'lumot bilan nima bo'lishini `persistentVolumeReclaimPolicy` hal qiladi:

| Qiymat | PVC o'chirilganda | Qachon |
|--------|-------------------|--------|
| `Delete` | PV va haqiqiy disk o'chiriladi | dinamik provisioning standarti |
| `Retain` | PV `Released` holatida qoladi, ma'lumot saqlanadi, qayta ishlatish uchun qo'lda aralashuv kerak | muhim ma'lumot |

Uchinchi qiymat `Recycle` deprecated.

`Released` PV yangi PVC'ga avtomatik bog'lanmaydi: unda eski PVC'ga ishora (`spec.claimRef`) qolgan, va ichida oldingi egasining ma'lumoti bor. Administrator ma'lumotni ko'rib chiqadi va `claimRef` ni tozalaydi yoki PV'ni qayta yaratadi.

**Tuzoq: `kubectl delete namespace`.** Namespace o'chirilsa ichidagi PVC'lar o'chadi, `Delete` siyosatida esa disklar ham. Bitta buyruq bilan production bazasi yo'qoladi. Muhim ma'lumot uchun `Retain`, RBAC cheklovi va zaxira (12-dars: VolumeSnapshot) uchalasi birga kerak.

Himoya mexanizmi: ishlatilayotgan PVC o'chirilsa, u `kubernetes.io/pvc-protection` finalizer'i tufayli `Terminating` holatida qoladi va pod'lar undan foydalanishni tugatgandagina haqiqatda o'chadi.

## 6. volumeBindingMode

| Qiymat | PV qachon yaratiladi va bog'lanadi |
|--------|------------------------------------|
| `Immediate` | PVC yaratilgan zahoti |
| `WaitForFirstConsumer` | PVC'ni ishlatadigan birinchi pod schedule qilinganda |

Nima uchun kutish kerak: disk topologiyaga bog'langan. Cloud blok diski bitta availability zone'da yashaydi, lokal disk bitta node'da. `Immediate` da disk tasodifiy zonada yaratiladi, keyin scheduler pod'ni faqat o'sha zonaga joylashtira oladi; u yerda CPU yoki xotira yetmasa yoki pod'ning boshqa cheklovlari (affinity, taint) to'g'ri kelmasa pod `Pending` qoladi. `WaitForFirstConsumer` da avval scheduler pod uchun node tanlaydi (barcha cheklovlarni hisobga olib), keyin disk o'sha joyda yaratiladi.

Oqibati: `WaitForFirstConsumer` bilan PVC pod yaratilmaguncha `Pending` turadi. Bu nosozlik emas.

PV'ning `spec.nodeAffinity` maydoni disk qaysi node yoki zonadan foydalanishi mumkinligini ko'rsatadi. Scheduler buni hisobga oladi: bog'langan PVC'li pod faqat disk yetib boradigan joyga tushadi.

## 7. Hajmni kengaytirish

StorageClass'da `allowVolumeExpansion: true` bo'lsa va driver qo'llasa, PVC'ning `spec.resources.requests.storage` qiymatini oshirish kifoya: driver diskni, keyin kubelet fayl tizimini kengaytiradi (ko'p driver'larda pod ishlab turgan holda).

- Faqat kattalashtirish mumkin. Kichraytirish yo'q: yangi kichik PVC yaratib ma'lumotni ko'chirish kerak.
- StatefulSet'ning `volumeClaimTemplates` i o'zgarmas: mavjud PVC'lar alohida tahrirlanadi (12-dars).
- Jarayon PVC `status.conditions` va event'larida ko'rinadi.

## 8. CSI arxitekturasi

Container Storage Interface (CSI) bu storage tizimlarini Kubernetes'ga ulash standarti. Avval storage drayverlari Kubernetes kodining ichida (in-tree) edi; endi ular alohida loyihalar, klasterga oddiy workload sifatida o'rnatiladi. Eski in-tree turlar (masalan `awsElasticBlockStore`) CSI drayverlariga ko'chirilgan.

CSI driver ikki qismdan iborat:

| Qism | Qanday ishlaydi | Vazifasi |
|------|-----------------|----------|
| Controller plugin | Deployment yoki StatefulSet, odatda 1–2 replika | storage API bilan gaplashadi: disk yaratish, o'chirish, node'ga biriktirish (attach), snapshot, kengaytirish |
| Node plugin | DaemonSet, har node'da | diskni node'da formatlash va pod katalogiga mount qilish |

Driver konteyneri yonida standart yordamchi sidecar'lar ishlaydi: `external-provisioner` (PVC'ni kuzatib `CreateVolume` chaqiradi), `external-attacher` (VolumeAttachment obyektlarini kuzatadi), `external-resizer`, `external-snapshotter`, node tomonda `node-driver-registrar` (driver'ni kubelet'ga tanitadi). Ular driver bilan Unix socket ustidan gRPC orqali gaplashadi.

Dinamik PVC'ning to'liq yo'li:

1. PVC yaratiladi, pod schedule qilinadi (`WaitForFirstConsumer`).
2. `external-provisioner` driver'dan disk yaratishni so'raydi va PV obyektini yozadi; PVC `Bound`.
3. Attach: `external-attacher` diskni tanlangan node'ga biriktiradi (VolumeAttachment obyekti).
4. Mount: o'sha node'dagi kubelet node plugin'ga murojaat qiladi, u diskni formatlab (kerak bo'lsa) pod katalogiga ulaydi.
5. Konteyner ishga tushadi.

Pod `ContainerCreating` da osilib qolsa va event'larda `FailedAttachVolume` yoki `FailedMount` bo'lsa, muammo 3 yoki 4-qadamda. Tegishli API obyektlari: `CSIDriver`, `CSINode`, `VolumeAttachment`.

## 9. local-path provisioner

kind va k3s'dagi standart storage. U har PVC uchun pod tushgan node'ning fayl tizimida katalog yaratadi va PV'ga o'sha node'ga `nodeAffinity` yozadi.

| Xususiyat | local-path | Cloud blok disk (CSI) |
|-----------|------------|-----------------------|
| Ma'lumot qayerda | bitta node diskida | tarmoq diski, node'dan mustaqil |
| Node o'lsa | ma'lumot yo'qoladi yoki yetib bo'lmaydi, pod boshqa node'ga ko'cha olmaydi | disk boshqa node'ga (o'sha zonada) qayta biriktiriladi |
| Hajm chegarasi | majburlanmaydi: so'ralgan `1Gi` shunchaki raqam | haqiqiy disk hajmi |
| Kengaytirish, snapshot | yo'q | driver'ga qarab bor |

Lokal diskning afzalligi tezlik (tarmoq yo'q) va narx. Production'da u faqat ilova o'zi replikatsiya qilgan holda ishlatiladi (masalan, uch nusxali baza klasteri: bitta node yo'qolsa ma'lumot boshqa nusxalarda bor).

**Tuzoq: laboratoriya xulosasini production'ga ko'chirish.** kind'da "pod'ni o'chirdim, ma'lumot joyida" tajribasi faqat pod o'sha node'ga qaytgani uchun ishlaydi. Storage tanlashda savol har doim: node butunlay yo'qolsa ma'lumot bilan nima bo'ladi?

## Tuzoqlar

- Ma'lumotni konteyner fayl tizimiga yoki `emptyDir` ga yozib, uni doimiy deb o'ylash.
- Ilova ma'lumoti uchun `hostPath`.
- `Delete` reclaim policy bilan muhim ma'lumot va namespace'ni o'chirish.
- RWO'ni "bitta pod" deb tushunish va ikki pod'ning bir faylga yozishidan himoyalangan deb o'ylash.
- RWO diskli Deployment'ni `RollingUpdate` bilan yangilash yoki bir nechta replikaga scale qilish: yangi pod boshqa node'ga tushsa `Multi-Attach` xatosi bilan osiladi.
- `WaitForFirstConsumer` dagi `Pending` PVC'ni nosozlik deb o'ylash, yoki aksincha, `Immediate` bilan zonalar bo'yicha `Pending` pod olish.
- Disk to'lishini kuzatmaslik: PVC to'lsa baza to'xtaydi. Kengaytirish imkoniyati (`allowVolumeExpansion`) oldindan tekshirilishi kerak.
- Konteyner root bo'lmagan foydalanuvchi bilan ishlaydi, volume esa root'ga tegishli: `permission denied`. `securityContext.fsGroup` bilan hal qilinadi.
- PV va PVC'ni zaxira deb hisoblash. Doimiy disk o'chirib yuborish va buzilishdan himoya qilmaydi.
- Lokal storage'dagi tajribani tarmoq diskli production'ga to'g'ridan-to'g'ri ko'chirish.

## Manbalar

- https://kubernetes.io/docs/concepts/storage/volumes/ – volume turlari
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/ – PV va PVC (majburiy, to'liq)
- https://kubernetes.io/docs/concepts/storage/storage-classes/ – StorageClass
- https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/ – dinamik provisioning
- https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/ – vaqtinchalik volume'lar
- https://kubernetes-csi.github.io/docs/ – CSI hujjatlari, sidecar'lar tavsifi
- https://github.com/rancher/local-path-provisioner – local-path provisioner
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/ – amaliy qo'llanma

---

## Vazifalar

Barchasini `kubernetes/07-storage/` papkasida bajaring (`make new m=kubernetes n=07 name=storage`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml` nomi bilan saqlanadi. Hammasi `storage` namespace'ida.

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

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 18 vazifa yozilgan, manifestlar papkada.
2. `make check` toza o'tadi (`yamllint`).
3. Papkada parol yoki Secret manifesti yo'q.
4. `storage` namespace'i o'chirilgan; `kubectl get pv` bo'sh (qo'lda yaratilgan va `Retain` qilingan PV'lar o'chirilgan); node'lar `uncordon` qilingan; node'lardagi `/tmp/hostpath-demo` tozalangan.
5. Menga xabar bering, tekshiraman.

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
