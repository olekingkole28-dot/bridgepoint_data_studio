import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
function clamp(n: number, min: number, max: number) { return Math.max(min, Math.min(max, n)); }
function rowsFromPayload(payload: any, entity: string): Record<string, unknown>[] {
  if (entity && Array.isArray(payload?.[entity])) return payload[entity];
  if (entity) {
    const alt = entity.charAt(0).toLowerCase() + entity.slice(1);
    if (Array.isArray(payload?.[alt])) return payload[alt];
  }
  if (payload && typeof payload === "object") {
    for (const [k, v] of Object.entries(payload)) {
      if (k.toLowerCase() !== "metadata" && Array.isArray(v)) return v as Record<string, unknown>[];
    }
  }
  return [];
}
async function fetchJsonWithRetry(url: URL): Promise<any> {
  let last = "source request failed";
  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      const res = await fetch(url.toString(), { headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0 national-lifecycle-ingest" } });
      if (res.ok) return await res.json();
      last = `HTTP ${res.status}: ${(await res.text()).slice(0, 800)}`;
      if (![429, 500, 502, 503, 504].includes(res.status)) break;
    } catch (e) { last = e instanceof Error ? e.message : String(e); }
    if (attempt < 5) await new Promise((r) => setTimeout(r, Math.min(8000, 1200 * attempt)));
  }
  throw new Error(last);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ complete: false, error: "method_not_allowed" }, 405);
  try {
    const body = await req.json().catch(() => ({}));
    const sourceCode = String(body?.source_code ?? "").toUpperCase();
    if (!sourceCode) return json({ complete: false, error: "source_code_required" }, 400);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) throw new Error("Supabase server credentials unavailable");
    const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const { data: secret, error: secretError } = await db.schema("automation").from("public_lifecycle_secret_v1100").select("task_token").eq("singleton", true).maybeSingle();
    if (secretError || !secret?.task_token || String(body?.task_token ?? "") !== String(secret.task_token)) {
      return json({ complete: false, error: "unauthorized" }, 401);
    }

    const { data: source, error: sourceError } = await db.schema("automation").from("source_registry")
      .select("source_code,source_url,access_method,enabled,geographic_scope,configuration,metadata")
      .eq("source_code", sourceCode).maybeSingle();
    if (sourceError || !source) return json({ complete: false, error: "unknown_source" }, 404);
    if (!source.enabled || !["NATIONAL", "GLOBAL"].includes(String(source.geographic_scope ?? "").toUpperCase())) return json({ complete: false, error: "source_not_national_or_disabled" }, 400);
    if (String(source.metadata?.national_openfema ?? "false") !== "true" && source.metadata?.national_openfema !== true) return json({ complete: false, error: "source_not_approved_for_national_openfema_worker" }, 400);
    const rawUrl = String(source.source_url ?? "");
    if (!rawUrl.startsWith("https://www.fema.gov/api/open/")) return json({ complete: false, error: "source_host_not_allowed" }, 400);

    const entity = String(source.configuration?.openfema_entity ?? "");
    const pageSize = clamp(Number(body?.page_size ?? 1000), 1, 1000);
    const maxPages = clamp(Number(body?.max_pages ?? 10), 1, 20);
    let offset = Number.isFinite(Number(body?.start_offset)) ? Math.max(Number(body.start_offset), 0) : Math.max(Number(source.configuration?.cursor_offset ?? 0), 0);
    let totalSeen = 0;
    let totalInserted = 0;
    let hasMore = false;
    let statesCovered = 0;

    for (let page = 0; page < maxPages; page++) {
      const u = new URL(rawUrl);
      u.searchParams.set("$top", String(pageSize));
      u.searchParams.set("$skip", String(offset));
      const payload = await fetchJsonWithRetry(u);
      const rows = rowsFromPayload(payload, entity);
      hasMore = rows.length === pageSize;
      const nextOffset = offset + rows.length;
      const { data: result, error: ingestError } = await db.rpc("ingest_national_lifecycle_context_v1107", {
        p_source_code: sourceCode,
        p_rows: rows,
        p_next_offset: hasMore ? nextOffset : 0,
        p_has_more: hasMore,
      });
      if (ingestError) throw ingestError;
      totalSeen += Number(result?.seen ?? rows.length);
      totalInserted += Number(result?.inserted ?? 0);
      statesCovered = Number(result?.states_covered ?? statesCovered);
      offset = nextOffset;
      if (!hasMore || rows.length === 0) break;
    }

    return json({ complete: true, source_code: sourceCode, total_seen: totalSeen, total_inserted: totalInserted, next_offset: hasMore ? offset : 0, has_more: hasMore, states_covered: statesCovered, bridge_version: 1107, truth_boundary: String(source.metadata?.truth_boundary ?? "CONTEXT_ONLY_UNLESS_EXACT_MATCH_IS_LAWFULLY_SUPPORTED") });
  } catch (e) {
    return json({ complete: false, error: e instanceof Error ? e.message : String(e) }, 500);
  }
});