import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/acquisition_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/state/auth_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/gr_ui.dart';
import '../../../auth/presentation/screens/login_screen.dart';

/// Status labels and colours — same as the website's STATUS_CONFIG / BOOKING_STATUS_CONFIG.
const _requestStatus = <String, (String, Color)>{
  'pending': ('Pending', Color(0xFFFACC15)),
  'accepted': ('Accepted', Color(0xFF60A5FA)),
  'receipt_uploaded': ('Receipt Uploaded', Color(0xFFD8B4FE)),
  'payment_confirmed': ('Payment Confirmed', Color(0xFF6EE7B7)),
  'completed': ('Completed', Color(0xFF4ADE80)),
};

const _bookingStatus = <String, (String, Color)>{
  'PENDING': ('Pending', Color(0xFFFACC15)),
  'CONFIRMED': ('Confirmed', Color(0xFF60A5FA)),
  'COMPLETED': ('Completed', Color(0xFF4ADE80)),
  'REJECTED': ('Rejected', Color(0xFFF87171)),
};

/// "My Requests" — web: /acquisitions.
class AcquisitionsScreen extends StatefulWidget {
  const AcquisitionsScreen({super.key});

  @override
  State<AcquisitionsScreen> createState() => _AcquisitionsScreenState();
}

class _AcquisitionsScreenState extends State<AcquisitionsScreen> {
  int _tab = 0;
  String _requestFilter = 'all';
  String _bookingFilter = 'all';

