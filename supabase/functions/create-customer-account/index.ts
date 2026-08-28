// Jamaica Guru — create-customer-account
//
// Triggered by a Supabase Database Webhook on `bookings` UPDATE (set up in
// the dashboard under Database → Webhooks — see README.md in this folder).
// When a booking's status just became "confirmed", this:
//   1. Sends a booking-confirmation email with the trip details, via
//      Resend's API directly (every confirmation, every time — including
//      repeat customers).
//   2. Finds or creates a Supabase Auth user for the guest's email and
//      sends them the "finish setting up your account" invite email
//      (via Supabase Auth's own email system, using whatever SMTP is
//      configured in Auth settings) — only for accounts that don't
//      already exist, so a repeat customer isn't re-invited every trip.
//   3. Links that user id onto every booking under that email that isn't
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
    if (!record.email) {
      return json({ skipped: true, reason: 'booking has no email' });
    }

    const results = {};

    // ---------- 1. Booking confirmation email (always, every confirmation) ----------
    try {
      results.confirmationEmail = await sendBookingConfirmationEmail(record);
    } catch (err) {
      console.error('confirmation email failed:', err);
      results.confirmationEmail = { error: String(err) };
    }

    // ---------- 2 & 3. Account creation/link (skipped if already linked) ----------
    if (record.customer_user_id) {
      results.account = { skipped: true, reason: 'already linked to an account' };
    } else {
      try {
        results.account = await ensureCustomerAccount(record);
      } catch (err) {
        console.error('account creation failed:', err);
        results.account = { error: String(err) };
      }
    }

    return json({ ok: true, ...results });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});

async function ensureCustomerAccount(record) {
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

  let newAccount = false;
  if (!userId) {
    const { data: invited, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, {
      data: {
        first_name: record.first_name || null,
        last_name: record.last_name || null,
        phone: record.phone || null
      },
      redirectTo: 'https://www.jamaicaguru.com/set-password.html'
    });
    if (inviteErr) throw inviteErr;
    userId = invited.user.id;
    newAccount = true;
  }

  const { error: updateErr } = await admin
    .from('bookings')
    .update({ customer_user_id: userId })
    .eq('email', record.email)
    .is('customer_user_id', null);
  if (updateErr) throw updateErr;

  return { ok: true, userId, newAccount };
}

async function sendBookingConfirmationEmail(record) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  if (!resendApiKey) {
    return { skipped: true, reason: 'RESEND_API_KEY not set' };
  }

  const firstName = record.first_name || 'there';
  const fmtMoney = (n) => '$' + Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const fmtDate = (iso) => {
    if (!iso) return '—';
    const d = new Date(iso + 'T00:00:00');
    return isNaN(d) ? iso : d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
  };
  const due = record.payment_method === 'full' ? Number(record.total) : Number(record.due_today);
  const remaining = Number(record.total || 0) - due;

  const detailRow = (label, value) => value
    ? `<tr><td style="padding:10px 0;border-bottom:1px solid #e3e8ed;color:#5b6472;font-size:13px;">${label}</td><td style="padding:10px 0;border-bottom:1px solid #e3e8ed;color:#1c2430;font-size:13px;font-weight:600;text-align:right;">${value}</td></tr>`
    : '';

  const html = `
  <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px 20px;color:#1c2430;">
    <div style="text-align:center;margin-bottom:28px;">
      <div style="font-size:22px;font-weight:800;color:#8040ff;">🌴 Jamaica Guru</div>
    </div>
    <h1 style="font-size:22px;margin:0 0 6px;">You're confirmed, ${firstName}!</h1>
    <p style="color:#5b6472;font-size:14px;line-height:1.6;margin:0 0 24px;">
      Your trip is officially booked. Here's a summary — we'll follow up separately with an email to set up
      your Jamaica Guru account, where you can see your full itinerary and excursion details any time.
    </p>
    <table style="width:100%;border-collapse:collapse;margin-bottom:24px;">
      ${detailRow('Booking reference', record.booking_ref)}
      ${detailRow('Package', record.package_name)}
      ${detailRow('Arrival', fmtDate(record.arrival_date))}
      ${detailRow('Departure', fmtDate(record.depart_date))}
      ${detailRow('Guests', record.guests)}
      ${detailRow('Paid today', fmtMoney(due))}
      ${detailRow('Remaining balance', fmtMoney(remaining))}
    </table>
    <p style="color:#5b6472;font-size:13px;line-height:1.6;">
      Questions before your trip? Just reply to this email or reach us at
      <a href="mailto:info@jamaicaguru.com" style="color:#8040ff;">info@jamaicaguru.com</a>.
    </p>
    <p style="color:#9aa1ac;font-size:12px;margin-top:32px;text-align:center;">Jamaica Guru &middot; Kingston &amp; Negril, Jamaica</p>
  </div>`;

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: 'Jamaica Guru <bookings@jamaicaguru.com>',
      to: record.email,
      subject: `You're confirmed! ${record.booking_ref} — Jamaica Guru`,
      html
    })
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Resend API ${res.status}: ${text}`);
  }
  return { ok: true };
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}
