# 4-dars: Terminal muharrirlari (Nano, Vim)

Maqsad: grafik muharrir yo'q joyda (ssh sessiyasi, konteyner, recovery rejimi) konfiguratsiya faylini ishonch bilan tahrirlay olish. Nano oddiy holatlar uchun, Vim esa har qanday serverda `vi` nomi bilan mavjud bo'lgani uchun: `visudo`, `crontab -e`, `git commit`, `systemctl edit`, `kubectl edit` sizni so'ramasdan muharrirga tashlaydi. Dars Vim'ni IDE qilishni emas, uning grammatikasini (rejimlar, operator + harakat), qidirish va almashtirishni, minimal `.vimrc` ni va "qotib qoldim" holatlaridan chiqishni o'rgatadi. Keyingi darslarda (`sudoers`, systemd unit, YAML manifestlar) barcha tahrirlar shu ko'nikmaga tayanadi.

Taxminiy vaqt: 2–3 kun (siz uchun). VS Code odatlari bu yerda xalaqit beradi, shuning uchun vaqtning ko'pi mashqqa ketadi. E'tiborni quyidagilarga qarating: Normal rejim asosiy rejim ekani, `operator + count + motion` grammatikasi, `.` bilan takrorlash, `:%s` va `:g`, visual block, swap fayl va readonly xatolari, `sudoedit`.

## Laboratoriya

- **`lab` VM**: barcha vazifalar. `multipass start lab && multipass shell lab`. VM'da `vim` va `nano` o'rnatilgan; tekshirish: `vim --version | head -1`. Yo'q bo'lsa: `sudo apt update && sudo apt install -y vim nano`.
- Tizim fayllarining o'zi emas, nusxasi tahrirlanadi: `cp /etc/ssh/sshd_config ~/edit/`. Yagona istisno 16-vazifa (`/etc/hosts`, `sudoedit` orqali), undan oldin `clean` snapshot mavjudligini tekshiring.
- **Docker konteyner**: 18-vazifa uchun `docker run --rm -it ubuntu:24.04 bash`.
- Ish mashinangizda to'liq Vim yo'q, `vi` bu `vim.tiny`. Uni o'rnatish shart emas, mashqlar VM'da.

Tozalash: VM'da `rm -r ~/edit`, 14-vazifadagi `~/.vimrc` ni qoldirishingiz mumkin. `multipass stop lab`.

---

## 1. Nima uchun terminal muharriri

Ko'p buyruqlar o'zi muharrir ochadi va qaysi birini ochishni muhit o'zgaruvchisidan oladi:

| Qayerda | Qaysi muharrir |
|---------|----------------|
| `git commit`, `crontab -e`, `systemctl edit`, `kubectl edit` | `$VISUAL`, bo'lmasa `$EDITOR`, bo'lmasa tizim standarti |
| `visudo`, `sudoedit` | `$SUDO_EDITOR`, `$VISUAL`, `$EDITOR`, bo'lmasa tizim standarti |
| Debian oilasida tizim standarti | `/usr/bin/editor` symlink'i, `update-alternatives --config editor` bilan o'zgartiriladi |

```
export EDITOR=vim            # for the current session; put it in ~/.profile to persist
EDITOR=nano crontab -e       # for one command only
```

Minimal tizimlarda `vi` to'liq Vim emas: Ubuntu'da `vim.tiny` (syntax highlighting, visual block va ko'p qulayliklar yo'q), Alpine va BusyBox'da undan ham soddasi. Shuning uchun asosiy harakatlar plugin va sozlamalarsiz ham qo'lda bo'lishi kerak.

## 2. Nano

Nano rejimsiz muharrir: yozgan narsangiz darhol matnga tushadi. Pastki ikki qatorda yorliqlar turadi: `^` bu `Ctrl`, `M-` bu `Alt`.

