param(
  [string]$EnrollmentCode = ''
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Agent = Join-Path $Root 'bridgepoint_local_ai.ps1'
$ConfigDir = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI'
$ConfigPath = Join-Path $ConfigDir 'config.json'
$Endpoint = 'https://xdfsjztwgsbmabshzsjw.supabase.co/functions/v1/bridgepoint-local-reasoning-v584'
$TaskName = 'BridgePoint Local AI'

function Has-Cmd([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Get-RamGB {
  try { return [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) }
  catch { return 0 }
}

Write-Host 'BridgePoint Local AI setup' -ForegroundColor Cyan
if (-not (Test-Path $Agent)) { throw "Missing agent file: $Agent" }
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

if (-not (Has-Cmd 'ollama')) {
  if (Has-Cmd 'winget') {
    Write-Host 'Installing Ollama...' -ForegroundColor Yellow
    & winget install -e --id Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
  } else {
    throw 'Ollama is not installed and Windows Package Manager (winget) is unavailable. Install Ollama, then rerun this script.'
  }
}

$ram = Get-RamGB
if ($ram -ge 32) {
  $PrimaryModel = 'gpt-oss:20b'
  $ReviewerModel = 'qwen3:8b'
  $ClaimLimit = 2
} elseif ($ram -ge 16) {
  $PrimaryModel = 'qwen3:8b'
  $ReviewerModel = 'deepseek-r1:8b'
  $ClaimLimit = 1
} else {
  $PrimaryModel = 'qwen3:4b'
  $ReviewerModel = 'qwen3:4b'
  $ClaimLimit = 1
}
Write-Host "Detected RAM: $ram GB" -ForegroundColor DarkGray
Write-Host "Primary: $PrimaryModel | Reviewer: $ReviewerModel" -ForegroundColor Cyan

foreach ($m in @($PrimaryModel,$ReviewerModel) | Select-Object -Unique) {
  Write-Host "Ensuring local model $m is available..." -ForegroundColor Yellow
  & ollama pull $m
  if ($LASTEXITCODE -ne 0) { throw "Ollama model pull failed: $m" }
}

if (-not $EnrollmentCode) {
  Write-Host ''
  Write-Host 'Open BridgePoint Owner Center > Local AI Setup and generate a one-time code.' -ForegroundColor Cyan
  $EnrollmentCode = Read-Host 'Paste enrollment code'
}
if ([string]::IsNullOrWhiteSpace($EnrollmentCode) -or $EnrollmentCode.Length -lt 24) { throw 'A valid one-time enrollment code is required.' }

$capabilities = @{
  provider='OLLAMA'; primary_model=$PrimaryModel; reviewer_model=$ReviewerModel;
  agent_version=610; outbound_only=$true; execution_authority=$false; hardware_aware=$true
}
$hardware = @{
  computer=$env:COMPUTERNAME; user=$env:USERNAME; ram_gb=$ram;
  os=(Get-CimInstance Win32_OperatingSystem).Caption;
  cpu=(Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name)
}
$enrollBody = @{
  action='enroll'; enrollment_code=$EnrollmentCode; node_name=("BridgePoint Owner PC - " + $env:COMPUTERNAME);
  capabilities=$capabilities; hardware=$hardware
} | ConvertTo-Json -Depth 20 -Compress
$resp = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType 'application/json' -Body $enrollBody -TimeoutSec 60
if (-not $resp.ok -or -not $resp.node_id -or -not $resp.node_token) { throw 'BridgePoint enrollment did not return a usable node credential.' }

$secure = ConvertTo-SecureString ([string]$resp.node_token) -AsPlainText -Force
$protected = ConvertFrom-SecureString $secure
$config = [ordered]@{
  endpoint=$Endpoint; node_id=[string]$resp.node_id; token_protected=$protected;
  primary_model=$PrimaryModel; reviewer_model=$ReviewerModel; claim_limit=$ClaimLimit;
  enrolled_at=(Get-Date).ToUniversalTime().ToString('o'); agent_version=610
}
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8

$PowerShellExe = (Get-Command powershell.exe).Source
$Args = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$Agent`""
$Action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $Args -WorkingDirectory $Root
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description 'BridgePoint outbound-only local AI reasoning node' -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 5

$statusBody = @{ action='status'; node_id=[string]$resp.node_id } | ConvertTo-Json -Compress
$status = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers @{ 'x-bridgepoint-node-token'=[string]$resp.node_token } -ContentType 'application/json' -Body $statusBody -TimeoutSec 30
if (-not $status.ok) { throw 'Node enrolled but status verification failed.' }

Write-Host ''
Write-Host 'BridgePoint Local AI is enrolled and started.' -ForegroundColor Green
Write-Host "Node: $($resp.node_id)" -ForegroundColor DarkGray
Write-Host "Config: $ConfigPath" -ForegroundColor DarkGray
Write-Host "Scheduled task: $TaskName" -ForegroundColor DarkGray
Write-Host 'You can close ChatGPT after this. The Windows task keeps local reasoning running while this PC is on and signed in.' -ForegroundColor Green
