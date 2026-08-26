-- ============================================================================
-- Jamaica Guru — Partners: Transportation (Phase 2)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- ============================================================================

-- ---------- 1. The drivers table itself ----------
create table if not exists partner_drivers (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  age                   int,
  email                 text,
  phone                 text,
  tour_company_name     text,   -- their own company, if any
  affiliation           text,   -- e.g. JUTA, Maxi Tours, Independent
  years_of_service      int,
  vehicle_type          text,   -- e.g. "Toyota Noah", "Sedan"
  vehicle_color         text,
  license_plate         text,
  profile_photo_url     text,             -- public — shown to guests pre-arrival
  vehicle_images        text[] not null default '{}',  -- public — shown to guests pre-arrival
  license_front_path    text,             -- PRIVATE bucket object path — driver's license, admin-only
  license_back_path     text,             -- PRIVATE bucket object path — driver's license, admin-only
  bank_name             text,             -- admin-only, never exposed to any public RPC
  bank_account_name     text,
  bank_account_number   text,
  status                text not null default 'applied' check (status in ('applied', 'processing', 'approved', 'assigned')),
  applicant_notes       text,
  rating_avg            numeric,
  rating_count          int not null default 0,
  created_at            timestamptz not null default now()
);

alter table partner_drivers enable row level security;

-- Admin-only. Unlike partner_properties, there is no public "read active
-- drivers" policy — a driver's profile carries private fields (banking
-- info, license paths), so the public site never queries this table
-- directly. Guests only ever see the safe subset via get_driver_intro().
drop policy if exists "authenticated full access to drivers" on partner_drivers;
create policy "authenticated full access to drivers" on partner_drivers
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant select, insert, update, delete on partner_drivers to authenticated;

-- ---------- 2. Storage buckets ----------
-- Dashboard → Storage → New bucket:
--   "driver-images"     — Public bucket: ON   (profile photo + vehicle photos)
--   "driver-documents"  — Public bucket: OFF  (license front/back — stays private)
-- Then Storage → driver-images → Policies: mirror the policies on your
-- existing "property-images"/"addon-images" buckets (public read + authenticated upload).
-- Storage → driver-documents → Policies: add ONE policy — authenticated
-- users get full access (select/insert/update/delete) — and nothing for anon.

-- ---------- 3. Link bookings to a driver + two tokens (intro page, review survey) ----------
alter table bookings add column if not exists driver_id uuid references partner_drivers(id);
-- Generated as soon as a driver is assigned to a booking, regardless of
-- trip status — this is what powers the pre-arrival "Meet your Guru" page.
alter table bookings add column if not exists driver_intro_token uuid;
-- Generated only once the trip is completed — the post-trip rating survey.
alter table bookings add column if not exists driver_review_token uuid;
alter table bookings add column if not exists driver_review_submitted boolean not null default false;

create table if not exists driver_reviews (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid references bookings(id) on delete set null,
  driver_id     uuid not null references partner_drivers(id) on delete cascade,
  rating        int not null check (rating between 1 and 5),
  comment       text,
  submitted_at  timestamptz not null default now()
);

alter table driver_reviews enable row level security;
drop policy if exists "no direct access" on driver_reviews;
create policy "no direct access" on driver_reviews for all using (false) with check (false);

create or replace function jg_gen_driver_intro_token() returns trigger
language plpgsql as $$
begin
  if new.driver_id is not null and new.driver_intro_token is null then
    new.driver_intro_token := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_driver_intro_token on bookings;
create trigger trg_driver_intro_token
  before insert or update on bookings
  for each row execute function jg_gen_driver_intro_token();

create or replace function jg_gen_driver_review_token() returns trigger
language plpgsql as $$
begin
  if new.driver_id is not null and new.status = 'completed' and new.driver_review_token is null then
    new.driver_review_token := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_driver_review_token on bookings;
create trigger trg_driver_review_token
  before insert or update on bookings
  for each row execute function jg_gen_driver_review_token();

