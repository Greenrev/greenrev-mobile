import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../products/presentation/widgets/product_actions.dart';

/// Part detail — web: /parts/[id].
class PartsDetailsScreen extends StatefulWidget {
  final ProductModel part;
  const PartsDetailsScreen({super.key, required this.part});

  @override
  State<PartsDetailsScreen> createState() => _PartsDetailsScreenState();
}

class _PartsDetailsScreenState extends State<PartsDetailsScreen> {
  List<ProductModel> _related = [];
  int _imageIndex = 0;

  ProductModel get part => widget.part;

  List<String> get _gallery => <String>{if (part.image.isNotEmpty) part.image, ...part.images}.toList();

  /// Same derivation as the web's transformProductToPartEntry.
  List<String> get _specChips {
    final s = part.specs;
    final chips = <String>[
      if (s?.horsepower != null) '${s!.horsepower} HP',
      if (s?.torque?.isNotEmpty ?? false) s!.torque!,
      if (s?.transmission?.isNotEmpty ?? false) s!.transmission!,
      if (s?.compatibility?.isNotEmpty ?? false) s!.compatibility!,
      if (s?.warranty?.isNotEmpty ?? false) s!.warranty!,
    ];
    return chips.isEmpty ? const ['Premium Quality'] : chips;
  }

  @override
  void initState() {
    super.initState();
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    try {
      final res = await ApiClient().get('/api/v1/products?category=part', requiresAuth: false);
      final list = (res is Map ? res['products'] : null) as List? ?? const [];
      final all = list.whereType<Map<String, dynamic>>().map(ProductModel.fromJson).where((p) => p.id != part.id).toList();
      final sameCategory = all.where((p) => p.make == part.make).toList();
      final related = [...sameCategory, ...all.where((p) => p.make != part.make)].take(4).toList();
      if (mounted) setState(() => _related = related);
    } catch (_) {
      // Related items are optional.
    }
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) showGrSnack(context, 'Could not start a call.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final inCart = context.select<CartProvider, bool>((c) => c.items.any((i) => i.product.id == part.id));
    final gallery = _gallery;
    final brand = (part.vendorName?.isNotEmpty ?? false) ? part.vendorName! : part.make;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            const Align(alignment: Alignment.centerLeft, child: GrBackLink()),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: Colors.black,
                  child: Hero(
                    tag: 'part-${part.id}',
                    child: Image(
                      image: safeImageProvider(gallery.isEmpty ? '' : gallery[_imageIndex]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.settings_outlined, color: Colors.white12, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            if (gallery.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _imageIndex = i),
                    child: Container(
                      width: 64,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: i == _imageIndex ? AppTheme.accent : AppTheme.border),
                      ),
                      child: Image(image: safeImageProvider(gallery[i]), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            GrEyebrow(brand),
            const SizedBox(height: 10),
            GrHeadline(part.name, size: 34),
            const SizedBox(height: 14),
            Text(part.displayPrice, style: const TextStyle(color: AppTheme.accent, fontSize: 28)),
            if ((part.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(part.description!.trim(), style: const TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.6)),
            ],
            const SizedBox(height: 24),
            GrCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrSectionLabel('Technical Specifications'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final c in _specChips) GrPill(c, color: Colors.white70)],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(icon: Icons.verified_user_outlined, label: 'Verified Vendor', value: brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.build_outlined,
                    label: 'Compatibility',
                    value: (part.specs?.compatibility?.isNotEmpty ?? false)
                        ? part.specs!.compatibility!
                        : 'Universal Fit / Spec',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GrPrimaryButton(
              label: 'Place Acquisition Request',
              icon: Icons.arrow_outward,
              onPressed: () => AcquisitionRequestSheet.show(context, part, isPart: true),
            ),
            const SizedBox(height: 10),
            GrSecondaryButton(
              label: inCart ? 'Added to Selection' : 'Add to Selection',
              icon: inCart ? Icons.check : Icons.add_shopping_cart,
              color: inCart ? AppTheme.accent : null,
              onPressed: inCart
                  ? null
                  : () {
                      context.read<CartProvider>().addItem(part);
                      showGrSnack(context, '${part.name} added to your selection.');
                    },
            ),
            const SizedBox(height: 10),
            VendorContactRow(product: part, isPart: true, onCall: _call),
            const SizedBox(height: 48),
            ProductReviews(productId: part.id),
            if (_related.isNotEmpty) ...[
              const SizedBox(height: 56),
              const GrHeadline('Related Components.', size: 32),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: [
                  for (final r in _related)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => PartsDetailsScreen(part: r)),
                      ),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Image(
                                image: safeImageProvider(r.image),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(r.displayPrice, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GrCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
