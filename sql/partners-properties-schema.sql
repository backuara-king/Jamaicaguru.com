-- ============================================================================
-- Jamaica Guru — Partners: Properties (Phase 1)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Kept here for reference — Supabase schema isn't otherwise tracked in this repo.
-- ============================================================================

-- ---------- 1. The properties table itself ----------
create table if not exists partner_properties (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  host_name         text,
  location          text,
  contact_email     text,
  contact_phone     text,
  property_size     text,
  bedrooms          int,
  bathrooms         numeric,
  beds              int,
  max_guests        int,
  has_kitchen       boolean not null default false,
  has_pool          boolean not null default false,
  gated_community   boolean not null default false,
  amenities         text[] not null default '{}',
  airbnb_url        text,
  images            text[] not null default '{}',
  status            text not null default 'pending' check (status in ('pending', 'active', 'inactive')),
  applicant_notes   text,       -- free text from the public "Become a Partner" application, for admin's eyes
  rating_avg        numeric,    -- kept in sync by the trigger below — don't edit by hand
  rating_count      int not null default 0,
  created_at        timestamptz not null default now()
);

alter table partner_properties enable row level security;

-- Public site can read active properties (for whenever they're surfaced
-- publicly); the admin dashboard authenticates via Supabase Auth, so it
-- needs its own broader policy.
drop policy if exists "public read active properties" on partner_properties;
create policy "public read active properties" on partner_properties
  for select using (status = 'active');

drop policy if exists "authenticated full access to properties" on partner_properties;
create policy "authenticated full access to properties" on partner_properties
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- RLS policies alone aren't enough — a table created via raw SQL (rather
-- than the Table Editor UI) doesn't automatically get table-level grants
-- for anon/authenticated the way the UI wizard sets up. Without these,
-- every query hits "permission denied for table partner_properties"
-- before RLS is even evaluated.
grant select, insert, update, delete on partner_properties to authenticated;
grant select on partner_properties to anon;

-- ---------- 2. Storage bucket for property photos ----------
-- Easiest done in the dashboard: Storage → New bucket → name it
-- "property-images" → Public bucket: ON. Then mirror whatever
-- upload/read policies you already have on the "addon-images" and
-- "experience-images" buckets (Storage → property-images → Policies).

-- ---------- 3. Link bookings to a property + a per-property survey token ----------
alter table bookings add column if not exists property_id uuid references partner_properties(id);
alter table bookings add column if not exists property_review_token uuid;
alter table bookings add column if not exists property_review_submitted boolean not null default false;

create table if not exists property_reviews (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid references bookings(id) on delete set null,
  property_id   uuid not null references partner_properties(id) on delete cascade,
  rating        int not null check (rating between 1 and 5),
  comment       text,
  submitted_at  timestamptz not null default now()
);

alter table property_reviews enable row level security;
-- No direct client access — all reads/writes go through the SECURITY DEFINER
-- RPC functions below, same pattern as this project's existing
-- get_review_request / submit_review functions.
drop policy if exists "no direct access" on property_reviews;
create policy "no direct access" on property_reviews for all using (false) with check (false);

-- Generates a property_review_token the moment a booking that has a
-- property assigned becomes (or already is, and only just got a property
-- assigned to it) "completed".
create or replace function jg_gen_property_review_token() returns trigger
language plpgsql as $$
begin
  if new.property_id is not null and new.status = 'completed' and new.property_review_token is null then
    new.property_review_token := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_property_review_token on bookings;
create trigger trg_property_review_token
  before insert or update on bookings
  for each row execute function jg_gen_property_review_token();

-- Keeps partner_properties.rating_avg / rating_count in sync whenever a
-- property_reviews row is inserted, updated, or deleted.
create or replace function jg_recompute_property_rating() returns trigger
language plpgsql as $$
declare
  target_id uuid := coalesce(new.property_id, old.property_id);
begin
  update partner_properties p set
    rating_count = sub.cnt,
    rating_avg = sub.avg_rating
  from (
    select count(*) as cnt, avg(rating)::numeric(3,2) as avg_rating
    from property_reviews where property_id = target_id
  ) sub
  where p.id = target_id;

  update partner_properties set rating_avg = null, rating_count = 0
  where id = target_id and not exists (select 1 from property_reviews where property_id = target_id);

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_property_rating on property_reviews;
create trigger trg_property_rating
  after insert or update or delete on property_reviews
  for each row execute function jg_recompute_property_rating();

-- ---------- 4. Public survey RPCs (used by submit-property-review.html) ----------
create or replace function get_property_review_request(p_token uuid)
returns table (already_submitted boolean, first_name text, property_name text)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select b.property_review_submitted, b.first_name, p.name
    from bookings b
    join partner_properties p on p.id = b.property_id
    where b.property_review_token = p_token;
end;
$$;
grant execute on function get_property_review_request(uuid) to anon, authenticated;

create or replace function submit_property_review(p_token uuid, p_rating int, p_comment text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  b bookings%rowtype;
begin
  select * into b from bookings where property_review_token = p_token;
  if not found then
    raise exception 'Invalid or expired link.';
  end if;
  if b.property_review_submitted then
    raise exception 'A rating has already been submitted for this stay.';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  insert into property_reviews (booking_id, property_id, rating, comment)
  values (b.id, b.property_id, p_rating, p_comment);

  update bookings set property_review_submitted = true where id = b.id;
end;
$$;
grant execute on function submit_property_review(uuid, int, text) to anon, authenticated;

-- ---------- 5. Public "Become a Partner" application RPC ----------
create or replace function submit_property_partner_application(
  p_name text, p_host_name text, p_location text, p_contact_email text, p_contact_phone text,
  p_bedrooms int, p_bathrooms numeric, p_beds int, p_max_guests int, p_property_size text,
  p_has_kitchen boolean, p_has_pool boolean, p_gated_community boolean,
  p_amenities text[], p_airbnb_url text, p_applicant_notes text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_name is null or trim(p_name) = '' then raise exception 'Property name is required.'; end if;
  if p_location is null or trim(p_location) = '' then raise exception 'Location is required.'; end if;
  if p_contact_email is null or trim(p_contact_email) = '' then raise exception 'Contact email is required.'; end if;

  -- status is always forced to 'pending' here regardless of caller input —
  -- applications only ever go live once an admin reviews them in Partners.
  insert into partner_properties (
    name, host_name, location, contact_email, contact_phone,
    bedrooms, bathrooms, beds, max_guests, property_size,
    has_kitchen, has_pool, gated_community, amenities, airbnb_url,
    applicant_notes, status
  ) values (
    p_name, p_host_name, p_location, p_contact_email, p_contact_phone,
    p_bedrooms, p_bathrooms, p_beds, p_max_guests, p_property_size,
    coalesce(p_has_kitchen, false), coalesce(p_has_pool, false), coalesce(p_gated_community, false),
    coalesce(p_amenities, '{}'), p_airbnb_url,
    p_applicant_notes, 'pending'
  );
end;
$$;
grant execute on function submit_property_partner_application(
  text, text, text, text, text, int, numeric, int, int, text,
  boolean, boolean, boolean, text[], text, text
) to anon, authenticated;
