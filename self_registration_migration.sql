-- Run this once in Supabase SQL Editor.
-- It changes player identity from "pre-register and claim" to self-registration.

alter table public.players enable row level security;

drop policy if exists "Claim or edit own player" on public.players;
drop policy if exists "Users register own player" on public.players;
drop policy if exists "Users edit own player" on public.players;

create policy "Users register own player"
on public.players
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
);

create policy "Users edit own player"
on public.players
for update
to authenticated
using (
  owner_id = (select auth.uid())
)
with check (
  owner_id = (select auth.uid())
);

-- The owner_id column is already UNIQUE in the original schema,
-- so one anonymous browser identity can create only one player profile.

-- Optional cleanup:
-- Delete old sample/pre-registered rows that nobody claimed.
-- Claimed profiles such as your existing Kaung profile are kept.
delete from public.players
where owner_id is null;
