import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
const H={"content-type":"application/json","cache-control":"no-store"};
Deno.serve(async(req)=>{
 try{
  const url=Deno.env.get("SUPABASE_URL")!, key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth=req.headers.get("authorization")||"";
  if(!auth) return new Response(JSON.stringify({complete:false,status:"unauthorized"}),{status:401,headers:H});
  const sb=createClient(url,key,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await sb.auth.getUser(auth.replace(/^Bearer\s+/i,""));
  if(!user) return new Response(JSON.stringify({complete:false,status:"unauthorized"}),{status:401,headers:H});
  const admin=createClient(url,key);
  const {data:ov}=await admin.from("platform_owner_overrides_v154").select("user_id").eq("user_id",user.id).maybeSingle();
  if(!ov) return new Response(JSON.stringify({complete:false,status:"forbidden",message:"Owner access required"}),{status:403,headers:H});
  const {data:cfg,error}=await admin.schema("growth").from("social_provider_config_v122").select("platform,client_id,client_secret_vault_id,redirect_uri,metadata").order("platform");
  if(error) throw error;
  const {data:tok}=await admin.schema("growth").from("social_provider_tokens_v122").select("platform,access_token_vault_id,refresh_token_vault_id,expires_at,provider_account_id,provider_username,scopes,metadata");
  const tm=new Map((tok||[]).map((x:any)=>[x.platform,x]));
  const providers=(cfg||[]).map((c:any)=>{const t:any=tm.get(c.platform); const configured=!!c.client_id&&!!c.client_secret_vault_id; const connected=!!t?.access_token_vault_id; return {platform:c.platform,configured,connected,refreshable:!!t?.refresh_token_vault_id,expires_at:t?.expires_at||null,account:t?.provider_username||t?.provider_account_id||null,scopes:t?.scopes||[],redirect_uri:c.redirect_uri,blocker:!configured?"OAUTH_CLIENT_CONFIGURATION_REQUIRED":!connected?"OWNER_AUTHORIZATION_REQUIRED":null};});
  return new Response(JSON.stringify({complete:true,status:"ready",mode:"OWNER_OAUTH_AUTOMATION",password_storage:false,providers}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,status:"error",message:String(e)}),{status:500,headers:H});}
});