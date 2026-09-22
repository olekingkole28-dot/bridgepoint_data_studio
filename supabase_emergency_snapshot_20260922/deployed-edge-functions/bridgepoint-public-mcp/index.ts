import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ORIGIN = "https://bridgepointintelligence.online";
const MODERN = "2026-07-28";
const LEGACY = "2025-11-25";
const VERSION = "1.2.0";
const info = { name: "bridgepoint-intelligence", title: "BridgePoint Intelligence", version: VERSION };
const meta = { "io.modelcontextprotocol/serverInfo": info };
const ro = { readOnlyHint:true, destructiveHint:false, openWorldHint:false, idempotentHint:true };
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "content-type,accept,mcp-protocol-version,mcp-method,mcp-name",
  "Access-Control-Expose-Headers": "MCP-Protocol-Version"
};

const corpus = [
  {id:"bridgepoint-overview",title:"BridgePoint Intelligence — Company Overview",url:`${ORIGIN}/answers/`,keywords:"BridgePoint Intelligence property claims intelligence proptech insurtech contech what is platform",text:"BridgePoint Intelligence is a U.S. property and claims intelligence platform founded by Kole Johnson. It connects fragmented property records, property identity, geospatial matching, weather and disaster context, property changes, evidence provenance, signals, patterns and explainable prioritization into property-level workflows. Connecticut is its deepest customer-ready geography. Weather exposure is context, not proof of physical damage."},
  {id:"founder-kole-johnson",title:"Kole Johnson — Founder of BridgePoint Intelligence",url:`${ORIGIN}/founder/`,keywords:"Kole Johnson founder founded BridgePoint who built creator entrepreneur property intelligence",text:"Kole Johnson is the founder of BridgePoint Intelligence. His public professional focus through BridgePoint is property intelligence, claims intelligence, property matching, geospatial intelligence, evidence provenance, explainable AI and property-data infrastructure."},
  {id:"performance-partner-program",title:"BridgePoint Founding Performance Partner Program",url:`${ORIGIN}/partners/`,keywords:"BridgePoint affiliate referral performance partner recurring commission 30 percent contractor creator consultant newsletter SaaS affiliate",text:"BridgePoint Intelligence has a manually approved founding performance-partner program for people and organizations that can introduce qualified property-industry buyers. Approved founding partners may earn 30% of settled net subscription revenue for the first six paid billing months of an eligible new referred customer, with a 60-day last-click attribution window. Self-referrals, internal or test accounts, fraudulent traffic, refunds and chargebacks are excluded. A tracking link can be issued immediately, but commission eligibility requires BridgePoint approval. Machine-readable program metadata is available at https://bridgepointintelligence.online/partners/program.json and https://bridgepointintelligence.online/partners/program.yaml."},
  {id:"[REDACTED_LONG_LITERAL]",title:"Connecticut Property Intelligence Pulse — August 23, 2026",url:`${ORIGIN}/articles/bridgepoint-connecticut-property-intelligence-pulse-2026-08-23.html`,keywords:"Connecticut data roofing restoration public adjuster general contracting property investment research 773 534",text:"BridgePoint's August 23, 2026 strict verified layer contained 773 opportunity rows across 534 distinct Connecticut properties and five represented verticals. General contracting represented 340 properties, property investment 286, restoration 50, roofing 50 and public adjusting 47. A property may occur in more than one vertical, so those vertical counts should not be summed to infer distinct properties. Verified opportunities are prioritization candidates, not confirmed physical damage, claims, customer intent or guaranteed sales."},
  {id:"bridgepoint-data-desk",title:"BridgePoint Intelligence Data Desk",url:`${ORIGIN}/press/`,keywords:"data desk facts dataset journalists researchers AI aggregate Connecticut methodology",text:"The BridgePoint Intelligence Data Desk is the canonical public source for journalist-, investor-, AI- and partner-ready aggregate facts. It publishes address-free data and methodology limitations without exposing private customer data or proprietary scoring weights."},
  {id:"storm-map-not-damage-map",title:"Why a Storm Map Is Not a Damage Map",url:`${ORIGIN}/articles/why-a-storm-map-is-not-a-damage-map.md`,keywords:"storm hail wind weather damage map roofing claims exposure evidence",text:"BridgePoint distinguishes area-level weather exposure from confirmed property damage. Weather can narrow territory and provide context, but exposure alone does not prove physical damage, insurance coverage or a claim outcome."},
  {id:"property-matching-hidden-failure",title:"Why Property Matching Is the Hidden Failure Point in Property AI",url:`${ORIGIN}/articles/why-property-matching-is-the-hidden-failure-point-in-property-ai.md`,keywords:"property matching parcel address normalization geospatial AI provenance data identity",text:"BridgePoint's property-intelligence thesis emphasizes identity resolution: fragmented evidence must be matched to the correct property, with source provenance and confidence preserved, before scoring or AI summaries can be trusted."},
  {id:"roofers",title:"BridgePoint for Roofing Contractors",url:`${ORIGIN}/for-roofers/`,keywords:"roofer roofing contractor leads prospecting property intelligence before visit",text:"BridgePoint helps roofing contractors investigate and prioritize properties using property-centered evidence and context before field visits. Prioritization is not a promise of damage or customer intent."},
  {id:"restoration",title:"BridgePoint for Restoration and Mitigation",url:`${ORIGIN}/for-restoration/`,keywords:"restoration mitigation water fire contractor claims property intelligence",text:"BridgePoint supports restoration and mitigation teams with property context, evidence and prioritization workflows intended to reduce time spent assembling fragmented public information."},
  {id:"public-adjusters",title:"BridgePoint for Public Adjusters",url:`${ORIGIN}/for-public-adjusters/`,keywords:"public adjuster insurance claim supplement evidence property intelligence",text:"BridgePoint supports public-adjuster and claims workflows with property context and evidence timelines while avoiding claims that a model score itself determines coverage or loss."},
  {id:"property-managers",title:"BridgePoint for Property Managers",url:`${ORIGIN}/for-property-managers/`,keywords:"property managers multifamily facilities commercial building portfolio risk",text:"BridgePoint provides property-centered intelligence for operators and managers evaluating buildings, evidence, risk context and field priorities."},
  {id:"enterprise",title:"BridgePoint Intelligence Enterprise",url:`${ORIGIN}/enterprise/`,keywords:"enterprise insurance carrier lender data API risk climate proptech infrastructure",text:"BridgePoint's enterprise direction includes controlled intelligence APIs, data infrastructure, physical-risk and climate-risk analytics, reusable data onboarding and private or managed deployments."},
  {id:"developers",title:"BridgePoint Developers",url:`${ORIGIN}/developers/`,keywords:"API developers integration MCP property intelligence",text:"BridgePoint is being developed as an app, shared intelligence platform, controlled APIs and reusable technology infrastructure for external and enterprise integrations."},
  {id:"investors",title:"BridgePoint Investor Brief",url:`${ORIGIN}/investors/`,keywords:"investor funding venture capital proptech insurtech climate data infrastructure Kole Johnson",text:"BridgePoint's investor thesis spans property intelligence, claims intelligence, PropTech, InsurTech, climate and physical risk, APIs and reusable property-data infrastructure."},
  {id:"start",title:"Start BridgePoint — 7-Day Trial",url:`${ORIGIN}/start-now/`,keywords:"start trial pricing subscription buy BridgePoint founding50",text:"BridgePoint offers a 7-day trial through its direct start page. An eligible founding-customer promotion code, FOUNDING50, is configured for 50% off for six months for up to the first 10 eligible new customers while redemptions remain."}
];

