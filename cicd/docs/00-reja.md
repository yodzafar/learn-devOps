# CI/CD o'quv rejasi (pipeline'dan avtomatik deploy'gacha)

Ishlash tartibi: men nazariya va vazifalar beraman, siz pipeline yozasiz va ishga tushirasiz, men `README.md`, pipeline fayllari va run natijalarini tekshirib xato va xavfsizlik muammolarini ko'rsataman.
Har dars uchun alohida papka: `cicd/01-intro/`, `cicd/02-github-actions/` va hokazo. Yaratish: `make new m=cicd n=01 name=intro`.

Kurs yo'l xaritasidagi mavzular: "CI/CD haqida ma'lumot" (1-dars), "Tools: Github actions, Gitlab CI, Jenkins, Teamcity" (2–4-darslar), "Dasturlarni serverga avtomatik deploy" (5-dars).

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Muddat (2–2.5 soat/kun) | Siz uchun | Sabab |
|---------|---------|--------------------------|-----------|-------|
| I - Tushunchalar | 1 | 3 kun | 2 kun | CI bilan frontend'da ishlagansiz (lint, test, build), atamalar tanish. Yangi: artifact promotion, DORA, pipeline'ni lokal modellashtirish |
| II - Asboblar | 3 | 14–15 kun | 11 kun | YAML va GitHub oqimi tanish, shuning uchun GitHub Actions tez ketadi. Runner/agent, executor, Jenkins ekspluatatsiyasi yangi, qisqartirilmaydi |
| III - Avtomatik deploy | 1 | 6 kun | 5 kun | SSH, Docker, cloud VM oldingi modullardan tanish. Deploy strategiyalari, rollback va OIDC yangi |
| **Jami** | **5** | **23–24 kun** | **18 kun (taxminan 3.5–4 hafta)** | |

Dars bo'yicha taqsimot (siz uchun): 1-dars 2 kun, 2-dars 4 kun, 3-dars 3 kun, 4-dars 4 kun, 5-dars 5 kun.

Bir mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, pipeline yashil va ataylab buzilganda qizil bo'ladi, men tekshirib tasdiqlaganman, va siz har qadam nima uchun kerakligini o'z so'zingiz bilan tushuntira olasiz.

## Laboratoriya

- **Demo repozitoriy**: GitHub'da alohida public repo `cicd-demo` (2-darsda yaratiladi). Pipeline fayllari repo ildizida turishi shart (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`), shu sababli ular bu o'quv repozitoriysi ichida ishlamaydi. Ish papkasidagi `README.md` ga javoblar, run havolalari va pipeline fayllarining nusxasi yoziladi.
- **GitHub**: akkaunt va `gh` CLI (ish mashinasida o'rnatilgan). Public repo'da standart hosted runner'lar bepul.
- **GitLab**: gitlab.com akkaunt, free tier. `cicd-demo` ga ikkinchi remote sifatida ulanadi. Self-managed GitLab faqat eslatib o'tiladi, o'rnatilmaydi (resurs talabi katta).
- **Jenkins va TeamCity**: ish mashinasida Docker konteynerlarida, named volume bilan. Ish mashinasiga paket o'rnatilmaydi. Dars oxirida konteyner, volume va network o'chiriladi.
- **Deploy nishoni**: cloud modulidagi AWS VM (Docker va Compose o'rnatilgan). 5-darsda qayta ko'tariladi, dars oxirida o'chiriladi. Budget alert yoqilgan bo'lishi shart.
- **Secret'lar**: token, SSH private key, `.env` hech qachon commit qilinmaydi. Ular faqat CI tizimining secret omborida turadi.

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
