# BridgePoint owner storage readiness check
# Safe/read-only: this script DOES NOT delete files and DOES NOT start an export.
$ErrorActionPreference = 'Stop'
Write-Host "BridgePoint Storage Readiness" -ForegroundColor Cyan
Write-Host "============================="
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
  $used = $_.Used
  $free = $_.Free
  $total = $used + $free
  [PSCustomObject]@{
    Drive = $_.Name
    TotalGB = if($total){[math]::Round($total/1GB,2)}else{0}
    UsedGB = if($used){[math]::Round($used/1GB,2)}else{0}
    FreeGB = if($free){[math]::Round($free/1GB,2)}else{0}
    FreePercent = if($total){[math]::Round(($free/$total)*100,1)}else{0}
  }
} | Format-Table -AutoSize
Write-Host ""
Write-Host "Node:" -ForegroundColor Yellow
try { node --version } catch { Write-Host "Node is not installed or not on PATH." -ForegroundColor Red }
Write-Host "npm:" -ForegroundColor Yellow
try { npm --version } catch { Write-Host "npm is not installed or not on PATH." -ForegroundColor Red }
Write-Host ""
Write-Host "Largest folders under your user profile (top level only):" -ForegroundColor Yellow
Get-ChildItem $HOME -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
  $size = (Get-ChildItem $_.FullName -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  [PSCustomObject]@{Folder=$_.FullName; SizeGB=[math]::Round(($size/1GB),2)}
} | Sort-Object SizeGB -Descending | Select-Object -First 15 | Format-Table -AutoSize
Write-Host ""
Write-Host "Nothing was deleted. Use this report before any cleanup or BridgePoint full export." -ForegroundColor Green
