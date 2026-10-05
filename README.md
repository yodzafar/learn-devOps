# dev-ops

DevOps kursi rejasi bo'yicha shaxsiy o'quv loyihasi. To'qqiz modul ketma-ket o'tiladi: har modulda reja, darslar (nazariya + vazifalar) va progress fayli bor.

## Tuzilma

```
dev-ops/
├── ROADMAP.md               # haftalar bo'yicha jadval, bog'liqliklar, nazorat nuqtalari
├── SETUP.md                 # ikki mashinada (Zorin va macOS) bir xil laboratoriya
├── PROGRESS.md              # modullar bo'yicha indeks
├── Makefile                 # barcha buyruqlar shu yerda, `make help`
│
├── linux/                   # 1) Operatsion tizimlar (Linux)
│   ├── docs/                #    00-reja.md, 01-intro.md, ..., PROGRESS.md
│   └── 01-intro/            #    mening ishim: README.md (javoblar) + skriptlar
│
├── git/                     # 2) Git va git hosting'lar
├── network/                 # 3) Kompyuter tarmoqlari
├── docker/                  # 4) Konteynerlash: Docker, Compose, Swarm
├── cloud/                   # 5) Cloud provayderlar (AWS asosida)
├── cicd/                    # 6) CI/CD: GitHub Actions, GitLab CI, Jenkins, TeamCity
├── iac/                     # 7) Infrastructure as Code: Ansible, Terraform
├── observability/           # 8) Prometheus, Grafana, Alertmanager, Loki, Tempo, Pyroscope, OpenTelemetry
│   └── stack/               #    barcha darslar davomida kengayadigan yagona compose stack
└── kubernetes/              # 9) Kubernetes
```

Har modul ichida bir xil tartib:

- `<modul>/docs/00-reja.md`: modul rejasi, vaqt hisobi, laboratoriya muhiti.
- `<modul>/docs/NN-nom.md`: dars. Nazariya, tuzoqlar, manbalar, vazifalar, o'zini tekshirish savollari.
- `<modul>/docs/PROGRESS.md`: vazifalar holati.
- `<modul>/NN-nom/`: sizning ishingiz. `make new` bilan yaratiladi.

## Modullar va darslar

| # | Modul | Darslar | Reja |
|---|-------|---------|------|
| 1 | Linux | 13 | `linux/docs/00-reja.md` |
| 2 | Git | 4 | `git/docs/00-reja.md` |
| 3 | Tarmoqlar | 6 | `network/docs/00-reja.md` |
| 4 | Docker | 5 | `docker/docs/00-reja.md` |
| 5 | Cloud | 4 | `cloud/docs/00-reja.md` |
| 6 | CI/CD | 5 | `cicd/docs/00-reja.md` |
| 7 | IaC | 5 | `iac/docs/00-reja.md` |
| 8 | Observability | 7 | `observability/docs/00-reja.md` |
| 9 | Kubernetes | 15 | `kubernetes/docs/00-reja.md` |

## Ishlash tartibi

1. Darsni o'qing: `make lesson m=linux n=01` yoki faylni muharrirda oching.
2. Ish papkasini yarating: `make new m=linux n=01 name=intro`.
3. Vazifalarni bajaring. Javoblar ish papkasidagi `README.md` da: har vazifa uchun `## N. Title`, buyruqlar, natijaning muhim qismi, o'z so'zingiz bilan izoh. Vazifa so'ragan fayllar (skript, `Dockerfile`, YAML, `.tf`) shu papkada.
4. `make check` toza bo'lsin.
5. Claude'ga "tekshir" deng. U har vazifaga `✓` yoki `✗ sabab` beradi, progress fayllarini yangilaydi va qabul qilingan vazifalarni commit qiladi.

Qoidalar:

- Claude vazifani bajarib bermaydi, faqat tushuntiradi va tekshiradi (`CLAUDE.md`).
- Tizimni o'zgartiradigan vazifalar VM yoki konteynerda bajariladi, ish mashinasida emas.
- Cloud vazifalaridan keyin resurslar o'chiriladi va o'chirilgani tekshiriladi.
- Secret, kalit, `.env`, `terraform.tfstate`, kubeconfig commit qilinmaydi (`make secrets`).

## Buyruqlar

```
make help                                  barcha buyruqlar
make list                                  modullar va darslar ro'yxati
make lesson m=linux n=03                   darsni terminalda o'qish
make new m=linux n=03 name=basic-commands  yangi ish papkasi
make check                                 shellcheck + yamllint + hadolint + terraform fmt + secrets
```

## Boshlash

0. `SETUP.md` ni har ikkala mashinada (ofis: Zorin, uy: macOS) bajaring: Docker, Multipass va `lab` VM.
1. `ROADMAP.md` ni o'qing, keyin `linux/docs/00-reja.md` ni.
2. `linux/docs/01-intro.md` dagi vazifalarni `linux/01-intro/` da bajaring.
3. Tartib: Linux → Git → Tarmoqlar → Docker → Cloud → CI/CD → IaC → Observability → Kubernetes.
