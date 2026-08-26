-- ============================================================================
-- Jamaica Guru — Partners: Excursions (Phase 3)
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- ============================================================================

-- ---------- 1. The excursion providers table itself ----------
create table if not exists partner_excursions (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,   -- provider / company name
  excursion_types   text,            -- free text, e.g. "ATV, Zipline, Waterfall Tours"
  location          text,
  price             numeric,
  price_unit        text,            -- e.g. "per person", "per couple", "flat rate"
  contact_email     text,
  contact_phone     text,
  notes             text,            -- other relevant info
  images            text[] not null default '{}',
  status            text not null default 'pending' check (status in ('pending', 'active', 'inactive')),
  applicant_notes   text,
  rating_avg        numeric,
  rating_count      int not null default 0,
  created_at        timestamptz not null default now()
);

alter table partner_excursions enable row level security;

drop policy if exists "public read active excursions" on partner_excursions;
create policy "public read active excursions" on partner_excursions
  for select using (status = 'active');

drop policy if exists "authenticated full access to excursions" on partner_excursions;
create policy "authenticated full access to excursions" on partner_excursions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant select, insert, update, delete on partner_excursions to authenticated;
grant select on partner_excursions to anon;

-- ---------- 2. Storage bucket ----------
-- Dashboard → Storage → New bucket → "excursion-images" → Public bucket: ON.
-- Then mirror the policies on your existing "property-images" bucket.

-- ---------- 3. Link bookings to a "primary" excursion provider + review token ----------
alter table bookings add column if not exists excursion_provider_id uuid references partner_excursions(id);
alter table bookings add column if not exists excursion_review_token uuid;
alter table bookings add column if not exists excursion_review_submitted boolean not null default false;

create table if not exists excursion_reviews (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid references bookings(id) on delete set null,
  provider_id   uuid not null references partner_excursions(id) on delete cascade,
  rating        int not null check (rating between 1 and 5),
  comment       text,
  submitted_at  timestamptz not null default now()
);

alter table excursion_reviews enable row level security;
drop policy if exists "no direct access" on excursion_reviews;
create policy "no direct access" on excursion_reviews for all using (false) with check (false);

create or replace function jg_gen_excursion_review_token() returns trigger
language plpgsql as $$
begin
  if new.excursion_provider_id is not null and new.status = 'completed' and new.excursion_review_token is null then
    new.excursion_review_token := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_excursion_review_token on bookings;
create trigger trg_excursion_review_token
  before insert or update on bookings
  for each row execute function jg_gen_excursion_review_token();

create or replace function jg_recompute_excursion_rating() returns trigger
language plpgsql as $$
declare
  target_id uuid := coalesce(new.provider_id, old.provider_id);
begin
  update partner_excursions p set
    rating_count = sub.cnt,
    rating_avg = sub.avg_rating
  from (
    select count(*) as cnt, avg(rating)::numeric(3,2) as avg_rating
    from excursion_reviews where provider_id = target_id
  ) sub
  where p.id = target_id;

  update partner_excursions set rating_avg = null, rating_count = 0
  where id = target_id and not exists (select 1 from excursion_reviews where provider_id = target_id);

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_excursion_rating on excursion_reviews;
create trigger trg_excursion_rating
  after insert or update or delete on excursion_reviews
  for each row execute function jg_recompute_excursion_rating();

-- ---------- 4. Public survey RPCs (used by submit-excursion-review.html) ----------
create or replace function get_excursion_review_request(p_token uuid)
returns table (already_submitted boolean, first_name text, provider_name text)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select b.excursion_review_submitted, b.first_name, p.name
    from bookings b
    join partner_excursions p on p.id = b.excursion_provider_id
    where b.excursion_review_token = p_token;
end;
$$;
grant execute on function get_excursion_review_request(uuid) to anon, authenticated;

create or replace function submit_excursion_review(p_token uuid, p_rating int, p_comment text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  b bookings%rowtype;
begin
  select * into b from bookings where excursion_review_token = p_token;
  if not found then
    raise exception 'Invalid or expired link.';
  end if;
  if b.excursion_review_submitted then
    raise exception 'A rating has already been submitted for this trip.';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  insert into excursion_reviews (booking_id, provider_id, rating, comment)
  values (b.id, b.excursion_provider_id, p_rating, p_comment);

  update bookings set excursion_review_submitted = true where id = b.id;
end;
$$;
grant execute on function submit_excursion_review(uuid, int, text) to anon, authenticated;

-- ---------- 5. Public "Become a Partner" application RPC (excursion providers) ----------
create or replace function submit_excursion_partner_application(
  p_name text, p_excursion_types text, p_location text,
  p_contact_email text, p_contact_phone text,
  p_price numeric, p_price_unit text, p_applicant_notes text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_name is null or trim(p_name) = '' then raise exception 'Provider/company name is required.'; end if;
  if p_location is null or trim(p_location) = '' then raise exception 'Location is required.'; end if;
  if p_contact_email is null or trim(p_contact_email) = '' then raise exception 'Contact email is required.'; end if;

  insert into partner_excursions (
    name, excursion_types, location, contact_email, contact_phone,
    price, price_unit, applicant_notes, status
  ) values (
    p_name, p_excursion_types, p_location, p_contact_email, p_contact_phone,
    p_price, p_price_unit, p_applicant_notes, 'pending'
  );
end;
$$;
grant execute on function submit_excursion_partner_application(
  text, text, text, text, text, numeric, text, text
) to anon, authenticated;
