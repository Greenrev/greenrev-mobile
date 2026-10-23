import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import 'login_screen.dart';

/// "Verify your email" — six single-digit boxes, same as the website.
class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 6;
  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _focusNodes = List.generate(_length, (_) => FocusNode());
  String? _message;
  bool _isError = true;
  bool _verified = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _pin => _controllers.map((c) => c.text).join();

  final _previous = List.filled(_length, '');

  void _onChanged(int index, String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    // Typing over a filled box yields two digits — keep only the new one.
    if (digits.length == 2 && _previous[index].isNotEmpty) {
      digits = digits.replaceFirst(_previous[index], '');
    }
    if (digits.length > 1) {
      // Pasted or autofilled code: spread it across the boxes.
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _focusNodes[(digits.length.clamp(1, _length)) - 1].requestFocus();
    } else {
      _controllers[index].text = digits;
      if (digits.isNotEmpty && index < _length - 1) _focusNodes[index + 1].requestFocus();
    }
    for (var i = 0; i < _length; i++) {
      _previous[i] = _controllers[i].text;
    }
    setState(() {});
    if (_pin.length == _length) _verify();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _previous[index - 1] = '';
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verify() async {
    if (_verified || context.read<AuthProvider>().isLoading) return;
    if (_pin.length != _length) {
      setState(() {
        _isError = true;
        _message = 'Please enter the full 6-digit PIN.';
      });
      return;
    }
    setState(() => _message = null);

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyEmail(widget.email, _pin);
    if (!mounted) return;

    if (success) {
      setState(() => _verified = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _isError = true;
        _message = auth.errorMessage ?? 'Invalid PIN. Please try again.';
      });
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resendVerification(widget.email);
    if (!mounted) return;
    setState(() {
      _isError = !success;
      _message = success ? 'A new PIN has been sent to your email.' : (auth.errorMessage ?? 'Failed to resend PIN');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: GrBackLink(label: 'Back to Login')),
              const SizedBox(height: 48),
              GrPageHeader(
                title: 'Verify your email',
                subtitle: 'Enter the 6-digit PIN we sent to ${widget.email.isEmpty ? 'your email address' : widget.email}.',
                size: 40,
              ),
              const SizedBox(height: 40),
              if (_verified)
                const _VerifiedBanner()
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _length; i++)
                      SizedBox(
                        width: 48,
                        height: 58,
                        child: Focus(
                          onKeyEvent: (_, e) => _onKey(i, e),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            autofocus: i == 0,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            cursorColor: AppTheme.accent,
                            autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            onChanged: (v) => _onChanged(i, v),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.04),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: _controllers[i].text.isNotEmpty
                                      ? AppTheme.accent.withValues(alpha: 0.4)
                                      : AppTheme.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_message != null) ...[
                  GrNotice(_message!, kind: _isError ? GrNoticeKind.error : GrNoticeKind.success),
                  const SizedBox(height: 20),
                ],
                GrPrimaryButton(
                  label: 'Verify Email',
                  loadingLabel: 'Verifying…',
                  loading: isLoading,
                  onPressed: _verify,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: isLoading ? null : _resend,
                    child: const Text('RESEND PIN'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedBanner extends StatelessWidget {
  const _VerifiedBanner();

  @override
  Widget build(BuildContext context) {
    return GrCard(
      borderColor: AppTheme.accent.withValues(alpha: 0.25),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.accent),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Email verified! Redirecting to login…',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