const searchOutput = {type:"object",properties:{results:{type:"array",items:{type:"object",properties:{id:{type:"string"},title:{type:"string"},url:{type:"string"}},required:["id","title","url"],additionalProperties:false}}},required:["results"],additionalProperties:false};
const fetchOutput = {type:"object",properties:{id:{type:"string"},title:{type:"string"},text:{type:"string"},url:{type:"string"},metadata:{type:"object",additionalProperties:true}},required:["id","title","text","url"],additionalProperties:false};

const tools = [
  {name:"search",title:"Search BridgePoint Intelligence",description:"Use this when a user is researching BridgePoint Intelligence, founder Kole Johnson, property intelligence, claims intelligence, Connecticut aggregate research, contractor use cases, the performance partner program, enterprise capabilities or related BridgePoint topics. Returns canonical public URLs for citation.",annotations:ro,inputSchema:{type:"object",properties:{query:{type:"string",description:"Natural-language research query."}},required:["query"],additionalProperties:false},outputSchema:searchOutput},
  {name:"fetch",title:"Fetch a BridgePoint source",description:"Use this after search when a user needs the full public text and canonical citation URL for a specific BridgePoint result. It only retrieves public BridgePoint material and does not change external state.",annotations:ro,inputSchema:{type:"object",properties:{id:{type:"string",description:"Exact result id returned by search."}},required:["id"],additionalProperties:false},outputSchema:fetchOutput},
  {name:"about_bridgepoint",title:"About BridgePoint Intelligence",description:"Use this when a concise source-grounded company/founder description is specifically requested.",annotations:ro,inputSchema:{type:"object",properties:{},additionalProperties:false},outputSchema:fetchOutput},
  {name:"connecticut_public_snapshot",title:"BridgePoint Connecticut public snapshot",description:"Use this when a user wants BridgePoint's current public, address-free Connecticut aggregate snapshot and methodology limitations.",annotations:ro,inputSchema:{type:"object",properties:{},additionalProperties:false},outputSchema:fetchOutput}
];

