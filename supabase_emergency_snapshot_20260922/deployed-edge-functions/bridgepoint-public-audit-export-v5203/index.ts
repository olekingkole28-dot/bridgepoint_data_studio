const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"GET, OPTIONS",
  "Cache-Control":"public, max-age=30, stale-while-revalidate=90"
};
const esc=(v:any)=>{const s=String(v??"");return /[",\n\r]/.test(s)?'"'+s.replace(/"/g,'""')+'"':s};
const json=(x:any,status=200)=>new Response(JSON.stringify(x,null,2),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="GET")return json({error:"GET only"},405);
  const u=new URL(req.url),mode=(u.searchParams.get("mode")||"latency").toLowerCase(),format=(u.searchParams.get("format")||"json").toLowerCase();
  const limit=Math.min(1000,Math.max(1,Number(u.searchParams.get("limit")||100)||100));
  const eventId=(u.searchParams.get("event_id")||"").trim();
  const supa=Deno.env.get("SUPABASE_URL")||"",anon=Deno.env.get("SUPABASE_ANON_KEY")||"";
  const rpc=async(name:string,body:any)=>{
    const r=await fetch(supa+"/rest/v1/rpc/"+name,{method:"POST",headers:{"apikey":anon,"Authorization":"Bearer "+anon,"Content-Type":"application/json","Accept":"application/json"},body:JSON.stringify(body)});
    const d=await r.json(); if(!r.ok)throw new Error(d?.message||("RPC "+r.status)); return d;
  };
  try{
    let payload:any;
    if(mode==="status") payload=await rpc("bridgepoint_public_audit_status_v5203",{});
    else if(mode==="exposure"){
      if(!/^[0-9a-f-]{36}$/i.test(eventId))return json({error:"valid event_id UUID required for exposure mode"},400);
      payload=await rpc("[REDACTED_LONG_LITERAL]",{p_event_id:eventId,p_limit:limit});
    } else payload=await rpc("bridgepoint_public_latency_ledger_v5203",{p_limit:limit});
    const meta={
      product:"BridgePoint Public Evidence Audit",
      version:"5203",
      mode,
      market_mispricing_claim:false,
      securities_instruction:false,
      damage_determination:false,
      canonical:"https://bridgepointintelligence.online/public-audit/"
    };
    if(format!=="csv")return json({...meta,data:payload});
    let cols:string[]=[],rows:any[]=[];
    if(mode==="latency"){
      cols=["hazard_event_id","provider","hazard_type","event_name","observation_kind","severity","certainty","urgency","source_updated_at","bridgepoint_first_seen_at","source_to_bridgepoint_seconds","active","source_url"];
      rows=payload?.samples||[];
    } else if(mode==="exposure"){
      cols=["event_exposure_id","property_id","distance_meters","overlap_ratio","exposure_score","exposure_confidence","confidence_band","match_method","created_at","updated_at"];
      rows=payload?.rows||[];
    } else {
      cols=Object.keys(payload||{}); rows=[payload||{}];
    }
    const csv=[cols.join(","),...rows.map(r=>cols.map(k=>esc(r?.[k])).join(","))].join("\n");
    return new Response(csv,{headers:{...cors,"Content-Type":"text/csv; charset=utf-8","Content-Disposition":`inline; filename="bridgepoint-${mode}-audit-v5203.csv"`}});
  }catch(e){return json({error:"audit_export_failed",detail:String(e?.message||e)},502)}
});