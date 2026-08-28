# BridgePoint Intelligence — Master Completion Source of Truth V960

Updated: 2026-08-27

This is the authoritative completion list for BridgePoint. It consolidates the founder's requirements from prior chats and current production debugging. The founder should not have to remember or restate requirements.

## Non-negotiable completion rule

A requirement is **DONE** only when all applicable layers are complete:
1. backend/data contract exists and is truthful;
2. entitlement/security is enforced;
3. customer UI is understandable without founder narration;
4. responsive phone/desktop behavior works;
5. production build compiles/tests;
6. the exact change is deployed to bridgepointintelligence.online/app/;
7. production behavior is verified with a normal customer account.

Source-only, branch-only, migration-only, or overlay-only changes are **not** full completion.

## P0 — Customer / investor readiness after Boroughs & Burbs

- [ ] Simplify the entire customer experience so a first-time user understands BridgePoint without Kole explaining it.
- [ ] Keep the core primary navigation small and obvious.
- [ ] Packages must be a primary visible tab on phone and desktop, not buried under More/Explore.
- [ ] Show each signed-in customer their current package, active geography, unlocked features, trial/access state, and upgrade options.
- [ ] Enforce package access server-side on every gated surface before data is returned.
- [ ] Never expose owner/admin controls, source code, private scoring weights, proprietary learning logic, or unrestricted backend access to customers.
- [ ] Replace backend codes/errors/payload language with plain-English customer explanations.
- [ ] Every score, signal, pattern, icon, timeline event, opportunity, map marker, and evidence object must answer: What is this? Why am I seeing it? Why does it matter? How confident is BridgePoint? How was it matched? What does it NOT prove?
- [ ] Preserve provenance/source links and evidence-first disclaimers without making the UI cluttered.
- [ ] Ensure investor-facing metrics distinguish product previews, real trials, paid customers, revenue, and directional platform counts.
- [ ] Keep founder/investor story and live verified company metrics truthful and current.

## P0 — Home / live operating pulse

- [ ] Home must visibly show the live U.S. property/parcel universe; no floating corner button as the primary presentation.
- [ ] U.S. parcel/property count must automatically update as ingestion changes the canonical universe.
- [ ] Show per-state parcel/property progress and state depth.
- [ ] Show live ingested/source-record count.
- [ ] Show live scored-property count.
- [ ] Show live detected-pattern count.
- [ ] Show live signal count.
- [ ] Show live active/qualified opportunity count.
- [ ] Show registered/healthy source count and source freshness summary.
- [ ] Show the system is actively ingesting/matching/scoring/patterning rather than presenting static vanity numbers.
- [ ] Refresh live metrics automatically without expensive repeated full-table counts.
- [ ] Owner Home/chrome must show signups, confirmed accounts, active users, sign-ins, trials, paid customers, revenue, and coarse sign-in/visitor geography.
- [ ] Customer screens must not expose other customers' identities or private analytics.
- [ ] Geography must be labeled accurately as coarse telemetry when it is not verified account location.
- [ ] Restore the useful always-visible progress feel of the earlier app while keeping the new UI clean.

## P0 — Property search / Property 360

- [x] Fix canonical displayed-address search so a property the UI displays can be found by that address in the backend contract.
- [x] Remove unnecessary opportunity-ranking dependency from base address lookup.
- [x] Repair indexed municipality lookup path.
- [x] Repair CT Buildings search to use canonical property suggestions for full address / parcel searches.
- [ ] Support forgiving partial address/street/owner/parcel/municipality search without timeouts.
- [ ] Autocomplete property search as the user types.
- [ ] Make property lookup U.S.-wide according to the user's entitled states/geographies, not Connecticut-only.
- [ ] Property 360 must not fail because one optional submodule is unavailable.
- [x] Register missing usage-meter product keys that caused Property 360 climate/digital-twin calls to throw Unknown product_key.
- [x] Verify normal-customer CT property detail returns real property intelligence.
- [x] Verify normal-customer CT climate profile returns without product-key failure.
- [x] Verify normal-customer CT Digital Twin summary returns without product-key failure.
- [x] Verify a real CT property can return source-backed 2023 building footprint geometry.
- [ ] Property 360 should load modules progressively and show partial success instead of one generic unavailable state.
- [ ] Add customer-readable retry/status per property module.
- [ ] Make the first property view a concise summary, with deeper evidence/details progressively disclosed.
- [ ] Property DNA/timeline must connect records, changes, weather, permits, sales, imagery, risk, signals, patterns, scores, and opportunities chronologically.
- [ ] Direct source record links should be available when legally/technically usable.
- [ ] Notes, presets, follow-up dates, watchlists, saved opportunities, and sharing should work from property detail.

