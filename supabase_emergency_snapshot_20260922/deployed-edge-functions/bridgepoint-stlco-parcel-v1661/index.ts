import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REST = `${SUPABASE_URL}/rest/v1`;
const SOURCE = "https://services2.arcgis.com/w657bnjzrjguNyOy/arcgis/rest/services/STLCOparcels/FeatureServer/0";
const EXPECTED = 399685;
const OUT_FIELDS = [
  "FID","LOCATOR","TAXYR","PROP_ADRNU","PROP_ADD","PROP_ZIP","SCHSUB","MUNYCODE","TAXCODE",
  "PROPCLASS","LUC","LANDUSE2","LUCODE","TENURE","LIVUNIT","YEARBLT","RESQFT","COMSTRUC","ACRES",
  "BLOCKNUM","LOTNUM","LOTDIM","LOTFRONT","LOTDEPTH","NBHD","TWP","TWPNAME","MUNICIPALI","ZONING"
].join(",");

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
}

async function sb(path: string, init: RequestInit = {}) {
  const res = await fetch(`${REST}${path}`, { ...init, headers: { ...headers, ...(init.headers || {}) } });
  const text = await res.text();
  let body: any = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) throw new Error(`SUPABASE_${res.status}: ${typeof body === "string" ? body : JSON.stringify(body)}`);
  return body;
}

async function arcgisPage(lastFid: number, limit: number) {
  const params = new URLSearchParams({
    where: `FID > ${Math.max(0, lastFid)}`,
    outFields: OUT_FIELDS,
    returnGeometry: "false",
    orderByFields: "FID ASC",
    resultRecordCount: String(limit),
    f: "json",
  });
  const res = await fetch(`${SOURCE}/query?${params.toString()}`, { signal: AbortSignal.timeout(30000) });
  const body = await res.json();
  if (!res.ok || body?.error) throw new Error(`ARCGIS_${res.status}: ${JSON.stringify(body?.error || body)}`);
  return Array.isArray(body?.features) ? body.features : [];
}

Deno.serve(async () => {
  try {
    const candidates = await sb(`/geographic_source_candidates_v86?select=candidate_id,decision_status,metadata&source_url=eq.${encodeURIComponent(SOURCE)}&decision_status=eq.ACCEPTED&order=discovered_at.desc&limit=1`);
    if (!Array.isArray(candidates) || candidates.length === 0) return json({ complete: true, skipped: "NO_ACCEPTED_SOURCE" });
    const candidateId = candidates[0].candidate_id;

    const tasks = await sb(`/geographic_source_tasks_v90?select=source_task_id,task_status,cursor,result,next_retry_at&candidate_id=eq.${candidateId}&task_type=eq.ACQUIRE_PROPERTY_FOUNDATION&task_status=in.(QUEUED,RETRY)&order=priority.asc,created_at.asc&limit=1`);
    if (!Array.isArray(tasks) || tasks.length === 0) return json({ complete: true, skipped: "NO_READY_TASK" });
    const task = tasks[0];
    if (task.next_retry_at && new Date(task.next_retry_at).getTime() > Date.now()) return json({ complete: true, skipped: "NOT_DUE" });

    const claimed = await sb(`/geographic_source_tasks_v90?source_task_id=eq.${task.source_task_id}&task_status=in.(QUEUED,RETRY)`, {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        task_status: "RUNNING",
        updated_at: new Date().toISOString(),
        result: { ...(task.result || {}), stlco_dedicated_v1661: true, claimed_at_v1661: new Date().toISOString() },
      }),
    });
    if (!Array.isArray(claimed) || claimed.length === 0) return json({ complete: true, skipped: "CLAIM_RACE" });

    let lastFid = Number(task.cursor?.last_oid || 0);
    let seen = Number(task.cursor?.keyset_rows_seen || 0);
    const records: any[] = [];
    let eof = false;
    const pageSize = 2000;
    const waves = 3;

    for (let i = 0; i < waves; i++) {
      const features = await arcgisPage(lastFid, pageSize);
      if (features.length === 0) { eof = true; break; }
      for (const f of features) {
        const a = f?.attributes || {};
        const fid = Number(a.FID);
        if (!Number.isFinite(fid)) continue;
        if (fid > lastFid) lastFid = fid;
        records.push({
          ...a,
          _bridgepoint_source_record_id: String(fid),
          parcel_id: a.LOCATOR ?? null,
          address: a.PROP_ADD ?? null,
          postal_code: a.PROP_ZIP ?? null,
          municipality: a.MUNICIPALI ?? null,
          county_name: "St. Louis County",
          land_use_code: a.LUCODE ?? a.LUC ?? null,
          property_subtype: a.PROPCLASS ?? null,
          year_built: a.YEARBLT ?? null,
          acreage: a.ACRES ?? null,
          stlco_current_alias_v1661: true,
        });
      }
      if (features.length < pageSize) { eof = true; break; }
    }

    seen += records.length;
    const done = eof || records.length === 0 || seen >= EXPECTED;
    const nextCursor = {
      last_oid: lastFid,
      object_id_field: "FID",
      pagination_mode: "OID_KEYSET_STLCO_V1661",
      keyset_rows_seen: seen,
      estimated_total_rows: EXPECTED,
      foundation_out_fields: OUT_FIELDS.split(","),
    };

    const stage = await sb(`/rpc/bridgepoint_expansion_worker_stage_records_v90`, {
      method: "POST",
      body: JSON.stringify({
        p_source_task_id: task.source_task_id,
        p_records: records,
        p_next_cursor: nextCursor,
        p_done: done,
        p_result: {
          worker: "bridgepoint-stlco-parcel-v1661",
          worker_ok: true,
          last_batch_records: records.length,
          last_batch_at: new Date().toISOString(),
          privacy_minimized: true,
          return_geometry: false,
          source_item_id: "3144d966d3534523beafb2fcfbae2140",
        },
      }),
    });

    return json({ complete: true, candidate_id: candidateId, source_task_id: task.source_task_id, records: records.length, seen, last_fid: lastFid, done, stage });
  } catch (err) {
    return json({ complete: false, error: String(err) }, 500);
  }
});
