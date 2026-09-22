import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async () => {
  const SB=Deno.env.get("SUPABASE_URL")!, KEY=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const targetCandidate="4cfbc807-49e1-4283-b31e-f73d3f237032";
  async function get(url:string){try{const r=await fetch(url,{headers:{"User-Agent":"BridgePoint-Source-Verification/1.0"},redirect:"follow"});const body=await r.text();return{status:r.status,url:r.url,body};}catch(e){return{status:0,url,body:String(e)}}}
  async function json(url:string){const r=await get(url);let j:any=null;try{j=JSON.parse(r.body)}catch{}return{...r,json:j};}
  const services:any[]=[
    {key:"propertySearch",root:"https://gis.cobbcounty.gov/gisserver/rest/services/cobbpublic/PropertySearch/MapServer"},
    {key:"taxDailyFeature",root:"https://gis.cobbcounty.gov/gisserver/rest/services/tax/taxassessorsdaily/FeatureServer"},
    {key:"taxDailyMap",root:"https://gis.cobbcounty.gov/gisserver/rest/services/tax/taxassessorsdaily/MapServer"},
    {key:"parcelDim",root:"https://gis.cobbcounty.gov/gisserver/rest/services/tax/parceldim/MapServer"}
  ];
  const out:any={complete:true,at:new Date().toISOString(),services:{},taxApi:{}};
  for(const s of services){
    const rr=await json(s.root+"?f=pjson");
    const root=rr.json||{}; const entries=[...(root.layers||[]).map((x:any)=>({...x,entryType:"layer"})),...(root.tables||[]).map((x:any)=>({...x,entryType:"table"}))];
    const details:any[]=[];
    for(const e of entries.slice(0,100)){
      const dr=await json(`${s.root}/${e.id}?f=pjson`); const d=dr.json||{};
      let count:any=null;
      if(d.capabilities && /query/i.test(d.capabilities)){
        const cr=await json(`${s.root}/${e.id}/query?where=1%3D1&returnCountOnly=true&f=json`); count=cr.json?.count??null;
      }
      details.push({id:e.id,name:e.name,entryType:e.entryType,status:dr.status,count,type:d.type,geometryType:d.geometryType,capabilities:d.capabilities,displayField:d.displayField,copyrightText:d.copyrightText,description:d.description,maxRecordCount:d.maxRecordCount,fields:(d.fields||[]).map((f:any)=>({name:f.name,alias:f.alias,type:f.type,length:f.length})),serviceItemId:d.serviceItemId});
    }
    out.services[s.key]={root:s.root,status:rr.status,description:root.description,copyrightText:root.copyrightText,capabilities:root.capabilities,serviceDescription:root.serviceDescription,layers:root.layers,tables:root.tables,details};
  }
  const apiBase="https://gis.cobbcounty.gov/taxestimator";
  for(const [k,u] of Object.entries({suggest:`${apiBase}/api/suggest?q=1000`,search:`${apiBase}/api/search?q=1000`,parcel:`${apiBase}/api/parcel/01000100010`})){
    const r=await get(u as string); out.taxApi[k]={status:r.status,finalUrl:r.url,body:r.body.slice(0,12000)};
  }
  const headers:any={apikey:KEY,Authorization:`Bearer ${KEY}`,"Accept-Profile":"automation","Content-Profile":"automation","content-type":"application/json"};
  const rr=await fetch(`${SB}/rest/v1/geographic_source_candidates_v86?candidate_id=eq.${targetCandidate}&select=metadata`,{headers});const rows=await rr.json();if(!rr.ok||!rows?.[0])return Response.json({complete:false,error:"read",status:rr.status,out},{status:500});
  const metadata={...(rows[0].metadata||{}),cobb_service_probe_v1668:out,cobb_service_probe_at_v1668:new Date().toISOString()};
  const wr=await fetch(`${SB}/rest/v1/geographic_source_candidates_v86?candidate_id=eq.${targetCandidate}`,{method:"PATCH",headers:{...headers,Prefer:"return=minimal"},body:JSON.stringify({metadata})});
  if(!wr.ok)return Response.json({complete:false,error:"write",status:wr.status,body:await wr.text(),out},{status:500});
  return Response.json({complete:true,written:true,summary:Object.fromEntries(Object.entries(out.services).map(([k,v]:any)=>[k,{status:v.status,layers:v.layers?.length||0,tables:v.tables?.length||0,details:v.details.map((d:any)=>({id:d.id,name:d.name,entryType:d.entryType,count:d.count,geometryType:d.geometryType,capabilities:d.capabilities,fieldNames:d.fields.map((f:any)=>f.name)}))}])),taxApi:Object.fromEntries(Object.entries(out.taxApi).map(([k,v]:any)=>[k,{status:v.status,body:v.body.slice(0,1000)}]))});
});