## P0 — Timeline / explainability

- [x] Timeline backend now returns customer-reading guidance and plain-English explanation fields.
- [x] Timeline backend distinguishes direct model evidence from contextual evidence.
- [x] Timeline confidence text explains confidence is source/match quality, not probability of damage or conversion.
- [x] Timeline limitations explicitly state what an item does not prove.
- [ ] Deploy the improved timeline drill-down UI to production.
- [ ] Tapping any timeline item must open a detail view: What happened / Why it matters / Evidence level / Match method / Confidence / Models using it / Source / Limitations / Open source record.
- [ ] Add a simple in-context legend for Signal vs Pattern vs Opportunity.

## P0 — Map usability / icons

- [ ] Deploy the corrected customer map source to the live Flutter bundle.
- [ ] Every property, signal, opportunity, weather, cluster, and other marker type must be tappable.
- [ ] Replace generic/confusing markers with recognizable category icons.
- [ ] Roofing opportunities use roof icon.
- [ ] Storm/hail/wind use storm icon.
- [ ] Fire uses fire icon.
- [ ] Flood/water uses water icon.
- [ ] Solar uses solar icon.
- [ ] Sales/transfer/investor uses real-estate icon.
- [ ] Development uses construction icon.
- [ ] Permit uses permit/fact-check icon.
- [ ] Keep distinct priority/score styling while explaining what color/border means.
- [ ] Add prominent "What am I seeing?" map legend/key.
- [ ] Tapping a marker must explain what it is, why it matters, evidence level, confidence, source/match, score/priority if relevant, and limitation.
- [ ] Keep map readable by clustering/limiting visible markers without hiding important intelligence.
- [ ] Satellite / street-map switching must work.
- [ ] Optional map layers should be package-aware.
- [ ] Locked/non-entitled states should be clearly visible as locked/available-to-add rather than appearing broken.
- [ ] Start customers in their entitled/default geography while allowing purchased multi-state access.
- [ ] Owner can inspect full U.S. coverage.

## P0 — NOAA radar / weather

- [ ] Deploy the corrected radar implementation to the live Flutter bundle.
- [ ] Radar opens on the latest NOAA MRMS frame and stays there by default.
- [ ] Radar animation starts only when the user presses Play.
- [ ] Slow animation enough for tiles to render reliably on mobile.
- [ ] Animation advances forward and stops at latest instead of endlessly looping to stale frames.
- [ ] Show timestamp/frame position/slider.
- [ ] Radar must remain available at property-level zoom instead of intentionally disappearing above a zoom threshold.
- [ ] Gracefully fall back to latest WMS imagery if time-frame discovery temporarily fails.
- [ ] Radar/weather feature must obey package entitlement (weather_intelligence) rather than being globally assumed.
- [ ] Explain radar freshness/source in plain English.
- [ ] Preserve live severe-weather/property context and automatic storm ingestion.

## P0 — Buildings / 2D / 3D / Digital Twin

