import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const allowedOrigins = new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online"
]);

function cors(origin: string | null) {
  const allow = origin && allowedOrigins.has(origin) ? origin : "https://bridgepointintelligence.online";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
    "Cache-Control": "no-store"
  };
}

const reply = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(origin), "Content-Type": "application/json; charset=utf-8" }
  });

async function rpc(name: string, payload: Record<string, unknown>) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: service,
      Authorization: `Bearer ${service}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const data = await res.json().catch(async () => ({ complete:false, error: await res.text() }));
  return { ok: res.ok, data };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origin) });

  try {
    if (req.method === "GET") {
      const status = await rpc("bridgepoint_public_founding_sprint_v673", {});
      if (!status.ok) return reply({ complete:false, error:"Sprint status unavailable" }, 502, origin);
      return reply({ complete:true, sprint:status.data }, 200, origin);
    }

    if (req.method !== "POST") return reply({ complete:false, error:"Method not allowed" }, 405, origin);
    const body = await req.json().catch(() => ({}));
    const query = String(body?.query ?? "").replace(/\s+/g, " ").trim().slice(0, 140);
    if (query.length < 6) return reply({ complete:false, resolved:false, reason:"INVALID_QUERY" }, 400, origin);

    const snapshot = await rpc("[REDACTED_LONG_LITERAL]", { p_query: query });
    if (!snapshot.ok) return reply({ complete:false, error:"Snapshot unavailable" }, 502, origin);
    return reply(snapshot.data, 200, origin);
  } catch (error) {
    return reply({ complete:false, error:"Snapshot unavailable", detail:String(error).slice(0,160) }, 500, origin);
  }
});
