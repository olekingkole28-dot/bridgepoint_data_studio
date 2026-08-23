param(
  [string]$EnrollmentCode = '',
  [switch]$SkipModelPull
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Base='https://xdfsjztwgsbmabshzsjw.supabase.co'
$Endpoint="$Base/functions/v1/bridgepoint-local-reasoning-v584"
$Root=Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI'
$AgentPath=Join-Path $Root 'bridgepoint_local_ai.ps1'
$ConfigPath=Join-Path $Root 'config.json'
$AgentUrl='https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/live-artifact/downloads/local-ai/bridgepoint_local_ai.ps1'
$TaskName='BridgePoint Local AI'

function Banner($x){Write-Host "`n=== $x ===" -ForegroundColor Cyan}
function Require-Windows {
  if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows.' }
  if ([Environment]::OSVersion.Version.Major -lt 10) { throw 'BridgePoint Local AI requires Windows 10 or newer.' }
}
function Resolve-Ollama {
  $cmd=Get-Command ollama -ErrorAction SilentlyContinue
  if($cmd){return $cmd.Source}
  $known=Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
  if(Test-Path $known){return $known}
  return $null
}
function Ensure-Ollama {
  $o=Resolve-Ollama
  if($o){return $o}
  Banner 'Installing Ollama'
  try {
    $script=(Invoke-WebRequest -UseBasicParsing 'https://ollama.com/install.ps1').Content
    & ([scriptblock]::Create($script))
  } catch {
    $winget=Get-Command winget -ErrorAction SilentlyContinue
    if($winget){ & winget install --id Ollama.Ollama -e --accept-package-agreements --accept-source-agreements }
    else { throw "Could not install Ollama automatically. Install it from ollama.com/download/windows and rerun this file. $($_.Exception.Message)" }
  }
  Start-Sleep -Seconds 4
  $o=Resolve-Ollama
  if(-not $o){throw 'Ollama installation finished but ollama.exe was not found. Reopen PowerShell and rerun the installer.'}
  return $o
}
function Get-Hardware {
  $cs=Get-CimInstance Win32_ComputerSystem
  $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
  $gpu=Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending | Select-Object -First 1
  $ram=[math]::Round($cs.TotalPhysicalMemory/1GB,1)
  $gpuRam=if($gpu.AdapterRAM){[math]::Round([double]$gpu.AdapterRAM/1GB,1)}else{0}
  return [ordered]@{computer=$env:COMPUTERNAME;os=(Get-CimInstance Win32_OperatingSystem).Caption;ram_gb=$ram;cpu=$cpu.Name;logical_processors=$cpu.NumberOfLogicalProcessors;gpu=$gpu.Name;gpu_ram_gb=$gpuRam}
}
function Choose-Models($hw){
  if([double]$hw.ram_gb -ge 24){return @('gpt-oss:20b','deepseek-r1:8b',1)}
  if([double]$hw.ram_gb -ge 12){return @('qwen2.5:7b-instruct','deepseek-r1:1.5b',1)}
  return @('qwen2.5:3b','deepseek-r1:1.5b',1)
}
function Start-Ollama($exe){
  try{Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3|Out-Null;return}catch{}
  Start-Process -FilePath $exe -ArgumentList 'serve' -WindowStyle Hidden
  for($i=0;$i -lt 20;$i++){Start-Sleep -Seconds 1;try{Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2|Out-Null;return}catch{}}
  throw 'Ollama did not start on http://127.0.0.1:11434.'
}
function Pull-Model($exe,$model){Banner "Pulling $model";& $exe pull $model;if($LASTEXITCODE -ne 0){throw "Ollama could not pull $model"}}
function Protect-Token([string]$token){ConvertTo-SecureString $token -AsPlainText -Force | ConvertFrom-SecureString}

Require-Windows
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Banner 'BridgePoint Local AI'
$hw=Get-Hardware
Write-Host ("Computer: {0}`nRAM: {1} GB`nCPU: {2}`nGPU: {3}" -f $hw.computer,$hw.ram_gb,$hw.cpu,$hw.gpu)
$choice=Choose-Models $hw
$primary=[string]$choice[0];$reviewer=[string]$choice[1];$claimLimit=[int]$choice[2]
Write-Host "Selected primary: $primary"
Write-Host "Selected reviewer: $reviewer"

$ollama=Ensure-Ollama
Start-Ollama $ollama
if(-not $SkipModelPull){Pull-Model $ollama $primary;if($reviewer -ne $primary){Pull-Model $ollama $reviewer}}

Banner 'Installing BridgePoint agent'
Invoke-WebRequest -UseBasicParsing -Uri $AgentUrl -OutFile $AgentPath
if(-not (Test-Path $AgentPath)){throw 'BridgePoint agent download failed.'}

if([string]::IsNullOrWhiteSpace($EnrollmentCode)){$EnrollmentCode=Read-Host 'Paste the one-time enrollment code from Owner Center > Local AI'}
if([string]::IsNullOrWhiteSpace($EnrollmentCode) -or $EnrollmentCode.Trim().Length -lt 24){throw 'A valid enrollment code is required.'}
$cap=@{provider='OLLAMA';primary_model=$primary;reviewer_model=$reviewer;agent_version=610;outbound_only=$true;execution_authority=$false;hardware_aware=$true}
$body=@{action='enroll';enrollment_code=$EnrollmentCode.Trim();node_name=("BridgePoint Owner PC - "+$env:COMPUTERNAME);capabilities=$cap;hardware=$hw}|ConvertTo-Json -Depth 20 -Compress
$enroll=Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType 'application/json' -Body $body -TimeoutSec 60
if(-not $enroll.ok -or -not $enroll.node_id -or -not $enroll.node_token){throw 'Enrollment did not return a usable node credential.'}
$config=[ordered]@{endpoint=$Endpoint;node_id=$enroll.node_id;token_protected=(Protect-Token ([string]$enroll.node_token));primary_model=$enroll.primary_model;reviewer_model=$enroll.reviewer_model;claim_limit=$claimLimit;installed_at=(Get-Date).ToUniversalTime().ToString('o');agent_path=$AgentPath;agent_version=610}
$config|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 $ConfigPath

Banner 'Registering automatic startup'
$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$AgentPath`""
$trigger=New-ScheduledTaskTrigger -AtLogOn
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'BridgePoint outbound-only local AI reasoning node' | Out-Null
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3

Banner 'Verification'
$secure=ConvertTo-SecureString ([string]$config.token_protected);$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try{$token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
$status=Invoke-RestMethod -Method Post -Uri $Endpoint -Headers @{'x-bridgepoint-node-token'=$token} -ContentType 'application/json' -Body (@{action='status';node_id=$config.node_id}|ConvertTo-Json -Compress) -TimeoutSec 30
if(-not $status.ok){throw 'Node enrolled but status verification failed.'}
Write-Host 'BridgePoint Local AI is enrolled and running.' -ForegroundColor Green
Write-Host "Node: $($config.node_id)"
Write-Host "Primary: $($config.primary_model)"
Write-Host "Reviewer: $($config.reviewer_model)"
Write-Host "Auto-start task: $TaskName"
Write-Host "Local files: $Root"
Write-Host 'Once enrolled, BridgePoint can use this PC for queued reasoning while ChatGPT is closed.' -ForegroundColor Green
