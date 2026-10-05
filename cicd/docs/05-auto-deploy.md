# 5-dars: Dasturlarni serverga avtomatik deploy

Maqsad: pipeline'ning oxirgi bo'g'inini qurish: `main` ga merge qilingan commit hech kim serverga qo'lda kirmasdan production'ga chiqadi, tekshiriladi va kerak bo'lsa bir buyruq bilan qaytariladi. Cloud modulida siz konteynerlangan ilovani AWS VM'ga qo'lda deploy qilgansiz: SSH bilan kirib, `docker compose pull` va `up`. Bu darsda o'sha qadamlarni 2-darsdagi GitHub Actions pipeline'iga ko'chirasiz va qo'lda qilganda yashirin qolgan savollarga javob berasiz: pipeline serverga qanday huquq bilan kiradi, yangi versiya buzuq chiqsa nima bo'ladi, deploy paytida foydalanuvchi xato ko'radimi, database sxemasi qachon o'zgaradi. Kubernetes modulida deploy mexanizmi o'zgaradi, lekin shu yerdagi tushunchalar (immutable tag, health check, strategiya, rollback) o'zgarishsiz qoladi.

Taxminiy vaqt: 5 kun (siz uchun): nazariya va SSH deploy 2 kun, blue-green va rollback 1.5 kun, mini-loyiha 1.5 kun. Diqqatni quyidagilarga qarating: deploy kalitining huquqini cheklash, `known_hosts`, SHA tag va rollback aloqasi, migratsiyalarning orqaga mos bo'lishi, blue-green almashtirish mexanizmi, smoke test yiqilganda avtomatik qaytish.

## Laboratoriya

- **Deploy nishoni**: cloud modulidagi AWS VM (eng kichik instans, Ubuntu, Docker va Compose plugin o'rnatilgan, security group'da 22, 80 portlar). O'chirgan bo'lsangiz cloud modulidagi qadamlar bilan qayta ko'taring. Budget alert yoqilganini tekshiring.
- VM'dagi tizim o'zgarishlari (deploy user, `authorized_keys`, papkalar) VM'da bajariladi, ish mashinasida emas.
- **Pipeline**: GitHub'dagi `cicd-demo`, 2-darsdagi `ci.yml` asosida. Image'lar GHCR'da.
- **Blue-green mashqi** avval ish mashinasida Docker Compose bilan lokal qilinadi (bepul, tez), keyin VM'ga ko'chiriladi.
- OIDC vazifasi uchun AWS CLI kerak bo'lsa, uni cloud modulida o'rnatgansiz. Yo'q bo'lsa: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Ish papkasi `cicd/05-auto-deploy/`: `README.md`, `deploy.sh`, `compose.yaml`, proxy konfiguratsiyasi, workflow nusxalari.
- **Tozalash (majburiy)**: dars oxirida VM, Elastic IP, OIDC uchun yaratilgan IAM role va identity provider o'chiriladi va konsolda o'chirilgani tekshiriladi. GitHub'dagi deploy secret'lari o'chiriladi. VM yo'q bo'lgach eski deploy kaliti ham yaroqsiz, lekin secret'ni baribir o'chiring.

---

## 1. Push-based va pull-based deploy

| | Push-based | Pull-based |
|-|------------|------------|
| Kim boshlaydi | pipeline serverga ulanadi va buyruq beradi | serverdagi agent yangi versiyani o'zi tekshirib oladi |
| Credential qayerda | CI tizimida serverga kirish kaliti | serverda registry/repo'ni o'qish huquqi |
| Tarmoq | server CI'dan kiruvchi ulanishni qabul qilishi kerak | faqat chiquvchi ulanish |
| Natija | pipeline deploy natijasini darhol biladi | pipeline bilmaydi, alohida kuzatish kerak |
| Misollar | SSH + compose, Ansible, `kubectl apply` CI'dan | Argo CD, Flux (GitOps), Watchtower, cron + `compose pull` |

Push-based sodda va tushunarli, kichik tizimlar uchun to'g'ri tanlov. Kamchiligi: CI tizimi production'ga kirish kalitini saqlaydi, demak CI'ni buzgan odam production'ni ham buzadi. Pull-based'da bu kalit yo'q, server faqat "kerakli holat" ni o'qiydi. GitOps shu g'oyaning to'liq shakli, Kubernetes modulida ko'rasiz.

Oraliq variant: serverning o'zida self-hosted runner. Runner chiquvchi ulanish bilan job oladi va deploy'ni lokal bajaradi. Kiruvchi SSH kerak emas, lekin 2-darsdagi runner xavflari (runner serverda ixtiyoriy kod bajaradi) to'liq amal qiladi.

