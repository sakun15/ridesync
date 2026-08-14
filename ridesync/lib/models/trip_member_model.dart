import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberRole { owner, member }

enum MemberStatus { active, left }

class TripMember {
  const TripMember({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.photoUrl,
  });

  final String uid;

  /// Snapshot of the user's name at join time.
  ///
  /// Denormalised on purpose: rendering a member list shouldn't require N
  /// extra reads against `users/`. The trade-off is that a name change won't
  /// propagate to trips already joined — acceptable for now, and cheap to fix
  /// later with a Cloud Function if it becomes a problem.
  final String displayName;

  final String? photoUrl;
  final MemberRole role;
  final MemberStatus status;
  final DateTime joinedAt;

  bool get isOwner => role == MemberRole.owner;

  factory TripMember.fromMap(Map<String, dynamic> map) {
    return TripMember(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? 'Rider',
      photoUrl: map['photoUrl'] as String?,
      role: MemberRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => MemberRole.member,
      ),
      status: MemberStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MemberStatus.active,
      ),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory TripMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TripMember.fromMap({...?doc.data(), 'uid': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.name,
      'status': status.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}