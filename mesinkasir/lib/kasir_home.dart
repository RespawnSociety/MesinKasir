import 'package:flutter/material.dart';
import 'package:mesinkasir/pos_screen.dart' hide ProductStore, Product;
import 'package:mesinkasir/product_store.dart';
import 'auth_store.dart';
import 'login_screen.dart';

class KasirHome extends StatefulWidget {
  const KasirHome({super.key});

  @override
  State<KasirHome> createState() => _KasirHomeState();
}

class _KasirHomeState extends State<KasirHome> {
  @override
  Widget build(BuildContext context) {
    final products = ProductStore.products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthStore.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PosScreen(products: products),
                  ),
                );
                if (!mounted) return;
                setState(() {});
              },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Mulai Transaksi'),
            ),
            const SizedBox(height: 12),
            Text('Produk tersedia: ${products.length}'),
          ],
        ),
      ),
    );
  }
}
