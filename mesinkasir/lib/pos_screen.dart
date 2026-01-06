import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mesinkasir/product_store.dart';

class PosScreen extends StatelessWidget {
  final List<Product> products;

  const PosScreen({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: products.isEmpty
          ? const Center(child: Text('Belum ada produk'))
          : ListView.separated(
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.category),
                  trailing: Text(rupiah.format(p.price)),
                );
              },
            ),
    );
  }
}