# 5-dars: Shell va muhit

Maqsad: bash buyruq satrini qanday qayta ishlashini va jarayon muhiti qanday shakllanishini tushunish: o'zgaruvchilar va `export`, `PATH` bo'yicha qidiruv, `.profile` va `.bashrc` ning yuklanish tartibi, quoting, redirection, exit code'lar, `sudo` va `sudoers`, hamda birinchi bash skript. "Mening terminalimda ishlaydi, cron'da, CI'da yoki systemd'da ishlamaydi" turidagi muammolarning deyarli hammasi shu darsdagi mexanizmlarga borib taqaladi. 3-darsdagi globbing bu yerda kengayish (expansion) tartibining bir qismi sifatida qayta ko'riladi; 9-dars (jarayonlar), 10-dars (foydalanuvchilar) va 11-dars (systemd) shu darsdagi muhit va `sudo` tushunchalariga tayanadi.

Taxminiy vaqt: 3–4 kun (siz uchun). Node'dagi `process.env` va npm skriptlar tajribangiz yordam beradi, lekin quyidagilar yangi va diqqat talab qiladi: shell va muhit o'zgaruvchisi farqi, login va non-login shell, word splitting va tirnoqlar, `2>&1` tartibi, pipeline exit code'i, `sudo` bilan redirection, `sudoers` sintaksisi.

## Laboratoriya

- **`lab` VM**: barcha vazifalar, bash'da. `multipass start lab && multipass shell lab`. Boshlashdan oldin snapshot yangilang: E guruhida `sudoers` va foydalanuvchi o'zgartiriladi.

```
multipass stop lab && multipass snapshot lab --name before-05 && multipass start lab
```

