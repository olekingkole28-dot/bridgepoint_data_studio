import { createClient } from "npm:@supabase/supabase-js@2";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H = { "content-type": "application/json", "cache-control": "no-store" };
const V = 1850;
const EXACT_LAYER = "https://services.arcgis.com/HYLRafMc4Ux6DA8c/ArcGIS/rest/services/CobbParcels/FeatureServer/0";
const EXACT_ROOT = "https://services.arcgis.com/HYLRafMc4Ux6DA8c/ArcGIS/rest/services/CobbParcels/FeatureServer";
const ITEM_ID = "d810aab5b7504c9882c1e61583dd035a";
const COUNTY_FIPS = "13067";
const MIN_EDIT_MS = Date.parse("2026-07-01T00:00:00Z");

function clean(v: unknown): string { return String(v ?? "").trim(); }
function normUrl(v: unknown): string { return clean(v).replace(/\/$/, ""); }
async function json(url: string) {
  const r = await fetch(url, { redirect: "follow", headers: { "user-agent": "BridgePointIntelligence/1.0 (official-public-record parcel-ID importer)" }, signal: AbortSignal.timeout(60000) });
  const txt = await r.text();
  if (!r.ok) throw new Error(`HTTP_${r.status}:${url}:${txt.slice(0,160)}`);
  const j = JSON.parse(txt);
  if (j?.error) throw new Error(`ARCGIS_ERROR:${JSON.stringify(j.error).slice(0,300)}`);
  return j;
}
function legalPass(meta: any, decision: unknown): boolean {
  const d = clean(decision).toUpperCase();
  const gate = clean(meta?.compliance_gate_v720).toUpperCase();
  const activation = clean(meta?.compliance_evaluation_v1006?.activation_status).toUpperCase();
  const rights = clean(meta?.compliance_evaluation_v1006?.rights_status).toUpperCase();
  const accepted = d === "ACCEPTED" || d === "APPROVED";
  const gatePass = gate === "PASS" || gate === "APPROVED";
  const evalPass = (activation === "APPROVED" || activation === "ACTIVE" || activation === "PASS") && rights === "PASS";
  return accepted && (gatePass || evalPass);
}
async function validateCandidate(sb: any, candidateId: string) {
  if (!candidateId) throw new Error("FAIL_CLOSED:CANDIDATE_ID_REQUIRED");
  const q = await sb.schema("automation").from("geographic_source_candidates_v86")
    .select("candidate_id,decision_status,source_url,metadata,state_code")
    .eq("candidate_id", candidateId).single();
  if (q.error) throw q.error;
  const c = q.data;
  if (clean(c?.state_code).toUpperCase() !== "GA") throw new Error("FAIL_CLOSED:STATE_NOT_GA");
  if (!legalPass(c?.metadata || {}, c?.decision_status)) throw new Error("FAIL_CLOSED:EXACT_CANDIDATE_NOT_COMPLIANCE_APPROVED");
  const fips = clean(c?.metadata?.county_fips || c?.metadata?.county_geoid);
  if (fips && fips !== COUNTY_FIPS) throw new Error(`FAIL_CLOSED:COUNTY_FIPS_${fips}`);
  const u = normUrl(c?.source_url);
  if (u !== EXACT_LAYER && u !== EXACT_ROOT) throw new Error(`FAIL_CLOSED:SOURCE_URL_MISMATCH:${u}`);
  return c;
}
async function validateLiveService() {
  const root = await json(`${EXACT_ROOT}?f=json`);
  if (clean(root?.serviceItemId).toLowerCase() !== ITEM_ID) throw new Error(`FAIL_CLOSED:SERVICE_ITEM_ID_MISMATCH:${root?.serviceItemId}`);
  const layer = await json(`${EXACT_LAYER}?f=json`);
  if (clean(layer?.name) !== "CobbParcels") throw new Error(`FAIL_CLOSED:LAYER_NAME:${layer?.name}`);
  if (clean(layer?.geometryType) !== "esriGeometryPolygon") throw new Error(`FAIL_CLOSED:GEOMETRY_TYPE:${layer?.geometryType}`);
  const fields = new Set((layer?.fields || []).map((x: any) => clean(x?.name)));
  if (!fields.has("FID") || (!fields.has("PARCEL_ID") && !fields.has("PIN"))) throw new Error("FAIL_CLOSED:REQUIRED_FIELDS_MISSING");
  const edit = Number(layer?.editingInfo?.lastEditDate || layer?.editingInfo?.dataLastEditDate || 0);
  if (Number.isFinite(edit) && edit > 0 && edit < MIN_EDIT_MS) throw new Error(`FAIL_CLOSED:STALE_LAYER:${new Date(edit).toISOString()}`);
  return { oid: "FID", edit: edit > 0 ? new Date(edit).toISOString() : null };
}
async function runTask(sb: any, t: any) {
  try {
    const candidateId = clean(t?.candidate_id || t?.source_candidate_id || t?.candidate_metadata?.candidate_id);
    await validateCandidate(sb, candidateId);
    const live = await validateLiveService();
    const cur = t.cursor || {};
    let total = Number(cur.estimated_total_rows || 0);
    if (!Number.isFinite(total) || total <= 0) {
      const c = await json(`${EXACT_LAYER}/query?where=1%3D1&returnCountOnly=true&f=json`);
      total = Number(c?.count || 0);
      if (!Number.isFinite(total) || total < 100000) throw new Error(`FAIL_CLOSED:COUNT_IMPLAUSIBLE:${total}`);
    }
    const last = Math.max(0, Number(cur.last_oid || 0) || 0);
    const q = `${EXACT_LAYER}/query?where=${encodeURIComponent(last > 0 ? `FID>${last}` : "1=1")}&outFields=FID%2CPARCEL_ID%2CPIN&returnGeometry=false&orderByFields=FID%20ASC&resultRecordCount=2000&f=json`;
    const j = await json(q);
    const features = Array.isArray(j?.features) ? j.features : [];
    const rows: any[] = [];
    let next = last;
    for (const f of features) {
      const a = f?.attributes || {};
      const oid = Number(a.FID || 0);
      if (Number.isFinite(oid)) next = Math.max(next, oid);
      const parcelId = clean(a.PARCEL_ID) || clean(a.PIN);
      if (!parcelId) continue;
      rows.push({
        _bridgepoint_source_record_id: parcelId,
        parcel_id: parcelId,
        property_number: parcelId,
        county_fips: COUNTY_FIPS,
        county_name: "Cobb County",
        state_code: "GA",
        source_mode: "COBB_OFFICIAL_PARCEL_ID_ONLY_V1850",
        source_object_id: oid || null,
        parcel_id_primary: clean(a.PARCEL_ID) || null,
        parcel_pin_fallback: clean(a.PIN) || null,
        geometry_retained: false,
        centroid_retained: false,
        owner_retained: false,
        mailing_address_retained: false,
        assessment_retained: false,
        tax_retained: false,
        legal_description_retained: false,
        raw_feature_retained: false
      });
    }
    const deduped = [...new Map(rows.map((r) => [r._bridgepoint_source_record_id, r])).values()];
    const seen = Number(cur.keyset_rows_seen || 0) + deduped.length;
    const done = features.length === 0 || (total > 0 && seen >= total) || (!j.exceededTransferLimit && features.length < 2000);
    const st = await sb.rpc("bridgepoint_expansion_worker_stage_records_v90", {
      p_source_task_id: t.source_task_id,
      p_records: deduped,
      p_next_cursor: { pagination_mode: "COBB_FID_KEYSET_V1850", last_oid: next, keyset_rows_seen: seen, estimated_total_rows: total, layer: EXACT_LAYER },
      p_done: done,
      p_result: {
        feeder_version: V,
        exact_source: EXACT_LAYER,
        service_item_id: ITEM_ID,
        source_data_last_edit: live.edit,
        batch_features: features.length,
        staged_unique_parcel_ids: deduped.length,
        estimated_total_rows: total,
        last_oid: next,
        legal_projection: "PARCEL_ID_PIN_ONLY_NO_GEOMETRY_NO_OWNER_NO_VALUE"
      }
    });
    if (st.error) throw st.error;
    return { task: t.source_task_id, candidate_id: candidateId, records: deduped.length, seen, total, next_oid: next, done };
  } catch (e) {
    const msg = String((e as any)?.message || e);
    if (t?.source_task_id) await sb.rpc("bridgepoint_expansion_worker_fail_task_v90", { p_source_task_id: t.source_task_id, p_error: msg, p_detail: { feeder_version: V, exact_source: EXACT_LAYER, fail_closed: true } }).catch(() => {});
    return { task: t?.source_task_id || null, records: 0, done: false, error: msg };
  }
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return new Response("method", { status: 405 });
    const b = await req.json().catch(() => ({}));
    const runId = clean(b.run_id);
    if (!runId) return new Response(JSON.stringify({ complete: false, version: V, error: "run_id required; worker never claims the global queue" }), { status: 400, headers: H });
    const sb = createClient(U, S, { auth: { persistSession: false, autoRefreshToken: false } });
    const auth = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: clean(b.task_token) });
    if (auth.error || auth.data !== true) return new Response(JSON.stringify({ complete: false, error: "Invalid task token" }), { status: 401, headers: H });
    const cl = await sb.rpc("bridgepoint_expansion_worker_claim_tasks_v90", { p_run_id: runId, p_limit: Math.min(Math.max(Number(b.limit || 4), 1), 8) });
    if (cl.error) throw cl.error;
    const tasks = cl.data?.tasks || [];
    const results = await Promise.all(tasks.map((t: any) => runTask(sb, t)));
    return new Response(JSON.stringify({ complete: true, version: V, run_id: runId, claimed: tasks.length, records: results.reduce((n: number, x: any) => n + Number(x.records || 0), 0), results }), { headers: H });
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: V, error: String((e as any)?.stack || (e as any)?.message || e) }), { status: 400, headers: H });
  }
});
