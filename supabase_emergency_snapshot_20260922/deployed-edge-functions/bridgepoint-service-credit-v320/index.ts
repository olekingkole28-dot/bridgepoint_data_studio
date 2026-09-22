import { createClient } from "npm:@supabase/supabase-js@2";
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
async function result(service:any,id:string,status:string,external:string|null,failure:string|null,metadata:Record<string,unknown>){const r=await service.rpc('bridgepoint_service_credit_result_v320',{p_service_credit_id:id,p_status:status,p_external_balance_transaction_id:external,p_failure_reason:failure,p_metadata:metadata});if(r.error)throw r.error;}
Deno.serve(async(req:Request)=>{
 try{
  if(req.method!=='POST')return json({complete:false,error:'POST required'},405);
  const url=Deno.env.get('SUPABASE_URL')!;const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;const stripe=Deno.env.get('STRIPE_SECRET_KEY')??'';
  const service=createClient(url,serviceKey,{auth:{persistSession:false}});
  const secret=await service.schema('automation').from('resilience_secret_v320').select('token').eq('singleton',true).single();
  if(secret.error||!secret.data||req.headers.get('x-bridgepoint-resilience-token')!==secret.data.token)return json({complete:false,error:'Unauthorized scheduler'},401);
  if(!stripe.startsWith('sk_live_'))return json({complete:true,live_stripe_ready:false,applied:0,message:'No live Stripe service credits attempted; live billing key is not configured.'});
  const pending=await service.rpc('bridgepoint_service_credit_pending_v320',{p_limit:25});if(pending.error)throw pending.error;
  const credits=Array.isArray(pending.data?.credits)?pending.data.credits:[];let applied=0,failed=0,deferred=0;const details:any[]=[];
  for(const c of credits){
   const id=String(c.service_credit_id),customer=String(c.external_customer_id??''),amount=Math.max(0,Number(c.amount_cents??0));
   if(!customer.startsWith('cus_')||amount<=0){await result(service,id,'SKIPPED',null,'Missing valid live Stripe customer or credit amount',{dispatcher_version:320});details.push({id,status:'SKIPPED'});continue;}
   const form=new URLSearchParams();form.set('amount',String(-amount));form.set('currency',String(c.currency??'usd').toLowerCase());form.set('description',`BridgePoint automatic service credit for incident ${c.incident_id}`);form.set('metadata[bridgepoint_service_credit_id]',id);form.set('metadata[bridgepoint_incident_id]',String(c.incident_id));form.set('metadata[bridgepoint_subscription_id]',String(c.subscription_id));form.set('metadata[bridgepoint_policy_version]','320');
   let response:Response;try{response=await fetch(`https://api.stripe.com/v1/customers/${encodeURIComponent(customer)}/balance_transactions`,{method:'POST',headers:{Authorization:`Bearer ${stripe}`,'Content-Type':'application/x-www-form-urlencoded','Idempotency-Key':`bridgepoint-service-credit-${id}`},body:form});}catch(e){deferred++;await result(service,id,'PENDING',null,String((e as any)?.message||e),{dispatcher_version:320,last_attempt_at:new Date().toISOString(),retryable:true});details.push({id,status:'DEFERRED'});continue;}
   const payload=await response.json().catch(()=>({}));
   if(response.ok&&payload?.id){applied++;await result(service,id,'APPLIED',String(payload.id),null,{dispatcher_version:320,ending_balance:payload.ending_balance??null,stripe_livemode:payload.livemode??true});details.push({id,status:'APPLIED',stripe_id:payload.id});}
   else if(response.status>=500||response.status===429){deferred++;await result(service,id,'PENDING',null,String(payload?.error?.message??`Stripe ${response.status}`),{dispatcher_version:320,last_attempt_at:new Date().toISOString(),retryable:true,http_status:response.status});details.push({id,status:'DEFERRED',http_status:response.status});}
   else{failed++;await result(service,id,'FAILED',null,String(payload?.error?.message??`Stripe ${response.status}`),{dispatcher_version:320,last_attempt_at:new Date().toISOString(),retryable:false,http_status:response.status});details.push({id,status:'FAILED',http_status:response.status});}
  }
  return json({complete:true,live_stripe_ready:true,pending_seen:credits.length,applied,failed,deferred,details});
 }catch(e){return json({complete:false,error:String((e as any)?.message||e)},500);}
});