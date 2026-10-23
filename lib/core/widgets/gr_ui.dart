import 'package:flutter/material.dart';
import '../theme/theme.dart';

export '../utils/format.dart';

/// Building blocks that reproduce the website's visual language
/// (eyebrow labels, period-terminated display headlines, underline inputs,
/// white pill CTAs, hairline glass cards).

/// Small accent micro-label shown above headlines — web: text-[10px] uppercase tracking-[0.4em].
class GrEyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const GrEyebrow(this.text, {super.key, this.color = AppTheme.accent});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 3.2,
      ),
    );
  }
}

/// Display headline, optionally followed by a muted italic phrase — web: "Quality <i>In Every</i> Interaction."
class GrHeadline extends StatelessWidget {
  final String title;
  final String? muted;
  final String? trailing;
  final double size;
  final TextAlign textAlign;
  final Color? mutedColor;

  const GrHeadline(
    this.title, {
    super.key,
    this.muted,
    this.trailing,
    this.mutedColor,
    this.size = 44,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: size,
      height: 1.0,
      color: Colors.white,
      letterSpacing: -0.5,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: title),
          if (muted != null)
            TextSpan(
              text: ' $muted',
              style: TextStyle(
                color: mutedColor ?? Colors.white.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          if (trailing != null)
            TextSpan(text: RegExp(r'^[.,!?]').hasMatch(trailing!) ? trailing : ' $trailing'),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Eyebrow + headline + supporting line, the standard top-of-page block on the website.
class GrPageHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? muted;
  final String? subtitle;
  final double size;
  final CrossAxisAlignment alignment;
  final Color? mutedColor;

  const GrPageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.muted,
    this.mutedColor,
    this.subtitle,
    this.size = 44,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final centered = alignment == CrossAxisAlignment.center;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (eyebrow != null) ...[
          GrEyebrow(eyebrow!),
          const SizedBox(height: 14),
        ],
        GrHeadline(
          title,
          muted: muted,
          mutedColor: mutedColor,
          size: size,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 14),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// Underline input with a leading icon that lights up on focus.
class GrTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  const GrTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<GrTextField> createState() => _GrTextFieldState();
}

class _GrTextFieldState extends State<GrTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      cursorColor: AppTheme.accent,
      style: const TextStyle(color: Colors.white, fontSize: 17),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: widget.icon != null ? Icon(widget.icon, size: 18) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Boxed multi-line input — web: bg-white/5 border-white/10 rounded-2xl textarea.
class GrTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final String? Function(String?)? validator;

  const GrTextArea({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 4,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines + 4,
      validator: validator,
      cursorColor: AppTheme.accent,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.all(18),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
        ),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppTheme.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppTheme.danger)),
      ),
    );
  }
}

/// Primary CTA — white pill with an uppercase micro-label and trailing chevron.
class GrPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;
  final IconData? icon;
  final bool accent;

  const GrPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon = Icons.chevron_right,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: accent
            ? ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.disabled) ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.accent),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading && loadingLabel == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            else
              Text((loading ? loadingLabel! : label).toUpperCase()),
            if (!loading && icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Secondary CTA — hairline outlined pill.
class GrSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const GrSecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: color != null
            ? OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color!.withValues(alpha: 0.3)),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 10),
            ],
            Text(label.toUpperCase()),
          ],
        ),
      ),
    );
  }
}

enum GrNoticeKind { error, success, info }

/// Inline status banner — web: text-[11px] bg-red-500/10 border-red-500/20 rounded-xl.
class GrNotice extends StatelessWidget {
  final String message;
  final GrNoticeKind kind;
  const GrNotice(this.message, {super.key, this.kind = GrNoticeKind.error});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      GrNoticeKind.error => AppTheme.danger,
      GrNoticeKind.success => AppTheme.accent,
      GrNoticeKind.info => Colors.white,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
      ),
    );
  }
}

/// Hairline glass card — web: bg-white/[0.02] border-white/5 rounded-3xl.
class GrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

/// Divider with a centered micro-label — web: "New Here?" rule.
class GrDividerLabel extends StatelessWidget {
  final String label;
  const GrDividerLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: AppTheme.hairline));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Uppercase section label used above lists and form groups.
class GrSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const GrSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.4,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// "← Home" style back link.
class GrBackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const GrBackLink({super.key, this.label = 'Back', this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 13, color: AppTheme.textSubtle),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppTheme.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill tag — status, category, role.
class GrPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const GrPill(this.text, {super.key, this.color = AppTheme.accent, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: filled ? Colors.black : color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// Centered empty / signed-out state.
class GrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GrEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: Colors.white38, size: 26),
            ),
            const SizedBox(height: 24),
            GrHeadline(title, size: 28, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              GrPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Floating snackbar in the site's tone; [error] tints it red.
void showGrSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: error ? AppTheme.danger : AppTheme.accent,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Simple top bar used by pushed screens: back link on the left, optional actions on the right.
class GrTopBar extends StatelessWidget {
  final String backLabel;
  final List<Widget> actions;
  const GrTopBar({super.key, this.backLabel = 'Back', this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GrBackLink(label: backLabel),
        const Spacer(),
        ...actions,
      ],
    );
  }
}