create or replace function jg_recompute_driver_rating() returns trigger
language plpgsql as $$
declare
  target_id uuid := coalesce(new.driver_id, old.driver_id);
begin
  update partner_drivers p set
    rating_count = sub.cnt,
    rating_avg = sub.avg_rating
  from (
    select count(*) as cnt, avg(rating)::numeric(3,2) as avg_rating
    from driver_reviews where driver_id = target_id
  ) sub
  where p.id = target_id;

  update partner_drivers set rating_avg = null, rating_count = 0
  where id = target_id and not exists (select 1 from driver_reviews where driver_id = target_id);

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_driver_rating on driver_reviews;
create trigger trg_driver_rating
  after insert or update or delete on driver_reviews
  for each row execute function jg_recompute_driver_rating();

-- ---------- 4. Public "Meet your Guru" RPC — safe subset only ----------
-- Deliberately excludes email/phone/banking/license fields.
create or replace function get_driver_intro(p_token uuid)
returns table (
  first_name text, driver_name text, profile_photo_url text, vehicle_images text[],
  years_of_service int, vehicle_type text, vehicle_color text, license_plate text,
  tour_company_name text, affiliation text, rating_avg numeric, rating_count int
)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select b.first_name, d.name, d.profile_photo_url, d.vehicle_images,
           d.years_of_service, d.vehicle_type, d.vehicle_color, d.license_plate,
           d.tour_company_name, d.affiliation, d.rating_avg, d.rating_count
    from bookings b
    join partner_drivers d on d.id = b.driver_id
    where b.driver_intro_token = p_token;
end;
$$;
grant execute on function get_driver_intro(uuid) to anon, authenticated;

-- ---------- 5. Public survey RPCs (used by submit-driver-review.html) ----------
create or replace function get_driver_review_request(p_token uuid)
returns table (already_submitted boolean, first_name text, driver_name text)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select b.driver_review_submitted, b.first_name, d.name
    from bookings b
    join partner_drivers d on d.id = b.driver_id
    where b.driver_review_token = p_token;
end;
$$;
grant execute on function get_driver_review_request(uuid) to anon, authenticated;

create or replace function submit_driver_review(p_token uuid, p_rating int, p_comment text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  b bookings%rowtype;
begin
  select * into b from bookings where driver_review_token = p_token;
  if not found then
    raise exception 'Invalid or expired link.';
  end if;
  if b.driver_review_submitted then
    raise exception 'A rating has already been submitted for this trip.';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  insert into driver_reviews (booking_id, driver_id, rating, comment)
  values (b.id, b.driver_id, p_rating, p_comment);

  update bookings set driver_review_submitted = true where id = b.id;
end;
$$;
grant execute on function submit_driver_review(uuid, int, text) to anon, authenticated;

-- ---------- 6. Public "Become a Partner" application RPC (drivers) ----------
create or replace function submit_driver_partner_application(
  p_name text, p_age int, p_email text, p_phone text,
  p_tour_company_name text, p_affiliation text, p_years_of_service int,
  p_vehicle_type text, p_vehicle_color text, p_license_plate text,
  p_applicant_notes text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_name is null or trim(p_name) = '' then raise exception 'Name is required.'; end if;
  if p_email is null or trim(p_email) = '' then raise exception 'Email is required.'; end if;
  if p_phone is null or trim(p_phone) = '' then raise exception 'Phone is required.'; end if;

  -- status is always forced to 'applied' — applications only ever
  -- progress from here through admin action in Partners.
  insert into partner_drivers (
    name, age, email, phone, tour_company_name, affiliation, years_of_service,
    vehicle_type, vehicle_color, license_plate, applicant_notes, status
  ) values (
    p_name, p_age, p_email, p_phone, p_tour_company_name, p_affiliation, p_years_of_service,
    p_vehicle_type, p_vehicle_color, p_license_plate, p_applicant_notes, 'applied'
  );
end;
$$;
grant execute on function submit_driver_partner_application(
  text, int, text, text, text, text, int, text, text, text, text
) to anon, authenticated;
