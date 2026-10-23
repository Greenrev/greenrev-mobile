import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../legal/data/legal_content.dart';
import '../../../legal/presentation/screens/legal_screen.dart';
import 'otp_screen.dart';

/// Copy per role, taken from the website's /register, /vendor-signup and /mechanic-signup pages.
class _RoleCopy {
  final String label;
  final String title;
  final String subtitle;
  final String nameHint;
  final String? businessHint;
  final String emailHint;
  final String cta;
  final String ctaLoading;

  const _RoleCopy({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.nameHint,
    this.businessHint,
    required this.emailHint,
    required this.cta,
    required this.ctaLoading,
  });
}

const _roleCopy = <String, _RoleCopy>{
  'customer': _RoleCopy(
    label: 'Client',
    title: 'Client Access.',
    subtitle: 'Join the GreenRev network to manage your acquisitions.',
    nameHint: 'Full Name',
    emailHint: 'Email Address',
    cta: 'Create Profile',
    ctaLoading: 'Creating Profile...',
  ),
  'vendor': _RoleCopy(
    label: 'Vendor',
    title: 'Vendor Application.',
    subtitle: 'Join the GreenRev network to list your premium inventory.',
    nameHint: 'Contact Full Name',
    businessHint: 'Dealership / Company Name',
    emailHint: 'Business Email',
    cta: 'Submit Application',
    ctaLoading: 'Submitting Application...',
  ),
  'mechanic': _RoleCopy(
    label: 'Expert',
    title: 'Expert Registration.',
    subtitle: 'Join the elite network of performance mechanics.',
    nameHint: 'Expert Full Name',
    businessHint: 'Garage / Shop Name',
    emailHint: 'Professional Email',
    cta: 'Apply as Expert',
    ctaLoading: 'Registering...',
  ),
};

class RegisterScreen extends StatefulWidget {
  final String initialRole;
  const RegisterScreen({super.key, this.initialRole = 'customer'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();

  late String _selectedRole = _roleCopy.containsKey(widget.initialRole) ? widget.initialRole : 'customer';
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _businessController.dispose();
    super.dispose();
  }

  int get _passwordScore {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z\d]').hasMatch(p)) score++;
    return score;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final authProvider = context.read<AuthProvider>();
    final business = _businessController.text.trim();
    final email = _emailController.text.trim();
    final success = await authProvider.register(
      email: email,
      password: _passwordController.text,
      role: _selectedRole,
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      companyName: _selectedRole == 'vendor' ? business : null,
      garageName: _selectedRole == 'mechanic' ? business : null,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
      );
    } else {
      setState(() => _errorMessage = authProvider.errorMessage ?? 'Signup failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final copy = _roleCopy[_selectedRole]!;

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
                const SizedBox(height: 32),
                _RoleSwitcher(
                  selected: _selectedRole,
                  onChanged: (role) => setState(() {
                    _selectedRole = role;
                    _errorMessage = null;
                  }),
                ),
                const SizedBox(height: 36),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: GrPageHeader(
                    key: ValueKey(_selectedRole),
                    title: copy.title,
                    subtitle: copy.subtitle,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 32),
                if (copy.businessHint != null) ...[
                  GrTextField(
                    controller: _businessController,
                    hint: copy.businessHint!,
                    icon: Icons.storefront_outlined,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 8),
                ],
                GrTextField(
                  controller: _nameController,
                  hint: copy.nameHint,
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 8),
                GrTextField(
                  controller: _emailController,
                  hint: copy.emailHint,
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
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Use at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _PasswordStrength(score: _passwordScore),
                const SizedBox(height: 24),
                _TermsCheckbox(
                  value: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v),
                ),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  GrNotice(_errorMessage!),
                  const SizedBox(height: 20),
                ],
                GrPrimaryButton(
                  label: copy.cta,
                  loadingLabel: copy.ctaLoading,
                  loading: isLoading,
                  icon: null,
                  onPressed: _agreedToTerms ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitcher extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RoleSwitcher({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          for (final entry in _roleCopy.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == entry.key ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.value.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: selected == entry.key ? Colors.black : Colors.white54,
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

class _PasswordStrength extends StatelessWidget {
  final int score;
  const _PasswordStrength({required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GrSectionLabel('Password Strength'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: score > i ? AppTheme.accent : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Use 8+ chars with upper/lowercase, number, and symbol.',
          style: TextStyle(color: AppTheme.textSubtle, fontSize: 11),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  State<_TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<_TermsCheckbox> {
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(LegalScreen.route(termsOfUse));
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(LegalScreen.route(privacyPolicy));

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: Colors.white,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white38,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: widget.value,
            onChanged: (v) => widget.onChanged(v ?? false),
            activeColor: AppTheme.accent,
            checkColor: Colors.black,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(text: 'Terms of Use', style: link, recognizer: _termsTap),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacyTap),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
