# Clinical Device Management System

Full-stack assignment implementation: **Flutter 3** client + **ASP.NET Core 8** API + **SQL Server** + **SignalR** live telemetry.

> **Synthetic data only** — no real patient information. A background simulation service generates ECG, SpO2, and BP waveforms.

## Architecture

```
┌─────────────┐     REST (JWT)      ┌─────────────┐     EF Core     ┌─────────────┐
│ Flutter App │ ◄─────────────────► │  Web API    │ ◄─────────────► │ SQL Server  │
│  (Riverpod) │                     │  Controllers│                 │             │
└──────┬──────┘                     └──────┬──────┘                 └─────────────┘
       │                                   │
       │         SignalR (TelemetryHub)    │
       └───────────────────────────────────┘
                    ▲
                    │ broadcast
            ┌───────┴────────┐
            │ Simulation Svc │
            └────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for the formal diagram.

## Prerequisites

| Tool | Version |
|------|---------|
| [.NET SDK](https://dotnet.microsoft.com/download) | 10.0+ |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.x |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Optional |

**Windows:** [docs/SETUP-WINDOWS.md](docs/SETUP-WINDOWS.md) — run `.\scripts\run-backend.ps1` and `.\scripts\run-frontend.ps1`.

## Quick start (Docker backend)

```powershell
cd "C:\Users\vijay\OneDrive\Desktop\Clinical Device Management System"
docker compose up --build
```

- API + Swagger: http://localhost:5000/swagger  
- SQL Server: `localhost:1433` (sa / `Your_strong_Password123`)

### Demo users

| Username | Password | Role |
|----------|----------|------|
| admin | Admin123! | Admin |
| clinician | Clinician123! | Clinician |
| tech | Tech123! | Tech |

## Flutter app

```powershell
cd frontend\clinical_device_app
C:\Users\vijay\flutter\bin\flutter pub get
C:\Users\vijay\flutter\bin\flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Or from the repo root (uses `scripts\config.ps1`):

```powershell
.\scripts\flutter.ps1 pub get
.\scripts\run-frontend.ps1
```

**Platform notes**

- **Windows desktop**: `http://localhost:5000`
- **Android emulator**: `--dart-define=API_BASE_URL=http://10.0.2.2:5000`
- **iOS simulator**: `http://localhost:5000`

## Local backend (without Docker)

**Default (Development):** uses **SQLite** (`clinical_device.db`) — no SQL Server install required.

To use SQL Server locally instead, set `"DatabaseProvider": "SqlServer"` and the `SqlServer` connection string in `appsettings.Development.json`.

1. Run:

```powershell
cd backend\ClinicalDevice.Api
dotnet restore
dotnet run
```

Migrations apply automatically on startup; seed data creates 3 devices and 2 synthetic patients.

## End-to-end demo flow (for screen recording)

1. **Login** as `clinician` / `Clinician123!`
2. **Dashboard** — view device grid and KPIs
3. Open a device → **Start** session → watch **live multi-channel charts** (ECG, SpO2, BP)
4. Tap **bolt icon** → triggers threshold spike → **alert** appears on Alerts screen
5. **Stop** session → **History** → select session → scrub timeline → **Export CSV/PDF**
6. **Patients** — search / add / edit synthetic patients

## API overview

| Endpoint | Description |
|----------|-------------|
| `POST /api/auth/login` | JWT login |
| `GET/POST/PUT/DELETE /api/devices` | Device CRUD |
| `GET /api/devices/{id}/health` | Telemetry snapshot |
| `POST /api/devices/{id}/simulate` | Trigger threshold spike |
| `GET/POST /api/patients` | Patients |
| `POST /api/sessions/start` | Start monitoring |
| `POST /api/sessions/{id}/stop` | End session |
| `POST /api/readings/batch` | Ingest readings |
| `GET /api/readings/{sessionId}` | Historical readings |
| `GET /api/alerts` | List alerts |
| `POST /api/alerts/{id}/acknowledge` | Acknowledge |
| SignalR `/hubs/telemetry` | `SubscribeSession`, `SubscribeDevice`, `TelemetryReceived`, `AlertRaised` |

Full OpenAPI docs: http://localhost:5000/swagger

Postman collection: [docs/postman_collection.json](docs/postman_collection.json)

## Project structure

```
├── backend/ClinicalDevice.Api/    # ASP.NET Core 8 API
├── frontend/clinical_device_app/  # Flutter + Riverpod
├── docker-compose.yml
├── docs/
└── README.md
```

## Assignment checklist

- [x] Flutter 3, Riverpod, dio, signalr_netcore, fl_chart, sqflite, Material 3
- [x] Six screens: Login, Dashboard, Live Monitor, Patients, History, Alerts
- [x] ASP.NET Core 8, EF Core, SQL Server, SignalR, JWT, Swagger
- [x] Simulation background service (ECG / SpO2 / BP)
- [x] docker-compose.yml
- [x] Architecture diagram & README

## Regenerate EF migrations (optional)

```powershell
cd backend\ClinicalDevice.Api
dotnet ef migrations add <Name>
dotnet ef database update
```
