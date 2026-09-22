import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL=Deno.env.get("SUPABASE_URL")!;
const ANON_KEY=Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin=createClient(SUPABASE_URL,SERVICE_ROLE,{auth:{persistSession:false}});
const MODERN="2026-07-28";
const LEGACY="2025-11-25";
const info={name:"bridgepoint-governed-property-intelligence",title:"BridgePoint Governed Property Intelligence",version:"1.0.0"};
const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Methods":"GET,POST,OPTIONS",
  "Access-Control-Allow-Headers":"authorization,apikey,x-client-info,content-type,accept,mcp-protocol-version,mcp-method,mcp-name",
  "Access-Control-Expose-Headers":"MCP-Protocol-Version"
};
const respond=(obj:unknown,status=200,extra:Record<string,string>={})=>new Response(JSON.stringify(obj),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store",...extra}});
const rpcOk=(id:unknown,result:unknown)=>respond({jsonrpc:"2.0",id,result},200,{"MCP-Protocol-Version":MODERN});
const rpcErr=(id:unknown,code:number,message:string,data?:unknown)=>respond({jsonrpc:"2.0",id,error:{code,message,...(data===undefined?{}:{data})}},200,{"MCP-Protocol-Version":MODERN});
const exact=(content:unknown)=>({structuredContent:content,content:[{type:"text",text:JSON.stringify(content)}],isError:false});

const tools=[
  {name:"map_render_manifest",title:"Map render manifest",description:"Return BridgePoint's tenant-scoped, rights-aware, quality-aware map layer decisions for a zoom/state. Premium layers remain blocked until licensed and activated.",resourceType:"map",annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true},inputSchema:{type:"object",properties:{zoom:{type:"number",minimum:0,maximum:24},state_code:{type:["string","null"]}},additionalProperties:false}},
  {name:"property_map_viewport",title:"Property map viewport",description:"Return entitled property records inside a geographic viewport using BridgePoint's server-side state and package gates.",resourceType:"property",annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true},inputSchema:{type:"object",properties:{min_lat:{type:"number"},max_lat:{type:"number"},min_lng:{type:"number"},max_lng:{type:"number"},limit:{type:"integer",minimum:1,maximum:500}},required:["min_lat","max_lat","min_lng","max_lng"],additionalProperties:false}},
  {name:"property_imagery_history",title:"Property imagery history",description:"Return source-linked imagery-history references for an entitled property. Historical imagery is evidence/context and not automatic proof of physical change.",resourceType:"intelligence",annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true},inputSchema:{type:"object",properties:{property_id:{type:"string",format:"uuid"}},required:["property_id"],additionalProperties:false}},
  {name:"weather_radar_state",title:"Weather radar state",description:"Return the entitled NOAA/NWS radar source state, truth-scale warning, hail-derived availability, historical-context separation and nonblank fallback chain.",resourceType:"intelligence",annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true},inputSchema:{type:"object",properties:{state_code:{type:["string","null"]}},additionalProperties:false}},
  {name:"competitor_scorecard",title:"Owner competitor scorecard",description:"Owner-only evidence-backed competitor capability/gap scorecard. Does not assert unsupported superiority.",resourceType:"intelligence",ownerOnly:true,annotations:{readOnlyHint:true,destructiveHint:false,idempotentHint:true},inputSchema:{type:"object",properties:{},additionalProperties:false}}
];

