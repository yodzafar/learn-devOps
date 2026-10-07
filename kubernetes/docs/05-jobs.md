# 5-dars: Job va CronJob

Maqsad: tugaydigan ishlarni (migratsiya, hisobot, zaxira, bir martalik skript) Kubernetes'da to'g'ri ishga tushirish. 3–4 darslarda ko'rgan Deployment "doim ishlab tursin" degan talabni bajaradi: pod tugasa, uni qayta ko'taradi. Job boshqa talabni bajaradi: "muvaffaqiyatli tugaguncha ishlasin, keyin to'xtasin". CronJob esa "jadval bo'yicha shunday Job yaratilsin" degan talabni. Bu darsda Job'ning qayta urinish semantikasi, parallel va indekslangan ishlar, CronJob'ning jadval va parallellik siyosatlari, hamda eng muhimi idempotent ish dizayni ko'riladi. Linux modulidagi cron bilimi shu yerda klaster darajasiga ko'tariladi. Yakuniy vazifa, ma'lumotlar bazasi zaxirasi CronJob'i, 7-dars (storage) va 12-dars (stateful workload'lar) bilan bog'lanadi.

Taxminiy vaqt: 3 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh vazifalari, ikkinchi kun 4-bo'lim, "Birga bajaramiz" va B guruhi, uchinchi kun 5–6 bo'limlar va C guruhi (zaxira va tiklash eng ko'p vaqt oladi). Sintaksis sodda, diqqatni semantikaga qarating: `restartPolicy` ning ikki qiymati qanday farq qiladi, `backoffLimit` nimani sanaydi, CronJob qachon ishni o'tkazib yuboradi yoki ikki marta ishga tushiradi, va nima uchun ish idempotent bo'lishi shart.

Qanday o'qish kerak: har bo'limdagi manifestni o'qing, keyin o'z klasteringizda shunga o'xshash (aynan o'zi emas) narsani ishga tushirib, chiqishni darsdagi izoh bilan solishtiring. Pod nomlaridagi tasodifiy suffiks, UID, vaqt va `AGE` qiymatlari sizda boshqa bo'ladi, darsda bunday joylar `<...>` bilan belgilangan yoki misol sifatida berilgan. Job va CronJob'da vaqt muhim: `kubectl get pods -w` (`-w` bu "watch", o'zgarishlarni jonli ko'rsatadi) ni alohida terminalda ochib qo'ying. Har bo'lim oxiridagi "Nima uchun shunday" qismi dizayn sababini aytadi.

## Laboratoriya

Hamma narsa host'dagi Docker ustidagi kind `dev` klasterida (1 control-plane + 2 worker, 3-darsda `kind-multi.yaml` bilan yaratilgan). Multipass VM bu darsda kerak emas: Job va CronJob haqiqiy node xulqiga bog'liq emas, kind node'lari yetarli. Alohida namespace:

```bash
kubectl config current-context        # must print: kind-dev
kubectl create namespace jobs
kubectl config set-context --current --namespace=jobs
```

Image'lar (ikkalasi ham multi-arch, `amd64` va `arm64` uchun bir xil tag):

| Image | Nima uchun |
|-------|------------|
| `busybox:1.36` | deyarli hamma Job va CronJob misollari: `sh`, `sleep`, `date`, `wget` bor |
| `postgres:17` | 16–18 vazifalar: baza serveri ham, `pg_dump`/`psql` klienti ham shu image'da |

15–18 vazifalarda PersistentVolumeClaim (PVC) ishlatiladi. PVC bu pod'ning "menga shuncha hajmli doimiy disk kerak" degan so'rovi; klaster uni haqiqiy disk bo'lagiga bog'laydi. Storage 7-darsda chuqur o'tiladi, hozircha kind'dagi standart `standard` StorageClass (StorageClass bu "disk qayerdan va qanday olinadi" degan retsept) bilan oddiy PVC yetarli. Shuni bilib qo'ying: bu StorageClass birinchi pod yaratilgandagina diskni ajratadi, shuning uchun hech kim ishlatmagan PVC `Pending` holatda turadi, bu xato emas.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Klaster | Docker Engine ustida kind, node'lar `amd64` | Docker Desktop ustida kind, node'lar `arm64` |
| Node'lar qayerda | host'dagi oddiy konteynerlar (`docker ps` da `dev-control-plane`, `dev-worker`, `dev-worker2`) | Docker Desktop'ning yashirin Linux VM'i ichidagi konteynerlar |
| PVC ma'lumoti fizik qayerda | node konteyneri ichida (`/var/local-path-provisioner`) | o'sha joyda, lekin VM ichidagi konteynerda: Mac fayl tizimida ko'rinmaydi |
| Resurs | PostgreSQL bilan birga 4 GB bo'sh RAM yetarli | Docker Desktop'ga kamida 6 GB RAM ajrating (Settings → Resources) |
| Vaqt zonasi | kind node'lari host soatini ishlatadi, zonasi alohida | xuddi shunday, Docker Desktop VM'i soati Mac'ga sinxron |

Ikkala mashinada `kubectl` buyruqlari va manifestlar bir xil. PVC ichini ko'rish uchun host fayl tizimiga emas, pod ichiga qarang (`kubectl exec` yoki vaqtinchalik pod): bu ikkala mashinada ishlaydi.

