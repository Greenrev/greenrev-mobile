import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/state/auth_provider.dart';
import 'core/state/cart_provider.dart';
import 'core/state/compare_provider.dart';
import 'core/theme/theme.dart';
import 'modules/onboarding/presentation/screens/splash_screen.dart';
import 'core/services/notification_service.dart';

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
      child: MaterialApp(
        title: 'GreenRev',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
