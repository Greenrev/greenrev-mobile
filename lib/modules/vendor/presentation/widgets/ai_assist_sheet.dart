import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../data/listing_service.dart';
import '../../data/voice_recorder.dart';

const _ease = Cubic(0.16, 1, 0.3, 1);
const _maxPhotos = 4;

enum AssistMode { scan, voice }

/// What the vendor chose to keep from the AI's suggestions.
class AssistResult {
  final Map<String, String> fields;
  final List<MapEntry<String, String>> specs;
  final List<XFile> photos;
  const AssistResult(this.fields, this.specs, this.photos);
}

const _labels = {
  'name': 'Listing name',
  'make': 'Make / Brand',
  'price': 'Price',
  'year': 'Year',
  'mileage': 'Mileage',
  'colorName': 'Colour',
  'transmission': 'Transmission',
  'origin': 'Condition',
  'vin': 'VIN',
  'horsepower': 'Horsepower',
  'torque': 'Torque',
  'topSpeed': 'Top speed',
  'acceleration': '0-100 km/h',
  'stockQuantity': 'Stock quantity',
  'description': 'Description',
};

Future<AssistResult?> showAiAssistSheet(
  BuildContext context, {
  required AssistMode mode,
  required String category,
  required Map<String, String> currentFields,
  required Map<String, String> currentSpecs,
}) {
  return showModalBottomSheet<AssistResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiAssistSheet(
      mode: mode,
      category: category,
      currentFields: currentFields,
      currentSpecs: currentSpecs,
    ),
  );
}

class _Row {
  final String id;
  final String label;
  final String value;
  final String? current;
  final Color? swatch;
  const _Row(this.id, this.label, this.value, this.current, this.swatch);
}

class _AiAssistSheet extends StatefulWidget {
  final AssistMode mode;
  final String category;
  final Map<String, String> currentFields;
  final Map<String, String> currentSpecs;

  const _AiAssistSheet({
    required this.mode,
    required this.category,
    required this.currentFields,
    required this.currentSpecs,
  });

  @override
  State<_AiAssistSheet> createState() => _AiAssistSheetState();
}

