import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"GET, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="GET") return json({complete:false,error:"Method not allowed"},405);
  const secret=Deno.env.get("STRIPE_SECRET_KEY")??"";
  const webhook=Deno.env.get("STRIPE_WEBHOOK_SECRET")??"";
  const appUrl=Deno.env.get("BRIDGEPOINT_APP_URL")??"";
  const environment=secret.startsWith("sk_live_")?"live":secret.startsWith("sk_test_")?"sandbox":"unconfigured";

  const base={
    complete:true,checked_at:new Date().toISOString(),stripe_secret_configured:Boolean(secret),webhook_secret_configured:Boolean(webhook),app_url_configured:Boolean(appUrl),environment,live_charges_enabled:false,payouts_enabled:false,details_submitted:false,account_id:null as string|null,readiness:"NOT_READY",payments_enabled:false,production_domain:appUrl.includes("bridgepointintelligence.online"),billing_contract_version:220,
  };

  if(!secret) return json({...base,readiness:"STRIPE_SECRET_MISSING"});
  try{
    const response=await fetch("https://api.stripe.com/v1/account",{headers:{Authorization:`Bearer ${secret}`}});
    const account=await response.json().catch(()=>({}));
    if(!response.ok) return json({...base,readiness:"STRIPE_ACCOUNT_CHECK_FAILED",stripe_status:response.status});
    const chargesEnabled=account.charges_enabled===true,payoutsEnabled=account.payouts_enabled===true,detailsSubmitted=account.details_submitted===true;
    const liveReady=environment==="live"&&chargesEnabled&&payoutsEnabled&&detailsSubmitted&&Boolean(webhook);
    const readiness=liveReady?"LIVE_READY":environment==="sandbox"?"SANDBOX_ONLY":"LIVE_SETUP_INCOMPLETE";
    return json({...base,account_id:typeof account.id==="string"?account.id:null,country:typeof account.country==="string"?account.country:null,default_currency:typeof account.default_currency==="string"?account.default_currency:null,business_type:typeof account.business_type==="string"?account.business_type:null,live_charges_enabled:chargesEnabled,payouts_enabled:payoutsEnabled,details_submitted:detailsSubmitted,requirements_due:Array.isArray(account.requirements?.currently_due)?account.requirements.currently_due.length:0,readiness,payments_enabled:liveReady});
  }catch(error){return json({...base,readiness:"STRIPE_ACCOUNT_CHECK_FAILED",error:String(error)});}
});
