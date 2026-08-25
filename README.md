# Jamaica Guru

A self-contained, static demo site for Jamaica Guru's all-inclusive travel packages — homepage, three package booking flows, cart review, and checkout, wired together as one connected experience.

## What's in here

- **`index.html`** — the actual deployable site. Open this file (or host it anywhere static) and everything works: no build step, no server, no dependencies. Fonts are embedded, and every other view below is bundled inside it as same-origin iframes that share state directly in JavaScript.
- **`home.html`, `package-3day.html`, `package-5day.html`, `package-7day.html`, `reviews-page.html`, `addons-page.html`, `addon-detail.html`, `review.html`, `checkout.html`** — the source for each individual view, kept separately so they're easier to read and edit than digging through `index.html`.
- **`pkg-template.html`** — the shared template the three `package-*.html` files are generated from.
- **`gen-packages.pl`** — a small Perl script that fills in `pkg-template.html` with each package's name, price, and dates to produce the three `package-*.html` files.
- **`gen-index.pl`** — rebuilds `index.html`'s embedded copy of all 9 views above from their source files.

## Editing a package page

Don't hand-edit `package-3day.html` / `-5day.html` / `-7day.html` directly — edit `pkg-template.html` and the per-package data at the top of `gen-packages.pl`, then regenerate:

```
perl gen-packages.pl
```

## Publishing changes to index.html

`index.html` is a bundle — it embeds all 9 views listed above as base64 text blocks so the whole site works from a single file with no server. After editing any source view file (or regenerating the package pages), rebuild it with:

```
perl gen-index.pl
```

It will not pick up changes automatically, and hand-editing the base64 blocks directly is not possible — always go through this script. If you changed `index.html`'s own shell (the styles/router/analytics code outside the embedded views), run this after that edit too, since it reads the current `index.html` to find where the embedded views start and end. It scans for those markers rather than assuming fixed line numbers, and refuses to run (rather than guess) if it can't find exactly 9 in the expected order — that's the fix for a real bug where an earlier hand-written version of this step, built around a hardcoded line range, silently corrupted the bundle the first time the shell's line count changed.

## Admin dashboard (`/admin`)

A separate internal dashboard for managing bookings, customers, the activity/experience catalog, transportation, and website content:

- **`admin/login.html`** — sign-in gate. Everything else in `/admin` redirects here if you're not signed in.
- **`admin/dashboard-home.html`** — overview (action items, revenue, today's operations).
- **`admin/admin-dashboard.html`** — edit a package's price, description, adventure options, and gallery.
- **`admin/bookings.html`**, **`admin/customers.html`**, **`admin/experiences.html`**, **`admin/transportation.html`**, **`admin/website.html`**, **`admin/analytics.html`**, **`admin/settings.html`** — one page per area, linked from the sidebar on every admin page.

**Important — this is not real security.** The login is a client-side check (see `ACCESS_CODE` near the top of `admin/login.html`'s `<script>`) that runs entirely in the visitor's browser. It stops casual visitors from wandering into the admin pages; it does **not** stop anyone who views the page source, and it does **not** stop anyone who can see this repo's code (if the repo is public, that includes anyone on the internet). Don't put real customer, payment, or business-sensitive data behind it and treat it as protected — that would need a real backend with server-side authentication, which this static site doesn't have.

To change the access code, edit the `ACCESS_CODE` value in `admin/login.html` and push. Every admin page (except `login.html` itself) is also entirely populated with the same kind of sample data as the public site — bookings, customers, and revenue numbers shown there aren't real.

## Hosting it

This is plain static HTML/CSS/JS — no build step required. To publish with GitHub Pages:

1. Go to this repo's **Settings → Pages**.
2. Under **Source**, choose the `main` branch and `/ (root)` folder.
3. Save. GitHub will give you a URL like `https://backuara-king.github.io/Jamaicaguru.com/` within a minute or two.
4. The admin dashboard will be at `https://backuara-king.github.io/Jamaicaguru.com/admin/login.html`.

## Status

This is a front-end design preview, not a production booking system:
- "Book Now" / "Confirm Booking" / "Continue to Checkout" all work and carry your selections across the flow, but the final "Complete Booking" step is a mocked confirmation — no real payment is processed.
- There's no backend or database. Nothing you enter is saved anywhere once you close the tab.
