-- Sunday League v11: Web Push subscriptions
-- Run after the previous Sunday League migrations.

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null
    references auth.users(id)
    on delete cascade,
  player_id uuid not null
    references public.players(id)
    on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

grant select, insert, update, delete
on public.push_subscriptions
to authenticated;

alter table public.push_subscriptions
enable row level security;

drop policy if exists "Users read own push subscriptions"
on public.push_subscriptions;

create policy "Users read own push subscriptions"
on public.push_subscriptions
for select
to authenticated
using (
  owner_id = (select auth.uid())
);

drop policy if exists "Users create own push subscriptions"
on public.push_subscriptions;

create policy "Users create own push subscriptions"
on public.push_subscriptions
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      push_subscriptions.player_id
      and player.owner_id =
        (select auth.uid())
  )
);

drop policy if exists "Users update own push subscriptions"
on public.push_subscriptions;

create policy "Users update own push subscriptions"
on public.push_subscriptions
for update
to authenticated
using (
  owner_id = (select auth.uid())
)
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.players player
    where player.id =
      push_subscriptions.player_id
      and player.owner_id =
        (select auth.uid())
  )
);

drop policy if exists "Users delete own push subscriptions"
on public.push_subscriptions;

create policy "Users delete own push subscriptions"
on public.push_subscriptions
for delete
to authenticated
using (
  owner_id = (select auth.uid())
);

create index if not exists
  push_subscriptions_owner_index
on public.push_subscriptions(owner_id);

-- Keep the corrected late-player team policy.
drop policy if exists "Player joins own team"
on public.match_players;

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
    where match.id = match_players.match_id
      and match.status = 'confirmed'
  )
);

drop policy if exists "Player changes own team"
on public.match_players;

create policy "Player changes own team"
on public.match_players
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
    where player.id = match_players.player_id
      and player.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.matches match
    where match.id = match_players.match_id
      and match.status = 'confirmed'
  )
);
