import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Records a mono 16 kHz voice note straight into memory and hands it back as WAV —
/// a format every speech model accepts.
class VoiceRecorder {
  static const sampleRate = 16000;
  static const maxDuration = Duration(seconds: 90);

  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _sub;

  /// Microphone level from 0 (silence) to 1, sampled every 80 ms while recording.
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 80))
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  /// Returns false when the microphone permission is denied.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _pcm.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _sub = stream.listen(_pcm.add);
    return true;
  }

  /// Stops and returns the WAV bytes, or null if nothing was captured.
  Future<Uint8List?> stop() async {
    await _recorder.stop();
    await _sub?.cancel();
    _sub = null;
    final pcm = _pcm.takeBytes();
    return pcm.isEmpty ? null : wavFromPcm16(pcm, sampleRate);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    await _sub?.cancel();
    _sub = null;
    _pcm.clear();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _recorder.dispose();
  }
}

Uint8List wavFromPcm16(Uint8List pcm, int sampleRate) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}
