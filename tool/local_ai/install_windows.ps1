$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host 'BridgePoint Local AI setup' -ForegroundColor Cyan

function Has-Cmd($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

if (-not (Has-Cmd 'ollama')) {
  Write-Host 'Installing Ollama...' -ForegroundColor Yellow
  irm https://ollama.com/install.ps1 | iex
}

if (-not (Has-Cmd 'python')) {
  if (Has-Cmd 'py') {
    $Python = 'py'
  } else {
    throw 'Python 3 is required. Install Python 3, reopen PowerShell, then run this script again.'
  }
} else {
  $Python = 'python'
}

Write-Host 'Ensuring primary model gpt-oss:20b is available...' -ForegroundColor Yellow
& ollama pull gpt-oss:20b

# Reviewer is intentionally smaller so it can fit on more owner machines.
# If this pull fails, the Python runner falls back to a second adversarial pass on the primary.
try {
  Write-Host 'Ensuring reviewer model qwen3:8b is available...' -ForegroundColor Yellow
  & ollama pull qwen3:8b
} catch {
  Write-Warning 'Reviewer model pull failed; primary-model critic fallback will remain active.'
}

$Runner = Join-Path $Root 'bridgepoint_local_node_v590.py'
if (-not (Test-Path $Runner)) { throw "Missing runner: $Runner" }

$TaskName = 'BridgePoint Local AI'
$PythonExe = if ($Python -eq 'py') { (Get-Command py).Source } else { (Get-Command python).Source }
$Args = if ($Python -eq 'py') { "-3 `"$Runner`"" } else { "`"$Runner`"" }

Write-Host ''
Write-Host 'You will need a one-time enrollment code from:' -ForegroundColor Cyan
Write-Host 'https://bridgepointintelligence.online/owner/completion/' -ForegroundColor White
Write-Host 'The runner stores only its node token in your Windows user profile. It does not store the Supabase service-role key.' -ForegroundColor DarkGray
Write-Host ''

# First run interactively so enrollment can be completed.
if ($Python -eq 'py') {
  & $PythonExe -3 $Runner
} else {
  & $PythonExe $Runner
}

# If the interactive process exits, register a logon task so subsequent starts are automatic.
$Action = New-ScheduledTaskAction -Execute $PythonExe -Argument $Args -WorkingDirectory $Root
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 20 -RestartInterval (New-TimeSpan -Minutes 1)
try {
  Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description 'BridgePoint outbound-only local reasoning node' -Force | Out-Null
  Write-Host "Registered '$TaskName' to start automatically at Windows logon." -ForegroundColor Green
} catch {
  Write-Warning "Could not register startup task automatically: $($_.Exception.Message)"
}
