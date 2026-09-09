param(
  [string]$GoogleMapsTileKey = $env:BRIDGEPOINT_GOOGLE_MAPS_TILE_KEY,
  [string]$CesiumIonToken = $env:BRIDGEPOINT_CESIUM_ION_TOKEN,
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
Write-Host "BridgePoint World bootstrap" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
flutter --version
flutter doctor
flutter pub get
$worldDir = Join-Path $RepoRoot 'web\bridgepoint-3d-world'
$localConfig = Join-Path $worldDir 'runtime-config.local.js'
$g = $GoogleMapsTileKey | ConvertTo-Json -Compress
$c = $CesiumIonToken | ConvertTo-Json -Compress
@"
/* Generated locally by bootstrap_bridgepoint_world.ps1. Do not commit. */
window.BRIDGEPOINT_WORLD_CONFIG = Object.assign(window.BRIDGEPOINT_WORLD_CONFIG || {}, {
  googleMapsTileKey: $g,
  cesiumIonToken: $c,
  photorealDefault: true,
  lockedCountryMinimumHeightMeters: 350000,
  photorealMaximumHeightMeters: 450000
});
"@ | Set-Content -Path $localConfig -Encoding UTF8
Write-Host "Runtime world config generated (keys remain local/untracked)." -ForegroundColor Green
if (-not $SkipFlutterBuild) {
  flutter build web --release --pwa-strategy=offline-first
  $worldOut = Join-Path $RepoRoot 'build\web\bridgepoint-3d-world'
  if (Test-Path $worldOut) { Remove-Item $worldOut -Recurse -Force }
  Copy-Item $worldDir $worldOut -Recurse -Force
  Write-Host "Production web build: $RepoRoot\build\web" -ForegroundColor Green
}
if (-not $SkipArchives) {
  $exportDir = Join-Path $RepoRoot 'exports'
  New-Item -ItemType Directory -Force -Path $exportDir | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $sourceZip = Join-Path $exportDir "BridgePoint-source-$stamp.zip"
  git archive --format=zip --output=$sourceZip HEAD
  Write-Host "Tracked source snapshot: $sourceZip" -ForegroundColor Green
  if (Test-Path (Join-Path $RepoRoot 'build\web')) {
    $runtimeZip = Join-Path $exportDir "BridgePoint-web-runtime-$stamp.zip"
    Compress-Archive -Path (Join-Path $RepoRoot 'build\web\*') -DestinationPath $runtimeZip -Force
    Write-Host "Runnable web export: $runtimeZip" -ForegroundColor Green
  }
}
Write-Host ""
Write-Host "Local preview:" -ForegroundColor Cyan
Write-Host "  python -m http.server 8787 --directory build/web"
Write-Host "  http://localhost:8787/bridgepoint-3d-world/"
