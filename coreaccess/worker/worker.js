// AYS2 CORE ACCESS — Stripe checkout redirect + entitlement API.
//
// Routes:
//   GET  /subscribe?plan=monthly|quarterly|yearly|lifetime
//        → 302 to the matching Stripe Payment Link (set via env vars).
//   POST /stripe-webhook
//        → Stripe events; on successful checkout / renewal, stores the buyer's
//          e-mail → entitlement in KV. On subscription cancellation, expires it.
//   GET  /entitlement?email=<email>
//        → { active, tier, expiresAt } consumed by the iOS app.
//   GET  /
//        → tiny landing page describing the membership.
//
// Bindings/env required (see README.md):
//   KV namespace:  ENTITLEMENTS
//   Secrets:       STRIPE_WEBHOOK_SECRET
//   Vars:          LINK_MONTHLY, LINK_QUARTERLY, LINK_YEARLY, LINK_LIFETIME

const GRACE_DAYS = 3; // renewal grace period on top of each period

const PERIOD_SECONDS = {
  monthly: (31 + GRACE_DAYS) * 86400,
  quarterly: (92 + GRACE_DAYS) * 86400,
  yearly: (366 + GRACE_DAYS) * 86400,
  lifetime: 0, // 0 = never expires
};

export default {
  async fetch(request, env, _ctx) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    if (path === "/subscribe") return subscribe(url, env);
    if (path === "/stripe-webhook" && request.method === "POST")
      return stripeWebhook(request, env);
    if (path === "/entitlement") return entitlement(url, env);
    if (path === "/") return landing();
    return json({ error: "not found" }, 404);
  },
};

function subscribe(url, env) {
  const plan = (url.searchParams.get("plan") || "").toLowerCase();
  const links = {
    monthly: env.LINK_MONTHLY,
    quarterly: env.LINK_QUARTERLY,
    yearly: env.LINK_YEARLY,
    lifetime: env.LINK_LIFETIME,
  };
  const target = links[plan];
  if (!target) return json({ error: "unknown plan" }, 400);
  return Response.redirect(target, 302);
}

async function entitlement(url, env) {
  const email = normalizeEmail(url.searchParams.get("email"));
  if (!email) return json({ error: "email required" }, 400);
  const raw = await env.ENTITLEMENTS.get(email);
  if (!raw) return json({ active: false, tier: null, expiresAt: null });
  const ent = JSON.parse(raw);
  const active =
    ent.expiresAt === 0 || ent.expiresAt > Math.floor(Date.now() / 1000);
  return json({
    active,
    tier: ent.tier ?? null,
    expiresAt: ent.expiresAt === 0 ? null : ent.expiresAt,
  });
}

async function stripeWebhook(request, env) {
  const payload = await request.text();
  const sig = request.headers.get("stripe-signature") || "";
  if (!(await verifyStripeSignature(payload, sig, env.STRIPE_WEBHOOK_SECRET)))
    return json({ error: "bad signature" }, 400);

  const event = JSON.parse(payload);
  const type = event.type;
  const obj = event.data?.object ?? {};

  // New purchase (payment link checkout, subscription or one-time lifetime).
  if (type === "checkout.session.completed") {
    const email = normalizeEmail(
      obj.customer_details?.email || obj.customer_email
    );
    // Each Payment Link carries metadata { plan: "monthly" | ... } (README).
    const plan = (obj.metadata?.plan || "").toLowerCase();
    if (email && PERIOD_SECONDS[plan] !== undefined) {
      await grant(env, email, plan);
      return json({ ok: true });
    }
    return json({ ok: false, reason: "missing email or plan metadata" });
  }

  // Subscription renewal — extend using the plan we stored at purchase time.
  if (type === "invoice.paid") {
    const email = normalizeEmail(obj.customer_email);
    if (email) {
      const raw = await env.ENTITLEMENTS.get(email);
      const tier = raw ? JSON.parse(raw).tier : null;
      if (tier && tier !== "lifetime") await grant(env, email, tier);
    }
    return json({ ok: true });
  }

  // Cancellation / failed payments — let the current period lapse naturally;
  // subscription.deleted hard-expires immediately after the paid period.
  if (type === "customer.subscription.deleted") {
    const email = normalizeEmail(
      obj.customer_email || event.data?.object?.customer_email
    );
    if (email) {
      const raw = await env.ENTITLEMENTS.get(email);
      if (raw) {
        const ent = JSON.parse(raw);
        if (ent.tier !== "lifetime") {
          ent.expiresAt = Math.min(
            ent.expiresAt || 0,
            Math.floor(Date.now() / 1000)
          );
          await env.ENTITLEMENTS.put(email, JSON.stringify(ent));
        }
      }
    }
    return json({ ok: true });
  }

  return json({ ok: true, ignored: type });
}

async function grant(env, email, plan) {
  const period = PERIOD_SECONDS[plan];
  const expiresAt =
    period === 0 ? 0 : Math.floor(Date.now() / 1000) + period;
  await env.ENTITLEMENTS.put(
    email,
    JSON.stringify({ tier: plan, expiresAt, updatedAt: Date.now() })
  );
}

// Stripe signature: header "t=<ts>,v1=<hmac>", HMAC-SHA256("<ts>.<payload>", secret).
async function verifyStripeSignature(payload, header, secret) {
  if (!secret) return false;
  const parts = Object.fromEntries(
    header.split(",").map((kv) => kv.split("=", 2))
  );
  const ts = parts.t;
  const expected = parts.v1;
  if (!ts || !expected) return false;
  // Reject events older than 5 minutes (replay protection).
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${ts}.${payload}`)
  );
  const hex = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return timingSafeEqual(hex, expected);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function normalizeEmail(e) {
  return (e || "").trim().toLowerCase() || null;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "cache-control": "no-store",
    },
  });
}

function landing() {
  return new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AYS2 CORE ACCESS</title>
<body style="font-family:-apple-system,system-ui;background:#0E1013;color:#F0F1F5;display:grid;place-items:center;min-height:100vh;margin:0">
<div style="text-align:center;max-width:420px;padding:24px">
<div style="font-size:44px">👑</div>
<h1 style="margin:8px 0 4px">AYS2 CORE ACCESS</h1>
<p style="color:#9AA1B2">The supporter membership of the AYS2 PlayStation 2 emulator for iOS.
Beta builds first, cloud sync, Discord VIP, your name in the credits.</p>
<p style="color:#9AA1B2">Subscribe from the AYS2 app → Settings → Core Access.</p>
<p style="color:#6B7280;font-size:12px">AYS2 stays free and open-source (GPL-3.0). CORE ACCESS funds development and the services around it.</p>
</div></body>`,
    { headers: { "content-type": "text/html; charset=utf-8" } }
  );
}
