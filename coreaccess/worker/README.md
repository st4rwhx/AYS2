# AYS2 CORE ACCESS — setup (one time, ~20 minutes)

The supporter membership: **the emulator stays free and complete for
everyone** (GPL-3.0 requires it and the community expects it). CORE ACCESS
sells what the license does *not* cover: server-side services and perks.

Money flow: the app opens `worker/subscribe?plan=…` → Stripe Payment Link →
Stripe webhook → this worker stores `email → entitlement` in KV → the app
checks `worker/entitlement?email=…`.

## 1. Stripe (dashboard.stripe.com)

1. Create a Stripe account (or use an existing one).
2. **Products** → create 4 products / prices:
   | Product | Price | Type |
   |---|---|---|
   | AYS2 CORE ACCESS — 1 Month | 3,99 € | Recurring, monthly |
   | AYS2 CORE ACCESS — 3 Months | 9,99 € | Recurring, every 3 months |
   | AYS2 CORE ACCESS — 12 Months | 29,99 € | Recurring, yearly |
   | AYS2 CORE ACCESS — Lifetime | 79,99 € | One-time |
3. **Payment Links** → create one link per price. On each link, open
   *Advanced / Metadata* and add **`plan`** = `monthly` / `quarterly` /
   `yearly` / `lifetime` (exactly these values — the webhook reads them).
4. Copy the 4 `https://buy.stripe.com/…` URLs.

## 2. Worker

```bash
cd coreaccess/worker
npx wrangler kv namespace create ENTITLEMENTS   # paste the id into wrangler.toml
# paste the 4 payment links into [vars] in wrangler.toml
npx wrangler deploy
```

The worker URL will be `https://ays2-core-access.<your-account>.workers.dev`.
It must match `CoreAccessStore.apiBase` in
`src/swift/Models/CoreAccessStore.swift` — update either side so they agree.

## 3. Stripe webhook

Stripe Dashboard → **Developers → Webhooks → Add endpoint**:

- Endpoint URL: `https://ays2-core-access.<your-account>.workers.dev/stripe-webhook`
- Events: `checkout.session.completed`, `invoice.paid`,
  `customer.subscription.deleted`
- Copy the signing secret (`whsec_…`) then:

```bash
npx wrangler secret put STRIPE_WEBHOOK_SECRET
```

## 4. Test end to end

1. Stripe **test mode**: create a test payment link the same way, pay with
   card `4242 4242 4242 4242`.
2. `curl "https://ays2-core-access.<account>.workers.dev/entitlement?email=you@test.com"`
   → `{"active":true,"tier":"monthly",…}`.
3. In the app: Settings → Core Access → *Already a member?* → enter the same
   e-mail → "Membership activated".

## Honest-model notes (read once)

- The app is GPL-3.0: anyone may fork it and remove these screens. That is
  fine — the perks live on YOUR server and YOUR Discord, which no fork gets.
- Never gate emulator features on the membership: it would be stripped in a
  day and burn community goodwill (see the AetherSX2 story).
- The post-game prompt is rate-limited in `CoreAccessStore` (never the first
  3 days, at most every 4 days, permanent opt-out). Resist the urge to make
  it more aggressive; conversion comes from the Settings tile + goodwill.