async function sha256(value:string){const bytes=new TextEncoder().encode(value);const digest=await crypto.subtle.digest("SHA-256",bytes);return [...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,"0")).join("");}
async function orgFor(userId:string){try{const {data}=await admin.schema("accounts").from("organization_members").select("organization_id").eq("user_id",userId).eq("is_active",true).limit(1).maybeSingle();return data?.organization_id??null;}catch{return null;}}
async function audit(userId:string,tool:string,allowed:boolean,resultStatus:string,requestHash:string,details:Record<string,unknown>={}){
  try{await admin.schema("product").from("mcp_audit_log_v859").insert({organization_id:await orgFor(userId),user_id:userId,connector_key:"bridgepoint_mcp_server",direction:"INBOUND",tool_name:tool,operation:"READ",write_attempt:false,allowed,request_hash:requestHash,result_status:resultStatus,details});}catch(_){/* Audit failure must not expose data or bypass authorization; caller authorization is evaluated separately. */}
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors});
  if(req.method!=="POST"&&req.method!=="GET")return respond({error:"method_not_allowed"},405);
  const auth=req.headers.get("authorization")||"";
  const userClient=createClient(SUPABASE_URL,ANON_KEY,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:authData,error:authError}=await userClient.auth.getUser();
  if(authError||!authData.user)return respond({error:"authentication_required"},401);
  const userId=authData.user.id;
  const {data:policy,error:policyError}=await userClient.rpc("bridgepoint_mcp_effective_policy_v859",{p_connector_key:"bridgepoint_mcp_server"});
  if(policyError||!policy||policy.authorized!==true)return respond({error:"mcp_connector_not_authorized",message:"This account does not have an active BridgePoint governed MCP grant."},403);
  const owner=policy.owner===true;
  const readScopes=Array.isArray(policy.read_scopes)?policy.read_scopes.map((x:any)=>String(x)):[];

  if(req.method==="GET")return respond({complete:true,serverInfo:info,protocols:[MODERN,LEGACY],authorized:true,owner,write_enabled:false,tools:tools.filter(t=>!t.ownerOnly||owner).map(t=>t.name)});
  let body:any;try{body=await req.json();}catch{return rpcErr(null,-32700,"Parse error");}
  const requestHash=await sha256(JSON.stringify(body));
  const id=body?.id??null;
  const method=String(body?.method||"");
  if(method==="initialize"){
    const requested=String(body?.params?.protocolVersion||"");
    const selected=requested===MODERN||requested===LEGACY?requested:MODERN;
    return respond({jsonrpc:"2.0",id,result:{protocolVersion:selected,capabilities:{tools:{listChanged:false}},serverInfo:info,instructions:"BridgePoint governed MCP is tenant-scoped and read-first. Only allowlisted resources are exposed. Writes are disabled unless a separately deployed owner-approved action and grant exist."}},200,{"MCP-Protocol-Version":selected});
  }
  if(method==="notifications/initialized")return new Response(null,{status:202,headers:cors});
  if(method==="ping")return rpcOk(id,{});
  if(method==="tools/list")return rpcOk(id,{tools:tools.filter(t=>!t.ownerOnly||owner).map(({resourceType,ownerOnly,...t})=>t)});
  if(method!=="tools/call")return rpcErr(id,-32601,"Method not found");

  const name=String(body?.params?.name||"");
  const args=body?.params?.arguments||{};
  const spec=tools.find(t=>t.name===name);
  if(!spec){await audit(userId,name||"<missing>",false,"UNKNOWN_TOOL",requestHash);return rpcErr(id,-32602,"Unknown tool");}
  if(spec.ownerOnly&&!owner){await audit(userId,name,false,"OWNER_ONLY_DENIED",requestHash);return rpcErr(id,-32603,"Owner access required");}
  if(!owner&&!readScopes.includes(spec.resourceType)){await audit(userId,name,false,"SCOPE_DENIED",requestHash,{required_scope:spec.resourceType});return rpcErr(id,-32603,"MCP scope does not allow this resource type");}

  try{
    let data:any=null,error:any=null;
    if(name==="map_render_manifest")({data,error}=await userClient.rpc("bridgepoint_map_render_manifest_v860",{p_zoom:Number(args.zoom??12),p_state_code:args.state_code??null}));
    else if(name==="property_map_viewport")({data,error}=await userClient.rpc("bridgepoint_flutter_property_map_viewport_v838",{p_min_lat:Number(args.min_lat),p_max_lat:Number(args.max_lat),p_min_lng:Number(args.min_lng),p_max_lng:Number(args.max_lng),p_limit:Number(args.limit??300)}));
    else if(name==="property_imagery_history")({data,error}=await userClient.rpc("bridgepoint_property_imagery_history_v169",{p_property_id:String(args.property_id||"")}));
    else if(name==="weather_radar_state")({data,error}=await userClient.rpc("bridgepoint_weather_radar_state_v860",{p_state_code:args.state_code??null}));
    else if(name==="competitor_scorecard")({data,error}=await userClient.rpc("bridgepoint_owner_competitor_gap_v679"));
    if(error)throw error;
    await audit(userId,name,true,"SUCCESS",requestHash,{resource_type:spec.resourceType});
    return rpcOk(id,exact(data));
  }catch(e){
    const message=String((e as any)?.message||e);
    await audit(userId,name,true,"UPSTREAM_ERROR",requestHash,{error:message.slice(0,500)});
    return rpcErr(id,-32000,"BridgePoint tool execution failed",{message});
  }
});