# Global Offline World — Flutter Companion Checkpoint 1

## Current integration
- The Clean V2 app now exposes **Offline World** in its Explore menu.
- Android/iOS/macOS use a platform WebView that opens the same-origin `/offline/` package UI. Downloaded public packs are held by that WebView's browser storage (Cache Storage + IndexedDB), not the app's SharedPreferences.
- Flutter Web embeds the same-origin `/offline/` page in an iframe, reusing the browser's service worker and storage origin.
- Other native desktop platforms get an explicit browser handoff rather than a false promise that the embedded map is available.

## Global pack contract
- `global-boundaries-v1`: around 7.9 MB; worldwide Natural Earth land/country outlines at 110m, 50m and 10m scales.
- `global-basemap-z6-v1`: around 45–50 MB, zoom 0–6 planet-wide vector basemap.
- `global-max-v1`: around 190–220 MB target, zoom 0–7 planet-wide vector archive plus country/land boundaries, local fonts and sprites. The build records exact size, source date and SHA-256. CI rejects an archive above 700 MB.
- All estimates are shown before download; actual reported bytes are retained after install. Browser quota limits vary by platform.

## Limits that must remain explicit
- Global max provides higher-detail global map context, but not universal parcel polygons, complete high-resolution 3D buildings, worldwide LiDAR, universally redistributable imagery or live feeds.
- Detailed buildings, parcel lines, high-resolution terrain, LiDAR and imagery need independently licensed regional packages.
- Cached alerts/weather must show their source timestamp and stale status when offline. Offline map downloads alone do not implement a Bluetooth/Wi-Fi multi-hop emergency mesh.

## Remaining verification
- CI must resolve Flutter dependencies and compile the Clean V2 web build.
- Cold-start airplane-mode tests are still required on real Android/iOS devices. Do not describe the mobile app as fully offline-ready until those device checks pass.
