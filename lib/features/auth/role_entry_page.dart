import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_theme.dart';
import '../../services/session_controller.dart';
import '../../widgets/brand_mark.dart';

class RoleEntryPage extends StatefulWidget {
  const RoleEntryPage({super.key, required this.session});

  final SessionController session;

  @override
  State<RoleEntryPage> createState() => _RoleEntryPageState();
}

class _RoleEntryPageState extends State<RoleEntryPage> {
  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController(text: '+961 ');
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final codeController = TextEditingController();
  bool codeSent = false;
  double? latitude;
  double? longitude;

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    addressController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await widget.session.requestCode(phoneController.text);
      if (!mounted) return;
      setState(() {
        codeSent = true;
        if (widget.session.developmentCode != null) {
          codeController.text = widget.session.developmentCode!;
        }
      });
    } catch (_) {
      showError();
    }
  }

  Future<void> verify() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await widget.session.verify(
        phone: phoneController.text,
        code: codeController.text,
        name: nameController.text,
        address: addressController.text,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      showError();
    }
  }

  Future<void> locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.session.error ?? 'Something went wrong')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (wide) const Expanded(flex: 11, child: _HeroPanel()),
              Expanded(
                flex: 9,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 64 : 24,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!wide) ...[
                                const BrandMark(),
                                const SizedBox(height: 32),
                              ],
                              Text(
                                'Your evening,\ndelivered.',
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Clients create an account here. Owners and drivers use the phone number registered by the owner.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                controller: nameController,
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 2
                                    ? 'Enter your full name'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                validator: (value) =>
                                    (value
                                                ?.replaceAll(RegExp(r'\D'), '')
                                                .length ??
                                            0) <
                                        7
                                    ? 'Enter an international phone number'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'WhatsApp phone number',
                                  prefixIcon: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: addressController,
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 3
                                    ? 'Enter your delivery address'
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Delivery address',
                                  prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: locate,
                                    icon: Icon(
                                      latitude == null
                                          ? Icons.my_location_rounded
                                          : Icons.check_circle_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              if (codeSent) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: codeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  validator: (value) => value?.length != 6
                                      ? 'Enter the six-digit code'
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'WhatsApp verification code',
                                    prefixIcon: Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    counterText: '',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              AnimatedBuilder(
                                animation: widget.session,
                                builder: (context, _) => FilledButton.icon(
                                  onPressed: widget.session.loading
                                      ? null
                                      : codeSent
                                      ? verify
                                      : requestCode,
                                  icon: widget.session.loading
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          codeSent
                                              ? Icons.verified_rounded
                                              : Icons.arrow_forward_rounded,
                                        ),
                                  label: Text(
                                    codeSent
                                        ? 'Verify and continue'
                                        : 'Continue with WhatsApp',
                                  ),
                                ),
                              ),
                              if (widget.session.developmentCode != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Development code: ${widget.session.developmentCode}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              const Text(
                                'A one-time code is sent using the configured WhatsApp Business account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.ember, AppColors.emberDark],
      ),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(light: true),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            size: 100,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'From our fire\nto your night.',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fresh setups, market essentials, and live delivery tracking across Beirut.',
          style: TextStyle(color: Colors.white70, fontSize: 17, height: 1.5),
        ),
        const Spacer(),
        const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Fast delivery',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 28),
            Icon(Icons.location_on_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Live tracking',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
