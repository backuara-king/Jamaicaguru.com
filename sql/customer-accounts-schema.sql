-- ============================================================================
-- Jamaica Guru — Customer Accounts
-- Run this AFTER admin-role-security-retrofit.sql (that one is a prerequisite —
-- it's what stops a customer account from being able to reach the admin
-- dashboard once accounts like this start existing).
-- ============================================================================

alter table bookings add column if not exists customer_user_id uuid references auth.users(id);

-- A customer can read their own bookings (any booking under their account),
-- but nothing else — no update/delete/insert access for customers at all.
-- This is additive: it doesn't touch whatever policy already lets checkout
-- insert new bookings or lets admin manage them.
drop policy if exists "customers read own bookings" on bookings;
create policy "customers read own bookings" on bookings
  for select using (auth.uid() = customer_user_id);
