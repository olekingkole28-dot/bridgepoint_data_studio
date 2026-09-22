const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"GET, OPTIONS",
  "Cache-Control":"public, max-age=60, stale-while-revalidate=120"
};
const esc=(s:unknown)=>String(s??"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;");
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="GET")return new Response("GET only",{status:405,headers:cors});
  const u=new URL(req.url),format=(u.searchParams.get("format")||"json").toLowerCase();
  const limit=Math.min(100,Math.max(1,Number(u.searchParams.get("limit")||20)||20));
  const supa=Deno.env.get("SUPABASE_URL")||"";
  const anon=Deno.env.get("SUPABASE_ANON_KEY")||"";
  const r=await fetch(supa+"/rest/v1/rpc/bridgepoint_public_exposure_stream_v5201",{
    method:"POST",
    headers:{"apikey":anon,"Authorization":"Bearer "+anon,"Content-Type":"application/json","Accept":"application/json"},
    body:JSON.stringify({p_limit:limit})
  });
  if(!r.ok)return new Response(JSON.stringify({error:"feed_upstream_unavailable",status:r.status}),{status:502,headers:{...cors,"Content-Type":"application/json"}});
  const d=await r.json();
  const canonical="https://bridgepointintelligence.online/distribution/";
  if(format==="xml"){
    const items=(d.events||[]).map((e:any)=>`<event><id>${esc(e.event_id)}</id><name>${esc(e.event_name)}</name><occurred_at>${esc(e.occurred_at)}</occurred_at><verified>${esc(e.verified)}</verified><magnitude>${esc(e.magnitude)}</magnitude><magnitude_unit>${esc(e.magnitude_unit)}</magnitude_unit><property_exposure_count>${esc(e.property_exposure_count)}</property_exposure_count><avg_exposure_score>${esc(e.avg_exposure_score)}</avg_exposure_score><avg_exposure_confidence>${esc(e.avg_exposure_confidence)}</avg_exposure_confidence><exposure_updated_at>${esc(e.exposure_updated_at)}</exposure_updated_at></event>`).join("");
    const xml=`<?xml version="1.0" encoding="UTF-8"?><bridgepoint_exposure_feed><mode>RESEARCH_CONTEXT_ONLY</mode><trade_instruction>false</trade_instruction><damage_determination>false</damage_determination><canonical>${canonical}</canonical><generated_at>${esc(d.generated_at)}</generated_at><events>${items}</events></bridgepoint_exposure_feed>`;
    return new Response(xml,{headers:{...cors,"Content-Type":"application/xml; charset=utf-8"}});
  }
  if(format==="rss"){
    const items=(d.events||[]).map((e:any)=>`<item><title>${esc(e.event_name)} · ${esc(e.property_exposure_count)} property exposures</title><guid isPermaLink="false">${esc(e.event_id)}</guid><pubDate>${new Date(e.exposure_updated_at||e.occurred_at||Date.now()).toUTCString()}</pubDate><description>${esc(`Verified: ${e.verified}; magnitude: ${e.magnitude??"n/a"} ${e.magnitude_unit??""}; average exposure confidence: ${e.avg_exposure_confidence??"n/a"}. Exposure is not proof of physical damage and is not a trading instruction.`)}</description><link>${canonical}</link></item>`).join("");
    const rss=`<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>BridgePoint Exposure Stream</title><link>${canonical}</link><description>Source-backed property-event exposure context. Research only; not damage proof or a trading instruction.</description><lastBuildDate>${new Date(d.generated_at||Date.now()).toUTCString()}</lastBuildDate>${items}</channel></rss>`;
    return new Response(rss,{headers:{...cors,"Content-Type":"application/rss+xml; charset=utf-8"}});
  }
  return new Response(JSON.stringify({
    ...d,
    canonical,
    license_note:"Public feed surface. Underlying source rights and attribution requirements remain source-specific.",
    interpretation:["Exposure is not proof of physical damage.","This feed is research/context only and is not a securities trading instruction, insurance decision, claim decision, lending decision, or engineering determination."]
  },null,2),{headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
});