import "jsr:@supabase/functions-js/edge-runtime.d.ts";
function out(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{"content-type":"application/json","cache-control":"no-store"}})}
Deno.serve(async(req:Request)=>{
  if(!["GET","POST"].includes(req.method))return out({complete:false,error:"GET or POST required"},405);
  try{
    const r=await fetch("https://zearches.com/",{headers:{"user-agent":"BridgePoint-Directory-Compatibility-Check/1.3 (+https://bridgepointintelligence.online/about/)"}});
    const html=await r.text();
    const forms=[...html.matchAll(/<form\b([^>]*)>([\s\S]*?)<\/form>/gi)].map((m)=>{
      const attrs=m[1]||"",body=m[2]||"";
      const action=(attrs.match(/action=["']([^"']*)["']/i)||[])[1]||"";
      const method=((attrs.match(/method=["']([^"']*)["']/i)||[])[1]||"GET").toUpperCase();
      const fields=[...body.matchAll(/<(input|textarea|select)\b([^>]*)>/gi)].map((x)=>{const a=x[2]||"";return {tag:x[1].toLowerCase(),name:(a.match(/name=["']([^"']*)["']/i)||[])[1]||"",type:(a.match(/type=["']([^"']*)["']/i)||[])[1]||"",value:(a.match(/value=["']([^"']*)["']/i)||[])[1]||"",required:/\brequired\b/i.test(a)};}).filter(x=>x.name);
      const hasCaptcha=/captcha|recaptcha|hcaptcha|turnstile/i.test(body);
      const options=[...body.matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)].map(x=>({value:(x[1].match(/value=["']([^"']*)["']/i)||[])[1]||"",label:x[2].replace(/<[^>]+>/g," ").replace(/\s+/g," ").trim()}));
      return {action,method,fields,hasCaptcha,options};
    });
    return out({complete:r.ok,status:r.status,url:r.url,forms},r.ok?200:502);
  }catch(e){return out({complete:false,error:String(e)},500)}
});