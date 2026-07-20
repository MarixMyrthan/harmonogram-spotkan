-- Pomysły i głosowanie dla Harmonogramu spotkań

create table if not exists public.meeting_ideas (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  title text not null check (char_length(btrim(title)) between 2 and 100),
  created_at timestamptz not null default now()
);

create unique index if not exists meeting_ideas_unique_title_day_idx
on public.meeting_ideas (day, lower(btrim(title)));

create index if not exists meeting_ideas_day_created_idx
on public.meeting_ideas (day, created_at);

create table if not exists public.meeting_idea_votes (
  idea_id uuid not null references public.meeting_ideas(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  vote text not null check (vote in ('up', 'down')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (idea_id, user_id)
);

create index if not exists meeting_idea_votes_vote_idx
on public.meeting_idea_votes (idea_id, vote);

-- Osobna, niedostępna publicznie lista administratorów modułu.
create table if not exists public.meeting_idea_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade
);

insert into public.meeting_idea_admins (user_id)
select id
from public.profiles
where member_code = 'OSOBA-1713FD05'
on conflict (user_id) do nothing;

revoke all on public.meeting_idea_admins from public, anon, authenticated;

create or replace function public.is_meeting_ideas_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meeting_idea_admins
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_meeting_ideas_admin() from public;
grant execute on function public.is_meeting_ideas_admin() to authenticated;

create or replace function public.is_candidate_meeting_day(p_day date)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_day >= current_date
    and (select count(*) from public.profiles where is_active = true) > 0
    and (
      select count(distinct availability.user_id)
      from public.availability
      join public.profiles on profiles.id = availability.user_id
      where availability.day = p_day
        and profiles.is_active = true
    ) = (
      select count(*)
      from public.profiles
      where is_active = true
    )
    and not exists (
      select 1
      from public.availability
      join public.profiles on profiles.id = availability.user_id
      where availability.day = p_day
        and profiles.is_active = true
        and availability.status = 'unavailable'
    );
$$;

revoke all on function public.is_candidate_meeting_day(date) from public;
grant execute on function public.is_candidate_meeting_day(date) to authenticated;

create or replace function public.touch_meeting_idea_vote_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists meeting_idea_votes_touch_updated_at on public.meeting_idea_votes;
create trigger meeting_idea_votes_touch_updated_at
before update on public.meeting_idea_votes
for each row
execute function public.touch_meeting_idea_vote_updated_at();

create or replace function public.remove_rejected_meeting_idea()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*)
    from public.meeting_idea_votes
    where idea_id = new.idea_id
      and vote = 'down'
  ) >= 3 then
    delete from public.meeting_ideas where id = new.idea_id;
  end if;

  return new;
end;
$$;

revoke all on function public.remove_rejected_meeting_idea() from public;

drop trigger if exists meeting_idea_vote_rejection_threshold on public.meeting_idea_votes;
create trigger meeting_idea_vote_rejection_threshold
after insert or update of vote on public.meeting_idea_votes
for each row
execute function public.remove_rejected_meeting_idea();

create or replace function public.cleanup_expired_meeting_ideas()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed_count integer;
begin
  if not public.is_active_member() then
    raise exception 'Brak dostępu';
  end if;

  delete from public.meeting_ideas
  where day < current_date;

  get diagnostics removed_count = row_count;
  return removed_count;
end;
$$;

revoke all on function public.cleanup_expired_meeting_ideas() from public;
grant execute on function public.cleanup_expired_meeting_ideas() to authenticated;

alter table public.meeting_ideas enable row level security;
alter table public.meeting_idea_votes enable row level security;

revoke all on public.meeting_ideas from public, anon, authenticated;
revoke all on public.meeting_idea_votes from public, anon, authenticated;

grant select, insert, delete on public.meeting_ideas to authenticated;
grant select, insert, update, delete on public.meeting_idea_votes to authenticated;

drop policy if exists "active members can read meeting ideas" on public.meeting_ideas;
create policy "active members can read meeting ideas"
on public.meeting_ideas for select
to authenticated
using (public.is_active_member());

drop policy if exists "active members can add meeting ideas" on public.meeting_ideas;
create policy "active members can add meeting ideas"
on public.meeting_ideas for insert
to authenticated
with check (
  public.is_active_member()
  and author_id = auth.uid()
  and title = btrim(title)
  and public.is_candidate_meeting_day(day)
);

drop policy if exists "meeting ideas admins can delete ideas" on public.meeting_ideas;
create policy "meeting ideas admins can delete ideas"
on public.meeting_ideas for delete
to authenticated
using (public.is_active_member() and public.is_meeting_ideas_admin());

drop policy if exists "active members can read idea votes" on public.meeting_idea_votes;
create policy "active members can read idea votes"
on public.meeting_idea_votes for select
to authenticated
using (public.is_active_member());

drop policy if exists "members can add their own idea vote" on public.meeting_idea_votes;
create policy "members can add their own idea vote"
on public.meeting_idea_votes for insert
to authenticated
with check (
  public.is_active_member()
  and user_id = auth.uid()
  and exists (
    select 1
    from public.meeting_ideas
    where id = idea_id
      and day >= current_date
  )
);

drop policy if exists "members can update their own idea vote" on public.meeting_idea_votes;
create policy "members can update their own idea vote"
on public.meeting_idea_votes for update
to authenticated
using (public.is_active_member() and user_id = auth.uid())
with check (
  public.is_active_member()
  and user_id = auth.uid()
  and exists (
    select 1
    from public.meeting_ideas
    where id = idea_id
      and day >= current_date
  )
);

drop policy if exists "members can withdraw their own idea vote" on public.meeting_idea_votes;
create policy "members can withdraw their own idea vote"
on public.meeting_idea_votes for delete
to authenticated
using (public.is_active_member() and user_id = auth.uid());

alter table public.meeting_ideas replica identity full;
alter table public.meeting_idea_votes replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'meeting_ideas'
  ) then
    alter publication supabase_realtime add table public.meeting_ideas;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'meeting_idea_votes'
  ) then
    alter publication supabase_realtime add table public.meeting_idea_votes;
  end if;
end;
$$;
