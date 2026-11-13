alter table public.subscriptions
  add column if not exists stripe_session_id text unique,
  add column if not exists stripe_payment_intent text;

update public.subscriptions
set amount_paid = case plan when 'monthly' then 2.99 else 29.99 end
where stripe_payment_intent is null and amount_paid in (9.99, 99.99);

drop policy if exists "Users manage their own subscriptions"
  on public.subscriptions;
drop policy if exists "Users read their own subscriptions"
  on public.subscriptions;
create policy "Users read their own subscriptions"
on public.subscriptions for select
to authenticated
using ((select auth.uid()) = user_id);