- **Ish mashinasi**: faqat 22-vazifadagi `shellcheck` (Docker image orqali, hech narsa o'rnatilmaydi). Ish mashinangizdagi shell `zsh`: uning startup fayllari (`~/.zshrc`, `~/.zprofile`) va ba'zi qoidalari boshqacha, shuning uchun tajribalar VM'dagi bashda.
- Skriptlar VM'da yoziladi va `multipass transfer` bilan ish papkasiga olinadi (yoki ish papkasida yozib VM'ga ko'chiriladi).

Tozalash: VM'da `deploy` foydalanuvchisi va `/etc/sudoers.d/deploy` o'chiriladi (yoki `multipass restore lab.before-05`), `~/.profile` va `~/.bashrc` dagi sinov qatorlari olib tashlanadi.

---

## 1. Shell buyruqni qanday bajaradi

Enter bosilgandan keyin bash qatorni quyidagi tartibda qayta ishlaydi:

| Qadam | Nima bo'ladi | Misol |
|-------|--------------|-------|
| 1. Tokenlarga ajratish | tirnoqlar va operatorlar (`|`, `>`, `&&`, `;`) aniqlanadi | |
| 2. Brace expansion | `{a,b}`, `{1..3}` | `f{1,2}` bu `f1 f2` |
| 3. Tilde, o'zgaruvchi, buyruq, arifmetika | `~`, `$VAR`, `$(cmd)`, `$((1+2))` | |
| 4. Word splitting | tirnoqsiz kengayish natijasi bo'shliq, tab, yangi qator bo'yicha bo'linadi | |
| 5. Pathname expansion | `*`, `?`, `[...]` | |
| 6. Redirection | fayllar ochiladi, `>` faylni shu paytda bo'shatadi | |
| 7. Buyruqni topish | alias, funksiya, builtin, keyin `PATH` | |
| 8. Bajarish | tashqi buyruq uchun yangi jarayon (`fork` + `exec`), shell kutadi | |
| 9. Exit code | `$?` ga yoziladi | |

Bu tartib ko'p tuzoqni tushuntiradi: o'zgaruvchi ichidagi `*` 5-qadamda ochiladi (chunki 3-qadamdan keyin keladi), redirection buyruqdan oldin bajariladi, tirnoq 4 va 5-qadamlarni o'chiradi.

## 2. O'zgaruvchilar va muhit

Ikki xil o'zgaruvchi bor:

- **Shell o'zgaruvchisi**: faqat joriy shell ichida. `NAME=value` (tenglik atrofida bo'shliq bo'lmaydi: `NAME = value` da shell `NAME` nomli buyruqni qidiradi).
- **Muhit (environment) o'zgaruvchisi**: `export` qilingan o'zgaruvchi. Bola jarayonlarga **nusxa** bo'lib o'tadi.

```
NAME=dev                 # shell variable
bash -c 'echo "[$NAME]"' # [] : the child does not see it
export NAME              # now it is in the environment
bash -c 'echo "[$NAME]"' # [dev]
```

- Muhit bir tomonlama meros: bola ota muhitining nusxasini oladi, bola o'zgartirgani otaga qaytmaydi. Skript ichidagi `export` va `cd` skript tugagach yo'qoladi. Joriy shell'ni o'zgartirish uchun fayl `source fayl` (yoki `. fayl`) bilan shu shell ichida o'qiladi. `nvm` va Python `venv` ning `activate` fayli shuning uchun `source` qilinadi.
- Bitta buyruq uchun: `LANG=C ls`, `NODE_ENV=production node app.js`. O'zgaruvchi faqat shu jarayonga beriladi.
- Ko'rish: `env` yoki `printenv` (muhit), `set` (hammasi, funksiyalar bilan), `echo "$NAME"`, `unset NAME`.

| O'zgaruvchi | Ma'nosi |
|-------------|---------|
| `PATH` | buyruqlar qidiriladigan papkalar |
| `HOME`, `USER`, `SHELL`, `PWD` | uy papkasi, foydalanuvchi, login shell, joriy papka |
| `LANG`, `LC_ALL` | locale: til, saralash tartibi, sana formati |
| `EDITOR`, `VISUAL` | standart muharrir |
| `PS1` | prompt ko'rinishi |
| `$?`, `$$`, `$!` | oxirgi exit code, shell PID'i, oxirgi fon jarayonining PID'i |

**Tuzoq: muhit o'zgaruvchilari sir emas.** Jarayon muhiti `/proc/<PID>/environ` da o'sha foydalanuvchi va root uchun ochiq, bola jarayonlarga o'tadi va crash dump'larga tushadi. Secret'ni muhitda saqlash qulay, lekin xavfsiz saqlash joyi emas.

## 3. PATH

Tashqi buyruq nomida `/` bo'lmasa, shell uni `PATH` dagi papkalardan chapdan o'ngga qidiradi va birinchi topilganini ishga tushiradi.

```
echo "$PATH"                    # /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:...
type -a python3                 # every match, in lookup order
export PATH="$HOME/bin:$PATH"   # prepend: your directory wins
```

- Oldinga qo'shilgan papka tizim buyruqlarini soya qiladi. Bu qulaylik (o'z versiyangiz) ham, xavf (yozish mumkin bo'lgan papka `PATH` boshida bo'lsa, kimdir soxta `ls` qo'yishi mumkin) ham.
- Joriy papka `PATH` da yo'q va bo'lmasligi kerak. Shuning uchun skript `./script.sh` deb ishga tushiriladi.
- bash topilgan yo'llarni keshlaydi (`hash`). Buyruq boshqa joyga ko'chsa `hash -r` keshni tozalaydi.
- `command not found` (exit code 127): `PATH` da yo'q. `Permission denied` (126): topildi, lekin bajarish huquqi yo'q.

**Tuzoq: `sudo`, cron va systemd'da `PATH` boshqa.** `sudo` standart holatda `PATH` ni `secure_path` ga almashtiradi, cron juda qisqa `PATH` beradi, systemd unit o'z standartiga ega. `~/.local/bin` yoki `nvm` orqali o'rnatilgan dastur u yerda topilmaydi. Skript va unit'larda absolut yo'l yozing yoki `PATH` ni aniq belgilang.

## 4. Startup fayllar

Bash qaysi faylni o'qishi ikki xususiyatga bog'liq: **login** shell'mi (sessiyaning birinchi shell'i: ssh, konsol, `bash -l`) va **interaktiv**mi (terminalga ulangan, prompt bor).

