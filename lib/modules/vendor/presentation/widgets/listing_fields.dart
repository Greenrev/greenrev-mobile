import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';
import '../../data/listing_service.dart';

const _ease = Cubic(0.16, 1, 0.3, 1);

InputDecoration listingInputDecoration(String hint, {Widget? suffix}) {
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.25),
      fontSize: 15,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.accent),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.danger),
    ),
    errorStyle: const TextStyle(color: AppTheme.danger, fontSize: 11),
  );
}

/// Tells [FlashOnFill] widgets which fields were just filled by the AI.
class FlashController extends ChangeNotifier {
  List<String> _keys = const [];
  List<String> get keys => _keys;

  void flash(Iterable<String> keys) {
    _keys = keys.toList();
    notifyListeners();
  }
}

/// Glows its child in the accent colour when its [fieldKey] is flashed.
class FlashOnFill extends StatefulWidget {
  final FlashController controller;
  final String fieldKey;
  final Widget child;
  const FlashOnFill({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.child,
  });

  @override
  State<FlashOnFill> createState() => _FlashOnFillState();
}

class _FlashOnFillState extends State<FlashOnFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    widget.controller.addListener(_onFlash);
  }

  @override
  void didUpdateWidget(FlashOnFill old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onFlash);
      widget.controller.addListener(_onFlash);
    }
  }

  void _onFlash() {
    final i = widget.controller.keys.indexOf(widget.fieldKey.toLowerCase());
    if (i < 0 || MediaQuery.of(context).disableAnimations) return;
    Future.delayed(Duration(milliseconds: 60 * i.clamp(0, 12)), () {
      if (mounted) _anim.forward(from: 0);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFlash);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (context, child) {
        // Rise fast, fade slowly.
        final t = _anim.value;
        final glow = t < 0.2
            ? t / 0.2
            : 1 - Curves.easeOut.transform((t - 0.2) / 0.8);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (glow > 0) ...[
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.7 * glow),
                  spreadRadius: 1.5,
                ),
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.25 * glow),
                  blurRadius: 24,
                ),
              ],
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Uppercase label above a field, with an optional required marker.
class ListingLabel extends StatelessWidget {
  final String text;
  final bool required;
  const ListingLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${text.toUpperCase()}${required ? ' *' : ''}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Text field with a live suggestions dropdown. Free text is always allowed.
class GrAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<String> Function() options;
  final ValueChanged<String>? onSelected;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// Colour swatch shown beside an option, if any.
  final Color? Function(String option)? swatchFor;

  /// Shown when focused with an empty field and no options.
  final String? emptyHint;

  const GrAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.options,
    this.onSelected,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
    this.swatchFor,
    this.emptyHint,
  });

  @override
  State<GrAutocompleteField> createState() => _GrAutocompleteFieldState();
}

class _GrAutocompleteFieldState extends State<GrAutocompleteField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (value) {
          final all = widget.options();
          if (all.isEmpty && widget.emptyHint != null && value.text.isEmpty) {
            return [''];
          }
          return rankOptions(all, value.text);
        },
        onSelected: (v) {
          if (v.isEmpty) return; // the empty-hint row
          HapticFeedback.selectionClick();
          widget.onSelected?.call(v);
          widget.onChanged?.call(v);
          _focus.unfocus();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              validator: widget.validator,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              onFieldSubmitted: (_) => onSubmit(),
              cursorColor: AppTheme.accent,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: listingInputDecoration(
                widget.hint,
                suffix: AnimatedRotation(
                  turns: _focus.hasFocus ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: _focus.hasFocus ? AppTheme.accent : Colors.white30,
                  ),
                ),
              ),
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: _OptionsList(
            width: constraints.maxWidth,
            query: widget.controller.text,
            options: options.toList(),
            onSelected: onSelected,
            swatchFor: widget.swatchFor,
            emptyHint: widget.emptyHint,
          ),
        ),
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  final double width;
  final String query;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final Color? Function(String)? swatchFor;
  final String? emptyHint;

  const _OptionsList({
    required this.width,
    required this.query,
    required this.options,
    required this.onSelected,
    this.swatchFor,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: _ease,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -6 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxHeight: 248),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1010),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final o = options[i];
              if (o.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    emptyHint ?? '',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                );
              }
              final active = i == highlighted;
              final swatch = swatchFor?.call(o);
              return InkWell(
                onTap: () => onSelected(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: active ? AppTheme.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (swatch != null) ...[
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _Match(text: o, query: query),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Match extends StatelessWidget {
  final String text;
  final String query;
  const _Match({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Colors.white70, fontSize: 14);
    final q = query.trim().toLowerCase();
    final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
    if (i < 0) return Text(text, style: base, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + q.length),
            style: const TextStyle(color: AppTheme.accent),
          ),
          TextSpan(text: text.substring(i + q.length)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
