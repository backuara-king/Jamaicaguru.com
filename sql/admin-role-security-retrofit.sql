-- ============================================================================
-- SECURITY RETROFIT — must run before customer accounts go live
-- ----------------------------------------------------------------------------
-- Today, every admin page only checks "is someone logged in", not "is this
-- person actually an admin" — safe only because the only Supabase Auth users
-- that exist are you. Customer accounts change that: a logged-in customer
-- would satisfy the same checks and could reach the admin dashboard.
--
-- This creates a real admin allowlist and a is_admin() helper, and updates
-- every RLS policy from this session (partner_properties, partner_drivers,
-- partner_excursions) to require it instead of just "any logged-in user".
-- ============================================================================

create table if not exists admin_users (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);
alter table admin_users enable row level security;
-- Deliberately no policies at all — nobody reads/writes this table directly
-- through the client. is_admin() below reads it as SECURITY DEFINER instead.

create or replace function is_admin() returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from admin_users where user_id = auth.uid());
$$;
grant execute on function is_admin() to authenticated, anon;

-- ---------- Register yourself as the admin ----------
-- Run this SELECT first to find your own user id:
--   select id, email from auth.users;
-- Then insert it here (replace the placeholder):
-- insert into admin_users (user_id) values ('paste-your-user-id-here');

-- ---------- Tighten the 3 tables from this session ----------
drop policy if exists "authenticated full access to properties" on partner_properties;
create policy "admin full access to properties" on partner_properties
  for all using (is_admin()) with check (is_admin());

drop policy if exists "authenticated full access to drivers" on partner_drivers;
create policy "admin full access to drivers" on partner_drivers
  for all using (is_admin()) with check (is_admin());

drop policy if exists "authenticated full access to excursions" on partner_excursions;
create policy "admin full access to excursions" on partner_excursions
  for all using (is_admin()) with check (is_admin());

-- ---------- Find anything else using the same loose pattern ----------
-- bookings, experiences, addons, and reviews predate this session, so I
-- don't know their exact policy names/definitions. Run this and share the
-- output so the exact fix can be written for each:
select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
