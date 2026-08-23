param(
  [Parameter(Mandatory=$true)][string]$BackupRoot
)
$ErrorActionPreference='Stop'
function Fail([string]$m){Write-Host "FAIL: $m" -ForegroundColor Red; exit 1}
function Ok([string]$m){Write-Host "OK: $m" -ForegroundColor Green}
if(-not(Test-Path $BackupRoot)){Fail "Backup folder not found: $BackupRoot"}
$manifestPath=Join-Path $BackupRoot 'manifest.json'
$sumsPath=Join-Path $BackupRoot 'SHA256SUMS.txt'
$dumpPath=Join-Path $BackupRoot 'database\bridgepoint_full.dump'
if(-not(Test-Path $manifestPath)){Fail 'manifest.json missing'}
if(-not(Test-Path $sumsPath)){Fail 'SHA256SUMS.txt missing'}
if(-not(Test-Path $dumpPath)){Fail 'database/bridgepoint_full.dump missing'}
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
if([int]$manifest.format_version -lt 2){Fail 'Backup format is older than v2 full-archive format'}
Ok "Manifest format $($manifest.format_version), exported $($manifest.exported_at)"

$bad=@()
Get-Content $sumsPath | ForEach-Object {
  if($_ -match '^([0-9a-fA-F]{64})  (.+)$'){
    $expected=$Matches[1].ToLower(); $rel=$Matches[2]; $path=Join-Path $BackupRoot $rel
    if(-not(Test-Path $path)){$bad += "missing $rel"; return}
    $actual=(Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    if($actual -ne $expected){$bad += "hash mismatch $rel"}
  }
}
if($bad.Count){$bad|ForEach-Object{Write-Host $_ -ForegroundColor Red};Fail "$($bad.Count) checksum problem(s)"}
Ok 'All recorded SHA-256 checksums match'

$pgRestore=Get-Command pg_restore -ErrorAction SilentlyContinue
if(-not $pgRestore){Fail 'pg_restore is required to validate the PostgreSQL archive catalog'}
$catalog=& $pgRestore.Source --list $dumpPath 2>&1
if($LASTEXITCODE -ne 0){$catalog|ForEach-Object{Write-Host $_};Fail 'pg_restore --list could not read bridgepoint_full.dump'}
$catalogText=($catalog -join "`n")
foreach($needle in @('SCHEMA - public','TABLE','TABLE DATA')){
  if($catalogText -notmatch [regex]::Escape($needle)){Write-Warning "Archive catalog did not contain expected marker: $needle"}
}
Ok 'PostgreSQL custom archive catalog is readable'

$dbFiles=@('roles.sql','schema.sql','data.sql','migration_history_schema.sql','migration_history_data.sql')
foreach($f in $dbFiles){
  $p=Join-Path $BackupRoot ("database\"+$f)
  if(-not(Test-Path $p)){Fail "Missing database/$f"}
  if((Get-Item $p).Length -eq 0){Fail "database/$f is empty"}
}
Ok 'Supabase split database files are present and non-empty'

$src1=Join-Path $BackupRoot 'source\bridgepoint_data_studio.git'
$src2=Join-Path $BackupRoot 'source\bridgepoint-live.git'
if($manifest.git_mirrors_included){
  if(-not(Test-Path $src1) -or -not(Test-Path $src2)){Fail 'Git mirrors were requested but one or more mirrors are missing'}
  Ok 'Source-code Git mirrors are present'
}
if($manifest.storage_included){
  $storage=Join-Path $BackupRoot 'storage'
  if(-not(Test-Path $storage)){Fail 'Storage was requested but storage folder is missing'}
  Ok 'Storage export folder is present'
}

$result=[ordered]@{verified=$true;verified_at=(Get-Date).ToUniversalTime().ToString('o');format_version=$manifest.format_version;archive_bytes=(Get-Item $dumpPath).Length;checksums='PASS';pg_restore_catalog='PASS'}
$result|ConvertTo-Json|Set-Content (Join-Path $BackupRoot 'verification.json') -Encoding UTF8
Write-Host ''
Write-Host 'BridgePoint backup VERIFIED.' -ForegroundColor Green
Write-Host (Join-Path $BackupRoot 'verification.json')
