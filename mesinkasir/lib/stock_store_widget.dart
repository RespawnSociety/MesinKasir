import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_store.dart';
import 'rupiah_input_formatter.dart';

class _StockItem {
  final int id;
  final String name;
  final String unit;
  final int qty;
  final int buyPrice;
  final bool active;

  const _StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    required this.buyPrice,
    required this.active,
  });

  factory _StockItem.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return _StockItem(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? 'pcs').toString(),
      qty: (json['qty'] is int)
          ? json['qty'] as int
          : int.tryParse('${json['qty']}') ?? 0,
      buyPrice: (json['buy_price'] is int)
          ? json['buy_price'] as int
          : int.tryParse('${json['buy_price']}') ?? 0,
      active: active,
    );
  }
}

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

  bool _loading = true;
  final List<_StockItem> _stocks = [];

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
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString();
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
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  @override
  void initState() {
    super.initState();
    _fetchStocks();
  }

  Future<void> _fetchStocks() async {
    if (mounted) setState(() => _loading = true);

    final res = await http.get(
      Uri.parse('${AuthStore.baseUrl}/api/stocks'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      setState(() => _loading = false);
      return;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);

    _stocks.clear();
    if (list is List) {
      _stocks.addAll(
        list
            .map(
              (e) => _StockItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
      _stocks.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<bool> _updateStock(
    int id, {
    int? qty,
    int? buyPrice,
    bool? active,
    String? name,
    String? unit,
  }) async {
    final payload = <String, dynamic>{};
    if (qty != null) payload['qty'] = qty;
    if (buyPrice != null) payload['buy_price'] = buyPrice;
    if (active != null) payload['active'] = active;
    if (name != null) payload['name'] = name;
    if (unit != null) payload['unit'] = unit;

    final res = await http.patch(
      Uri.parse('${AuthStore.baseUrl}/api/stocks/$id'),
      headers: await _authHeaders(json: true),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<bool> _createStock({
    required String name,
    required String unit,
    required int qty,
    required int buyPrice,
    required bool active,
  }) async {
    final res = await http.post(
      Uri.parse('${AuthStore.baseUrl}/api/stocks'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'name': name,
        'unit': unit,
        'qty': qty,
        'buy_price': buyPrice,
        'active': active,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<bool> _deleteStock(int id) async {
    final res = await http.delete(
      Uri.parse('${AuthStore.baseUrl}/api/stocks/$id'),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errMsg(res))));
      return false;
    }

    await _fetchStocks();
    return true;
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_UpsertStockResult>(
      context: context,
      barrierDismissible: false, // ✅ lebih aman buat user awam
      builder: (_) => const _UpsertStockDialog(title: 'Tambah Stock'),
    );

    if (result == null) return;

    final ok = await _createStock(
      name: result.name,
      unit: result.unit,
      qty: result.qty,
      buyPrice: result.buyPrice,
      active: result.active,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock berhasil dibuat ✅')));
    }
  }

  Future<void> _openEditDialog(_StockItem s) async {
    final result = await showDialog<_UpsertStockResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpsertStockDialog(title: 'Ubah Stock', initial: s),
    );

    if (result == null) return;

    final ok = await _updateStock(
      s.id,
      name: result.name,
      unit: result.unit,
      qty: result.qty,
      buyPrice: result.buyPrice,
      active: result.active,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock berhasil diupdate ✅')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Barang'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _fetchStocks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),

      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _stocks.isEmpty
            ? const Center(child: Text('Belum ada stock'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: _stocks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final s = _stocks[i];
                  return _StockFriendlyCard(
                    item: s,
                    buyPriceText: rupiah.format(s.buyPrice),
                    onEdit: () => _openEditDialog(s),
                    onToggleActive: (v) => _updateStock(s.id, active: v),
                    onQtyChanged: (q) => _updateStock(s.id, qty: q),
                    onDelete: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Hapus Stock'),
                          content: Text('Yakin hapus "${s.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) await _deleteStock(s.id);
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Card versi "ramah orang tua":
/// - tombol besar
/// - qty pakai stepper + input
/// - edit pakai tombol "Ubah"
class _StockFriendlyCard extends StatefulWidget {
  const _StockFriendlyCard({
    required this.item,
    required this.buyPriceText,
    required this.onEdit,
    required this.onToggleActive,
    required this.onQtyChanged,
    required this.onDelete,
  });

  final _StockItem item;
  final String buyPriceText;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onDelete;

  @override
  State<_StockFriendlyCard> createState() => _StockFriendlyCardState();
}

class _StockFriendlyCardState extends State<_StockFriendlyCard> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _StockFriendlyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.qty != widget.item.qty) {
      _qtyCtrl.text = widget.item.qty.toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  int _parseQty() {
    final raw = _qtyCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'gram':
        return 'Gram';
      case 'kg':
        return 'Kilogram';
      default:
        return 'Pcs';
    }
  }

  Future<void> _setQty(int value) async {
    final v = value < 0 ? 0 : value;
    _qtyCtrl.text = v.toString();
    widget.onQtyChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.item;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withOpacity(0.75);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nama + Unit + Switch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(text: 'Unit: ${_unitLabel(s.unit)}'),
                          _Pill(text: 'Harga: ${widget.buyPriceText}'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      'Aktif',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Switch(value: s.active, onChanged: widget.onToggleActive),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            Text(
              'Jumlah (Qty)',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Qty stepper besar
            Row(
              children: [
                _BigIconButton(
                  icon: Icons.remove,
                  onPressed: () => _setQty(s.qty - 1),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSubmitted: (_) => widget.onQtyChanged(_parseQty()),
                  ),
                ),
                const SizedBox(width: 10),
                _BigIconButton(
                  icon: Icons.add,
                  onPressed: () => _setQty(s.qty + 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onQtyChanged(_parseQty()),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Simpan Qty',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Aksi besar: Ubah & Hapus
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigIconButton extends StatelessWidget {
  const _BigIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 26),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withOpacity(0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _UpsertStockResult {
  final String name;
  final String unit;
  final int qty;
  final int buyPrice;
  final bool active;

  const _UpsertStockResult({
    required this.name,
    required this.unit,
    required this.qty,
    required this.buyPrice,
    required this.active,
  });
}

class _UpsertStockDialog extends StatefulWidget {
  const _UpsertStockDialog({required this.title, this.initial});

  final String title;
  final _StockItem? initial;

  @override
  State<_UpsertStockDialog> createState() => _UpsertStockDialogState();
}

class _UpsertStockDialogState extends State<_UpsertStockDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _buy;

  bool _active = true;
  String _unit = 'pcs';

  final List<({String value, String label})> _units = const [
    (value: 'pcs', label: 'Pcs'),
    (value: 'gram', label: 'Gram'),
    (value: 'kg', label: 'Kilogram'),
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _qty = TextEditingController(text: (i?.qty ?? 0).toString());
    _buy = TextEditingController(text: (i?.buyPrice ?? 0).toString());
    _active = i?.active ?? true;
    _unit = i?.unit ?? 'pcs';
  }

  int _parseInt(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _buy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Nama Stock',
                    hintText: 'Contoh: Tepung Terigu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Nama wajib diisi';
                    if (s.length < 2) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  items: _units
                      .map(
                        (u) => DropdownMenuItem<String>(
                          value: u.value,
                          child: Text(u.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (_) {
                          final q = _parseInt(_qty);
                          if (q < 0) return 'Qty tidak boleh minus';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _buy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RupiahInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Harga Beli',
                          hintText: 'Contoh: 12000',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (_) {
                          final p = _parseInt(_buy);
                          if (p < 0) return 'Harga tidak boleh minus';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text(
                    'Stock Aktif',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Kalau dimatikan, stock tidak tampil untuk dipakai.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(
                    context,
                    _UpsertStockResult(
                      name: _name.text.trim(),
                      unit: _unit,
                      qty: _parseInt(_qty),
                      buyPrice: _parseInt(_buy),
                      active: _active,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
