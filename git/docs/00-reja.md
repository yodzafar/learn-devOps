# Git moduli rejasi (Version Control System, ops nuqtai nazaridan)

Ishlash tartibi: men nazariya va vazifalar beraman, siz scratch repolarda bajarib, buyruq, natija va izohni ish papkasidagi `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `git/01-commits/`, `git/02-branches-merge/` va hokazo. Yaratish: `make new m=git n=01 name=commits`.

Kim uchun: frontend dasturchi (TS/Node), backend va ops'ni endi o'rganmoqda. Git'ni `add`, `commit`, `push`, PR darajasida har kuni ishlatadi, lekin ichki tuzilishini (obyektlar, ref'lar, index) ko'rmagan. Shuning uchun darslar hech narsani "tanish" deb o'tkazib yubormaydi: har tushuncha noldan, mexanizmi va ishlaydigan misoli bilan beriladi, kundalik buyruqlar esa "ichkarida nima bo'ladi" tomonidan qayta ochiladi.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan. Bir hafta 5 o'quv kuni.

| Bosqich | Darslar | Siz uchun | Sabab |
|---------|---------|-----------|-------|
| I - Lokal Git ichki tuzilishi | 2 | 8 kun | Hammasi noldan: object model, uch qatlam, reflog, `reset` rejimlari, three-way merge, interactive rebase, bisect. Ko'p vazifa grafni qo'lda chizishni talab qiladi |
| II - Hamkorlik va hosting | 2 | 10 kun | Remote-tracking ref, refspec, `--force-with-lease`, SSH va signing, hook'lar, hosting administratsiyasi, self-hosted Gitea. Ikki mashinada sozlash (kalitlar, `gh`, Docker) vaqt oladi |
| **Jami** | **4** | **18 kun (3.6 hafta, taxminan 4 hafta)** | |

Darslar bo'yicha (siz uchun): 1-dars 3 kun, 2-dars 5 kun, 3-dars 5 kun, 4-dars 5 kun.

Mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz mexanizmni (nima uchun shunday ishlashini) o'z so'zingiz bilan tushuntira olasiz. "Buyruqni bilaman" yetarli emas, bu modulning maqsadi buyruq ortidagi modelni ko'rish.

## Laboratoriya

Modul ikki mashinada bir xil bajariladi: ofisda Zorin OS 18, uyda macOS (Apple Silicon). Asosiy asboblar va `lab` VM root'dagi `SETUP.md` bo'yicha o'rnatiladi; har darsning "Laboratoriya" bo'limida "Zorin (ofis) / macOS (uy)" jadvali bor.

| | Zorin (ofis) | macOS (uy) |
|---|--------------|------------|
| Git | `apt`, 2.43 | Xcode Command Line Tools (Apple Git, odatda eskiroq); yangi versiya kerak bo'lsa `brew install git`. Versiyaga bog'liq joylarda dars `git --version` ni tekshirishni aytadi |
| `gh` CLI | GitHub'ning rasmiy apt reposi | `brew install gh` |
| `pre-commit` | `pipx install pre-commit` | `brew install pre-commit` |
| Docker (4-dars, Gitea) | Docker Engine, `amd64` | Docker Desktop, `arm64` |
| SSH kalitlar, `~/.ssh/config` | bir xil | bir xil, qo'shimcha Keychain imkoniyati (3-darsda) |

- **Qayerda bajariladi**: Git ishlari ikkala mashinada host'ning o'zida. Tizim holatini o'zgartiradigan vazifa bu modulda yo'q, shuning uchun `lab` VM kerak emas.
- **Holat ko'chishi**: scratch repolar har mashinada lokal va ko'chmaydi (vazifani qaysi mashinada boshlasangiz, o'sha yerda tugating yoki ikkinchisida qaytadan yarating). GitHub'dagi sinov repolari umumiy. Javoblar kurs reposi orqali `git push` va `git pull` bilan ko'chadi.
- **Scratch repolar**: `~/git-lab/` ostida, dars bo'yicha (`~/git-lab/01/`, `~/git-lab/02/` ...). Ularni kurs reposi ichida yaratmang: Git ichidagi Git "embedded repository" bo'lib qoladi va tashqi repo uning ichini kuzatmaydi. Kurs reposidagi ish papkasiga faqat `README.md` va so'ralgan fayllar (hook skripti, `compose.yaml`, config nusxasi) tushadi.
- **Remote'lar**: 3-darsda lokal bare repo (`git init --bare`) ikki "dasturchi" o'rtasidagi server vazifasini bajaradi, PR vazifalari uchun GitHub'dagi shaxsiy akkauntingizda bir martalik repo ochiladi.
- **Gitea**: 4-darsda Docker Compose bilan `127.0.0.1` da ko'tariladi, dars oxirida `docker compose down -v` bilan o'chiriladi.
- **Tozalash**: har dars oxirida scratch repolar va GitHub'dagi sinov repolari o'chiriladi (dars "Laboratoriya" bo'limida aniq buyruqlar bor).
- **Xavfsizlik**: token, private key va `.env` hech qachon kurs reposiga commit qilinmaydi. Vazifalarda ataylab "secret" commit qilinadigan joylarda faqat soxta qiymat ishlatiladi.

## I bosqich - Lokal Git ichki tuzilishi

1. **Commit va object model**: blob, tree, commit, tag obyektlari, SHA va content-addressable storage, working tree / index / repository, `add -p`, commit message qoidalari, `log`/`diff`/`show`/`blame`, `.gitignore`, bekor qilish: `restore`, `reset --soft/--mixed/--hard`, `revert`, `commit --amend`, `reflog`
2. **Branch va merge**: branch pointer sifatida, `HEAD` va detached HEAD, `switch`, fast-forward va merge commit, three-way merge va conflict, `rebase` va interactive rebase, `cherry-pick`, `stash`, annotated va lightweight tag, `bisect`

## II bosqich - Hamkorlik va hosting

3. **Remote va pull request**: remote va refspec, `fetch` va `pull` farqi, tracking branch, `push` va `--force-with-lease`, SSH kalitlar va commit signing, fork, PR oqimi va review, workflow'lar (trunk-based, GitFlow, GitHub Flow), protected branch, hook'lar va `pre-commit`
4. **Git hostinglar**: GitHub, GitLab, Gitea, Bitbucket taqqosi, `gh` CLI, tokenlar va deploy key, Gitea'ni Docker Compose bilan self-host qilish va repo mirroring, GitLab self-managed tuzilishi, ops muhandis javob beradigan sozlamalar (branch protection, `CODEOWNERS`, required checks, secrets), modul mini-loyihasi

## Yakuniy natija

Moduldan keyin siz:

- `.git` ichidagi obyektlarni `cat-file` bilan o'qib, commit, tree va blob bog'lanishini tushuntira olasiz;
- "yo'qolgan" commit, o'chirilgan branch yoki noto'g'ri `reset --hard` ni `reflog` orqali tiklaysiz va qaysi holatda tiklab bo'lmasligini bilasiz;
- tarixni xavfsiz qayta yozasiz (amend, interactive rebase, autosquash) va qachon qayta yozish mumkin emasligini bilasiz;
- conflict'ni merge base, ours va theirs tushunchalari bilan ongli hal qilasiz;
- regressiyani `bisect run` bilan avtomatik topasiz;
- jamoa uchun workflow tanlaysiz va tanlovni asoslaysiz, reliz uchun signed annotated tag qo'yasiz;
- repo sozlamalarini ops nuqtai nazaridan o'rnatasiz: branch protection, `CODEOWNERS`, required checks, secrets, deploy key, eng kam huquqli token;
- Gitea'ni self-host qilib, reponi boshqa hostingga mirror qilasiz va hostinglar orasidagi farqni (model, CI, narx modeli, self-hosting) tushuntirasiz.

Bu modul keyingi modullar uchun poydevor: CI/CD pipeline'lar push, tag va PR hodisalaridan ishga tushadi, GitOps'da (Argo CD, Flux) Git repo klaster holatining yagona manbai, Terraform va Ansible kodi ham PR orqali review qilinadi.

## Ataylab kiritilmagan

- Git'ni o'rnatish: `SETUP.md` da. Kundalik buyruqlar (`init`, `add`, `commit`, `push`) esa o'tkazib yuborilmaydi, 1-darsda ichki mexanizmi bilan qayta tushuntiriladi.
- CI pipeline yozish (GitHub Actions, GitLab CI): alohida CI/CD modulida. Bu yerda faqat hosting sozlamalari va "required check" tushunchasi.
- Git LFS, submodule, subtree, sparse checkout, partial clone, monorepo asboblari: kerak bo'lganda alohida so'rang.
- Katta hajmli tarixni tozalash (`git filter-repo`): faqat nima uchun kerakligi va havolasi beriladi.
- GitLab'ni to'liq o'rnatish va ekspluatatsiya qilish: faqat arxitektura va asosiy buyruqlar ko'rib chiqiladi (kamida 8 GB RAM atrofida talab qiladi, o'quv mashinasi uchun og'ir).
- GUI klientlar (GitKraken, Sourcetree) va IDE integratsiyasi.

## Manbalar

- Chacon, Straub, "Pro Git" (2-nashr, bepul): https://git-scm.com/book/en/v2 (asosiy kitob; 2, 3, 7 va 10-boblar)
- Git reference va man sahifalar: https://git-scm.com/docs (`man git-reset`, `man gitrevisions`, `man githooks`)
- GitHub Docs: https://docs.github.com
- GitLab Docs: https://docs.gitlab.com
- Gitea Docs: https://docs.gitea.com
- Bitbucket Cloud Docs: https://support.atlassian.com/bitbucket-cloud/
- Trunk-based development: https://trunkbaseddevelopment.com
- Forsgren, Humble, Kim, "Accelerate" (workflow tanlovi va yetkazib berish tezligi orasidagi bog'liqlik)
