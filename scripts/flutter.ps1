# Run any flutter command with your SDK path, e.g.:
#   .\scripts\flutter.ps1 pub get
#   .\scripts\flutter.ps1 analyze
#   .\scripts\flutter.ps1 doctor

. "$PSScriptRoot\config.ps1"

if (-not (Test-Path $FlutterBin)) {
    Write-Error "Flutter not found at $FlutterBin"
    exit 1
}

Push-Location "$PSScriptRoot\..\frontend\clinical_device_app"
try {
    & $FlutterBin @args
} finally {
    Pop-Location
}
