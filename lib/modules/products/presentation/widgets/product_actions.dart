import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/review_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../acquisitions/presentation/screens/acquisitions_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

/// Shared pieces of the website's vehicle (/shop/[id]) and part (/parts/[id]) pages.

void _pushLogin(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));

Widget _sheetFrame(BuildContext context, Widget child) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

/// "Place Acquisition Request" — one request for one product.
class AcquisitionRequestSheet extends StatefulWidget {
  final ProductModel product;
  final bool isPart;
  const AcquisitionRequestSheet({super.key, required this.product, this.isPart = false});

  static void show(BuildContext context, ProductModel product, {bool isPart = false}) {
    if (!context.read<AuthProvider>().isLoggedIn) {
      _pushLogin(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AcquisitionRequestSheet(product: product, isPart: isPart),
    );
  }

  @override
  State<AcquisitionRequestSheet> createState() => _AcquisitionRequestSheetState();
}

class _AcquisitionRequestSheetState extends State<AcquisitionRequestSheet> {
  final _message = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final text = _message.text.trim();
      await ApiClient().post('/api/v1/acquisition-requests', body: {
        'productId': widget.product.id,
        'quantity': 1,
        if (text.isNotEmpty) 'message': text,
      });
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : 'Failed to submit request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return _sheetFrame(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GrCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              borderColor: AppTheme.accent.withValues(alpha: 0.25),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request sent successfully!', style: TextStyle(color: Colors.white, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('The vendor has been notified.', style: TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GrCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrEyebrow('Next Step'),
                  const SizedBox(height: 8),
                  Text(
                    widget.isPart
                        ? "Once the vendor accepts your request, you'll see their contact details and a payment receipt upload field in your requests page."
                        : "Once the vendor accepts, you'll see their contact details and a payment receipt upload field in your requests page.",
                    style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GrPrimaryButton(
              label: 'View My Requests',
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const AcquisitionsScreen()));
              },
            ),
            const SizedBox(height: 10),
            GrSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    return _sheetFrame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrHeadline('Place Acquisition Request', size: 26),
          const SizedBox(height: 6),
          Text(widget.product.name, style: const TextStyle(color: AppTheme.accent, fontSize: 14)),
          const SizedBox(height: 12),
          Text(
            widget.isPart
                ? 'Submitting this request will connect you with the vendor. Their contact details will be revealed once they accept your request.'
                : 'Submitting this request will connect you with the vendor. Their contact details will be revealed so you can coordinate directly.',
            style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          const GrSectionLabel('Message to Vendor (optional)'),
          const SizedBox(height: 10),
          GrTextArea(
            controller: _message,
            minLines: 3,
            hint: widget.isPart
                ? 'Any fitment questions, quantity needs, or specific requirements…'
                : 'Introduce yourself or ask any questions about this vehicle…',
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            GrNotice(_error!),
            const SizedBox(height: 14),
          ],
          GrPrimaryButton(
            label: 'Send Request',
            loadingLabel: 'Submitting…',
            loading: _submitting,
            icon: Icons.send_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// "Message Vendor" — POST /api/v1/vendors/:vendorId/messages.
class VendorMessageSheet extends StatefulWidget {
  final ProductModel product;
  final bool isPart;
  const VendorMessageSheet({super.key, required this.product, this.isPart = false});

  static void show(BuildContext context, ProductModel product, {bool isPart = false}) {
    if (!context.read<AuthProvider>().isLoggedIn) {
      _pushLogin(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VendorMessageSheet(product: product, isPart: isPart),
    );
  }

  @override
  State<VendorMessageSheet> createState() => _VendorMessageSheetState();
}

class _VendorMessageSheetState extends State<VendorMessageSheet> {
  final _message = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/vendors/${widget.product.vendorId}/messages', body: {
        'message': _message.text.trim(),
        'productId': widget.product.id,
      });
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _sheetFrame(
        context,
        Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(height: 16),
            const GrHeadline('Message Sent!', size: 24, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('The vendor has been notified and will get back to you soon.',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
            const SizedBox(height: 24),
            GrSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }

    return _sheetFrame(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrHeadline('Message Vendor', size: 26),
          const SizedBox(height: 12),
          Text(
            'Send a direct message to the vendor about this ${widget.isPart ? 'component' : 'listing'}. They will reply to your registered email.',
            style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          GrTextArea(controller: _message, hint: 'Type your message here...'),
          const SizedBox(height: 18),
          if (_error != null) ...[
            GrNotice(_error!),
            const SizedBox(height: 14),
          ],
          ListenableBuilder(
            listenable: _message,
            builder: (_, _) => GrPrimaryButton(
              label: 'Send Message',
              loadingLabel: 'Sending…',
              loading: _submitting,
              icon: Icons.send_rounded,
              onPressed: _message.text.trim().isEmpty ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}

/// Call / message the vendor when signed in; otherwise "Sign in to view owner details".
class VendorContactRow extends StatelessWidget {
  final ProductModel product;
  final bool isPart;
  final void Function(String phone) onCall;
  const VendorContactRow({super.key, required this.product, required this.onCall, this.isPart = false});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      return GrSecondaryButton(label: 'Sign in to view owner details', onPressed: () => _pushLogin(context));
    }
    final hasPhone = product.vendorPhone?.trim().isNotEmpty ?? false;
    final canMessage = product.vendorId?.isNotEmpty ?? false;
    if (!hasPhone && !canMessage) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasPhone)
          Expanded(
            child: GrSecondaryButton(
              label: 'Call Vendor',
              icon: Icons.phone_outlined,
              onPressed: () => onCall(product.vendorPhone!.trim()),
            ),
          ),
        if (hasPhone && canMessage) const SizedBox(width: 10),
        if (canMessage)
          Expanded(
            child: GrSecondaryButton(
              label: 'Message Vendor',
              icon: Icons.mail_outline,
              onPressed: () => VendorMessageSheet.show(context, product, isPart: isPart),
            ),
          ),
      ],
    );
  }
}

/// "Customer Feedback / Reviews." section.
class ProductReviews extends StatefulWidget {
  final String productId;
  const ProductReviews({super.key, required this.productId});

  @override
  State<ProductReviews> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviews> {
  final _comment = TextEditingController();
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  int _rating = 5;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient().get('/api/v1/products/${widget.productId}/reviews', requiresAuth: false);
      final list = res is List ? res : (res is Map ? res['reviews'] as List? : null) ?? const [];
      _reviews = list.whereType<Map<String, dynamic>>().map(ReviewModel.fromJson).toList();
    } catch (_) {
      // Reviews are non-critical; show the empty state on failure.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/products/${widget.productId}/reviews', body: {
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      _comment.clear();
      if (mounted) setState(() => _submitted = true);
      _fetch();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to submit review');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GrPageHeader(eyebrow: 'Customer Feedback', title: 'Reviews.', size: 36),
        const SizedBox(height: 20),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
          )
        else if (_reviews.isEmpty)
          GrCard(
            child: Text('No reviews yet. Be the first to share your thoughts!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
          )
        else
          for (final r in _reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.userName, style: const TextStyle(color: Colors.white, fontSize: 15))),
                        _Stars(rating: r.rating),
                      ],
                    ),
                    if (r.comment?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 10),
                      Text(r.comment!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5)),
                    ],
                    const SizedBox(height: 8),
                    Text(grDate(DateTime.tryParse(r.createdAt)), style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 16),
        GrCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Write a Review', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 14),
              if (!loggedIn) ...[
                Text('You must be logged in to leave a review.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 16),
                GrPrimaryButton(label: 'Log In', onPressed: () => _pushLogin(context)),
              ] else if (_submitted) ...[
                const Text('Thank you for your review!', style: TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 14),
                GrSecondaryButton(label: 'Write Another', onPressed: () => setState(() => _submitted = false)),
              ] else ...[
                const GrSectionLabel('Rating'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = i),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i <= _rating ? AppTheme.accent : Colors.white24,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const GrSectionLabel('Comment (optional)'),
                const SizedBox(height: 8),
                GrTextArea(controller: _comment, hint: 'Share your experience...', minLines: 3),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  GrNotice(_error!),
                  const SizedBox(height: 12),
                ],
                GrPrimaryButton(label: 'Submit Review', loading: _submitting, icon: null, onPressed: _submit),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14, color: i <= rating ? AppTheme.accent : Colors.white24),
      ],
    );
  }
}
