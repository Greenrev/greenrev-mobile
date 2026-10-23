import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/cart_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../inquiries/presentation/widgets/inquiry_modal.dart';
import 'parts_details_screen.dart';

/// Same popular list the website seeds its category filter with.
const _popularCategories = [
  'Engines',
  'Brake Pads',
  'Lights',
  'Batteries',
  'Air Filters',
  'Shock Absorbers',
  'Spark Plugs',
  'Tyres',
  'Alternators',
];

/// "Parts" — web: /parts. A part's category is its `make` field, as on the website.
class PartsScreen extends StatefulWidget {
  const PartsScreen({super.key});

  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  final _searchController = TextEditingController();
  List<ProductModel> _allParts = [];
  bool _isLoading = true;
  String? _error;
  String _activeCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchParts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchParts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().get('/api/v1/products?category=part', requiresAuth: false);
      final list = (response is Map ? response['products'] : null) as List? ?? const [];
      _allParts = list.whereType<Map<String, dynamic>>().map(ProductModel.fromJson).toList();
    } catch (e) {
      _error = e is ApiException && e.code != 'NETWORK_ERROR'
          ? e.message
          : 'We couldn\'t load the parts catalogue. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _categories => [
        'All',
        ...{..._popularCategories, for (final p in _allParts) if (p.make.isNotEmpty) p.make},
      ];

  List<ProductModel> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _allParts.where((p) {
      if (_activeCategory != 'All' && p.make != _activeCategory) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.make.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _clearAll() => setState(() {
        _activeCategory = 'All';
        _searchController.clear();
      });

  @override
  Widget build(BuildContext context) {
    final parts = _filtered;

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.cardBg,
        onRefresh: _fetchParts,
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GrPageHeader(
                        title: 'Parts',
                        subtitle:
                            'Find top-quality parts for your vehicle, including engines, brake pads, lights, batteries, air filters, shock absorbers, and more.',
                        size: 48,
                      ),
                      const SizedBox(height: 24),
                      GrTextField(
                        controller: _searchController,
                        hint: 'Search components...',
                        icon: Icons.search,
                        textInputAction: TextInputAction.search,
                      ),
                      const SizedBox(height: 22),
                      const GrSectionLabel('Categories'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = _categories[i];
                            final selected = cat == _activeCategory;
                            return GestureDetector(
                              onTap: () => setState(() => _activeCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: selected ? Colors.white : AppTheme.border),
                                ),
                                child: Text(
                                  cat.toUpperCase(),
                                  style: TextStyle(
                                    color: selected ? Colors.black : Colors.white60,
                                    fontSize: 10,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                  children: List.generate(
                    4,
                    (_) => Shimmer.fromColors(
                      baseColor: Colors.white10,
                      highlightColor: Colors.white24,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: GrEmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Catalogue unavailable',
                  message: _error!,
                  actionLabel: 'Try Again',
                  onAction: _fetchParts,
                ),
              )
            else if (parts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: GrEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No parts found.',
                  message: 'Try a different category or search term.',
                  actionLabel: 'Clear All Filters',
                  onAction: _clearAll,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverGrid.builder(
                  itemCount: parts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.6,
                  ),
                  itemBuilder: (context, i) => _PartCard(
                    part: parts[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PartsDetailsScreen(part: parts[i])),
                    ),
                  ),
                ),
              ),
            ],
            if (!_isLoading && _error == null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                sliver: SliverToBoxAdapter(
                  child: GrCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GrEyebrow('Expert Tuning'),
                        const SizedBox(height: 10),
                        const Text('Need help with installation or selecting the right spec?',
                            style: TextStyle(color: Colors.white, fontSize: 19, height: 1.25)),
                        const SizedBox(height: 18),
                        GrSecondaryButton(label: 'Contact Support', onPressed: () => InquiryModalSheet.show(context)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final ProductModel part;
  final VoidCallback onTap;
  const _PartCard({required this.part, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inCart = context.select<CartProvider, bool>((c) => c.items.any((i) => i.product.id == part.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero(
                tag: 'part-${part.id}',
                child: Image(
                  image: safeImageProvider(part.image),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.black,
                    child: const Icon(Icons.settings_outlined, color: Colors.white12, size: 36),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (part.vendorName?.isNotEmpty ?? false ? part.vendorName! : part.make).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.accent, fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(part.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.15)),
                  const SizedBox(height: 8),
                  Text(part.displayPrice, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: inCart
                          ? null
                          : () {
                              context.read<CartProvider>().addItem(part);
                              showGrSnack(context, '${part.name} added to your selection.');
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        foregroundColor: inCart ? AppTheme.accent : Colors.white70,
                        disabledForegroundColor: AppTheme.accent,
                        side: BorderSide(color: inCart ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border),
                        textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.bold),
                      ),
                      child: Text(inCart ? 'ADDED' : 'ADD TO SELECTION'),
                    ),
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
