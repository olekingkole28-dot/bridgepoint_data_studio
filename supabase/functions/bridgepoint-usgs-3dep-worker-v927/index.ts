import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
const VERSION = 927;
const IMAGE_SAMPLES = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/getSamples";
const EPQS = "https://epqs.nationalmap.gov/v1/json";
const H = { "content-type": "application/json", "cache-control": "no-store" };
const IMAGE_CHUNK = 10;
const EPQS_CONCURRENCY = 5;

async function authenticated(token: string) {
  const q = await sb.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: token });
  return !q.error && q.data === true;
}

function finiteNumber(v: unknown): number | null {
  const n = typeof v === "number" ? v : Number(String(v ?? "").trim());
  return Number.isFinite(n) ? n : null;
}

function baseRow(r: any) {
  return {
    property_id: String(r.property_id),
    longitude: Number(r.longitude),
    latitude: Number(r.latitude),
    sample_status: "NO_DATA",
    elevation_m: null as number | null,
    resolution_m: null as number | null,
    raster_id: null as number | null,
    dataset_id: null as string | null,
    product_name: null as string | null,
    vertical_datum: null as string | null,
    acquisition_date: null as string | null,
    attributes: {} as Record<string, unknown>,
  };
}

function assignSample(target: any, sample: any, provenance: Record<string, unknown>) {
  const value = finiteNumber(sample?.value ?? sample?.Elevation ?? sample?.elevation);
  if (value !== null && value >= -12000 && value <= 10000) {
    target.sample_status = "OK";
    target.elevation_m = value;
  } else if (value === null || value === -1000000) {
    target.sample_status = "NO_DATA";
    target.elevation_m = null;
  } else {
    target.sample_status = "INVALID";
    target.elevation_m = null;
  }
  target.resolution_m = finiteNumber(sample?.resolution ?? sample?.Resolution ?? sample?.attributes?.Resolution_X ?? sample?.attributes?.resolution);
  target.raster_id = finiteNumber(sample?.rasterId ?? sample?.RasterId ?? sample?.raster_id);
  const attrs = sample?.attributes && typeof sample.attributes === "object" ? sample.attributes : {};
  target.dataset_id = attrs.Dataset_ID == null ? null : String(attrs.Dataset_ID);
  target.product_name = attrs.ProductName == null ? null : String(attrs.ProductName);
  target.vertical_datum = attrs.VerticalDatum == null ? null : String(attrs.VerticalDatum);
  target.acquisition_date = attrs.AcquisitionDate == null ? null : String(attrs.AcquisitionDate);
  target.attributes = { ...attrs, ...provenance };
}

async function imageSamples(rows: any[]) {
  const points = rows.map((r: any) => [Number(r.longitude), Number(r.latitude)]);
  const params = new URLSearchParams();
  params.set("geometryType", "esriGeometryMultipoint");
  params.set("geometry", JSON.stringify({ points, spatialReference: { wkid: 4326 } }));
  params.set("returnFirstValueOnly", "true");
  params.set("interpolation", "RSP_BilinearInterpolation");
  params.set("outFields", "Dataset_ID,ProductName,VerticalDatum,AcquisitionDate,Source,Resolution_X,Resolution_Y,pubdate,title");
  params.set("f", "json");

  const res = await fetch(IMAGE_SAMPLES, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
      "accept": "application/json",
      "user-agent": "BridgePointIntelligence/1.0"
    },
    body: params.toString(),
    signal: AbortSignal.timeout(18000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`USGS_IMAGE_HTTP_${res.status}:${text.slice(0,300)}`);
  let payload: any;
  try { payload = JSON.parse(text); } catch { throw new Error(`USGS_IMAGE_NON_JSON:${text.slice(0,300)}`); }
  if (payload?.error) throw new Error(`USGS_IMAGE_ARCGIS_ERROR:${JSON.stringify(payload.error).slice(0,500)}`);
  return Array.isArray(payload?.samples) ? payload.samples : [];
}

