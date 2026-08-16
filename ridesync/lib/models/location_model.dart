import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementState { moving, stopped, offline }

class LiveLocation {
  const LiveLocation({
    required this.uid,
    required this.tripId,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.movementState,
    required this.updatedAt,
    this.batteryLevel,
  });

  final String uid;
  final String tripId;
  final double lat;
  final double lng;

  /// GPS accuracy radius in metres. Lower is better.
  /// Readings above ~50m are usually junk — tunnels, dense buildings.
  final double accuracy;

  /// Metres per second, straight from GPS.
  final double speed;

  /// Direction of travel in degrees (0 = north).
  final double heading;

  final MovementState movementState;
  final DateTime updatedAt;

  /// Useful in an emergency — "his phone was at 6% when it stopped updating"
  /// tells responders something different from "he stopped updating."
  final int? batteryLevel;

  double get speedKmh => speed * 3.6;

  /// A member is offline if we haven't heard from them recently, regardless
  /// of what their last write said. Computed on read, not stored — the whole
  /// point is that a dead phone can't write "I'm offline."
  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(seconds: 90);

  MovementState get effectiveState =>
      isStale ? MovementState.offline : movementState;

  factory LiveLocation.fromMap(Map<String, dynamic> map) {
    return LiveLocation(
      uid: map['uid'] as String,
      tripId: map['tripId'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
      movementState: MovementState.values.firstWhere(
        (s) => s.name == map['movementState'],
        orElse: () => MovementState.stopped,
      ),
      batteryLevel: (map['batteryLevel'] as num?)?.toInt(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory LiveLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return LiveLocation.fromMap(doc.data()!);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'tripId': tripId,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'movementState': movementState.name,
      'batteryLevel': batteryLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}