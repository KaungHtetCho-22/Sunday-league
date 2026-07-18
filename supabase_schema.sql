-- Sunday League Supabase schema
-- Run in Supabase Dashboard -> SQL Editor -> New query.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid unique references auth.users(id) on delete set null,
  name text not null check (char_length(trim(name)) between 1 and 30),
  shirt_number smallint check (shirt_number between 0 and 99),
  position text not null default 'Anywhere'
    check (position in ('Goalkeeper','Defender','Midfielder','Forward','Anywhere')),
  description text not null default '',
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid()
    references auth.users(id) on delete restrict,
  title text not null default 'Sunday Match',
  match_date date not null unique,
  location text not null default 'AIT Football Field',
  team_a_name text not null default 'Team A',
  team_b_name text not null default 'Team B',
  status text not null default 'voting'
    check (status in ('voting','confirmed','completed','cancelled')),
  confirmed_time time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_time_options (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  start_time time not null,
  created_at timestamptz not null default now(),
  unique (match_id, start_time)
);

create table if not exists public.availability_votes (
  time_option_id uuid not null references public.match_time_options(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (time_option_id, player_id)
);

create table if not exists public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  team text not null check (team in ('A','B')),
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, player_id)
);

create table if not exists public.memory_posts (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  image_path text not null,
  caption text not null default '' check (char_length(caption) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memory_comments (
  id uuid primary key default gen_random_uuid(),
  memory_post_id uuid not null references public.memory_posts(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  comment text not null check (char_length(trim(comment)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists players_set_updated_at on public.players;
create trigger players_set_updated_at before update on public.players
for each row execute function public.set_updated_at();

drop trigger if exists matches_set_updated_at on public.matches;
create trigger matches_set_updated_at before update on public.matches
for each row execute function public.set_updated_at();

drop trigger if exists match_players_set_updated_at on public.match_players;
create trigger match_players_set_updated_at before update on public.match_players
for each row execute function public.set_updated_at();

drop trigger if exists memory_posts_set_updated_at on public.memory_posts;
create trigger memory_posts_set_updated_at before update on public.memory_posts
for each row execute function public.set_updated_at();

drop trigger if exists memory_comments_set_updated_at on public.memory_comments;
create trigger memory_comments_set_updated_at before update on public.memory_comments
for each row execute function public.set_updated_at();

grant usage on schema public to authenticated;
grant select, insert, update, delete on
  public.players, public.matches, public.match_time_options,
  public.availability_votes, public.match_players,
  public.memory_posts, public.memory_comments
to authenticated;

alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_time_options enable row level security;
alter table public.availability_votes enable row level security;
alter table public.match_players enable row level security;
alter table public.memory_posts enable row level security;
alter table public.memory_comments enable row level security;

drop policy if exists "Friends read players" on public.players;
create policy "Friends read players" on public.players
for select to authenticated using (true);

drop policy if exists "Claim or edit own player" on public.players;
create policy "Claim or edit own player" on public.players
for update to authenticated
using (owner_id is null or owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "Friends read matches" on public.matches;
create policy "Friends read matches" on public.matches
for select to authenticated using (true);

drop policy if exists "Friends create matches" on public.matches;
create policy "Friends create matches" on public.matches
for insert to authenticated
with check (created_by = (select auth.uid()));

drop policy if exists "Creator edits match" on public.matches;
create policy "Creator edits match" on public.matches
for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

drop policy if exists "Creator deletes match" on public.matches;
create policy "Creator deletes match" on public.matches
for delete to authenticated
using (created_by = (select auth.uid()));

drop policy if exists "Friends read time options" on public.match_time_options;
create policy "Friends read time options" on public.match_time_options
for select to authenticated using (true);

drop policy if exists "Creator adds time options" on public.match_time_options;
create policy "Creator adds time options" on public.match_time_options
for insert to authenticated
with check (
  exists (
    select 1 from public.matches m
    where m.id = match_time_options.match_id
      and m.created_by = (select auth.uid())
      and m.status = 'voting'
  )
);

drop policy if exists "Creator removes time options" on public.match_time_options;
create policy "Creator removes time options" on public.match_time_options
for delete to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = match_time_options.match_id
      and m.created_by = (select auth.uid())
      and m.status = 'voting'
  )
);

drop policy if exists "Friends read availability" on public.availability_votes;
create policy "Friends read availability" on public.availability_votes
for select to authenticated using (true);

drop policy if exists "Player adds own availability" on public.availability_votes;
create policy "Player adds own availability" on public.availability_votes
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.players p
    where p.id = availability_votes.player_id
      and p.owner_id = (select auth.uid())
  )
  and exists (
    select 1 from public.match_time_options o
    join public.matches m on m.id = o.match_id
    where o.id = availability_votes.time_option_id
      and m.status = 'voting'
  )
);

drop policy if exists "Player removes own availability" on public.availability_votes;
create policy "Player removes own availability" on public.availability_votes
for delete to authenticated
using (created_by = (select auth.uid()));

drop policy if exists "Friends read teams" on public.match_players;
create policy "Friends read teams" on public.match_players
for select to authenticated using (true);

drop policy if exists "Player joins own team" on public.match_players;
create policy "Player joins own team" on public.match_players
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.players p
    where p.id = match_players.player_id
      and p.owner_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.matches m
    join public.match_time_options o
      on o.match_id = m.id and o.start_time = m.confirmed_time
    join public.availability_votes v
      on v.time_option_id = o.id and v.player_id = match_players.player_id
    where m.id = match_players.match_id
      and m.status = 'confirmed'
  )
);

drop policy if exists "Player changes own team" on public.match_players;
create policy "Player changes own team" on public.match_players
for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

drop policy if exists "Player leaves own team" on public.match_players;
create policy "Player leaves own team" on public.match_players
for delete to authenticated
using (created_by = (select auth.uid()));

drop policy if exists "Friends read memories" on public.memory_posts;
create policy "Friends read memories" on public.memory_posts
for select to authenticated using (true);

drop policy if exists "Player creates own memory" on public.memory_posts;
create policy "Player creates own memory" on public.memory_posts
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.players p
    where p.id = memory_posts.player_id
      and p.owner_id = (select auth.uid())
  )
);

