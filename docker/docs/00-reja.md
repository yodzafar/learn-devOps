# Konteynerlash moduli rejasi (Docker, Compose, orkestratsiyaga kirish)

Ishlash tartibi: men nazariya va vazifalar beraman, siz buyruqlarni ishlatib, `Dockerfile` va `compose.yaml` fayllarni o'zingiz yozasiz, men tekshirib xatolar, xavfsizlik va idiomalarni ko'rsataman.
Har dars uchun alohida papka: `docker/01-containers/`, `docker/02-images/` va hokazo. Yaratish: `make new m=docker n=01 name=containers`.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Konteyner va image | 2 | 9–10 kun | 7 kun | `docker run` va tayyor `Dockerfile` dan nusxa olish tanish. Yangi: namespaces, cgroups, signal va PID 1, layer cache mexanizmi, multi-stage, non-root |
| II - Ma'lumot, tarmoq, Compose | 2 | 7–8 kun | 6 kun | Compose'ni frontend loyihalarda ishlatgansiz. Yangi: volume hayot sikli, UID muammolari, bridge DNS, NAT, healthcheck bilan `depends_on` |
| III - Orkestratsiyaga kirish | 1 | 5 kun | 4–5 kun | Butunlay yangi soha, qisqartirilmaydi. Mini-loyiha shu yerda |
| **Jami** | **5** | **3–3.5 hafta** | **2.5–3 hafta** | |

Bir darsni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, yaratilgan resurslar tozalangan va siz mexanizmni o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

- Barcha vazifalar ish mashinasidagi Docker Engine'da bajariladi. Reja yozilgan paytdagi versiyalar: Docker Engine 29.8, containerd 2.3, runc 1.5, Compose v5.5, buildx 0.37, cgroup v2, containerd image store (`docker info` da `Storage Driver: overlayfs`, `driver-type: io.containerd.snapshotter.v1`). O'zingizda `docker version` va `docker info` bilan tekshiring.
- Siz `docker` guruhidasiz, shuning uchun `sudo` kerak emas. Esda tuting: `docker` guruhi a'zoligi amalda root huquqiga teng (1-dars, 2-bo'lim).
- Konteyner ichida paket o'rnatish, user yaratish, fayl tizimini buzish mumkin, bu ish mashinasiga ta'sir qilmaydi. Ish mashinasining o'zida paket o'rnatilmaydi. Istisnolar: `kind` va `kubectl` binary'lari (5-dars, `~/.local/bin` ga, `sudo` siz).
- 5-darsda `docker swarm init` ish mashinasidagi Docker'ni vaqtincha Swarm rejimiga o'tkazadi. Dars oxirida `docker swarm leave --force` bilan qaytariladi.
- Registry: Docker Hub yoki GitHub Container Registry (GHCR) akkaunti kerak bo'ladi (2-dars). Token `.env` yoki shell history'ga emas, `docker login --password-stdin` orqali beriladi va hech qachon commit qilinmaydi.
- Har dars oxirida tozalash majburiy: konteynerlar, image'lar, volume'lar, network'lar. Tekshirish: `docker ps -a`, `docker volume ls`, `docker network ls`, `docker system df`.
- Mashinada boshqa loyihalarning konteyner va volume'lari bor. Dars resurslari prefiks yoki label bilan nomlanadi (`lesson=01`, `lesson02/`, `l3-`, `l4-`, `l5-`) va faqat shular o'chiriladi. `docker system prune`, `docker volume prune -a`, `docker rm -f $(docker ps -aq)` bu modulda ishlatilmaydi.

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
- Docker Desktop va uning kengaytmalari: sizda Linux'da Docker Engine bor, Desktop kerak emas.
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
