
-- User profiles, linked to Supabase Auth.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Automatically create a profile after registration.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Favorites.
create table public.favorites (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null,
  created_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

-- Watchlist.
create table public.watchlist (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null,
  created_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

-- Ratings and reviews.
create table public.reviews (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tmdb_movie_id integer not null,
  rating integer not null check (rating between 1 and 10),
  review_text text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, tmdb_movie_id)
);

-- User-created lists.
create table public.custom_lists (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);

-- Movies within custom lists.
create table public.custom_list_movies (
  list_id bigint not null references public.custom_lists(id) on delete cascade,
  tmdb_movie_id integer not null,
  added_at timestamptz not null default now(),
  primary key (list_id, tmdb_movie_id)
);

-- Enable Row Level Security.
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.watchlist enable row level security;
alter table public.reviews enable row level security;
alter table public.custom_lists enable row level security;
alter table public.custom_list_movies enable row level security;

-- Profiles: users can read and update their own profile.
create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- Favorites: users manage their own records.
create policy "Users manage their own favorites"
on public.favorites for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Watchlist: users manage their own records.
create policy "Users manage their own watchlist"
on public.watchlist for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Reviews: users manage their own reviews.
create policy "Users manage their own reviews"
on public.reviews for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Custom lists: users manage their own lists.
create policy "Users manage their own custom lists"
on public.custom_lists for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Custom-list movies: access only lists owned by the current user.
create policy "Users manage movies in their own lists"
on public.custom_list_movies for all
to authenticated
using (
  exists (
    select 1
    from public.custom_lists l
    where l.id = list_id
      and l.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.custom_lists l
    where l.id = list_id
      and l.user_id = (select auth.uid())
  )
);
