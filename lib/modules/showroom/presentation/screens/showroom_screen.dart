import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/compare_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../inquiries/presentation/widgets/inquiry_modal.dart';
import '../widgets/vehicle_card.dart';
import 'compare_screen.dart';
import 'vehicle_details_screen.dart';

/// "The Showroom." — web: /shop.
class ShowroomScreen extends StatefulWidget {
  const ShowroomScreen({super.key});

  @override
  State<ShowroomScreen> createState() => _ShowroomScreenState();
}

class _ShowroomScreenState extends State<ShowroomScreen> {
  final ApiClient _apiClient = ApiClient();
  final _searchController = TextEditingController();
  List<ProductModel> _allVehicles = [];
  bool _isLoading = true;
  String? _error;

  String _activeMake = 'All';
  String _activeColor = 'All';
  double? _minPrice;
  double? _maxPrice;
  int? _minYear;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get('/api/v1/products?category=vehicle', requiresAuth: false);
      final list = (response is Map ? response['products'] : null) as List? ?? const [];
      _allVehicles = list.whereType<Map<String, dynamic>>().map(ProductModel.fromJson).toList();
    } catch (e) {
      _error = e is ApiException && e.code != 'NETWORK_ERROR'
          ? e.message
          : 'We couldn\'t reach the showroom. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _makes => ['All', ...{for (final v in _allVehicles) if (v.make.isNotEmpty) v.make}];
  List<String> get _colors =>
      ['All', ...{for (final v in _allVehicles) if ((v.color?.name.trim() ?? '').isNotEmpty) v.color!.name.trim()}];

  List<ProductModel> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _allVehicles.where((v) {
      if (q.isNotEmpty && !v.name.toLowerCase().contains(q) && !v.make.toLowerCase().contains(q)) return false;
      if (_activeMake != 'All' && v.make != _activeMake) return false;
      if (_activeColor != 'All' && v.color?.name.trim() != _activeColor) return false;
      if (_minPrice != null && v.priceValue < _minPrice!) return false;
      if (_maxPrice != null && v.priceValue > _maxPrice!) return false;
      if (_minYear != null && (v.year ?? 0) < _minYear!) return false;
      return true;
    }).toList();
  }

  bool get _hasFilters =>
      _activeMake != 'All' ||
      _activeColor != 'All' ||
      _minPrice != null ||
      _maxPrice != null ||
      _minYear != null ||
      _searchController.text.isNotEmpty;

  void _clearAll() {
    setState(() {
      _activeMake = 'All';
      _activeColor = 'All';
      _minPrice = null;
      _maxPrice = null;
      _minYear = null;
      _searchController.clear();
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterValues>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(initial: _FilterValues(_minPrice, _maxPrice, _minYear)),
    );
    if (result != null) {
      setState(() {
        _minPrice = result.minPrice;
        _maxPrice = result.maxPrice;
        _minYear = result.minYear;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _filtered;
    final compareCount = context.watch<CompareProvider>().count;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.cardBg,
            onRefresh: _fetchVehicles,
            child: CustomScrollView(
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeader()),
                  ),
                ),
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                    sliver: SliverList.separated(
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(height: 20),
                      itemBuilder: (_, _) => Shimmer.fromColors(
                        baseColor: Colors.white10,
                        highlightColor: Colors.white24,
                        child: Container(
                          height: 380,
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: GrEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Showroom unavailable',
                      message: _error!,
                      actionLabel: 'Try Again',
                      onAction: _fetchVehicles,
                    ),
                  )
                else if (vehicles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: GrEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No machines found.',
                      message: 'Adjust your filters or search query to find your perfect match.',
                      actionLabel: _hasFilters ? 'Clear All Filters' : null,
                      onAction: _hasFilters ? _clearAll : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, compareCount > 0 ? 200 : 140),
                    sliver: SliverList.separated(
                      itemCount: vehicles.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 20),
                      itemBuilder: (context, i) {
                        if (i == vehicles.length) return _buildConciergeCard();
                        final v = vehicles[i];
                        return VehicleCard(
                          vehicle: v,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => VehicleDetailsScreen(vehicle: v)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (compareCount > 0) _CompareBar(count: compareCount),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GrPageHeader(
          title: 'The Showroom.',
          subtitle: 'Explore our full inventory of world-class performance machines.',
          size: 44,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GrTextField(
                controller: _searchController,
                hint: 'Search machines...',
                icon: Icons.search,
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(width: 12),
            _FilterButton(
              active: _minPrice != null || _maxPrice != null || _minYear != null,
              onTap: _openFilters,
            ),
          ],
        ),
        if (!_isLoading && _allVehicles.isNotEmpty) ...[
          const SizedBox(height: 22),
          const GrSectionLabel('Manufacturers'),
          const SizedBox(height: 10),
          _ChipRow(values: _makes, active: _activeMake, onSelect: (v) => setState(() => _activeMake = v)),
          if (_colors.length > 2) ...[
            const SizedBox(height: 18),
            const GrSectionLabel('Colors'),
            const SizedBox(height: 10),
            _ChipRow(values: _colors, active: _activeColor, onSelect: (v) => setState(() => _activeColor = v)),
          ],
          if (_hasFilters) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _clearAll, child: const Text('CLEAR ALL')),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildConciergeCard() {
    return GrCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GrEyebrow('Concierge'),
          const SizedBox(height: 10),
          const Text("Can't find what you're looking for?",
              style: TextStyle(color: Colors.white, fontSize: 20, height: 1.2)),
          const SizedBox(height: 18),
          GrSecondaryButton(
            label: 'Request Vehicle',
            onPressed: () => InquiryModalSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
        ),
        child: Icon(Icons.tune, size: 18, color: active ? Colors.black : Colors.white70),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> values;
  final String active;
  final ValueChanged<String> onSelect;
  const _ChipRow({required this.values, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final value = values[i];
          final selected = value == active;
          return GestureDetector(
            onTap: () => onSelect(value),
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
                value.toUpperCase(),
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
    );
  }
}

class _CompareBar extends StatelessWidget {
  final int count;
  const _CompareBar({required this.count});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 96;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111313),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24)],
        ),
        child: Row(
          children: [
            const Icon(Icons.compare_arrows, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1 ? '1 machine selected — add a challenger' : '2 machines ready',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => context.read<CompareProvider>().clear(),
              child: const Text('CLEAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompareScreen())),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('COMPARE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterValues {
  final double? minPrice;
  final double? maxPrice;
  final int? minYear;
  const _FilterValues(this.minPrice, this.maxPrice, this.minYear);
}

class _FiltersSheet extends StatefulWidget {
  final _FilterValues initial;
  const _FiltersSheet({required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final _min = TextEditingController(text: widget.initial.minPrice?.toStringAsFixed(0) ?? '');
  late final _max = TextEditingController(text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '');
  late final _year = TextEditingController(text: widget.initial.minYear?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _year.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GrHeadline('Filters.', size: 32),
                const SizedBox(height: 20),
                const GrSectionLabel('Price Range'),
                Row(
                  children: [
                    Expanded(
                      child: GrTextField(controller: _min, hint: 'Min Price', keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GrTextField(controller: _max, hint: 'Max Price', keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const GrSectionLabel('Min Year'),
                GrTextField(controller: _year, hint: 'e.g. 2020', keyboardType: TextInputType.number),
                const SizedBox(height: 28),
                GrPrimaryButton(
                  label: 'Apply',
                  icon: null,
                  onPressed: () => Navigator.pop(
                    context,
                    _FilterValues(_parse(_min.text), _parse(_max.text), int.tryParse(_year.text.trim())),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, const _FilterValues(null, null, null)),
                  child: const Text('RESET ALL'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
