-- ============================================================================
-- Fix: Edge Function got "permission denied for table bookings" (42501) when
-- trying to link a booking to a newly created customer account. The
-- service_role key is supposed to bypass RLS entirely, but this table never
-- had explicit grants given to that role (same class of gotcha as the
-- earlier "permission denied for table partner_properties" issue).
-- ============================================================================

grant select, update on public.bookings to service_role;
