import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../home/presentation/screens/main_shell.dart';

class OnboardingItem {
  final String eyebrow;
  final String title;
  final String? muted;
  final String description;
  final String imagePath;

  const OnboardingItem({
    required this.eyebrow,
    required this.title,
    this.muted,
    required this.description,
    required this.imagePath,
  });
}

/// First-launch intro slides. Copy mirrors the website's landing page sections.
class OnboardingScreen extends StatefulWidget {
  /// SharedPreferences flag — set once the intro has been completed or skipped.
  static const seenKey = 'has_seen_onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingItem(
      eyebrow: '01 / The Showroom',
      title: 'The',
      muted: 'Showroom.',
      description:
          'A curated collection of world-class machines, meticulously selected for the discerning collector.',
      imagePath: '/images/home/showroom.jpeg',
    ),
    OnboardingItem(
      eyebrow: '02 / Parts & Performance',
      title: 'Parts &',
      muted: 'Performance.',
      description: 'Enhance your car with highest-grade components and custom accessories.',
      imagePath: '/images/home/parts.png',
    ),
    OnboardingItem(
      eyebrow: '03 / Expert Care',
      title: 'Expert',
      muted: 'Care.',
      description: 'Access our elite network of mechanics and specialized service centers.',
      imagePath: '/images/home/expert.jpeg',
    ),
    OnboardingItem(
      eyebrow: '04 / Compare',
      title: 'Compare',
      muted: 'and Decide.',
      description:
          'Utilize our side-by-side analysis tool to evaluate performance metrics, aerodynamics, and custom options.',
      imagePath: '/images/home/compare.jpeg',
    ),
    OnboardingItem(
      eyebrow: '05 / Relinquish',
      title: 'Relinquish',
      muted: 'Your Machine.',
      description:
          'Experience a seamless and discreet transition. Our expert appraisers provide accurate valuations that reflect true pedigree.',
      imagePath: '/images/home/relinquish.jpeg',
    ),
    OnboardingItem(
      eyebrow: '06 / Concierge',
      title: 'GreenRev',
      muted: 'Concierge.',
      description: 'AI expert advice on vehicles, specs and parts — whenever you need it.',
      imagePath: '/images/home/showroom.png',
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.seenKey, true);
    } catch (_) {}

    if (!mounted) return;
    final destination = context.read<AuthProvider>().isLoggedIn ? const MainShell() : const LoginScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _complete();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => _Slide(item: _pages[i], bottomSpace: 150 + bottomInset),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  Image(image: safeImageProvider('/logo2.png'), height: 30, fit: BoxFit.contain),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isLast ? 0 : 1,
                    child: TextButton(
                      onPressed: _isLast ? null : _complete,
                      child: const Text('SKIP'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32 + bottomInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentPage ? AppTheme.accent : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${(_currentPage + 1).toString().padLeft(2, '0')} / ${_pages.length.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GrPrimaryButton(
                  label: _isLast ? 'Get Started' : 'Next',
                  icon: Icons.arrow_forward,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final OnboardingItem item;
  final double bottomSpace;
  const _Slide({required this.item, required this.bottomSpace});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: safeImageProvider(item.imagePath), fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x33000000), Color(0xF2050606), AppTheme.background],
              stops: [0, 0.3, 0.72, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomSpace),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GrEyebrow(item.eyebrow),
              const SizedBox(height: 16),
              GrHeadline(item.title, muted: item.muted, size: 46),
              const SizedBox(height: 16),
              Text(
                item.description,
                style: const TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
