import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const FALLBACK = "https://bridgepointintelligence.online";

Deno.serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const code = (url.searchParams.get("r") || "").trim().toLowerCase();
    if (!/^bp-[a-z0-9-]{3,80}$/.test(code)) {
      return Response.redirect(FALLBACK, 302);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const client = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await client.rpc("bridgepoint_referral_resolve_v409", { p_code: code });
    const destination = !error && typeof data === "string" && data.startsWith("https://") ? data : FALLBACK;

    return new Response(null, {
      status: 302,
      headers: {
        "Location": destination,
        "Cache-Control": "no-store, max-age=0",
        "Referrer-Policy": "strict-origin-when-cross-origin",
      },
    });
  } catch (_) {
    return Response.redirect(FALLBACK, 302);
  }
});
