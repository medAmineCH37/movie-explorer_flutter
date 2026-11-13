alter table public.profiles
  add column if not exists email text,
  add column if not exists role text not null default 'user',
  add column if not exists valide boolean not null default true,
  add column if not exists is_subscribed boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('user', 'admin'));
  end if;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Admins can read all profiles" on public.profiles;
create policy "Admins can read all profiles"
on public.profiles for select
to authenticated
using ((select public.is_admin()));

drop policy if exists "Admins can update profiles" on public.profiles;
create policy "Admins can update profiles"
on public.profiles for update
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = id);

create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not (select public.is_admin()) then
    if tg_op = 'INSERT' then
      if new.role <> 'user' or not new.valide or new.is_subscribed then
        raise exception 'Only an administrator can set profile privileges';
      end if;
    elsif new.role is distinct from old.role
       or new.valide is distinct from old.valide
       or new.is_subscribed is distinct from old.is_subscribed then
      raise exception 'Only an administrator can change profile privileges';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_profile_privilege_escalation on public.profiles;
create trigger prevent_profile_privilege_escalation
before insert or update on public.profiles
for each row execute function public.prevent_profile_privilege_escalation();