| Shell turi | Misol | O'qiladigan fayllar |
|------------|-------|---------------------|
| login | `ssh host`, `multipass shell`, `su - user`, `bash -l` | `/etc/profile` (u `/etc/profile.d/*.sh` ni yuklaydi), keyin birinchi topilgani: `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| interaktiv, login emas | terminal ichida `bash`, grafik terminal oynasi | `/etc/bash.bashrc` (Debian oilasi), `~/.bashrc` |
| interaktiv emas | skript, `bash -c '...'`, cron, CI | hech biri (faqat `$BASH_ENV` ko'rsatgan fayl, agar bo'lsa) |

- Ubuntu'da `~/.profile` ichida `~/.bashrc` ni yuklaydigan qator bor, shuning uchun login shell ham `.bashrc` ni o'qiydi. `~/.bash_profile` yaratsangiz `~/.profile` o'qilmay qoladi (birinchi topilgani qoidasi).
- Ubuntu'ning `~/.bashrc` boshida `case $- in *i*) ;; *) return;; esac` turadi: interaktiv bo'lmasa darhol qaytadi. Undan pastga yozilgan `export` interaktiv bo'lmagan shell'ga ta'sir qilmaydi.
- RHEL oilasida: `~/.bash_profile` va `/etc/bashrc`.

Nima qayerga yoziladi:

| Narsa | Qayerga | Sabab |
|-------|---------|-------|
| muhit o'zgaruvchilari, `PATH` | `~/.profile` | bir marta, login'da o'rnatiladi va barcha bolalarga meros bo'ladi |
| alias, funksiya, prompt, completion | `~/.bashrc` | meros bo'lmaydi, har interaktiv shell'da qayta kerak |
| barcha foydalanuvchilar uchun muhit | `/etc/profile.d/nom.sh` | paketlar ham shu yerga qo'yadi |

Fayl o'zgartirilgach yangi sessiya oching yoki `source ~/.bashrc`.

**Tuzoq: cron va systemd bu fayllarning hech birini o'qimaydi.** `.bashrc` dagi `export DATABASE_URL=...` terminalda bor, cron job'da yo'q. Servis muhiti unit faylida (`Environment=`, `EnvironmentFile=`) beriladi, 11-darsda.

## 5. Quoting

| Yozuv | Shell nima qiladi |
|-------|-------------------|
| `'...'` | hech narsa: ichidagi har belgi harfma-harf |
| `"..."` | `$VAR`, `$(cmd)`, `\` ishlaydi; word splitting va globbing o'chadi |
| tirnoqsiz | hamma kengayishlar, keyin word splitting va globbing |
| `\x` | bitta belgini ekranlaydi |

```
file="my report.txt"
touch $file        # two files: "my" and "report.txt"
touch "$file"      # one file
echo '$HOME'       # $HOME
echo "$HOME"       # /home/ubuntu
```

- Qoida: o'zgaruvchi va `$(...)` har doim qo'shtirnoqda: `"$var"`, `"$(cmd)"`. Istisno juda kam va ataylab qilinadi.
- Buyruq natijasini olish: `$(cmd)`. Eski shakli teskari tirnoq, ichma-ich yozish qiyin, yangi kodda ishlatilmaydi.
- Barcha argumentlarni uzatish: `"$@"` (har argument alohida so'z bo'lib qoladi). `$*` va tirnoqsiz `$@` bo'shliqli argumentlarni buzadi.
- ssh va `docker exec` da ikki qavat shell bor: `ssh host "echo $HOME"` da `$HOME` sizning mashinangizda ochiladi, `ssh host 'echo $HOME'` da serverda.

## 6. Redirection va pipe

Har jarayonda uchta standart oqim bor: 0 stdin, 1 stdout, 2 stderr. Bular file descriptor, standart holatda terminalga ulangan.

| Yozuv | Ma'nosi |
|-------|---------|
| `cmd > f` | stdout faylga, fayl avval bo'shatiladi |
| `cmd >> f` | stdout fayl oxiriga qo'shiladi |
| `cmd < f` | stdin fayldan |
| `cmd 2> f` | stderr faylga |
| `cmd > f 2>&1` | ikkalasi bitta faylga (`&> f` bash qisqartmasi) |
| `cmd > /dev/null 2>&1` | hamma chiqishni tashlash |
| `a | b` | `a` ning stdout'i `b` ning stdin'iga; stderr terminalda qoladi |
| `a 2>&1 | b` | stderr ham pipe'ga |
| `cmd | tee f` | chiqish ham ekranga, ham faylga |
| `cmd <<EOF ... EOF` | here-document: keyingi qatorlar stdin bo'ladi |
| `cmd <<< "matn"` | here-string |

- **Tartib muhim**: redirection'lar chapdan o'ngga qo'llanadi. `> f 2>&1`: avval 1 faylga, keyin 2 "1 hozir qayerga qarasa" o'sha yerga, ya'ni faylga. `2>&1 > f`: avval 2 terminalga (1 hali terminalda), keyin 1 faylga. Natijada stderr ekranda qoladi.
- Here-document'da `<<EOF` ichida o'zgaruvchilar ochiladi, `<<'EOF'` da ochilmaydi. Konfiguratsiya fayli generatsiya qilishda farq muhim.
- Xato xabarlari stderr'ga yoziladi: `echo "error: ..." >&2`. Shunda `script | boshqa` da xato pipe'ga aralashmaydi.

**Tuzoq: `sudo cmd > /etc/fayl`.** Redirection'ni `sudo` emas, sizning shell'ingiz bajaradi, u esa root emas: `Permission denied`. Yechim: `cmd | sudo tee /etc/fayl > /dev/null` (qo'shish uchun `tee -a`).

**Tuzoq: bir faylni o'qib o'ziga yozish.** `sort f > f` faylni bo'shatadi: `>` buyruq ishga tushishidan oldin faylni kesadi. Vaqtinchalik faylga yozib `mv` qiling, yoki `sort -o f f`.

## 7. Exit code'lar

Har buyruq 0–255 oralig'ida son qaytaradi: 0 muvaffaqiyat, boshqasi xato. `$?` oxirgi buyruqnikini saqlaydi (keyingi buyruq uni ustidan yozadi).

| Kod | Ma'nosi |
|-----|---------|
| 0 | muvaffaqiyat |
| 1 | umumiy xato (`grep` da: topilmadi) |
| 2 | noto'g'ri ishlatish (ko'p utilitalarda) |
| 126 | topildi, lekin bajarib bo'lmadi |
| 127 | buyruq topilmadi |
| 128+N | N-signal bilan tugagan: 130 (`Ctrl+C`, SIGINT), 137 (SIGKILL), 143 (SIGTERM) |

- `a && b`: `b` faqat `a` muvaffaqiyatli bo'lsa. `a || b`: faqat `a` xato bersa. `a ; b`: har doim.
- `if cmd; then` exit code'ni tekshiradi, `[ ... ]` va `[[ ... ]]` ham oddiy buyruqlar.
- Pipeline'ning exit code'i **oxirgi** buyruqniki: `false | true` 0 qaytaradi. `set -o pipefail` bilan birinchi xato qaytgan buyruqniki. Har bo'g'inniki: `"${PIPESTATUS[@]}"`.
- CI va systemd muvaffaqiyatni faqat exit code'ga qarab baholaydi. Xatoni chop etib `exit 0` qilgan skript "yashil" bo'ladi.

## 8. sudo va sudoers

`sudo` buyruqni boshqa foydalanuvchi (standart: root) nomidan ishga tushiradi. Oldin siyosatni (`sudoers`) tekshiradi, **sizning** parolingizni so'raydi (root'nikini emas) va har chaqiruvni logga yozadi.

| Buyruq | Nima qiladi |
|--------|-------------|
| `sudo cmd` | root nomidan bitta buyruq |
| `sudo -u postgres cmd` | boshqa foydalanuvchi nomidan |
| `sudo -i` | root'ning login shell'i (uning muhiti va uy papkasi) |
| `sudo -s` | root shell, sizning muhitingizning bir qismi bilan |
| `sudo -l` | sizga nima ruxsat etilgan |
| `sudo -k` | keshlangan autentifikatsiyani unutish (standart kesh 15 daqiqa) |
| `sudo -E cmd` | muhitni saqlab (siyosat ruxsat bersa) |

`sudo` muhitni tozalaydi (`env_reset`) va `PATH` ni `secure_path` ga almashtiradi. `sudo env` va `env` ni solishtirsangiz farq ko'rinadi.

### sudoers sintaksisi

```
# who   where = (as_user:as_group)  what
root    ALL=(ALL:ALL) ALL
%sudo   ALL=(ALL:ALL) ALL                 # % means a group
deploy  ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

