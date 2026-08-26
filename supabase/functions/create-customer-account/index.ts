// Jamaica Guru — create-customer-account
//
// Triggered by a Supabase Database Webhook on `bookings` UPDATE (set up in
// the dashboard under Database → Webhooks — see README.md in this folder).
// When a booking's status just became "confirmed", this:
//   1. Finds or creates a Supabase Auth user for the guest's email and
//      sends them the "finish setting up your account" invite email
//      (via whatever SMTP is configured in Auth settings).
//   2. Links that user id onto every booking under that email that isn't
//      linked yet, so repeat customers see every trip in one account.
//
// Uses the service-role key — which Supabase auto-injects into every Edge
// Function's environment — to call the Admin Auth API. This key must never
// be used anywhere client-side; that's exactly why this has to run here.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    const oldRecord = payload.old_record;

    if (!record || record.status !== 'confirmed') {
      return json({ skipped: true, reason: 'not confirmed' });
    }
    if (oldRecord && oldRecord.status === 'confirmed') {
      return json({ skipped: true, reason: 'already confirmed before this update' });
    }
    if (record.customer_user_id) {
      return json({ skipped: true, reason: 'already linked to an account' });
    }
    if (!record.email) {
      return json({ skipped: true, reason: 'booking has no email' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const email = record.email.trim().toLowerCase();
    let userId = null;

    // No direct "get user by email" in the admin API, so page through
    // existing users looking for a match — fine at this business's scale;
    // if the user base grows into the many thousands, maintain a lookup
    // table instead of paging on every confirmation.
    for (let page = 1; page <= 10 && !userId; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) throw error;
      const found = data.users.find(u => (u.email || '').toLowerCase() === email);
      if (found) userId = found.id;
      if (data.users.length < 200) break; // last page
    }

    if (!userId) {
      const { data: invited, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, {
        data: {
          first_name: record.first_name || null,
          last_name: record.last_name || null,
          phone: record.phone || null
        },
        redirectTo: 'https://jamaicaguru.com/set-password.html'
      });
      if (inviteErr) throw inviteErr;
      userId = invited.user.id;
    }

    const { error: updateErr } = await admin
      .from('bookings')
      .update({ customer_user_id: userId })
      .eq('email', record.email)
      .is('customer_user_id', null);
    if (updateErr) throw updateErr;

    return json({ ok: true, userId, newAccount: !record.customer_user_id });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}
