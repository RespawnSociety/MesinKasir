import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'product_store.dart';
import 'stock_store.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final products = ProductStore.products;
    final items = StockStore.items(products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Produk'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const Center(child: Text('Belum ada produk'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return _StockTile(
                    name: item.product.name,
                    category: item.product.category,
                    priceText: rupiah.format(item.product.price),
                    qty: item.qty,
                    onSet: (qty) {
                      StockStore.setQty(productId: item.product.id, qty: qty);
                      setState(() {});
                    },
                    onPlus: () {
                      StockStore.addQty(productId: item.product.id, delta: 1);
                      setState(() {});
                    },
                    onMinus: () {
                      StockStore.reduceQty(productId: item.product.id, delta: 1);
                      setState(() {});
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _StockTile extends StatefulWidget {
  const _StockTile({
    required this.name,
    required this.category,
    required this.priceText,
    required this.qty,
    required this.onSet,
    required this.onPlus,
    required this.onMinus,
  });

  final String name;
  final String category;
  final String priceText;
  final int qty;
  final ValueChanged<int> onSet;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  @override
  State<_StockTile> createState() => _StockTileState();
}

class _StockTileState extends State<_StockTile> {
  late final TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _StockTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) {
      ctrl.text = widget.qty.toString();
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  int _parseQty() {
    final raw = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final qty = widget.qty;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(qty.toString()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.category} • ${widget.priceText}',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Stok',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => widget.onSet(_parseQty()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => widget.onSet(_parseQty()),
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                IconButton(
                  onPressed: widget.onPlus,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                IconButton(
                  onPressed: widget.onMinus,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