Bu darsda push-based SSH deploy quriladi, chunki uning har qadami ko'rinadi.

## 2. Pipeline'dan SSH: kalit, known_hosts, deploy user

### Alohida deploy kaliti
Pipeline sizning shaxsiy SSH kalitingiz bilan kirmaydi. Faqat deploy uchun alohida juftlik yaratiladi, parolsiz (pipeline parol kirita olmaydi), private qismi faqat CI secret'ida turadi:

```
ssh-keygen -t ed25519 -N "" -C "cicd-demo-deploy" -f ./deploy_key
gh secret set DEPLOY_SSH_KEY --env production < ./deploy_key
```

Secret'ga yozilgach lokal private fayl o'chiriladi. Kalit yo'qolsa yangisi yaratiladi, bu arzon.

### known_hosts
SSH birinchi ulanishda server host key'ini ko'rsatib "ishonasizmi?" deb so'raydi. Pipeline'da buni `StrictHostKeyChecking=no` bilan o'chirish keng tarqalgan va noto'g'ri: bu man-in-the-middle himoyasini olib tashlaydi, pipeline deploy kaliti bilan soxta serverga ulanib ketishi mumkin.

To'g'ri yo'l: host key'ni bir marta, ishonchli kanal orqali oling, CI'da variable sifatida saqlang va job'da `~/.ssh/known_hosts` ga yozing.

```
ssh-keyscan -t ed25519 <host> > known_hosts_entry
ssh-keygen -lf known_hosts_entry
```

**Tuzoq: `ssh-keyscan` ni job ichida ishlatish.** Har run'da tarmoqdan olingan kalitga ishonish `StrictHostKeyChecking=no` bilan bir xil. `ssh-keyscan` natijasining fingerprint'ini serverning o'zidagi kalit bilan (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`, VM konsolidan) solishtirib, keyin saqlang. Host key ochiq ma'lumot, uni secret emas, variable sifatida saqlash mumkin.

### Least-privilege deploy user
Deploy kaliti `ubuntu` yoki `root` ga kirish bermaydi. Alohida `deploy` foydalanuvchisi yaratiladi: `sudo` huquqisiz, parolsiz, faqat kalit bilan.

Nozik joy: `deploy` Docker bilan ishlashi kerak, `docker` guruhiga a'zolik esa amalda root huquqi (docker modulida ko'rgansiz: `docker run -v /:/host` bilan butun host ochiladi). Shuning uchun kalitning o'zi cheklanadi. `authorized_keys` dagi variantlar:

```
restrict,command="/opt/app/deploy.sh" ssh-ed25519 AAAA... cicd-demo-deploy
```

- `command="..."` (forced command): bu kalit bilan kirilganda mijoz nima so'rasa ham faqat shu buyruq bajariladi. Mijoz yuborgan asl buyruq `SSH_ORIGINAL_COMMAND` env variable'ida keladi, skript undan faqat versiya (SHA) ni oladi va qat'iy tekshiradi.
- `restrict`: port forwarding, agent forwarding, PTY va boshqa imkoniyatlarni o'chiradi.

Natija: kalit o'g'irlansa ham u bilan faqat "ruxsat etilgan image'ning boshqa versiyasini deploy qilish" mumkin, shell ochib bo'lmaydi. Deploy mantiqi (`deploy.sh`) serverda turadi, pipeline faqat "shu SHA'ni chiqar" deydi.

**Tuzoq: `SSH_ORIGINAL_COMMAND` ni tekshirmasdan ishlatish.** Uni `eval` qilish yoki `docker` buyrug'iga to'g'ridan qo'yish forced command'ni ma'nosiz qiladi. Qiymatni regex bilan tekshiring (masalan faqat 40 ta hex belgi), mos kelmasa rad eting.

