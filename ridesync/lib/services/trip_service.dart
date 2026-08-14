import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip_member_model.dart';
import '../models/trip_model.dart';

class TripException implements Exception {
  const TripException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TripService {
  TripService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _trips =>
      _firestore.collection('trips');

  /// Public lookup table: invite code -> trip ID.
  ///
  /// This exists because joining requires finding a trip you are not yet a
  /// member of, and the trip documents themselves are readable only by
  /// members. Rather than weakening that rule, we keep a tiny separate
  /// collection containing nothing sensitive — just a code, the trip it points
  /// at, and who owns it. Knowing a trip ID grants no access on its own.
  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _firestore.collection('invite_codes');

  /// Excludes visually ambiguous characters (0/O, 1/I/L) — these codes get
  /// read aloud across a car park and typed one-handed.
  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _codeLength = 6;

  String _randomCode() {
    final random = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  /// Finds a code not currently in use.
  ///
  /// A collision would send someone into a stranger's trip, so this checks
  /// rather than trusting the ~887 million combinations.
  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final existing = await _inviteCodes.doc(code).get();
      if (!existing.exists) return code;
    }
    throw const TripException(
      'Could not generate an invite code. Please try again.',
    );
  }

  /// Creates a trip, its invite code, and the owner's membership — atomically.
  Future<Trip> createTrip({
    required String name,
    required String ownerId,
    required String ownerDisplayName,
    String? ownerPhotoUrl,
    String? description,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const TripException('Give your trip a name.');
    }

    final code = await _generateUniqueCode();
    final tripRef = _trips.doc();
    final now = DateTime.now();

    final trip = Trip(
      tripId: tripRef.id,
      name: trimmedName,
      description: description?.trim(),
      inviteCode: code,
      ownerId: ownerId,
      status: TripStatus.active,
      memberIds: [ownerId],
      createdAt: now,
    );

    final owner = TripMember(
      uid: ownerId,
      displayName: ownerDisplayName,
      photoUrl: ownerPhotoUrl,
      role: MemberRole.owner,
      status: MemberStatus.active,
      joinedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(tripRef, trip.toMap());
    batch.set(tripRef.collection('members').doc(ownerId), owner.toMap());
    batch.set(_inviteCodes.doc(code), {
      'code': code,
      'tripId': tripRef.id,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(now),
    });
    await batch.commit();

    return trip;
  }

  /// Joins a trip by invite code.
  ///
  /// Both membership writes go in one batch. Splitting them risks a half-joined
  /// state: present in `memberIds` (so the security rule grants access to
  /// everyone's location) but absent from the member list, so nobody knows
  /// they're there — or the reverse, where they join and can see nothing.
  Future<Trip> joinTrip({
    required String code,
    required String uid,
    required String displayName,
    String? photoUrl,
  }) async {
    final normalised = code.trim().toUpperCase();
    if (normalised.isEmpty) {
      throw const TripException('Enter an invite code.');
    }

    final codeDoc = await _inviteCodes.doc(normalised).get();
    if (!codeDoc.exists) {
      throw const TripException('No active trip found with that code.');
    }

    final tripId = codeDoc.data()!['tripId'] as String;
    final tripRef = _trips.doc(tripId);

    // Already a member? Rejoining is a no-op, not an error — the user probably
    // re-entered the code because they weren't sure it worked. Reading our own
    // member doc is permitted by the rules even before joining.
    final existing = await tripRef.collection('members').doc(uid).get();
    if (existing.exists &&
        existing.data()!['status'] == MemberStatus.active.name) {
      final snapshot = await tripRef.get();
      return Trip.fromDoc(snapshot);
    }

    final member = TripMember(
      uid: uid,
      displayName: displayName,
      photoUrl: photoUrl,
      role: MemberRole.member,
      status: MemberStatus.active,
      joinedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    batch.set(tripRef.collection('members').doc(uid), member.toMap());
    await batch.commit();

    // Safe to read now — the batch made us a member.
    final snapshot = await tripRef.get();
    return Trip.fromDoc(snapshot);
  }

  /// Leaves a trip.
  ///
  /// Removes the UID from `memberIds` (revoking access) and marks the member
  /// record `left` rather than deleting it, so trip history still shows who was
  /// present. Deleting it would erase the record of who was on a trip where
  /// something happened.
  Future<void> leaveTrip({
    required String tripId,
    required String uid,
  }) async {
    final tripRef = _trips.doc(tripId);
    final snapshot = await tripRef.get();

    if (!snapshot.exists) {
      throw const TripException('That trip no longer exists.');
    }

    if (Trip.fromDoc(snapshot).isOwnedBy(uid)) {
      throw const TripException(
        'You created this trip. End it instead of leaving.',
      );
    }

    final batch = _firestore.batch();
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayRemove([uid]),
    });
    batch.update(tripRef.collection('members').doc(uid), {
      'status': MemberStatus.left.name,
    });
    await batch.commit();
  }

  /// Ends a trip. Owner only.
  ///
  /// The invite code document is deleted so the code stops working immediately
  /// and becomes available for reuse. `memberIds` stays intact so members can
  /// still see the trip in their history.
  Future<void> endTrip({
    required String tripId,
    required String uid,
  }) async {
    final tripRef = _trips.doc(tripId);
    final snapshot = await tripRef.get();

    if (!snapshot.exists) {
      throw const TripException('That trip no longer exists.');
    }

    final trip = Trip.fromDoc(snapshot);
    if (!trip.isOwnedBy(uid)) {
      throw const TripException(
        'Only the person who created a trip can end it.',
      );
    }

    final batch = _firestore.batch();
    batch.update(tripRef, {
      'status': TripStatus.ended.name,
      'endedAt': Timestamp.now(),
    });
    batch.delete(_inviteCodes.doc(trip.inviteCode));
    await batch.commit();
  }

  Stream<List<Trip>> watchActiveTrips(String uid) {
    return _trips
        .where('memberIds', arrayContains: uid)
        .where('status', isEqualTo: TripStatus.active.name)
        .snapshots()
        .map((snap) => snap.docs.map(Trip.fromDoc).toList());
  }

  Stream<Trip?> watchTrip(String tripId) {
    return _trips.doc(tripId).snapshots().map(
          (doc) => doc.exists ? Trip.fromDoc(doc) : null,
        );
  }

  Stream<List<TripMember>> watchMembers(String tripId) {
    return _trips
        .doc(tripId)
        .collection('members')
        .where('status', isEqualTo: MemberStatus.active.name)
        .snapshots()
        .map((snap) => snap.docs.map(TripMember.fromDoc).toList());
  }
}