Write-Host "Stopping Clinical Device processes..." -ForegroundColor Cyan
Stop-Process -Name "ClinicalDevice.Api" -Force -ErrorAction SilentlyContinue
Get-Process -Name "dart" -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "*flutter*" -or $_.CommandLine -like "*clinical_device*"
} | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "Done. Close any Chrome window from the app if it is still open." -ForegroundColor Green
