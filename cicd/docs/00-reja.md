# CI/CD o'quv rejasi (pipeline'dan avtomatik deploy'gacha)

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. PR'larda CI tekshiruvlarini (lint, test, preview deploy) ko'rgan, lekin pipeline'ning egasi bo'lmagan deb olinadi: runner, artifact, secret, environment, deploy strategiyasi va OIDC noldan, mexanizmi va ishlaydigan misoli bilan tushuntiriladi. `git`, `docker` va `cloud` modullari oldindan o'tilgan bo'lishi kerak.

Ishlash tartibi: men nazariya va vazifalar beraman, siz pipeline yozasiz va ishga tushirasiz, men `README.md`, pipeline fayllari va run natijalarini tekshirib xato va xavfsizlik muammolarini ko'rsataman.
Har dars uchun alohida papka: `cicd/01-intro/`, `cicd/02-github-actions/` va hokazo. Yaratish: `make new m=cicd n=01 name=intro`.

Kurs yo'l xaritasidagi mavzular: "CI/CD haqida ma'lumot" (1-dars), "Tools: Github actions, Gitlab CI, Jenkins, Teamcity" (2–4-darslar), "Dasturlarni serverga avtomatik deploy" (5-dars).

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Har darsning muddati o'sha darsning `Taxminiy vaqt` qatorida, bu jadval ularning yig'indisi. Hafta 5 o'quv kuni deb olinadi.

| Bosqich | Darslar | Dars bo'yicha (kun) | Siz uchun | Sabab |
|---------|---------|---------------------|-----------|-------|
| I - Tushunchalar | 1 | 1-dars: 3 | 3 kun | CI, delivery va deployment farqi, pipeline anatomiyasi, artifact promotion, secret'lar, DORA, pipeline'ni lokal modellashtirish |
| II - Asboblar | 3 | 2-dars: 6, 3-dars: 5, 4-dars: 6 | 17 kun | Workflow va runner mexanizmi, xavfsizlik (pin, permissions, fork), GitLab runner, Jenkins ekspluatatsiyasi. 4-dars vaqt yetmasa birinchi qisqaradi (`ROADMAP.md`) |
| III - Avtomatik deploy | 1 | 5-dars: 7 | 7 kun | Pipeline'dan SSH, immutable tag, health check, deploy strategiyalari, rollback, OIDC. Cloud VM qayta ko'tariladi |
| **Jami** | **5** | | **27 kun (5 hafta va 2 kun)** | |

Bir mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, pipeline yashil va ataylab buzilganda qizil bo'ladi, men tekshirib tasdiqlaganman, va siz har qadam nima uchun kerakligini o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

Kurs ikki mashinada o'tiladi: ofisda Zorin OS 18 (`amd64`), uyda macOS (Apple Silicon, `arm64`). Pipeline'lar CI servislarida ishlaydi, shuning uchun natija qaysi mashinadan push qilinganiga bog'liq emas; mashinaga xos narsalar faqat lokal: klon, `gh` va registry login'lari, SSH kalitlar, self-hosted runner'lar va lokal CI serverlar. Har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.

