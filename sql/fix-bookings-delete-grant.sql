-- ============================================================================
-- Fix: admin dashboard got "permission denied for table bookings" when
-- deleting a booking. SELECT/UPDATE already work (that's how the booking
-- list and status changes function), but DELETE was never explicitly
-- granted to the authenticated role — same class of gotcha as the earlier
-- service_role grant fix.
-- ============================================================================

grant delete on public.bookings to authenticated;