### Tarmoq
GitHub hosted runner'larning IP manzillari keng va o'zgaruvchan diapazonlardan keladi, shuning uchun security group'da 22-portni aniq manzilga toraytirib bo'lmaydi. Variantlar: 22-port ochiq, lekin faqat kalit bilan kirish va cheklangan kalit (shu dars); serverdagi self-hosted runner; VPN yoki bastion; AWS'da SSH o'rniga Systems Manager orqali buyruq yuborish (OIDC bilan, 8-bo'lim); pull-based deploy. Tanlov xavf modeliga bog'liq, lekin "22-port butun internetga ochiq va parol bilan kirish yoqilgan" hech qachon variant emas.

## 3. Image tag: commit SHA, hech qachon latest

Deploy buyrug'i "qaysi versiya" ni aniq aytishi kerak. `latest` buni aytmaydi:

- `docker compose up -d` lokal image bor bo'lsa registry'ni tekshirmaydi: yangi `latest` push qilingan, serverda esa eskisi ishlayveradi.
- Serverda hozir qaysi commit ishlayotganini bilib bo'lmaydi.
- Rollback uchun "oldingi `latest`" degan narsa yo'q, u ustidan yozilgan.
- Ikki server turli vaqtda pull qilsa turli versiyalarni ishlatadi.

SHA tag bilan compose fayl o'zgaruvchi orqali versiya oladi:

```yaml
services:
  app:
    image: ghcr.io/<owner>/cicd-demo:${APP_TAG:?APP_TAG is required}
    environment:
      APP_VERSION: ${APP_TAG}
```

`${VAR:?msg}` o'zgaruvchi berilmasa xato bilan to'xtaydi, tasodifan bo'sh tag bilan deploy bo'lmaydi. Rollback endi oddiy: oldingi SHA bilan o'sha deploy. Eng qat'iy variant tag o'rniga digest (`image@sha256:...`): tag nazariy jihatdan qayta yozilishi mumkin, digest yo'q.

Serverdan private GHCR image'ni pull qilish uchun serverda alohida, faqat o'qish huquqli (`read:packages`) token bilan `docker login ghcr.io` qilinadi, yoki package public qilinadi. Pipeline'ning `GITHUB_TOKEN` i serverga berilmaydi (u baribir job tugashi bilan o'ladi).

## 4. Health check va smoke test

"Konteyner ishga tushdi" va "ilova ishlayapti" turli narsalar. Deploy uch darajada tekshiriladi:

| Daraja | Nima tekshiradi | Qayerda |
|--------|-----------------|---------|
| Konteyner healthcheck | jarayon ichkaridan javob beradimi | `Dockerfile` `HEALTHCHECK` yoki compose `healthcheck` |
| Deploy kutishi | yangi konteyner `healthy` bo'ldimi | `docker compose up -d --wait` |
| Smoke test | tashqaridan, foydalanuvchi yo'li bilan ishlaydimi va **kutilgan versiya** javob beradimi | pipeline'ning deploy'dan keyingi step'i |

`docker compose up -d --wait` servislar `running`/`healthy` bo'lguncha kutadi va bo'lmasa nol bo'lmagan kod qaytaradi (`--wait-timeout` bilan cheklanadi). Smoke test esa ommaviy URL'ga so'rov yuboradi:

```
curl --fail --silent --show-error --retry 10 --retry-delay 3 --retry-all-errors \
  "https://app.example.com/version"
```

Smoke test `/healthz` 200 qaytarganini emas, `/version` aynan deploy qilingan SHA'ni qaytarganini tekshirishi kerak. Aks holda eski versiya ishlab turgan va yangi versiya umuman ko'tarilmagan holatda ham test "yashil" bo'ladi.

Health endpoint dizayni: **liveness** (jarayon tirik) va **readiness** (so'rov qabul qilishga tayyor: bazaga ulangan, migratsiya tugagan) ajratiladi. Proxy trafikni faqat ready bo'lgan nusxaga yuboradi. Bu ajratish Kubernetes modulida probe'lar sifatida qaytadi.

## 5. Deploy strategiyalari

| Strategiya | Qanday ishlaydi | Downtime | Rollback | Narxi |
|------------|-----------------|----------|----------|-------|
| Recreate | eskisini to'xtat, yangisini ko'tar | bor (soniyalar, daqiqalar) | qayta deploy | eng sodda, qo'shimcha resurs yo'q |
| Rolling | nusxalar birin-ketin yangilanadi | yo'q (2+ nusxa bo'lsa) | teskari rolling | bir vaqtda ikki versiya ishlaydi |
| Blue-green | yangi versiya to'liq parallel ko'tariladi, trafik bir zumda almashtiriladi | yo'q | trafikni qaytarish, soniyalar | vaqtincha ikki barobar resurs |
| Canary | trafikning kichik qismi (1–5%) yangi versiyaga, metrikalar yaxshi bo'lsa oshiriladi | yo'q | canary'ni o'chirish | trafik bo'lish va metrika tahlili kerak |

Bitta VM'da oddiy `docker compose up -d` bu recreate: eski konteyner to'xtaydi, yangisi ko'tariladi, orada so'rovlar yiqiladi. Rolling, blue-green va canary'ning umumiy sharti: bir vaqtda ikki versiya ishlaydi, demak ular bir-biriga va bitta database sxemasiga mos bo'lishi kerak (6-bo'lim).

### Compose va reverse proxy bilan blue-green
G'oya: ilovaning ikki nusxasi (`blue`, `green`) uchun joy bor, reverse proxy (network modulidagi nginx) ulardan biriga trafik yuboradi.

1. Hozir `blue` jonli. Yangi versiya `green` sifatida ko'tariladi, `blue` ga tegilmaydi.
2. `green` ichki tarmoq orqali tekshiriladi (health, versiya). Yiqilsa `green` o'chiriladi, foydalanuvchi hech narsa sezmaydi.
3. Proxy konfiguratsiyasi `green` ga yo'naltiriladi va **reload** qilinadi (restart emas).
4. Tashqaridan smoke test. Yiqilsa proxy `blue` ga qaytariladi: rollback bir necha soniya.
5. Kuzatuv oynasidan keyin `blue` to'xtatiladi (yoki keyingi deploy'gacha zaxira sifatida qoldiriladi).

