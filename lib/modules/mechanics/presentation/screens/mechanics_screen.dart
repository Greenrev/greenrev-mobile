import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class _Expert {
  final String id;
  final String name;
  final String city;
  final String country;
  final String address;
  final double lat;
  final double lng;
  final List<String> specialization;
  final String phone;
  final String email;
  final String? image;
  final double? averageRating;
  final int reviewCount;

  _Expert.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? j['_id'] ?? '').toString(),
        name = j['name']?.toString() ?? 'Expert',
        city = _clean(j['city']),
        country = _clean(j['country']),
        address = j['address']?.toString() ?? '',
        lat = (j['lat'] as num?)?.toDouble() ?? 0,
        lng = (j['lng'] as num?)?.toDouble() ?? 0,
        specialization = (j['specialization'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        phone = j['phone']?.toString() ?? '',
        email = j['email']?.toString() ?? '',
        image = j['image'] as String?,
        averageRating = (j['averageRating'] as num?)?.toDouble(),
        reviewCount = (j['reviewCount'] as num?)?.toInt() ?? 0;

  // The API fills unknown locations with placeholders; hide those.
  static String _clean(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.startsWith('Unknown') ? '' : s;
  }

  bool get hasLocation => lat != 0 || lng != 0;
  String get place => [city, country].where((s) => s.isNotEmpty).join(', ');
}

void _pushLogin(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));

/// "Find your EXPERT." — web: /experts (list + map).
class MechanicsScreen extends StatefulWidget {
  const MechanicsScreen({super.key});

  @override
  State<MechanicsScreen> createState() => _MechanicsScreenState();
}