| Narsa | Umumiy yoki mashinaga xos | Izoh |
|-------|---------------------------|------|
| `cicd-demo` repo (GitHub, public), uning secret, environment va run'lari | umumiy | 2-darsda yaratiladi. Pipeline fayllari repo ildizida turishi shart (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`), shu sababli ular bu o'quv repozitoriysi ichida ishlamaydi. Ish papkasidagi `README.md` ga javoblar, run havolalari va pipeline fayllarining nusxasi yoziladi |
| gitlab.com loyihasi (free tier), uning variable va pipeline'lari | umumiy | `cicd-demo` ga ikkinchi remote sifatida ulanadi. Self-managed GitLab o'rnatilmaydi (resurs talabi katta) |
| Lokal klon, ikkinchi remote, `gh auth login`, SSH kalit | mashinaga xos | har mashinada alohida sozlanadi; `gh` git modulining 4-darsida o'rnatilgan (Zorin: rasmiy apt repo, macOS: `brew install gh`) |
| Self-hosted runner'lar (GitHub, GitLab) | mashinaga xos | faqat Docker konteynerida, faqat o'z repongiz uchun. Ofisda ko'tarilgan runner uyda offline, unga mo'ljallangan job navbatda qoladi. macOS'da runner va u yig'gan image'lar `arm64`, Zorin'da `amd64` |
| Jenkins va TeamCity | mashinaga xos | host'dagi Docker konteynerlarida, named volume bilan, portlar `127.0.0.1` ga bog'langan. Holat mashinalar orasida ko'chmaydi: har asbob vazifalarini bitta mashinada tugating yoki fayllardan qayta quring. Host'ga paket o'rnatilmaydi |
| Deploy nishoni: cloud modulidagi AWS VM | umumiy | 5-darsda qayta ko'tariladi, dars oxirida o'chiriladi. Budget alert yoqilgan bo'lishi shart. AWS CLI profili va shaxsiy SSH kalit har mashinada alohida |

- **Arxitektura**: GitHub va GitLab hosted runner'lari `x86_64`, ular yig'gan image `linux/amd64`. Mac'da bunday image emulyatsiyada ishlaydi; kerak bo'lsa pipeline multi-platform image yig'adi (docker moduli, 2-dars). Deploy nishoni arxitekturasi image'ga mos bo'lishi kerak.
- **Lokal asboblar**: 1-darsda pipeline lokal modellashtiriladi, asboblar Docker konteynerida ishlaydi. `make` ikkala mashinada bor (macOS'da GNU Make 3.81, Zorin'da 4.x). `actionlint` konteyner shaklida ikkalasida ishlaydi.
- **Secret'lar**: token, SSH private key, `.env` hech qachon commit qilinmaydi va README'ga yozilmaydi. Ular faqat CI tizimining secret omborida turadi (`gh secret set` stdin'dan o'qiydi). Pipeline uchun deploy kaliti alohida yaratiladi, shaxsiy kalit bilan aralashtirilmaydi.
- **Tozalash**: har dars oxirida runner'lar ro'yxatdan chiqariladi, konteyner, volume va network'lar nomi bilan o'chiriladi (`docker system prune` ishlatilmaydi), sinov image'lari registry'dan, vaqtinchalik token'lar akkauntdan o'chiriladi. 5-dars oxirida VM, IAM role va OIDC provider o'chirilgani buyruq bilan tekshiriladi.

## I bosqich - Tushunchalar

1. **CI/CD ga kirish**: continuous integration, continuous delivery va continuous deployment farqi, pipeline anatomiyasi (stage, job, step, runner/agent, artifact, cache), pipeline as code, trunk-based development, qisqa feedback loop, build once deploy many, environment va promotion, pipeline'da secret'lar, DORA metrikalari, asboblar taqqosi. Amaliyot: kichik ilova uchun lokal "pipeline" (Makefile: lint, test, image build).

## II bosqich - Asboblar

2. **GitHub Actions**: workflow sintaksisi (`on`, `jobs`, `steps`), runner'lar, action'lar va SHA bo'yicha pin qilish, context va expression'lar, matrix, cache, artifact, secret va variable'lar, environment va approval, `GITHUB_TOKEN` permissions, reusable workflow va composite action, concurrency, Docker image'ni GHCR'ga push qilish, debug, `gh run`, self-hosted runner va uning xavfi.
3. **GitLab CI**: `.gitlab-ci.yml` (stages, jobs, `rules`, `needs`/DAG, variables), cache va artifacts farqi, services, `include` va shablonlar, environments, protected variables, runner executor turlari, Docker'da self-hosted runner ro'yxatdan o'tkazish, container registry. 2-darsdagi pipeline'ni ko'chirish va taqqoslash.
4. **Jenkins va TeamCity**: Jenkins arxitekturasi (controller/agent), Docker'da ishga tushirish, declarative `Jenkinsfile`, plugin'lar, credentials, Docker agent'lar, Configuration as Code, ekspluatatsiya yuki; TeamCity server/agent, build configuration, Kotlin DSL, rasmiy image'lar. Qachon korxonalar qaysi birini tanlaydi. Xuddi shu pipeline'ni Jenkins'ga ko'chirish, TeamCity bilan yengilroq tanishuv.

