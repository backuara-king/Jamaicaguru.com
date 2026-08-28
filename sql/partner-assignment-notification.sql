-- ============================================================================
-- Jamaica Guru — email the customer when their property and/or Guru gets
-- assigned to their booking, with a link to view each.
-- ============================================================================

-- ---------- 1. Property intro token (mirrors driver_intro_token) ----------
-- Generated as soon as a property is assigned to a booking, regardless of
-- trip status — powers the public "Your Stay" page.
alter table bookings add column if not exists property_intro_token uuid;

create or replace function jg_gen_property_intro_token() returns trigger
language plpgsql as $$
begin
  if new.property_id is not null and new.property_intro_token is null then
    new.property_intro_token := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_property_intro_token on bookings;
create trigger trg_property_intro_token
  before insert or update on bookings
  for each row execute function jg_gen_property_intro_token();

-- ---------- 2. Public "Your Stay" RPC — safe property subset ----------
create or replace function get_property_intro(p_token uuid)
returns table (
  first_name text, property_name text, host_name text, location text,
  property_size text, bedrooms int, bathrooms numeric, beds int, max_guests int,
  has_kitchen boolean, has_pool boolean, gated_community boolean, amenities text[],
  airbnb_url text, images text[], rating_avg numeric, rating_count int
)
language plpgsql security definer set search_path = public as $$
begin
  return query
    select b.first_name, p.name, p.host_name, p.location, p.property_size, p.bedrooms, p.bathrooms,
           p.beds, p.max_guests, p.has_kitchen, p.has_pool, p.gated_community, p.amenities, p.airbnb_url,
           p.images, p.rating_avg, p.rating_count
    from bookings b
    join partner_properties p on p.id = b.property_id
    where b.property_intro_token = p_token;
end;
$$;
grant execute on function get_property_intro(uuid) to anon, authenticated;

-- ---------- 3. Trigger: notify whenever property_id or driver_id newly assigned ----------
-- Same pg_net-direct-call pattern as customer-account-webhook-fallback.sql,
-- since this project's Database Webhooks UI is broken.
create extension if not exists pg_net;

create or replace function jg_invoke_notify_partner_assigned() returns trigger
language plpgsql as $$
begin
  if (new.property_id is distinct from old.property_id and new.property_id is not null)
     or (new.driver_id is distinct from old.driver_id and new.driver_id is not null) then
    perform net.http_post(
      url := 'https://fgzfpeewbcccxaakpmty.supabase.co/functions/v1/notify-partner-assigned',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnemZwZWV3YmNjY3hhYWtwbXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1ODAxNzEsImV4cCI6MjEwMjE1NjE3MX0.YLj7ZCr3VRtXrhf_-4C__eyO5iAkrZvF9fZdJKpRqLs'
      ),
      body := jsonb_build_object(
        'type', 'UPDATE',
        'table', 'bookings',
        'record', to_jsonb(new),
        'old_record', to_jsonb(old)
      )
    );
  end if;
  return new;
end;
$$;

-- Runs AFTER the property/driver intro-token triggers above (both are
-- BEFORE triggers on the same event, so by the time this AFTER trigger
-- fires, new.property_intro_token / new.driver_intro_token are already
-- populated and safe to include in the notification payload.
drop trigger if exists trg_notify_partner_assigned on bookings;
create trigger trg_notify_partner_assigned
  after update on bookings
  for each row execute function jg_invoke_notify_partner_assigned();
