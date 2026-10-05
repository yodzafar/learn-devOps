# 4-dars: Dasturlarni serverga joylash (deployment)

Maqsad: konteynerlangan web dasturni toza virtual mashinaga qo'lda, boshidan oxirigacha deploy qilish: server tayyorlash, image yetkazish, reverse proxy, DNS, TLS, secret'lar, loglar, yangilash va rollback, backup, hardening. Bu dars oldingi hamma modullarni birlashtiradi: linux (systemd, ssh, foydalanuvchilar), network (DNS, TLS, portlar), docker (image, compose) va shu modulning 2–3-darslari (IAM role, EC2, security group, S3). Deploy bu yerda ataylab qo'lda qilinadi: CI/CD va Terraform keyingi modullarda keladi, ular aynan shu qadamlarni avtomatlashtiradi. Qo'lda bir marta qilmagan odam pipeline buzilganda nima buzilganini tushunmaydi. Dars oxirida managed variantlarga (ECS/Fargate, App Runner, Elastic Beanstalk, Lightsail) qisqa nazar tashlanadi va modul mini-loyihasi topshiriladi.

Taxminiy vaqt: 5 kun (siz uchun): 1-kun server va image, 2-kun proxy, DNS va TLS, 3-kun secret, log, yangilash va rollback, 4-kun backup va hardening, 5-kun runbook, toza serverda qayta deploy va teardown. Diqqatni quyidagilarga qarating: so'rov foydalanuvchidan konteynergacha qaysi qatlamlardan o'tadi, deploy paytida uzilish qayerdan keladi, tiklab ko'rilmagan backup nima uchun backup emas, server yo'qolsa qayta qurish uchun nima yozib qo'yilgan bo'lishi kerak.

## Laboratoriya

- **Cloud akkaunt**: AWS, 2-darsdagi admin profil, 3-darsdagi region. Boshlashdan oldin: `aws sts get-caller-identity`, budget alert mavjud, 3-darsdagi `leftovers.sh` natijasi bo'sh.
- **Resurslar**: bitta EC2 instans (Ubuntu 24.04, eng kichik tip), bitta security group, bitta Elastic IP, bitta S3 bucket (backup), bitta IAM role, ixtiyoriy ravishda bitta ECR repozitoriy. Hammasida `project=devops-course` tag. NAT gateway, load balancer, RDS yaratilmaydi.
- **Instans tipi**: eng kichigidan boshlang. Xotira yetmasa bir pog'ona kattasiga o'ting va narxini https://aws.amazon.com/ec2/pricing/on-demand/ dan tekshiring. Image serverda build qilinmaydi (xotira va disk yetmaydi, production'da ham shunday qilinmaydi).
- **Domen**: TLS uchun DNS nomi kerak. O'z domeningiz bo'lsa registratordagi DNS'da subdomen uchun `A` yozuv yetarli (Route 53 hosted zone alohida haq oladi, shart emas). Domen bo'lmasa bepul dinamik DNS xizmatidan subdomen oling (masalan https://www.duckdns.org/).
- **Dastur**: docker modulida yozgan konteynerlangan web dasturingiz, PostgreSQL bilan. Talablar: HTTP port, health endpoint (masalan `/healthz`), konfiguratsiya environment o'zgaruvchilaridan, `SIGTERM` da to'g'ri to'xtash.
- **Xarajat**: instans, disk, public IPv4 va S3 bir necha kun ishlaydi. Mashg'ulotlar orasida instansni stop qilsangiz hisoblash haqi to'xtaydi, disk va Elastic IP haqi davom etadi. Darsni ketma-ket kunlarda tugating.
- **Dars oxirida**: hammasi o'chiriladi, `leftovers.sh` bilan tekshiriladi.
- **Server ichidagi hamma o'zgarish** (paket, user, sshd, systemd, firewall) faqat EC2 instansda. Ish mashinasida faqat `aws`, `ssh`, `docker build` va `docker push`.

---

## 1. Maqsadli arxitektura

```
user -> DNS (A record) -> Elastic IP -> security group (80, 443)
     -> reverse proxy container (TLS termination)
     -> app container (private Docker network)
     -> database container (volume) -> backup -> S3
```

Bitta server, uch konteyner, bitta compose fayl. Bu "single-node" deploy: yuqori mavjudlik yo'q (1-dars: bitta AZ dagi bitta VM), lekin kichik loyihalarning katta qismi aynan shunday ishlaydi va har bir keyingi murakkab sxema shu qatlamlarning ko'paytirilgani.

Deploy jarayonining qismlari:

| Qadam | Savol | Bu darsda |
|-------|-------|-----------|
| Build | Image qayerda yig'iladi | Ish mashinasida (keyin CI'da) |
| Ship | Image serverga qanday yetadi | Registry orqali |
| Configure | Konfiguratsiya va secret qayerdan keladi | Serverdagi `.env` fayl |
| Run | Kim ishga tushiradi va qayta ko'taradi | Docker restart policy, compose |
| Route | Trafik qanday yetadi | DNS, Elastic IP, security group, reverse proxy |
| Verify | Ishlayotganini qayerdan bilamiz | Health check, loglar |
| Recover | Buzilsa nima qilamiz | Rollback, backup, runbook |

