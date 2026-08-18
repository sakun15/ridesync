import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/crash_detection/sensor_recorder.dart';

/// Kept alive for the app's lifetime so a recording survives navigation.
final sensorRecorderProvider = Provider<SensorRecorder>((ref) {
  final recorder = SensorRecorder();
  ref.onDispose(recorder.stop);
  return recorder;
});