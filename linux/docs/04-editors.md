# 4-dars: Terminal muharrirlari (Nano, Vim)

Maqsad: grafik muharrir yo'q joyda (ssh sessiyasi, konteyner, recovery rejimi) konfiguratsiya faylini ishonch bilan tahrirlay olish. Nano oddiy holatlar uchun, Vim esa har qanday serverda `vi` nomi bilan mavjud bo'lgani uchun: `visudo`, `crontab -e`, `git commit`, `systemctl edit`, `kubectl edit` sizdan so'ramasdan muharrir ochadi. Dars Vim'ni IDE qilishni emas, uning grammatikasini (rejimlar, operator + harakat), qidirish va almashtirishni, minimal `.vimrc` ni va "qotib qoldim" holatlaridan chiqishni o'rgatadi. Keyingi darslarda (`sudoers`, systemd unit, YAML manifestlar) barcha tahrirlar shu ko'nikmaga tayanadi.

Taxminiy vaqt: 4 kun (siz uchun). Birinchi kun 1–3 bo'limlar, A guruh va 4–5 vazifalar (`vimtutor` ning o'zi 30–40 daqiqa); ikkinchi kun 4–5 bo'limlar va 6–8 vazifalar; uchinchi kun 6–8 bo'limlar va C, D, E guruhlari; to'rtinchi kun 9-bo'lim, "Birga bajaramiz", F va G guruhlari. VS Code odatlari (sichqoncha, strelkalar, `Cmd+S`) bu yerda xalaqit beradi, shuning uchun vaqtning ko'pi o'qishga emas, qo'l mashqiga ketadi. E'tiborni quyidagilarga qarating: Normal rejim asosiy rejim ekani, `operator + son + harakat` grammatikasi, `.` bilan takrorlash, `:%s` va `:g`, visual block, swap fayl va readonly xatolari, `sudoedit`.

Qanday o'qish kerak: muharrirda "buyruq va uning natijasi" bu bosilgan klavishlar va ekranning eng pastki qatorida (status qatori) paydo bo'lgan yozuv. Darsda klavishlar `shu shaklda`, pastki qatordagi xabar esa alohida blokda berilgan. Har misolni VM ichida o'zingiz bosib, pastki qatorni darsdagi bilan solishtiring. Sizda farq qiladigan qiymatlar (`<PID>`, `<sana>`, bayt soni `<N>`) `<...>` bilan belgilangan.

## Laboratoriya

Hamma mashq `lab` VM ichida (`SETUP.md`, Multipass, Ubuntu 24.04), `multipass shell lab` orqali. Bu real holatning aynan o'zi: serverga ssh bilan kirib, grafik muhitsiz konfiguratsiya tahrirlash.

| Joy | Bu darsda nima qilinadi |
|-----|-------------------------|
| Host (Zorin yoki macOS) | `make new`, `git`, `multipass`, README yozish, 18-vazifadagi `docker run` |
| `lab` VM | 1–17, 19, 20-vazifalar, hammasi `~/edit` papkasida |
| Konteyner (`ubuntu:24.04`) | 18-vazifa: muharrir umuman yo'q muhit |

- **Tayyorlash** (VM ichida): `mkdir -p ~/edit && cd ~/edit`. Tizim fayllarining o'zi emas, nusxasi tahrirlanadi (`cp /etc/services ~/edit/`). Yagona istisno 16-vazifa (`/etc/hosts`, `sudoedit` orqali): undan oldin host'da `multipass list --snapshots` bilan `clean` snapshot borligini tekshiring (2-dars; snapshot to'xtatilgan VM'dan olinadi).
- **Muharrirlar**: VM'da `nano` va `vi` bor. To'liq `vim` borligini `vim --version | head -5` bilan tekshiring; `command not found` desa VM ichida `sudo apt update && sudo apt install -y vim`. Bu paket o'rnatish VM'da bajariladi, host'da emas.
- **Ikkinchi terminal**: 15–17-vazifalarda ikkita sessiya kerak. Host'da yana bitta terminal oynasi ochib `multipass shell lab` qiling, ikkalasi bitta VM'ga ulanadi.
- **Fayl ko'chirish**: `~/.vimrc`, `~/.nanorc` va `sshd_config.lab` VM ichida yotadi, git'ga esa host'dagi ish papkasi kiradi. Host'da: `multipass transfer lab:/home/ubuntu/.vimrc linux/04-editors/vimrc`.
- **Ikkinchi mashinada tiklash**: laboratoriya holati mashinalar orasida ko'chmaydi. Boshqa mashinadagi `lab` da `~/edit` ni qayta yarating va nusxalarni qayta oling; sozlama fayllarini git'dan qaytaring: `multipass transfer linux/04-editors/vimrc lab:/home/ubuntu/.vimrc` (`nanorc` uchun ham shunday).
- **Tozalash**: VM'da `rm -r ~/edit` (`~/.vimrc` qolishi mumkin), `docker ps -a` da konteyner qolmagan, `multipass stop lab`.

| Mashina | Bu darsda nima farq qiladi |
|---------|----------------------------|
| Zorin (ofis) | Terminalda `Alt` nano'ning `M-` yorliqlari uchun to'g'ridan-to'g'ri ishlaydi. Host'ning o'zida odatda faqat `vi` (`vim.tiny`) bor; host'ga hech narsa o'rnatish shart emas, mashq VM'da. Konteyner `amd64`. |
| macOS (uy) | Muharrir yorliqlari `Control` bilan bosiladi, `Cmd` bilan emas: `Cmd+S`, `Cmd+Q`, `Cmd+W` terminal dasturining o'ziga tegishli (`Cmd+Q` terminalni yopadi). `Option` standart holatda Meta emas: Terminal.app'da Settings → Profiles → Keyboard → "Use Option as Meta key", iTerm2'da Profiles → Keys → Left Option key: `Esc+`. Sozlamasdan ham ishlaydigan yo'l: `Esc` ni bosib qo'yib yuborib, keyin harfni bosish (`Esc`, `U` = `M-U`). Host'dagi `nano` aslida `pico` ga symlink (`ls -l /usr/bin/nano`), yorliqlari farq qiladi, shuning uchun nano ham VM'da mashq qilinadi. Konteyner `arm64`. |

---

## 1. Nima uchun terminal muharriri va uni kim tanlaydi

### Bu nima

Terminal muharriri bu grafik oynasiz, terminalning o'zida ishlaydigan matn muharriri. Serverda monitor ham, VS Code ham yo'q, faqat ssh sessiyasi bor, shuning uchun konfiguratsiya shu yerda tahrirlanadi. Ikkita muharrir amalda hamma joyda uchraydi: **nano** (sodda, rejimsiz) va **vi** oilasi (`vi`, `vim`).

### Mexanizm: `$VISUAL`, `$EDITOR` va alternatives

