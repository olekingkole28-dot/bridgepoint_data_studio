import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});
const stripeEnvironment=(key:string)=>key.startsWith("sk_live_")?"live":key.startsWith("sk_test_")?"sandbox":"unconfigured";
const short=(v:unknown,n=480)=>String(v??"").replace(/\s+/g," ").trim().slice(0,n);
const trackCheckout=async(supabaseUrl:string,anon:string,auth:string,userId:string,packageKey:unknown,interval:unknown,skipTrial:boolean)=>{
  try{
    await fetch(`${supabaseUrl}/rest/v1/rpc/track_acquisition_event_v400`,{
      method:"POST",
      headers:{apikey:anon,Authorization:auth,"Content-Type":"application/json"},
      body:JSON.stringify({
        p_event_type:"CHECKOUT_START",
        p_visitor_id:`auth-${userId}`,
        p_session_id:`checkout-${userId}-${new Date().toISOString().slice(0,13)}`,
        p_page_path:"/app/#packages",
        p_platform:"FLUTTER",
        p_referrer_host:null,p_utm_source:null,p_utm_medium:null,p_utm_campaign:null,p_utm_content:null,p_referral_code:null,p_auth_error_code:null,
        p_metadata:{capture_version:486,source:"checkout_edge",package_key:String(packageKey??"unknown").slice(0,80),interval:String(interval??"month").slice(0,20),billing_start:skipTrial?"IMMEDIATE_PAID":"TRIAL_IF_ELIGIBLE"}
      })
    });
  }catch(_){/* tracking must never block checkout */}
};

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="POST") return json({complete:false,error:"Method not allowed"},405);
  try{
    const auth=req.headers.get("Authorization");
    if(!auth) return json({complete:false,error:"Authentication required"},401);
    const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
    const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
    const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const stripe=Deno.env.get("STRIPE_SECRET_KEY")??"";
    const configuredAppUrl=(Deno.env.get("BRIDGEPOINT_APP_URL")??"https://bridgepointintelligence.online").replace(/\/+$/,"");
    const appUrl=configuredAppUrl.endsWith("/app")?configuredAppUrl:`${configuredAppUrl}/app`;
    const productionApp=configuredAppUrl.includes("bridgepointintelligence.online");
    const secretEnvironment=stripeEnvironment(stripe);
    if(!stripe) return json({complete:false,error:"Stripe secret is not configured",code:"STRIPE_SECRET_MISSING"},503);
    if(productionApp&&secretEnvironment!=="live") return json({complete:false,error:"Live payments are still being activated. No charge was attempted.",code:"LIVE_BILLING_NOT_READY",stripe_environment:secretEnvironment},503);

    const userRes=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{Authorization:auth,apikey:anon}});
    if(!userRes.ok) return json({complete:false,error:"Invalid session"},401);
    const user=await userRes.json();
    const input=await req.json();
    const interval=input.interval??"month";
    const skipTrial=input.skip_trial===true||input.billing_start==="IMMEDIATE_PAID";
    await trackCheckout(supabaseUrl,anon,auth,user.id,input.package_key,interval,skipTrial);
    const ctxRes=await fetch(`${supabaseUrl}/rest/v1/rpc/bridgepoint_billing_checkout_context_v64`,{method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify({p_user_id:user.id,p_package_key:input.package_key,p_interval:interval})});
    if(!ctxRes.ok) return json({complete:false,error:await ctxRes.text()},400);
    const ctx=await ctxRes.json();
    if(!ctx.stripe_price_id) return json({complete:false,error:"Stripe price is not configured for this package"},503);
    if(productionApp&&ctx.stripe_environment!=="live") return json({complete:false,error:"Live pricing is still being activated. No charge was attempted.",code:"LIVE_CATALOG_NOT_READY",stripe_environment:ctx.stripe_environment??"unknown"},503);

    const form=new URLSearchParams();
    form.set("mode","subscription");
    form.set("integration_identifier","bridgepoint_checkout_kjrmxqta");
    form.set("line_items[0][price]",ctx.stripe_price_id);
    form.set("line_items[0][quantity]","1");
    form.set("success_url",`${appUrl}/?checkout=success&session_id={CHECKOUT_SESSION_ID}`);
    form.set("cancel_url",`${appUrl}/?checkout=cancelled`);
    form.set("client_reference_id",user.id);
    form.set("payment_method_collection","always");
    if(ctx.stripe_customer_id) form.set("customer",ctx.stripe_customer_id); else form.set("customer_email",ctx.email);
    const remaining=Number(ctx.trial_days_remaining??0);
    const effectiveTrialDays=skipTrial?0:(Number.isFinite(remaining)&&remaining>0?Math.min(remaining,7):0);
    if(effectiveTrialDays>0) form.set("subscription_data[trial_period_days]",String(effectiveTrialDays));

    const metadata:Record<string,string>={bridgepoint_user_id:String(user.id),bridgepoint_package_key:String(ctx.package_key),bridgepoint_interval:String(interval),bridgepoint_purchase_mode:skipTrial?"IMMEDIATE_PAID_ACTIVATION":String(ctx.purchase_mode??"IMMEDIATE"),bridgepoint_delivery_status:String(ctx.delivery_status??"READY"),bridgepoint_delivery_mode:String(ctx.delivery_mode??"APP"),bridgepoint_rules_version:String(ctx.purchase_rules_version??223),bridgepoint_auto_renew:"true",bridgepoint_card_on_file:"stripe_managed",bridgepoint_billing_start:skipTrial?"IMMEDIATE_PAID":"TRIAL_IF_ELIGIBLE"};
    for(const [k,v] of Object.entries(metadata)){form.set(`subscription_data[metadata][${k}]`,v);form.set(`metadata[${k}]`,v);}
    if(ctx.organization_id){form.set("subscription_data[metadata][bridgepoint_organization_id]",String(ctx.organization_id));form.set("metadata[bridgepoint_organization_id]",String(ctx.organization_id));}
    if(ctx.promotion_assignment_id) form.set("metadata[promotion_assignment_id]",ctx.promotion_assignment_id);
    if(ctx.coupon_id) form.set("discounts[0][coupon]",ctx.coupon_id);

    const disclosure=short(ctx.delivery_disclosure,300);
    const renewal=effectiveTrialDays>0?"Your card is securely saved by Stripe. After your trial, the subscription renews automatically at the amount and interval Stripe displays at checkout, including any eligible discount, until you cancel.":"You are choosing immediate paid activation. Stripe charges the amount displayed at checkout now, then the subscription renews automatically at the displayed interval, including any eligible discount, until you cancel.";
    const rules="Access is tied to your BridgePoint account/workspace. BridgePoint provides decision-support intelligence, not legal, insurance, engineering, or coverage determinations.";
    form.set("custom_text[submit][message]",short(`${disclosure} ${renewal} ${rules}`,500));

    const stripeRes=await fetch("https://api.stripe.com/v1/checkout/sessions",{method:"POST",headers:{Authorization:`Bearer ${stripe}`,"Content-Type":"application/x-www-form-urlencoded"},body:form});
    const session=await stripeRes.json();
    if(!stripeRes.ok) return json({complete:false,error:session.error?.message??"Stripe checkout failed"},400);
    return json({complete:true,url:session.url,session_id:session.id,trial_days_remaining:remaining,effective_trial_days:effectiveTrialDays,immediate_paid_activation:skipTrial,founding_discount_applied:Boolean(ctx.coupon_id),package_key:ctx.package_key,package_name:ctx.package_name,organization_id:ctx.organization_id??null,stripe_environment:ctx.stripe_environment,purchase_mode:skipTrial?"IMMEDIATE_PAID_ACTIVATION":ctx.purchase_mode??"IMMEDIATE",delivery_status:ctx.delivery_status??null,delivery_mode:ctx.delivery_mode??null,delivery_disclosure:ctx.delivery_disclosure??null,purchase_rules_version:ctx.purchase_rules_version??223,billing_contract_version:487,payment_method_collection:"always",automatic_renewal:true,return_path:"/app/",renewal_disclosure:effectiveTrialDays>0?"Stripe securely stores the payment method and automatically charges recurring invoices after the trial until cancellation; any eligible BridgePoint discount is applied before confirmation.":"Stripe charges the amount displayed at checkout immediately and securely stores the payment method for recurring renewal until cancellation; any eligible BridgePoint discount is applied before confirmation."});
  }catch(error){return json({complete:false,error:String(error)},500);}
});
