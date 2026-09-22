import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const TASK_TOKEN = "2f077546f9566fff7312f290bff97649040fa39a4cd601e5ef97b7d93f05bdec";
const allowed: Record<string,string> = {
  "TCEQ_SPILLS":"xagr-a3x2",
  "TCEQ_NOV":"mwzi-gyw7",
  "TCEQ_NOE":"rua3-iswk",
  "TCEQ_COMPLAINTS":"tdzs-qqjn",
};

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("method", {status:405});
    const body = await req.json();
    if (body?.task_token !== TASK_TOKEN) return new Response("unauthorized", {status:401});
    const out:any = {};
    for (const [key,id] of Object.entries(allowed)) {
      const url = `https://data.texas.gov/resource/${id}.json?$limit=2`;
      const r = await fetch(url, {headers:{"Accept":"application/json","User-Agent":"BridgePoint-Intelligence/2020"}});
      const text = await r.text();
      let rows:any[]=[];
      try { rows = JSON.parse(text); } catch {}
      out[key] = {
        status:r.status,
        dataset_id:id,
        row_count:Array.isArray(rows)?rows.length:0,
        keys:Array.isArray(rows)&&rows[0]?Object.keys(rows[0]).sort():[],
        sample_types:Array.isArray(rows)&&rows[0]?Object.fromEntries(Object.entries(rows[0]).map(([k,v])=>[k,Array.isArray(v)?"array":v===null?"null":typeof v])):{},
        error: r.ok?null:text.slice(0,500)
      };
    }
    return new Response(JSON.stringify({complete:true,version:2020,sources:out}), {headers:{"content-type":"application/json"}});
  } catch (e) {
    return new Response(JSON.stringify({complete:false,error:String(e)}), {status:500,headers:{"content-type":"application/json"}});
  }
});
