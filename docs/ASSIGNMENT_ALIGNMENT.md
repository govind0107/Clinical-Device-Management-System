# Assignment alignment

## REST API endpoints (screenshot §2.2)

| Spec endpoint | Implemented | Route |
|---------------|-------------|-------|
| `POST /api/auth/login` | ✅ | `AuthController.Login` |
| `GET/POST/PUT/DELETE /api/devices` | ✅ | `DevicesController` |
| `GET /api/devices/{id}/health` | ✅ | `DevicesController.GetHealth` |
| `GET/POST /api/patients` | ✅ | `PatientsController` (POST also updates when `patientId` is sent — edit flow) |
| `POST /api/sessions/start` | ✅ | `SessionsController.Start` |
| `POST /api/sessions/{id}/stop` | ✅ | `SessionsController.Stop` |
| `POST /api/readings/batch` | ✅ | `ReadingsController.IngestBatch` |
| `GET /api/readings/{sessionId}` | ✅ | `ReadingsController.GetBySession` |
| `GET /api/alerts` | ✅ | `AlertsController.GetAll` |
| `POST /api/devices/{id}/simulate` | ✅ | `DevicesController.Simulate` |

**Supporting endpoint (Alerts screen §3.1):** `POST /api/alerts/{id}/acknowledge`

**Removed (not in spec):** `GET /api/sessions` — history uses sqflite after `stop` + `GET /api/readings/{sessionId}`

## Database schema (screenshot §2.1)

| Table | Spec columns | Match |
|-------|--------------|-------|
| **Devices** | DeviceId, SerialNumber, Model, Status, LastSeen, CalibrationDate | ✅ |
| **Patients** | PatientId, Name, DateOfBirth, MRN | ✅ |
| **Sessions** | SessionId, DeviceId, PatientId, StartTime, EndTime | ✅ (removed extra `IsSimulating`) |
| **Readings** | ReadingId, SessionId, Timestamp, Channel, Value, Unit | ✅ |
| **Alerts** | AlertId, DeviceId, Severity, Message, CreatedAt, Acknowledged | ✅ (removed extra `SessionId`) |
| **Users** | UserId, Username, PasswordHash, Role | ✅ |

## Flutter screens & flow (screenshot §3–4)

| Screen / flow | Match |
|---------------|-------|
| Login + JWT + role routing | ✅ `RoleConfig` + nav limits (Tech: no Patients) |
| Dashboard (grid, KPIs, alert banner) | ✅ |
| Live monitor (charts, channels, start/stop, min/avg/max) | ✅ + decimation |
| Patients (list, search, add/edit, link to session) | ✅ POST patients + patient dropdown on session |
| History (playback scrub, CSV/PDF) | ✅ sqflite session list + `GET readings/{sessionId}` |
| Alerts (severity, acknowledge) | ✅ + SignalR instant snackbar |
| Demo flow §4 | ✅ |

## Tech stack

| Required | Status |
|----------|--------|
| Riverpod, dio, signalr_netcore, fl_chart, sqflite, Material 3 | ✅ |

**After schema migration:** delete `backend/ClinicalDevice.Api/clinical_device.db` and restart API, or run `dotnet ef database update`.
