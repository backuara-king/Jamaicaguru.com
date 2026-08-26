# Setting up customer accounts

Do these in order. Steps 1–2 only need to happen once, ever.

## 1. Run the SQL

In Supabase SQL Editor, run (in this order — copy from the actual files, not
from a chat window, to avoid smart-quote corruption):

1. `sql/admin-role-security-retrofit.sql` — then follow the comment inside it
   to register yourself as admin (run `select id, email from auth.users;`,
   copy your id, and run the `insert into admin_users ...` line with it).
2. `sql/customer-accounts-schema.sql`

## 2. Connect Resend for email

1. Sign up free at resend.com (3,000 emails/month free tier).
2. Add and verify your domain (Resend walks you through adding a couple of
   DNS records) — or use their sandbox sender for testing first.
3. Create an API key (Resend dashboard → API Keys).
4. In Supabase: **Project Settings → Authentication → SMTP Settings** →
   enable custom SMTP:
   - Host: `smtp.resend.com`
   - Port: `465`
   - Username: `resend`
   - Password: *(your Resend API key)*
   - Sender email: something on your verified domain, e.g.
     `accounts@jamaicaguru.com` (or Resend's sandbox address while testing)
   - Sender name: `Jamaica Guru`

## 3. Customize the invite email

**Supabase → Authentication → Email Templates → Invite user.** Replace the
default text with something like:

> Subject: Finish setting up your Jamaica Guru account
>
> Hi {{ .Data.first_name }},
>
> Your trip is booked! Finish setting up your Jamaica Guru account to see
> your itinerary, excursion details, and everything else — [Set up my
> account]({{ .ConfirmationURL }}).

(`{{ .ConfirmationURL }}` is Supabase's placeholder for the actual signed
link — leave it as-is, just wrap your own link text/button around it.)

## 4. Deploy the Edge Function

You need the Supabase CLI installed once (`npm install -g supabase`, or see
supabase.com/docs/guides/cli for other install methods), then from this
repo's root:

```
supabase login
supabase link --project-ref fgzfpeewbcccxaakpmty
supabase functions deploy create-customer-account
```

No extra secrets to set — `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
automatically available inside every Edge Function.

(If your Supabase project's dashboard has an Edge Functions section with an
in-browser code editor, you can paste `index.ts`'s contents there instead —
check Edge Functions in the left sidebar first before installing the CLI.)

## 5. Wire it up as a Database Webhook

**Supabase → Database → Webhooks → Create a new webhook.**
- Name: `create-customer-account`
- Table: `bookings`
- Events: `Update` only
- Type: `Supabase Edge Functions`
- Edge Function: `create-customer-account`

That's it — Supabase signs and sends the request automatically, no secrets
to wire up by hand. The function itself checks whether this particular
update actually just flipped status to "confirmed" before doing anything,
so it's safe that it fires on every booking edit.

## Testing it

In admin → Bookings, open a booking with a real email you can check, and
change its status to **Confirmed**. Within a few seconds you should get the
invite email. Click through, set a password, and you should land on
`my-trip.html` showing that booking.
