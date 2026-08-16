import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/location_model.dart';
import '../../../../models/trip_member_model.dart';

class TripMap extends StatefulWidget {
  const TripMap({
    required this.members,
    required this.locations,
    required this.currentUid,
    super.key,
  });

  final List<TripMember> members;
  final Map<String, LiveLocation> locations;
  final String? currentUid;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  GoogleMapController? _controller;

  /// When true, the camera follows the current user. Turned off the moment
  /// they pan the map themselves — nothing is more irritating than a map that
  /// yanks itself back while you're trying to look at something.
  bool _followMe = true;

  bool _hasDoneInitialFit = false;

  static const _bengaluru = LatLng(12.9716, 77.5946);

  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_followMe) _centreOnMe();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  LiveLocation? get _myLocation =>
      widget.currentUid == null ? null : widget.locations[widget.currentUid];

  Future<void> _centreOnMe() async {
    final me = _myLocation;
    final controller = _controller;
    if (me == null || controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newLatLng(LatLng(me.lat, me.lng)),
    );
  }

  /// Zooms out far enough to show everyone. Useful when the group has spread
  /// out and you've lost track of where people are relative to each other.
  Future<void> _fitAll() async {
    final controller = _controller;
    if (controller == null) return;

    final points = widget.locations.values
        .where((l) => !l.isStale)
        .map((l) => LatLng(l.lat, l.lng))
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    final bounds = _boundsFor(points);
    // 80px padding so markers near the edge aren't clipped by the frame.
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    setState(() => _followMe = false);
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final member in widget.members) {
      final location = widget.locations[member.uid];
      if (location == null) continue;

      final isMe = member.uid == widget.currentUid;
      final state = location.effectiveState;

      markers.add(
        Marker(
          markerId: MarkerId(member.uid),
          position: LatLng(location.lat, location.lng),
          // Heading only means something while moving. A stopped rider's last
          // heading is stale information dressed up as current.
          rotation: state == MovementState.moving ? location.heading : 0,
          flat: state == MovementState.moving,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(state, isMe)),
          infoWindow: InfoWindow(
            title: isMe ? '${member.displayName} (you)' : member.displayName,
            snippet: _snippetFor(location),
          ),
        ),
      );
    }

    return markers;
  }

  double _hueFor(MovementState state, bool isMe) {
    // Deliberately not red for any of these. Red belongs to emergencies only —
    // if it appears on ordinary markers it stops meaning anything.
    if (isMe) return BitmapDescriptor.hueAzure;
    switch (state) {
      case MovementState.moving:
        return BitmapDescriptor.hueCyan;
      case MovementState.stopped:
        return BitmapDescriptor.hueYellow;
      case MovementState.offline:
        return BitmapDescriptor.hueViolet;
    }
  }

  String _snippetFor(LiveLocation location) {
    switch (location.effectiveState) {
      case MovementState.moving:
        return '${location.speedKmh.round()} km/h';
      case MovementState.stopped:
        return 'Stopped';
      case MovementState.offline:
        return 'No signal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _myLocation;

    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: me != null ? LatLng(me.lat, me.lng) : _bengaluru,
                zoom: 14,
              ),
              markers: _buildMarkers(),
              myLocationEnabled: false, // our own marker already shows this
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _controller = controller;
                _controller!.setMapStyle(_darkMapStyle);
                if (!_hasDoneInitialFit) {
                  _hasDoneInitialFit = true;
                  // Delayed so the map has laid out before we animate.
                  Future.delayed(const Duration(milliseconds: 300), _fitAll);
                }
              },
              // Any manual gesture means the user wants to look at something
              // specific. Stop dragging the camera away from them.
              onCameraMoveStarted: () {
                if (_followMe) setState(() => _followMe = false);
              },
            ),

            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Column(
                children: [
                  _MapButton(
                    icon: _followMe
                        ? Icons.my_location
                        : Icons.location_searching,
                    tooltip: _followMe ? 'Following you' : 'Centre on me',
                    isActive: _followMe,
                    onPressed: () {
                      setState(() => _followMe = true);
                      _centreOnMe();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapButton(
                    icon: Icons.zoom_out_map,
                    tooltip: 'Show everyone',
                    isActive: false,
                    onPressed: _fitAll,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.slate,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.signal : AppColors.fog,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark map styling, so the map doesn't blow out the rest of the interface.
/// Roads stay legible; everything else recedes.
const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
]
''';