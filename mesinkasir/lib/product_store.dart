class Product {
  final String id;
  final String name;
  final int price;
  final String category;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });
}

class ProductStore {
  static final List<Product> _products = [];
  static int _autoId = 1;

  static List<Product> get products => List.unmodifiable(_products);

  static void add({
    required String name,
    required int price,
    required String category,
  }) {
    final id = (_autoId++).toString();
    _products.add(
      Product(
        id: id,
        name: name.trim(),
        price: price,
        category: category.trim(),
      ),
    );
  }
}
