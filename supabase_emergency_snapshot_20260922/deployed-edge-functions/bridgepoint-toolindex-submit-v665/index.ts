import { createClient } from "npm:@supabase/supabase-js@2";
const U=Deno.env.get("SUPABASE_URL")!, S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const H={"content-type":"application/json"};
const TARGET="TOOLINDEX";
const PAGE="https://strategic-flow-audit.replit.app/directory";
const API="https://strategic-flow-audit.replit.app/api/directory/submit";
const ASSET="https://bridgepointintelligence.online/for-roofers/?utm_source=toolindex&utm_medium=directory&utm_campaign=general_b2b_v645";
async function receipt(s:any,status:string,http:number|null,live:string|null,detail:any){
  await s.from("external_directory_receipts_v662").insert({target_key:TARGET,status,http_status:http,live_url:live,detail});
}
Deno.serve(async(req:Request)=>{
 const s=createClient(U,S,{auth:{persistSession:false}});
 try{
  const b=await req.json().catch(()=>({}));
  const au=await s.rpc("bridgepoint_expansion_worker_auth_v90",{p_task_token:String(b.task_token||"")});
  if(au.error||au.data!==true)return new Response(JSON.stringify({complete:false,error:"Invalid task token"}),{status:401,headers:H});
  const prior=await s.from("external_directory_receipts_v662").select("status,attempted_at,live_url").eq("target_key",TARGET).in("status",["SUBMITTED","VERIFIED","ALREADY_LIVE"]).order("attempted_at",{ascending:false}).limit(1);
  if(prior.error)throw prior.error;
  if((prior.data||[]).length){
    await receipt(s,"ALREADY_LIVE",200,prior.data[0].live_url||null,{reason:"DEDUPED_PRIOR_CONFIRMED_SUBMISSION",prior:prior.data[0]});
    return new Response(JSON.stringify({complete:true,status:"ALREADY_SUBMITTED",prior:prior.data[0]}),{status:200,headers:H});
  }
  const payload={name:"BridgePoint Intelligence",url:ASSET,category:"Analytics",description:"Property and claims intelligence for roofing contractors, combining property records, geospatial matching, weather context, evidence provenance, scoring, maps, and timelines.",email:"",terms_accepted:true};
  const post=await fetch(API,{method:"POST",headers:{"content-type":"application/json","referer":PAGE,"user-agent":"BridgePoint-Directory-Submission/1.0 (+https://bridgepointintelligence.online/about/)"},body:JSON.stringify(payload)});
  const bodyText=await post.text(); let d:any={}; try{d=JSON.parse(bodyText)}catch{}
  const success=post.ok&&d.success===true&&Number.isFinite(Number(d.id));
  const id=success?Number(d.id):null;
  const live=id?("https://strategic-flow-audit.replit.app/directory/bridgepoint-intelligence-"+id):null;
  const status=success?"SUBMITTED":(post.ok?"ABORTED":"FAILED");
  await receipt(s,status,post.status,live,{response:d,response_preview:bodyText.slice(0,1200),asset_url:ASSET,payload_public:{name:payload.name,url:payload.url,category:payload.category,description:payload.description,email_omitted:true,terms_accepted:true}});
  return new Response(JSON.stringify({complete:success,status,http_status:post.status,id,live_url:live,response:d}),{status:success?200:(post.ok?409:502),headers:H});
 }catch(e){
  return new Response(JSON.stringify({complete:false,status:"FAILED",error:String((e as any)?.message||e)}),{status:500,headers:H});
 }
});