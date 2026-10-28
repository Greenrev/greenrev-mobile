import 'package:geolocator/geolocator.dart';

/// A device position fix.
class DeviceFix {
  final double lat;
  final double lng;

  /// Metres, 68% confidence.
  final double accuracy;
  const DeviceFix(this.lat, this.lng, this.accuracy);
}

/// Why we couldn't get a position, phrased for the user.
class LocationFailure implements Exception {
  final String message;

  /// The user has to change a system setting (location off, or permission denied for good).
  final bool needsSettings;
  const LocationFailure(this.message, {this.needsSettings = false});
}

/// Asks for permission if needed and returns the current position.
/// Every failure surfaces as a [LocationFailure] with a user-facing message.
Future<DeviceFix> currentDeviceFix() async {
  try {
    return await _fix();
  } on LocationFailure {
    rethrow;
  } catch (_) {
    throw const LocationFailure("We couldn't use your phone's location. Search for your address instead.");
  }
}

Future<DeviceFix> _fix() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationFailure('Location is turned off. Turn it on in your phone settings.', needsSettings: true);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) {
    throw const LocationFailure('GreenRev needs location access to do that.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationFailure('Location access is off for GreenRev. Allow it in Settings.', needsSettings: true);
  }
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return DeviceFix(p.latitude, p.longitude, p.accuracy);
  } catch (_) {
    throw const LocationFailure("We couldn't get a GPS fix. Try again near a window or outdoors.");
  }
}

Future<void> openLocationSettings() => Geolocator.openAppSettings();

/// Great-circle distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) =>
    Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;

String formatKm(double km) =>
    km < 1 ? '< 1 km' : km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
