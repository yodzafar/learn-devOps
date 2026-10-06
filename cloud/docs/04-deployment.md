# 4-dars: Dasturlarni serverga joylash (deployment)

Maqsad: konteynerlangan web dasturni toza virtual mashinaga qo'lda, boshidan oxirigacha deploy qilish: server tayyorlash, image yetkazish, reverse proxy, DNS, TLS, secret'lar, loglar, yangilash va rollback, backup, hardening. Deploy (joylash) degani yozilgan kodni foydalanuvchi internetdan ocha oladigan holatga keltirish va shu holatda ushlab turish. Bu dars oldingi hamma modullarni birlashtiradi: linux (systemd, ssh, foydalanuvchilar), network (DNS, TLS, portlar), docker (image, registry, Compose) va shu modulning 2–3-darslari (IAM role, EC2, security group, S3). Vercel yoki Netlify'da `git push` qilganingizda platforma build qiladi, artifact saqlaydi, uni ishga tushiradi, domenni ulaydi, sertifikat oladi va log yig'adi. Bu darsda shu ko'rinmas qadamlarning har birini o'z qo'lingiz bilan bajarasiz. Deploy ataylab qo'lda qilinadi: CI/CD va Terraform keyingi modullarda keladi va aynan shu qadamlarni avtomatlashtiradi. Qo'lda bir marta qilmagan odam pipeline buzilganda nima buzilganini tushunmaydi. Dars oxirida managed variantlar (ECS/Fargate, App Runner, Elastic Beanstalk, Lightsail) tushuncha darajasida ko'riladi va modul mini-loyihasi topshiriladi.

Taxminiy vaqt: 8 kun (siz uchun). 1-kun: 1–3-bo'limlar va 1–3-vazifalar (server va image). 2-kun: 4-bo'lim, "Birga bajaramiz", 4–5-vazifalar. 3-kun: 6–9-vazifalar (TLS, nginx). 4-kun: 5–7-bo'limlar va 10–13-vazifalar. 5-kun: 8-bo'lim va 14–15-vazifalar. 6-kun: 9–10-bo'limlar va 16–18-vazifalar. 7-kun: 11-bo'lim, 19–20-vazifalar (runbook). 8-kun: 21–22-vazifalar (toza serverda qayta deploy va teardown). Diqqatni quyidagilarga qarating: so'rov foydalanuvchidan konteynergacha qaysi qatlamlardan o'tadi, deploy paytida uzilish qayerdan keladi, tiklab ko'rilmagan backup nima uchun backup emas, server yo'qolsa qayta qurish uchun nima yozib qo'yilgan bo'lishi kerak.

Qanday o'qish kerak: har bo'limdagi misolni o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Sizdagi ID, IP, domen, vaqt va versiyalar farq qiladi, bunday joylar `<...>` bilan belgilangan. Har buyruq oldidan qayerda turganingizni prompt'dan tekshiring: host'dami yoki serverda. Har bo'lim oxiridagi "Nima uchun shunday" qismi qoidaning sababini aytadi.

## Laboratoriya

Bu darsda uch "joy" bor:

| Joy | Prompt | Nima bajariladi |
|-----|--------|-----------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` | `aws`, `docker build` va `push`, `ssh`, `scp`, `curl`, `dig`, repo (`make`, `git`) |
| EC2 instans (server) | `ubuntu@ip-<...>:~$` | Linux'ga xos hamma narsa: Docker Engine, Compose stack, `systemctl`, `journalctl`, `ss`, `ufw`, `apt` |
| Registry | prompt yo'q | image'lar saqlanadi: ECR yoki docker modulida ishlatgan registry'ingiz (Docker Hub, GHCR) |

- **Cloud akkaunt**: AWS, 2-darsdagi admin profil, 3-darsdagi region (faqat bitta region). Boshlashdan oldin: `aws sts get-caller-identity`, budget alert mavjud (`aws budgets describe-budgets --account-id <ACCOUNT_ID>`), 3-darsdagi `leftovers.sh` natijasi bo'sh.
- **Resurslar**: bitta EC2 instans (Ubuntu 24.04, eng kichik tip), bitta security group, bitta Elastic IP, bitta S3 bucket (backup), bitta IAM role, ixtiyoriy ravishda bitta ECR repozitoriy. Hammasida `project=devops-course` tag. NAT gateway, load balancer, RDS yaratilmaydi.
- **Instans tipi**: eng kichigidan boshlang. Xotira yetmasa bir pog'ona kattasiga o'ting va narxini https://aws.amazon.com/ec2/pricing/on-demand/ dan tekshiring. Instans arxitekturasi (`x86_64` yoki `arm64`) image arxitekturasini belgilaydi, bu 3-bo'limda.
- **Domen**: TLS uchun DNS nomi kerak. O'z domeningiz bo'lsa registratordagi DNS'da subdomen uchun `A` yozuv yetarli (Route 53 hosted zone alohida haq oladi, shart emas). Domen bo'lmasa bepul dinamik DNS xizmatidan subdomen oling (masalan https://www.duckdns.org/).
- **Dastur**: docker modulida yozgan konteynerlangan web dasturingiz, PostgreSQL bilan. Talablar: HTTP port, health endpoint (masalan `/healthz`), konfiguratsiya environment o'zgaruvchilaridan, `SIGTERM` da to'g'ri to'xtash.
- **Xarajat**: instans, disk, public IPv4 va S3 bir necha kun ishlaydi. Har mashg'ulot oxirida instansni stop qiling: hisoblash haqi to'xtaydi, lekin disk (EBS volume) va Elastic IP haqi davom etadi. Elastic IP'siz instansning public IPv4 manzili har stop va start'da o'zgaradi, Elastic IP esa o'zgarmaydi, shuning uchun DNS yozuvi unga qaratiladi. Aniq narxlar rasmiy sahifada: https://aws.amazon.com/vpc/pricing/ va EC2 narx sahifasi. Darsni ketma-ket kunlarda tugating.
- **Dars oxirida**: hammasi o'chiriladi (DNS yozuvi ham), `leftovers.sh` bilan tekshiriladi (22-vazifa).
- **Server ichidagi hamma o'zgarish** (paket, user, sshd, systemd, firewall, Docker o'rnatish) faqat EC2 instansda. Ish mashinasida faqat `aws`, `ssh`, `scp`, `curl`, `dig`, `docker build` va `docker push`.
- **Kalitlar va secret'lar**: SSH private key repodan tashqarida (`~/.ssh/`), huquqi `600`. Registry'ga `docker login --password-stdin` bilan kiriladi (parol shell tarixiga tushmaydi). Dastur secret'lari serverdagi `.env` faylda (`600`), git'da faqat `.env.example`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis, `amd64`) | `docker build` natijasi `linux/amd64`, `x86_64` instansda o'zgarishsiz ishlaydi. `arm64` image yig'ish uchun QEMU emulyatsiyasi alohida sozlanadi (3-bo'lim). `openssl` bu OpenSSL 3. `nmap` kerak bo'lsa `sudo apt install nmap`. |
| macOS (uy, `arm64`) | `docker build` natijasi `linux/arm64`, `x86_64` instansda `exec format error` beradi: `--platform linux/amd64` kerak (Docker Desktop emulyatsiyani o'zi beradi). `openssl` bu LibreSSL, chiqish formati biroz boshqacha. `ss`, `systemctl`, `ip` yo'q: ular faqat serverda. `nmap` kerak bo'lsa `brew install nmap`. |

Ikkinchi mashinada nimani takrorlash kerak. AWS akkaunt, instans, Elastic IP, DNS yozuvi va registry umumiy: ikkala mashinadan bir xil ko'rinadi. Mashinaga xos va git orqali hech qachon ko'chmaydigan narsalar:

- **AWS CLI profili**: har mashinada 2-darsdagi kabi alohida sozlangan.
- **SSH kaliti**: private key ko'chirilmaydi. Ikkinchi mashinada yangi kalit juftligi yarating (`ssh-keygen -t ed25519`, linux 10-dars) va uning public qismini birinchi mashinadan serverdagi `~/.ssh/authorized_keys` ga qo'shing.
- **Registry login**: `docker login` har mashinada alohida.
- **SSH manba IP'si**: security group'da 22-port faqat sizning IP'ingizga ochiq, ofis va uy IP'lari har xil. Mashg'ulot boshida IP'ni aniqlang va qoidani yangilang, eskisini olib tashlang:

```
curl -s https://checkip.amazonaws.com      # prints your current public IP
aws ec2 authorize-security-group-ingress --group-id sg-<...> \
  --protocol tcp --port 22 --cidr <MY_IP>/32
aws ec2 revoke-security-group-ingress --group-id sg-<...> \
  --protocol tcp --port 22 --cidr <OLD_IP>/32
```

SSH hech qachon `0.0.0.0/0` ga ochilmaydi. Hammaga ochiq portlar faqat 80 va 443.

---

## 1. Deploy bosqichlari va maqsadli arxitektura

### Bu nima

Deploy bitta buyruq emas, ketma-ket bosqichlar zanjiri. PaaS (Vercel, Netlify; 1-dars) bu zanjirni to'liq yashiradi, shuning uchun avval uni ochiq ko'rinishda yozib olamiz:

| Bosqich | Savol | Bu darsda | Vercel/Netlify'da ko'rinmas qadam |
|---------|-------|-----------|-----------------------------------|
| Build | Image qayerda yig'iladi | Ish mashinasida (keyin CI'da) | "Building" bosqichi |
| Ship | Image serverga qanday yetadi | O'zgarmas tag bilan registry orqali | build artifact'ini saqlash |
| Configure | Konfiguratsiya va secret qayerdan keladi | Serverdagi `.env` fayl | "Environment Variables" sahifasi |
| Run | Kim ishga tushiradi va qayta ko'taradi | Docker restart policy, Compose | runtime (funksiya yoki konteyner) |
| Route | Trafik qanday yetadi | DNS, Elastic IP, security group, reverse proxy, TLS | domen ulash va avtomatik HTTPS |
| Verify | Ishlayotganini qayerdan bilamiz | Health check, loglar | "Logs" va deploy holati |
| Recover | Buzilsa nima qilamiz | Rollback, backup, runbook | "Rollback to previous deployment" tugmasi |

Artifact bu build natijasi: ishga tushirishga tayyor, o'zgarmaydigan paket. Bu kursda artifact Docker image (docker 2-dars).

### Mexanizm: so'rov yo'li

```
user -> DNS (A record) -> Elastic IP -> security group (80, 443)
     -> reverse proxy container (TLS termination)
     -> app container (private Docker network)
     -> database container (volume) -> backup -> S3
```

Bitta server, uch konteyner, bitta Compose fayl. Bu "single-node" deploy: yuqori mavjudlik yo'q (1-dars: bitta AZ dagi bitta VM), lekin kichik loyihalarning katta qismi aynan shunday ishlaydi va har bir murakkabroq sxema shu qatlamlarning ko'paytirilgani. Har strelka alohida buzilishi mumkin bo'lgan nuqta: DNS noto'g'ri IP'ga qaragan, security group portni yopgan, proxy ishlamayapti, dastur yiqilgan, database javob bermayapti.

### Misol: bitta so'rovning qatlamlarini o'lchash

`curl` so'rovning har bosqichi qachon tugaganini ayta oladi. Host'da, tayyor sayt bilan:

```
$ curl -sS -o /dev/null \
    -w '%{remote_ip} %{http_code} dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n' \
    https://example.com/
