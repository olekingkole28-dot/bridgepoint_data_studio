const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"GET, OPTIONS","Cache-Control":"public, max-age=60, stale-while-revalidate=120"};
const esc=(v:any)=>{const s=String(v??"");return /[",\n\r]/.test(s)?'"'+s.replace(/"/g,'""')+'"':s};
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="GET")return new Response("GET only",{status:405,headers:cors});
  const u=new URL(req.url),format=(u.searchParams.get("format")||"json").toLowerCase(),state=(u.searchParams.get("state")||"").trim().toUpperCase();
  const supa=Deno.env.get("SUPABASE_URL")||"",anon=Deno.env.get("SUPABASE_ANON_KEY")||"";
  const r=await fetch(supa+"/rest/v1/rpc/bridgepoint_public_data_discrepancy_ledger_v5208",{method:"POST",headers:{"apikey":anon,"Authorization":"Bearer "+anon,"Content-Type":"application/json","Accept":"application/json"},body:JSON.stringify({p_state_code:state||null})});
  const d=await r.json();if(!r.ok)return new Response(JSON.stringify({error:"upstream",status:r.status}),{status:502,headers:{...cors,"Content-Type":"application/json"}});
  if(format!=="csv")return new Response(JSON.stringify(d,null,2),{headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
  const cols=["state_code","sample_rows","missing_anchor_rows","missing_anchor_pct","sample_rate_pct","sampled_at","canonical_identity_collision_groups","address_parity_rows_scanned","addresses_recovered","addresses_normalized","feed_rows_refreshed","address_parity_last_run_at"];
  const rows=d.jurisdictions||[];const csv=[cols.join(","),...rows.map((x:any)=>cols.map(k=>esc(x?.[k])).join(","))].join("\n");
  return new Response(csv,{headers:{...cors,"Content-Type":"text/csv; charset=utf-8","Content-Disposition":'inline; filename="[REDACTED_LONG_LITERAL]"'}});
});