param(
  [string]$Destination = "$env:USERPROFILE\BridgePointBackups"
)
$ErrorActionPreference='Stop'
$Root=Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI'
$ConfigPath=Join-Path $Root 'backup-config.json'
New-Item -ItemType Directory -Force -Path $Root | Out-Null
function Protect([string]$v){if([string]::IsNullOrWhiteSpace($v)){return ''};ConvertTo-SecureString $v -AsPlainText -Force | ConvertFrom-SecureString}
function Read-Secret([string]$label){$s=Read-Host $label -AsSecureString;$p=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s);try{[Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p)}}
Write-Host 'BridgePoint independent backup setup' -ForegroundColor Cyan
Write-Host 'Secrets are encrypted for this Windows user with DPAPI and are not sent to GitHub or stored in BridgePoint job payloads.' -ForegroundColor Green
$db=Read-Secret 'Supabase production database URL (Dashboard > Connect)'
if($db -notmatch '^postgres(ql)?://'){throw 'A PostgreSQL connection URL is required.'}
$s3id=Read-Secret 'Supabase Storage S3 Access Key ID'
$s3secret=Read-Secret 'Supabase Storage S3 Secret Access Key'
if(-not$s3id -or -not$s3secret){throw 'Storage S3 credentials are required for a complete independent backup.'}
$restore=Read-Secret 'Optional NON-PRODUCTION restore-test database URL (press Enter to skip)'
if($restore -and $restore -notmatch '^postgres(ql)?://'){throw 'Restore-test URL must be PostgreSQL or blank.'}
if($restore -match 'xdfsjztwgsbmabshzsjw'){throw 'The live BridgePoint production database may never be used as a restore-test target.'}
$deps=@('supabase','pg_dump','pg_restore','rclone','git')
$missing=@($deps|Where-Object{-not(Get-Command $_ -ErrorAction SilentlyContinue)})
$cfg=[ordered]@{
  version=718
  backup_enabled=$true
  destination=$Destination
  db_url_protected=(Protect $db)
  s3_access_key_protected=(Protect $s3id)
  s3_secret_key_protected=(Protect $s3secret)
  restore_test_db_url_protected=(Protect $restore)
  restore_test_enabled=[bool]$restore
  missing_dependencies=$missing
  configured_at=(Get-Date).ToUniversalTime().ToString('o')
}
$cfg|ConvertTo-Json -Depth 10|Set-Content $ConfigPath -Encoding UTF8
try{icacls $ConfigPath /inheritance:r /grant:r "$env:USERNAME`:F"|Out-Null}catch{}
$db=$null;$s3id=$null;$s3secret=$null;$restore=$null
if($missing.Count){Write-Warning ('Install these free tools before automatic backup can activate: '+($missing -join ', '))}
else{Write-Host 'All backup dependencies detected.' -ForegroundColor Green}
Write-Host "Backup configuration saved locally: $ConfigPath" -ForegroundColor Green
Write-Host 'Restart the BridgePoint Local AI task/agent after setup; it will advertise backup authority only when this protected configuration and required tools are present.' -ForegroundColor Yellow
