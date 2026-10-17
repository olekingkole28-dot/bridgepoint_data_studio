# Contributing to BridgePoint Intelligence

Thanks for helping improve BridgePoint. Useful contributions include bug reports,
reproducible fixes, tests, documentation, accessible UI improvements, better source
provenance, performance work, and integrations with clearly documented data rights.

## Before opening a pull request

1. Search existing issues and pull requests first.
2. Explain the user problem, expected behavior, and how you tested the change.
3. Keep changes focused; avoid bundling unrelated refactors or giant generated artifacts.
4. Never commit credentials, private customer data, raw account exports, provider keys,
   local environment files, or data you do not have permission to redistribute.
5. For maps/property intelligence, keep the source, retrieval timestamp, match method,
   uncertainty, and limitations visible. Exposure is not confirmed damage.
6. For database changes, explain migration impact, required privileges/RLS policies,
   indexes, backfill/refresh behavior, and a rollback path.
7. For third-party assets/data, include the applicable licence, attribution, and provenance.

## Local development

The project is multi-repository and has different components rather than one universal
build command. Follow the README and component-specific instructions for the area changed.
For the Flutter app, install a compatible Flutter SDK, then run:

```bash
flutter pub get
flutter analyze
flutter test
```

Use a separate development database and test project. Do not run production deployment
workflows or apply migrations to production as a way to verify a pull request.

For static web/JavaScript components, run the relevant project smoke tests and inspect
the experience at both mobile and desktop widths. Do not add expensive map layers to
startup without testing load time and degraded-network behavior.

## Pull-request expectations

- Describe the change and why it matters.
- Link a related issue when there is one.
- Include test results and screenshots for visible UI changes.
- Note any external service, secret, licence, or migration prerequisites.
- State what is not tested or remains experimental.
- Do not claim a feature is production-ready based only on code presence.

## Project principles

- Prefer explainable evidence over unexplained scores.
- Preserve provenance and source limitations.
- Keep expensive optional layers opt-in when they affect performance.
- Treat private property/claim/customer information with care.
- Never present game/simulation objects as real-world observations.
