import 'product_store.dart';

class StockItem {
  final Product product;
  final int qty;

  const StockItem({
    required this.product,
    required this.qty,
  });
}

class StockStore {
  static final Map<String, int> _stockByProductId = {};

  static void syncWithProducts(List<Product> products) {
    for (final p in products) {
      _stockByProductId.putIfAbsent(p.id, () => 0);
    }
    final validIds = products.map((e) => e.id).toSet();
    _stockByProductId.removeWhere((key, _) => !validIds.contains(key));
  }

  static int qtyOf(String productId) => _stockByProductId[productId] ?? 0;

  static List<StockItem> items(List<Product> products) {
    syncWithProducts(products);
    return products
        .map((p) => StockItem(product: p, qty: qtyOf(p.id)))
        .toList(growable: false);
  }

  static void setQty({
    required String productId,
    required int qty,
  }) {
    if (qty < 0) return;
    _stockByProductId[productId] = qty;
  }

  static void addQty({
    required String productId,
    required int delta,
  }) {
    if (delta <= 0) return;
    final now = qtyOf(productId);
    _stockByProductId[productId] = now + delta;
  }

  static bool reduceQty({
    required String productId,
    required int delta,
  }) {
    if (delta <= 0) return false;
    final now = qtyOf(productId);
    if (now < delta) return false;
    _stockByProductId[productId] = now - delta;
    return true;
  }

  static bool isInStock(String productId) => qtyOf(productId) > 0;
}
