import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SOURCE = "https://geodata.hawaii.gov/arcgis/rest/services/ParcelsZoning/MapServer/25/query";
const H = { "content-type": "application/json" };
const VERSION = 911;

type RepairState = {
  last_objectid?: number | string;
  total_source_count?: number | string | null;
  rows_updated?: number | string;
  repair_complete?: boolean;
};

function numberValue(v: unknown, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

async function fetchJson(url: URL, timeoutMs = 30000) {
  const response = await fetch(url, {
    headers: {
      accept: "application/json",
      "user-agent": "BridgePointIntelligence/1.0 Hawaii parcel repair",
    },
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await response.text();
  let data: any = {};
  try { data = JSON.parse(text); } catch { /* handled below */ }
  if (!response.ok || data?.error) {
    throw new Error(`Hawaii ArcGIS ${response.status}: ${text.slice(0, 500)}`);
  }
  return data;
}

async function sourceCount() {
  const url = new URL(SOURCE);
  url.searchParams.set("where", "1=1");
  url.searchParams.set("returnCountOnly", "true");
  url.searchParams.set("f", "json");
  const data = await fetchJson(url, 20000);
  return numberValue(data?.count, 0);
}

async function sourceBatch(afterObjectId: number, batchSize: number) {
  const url = new URL(SOURCE);
  url.searchParams.set("where", `objectid>${afterObjectId}`);
  url.searchParams.set("outFields", "objectid,tmk_txt,cty_tmk,county,gisacres,qpub_link");
  url.searchParams.set("returnGeometry", "true");
  url.searchParams.set("outSR", "4326");
  url.searchParams.set("orderByFields", "objectid ASC");
  url.searchParams.set("resultRecordCount", String(batchSize));
  url.searchParams.set("geometryPrecision", "6");
  url.searchParams.set("f", "geojson");
  const data = await fetchJson(url, 45000);
  const features = Array.isArray(data?.features) ? data.features : [];
  return features.map((feature: any) => {
    const p = feature?.properties ?? {};
    return {
      objectid: String(p.objectid ?? p.OBJECTID ?? p.ObjectID ?? ""),
      tmk_txt: p.tmk_txt ?? p.TMK_Txt ?? p.TMK_TXT ?? null,
      cty_tmk: p.cty_tmk ?? p.CTY_TMK ?? null,
      county: p.county ?? p.COUNTY ?? null,
      gisacres: p.gisacres ?? p.GISAcres ?? p.GISACRES ?? null,
      qpub_link: p.qpub_link ?? p.QPUB_LINK ?? null,
      geometry: feature?.geometry ?? null,
    };
  }).filter((row: any) => row.objectid && row.geometry);
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "POST required" }), { status: 405, headers: H });
    }

    const body = await req.json().catch(() => ({}));
    const taskToken = String(body?.task_token ?? req.headers.get("x-bridgepoint-token") ?? "");
    const maxBatches = Math.min(Math.max(numberValue(body?.limit, 8), 1), 12);
    const batchSize = Math.min(Math.max(numberValue(body?.batch_size, 500), 100), 750);
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    const auth = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: taskToken });
    if (auth.error || auth.data !== true) {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "invalid task token" }), { status: 401, headers: H });
    }

    const stateResponse = await sb.rpc("bridgepoint_hi_parcel_repair_state_v911", { p_task_token: taskToken });
    if (stateResponse.error) throw stateResponse.error;
    const state = (stateResponse.data ?? {}) as RepairState;
    if (state.repair_complete === true) {
      return new Response(JSON.stringify({ complete: true, version: VERSION, skipped: true, reason: "REPAIR_COMPLETE", state }), { headers: H });
    }

    let total = numberValue(state.total_source_count, 0);
    if (total <= 0) total = await sourceCount();
    let cursor = numberValue(state.last_objectid, 0);
    let updated = 0;
    let processed = 0;
    const batches: any[] = [];

    for (let i = 0; i < maxBatches; i++) {
      const rows = await sourceBatch(cursor, batchSize);
      if (rows.length === 0) {
        const done = await sb.rpc("bridgepoint_hi_parcel_repair_persist_v911", {
          p_task_token: taskToken,
          p_rows: [],
          p_total_source_count: total || null,
        });
        if (done.error) throw done.error;
        return new Response(JSON.stringify({
          complete: true,
          version: VERSION,
          repair_complete: true,
          source_count: total,
          processed_this_run: processed,
          updated_this_run: updated,
          last_objectid: cursor,
          batches,
          final_state: done.data,
        }), { headers: H });
      }

      const persist = await sb.rpc("bridgepoint_hi_parcel_repair_persist_v911", {
        p_task_token: taskToken,
        p_rows: rows,
        p_total_source_count: total || null,
      });
      if (persist.error) throw persist.error;
      const result = persist.data ?? {};
      const nextCursor = numberValue(result?.last_objectid, cursor);
      if (nextCursor <= cursor) throw new Error(`Hawaii repair cursor did not advance beyond ${cursor}`);
      cursor = nextCursor;
      processed += rows.length;
      updated += numberValue(result?.updated_rows, 0);
      batches.push({ rows: rows.length, updated: numberValue(result?.updated_rows, 0), last_objectid: cursor });
    }

    return new Response(JSON.stringify({
      complete: true,
      version: VERSION,
      repair_complete: false,
      source_count: total,
      processed_this_run: processed,
      updated_this_run: updated,
      last_objectid: cursor,
      batches,
    }), { headers: H });
  } catch (error) {
    return new Response(JSON.stringify({
      complete: false,
      version: VERSION,
      error: String((error as any)?.message ?? error),
    }), { status: 500, headers: H });
  }
});
