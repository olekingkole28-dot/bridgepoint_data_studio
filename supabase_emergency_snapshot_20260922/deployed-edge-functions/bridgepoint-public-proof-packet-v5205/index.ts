const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"GET, OPTIONS","Cache-Control":"no-store"};
const json=(x:any,s=200)=>new Response(JSON.stringify(x,null,2),{status:s,headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
const hex=(buf:ArrayBuffer)=>[...new Uint8Array(buf)].map(b=>b.toString(16).padStart(2,"0")).join("");
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="GET")return json({error:"GET only"},405);
  const u=new URL(req.url),eventId=(u.searchParams.get("event_id")||"").trim();
  if(!/^[0-9a-f-]{36}$/i.test(eventId))return json({error:"valid event_id UUID required"},400);
  const supa=Deno.env.get("SUPABASE_URL")||"",anon=Deno.env.get("SUPABASE_ANON_KEY")||"";
  const rpc=async(name:string,body:any={})=>{const r=await fetch(supa+"/rest/v1/rpc/"+name,{method:"POST",headers:{"apikey":anon,"Authorization":"Bearer "+anon,"Content-Type":"application/json","Accept":"application/json"},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw new Error(name+": "+(d?.message||r.status));return d};
  try{
    const [audit,event,frontend,roof]=await Promise.all([
      rpc("bridgepoint_public_audit_status_v5203"),
      rpc("[REDACTED_LONG_LITERAL]",{p_event_id:eventId,p_limit:100}),
      rpc("bridgepoint_frontend_status_v5000"),
      rpc("bridgepoint_public_roof_status_v5100")
    ]);
    const stable={
      packet_version:"5205",
      event:event?.event||null,
      exposure_summary:event?.summary||null,
      exposure_rows:event?.rows||[],
      audit_method:{
        benchmark_mode:audit?.benchmark_mode,
        valid_latency_samples_24h:audit?.valid_latency_samples,
        median_seconds_24h:audit?.median_source_to_bridgepoint_seconds,
        p90_seconds_24h:audit?.p90_source_to_bridgepoint_seconds,
        p95_seconds_24h:audit?.p95_source_to_bridgepoint_seconds
      },
      infrastructure:{
        canonical_properties:frontend?.canonical_properties,
        unique_addresses:frontend?.unique_addresses,
        map_ready_buildings:frontend?.map_ready_buildings,
        parcel_fresh_jurisdictions:frontend?.parcel_fresh_jurisdictions,
        parcel_required_jurisdictions:frontend?.parcel_required_jurisdictions,
        source_roof_records:roof?.source_roof_records,
        exact_roof_plane_records:roof?.exact_roof_plane_records,
        pitch_records:roof?.pitch_records,
        direction_records:roof?.direction_records
      },
      interpretation:[
        "This packet is a reproducible evidence artifact, not a market-price opinion.",
        "Exposure is not proof of physical damage.",
        "Map-ready building geometry is distinct from source-backed roof attributes.",
        "No security/ticker mapping, trade instruction, claim decision or payment instruction is included."
      ]
    };
    const canonical=JSON.stringify(stable);
    const digest=hex(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(canonical)));
    return json({
      name:"BridgePoint Public Proof Packet",
      generated_at:new Date().toISOString(),
      sha256:digest,
      canonical_audit_url:"https://bridgepointintelligence.online/public-audit/",
      ...stable
    });
  }catch(e){return json({error:"proof_packet_failed",detail:String(e?.message||e)},502)}
});