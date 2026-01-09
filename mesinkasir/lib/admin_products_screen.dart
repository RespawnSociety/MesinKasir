import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'product_store.dart';
import 'auth_store.dart';

class _Cat {
  final int id;
  final String name;
  final bool active;

  const _Cat({required this.id, required this.name, required this.active});

  factory _Cat.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
            ? rawActive == 1
            : (rawActive?.toString().toLowerCase() == '1' ||
                rawActive?.toString().toLowerCase() == 'true');

    return _Cat(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      active: active,
    );
  }
}

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _selectedCategory;

  final List<_Cat> _categories = [];
  bool _loadingCats = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  int? _parsePrice() {
    final raw = priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw);
  }

  dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  String _errMsg(http.Response res) {
    final body = _tryJson(res.body);
    if (body is Map) {
      final msg = body['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) return msg.toString();
      final errors = body['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      }
    }
    return 'HTTP ${res.statusCode}';
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final t = await AuthStore.token();
    final h = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<void> _fetchCategories() async {
    setState(() => _loadingCats = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/categories'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errMsg(res))),
        );
      }
      if (mounted) setState(() => _loadingCats = false);
      return;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    _categories.clear();
    if (list is List) {
      _categories.addAll(
        list
            .map((e) => _Cat.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((c) => c.active)
            .toList(),
      );
      _categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    if (_selectedCategory != null) {
      final ok = _categories.any((c) => c.name == _selectedCategory);
      if (!ok) _selectedCategory = null;
    }

    if (mounted) setState(() => _loadingCats = false);
  }

  void addProduct() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = nameCtrl.text.trim();
    final price = _parsePrice()!;
    final category = _selectedCategory!;

    ProductStore.add(name: name, price: price, category: category);

    nameCtrl.clear();
    priceCtrl.clear();
    setState(() => _selectedCategory = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produk berhasil ditambahkan ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductStore.products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Produk'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadingCats ? null : () async => await _fetchCategories(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _HeaderCard(
                      title: 'Kelola Produk',
                      subtitle: 'Tambah produk baru dan lihat daftar produk di bawah.',
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 14),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Tambah Produk',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                items: _categories
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.name,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loadingCats ? null : (v) => setState(() => _selectedCategory = v),
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  prefixIcon: const Icon(Icons.category_rounded),
                                  suffixIcon: _loadingCats
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (v) => (v == null) ? 'Kategori wajib dipilih' : null,
                              ),

                              const SizedBox(height: 12),

                              TextFormField(
                                controller: nameCtrl,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Nama produk',
                                  hintText: 'Contoh: Kopi Susu 250ml',
                                  prefixIcon: const Icon(Icons.sell_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Nama produk wajib diisi';
                                  if (s.length < 3) return 'Nama terlalu pendek';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 12),

                              TextFormField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _ThousandSeparatorInputFormatter(),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Harga',
                                  hintText: 'Contoh: 15000',
                                  prefixIcon: const Icon(Icons.payments_rounded),
                                  prefixText: 'Rp ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  helperText: 'Masukkan angka tanpa titik/koma (akan diformat otomatis).',
                                ),
                                validator: (_) {
                                  final p = _parsePrice();
                                  if (p == null) return 'Harga wajib diisi';
                                  if (p <= 0) return 'Harga harus lebih dari 0';
                                  if (p > 1000000000) return 'Harga terlalu besar';
                                  return null;
                                },
                                onFieldSubmitted: (_) => addProduct(),
                              ),

                              const SizedBox(height: 14),

                              SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: addProduct,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Tambah Produk'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Text(
                          'Daftar Produk',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Chip(
                          label: Text('${products.length} item'),
                          avatar: const Icon(Icons.list_rounded, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            if (products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyState(
                    title: 'Belum ada produk',
                    subtitle: 'Tambahkan produk pertama kamu dari form di atas.',
                    icon: Icons.inbox_rounded,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: products.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${_rupiah.format(p.price)} • ${p.category}'),
                          trailing: Chip(
                            label: Text(p.category),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final number = int.parse(digits);
    final formatted = NumberFormat('#,###', 'id_ID').format(number).replaceAll(',', '.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