- [x] CT canonical full-address Buildings search repaired at backend contract level.
- [x] Verified real CT source-backed 2023 footprint returned for a customer property.
- [ ] Deploy repaired Buildings/property search experience to production.
- [ ] Clearly distinguish 2D footprint, L0 property shell, L1 schematic massing, higher-fidelity source geometry, and future photorealistic/semantic models.
- [ ] Never claim schematic massing is an exact replica, scan, BIM model, or engineering survey.
- [ ] Show source/provider/year/match confidence/fidelity/provenance.
- [ ] State readiness must show 2D/3D counts and status honestly.
- [ ] Continue national building footprint/height/geometry materialization.
- [ ] Ingest/associate historical aerial imagery, LiDAR, source geometry and other authorized physical layers where available.
- [ ] Derive roof change, additions/removals, solar change, pool/site/vegetation change, redevelopment/demolition where evidence supports it.
- [ ] Future Digital Twin simulations: thermal/window, water pooling, flood/site flow, wind/envelope only when minimum fidelity/evidence supports the claim.

## P0 — Packages / billing / entitlements

- [ ] Rename customer-facing Plans wording to Packages where the founder requested Packages.
- [ ] Packages is visible in primary phone navigation.
- [ ] Packages & Access is visible in primary desktop navigation/sidebar.
- [x] Packages source reads bridgepoint_customer_plans_v944.
- [x] Packages source reads bridgepoint_customer_access_contract_v318.
- [x] Stripe production readiness previously verified green; preserve and continuously re-check.
- [ ] Show current package prominently above purchase catalog.
- [ ] Show exactly which features/geographies are currently unlocked.
- [ ] Show unavailable capabilities with reason + upgrade path instead of generic errors.
- [ ] Never guess access if the access contract is unavailable; show verification/retry state.
- [ ] Server-side package/geography enforcement on every feature.
- [ ] 7-day account preview/trial behavior must be clearly labeled and not falsely counted as real buyer trial unless backed by actual commercial billing truth.
- [x] Commercial funnel repaired so free account previews are not counted as real buyer trials.
- [ ] Preserve founder/operator platform override / free All Intelligence access without leaking override behavior to customers.
- [ ] Support package changes/upgrades/downgrades/cancellation/billing portal.
- [ ] Support homeowner, contractor/pro, business/company, combined/multi-user, All Intelligence, Enterprise and custom intelligence packaging according to the active catalog.
- [ ] Support multi-state packages/state add-ons and future country/global expansion products.
- [ ] Support Immediate Access / Founding Early Access / Managed Activation states where appropriate.
- [ ] Keep high-touch enterprise/custom/top-tier purchases owner/sales-approved where self-checkout is inappropriate.

## P0 — Release / deployment integrity

- [ ] Fix private-repo native Flutter build path; current private GitHub jobs are created but receive no runner/steps/logs.
- [ ] Remove obsolete build assertions that require 2600ms radar autoplay and older navigation.
- [ ] Build/test/analyze the actual customer-ready Flutter source.
- [ ] Produce immutable compiled release metadata with source SHA and digests.
- [ ] Promote the exact compiled customer-ready release into the durable bridgepoint-live live-artifact.
- [ ] Ensure public promotion workflow is not pinned forever to an obsolete Supabase Storage release archive.
- [ ] Verify production /app/ exact release SHA after promotion.
- [ ] Preserve PWA assets/icons/service worker/install flow.
- [ ] Avoid regressions from stale service-worker caches; version/update strategy must force new customer releases when required.

## P1 — National / global expansion engine

- [ ] U.S.-wide—not CT-only—property foundation and customer product architecture.
- [x] Public parcel counter currently represents all 50 states + D.C. with progressive depth.
- [ ] Keep state-by-state completeness/readiness percentages and source depth truthful.
- [ ] Continue automatic parcel acquisition for weak/incomplete states including county fallback where statewide sources are inadequate.
- [ ] Maintain official county/county-equivalent target universe and automated county source discovery.
- [ ] Parallelize large state parcel acquisition safely.
- [ ] Automatic source discovery, validation, ingestion, normalization, canonical property matching, evidence linking, signals, patterns, scoring, opportunities and app propagation.
- [ ] Every dataset must flow ingest → normalize/match → evidence/signals → patterns → scoring → opportunities → customer UI automatically.
- [ ] No manual scoring/pattern job should be required for normal source refresh.
- [ ] Self-heal when external source URLs/endpoints/schema change; maintain alternates/fallbacks and source revalidation.
- [ ] Automatic refresh cadence appropriate to source volatility.
- [ ] One-button U.S. expansion controls for owner.
- [ ] One-button country/global expansion framework with country-specific adapters, legal/data-rights checks and controlled rollout.
- [ ] Never pretend a geography is complete when depth is partial.