<IP> 200 dns=<0.0NN> tcp=<0.NNN> tls=<0.NNN> total=<0.NNN>
```

Maydonlar bo'yicha: `remote_ip` DNS qaytargan va `curl` ulangan manzil (network 4-dars); `http_code` dastur qatlamining javobi; `dns` nom IP'ga aylangan vaqt; `tcp` TCP ulanish o'rnatilgan vaqt (shu yerda security group yoki firewall to'ssa, so'rov osilib qoladi); `tls` TLS handshake tugagan vaqt (sertifikat shu bosqichda tekshiriladi); `total` javob to'liq kelgan vaqt. Raqamlar soniyada va boshidan hisoblanadi, ya'ni har biri oldingisidan katta. O'z deploy'ingizda sayt ochilmasa aynan shu tartibda tekshirasiz: DNS, TCP, TLS, HTTP.

### Real ishda qachon kerak

- Nosozlikda "sayt ishlamayapti" degan xabarni qatlamga aylantirish: qaysi strelkada uzilgan.
- Yangi loyihada deploy sxemasini chizish: har bosqich uchun kim javobgar va qaysi asbob.
- CI/CD pipeline o'qiyotganda: undagi har job shu jadvaldagi bir bosqich.

### Nima uchun shunday

Bosqichlarning ajratilgani tarixiy tajriba natijasi. Ilgari kod serverga `scp` yoki FTP bilan ko'chirilib, o'sha yerda yig'ilar edi: har serverda natija biroz boshqacha chiqar, orqaga qaytish uchun eski fayllar qolmas edi. Build'ni Run'dan ajratish (bir marta yig'ilgan artifact hamma joyda bir xil ishlaydi) va konfiguratsiyani artifact'dan ajratish twelve-factor tamoyillarida yozilgan. Muqobili PaaS: bosqichlar o'sha-o'sha, faqat ularni platforma bajaradi va siz ularni ko'rmaysiz (11-bo'lim).

## 2. Serverni tayyorlash

### Bu nima

Toza EC2 instans bu faqat Ubuntu: unda Docker yo'q, dasturingiz haqida hech narsa bilmaydi. Tayyorlash uch ishdan iborat: tarmoq kirishini cheklash, container runtime o'rnatish, dastur fayllari uchun joy ajratish.

Instans 3-darsdagi kabi yaratiladi: Ubuntu 24.04, public subnet, Elastic IP, security group: 22 faqat sizning IP'dan, 80 va 443 hamma joydan. Database porti hech qachon ochilmaydi.

### Mexanizm

- **Docker Engine** rasmiy apt repozitoriysidan o'rnatiladi: https://docs.docker.com/engine/install/ubuntu/ (Compose plugin ham shu paketlar bilan keladi). Ubuntu'ning o'z repozitoriysidagi `docker.io` paketi eskiroq bo'lishi mumkin (linux 12-dars: uchinchi tomon repozitoriysi va uning kaliti).
- **User data** (3-dars) bu instans birinchi marta yuklanganda cloud-init root nomidan bir marta bajaradigan skript. O'rnatishni unga yozsangiz server yaratilganda tayyor bo'ladi va qayta yaratish bitta buyruqqa aylanadi. Uning logi serverda `/var/log/cloud-init-output.log` da.
- **Deploy foydalanuvchisi**: dastur bilan root emas, oddiy foydalanuvchi ishlaydi (Ubuntu AMI'da `ubuntu`). Uni `docker` group'ga qo'shish (`sudo usermod -aG docker ubuntu`, keyin qayta login) `sudo` siz `docker` ishlatish imkonini beradi. Lekin bu group a'zosi amalda root: konteynerga host fayl tizimini mount qila oladi. Bitta odamli laboratoriya serverida maqbul, ko'p foydalanuvchili serverda emas.

Serverdagi tuzilma:

```
/opt/app/
  compose.yaml
  Caddyfile
  .env          # chmod 600, not in git
```

Fayllar serverga `scp` bilan yetkaziladi (masalan `scp compose.yaml ubuntu@<EIP>:/opt/app/`). Serverda repozitoriy nusxasi va git credential'i saqlanmaydi.

### Misol: instans holati va arxitekturasi

Host'da:

```
$ aws ec2 describe-instances --instance-ids i-<...> \
    --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,Architecture]' \
    --output text
running	<EIP>	x86_64
```

Uch maydon: instans holati, public IPv4 manzil (Elastic IP biriktirilgan bo'lsa o'sha), CPU arxitekturasi. Keyin serverning o'zidan:

```
$ ssh -i ~/.ssh/<key> ubuntu@<EIP>
ubuntu@ip-<...>:~$ uname -m
x86_64
ubuntu@ip-<...>:~$ id -nG
ubuntu adm <...> sudo <...> docker
ubuntu@ip-<...>:~$ systemctl is-active docker
active
```

`uname -m` kernel ko'radigan arxitektura: `x86_64` bu Docker tilida `amd64`, `aarch64` bu `arm64` (docker 2-dars). `id -nG` joriy sessiyaning group'lari: `docker` ko'rinmasa, `usermod` dan keyin qayta login qilinmagan. `systemctl is-active` (linux 11-dars) Docker daemon ishlayotganini aytadi.

Mashg'ulot oxirida host'dan:

```
$ aws ec2 stop-instances --instance-ids i-<...> --query 'StoppingInstances[0].CurrentState.Name' --output text
stopping
```

### Real ishda qachon kerak

- Yangi server ochilganda: qo'lda sozlangan server takrorlanmaydi, user data yoki skriptga yozilgan server takrorlanadi.
- "Serverga kira olmayapman": security group manba IP'si, kalit, foydalanuvchi nomi (`ubuntu`), instans holati shu tartibda tekshiriladi.

### Nima uchun shunday

Sozlash qadamlarini skriptga yozish talabi "server bir kuni yo'qoladi" degan taxmindan kelib chiqadi: disk buziladi, instans tasodifan terminate qilinadi, AZ ishdan chiqadi. Qo'lda sozlangan va hech qayerga yozilmagan server (ingliz tilida "snowflake") bilan birga bilim ham yo'qoladi. User data bu yo'nalishdagi birinchi qadam, keyingisi iac modulidagi Terraform va Ansible.

## 3. Image'ni yetkazish: registry, tag, arxitektura

### Bu nima

Image ish mashinasida yig'iladi, registry'ga push qilinadi, serverda pull qilinadi. Registry (docker 3-dars) bu image'lar saqlanadigan server. Variantlar: docker modulida ishlatgan registry'ingiz (Docker Hub, GHCR) yoki AWS ECR (Elastic Container Registry: private repozitoriy, kirish IAM orqali).

```
aws ecr get-login-password --region "$AWS_REGION" | docker login \
  --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.$AWS_REGION.amazonaws.com
```

Birinchi buyruq IAM huquqingiz asosida vaqtinchalik parol chiqaradi, `--password-stdin` uni pipe'dan o'qiydi, shuning uchun parol buyruq qatorida va shell tarixida qolmaydi. ECR ishlatilsa serverga access key kerak emas: instansga `AmazonEC2ContainerRegistryReadOnly` policy'li role biriktiriladi (3-dars, instance role).

### Tag qoidalari

- Har deploy noyob, o'zgarmas tag bilan: versiya (`1.4.2`) yoki git commit SHA. Compose faylda aniq tag yoziladi.
- `latest` ishlatilmaydi. `latest` maxsus narsa emas, tag ko'rsatilmaganda qo'yiladigan oddiy nom va har push'da boshqa image'ga ko'chadi. Natijada serverda qaysi kod ishlayotganini aytib bo'lmaydi va rollback uchun "oldingi latest" degan narsa yo'q.
- Oldingi versiya image'i registry'da va serverda saqlanadi: rollback bu eski tag'ni qaytarish.

Frontend o'xshatishi: `package.json` da `"react": "latest"` yozib, lock faylsiz o'rnatish bilan bir xil muammo. Aniq tag bu aniq versiya, image digest esa `package-lock.json` dagi integrity hash vazifasini bajaradi.

### Mexanizm: arxitektura

Image ichida ma'lum CPU arxitekturasi uchun kompilyatsiya qilingan binary'lar yotadi (docker 2-dars). Mac'da (Apple Silicon) `docker build` standart holatda `linux/arm64` image beradi, Zorin'da `linux/amd64`. `arm64` image `x86_64` serverda ishga tushirilsa, kernel binary'ni bajara olmaydi va konteyner `exec format error` bilan darhol tugaydi. Uch yechim:

| Yechim | Qanday | Afzalligi | Narxi |
|--------|--------|-----------|-------|
| Platformani ko'rsatib build | `docker build --platform linux/amd64 ...` yoki `docker buildx build --platform linux/amd64 -t <image>:<tag> --push .` | Server va registry o'zgarmaydi, ikkala mashinadan bir xil natija | Boshqa arxitektura emulyatsiya (QEMU) bilan yig'iladi: sekinroq. Docker Desktop'da tayyor, Zorin'da binfmt sozlanadi (https://docs.docker.com/build/building/multi-platform/) |
| `arm64` (Graviton) instans | Instans tipi va AMI `arm64` tanlanadi | Mac'dagi build to'g'ridan-to'g'ri ishlaydi | Endi Zorin'da `--platform linux/arm64` kerak, muammo ikkinchi mashinaga ko'chadi |
| Serverning o'zida build | Kod serverga ko'chiriladi va o'sha yerda `docker build` | Arxitektura doim mos | Kichik instansda xotira va disk yetmasligi mumkin, serverda kod va build asboblari paydo bo'ladi, "bir marta yig'ilgan artifact" tamoyili buziladi |

Bu darsda asosiy yo'l birinchisi. Uchinchisi tushunish uchun aytiladi, production'da ishlatilmaydi.

### Misol: tayyor image qaysi arxitekturalar uchun bor

Host'da (ikkala mashinada bir xil):

```
$ docker buildx imagetools inspect nginx:1.27-alpine
Name:      docker.io/library/nginx:1.27-alpine
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:<...>

Manifests:
  Name:      docker.io/library/nginx:1.27-alpine@sha256:<...>
  MediaType: application/vnd.oci.image.manifest.v1+json
  Platform:  linux/amd64

  Name:      docker.io/library/nginx:1.27-alpine@sha256:<...>
  MediaType: application/vnd.oci.image.manifest.v1+json
  Platform:  linux/arm64/v8
  <...>