async function epqsOne(row: any) {
  const url = new URL(EPQS);
  url.searchParams.set("x", String(Number(row.longitude)));
  url.searchParams.set("y", String(Number(row.latitude)));
  url.searchParams.set("wkid", "4326");
  url.searchParams.set("units", "Meters");
  url.searchParams.set("includeDate", "true");
  const res = await fetch(url, {
    headers: { "accept": "application/json", "user-agent": "BridgePointIntelligence/1.0", "cache-control": "no-cache" },
    signal: AbortSignal.timeout(12000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`USGS_EPQS_HTTP_${res.status}:${text.slice(0,250)}`);
  let p: any;
  try { p = JSON.parse(text); } catch { throw new Error(`USGS_EPQS_NON_JSON:${text.slice(0,250)}`); }
  if (p?.error) throw new Error(`USGS_EPQS_ERROR:${JSON.stringify(p.error).slice(0,400)}`);
  const legacy = p?.USGS_Elevation_Point_Query_Service?.Elevation_Query || p?.Elevation_Query || {};
  return {
    value: p?.value ?? p?.elevation ?? legacy?.Elevation,
    rasterId: p?.rasterId ?? p?.rasterID ?? legacy?.RasterId,
    resolution: p?.resolution ?? legacy?.Resolution,
    attributes: {
      ...(p?.attributes && typeof p.attributes === "object" ? p.attributes : {}),
      EPQS_Date: p?.date ?? p?.Date ?? legacy?.Data_Source ?? null,
    },
  };
}

async function mapLimited<T, R>(items: T[], limit: number, fn: (item: T, index: number) => Promise<R>): Promise<R[]> {
  const out = new Array<R>(items.length);
  let next = 0;
  async function runner() {
    while (true) {
      const i = next++;
      if (i >= items.length) return;
      out[i] = await fn(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, () => runner()));
  return out;
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

    const batchSize = Math.max(1, Math.min(Number(body.batch_size || 50), 500));
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
      const out = rows.map(baseRow);
      let imageChunksOk = 0;
      let imageChunksFailed = 0;
      let imageSamplesUsed = 0;
      let epqsFallbacks = 0;
      const fallbackIndexes = new Set<number>();

      for (let start = 0; start < rows.length; start += IMAGE_CHUNK) {
        const chunk = rows.slice(start, start + IMAGE_CHUNK);
        try {
          const samples = await imageSamples(chunk);
          imageChunksOk++;
          const ids = samples.map((s: any) => Number(s?.locationId)).filter((n: number) => Number.isInteger(n));
          const oneBased = ids.length > 0 && Math.min(...ids) >= 1 && Math.max(...ids) <= chunk.length && !ids.includes(0);
          const touched = new Set<number>();
          for (let i = 0; i < samples.length; i++) {
            const s: any = samples[i] || {};
            const rawId = Number(s.locationId);
            let local = Number.isInteger(rawId) ? rawId - (oneBased ? 1 : 0) : i;
            if (local < 0 || local >= chunk.length) local = i < chunk.length ? i : -1;
            if (local < 0) continue;
            const global = start + local;
            assignSample(out[global], s, { query_path: "3DEP_IMAGESERVER_GETSAMPLES", image_chunk_size: chunk.length });
            touched.add(local);
            imageSamplesUsed++;
          }
          for (let local = 0; local < chunk.length; local++) if (!touched.has(local)) fallbackIndexes.add(start + local);
        } catch (_) {
          imageChunksFailed++;
          for (let local = 0; local < chunk.length; local++) fallbackIndexes.add(start + local);
        }
      }

      const indexes = [...fallbackIndexes].sort((a, b) => a - b);
      if (indexes.length) {
        const fallbackResults = await mapLimited(indexes, EPQS_CONCURRENCY, async (idx) => {
          const sample = await epqsOne(rows[idx]);
          return { idx, sample };
        });
        for (const { idx, sample } of fallbackResults) {
          assignSample(out[idx], sample, { query_path: "EPQS_FALLBACK", fallback_from: "3DEP_IMAGESERVER_GETSAMPLES" });
          epqsFallbacks++;
        }
      }

      const saved = await sb.rpc("bridgepoint_3dep_persist_v927", {
        p_task_token: token,
        p_state_code: state,
        p_lease_token: lease,
        p_samples: out,
      });
      if (saved.error) throw saved.error;

      const accepted = out.filter((x: any) => x.sample_status === "OK").length;
      return new Response(JSON.stringify({
        complete: true,
        version: VERSION,
        claimed: true,
        state_code: state,
        requested: rows.length,
        accepted,
        image_chunks_ok: imageChunksOk,
        image_chunks_failed: imageChunksFailed,
        image_samples_used: imageSamplesUsed,
        epqs_fallbacks: epqsFallbacks,
        persisted: saved.data,
      }), { status: 200, headers: H });
    } catch (e) {
      const msg = String((e as any)?.message || e);
      try {
        await sb.rpc("bridgepoint_3dep_fail_v927", {
          p_task_token: token,
          p_state_code: state,
          p_lease_token: lease,
          p_error: msg.slice(0, 1500),
        });
      } catch (_) {}
      throw e;
    }
  } catch (e) {
    return new Response(JSON.stringify({ complete: false, version: VERSION, error: String((e as any)?.message || e) }), { status: 500, headers: H });
  }
});
