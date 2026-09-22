import { PDFDocument, StandardFonts, rgb } from "npm:pdf-lib@1.17.1";

const cors = {
  "Access-Control-Allow-Origin": "https://bridgepointintelligence.online",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function wrap(text: unknown, max = 108): string[] {
  const s = String(text ?? "").replace(/\s+/g, " ").trim();
  if (!s) return [];
  const words = s.split(" ");
  const out: string[] = [];
  let line = "";
  for (const w of words) {
    const next = line ? line + " " + w : w;
    if (next.length > max && line) { out.push(line); line = w; }
    else line = next;
  }
  if (line) out.push(line);
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") return new Response("Method not allowed", { status: 405, headers: cors });

  const auth = req.headers.get("authorization");
  if (!auth) return new Response("Owner sign-in required", { status: 401, headers: cors });

  const url = new URL(req.url);
  const state = (url.searchParams.get("state") || "").trim().toUpperCase() || null;
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const keys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") || "{}");
  const apiKey = keys.default || Deno.env.get("SUPABASE_ANON_KEY");
  if (!apiKey) return new Response("Publishable API key unavailable", { status: 500, headers: cors });

  const rpc = await fetch(`${supabaseUrl}/rest/v1/rpc/bridgepoint_owner_source_legal_manifest_v2160`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "apikey": apiKey,
      "Authorization": auth,
    },
    body: JSON.stringify({ p_state_code: state, p_limit: 5000, p_offset: 0 }),
  });
  const data = await rpc.json().catch(() => null);
  if (!rpc.ok || !data?.complete) {
    return new Response(JSON.stringify({ error: data?.message || data?.error || "Owner manifest unavailable" }), {
      status: rpc.status || 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const pdf = await PDFDocument.create();
  pdf.setTitle("BridgePoint Intelligence Source & Legal Evidence Manifest");
  pdf.setAuthor("BridgePoint Intelligence");
  pdf.setSubject("Operational source, provenance, rights, licensing and legal-evidence manifest");
  pdf.setKeywords(["BridgePoint Intelligence", "sources", "provenance", "licensing", "legal evidence"]);

  const regular = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
  const pageW = 612, pageH = 792, margin = 42;
  const black = rgb(0.08,0.10,0.12), muted = rgb(0.30,0.35,0.39), accent = rgb(0.05,0.45,0.52);
  let page = pdf.addPage([pageW,pageH]), y = pageH - margin;

  const newPage = () => { page = pdf.addPage([pageW,pageH]); y = pageH - margin; };
  const need = (h:number) => { if (y-h < margin) newPage(); };
  const line = (text:string, size=8, font=regular, color=black, indent=0) => {
    need(size + 4);
    page.drawText(text, { x: margin+indent, y, size, font, color, maxWidth: pageW-margin*2-indent });
    y -= size + 4;
  };
  const wrapped = (text:unknown, label?:string, color=black) => {
    const prefix = label ? label + ": " : "";
    const lines = wrap(prefix + String(text ?? ""), 108);
    for (const s of lines) line(s, 7.5, regular, color, label ? 8 : 0);
  };

  line("BRIDGEPOINT INTELLIGENCE", 10, bold, accent);
  line("Source & Legal Evidence Manifest", 19, bold, black);
  line(`Generated live: ${new Date(data.generated_at || Date.now()).toISOString()}`, 8, regular, muted);
  if (state) line(`State filter: ${state}`, 8, bold, muted);
  y -= 4;
  wrapped(data.legal_note || "Operational evidence; not legal advice.", "NOTICE", muted);
  y -= 6;

  const summary = data.summary || {};
  line(`Manifest rows: ${summary.legal_manifest_rows ?? 0}`, 9, bold);
  line(`Registered routes: ${summary.registered_routes ?? 0}`, 8);
  line(`Claims candidates: ${summary.claims_candidates ?? 0}`, 8);
  if (summary.rights_status_counts) wrapped(JSON.stringify(summary.rights_status_counts), "Rights status counts", muted);
  y -= 10;

  const sources = Array.isArray(data.sources) ? data.sources : [];
  sources.forEach((s:any, i:number) => {
    need(78);
    line(`${i+1}. ${s.source_name || s.source_key || "Source"}`, 9, bold, black);
    wrapped([s.provider, s.state_code, s.source_category, s.access_method].filter(Boolean).join(" · "), "Provider / scope", muted);
    wrapped(s.source_url, "Source URL");
    wrapped(s.evidence_url, "Evidence URL");
    wrapped([s.rights_status, s.activation_status].filter(Boolean).join(" · "), "Rights / activation");
    wrapped(s.allowed_use_scope, "Allowed use");
    wrapped(s.legal_basis, "Legal basis");
    wrapped(s.license_note, "License note");
    wrapped([s.last_checked_at ? "checked "+s.last_checked_at : null, s.snapshot_at ? "snapshot "+s.snapshot_at : null].filter(Boolean).join(" · "), "Evidence time", muted);
    y -= 7;
  });

  const pages = pdf.getPages();
  pages.forEach((p,idx) => {
    p.drawLine({ start:{x:margin,y:26}, end:{x:pageW-margin,y:26}, thickness:0.5, color:rgb(.78,.82,.84) });
    p.drawText(`BridgePoint Intelligence · live source/legal manifest · page ${idx+1} of ${pages.length}`, {
      x:margin, y:14, size:6.5, font:regular, color:muted
    });
  });

  const bytes = await pdf.save({ useObjectStreams: true });
  const filename = state ? `BridgePoint-Legal-Sources-${state}.pdf` : "BridgePoint-Legal-Sources.pdf";
  return new Response(bytes, {
    headers: {
      ...cors,
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="${filename}"`,
      "Cache-Control": "private, no-store",
      "X-BridgePoint-Manifest-Version": String(data.version || 2160),
    },
  });
});