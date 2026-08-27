-- ============================================================================
-- Fallback for wiring create-customer-account, since this project's Database
-- Webhooks UI errors with "schema supabase_functions does not exist".
-- This calls the Edge Function directly via pg_net instead, sending the same
-- payload shape a Database Webhook would — no changes needed to the function.
-- ============================================================================

create extension if not exists pg_net;

create or replace function jg_invoke_create_customer_account() returns trigger
language plpgsql as $$
begin
  if new.status = 'confirmed' and (old.status is distinct from 'confirmed') then
    perform net.http_post(
      url := 'https://fgzfpeewbcccxaakpmty.supabase.co/functions/v1/create-customer-account',
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

drop trigger if exists trg_invoke_create_customer_account on bookings;
create trigger trg_invoke_create_customer_account
  after update on bookings
  for each row execute function jg_invoke_create_customer_account();