  List<AcquisitionModel> _requests = [];
  List<BookingModel> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient().get('/api/v1/acquisition-requests'),
        ApiClient().get('/api/v1/bookings/my').catchError((_) => null),
      ]);
      final reqs = (results[0] is Map ? results[0]['requests'] : null) as List? ?? const [];
      final books = (results[1] is Map ? results[1]['bookings'] : null) as List? ?? const [];
      _requests = reqs.whereType<Map<String, dynamic>>().map(AcquisitionModel.fromJson).toList();
      _bookings = books.whereType<Map<String, dynamic>>().map(BookingModel.fromJson).toList();
    } catch (e) {
      _error = e is ApiException ? e.message : 'Failed to load your requests.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replace(AcquisitionModel updated) {
    setState(() {
      final i = _requests.indexWhere((r) => r.id == updated.id);
      if (i >= 0) _requests[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;

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
                title: 'My Requests',
                subtitle: 'Track your car acquisition and expert service requests.',
                size: 42,
              ),
              const SizedBox(height: 28),
              if (!loggedIn)
                GrCard(
                  child: GrEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Sign in required',
                    message: 'Sign in to track your car acquisition and expert service requests.',
                    actionLabel: 'Sign In',
                    onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
                )
              else ...[
                _Tabs(
                  index: _tab,
                  labels: [
                    'Car Requests${_requests.isEmpty ? '' : ' (${_requests.length})'}',
                    'Expert Bookings${_bookings.isEmpty ? '' : ' (${_bookings.length})'}',
                  ],
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
                  )
                else if (_error != null)
                  GrNotice(_error!)
                else if (_tab == 0)
                  ..._buildRequests()
                else
                  ..._buildBookings(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRequests() {
    if (_requests.isEmpty) {
      return [
        GrCard(
          child: GrEmptyState(
            icon: Icons.directions_car_outlined,
            title: 'No car requests yet',
            message: 'Browse the showroom and place your first acquisition request to get started.',
            actionLabel: 'Browse Showroom',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      ];
    }
    final filtered = _requestFilter == 'all' ? _requests : _requests.where((r) => r.status == _requestFilter).toList();
    return [
      _FilterChips(
        options: [('All', 'all'), for (final e in _requestStatus.entries) (e.value.$1, e.key)],
        active: _requestFilter,
        onSelect: (v) => setState(() => _requestFilter = v),
      ),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No requests match this filter.', style: TextStyle(color: AppTheme.textSubtle))),
        )
      else
        for (final r in filtered) ...[
          _RequestCard(request: r, onUpdated: _replace, onRefresh: _fetch),
          const SizedBox(height: 12),
        ],
    ];
  }

  List<Widget> _buildBookings() {
    if (_bookings.isEmpty) {
      return [
        GrCard(
          child: GrEmptyState(
            icon: Icons.build_outlined,
            title: 'No expert bookings yet',
            message: 'Book an expert mechanic to service your vehicle and track updates here.',
            actionLabel: 'Find an Expert',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      ];
    }
    final filtered = _bookingFilter == 'all' ? _bookings : _bookings.where((b) => b.status == _bookingFilter).toList();
    return [
      _FilterChips(
        options: [('All', 'all'), for (final e in _bookingStatus.entries) (e.value.$1, e.key)],
        active: _bookingFilter,
        onSelect: (v) => setState(() => _bookingFilter = v),
      ),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No bookings match this filter.', style: TextStyle(color: AppTheme.textSubtle))),
        )
      else
        for (final b in filtered) ...[
          _BookingCard(booking: b),
          const SizedBox(height: 12),
        ],
    ];
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[i].toUpperCase(),
                    style: TextStyle(
                      color: i == index ? Colors.black : Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<(String, String)> options;
  final String active;
  final ValueChanged<String> onSelect;
  const _FilterChips({required this.options, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, value) = options[i];
          final selected = value == active;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border),
              ),
              child: Text(label,
                  style: TextStyle(color: selected ? AppTheme.accent : Colors.white60, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final (String, Color) config;
  const _StatusPill(this.config);

  @override
  Widget build(BuildContext context) => GrPill(config.$1, color: config.$2);
}

Future<void> _open(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showGrSnack(context, 'Could not open that link.', error: true);
}

class _RequestCard extends StatefulWidget {
  final AcquisitionModel request;
  final ValueChanged<AcquisitionModel> onUpdated;
  final Future<void> Function() onRefresh;
  const _RequestCard({required this.request, required this.onUpdated, required this.onRefresh});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;
  bool _busy = false;
  XFile? _receipt;

  AcquisitionModel get r => widget.request;

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file != null) setState(() => _receipt = file);
  }

  Future<void> _uploadReceipt() async {
    if (_receipt == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await _receipt!.readAsBytes();
      final mime = _receipt!.mimeType ?? (_receipt!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      final res = await ApiClient().post('/api/v1/acquisition-requests/${r.id}/receipt', body: {
        'receiptImageBase64': 'data:$mime;base64,${base64Encode(bytes)}',
      });
      _applyResponse(res);
      _receipt = null;
      if (mounted) showGrSnack(context, 'Receipt submitted.');
    } catch (e) {
      if (mounted) showGrSnack(context, e is ApiException ? e.message : 'Upload failed.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCompleted() async {
    setState(() => _busy = true);
    try {
      final res = await ApiClient().post('/api/v1/acquisition-requests/${r.id}/client/confirm-completed');
      _applyResponse(res);
    } catch (e) {
      if (mounted) showGrSnack(context, e is ApiException ? e.message : 'Could not confirm.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyResponse(dynamic res) {
    final data = res is Map<String, dynamic> ? (res['request'] ?? res) : null;
    if (data is Map<String, dynamic> && data['_id'] != null) {
      widget.onUpdated(AcquisitionModel.fromJson(data));
    } else {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _requestStatus[r.status] ?? (r.status, Colors.white54);
    final meta = [r.productPrice, r.productMake].whereType<String>().join(' · ');

    return GrCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image(
                        image: safeImageProvider(r.productImage ?? ''),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.black,
                          child: const Icon(Icons.directions_car_outlined, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.productName}${r.quantity > 1 ? ' (x${r.quantity})' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(meta, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 11)),
                        ],
                        if (r.vendorName != null) ...[
                          const SizedBox(height: 2),
                          Text(r.vendorName!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                        const SizedBox(height: 8),
                        _StatusPill(status),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white30),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.hairline))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  const GrSectionLabel('Vendor Contact'),
                  const SizedBox(height: 8),
                  if (r.status == 'pending')
                    const Text('Vendor contact details unlock after the vendor accepts your request.',
                        style: TextStyle(color: AppTheme.textSubtle, fontSize: 13))
                  else ...[
                    if (r.vendorCompanyName != null)
                      Text(r.vendorCompanyName!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    if (r.vendorEmail != null)
                      _LinkRow(icon: Icons.mail_outline, text: r.vendorEmail!,
                          onTap: () => _open(context, Uri(scheme: 'mailto', path: r.vendorEmail))),
                    if (r.vendorPhone != null)
                      _LinkRow(icon: Icons.phone_outlined, text: r.vendorPhone!,
                          onTap: () => _open(context, Uri(scheme: 'tel', path: r.vendorPhone))),
                  ],
                  if (r.message != null) ...[
                    const SizedBox(height: 16),
                    const GrSectionLabel('Your Message'),
                    const SizedBox(height: 6),
                    Text(r.message!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
                  ],
                  if (r.status == 'accepted') ...[
                    const SizedBox(height: 18),
                    const GrSectionLabel('Upload Payment Receipt'),
                    const SizedBox(height: 10),
                    GrSecondaryButton(
                      label: _receipt == null ? 'Choose Image' : _receipt!.name,
                      icon: Icons.image_outlined,
                      onPressed: _busy ? null : _pickReceipt,
                    ),
                    const SizedBox(height: 10),
                    GrPrimaryButton(
                      label: 'Submit Receipt',
                      loadingLabel: 'Uploading...',
                      loading: _busy,
                      icon: Icons.upload,
                      onPressed: _receipt == null ? null : _uploadReceipt,
                    ),
                  ],
                  if (r.status == 'receipt_uploaded') ...[
                    const SizedBox(height: 18),
                    const GrNotice('Receipt submitted. Waiting for the vendor to confirm payment.', kind: GrNoticeKind.info),
                    if (r.receiptUrl != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _open(context, Uri.parse(r.receiptUrl!)),
                          child: const Text('VIEW RECEIPT'),
                        ),
                      ),
                  ],
                  if (r.status == 'payment_confirmed') ...[
                    const SizedBox(height: 18),
                    GrNotice(
                      'Vendor confirmed payment${r.vendorPaymentAmount != null ? ' (${grMoney(r.vendorPaymentAmount!)})' : ''}.',
                      kind: GrNoticeKind.success,
                    ),
                    const SizedBox(height: 12),
                    GrPrimaryButton(
                      label: 'I Received My Order',
                      loadingLabel: 'Confirming...',
                      loading: _busy,
                      accent: true,
                      onPressed: _confirmCompleted,
                    ),
                  ],
                  if (r.status == 'completed') ...[
                    const SizedBox(height: 18),
                    GrNotice(
                      r.completedAt != null ? 'Completed on ${grDate(r.completedAt)}.' : 'Completed.',
                      kind: GrNoticeKind.success,
                    ),
                    const SizedBox(height: 14),
                    if (r.hasReview)
                      _ExistingReview(rating: r.reviewRating ?? 0, comment: r.reviewComment)
                    else
                      _VendorReviewForm(requestId: r.id, onSubmitted: widget.onRefresh),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
          ],
        ),
      ),
    );
  }
}

class _ExistingReview extends StatelessWidget {
  final int rating;
  final String? comment;
  const _ExistingReview({required this.rating, this.comment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GrSectionLabel('Your Review'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var s = 1; s <= 5; s++)
              Icon(s <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16, color: s <= rating ? AppTheme.accent : Colors.white24),
          ],
        ),
        if (comment != null) ...[
          const SizedBox(height: 6),
          Text(comment!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ],
    );
  }
}

class _VendorReviewForm extends StatefulWidget {
  final String requestId;
  final Future<void> Function() onSubmitted;
  const _VendorReviewForm({required this.requestId, required this.onSubmitted});

  @override
  State<_VendorReviewForm> createState() => _VendorReviewFormState();
}

class _VendorReviewFormState extends State<_VendorReviewForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().post('/api/v1/acquisition-requests/${widget.requestId}/review', body: {
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      await widget.onSubmitted();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Failed to submit review');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Leave a Review', style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 28, color: i <= _rating ? AppTheme.accent : Colors.white24),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GrTextArea(controller: _comment, hint: 'Share your experience with this vendor (optional)…', minLines: 2),
        const SizedBox(height: 12),
        if (_error != null) ...[
          GrNotice(_error!),
          const SizedBox(height: 10),
        ],
        GrPrimaryButton(label: 'Submit Review', loading: _submitting, icon: null, onPressed: _submit),
      ],
    );
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final status = _bookingStatus[b.status] ?? (b.status, Colors.white54);
    final expertTitle = '${b.mechanicName ?? 'Expert'}${b.garageName != null ? ' · ${b.garageName}' : ''}';

    final statusText = switch (b.status) {
      'PENDING' => 'Your request is awaiting confirmation from the expert.',
      'CONFIRMED' => 'The expert has confirmed your booking for ${grDate(b.requestedDate)}.',
      'COMPLETED' => 'Service completed successfully.',
      'REJECTED' => 'The expert was unable to accept this booking. Please try booking another expert.',
      _ => '',
    };

    return GrCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.build_outlined, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expertTitle, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(b.vehicle, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('Requested for ${grDate(b.requestedDate)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 8),
                        _StatusPill(status),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white30),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.hairline))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrSectionLabel('Booking Status'),
                  const SizedBox(height: 6),
                  Text(statusText, style: TextStyle(color: status.$2.withValues(alpha: 0.85), fontSize: 13, height: 1.45)),
                  const SizedBox(height: 16),
                  const GrSectionLabel('Issue Description'),
                  const SizedBox(height: 6),
                  Text(b.issueDescription, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
                  const SizedBox(height: 16),
                  const GrSectionLabel('Expert Contact'),
                  const SizedBox(height: 6),
                  if (b.status == 'PENDING')
                    const Text('Expert contact details unlock once the booking is confirmed.',
                        style: TextStyle(color: AppTheme.textSubtle, fontSize: 13))
                  else ...[
                    if (b.mechanicEmail != null)
                      _LinkRow(icon: Icons.mail_outline, text: b.mechanicEmail!,
                          onTap: () => _open(context, Uri(scheme: 'mailto', path: b.mechanicEmail))),
                    if (b.mechanicPhone?.isNotEmpty ?? false)
                      _LinkRow(icon: Icons.phone_outlined, text: b.mechanicPhone!,
                          onTap: () => _open(context, Uri(scheme: 'tel', path: b.mechanicPhone))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
