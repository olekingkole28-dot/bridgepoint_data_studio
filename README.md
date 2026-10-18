# BridgePoint Intelligence — Flutter application


> **BridgePoint Data Studio is the application companion to BridgePoint Intelligence**, a globe-scale geospatial platform building an explorable **3D digital twin of the entire globe**. The platform currently reports **412M+ canonical property records worldwide**. That canonical identity count is distinct from parcel polygons and does not imply every region has complete 3D buildings, owner details, or equally deep source coverage. The app connects interactive mapping with property intelligence, weather/hazard signals, and evidence-oriented workflows—where data is available and authorized.
>
> 🌎 **Explore the live platform:** https://bridgepointintelligence.online/
> 
> 🌐 **Main web/data repository:** https://github.com/olekingkole28-dot/bridgepoint-live

## What this repository contains

- Flutter/Dart application and product screens
- App-specific globe, map, and spatial-data integration
- Supabase functions and database migrations
- Release and automation workflows

## Important boundaries

The application source is not the same as a complete production deployment. Production records, secrets, paid provider access, third-party datasets, and deployment-specific configuration are not included by the source-code licence. Geographic coverage, geometry detail, and available intelligence vary by region. Review [OPEN_SOURCE_SCOPE.md](OPEN_SOURCE_SCOPE.md), [NOTICE](NOTICE), and [SECURITY.md](SECURITY.md) before deploying.

**Search terms:** Flutter GIS, global 3D digital twin, digital twin of Earth, entire-globe mapping, 3D globe, global geospatial intelligence, geospatial application, open-source GIS, canonical property records, property intelligence, property data, spatial intelligence, Supabase GIS, building footprints, parcel data, building geometry, 3D terrain, weather and hazard mapping, physical-world AI.

---


> **Open-source release preparation:** this repository contains the Flutter/Dart application, product screens, app-specific world integration, Supabase functions/migrations, and release automation. It is licensed under Apache-2.0 for first-party code and documentation, subject to the boundaries in [NOTICE](NOTICE) and [OPEN_SOURCE_SCOPE.md](OPEN_SOURCE_SCOPE.md). Both the web/data-workflow repository and this Flutter companion repository are now public. See [OPEN_SOURCE_SCOPE.md](OPEN_SOURCE_SCOPE.md) for the boundaries: public source code does not include production database contents, credentials, third-party datasets, or external provider entitlements.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidance and [SECURITY.md](SECURITY.md) for responsible vulnerability reporting. External data, production records, provider access, credentials, and third-party assets are not granted by the source-code licence.

Live Connecticut property intelligence, automated opportunity scoring, evidence-backed maps, packages, pricing, and system health.

## Live product rules

- Every customer starts with a seven-day All Intelligence trial.
- The first ten non-founder customers receive 50% off their selected package for their first six paid months.
- Founder/owner access is configured through the deployment's authentication and entitlement rules. For deployment, verify that privileged access is enforced server-side and that no private account identifiers or privileged credentials are exposed in client-visible paths.
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
