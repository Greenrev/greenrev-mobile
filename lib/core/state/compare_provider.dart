import 'package:flutter/material.dart';
import '../models/product_model.dart';

/// App-wide compare list — mirrors the website's CompareContext (max two machines).
class CompareProvider extends ChangeNotifier {
  static const maxItems = 2;
  final List<ProductModel> _items = [];

  List<ProductModel> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool contains(String id) => _items.any((v) => v.id == id);

  /// Returns false when the list is already full.
  bool toggle(ProductModel vehicle) {
    if (contains(vehicle.id)) {
      _items.removeWhere((v) => v.id == vehicle.id);
      notifyListeners();
      return true;
    }
    if (_items.length >= maxItems) return false;
    _items.add(vehicle);
    notifyListeners();
    return true;
  }

  void remove(String id) {
    _items.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
