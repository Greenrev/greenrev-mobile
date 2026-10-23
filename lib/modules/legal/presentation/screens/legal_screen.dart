import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../data/legal_content.dart';

/// Renders the Terms of Use / Privacy Policy with the same wording as the website.
class LegalScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  static Route<void> route(LegalDocument document) =>
      MaterialPageRoute(builder: (_) => LegalScreen(document: document));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GrBackLink(),
                    const SizedBox(height: 32),
                    const GrEyebrow('GreenRev'),
                    const SizedBox(height: 14),
                    GrHeadline(document.title, size: 40),
                    const SizedBox(height: 16),
                    for (final line in document.meta)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(line, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              sliver: SliverList.builder(
                itemCount: document.blocks.length,
                itemBuilder: (context, i) => _LegalBlockView(document.blocks[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  final LegalBlock block;
  const _LegalBlockView(this.block);

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case LegalBlockType.heading:
        return Container(
          margin: const EdgeInsets.only(top: 32, bottom: 14),
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Text(block.text, style: const TextStyle(color: Colors.white, fontSize: 21, height: 1.2)),
        );
      case LegalBlockType.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(block.text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        );
      case LegalBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 8, right: 12),
                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              ),
              Expanded(child: Text(block.text, style: _body)),
            ],
          ),
        );
      case LegalBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(block.text, style: _body),
        );
    }
  }

  static const _body = TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.6);
}
