-- Sunday League v11.3
-- Keep only one match per calendar day and enforce that rule.
-- Existing duplicate dates are cleaned before the unique index is created.

with ranked_matches as (
  select
    id,
    row_number() over (
      partition by match_date
      order by
        case when status = 'confirmed' then 0 else 1 end,
        created_at asc,
        id asc
    ) as duplicate_rank
  from public.matches
)
delete from public.matches match
using ranked_matches ranked
where match.id = ranked.id
  and ranked.duplicate_rank > 1;

alter table public.matches
  drop constraint if exists matches_match_date_key;

drop index if exists public.matches_one_match_per_day_index;

create unique index matches_one_match_per_day_index
on public.matches(match_date);
