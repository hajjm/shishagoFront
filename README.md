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

## Run

Start `chichagoBack`, then:

```powershell
flutter pub get
flutter run --dart-define=CHICHAGO_API_URL=http://127.0.0.1:8000
```

For an Android emulator, use `http://10.0.2.2:8000`. For a physical phone, use the
backend computer's LAN address. Web location access requires HTTPS or localhost.

## Build targets

```powershell
flutter build web --dart-define=CHICHAGO_API_URL=https://api.example.com
flutter build apk --dart-define=CHICHAGO_API_URL=https://api.example.com
flutter build ios --dart-define=CHICHAGO_API_URL=https://api.example.com
```

iOS builds require macOS/Xcode. Replace `https://api.example.com` with the deployed
HTTPS API; realtime tracking automatically uses the matching `wss` URL.

## Production services

WhatsApp delivery is configured in the backend. In-app notifications and tracking work
through the API and WebSockets. Background push notifications require Firebase project
configuration files plus obtaining and registering an FCM token with the backend.
