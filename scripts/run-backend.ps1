$env:ASPNETCORE_ENVIRONMENT = "Development"
Set-Location "$PSScriptRoot\..\backend\ClinicalDevice.Api"
Write-Host "Starting API at http://localhost:5000 (SQLite dev DB)" -ForegroundColor Cyan
dotnet run --urls "http://localhost:5000"
