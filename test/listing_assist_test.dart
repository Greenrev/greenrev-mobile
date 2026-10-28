import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenrev_mobile/core/network/api_client.dart';
import 'package:greenrev_mobile/core/network/token_store.dart';
import 'package:greenrev_mobile/modules/vendor/data/listing_service.dart';
import 'package:greenrev_mobile/modules/vendor/data/voice_recorder.dart';

http.Response _json(int status, Object body, {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

void main() {
  group('wavFromPcm16', () {
    test('writes a 44-byte mono 16 kHz PCM header in front of the samples', () {
      final pcm = Uint8List.fromList(List.generate(320, (i) => i % 256));
      final wav = wavFromPcm16(pcm, 16000);
      final h = ByteData.sublistView(wav);

      expect(wav.length, 44 + 320);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(h.getUint32(4, Endian.little), 36 + 320);
      expect(ascii.decode(wav.sublist(8, 16)), 'WAVEfmt ');
      expect(h.getUint16(20, Endian.little), 1); // PCM
      expect(h.getUint16(22, Endian.little), 1); // mono
      expect(h.getUint32(24, Endian.little), 16000);
      expect(h.getUint16(34, Endian.little), 16); // bits per sample
      expect(ascii.decode(wav.sublist(36, 40)), 'data');
      expect(h.getUint32(40, Endian.little), 320);
      expect(wav.sublist(44), pcm);
    });
  });

  group('suggestions', () {
    test('rank prefix, then word-prefix, then substring matches', () {
      expect(rankOptions(['Aston Martin', 'Tesla', 'Toyota', 'Land Cruiser'], 't'), ['Tesla', 'Toyota', 'Aston Martin']);
      expect(rankOptions(['Toyota', 'Land Cruiser'], 'cru'), ['Land Cruiser']);
      expect(rankOptions(['Toyota'], 'toyota'), isEmpty, reason: 'an exact match needs no suggestion');
    });

    test('vehicle names come from the chosen make, prefixed with the year', () {
      expect(nameOptionsFor('vehicle', 'toyota', '2019'), contains('2019 Toyota Camry'));
      expect(nameOptionsFor('vehicle', 'Toyota', ''), contains('Toyota Camry'));
      expect(nameOptionsFor('vehicle', 'Nonexistent', '2019'), isEmpty);
      expect(nameOptionsFor('part', '', ''), contains('Brake Pads'));
    });

    test('spec values follow the spec key', () {
      expect(specValuesFor('vehicle', 'fuel type'), contains('Petrol'));
      expect(specValuesFor('part', 'Compatibility'), contains('Toyota'));
      expect(specValuesFor('vehicle', 'Something else'), isEmpty);
    });
  });

  test('ExtractionResult keeps only non-empty fields and well-formed specs', () {
    final r = ExtractionResult.fromJson({
      'transcript': '  ',
      'warnings': ['Check the VIN'],
      'fields': {
        'make': 'Toyota',
        'year': 2019,
        'price': '',
        'extraSpecs': [
          {'key': 'Fuel Type', 'value': 'Petrol'},
          {'key': 'Broken'},
        ],
      },
    });
    expect(r.listing.fields, {'make': 'Toyota', 'year': '2019'});
    expect(r.listing.extraSpecs.map((e) => '${e.key}=${e.value}'), ['Fuel Type=Petrol']);
    expect(r.transcript, isNull);
    expect(r.warnings, ['Check the VIN']);
  });

  test('postMultipart refreshes an expired session and resends the files', () async {
    var access = 'only-valid-after-refresh';
    final seen = <String>[];
    final api = ApiClient()
      ..configureForTesting(
        client: MockClient((req) async {
          if (req.url.path == '/api/v1/auth/refresh') {
            access = 'new';
            return _json(200, {'success': true, 'data': {'accessToken': 'new'}},
                headers: {'set-cookie': 'refresh_token=r2; Path=/; HttpOnly'});
          }
          seen.add('${req.headers['Authorization']} ${req.headers['content-type']?.split(';').first}');
          if (req.headers['Authorization'] != 'Bearer $access') {
            return _json(401, {'success': false, 'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'}});
          }
          expect(utf8.decode(req.bodyBytes, allowMalformed: true), contains('name="audio"; filename="voice-note.wav"'));
          return _json(200, {'success': true, 'data': {'fields': {'make': 'Toyota'}, 'warnings': []}});
        }),
        store: InMemoryTokenStore(),
      )
      ..setTokens(accessToken: 'old', refreshToken: 'r1');

    final res = await ListingService(api).extract(category: 'vehicle', wav: wavFromPcm16(Uint8List(32), 16000));

    expect(res.listing.fields['make'], 'Toyota');
    expect(seen, ['Bearer old multipart/form-data', 'Bearer new multipart/form-data']);
  });

  group('ListingCatalog', () {
    final serverList = {
      'vehicleMakes': ['Toyota', 'Zeekr'],
      'vehicleModels': {'Zeekr': ['001', '7X']},
      'transmissions': ['Automatic'],
      'conditions': ['Brand New'],
      'colors': [{'name': 'Aurora Green', 'hex': '#1F7A5A'}, {'name': 'Broken', 'hex': 'green'}],
      'vehicleSpecValues': {'Fuel Type': ['Electric']},
      'partBrands': ['Bosch'],
      'partNames': ['Brake Pads'],
      'partSpecValues': {'Part Number': []},
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ListingCatalog.current = ListingOptionsData.bundled;
    });

    test('uses the server list and saves it for offline use', () async {
      final api = ApiClient()
        ..configureForTesting(
          client: MockClient((_) async => _json(200, {'success': true, 'data': serverList})),
          store: InMemoryTokenStore(),
        );
      expect(await ListingCatalog.refresh(api), isTrue);
      expect(nameOptionsFor('vehicle', 'zeekr', '2025'), ['2025 Zeekr 001', '2025 Zeekr 7X']);
      expect(colorNamed('aurora green')?.hex, 0xFF1F7A5A);
      expect(ListingCatalog.current.colors, hasLength(1), reason: 'invalid hex is dropped');

      // Next launch, offline: the saved copy is used instead of the bundled list.
      ListingCatalog.current = ListingOptionsData.bundled;
      final offline = ApiClient()
        ..configureForTesting(
          client: MockClient((_) async => throw Exception('offline')),
          store: InMemoryTokenStore(),
        );
      expect(await ListingCatalog.refresh(offline), isTrue);
      expect(ListingCatalog.current.vehicleMakes, contains('Zeekr'));
    });

    test('keeps the bundled list when the server sends something unusable', () async {
      final api = ApiClient()
        ..configureForTesting(
          client: MockClient((_) async => _json(200, {'success': true, 'data': {'vehicleMakes': []}})),
          store: InMemoryTokenStore(),
        );
      expect(await ListingCatalog.refresh(api), isFalse);
      expect(identical(ListingCatalog.current, ListingOptionsData.bundled), isTrue);
      expect(nameOptionsFor('vehicle', 'Toyota', ''), contains('Toyota Camry'));
    });
  });
}
