param(
  [string]$Destination = "$env:USERPROFILE\BridgePointBackups",
  [string]$DbUrl = '',
  [switch]$SkipStorage,
  [switch]$SkipFunctions
)
$ErrorActionPreference='Stop'
$ProjectRef='xdfsjztwgsbmabshzsjw'
$ProjectUrl='https://xdfsjztwgsbmabshzsjw.supabase.co'
$Region='us-east-1'
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
function Run([string]$exe,[string[]]$args){Write-Host ("> "+$exe+' '+($args -join ' ')) -ForegroundColor DarkGray;& $exe @args;if($LASTEXITCODE -ne 0){throw "$exe failed with exit code $LASTEXITCODE"}}

Write-Host "BridgePoint full export -> $Root" -ForegroundColor Cyan
Require-Cmd 'supabase' 'Install the Supabase CLI, then rerun.'
Require-Cmd 'git' 'Install Git for Windows, then rerun.'

if(-not $DbUrl){
  Write-Host 'Paste the BridgePoint database connection string from Supabase Dashboard > Connect.' -ForegroundColor Yellow
  $DbUrl=Read-Host 'Database URL'
}
if([string]::IsNullOrWhiteSpace($DbUrl) -or $DbUrl -notmatch '^postgres(ql)?://'){throw 'A PostgreSQL connection URL is required.'}

# Supabase-recommended logical backup split for portable restore.
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'roles.sql'),'--role-only')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'schema.sql'))
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'data.sql'),'--use-copy','--data-only','-x','storage.buckets_vectors','-x','storage.vector_indexes')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'migration_history_schema.sql'),'--schema','supabase_migrations')
Run 'supabase' @('db','dump','--db-url',$DbUrl,'-f',(Join-Path $DbDir 'migration_history_data.sql'),'--use-copy','--data-only','--schema','supabase_migrations')

# Keep the application/source snapshot beside the data backup.
Run 'git' @('clone','--mirror','https://github.com/olekingkole28-dot/bridgepoint_data_studio.git',(Join-Path $SourceDir 'bridgepoint_data_studio.git'))
Run 'git' @('clone','--mirror','https://github.com/olekingkole28-dot/bridgepoint-live.git',(Join-Path $SourceDir 'bridgepoint-live.git'))

if(-not $SkipFunctions){
  try {
    $manifestPath=Join-Path $PSScriptRoot 'edge_functions_manifest.txt'
    if(Test-Path $manifestPath){
      Get-Content $manifestPath | Where-Object {$_ -and -not $_.StartsWith('#')} | ForEach-Object {
        $slug=$_.Trim(); if($slug){
          Push-Location $FnDir
          try { Run 'supabase' @('functions','download',$slug,'--project-ref',$ProjectRef) }
          finally { Pop-Location }
        }
      }
    } else { Write-Warning 'Edge function manifest missing; source Git mirrors were still captured.' }
  } catch { Write-Warning "Edge Function download pass did not fully complete: $($_.Exception.Message)" }
}

if(-not $SkipStorage){
  Require-Cmd 'rclone' 'Install rclone, then rerun without -SkipStorage. Large Storage backups are intentionally copied through Supabase S3.'
  Write-Host 'Create/read an S3 access key in Supabase Dashboard > Storage > Configuration > S3.' -ForegroundColor Yellow
  $Access=Read-Host 'S3 Access Key ID'
  $SecretSecure=Read-Host 'S3 Secret Access Key' -AsSecureString
  $Secret=Secure-ToPlain $SecretSecure
  $Endpoint="$ProjectUrl/storage/v1/s3"
  try {
    $buckets=& rclone lsf ':s3:' --s3-provider Other --s3-endpoint $Endpoint --s3-region $Region --s3-access-key-id $Access --s3-secret-access-key $Secret
    if($LASTEXITCODE -ne 0){throw 'Could not list Supabase Storage buckets.'}
    foreach($raw in $buckets){
      $bucket=$raw.TrimEnd('/').Trim(); if(-not $bucket){continue}
      $dest=Join-Path $StorageDir $bucket; New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Write-Host "Copying Storage bucket $bucket" -ForegroundColor Cyan
      & rclone copy ":s3:$bucket" $dest --s3-provider Other --s3-endpoint $Endpoint --s3-region $Region --s3-access-key-id $Access --s3-secret-access-key $Secret --transfers 4 --checkers 8 --timeout 30m --create-empty-src-dirs
      if($LASTEXITCODE -ne 0){throw "Storage copy failed for bucket $bucket"}
    }
  } finally { $Secret=$null; $SecretSecure=$null }
}

# Machine-readable manifest + file hashes. Secrets are intentionally not exported.
$manifest=[ordered]@{
  project_ref=$ProjectRef; project_url=$ProjectUrl; region=$Region; exported_at=(Get-Date).ToUniversalTime().ToString('o');
  postgres_major=17; format_version=1; database_files=@('roles.sql','schema.sql','data.sql','migration_history_schema.sql','migration_history_data.sql');
  storage_included=(-not $SkipStorage); edge_functions_attempted=(-not $SkipFunctions);
  source_repositories=@('olekingkole28-dot/bridgepoint_data_studio','olekingkole28-dot/bridgepoint-live');
  secrets_exported=$false; note='API/JWT/OAuth/SMTP/payment secrets are intentionally not placed in the archive. Recreate or migrate them separately.'
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
- local BridgePoint node credentials (re-enroll local AI against the new backend)
- DNS/custom-domain targets

Do not commit restored secrets to Git.
'@ | Set-Content (Join-Path $Root 'SECRETS_NOT_EXPORTED.txt') -Encoding UTF8

Get-ChildItem $Root -Recurse -File | Where-Object {$_.Name -ne 'SHA256SUMS.txt'} | ForEach-Object {
  $h=Get-FileHash $_.FullName -Algorithm SHA256
  $rel=$_.FullName.Substring($Root.Length+1)
  "$($h.Hash.ToLower())  $rel"
} | Set-Content (Join-Path $Root 'SHA256SUMS.txt') -Encoding ASCII

Write-Host ''
Write-Host 'BridgePoint full export completed.' -ForegroundColor Green
Write-Host "Archive folder: $Root" -ForegroundColor Green
Write-Host 'Run bridgepoint_verify_backup_windows.ps1 against this folder before treating it as a disaster-recovery copy.' -ForegroundColor Yellow
