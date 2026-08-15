import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/location_model.dart';
import '../../../../models/trip_member_model.dart';

class MemberLocationTile extends StatelessWidget {
  const MemberLocationTile({
    required this.member,
    required this.isCurrentUser,
    this.location,
    this.distanceMeters,
    super.key,
  });

  final TripMember member;
  final bool isCurrentUser;

  /// Null when this member has never written a location — they joined but
  /// haven't started sharing yet.
  final LiveLocation? location;

  /// Distance from the current user. Null if either position is unknown.
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = location?.effectiveState;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Avatar(member: member, state: state),
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
                const SizedBox(height: 2),
                _StatusLine(
                  location: location,
                  distanceMeters: distanceMeters,
                  isCurrentUser: isCurrentUser,
                ),
              ],
            ),
          ),
          if (location != null && !location!.isStale)
            _SpeedReadout(speedKmh: location!.speedKmh),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.state});

  final TripMember member;
  final MovementState? state;

  Color get _dotColour {
    switch (state) {
      case MovementState.moving:
        return AppColors.signal;
      case MovementState.stopped:
        return AppColors.stopped;
      case MovementState.offline:
      case null:
        return AppColors.ash;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.graphite,
          backgroundImage:
              member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
          child: member.photoUrl == null
              ? Text(
                  member.displayName.characters.first.toUpperCase(),
                  style: textTheme.titleMedium,
                )
              : null,
        ),
        // Status dot. Colour alone never carries meaning — the text line
        // below always states the status in words too.
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _dotColour,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.slate, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.location,
    required this.distanceMeters,
    required this.isCurrentUser,
  });

  final LiveLocation? location;
  final double? distanceMeters;
  final bool isCurrentUser;

  String _formatAge(DateTime updatedAt) {
    // Clamp at zero. `updatedAt` is a server timestamp while `now` is the
    // device clock — if the device runs behind the server, the difference
    // comes out negative. "-2s ago" is worse than "just now".
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loc = location;

    if (loc == null) {
      return Text('Not sharing location', style: textTheme.bodySmall);
    }

    final parts = <String>[];

    switch (loc.effectiveState) {
      case MovementState.moving:
        parts.add('Moving');
      case MovementState.stopped:
        parts.add('Stopped');
      case MovementState.offline:
        // Deliberately vague. We know they stopped updating; we do not know
        // why. Saying anything stronger would be claiming knowledge we
        // don't have.
        parts.add('No signal');
    }

    if (!isCurrentUser && distanceMeters != null) {
      parts.add(_formatDistance(distanceMeters!));
    }

    parts.add(_formatAge(loc.updatedAt));

    final isOffline = loc.effectiveState == MovementState.offline;

    return Text(
      parts.join('  ·  '),
      style: textTheme.bodySmall?.copyWith(
        color: isOffline ? AppColors.warning : null,
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout({required this.speedKmh});

  final double speedKmh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          speedKmh < 1 ? '0' : speedKmh.round().toString(),
          style: textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text('km/h', style: textTheme.bodySmall),
      ],
    );
  }
}