## P1 — Sources / intelligence depth

- [ ] Parcel/assessor/CAMA/property foundations.
- [ ] Ownership/sales/property transitions.
- [ ] Permits/building/code/fire/public-safety records where available.
- [ ] 311/SeeClickFix/local issue records.
- [ ] NOAA/NWS weather and severe-weather observations.
- [ ] FEMA declarations, NFHL/floodway/base-flood and relevant hazard context.
- [ ] Environmental spills/UST and other high-value environmental sources.
- [ ] Fire incidents.
- [ ] Imagery/LiDAR/building footprints/physical change.
- [ ] Solar signals.
- [ ] Claims/insurance-relevant signals only within legal/licensing/data-rights boundaries.
- [ ] Add other high-value property/public sources automatically as discovered and validated.
- [ ] Source registry must expose freshness, health, trust, geography, rights/provenance and fallback state to owner.

## P1 — Patterns / scoring / opportunities

- [x] Pattern backend exists in production; surface it appropriately instead of making founder think it disappeared.
- [ ] Home live pattern count.
- [ ] Owner pattern-engine health/backlog/runs/geography.
- [ ] Customer-facing patterns only where package permits, with plain-English explanation/evidence.
- [ ] Tighten scoring to avoid useless ties and excessive lead volume.
- [ ] Negative/contradictory evidence dampening.
- [ ] Explain top contributing signal/pattern families without exposing proprietary raw weights.
- [ ] Score history/movement/timeline.
- [ ] Opportunity dedupe.
- [ ] Opportunity why-now / why-surfaced / evidence gate explanation.
- [ ] Priority and confidence must be understandable.
- [ ] Feedback/outcome learning loop should improve models without contaminating truth labels.
- [ ] Custom model builder / marketplace remains part of the platform vision with entitlement controls.

## P1 — Saved work / field workflow

- [ ] Saved properties/opportunities/watchlists.
- [ ] Alerts and digests.
- [ ] Phone/computer notifications with customer controls.
- [ ] Notes with presets/custom notes/follow-up dates.
- [ ] Calendar.
- [ ] Routes/field planning/top houses/doorknocking workflow.
- [ ] Company teams, owner/co-owner/manager/supervisor/seat roles.
- [ ] Optional consent-based field/team location visibility—not hidden surveillance.
- [ ] Shared company workspaces where package allows.
- [ ] Daily brief / "what changed overnight".
- [ ] Welcome experience personalized by account without exposing founder initials/avatar to other users.

## P1 — Settings / support / accessibility

- [ ] Light/dark/system appearance where supported.
- [ ] Larger text.
- [ ] High/strong contrast.
- [ ] Reduced motion.
- [ ] Simplified views.
- [ ] Hide/show optional elements/layers.
- [ ] Account/profile customization.
- [ ] Correct per-user avatar/profile identity; no global KJ initials leakage.
- [ ] Password visibility toggle.
- [ ] Password reset/recovery.
- [ ] Optional walkthrough/onboarding; founder/admin bypass.
- [ ] Onboarding questions recommend best package without trapping the user.
- [ ] Help/FAQ.
- [ ] Legal & Trust Center / privacy/security/data-use explanations.
- [ ] Suggestions/feedback/bug reporting/data-source requests.
- [ ] Share links where package/security permits.

## P1 — Owner/admin operations center

