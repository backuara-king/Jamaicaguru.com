# Setting up the partner-assignment email

Sends the guest an email — with a link to view each — whenever their
property and/or Guru gets assigned to their booking.

## 1. Run the SQL

`sql/partner-assignment-notification.sql` — copy from the actual file (not
from a chat window) into Supabase SQL Editor and run it. This adds:
- `bookings.property_intro_token` (mirrors the existing `driver_intro_token`)
- `get_property_intro(token)` — the public RPC `my-stay.html` calls
- the trigger that calls this function whenever `property_id` or
  `driver_id` newly gets assigned

## 2. Deploy the function

Same as `create-customer-account`: paste `index.ts` into a new function
named `notify-partner-assigned` in Supabase's Edge Functions editor (or
`supabase functions deploy notify-partner-assigned` via the CLI).

## 3. Set its RESEND_API_KEY secret

Same Resend API key as the other function — add it as a secret for this
function too (function secrets aren't shared between functions, so this
needs setting again even though it's the same value).

## 4. No webhook needed

The SQL in step 1 already wires the trigger directly (same pg_net-based
approach as `create-customer-account`, since this project's Database
Webhooks dashboard feature is broken). Nothing to configure in the
dashboard.

## Testing it

In admin → Bookings, open a booking with a real email, and use the
"Property assigned" and/or "Guru (driver) assigned" dropdowns. Within a
few seconds to a minute you should get an email — with a "View Your Stay"
link and/or a "Meet Your Guru" link depending on what you assigned. Assign
the other one later and you'll get a second email with both links (the
email always reflects everything currently assigned, not just what
changed in that particular update).
