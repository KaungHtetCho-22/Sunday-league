-- Sunday League v10.1
-- Fix Team A / Team B joining for newly registered players.
-- Run this once in Supabase -> SQL Editor.

grant select, insert, update, delete
on public.match_players
to authenticated;

alter table public.match_players
enable row level security;

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

drop policy if exists "Player leaves own team"
on public.match_players;

create policy "Player leaves own team"
on public.match_players
for delete
to authenticated
using (
  created_by = (select auth.uid())
);
