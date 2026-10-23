/// Mirrors greenrev-web/src/types/acquisition.ts (AcquisitionRequest).
class AcquisitionModel {
  final String id;
  final String? productId;
  final String productName;
  final String? productImage;
  final String? productPrice;
  final String? productMake;
  final String? vendorName;
  final String? vendorEmail;
  final String? vendorPhone;
  final String? vendorCompanyName;

  /// pending | accepted | receipt_uploaded | payment_confirmed | completed
  final String status;
  final int quantity;
  final String? message;
  final String? receiptUrl;
  final num? vendorPaymentAmount;
  final DateTime? completedAt;
  final bool hasReview;
  final int? reviewRating;
  final String? reviewComment;
  final DateTime? createdAt;

  AcquisitionModel({
    required this.id,
    this.productId,
    required this.productName,
    this.productImage,
    this.productPrice,
    this.productMake,
    this.vendorName,
    this.vendorEmail,
    this.vendorPhone,
    this.vendorCompanyName,
    required this.status,
    this.quantity = 1,
    this.message,
    this.receiptUrl,
    this.vendorPaymentAmount,
    this.completedAt,
    this.hasReview = false,
    this.reviewRating,
    this.reviewComment,
    this.createdAt,
  });

  factory AcquisitionModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map<String, dynamic> ? json['product'] as Map<String, dynamic> : null;
    final review = json['review'] is Map<String, dynamic> ? json['review'] as Map<String, dynamic> : null;
    String? str(dynamic v) => (v == null || v.toString().isEmpty) ? null : v.toString();

    return AcquisitionModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      productId: json['productId'] is String ? json['productId'] as String : str(product?['_id']),
      productName: str(json['productName']) ?? str(product?['name']) ?? 'Acquisition Request',
      productImage: str(json['productImage']) ?? str(product?['image']),
      productPrice: str(json['productPrice']),
      productMake: str(json['productMake']),
      vendorName: str(json['vendorName']),
      vendorEmail: str(json['vendorEmail']),
      vendorPhone: str(json['vendorPhone']),
      vendorCompanyName: str(json['vendorCompanyName']),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      message: str(json['message']),
      receiptUrl: str(json['receiptUrl']),
      vendorPaymentAmount: json['vendorPaymentAmount'] as num?,
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      hasReview: json['hasReview'] == true || review != null,
      reviewRating: (review?['rating'] as num?)?.toInt(),
      reviewComment: str(review?['comment']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Expert service booking — GET /api/v1/bookings/my.
class BookingModel {
  final String id;
  final String make;
  final String model;
  final String year;
  final String issueDescription;
  final DateTime? requestedDate;

  /// PENDING | CONFIRMED | REJECTED | COMPLETED
  final String status;
  final DateTime? createdAt;
  final String? mechanicName;
  final String? mechanicEmail;
  final String? mechanicPhone;
  final String? garageName;

  BookingModel.fromJson(Map<String, dynamic> json)
      : id = (json['_id'] ?? '').toString(),
        make = (json['vehicleDetails']?['make'] ?? '').toString(),
        model = (json['vehicleDetails']?['model'] ?? '').toString(),
        year = (json['vehicleDetails']?['year'] ?? '').toString(),
        issueDescription = (json['issueDescription'] ?? '').toString(),
        requestedDate = DateTime.tryParse(json['requestedDate']?.toString() ?? ''),
        status = (json['status'] ?? 'PENDING').toString().toUpperCase(),
        createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        mechanicName = json['mechanicId'] is Map ? json['mechanicId']['name'] as String? : null,
        mechanicEmail = json['mechanicId'] is Map ? json['mechanicId']['email'] as String? : null,
        mechanicPhone = json['mechanicId'] is Map ? json['mechanicId']['phone'] as String? : null,
        garageName = json['mechanicId'] is Map ? json['mechanicId']['garageName'] as String? : null;

  String get vehicle => [year, make, model].where((s) => s.isNotEmpty).join(' ');
}
