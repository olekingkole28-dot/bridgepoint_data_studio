# BridgePoint Intelligence — open-source scope

## What it is

BridgePoint Intelligence is a geospatial and property/claims-intelligence platform.
It connects property identity and location with physical-world context, records and
events, source provenance, evidence, and explainable operational workflows. The aim
is to help people investigate a place and understand why a signal appears, where the
supporting information came from, and what still needs verification.

It is not a substitute for professional inspection, claim adjudication, legal advice,
or source-owner permission. Weather exposure is context, not proof of property damage.
A model score or “verified” platform status is not a guarantee of coverage, loss,
payment, physical condition, customer intent, or commercial outcome.

## What is in the source repositories

### `bridgepoint-live` — public web and data-workflow repository

- Web pages, JavaScript and CSS for the public site and product surfaces.
- 3D globe/map experiences, property lookups, map overlays, and related UI.
- Public research pages, product guides, press/discovery content, and machine-readable
  product facts.
- Claims-lifecycle public terminal, its JSON/feed/OpenAPI surfaces, and public utilities.
- Supabase Edge Functions, SQL migrations, data contracts, and source-refresh logic.
- Python/JavaScript scripts, tests, build/release automation, and GitHub Actions workflows.
- The separate BridgePoint Horizon simulation/game experiments and their asset notices.

### `bridgepoint_data_studio` — companion Flutter application repository

- Flutter/Dart application and product screens.
- The 3D world/web integration and property, opportunity, claims, valuation, and
  operations surfaces.
- Supabase Edge Functions, SQL migrations, data contracts, and ingestion/refresh workers.
- Application tests, configuration, and deployment workflows.

The repositories are related but are not a single turnkey deploy. The Flutter client,
static web surfaces, Supabase database/functions, scheduled workers, source providers,
and deployment pipelines have distinct requirements.

## What is not included by publishing source code

- Live production database rows, customer data, private account/activity records, or
  other non-public operational information.
- Secret keys, signing keys, passwords, service-role credentials, and private tokens.
- Paid or access-controlled data, imagery, maps, API access, or provider entitlements.
- Any third-party material whose licence or terms do not permit redistribution.
- A guarantee that all source providers, external integrations, or production workflows
  are currently active, authorized, or reproducible from a clean checkout.

A connector's presence does not prove that every record from its upstream source may be
redistributed. Keep provenance, refresh time, licence/terms, and known limitations attached
to data; publish aggregate examples only when the source terms permit it.

## Licensing

First-party code and documentation are offered under Apache License 2.0 (see LICENSE).
Apache-2.0 includes conditions, warranty/liability limitations, and an express patent
grant. It does not grant rights to third-party materials, BridgePoint trademarks, or
external data. Existing per-directory licences and attribution notices continue to apply.

## Safe setup and deployment principles

1. Start with a separate development Supabase project. Never point experimental migrations
   or workflows at production by default.
2. Use environment variables or the hosting provider's secret store for credentials.
   Never put service-role keys in Flutter/web client code, issues, docs, or commits.
3. Apply migrations only after reviewing their effects, privileges, row-level security,
   and rollback strategy in a disposable database.
4. Enable only the workers and source connectors for which you have access rights and a
   clear rate-limit/refresh policy.
5. Validate map/property matches and data freshness before describing a record as verified.
6. Review each third-party asset's own licence/attribution file before redistribution.

## Public source status

Both the web/data-workflow repository and the companion Flutter repository are currently
public on GitHub. The source code can be inspected and forked under the licences that apply
to each file and directory. This is not equivalent to publishing the production service:
live database rows, account/customer data, provider entitlements, secret values, and
third-party datasets or imagery are not included by the source licence. Deployment still
requires environment-specific configuration, authorized upstream access, and a security
and asset review before production use.


## Useful links

- Live product: https://bridgepointintelligence.online/
- Web/data-workflow repository: https://github.com/olekingkole28-dot/bridgepoint-live
- Companion Flutter repository: https://github.com/olekingkole28-dot/bridgepoint_data_studio
- Security reporting: https://bridgepointintelligence.online/.well-known/security.txt