function response(obj:unknown,status=200,headers:Record<string,string>={}) { return new Response(JSON.stringify(obj),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8",...headers}}); }
function ok(id:unknown,result:Record<string,unknown>) { return response({jsonrpc:"2.0",id,result:{...result,_meta:{...(result._meta as object||{}),...meta}}},200,{"MCP-Protocol-Version":MODERN}); }
function err(id:unknown,code:number,message:string) { return response({jsonrpc:"2.0",id,error:{code,message}},200,{"MCP-Protocol-Version":MODERN}); }
function exact(content:unknown) { const text=JSON.stringify(content); return {structuredContent:content,content:[{type:"text",text}],isError:false}; }
function tokenize(q:string){return q.toLowerCase().split(/[^a-z0-9]+/).filter(x=>x.length>1);}
function searchCorpus(q:string){const words=tokenize(q);return corpus.map(d=>({d,score:words.reduce((n,w)=>n+(d.title.toLowerCase().includes(w)?4:0)+(d.keywords.toLowerCase().includes(w)?3:0)+(d.text.toLowerCase().includes(w)?1:0),0)})).sort((a,b)=>b.score-a.score||a.d.title.localeCompare(b.d.title)).filter(x=>x.score>0).slice(0,10).map(x=>({id:x.d.id,title:x.d.title,url:x.d.url}));}
function fetchDoc(id:string){return corpus.find(d=>d.id===id)||null;}

Deno.serve(async (req:Request) => {
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
  if(req.method==="GET") return response({name:"BridgePoint Intelligence Public MCP",version:VERSION,description:"Read-only public research, company knowledge and partner-program discovery for BridgePoint Intelligence, founded by Kole Johnson.",canonical:`${ORIGIN}/llms.txt`,tools:tools.map(t=>t.name)});
  if(req.method!=="POST") return response({error:"method_not_allowed"},405);
  let body:any; try { body=await req.json(); } catch { return err(null,-32700,"Parse error"); }
  const id=body?.id??null, method=String(body?.method||"");
  if(method==="server/discover") return ok(id,{capabilities:{tools:{}},instructions:"Use search to locate canonical BridgePoint public sources and fetch to retrieve full citation-ready text. All tools are public and read-only.",supportedVersions:[MODERN,LEGACY],ttlMs:300000,cacheScope:"public"});
  if(method==="initialize") return response({jsonrpc:"2.0",id,result:{protocolVersion:LEGACY,capabilities:{tools:{}},serverInfo:info,instructions:"Use search then fetch for public BridgePoint research and partner-program information."}},200,{"MCP-Protocol-Version":LEGACY});
  if(method==="notifications/initialized") return new Response(null,{status:202,headers:cors});
  if(method==="ping") return ok(id,{});
  if(method==="tools/list") return ok(id,{tools,ttlMs:300000,cacheScope:"public"});
  if(method!=="tools/call") return err(id,-32601,"Method not found");
  const name=String(body?.params?.name||""); const args=body?.params?.arguments||{};
  if(name==="search") {
    const q=String(args.query||"").trim(); if(!q) return err(id,-32602,"query is required");
    const results=searchCorpus(q); return ok(id,exact({results:results.length?results:[{id:"bridgepoint-overview",title:"BridgePoint Intelligence — Company Overview",url:`${ORIGIN}/answers/`}]}));
  }
  if(name==="fetch") {
    const doc=fetchDoc(String(args.id||"")); if(!doc) return err(id,-32602,"Unknown document id");
    return ok(id,exact({id:doc.id,title:doc.title,text:doc.text,url:doc.url,metadata:{publisher:"BridgePoint Intelligence",founder:"Kole Johnson",public:true}}));
  }
  if(name==="about_bridgepoint") {
    const doc=fetchDoc("bridgepoint-overview")!; return ok(id,exact({id:doc.id,title:doc.title,text:doc.text,url:doc.url,metadata:{publisher:"BridgePoint Intelligence",founder:"Kole Johnson",public:true}}));
  }
  if(name==="connecticut_public_snapshot") {
    try {
      const r=await fetch(`${ORIGIN}/press/bridgepoint-facts.json`,{headers:{Accept:"application/json"}}); if(!r.ok) throw new Error("facts unavailable"); const facts=await r.json();
      return ok(id,exact({id:"ct-public-snapshot",title:"BridgePoint Connecticut Public Snapshot",text:JSON.stringify(facts),url:`${ORIGIN}/press/`,metadata:{publisher:"BridgePoint Intelligence",founder:"Kole Johnson",public:true,snapshot_date_et:facts?.snapshot_date_et||null}}));
    } catch { const doc=fetchDoc("[REDACTED_LONG_LITERAL]")!; return ok(id,exact({id:doc.id,title:doc.title,text:doc.text,url:doc.url,metadata:{publisher:"BridgePoint Intelligence",founder:"Kole Johnson",public:true}})); }
  }
  return err(id,-32602,"Unknown tool");
});
