import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../legal/data/legal_content.dart';
import '../../../legal/presentation/screens/legal_screen.dart';
import '../../data/faq_content.dart';

const _supportEmail = 'support@greenrevs.com';
const _ease = Cubic(0.16, 1, 0.3, 1);

/// Help centre — same questions and answers as the website's /faq page.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const FaqScreen());

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _headerKey = GlobalKey();
  final Set<String> _open = {};
  String _query = '';
  String? _category;

  static final _total = faqCategories.fold<int>(0, (n, c) => n + c.items.length);

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  List<FaqCategory> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final c in faqCategories)
        if (_category == null || c.id == _category)
          FaqCategory(c.id, c.label, [
            for (final i in c.items)
              if (q.isEmpty || i.question.toLowerCase().contains(q) || i.answer.toLowerCase().contains(q)) i,
          ]),
    ].where((c) => c.items.isNotEmpty).toList();
  }

  /// Keeps the list start in view when the filter changes while scrolled deep.
  void _jumpToListStart() {
    final header = _headerKey.currentContext?.size?.height;
    if (header == null || !_scroll.hasClients || _scroll.offset <= header) return;
    _scroll.animateTo(header, duration: const Duration(milliseconds: 600), curve: _ease);
  }

  void _pickCategory(String? id) {
    HapticFeedback.selectionClick();
    setState(() => _category = id);
    _jumpToListStart();
  }

  void _toggle(String id) {
    HapticFeedback.lightImpact();
    setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));
  }

  void _reset() {
    _search.clear();
    setState(() {
      _query = '';
      _category = null;
    });
  }

  Future<void> _emailSupport() async {
    final ok = await launchUrl(Uri(scheme: 'mailto', path: _supportEmail));
    if (!ok && mounted) showGrSnack(context, 'No email app found. Write to $_supportEmail', error: true);
  }

  Future<void> _copyLink(FaqEntry item) async {
    await Clipboard.setData(ClipboardData(text: '${Env.siteBaseUrl}/faq#${item.id}'));
    if (mounted) showGrSnack(context, 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final count = visible.fold<int>(0, (n, c) => n + c.items.length);
    final allOpen = count > 0 && visible.every((c) => c.items.every((i) => _open.contains(i.id)));
    // Changing the filter re-keys the rows so they replay their entrance.
    final filterKey = '${_category ?? 'all'}|${_query.trim().toLowerCase()}';

    final rows = <Widget>[];
    for (final c in visible) {
      final number = faqCategories.indexWhere((x) => x.id == c.id) + 1;
      rows.add(_Reveal(
        key: ValueKey('$filterKey-h-${c.id}'),
        delay: Duration.zero,
        offset: const Offset(-0.08, 0),
        child: _CategoryHeading(number: number, label: c.label),
      ));
      for (var i = 0; i < c.items.length; i++) {
        final item = c.items[i];
        rows.add(_Reveal(
          key: ValueKey('$filterKey-${item.id}'),
          delay: Duration(milliseconds: 40 * math.min(i, 6)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FaqTile(
              item: item,
              query: _query,
              open: _open.contains(item.id),
              onToggle: () => _toggle(item.id),
              onCopyLink: () => _copyLink(item),
            ),
          ),
        ));
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _headerKey,
                  child: _Header(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _RailDelegate(
                  selected: _category,
                  onSelect: _pickCategory,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(child: _ResultCount(count: count, query: _query.trim())),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: count == 0
                            ? const SizedBox.shrink()
                            : TextButton(
                                key: ValueKey(allOpen),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (allOpen) {
                                      _open.clear();
                                    } else {
                                      _open.addAll(visible.expand((c) => c.items.map((i) => i.id)));
                                    }
                                  });
                                },
                                child: Text(allOpen ? 'COLLAPSE ALL' : 'EXPAND ALL'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (count == 0)
                SliverToBoxAdapter(
                  child: _Reveal(
                    key: ValueKey('$filterKey-empty'),
                    child: GrEmptyState(
                      icon: Icons.search_off,
                      title: 'No answers found',
                      message: 'Try a different word, choose another topic, or ask our support team directly.',
                      actionLabel: 'Reset search',
                      onAction: _reset,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  sliver: SliverList.list(children: rows),
                ),
              SliverToBoxAdapter(
                child: _SupportBlock(onEmail: _emailSupport),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _Header({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ambient accent glow behind the headline.
        Positioned(
          top: -80,
          right: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.accent.withValues(alpha: 0.14), AppTheme.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GrBackLink(),
              const SizedBox(height: 32),
              const _Reveal(child: GrEyebrow('Help Centre')),
              const SizedBox(height: 14),
              const _Reveal(
                delay: Duration(milliseconds: 100),
                offset: Offset(0, 0.3),
                child: GrHeadline('Questions,', muted: 'answered.', mutedColor: AppTheme.accent, size: 44),
              ),
              const SizedBox(height: 16),
              const _Reveal(
                delay: Duration(milliseconds: 200),
                child: Text(
                  'Everything about finding cars, parts and mechanics on GreenRev, selling as a business, staying safe and getting help when something goes wrong.',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.55),
                ),
              ),
              const SizedBox(height: 28),
              _Reveal(
                delay: const Duration(milliseconds: 300),
                child: _SearchField(controller: controller, onChanged: onChanged),
              ),
              const SizedBox(height: 24),
              _Reveal(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    _Stat(value: _FaqScreenState._total, label: 'Answers'),
                    const SizedBox(width: 36),
                    _Stat(value: faqCategories.length, label: 'Topics'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counts up from zero on first build.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 1400),
          curve: _ease,
          builder: (_, v, _) => Text(
            v.round().toString(),
            style: const TextStyle(color: Colors.white, fontSize: 28, height: 1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
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
    final focused = _focus.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 56,
      decoration: BoxDecoration(
        color: Color.alphaBlend(Colors.white.withValues(alpha: focused ? 0.05 : 0.03), AppTheme.background),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border,
        ),
        boxShadow: [
          if (focused) BoxShadow(color: AppTheme.accent.withValues(alpha: 0.12), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.search,
              key: ValueKey(focused),
              size: 20,
              color: focused ? AppTheme.accent : Colors.white38,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Search payments, refunds…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
              ),
            ),
          ),
          AnimatedScale(
            scale: hasText ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                widget.controller.clear();
                setState(() {});
                widget.onChanged('');
              },
              icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category rail (pinned)
// ---------------------------------------------------------------------------

class _RailDelegate extends SliverPersistentHeaderDelegate {
  final String? selected;
  final ValueChanged<String?> onSelect;
  _RailDelegate({required this.selected, required this.onSelect});

  static const _height = 64.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: overlapsContent ? 0.96 : 1),
        border: Border(
          bottom: BorderSide(color: overlapsContent ? AppTheme.border : AppTheme.hairline),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        children: [
          _Chip(label: 'All', active: selected == null, onTap: () => onSelect(null)),
          for (final c in faqCategories)
            _Chip(label: c.label, active: selected == c.id, onTap: () => onSelect(c.id)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_RailDelegate old) => old.selected != selected || old.onSelect != onSelect;
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 400),
            curve: _ease,
          );
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: _ease,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: active ? Colors.black : Colors.white60,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

class _ResultCount extends StatelessWidget {
  final int count;
  final String query;
  const _ResultCount({required this.count, required this.query});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The number rolls up/down when it changes.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ClipRect(
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.8), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
          ),
          child: Text(
            '$count',
            key: ValueKey(count),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
              children: [
                TextSpan(text: count == 1 ? ' answer' : ' answers'),
                if (query.isNotEmpty) ...[
                  const TextSpan(text: ' for '),
                  TextSpan(text: '“$query”', style: const TextStyle(color: AppTheme.accent)),
                ],
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  final int number;
  final String label;
  const _CategoryHeading({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            number.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // High flex so the label keeps its line and the rule takes what's left.
          Flexible(
            flex: 8,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.15)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: AppTheme.hairline)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqEntry item;
  final String query;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onCopyLink;

  const _FaqTile({
    required this.item,
    required this.query,
    required this.open,
    required this.onToggle,
    required this.onCopyLink,
  });

  static const _duration = Duration(milliseconds: 380);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _duration,
      curve: _ease,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: open ? 0.045 : 0.025),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: open ? AppTheme.border : AppTheme.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Accent rail grows down the left edge while open.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedScale(
                scale: open ? 1 : 0,
                alignment: Alignment.topCenter,
                duration: _duration,
                curve: _ease,
                child: Container(width: 2, color: AppTheme.accent),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: open,
                  child: InkWell(
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: _duration,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: open ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                fontSize: 15.5,
                                height: 1.35,
                              ),
                              child: _Highlighted(item.question, query),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _PlusMinus(open: open),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: _duration,
                  curve: _ease,
                  alignment: Alignment.topCenter,
                  child: open
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Reveal(
                                duration: _duration,
                                offset: const Offset(0, -0.1),
                                child: DefaultTextStyle.merge(
                                  style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.6),
                                  child: _Highlighted(item.answer, query),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: onCopyLink,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: Colors.white38,
                                ),
                                icon: const Icon(Icons.link, size: 14),
                                label: const Text('COPY LINK'),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Plus that folds into a minus: the vertical bar collapses as it spins.
class _PlusMinus extends StatelessWidget {
  final bool open;
  const _PlusMinus({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.black : Colors.white70;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: open ? AppTheme.accent : Colors.transparent,
        border: Border.all(color: open ? AppTheme.accent : AppTheme.border),
      ),
      child: AnimatedRotation(
        turns: open ? 0.5 : 0,
        duration: const Duration(milliseconds: 380),
        curve: _ease,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 13, height: 1.6, color: color),
            AnimatedScale(
              scale: open ? 0 : 1,
              duration: const Duration(milliseconds: 260),
              child: Container(width: 1.6, height: 13, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text with every case-insensitive match of [query] tinted in the accent colour.
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;
  const _Highlighted(this.text, this.query);

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Text(text);
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = lower.indexOf(q); i != -1; i = lower.indexOf(q, start)) {
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + q.length),
        style: TextStyle(color: AppTheme.accent, backgroundColor: AppTheme.accent.withValues(alpha: 0.15)),
      ));
      start = i + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(TextSpan(children: spans));
  }
}

// ---------------------------------------------------------------------------
// Support
// ---------------------------------------------------------------------------

class _SupportBlock extends StatelessWidget {
  final VoidCallback onEmail;
  const _SupportBlock({required this.onEmail});

  @override
  Widget build(BuildContext context) {
    final updated = DateTime.tryParse(faqUpdated);
    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: AppTheme.hairline)),
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.1,
          colors: [AppTheme.accent.withValues(alpha: 0.08), Colors.black],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const GrEyebrow('Still need help?'),
            const SizedBox(height: 14),
            const GrHeadline(
              'Talk to a',
              muted: 'human',
              trailing: '.',
              mutedColor: AppTheme.accent,
              size: 38,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            const Text(
              'Email us with the listing link, the email or phone number on your account and a short description of the issue. Never share your password, one-time codes or full card details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.55),
            ),
            const SizedBox(height: 28),
            GrPrimaryButton(label: 'Email support', icon: Icons.mail_outline, accent: true, onPressed: onEmail),
            const SizedBox(height: 10),
            const SelectableText(_supportEmail, style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(LegalScreen.route(termsOfUse)),
                  child: const Text('TERMS OF USE'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(LegalScreen.route(privacyPolicy)),
                  child: const Text('PRIVACY POLICY'),
                ),
              ],
            ),
            if (updated != null) ...[
              const SizedBox(height: 8),
              Text(
                'LAST UPDATED ${_formatDate(updated)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 1.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// Fades and slides its child in once, after [delay]. Skipped when the
/// platform asks for reduced motion.
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const _Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.offset = const Offset(0, 0.15),
  });

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: _ease);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) return;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
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
        position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
