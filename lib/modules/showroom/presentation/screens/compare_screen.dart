import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/state/compare_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../concierge/presentation/concierge_sheet.dart';
import '../widgets/vehicle_card.dart';
import 'vehicle_details_screen.dart';

double? _num(String? s) => s == null ? null : double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));

/// "Compare Models" — web: /compare. Reads the shared [CompareProvider].
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CompareProvider>().items;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          children: [
            const Align(alignment: Alignment.centerLeft, child: GrBackLink()),
            const SizedBox(height: 28),
            const GrPageHeader(
              eyebrow: 'Performance Analysis',
              title: 'Compare Models',
              size: 42,
              alignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 32),
            if (items.isEmpty)
              _EmptyState(onExplore: () => Navigator.of(context).maybePop())
            else ...[
              _Heads(items: items),
              const SizedBox(height: 24),
              if (items.length == 1)
                _ChallengerSlot(onBrowse: () => Navigator.of(context).maybePop())
              else ...[
                _SpecRow(
                  label: 'Horsepower',
                  values: [for (final v in items) v.specs?.horsepower?.toDouble()],
                  format: (v) => '${v.toStringAsFixed(0)} HP',
                ),
                _SpecRow(
                  label: 'Acceleration (0-100)',
                  values: [for (final v in items) v.specs?.acceleration],
                  format: (v) => '${v}s',
                  lowerIsBetter: true,
                ),
                _SpecRow(
                  label: 'Top Speed',
                  values: [for (final v in items) _num(v.specs?.topSpeed)],
                  format: (v) => '${v.toStringAsFixed(0)} km/h',
                ),
                _TextRow(label: 'Torque', values: [for (final v in items) formatTorque(v.specs?.torque)]),
                _TextRow(label: 'Transmission', values: [for (final v in items) v.specs?.transmission ?? 'N/A']),
                _TextRow(label: 'Color', values: [for (final v in items) v.color?.name.trim() ?? 'N/A']),
                _TextRow(label: 'Year', values: [for (final v in items) v.year?.toString() ?? 'N/A']),
                _TextRow(label: 'Price', values: [for (final v in items) v.displayPrice], accent: true),
              ],
              const SizedBox(height: 28),
              GrPrimaryButton(
                label: 'Ask the Compare Concierge',
                icon: Icons.auto_awesome,
                accent: true,
                onPressed: () => ConciergeSheet.show(context, compareItems: items),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onExplore;
  const _EmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return GrEmptyState(
      icon: Icons.layers_outlined,
      title: 'Head to Head.',
      message: 'Select up to two machines from our curated inventory to compare their performance, power, and presence.',
      actionLabel: 'Explore Showroom',
      onAction: onExplore,
    );
  }
}

class _Heads extends StatelessWidget {
  final List<ProductModel> items;
  const _Heads({required this.items});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: i < items.length ? _HeadCard(vehicle: items[i]) : const SizedBox.shrink()),
            ],
          ],
        ),
        if (items.length == 2)
          Positioned(
            top: 64,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 20)],
              ),
              child: const Text('vs', style: TextStyle(color: AppTheme.accent, fontSize: 16, fontStyle: FontStyle.italic)),
            ),
          ),
      ],
    );
  }
}

class _HeadCard extends StatelessWidget {
  final ProductModel vehicle;
  const _HeadCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.1,
                child: Image(
                  image: safeImageProvider(vehicle.image),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => context.read<CompareProvider>().remove(vehicle.id),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white70, size: 15),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.make.toUpperCase(),
                    style: const TextStyle(color: AppTheme.accent, fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(vehicle.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.15)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: vehicle)),
                  ),
                  child: const Text('VIEW FULL DETAILS',
                      style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengerSlot extends StatelessWidget {
  final VoidCallback onBrowse;
  const _ChallengerSlot({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        color: Colors.white.withValues(alpha: 0.01),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text('+', style: TextStyle(color: Colors.white54, fontSize: 24)),
          ),
          const SizedBox(height: 18),
          const GrHeadline('Add a Challenger', size: 24, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text(
            'Select another vehicle from the shop to compare technical specifications side-by-side.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          GrSecondaryButton(label: 'Browse Inventory', onPressed: onBrowse),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final List<double?> values;
  final String Function(double) format;
  final bool lowerIsBetter;

  const _SpecRow({required this.label, required this.values, required this.format, this.lowerIsBetter = false});

  @override
  Widget build(BuildContext context) {
    final a = values[0];
    final b = values.length > 1 ? values[1] : null;
    int? winner;
    if (a != null && b != null && a > 0 && b > 0 && a != b) {
      winner = (lowerIsBetter ? a < b : a > b) ? 0 : 1;
    }
    final present = values.whereType<double>().where((v) => v > 0).toList();
    final maxV = present.isEmpty ? 0.0 : present.reduce((x, y) => x > y ? x : y);
    final minV = present.isEmpty ? 0.0 : present.reduce((x, y) => x < y ? x : y);
    // Bar length relative to the best value: higher-is-better scales by v/max, lower-is-better by min/v.
    double barFor(double? v) {
      if (v == null || v <= 0 || maxV == 0) return 0;
      return lowerIsBetter ? minV / v : v / maxV;
    }

    return _RowShell(
      label: label,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        values[i] == null || values[i] == 0 ? 'N/A' : format(values[i]!),
                        style: TextStyle(color: winner == i ? AppTheme.accent : Colors.white, fontSize: 17),
                      ),
                    ),
                    if (winner == i) ...[
                      const SizedBox(width: 6),
                      const GrPill('Winner'),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: barFor(values[i]),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    color: winner == i ? AppTheme.accent : Colors.white30,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TextRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final bool accent;
  const _TextRow({required this.label, required this.values, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      label: label,
      children: [
        for (final v in values)
          Expanded(
            child: Text(v, style: TextStyle(color: accent ? AppTheme.accent : Colors.white, fontSize: accent ? 17 : 15)),
          ),
      ],
    );
  }
}

class _RowShell extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _RowShell({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrSectionLabel(label),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}
