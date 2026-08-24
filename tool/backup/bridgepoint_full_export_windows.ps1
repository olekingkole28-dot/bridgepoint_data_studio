param(
  [string]$Destination = "$env:USERPROFILE\BridgePointBackups",
  [string]$DbUrl = '',
  [string]$S3AccessKey = '',
  [string]$S3SecretKey = '',
  [switch]$SkipStorage,
  [switch]$SkipFunctions,
  [switch]$SkipGit,
  [switch]$NonInteractive
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$ProjectRef='xdfsjztwgsbmabshzsjw'
$ProjectUrl='https://xdfsjztwgsbmabshzsjw.supabase.co'
$Region='us-east-1'
if($env:BRIDGEPOINT_BACKUP_DESTINATION){$Destination=$env:BRIDGEPOINT_BACKUP_DESTINATION}
$Stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$Root=Join-Path $Destination "BridgePoint-$Stamp"
$DbDir=Join-Path $Root 'database'
$FnDir=Join-Path $Root 'edge-functions'
$StorageDir=Join-Path $Root 'storage'
$SourceDir=Join-Path $Root 'source'
New-Item -ItemType Directory -Force -Path $DbDir,$FnDir,$StorageDir,$SourceDir | Out-Null

function Has-Cmd([string]$n){ [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Secure-ToPlain([Security.SecureString]$s){$p=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s);try{[Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p)}}
function Require-Cmd([string]$n,[string]$how){if(-not (Has-Cmd $n)){throw "$n is required. $how"}}
function Run([string]$exe,[string[]]$args){Write-Host ("> "+$exe+' '+(($args|ForEach-Object{if($_ -match 'postgres(ql)?://'){ '[DATABASE_URL]' }else{$_}}) -join ' ')) -ForegroundColor DarkGray;& $exe @args;if($LASTEXITCODE -ne 0){throw "$exe failed with exit code $LASTEXITCODE"}}

Write-Host "BridgePoint full export -> $Root" -ForegroundColor Cyan
Require-Cmd 'supabase' 'Install the Supabase CLI, then rerun.'
Require-Cmd 'pg_dump' 'Install PostgreSQL client tools (v17 preferred), then rerun.'
Require-Cmd 'pg_restore' 'Install PostgreSQL client tools (v17 preferred), then rerun.'
if(-not $SkipGit){Require-Cmd 'git' 'Install Git for Windows, then rerun.'}

if(-not $DbUrl){$DbUrl=[string]$env:BRIDGEPOINT_BACKUP_DB_URL}
if(-not $DbUrl -and -not $NonInteractive){
  Write-Host 'Paste the BridgePoint database connection string from Supabase Dashboard > Connect.' -ForegroundColor Yellow
  $DbUrl=Read-Host 'Database URL'
}
if([string]::IsNullOrWhiteSpace($DbUrl) -or $DbUrl -notmatch '^postgres(ql)?://'){throw 'A PostgreSQL connection URL is required. For unattended mode set BRIDGEPOINT_BACKUP_DB_URL locally.'}

Run 'pg_dump' @('--format=custom','--no-owner','--no-acl','--verbose','--file',(Join-Path $DbDir 'bridgepoint_full.dump'),$DbUrl)
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'roles.sql'),'--role-only')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'schema.sql'))
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'data.sql'),'--use-copy','--data-only','-x','storage.buckets_vectors','-x','storage.vector_indexes')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'migration_history_schema.sql'),'--schema','supabase_migrations')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'migration_history_data.sql'),'--use-copy','--data-only','--schema','supabase_migrations')
Run 'pg_restore' @('--list',(Join-Path $DbDir 'bridgepoint_full.dump'))
& pg_restore --list (Join-Path $DbDir 'bridgepoint_full.dump') | Set-Content (Join-Path $DbDir 'bridgepoint_full.catalog.txt') -Encoding UTF8
if($LASTEXITCODE -ne 0){throw 'pg_restore could not read the full archive catalog.'}

if(-not $SkipGit){
  Run 'git' @('clone','--mirror','https://github.com/olekingkole28-dot/bridgepoint_data_studio.git',(Join-Path $SourceDir 'bridgepoint_data_studio.git'))
  Run 'git' @('clone','--mirror','https://github.com/olekingkole28-dot/bridgepoint-live.git',(Join-Path $SourceDir 'bridgepoint-live.git'))
}

if(-not $SkipFunctions){
  try {
    $manifestPath=Join-Path $PSScriptRoot 'edge_functions_manifest.txt'
    if(Test-Path $manifestPath){
      Get-Content $manifestPath | Where-Object {$_ -and -not $_.StartsWith('#')} | ForEach-Object {
        $slug=$_.Trim(); if($slug){Push-Location $FnDir;try { Run 'supabase' @('functions','download',$slug,'--project-ref',$ProjectRef) } finally { Pop-Location }}
      }
    } else { Write-Warning 'Edge function manifest missing; source Git mirrors were still captured.' }
  } catch { Write-Warning "Edge Function download pass did not fully complete: $($_.Exception.Message)" }
}