class _MechanicsScreenState extends State<MechanicsScreen> {
  final _mapController = MapController();
  final _search = TextEditingController();
  List<_Expert> _experts = [];
  bool _isLoading = true;
  String? _error;
  String? _expandedId;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _fetchExperts();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetchExperts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().get('/api/v1/experts', requiresAuth: false);
      final list = (response is Map ? response['experts'] : null) as List? ?? const [];
      _experts = list.whereType<Map<String, dynamic>>().map(_Expert.fromJson).toList();
    } catch (e) {
      _error = e is ApiException && e.code != 'NETWORK_ERROR'
          ? e.message
          : 'We couldn\'t load the expert network. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_Expert> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _experts;
    return _experts
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.city.toLowerCase().contains(q) ||
            e.country.toLowerCase().contains(q) ||
            e.address.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showGrSnack(context, 'Could not open that link.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final experts = _filtered;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const GrEyebrow('Global Expert Network'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const GrHeadline('Find your', muted: 'EXPERT.', mutedColor: AppTheme.accent, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Connect with our elite network of factory-certified master technicians operating in strategic locations worldwide.',
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GrTextField(
                          controller: _search,
                          hint: 'Search by name or location...',
                          icon: Icons.search,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ViewToggle(showMap: _showMap, onChanged: (v) => setState(() => _showMap = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
                  : _error != null
                      ? GrEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Network unavailable',
                          message: _error!,
                          actionLabel: 'Try Again',
                          onAction: _fetchExperts,
                        )
                      : _showMap
                          ? _buildMap(experts)
                          : _buildList(experts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_Expert> experts) {
    if (experts.isEmpty) {
      return const GrEmptyState(
        icon: Icons.person_search_outlined,
        title: 'No experts found',
        message: 'No experts found matching your criteria.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.cardBg,
      onRefresh: _fetchExperts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        itemCount: experts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final e = experts[i];
          return _ExpertCard(
            expert: e,
            expanded: _expandedId == e.id,
            onTap: () => setState(() => _expandedId = _expandedId == e.id ? null : e.id),
            onCall: e.phone.isEmpty ? null : () => _launch(Uri(scheme: 'tel', path: e.phone)),
            onDirections: !e.hasLocation
                ? null
                : () => _launch(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${e.lat},${e.lng}')),
          );
        },
      ),
    );
  }

  Widget _buildMap(List<_Expert> experts) {
    final located = experts.where((e) => e.hasLocation).toList();
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: located.isNotEmpty ? LatLng(located.first.lat, located.first.lng) : const LatLng(9.0820, 8.6753),
            initialZoom: 5.5,
            onTap: (_, _) => setState(() => _expandedId = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              userAgentPackageName: 'com.greenrev.mobile',
            ),
            MarkerLayer(
              markers: [
                for (final e in located)
                  Marker(
                    point: LatLng(e.lat, e.lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _expandedId = e.id);
                        _mapController.move(LatLng(e.lat, e.lng), 11);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _expandedId == e.id ? AppTheme.accent : Colors.black,
                          border: Border.all(color: AppTheme.accent, width: 2),
                          boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 12)],
                        ),
                        child: Icon(Icons.build, size: 18, color: _expandedId == e.id ? Colors.black : AppTheme.accent),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (located.isEmpty)
          Positioned(
            left: 20,
            right: 20,
            top: 12,
            child: GrNotice('None of these experts have shared a map location yet.', kind: GrNoticeKind.info),
          ),
        if (_expandedId != null && located.any((e) => e.id == _expandedId))
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 96,
            child: Builder(builder: (context) {
              final e = located.firstWhere((x) => x.id == _expandedId);
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24)],
                ),
                child: _ExpertCard(
                  expert: e,
                  expanded: true,
                  onTap: () {},
                  onCall: e.phone.isEmpty ? null : () => _launch(Uri(scheme: 'tel', path: e.phone)),
                  onDirections: () =>
                      _launch(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${e.lat},${e.lng}')),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.showMap, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(bool map, IconData icon) => GestureDetector(
          onTap: () => onChanged(map),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showMap == map ? Colors.white : Colors.transparent,
            ),
            child: Icon(icon, size: 17, color: showMap == map ? Colors.black : Colors.white60),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
      child: Row(children: [seg(false, Icons.view_list_outlined), seg(true, Icons.map_outlined)]),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  final _Expert expert;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;

  const _ExpertCard({
    required this.expert,
    required this.expanded,
    required this.onTap,
    this.onCall,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final initials = expert.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    return GrCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 22,
      borderColor: expanded ? AppTheme.accent.withValues(alpha: 0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: expert.image != null && expert.image!.isNotEmpty
                    ? Image(image: safeImageProvider(expert.image!), fit: BoxFit.cover)
                    : Center(
                        child: Text(initials.isEmpty ? 'EX' : initials,
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expert.name, style: const TextStyle(color: Colors.white, fontSize: 17)),
                    const SizedBox(height: 4),
                    if (expert.averageRating != null && expert.reviewCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${expert.averageRating!.toStringAsFixed(1)} (${expert.reviewCount})',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      )
                    else
                      const Text('No ratings yet', style: TextStyle(color: Colors.white30, fontSize: 10)),
                    if (expert.place.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, color: Colors.white38, size: 13),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(expert.place, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(expanded ? Icons.expand_less : Icons.chevron_right, color: Colors.white30, size: 20),
            ],
          ),
          if (expert.specialization.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in expert.specialization.take(expanded ? 6 : 2)) GrPill(s, color: Colors.white60)],
            ),
          ],
          if (expanded) ...[
            if (expert.address.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(expert.address, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.45)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCall != null) _ActionChip(icon: Icons.phone_outlined, label: 'Call', onTap: onCall!),
                if (onDirections != null)
                  _ActionChip(icon: Icons.navigation_outlined, label: 'Directions', onTap: onDirections!),
                _ActionChip(
                  icon: Icons.mail_outline,
                  label: 'Message',
                  onTap: () => _ExpertMessageSheet.show(context, expert),
                ),
                _ActionChip(
                  icon: Icons.star_outline_rounded,
                  label: 'Reviews',
                  onTap: () => _ExpertReviewsSheet.show(context, expert),
                ),
                _ActionChip(
                  icon: Icons.event_outlined,
                  label: 'Book Service',
                  accent: true,
                  onTap: () => _BookingSheet.show(context, expert),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppTheme.accent : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent ? Colors.black : Colors.white),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: accent ? Colors.black : Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sheet(BuildContext context, List<Widget> children) {
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
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showSheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );

/// Message an expert — POST /api/v1/experts/:id/messages. Replies appear in My Messages.
class _ExpertMessageSheet extends StatefulWidget {
  final _Expert expert;
  const _ExpertMessageSheet({required this.expert});

  static void show(BuildContext context, _Expert expert) => _showSheet(context, _ExpertMessageSheet(expert: expert));

  @override
  State<_ExpertMessageSheet> createState() => _ExpertMessageSheetState();
}

class _ExpertMessageSheetState extends State<_ExpertMessageSheet> {
  final _message = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Please write a message.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/experts/${widget.expert.id}/messages', body: {'message': _message.text.trim()});
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (_sent) {
      return _sheet(context, [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: AppTheme.accent, size: 28),
          ),
        ),
        const SizedBox(height: 16),
        const GrHeadline('Message Sent!', size: 24, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${widget.expert.name} has been notified and will get back to you soon.',
            textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
        const SizedBox(height: 24),
        GrSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ]);
    }
    return _sheet(context, [
      const GrEyebrow('Message'),
      const SizedBox(height: 10),
      GrHeadline(widget.expert.name, size: 26),
      const SizedBox(height: 18),
      if (!loggedIn) ...[
        const Text('Please log in to send a message.', style: TextStyle(color: AppTheme.textSubtle, fontSize: 14)),
        const SizedBox(height: 18),
        GrPrimaryButton(
          label: 'Sign in',
          onPressed: () {
            Navigator.pop(context);
            _pushLogin(context);
          },
        ),
      ] else ...[
        GrTextArea(controller: _message, hint: 'Type your message here...'),
        const SizedBox(height: 16),
        if (_error != null) ...[
          GrNotice(_error!),
          const SizedBox(height: 14),
        ],
        GrPrimaryButton(
          label: 'Send Message',
          loadingLabel: 'Sending…',
          loading: _submitting,
          icon: Icons.send_rounded,
          onPressed: _send,
        ),
      ],
    ]);
  }
}

/// Expert reviews — GET/POST /api/v1/experts/:id/reviews.
class _ExpertReviewsSheet extends StatefulWidget {
  final _Expert expert;
  const _ExpertReviewsSheet({required this.expert});

  static void show(BuildContext context, _Expert expert) => _showSheet(context, _ExpertReviewsSheet(expert: expert));

  @override
  State<_ExpertReviewsSheet> createState() => _ExpertReviewsSheetState();
}

class _ExpertReviewsSheetState extends State<_ExpertReviewsSheet> {
  final _comment = TextEditingController();
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  int _rating = 0;
  bool _submitting = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient().get('/api/v1/experts/${widget.expert.id}/reviews', requiresAuth: false);
      final list = (res is Map ? res['reviews'] : null) as List? ?? const [];
      _reviews = list.whereType<Map<String, dynamic>>().map(ReviewModel.fromJson).toList();
    } catch (_) {
      // Non-critical.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please choose a star rating.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/experts/${widget.expert.id}/reviews', body: {
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      if (mounted) setState(() => _saved = true);
      _fetch();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    return _sheet(context, [
      const GrEyebrow('Reviews'),
      const SizedBox(height: 10),
      GrHeadline(widget.expert.name, size: 26),
      const SizedBox(height: 18),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
        )
      else if (_reviews.isEmpty)
        const Text('No reviews yet. Be the first!', style: TextStyle(color: AppTheme.textSubtle, fontSize: 14))
      else
        for (final r in _reviews)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.hairline))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.userName, style: const TextStyle(color: Colors.white, fontSize: 14))),
                    for (var i = 1; i <= 5; i++)
                      Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 13, color: i <= r.rating ? AppTheme.accent : Colors.white24),
                  ],
                ),
                if (r.comment?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(r.comment!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
                ],
              ],
            ),
          ),
      const SizedBox(height: 22),
      GrSectionLabel(_saved ? 'Your review was saved' : 'Leave a Review'),
      const SizedBox(height: 12),
      if (!loggedIn)
        GrSecondaryButton(
          label: 'Sign in',
          onPressed: () {
            Navigator.pop(context);
            _pushLogin(context);
          },
        )
      else if (_saved)
        GrSecondaryButton(label: 'Edit', onPressed: () => setState(() => _saved = false))
      else ...[
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 30, color: i <= _rating ? AppTheme.accent : Colors.white24),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GrTextArea(controller: _comment, hint: 'Share your experience (optional)...', minLines: 3),
        const SizedBox(height: 14),
        if (_error != null) ...[
          GrNotice(_error!),
          const SizedBox(height: 12),
        ],
        GrPrimaryButton(label: 'Submit Review', loadingLabel: 'Saving…', loading: _submitting, icon: null, onPressed: _submit),
      ],
    ]);
  }
}

