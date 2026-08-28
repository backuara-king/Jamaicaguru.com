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

## 4. Set the RESEND_API_KEY secret (booking confirmation email)

The function sends the booking-confirmation email (trip details) via
Resend's API directly, separate from the account-setup email Supabase Auth
sends via SMTP. It needs its own copy of the API key as a function secret:

- **If using the dashboard's Edge Functions editor**: look for a
  "Secrets" / "Environment Variables" section for the function and add
  `RESEND_API_KEY` = *(the same Resend API key from step 2)*.
- **If using the CLI**: `supabase secrets set RESEND_API_KEY=re_xxxxx`

Without this secret the function still runs fine — it just skips the
confirmation email and only sends the account-setup one.

The confirmation email sends from `bookings@jamaicaguru.com` — that address
doesn't need to be a real inbox, just on your verified domain. Change the
`from` line in `index.ts` if you want a different address.

## 5. Deploy the Edge Function

You need the Supabase CLI installed once (`npm install -g supabase`, or see
supabase.com/docs/guides/cli for other install methods), then from this
repo's root:

```
supabase login
supabase link --project-ref fgzfpeewbcccxaakpmty
supabase functions deploy create-customer-account
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available
inside every Edge Function — no need to set those yourself.

(If your Supabase project's dashboard has an Edge Functions section with an
in-browser code editor, you can paste `index.ts`'s contents there instead —
check Edge Functions in the left sidebar first before installing the CLI.
That's how this was actually deployed the first time.)

## 6. Wire it up so it actually fires

The dashboard's **Database → Webhooks** feature errors on this project
(`schema "supabase_functions" does not exist`), so this is wired via a
direct SQL trigger instead — already set up if you ran
**`sql/customer-account-webhook-fallback.sql`**. That trigger calls this
function whenever a booking's status flips to "confirmed". Nothing to redo
here unless you haven't run that file yet.

## Testing it

In admin → Bookings, open a booking with a real email you can check
(a fresh one it hasn't already sent to — repeat emails to the same address
only get the confirmation email, not a second account-setup email), and
change its status to **Confirmed**. Within a few seconds to a minute you
should get two emails: the trip confirmation, and the account-setup invite.
Click the invite link, set a password, and you should land on
`my-trip.html` showing that booking.
