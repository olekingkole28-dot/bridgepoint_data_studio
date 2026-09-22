import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.55.0";

const SOURCE_CODE = "NERIS_PUBLIC_INCIDENT_BASICS_V1630";
const BASE = "https://lpbcyjocolyzmvo6.svcs5.arcgis.com/lPbcyJOcoLyZmvo6/arcgis/rest/services/NERIS%20Public%20Incident%20Basics/FeatureServer/0/query";
const STATES = new Set(["AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]);
const OUT_FIELDS = [
  "neris_id_incident","neris_id_dept","department_name","department_state",
  "type_1","type_1_primary","type_2","type_3","special_modifiers","aid_direction","nonfd_aid",
  "unit_response_count","rescue_animal","call_create","duration","civic_location","incident_state","incident_county",
  "type_location_use","in_use","intended","type_vacancy","type_location_use__second","acres_burned","room_of_origin",
  "building_damage","action_and_tactics","exposure_count","displacement_count","displacement_causes",
  "smoke_alarm_present","smoke_alarm_types","smoke_alarm_operation","fire_suppression_present","fire_suppression_types","fire_suppression_operation",
  "csst_hazard_flag","electric_hazard_flag","powergen_hazard_flag","medical_oxygen_hazard_flag",
  "point_origin","x","y","export_date","ObjectId"
].join(",");

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
function clamp(n: number, min: number, max: number) { return Math.max(min, Math.min(max, n)); }
function isoDate(v: unknown): unknown {
  if (typeof v === "number" && Number.isFinite(v)) {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }
  if (typeof v === "string" && v.trim()) {
    const asNum = Number(v);
    if (Number.isFinite(asNum) && /^\d{10,}$/.test(v.trim())) {
      const d = new Date(asNum);
      return Number.isNaN(d.getTime()) ? v : d.toISOString();
    }
    return v;
  }
  return v ?? null;
}
async function fetchArcgis(url: URL): Promise<any> {
  let last = "NERIS request failed";
  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      const res = await fetch(url.toString(), { headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0 NERIS-public-ingest" } });
      const text = await res.text();
      if (res.ok) {
        const payload = JSON.parse(text);
        if (payload?.error) throw new Error(`ArcGIS ${payload.error?.code ?? "error"}: ${payload.error?.message ?? "unknown"}`);
        return payload;
      }
      last = `HTTP ${res.status}: ${text.slice(0, 800)}`;
      if (![429,500,502,503,504].includes(res.status)) break;
    } catch (e) { last = e instanceof Error ? e.message : String(e); }
    if (attempt < 5) await new Promise((r) => setTimeout(r, Math.min(8000, 1000 * attempt)));
  }
  throw new Error(last);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ complete:false, error:"method_not_allowed" }, 405);
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ complete:false, error:"server_credentials_unavailable" }, 500);
  const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession:false, autoRefreshToken:false } });
  let stateCode = "";
  let stage = "parse_request";
  try {
    const body = await req.json().catch(() => ({}));
    const sourceCode = String(body?.source_code ?? "").toUpperCase();
    stateCode = String(body?.state_code ?? "").toUpperCase();
    if (sourceCode !== SOURCE_CODE) return json({ complete:false, error:"unsupported_source" }, 400);
    if (!STATES.has(stateCode)) return json({ complete:false, error:"invalid_state_code" }, 400);

    stage = "authorize_contract";
    const { data: contract, error: contractError } = await db.rpc("neris_worker_contract_v1631", {
      p_task_token: String(body?.task_token ?? ""),
      p_source_code: SOURCE_CODE,
      p_state_code: stateCode
    });
    if (contractError) throw new Error(`worker contract: ${contractError.message}`);
    if (!contract?.authorized || !String(contract?.source_url ?? "").startsWith("https://lpbcyjocolyzmvo6.svcs5.arcgis.com/")) throw new Error("worker contract rejected source");

    const pageSize = clamp(Number(body?.page_size ?? 1000), 1, 1000);
    const maxPages = clamp(Number(body?.max_pages ?? 10), 1, 20);
    let lastObjectId = Math.max(Number(body?.last_object_id ?? 0), 0);
    let totalSeen = 0;
    let totalInserted = 0;
    let totalExact = 0;
    let hasMore = true;

    for (let page = 0; page < maxPages; page++) {
      stage = `arcgis_page_${page + 1}`;
      const u = new URL(BASE);
      u.searchParams.set("where", `incident_state='${stateCode}' AND ObjectId>${Math.floor(lastObjectId)}`);
      u.searchParams.set("outFields", OUT_FIELDS);
      u.searchParams.set("returnGeometry", "false");
      u.searchParams.set("orderByFields", "ObjectId ASC");
      u.searchParams.set("resultRecordCount", String(pageSize));
      u.searchParams.set("f", "json");
      const payload = await fetchArcgis(u);
      const features = Array.isArray(payload?.features) ? payload.features : [];
      const rows = features.map((f:any) => ({ ...(f?.attributes ?? {}) })).filter((r:any) => r && typeof r === "object");
      for (const r of rows) {
        r.call_create = isoDate(r.call_create);
        r.export_date = isoDate(r.export_date);
        r.csst_hazard = r.csst_hazard_flag ?? null;
        r.electric_hazard = r.electric_hazard_flag ?? null;
        r.powergen_hazard = r.powergen_hazard_flag ?? null;
        r.medical_oxygen_hazard = r.medical_oxygen_hazard_flag ?? null;
        delete r.csst_hazard_flag;
        delete r.electric_hazard_flag;
        delete r.powergen_hazard_flag;
        delete r.medical_oxygen_hazard_flag;
      }
      const objectIds = rows.map((r:any) => Number(r.ObjectId)).filter((n:number) => Number.isFinite(n));
      const pageLast = objectIds.length ? Math.max(...objectIds) : lastObjectId;
      hasMore = Boolean(payload?.exceededTransferLimit) || rows.length === pageSize;

      stage = `ingest_page_${page + 1}`;
      const { data: result, error: ingestError } = await db.rpc("ingest_neris_incident_basics_v1630", {
        p_source_code: SOURCE_CODE,
        p_state_code: stateCode,
        p_rows: rows,
        p_last_object_id: pageLast,
        p_has_more: hasMore
      });
      if (ingestError) throw new Error(`ingest RPC: ${ingestError.message}`);
      totalSeen += Number(result?.seen ?? rows.length);
      totalInserted += Number(result?.inserted ?? 0);
      totalExact += Number(result?.exact_matchable ?? 0);
      lastObjectId = pageLast;
      if (!hasMore || rows.length === 0) break;
    }

    return json({ complete:true, source_code:SOURCE_CODE, state_code:stateCode, total_seen:totalSeen, total_inserted:totalInserted, exact_matchable:totalExact, last_object_id:lastObjectId, has_more:hasMore, bridge_version:1631, privacy_projection:"NERIS_PUBLIC_ALLOWLIST_V1630" });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const safe = `${stage}: ${msg}`.slice(0, 1500);
    if (stateCode && STATES.has(stateCode)) {
      try {
        await db.rpc("mark_neris_worker_error_v1631", { p_source_code:SOURCE_CODE, p_state_code:stateCode, p_error:safe });
      } catch (_) {}
    }
    return json({ complete:false, error:safe, state_code:stateCode || null, bridge_version:1631 }, 500);
  }
});