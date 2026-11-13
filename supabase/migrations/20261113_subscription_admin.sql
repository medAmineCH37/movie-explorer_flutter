drop policy if exists "Admins manage all subscriptions" on public.subscriptions;
create policy "Admins manage all subscriptions"
on public.subscriptions for all
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));
