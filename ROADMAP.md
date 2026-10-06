# ROADMAP: DevOps kursi bo'yicha yagona jadval

Bu fayl to'qqiz modulni (`linux`, `git`, `network`, `docker`, `cloud`, `cicd`, `iac`, `observability`, `kubernetes`) bitta vaqt chizig'iga joylaydi. Har modulning o'z rejasi `<modul>/docs/00-reja.md` da; bu yerda "qaysi haftada nima va nimadan keyin" degan savolga javob.

Manba: kurs rejasi (Google Form, "Kurs rejasi"). Formadagi har mavzu bitta darsga aylantirilgan; to'rtta modulda (Git, Docker, CI/CD, IaC) mavzu katta bo'lgani uchun bir nechta darsga bo'lingan.

## Hisob asoslari

- Kuniga 2–2.5 soat, haftada 5 kun. Shanba: hafta qarzini yopish va o'tilganni takrorlash. Yakshanba: dam.
- Sizning foningiz (Senior Frontend, TS/Node) hisobga olingan: terminal, git va HTTP tanish, shuning uchun Git va Docker asoslari qisqa. Tarmoq, Linux ichki tuzilishi, IaC va Kubernetes qisqartirilmagan.
- Jami: **42 hafta (taxminan 10 oy)**: 200 ish kuni va har modul oxirida bir necha kun zaxira. Kuniga 4–5 soat bo'lsa 5 oy.
- Bu loyiha `learn-golang` va `learn-pyhton` bilan parallel ketadi. Uchalasiga vaqt yetmasa, shu jadval cho'ziladi, darslar qisqartirilmaydi.
- Qoida: dars "tugadi" deyilishi uchun vazifalar bajarilgan, `make check` toza, Claude tekshirgan, o'zini tekshirish savollariga og'zaki javob bera olasiz.

## Bog'liqliklar (nima nimadan keyin)

```
linux 1–7 ──► git ──► hammasi (har modulda skript va repo ishlatiladi)
linux 8–13 ─► network (ip, ss, systemd, firewall VM'da)
linux + network ──► docker (namespaces, cgroups, NAT, DNS konteynerda)
docker + network ──► cloud (VM, VPC, security group, qo'lda deploy)
git + docker + cloud ──► cicd (pipeline cloud VM'ga deploy qiladi)
cloud + cicd ──► iac (qo'lda qilingan hamma narsa kodga o'tadi)
docker (compose) ──► observability (stack compose'da quriladi)
docker + network + iac + observability ──► kubernetes
```

Tartibni o'zgartirish mumkin bo'lgan joylar: `git` ni `linux` 5-darsdan keyin parallel boshlash mumkin; `observability` ni `cloud` dan oldin ham o'tish mumkin (faqat Docker Compose kerak).

## Vaqt chizig'i

| Hafta | Modul | Darslar | Bosqich yakuni |
|---|---|---|---|
| 1–3 | linux | 1–7: kirish, distributivlar, asosiy buyruqlar, muharrirlar, shell, fayllar, matn | |
| 4–7 | linux | 8–13: resurslar, jarayonlar, userlar, systemd, paketlar, disklar | **Linux tugadi** |
| 8–9 | git | 1–4: commit modeli, branch va merge, remote va PR, hosting'lar | **Git tugadi** |
| 10–13 | network | 1–6: tarmoq turlari, OSI, IP va subnetting, protokollar, routing, firewall/NAT/VPN | **Tarmoq tugadi. Serverni qo'lda sozlay olasiz** |
| 14–17 | docker | 1–5: konteynerlar, image'lar, volume va tarmoq, Compose, orchestration'ga kirish | **Docker tugadi** |
| 18–20 | cloud | 1–4: provayderlar, birinchi sozlash, VM/tarmoq/S3, qo'lda deploy | **Cloud tugadi. Ilova internetda ishlaydi** |
| 21–24 | cicd | 1–5: kirish, GitHub Actions, GitLab CI, Jenkins/TeamCity, avtomatik deploy | **CI/CD tugadi. Junior DevOps vazifalariga tayyor** |
| 25–28 | iac | 1–5: kirish, Ansible asoslari, rollar, Terraform asoslari, state va modullar | **IaC tugadi** |
| 29–32 | observability | 1–7: Prometheus, Grafana, alerting, logging, tracing, profiling, OpenTelemetry | **Observability tugadi** |
| 33–37 | kubernetes | 1–8: kirish, klaster, birinchi deploy, workload'lar, Job, Service, storage, cert-manager | |
| 38–42 | kubernetes | 9–15: CI/CD integratsiya, GitOps, HA, stateful, xavfsizlik, autoscaling, cost + yakuniy loyiha | **Kurs tugadi** |

