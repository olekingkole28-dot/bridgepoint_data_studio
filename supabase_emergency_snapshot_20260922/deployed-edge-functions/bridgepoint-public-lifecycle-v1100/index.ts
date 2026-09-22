import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

type SupportedSource =
  | "FEMA_NFIP_POLICIES_CT_V1100"
  | "CT_CID_INSURANCE_COMPLAINTS_V1100"
  | "CT_UCC_LIENS_V1100";

const SUPPORTED = new Set<SupportedSource>([
  "FEMA_NFIP_POLICIES_CT_V1100",
  "CT_CID_INSURANCE_COMPLAINTS_V1100",
  "CT_UCC_LIENS_V1100",
]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

async function fetchJsonWithRetry(url: URL): Promise<unknown> {
  let last = "";
  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      const res = await fetch(url.toString(), {
        headers: {
          accept: "application/json",
          "user-agent": "BridgePointIntelligence/1.0 public-lifecycle-ingest",
        },
      });
      if (res.ok) return await res.json();
      last = `HTTP ${res.status}: ${(await res.text()).slice(0, 500)}`;
      if (![429, 500, 502, 503, 504].includes(res.status)) throw new Error(last);
    } catch (e) {
      last = e instanceof Error ? e.message : String(e);
    }
    if (attempt < 5) await new Promise((r) => setTimeout(r, Math.min(8000, attempt * 1200)));
  }
  throw new Error(last || "source request failed");
}

function rowsFromFema(payload: any): Record<string, unknown>[] {
  const candidates = [
    payload?.FimaNfipPolicies,
    payload?.fimaNfipPolicies,
    payload?.FimaNFIPPolicies,
    payload?.fimaNFIPPolicies,
  ];
  for (const c of candidates) if (Array.isArray(c)) return c;
  return [];
}

function buildSourceUrl(source: SupportedSource, offset: number, limit: number, femaStateField = "state") {
  if (source === "FEMA_NFIP_POLICIES_CT_V1100") {
    const u = new URL("https://www.fema.gov/api/open/v2/FimaNfipPolicies");
    u.searchParams.set("$filter", `${femaStateField} eq 'CT'`);
    u.searchParams.set("$top", String(limit));
    u.searchParams.set("$skip", String(offset));
    return u;
  }
  const dataset = source === "CT_CID_INSURANCE_COMPLAINTS_V1100" ? "t64r-mt64" : "xfev-8smz";
  const u = new URL(`https://data.ct.gov/resource/${dataset}.json`);
  u.searchParams.set("$limit", String(limit));
  u.searchParams.set("$offset", String(offset));
  return u;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ complete: false, error: "method_not_allowed" }, 405);
  try {
    const body = await req.json().catch(() => ({}));
    const source = String(body?.source_code ?? "").toUpperCase() as SupportedSource;
    if (!SUPPORTED.has(source)) return json({ complete: false, error: "unsupported_source", source_code: source }, 400);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) throw new Error("Supabase server credentials unavailable");
    const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const { data: secret, error: secretError } = await db
      .schema("automation")
      .from("public_lifecycle_secret_v1100")
      .select("task_token")
      .eq("singleton", true)
      .maybeSingle();
    const supplied = String(body?.task_token ?? "");
    if (secretError || !secret?.task_token || supplied !== secret.task_token) {
      return json({ complete: false, error: "unauthorized" }, 401);
    }

    const pageSize = clamp(Number(body?.page_size ?? 1000), 1, 1000);
    const maxPages = clamp(Number(body?.max_pages ?? 10), 1, 20);
    let offset = Math.max(Number(body?.start_offset ?? 0), 0);
    let totalSeen = 0;
    let totalInserted = 0;
    let hasMore = false;
    let femaStateField = "state";

    for (let page = 0; page < maxPages; page++) {
      let payload: any;
      if (source === "FEMA_NFIP_POLICIES_CT_V1100") {
        try {
          payload = await fetchJsonWithRetry(buildSourceUrl(source, offset, pageSize, femaStateField));
        } catch (e) {
          if (page === 0 && offset === Number(body?.start_offset ?? 0)) {
            femaStateField = "propertyState";
            payload = await fetchJsonWithRetry(buildSourceUrl(source, offset, pageSize, femaStateField));
          } else throw e;
        }
      } else {
        payload = await fetchJsonWithRetry(buildSourceUrl(source, offset, pageSize));
      }

      const rows = source === "FEMA_NFIP_POLICIES_CT_V1100"
        ? rowsFromFema(payload)
        : Array.isArray(payload) ? payload : [];
      hasMore = rows.length === pageSize;
      const nextOffset = offset + rows.length;

      const { data: result, error: ingestError } = await db.rpc("ingest_public_lifecycle_context_v1100", {
        p_source_code: source,
        p_rows: rows,
        p_next_offset: hasMore ? nextOffset : 0,
        p_has_more: hasMore,
      });
      if (ingestError) throw ingestError;
      totalSeen += Number(result?.seen ?? rows.length);
      totalInserted += Number(result?.inserted ?? 0);
      offset = nextOffset;
      if (!hasMore) break;
    }

    return json({
      complete: true,
      source_code: source,
      total_seen: totalSeen,
      total_inserted: totalInserted,
      next_offset: hasMore ? offset : 0,
      has_more: hasMore,
      truth_boundary: "[REDACTED_LONG_LITERAL]",
    });
  } catch (e) {
    return json({ complete: false, error: e instanceof Error ? e.message : String(e) }, 500);
  }
});