Write-Host "Stopping API if running..." -ForegroundColor Cyan
Stop-Process -Name "ClinicalDevice.Api" -Force -ErrorAction SilentlyContinue

$db = Join-Path $PSScriptRoot "..\backend\ClinicalDevice.Api\clinical_device.db"
$wal = "$db-wal"
$shm = "$db-shm"

foreach ($f in @($db, $wal, $shm)) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        Write-Host "Deleted $f" -ForegroundColor Yellow
    }
}

Write-Host "Database reset. Run .\scripts\run-backend.ps1 to recreate and seed." -ForegroundColor Green
