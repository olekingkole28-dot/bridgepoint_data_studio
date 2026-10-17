# BridgePoint Intelligence — Flutter application

> **Open-source release preparation:** this repository contains the Flutter/Dart application, product screens, app-specific world integration, Supabase functions/migrations, and release automation. It is licensed under Apache-2.0 for first-party code and documentation, subject to the boundaries in [NOTICE](NOTICE) and [OPEN_SOURCE_SCOPE.md](OPEN_SOURCE_SCOPE.md). The full multi-repository source release is not complete while this repository remains private.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidance and [SECURITY.md](SECURITY.md) for responsible vulnerability reporting. External data, production records, provider access, credentials, and third-party assets are not granted by the source-code licence.

Live Connecticut property intelligence, automated opportunity scoring, evidence-backed maps, packages, pricing, and system health.

## Live product rules

- Every customer starts with a seven-day All Intelligence trial.
- The first ten non-founder customers receive 50% off their selected package for their first six paid months.
- Founder/owner access is configured through the deployment's authentication and entitlement rules. Before a public release, verify that privileged access is enforced server-side and that private account identifiers are not hard-coded into client-visible paths.
- The workspace refreshes automatically and reads modern V36/V37/V38 intelligence engines.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

The client contains only the Supabase publishable key. Never add a service-role or secret key to Flutter.

## Database

The applied migrations are retained in `supabase/migrations`. V59 through V63 provide runtime settings, pricing/trials, security hardening, health cleanup, the founding-customer offer, founder provisioning, and the private owner dashboard.

## Release status

- Supabase migrations are retained in `supabase/migrations`; the applied database state is environment-specific.
- GitHub Actions workflows and ingestion/refresh workers are included, but enabling them requires an isolated development environment, appropriate permissions, secrets, source licences, and rate-limit controls.
- The Flutter source is provided for local inspection and development; a clean checkout does not recreate production data or deployment secrets.
- Checkout and real payments require a separately configured, authorized billing-provider connection; source code alone does not activate billing.

Do not run migrations or deployment workflows against production to validate a pull request. Start with a separate development Supabase project and review the applicable migration/workflow first.
