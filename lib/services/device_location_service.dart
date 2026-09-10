import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class CapturedLocation {
  const CapturedLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<CapturedLocation> captureCurrent() async {
    if (kIsWeb) {
      final uri = Uri.base;
      final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
      if (uri.scheme != 'https' && !isLocalhost) {
        throw const LocationCaptureException(
          'Location on the web requires HTTPS or localhost.',
        );
      }
    } else if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationCaptureException(
        'Location services are turned off. Enable them and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationCaptureException(
        'Location access is blocked. Enable it in the browser or app settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationCaptureException(
        'Location permission is required to save the delivery point.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return CapturedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      throw const LocationCaptureException(
        'Location services are turned off. Enable them and try again.',
      );
    } on PermissionDeniedException {
      throw const LocationCaptureException(
        'Location permission was denied. Allow it and try again.',
      );
    } on TimeoutException {
      throw const LocationCaptureException(
        'Location took too long. Move near a window and try again.',
      );
    } catch (error) {
      throw LocationCaptureException('Could not capture location: $error');
    }
  }
}

class LocationCaptureException implements Exception {
  const LocationCaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}
