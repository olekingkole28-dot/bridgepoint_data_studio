const U=Deno.env.get("SUPABASE_URL")!,S=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
async function rpc(name:string,body:any){
  const r=await fetch(U+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:S,authorization:"Bearer "+S,"content-type":"application/json"},body:JSON.stringify(body)});
  const t=await r.text();if(!r.ok)throw new Error(name+"_"+r.status+":"+t.slice(0,500));return t?JSON.parse(t):null
}
function cell(key:string,count:number,b:number[]){
  const [d,x,y,z]=key.split("-").map(Number),n=2**d,dx=(b[3]-b[0])/n,dy=(b[4]-b[1])/n,dz=(b[5]-b[2])/n;
  return {node_key:key,depth:d,x_index:x,y_index:y,z_index:z,point_count:count,
    x_min:b[0]+x*dx,y_min:b[1]+y*dy,z_min:b[2]+z*dz,
    x_max:b[0]+(x+1)*dx,y_max:b[1]+(y+1)*dy,z_max:b[2]+(z+1)*dz}
}
Deno.serve(async(req)=>{
 let claim:any=null;
 try{
   if(req.method!=="POST")return new Response("POST required",{status:405});
   const body=await req.json().catch(()=>({})),token=String(body.task_token||"");if(!token)throw new Error("TASK_TOKEN_REQUIRED");
   claim=await rpc("bridgepoint_lidar_roof_hierarchy_claim_v5057",{p_task_token:token});
   if(!claim?.claimed)return new Response(JSON.stringify({complete:true,version:5057,skipped:"NO_HIERARCHY_DUE"}),{headers:{"content-type":"application/json"}});
   const bounds=(claim.bounds||[]).map(Number);if(bounds.length<6)throw new Error("BAD_PROJECT_BOUNDS");
   const width=Math.max(bounds[3]-bounds[0],bounds[4]-bounds[1]);
   const minDepth=Math.max(6,Math.min(8,Math.ceil(Math.log2(Math.max(1,width)/300))));
   const base=String(claim.ept_url).replace(/\/ept\.json$/,"");
   const url=base+"/ept-hierarchy/"+claim.hierarchy_key+".json";
   const res=await fetch(url,{signal:AbortSignal.timeout(90000)});if(!res.ok)throw new Error("HIER_"+res.status+":"+url);
   if(!res.body)throw new Error("HIER_NO_BODY");
   const reader=res.body.getReader(),decoder=new TextDecoder();
   let buf="",entries=0,cellsN=0,childrenN=0;
   let cells:any[]=[],children:any[]=[];
   const flush=async()=>{
     if(!cells.length&&!children.length)return;
     await rpc("bridgepoint_lidar_roof_hierarchy_ingest_v5057",{p_task_token:token,p_project_key:claim.project_key,p_cells:cells,p_children:children});
     cells=[];children=[]
   };
   const parsePart=async(part:string)=>{
     const m=part.match(/"([0-9]+-[0-9]+-[0-9]+-[0-9]+)"\s*:\s*(-?[0-9]+)/);if(!m)return;
     entries++;const key=m[1],count=Number(m[2]),depth=Number(key.split("-")[0]);
     if(count<0){children.push({hierarchy_key:key});childrenN++}
     else if(count>0&&depth>=minDepth){cells.push(cell(key,count,bounds));cellsN++}
     if(cells.length+children.length>=180)await flush()
   };
   while(true){
     const {value,done}=await reader.read();
     if(done)break;
     buf+=decoder.decode(value,{stream:true});
     const parts=buf.split(",");buf=parts.pop()||"";
     for(const p of parts)await parsePart(p)
   }
   buf+=decoder.decode();
   await parsePart(buf.replace(/[{}]/g,""));
   await flush();
   await rpc("bridgepoint_lidar_roof_hierarchy_finish_v5057",{p_task_token:token,p_project_key:claim.project_key,p_hierarchy_key:claim.hierarchy_key,p_lease_token:claim.lease_token,p_success:true,p_entries_seen:entries,p_cells_enqueued:cellsN,p_child_hierarchies:childrenN,p_error:null});
   return new Response(JSON.stringify({complete:true,version:5057,project_key:claim.project_key,hierarchy_key:claim.hierarchy_key,min_depth:minDepth,entries_seen:entries,cells_enqueued:cellsN,child_hierarchies:childrenN}),{headers:{"content-type":"application/json"}})
 }catch(e){
   try{if(claim?.claimed){const body=await req.clone().json().catch(()=>({}));await rpc("bridgepoint_lidar_roof_hierarchy_finish_v5057",{p_task_token:String(body.task_token||""),p_project_key:claim.project_key,p_hierarchy_key:claim.hierarchy_key,p_lease_token:claim.lease_token,p_success:false,p_entries_seen:0,p_cells_enqueued:0,p_child_hierarchies:0,p_error:String((e as any)?.message||e)})}}catch(_){}
   return new Response(JSON.stringify({complete:false,version:5057,error:String((e as any)?.message||e),project_key:claim?.project_key||null,hierarchy_key:claim?.hierarchy_key||null}),{status:500,headers:{"content-type":"application/json"}})
 }
});