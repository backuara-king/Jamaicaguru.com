// Jamaica Guru — notify-partner-assigned
//
// Triggered by a direct pg_net SQL trigger on `bookings` UPDATE (see
// sql/partner-assignment-notification.sql — this project's Database
// Webhooks dashboard feature is broken, so this is wired the same way as
// create-customer-account's trigger).
//
// Fires whenever a booking's property_id or driver_id just got newly
// assigned (changed from something else to a real value). Sends the guest
// one email with a link to view whichever of "Your Stay" (property) and
// "Meet Your Guru" (driver) are CURRENTLY assigned on the booking — not
// just the one that changed in this particular update — so the email is
// always a complete, current picture even if the two get assigned on
// different days.

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    const oldRecord = payload.old_record;

    const propertyJustAssigned = record.property_id && record.property_id !== oldRecord?.property_id;
    const driverJustAssigned = record.driver_id && record.driver_id !== oldRecord?.driver_id;

    if (!propertyJustAssigned && !driverJustAssigned) {
      return json({ skipped: true, reason: 'no new property/driver assignment' });
    }
    if (!record.email) {
      return json({ skipped: true, reason: 'booking has no email' });
    }

    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (!resendApiKey) {
      return json({ skipped: true, reason: 'RESEND_API_KEY not set' });
    }

    const sections = [];
    if (record.property_id && record.property_intro_token) {
      sections.push({
        title: 'Your Stay',
        blurb: 'See your property\'s details, amenities, and photos.',
        url: `https://www.jamaicaguru.com/my-stay.html?token=${record.property_intro_token}`,
        cta: 'View Your Stay'
      });
    }
    if (record.driver_id && record.driver_intro_token) {
      sections.push({
        title: 'Meet Your Guru',
        blurb: 'Say hello to your driver before you land.',
        url: `https://www.jamaicaguru.com/meet-your-guru.html?token=${record.driver_intro_token}`,
        cta: 'Meet Your Guru'
      });
    }

    if (!sections.length) {
      return json({ skipped: true, reason: 'no tokens available yet' });
    }

    const firstName = record.first_name || 'there';
    const cardsHtml = sections.map(s => `
      <div style="background:#f3f6f8;border-radius:14px;padding:20px;margin-bottom:14px;">
        <div style="font-weight:700;font-size:16px;color:#1c2430;margin-bottom:4px;">${s.title}</div>
        <div style="color:#5b6472;font-size:13px;margin-bottom:14px;">${s.blurb}</div>
        <a href="${s.url}" style="display:inline-block;background:#8040ff;color:#fff;text-decoration:none;font-weight:600;font-size:13px;padding:10px 20px;border-radius:999px;">${s.cta} &rarr;</a>
      </div>`).join('');

    const html = `
    <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px 20px;color:#1c2430;">
      <div style="text-align:center;margin-bottom:28px;">
        <div style="font-size:22px;font-weight:800;color:#8040ff;">🌴 Jamaica Guru</div>
      </div>
      <h1 style="font-size:22px;margin:0 0 6px;">Trip update, ${firstName}!</h1>
      <p style="color:#5b6472;font-size:14px;line-height:1.6;margin:0 0 24px;">
        Good news — your trip (${record.booking_ref || ''}) just got a little more real. Take a look below.
      </p>
      ${cardsHtml}
      <p style="color:#5b6472;font-size:13px;line-height:1.6;margin-top:10px;">
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
        subject: sections.length > 1
          ? `Meet your Guru & see your stay — ${record.booking_ref || 'Jamaica Guru'}`
          : `${sections[0].title} is ready — ${record.booking_ref || 'Jamaica Guru'}`,
        html
      })
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Resend API ${res.status}: ${text}`);
    }

    return json({ ok: true, sections: sections.map(s => s.title) });
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
