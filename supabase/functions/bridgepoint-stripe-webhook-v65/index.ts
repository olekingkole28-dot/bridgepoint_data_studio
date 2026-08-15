import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});
const hex=(bytes:ArrayBuffer)=>[...new Uint8Array(bytes)].map(b=>b.toString(16).padStart(2,"0")).join("");
const safeEqual=(a:string,b:string)=>{
 if(a.length!==b.length) return false;
 let diff=0; for(let i=0;i<a.length;i++) diff|=a.charCodeAt(i)^b.charCodeAt(i);
 return diff===0;
};

Deno.serve(async(req:Request)=>{
 try{
  if(req.method!=="POST") return json({complete:false,error:"Method not allowed"},405);
  const secret=Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if(!secret) return json({complete:false,error:"Webhook secret is not configured"},503);
  const signature=req.headers.get("stripe-signature")??"";
  const raw=await req.text();
  const parts=Object.fromEntries(signature.split(",").map(x=>x.split("=",2)));
  const timestamp=parts.t; const supplied=parts.v1;
  if(!timestamp||!supplied||Math.abs(Date.now()/1000-Number(timestamp))>300) return json({complete:false,error:"Invalid signature"},400);
  const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const expected=hex(await crypto.subtle.sign("HMAC",key,new TextEncoder().encode(`${timestamp}.${raw}`)));
  if(!safeEqual(expected,supplied)) return json({complete:false,error:"Invalid signature"},400);
  const event=JSON.parse(raw);
  const url=Deno.env.get("SUPABASE_URL")!; const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const result=await fetch(`${url}/rest/v1/rpc/bridgepoint_billing_apply_event_v65`,{
   method:"POST",headers:{apikey:service,Authorization:`Bearer ${service}`,"Content-Type":"application/json"},body:JSON.stringify({p_event:event})
  });
  if(!result.ok) return json({complete:false,error:await result.text()},500);
  return json(await result.json());
 }catch(error){return json({complete:false,error:String(error)},500);}
});
