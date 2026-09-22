import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const headers = {
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"GET, OPTIONS",
  "Content-Type":"application/json; charset=utf-8",
  "Cache-Control":"no-store"
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

const dormantEvent = {
  key:"year_one",
  active:false,
  configured_active:false,
  start_at:null,
  duration_days:365,
  day:0,
  progress:0,
  max_lives:3,
  world_mode:"continuous_us_jurisdictions",
  interior_policy:"fictional_generated_only",
  storm_type:"zombie_wall",
  storm_endgame_strategy:"major_city_showdown",
  rooftop_ziplines_enabled:true,
  battle_pass_levels:150,
  battle_pass_price_cents:999,
  commerce_enabled:false,
  payment_provider:null
};

Deno.serve(async (req: Request) => {
  const origin=req.headers.get("origin")||"";
  if (req.method === "OPTIONS"){
    if(!allowedOrigin(origin))return new Response("forbidden",{status:403,headers});
    return new Response("ok",{headers});
  }
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ok:false,error:"GET only"}),{status:405,headers});
  }
  if(!allowedOrigin(origin))return new Response(JSON.stringify({ok:false,error:"ORIGIN_NOT_ALLOWED"}),{status:403,headers});

  const url = Deno.env.get("SUPABASE_URL") || "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  // Fail closed: if server configuration is unavailable, Year One MUST remain dormant.
  if (!url || !serviceKey) {
    return new Response(JSON.stringify({
      ok:true,
      degraded:true,
      degradation_reason:"server_config_unavailable",
      event:dormantEvent,
      daily_reward:null,
      challenge_npcs:[],
      server_time:new Date().toISOString()
    }),{headers});
  }

  const db = createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});

  try {
    const ip=firstIp(req),day=new Date().toISOString().slice(0,10);
    const subject=(await sha256(ip+"|"+day+"|horizon-event-v5305")).slice(0,48);
    let originHost="";try{originHost=origin?new URL(origin).host:""}catch{}
    const gate=await db.rpc("bridgepoint_public_tile_gate_v5300",{p_subject_hash:subject,p_asset_key:"HORIZON_EVENT_V5305",p_origin_host:originHost});
    if(gate.error)throw new Error("RATE_GATE");
    if(gate.data?.allowed!==true)return new Response(JSON.stringify({ok:false,error:"RATE_LIMITED"}),{status:429,headers:{...headers,"Retry-After":"60"}});
    const configResult = await db
      .from("horizon_event_config")
      .select("*")
      .eq("event_key","year_one")
      .maybeSingle();

    if (configResult.error || !configResult.data) {
      console.warn("Horizon event config fallback",configResult.error?.message || "missing year_one row");
      return new Response(JSON.stringify({
        ok:true,
        degraded:true,
        degradation_reason:"event_config_unavailable",
        event:dormantEvent,
        daily_reward:null,
        challenge_npcs:[],
        server_time:new Date().toISOString()
      }),{headers});
    }

    const config = configResult.data;
    const now = Date.now();
    const start = config?.start_at ? new Date(config.start_at).getTime() : 0;
    const active = Boolean(config?.active && start && Number.isFinite(start) && now >= start);
    const elapsed = active ? Math.max(0,Math.floor((now-start)/86400000)) : 0;
    const durationDays = Math.max(1,Number(config.duration_days || 365));
    const day = active ? Math.min(durationDays,elapsed+1) : 0;
    const progress = active ? Math.min(1,elapsed/Math.max(1,durationDays-1)) : 0;

    const npcResult = await db
      .from("horizon_challenge_npc_archetypes")
      .select("*")
      .order("npc_key");

    let dailyReward = null;
    if (active && config?.daily_rewards_enabled) {
      const rewardResult = await db
        .from("horizon_daily_reward_catalog")
        .select("*")
        .eq("day_index",day)
        .maybeSingle();
      if (!rewardResult.error) dailyReward = rewardResult.data || null;
    }

    const event = {
      key:String(config.event_key || "year_one"),
      active,
      configured_active:Boolean(config.active),
      start_at:config.start_at || null,
      duration_days:durationDays,
      day,
      progress,
      max_lives:Math.max(1,Number(config.max_lives || 3)),
      world_mode:config.world_mode || dormantEvent.world_mode,
      interior_policy:config.interior_policy || dormantEvent.interior_policy,
      storm_type:config.storm_type || dormantEvent.storm_type,
      storm_endgame_strategy:config.storm_endgame_strategy || dormantEvent.storm_endgame_strategy,
      rooftop_ziplines_enabled:Boolean(config.rooftop_ziplines_enabled),
      battle_pass_levels:Math.max(1,Number(config.battle_pass_levels || 150)),
      battle_pass_price_cents:Math.max(0,Number(config.battle_pass_price_cents || 999)),
      commerce_enabled:false,
      payment_provider:null
    };

    return new Response(JSON.stringify({
      ok:true,
      degraded:Boolean(npcResult.error),
      degradation_reason:npcResult.error ? "npc_catalog_unavailable" : null,
      event,
      daily_reward:dailyReward,
      challenge_npcs:npcResult.error ? [] : (npcResult.data || []),
      server_time:new Date(now).toISOString()
    }),{headers});
  } catch (error) {
    console.error("Horizon event endpoint degraded",String(error?.message ?? error));
    return new Response(JSON.stringify({
      ok:true,
      degraded:true,
      degradation_reason:"event_endpoint_exception",
      event:dormantEvent,
      daily_reward:null,
      challenge_npcs:[],
      server_time:new Date().toISOString()
    }),{headers});
  }
});