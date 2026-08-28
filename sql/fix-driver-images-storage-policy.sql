-- ============================================================================
-- Fix: uploading a driver profile/vehicle photo hits "new row violates
-- row-level security policy" even though a policy allowing insert/select/
-- update/delete already exists. Likely cause: the existing policy was
-- created from a template that scopes uploads to a per-user folder (e.g.
-- requiring the path to start with the uploader's user id), but this
-- app's code just uploads plain filenames — so the path never matches.
--
-- This adds a plain policy with no folder requirement. It's additive — it
-- doesn't touch whatever policy is already there, just adds another one
-- that will actually match (Postgres ORs multiple policies together for
-- the same operation).
-- ============================================================================

drop policy if exists "authenticated full access to driver-images" on storage.objects;
create policy "authenticated full access to driver-images" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'driver-images')
  with check (bucket_id = 'driver-images');

drop policy if exists "public read driver-images" on storage.objects;
create policy "public read driver-images" on storage.objects
  for select
  using (bucket_id = 'driver-images');
