[CmdletBinding()]
param(
  [string]$EnrollmentCode = '',
  [string]$Destination = "$env:USERPROFILE\BridgePointBackups",
  [string]$DbUrl = '',
  [switch]$RunExport,
  [switch]$SkipStorage,
  [switch]$SkipGitMirrors,
  [switch]$SkipModelPull,
  [switch]$PreflightOnly
)

$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$PublicRaw='https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/main'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalRoot=Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI'
$Config=Join-Path $LocalRoot 'config.json'
$Tools=Join-Path $env:LOCALAPPDATA 'BridgePoint\ExportTools'
New-Item -ItemType Directory -Force -Path $Tools | Out-Null

function Banner([string]$s){Write-Host "`n=== $s ===" -ForegroundColor Cyan}
function Has([string]$n){return [bool](Get-Command $n -ErrorAction SilentlyContinue)}
function Download([string]$name,[string]$dest){
  $tmp=$dest+'.tmp'
  Invoke-WebRequest -UseBasicParsing -TimeoutSec 90 -Uri "$PublicRaw/downloads/backup/$name" -OutFile $tmp
  $txt=Get-Content $tmp -Raw
  if($txt.Length -lt 300 -or $txt -notmatch 'BridgePoint'){Remove-Item $tmp -Force -ErrorAction SilentlyContinue;throw "Rejected export tool payload: $name"}
  Move-Item $tmp $dest -Force
}
function Hardware {
  $cs=Get-CimInstance Win32_ComputerSystem
  $os=Get-CimInstance Win32_OperatingSystem
  $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
  $gpu=Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending | Select-Object -First 1
  $drives=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    [ordered]@{drive=$_.DeviceID;free_gb=[math]::Round([double]$_.FreeSpace/1GB,1);size_gb=[math]::Round([double]$_.Size/1GB,1)}
  }
  return [ordered]@{
    computer=$env:COMPUTERNAME
    os=$os.Caption
    ram_gb=[math]::Round([double]$cs.TotalPhysicalMemory/1GB,1)
    free_ram_gb=[math]::Round(([double]$os.FreePhysicalMemory*1KB)/1GB,1)
    cpu=$cpu.Name
    logical_processors=[int]$cpu.NumberOfLogicalProcessors
    cpu_load_pct=[int]($cpu.LoadPercentage ?? 0)
    gpu=$gpu.Name
    gpu_ram_gb=if($gpu.AdapterRAM){[math]::Round([double]$gpu.AdapterRAM/1GB,1)}else{0}
    drives=@($drives)
  }
}

Banner 'BridgePoint NEW DESKTOP bootstrap'
if($env:OS -ne 'Windows_NT'){throw 'This bootstrap is for the new Windows desktop.'}
$hw=Hardware
$hw | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Tools 'new-desktop-hardware.json') -Encoding UTF8
Write-Host ("Computer: {0} | RAM: {1} GB | CPU threads: {2} | GPU: {3}" -f $hw.computer,$hw.ram_gb,$hw.logical_processors,$hw.gpu)
$hw.drives | ForEach-Object { Write-Host ("Drive {0}: {1} GB free / {2} GB" -f $_.drive,$_.free_gb,$_.size_gb) }