```nginx
upstream app {
    server app-green:3000;
}
```

`nginx -s reload` yangi worker'larni yangi konfiguratsiya bilan ochadi, eski worker'lar ochiq so'rovlarni tugatib yopiladi, ulanishlar uzilmaydi. Reload'dan oldin `nginx -t` bilan konfiguratsiya tekshiriladi. Qaysi rang jonli ekani serverda faylda saqlanadi, `deploy.sh` uni o'qib qarama-qarshisini tanlaydi.

**Tuzoq: graceful shutdown.** Eski nusxa `SIGTERM` olganda ochiq so'rovlarni tugatmasdan o'lsa, almashtirish paytida bir nechta foydalanuvchi baribir xato oladi. Ilova `SIGTERM` ni ushlab yangi ulanishlarni qabul qilishni to'xtatishi va joriylarini tugatishi kerak (docker modulidagi PID 1 va signal mavzusi), compose'da `stop_grace_period` yetarli bo'lsin.

## 6. Database migratsiyalari

Kod stateless, uni qaytarish oson. Database esa holat: sxema o'zgarishi ko'pincha orqaga qaytmaydi (o'chirilgan ustundagi ma'lumot qaytib kelmaydi). Shuning uchun migratsiyalar deploy'ning eng xavfli qismi.

Qoidalar:

- Migratsiyalar kod bilan birga repo'da, versiyalangan, tartibli (migration tool: `node-pg-migrate`, Prisma Migrate, Flyway, `golang-migrate` va boshqalar). Tool qaysi migratsiyalar qo'llanganini bazadagi jadvalda saqlaydi.
- Migratsiya pipeline'da **alohida qadam**, ilova ishga tushishidan oldin, **bir marta** bajariladi. Ilovaning start kodida migratsiya ishlatilsa, bir nechta nusxa bir vaqtda migratsiya qilishga urinadi.
- Har migratsiya **orqaga mos** (backward compatible) bo'lishi kerak: eski kod yangi sxema bilan ishlay olsin. Chunki deploy paytida (va rollback'dan keyin) eski kod yangi sxemaga duch keladi.

Buzuvchi o'zgarishlar **expand/contract** usulida bir nechta deploy'ga bo'linadi. Ustun nomini o'zgartirish misoli:

| Deploy | Sxema | Kod |
|--------|-------|-----|
| 1. Expand | yangi ustun qo'shiladi (nullable) | ikkalasiga yozadi, eskisidan o'qiydi |
| 2. Migrate | eski ma'lumot yangi ustunga ko'chiriladi | yangisidan o'qiydi, ikkalasiga yozadi |
| 3. Contract | eski ustun o'chiriladi | faqat yangisi bilan ishlaydi |

Har qadamdan keyin oldingi kod versiyasiga xavfsiz qaytish mumkin. Bitta deploy'da `RENAME COLUMN` qilinsa, eski kod darhol yiqiladi va rollback ham yordam bermaydi.

**Tuzoq: uzoq lock.** Katta jadvalda ba'zi `ALTER TABLE` amallari jadvalni bloklaydi va migratsiya davomida ilova to'xtab qoladi. Production migratsiyalari real hajmdagi ma'lumotda sinalishi kerak. Migratsiyadan oldin zaxira nusxa (yoki snapshot) olinadi.

## 7. Rollback va xabarnomalar

Rollback bu "oldingi versiyani deploy qilish", alohida mexanizm emas. Agar deploy `deploy.sh <sha>` bo'lsa, rollback `deploy.sh <previous-sha>`. Buning uchun:

- Oldingi image registry'da turibdi (SHA tag'lar o'chirilmagan, cleanup policy oxirgi N tasini saqlaydi).
- Server oldingi muvaffaqiyatli SHA'ni biladi (faylda saqlaydi) yoki pipeline uni deployment tarixidan oladi.
- Rollback yo'li oddiy deploy bilan bir xil kod orqali o'tadi va muntazam sinab turiladi. Sinalmagan rollback mavjud emas deb hisoblanadi.

