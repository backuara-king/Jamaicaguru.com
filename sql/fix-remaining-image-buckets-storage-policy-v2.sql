-- ============================================================================
-- Corrected version — the first attempt had a quoting bug (%L used for the
-- policy NAME, which needs identifier-quoting %I; %L is only right for the
-- bucket_id VALUE compared inside the policy expression). Use this file
-- instead of fix-remaining-image-buckets-storage-policy.sql.
--
-- Fixes the same folder-scoped-template storage RLS problem as
-- driver-images/driver-documents, applied to every remaining public image
-- bucket — property-images, addon-images, experience-images, and
-- excursion-images. All public read, since these are all meant to be
-- guest-facing photos. Safe to run even for a bucket that doesn't exist
-- yet (bucket_id is just a string match, not a foreign key).
-- ============================================================================

do $$
declare
  bucket text;
begin
  foreach bucket in array array['property-images', 'addon-images', 'experience-images', 'excursion-images']
  loop
    execute format('drop policy if exists %I on storage.objects', 'authenticated full access to ' || bucket);
    execute format(
      'create policy %I on storage.objects for all to authenticated using (bucket_id = %L) with check (bucket_id = %L)',
      'authenticated full access to ' || bucket, bucket, bucket
    );
    execute format('drop policy if exists %I on storage.objects', 'public read ' || bucket);
    execute format(
      'create policy %I on storage.objects for select using (bucket_id = %L)',
      'public read ' || bucket, bucket
    );
  end loop;
end $$;
