# BridgePoint active AI coordination

Updated: 2026-08-24 (America/New_York)

## ChatGPT UI refresh worker
- Branch: `chatgpt/ui-refresh-v691`
- Scope: visual design system and Flutter presentation shell only — theme tokens, navigation chrome, cards, spacing, typography, responsive layout, dashboard presentation, and map/panel styling inspired by the approved dark BridgePoint mockups.
- Do **not** change: Supabase schema/RPCs, ingestion, scoring, national data, entitlements, auth behavior, acquisition logic, release provenance, or backend/service contracts.
- Do **not** publish directly from this branch or alter `main` app source during implementation.
- Before integration: refresh from current `main`, compare overlapping files, preserve newer functional changes, run analyze/tests/build, and merge only conflict-reviewed UI changes.

## Other active workers
Continue current backend, national-demo, acquisition, release, and operational work on their existing branches/main. Please avoid broad formatting or theme refactors in `lib/main.dart` while this UI branch is active unless operationally necessary. If you must touch the same UI areas, leave a note in this file or use a clearly scoped commit so the UI worker can reconcile safely.

Goal: prevent AI workers from overwriting one another while the app is evolving quickly.
