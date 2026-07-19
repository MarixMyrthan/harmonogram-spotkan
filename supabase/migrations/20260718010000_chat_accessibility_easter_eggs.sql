-- Czat grupowy, tryb daltonisty per użytkownik i zdarzenia JACKPOT.
-- Uruchom jeden raz w SQL Editor przed publikacją nowej wersji aplikacji.

alter table public.profiles
  add column if not exists colorblind_mode boolean not null default false;

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (char_length(btrim(message)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_created_at_idx
on public.chat_messages(created_at desc);

create table if not exists public.meeting_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('jackpot')),
  day date not null,
  created_at timestamptz not null default now()
);

create index if not exists meeting_events_created_at_idx
on public.meeting_events(created_at desc);

alter table public.chat_messages enable row level security;
alter table public.meeting_events enable row level security;

revoke all on public.chat_messages from public, anon, authenticated;
revoke all on public.meeting_events from public, anon, authenticated;

grant select, insert on public.chat_messages to authenticated;
grant select on public.meeting_events to authenticated;

drop policy if exists "active members can read chat" on public.chat_messages;
drop policy if exists "active members can send chat messages" on public.chat_messages;
drop policy if exists "active members can read meeting events" on public.meeting_events;

create policy "active members can read chat"
on public.chat_messages for select
to authenticated
using (public.is_active_member());

create policy "active members can send chat messages"
on public.chat_messages for insert
to authenticated
with check (
  public.is_active_member()
  and user_id = auth.uid()
  and char_length(btrim(message)) between 1 and 500
);

create policy "active members can read meeting events"
on public.meeting_events for select
to authenticated
using (public.is_active_member());

create or replace function public.emit_jackpot_when_everyone_available()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_new_available_count integer;
  v_old_available_count integer;
begin
  select count(*)
  into v_active_count
  from public.profiles
  where is_active = true;

  if v_active_count = 0 then
    return new;
  end if;

  select count(*)
  into v_new_available_count
  from public.availability a
  join public.profiles p on p.id = a.user_id and p.is_active = true
  where a.day = new.day
    and a.status = 'available';

  if tg_op = 'INSERT' then
    v_old_available_count := v_new_available_count
      - case when new.status = 'available' then 1 else 0 end;
  else
    v_old_available_count := v_new_available_count
      - case when new.status = 'available' then 1 else 0 end
      + case when old.status = 'available' then 1 else 0 end;
  end if;

  if v_new_available_count = v_active_count
     and v_old_available_count <> v_active_count then
    insert into public.meeting_events (event_type, day)
    values ('jackpot', new.day);
  end if;

  return new;
end;
$$;

revoke all on function public.emit_jackpot_when_everyone_available() from public, anon, authenticated;

drop trigger if exists availability_emit_jackpot on public.availability;
create trigger availability_emit_jackpot
after insert or update of status on public.availability
for each row execute function public.emit_jackpot_when_everyone_available();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'meeting_events'
  ) then
    alter publication supabase_realtime add table public.meeting_events;
  end if;
end $$;

notify pgrst, 'reload schema';
