-- JACKPOT uruchamia się, gdy wszyscy aktywni użytkownicy odpowiedzieli
-- i nikt nie wybrał statusu "unavailable". Status "unsure" jest dozwolony.

create or replace function public.emit_jackpot_when_meeting_possible()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_new_possible_count integer;
  v_old_possible_count integer;
begin
  select count(*)
  into v_active_count
  from public.profiles
  where is_active = true;

  if v_active_count = 0 then
    return new;
  end if;

  select count(*)
  into v_new_possible_count
  from public.availability a
  join public.profiles p
    on p.id = a.user_id
   and p.is_active = true
  where a.day = new.day
    and a.status in ('available', 'unsure');

  if tg_op = 'INSERT' then
    v_old_possible_count := v_new_possible_count
      - case when new.status in ('available', 'unsure') then 1 else 0 end;
  else
    v_old_possible_count := v_new_possible_count
      - case when new.status in ('available', 'unsure') then 1 else 0 end
      + case when old.status in ('available', 'unsure') then 1 else 0 end;
  end if;

  if v_new_possible_count = v_active_count
     and v_old_possible_count <> v_active_count then
    insert into public.meeting_events (event_type, day)
    values ('jackpot', new.day);
  end if;

  return new;
end;
$$;

revoke all on function public.emit_jackpot_when_meeting_possible()
from public, anon, authenticated;

drop trigger if exists availability_emit_jackpot on public.availability;

create trigger availability_emit_jackpot
after insert or update of status on public.availability
for each row execute function public.emit_jackpot_when_meeting_possible();

-- Stara funkcja nie jest już używana.
drop function if exists public.emit_jackpot_when_everyone_available();
