import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';

/// "General Inquiry" form — same fields and wording as the website's Inquire Now modal.
class InquiryModalSheet extends StatefulWidget {
  final String? productId;
  final String? productName;
  final String? title;
  final String? initialMessage;

  const InquiryModalSheet({
    super.key,
    this.productId,
    this.productName,
    this.title,
    this.initialMessage,
  });

  static void show(
    BuildContext context, {
    String? productId,
    String? productName,
    String? title,
    String? initialMessage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InquiryModalSheet(
        productId: productId,
        productName: productName,
        title: title,
        initialMessage: initialMessage,
      ),
    );
  }

  @override
  State<InquiryModalSheet> createState() => _InquiryModalSheetState();
}

class _InquiryModalSheetState extends State<InquiryModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  late final TextEditingController _messageController = TextEditingController(
    text: widget.initialMessage ?? (widget.productName != null ? 'Inquiry regarding: ${widget.productName}\n\n' : ''),
  );
  final ApiClient _apiClient = ApiClient();
  bool _isSubmitting = false;
  bool _received = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final body = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
        'message': _messageController.text.trim(),
      };
      await _apiClient.post('/api/v1/inquiries', body: body, requiresAuth: false);
      if (!mounted) return;
      setState(() => _received = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Failed to send inquiry. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _received ? _buildReceived() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _buildReceived() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check, color: AppTheme.accent, size: 30),
        ),
        const SizedBox(height: 20),
        const GrHeadline('Inquiry Received', size: 26, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text(
          'Thank you for reaching out to GreenRev. Our support team will contact you shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSubtle, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        GrSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 2),
        child: GrSectionLabel(text),
      );

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          Row(
            children: [
              const Expanded(child: GrEyebrow('Inquire Now')),
              GestureDetector(
                onTap: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white38, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GrHeadline(widget.title ?? 'General Inquiry', size: 30),
          if (widget.productName != null) ...[
            const SizedBox(height: 8),
            Text(widget.productName!, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          _label('Name *'),
          GrTextField(
            controller: _nameController,
            hint: 'Your full name',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          _label('Email *'),
          GrTextField(
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^.+@.+\..+$').hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          _label('Phone'),
          GrTextField(
            controller: _phoneController,
            hint: 'Optional',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          _label('Message *'),
          const SizedBox(height: 8),
          GrTextArea(
            controller: _messageController,
            hint: 'How can we help you?',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            GrNotice(_error!),
            const SizedBox(height: 16),
          ],
          GrPrimaryButton(
            label: 'Send Inquiry',
            loadingLabel: 'Sending…',
            loading: _isSubmitting,
            icon: Icons.send_rounded,
            onPressed: _submitInquiry,
          ),
        ],
      ),
    );
  }
}