| Klavish | Nima qiladi |
|---------|-------------|
| `Ctrl+O`, `Enter` | saqlash (Write Out) |
| `Ctrl+X` | chiqish (o'zgarish bo'lsa so'raydi) |
| `Ctrl+W` | qidirish, `Alt+W` keyingi topilma |
| `Ctrl+\` | qidirib almashtirish |
| `Ctrl+K`, `Ctrl+U` | qatorni kesish, qo'yish |
| `Alt+A`, keyin `Alt+6` | belgilashni boshlash, nusxa olish |
| `Ctrl+_` | qator raqamiga o'tish |
| `Alt+U`, `Alt+E` | undo, redo |
| `Alt+N` | qator raqamlarini yoqish va o'chirish |
| `Ctrl+G` | yordam |

- `nano +42 fayl` 42-qatorda ochadi, `nano -l fayl` qator raqamlari bilan.
- Sozlamalar: `~/.nanorc` (tizim bo'yicha `/etc/nanorc`). Foydali uchtasi: `set linenumbers`, `set tabsize 2`, `set tabstospaces`.

**Tuzoq: terminalda `Ctrl+S`.** Ko'p terminallarda `Ctrl+S` chiqishni muzlatadi (XOFF), ekran qotib qolgandek ko'rinadi. `Ctrl+Q` davom ettiradi. Bu muharrirga emas, terminalga tegishli va Vim'da ham uchraydi.

## 3. Vim: rejimlar

Vim'da klaviatura ikki xil ishlaydi: matn yozish va matn ustida buyruq berish. Asosiy rejim Normal: Vim'da vaqtning ko'pi yozishga emas, yurish va o'zgartirishga ketadi.

| Rejim | Nima uchun | Qanday kiriladi | Chiqish |
|-------|------------|-----------------|---------|
| Normal | harakatlanish, buyruqlar | Vim shu rejimda ochiladi | |
| Insert | matn yozish | `i`, `a`, `o`, `I`, `A`, `O` | `Esc` |
| Visual | belgilash | `v` (belgi), `V` (qator), `Ctrl+v` (blok) | `Esc` |
| Command-line | `:` buyruqlari, qidiruv | `:`, `/`, `?` | `Enter` yoki `Esc` |

| Insert'ga kirish | Qayerdan yozadi |
|------------------|-----------------|
| `i`, `a` | kursor oldidan, kursordan keyin |
| `I`, `A` | qator boshidan, qator oxiridan |
| `o`, `O` | pastda, yuqorida yangi qator ochib |

Qaysi rejimda ekaningizni bilmasangiz: `Esc` ni ikki marta bosing, Normal'dasiz. Pastki chapda `-- INSERT --` yoki `-- VISUAL --` yozuvi rejimni ko'rsatadi.

### Saqlash va chiqish

| Buyruq | Nima qiladi |
|--------|-------------|
| `:w` | saqlash |
| `:q` | chiqish (o'zgarish bo'lsa rad etadi: `E37: No write since last change`) |
| `:q!` | saqlamasdan chiqish |
| `:wq`, `:x`, `ZZ` | saqlab chiqish (`:x` va `ZZ` faqat o'zgarish bo'lsa yozadi) |
| `:e!` | fayl diskdagi holatiga qaytariladi |
| `:w boshqa.txt` | boshqa nom bilan yozish |

## 4. Harakatlanish (motions)

| Harakat | Qayerga |
|---------|---------|
| `h` `j` `k` `l` | chap, past, yuqori, o'ng |
| `w`, `b`, `e` | keyingi so'z boshi, oldingi so'z boshi, so'z oxiri |
| `0`, `^`, `$` | qator boshi, birinchi bo'sh bo'lmagan belgi, qator oxiri |
| `gg`, `G` | fayl boshi, fayl oxiri |
| `42G` yoki `:42` | 42-qator |
| `Ctrl+d`, `Ctrl+u` | yarim ekran pastga, yuqoriga |
| `f{belgi}`, `t{belgi}` | qatordagi keyingi belgiga, undan bitta oldinga; `;` takrorlaydi |
| `%` | juft qavsga |
| `{`, `}` | oldingi, keyingi bo'sh qatorga (paragraf) |

Har harakat oldiga son yoziladi: `5j` besh qator pastga, `3w` uch so'z oldinga.

## 5. Tahrirlash grammatikasi

Vim buyruqlari gap kabi tuziladi: **operator + [son] + harakat**. Operatorlar va harakatlar alohida yodlanadi, keyin erkin birlashtiriladi.

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

- Operator ikki marta yozilsa butun qatorga ta'sir qiladi: `dd`, `cc`, `yy`, `>>`. Son bilan: `3dd`.
- `p` kursordan keyin, `P` kursordan oldin qo'yadi. `d` bilan o'chirilgan narsa ham xotiraga tushadi, ya'ni `dd` va `p` bu "kesib qo'yish".
- `x` bitta belgini o'chiradi, `r{belgi}` bitta belgini almashtiradi, `J` keyingi qatorni joriy qatorga ulaydi.
- `u` undo, `Ctrl+r` redo.
- `.` oxirgi o'zgartirishni takrorlaydi. Vim'ning eng foydali klavishi: bir marta `cw yangi Esc` qilasiz, keyin `n` va `.` bilan qolganlarini.

### Text object'lar

Operator'dan keyin harakat o'rniga "obyekt" berish mumkin: `i` (inner, ichi) yoki `a` (around, atrofi bilan) va obyekt turi. Kursor obyekt ichida istalgan joyda bo'lishi mumkin.

| Buyruq | Nima qiladi |
|--------|-------------|
| `ciw` | kursor ostidagi so'zni almashtirish |
| `ci"`, `ci'` | tirnoq ichidagini almashtirish |
| `di(`, `da(` | qavs ichini, qavslari bilan birga o'chirish |
| `dap` | paragrafni o'chirish |
| `yi{` | figurali qavs ichini nusxalash |

Konfiguratsiya faylida `key = "old value"` qatorida `ci"` bitta harakat bilan qiymatni almashtirishga tayyorlaydi.

## 6. Qidirish va almashtirish

| Buyruq | Nima qiladi |
|--------|-------------|
| `/pattern`, `?pattern` | oldinga, orqaga qidirish |
| `n`, `N` | keyingi, oldingi topilma |
| `*`, `#` | kursor ostidagi so'zni oldinga, orqaga qidirish |
| `:noh` | yoritishni vaqtincha o'chirish |
| `/pattern\c` | registrga qaramasdan |

Almashtirish: `:[oraliq]s/pattern/almashtirish/[flaglar]`.

```
:s/foo/bar/          first match on the current line
:s/foo/bar/g         all matches on the current line
:%s/foo/bar/g        whole file
:%s/foo/bar/gc       whole file, confirm each one
:10,20s/foo/bar/g    lines 10 to 20
:%s/\<foo\>/bar/g    whole word only
:%s#/var/www#/srv#g  another delimiter when the pattern contains slashes
```

- `%` butun fayl degani. `g` bo'lmasa har qatorda faqat birinchi topilma almashadi.
- Visual rejimda qatorlarni belgilab `:` bossangiz oraliq avtomatik qo'yiladi (`:'<,'>`).

### :g buyrug'i

`:g/pattern/buyruq` pattern mos kelgan har qatorda buyruqni bajaradi, `:v/pattern/buyruq` mos kelmaganlarida.

```
:g/^#/d              delete all comment lines
:g/^$/d              delete all empty lines
:v/error/d           keep only lines containing "error"
```

## 7. Visual rejim va blok tahrirlash

- `v` belgilar, `V` butun qatorlar, `Ctrl+v` to'rtburchak blok. Belgilab bo'lgach operator: `d`, `y`, `c`, `>`, `<`.
- Bir nechta qatorni komment qilish: `Ctrl+v` bilan birinchi ustunni pastga belgilang, `I`, `#` yozing, `Esc`. Belgi barcha belgilangan qatorlarga qo'yiladi.
- Kommentni olib tashlash: `Ctrl+v` bilan `#` ustunini belgilang, `d`.
- `gv` oxirgi belgilashni qayta tiklaydi.

### Tashqi buyruqlar va fayllar

| Buyruq | Nima qiladi |
|--------|-------------|
| `:r fayl`, `:r !date` | fayl mazmunini, buyruq chiqishini kursor ostiga qo'shadi |
| `:!ls -l` | muharrirdan chiqmasdan shell buyrug'i |
| `:e fayl` | boshqa faylni ochish |
| `:sp`, `:vsp` | oynani gorizontal, vertikal bo'lish; `Ctrl+w w` oynalar orasida |
| `vim +42 fayl` | 42-qatorda ochish |
| `vim -d a b` (`vimdiff`) | ikki faylni yonma-yon solishtirish |
| `view fayl` | faqat o'qish rejimida ochish |

## 8. Minimal .vimrc

Sozlamalar `~/.vimrc` da. Server uchun maqsad qulaylik emas, xatoni kamaytirish: qator raqami, to'g'ri chekinish, ko'rinadigan qidiruv.

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

- Sozlamani faqat joriy sessiyada sinash: `:set number`, o'chirish: `:set nonumber`, qiymatni ko'rish: `:set tabstop?`.
- `:set list` ko'rinmas belgilarni ko'rsatadi (tab `^I`, qator oxiri `$`), `:set nolist` o'chiradi. `:retab` mavjud tab'larni `expandtab` sozlamasiga ko'ra bo'shliqqa aylantiradi.
- `.vimrc` siz ishga tushirish (toza serverdagi holatni ko'rish uchun): `vim -u NONE fayl`.

**Tuzoq: YAML va tab.** YAML'da chekinish uchun tab taqiqlangan, Makefile'da esa aksincha tab majburiy. Ko'zga bir xil ko'rinadi. YAML tahrirlaganda `:set list` bilan tekshiring. `expandtab` yoqilgan holda haqiqiy tab kiritish: Insert rejimida `Ctrl+v`, keyin `Tab`.

## 9. Serverda omon qolish

| Holat | Belgisi | Yechim |
|-------|---------|--------|
| Chiqa olmayapman | har xil harflar yozilyapti | `Esc Esc`, keyin `:q!` |
| O'zgarish bor, chiqmayapti | `E37: No write since last change` | `:wq` yoki `:q!` |
| Fayl faqat o'qish uchun | `E45: 'readonly' option is set` | huquq yo'q: `:q!`, keyin `sudoedit fayl` |
| Yozib bo'lmayapti | `E212: Can't open file for writing` | papkaga yoki faylga yozish huquqi yo'q; `:w /tmp/nusxa` bilan ishni saqlab chiqing |
| Swap fayl topildi | `E325: ATTENTION` | pastda o'qing |
| Ekran qotdi | hech narsa javob bermaydi | `Ctrl+Q` (avval `Ctrl+S` bosilgan) |
| Vim yo'qoldi, prompt chiqdi | `[1]+ Stopped` | `Ctrl+Z` bosilgan; `fg` qaytaradi |
| Pastda `recording @q` | makro yozilyapti | `q` to'xtatadi |
| Hamma narsa katta harfda buyruq bo'lyapti | | Caps Lock yoqilgan |

### Swap fayl

Vim tahrirlash paytida fayl yonida `.fayl.swp` yaratadi: saqlanmagan o'zgarishlar shu yerda. Ikki holatda `E325` chiqadi: fayl hozir boshqa sessiyada ochiq, yoki oldingi sessiya saqlamasdan uzilgan (ssh uzilishi, `kill`).

- Xabardagi `process ID` va `(STILL RUNNING)` yozuviga qarang. Jarayon tirik bo'lsa fayl boshqa joyda ochiq: `Q` (Quit) va o'sha sessiyani toping.
- Jarayon yo'q bo'lsa: `R` (Recover) bilan tiklang, `:w` qiling, chiqing va swap faylni o'chiring. Aks holda xabar har safar chiqadi.
- Terminaldan tiklash: `vim -r fayl`.

### sudoedit

Root'ga tegishli faylni `sudo vim fayl` bilan ochmang: butun muharrir root sifatida ishlaydi (`:!sh` root shell beradi, plugin'lar root bilan bajariladi). To'g'ri usul: `sudoedit fayl` (yoki `sudo -e fayl`). U faylning vaqtinchalik nusxasini sizning nomingizdan, sizning muharrir va sozlamalaringiz bilan ochadi, saqlaganingizdan keyin root huquqi bilan joyiga qo'yadi.

`/etc/sudoers` uchun faqat `visudo` (5-darsda), u saqlashdan oldin sintaksisni tekshiradi.

### Muharrir umuman yo'q bo'lsa

Minimal konteynerda `vi` ham, `nano` ham bo'lmasligi mumkin. Variantlar: `cat > fayl <<'EOF'` (here-document, 5-darsda), `sed -i` (7-darsda), `echo "qator" >> fayl`, yoki faylni tashqarida tahrirlab `docker cp` bilan kiritish. Production konteyneriga muharrir o'rnatish odatda noto'g'ri yo'l: konteyner o'zgarmas bo'lishi kerak, tuzatish image yoki konfiguratsiyaga kiritiladi.

## Tuzoqlar

- Production konfiguratsiyasini nusxa olmasdan tahrirlash. Avval `cp -a fayl fayl.bak`, yaxshisi konfiguratsiya git'da yoki Ansible'da.
- `sudo vim /etc/...` odati. `sudoedit` ishlating, `sudoers` uchun `visudo`.
- Saqlagandan keyin tekshirmaslik. Ko'p servislarda sintaksis tekshiruvi bor: `sshd -t`, `nginx -t`, `visudo -c`. Tekshirmasdan restart qilingan servis ko'tarilmaydi, `sshd` bo'lsa serverga kira olmay qolasiz.
- Swap xabarida o'qimasdan `E` (Edit anyway) bosish: boshqa sessiyadagi o'zgarishlar bilan to'qnashuv, biri ikkinchisini ustidan yozadi.
- YAML'ga tab tushishi. Xato xabari odatda boshqa qatorni ko'rsatadi va topish qiyin. `:set list`.
- Terminalga ko'p qatorli matn qo'yganda `autoindent` chekinishni zinapoya qilib yuborishi mumkin (bracketed paste qo'llamaydigan terminal yoki eski Vim'da). Belgisi shu bo'lsa: `:set paste`, qo'ying, `:set nopaste`.
- `:wq` ni odat qilib, faqat o'qimoqchi bo'lgan faylni ham yozish (mtime o'zgaradi, monitoring yoki deploy vositasi "o'zgardi" deb o'ylaydi). Faqat ko'rish uchun `view` yoki `less`.
- `Ctrl+Z` bilan Vim'ni fonda unutib, faylni ikkinchi marta ochish. `jobs` bilan tekshiring.

## Manbalar

- https://vimhelp.org/usr_02.txt.html – Vim user manual, "The first steps in Vim"
- https://vimhelp.org/usr_04.txt.html – operatorlar, harakatlar, text object'lar
- https://vimhelp.org/usr_10.txt.html – katta o'zgartirishlar: `:s`, `:g`, visual block
- https://vimhelp.org/recover.txt.html – swap fayl va tiklash
- https://vimhelp.org/options.txt.html – barcha `set` sozlamalari
- https://www.nano-editor.org/dist/latest/nano.html – nano rasmiy qo'llanmasi
- https://www.nano-editor.org/dist/latest/nanorc.5.html – `nanorc(5)`
- https://www.sudo.ws/docs/man/sudo.man/ – `sudo(8)`, `-e` (sudoedit) bo'limi
- `vimtutor` buyrug'i – Vim bilan birga keladigan 30 daqiqalik interaktiv darslik
- Neil, "Practical Vim" (2-nashr) – 1–4 boblar (grammatika va `.` formulasi)

---

## Vazifalar

Ish papkasi: `linux/04-editors/` (`make new m=linux n=04 name=editors` bilan yarating). Javoblarni shu papkadagi `README.md` ga yozing: har vazifa uchun `## N. Title` sarlavhasi, ostida nima qilganingiz, **bosgan klavishlar ketma-ketligi**, xato xabarlari va o'z so'zingiz bilan izoh. So'ralgan fayllarni (`vimrc`, `nanorc`, `sshd_config.lab`) VM'dan `multipass transfer` bilan olib shu papkaga saqlang. Vazifalar `lab` VM'da, `~/edit` papkasida. Vim vazifalarida sichqoncha va strelkalarni ishlatmang.

### A. Nano

1. **Nano basics.** `cp /etc/services ~/edit/services` qiling va nano'da oching. `https` so'zini qidiring, 100-qatorga o'ting, bitta qatorni kesib fayl boshiga qo'ying, `tcp` ni `TCP` ga birinchi 5 ta topilmada almashtiring, undo bilan bittasini qaytaring, saqlang va chiqing. Har amal uchun klavishni yozing.

2. **Nano config.** `~/.nanorc` yarating: qator raqamlari, tab kengligi 2, tab o'rniga bo'shliq. Faylni qayta ochib `Tab` bosing va `cat -A` bilan tab emas bo'shliq yozilganini isbotlang. `/etc/nanorc` dan yana bitta foydali sozlamani topib qo'shing va nima qilishini yozing. Faylni ish papkasiga `nanorc` nomi bilan saqlang.

3. **Default editor.** `echo "$EDITOR" "$VISUAL"`, `ls -l /usr/bin/editor /etc/alternatives/editor` va `update-alternatives --display editor` natijasini yozing. `crontab -e` qaysi muharrirni ochdi (saqlamasdan chiqing)? `EDITOR=vim crontab -e` bilan qayta sinang. Sozlama doimiy bo'lishi uchun qayerga yozilishi kerak?

### B. Vim asoslari

4. **vimtutor.** `vimtutor` ni ishga tushirib 1–4 darslarni bajaring. Siz uchun yangi bo'lgan 5 ta buyruqni va har biri qaysi holatda foydali ekanini yozing.

5. **Modes and exit.** Faylni oching, matn qo'shing va chiqishning har bir usulini alohida sinang: `:q`, `:q!`, `:wq`, `:x`, `ZZ`. `:q` bergan xatoni yozing. `:wq` va `:x` farqini isbotlang: faylni o'zgartirmasdan har biri bilan chiqing va `stat` dagi mtime ni solishtiring.

6. **Motions drill.** `~/edit/services` da faqat harakat buyruqlari bilan: 250-qatorga, fayl oxiriga, fayl boshiga o'ting; qatorda uchinchi so'zga, qator oxiriga, birinchi bo'sh bo'lmagan belgiga; keyingi `/` belgisiga (`f`); 10 qator pastga; keyingi bo'sh qatorga. Har biri uchun klavishlarni yozing. `w` va `W` farqi nima (`ssh 22/tcp` qatorida sinang)?

7. **Operator grammar.** `~/edit/g.txt` ga 15–20 qatorli konfiguratsiyaga o'xshash matn yozing (`key = "value"` qatorlari, qavsli ro'yxat, ikkita paragraf). Har birini bitta buyruq bilan bajaring va klavishlarni yozing: 3 qatorni o'chirish, kursordan qator oxirigacha o'chirish, so'zni almashtirish, tirnoq ichidagi qiymatni almashtirish, qavs ichini o'chirish, paragrafni nusxalab fayl oxiriga qo'yish, ikki qatorni joylarini almashtirish.

8. **Dot and undo.** `g.txt` da 6 ta qator boshiga `# ` qo'shing: birinchisini `I` bilan, qolganlarini faqat `j` va `.` bilan. Keyin `u` bilan uchtasini qaytaring va `Ctrl+r` bilan ikkitasini tiklang. `.` aynan nimani takrorlaydi: oxirgi klavishnimi yoki oxirgi o'zgartirishnimi? Buni ko'rsatadigan tajriba qiling.

### C. Qidirish va almashtirish

9. **Search.** `~/edit/services` da: `ssh` ni qidiring va `n` bilan barcha topilmalarni aylaning; kursor ostidagi so'zni `*` bilan qidiring; `SSH` ni registrga qaramasdan toping; `:set hlsearch` va `:noh` farqini ko'ring. Mavjud bo'lmagan so'zni qidirganda chiqqan xatoni yozing.

10. **Substitute.** `~/edit/services` nusxasida: (a) butun faylda `tcp` ni `TCP` ga, (b) faqat 20–40 qatorlarda `udp` ni `UDP` ga, (c) butun so'z `www` ni (masalan `www-http` ichidagisini emas) `web` ga tasdiqlash bilan, (d) `/tcp` ni `/TCP` ga slash'dan boshqa ajratuvchi bilan almashtiring. Har buyruqni va pastda chiqqan "N substitutions on M lines" xabarini yozing. `g` flag'isiz nima o'zgaradi?

11. **Global command.** `cp /etc/ssh/sshd_config ~/edit/sshd_strip` qiling. Vim ichida barcha komment qatorlarini va barcha bo'sh qatorlarni o'chiring, nechta qator qolganini yozing. Natijani `grep -cvE '^(#|$)' /etc/ssh/sshd_config` soni bilan solishtiring. `:g` va `:v` farqini bitta misolda ko'rsating.

### D. Visual va chekinish

12. **Block edit.** `g.txt` da visual block bilan 8 ta ketma-ket qatorni komment qiling (`# ` qo'shing), keyin xuddi shu usulda kommentni olib tashlang. Xuddi shu ishni `:s` bilan oraliq berib bajaring. Qaysi usul qachon qulay?

13. **Tabs in YAML.** `printf 'app:\n\tname: web\n\tports:\n\t\t- 80\n' > ~/edit/bad.yaml` yarating. `python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' ~/edit/bad.yaml` xatosini yozing. Vim'da `:set list` bilan muammoni ko'ring, `expandtab` va `:retab` bilan tuzating, tekshiruvni qayta ishga tushiring. Keyin `ports` blokini `>` bilan bir daraja o'ngga suring va YAML ma'nosi qanday o'zgarganini izohlang.

### E. Sozlama

14. **Minimal vimrc.** O'zingizning `~/.vimrc` ni yozing: 15 qatordan oshmasin, har sozlama yonida nima uchun kerakligi haqida inglizcha komment. Har sozlamani avval `:set` bilan sinab ko'ring. `vim -u NONE fayl` bilan solishtirib, qaysi sozlamasiz ishlash eng qiyin ekanini yozing. Faylni ish papkasiga `vimrc` nomi bilan saqlang.

### F. Omon qolish

15. **Swap file.** Birinchi terminalda faylni Vim'da ochib o'zgartiring, saqlamang. Ikkinchi terminaldan o'sha faylni oching: xabarni to'liq o'qing, undagi PID va holatni yozing, `Q` bilan chiqing. Keyin ikkinchi terminaldan Vim jarayonini `kill -9` bilan o'ldiring, `ls -la` da swap faylni toping, faylni qayta ochib o'zgarishlarni tiklang, saqlang va swap faylni o'chiring. Ikki holatda (jarayon tirik va o'lik) to'g'ri harakat nima uchun farq qiladi?

16. **Read-only file.** `clean` snapshot borligini tekshiring. `vim /etc/hosts` ni `sudo` siz oching, qator qo'shing, `:w` va `:w!` xatolarini yozing, o'zgarishni `/tmp` ga saqlab chiqing. Keyin `sudoedit /etc/hosts` bilan `10.0.0.10 lab-db` qatorini qo'shing va `getent hosts lab-db` bilan tekshiring. `sudoedit` paytida ikkinchi terminalda `ps -ef | grep vim` qiling: muharrir kim nomidan ishlayapti? `sudo vim` dan farqi nima? Oxirida qo'shilgan qatorni olib tashlang.

17. **Frozen terminal.** Vim ichida `Ctrl+S` bosing, bir nechta klavish bosib ko'ring, keyin `Ctrl+Q`. Nima bo'ldi? Keyin `Ctrl+Z` bosing: Vim qayerga ketdi? `jobs` va `fg` bilan qaytaring. Normal rejimda `q` va `a` ni bosing, pastdagi yozuvni o'qing va bu holatdan chiqing.

18. **No editor at all.** `docker run --rm -it ubuntu:24.04 bash` ichida `vi`, `vim`, `nano` ni sinang. Muharrir o'rnatmasdan `/etc/motd` faylini uch qator bilan yarating, keyin o'rtadagi qatorni o'zgartiring (ikki xil usul toping). Shundan keyin `apt` bilan `vim-tiny` o'rnatib, `vi` da xuddi shu tahrirni bajaring. Production konteynerida muharrir o'rnatish nima uchun yomon amaliyot?

### G. Yakuniy

19. **Config edit.** `cp /etc/ssh/sshd_config ~/edit/sshd_config.lab` qiling va faqat Vim bilan (har qadam klavishlarini yozib): (a) `#Port 22` qatorini topib kommentdan chiqaring va `2222` ga o'zgartiring, (b) `PermitRootLogin` ni `no` qiling, (c) `PasswordAuthentication` ni `no` qiling, (d) faylning eng boshiga `# edited by <ismingiz> on <sana>` qatorini qo'shing, sanani `:r !date +\%F` orqali oling, (e) fayl oxiriga `AllowUsers ubuntu` qo'shing. Keyin `diff /etc/ssh/sshd_config ~/edit/sshd_config.lab` bilan faqat shu o'zgarishlar borligini, `sudo sshd -t -f ~/edit/sshd_config.lab` bilan sintaksis to'g'riligini tekshiring. Bitta kalit so'zni ataylab buzib `sshd -t` xatosini o'qing va tuzating. Faylni ish papkasiga saqlang. Haqiqiy `/etc/ssh/sshd_config` ga tegmang.

20. **Speed run.** 19-vazifani toza nusxada qayta bajaring va vaqtni o'lchang. Qaysi qadamlarda sekinlashdingiz, qaysi buyruqlar bilan qisqartirish mumkin edi (masalan qidiruv + `cw` + `n` + `.`)? Yakuniy klavishlar ro'yxatini birinchi urinishdagi bilan solishtirib yozing.

### Topshirish

Tayyor bo'lgach:
1. `linux/04-editors/README.md` da 20 ta vazifa `## N. Title` sarlavhalari ostida, klavishlar ketma-ketligi bilan.
2. Ish papkasida `nanorc`, `vimrc`, `sshd_config.lab` fayllari bor.
3. `make check` toza o'tadi.
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