Ikkinchi mashinada tiklash: klaster holati mashinalar orasida ko'chmaydi, manifest va skriptlar git orqali keladi. Uyda `kind get clusters` da `dev` bo'lmasa, 3-darsdagidek `kind create cluster --name dev --config kind-multi.yaml`, keyin namespace va `kubectl apply -f`. Git orqali kelmaydigan narsalar: Secret'lar (16-vazifadagi parol), PVC ichidagi ma'lumot (test qatorlari, zaxira fayllari) va Job tarixi. Secret'ni har mashinada qo'lda qayta yarating (repo'dan tashqaridagi fayldan yoki tasodifiy generatsiya qilib), test ma'lumotlarini esa skript bilan qayta yozing. Zaxira CronJob'ini ikkala mashinada bir vaqtda ishlatish muammo emas (klasterlar alohida), lekin ketishdan oldin `suspend: true` qilish odat bo'lsin.

Xavfsizlik va tartib:

- Parol hech qachon manifestga, README'ga yoki `kubectl create secret --from-literal` orqali shell tarixiga yozilmaydi. Secret manifesti commit qilinmaydi (4-dars, 19-vazifa).
- Har daqiqada ishlaydigan CronJob'lar sinov tugashi bilan o'chiriladi yoki `suspend: true` qilinadi: unutilgan CronJob kun bo'yi Job va pod yaratib turadi.
- Tozalash: `kubectl delete namespace jobs` (PVC'lar ham, ichidagi ma'lumot ham o'chadi). Klasterni o'chirish shart emas, keyingi darslar uchun `dev` qoladi.

---

## 1. Job nima

### Bu nima

Job bu bir yoki bir nechta pod yaratib, belgilangan miqdordagi pod muvaffaqiyatli tugaguncha ularni kuzatadigan obyekt. "Muvaffaqiyatli" degani konteyner exit code 0 bilan chiqdi (exit code bu jarayon tugaganda qaytaradigan son: 0 muvaffaqiyat, boshqasi xato; Node'dagi `process.exit(1)` aynan shu). Pod xato bilan tugasa yoki node o'lsa, Job yangisini yaratadi. Muvaffaqiyat soni yetgach Job `Complete` bo'ladi va boshqa pod yaratmaydi.

Frontend tajribasidan haqiqiy o'xshatish: CI'dagi `npm run migrate` qadami. U bir marta ishlaydi, 0 qaytarsa pipeline davom etadi, aks holda qadam yiqiladi. Kubernetes'da bu qadam Job bo'ladi, faqat klasterning o'zi qayta urinishni boshqaradi.

### Mexanizm

1-darsdagi reconciliation loop'ni eslang: controller kerakli holat (`spec`) va haqiqiy holat (`status`) farqini kuzatib, farqni yopadi. Job controller (kube-controller-manager ichidagi bo'lim) uchun kerakli holat "N ta pod muvaffaqiyatli tugagan bo'lsin":

1. Siz Job yaratasiz, API server uni etcd'ga yozadi.
2. Job controller pod'larni sanaydi: muvaffaqiyatli tugagan 0, ishlayotgan 0, kerak 1. Bitta pod yaratadi.
3. Scheduler pod'ni node'ga joylaydi, kubelet konteynerni ishga tushiradi (1-dars).
4. Konteyner chiqadi. Kubelet pod fazasini `Succeeded` yoki `Failed` qiladi (4-dars, pod fazalari).
5. Controller yana sanaydi: `Succeeded` yetarli bo'lsa Job'ga `Complete` sharti qo'shiladi; `Failed` bo'lsa va limit tugamagan bo'lsa yangi pod yaratiladi.

Har yaratilgan pod'ning `metadata.ownerReferences` maydonida Job ko'rsatilgan. `ownerReferences` bu "bu obyektning egasi kim" degan havola (4-darsda ReplicaSet va pod orasida ko'rgansiz): ega o'chirilsa, garbage collector (egasi yo'qolgan obyektlarni tozalaydigan controller) bola obyektlarni ham o'chiradi.

### Ishlaydigan misol

Vazifalardagidan boshqa misol, 3 dan 1 gacha sanaydigan Job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: countdown
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: main
          image: busybox:1.36
          command: ["sh", "-c", "for i in 3 2 1; do echo $i; sleep 2; done; echo liftoff"]
```

Qatorma-qator:

- `apiVersion: batch/v1` Job va CronJob `batch` API guruhida (Deployment esa `apps/v1` da).
- `backoffLimit: 2` ikki marta muvaffaqiyatsiz urinishdan keyin Job taslim bo'ladi (2-bo'lim).
- `template` oddiy pod shabloni, Deployment'dagi bilan bir xil tuzilish.
- `restartPolicy: Never` Job'da majburiy tanlov: `Never` yoki `OnFailure`.

```
$ kubectl apply -f countdown.yaml
job.batch/countdown created
$ kubectl get jobs
NAME        STATUS    COMPLETIONS   DURATION   AGE
countdown   Running   0/1           3s         3s
$ kubectl get jobs
NAME        STATUS     COMPLETIONS   DURATION   AGE
countdown   Complete   1/1           9s         15s
```

- `STATUS` Job'ning umumiy holati: `Running`, `Complete`, `Failed`, `Suspended` (eski `kubectl` versiyalarida bu ustun yo'q).
- `COMPLETIONS 1/1` "muvaffaqiyatli tugaganlar / kerak bo'lganlar".
- `DURATION` Job boshlanishidan tugashigacha (yoki hozirgacha) o'tgan vaqt. 6 soniyalik `sleep` ga image tortish va pod yaratish qo'shilgan.

```
$ kubectl get pods
NAME              READY   STATUS      RESTARTS   AGE
countdown-<abc12> 0/1     Completed   0          20s
$ kubectl logs job/countdown
3
2
1
liftoff
```

- Pod nomi Job nomi va tasodifiy suffiksdan iborat. `READY 0/1` tugagan pod uchun normal: konteyner ishlamayapti.
- `STATUS Completed` bu `Succeeded` fazasining `kubectl` dagi ko'rinishi.
- `kubectl logs job/countdown` Job'ning bitta pod'ini o'zi topib log'ini chiqaradi, pod nomini bilish shart emas.

Skriptda tugashni kutish:

```
$ kubectl wait --for=condition=complete job/countdown --timeout=60s
job.batch/countdown condition met
```

`kubectl wait` shart bajarilguncha yoki `--timeout` tugaguncha bloklanadi. Timeout'da 0 dan farqli kod bilan chiqadi, shuning uchun CI qadamida ishlatish qulay. Faqat bitta tuzoq: Job `Failed` bo'lsa `--for=condition=complete` timeout'gacha bekor kutadi. Shuning uchun CI skriptlarida `--for=condition=failed` ham alohida tekshiriladi yoki timeout'dan keyin `kubectl get job` bilan holat o'qiladi.

### Deployment'dan farqlari

- `restartPolicy` faqat `Never` yoki `OnFailure`. `Always` rad etiladi, chunki "tugash" tushunchasi yo'qoladi: tugagan konteyner darhol qayta ishga tushadi.
- `selector` yozilmaydi. Job controller har Job uchun noyob UID asosida selector va pod label'larini o'zi yaratadi. Qaysi label'lar qo'shilganini 1-vazifada `--show-labels` va `-o yaml` bilan o'zingiz topasiz.
- `spec.template` yaratilgandan keyin o'zgartirilmaydi. Boshqa parametr bilan qayta ishga tushirish uchun Job o'chirilib qayta yaratiladi (7-vazifa shu cheklov haqida).
- Tugagan Job va uning pod'lari avtomatik o'chirilmaydi: log va holatni o'qish uchun qoladi (2-bo'lim, TTL).

Job holati `status.conditions` da. Terminal (yakuniy) shartlar ikkita: `Complete` va `Failed`, ikkinchisi `reason` bilan (`BackoffLimitExceeded`, `DeadlineExceeded` va boshqalar). Yangi versiyalarda ulardan oldin `SuccessCriteriaMet` yoki `FailureTarget` oraliq shartlari paydo bo'ladi: controller qaror qabul qildi, lekin pod'lar hali to'liq to'xtamagan. Skriptda terminal shartni kuting.

### Real ishda qachon kerak

Ma'lumotlar bazasi migratsiyasi (deploy'dan oldin), bir martalik ma'lumot tuzatish, kesh isitish, hisobot yaratish, test to'plamini klaster ichida ishga tushirish. Qoida oddiy: jarayon "o'z ishini qilib chiqishi" kerak bo'lsa Job, "doim tinglab turishi" kerak bo'lsa Deployment.

### Nima uchun shunday

Kubernetes'ning hamma workload controller'lari bitta naqshda: kerakli holat yoziladi, controller uni ta'minlaydi. Deployment uchun kerakli holat "N ta ishlayotgan pod", Job uchun "N ta tugagan pod". Muqobili, tugaydigan ishni Deployment ichida `sleep infinity` bilan ushlab turish yoki host cron'idan `kubectl run` chaqirish, qayta urinish, tarix va log'ni qo'lda yozishni talab qiladi. `template` ning o'zgarmasligi ham shu modeldan: ishlab turgan Job'ning yarmi eski, yarmi yangi shablon bilan tugasa, "Job muvaffaqiyatli bo'ldi" degan gap ma'nosini yo'qotadi.

## 2. Qayta urinish semantikasi

### restartPolicy: kim qayta ishga tushiradi

Ikki qiymat ikki xil darajadagi qayta urinishni bildiradi. `Never` da qayta urinishni Job controller qiladi (yangi pod), `OnFailure` da kubelet (o'sha pod ichida yangi konteyner).

| | `Never` | `OnFailure` |
|---|---------|-------------|
| Konteyner xato bilan chiqsa | pod `Failed` bo'ladi, Job yangi pod yaratadi | kubelet konteynerni o'sha pod ichida qayta ishga tushiradi |
| Xatodan keyin nima qoladi | har urinish uchun alohida pod, log'lari bilan | bitta pod, `RESTARTS` ortadi, faqat joriy va oldingi (`--previous`) log |
| Boshqa node'ga o'tadimi | ha, yangi pod boshqa node'ga tushishi mumkin | yo'q, o'sha node'da qoladi |
| Debug | oson | qiyinroq |
| Limit oshganda | xato pod'lar qoladi | ishlayotgan pod o'chiriladi, log yo'qoladi |

Debug muhim bo'lsa `Never` afzal. Ikkala holatda ham ish bir necha marta boshlanishi mumkin, shuning uchun u idempotent bo'lishi kerak (5-bo'lim).

### backoffLimit va kutish vaqti

`backoffLimit` (standart 6) muvaffaqiyatsiz urinishlar sonini cheklaydi. `Never` da har `Failed` pod bitta urinish, `OnFailure` da konteyner restart'lari ham sanaladi. Limit oshsa Job `Failed` bo'ladi, sababi `BackoffLimitExceeded`, va ishlayotgan pod'lar to'xtatiladi.

Urinishlar orasidagi kutish eksponensial o'sadi: 10 s, 20 s, 40 s va hokazo, eng ko'pi 6 daqiqa. Eksponensial backoff bu har xatodan keyin kutishni ikki baravar oshirish: tashqi servis (masalan baza) vaqtincha ishlamayotgan bo'lsa, ish uni so'rovlar bilan ko'mib tashlamaydi.

Misol: har doim `exit 2` qiladigan, `backoffLimit: 2` bilan Job `flaky`:

```
$ kubectl describe job flaky
...
Pods Statuses:    0 Active (0 Ready) / 0 Succeeded / 3 Failed
...
Events:
  Type     Reason                Age   From            Message
  ----     ------                ----  ----            -------
  Normal   SuccessfulCreate      52s   job-controller  Created pod: flaky-<aaa11>
  Normal   SuccessfulCreate      49s   job-controller  Created pod: flaky-<bbb22>
  Normal   SuccessfulCreate      36s   job-controller  Created pod: flaky-<ccc33>
  Warning  BackoffLimitExceeded  4s    job-controller  Job has reached the specified backoff limit
```

- `3 Failed`: birinchi urinish plyus ikki qayta urinish. `backoffLimit: 2` "ikki qayta urinish" emas, "ikki xatogacha chidash, uchinchisida to'xtash" deb o'qiladi; aniq sanashni 3–4 vazifalarda o'zingiz tekshirasiz.
- Pod'lar orasidagi oraliq o'sib boryapti. Oraliq faqat backoff emas: pod yaratish, image tekshirish va konteynerning o'zi ishlash vaqti ham qo'shiladi.
- Oxirgi event: controller taslim bo'ldi. Xuddi shu matn `status.conditions` dagi `message` da ham bor.

`kubectl get pods` da uchala pod `Error` holatida turadi va har birining log'i alohida o'qiladi. Bu `Never` ning debug afzalligi.

### Vaqt chegaralari, TTL va suspend

| Maydon | Standart | Ma'nosi |
|--------|----------|---------|
| `backoffLimit` | 6 | nechta muvaffaqiyatsiz urinishdan keyin Job `Failed` (`BackoffLimitExceeded`) |
| `activeDeadlineSeconds` | yo'q | Job'ning umumiy vaqt chegarasi. Oshsa barcha pod'lar to'xtatiladi, sabab `DeadlineExceeded`. `backoffLimit` dan ustun turadi |
| `ttlSecondsAfterFinished` | yo'q | tugagan Job (va pod'lari) shuncha soniyadan keyin avtomatik o'chiriladi |
| `suspend` | `false` | `true` bo'lsa pod'lar yaratilmaydi; ishlab turgan Job'da `true` qilinsa pod'lar to'xtatiladi |

`activeDeadlineSeconds` ikki darajada bor: `spec.activeDeadlineSeconds` (butun Job uchun, barcha urinishlar yig'indisi) va `spec.template.spec.activeDeadlineSeconds` (har bir pod uchun alohida). Ularni adashtirmang. Deadline oshganda pod'lar oddiy to'xtash ketma-ketligidan o'tadi (4-dars): avval `SIGTERM` (jarayonga "chiroyli tugat" degan signal), `terminationGracePeriodSeconds` dan keyin `SIGKILL` (majburiy o'ldirish). Skriptingiz `SIGTERM` ni ushlasa, vaqtinchalik fayllarni tozalashga ulguradi.

TTL (time to live, "yashash muddati") ni TTL-after-finished controller bajaradi: Job tugagan vaqtdan `ttlSecondsAfterFinished` o'tgach, Job'ni o'chiradi, pod'lar esa `ownerReferences` orqali kaskad bilan o'chadi. `0` qiymati "tugashi bilan darhol o'chir" degani, unda log'ni o'qishga ulgurmaysiz.

`suspend` Job'ni o'chirmasdan "pauza" qiladi: `true` paytida ishlayotgan pod'lar to'xtatiladi, `false` qilinganda yangi pod'lar yaratiladi. To'xtatilgan pod'lar `backoffLimit` hisobiga kirmaydi. `kubectl get jobs` da `STATUS Suspended` ko'rinadi.

### podFailurePolicy

`backoffLimit` hamma xatoni bir xil sanaydi. Lekin xatolar har xil: "konfiguratsiya noto'g'ri, exit code 42" qayta urinishdan foyda yo'q, "node drain qilindi, pod ko'chirildi" esa ishning aybi emas. `podFailurePolicy` exit code yoki pod sharti bo'yicha qoidalar beradi:

```yaml
spec:
  podFailurePolicy:
    rules:
      - action: FailJob
        onExitCodes:
          containerName: main
          operator: In
          values: [42]
      - action: Ignore
        onPodConditions:
          - type: DisruptionTarget
```

Birinchi qoida: `main` konteyneri 42 bilan chiqsa, qolgan urinishlarni kutmay Job'ni darhol `Failed` qil. Ikkinchi qoida: pod tashqi sabab bilan (drain, preemption) to'xtatilgan bo'lsa (`DisruptionTarget` sharti), bu xatoni `backoffLimit` ga sanama. Yana ikki amal bor: `Count` (oddiy sanash) va `FailIndex` (3-bo'limdagi Indexed Job uchun). `podFailurePolicy` faqat `restartPolicy: Never` bilan ishlaydi.

### Real ishda qachon kerak

Migratsiya Job'i: `backoffLimit` kichik (migratsiyani ko'r-ko'rona 6 marta qayta urinish xavfli), `activeDeadlineSeconds` bor (osilib qolgan migratsiya deploy'ni cheksiz to'smasin), `ttlSecondsAfterFinished` bir necha soat yoki kun (debug qilishga ulgurish uchun, lekin to'planib qolmasin). Tashqi API'ga murojaat qiladigan ish: `backoffLimit` kattaroq, chunki tarmoq xatolari vaqtinchalik.

**Tuzoq: TTL'siz Job'lar.** `ttlSecondsAfterFinished` qo'yilmasa tugagan Job va pod obyektlari abadiy qoladi. CI har deploy'da migratsiya Job'i yaratsa, bir necha oyda minglab obyekt to'planib, API server va etcd'ni sekinlashtiradi.

### Nima uchun shunday

Ikki darajali qayta urinish (kubelet va controller) ikki xil xatoni ajratadi: konteyner ichidagi vaqtinchalik xato (tez, o'sha joyda qayta urinish arzon) va pod yoki node darajasidagi xato (boshqa joyda qayta boshlash kerak). Tugagan Job'larning o'zi o'chmasligi ataylab: Kubernetes "kerak bo'lmay qoldi" degan qarorni sizga qoldiradi, chunki xato Job'ning log'i uni o'chirgan controller uchun emas, siz uchun kerak. TTL controller 1.23 da barqaror bo'lgunga qadar har kompaniya o'z tozalash CronJob'ini yozardi.

## 3. Parallel ishlar

### Uch naqsh

| Naqsh | `completions` | `parallelism` | Xulqi |
|-------|---------------|---------------|-------|
| Bitta ish | 1 (standart) | 1 (standart) | bitta pod muvaffaqiyatli tugaguncha |
| Belgilangan son | N | M | N ta muvaffaqiyatli tugash kerak, bir vaqtda ko'pi bilan M ta pod |
| Ish navbati | berilmaydi | M | M ta worker, ular tashqi navbatdan (Redis, RabbitMQ) ish oladi; bittasi muvaffaqiyatli tugasa va qolganlari chiqsa Job tugaydi |

`completions` bu "nechta muvaffaqiyatli tugash kerak", `parallelism` bu "bir vaqtda ko'pi bilan nechta pod ishlasin". Ish navbati (work queue) naqshida Kubernetes ishlarni taqsimlamaydi: har worker navbatdan o'zi oladi va navbat bo'shaganini o'zi aniqlaydi.

### Mexanizm

Controller har sinxronizatsiyada hisoblaydi: "hali kerak bo'lgan muvaffaqiyat" = `completions` minus muvaffaqiyatli tugaganlar; ishlayotgan pod'lar soni `parallelism` dan va hali kerak bo'lgan sondan oshmasligi kerak. Farq bo'lsa pod yaratadi, ortiqcha bo'lsa o'chiradi. `parallelism` ni ishlab turgan Job'da o'zgartirish mumkinmi, 2-vazifada o'zingiz sinaysiz.

Misol: `completions: 4`, `parallelism: 2`, har pod 5 soniya ishlaydi. `kubectl get pods -w` dan qisqartirilgan:

```
NAME             READY   STATUS              RESTARTS   AGE
batch-<p1>       0/1     ContainerCreating   0          0s
batch-<p2>       0/1     ContainerCreating   0          0s
batch-<p1>       1/1     Running             0          2s
batch-<p2>       1/1     Running             0          2s
batch-<p1>       0/1     Completed           0          7s
batch-<p3>       0/1     ContainerCreating   0          0s
batch-<p2>       0/1     Completed           0          7s
batch-<p4>       0/1     ContainerCreating   0          0s
```

- Boshida aynan ikkita pod: `parallelism` chegarasi.
- `p1` tugashi bilan `p3` yaratildi: controller bo'shagan joyni darhol to'ldiradi.
- Jami 4 pod yaratiladi, Job `COMPLETIONS 4/4` bo'ladi. Umumiy vaqt taxminan 2 "to'lqin".

### Indexed Job

Oddiy parallel Job'da pod'lar bir-biridan farq qilmaydi: hammasi bir xil ishni qiladi va qaysi biri nimani qayta ishlashini bilmaydi. `completionMode: Indexed` bilan har pod `0` dan `completions - 1` gacha bo'lgan o'z indeksini oladi. Indeks pod'ga uch yo'l bilan yetadi: `JOB_COMPLETION_INDEX` muhit o'zgaruvchisi, `batch.kubernetes.io/job-completion-index` annotation'i va pod nomi (`<job>-<indeks>-<suffiks>`). Har indeks aynan bir marta muvaffaqiyatli tugashi kerak.

```yaml
spec:
  completions: 3
  parallelism: 3
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo \"resizing images with prefix $JOB_COMPLETION_INDEX\""]
```

```
$ kubectl get pods
NAME              READY   STATUS      RESTARTS   AGE
resize-0-<x1>     0/1     Completed   0          12s
resize-1-<x2>     0/1     Completed   0          12s
resize-2-<x3>     0/1     Completed   0          12s
$ kubectl get job resize -o jsonpath='{.status.completedIndexes}'
0-2
```

- Pod nomidagi raqam indeks. Indeks 1 li pod yiqilsa, uning o'rniga keladigan pod ham `resize-1-...` bo'ladi va xuddi shu `JOB_COMPLETION_INDEX=1` ni oladi.
- `completedIndexes` qisqa yozuv: `0-2` "0, 1, 2", masalan `0,2-4` "0, 2, 3, 4".

Bu shard (ma'lumotni bo'laklarga ajratish, har bo'lakni alohida worker qayta ishlaydi) uchun tashqi navbat tizimisiz yechim: indeks 0 fayllarning birinchi qismini, indeks 1 ikkinchisini oladi.

Indexed Job uchun qo'shimcha maydonlar:

- `backoffLimitPerIndex`: har indeks uchun alohida qayta urinish chegarasi. Bu bo'lmasa `backoffLimit` hamma indekslar uchun umumiy, bitta "yomon" indeks butun Job'ni yiqitadi.
- `maxFailedIndexes`: nechta indeks butunlay yiqilsa butun Job `Failed` bo'lishi. `backoffLimitPerIndex` bilan birga ishlatiladi; yiqilgan indekslar `status.failedIndexes` da ko'rinadi.
- `successPolicy`: "barcha indeks emas, faqat shu indekslar yoki shuncha indeks muvaffaqiyatli bo'lsa yetarli" degan qoida (masalan, faqat "leader" indeksi muhim bo'lgan hisoblash ishlari).

### Real ishda qachon kerak

Katta ma'lumotni bo'laklab qayta ishlash (har oy uchun alohida hisobot, har mijoz uchun eksport), parallel test (test to'plamini N bo'lakka bo'lish, frontend'dagi `jest --shard=1/4` g'oyasining klaster versiyasi), ML va ilmiy hisoblashlar. Ish navbati naqshi esa ishlar soni oldindan noma'lum bo'lganda.

### Nima uchun shunday

`Indexed` rejimi 1.24 da barqaror bo'lgunga qadar shard qilish uchun har kim o'z navbatini (Redis, RabbitMQ) ko'tarardi, faqat "kim qaysi bo'lakni oladi" degan savol uchun. Indeks bu savolni klasterning o'ziga beradi va navbatsiz deterministik taqsimot hosil qiladi. Muqobili hali ham bor: ishlar dinamik bo'lsa (soni noma'lum, uzoq va qisqa aralash), haqiqiy navbat yaxshiroq yuklama taqsimlaydi.

## 4. CronJob

### Bu nima

CronJob jadval bo'yicha Job yaratadi. O'zi pod yaratmaydi: zanjir CronJob → Job → Pod. Linux modulidagi cron bilan solishtirsangiz: cron bitta mashinada jarayon ishga tushiradi, CronJob esa klasterda Job obyektini yaratadi va qolganini (qayerda, qayta urinish, tarix) Job mexanizmi hal qiladi.

Frontend'dan haqiqiy o'xshatish: Node ilovasi ichidagi `node-cron`. Ilovani 3 replika bilan deploy qilsangiz, har replika o'z jadvalini ishlatadi va har tungi ish 3 marta bajariladi. CronJob jadvalni ilovadan chiqarib, klaster darajasida bitta joyga qo'yadi.

### Maydonlar

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cache-warm
spec:
  schedule: "*/15 6-22 * * 1-5"
  timeZone: "Europe/Berlin"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 120
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      activeDeadlineSeconds: 600
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: warm
              image: busybox:1.36
              command: ["sh", "-c", "date; echo warming cache"]
```

`schedule` standart 5 maydonli cron ifodasi: daqiqa, soat, oy kuni, oy, hafta kuni. `"*/15 6-22 * * 1-5"` "dushanbadan jumagacha, soat 6 dan 22:59 gacha, har 15 daqiqada" (Linux modulidagi crontab sintaksisi bilan bir xil; https://crontab.guru/ da tekshiring). `jobTemplate` ichida to'liq Job `spec` i turadi, shuning uchun 2-bo'limdagi hamma maydonlar shu yerda ham ishlaydi.

| Maydon | Standart | Ma'nosi |
|--------|----------|---------|
| `schedule` | majburiy | cron ifodasi, `@hourly`, `@daily` kabi makroslar ham bor |
| `timeZone` | kube-controller-manager vaqt zonasi | IANA nomi (`Asia/Tashkent` kabi standart zona bazasidagi nom). `schedule` ichida `TZ=` yoki `CRON_TZ=` yozish qo'llanmaydi |
| `concurrencyPolicy` | `Allow` | oldingi Job hali tugamagan bo'lsa: `Allow` yangisini parallel boshlaydi, `Forbid` yangisini o'tkazib yuboradi, `Replace` eskisini o'chirib yangisini boshlaydi |
| `startingDeadlineSeconds` | yo'q | rejadagi vaqtdan shuncha soniya kechikkan ish hali boshlanishi mumkin, undan kech bo'lsa o'tkazib yuboriladi |
| `successfulJobsHistoryLimit` | 3 | nechta muvaffaqiyatli Job saqlanadi |
| `failedJobsHistoryLimit` | 1 | nechta muvaffaqiyatsiz Job saqlanadi |
| `suspend` | `false` | `true` bo'lsa yangi Job yaratilmaydi, ishlab turganlariga ta'sir qilmaydi |

### Mexanizm

CronJob controller taxminan har 10 soniyada har CronJob uchun hisoblaydi: oxirgi ishga tushish (`status.lastScheduleTime`) va hozir orasida jadval bo'yicha qaysi vaqtlar o'tgan. Eng oxirgi o'tgan vaqt uchun Job hali yaratilmagan bo'lsa, `startingDeadlineSeconds` va `concurrencyPolicy` ni tekshiradi va Job yaratadi. Job nomi CronJob nomi va raqamli suffiksdan iborat; bu raqam nimani bildirishini 10-vazifada o'zingiz aniqlaysiz.

Shu hisobdan ikki qoida chiqadi:

- CronJob nomi 52 belgidan oshmasligi kerak: controller unga suffiks qo'shadi, Job nomi esa 63 belgi bilan cheklangan.
- `startingDeadlineSeconds` ni 10 dan kichik qo'ymang: controller har 10 soniyada tekshirgani uchun Job hech qachon yaratilmasligi mumkin.

CronJob holati `status` da: `active` (hozir ishlayotgan Job'lar ro'yxati), `lastScheduleTime` (oxirgi marta Job yaratilgan rejaviy vaqt), `lastSuccessfulTime` (oxirgi muvaffaqiyatli tugagan Job vaqti). Oxirgi ikkisi orasidagi farq monitoring uchun eng muhim signal (14-vazifa).

```
$ kubectl get cronjob cache-warm
NAME         SCHEDULE            TIMEZONE        SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cache-warm   */15 6-22 * * 1-5   Europe/Berlin   False     0        4m12s           2d
```

- `TIMEZONE` berilgan zona, berilmasa `<none>`.
- `ACTIVE` hozir ishlayotgan Job'lar soni.
- `LAST SCHEDULE` oxirgi ishga tushishdan beri o'tgan vaqt. Bu "oxirgi muvaffaqiyat" emas: Job yaratildi, lekin yiqilgan bo'lishi mumkin.

CronJob'ni o'zgartirish faqat keyingi yaratiladigan Job'larga ta'sir qiladi, ishlab turgan Job eski shablon bilan tugaydi.

### Qo'lda ishga tushirish

Jadvalni kutmasdan sinash uchun CronJob shablonidan oddiy Job yaratiladi:

```
$ kubectl create job cache-warm-test --from=cronjob/cache-warm
job.batch/cache-warm-test created
```

Bu Job'ning CronJob bilan munosabati (`ownerReferences`, annotation'lar, `concurrencyPolicy` hisobiga kirishi) 13-vazifaning mavzusi.

### Kafolatlar va ularning yo'qligi

CronJob "taxminan bir marta" ishlaydi. Rasmiy hujjat aniq aytadi: ba'zi holatlarda bitta jadval vaqti uchun ikki Job yaratilishi yoki hech biri yaratilmasligi mumkin.

- Controller o'chiq bo'lgan vaqtda (control plane qayta ishga tushdi, kind klasteri noutbuk bilan uxladi) o'tgan jadval vaqtlari "o'tkazib yuborilgan" hisoblanadi. `startingDeadlineSeconds` berilmagan bo'lsa va oxirgi ishga tushishdan beri 100 tadan ko'p vaqt o'tkazib yuborilgan bo'lsa, controller Job yaratmaydi va xato event yozadi. `startingDeadlineSeconds` berilsa, faqat shu oynadagi o'tkazib yuborilganlar sanaladi.
- `suspend: true` paytida o'tgan vaqtlar ham o'tkazib yuborilgan hisoblanadi. `startingDeadlineSeconds` siz `suspend` olib tashlansa, o'tkazib yuborilgan ish darhol boshlanishi mumkin.
- `concurrencyPolicy: Forbid` bilan uzoq ishlayotgan Job keyingi ishga tushishlarni jimgina yutadi.
- Job yaratilgandan keyin ham ikki marta bajarilish mumkin: pod'ning qayta urinishi (2-bo'lim) ishni qaytadan boshlaydi.

**Tuzoq: CronJob jim o'ladi.** Zaxira CronJob'i bir oy oldin ishlamay qolgan bo'lsa, buni hech kim sezmaydi, toki tiklash kerak bo'lmaguncha. `status.lastSuccessfulTime` ni kuzatish va "oxirgi muvaffaqiyatli ish N soatdan eski" alertini qo'yish shart (observability moduli, 3-dars).

Noutbukda o'qiyotganingiz uchun bu siz uchun nazariya emas: kechqurun noutbuk yopilsa, kind klasteri bilan birga CronJob controller ham uxlaydi. Ertalab ochganda nima bo'lishi `startingDeadlineSeconds` ga bog'liq.

### Real ishda qachon kerak

Tungi zaxira, hisobot va eksport, eski ma'lumotni tozalash, sertifikat yoki token muddatini tekshirish, kesh isitish. Har daqiqalik yoki soniyalik ishlar uchun CronJob yomon tanlov: har ishga tushish yangi pod (image tekshirish, schedule, konteyner ko'tarish), bunday ish Deployment ichidagi sikl yoki navbat sifatida yaxshiroq.

### Nima uchun shunday

CronJob controller ataylab "eng kamida bir marta" yoki "aniq bir marta" kafolatini bermaydi: buning uchun taqsimlangan lock va tranzaksiya kerak, bu esa controller'ni murakkab va sekin qiladi. Kubernetes oddiy va bashorat qilinadigan xulqni tanlab, aniqlik javobgarligini ish dizayniga (5-bo'lim) qoldiradi. `timeZone` maydoni 1.27 da barqaror bo'ldi; undan oldin jadval controller-manager zonasida talqin qilinardi va jamoalar UTC'ga qayta hisoblab yozardi. `CRON_TZ=` prefiksi rasmiy qo'llab-quvvatlanmagan holda ishlardi va endi validatsiya bilan taqiqlangan, chunki ikki yo'l bir vaqtda chalkashlik keltirardi.

