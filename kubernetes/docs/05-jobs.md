# 5-dars: Job va CronJob

Maqsad: tugaydigan ishlarni (migratsiya, hisobot, zaxira, bir martalik skript) Kubernetes'da to'g'ri ishga tushirish. Deployment "doim ishlab tursin" degan talabni bajaradi; Job "muvaffaqiyatli tugaguncha ishlasin", CronJob esa "jadval bo'yicha Job yaratilsin" degan talabni. Bu darsda Job'ning qayta urinish semantikasi, parallel va indekslangan ishlar, CronJob'ning jadval va parallellik siyosatlari, hamda eng muhimi idempotent ish dizayni ko'riladi. Linux modulidagi cron bilimi shu yerda klaster darajasiga ko'tariladi. Yakuniy vazifa, ma'lumotlar bazasi zaxirasi CronJob'i, 7-dars (storage) va 12-dars (stateful workload'lar) bilan bog'lanadi.

Taxminiy vaqt: 2 kun (siz uchun). Sintaksis sodda, diqqatni semantikaga qarating: `restartPolicy` ning ikki qiymati qanday farq qiladi, `backoffLimit` nimani sanaydi, CronJob qachon ishni o'tkazib yuboradi yoki ikki marta ishga tushiradi, va nima uchun ish idempotent bo'lishi shart.

## Laboratoriya

kind `dev` klasteri. Alohida namespace:

```bash
kubectl create namespace jobs
kubectl config set-context --current --namespace=jobs
```

Image'lar: `busybox:1.36`, `postgres:17` (zaxira vazifasi uchun; baza ham klaster ichida, test ma'lumotlari bilan). 15–17 vazifalarda PersistentVolumeClaim ishlatiladi; storage 7-darsda chuqur o'tiladi, hozircha kind'dagi standart StorageClass bilan oddiy PVC yetarli. Tozalash: `kubectl delete namespace jobs`.

---

## 1. Job nima

Job bir yoki bir nechta pod yaratadi va belgilangan miqdordagi pod muvaffaqiyatli (exit code 0) tugaguncha ularni kuzatadi. Pod xato bilan tugasa yoki node o'lsa, Job yangisini yaratadi.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: main
        image: busybox:1.36
        command: ['sh', '-c', 'echo working; sleep 5; echo done']
