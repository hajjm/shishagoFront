# Starting Chichago Locally

This guide starts the Chichago PostgreSQL database, FastAPI backend, and Flutter
frontend on Windows PowerShell.

## Project locations

```text
C:\Users\LOQ\Documents\GitHub\chichagoBack
C:\Users\LOQ\Documents\GitHub\chichagoFront
```

## Local ports

| Service | Address |
|---|---|
| PostgreSQL in Docker | `localhost:55432` |
| FastAPI backend | `http://127.0.0.1:8001` |
| FastAPI documentation | `http://127.0.0.1:8001/docs` |
| Flutter web | `http://localhost:8080` |

PostgreSQL intentionally uses host port `55432` because another local PostgreSQL
installation may already use the standard port `5432`.

## Prerequisites

Install these once:

- Docker Desktop
- Python 3
- Flutter SDK
- Chrome for Flutter web
- Android Studio and an emulator for Android development

Confirm the tools are available:

```powershell
docker --version
python --version
flutter doctor
```

## First-time backend setup

Open PowerShell and run:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoBack

Copy-Item .env.dev.example .env.dev
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Open `.env.dev` and replace the example `JWT_SECRET` with a long random value.
The `.env.dev` file is ignored by Git and must not be committed.

Start PostgreSQL and apply all database migrations:

```powershell
docker compose up -d postgres

$env:CHICHAGO_ENV = "dev"
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
.\.venv\Scripts\python.exe -m alembic upgrade head
```

`Remove-Item Env:DATABASE_URL` prevents an old PowerShell environment variable
from overriding `.env.dev`.

## Start the backend each day

Use the first PowerShell window:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoBack

docker compose up -d postgres

$env:CHICHAGO_ENV = "dev"
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8001
```

Keep this window open. Verify the backend in a browser:

- Health check: <http://127.0.0.1:8001/health>
- Interactive API documentation: <http://127.0.0.1:8001/docs>

The health response should report `"status": "ok"` and
`"environment": "dev"`.

## First-time frontend setup

Open a second PowerShell window:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoFront
flutter pub get
flutter devices
```

## Start Flutter web

Run this in the second PowerShell window:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoFront

flutter run -d chrome `
  --web-port 8080 `
  -t lib/main_dev.dart `
  --dart-define=CHICHAGO_API_URL=http://127.0.0.1:8001
```

Flutter should open <http://localhost:8080>. Web location access works on
`localhost`; allow the browser's location permission when testing addresses.

## Start an Android emulator

Start an emulator in Android Studio, then run:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoFront
flutter devices

flutter run -d <ANDROID_DEVICE_ID> `
  --flavor dev `
  -t lib/main_dev.dart `
  --dart-define=CHICHAGO_API_URL=http://10.0.2.2:8001
```

Replace `<ANDROID_DEVICE_ID>` with the ID printed by `flutter devices`.
Android emulators use `10.0.2.2` to reach the Windows host computer.

If Android reports that cleartext HTTP traffic is not permitted, use an HTTPS
development URL or configure a development-only Android network security rule.
Do not enable cleartext HTTP in production.

## Start on a physical Android phone

The phone and computer must be connected to the same network.

1. Find the computer's IPv4 address with `ipconfig`.
2. Start FastAPI so it listens on the local network:

   ```powershell
   cd C:\Users\LOQ\Documents\GitHub\chichagoBack
   $env:CHICHAGO_ENV = "dev"
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
   ```

3. Run Flutter using that IPv4 address:

   ```powershell
   cd C:\Users\LOQ\Documents\GitHub\chichagoFront

   flutter run -d <PHONE_DEVICE_ID> `
     --flavor dev `
     -t lib/main_dev.dart `
     --dart-define=CHICHAGO_API_URL=http://192.168.1.50:8001
   ```

Replace `192.168.1.50` with the computer's actual IPv4 address. Windows Firewall
may ask whether Python can accept private-network connections.

## Start on iOS

iOS development requires macOS with Xcode. On a Mac, use the `dev` scheme and
an API URL reachable by the simulator or physical device:

```bash
flutter run --flavor dev \
  -t lib/main_dev.dart \
  --dart-define=CHICHAGO_API_URL=http://<BACKEND-IP>:8001
```

For a physical iPhone, prefer an HTTPS development URL. iOS may reject a local
plain-HTTP URL unless a development-only App Transport Security exception is
configured.

## Development accounts

- Owner/admin phone: `+96170000000`
- New clients use **Create an account** from the sign-in page.
- Drivers are created by the owner under **People → Add driver**, then sign in
  using the registered driver phone number.

With `WHATSAPP_PROVIDER=development`, the six-digit verification code is shown
and automatically filled by the app. No real WhatsApp message is sent.

## Run automated checks

Backend:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoBack
$env:CHICHAGO_ENV = "dev"
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe -m alembic check
```

Frontend:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoFront
flutter analyze
flutter test
```

## Stop the application

Press `Ctrl+C` in the backend and Flutter PowerShell windows.

PostgreSQL may remain running for the next development session. To stop it:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoBack
docker compose stop postgres
```

The database data remains stored in the Docker volume.

## Common problems

### Port 8001 is already in use

Use another backend port, for example `8002`, and pass the same port to Flutter:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8002
```

```powershell
flutter run -d chrome `
  --web-port 8080 `
  -t lib/main_dev.dart `
  --dart-define=CHICHAGO_API_URL=http://127.0.0.1:8002
```

### Port 8080 is already in use

Stop the previous Flutter process with `Ctrl+C`. If a different web port is
required, add that origin to `CORS_ORIGINS` in `.env.dev`, restart the backend,
and run Flutter with the new `--web-port` value.

### Alembic reports a PostgreSQL password error

Confirm Docker Desktop is running, then run:

```powershell
cd C:\Users\LOQ\Documents\GitHub\chichagoBack
docker compose up -d postgres
$env:CHICHAGO_ENV = "dev"
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
.\.venv\Scripts\python.exe -m alembic upgrade head
```

The development database URL must use port `55432`, not `5432`.

### The frontend cannot reach the backend

- Confirm <http://127.0.0.1:8001/health> works.
- Confirm Flutter uses the same backend port.
- Use `127.0.0.1` for web, `10.0.2.2` for an Android emulator, and the
  computer's LAN IPv4 address for a physical phone.
- Restart the frontend after changing `CHICHAGO_API_URL`.

### Location does not work on web

- Use `http://localhost:8080` or an HTTPS deployment.
- Allow location access in the browser.
- Turn on Windows location services.
- Reload the page after changing permission settings.

### Real WhatsApp codes are not arriving

Development mode does not send messages. To use Meta WhatsApp Cloud API,
configure the ignored backend environment file with `WHATSAPP_PROVIDER=meta`,
the phone number ID, system-user token, approved authentication-template name,
language, and current API version. Restart FastAPI after changing the file.

Never put the WhatsApp access token in Flutter or commit it to Git.

## Staging and production

Use the matching backend environment and Flutter entry point:

| Environment | Backend selector | Flutter entry point |
|---|---|---|
| Development | `CHICHAGO_ENV=dev` | `lib/main_dev.dart` |
| Staging | `CHICHAGO_ENV=staging` | `lib/main_staging.dart` |
| Production | `CHICHAGO_ENV=prod` | `lib/main_prod.dart` |

Staging and production require real HTTPS API URLs, PostgreSQL credentials,
strong secrets, exact CORS origins, and configured WhatsApp/Firebase services.
