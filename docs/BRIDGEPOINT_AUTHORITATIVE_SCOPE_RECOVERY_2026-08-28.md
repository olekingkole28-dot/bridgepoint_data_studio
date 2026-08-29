# BridgePoint authoritative scope recovery — 2026-08-28

This file is a durable scope anchor so BridgePoint requirements do not depend on one chat thread.

## Authority order

1. **BRIDGEPOINT MASTER LOCK — AUGUST 18, 2026** — prior conversation identified this as the authoritative consolidated product scope with **47 locked sections**. It superseded older giant “everything” lists. The exact 47 section text has not yet been recovered verbatim into a file; do not invent missing section text.
2. **THE REMAINING LIST** — prior conversation identified this as the execution/finish order immediately following the Master Lock. Recovered order:
   1. loading failures
   2. county job failures
   3. security / RLS
   4. indexing / performance
   5. navigation
   6. reliable actions / no dead buttons
   7. progressive loading
   8. analytics
   9. backend exposure in UI
   10. Next Best Action / Outcome Learning
   11. visual polish
   12. legal / trust
   13. socials / growth
   14. Stripe / purchase completion
3. **BridgePoint Launch Guide** — customer-facing minimum product promise.
4. **BridgePoint Master Launch, Sales & Operations Manual** — launch, billing, QA, demo and operations truth.
5. Current production truth and guarded release tests override stale version numbers or stale “already done” claims in old documents.

## Customer-facing minimum product promise recovered from Launch Guide

BridgePoint must provide:
- property-linked signals with source, provider, date, match method, confidence and limitations;
- strict opportunity scoring with direct-evidence requirements, negative scoring and duplicate protection;
- property timelines;
- color-coded maps and working live radar;
- search suggestions, alerts and notifications;
- saved opportunities, notes, preset outcomes, calendar, routes and field workflows;
- company teams, owner/co-owner controls, optional consent-based field tracking and plan management;
- owner/founder operations center for signups, active users, revenue, trials, data jobs, sources and queues.

The standard demo path is:
1. Welcome / Daily Brief / what changed.
2. Strict opportunity with direct evidence, source, timing, match, confidence, limitations and negative-scoring protection.
3. Property timeline / full property story / saved state / recommended actions.
4. Map + radar with color-coded categories, locked states, live coverage, and a clear distinction between area context and direct property evidence.
5. Workflow actions: save, note, assign, calendar, routes/door-knocking/company controls.
6. Recommended plan, trial, plan-change controls and purchase path.

## QA rules recovered from Master Operations Manual

Before a release is considered good:
- guarded release markers pass;
- compile/static checks pass;
- automated tests pass where present;
- dead/no-op click-handler audit passes;
- intentionally unavailable actions are visibly labeled rather than silently failing;
- owner-only controls stay hidden from customer preview;
- package buttons reflect backend checkout readiness;
- Stripe success/cancel paths are handled;
- every package shows the correct delivery/purchase-mode disclosure;
- authenticated Settings purchase/billing data loads;
- map/property/detail pages are responsive on mobile and desktop;
- Supabase security/performance advisors are reviewed after schema changes;
- top RPCs are checked for avoidable full scans/missing indexes;
- the **actual production domain** is verified after deployment, not just the build artifact.

## 2026-08-28 production incident / recovery rule

The v999 web navigation attempted to open Properties/Worth/More by locating Flutter accessibility/semantic nodes. That approach could pass a mocked test while failing on a real Android session with “Could not open … Try again.” Do not reintroduce semantic-node/programmatic tab navigation as the primary mobile navigation path.

v1000 recovery direction:
- Home uses the web production dashboard while preserving the actual Flutter bottom navigation strip;
- Properties/Worth/More use trusted native Flutter taps;
- Map hides Flutter and uses the BridgePoint map runtime;
- language/sign-in entry is triggered from the public landing page’s Open BridgePoint action, not forced on every app open;
- Home web UI is allowed to paint before the heavy Flutter bundle;
- NOAA radar uses the official MRMS ImageServer Export Image operation, not the prior invisible `layers=0` WMS request;
- radar CI must download/decode a live NOAA PNG and require meaningful non-transparent colored pixels before promotion.

## Do not lose these architectural requirements

- Automatic ingestion and refresh for every supported source.
- Normalize → property/geography match → signal → score → patterns/opportunities → UI propagation.
- Nationwide expansion must be truthful by state/geography and quality-gated.
- Locked/available states must not be presented as fully active when their underlying intelligence is incomplete.
- Source provenance, confidence, match method, evidence and limitations remain visible/explainable.
- Customer package/role/state entitlements are server-side truth, not client-only button state.
- Owner/admin telemetry must not bleed into customer Home.
- No regression may disable stable backend ingestion merely to fix UI.
- Releases require real-device/user-visible behavior where feasible; mocked DOM tests alone are insufficient for mobile navigation or rendering claims.

## Recovery status

The exact text of the 47 Master Lock sections and any earlier >1,000-item raw list still needs verbatim recovery if a copy exists. Until then, this file is an **index and guardrail**, not permission to replace or shrink the locked scope.