- [ ] Live signups, confirmed users, sessions, active users, user pages/activity and coarse geography.
- [ ] Trial/preview/paid truth separated.
- [ ] Revenue/MRR/ARR/Stripe health where data exists.
- [ ] New signup notification to owner.
- [ ] Ingestion throughput and live counts.
- [ ] Scoring throughput/backlog.
- [ ] Pattern throughput/backlog.
- [ ] Opportunity throughput.
- [ ] Source health/errors/retries/freshness.
- [ ] Expansion state/county/source progress.
- [ ] Automated-worker health and queues.
- [ ] Database/compute/disk/I/O health and alerts.
- [ ] Backup/export health.
- [ ] Customer package/entitlement support tools.
- [ ] Error log should identify customer-visible breakage before founder has to report it.

## P1 — Export / backup / portability

- [ ] Full platform data export where legally allowed.
- [ ] Per-state export after/while states reach sufficient readiness.
- [ ] Export property universe, evidence/signals/patterns/scores/opportunities/source/provenance in practical formats.
- [ ] Spreadsheet-compatible state exports for free/offline backup workflows.
- [ ] Full archive suitable for local computer/USB/external drive.
- [ ] Code/config/migrations/source registry backup.
- [ ] Operator account backup/recovery path.
- [ ] Preserve ability to reduce vendor dependence / migrate away from Supabase if needed while respecting auth/security/data volume realities.

## P1 — Customer acquisition/product conversion surfaces

- [ ] Public landing page explains BridgePoint before forcing account creation.
- [ ] Clear sign-in/create-account paths.
- [x] Email-confirmation guidance added to live shell after podcast signup friction.
- [ ] Customer signup flow must not encourage repeated resend/sign-in attempts that trigger auth rate limits.
- [ ] Pricing/package CTA visible and clear.
- [ ] Free trial/preview wording truthful.
- [ ] Sample/territory preview where appropriate.
- [ ] Customer screenshots/demo surfaces must show live value, not backend complexity.
- [ ] PWA install/download button works on supported phone/computer browsers.
- [ ] Mobile layout must not produce elongated/broken cards or clipped labels.
- [ ] Public site/app URLs/metadata should validate on major social platforms.

## P1 — Investor / enterprise readiness

- [ ] Live investor view driven by verified metrics, with audited-vs-directional distinctions.
- [ ] Company/investment story, problem, moat, market, architecture and scaling plan understandable quickly.
- [ ] Partnership/investment materials must explain data rights, privacy, security, provenance, package access, IP boundaries and enterprise deployment options.
- [ ] Blockchain/public-ledger ideas should be evaluated for concrete provenance/verification use cases rather than added as hype.
- [ ] Enterprise/API/private deployment/white-label options must protect core IP.
- [ ] Prove customer pilots/outcomes and commercial traction as they appear.

## Current verified production/backend truths from this completion pass

- Public U.S. parcel universe counter: ~44.4M records across all 50 states + D.C.; progressive depth varies substantially by state.
- Live system-pulse backend contract: v957.
- Owner live activity backend contract: v958.
- CT Buildings search repair / customer property contract repair: v959.
- Pattern engine production tables are present and populated; pattern UI visibility is the issue, not absence of backend patterns.
- Normal-customer CT property detail, climate profile, Digital Twin summary and source-backed 2D geometry have been verified after v959 contract repairs.
- Customer-ready Flutter source contains the intended paused-latest radar / tappable explanatory map direction, but that source is not yet the verified production bundle.

## Work-order rule

Work in this order unless a production outage demands otherwise:
1. customer-visible breakage and release path;
2. Home/live operating pulse;
3. search / Property 360 / timeline / Buildings;
4. map / radar / packages/access;
5. national data visibility + patterns/scoring/source progress;
6. owner analytics and commercial truth;
7. saved/team/settings/support/accessibility;
8. national completion, exports/backups, global expansion;
9. investor/enterprise enhancements.

Every new founder request should be added here automatically and should not require the founder to remember prior requests.