if(-not $SkipStorage){
  Require-Cmd 'rclone' 'Install rclone, then rerun without -SkipStorage. Storage is copied through the Supabase S3 endpoint.'
  if(-not $S3AccessKey){$S3AccessKey=[string]$env:BRIDGEPOINT_BACKUP_S3_ACCESS_KEY_ID}
  if(-not $S3SecretKey){$S3SecretKey=[string]$env:BRIDGEPOINT_BACKUP_S3_SECRET_ACCESS_KEY}
  if((-not $S3AccessKey -or -not $S3SecretKey) -and -not $NonInteractive){
    Write-Host 'Create/read an S3 access key in Supabase Dashboard > Storage > Configuration > S3.' -ForegroundColor Yellow
    if(-not $S3AccessKey){$S3AccessKey=Read-Host 'S3 Access Key ID'}
    if(-not $S3SecretKey){$SecretSecure=Read-Host 'S3 Secret Access Key' -AsSecureString;$S3SecretKey=Secure-ToPlain $SecretSecure}
  }
  if(-not $S3AccessKey -or -not $S3SecretKey){throw 'Storage backup credentials are required. Configure them locally; they are never accepted from a BridgePoint server job.'}
  $Endpoint="$ProjectUrl/storage/v1/s3"
  $env:RCLONE_CONFIG_BPS3_TYPE='s3'
  $env:RCLONE_CONFIG_BPS3_PROVIDER='Other'
  $env:RCLONE_CONFIG_BPS3_ENDPOINT=$Endpoint
  $env:RCLONE_CONFIG_BPS3_REGION=$Region
  $env:RCLONE_CONFIG_BPS3_ACCESS_KEY_ID=$S3AccessKey
  $env:RCLONE_CONFIG_BPS3_SECRET_ACCESS_KEY=$S3SecretKey
  try {
    $buckets=& rclone lsf 'bps3:'
    if($LASTEXITCODE -ne 0){throw 'Could not list Supabase Storage buckets.'}
    foreach($raw in $buckets){
      $bucket=$raw.TrimEnd('/').Trim(); if(-not $bucket){continue}
      $dest=Join-Path $StorageDir $bucket; New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Write-Host "Copying Storage bucket $bucket" -ForegroundColor Cyan
      & rclone copy "bps3:$bucket" $dest --transfers 4 --checkers 8 --timeout 30m --create-empty-src-dirs
      if($LASTEXITCODE -ne 0){throw "Storage copy failed for bucket $bucket"}
    }
  } finally {
    Remove-Item Env:RCLONE_CONFIG_BPS3_TYPE,Env:RCLONE_CONFIG_BPS3_PROVIDER,Env:RCLONE_CONFIG_BPS3_ENDPOINT,Env:RCLONE_CONFIG_BPS3_REGION,Env:RCLONE_CONFIG_BPS3_ACCESS_KEY_ID,Env:RCLONE_CONFIG_BPS3_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    $S3SecretKey=$null;$SecretSecure=$null
  }
}

$full=Get-Item (Join-Path $DbDir 'bridgepoint_full.dump')
$manifest=[ordered]@{
  project_ref=$ProjectRef; project_url=$ProjectUrl; region=$Region; exported_at=(Get-Date).ToUniversalTime().ToString('o');
  postgres_major=17; format_version=3; primary_database_archive='database/bridgepoint_full.dump'; primary_database_archive_bytes=$full.Length;
  database_files=@('bridgepoint_full.dump','bridgepoint_full.catalog.txt','roles.sql','schema.sql','data.sql','migration_history_schema.sql','migration_history_data.sql');
  storage_included=(-not $SkipStorage); edge_functions_attempted=(-not $SkipFunctions); git_mirrors_included=(-not $SkipGit);
  source_repositories=@('olekingkole28-dot/bridgepoint_data_studio','olekingkole28-dot/bridgepoint-live');
  secrets_exported=$false; note='API/JWT/OAuth/SMTP/payment/database/S3 secrets are intentionally not placed in the archive.'
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Root 'manifest.json') -Encoding UTF8
@'
BRIDGEPOINT SECRET / CONFIG RESTORE CHECKLIST

This archive intentionally does NOT contain live secret credentials.
Before failover/self-host restore, configure fresh secrets for:
- Supabase/self-hosted JWT and API keys
- Stripe keys and webhook secret
- OAuth/social provider secrets and redirect URLs
- SMTP/email credentials
- any external API credentials
- local BridgePoint node credentials
- DNS/custom-domain targets

Do not commit restored secrets to Git.
'@ | Set-Content (Join-Path $Root 'SECRETS_NOT_EXPORTED.txt') -Encoding UTF8
Get-ChildItem $Root -Recurse -File | Where-Object {$_.Name -ne 'SHA256SUMS.txt'} | ForEach-Object {$h=Get-FileHash $_.FullName -Algorithm SHA256;$rel=$_.FullName.Substring($Root.Length+1);"$($h.Hash.ToLower())  $rel"} | Set-Content (Join-Path $Root 'SHA256SUMS.txt') -Encoding ASCII
Write-Host ''
Write-Host 'BridgePoint full export completed.' -ForegroundColor Green
Write-Host "Archive folder: $Root" -ForegroundColor Green
Write-Output ("BRIDGEPOINT_BACKUP_ROOT="+$Root)
