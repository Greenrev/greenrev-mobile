import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/state/compare_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../concierge/presentation/concierge_sheet.dart';
import '../../../inquiries/presentation/widgets/inquiry_modal.dart';
import '../../../showroom/presentation/screens/compare_screen.dart';

/// Tab indexes in [MainShell] that Home links into.
class HomeTabs {
  static const showroom = 1;
  static const parts = 2;
  static const experts = 3;
}

/// Mirrors the website's landing page: hero → services grid → compare / relinquish
/// → philosophy → "Delivered anywhere." inquiry.
class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;
  const HomeScreen({super.key, this.onSelectTab});

  static const _pillars = [
    (
      'Quality',
      'Every machine at GreenRev undergoes a rigorous 300-point performance and telemetry audit. We deal in absolute technical mastery, ensuring every vehicle in our collection delivers peak efficiency and surgical handling on every curve.',
    ),
    (
      'Exclusivity',
      'Access to high-performance cars and custom modifications. Our global network secures limited-run vehicles for a select clientele that demands nothing less than the extraordinary.',
    ),
    (
      'Innovation',
      "We are the architects of the next automotive renaissance. From advanced aerodynamics to high-performance component integration, we don't just follow industry trends—we set the pace for the future of the road.",
    ),
    (
      'Performance',
      'Speed is our primary directive. We recalibrate the boundaries of what is possible, delivering instant torque and unprecedented power. Every machine we touch is optimized for dominance and engineered for the ultimate drive.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(onExplore: () => onSelectTab?.call(HomeTabs.showroom)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _ConciergeCard(onTap: () => ConciergeSheet.show(context)),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ServiceCard(
                    title: 'The Showroom',
                    description:
                        'A curated collection of world-class machines, meticulously selected for the discerning collector.',
                    image: '/images/home/showroom.jpeg',
                    cta: 'Enter Showroom',
                    height: 340,
                    onTap: () => onSelectTab?.call(HomeTabs.showroom),
                  ),
                  const SizedBox(height: 16),
                  _ServiceCard(
                    title: 'Parts & Performance',
                    description: 'Enhance your car with highest-grade components and custom accessories.',
                    image: '/images/home/parts.png',
                    cta: 'Browse Parts',
                    onTap: () => onSelectTab?.call(HomeTabs.parts),
                  ),
                  const SizedBox(height: 16),
                  _ServiceCard(
                    title: 'Expert Care',
                    description: 'Access our elite network of mechanics and specialized service centers.',
                    image: '/images/home/expert.jpeg',
                    cta: 'Find an Expert',
                    onTap: () => onSelectTab?.call(HomeTabs.experts),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _FeatureCard(
                    title: 'Compare\nand Decide.',
                    description:
                        'Utilize our side-by-side analysis tool to evaluate performance metrics, aerodynamics, and custom options.',
                    cta: 'Launch Comparison',
                    image: '/images/home/compare.jpeg',
                    onTap: () {
                      if (context.read<CompareProvider>().count > 0) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompareScreen()));
                      } else {
                        onSelectTab?.call(HomeTabs.showroom);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    title: 'Relinquish\nYour Machine.',
                    description:
                        'Experience a seamless and discreet transition. Our expert appraisers provide accurate valuations that reflect true pedigree.',
                    cta: 'Get Valuation',
                    image: '/images/home/relinquish.jpeg',
                    onTap: () => InquiryModalSheet.show(
                      context,
                      title: 'Get a Valuation',
                      initialMessage:
                          'I would like a valuation for my vehicle.\n\nMake & model:\nYear:\nMileage:\nCondition / notes:',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: GrPageHeader(
                eyebrow: 'The GreenRev Philosophy',
                title: 'We curate the',
                muted: 'revolution.',
                size: 38,
              ),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < _pillars.length; i++)
              _PillarRow(index: i + 1, title: _pillars[i].$1, description: _pillars[i].$2),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrHeadline('Delivered', muted: 'anywhere.', size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Lagos · Nairobi · Johannesburg',
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 13, letterSpacing: 1),
                  ),
                  const SizedBox(height: 28),
                  GrPrimaryButton(
                    label: 'Inquire Now',
                    onPressed: () => InquiryModalSheet.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120), // clear the floating bottom bar
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onExplore;
  const _Hero({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: safeImageProvider('/images/home/showroom.jpeg'), fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
                  AppTheme.background,
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrEyebrow('One Automotive Ecosystem.'),
                const SizedBox(height: 14),
                const GrHeadline('GreenRev', size: 64),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final (i, word) in const ['Discover', 'Compare', 'Connect'].indexed) ...[
                      if (i > 0)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                        ),
                      Text(
                        word.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connecting buyers with independent vehicle dealers, automotive parts vendors, mechanics and other automotive service providers.',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                GrPrimaryButton(label: 'Explore GreenRev', icon: Icons.arrow_forward, onPressed: onExplore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConciergeCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ConciergeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GrCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GreenRev Concierge', style: TextStyle(color: Colors.white, fontSize: 16)),
                SizedBox(height: 4),
                Text(
                  'AI expert advice on vehicles, specs and parts.',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_outward, color: AppTheme.accent, size: 18),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String description;
  final String image;
  final String cta;
  final double height;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.description,
    required this.image,
    required this.cta,
    required this.onTap,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: safeImageProvider(image), fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black, Colors.black.withValues(alpha: 0.2), Colors.transparent],
                  ),
                  border: Border.all(color: AppTheme.hairline),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.05)),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          cta.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_outward, color: Colors.white, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final String cta;
  final String image;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.cta,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.obsidian,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Image(image: safeImageProvider(image), fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, height: 1.0)),
                const SizedBox(height: 14),
                Text(description, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5)),
                const SizedBox(height: 22),
                GrSecondaryButton(label: cta, onPressed: onTap, icon: Icons.arrow_outward),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  const _PillarRow({required this.index, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: const TextStyle(color: AppTheme.accent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 14),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24)),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.55)),
        ],
      ),
    );
  }
}
