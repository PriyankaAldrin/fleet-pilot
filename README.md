# Fleet Pilot

Daily shift tracking for limousine drivers. Drivers pick a vehicle, photograph the odometer at
the start and end of each shift, and the app records times, km and location. Admins manage
admins, drivers and vehicles, review suspicious readings, and run reports per driver and per
vehicle with PDF and Excel export.

| Part | Folder | Stack |
| --- | --- | --- |
| API | `backend/` | ASP.NET Core 8, EF Core 8 on SQL Server, JWT + refresh tokens, Serilog, Swagger |
| App | `mobile/` | Flutter (Android and iOS), Riverpod, Dio, go_router, Google ML Kit, English and Arabic |

---

## How the odometer reading works

Reading km from a photo works well for digital odometers but is not perfect for analog drums,
glare, night shots or blur. So the app never trusts it blindly:

1. The driver takes the photo **in the app with the camera** (the gallery is not offered).
2. **ML Kit reads the number on the phone** (works offline) and pre-fills it.
3. The driver **confirms or corrects** the number.
4. The photo, the phone's reading, the confirmed value, GPS and time are sent to the API.
5. The API can **read the photo again** (Azure AI Vision, optional) and **flags the shift for
   admin review** when any of these is true:
   - no number was detected, or the driver changed it
   - OCR confidence is below `OdometerRules:MinOcrConfidence` (0.80)
   - the server reading disagrees with the confirmed value
   - the start reading is lower than the vehicle's last odometer, or more than
     `MaxGapBetweenShiftsKm` (50) above it (unlogged driving)
   - the shift is longer than `MaxKmPerShift` (1,000 km)
6. Admins see flagged shifts on the dashboard, open the photo next to the readings, correct the
   km if needed and mark the shift as reviewed.

End km can never be lower than start km. A driver can have only one active shift, and a vehicle
can be in only one active shift; SQL Server enforces both with filtered unique indexes.

The digit picking rule (longest run of digits, skip trip meters like `123.4`, max 7 digits) lives
in `OdometerParser.cs` and `odometer_parser.dart` and both have the same tests.

---

## 1. Set up the API

### Requirements

- .NET 8 SDK
- Your SQL Server (2016 or newer, or Azure SQL). The database is created by the migrations.

### Configure

Settings live in `backend/src/FleetPilot.Api/appsettings.json`. Do not commit real secrets.
Put them in `appsettings.Production.json` (git-ignored), in user secrets, or in environment
variables (use `__` for nesting, e.g. `ConnectionStrings__Default`).

| Setting | What to put |
| --- | --- |
| `ConnectionStrings:Default` | Your SQL Server, e.g. `Server=sql01;Database=FleetPilot;User Id=fleet;Password=...;TrustServerCertificate=True` |
| `Jwt:SigningKey` | A random string of at least 32 characters. The API refuses to start without it. |
| `SeedAdmin:Email`, `SeedAdmin:Password` | The first admin, created on startup only when no admin exists. Change the password after signing in. |
| `Company:TimeZone` | Used for "today" and report dates. Default `Asia/Dubai`. Any IANA or Windows id works. |
| `Storage:Provider` | `Local` (default, saves under `App_Data/photos`) or `AzureBlob` (set `AzureConnectionString`). |
| `Ocr:Provider` | `None` (default) or `Azure` (set `AzureEndpoint` and `AzureKey` of an Azure AI Vision resource). |
| `OdometerRules:*` | Thresholds for flagging, see above. |
| `Swagger:Enabled` | `true` to expose `/swagger` outside Development. |
| `Database:MigrateOnStartup` | `true` applies migrations at startup. Set `false` if you prefer to run them yourself. |

Generate a signing key:

```bash
openssl rand -base64 48
```

### Create the database

Either let the API migrate on startup (default), or run the migration yourself:

```bash
cd backend
dotnet tool restore
dotnet ef database update --project src/FleetPilot.Api
# or produce a SQL script for your DBA:
dotnet ef migrations script --idempotent --project src/FleetPilot.Api -o fleetpilot.sql
```

### Run

```bash
cd backend/src/FleetPilot.Api
dotnet run            # http://0.0.0.0:5080, Swagger at http://localhost:5080/swagger
```

`appsettings.Development.json` points at a local SQL Server (`localhost,1433`, user `sa`) and seeds
`admin@fleetpilot.local` / `ChangeMe123!`. To try it without installing SQL Server:

```bash
docker run -d -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Your_strong_password1' -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```

Health check: `GET /health`.

### Deploy

Publish with `dotnet publish -c Release` and host on IIS, a Windows service, Linux + systemd, or a
container. Serve it over **HTTPS** (release builds of the app refuse plain http). Make sure the
photo folder (`Storage:LocalPath`) is on persistent disk and backed up, or use Azure Blob.

### Tests

```bash
cd backend
dotnet test
```

56 tests: odometer parsing, flag rules, shift rules (one active shift, end ≥ start, idempotent
offline sync, offline timestamps), admin rules (no self delete, last admin, soft delete, audit
log without password hashes), auth (refresh rotation and reuse detection), reports (time zone,
totals, PDF/Excel), and an HTTP test of the whole driver day through the real pipeline.

---

## 2. Set up the app

### Requirements

- Flutter 3.50 or newer (stable)
- Android: Android Studio / SDK. Min SDK comes from Flutter (ML Kit needs 21+).
- iOS: Xcode 15.3+, iOS 15.0+.

### iOS: add the ML Kit model once

`google_mlkit_text_recognition` uses Swift Package Manager, which cannot copy the text model into
the app. Run this once and add the bundle to the Runner target in Xcode
(**Build Phases → Copy Bundle Resources**):

