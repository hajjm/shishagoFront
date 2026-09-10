import 'package:flutter/material.dart';

import 'config/app_environment.dart';
import 'core/app_theme.dart';
import 'data/app_store.dart';
import 'features/auth/sign_in_page.dart';
import 'features/client/client_shell.dart';
import 'features/driver/driver_dashboard.dart';
import 'features/owner/owner_dashboard.dart';
import 'models/app_models.dart';
import 'services/shishago_api.dart';
import 'services/session_controller.dart';
import 'widgets/brand_mark.dart';

class ShishaGoApp extends StatefulWidget {
  const ShishaGoApp({
    super.key,
    this.config = AppConfig.development,
    this.sessionController,
    this.skipRestore = false,
  });

  final AppConfig config;
  final SessionController? sessionController;
  final bool skipRestore;

  @override
  State<ShishaGoApp> createState() => _ShishaGoAppState();
}

class _ShishaGoAppState extends State<ShishaGoApp> {
  late final ShishaGoApi api;
  late final SessionController session;
  late final Future<void> restoration;

  @override
  void initState() {
    super.initState();
    session =
        widget.sessionController ??
        SessionController(ShishaGoApi(baseUrl: widget.config.apiBaseUrl));
    api = session.api;
    restoration = widget.skipRestore ? Future.value() : session.restore();
  }

  @override
  void dispose() {
    if (widget.sessionController == null) {
      session.dispose();
      api.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.config.environment.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<void>(
        future: restoration,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingPage();
          }
          return AnimatedBuilder(
            animation: session,
            builder: (context, _) => session.user == null
                ? SignInPage(session: session)
                : _AuthenticatedHome(session: session),
          );
        },
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({required this.session});

  final SessionController session;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late final ShishaGoStore store;
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    store = ShishaGoStore(api: widget.session.api, session: widget.session);
    initialization = store.initialize();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingPage();
        }
        if (snapshot.hasError) {
          return _ConnectionError(
            message: snapshot.error.toString(),
            onLogout: widget.session.logout,
          );
        }
        return switch (widget.session.user!.role) {
          UserRole.client => ClientShell(store: store, session: widget.session),
          UserRole.owner => OwnerDashboard(
            store: store,
            session: widget.session,
          ),
          UserRole.driver => DriverDashboard(
            store: store,
            session: widget.session,
          ),
        };
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(size: 112),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.message, required this.onLogout});

  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54),
              const SizedBox(height: 16),
              Text(
                'Could not reach Shisha Go',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onLogout,
                child: const Text('Return to sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
