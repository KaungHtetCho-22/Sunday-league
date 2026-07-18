-- Sunday League v10
-- Multiple upcoming matches + explicit Not available responses.
-- Run after the v9.2 migration.

-- Allow more than one match date/session to exist.
alter table public.matches
  drop constraint if exists matches_match_date_key;

create index if not exists matches_upcoming_index
  on public.matches(match_date, status, created_at);

-- Store a response even when the player chooses Not available.
create table if not exists public.match_availability_responses (
  match_id uuid not null
    references public.matches(id)
    on delete cascade,
  player_id uuid not null
    references public.players(id)
    on delete cascade,
  created_by uuid not null
    references auth.users(id)
    on delete cascade,
  response_status text not null
    check (
      response_status in (
        'available',
        'unavailable'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, player_id)
);

grant select, insert, update, delete
on public.match_availability_responses
to authenticated;

alter table public.match_availability_responses
enable row level security;

drop policy if exists "Friends read availability responses"
on public.match_availability_responses;

create policy "Friends read availability responses"
on public.match_availability_responses
for select
to authenticated
using (true);

drop policy if exists "Player creates own availability response"
on public.match_availability_responses;

create policy "Player creates own availability response"
on public.match_availability_responses
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      match_availability_responses.player_id
      and player.owner_id =
        (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id =
      match_availability_responses.match_id
      and match.status = 'voting'
  )
);

drop policy if exists "Player updates own availability response"
on public.match_availability_responses;

create policy "Player updates own availability response"
on public.match_availability_responses
for update
to authenticated
using (
  created_by = (select auth.uid())
)
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      match_availability_responses.player_id
      and player.owner_id =
        (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id =
      match_availability_responses.match_id
      and match.status = 'voting'
  )
);

drop policy if exists "Player deletes own availability response"
on public.match_availability_responses;

create policy "Player deletes own availability response"
on public.match_availability_responses
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

-- Existing voters count as available.
insert into public.match_availability_responses (
  match_id,
  player_id,
  created_by,
  response_status
)
select distinct
  option.match_id,
  vote.player_id,
  vote.created_by,
  'available'
from public.availability_votes vote
join public.match_time_options option
  on option.id = vote.time_option_id
on conflict (match_id, player_id)
do nothing;

-- Planned arrival can now also be Not available.
alter table public.match_arrival_plans
  add column if not exists availability_status text;

update public.match_arrival_plans
set availability_status = 'coming'
where availability_status is null;

alter table public.match_arrival_plans
  alter column availability_status
  set default 'coming';

alter table public.match_arrival_plans
  alter column availability_status
  set not null;

alter table public.match_arrival_plans
  alter column expected_arrival_time
  drop not null;

alter table public.match_arrival_plans
  drop constraint if exists
  match_arrival_plans_availability_check;

alter table public.match_arrival_plans
  add constraint
  match_arrival_plans_availability_check
  check (
    (
      availability_status = 'coming'
      and expected_arrival_time is not null
    )
    or
    (
      availability_status = 'unavailable'
      and expected_arrival_time is null
    )
  );

drop policy if exists "Player creates own arrival plan"
on public.match_arrival_plans;

create policy "Player creates own arrival plan"
on public.match_arrival_plans
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      match_arrival_plans.player_id
      and player.owner_id =
        (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id =
      match_arrival_plans.match_id
      and match.status = 'confirmed'
  )
  and (
    (
      availability_status = 'unavailable'
      and expected_arrival_time is null
    )
    or
    (
      availability_status = 'coming'
      and exists (
        select 1
        from public.match_time_options option
        where option.match_id =
          match_arrival_plans.match_id
          and option.start_time =
            match_arrival_plans.expected_arrival_time
      )
    )
  )
);

drop policy if exists "Player updates own arrival plan"
on public.match_arrival_plans;

create policy "Player updates own arrival plan"
on public.match_arrival_plans
for update
to authenticated
using (
  created_by = (select auth.uid())
)
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      match_arrival_plans.player_id
      and player.owner_id =
        (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id =
      match_arrival_plans.match_id
      and match.status = 'confirmed'
  )
  and (
    (
      availability_status = 'unavailable'
      and expected_arrival_time is null
    )
    or
    (
      availability_status = 'coming'
      and exists (
        select 1
        from public.match_time_options option
        where option.match_id =
          match_arrival_plans.match_id
          and option.start_time =
            match_arrival_plans.expected_arrival_time
      )
    )
  )
);

create index if not exists
  match_availability_responses_status_index
on public.match_availability_responses(
  match_id,
  response_status
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename =
        'match_availability_responses'
  ) then
    alter publication supabase_realtime
      add table
      public.match_availability_responses;
  end if;
end
$$;
