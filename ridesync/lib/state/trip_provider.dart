import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_member_model.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import 'auth_provider.dart';

final tripServiceProvider = Provider<TripService>((ref) => TripService());

/// The signed-in user's active trips. Empty when signed out.
final activeTripsProvider = StreamProvider<List<Trip>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);

  return ref.watch(tripServiceProvider).watchActiveTrips(user.uid);
});

/// A single trip by ID. Emits null if it's deleted while being watched.
final tripProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  return ref.watch(tripServiceProvider).watchTrip(tripId);
});

/// Active members of a trip.
final tripMembersProvider =
    StreamProvider.family<List<TripMember>, String>((ref, tripId) {
  return ref.watch(tripServiceProvider).watchMembers(tripId);
});