- Maydonlar: kim (foydalanuvchi yoki `%guruh`), qaysi hostda, kim nomidan, qaysi buyruqlar. Buyruqlar absolut yo'l bilan, argumentlari bilan birga yozilishi mumkin.
- `NOPASSWD:` parol so'ramaydi. Avtomatlashtirish uchun kerak, lekin faqat aniq buyruqlar ro'yxati bilan.
- Qo'shimcha qoidalar `/etc/sudoers.d/` ga alohida fayl bo'lib qo'yiladi (nomida `.` yoki `~` bo'lmasin, bunday fayllar o'tkazib yuboriladi; ruxsati `0440`). Multipass VM'dagi `ubuntu` foydalanuvchisi huquqi shu yerda: `/etc/sudoers.d/90-cloud-init-users`.
- Tahrirlash faqat `visudo` bilan: `sudo visudo` yoki `sudo visudo -f /etc/sudoers.d/deploy`. U faylni qulflaydi va saqlashdan oldin sintaksisni tekshiradi. Tekshirish: `sudo visudo -c`.

**Tuzoq: buzilgan `sudoers`.** Sintaksis xatosi bo'lgan `sudoers` bilan `sudo` umuman ishlamay qoladi, root paroli bo'lmagan serverda (cloud'da odatiy holat) bu tizimdan qulflanish degani. Shuning uchun faqat `visudo`.

**Tuzoq: "faqat bitta buyruq" aslida root shell.** `vim`, `less`, `find`, `tar`, `awk` kabi dasturlar ichidan shell ochish yoki ixtiyoriy buyruq bajarish mumkin. Ularni `sudoers` da ruxsat etish to'liq root berish bilan teng. Ruxsat etilgan buyruq aniq, argumentlari bilan va foydalanuvchi o'zgartira olmaydigan faylga ko'rsatishi kerak.

## 9. Birinchi bash skript

```
#!/usr/bin/env bash
set -euo pipefail

dir="${1:-}"
if [[ -z "$dir" || ! -d "$dir" ]]; then
  echo "usage: $0 <directory>" >&2
  exit 2
fi
echo "files: $(find "$dir" -type f | wc -l)"
```

- **Shebang** (`#!`) kernel'ga skriptni qaysi interpretator bilan ishga tushirishni aytadi. `#!/usr/bin/env bash` bash'ni `PATH` dan topadi. Shebang'siz yoki `#!/bin/sh` bilan bash sintaksisi ishlamasligi mumkin (Ubuntu'da `sh` bu `dash`).
- Ishga tushirish: `chmod +x script.sh`, keyin `./script.sh`. Yoki `bash script.sh` (bajarish huquqi shart emas).
- `set -e` xato bergan buyruqda to'xtaydi, `set -u` aniqlanmagan o'zgaruvchini xato deb biladi, `set -o pipefail` pipeline'dagi xatoni yashirmaydi.
- Argumentlar: `$1`, `$2`, soni `$#`, hammasi `"$@"`, skript nomi `$0`. Standart qiymat: `"${1:-default}"`.
- `[[ ... ]]` bash'ning test konstruksiyasi: `-f` fayl, `-d` papka, `-z` bo'sh satr, `-n` bo'sh emas, `==` satr tengligi, `-eq`, `-lt`, `-gt` sonlar uchun.
- Sikl: `for f in *.log; do ...; done`. Funksiya: `name() { ...; }`.
- **shellcheck** skriptdagi quoting va mantiq xatolarini topadigan statik analizator. Har skript undan toza o'tishi kerak.

