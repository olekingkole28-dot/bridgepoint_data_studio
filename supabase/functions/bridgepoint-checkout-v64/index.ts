import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});

Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 try{
  const auth=req.headers.get("Authorization");
  if(!auth) return json({complete:false,error:"Authentication required"},401);
  const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
  const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const stripe=Deno.env.get("STRIPE_SECRET_KEY");
  if(!stripe) return json({complete:false,error:"Stripe secret is not configured"},503);
  const userRes=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{Authorization:auth,apikey:anon}});
  if(!userRes.ok) return json({complete:false,error:"Invalid session"},401);
  const user=await userRes.json();
  const input=await req.json();
  const ctxRes=await fetch(`${supabaseUrl}/rest/v1/rpc/bridgepoint_billing_checkout_context_v64`,{
   method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},
   body:JSON.stringify({p_user_id:user.id,p_package_key:input.package_key,p_interval:input.interval??"month"})
  });
  if(!ctxRes.ok) return json({complete:false,error:await ctxRes.text()},400);
  const ctx=await ctxRes.json();
  const appUrl=Deno.env.get("BRIDGEPOINT_APP_URL")??"http://localhost:49981";
  const form=new URLSearchParams();
  form.set("mode","subscription");
  form.set("integration_identifier","bridgepoint_checkout_kjrmxqta");
  form.set("line_items[0][price]",ctx.stripe_price_id);
  form.set("line_items[0][quantity]","1");
  form.set("success_url",`${appUrl}/?checkout=success&session_id={CHECKOUT_SESSION_ID}`);
  form.set("cancel_url",`${appUrl}/?checkout=cancelled`);
  form.set("client_reference_id",user.id);
  form.set("customer_email",ctx.email);
  form.set("subscription_data[trial_period_days]","7");
  form.set("subscription_data[metadata][bridgepoint_user_id]",user.id);
  form.set("subscription_data[metadata][bridgepoint_package_key]",ctx.package_key);
  form.set("metadata[bridgepoint_user_id]",user.id);
  form.set("metadata[bridgepoint_package_key]",ctx.package_key);
  if(ctx.promotion_assignment_id) form.set("metadata[promotion_assignment_id]",ctx.promotion_assignment_id);
  if(ctx.coupon_id) form.set("discounts[0][coupon]",ctx.coupon_id);
  const stripeRes=await fetch("https://api.stripe.com/v1/checkout/sessions",{method:"POST",headers:{Authorization:`Bearer ${stripe}`,"Content-Type":"application/x-www-form-urlencoded"},body:form});
  const session=await stripeRes.json();
  if(!stripeRes.ok) return json({complete:false,error:session.error?.message??"Stripe checkout failed"},400);
  return json({complete:true,url:session.url,session_id:session.id});
 }catch(error){return json({complete:false,error:String(error)},500);}
});
