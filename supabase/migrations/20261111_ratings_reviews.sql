-- Ratings & Reviews.
--
-- * ratings          one 1–5 score per user and movie (re-rating replaces it)
-- * reviews          one review per user and movie, 3–1000 characters,
--                    optional spoiler flag; the score is read from ratings
-- * review_likes     one like per user and review, never on one's own review
-- * review_reports   one report per user and review, 3–300 characters,
--                    never on one's own review
--
-- Movies are identified by their TMDB id (tmdb_movie_id), like favorites,
-- watchlist and watched_movies.
--
-- The existing public.reviews table from schema.sql (rating 1–10 stored on
-- the review) is migrated in place: its ratings move to public.ratings
-- (ceil(rating / 2)), and rows whose text is shorter than 3 characters
-- become rating-only.

-- ---------------------------------------------------------------------------
-- Ratings
-- ---------------------------------------------------------------------------

create table if not exists public.ratings (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null check (tmdb_movie_id > 0),
  score smallint not null check (score between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

create index if not exists ratings_movie_idx
  on public.ratings (tmdb_movie_id);

-- ---------------------------------------------------------------------------
-- Reviews: create, or migrate the schema.sql version
-- ---------------------------------------------------------------------------

create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null,
  content text not null,
  spoiler boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reviews'
      and column_name = 'rating'
  ) then
    insert into public.ratings (user_id, tmdb_movie_id, score, created_at, updated_at)
    select user_id, tmdb_movie_id, ceil(rating / 2.0)::smallint, created_at, updated_at
    from public.reviews
    where tmdb_movie_id > 0
    on conflict (user_id, tmdb_movie_id) do nothing;

    delete from public.reviews
    where char_length(regexp_replace(review_text, '^\s+|\s+$', '', 'g')) < 3;

    update public.reviews
    set review_text = left(regexp_replace(review_text, '^\s+|\s+$', '', 'g'), 1000);

    alter table public.reviews drop column rating;
    alter table public.reviews rename column review_text to content;
    alter table public.reviews alter column content drop default;
  end if;
end;
$$;

alter table public.reviews
  add column if not exists spoiler boolean not null default false;

alter table public.reviews
  drop constraint if exists reviews_content_length;
alter table public.reviews
  add constraint reviews_content_length
  check (char_length(content) between 3 and 1000);

alter table public.reviews
  drop constraint if exists reviews_tmdb_movie_id_positive;
alter table public.reviews
  add constraint reviews_tmdb_movie_id_positive check (tmdb_movie_id > 0);

create index if not exists reviews_movie_created_idx
  on public.reviews (tmdb_movie_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Likes and reports
-- ---------------------------------------------------------------------------

create table if not exists public.review_likes (
  review_id bigint not null references public.reviews(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (review_id, user_id)
);

create index if not exists review_likes_user_idx
  on public.review_likes (user_id);

create table if not exists public.review_reports (
  id bigint generated always as identity primary key,
  review_id bigint not null references public.reviews(id) on delete cascade,
  reporter_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 300),
  created_at timestamptz not null default now(),
  unique (review_id, reporter_user_id)
);

-- ---------------------------------------------------------------------------
-- Triggers: normalisation, immutable keys, "edited" timestamps, ownership
-- ---------------------------------------------------------------------------

create or replace function public.trim_text(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(value, '^\s+|\s+$', '', 'g');
$$;

-- Ratings: keep owner, movie and creation date; bump updated_at.
create or replace function public.ratings_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
    new.tmdb_movie_id := old.tmdb_movie_id;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists ratings_before_write on public.ratings;
create trigger ratings_before_write
  before insert or update on public.ratings
  for each row execute function public.ratings_before_write();

-- Reviews: trim content; updated_at only moves when the text or the
-- spoiler flag changes, so it can drive the "edited" indicator.
create or replace function public.reviews_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.content := public.trim_text(new.content);

  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := new.created_at;
    return new;
  end if;

  new.user_id := old.user_id;
  new.tmdb_movie_id := old.tmdb_movie_id;
  new.created_at := old.created_at;
  if new.content is distinct from old.content
     or new.spoiler is distinct from old.spoiler then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

drop trigger if exists reviews_before_write on public.reviews;
create trigger reviews_before_write
  before insert or update on public.reviews
  for each row execute function public.reviews_before_write();

create or replace function public.review_likes_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.reviews r
    where r.id = new.review_id and r.user_id = new.user_id
  ) then
    raise exception 'own_review_like'
      using hint = 'You cannot like your own review.';
  end if;
  return new;
end;
$$;

drop trigger if exists review_likes_before_insert on public.review_likes;
create trigger review_likes_before_insert
  before insert on public.review_likes
  for each row execute function public.review_likes_before_insert();

create or replace function public.review_reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.reason := public.trim_text(new.reason);
  if exists (
    select 1 from public.reviews r
    where r.id = new.review_id and r.user_id = new.reporter_user_id
  ) then
    raise exception 'own_review_report'
      using hint = 'You cannot report your own review.';
  end if;
  return new;
end;
$$;

drop trigger if exists review_reports_before_insert on public.review_reports;
create trigger review_reports_before_insert
  before insert on public.review_reports
  for each row execute function public.review_reports_before_insert();

-- ---------------------------------------------------------------------------
-- Authorisation
-- ---------------------------------------------------------------------------

-- True when the caller is an administrator. The real definition belongs to
-- User Management (20261113_user_management_profiles.sql, profiles.role).
-- This fallback is created only when no is_admin() exists yet, so this file
-- never replaces it; until then it reads profiles.role if that column exists.
do $do$
begin
  if to_regprocedure('public.is_admin()') is null then
    create function public.is_admin()
    returns boolean
    language plpgsql
    stable
    security definer
    set search_path = ''
    as $fn$
    declare
      result boolean := false;
    begin
      if auth.uid() is null then
        return false;
      end if;
      if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'profiles'
          and column_name = 'role'
      ) then
        execute 'select role = ''admin'' from public.profiles where id = $1'
          into result
          using auth.uid();
      end if;
      return coalesce(result, false);
    end;
    $fn$;
    grant execute on function public.is_admin() to authenticated;
  end if;
end;
$do$;

alter table public.ratings enable row level security;
alter table public.reviews enable row level security;
alter table public.review_likes enable row level security;
alter table public.review_reports enable row level security;

drop policy if exists "Users manage their own reviews" on public.reviews;

-- Ratings: public read (community averages), owner writes.
drop policy if exists "Ratings are public" on public.ratings;
create policy "Ratings are public"
on public.ratings for select
to anon, authenticated
using (true);

drop policy if exists "Users insert their own ratings" on public.ratings;
create policy "Users insert their own ratings"
on public.ratings for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own ratings" on public.ratings;
create policy "Users update their own ratings"
on public.ratings for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete their own ratings" on public.ratings;
create policy "Users delete their own ratings"
on public.ratings for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Reviews: public read, owner writes, owner or admin deletes.
drop policy if exists "Reviews are public" on public.reviews;
create policy "Reviews are public"
on public.reviews for select
to anon, authenticated
using (true);

drop policy if exists "Users insert their own reviews" on public.reviews;
create policy "Users insert their own reviews"
on public.reviews for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own reviews" on public.reviews;
create policy "Users update their own reviews"
on public.reviews for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Authors and admins delete reviews" on public.reviews;
create policy "Authors and admins delete reviews"
on public.reviews for delete
to authenticated
using ((select auth.uid()) = user_id or (select public.is_admin()));

-- Likes: each user sees and manages only their own likes; counts are
-- exposed through public.get_reviews.
drop policy if exists "Users read their own likes" on public.review_likes;
create policy "Users read their own likes"
on public.review_likes for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users like reviews" on public.review_likes;
create policy "Users like reviews"
on public.review_likes for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users unlike reviews" on public.review_likes;
create policy "Users unlike reviews"
on public.review_likes for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Reports: write-only for users (they can see their own reports).
drop policy if exists "Users read their own reports" on public.review_reports;
create policy "Users read their own reports"
on public.review_reports for select
to authenticated
using ((select auth.uid()) = reporter_user_id);

drop policy if exists "Users report reviews" on public.review_reports;
create policy "Users report reviews"
on public.review_reports for insert
to authenticated
with check ((select auth.uid()) = reporter_user_id);

-- ---------------------------------------------------------------------------
-- Read API
-- ---------------------------------------------------------------------------

-- Community rating of a movie, the caller's score and the review count.
create or replace function public.get_movie_rating_summary(p_movie_id integer)
returns json
language sql
stable
security invoker
set search_path = ''
as $$
  select json_build_object(
    'tmdb_movie_id', p_movie_id,
    'average', coalesce(round(avg(r.score)::numeric, 1), 0),
    'count', count(*),
    'distribution', json_build_array(
      count(*) filter (where r.score = 1),
      count(*) filter (where r.score = 2),
      count(*) filter (where r.score = 3),
      count(*) filter (where r.score = 4),
      count(*) filter (where r.score = 5)
    ),
    'my_score', (
      select m.score from public.ratings m
      where m.tmdb_movie_id = p_movie_id and m.user_id = auth.uid()
    ),
    'review_count', (
      select count(*) from public.reviews v where v.tmdb_movie_id = p_movie_id
    )
  )
  from public.ratings r
  where r.tmdb_movie_id = p_movie_id;
$$;

-- Reviews of a movie (p_movie_id) and/or of an author (p_author), with the
-- author's score, like count and author name.
-- Sorts: recent | likes | highest | lowest. Unrated reviews come last in
-- rating sorts. total_count repeats the number of matching reviews.
create or replace function public.get_reviews(
  p_movie_id integer default null,
  p_author uuid default null,
  p_sort text default 'recent',
  p_page integer default 1,
  p_page_size integer default 10
)
returns table (
  id bigint,
  tmdb_movie_id integer,
  user_id uuid,
  content text,
  spoiler boolean,
  score smallint,
  like_count bigint,
  liked_by_me boolean,
  edited boolean,
  author_name text,
  author_avatar_url text,
  created_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  page_size integer := least(greatest(coalesce(p_page_size, 10), 1), 100);
  page_number integer := greatest(coalesce(p_page, 1), 1);
begin
  if p_movie_id is null and p_author is null then
    raise exception 'get_reviews needs a movie or an author';
  end if;
  if coalesce(p_sort, 'recent') not in ('recent', 'likes', 'highest', 'lowest') then
    raise exception 'unknown sort %', p_sort;
  end if;

  return query
  with base as (
    select
      v.*,
      rt.score as rating_score,
      (select count(*) from public.review_likes l where l.review_id = v.id) as likes
    from public.reviews v
    left join public.ratings rt
      on rt.user_id = v.user_id and rt.tmdb_movie_id = v.tmdb_movie_id
    where (p_movie_id is null or v.tmdb_movie_id = p_movie_id)
      and (p_author is null or v.user_id = p_author)
  )
  select
    b.id,
    b.tmdb_movie_id,
    b.user_id,
    b.content,
    b.spoiler,
    b.rating_score,
    b.likes,
    exists (
      select 1 from public.review_likes l
      where l.review_id = b.id and l.user_id = auth.uid()
    ),
    b.updated_at > b.created_at + interval '1 second',
    case
      when p.id is null then 'Deleted user'
      else coalesce(
        nullif(public.trim_text(p.display_name), ''),
        nullif(public.trim_text(p.username), ''),
        'Movie fan'
      )
    end,
    p.avatar_url,
    b.created_at,
    b.updated_at,
    count(*) over ()
  from base b
  left join public.profiles p on p.id = b.user_id
  order by
    case when p_sort = 'likes' then b.likes end desc nulls last,
    case when p_sort = 'highest' then coalesce(b.rating_score, 0) end desc nulls last,
    case when p_sort = 'lowest' then coalesce(b.rating_score, 6) end asc nulls last,
    b.created_at desc,
    b.id desc
  limit page_size
  offset (page_number - 1) * page_size;
end;
$$;

grant execute on function public.get_movie_rating_summary(integer) to anon, authenticated;
grant execute on function public.get_reviews(integer, uuid, text, integer, integer) to anon, authenticated;
