-- Sunday League v9.2
-- Let every registered player share an expected arrival time after the match time is confirmed.

create table if not exists public.match_arrival_plans (
  match_id uuid not null
    references public.matches(id)
    on delete cascade,
  player_id uuid not null
    references public.players(id)
    on delete cascade,
  created_by uuid not null
    references auth.users(id)
    on delete cascade,
  expected_arrival_time time not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, player_id)
);

grant select, insert, update, delete
on public.match_arrival_plans
to authenticated;

alter table public.match_arrival_plans
enable row level security;

drop policy if exists "Friends read arrival plans"
on public.match_arrival_plans;

create policy "Friends read arrival plans"
on public.match_arrival_plans
for select
to authenticated
using (true);

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
    where player.id = match_arrival_plans.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id = match_arrival_plans.match_id
      and match.status = 'confirmed'
  )
  and expected_arrival_time in (
    time '17:00',
    time '17:15',
    time '17:30',
    time '17:45',
    time '18:00'
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
    where player.id = match_arrival_plans.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id = match_arrival_plans.match_id
      and match.status = 'confirmed'
  )
  and expected_arrival_time in (
    time '17:00',
    time '17:15',
    time '17:30',
    time '17:45',
    time '18:00'
  )
);

drop policy if exists "Player deletes own arrival plan"
on public.match_arrival_plans;

create policy "Player deletes own arrival plan"
on public.match_arrival_plans
for delete
to authenticated
using (
  created_by = (select auth.uid())
);

create index if not exists match_arrival_plans_time_index
  on public.match_arrival_plans(
    match_id,
    expected_arrival_time
  );

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_arrival_plans'
  ) then
    alter publication supabase_realtime
      add table public.match_arrival_plans;
  end if;
end
$$;
