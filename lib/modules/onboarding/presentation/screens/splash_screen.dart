import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../home/presentation/screens/main_shell.dart';
import 'onboarding_screen.dart';

/// Brand splash → intro slides (first launch only) → login. Signed-in users go straight to the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.7, curve: Curves.easeOut));
  late final Animation<double> _rise = Tween(begin: 16.0, end: 0.0)
      .animate(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.7, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();
    _continue();
  }

  Future<void> _continue() async {
    final auth = context.read<AuthProvider>();
    await Future.delayed(const Duration(milliseconds: 1800));
    // Wait for the persisted session check so the shell opens signed in when possible.
    while (auth.isLoading && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    var seenOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seenOnboarding = prefs.getBool(OnboardingScreen.seenKey) ?? false;
    } catch (_) {}
    if (!mounted) return;

    final Widget destination = auth.isLoggedIn
        ? const MainShell()
        : seenOnboarding
            ? const LoginScreen()
            : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.forest.withValues(alpha: 0.6),
                boxShadow: [BoxShadow(color: AppTheme.forest, blurRadius: 160, spreadRadius: 60)],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fade.value,
                child: Transform.translate(offset: Offset(0, _rise.value), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(image: safeImageProvider('/logo2.png'), height: 72, fit: BoxFit.contain),
                  const SizedBox(height: 28),
                  const GrHeadline('GreenRev', size: 44, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  const GrEyebrow('One Automotive Ecosystem.'),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
