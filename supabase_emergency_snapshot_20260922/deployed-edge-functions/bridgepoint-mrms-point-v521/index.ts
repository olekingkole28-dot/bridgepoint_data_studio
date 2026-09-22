import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { Buffer } from "node:buffer";
import grib2 from "npm:grib2-simple@1.1.1";

async function gunzip(bytes: Uint8Array): Promise<Uint8Array> {
  const ds = new DecompressionStream("gzip");
  const stream = new Blob([bytes]).stream().pipeThrough(ds);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const client = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
  const supplied = req.headers.get("x-bridgepoint-prestorm-token") ?? "";
  const { data: secretRow } = await client.schema("automation").from("prestorm_worker_secret_v516").select("token").eq("singleton", true).maybeSingle();
  if (!secretRow?.token || supplied !== secretRow.token) return new Response(JSON.stringify({ ok:false,error:"unauthorized" }),{status:401,headers:{"content-type":"application/json"}});
  const body = await req.json().catch(()=>({}));
  const lat = Number(body.lat), lon = Number(body.lon);
  if (!Number.isFinite(lat)||!Number.isFinite(lon)) return new Response(JSON.stringify({ok:false,error:"lat/lon required"}),{status:400,headers:{"content-type":"application/json"}});
  try {
    const sourceUrl = "https://mrms.ncep.noaa.gov/2D/MESH/MRMS_MESH.latest.grib2.gz";
    const res = await fetch(sourceUrl,{headers:{"User-Agent":"BridgePoint Intelligence (https://bridgepointintelligence.online)"}});
    if(!res.ok) throw new Error(`MRMS ${res.status}`);
    const compressed = new Uint8Array(await res.arrayBuffer());
    const raw = await gunzip(compressed);
    const parsed:any[] = grib2(Buffer.from(raw));
    if(!Array.isArray(parsed)||parsed.length===0) throw new Error("No GRIB messages parsed");
    const value = parsed[0].getValue(lon,lat);
    return new Response(JSON.stringify({ok:true,source:"NOAA_MRMS_MESH",source_url:sourceUrl,lat,lon,mesh_mm:value,mesh_inches:typeof value==='number'?value/25.4:null,reference_timestamp:parsed[0].referenceTimestamp??null,forecast_timestamp:parsed[0].forecastTimestamp??null,native_resolution_m_approx:1000,individual_hailstone_path:false}),{headers:{"content-type":"application/json","cache-control":"no-store"}});
  } catch(e){
    return new Response(JSON.stringify({ok:false,error:String(e?.message??e),parser:"grib2-simple",note:"MRMS GRIB2 template/compression may require a broader parser"}),{status:500,headers:{"content-type":"application/json"}});
  }
});