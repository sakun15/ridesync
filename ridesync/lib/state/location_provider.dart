import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../services/location_service.dart';

/// Kept alive for the app's lifetime so the tracking stream survives screen
/// changes. If this were disposed when the trip screen closed, location
/// sharing would silently stop the moment someone checked their settings.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.stopTracking);
  return service;
});

/// Live locations of everyone in a trip.
final tripLocationsProvider =
    StreamProvider.family<List<LiveLocation>, String>((ref, tripId) {
  return ref.watch(locationServiceProvider).watchTripLocations(tripId);
});

/// Current permission state. Refreshable — the user may grant permission in
/// system settings and come back, so this needs to be re-checked rather than
/// read once at startup.
final locationPermissionProvider =
    FutureProvider<LocationPermissionState>((ref) {
  return ref.watch(locationServiceProvider).checkPermission();
});