import { createClient } from "npm:@supabase/supabase-js@2";

const PLANS: Record<string, { label: string; price: number; days: number }> = {
  monthly: { label: "Premium Monthly", price: 2.99, days: 30 },
  yearly: { label: "Premium Yearly", price: 29.99, days: 365 },
};

const MIN_CHARGE = 0.5;
const DAY = 24 * 60 * 60 * 1000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Row = {
  id: number;
  plan: string;
  status: string;
  ends_at: string;
  amount_paid: number | string;
  refund_amount: number | string;
  stripe_payment_intent: string | null;
};

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const round = (value: number) => Math.round(value * 100) / 100;

const cents = (value: number) => String(Math.round(value * 100));

async function stripe(
  path: string,
  params?: Record<string, string>,
): Promise<any> {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) throw new Error("Stripe is not configured on the server.");

  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: params ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${key}`,
      ...(params
        ? { "Content-Type": "application/x-www-form-urlencoded" }
        : {}),
    },
    body: params ? new URLSearchParams(params) : undefined,
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error?.message ?? "Stripe error");
  return data;
}

function creditOf(row: Row) {
  const plan = PLANS[row.plan];
  const left = Math.floor((new Date(row.ends_at).getTime() - Date.now()) / DAY);
  const days = Math.max(0, Math.min(left, plan.days));
  const paid = Number(row.amount_paid) - Number(row.refund_amount);
  return round(Math.max(0, Math.min((plan.price * days) / plan.days, paid)));
}

async function activeSubscription(userId: string): Promise<Row | null> {
  const { data, error } = await db
    .from("subscriptions")
    .select()
    .eq("user_id", userId)
    .eq("status", "active")
    .gt("ends_at", new Date().toISOString())
    .order("started_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function endWithRefund(row: Row, refund: number) {
  if (refund > 0 && row.stripe_payment_intent) {
    await stripe("/refunds", {
      payment_intent: row.stripe_payment_intent,
      amount: cents(refund),
    });
  }

  const { error } = await db
    .from("subscriptions")
    .update({
      status: "cancelled",
      ends_at: new Date().toISOString(),
      refund_amount: round(Number(row.refund_amount) + refund),
    })
    .eq("id", row.id);
  if (error) throw error;
}

async function insertSubscription(values: Record<string, unknown>) {
  const plan = PLANS[values.plan as string];
  const now = new Date();
  const { error } = await db.from("subscriptions").insert({
    ...values,
    status: "active",
    started_at: now.toISOString(),
    ends_at: new Date(now.getTime() + plan.days * DAY).toISOString(),
  });
  if (error) throw error;
}

async function checkout(userId: string, email: string | undefined, body: any) {
  const plan = PLANS[body.plan];
  if (!plan) throw new Error("Unknown plan.");
  if (!/^https?:\/\//.test(body.returnUrl ?? "")) {
    throw new Error("Invalid return URL.");
  }

  const { data: profile } = await db
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (profile?.role === "admin") {
    throw new Error("Admins already have full access.");
  }

  const current = await activeSubscription(userId);
  if (current?.plan === body.plan) {
    throw new Error("You are already on this plan.");
  }

  const credit = current ? creditOf(current) : 0;
  const refund = round(Math.max(0, credit - plan.price));
  let total = round(Math.max(0, plan.price - credit));

  if (total === 0) {
    if (current) await endWithRefund(current, refund);
    await insertSubscription({ user_id: userId, plan: body.plan, amount_paid: 0 });
    return { switched: true, refund };
  }

  if (total < MIN_CHARGE) total = MIN_CHARGE;

  const separator = body.returnUrl.includes("?") ? "&" : "?";
  const session = await stripe("/checkout/sessions", {
    mode: "payment",
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": "eur",
    "line_items[0][price_data][unit_amount]": cents(total),
    "line_items[0][price_data][product_data][name]": plan.label,
    "line_items[0][price_data][product_data][description]": credit > 0
      ? `${plan.days} days of Premium · ${credit.toFixed(2)} € credit applied`
      : `${plan.days} days of Premium`,
    client_reference_id: userId,
    ...(email ? { customer_email: email } : {}),
    "metadata[user_id]": userId,
    "metadata[plan]": body.plan,
    "metadata[from_id]": current ? String(current.id) : "",
    success_url:
      `${body.returnUrl}${separator}checkout=success&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${body.returnUrl}${separator}checkout=cancelled`,
  });

  return { url: session.url };
}

async function confirm(userId: string, body: any) {
  const sessionId = String(body.sessionId ?? "");
  if (!sessionId.startsWith("cs_")) throw new Error("Invalid session.");

  const { data: existing } = await db
    .from("subscriptions")
    .select("id")
    .eq("stripe_session_id", sessionId)
    .maybeSingle();
  if (existing) return { confirmed: true };

  const session = await stripe(
    `/checkout/sessions/${sessionId}?expand[]=payment_intent.payment_method`,
  );
  if (session.metadata?.user_id !== userId) {
    throw new Error("This payment belongs to another account.");
  }
  if (session.payment_status !== "paid") {
    throw new Error("The payment was not completed.");
  }

  const fromId = Number(session.metadata.from_id);
  if (fromId) {
    await db
      .from("subscriptions")
      .update({ status: "cancelled", ends_at: new Date().toISOString() })
      .eq("id", fromId)
      .eq("user_id", userId)
      .gt("ends_at", new Date().toISOString());
  }

  const card = session.payment_intent?.payment_method?.card;
  const brand = card?.brand === "amex"
    ? "Amex"
    : card?.brand
    ? card.brand[0].toUpperCase() + card.brand.slice(1)
    : null;

  try {
    await insertSubscription({
      user_id: userId,
      plan: session.metadata.plan,
      amount_paid: session.amount_total / 100,
      card_brand: brand,
      card_last4: card?.last4 ?? null,
      stripe_session_id: sessionId,
      stripe_payment_intent: session.payment_intent?.id ?? null,
    });
  } catch (error) {
    if ((error as { code?: string }).code !== "23505") throw error;
  }

  return { confirmed: true, amount: session.amount_total / 100 };
}

async function cancel(userId: string) {
  const current = await activeSubscription(userId);
  if (!current) {
    throw new Error("No active subscription to cancel.");
  }
  const refund = creditOf(current);
  await endWithRefund(current, refund);
  return { refund };
}

async function adminCancel(userId: string, body: any) {
  const { data: profile } = await db
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (profile?.role !== "admin") throw new Error("Admins only.");

  const { data: row, error } = await db
    .from("subscriptions")
    .select()
    .eq("id", Number(body.subscriptionId))
    .maybeSingle();
  if (error) throw error;
  if (
    !row || row.status !== "active" ||
    new Date(row.ends_at).getTime() <= Date.now()
  ) {
    throw new Error("This subscription has already ended.");
  }

  const refund = body.refund === true ? creditOf(row) : 0;
  await endWithRefund(row, refund);
  return { refund };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const token = (req.headers.get("Authorization") ?? "").replace(
      "Bearer ",
      "",
    );
    const { data: { user } } = await db.auth.getUser(token);
    if (!user) return json({ error: "You must be signed in." }, 401);

    const body = await req.json();
    switch (body.action) {
      case "checkout":
        return json(await checkout(user.id, user.email, body));
      case "confirm":
        return json(await confirm(user.id, body));
      case "cancel":
        return json(await cancel(user.id));
      case "admin_cancel":
        return json(await adminCancel(user.id, body));
      default:
        return json({ error: "Unknown action." }, 400);
    }
  } catch (error) {
    return json({ error: (error as Error).message }, 400);
  }
});
