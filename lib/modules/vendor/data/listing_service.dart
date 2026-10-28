import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import 'listing_options.dart' show ColorOption;
import 'listing_options.dart' as defaults;

/// Fields the AI suggested. Everything is optional — it only returns what it saw or heard.
class ExtractedListing {
  final Map<String, String> fields;
  final List<MapEntry<String, String>> extraSpecs;
  const ExtractedListing(this.fields, this.extraSpecs);

  factory ExtractedListing.fromJson(Map<String, dynamic> json) {
    final fields = <String, String>{};
    json.forEach((k, v) {
      if (k == 'extraSpecs' || v == null) return;
      final s = v.toString().trim();
      if (s.isNotEmpty) fields[k] = s;
    });
    final specs = <MapEntry<String, String>>[
      for (final s in (json['extraSpecs'] as List? ?? const []))
        if (s is Map && s['key'] != null && s['value'] != null)
          MapEntry(s['key'].toString(), s['value'].toString()),
    ];
    return ExtractedListing(fields, specs);
  }
}

class ExtractionResult {
  final ExtractedListing listing;
  final String? transcript;
  final List<String> warnings;
  const ExtractionResult(this.listing, this.transcript, this.warnings);

  factory ExtractionResult.fromJson(Map<String, dynamic> json) =>
      ExtractionResult(
        ExtractedListing.fromJson(
          (json['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        (json['transcript'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['transcript'] as String,
        [for (final w in (json['warnings'] as List? ?? const [])) w.toString()],
      );
}

class ListingService {
  final ApiClient _api;
  ListingService([ApiClient? api]) : _api = api ?? ApiClient();

  static String _mimeFor(XFile f) {
    final m = f.mimeType;
    if (m != null && m.startsWith('image/')) return m;
    final name = f.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _extFor(String mime) => switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  static Future<List<UploadFile>> _imageParts(
    String field,
    List<XFile> photos,
  ) async => [
    for (var i = 0; i < photos.length; i++)
      await photos[i].readAsBytes().then((bytes) {
        final mime = _mimeFor(photos[i]);
        return UploadFile(
          field: field,
          bytes: bytes,
          filename: 'photo-${i + 1}.${_extFor(mime)}',
          contentType: mime,
        );
      }),
  ];

  /// Photos and/or a WAV voice note in, suggested listing fields out.
  Future<ExtractionResult> extract({
    required String category,
    List<XFile> photos = const [],
    Uint8List? wav,
  }) async {
    final files = await _imageParts('images', photos);
    if (wav != null) {
      files.add(
        UploadFile(
          field: 'audio',
          bytes: wav,
          filename: 'voice-note.wav',
          contentType: 'audio/wav',
        ),
      );
    }
    final data = await _api.postMultipart(
      '/api/v1/ai/listing-extract',
      fields: {'category': category},
      files: files,
    );
    return ExtractionResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<String>> uploadPhotos(List<XFile> photos) async {
    final data = await _api.postMultipart(
      '/api/v1/upload',
      files: await _imageParts('files', photos),
    );
    return [for (final u in (data as Map)['urls'] as List) u.toString()];
  }

  Future<void> createProduct(Map<String, dynamic> payload) =>
      _api.post('/api/v1/products', body: payload);
}

// ---------------------------------------------------------------------------
// Admin-managed dropdown options
// ---------------------------------------------------------------------------

/// Same shape as GET /api/v1/listing-options and the website's listingOptions.json.
class ListingOptionsData {
  final List<String> vehicleMakes;
  final Map<String, List<String>> vehicleModels;
  final List<String> transmissions;
  final List<String> conditions;
  final List<ColorOption> colors;
  final Map<String, List<String>> vehicleSpecValues;
  final List<String> partBrands;
  final List<String> partNames;
  final Map<String, List<String>> partSpecValues;

  const ListingOptionsData({
    required this.vehicleMakes,
    required this.vehicleModels,
    required this.transmissions,
    required this.conditions,
    required this.colors,
    required this.vehicleSpecValues,
    required this.partBrands,
    required this.partNames,
    required this.partSpecValues,
  });

  /// The list shipped with the app — used offline and until the server answers.
  static const bundled = ListingOptionsData(
    vehicleMakes: defaults.vehicleMakes,
    vehicleModels: defaults.vehicleModels,
    transmissions: defaults.transmissions,
    conditions: defaults.conditions,
    colors: defaults.colorOptions,
    vehicleSpecValues: defaults.vehicleSpecValues,
    partBrands: defaults.partBrands,
    partNames: defaults.partNames,
    partSpecValues: defaults.partSpecValues,
  );

  static List<String> _list(dynamic v) => [
    for (final x in (v as List? ?? const [])) x.toString(),
  ];
  static Map<String, List<String>> _map(dynamic v) => {
    for (final e in ((v as Map?) ?? const {}).entries)
      e.key.toString(): _list(e.value),
  };

  /// Throws if [json] isn't a usable list, so a bad response never replaces a good one.
  factory ListingOptionsData.fromJson(Map<String, dynamic> json) {
    final makes = _list(json['vehicleMakes']);
    if (makes.isEmpty) throw const FormatException('No vehicle makes');
    return ListingOptionsData(
      vehicleMakes: makes,
      vehicleModels: _map(json['vehicleModels']),
      transmissions: _list(json['transmissions']),
      conditions: _list(json['conditions']),
      colors: [
        for (final c in (json['colors'] as List? ?? const []))
          if (c is Map && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch('${c['hex']}'))
            ColorOption(
              '${c['name']}',
              int.parse('FF${'${c['hex']}'.substring(1)}', radix: 16),
            ),
      ],
      vehicleSpecValues: _map(json['vehicleSpecValues']),
      partBrands: _list(json['partBrands']),
      partNames: _list(json['partNames']),
      partSpecValues: _map(json['partSpecValues']),
    );
  }
}

/// The options the listing form suggests from: the bundled list, then the last copy
/// saved on the device, then the server's current list.
class ListingCatalog {
  static const _prefsKey = 'listing_options_v1';
  static ListingOptionsData current = ListingOptionsData.bundled;

  /// Returns true when [current] changed.
  static Future<bool> refresh([ApiClient? api]) async {
    var changed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && identical(current, ListingOptionsData.bundled)) {
        current = ListingOptionsData.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
        changed = true;
      }
      final data = await (api ?? ApiClient()).get(
        '/api/v1/listing-options',
        requiresAuth: false,
      );
      current = ListingOptionsData.fromJson(
        (data as Map).cast<String, dynamic>(),
      );
      await prefs.setString(_prefsKey, jsonEncode(data));
      return true;
    } catch (_) {
      // Offline or unexpected response: keep whatever we have.
      return changed;
    }
  }
}

// ---------------------------------------------------------------------------
// Suggestions for the autocomplete fields
// ---------------------------------------------------------------------------

/// Ranks prefix and word-prefix matches above plain substring matches.
List<String> rankOptions(
  Iterable<String> options,
  String query, {
  int limit = 40,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return options.take(limit).toList();
  final scored = <(String, int)>[];
  for (final o in options) {
    final v = o.toLowerCase();
    if (v == q) continue;
    final score = v.startsWith(q)
        ? 0
        : v.split(RegExp(r'[\s\-/]+')).any((w) => w.startsWith(q))
        ? 1
        : v.contains(q)
        ? 2
        : -1;
    if (score >= 0) scored.add((o, score));
  }
  scored.sort((a, b) => a.$2.compareTo(b.$2));
  return scored.take(limit).map((e) => e.$1).toList();
}

List<String> nameOptionsFor(String category, String make, String year) {
  final o = ListingCatalog.current;
  if (category == 'part') return o.partNames;
  final key = o.vehicleModels.keys
      .where((k) => k.toLowerCase() == make.trim().toLowerCase())
      .firstOrNull;
  if (key == null) return const [];
  final prefix = RegExp(r'^\d{4}$').hasMatch(year.trim())
      ? '${year.trim()} '
      : '';
  return [for (final m in o.vehicleModels[key]!) '$prefix$key $m'];
}

List<String> specKeysFor(String category) {
  final o = ListingCatalog.current;
  return (category == 'vehicle' ? o.vehicleSpecValues : o.partSpecValues).keys
      .toList();
}

List<String> specValuesFor(String category, String key) {
  final o = ListingCatalog.current;
  final table = category == 'vehicle' ? o.vehicleSpecValues : o.partSpecValues;
  final match = table.keys
      .where((k) => k.toLowerCase() == key.trim().toLowerCase())
      .firstOrNull;
  if (match == 'Compatibility') return o.vehicleMakes;
  return match == null ? const [] : table[match]!;
}

ColorOption? colorNamed(String name) => ListingCatalog.current.colors
    .where((c) => c.name.toLowerCase() == name.trim().toLowerCase())
    .firstOrNull;

final yearOptions = [
  for (var y = DateTime.now().year + 1; y >= 1980; y--) '$y',
];
