# Build, run and test Fleet Pilot on a Mac and an iPhone

This guide takes you from a clean MacBook to testing every screen of Fleet Pilot on your iPhone.
Plan on about 1.5 hours the first time. Most of that is downloading Xcode.

You will end up with:

- the **API** running on your Mac and connected to your SQL Server
- the **app** installed on your iPhone and talking to that API over your Wi-Fi

```
iPhone (Fleet Pilot app) ──Wi-Fi──▶ MacBook (API on port 5080) ──▶ SQL Server (port 1433)
```

The Mac and the iPhone must be on the **same Wi-Fi network**. Office guest networks often block
devices from reaching each other, so use a home or office network you control, or a personal
hotspot.

---

## Contents

1. [Install the tools](#1-install-the-tools)
2. [Get the code](#2-get-the-code)
3. [Prepare SQL Server](#3-prepare-sql-server)
4. [Configure and run the API](#4-configure-and-run-the-api)
5. [Check the API from the iPhone](#5-check-the-api-from-the-iphone)
6. [Prepare the iPhone and Xcode](#6-prepare-the-iphone-and-xcode)
7. [Run the app on the iPhone](#7-run-the-app-on-the-iphone)
8. [Test the system](#8-test-the-system)
9. [Run the automated tests](#9-run-the-automated-tests)
10. [Troubleshooting](#10-troubleshooting)
11. [Day to day commands](#11-day-to-day-commands)

---

## 1. Install the tools

Open **Terminal** (Applications → Utilities → Terminal). Run each block and wait for it to finish
before starting the next one.

### 1.1 Homebrew (package manager)

Skip this if `brew --version` already prints a version.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

At the end, Homebrew prints two or three `echo ... >> ~/.zprofile` lines under **Next steps**.
Copy and run them, then close Terminal and open it again.

### 1.2 Git

```bash
git --version
```

If macOS offers to install the Command Line Developer Tools, accept and run the command again.

### 1.3 .NET 8 SDK (for the API)

Download the **macOS installer for .NET 8 SDK** from https://dotnet.microsoft.com/download/dotnet/8.0.
Choose **Arm64** on an Apple silicon Mac (M1, M2, M3, M4) or **x64** on an older Intel Mac. To
check which you have: Apple menu → About This Mac → Chip.

Run the `.pkg`, then open a new Terminal window:

```bash
dotnet --list-sdks
```

You should see a line starting with `8.0.`.

### 1.4 Xcode (to build for iPhone)

1. Install **Xcode** from the App Store. It's large, so allow 30 to 60 minutes.
2. Open Xcode once and accept the licence. When it asks which platforms to install, tick **iOS**.
   (Later you can find this under Xcode → Settings → Components.)
3. In Terminal:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 1.5 CocoaPods

Some Flutter plugins still use CocoaPods on iOS.

```bash
brew install cocoapods
pod --version
```

### 1.6 Flutter

```bash
brew install --cask flutter
flutter --version
```

The version must be **3.50 or newer**. If it's older, run `flutter upgrade`.

Then check everything:

```bash
flutter doctor
```

The **Flutter** and **Xcode** lines must have a green tick. You can ignore Android, Chrome and
Android Studio because you are testing on an iPhone. If Xcode has a red cross, follow the command
that `flutter doctor` prints, then run it again.

---

## 2. Get the code

The app is on the pull request branch until it's merged into `main`.

```bash
cd ~
git clone https://github.com/PriyankaAldrin/fleet-pilot.git
cd fleet-pilot
git checkout feature/shift-tracking-app
```

GitHub will ask you to sign in because the repository is private. Use your GitHub username and a
[personal access token](https://github.com/settings/tokens) as the password, or install the GitHub
CLI (`brew install gh`, then `gh auth login`) and clone with `gh repo clone PriyankaAldrin/fleet-pilot`.

From here on, **`~/fleet-pilot`** is the project folder.

---

## 3. Prepare SQL Server

Choose **A** to use your own SQL Server, or **B** for a throwaway test database on the Mac.

### A. Your own SQL Server

You need:

- the server name or IP, and the port (usually 1433)
- a SQL login (user name and password) that can create a database, or an empty database
  named `FleetPilot` that the login owns (`db_owner`)
- SQL Server Authentication turned on (mixed mode) and TCP/IP enabled on the server

Check that the Mac can reach the server:

```bash
nc -vz YOUR_SQL_SERVER 1433
```

You should see `succeeded`. If it times out, a firewall or VPN is in the way. Open port 1433 to
your Mac, or connect to the VPN first.

### B. A test SQL Server on the Mac (Docker)

1. Install **Docker Desktop** from https://www.docker.com/products/docker-desktop/ and start it.
2. On an Apple silicon Mac, go to Docker Desktop → Settings → General, turn on
   **Use Rosetta for x86_64/amd64 emulation on Apple Silicon**, and click Apply & restart.
3. Start SQL Server 2022:

```bash
docker run -d --name fleet-sql \
  -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Your_strong_password1' \
  -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```

4. Wait about 30 seconds, then check that it's ready:

```bash
docker logs fleet-sql 2>&1 | grep "ready for client connections"
```

The project's development settings already point at this container (`localhost,1433`, user `sa`,
password `Your_strong_password1`), so there's nothing to change in step 4.2.

---

## 4. Configure and run the API

### 4.1 Open the settings file

```bash
cd ~/fleet-pilot/backend/src/FleetPilot.Api
open -e appsettings.Development.json
```

This opens the file in TextEdit. You can also use VS Code if you have it.

### 4.2 Fill in your values

```json
{
  "ConnectionStrings": {
    "Default": "Server=YOUR_SQL_SERVER,1433;Database=FleetPilot;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True"
  },
  "Jwt": {
    "SigningKey": "dev-only-signing-key-change-me-0123456789abcdef"
  },
  "SeedAdmin": {
    "Email": "you@yourcompany.com",
    "Password": "ChangeMe123!"
  },
  "Swagger": {
    "Enabled": true
  }
}
```

| Setting | What it does |
| --- | --- |
| `ConnectionStrings:Default` | Where the database is. Keep `TrustServerCertificate=True` unless your server has a trusted certificate. For a named instance, write `Server=HOST\\INSTANCE`. If you chose Docker (3B), leave it as it is. |
| `Jwt:SigningKey` | Signs login tokens. Any 32+ character string is fine for testing. For a real server, generate one with `openssl rand -base64 48`. |
| `SeedAdmin` | Your first admin login. It's only created when the database has no admin yet. |

The company time zone is already set to `Asia/Dubai` in `appsettings.json`.

> Keep real passwords out of git. Before you commit anything, undo your edits to this file with
> `git checkout -- appsettings.Development.json`.

Save the file and close TextEdit. If TextEdit turns your straight quotes into curly quotes, turn
that off under TextEdit → Settings → *Smart quotes*.

### 4.3 Run the API

```bash
cd ~/fleet-pilot/backend/src/FleetPilot.Api
dotnet run
```

The first run downloads packages and takes a minute. You should then see something like:

```
[INF] Applying database migrations
[INF] Created seed admin you@yourcompany.com. Change this password after the first sign in.
[INF] Now listening on: http://0.0.0.0:5080
```

- **Applying database migrations** means the `FleetPilot` database and all tables were created.
- **Created seed admin** means your admin login exists.
- **0.0.0.0:5080** means the API accepts connections from your iPhone as well as from the Mac.

If macOS asks *"Do you want the application dotnet to accept incoming network connections?"*,
click **Allow**.

Leave this Terminal window open while you test. To stop the API, press `Ctrl+C`.

### 4.4 Check it in the browser

Open **http://localhost:5080/swagger** in Safari or Chrome on the Mac. You should see the
**Fleet Pilot API** page listing every endpoint.

Optional: try signing in through Swagger.

1. Open **POST /api/v1/auth/login** → *Try it out*.
2. Enter `{"email":"you@yourcompany.com","password":"ChangeMe123!"}` → *Execute*.
3. The response has an `accessToken`. Copy it, click **Authorize** at the top of the page, paste
   it, and you can call any admin endpoint from the browser.

---

## 5. Check the API from the iPhone

Doing this before building the app saves a lot of guessing later.

1. Find your Mac's IP address on the Wi-Fi:

```bash
ipconfig getifaddr en0
```

   You'll get something like `192.168.1.20`. **Write it down**, you'll need it in step 7. If it
   prints nothing, open System Settings → Wi-Fi → Details on your network to find the IP address.

2. On the iPhone, connected to the same Wi-Fi, open Safari and go to:

```
http://192.168.1.20:5080/health
```

   (Use your own IP.) You should see **Healthy**.

If you don't see Healthy, fix it now with [Troubleshooting](#10-troubleshooting) before going on.
The app needs this same connection.

---

## 6. Prepare the iPhone and Xcode

You only do this once.

### 6.1 Connect and trust

1. Plug the iPhone into the Mac with a cable and unlock it.
2. On the iPhone, tap **Trust** when it asks *Trust This Computer?*, then enter your passcode.

### 6.2 Turn on Developer Mode (iOS 16 and later)

1. With the iPhone plugged in, open Xcode → Window → **Devices and Simulators** and select your
   iPhone. This makes the Developer Mode switch appear on the phone.
2. On the iPhone, go to Settings → **Privacy & Security** → **Developer Mode** (near the bottom),
   turn it on, and restart when asked.
3. After the restart, tap **Turn On** and enter your passcode.

### 6.3 Add your Apple ID to Xcode

Xcode → Settings → **Accounts** → **+** → Apple ID, then sign in. A free Apple ID is enough for
testing on your own phone. (A free account's install expires after 7 days; just run the app from
the Mac again. A paid Apple Developer account lasts a year and can use TestFlight.)

### 6.4 Download the ML Kit text model

The odometer reader needs a model file that has to be added to the iOS project by hand, once:

```bash
cd ~/fleet-pilot/mobile
flutter pub get
./ios/scripts/download_mlkit_bundle.sh
```

This creates `ios/Runner/LatinOCRResources.bundle`.

### 6.5 Open the iOS project and set signing

```bash
open ios/Runner.xcworkspace
```

Always open the **.xcworkspace** file, not the .xcodeproj.

In Xcode:

1. **Add the model bundle.** In the left sidebar, click the **Runner** folder (the yellow folder
   inside the blue Runner project). Drag `LatinOCRResources.bundle` from Finder
   (`~/fleet-pilot/mobile/ios/Runner/`) onto it. In the dialog, choose **Copy items if needed**
   (or *Reference files in place*, since it's already in the folder), tick the **Runner** target,
   and click Finish.
   Check it worked: click the blue **Runner** project → target **Runner** → **Build Phases** →
   **Copy Bundle Resources**. `LatinOCRResources.bundle` should be in that list.
2. **Signing.** Go to target **Runner** → **Signing & Capabilities**:
   - Tick **Automatically manage signing**.
   - **Team**: pick your Apple ID (shown as "Your Name (Personal Team)").
   - **Bundle Identifier**: change `com.fleetpilot.fleetPilot` to something unique to you, for
     example `com.subinmartin.fleetpilot`. Bundle identifiers must be unique across Apple.
   - The red errors should go away within a few seconds.
3. Close Xcode. (Flutter builds from the command line, and Xcode remembers these settings.)

> Commit the bundle identifier change if you want to keep it. You can also commit
> `LatinOCRResources.bundle`, so you don't have to download it again on another Mac.

---

## 7. Run the app on the iPhone

Keep the API running in its own Terminal window (step 4.3). Open a **second** Terminal window:

```bash
cd ~/fleet-pilot/mobile
flutter devices
```

Your iPhone should be listed, for example `Subin's iPhone (mobile) • 00008110-001234... • ios`.
Then run, using **your Mac's IP from step 5**:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5080
```

If more than one device is listed, add `-d` followed by the iPhone's id.

The first build takes 5 to 10 minutes. Later builds are much faster.

The first time it installs, iOS may refuse to open the app with *Untrusted Developer*. On the
iPhone, go to Settings → General → **VPN & Device Management**, tap your Apple ID under
*Developer App*, tap **Trust**, then run the command again.

When the app opens:

- Tap **Allow** when it asks to find devices on your **local network**. This is how it reaches
  your Mac. If you tap Don't Allow, fix it under Settings → Fleet Pilot → Local Network.
- You'll see the **Fleet Pilot** sign in screen.

While `flutter run` is active you can press `r` in Terminal to reload after a code change, or `q`
to quit.

### Using the app without the cable

An app started with `flutter run` is a *debug* build. Once you unplug the cable, it won't open
from the home screen. To install a build you can use on its own:

```bash
flutter run --release --dart-define=API_BASE_URL=http://192.168.1.20:5080
```

Wait until it starts, press `q`, unplug, and open **Fleet Pilot** from the home screen. It still
needs the Mac's API to be running and reachable.

---

## 8. Test the system

Tick each step as you go. **Expected** is what you should see. If something is different, note
the step number and send a screenshot.

You'll need something to photograph as an "odometer". Any of these works:

- a real car's dashboard
- a photo of an odometer on your Mac screen (search images for "digital odometer")
- a number written large on paper, for example **045210**

### 8.1 Admin: first sign in

| # | Do | Expected |
| --- | --- | --- |
| 1 | Sign in with the `SeedAdmin` email and password. | The **Dashboard** opens with six tiles, all showing 0. |
| 2 | Tap ☰ (top left). | The menu shows Dashboard, Shifts, Drivers, Vehicles, Admins, Reports. |
| 3 | Settings (⚙ top right) → **Change password**. Enter a new password with at least 8 characters, a letter and a number. | "Password changed", and you're signed out. Sign in again with the new password. |

### 8.2 Admin: vehicles

| # | Do | Expected |
| --- | --- | --- |
| 4 | Vehicles → **New vehicle**. Plate `dxb a 1234`, Make `Cadillac`, Model `Escalade`, Year `2024`, Colour `Black`, Current odometer **45200**. Save. | "Saved". The list shows plate **DXB A 1234** (made upper case). |
| 5 | Add a second vehicle with **the same plate**. | Error: a vehicle with that plate already exists. |
| 6 | Add a second vehicle with a different plate, for example `DXB B 777`, odometer 1000. | Saved. |
| 7 | Search for `777`. | Only the second vehicle is shown. |

### 8.3 Admin: drivers and admins

| # | Do | Expected |
| --- | --- | --- |
| 8 | Drivers → **New driver**. Name, an email you'll remember (it doesn't have to be real), phone, licence number, licence expiry, password `Driver123`. Save. | Saved and listed. |
| 9 | Create another driver with the **same email**. | Error: a user with that email already exists. |
| 10 | Try a password of `abc`. | "At least 8 characters with a letter and a number". |
| 11 | Admins → **New admin**. Create a second admin. | Saved. Your own row shows "(You)". |
| 12 | Open **your own** admin row. | There's no delete button, and the Active switch is greyed out, so you can't lock yourself out. |

### 8.4 Driver: start a shift (camera and km reading)

| # | Do | Expected |
| --- | --- | --- |
| 13 | Settings → **Sign out**. Sign in as the driver from step 8. | **My shift** screen: "You are not on a shift". |
| 14 | Tap **Start shift**. | The list shows both vehicles, each with its last odometer. |
| 15 | Tap **DXB A 1234**. | The camera opens straight away. Allow **Camera** and **Location** when asked. There's no option to choose from the photo library. |
| 16 | Photograph your "odometer" showing **45210**. | The photo appears, then "Reading the odometer…", then **45210** is filled in. |
| 17 | Check the number and tap **Confirm**. | "Shift started". The card shows the plate, start time, a timer and start km 45,210. |
| 18 | Admin check, later: this shift should **not** be flagged. 45210 is only 10 km above the vehicle's 45200. | — |

If no number is found in step 16, the app says *"Could not read the number"*. Type it in instead.
The shift will then be flagged for review, which is the expected behaviour.

### 8.5 Driver: end a shift with a corrected reading

| # | Do | Expected |
| --- | --- | --- |
| 19 | Tap **End shift**. | The camera opens. The hint says "Must be at least 45,210". |
| 20 | Photograph **45380**. When it's read, change the number to **45390** by hand. | Red text: "You changed the reading. An admin will review this shift." |
| 21 | Try typing **45000** instead. | Error: "Must be at least 45,210". You can't end below the start. |
| 22 | Set it back to 45390 and tap **Confirm**. | "Shift ended". The home screen shows "Last shift: 180 km in 0.0 h" and "Flagged for admin review". |
| 23 | Tap the clock icon (history). | The shift is listed with its km and time. |

### 8.6 The one-active-shift rule

| # | Do | Expected |
| --- | --- | --- |
| 24 | Start another shift on **DXB A 1234** (odometer 45390). | Started. |
| 25 | Sign out. Sign in as **admin**. Dashboard → **Active now** = 1, and the shift is listed under **On the road**. | — |
| 26 | Vehicles → DXB A 1234 shows **In use**. Try to delete it. | Error: the vehicle is in an active shift. |

### 8.7 Admin: review a flagged reading

| # | Do | Expected |
| --- | --- | --- |
| 27 | Dashboard → tap the **Needs review** tile. | The Shifts list opens filtered to the shift from step 22. |
| 28 | Open it. | Both photos are shown side by side. Under the end photo: *Confirmed: 45,390* and *Phone read: 45,380* in red. The "Why it was flagged" box says the driver changed the reading from 45380 to 45390. |
| 29 | Tap a photo. | It opens full screen and you can pinch to zoom. |
| 30 | Change **End km** to 45380, add a review note, tap **Save review**. | "Saved". The flag box now shows "Reviewed …", and the dashboard's Needs review count drops by one. |
| 31 | Open the active shift from step 24 → enter an End km → **End shift for driver**. | The shift is completed and noted "Ended by admin …". Use this when a driver forgets to end a shift. |

### 8.8 Reports and exports

| # | Do | Expected |
| --- | --- | --- |
| 32 | Reports → **All drivers**, dates covering today → **Show report**. | A table with one row per driver: shifts, hours, km, average km, flags. |
| 33 | Choose **One driver** → pick your driver → Show report. | Totals at the top and every shift listed, with times in Dubai time. |
| 34 | Tap the **PDF** icon. | iOS asks where to save. Choose **Files → On My iPhone**. Open the PDF from the Files app. |
| 35 | Tap the **Excel** icon and save it. | Opens in Numbers or Excel with a Summary sheet and a Shifts sheet. |
| 36 | Repeat with **All vehicles** and **One vehicle**. | Same, per vehicle. |

### 8.9 Offline mode

Choosing a vehicle needs the server, so start the shift while you're online.

| # | Do | Expected |
| --- | --- | --- |
| 37 | Sign in as the driver and **start a shift** while online. | "Shift started". |
| 38 | Turn on **Airplane Mode** on the iPhone, then pull down to refresh. | Banner: "You are offline. Shifts are saved on this phone…". |
| 39 | Tap **End shift**, take the photo and confirm. | "Shift ended", plus a banner saying "1 change(s) waiting to sync". |
| 40 | Turn Airplane Mode **off** and pull down to refresh. | The banner disappears. As admin, the shift shows as completed, with "Recorded offline" and the time the photo was taken. |

### 8.10 Language

| # | Do | Expected |
| --- | --- | --- |
| 41 | Settings → Language → **العربية**. | All screens switch to Arabic and lay out right to left. |
| 42 | Switch back to **English**. | Back to normal. The choice is remembered after closing the app. |

### 8.11 Deletes and history

| # | Do | Expected |
| --- | --- | --- |
| 43 | As admin, delete the **second** vehicle (not in use). | "Deleted", and it disappears from the list. |
| 44 | Reports → All vehicles. | The deleted vehicle only appears if it had shifts in the period, so history is kept. |
| 45 | Try signing in as a driver you **deactivated** (Drivers → open → Active off → Save). | "This account is disabled". |

### 8.12 What to look at on the Mac

- The Terminal running the API shows a line for every request. Errors appear in red as `ERR`.
- Log files: `~/fleet-pilot/backend/src/FleetPilot.Api/logs/`
- Odometer photos: `~/fleet-pilot/backend/src/FleetPilot.Api/App_Data/photos/`
- Audit log of every admin change: Swagger → `GET /api/v1/audit-logs`.

### Known iPhone behaviour

- ML Kit on iOS doesn't report a confidence score, so the "reading may be wrong" warning only
  appears when no number is found. Edited readings are still flagged. Turning on server OCR
  (`Ocr:Provider = Azure`) adds a second check on every photo.
- GPS can take a few seconds indoors. If it can't get a fix, the shift is still saved without a
  location.

---

## 9. Run the automated tests

Run these from the Mac. They don't need the iPhone or your SQL Server.

```bash
# API: 56 tests, uses an in-memory SQLite database
cd ~/fleet-pilot/backend
dotnet test

# App: static checks and 21 tests
cd ~/fleet-pilot/mobile
flutter analyze
flutter test
```

Expected: `Passed! - Failed: 0, Passed: 56` for the API, then `No issues found!` and
`All tests passed!` for the app.

---

## 10. Troubleshooting

| Problem | Fix |
| --- | --- |
| `dotnet run`: **A network-related or instance-specific error** / **Login failed** | The connection string is wrong or the server can't be reached. Check `nc -vz SERVER 1433`, the user and password, that SQL authentication is on, and that the server name includes the port (`HOST,1433`). For Docker, check `docker ps` shows `fleet-sql` running. |
| `dotnet run`: **Jwt:SigningKey must be at least 32 characters** | Fill in `Jwt:SigningKey` in `appsettings.Development.json`. |
| `dotnet run`: **CREATE DATABASE permission denied** | Ask your DBA to create an empty `FleetPilot` database and make your login `db_owner`, then run again. |
| `dotnet run`: **address already in use** | Something else uses port 5080. Find it with `lsof -i :5080` and stop it, or run on another port with `dotnet run --urls http://0.0.0.0:5090` (then use 5090 in the app's URL too). |
| Docker SQL container exits straight away | The password must have upper case, lower case, a number and a symbol, and be 8+ characters. On Apple silicon, turn on the Rosetta setting from step 3B. |
| Swagger page doesn't load | Check the API is running and you used `http://` (not https) and port 5080. Swagger only shows when `Swagger:Enabled` is true or the environment is Development (the default for `dotnet run`). |
| iPhone Safari can't open `/health` | 1) Mac and iPhone on the same Wi-Fi? 2) Right IP (`ipconfig getifaddr en0`)? 3) System Settings → Network → **Firewall**: allow `dotnet` or turn the firewall off while testing. 4) Some routers isolate clients; try a personal hotspot from another phone. 5) A VPN on the Mac or iPhone can block local traffic; turn it off. |
| App: **"Cannot reach the server. Check your connection."** | Same checks as the row above. Also check the URL you passed to `flutter run` has no trailing `/`, and that **Local Network** is allowed for Fleet Pilot (iPhone Settings → Fleet Pilot). |
| App sign in: **Email or password is incorrect** | The seed admin is only created when no admin exists. If you changed `SeedAdmin` after the first run, the old one is still there. Sign in with the first email, or delete the database and run again. |
| `flutter devices` doesn't list the iPhone | Unlock the phone, use a data cable (not charge-only), tap Trust, and check Developer Mode is on. Open Xcode → Window → Devices and Simulators to see what it reports. |
| Build error: **No profiles for 'com.fleetpilot.fleetPilot'** or **Signing requires a development team** | Redo step 6.5, part 2: choose your Team and set a unique Bundle Identifier. |
| Build error mentioning **CocoaPods** / `pod install` | `cd ~/fleet-pilot/mobile/ios && pod repo update && cd .. && flutter clean && flutter pub get`, then run again. |
| Build error: **iOS deployment target** or **minimum iOS** | The project targets iOS 15.0. Your iPhone must run iOS 15 or later. |
| App opens and closes straight away | It's a debug build started without the cable. Use `flutter run --release` (step 7) for standalone use. |
| **Untrusted Developer** | iPhone Settings → General → VPN & Device Management → your Apple ID → Trust. |
| The number is never read, or the app crashes when reading | The ML Kit model bundle is missing. Redo steps 6.4 and 6.5 part 1, and check **Copy Bundle Resources** lists `LatinOCRResources.bundle`. Then run `flutter clean` and run again. |
| The reading is wrong | Expected sometimes with glare or analog dials. Retake closer and straight on, or type the number. Edited readings are flagged for the admin. |
| PDF or Excel button does nothing | Wait for the save dialog. It needs the Files app to be available. Check the API terminal for errors on `/reports`. |
| Start shift: **This vehicle is already in use by another driver** | Someone has an active shift on it. End it (as that driver, or as admin with *End shift for driver*). |
| Offline change shows **The server refused a saved shift** | The server rejected it, for example because the vehicle was taken by someone else while you were offline. Read the message, tap **Discard**, and record the shift again. |
| The app is installed but expired after a week | Free Apple ID builds last 7 days. Plug in and run `flutter run --release ...` again. |

### Start again with a clean database

**Docker (3B):**

```bash
docker rm -f fleet-sql
```

Then start it again with the command in 3B.

**Your own server:** in SQL Server Management Studio or Azure Data Studio, run
`DROP DATABASE FleetPilot;`, then `dotnet run` again.

Either way, the API recreates the tables and the seed admin on the next start.

---

## 11. Day to day commands

```bash
# Start the test database (Docker option), if it's stopped
docker start fleet-sql

# Terminal 1: API
cd ~/fleet-pilot/backend/src/FleetPilot.Api && dotnet run

# Terminal 2: app on the iPhone (use your Mac's current IP)
cd ~/fleet-pilot/mobile && flutter run --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):5080

# Get the latest code
cd ~/fleet-pilot && git pull
```

Your Mac's IP can change when you reconnect to Wi-Fi. The `$(ipconfig getifaddr en0)` in the
command above fills it in for you.

When you're ready for real drivers, host the API on a server with HTTPS and a fixed address, then
build the app with `--dart-define=API_BASE_URL=https://your-server`. The README's *Deploy* section
covers this.