Hisob darslardagi "Taxminiy vaqt" yig'indisidan: linux 31 kun, git 11, network 20, docker 17, cloud 13, cicd 18, iac 20, observability 21, kubernetes 49. Jami 200 ish kuni, 1307 vazifa.

## Haftalik ritm

| Kun | Vaqt | Nima |
|---|---|---|
| Dushanba–Juma | 2–2.5 soat | Joriy dars: nazariya, vazifalar, `README.md` ga izoh yozish |
| Shanba | 2–3 soat | Qarzni yopish, hafta bo'yi to'plangan savollarni Claude'ga berish, tekshiruv |
| Yakshanba | – | Dam |

## Nazorat nuqtalari

| Hafta | Nima bo'lishi kerak |
|---|---|
| 7 | Yangi Ubuntu serverga SSH bilan kirib: user, sudo, systemd servis, paket, disk va log bilan ishlay olasiz. "Server sekin" degan shikoyatni 60 soniyada birlamchi tahlil qila olasiz |
| 13 | Subnetni qo'lda hisoblaysiz, DNS/TCP muammosini `dig`, `ss`, `tcpdump` bilan ajratasiz, firewall va WireGuard sozlay olasiz |
| 17 | Node/Go ilovani kichik, non-root, multi-stage image'ga yig'ib, Compose'da DB va reverse proxy bilan ko'tarasiz |
| 20 | Ilova cloud VM'da TLS bilan ishlaydi, hech qanday ortiqcha resurs qolmagan, budget alert yoqilgan |
| 24 | `main` ga push → test → image → deploy → smoke test, rollback mashq qilingan |
| 28 | Butun muhit `terraform apply` + `ansible-playbook` bilan noldan ko'tariladi va bir buyruq bilan o'chadi |
| 32 | Ilovada metrika, log, trace va profil bor; alert kelganda sababni dashboard → log → trace orqali topasiz |
| 42 | Ilova multi-node klasterda GitOps orqali deploy qilingan: TLS, autoscaling, network policy, backup/restore, xarajat bahosi bilan |

## Agar vaqt yetmasa

Qisqartirish tartibi (birinchisi birinchi qisqaradi):

1. `cicd` 4 (Jenkins, TeamCity): faqat nazariya va taqqoslash, amaliyotsiz.
2. `observability` 6 (profiling) va `git` 4 dagi Gitea self-hosting.
3. `kubernetes` 15 dagi OpenCost amaliyoti va `kubernetes` 2 dagi kubeadm (k3s yetadi).
4. `iac` 3 dagi Molecule va dynamic inventory.

Qisqartirilmaydi: `linux` to'liq, `network` 3–6, `docker` 1–4, `cloud` 2–4, `cicd` 2 va 5, `iac` 4–5, `observability` 1–4, `kubernetes` 1–7, 10, 13.

## Hozirgi holat

- Boshlangan sana: 2026-10-05 (loyiha tuzilmasi, rejalar va darslar yozildi)
- Joriy bosqich: `linux`, 1-hafta
- [ ] Hafta 1–3: linux 1–7. Hozir 1-dars (`linux/docs/01-intro.md` → `linux/01-intro/`)
- [ ] Hafta 4–7: linux 8–13
- Batafsil holat: `PROGRESS.md` (indeks) va `linux/docs/PROGRESS.md`
- Darslar holati: 64 darsdan 15 tasi yangi (batafsil, ikki mashinaga mos) formatda: linux 1, 6, 8, 10–13; git 1–2; network 1, 2, 4; cloud 1; iac 1, 3. Qolgan 49 tasi hali birinchi variantda. Hammasi o'tkazilgach vaqt chizig'i qayta hisoblanadi (darslar vaqti taxminan 1.5 baravar oshadi).

### Temp: reja bilan solishtirish

Holat uch xil bo'ladi: **oldinda** (rejadan kamida 2 kun oldin), **jadvalda** (farq 2 kundan kam), **orqada** (rejadan kamida 2 kun keyin). Hisob kalendar kunlarida, boshlanish 2026-10-05.

| Ko'rsatkich | Qiymat (2026-10-05 holati) |
|---|---|
| Holat | **jadvalda** (boshlanish kuni) |
| Reja bo'yicha shu kunga | linux 1 boshlangan |
| Haqiqatda | hali vazifa qabul qilinmagan |

Tarix (har tekshiruv kunida bitta qator, eng yangisi pastda):

| Sana | Qabul qilingan | Reja bo'yicha | Holat |
|---|---|---|---|
| | | | |

Claude bu jadvallarni har tekshiruvdan keyin yangilaydi va holatni bo'yamasdan yozadi.
