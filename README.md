# shishaGoFront

Project name: `shishaGo`. Display name: **Shisha Go**. The Dart package is
`shishago`, following Dart's lowercase naming requirements.

This checkout remains at `C:\Users\LOQ\Documents\GitHub\chichagoFront`.
The rename does not change saved project locations or Git remote URLs.
Use `SHISHAGO_API_URL` and `SHISHAGO_ENV`; the previous `CHICHAGO_*` build
defines remain supported as fallbacks. Native identifiers now use
`com.shishago.app` (plus the environment suffix), so mobile builds install as
the new app identity. Any external Firebase registrations or signing profiles
must match that identifier before configuring those services.

Responsive Flutter client for Shisha Go. One codebase targets Android, iOS, and web
and selects the client, owner, or driver experience from the authenticated server role.

## Included flows

- Sign-in-first WhatsApp OTP authentication with a separate client sign-up page
- Client delivery addresses with a required, visibly confirmed GPS point
- Chicha and market catalogs, cart, checkout, order history, and reorder
- Live order status, driver coordinates, and driver phone details
- Owner dashboard with order filtering, Excel export with daily/monthly summaries, catalog, client, and driver management
- Driver assignments, customer calling, live GPS sharing, and delivery status progression
- Persisted notifications with live WebSocket refresh

## Environments

| Flavor | Dart entry point | Android application ID | iOS scheme |
|---|---|---|---|
| `dev` | `lib/main_dev.dart` | `com.shishago.app.dev` | `dev` |
| `staging` | `lib/main_staging.dart` | `com.shishago.app.staging` | `staging` |
| `prod` | `lib/main_prod.dart` | `com.shishago.app` | `prod` |

Environment selection and API URLs are typed in `lib/config/app_environment.dart`.
Pass `SHISHAGO_API_URL` during real staging and production builds. Their checked-in
fallbacks use the reserved `.example` domain so a build cannot accidentally target an
unknown live server.

## Run

For complete first-time setup, daily startup commands, mobile devices, and
troubleshooting, read [Starting Shisha Go locally](docs/START_FRONTEND_AND_BACKEND.md).
The concise [Word startup guide](docs/START_SHISHAGO_FRONTEND_AND_BACKEND.docx)
also uses the new project name and environment variables.

Start `shishaGoBack`, then:

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart --dart-define=SHISHAGO_API_URL=http://10.0.2.2:8001
```

For an Android emulator, use `http://10.0.2.2:8001`. For a physical phone, use the
backend computer's LAN address. For iOS, use the same command with the `dev` Xcode
scheme and a URL reachable by the simulator/device.

Flutter web does not use native flavors, so select its entry point directly:

```powershell
flutter run -d chrome -t lib/main_dev.dart --dart-define=SHISHAGO_API_URL=http://127.0.0.1:8001
```

Web location access requires HTTPS or localhost.

## Build targets

```powershell
flutter build web -t lib/main_prod.dart --dart-define=SHISHAGO_API_URL=https://api.shishago.example
flutter build appbundle --flavor prod -t lib/main_prod.dart --dart-define=SHISHAGO_API_URL=https://api.shishago.example
flutter build ios --flavor prod -t lib/main_prod.dart --dart-define=SHISHAGO_API_URL=https://api.shishago.example
```

iOS builds require macOS/Xcode. Replace the example command URL with the deployed HTTPS
API; realtime tracking automatically uses the matching `wss` URL. Substitute `staging`
and `lib/main_staging.dart` to create a staging build.

## Production services

WhatsApp delivery is configured in the backend. In-app notifications and tracking work
through the API and WebSockets. Background push notifications require Firebase project
configuration files plus obtaining and registering an FCM token with the backend.