```
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable task_21.sh
```

## Tuzoqlar

- Tirnoqsiz o'zgaruvchi: `rm $file`, `cd $dir`, `[ $x = y ]`. Bo'shliqli yoki bo'sh qiymatda buyruq boshqa narsani bajaradi. Har doim `"$var"`.
- `2>&1 > file` tartibi: stderr faylga tushmaydi. To'g'risi `> file 2>&1`.
- `sudo echo ... > /etc/...` va `sudo cat a > /root/b`: redirection root bilan bajarilmaydi.
- Pipeline exit code'i: `curl ... | tar xz` da `curl` xato bersa ham skript davom etadi. `set -o pipefail`.
- `.bashrc` ga yozilgan muhit o'zgaruvchisiga cron, systemd yoki CI'da tayanish.
- `PATH` ga tayangan skript `sudo` yoki cron ostida "command not found" beradi.
- `sudoers` ni `visudo` siz tahrirlash, yoki `NOPASSWD: ALL` ni servis foydalanuvchisiga berish.
- `sudoers` da muharrir, pager yoki interpretatorni ruxsat etish: bu root shell.
- `set -e` siz skript: o'rtadagi `cd` yoki `cp` xato beradi, skript davom etib noto'g'ri joyda ishlaydi.
- Secret'ni buyruq argumentida yoki `export` bilan berish: tarixda, `ps` da va `/proc/<PID>/environ` da ko'rinadi.

## Manbalar

