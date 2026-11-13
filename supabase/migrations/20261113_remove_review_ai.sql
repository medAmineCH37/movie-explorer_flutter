-- The AI review helpers (review-ai Edge Function) were removed from the
-- Ratings & Reviews module. Drop their summary cache on databases where an
-- earlier version of 20261111_ratings_reviews.sql created it.

drop table if exists public.review_summaries;
