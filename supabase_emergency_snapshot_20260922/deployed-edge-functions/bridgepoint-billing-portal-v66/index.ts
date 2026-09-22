import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});
const stripeEnvironment=(key:string)=>key.startsWith("sk_live_")?"live":key.startsWith("sk_test_")?"sandbox":"unconfigured";
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 if(req.method!=="POST") return json({complete:false,error:"Method not allowed"},405);
 try{
  const auth=req.headers.get("Authorization"); if(!auth) return json({complete:false,error:"Authentication required"},401);
  const url=Deno.env.get("SUPABASE_URL")!; const anon=Deno.env.get("SUPABASE_ANON_KEY")!; const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const stripe=Deno.env.get("STRIPE_SECRET_KEY")??""; if(!stripe) return json({complete:false,error:"Stripe secret is not configured",code:"STRIPE_SECRET_MISSING"},503);
  const appUrl=Deno.env.get("BRIDGEPOINT_APP_URL")??"https://bridgepointintelligence.online";
  const productionApp=appUrl.includes("bridgepointintelligence.online");
  const environment=stripeEnvironment(stripe);
  if(productionApp&&environment!=="live") return json({complete:false,error:"Live billing management is still being activated. No account changes were made.",code:"LIVE_BILLING_NOT_READY",stripe_environment:environment},503);
  const userRes=await fetch(`${url}/auth/v1/user`,{headers:{Authorization:auth,apikey:anon}}); if(!userRes.ok) return json({complete:false,error:"Invalid session"},401);
  const user=await userRes.json();
  const customerRes=await fetch(`${url}/rest/v1/rpc/bridgepoint_billing_customer_v66`,{method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify({p_user_id:user.id})});
  if(!customerRes.ok) return json({complete:false,error:"No Stripe customer is connected"},404);
  const customer=await customerRes.json(); if(!customer?.stripe_customer_id) return json({complete:false,error:"No active billing profile"},404);
  const form=new URLSearchParams({customer:customer.stripe_customer_id,return_url:`${appUrl}/?billing=returned`});
  const stripeRes=await fetch("https://api.stripe.com/v1/billing_portal/sessions",{method:"POST",headers:{Authorization:`Bearer ${stripe}`,"Content-Type":"application/x-www-form-urlencoded"},body:form});
  const session=await stripeRes.json(); if(!stripeRes.ok) return json({complete:false,error:session.error?.message??"Billing portal failed"},400);
  return json({complete:true,url:session.url,stripe_environment:environment,billing_contract_version:220});
 }catch(error){return json({complete:false,error:String(error)},500);}
});
