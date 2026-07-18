-- Sunday League v7: shared match synchronization
-- Run this once in Supabase Dashboard -> SQL Editor -> New query.
-- This is idempotent and can be safely run after the original schema.

grant usage on schema public to authenticated;

grant select, insert, update, delete on
  public.matches,
  public.match_time_options,
  public.availability_votes,
  public.match_players
to authenticated;

alter table public.matches enable row level security;
alter table public.match_time_options enable row level security;
alter table public.availability_votes enable row level security;
alter table public.match_players enable row level security;

drop policy if exists "Friends read matches" on public.matches;
create policy "Friends read matches"
on public.matches
for select
to authenticated
using (true);

drop policy if exists "Friends create matches" on public.matches;
create policy "Friends create matches"
on public.matches
for insert
to authenticated
with check (
  created_by = (select auth.uid())
);

drop policy if exists "Creator edits match" on public.matches;
create policy "Creator edits match"
on public.matches
for update
to authenticated
using (
  created_by = (select auth.uid())
)
with check (
  created_by = (select auth.uid())
);

drop policy if exists "Creator deletes match" on public.matches;
create policy "Creator deletes match"
on public.matches
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

drop policy if exists "Friends read time options" on public.match_time_options;
create policy "Friends read time options"
on public.match_time_options
for select
to authenticated
using (true);

drop policy if exists "Creator adds time options" on public.match_time_options;
create policy "Creator adds time options"
on public.match_time_options
for insert
to authenticated
with check (
  exists (
    select 1
    from public.matches match
    where match.id = match_time_options.match_id
      and match.created_by = (select auth.uid())
      and match.status = 'voting'
  )
);

drop policy if exists "Creator removes time options" on public.match_time_options;
create policy "Creator removes time options"
on public.match_time_options
for delete
to authenticated
using (
  exists (
    select 1
    from public.matches match
    where match.id = match_time_options.match_id
      and match.created_by = (select auth.uid())
      and match.status = 'voting'
  )
);

drop policy if exists "Friends read availability" on public.availability_votes;
create policy "Friends read availability"
on public.availability_votes
for select
to authenticated
using (true);

drop policy if exists "Player adds own availability" on public.availability_votes;
create policy "Player adds own availability"
on public.availability_votes
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id = availability_votes.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.match_time_options option
    join public.matches match
      on match.id = option.match_id
    where option.id = availability_votes.time_option_id
      and match.status = 'voting'
  )
);

drop policy if exists "Player removes own availability" on public.availability_votes;
create policy "Player removes own availability"
on public.availability_votes
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

drop policy if exists "Friends read teams" on public.match_players;
create policy "Friends read teams"
on public.match_players
for select
to authenticated
using (true);

drop policy if exists "Player joins own team" on public.match_players;
create policy "Player joins own team"
on public.match_players
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id = match_players.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    join public.match_time_options option
      on option.match_id = match.id
      and option.start_time = match.confirmed_time
    join public.availability_votes vote
      on vote.time_option_id = option.id
      and vote.player_id = match_players.player_id
    where match.id = match_players.match_id
      and match.status = 'confirmed'
  )
);

drop policy if exists "Player changes own team" on public.match_players;
create policy "Player changes own team"
on public.match_players
for update
to authenticated
using (
  created_by = (select auth.uid())
)
with check (
  created_by = (select auth.uid())
);

drop policy if exists "Player leaves own team" on public.match_players;
create policy "Player leaves own team"
on public.match_players
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

create or replace function public.confirm_match_time(
  p_match_id uuid,
  p_time_option_id uuid
)
returns time
language plpgsql
security invoker
set search_path = public
as $$
declare
  selected_time time;
  vote_count integer;
begin
  if not exists (
    select 1
    from public.matches
    where id = p_match_id
      and created_by = auth.uid()
      and status = 'voting'
  ) then
    raise exception 'Only the match creator can confirm this match';
  end if;

  select start_time
  into selected_time
  from public.match_time_options
  where id = p_time_option_id
    and match_id = p_match_id;

  if selected_time is null then
    raise exception 'Invalid time option';
  end if;

  select count(*)
  into vote_count
  from public.availability_votes
  where time_option_id = p_time_option_id;

  if vote_count < 3 then
    raise exception 'At least 3 players must agree on this time';
  end if;

  update public.matches
  set
    confirmed_time = selected_time,
    status = 'confirmed'
  where id = p_match_id;

  return selected_time;
end;
$$;

grant execute on function
  public.confirm_match_time(uuid, uuid)
to authenticated;

create index if not exists matches_status_date_index
  on public.matches(status, match_date);

create index if not exists availability_votes_player_index
  on public.availability_votes(player_id);

create index if not exists match_players_player_index
  on public.match_players(player_id);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'matches',
    'match_time_options',
    'availability_votes',
    'match_players'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end
$$;

-- v8 addition: live arrival check-ins

create table if not exists public.match_arrivals (
  match_id uuid not null
    references public.matches(id)
    on delete cascade,
  player_id uuid not null
    references public.players(id)
    on delete cascade,
  created_by uuid not null
    references auth.users(id)
    on delete cascade,
  arrived_at timestamptz not null default now(),
  primary key (match_id, player_id)
);

grant select, insert, update, delete
on public.match_arrivals
to authenticated;

alter table public.match_arrivals enable row level security;

drop policy if exists "Friends read arrivals"
on public.match_arrivals;

create policy "Friends read arrivals"
on public.match_arrivals
for select
to authenticated
using (true);

drop policy if exists "Player shares own arrival"
on public.match_arrivals;

create policy "Player shares own arrival"
on public.match_arrivals
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id = match_arrivals.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.match_players participant
    join public.matches match
      on match.id = participant.match_id
    where participant.match_id = match_arrivals.match_id
      and participant.player_id = match_arrivals.player_id
      and match.status = 'confirmed'
  )
);

drop policy if exists "Player updates own arrival"
on public.match_arrivals;

create policy "Player updates own arrival"
on public.match_arrivals
for update
to authenticated
using (
  created_by = (select auth.uid())
)
with check (
  created_by = (select auth.uid())
);

drop policy if exists "Player removes own arrival"
on public.match_arrivals;

create policy "Player removes own arrival"
on public.match_arrivals
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

create index if not exists match_arrivals_time_index
  on public.match_arrivals(match_id, arrived_at);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_arrivals'
  ) then
    alter publication supabase_realtime
      add table public.match_arrivals;
  end if;
end
$$;
