import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const U=Deno.env.get('SUPABASE_URL')!;
const A=Deno.env.get('SUPABASE_ANON_KEY')!;
const S=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PRODUCTION_URL='https://bridgepointintelligence.online';
const cors={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});

function safeRedirect(raw:unknown){
  try{
    const value=String(raw||'').trim();
    if(!value)return PRODUCTION_URL;
    const u=new URL(value);
    if(u.protocol==='https:' && (u.hostname==='bridgepointintelligence.online'||u.hostname==='www.bridgepointintelligence.online'))return PRODUCTION_URL;
  }catch{}
  return PRODUCTION_URL;
}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS') return new Response('ok',{status:200,headers:cors});
  if(req.method!=='POST') return json({complete:false,error:'Method not allowed'},405);
  try{
    const auth=req.headers.get('authorization')||'';
    if(!auth) return json({complete:false,error:'Authentication required'},401);
    const caller=createClient(U,A,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
    const admin=createClient(U,S,{auth:{persistSession:false}});
    const body=await req.json().catch(()=>({}));
    const email=String(body.email||'').trim().toLowerCase();
    const displayName=String(body.display_name||'').trim()||null;
    const redirectUrl=safeRedirect(body.redirect_url);
    if(!email||!email.includes('@')) return json({complete:false,error:'Enter a valid email address.'},400);

    const prep=await caller.rpc('bridgepoint_owner_prepare_full_access_invite_v153',{p_email:email,p_display_name:displayName});
    if(prep.error)throw prep.error;
    const state=prep.data||{};
    if(state.status==='ACCEPTED')return json({...state,invite_email_sent:false,redirect_url:PRODUCTION_URL,message:'This account already has accepted full access. If this is their first login, use First-time owner / Forgot password on the BridgePoint sign-in screen to choose a password.'});

    const inviteId=state.invite_id;
    const result=await admin.auth.admin.inviteUserByEmail(email,{redirectTo:redirectUrl,data:{bridgepoint_full_owner:true,display_name:displayName}});
    if(result.error){
      await caller.rpc('bridgepoint_owner_mark_invite_state_v153',{p_invite_id:inviteId,p_status:'FAILED',p_error:result.error.message});
      throw result.error;
    }
    await caller.rpc('bridgepoint_owner_mark_invite_state_v153',{p_invite_id:inviteId,p_status:'INVITED',p_error:null});
    return json({complete:true,invite_id:inviteId,status:'INVITED',existing_account:false,invite_email_sent:true,email,redirect_url:PRODUCTION_URL,message:'Full-access invitation sent. The recipient can accept the invite, then choose a password from the BridgePoint sign-in screen if needed.'});
  }catch(e){return json({complete:false,error:String((e as any)?.message||e)},400);}
});