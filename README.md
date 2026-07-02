# Harmonogram spotkań

Prywatny, wspólny kalendarz dla grupy planującej spotkania w prawdziwym życiu. Każdy uczestnik widzi terminy całej grupy, ale może zmieniać wyłącznie własne zaznaczenia, uwagi, propozycję miejsca i własną nazwę.

## Funkcje MVP

- miesięczny kalendarz działający na komputerze i telefonie;
- zaznaczenie dnia „pasuje mi”;
- osobne pole **Godziny / uwagi**, np. `po 18:00`;
- osobne pole **Miejsce / propozycja**, np. `Wrocław, Rynek`;
- podgląd osób dostępnych danego dnia;
- wyróżnienie dni pasujących wszystkim;
- pierwsze wejście przez jednorazowy kod aktywacyjny;
- własny 6-cyfrowy PIN i stały kod uczestnika;
- zmiana nazwy i PIN-u przez użytkownika;
- aktualizacje na żywo przez Supabase Realtime;
- Row Level Security: odczyt całej grupy, zapis tylko własnych rekordów;
- automatyczne wdrożenie na GitHub Pages.

## Architektura

- React + TypeScript + Vite – interfejs;
- Supabase Auth – PIN przechowywany jak hasło, bez jawnego zapisu w tabelach;
- Supabase PostgreSQL + RLS – profile, terminy, uwagi i miejsca;
- Supabase Edge Function – bezpieczna aktywacja konta;
- GitHub Pages – hosting statycznej aplikacji.

## 1. Uruchomienie Supabase

1. Utwórz **osobny projekt** w Supabase, niezależny od harmonogramu grania.
2. W **SQL Editor** wklej i uruchom cały plik:
   `supabase/migrations/20260702010000_initial.sql`.
3. W **Authentication → Configuration** wyłącz `Allow new users to sign up`.
4. Dostawca e-mail/hasło musi pozostać włączony. Techniczny adres e-mail powstaje automatycznie z kodu uczestnika i nie jest pokazywany użytkownikowi.

## 2. Wdrożenie funkcji aktywacyjnej

### Przez Supabase Dashboard

1. Wejdź w **Edge Functions → Deploy a new function → Via Editor**.
2. Wklej zawartość pliku `supabase/functions/activate-member/index.ts`.
3. Nazwij funkcję dokładnie `activate-member`.
4. Wdróż funkcję.
5. W jej ustawieniach wyłącz **Verify JWT with legacy secret** i zapisz zmianę.

### Alternatywnie przez CLI

```bash
supabase login
supabase link --project-ref TWOJ_PROJECT_REF
supabase functions deploy activate-member --no-verify-jwt
```

Nie dodawaj secret/service-role key do `.env`, repozytorium ani zmiennych `VITE_*`.

## 3. Konfiguracja lokalna

Windows PowerShell:

```powershell
Copy-Item .env.example .env
npm.cmd install
npm.cmd run dev
```

Uzupełnij `.env`:

```env
VITE_SUPABASE_URL=https://TWOJ_PROJECT_REF.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_TWOJ_KLUCZ
```

Klucz publishable może znajdować się w aplikacji przeglądarkowej, ponieważ właściwe uprawnienia wymusza RLS. Sekretny klucz nie może trafić do przeglądarki.

## 4. Utworzenie pierwszych zaproszeń

W Supabase SQL Editor uruchom osobno dla każdej osoby:

```sql
select * from public.issue_member_invite();
```

Przekaż osobie wyłącznie wartość `activation_code`. Przy pierwszym wejściu poda nazwę i ustawi własny PIN. Po aktywacji otrzyma stały `member_code` zaczynający się od `OSOBA-`.

Dalsze operacje administratora opisuje plik [ADMIN.md](ADMIN.md).

## 5. Wdrożenie na GitHub Pages

1. Utwórz repozytorium, np. `harmonogram-spotkan`, i wypchnij projekt na gałąź `main`.
2. W GitHubie przejdź do **Settings → Secrets and variables → Actions → Variables**.
3. Dodaj zmienne:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
4. Przejdź do **Settings → Pages** i jako źródło wybierz **GitHub Actions**.
5. Uruchom workflow **Deploy to GitHub Pages**.

Konfiguracja Vite automatycznie wykrywa nazwę repozytorium i ustawia właściwą ścieżkę dla adresu w rodzaju:

```text
https://uzytkownik.github.io/harmonogram-spotkan/
```

## Test przed publikacją

```powershell
npm.cmd run typecheck
npm.cmd run build
```

Sprawdź w dwóch oddzielnych przeglądarkach lub profilach:

1. aktywację dwóch kont;
2. widoczność terminów obu osób;
3. zapis godzin i miejsca;
4. edycję własnego wpisu;
5. brak możliwości modyfikowania wpisu drugiej osoby;
6. zmianę nazwy i PIN-u;
7. odświeżanie kalendarza na żywo.

## Ważne uwagi bezpieczeństwa

- PIN ma dokładnie 6 cyfr. Kod uczestnika jest dodatkową, losową częścią danych logowania.
- Nie umieszczaj secret/service-role key w repozytorium ani w zmiennych `VITE_*`.
- RLS jest obowiązkowy; nie wyłączaj go na tabelach `profiles` i `availability`.
- Projekt jest przeznaczony dla niewielkiej, prywatnej grupy.