Ikki xil rollback: **avtomatik** (smoke test yiqilsa pipeline o'zi oldingi SHA'ga qaytaradi va run'ni qizil qiladi) va **qo'lda** (`workflow_dispatch` bilan, SHA input sifatida). Blue-green'da avtomatik rollback proxy'ni qaytarishdan iborat.

Rollback va **roll forward**: kichik xatoda tuzatishni yangi commit sifatida chiqarish tezroq bo'lishi mumkin (pipeline tez bo'lsa). Database migratsiyasi orqaga qaytmaydigan bo'lsa, yagona yo'l roll forward. Qoida: avval xizmatni tikla (rollback), keyin sababni qidir.

### Xabarnomalar
Jamoa deploy boshlanganini, tugaganini va ayniqsa yiqilganini bilishi kerak. Pipeline oxirida chat'ga xabar yuboriladi (Slack webhook, Telegram Bot API), holat sharti bilan:

```yaml
- name: Notify failure
  if: failure()
  env:
    TG_TOKEN: ${{ secrets.TG_TOKEN }}
  run: |
    curl --fail --silent -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      -d chat_id="${{ vars.TG_CHAT_ID }}" -d text="Deploy failed: ${GITHUB_SHA}"
```

Xabarda: environment, SHA, kim boshlagan, run havolasi. Muvaffaqiyatli deploy'lar uchun shovqin kam bo'lsin, yiqilganlar uchun aniq va harakatga chaqiruvchi.

## 8. OIDC: uzoq yashaydigan kalitlarsiz cloud'ga kirish

Pipeline cloud API bilan ishlashi kerak bo'lsa (S3'ga yuklash, ECR'ga push, Systems Manager orqali buyruq), eski usul: IAM user access key'ini CI secret'iga yozish. Muammo: kalit uzoq yashaydi, sizib chiqsa bekor qilinguncha ishlaydi, aylantirish qo'lda.

OIDC (OpenID Connect) bilan saqlanadigan kalit yo'q:

1. Job GitHub'ning OIDC provayderidan imzolangan qisqa muddatli JWT oladi. Ichida claim'lar: qaysi repo, qaysi branch, qaysi environment, qaysi workflow.
2. Job bu token'ni AWS STS'ga beradi (`AssumeRoleWithWebIdentity`).
3. AWS imzoni tekshiradi va IAM role'ning **trust policy** sidagi shartlarni claim'lar bilan solishtiradi.
4. Mos kelsa, vaqtinchalik credential (standart 1 soat) qaytaradi.

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/cicd-demo-deploy
      aws-region: eu-central-1
```

AWS tomonda: IAM'da OIDC identity provider (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`) va trust policy'sida `sub` claim'iga shart qo'yilgan role, masalan `repo:<owner>/cicd-demo:environment:production`.

**Tuzoq: keng trust policy.** `sub` sharti `repo:<owner>/*` yoki umuman yo'q bo'lsa, o'sha owner'ning (yoki har qanday) istalgan reposidagi workflow sizning role'ingizni oladi. Shart aniq repo va branch yoki environment'gacha toraytiriladi. Role'ning o'ziga ham faqat kerakli minimal huquqlar beriladi.

Xuddi shu mexanizm GitLab CI'da (`id_tokens`), boshqa cloud'larda va Vault kabi secret omborlarida ham ishlaydi.

## Tuzoqlar

