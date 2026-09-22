import { createClient } from "npm:@supabase/supabase-js@2";

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
const APP='https://bridgepointintelligence.online/app';
async function timedFetch(url:string,ms=9000){const c=new AbortController();const t=setTimeout(()=>c.abort(),ms);const start=Date.now();try{const r=await fetch(url,{redirect:'follow',cache:'no-store',signal:c.signal,headers:{'user-agent':'BridgePoint-Resilience-Watch/320','cache-control':'no-cache'}});const text=await r.text();return {ok:r.ok,status:r.status,latency:Date.now()-start,bytes:text.length,hasBridgePoint:/BridgePoint|flutter/i.test(text)};}catch(e){return {ok:false,status:0,latency:Date.now()-start,bytes:0,error:String((e as any)?.message||e),hasBridgePoint:false};}finally{clearTimeout(t);}}

Deno.serve(async(req:Request)=>{
 try{
  if(req.method!=='POST')return json({complete:false,error:'POST required'},405);
  const url=Deno.env.get('SUPABASE_URL')!;const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const service=createClient(url,serviceKey,{auth:{persistSession:false}});
  const secret=await service.schema('automation').from('resilience_secret_v320').select('token').eq('singleton',true).single();
  if(secret.error||!secret.data||req.headers.get('x-bridgepoint-resilience-token')!==secret.data.token)return json({complete:false,error:'Unauthorized scheduler'},401);

  const [home,bootstrap]=await Promise.all([timedFetch(`${APP}/`,9000),timedFetch(`${APP}/flutter_bootstrap.js`,9000)]);
  const frontendOk=home.ok&&home.hasBridgePoint&&bootstrap.ok&&bootstrap.bytes>100;
  const frontendLatency=Math.max(home.latency,bootstrap.latency);

  const db=await service.schema('automation').from('system_status_v320').select('singleton,updated_at').eq('singleton',true).single();
  const databaseOk=!db.error&&!!db.data;
  const q=await service.schema('automation').from('v40_property_queue_health').select('pending,processing,failed,latest_completion').limit(1).maybeSingle();
  let workerOk=!q.error&&!!q.data;
  if(workerOk&&q.data){const pending=Number(q.data.pending??0),failed=Number(q.data.failed??0);const last=q.data.latest_completion?Date.parse(String(q.data.latest_completion)):0;workerOk=failed===0&&(pending===0||(last>0&&Date.now()-last<12*60*1000));}

  const detail={watch_version:320,home,bootstrap,queue_health:q.data??null,queue_health_error:q.error?.message??null};
  const evaluated=await service.rpc('[REDACTED_LONG_LITERAL]',{p_frontend_ok:frontendOk,p_frontend_latency_ms:frontendLatency,p_database_ok:databaseOk,p_worker_ok:workerOk,p_detail:detail});
  if(evaluated.error)return json({complete:false,error:evaluated.error.message,frontend_ok:frontendOk,database_ok:databaseOk,worker_ok:workerOk,detail},500);
  return json({complete:true,frontend_ok:frontendOk,database_ok:databaseOk,worker_ok:workerOk,frontend_latency_ms:frontendLatency,status:evaluated.data,checked_at:new Date().toISOString()});
 }catch(e){return json({complete:false,error:String((e as any)?.message||e)},500);}
});