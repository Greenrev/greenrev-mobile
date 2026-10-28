import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../data/listing_service.dart';
import '../widgets/ai_assist_sheet.dart';
import '../widgets/listing_fields.dart';

const _ease = Cubic(0.16, 1, 0.3, 1);
const _maxPhotos = 10;

/// Vendor "add a vehicle or part" — same fields and rules as the website's
/// /vendor/products/add, with three ways in: type it, scan photos, or say it.
class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AddListingScreen());

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _SpecRow {
  final key = TextEditingController();
  final value = TextEditingController();
  _SpecRow([String k = '', String v = '']) {
    key.text = k;
    value.text = v;
  }
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formTop = GlobalKey();
  final _flash = FlashController();
  final _service = ListingService();

  String _category = 'vehicle';
  bool _inStock = true;
  Color? _colorSwatch;
  final List<XFile> _photos = [];
  final List<_SpecRow> _specs = [];
  bool _submitting = false;
  String? _submitStage;
  String? _aiNote;
  String? _photoError;

  late final Map<String, TextEditingController> _c = {
    for (final k in const [
      'name',
      'make',
      'price',
      'year',
      'mileage',
      'colorName',
      'description',
      'transmission',
      'origin',
      'vin',
      'horsepower',
      'torque',
      'topSpeed',
      'acceleration',
      'stockQuantity',
    ])
      k: TextEditingController(text: k == 'stockQuantity' ? '1' : ''),
  };

  bool get _isVehicle => _category == 'vehicle';

  @override
  void initState() {
    super.initState();
    // Pick up the latest admin-approved suggestions.
    ListingCatalog.refresh().then((changed) {
      if (changed && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final s in _specs) {
      s.dispose();
    }
    _flash.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- AI

  Future<void> _openAssist(AssistMode mode) async {
    FocusScope.of(context).unfocus();
    final result = await showAiAssistSheet(
      context,
      mode: mode,
      category: _category,
      currentFields: {
        for (final e in _c.entries)
          if (!(e.key == 'stockQuantity' && e.value.text == '1'))
            e.key: e.value.text,
      },
      currentSpecs: {for (final s in _specs) s.key.text: s.value.text},
    );
    if (result == null || !mounted) return;
    _applyAssist(result);
  }

  void _applyAssist(AssistResult r) {
    final changed = <String>[];
    setState(() {
      r.fields.forEach((k, v) {
        if (k == 'colorHex') return;
        final c = _c[k];
        if (c == null) return;
        c.text = k == 'vin' ? v.toUpperCase() : v;
        changed.add(k);
      });
      final hex = r.fields['colorHex'];
      if (hex != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
        _colorSwatch = Color(int.parse('FF${hex.substring(1)}', radix: 16));
      } else if (r.fields['colorName'] != null) {
        final opt = colorNamed(r.fields['colorName']!);
        if (opt != null) _colorSwatch = Color(opt.hex);
      }

      _specs.removeWhere((s) {
        final empty = s.key.text.trim().isEmpty && s.value.text.trim().isEmpty;
        if (empty) s.dispose();
        return empty;
      });
      for (final spec in r.specs) {
        final existing = _specs
            .where(
              (s) => s.key.text.trim().toLowerCase() == spec.key.toLowerCase(),
            )
            .firstOrNull;
        if (existing != null) {
          existing.value.text = spec.value;
        } else {
          _specs.add(_SpecRow(spec.key, spec.value));
        }
        changed.add('spec:${spec.key}');
      }

      if (r.photos.isNotEmpty) {
        _photos.addAll(r.photos.take(_maxPhotos - _photos.length));
        _photoError = null;
        changed.add('images');
      }

      final n = changed.length;
      _aiNote =
          'Filled $n ${n == 1 ? 'detail' : 'details'}'
          '${r.photos.isNotEmpty ? ' and added ${r.photos.length} photo${r.photos.length == 1 ? '' : 's'}' : ''}'
          ' — check everything below, then add anything missing.';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _formTop.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 600),
          curve: _ease,
        );
      }
      _flash.flash(changed.map((k) => k.toLowerCase()));
    });
  }

  // ---------------------------------------------------------------- photos

  Future<void> _addPhotos(ImageSource source) async {
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
      _photoError = null;
    });
  }

  // ---------------------------------------------------------------- submit

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    if (_photos.isEmpty) setState(() => _photoError = 'Add at least one photo');
    if (!valid || _photos.isEmpty) {
      HapticFeedback.heavyImpact();
      showGrSnack(
        context,
        'Fill in the highlighted fields first.',
        error: true,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _submitStage = 'Uploading photos…';
    });
    try {
      final urls = await _service.uploadPhotos(_photos);
      if (!mounted) return;
      setState(() => _submitStage = 'Publishing…');

      String t(String k) => _c[k]!.text.trim();
      final specs = <String, dynamic>{};
      if (_isVehicle) {
        final hp = num.tryParse(t('horsepower'));
        if (hp != null) specs['horsepower'] = hp;
        for (final k in const [
          'torque',
          'transmission',
          'topSpeed',
          'origin',
          'vin',
        ]) {
          if (t(k).isNotEmpty) specs[k] = t(k);
        }
        final acc = num.tryParse(t('acceleration'));
        if (acc != null) specs['acceleration'] = acc;
      }
      for (final s in _specs) {
        if (s.key.text.trim().isNotEmpty && s.value.text.trim().isNotEmpty) {
          specs[s.key.text.trim()] = s.value.text.trim();
        }
      }
      final priceValue = double.tryParse(
        t('price').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      final hex = _colorSwatch
          ?.toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2);

      await _service.createProduct({
        'name': t('name'),
        'make': t('make'),
        'category': _category,
        'price': t('price'),
        'priceValue': ?priceValue,
        if (_isVehicle && int.tryParse(t('year')) != null)
          'year': int.parse(t('year')),
        if (_isVehicle && t('mileage').isNotEmpty) 'mileage': t('mileage'),
        'image': urls.first,
        'images': urls,
        if (specs.isNotEmpty) 'specs': specs,
        if (_isVehicle && t('colorName').isNotEmpty)
          'color': {'name': t('colorName'), 'hex': '#${hex ?? '000000'}'},
        if (t('description').isNotEmpty) 'description': t('description'),
        'inStock': _inStock,
        'stockQuantity': int.tryParse(t('stockQuantity')) ?? 1,
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showGrSnack(context, 'Listing published');
      _reset();
    } on ApiException catch (e) {
      if (mounted) showGrSnack(context, e.message, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStage = null;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      for (final e in _c.entries) {
        e.value.text = e.key == 'stockQuantity' ? '1' : '';
      }
      for (final s in _specs) {
        s.dispose();
      }
      _specs.clear();
      _photos.clear();
      _colorSwatch = null;
      _inStock = true;
      _aiNote = null;
    });
    _formKey.currentState?.reset();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                40 + MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                const GrBackLink(),
                const SizedBox(height: 28),
                const _Reveal(child: GrEyebrow('Vendor')),
                const SizedBox(height: 12),
                const _Reveal(
                  delay: Duration(milliseconds: 80),
                  child: GrHeadline(
                    'Add a',
                    muted: 'listing',
                    trailing: '.',
                    mutedColor: AppTheme.accent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),
                _Reveal(
                  delay: const Duration(milliseconds: 160),
                  child: _categoryPicker(),
                ),
                const SizedBox(height: 28),
                _Reveal(
                  delay: const Duration(milliseconds: 240),
                  child: _methodPicker(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: _ease,
                  child: _aiNote == null
                      ? const SizedBox(width: double.infinity)
                      : _aiBanner(),
                ),
                const SizedBox(height: 32),
                KeyedSubtree(
                  key: _formTop,
                  child: const GrSectionLabel('Photos'),
                ),
                const SizedBox(height: 12),
                FlashOnFill(
                  controller: _flash,
                  fieldKey: 'images',
                  child: _photoGrid(),
                ),
                if (_photoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _photoError!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                const GrSectionLabel('Basic information'),
                const SizedBox(height: 16),
                ..._basicFields(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: _ease,
                  alignment: Alignment.topCenter,
                  child: _isVehicle
                      ? Column(children: _vehicleFields())
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 32),
                GrSectionLabel(
                  _isVehicle ? 'Additional details' : 'Part details',
                  trailing: GestureDetector(
                    onTap: () => setState(() => _specs.add(_SpecRow())),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ADD',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ..._specFields(),
                const SizedBox(height: 32),
                const GrSectionLabel('Inventory'),
                const SizedBox(height: 16),
                ..._inventoryFields(),
                const SizedBox(height: 36),
                GrPrimaryButton(
                  label: 'Publish listing',
                  loading: _submitting,
                  loadingLabel: _submitStage,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryPicker() {
    Widget card(String id, IconData icon, String title, String sub) {
      final active = _category == id;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (active) return;
            HapticFeedback.selectionClick();
            setState(() => _category = id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: _ease,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? AppTheme.accent : AppTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: active ? AppTheme.accent : Colors.white54,
                  size: 26,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    color: AppTheme.textSubtle,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          'vehicle',
          Icons.directions_car_outlined,
          'Vehicle',
          'Car or motorcycle',
        ),
        const SizedBox(width: 12),
        card('part', Icons.build_outlined, 'Part', 'Parts and accessories'),
      ],
    );
  }

  Widget _methodPicker() {
    Widget card(
      IconData icon,
      String title,
      String sub,
      VoidCallback onTap, {
      bool ai = false,
    }) {
      return Expanded(
        child: _PressScale(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              color: ai
                  ? AppTheme.accent.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ai
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ai ? AppTheme.accent : Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ai ? AppTheme.accent : AppTheme.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: ai ? Colors.black : Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSubtle,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GrSectionLabel('How would you like to add it?'),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(Icons.edit_outlined, 'Type it', 'Smart suggestions', () {
                final ctx = _formTop.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    duration: const Duration(milliseconds: 600),
                    curve: _ease,
                  );
                }
              }),
              const SizedBox(width: 10),
              card(
                Icons.document_scanner_outlined,
                'Scan photos',
                _isVehicle ? 'Car, VIN, papers' : 'Part, box, label',
                () => _openAssist(AssistMode.scan),
                ai: true,
              ),
              const SizedBox(width: 10),
              card(
                Icons.mic_none,
                'Speak it',
                'Describe it out loud',
                () => _openAssist(AssistMode.voice),
                ai: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aiBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _aiNote!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _aiNote = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoGrid() {
    Widget addTile(IconData icon, String label, ImageSource source) => InkWell(
      onTap: () => _addPhotos(source),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: _photoError != null ? AppTheme.danger : AppTheme.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accent, size: 22),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < _photos.length; i++)
          _PhotoThumb(
            key: ValueKey(_photos[i].path),
            file: _photos[i],
            cover: i == 0,
            onRemove: () => setState(() => _photos.removeAt(i)),
          ),
        if (_photos.length < _maxPhotos) ...[
          addTile(Icons.photo_camera_outlined, 'Camera', ImageSource.camera),
          addTile(Icons.photo_library_outlined, 'Gallery', ImageSource.gallery),
        ],
      ],
    );
  }

  Widget _field(
    String key,
    String label,
    Widget input, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingLabel(label, required: required),
          FlashOnFill(controller: _flash, fieldKey: key, child: input),
        ],
      ),
    );
  }

  Widget _text(
    String key,
    String hint, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: _c[key],
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 4 : 1,
      inputFormatters: formatters,
      textCapitalization: caps,
      cursorColor: AppTheme.accent,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
      decoration: listingInputDecoration(hint),
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  List<Widget> _basicFields() => [
    _field(
      'make',
      _isVehicle ? 'Make' : 'Brand',
      GrAutocompleteField(
        controller: _c['make']!,
        hint: _isVehicle
            ? 'Start typing, e.g. Toyota'
            : 'Start typing, e.g. Bosch',
        options: () => _isVehicle
            ? ListingCatalog.current.vehicleMakes
            : ListingCatalog.current.partBrands,
        validator: _required,
        onChanged: (_) => setState(() {}),
      ),
      required: true,
    ),
    _field(
      'name',
      _isVehicle ? 'Listing name' : 'Part name',
      GrAutocompleteField(
        controller: _c['name']!,
        hint: _isVehicle ? 'e.g. 2019 Toyota Camry XSE' : 'e.g. Brake Pads',
        options: () =>
            nameOptionsFor(_category, _c['make']!.text, _c['year']!.text),
        emptyHint: _isVehicle ? 'Choose a make first to see models' : null,
        validator: _required,
      ),
      required: true,
    ),
    _field(
      'price',
      'Price',
      _text(
        'price',
        'e.g. ₦18,000,000',
        validator: _required,
        keyboardType: TextInputType.text,
      ),
      required: true,
    ),
    _field(
      'description',
      'Description',
      _text(
        'description',
        'Describe the condition, history and highlights…',
        maxLines: 6,
      ),
    ),
  ];

  List<Widget> _vehicleFields() => [
    _pair(
      _field(
        'year',
        'Year',
        GrAutocompleteField(
          controller: _c['year']!,
          hint: 'e.g. 2019',
          options: () => yearOptions,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
      ),
      _field('mileage', 'Mileage', _text('mileage', 'e.g. 45,000 km')),
    ),
    _field(
      'colorName',
      'Colour',
      GrAutocompleteField(
        controller: _c['colorName']!,
        hint: 'e.g. Midnight Black',
        options: () => [for (final c in ListingCatalog.current.colors) c.name],
        swatchFor: (name) {
          final c = colorNamed(name);
          return c == null ? null : Color(c.hex);
        },
        onChanged: (v) {
          final c = colorNamed(v);
          if (c != null) setState(() => _colorSwatch = Color(c.hex));
        },
      ),
    ),
    _pair(
      _field(
        'transmission',
        'Transmission',
        GrAutocompleteField(
          controller: _c['transmission']!,
          hint: 'e.g. Automatic',
          options: () => ListingCatalog.current.transmissions,
          validator: _isVehicle ? _required : null,
        ),
        required: true,
      ),
      _field(
        'origin',
        'Condition',
        GrAutocompleteField(
          controller: _c['origin']!,
          hint: 'e.g. Foreign Used',
          options: () => ListingCatalog.current.conditions,
          validator: _isVehicle ? _required : null,
        ),
        required: true,
      ),
    ),
    _field(
      'vin',
      'VIN',
      _text(
        'vin',
        '17-character VIN',
        caps: TextCapitalization.characters,
        formatters: [
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(17),
          TextInputFormatter.withFunction(
            (_, v) => v.copyWith(text: v.text.toUpperCase()),
          ),
        ],
        validator: _isVehicle
            ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : v.trim().length != 17
                  ? 'A VIN has 17 characters'
                  : null
            : null,
      ),
      required: true,
    ),
    _pair(
      _field(
        'horsepower',
        'Horsepower',
        _text('horsepower', 'e.g. 301', keyboardType: TextInputType.number),
      ),
      _field('torque', 'Torque', _text('torque', 'e.g. 362 Nm')),
    ),
    _pair(
      _field('topSpeed', 'Top speed', _text('topSpeed', 'e.g. 220 km/h')),
      _field(
        'acceleration',
        '0-100 km/h (s)',
        _text(
          'acceleration',
          'e.g. 5.8',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
    ),
  ];

  List<Widget> _specFields() => [
    for (final s in _specs)
      TweenAnimationBuilder<double>(
        key: ObjectKey(s),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: _ease,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - t)),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GrAutocompleteField(
                  controller: s.key,
                  hint: _isVehicle ? 'e.g. Fuel Type' : 'e.g. Compatibility',
                  options: () => specKeysFor(_category),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FlashOnFill(
                  controller: _flash,
                  fieldKey: 'spec:${s.key.text.trim()}',
                  child: GrAutocompleteField(
                    controller: s.value,
                    hint: _isVehicle ? 'e.g. Petrol' : 'e.g. Camry 2018-22',
                    options: () => specValuesFor(_category, s.key.text),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _specs.remove(s);
                  s.dispose();
                }),
                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in specKeysFor(_category))
          if (!_specs.any(
            (s) => s.key.text.trim().toLowerCase() == k.toLowerCase(),
          ))
            ActionChip(
              onPressed: () => setState(() => _specs.add(_SpecRow(k))),
              label: Text('+ ${k.toUpperCase()}'),
              labelStyle: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              side: BorderSide(color: AppTheme.border),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
      ],
    ),
  ];

  List<Widget> _inventoryFields() => [
    _pair(
      _field(
        'stockQuantity',
        'Stock quantity',
        _text(
          'stockQuantity',
          '1',
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListingLabel('Availability'),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _inStock = !_inStock);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: (_inStock ? AppTheme.accent : AppTheme.danger)
                      .withValues(alpha: 0.1),
                  border: Border.all(
                    color: _inStock ? AppTheme.accent : AppTheme.danger,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _inStock ? 'In stock' : 'Out of stock',
                    key: ValueKey(_inStock),
                    style: TextStyle(
                      color: _inStock ? AppTheme.accent : AppTheme.danger,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}

class _PhotoThumb extends StatelessWidget {
  final XFile file;
  final bool cover;
  final VoidCallback onRemove;
  const _PhotoThumb({
    super.key,
    required this.file,
    required this.cover,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: _ease,
      builder: (_, s, child) => Transform.scale(
        scale: s,
        child: Opacity(opacity: ((s - 0.85) / 0.15).clamp(0, 1), child: child),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (_, snap) => snap.hasData
                  ? Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Container(color: Colors.white10),
            ),
            if (cover)
              const Positioned(
                left: 6,
                bottom: 6,
                child: GrPill('Cover', filled: true),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shrinks slightly while pressed.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides its child in once, after [delay].
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _Reveal({required this.child, this.delay = Duration.zero});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: _ease);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) return;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
