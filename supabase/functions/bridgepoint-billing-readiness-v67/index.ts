import "jsr:@supabase/functions-js/edge-runtime.d.ts";
Deno.serve(()=>new Response(JSON.stringify({
 complete:true,
 stripe_secret_configured:Boolean(Deno.env.get("STRIPE_SECRET_KEY")),
 webhook_secret_configured:Boolean(Deno.env.get("STRIPE_WEBHOOK_SECRET")),
 app_url_configured:Boolean(Deno.env.get("BRIDGEPOINT_APP_URL")),
 environment:"sandbox"
}),{headers:{"Content-Type":"application/json","Cache-Control":"no-store"}}));