- `latest` bilan deploy: nima ishlab turganini ham, nimaga qaytishni ham bilmaysiz.
- `StrictHostKeyChecking=no` yoki job ichida `ssh-keyscan`.
- Deploy kalitini shaxsiy kalit bilan bir xil qilish, `root`/`sudo` huquqli foydalanuvchiga berish, forced command'siz qoldirish.
- Smoke test faqat 200 kodni tekshiradi, versiyani emas. Deploy bo'lmagan holatda ham yashil.
- Rollback hech qachon sinalmagan. Incident paytida birinchi marta sinab ko'riladi va ishlamaydi.
- Orqaga mos bo'lmagan migratsiya bitta deploy'da kod bilan birga. Rollback imkonsiz.
- Migratsiyani ilova start'ida, har nusxada ishga tushirish.
- Ikki deploy bir vaqtda (concurrency yo'q): server yarim yangi, yarim eski holatda.
- Deploy yiqilganda pipeline yashil (`|| true`, `continue-on-error`, SSH ichidagi buyruqning exit code'i yo'qolishi).
- Eski image'lar va to'xtatilgan konteynerlar serverda to'planib disk to'lishi, yoki aksincha, registry cleanup rollback uchun kerakli tag'ni o'chirib yuborishi.
- Deploy secret'larini repo darajasida saqlash: har branch'dagi workflow ularni oladi. Environment darajasida va deployment branch cheklovi bilan saqlang.

## Manbalar

- https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT – `authorized_keys` formati: `command=`, `restrict`
- https://man.openbsd.org/ssh-keyscan – `ssh-keyscan`
- https://man.openbsd.org/ssh_config – `StrictHostKeyChecking`, `UserKnownHostsFile`
- https://docs.docker.com/reference/cli/docker/compose/up/ – `docker compose up`, `--wait`
- https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ – compose'da `${VAR:?}` interpolatsiyasi
- https://nginx.org/en/docs/control.html – nginx reload mexanizmi
- https://martinfowler.com/bliki/BlueGreenDeployment.html – blue-green deployment
- https://martinfowler.com/bliki/CanaryRelease.html – canary release
- https://martinfowler.com/bliki/ParallelChange.html – expand/contract (parallel change)
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect – GitHub Actions OIDC
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services – AWS bilan OIDC
- https://github.com/aws-actions/configure-aws-credentials – AWS credentials action
- https://core.telegram.org/bots/api#sendmessage – Telegram Bot API
- Humble, Farley, "Continuous Delivery", 10-bob (Deploying and Releasing Applications) va 12-bob (Managing Data)

---

## Vazifalar

Pipeline `cicd-demo` reposida, server qismi VM'da bajariladi. Javoblar `cicd/05-auto-deploy/` da (yaratish: `make new m=cicd n=05 name=auto-deploy`), shu papkadagi `README.md` ga `## N. Title` sarlavhalari ostida: bajarilgan buyruqlar, natijaning muhim qismi, run havolasi va o'z so'zingiz bilan izoh. `deploy.sh`, `compose.yaml`, proxy konfiguratsiyasi va workflow nusxalari shu papkada saqlanadi. Private key, token va `.env` commit qilinmaydi.

### A. Server va kirish

1. **Deploy target.** Cloud modulidagi VM'ni ko'taring (yoki mavjudini tekshiring): Docker va Compose versiyalari, security group qoidalari, budget alert. `cicd-demo` image'ini qo'lda, SHA tag bilan pull qilib ishga tushiring va tashqaridan `/version` ni tekshiring. Bu avtomatlashtiriladigan qo'l jarayonining bazaviy o'lchovi: qadamlar soni va ketgan vaqtni yozing.

2. **Deploy user.** VM'da `deploy` foydalanuvchisini yarating: `sudo` siz, parol bilan kirish imkonisiz, `/opt/app` egasi. Unga Docker bilan ishlash huquqini bering va bu nima uchun "amalda root" ekanini bitta buyruq bilan namoyish qiling (VM'da, zararsiz misol). Bu xavfni keyingi vazifalar qanday kamaytirishini oldindan yozing.

3. **Deploy key.** Alohida ed25519 juftlik yarating, public qismini `deploy` ning `authorized_keys` iga qo'ying, `ssh -i` bilan kirishni tekshiring. Private kalitni `production` environment secret'i sifatida `gh secret set` bilan yozing va lokal faylni o'chiring. Nima uchun shaxsiy kalitingizni ishlatmadingiz va nima uchun secret repo emas, environment darajasida?

4. **known_hosts.** VM host key'ini `ssh-keyscan` bilan oling va fingerprint'ini VM'ning o'zidagi kalit fingerprint'i bilan solishtiring (ikkala buyruq va natijani yozing). Uni environment variable sifatida saqlang. `StrictHostKeyChecking=no` qanday hujumga yo'l ochishini aniq ssenariy bilan tasvirlang.

5. **Forced command.** VM'da `/opt/app/deploy.sh` yozing: `SSH_ORIGINAL_COMMAND` dan SHA'ni oladi, formatini qat'iy tekshiradi, noto'g'ri bo'lsa rad etadi (hozircha faqat `echo`). `authorized_keys` da kalitni `restrict,command=...` bilan cheklang. Tekshiring: `ssh deploy@host` (shell), `ssh deploy@host 'cat /etc/passwd'`, `ssh deploy@host '<sha>; id'`, `scp`, port forwarding. Har birida nima bo'ldi?

### B. Avtomatik deploy

6. **Compose with SHA tag.** VM'dagi `/opt/app/compose.yaml`: image tag `${APP_TAG:?}` dan, `healthcheck` bilan, `APP_VERSION` ilovaga uzatiladi. `deploy.sh` ni to'ldiring: pull, `up -d --wait`, muvaffaqiyatli SHA'ni faylga yozish, oldingisini saqlash. `APP_TAG` siz `docker compose config` nima deydi? Private package uchun serverdagi registry login'ini qanday hal qilganingizni yozing.

