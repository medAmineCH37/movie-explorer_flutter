alter table public.subscriptions
  add column if not exists credit_applied numeric(10, 2) not null default 0,
  add column if not exists credit_from bigint
    references public.subscriptions(id) on delete set null;
