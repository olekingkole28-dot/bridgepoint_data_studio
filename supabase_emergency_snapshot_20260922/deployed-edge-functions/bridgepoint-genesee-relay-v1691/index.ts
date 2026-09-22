import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const KEY = "G26049_s9Qm2x4L7pR8vN3cK6tW";
const BASE = "https://app.fetchgis.com/geoservices/fgis/genParcels/FeatureServer/0";
const PREFIX = `/${KEY}/FeatureServer/0`;
const ALLOWED = new Set([
  "f","where","outFields","returnCountOnly","returnGeometry","returnIdsOnly",
  "orderByFields","resultRecordCount","resultOffset","objectIds","outSR",
  "returnCentroid","geometry","geometryType","spatialRel","inSR"
]);
const H = {"content-type":"application/json","cache-control":"no-store"};

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "GET") return new Response(JSON.stringify({error:"GET_REQUIRED"}), {status:405, headers:H});
    const u = new URL(req.url);
    const marker = "/bridgepoint-genesee-relay-v1691";
    const idx = u.pathname.indexOf(marker);
    const p = idx >= 0 ? u.pathname.slice(idx + marker.length) : u.pathname;
    if (!(p === PREFIX || p === `${PREFIX}/query`)) {
      return new Response(JSON.stringify({error:"NOT_FOUND"}), {status:404, headers:H});
    }
    const upstream = new URL(BASE + (p.endsWith("/query") ? "/query" : ""));
    for (const [k,v] of u.searchParams.entries()) if (ALLOWED.has(k)) upstream.searchParams.append(k,v);
    if (!upstream.searchParams.has("f")) upstream.searchParams.set("f","json");
    const client = Deno.createHttpClient({ http2: false });
    try {
      const r = await fetch(upstream, {
        method:"GET",
        headers:{"accept":"application/json","user-agent":"BridgePointIntelligence/1.0"},
        client,
        signal: AbortSignal.timeout(45000)
      } as RequestInit & {client: Deno.HttpClient});
      const body = await r.text();
      return new Response(body, {status:r.status, headers:{"content-type":r.headers.get("content-type") || "application/json","cache-control":"no-store"}});
    } finally {
      client.close();
    }
  } catch (e) {
    return new Response(JSON.stringify({error:String((e as Error)?.message || e)}), {status:502, headers:H});
  }
});