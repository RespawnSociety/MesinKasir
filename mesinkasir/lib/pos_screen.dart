import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_store.dart';

class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final n = int.parse(digits);
    final formatted = NumberFormat.decimalPattern('id_ID').format(n);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PosProduct {
  final String id;
  final String name;
  final int price;
  final String category;

  const PosProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId.toString() : (rawId ?? '').toString();

    final rawPrice = json['price'];
    final price = rawPrice is int ? rawPrice : int.tryParse('${rawPrice ?? 0}') ?? 0;

    final cat = json['category'];
    final categoryName = (cat is Map && cat['name'] != null) ? cat['name'].toString() : '-';

    return PosProduct(
      id: id,
      name: (json['name'] ?? '').toString(),
      price: price,
      category: categoryName,
    );
  }
}

class _CartItem {
  final PosProduct product;
  int qty;

  _CartItem({required this.product, this.qty = 1});

  int get subtotal => product.price * qty;
}

enum PayMethod { cash, qris, transfer }
enum ProductView { grid, list }

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool _loading = true;
  String? _error;

  List<PosProduct> _products = const [];
  List<Map<String, dynamic>> _categories = const [];
  String _search = '';
  int? _categoryId;

  final Map<String, _CartItem> _cart = {};
  final _noteCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();

  PayMethod _payMethod = PayMethod.cash;
  ProductView _view = ProductView.grid;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  int get _total {
    var t = 0;
    for (final item in _cart.values) {
      t += item.subtotal;
    }
    return t;
  }

  int get _totalQty {
    var q = 0;
    for (final item in _cart.values) {
      q += item.qty;
    }
    return q;
  }

  int get _cashPaid {
    final s = _cashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? 0;
  }

  int get _change {
    if (_payMethod != PayMethod.cash) return 0;
    final diff = _cashPaid - _total;
    return diff > 0 ? diff : 0;
  }

  int _qtyOf(String productId) => _cart[productId]?.qty ?? 0;

  void _addToCart(PosProduct p) {
    setState(() {
      final existing = _cart[p.id];
      if (existing != null) {
        existing.qty += 1;
      } else {
        _cart[p.id] = _CartItem(product: p, qty: 1);
      }
    });
  }

  void _inc(String id) {
    setState(() {
      final it = _cart[id];
      if (it != null) {
        it.qty += 1;
        return;
      }

      final idx = _products.indexWhere((x) => x.id == id);
      if (idx == -1) return;
      _cart[id] = _CartItem(product: _products[idx], qty: 1);
    });
  }

  void _dec(String id) {
    setState(() {
      final it = _cart[id];
      if (it == null) return;
      it.qty -= 1;
      if (it.qty <= 0) _cart.remove(id);
    });
  }

  void _remove(String id) {
    setState(() => _cart.remove(id));
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchCategories(), _fetchProducts()]);
  }

  Future<void> _fetchCategories() async {
    try {
      final t = await AuthStore.token();
      final uri = Uri.parse('${AuthStore.baseUrl}/api/kasir/categories');

      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
        },
      );

      if (res.statusCode != 200) return;

      final root = jsonDecode(res.body) as Map<String, dynamic>;
      final data = root['data'];

      if (data is List) {
        final list = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (!mounted) return;
        setState(() => _categories = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final t = await AuthStore.token();

      final qp = <String, String>{'per_page': '200'};
      if (_search.trim().isNotEmpty) qp['search'] = _search.trim();
      if (_categoryId != null) qp['category_id'] = _categoryId.toString();

      final uri = Uri.parse('${AuthStore.baseUrl}/api/kasir/products').replace(queryParameters: qp);

      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
        },
      );

      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'HTTP ${res.statusCode}';
        });
        return;
      }

      final root = jsonDecode(res.body) as Map<String, dynamic>;
      final data = root['data'];

      List list;
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is List) {
        list = data;
      } else {
        list = const [];
      }

      final items = list
          .whereType<Map>()
          .map((e) => PosProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _products = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _pay() {
    if (_cart.isEmpty) return;
    if (_payMethod == PayMethod.cash && _cashPaid < _total) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil bayar: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_total)}',
        ),
      ),
    );

    setState(() {
      _cart.clear();
      _noteCtrl.text = '';
      _cashCtrl.text = '';
      _payMethod = PayMethod.cash;
    });
  }

  Widget _filtersWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Cari produk...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              onChanged: (v) => _search = v,
              onSubmitted: (_) => _fetchProducts(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_rounded),
                border: OutlineInputBorder(),
                hintText: 'Kategori',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua kategori'),
                ),
                ..._categories.map((c) {
                  final id = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}');
                  final name = (c['name'] ?? '-').toString();
                  return DropdownMenuItem<int?>(value: id, child: Text(name));
                }).toList(),
              ],
              onChanged: (v) {
                setState(() => _categoryId = v);
                _fetchProducts();
              },
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: () {
              setState(() {
                _view = _view == ProductView.grid ? ProductView.list : ProductView.grid;
              });
            },
            icon: Icon(_view == ProductView.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _filtersMobile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari produk...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  onChanged: (v) => _search = v,
                  onSubmitted: (_) => _fetchProducts(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    _view = _view == ProductView.grid ? ProductView.list : ProductView.grid;
                  });
                },
                icon: Icon(_view == ProductView.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            value: _categoryId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_rounded),
              border: OutlineInputBorder(),
              hintText: 'Kategori',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Semua kategori'),
              ),
              ..._categories.map((c) {
                final id = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}');
                final name = (c['name'] ?? '-').toString();
                return DropdownMenuItem<int?>(value: id, child: Text(name));
              }).toList(),
            ],
            onChanged: (v) {
              setState(() => _categoryId = v);
              _fetchProducts();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final isWide = w >= 1000;

        return Scaffold(
          appBar: AppBar(title: const Text('POS')),
          body: SafeArea(
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _filtersWide(),
                            const Divider(height: 1),
                            Expanded(
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : (_error != null)
                                      ? Center(child: Text(_error!))
                                      : _products.isEmpty
                                          ? const Center(child: Text('Belum ada produk'))
                                          : _view == ProductView.grid
                                              ? _ProductGridKasirResponsive(
                                                  products: _products,
                                                  rupiah: rupiah,
                                                  qtyOf: _qtyOf,
                                                  onTapAdd: _addToCart,
                                                  onInc: (p) => _inc(p.id),
                                                  onDec: (p) => _dec(p.id),
                                                )
                                              : _ProductList(
                                                  products: _products,
                                                  rupiah: rupiah,
                                                  qtyOf: _qtyOf,
                                                  onTap: _addToCart,
                                                  onInc: (p) => _inc(p.id),
                                                  onDec: (p) => _dec(p.id),
                                                ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 380,
                        child: _CartSidePanel(
                          rupiah: rupiah,
                          cart: _cart,
                          totalQty: _totalQty,
                          total: _total,
                          noteCtrl: _noteCtrl,
                          cashCtrl: _cashCtrl,
                          payMethod: _payMethod,
                          change: _change,
                          cashPaid: _cashPaid,
                          onSetPayMethod: (m) {
                            setState(() {
                              _payMethod = m;
                              if (_payMethod != PayMethod.cash) _cashCtrl.text = '';
                            });
                          },
                          onDec: (id) => _dec(id),
                          onInc: (id) => _inc(id),
                          onRemove: (id) => _remove(id),
                          onClear: _clearCart,
                          onPay: _pay,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _filtersMobile(),
                      const Divider(height: 1),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : (_error != null)
                                ? Center(child: Text(_error!))
                                : _products.isEmpty
                                    ? const Center(child: Text('Belum ada produk'))
                                    : _view == ProductView.grid
                                        ? _ProductGridKasirResponsive(
                                            products: _products,
                                            rupiah: rupiah,
                                            qtyOf: _qtyOf,
                                            onTapAdd: _addToCart,
                                            onInc: (p) => _inc(p.id),
                                            onDec: (p) => _dec(p.id),
                                          )
                                        : _ProductList(
                                            products: _products,
                                            rupiah: rupiah,
                                            qtyOf: _qtyOf,
                                            onTap: _addToCart,
                                            onInc: (p) => _inc(p.id),
                                            onDec: (p) => _dec(p.id),
                                          ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _CartSidePanel extends StatelessWidget {
  const _CartSidePanel({
    required this.rupiah,
    required this.cart,
    required this.totalQty,
    required this.total,
    required this.noteCtrl,
    required this.cashCtrl,
    required this.payMethod,
    required this.change,
    required this.cashPaid,
    required this.onSetPayMethod,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
    required this.onClear,
    required this.onPay,
  });

  final NumberFormat rupiah;
  final Map<String, _CartItem> cart;
  final int totalQty;
  final int total;

  final TextEditingController noteCtrl;
  final TextEditingController cashCtrl;

  final PayMethod payMethod;
  final int change;
  final int cashPaid;

  final void Function(PayMethod m) onSetPayMethod;
  final void Function(String id) onDec;
  final void Function(String id) onInc;
  final void Function(String id) onRemove;
  final VoidCallback onClear;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded),
                const SizedBox(width: 8),
                Text(
                  'Pesanan ($totalQty)',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const Spacer(),
                TextButton(
                  onPressed: cart.isEmpty ? null : onClear,
                  child: const Text('Kosongkan'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Belum ada item'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = cart.values.elementAt(i);
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(item.product.category, style: TextStyle(color: Theme.of(context).hintColor)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(rupiah.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => onDec(item.product.id),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                IconButton(
                                  onPressed: () => onInc(item.product.id),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                IconButton(
                                  onPressed: () => onRemove(item.product.id),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: noteCtrl,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Pesan pelanggan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: payMethod == PayMethod.cash,
                        onSelected: (_) => onSetPayMethod(PayMethod.cash),
                        label: const Text('Cash'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: payMethod == PayMethod.qris,
                        onSelected: (_) => onSetPayMethod(PayMethod.qris),
                        label: const Text('QRIS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: payMethod == PayMethod.transfer,
                        onSelected: (_) => onSetPayMethod(PayMethod.transfer),
                        label: const Text('Transfer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (payMethod == PayMethod.cash)
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Uang dibayar (cash)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Column(
                    children: [
                      _RowKeyVal(k: 'Total', v: rupiah.format(total), bold: true),
                      if (payMethod == PayMethod.cash) ...[
                        const SizedBox(height: 6),
                        _RowKeyVal(k: 'Dibayar', v: rupiah.format(cashPaid)),
                        const SizedBox(height: 6),
                        _RowKeyVal(k: 'Kembalian', v: rupiah.format(change)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : (payMethod == PayMethod.cash && cashPaid < total)
                            ? null
                            : onPay,
                    child: Text(
                      payMethod == PayMethod.cash && cashPaid < total ? 'Uang kurang' : 'Bayar',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGridKasirResponsive extends StatelessWidget {
  const _ProductGridKasirResponsive({
    required this.products,
    required this.rupiah,
    required this.qtyOf,
    required this.onTapAdd,
    required this.onInc,
    required this.onDec,
  });

  final List<PosProduct> products;
  final NumberFormat rupiah;
  final int Function(String id) qtyOf;
  final void Function(PosProduct p) onTapAdd;
  final void Function(PosProduct p) onInc;
  final void Function(PosProduct p) onDec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final q = qtyOf(p.id);

        return Material(
          color: cs.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 38,
                child: InkWell(
                  onTap: () => onTapAdd(p),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                height: 1.1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              rupiah.format(p.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        if (q > 0)
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'x$q',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.35),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton.outlined(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onPressed: q > 0 ? () => onDec(p) : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Center(
                          child: Text(
                            q == 0 ? 'Tambah' : '$q',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: q == 0 ? Theme.of(context).hintColor : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton.filled(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onPressed: () => onInc(p),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.rupiah,
    required this.qtyOf,
    required this.onTap,
    required this.onInc,
    required this.onDec,
  });

  final List<PosProduct> products;
  final NumberFormat rupiah;
  final int Function(String id) qtyOf;
  final void Function(PosProduct p) onTap;
  final void Function(PosProduct p) onInc;
  final void Function(PosProduct p) onDec;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = products[i];
        final q = qtyOf(p.id);

        return ListTile(
          dense: true,
          isThreeLine: true,
          onTap: () => onTap(p),
          title: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.category, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(rupiah.format(p.price), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton.outlined(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: q > 0 ? () => onDec(p) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Text('$q', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton.filled(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => onInc(p),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RowKeyVal extends StatelessWidget {
  const _RowKeyVal({required this.k, required this.v, this.bold = false});

  final String k;
  final String v;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      fontSize: bold ? 16 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(k, style: st)),
        Text(v, style: st),
      ],
    );
  }
}
