# Deploy the Fleet Pilot API to IIS with Azure SQL

Use this guide when your database is **Azure SQL** and your Mac can't connect to it directly.
The API runs on a **Windows server with IIS** that is allowed to reach Azure SQL. The iPhone app
then talks to that server instead of your Mac.

```
iPhone (Fleet Pilot app) ──internet/https──▶ IIS server (Fleet Pilot API) ──▶ Azure SQL
```

You don't need to connect to the database from your Mac. The API creates its own tables and your
first admin the first time it starts on the server.

**What you need**

- Access to the **Azure portal** for your SQL server
- **Remote Desktop** (or other admin access) to the Windows server running IIS
- Your Mac with the .NET 8 SDK and the code (see [SETUP_MAC_IPHONE.md](SETUP_MAC_IPHONE.md),
  sections 1.3 and 2)

---

## Contents

1. [Prepare Azure SQL](#1-prepare-azure-sql)
2. [Prepare the IIS server (once)](#2-prepare-the-iis-server-once)
3. [Build the API on your Mac](#3-build-the-api-on-your-mac)
4. [Copy it to the server and create the IIS site](#4-copy-it-to-the-server-and-create-the-iis-site)
5. [Configure the API](#5-configure-the-api)
6. [Start and check it](#6-start-and-check-it)
7. [Point the iPhone app at the server](#7-point-the-iphone-app-at-the-server)
8. [Deploy an update](#8-deploy-an-update)
9. [If you can't let the API create the tables](#9-if-you-cant-let-the-api-create-the-tables)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prepare Azure SQL

### 1.1 Create the database

Create the database yourself rather than letting the API do it. If the API creates it, Azure picks
a default size that may cost more than you want.

1. Azure portal → **SQL databases** → **Create**.
2. **Server**: your existing SQL server. **Database name**: `FleetPilot`.
3. **Compute + storage** → *Configure database*. For a small fleet, **Basic** or **Standard S0**
   is plenty to start with, and you can scale up later.
4. Review + create.

### 1.2 Create a login for the API

Use a dedicated user rather than the server admin account.

1. Open the `FleetPilot` database → **Query editor (preview)** → sign in as the server admin.
   If it says your IP isn't allowed, click the link to add it, or use SQL Server Management
   Studio on the IIS server instead.
2. Run this, choosing your own strong password:

```sql
CREATE USER fleetpilot_api WITH PASSWORD = 'A-Strong-Password-123!';
ALTER ROLE db_owner ADD MEMBER fleetpilot_api;
```

`db_owner` lets the API create and update its tables. If you'd rather not give it that, see
[section 9](#9-if-you-cant-let-the-api-create-the-tables).

### 1.3 Let the IIS server through the Azure SQL firewall

Azure SQL blocks every address until you allow it.

1. Find the IIS server's **public** IP. On the server, open a browser and visit
   https://api.ipify.org. If the server is an Azure VM, the IP is also on the VM's Overview page.
2. Azure portal → your **SQL server** (the server, not the database) → **Networking** →
   **Firewall rules** → **Add a firewall rule**. Name it `IIS server`, and put the IP in both
   *Start* and *End*. Click **Save**.

If the IIS server is an Azure VM in a virtual network, a **virtual network rule** or a
**private endpoint** is better than a public IP rule. Your Azure admin can set that up instead.

### 1.4 Copy the connection string

Database `FleetPilot` → **Connection strings** → **ADO.NET (SQL authentication)**. It looks like
this:

```
Server=tcp:YOUR-SERVER.database.windows.net,1433;Initial Catalog=FleetPilot;Persist Security Info=False;User ID={your_username};Password={your_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

Replace `{your_username}` with `fleetpilot_api` and `{your_password}` with the password from 1.2.
Keep it somewhere safe; you'll paste it in section 5.

---

## 2. Prepare the IIS server (once)

Do these on the Windows server, over Remote Desktop.

### 2.1 IIS

If IIS isn't installed yet, open **Server Manager** → Add Roles and Features → **Web Server (IIS)**,
and keep the default features.

### 2.2 ASP.NET Core 8 Hosting Bundle

This is what lets IIS run the API.

1. Go to https://dotnet.microsoft.com/download/dotnet/8.0. Under **ASP.NET Core Runtime 8.0.x** →
   **Windows**, download **Hosting Bundle** and install it.
2. Restart IIS. Open **Command Prompt as Administrator** and run:

```bat
net stop was /y
net start w3svc
```

If IIS was installed *after* the Hosting Bundle, run the Hosting Bundle installer again and choose
**Repair**.

### 2.3 Folders

Create two folders, one for the program and one for data that must survive updates:

```bat
mkdir C:\inetpub\fleetpilot
mkdir D:\FleetPilotData\photos
mkdir D:\FleetPilotData\logs
```

If the server has no `D:` drive, use `C:\FleetPilotData` and change the paths in section 5 to
match. Odometer photos are stored in `photos`, so back that folder up. If you'd rather keep photos
in Azure, see the **Storage** note in section 5.

---

## 3. Build the API on your Mac

```bash
cd ~/fleet-pilot
git pull
cd backend
dotnet publish src/FleetPilot.Api -c Release -o ~/fleetpilot-publish
cd ~ && zip -r fleetpilot-publish.zip fleetpilot-publish
```

This creates `~/fleetpilot-publish.zip`. It already includes the `web.config` that IIS needs.
It does not include any passwords; those go on the server in section 5.

---

## 4. Copy it to the server and create the IIS site

### 4.1 Copy the files

Copy `fleetpilot-publish.zip` to the server. In the macOS **Windows App** (formerly Microsoft
Remote Desktop), you can share a Mac folder with the server, or you can drag and drop the file.
Then unzip it so that `FleetPilot.Api.dll` and `web.config` sit directly in
`C:\inetpub\fleetpilot`.

### 4.2 Application pool

Open **IIS Manager** (search for `inetmgr`).

1. **Application Pools** → **Add Application Pool**:
   - Name: `FleetPilot`
   - .NET CLR version: **No Managed Code**
   - Managed pipeline mode: Integrated
2. Select `FleetPilot` → **Advanced Settings**:
   - **Enable 32-Bit Applications**: `False`
   - **Start Mode**: `AlwaysRunning` (optional, makes the first request after a restart faster)
   - **Idle Time-out (minutes)**: `0` (optional, stops IIS from unloading the API when nobody uses it)

### 4.3 Website

**Sites** → **Add Website**:

- Site name: `FleetPilot`
- Application pool: `FleetPilot`
- Physical path: `C:\inetpub\fleetpilot`
- Binding: choose one of these.
  - **For real use: https.** Type `https`, port 443, host name `fleet.yourcompany.com`, and an SSL
    certificate for that name. If you don't have a certificate, [win-acme](https://www.win-acme.com/)
    gets a free Let's Encrypt one and renews it for you. The domain name has to point at the
    server first.
  - **For a quick test: http on a port.** Type `http`, port `5080`, no host name. Then open the
    port in Windows Firewall (Administrator Command Prompt):

    ```bat
    netsh advfirewall firewall add rule name="Fleet Pilot 5080" dir=in action=allow protocol=TCP localport=5080
    ```

    If the server is an Azure VM, also allow port 5080 in its **Network security group**. Only use
    this for testing: passwords travel unencrypted over plain http.

If the **Default Web Site** already uses port 80 or 443 with no host name, either give Fleet Pilot
a host name or use a different port.

### 4.4 Folder permissions

The application pool needs to write photos and logs:

```bat
icacls "D:\FleetPilotData" /grant "IIS AppPool\FleetPilot:(OI)(CI)M"
icacls "C:\inetpub\fleetpilot" /grant "IIS AppPool\FleetPilot:(OI)(CI)RX"
```

---

## 5. Configure the API

1. In `C:\inetpub\fleetpilot`, create a file named **`appsettings.Production.json`**. Notepad
   works; when saving, choose *Save as type: All files* so it doesn't get a `.txt` ending.
2. Paste this in and fill in your values. The template is also in the repo, at
   `backend/src/FleetPilot.Api/appsettings.Production.example.json`.

```json
{
  "ConnectionStrings": {
    "Default": "Server=tcp:YOUR-SERVER.database.windows.net,1433;Initial Catalog=FleetPilot;User ID=fleetpilot_api;Password=YOUR_PASSWORD;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  },
  "Jwt": {
    "SigningKey": "PASTE_THE_KEY_FROM_THE_COMMAND_BELOW"
  },
  "SeedAdmin": {
    "Name": "Administrator",
    "Email": "you@yourcompany.com",
    "Password": "ChangeMe123!"
  },
  "Company": {
    "Name": "Your Limousine Company",
    "TimeZone": "Asia/Dubai"
  },
  "Storage": {
    "Provider": "Local",
    "LocalPath": "D:\\FleetPilotData\\photos"
  },
  "Serilog": {
    "WriteTo": [
      { "Name": "Console" },
      {
        "Name": "File",
        "Args": { "path": "D:\\FleetPilotData\\logs\\fleetpilot-.log", "rollingInterval": "Day", "retainedFileCountLimit": 30 }
      }
    ]
  },
  "Swagger": {
    "Enabled": true
  }
}
```

Notes:

- Inside JSON, every `\` in a Windows path must be written as `\\`, as shown above.
- **Jwt:SigningKey**: generate one in PowerShell and paste it in. Keep it secret, and don't
  change it later or everyone will be signed out.

  ```powershell
  $b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
  ```

- **SeedAdmin** is used only on the first start, when there's no admin yet. Change that password
  in the app after you sign in.
- **Swagger** is turned on so you can check the API in a browser. Set it to `false` once you're
  live.
- **Storage**: to keep photos in Azure instead of on the server, create a Storage account, then set
  `"Provider": "AzureBlob"` and `"AzureConnectionString": "<the storage account's connection string>"`.
- **Server OCR (optional)**: to have Azure re-read every odometer photo as a second check, create an
  *Azure AI Vision* resource and add:
  `"Ocr": { "Provider": "Azure", "AzureEndpoint": "https://<name>.cognitiveservices.azure.com/", "AzureKey": "<key>" }`.

This file stays on the server only. It's never in git, and publishing an update doesn't overwrite
it.

---

## 6. Start and check it

1. IIS Manager → select site **FleetPilot** → **Restart** (or Start).
2. On the server, open a browser to `http://localhost:5080/health` (or `https://fleet.yourcompany.com/health`).
   It should show **Healthy**.

   The first request takes 10 to 30 seconds: the API creates the tables in Azure SQL and your
   admin account.

3. Open `/swagger` on the same address. You should see the **Fleet Pilot API** page.
4. Check the log, `D:\FleetPilotData\logs\fleetpilot-<date>.log`. You should see:

```
Applying database migrations
Created seed admin you@yourcompany.com. ...
```

5. From your **iPhone's Safari**, open the same `/health` address using the server's public
   address. If it says Healthy, the phone can reach the API.

If you see an error page instead, go to [Troubleshooting](#10-troubleshooting).

---

## 7. Point the iPhone app at the server

Follow [SETUP_MAC_IPHONE.md](SETUP_MAC_IPHONE.md) **sections 1, 2, 6 and 7**. You can skip
sections 3, 4 and 5 (the database and the API on your Mac). In section 7, use the server's address
instead of your Mac's:

```bash
cd ~/fleet-pilot/mobile
# https with a domain (recommended)
flutter run --release --dart-define=API_BASE_URL=https://fleet.yourcompany.com
# or the quick-test http port
flutter run --release --dart-define=API_BASE_URL=http://SERVER_PUBLIC_IP:5080
```

No trailing `/`. The iPhone doesn't need to be on the same Wi-Fi any more; mobile data works too.
Then run the tests in SETUP_MAC_IPHONE.md section 8.

---

## 8. Deploy an update

1. On the Mac, repeat [section 3](#3-build-the-api-on-your-mac) to make a new zip.
2. On the server, put the site offline so files aren't locked: copy any small text file into
   `C:\inetpub\fleetpilot` and name it **`app_offline.htm`**. IIS then shows that page and stops the
   API.
3. Copy the new files over the old ones. Your `appsettings.Production.json` isn't in the zip, so
   it stays as it is.
4. Delete `app_offline.htm`. The API starts again on the next request and applies any new database
   changes automatically.

---

## 9. If you can't let the API create the tables

Some companies don't allow an application account to change the database structure. In that case:

1. Ask your DBA (or yourself, as server admin) to run **`backend/database/FleetPilot.sql`** from the
   repo against the `FleetPilot` database. Use **SQL Server Management Studio** or **Azure Data
   Studio** on the IIS server (it can reach Azure SQL). The script is safe to run more than once.
2. Give the API user only data access:

```sql
ALTER ROLE db_owner DROP MEMBER fleetpilot_api;
ALTER ROLE db_datareader ADD MEMBER fleetpilot_api;
ALTER ROLE db_datawriter ADD MEMBER fleetpilot_api;
```

3. In `appsettings.Production.json`, add `"Database": { "MigrateOnStartup": false }`.

The API still creates the first admin on startup. That only needs data access.

When a future update changes the database, a new script will come with it.

---

## 10. Troubleshooting

To see why the API won't start, open `C:\inetpub\fleetpilot\web.config`, change
`stdoutLogEnabled="false"` to `"true"`, create the folder `C:\inetpub\fleetpilot\logs`, and grant
`IIS AppPool\FleetPilot` Modify on it (same `icacls` command as in 4.4). Restart the site, then read
the newest `stdout_*.log` in that folder. Turn it back off afterwards.

| What you see | Cause and fix |
| --- | --- |
| **HTTP 500.19**, *configuration data is invalid* | The Hosting Bundle isn't installed, or IIS was installed after it. Install or Repair the Hosting Bundle (2.2) and restart IIS. |
| **HTTP 500.30** / **500.31**, *ASP.NET Core app failed to start* | Check the stdout log (above). The usual causes are in the rows below. |
| Log: **Jwt:SigningKey must be at least 32 characters** | `appsettings.Production.json` is missing, misnamed (e.g. `.json.txt`), or the key is empty. In Explorer, turn on *View → File name extensions* to check. |
| Log: **Cannot open server ... Client with IP address 'x.x.x.x' is not allowed** | Add that exact IP to the Azure SQL firewall (1.3). It can take up to 5 minutes to apply. |
| Log: **Login failed for user 'fleetpilot_api'** | Wrong user or password in the connection string, or the user was created in `master` instead of the `FleetPilot` database. Re-run 1.2 inside `FleetPilot`. |
| Log: **CREATE TABLE permission denied** | The user isn't `db_owner`. Re-run the `ALTER ROLE` line in 1.2, or use section 9. |
| Log: **Access to the path 'D:\FleetPilotData\...' is denied** | Re-run the `icacls` commands in 4.4 with the folder you actually used. |
| Log: **'...' is not a known time zone** | Use `Asia/Dubai` or the Windows name `Arabian Standard Time`. |
| **HTTP 500.32**, *failed to load dll* | The app pool has *Enable 32-Bit Applications* set to True. Set it to False (4.2). |
| **HTTP 503 Service Unavailable** | The app pool stopped after repeated crashes. Fix the cause using the log, then start the pool again in IIS Manager. |
| **HTTP 404** on `/swagger` but `/health` works | `Swagger:Enabled` isn't `true` in `appsettings.Production.json`. |
| `/health` works on the server but not from the iPhone | Windows Firewall or the Azure NSG doesn't allow the port (4.3), or you're using the server's private IP instead of its public address. |
| Photo upload fails with **413** | A proxy or load balancer in front of IIS has a lower upload limit. The site itself allows 12 MB (`web.config`). |
| **Health shows Unhealthy** | The API is running but can't reach Azure SQL. Check the firewall and connection string, as above. |
| Sign in works, then everyone is signed out after an update | `Jwt:SigningKey` changed. Keep the same key across updates. |