## 2. Serverni tayyorlash

Instans 3-darsdagi kabi yaratiladi: Ubuntu 24.04, public subnet, Elastic IP, security group: 22 faqat sizning IP'dan, 80 va 443 hamma joydan. Database porti hech qachon ochilmaydi.

Docker Engine rasmiy apt repozitoriysidan o'rnatiladi: https://docs.docker.com/engine/install/ubuntu/ (compose plugin ham shu paketlar bilan keladi). O'rnatishni user data'ga yozsangiz server yaratilganda tayyor bo'ladi va qayta yaratish bitta buyruqqa aylanadi.

Serverdagi tuzilma:

```
/opt/app/
  compose.yaml
  Caddyfile
  .env          # chmod 600, not in git
```

`ubuntu` foydalanuvchisini `docker` group'ga qo'shish qulay, lekin bu group a'zosi amalda root (konteynerga host fayl tizimini mount qila oladi). Bitta odamli laboratoriya serverida maqbul, ko'p foydalanuvchili serverda emas.

## 3. Image'ni yetkazish

Image registry orqali yetkaziladi: ish mashinasida build va push, serverda pull. Variantlar: docker modulida ishlatgan registry'ingiz (Docker Hub, GHCR) yoki AWS ECR (private repozitoriy, kirish IAM orqali).

```
aws ecr get-login-password --region "$AWS_REGION" | docker login \
  --username AWS --password-stdin 123456789012.dkr.ecr.$AWS_REGION.amazonaws.com
```

ECR ishlatilsa serverga access key kerak emas: instansga `AmazonEC2ContainerRegistryReadOnly` policy'li role biriktiriladi (3-dars, 21-vazifa).

Tag qoidalari:

- Har deploy noyob, o'zgarmas tag bilan: versiya (`1.4.2`) yoki git commit SHA. Compose faylda aniq tag yoziladi.
- `latest` ishlatilmaydi: serverda qaysi kod ishlayotganini aytib bo'lmaydi va rollback uchun "oldingi latest" yo'q.
- Oldingi versiya image'i registry'da va serverda saqlanadi: rollback bu eski tag'ni qaytarish.

**Tuzoq: arxitektura mos kelmasligi.** Ish mashinangiz `amd64`. Server ARM (`t4g`) bo'lsa image `exec format error` bilan yiqiladi. Server arxitekturasiga mos build qiling yoki `docker buildx build --platform` ishlating.

## 4. Reverse proxy, DNS va TLS

Dastur konteyneri to'g'ridan-to'g'ri internetga chiqarilmaydi. Oldida reverse proxy turadi: TLS'ni yechadi (termination), HTTP'ni HTTPS'ga yo'naltiradi, so'rovni ichki Docker tarmog'idagi konteynerga uzatadi, keyinchalik bir nechta dastur va nusxalarni bitta IP ortida ushlaydi.

| | Caddy | nginx |
|---|-------|-------|
| TLS | Avtomatik: sertifikatni o'zi oladi va yangilaydi | Alohida ACME mijoz (certbot) va yangilash jadvali kerak |
| Konfiguratsiya | Qisqa Caddyfile | Batafsil, hamma narsa aniq yoziladi |
| Qachon | Kichik va o'rta deploy, tez boshlash | Keng tarqalgan, mavjud tizimlarda ko'p uchraydi, nozik sozlash |

Bu darsda asosiy yo'l Caddy, nginx va certbot varianti alohida vazifada.

```
app.example.com {
    reverse_proxy app:8080
}
```

```yaml
services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
volumes:
  caddy_data:
```

`caddy_data` volume'da sertifikatlar va ACME akkaunt kaliti saqlanadi. Volume'siz har qayta yaratishda yangi sertifikat so'raladi va rate limit'ga urilasiz.

### DNS

Subdomen uchun `A` yozuv Elastic IP ga qaratiladi. TTL'ni laboratoriyada past qo'ying (masalan 300 soniya). Tekshirish: `dig +short A app.example.com`. Yozuv tarqalmaguncha TLS so'rash foydasiz.

### Let's Encrypt qanday ishlaydi

Let's Encrypt bepul sertifikat beradi, ACME protokoli orqali. HTTP-01 tekshiruvida CA domeningizning 80-portiga so'rov yuboradi va server ACME mijoz qo'ygan tokenni qaytarishi kerak: shu bilan domen sizniki ekani isbotlanadi. Demak sertifikat olish uchun: DNS serverga qaragan, 80-port internetdan ochiq (security group!), proxy ishlab turibdi.

- Sertifikatlar qisqa muddatli, shuning uchun yangilash faqat avtomatik bo'ladi. Qo'lda yangilanadigan sertifikat bir kuni albatta unutiladi.
- Production CA'da rate limit bor (https://letsencrypt.org/docs/rate-limits/). Sozlashni **staging** muhitida sinang: Caddyfile global bloki `{ acme_ca https://acme-staging-v02.api.letsencrypt.org/directory }`. Staging sertifikatiga brauzer ishonmaydi, bu kutilgan holat.
- DNS hali tarqalmagan paytda serverni tekshirish: `curl --resolve app.example.com:443:<EIP> https://app.example.com/healthz`.

