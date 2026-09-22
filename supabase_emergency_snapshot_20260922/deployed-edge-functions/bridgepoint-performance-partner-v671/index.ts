import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ORIGIN="https://bridgepointintelligence.online";
const cors={
  "Access-Control-Allow-Origin":ORIGIN,
  "Access-Control-Allow-Methods":"POST,OPTIONS",
  "Access-Control-Allow-Headers":"content-type",
  "Vary":"Origin",
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"}});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
  if(req.method!=="POST") return json({complete:false,error:"Method not allowed"},405);
  const origin=req.headers.get("origin")||"";
  if(origin && origin!==ORIGIN) return json({complete:false,error:"Origin not allowed"},403);
  const len=Number(req.headers.get("content-length")||0);
  if(len>16000) return json({complete:false,error:"Request too large"},413);

  try{
    const body=await req.json();
    if(String(body?.website||"").trim()) return json({complete:true,ignored:true});
    if(body?.accept_terms!==true) return json({complete:false,error:"Please acknowledge the partner terms."},400);

    const payload={
      p_full_name:String(body?.full_name||"").slice(0,120),
      p_email:String(body?.email||"").slice(0,254),
      p_audience_type:String(body?.audience_type||"").slice(0,60),
      p_channel_url:String(body?.channel_url||"").slice(0,500)||null,
      p_audience_description:String(body?.audience_description||"").slice(0,1200)||null,
      p_source:"PERFORMANCE_PARTNER_PAGE"
    };
    const url=Deno.env.get("SUPABASE_URL")!;
    const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const r=await fetch(`${url}/rest/v1/rpc/bridgepoint_performance_partner_apply_v671`,{
      method:"POST",
      headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},
      body:JSON.stringify(payload)
    });
    const text=await r.text();
    if(!r.ok){
      const safe=/Valid email|Name is required|Audience type|Channel URL/.test(text)?"Please check the form fields.":"We could not issue a partner link right now.";
      return json({complete:false,error:safe},400);
    }
    let data:unknown={}; try{data=JSON.parse(text)}catch{}
    return json(data,200);
  }catch(_){
    return json({complete:false,error:"We could not issue a partner link right now."},400);
  }
});
