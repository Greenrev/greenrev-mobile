class ReviewModel {
  final String id;
  final String productId;
  final String? userId;
  final String userName;
  final int rating;
  final String? comment;
  final String createdAt;

  ReviewModel({
    required this.id,
    required this.productId,
    this.userId,
    required this.userName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'] ?? json['id'] ?? '',
      productId: json['productId'] ?? '',
      userId: json['userId'],
      userName: json['customerName'] ?? json['authorName'] ?? json['userName'] ?? json['user']?['name'] ?? json['user']?['email'] ?? 'Verified Client',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'],
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt,
      };
}
