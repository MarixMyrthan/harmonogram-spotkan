# Krótka instrukcja administratora

## Dodanie nowej osoby

W Supabase otwórz **SQL Editor** i uruchom:

```sql
select * from public.issue_member_invite();
```

Otrzymasz:

- `member_code` – stały kod uczestnika, używany po aktywacji;
- `activation_code` – jednorazowy kod do pierwszego wejścia;
- `expires_at` – termin ważności zaproszenia.

Nowej osobie przekaż wyłącznie `activation_code`. Po aktywacji strona pokaże jej stały kod uczestnika.

Kod z innym terminem ważności:

```sql
select * from public.issue_member_invite(interval '7 days');
```

## Lista uczestników

```sql
select id, display_name, member_code, is_active, created_at
from public.profiles
order by display_name;
```

## Zablokowanie uczestnika

```sql
update public.profiles
set is_active = false
where member_code = 'OSOBA-XXXXXXXX';
```

Zablokowana osoba może nadal posiadać sesję Auth, ale zasady RLS nie pozwolą jej odczytywać ani zmieniać danych.

## Odblokowanie uczestnika

```sql
update public.profiles
set is_active = true
where member_code = 'OSOBA-XXXXXXXX';
```

## Usunięcie konta

Najbezpieczniej usuwać użytkownika w Supabase: **Authentication → Users**. Najpierw ustal jego `id` za pomocą zapytania z sekcji „Lista uczestników”. Profil i wszystkie jego terminy zostaną usunięte automatycznie przez `ON DELETE CASCADE`.

## Wygaszenie niewykorzystanego zaproszenia

```sql
update public.member_invites
set expires_at = now()
where member_code = 'OSOBA-XXXXXXXX' and consumed_at is null;
```
