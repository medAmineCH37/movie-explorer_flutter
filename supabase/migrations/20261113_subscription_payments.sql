alter table public.subscriptions
  add column if not exists amount_paid numeric(10, 2) not null default 0,
  add column if not exists refund_amount numeric(10, 2) not null default 0,
  add column if not exists card_brand text,
  add column if not exists card_last4 text;

update public.subscriptions
set amount_paid = case plan when 'monthly' then 9.99 else 99.99 end
where amount_paid = 0;
