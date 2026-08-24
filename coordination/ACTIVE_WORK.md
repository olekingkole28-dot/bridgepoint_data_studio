# BridgePoint active AI coordination

Updated: 2026-08-24 (America/New_York)

## Unified ChatGPT owner — UI refresh + national CT parity
The previous standalone UI-refresh chat was stopped by the user on 2026-08-24. This chat now owns both workstreams, but they remain intentionally isolated until integration and QA.

### UI refresh lane
- Branch: `chatgpt/ui-refresh-v691`
- Scope: visual design system and Flutter presentation shell only — theme tokens, navigation chrome, cards, spacing, typography, responsive layout, dashboard presentation, property-detail presentation, and map/panel styling inspired by the approved cleaner dark BridgePoint mockups.
- Preserve every newer functional capability from `main`, especially V690 national search/map/property-detail navigation, auth/onboarding behavior, owner controls, entitlements, field tools, media/photo contribution, save/workspace actions, CRM handoff, and release/audit hooks.
- Do **not** change Supabase schema/RPCs, ingestion, scoring, source activation, national data, entitlements, auth contracts, acquisition logic, release provenance, or backend/service contracts from this branch.
- Do **not** publish directly from this branch.
- Before integration: refresh/compare against current `main`, preserve newer functional changes, review every overlap, run analyze/tests/build, and merge only conflict-reviewed UI changes.

### National property parity / backend lane
- Scope: make non-CT property intelligence reach and then exceed Connecticut-grade capability: national/state source discovery review, accepted-source ingestion/materialization, address normalization/backfill, property-level signal/evidence attachment, aerial/property-media source coverage, property-detail backend contracts, property timelines, save/workspace/CRM handoff verification, and parity/readiness measurement.
- Current verified baseline: shared property media/photo contribution, saved-property tracking, saved opportunities, CRM handoff preparation, property timeline, and media bundle contracts are property-ID/state-aware; the main national gap is source/materialization depth, address normalization, physical-intelligence breadth, and verified media coverage outside CT.
- Current CT benchmark observed in production: 25 signal families, 62 signal types, 12 source labels. Most expanded states are still much thinner and must not be represented as CT-equivalent until materialized and verified.
- National target is not weather-only parity: properties should expose the same customer workflow as CT wherever evidence exists — searchable real address, property profile, current/front media when lawfully available, aerial/current/historical imagery references, option to contribute a front photo, save/watch/track actions, CRM handoff, chronological timeline, explainable signals/patterns/opportunities, and state-aware source attribution.
- Prioritize source families beyond solar/weather: assessor/tax, parcels, transfers/sales, permits, code/311, fire/emergency, FEMA/disaster/flood, environmental/release/UST/remediation, zoning/land-use, utilities/grid, wetlands/water, physical buildings/footprints/elevation/imagery, ownership/entity context, and other authoritative state/local sources where legally/display-safe.
- Do not auto-activate unverified/rejected external sources merely to inflate source counts. Preserve source attribution, matching precision, licensing/display constraints, evidence confidence, and customer-safe limitations.

## Integration rule
- Keep backend/data work off `chatgpt/ui-refresh-v691` unless a UI contract must be consumed there.
- Keep broad theme/layout work off `main` until the UI branch has been reconciled.
- Any operationally necessary overlap must be documented here first and committed in a narrowly scoped change.
- Never force-reset or overwrite another workstream. Compare current commits before merging.

## Other workers
No other ChatGPT worker is currently expected to own the stopped UI-refresh lane. If another worker resumes or leaves a new GitHub coordination note, re-read this file and recent commits before modifying overlapping areas.

Goal: one coordinated BridgePoint build where national property depth and the cleaner finished UI land together without regressions.
