import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/trip_member_model.dart';
import '../../../models/trip_model.dart';
import '../../../services/trip_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/trip_provider.dart';

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
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
        error: (_, __) => const _ErrorState(
          message: 'Could not load this trip.',
        ),
        data: (trip) {
          if (trip == null) {
            return const _ErrorState(message: 'This trip no longer exists.');
          }
          if (!trip.isActive) {
            return const _ErrorState(message: 'This trip has ended.');
          }
          return _TripBody(trip: trip);
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
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _InviteCodeCard(code: trip.inviteCode, tripName: trip.name),

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
          error: (_, __) => Text(
            'Could not load members.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
          data: (members) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${members.length} ${members.length == 1 ? "person" : "people"}',
                style: textTheme.labelSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...members.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MemberTile(
                    member: m,
                    isCurrentUser: m.uid == currentUid,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Placeholder for Phase 3. Stated plainly rather than showing a
        // disabled map that looks broken.
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
              Text('Live map coming in Phase 3', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Location sharing is not active yet.',
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
  const _InviteCodeCard({required this.code, required this.tripName});

  final String code;
  final String tripName;

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
          Text(
            code,
            style: textTheme.displayMedium?.copyWith(letterSpacing: 8),
          ),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isCurrentUser});

  final TripMember member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.graphite,
            backgroundImage: member.photoUrl != null
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(
                    member.displayName.characters.first.toUpperCase(),
                    style: textTheme.titleMedium,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('You', style: textTheme.bodySmall),
                    ],
                  ],
                ),
                if (member.isOwner)
                  Text('Created this trip', style: textTheme.bodySmall),
              ],
            ),
          ),
          // Location status lands here in Phase 3.
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