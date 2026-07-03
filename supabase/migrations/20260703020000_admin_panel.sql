-- Panel administratora: prywatna rola administratora i rejestrowanie aktywności użytkowników.
-- Uruchom ten plik jeden raz w SQL Editor właściwego projektu Supabase.

create table if not exists public.admin_users (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.user_activity (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_seen_at timestamptz not null default now()
);

create index if not exists user_activity_last_seen_idx
on public.user_activity(last_seen_at desc);

alter table public.admin_users enable row level security;
alter table public.user_activity enable row level security;

revoke all on public.admin_users from public, anon, authenticated;
revoke all on public.user_activity from public, anon, authenticated;
grant all on public.admin_users to service_role;
grant all on public.user_activity to service_role;
grant execute on function public.issue_member_invite(interval) to service_role;


do $$
declare
  v_admin_id uuid;
begin
  select id into v_admin_id
  from public.profiles
  where member_code = 'OSOBA-1713FD05';

  if v_admin_id is null then
    raise exception 'Nie znaleziono konta administratora: OSOBA-1713FD05';
  end if;

  delete from public.admin_users;
  insert into public.admin_users (user_id) values (v_admin_id);
end $$;

notify pgrst, 'reload schema';
