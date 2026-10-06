# 5-dars: Shell va muhit

Maqsad: bash buyruq satrini qanday qayta ishlashini va jarayon muhiti qanday shakllanishini mexanizm darajasida tushunish: kengayish (expansion) tartibi, shell va muhit o'zgaruvchilari, `export`, `PATH` bo'yicha qidiruv, `.profile` va `.bashrc` ning yuklanish tartibi, quoting, redirection va pipe, exit code'lar, `sudo` va `sudoers`, hamda birinchi bash skript. "Mening terminalimda ishlaydi, cron'da, CI'da yoki systemd'da ishlamaydi" turidagi muammolarning deyarli hammasi shu darsdagi mexanizmlarga borib taqaladi. 1-darsda shell nima ekani, builtin va tashqi buyruq farqi va exit code asoslari o'tilgan; 3-darsdagi globbing bu yerda kengayish tartibining bir qismi sifatida qayta ko'riladi. 9-dars (jarayonlar), 10-dars (foydalanuvchilar) va 11-dars (systemd) shu darsdagi muhit va `sudo` tushunchalariga tayanadi. `grep`, `sed`, `awk` 7-darsda, bu yerda ular o'rgatilmaydi.

Taxminiy vaqt: 5 kun (siz uchun). Birinchi kun 1–3 bo'limlar va A guruh; ikkinchi kun 4–5 bo'limlar va B, C guruhlari; uchinchi kun 6–7 bo'limlar va D guruhi; to'rtinchi kun 8-bo'lim va E guruhi; beshinchi kun 9-bo'lim, "Birga bajaramiz", F guruhi va README'ni tartibga solish. Node'dagi `process.env`, `process.argv` va npm skriptlar tajribangiz yordam beradi, lekin quyidagilar yangi va diqqat talab qiladi: shell va muhit o'zgaruvchisi farqi, login va non-login shell, word splitting va tirnoqlar, `2>&1` tartibi, pipeline exit code'i, `sudo` bilan redirection, `sudoers` sintaksisi.

Qanday o'qish kerak: har bo'limdagi misolni VM ichida o'zingiz terib ishga tushiring va chiqishni darsdagi izoh bilan solishtiring. Mashinaga bog'liq qiymatlar `<...>` bilan belgilangan. Natija darsdagidan farq qilsa, avval qaysi shell'da turganingizni tekshiring (`echo $0`): bu darsdagi hamma narsa bash uchun yozilgan, zsh'da ayrim natijalar boshqacha.

## Laboratoriya

Hamma vazifa `lab` VM ichida (Multipass, Ubuntu 24.04, `SETUP.md`), bash'da bajariladi. Host'da faqat ish papkasi, `multipass`, `make` va `shellcheck` ishlatiladi.

| Joy | Prompt | Bu darsda nima uchun |
|-----|--------|----------------------|
| Host (Zorin yoki macOS) | `user@host:~$` yoki `%` (zsh) | ish papkasi, `task_N.sh` fayllarini yozish, `multipass transfer`, `multipass exec`, `shellcheck`, `make check` |
| `lab` VM | `ubuntu@lab:~$` | barcha tajribalar: o'zgaruvchilar, startup fayllar, redirection, `sudo`, `sudoers`, skriptlarni ishga tushirish |

E guruhida `sudoers` va foydalanuvchi o'zgartiriladi, shuning uchun boshlashdan oldin host'da snapshot (VM diskining shu paytdagi holati, unga qaytish mumkin; 2-dars) oling:

```
multipass stop lab && multipass snapshot lab --name before-05 && multipass start lab
multipass shell lab
```

Skriptlar (`task_2.sh`, `task_21.sh`) host'dagi ish papkasida yoziladi (git'ga shu yerdan tushadi) va VM'ga ko'chirib ishga tushiriladi. Host'da, ish papkasi ichida:

```
multipass transfer task_21.sh lab:        # host -> VM home directory (/home/ubuntu)
multipass transfer lab:task_21.sh .       # VM -> host, if you edited it inside the VM
```

`shellcheck` (bash skriptlardagi xatolarni topadigan statik analizator, 9-bo'lim) host'da kerak, chunki `make check` uni host'da ishga tushiradi:

| Mashina | O'rnatish | Tekshirish |
|---------|-----------|------------|
| Zorin (ofis, `amd64`) | `sudo apt install shellcheck` | `shellcheck --version` |
| macOS (uy, `arm64`) | `brew install shellcheck` | `shellcheck --version` |

Muqobil, hech narsa o'rnatmasdan: `docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable task_21.sh` (ish papkasi ichida, ikkala host'da bir xil ishlaydi).

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Host Linux, lekin shell'i `zsh` bo'lishi mumkin (`echo $0` bilan tekshiring). Host'ning `~/.bashrc`, `~/.profile`, `/etc/sudoers` fayllariga tegilmaydi: startup fayl va `sudo` tajribalari faqat VM'da. |
| macOS (uy) | Host shell'i har doim `zsh`, Terminal har oynada login shell ochadi. `/proc` yo'q, `sudoers` va `PATH` tarkibi boshqa, utilitalar BSD. Bu darsdagi hech bir tajriba host'da bajarilmaydi. |

Host'dagi zsh'da quyidagilar bash'dan farq qiladi, shuning uchun vazifalarni host'da bajarsangiz natija boshqa chiqadi:

| Narsa | bash (VM, serverlar) | zsh (host) |
|-------|----------------------|------------|
| Tirnoqsiz `$var` | word splitting va globbing qo'llanadi | standart holatda bo'linmaydi va glob sifatida ochilmaydi |
| Mos kelmagan glob (`ls *.xyz`) | pattern o'zgarishsiz buyruqqa beriladi | shell o'zi `no matches found` xatosini beradi |
| Massiv indeksi | 0 dan | 1 dan |
| Pipeline kodlari | `PIPESTATUS` massivi | `pipestatus` massivi (kichik harf) |
| `echo 'a\nb'` | `a\nb` (escape faqat `echo -e` bilan) | ikki qator (escape standart holatda ishlaydi) |
| Startup fayllar | `~/.profile` yoki `~/.bash_profile`, `~/.bashrc` | `~/.zshenv`, `~/.zprofile`, `~/.zshrc` |

Holat va tiklash: bu dars oldingi darslar holatiga tayanmaydi, toza `lab` yetarli. Darsning o'zi VM'da holat qoldiradi (`deploy` foydalanuvchisi, `/etc/sudoers.d/deploy`, `~/.profile` va `~/.bashrc` dagi sinov qatorlari, `~/bin`). Mashinani almashtirsangiz bu holat ko'chmaydi: javoblar git orqali ko'chadi, ikkinchi mashinada esa tugallanmagan guruhni boshidan bajarasiz (har guruh mustaqil; faqat 8-vazifa 4-vazifadagi `~/bin/hello` ga, 20-vazifa 19-vazifadagi `deploy` ga tayanadi). Tozalash: "Topshirish" bandidagi ro'yxat yoki `multipass stop lab && multipass restore lab.before-05 && multipass start lab`.

---

## 1. Shell buyruqni qanday bajaradi

### Bu nima

