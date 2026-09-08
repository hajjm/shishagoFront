# chichagoFront

Responsive Flutter client for Chichago. One codebase targets Android, iOS, and web
and selects the client, owner, or driver experience from the authenticated server role.

## Included flows

- WhatsApp OTP account creation and sign-in
- GPS-backed client delivery address
- Chicha and market catalogs, cart, checkout, order history, and reorder
- Live order status, driver coordinates, and driver phone details
- Owner dashboard with order filtering, CSV export, catalog, client, and driver management
- Driver assignments, customer calling, live GPS sharing, and delivery status progression
- Persisted notifications with live WebSocket refresh

## Environments

| Flavor | Dart entry point | Android application ID | iOS scheme |
|---|---|---|---|
| `dev` | `lib/main_dev.dart` | `com.chichago.app.dev` | `dev` |
| `staging` | `lib/main_staging.dart` | `com.chichago.app.staging` | `staging` |
| `prod` | `lib/main_prod.dart` | `com.chichago.app` | `prod` |

Environment selection and API URLs are typed in `lib/config/app_environment.dart`.
Pass `CHICHAGO_API_URL` during real staging and production builds. Their checked-in
fallbacks use the reserved `.example` domain so a build cannot accidentally target an
unknown live server.

## Run

Start `chichagoBack`, then:

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart --dart-define=CHICHAGO_API_URL=http://10.0.2.2:8000
```

For an Android emulator, use `http://10.0.2.2:8000`. For a physical phone, use the
backend computer's LAN address. For iOS, use the same command with the `dev` Xcode
scheme and a URL reachable by the simulator/device.

Flutter web does not use native flavors, so select its entry point directly:

```powershell
flutter run -d chrome -t lib/main_dev.dart --dart-define=CHICHAGO_API_URL=http://127.0.0.1:8000
```

Web location access requires HTTPS or localhost.

## Build targets

```powershell
flutter build web -t lib/main_prod.dart --dart-define=CHICHAGO_API_URL=https://api.chichago.example
flutter build appbundle --flavor prod -t lib/main_prod.dart --dart-define=CHICHAGO_API_URL=https://api.chichago.example
flutter build ios --flavor prod -t lib/main_prod.dart --dart-define=CHICHAGO_API_URL=https://api.chichago.example
```

iOS builds require macOS/Xcode. Replace the example command URL with the deployed HTTPS
API; realtime tracking automatically uses the matching `wss` URL. Substitute `staging`
and `lib/main_staging.dart` to create a staging build.

## Production services

WhatsApp delivery is configured in the backend. In-app notifications and tracking work
through the API and WebSockets. Background push notifications require Firebase project
configuration files plus obtaining and registering an FCM token with the backend.