## 5. Idempotent ish dizayni

### Bu nima

Yuqoridagilardan xulosa: ish bir necha marta boshlanishi, o'rtasida uzilishi, ikki nusxada parallel ishlashi mumkin. Idempotent ish bu necha marta bajarilsa ham natijasi bir xil bo'lgan ish. HTTP'dan tanish g'oya: `PUT` idempotent (bir xil resursni bir xil holatga qo'yadi), `POST` esa odatda emas (har chaqiriqda yangi yozuv).

| Idempotent emas | Idempotent |
|-----------------|------------|
| `INSERT` har ishga tushishda | `INSERT ... ON CONFLICT DO NOTHING`, yoki unikal kalit bilan upsert |
| faylga qo'shib yozish (`>>`) | vaqtinchalik faylga yozib, tugagach atomar `mv` |
| "barcha foydalanuvchilarga xat yubor" | yuborilganlarni belgilab borish, belgilanmaganlarga yuborish |
| `backup.sql` ni ustidan yozish | sana bilan nomlangan fayl, vaqtinchalik nomdan `mv` |
| hisoblagichni 1 ga oshirish | holatni manbadan qayta hisoblash |

Upsert bu "bor bo'lsa yangila, yo'q bo'lsa qo'sh" amali.

### Mexanizm: atomar almashtirish

Bitta fayl tizimi ichida `mv` (`rename` system call) atomar: boshqa jarayon faylni yo eski holatida, yo yangi holatida ko'radi, yarim holat yo'q. Shu sababli "avval vaqtinchalik nomga to'liq yoz, keyin bir harakatda nomini almashtir" naqshi ishlaydi. Umumiy shakl (vazifalardagi ish emas, istalgan fayl uchun):

```sh
tmp="$out.tmp.$$"            # unique temp name next to the target
generate_report > "$tmp"     # may fail or be killed halfway
mv "$tmp" "$out"             # atomic within one filesystem
```

`$$` joriy jarayon ID'si, ikki parallel nusxa bir-birining vaqtinchalik faylini bosmasligi uchun. Vaqtinchalik fayl maqsad bilan bir papkada bo'lishi kerak: boshqa fayl tizimiga `mv` aslida nusxa ko'chirish va o'chirish, u atomar emas. Ish o'ldirilsa, ortda faqat `*.tmp.*` qoladi, uni keyingi ishga tushish tozalaydi.

### Mexanizm: halol exit code

Job faqat exit code'ga qaraydi. Skript xatoni yashirsa, Kubernetes buni bilish yo'li yo'q. Shell'dagi uch flag:

- `set -e`: istalgan buyruq xato bilan tugasa skript to'xtaydi.
- `set -u`: e'lon qilinmagan o'zgaruvchiga murojaat xato (`$BAKCUP_DIR` kabi xato yozilgan nom bo'sh qatorga aylanib ketmaydi).
- `set -o pipefail`: pipe'ning (`a | b`) exit code'i oxirgi buyruqniki emas, xato bilan tugagan birinchisiniki bo'ladi.

Oxirgisini o'z klasteringizda ko'ring (busybox `sh` ham `pipefail` ni qo'llaydi):

```
$ kubectl run pf --rm -it --restart=Never --image=busybox:1.36 -- sh -c 'false | cat; echo "exit=$?"'
exit=0
$ kubectl run pf --rm -it --restart=Never --image=busybox:1.36 -- sh -c 'set -o pipefail; false | cat; echo "exit=$?"'
exit=1
```

- Birinchi qatorda `false` yiqildi, lekin pipe'ning natijasi `cat` niki: 0. Zaxira skriptida `dump | gzip > file` xuddi shunday: dump yiqilsa ham `gzip` bo'sh kirishni muvaffaqiyatli siqadi, Job `Complete`, faylda esa hech narsa yo'q.
- Ikkinchi qatorda `pipefail` bilan pipe xatoni qaytardi. `set -e` qo'shilsa skript shu joyda to'xtab, Job `Failed` bo'lardi.
- (`kubectl run` `pod "pf" deleted` degan qator ham chiqaradi, u bu yerda ko'rsatilmagan.)

### Qo'shimcha qoidalar

- **Yarim natija qoldirmang.** Ish o'rtasida o'ldirilishi mumkin (`SIGTERM`, node o'limi, deadline). Natija yo to'liq, yo yo'q bo'lsin: vaqtinchalik fayl va `mv`, bazada tranzaksiya.
- **Parallel nusxadan himoyalaning**, agar ish bunga chidamasa: `concurrencyPolicy: Forbid` va qo'shimcha ravishda ilova darajasidagi lock (masalan, PostgreSQL'dagi advisory lock, ya'ni ilova o'zi nom berib oladigan va bo'shatadigan qulf), chunki `Forbid` ham mutlaq kafolat emas.
- **Chegaralar qo'ying**: `activeDeadlineSeconds` osilib qolgan ishni o'ldiradi, `backoffLimit` cheksiz urinishni to'xtatadi.
- **Exit code halol bo'lsin**: `set -euo pipefail`, va xatoni `|| true` bilan "yutish" faqat ongli qaror bo'lsin.
- **Natijani tekshiring**: fayl hajmi noldan kattami, qatorlar soni kutilganidekmi. Tekshiruv yiqilsa, 0 dan farqli kod bilan chiqing.

### Real ishda qachon kerak

Har Job va CronJob'da, istisnosiz. Ayniqsa tashqi dunyoga ta'sir qiladigan ishlarda: pul o'tkazmasi, xat yoki push xabar yuborish, tashqi API'ga yozish. Ikki marta ketgan "Sizning buyurtmangiz tasdiqlandi" xati yoqimsiz, ikki marta yechilgan to'lov esa incident.

### Nima uchun shunday

Taqsimlangan tizimlarda "aniq bir marta bajarish" (exactly-once) amalda erishib bo'lmaydigan kafolat: tarmoq uzilsa, jo'natuvchi ish bajarildimi yoki yo'qmi bila olmaydi va qayta urinishga majbur. Shuning uchun sanoat "kamida bir marta yetkazish + idempotent qayta ishlash" ni tanlagan: Kafka iste'molchilari, Stripe'ning `Idempotency-Key` sarlavhasi, SQS va Kubernetes Job'lari bir xil g'oyaga tayanadi. Muqobili (har ishni tranzaksion koordinator orqali o'tkazish) sekin va murakkab.

## 6. Misol: ma'lumotlar bazasi zaxirasi

### Bu nima

Zaxira CronJob'i darsdagi hamma narsani birlashtiradi: jadval, parallellik siyosati, vaqt chegaralari, idempotentlik, halol exit code, Secret va storage. Bu bo'lim tuzilishni beradi, skriptni 16-vazifada o'zingiz yozasiz.

`pg_dump` PostgreSQL bazasini SQL fayl (yoki maxsus arxiv formati) ko'rinishida chiqaradigan klient dasturi. U ishlayotgan bazadan izchil (consistent) nusxa oladi: dump boshlangan paytdagi holat, o'rtadagi yozuvlar aralashmaydi. Tiklash `psql` (SQL format uchun) yoki `pg_restore` (arxiv formati uchun) bilan.

### Tuzilish

- Baza paroli Secret'da, CronJob pod'iga env (`PGPASSWORD`) yoki fayl (`PGPASSFILE`) orqali beriladi (4-dars, 9-bo'lim: fayl afzal).
- CronJob `postgres` image'i bilan `pg_dump` ni ishga tushiradi. Klient versiyasi server versiyasidan eski bo'lmasligi kerak, eng oddiy yo'l: server bilan bir xil image tag.
- Baza manziliga Service nomi orqali ulaniladi (3-darsda Service'ni ko'rgansiz, DNS nomlari 6-darsda chuqur).
- Dump PVC'ga, sana bilan nomlangan faylga yoziladi; avval vaqtinchalik nom, muvaffaqiyatdan keyin `mv` (5-bo'lim).
- Eski zaxiralar o'chiriladi (retention, ya'ni "qancha vaqt saqlanadi" siyosati), masalan `find /backup -name '*.sql.gz' -mtime +7 -delete`.
- `concurrencyPolicy: Forbid`, `activeDeadlineSeconds`, `backoffLimit`, `startingDeadlineSeconds`, history limit'lar. Har birini nima uchun qo'yganingizni 16-vazifada asoslaysiz.
- Skript ConfigMap'dan volume sifatida ulanadi (4-dars, 9-bo'lim), image'ga "yopishtirilmaydi".

PVC haqida bitta ogohlantirish: kind'dagi `standard` StorageClass'ning disklari `ReadWriteOnce`, ya'ni bir vaqtda faqat bitta node'dagi pod'lar ulay oladi. Zaxira CronJob'i va PostgreSQL pod'i turli PVC ishlatadi, shuning uchun bu ularga xalaqit bermaydi. Lekin zaxira PVC'sini bir vaqtda boshqa node'dagi pod ham ulamoqchi bo'lsa (masalan tiklash Job'i), pod `ContainerCreating` da qolishi mumkin. Mexanizmi 7-darsda.

### Real ishda qachon kerak

Bu laboratoriya sxemasi. Production'da zaxira klasterdan tashqariga, object storage'ga (S3 kabi, fayllarni HTTP API orqali saqlaydigan xizmat) yoziladi: klaster yoki disk yo'qolsa, ichidagi zaxira ham yo'qoladi. Ko'pincha baza operatori (12-dars) yoki managed baza (RDS) zaxirani o'zi qiladi va siz faqat siyosatni sozlaysiz. Va tiklab ko'rilmagan zaxira zaxira hisoblanmaydi: tiklash ham Job sifatida avtomatlashtiriladi va muntazam sinaladi (18-vazifa).

### Nima uchun shunday

Zaxira ishi klasterdagi eng "jim" ish: u hech kimga ko'rinmaydi, muvaffaqiyatini hech kim tekshirmaydi, va uning sifati faqat falokat kunida ma'lum bo'ladi. Shuning uchun undagi har himoya maydoni bitta konkret nosozlikka qarshi: `Forbid` ikki dump'ning bir-birini bosishiga, deadline osilib qolgan dump'ga, `pipefail` bo'sh faylga, atomar `mv` yarim faylga, retention diskning to'lishiga, tiklash sinovi esa "zaxira bor, lekin ochilmaydi" degan eng yomon holatga.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Job | belgilangan sondagi pod muvaffaqiyatli tugaguncha ularni yaratib kuzatadigan obyekt |
| CronJob | jadval bo'yicha Job yaratadigan obyekt |
| Exit code | jarayon tugaganda qaytaradigan son, 0 muvaffaqiyat |
| `restartPolicy` | xatoda kim qayta ishga tushiradi: `Never` (controller, yangi pod), `OnFailure` (kubelet, o'sha pod) |
| `backoffLimit` | Job `Failed` bo'lgunga qadar chidaladigan muvaffaqiyatsiz urinishlar soni |
| Eksponensial backoff | har xatodan keyin kutish vaqtini ikki baravar oshirish |
| `activeDeadlineSeconds` | Job (yoki pod) uchun umumiy vaqt chegarasi |
| `ttlSecondsAfterFinished` | tugagan Job avtomatik o'chiriladigan muddat |
| `ownerReferences` | obyektning egasini ko'rsatuvchi havola, kaskadli o'chirish shunga tayanadi |
| Garbage collector | egasi yo'qolgan obyektlarni o'chiradigan controller |
| `podFailurePolicy` | exit code yoki pod sharti bo'yicha xatoni qanday sanashni belgilaydigan qoidalar |
| `completions` / `parallelism` | kerakli muvaffaqiyatlar soni / bir vaqtdagi pod'lar chegarasi |
| Indexed Job | har pod `0..completions-1` oralig'ida o'z indeksini oladigan Job |
| Shard | katta ma'lumotning alohida qayta ishlanadigan bo'lagi |
| Work queue | worker'lar ish oladigan tashqi navbat |
| `concurrencyPolicy` | oldingi Job tugamaganda yangisi bilan nima qilish: `Allow`, `Forbid`, `Replace` |
| `startingDeadlineSeconds` | kechikkan ishga tushish hali ruxsat etiladigan oyna |
| `timeZone` | CronJob jadvali talqin qilinadigan IANA vaqt zonasi |
| `lastScheduleTime` / `lastSuccessfulTime` | oxirgi Job yaratilgan vaqt / oxirgi muvaffaqiyatli Job vaqti |
| Idempotent | necha marta bajarilsa ham natijasi bir xil |
| Atomar `mv` | bitta fayl tizimida faylni bir harakatda almashtirish, yarim holatsiz |
| `pipefail` | pipe'dagi har qanday buyruq xatosini pipe natijasiga chiqaradigan shell sozlamasi |
| PVC | pod'ning doimiy diskka so'rovi (7-dars) |
| `pg_dump` | PostgreSQL bazasining izchil nusxasini chiqaradigan klient |
| Retention | zaxiralar qancha vaqt saqlanishi siyosati |

## Tuzoqlar

- Ish idempotent emas, Job esa uni ikki marta ishga tushirdi: ikkilangan yozuvlar, ikki marta yuborilgan xatlar.
- `ttlSecondsAfterFinished` va history limit'lar yo'q: minglab eski Job va pod obyektlari.
- `activeDeadlineSeconds` yo'q: osilib qolgan Job bir hafta ishlaydi, `Forbid` tufayli keyingilarini to'sadi.
- Job darajasidagi va pod darajasidagi `activeDeadlineSeconds` ni adashtirish.
- Shell skriptda `set -euo pipefail` yo'qligi: pipe ichidagi xato yutiladi, Job "muvaffaqiyatli".
- `timeZone` berilmagan: jadval controller-manager zonasida (kind'da odatda UTC) ishlaydi, "tungi 2" aslida mahalliy vaqt bilan ertalabki 7.
- `restartPolicy: OnFailure` va `backoffLimit` oshishi: pod o'chiriladi, xato log'i yo'qoladi.
- `kubectl wait --for=condition=complete` ni yolg'iz ishlatish: Job `Failed` bo'lsa CI timeout'gacha bekor kutadi.
- `startingDeadlineSeconds` 10 dan kichik: CronJob hech qachon ishga tushmasligi mumkin.
- Noutbuk uxlagandan keyin "o'tkazib yuborilgan" ishlarni unutish: CronJob kechikib bir marta ishlaydi yoki umuman ishlamaydi.
- CronJob'ni kuzatmaslik: ish haftalab ishlamaydi va hech kim bilmaydi. `LAST SCHEDULE` muvaffaqiyat degani emas.
- Vaqtinchalik faylni boshqa fayl tizimida (masalan `/tmp` da, natija esa PVC'da) yaratish: `mv` atomar bo'lmay qoladi.
- Parolni `--from-literal` bilan berish yoki manifestga yozish: shell tarixi va git'da qoladi.
- Zaxirani faqat klaster ichida saqlash va hech qachon tiklab ko'rmaslik.
- Job template'ni o'zgartirib `apply` qilish: `field is immutable` xatosi.
- Har daqiqalik sinov CronJob'ini o'chirmay ketish: kun bo'yi pod yaratilib turadi.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/job/ – Job (majburiy, to'liq)
- https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ – CronJob, cheklovlari bilan
- https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/ – tugagan Job'larni avtomatik tozalash
- https://kubernetes.io/docs/tasks/job/ – Job naqshlari bo'yicha amaliy misollar (Indexed Job, work queue, pod failure policy)
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/job-v1/ – Job API ma'lumotnomasi
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/cron-job-v1/ – CronJob API ma'lumotnomasi
- https://kubernetes.io/docs/concepts/architecture/garbage-collection/ – `ownerReferences` va kaskadli o'chirish
- https://www.postgresql.org/docs/current/app-pgdump.html – pg_dump
- https://www.postgresql.org/docs/current/backup-dump.html – SQL dump va undan tiklash
- https://www.postgresql.org/docs/current/libpq-envars.html – `PGHOST`, `PGPASSWORD`, `PGPASSFILE` kabi muhit o'zgaruvchilari
- https://www.shellcheck.net/ – shell skriptlarni tekshirish
- https://crontab.guru/ – cron ifodalarini tekshirish

---

## Birga bajaramiz

Vazifalardan boshqa misol: klaster ichidagi nginx'ni tekshiradigan "sintetik health check" CronJob'i. U har daqiqada Service'ga HTTP so'rov yuboradi va javob kelmasa xato bilan chiqadi. Yo'l davomida CronJob → Job → Pod zanjirini, muvaffaqiyatsiz ishni o'qishni va CronJob'ni to'xtatishni ko'ramiz. Hammasi `jobs` namespace'ida, ikkala mashinada bir xil. Vaqt va suffikslar sizda boshqa bo'ladi.

1. Tekshiriladigan servis. 3-darsdagidek oddiy nginx Deployment va Service:

```
$ kubectl create deployment web --image=nginx:1.28 --replicas=1
deployment.apps/web created
$ kubectl expose deployment web --port=80
service/web exposed
$ kubectl rollout status deployment/web
deployment "web" successfully rolled out
```

2. CronJob manifesti `probe.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: probe-web
spec:
  schedule: "* * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 30
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: probe
              image: busybox:1.36
              command: ["sh", "-c", "set -eu; wget -q -T 5 -O /dev/null http://web/ && echo \"$(date -u) web OK\""]
```

Tanlovlar: `backoffLimit: 0` chunki health check'ni qayta urinish ma'nosiz, keyingi daqiqada baribir yana ishlaydi. `activeDeadlineSeconds: 30` osilib qolgan tekshiruv keyingisini to'smasligi uchun (`Forbid` bilan birga). `wget -T 5` 5 soniyalik timeout. `http://web/` Service nomi, klaster DNS'i uni hal qiladi (6-dars). `timeZone` ataylab berilmagan: "har daqiqa" jadvali uchun zona ahamiyatsiz.

3. Qo'llash va birinchi ishni kutish:

```
$ kubectl apply -f probe.yaml
cronjob.batch/probe-web created
$ kubectl get cronjob probe-web
NAME        SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
probe-web   * * * * *   <none>     False     0        <none>          20s
```

`LAST SCHEDULE <none>`: hali birorta daqiqa chegarasi o'tmagan. Bir-ikki daqiqadan keyin:

```
$ kubectl get cronjob,jobs,pods
NAME                      SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob.batch/probe-web   * * * * *   <none>     False     0        38s             2m10s

NAME                           STATUS     COMPLETIONS   DURATION   AGE
job.batch/probe-web-<N1>       Complete   1/1           4s         98s
job.batch/probe-web-<N2>       Complete   1/1           3s         38s

NAME                             READY   STATUS      RESTARTS   AGE
pod/probe-web-<N1>-<s1>          0/1     Completed   0          98s
pod/probe-web-<N2>-<s2>          0/1     Completed   0          38s
```

- Har daqiqada bitta Job, har Job'da bitta pod. Zanjir nomlarda ko'rinadi: pod nomi Job nomidan, Job nomi CronJob nomidan boshlanadi.
- `ACTIVE 0`: tekshiruv 3–4 soniyada tugaydi, keyingi ishga tushishgacha hech narsa ishlamaydi.

4. Natijani o'qish:

```
$ kubectl logs job/probe-web-<N2>
Wed Oct  7 09:41:03 UTC 2026 web OK
```

5. Nosozlik. Servisni "o'ldiramiz":

```
$ kubectl scale deployment web --replicas=0
deployment.apps/web scaled
```

Keyingi daqiqada:

```
$ kubectl get jobs
NAME             STATUS     COMPLETIONS   DURATION   AGE
probe-web-<N2>   Complete   1/1           3s         2m40s
probe-web-<N3>   Complete   1/1           3s         100s
probe-web-<N4>   Failed     0/1           8s         40s
$ kubectl logs job/probe-web-<N4>
wget: can't connect to remote host (10.96.<...>): Connection refused
```

- `Failed 0/1`: `backoffLimit: 0` bo'lgani uchun birinchi xatodayoq. Service'da pod (endpoint) qolmagani uchun kube-proxy ulanishni rad etdi va `wget` xato qaytardi (sozlamaga qarab xabar `download timed out` ham bo'lishi mumkin, unda `-T 5` ishlagan).
- `set -eu` tufayli `echo` ishlamadi va exit code `wget` niki bo'ldi. `&&` o'rniga `;` yozilganda nima bo'lishini o'zingiz o'ylab ko'ring: 5-bo'limdagi "halol exit code".
- Muvaffaqiyatli Job'lar soni `successfulJobsHistoryLimit: 2` bilan cheklangan: eng eskisi o'chirilgan.

Sababini CronJob event'larida ham ko'rish mumkin:

```
$ kubectl describe cronjob probe-web | tail -n 5
  Normal   SuccessfulCreate  40s   cronjob-controller  Created job probe-web-<N4>
  Normal   SawCompletedJob   30s   cronjob-controller  Saw completed job: probe-web-<N4>, status: Failed
  Normal   SuccessfulDelete  30s   cronjob-controller  Deleted job probe-web-<N1>
```

`SawCompletedJob` controller Job'ning terminal holatini ko'rganini bildiradi, `SuccessfulDelete` esa history limit bo'yicha tozalash. (Sarlavha qatorlari `tail` bilan kesilgan.) CronJob'ning `status` maydonlari shu paytda qanday o'zgarishini 14-vazifada o'zingiz kuzatasiz.

6. Tiklash va pauza. Servisni qaytaramiz va tekshiruvni to'xtatamiz:

```
$ kubectl scale deployment web --replicas=1
deployment.apps/web scaled
$ kubectl patch cronjob probe-web -p '{"spec":{"suspend":true}}'
cronjob.batch/probe-web patched
$ kubectl get cronjob probe-web
NAME        SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
probe-web   * * * * *   <none>     True      0        50s             6m
```

`SUSPEND True`: yangi Job yaratilmaydi, eski Job'lar va ularning log'i joyida.

7. Tozalash:

```
$ kubectl delete cronjob probe-web
cronjob.batch "probe-web" deleted
$ kubectl delete deployment,service web
deployment.apps "web" deleted
service "web" deleted
$ kubectl get jobs,pods
No resources found in jobs namespace.
```

CronJob o'chirilganda uning Job'lari va pod'lari ham o'chdi: zanjir `ownerReferences` bilan bog'langan (1-bo'lim).

Qaysi qadam nimani ko'rsatdi:

| Qadam | Bo'lim |
|-------|--------|
| 2 | 4-bo'lim: maydonlar; 2-bo'lim: `backoffLimit`, `activeDeadlineSeconds` |
| 3 | 4-bo'lim: mexanizm, CronJob → Job → Pod |
| 4–5 | 1-bo'lim: `kubectl logs job/...`; 2-bo'lim: `Failed` sababi; 5-bo'lim: halol exit code |
| 5 | 4-bo'lim: history limit'lar |
| 6 | 4-bo'lim: `suspend` |
| 7 | 1-bo'lim: `ownerReferences` va kaskadli o'chirish |

Bu CronJob production uchun yetarli monitoring emas: u xatoni faqat log'ga yozadi, hech kimga xabar bermaydi. Haqiqiy tekshiruv Prometheus'ning blackbox exporter'i yoki shunga o'xshash vosita va alert bilan qilinadi (observability moduli).

---

## Vazifalar

Barchasini `kubernetes/05-jobs/` papkasida bajaring (`make new m=kubernetes n=05 name=jobs`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml`, skriptlar `task_N.sh` nomi bilan saqlanadi. Hammasi `jobs` namespace'ida, host'dagi `kubectl` orqali; ikkala mashinada bir xil. README'da qaysi mashinada bajarganingizni (Zorin yoki macOS) bir marta yozib qo'ying. Vaqt o'lchanadigan vazifalarda (2, 4, 10–13) `kubectl get pods -w` yoki `kubectl get jobs -w` ni alohida terminalda ochib qo'ying.

### A. Job

1. **First Job.** 1-bo'limdagi kabi oddiy Job yozing va qo'llang. `kubectl get jobs`, `get pods`, `logs job/NAME` natijasini ko'rsating. Job controller pod'ga qanday label'lar va selector qo'shganini toping. `kubectl wait --for=condition=complete` bilan tugashini kuting. `restartPolicy: Always` yozib ko'ring va xatoni yozing.

2. **Completions and parallelism.** `completions: 6, parallelism: 2` bilan har pod 10 soniya "ishlaydigan" Job yarating. `kubectl get pods -w` bilan bir vaqtda nechta pod ishlashini kuzating, umumiy vaqtni o'lchang. `parallelism: 6` bilan takrorlang. Job ishlab turganda `kubectl patch` bilan `parallelism` ni o'zgartirish mumkinmi?

3. **Restart policies.** Har doim `exit 1` qiladigan Job'ni `backoffLimit: 3` bilan ikki marta yarating: `restartPolicy: Never` va `OnFailure`. Har birida Job `Failed` bo'lgach nechta pod qoldi, ularning holati va log'lari mavjudligini solishtiring. Debug nuqtai nazaridan xulosa yozing.

4. **Backoff timing.** 3-vazifadagi `Never` variantida pod'larning `creationTimestamp` larini chiqarib, urinishlar orasidagi intervallarni hisoblang. Ular 2-bo'limdagi tavsifga mos keladimi? Job `status.conditions` idagi `reason` va `message` ni yozing.

5. **Active deadline.** `sleep 300` qiladigan Job'ga `activeDeadlineSeconds: 20` qo'ying. Nima bo'ldi, pod'ga qanday signal bordi, Job holati va sababi nima? `backoffLimit` hali tugamagan bo'lsa ham Job nima uchun qayta urinmadi?

6. **TTL cleanup.** `ttlSecondsAfterFinished: 30` bilan Job yarating va tugagandan keyin Job hamda pod'lari yo'qolishini kuzating. TTL'siz Job'ni o'chirganda pod'lari bilan nima bo'ladi va nima uchun (`ownerReferences`)?

7. **Immutable template.** Tugagan Job manifestida image yoki `command` ni o'zgartirib `kubectl apply` qiling. Xato matnini yozing. CI/CD'da har deploy'da migratsiya Job'ini ishga tushirish kerak bo'lsa, bu cheklovni chetlab o'tishning ikki usulini taklif qiling, har birining kamchiligi bilan.

8. **Indexed Job.** `completionMode: Indexed`, `completions: 5`, `parallelism: 2` bilan Job yozing: har pod o'z indeksini chop etsin, indeksi 3 bo'lgan pod esa har doim xato bilan chiqsin (`backoffLimit` bilan cheklang). Pod nomlari va `status.completedIndexes`, `status.failed` qiymatlarini ko'rsating. Bitta indeks tufayli butun Job yiqilmasligi uchun qaysi maydon kerak?

9. **Suspend and resume.** `suspend: true` bilan Job yarating: pod yaratildimi? `kubectl patch` bilan `suspend: false` qiling. Keyin ishlab turgan uzoq Job'ni `suspend: true` qiling: pod'larga nima bo'ldi? Bu mexanizm qachon foydali?

### B. CronJob

10. **First CronJob.** Har daqiqada ishlaydigan, sana va hostname chop etadigan CronJob yozing. 5 daqiqa kuzating: `kubectl get cronjob,jobs,pods`. Job nomlaridagi raqam nimani bildiradi? Bir vaqtda nechta eski Job saqlanyapti va buni qaysi maydonlar boshqaradi? `successfulJobsHistoryLimit: 1` qilib tekshiring.

11. **Time zone.** CronJob'ga `timeZone: "Asia/Tashkent"` qo'shing va `kubectl get cronjob` dagi ustunlarni ko'rsating. `schedule: "CRON_TZ=Asia/Tashkent 0 2 * * *"` yozib ko'ring va API javobini yozing. `timeZone` berilmasa jadval qaysi vaqt zonasida talqin qilinadi va buni kind klasteringizda qanday tekshirasiz?

12. **Concurrency policy.** Har daqiqada ishga tushadigan, lekin 150 soniya ishlaydigan CronJob'ni uch siyosat bilan (`Allow`, `Forbid`, `Replace`) sinang, har birini kamida 5 daqiqa kuzatib. Har holatda bir vaqtda nechta Job ishladi, nechta ishga tushish o'tkazib yuborildi yoki to'xtatildi? `kubectl describe cronjob` event'larini yozing. Zaxira ishi uchun qaysi biri mos va nima uchun?

13. **Manual trigger and suspend.** CronJob'dan `kubectl create job --from=cronjob/...` bilan qo'lda Job yarating. U `concurrencyPolicy` hisobiga kiradimi (`ownerReferences` ni solishtiring)? Keyin `suspend: true` qilib 3 daqiqa kuting, `suspend: false` qiling: nima bo'ldi? Xuddi shu tajribani `startingDeadlineSeconds: 30` bilan takrorlang va farqni izohlang.

14. **Missed schedule detection.** `kubectl get cronjob NAME -o yaml` dan `status.lastScheduleTime` va `status.lastSuccessfulTime` ni toping. CronJob'ni har doim xato qaytaradigan qilib o'zgartiring va bu maydonlar qanday o'zgarishini kuzating. Observability modulidagi bilimingiz bilan "zaxira 26 soatdan beri muvaffaqiyatli ishlamadi" alertini qanday qurgan bo'lardingiz (qaysi ma'lumot manbai, qanday shart)? Faqat reja yozing.

### C. Dizayn

15. **Idempotent job.** PVC yarating va ikki skript yozing. `task_15_bad.sh`: har ishga tushishda `/data/report.txt` ga qator qo'shadi. `task_15_good.sh`: sana bilan nomlangan faylni vaqtinchalik nom orqali yozib `mv` qiladi, fayl allaqachon mavjud bo'lsa hech narsa qilmay 0 qaytaradi. Skriptlarni ConfigMap orqali Job'ga bering va har birini uch marta ishga tushiring. PVC tarkibini ko'rsatib, farqni izohlang. Yaxshi variantni yozish o'rtasida o'ldiring (`activeDeadlineSeconds` bilan) va yarim fayl qolmaganini ko'rsating.

16. **Database backup CronJob.** `jobs` namespace'ida PostgreSQL ko'taring (bitta replikali Deployment yoki StatefulSet, PVC bilan, parol Secret'da) va test jadvaliga bir nechta qator yozing. 6-bo'limdagi tuzilish bo'yicha zaxira CronJob'ini yozing: `task_16.yaml` va `backup.sh` (`set -euo pipefail`, sana bilan nomlangan siqilgan dump, vaqtinchalik fayl va `mv`, 7 kundan eski fayllarni o'chirish). Barcha himoya maydonlarini qo'ying va har birini README'da asoslang. Sinov uchun jadvalni har 2 daqiqaga qo'ying, 3 ta zaxira paydo bo'lishini va hajmi noldan katta ekanini ko'rsating. `shellcheck` toza bo'lsin. Parol hech qayerda ochiq yozilmasin.

17. **Break the backup.** 16-vazifadagi CronJob'ni uch usulda buzing va har birida nima ko'rinishini yozing: (a) Secret'dagi parolni noto'g'ri qiling; (b) baza Service nomini xato yozing; (c) skriptdan `set -o pipefail` ni olib tashlab (a) ni takrorlang. (c) holatda Job holati qanday va PVC'da nima paydo bo'ldi? Bu nima uchun eng xavfli variant?

18. **Restore test.** Zaxirani tiklaydigan Job yozing: yangi bo'sh bazaga (alohida Deployment yoki alohida database) eng oxirgi dump'ni tiklab, test jadvalidagi qatorlar sonini chop etsin va kutilgan songa teng bo'lmasa xato bilan chiqsin. Manba bazadagi jadvalni `DROP` qilib, zaxiradan tiklanganini ko'rsating. README'da yozing: bu laboratoriya sxemasida production uchun nima yetishmaydi (kamida 4 band).

Yo'nalishlar (yechim emas, qayerga qarash kerakligi):

- 1–7: 1–2 bo'limlar. Label va `ownerReferences` ni ko'rish uchun `kubectl get pod <nom> -o yaml` ning `metadata` qismi yetarli. Vaqtlar uchun `-o jsonpath` yoki `-o custom-columns`.
- 8: 3-bo'lim, "Indexed Job" va undagi qo'shimcha maydonlar ro'yxati.
- 9: 2-bo'lim, "Vaqt chegaralari, TTL va suspend".
- 10–14: 4-bo'lim va "Birga bajaramiz". Har daqiqalik CronJob'larni har vazifa oxirida o'chiring. 11 uchun kind node'lari Docker konteyneri ekanini eslang (2-dars).
- 15: 5-bo'lim, "Mexanizm: atomar almashtirish". Vaqtinchalik fayl PVC ichida bo'lsin.
- 16–18: 6-bo'lim. Secret'ni repo'dan tashqaridagi fayldan yoki tasodifiy generatsiya qilib yarating (`kubectl create secret generic ... --from-file=...`), qiymat README'ga tushmasin. PostgreSQL tayyor bo'lganini `pg_isready` yoki readiness probe (4-dars) bilan tekshiring. Tiklash Job'i zaxira PVC'sini ulashi kerak: 6-bo'limdagi `ReadWriteOnce` ogohlantirishini eslang.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 18 vazifa yozilgan, manifest va skriptlar papkada.
2. `make check` toza o'tadi (`yamllint`, `shellcheck`).
3. Papkada parol yoki Secret manifesti yo'q, README'da parol qiymati yo'q.
4. Har daqiqalik sinov CronJob'lari o'chirilgan; `jobs` namespace'i o'chirilgan (PVC'lar bilan birga), `kubectl get ns jobs` "NotFound" qaytaradi.
5. Menga "tekshir" deb xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Job'da `restartPolicy: Never` va `OnFailure` qanday farq qiladi va qaysi birini qachon tanlaysiz?
- `backoffLimit` va `activeDeadlineSeconds` nimani cheklaydi, ikkalasi to'qnashsa qaysi biri ustun?
- Indexed Job oddiy parallel Job'dan nimasi bilan farq qiladi?
- CronJob qaysi holatlarda ishni o'tkazib yuboradi va qaysi holatlarda ikki marta ishga tushirishi mumkin?
- `concurrencyPolicy` ning uch qiymati qanday xulq beradi?
- Idempotent ish nima va Kubernetes'da nima uchun bu talab majburiy?
- Shell skriptdagi `set -o pipefail` zaxira ishida nima uchun hal qiluvchi?
- Tugagan Job'lar nima uchun o'zi o'chmaydi va buni qanday boshqarasiz?
- CronJob ishlamay qolganini qanday bilasiz?