```bash
cd mobile
./ios/scripts/download_mlkit_bundle.sh
```

### Run

Point the app at your API with `API_BASE_URL` (no trailing slash):

```bash
cd mobile
flutter pub get
# Android emulator talking to the API on your computer (default):
flutter run
# Real phone on the same Wi-Fi:
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5080
# Production:
flutter build apk --release --dart-define=API_BASE_URL=https://fleet.yourcompany.com
flutter build ipa --release --dart-define=API_BASE_URL=https://fleet.yourcompany.com
```

Debug Android builds allow plain http so you can test against a local API. Release builds need
https.

### Tests

```bash
cd mobile
flutter analyze
flutter test
```

### Screens

**Driver**
- Sign in. The session is kept on the phone (secure storage) and refreshed automatically.
- *My shift*: start a shift, or see the active one (vehicle, start time, elapsed time, start km).
- *Select vehicle*: only active vehicles that nobody else is using.
- *Odometer*: camera photo → ML Kit reading → confirm or correct → GPS is attached.
- *Shift history*.
- **Offline**: if there is no connection, the start or end is saved on the phone (with a copy of
  the photo and the time it was taken) and sent automatically when the connection is back. The
  API accepts offline times up to `MaxOfflineAgeHours` (72 h) old. Retries are safe: each shift
  has an id made by the app, so the same start is never recorded twice.

**Admin** (same app, shown to admin accounts)
- *Dashboard*: active shifts now, shifts and km today, flagged readings awaiting review, active
  drivers and vehicles.
- *Shifts*: filter by all, needs review, active, completed; search by driver or plate. Open a shift
  to see both photos next to the phone and server readings, correct km, add review notes, or end a
  shift a driver forgot to close.
- *Drivers*, *Vehicles*, *Admins*: create, edit, deactivate and delete, with search and paging.
  Deletes are soft, so history and reports stay intact. You cannot delete or deactivate yourself,
  and the last active admin cannot be removed.
- *Reports*: all drivers, all vehicles, one driver or one vehicle, for a date range. Shows shifts,
  hours, km and averages, and exports PDF or Excel.
- *Settings*: English / Arabic (right to left), change password, sign out.

---

## API overview

All routes are under `/api/v1`. Full details in Swagger.

| Method | Route | Who |
| --- | --- | --- |
| POST | `/auth/login`, `/auth/refresh`, `/auth/logout` | anyone |
| GET | `/auth/me` · POST `/auth/change-password` | signed in |
| GET/POST/PUT/DELETE | `/admins`, `/drivers`, `/vehicles` (`?search=&page=&pageSize=&isActive=`) | admin |
| GET | `/vehicles/available` | signed in |
| GET | `/shifts/active` | driver |
| POST | `/shifts/start` (multipart: `clientId, vehicleId, startKm, ocrKm, ocrConfidence, latitude, longitude, capturedAt, recordedOffline, notes, photo`) | driver |
| POST | `/shifts/{id}/end` (multipart: `endKm, ocrKm, ...photo`) | the shift's driver, or admin |
| GET | `/shifts` (`?driverId&vehicleId&from&to&status&flagged&needsReview&search`) | admin: all, driver: own |
| GET | `/shifts/{id}`, `/shifts/{id}/photos/{start\|end}` | admin, or the shift's driver |
| PUT | `/shifts/{id}/review` | admin |
| GET | `/dashboard`, `/audit-logs` | admin |
| GET | `/reports/drivers`, `/reports/drivers/{id}`, `/reports/vehicles`, `/reports/vehicles/{id}` (`?from=yyyy-MM-dd&to=yyyy-MM-dd&format=json\|pdf\|xlsx`) | admin |

Errors use RFC 7807 problem details. Validation errors return 400 with an `errors` object per field;
business rule failures return 422, conflicts (active shift, duplicate email or plate) return 409.

Every create, update and delete by an admin is written to `AuditLogs` with the changed fields
(password hashes are never logged).

---

## Notes and limits

- **Reports**: a shift belongs to the day it started (company time zone). Hours and km count
  completed shifts only; active shifts are listed but not totalled.
- **ML Kit confidence** is reported on Android only. On iOS the device reading has no confidence,
  so the confidence rule relies on the server OCR when it is enabled.
- **QuestPDF** is used under its Community licence, which is free for companies with less than
  USD 1M annual revenue. Larger companies need a QuestPDF licence.
- **AutoMapper** was left out on purpose: its free versions have known vulnerabilities and newer
  versions need a paid licence. Mapping is hand written in `Services/Mappings.cs`.
- Photos are compressed on the phone (max 1600 px, JPEG quality 80) and limited to 8 MB on the
  server.

## Project layout

```
backend/
  src/FleetPilot.Api/
    Controllers/        REST endpoints
    Services/           business logic (shifts, odometer rules, reports, auth, CRUD)
    Repositories/       generic repository + unit of work over EF Core
    Data/               DbContext (soft delete, audit), migrations, seeding
    Domain/             entities
    Dtos/  Validators/  request/response models and FluentValidation rules
    Infrastructure/     OCR (Azure), photo storage (local/Azure Blob), PDF/Excel export
    Middleware/         validation filter, problem details
  tests/FleetPilot.Api.Tests/
mobile/
  lib/core/             config, API client (token refresh), models, router
  lib/features/auth/    sign in, session
  lib/features/driver/  shift flow, offline sync
  lib/features/odometer/ camera + ML Kit + confirm screen, digit parser
  lib/features/admin/   dashboard, CRUD, shift review, reports
  lib/l10n/             English and Arabic strings
  test/
```
