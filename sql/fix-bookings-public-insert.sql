-- ============================================================================
-- Fix: checkout can't insert a booking ("new row violates row-level security
-- policy for table bookings"). This adds a policy allowing anyone (a guest
-- checking out has no login) to insert a new booking row. Purely additive —
-- doesn't remove or change any existing policy on this table.
-- ============================================================================

drop policy if exists "public can insert bookings" on bookings;
create policy "public can insert bookings" on bookings
  for insert to anon, authenticated
  with check (true);

-- Diagnostic — run this too and share the output if the error persists
-- after the policy above; it shows every current rule on this table so
-- the actual conflicting one (if there is one) can be found precisely.
select policyname, cmd, roles, qual, with_check
from pg_policies
where tablename = 'bookings';
