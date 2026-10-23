import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/state/compare_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../products/presentation/widgets/product_actions.dart';
import '../widgets/vehicle_card.dart';
import 'compare_screen.dart';

/// Vehicle detail — web: /shop/[id].
class VehicleDetailsScreen extends StatefulWidget {
  final ProductModel vehicle;
  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _pageController = PageController();
  int _imageIndex = 0;
  List<ProductModel> _suggested = [];

  ProductModel get vehicle => widget.vehicle;

  List<String> get _gallery {
    final all = <String>[if (vehicle.image.isNotEmpty) vehicle.image, ...vehicle.images];
    return all.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final res = await ApiClient().get('/api/v1/products?category=vehicle', requiresAuth: false);
      final list = (res is Map ? res['products'] : null) as List? ?? const [];
      final others = list
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .where((p) => p.id != vehicle.id)
          .take(3)
          .toList();
      if (mounted) setState(() => _suggested = others);
    } catch (_) {
      // Suggestions are optional.
    }
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) showGrSnack(context, 'Could not start a call.', error: true);
  }

  void _toggleCompare() {
    final compare = context.read<CompareProvider>();
    final wasIn = compare.contains(vehicle.id);
    toggleCompareWithFeedback(context, vehicle);
    // Same as the web: adding the second machine jumps straight to the comparison.
    if (!wasIn && compare.count == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompareScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comparing = context.select<CompareProvider, bool>((c) => c.contains(vehicle.id));
    final inCart = context.select<CartProvider, bool>((c) => c.items.any((i) => i.product.id == vehicle.id));
    final gallery = _gallery;
    final specs = vehicle.specs;

    final specRows = <(String, String)>[
      ('0-100', specs?.acceleration != null ? '${specs!.acceleration}s' : 'N/A'),
      ('Horsepower', formatHorsepower(specs?.horsepower)),
      ('Torque', formatTorque(specs?.torque)),
      ('Transmission', specs?.transmission?.trim().isNotEmpty == true ? specs!.transmission!.trim() : 'N/A'),
      ('Top Speed', formatTopSpeed(specs?.topSpeed)),
      ('Mileage', formatMileage(vehicle.mileage)),
      if (vehicle.year != null) ('Year', '${vehicle.year}'),
      if (vehicle.color != null && vehicle.color!.name.trim().isNotEmpty) ('Color', vehicle.color!.name.trim()),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: gallery.isEmpty ? 1 : gallery.length,
                    onPageChanged: (i) => setState(() => _imageIndex = i),
                    itemBuilder: (_, i) {
                      final img = Image(
                        image: safeImageProvider(gallery.isEmpty ? '' : gallery[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
                      );
                      return i == 0 ? Hero(tag: 'vehicle-${vehicle.id}', child: img) : img;
                    },
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99000000), Colors.transparent, AppTheme.background],
                          stops: [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Align(alignment: Alignment.topLeft, child: GrBackLink()),
                    ),
                  ),
                  if (gallery.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < gallery.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _imageIndex ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _imageIndex ? AppTheme.accent : Colors.white30,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            sliver: SliverList.list(
              children: [
                GrEyebrow(vehicle.make),
                const SizedBox(height: 10),
                GrHeadline(vehicle.name, size: 40),
                if (vehicle.vendorName?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text('By ${vehicle.vendorName}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(vehicle.displayPrice, style: const TextStyle(color: AppTheme.accent, fontSize: 30)),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('EXC. TAX',
                          style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if ((vehicle.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(vehicle.description!.trim(),
                      style: const TextStyle(color: AppTheme.textSubtle, fontSize: 15, height: 1.6)),
                ],
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _SpecTile(icon: Icons.speed, label: '0-100 km/h',
                        value: specs?.acceleration != null ? '${specs!.acceleration}s' : 'N/A'),
                    _SpecTile(icon: Icons.bolt, label: 'Power', value: formatHorsepower(specs?.horsepower)),
                    _SpecTile(icon: Icons.layers_outlined, label: 'Torque', value: formatTorque(specs?.torque)),
                    _SpecTile(
                      icon: Icons.memory,
                      label: 'Gearbox',
                      value: (specs?.transmission?.trim().isNotEmpty ?? false)
                          ? specs!.transmission!.trim().split(' ').first
                          : 'N/A',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GrCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Assurance(icon: Icons.verified_user_outlined, text: 'Mechanical Inspection'),
                      const SizedBox(height: 14),
                      const _Assurance(icon: Icons.calendar_today_outlined, text: 'Ready for Dispatch: 48 Hours'),
                      const SizedBox(height: 22),
                      GrPrimaryButton(
                        label: 'Place Acquisition Request',
                        icon: Icons.arrow_outward,
                        onPressed: () => AcquisitionRequestSheet.show(context, vehicle),
                      ),
                      const SizedBox(height: 10),
                      GrSecondaryButton(
                        label: comparing ? 'Added to Compare' : 'Compare Vehicle',
                        icon: Icons.balance,
                        color: comparing ? AppTheme.accent : null,
                        onPressed: _toggleCompare,
                      ),
                      const SizedBox(height: 10),
                      GrSecondaryButton(
                        label: inCart ? 'Added to Selection' : 'Add to Selection',
                        icon: inCart ? Icons.check : Icons.add_shopping_cart,
                        color: inCart ? AppTheme.accent : null,
                        onPressed: inCart
                            ? null
                            : () {
                                context.read<CartProvider>().addItem(vehicle);
                                showGrSnack(context, '${vehicle.name} added to your selection.');
                              },
                      ),
                      const SizedBox(height: 16),
                      Divider(color: AppTheme.hairline, height: 1),
                      const SizedBox(height: 16),
                      VendorContactRow(product: vehicle, onCall: _call),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GrCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GrSectionLabel('Technical Specifications'),
                      const SizedBox(height: 12),
                      for (final (label, value) in specRows)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.hairline))),
                          child: Row(
                            children: [
                              Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14))),
                              Flexible(
                                child: Text(value,
                                    textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                ProductReviews(productId: vehicle.id),
                if (_suggested.isNotEmpty) ...[
                  const SizedBox(height: 56),
                  const GrPageHeader(eyebrow: 'You Might Also Command', title: 'Suggested Machines.', size: 34),
                  const SizedBox(height: 20),
                  for (final s in _suggested) ...[
                    VehicleCard(
                      vehicle: s,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: s)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  GrSecondaryButton(label: 'View Full Showroom', onPressed: () => Navigator.of(context).maybePop()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SpecTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GrCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.4, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Assurance extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Assurance({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