class _AiAssistSheetState extends State<_AiAssistSheet>
    with TickerProviderStateMixin {
  final _service = ListingService();
  // Created on first use so the scan sheet never touches the microphone plugin.
  VoiceRecorder? _voice;
  VoiceRecorder get _recorder => _voice ??= VoiceRecorder();
  final List<XFile> _photos = [];
  bool _usePhotos = true;
  bool _loading = false;
  bool _recording = false;
  String? _error;
  ExtractionResult? _result;
  final Set<String> _checked = {};
  final List<double> _levels = List.filled(28, 0);
  StreamSubscription<double>? _levelSub;
  Timer? _timer;
  int _seconds = 0;

  // Created eagerly: a lazy controller first touched in dispose() would be built mid-teardown.
  late final AnimationController _pulse;
  late final AnimationController _scan;
  late final AnimationController _rowsIn;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _rowsIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  bool get _isVehicle => widget.category == 'vehicle';

  @override
  void dispose() {
    _levelSub?.cancel();
    _timer?.cancel();
    _voice?.dispose();
    _pulse.dispose();
    _scan.dispose();
    _rowsIn.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- capture

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = source == ImageSource.camera
        ? [
            ?await picker.pickImage(
              source: source,
              maxWidth: 2000,
              imageQuality: 85,
            ),
          ]
        : await picker.pickMultiImage(
            maxWidth: 2000,
            imageQuality: 85,
            limit: remaining > 1 ? remaining : null,
          );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(picked.take(remaining));
      _error = null;
    });
  }

  Future<void> _toggleRecording() async {
    if (_recording) return _finishRecording();
    setState(() {
      _error = null;
      _result = null;
    });
    final ok = await _recorder.start();
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _error =
            'Microphone access is off. Turn it on for GreenRev in your phone settings.',
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _levelSub = _recorder.levels.listen((l) {
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(l);
      });
    });
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _seconds++);
      if (_seconds >= VoiceRecorder.maxDuration.inSeconds) _finishRecording();
    });
    _pulse.repeat();
    setState(() => _recording = true);
  }

  Future<void> _finishRecording() async {
    _timer?.cancel();
    await _levelSub?.cancel();
    _levelSub = null;
    _pulse.stop();
    HapticFeedback.lightImpact();
    final wav = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _levels.fillRange(0, _levels.length, 0);
    });
    if (wav == null) {
      setState(
        () => _error =
            "We didn't catch anything. Try again a little closer to the mic.",
      );
      return;
    }
    await _run(wav: wav);
  }

  Future<void> _run({Uint8List? wav}) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    if (wav == null) _scan.repeat();
    try {
      final res = await _service.extract(
        category: widget.category,
        photos: wav == null ? _photos : const [],
        wav: wav,
      );
      if (!mounted) return;
      final rows = _rowsFor(res);
      setState(() {
        _result = res;
        _checked
          ..clear()
          ..addAll(rows.where((r) => r.current == null).map((r) => r.id));
      });
      HapticFeedback.mediumImpact();
      _rowsIn.forward(from: 0);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      _scan.stop();
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------- review

  List<_Row> _rowsFor(ExtractionResult res) {
    final f = res.listing.fields;
    final rows = <_Row>[];
    for (final key in _labels.keys) {
      final v = f[key];
      if (v == null) continue;
      final cur = widget.currentFields[key]?.trim();
      rows.add(
        _Row(
          key,
          key == 'make' && !_isVehicle ? 'Brand' : _labels[key]!,
          v,
          cur != null && cur.isNotEmpty && cur.toLowerCase() != v.toLowerCase()
              ? cur
              : null,
          key == 'colorName' ? _hex(f['colorHex']) : null,
        ),
      );
    }
    for (final s in res.listing.extraSpecs) {
      final curKey = widget.currentSpecs.keys
          .where((k) => k.toLowerCase() == s.key.toLowerCase())
          .firstOrNull;
      final cur = curKey == null ? null : widget.currentSpecs[curKey]?.trim();
      rows.add(
        _Row(
          'spec:${s.key}',
          s.key,
          s.value,
          cur != null &&
                  cur.isNotEmpty &&
                  cur.toLowerCase() != s.value.toLowerCase()
              ? cur
              : null,
          null,
        ),
      );
    }
    return rows;
  }

  static Color? _hex(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  void _apply() {
    final res = _result!;
    final fields = <String, String>{};
    res.listing.fields.forEach((k, v) {
      if (_checked.contains(k)) fields[k] = v;
    });
    if (_checked.contains('colorName') &&
        res.listing.fields['colorHex'] != null) {
      fields['colorHex'] = res.listing.fields['colorHex']!;
    }
    final specs = res.listing.extraSpecs
        .where((s) => _checked.contains('spec:${s.key}'))
        .toList();
    Navigator.of(context).pop(
      AssistResult(
        fields,
        specs,
        widget.mode == AssistMode.scan && _usePhotos
            ? List.of(_photos)
            : const [],
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.accent.withValues(alpha: 0.25)),
        ),
        // Opaque stops: a translucent gradient would let the page show through.
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [
            Color.alphaBlend(
              AppTheme.accent.withValues(alpha: 0.08),
              const Color(0xFF0A0B0B),
            ),
            const Color(0xFF0A0B0B),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 8),
                const GrEyebrow('AI assist'),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    if (_recording) await _recorder.cancel();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            GrHeadline(
              widget.mode == AssistMode.scan ? 'Scan photos' : 'Speak it',
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              widget.mode == AssistMode.scan
                  ? _isVehicle
                        ? 'Add photos of the car, its VIN plate, odometer, customs papers or a spec sheet.'
                        : 'Add photos of the part, its box, label or part number.'
                  : _isVehicle
                  ? 'Say the make, model, year, mileage, condition (e.g. tokunbo), transmission, colour and your price.'
                  : 'Say the part, brand, which cars it fits, its condition and your price.',
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: _ease,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _result != null
                  ? KeyedSubtree(
                      key: const ValueKey('review'),
                      child: _review(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('capture'),
                      child: widget.mode == AssistMode.scan
                          ? _scanView()
                          : _voiceView(),
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: GrNotice(_error!),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < _photos.length; i++) _photoTile(i),
            if (_photos.length < _maxPhotos && !_loading) ...[
              _addTile(
                Icons.photo_camera_outlined,
                'Camera',
                () => _pick(ImageSource.camera),
              ),
              if (_photos.length < _maxPhotos - 1 || _photos.isEmpty)
                _addTile(
                  Icons.photo_library_outlined,
                  'Gallery',
                  () => _pick(ImageSource.gallery),
                ),
            ],
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _usePhotos,
            onChanged: _loading ? null : (v) => setState(() => _usePhotos = v),
            activeTrackColor: AppTheme.accent,
            title: const Text(
              'Also use these as listing photos',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          GrPrimaryButton(
            label: 'Read photos',
            loadingLabel: 'Reading photos…',
            loading: _loading,
            accent: true,
            icon: Icons.auto_awesome,
            onPressed: () => _run(),
          ),
        ],
      ],
    );
  }

  Widget _photoTile(int i) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_photos[i].path),
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: _ease,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List>(
              future: _photos[i].readAsBytes(),
              builder: (_, snap) => snap.hasData
                  ? Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Container(color: Colors.white10),
            ),
            if (_loading)
              AnimatedBuilder(
                animation: _scan,
                builder: (_, _) {
                  final t = (_scan.value + i * 0.15) % 1.0;
                  return Stack(
                    children: [
                      Container(color: AppTheme.accent.withValues(alpha: 0.08)),
                      Align(
                        alignment: Alignment(
                          0,
                          -1.2 + 2.4 * Curves.easeInOut.transform(t),
                        ),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.accent.withValues(alpha: 0),
                                AppTheme.accent.withValues(alpha: 0.5),
                                AppTheme.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _photos.removeAt(i)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _addTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accent, size: 26),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceView() {
    final busy = _loading;
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_recording)
                for (var i = 0; i < 3; i++)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) {
                      final t = (_pulse.value + i / 3) % 1.0;
                      return Container(
                        width: 88 + 72 * t,
                        height: 88 + 72 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.danger.withValues(
                              alpha: 0.5 * (1 - t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              GestureDetector(
                onTap: busy ? null : _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: _ease,
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? AppTheme.danger : AppTheme.accent,
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? AppTheme.danger : AppTheme.accent)
                            .withValues(alpha: 0.4),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: busy
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            _recording ? Icons.stop_rounded : Icons.mic,
                            key: ValueKey(_recording),
                            size: 36,
                            color: _recording ? Colors.white : Colors.black,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final l in _levels)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 3,
                  height: _recording ? math.max(4, l * 48) : 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _recording ? AppTheme.accent : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _recording
              ? 'Recording ${_fmt(_seconds)} / ${_fmt(VoiceRecorder.maxDuration.inSeconds)} — tap to finish'
              : busy
              ? 'Listening back and filling in your listing…'
              : 'Tap the mic and start talking',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _review() {
    final res = _result!;
    final rows = _rowsFor(res);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (res.transcript != null) ...[
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppTheme.accent.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              '“${res.transcript}”',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final w in res.warnings) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.goldAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.goldAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppTheme.goldAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    w,
                    style: const TextStyle(
                      color: Color(0xFFE9D9A6),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "We couldn't find listing details in that. Try clearer photos or say a little more.",
              style: TextStyle(color: AppTheme.textSubtle, fontSize: 14),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          GrSectionLabel(
            'Found ${rows.length} ${rows.length == 1 ? 'detail' : 'details'}',
            trailing: GestureDetector(
              onTap: () => setState(() {
                if (_checked.length == rows.length) {
                  _checked.clear();
                } else {
                  _checked.addAll(rows.map((r) => r.id));
                }
              }),
              child: Text(
                _checked.length == rows.length ? 'SELECT NONE' : 'SELECT ALL',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              color: Colors.black26,
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _rowTile(rows[i], i, rows.length),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (rows.isNotEmpty)
          GrPrimaryButton(
            label:
                'Use ${_checked.length} ${_checked.length == 1 ? 'detail' : 'details'}',
            icon: Icons.check,
            accent: true,
            onPressed: _checked.isEmpty ? null : _apply,
          ),
        const SizedBox(height: 10),
        GrSecondaryButton(
          label: widget.mode == AssistMode.scan
              ? 'Change photos'
              : 'Record again',
          icon: Icons.refresh,
          onPressed: () => setState(() {
            _result = null;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _rowTile(_Row r, int i, int count) {
    final start = (i / math.max(count, 1)) * 0.6;
    final anim = CurvedAnimation(
      parent: _rowsIn,
      curve: Interval(start, math.min(1, start + 0.4), curve: _ease),
    );
    final checked = _checked.contains(r.id);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-0.06, 0),
          end: Offset.zero,
        ).animate(anim),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(
              () => checked ? _checked.remove(r.id) : _checked.add(r.id),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: i == count - 1
                  ? null
                  : Border(bottom: BorderSide(color: AppTheme.hairline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: checked
                        ? AppTheme.accent
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: checked ? AppTheme.accent : Colors.white24,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: checked ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (r.swatch != null) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: r.swatch,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              r.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (r.current != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Currently: ${r.current}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
