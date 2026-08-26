import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
const VERSION = 927;
const SERVICE = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const H = { "content-type": "application/json", "cache-control": "no-store" };

async function authenticated(token: string) {
  const q = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: token });
  return !q.error && q.data === true;
}

function finiteNumber(v: unknown): number | null {
  const n = typeof v === "number" ? v : Number(String(v ?? "").trim());
  return Number.isFinite(n) ? n : null;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "POST required" }), { status: 405, headers: H });
    }
    const body = await req.json().catch(() => ({}));
    const token = String(body.task_token || req.headers.get("x-bridgepoint-token") || "");
    if (!(await authenticated(token))) {
      return new Response(JSON.stringify({ complete: false, version: VERSION, error: "invalid task token" }), { status: 401, headers: H });
    }

    const batchSize = Math.max(1, Math.min(Number(body.batch_size || 150), 500));
    const claim = await sb.rpc("bridgepoint_3dep_claim_v927", { p_task_token: token, p_batch_size: batchSize });
    if (claim.error) throw claim.error;
    const job = claim.data || {};
    if (!job.claimed) {
      return new Response(JSON.stringify({ complete: true, version: VERSION, claimed: false, reason: job.reason || "NO_WORK" }), { status: 200, headers: H });
    }

    const state = String(job.state_code || "");
    const lease = String(job.lease_token || "");
    const rows = Array.isArray(job.rows) ? job.rows : [];
    if (!state || !lease || !rows.length) throw new Error("invalid claim payload");

    try {
      const points = rows.map((r: any) => [Number(r.longitude), Number(r.latitude)]);
      const params = new URLSearchParams();
      params.set("geometryType", "esriGeometryMultipoint");
      params.set("geometry", JSON.stringify({ points, spatialReference: { wkid: 4326 } }));
      params.set("returnFirstValueOnly", "true");
      params.set("interpolation", "RSP_BilinearInterpolation");
      params.set("outFields", "Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Source,Resolution_X,Resolution_Y,pubdate,title");
      params.set("f", "json");

      const usgs = await fetch(SERVICE, {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
          "accept": "application/json",
          "user-agent": "BridgePointIntelligence/1.0"
        },
        body: params.toString(),
        signal: AbortSignal.timeout(45000)
      });
      const text = await usgs.text();
      if (!usgs.ok) throw new Error(`USGS_HTTP_${usgs.status}:${text.slice(0, 500)}`);
      let payload: any;
      try { payload = JSON.parse(text); } catch { throw new Error(`USGS_NON_JSON:${text.slice(0, 500)}`); }
      if (payload?.error) throw new Error(`USGS_ARCGIS_ERROR:${JSON.stringify(payload.error).slice(0, 1000)}`);

      const samples = Array.isArray(payload?.samples) ? payload.samples : [];
      const out = rows.map((r: any) => ({
        property_id: String(r.property_id), longitude: Number(r.longitude), latitude: Number(r.latitude),
        sample_status: "NO_DATA", elevation_m: null, resolution_m: null, raster_id: null,
        dataset_id: null, product_name: null, vertical_datum: null, acquisition_date: null, attributes: {}
      }));

      const ids = samples.map((s: any) => Number(s?.locationId)).filter((n: number) => Number.isInteger(n));
      const oneBased = ids.length > 0 && Math.min(...ids) >= 1 && Math.max(...ids) <= rows.length && !ids.includes(0);
      let accepted = 0;
      for (let i = 0; i < samples.length; i++) {
        const s: any = samples[i] || {};
        const rawId = Number(s.locationId);
        let idx = Number.isInteger(rawId) ? rawId - (oneBased ? 1 : 0) : i;
        if (idx < 0 || idx >= out.length) idx = i < out.length ? i : -1;
        if (idx < 0) continue;
        const value = finiteNumber(s.value);
        const attrs = s.attributes && typeof s.attributes === "object" ? s.attributes : {};
        if (value !== null && value >= -12000 && value <= 10000) {
          out[idx].sample_status = "OK";
          out[idx].elevation_m = value;
          accepted++;
        } else {
          out[idx].sample_status = value === null ? "NO_DATA" : "INVALID";
        }
        out[idx].resolution_m = finiteNumber(s.resolution);
        out[idx].raster_id = finiteNumber(s.rasterId);
        out[idx].dataset_id = attrs.Dataset_ID == null ? null : String(attrs.Dataset_ID);
        out[idx].product_name = attrs.ProductName == null ? null : String(attrs.ProductName);
        out[idx].vertical_datum = attrs.VerticalDatum == null ? null : String(attrs.VerticalDatum);
        out[idx].acquisition_date = attrs.AcquisitionDate == null ? null : String(attrs.AcquisitionDate);
        out[idx].attributes = attrs;
      }

      const saved = await sb.rpc("bridgepoint_3dep_persist_v927", {
        p_task_token: token, p_state_code: state, p_lease_token: lease, p_samples: out
      });
      if (saved.error) throw saved.error;

      return new Response(JSON.stringify({
        complete: true, version: VERSION, claimed: true, state_code: state,
        requested: rows.length, usgs_samples: samples.length, accepted, persisted: saved.data
      }), { status: 200, headers: H });
    } catch (e) {
      const msg = String((e as any)?.message || e);
      try {
        await sb.rpc("bridgepoint_3dep_fail_v927", {
          p_task_token: token, p_state_code: state, p_lease_token: lease, p_error: msg.slice(0, 1500)
        });
      } catch (_) {}
      throw e;
    }
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: VERSION, error: String((e as any)?.message || e) }), { status: 500, headers: H });
  }
});