drop policy if exists "Player edits own memory" on public.memory_posts;
create policy "Player edits own memory" on public.memory_posts
for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

drop policy if exists "Player deletes own memory" on public.memory_posts;
create policy "Player deletes own memory" on public.memory_posts
for delete to authenticated
using (created_by = (select auth.uid()));

drop policy if exists "Friends read comments" on public.memory_comments;
create policy "Friends read comments" on public.memory_comments
for select to authenticated using (true);

drop policy if exists "Player creates own comment" on public.memory_comments;
create policy "Player creates own comment" on public.memory_comments
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.players p
    where p.id = memory_comments.player_id
      and p.owner_id = (select auth.uid())
  )
);

drop policy if exists "Player edits own comment" on public.memory_comments;
create policy "Player edits own comment" on public.memory_comments
for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

drop policy if exists "Player deletes own comment" on public.memory_comments;
create policy "Player deletes own comment" on public.memory_comments
for delete to authenticated
using (created_by = (select auth.uid()));

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
  v_time time;
  v_votes integer;
begin
  if not exists (
    select 1 from public.matches
    where id = p_match_id
      and created_by = auth.uid()
      and status = 'voting'
  ) then
    raise exception 'Only the match creator can confirm this match';
  end if;

  select start_time into v_time
  from public.match_time_options
  where id = p_time_option_id and match_id = p_match_id;

  if v_time is null then
    raise exception 'Invalid time option';
  end if;

  select count(*) into v_votes
  from public.availability_votes
  where time_option_id = p_time_option_id;

  if v_votes < 3 then
    raise exception 'At least 3 players must agree on this time';
  end if;

  update public.matches
  set confirmed_time = v_time, status = 'confirmed'
  where id = p_match_id;

  return v_time;
end;
$$;

grant execute on function public.confirm_match_time(uuid, uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', false, 5242880, array['image/jpeg','image/png','image/webp']),
  ('memories', 'memories', false, 6291456, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Friends view football images" on storage.objects;
create policy "Friends view football images" on storage.objects
for select to authenticated
using (bucket_id in ('avatars','memories'));

drop policy if exists "Users upload own football images" on storage.objects;
create policy "Users upload own football images" on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars','memories')
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "Users update own football images" on storage.objects;
create policy "Users update own football images" on storage.objects
for update to authenticated
using (
  bucket_id in ('avatars','memories')
  and owner_id = (select auth.uid()::text)
)
with check (
  bucket_id in ('avatars','memories')
  and owner_id = (select auth.uid()::text)
);

drop policy if exists "Users delete own football images" on storage.objects;
create policy "Users delete own football images" on storage.objects
for delete to authenticated
using (
  bucket_id in ('avatars','memories')
  and owner_id = (select auth.uid()::text)
);

do $$
declare t text;
begin
  foreach t in array array[
    'players','matches','match_time_options','availability_votes',
    'match_players','memory_posts','memory_comments'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