```

Deployment'dan farqlari:

- `restartPolicy` faqat `Never` yoki `OnFailure` bo'lishi mumkin. `Always` rad etiladi, chunki "tugash" tushunchasi yo'qoladi.
- Selector yozilmaydi, Job controller uni o'zi yaratadi va pod'larga `batch.kubernetes.io/job-name` label'ini qo'yadi.
- `spec.template` yaratilgandan keyin o'zgartirilmaydi. Boshqa parametr bilan qayta ishga tushirish uchun Job o'chirilib qayta yaratiladi.
- Tugagan Job va uning pod'lari o'chirilmaydi (log'ni o'qish uchun), `Completed` holatida qoladi.

Job holati `status.conditions` da: `Complete` yoki `Failed` (sababi bilan). Skriptda kutish: `kubectl wait --for=condition=complete job/hello --timeout=120s`.

## 2. Qayta urinish semantikasi

### restartPolicy

| | `Never` | `OnFailure` |
|---|---------|-------------|
| Konteyner xato bilan chiqsa | pod `Failed` bo'ladi, Job yangi pod yaratadi | kubelet konteynerni o'sha pod ichida qayta ishga tushiradi |
| Xatodan keyin nima qoladi | har urinish uchun alohida pod, log'lari bilan | bitta pod, `RESTARTS` ortadi, faqat oxirgi va oldingi (`--previous`) log |
| Debug | oson | qiyinroq |
| Limit oshganda | xato pod'lar qoladi | pod o'chiriladi, log yo'qoladi |

Debug muhim bo'lsa `Never` afzal. Ikkala holatda ham ish bir necha marta boshlanishi mumkin, shuning uchun u idempotent bo'lishi kerak (5-bo'lim).

### backoffLimit va muddatlar

| Maydon | Standart | Ma'nosi |
|--------|----------|---------|
| `backoffLimit` | 6 | necha marta muvaffaqiyatsiz urinishdan keyin Job `Failed` deb belgilanadi (`BackoffLimitExceeded`) |
| `activeDeadlineSeconds` | yo'q | Job'ning umumiy vaqt chegarasi. Oshsa barcha pod'lar to'xtatiladi, sabab `DeadlineExceeded`. `backoffLimit` dan ustun turadi |
| `ttlSecondsAfterFinished` | yo'q | tugagan Job (va pod'lari) shuncha soniyadan keyin avtomatik o'chiriladi |
| `suspend` | `false` | `true` bo'lsa pod'lar yaratilmaydi; ishlab turgan Job'da `true` qilinsa pod'lar to'xtatiladi |

Urinishlar orasidagi kutish eksponensial o'sadi: 10 s, 20 s, 40 s va hokazo, 6 daqiqagacha.

`activeDeadlineSeconds` ikki darajada bor: `spec.activeDeadlineSeconds` (butun Job uchun) va `spec.template.spec.activeDeadlineSeconds` (bitta pod uchun). Ularni adashtirmang.

**Tuzoq: TTL'siz Job'lar.** `ttlSecondsAfterFinished` qo'yilmasa tugagan Job va pod obyektlari abadiy qoladi. CI har deploy'da migratsiya Job'i yaratsa, bir necha oyda minglab obyekt to'planib, API va etcd'ni sekinlashtiradi.

Nozikroq boshqaruv uchun `podFailurePolicy` bor: exit code yoki pod holatiga qarab "bu xatoda qayta urinma, darhol Job'ni yiqit" yoki "bu xatoni sanama" (masalan, node drain tufayli o'lgan pod) deyish mumkin.

## 3. Parallel ishlar

| Naqsh | `completions` | `parallelism` | Xulqi |
|-------|---------------|---------------|-------|
| Bitta ish | 1 (standart) | 1 (standart) | bitta pod muvaffaqiyatli tugaguncha |
| Belgilangan son | N | M | N ta muvaffaqiyatli tugash kerak, bir vaqtda ko'pi bilan M ta pod |
| Ish navbati | berilmaydi | M | M ta worker, ular navbatdan (Redis, RabbitMQ) ish oladi; bittasi muvaffaqiyatli tugasa va qolganlari chiqsa Job tugaydi |

### Indexed Job

`completionMode: Indexed` bilan har pod `0` dan `completions - 1` gacha bo'lgan o'z indeksini oladi: `JOB_COMPLETION_INDEX` muhit o'zgaruvchisi va pod nomidagi raqam orqali. Har indeks aynan bir marta muvaffaqiyatli tugashi kerak.

```yaml
spec:
  completions: 5
  parallelism: 2
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ['sh', '-c', 'echo "processing shard $JOB_COMPLETION_INDEX"']
```

Ishlatilishi: ma'lumotni bo'laklarga (shard) ajratib parallel qayta ishlash, tashqi navbat tizimisiz. Har indeks uchun alohida qayta urinish chegarasi `backoffLimitPerIndex` bilan beriladi.

## 4. CronJob

CronJob jadval bo'yicha Job yaratadi. O'zi pod yaratmaydi: CronJob Job'ni, Job esa Pod'ni yaratadi.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report
spec:
  schedule: "30 2 * * *"
  timeZone: "Asia/Tashkent"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 300
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: report
            image: busybox:1.36
            command: ['sh', '-c', 'date; echo report']
```

| Maydon | Standart | Ma'nosi |
|--------|----------|---------|
| `schedule` | majburiy | standart 5 maydonli cron ifodasi, `@hourly`, `@daily` kabi makroslar |
| `timeZone` | controller-manager vaqt zonasi (odatda UTC) | IANA nomi. `schedule` ichida `TZ=` yoki `CRON_TZ=` yozish qo'llanmaydi, validatsiya xatosi beradi |
| `concurrencyPolicy` | `Allow` | oldingi Job hali tugamagan bo'lsa: `Allow` yangisini parallel boshlaydi, `Forbid` yangisini o'tkazib yuboradi, `Replace` eskisini o'chirib yangisini boshlaydi |
| `startingDeadlineSeconds` | yo'q | rejadagi vaqtdan shuncha soniya kechikkan ish hali boshlanishi mumkin, undan kech bo'lsa o'tkazib yuboriladi |
| `successfulJobsHistoryLimit` | 3 | nechta muvaffaqiyatli Job saqlanadi |
| `failedJobsHistoryLimit` | 1 | nechta muvaffaqiyatsiz Job saqlanadi |
| `suspend` | `false` | `true` bo'lsa yangi Job yaratilmaydi, ishlab turganlariga ta'sir qilmaydi |

