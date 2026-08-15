import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/location_model.dart';
import '../../../models/trip_member_model.dart';
import '../../../models/trip_model.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/location_provider.dart';
import '../../../state/trip_provider.dart';
import 'widgets/location_permission_gate.dart';
import 'widgets/member_location_tile.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred because startTracking touches providers, and modifying provider
    // state during the first build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void dispose() {
    // Deliberately NOT stopping tracking here.
    //
    // dispose() fires when this screen is popped — including when the user
    // taps into settings or a member's details. Stopping here would silently
    // end location sharing every time they navigated away, which is exactly
    // the moment it matters most. Tracking is stopped explicitly on leave/end
    // instead.
    super.dispose();
  }

  Future<void> _startTracking() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final service = ref.read(locationServiceProvider);
    final permission = await service.checkPermission();
    if (permission != LocationPermissionState.granted) return;

    await service.startTracking(tripId: widget.tripId, uid: user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(tripAsync.value?.name ?? 'Trip'),
        actions: [
          if (tripAsync.value != null && user != null)
            _TripMenu(trip: tripAsync.value!, uid: user.uid),
        ],
      ),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorState(
          message: 'Could not load this trip.',
        ),
        data: (trip) {
          if (trip == null) {
            return const _ErrorState(message: 'This trip no longer exists.');
          }
          if (!trip.isActive) {
            return const _ErrorState(message: 'This trip has ended.');
          }
          return LocationPermissionGate(child: _TripBody(trip: trip));
        },
      ),
    );
  }
}

class _TripBody extends ConsumerWidget {
  const _TripBody({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final membersAsync = ref.watch(tripMembersProvider(trip.tripId));
    final locationsAsync = ref.watch(tripLocationsProvider(trip.tripId));
    final currentUid = ref.watch(authStateProvider).value?.uid;

    // Keyed by uid so each member tile can find its own location in O(1)
    // rather than scanning the list.
    final locations = <String, LiveLocation>{
      for (final l in locationsAsync.value ?? const <LiveLocation>[])
        l.uid: l,
    };

    final myLocation = currentUid == null ? null : locations[currentUid];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _InviteCodeCard(code: trip.inviteCode),

        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Notes', style: textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(trip.description!, style: textTheme.bodyMedium),
        ],

        const SizedBox(height: AppSpacing.lg),

        membersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Could not load members.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
          data: (members) {
            // Moving members first, then stopped, then offline. On a group
            // ride you care most about who's actually moving.
            final sorted = [...members]..sort((a, b) {
                int rank(TripMember m) {
                  final state = locations[m.uid]?.effectiveState;
                  return switch (state) {
                    MovementState.moving => 0,
                    MovementState.stopped => 1,
                    MovementState.offline => 2,
                    null => 3,
                  };
                }
                return rank(a).compareTo(rank(b));
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${members.length} ${members.length == 1 ? "person" : "people"}',
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...sorted.map((m) {
                  final memberLocation = locations[m.uid];
                  double? distance;
                  if (myLocation != null &&
                      memberLocation != null &&
                      m.uid != currentUid) {
                    distance = LocationService.distanceBetween(
                      myLocation,
                      memberLocation,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: MemberLocationTile(
                      member: m,
                      isCurrentUser: m.uid == currentUid,
                      location: memberLocation,
                      distanceMeters: distance,
                    ),
                  );
                }),
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.map_outlined, size: 28, color: AppColors.ash),
              const SizedBox(height: AppSpacing.sm),
              Text('Map coming next', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Location data is live — the map view is being added.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Invite code', style: textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(code, style: textTheme.displayMedium?.copyWith(letterSpacing: 8)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy code'),
          ),
        ],
      ),
    );
  }
}

class _TripMenu extends ConsumerWidget {
  const _TripMenu({required this.trip, required this.uid});

  final Trip trip;
  final String uid;

  Future<void> _confirmAndRun({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Stop broadcasting BEFORE the membership change. Once the security
      // rules no longer recognise us as a member, our writes would start
      // failing — and a stream retrying failed writes forever is worse than
      // one that stopped cleanly.
      final locationService = ref.read(locationServiceProvider);
      await locationService.stopTracking();

      try {
        await locationService.clearLocation(tripId: trip.tripId, uid: uid);
      } catch (_) {}

      await action();
      if (context.mounted) context.go(AppRoutes.home);
    } on TripException catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = trip.isOwnedBy(uid);
    final service = ref.read(tripServiceProvider);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) {
        if (value == 'end') {
          _confirmAndRun(
            context: context,
            ref: ref,
            title: 'End this trip?',
            body: 'Everyone will stop sharing their location and the invite '
                'code will stop working.',
            confirmLabel: 'End trip',
            action: () => service.endTrip(tripId: trip.tripId, uid: uid),
          );
        } else if (value == 'leave') {
          _confirmAndRun(
            context: context,
            ref: ref,
            title: 'Leave this trip?',
            body: 'You will stop sharing your location and will no longer see '
                'the others.',
            confirmLabel: 'Leave',
            action: () => service.leaveTrip(tripId: trip.tripId, uid: uid),
          );
        }
      },
      itemBuilder: (context) => [
        if (isOwner)
          const PopupMenuItem(value: 'end', child: Text('End trip'))
        else
          const PopupMenuItem(value: 'leave', child: Text('Leave trip')),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 32, color: AppColors.ash),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}