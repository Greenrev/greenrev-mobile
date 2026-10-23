import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';

class _ExpertMessage {
  final String id;
  final String expertName;
  final String expertEmail;
  final String? expertImage;
  final String message;
  final String? reply;
  final DateTime? replyDate;
  final String status;
  final DateTime? createdAt;

  _ExpertMessage.fromJson(Map<String, dynamic> json)
      : id = json['_id']?.toString() ?? '',
        expertName = (json['expertId'] is Map ? json['expertId']['name'] : null) ?? 'Unknown Expert',
        expertEmail = (json['expertId'] is Map ? json['expertId']['email'] : null) ?? '',
        expertImage = json['expertId'] is Map ? json['expertId']['profileImage'] as String? : null,
        message = json['message']?.toString() ?? '',
        reply = json['reply'] as String?,
        replyDate = DateTime.tryParse(json['replyDate']?.toString() ?? ''),
        status = json['status']?.toString() ?? '',
        createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');

  bool get isAnswered => status == 'REPLIED';
}

/// "My Messages" — conversation history with GreenRev experts (web: /messages).
class MessagesScreen extends StatefulWidget {
  /// Called when the user taps "Browse Experts" from the empty state.
  final VoidCallback? onBrowseExperts;
  const MessagesScreen({super.key, this.onBrowseExperts});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<_ExpertMessage> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient().get('/api/v1/profile/messages');
      final list = (data is Map ? data['messages'] : null) as List? ?? const [];
      _messages = list.whereType<Map<String, dynamic>>().map(_ExpertMessage.fromJson).toList();
    } catch (e) {
      _error = e is ApiException ? e.message : 'Failed to load messages';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.cardBg,
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: [
              const Align(alignment: Alignment.centerLeft, child: GrBackLink()),
              const SizedBox(height: 28),
              const GrPageHeader(
                title: 'My Messages',
                subtitle: 'View your conversation history with GreenRev experts.',
                size: 40,
              ),
              const SizedBox(height: 32),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
                )
              else if (_error != null)
                GrNotice(_error!)
              else if (_messages.isEmpty)
                GrCard(
                  child: GrEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message:
                        "You haven't contacted any experts yet. Browse our directory to find the perfect mechanic for your needs.",
                    actionLabel: widget.onBrowseExperts != null ? 'Browse Experts' : null,
                    onAction: widget.onBrowseExperts == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onBrowseExperts!();
                          },
                  ),
                )
              else
                for (final m in _messages) ...[
                  _MessageCard(message: m),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final _ExpertMessage message;
  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final initials = message.expertName.length >= 2 ? message.expertName.substring(0, 2).toUpperCase() : 'EX';
    return GrCard(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: message.expertImage != null && message.expertImage!.isNotEmpty
                    ? Image(image: safeImageProvider(message.expertImage!), fit: BoxFit.cover)
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.expertName, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    if (message.expertEmail.isNotEmpty)
                      Text(message.expertEmail, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GrPill(
                    message.isAnswered ? 'Answered' : 'Awaiting Reply',
                    color: message.isAnswered ? AppTheme.accent : Colors.white54,
                  ),
                  const SizedBox(height: 4),
                  Text(grDate(message.createdAt), style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrSectionLabel('You asked:'),
                const SizedBox(height: 8),
                Text(message.message, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          if (message.isAnswered && (message.reply?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppTheme.accent, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrEyebrow('Expert Reply:'),
                  const SizedBox(height: 8),
                  Text(message.reply!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
                  if (message.replyDate != null) ...[
                    const SizedBox(height: 6),
                    Text('Replied on ${grDate(message.replyDate)}',
                        style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
