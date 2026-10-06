# Konteynerlash moduli rejasi (Docker, Compose, orkestratsiyaga kirish)

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. `docker run` yoki tayyor `Dockerfile` ni ishlatgan bo'lishi mumkin, lekin konteyner ichida aslida nima borligi (namespace, cgroup, layer, bridge, NAT) yangi mavzu deb olinadi va har darsda noldan, mexanizmi va ishlaydigan misoli bilan tushuntiriladi. `linux` va `network` modullari oldindan o'tilgan bo'lishi kerak.

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni ishlatib, `Dockerfile` va `compose.yaml` fayllarni o'zingiz yozasiz, men tekshirib xatolar, xavfsizlik va idiomalarni ko'rsataman.
Har dars uchun alohida papka: `docker/01-containers/`, `docker/02-images/` va hokazo. Yaratish: `make new m=docker n=01 name=containers`.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har darsning muddati o'sha darsning `Taxminiy vaqt` qatorida, bu jadval ularning yig'indisi. Hafta 5 o'quv kuni deb olinadi.

| Bosqich | Darslar | Dars bo'yicha (kun) | Siz uchun | Sabab |
|---------|---------|---------------------|-----------|-------|
| I - Konteyner va image | 2 | 1-dars: 4, 2-dars: 6 | 10 kun | Namespaces, cgroups, signal va PID 1, layer va cache mexanizmi, multi-stage, non-root, arxitektura (`amd64` va `arm64`) va multi-platform build |
| II - Ma'lumot, tarmoq, Compose | 2 | 3-dars: 5, 4-dars: 5 | 10 kun | Volume hayot sikli, UID muammolari, bridge DNS, NAT, healthcheck, Compose modeli va `depends_on`. 3-darsda vazifalarning bir qismi `lab` VM ichidagi Docker'da |
| III - Orkestratsiyaga kirish | 1 | 5-dars: 7 | 7 kun | Butunlay yangi soha, qisqartirilmaydi. Mini-loyiha shu yerda |
| **Jami** | **5** | | **27 kun (5 hafta va 2 kun)** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, yaratilgan resurslar tozalangan va siz mexanizmni o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS 18 (`amd64`), uyda macOS (Apple Silicon, `arm64`). Docker ikkalasida `SETUP.md` bo'yicha o'rnatilgan. Har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.

| Muhit | Zorin (ofis) | macOS (uy) | Nima uchun |
|-------|--------------|------------|------------|
| Host'dagi Docker | Docker Engine, to'g'ridan-to'g'ri host kernel'ida, image'lar `amd64` | Docker Desktop, engine yashirin Linux VM ichida, image'lar `arm64` | oddiy `docker` ishlari: `run`, `build`, `logs`, `exec`, `localhost` dagi published portlar, Compose, Swarm, `kind` |
| `lab` VM ichidagi Docker (`docker.io`, network modulining 1-darsida o'rnatilgan) | bir xil | bir xil | engine'ning host tomonini ko'rish kerak bo'lgan vazifalar: host'dagi `ps`, `/proc/<pid>/ns`, cgroup fayllari, `/var/lib/docker`, `docker0` va veth, konteyner IP'lari, iptables qoidalari. macOS'da bular host'da ko'rinmaydi, shuning uchun ikkala mashinada VM ishlatiladi (1, 2 va 3-darslar). VM kichik: 2 CPU, 2G, 10G |

- Versiyalar har mashinada boshqa, darslar ularga tayanmaydi: `docker version`, `docker info`, `docker compose version` bilan o'zingizda tekshiring. Image store turi ham farq qilishi mumkin (`docker info` dagi `Storage Driver`), 2-dars buni tekshirishni o'rgatadi.
- Host'da ham, VM'dagi `ubuntu` foydalanuvchisi ham `docker` guruhida, `sudo` kerak emas. Esda tuting: `docker` guruhi a'zoligi amalda root huquqiga teng (1-dars, 2-bo'lim).
- Arxitektura: Mac'da yig'ilgan image `linux/arm64`, Zorin'da `linux/amd64`. Bir arxitekturali image ikkinchi mashinada `exec format error` beradi yoki emulyatsiyada ishlaydi. 2-dars multi-platform build'ni o'rgatadi, keyingi darslar shunga tayanadi.
- Konteyner ichida paket o'rnatish, user yaratish, fayl tizimini buzish mumkin, bu host'ga ta'sir qilmaydi. Host'ning o'zida tizim holati o'zgartirilmaydi. Istisnolar foydalanuvchi darajasidagi asboblar: `hadolint` (2-dars), `kind` va `kubectl` (5-dars). Zorin'da `~/.local/bin` ga `sudo` siz, macOS'da Homebrew orqali.
- 5-darsda `docker swarm init` host'dagi Docker'ni vaqtincha Swarm rejimiga o'tkazadi. Har mashg'ulot oxirida `docker swarm leave --force` bilan qaytariladi: holat mashinalar orasida ko'chmaydi.
- Registry: Docker Hub yoki GitHub Container Registry (GHCR) akkaunti kerak bo'ladi (2-dars). Token `.env` yoki shell history'ga emas, `docker login --password-stdin` orqali beriladi, har mashinada alohida saqlanadi va hech qachon commit qilinmaydi.
- Laboratoriya holati (konteyner, image, volume) mashinalar orasida ko'chmaydi, javoblar va fayllar (`Dockerfile`, `compose.yaml`, skriptlar) git orqali ko'chadi.
- Har dars oxirida tozalash majburiy: konteynerlar, image'lar, volume'lar, network'lar, host'da ham, `lab` VM'da ham. Tekshirish: `docker ps -a`, `docker volume ls`, `docker network ls`, `docker system df`.
- Ikkala mashinada boshqa loyihalarning konteyner va volume'lari bor. Dars resurslari prefiks yoki label bilan nomlanadi (`lesson=01`, `l02-`, `l3-`, `l4-`, `l5-`) va faqat shular o'chiriladi. `docker system prune`, `docker volume prune -a`, `docker rm -f $(docker ps -aq)` bu modulda ishlatilmaydi.

