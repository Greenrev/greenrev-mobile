import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/state/compare_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';

bool _isBareNumber(String? v) => v != null && RegExp(r'^\s*[\d.,]+\s*$').hasMatch(v);

/// "12,000 km" — the API stores mileage as a bare number string.
String formatMileage(String? mileage) {
  if (mileage == null || mileage.trim().isEmpty) return 'N/A';
  return _isBareNumber(mileage) ? '${mileage.trim()} km' : mileage.trim();
}

String formatTopSpeed(String? topSpeed) {
  if (topSpeed == null || topSpeed.trim().isEmpty) return 'N/A';
  return _isBareNumber(topSpeed) ? '${topSpeed.trim()} km/h' : topSpeed.trim();
}

String formatTorque(String? torque) {
  if (torque == null || torque.trim().isEmpty) return 'N/A';
  return _isBareNumber(torque) ? '${torque.trim()} Nm' : torque.trim();
}

String formatHorsepower(int? hp) => hp == null || hp == 0 ? 'N/A' : '$hp HP';

/// Toggle compare with the web's two-machine limit; shows feedback either way.
void toggleCompareWithFeedback(BuildContext context, ProductModel vehicle) {
  final compare = context.read<CompareProvider>();
  final wasIn = compare.contains(vehicle.id);
  if (!compare.toggle(vehicle)) {
    showGrSnack(context, 'You can compare up to two machines. Remove one to add another.', error: true);
    return;
  }
  showGrSnack(context, wasIn ? 'Removed from compare.' : '${vehicle.name} added to compare.');
}

/// Mobile counterpart of the website's InventoryCard.
class VehicleCard extends StatelessWidget {
  final ProductModel vehicle;
  final VoidCallback onTap;
  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final comparing = context.select<CompareProvider, bool>((c) => c.contains(vehicle.id));
    final inCart = context.select<CartProvider, bool>((c) => c.items.any((i) => i.product.id == vehicle.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'vehicle-${vehicle.id}',
                    child: Image(
                      image: safeImageProvider(vehicle.image),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.black,
                        child: const Icon(Icons.directions_car_outlined, color: Colors.white12, size: 48),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  if (vehicle.year != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _GlassTag(text: '${vehicle.year}'),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        _RoundAction(
                          icon: comparing ? Icons.check : Icons.compare_arrows,
                          active: comparing,
                          tooltip: 'Add to compare',
                          onTap: () => toggleCompareWithFeedback(context, vehicle),
                        ),
                        const SizedBox(width: 8),
                        _RoundAction(
                          icon: inCart ? Icons.check : Icons.add_shopping_cart,
                          active: inCart,
                          tooltip: 'Add to cart',
                          onTap: () {
                            if (inCart) return;
                            context.read<CartProvider>().addItem(vehicle);
                            showGrSnack(context, '${vehicle.name} added to your selection.');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.make.toUpperCase(),
                    style: const TextStyle(color: AppTheme.accent, fontSize: 10, letterSpacing: 2.4, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(vehicle.name, style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.1)),
                  if (vehicle.vendorName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text('By ${vehicle.vendorName}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Spec(label: 'Mileage', value: formatMileage(vehicle.mileage)),
                      _Spec(label: 'Power', value: formatHorsepower(vehicle.specs?.horsepower)),
                      _Spec(label: 'Top Speed', value: formatTopSpeed(vehicle.specs?.topSpeed)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(vehicle.displayPrice,
                            style: const TextStyle(color: AppTheme.accent, fontSize: 22)),
                      ),
                      const Text('VIEW',
                          style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_outward, color: Colors.white54, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  final String label;
  final String value;
  const _Spec({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  final String text;
  const _GlassTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.active, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.accent : Colors.black.withValues(alpha: 0.55),
            border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
          ),
          child: Icon(icon, size: 17, color: active ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}
