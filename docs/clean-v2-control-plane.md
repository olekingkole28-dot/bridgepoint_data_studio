# BridgePoint Clean V2 control plane

The active application architecture is Clean V2 only.

Authoritative automated paths:
- `.github/workflows/flutter-web-v2-production.yml` — compile, analyze, test, and create the validated Clean V2 handoff.
- `.github/workflows/canonical-source-validation.yml` — source validation only.
- `.github/workflows/product-release-audit-v852.yml` — product release audit only.
- `.github/workflows/product-surface-audit.yml` — surface audit only.
- `.github/workflows/live-release-verification.yml` — independent live verification only.

Historical one-shot patch, restore, wire, visual-release, branch-recovery, and alternate-build workflows are retired. Product changes must be made in canonical Clean V2 source and pass the authoritative release build rather than being reapplied by self-mutating patch workflows.

Current UX contract:
- Primary customer navigation: Home / Map / Properties / Work.
- Plans is a prominent gold conversion action.
- Models, valuation formulas, source operations, Studio, and raw diagnostics are owner-only / Advanced.
- Property-specific imagery, evidence, timeline, risk, and Structure 3D are contextualized under Property.
- Customer surfaces must not dump raw backend payloads or formulas.
