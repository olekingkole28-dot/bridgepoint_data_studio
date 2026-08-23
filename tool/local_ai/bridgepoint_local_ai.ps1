$ErrorActionPreference = 'Stop'
$ConfigPath = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\config.json'
$LogDir = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogPath = Join-Path $LogDir ('agent-' + (Get-Date -Format 'yyyyMMdd') + '.log')

function Write-Log([string]$Message) {
  $line = ('{0:o} {1}' -f (Get-Date), $Message)
  Add-Content -Path $LogPath -Value $line
  Write-Host $line
}
function Load-Config {
  if (-not (Test-Path $ConfigPath)) { throw "BridgePoint Local AI is not enrolled. Run install_windows.ps1 first." }
  return (Get-Content $ConfigPath -Raw | ConvertFrom-Json)
}
function Get-NodeToken($cfg) {
  $secure = ConvertTo-SecureString ([string]$cfg.token_protected)
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Invoke-BP($cfg,[string]$token,[string]$action,$payload=@{}) {
  $body = @{} + $payload
  $body.action = $action
  $body.node_id = [string]$cfg.node_id
  $json = $body | ConvertTo-Json -Depth 40 -Compress
  return Invoke-RestMethod -Method Post -Uri ([string]$cfg.endpoint) -Headers @{ 'x-bridgepoint-node-token'=$token } -ContentType 'application/json' -Body $json -TimeoutSec 60
}
function Invoke-Ollama([string]$model,[array]$messages) {
  $body = @{ model=$model; messages=$messages; stream=$false; format='json'; options=@{ temperature=0.15; num_ctx=8192 } } | ConvertTo-Json -Depth 30 -Compress
  $r = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:11434/api/chat' -ContentType 'application/json' -Body $body -TimeoutSec 900
  $text = [string]$r.message.content
  try { return ($text | ConvertFrom-Json) }
  catch { return @{ summary=$text; parse_warning='MODEL_OUTPUT_WAS_NOT_JSON' } }
}
function Build-PrimaryMessages($task) {
  $worker = $task.worker
  $system = @"
You are a local BridgePoint Intelligence reasoning worker. You are NOT the execution authority. Supabase remains the authority for policy, permissions, security, money, external actions and verification. Never claim an action happened unless the supplied evidence proves it. Never invent database state. Return JSON only with: summary, findings, recommended_actions, evidence_needed, verification_tests, risks, confidence. Keep recommended_actions safe, reversible and internal unless the task explicitly says approval exists.
Worker mission: $($worker.mission)
Worker guardrails: $($worker.guardrails | ConvertTo-Json -Depth 10 -Compress)
Worker permissions: $($worker.permissions | ConvertTo-Json -Depth 10 -Compress)
"@
  $user = "TASK TYPE: $($task.task_type)`nSECURITY CLASS: $($task.security_class)`nINPUT:`n" + ($task.input | ConvertTo-Json -Depth 30)
  return @(@{role='system';content=$system},@{role='user';content=$user})
}
function Build-ReviewerMessages($task,$primary) {
  $system = @"
You are BridgePoint's independent local reviewer. Critique the primary reasoning. Return JSON only with: verdict (APPROVE, REVISE, REJECT), issues, unsupported_claims, security_concerns, missing_evidence, required_changes, verification_tests, confidence. Reject any claim that work is complete without evidence, any credential exposure, destructive action, regulated action, unauthorized external messaging, or money movement.
"@
  $user = "ORIGINAL TASK:`n" + ($task.input | ConvertTo-Json -Depth 30) + "`nPRIMARY RESULT:`n" + ($primary | ConvertTo-Json -Depth 30)
  return @(@{role='system';content=$system},@{role='user';content=$user})
}

$cfg = Load-Config
$token = Get-NodeToken $cfg
Write-Log "BridgePoint Local AI starting. Node=$($cfg.node_id) Primary=$($cfg.primary_model) Reviewer=$($cfg.reviewer_model)"
$lastHeartbeat = [datetime]::MinValue
while ($true) {
  try {
    if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 45) {
      $cap = @{ provider='OLLAMA'; primary_model=$cfg.primary_model; reviewer_model=$cfg.reviewer_model; agent_version=610; outbound_only=$true; execution_authority=$false }
      $hw = @{ computer=$env:COMPUTERNAME; user=$env:USERNAME; os=[Environment]::OSVersion.VersionString }
      $null = Invoke-BP $cfg $token 'heartbeat' @{ capabilities=$cap; hardware=$hw }
      $lastHeartbeat = Get-Date
    }
    try { $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5 }
    catch { Write-Log 'Ollama not responding; starting ollama serve.'; Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden; Start-Sleep -Seconds 4 }

    $claim = Invoke-BP $cfg $token 'claim' @{ limit=[int]$cfg.claim_limit }
    $tasks = @($claim.tasks)
    if ($tasks.Count -eq 0) { Start-Sleep -Seconds 8; continue }

    foreach ($task in $tasks) {
      try {
        Write-Log "Reasoning task $($task.task_id) / $($task.task_type) / $($task.worker_key)"
        $primary = Invoke-Ollama ([string]$cfg.primary_model) (Build-PrimaryMessages $task)
        $reviewer = Invoke-Ollama ([string]$cfg.reviewer_model) (Build-ReviewerMessages $task $primary)
        $models = @{ provider='OLLAMA'; primary=$cfg.primary_model; reviewer=$cfg.reviewer_model; agent_version=610; computer=$env:COMPUTERNAME }
        $null = Invoke-BP $cfg $token 'submit' @{ task_id=[string]$task.task_id; primary=$primary; reviewer=$reviewer; models=$models }
        Write-Log "Submitted governed result for $($task.task_id)."
      } catch {
        $msg = $_.Exception.Message
        Write-Log "Task failed $($task.task_id): $msg"
        try { $null = Invoke-BP $cfg $token 'fail' @{ task_id=[string]$task.task_id; error=$msg } } catch { Write-Log "Could not report task failure: $($_.Exception.Message)" }
      }
    }
  } catch {
    Write-Log "Agent loop error: $($_.Exception.Message)"
    Start-Sleep -Seconds 20
  }
}
