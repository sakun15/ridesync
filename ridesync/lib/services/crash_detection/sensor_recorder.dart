import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Captures raw sensor data to a file so real rides can be replayed offline.
///
/// This exists because crash detection thresholds cannot be reasoned into
/// existence — they have to be measured. Without recorded data, every change
/// to a threshold would mean another test ride. With it, one ride can be
/// replayed a hundred times.
///
/// Development tool. Not part of the shipped app.
class SensorRecorder {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<Position>? _positionSub;

  IOSink? _sink;
  File? _file;
  DateTime? _startedAt;

  int _sampleCount = 0;

  bool get isRecording => _sink != null;
  int get sampleCount => _sampleCount;
  String? get filePath => _file?.path;

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Sensor sampling rate.
  ///
  /// 50Hz is deliberately high — a crash impact lasts well under a second, and
  /// undersampling would miss the peak entirely. Storage is cheap; a missed
  /// impact in the training data is not.
  static const _samplingPeriod = Duration(milliseconds: 20);

  Future<void> start({String? label}) async {
    if (isRecording) return;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final name = label == null ? timestamp : '${label}_$timestamp';

    _file = File('${dir.path}/sensors_$name.jsonl');
    _sink = _file!.openWrite();
    _startedAt = DateTime.now();
    _sampleCount = 0;

    // One header line describing the session, then one JSON object per line.
    // JSONL rather than a JSON array so a crashed or force-quit app still
    // leaves a readable file — every complete line is valid on its own.
    _write({
      'type': 'session',
      'startedAt': _startedAt!.toIso8601String(),
      'label': label,
      'samplingHz': 1000 ~/ _samplingPeriod.inMilliseconds,
    });

    _accelSub = accelerometerEventStream(samplingPeriod: _samplingPeriod)
        .listen((e) {
      _write({
        'type': 'accel',
        't': _elapsedMs(),
        'x': e.x,
        'y': e.y,
        'z': e.z,
      });
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: _samplingPeriod).listen((e) {
      _write({
        'type': 'gyro',
        't': _elapsedMs(),
        'x': e.x,
        'y': e.y,
        'z': e.z,
      });
    });

    // GPS at whatever rate it produces. Much slower than the sensors, but the
    // speed signal is essential — an impact without a speed drop is probably a
    // dropped phone, not a crash.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // every fix, we want the full picture
      ),
    ).listen((p) {
      _write({
        'type': 'gps',
        't': _elapsedMs(),
        'lat': p.latitude,
        'lng': p.longitude,
        'speed': p.speed,
        'accuracy': p.accuracy,
        'heading': p.heading,
      });
    });
  }

  /// Marks a moment of interest in the recording.
  ///
  /// Press this immediately after riding over something notable — a pothole, a
  /// speed bump, hard braking. When reviewing the data later, these markers are
  /// what let you say "this spike was a pothole" rather than guessing.
  void mark(String note) {
    if (!isRecording) return;
    _write({'type': 'mark', 't': _elapsedMs(), 'note': note});
  }

  Future<String?> stop() async {
    if (!isRecording) return null;

    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _positionSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _positionSub = null;

    _write({
      'type': 'end',
      't': _elapsedMs(),
      'samples': _sampleCount,
    });

    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _startedAt = null;

    final path = _file?.path;
    _file = null;
    return path;
  }

  int _elapsedMs() =>
      _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inMilliseconds;

  void _write(Map<String, dynamic> event) {
    _sink?.writeln(jsonEncode(event));
    _sampleCount++;
  }

  /// Every recording on this device, newest first.
  static Future<List<File>> listRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('sensors_') && f.path.endsWith('.jsonl'))
        .toList();

    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}