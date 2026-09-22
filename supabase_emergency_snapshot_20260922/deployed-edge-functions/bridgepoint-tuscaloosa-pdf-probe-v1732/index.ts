import pdf from "npm:pdf-parse@1.1.1";
import { Buffer } from "node:buffer";
const H={"content-type":"application/json","cache-control":"no-store"};
const KEY="[REDACTED_LONG_LITERAL]";
const PDF_URL="https://www.tuscco.com/wp-content/uploads/2026/05/2026-Real-Property-Valuation-Notices-Numerical-by-Parcel-01-21.pdf";
Deno.serve(async(req:Request)=>{try{
 const ru=new URL(req.url); if(req.method!=="GET"||ru.searchParams.get("k")!==KEY)return new Response(JSON.stringify({complete:false,error:"UNAUTHORIZED"}),{status:401,headers:H});
 const r=await fetch(PDF_URL,{headers:{"user-agent":"BridgePointIntelligence/1.0 (+county-public-record-ingest)",accept:"application/pdf"},signal:AbortSignal.timeout(120000)}); if(!r.ok)throw new Error(`PDF_HTTP_${r.status}`);
 const ab=await r.arrayBuffer(); const data=await pdf(Buffer.from(ab)); const text=String(data.text||"");
 const lines=text.split(/\r?\n/).map(x=>x.trim()).filter(Boolean); const candidates=lines.filter(x=>/\b(?:0?[1-9]|1\d|2[01])[-\s][0-9A-Z.-]{3,}/i.test(x)).slice(0,120);
 return new Response(JSON.stringify({complete:true,bytes:ab.byteLength,pages:data.numpages,text_length:text.length,first_lines:lines.slice(0,140),parcelish_lines:candidates}),{headers:H});
 }catch(e){return new Response(JSON.stringify({complete:false,error:String((e as any)?.stack||e)}),{status:500,headers:H});}});