# Global Offline World — Flutter Companion Checkpoint 1

## Current state inspected
- Flutter app currently depends on `flutter_map`, `http`, `shared_preferences`, and Supabase.
- Existing offline route workflow stores a small route working set in SharedPreferences. That is appropriate only for small records, not multi-gigabyte map packs.
- The web 3D world uses CesiumJS; native Flutter maps are a separate path and must consume the same versioned pack manifest without assuming identical rendering APIs.

## Required implementation
1. Use a platform-specific persistent file store for large archives (Android/iOS/desktop), not SharedPreferences.
2. Use IndexedDB/Cache Storage for Flutter Web or a browser-compatible adapter.
3. Share the manifest contract with `bridgepoint-live/rebuild-v5000/offline-world-v1.js`: schemaVersion, id, version, title, resources, expected bytes, generatedAt, source, licence, and optional checksums.
4. Use resumable chunk/range downloads where the hosting server supports them. Verify checksums before marking a pack installed.
5. Keep private/customer data separate from public geographic packs and enforce sign-out policy explicitly; do not blindly clear public offline packs on sign-out.
6. Add a storage-management UI with progress, cancellation, pause/resume, retry, remove, and last-updated metadata.
7. Only mark the app offline-capable after a cold-start airplane-mode test on Android and web.

## Checkpoint order
- C1: shared manifest and storage contract.
- C2: native file-backed pack manager and Flutter Web adapter.
- C3: map source adapter and global starter pack.
- C4: region-level detail packages.
- C5: offline sync/conflict handling for field workflows.
- C6: secure direct device-to-device exchange; multi-hop mesh is a separate project.

## Data rights and scale
The 412M+ canonical property identity count does not imply a global bundle of 412M parcel polygons or 3D buildings. Geometry and source rights vary by region. Every downloadable source needs provenance, date, licence/redistribution approval, and freshness semantics. The global overview should be compact; maximum detail is delivered through large optional regional packages.