Qo'lda ishga tushirish (jadvalni kutmasdan sinash uchun):

```bash
kubectl create job report-manual --from=cronjob/report
```

### Kafolatlar va ularning yo'qligi

CronJob "taxminan bir marta" ishlaydi. Rasmiy hujjat aniq aytadi: ba'zi holatlarda bitta jadval vaqti uchun ikki Job yaratilishi yoki hech biri yaratilmasligi mumkin.

- Controller o'chiq bo'lgan vaqtda o'tgan jadval vaqtlari "o'tkazib yuborilgan" hisoblanadi. `startingDeadlineSeconds` berilmagan bo'lsa va oxirgi ishga tushishdan beri 100 tadan ko'p vaqt o'tkazib yuborilgan bo'lsa, controller Job yaratmaydi va xato yozadi. `startingDeadlineSeconds` berilsa, faqat shu oynadagi o'tkazib yuborilganlar sanaladi.
- `suspend: true` paytida o'tgan vaqtlar ham o'tkazib yuborilgan hisoblanadi. `startingDeadlineSeconds` siz `suspend` olib tashlansa, o'tkazib yuborilgan ish darhol boshlanadi.
- `concurrencyPolicy: Forbid` bilan uzoq ishlayotgan Job keyingi ishga tushishlarni jimgina yutadi.

**Tuzoq: CronJob jim o'ladi.** Zaxira CronJob'i bir oy oldin ishlamay qolgan bo'lsa, buni hech kim sezmaydi, toki tiklash kerak bo'lmaguncha. `status.lastSuccessfulTime` ni kuzatish va "oxirgi muvaffaqiyatli ish N soatdan eski" alertini qo'yish shart (observability moduli).

CronJob nomi 52 belgidan oshmasligi kerak: controller Job nomiga qo'shimcha qo'shadi, Job nomi esa 63 belgi bilan cheklangan. CronJob'ni o'zgartirish faqat keyingi yaratiladigan Job'larga ta'sir qiladi.

## 5. Idempotent ish dizayni

Yuqoridagilardan xulosa: ish bir necha marta boshlanishi, o'rtasida uzilishi, ikki nusxada parallel ishlashi mumkin. Idempotent ish bu necha marta bajarilsa ham natijasi bir xil bo'lgan ish.

| Idempotent emas | Idempotent |
|-----------------|------------|
| `INSERT` har ishga tushishda | `INSERT ... ON CONFLICT DO NOTHING`, yoki unikal kalit bilan upsert |
| faylga qo'shib yozish (`>>`) | vaqtinchalik faylga yozib, tugagach atomar `mv` |
| "barcha foydalanuvchilarga xat yubor" | yuborilganlarni belgilab borish, belgilanmaganlarga yuborish |
| `backup.sql` ni ustidan yozish | sana bilan nomlangan fayl, vaqtinchalik nomdan `mv` |
| hisoblagichni 1 ga oshirish | holatni manbadan qayta hisoblash |

Qo'shimcha qoidalar:

