import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/device_location_service.dart';
import '../../services/session_controller.dart';
import 'auth_layout.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.session,
    this.locationService = const DeviceLocationService(),
  });

  final SessionController session;
  final DeviceLocationService locationService;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController(text: '+961 ');
  final addressController = TextEditingController();
  final codeController = TextEditingController();
  CapturedLocation? location;
  String? locationError;
  bool codeSent = false;
  bool capturingLocation = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> captureLocation() async {
    setState(() {
      capturingLocation = true;
      locationError = null;
    });
    try {
      final result = await widget.locationService.captureCurrent();
      if (!mounted) return;
      setState(() => location = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => locationError = error.toString());
    } finally {
      if (mounted) setState(() => capturingLocation = false);
    }
  }

  bool validateSignUp() {
    final formValid = formKey.currentState!.validate();
    if (location == null) {
      setState(() {
        locationError = 'Capture your delivery location before continuing.';
      });
      return false;
    }
    return formValid;
  }

  Future<void> requestCode() async {
    if (!validateSignUp()) return;
    try {
      await widget.session.requestSignUpCode(phoneController.text);
      if (!mounted) return;
      setState(() {
        codeSent = true;
        codeController.text = widget.session.developmentCode ?? '';
      });
    } catch (_) {
      showError();
    }
  }

  Future<void> verify() async {
    if (!validateSignUp()) return;
    try {
      await widget.session.signUp(
        phone: phoneController.text,
        code: codeController.text,
        name: nameController.text.trim(),
        address: addressController.text.trim(),
        latitude: location!.latitude,
        longitude: location!.longitude,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      showError();
    }
  }

  void showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.session.error ?? 'Something went wrong')),
    );
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.session.loading
                  ? null
                  : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to sign in'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your\naccount.',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Client accounts need a delivery address and a precise GPS point. Driver and owner accounts are created by the owner.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: nameController,
            enabled: !codeSent,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            enabled: !codeSent,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: (value) =>
                (value?.replaceAll(RegExp(r'\D'), '').length ?? 0) < 7
                ? 'Enter an international phone number'
                : null,
            decoration: const InputDecoration(
              labelText: 'WhatsApp phone number',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            enabled: !codeSent,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.fullStreetAddress],
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Enter your street, building, and area'
                : null,
            decoration: const InputDecoration(
              labelText: 'Written delivery address',
              hintText: 'Street, building, floor, area',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: codeSent || capturingLocation ? null : captureLocation,
            icon: capturingLocation
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    location == null
                        ? Icons.my_location_rounded
                        : Icons.check_circle_rounded,
                  ),
            label: Text(
              capturingLocation
                  ? 'Finding your location…'
                  : location == null
                  ? 'Use my current location'
                  : 'Location captured — update',
            ),
          ),
          if (location != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Captured coordinates ${location!.label}',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.sage,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS: ${location!.label}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              locationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'The written address helps the driver find the building; GPS saves the exact delivery point.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          if (codeSent) ...[
            const SizedBox(height: 12),
            AuthCodeField(controller: codeController),
          ],
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: widget.session,
            builder: (context, _) => AuthSubmitButton(
              loading: widget.session.loading,
              codeSent: codeSent,
              onPressed: codeSent ? verify : requestCode,
              initialLabel: 'Send verification code',
              verifyLabel: 'Verify and create account',
            ),
          ),
          if (codeSent)
            DevelopmentCodeNotice(code: widget.session.developmentCode),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.session.loading
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    ),
  );
}
