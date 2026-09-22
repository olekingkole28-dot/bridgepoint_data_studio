import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const H={"content-type":"application/json","cache-control":"no-store"};
Deno.serve(async(req)=>{
 try{
  const url=Deno.env.get("SUPABASE_URL")!, key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, auth=req.headers.get("authorization")||"";
  if(!auth) return new Response(JSON.stringify({complete:false,status:"unauthorized"}),{status:401,headers:H});
  const admin=createClient(url,key), sb=createClient(url,key,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await sb.auth.getUser(auth.replace(/^Bearer\s+/i,""));
  if(!user) return new Response(JSON.stringify({complete:false,status:"unauthorized"}),{status:401,headers:H});
  const {data:ov}=await admin.from("platform_owner_overrides_v154").select("user_id").eq("user_id",user.id).maybeSingle();
  if(!ov) return new Response(JSON.stringify({complete:false,status:"forbidden",message:"Owner access required"}),{status:403,headers:H});
  const {data:cfg}=await admin.schema("growth").from("social_provider_config_v122").select("platform,client_id,client_secret_vault_id");
  const {data:tok}=await admin.schema("growth").from("social_provider_tokens_v122").select("platform,access_token_vault_id,refresh_token_vault_id,expires_at,provider_account_id,provider_username,scopes");
  const cm=new Map((cfg||[]).map((x:any)=>[x.platform,x]));
  const platforms=["FACEBOOK","INSTAGRAM","LINKEDIN","TIKTOK","X","YOUTUBE_SHORTS"];
  const readiness=platforms.map(p=>{const c:any=cm.get(p),t:any=(tok||[]).find((x:any)=>x.platform===p); return {platform:p,configured:!!c?.client_id&&!!c?.client_secret_vault_id,connected:!!t?.access_token_vault_id,refreshable:!!t?.refresh_token_vault_id,account:t?.provider_username||t?.provider_account_id||null,blocker:(!c?.client_id||!c?.client_secret_vault_id)?"OAUTH_CLIENT_CONFIGURATION_REQUIRED":!t?.access_token_vault_id?"OWNER_AUTHORIZATION_REQUIRED":null};});
  const ready=readiness.filter(x=>x.configured&&x.connected);
  if(!ready.length) return new Response(JSON.stringify({complete:false,status:"blocked",mode:"AUTOMATIC_SOCIAL",message:"No provider is authorized for automatic publishing yet. Content staging remains preserved; configure provider OAuth then complete the one-time owner authorization.",readiness}),{status:409,headers:H});
  return new Response(JSON.stringify({complete:true,status:"ready",mode:"AUTOMATIC_SOCIAL",password_storage:false,ready_platforms:ready.map(x=>x.platform),readiness,message:"Automatic publishing is restored at the secure readiness gate; provider-specific dispatch remains gated by valid OAuth scopes/account eligibility."}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,status:"error",message:String(e)}),{status:500,headers:H});}
});