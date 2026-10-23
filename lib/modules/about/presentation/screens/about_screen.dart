import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../legal/data/legal_content.dart';
import '../../../legal/presentation/screens/legal_screen.dart';

/// About GreenRev — same content as the website's /about page.
class AboutScreen extends StatelessWidget {
  /// Opens the Showroom tab ("Explore GreenRev").
  final VoidCallback? onExplore;
  const AboutScreen({super.key, this.onExplore});

  static const _pillars = [
    (
      Icons.directions_car_outlined,
      'Vehicles',
      'Explore vehicle listings from independent dealers and sellers and discover options that suit your needs, preferences and budget.',
      false,
    ),
    (
      Icons.settings_outlined,
      'Automotive Parts',
      'Discover automotive parts and components from vendors through the GreenRev marketplace.',
      false,
    ),
    (
      Icons.build_outlined,
      'Mechanics & Experts',
      'Find and connect with mechanics and automotive service providers for maintenance, repairs and other vehicle-related needs.',
      false,
    ),
    (
      Icons.local_shipping_outlined,
      'Rentals & Mobility',
      'Explore available vehicle rental options and connect with logistics mobility services.',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context),
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrEyebrow('Why GreenRev?'),
                  const SizedBox(height: 14),
                  const GrHeadline('Bringing fragmentation', muted: 'together.', mutedColor: AppTheme.accent, size: 34),
                  const SizedBox(height: 18),
                  const _Body(
                    'The automotive market can be fragmented. Buyers often have to move between different platforms, dealers, vendors and service providers to find a vehicle, source parts, locate a mechanic or access other automotive services.',
                  ),
                  const SizedBox(height: 12),
                  const Text('GreenRev exists to bring these experiences together.',
                      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 12),
                  const _Body(
                    'Our platform creates a digital connection between consumers and automotive businesses, making it easier to discover, compare, and connect with options from one connected platform.',
                  ),
                  const SizedBox(height: 20),
                  const GrEyebrow('Discover. Compare. Connect.'),
                  const SizedBox(height: 28),
                  for (final p in _pillars) ...[
                    _PillarCard(icon: p.$1, title: p.$2, description: p.$3, comingSoon: p.$4),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            _section(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Audience(
                    title: 'For Buyers',
                    body:
                        'GreenRev is designed to make automotive discovery easier. Instead of navigating multiple disconnected channels, customers can use one platform to explore vehicles, products and services while accessing information that helps them make more informed decisions.',
                    tagline: 'Our goal is simple: Make the automotive journey easier to navigate.',
                  ),
                  SizedBox(height: 32),
                  _Audience(
                    title: 'For Automotive Businesses',
                    body:
                        'We provide independent dealers, automotive parts vendors, mechanics and other service providers with a digital platform to showcase their businesses, reach potential customers and participate in a growing automotive ecosystem.',
                    tagline: 'Connect your business with people looking for what you offer.',
                  ),
                  SizedBox(height: 32),
                  _TrustBlock(),
                ],
              ),
            ),
            _section(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GrEyebrow('Our Mission'),
                  SizedBox(height: 14),
                  GrHeadline(
                    'To simplify how people discover, compare and access vehicles, automotive products and services through technology.',
                    size: 26,
                  ),
                  SizedBox(height: 14),
                  _Body(
                    'We want to reduce fragmentation within the automotive journey by bringing consumers and automotive businesses together through one connected digital platform.',
                  ),
                  SizedBox(height: 40),
                  GrEyebrow('Our Vision'),
                  SizedBox(height: 14),
                  GrHeadline("To build Africa's connected digital automotive ecosystem.", size: 26),
                  SizedBox(height: 14),
                  _Body(
                    'Beginning in Nigeria, our ambition is to create a platform that connects consumers, automotive businesses, services and technology—and progressively expand the GreenRev ecosystem across Africa and beyond.',
                  ),
                ],
              ),
            ),
            _section(
              child: Column(
                children: [
                  const Text('An Independent Marketplace',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 12),
                  const Text(
                    'GreenRev operates as a digital automotive marketplace and technology platform. Vehicles, automotive parts and services displayed on GreenRev may be offered by independent dealers, sellers, vendors, mechanics and other third-party service providers. Unless expressly stated otherwise, GreenRev does not own the vehicles or products advertised by independent marketplace participants.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1.6),
                      children: const [
                        TextSpan(text: 'GREENREV IS OPERATED BY '),
                        TextSpan(text: 'GREENCREST LIMITED', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        TextSpan(text: ', A COMPANY INCORPORATED IN NIGERIA.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _section(
              child: Column(
                children: [
                  const GrHeadline('Join the',
                      muted: 'Ecosystem', trailing: '.', mutedColor: AppTheme.accent, size: 44, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text(
                    "Whether you're looking for your next vehicle, searching for automotive parts, finding a mechanic, or looking to grow your automotive business, GreenRev is being built to bring those possibilities together.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.55),
                  ),
                  if (onExplore != null) ...[
                    const SizedBox(height: 28),
                    GrPrimaryButton(
                      label: 'Explore GreenRev',
                      onPressed: () {
                        Navigator.of(context).pop();
                        onExplore!();
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(LegalScreen.route(termsOfUse)),
                        child: const Text('TERMS OF USE'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(LegalScreen.route(privacyPolicy)),
                        child: const Text('PRIVACY POLICY'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Font made from Web Fonts (onlinewebfonts.com), licensed by CC BY 4.0.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: safeImageProvider('/images/home/showroom.jpeg'), fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x66000000), AppTheme.background],
              ),
            ),
          ),
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Align(alignment: Alignment.topLeft, child: GrBackLink()),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              children: [
                GrEyebrow('One Automotive Ecosystem'),
                SizedBox(height: 16),
                GrHeadline('GreenRev', size: 60, textAlign: TextAlign.center),
                SizedBox(height: 18),
                Text(
                  'A technology-driven digital automotive marketplace connecting buyers with independent vehicle dealers, automotive parts vendors, mechanics and other automotive service providers through one integrated platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.hairline))),
      child: child,
    );
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.6));
  }
}

class _PillarCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool comingSoon;
  const _PillarCard({required this.icon, required this.title, required this.description, this.comingSoon = false});

  @override
  Widget build(BuildContext context) {
    return GrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const Spacer(),
              if (comingSoon) const GrPill('Coming Soon', color: Colors.white60),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}

class _Audience extends StatelessWidget {
  final String title;
  final String body;
  final String tagline;
  const _Audience({required this.title, required this.body, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 24)),
        const SizedBox(height: 12),
        _Body(body),
        const SizedBox(height: 12),
        Text(tagline, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
      ],
    );
  }
}

class _TrustBlock extends StatelessWidget {
  const _TrustBlock();

  @override
  Widget build(BuildContext context) {
    return GrCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppTheme.accent, size: 22),
              SizedBox(width: 10),
              Text('Built Around Trust', style: TextStyle(color: Colors.white, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          const _Body(
            'Trust is essential in the automotive marketplace. GreenRev is being developed with technology and platform controls designed to support greater accountability across interactions.',
          ),
          const SizedBox(height: 14),
          for (final item in const [
            'Business and provider verification',
            'Structured marketplace listings',
            'Transaction references and tracking',
            'Ratings and reviews',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $item', style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
