import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/concierge_service.dart';
import '../../../core/theme/theme.dart';

/// AI concierge chat — mobile counterpart of the website's CompareAIChat.
/// Opened from Home (general) and Compare (with the vehicles being compared).
class ConciergeSheet extends StatefulWidget {
  final List<ProductModel> compareItems;
  const ConciergeSheet({super.key, this.compareItems = const []});

  static Future<void> show(BuildContext context, {List<ProductModel> compareItems = const []}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConciergeSheet(compareItems: compareItems),
    );
  }

  @override
  State<ConciergeSheet> createState() => _ConciergeSheetState();
}

class _LocalMessage {
  final String role;
  final String content;
  final bool isError;
  const _LocalMessage(this.role, this.content, {this.isError = false});
}

class _ConciergeSheetState extends State<ConciergeSheet> {
  static const _errorText = "I'm having trouble responding right now. Please try again in a moment.";

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_LocalMessage> _messages = [];
  final List<ConciergeMessage> _history = [];
  String _streaming = '';
  bool _thinking = false;

  bool get _isCompare => widget.compareItems.isNotEmpty;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _clear() {
    if (_thinking) return;
    setState(() {
      _messages.clear();
      _history.clear();
      _streaming = '';
    });
  }

  List<Map<String, dynamic>> get _compareData => [
        for (final c in widget.compareItems)
          {
            'name': c.name,
            'make': c.make,
            'price': c.priceValue,
            'specs': {
              'horsepower': c.specs?.horsepower,
              'topSpeed': c.specs?.topSpeed,
              '0_100': c.specs?.acceleration,
              'torque': c.specs?.torque,
            },
          },
      ];

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();

    setState(() {
      _messages.add(_LocalMessage('user', text));
      _history.add(ConciergeMessage('user', text));
      _thinking = true;
      _streaming = '';
    });
    _scrollToEnd();

    try {
      var full = '';
      await for (final partial in ConciergeService().ask(_history, compareData: _compareData)) {
        full = partial;
        if (!mounted) return;
        setState(() => _streaming = partial);
        _scrollToEnd();
      }
      final reply = full.trim();
      if (!mounted) return;
      setState(() {
        if (reply.isEmpty) {
          _messages.add(const _LocalMessage('assistant', _errorText, isError: true));
          _history.removeLast();
        } else {
          _messages.add(_LocalMessage('assistant', reply));
          _history.add(ConciergeMessage('assistant', reply));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _LocalMessage('assistant', _errorText, isError: true));
        // Drop the failed user turn so it isn't re-sent.
        _history.removeLast();
      });
    } finally {
      if (mounted) {
        setState(() {
          _thinking = false;
          _streaming = '';
        });
        _scrollToEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessages()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: AppTheme.hairline)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.smart_toy_outlined, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCompare ? 'Compare Concierge' : 'GreenRev Concierge',
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI EXPERT ADVICE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear Chat',
                onPressed: _clear,
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.white.withValues(alpha: 0.4)),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty && !_thinking) {
      return Center(
        child: Opacity(
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 30),
                const SizedBox(height: 16),
                Text(
                  _isCompare ? 'Ask about these machines' : 'Ask the concierge',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  _isCompare
                      ? 'I can analyze their specs and help you decide.'
                      : 'Ask about vehicles in the showroom, parts, or expert care.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final showThinking = _thinking && _streaming.isEmpty;
    final extra = (_streaming.isNotEmpty ? 1 : 0) + (showThinking ? 1 : 0);

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + extra,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        if (i < _messages.length) {
          final m = _messages[i];
          return _Bubble(role: m.role, content: m.content, isError: m.isError);
        }
        if (_streaming.isNotEmpty) return _Bubble(role: 'assistant', content: _streaming);
        return const _ThinkingBubble();
      },
    );
  }

  Widget _buildInput() {
    final placeholder = widget.compareItems.length == 2
        ? 'Ask about the ${widget.compareItems[0].name} vs ${widget.compareItems[1].name}...'
        : 'Ask me about any vehicle...';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(top: BorderSide(color: AppTheme.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              cursorColor: AppTheme.accent,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: _input,
            builder: (context, _) {
              final enabled = !_thinking && _input.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: enabled ? _send : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: enabled ? 1 : 0.4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                    child: _thinking
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String role;
  final String content;
  final bool isError;
  const _Bubble({required this.role, required this.content, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    final avatar = Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isUser ? Colors.white.withValues(alpha: 0.1) : AppTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.smart_toy_outlined,
        size: 16,
        color: isUser ? Colors.white : AppTheme.accent,
      ),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.accent
            : isError
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
        border: isError ? Border.all(color: Colors.red.withValues(alpha: 0.2)) : null,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 18 : 0),
          topRight: Radius.circular(isUser ? 0 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
      child: isUser
          ? Text(content, style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.45))
          : isError
              ? Text(content, style: TextStyle(color: Colors.red.shade200, fontSize: 14, height: 1.45))
              : _MiniMarkdown(content),
    );

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isUser
          ? [bubble, const SizedBox(width: 10), avatar]
          : [avatar, const SizedBox(width: 10), bubble],
    );
  }
}

/// Same subset as the web MarkdownRenderer: **bold** (accent) and "* "/"- " bullets.
class _MiniMarkdown extends StatelessWidget {
  final String content;
  const _MiniMarkdown(this.content);

  List<TextSpan> _inline(String text) {
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(\*\*.*?\*\*)'));
    final matches = RegExp(r'\*\*(.*?)\*\*').allMatches(text).toList();
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < matches.length) {
        spans.add(TextSpan(
          text: matches[i].group(1),
          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, height: 1.5);
    final children = <Widget>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (i > 0) children.add(const SizedBox(height: 6));
        continue;
      }
      final isBullet = trimmed.startsWith('* ') || trimmed.startsWith('- ');
      if (isBullet) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8, right: 10),
                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              ),
              Expanded(child: Text.rich(TextSpan(style: style, children: _inline(trimmed.substring(2))))),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(TextSpan(style: style, children: _inline(line))),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.smart_toy_outlined, size: 16, color: AppTheme.accent),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Opacity(
                    opacity: 0.4 + 0.6 * (1 - ((_controller.value * 3 - i) % 3 - 0.5).abs().clamp(0, 1)),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
