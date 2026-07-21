-- Ostatnie urządzenie użytkownika, ochrona wybranych terminów oraz porządki danych.

alter table public.user_activity
  add column if not exists device_type text not null default 'unknown',
  add column if not exists operating_system text not null default 'unknown',
  add column if not exists browser text not null default 'unknown';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_activity'::regclass
      and conname = 'user_activity_device_type_check'
  ) then
    alter table public.user_activity
      add constraint user_activity_device_type_check
      check (device_type in ('computer', 'phone', 'tablet', 'unknown'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_activity'::regclass
      and conname = 'user_activity_operating_system_check'
  ) then
    alter table public.user_activity
      add constraint user_activity_operating_system_check
      check (operating_system in ('windows', 'android', 'apple', 'linux', 'unknown'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_activity'::regclass
      and conname = 'user_activity_browser_check'
  ) then
    alter table public.user_activity
      add constraint user_activity_browser_check
      check (browser in ('firefox', 'chrome', 'edge', 'safari', 'opera', 'brave', 'unknown'));
  end if;
end $$;

create table if not exists public.calendar_day_protections (
  day date primary key,
  protected_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_state (
  key text primary key,
  last_run_at timestamptz not null default to_timestamp(0)
);

alter table public.calendar_day_protections enable row level security;
alter table public.maintenance_state enable row level security;

revoke all on public.calendar_day_protections from public, anon, authenticated;
revoke all on public.maintenance_state from public, anon, authenticated;
grant all on public.calendar_day_protections to service_role;
grant all on public.maintenance_state to service_role;

drop trigger if exists calendar_day_protections_set_updated_at on public.calendar_day_protections;
create trigger calendar_day_protections_set_updated_at
before update on public.calendar_day_protections
for each row execute function public.set_updated_at();

create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_admin_user() from public;
grant execute on function public.is_admin_user() to authenticated;

-- Moduł pomysłów korzysta od teraz ze wspólnej listy administratorów.
drop policy if exists "meeting ideas admins can delete ideas" on public.meeting_ideas;
drop policy if exists "admins can delete meeting ideas" on public.meeting_ideas;
create policy "admins can delete meeting ideas"
on public.meeting_ideas for delete
to authenticated
using (public.is_active_member() and public.is_admin_user());

drop function if exists public.is_meeting_ideas_admin();
drop table if exists public.meeting_idea_admins;
drop function if exists public.cleanup_expired_meeting_ideas();

create or replace function public.count_chat_messages_older_than(p_days integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if p_days is null or p_days < 1 or p_days > 3650 then
    raise exception 'Liczba dni musi mieścić się w zakresie 1–3650';
  end if;

  select count(*)::integer
  into v_count
  from public.chat_messages
  where created_at < now() - make_interval(days => p_days);

  return v_count;
end;
$$;

create or replace function public.delete_chat_messages_older_than(p_days integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if p_days is null or p_days < 1 or p_days > 3650 then
    raise exception 'Liczba dni musi mieścić się w zakresie 1–3650';
  end if;

  delete from public.chat_messages
  where created_at < now() - make_interval(days => p_days);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.count_chat_messages_older_than(integer) from public, anon, authenticated;
revoke all on function public.delete_chat_messages_older_than(integer) from public, anon, authenticated;
grant execute on function public.count_chat_messages_older_than(integer) to service_role;
grant execute on function public.delete_chat_messages_older_than(integer) to service_role;

create or replace function public.run_daily_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_run timestamptz;
  v_availability integer := 0;
  v_events integer := 0;
  v_ideas integer := 0;
  v_invites integer := 0;
begin
  insert into public.maintenance_state (key, last_run_at)
  values ('daily_cleanup', to_timestamp(0))
  on conflict (key) do nothing;

  select last_run_at
  into v_last_run
  from public.maintenance_state
  where key = 'daily_cleanup'
  for update;

  if v_last_run >= date_trunc('day', now()) then
    return jsonb_build_object('ran', false, 'last_run_at', v_last_run);
  end if;

  delete from public.availability a
  where a.day <= current_date - 7
    and not exists (
      select 1
      from public.calendar_day_protections p
      where p.day = a.day
    );
  get diagnostics v_availability = row_count;

  delete from public.meeting_events
  where created_at < now() - interval '30 days';
  get diagnostics v_events = row_count;

  delete from public.meeting_ideas
  where day < current_date;
  get diagnostics v_ideas = row_count;

  delete from public.member_invites
  where (
      consumed_at is not null
      and consumed_at < now() - interval '5 days'
    ) or (
      consumed_at is null
      and expires_at < now() - interval '5 days'
    );
  get diagnostics v_invites = row_count;

  update public.maintenance_state
  set last_run_at = now()
  where key = 'daily_cleanup';

  return jsonb_build_object(
    'ran', true,
    'availability', v_availability,
    'meeting_events', v_events,
    'meeting_ideas', v_ideas,
    'member_invites', v_invites
  );
end;
$$;

revoke all on function public.run_daily_maintenance() from public, anon, authenticated;
grant execute on function public.run_daily_maintenance() to service_role;

notify pgrst, 'reload schema';
