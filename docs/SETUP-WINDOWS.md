# Windows setup notes

## Verified on your machine

| Tool | Status |
|------|--------|
| .NET SDK | 8.0+ |
| Flutter | 3.44.0+ (configured in `scripts\config.ps1` or added to system PATH) |
| API build | OK (targets `net8.0`) |
| API smoke test | Login + devices OK |

## Run everything in **Cursor terminal**

### 1. Open the terminal panel

- Menu: **View → Terminal**
- Shortcut: **Ctrl + `** (backtick, key above Tab)

### 2. Open the project folder in the terminal

The terminal should start in your project root. If not:

```powershell
cd "C:\path\to\Clinical Device Management System"
```

### 3. Split into two terminals (backend + Flutter)

- Click the **split terminal** icon (split pane) in the terminal panel, **or**
- **Terminal → New Terminal** and drag tabs side by side

**Terminal 1 (left or first tab) — API:**

```powershell
.\scripts\run-backend.ps1
```

Wait until you see: `Now listening on: http://localhost:5000`

**Terminal 2 (second tab) — Flutter / Chrome:**

```powershell
.\scripts\run-frontend.ps1
```

Chrome opens — that is the app. Keep **both** terminals running.

### 4. While Flutter terminal is focused

| Key | Action |
|-----|--------|
| `r` | Hot reload (after saving code changes) |
| `R` | Hot restart |
| `q` | Quit Flutter and close the debug session |

Click inside the **Flutter terminal** before pressing these keys.

### 5. Stop everything

In any Cursor terminal:

```powershell
.\scripts\stop-all.ps1
```

Or press **`q`** in the Flutter terminal, then **Ctrl+C** in the backend terminal.

### 6. Check the API (no extra terminal needed)

Open in browser: http://localhost:5000/swagger

---

## Run the backend (Terminal 1)

```powershell
.\scripts\run-backend.ps1
```

Swagger: http://localhost:5000/swagger

Uses **SQLite** in Development (`clinical_device.db` in the API folder).

## Run the Flutter app (Terminal 2)

```powershell
.\scripts\run-frontend.ps1
```

Or use the wrapper (same path, any flutter command):

```powershell
.\scripts\flutter.ps1 doctor
.\scripts\flutter.ps1 run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

### If Flutter fails with symlink / OneDrive errors

The project is under **OneDrive**, which often locks `ios/Flutter/ephemeral` and `macos/Flutter/ephemeral`.

**Fix (pick one):**

1. **Move the repo** to a non-synced path, e.g. `C:\dev\Clinical-Device-Management-System`
2. **Pause OneDrive sync**, then delete:
   - `frontend\clinical_device_app\ios\Flutter\ephemeral`
   - `frontend\clinical_device_app\macos\Flutter\ephemeral`
3. **Enable Developer Mode** (required for plugin symlinks):
   - Settings → System → For developers → **Developer Mode** ON
   - Or run: `start ms-settings:developers`

### Add Flutter to PATH (optional)

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\path\to\flutter\bin", "User")
```

Restart the terminal after changing PATH.

## Docker (optional, for SQL Server + assignment docker-compose)

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), restart, then:

```powershell
docker compose up --build
```

Set `DatabaseProvider` to `SqlServer` in `appsettings` when using Docker SQL.

## Demo credentials

- `clinician` / `Clinician123!`
- `admin` / `Admin123!`
- `tech` / `Tech123!`