- https://www.gnu.org/software/bash/manual/bash.html#Shell-Expansions – kengayishlar va ularning tartibi
- https://www.gnu.org/software/bash/manual/bash.html#Bash-Startup-Files – startup fayllar
- https://www.gnu.org/software/bash/manual/bash.html#Redirections – redirection
- https://www.gnu.org/software/bash/manual/bash.html#Exit-Status – exit status
- https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin – `set -e`, `-u`, `-o pipefail`
- https://www.sudo.ws/docs/man/sudoers.man/ – `sudoers(5)`
- https://www.sudo.ws/docs/man/visudo.man/ – `visudo(8)`
- https://www.shellcheck.net/ – shellcheck, https://www.shellcheck.net/wiki/ da har xato kodi izohi
- https://mywiki.wooledge.org/Quotes – quoting bo'yicha batafsil
- https://mywiki.wooledge.org/BashPitfalls – bash'dagi keng tarqalgan xatolar
- https://google.github.io/styleguide/shellguide.html – Google Shell Style Guide
- Shotts, "The Linux Command Line" (https://linuxcommand.org/tlcl.php) – 6, 7, 11 va 24–27 boblar

---

## Vazifalar

Ish papkasi: `linux/05-shell/` (`make new m=linux n=05 name=shell` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida bajarilgan buyruqlar, natijaning muhim qismi va o'z so'zingiz bilan izoh. Skriptlar (`task_2.sh`, `task_21.sh`) shu papkaga saqlanadi. Vazifalar `lab` VM'da, bash'da.

### A. O'zgaruvchilar va PATH

1. **Shell versus environment.** `STAGE=dev` qiling. `echo "$STAGE"`, `bash -c 'echo "[$STAGE]"'` va `env | grep STAGE` natijalarini yozing. `export STAGE` dan keyin takrorlang. Bola shell ichida `STAGE=prod` qilib chiqing va ota shell'dagi qiymatni tekshiring. `STAGE = dev` (bo'shliq bilan) xatosini yozing va nima uchun bunday xato chiqishini izohlang.

2. **Run versus source.** `task_2.sh` yozing: ichida `cd /tmp`, `export FROM_SCRIPT=1` va `pwd`. Uni avval `bash task_2.sh`, keyin `source task_2.sh` bilan ishga tushiring. Har safar keyin `pwd` va `echo "$FROM_SCRIPT"` ni tekshiring. Farqni jarayonlar nuqtai nazaridan izohlang. `nvm` yoki Python `venv` nima uchun `source` talab qiladi?

3. **One-shot variable.** `date` va `TZ=Asia/Tokyo date` ni solishtiring, keyin `echo "[$TZ]"` ni bajaring. `FOO=1 bash -c 'echo "[$FOO]"'; echo "[$FOO]"` natijasini yozing: `FOO` `export` qilinmagan bo'lsa ham bola uni nima uchun ko'rdi, ota shell'da esa nima uchun yo'q? Bu yozuv `export TZ=Asia/Tokyo; date` dan nimasi bilan farq qiladi va Node'dagi `NODE_ENV=production node app.js` bilan qanday bog'liq?

4. **PATH lookup.** `~/bin/hello` skriptini yarating (bitta `echo`), `chmod +x` qiling. `hello` ishlaydimi? `PATH` ga qo'shing va qayta sinang. Keyin `~/bin/date` nomli, `echo fake date` chiqaradigan skript yarating: `date`, `type -a date`, `hash` natijalarini yozing. `~/bin` ni `PATH` ning boshiga va oxiriga qo'yib farqni ko'ring. Oxirida soxta `date` ni o'chiring. Bu xatti-harakatning xavfsizlik oqibati nima?

5. **126 and 127.** Bajarish huquqi yo'q skriptni `./x.sh` deb, mavjud bo'lmagan buyruqni, va papkani buyruq sifatida (`/tmp`) ishga tushiring. Har birida xato matni va `$?` ni yozing. Keyin `PATH= ls` va `PATH= cd /tmp && pwd` ni bajaring: biri nima uchun ishlamadi, ikkinchisi ishladi?

### B. Startup fayllar

6. **Load order trace.** `~/.profile` va `~/.bashrc` ning eng boshiga (`.bashrc` da interaktivlik tekshiruvidan oldin) `echo "loading: <fayl nomi>" >&2` qatorini qo'shing. Keyin to'rt usulda shell oching va qaysi fayllar yuklanganini jadvalga yozing: `multipass shell lab`, uning ichida `bash`, `bash -l`, va `bash -c 'echo hi'`. Beshinchi: ish mashinasidan `multipass exec lab -- bash -c 'echo hi'`. Natijani 4-bo'limdagi jadval bilan solishtiring. Oxirida qo'shilgan qatorlarni olib tashlang.

7. **Alias scope.** `~/.bashrc` ga `alias k='echo kubectl'` va `export FROM_RC=1` qo'shing (interaktivlik tekshiruvidan pastga). Yangi sessiyada `k` va `echo "$FROM_RC"` ishlaydimi? `bash -c 'k; echo "[$FROM_RC]"'` da-chi? Ish mashinasidan `multipass exec lab -- bash -c 'echo "[$FROM_RC]"'` da-chi? Har natijani izohlang va o'zgaruvchi to'g'ri joyga ko'chirilgandan keyin qaysi holat o'zgarishini ko'rsating.

8. **Cron-like environment.** `env -i bash --noprofile --norc -c 'env; echo "PATH=$PATH"'` ni bajaring. Qaysi o'zgaruvchilar bor? Shu muhitda 4-vazifadagi `hello` topiladimi? Bundan kelib chiqib, cron yoki systemd'dan ishga tushadigan skript uchun uchta qoida yozing.

### C. Quoting

9. **Three quote types.** `name="Ali Valiyev"` uchun `echo '$name'`, `echo "$name"`, `echo $name`, `echo "\$name"` natijalarini yozing. `f="my file.txt"` uchun `touch $f; ls -l` va `touch "$f"; ls -l` ni solishtiring. `pattern="*"` uchun `echo $pattern` va `echo "$pattern"` farqini 1-bo'limdagi qadamlar bilan izohlang.

10. **Command substitution.** `backup-YYYY-MM-DD.tar` ko'rinishidagi nomni `$(date ...)` bilan hosil qiling. `echo "Kernel: $(uname -r), files in /etc: $(ls /etc | wc -l)"` ni yozing. `files=$(ls /etc)` dan keyin `echo $files | wc -l` va `echo "$files" | wc -l` nima uchun farq qiladi?

11. **Word splitting bug.** Papkada `a.txt`, `b c.txt`, `d.txt` yarating. `for f in $(ls); do echo "[$f]"; done` va `for f in *; do echo "[$f]"; done` natijalarini solishtiring. Birinchisi nima uchun buziladi? `args() { echo "$#"; }` funksiyasini yozib `args $f`, `args "$f"`, `args "$@"` kabi chaqiruvlar bilan argumentlar sonini ko'rsating.

### D. Redirection va exit code

12. **stdout and stderr.** `ls /etc/hostname /nope` ni: (a) stdout va stderr alohida fayllarga, (b) ikkalasi bitta faylga, (c) faqat xatoni ko'rsatib, (d) faqat natijani ko'rsatib bajaring. Keyin `ls /etc/hostname /nope > out.txt 2>&1` va `ls /etc/hostname /nope 2>&1 > out.txt` ni solishtiring: ekranda nima qoldi, faylda nima? `ls /etc/hostname /nope | wc -l` nima uchun 1 chiqaradi?

13. **sudo redirect trap.** `sudo echo "test" > /etc/lab.conf` ni bajaring va xatoni yozing. Kim faylni ochmoqchi bo'ldi? Ikki to'g'ri usulni yozing (`tee` bilan va `sudo sh -c` bilan), har birini sinang. Fayl oxiriga qator qo'shish variantini ham ko'rsating. Oxirida faylni o'chiring.

14. **Truncation trap.** 5 qatorli `n.txt` yarating (`printf` yoki `seq`). `sort -r n.txt > n.txt` dan keyin faylni ko'ring. Nima uchun bo'sh? Ikki to'g'ri usulni yozing. `set -o noclobber` yoqilganda `echo x > n.txt` nima qiladi va uni qanday chetlab o'tiladi?

15. **Here-document.** `cat > app.conf <<EOF` bilan `user=$USER`, `home=$HOME`, `date=$(date +%F)` qatorli fayl yarating. Xuddi shuni `<<'EOF'` bilan `app.tpl` ga yozing va ikki faylni solishtiring. Qaysi birini konfiguratsiya, qaysi birini shablon yoki skript generatsiyasi uchun ishlatasiz? `grep ubuntu <<< "$(id)"` nima qiladi?

16. **Exit codes.** Quyidagilar uchun `$?` ni yozing va izohlang: `true`, `false`, `grep -q root /etc/passwd`, `grep -q nope /etc/passwd`, `grep x /nope`, `ls /nope`, `sleep 30` ni `Ctrl+C` bilan to'xtatgandan keyin, boshqa terminaldan `kill -9` qilingandan keyin. `mkdir d && cd d || echo failed` zanjiri qanday ishlaydi? `false; echo $?; echo $?` nima uchun `1` va `0` chiqaradi?

17. **pipefail.** `false | true; echo $?` va `cat /nope | wc -l; echo "${PIPESTATUS[@]}"` natijalarini yozing. `set -o pipefail` dan keyin takrorlang. `curl -fsS https://example.invalid | tar xz` kabi qatorli deploy skriptida `pipefail` siz nima bo'lishini izohlang.

### E. sudo

18. **sudo inspection.** `sudo -l` natijasini yozing. `sudo cat /etc/sudoers` va `sudo cat /etc/sudoers.d/90-cloud-init-users` dan: `Defaults` qatorlari nima qiladi, `%sudo` qatori nimani anglatadi, `ubuntu` foydalanuvchisi huquqi qaysi qatorda? `env | grep -c .` va `sudo env | grep -c .` ni, `echo $PATH` va `sudo sh -c 'echo $PATH'` ni solishtiring. `sudo` chaqiruvlaringiz qayerda loglangan (`sudo grep sudo /var/log/auth.log | tail -5` yoki `journalctl -t sudo`)?

19. **Restricted sudo rule.** `sudo adduser --disabled-password --gecos "" deploy` bilan foydalanuvchi yarating. `sudo visudo -f /etc/sudoers.d/deploy` orqali shunday qoida yozing: `deploy` parolsiz faqat `systemctl restart ssh` va `systemctl is-active ssh` ni root nomidan bajara oladi. Tekshiring: `sudo -l -U deploy`; `sudo -iu deploy` bilan kirib ruxsat etilgan buyruqlar ishlashini, `sudo -n cat /etc/shadow` va `sudo -n systemctl restart cron` rad etilishini ko'rsating (xato matnlari va logdagi yozuv bilan). `-n` bu yerda nima uchun kerak? Qoidaga `systemctl status ssh` yoki `/usr/bin/less /var/log/syslog` qo'shilsa nima uchun xavfli bo'lishini izohlang (ishora: pager ichida `!sh`).

20. **Broken sudoers.** `sudo visudo -f /etc/sudoers.d/deploy` da ataylab sintaksis xatosi qiling va saqlang. `visudo` nima dedi va qanday variantlar taklif qildi? Xatoni tuzating, `sudo visudo -c` natijasini yozing. Agar shu xatoni `sudo nano /etc/sudoers.d/deploy` bilan qilganingizda nima bo'lar edi va bu VM'da undan qanday chiqilar edi? Fayl ruxsatlarini (`ls -l /etc/sudoers.d/`) yozing.

### F. Skript

21. **First script.** `task_21.sh` yozing: bitta argument (papka) oladi; argument yo'q bo'lsa stderr'ga usage chiqarib 2 bilan, papka mavjud bo'lmasa xabar bilan 1 bilan tugaydi; aks holda papkadagi oddiy fayllar soni, papkalar soni, umumiy hajm (`du -sh`) va eng katta 3 ta faylni chiqaradi. Talablar: `#!/usr/bin/env bash`, `set -euo pipefail`, barcha o'zgaruvchilar tirnoqda, kamida bitta funksiya, xatolar stderr'ga. Sinovlar: argumentsiz, mavjud bo'lmagan papka, `/etc`, nomida bo'shliq bor papka. Har sinovdan keyin `echo $?`.

22. **shellcheck.** `task_21.sh` ni shellcheck bilan tekshiring (darsdagi Docker buyrug'i yoki VM'da `sudo apt install -y shellcheck`). Chiqqan har ogohlantirish kodini (`SC....`) va uni qanday tuzatganingizni yozing. Keyin ataylab uchta xato kiriting: bitta o'zgaruvchidan tirnoqni olib tashlang, `cd "$dir"` ni natijasini tekshirmasdan qo'shing, `for f in $(ls "$dir")` yozing. shellcheck har biri uchun qaysi kodni berdi va nima deb tushuntirdi? Xatolarni qaytarib, toza holatda topshiring.

### Topshirish

Tayyor bo'lgach:
1. `linux/05-shell/README.md` da 22 ta vazifa `## N. Title` sarlavhalari ostida.
2. Ish papkasida `task_2.sh` va `task_21.sh` bor, `shellcheck` hech narsa chiqarmaydi.
3. `make check` toza o'tadi.
4. VM'da: `deploy` foydalanuvchisi (`sudo deluser --remove-home deploy`) va `/etc/sudoers.d/deploy` o'chirilgan, `sudo visudo -c` toza, `~/.profile` va `~/.bashrc` da sinov qatorlari yo'q, `/etc/lab.conf` yo'q.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Shell o'zgaruvchisi va muhit o'zgaruvchisi farqi nima? Skript ichidagi `export` nima uchun terminalingizga ta'sir qilmaydi?
- Buyruq nomi yozilganda shell uni qanday tartibda qidiradi? 126 va 127 farqi nima?
- Login va non-login, interaktiv va interaktiv bo'lmagan shell qaysi fayllarni o'qiydi? cron-chi?
- `PATH` ni qayerda, alias'ni qayerda belgilaysiz va nima uchun?
- Bittalik tirnoq, qo'shtirnoq va tirnoqsiz yozuv farqi nima? Word splitting qachon sodir bo'ladi?
- `> f 2>&1` va `2>&1 > f` nima uchun har xil natija beradi?
- `sudo echo x > /etc/f` nima uchun ishlamaydi?
- Pipeline'ning exit code'i qanday aniqlanadi va `pipefail` nimani o'zgartiradi?
- `sudoers` qatoridagi to'rt maydon nima? Nima uchun faqat `visudo`?
- `sudoers` da `less` yoki `vim` ga ruxsat berish nima uchun to'liq root berish bilan teng?
