import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { active, ended }

class Trip {
  const Trip({
    required this.tripId,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.status,
    required this.memberIds,
    required this.createdAt,
    this.description,
    this.endedAt,
  });

  final String tripId;
  final String name;
  final String? description;
  final String inviteCode;
  final String ownerId;
  final TripStatus status;

  /// Denormalised copy of the member UIDs from the `members` subcollection.
  ///
  /// This exists solely because Firestore security rules cannot query
  /// subcollections — a rule like "only members can read this trip" needs
  /// membership visible on the trip document itself. It MUST be kept in sync
  /// with the subcollection via batch writes on every join and leave.
  final List<String> memberIds;

  final DateTime createdAt;
  final DateTime? endedAt;

  bool get isActive => status == TripStatus.active;

  bool isOwnedBy(String uid) => ownerId == uid;

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      tripId: map['tripId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      inviteCode: map['inviteCode'] as String,
      ownerId: map['ownerId'] as String,
      status: TripStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TripStatus.ended,
      ),
      memberIds: List<String>.from(map['memberIds'] as List? ?? const []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Trip.fromMap({...?doc.data(), 'tripId': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'ownerId': ownerId,
      'status': status.name,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
    };
  }
}