# Jamaica Guru

A self-contained, static demo site for Jamaica Guru's all-inclusive travel packages — homepage, three package booking flows, cart review, and checkout, wired together as one connected experience.

## What's in here

- **`index.html`** — the actual deployable site. Open this file (or host it anywhere static) and everything works: no build step, no server, no dependencies. Fonts are embedded, and the homepage / package pages / review / checkout are bundled inside it as same-origin iframes that share state directly in JavaScript.
- **`home.html`, `package-3day.html`, `package-5day.html`, `package-7day.html`, `review.html`, `checkout.html`** — the source for each individual view, kept separately so they're easier to read and edit than digging through `index.html`.
- **`pkg-template.html`** — the shared template the three `package-*.html` files are generated from.
- **`gen-packages.pl`** — a small Perl script that fills in `pkg-template.html` with each package's name, price, and dates to produce the three `package-*.html` files.

## Editing a package page

Don't hand-edit `package-3day.html` / `-5day.html` / `-7day.html` directly — edit `pkg-template.html` and the per-package data at the top of `gen-packages.pl`, then regenerate:

```
perl gen-packages.pl
```

## Publishing changes to index.html

`index.html` is a bundle — it embeds `home.html`, the three package pages, `review.html`, and `checkout.html` as base64 text blocks so the whole site works from a single file with no server. After editing any of the source view files (or regenerating the package pages), `index.html` needs to be rebuilt from them; it will not pick up changes automatically. Ask Claude to rebuild it, or see the conversation history for the build script.

## Hosting it

This is plain static HTML/CSS/JS — no build step required. To publish with GitHub Pages:

1. Go to this repo's **Settings → Pages**.
2. Under **Source**, choose the `main` branch and `/ (root)` folder.
3. Save. GitHub will give you a URL like `https://backuara-king.github.io/Jamaicaguru.com/` within a minute or two.

## Status

This is a front-end design preview, not a production booking system:
- "Book Now" / "Confirm Booking" / "Continue to Checkout" all work and carry your selections across the flow, but the final "Complete Booking" step is a mocked confirmation — no real payment is processed.
- There's no backend or database. Nothing you enter is saved anywhere once you close the tab.
