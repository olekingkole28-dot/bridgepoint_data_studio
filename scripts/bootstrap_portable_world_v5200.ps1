param(
  [Parameter(Mandatory=$true)][string]$BundleRoot,
  [string]$Manifest = '',
  [string]$CoverageGate = '',
  [switch]$VerifyHashes,
  [switch]$AllowIncomplete
)
$ErrorActionPreference='Stop'
if(-not $Manifest){$Manifest=Join-Path $BundleRoot 'manifest\world-parquet-manifest.json'}
if(-not $CoverageGate){$CoverageGate=Join-Path $BundleRoot 'manifest\coverage-gate.json'}
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Builder=Join-Path $RepoRoot 'scripts\build_world_duckdb_catalog_v5200.py'

function Require([string]$Name){
  if(-not (Get-Command $Name -ErrorAction SilentlyContinue)){throw "Required command '$Name' was not found on PATH."}
}
Require 'python'
if(-not (Test-Path $Builder)){throw "Missing V5200 DuckDB builder: $Builder"}
if(-not (Test-Path $Manifest)){throw "Missing manifest: $Manifest"}
if(-not (Test-Path $CoverageGate)){throw "Missing coverage gate: $CoverageGate"}

python - <<'PY'
import importlib.util,sys
missing=[m for m in ('duckdb',) if importlib.util.find_spec(m) is None]
if missing:
    print('Missing Python packages: '+','.join(missing),file=sys.stderr);sys.exit(2)
PY
if($LASTEXITCODE -ne 0){throw 'Python duckdb package is required: python -m pip install duckdb'}

$Args=@(
  $Builder,
  '--bundle-root',$BundleRoot,
  '--manifest-json',$Manifest,
  '--coverage-json',$CoverageGate,
  '--threads','4'
)
if($VerifyHashes){$Args+='--verify-hashes'}
if(-not $AllowIncomplete){$Args+='--require-export-ready'}

Write-Host 'BridgePoint Portable World V5200' -ForegroundColor Cyan
Write-Host "Bundle: $BundleRoot"
Write-Host "Manifest: $Manifest"
Write-Host "Coverage gate: $CoverageGate"
& python @Args
if($LASTEXITCODE -ne 0){throw "DuckDB catalog build failed with exit code $LASTEXITCODE"}

$Db=Join-Path $BundleRoot 'bridgepoint-world.duckdb'
if(-not (Test-Path $Db)){throw 'DuckDB file was not created.'}

Write-Host ''
Write-Host 'Portable catalog created.' -ForegroundColor Green
Write-Host "DuckDB: $Db" -ForegroundColor Green
Write-Host ''
Write-Host 'Storage rule:' -ForegroundColor Cyan
Write-Host '  Parquet/ZSTD remains the durable national store.'
Write-Host '  DuckDB is the lean catalog/query engine and does not duplicate national geometry.'
Write-Host ''
Write-Host 'Example DuckDB queries:' -ForegroundColor Cyan
Write-Host "  select * from export_readiness;"
Write-Host "  select * from portable_layer_summary;"
Write-Host "  select * from jurisdiction_summary where jurisdiction_code='CT';"
Write-Host "  select relative_path from portable_layers where jurisdiction_code='CT' and layer_family='PARCEL';"
