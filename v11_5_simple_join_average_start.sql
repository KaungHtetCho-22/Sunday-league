-- Sunday League v11.5
-- Simplified participation, expected-arrival average, and immediate confirmation.
-- Run after previous Sunday League migrations.

-- Players may answer Yes/No before or after creator confirmation.
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
      and match.status in ('voting', 'confirmed')
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
      and match.status in ('voting', 'confirmed')
  )
);

-- Expected arrival may be saved while the poll is open or after confirmation.
drop policy if exists "Player creates own arrival plan"
on public.match_arrival_plans;

create policy "Player creates own arrival plan"
on public.match_arrival_plans
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and availability_status = 'coming'
  and expected_arrival_time is not null
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
      and match.status in ('voting', 'confirmed')
  )
  and exists (
    select 1
    from public.match_availability_responses response
    where response.match_id = match_arrival_plans.match_id
      and response.player_id = match_arrival_plans.player_id
      and response.response_status = 'available'
  )
  and exists (
    select 1
    from public.match_time_options option
    where option.match_id = match_arrival_plans.match_id
      and option.start_time =
        match_arrival_plans.expected_arrival_time
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
  and availability_status = 'coming'
  and expected_arrival_time is not null
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
      and match.status in ('voting', 'confirmed')
  )
  and exists (
    select 1
    from public.match_availability_responses response
    where response.match_id = match_arrival_plans.match_id
      and response.player_id = match_arrival_plans.player_id
      and response.response_status = 'available'
  )
  and exists (
    select 1
    from public.match_time_options option
    where option.match_id = match_arrival_plans.match_id
      and option.start_time =
        match_arrival_plans.expected_arrival_time
  )
);

-- The creator already has update permission on their own match.
-- No minimum-player RPC is needed; the frontend now confirms directly.
