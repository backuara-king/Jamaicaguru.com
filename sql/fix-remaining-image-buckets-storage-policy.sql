-- ============================================================================
-- Same fix as driver-images, applied to every remaining public image
-- bucket in this project — property-images (this one hit the error),
-- plus addon-images, experience-images, and excursion-images (set up the
-- same way, via the dashboard wizard, so they very likely have the same
-- folder-scoped-template problem even if not yet hit in testing). All
-- public read, since these are all meant to be guest-facing photos.
-- ============================================================================

do $$
declare
  bucket text;
begin
  foreach bucket in array array['property-images', 'addon-images', 'experience-images', 'excursion-images']
  loop
    execute format('drop policy if exists %L on storage.objects', 'authenticated full access to ' || bucket);
    execute format(
      'create policy %L on storage.objects for all to authenticated using (bucket_id = %L) with check (bucket_id = %L)',
      'authenticated full access to ' || bucket, bucket, bucket
    );
    execute format('drop policy if exists %L on storage.objects', 'public read ' || bucket);
    execute format(
      'create policy %L on storage.objects for select using (bucket_id = %L)',
      'public read ' || bucket, bucket
    );
  end loop;
end $$;
