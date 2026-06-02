# Machine-specific paths — edit if your install location changes
$script:FlutterHome = "C:\path\to\flutter"

# Auto-detect from system PATH if the configured path doesn't exist
if (-not (Test-Path $script:FlutterHome)) {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        $script:FlutterHome = Split-Path (Split-Path $flutterCmd.Source -Parent) -Parent
    }
}

$script:FlutterBin  = Join-Path $FlutterHome "bin\flutter.bat"

