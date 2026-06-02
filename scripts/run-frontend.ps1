param(
    [switch]$Windows
)

. "$PSScriptRoot\config.ps1"

if (-not (Test-Path $FlutterBin)) {
    Write-Error "Flutter not found at $FlutterBin. Update scripts\config.ps1"
    exit 1
}

Set-Location "$PSScriptRoot\..\frontend\clinical_device_app"
Write-Host "Flutter: $FlutterHome" -ForegroundColor DarkGray

$devices = & $FlutterBin devices 2>&1 | Out-String

# Default to Chrome (no Developer Mode / VS symlinks required). Use -Windows for desktop app.
if ($Windows -and ($devices -match "windows.*desktop")) {
    $target = "windows"
    Write-Host "Using Windows desktop build." -ForegroundColor Yellow
    Write-Host "If build fails, enable Developer Mode: start ms-settings:developers" -ForegroundColor Yellow
} elseif ($devices -match "chrome") {
    $target = "chrome"
} elseif ($devices -match "windows.*desktop") {
    Write-Host "Chrome not found; falling back to Windows (enable Developer Mode if build fails)." -ForegroundColor Yellow
    $target = "windows"
} else {
    Write-Error "No Chrome or Windows device found. Run: flutter doctor"
    exit 1
}

Write-Host ('Starting app on ' + $target + ' (API http://localhost:5000)') -ForegroundColor Cyan
& $FlutterBin run -d $target --dart-define=API_BASE_URL=http://localhost:5000
