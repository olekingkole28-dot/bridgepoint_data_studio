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
$RunValueName='BridgePoint Local AI'

function Banner($x){Write-Host "`n=== $x ===" -ForegroundColor Cyan}
function Require-Windows {
  if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows.' }
  if ([Environment]::OSVersion.Version.Major -lt 10) { throw 'BridgePoint Local AI requires Windows 10 or newer.' }
}
function Resolve-Ollama {
  $cmd=Get-Command ollama -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if($cmd){
    $candidate=$null
    if($cmd.Path){$candidate=[string]$cmd.Path}elseif($cmd.Source){$candidate=[string]$cmd.Source}
    if($candidate -and (Test-Path $candidate)){return [string]$candidate}
  }
  $known=@(
    (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Programs\Ollama\ollama.exe'),
    (Join-Path $env:ProgramFiles 'Ollama\ollama.exe')
  )
  foreach($p in $known){if($p -and (Test-Path $p)){return [string]$p}}
  return $null
}
function Ensure-Ollama {
  $o=Resolve-Ollama
  if($o){Write-Host "Ollama found: $o" -ForegroundColor Green;return [string]$o}
  Banner 'Installing Ollama'
  try {
    $script=(Invoke-WebRequest -UseBasicParsing -TimeoutSec 45 'https://ollama.com/install.ps1').Content
    & ([scriptblock]::Create($script)) | Out-Host
  } catch {
    Write-Warning "Direct Ollama installer did not complete cleanly: $($_.Exception.Message)"
    $winget=Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($winget){
      & ([string]$winget.Path) install --id Ollama.Ollama -e --accept-package-agreements --accept-source-agreements | Out-Host
      if($LASTEXITCODE -ne 0){throw "winget could not install Ollama (exit $LASTEXITCODE)."}
    } else {
      throw 'Could not install Ollama automatically. Install Ollama for Windows, then rerun this BridgePoint installer.'
    }
  }
  Start-Sleep -Seconds 3
  $o=Resolve-Ollama
  if(-not $o){throw 'Ollama appears installed but ollama.exe was not found. Close this window, reopen the BridgePoint installer, and it will detect the completed Ollama install.'}
  Write-Host "Ollama ready: $o" -ForegroundColor Green
  return [string]$o
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
function Start-Ollama([string]$exe){
  try{Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3|Out-Null;Write-Host 'Ollama service is already running.' -ForegroundColor Green;return}catch{}
  if([string]::IsNullOrWhiteSpace($exe) -or -not (Test-Path $exe)){throw "Ollama executable path is invalid: $exe"}
  Start-Process -FilePath $exe -ArgumentList 'serve' -WindowStyle Hidden
  for($i=0;$i -lt 30;$i++){Start-Sleep -Seconds 1;try{Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2|Out-Null;Write-Host 'Ollama service started.' -ForegroundColor Green;return}catch{}}
  throw 'Ollama installed, but its local service did not start on http://127.0.0.1:11434.'
}
function Test-ModelInstalled([string]$model){
  try{
    $tags=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5
    foreach($m in @($tags.models)){if(([string]$m.name) -eq $model -or ([string]$m.model) -eq $model){return $true}}
  }catch{}
  return $false
}
function Pull-Model([string]$exe,[string]$model){
  if(Test-ModelInstalled $model){Write-Host "Model already present: $model" -ForegroundColor Green;return}
  Banner "Pulling $model"
  & $exe pull $model | Out-Host
  if($LASTEXITCODE -ne 0){throw "Ollama could not pull $model"}
}
function Protect-Token([string]$token){ConvertTo-SecureString $token -AsPlainText -Force | ConvertFrom-SecureString}
function Unprotect-Token([string]$protected){
  $secure=ConvertTo-SecureString $protected
  $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
}
function Test-ExistingEnrollment {
  if(-not (Test-Path $ConfigPath)){return $null}
  try{
    $existing=Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if(-not $existing.node_id -or -not $existing.token_protected){return $null}
    $token=Unprotect-Token ([string]$existing.token_protected)
    $status=Invoke-RestMethod -Method Post -Uri $Endpoint -Headers @{'x-bridgepoint-node-token'=$token} -ContentType 'application/json' -Body (@{action='status';node_id=[string]$existing.node_id}|ConvertTo-Json -Compress) -TimeoutSec 20
    if($status.ok){
      Write-Host "Existing BridgePoint enrollment found: $($existing.node_id)" -ForegroundColor Green
      return $existing
    }
  }catch{
    Write-Warning 'Existing local enrollment could not be validated; a new Owner Center code will be requested.'
  }
  return $null
}
function Test-IsElevated {
  try{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }catch{return $false}
}
function Register-AutoStart([string]$agentPath){
  $args="-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$agentPath`""
  if(Test-IsElevated){
    try{
      $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
      $trigger=New-ScheduledTaskTrigger -AtLogOn
      $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
      Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'BridgePoint outbound-only local AI reasoning node' | Out-Null
      Write-Host "Auto-start registered with Windows Task Scheduler: $TaskName" -ForegroundColor Green
      return 'SCHEDULED_TASK'
    }catch{
      Write-Warning "Task Scheduler registration was blocked; switching to per-user startup. $($_.Exception.Message)"
    }
  }
  $runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  New-Item -Path $runPath -Force | Out-Null
  $runCommand="powershell.exe $args"
  New-ItemProperty -Path $runPath -Name $RunValueName -Value $runCommand -PropertyType String -Force | Out-Null
  Write-Host 'Auto-start registered for this Windows user (no administrator permission required).' -ForegroundColor Green
  return 'HKCU_RUN'
}
function Start-AgentNow([string]$agentPath){
  $arg="-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$agentPath`""
  Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Hidden
}

Require-Windows
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Banner 'BridgePoint Local AI'
$hw=Get-Hardware
Write-Host ("Computer: {0}`nRAM: {1} GB`nCPU: {2}`nGPU: {3}" -f $hw.computer,$hw.ram_gb,$hw.cpu,$hw.gpu)
$choice=Choose-Models $hw
$primary=[string]$choice[0];$reviewer=[string]$choice[1];$claimLimit=[int]$choice[2]
Write-Host "Selected primary: $primary"
Write-Host "Selected reviewer: $reviewer"
$ollama=[string](Ensure-Ollama)
Start-Ollama -exe $ollama
if(-not $SkipModelPull){Pull-Model -exe $ollama -model $primary;if($reviewer -ne $primary){Pull-Model -exe $ollama -model $reviewer}}

Banner 'Installing BridgePoint agent'
Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 -Uri $AgentUrl -OutFile $AgentPath
if(-not (Test-Path $AgentPath)){throw 'BridgePoint agent download failed.'}

$config=Test-ExistingEnrollment
if(-not $config){
  if([string]::IsNullOrWhiteSpace($EnrollmentCode)){$EnrollmentCode=Read-Host 'Paste the one-time enrollment code from the main Owner Center'}
  if([string]::IsNullOrWhiteSpace($EnrollmentCode) -or $EnrollmentCode.Trim().Length -lt 24){throw 'A valid enrollment code is required.'}
  $cap=@{provider='OLLAMA';primary_model=$primary;reviewer_model=$reviewer;agent_version=625;outbound_only=$true;execution_authority=$false;hardware_aware=$true}
  $body=@{action='enroll';enrollment_code=$EnrollmentCode.Trim();node_name=("BridgePoint Owner PC - "+$env:COMPUTERNAME);capabilities=$cap;hardware=$hw}|ConvertTo-Json -Depth 20 -Compress
  $enroll=Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType 'application/json' -Body $body -TimeoutSec 60
  if(-not $enroll.ok -or -not $enroll.node_id -or -not $enroll.node_token){throw 'Enrollment did not return a usable node credential.'}
  $config=[ordered]@{endpoint=$Endpoint;node_id=$enroll.node_id;token_protected=(Protect-Token ([string]$enroll.node_token));primary_model=$enroll.primary_model;reviewer_model=$enroll.reviewer_model;claim_limit=$claimLimit;installed_at=(Get-Date).ToUniversalTime().ToString('o');agent_path=$AgentPath;agent_version=625}
  $config|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 $ConfigPath
}else{
  $config.agent_path=$AgentPath
  $config.agent_version=625
  $config|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 $ConfigPath
}

Banner 'Registering automatic startup'
$startupMode=Register-AutoStart -agentPath $AgentPath
Start-AgentNow -agentPath $AgentPath
Start-Sleep -Seconds 4

Banner 'Verification'
$token=Unprotect-Token ([string]$config.token_protected)
$status=Invoke-RestMethod -Method Post -Uri $Endpoint -Headers @{'x-bridgepoint-node-token'=$token} -ContentType 'application/json' -Body (@{action='status';node_id=[string]$config.node_id}|ConvertTo-Json -Compress) -TimeoutSec 30
if(-not $status.ok){throw 'Node is configured locally but status verification failed.'}
Write-Host 'BridgePoint Local AI is enrolled and running.' -ForegroundColor Green
Write-Host "Node: $($config.node_id)"
Write-Host "Primary: $($config.primary_model)"
Write-Host "Reviewer: $($config.reviewer_model)"
Write-Host "Auto-start mode: $startupMode"
Write-Host "Local files: $Root"
Write-Host 'You can close this window. BridgePoint can use this PC for queued reasoning while ChatGPT is closed.' -ForegroundColor Green
