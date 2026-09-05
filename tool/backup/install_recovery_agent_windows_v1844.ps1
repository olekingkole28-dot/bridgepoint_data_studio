param(
  [switch]$ConfigureBackup,
  [switch]$StartNow
)
$ErrorActionPreference='Stop'
$Here=$PSScriptRoot
$Agent=Join-Path $Here 'bridgepoint_recovery_agent_v1844.py'
$Configure=Join-Path $Here 'configure_backup_windows.ps1'
$NodeState=Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\node.json'
if(-not(Test-Path $Agent)){throw "Recovery agent not found: $Agent"}
if(-not(Test-Path $NodeState)){throw "BridgePoint local node is not enrolled on this Windows user yet: $NodeState"}
$Python=(Get-Command python -ErrorAction SilentlyContinue)
if(-not $Python){$Python=(Get-Command py -ErrorAction SilentlyContinue)}
if(-not $Python){throw 'Python 3 is required.'}
$Py=$Python.Source
if($ConfigureBackup){
  if(-not(Test-Path $Configure)){throw "Backup configuration script not found: $Configure"}
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Configure
  if($LASTEXITCODE -ne 0){throw 'Backup configuration did not complete.'}
}
$Task='BridgePoint Recovery Agent v1844'
$TaskCmd='"'+$Py+'" "'+$Agent+'"'
schtasks /Create /TN $Task /SC ONLOGON /TR $TaskCmd /RL LIMITED /F | Out-Null
Write-Host "Installed scheduled task: $Task" -ForegroundColor Green
Write-Host 'The recovery worker is outbound-only and uses the existing local node token; it does not store a Supabase service-role key.' -ForegroundColor Green
if($StartNow){
  Start-Process -FilePath $Py -ArgumentList @($Agent) -WindowStyle Minimized
  Write-Host 'Recovery agent started.' -ForegroundColor Green
}else{
  Write-Host 'Use -StartNow or sign out/in to start it.' -ForegroundColor Yellow
}
