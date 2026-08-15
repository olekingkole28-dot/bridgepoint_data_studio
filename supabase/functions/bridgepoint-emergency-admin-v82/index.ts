import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, apikey, content-type",
};
const respond=(body:unknown,status=200)=>new Response(JSON.stringify(body),{
  status,headers:{...cors,"Content-Type":"application/json"},
});

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return respond({complete:false,error:"Method not allowed"},405);
  try{
    const authorization=req.headers.get("Authorization");
    if(!authorization)return respond({complete:false,error:"Authentication required"},401);
    const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
    const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
    const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const input=await req.json();
    const email=String(input.email??"").trim().toLowerCase();
    const confirmation=String(input.confirmation??"");
    const rpc=await fetch(supabaseUrl+"/rest/v1/rpc/bridgepoint_prepare_emergency_admin_v82",{
      method:"POST",headers:{apikey:anon,Authorization:authorization,"Content-Type":"application/json"},
      body:JSON.stringify({p_email:email,p_confirmation:confirmation}),
    });
    const result=await rpc.json().catch(()=>({complete:false,error:"Backup administrator invitation could not be saved"}));
    if(!rpc.ok)return respond({complete:false,error:result.message??result.error??"Invitation could not be saved"},rpc.status);
    const appUrl=Deno.env.get("BRIDGEPOINT_APP_URL")??"http://localhost:49981";
    const invite=await fetch(supabaseUrl+"/auth/v1/invite?redirect_to="+encodeURIComponent(appUrl),{
      method:"POST",headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},
      body:JSON.stringify({email,data:{
        display_name:"BridgePoint Backup Administrator",
        bridgepoint_emergency_invitation_id:result.emergency_invitation_id,
        bridgepoint_backup_admin:true,
      }}),
    });
    if(!invite.ok){
      const detail=await invite.json().catch(()=>({}));
      return respond({...result,email_sent:false,email_message:detail.msg??detail.message??"Invitation saved; email delivery is pending configuration."});
    }
    return respond({...result,email_sent:true});
  }catch(error){return respond({complete:false,error:String(error)},500);}
});
