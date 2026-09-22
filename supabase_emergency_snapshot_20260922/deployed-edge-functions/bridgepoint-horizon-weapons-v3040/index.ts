import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, OPTIONS"
};
const ALLOWED_ORIGINS=new Set([
  "https://bridgepointintelligence.online",
  "https://www.bridgepointintelligence.online",
  "https://olekingkole28-dot.github.io"
]);
function allowedOrigin(origin:string){
  if(!origin)return true;
  if(ALLOWED_ORIGINS.has(origin))return true;
  try{const u=new URL(origin);return (u.hostname==="localhost"||u.hostname==="127.0.0.1")&&(u.protocol==="http:"||u.protocol==="https:")}catch{return false}
}
async function sha256(s:string){
  const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
function firstIp(req:Request){
  const raw=req.headers.get("x-forwarded-for")||req.headers.get("cf-connecting-ip")||req.headers.get("x-real-ip")||"unknown";
  return raw.split(",")[0].trim().slice(0,80);
}

Deno.serve(async (req: Request) => {
  const origin=req.headers.get("origin")||"";
  if (req.method === "OPTIONS"){
    if(!allowedOrigin(origin))return new Response("forbidden",{status:403,headers:cors});
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "GET") return new Response("Method not allowed", { status: 405, headers: cors });
  if(!allowedOrigin(origin))return new Response(JSON.stringify({ok:false,error:"ORIGIN_NOT_ALLOWED"}),{status:403,headers:{...cors,"content-type":"application/json","cache-control":"no-store"}});
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, key, { auth: { persistSession: false } });
    const ip=firstIp(req),day=new Date().toISOString().slice(0,10);
    const subject=(await sha256(ip+"|"+day+"|horizon-weapons-v5305")).slice(0,48);
    let originHost="";try{originHost=origin?new URL(origin).host:""}catch{}
    const gate=await supabase.rpc("bridgepoint_public_tile_gate_v5300",{p_subject_hash:subject,p_asset_key:"HORIZON_WEAPONS_V5305",p_origin_host:originHost});
    if(gate.error)throw new Error("RATE_GATE");
    if(gate.data?.allowed!==true)return new Response(JSON.stringify({ok:false,error:"RATE_LIMITED"}),{status:429,headers:{...cors,"content-type":"application/json","cache-control":"no-store","retry-after":"60"}});
    const { data, error } = await supabase
      .from("weapon_registry")
      .select("weapon_id,weapon_name,weapon_type,equip_slot,model_url,asset_source,asset_source_url,license_code,stance_type,fire_mode,damage,range_m,magazine_size,reserve_default,fire_interval_seconds,reload_time_seconds,recoil_pitch_deg,recoil_yaw_deg,spread_deg,aim_fov,two_handed,hitscan,metadata")
      .eq("enabled", true)
      .order("weapon_type")
      .order("weapon_name");
    if (error) throw error;
    return new Response(JSON.stringify({
      ok: true,
      schema: "bridgepoint.weapon_registry.v1",
      generated_at: new Date().toISOString(),
      weapons: data ?? []
    }), {
      headers: { ...cors, "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=60, stale-while-revalidate=300" }
    });
  } catch (error) {
    return new Response(JSON.stringify({ ok:false, error: String(error?.message ?? error) }), {
      status: 500,
      headers: { ...cors, "content-type": "application/json; charset=utf-8" }
    });
  }
});