- **Yarim natija qoldirmang.** Ish o'rtasida o'ldirilishi mumkin (`SIGTERM`, node o'limi, deadline). Natija yo to'liq, yo yo'q bo'lsin: vaqtinchalik fayl va `mv`, tranzaksiya.
- **Parallel nusxadan himoyalaning**, agar ish bunga chidamasa: `concurrencyPolicy: Forbid` va qo'shimcha ravishda ilova darajasidagi lock (masalan, bazada advisory lock), chunki `Forbid` ham mutlaq kafolat emas.
- **Chegaralar qo'ying**: `activeDeadlineSeconds` osilib qolgan ishni o'ldiradi, `backoffLimit` cheksiz urinishni to'xtatadi.
- **Exit code halol bo'lsin.** Shell skriptda `set -euo pipefail` bo'lmasa, `pg_dump | gzip > file` da `pg_dump` yiqilsa ham skript 0 qaytaradi va Job "muvaffaqiyatli" bo'sh fayl yaratadi.

## 6. Misol: ma'lumotlar bazasi zaxirasi

Tuzilishi (yakuniy vazifada o'zingiz yozasiz):

- Baza paroli Secret'da, CronJob pod'iga env yoki fayl orqali beriladi (`PGPASSWORD`, yoki `PGPASSFILE`).
- CronJob `postgres` image'i bilan `pg_dump` ni ishga tushiradi (klient versiyasi server versiyasidan eski bo'lmasligi kerak).
- Dump PVC'ga, sana bilan nomlangan faylga yoziladi; avval vaqtinchalik nom, muvaffaqiyatdan keyin `mv`.
- Eski zaxiralar o'chiriladi (retention), masalan `find /backup -name '*.sql.gz' -mtime +7 -delete`.
- `concurrencyPolicy: Forbid`, `activeDeadlineSeconds`, `backoffLimit`, `startingDeadlineSeconds`, history limit'lar.

Bu laboratoriya sxemasi. Production'da zaxira klasterdan tashqariga, object storage'ga (S3) yoziladi: klaster yoki disk yo'qolsa, ichidagi zaxira ham yo'qoladi. Va tiklab ko'rilmagan zaxira zaxira hisoblanmaydi: tiklash ham Job sifatida avtomatlashtiriladi va muntazam sinaladi.

## Tuzoqlar

- Ish idempotent emas, Job esa uni ikki marta ishga tushirdi: ikkilangan yozuvlar, ikki marta yuborilgan xatlar.
- `ttlSecondsAfterFinished` va history limit'lar yo'q: minglab eski Job va pod obyektlari.
- `activeDeadlineSeconds` yo'q: osilib qolgan Job bir hafta ishlaydi, `Forbid` tufayli keyingilarini to'sadi.
- Shell skriptda `set -euo pipefail` yo'qligi: pipe ichidagi xato yutiladi, Job "muvaffaqiyatli".
- `timeZone` berilmagan: jadval UTC bo'yicha ishlaydi, "tungi 2" aslida mahalliy vaqt bilan ertalabki 7.
- `restartPolicy: OnFailure` va `backoffLimit` oshishi: pod o'chiriladi, xato log'i yo'qoladi.
- CronJob'ni kuzatmaslik: ish haftalab ishlamaydi va hech kim bilmaydi.
- Zaxirani faqat klaster ichida saqlash va hech qachon tiklab ko'rmaslik.
- Job template'ni o'zgartirib `apply` qilish: `field is immutable` xatosi. CI'da Job nomiga versiya yoki hash qo'shiladi, yoki eski Job avval o'chiriladi.

## Manbalar

- https://kubernetes.io/docs/concepts/workloads/controllers/job/ – Job (majburiy, to'liq)
- https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ – CronJob, cheklovlari bilan
- https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/ – tugagan Job'larni avtomatik tozalash
- https://kubernetes.io/docs/tasks/job/ – Job naqshlari bo'yicha amaliy misollar
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/cron-job-v1/ – CronJob API ma'lumotnomasi
- https://www.postgresql.org/docs/current/app-pgdump.html – pg_dump
- https://crontab.guru/ – cron ifodalarini tekshirish

---

## Vazifalar

Barchasini `kubernetes/05-jobs/` papkasida bajaring (`make new m=kubernetes n=05 name=jobs`). Javoblar `README.md` ga `## N. Title` sarlavhalari ostida: buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Manifestlar `task_N.yaml`, skriptlar `task_N.sh` nomi bilan saqlanadi. Hammasi `jobs` namespace'ida.

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

### Topshirish

Tayyor bo'lgach:
1. `README.md` da barcha 18 vazifa yozilgan, manifest va skriptlar papkada.
2. `make check` toza o'tadi (`yamllint`, `shellcheck`).
3. Papkada parol yoki Secret manifesti yo'q.
4. `jobs` namespace'i o'chirilgan (PVC'lar bilan birga).
5. Menga xabar bering, tekshiraman.

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