## III bosqich - Avtomatik deploy

5. **Serverga avtomatik deploy**: pipeline'dan VM'ga SSH orqali deploy (deploy key, `known_hosts`, least-privilege deploy user), push-based va pull-based deploy, commit SHA bo'yicha image tag, pipeline'da database migratsiyalari, deploy strategiyalari (rolling, blue-green, canary), Compose va reverse proxy bilan blue-green, rollback, health check va smoke test, xabarnomalar, uzoq yashaydigan kalitlar o'rniga OIDC. Modul mini-loyihasi: `main` ga push, test, build, image push, cloud VM'ga deploy, smoke test, rollback mashqi.

## Yakuniy natija

Modul oxirida siz:

- CI, continuous delivery va continuous deployment farqini va jamoa qaysi bosqichda ekanini aniqlay olasiz.
- Istalgan ilova uchun pipeline loyihalaysiz: qaysi tekshiruv qaysi stage'da, nima cache, nima artifact, qayerda approval.
- GitHub Actions'da test, build, image push va deploy qiladigan workflow'ni noldan yozasiz, uni `gh` orqali debug qilasiz.
- Xuddi shu pipeline'ni GitLab CI va Jenkins'da qayta yoza olasiz va uch tizimning modelidagi farqni tushuntirasiz.
- Pipeline xavfsizligini baholaysiz: token huquqlari, secret'larning oqib chiqish yo'llari, action'larni pin qilish, self-hosted runner xavfi.
- Commit SHA bilan teglangan image'ni VM'ga avtomatik deploy qilasiz, smoke test bilan tekshirasiz va bir buyruq bilan oldingi versiyaga qaytarasiz.
- Downtime'siz deploy uchun blue-green sxemasini Compose va reverse proxy bilan qurasiz.

## Ataylab kiritilmagan

- Kubernetes'ga deploy, Helm, GitOps (Argo CD, Flux): Kubernetes modulida.
- Infratuzilmani pipeline'dan yaratish (Terraform plan/apply CI'da): IaC modulida.
- Monitoring va alerting bilan avtomatik rollback (metrikaga asoslangan canary tahlili): monitoring modulida.
- Supply chain chuqur mavzulari: image imzolash (cosign), SBOM, SLSA darajalari. Faqat eslatib o'tiladi.
- Boshqa CI tizimlari: CircleCI, Azure DevOps, Bitbucket Pipelines, Drone, Tekton. Modelni bilgach, hujjatidan o'qib olish mumkin.
- Mobil ilovalar va monorepo build tizimlari (Bazel, Nx remote cache).

## Manbalar

- Humble, Farley, "Continuous Delivery" (asosiy kitob: deployment pipeline, build once, promotion)
- Forsgren, Humble, Kim, "Accelerate" (DORA metrikalari qayerdan kelgani)
- Kim, Humble, Debois, Willis, "The DevOps Handbook" (2-nashr)
- https://martinfowler.com/articles/continuousIntegration.html – Continuous Integration (Fowler)
- https://trunkbaseddevelopment.com/ – trunk-based development
- https://dora.dev/ – DORA tadqiqotlari va metrikalar
- https://docs.github.com/en/actions – GitHub Actions hujjati
- https://docs.gitlab.com/ci/ – GitLab CI/CD hujjati
- https://www.jenkins.io/doc/ – Jenkins hujjati
- https://www.jetbrains.com/help/teamcity/teamcity-documentation.html – TeamCity hujjati
