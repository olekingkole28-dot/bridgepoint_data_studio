import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (_req: Request) => {
  const url = "https://taxpayments.stlouiscountymo.gov/search/quick?p=4&q=south%20mo";
  try {
    const r = await fetch(url, {
      redirect: "follow",
      headers: {
        "user-agent": "Mozilla/5.0 (compatible; BridgePointDataValidation/1.0)",
        "accept": "text/html,application/xhtml+xml"
      }
    });
    const text = await r.text();
    const hrefs = [...text.matchAll(/href=["']([^"']+)["']/gi)].map(m => m[1]);
    const forms = [...text.matchAll(/<form[^>]*action=["']([^"']*)["'][^>]*>/gi)].map(m => m[1]);
    const interesting = [...new Set(hrefs.filter(h => /csv|export|search|download/i.test(h)))].slice(0,100);
    const snippets = [...text.matchAll(/.{0,180}(?:Export Results to CSV|csv|download).{0,280}/gi)].map(m => m[0]).slice(0,20);
    return Response.json({complete:true,status:r.status,final_url:r.url,length:text.length,interesting,forms,snippets,head:text.slice(0,5000)});
  } catch (e) {
    return Response.json({complete:false,error:String(e)}, {status:500});
  }
});