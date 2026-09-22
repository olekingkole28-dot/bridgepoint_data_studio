import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const body = await req.json().catch(() => ({}));
    const supplied = String(body?.task_token ?? "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    const { data: secretRow, error: secretErr } = await db
      .schema("automation")
      .from("nfip_claims_secret_v1099")
      .select("task_token")
      .eq("singleton", true)
      .maybeSingle();
    if (secretErr || !secretRow?.task_token || supplied !== secretRow.task_token) {
      return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { "content-type": "application/json" } });
    }

    const pageSize = Math.min(Math.max(Number(body?.page_size ?? 1000), 1), 1000);
    const maxPages = Math.min(Math.max(Number(body?.max_pages ?? 10), 1), 20);
    let skip = Math.max(Number(body?.start_skip ?? 0), 0);
    let totalSeen = 0;
    let totalInserted = 0;
    let hasMore = false;

    for (let page = 0; page < maxPages; page++) {
      const u = new URL("https://www.fema.gov/api/open/v2/FimaNfipClaims");
      u.searchParams.set("$filter", "state eq 'CT'");
      u.searchParams.set("$top", String(pageSize));
      u.searchParams.set("$skip", String(skip));
      const fema = await fetch(u.toString(), { headers: { "accept": "application/json", "user-agent": "BridgePointIntelligence/1.0 public-data-ingest" } });
      if (!fema.ok) throw new Error(`OpenFEMA ${fema.status}: ${await fema.text()}`);
      const payload = await fema.json();
      const rows = Array.isArray(payload?.FimaNfipClaims) ? payload.FimaNfipClaims : Array.isArray(payload?.fimaNfipClaims) ? payload.fimaNfipClaims : [];
      hasMore = rows.length === pageSize;
      const nextSkip = skip + rows.length;

      if (rows.length > 0) {
        const { data: ingestResult, error: ingestErr } = await db.rpc("ingest_ct_nfip_claims_context_v1099", {
          p_rows: rows,
          p_next_skip: nextSkip,
          p_has_more: hasMore,
        });
        if (ingestErr) throw ingestErr;
        totalSeen += Number(ingestResult?.seen ?? rows.length);
        totalInserted += Number(ingestResult?.inserted ?? 0);
      } else {
        const { error: ingestErr } = await db.rpc("ingest_ct_nfip_claims_context_v1099", {
          p_rows: [],
          p_next_skip: 0,
          p_has_more: false,
        });
        if (ingestErr) throw ingestErr;
        hasMore = false;
      }

      skip = nextSkip;
      if (!hasMore) break;
    }

    return new Response(JSON.stringify({ complete: true, state: "CT", total_seen: totalSeen, total_inserted: totalInserted, next_skip: hasMore ? skip : 0, has_more: hasMore, truth_boundary: "PUBLIC_REDACTED_CONTEXT_ONLY" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, error: e instanceof Error ? e.message : String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});