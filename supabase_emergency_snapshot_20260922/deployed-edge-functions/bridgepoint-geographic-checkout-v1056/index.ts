import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="POST") return json({complete:false,error:"Method not allowed"},405);
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
    const input=await req.json().catch(()=>({}));
    const itemType=String(input.item_type??"").trim().toUpperCase();
    const itemKey=String(input.item_key??"").trim();
    const interval=String(input.interval??"month").trim().toLowerCase();
    if(!["STATE","BUNDLE"].includes(itemType)) return json({complete:false,error:"Choose a state or bundle"},400);
    if(!itemKey) return json({complete:false,error:"Missing geographic item"},400);
    if(!["month","year"].includes(interval)) return json({complete:false,error:"Invalid billing interval"},400);

    const ctxRes=await fetch(`${supabaseUrl}/rest/v1/rpc/bridgepoint_geographic_checkout_context_v77`,{
      method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},
      body:JSON.stringify({p_user_id:user.id,p_item_type:itemType,p_item_key:itemKey,p_interval:interval})
    });
    if(!ctxRes.ok){const text=await ctxRes.text();return json({complete:false,error:text||"Geographic coverage is not ready for purchase"},400);}
    const ctx=await ctxRes.json();
    if(!ctx?.stripe_price_id) return json({complete:false,error:"This geographic coverage is not ready for purchase"},400);

    const appBase=(Deno.env.get("BRIDGEPOINT_APP_URL")??"https://bridgepointintelligence.online").replace(/\/+$/,'');
    const form=new URLSearchParams();
    form.set("mode","subscription");
    form.set("integration_identifier","bridgepoint_geographic_checkout_v1056");
    form.set("line_items[0][price]",ctx.stripe_price_id);
    form.set("line_items[0][quantity]","1");
    form.set("success_url",`${appBase}/app/?geography_checkout=success&session_id={CHECKOUT_SESSION_ID}`);
    form.set("cancel_url",`${appBase}/app/?geography_checkout=cancelled`);
    form.set("client_reference_id",user.id);
    if(ctx.stripe_customer_id) form.set("customer",ctx.stripe_customer_id); else form.set("customer_email",ctx.email);
    for(const [k,v] of Object.entries({
      bridgepoint_user_id:user.id,
      bridgepoint_purchase_type:"geography",
      bridgepoint_geographic_item_type:itemType,
      bridgepoint_geographic_item_key:ctx.item_key
    })){
      form.set(`metadata[${k}]`,String(v));
      form.set(`subscription_data[metadata][${k}]`,String(v));
    }

    const stripeRes=await fetch("https://api.stripe.com/v1/checkout/sessions",{
      method:"POST",headers:{Authorization:`Bearer ${stripe}`,"Content-Type":"application/x-www-form-urlencoded"},body:form
    });
    const session=await stripeRes.json();
    if(!stripeRes.ok) return json({complete:false,error:session.error?.message??"Stripe checkout failed"},400);
    return json({complete:true,url:session.url,session_id:session.id,purchase_type:"geography",item_type:itemType,item_key:ctx.item_key,interval});
  }catch(error){return json({complete:false,error:String(error)},500);}
});
