import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'auth_store.dart';

class ProductCategory {
  final int id;
  final String name;
  bool active;

  ProductCategory({required this.id, required this.name, required this.active});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
            ? rawActive == 1
            : (rawActive?.toString().toLowerCase() == '1' ||
                rawActive?.toString().toLowerCase() == 'true');

    return ProductCategory(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      active: active,
    );
  }
}

class PengaturanTokoScreen extends StatefulWidget {
  const PengaturanTokoScreen({super.key});

  @override
  State<PengaturanTokoScreen> createState() => _PengaturanTokoScreenState();
}

class _PengaturanTokoScreenState extends State<PengaturanTokoScreen> {
  static const _storage = FlutterSecureStorage();

  static const _kPrinterKey = 'store_printer_settings';
  static const _kPayModesKey = 'store_payment_modes';

  final _printerNameCtrl = TextEditingController();
  final _printerIpCtrl = TextEditingController();
  final _printerPortCtrl = TextEditingController(text: '9100');
  String _printerType = 'network';

  final List<String> _allPayModes = const ['Tunai', 'QRIS', 'Debit/Kartu', 'Transfer'];
  final Set<String> _enabledPayModes = {};

  final _catNameCtrl = TextEditingController();
  final List<ProductCategory> _categories = [];
  final Set<int> _busyCatIds = {};
  bool _loading = true;
  bool _loadingCats = true;
  bool _savingPrinter = false;
  bool _savingCat = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() => _loading = true);
    await _loadLocalSettings();
    await _fetchCategories();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _printerNameCtrl.dispose();
    _printerIpCtrl.dispose();
    _printerPortCtrl.dispose();
    _catNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    final printerRaw = await _storage.read(key: _kPrinterKey);
    if (printerRaw != null && printerRaw.isNotEmpty) {
      try {
        final m = jsonDecode(printerRaw) as Map<String, dynamic>;
        _printerType = (m['type'] ?? 'network').toString();
        _printerNameCtrl.text = (m['name'] ?? '').toString();
        _printerIpCtrl.text = (m['ip'] ?? '').toString();
        _printerPortCtrl.text = (m['port'] ?? '9100').toString();
      } catch (_) {}
    }

    final payRaw = await _storage.read(key: _kPayModesKey);
    _enabledPayModes.clear();
    if (payRaw != null && payRaw.isNotEmpty) {
      try {
        final list = jsonDecode(payRaw);
        if (list is List) {
          _enabledPayModes.addAll(list.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    if (_enabledPayModes.isEmpty) {
      _enabledPayModes.addAll(_allPayModes);
    }
  }

  Future<void> _savePrinter() async {
    setState(() => _savingPrinter = true);

    final data = {
      'type': _printerType,
      'name': _printerNameCtrl.text.trim(),
      'ip': _printerIpCtrl.text.trim(),
      'port': _printerPortCtrl.text.trim(),
    };

    await _storage.write(key: _kPrinterKey, value: jsonEncode(data));

    if (!mounted) return;
    setState(() => _savingPrinter = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan printer tersimpan ✅')),
    );
  }

  Future<void> _savePayModes() async {
    await _storage.write(key: _kPayModesKey, value: jsonEncode(_enabledPayModes.toList()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mode bayar tersimpan ✅')),
    );
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

  Future<void> _fetchCategories() async {
    setState(() => _loadingCats = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/categories'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 401) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token expired, silakan login ulang')),
        );
      }
      if (mounted) setState(() => _loadingCats = false);
      return;
    }

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
        list.map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
    }

    if (mounted) setState(() => _loadingCats = false);
  }

  Future<void> _createCategory() async {
    final name = _catNameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingCat = true);

    final res = await http.post(
      Uri.parse('${AuthStore.baseUrl}/api/categories'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'name': name}),
    );

    setState(() => _savingCat = false);

    if (res.statusCode == 401) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token expired, login ulang')),
      );
      return;
    }

    if (res.statusCode != 201 && res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(res))),
      );
      return;
    }

    _catNameCtrl.clear();
    await _fetchCategories();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kategori berhasil dibuat ✅')),
    );
  }

  Future<void> _setCategoryActive(ProductCategory c, bool active) async {
    setState(() => _busyCatIds.add(c.id));

    final res = await http.patch(
      Uri.parse('${AuthStore.baseUrl}/api/categories/${c.id}/active'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'active': active}),
    );

    setState(() => _busyCatIds.remove(c.id));

    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(res))),
      );
      return;
    }

    c.active = active;
    if (mounted) setState(() {});
  }

  Future<void> _deleteCategory(ProductCategory c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${c.name}"?'),
        content: const Text('Kategori akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busyCatIds.add(c.id));

    final res = await http.delete(
      Uri.parse('${AuthStore.baseUrl}/api/categories/${c.id}'),
      headers: await _authHeaders(),
    );

    setState(() => _busyCatIds.remove(c.id));

    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(res))),
      );
      return;
    }

    _categories.removeWhere((x) => x.id == c.id);
    if (mounted) setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kategori dihapus ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await _fetchCategories();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _initAll,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _HeaderCard(
                              title: 'Pengaturan Toko',
                              subtitle: 'Atur printer, mode bayar, dan kategori produk.',
                              icon: Icons.settings_rounded,
                            ),
                            const SizedBox(height: 14),

                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Printer',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: _printerType,
                                      items: const [
                                        DropdownMenuItem(value: 'network', child: Text('Network (IP)')),
                                        DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth')),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _printerType = v);
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Tipe printer',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _printerNameCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Nama printer (opsional)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_printerType == 'network') ...[
                                      TextFormField(
                                        controller: _printerIpCtrl,
                                        keyboardType: TextInputType.url,
                                        decoration: InputDecoration(
                                          labelText: 'IP printer',
                                          hintText: 'contoh: 192.168.1.50',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _printerPortCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Port',
                                          hintText: '9100',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    SizedBox(
                                      height: 48,
                                      child: FilledButton.icon(
                                        onPressed: _savingPrinter ? null : _savePrinter,
                                        icon: const Icon(Icons.save_rounded),
                                        label: Text(_savingPrinter ? 'Menyimpan...' : 'Simpan Printer'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Mode Bayar',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._allPayModes.map((m) {
                                      final on = _enabledPayModes.contains(m);
                                      return SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(m),
                                        value: on,
                                        onChanged: (v) {
                                          setState(() {
                                            if (v) {
                                              _enabledPayModes.add(m);
                                            } else {
                                              _enabledPayModes.remove(m);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 48,
                                      child: FilledButton.icon(
                                        onPressed: _savePayModes,
                                        icon: const Icon(Icons.save_rounded),
                                        label: const Text('Simpan Mode Bayar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Kategori Produk',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                        if (_loadingCats)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _catNameCtrl,
                                            decoration: InputDecoration(
                                              labelText: 'Nama kategori',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          height: 50,
                                          child: FilledButton(
                                            onPressed: _savingCat ? null : _createCategory,
                                            child: Text(_savingCat ? '...' : 'Tambah'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_categories.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: cs.surfaceContainerHighest.withOpacity(0.35),
                                        ),
                                        child: const Text('Belum ada kategori.'),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _categories.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (_, i) {
                                          final c = _categories[i];
                                          final busy = _busyCatIds.contains(c.id);

                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            subtitle: Text(c.active ? 'Aktif' : 'Nonaktif'),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Switch.adaptive(
                                                  value: c.active,
                                                  onChanged: busy ? null : (v) => _setCategoryActive(c, v),
                                                ),
                                                IconButton(
                                                  onPressed: busy ? null : () => _deleteCategory(c),
                                                  icon: const Icon(Icons.delete_outline_rounded),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
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
          colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.18)),
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