## I bosqich - Konteyner va image

1. **Konteynerlar**: namespaces, cgroups, konteyner va VM farqi, Docker arxitekturasi (CLI, dockerd, containerd, shim, runc), `run`/`ps`/`logs`/`exec`/`stop`/`rm`, hayot sikli va holatlar, PID 1 va signallar, `-d`/`-it`/`--rm`, port publishing, env, resurs limitlari, restart policy, `inspect`
2. **Image'lar**: layer va union filesystem (OverlayFS), registry/tag/digest, Dockerfile instruksiyalari, build cache va layer tartibi, `CMD` va `ENTRYPOINT`, exec va shell form, `.dockerignore`, multi-stage build, kichik base image'lar (alpine, slim, distroless, scratch), non-root user, BuildKit va buildx, zaiflik skaneri (Trivy, Docker Scout), Docker Hub va GHCR ga push, Node.js va Go ilovasini konteynerlash

## II bosqich - Ma'lumot, tarmoq, Compose

3. **Volume va tarmoqlar**: volume, bind mount, tmpfs, ma'lumot hayot sikli, volume backup/restore, ruxsat va UID muammolari, default va user-defined bridge, konteyner DNS, `host` va `none` driver'lari, port publishing va NAT, healthcheck
4. **Docker Compose**: `compose.yaml` tuzilishi, services/networks/volumes, `depends_on` va healthcheck shartlari, `.env` va interpolation, profiles, override fayllar, compose ichida build, secrets, `up`/`down -v`/`logs`/`exec`, `compose watch`, ko'p servisli stack (app + Postgres + Redis + nginx reverse proxy)

## III bosqich - Orkestratsiyaga kirish

5. **Orkestratsiyaga kirish**: nima uchun orkestratsiya (scheduling, self-healing, scaling, service discovery, rolling update), Docker Swarm amalda (swarm init, service, replicas, stack deploy, rolling update va rollback, secrets), Kubernetes arxitekturasi va asosiy obyektlari konseptual darajada, Swarm va Kubernetes taqqosi, `kind` bilan birinchi tanishuv, modul mini-loyihasi

## Yakuniy natija

Moduldan keyin siz:

- Konteyner nima ekanini kernel darajasida (namespaces, cgroups, OverlayFS) tushuntira olasiz va VM bilan farqini aytasiz.
- Ishlamayotgan konteynerni `ps`, `logs`, `inspect`, `exec`, exit code va `OOMKilled` orqali diagnostika qilasiz.
- Node.js va Go ilovasi uchun kichik, non-root, cache'dan to'g'ri foydalanadigan multi-stage `Dockerfile` yozasiz, image'ni skanerlab registry'ga push qilasiz.
- Ma'lumotni volume'da saqlaysiz, backup va restore qilasiz, konteynerlar orasidagi tarmoqni loyihalaysiz va nosozligini topasiz.
- Bir necha servisli muhitni `compose.yaml` bilan tavsiflaysiz: healthcheck, ishga tushish tartibi, secrets, profile va override bilan.
- Orkestrator qaysi muammolarni yechishini bilasiz, Swarm'da stack deploy, rolling update va rollback qila olasiz, Kubernetes modulini boshlash uchun tushunchalar tayyor.

## Ataylab kiritilmagan

- Kubernetes amaliyoti (manifestlar, Helm, Ingress, RBAC): alohida Kubernetes modulida. Bu yerda faqat konsepsiya va bitta `kind` vazifasi.
- CI/CD ichida image build va push (GitHub Actions, cache export): CI/CD modulida.
- Podman, rootless Docker, user namespace remapping, gVisor va Kata Containers: faqat tilga olinadi.
- O'z registry'ingizni ko'tarish (Harbor), image signing (cosign), SBOM siyosati: xavfsizlik mavzulari bilan birga keyinroq.
- Docker Desktop'ning grafik interfeysi va kengaytmalari: uyda macOS'da Docker Desktop engine sifatida ishlatiladi, lekin hamma ish ikkala mashinada bir xil ishlaydigan `docker` CLI orqali bajariladi.
- Windows konteynerlari.

## Manbalar

- Docker rasmiy hujjatlari: https://docs.docker.com/ (Engine, Build, Compose, Swarm bo'limlari)
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Compose file reference: https://docs.docker.com/reference/compose-file/
- Kane, Matthias, "Docker: Up & Running" (3-nashr, O'Reilly): I–II bosqich uchun asosiy kitob
- Rice, "Container Security" (O'Reilly): namespaces, cgroups, capabilities, image xavfsizligi
- Poulton, "Docker Deep Dive": qisqa va amaliy, Swarm bo'limi bilan
- OCI spetsifikatsiyalari: https://github.com/opencontainers/runtime-spec va https://github.com/opencontainers/image-spec
- man sahifalari: `man 7 namespaces`, `man 7 cgroups`, `man 7 capabilities`
- Kubernetes konsepsiyalari: https://kubernetes.io/docs/concepts/ (5-dars uchun)