7. **Deploy job.** `ci.yml` ga `deploy-production` job'ini qo'shing: `build` dan keyin, faqat `main` da, `environment: production`, `concurrency` (`cancel-in-progress: false`), minimal `permissions`. Job SSH kalit va `known_hosts` ni sozlab, serverga faqat `github.sha` ni yuboradi. Merge qiling va `/version` yangi SHA'ni qaytarishini tekshiring. Kalit fayliga qanday permission berdingiz va nima uchun?

8. **Smoke test.** Deploy'dan keyin tashqaridan `/healthz` va `/version` ni retry bilan tekshiradigan step qo'shing, `/version` aynan `github.sha` ga teng bo'lishi shart. Testni sinash: serverdagi `deploy.sh` ni vaqtincha hech narsa qilmaydigan qilib qo'ying va pipeline qizil bo'lishini ko'rsating. Faqat 200 kodni tekshiradigan smoke test bu holatda nima deyardi?

9. **Broken release.** Start'da yiqiladigan (yoki `/healthz` 500 qaytaradigan) versiyani merge qiling. Kuzating: `--wait` nima qaytardi, pipeline qayerda to'xtadi, sayt shu paytda ishlayaptimi (recreate strategiyasi)? Downtime'ni `while` sikli ichidagi `curl` bilan o'lchang. Bu natija keyingi guruh uchun motivatsiya.

10. **Exit code propagation.** `deploy.sh` ichida bir buyruq yiqilganda SSH va pipeline step'i ham yiqilishini isbotlang. Keyin skriptdan `set -e` ni olib tashlab (yoki `|| true` qo'shib) "deploy yiqildi, pipeline yashil" holatini hosil qiling, kuzating va qaytaring. Yana qaysi yo'llar bilan exit code yo'qolishi mumkin (pipe, `ssh` ichidagi `;`)?

11. **Manual rollback.** `rollback.yml` (`workflow_dispatch`, input: SHA, bo'sh bo'lsa serverdagi oldingi muvaffaqiyatli SHA) yozing. U oddiy deploy bilan bir xil yo'ldan o'tsin (o'sha `deploy.sh`, o'sha smoke test). `gh workflow run` bilan ishga tushirib vaqtini o'lchang. Registry'da mavjud bo'lmagan SHA bersangiz nima bo'ladi va sayt shu paytda qanday holatda qoladi?

12. **Notifications.** Deploy natijasi haqida xabar yuboradigan step'lar qo'shing (Telegram bot yoki boshqa webhook): muvaffaqiyat va xato uchun alohida matn, ichida environment, qisqa SHA, actor va run havolasi. Token secret'da. Xabar step'ining o'zi yiqilsa deploy natijasi qanday ko'rinishi kerakligini hal qiling va asoslang.

### C. Downtime'siz deploy

13. **Blue-green locally.** Ish mashinasida `compose.yaml`: `app-blue`, `app-green` va nginx. Qo'lda bajaring: blue jonli, green'ni yangi versiya bilan ko'tarish, ichki tarmoqdan tekshirish, upstream'ni almashtirish, `nginx -t`, reload. Almashtirish davomida boshqa terminalda `while` sikli bilan sekundiga bir necha so'rov yuborib, nechta xato bo'lganini sanang. Xuddi shu o'lchovni `nginx` ni restart qilib takrorlang va farqni izohlang.

14. **Blue-green script.** `deploy.sh` ni blue-green'ga o'tkazing: jonli rangni fayldan o'qish, bo'sh rangni yangi SHA bilan ko'tarish, health va versiya tekshiruvi, proxy'ni almashtirish, tashqi tekshiruv yiqilsa proxy'ni qaytarish, eski rangni to'xtatish. Lokal sinang: yaxshi versiya, keyin buzuq versiya (9-vazifadagi). Buzuq versiyada foydalanuvchi nechta xato ko'rdi?

15. **Graceful shutdown.** Ilovaga sun'iy sekin endpoint (`/slow`, 5 soniya) qo'shing. So'rov ketayotgan paytda rangni almashtiring va eski nusxani to'xtating. So'rov tugadimi? Ilovada `SIGTERM` ishlovchisi yo'q va bor holatlarni taqqoslang, `stop_grace_period` rolini izohlang.

16. **Migration design.** Kodsiz, yozma: `users.name` ustunini `full_name` ga o'zgartirish kerak, ilova blue-green bilan deploy qilinadi. Expand/contract bo'yicha har deploy'da sxema va kod nima qilishini jadval qilib yozing. Har qadamdan keyin oldingi versiyaga rollback xavfsizmi? Migratsiya qadami pipeline'da qayerda turadi va nima uchun ilova start'ida emas?

