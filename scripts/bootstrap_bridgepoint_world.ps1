param(
  [switch]$SkipFlutterBuild,
  [switch]$SkipArchives
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RepoRoot
function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Required command '$Name' was not found on PATH." }
}
Require-Command git
Require-Command flutter
Write-Host "BridgePoint World V2500 bootstrap" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
Write-Host "World data policy: BridgePoint + free/public sources only. No Google/Mapbox/Bing/Nearmap/Cesium-ion data key is required." -ForegroundColor Green
Write-Host "Building policy: property-linked BridgePoint geometry first; source-native Overture PMTiles fill viewport gaps. The 112 state/kind archive copies are NOT required for bootstrap." -ForegroundColor Green
flutter --version
flutter doctor
flutter pub get
$worldDir = Join-Path $RepoRoot 'web\bridgepoint-3d-world'
$worldJs = Join-Path $worldDir 'world-v2500.js'
$inspectorJs = Join-Path $worldDir 'world-v2500-inspector.js'
$sourceNativeBuildingsJs = Join-Path $worldDir 'world-v2713-source-native-buildings.js'
$worldContract = Join-Path $worldDir 'world-contract-v2500.json'
if (-not (Test-Path $worldJs)) { throw 'World V2500 runtime is missing.' }
if (-not (Test-Path $inspectorJs)) { throw 'World V2500 inspector is missing.' }
if (-not (Test-Path $sourceNativeBuildingsJs)) { throw 'Source-native building runtime is missing.' }
if (-not (Test-Path $worldContract)) { throw 'World V2500 contract is missing.' }
$contract = Get-Content $worldContract -Raw | ConvertFrom-Json
if (-not $contract.defaults.source_native_buildings) { throw 'World contract does not enable source-native buildings.' }
if ($contract.building_runtime_policy.bulk_download_required_for_bootstrap) { throw 'World contract unexpectedly requires a bulk building download.' }
if ($contract.building_runtime_policy.state_archive_cache_required_for_bootstrap) { throw 'World contract unexpectedly requires the state archive cache.' }
Write-Host "Building bootstrap gate passed without bulk U.S. building preprocessing." -ForegroundColor Green
if (Get-Command node -ErrorAction SilentlyContinue) {
  node --check $worldJs
  node --check $inspectorJs
  node --check $sourceNativeBuildingsJs
  Write-Host "V2500 JavaScript + source-native building syntax passed local Node check." -ForegroundColor Green
} else {
  Write-Host "Node is not currently on PATH. Flutter build can continue, but run the separate Node readiness helper before final owner export." -ForegroundColor Yellow
}
if (-not $SkipFlutterBuild) {
  flutter build web --release -t lib/main_v2.dart --base-href "/app/" --pwa-strategy=offline-first --dart-define=BRIDGEPOINT_RELEASE=local-v2500
  $worldOut = Join-Path $RepoRoot 'build\web\bridgepoint-3d-world'
  if (Test-Path $worldOut) { Remove-Item $worldOut -Recurse -Force }
  Copy-Item $worldDir $worldOut -Recurse -Force
  if (-not (Test-Path (Join-Path $worldOut 'world-v2500.js'))) { throw 'World V2500 runtime did not survive web assembly.' }
  if (-not (Test-Path (Join-Path $worldOut 'world-v2713-source-native-buildings.js'))) { throw 'Source-native buildings did not survive web assembly.' }
  if (-not (Select-String -Path (Join-Path $worldOut 'index.html') -Pattern 'world-v2713-source-native-buildings.js' -Quiet)) { throw 'Built world is not wired to source-native buildings.' }
  if (-not (Select-String -Path (Join-Path $RepoRoot 'build\web\main.dart.js') -Pattern 'bridgepoint-world-v2500' -Quiet) -and -not (Select-String -Path (Join-Path $RepoRoot 'lib\v2\bridgepoint_world_embed_web_v2.dart') -Pattern 'bridgepoint-world-v2500' -Quiet)) { throw 'Clean V2 map replacement contract was not found.' }
  Write-Host "Production Clean V2 + World V2500 web build: $RepoRoot\build\web" -ForegroundColor Green
}
if (-not $SkipArchives) {
  $exportDir = Join-Path $RepoRoot 'exports'
  New-Item -ItemType Directory -Force -Path $exportDir | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $sourceZip = Join-Path $exportDir "BridgePoint-source-v2500-$stamp.zip"
  git archive --format=zip --output=$sourceZip HEAD
  Write-Host "Tracked source snapshot: $sourceZip" -ForegroundColor Green
  if (Test-Path (Join-Path $RepoRoot 'build\web')) {
    $runtimeZip = Join-Path $exportDir "BridgePoint-web-runtime-v2500-$stamp.zip"
    Compress-Archive -Path (Join-Path $RepoRoot 'build\web\*') -DestinationPath $runtimeZip -Force
    Write-Host "Runnable web export: $runtimeZip" -ForegroundColor Green
  }
}
Write-Host ""
Write-Host "Local preview:" -ForegroundColor Cyan
Write-Host "  python -m http.server 8787 --directory build/web"
Write-Host "  http://localhost:8787/bridgepoint-3d-world/"
