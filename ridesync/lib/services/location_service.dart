import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_model.dart';

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
}

class LocationService {
  LocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;

  Position? _lastWrittenPosition;
  DateTime? _lastWrittenAt;
  DateTime? _stationarySince;

  String? _activeTripId;
  String? _activeUid;

  // ---------------------------------------------------------------------------
  // Tuning
  // ---------------------------------------------------------------------------

  /// The knob is positional drift, not time.
  ///
  /// A 50m tolerance means the marker updates roughly every 3s at 60 km/h and
  /// every 6s at 30 km/h — geolocator's distanceFilter handles that curve for
  /// us automatically.
  ///
  /// Not lower than 50m: GPS accuracy is ±5–15m at best, so tightening further
  /// spends writes chasing error smaller than the measurement noise itself.
  static const double _driftMeters = 50;

  /// Safety net. Someone crawling in traffic still needs to prove they're
  /// alive and connected, even if they've barely moved.
  static const Duration _maxInterval = Duration(seconds: 20);

  /// Heartbeat when parked. Long, because nothing is changing.
  static const Duration _stationaryInterval = Duration(minutes: 2);

  /// Discard readings worse than this. In tunnels and urban canyons GPS
  /// reports positions that are simply wrong — writing them makes a member's
  /// marker teleport across the map.
  static const double _maxAcceptableAccuracy = 50;

  /// Below this we call it stopped. GPS reports non-zero speed while
  /// stationary because of noise.
  static const double _stoppedSpeedMps = 1.0; // ~3.6 km/h

  /// How long at near-zero speed before switching to heartbeat mode.
  static const Duration _stationaryThreshold = Duration(minutes: 2);

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<LocationPermissionState> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ---------------------------------------------------------------------------
  // Tracking
  // ---------------------------------------------------------------------------

  bool get isTracking => _positionSubscription != null;

  /// Starts writing this user's location to the trip.
  ///
  /// Safe to call repeatedly — stops any existing stream first, so switching
  /// trips can't leave two streams writing at once.
  Future<void> startTracking({
    required String tripId,
    required String uid,
  }) async {
    await stopTracking();

    _activeTripId = tripId;
    _activeUid = uid;
    _lastWrittenPosition = null;
    _lastWrittenAt = null;
    _stationarySince = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // metres — sample often, decide later whether to write
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen(_onPosition, onError: (_) {});

    // Write immediately so the member appears on the map without waiting
    // for the first movement.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _write(position);
    } catch (_) {
      // No fix yet. The stream will catch up.
    }

    _startHeartbeat();
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _activeTripId = null;
    _activeUid = null;
  }

  /// Removes this user's location document. Called on leaving a trip — their
  /// last known position shouldn't linger on everyone's map.
  Future<void> clearLocation({
    required String tripId,
    required String uid,
  }) async {
    await _locationDoc(tripId, uid).delete();
  }

  // ---------------------------------------------------------------------------
  // The write decision
  // ---------------------------------------------------------------------------

  void _onPosition(Position position) {
    if (!_shouldWrite(position)) return;
    _write(position);
  }

  bool _shouldWrite(Position position) {
    // 1. Reject junk. A 200m-accuracy fix in a tunnel would teleport this
    //    member across the map for everyone watching.
    if (position.accuracy > _maxAcceptableAccuracy) return false;

    // 2. Track how long we've been stationary.
    final isStopped = position.speed < _stoppedSpeedMps;
    if (isStopped) {
      _stationarySince ??= DateTime.now();
    } else {
      _stationarySince = null;
    }

    // 3. First fix always writes.
    final last = _lastWrittenPosition;
    final lastAt = _lastWrittenAt;
    if (last == null || lastAt == null) return true;

    final elapsed = DateTime.now().difference(lastAt);

    // 4. Parked: heartbeat only. The heartbeat timer handles those writes,
    //    so nothing to do from the position stream.
    if (_isStationary()) {
      return elapsed >= _stationaryInterval;
    }

    // 5. Moving: write if we've drifted far enough to matter...
    final metresMoved = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );
    if (metresMoved >= _driftMeters) return true;

    // 6. ...or if it's simply been too long. Crawling in traffic still needs
    //    to prove the connection is alive.
    if (elapsed >= _maxInterval) return true;

    return false;
  }

  bool _isStationary() {
    final since = _stationarySince;
    if (since == null) return false;
    return DateTime.now().difference(since) >= _stationaryThreshold;
  }

  MovementState _movementStateFor(Position position) {
    return position.speed < _stoppedSpeedMps
        ? MovementState.stopped
        : MovementState.moving;
  }

  Future<void> _write(Position position) async {
    final tripId = _activeTripId;
    final uid = _activeUid;
    if (tripId == null || uid == null) return;

    final location = LiveLocation(
      uid: uid,
      tripId: tripId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed < 0 ? 0 : position.speed,
      heading: position.heading,
      movementState: _movementStateFor(position),
      updatedAt: DateTime.now(),
    );

    try {
      await _locationDoc(tripId, uid).set(location.toMap());
      _lastWrittenPosition = position;
      _lastWrittenAt = DateTime.now();
    } catch (_) {
      // Offline. Firestore queues the write and flushes on reconnect;
      // deliberately not updating _lastWritten so the next fix retries.
    }
  }

  /// Keeps a parked member visible. Without this they'd go stale after 90
  /// seconds and everyone would think they'd dropped off the network.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_stationaryInterval, (_) async {
      if (!_isStationary()) return;
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) await _write(position);
      } catch (_) {}
    });
  }

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _locationDoc(
    String tripId,
    String uid,
  ) {
    // A subcollection of the trip, not a top-level collection, so tripId lives
    // in the path. Security rules can then authorise reads without inspecting
    // document contents — which Firestore cannot do for queries at all.
    //
    // One document per user, overwritten on every update. Appending a document
    // per GPS ping would mean hundreds of thousands of documents after a few
    // trips.
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('live_locations')
        .doc(uid);
  }

  /// Live locations for everyone in a trip.
  Stream<List<LiveLocation>> watchTripLocations(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('live_locations')
        .snapshots()
        .map((snap) => snap.docs.map(LiveLocation.fromDoc).toList());
  }

  /// Straight-line distance in metres. Not road distance — that needs the
  /// Directions API and costs money per call.
  static double distanceBetween(LiveLocation a, LiveLocation b) {
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }
}