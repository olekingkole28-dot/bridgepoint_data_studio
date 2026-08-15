# BridgePoint Intelligence

Live Connecticut property intelligence, automated opportunity scoring, evidence-backed maps, packages, pricing, and system health.

## Live product rules

- Every customer starts with a seven-day All Intelligence trial.
- The first ten non-founder customers receive 50% off their selected package for their first six paid months.
- `olekingkole28@gmail.com` is the founder allowlist account and receives permanent All Intelligence owner access when it signs up.
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

- Supabase production migrations: applied and verified
- Automated jobs: active
- Recent worker failures at release: zero
- Flutter source: interactive live workspace with two-minute refresh, details, category map icons, and settings
- Payment checkout: requires the production billing provider connection before accepting real payments
