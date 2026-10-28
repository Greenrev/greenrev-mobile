import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/widgets/gr_map.dart';
import '../../../../core/widgets/gr_ui.dart';

const _ease = Cubic(0.16, 1, 0.3, 1);
const _nigeria = LatLng(9.082, 8.6753);
const _radii = [5, 10, 25, 50, 100, 0];

/// A geocoded place from GET /geo/search or /geo/reverse.
class _Place {
  final String label;
  final String address;
  final String city;
  final String state;
  final String country;
  final double lat;
  final double lng;

  _Place.fromJson(Map<String, dynamic> j)
      : label = '${j['label'] ?? ''}',
        address = '${j['address'] ?? ''}',
        city = '${j['city'] ?? ''}',
        state = '${j['state'] ?? ''}',
        country = '${j['country'] ?? ''}',
        lat = (j['lat'] as num).toDouble(),
        lng = (j['lng'] as num).toDouble();
}

/// Experts pin their workshop for the public experts map — same rules as the
/// website's /mechanic/location.
class ExpertLocationScreen extends StatefulWidget {
  const ExpertLocationScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const ExpertLocationScreen());

  @override
  State<ExpertLocationScreen> createState() => _ExpertLocationScreenState();
}

class _ExpertLocationScreenState extends State<ExpertLocationScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  final _map = MapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController(text: 'Nigeria');
  late final AnimationController _lift;

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _lookingUp = false;
  bool _mapReady = false;
  LatLng? _pin; // null until the expert places it
  LatLng? _savedPin;
  int _radiusKm = 25;
  String _privacy = 'exact';
  String? _note;
  List<_Place> _results = [];
  Timer? _searchDebounce;
  Timer? _reverseDebounce;
  int _reverseSeq = 0;

  @override
  void initState() {
    super.initState();
    _lift = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _lift.dispose();
    _map.dispose();
    for (final c in [_search, _address, _city, _state, _country]) {
      c.dispose();
    }
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- load / save

  Future<void> _load() async {
    try {
      final data = await _api.get('/api/v1/mechanic/profile');
      final p = (data as Map)['profile'] as Map? ?? const {};
      final lat = (p['lat'] as num?)?.toDouble() ?? 0;
      final lng = (p['lng'] as num?)?.toDouble() ?? 0;
      _address.text = '${p['address'] ?? ''}';
      _city.text = '${p['city'] ?? ''}';
      _state.text = '${p['state'] ?? ''}';
      if ('${p['country'] ?? ''}'.isNotEmpty) _country.text = '${p['country']}';
      _radiusKm = (p['serviceRadiusKm'] as num?)?.toInt() ?? 25;
      _privacy = p['locationPrivacy'] == 'approximate' ? 'approximate' : 'exact';
      if (lat != 0 || lng != 0) _pin = _savedPin = LatLng(lat, lng);
    } on ApiException catch (e) {
      _note = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // First time here: offer GPS straight away — it's the quickest way to get a pin down.
    if (mounted && _savedPin == null) WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null) {
      setState(() => _note = 'Move the map so the pin sits on your workshop, then save.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final data = await _api.patch('/api/v1/mechanic/location', body: {
        'lat': pin.latitude,
        'lng': pin.longitude,
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': _country.text.trim(),
        'serviceRadiusKm': _radiusKm,
        'locationPrivacy': _privacy,
      });
      final wasVisible = _savedPin != null;
      final loc = (data as Map)['location'] as Map;
      setState(() {
        _savedPin = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        _note = null;
      });
      HapticFeedback.mediumImpact();
      if (mounted) showGrSnack(context, wasVisible ? 'Location updated' : "You're now on the experts map");
    } on ApiException catch (e) {
      if (mounted) showGrSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- pin & address

  void _moveTo(LatLng p, {double zoom = 17}) {
    if (_mapReady) _map.move(p, zoom);
    setState(() => _pin = p);
  }

  /// The pin is the source of truth: when it settles, fill the address from there.
  void _scheduleReverse(LatLng p) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 500), () async {
      final seq = ++_reverseSeq;
      setState(() => _lookingUp = true);
      try {
        final data = await _api.get('/api/v1/geo/reverse?lat=${p.latitude}&lng=${p.longitude}');
        final place = (data as Map)['place'];
        if (seq != _reverseSeq || !mounted || place is! Map) return;
        final pl = _Place.fromJson(place.cast<String, dynamic>());
        setState(() {
          if (pl.address.isNotEmpty) _address.text = pl.address;
          if (pl.city.isNotEmpty) _city.text = pl.city;
          if (pl.state.isNotEmpty) _state.text = pl.state;
          if (pl.country.isNotEmpty) _country.text = pl.country;
        });
      } on ApiException {
        // Lookup is a convenience; the pin alone is enough to save.
      } finally {
        if (seq == _reverseSeq && mounted) setState(() => _lookingUp = false);
      }
    });
  }

  void _onMapEvent(MapEvent e) {
    if (e is MapEventMoveStart && e.source != MapEventSource.mapController) {
      _lift.forward();
    } else if (e is MapEventMove) {
      setState(() => _pin = e.camera.center);
    } else if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd) {
      _lift.reverse();
      final c = e.camera.center;
      setState(() => _pin = c);
      _scheduleReverse(c);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _note = null;
    });
    try {
      final fix = await currentDeviceFix();
      final p = LatLng(fix.lat, fix.lng);
      _moveTo(p);
      _scheduleReverse(p);
      HapticFeedback.selectionClick();
      setState(() => _note = fix.accuracy > 150
          ? 'Your phone placed you within about ${fix.accuracy.round()} m. Drag the map so the pin is on your workshop.'
          : 'Found you. Nudge the map if the pin isn\'t quite on your workshop.');
    } on LocationFailure catch (f) {
      if (!mounted) return;
      setState(() => _note = f.message);
      if (f.needsSettings) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(f.message),
          action: SnackBarAction(label: 'SETTINGS', onPressed: openLocationSettings),
        ));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final data = await _api.get('/api/v1/geo/search?q=${Uri.encodeQueryComponent(q.trim())}');
        final list = ((data as Map)['places'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => _Place.fromJson(m.cast<String, dynamic>()))
            .toList();
        if (mounted && _search.text == q) setState(() => _results = list);
      } on ApiException catch (e) {
        if (mounted) setState(() => _note = e.message);
      }
    });
  }

  void _pickResult(_Place p) {
    _searchFocus.unfocus();
    _search.text = p.label;
    setState(() {
      _results = [];
      _address.text = p.address;
      if (p.city.isNotEmpty) _city.text = p.city;
      if (p.state.isNotEmpty) _state.text = p.state;
      if (p.country.isNotEmpty) _country.text = p.country;
      _note = 'Check the pin sits on your workshop entrance — drag the map if not.';
    });
    _moveTo(LatLng(p.lat, p.lng));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final visible = _savedPin != null;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
          : Column(
              children: [
                Expanded(flex: 11, child: _mapArea()),
                Expanded(flex: 10, child: _formArea(visible)),
              ],
            ),
    );
  }

  Widget _mapArea() {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pin ?? _nigeria,
            initialZoom: _pin != null ? 16 : 6,
            // Dark while tiles load, instead of flashing light grey.
            backgroundColor: const Color(0xFF1B1D1D),
            onMapReady: () => _mapReady = true,
            onMapEvent: _onMapEvent,
            onTap: (_, p) {
              _moveTo(p, zoom: _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
              _scheduleReverse(p);
            },
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            darkOsmTileLayer(),
            if (_pin != null && _radiusKm > 0)
              CircleLayer(circles: [
                CircleMarker(
                  point: _pin!,
                  radius: _radiusKm * 1000,
                  useRadiusInMeter: true,
                  color: AppTheme.accent.withValues(alpha: 0.07),
                  borderColor: AppTheme.accent.withValues(alpha: 0.4),
                  borderStrokeWidth: 1,
                ),
              ]),
            osmAttribution(),
          ],
        ),

        // Fixed centre pin: the map moves underneath it. Lifts while dragging.
        if (_pin != null)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _lift,
                builder: (_, _) {
                  final t = Curves.easeOut.transform(_lift.value);
                  return Transform.translate(
                    offset: Offset(0, -24 - 10 * t),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 48, color: AppTheme.accent, shadows: [
                          Shadow(color: Colors.black87, blurRadius: 8),
                        ]),
                        Container(
                          width: 8 - 3 * t,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6 - 0.3 * t),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        else
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                child: const Text('Tap the map where your workshop is', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
          ),

        // Back + search
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoundButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xF20C0D0D),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _searchFocus.hasFocus ? AppTheme.accent : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search, size: 18, color: Colors.white38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              focusNode: _searchFocus,
                              onChanged: _onSearchChanged,
                              onTap: () => setState(() {}),
                              textInputAction: TextInputAction.search,
                              cursorColor: AppTheme.accent,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'Search your workshop or street',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                              ),
                            ),
                          ),
                          if (_search.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                              onPressed: () {
                                _search.clear();
                                setState(() => _results = []);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: _ease,
                child: _results.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        margin: const EdgeInsets.only(top: 8, left: 58),
                        decoration: BoxDecoration(
                          color: const Color(0xF20C0D0D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            for (final r in _results)
                              InkWell(
                                onTap: () => _pickResult(r),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.place_outlined, size: 16, color: AppTheme.accent),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(r.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Use my location
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: _locating ? null : _useMyLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.35), blurRadius: 24)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _locating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.my_location, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(_locating ? 'LOCATING…' : 'USE MY LOCATION',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.6)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _formArea(bool visible) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.of(context).padding.bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              const Expanded(child: GrHeadline('Your', muted: 'workshop', trailing: '.', mutedColor: AppTheme.accent, size: 28)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (visible ? AppTheme.accent : AppTheme.goldAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: (visible ? AppTheme.accent : AppTheme.goldAccent).withValues(alpha: 0.35)),
                ),
                child: Text(
                  visible ? 'ON THE MAP' : 'NOT ON THE MAP',
                  style: TextStyle(
                    color: visible ? AppTheme.accent : AppTheme.goldAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _note == null
                ? const SizedBox(width: double.infinity, height: 14)
                : Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: GrNotice(_note!, kind: GrNoticeKind.info),
                  ),
          ),
          Row(
            children: [
              const Expanded(child: GrSectionLabel('Address')),
              if (_lookingUp)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 10),
          _field(_address, 'Street, e.g. 12 Admiralty Way'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_city, 'City')),
              const SizedBox(width: 10),
              Expanded(child: _field(_state, 'State')),
            ],
          ),
          const SizedBox(height: 10),
          _field(_country, 'Country'),
          const SizedBox(height: 24),
          const GrSectionLabel('How far will you travel?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _radii)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _radiusKm = r);
                    if (_pin != null && r > 0 && _mapReady) {
                      // Zoom out enough to show the whole service area.
                      _map.fitCamera(CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          const Distance().offset(_pin!, r * 1000, 0),
                          const Distance().offset(_pin!, r * 1000, 180),
                        ]),
                        padding: const EdgeInsets.all(40),
                      ));
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: _ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _radiusKm == r ? AppTheme.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _radiusKm == r ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Text(
                      r == 0 ? 'Anywhere' : '$r km',
                      style: TextStyle(color: _radiusKm == r ? Colors.black : Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const GrSectionLabel('What customers see'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _privacyCard('exact', Icons.visibility_outlined, 'Exact location', 'Pin and street address')),
              const SizedBox(width: 10),
              Expanded(child: _privacyCard('approximate', Icons.visibility_off_outlined, 'Approximate area', 'About 1 km, no street')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Working from home? Approximate keeps your street private — customers message you for directions.',
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 24),
          GrPrimaryButton(
            label: visible ? 'Save location' : 'Put me on the map',
            loading: _saving,
            loadingLabel: 'Saving…',
            accent: !visible,
            icon: Icons.check,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint) {
    final radius = BorderRadius.circular(14);
    return TextField(
      controller: c,
      textCapitalization: TextCapitalization.words,
      cursorColor: AppTheme.accent,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppTheme.accent)),
      ),
    );
  }

  Widget _privacyCard(String id, IconData icon, String title, String body) {
    final active = _privacy == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _privacy = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: active ? AppTheme.accent : Colors.white54),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xF20C0D0D),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}
