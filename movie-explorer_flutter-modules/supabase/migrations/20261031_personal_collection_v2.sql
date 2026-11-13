-- Personal Collection 2.0: retain the existing Favorites and Watchlist tables.
-- Watching a movie removes it from Watchlist while Favorites remain independent.

alter table public.watchlist
  add column if not exists priority text not null default 'medium'
  check (priority in ('high', 'medium', 'low'));

create table if not exists public.watched_movies (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null,
  watched_at date not null default current_date,
  created_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

alter table public.watched_movies enable row level security;

drop policy if exists "Users manage their own watched movies"
  on public.watched_movies;
create policy "Users manage their own watched movies"
on public.watched_movies for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index if not exists watched_movies_user_watched_at_idx
  on public.watched_movies (user_id, watched_at desc);
