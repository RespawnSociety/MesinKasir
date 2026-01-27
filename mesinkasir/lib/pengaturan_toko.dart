import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'auth_store.dart';

class PengaturTokoScreen extends StatefulWidget {
  const PengaturTokoScreen({super.key});

  @override
  State<PengaturTokoScreen> createState() => _PengaturTokoScreenState();
}

class _PengaturTokoScreenState extends State<PengaturTokoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _pajakCtrl = TextEditingController(text: '0.00');

  bool _loading = true;
  bool _saving = false;

  // ✅ API endpoints (sesuai controller Laravel yang kita buat)
  Uri get _getUri => Uri.parse('${AuthStore.baseUrl}/api/store-settings');
  Uri get _putUri => Uri.parse('${AuthStore.baseUrl}/api/store-settings');

  dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _authHeaders({bool jsonBody = false}) async {
    final t = await AuthStore.token();
    final h = <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
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

  double _parseTaxPercent() {
    final raw = _pajakCtrl.text.trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  void _logRes(String tag, http.Response res) {
    // Biar gampang debug kalau API ngambek
    debugPrint('[$tag] status=${res.statusCode}');
    debugPrint('[$tag] body=${res.body}');
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    _pajakCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await http.get(_getUri, headers: await _authHeaders());
      _logRes('GET store-settings', res);

      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
        setState(() => _loading = false);
        return;
      }

      final decoded = _tryJson(res.body);

      // Terima format:
      // {data:{...}} (sesuai controller) atau {...}
      final data = (decoded is Map && decoded['data'] is Map)
          ? Map<String, dynamic>.from(decoded['data'])
          : (decoded is Map)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};

      _namaCtrl.text = (data['store_name'] ?? '').toString();
      _alamatCtrl.text = (data['store_address'] ?? '').toString();

      final tax = data['tax_percent'] ?? 0;
      final taxNum = (tax is num) ? tax.toDouble() : (double.tryParse('$tax') ?? 0.0);
      _pajakCtrl.text = taxNum.toStringAsFixed(2);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final payload = {
        'store_name': _namaCtrl.text.trim(),
        'store_address': _alamatCtrl.text.trim(),
        'tax_percent': _parseTaxPercent(),
      };

      final res = await http.put(
        _putUri,
        headers: await _authHeaders(jsonBody: true),
        body: jsonEncode(payload),
      );
      _logRes('PUT store-settings', res);

      if (res.statusCode != 200 && res.statusCode != 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errMsg(res))));
        setState(() => _saving = false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan toko tersimpan ✅')));
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengatur Toko'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading || _saving ? null : _fetchSettings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Toko',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _namaCtrl,
                              enabled: !_saving,
                              decoration: InputDecoration(
                                labelText: 'Nama Toko',
                                hintText: 'Contoh: Toko Sungaibudi',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Nama toko wajib diisi';
                                if (s.length < 2) return 'Nama toko terlalu pendek';
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _alamatCtrl,
                              enabled: !_saving,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Alamat Toko',
                                hintText: 'Contoh: Jl. Mawar No. 12, Jakarta',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),

                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _pajakCtrl,
                              enabled: !_saving,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,2})?$')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Pajak (%)',
                                hintText: 'Contoh: 11.00',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (_) {
                                final v = _parseTaxPercent();
                                if (v < 0) return 'Pajak tidak boleh minus';
                                if (v > 100) return 'Pajak maksimal 100%';
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _saving ? 'Menyimpan...' : 'Simpan',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Catatan: Pajak disimpan dalam persen (contoh 11.00).',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
      ),
    );
  }
}
