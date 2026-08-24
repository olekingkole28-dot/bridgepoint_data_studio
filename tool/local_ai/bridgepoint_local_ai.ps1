# BridgePoint Local Agent - signed channel live-artifact
$ErrorActionPreference = 'Stop'
$AgentVersion = 718
$ConfigPath = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\config.json'
$BackupConfigPath = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\backup-config.json'
$AgentPath = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\bridgepoint_local_ai.ps1'
$BackupToolDir = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\backup-tools'
$LogDir = Join-Path $env:LOCALAPPDATA 'BridgePoint\LocalAI\logs'
$AgentUrl = 'https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/live-artifact/downloads/local-ai/bridgepoint_local_ai.ps1'
$BackupBaseUrl = 'https://raw.githubusercontent.com/olekingkole28-dot/bridgepoint-live/live-artifact/downloads/backup'
New-Item -ItemType Directory -Force -Path $LogDir,$BackupToolDir | Out-Null
$LogPath = Join-Path $LogDir ('agent-' + (Get-Date -Format 'yyyyMMdd') + '.log')

function Write-Log([string]$Message) {
  $line = ('{0:o} {1}' -f (Get-Date), $Message)
  Add-Content -Path $LogPath -Value $line
  Write-Host $line
}
function Load-Config {
  if (-not (Test-Path $ConfigPath)) { throw 'BridgePoint Local AI is not enrolled. Run install_windows.ps1 first.' }
  return (Get-Content $ConfigPath -Raw | ConvertFrom-Json)
}
function Unprotect([string]$protected) {
  if ([string]::IsNullOrWhiteSpace($protected)) { return '' }
  $secure = ConvertTo-SecureString $protected
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Get-NodeToken($cfg) { return Unprotect ([string]$cfg.token_protected) }
function Invoke-BP($cfg,[string]$token,[string]$action,$payload=@{}) {
  $body = @{} + $payload
  $body.action = $action
  $body.node_id = [string]$cfg.node_id
  $json = $body | ConvertTo-Json -Depth 40 -Compress
  return Invoke-RestMethod -Method Post -Uri ([string]$cfg.endpoint) -Headers @{ 'x-bridgepoint-node-token'=$token } -ContentType 'application/json' -Body $json -TimeoutSec 90
}
function Has-Cmd([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Get-BackupRuntime {
  $r=[ordered]@{ configured=$false; backup_authority=$false; restore_test_authority=$false; destination=''; config=$null; missing=@() }
  if (-not (Test-Path $BackupConfigPath)) { return $r }
  try {
    $c=Get-Content $BackupConfigPath -Raw | ConvertFrom-Json
    $r.config=$c; $r.destination=[string]$c.destination; $r.configured=[bool]$c.backup_enabled
    $required=@('supabase','pg_dump','pg_restore','rclone','git')
    $r.missing=@($required | Where-Object { -not (Has-Cmd $_) })
    $hasProtected= -not [string]::IsNullOrWhiteSpace([string]$c.db_url_protected) -and -not [string]::IsNullOrWhiteSpace([string]$c.s3_access_key_protected) -and -not [string]::IsNullOrWhiteSpace([string]$c.s3_secret_key_protected)
    if($r.configured -and $hasProtected -and $r.missing.Count -eq 0){
      # Prove DPAPI material can be decrypted by this Windows user before advertising authority.
      $d=Unprotect ([string]$c.db_url_protected); $a=Unprotect ([string]$c.s3_access_key_protected); $s=Unprotect ([string]$c.s3_secret_key_protected)
      $r.backup_authority=($d -match '^postgres(ql)?://' -and $a.Length -gt 0 -and $s.Length -gt 0)
      $d=$null;$a=$null;$s=$null
    }
    if($r.backup_authority -and [bool]$c.restore_test_enabled -and (Has-Cmd 'psql') -and -not [string]::IsNullOrWhiteSpace([string]$c.restore_test_db_url_protected){
      $x=Unprotect ([string]$c.restore_test_db_url_protected)
      $r.restore_test_authority=($x -match '^postgres(ql)?://' -and $x -notmatch 'xdfsjztwgsbmabshzsjw')
      $x=$null
    }
  } catch { Write-Log ('Backup config unavailable: '+$_.Exception.Message) }
  return $r
}
function Ensure-BackupTools {
  $map=[ordered]@{
    'bridgepoint_full_export_windows.ps1'='bridgepoint_full_export_windows.ps1'
    'bridgepoint_verify_backup_windows.ps1'='bridgepoint_verify_backup_windows.ps1'
    'bridgepoint_restore_test_windows.ps1'='bridgepoint_restore_test_windows.ps1'
  }
  foreach($name in $map.Keys){
    $dest=Join-Path $BackupToolDir $name
    $url="$BackupBaseUrl/$($map[$name])"
    if(-not(Test-Path $dest) -or ((Get-Date)-(Get-Item $dest).LastWriteTime).TotalHours -ge 12){
      $tmp=$dest+'.tmp'
      Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 -Uri $url -OutFile $tmp
      $txt=Get-Content $tmp -Raw
      if($txt.Length -lt 500 -or $txt -notmatch 'BridgePoint'){Remove-Item $tmp -Force -ErrorAction SilentlyContinue;throw "Rejected invalid backup tool payload: $name"}
      Move-Item $tmp $dest -Force
    }
  }
}
function Get-LatestBackup([string]$destination) {
  if(-not(Test-Path $destination)){return $null}
  return Get-ChildItem $destination -Directory -Filter 'BridgePoint-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function Invoke-BackupJob($cfg,[string]$token,$job,$runtime) {
  $id=[string]$job.job_id; $op=([string]$job.operation).ToUpperInvariant()
  if($op -notin @('EXPORT','VERIFY','RESTORE_TEST')){throw "Operation is not allowlisted: $op"}
  Ensure-BackupTools
  $dest=[string]$runtime.destination
  if([string]::IsNullOrWhiteSpace($dest)){throw 'Backup destination is not configured locally.'}
  Write-Log "Backup job $id / $op claimed."
  try {
    if($op -eq 'EXPORT'){
      if(-not$runtime.backup_authority){throw 'Local backup authority is not ready.'}
      $c=$runtime.config
      $env:BRIDGEPOINT_BACKUP_DB_URL=Unprotect ([string]$c.db_url_protected)
      $env:BRIDGEPOINT_BACKUP_S3_ACCESS_KEY_ID=Unprotect ([string]$c.s3_access_key_protected)
      $env:BRIDGEPOINT_BACKUP_S3_SECRET_ACCESS_KEY=Unprotect ([string]$c.s3_secret_key_protected)
      $env:BRIDGEPOINT_BACKUP_DESTINATION=$dest
      $script=Join-Path $BackupToolDir 'bridgepoint_full_export_windows.ps1'
      $out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Destination $dest -NonInteractive 2>&1
      if($LASTEXITCODE -ne 0){throw "Export script exited $LASTEXITCODE: $($out | Select-Object -Last 8 | Out-String)"}
      $latest=Get-LatestBackup $dest; if(-not$latest){throw 'Export completed but no backup folder was found.'}
      $manifest=Get-Content (Join-Path $latest.FullName 'manifest.json') -Raw | ConvertFrom-Json
      $result=@{ backup_name=$latest.Name; exported_at=$manifest.exported_at; archive_bytes=$manifest.primary_database_archive_bytes; storage_included=$manifest.storage_included; git_mirrors_included=$manifest.git_mirrors_included; format_version=$manifest.format_version }
    } elseif($op -eq 'VERIFY'){
      $latest=Get-LatestBackup $dest; if(-not$latest){throw 'No local backup exists to verify.'}
      $script=Join-Path $BackupToolDir 'bridgepoint_verify_backup_windows.ps1'
      $out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -BackupRoot $latest.FullName 2>&1
      if($LASTEXITCODE -ne 0){throw "Verify script exited $LASTEXITCODE: $($out | Select-Object -Last 8 | Out-String)"}
      $v=Get-Content (Join-Path $latest.FullName 'verification.json') -Raw | ConvertFrom-Json
      $result=@{ backup_name=$latest.Name; verified=[bool]$v.verified; verified_at=$v.verified_at; archive_bytes=$v.archive_bytes; checksums=$v.checksums; pg_restore_catalog=$v.pg_restore_catalog }
    } else {
      if(-not$runtime.restore_test_authority){throw 'Restore-test authority is not configured locally.'}
      $latest=Get-LatestBackup $dest; if(-not$latest){throw 'No local backup exists for restore testing.'}
      $c=$runtime.config; $env:BRIDGEPOINT_RESTORE_TEST_DB_URL=Unprotect ([string]$c.restore_test_db_url_protected)
      if($env:BRIDGEPOINT_RESTORE_TEST_DB_URL -match 'xdfsjztwgsbmabshzsjw'){throw 'Production restore target blocked.'}
      $script=Join-Path $BackupToolDir 'bridgepoint_restore_test_windows.ps1'
      $out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -BackupRoot $latest.FullName -SkipData -NonInteractive 2>&1
      if($LASTEXITCODE -ne 0){throw "Restore-test script exited $LASTEXITCODE: $($out | Select-Object -Last 8 | Out-String)"}
      $v=Get-Content (Join-Path $latest.FullName 'restore-test.json') -Raw | ConvertFrom-Json
      $result=@{ backup_name=$latest.Name; restore_test_passed=[bool]$v.restore_test_passed; tested_at=$v.tested_at; target_host=$v.target_host; schema_only=$v.schema_only }
    }
    $null=Invoke-BP $cfg $token 'backup_complete' @{job_id=$id;result=$result}
    Write-Log "Backup job $id / $op completed."
  } catch {
    $msg=$_.Exception.Message
    try{$null=Invoke-BP $cfg $token 'backup_fail' @{job_id=$id;error=$msg.Substring(0,[Math]::Min(1600,$msg.Length));result=@{operation=$op;agent_version=$AgentVersion}}}catch{}
    Write-Log "Backup job $id / $op failed: $msg"
  } finally {
    Remove-Item Env:BRIDGEPOINT_BACKUP_DB_URL,Env:BRIDGEPOINT_BACKUP_S3_ACCESS_KEY_ID,Env:BRIDGEPOINT_BACKUP_S3_SECRET_ACCESS_KEY,Env:BRIDGEPOINT_BACKUP_DESTINATION,Env:BRIDGEPOINT_RESTORE_TEST_DB_URL -ErrorAction SilentlyContinue
  }
}
function Invoke-Ollama([string]$model,[array]$messages) {
  $body = @{ model=$model; messages=$messages; stream=$false; format='json'; options=@{ temperature=0.15; num_ctx=8192 } } | ConvertTo-Json -Depth 30 -Compress
  $r = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:11434/api/chat' -ContentType 'application/json' -Body $body -TimeoutSec 900
  $text = [string]$r.message.content
  try { return ($text | ConvertFrom-Json) } catch { return @{ summary=$text; parse_warning='MODEL_OUTPUT_WAS_NOT_JSON' } }
}
function Build-PrimaryMessages($task) {
  $worker=$task.worker
  $system=@"
You are a local BridgePoint Intelligence reasoning worker. You are NOT the execution authority. Supabase remains the authority for policy, permissions, security, money, external actions and verification. Never claim an action happened unless supplied evidence proves it. Never invent database state. Return JSON only with: summary, findings, recommended_actions, evidence_needed, verification_tests, risks, confidence. Keep recommended_actions safe, reversible and internal unless the task explicitly says approval exists.
Worker mission: $($worker.mission)
Worker guardrails: $($worker.guardrails | ConvertTo-Json -Depth 10 -Compress)
Worker permissions: $($worker.permissions | ConvertTo-Json -Depth 10 -Compress)
"@
  return @(@{role='system';content=$system},@{role='user';content=("TASK TYPE: $($task.task_type)`nSECURITY CLASS: $($task.security_class)`nINPUT:`n"+($task.input|ConvertTo-Json -Depth 30))})
}
function Build-ReviewerMessages($task,$primary) {
  $system="You are BridgePoint's independent local reviewer. Critique the primary reasoning. Return JSON only with: verdict (APPROVE, REVISE, REJECT), issues, unsupported_claims, security_concerns, missing_evidence, required_changes, verification_tests, confidence. Reject any claim that work is complete without evidence, any credential exposure, destructive action, regulated action, unauthorized external messaging, or money movement."
  return @(@{role='system';content=$system},@{role='user';content=("ORIGINAL TASK:`n"+($task.input|ConvertTo-Json -Depth 30)+"`nPRIMARY RESULT:`n"+($primary|ConvertTo-Json -Depth 30))})
}
function Test-AgentUpdate {
  try {
    if(-not(Test-Path $AgentPath)){return $false}
    $tmp=$AgentPath+'.update'
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 45 -Uri $AgentUrl -OutFile $tmp
    $txt=Get-Content $tmp -Raw
    if($txt -notmatch '# BridgePoint Local Agent - signed channel live-artifact' -or $txt -notmatch '\$AgentVersion\s*=\s*(\d+)'){Remove-Item $tmp -Force -ErrorAction SilentlyContinue;return $false}
    $remote=[int]$Matches[1]
    if($remote -le $AgentVersion){Remove-Item $tmp -Force -ErrorAction SilentlyContinue;return $false}
    Move-Item $tmp $AgentPath -Force
    Write-Log "Installed BridgePoint Local Agent update $remote; restarting."
    Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$AgentPath`"" -WindowStyle Hidden
    return $true
  } catch { Write-Log ('Agent update check failed safely: '+$_.Exception.Message); return $false }
}

$cfg=Load-Config
$token=Get-NodeToken $cfg
Write-Log "BridgePoint Local AI starting. Node=$($cfg.node_id) Agent=$AgentVersion Primary=$($cfg.primary_model) Reviewer=$($cfg.reviewer_model)"
$lastHeartbeat=[datetime]::MinValue; $lastUpdateCheck=[datetime]::MinValue
while($true){
  try {
    if(((Get-Date)-$lastUpdateCheck).TotalHours -ge 6){$lastUpdateCheck=Get-Date;if(Test-AgentUpdate){exit 0}}
    $backup=Get-BackupRuntime
    if(((Get-Date)-$lastHeartbeat).TotalSeconds -ge 45){
      $cap=@{provider='OLLAMA';primary_model=$cfg.primary_model;reviewer_model=$cfg.reviewer_model;agent_version=$AgentVersion;outbound_only=$true;execution_authority=$false;backup_authority=[bool]$backup.backup_authority;restore_test_authority=[bool]$backup.restore_test_authority;backup_protocol='ALLOWLIST_V717'}
      $hw=@{computer=$env:COMPUTERNAME;os=[Environment]::OSVersion.VersionString}
      $null=Invoke-BP $cfg $token 'heartbeat' @{capabilities=$cap;hardware=$hw};$lastHeartbeat=Get-Date
    }
    if($backup.backup_authority){
      $bc=Invoke-BP $cfg $token 'backup_claim' @{}
      if($bc.job){Invoke-BackupJob $cfg $token $bc.job $backup}
    }
    try{$null=Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5}catch{Write-Log 'Ollama not responding; starting ollama serve.';Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden;Start-Sleep -Seconds 4}
    $claim=Invoke-BP $cfg $token 'claim' @{limit=[int]$cfg.claim_limit};$tasks=@($claim.tasks)
    foreach($task in $tasks){
      try{
        Write-Log "Reasoning task $($task.task_id) / $($task.task_type) / $($task.worker_key)"
        $primary=Invoke-Ollama ([string]$cfg.primary_model) (Build-PrimaryMessages $task)
        $reviewer=Invoke-Ollama ([string]$cfg.reviewer_model) (Build-ReviewerMessages $task $primary)
        $models=@{provider='OLLAMA';primary=$cfg.primary_model;reviewer=$cfg.reviewer_model;agent_version=$AgentVersion;computer=$env:COMPUTERNAME}
        $null=Invoke-BP $cfg $token 'submit' @{task_id=[string]$task.task_id;primary=$primary;reviewer=$reviewer;models=$models};Write-Log "Submitted governed result for $($task.task_id)."
      }catch{$msg=$_.Exception.Message;Write-Log "Task failed $($task.task_id): $msg";try{$null=Invoke-BP $cfg $token 'fail' @{task_id=[string]$task.task_id;error=$msg}}catch{}}
    }
    if($tasks.Count -eq 0){Start-Sleep -Seconds 8}
  } catch { Write-Log "Agent loop error: $($_.Exception.Message)";Start-Sleep -Seconds 20 }
}