**Tuzoq: 80-portni "kerak emas" deb yopish.** HTTP-01 tekshiruvi va HTTP'dan HTTPS'ga yo'naltirish 80-portda ishlaydi. Yopilsa birinchi sertifikat olinmaydi yoki bir necha haftadan keyin yangilanish jim to'xtaydi.

## 5. Ishga tushirish va qayta ko'tarish

Server qayta yuklanganda yoki jarayon yiqilganda dastur odam aralashuvisiz ko'tarilishi shart. Ikki mexanizm:

**Docker restart policy** (asosiy yo'l). Docker daemon systemd servisi sifatida boot'da ishga tushadi va restart policy'li konteynerlarni ko'taradi.

| Policy | Xulq |
|--------|------|
| `no` | Qayta ishga tushirilmaydi (standart) |
| `on-failure` | Faqat noldan farqli exit code bilan chiqsa |
| `always` | Har doim; qo'lda to'xtatilgan bo'lsa ham daemon restart'ida ko'tariladi |
| `unless-stopped` | Har doim, qo'lda to'xtatilganidan tashqari |

**systemd unit** compose loyihasini boshqaradi: boot tartibi va bog'liqliklarni aniq yozish kerak bo'lsa.

```
[Unit]
Description=app stack
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/app
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
```

Bittasini tanlang. Restart policy "jarayon o'ldi" holatini yopadi, lekin "jarayon tirik, javob bermayapti" holatini yopmaydi: buning uchun compose'da `healthcheck` va tashqi monitoring kerak (monitoring modulida). `depends_on` da `condition: service_healthy` dastur database tayyor bo'lguncha kutishini ta'minlaydi.

**Tuzoq: crash loop.** Noto'g'ri konfiguratsiya bilan `restart: always` konteynerni cheksiz qayta ishga tushiradi. `docker compose ps` da `Restarting` holati va loglardagi takrorlanuvchi xato shuning belgisi.

## 6. Konfiguratsiya va secret'lar

Tamoyil (twelve-factor): bir xil image hamma muhitda, farq faqat konfiguratsiyada, konfiguratsiya environment'dan.

- Secret image ichiga tushmaydi (`ENV`, `COPY .env`): image layer'laridan o'qiladi.
- Secret git'da yo'q. Repozitoriyda faqat `.env.example` (kalit nomlari, qiymatsiz).
- Serverda `/opt/app/.env`, egasi deploy foydalanuvchisi, `chmod 600`, compose'da `env_file: .env`.
- AWS credential serverda umuman yo'q: S3 va ECR ga instance role orqali.

Chegaralari: environment o'zgaruvchilari `docker inspect` da va konteyner ichidagi `/proc/1/environ` da ko'rinadi, ya'ni `docker` group'dagi har kim o'qiydi. Keyingi qadam secret omborlari: AWS SSM Parameter Store (`aws ssm get-parameter --name ... --with-decryption`) yoki Secrets Manager, ulardan deploy paytida o'qib olinadi. Bu darsda `.env` fayl yetarli, lekin secret'lar qayerda turgani va qanday almashtirilishi runbook'da yozilishi shart.

## 7. Loglar

Konteynerdagi dastur stdout va stderr ga yozadi, fayllarga emas. Docker ularni standart `json-file` driver bilan diskka saqlaydi: `docker compose logs -f --tail 100 app`.

**Tuzoq: `json-file` standart holatda cheklanmagan.** Loglar disk to'lguncha o'sadi, disk to'lgach database yoza olmaydi va hamma narsa yiqiladi. Har servisga rotation qo'ying:

```yaml
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Server yo'qolsa loglar ham yo'qoladi. Markaziy log yig'ish monitoring modulida, bu yerda bilishingiz kerak bo'lgani: loglar qayerda, qancha joy oladi, proxy access log'i va dastur log'i alohida.

## 8. Yangilash, rollback va uzilish

Sodda yangilash: compose faylda tag'ni o'zgartirish, `docker compose pull`, `docker compose up -d`. Compose o'zgargan servisni to'xtatadi va yangisini yaratadi. Shu oraliqda (soniyalar) so'rovlar xato oladi. Bu single-node deploy'ning tabiiy narxi.

Uzilishni kamaytirish, oddiydan murakkabga:

1. **Graceful shutdown**: dastur `SIGTERM` olganda yangi so'rov qabul qilishni to'xtatib, joriylarini tugatadi. Docker `stop_grace_period` (standart 10 soniya) dan keyin `SIGKILL` yuboradi.
2. **Health check va proxy retry**: proxy tayyor bo'lmagan upstream'ga so'rovni qayta urinadi (Caddy'da `reverse_proxy` ichida `lb_try_duration`), qisqa uzilish foydalanuvchiga kechikish bo'lib ko'rinadi.
3. **Ikki nusxa**: dasturning ikki konteyneri proxy ortida, navbat bilan yangilanadi (rolling).
4. **Blue-green**: yangi versiya yonma-yon ko'tariladi, health tekshiriladi, proxy unga o'tkaziladi (`caddy reload`), eskisi bir muddat rollback uchun turadi.

Qaysi usul bo'lmasin, eski va yangi versiya bir muddat bitta database bilan ishlaydi. Shuning uchun sxema migratsiyalari orqaga mos bo'lishi kerak (avval ustun qo'shiladi va kod yangilanadi, eski ustun keyingi relizda o'chiriladi). Aks holda rollback imkonsiz bo'ladi.

**Rollback** bu oldindan tayyorlangan buyruq, vahima paytidagi ijod emas: oldingi tag'ni qaytarish va `up -d`. Runbook'da yozilgan va kamida bir marta sinalgan bo'lishi kerak.

## 9. Backup

Holat uch joyda: database volume, foydalanuvchi yuklagan fayllar (bo'lsa, ular boshidan S3 da turgani ma'qul), konfiguratsiya (`.env`, compose, Caddyfile). Image backup qilinmaydi, u registry'da.

Database uchun mantiqiy dump va S3:

```
docker compose exec -T db pg_dump -U app appdb | gzip \
  | aws s3 cp - "s3://my-backups/db/$(date +%F-%H%M).sql.gz"
```

- Server S3 ga instance role orqali yozadi. Role faqat `PutObject` ga ega bo'lsa, buzib kirilgan server eski backup'larni o'qiy ham, o'chira ham olmaydi.
- Bucket: Block Public Access yoqilgan, versioning, eski backup'lar uchun lifecycle (3-dars).
- Jadval: systemd timer yoki cron (linux moduli). Backup skripti xato bilan tugasa buni kimdir bilishi kerak.
- **Tiklab ko'rilmagan backup backup emas.** Dump'ni toza database'ga tiklash muntazam sinaladi.

Ikki ko'rsatkich: **RPO** (qancha ma'lumot yo'qotishga rozimiz: backup oralig'i) va **RTO** (qancha vaqtda tiklaymiz: toza serverda qayta deploy va restore vaqti). EBS snapshot butun diskni saqlaydi, lekin ishlab turgan database uchun izchil (consistent) bo'lmasligi mumkin va alohida haq oladi, mantiqiy dump o'rnini bosmaydi.

## 10. Hardening

Minimal ro'yxat, qatlamlar bo'yicha:

| Qatlam | Chora |
|--------|-------|
| Security group | 22 faqat ma'lum IP'dan, 80 va 443 ochiq, qolgan hammasi yopiq |
| SSH | Faqat kalit (`PasswordAuthentication no`), root login yo'q (`PermitRootLogin no`). Tekshirish: `sudo sshd -T`. O'zgartirish `/etc/ssh/sshd_config.d/` da, `sudo sshd -t` bilan sinab, keyin reload |
| Yangilanishlar | `unattended-upgrades` xavfsizlik yangilanishlarini o'zi o'rnatadi. `/var/run/reboot-required` paydo bo'lsa reboot rejalashtiriladi |
| Konteynerlar | Root bo'lmagan `USER`, faqat proxy port publish qiladi, database `ports` siz, image'lar muntazam yangilanadi |
| IAM | Instance role minimal: faqat backup bucket'iga yozish va registry'dan o'qish |
| Fayllar | `.env` `600`, serverda ortiqcha kalit va repozitoriy nusxasi yo'q |

SSH'ni butunlay yopish ham mumkin: AWS Systems Manager Session Manager IAM orqali kirish beradi, 22-port ochilmaydi.

**Tuzoq: Docker va host firewall.** Docker `ports:` bilan chiqarilgan portlar uchun o'z iptables qoidalarini yozadi va ular `ufw` qoidalaridan oldin ishlaydi: `ufw deny 5432` ga qaramay `ports: ["5432:5432"]` internetga ochiq bo'ladi. Himoya: keraksiz portni publish qilmaslik, zarur bo'lsa `127.0.0.1:5432:5432`, va tashqi qatlam sifatida security group.

**Tuzoq: SSH sozlamasini sinamasdan yopish.** `sshd` konfiguratsiyasini o'zgartirgach joriy sessiyani yopmang, yangi terminaldan kirib ko'ring. Aks holda serverdan o'zingizni qulflab qo'yasiz.

## 11. Managed variantlar

Yuqoridagi ishlarning katta qismini platformaga topshirish mumkin. Bu darsda faqat tushuncha darajasida, amaliyotsiz.

| Xizmat | Nima | Siz berasiz | Platforma qiladi | Qachon |
|--------|------|-------------|------------------|--------|
| Lightsail | Soddalashtirilgan VPS, oldindan ma'lum oylik narx | Hamma narsa, 2–10-bo'limlardagi kabi | Sodda konsol, paket narx | Developer cloud uslubidagi oddiy server kerak bo'lsa |
| Elastic Beanstalk | Klassik PaaS, EC2 ustida | Kod yoki image, konfiguratsiya | Instans, load balancer, autoscaling, deploy strategiyalari | Standart web dastur, EC2 ko'rinib tursin desangiz |
| App Runner | Konteyner PaaS | Image yoki repozitoriy | Build, TLS, scaling, load balancing | Bitta stateless servisni eng kam sozlama bilan |
| ECS va Fargate | Konteyner orkestratori, Fargate bilan serversiz | Task definition, tarmoq, IAM | Konteynerni joylash, qayta ko'tarish, rolling deploy; Fargate'da server yo'q | Bir nechta servis, production, Kubernetes'siz |

Xizmatlar ro'yxati va yangi mijozlar uchun mavjudligi o'zgarib turadi, tanlashdan oldin har birining hujjat sahifasini tekshiring. 1-darsdagi savdolashuv bu yerda aniq ko'rinadi: yuqoriroq variantda OS patch, TLS yangilash, qayta ko'tarish va rolling deploy platformada, evaziga narx yuqoriroq, nazorat kamroq, debug faqat log orqali. Database har qanday holatda alohida hal qilinadi (managed: RDS).

Boshqa provayderlardagi mosliklar:

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| VM'da qo'lda deploy | EC2 | Compute Engine | Virtual Machines | Droplet | Server |
| Sodda VPS | Lightsail | yo'q | yo'q | Droplet | Server |
| Konteyner PaaS | App Runner | Cloud Run | Container Apps | App Platform | yo'q |
| Konteyner registry | ECR | Artifact Registry | Container Registry | Container Registry | yo'q |
| Secret ombori | Secrets Manager, SSM Parameter Store | Secret Manager | Key Vault | yo'q (env) | yo'q |
| Backup ombori | S3 | Cloud Storage | Blob Storage | Spaces | Object Storage |

Bu darsdagi 2–10-bo'limlar har qanday provayderdagi Ubuntu serverda o'zgarishsiz ishlaydi. Faqat instance role va S3 qismi provayderga xos.

## Tuzoqlar

- `latest` tag bilan deploy: serverda nima ishlayotgani noma'lum, rollback yo'q.
- Database portini `ports:` bilan chiqarish va `ufw` himoya qiladi deb o'ylash.
- Sertifikat volume'ini saqlamaslik va production CA'da tajriba qilib rate limit'ga urilish.
- 80-portni yopib sertifikat yangilanishini jim sindirish.
- Log rotation'siz `json-file`: disk to'ladi, database yiqiladi.
- Secret'ni image'ga, git'ga yoki user data'ga yozish; serverga access key qo'yish (role o'rniga).
- Backup bor, lekin hech qachon tiklab ko'rilmagan; backup o'sha serverning o'zida turadi.
- Rollback rejasiz deploy va orqaga mos bo'lmagan migratsiya.
- Serverni qo'lda sozlab, qadamlarni hech qayerga yozmaslik: server yo'qolsa bilim ham yo'qoladi.
- Juma kechqurun deploy qilish va tashqaridan tekshirmaslik (`curl` serverning o'zidan emas, internetdan).

## Manbalar

- https://docs.docker.com/engine/install/ubuntu/ – Docker Engine'ni Ubuntu'ga o'rnatish
- https://docs.docker.com/engine/containers/start-containers-automatically/ – restart policy'lar
- https://docs.docker.com/engine/logging/drivers/json-file/ – json-file log driver va rotation
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker, iptables va ufw
- https://docs.docker.com/reference/compose-file/ – Compose file reference
- https://caddyserver.com/docs/automatic-https – Caddy avtomatik HTTPS (majburiy)
- https://caddyserver.com/docs/caddyfile/directives/reverse_proxy – `reverse_proxy` direktivasi
- https://nginx.org/en/docs/http/ngx_http_proxy_module.html va https://certbot.eff.org/ – nginx proxy va certbot
- https://letsencrypt.org/how-it-works/ va https://letsencrypt.org/docs/challenge-types/ – ACME va challenge turlari
- https://letsencrypt.org/docs/rate-limits/ va https://letsencrypt.org/docs/staging-environment/ – rate limit va staging
- https://12factor.net/ – The Twelve-Factor App (config, logs, disposability bo'limlari)
- https://www.postgresql.org/docs/current/backup-dump.html – `pg_dump` va tiklash
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html – ECR bilan ishlash
- https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html – Session Manager
- https://docs.aws.amazon.com/decision-guides/latest/containers-on-aws-how-to-choose/choosing-aws-container-service.html – AWS'da konteyner xizmatini tanlash
- https://sre.google/sre-book/table-of-contents/ – Google SRE Book (release engineering va runbook madaniyati)

---

## Vazifalar

Vazifalarni `cloud/04-deployment/` papkasida bajaring (`make new m=cloud n=04 name=deployment` bilan yaratiladi). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. So'ralgan fayllar (`compose.yaml`, `Caddyfile`, skriptlar, unit fayllar, `RUNBOOK.md`) shu papkada saqlanadi. `.env`, kalitlar, account ID va haqiqiy secret'lar commit qilinmaydi, faqat `.env.example`.

### A. Server va image

1. **Preflight and plan.** `aws sts get-caller-identity`, budget'lar, `leftovers.sh` natijasini tekshiring. Bu darsda yaratiladigan har resursni jadvalga yozing: nomi, nima uchun kerak, pullikmi, narx sahifasi havolasi, qachon o'chiriladi. 1-bo'limdagi sxemani o'z dasturingiz, domeningiz va portlaringiz bilan qayta chizing.

2. **Provision the server.** CLI bilan yarating: security group (22 sizning IP'dan, 80 va 443 hamma joydan), Ubuntu 24.04 instans (eng kichik tip, 3-darsdagi key pair), Elastic IP. Docker Engine'ni rasmiy qo'llanma bo'yicha o'rnatadigan user data skriptini (`user-data.sh`) yozing. Instans tayyor bo'lgach `docker version`, `docker compose version`, `systemctl is-enabled docker` natijalarini ko'rsating. Buyruqlarni `provision.sh` ga yig'ing.

3. **Ship the image.** Dasturingiz image'ini server arxitekturasiga mos qilib, versiya tag'i bilan build qiling va registry'ga push qiling (ECR yoki docker modulidagi registry). ECR bo'lsa: repozitoriy yarating, instansga faqat o'qish huquqli role biriktiring va serverda access key'siz `docker pull` qiling. Boshqa registry bo'lsa: serverda login credential'i qayerda saqlanishini va uning xavfini yozing. Keyin ataylab boshqa arxitektura uchun (`--platform` bilan, masalan server `amd64` bo'lsa `linux/arm64`) sinov tag'i bilan build va push qilib serverda ishga tushiring: xatoni yozing, `docker image inspect` da arxitektura qayerda ko'rinishini ko'rsating va sinov tag'ini o'chiring.

### B. Proxy, DNS, TLS

4. **Run the stack.** Serverda `/opt/app/` ichida `compose.yaml` yozing: dastur, PostgreSQL (volume bilan, port publish qilinmagan), Caddy. Hamma servisda restart policy, dasturda `healthcheck`, dastur database'ni `service_healthy` sharti bilan kutadi. Hozircha Caddy'da domen o'rniga `:80` ishlating. Ish mashinasidan `curl http://<EIP>/healthz` ishlashini ko'rsating. `docker compose ps` va serverda `sudo ss -tlnp` natijasida qaysi portlar tashqariga ochiq?

5. **DNS record.** Subdomeningiz uchun `A` yozuvni Elastic IP ga qarating. `dig +short`, `dig +trace` va boshqa resolver (`@1.1.1.1`, `@8.8.8.8`) bilan tekshiring. TTL qancha? Yozuvni o'zgartirsangiz eski qiymat qancha vaqt kesh'da qolishi mumkin va bu deploy paytida IP almashtirishga qanday ta'sir qiladi?

6. **TLS with staging.** Caddyfile'da domeningizni yozing va global blokda Let's Encrypt staging CA'ni ko'rsating. Caddy loglarida sertifikat olish jarayonini kuzating va bosqichlarini (challenge turi, tekshiruv, sertifikat) o'z so'zingiz bilan yozing. `curl -v https://...` nima deydi va nima uchun? `openssl s_client -connect <domain>:443 -servername <domain>` bilan issuer'ni ko'rsating.

7. **Break the challenge.** Staging rejimida qoling. Caddy volume'ini o'chirib (sertifikat qaytadan so'ralsin), security group'dan 80-portni olib tashlang va stack'ni qayta ko'taring. Caddy logidagi xatoni to'liq o'qing: kim kimga ulana olmadi? 80-portni qaytaring va tiklanishini kuzating. Xuddi shu xato production'da sertifikat yangilanadigan kuni qanday ko'rinishda paydo bo'lar edi?

8. **Production certificate.** Staging qatorini olib tashlab haqiqiy sertifikat oling. `curl -I http://...` (redirect), `curl -I https://...`, sertifikatning amal qilish muddati va issuer'ini ko'rsating. Stack'ni `down` va `up` qiling: sertifikat qayta so'raldimi, nima uchun yo'q? Rate limit sahifasidan bitta domen uchun sizga tegishli ikkita limitni yozing.

9. **nginx and certbot.** Qiyoslash uchun. Vaqtincha Caddy o'rniga nginx konteynerini reverse proxy qiling: `proxy_pass`, `Host` va `X-Forwarded-*` header'lari, HTTP'dan HTTPS'ga redirect. Sertifikatni certbot hujjatidagi usullardan biri bilan (staging'da, `--dry-run` yoki `--test-cert`) oling. Yangilanish qanday rejalashtiriladi va nginx yangi sertifikatni qanday o'qiydi? Caddy bilan solishtirganda qaysi ishlarni o'zingiz qilishingizga to'g'ri keldi? Oxirida Caddy'ga qayting. `nginx.conf` ni papkada saqlang.

### C. Ekspluatatsiya

10. **Survive a reboot.** Uch sinov o'tkazing va har biridan keyin tashqaridan `curl` bilan tekshiring: (a) dastur jarayonini `docker kill` bilan o'ldirish, (b) `sudo systemctl restart docker`, (c) `sudo reboot`. Har holatda xizmat qancha vaqtda qaytdi (`while` sikli va `curl` bilan o'lchang)? Keyin dastur servisini `restart: "no"` qilib (c) ni takrorlang va farqni ko'rsating. Ixtiyoriy: 5-bo'limdagi systemd unit bilan xuddi shu sinovlar.

11. **Crash loop.** `.env` da database parolini ataylab noto'g'ri qiling va stack'ni qayta ko'taring. `docker compose ps`, `docker compose logs`, `docker inspect` dagi `RestartCount` bilan nima bo'layotganini aniqlang. Tashqaridan foydalanuvchi nimani ko'radi (proxy qanday status qaytaradi)? Tuzating.

12. **Secrets handling.** Serverda `.env` egasi va huquqlarini tekshiring. Secret'ni uch joydan o'qib ko'rsating: `docker inspect`, `docker compose exec app env`, `/proc/<pid>/environ` (host'dan). Kim bularni o'qiy oladi? `docker history` bilan image'ingizda secret yo'qligini isbotlang. Database parolini almashtirish (rotation) tartibini qadam-baqadam yozing va bajaring: qaysi nuqtada uzilish bo'ldi?

13. **Logs and disk.** Log rotation'siz konteynerda `docker inspect --format '{{.LogPath}}'` bilan log faylini toping. Dasturga sikl bilan bir necha ming so'rov yuborib fayl o'sishini ko'rsating. Hamma servisga `max-size` va `max-file` qo'ying, qayta yarating va rotation ishlashini isbotlang. `df -h` va `docker system df` natijasini yozing: diskni yana nima egallaydi va qanday tozalanadi?

14. **Deploy and rollback.** Dasturda ko'rinadigan o'zgarish qiling (masalan `/version` javobi), yangi tag bilan push qiling. Ish mashinasida `while true; do curl -s -o /dev/null -w '%{http_code}\n' https://<domain>/healthz; sleep 0.2; done` ishlab turganda serverda yangilang. Nechta so'rov xato oldi, qanday kodlar bilan? Keyin oldingi tag'ga rollback qiling va vaqtini o'lchang. Yangilash va rollback buyruqlarini `deploy.sh <tag>` skriptiga yozing: tag'ni almashtiradi, pull qiladi, ko'taradi, health endpoint javob berguncha kutadi, bermasa xato kodi bilan chiqadi.

15. **Reduce downtime.** 14-vazifadagi uzilishni kamaytiring. Kamida ikkitasini qo'llang: dasturda graceful shutdown (`SIGTERM`), Caddy'da upstream retry, dasturning ikki nusxasi va navbat bilan yangilash, blue-green almashtirish. 14-vazifadagi o'lchovni takrorlang va natijalarni jadvalda solishtiring. Nolga tushdimi? Tushmagan bo'lsa qolgan uzilish qayerdan kelyapti? Bitta serverda bu yondashuvning chegarasi nima?

16. **Backup to S3.** Backup uchun bucket yarating (Block Public Access, versioning, 30 kundan eski backup'larni o'chiradigan lifecycle). Instans role'iga faqat shu bucket'ning `db/` prefiksiga `s3:PutObject` beradigan policy (`backup-policy.json`) qo'shing. `backup.sh` yozing: `pg_dump`, siqish, S3 ga yuklash, xato bo'lsa noldan farqli exit code. Uni systemd timer bilan kuniga bir marta ishlaydigan qiling (`backup.service`, `backup.timer`), `systemctl list-timers` va qo'lda ishga tushirilgan natijani ko'rsating. Serverdan backup'ni o'qish yoki o'chirishga urinib ko'ring: nima bo'ladi va bu nima uchun yaxshi?

17. **Restore drill.** Database'ga bir nechta taniqli yozuv qo'shing, backup oling, keyin database volume'ini butunlay o'chiring (`docker compose down`, `docker volume rm`). Ish mashinasidagi admin profil bilan oxirgi dump'ni olib, toza database'ga tiklang va yozuvlar qaytganini ko'rsating. Tiklash qancha vaqt oldi (RTO)? Backup jadvalingiz bo'yicha eng yomon holatda qancha ma'lumot yo'qoladi (RPO)? Tiklash buyruqlarini `restore.sh` ga yozing.

18. **Hardening pass.** Tekshiring va kerak bo'lsa tuzating, har biriga dalil keltiring: `sudo sshd -T` da parol va root login o'chirilgan; `unattended-upgrades` yoqilgan va oxirgi ishlagan vaqti; `apt list --upgradable` va reboot kerakligi; konteynerlar root bo'lmagan foydalanuvchida (`docker compose exec app id`); tashqi skaner natijasi (ish mashinasidan `nmap -Pn <EIP>` faqat o'zingizning serveringizga). Keyin tajriba: database'ga `ports: ["5432:5432"]` qo'shing, serverda `ufw` ni yoqib (avval `ufw allow OpenSSH`!) `ufw deny 5432` qiling, security group'da 5432 ni vaqtincha o'z IP'ingizga oching va tashqaridan ulanib ko'ring. Natijani izohlang, hammasini qaytaring.

### D. Managed variantlar va mini-loyiha

19. **Managed comparison.** Amaliyotsiz, hujjat asosida. Shu dasturni ECS Fargate (database RDS da) va App Runner yoki Elastic Beanstalk'da ishlatish uchun jadval tuzing: bu darsda qo'lda qilgan har ish (server patch, TLS, restart, deploy, rollback, loglar, backup, secret'lar) har variantda kimda qoladi va qaysi AWS xizmati bajaradi. Pricing Calculator'da uch variantning oylik narxini taxminlang (havola va sana bilan). Qaysi sharoitda qaysi birini tanlar edingiz? Tanlangan xizmatlarning hozir yangi mijozlar uchun ochiqligini hujjatdan tekshirib yozing.

20. **Runbook.** Mini-loyiha, 1-qism. `RUNBOOK.md` yozing: shu serverni va dasturni hech qachon ko'rmagan muhandis faqat shu hujjat bilan ishlay olsin. Bo'limlar: arxitektura sxemasi va resurslar ro'yxati; toza akkauntdan to'liq deploy (buyruqlar tartib bilan, skriptlaringizga havola); yangi versiya chiqarish va rollback; secret'lar qayerda va qanday almashtiriladi; backup va tiklash (RPO, RTO raqamlaringiz bilan); loglar qayerda; sertifikat qanday yangilanadi va muddati qanday tekshiriladi; besh nosozlik ssenariysi (sayt ochilmayapti, 502, disk to'ldi, sertifikat muddati o'tdi, server yo'qoldi) uchun tashxis qadamlari; to'liq teardown.

21. **Rebuild from the runbook.** Mini-loyiha, 2-qism. Runbook'ni sinang: joriy instansni terminate qiling (Elastic IP va backup bucket qolsin), faqat `RUNBOOK.md` va skriptlaringizga qarab yangi instansda hammasini qayta ko'taring va database'ni backup'dan tiklang. Vaqtni o'lchang. Runbook'da yo'q bo'lib, xotiradan qilgan har qadamingizni yozib boring va runbook'ni to'ldiring. Yakunda: sayt HTTPS bilan ishlaydi, ma'lumot joyida, `curl` natijasi `README.md` da.

22. **Teardown and proof.** Mini-loyiha, 3-qism. Runbook'ning teardown bo'limi bo'yicha hammasini o'chiring: instans, Elastic IP, security group, IAM role va instance profile, policy'lar, ECR repozitoriy (image'lari bilan), backup bucket (hamma versiyalari bilan), DNS yozuvi. `leftovers.sh` ga ECR repozitoriylar va IAM role'lar tekshiruvini qo'shing, natijasi bo'sh bo'lsin. Ertasi kuni Bills sahifasidan bu dars qanchaga tushganini xizmatlar bo'yicha yozing va 1-vazifadagi rejangiz bilan solishtiring.

### Topshirish

Tayyor bo'lgach:
1. `README.md` da 22 ta vazifa; `compose.yaml`, `Caddyfile`, `nginx.conf`, `.env.example`, `user-data.sh`, `provision.sh`, `deploy.sh`, `backup.sh`, `restore.sh`, unit fayllar, `backup-policy.json`, `RUNBOOK.md` papkada.
2. 21-vazifa bajarilgan: runbook toza serverda sinalgan va to'ldirilgan.
3. Hamma resurs o'chirilgan, `leftovers.sh` natijasi bo'sh va `README.md` ga qo'yilgan, DNS yozuvi olib tashlangan.
4. Repozitoriyda `.env`, kalit, parol, account ID yo'q. `make check` toza.
5. Menga xabar bering: fayllar va runbook'ni o'qib chiqaman. Bu modulning yakuniy topshirig'i.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Foydalanuvchi so'rovi brauzerdan dastur konteynerigacha qaysi qatlamlardan o'tadi? Har birida nima buzilishi mumkin?
- Nima uchun `latest` tag bilan deploy qilinmaydi?
- Let's Encrypt HTTP-01 tekshiruvi qanday ishlaydi va u uchun qaysi uch narsa to'g'ri bo'lishi kerak?
- Restart policy qaysi nosozlikni yopadi, qaysisini yopmaydi?
- Secret'ni environment o'zgaruvchisi orqali berishning chegarasi nima? Serverda nima uchun AWS access key bo'lmasligi kerak?
- `docker compose up -d` bilan yangilashda uzilish qayerdan keladi va uni qanday kamaytirasiz?
- Nima uchun migratsiyalar orqaga mos bo'lishi kerak?
- RPO va RTO nima? Sizning deploy'ingizda ular qancha va nimaga bog'liq?
- `ufw` Docker publish qilgan portni nima uchun to'smaydi va haqiqiy himoya nima?
- Qo'lda deploy'ning qaysi qadamlari xatoga eng moyil va keyingi modullarda (CI/CD, Terraform) qaysi biri ularni yopadi?
