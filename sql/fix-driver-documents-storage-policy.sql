-- ============================================================================
-- Same fix as driver-images, applied to driver-documents (license photos).
-- Kept private on purpose — no public/anon read policy here, only
-- authenticated (admin) gets access, since these are ID documents.
-- Admin views them via a signed URL (createSignedUrl), which works
-- regardless of this bucket being private.
-- ============================================================================

drop policy if exists "authenticated full access to driver-documents" on storage.objects;
create policy "authenticated full access to driver-documents" on storage.objects
  for all
  to authenticated
  using (bucket_id = 'driver-documents')
  with check (bucket_id = 'driver-documents');