17. **Migration step.** Ixtiyoriy chuqurlashtirish, lekin tavsiya etiladi: compose'ga `postgres` qo'shing, ilovaga bitta jadval va migration tool. Deploy'ga migratsiya qadamini qo'shing (alohida bir martalik konteyner, ilova almashtirilishidan oldin). Bitta additive migratsiyani to'liq pipeline orqali chiqaring va rollback'dan keyin eski kod yangi sxema bilan ishlashini ko'rsating.

### D. OIDC va mini-loyiha

18. **OIDC to AWS.** AWS'da GitHub OIDC identity provider va faqat `sts:GetCallerIdentity` uchun yetarli (yoki bitta S3 bucket'ni o'qish huquqli) IAM role yarating, trust policy `cicd-demo` reposi va `production` environment'iga toraytirilgan. Workflow'da `id-token: write` bilan role'ni olib `aws sts get-caller-identity` chiqaring. Repo'da hech qanday AWS kaliti yo'qligini ko'rsating. Keyin trust policy'ga mos kelmaydigan joydan (boshqa branch yoki environment'siz job) urinib ko'ring va xatoni yozing.

19. **Mini-project: full pipeline.** Hammasini birlashtiring. PR: lint, test, image build (push'siz). `main` ga merge: test, build, GHCR'ga SHA tag bilan push, VM'ga blue-green deploy (approval bilan yoki avtomatik, tanlovingizni asoslang), tashqi smoke test, yiqilsa avtomatik qaytish, xabarnoma. `README.md` ga: pipeline grafi, har job'ning permissions va secret'lari jadvali, commit'dan production'gacha vaqt (lead time), 1-vazifadagi qo'l jarayoni bilan taqqos.

20. **Rollback drill.** Uch ssenariyni ketma-ket o'tkazing va har biri uchun vaqt jadvalini (aniqlash, qaror, tiklanish) yozing: (a) health'i yiqiladigan versiya, avtomatik qaytish ishladimi; (b) health'i yashil, lekin `/version` dan boshqa endpoint buzuq versiya, uni kim va qanday aniqladi, qo'lda rollback qancha vaqt oldi; (c) rollback o'rniga roll forward (tuzatish commit'i), qaysi biri tezroq chiqdi. Xulosa: sizning pipeline'ingiz uchun time to restore qancha va uni nima cheklaydi?

21. **Threat review.** Yakuniy pipeline uchun qisqa tahlil: hujumchi (a) repo'ga PR ocha oladi, (b) bitta uchinchi tomon action'ini buzgan, (c) deploy private kalitini qo'lga kiritgan, (d) VM'dagi `deploy` foydalanuvchisi bo'lib olgan. Har holatda u nima qila oladi, qaysi himoya chorasi uni to'xtatadi yoki cheklaydi, qanday qoldiq xavf bor?

### Topshirish

Tayyor bo'lgach:
1. `main` ga merge qilingan commit qo'l tekkizmasdan production'ga chiqadi va `/version` shu SHA'ni qaytaradi.
2. Buzuq versiya foydalanuvchiga ko'rinmasdan qaytariladi, pipeline qizil bo'ladi, xabarnoma keladi.
3. `rollback.yml` ishlaydi va vaqti o'lchangan.
4. Repo'da, log'larda va ish papkasida hech qanday private key, token yoki `.env` yo'q. `actionlint` va `shellcheck` toza, `make check` toza.
5. Cloud resurslari o'chirilgan va konsolda tekshirilgan: VM, Elastic IP, IAM role va OIDC provider. GitHub environment secret'lari va Telegram token o'chirilgan.
6. Menga xabar bering, repo havolasi va oxirgi muvaffaqiyatli hamda yiqilgan run havolalarini qo'shing.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Push-based va pull-based deploy farqi nima? Credential qaysi tomonda turadi?
- Nima uchun `StrictHostKeyChecking=no` va job ichidagi `ssh-keyscan` xavfli?
- Forced command va `restrict` deploy kalitini qanday cheklaydi? `docker` guruhidagi foydalanuvchi nima uchun baribir xavfli?
- Nima uchun `latest` bilan deploy qilinmaydi? SHA tag rollback'ni qanday soddalashtiradi?
- Smoke test nima uchun versiyani ham tekshirishi kerak?
- Recreate, rolling, blue-green va canary farqi nima? Blue-green'da rollback nima uchun tez?
- `nginx` reload va restart farqi nima?
- Migratsiya nima uchun orqaga mos bo'lishi kerak? Expand/contract qadamlarini ayting.
- Rollback va roll forward qachon qaysi biri tanlanadi?
- OIDC uzoq yashaydigan access key'ga nisbatan nimani yaxshilaydi? Trust policy'dagi `sub` sharti nima uchun muhim?
