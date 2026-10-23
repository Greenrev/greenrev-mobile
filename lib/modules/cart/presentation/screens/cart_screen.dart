import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/cart_item_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../acquisitions/presentation/screens/acquisitions_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

String priceLabel(CartItemModel item) => item.product.displayPrice;

/// "Your Selection." — web: /cart.
class CartScreen extends StatelessWidget {
  /// Switches to the Showroom tab ("Explore Inventory").
  final VoidCallback? onBrowse;
  const CartScreen({super.key, this.onBrowse});

  void _checkout(BuildContext context) {
    if (!context.read<AuthProvider>().isLoggedIn) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(onBrowse: onBrowse),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;
    final vehicles = cart.vehicleItems;
    final parts = cart.partItems;
    final total = items.fold<double>(0, (sum, i) => sum + i.product.priceValue * i.quantity);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GrHeadline('Your', muted: 'Selection.', mutedColor: AppTheme.accent, size: 46),
                      const SizedBox(height: 12),
                      GrSectionLabel('${items.length} ${items.length == 1 ? 'Item' : 'Items'} Selected'),
                    ],
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: GrCard(
                    child: GrEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Your selection is empty.',
                      message: "You haven't added any vehicles or parts to your cart yet.",
                      actionLabel: onBrowse != null ? 'Explore Inventory' : null,
                      onAction: onBrowse,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
                sliver: SliverList.list(
                  children: [
                    if (vehicles.isNotEmpty) ...[
                      _GroupLabel('Machines'),
                      for (final item in vehicles) _VehicleRow(item: item),
                      const SizedBox(height: 28),
                    ],
                    if (parts.isNotEmpty) ...[
                      _GroupLabel('Components'),
                      for (final item in parts) _PartRow(item: item),
                      const SizedBox(height: 28),
                    ],
                    _Summary(
                      vehicleCount: vehicles.length,
                      partCount: parts.length,
                      total: total,
                      onCheckout: () => _checkout(context),
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

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2))),
      ),
      child: GrEyebrow(text),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String image;
  final double size;
  const _Thumb(this.image, {this.size = 88});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: Colors.black,
        child: Image(
          image: safeImageProvider(image),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: Colors.white24),
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final CartItemModel item;
  const _VehicleRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    final meta = [
      if (p.year != null) '${p.year}',
      if (p.specs?.horsepower != null) '${p.specs!.horsepower} HP',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GrCard(
        padding: const EdgeInsets.all(12),
        radius: 20,
        child: Row(
          children: [
            _Thumb(p.image),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((p.vendorName ?? p.make).isNotEmpty)
                    Text((p.vendorName ?? p.make).toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.15)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 11)),
                  ],
                  const SizedBox(height: 8),
                  Text(priceLabel(item), style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () => context.read<CartProvider>().removeItem(p.id),
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  final CartItemModel item;
  const _PartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    final cart = context.read<CartProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GrCard(
        padding: const EdgeInsets.all(12),
        radius: 20,
        child: Row(
          children: [
            _Thumb(p.image, size: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(priceLabel(item), style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _QtyButton(icon: Icons.remove, onTap: () => cart.updateQuantity(p.id, item.quantity - 1)),
                      SizedBox(
                        width: 36,
                        child: Text('${item.quantity}',
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                      _QtyButton(icon: Icons.add, onTap: () => cart.updateQuantity(p.id, item.quantity + 1)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () => cart.removeItem(p.id),
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
        child: Icon(icon, size: 14, color: Colors.white70),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final int vehicleCount;
  final int partCount;
  final double total;
  final VoidCallback onCheckout;

  const _Summary({
    required this.vehicleCount,
    required this.partCount,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(color: strong ? Colors.white : AppTheme.textSubtle, fontSize: strong ? 15 : 13)),
              ),
              Text(value, style: TextStyle(color: Colors.white, fontSize: strong ? 22 : 14)),
            ],
          ),
        );

    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    return GrCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrSectionLabel('Acquisition Summary'),
          const SizedBox(height: 14),
          if (vehicleCount > 0) row('$vehicleCount ${vehicleCount == 1 ? 'Vehicle' : 'Vehicles'}', ''),
          if (partCount > 0) row('$partCount ${partCount == 1 ? 'Component' : 'Components'}', ''),
          Divider(color: AppTheme.border, height: 24),
          row('Total Value', grMoney(total), strong: true),
          const SizedBox(height: 20),
          GrPrimaryButton(label: 'Send Acquisition Request', icon: Icons.send_rounded, onPressed: onCheckout),
          const SizedBox(height: 12),
          Text(
            loggedIn
                ? 'Each item is sent as a separate request to its vendor.'
                : 'Each item is sent as a separate request to its vendor. Authentication required.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSubtle, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final VoidCallback? onBrowse;
  const _RequestSheet({this.onBrowse});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _message = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cart = context.read<CartProvider>();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final text = _message.text.trim();
      await Future.wait([
        for (final item in cart.items)
          ApiClient().post('/api/v1/acquisition-requests', body: {
            'productId': item.product.id,
            'quantity': item.quantity,
            if (text.isNotEmpty) 'message': text,
          }),
      ]);
      cart.clearAll();
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : 'Failed to submit request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final total = cart.items.fold<double>(0, (sum, i) => sum + i.product.priceValue * i.quantity);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (_success) ..._successContent(context) else ..._formContent(cart, total),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formContent(CartProvider cart, double total) => [
        const GrHeadline('Confirm Acquisition Request', size: 26),
        const SizedBox(height: 10),
        const Text(
          'Each item will be sent as a separate request to its vendor. Their contact details will be revealed once they accept.',
          style: TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        for (final item in cart.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _Thumb(item.product.image, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.quantity > 1 ? '${item.product.name} × ${item.quantity}' : item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Text(priceLabel(item), style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
              ],
            ),
          ),
        Divider(color: AppTheme.border, height: 24),
        Row(
          children: [
            const Expanded(child: GrSectionLabel('Total Value')),
            Text(grMoney(total), style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 20),
        GrTextArea(controller: _message, hint: 'Introduce yourself or add any notes for the vendors…', minLines: 3),
        Align(
          alignment: Alignment.centerRight,
          child: ListenableBuilder(
            listenable: _message,
            builder: (_, _) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_message.text.length}/1000',
                style: TextStyle(
                  color: _message.text.length > 1000 ? AppTheme.danger : Colors.white30,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          GrNotice(_error!),
          const SizedBox(height: 16),
        ],
        ListenableBuilder(
          listenable: _message,
          builder: (_, _) => GrPrimaryButton(
            label: 'Send Acquisition Request',
            loadingLabel: 'Submitting…',
            loading: _submitting,
            icon: Icons.send_rounded,
            onPressed: _message.text.length > 1000 ? null : _submit,
          ),
        ),
      ];

  List<Widget> _successContent(BuildContext context) => [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 32),
          ),
        ),
        const SizedBox(height: 18),
        const GrHeadline('All requests sent!', size: 28, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Your vendors have been notified.',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSubtle, fontSize: 14)),
        const SizedBox(height: 22),
        GrCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GrEyebrow('Next Step'),
              SizedBox(height: 8),
              Text(
                "Once vendors accept, you'll see their contact details and a payment receipt upload field in your requests page.",
                style: TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GrPrimaryButton(
          label: 'View My Requests',
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(MaterialPageRoute(builder: (_) => const AcquisitionsScreen()));
          },
        ),
        const SizedBox(height: 10),
        GrSecondaryButton(
          label: 'Continue Browsing',
          onPressed: () {
            Navigator.pop(context);
            widget.onBrowse?.call();
          },
        ),
      ];
}
