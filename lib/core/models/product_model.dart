import '../utils/format.dart';

class ProductColor {
  final String name;
  final String hex;

  ProductColor({required this.name, required this.hex});

  factory ProductColor.fromJson(Map<String, dynamic> json) {
    return ProductColor(
      name: json['name'] ?? '',
      hex: json['hex'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'hex': hex};
}

class ProductSpecs {
  final double? acceleration;
  final int? horsepower;
  final String? torque;
  final String? transmission;
  final String? topSpeed;
  final String? compatibility;
  final String? warranty;

  ProductSpecs({
    this.acceleration,
    this.horsepower,
    this.torque,
    this.transmission,
    this.topSpeed,
    this.compatibility,
    this.warranty,
  });

  factory ProductSpecs.fromJson(Map<String, dynamic> json) {
    return ProductSpecs(
      acceleration: (json['acceleration'] as num?)?.toDouble() ?? (json['0_100'] as num?)?.toDouble(),
      horsepower: (json['horsepower'] as num?)?.toInt(),
      torque: json['torque']?.toString(),
      transmission: json['transmission']?.toString(),
      topSpeed: json['topSpeed']?.toString(),
      compatibility: json['compatibility']?.toString(),
      warranty: json['warranty']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'acceleration': acceleration,
    'horsepower': horsepower,
    'torque': torque,
    'transmission': transmission,
    'topSpeed': topSpeed,
    'compatibility': compatibility,
    'warranty': warranty,
  };
}

class ProductModel {
  final String id;
  final String name;
  final String make;
  final String category; // 'vehicle' or 'part'
  final String price;
  final double priceValue;
  final int? year;
  final String? mileage;
  final ProductColor? color;
  final String image;
  final List<String> images;
  final ProductSpecs? specs;
  final String? description;
  final bool inStock;
  final int stockQuantity;
  final String? vendorId;
  final String? vendorName;
  final String? vendorPhone;

  ProductModel({
    required this.id,
    required this.name,
    required this.make,
    required this.category,
    required this.price,
    required this.priceValue,
    this.year,
    this.mileage,
    this.color,
    required this.image,
    required this.images,
    this.specs,
    this.description,
    this.inStock = true,
    this.stockQuantity = 1,
    this.vendorId,
    this.vendorName,
    this.vendorPhone,
  });

  /// Price as shown to users. The API often stores a bare number string ("90000000");
  /// those are formatted as ₦90,000,000, anything already formatted is kept as-is.
  String get displayPrice {
    final raw = price.trim();
    if (raw.isEmpty || RegExp(r'^[\d.]+$').hasMatch(raw)) {
      return priceValue > 0 ? grMoney(priceValue) : 'Price on request';
    }
    return raw;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price']?.toString() ?? '';
    final priceValue = (json['priceValue'] as num?)?.toDouble() ??
        double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    return ProductModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      make: json['make'] ?? '',
      category: json['category'] ?? 'vehicle',
      price: rawPrice,
      priceValue: priceValue,
      year: (json['year'] as num?)?.toInt(),
      mileage: json['mileage']?.toString(),
      color: json['color'] != null ? ProductColor.fromJson(json['color']) : null,
      image: json['image'] ?? '',
      images: json['images'] is List ? List<String>.from((json['images'] as List).map((e) => e.toString())) : [],
      specs: json['specs'] != null ? ProductSpecs.fromJson(json['specs']) : null,
      description: json['description'],
      inStock: json['inStock'] ?? true,
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 1,
      vendorId: json['vendorId']?.toString(),
      vendorName: json['vendorName']?.toString(),
      vendorPhone: json['vendorPhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'make': make,
    'category': category,
    'price': price,
    'priceValue': priceValue,
    'year': year,
    'mileage': mileage,
    'color': color?.toJson(),
    'image': image,
    'images': images,
    'specs': specs?.toJson(),
    'description': description,
    'inStock': inStock,
    'stockQuantity': stockQuantity,
    'vendorId': vendorId,
    'vendorName': vendorName,
    'vendorPhone': vendorPhone,
  };
}
