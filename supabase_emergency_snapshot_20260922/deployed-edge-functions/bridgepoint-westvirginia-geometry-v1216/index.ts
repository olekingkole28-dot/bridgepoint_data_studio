import { createClient } from "npm:@supabase/supabase-js@2";

const U = Deno.env.get("SUPABASE_URL")!;
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H = { "content-type": "application/json" };
const V = 1216;
const LANE_WIDTH = 2000;
const SUB_WIDTH = 500;
const STRIDE = 8000;
const APPLY_CHUNK = 500;

async function fetchJson(url: string, ms: number) {
  const started = Date.now();
  const r = await fetch(url, {
    signal: AbortSignal.timeout(ms),
    headers: { accept: "application/json", "user-agent": "BridgePointIntelligence/1.0" },
  });
  const txt = await r.text();
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${txt.slice(0, 220)}`);
  let j: any;
  try { j = JSON.parse(txt); } catch { throw new Error("Unparseable ArcGIS JSON"); }
  if (j?.error) throw new Error(`ArcGIS ${j.error.code || ""}: ${j.error.message || "error"}`);
  return { j, ms: Date.now() - started };
}

async function queryRange(base: string, of: string, lo: number, hi: number, geometry = false) {
  const where = `${of}>${lo} AND ${of}<=${hi}`;
  const q = `${base}/query?where=${encodeURIComponent(where)}` +
    `&outFields=${encodeURIComponent(of)}` +
    `&returnGeometry=${geometry ? "true" : "false"}` +
    `&returnCentroid=${geometry ? "false" : "true"}` +
    `&outSR=4326&orderByFields=${encodeURIComponent(of + " ASC")}` +
    `&resultRecordCount=${Math.max(1, hi - lo)}&geometryPrecision=6&f=json`;
  return await fetchJson(q, geometry ? 18000 : 10000);
}

function pointFor(f: any) {
  const c = f?.centroid;
  if (Number.isFinite(c?.x) && Number.isFinite(c?.y)) return { lng: Number(c.x), lat: Number(c.y) };
  const g = f?.geometry;
  if (Number.isFinite(g?.x) && Number.isFinite(g?.y)) return { lng: Number(g.x), lat: Number(g.y) };
  const rings = g?.rings;
  if (Array.isArray(rings)) {
    let minx = Infinity, maxx = -Infinity, miny = Infinity, maxy = -Infinity, n = 0;
    for (const ring of rings) {
      if (!Array.isArray(ring)) continue;
      for (const pt of ring) {
        const x = Number(pt?.[0]), y = Number(pt?.[1]);
        if (Number.isFinite(x) && Number.isFinite(y)) {
          minx = Math.min(minx, x); maxx = Math.max(maxx, x);
          miny = Math.min(miny, y); maxy = Math.max(maxy, y); n++;
        }
      }
    }
    if (n) return { lng: (minx + maxx) / 2, lat: (miny + maxy) / 2 };
  }
  return null;
}

async function fetchSub(base: string, of: string, lo: number, hi: number) {
  try {
    const a = await queryRange(base, of, lo, hi, false);
    const fs = a.j.features || [];
    if (fs.length === 0 || fs.some((f: any) => pointFor(f))) {
      return { features: fs, ms: a.ms, fallback: false };
    }
  } catch (_) {}
  const b = await queryRange(base, of, lo, hi, true);
  return { features: b.j.features || [], ms: b.ms, fallback: true };
}

Deno.serve(async (req: Request) => {
  const s = createClient(U, S, { auth: { persistSession: false } });
  let lane = 0;
  try {
    const b = await req.json().catch(() => ({}));
    lane = Math.max(0, Math.min(3, Number(b.lane || 0)));
    const ok = await s.rpc("bridgepoint_expansion_worker_auth_v90", { p_task_token: String(b.task_token || "") });
    if (ok.error || ok.data !== true) {
      return new Response(JSON.stringify({ complete: false, error: "Invalid task token" }), { status: 401, headers: H });
    }

    const sq = await s.schema("automation").from("westvirginia_geometry_lane_state_v1216").select("*").eq("lane", lane).single();
    if (sq.error) throw new Error(sq.error.message);
    const state: any = sq.data;

    const tq = await s.schema("automation").from("geographic_source_tasks_v90")
      .select("cursor,result").eq("state_code", "WV").eq("task_type", "ACQUIRE_PROPERTY_FOUNDATION")
      .order("updated_at", { ascending: false }).limit(1);
    if (tq.error) throw new Error(tq.error.message);
    const task: any = tq.data?.[0];
    if (!task) return new Response(JSON.stringify({ complete: true, skipped: "NO_WV_TASK" }), { headers: H });

    const cur = task.cursor || {}, prev = task.result || {};
    const base = String(cur.layer || prev.layer || "https://services.wvgis.wvu.edu/arcgis/rest/services/Planning_Cadastre/WV_Parcels/MapServer/0").replace(/\/$/, "");
    const of = String(cur.object_id_field || prev.object_id_field || "OBJECTID");
    const ingestOid = Number(cur.last_oid || prev.last_oid || 0) || 0;
    const maxOid = Number(state.max_oid || 0) || Number(cur.max_oid || prev.max_oid || 0) || ingestOid;
    const start = Number(state.next_window_start || 0);

    if (start >= maxOid) return new Response(JSON.stringify({ complete: true, version: V, lane, done: true }), { headers: H });
    const laneEnd = Math.min(start + LANE_WIDTH, ingestOid, maxOid);
    if (start >= laneEnd) return new Response(JSON.stringify({ complete: true, version: V, lane, waiting: true }), { headers: H });

    const defs: Array<{ lo: number; hi: number }> = [];
    for (let lo = start; lo < laneEnd; lo += SUB_WIDTH) defs.push({ lo, hi: Math.min(lo + SUB_WIDTH, laneEnd) });

    const got: any[] = [];
    for (let i = 0; i < defs.length; i += 2) {
      const wave = defs.slice(i, i + 2);
      const results = await Promise.all(wave.map(async (d) => ({ ...d, ...(await fetchSub(base, of, d.lo, d.hi)) })));
      got.push(...results);
    }

    const raw: any[] = [];
    for (const g of got) raw.push(...g.features);
    const recs: any[] = [];
    for (const f of raw) {
      const a = f.attributes || {};
      const id = Number(a[of] ?? a.OBJECTID ?? a.objectid);
      const p = pointFor(f);
      if (Number.isFinite(id) && p && p.lat >= 37 && p.lat <= 41.5 && p.lng >= -83.5 && p.lng <= -77) {
        recs.push({ source_record_id: String(id), lat: p.lat, lng: p.lng });
      }
    }

    const done = start + STRIDE >= maxOid;
    let stage = 0, props = 0, addrs = 0;
    for (let i = 0; i < recs.length; i += APPLY_CHUNK) {
      const ap = await s.schema("automation").rpc("apply_westvirginia_geometry_batch_v1216", {
        p_lane: lane,
        p_records: recs.slice(i, i + APPLY_CHUNK),
        p_window_start: start,
        p_window_end: laneEnd,
        p_max_oid: maxOid,
        p_done: done && i + APPLY_CHUNK >= recs.length,
      });
      if (ap.error) throw new Error(ap.error.message);
      stage += Number(ap.data?.staging_rows_updated || 0);
      props += Number(ap.data?.properties_updated || 0);
      addrs += Number(ap.data?.addresses_updated || 0);
    }
    if (!recs.length) {
      const ap = await s.schema("automation").rpc("apply_westvirginia_geometry_batch_v1216", {
        p_lane: lane, p_records: [], p_window_start: start, p_window_end: laneEnd, p_max_oid: maxOid, p_done: done,
      });
      if (ap.error) throw new Error(ap.error.message);
    }

    return new Response(JSON.stringify({
      complete: true, version: V, lane, features: raw.length, coordinates: recs.length,
      window_start: start, window_end: laneEnd, next_window_start: start + STRIDE, max_oid: maxOid,
      fallback_subranges: got.filter((x: any) => x.fallback).length,
      staging_rows_updated: stage, properties_updated: props, addresses_updated: addrs, done,
    }), { headers: H });
  } catch (e) {
    try {
      const q = await s.schema("automation").from("westvirginia_geometry_lane_state_v1216").select("consecutive_failures").eq("lane", lane).single();
      await s.schema("automation").from("westvirginia_geometry_lane_state_v1216").update({
        consecutive_failures: Number(q.data?.consecutive_failures || 0) + 1,
        last_error: String((e as any)?.message || e), updated_at: new Date().toISOString(),
      }).eq("lane", lane);
    } catch (_) {}
    return new Response(JSON.stringify({ complete: false, version: V, lane, error: String((e as any)?.message || e) }), { status: 400, headers: H });
  }
});
