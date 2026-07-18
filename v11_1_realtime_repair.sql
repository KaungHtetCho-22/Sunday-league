-- Sunday League v11.1
-- Repair Supabase Realtime publication for every shared table.
-- Safe to run more than once.

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'players',
    'matches',
    'match_time_options',
    'availability_votes',
    'match_availability_responses',
    'match_players',
    'match_arrival_plans',
    'match_arrivals',
    'memory_posts',
    'memory_comments'
  ]
  loop
    if to_regclass(
      format('public.%I', table_name)
    ) is not null
    and not exists (
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

-- Helpful diagnostic result:
select
  schemaname,
  tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in (
    'players',
    'matches',
    'match_time_options',
    'availability_votes',
    'match_availability_responses',
    'match_players',
    'match_arrival_plans',
    'match_arrivals',
    'memory_posts',
    'memory_comments'
  )
order by tablename;
