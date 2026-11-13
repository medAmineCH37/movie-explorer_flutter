-- Restores the AI review helpers (review-ai Edge Function): "Help me write it"
-- drafts and the AI summary of a movie's reviews.
-- Recreates the summary cache dropped by 20261113_remove_review_ai.sql.

create table if not exists public.review_summaries (
  tmdb_movie_id integer primary key check (tmdb_movie_id > 0),
  review_count integer not null,
  summary jsonb not null,
  generated_at timestamptz not null default now()
);

alter table public.review_summaries enable row level security;

-- Summary cache: public read; only the service role (Edge Function) writes.
drop policy if exists "Review summaries are public" on public.review_summaries;
create policy "Review summaries are public"
on public.review_summaries for select
to anon, authenticated
using (true);