```

`MediaType: ...image.index...` bu tag bitta image emas, ro'yxat (manifest list) ekanini bildiradi. `Manifests` ostidagi har yozuv bitta platforma uchun alohida image va o'z digest'i bor. `docker pull` shu ro'yxatdan o'z mashinasining platformasiga mosini tanlaydi, shuning uchun rasmiy image'lar ikkala mashinada ham, serverda ham ishlaydi. Siz `--platform` siz yig'ib push qilgan image'da esa faqat bitta yozuv bo'ladi: build qilingan mashinaning arxitekturasi.

Tag va push ketma-ketligi (boshqa loyiha misolida):

```
$ docker build --platform linux/amd64 -t ghcr.io/<user>/notes-api:1.4.2 .
$ docker push ghcr.io/<user>/notes-api:1.4.2
The push refers to repository [ghcr.io/<user>/notes-api]
<layer-id>: Pushed
<...>
1.4.2: digest: sha256:<...> size: <N>
```

Oxirgi qator eng muhimi: registry shu tag'ga qaysi digest'ni yozganini aytadi. Digest image mazmunining hash'i, tag'dan farqli ravishda hech qachon boshqa narsaga ko'chmaydi.

### Real ishda qachon kerak

- "Mening mashinamda ishlaydi, serverda `exec format error`": birinchi tekshiriladigan narsa image va server arxitekturasi.
- Rollback paytida: oldingi tag aniq ma'lum va registry'da turgan bo'lishi kerak.
- Audit: "production'da hozir qaysi commit ishlayapti" degan savolga tag javob beradi.

### Nima uchun shunday

Registry orqali yetkazish `docker save` bilan fayl ko'chirishdan (docker 3-dars) farqli ravishda bitta manbani beradi: ish mashinasi, CI va har bir server image'ni bir joydan oladi va layer'lar kesh'lanadi (faqat o'zgargan layer yuklanadi). O'zgarmas tag qoidasi rollback'ni oddiy qiladi: orqaga qaytish yangi build emas, mavjud artifact'ni qayta ishga tushirish. Ko'p arxitekturali image'lar ARM serverlar (Graviton) va Apple Silicon tarqalgach zarurat bo'ldi, ungacha deyarli hamma narsa `amd64` edi va bu savol tug'ilmas edi.

## 4. Reverse proxy, DNS va TLS

### Reverse proxy nima

Reverse proxy bu mijoz va dastur orasida turadigan server: so'rovni o'zi qabul qiladi va ichkaridagi dasturga (upstream) uzatadi, javobni mijozga qaytaradi. Dastur konteyneri to'g'ridan-to'g'ri internetga chiqarilmaydi, chunki proxy quyidagi ishlarni bir joyda bajaradi:

- **TLS termination**: shifrlangan ulanish proxy'da tugaydi, ichkariga oddiy HTTP ketadi. Sertifikat va private key faqat proxy'da turadi, dastur TLS haqida bilmaydi.
- HTTP'ni HTTPS'ga yo'naltiradi.
- 80 va 443 kabi imtiyozli portlarni egallaydi, dastur esa root'siz yuqori portda (masalan 8080) ishlaydi.
- Bir IP ortida bir nechta dastur va nusxani `Host` header bo'yicha ajratadi.

Proxy so'rovni o'z nomidan uzatgani uchun dastur mijozning haqiqiy IP'sini ko'rmaydi: TCP ulanishning manbasi proxy konteyneri. Shuning uchun proxy `X-Forwarded-For` (mijoz IP'si), `X-Forwarded-Proto` (asl sxema: `http` yoki `https`) va `X-Forwarded-Host` header'larini qo'shadi. Node'da Express'ning `trust proxy` sozlamasi aynan shu header'larga ishonish haqida.

| | Caddy | nginx |
|---|-------|-------|
| TLS | Avtomatik: sertifikatni o'zi oladi va yangilaydi | Alohida ACME mijoz (certbot) va yangilash jadvali kerak |
| Konfiguratsiya | Qisqa Caddyfile | Batafsil, hamma narsa aniq yoziladi |
| Qachon | Kichik va o'rta deploy, tez boshlash | Keng tarqalgan, mavjud tizimlarda ko'p uchraydi, nozik sozlash |

Bu darsda asosiy yo'l Caddy, nginx va certbot varianti alohida vazifada. Caddyfile'da har sayt o'z manzili bilan boshlanadigan blok, ichida direktivalar (boshqa loyiha misolida):

```
api.example.org {
    reverse_proxy backend:3000
}
```

Manzil domen bo'lsa Caddy shu domen uchun sertifikat oladi va HTTPS'ni yoqadi, manzil `:80` kabi faqat port bo'lsa sertifikat so'ramaydi. Caddy sertifikatlar va ACME akkaunt kalitini konteyner ichida `/data` da saqlaydi, shuning uchun bu yo'l volume'ga ulanadi (`caddy_data:/data`). Volume'siz har qayta yaratishda yangi sertifikat so'raladi va rate limit'ga urilasiz.

### Mexanizm: ichki tarmoqdagi nom

User-defined Docker tarmog'ida (docker 4-dars) konteynerlar bir-birini nomi bilan topadi: Docker ichki DNS serveri `backend` nomini konteyner IP'siga aylantiradi. Port publish qilinmagan konteynerga faqat shu tarmoq ichidan yetish mumkin. Serverda, `web` tarmog'i va unga ulangan `app` konteyneri bor deb olsak ("Birga bajaramiz", 2-qadam):

```
ubuntu@ip-<...>:~$ docker run --rm --network web alpine:3.20 ping -c 1 app
PING app (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=<0.1NN> ms
```

Birinchi qatorda `app` nomi `172.18.0.2` ga aylangani ko'rinadi (sizda manzil boshqa bo'lishi mumkin), ikkinchi qator javob kelganini bildiradi. Bu manzil faqat server ichida mavjud, internetdan unga yo'l yo'q. To'liq yurish "Birga bajaramiz" da.

### DNS

Subdomen uchun `A` yozuv (network 4-dars) Elastic IP ga qaratiladi. TTL'ni laboratoriyada past qo'ying (masalan 300 soniya). Tekshirish host'da:

```
$ dig +short A <domen>
<EIP>
```

Chiqish bo'sh bo'lsa yozuv hali yo'q yoki tarqalmagan, boshqa IP chiqsa resolver kesh'ida eski qiymat turibdi. Yozuv tarqalmaguncha TLS so'rash foydasiz. DNS hali tarqalmagan paytda serverni tekshirish: `curl --resolve <domen>:443:<EIP> https://<domen>/healthz` (`--resolve` shu so'rov uchun DNS'ni chetlab, nomni berilgan IP'ga bog'laydi).

### Let's Encrypt va ACME qanday ishlaydi

Let's Encrypt bepul sertifikat beradigan CA (certificate authority, network 4-dars). U sertifikatni ACME protokoli orqali avtomatik beradi. Sertifikat berishdan oldin CA domen sizniki ekanini tekshiradi, bu tekshiruv challenge deyiladi. HTTP-01 challenge bosqichlari:

1. ACME mijoz (Caddy yoki certbot) akkaunt kaliti yaratadi va CA'dan `<domen>` uchun sertifikat so'raydi.
2. CA tasodifiy token beradi.
3. Mijoz shu token asosidagi javobni `http://<domen>/.well-known/acme-challenge/<token>` manzilida xizmat qiladi.
4. CA o'z serverlaridan shu manzilga 80-port orqali so'rov yuboradi. DNS haqiqatan sizning serveringizga qaragan bo'lsa va javob mos kelsa, domen nazorati isbotlangan.
5. Mijoz sertifikatni yuklab oladi va ishlata boshlaydi.

Demak HTTP-01 uchun uch narsa to'g'ri bo'lishi kerak: DNS serverga qaragan, 80-port internetdan ochiq (security group), proxy ishlab turibdi. Boshqa challenge turlari ham bor: TLS-ALPN-01 xuddi shu isbotni 443-portdagi TLS handshake ichida qiladi, DNS-01 esa DNS'ga TXT yozuv qo'yishni talab qiladi. Caddy standart holatda HTTP-01 va TLS-ALPN-01 ning ikkalasini biladi va biri o'tmasa ikkinchisini sinaydi. Certbot'da usulni siz tanlaysiz.

- Sertifikatlar qisqa muddatli (hozir 90 kun, aniq va joriy muddat Let's Encrypt hujjatida), shuning uchun yangilash (renewal) faqat avtomatik bo'ladi. Yangilash bu xuddi shu challenge'ni muddat tugashidan ancha oldin qayta o'tish. Caddy buni fon jarayonida o'zi qiladi, certbot'da jadval (systemd timer yoki cron) kerak. Qo'lda yangilanadigan sertifikat bir kuni albatta unutiladi.
- Production CA'da rate limit bor (https://letsencrypt.org/docs/rate-limits/). Sozlashni **staging** muhitida sinang: Caddy'da bu global `acme_ca` opsiyasi bilan, certbot'da `--test-cert` yoki `--dry-run` bilan qilinadi. Staging manzili https://letsencrypt.org/docs/staging-environment/ da. Staging sertifikatiga brauzer ishonmaydi, bu kutilgan holat.

### Misol: sertifikatni tashqaridan o'qish

Host'da, tayyor sayt bilan:

```
$ openssl s_client -connect letsencrypt.org:443 -servername letsencrypt.org </dev/null 2>/dev/null \
    | openssl x509 -noout -issuer -dates
issuer=C = US, O = Let's Encrypt, CN = <...>
notBefore=<...> GMT
notAfter=<...> GMT
```

`s_client` TLS handshake qiladi va server yuborgan sertifikatni chiqaradi, `-servername` qaysi domen so'ralayotganini aytadi (SNI, network 4-dars), `</dev/null` ulanishni darhol yopadi. `x509 -noout` sertifikatning o'zini chop etmay faqat so'ralgan maydonlarni beradi: `issuer` kim imzolagan, `notBefore` va `notAfter` amal qilish oralig'i. macOS'dagi LibreSSL `issuer` qatorini `/C=US/O=.../CN=...` ko'rinishida chiqaradi, mazmuni bir xil.

**Tuzoq: 80-portni "kerak emas" deb yopish.** HTTP-01 tekshiruvi va HTTP'dan HTTPS'ga yo'naltirish 80-portda ishlaydi. Yopilsa certbot HTTP-01 bilan sertifikat ololmaydi yoki bir necha haftadan keyin yangilanish jim to'xtaydi. Caddy bunday holatda TLS-ALPN-01 bilan o'tib ketishi mumkin, lekin `http://` bilan kelgan foydalanuvchi baribir javobsiz qoladi.

### Real ishda qachon kerak

- 502 xatosi: proxy tirik, upstream javob bermayapti. Proxy logi va dastur holati tekshiriladi.
- "Sertifikat muddati o'tdi": yangilanish qachondan beri va nima uchun o'tmayotganini proxy logi aytadi.
- Bir serverga ikkinchi dastur qo'shish: yangi port ochilmaydi, proxy'ga yangi blok qo'shiladi.

### Nima uchun shunday

TLS, yo'naltirish va marshrutlash har dasturda qayta yozilmasligi uchun alohida qatlamga chiqarilgan: dastur Go'da ham, Node'da ham bo'lsin, proxy bir xil. Let's Encrypt (2015) paydo bo'lguncha sertifikat pullik edi va qo'lda, yiliga bir marta o'rnatilar edi. Avtomatik tekshiruv sertifikatni bepul qildi, qisqa muddat esa o'g'irlangan kalit zararini cheklaydi va avtomatlashtirishga majbur qiladi. Muqobili: TLS'ni cloud load balancer yoki CDN'da tugatish (AWS'da ALB va ACM sertifikatlari), bu amaliyoti keyingi modullarda.

## 5. Ishga tushirish va qayta ko'tarish

### Bu nima

Server qayta yuklanganda yoki jarayon yiqilganda dastur odam aralashuvisiz ko'tarilishi shart. Node dunyosida bu ishni `pm2` qiladi, bu yerda ikki mexanizm bor.

**Docker restart policy** (asosiy yo'l). Docker daemon systemd servisi sifatida boot'da ishga tushadi (linux 11-dars) va restart policy'li konteynerlarni ko'taradi.

| Policy | Xulq |
|--------|------|
| `no` | Qayta ishga tushirilmaydi (standart) |
| `on-failure` | Faqat noldan farqli exit code bilan chiqsa |
| `always` | Har doim; qo'lda to'xtatilgan bo'lsa ham daemon restart'ida ko'tariladi |
| `unless-stopped` | Har doim, qo'lda to'xtatilganidan tashqari |

**systemd unit** Compose loyihasini boshqaradi: boot tartibi va bog'liqliklarni aniq yozish kerak bo'lsa.

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

`Type=oneshot` va `RemainAfterExit=yes` birga "buyruq bir marta ishlab tugaydi, lekin unit faol hisoblanadi" degani: `docker compose up -d` konteynerlarni fon rejimida qoldirib chiqadi. Bittasini tanlang, ikkalasini birga ishlatmang.

### Mexanizm: tirik va sog'lom

Restart policy "jarayon o'ldi" holatini yopadi, lekin "jarayon tirik, javob bermayapti" holatini yopmaydi. Buning uchun `healthcheck` bor: Docker konteyner ichida berilgan buyruqni davriy ishlatadi va exit code'iga qarab holatni `healthy` yoki `unhealthy` deb belgilaydi. Boshqa servis misolida:

```yaml
  cache:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
```

`depends_on` da `condition: service_healthy` bir servisni boshqasi sog'lom bo'lguncha kutishga majbur qiladi. Docker `unhealthy` konteynerni o'zi qayta ishga tushirmaydi: bu holatni ko'rish va xabar berish tashqi monitoring ishi (monitoring modulida).

### Misol: holatni o'qish

Serverda:

```
ubuntu@ip-<...>:~$ docker ps --format 'table {{.Names}}\t{{.Status}}'
NAMES     STATUS
cache     Up 2 minutes (healthy)
worker    Restarting (1) 5 seconds ago
```

`Up 2 minutes (healthy)`: jarayon ishlayapti va oxirgi health tekshiruvlari o'tgan. `Restarting (1) 5 seconds ago`: jarayon exit code 1 bilan chiqqan va restart policy uni qayta ko'taryapti. Bu qator qayta-qayta ko'rinsa, bu crash loop.

**Tuzoq: crash loop.** Noto'g'ri konfiguratsiya bilan `restart: always` konteynerni cheksiz qayta ishga tushiradi. `Restarting` holati va loglardagi takrorlanuvchi xato shuning belgisi.

### Real ishda qachon kerak

- Provayder serverni rejali reboot qiladi yoki kernel yangilanishi reboot talab qiladi: dastur o'zi qaytishi kerak.
- Dastur xotira yetmay o'ldiriladi (OOM): restart policy ko'taradi, sababni esa log va monitoring ko'rsatadi.

### Nima uchun shunday

Jarayonni kuzatuvchi (supervisor) g'oyasi init tizimlaridan keladi: PID 1 servislarni ko'taradi va yiqilsa qaytaradi (linux 11-dars). Docker shu vazifani konteynerlar uchun o'z daemon'ida takrorlagan. Bitta serverda bu yetarli. Server o'zi yo'qolsa hech qaysi restart policy yordam bermaydi: buning uchun bir nechta serverda ishlaydigan orkestrator (Kubernetes, ECS) kerak.

## 6. Konfiguratsiya va secret'lar

### Bu nima

Tamoyil (twelve-factor): bir xil image hamma muhitda, farq faqat konfiguratsiyada, konfiguratsiya environment'dan. Secret bu oshkor bo'lsa zarar keltiradigan konfiguratsiya qiymati: database paroli, API kaliti, token.

- Secret image ichiga tushmaydi (`ENV`, `COPY .env`): image layer'laridan o'qiladi.
- Secret git'da yo'q. Repozitoriyda faqat `.env.example` (kalit nomlari, qiymatsiz).
- Serverda `/opt/app/.env`, egasi deploy foydalanuvchisi, `chmod 600`, Compose'da `env_file: .env`.
- AWS credential serverda umuman yo'q: S3 va ECR ga instance role orqali (3-dars).

### Mexanizm va chegaralari

`env_file` dagi qatorlar konteyner yaratilayotganda uning birinchi jarayoni environment'iga yoziladi. Bu qiymatlar konteyner konfiguratsiyasining qismi bo'lib qoladi: `docker inspect` da va jarayonning `/proc/<pid>/environ` faylida ko'rinadi, ya'ni `docker` group'dagi har kim va root o'qiydi. Qiymatni o'zgartirish uchun konteyner qayta yaratilishi kerak, `.env` ni tahrirlashning o'zi ishlab turgan jarayonga ta'sir qilmaydi.

Keyingi qadam secret omborlari: AWS SSM Parameter Store (`aws ssm get-parameter --name ... --with-decryption`) yoki Secrets Manager, ulardan deploy paytida o'qib olinadi. Bu darsda `.env` fayl yetarli, lekin secret'lar qayerda turgani va qanday almashtirilishi runbook'da yozilishi shart.

### Misol: fayl huquqi

Serverda:

```
ubuntu@ip-<...>:/opt/app$ stat -c '%a %U:%G %n' .env
600 ubuntu:ubuntu .env
```

`600`: faqat egasi o'qiydi va yozadi (linux 3-dars), `ubuntu:ubuntu` egasi va group'i. `644` chiqsa serverdagi har foydalanuvchi parolni o'qiy oladi.

### Real ishda qachon kerak

- Xodim ketganda yoki secret log'ga tushib qolganda rotation: yangi qiymat yaratiladi, ombor yoki `.env` yangilanadi, servis qayta yaratiladi, eski qiymat bekor qilinadi.
- Staging va production bir xil image bilan, har xil `.env` bilan ishlaydi.

### Nima uchun shunday

Vercel'dagi "Environment Variables" sahifasi aynan shu ajratishni qiladi: kod repozitoriyda, qiymatlar platformada. Secret'ni image'ga yozish qulay ko'rinadi, lekin image registry'da, kesh'da va har serverda nusxalanadi, uni qaytarib olib bo'lmaydi. Environment'ning muqobili fayl sifatida mount qilinadigan secret'lar (Compose `secrets`, Kubernetes Secret): ular `docker inspect` da ko'rinmaydi, kubernetes modulida ko'riladi.

## 7. Loglar

### Bu nima

Konteynerdagi dastur stdout va stderr ga yozadi, fayllarga emas. Docker bu oqimlarni ushlab, log driver orqali saqlaydi. Standart driver `json-file`: har konteyner uchun serverda `/var/lib/docker/containers/<id>/<id>-json.log` fayli. O'qish: `docker compose logs -f --tail 100 <service>`.

### Mexanizm

Faylning har qatori bitta JSON obyekt: log matni, oqim nomi (`stdout` yoki `stderr`) va vaqt. `docker logs` shu faylni o'qib, matnni chiqaradi. Fayl konteynerga tegishli: konteyner o'chirilsa (`docker rm`, `docker compose down`) log ham o'chadi.

**Tuzoq: `json-file` standart holatda cheklanmagan.** Loglar disk to'lguncha o'sadi, disk to'lgach database yoza olmaydi va hamma narsa yiqiladi. Har servisga rotation qo'ying:

```yaml
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

`max-size` bitta fayl chegarasi, `max-file` nechta eski fayl saqlanishi: jami 30 MB dan oshmaydi. Sozlama faqat yangi yaratilgan konteynerga ta'sir qiladi.

### Misol: log qancha joy oladi

Serverda:

```
ubuntu@ip-<...>:~$ sudo du -sh /var/lib/docker/containers/*/*-json.log
<N>K	/var/lib/docker/containers/<id>/<id>-json.log
<N>M	/var/lib/docker/containers/<id>/<id>-json.log
```

Har qator bitta konteynerning log fayli va hajmi. `sudo` kerak, chunki `/var/lib/docker` faqat root'ga ochiq. macOS'dagi mahalliy Docker'da bu yo'l host'da ko'rinmaydi (Docker Desktop VM ichida), serverda esa oddiy fayl.

### Real ishda qachon kerak

- Nosozlikda birinchi qadam: proxy access log'i (so'rov keldimi, qanday status qaytdi) va dastur log'i (nima uchun) alohida o'qiladi.
- "Disk to'ldi" hodisasida birinchi gumon: rotation'siz loglar va eski image'lar.

### Nima uchun shunday

Dastur faylga emas stdout'ga yozishi twelve-factor tamoyili: log yo'li, rotation va yig'ish dasturning emas, muhitning ishi, shunda bir xil image har joyda ishlaydi. Server yo'qolsa loglar ham yo'qoladi, shuning uchun production'da ular markaziy tizimga jo'natiladi (monitoring modulida). Vercel'dagi "Logs" sahifasi shunday markaziy yig'ishning tayyor ko'rinishi.

## 8. Yangilash, rollback va uzilish

### Bu nima

Sodda yangilash: Compose faylda tag'ni o'zgartirish, `docker compose pull`, `docker compose up -d`. Compose o'zgargan servisni to'xtatadi va yangisini yaratadi. Shu oraliqda (soniyalar) so'rovlar xato oladi. Bu single-node deploy'ning tabiiy narxi. Rollback bu xuddi shu amalning teskarisi: oldingi tag'ni qaytarish va `up -d`.

### Mexanizm: uzilish qayerdan keladi

Eski konteyner to'xtatilgan va yangisi so'rov qabul qilishga tayyor bo'lgan onlar orasida upstream yo'q. To'xtatish quyidagicha ishlaydi: Docker konteynerning birinchi jarayoniga `SIGTERM` yuboradi, `stop_grace_period` (standart 10 soniya) kutadi, jarayon chiqmasa `SIGKILL` bilan o'ldiradi. Uzilishni kamaytirish, oddiydan murakkabga:

1. **Graceful shutdown**: dastur `SIGTERM` olganda yangi so'rov qabul qilishni to'xtatib, joriylarini tugatadi va o'zi chiqadi.
2. **Health check va proxy retry**: proxy tayyor bo'lmagan upstream'ga so'rovni qayta urinadi (Caddy'da `reverse_proxy` ichida `lb_try_duration`), qisqa uzilish foydalanuvchiga kechikish bo'lib ko'rinadi.
3. **Ikki nusxa**: dasturning ikki konteyneri proxy ortida, navbat bilan yangilanadi (rolling).
4. **Blue-green**: yangi versiya yonma-yon ko'tariladi, health tekshiriladi, proxy unga o'tkaziladi (`caddy reload`), eskisi bir muddat rollback uchun turadi.

Qaysi usul bo'lmasin, eski va yangi versiya bir muddat bitta database bilan ishlaydi. Shuning uchun sxema migratsiyalari orqaga mos bo'lishi kerak (avval ustun qo'shiladi va kod yangilanadi, eski ustun keyingi relizda o'chiriladi). Aks holda rollback imkonsiz bo'ladi.

### Misol: SIGTERM'ni e'tiborsiz qoldiradigan jarayon

Serverda (bash; zsh'da `time` chiqishi boshqa formatda, ma'nosi bir xil):

```
$ docker run -d --name sleeper alpine:3.20 sleep 1000
$ time docker stop sleeper
sleeper

real	0m10.<NNN>s
$ docker inspect --format '{{.State.ExitCode}}' sleeper
137
$ docker rm sleeper
```

`sleep` konteynerda PID 1 bo'lib ishlaydi va `SIGTERM` ni qayta ishlamaydi, shuning uchun `docker stop` to'liq 10 soniya kutadi (`real 0m10...`), keyin `SIGKILL` yuboradi. Exit code `137` bu 128 + 9, ya'ni jarayon 9-signal (`SIGKILL`) bilan o'ldirilgan (linux 1-dars: 128 + signal raqami). Dasturingiz shunday tutsa, har deploy kamida 10 soniya uzilish beradi va joriy so'rovlar uziladi. To'g'ri yozilgan dastur shu yerda bir soniyadan kam vaqtda `0` yoki `143` bilan chiqadi.

### Real ishda qachon kerak

- Har relizda. Rollback bu oldindan tayyorlangan buyruq, vahima paytidagi ijod emas: runbook'da yozilgan va kamida bir marta sinalgan bo'lishi kerak.
- Reliz xato chiqqanda birinchi harakat tuzatish emas, oldingi tag'ga qaytish, sabab keyin qidiriladi.

### Nima uchun shunday

Bitta serverda to'liq "zero-downtime" (uzilishsiz deploy) ga faqat yaqinlashish mumkin: buning uchun kamida ikki nusxa, health check'ga qaraydigan proxy va trafikni almashtirish tartibi kerak, server o'zi reboot bo'lsa baribir uzilish bo'ladi. Haqiqiy uzilishsiz deploy bir nechta server va load balancer talab qiladi, uni avtomatlashtirish (rolling va blue-green strategiyalari pipeline'da) cicd modulida. Vercel'da har deploy yangi o'zgarmas nusxa bo'lib, domen unga bir zumda o'tkaziladi: bu blue-green'ning platforma bajargan ko'rinishi.

## 9. Backup

### Bu nima

Backup bu qayta yaratib bo'lmaydigan narsaning boshqa joydagi nusxasi. Holat uch joyda: database volume, foydalanuvchi yuklagan fayllar (bo'lsa, ular boshidan S3 da turgani ma'qul), konfiguratsiya (`.env`, Compose fayl, Caddyfile). Image backup qilinmaydi, u registry'da; server ham backup qilinmaydi, u skriptdan qayta quriladi. Takrorlanmaydigan yagona narsa ma'lumot.

### Mexanizm

Database uchun mantiqiy dump olinadi: `pg_dump` ishlab turgan PostgreSQL'dan izchil (consistent) nusxani SQL ko'rinishida chiqaradi (https://www.postgresql.org/docs/current/backup-dump.html). Dump siqiladi va S3 ga yuklanadi. `aws s3 cp` manba o'rnida `-` berilsa stdin'dan o'qiydi, shuning uchun oraliq fayl kerak emas. Boshqa narsa (konfiguratsiya papkasi) misolida:

```
tar -czf - -C /opt/app compose.yaml Caddyfile \
  | aws s3 cp - "s3://<bucket>/config/$(date +%F-%H%M).tar.gz"
```

- Server S3 ga instance role orqali yozadi. Role faqat `PutObject` ga ega bo'lsa, buzib kirilgan server eski backup'larni o'qiy ham, o'chira ham olmaydi.
- Bucket: Block Public Access yoqilgan, versioning, eski backup'lar uchun lifecycle (3-dars).
- Jadval: systemd timer yoki cron (linux 11-dars). Backup skripti xato bilan tugasa buni kimdir bilishi kerak.
- **Tiklab ko'rilmagan backup backup emas.** Dump'ni toza database'ga tiklash muntazam sinaladi.

Ikki ko'rsatkich: **RPO** (recovery point objective: qancha ma'lumot yo'qotishga rozimiz, ya'ni backup oralig'i) va **RTO** (recovery time objective: qancha vaqtda tiklaymiz, ya'ni toza serverda qayta deploy va restore vaqti). EBS snapshot butun diskni saqlaydi, lekin ishlab turgan database uchun izchil bo'lmasligi mumkin va alohida haq oladi, mantiqiy dump o'rnini bosmaydi.

### Misol: pipe ichidagi xato qanday yo'qoladi

Host'da yoki serverda (bash va zsh'da bir xil):

```
$ false | gzip > /dev/null; echo $?
0
$ set -o pipefail
$ false | gzip > /dev/null; echo $?
1
```

Birinchi holatda `false` xato bilan tugadi, lekin pipe'ning exit code'i oxirgi buyruqniki (`gzip`), ya'ni `0`. Backup skriptida bu "dump yiqildi, bo'sh arxiv S3 ga muvaffaqiyatli yuklandi" degani. `set -o pipefail` dan keyin pipe'dagi istalgan buyruq xatosi butun pipe'ning xatosi bo'ladi.

### Real ishda qachon kerak

- Noto'g'ri migratsiya yoki tasodifiy `DELETE` dan keyin: tiklash nuqtasi oxirgi backup.
- Server yo'qolganda: yangi server skriptdan, ma'lumot backup'dan.
- Reja tuzishda: "kuniga bir marta backup" degani "eng yomon holatda 24 soatlik ma'lumot yo'qoladi" degani, biznes shunga rozimi?

### Nima uchun shunday

Backup serverning o'zida tursa, server bilan birga yo'qoladi, shuning uchun u boshqa xizmatga (S3) va cheklangan huquq bilan yoziladi. Mantiqiy dump tanlanishi sababi: u PostgreSQL versiyasi va disk formatiga bog'liq emas, istalgan toza database'ga tiklanadi. Muqobili managed database (RDS): avtomatik backup va point-in-time recovery platformada, evaziga narx (11-bo'lim).

## 10. Hardening

### Bu nima

Hardening bu serverning hujum yuzasini kamaytirish: keraksiz kirish yo'llarini yopish va qolganlarini mustahkamlash. Minimal ro'yxat, qatlamlar bo'yicha:

| Qatlam | Chora |
|--------|-------|
| Security group | 22 faqat ma'lum IP'dan, 80 va 443 ochiq, qolgan hammasi yopiq |
| SSH | Faqat kalit (`PasswordAuthentication no`), root login yo'q (`PermitRootLogin no`). Tekshirish: `sudo sshd -T`. O'zgartirish `/etc/ssh/sshd_config.d/` da, `sudo sshd -t` bilan sinab, keyin reload (linux 10-dars) |
| Yangilanishlar | `unattended-upgrades` xavfsizlik yangilanishlarini o'zi o'rnatadi. `/var/run/reboot-required` paydo bo'lsa reboot rejalashtiriladi |
| Konteynerlar | Root bo'lmagan `USER`, faqat proxy port publish qiladi, database `ports` siz, image'lar muntazam yangilanadi |
| IAM | Instance role minimal: faqat backup bucket'iga yozish va registry'dan o'qish |
| Fayllar | `.env` `600`, serverda ortiqcha kalit va repozitoriy nusxasi yo'q |

SSH'ni butunlay yopish ham mumkin: AWS Systems Manager Session Manager IAM orqali kirish beradi, 22-port ochilmaydi.

### Mexanizm: Docker va host firewall

Docker `ports:` bilan chiqarilgan portlar uchun o'z iptables qoidalarini yozadi (network 6-dars) va ular `ufw` qoidalaridan oldin ishlaydi: `ufw deny 5432` ga qaramay `ports: ["5432:5432"]` internetga ochiq bo'ladi. Himoya: keraksiz portni publish qilmaslik, zarur bo'lsa `127.0.0.1:5432:5432` (faqat serverning o'zidan), va tashqi qatlam sifatida security group.

### Misol: avtomatik yangilanish yoqilganmi

Serverda:

```
ubuntu@ip-<...>:~$ cat /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Birinchi qator paketlar ro'yxatini har kuni yangilashni (`apt update` ning avtomatik ko'rinishi, linux 12-dars), ikkinchisi `unattended-upgrade` ni har kuni ishlatishni yoqadi; `"0"` o'chirilgan degani. Nima o'rnatilgani `/var/log/unattended-upgrades/` dagi loglarda.

**Tuzoq: SSH sozlamasini sinamasdan yopish.** `sshd` konfiguratsiyasini o'zgartirgach joriy sessiyani yopmang, yangi terminaldan kirib ko'ring. Aks holda serverdan o'zingizni qulflab qo'yasiz.

### Real ishda qachon kerak

- Har yangi serverda, internetga chiqarilishidan oldin: public IP'li server bir necha daqiqada avtomatik skanerlar nishoniga tushadi.
- Xavfsizlik auditi va hodisadan keyingi tekshiruvda shu ro'yxat bo'yicha dalil so'raladi.

### Nima uchun shunday

Qatlamlar ataylab takrorlanadi (defense in depth): security group xato ochilsa SSH kaliti, kalit oshkor bo'lsa manba IP cheklovi, konteyner buzilsa minimal IAM role zararni cheklaydi. Shared responsibility modelida (1-dars) IaaS'da OS va undan yuqori hamma narsa sizning zimmangizda, shuning uchun bu ro'yxatni provayder bajarmaydi.

## 11. Managed variantlar

### Bu nima

Yuqoridagi ishlarning katta qismini platformaga topshirish mumkin. Bu bo'limda faqat tushuncha, amaliyot va buyruqlar yo'q (taqqoslash 19-vazifada hujjat asosida).

| Xizmat | Nima | Siz berasiz | Platforma qiladi | Qachon |
|--------|------|-------------|------------------|--------|
| Lightsail | Soddalashtirilgan VPS, oldindan ma'lum oylik narx | Hamma narsa, 2–10-bo'limlardagi kabi | Sodda konsol, paket narx | Developer cloud uslubidagi oddiy server kerak bo'lsa |
| Elastic Beanstalk | Klassik PaaS, EC2 ustida | Kod yoki image, konfiguratsiya | Instans, load balancer, autoscaling, deploy strategiyalari | Standart web dastur, EC2 ko'rinib tursin desangiz |
| App Runner | Konteyner PaaS | Image yoki repozitoriy | Build, TLS, scaling, load balancing | Bitta stateless servisni eng kam sozlama bilan |
| ECS va Fargate | Konteyner orkestratori, Fargate bilan serversiz | Task definition, tarmoq, IAM | Konteynerni joylash, qayta ko'tarish, rolling deploy; Fargate'da server yo'q | Bir nechta servis, production, Kubernetes'siz |

Xizmatlar ro'yxati va yangi mijozlar uchun mavjudligi o'zgarib turadi, tanlashdan oldin har birining hujjat sahifasini tekshiring. Database har qanday holatda alohida hal qilinadi (managed: RDS).

### Boshqa provayderlardagi mosliklar

| Tushuncha | AWS | Google Cloud | Azure | DigitalOcean | Hetzner Cloud |
|-----------|-----|--------------|-------|--------------|---------------|
| VM'da qo'lda deploy | EC2 | Compute Engine | Virtual Machines | Droplet | Server |
| Sodda VPS | Lightsail | yo'q | yo'q | Droplet | Server |
| Konteyner PaaS | App Runner | Cloud Run | Container Apps | App Platform | yo'q |
| Konteyner registry | ECR | Artifact Registry | Container Registry | Container Registry | yo'q |
| Secret ombori | Secrets Manager, SSM Parameter Store | Secret Manager | Key Vault | yo'q (env) | yo'q |
| Backup ombori | S3 | Cloud Storage | Blob Storage | Spaces | Object Storage |

Bu darsdagi 2–10-bo'limlar har qanday provayderdagi Ubuntu serverda o'zgarishsiz ishlaydi. Faqat instance role va S3 qismi provayderga xos.

### Real ishda qachon kerak

- Yangi loyihada "VM'mi yoki managed'mi" qarori: jamoada serverni patch qiladigan va tunda uyg'onadigan odam bormi?
- Mavjud VM deploy'ini ko'chirishda: qaysi ishlar platformaga o'tadi, qaysilari (database, secret'lar, migratsiya) baribir sizda qoladi.

### Nima uchun shunday

1-darsdagi savdolashuv bu yerda aniq ko'rinadi: yuqoriroq variantda OS patch, TLS yangilash, qayta ko'tarish va rolling deploy platformada, evaziga narx yuqoriroq, nazorat kamroq, debug faqat log orqali. Vercel va Netlify shu shkalaning eng yuqori uchi. Bu darsni qo'lda o'tganingizdan keyin managed xizmat hujjatidagi har sozlamani bitta savol bilan o'qiy olasiz: bu qaysi bosqichni mening o'rnimga bajaryapti?

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Deploy | kodni foydalanuvchi ocha oladigan holatga keltirish va shu holatda ushlab turish jarayoni |
| Artifact | build natijasi bo'lgan, ishga tushirishga tayyor o'zgarmas paket (bu kursda Docker image) |
| Registry | image'lar saqlanadigan va tarqatiladigan server (Docker Hub, GHCR, ECR) |
| O'zgarmas tag | bir marta push qilingach boshqa image'ga ko'chirilmaydigan tag (versiya yoki commit SHA) |
| Digest | image mazmunining `sha256` hash'i, mazmun o'zgarsa u ham o'zgaradi |
| Manifest list | bitta tag ostidagi har platforma uchun alohida image'lar ro'yxati |
| Reverse proxy | mijoz so'rovini qabul qilib ichkaridagi dasturga uzatadigan server |
| Upstream | proxy so'rovni uzatadigan ichki dastur |
| TLS termination | shifrlangan ulanishni proxy'da tugatib, ichkariga oddiy HTTP uzatish |
| ACME | CA bilan sertifikat olish va yangilashni avtomatlashtiradigan protokol |
| Challenge | CA domen nazoratini tekshiradigan sinov (HTTP-01, TLS-ALPN-01, DNS-01) |
| Staging CA | Let's Encrypt'ning sinov muhiti: limitlari yumshoq, sertifikatiga brauzer ishonmaydi |
| Rate limit | ma'lum vaqt ichida beriladigan sertifikatlar soniga qo'yilgan chegara |
| Restart policy | konteyner to'xtaganda Docker uni qayta ishga tushirish-tushirmasligini belgilaydigan qoida |
| Healthcheck | konteyner ichida davriy ishlab, dastur javob berayotganini tekshiradigan buyruq |
| Crash loop | konteynerning ishga tushib darhol yiqilishi va cheksiz qayta ko'tarilishi |
| Secret | oshkor bo'lsa zarar keltiradigan konfiguratsiya qiymati (parol, token, kalit) |
| Rotation | secret'ni yangisiga almashtirib, eskisini bekor qilish |
| Log driver | Docker konteyner stdout va stderr oqimlarini qayerga yozishini belgilaydigan mexanizm |
| Graceful shutdown | `SIGTERM` olgan dasturning joriy so'rovlarni tugatib, o'zi tartibli to'xtashi |
| Rollback | oldingi ishlagan versiyaga qaytish |
| Rolling deploy | nusxalarni navbat bilan yangilash |
| Blue-green | yangi versiyani eskisi yonida ko'tarib, trafikni bir zumda almashtirish |
| Zero-downtime | foydalanuvchi so'rovlari xato olmaydigan deploy |
| RPO | nosozlikda yo'qotishga rozi bo'lingan ma'lumot hajmi, vaqt bilan o'lchanadi |
| RTO | nosozlikdan keyin xizmatni tiklash uchun belgilangan vaqt |
| Hardening | serverning hujum yuzasini kamaytiradigan sozlashlar to'plami |
| Runbook | tizimni ishlatish va nosozlikni bartaraf etish qadamlari yozilgan hujjat |
| Teardown | yaratilgan hamma resursni tartib bilan o'chirish |

## Tuzoqlar

- `latest` tag bilan deploy: serverda nima ishlayotgani noma'lum, rollback yo'q.
- Mac'da `--platform` siz yig'ilgan image'ni `x86_64` serverga push qilish: `exec format error`.
- Database portini `ports:` bilan chiqarish va `ufw` himoya qiladi deb o'ylash.
- Sertifikat volume'ini saqlamaslik va production CA'da tajriba qilib rate limit'ga urilish.
- 80-portni yopib HTTP-01 yangilanishini va HTTPS'ga yo'naltirishni jim sindirish.
- Log rotation'siz `json-file`: disk to'ladi, database yiqiladi.
- Secret'ni image'ga, git'ga yoki user data'ga yozish; serverga access key qo'yish (role o'rniga).
- Backup bor, lekin hech qachon tiklab ko'rilmagan; backup o'sha serverning o'zida turadi; pipe'dagi xato `pipefail` siz yo'qoladi.
- Rollback rejasiz deploy va orqaga mos bo'lmagan migratsiya.
- Serverni qo'lda sozlab, qadamlarni hech qayerga yozmaslik: server yo'qolsa bilim ham yo'qoladi.
- Mashinani almashtirganda security group'dagi SSH manba IP'sini yangilamaslik (ulanish osilib qoladi) yoki "vaqtincha" `0.0.0.0/0` ochish.
- Elastic IP'siz instansni stop va start qilish: public IP o'zgaradi, DNS yozuvi eski manzilga qarab qoladi.
- Mashg'ulot oxirida instansni stop qilmaslik; dars oxirida Elastic IP va DNS yozuvini unutish.
- Juma kechqurun deploy qilish va tashqaridan tekshirmaslik (`curl` serverning o'zidan emas, internetdan).

## Manbalar

- https://docs.docker.com/engine/install/ubuntu/ – Docker Engine'ni Ubuntu'ga o'rnatish
- https://docs.docker.com/build/building/multi-platform/ – ko'p platformali build, `--platform`, QEMU
- https://docs.docker.com/engine/containers/start-containers-automatically/ – restart policy'lar
- https://docs.docker.com/engine/logging/drivers/json-file/ – json-file log driver va rotation
- https://docs.docker.com/engine/network/packet-filtering-firewalls/ – Docker, iptables va ufw
- https://docs.docker.com/reference/compose-file/ – Compose file reference
- https://caddyserver.com/docs/automatic-https – Caddy avtomatik HTTPS (majburiy)
- https://caddyserver.com/docs/caddyfile/directives/reverse_proxy va https://caddyserver.com/docs/caddyfile/options – `reverse_proxy` direktivasi va global opsiyalar
- https://nginx.org/en/docs/http/ngx_http_proxy_module.html va https://certbot.eff.org/ – nginx proxy va certbot
- https://letsencrypt.org/how-it-works/ va https://letsencrypt.org/docs/challenge-types/ – ACME va challenge turlari
- https://letsencrypt.org/docs/rate-limits/ va https://letsencrypt.org/docs/staging-environment/ – rate limit va staging
- https://12factor.net/ – The Twelve-Factor App (config, logs, disposability bo'limlari)
- https://www.postgresql.org/docs/current/backup-dump.html – `pg_dump` va tiklash
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html – ECR bilan ishlash
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Stop_Start.html – instansni stop va start qilish, nima saqlanadi
- https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html – Session Manager
- https://docs.aws.amazon.com/decision-guides/latest/containers-on-aws-how-to-choose/choosing-aws-container-service.html – AWS'da konteyner xizmatini tanlash
- https://sre.google/sre-book/table-of-contents/ – Google SRE Book (release engineering va runbook madaniyati)

## Birga bajaramiz

Tayyor image'ni (o'z dasturingizni emas) proxy ortida ishga tushiramiz, yangilaymiz, orqaga qaytaramiz va tozalaymiz. "Dastur" o'rnida rasmiy `nginx` image'ining ikki versiyasi, proxy o'rnida Caddy turadi. Compose, database, domen va TLS bu yerda ataylab yo'q: ular vazifalarda. Yurish 2-vazifadan keyin, o'sha serverda bajariladi (Docker o'rnatilgan, 80-port ochiq).

1. Host'da kimligingizni va server arxitekturasini tekshiring:

```
$ aws sts get-caller-identity --query Arn --output text
arn:aws:<...>
$ ssh -i ~/.ssh/<key> ubuntu@<EIP> uname -m
x86_64
```

Birinchi buyruq qaysi akkaunt va identity bilan ishlayotganingizni aytadi (2-dars). `ssh` ga buyruq berilsa, u serverda bajarilib natijasi qaytadi va sessiya yopiladi. `x86_64` bo'lgani uchun `linux/amd64` image kerak. 3-bo'limdagi `imagetools inspect` chiqishida `nginx` uchun bu platforma bor edi, demak `--platform` haqida o'ylash shart emas: rasmiy image manifest list.

2. Serverga kiring, ichki tarmoq yarating va "dastur"ni aniq tag bilan, port publish qilmasdan ishga tushiring:

```
$ ssh -i ~/.ssh/<key> ubuntu@<EIP>
ubuntu@ip-<...>:~$ docker network create web
<network-id>
ubuntu@ip-<...>:~$ docker run -d --name app --network web --restart unless-stopped nginx:1.26-alpine
<container-id>
```

`--network web` konteynerni user-defined tarmoqqa ulaydi, shunda u `app` nomi bilan topiladi. `-p` yo'q: tashqaridan bu konteynerga yo'l yo'q. `--restart unless-stopped` 5-bo'limdagi restart policy.

3. Proxy'ni ishga tushiring. Caddyfile yozmaslik uchun Caddy'ning bir qatorlik rejimi ishlatiladi:

```
ubuntu@ip-<...>:~$ docker run -d --name proxy --network web --restart unless-stopped \
    -p 80:80 caddy:2 caddy reverse-proxy --from :80 --to app:80
<container-id>
ubuntu@ip-<...>:~$ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
NAMES     IMAGE               PORTS
proxy     caddy:2             0.0.0.0:80->80/tcp, <...>
app       nginx:1.26-alpine   80/tcp
```

`--from :80` manzilda domen yo'q, shuning uchun Caddy sertifikat so'ramaydi va oddiy HTTP xizmat qiladi. `PORTS` ustunini o'qing: `proxy` da `0.0.0.0:80->80/tcp` host'ning 80-porti konteynerga ulanganini bildiradi (qolgan yozuvlar image e'lon qilgan, lekin publish qilinmagan portlar). `app` da faqat `80/tcp`, strelkasiz: port konteyner ichida ochiq, host'da emas.

4. Host'dan (yangi terminal) tashqi tekshiruv:

```
$ curl -s -o /dev/null -w '%{http_code}\n' http://<EIP>/
200
```

So'rov 1-bo'limdagi yo'lni bosib o'tdi: Elastic IP, security group (80), proxy, ichki tarmoq, `app`.

5. Serverda dastur logidan proxy izini ko'ring:

```
ubuntu@ip-<...>:~$ docker logs --tail 1 app
172.18.0.3 - - [<date>] "GET / HTTP/1.1" 200 615 "-" "curl/<version>" "<MY_IP>"
```

Birinchi maydon dastur ko'rgan ulanish manbasi: bu sizning IP'ingiz emas, `proxy` konteynerining ichki manzili. Oxirgi qo'shtirnoq ichidagi qiymat `X-Forwarded-For` header'i, uni Caddy qo'shgan va unda haqiqiy mijoz IP'si turibdi. `200 615` status va javob hajmi (bayt). 4-bo'limdagi "dastur mijozni ko'rmaydi" degan gap shu qatorda ko'rinadi.

6. Yangilash. Host'dagi terminalda o'lchov siklini qoldiring (to'xtatish: Ctrl+C):

```
$ while true; do curl -s -m 2 -o /dev/null -w '%{http_code}\n' http://<EIP>/; sleep 0.5; done
```

Serverda yangi tag'ni oldindan torting, keyin konteynerni almashtiring:

```
ubuntu@ip-<...>:~$ docker pull nginx:1.27-alpine
ubuntu@ip-<...>:~$ docker stop app && docker rm app
ubuntu@ip-<...>:~$ docker run -d --name app --network web --restart unless-stopped nginx:1.27-alpine
ubuntu@ip-<...>:~$ docker exec app nginx -v
nginx version: nginx/1.27.<N>
```

Host'dagi sikl chiqishida shu payt bir nechta `502` ko'rinadi, keyin yana `200`:

```
200
502
502
200
```

`502 Bad Gateway` ni proxy qaytaradi: u tirik, lekin `app` yo'q paytda upstream'ga ulana olmadi. `pull` ni oldindan qilganimiz uchun uzilish faqat `stop` va `run` orasidagi vaqtga teng, yuklab olish vaqti unga qo'shilmadi. `docker exec app nginx -v` yangi versiya ishlayotganini konteyner ichidan tasdiqlaydi.

7. Rollback. Oldingi image serverda turibdi, shuning uchun hech narsa yuklanmaydi:

```
ubuntu@ip-<...>:~$ docker stop app && docker rm app
ubuntu@ip-<...>:~$ docker run -d --name app --network web --restart unless-stopped nginx:1.26-alpine
ubuntu@ip-<...>:~$ docker exec app nginx -v
nginx version: nginx/1.26.<N>
```

Tag'lar aniq bo'lgani uchun "oldingi versiya" degan savolning javobi bor edi: `1.26`. Ikkalasi ham `latest` bo'lganida qaytadigan joy bo'lmas edi.

8. Tozalash va mashg'ulotni yopish. Serverda:

```
ubuntu@ip-<...>:~$ docker rm -f proxy app
ubuntu@ip-<...>:~$ docker network rm web
ubuntu@ip-<...>:~$ docker image rm nginx:1.26-alpine nginx:1.27-alpine caddy:2
ubuntu@ip-<...>:~$ docker ps -a --format '{{.Names}}'
ubuntu@ip-<...>:~$ exit
```

Oxirgi `docker ps -a` hech narsa chiqarmasligi kerak. Host'da siklni Ctrl+C bilan to'xtating. Bugun boshqa ishlamasangiz instansni stop qiling (`aws ec2 stop-instances --instance-ids i-<...>`, 2-bo'lim): disk va Elastic IP haqi davom etishini unutmang.

Shu 8 qadamda ko'rganingiz: arxitektura deploy'dan oldin tekshiriladi va rasmiy image'lar manifest list (3-bo'lim); dastur porti publish qilinmaydi, tashqariga faqat proxy chiqadi va mijoz IP'si header orqali uzatiladi (4-bo'lim); restart policy har konteynerda (5-bo'lim); log stdout'dan o'qiladi (7-bo'lim); yangilashdagi uzilish eski va yangi konteyner orasidagi bo'shliq, rollback esa oldingi aniq tag (8-bo'lim). Vazifalarda xuddi shu zanjirni o'z dasturingiz, database, Compose, domen va TLS bilan qurasiz.

---

## Vazifalar

Ish papkasi: `cloud/04-deployment/` (`make new m=cloud n=04 name=deployment` bilan host'da yarating). Javoblar shu papkadagi `README.md` ga, har vazifa `## N. Title` sarlavhasi ostida: bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Buyruq host'da yoki serverda bajarilgani prompt'dan ko'rinib tursin; host'dagi natija qaysi mashinada (Zorin yoki macOS) olinganini yozing. So'ralgan fayllar (`compose.yaml`, `Caddyfile`, skriptlar, unit fayllar, `RUNBOOK.md`) shu papkada saqlanadi va serverga `scp` bilan ko'chiriladi. Host'da ishlaydigan skriptlar (`provision.sh`, `leftovers.sh`) ikkala mashinada ishlaydigan portable bash bo'lsin; `deploy.sh`, `backup.sh`, `restore.sh` qayerda ishlashini (host yoki server) skript boshidagi kommentda yozing. `.env`, kalitlar, account ID va haqiqiy secret'lar commit qilinmaydi, faqat `.env.example`. Har mashg'ulot oxirida instansni stop qiling, mashinani almashtirganda Laboratoriya bo'limidagi ro'yxatni (profil, SSH kaliti, registry login, SSH manba IP'si) bajaring.

### A. Server va image

1. **Preflight and plan.** `aws sts get-caller-identity`, budget'lar, `leftovers.sh` natijasini tekshiring. Bu darsda yaratiladigan har resursni jadvalga yozing: nomi, nima uchun kerak, pullikmi, narx sahifasi havolasi, qachon o'chiriladi. 1-bo'limdagi sxemani o'z dasturingiz, domeningiz va portlaringiz bilan qayta chizing. Yo'nalish: 1-bo'lim, "Mexanizm: so'rov yo'li" va Laboratoriya bo'limi.

2. **Provision the server.** CLI bilan yarating: security group (22 sizning IP'dan, 80 va 443 hamma joydan), Ubuntu 24.04 instans (eng kichik tip, 3-darsdagi key pair), Elastic IP. Docker Engine'ni rasmiy qo'llanma bo'yicha o'rnatadigan user data skriptini (`user-data.sh`) yozing. Instans tayyor bo'lgach `docker version`, `docker compose version`, `systemctl is-enabled docker` natijalarini ko'rsating. Buyruqlarni `provision.sh` ga yig'ing. Har resursga `project=devops-course` tag qo'ying, `provision.sh` ikkala mashinada ishlasin. Yo'nalish: 2-bo'lim, "Mexanizm".

3. **Ship the image.** Dasturingiz image'ini server arxitekturasiga mos qilib, versiya tag'i bilan build qiling va registry'ga push qiling (ECR yoki docker modulidagi registry). ECR bo'lsa: repozitoriy yarating, instansga faqat o'qish huquqli role biriktiring va serverda access key'siz `docker pull` qiling. Boshqa registry bo'lsa: serverda login credential'i qayerda saqlanishini va uning xavfini yozing. Keyin ataylab boshqa arxitektura uchun (`--platform` bilan, masalan server `amd64` bo'lsa `linux/arm64`) sinov tag'i bilan build va push qilib serverda ishga tushiring: xatoni yozing, `docker image inspect` da arxitektura qayerda ko'rinishini ko'rsating va sinov tag'ini o'chiring. Qaysi mashinada build qilganingizni va u yerda `--platform` kerak bo'lgan-bo'lmaganini yozing. Yo'nalish: 3-bo'lim, "Mexanizm: arxitektura".

### B. Proxy, DNS, TLS

4. **Run the stack.** Serverda `/opt/app/` ichida `compose.yaml` yozing: dastur, PostgreSQL (volume bilan, port publish qilinmagan), Caddy. Hamma servisda restart policy, dasturda `healthcheck`, dastur database'ni `service_healthy` sharti bilan kutadi. Hozircha Caddy'da domen o'rniga `:80` ishlating. Ish mashinasidan `curl http://<EIP>/healthz` ishlashini ko'rsating. `docker compose ps` va serverda `sudo ss -tlnp` natijasida qaysi portlar tashqariga ochiq? Yo'nalish: 4-bo'lim, "Mexanizm: ichki tarmoqdagi nom" va 5-bo'lim, "Mexanizm: tirik va sog'lom".

5. **DNS record.** Subdomeningiz uchun `A` yozuvni Elastic IP ga qarating. `dig +short`, `dig +trace` va boshqa resolver (`@1.1.1.1`, `@8.8.8.8`) bilan tekshiring. TTL qancha? Yozuvni o'zgartirsangiz eski qiymat qancha vaqt kesh'da qolishi mumkin va bu deploy paytida IP almashtirishga qanday ta'sir qiladi? Yo'nalish: 4-bo'lim, "DNS".

6. **TLS with staging.** Caddyfile'da domeningizni yozing va global blokda Let's Encrypt staging CA'ni ko'rsating. Caddy loglarida sertifikat olish jarayonini kuzating va bosqichlarini (challenge turi, tekshiruv, sertifikat) o'z so'zingiz bilan yozing. `curl -v https://...` nima deydi va nima uchun? `openssl s_client -connect <domain>:443 -servername <domain>` bilan issuer'ni ko'rsating. Yo'nalish: 4-bo'lim, "Let's Encrypt va ACME qanday ishlaydi".

7. **Break the challenge.** Staging rejimida qoling. Caddy volume'ini o'chirib (sertifikat qaytadan so'ralsin), security group'dan 80-portni olib tashlang va stack'ni qayta ko'taring. Caddy logidagi xatoni to'liq o'qing: kim kimga ulana olmadi? 80-portni qaytaring va tiklanishini kuzating. Xuddi shu xato production'da sertifikat yangilanadigan kuni qanday ko'rinishda paydo bo'lar edi? Agar 80-port yopiq bo'lsa ham sertifikat olinsa, logdan qaysi challenge turi o'tganini toping va nima uchun o'tganini tushuntiring. Yo'nalish: 4-bo'lim, "Let's Encrypt va ACME qanday ishlaydi" (challenge turlari).

8. **Production certificate.** Staging qatorini olib tashlab haqiqiy sertifikat oling. `curl -I http://...` (redirect), `curl -I https://...`, sertifikatning amal qilish muddati va issuer'ini ko'rsating. Stack'ni `down` va `up` qiling: sertifikat qayta so'raldimi, nima uchun yo'q? Rate limit sahifasidan bitta domen uchun sizga tegishli ikkita limitni yozing. Yo'nalish: 4-bo'lim, "Reverse proxy nima" (`/data` volume) va "Misol: sertifikatni tashqaridan o'qish".

9. **nginx and certbot.** Qiyoslash uchun. Vaqtincha Caddy o'rniga nginx konteynerini reverse proxy qiling: `proxy_pass`, `Host` va `X-Forwarded-*` header'lari, HTTP'dan HTTPS'ga redirect. Sertifikatni certbot hujjatidagi usullardan biri bilan (staging'da, `--dry-run` yoki `--test-cert`) oling. Yangilanish qanday rejalashtiriladi va nginx yangi sertifikatni qanday o'qiydi? Caddy bilan solishtirganda qaysi ishlarni o'zingiz qilishingizga to'g'ri keldi? Oxirida Caddy'ga qayting. `nginx.conf` ni papkada saqlang. Yo'nalish: 4-bo'lim, "Reverse proxy nima" va Manbalardagi nginx, certbot hujjatlari.

### C. Ekspluatatsiya

10. **Survive a reboot.** Uch sinov o'tkazing va har biridan keyin tashqaridan `curl` bilan tekshiring: (a) dastur jarayonini `docker kill` bilan o'ldirish, (b) `sudo systemctl restart docker`, (c) `sudo reboot`. Har holatda xizmat qancha vaqtda qaytdi (`while` sikli va `curl` bilan o'lchang)? Keyin dastur servisini `restart: "no"` qilib (c) ni takrorlang va farqni ko'rsating. Ixtiyoriy: 5-bo'limdagi systemd unit bilan xuddi shu sinovlar. Yo'nalish: 5-bo'lim, "Bu nima".

11. **Crash loop.** `.env` da database parolini ataylab noto'g'ri qiling va stack'ni qayta ko'taring. `docker compose ps`, `docker compose logs`, `docker inspect` dagi `RestartCount` bilan nima bo'layotganini aniqlang. Tashqaridan foydalanuvchi nimani ko'radi (proxy qanday status qaytaradi)? Tuzating. Yo'nalish: 5-bo'lim, "Misol: holatni o'qish".

12. **Secrets handling.** Serverda `.env` egasi va huquqlarini tekshiring. Secret'ni uch joydan o'qib ko'rsating: `docker inspect`, `docker compose exec app env`, `/proc/<pid>/environ` (host'dan). Kim bularni o'qiy oladi? `docker history` bilan image'ingizda secret yo'qligini isbotlang. Database parolini almashtirish (rotation) tartibini qadam-baqadam yozing va bajaring: qaysi nuqtada uzilish bo'ldi? Yo'nalish: 6-bo'lim, "Mexanizm va chegaralari".

13. **Logs and disk.** Log rotation'siz konteynerda `docker inspect --format '{{.LogPath}}'` bilan log faylini toping. Dasturga sikl bilan bir necha ming so'rov yuborib fayl o'sishini ko'rsating. Hamma servisga `max-size` va `max-file` qo'ying, qayta yarating va rotation ishlashini isbotlang. `df -h` va `docker system df` natijasini yozing: diskni yana nima egallaydi va qanday tozalanadi? Yo'nalish: 7-bo'lim, "Mexanizm".

14. **Deploy and rollback.** Dasturda ko'rinadigan o'zgarish qiling (masalan `/version` javobi), yangi tag bilan push qiling. Ish mashinasida `while true; do curl -s -o /dev/null -w '%{http_code}\n' https://<domain>/healthz; sleep 0.2; done` ishlab turganda serverda yangilang. Nechta so'rov xato oldi, qanday kodlar bilan? Keyin oldingi tag'ga rollback qiling va vaqtini o'lchang. Yangilash va rollback buyruqlarini `deploy.sh <tag>` skriptiga yozing: tag'ni almashtiradi, pull qiladi, ko'taradi, health endpoint javob berguncha kutadi, bermasa xato kodi bilan chiqadi. Yo'nalish: 8-bo'lim, "Bu nima" va 3-bo'lim, "Tag qoidalari".

15. **Reduce downtime.** 14-vazifadagi uzilishni kamaytiring. Kamida ikkitasini qo'llang: dasturda graceful shutdown (`SIGTERM`), Caddy'da upstream retry, dasturning ikki nusxasi va navbat bilan yangilash, blue-green almashtirish. 14-vazifadagi o'lchovni takrorlang va natijalarni jadvalda solishtiring. Nolga tushdimi? Tushmagan bo'lsa qolgan uzilish qayerdan kelyapti? Bitta serverda bu yondashuvning chegarasi nima? Yo'nalish: 8-bo'lim, "Mexanizm: uzilish qayerdan keladi".

16. **Backup to S3.** Backup uchun bucket yarating (Block Public Access, versioning, 30 kundan eski backup'larni o'chiradigan lifecycle). Instans role'iga faqat shu bucket'ning `db/` prefiksiga `s3:PutObject` beradigan policy (`backup-policy.json`) qo'shing. `backup.sh` yozing: `pg_dump`, siqish, S3 ga yuklash, xato bo'lsa noldan farqli exit code. Uni systemd timer bilan kuniga bir marta ishlaydigan qiling (`backup.service`, `backup.timer`), `systemctl list-timers` va qo'lda ishga tushirilgan natijani ko'rsating. Serverdan backup'ni o'qish yoki o'chirishga urinib ko'ring: nima bo'ladi va bu nima uchun yaxshi? Yo'nalish: 9-bo'lim, "Mexanizm" va "Misol: pipe ichidagi xato qanday yo'qoladi".

17. **Restore drill.** Database'ga bir nechta taniqli yozuv qo'shing, backup oling, keyin database volume'ini butunlay o'chiring (`docker compose down`, `docker volume rm`). Ish mashinasidagi admin profil bilan oxirgi dump'ni olib, toza database'ga tiklang va yozuvlar qaytganini ko'rsating. Tiklash qancha vaqt oldi (RTO)? Backup jadvalingiz bo'yicha eng yomon holatda qancha ma'lumot yo'qoladi (RPO)? Tiklash buyruqlarini `restore.sh` ga yozing. Yo'nalish: 9-bo'lim, "Mexanizm" (RPO va RTO).

18. **Hardening pass.** Tekshiring va kerak bo'lsa tuzating, har biriga dalil keltiring: `sudo sshd -T` da parol va root login o'chirilgan; `unattended-upgrades` yoqilgan va oxirgi ishlagan vaqti; `apt list --upgradable` va reboot kerakligi; konteynerlar root bo'lmagan foydalanuvchida (`docker compose exec app id`); tashqi skaner natijasi (ish mashinasidan `nmap -Pn <EIP>` faqat o'zingizning serveringizga). Keyin tajriba: database'ga `ports: ["5432:5432"]` qo'shing, serverda `ufw` ni yoqib (avval `ufw allow OpenSSH`!) `ufw deny 5432` qiling, security group'da 5432 ni vaqtincha o'z IP'ingizga oching va tashqaridan ulanib ko'ring. Natijani izohlang, hammasini qaytaring. `nmap` host'da bo'lmasa Laboratoriya jadvalidagi usul bilan o'rnating. Yo'nalish: 10-bo'lim, "Mexanizm: Docker va host firewall".

### D. Managed variantlar va mini-loyiha

19. **Managed comparison.** Amaliyotsiz, hujjat asosida. Shu dasturni ECS Fargate (database RDS da) va App Runner yoki Elastic Beanstalk'da ishlatish uchun jadval tuzing: bu darsda qo'lda qilgan har ish (server patch, TLS, restart, deploy, rollback, loglar, backup, secret'lar) har variantda kimda qoladi va qaysi AWS xizmati bajaradi. Pricing Calculator'da uch variantning oylik narxini taxminlang (havola va sana bilan). Qaysi sharoitda qaysi birini tanlar edingiz? Tanlangan xizmatlarning hozir yangi mijozlar uchun ochiqligini hujjatdan tekshirib yozing. Yo'nalish: 11-bo'lim, "Bu nima".

20. **Runbook.** Mini-loyiha, 1-qism. `RUNBOOK.md` yozing: shu serverni va dasturni hech qachon ko'rmagan muhandis faqat shu hujjat bilan ishlay olsin. Bo'limlar: arxitektura sxemasi va resurslar ro'yxati; toza akkauntdan to'liq deploy (buyruqlar tartib bilan, skriptlaringizga havola); yangi versiya chiqarish va rollback; secret'lar qayerda va qanday almashtiriladi; backup va tiklash (RPO, RTO raqamlaringiz bilan); loglar qayerda; sertifikat qanday yangilanadi va muddati qanday tekshiriladi; besh nosozlik ssenariysi (sayt ochilmayapti, 502, disk to'ldi, sertifikat muddati o'tdi, server yo'qoldi) uchun tashxis qadamlari; to'liq teardown. Yo'nalish: har bo'limning "Real ishda qachon kerak" qismi.

21. **Rebuild from the runbook.** Mini-loyiha, 2-qism. Runbook'ni sinang: joriy instansni terminate qiling (Elastic IP va backup bucket qolsin), faqat `RUNBOOK.md` va skriptlaringizga qarab yangi instansda hammasini qayta ko'taring va database'ni backup'dan tiklang. Vaqtni o'lchang. Runbook'da yo'q bo'lib, xotiradan qilgan har qadamingizni yozib boring va runbook'ni to'ldiring. Yakunda: sayt HTTPS bilan ishlaydi, ma'lumot joyida, `curl` natijasi `README.md` da. Yo'nalish: 2-bo'lim, "Nima uchun shunday".

22. **Teardown and proof.** Mini-loyiha, 3-qism. Runbook'ning teardown bo'limi bo'yicha hammasini o'chiring: instans, Elastic IP, security group, IAM role va instance profile, policy'lar, ECR repozitoriy (image'lari bilan), backup bucket (hamma versiyalari bilan), DNS yozuvi. `leftovers.sh` ga ECR repozitoriylar va IAM role'lar tekshiruvini qo'shing, natijasi bo'sh bo'lsin. Ertasi kuni Bills sahifasidan bu dars qanchaga tushganini xizmatlar bo'yicha yozing va 1-vazifadagi rejangiz bilan solishtiring. Yo'nalish: Laboratoriya bo'limi, "Xarajat" va "Dars oxirida".

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
- Mac'da yig'ilgan image `x86_64` serverda nima uchun ishlamaydi? Uch yechimning har biri nimani osonlashtiradi va evaziga nimani qiyinlashtiradi?
- Mashg'ulot oxirida stop qilingan instans nima uchun baribir xarajat keltiradi va Elastic IP'siz stop, start qilinsa DNS bilan nima bo'ladi?