Shell (1-dars) siz yozgan qatorni o'qib, dasturlarni ishga tushiradigan interpretator. Muhim jihati: dastur siz yozgan matnni ko'rmaydi. Shell avval qatorni qayta yozadi (o'zgaruvchilarni qiymatga, `*` ni fayl nomlariga almashtiradi), keyin dasturga tayyor argumentlar ro'yxatini beradi. `ls *.txt` da `ls` hech qachon `*` belgisini ko'rmaydi, u fayl nomlari ro'yxatini oladi.

### Mexanizm: to'qqiz qadam

Enter bosilgandan keyin bash qatorni quyidagi tartibda qayta ishlaydi:

| Qadam | Nima bo'ladi | Misol |
|-------|--------------|-------|
| 1. Tokenlarga ajratish | tirnoqlar va operatorlar (`\|`, `>`, `&&`, `;`) aniqlanadi; birinchi so'z alias bo'lsa shu yerda almashtiriladi | `ll` bu `ls -alF` |
| 2. Brace expansion | `{a,b}`, `{1..3}` | `f{1,2}` bu `f1 f2` |
| 3. Tilde, o'zgaruvchi, buyruq, arifmetika | `~`, `$VAR`, `$(cmd)`, `$((1+2))` | `$HOME` bu `/home/ubuntu` |
| 4. Word splitting | 3-qadamning tirnoqsiz natijasi bo'shliq, tab, yangi qator bo'yicha so'zlarga bo'linadi | |
| 5. Pathname expansion (globbing) | `*`, `?`, `[...]` mos fayl nomlariga almashtiriladi (3-dars) | |
| 6. Redirection | fayllar ochiladi, `>` faylni shu paytda bo'shatadi | |
| 7. Buyruqni topish | funksiya, builtin, keyin `PATH` (3-bo'lim) | |
| 8. Bajarish | tashqi buyruq uchun yangi jarayon (`fork` + `exec`), shell uning tugashini kutadi | |
| 9. Exit code | `$?` ga yoziladi (7-bo'lim) | |

8-qadamdagi `fork` va `exec` bu system call'lar (1-dars): `fork` shell jarayonining nusxasini (bola jarayon) yaratadi, `exec` shu nusxa ichidagi dasturni yangi dasturga almashtiradi. Bola ota shell'ning muhiti, joriy papkasi va ochiq fayllarini meros oladi. Bu darsning 2 va 6-bo'limlari aynan shu merosga tayanadi. Builtin (`cd`, `export`, `echo`) uchun jarayon yaratilmaydi, u shell'ning o'zida bajariladi.

### Misol: shell nimani ko'rsatmaydi, `set -x` nimani ko'rsatadi

`set -x` yoqilganda bash har buyruqni kengayishlardan keyin, bajarishdan oldin `+` belgisi bilan chop etadi. Bu "dastur aslida nima oldi?" savoliga javob:

```
ubuntu@lab:~$ set -x
ubuntu@lab:~$ echo ~ f{1,2}.txt $((2+3)) "$USER"
+ echo /home/ubuntu f1.txt f2.txt 5 ubuntu
/home/ubuntu f1.txt f2.txt 5 ubuntu
ubuntu@lab:~$ msg="a    b"
+ msg='a    b'
ubuntu@lab:~$ echo $msg
+ echo a b
a b
ubuntu@lab:~$ echo "$msg"
+ echo 'a    b'
a    b
ubuntu@lab:~$ set +x
+ set +x
```

- `+ echo /home/ubuntu f1.txt f2.txt 5 ubuntu`: `echo` beshta tayyor argument oldi. `~` (3-qadam), `f{1,2}.txt` (2-qadam), `$((2+3))` va `"$USER"` (3-qadam) shell tomonidan almashtirilgan.
- `+ echo a b`: tirnoqsiz `$msg` 4-qadamda ikki so'zga bo'lindi (`a` va `b`), `echo` ularni bitta bo'shliq bilan chiqardi. To'rtta bo'shliq yo'qoldi, chunki ular qiymatning qismi emas, so'z ajratuvchi deb qaraldi.
- `+ echo 'a    b'`: qo'shtirnoq 4 va 5-qadamlarni o'chirdi, `echo` bitta argument oldi.
- `set +x` izlashni o'chiradi. (Izlash yoqiqligida Tab bossangiz completion funksiyalarining izlari ham chiqadi, bu normal.)

Bu tartib ko'p tuzoqni tushuntiradi: o'zgaruvchi ichidagi `*` 5-qadamda ochiladi (chunki o'zgaruvchi 3-qadamda qiymatga aylanadi va glob undan keyin keladi), redirection buyruqdan oldin bajariladi, tirnoq 4 va 5-qadamlarni o'chiradi.

### Real ishda qachon kerak

- Skript kutilmagan ish qilsa: `bash -x script.sh` har qatorni kengaygan holda ko'rsatadi. CI log'larida ham shu usul ishlatiladi.
- npm skriptlar: `npm run build` `package.json` dagi satrni `sh -c "<satr>"` orqali bajaradi. Ya'ni `"build": "rm -rf dist/* && tsc"` dagi `*` va `&&` ni Node emas, shell qayta ishlaydi; qoidalar shu bo'limdagi qoidalar.
- Dockerfile'dagi `RUN cmd` (shell shakli) ham `/bin/sh -c` orqali o'tadi, `RUN ["cmd", "arg"]` (exec shakli) esa shell'siz, kengayishlarsiz bajariladi.

### Nima uchun shunday

Unix'da kengayishni shell qiladi, dastur emas. Shuning uchun `*` har dasturda bir xil ishlaydi va dastur muallifi uni qayta yozmaydi. Muqobil yondashuv Windows `cmd.exe` da: u yerda `*` ni har dastur o'zi talqin qiladi, natijada xatti-harakat dasturdan dasturga farq qiladi. Bahosi: shell qoidalarini bilmagan odam uchun natija kutilmagan bo'ladi, chunki yozilgan matn va dastur olgan argumentlar orasida to'qqiz qadam turadi.

## 2. O'zgaruvchilar va muhit

### Ikki xil o'zgaruvchi

- **Shell o'zgaruvchisi**: faqat joriy shell xotirasida yashaydi. `NAME=value` deb yaratiladi. Tenglik atrofida bo'shliq bo'lmaydi: `NAME = value` da shell 1-qadamda uchta so'z ko'radi va `NAME` nomli buyruqni qidiradi.
- **Muhit (environment) o'zgaruvchisi**: `export` qilingan o'zgaruvchi. U bola jarayonlarga nusxa bo'lib o'tadi.

### Mexanizm: muhit bu jarayonning xususiyati

Muhit shell'ga xos narsa emas. Har jarayonda `KEY=value` ko'rinishidagi satrlar ro'yxati bor, kernel uni `execve` system call'i paytida yangi dasturga uzatadi. Shell `export` qilingan o'zgaruvchilardan shu ro'yxatni tuzadi va bolaga beradi; `export` qilinmaganlari ro'yxatga kirmaydi. Node'dagi `process.env` aynan shu ro'yxatning obyekt ko'rinishi: `node` ishga tushganda kernel bergan satrlarni o'qiydi.

Uch oqibat:

1. Meros bir tomonlama. Bola ota muhitining nusxasini oladi; bola o'zgartirgani otaga qaytmaydi, chunki bu boshqa jarayonning xotirasi.
2. Skript alohida jarayonda ishlaydi (`bash script.sh` yoki `./script.sh`). Uning ichidagi `export` va `cd` skript tugagach yo'qoladi. Joriy shell'ni o'zgartirish uchun fayl `source fayl` (yoki `. fayl`) bilan shu shell ichida, yangi jarayonsiz o'qiladi. `nvm` va Python `venv` ning `activate` fayli shuning uchun `source` qilinadi.
3. Muhit jarayon ishga tushgan paytdagi surat. Ishlab turgan servisning muhitini tashqaridan o'zgartirib bo'lmaydi, uni qayta ishga tushirish kerak.

### Misol

```
ubuntu@lab:~$ APP_ENV=staging
ubuntu@lab:~$ echo "$APP_ENV"
staging
ubuntu@lab:~$ bash -c 'echo "[$APP_ENV]"'
[]
ubuntu@lab:~$ printenv APP_ENV; echo "exit: $?"
exit: 1
ubuntu@lab:~$ export APP_ENV
ubuntu@lab:~$ bash -c 'echo "[$APP_ENV]"'
[staging]
ubuntu@lab:~$ printenv APP_ENV; echo "exit: $?"
staging
exit: 0
```

- `echo "$APP_ENV"` qiymatni ko'rsatdi: kengayishni joriy shell qiladi, u o'z o'zgaruvchisini biladi.
- `bash -c '...'` yangi bash jarayonini ishga tushiradi va bittalik tirnoq ichidagi matnni unga buyruq sifatida beradi. Bola `[]` chiqardi: o'zgaruvchi muhitda yo'q edi.
- `printenv NOM` muhitdagi o'zgaruvchi qiymatini chiqaradi; yo'q bo'lsa hech narsa chiqarmay 1 qaytaradi. U tashqi dastur, shuning uchun faqat muhitni ko'radi.
- `export APP_ENV` dan keyin ikkalasi ham qiymatni ko'rdi. `export APP_ENV=staging` deb bir qatorda yozish ham mumkin.

Bitta buyruq uchun o'zgaruvchi: `LC_ALL=C sort fayl`, `NODE_ENV=production node app.js`. Buyruq oldidagi `NOM=qiymat` faqat shu bitta jarayonning muhitiga qo'shiladi, joriy shell'da hech narsa o'zgarmaydi. `package.json` skriptlaridagi `NODE_ENV=production webpack` aynan shu sintaksis (va shuning uchun Windows `cmd.exe` da ishlamaydi, `cross-env` paketi shu sababdan paydo bo'lgan).

Ko'rish va o'chirish: `env` yoki `printenv` (butun muhit), `set` (shell o'zgaruvchilari va funksiyalar ham), `declare -p NOM` (bitta o'zgaruvchi va uning atributlari: `declare -x` export qilingan degani), `unset NOM`.

| O'zgaruvchi | Ma'nosi |
|-------------|---------|
| `PATH` | buyruqlar qidiriladigan papkalar (3-bo'lim) |
| `HOME`, `USER`, `SHELL`, `PWD` | uy papkasi, foydalanuvchi, login shell, joriy papka |
| `LANG`, `LC_ALL` | locale: til, saralash tartibi, sana formati |
| `EDITOR`, `VISUAL` | standart muharrir (4-dars) |
| `PS1` | prompt ko'rinishi (shell o'zgaruvchisi, `export` qilinmaydi) |
| `$?`, `$$`, `$!` | oxirgi exit code, shell PID'i, oxirgi fon jarayonining PID'i (maxsus parametrlar, muhitda yo'q) |

Jarayonning boshlang'ich muhitini kernel `/proc/<PID>/environ` faylida ko'rsatadi (`/proc` 1-darsda), yozuvlar NUL bayt bilan ajratilgan:

```
ubuntu@lab:~$ tr '\0' '\n' < /proc/$$/environ | grep -c .
<son>
```

`tr '\0' '\n'` NUL baytlarni yangi qatorga almashtiradi, `grep -c .` bo'sh bo'lmagan qatorlarni sanaydi. `$$` joriy shell PID'i, ya'ni shell o'zining ishga tushgan paytdagi muhitini o'qiyapti. Bu fayl shu foydalanuvchi va root uchun ochiq.

**Tuzoq: muhit o'zgaruvchilari sir emas.** Jarayon muhiti `/proc/<PID>/environ` da ko'rinadi, barcha bola jarayonlarga o'tadi va crash dump'larga tushadi. Secret'ni muhitda berish qulay va keng tarqalgan, lekin u xavfsiz saqlash joyi emas.

### Real ishda qachon kerak

- "Twelve-factor" uslubida ilova sozlamalari muhit orqali beriladi: `DATABASE_URL`, `PORT`, `NODE_ENV`. Docker'da `-e`, systemd'da `Environment=`, Kubernetes'da `env:` hammasi shu `KEY=value` ro'yxatini to'ldiradi.
- "Terminalda ishlaydi, servisda ishlamaydi": servis jarayoni terminalingizning bolasi emas, u sizning `export` laringizni meros olmagan.
- `source .env` va `bash .env` farqi: ikkinchisi hech narsa qoldirmaydi.

### Nima uchun shunday

Muhit jarayonga argumentlardan tashqari sozlama berishning eng sodda yo'li: fayl formati ham, parser ham kerak emas, har til uni o'qiy oladi. Nusxa bo'lib meros qolishi izolyatsiya beradi: bola dastur otaning holatini buza olmaydi. Muqobili umumiy registr (Windows Registry kabi) bo'lar edi, unda bitta dasturning o'zgarishi hammaga ta'sir qiladi. Ikki xil o'zgaruvchi (shell va muhit) bo'lishining sababi: skript ichidagi vaqtinchalik `i`, `tmp`, `line` kabi o'zgaruvchilar har ishga tushirilgan dasturga sizib chiqmasligi kerak.

## 3. PATH

### Bu nima va qanday ishlaydi

Buyruq nomida `/` bo'lmasa va u funksiya yoki builtin bo'lmasa, shell uni `PATH` o'zgaruvchisidagi papkalardan chapdan o'ngga qidiradi va birinchi topilgan bajariladigan faylni ishga tushiradi. Papkalar `:` bilan ajratilgan. Nomda `/` bo'lsa (`./script.sh`, `/usr/bin/ls`) qidiruv bo'lmaydi, aynan shu fayl olinadi.

```
ubuntu@lab:~$ echo "$PATH"
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
ubuntu@lab:~$ type -a echo
echo is a shell builtin
echo is /usr/bin/echo
echo is /bin/echo
```

- `PATH` da 9 ta papka (toza VM'da; sizda `~/bin` yoki `~/.local/bin` mavjud bo'lsa, ular boshida turadi). `/usr/local/...` birinchi turadi: qo'lda o'rnatilgan dastur paketdan kelganidan ustun bo'lsin deb (FHS, 1-dars).
- `type -a` barcha mosliklarni qidiruv tartibida ko'rsatadi. Builtin `PATH` dan oldin keladi, shuning uchun `echo` deb yozganda `/usr/bin/echo` emas, bash'ning o'z `echo` si ishlaydi. `/bin/echo` va `/usr/bin/echo` bitta fayl: Ubuntu'da `/bin` bu `/usr/bin` ga symlink.

O'zgartirish: `PATH="$HOME/tools:$PATH"` (oldiga, sizning papkangiz ustun) yoki `PATH="$PATH:$HOME/tools"` (oxiriga, tizim buyruqlari ustun). `PATH` allaqachon muhitda, shuning uchun qayta `export` shart emas. O'zgarish faqat joriy shell va uning bolalarida; doimiy qilish 4-bo'limda.

Bu `node_modules/.bin` bilan bir xil mexanizm: `npm run` skriptni ishga tushirishdan oldin `PATH` ning oldiga loyihaning `node_modules/.bin` papkasini qo'shadi. Shuning uchun `package.json` da `"lint": "eslint ."` ishlaydi, terminalda esa `eslint` topilmaydi va `npx` yoki `./node_modules/.bin/eslint` kerak bo'ladi.

### hash: bash topganini eslab qoladi

```
ubuntu@lab:~$ hash -r
ubuntu@lab:~$ date > /dev/null
ubuntu@lab:~$ hash
hits	command
   1	/usr/bin/date
ubuntu@lab:~$ type date
date is hashed (/usr/bin/date)
```

`hash -r` keshni tozaladi; `date` bir marta ishga tushdi (chiqishi `/dev/null` ga tashlandi); `hash` jadvalida `hits` (necha marta ishlatilgani) va to'liq yo'l bor. Keyingi safar bash `PATH` ni qayta aylanmaydi. Oqibati: buyruq boshqa papkaga ko'chsa yoki `PATH` da oldinroq turgan papkada shu nomli yangi fayl paydo bo'lsa, bash eski yo'lni ishlataverishi mumkin. `hash -r` buni tuzatadi.

### 127 va 126

```
ubuntu@lab:~$ nosuchcmd; echo "exit: $?"
nosuchcmd: command not found
exit: 127
```

127: nom `PATH` dagi hech bir papkada topilmadi (Ubuntu'da nom biror paketdagi buyruqqa o'xshasa, qo'shimcha "qaysi paketni o'rnatish kerak" maslahati ham chiqadi). 126: fayl topildi, lekin uni bajarib bo'lmadi (bajarish huquqi yo'q yoki bu papka), xabar `Permission denied` yoki `Is a directory`.

**Tuzoq: `sudo`, cron va systemd'da `PATH` boshqa.** `sudo` standart holatda `PATH` ni `secure_path` ga almashtiradi (8-bo'lim), cron juda qisqa `PATH` beradi, systemd unit o'z standartiga ega. `~/.local/bin` yoki `nvm` orqali o'rnatilgan dastur u yerda topilmaydi. Skript va unit'larda absolut yo'l yozing yoki `PATH` ni aniq belgilang.

### Real ishda qachon kerak

- "command not found", lekin dastur o'rnatilgan: `type -a nom` va `echo "$PATH"` birinchi ikki tekshiruv.
- Bir dasturning ikki versiyasi (tizim `python3` va o'zingiz o'rnatgani, `nvm` dagi `node`): qaysi biri ishlashini `PATH` tartibi hal qiladi.
- Joriy papka `PATH` da yo'q va bo'lmasligi kerak. Shuning uchun skript `./script.sh` deb ishga tushiriladi.

### Nima uchun shunday

`PATH` bo'lmasa har buyruqni to'liq yo'l bilan yozish kerak bo'lar edi. Tartibli ro'yxat esa ustunlikni boshqarish imkonini beradi. Bahosi xavfsizlikda: `PATH` boshida turgan va boshqalar yoza oladigan papkaga kimdir `ls` nomli soxta dastur qo'ysa, siz uni ishga tushirasiz. Joriy papka (`.`) aynan shu sababdan `PATH` ga qo'shilmaydi (begona papkaga `cd` qilib `ls` yozish xavfli bo'lar edi), `sudo` ham shu sababdan `PATH` ni o'zinikiga almashtiradi.

## 4. Startup fayllar

### Bu nima

Startup fayl bu shell ishga tushganda o'zi o'qib bajaradigan skript: `PATH`, alias'lar, prompt shu yerda sozlanadi. Bash qaysi faylni o'qishi ikki xususiyatga bog'liq:

- **Login shell**: sessiyaning birinchi shell'i (ssh orqali kirish, konsol, `su - user`, `bash -l`). Vazifasi sessiya muhitini bir marta qurish.
- **Interaktiv shell**: terminalga ulangan, prompt chiqaradigan va buyruq kutadigan shell. Skriptni bajarayotgan shell interaktiv emas.

### Mexanizm: qaysi shell nimani o'qiydi

| Shell turi | Misol | O'qiladigan fayllar |
|------------|-------|---------------------|
| login | `ssh host`, `multipass shell lab`, `su - user`, `bash -l` | `/etc/profile` (u `/etc/profile.d/*.sh` ni yuklaydi), keyin birinchi topilgani: `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| interaktiv, login emas | terminal ichida `bash`, grafik terminal oynasi | `/etc/bash.bashrc` (Debian oilasi), `~/.bashrc` |
| interaktiv emas | skript, `bash -c '...'`, cron, CI | hech biri (faqat `$BASH_ENV` ko'rsatgan fayl, agar bo'lsa) |

Ubuntu'dagi uchta tafsilot jadvalni to'ldiradi:

- Standart `~/.profile` ichida `~/.bashrc` ni yuklaydigan qator bor, shuning uchun login shell ham `.bashrc` ni o'qiydi. Yana u `~/bin` va `~/.local/bin` papkalari **mavjud bo'lsa** ularni `PATH` oldiga qo'shadi: papkani yaratganingizdan keyin u faqat keyingi login'da `PATH` ga tushadi. `~/.bash_profile` yaratsangiz `~/.profile` o'qilmay qoladi (birinchi topilgani qoidasi).
- Standart `~/.bashrc` boshida `case $- in *i*) ;; *) return;; esac` turadi: shell interaktiv bo'lmasa fayl shu yerda to'xtaydi. Undan pastga yozilgan qatorlar interaktiv bo'lmagan shell'ga ta'sir qilmaydi.
- Bash manual'idagi istisno: bash o'zini ssh daemon ishga tushirganini aniqlasa (`ssh host 'buyruq'` holati), interaktiv bo'lmasa ham `~/.bashrc` ni o'qiydi. Yuqoridagi `case` qatori aynan shu holat uchun yozilgan. `multipass exec` qaysi turga tushishini 6 va 7-vazifalarda o'zingiz o'lchaysiz.

RHEL oilasida (2-dars) fayllar `~/.bash_profile` va `/etc/bashrc`. zsh'da (host) nomlar boshqa: `~/.zshenv` (har doim), `~/.zprofile` (login), `~/.zshrc` (interaktiv).

### Misol: men qaysi shell'daman

```
ubuntu@lab:~$ echo $0
-bash
ubuntu@lab:~$ shopt -q login_shell && echo login || echo non-login
login
ubuntu@lab:~$ echo $-
himBHs
ubuntu@lab:~$ bash -c 'echo $0; echo $-; shopt -q login_shell && echo login || echo non-login'
bash
hBc
non-login
```

- `-bash`: nom oldidagi `-` login shell belgisi (uni login dasturi qo'yadi). `multipass shell` ssh orqali kiradi, shuning uchun bu login shell.
- `shopt -q login_shell` bash'ning `login_shell` opsiyasini tekshiradi va natijani faqat exit code bilan beradi (7-bo'lim).
- `$-` joriy shell opsiyalari harflari. `i` bor: interaktiv. `bash -c` da `i` yo'q, `c` bor (buyruq `-c` orqali berilgan): interaktiv emas, login ham emas, demak hech bir startup fayl o'qilmagan.

Nima qayerga yoziladi:

| Narsa | Qayerga | Sabab |
|-------|---------|-------|
| muhit o'zgaruvchilari, `PATH` | `~/.profile` | bir marta, login'da o'rnatiladi va barcha bolalarga meros bo'ladi |
| alias, funksiya, prompt, completion | `~/.bashrc` | meros bo'lmaydi, har interaktiv shell'da qayta kerak |
| barcha foydalanuvchilar uchun muhit | `/etc/profile.d/nom.sh` | paketlar ham shu yerga qo'yadi |

Fayl o'zgartirilgach yangi sessiya oching yoki `source ~/.bashrc` qiling (2-bo'lim: `source` joriy shell ichida o'qiydi).

**Tuzoq: cron va systemd bu fayllarning hech birini o'qimaydi.** `.bashrc` dagi `export DATABASE_URL=...` terminalda bor, cron job'da yo'q. Servis muhiti unit faylida (`Environment=`, `EnvironmentFile=`) beriladi, 11-darsda.

### Real ishda qachon kerak

- `nvm`, `pyenv`, Go o'rnatuvchilari "shu qatorni `~/.bashrc` ga qo'shing" deydi. Qator `case` tekshiruvidan pastda bo'lsa, `ssh server 'node -v'` va CI'da dastur topilmaydi.
- Yangi serverda alias ishlamayapti yoki `PATH` to'liq emas: avval shell turini (`echo $0`, `echo $-`) aniqlang.
- Docker'da `RUN` va `CMD` login ham, interaktiv ham bo'lmagan shell'da ishlaydi: image ichidagi `.bashrc` u yerda o'qilmaydi, muhit `ENV` bilan beriladi.

### Nima uchun shunday

Ikki fayl bo'linishi muhit va interaktiv qulayliklar tabiati har xil bo'lgani uchun: muhit meros bo'ladi, uni bir marta login'da qurish yetarli; alias va funksiyalar meros bo'lmaydi, ular har interaktiv shell'da qayta aniqlanishi kerak. Interaktiv bo'lmagan shell hech narsa o'qimasligi esa skriptlarni oldindan aytib bo'ladigan qiladi: skript natijasi uni kim ishga tushirganiga va uning shaxsiy alias'lariga bog'liq bo'lmasligi kerak. Tarixiy tartibsizlik (`.bash_profile`, `.bash_login`, `.profile`) Bourne shell (`.profile`) va C shell (`.login`) bilan moslikdan qolgan.

## 5. Quoting

### Bu nima

Quoting (tirnoqlash) shell'ga "bu belgilarni maxsus deb hisoblama" deyish usuli. 1-bo'limdagi qadamlar tilida: tirnoq qaysi kengayishlar ishlashini va natija so'zlarga bo'linishini boshqaradi.

| Yozuv | Shell nima qiladi |
|-------|-------------------|
| `'...'` | hech narsa: ichidagi har belgi harfma-harf |
| `"..."` | `$VAR`, `$(cmd)`, `$((...))`, `\` ishlaydi; word splitting va globbing o'chadi |
| tirnoqsiz | hamma kengayishlar, keyin word splitting va globbing |
| `\x` | bitta belgini ekranlaydi (escape) |

### Mexanizm: word splitting

3-qadamdagi kengayish natijasi tirnoqsiz bo'lsa, bash uni `IFS` o'zgaruvchisidagi belgilar (standart: bo'shliq, tab, yangi qator) bo'yicha alohida so'zlarga bo'ladi, har so'z alohida argument bo'ladi. Keyin har so'z glob pattern sifatida tekshiriladi. Qo'shtirnoq ichidagi kengayish har doim bitta so'z bo'lib qoladi. 1-bo'limdagi `msg="a    b"` misoli shuni ko'rsatgan edi.

### Misol: argumentlar chegarasi

`printf '[%s]\n'` har argumentni alohida qatorda qavs ichida chiqaradi, argument chegaralarini ko'rish uchun qulay. `set --` joriy shell'ning pozitsion parametrlarini (`$1`, `$2`, ...) o'rnatadi:

```
ubuntu@lab:~$ set -- "a b" c
ubuntu@lab:~$ echo "$#"
2
ubuntu@lab:~$ printf '[%s]\n' "$@"
[a b]
[c]
ubuntu@lab:~$ printf '[%s]\n' $@
[a]
[b]
[c]
ubuntu@lab:~$ printf '[%s]\n' "$*"
[a b c]
ubuntu@lab:~$ echo '$HOME' "$HOME" \$HOME
$HOME /home/ubuntu $HOME
```

- `$#` argumentlar soni: 2 (`a b` va `c`).
- `"$@"`: har argument alohida so'z bo'lib, o'zgarishsiz uzatildi. Argumentlarni boshqa buyruqqa uzatishning yagona to'g'ri shakli.
- Tirnoqsiz `$@`: `a b` word splitting'dan o'tib ikkiga bo'lindi, ikki argument uchtaga aylandi.
- `"$*"`: hamma argument bitta satrga yopishtirildi. Xabar chop etish uchun yaraydi, uzatish uchun emas.
- Oxirgi qator: bittalik tirnoq va `\` kengayishni to'xtatdi, qo'shtirnoq esa yo'q.

`$@` Node'dagi `process.argv.slice(2)` ning o'xshashi: dasturga berilgan argumentlar ro'yxati. Farqi: Node'da massiv massivligicha qoladi, bash'da esa tirnoq qo'ymasangiz ro'yxat qayta bo'linadi.

Qoidalar:

- O'zgaruvchi va `$(...)` har doim qo'shtirnoqda: `"$var"`, `"$(cmd)"`. Istisno juda kam va ataylab qilinadi.
- Buyruq natijasini olish (command substitution): `$(cmd)`. Shell `cmd` ni bola jarayonda bajaradi, stdout'ini oladi va oxiridagi yangi qatorlarni olib tashlaydi. Eski shakli teskari tirnoq, ichma-ich yozish qiyin, yangi kodda ishlatilmaydi.
- ssh va `docker exec` da ikki qavat shell bor: `ssh host "echo $HOME"` da `$HOME` sizning mashinangizda ochiladi, `ssh host 'echo $HOME'` da serverda. `multipass exec lab -- bash -c '...'` ham shunday: bittalik tirnoq matnni host shell'idan himoya qiladi.

### Real ishda qachon kerak

- Bo'shliqli fayl nomlari va yo'llar (macOS'da `Application Support`, foydalanuvchi yuklagan fayllar): tirnoqsiz skript ularda buziladi yoki boshqa faylni o'chiradi.
- Bo'sh o'zgaruvchi: `rm -rf $DIR/` da `DIR` bo'sh bo'lsa buyruq `rm -rf /` ga aylanadi. Tirnoq va `set -u` (9-bo'lim) shundan himoya.
- CI YAML'laridagi shell qatorlari: YAML tirnog'i va shell tirnog'i ikki alohida qavat.

### Nima uchun shunday

Word splitting 1970-yillardagi Bourne shell'dan qolgan: o'sha paytda massivlar yo'q edi va `FILES="a b c"` ni ro'yxat sifatida ishlatish uchun tirnoqsiz kengayish bo'linadigan qilingan. Bugun bu ko'proq xato manbai, lekin bash eski skriptlar bilan moslikni saqlaydi. zsh bu qoidani ataylab o'zgartirgan (tirnoqsiz `$var` bo'linmaydi), shuning uchun host'dagi tajriba VM'dagidan farq qiladi. Bash'da ro'yxat kerak bo'lsa massiv (`arr=(a "b c")`, `"${arr[@]}"`) ishlatiladi.

## 6. Redirection va pipe

### Bu nima

Har jarayonda uchta standart oqim bor: 0 stdin (kirish), 1 stdout (natija), 2 stderr (xato va diagnostika). Bu raqamlar **file descriptor** (fd): jarayonning ochiq fayllari jadvalidagi indeks. Dastur "1-raqamga yozaman" deydi va u yerda terminalmi, faylmi, pipe'mi turganini bilmaydi. Redirection shu jadvalni dastur ishga tushishidan oldin o'zgartirish.

### Mexanizm

Shell `fork` qilgach, `exec` dan oldin bola jarayonda kerakli fd'larni qayta ulaydi (faylni ochadi va uni 1 yoki 2-raqamga ko'chiradi), keyin dasturni ishga tushiradi. Jadvalni kernel `/proc/<PID>/fd` da ko'rsatadi:

```
ubuntu@lab:~$ ls -l /proc/self/fd
total 0
lrwx------ 1 ubuntu ubuntu 64 <sana> 0 -> /dev/pts/0
lrwx------ 1 ubuntu ubuntu 64 <sana> 1 -> /dev/pts/0
lrwx------ 1 ubuntu ubuntu 64 <sana> 2 -> /dev/pts/0
lr-x------ 1 ubuntu ubuntu 64 <sana> 3 -> /proc/<PID>/fd
ubuntu@lab:~$ ls -l /proc/self/fd > /tmp/fd.txt; grep ' 1 -> ' /tmp/fd.txt
l-wx------ 1 ubuntu ubuntu 64 <sana> 1 -> /tmp/fd.txt
```

`/proc/self` har doim o'qiyotgan jarayonning o'ziga (bu yerda `ls` ga) ko'rsatadi. Birinchi chiqishda 0, 1, 2 hammasi `/dev/pts/0` ga, ya'ni terminalga (1-dars) ulangan; 3 bu `ls` ning o'zi papkani o'qish uchun ochgan fd. Ikkinchisida `>` tufayli 1-raqam `/tmp/fd.txt` ga qaragan, `ls` esa buni bilmaydi ham.

| Yozuv | Ma'nosi |
|-------|---------|
| `cmd > f` | stdout faylga, fayl avval bo'shatiladi |
| `cmd >> f` | stdout fayl oxiriga qo'shiladi |
| `cmd < f` | stdin fayldan |
| `cmd 2> f` | stderr faylga |
| `cmd > f 2>&1` | ikkalasi bitta faylga (`&> f` bash qisqartmasi) |
| `cmd > /dev/null 2>&1` | hamma chiqishni tashlash (`/dev/null` yozilganni yutadigan maxsus fayl) |
| `a \| b` | `a` ning stdout'i `b` ning stdin'iga; stderr terminalda qoladi |
| `a 2>&1 \| b` | stderr ham pipe'ga |
| `cmd \| tee f` | chiqish ham ekranga, ham faylga |
| `cmd <<EOF ... EOF` | here-document: keyingi qatorlar stdin bo'ladi |
| `cmd <<< "matn"` | here-string: bitta satr stdin bo'ladi |

### Misol: ikki oqim

```
ubuntu@lab:~$ both() { echo out; echo err >&2; }
ubuntu@lab:~$ both > /dev/null
err
ubuntu@lab:~$ both 2> /dev/null
out
ubuntu@lab:~$ both | wc -l
err
1
ubuntu@lab:~$ both 2>&1 | wc -l
2
```

- `both` funksiyasi bir qatorni stdout'ga, bir qatorni stderr'ga yozadi (`>&2`: "stdout'ni 2 qaragan joyga ula").
- `> /dev/null` faqat 1-raqamni tashladi, `err` ekranda qoldi. `2> /dev/null` aksincha.
- `both | wc -l`: pipe faqat stdout'ni oladi. `err` pipe'ni chetlab to'g'ri terminalga chiqdi, `wc` bitta qator sanadi.
- `2>&1 |` bilan ikkala qator pipe'ga tushdi.

**Tartib muhim.** Redirection'lar chapdan o'ngga qo'llanadi va `2>&1` "2 ni 1 bilan bog'la" emas, "2 ni 1 **hozir** qarab turgan joyga ula" degani. `> f 2>&1`: avval 1 faylga, keyin 2 ham o'sha faylga. `2>&1 > f`: avval 2 terminalga (1 hali terminalda edi), keyin 1 faylga; natijada stderr ekranda qoladi.

Here-document'da `<<EOF` ichida o'zgaruvchilar va `$(...)` ochiladi, `<<'EOF'` (tirnoqli) da matn harfma-harf qoladi. Konfiguratsiya fayli yoki boshqa skriptni generatsiya qilishda bu farq hal qiluvchi.

**Tuzoq: `sudo cmd > /etc/fayl`.** Redirection'ni `sudo` emas, sizning shell'ingiz 6-qadamda bajaradi, u esa root emas: `Permission denied`. Yechim: yozishni root nomidan ishlaydigan dasturga topshirish, `cmd | sudo tee /etc/fayl > /dev/null` (qo'shish uchun `tee -a`).

**Tuzoq: bir faylni o'qib o'ziga yozish.** `sort f > f` faylni bo'shatadi: `>` 6-qadamda, `sort` ishga tushishidan oldin faylni kesadi. Vaqtinchalik faylga yozib `mv` qiling, yoki `sort -o f f`.

### Real ishda qachon kerak

- Log yig'ish: Docker va systemd servisning stdout va stderr'ini ushlab log qiladi. Shuning uchun konteynerdagi ilova faylga emas, stdout'ga yozadi (Node'da `console.log` stdout'ga, `console.error` stderr'ga).
- Cron job'da `>> /var/log/job.log 2>&1`: usiz xatolar yo'qoladi.
- Skriptda xato xabarlari stderr'ga: `echo "error: ..." >&2`. Shunda `script | boshqa` da xato ma'lumotga aralashmaydi.

### Nima uchun shunday

Unix'ning asosiy g'oyasi: dastur qayerdan o'qib qayerga yozayotganini bilmasligi kerak, shunda kichik dasturlarni pipe bilan ulash mumkin. stderr alohida oqim qilingani ham shundan: natija pipe'ga ketganda xato xabari foydalanuvchiga ko'rinib qolsin va keyingi dasturning kirishini buzmasin. Muqobili (har dastur o'zi `--output fayl` flag'ini qo'llab-quvvatlashi) har dasturda qayta yozishni talab qilar edi.

## 7. Exit code'lar

### Bu nima va qanday ishlaydi

Har jarayon tugaganda kernel'ga 0–255 oralig'ida bitta son qoldiradi, ota jarayon uni `wait` system call'i bilan oladi (1-darsda asoslari). 0 muvaffaqiyat, boshqa har qanday son xato. Shell oxirgi buyruqning kodini `$?` ga yozadi va keyingi buyruq uni ustidan yozadi. Node'da bu `process.exit(n)`: ushlanmagan exception bilan o'lgan Node jarayoni 1 qaytaradi, `process.exitCode = 0` bilan tugagani 0.

| Kod | Ma'nosi |
|-----|---------|
| 0 | muvaffaqiyat |
| 1 | umumiy xato (`grep` da: topilmadi) |
| 2 | noto'g'ri ishlatish (ko'p utilitalarda; `grep` da: xato yuz berdi) |
| 126 | topildi, lekin bajarib bo'lmadi |
| 127 | buyruq topilmadi |
| 128+N | N-signal bilan tugagan: 130 (`Ctrl+C`, SIGINT 2), 137 (SIGKILL 9), 143 (SIGTERM 15) |

1 va 2 ning aniq ma'nosini har dastur o'zi belgilaydi, `man` sahifasining EXIT STATUS bo'limida yoziladi. 126, 127 va 128+N ni shell qo'yadi.

### Misol

```
ubuntu@lab:~$ sh -c 'exit 3'; echo $?
3
ubuntu@lab:~$ sh -c 'exit 300'; echo $?
44
ubuntu@lab:~$ sh -c 'kill -TERM $$'; echo $?
Terminated
143
ubuntu@lab:~$ true | sh -c 'exit 3' | true; echo "${PIPESTATUS[@]}"
0 3 0
ubuntu@lab:~$ true | sh -c 'exit 3' | true; echo $?
0
ubuntu@lab:~$ set -o pipefail
ubuntu@lab:~$ true | sh -c 'exit 3' | true; echo $?
3
ubuntu@lab:~$ set +o pipefail
```

- `sh -c 'exit 3'`: bola shell 3 bilan tugadi, `$?` shuni ko'rsatdi.
- `exit 300` dan 44 chiqdi: kod bitta bayt, `300 - 256 = 44`. 255 dan katta kod yo'q.
- `kill -TERM $$`: bola o'ziga SIGTERM yubordi (signal'lar 9-darsda). Bash `Terminated` deb xabar berdi, kod `128 + 15 = 143`.
- `PIPESTATUS` massivi oxirgi pipeline'dagi har bo'g'inning kodini saqlaydi: `0 3 0`.
- Pipeline'ning o'z kodi standart holatda **oxirgi** buyruqniki, shuning uchun o'rtadagi 3 yo'qoldi va `$?` 0 bo'ldi.
- `set -o pipefail` bilan pipeline kodi noldan farqli kod qaytargan eng o'ngdagi buyruqniki (hammasi 0 bo'lsa 0). `set +o pipefail` o'chiradi.

Kodga tayangan konstruksiyalar:

- `a && b`: `b` faqat `a` 0 qaytarsa. `a || b`: faqat `a` xato bersa. `a ; b`: har doim.
- `if cmd; then ...; fi` shartni emas, buyruqning exit code'ini tekshiradi. `[ ... ]` oddiy builtin buyruq (`test` ning boshqa nomi), `[[ ... ]]` bash kalit so'zi; ikkalasi ham natijani exit code bilan beradi.
- `cmd -q` kabi "jim" rejimlar (`grep -q`, `shopt -q`) aynan shu uchun: chiqish kerak emas, faqat kod.

### Real ishda qachon kerak

- CI har qadamni exit code bo'yicha baholaydi: `npm test` 0 dan farqli qaytarsa pipeline qizil. Xatoni chop etib `exit 0` qilgan skript "yashil" bo'ladi.
- systemd servis kodiga qarab qayta ishga tushirish qarorini qiladi (11-dars). Docker va Kubernetes'da konteyner `Exited (137)` bo'lsa, bu SIGKILL (ko'pincha xotira limiti).
- `curl ... | tar xz`: `pipefail` siz `curl` xatosi ko'rinmaydi.

### Nima uchun shunday

Bitta son eng sodda universal protokol: har til uni qaytara oladi va har ota jarayon uni o'qiy oladi, matnni parse qilish kerak emas. 0 ning muvaffaqiyat ekani mantiqan teskari ko'rinadi (JS'da `0` falsy), sababi: muvaffaqiyat bitta, xato turlari esa ko'p, ular uchun 255 ta qiymat qoladi. Pipeline'da oxirgi kodning olinishi tarixiy qaror; `pipefail` keyinroq qo'shilgan va standart qilinmagan, chunki ba'zi pipeline'larda oraliq xato normal (masalan `cmd | head -1` da `cmd` SIGPIPE bilan tugashi mumkin).

## 8. sudo va sudoers

### Bu nima

`sudo` buyruqni boshqa foydalanuvchi (standart: `root`, hamma narsaga ruxsati bor administrator; foydalanuvchilar 10-darsda) nomidan ishga tushiradi. Oldin siyosatni (`/etc/sudoers`) tekshiradi, kerak bo'lsa **sizning** parolingizni so'raydi (root'nikini emas) va har chaqiruvni logga yozadi.

### Mexanizm

```
ubuntu@lab:~$ ls -l /usr/bin/sudo
-rwsr-xr-x 1 root root <hajm> <sana> /usr/bin/sudo
ubuntu@lab:~$ sudo whoami
root
ubuntu@lab:~$ sudo -u nobody whoami
nobody
```

- Ruxsatlardagi `s` (odatdagi `x` o'rnida) setuid biti: bu faylni kim ishga tushirsa ham jarayon fayl egasi, ya'ni root huquqi bilan boshlanadi (ruxsatlar 6-darsda). Shunday qilib oddiy foydalanuvchi ishga tushirgan `sudo` root bo'lib ishlaydi.
- Root bo'lgan `sudo` `sudoers` ni o'qiydi, sizga shu buyruq ruxsat etilganini tekshiradi, parolni tekshiradi, logga yozadi, muhitni tozalaydi va shundan keyingina so'ralgan buyruqni maqsad foydalanuvchi nomidan `exec` qiladi.
- `whoami` joriy foydalanuvchi nomini chiqaradi: `sudo` ostida `root`, `-u nobody` bilan `nobody` (huquqsiz tizim foydalanuvchisi).

Log yozuvi shunday ko'rinadi:

```
<sana> lab sudo[<PID>]:   ubuntu : TTY=pts/0 ; PWD=/home/ubuntu ; USER=root ; COMMAND=/usr/bin/whoami
```

Maydonlar: kim chaqirdi (`ubuntu`), qaysi terminaldan, qaysi papkada turib, kim nomidan (`USER=root`), qaysi buyruq (to'liq yo'l bilan).

| Buyruq | Nima qiladi |
|--------|-------------|
| `sudo cmd` | root nomidan bitta buyruq |
| `sudo -u postgres cmd` | boshqa foydalanuvchi nomidan |
| `sudo -i` | root'ning login shell'i (uning muhiti va uy papkasi) |
| `sudo -s` | root shell, sizning muhitingizning bir qismi bilan |
| `sudo -l` | sizga nima ruxsat etilgan (`-U user`: boshqa foydalanuvchiga) |
| `sudo -n cmd` | interaktiv emas: parol kerak bo'lsa so'ramaydi, xato bilan tugaydi |
| `sudo -k` | keshlangan autentifikatsiyani unutish (Ubuntu'da kesh 15 daqiqa) |
| `sudo -E cmd` | muhitni saqlab (siyosat ruxsat bersa) |

`sudo` standart holatda muhitni tozalaydi (`env_reset`: faqat xavfsiz deb belgilangan o'zgaruvchilar qoladi) va `PATH` ni `sudoers` dagi `secure_path` ga almashtiradi. Ubuntu 24.04 da: `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin`. Sizning `export` laringiz va `PATH` ga qo'shgan papkalaringiz `sudo` ostida yo'q.

### sudoers sintaksisi

```
# who   where = (as_user:as_group)  what
root    ALL=(ALL:ALL) ALL
%sudo   ALL=(ALL:ALL) ALL                 # % means a group
deploy  ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

- To'rt maydon: kim (foydalanuvchi yoki `%guruh`), qaysi hostda, kim nomidan, qaysi buyruqlar. Buyruq absolut yo'l bilan yoziladi; argumentlari ko'rsatilsa, faqat aynan shu argumentlar bilan ruxsat etiladi. Bir nechta buyruq vergul bilan ajratiladi.
- `NOPASSWD:` parol so'ramaydi. Avtomatlashtirish (CI, deploy) uchun kerak, lekin faqat aniq buyruqlar ro'yxati bilan.
- `Defaults` bilan boshlanadigan qatorlar qoida emas, `sudo` ning sozlamalari (`env_reset`, `secure_path` shu yerda).
- Qo'shimcha qoidalar `/etc/sudoers.d/` ga alohida fayl bo'lib qo'yiladi. Fayl nomida `.` bo'lsa yoki `~` bilan tugasa u o'tkazib yuboriladi; ruxsati `0440`. Multipass VM'dagi `ubuntu` foydalanuvchisi huquqi shu papkada: `/etc/sudoers.d/90-cloud-init-users`.
- Tahrirlash faqat `visudo` bilan: `sudo visudo` yoki `sudo visudo -f /etc/sudoers.d/nom`. U vaqtinchalik nusxani muharrirda ochadi (Ubuntu'da standart `nano`, 4-dars), saqlashdan keyin sintaksisni tekshiradi va faqat to'g'ri bo'lsa asl faylni almashtiradi. Butun konfiguratsiyani tekshirish: `sudo visudo -c`.

**Tuzoq: buzilgan `sudoers`.** Sintaksis xatosi bo'lgan `sudoers` bilan `sudo` umuman ishlamay qoladi. Root paroli bo'lmagan serverda (cloud'da odatiy holat) bu tizimdan qulflanish degani. Shuning uchun faqat `visudo`.

**Tuzoq: "faqat bitta buyruq" aslida root shell.** `vim`, `less`, `find`, `tar`, `awk` kabi dasturlar ichidan shell ochish yoki ixtiyoriy buyruq bajarish mumkin. Ularni `sudoers` da ruxsat etish to'liq root berish bilan teng. Ruxsat etilgan buyruq aniq, argumentlari bilan bo'lishi va foydalanuvchi o'zgartira olmaydigan faylga ko'rsatishi kerak.

### Real ishda qachon kerak

- Cloud serverlarda root bilan to'g'ridan-to'g'ri kirilmaydi: oddiy foydalanuvchi va `sudo`. Kim nima qilgani logda qoladi.
- Deploy foydalanuvchisi yoki CI runner'ga "faqat servisni qayta ishga tushirish" huquqini berish.
- Ansible (keyingi modul) vazifalarni `become: true` orqali aynan `sudo` bilan bajaradi.

### Nima uchun shunday

Muqobili hamma administrator bitta root parolini bilishi va `su` bilan root bo'lishi. Unda kim nima qilganini ajratib bo'lmaydi, bir kishi ketsa parolni hammaga almashtirish kerak, huquq esa "hammasi yoki hech narsa". `sudo` uchala muammoni yechadi: har kim o'z paroli bilan, har chaqiruv nomma-nom loglanadi, huquq buyruq darajasida beriladi. Muhitni tozalash va `secure_path` esa 3-bo'limdagi xavfning oldini oladi: foydalanuvchi o'z `PATH` i yoki `LD_PRELOAD` kabi o'zgaruvchi orqali root jarayoniga begona kod kirita olmasligi kerak.

## 9. Birinchi bash skript

### Bu nima va qanday ishga tushadi

Skript bu shell buyruqlari yozilgan matn fayl. Birinchi qatordagi **shebang** (`#!`) kernel uchun: `./script.sh` deganingizda kernel faylning dastlabki ikki baytini o'qiydi, `#!` ni ko'rsa qatorning qolganini interpretator deb oladi va uni skript yo'li bilan birga ishga tushiradi. `#!/usr/bin/env bash` da `env` bash'ni `PATH` dan topadi (bash turli tizimlarda turli joyda bo'lishi mumkin, masalan macOS'da Homebrew bash'i). `#!/bin/sh` bilan bash sintaksisi (`[[ ]]`, massivlar, `pipefail`) ishlamasligi mumkin: Ubuntu'da `sh` bu `dash`, kichikroq boshqa shell.

Ikki xil ishga tushirish: `chmod +x script.sh` va `./script.sh` (shebang ishlaydi, bajarish huquqi kerak), yoki `bash script.sh` (bash faylni o'qiydi, shebang oddiy komment, huquq shart emas).

### Misol

Berilgan fayllarning qator sonini chiqaradigan `lines.sh`:

```
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <file>..." >&2
  exit 2
}

[[ $# -ge 1 ]] || usage

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "skip: $f is not a regular file" >&2
    continue
  fi
  printf '%s\t%s\n' "$(wc -l < "$f")" "$f"
done
```

```
ubuntu@lab:~$ chmod +x lines.sh
ubuntu@lab:~$ ./lines.sh /etc/hostname /etc/nope; echo "exit: $?"
1	/etc/hostname
skip: /etc/nope is not a regular file
exit: 0
ubuntu@lab:~$ ./lines.sh; echo "exit: $?"
usage: ./lines.sh <file>...
exit: 2
```

Qatorma-qator:

- `set -e`: buyruq xato qaytarsa skript shu yerda to'xtaydi (istisno: `if` sharti va `&&`, `||` zanjirining oxirgisidan boshqa bo'g'inlari). `set -u`: aniqlanmagan o'zgaruvchiga murojaat xato (`$DIR` dagi imlo xatosi bo'sh satrga aylanmaydi). `set -o pipefail`: 7-bo'lim.
- `usage() { ...; }` funksiya. `$0` skript qanday chaqirilgan bo'lsa shu nom, xabar stderr'ga, kod 2 ("noto'g'ri ishlatish").
- `[[ $# -ge 1 ]] || usage`: argumentlar soni 1 dan kam bo'lsa `usage` chaqiriladi. `-ge`, `-eq`, `-lt`, `-gt` sonlarni solishtiradi.
- `for f in "$@"`: har argument bo'yicha sikl, tirnoq tufayli bo'shliqli nomlar butun qoladi (5-bo'lim).
- `[[ ! -f "$f" ]]`: oddiy fayl emasmi. Boshqa testlar: `-d` papka, `-e` mavjud, `-z` bo'sh satr, `-n` bo'sh emas, `==` satr tengligi.
- `wc -l < "$f"`: fayl stdin orqali berilgani uchun `wc` nomni chop etmaydi, faqat son.
- Standart qiymat: `"${1:-default}"` birinchi argument yo'q yoki bo'sh bo'lsa `default` ni beradi; `set -u` ostida argumentni xavfsiz o'qish usuli.

### shellcheck

**shellcheck** skriptni ishga tushirmasdan o'qib, quoting va mantiq xatolarini topadigan statik analizator (ESLint'ning shell uchun o'xshashi). Har topilma `SC` kodi bilan keladi, izohi `https://www.shellcheck.net/wiki/SC<raqam>` da. Host'da, ish papkasida: `shellcheck task_21.sh`. Toza skriptda hech narsa chiqmaydi va exit code 0. `make check` repo'dagi barcha `*.sh` fayllarni shu bilan tekshiradi.

### Real ishda qachon kerak

- CI pipeline qadamlari, Dockerfile `ENTRYPOINT` skriptlari, deploy va backup skriptlari, cloud-init: hammasi shell skript.
- Qoida: 50–100 qatordan oshgan yoki murakkab ma'lumot tuzilmasi kerak bo'lgan skript Python yoki Go'ga ko'chiriladi. Bash dasturlarni ulash uchun, hisoblash uchun emas.

### Nima uchun shunday

Shebang tufayli skript va kompilyatsiya qilingan binary bir xil ishga tushadi: chaqiruvchi fayl qaysi tilda yozilganini bilishi shart emas (`#!/usr/bin/env node` bilan boshlanadigan npm CLI'lar ham shunday ishlaydi). `set -euo pipefail` standart emasligining sababi tarixiy moslik: bash odatda xatodan keyin davom etadi, chunki interaktiv ishda bu qulay. Skriptda esa bu xavfli, shuning uchun uchala opsiya har skript boshida qo'lda yoqiladi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Expansion (kengayish) | shell buyruqni bajarishdan oldin `$VAR`, `$(cmd)`, `*`, `~`, `{a,b}` kabi yozuvlarni qiymatlarga almashtirishi |
| Word splitting | tirnoqsiz kengayish natijasining bo'shliq, tab va yangi qator bo'yicha alohida argumentlarga bo'linishi |
| Shell o'zgaruvchisi | faqat joriy shell ichida yashaydigan, bolalarga o'tmaydigan o'zgaruvchi |
| Muhit (environment) | har jarayonga ishga tushganda beriladigan `KEY=value` satrlari ro'yxati |
| `export` | shell o'zgaruvchisini muhitga qo'shadigan, ya'ni bolalarga meros qiladigan builtin |
| `source` (`.`) | faylni yangi jarayonsiz, joriy shell ichida o'qib bajarish |
| `PATH` | buyruq nomi qidiriladigan papkalarning `:` bilan ajratilgan tartibli ro'yxati |
| Login shell | sessiyaning birinchi shell'i, `/etc/profile` va `~/.profile` ni o'qiydi |
| Interaktiv shell | terminalga ulangan va prompt chiqaradigan shell, `~/.bashrc` ni o'qiydi |
| Startup fayl | shell ishga tushganda avtomatik o'qiladigan sozlama skripti |
| Quoting | tirnoq yoki `\` bilan belgilarning maxsus ma'nosini o'chirish |
| Command substitution | `$(cmd)`: buyruq stdout'ini satr sifatida qatorga qo'yish |
| File descriptor (fd) | jarayonning ochiq fayllari jadvalidagi raqam: 0 stdin, 1 stdout, 2 stderr |
| Redirection | dastur ishga tushishidan oldin fd'ni fayl yoki boshqa fd'ga ulash |
| Pipe | bir jarayonning stdout'ini ikkinchisining stdin'iga ulaydigan kanal |
| Here-document | `<<EOF` dan keyingi qatorlarni buyruqning stdin'iga berish |
| Exit code | jarayon tugaganda qaytaradigan 0–255 son, 0 muvaffaqiyat |
| `pipefail` | pipeline kodi oxirgi buyruqniki emas, xato qaytargan eng o'ngdagi buyruqniki bo'ladigan bash opsiyasi |
| `sudo` | siyosatni tekshirib, buyruqni boshqa foydalanuvchi (odatda root) nomidan ishga tushiradigan dastur |
| `sudoers` | kim qaysi buyruqni kim nomidan bajara olishini belgilaydigan `sudo` siyosat fayli |
| `visudo` | `sudoers` ni qulflab, sintaksisini tekshirib tahrirlaydigan buyruq |
| setuid | bajariladigan fayldagi bit: jarayon chaqiruvchi emas, fayl egasi huquqi bilan ishlaydi |
| Shebang | skriptning `#!` bilan boshlanadigan birinchi qatori, kernel'ga interpretatorni aytadi |
| shellcheck | shell skriptlar uchun statik analizator |

## Tuzoqlar

- Tirnoqsiz o'zgaruvchi: `rm $file`, `cd $dir`, `[ $x = y ]`. Bo'shliqli yoki bo'sh qiymatda buyruq boshqa narsani bajaradi. Har doim `"$var"`.
- Tajribani host'dagi zsh'da qilish: word splitting, `PIPESTATUS`, startup fayllar boshqacha, natija darsdagidan farq qiladi.
- `2>&1 > file` tartibi: stderr faylga tushmaydi. To'g'risi `> file 2>&1`.
- `sudo echo ... > /etc/...` va `sudo cat a > /root/b`: redirection root bilan bajarilmaydi.
- Pipeline exit code'i: `curl ... | tar xz` da `curl` xato bersa ham skript davom etadi. `set -o pipefail`.
- `.bashrc` ga yozilgan muhit o'zgaruvchisiga cron, systemd yoki CI'da tayanish.
- `~/.bash_profile` yaratish: Ubuntu'da `~/.profile` (va u orqali `~/.bashrc`) login'da o'qilmay qoladi.
- `PATH` ga tayangan skript `sudo` yoki cron ostida "command not found" beradi.
- `sudoers` ni `visudo` siz tahrirlash, yoki `NOPASSWD: ALL` ni servis foydalanuvchisiga berish.
- `sudoers` da muharrir, pager yoki interpretatorni ruxsat etish: bu root shell.
- `set -e` siz skript: o'rtadagi `cd` yoki `cp` xato beradi, skript davom etib noto'g'ri joyda ishlaydi.
- Secret'ni buyruq argumentida yoki `export` bilan berish: tarixda, `ps` da va `/proc/<PID>/environ` da ko'rinadi.

## Manbalar

- https://www.gnu.org/software/bash/manual/bash.html#Shell-Expansions – kengayishlar va ularning tartibi
- https://www.gnu.org/software/bash/manual/bash.html#Bash-Startup-Files – startup fayllar, ssh istisnosi bilan
- https://www.gnu.org/software/bash/manual/bash.html#Redirections – redirection
- https://www.gnu.org/software/bash/manual/bash.html#Exit-Status – exit status
- https://www.gnu.org/software/bash/manual/bash.html#Pipelines – pipeline va `pipefail`
- https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin – `set -e`, `-u`, `-x`, `-o pipefail`
- https://man7.org/linux/man-pages/man7/environ.7.html – `environ(7)`: jarayon muhiti
- https://man7.org/linux/man-pages/man2/execve.2.html – `execve(2)`: muhit va shebang qanday uzatiladi
- https://www.sudo.ws/docs/man/sudoers.man/ – `sudoers(5)`
- https://www.sudo.ws/docs/man/visudo.man/ – `visudo(8)`
- https://www.shellcheck.net/ – shellcheck, https://www.shellcheck.net/wiki/ da har xato kodi izohi
- https://mywiki.wooledge.org/Quotes – quoting bo'yicha batafsil
- https://mywiki.wooledge.org/BashPitfalls – bash'dagi keng tarqalgan xatolar
- https://google.github.io/styleguide/shellguide.html – Google Shell Style Guide
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 6, 7, 11 va 24–27 boblar

## Birga bajaramiz

Kichik buyruq yozib, uni "o'rnatamiz" va darsdagi hamma mexanizmdan o'tkazamiz: here-document, `PATH`, shell va muhit o'zgaruvchisi, redirection, exit code, `sudo`. Buyruq nomi `labstamp`: xabarni prefiks bilan chiqaradi, prefiks `STAMP_PREFIX` muhit o'zgaruvchisidan olinadi. Hamma narsa VM ichida, uy papkasida.

1. Skriptni here-document bilan yarating. Delimiter tirnoqda (`'EOF'`), aks holda `$#` va `$*` fayl yozilayotgan paytda ochilib ketar edi:

```
ubuntu@lab:~$ mkdir -p ~/tools
ubuntu@lab:~$ cat > ~/tools/labstamp <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# -eq 0 ]]; then
  echo "usage: labstamp <message>" >&2
  exit 2
fi
echo "[${STAMP_PREFIX:-none}] $*"
EOF
ubuntu@lab:~$ chmod +x ~/tools/labstamp
```

`${STAMP_PREFIX:-none}`: o'zgaruvchi yo'q yoki bo'sh bo'lsa `none`. Skript o'zgaruvchini faqat muhitdan olishi mumkin, chunki u alohida jarayon.

2. Nom bilan chaqiring, keyin to'liq yo'l bilan:

```
ubuntu@lab:~$ labstamp hi; echo "exit: $?"
labstamp: command not found
exit: 127
ubuntu@lab:~$ ~/tools/labstamp hi
[none] hi
```

Fayl bor va bajariladi, lekin `~/tools` `PATH` da yo'q: 127. Yo'lda `/` bo'lsa qidiruv kerak emas.

3. Papkani `PATH` oldiga qo'shing:

```
ubuntu@lab:~$ PATH="$HOME/tools:$PATH"
ubuntu@lab:~$ type labstamp
labstamp is /home/ubuntu/tools/labstamp
ubuntu@lab:~$ labstamp hi
[none] hi
```

`export` yozilmadi, chunki `PATH` allaqachon muhitda. Bu o'zgarish faqat shu sessiyada yashaydi.

4. Prefiksni uch usulda bering:

```
ubuntu@lab:~$ STAMP_PREFIX=dev
ubuntu@lab:~$ labstamp one
[none] one
ubuntu@lab:~$ export STAMP_PREFIX
ubuntu@lab:~$ labstamp two
[dev] two
ubuntu@lab:~$ STAMP_PREFIX=prod labstamp three
[prod] three
ubuntu@lab:~$ labstamp four
[dev] four
```

`one`: o'zgaruvchi shell'da bor, muhitda yo'q, skript ko'rmadi. `two`: `export` dan keyin ko'rdi. `three`: buyruq oldidagi qiymat faqat shu bitta jarayonga berildi. `four`: shell'dagi qiymat o'zgarmagan.

5. Natija va xatoni alohida fayllarga yo'naltiring:

```
ubuntu@lab:~$ labstamp start > out.log 2> err.log; echo "exit: $?"
exit: 0
ubuntu@lab:~$ labstamp >> out.log 2>> err.log; echo "exit: $?"
exit: 2
ubuntu@lab:~$ cat out.log
[dev] start
ubuntu@lab:~$ cat err.log
usage: labstamp <message>
```

Ikkinchi chaqiruv argumentsiz: usage stderr'ga yozilgani uchun `err.log` ga tushdi, `out.log` toza qoldi, kod 2.

6. Exit code'ga tayangan zanjir va pipeline:

```
ubuntu@lab:~$ labstamp finish >> out.log && echo logged || echo failed
logged
ubuntu@lab:~$ labstamp | tee -a out.log; echo "exit: $? pipe: ${PIPESTATUS[*]}"
usage: labstamp <message>
exit: 0 pipe: 2 0
```

Pipeline'da `labstamp` 2 qaytardi, lekin `$?` 0: oxirgi buyruq `tee` muvaffaqiyatli. Xato faqat `PIPESTATUS` da ko'rinadi. `pipefail` yoqilgan skriptda shu qator skriptni to'xtatar edi.

7. Xuddi shu buyruq `sudo` ostida:

```
ubuntu@lab:~$ sudo labstamp hi
sudo: labstamp: command not found
ubuntu@lab:~$ sudo "$(command -v labstamp)" hi
[none] hi
```

Birinchisi: `sudo` buyruqni `secure_path` dan qidirdi, `~/tools` u yerda yo'q. Ikkinchisi: `command -v` to'liq yo'lni berdi (kengayishni `sudo` emas, sizning shell'ingiz qildi), buyruq ishladi, lekin prefiks `none`: `env_reset` `STAMP_PREFIX` ni muhitdan olib tashladi.

8. Tozalang va sessiyani yangilang (`PATH` asl holiga qaytadi):

```
ubuntu@lab:~$ rm -r ~/tools out.log err.log
ubuntu@lab:~$ unset STAMP_PREFIX
ubuntu@lab:~$ exit
```

Shu 8 qadamda ko'rganingiz: tirnoqli here-document matnni kengayishdan saqlaydi (6-bo'lim), shebang va `set -euo pipefail` (9-bo'lim), buyruq `PATH` dan topiladi va topilmasa 127 (3-bo'lim), `export` va bitta buyruqlik o'zgaruvchi (2-bo'lim), stdout va stderr alohida yo'naltiriladi (6-bo'lim), `&&`, `||` va pipeline kodi (7-bo'lim), `sudo` `PATH` ni ham, muhitni ham almashtiradi (8-bo'lim). `PATH` ni doimiy qilish uchun qator `~/.profile` ga yozilar edi (4-bo'lim); bu yerda ataylab qilinmadi.

---

## Vazifalar

Ish papkasi: `linux/05-shell/` (`make new m=linux n=05 name=shell` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi (butun chiqish emas) va o'z so'zingiz bilan izoh. Skriptlar (`task_2.sh`, `task_21.sh`) shu papkada saqlanadi va `multipass transfer` bilan VM'ga ko'chiriladi. Barcha vazifalar `lab` VM'da, bash'da bajariladi; host'dagi zsh'da natija boshqacha chiqishi mumkin ("Laboratoriya" dagi jadval). Tizimni o'zgartiradigan vazifalar (13, 18–20) faqat VM'da.

### A. O'zgaruvchilar va PATH

1. **Shell versus environment.** `STAGE=dev` qiling. `echo "$STAGE"`, `bash -c 'echo "[$STAGE]"'` va `env | grep STAGE` natijalarini yozing. `export STAGE` dan keyin takrorlang. Bola shell ichida `STAGE=prod` qilib chiqing va ota shell'dagi qiymatni tekshiring. `STAGE = dev` (bo'shliq bilan) xatosini yozing va nima uchun bunday xato chiqishini izohlang. Yo'nalish: 2-bo'lim, "Ikki xil o'zgaruvchi" va "Misol".

2. **Run versus source.** `task_2.sh` yozing: ichida `cd /tmp`, `export FROM_SCRIPT=1` va `pwd`. Uni avval `bash task_2.sh`, keyin `source task_2.sh` bilan ishga tushiring. Har safar keyin `pwd` va `echo "$FROM_SCRIPT"` ni tekshiring. Farqni jarayonlar nuqtai nazaridan izohlang. `nvm` yoki Python `venv` nima uchun `source` talab qiladi? Skriptni host'dagi ish papkasida yozing va `multipass transfer task_2.sh lab:` bilan VM'ga ko'chiring. Yo'nalish: 2-bo'lim, "Mexanizm: muhit bu jarayonning xususiyati".

3. **One-shot variable.** `date` va `TZ=Asia/Tokyo date` ni solishtiring, keyin `echo "[$TZ]"` ni bajaring. `FOO=1 bash -c 'echo "[$FOO]"'; echo "[$FOO]"` natijasini yozing: `FOO` `export` qilinmagan bo'lsa ham bola uni nima uchun ko'rdi, ota shell'da esa nima uchun yo'q? Bu yozuv `export TZ=Asia/Tokyo; date` dan nimasi bilan farq qiladi va Node'dagi `NODE_ENV=production node app.js` bilan qanday bog'liq? Yo'nalish: 2-bo'lim, "Misol" (bitta buyruq uchun o'zgaruvchi).

4. **PATH lookup.** `~/bin/hello` skriptini yarating (bitta `echo`), `chmod +x` qiling. `hello` ishlaydimi? `PATH` ga qo'shing va qayta sinang. Keyin `~/bin/date` nomli, `echo fake date` chiqaradigan skript yarating: `date`, `type -a date`, `hash` natijalarini yozing. `~/bin` ni `PATH` ning boshiga va oxiriga qo'yib farqni ko'ring. Oxirida soxta `date` ni o'chiring. Bu xatti-harakatning xavfsizlik oqibati nima? Eslatma: Ubuntu'ning `~/.profile` fayli `~/bin` ni keyingi login'da o'zi `PATH` ga qo'shadi, shuning uchun tajribani joriy sessiyada, qayta kirmasdan bajaring. Yo'nalish: 3-bo'lim, "Bu nima va qanday ishlaydi" va "hash: bash topganini eslab qoladi".

5. **126 and 127.** Bajarish huquqi yo'q skriptni `./x.sh` deb, mavjud bo'lmagan buyruqni, va papkani buyruq sifatida (`/tmp`) ishga tushiring. Har birida xato matni va `$?` ni yozing. Keyin `PATH= ls` va `PATH= cd /tmp && pwd` ni bajaring: biri nima uchun ishlamadi, ikkinchisi ishladi? Yo'nalish: 3-bo'lim, "127 va 126"; 1-bo'lim, "Mexanizm: to'qqiz qadam" (7-qadam).

### B. Startup fayllar

6. **Load order trace.** `~/.profile` va `~/.bashrc` ning eng boshiga (`.bashrc` da interaktivlik tekshiruvidan oldin) `echo "loading: <fayl nomi>" >&2` qatorini qo'shing. Keyin to'rt usulda shell oching va qaysi fayllar yuklanganini jadvalga yozing: `multipass shell lab`, uning ichida `bash`, `bash -l`, va `bash -c 'echo hi'`. Beshinchi: host'dan (Zorin yoki macOS terminali) `multipass exec lab -- bash -c 'echo hi'`. Natijani 4-bo'limdagi jadval bilan solishtiring. Oxirida qo'shilgan qatorlarni olib tashlang. Yo'nalish: 4-bo'lim, "Mexanizm: qaysi shell nimani o'qiydi".

7. **Alias scope.** `~/.bashrc` ga `alias k='echo kubectl'` va `export FROM_RC=1` qo'shing (interaktivlik tekshiruvidan pastga). Yangi sessiyada `k` va `echo "$FROM_RC"` ishlaydimi? `bash -c 'k; echo "[$FROM_RC]"'` da-chi? Ish mashinasidan `multipass exec lab -- bash -c 'echo "[$FROM_RC]"'` da-chi? Har natijani izohlang va o'zgaruvchi to'g'ri joyga ko'chirilgandan keyin qaysi holat o'zgarishini ko'rsating. Yo'nalish: 4-bo'lim, "Mexanizm: qaysi shell nimani o'qiydi" va "Nima qayerga yoziladi" jadvali.

8. **Cron-like environment.** `env -i bash --noprofile --norc -c 'env; echo "PATH=$PATH"'` ni bajaring. Qaysi o'zgaruvchilar bor? Shu muhitda 4-vazifadagi `hello` topiladimi? Bundan kelib chiqib, cron yoki systemd'dan ishga tushadigan skript uchun uchta qoida yozing. Yo'nalish: 3-bo'lim, tuzoq "`sudo`, cron va systemd'da `PATH` boshqa"; 4-bo'lim, tuzoq "cron va systemd bu fayllarning hech birini o'qimaydi".

### C. Quoting

9. **Three quote types.** `name="Ali Valiyev"` uchun `echo '$name'`, `echo "$name"`, `echo $name`, `echo "\$name"` natijalarini yozing. `f="my file.txt"` uchun `touch $f; ls -l` va `touch "$f"; ls -l` ni solishtiring. `pattern="*"` uchun `echo $pattern` va `echo "$pattern"` farqini 1-bo'limdagi qadamlar bilan izohlang. Yo'nalish: 5-bo'lim, "Bu nima" jadvali; 1-bo'lim, "Mexanizm: to'qqiz qadam".

10. **Command substitution.** `backup-YYYY-MM-DD.tar` ko'rinishidagi nomni `$(date ...)` bilan hosil qiling. `echo "Kernel: $(uname -r), files in /etc: $(ls /etc | wc -l)"` ni yozing. `files=$(ls /etc)` dan keyin `echo $files | wc -l` va `echo "$files" | wc -l` nima uchun farq qiladi? Yo'nalish: 5-bo'lim, "Mexanizm: word splitting" va "Qoidalar" (command substitution).

11. **Word splitting bug.** Papkada `a.txt`, `b c.txt`, `d.txt` yarating. `for f in $(ls); do echo "[$f]"; done` va `for f in *; do echo "[$f]"; done` natijalarini solishtiring. Birinchisi nima uchun buziladi? `args() { echo "$#"; }` funksiyasini yozib `args $f`, `args "$f"`, `args "$@"` kabi chaqiruvlar bilan argumentlar sonini ko'rsating. Yo'nalish: 5-bo'lim, "Misol: argumentlar chegarasi".

### D. Redirection va exit code

12. **stdout and stderr.** `ls /etc/hostname /nope` ni: (a) stdout va stderr alohida fayllarga, (b) ikkalasi bitta faylga, (c) faqat xatoni ko'rsatib, (d) faqat natijani ko'rsatib bajaring. Keyin `ls /etc/hostname /nope > out.txt 2>&1` va `ls /etc/hostname /nope 2>&1 > out.txt` ni solishtiring: ekranda nima qoldi, faylda nima? `ls /etc/hostname /nope | wc -l` nima uchun 1 chiqaradi? Yo'nalish: 6-bo'lim, "Misol: ikki oqim" va "Tartib muhim".

13. **sudo redirect trap.** `sudo echo "test" > /etc/lab.conf` ni bajaring va xatoni yozing. Kim faylni ochmoqchi bo'ldi? Ikki to'g'ri usulni yozing (`tee` bilan va `sudo sh -c` bilan), har birini sinang. Fayl oxiriga qator qo'shish variantini ham ko'rsating. Oxirida faylni o'chiring. Yo'nalish: 6-bo'lim, tuzoq "`sudo cmd > /etc/fayl`".

14. **Truncation trap.** 5 qatorli `n.txt` yarating (`printf` yoki `seq`). `sort -r n.txt > n.txt` dan keyin faylni ko'ring. Nima uchun bo'sh? Ikki to'g'ri usulni yozing. `set -o noclobber` yoqilganda `echo x > n.txt` nima qiladi va uni qanday chetlab o'tiladi? Yo'nalish: 6-bo'lim, tuzoq "bir faylni o'qib o'ziga yozish"; `noclobber` uchun `help set` va bash manual'ining Redirections bo'limi.

15. **Here-document.** `cat > app.conf <<EOF` bilan `user=$USER`, `home=$HOME`, `date=$(date +%F)` qatorli fayl yarating. Xuddi shuni `<<'EOF'` bilan `app.tpl` ga yozing va ikki faylni solishtiring. Qaysi birini konfiguratsiya, qaysi birini shablon yoki skript generatsiyasi uchun ishlatasiz? `grep ubuntu <<< "$(id)"` nima qiladi? Yo'nalish: 6-bo'lim, here-document haqidagi xatboshi va jadval.

16. **Exit codes.** Quyidagilar uchun `$?` ni yozing va izohlang: `true`, `false`, `grep -q root /etc/passwd`, `grep -q nope /etc/passwd`, `grep x /nope`, `ls /nope`, `sleep 30` ni `Ctrl+C` bilan to'xtatgandan keyin, boshqa terminaldan `kill -9` qilingandan keyin. `mkdir d && cd d || echo failed` zanjiri qanday ishlaydi? `false; echo $?; echo $?` nima uchun `1` va `0` chiqaradi? Yo'nalish: 7-bo'lim, kodlar jadvali va "Misol".

17. **pipefail.** `false | true; echo $?` va `cat /nope | wc -l; echo "${PIPESTATUS[@]}"` natijalarini yozing. `set -o pipefail` dan keyin takrorlang. `curl -fsS https://example.invalid | tar xz` kabi qatorli deploy skriptida `pipefail` siz nima bo'lishini izohlang. Yo'nalish: 7-bo'lim, "Misol" (`PIPESTATUS`, `pipefail`).

### E. sudo

18. **sudo inspection.** `sudo -l` natijasini yozing. `sudo cat /etc/sudoers` va `sudo cat /etc/sudoers.d/90-cloud-init-users` dan: `Defaults` qatorlari nima qiladi, `%sudo` qatori nimani anglatadi, `ubuntu` foydalanuvchisi huquqi qaysi qatorda? `env | grep -c .` va `sudo env | grep -c .` ni, `echo $PATH` va `sudo sh -c 'echo $PATH'` ni solishtiring. `sudo` chaqiruvlaringiz qayerda loglangan (`sudo grep sudo /var/log/auth.log | tail -5` yoki `journalctl -t sudo`)? Yo'nalish: 8-bo'lim, "Mexanizm" va "sudoers sintaksisi".

19. **Restricted sudo rule.** `sudo adduser --disabled-password --gecos "" deploy` bilan foydalanuvchi yarating. `sudo visudo -f /etc/sudoers.d/deploy` orqali shunday qoida yozing: `deploy` parolsiz faqat `systemctl restart ssh` va `systemctl is-active ssh` ni root nomidan bajara oladi. Tekshiring: `sudo -l -U deploy`; `sudo -iu deploy` bilan kirib ruxsat etilgan buyruqlar ishlashini, `sudo -n cat /etc/shadow` va `sudo -n systemctl restart cron` rad etilishini ko'rsating (xato matnlari va logdagi yozuv bilan). `-n` bu yerda nima uchun kerak? Qoidaga `systemctl status ssh` yoki `/usr/bin/less /var/log/syslog` qo'shilsa nima uchun xavfli bo'lishini izohlang (ishora: pager ichida `!sh`). Yo'nalish: 8-bo'lim, "sudoers sintaksisi" va tuzoq "faqat bitta buyruq aslida root shell".

20. **Broken sudoers.** `sudo visudo -f /etc/sudoers.d/deploy` da ataylab sintaksis xatosi qiling va saqlang. `visudo` nima dedi va qanday variantlar taklif qildi? Xatoni tuzating, `sudo visudo -c` natijasini yozing. Agar shu xatoni `sudo nano /etc/sudoers.d/deploy` bilan qilganingizda nima bo'lar edi va bu VM'da undan qanday chiqilar edi? Fayl ruxsatlarini (`ls -l /etc/sudoers.d/`) yozing. Yo'nalish: 8-bo'lim, tuzoq "buzilgan `sudoers`".

### F. Skript

21. **First script.** `task_21.sh` yozing: bitta argument (papka) oladi; argument yo'q bo'lsa stderr'ga usage chiqarib 2 bilan, papka mavjud bo'lmasa xabar bilan 1 bilan tugaydi; aks holda papkadagi oddiy fayllar soni, papkalar soni, umumiy hajm (`du -sh`) va eng katta 3 ta faylni chiqaradi. Talablar: `#!/usr/bin/env bash`, `set -euo pipefail`, barcha o'zgaruvchilar tirnoqda, kamida bitta funksiya, xatolar stderr'ga. Sinovlar: argumentsiz, mavjud bo'lmagan papka, `/etc`, nomida bo'shliq bor papka. Har sinovdan keyin `echo $?`. Skriptni host'dagi ish papkasida yozing, `multipass transfer task_21.sh lab:` bilan VM'ga ko'chirib u yerda sinang. Yo'nalish: 9-bo'lim, "Misol".

22. **shellcheck.** `task_21.sh` ni shellcheck bilan tekshiring (host'da, ish papkasi ichida: `shellcheck task_21.sh`; o'rnatish "Laboratoriya" bo'limida). Chiqqan har ogohlantirish kodini (`SC....`) va uni qanday tuzatganingizni yozing. Keyin ataylab uchta xato kiriting: bitta o'zgaruvchidan tirnoqni olib tashlang, `cd "$dir"` ni natijasini tekshirmasdan qo'shing, `for f in $(ls "$dir")` yozing. shellcheck har biri uchun qaysi kodni berdi va nima deb tushuntirdi? Xatolarni qaytarib, toza holatda topshiring. Yo'nalish: 9-bo'lim, "shellcheck".

### Topshirish

Tayyor bo'lgach:
1. `linux/05-shell/README.md` da 22 ta vazifaning har biri `## N. Title` sarlavhasi ostida.
2. Har javobda buyruq, natijaning muhim qismi va o'z so'zingiz bilan izoh bor; buyruq VM'da yoki host'da bajarilgani aniq ko'rinadi.
3. Ish papkasida `task_2.sh` va `task_21.sh` bor, host'da `shellcheck task_2.sh task_21.sh` hech narsa chiqarmaydi (`task_2.sh` da ham shebang bo'lsin, aks holda shellcheck qaysi shell ekanini bilmaydi).
4. `make check` toza o'tadi (host'da).
5. VM'da: `deploy` foydalanuvchisi (`sudo deluser --remove-home deploy`) va `/etc/sudoers.d/deploy` o'chirilgan, `sudo visudo -c` toza, `~/.profile` va `~/.bashrc` da sinov qatorlari yo'q, `/etc/lab.conf` va soxta `~/bin/date` yo'q. Muqobil: `multipass stop lab && multipass restore lab.before-05 && multipass start lab`.
6. Hech bir secret yoki parol README'ga yozilmagan.
7. Menga xabar bering, README va skriptlarni o'qib chiqaman.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Shell o'zgaruvchisi va muhit o'zgaruvchisi farqi nima? Skript ichidagi `export` nima uchun terminalingizga ta'sir qilmaydi?
- `NODE_ENV=production node app.js` yozuvida o'zgaruvchi qayerda yashaydi va `process.env` uni qayerdan oladi?
- Buyruq nomi yozilganda shell uni qanday tartibda qidiradi? 126 va 127 farqi nima?
- `npm run` ichida `eslint` topiladi, terminalda topilmaydi. Nima uchun?
- Login va non-login, interaktiv va interaktiv bo'lmagan shell qaysi fayllarni o'qiydi? cron-chi?
- `PATH` ni qayerda, alias'ni qayerda belgilaysiz va nima uchun?
- Bittalik tirnoq, qo'shtirnoq va tirnoqsiz yozuv farqi nima? Word splitting qachon sodir bo'ladi?
- `"$@"` va `"$*"` farqi nima?
- `> f 2>&1` va `2>&1 > f` nima uchun har xil natija beradi?
- `sudo echo x > /etc/f` nima uchun ishlamaydi?
- Pipeline'ning exit code'i qanday aniqlanadi va `pipefail` nimani o'zgartiradi?
- `sudo` oddiy foydalanuvchi ishga tushirgan holda qanday qilib root huquqiga ega bo'ladi? U muhit va `PATH` bilan nima qiladi?
- `sudoers` qatoridagi to'rt maydon nima? Nima uchun faqat `visudo`?
- `sudoers` da `less` yoki `vim` ga ruxsat berish nima uchun to'liq root berish bilan teng?
- Shebang'ni kim o'qiydi? `./script.sh` va `bash script.sh` farqi nima?
- Xuddi shu buyruq host'dagi zsh'da va VM'dagi bash'da har xil natija bersa, birinchi navbatda nimalarni tekshirasiz?
