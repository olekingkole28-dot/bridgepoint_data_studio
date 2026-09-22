import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
const esc=(value:unknown)=>String(value??"").replace(/[&<>"']/g,(c)=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[c]??c));

async function rpc(url:string,service:string,name:string,payload:Record<string,unknown>={}){
  const response=await fetch(`${url}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify(payload)});
  const text=await response.text();
  if(!response.ok) throw new Error(`${name}: ${text}`);
  try{return JSON.parse(text);}catch{return text;}
}

function money(cents:unknown,currency:unknown){
  const n=Number(cents);
  if(!Number.isFinite(n)||n<=0)return "";
  try{return new Intl.NumberFormat("en-US",{style:"currency",currency:String(currency||"usd").toUpperCase()}).format(n/100);}catch{return `$${(n/100).toFixed(2)}`;}
}

function renderPurchase(payload:Record<string,unknown>,subject:string){
  const packageName=esc(payload.package_name||payload.package_key||"BridgePoint Intelligence");
  const interval=esc(String(payload.billing_interval||"").replaceAll("_"," "));
  const amount=esc(money(payload.amount_total_cents,payload.currency));
  const access=esc(String(payload.purchase_mode||"IMMEDIATE").replaceAll("_"," "));
  const delivery=esc(String(payload.delivery_status||"READY").replaceAll("_"," "));
  const disclosure=esc(payload.delivery_disclosure||"");
  const appUrl=String(payload.app_url||"https://bridgepointintelligence.online");
  const support=esc(payload.support_email||"bridgepointintelligence@gmail.com");
  const thankYou=esc(payload.thank_you||"Thank you for choosing BridgePoint Intelligence.");
  const whatYouGot=esc(payload.what_you_got||`Your BridgePoint account now includes ${packageName}.`);
  const rules=Array.isArray(payload.rules)?payload.rules.map((r)=>`<li style="margin:0 0 8px 0;line-height:1.5;color:#cbd5e1">${esc(r)}</li>`).join(""):"";
  const summaryRows=[
    ["Package",packageName],
    interval?["Billing",interval]:null,
    amount?["Purchase total",amount]:null,
    ["Access",access],
    ["Delivery",delivery],
  ].filter(Boolean).map((row:any)=>`<tr><td style="padding:7px 12px 7px 0;color:#94a3b8;font-size:13px">${row[0]}</td><td style="padding:7px 0;color:#f8fafc;font-size:13px;font-weight:700">${row[1]}</td></tr>`).join("");
  const html=`<!doctype html><html><body style="margin:0;background:#07111f;font-family:Arial,Helvetica,sans-serif;color:#f8fafc"><div style="max-width:640px;margin:0 auto;padding:28px 18px"><div style="padding:24px;border-radius:18px;background:#0d1b2a;border:1px solid #1e3a5f"><div style="font-size:12px;letter-spacing:1.7px;font-weight:800;color:#67e8f9">BRIDGEPOINT INTELLIGENCE</div><h1 style="margin:10px 0 10px;font-size:25px;line-height:1.2;color:#ffffff">Thank you for your purchase</h1><p style="margin:0 0 18px;color:#cbd5e1;line-height:1.6">${thankYou}</p><div style="padding:16px;border-radius:12px;background:#0a1522;border:1px solid #1f334a"><table role="presentation" style="width:100%;border-collapse:collapse">${summaryRows}</table></div><p style="margin:18px 0 8px;color:#e2e8f0;line-height:1.6">${whatYouGot}</p>${disclosure?`<p style="margin:0 0 18px;color:#94a3b8;line-height:1.55">${disclosure}</p>`:""}<div style="margin:20px 0"><a href="${esc(appUrl)}" style="display:inline-block;padding:12px 18px;border-radius:10px;background:#22d3ee;color:#07111f;text-decoration:none;font-weight:800">Open BridgePoint</a></div>${rules?`<div style="margin-top:20px"><div style="font-weight:800;margin-bottom:9px">Account & use reminders</div><ul style="padding-left:20px;margin:0">${rules}</ul></div>`:""}<div style="margin-top:24px;padding-top:16px;border-top:1px solid #1f334a;color:#94a3b8;font-size:12px;line-height:1.6">Questions? Reply to this email or contact ${support}.<br>BridgePoint Intelligence • Property intelligence for better-timed decisions.</div></div></div></body></html>`;
  const text=["BRIDGEPOINT INTELLIGENCE","","Thank you for your purchase",String(payload.thank_you||"Thank you for choosing BridgePoint Intelligence."),"",`Package: ${String(payload.package_name||payload.package_key||"BridgePoint Intelligence")}`,interval?`Billing: ${String(payload.billing_interval).replaceAll("_"," ")}`:"",amount?`Purchase total: ${money(payload.amount_total_cents,payload.currency)}`:"",`Access: ${String(payload.purchase_mode||"IMMEDIATE").replaceAll("_"," ")}`,`Delivery: ${String(payload.delivery_status||"READY").replaceAll("_"," ")}`,"",String(payload.what_you_got||"Your BridgePoint account entitlement is active."),String(payload.delivery_disclosure||""),"",`Open BridgePoint: ${appUrl}`,"",`Support: ${String(payload.support_email||"bridgepointintelligence@gmail.com")}`].filter(Boolean).join("\n");
  return {subject,html,text};
}

Deno.serve(async(req:Request)=>{
  try{
    if(req.method!=="POST")return json({complete:false,error:"Method not allowed"},405);
    const url=Deno.env.get("SUPABASE_URL")!;
    const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const token=req.headers.get("x-bridgepoint-mail-token")??"";
    if(!token||await rpc(url,service,"bridgepoint_mail_internal_validate_scheduler_token_v225",{p_token:token})!==true)return json({complete:false,error:"Unauthorized"},401);

    const provider=await rpc(url,service,"bridgepoint_mail_internal_provider_v225") as Record<string,unknown>;
    const key=await rpc(url,service,"bridgepoint_mail_internal_get_resend_key_v225") as string|null;
    if(!provider||provider.enabled!==true||String(provider.domain_status||"").toLowerCase()!=="verified"||!key){
      return json({complete:true,mail_contract_version:225,status:"NOT_READY",provider:"RESEND",configured:Boolean(key),enabled:provider?.enabled===true,domain_status:provider?.domain_status??"NOT_CONFIGURED"});
    }

    const rows=await rpc(url,service,"bridgepoint_mail_internal_claim_v225",{p_limit:25}) as Array<Record<string,unknown>>;
    const results:Array<Record<string,unknown>>=[];
    for(const row of rows){
      try{
        const payload=(row.payload&&typeof row.payload==="object"?row.payload:{}) as Record<string,unknown>;
        const rendered=renderPurchase(payload,String(row.subject||"Thank you for choosing BridgePoint"));
        const response=await fetch("https://api.resend.com/emails",{
          method:"POST",
          headers:{"Authorization":`Bearer ${key}`,"Content-Type":"application/json","User-Agent":"BridgePoint-Intelligence/225","Idempotency-Key":`bridgepoint-${row.email_outbox_id}`},
          body:JSON.stringify({
            from:`${provider.from_name||"BridgePoint Intelligence"} <${provider.from_email||"notifications@bridgepointintelligence.online"}>`,
            to:[String(row.recipient_email)],
            reply_to:String(provider.reply_to_email||"bridgepointintelligence@gmail.com"),
            subject:rendered.subject,
            html:rendered.html,
            text:rendered.text,
            tags:[{name:"template",value:String(row.template_key||"bridgepoint").replace(/[^A-Za-z0-9_-]/g,"_").slice(0,256)},{name:"contract",value:"225"}]
          })
        });
        const responseText=await response.text();
        let data:any={};try{data=JSON.parse(responseText);}catch{data={raw:responseText};}
        if(!response.ok)throw new Error(`Resend ${response.status}: ${data?.message||responseText}`);
        await rpc(url,service,"bridgepoint_mail_internal_mark_v225",{p_email_outbox_id:row.email_outbox_id,p_success:true,p_provider_message_id:String(data?.id||""),p_error:null});
        results.push({email_outbox_id:row.email_outbox_id,status:"SENT",provider_message_id:data?.id??null});
      }catch(error){
        await rpc(url,service,"bridgepoint_mail_internal_mark_v225",{p_email_outbox_id:row.email_outbox_id,p_success:false,p_provider_message_id:null,p_error:String(error)});
        results.push({email_outbox_id:row.email_outbox_id,status:"RETRY_OR_FAILED",error:String(error)});
      }
    }
    return json({complete:true,mail_contract_version:225,status:"READY",processed:rows.length,results});
  }catch(error){return json({complete:false,mail_contract_version:225,error:String(error)},500);}
});