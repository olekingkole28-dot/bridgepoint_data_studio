import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const U=Deno.env.get("SUPABASE_URL")!;
const A=Deno.env.get("SUPABASE_ANON_KEY")!;
const S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CENSUS_STATES="https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/32/query";
const CORS={
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"authorization, apikey, content-type",
  "access-control-allow-methods":"GET, OPTIONS",
};
const JSONH={...CORS,"content-type":"application/json","cache-control":"no-store"};

function hexToBytes(v:string){
  const s=String(v||"").replace(/^\\x/,"");
  const out=new Uint8Array(Math.floor(s.length/2));
  for(let i=0;i<out.length;i++) out[i]=parseInt(s.slice(i*2,i*2+2),16);
  return out;
}

async function ownerAllowed(req:Request,_service:any){
  const auth=req.headers.get("authorization")||"";
  if(!auth.toLowerCase().startsWith("bearer ")) return false;
  const token=auth.slice(7).trim();
  if(!token) return false;
  const validator=createClient(U,A,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:userData,error:userErr}=await validator.auth.getUser(token);
  const user=userData?.user;
  if(userErr||!user?.id) return false;
  const app=user.app_metadata||{};
  return app.bridgepoint_owner===true && (app.bridgepoint_role==="owner"||app.bridgepoint_role==="co_owner");
}

async function stateStatuses(service:any){
  const {data:allowed,error:allowErr}=await service.schema("automation").from("parcel_boundary_rights_allowlist_v1831")
    .select("candidate_id").eq("active",true);
  if(allowErr) throw allowErr;
  const ids=(allowed||[]).map((r:any)=>String(r.candidate_id||"")).filter(Boolean);
  if(!ids.length) return [];
  const [{data:cands,error:candErr},{data:valid,error:validErr}]=await Promise.all([
    service.schema("automation").from("geographic_source_candidates_v86")
      .select("candidate_id,state_code,decision_status,metadata").in("candidate_id",ids),
    service.schema("automation").from("source_compliance_validation_v720")
      .select("candidate_id,activation_status,rights_status,authority_status,provenance_status,local_law_status").in("candidate_id",ids)
  ]);
  if(candErr) throw candErr;
  if(validErr) throw validErr;
  const validation=new Map<string,any>((valid||[]).map((r:any)=>[String(r.candidate_id),r]));
  const states=new Map<string,{state_code:string,active_approved:number,public_approved:number}>();
  for(const c of cands||[]){
    const code=String(c.state_code||"").toUpperCase().trim();
    if(!code) continue;
    const v=validation.get(String(c.candidate_id));
    const approved=c.decision_status==="ACCEPTED"&&v?.activation_status==="APPROVED"&&v?.rights_status==="PASS"&&v?.authority_status==="PASS"&&v?.provenance_status==="PASS"&&v?.local_law_status==="PASS";
    if(!approved) continue;
    const row=states.get(code)||{state_code:code,active_approved:0,public_approved:0};
    row.active_approved++;
    const m=c.metadata||{};
    if(m.raw_redistribution_allowed===true||m.public_boundary_display_allowed===true) row.public_approved++;
    states.set(code,row);
  }
  return [...states.values()].map(r=>({
    ...r,
    public_enabled:r.public_approved>0,
    reason_code:r.public_approved>0
      ?"PUBLIC_DISPLAY_ENABLED"
      :r.active_approved>0
        ?"INTERNAL_APPROVED_PUBLIC_RIGHTS_NOT_CONFIRMED"
        :"NO_ACTIVE_APPROVED_BOUNDARY_SOURCE"
  })).sort((a,b)=>a.state_code.localeCompare(b.state_code));
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:CORS});
  if(req.method!=="GET") return new Response(JSON.stringify({complete:false,error:"GET_REQUIRED"}),{status:405,headers:JSONH});
  const service=createClient(U,S,{auth:{persistSession:false,autoRefreshToken:false}});
  try{
    const url=new URL(req.url);

    if(url.searchParams.get("states")==="1"){
      const bodyParams=new URLSearchParams({
        where:"STATE IS NOT NULL",
        outFields:"STATE,STUSAB,BASENAME,NAME",
        returnGeometry:"true",
        outSR:"4326",
        f:"geojson"
      });
      const upstream=await fetch(CENSUS_STATES,{
        method:"POST",
        headers:{
          "content-type":"application/x-www-form-urlencoded;charset=UTF-8",
          "accept":"application/geo+json,application/json",
          "user-agent":"BridgePoint-Intelligence/1.0 (+https://bridgepointintelligence.online)"
        },
        body:bodyParams.toString()
      });
      if(!upstream.ok) throw new Error("CENSUS_STATE_GEOMETRY_HTTP_"+upstream.status);
      const body=await upstream.text();
      if(!body.trim().startsWith("{")) throw new Error("CENSUS_STATE_GEOMETRY_REJECTED");
      return new Response(body,{status:200,headers:{
        ...CORS,
        "content-type":"application/geo+json",
        "cache-control":"public,max-age=86400,stale-while-revalidate=604800",
        "x-bridgepoint-boundary-source":"US_CENSUS_TIGERWEB_2026"
      }});
    }

    const mode=(url.searchParams.get("mode")||"public").toLowerCase();
    const owner=mode==="owner";
    if(owner && !(await ownerAllowed(req,service))){
      return new Response(JSON.stringify({complete:false,error:"OWNER_REQUIRED"}),{status:403,headers:JSONH});
    }
    if(!owner && mode!=="public"){
      return new Response(JSON.stringify({complete:false,error:"INVALID_MODE"}),{status:400,headers:JSONH});
    }

    if(url.searchParams.get("status")==="1"){
      const [{data,error},states]=await Promise.all([
        service.schema("automation").rpc("parcel_boundary_viewer_status_v5403",{}),
        stateStatuses(service)
      ]);
      if(error) throw error;
      const safe=owner?{...data,states}:{ 
        version:5579,
        generated_at:data?.generated_at,
        parcel_counter_total:data?.parcel_counter_total,
        public_display_candidates:data?.public_display_candidates,
        public_policy:data?.public_policy,
        states
      };
      return new Response(JSON.stringify({complete:true,version:5579,mode,status:safe}),{headers:JSONH});
    }

    const z=Number(url.searchParams.get("z")),x=Number(url.searchParams.get("x")),y=Number(url.searchParams.get("y"));
    if(!Number.isInteger(z)||!Number.isInteger(x)||!Number.isInteger(y)||z<0||z>22||x<0||y<0){
      return new Response(JSON.stringify({complete:false,error:"INVALID_TILE"}),{status:400,headers:JSONH});
    }
    if((!owner&&z<7)||(owner&&z<4)){
      return new Response(new Uint8Array(),{status:200,headers:{...CORS,"content-type":"application/vnd.mapbox-vector-tile","cache-control":owner?"no-store":"public,max-age=120"}});
    }
    const {data,error}=await service.schema("automation").rpc("parcel_boundary_tile_v5403",{p_z:z,p_x:x,p_y:y,p_public:!owner});
    if(error) throw error;
    return new Response(hexToBytes(String(data||"")),{status:200,headers:{
      ...CORS,
      "content-type":"application/vnd.mapbox-vector-tile",
      "cache-control":owner?"no-store":"public,max-age=120,stale-while-revalidate=300",
      "x-bridgepoint-boundary-viewer":"5579",
      "x-bridgepoint-boundary-mode":owner?"owner-exact":"public-rights-cleared"
    }});
  }catch(e){
    return new Response(JSON.stringify({complete:false,version:5579,error:String((e as any)?.message||e)}),{status:500,headers:JSONH});
  }
});