---
name: task-done
description: Qabul qilingan (✓) vazifani alohida commit qilib push qiladi. Tekshiruvda vazifa ✓ bo'lgach avtomatik chaqiriladi, yoki qo'lda `/task-done <modul-yo'li> <N>`.
---

# task-done

Har bir qabul qilingan vazifa uchun bitta commit, keyin push. Bir tekshiruvda bir nechta vazifa qabul qilinsa, har biriga alohida commit, raqam tartibida.

## Kirish ma'lumotlari

- Modul yo'li: masalan `linux/03-basic-commands`, `docker/02-images`, `kubernetes/06-services`.
- Vazifa raqami `N` va inglizcha sarlavhasi. Sarlavha modul `docs/PROGRESS.md` dagi `N. Title` qatoridan olinadi, o'zgartirilmaydi.
- Argument berilmasa, shu suhbatda oxirgi marta ✓ qilingan vazifa(lar) olinadi.

## Shartlar

1. Vazifa modul progress faylida `[x]` bo'lishi shart. `[!]` yoki `[~]` bo'lsa commit qilinmaydi.
2. `make check` toza bo'lishi kerak (o'rnatilmagan linter "o'tkazib yuborildi" deb chiqsa bu xato emas). Toza bo'lmasa to'xta va sababini ayt.
3. `make secrets` toza bo'lishi kerak. Stage qilinayotgan fayllarda kalit, token, parol, `.env`, `*.tfstate`, kubeconfig bo'lsa commit qilinmaydi, foydalanuvchiga aytiladi.

## Qadamlar

1. `git status --short` bilan o'zgargan fayllarni ko'r.
2. Faqat shu vazifaga tegishli fayllarni stage qil:
   - ish papkasidagi vazifa fayllari (`task_N.sh`, `Dockerfile`, manifest va shu kabi);
   - ish papkasidagi `README.md` (shu vazifa bo'limi);
   - modul progress fayli va ildiz `PROGRESS.md`.
   `README.md` (ildiz), `ROADMAP.md`, `*/docs/*.md` kabi darsga oid fayllar bu commitga kirmaydi, ular alohida commit qilinadi.
3. Bir nechta vazifa bir vaqtda commit qilinsa, ish papkasidagi `README.md` ni har commitda faqat o'sha vazifagacha bo'lgan holatda stage qil (`git hash-object -w` + `git update-index --cacheinfo`), ishchi daraxtga tegma.
4. Commit xabari, aynan shu ko'rinishda:

   ```
   task-done: <modul-yo'li> <N>. <Title>
   ```

   Masalan: `task-done: linux/03-basic-commands 4. Hidden files`. Sessiyada belgilangan attribution qatorlari (Co-Authored-By) xabar oxiriga qo'shiladi.
5. `git push origin <joriy branch>`. Remote sozlanmagan bo'lsa push o'tkazib yuboriladi va bu hisobotda aytiladi.
6. Hisobotda commit hash va push natijasini ayt. Push o'tmasa (auth, network) commit saqlanib qoladi, foydalanuvchiga `git push` ni o'zi ishlatishini ayt.