Banner 'Fresh Local AI enrollment'
if(Test-Path $Config){
  $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
  $old=Join-Path $LocalRoot "config.pre-new-desktop-$stamp.json"
  Move-Item $Config $old -Force
  Write-Host "Existing node config was archived to $old. It will NOT be reused." -ForegroundColor Yellow
}
$installer=Join-Path $Root 'install_windows.ps1'
if(-not(Test-Path $installer)){throw "Missing $installer. Run this script from tool\local_ai in the private BridgePoint repo."}
if([string]::IsNullOrWhiteSpace($EnrollmentCode)){
  $EnrollmentCode=Read-Host 'Paste the fresh one-time enrollment code from BridgePoint Owner > Local AI'
}
if([string]::IsNullOrWhiteSpace($EnrollmentCode)){throw 'A fresh enrollment code is required for the new desktop.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -EnrollmentCode $EnrollmentCode @($(if($SkipModelPull){'-SkipModelPull'}))
if($LASTEXITCODE -ne 0){throw "Local AI installer failed with exit code $LASTEXITCODE"}
if(-not(Test-Path $Config)){throw 'Local AI enrollment did not create config.json.'}
$cfg=Get-Content $Config -Raw|ConvertFrom-Json
if([int]$cfg.agent_version -lt 718){throw "Local AI enrollment is stale: agent v$($cfg.agent_version)"}
Write-Host "Fresh desktop node enrolled with agent v$($cfg.agent_version)." -ForegroundColor Green

Banner 'Export tools'
$files=@(
 'bridgepoint_full_export_windows.ps1',
 'bridgepoint_verify_backup_windows.ps1',
 'bridgepoint_restore_test_windows.ps1'
)
foreach($n in $files){Download $n (Join-Path $Tools $n)}
Write-Host "Current export tools staged in $Tools" -ForegroundColor Green

$required=@('psql','pg_dump','pg_restore','supabase')
if(-not$SkipGitMirrors){$required+='git'}
if(-not$SkipStorage){$required+='rclone'}
$missing=@($required|Where-Object{-not(Has $_)})
if($missing.Count){
  Write-Warning ("Export prerequisites still missing: "+($missing -join ', '))
  Write-Host 'Local Ollama node is enrolled and can run independently. Install the missing export tools, then rerun this bootstrap.' -ForegroundColor Yellow
  exit 2
}

if([string]::IsNullOrWhiteSpace($DbUrl)){
  $DbUrl=Read-Host 'Paste the Supabase PostgreSQL connection URL for the export preflight'
}
if($DbUrl -notmatch '^postgres(ql)?://'){throw 'A PostgreSQL connection URL is required for export preflight.'}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$export=Join-Path $Tools 'bridgepoint_full_export_windows.ps1'
$verify=Join-Path $Tools 'bridgepoint_verify_backup_windows.ps1'

Banner 'Full export preflight'
$preArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$export,'-Destination',$Destination,'-DbUrl',$DbUrl,'-PreflightOnly')
if($SkipStorage){$preArgs+='-SkipStorage'}
if($SkipGitMirrors){$preArgs+='-SkipGit'}
& powershell.exe @preArgs
if($LASTEXITCODE -ne 0){throw "BridgePoint export preflight failed with exit code $LASTEXITCODE"}
Write-Host 'Preflight passed.' -ForegroundColor Green

if($PreflightOnly -or -not$RunExport){
  Write-Host 'New desktop is prepared. Re-run with -RunExport when the backend export gate is READY.' -ForegroundColor Green
  exit 0
}

Banner 'Full BridgePoint export'
$before=@(Get-ChildItem $Destination -Directory -Filter 'BridgePoint-*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$export,'-Destination',$Destination,'-DbUrl',$DbUrl)
if($SkipStorage){$args+='-SkipStorage'}
if($SkipGitMirrors){$args+='-SkipGit'}
& powershell.exe @args
if($LASTEXITCODE -ne 0){throw "BridgePoint export failed with exit code $LASTEXITCODE"}

$latest=Get-ChildItem $Destination -Directory -Filter 'BridgePoint-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if(-not$latest){throw 'Export completed without a discoverable BridgePoint archive directory.'}
if($before -contains $latest.FullName){Write-Warning 'Latest archive directory existed before this run; verification will still use its current contents.'}

Banner 'Verify exported archive'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verify -BackupRoot $latest.FullName
if($LASTEXITCODE -ne 0){throw "Backup verification failed with exit code $LASTEXITCODE"}

Write-Host "`nNEW DESKTOP HANDOFF READY" -ForegroundColor Green
Write-Host "Local AI: fresh enrollment v$($cfg.agent_version), auto-start/self-update enabled."
Write-Host "Verified export: $($latest.FullName)"
Write-Host 'Do not delete Supabase/cloud data until an isolated restore test passes and the backend export gate reports ready.' -ForegroundColor Yellow
