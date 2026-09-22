import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ORIGINS=new Set(["https://bridgepointintelligence.online","https://www.bridgepointintelligence.online"]);
const LOOKUP="bridgepoint_ct_territory_report_v674";
const AMOUNT=4900;
const API_VERSION="2026-07-29.dahlia";
const cors=(origin:string|null)=>({"Access-Control-Allow-Origin":origin&&ORIGINS.has(origin)?origin:"https://bridgepointintelligence.online","Access-Control-Allow-Headers":"content-type, apikey","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin","Cache-Control":"no-store"});
const reply=(body:unknown,status=200,origin:string|null=null)=>new Response(JSON.stringify(body),{status,headers:{...cors(origin),"Content-Type":"application/json; charset=utf-8"}});
const clean=(v:unknown,n:number)=>String(v??"").replace(/\s+/g," ").trim().slice(0,n);
const email=(v:unknown)=>{const x=clean(v,254).toLowerCase();return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(x)?x:""};
async function rpc(name:string,payload:Record<string,unknown>){
  const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res=await fetch(`${url}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify(payload)});
  const text=await res.text();let data:unknown;try{data=JSON.parse(text)}catch{data=text};return {ok:res.ok,data,text};
}
async function stripe(path:string,init:RequestInit={}){
  const key=Deno.env.get("STRIPE_SECRET_KEY")??"";
  if(!key.startsWith("sk_live_")) throw new Error("LIVE_STRIPE_NOT_READY");
  const headers=new Headers(init.headers);headers.set("Authorization",`Bearer ${key}`);headers.set("Stripe-Version",API_VERSION);
  if(init.body) headers.set("Content-Type","application/x-www-form-urlencoded");
  const res=await fetch(`https://api.stripe.com/v1${path}`,{...init,headers});
  const data=await res.json().catch(()=>({}));if(!res.ok) throw new Error(data?.error?.message??`STRIPE_${res.status}`);return data;
}
async function ensurePrice(){
  const qs=new URLSearchParams();qs.append("lookup_keys[]",LOOKUP);qs.set("active","true");qs.set("limit","1");
  const found=await stripe(`/prices?${qs.toString()}`);
  if(found?.data?.[0]?.id) return found.data[0].id as string;
  const productForm=new URLSearchParams();productForm.set("name","BridgePoint Connecticut Territory Intelligence Report");productForm.set("description","One-time BridgePoint territory intelligence report with up to 25 ranked Connecticut property opportunities and evidence context.");productForm.set("metadata[bridgepoint_product]","TERRITORY_REPORT");productForm.set("metadata[bridgepoint_version]","674");
  const product=await stripe("/products",{method:"POST",headers:{"Idempotency-Key":"[REDACTED_LONG_LITERAL]"},body:productForm});
  const priceForm=new URLSearchParams();priceForm.set("product",product.id);priceForm.set("currency","usd");priceForm.set("unit_amount",String(AMOUNT));priceForm.set("lookup_key",LOOKUP);priceForm.set("nickname","CT Territory Intelligence Report — one time");priceForm.set("metadata[bridgepoint_product]","TERRITORY_REPORT");priceForm.set("metadata[bridgepoint_version]","674");
  try{const price=await stripe("/prices",{method:"POST",headers:{"Idempotency-Key":"bridgepoint-territory-report-price-v674"},body:priceForm});return price.id as string}catch{
    const retry=await stripe(`/prices?${qs.toString()}`);if(retry?.data?.[0]?.id) return retry.data[0].id as string;throw new Error("REPORT_PRICE_UNAVAILABLE");
  }
}
async function record(session:any,status:string){
  const m=session?.metadata??{};const customerEmail=session?.customer_details?.email??session?.customer_email??null;
  return rpc("[REDACTED_LONG_LITERAL]",{
    p_stripe_checkout_session_id:String(session?.id??""),p_status:status,p_state_code:String(m.bridgepoint_state_code??"CT"),p_territory:String(m.bridgepoint_territory??"Connecticut"),p_vertical:String(m.bridgepoint_vertical??"ROOFING"),p_visitor_id:m.bridgepoint_visitor_id??null,p_session_id:m.bridgepoint_session_id??null,p_stripe_payment_intent_id:typeof session?.payment_intent==="string"?session.payment_intent:(session?.payment_intent?.id??null),p_stripe_customer_id:typeof session?.customer==="string"?session.customer:(session?.customer?.id??null),p_customer_email:customerEmail,p_amount_total:session?.amount_total??null,p_currency:session?.currency??null,p_metadata:{checkout_status:session?.status??null,payment_status:session?.payment_status??null,source:"stripe_checkout",version:674}
  });
}
Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin");if(req.method==="OPTIONS")return new Response("ok",{headers:cors(origin)});if(req.method!=="POST")return reply({complete:false,error:"METHOD_NOT_ALLOWED"},405,origin);if(origin&&!ORIGINS.has(origin))return reply({complete:false,error:"ORIGIN_NOT_ALLOWED"},403,origin);
  try{
    const body=await req.json().catch(()=>({}));const action=clean(body?.action??"checkout",20).toLowerCase();
    if(action==="status"){
      const sid=clean(body?.session_id,160);if(!/^cs_(live|test)_/.test(sid))return reply({complete:false,error:"INVALID_SESSION"},400,origin);
      const session=await stripe(`/checkout/sessions/${encodeURIComponent(sid)}?expand[]=payment_intent`);
      if(session?.metadata?.bridgepoint_purchase_type!=="TERRITORY_REPORT") return reply({complete:false,error:"NOT_A_TERRITORY_REPORT"},400,origin);
      const status=session.payment_status==="paid"?"PAID":session.status==="expired"?"EXPIRED":"PENDING";await record(session,status);
      if(status!=="PAID") return reply({complete:true,status,payment_status:session.payment_status??null},200,origin);
      const report=await rpc("bridgepoint_paid_territory_report_v674",{p_state_code:session.metadata.bridgepoint_state_code,p_territory:session.metadata.bridgepoint_territory,p_vertical:session.metadata.bridgepoint_vertical});
      if(!report.ok) return reply({complete:false,error:"REPORT_BUILD_FAILED"},502,origin);
      return reply({complete:true,status:"PAID",amount_total:session.amount_total,currency:session.currency,report:report.data},200,origin);
    }
    const state=clean(body?.state_code??"CT",2).toUpperCase(),territory=clean(body?.territory,120),vertical=clean(body?.vertical??"ROOFING",40).toUpperCase();
    if(state!=="CT") return reply({complete:false,error:"REPORT_CURRENTLY_CT_ONLY"},400,origin);if(territory.length<2)return reply({complete:false,error:"TERRITORY_REQUIRED"},400,origin);
    const visitor=clean(body?.visitor_id,128),sessionId=clean(body?.session_id,128),referral=clean(body?.referral_code,64),customerEmail=email(body?.email);
    const priceId=await ensurePrice();const appUrl="https://bridgepointintelligence.online";const form=new URLSearchParams();
    form.set("mode","payment");form.set("integration_identifier","bridgepoint_report_qzmtxwca");form.set("line_items[0][price]",priceId);form.set("line_items[0][quantity]","1");form.set("success_url",`${appUrl}/sample/?report=paid&session_id={CHECKOUT_SESSION_ID}`);form.set("cancel_url",`${appUrl}/sample/?report=cancelled`);if(customerEmail)form.set("customer_email",customerEmail);
    const metadata:Record<string,string>={bridgepoint_purchase_type:"TERRITORY_REPORT",bridgepoint_state_code:state,bridgepoint_territory:territory,bridgepoint_vertical:vertical,bridgepoint_version:"674"};if(visitor.length>=8)metadata.bridgepoint_visitor_id=visitor;if(sessionId.length>=8)metadata.bridgepoint_session_id=sessionId;if(referral)metadata.bridgepoint_referral_code=referral;
    for(const [k,v] of Object.entries(metadata)){form.set(`metadata[${k}]`,v);form.set(`payment_intent_data[metadata][${k}]`,v)}
    form.set("custom_text[submit][message]","One-time $49 BridgePoint Connecticut Territory Intelligence Report. This purchase does not start a subscription. Intelligence is decision support and should be verified against source records and field conditions before action.");
    const session=await stripe("/checkout/sessions",{method:"POST",body:form});await record(session,"PENDING");
    if(visitor.length>=8&&sessionId.length>=8){void rpc("track_acquisition_event_v400",{p_event_type:"CHECKOUT_START",p_visitor_id:visitor,p_session_id:sessionId,p_page_path:"/sample/",p_platform:"WEB",p_referrer_host:null,p_utm_source:null,p_utm_medium:null,p_utm_campaign:null,p_utm_content:"territory_report",p_referral_code:referral||null,p_auth_error_code:null,p_metadata:{capture_version:674,surface:"territory_report_checkout",state_code:state,vertical,purchase_type:"ONE_TIME_REPORT",amount_usd:49}})}
    return reply({complete:true,url:session.url,session_id:session.id,price_usd:49,purchase_type:"ONE_TIME_REPORT",subscription:false},200,origin);
  }catch(e){const message=String(e);return reply({complete:false,error:message.includes("LIVE_STRIPE_NOT_READY")?"LIVE_BILLING_NOT_READY":"REPORT_CHECKOUT_UNAVAILABLE",detail:message.slice(0,180)},500,origin)}
});
