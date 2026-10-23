import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../home/presentation/screens/main_shell.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final success = await authProvider.login(email, _passwordController.text);
    if (!mounted) return;

    if (success) {
      if (authProvider.user?.role == 'admin') {
        await authProvider.clearSession();
        if (!mounted) return;
        setState(() => _errorMessage =
            'Administrator accounts must sign in via the Admin Portal on the website.');
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
      return;
    }

    final msg = authProvider.errorMessage ?? 'Login failed';
    if (msg.toLowerCase().contains('not verified') || msg.contains('EMAIL_NOT_VERIFIED')) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(email: email)));
      return;
    }
    setState(() => _errorMessage = msg);
  }

  void _openRegister(String role) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen(initialRole: role)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Faint greyscale photo + fade, same treatment as the website's mobile login.
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0, 0, 0, 0.10, 0,
              ]),
              child: Image(image: safeImageProvider('/images/home/relinquish.jpeg'), fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black.withValues(alpha: 0.8), Colors.black],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Navigator.of(context).canPop() ? const GrBackLink(label: 'Home') : const SizedBox(height: 32),
                      ),
                      const SizedBox(height: 48),
                      const GrPageHeader(
                        eyebrow: 'GreenRev Boutique',
                        title: 'Portal.',
                        subtitle: 'Sign in to your GreenRev account.',
                        size: 52,
                      ),
                      const SizedBox(height: 40),
                      GrTextField(
                        controller: _emailController,
                        hint: 'Email Address',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^.+@.+\..+$').hasMatch(value.trim())) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      GrTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 28),
                      if (_errorMessage != null) ...[
                        GrNotice(_errorMessage!),
                        const SizedBox(height: 20),
                      ],
                      GrPrimaryButton(
                        label: 'Enter Portal',
                        loadingLabel: 'Authenticating',
                        loading: isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
                            ),
                          ),
                          child: const Text('FORGOT PASSWORD'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const GrDividerLabel('New Here?'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          for (final (label, role) in const [
                            ('Client', 'customer'),
                            ('Vendor', 'vendor'),
                            ('Expert', 'mechanic'),
                          ]) ...[
                            if (role != 'customer') const SizedBox(width: 10),
                            Expanded(child: _SignupChip(label: label, onTap: () => _openRegister(role))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SignupChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.hairline),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