Ko'p buyruqlar o'zi matn tahrirlamaydi: ular vaqtinchalik fayl yaratadi, muharrirni bola jarayon sifatida ishga tushiradi, muharrir yopilishini kutadi va faylni o'qib oladi. Qaysi muharrirni ochishni muhit o'zgaruvchilaridan oladi (muhit o'zgaruvchisi bu jarayonga ota jarayondan meros o'tadigan `NOM=qiymat` juftligi, Node'dagi `process.env`; batafsil 5-darsda).

| Buyruq | Qaysi tartibda qidiradi |
|--------|-------------------------|
| `git commit` | `$GIT_EDITOR`, `core.editor` sozlamasi, `$VISUAL`, `$EDITOR`, bo'lmasa standart (`vi`; Debian oilasida `editor`) |
| `crontab -e` (Ubuntu) | `$VISUAL`, `$EDITOR`, bo'lmasa `sensible-editor` |
| `systemctl edit` | `$SYSTEMD_EDITOR`, `$EDITOR`, `$VISUAL`, bo'lmasa `editor`, `nano`, `vim`, `vi` |
| `sudoedit`, `visudo` (Ubuntu) | `$SUDO_EDITOR`, `$VISUAL`, `$EDITOR`, bo'lmasa `editor` |
| `kubectl edit` | `$KUBE_EDITOR`, `$EDITOR`, bo'lmasa `vi` |

`editor` bu haqiqiy dastur emas, symlink zanjiri: `/usr/bin/editor` → `/etc/alternatives/editor` → haqiqiy binary. Debian oilasidagi **alternatives** tizimi bitta umumiy nom (`editor`, `vi`, `pager`) ortida bir nechta nomzodni ushlaydi va eng yuqori priority'lisini tanlaydi. `vi` nomi misolida:

```
ubuntu@lab:~$ update-alternatives --display vi
vi - auto mode
  link best version is /usr/bin/vim.basic
  link currently points to /usr/bin/vim.basic
  link vi is /usr/bin/vi
  ...
/usr/bin/vim.basic - priority <N>
/usr/bin/vim.tiny - priority <N>
```

Qatorma-qator: `auto mode` tanlov avtomatik (priority bo'yicha), qo'lda tanlangan bo'lsa `manual mode`; `link best version` eng yuqori priority'li nomzod; `link currently points to` hozir symlink qayerga qaragani; `link vi is` umumiy nomning o'zi; pastda har nomzod va uning priority'si. Demak bu VM'da `vi` deb yozsangiz to'liq Vim ochiladi. To'liq `vim` paketi o'rnatilmagan tizimda ro'yxatda faqat `vim.tiny` qoladi. Tanlovni o'zgartirish: `sudo update-alternatives --config editor` (interaktiv menyu).

```
export EDITOR=vim            # for the current shell session and its children
EDITOR=nano crontab -e       # for this one command only
```

### `vi`, `vim.tiny`, `vim`: qaysi biri ochildi

`vi` 1976-yilgi asl muharrir nomi, bugun u deyarli har doim Vim'ning biror yig'masi. Ubuntu'da ikkita yig'ma bor: `vim.tiny` (`vim-tiny` paketi, minimal) va `vim.basic` (`vim` paketi, to'liq). Farqni `--version` aytadi:

```
ubuntu@lab:~$ vim --version | head -5
VIM - Vi IMproved 9.1 (<sana>, compiled <sana>)
Included patches: 1-<N>
Modified by team+vim@tracker.debian.org
Compiled by team+vim@tracker.debian.org
Huge version without GUI.  Features included (+) or not (-):
ubuntu@lab:~$ vim --version | grep -o '[+-]syntax'
+syntax
```

Birinchi qator versiya, ikkinchisi qo'shilgan patch'lar, uchinchi va to'rtinchisi paketni kim yig'gani (Ubuntu Debian'ning yig'masini oladi). Beshinchi qatordagi `Huge version` to'liq yig'mani bildiradi, minimal yig'mada shu o'rinda `Tiny` (eski versiyalarda `Small`) turadi. Pastdagi uzun ro'yxatda `+nom` yig'maga kiritilgan, `-nom` kiritilmagan imkoniyat: `-syntax` bo'lsa rang yo'q. Alpine va BusyBox'dagi `vi` undan ham sodda, Vim emas. Xulosa: asosiy harakatlar plugin va sozlamasiz ham qo'lda bo'lishi kerak.

### Real ishda qachon kerak

- `git commit` ni `-m` siz yozdingiz va notanish muharrir ochildi: nima ochilganini va undan qanday chiqishni bilish.
- `crontab -e`, `visudo`, `systemctl edit nginx`, `kubectl edit deploy/web`: hammasi shu o'zgaruvchilarga qaraydi.
- Yangi serverda bir marta `export EDITOR=vim` ni `~/.profile` ga yozish (5-dars).

### Nima uchun shunday

`vi` POSIX standartiga kiritilgan, shuning uchun Unix'ga o'xshash har bir tizimda (Linux, macOS, BSD, minimal konteynerlarning ko'pi) bor deb hisoblash mumkin; nano esa kafolatlanmagan. Muharrirni o'zgaruvchi orqali tanlash Unix'ning "har dastur bitta ish qiladi" tamoyilidan: `git` muharrir yozmaydi, mavjudini chaqiradi. Ikki o'zgaruvchi tarixiy: `$EDITOR` qatorli muharrirlar (`ed`) davridan, `$VISUAL` to'liq ekranli muharrirlar uchun qo'shilgan, shuning uchun ko'p dasturlar avval `$VISUAL` ga qaraydi. Muqobili har dasturning o'z sozlamasi bo'lardi (`core.editor` kabi), bu esa har joyda alohida sozlashni talab qiladi.

## 2. Nano

### Bu nima va ekrani

Nano rejimsiz muharrir: yozgan harfingiz darhol matnga tushadi, buyruqlar esa `Ctrl` yoki `Alt` (Meta) bilan beriladi. `nano ~/edit/services` ochilganda ekran to'rt qismdan iborat:

```
  GNU nano 7.2                    services                    Modified
# Network services, Internet style
...
                              [ Read <N> lines ]
^G Help      ^O Write Out ^W Where Is  ^K Cut       ^T Execute   ^C Location
^X Exit      ^R Read File ^\ Replace   ^U Paste     ^J Justify   ^/ Go To Line
```

Yuqori qator: versiya, fayl nomi va saqlanmagan o'zgarish bo'lsa `Modified`. O'rtada matn. Pastdan uchinchi qator xabar qatori (`[ Read <N> lines ]`). Eng pastdagi ikki qator yorliqlar: `^` bu `Ctrl`, `M-` bu Meta (`Alt`, Mac'da `Option` yoki `Esc` keyin harf).

| Klavish | Nima qiladi | Xabar qatorida |
|---------|-------------|----------------|
| `Ctrl+O`, `Enter` | saqlash (Write Out) | `File Name to Write: services`, keyin `[ Wrote <N> lines ]` |
| `Ctrl+X` | chiqish | o'zgarish bo'lsa `Save modified buffer?` (`Y`, `N`, `Ctrl+C` bekor) |
| `Ctrl+W` | qidirish, `Alt+W` keyingi topilma | `Search:`; topilmasa `[ "soz" not found ]` |
| `Ctrl+\` | qidirib almashtirish | `Search (to replace):`, `Replace with:`, `Replace this instance?` (`Y`, `N`, `A` hammasi) |
| `Ctrl+K`, `Ctrl+U` | qatorni kesish, qo'yish | |
| `Alt+A`, keyin `Alt+6` | belgilashni boshlash, nusxa olish | `[ Mark Set ]` |
| `Ctrl+_` (yoki `Ctrl+/`) | qator raqamiga o'tish | `Enter line number, column number:` |
| `Alt+U`, `Alt+E` | undo, redo | |
| `Alt+N` | qator raqamlarini yoqish va o'chirish | |
| `Ctrl+G` | yordam, `Ctrl+X` bilan yopiladi | |

- `nano +42 fayl` 42-qatorda ochadi, `nano -l fayl` qator raqamlari bilan.
- Sozlamalar `~/.nanorc` da (tizim bo'yicha `/etc/nanorc`, unda barcha variantlar kommentda turadi). Foydali uchtasi: `set linenumbers`, `set tabsize 2`, `set tabstospaces`.

### Misol: bitta qiymatni o'zgartirish

`nano +3 notes.txt` → kursor 3-qatorda. `Ctrl+W`, `8080`, `Enter`: kursor topilmaning birinchi belgisiga keladi. `Delete` ni to'rt marta bosib `9090` yozing: yuqori o'ngda `Modified` paydo bo'ladi. `Ctrl+O`: pastda `File Name to Write: notes.txt`, `Enter`: `[ Wrote 5 lines ]` va `Modified` yo'qoladi. `Ctrl+X`: savolsiz chiqadi, chunki saqlanmagan o'zgarish yo'q.

**Tuzoq: `Ctrl+S` va `Ctrl+Q`.** Terminal drayverida eski "flow control" mexanizmi bor: `Ctrl+S` (XOFF) chiqishni to'xtatadi, ekran qotgandek ko'rinadi, `Ctrl+Q` (XON) davom ettiradi. Shell'da va Vim'da bu ishlaydi va yangi boshlovchini qo'rqitadi. Nano o'zi ishlayotganda flow control'ni o'chiradi, shuning uchun unda `Ctrl+S` shunchaki saqlaydi. Qoida: terminal qotsa birinchi bo'lib `Ctrl+Q` ni bosing.

### Real ishda qachon kerak

Bitta qatorni tuzatish, `crontab -e` standart holatda nano ochganda, Vim bilmaydigan hamkasbga "shu faylni och va shu qatorni o'zgartir" deganda. Katta va takroriy tahrirlarda (30 qatorni komment qilish, yuzta almashtirish) Vim tezroq.

### Nima uchun shunday

Nano 1999-yilda Pine pochta dasturining Pico muharririga erkin litsenziyali o'rinbosar sifatida yozilgan; maqsad o'rganishsiz ishlatish, shuning uchun yorliqlar doim ekranda. Narxi: tahrirlash "tili" yo'q, har amal alohida yorliq. Ubuntu `editor` uchun nano'ga eng yuqori priority beradi, chunki yangi foydalanuvchi undan chiqa oladi.

## 3. Vim: rejimlar

### Bu nima

Vim **modal** muharrir: bir xil klavish qaysi rejimda ekaningizga qarab har xil ish qiladi. Asosiy rejim Normal: unda harflar matn emas, buyruq (`d` o'chirish, `w` so'z oldinga). Sabab: konfiguratsiya ustida vaqtning ko'pi yangi matn yozishga emas, kerakli joyga borish va mavjud narsani o'zgartirishga ketadi.

| Rejim | Nima uchun | Qanday kiriladi | Pastki qatorda | Chiqish |
|-------|------------|-----------------|----------------|---------|
| Normal | harakatlanish, buyruqlar | Vim shu rejimda ochiladi | bo'sh | |
| Insert | matn yozish | `i`, `a`, `o`, `I`, `A`, `O` | `-- INSERT --` | `Esc` |
| Visual | belgilash | `v` (belgi), `V` (qator), `Ctrl+v` (blok) | `-- VISUAL --`, `-- VISUAL LINE --`, `-- VISUAL BLOCK --` | `Esc` |
| Command-line | `:` buyruqlari, qidiruv | `:`, `/`, `?` | yozayotgan buyrug'ingiz | `Enter` yoki `Esc` |

| Insert'ga kirish | Qayerdan yozadi |
|------------------|-----------------|
| `i`, `a` | kursor oldidan, kursordan keyin |
| `I`, `A` | qator boshidan (birinchi bo'sh bo'lmagan belgidan), qator oxiridan |
| `o`, `O` | pastda, yuqorida yangi qator ochib |

Qaysi rejimda ekaningizni bilmasangiz `Esc` ni ikki marta bosing: Normal'dasiz (ortiqcha `Esc` zarar qilmaydi).

### Misol: fayl yaratish, yozish, saqlash

```
ubuntu@lab:~/edit$ vim notes.txt
```

Ekran bo'sh, chap ustunda `~` belgilari (bu "fayl shu yerda tugagan" degani, matn emas), pastda:

```
"notes.txt" [New]
```

`i` bosing: pastda `-- INSERT --`. Uch qator yozing, `Esc`: yozuv yo'qoladi, Normal'dasiz. `:w` va `Enter`:

```
"notes.txt" [New] 3L, 42B written
```

Maydonlar: fayl nomi, `[New]` fayl hozir yaratildi, `3L` qatorlar soni, `42B` baytlar soni, `written` diskka yozildi. Bu qatorni ko'rmaguningizcha fayl saqlanmagan. Endi `:q` chiqaradi. O'zgartirib saqlamasdan `:q` desangiz:

```
E37: No write since last change (add ! to override)
```

| Buyruq | Nima qiladi |
|--------|-------------|
| `:w` | saqlash |
| `:q` | chiqish (saqlanmagan o'zgarish bo'lsa `E37` bilan rad etadi) |
| `:q!` | saqlamasdan chiqish |
| `:wq` | har doim yozadi va chiqadi |
| `:x`, `ZZ` | faqat o'zgarish bo'lsa yozadi, keyin chiqadi |
| `:e!` | saqlanmagan o'zgarishlarni tashlab, faylni diskdagi holatidan qayta o'qiydi |
| `:w boshqa.txt` | boshqa nom bilan yozish |

**Tuzoq: `vi` va vi-compatible rejim.** Debian oilasida `vim.tiny` `vi` nomi bilan chaqirilganda `/etc/vim/vimrc.tiny` o'qiladi va u `compatible` sozlamasini yoqadi (asl `vi` ga taqlid). Belgilari: pastda `-- INSERT --` chiqmaydi, Insert rejimida strelkalar harf yozadi, `u` faqat bitta qadamni qaytaradi (ikkinchi `u` qaytarilganni tiklaydi). Chora: `:set nocompatible`. Harakatni `h j k l` bilan qilsangiz bu farq sizga tegmaydi.

### Real ishda qachon kerak

Har `git commit`, `visudo`, `kubectl edit` da kamida uchta narsa kerak: Insert'ga kirish (`i`), Normal'ga qaytish (`Esc`), saqlab chiqish (`:wq`) yoki bekor qilish (`:q!`). `git commit` da `:q!` bo'sh xabar qoldiradi va commit bekor bo'ladi, bu qulay "voz kechish" yo'li.

### Nima uchun shunday

`vi` 1976-yilda sekin terminallar va sichqonchasiz klaviaturalar uchun yozilgan: `Ctrl` kombinatsiyalari kam va noqulay edi, shuning uchun oddiy harflar buyruq qilingan, matn yozish alohida rejimga chiqarilgan. `h j k l` strelkalar chizilgan ADM-3A terminali klaviaturasidan qolgan. Bu qaror bugun ham foydali: qo'l asosiy qatordan uzilmaydi va buyruqlarni birlashtirish mumkin (5-bo'lim). Muqobili rejimsiz muharrir (nano, VS Code): o'rganish oson, lekin har amal uchun alohida yorliq kerak.

## 4. Harakatlanish (motions)

### Bu nima

Motion bu Normal rejimda kursorni ko'chiradigan buyruq. Sichqoncha yo'q, ssh orqali strelka bilan 300-qatorga borish esa sekin, shuning uchun Vim'da "qayerga" degan savolga o'nlab aniq javob bor: so'z, qator boshi, juft qavs, paragraf, qator raqami.

| Harakat | Qayerga |
|---------|---------|
| `h` `j` `k` `l` | chap, past, yuqori, o'ng |
| `w`, `b`, `e` | keyingi so'z boshi, oldingi so'z boshi, so'z oxiri |
| `W`, `B`, `E` | xuddi shu, lekin "so'z" faqat bo'shliq bilan ajratiladi |
| `0`, `^`, `$` | qator boshi, birinchi bo'sh bo'lmagan belgi, qator oxiri |
| `gg`, `G` | fayl boshi, fayl oxiri |
| `42G` yoki `:42` | 42-qator |
| `Ctrl+d`, `Ctrl+u` | yarim ekran pastga, yuqoriga |
| `f{belgi}`, `t{belgi}` | qatordagi keyingi shu belgiga, undan bitta oldinga; `;` takrorlaydi |
| `%` | juft qavsga (`(`, `[`, `{`) |
| `{`, `}` | oldingi, keyingi bo'sh qatorga (paragraf chegarasi) |

### Mexanizm: son va "so'z" ta'rifi

Har harakat oldiga son yoziladi va harakat shuncha marta bajariladi: `5j` besh qator pastga, `3w` uch so'z oldinga. Vim uchun kichik `w` dagi "so'z" bu harf, raqam va `_` ketma-ketligi **yoki** boshqa belgilar ketma-ketligi; katta `W` uchun esa bo'shliqlar orasidagi hamma narsa. Shuning uchun `--log-level=info` ustida `w` bir necha marta to'xtaydi, `W` esa butun bo'lakni bitta hatlab o'tadi.

### Misol

Ichida `server_name = "api.example.com"  # public` qatori bor faylda kursor qator boshida turibdi:

| Klavish | Kursor qayerga keldi |
|---------|----------------------|
| `w` | `=` belgisiga (ikkinchi so'z) |
| `f"` | birinchi `"` ga |
| `;` | ikkinchi `"` ga (`f"` takrorlandi) |
| `$` | oxirgi belgi `c` ga |
| `^` | `s` ga, qator boshidagi bo'shliqlar bo'lsa ularni o'tkazib |
| `:set number`, `:3` | 3-qatorga; `Ctrl+g` pastda fayl nomi, qator soni va foizdagi o'rinni ko'rsatadi |

### Real ishda qachon kerak

Xato xabari qator raqamini aytadi (`nginx: ... in /etc/nginx/nginx.conf:42`): `vim +42 fayl` yoki `:42`. Uzun qatorda bitta parametrga yetish: `f=` yoki `/` bilan qidiruv (6-bo'lim). JSON yoki nginx blokining oxirini topish: `%`.

### Nima uchun shunday

Harakatlar alohida buyruq bo'lgani ularning o'zi uchun emas: ular 5-bo'limdagi operatorlarning "qayergacha" qismi. `w` ni bilsangiz `dw`, `cw`, `yw` ni ham bilasiz. Muqobili (Shift+strelka bilan belgilash) faqat belgi va qator birligida ishlaydi, "qavs ichi" yoki "paragraf" degan tushuncha yo'q.

## 5. Tahrirlash grammatikasi

### Bu nima

Vim buyruqlari gap kabi tuziladi: **operator + [son] + harakat**. Operator "nima qilish", harakat "qayergacha". Operatorlar va harakatlar alohida o'rganiladi, keyin erkin birlashtiriladi: 4 operator va 15 harakat 60 ta buyruq beradi.

| Operator | Ma'nosi |
|----------|---------|
| `d` | o'chirish (kesish) |
| `c` | o'chirib Insert'ga o'tish (change) |
| `y` | nusxa olish (yank) |
| `>`, `<` | chekinishni oshirish, kamaytirish |

```
dw      delete to the start of the next word
d$      delete to the end of the line (same as D)
c3w     change three words
y}      yank to the end of the paragraph
dG      delete to the end of the file
```

### Mexanizm: register, qator shakli va `.`

- Operator ikki marta yozilsa butun qatorga ta'sir qiladi: `dd`, `cc`, `yy`, `>>`. Son bilan: `3dd`.
- `d`, `c`, `y` olgan matn **register**ga tushadi (Vim'ning ichki buferi, tizim clipboard'i emas). `p` uni kursordan keyin, `P` oldin qo'yadi. Demak `dd` va `p` bu "kesib qo'yish".
- `x` bitta belgini o'chiradi, `r{belgi}` bitta belgini almashtiradi, `J` keyingi qatorni joriy qatorga ulaydi.
- `u` undo, `Ctrl+r` redo.
- `.` oxirgi **o'zgartirishni** butunligicha takrorlaydi: operator, harakat va Insert'da yozilgan matn birga. Harakatlar va `:` buyruqlari o'zgartirish hisoblanmaydi.

### Text object'lar

Operator'dan keyin harakat o'rniga "obyekt" berish mumkin: `i` (inner, ichi) yoki `a` (around, chegarasi bilan) va obyekt turi. Kursor obyekt ichida istalgan joyda bo'lishi mumkin, boshiga borish shart emas.

| Buyruq | Nima qiladi |
|--------|-------------|
| `ciw` | kursor ostidagi so'zni almashtirish |
| `ci"`, `ci'` | tirnoq ichidagini almashtirish |
| `di(`, `da(` | qavs ichini, qavslari bilan birga o'chirish |
| `dap` | paragrafni (bo'sh qatori bilan) o'chirish |
| `yi{` | figurali qavs ichini nusxalash |

### Misol: uchta qatorda bir xil o'zgartirish

Faylda uchta `timeout = "30"` shaklidagi qator bor, uchalasi `"120"` bo'lishi kerak. Kursor birinchisida:

| Klavish | Ekranda |
|---------|---------|
| `ci"` | tirnoq ichi bo'shadi (`timeout = ""`), pastda `-- INSERT --` |
| `120`, `Esc` | `timeout = "120"`, Normal rejim |
| `j` | keyingi qator |
| `.` | bu qator ham `"120"` bo'ldi: `.` uchta klavishni emas, "tirnoq ichini `120` ga almashtir" degan butun o'zgartirishni takrorladi |
| `j.` | uchinchisi |
| `3dd` | uch qator o'chadi, pastda `3 fewer lines` |
| `u` | qaytadi, pastda `3 more lines` bilan boshlanadigan xabar |

### Real ishda qachon kerak

`key = "value"` yoki `KEY=value` ko'rinishidagi konfiguratsiyada qiymat almashtirish (`ci"`, `cw`, `C`), blokni ko'chirish (`dap`, `p`), bir xil tuzatishni bir necha joyda takrorlash (`.`).

### Nima uchun shunday

Kompozitsiya yodlashni kamaytiradi: yangi harakat o'rgansangiz u barcha operatorlar bilan darhol ishlaydi. Bu shell'dagi pipe g'oyasining klaviaturadagi ko'rinishi: kichik qismlar, erkin birikma. `.` ning kuchi ham shundan: o'zgartirish bitta "gap" bo'lgani uchun uni butunligicha qayta aytish mumkin.

## 6. Qidirish va almashtirish

### Qidirish

| Buyruq | Nima qiladi |
|--------|-------------|
| `/pattern`, `?pattern` | oldinga, orqaga qidirish |
| `n`, `N` | keyingi, oldingi topilma |
| `*`, `#` | kursor ostidagi so'zni oldinga, orqaga qidirish |
| `:noh` | joriy yoritishni o'chiradi (keyingi qidiruvgacha) |
| `/pattern\c` | registrga qaramasdan |

Fayl oxiriga yetganda qidiruv boshidan davom etadi va pastda `search hit BOTTOM, continuing at TOP` chiqadi. Topilmasa: `E486: Pattern not found: <pattern>`. Pattern bu regex (regular expression, matn shablonlari tili; JS'dagidan sintaksisi biroz farq qiladi, 7-darsda batafsil): `.` istalgan belgi, `^` qator boshi, `$` qator oxiri, `\<` va `\>` so'z chegarasi.

### Almashtirish: `:[oraliq]s/pattern/almashtirish/[flaglar]`

```
:s/foo/bar/          first match on the current line
:s/foo/bar/g         all matches on the current line
:%s/foo/bar/g        whole file
:%s/foo/bar/gc       whole file, confirm each one
:10,20s/foo/bar/g    lines 10 to 20
:%s/\<foo\>/bar/g    whole word only
:%s#/var/www#/srv#g  another delimiter when the pattern contains slashes
```

Mexanizm: `:s` bu qatorli `ex` muharriri buyrug'i, u **oraliq**dagi har qatorni birma-bir ko'radi. Oraliq berilmasa faqat joriy qator, `%` butun fayl (`1,$` ning qisqartmasi), `10,20` qator raqamlari. `g` flag'i bo'lmasa har qatorda faqat birinchi topilma almashadi; `c` har birida `replace with bar (y/n/a/q/l/^E/^Y)?` deb so'raydi (`y` ha, `n` yo'q, `a` qolganining hammasi, `q` to'xtat). Visual rejimda qatorlarni belgilab `:` bossangiz oraliq o'zi qo'yiladi: `:'<,'>`.

Natija pastki qatorda:

```
7 substitutions on 5 lines
```

5 ta qator o'zgargan, ularda jami 7 ta almashtirish bo'lgan. Bu xabar faqat o'zgargan qatorlar soni `report` sozlamasidan (standart 2) ko'p bo'lsa chiqadi; bir yoki ikki qator o'zgarsa xabar yo'q, bu xato emas. Hech narsa topilmasa `E486`.

### `:g` buyrug'i

`:g/pattern/buyruq` pattern mos kelgan har qatorda `ex` buyrug'ini bajaradi, `:v/pattern/buyruq` mos kelmaganlarida.

```
:g/^#/d              delete all comment lines
:g/^$/d              delete all empty lines
:v/error/d           keep only lines containing "error"
```

`:g/^#/d` dan keyin pastda masalan `48 fewer lines` chiqadi. `grep` nomi aynan shu buyruqdan: `g/re/p` (global, regular expression, print).

### Real ishda qachon kerak

Konfiguratsiyada host nomi yoki yo'l almashganda (`:%s#old#new#gc`, `c` bilan ko'z yugurtirib), kommentlarga to'la standart konfiguratsiyadan faqat amaldagi qatorlarni ko'rish (`:g/^#/d`, saqlamasdan `:q!`), logdan faqat kerakli qatorlarni qoldirish (`:v`).

### Nima uchun shunday

Vim ikki muharrirning birikmasi: ekranli `vi` va uning ostidagi qatorli `ex` (`:` bilan boshlanadigan hamma narsa). `ex` buyruqlari ekransiz ishlashga mo'ljallangan, shuning uchun ular oraliq va pattern bilan ishlaydi. Xuddi shu `s/a/b/g` sintaksisi `sed` da ham bor (7-dars), chunki `sed` ham `ed` avlodidan: bu yerda o'rganganingiz u yerda qayta ishlatiladi.

## 7. Visual rejim, blok tahrirlash va tashqi buyruqlar

### Bu nima va qanday ishlaydi

Visual rejimda tartib teskari: avval belgilaysiz (ko'zingiz bilan ko'rasiz), keyin operator berasiz (`d`, `y`, `c`, `>`, `<`). `v` belgilar bo'yicha, `V` butun qatorlar, `Ctrl+v` to'rtburchak **blok** (ustunlar). `gv` oxirgi belgilashni qayta tiklaydi.

Blokning maxsus xususiyati: `I` (blok oldiga) yoki `A` (blokdan keyin) bilan yozilgan matn `Esc` bosilganda blokdagi **har** qatorga qo'yiladi.

### Misol: to'rt qatorni komment qilish

| Klavish | Ekranda |
|---------|---------|
| `0` | kursor qator boshida |
| `Ctrl+v` | pastda `-- VISUAL BLOCK --` |
| `3j` | birinchi ustun to'rt qatorda belgilandi |
| `I` | Insert rejimi, kursor birinchi qatorda |
| `# ` | hozircha faqat birinchi qatorda ko'rinadi |
| `Esc` | `# ` to'rtala qatorga qo'yildi |

Qaytarish: `0`, `Ctrl+v`, `3j`, `l` (ikki ustun: `#` va bo'shliq), `d`. Xuddi shu ishni `ex` yo'li bilan: `:12,15s/^/# /` va `:12,15s/^# //`.

### Tashqi buyruqlar va fayllar

| Buyruq | Nima qiladi |
|--------|-------------|
| `:r fayl`, `:r !date` | fayl mazmunini, buyruq chiqishini kursor ostidagi yangi qatorga qo'shadi |
| `:!ls -l` | muharrirdan chiqmasdan shell buyrug'i; `Enter` qaytaradi |
| `:e fayl` | boshqa faylni ochish |
| `:sp`, `:vsp` | oynani gorizontal, vertikal bo'lish; `Ctrl+w w` oynalar orasida |
| `vim +42 fayl` | 42-qatorda ochish |
| `vim -d a b` (`vimdiff`) | ikki faylni yonma-yon solishtirish |
| `view fayl` | faqat o'qish rejimida ochish |

`:!` va `:r !` ichida `%` belgisi joriy fayl nomiga almashadi (`:!wc -l %`). Haqiqiy `%` kerak bo'lsa `\%` yoziladi, masalan `:r !date +\%F`.

### Real ishda qachon kerak

Bir necha qatorni vaqtincha o'chirib qo'yish (komment), YAML blokini bir daraja surish (`V`, qatorlarni belgilash, `>`), faylga sana yoki hostname qo'shish (`:r !`), saqlashdan oldin sintaksisni tekshirish (`:w`, keyin `:!nginx -t`).

### Nima uchun shunday

Operator + harakat tez, lekin "qayergacha" ni oldindan aniq bilishni talab qiladi. Visual rejim (asl `vi` da yo'q, Vim qo'shgan) xato narxini kamaytiradi: nima o'zgarishini avval ko'rasiz. Blok rejimi konfiguratsiya va jadval ko'rinishidagi matn uchun: ustun bo'yicha ishlash boshqa muharrirlardagi multi-cursor'ning o'rnini bosadi.

## 8. Minimal .vimrc

### Bu nima

`~/.vimrc` bu Vim har ishga tushganda o'qiydigan sozlamalar fayli: ichidagi har qator `:` siz yozilgan Command-line buyrug'i. Server uchun maqsad qulaylik emas, xatoni kamaytirish: qator raqami, to'g'ri chekinish, ko'rinadigan qidiruv.

```
syntax on
set number              " line numbers
set expandtab           " insert spaces instead of tabs
set tabstop=2           " a tab is displayed as 2 columns
set shiftwidth=2        " indent step for >> and autoindent
set autoindent
set hlsearch incsearch  " highlight matches, search while typing
set ignorecase smartcase
```

Komment `"` belgisidan boshlanadi. `ignorecase smartcase` juftligi: kichik harf bilan yozilgan qidiruv registrga qaramaydi, ichida katta harf bo'lsa qaraydi.

### Mexanizm: tab bilan bog'liq uch sozlama

Tab bu bitta belgi (bayt `0x09`), ekranda nechta ustun egallashi esa muharrirning ishi. `tabstop` mavjud tab belgisi nechta ustun bo'lib **ko'rinishini** belgilaydi; `shiftwidth` `>>`, `<<` va avtomatik chekinish qadamini; `expandtab` yoqilgan bo'lsa `Tab` klavishi tab belgisi o'rniga bo'shliqlar yozadi. `expandtab` faqat yangi kiritilgan matnga ta'sir qiladi, faylda bor tab'lar qoladi: ularni `:retab` aylantiradi.

### Misol: sozlamani sinash va ko'rinmas belgilarni ko'rish

| Buyruq | Pastki qatorda yoki ekranda |
|--------|------------------------------|
| `:set number` | chapda qator raqamlari paydo bo'ladi |
| `:set nonumber` | yo'qoladi (`no` old qo'shimchasi o'chiradi) |
| `:set tabstop?` | `  tabstop=8` (joriy qiymat; `?` so'raydi, o'zgartirmaydi) |
| `:set list` | har tab `^I`, har qator oxiri `$` bo'lib ko'rinadi |
| `:set nolist` | odatdagi ko'rinish |
| `:retab` | `expandtab` yoqilgan bo'lsa tab'lar bo'shliqqa aylanadi, `:set list` da `^I` qolmaydi |

Shell'dan tekshirish: `cat -A fayl` ham tab'ni `^I`, qator oxirini `$` qilib ko'rsatadi (3-dars). `.vimrc` siz ishga tushirish (toza serverdagi holatni ko'rish uchun): `vim -u NONE fayl`.

**Tuzoq: YAML va tab.** YAML'da chekinish uchun tab taqiqlangan, Makefile'da esa aksincha, retsept qatori tab bilan boshlanishi shart. Ko'zga bir xil ko'rinadi. YAML tahrirlaganda `:set list` bilan tekshiring. `expandtab` yoqilgan holda haqiqiy tab kiritish: Insert rejimida `Ctrl+v`, keyin `Tab`.

### Real ishda qachon kerak

Kubernetes manifesti, `compose.yaml`, Ansible playbook: hammasi YAML va chekinish ma'no tashiydi. Serverda `.vimrc` yo'q bo'lsa kerakli ikki-uch sozlamani `:set` bilan qo'lda yoqasiz, shuning uchun ularni yoddan bilish kerak.

### Nima uchun shunday

Vim standart sozlamalari asl `vi` ga yaqin qoldirilgan (orqaga moslik), zamonaviy xulq esa sozlama bilan yoqiladi. Qisqa `.vimrc` ataylab: plugin'li katta konfiguratsiya o'z mashinangizda yaxshi, lekin 50 ta serverga ko'chmaydi va qo'lingizni u yerda yo'q narsaga o'rgatadi. `.editorconfig` va `prettier` loyihada qilgan ishni (chekinish qoidasi) bu yerda uch qator `set` qiladi.

## 9. Serverda omon qolish

### Tez yordam jadvali

| Holat | Belgisi | Yechim |
|-------|---------|--------|
| Chiqa olmayapman | har xil harflar yozilyapti | `Esc Esc`, keyin `:q!` |
| O'zgarish bor, chiqmayapti | `E37: No write since last change (add ! to override)` | `:wq` yoki `:q!` |
| Fayl faqat o'qish uchun | `E45: 'readonly' option is set (add ! to override)` | huquq yo'q: `:q!`, keyin `sudoedit fayl` |
| Yozib bo'lmayapti | `E212: Can't open file for writing` | faylga yoki papkaga yozish huquqi yo'q; `:w /tmp/nusxa` bilan ishni saqlab chiqing |
| Swap fayl topildi | `E325: ATTENTION` | pastda o'qing |
| Ekran qotdi | hech narsa javob bermaydi | `Ctrl+Q` (avval `Ctrl+S` bosilgan, 2-bo'lim) |
| Vim yo'qoldi, prompt chiqdi | `[1]+  Stopped                 vim fayl` | `Ctrl+Z` bosilgan; `fg` qaytaradi |
| Pastda `recording @q` | makro yozilyapti (`q` va harf bosilgan) | `q` to'xtatadi |
| Hamma harf buyruq bo'lyapti, g'alati ishlar | | Caps Lock yoqilgan: `j` o'rniga `J` ketmoqda |

Huquqi yo'q faylni ochganingizda Vim buni darhol aytadi, pastda: `"/etc/hosts" [readonly] <N>L, <N>B`. O'zgartira boshlasangiz `W10: Warning: Changing a readonly file`. Shu ikki yozuvni ko'rgan zahoti to'xtang: tahrir saqlanmaydi.

### Swap fayl

Mexanizm: Vim faylni xotiraga o'qiydi va tahrirlash paytida fayl yonida yashirin `.fayl.swp` yaratadi, saqlanmagan o'zgarishlarni unga vaqti-vaqti bilan yozib boradi. Normal chiqishda swap o'chiriladi. Ochayotganda swap allaqachon bor bo'lsa, ikki sababdan biri: fayl hozir boshqa sessiyada ochiq, yoki oldingi sessiya saqlamasdan uzilgan (ssh uzilishi, `kill`).

```
E325: ATTENTION
Found a swap file by the name ".notes.txt.swp"
          owned by: ubuntu   dated: <sana>
         file name: ~ubuntu/edit/notes.txt
          modified: YES
         user name: ubuntu   host name: lab
        process ID: <PID> (STILL RUNNING)
While opening file "notes.txt"
             dated: <sana>
...
[O]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort:
```

O'qish tartibi: `owned by` va `dated` swap kimniki va qachongi; `modified: YES` unda saqlanmagan o'zgarish bor; `process ID` uni yaratgan Vim jarayoni; `(STILL RUNNING)` o'sha jarayon hozir ham tirik. Oxirgi qator tanlov menyusi.

- Jarayon tirik bo'lsa fayl boshqa joyda ochiq: `Q` va o'sha sessiyani toping (boshqa terminal, `Ctrl+Z` bilan fonda qolgan Vim, hamkasbingiz).
- `(STILL RUNNING)` yo'q bo'lsa: `R` (Recover) bilan tiklang, natijani ko'zdan kechiring, `:w` qiling, chiqing va swap faylni o'chiring (`rm .notes.txt.swp`). Aks holda xabar har safar chiqadi.
- Terminaldan tiklash: `vim -r fayl`.

### sudoedit

Root'ga tegishli faylni `sudo vim fayl` bilan ochmang: butun muharrir root sifatida ishlaydi (`:!sh` root shell beradi, `.vimrc` va plugin'lar root huquqi bilan bajariladi). To'g'ri usul: `sudoedit fayl` (yoki `sudo -e fayl`). Mexanizmi: `sudo` faylning vaqtinchalik nusxasini yaratadi, muharrirni (`$SUDO_EDITOR`, `$VISUAL`, `$EDITOR`) **sizning** nomingizdan shu nusxa ustida ochadi, siz saqlab chiqqaningizdan keyin nusxani root huquqi bilan asl joyiga yozadi. Hech narsa o'zgartirmasangiz: `sudoedit: /etc/hosts unchanged`.

`/etc/sudoers` uchun faqat `visudo` (5-darsda): u ham nusxa ustida ishlaydi va saqlashdan oldin sintaksisni tekshiradi, chunki buzilgan `sudoers` sizni `sudo` siz qoldiradi.

### Muharrir umuman yo'q bo'lsa

Minimal konteyner image'ida `vi` ham, `nano` ham bo'lmasligi mumkin (1-dars, 21-vazifa). Variantlar: `cat > fayl <<'EOF'` (here-document, 5-darsda), `sed -i` (7-darsda), `echo "qator" >> fayl`, yoki faylni tashqarida tahrirlab `docker cp` bilan kiritish. Production konteyneriga muharrir o'rnatish odatda noto'g'ri yo'l: konteyner o'zgarmas bo'lishi kerak, tuzatish image yoki konfiguratsiyaga kiritiladi (Docker modulida).

### Real ishda qachon kerak

ssh uzilib qolganda tahrirni yo'qotmaslik (swap), `/etc` dagi faylni xavfsiz o'zgartirish (`sudoedit`), ishlamay qolgan pod ichida bitta faylni tuzatib ko'rish (muharrirsiz usullar).

### Nima uchun shunday

Swap fayl sekin va uzilib turadigan aloqa davridan: sessiya har daqiqada uzilishi mumkin edi, bir soatlik tahrir yo'qolmasligi kerak. `sudoedit` "eng kam imtiyoz" tamoyili: root huquqi faqat bitta faylni yozish uchun kerak, butun interaktiv dastur uchun emas. Muqobili (`sudo vim`) ishlaydi, lekin xato yoki zararli sozlama root nomidan bajariladi.

## Atamalar

| Atama | Ta'rif |
|-------|--------|
| Modal muharrir | bir xil klavish joriy rejimga qarab har xil ish qiladigan muharrir |
| Normal, Insert, Visual, Command-line | Vim rejimlari: buyruq berish, matn yozish, belgilash, `:` buyruqlari |
| Status qatori (pastki qator) | Vim rejim va xabarlarni ko'rsatadigan ekranning oxirgi qatori |
| Motion | kursorni ko'chiradigan va operatorga "qayergacha" ni aytadigan buyruq (`w`, `$`, `G`) |
| Operator | harakat yoki obyekt ustida amal bajaradigan buyruq (`d`, `c`, `y`, `>`) |
| Text object | kursor atrofidagi tuzilma: so'z, tirnoq ichi, qavs ichi, paragraf (`iw`, `i"`, `ap`) |
| Register | `d`, `c`, `y` olgan matn saqlanadigan Vim ichki buferi |
| Yank | Vim'da nusxa olish (`y`) |
| `ex` buyrug'i | `:` bilan boshlanadigan, qatorlar oralig'i ustida ishlaydigan buyruq (`:s`, `:g`, `:w`) |
| Oraliq (range) | `ex` buyrug'i ta'sir qiladigan qatorlar: `%`, `10,20`, `'<,'>` |
| Visual block | `Ctrl+v` bilan to'rtburchak (ustun) belgilash |
| Swap fayl | saqlanmagan o'zgarishlar yoziladigan `.fayl.swp`, tiklash va ikki marta ochishdan himoya uchun |
| `.vimrc`, `.nanorc` | Vim va nano'ning foydalanuvchi sozlama fayllari |
| `$EDITOR`, `$VISUAL` | boshqa dasturlar qaysi muharrirni ochishini belgilaydigan muhit o'zgaruvchilari |
| Alternatives | Debian oilasida umumiy nomni (`editor`, `vi`) aniq dasturga symlink orqali bog'laydigan tizim |
| Meta (`M-`) | nano yorliqlaridagi `Alt` (`Option`) klavishi yoki `Esc` keyin harf |
| Flow control (XON/XOFF) | terminalning `Ctrl+S` bilan chiqishni to'xtatib, `Ctrl+Q` bilan davom ettirish mexanizmi |
| `sudoedit` | faylni foydalanuvchi nomidan nusxada tahrirlab, root huquqi bilan joyiga yozadigan `sudo -e` rejimi |

## Tuzoqlar

- Production konfiguratsiyasini nusxa olmasdan tahrirlash. Avval `cp -a fayl fayl.bak`, yaxshisi konfiguratsiya git'da yoki Ansible'da.
- `sudo vim /etc/...` odati. `sudoedit` ishlating, `sudoers` uchun `visudo`.
- Saqlagandan keyin tekshirmaslik. Ko'p servislarda sintaksis tekshiruvi bor: `sshd -t`, `nginx -t`, `visudo -c`. Tekshirmasdan restart qilingan servis ko'tarilmaydi, `sshd` bo'lsa serverga kira olmay qolasiz.
- Swap xabarida o'qimasdan `E` (Edit anyway) bosish: boshqa sessiyadagi o'zgarishlar bilan to'qnashuv, biri ikkinchisini ustidan yozadi.
- YAML'ga tab tushishi. Xato xabari ko'pincha boshqa qatorni ko'rsatadi va topish qiyin. `:set list`.
- Terminalga ko'p qatorli matn qo'yganda `autoindent` chekinishni zinapoya qilib yuborishi mumkin (bracketed paste qo'llamaydigan terminal yoki eski Vim'da). Belgisi shu bo'lsa: `:set paste`, qo'ying, `:set nopaste`.
- `:wq` ni odat qilib, faqat o'qimoqchi bo'lgan faylni ham yozish (mtime o'zgaradi, monitoring yoki deploy vositasi "o'zgardi" deb o'ylaydi). Faqat ko'rish uchun `view` yoki `less`, chiqish uchun `:q`.
- `Ctrl+Z` bilan Vim'ni fonda unutib, faylni ikkinchi marta ochish. `jobs` bilan tekshiring.
- macOS'da `Cmd+S`, `Cmd+Z`, `Cmd+Q` ni muharrir yorlig'i deb bosish: ular terminal dasturiga ketadi. Host'dagi `nano` (aslida `pico`) va BSD utilitalarida o'rganilgan narsa serverdagidan farq qiladi, mashq VM'da.
- `vi` da `-- INSERT --` ko'rinmasligi va strelkalar harf yozishi buzilish emas, vi-compatible rejim (3-bo'lim).

## Manbalar

- https://vimhelp.org/usr_02.txt.html – Vim user manual, "The first steps in Vim"
- https://vimhelp.org/usr_03.txt.html – harakatlanish
- https://vimhelp.org/usr_04.txt.html – operatorlar, text object'lar, `.`
- https://vimhelp.org/usr_10.txt.html – katta o'zgartirishlar: `:s`, `:g`, visual block
- https://vimhelp.org/recover.txt.html – swap fayl va tiklash
- https://vimhelp.org/options.txt.html – barcha `set` sozlamalari
- https://www.nano-editor.org/dist/latest/nano.html – nano rasmiy qo'llanmasi
- https://www.nano-editor.org/dist/latest/nanorc.5.html – `nanorc(5)`
- https://www.sudo.ws/docs/man/sudo.man/ – `sudo(8)`, `-e` (sudoedit) bo'limi
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/vi.html – POSIX'dagi `vi` ta'rifi
- https://git-scm.com/docs/git-var – `GIT_EDITOR`: git muharrirni qaysi tartibda tanlaydi
- https://www.freedesktop.org/software/systemd/man/latest/systemctl.html – `systemctl edit` va `$SYSTEMD_EDITOR`
- https://man7.org/linux/man-pages/man1/update-alternatives.1.html – `update-alternatives(1)`
- `vimtutor` buyrug'i – Vim bilan birga keladigan 30 daqiqalik interaktiv darslik
- Neil, "Practical Vim" (2-nashr) – 1–4 boblar (grammatika va `.` formulasi)

## Birga bajaramiz

Bitta xayoliy servis (`shop-api`) konfiguratsiyasini boshidan oxirigacha tahrirlaymiz: nusxa olish, nano'da bitta qiymat, Vim'da qolgan hammasi, oxirida `diff` bilan tekshirish. Hamma narsa VM ichida, alohida `~/edit/demo` papkasida.

1. Faylni yarating va zaxira nusxa oling:

```
ubuntu@lab:~$ mkdir -p ~/edit/demo && cd ~/edit/demo
ubuntu@lab:~/edit/demo$ printf '%s\n' '# shop-api settings' 'listen_host = "127.0.0.1"' 'listen_port = "8080"' 'db_host = "db-old.internal"' 'db_replica = "db-old.internal"' 'db_backup = "db-old.internal"' 'cache_host = "cache.internal"' 'log_level = "debug"' 'debug_sql = "on"' 'debug_trace = "on"' 'debug_http = "on"' 'workers = "2"' > app.conf
ubuntu@lab:~/edit/demo$ cp -a app.conf app.conf.orig
ubuntu@lab:~/edit/demo$ wc -lc app.conf
 12 274 app.conf
```

`printf '%s\n'` har argumentni alohida qatorga yozadi. `cp -a` vaqt va huquqlarni saqlab nusxalaydi (3-dars). `wc -lc`: 12 qator, 274 bayt, shu sonlarni Vim'da yana ko'ramiz.

2. Nano'da portni o'zgartiring: `nano app.conf`, `Ctrl+W`, `8080`, `Enter` (kursor `8` ustida), `Delete` to'rt marta, `9090` (yuqorida `Modified`), `Ctrl+O`, `Enter`:

```
[ Wrote 12 lines ]
```

`Ctrl+X` savolsiz chiqaradi.

3. Vim'da oching: `vim app.conf`. Pastda:

```
"app.conf" 12L, 274B
```

Qator va bayt soni `wc` bilan bir xil (`8080` va `9090` uzunligi teng).

4. Log darajasini almashtiring: `/log_level`, `Enter` (kursor 8-qatorga keladi), `ci"`, `info`, `Esc`. Qator `log_level = "info"` bo'ldi. Kursor qator boshida edi, tirnoqqa bormadik: `ci"` qatordagi birinchi tirnoq juftini o'zi topadi.

5. Ma'lumotlar bazasi host'ini uch qatorda almashtiring: `:%s/db-old/db-new/g`, `Enter`:

```
3 substitutions on 3 lines
```

6. Debug qatorlarini o'chiring: `:g/^debug_/d`, `Enter`:

```
3 fewer lines
```

`^` tufayli faqat `debug_` bilan **boshlanadigan** qatorlar o'chdi; `log_level = "info"` ichida `debug` so'zi endi yo'q, bo'lganda ham `^debug_` unga mos kelmasdi.

7. Ikki qatorni vaqtincha komment qiling: `/cache`, `Enter`, `0`, `Ctrl+v` (pastda `-- VISUAL BLOCK --`), `j`, `I`, `# `, `Esc`. `cache_host` va `log_level` qatorlari `# ` bilan boshlanadi.

8. Faylning boshiga sana yozing: `gg`, `O` (yuqorida yangi qator, Insert), `# edited on`, `Esc`, `:r !date +\%F`, `Enter` (sana alohida 2-qator bo'lib tushadi), `k`, `J`. `J` ikki qatorni bitta bo'shliq bilan uladi: `# edited on <sana>`.

9. Saqlang va chiqing: `:w`, `Enter`:

```
"app.conf" 10L, 246B written
```

12 qatordan 3 tasi o'chdi, 1 tasi qo'shildi: 10. Keyin `:q`.

10. Nima o'zgarganini tekshiring:

```
ubuntu@lab:~/edit/demo$ diff app.conf.orig app.conf
0a1
> # edited on <sana>
3,11c4,9
< listen_port = "8080"
< db_host = "db-old.internal"
< db_replica = "db-old.internal"
< db_backup = "db-old.internal"
< cache_host = "cache.internal"
< log_level = "debug"
< debug_sql = "on"
< debug_trace = "on"
< debug_http = "on"
---
> listen_port = "9090"
> db_host = "db-new.internal"
> db_replica = "db-new.internal"
> db_backup = "db-new.internal"
> # cache_host = "cache.internal"
> # log_level = "info"
ubuntu@lab:~/edit/demo$ ls -A
app.conf  app.conf.orig
```

`0a1`: yangi faylning 1-qatori qo'shilgan (`a` add). `3,11c4,9`: eski 3–11 qatorlar yangi 4–9 qatorlarga almashgan (`c` change); `<` eski, `>` yangi. Kutilmagan o'zgarish yo'q. `ls -A` da `.app.conf.swp` yo'q: Vim to'g'ri yopilgan. Oxirida `cd ~ && rm -r ~/edit/demo`.

Shu 10 qadamda ko'rganingiz: tahrirdan oldin nusxa (Tuzoqlar), nano'da oddiy tahrir (2-bo'lim), Vim status qatorini o'qish va saqlash (3-bo'lim), qidiruv bilan borish (4 va 6-bo'limlar), text object (5-bo'lim), `:s` va `:g` (6-bo'lim), visual block va `:r !` (7-bo'lim), swap fayl qolmaganini tekshirish (9-bo'lim).

---

## Vazifalar

Ish papkasi: `linux/04-editors/` (`make new m=linux n=04 name=editors` bilan host'da yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida nima qilganingiz, **bosgan klavishlar ketma-ketligi**, pastki qatorda chiqqan xabarlar (xatolar so'zma-so'z) va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`vimrc`, `nanorc`, `sshd_config.lab`) VM'dan `multipass transfer` bilan olib shu papkaga saqlang (Laboratoriya bo'limi). Vazifalar `lab` VM'da, `~/edit` papkasida bajariladi, 18-vazifa host'dagi konteynerda. Vim vazifalarida sichqoncha va strelkalarni ishlatmang. macOS'da `M-` yorliqlari uchun `Option` ni Meta qiling yoki `Esc` keyin harf bosing; ikkala host'da ham vazifa matni bir xil, chunki hammasi VM ichida.

### A. Nano

1. **Nano basics.** `cp /etc/services ~/edit/services` qiling va nano'da oching. `https` so'zini qidiring, 100-qatorga o'ting, bitta qatorni kesib fayl boshiga qo'ying, `tcp` ni `TCP` ga birinchi 5 ta topilmada almashtiring, undo bilan bittasini qaytaring, saqlang va chiqing. Har amal uchun klavishni yozing. Yo'nalish: 2-bo'lim, "Bu nima va ekrani".

2. **Nano config.** `~/.nanorc` yarating: qator raqamlari, tab kengligi 2, tab o'rniga bo'shliq. Faylni qayta ochib `Tab` bosing va `cat -A` bilan tab emas bo'shliq yozilganini isbotlang. `/etc/nanorc` dan yana bitta foydali sozlamani topib qo'shing va nima qilishini yozing. Faylni ish papkasiga `nanorc` nomi bilan saqlang. Yo'nalish: 2-bo'lim (sozlamalar) va 8-bo'lim, "Misol: sozlamani sinash va ko'rinmas belgilarni ko'rish".

3. **Default editor.** `echo "$EDITOR" "$VISUAL"`, `ls -l /usr/bin/editor /etc/alternatives/editor` va `update-alternatives --display editor` natijasini yozing. `crontab -e` qaysi muharrirni ochdi (saqlamasdan chiqing)? `EDITOR=vim crontab -e` bilan qayta sinang. Sozlama doimiy bo'lishi uchun qayerga yozilishi kerak? Yo'nalish: 1-bo'lim, "Mexanizm: `$VISUAL`, `$EDITOR` va alternatives".

### B. Vim asoslari

4. **vimtutor.** `vimtutor` ni ishga tushirib 1–4 darslarni bajaring. Siz uchun yangi bo'lgan 5 ta buyruqni va har biri qaysi holatda foydali ekanini yozing. Yo'nalish: 3–5 bo'limlar.

5. **Modes and exit.** Faylni oching, matn qo'shing va chiqishning har bir usulini alohida sinang: `:q`, `:q!`, `:wq`, `:x`, `ZZ`. `:q` bergan xatoni yozing. `:wq` va `:x` farqini isbotlang: faylni o'zgartirmasdan har biri bilan chiqing va `stat` dagi mtime ni solishtiring. Yo'nalish: 3-bo'lim, "Misol: fayl yaratish, yozish, saqlash".

6. **Motions drill.** `~/edit/services` da faqat harakat buyruqlari bilan: 250-qatorga, fayl oxiriga, fayl boshiga o'ting; qatorda uchinchi so'zga, qator oxiriga, birinchi bo'sh bo'lmagan belgiga; keyingi `/` belgisiga (`f`); 10 qator pastga; keyingi bo'sh qatorga. Har biri uchun klavishlarni yozing. `w` va `W` farqi nima (`ssh 22/tcp` qatorida sinang)? Yo'nalish: 4-bo'lim, "Mexanizm: son va so'z ta'rifi".

7. **Operator grammar.** `~/edit/g.txt` ga 15–20 qatorli konfiguratsiyaga o'xshash matn yozing (`key = "value"` qatorlari, qavsli ro'yxat, ikkita paragraf). Har birini bitta buyruq bilan bajaring va klavishlarni yozing: 3 qatorni o'chirish, kursordan qator oxirigacha o'chirish, so'zni almashtirish, tirnoq ichidagi qiymatni almashtirish, qavs ichini o'chirish, paragrafni nusxalab fayl oxiriga qo'yish, ikki qatorni joylarini almashtirish. Yo'nalish: 5-bo'lim, "Text object'lar".

8. **Dot and undo.** `g.txt` da 6 ta qator boshiga `# ` qo'shing: birinchisini `I` bilan, qolganlarini faqat `j` va `.` bilan. Keyin `u` bilan uchtasini qaytaring va `Ctrl+r` bilan ikkitasini tiklang. `.` aynan nimani takrorlaydi: oxirgi klavishnimi yoki oxirgi o'zgartirishnimi? Buni ko'rsatadigan tajriba qiling. Yo'nalish: 5-bo'lim, "Mexanizm: register, qator shakli va `.`".

### C. Qidirish va almashtirish

9. **Search.** `~/edit/services` da: `ssh` ni qidiring va `n` bilan barcha topilmalarni aylaning; kursor ostidagi so'zni `*` bilan qidiring; `SSH` ni registrga qaramasdan toping; `:set hlsearch` va `:noh` farqini ko'ring. Mavjud bo'lmagan so'zni qidirganda chiqqan xatoni yozing. Yo'nalish: 6-bo'lim, "Qidirish".

10. **Substitute.** `~/edit/services` nusxasida: (a) butun faylda `tcp` ni `TCP` ga, (b) faqat 20–40 qatorlarda `udp` ni `UDP` ga, (c) butun so'z `www` ni (masalan `www-http` ichidagisini emas) `web` ga tasdiqlash bilan, (d) `/tcp` ni `/TCP` ga slash'dan boshqa ajratuvchi bilan almashtiring. Har buyruqni va pastda chiqqan "N substitutions on M lines" xabarini yozing. `g` flag'isiz nima o'zgaradi? Yo'nalish: 6-bo'lim, "Almashtirish".

11. **Global command.** `cp /etc/ssh/sshd_config ~/edit/sshd_strip` qiling. Vim ichida barcha komment qatorlarini va barcha bo'sh qatorlarni o'chiring, nechta qator qolganini yozing. Natijani `grep -cvE '^(#|$)' /etc/ssh/sshd_config` soni bilan solishtiring. `:g` va `:v` farqini bitta misolda ko'rsating. Yo'nalish: 6-bo'lim, "`:g` buyrug'i".

### D. Visual va chekinish

12. **Block edit.** `g.txt` da visual block bilan 8 ta ketma-ket qatorni komment qiling (`# ` qo'shing), keyin xuddi shu usulda kommentni olib tashlang. Xuddi shu ishni `:s` bilan oraliq berib bajaring. Qaysi usul qachon qulay? Yo'nalish: 7-bo'lim, "Misol: to'rt qatorni komment qilish".

13. **Tabs in YAML.** `printf 'app:\n\tname: web\n\tports:\n\t\t- 80\n' > ~/edit/bad.yaml` yarating. `python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' ~/edit/bad.yaml` xatosini yozing. Vim'da `:set list` bilan muammoni ko'ring, `expandtab` va `:retab` bilan tuzating, tekshiruvni qayta ishga tushiring. Keyin `ports` blokini `>` bilan bir daraja o'ngga suring va YAML ma'nosi qanday o'zgarganini izohlang. Yo'nalish: 8-bo'lim, "Mexanizm: tab bilan bog'liq uch sozlama".

### E. Sozlama

14. **Minimal vimrc.** O'zingizning `~/.vimrc` ni yozing: 15 qatordan oshmasin, har sozlama yonida nima uchun kerakligi haqida inglizcha komment. Har sozlamani avval `:set` bilan sinab ko'ring. `vim -u NONE fayl` bilan solishtirib, qaysi sozlamasiz ishlash eng qiyin ekanini yozing. Faylni ish papkasiga `vimrc` nomi bilan saqlang. Yo'nalish: 8-bo'lim.

### F. Omon qolish

15. **Swap file.** Birinchi terminalda faylni Vim'da ochib o'zgartiring, saqlamang. Ikkinchi terminaldan o'sha faylni oching: xabarni to'liq o'qing, undagi PID va holatni yozing, `Q` bilan chiqing. Keyin ikkinchi terminaldan Vim jarayonini `kill -9` bilan o'ldiring, `ls -la` da swap faylni toping, faylni qayta ochib o'zgarishlarni tiklang, saqlang va swap faylni o'chiring. Ikki holatda (jarayon tirik va o'lik) to'g'ri harakat nima uchun farq qiladi? Ikkinchi terminal: host'da yana bir oyna va `multipass shell lab`. Yo'nalish: 9-bo'lim, "Swap fayl".

16. **Read-only file.** `clean` snapshot borligini tekshiring. `vim /etc/hosts` ni `sudo` siz oching, qator qo'shing, `:w` va `:w!` xatolarini yozing, o'zgarishni `/tmp` ga saqlab chiqing. Keyin `sudoedit /etc/hosts` bilan `10.0.0.10 lab-db` qatorini qo'shing va `getent hosts lab-db` bilan tekshiring. `sudoedit` paytida ikkinchi terminalda `ps -ef | grep vim` qiling: muharrir kim nomidan ishlayapti? `sudo vim` dan farqi nima? Oxirida qo'shilgan qatorni olib tashlang. Yo'nalish: 9-bo'lim, "sudoedit" va "Tez yordam jadvali".

17. **Frozen terminal.** Vim ichida `Ctrl+S` bosing, bir nechta klavish bosib ko'ring, keyin `Ctrl+Q`. Nima bo'ldi? Keyin `Ctrl+Z` bosing: Vim qayerga ketdi? `jobs` va `fg` bilan qaytaring. Normal rejimda `q` va `a` ni bosing, pastdagi yozuvni o'qing va bu holatdan chiqing. Yo'nalish: 2-bo'limdagi `Ctrl+S` tuzog'i va 9-bo'lim, "Tez yordam jadvali".

18. **No editor at all.** Host'da `docker run --rm -it ubuntu:24.04 bash` ichida `vi`, `vim`, `nano` ni sinang. Muharrir o'rnatmasdan `/etc/motd` faylini uch qator bilan yarating, keyin o'rtadagi qatorni o'zgartiring (ikki xil usul toping). Shundan keyin `apt` bilan `vim-tiny` o'rnatib, `vi` da xuddi shu tahrirni bajaring. Production konteynerida muharrir o'rnatish nima uchun yomon amaliyot? Mac'da konteyner `arm64`, Zorin'da `amd64`, vazifa ikkalasida bir xil. Yo'nalish: 9-bo'lim, "Muharrir umuman yo'q bo'lsa" va 3-bo'limdagi vi-compatible tuzog'i.

### G. Yakuniy

19. **Config edit.** `cp /etc/ssh/sshd_config ~/edit/sshd_config.lab` qiling va faqat Vim bilan (har qadam klavishlarini yozib): (a) `#Port 22` qatorini topib kommentdan chiqaring va `2222` ga o'zgartiring, (b) `PermitRootLogin` ni `no` qiling, (c) `PasswordAuthentication` ni `no` qiling, (d) faylning eng boshiga `# edited by <ismingiz> on <sana>` qatorini qo'shing, sanani `:r !date +\%F` orqali oling, (e) fayl oxiriga `AllowUsers ubuntu` qo'shing. Keyin `diff /etc/ssh/sshd_config ~/edit/sshd_config.lab` bilan faqat shu o'zgarishlar borligini, `sudo sshd -t -f ~/edit/sshd_config.lab` bilan sintaksis to'g'riligini tekshiring. Bitta kalit so'zni ataylab buzib `sshd -t` xatosini o'qing va tuzating. Faylni ish papkasiga saqlang. Haqiqiy `/etc/ssh/sshd_config` ga tegmang. Yo'nalish: butun dars; sana uchun 7-bo'lim, "Tashqi buyruqlar va fayllar".

20. **Speed run.** 19-vazifani toza nusxada qayta bajaring va vaqtni o'lchang. Qaysi qadamlarda sekinlashdingiz, qaysi buyruqlar bilan qisqartirish mumkin edi (masalan qidiruv + `cw` + `n` + `.`)? Yakuniy klavishlar ro'yxatini birinchi urinishdagi bilan solishtirib yozing. Yo'nalish: 5-bo'lim (`.`) va "Birga bajaramiz".

### Topshirish

Tayyor bo'lgach:
1. `linux/04-editors/README.md` da 20 ta vazifa `## N. Title` sarlavhalari ostida, klavishlar ketma-ketligi bilan.
2. Ish papkasida `nanorc`, `vimrc`, `sshd_config.lab` fayllari bor.
3. `make check` toza o'tadi (host'da).
4. VM'da `/etc/hosts` va `/etc/ssh/sshd_config` asl holatida, `~/edit` da swap fayl qolmagan, konteyner o'chirilgan.
5. Menga xabar bering.

### O'zini tekshirish savollari (kodsiz, o'z so'zingiz bilan javob bering)

- Vim'da nima uchun Normal rejim asosiy va rejimni bilmasangiz nima qilasiz?
- `d3w`, `ci"`, `dap` buyruqlarini qismlarga ajratib tushuntiring.
- `.` nimani takrorlaydi va uni qidiruv bilan qanday birlashtirasiz?
- `:s/a/b/`, `:s/a/b/g`, `:%s/a/b/g`, `:%s/a/b/gc` farqlari nima?
- `:g/pattern/d` nima qiladi, `:v` nima?
- `E325` xabari chiqqanda qanday qaror qabul qilasiz?
- `sudo vim fayl` va `sudoedit fayl` farqi nima? `/etc/sudoers` uchun nima ishlatiladi?
- YAML faylida tab borligini qanday aniqlaysiz va tuzatasiz?
- `git commit` yoki `crontab -e` qaysi muharrirni ochishini nima belgilaydi?
- Konfiguratsiyani saqlagandan keyin servisni restart qilishdan oldin nima qilish kerak?
