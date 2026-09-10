import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/session_controller.dart';
import 'auth_layout.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.session});

  final SessionController session;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController(text: '+961 ');
  final codeController = TextEditingController();
  bool codeSent = false;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await widget.session.requestSignInCode(phoneController.text);
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
    if (!formKey.currentState!.validate()) return;
    try {
      await widget.session.signIn(
        phone: phoneController.text,
        code: codeController.text,
      );
    } catch (_) {
      showError();
    }
  }

  void resetPhone() {
    setState(() {
      codeSent = false;
      codeController.clear();
    });
  }

  void showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.session.error ?? 'Something went wrong')),
    );
  }

  Future<void> openSignUp() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignUpPage(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back.',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in with the WhatsApp number registered to your Shisha Go account.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 26),
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
          if (codeSent) ...[
            const SizedBox(height: 12),
            AuthCodeField(controller: codeController),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.session.loading ? null : resetPhone,
                child: const Text('Use another number'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: widget.session,
            builder: (context, _) => AuthSubmitButton(
              loading: widget.session.loading,
              codeSent: codeSent,
              onPressed: codeSent ? verify : requestCode,
              initialLabel: 'Send code with WhatsApp',
              verifyLabel: 'Sign in',
            ),
          ),
          if (codeSent)
            DevelopmentCodeNotice(code: widget.session.developmentCode),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('New to Shisha Go?'),
              TextButton(
                onPressed: widget.session.loading ? null : openSignUp,
                child: const Text('Create an account'),
              ),
            ],
          ),
          const Text(
            'Owner and driver accounts are created in advance and sign in here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
