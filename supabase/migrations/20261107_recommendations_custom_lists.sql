-- Module 6 — Recommendations & Custom Lists (Yasmine)
-- Rules: name 2–50 characters, unique per user (case-insensitive), 20 lists per user,
-- 100 movies per list, no duplicate movie, private or public list, only the owner can modify.

-- 1. Custom lists -----------------------------------------------------------
alter table public.custom_lists
  add column if not exists is_public boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

alter table public.custom_lists drop constraint if exists custom_lists_name_length;
alter table public.custom_lists add constraint custom_lists_name_length
  check (name = btrim(name) and char_length(name) between 2 and 50);

alter table public.custom_lists drop constraint if exists custom_lists_description_length;
alter table public.custom_lists add constraint custom_lists_description_length
  check (char_length(description) <= 300);

create unique index if not exists custom_lists_user_name_ci_idx
  on public.custom_lists (user_id, lower(name));

create index if not exists custom_lists_public_updated_idx
  on public.custom_lists (updated_at desc) where is_public;

-- 2. Movies within lists (denormalized TMDB data: no TMDB call to display a list)
alter table public.custom_list_movies
  add column if not exists title text not null default '',
  add column if not exists poster_path text,
  add column if not exists genre_ids integer[] not null default '{}',
  add column if not exists vote_average real not null default 0;

create index if not exists custom_list_movies_list_added_idx
  on public.custom_list_movies (list_id, added_at desc);

-- 3. Limits (the advisory lock prevents two concurrent inserts from exceeding them)
create or replace function public.enforce_custom_list_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('custom_lists:' || new.user_id::text));
  if (select count(*) from public.custom_lists where user_id = new.user_id) >= 20 then
    raise exception 'LIST_LIMIT_REACHED' using hint = 'Maximum 20 lists per user.';
  end if;
  return new;
end;
$$;

drop trigger if exists custom_lists_limit on public.custom_lists;
create trigger custom_lists_limit
  before insert on public.custom_lists
  for each row execute function public.enforce_custom_list_limit();

create or replace function public.enforce_custom_list_movie_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('custom_list_movies:' || new.list_id::text));
  if (select count(*) from public.custom_list_movies where list_id = new.list_id) >= 100 then
    raise exception 'LIST_MOVIE_LIMIT_REACHED' using hint = 'Maximum 100 movies per list.';
  end if;
  return new;
end;
$$;

drop trigger if exists custom_list_movies_limit on public.custom_list_movies;
create trigger custom_list_movies_limit
  before insert on public.custom_list_movies
  for each row execute function public.enforce_custom_list_movie_limit();

-- 4. updated_at
create or replace function public.touch_custom_list()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'custom_lists' then
    new.updated_at := now();
    return new;
  end if;
  update public.custom_lists
     set updated_at = now()
   where id = coalesce(new.list_id, old.list_id);
  return null;
end;
$$;

drop trigger if exists custom_lists_touch on public.custom_lists;
create trigger custom_lists_touch
  before update on public.custom_lists
  for each row execute function public.touch_custom_list();

drop trigger if exists custom_list_movies_touch on public.custom_list_movies;
create trigger custom_list_movies_touch
  after insert or delete on public.custom_list_movies
  for each row execute function public.touch_custom_list();

-- 5. Row Level Security: read own or public lists, write only own lists
drop policy if exists "Users manage their own custom lists" on public.custom_lists;
drop policy if exists "Read own or public custom lists" on public.custom_lists;
drop policy if exists "Owners insert custom lists" on public.custom_lists;
drop policy if exists "Owners update custom lists" on public.custom_lists;
drop policy if exists "Owners delete custom lists" on public.custom_lists;

create policy "Read own or public custom lists"
on public.custom_lists for select to authenticated
using (is_public or (select auth.uid()) = user_id);

create policy "Owners insert custom lists"
on public.custom_lists for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Owners update custom lists"
on public.custom_lists for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Owners delete custom lists"
on public.custom_lists for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users manage movies in their own lists" on public.custom_list_movies;
drop policy if exists "Read movies of own or public lists" on public.custom_list_movies;
drop policy if exists "Owners write movies in their lists" on public.custom_list_movies;

create policy "Read movies of own or public lists"
on public.custom_list_movies for select to authenticated
using (
  exists (
    select 1 from public.custom_lists l
    where l.id = list_id
      and (l.is_public or l.user_id = (select auth.uid()))
  )
);

create policy "Owners write movies in their lists"
on public.custom_list_movies for all to authenticated
using (
  exists (
    select 1 from public.custom_lists l
    where l.id = list_id and l.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.custom_lists l
    where l.id = list_id and l.user_id = (select auth.uid())
  )
);

-- 6. List summaries (count + 4 posters) in a single query
create or replace function public.get_my_custom_lists()
returns table (
  id bigint, user_id uuid, name text, description text, is_public boolean,
  movie_count bigint, preview_posters text[], created_at timestamptz, updated_at timestamptz
)
language sql
stable
set search_path = ''
as $$
  select l.id, l.user_id, l.name, l.description, l.is_public,
         (select count(*) from public.custom_list_movies m where m.list_id = l.id),
         array(select m.poster_path from public.custom_list_movies m
               where m.list_id = l.id and m.poster_path is not null
               order by m.added_at desc limit 4),
         l.created_at, l.updated_at
  from public.custom_lists l
  where l.user_id = (select auth.uid())
  order by l.updated_at desc;
$$;

-- Public lists with the owner's display name (profiles stay private: security definer
-- exposes only the display name, and only for public lists).
create or replace function public.get_public_custom_lists(p_limit integer default 30, p_offset integer default 0)
returns table (
  id bigint, user_id uuid, name text, description text, is_public boolean, owner_name text,
  movie_count bigint, preview_posters text[], created_at timestamptz, updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.user_id, l.name, l.description, l.is_public,
         coalesce(nullif(p.display_name, ''), p.username, 'Movie fan'),
         (select count(*) from public.custom_list_movies m where m.list_id = l.id),
         array(select m.poster_path from public.custom_list_movies m
               where m.list_id = l.id and m.poster_path is not null
               order by m.added_at desc limit 4),
         l.created_at, l.updated_at
  from public.custom_lists l
  join public.profiles p on p.id = l.user_id
  where l.is_public
    and exists (select 1 from public.custom_list_movies m where m.list_id = l.id)
  order by l.updated_at desc
  limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
$$;

create or replace function public.get_custom_list_owner_name(p_list_id bigint)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(p.display_name, ''), p.username, 'Movie fan')
  from public.custom_lists l
  join public.profiles p on p.id = l.user_id
  where l.id = p_list_id
    and (l.is_public or l.user_id = (select auth.uid()));
$$;

revoke all on function public.get_my_custom_lists() from public, anon;
revoke all on function public.get_public_custom_lists(integer, integer) from public, anon;
revoke all on function public.get_custom_list_owner_name(bigint) from public, anon;
grant execute on function public.get_my_custom_lists() to authenticated;
grant execute on function public.get_public_custom_lists(integer, integer) to authenticated;
grant execute on function public.get_custom_list_owner_name(bigint) to authenticated;