/// Book a service — POST /api/v1/bookings with the fields the server requires.
class _BookingSheet extends StatefulWidget {
  final _Expert expert;
  const _BookingSheet({required this.expert});

  static void show(BuildContext context, _Expert expert) {
    if (!context.read<AuthProvider>().isLoggedIn) {
      _pushLogin(context);
      return;
    }
    _showSheet(context, _BookingSheet(expert: expert));
  }

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _issue = TextEditingController();
  DateTime? _date;
  bool _submitting = false;
  bool _booked = false;
  String? _error;

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _issue.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.accent, onPrimary: Colors.black, surface: AppTheme.cardBg),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      setState(() => _error = 'Please choose a preferred date.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/bookings', body: {
        'mechanicId': widget.expert.id,
        'vehicleDetails': {
          'make': _make.text.trim(),
          'model': _model.text.trim(),
          'year': _year.text.trim(),
        },
        'issueDescription': _issue.text.trim(),
        'requestedDate': _date!.toIso8601String(),
      });
      if (mounted) setState(() => _booked = true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Booking failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    if (_booked) {
      return _sheet(context, [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.event_available, color: AppTheme.accent, size: 28),
          ),
        ),
        const SizedBox(height: 16),
        const GrHeadline('Request Sent!', size: 24, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${widget.expert.name} has been notified and will confirm your appointment.',
            textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
        const SizedBox(height: 24),
        GrSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ]);
    }
    return _sheet(context, [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GrEyebrow('Book Service'),
            const SizedBox(height: 10),
            GrHeadline(widget.expert.name, size: 26),
            const SizedBox(height: 18),
            const GrSectionLabel('Vehicle'),
            Row(
              children: [
                Expanded(child: GrTextField(controller: _make, hint: 'Make', validator: _required)),
                const SizedBox(width: 12),
                Expanded(child: GrTextField(controller: _model, hint: 'Model', validator: _required)),
              ],
            ),
            GrTextField(controller: _year, hint: 'Year', keyboardType: TextInputType.number, validator: _required),
            const SizedBox(height: 18),
            const GrSectionLabel('Preferred Date'),
            const SizedBox(height: 8),
            GrSecondaryButton(
              label: _date == null ? 'Choose a date' : grDate(_date),
              icon: Icons.calendar_today_outlined,
              onPressed: _pickDate,
            ),
            const SizedBox(height: 18),
            const GrSectionLabel('What needs attention?'),
            const SizedBox(height: 8),
            GrTextArea(controller: _issue, hint: 'Describe the issue or service you need…', minLines: 3, validator: _required),
            const SizedBox(height: 16),
            if (_error != null) ...[
              GrNotice(_error!),
              const SizedBox(height: 14),
            ],
            GrPrimaryButton(label: 'Send Booking Request', loadingLabel: 'Sending…', loading: _submitting, onPressed: _submit),
          ],
        ),
      ),
    ]);
  }
}
