import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/state/auth_provider.dart';
import 'core/state/cart_provider.dart';
import 'core/state/compare_provider.dart';
import 'core/theme/theme.dart';
import 'modules/onboarding/presentation/screens/splash_screen.dart';
import 'core/services/notification_service.dart';
import 'core/services/visit_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CompareProvider()),
      ],
      child: _VisitTrackerHost(
        child: MaterialApp(
          title: 'GreenRev',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Starts daily-visit counting once the auth state is available.
class _VisitTrackerHost extends StatefulWidget {
  final Widget child;
  const _VisitTrackerHost({required this.child});

  @override
  State<_VisitTrackerHost> createState() => _VisitTrackerHostState();
}

class _VisitTrackerHostState extends State<_VisitTrackerHost> {
  @override
  void initState() {
    super.initState();
    VisitTracker.instance.start(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
