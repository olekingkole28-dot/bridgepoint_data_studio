import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"POST, OPTIONS",
  "Access-Control-Max-Age":"86400",
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});

async function rpc(url:string,key:string,bearer:string,name:string,payload:Record<string,unknown>={}){
  const response=await fetch(`${url}/rest/v1/rpc/${name}`,{method:"POST",headers:{apikey:key,Authorization:bearer,"Content-Type":"application/json"},body:JSON.stringify(payload)});
  const text=await response.text();
  if(!response.ok)throw new Error(`${name}: ${text}`);
  try{return JSON.parse(text);}catch{return text;}
}
async function resend(key:string,path:string,method="GET",body?:unknown){
  const response=await fetch(`https://api.resend.com${path}`,{method,headers:{Authorization:`Bearer ${key}`,"Content-Type":"application/json","User-Agent":"BridgePoint-Intelligence/225"},body:body===undefined?undefined:JSON.stringify(body)});
  const text=await response.text();
  let data:any={};try{data=text?JSON.parse(text):{};}catch{data={raw:text};}
  if(!response.ok)throw new Error(`Resend ${response.status}: ${data?.message||data?.name||text||"request failed"}`);
  return data;
}
function normalizeDomain(data:any){
  if(!data||typeof data!=="object")return {id:null,status:"unknown",records:[]};
  return {id:data.id??null,status:String(data.status??"unknown"),records:Array.isArray(data.records)?data.records:[]};
}
async function owner(url:string,anon:string,auth:string){return await rpc(url,anon,auth,"bridgepoint_mail_provider_status_v225",{});}
async function currentUser(url:string,anon:string,auth:string){
  const response=await fetch(`${url}/auth/v1/user`,{headers:{apikey:anon,Authorization:auth}});
  const text=await response.text();if(!response.ok)throw new Error(`User session: ${text}`);return JSON.parse(text);
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
  const url=Deno.env.get("SUPABASE_URL")!;
  const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth=req.headers.get("Authorization")??"";
  try{
    if(req.method!=="POST")return json({complete:false,error:"Method not allowed"},405);
    if(!auth.startsWith("Bearer "))return json({complete:false,error:"Authentication required"},401);
    await owner(url,anon,auth);
    const input=await req.json().catch(()=>({})) as Record<string,unknown>;
    const action=String(input.action||"status").toLowerCase();
    const domain="bridgepointintelligence.online";

    if(action==="configure"){
      const apiKey=String(input.api_key||"").trim();
      if(!/^re_[A-Za-z0-9_-]{10,}$/.test(apiKey))return json({complete:false,error:"Paste a valid Resend API key beginning with re_. The key is sent only to BridgePoint's server and is never returned."},400);
      let list:any;
      try{list=await resend(apiKey,"/domains");}catch(error){return json({complete:false,error:`The Resend key could not manage domains. Create a Full access Resend API key for the one-time BridgePoint setup. ${String(error)}`},400);}
      let found=(Array.isArray(list?.data)?list.data:[]).find((d:any)=>String(d?.name||"").toLowerCase()===domain);
      if(!found)found=await resend(apiKey,"/domains","POST",{name:domain,region:"us-east-1",tls:"enforced",capabilities:{sending:"enabled",receiving:"disabled"}});
      let details:any=found;
      if(found?.id){try{details=await resend(apiKey,`/domains/${found.id}`);}catch{details=found;}}
      const normalized=normalizeDomain(details);
      await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_store_resend_key_v225",{p_key:apiKey});
      const verified=normalized.status.toLowerCase()==="verified";
      await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_update_provider_v225",{p_patch:{domain_id:normalized.id,domain_status:normalized.status,dns_records:normalized.records,enabled:verified,checked:true,verified,last_error:""}});
      return json({complete:true,mail_contract_version:225,provider:"RESEND",configured:true,domain,domain_id:normalized.id,domain_status:normalized.status,dns_records:normalized.records,enabled:verified,ready:verified,next_step:verified?"Transactional email is ready. Send a test email to confirm end-to-end delivery.":"Add the returned DNS records at your domain DNS provider, then press Verify domain."});
    }

    const apiKey=await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_get_resend_key_v225",{}) as string|null;
    if(!apiKey)return json({complete:true,mail_contract_version:225,provider:"RESEND",configured:false,ready:false,domain,domain_status:"NOT_CONFIGURED",from_email:"notifications@bridgepointintelligence.online",reply_to_email:"bridgepointintelligence@gmail.com",next_step:"Create a Resend account and Full access API key, then connect it here."});
    let cfg=await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_provider_v225",{}) as Record<string,unknown>;
    let domainId=String(cfg?.domain_id||"");
    if(!domainId){
      const list=await resend(apiKey,"/domains");
      const found=(Array.isArray(list?.data)?list.data:[]).find((d:any)=>String(d?.name||"").toLowerCase()===domain);
      if(found?.id){domainId=String(found.id);await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_update_provider_v225",{p_patch:{domain_id:domainId,domain_status:String(found.status||"unknown"),checked:true,last_error:""}});}
    }
    if(action==="verify"){
      if(!domainId)return json({complete:false,error:"Resend domain has not been created yet. Connect Resend first."},409);
      await resend(apiKey,`/domains/${domainId}/verify`,"POST",{});
    }
    if(action==="status"||action==="verify"||action==="send_test"){
      if(!domainId)return json({complete:true,mail_contract_version:225,provider:"RESEND",configured:true,domain,domain_status:"NOT_CREATED",ready:false,from_email:cfg.from_email,reply_to_email:cfg.reply_to_email,next_step:"Reconnect Resend so BridgePoint can create the sending domain."});
      const details=await resend(apiKey,`/domains/${domainId}`);
      const normalized=normalizeDomain(details);
      const verified=normalized.status.toLowerCase()==="verified";
      await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_update_provider_v225",{p_patch:{domain_id:normalized.id,domain_status:normalized.status,dns_records:normalized.records,enabled:verified,checked:true,verified,last_error:""}});
      cfg=await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_provider_v225",{}) as Record<string,unknown>;
      if(action==="send_test"){
        if(!verified)return json({complete:false,error:"The Resend domain is not verified yet. Add the DNS records, verify the domain, then send the test."},409);
        const user=await currentUser(url,anon,auth);
        const recipient=String(user?.email||"").trim().toLowerCase();
        if(!recipient)return json({complete:false,error:"Your signed-in BridgePoint account has no email address."},409);
        const send=await resend(apiKey,"/emails","POST",{
          from:`${cfg.from_name||"BridgePoint Intelligence"} <${cfg.from_email||"notifications@bridgepointintelligence.online"}>`,
          to:[recipient],reply_to:String(cfg.reply_to_email||"bridgepointintelligence@gmail.com"),subject:"BridgePoint transactional email is live",
          html:`<div style="font-family:Arial,sans-serif;max-width:620px;margin:auto;padding:24px"><h2>BridgePoint transactional email is live.</h2><p>This confirms the verified Resend domain, BridgePoint server connection, sender identity, and delivery API are working end to end.</p><p>Purchase welcome emails will be sent automatically from <strong>${String(cfg.from_email||"notifications@bridgepointintelligence.online")}</strong> and replies will go to <strong>${String(cfg.reply_to_email||"bridgepointintelligence@gmail.com")}</strong>.</p><p><a href="https://bridgepointintelligence.online">Open BridgePoint Intelligence</a></p></div>`,
          text:"BridgePoint transactional email is live. Purchase welcome emails will be sent automatically. Open BridgePoint: https://bridgepointintelligence.online",
          tags:[{name:"template",value:"mail_setup_test"},{name:"contract",value:"225"}]
        });
        await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_update_provider_v225",{p_patch:{test_sent:true,test_recipient:recipient,last_error:""}});
        return json({complete:true,mail_contract_version:225,provider:"RESEND",ready:true,domain_status:normalized.status,test_sent:true,test_recipient:recipient,provider_message_id:send?.id??null});
      }
      return json({complete:true,mail_contract_version:225,provider:"RESEND",configured:true,enabled:verified,ready:verified,domain,domain_id:normalized.id,domain_status:normalized.status,dns_records:normalized.records,from_email:cfg.from_email,reply_to_email:cfg.reply_to_email,last_test_email_at:cfg.last_test_email_at,last_test_recipient:cfg.last_test_recipient,next_step:verified?"Domain verified. Send a test email to confirm end-to-end delivery.":"Add every required Resend DNS record at your DNS provider, wait for DNS propagation, then press Verify domain."});
    }
    return json({complete:false,error:"Unknown action"},400);
  }catch(error){
    try{await rpc(url,service,`Bearer ${service}`,"bridgepoint_mail_internal_update_provider_v225",{p_patch:{last_error:String(error),checked:true}});}catch{}
    return json({complete:false,mail_contract_version:225,error:String(error)},500);
  }
});