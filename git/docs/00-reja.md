# Git moduli rejasi (Version Control System, ops nuqtai nazaridan)

Ishlash tartibi: men nazariya va vazifalar beraman, siz scratch repolarda bajarib, buyruq, natija va izohni ish papkasidagi `README.md` ga yozasiz, men tekshiraman.
Har dars uchun alohida papka: `git/01-commits/`, `git/02-branches-merge/` va hokazo. Yaratish: `make new m=git n=01 name=commits`.

## Vaqt hisobi

Hisob kuniga 2–2.5 soat muntazam mashg'ulot va vazifalarni to'liq bajarish sharti bilan.

| Bosqich | Darslar | Umumiy muddat | Siz uchun | Sabab |
|---------|---------|---------------|-----------|-------|
| I - Lokal Git ichki tuzilishi | 2 | 7–8 kun | 5 kun | `add/commit/branch/merge` kundalik ish. Yangi: object model, reflog, `reset` rejimlari, interactive rebase, bisect |
| II - Hamkorlik va hosting | 2 | 8–9 kun | 6 kun | PR va review tajribasi bor. Yangi: refspec, `--force-with-lease`, signing, hook'lar, hosting administratsiyasi, self-hosted Gitea |
| **Jami** | **4** | **15–17 kun** | **11 kun (taxminan 2 hafta)** | |

Darslar bo'yicha (siz uchun): 1-dars 2 kun, 2-dars 3 kun, 3-dars 3 kun, 4-dars 3 kun.

Mavzuni "o'rgandim" deyish mezoni: vazifalar bajarilgan, men tekshirib tasdiqlaganman, va siz mexanizmni (nima uchun shunday ishlashini) o'z so'zingiz bilan tushuntira olasiz. "Buyruqni bilaman" yetarli emas, bu modulning maqsadi buyruq ortidagi modelni ko'rish.

## Laboratoriya

- **Ish mashinasi** (Zorin OS 18). Git 2.43 va `gh` CLI o'rnatilgan. Tizim holatini o'zgartiradigan vazifa bu modulda yo'q, VM kerak emas.
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

- Git'ning boshlang'ich darajasi (`init`, `add`, `commit`, `push` nima ekani): kundalik tajribangiz bor.
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
