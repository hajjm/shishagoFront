import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/brand_mark.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!wide) ...[
                            const BrandMark(),
                            const SizedBox(height: 32),
                          ],
                          child,
                        ],
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

class AuthCodeField extends StatelessWidget {
  const AuthCodeField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    maxLength: 6,
    autofillHints: const [AutofillHints.oneTimeCode],
    validator: (value) =>
        value?.length != 6 ? 'Enter the six-digit code sent to WhatsApp' : null,
    decoration: const InputDecoration(
      labelText: 'WhatsApp verification code',
      prefixIcon: Icon(Icons.verified_user_outlined),
      counterText: '',
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.loading,
    required this.codeSent,
    required this.onPressed,
    required this.initialLabel,
    required this.verifyLabel,
  });

  final bool loading;
  final bool codeSent;
  final VoidCallback onPressed;
  final String initialLabel;
  final String verifyLabel;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: loading ? null : onPressed,
    icon: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(codeSent ? Icons.verified_rounded : Icons.arrow_forward_rounded),
    label: Text(codeSent ? verifyLabel : initialLabel),
  );
}

class DevelopmentCodeNotice extends StatelessWidget {
  const DevelopmentCodeNotice({super.key, required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    if (code == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Development code: $code',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
        const Wrap(
          spacing: 28,
          runSpacing: 12,
          children: [
            _HeroBenefit(icon: Icons.bolt_rounded, label: 'Fast delivery'),
            _HeroBenefit(
              icon: Icons.location_on_rounded,
              label: 'Live tracking',
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeroBenefit extends StatelessWidget {
  const _HeroBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
