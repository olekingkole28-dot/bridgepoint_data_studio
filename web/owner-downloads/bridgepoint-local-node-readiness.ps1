# BridgePoint local Node readiness helper
# This script DOES NOT start the database export.
$ErrorActionPreference='Stop'
Write-Host "BridgePoint Local Node Readiness" -ForegroundColor Cyan
Write-Host "================================"
$nodeOk=$false
try {
  $current=(node --version).Trim()
  Write-Host "Current Node: $current" -ForegroundColor Yellow
  $nodeOk=$true
} catch {
  Write-Host "Node is missing from PATH." -ForegroundColor Red
}
Write-Host ""
Write-Host "Recommended owner workflow:" -ForegroundColor Yellow
Write-Host "1. Finish BridgePoint build/data sprint."
Write-Host "2. Do NOT start final export yet."
Write-Host "3. Run bridgepoint-storage-check.ps1 and make enough free space."
Write-Host "4. Upgrade Node to the current supported release/LTS from the official Node.js source or your Windows package manager."
Write-Host "5. Close and reopen PowerShell, then run: node --version"
Write-Host "6. Only after the owner marks the build/export READY should the final export launcher be used."
Write-Host ""
if(Get-Command winget -ErrorAction SilentlyContinue){
  Write-Host "winget is available. To REVIEW available Node packages (does not install):" -ForegroundColor Green
  Write-Host "  winget search OpenJS.NodeJS"
  Write-Host "When you intentionally choose to upgrade, use the exact official package shown by winget rather than a random download link."
} else {
  Write-Host "winget was not detected. Use the official Node.js installer when you are ready to upgrade." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Export remains intentionally separate from this script." -ForegroundColor Green
