# ROADMAP: DevOps kursi bo'yicha yagona jadval

Bu fayl to'qqiz modulni (`linux`, `git`, `network`, `docker`, `cloud`, `cicd`, `iac`, `observability`, `kubernetes`) bitta vaqt chizig'iga joylaydi. Har modulning o'z rejasi `<modul>/docs/00-reja.md` da; bu yerda "qaysi haftada nima va nimadan keyin" degan savolga javob.

Manba: kurs rejasi (Google Form, "Kurs rejasi"). Formadagi har mavzu bitta darsga aylantirilgan; to'rtta modulda (Git, Docker, CI/CD, IaC) mavzu katta bo'lgani uchun bir nechta darsga bo'lingan.

## Hisob asoslari

- Kuniga 2–2.5 soat, haftada 5 kun. Shanba: hafta qarzini yopish va o'tilganni takrorlash. Yakshanba: dam.
- Sizning foningiz: frontend dasturchi (TS/Node, 6–7 yil), backend va ops'ni endi o'rganmoqdasiz. Terminal, git va HTTP tanish bo'lsa ham, backend va ops tushunchalari har darsda noldan, mexanizmi va ishlaydigan misoli bilan tushuntiriladi (CLAUDE.md, "Batafsillik"). Shuning uchun hech bir modul "tanish" deb qisqartirilmagan; Node/frontend tajribasi faqat o'xshatish haqiqiy bo'lgan joyda ishlatiladi.
- Har dars ikki mashinada (ofisda Zorin, uyda macOS) to'liq bajariladi, shuning uchun darslarga ikki mashina farqlari va laboratoriyani qayta tiklash ham kiradi.
- Jami: **64 hafta (taxminan 15 oy)**: 294 ish kuni (320 kunlik sig'imdan), qolgan 26 kun modullar orasida zaxira. Kuniga 4–5 soat bo'lsa taxminan 7–8 oy.
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

| Hafta | Modul | Darslar (ish kuni) | Bosqich yakuni |
|---|---|---|---|
| 1–6 | linux | 1–7: kirish, distributivlar, asosiy buyruqlar, muharrirlar, shell, fayllar, matn (28) | |
| 7–11 | linux | 8–13: resurslar, jarayonlar, userlar, systemd, paketlar, disklar (22) | **Linux tugadi** |
| 12–15 | git | 1–4: commit modeli, branch va merge, remote va PR, hosting'lar (18) | **Git tugadi** |
| 16–22 | network | 1–6: tarmoq turlari, OSI, IP va subnetting, protokollar, routing, firewall/NAT/VPN (32) | **Tarmoq tugadi. Serverni qo'lda sozlay olasiz** |
| 23–28 | docker | 1–5: konteynerlar, image'lar, volume va tarmoq, Compose, orchestration'ga kirish (27) | **Docker tugadi** |
| 29–32 | cloud | 1–4: provayderlar, birinchi sozlash, VM/tarmoq/S3, qo'lda deploy (20) | **Cloud tugadi. Ilova internetda ishlaydi** |
| 33–38 | cicd | 1–5: kirish, GitHub Actions, GitLab CI, Jenkins/TeamCity, avtomatik deploy (27) | **CI/CD tugadi. Junior DevOps vazifalariga tayyor** |
| 39–45 | iac | 1–5: kirish, Ansible asoslari, rollar, Terraform asoslari, state va modullar (31) | **IaC tugadi** |
| 46–52 | observability | 1–7: Prometheus, Grafana, alerting, logging, tracing, profiling, OpenTelemetry (33) | **Observability tugadi** |
| 53–58 | kubernetes | 1–8: kirish, klaster, birinchi deploy, workload'lar, Job, Service, storage, cert-manager (27) | |
| 59–64 | kubernetes | 9–15: CI/CD integratsiya, GitOps, HA, stateful, xavfsizlik, autoscaling, cost (23) + yakuniy loyiha (5–6) | **Kurs tugadi** |

Hisob darslardagi "Taxminiy vaqt" yig'indisidan (2026-10-08 da, barcha darslar batafsil formatga o'tkazilgach qayta hisoblangan): linux 50 kun, git 18, network 32, docker 27, cloud 20, cicd 27, iac 31, observability 33, kubernetes 50 + yakuniy loyiha 6. Jami 294 ish kuni, 1307 vazifa. Har qatordagi haftalar soni kunlarni 5 ga bo'lib yuqoriga yaxlitlangan; ortib qolgan kunlar shu bosqichning zaxirasi.

## Haftalik ritm

| Kun | Vaqt | Nima |
|---|---|---|
| Dushanba–Juma | 2–2.5 soat | Joriy dars: nazariya, vazifalar, `README.md` ga izoh yozish |
| Shanba | 2–3 soat | Qarzni yopish, hafta bo'yi to'plangan savollarni Claude'ga berish, tekshiruv |
| Yakshanba | – | Dam |

## Nazorat nuqtalari

| Hafta | Nima bo'lishi kerak |
|---|---|
| 11 | Yangi Ubuntu serverga SSH bilan kirib: user, sudo, systemd servis, paket, disk va log bilan ishlay olasiz. "Server sekin" degan shikoyatni 60 soniyada birlamchi tahlil qila olasiz |
| 22 | Subnetni qo'lda hisoblaysiz, DNS/TCP muammosini `dig`, `ss`, `tcpdump` bilan ajratasiz, firewall va WireGuard sozlay olasiz |
| 28 | Node/Go ilovani kichik, non-root, multi-stage image'ga yig'ib, Compose'da DB va reverse proxy bilan ko'tarasiz |
| 32 | Ilova cloud VM'da TLS bilan ishlaydi, hech qanday ortiqcha resurs qolmagan, budget alert yoqilgan |
| 38 | `main` ga push → test → image → deploy → smoke test, rollback mashq qilingan |
| 45 | Butun muhit `terraform apply` + `ansible-playbook` bilan noldan ko'tariladi va bir buyruq bilan o'chadi |
| 52 | Ilovada metrika, log, trace va profil bor; alert kelganda sababni dashboard → log → trace orqali topasiz |
| 64 | Ilova multi-node klasterda GitOps orqali deploy qilingan: TLS, autoscaling, network policy, backup/restore, xarajat bahosi bilan |

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
- [ ] Hafta 1–6: linux 1–7. Hozir 1-dars (`linux/docs/01-intro.md` → `linux/01-intro/`)
- [ ] Hafta 7–11: linux 8–13
- Batafsil holat: `PROGRESS.md` (indeks) va `linux/docs/PROGRESS.md`
- Darslar holati: 64 darsning hammasi yangi (batafsil, ikki mashinaga mos) formatda. Vaqt chizig'i 2026-10-08 da shunga moslab qayta hisoblandi (200 kundan 294 kunga, 42 haftadan 64 haftaga).

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
