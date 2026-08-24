# BridgePoint active AI coordination

Updated: 2026-08-24 (America/New_York)

## ChatGPT UI refresh worker
- Branch: `chatgpt/ui-refresh-v691`
- Scope: visual design system and Flutter presentation shell only — theme tokens, navigation chrome, cards, spacing, typography, responsive layout, dashboard presentation, and map/panel styling inspired by the approved dark BridgePoint mockups.
- Do **not** change: Supabase schema/RPCs, ingestion, scoring, national data, entitlements, auth behavior, acquisition logic, release provenance, or backend/service contracts.
- Do **not** publish directly from this branch or alter `main` app source during implementation.
- Before integration: refresh from current `main`, compare overlapping files, preserve newer functional changes, run analyze/tests/build, and merge only conflict-reviewed UI changes.

## National property parity / backend worker
- Scope: make non-CT property intelligence reach Connecticut-grade capability without changing the active UI-refresh work: national/state source discovery review, accepted-source ingestion/materialization, property-level signal/evidence attachment, aerial/property-media source coverage, property-detail backend contracts, save/workspace/CRM handoff verification, and parity/readiness measurement.
- Current verified baseline: shared property media/photo contribution, saved-property tracking, saved opportunities, CRM handoff preparation, and property timeline contracts are property-ID/state-aware; the main national gap is source/materialization depth and verified media coverage outside CT.
- Current CT benchmark observed in production: 25 signal families, 62 signal types, 12 source labels; most expanded states are still much thinner and must not be represented as CT-equivalent until materialized/verified.
- Do **not** broadly refactor `lib/main.dart`, theme tokens, navigation chrome, card/layout styling, responsive presentation, or other files owned by `chatgpt/ui-refresh-v691` while that worker is active.
- Do **not** merge, publish, reset, force-update, or alter `chatgpt/ui-refresh-v691`.
- Before any overlapping app-file edit: re-read this coordination file and recent commits; prefer backend/RPC/data work or a clearly isolated branch/commit. If UI wiring becomes operationally necessary, document exact files/functions here first so the UI worker can reconcile safely.
- Do not auto-activate unverified/rejected external sources merely to inflate source counts; preserve source attribution, matching precision, licensing/display constraints, and customer-safe evidence language.

## Other active workers
Continue current backend, national-demo, acquisition, release, and operational work on their existing branches/main. Please avoid broad formatting or theme refactors in `lib/main.dart` while this UI branch is active unless operationally necessary. If you must touch the same UI areas, leave a note in this file or use a clearly scoped commit so the UI worker can reconcile safely.

Goal: prevent AI workers from overwriting one another while the app is evolving quickly.
