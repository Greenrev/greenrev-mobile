import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/widgets/gr_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgotPassword(_emailController.text.trim());
    if (!mounted) return;
    setState(() {
      _isError = !ok;
      _message = ok
          ? 'If this email exists, a reset link has been sent.'
          : (auth.errorMessage ?? 'Request failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: GrBackLink(label: 'Back to Login')),
                const SizedBox(height: 48),
                const GrPageHeader(
                  title: 'Reset Access',
                  subtitle: 'Request a time-limited password reset link.',
                ),
                const SizedBox(height: 40),
                GrTextField(
                  controller: _emailController,
                  hint: 'Email Address',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^.+@.+\..+$').hasMatch(value.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                if (_message != null) ...[
                  GrNotice(_message!, kind: _isError ? GrNoticeKind.error : GrNoticeKind.success),
                  const SizedBox(height: 20),
                ],
                GrPrimaryButton(
                  label: 'Send Reset Link',
                  loadingLabel: 'Sending...',
                  loading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
