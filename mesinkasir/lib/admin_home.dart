import 'package:flutter/material.dart';
import 'admin_products_screen.dart';
import 'manage_kasir_screen.dart';
import 'login_screen.dart';
import 'reports_screen.dart';
import 'stock_store_widget.dart';
import 'auth_store.dart';
import 'pengaturan_toko_screen.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthStore.logout();
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 1100 ? 4 : (w >= 780 ? 3 : 2);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: Theme.of(context).colorScheme.primary,
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _logout(context), // <-- tetap sama
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 14,
              ),
              title: const Text('Dashboard Pemilik'),
              background: const _HeaderBackground(
                title: 'Halo, Pemilik 👋',
                subtitle: 'Pantau bisnis kamu dari sini',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            sliver: SliverList(
              delegate: SliverChildListDelegate(const [
                _SummaryRow(),
                SizedBox(height: 16),
                _SectionTitle(
                  title: 'Menu Utama',
                  subtitle: 'Kelola operasional toko kamu',
                ),
                SizedBox(height: 12),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.count(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: w >= 600 ? 1.15 : 1.05,
              children: [
                _DashboardTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Laporan',
                  subtitle: 'Omset, transaksi, produk',
                  tone: _Tone.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                  },
                ),
                _DashboardTile(
                  icon: Icons.inventory_2_rounded,
                  title: 'Produk',
                  subtitle: 'Tambah, hapus, harga',
                  tone: _Tone.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminProductsScreen(),
                      ),
                    );
                  },
                ),
                _DashboardTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Akun Kasir',
                  subtitle: 'Tambah, nonaktifkan',
                  tone: _Tone.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageKasirScreen(),
                      ),
                    );
                  },
                ),
                _DashboardTile(
                  icon: Icons.warehouse_rounded,
                  title: 'Stok',
                  subtitle: 'Tambah & atur stok',
                  tone: _Tone.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StockScreen()),
                    );
                  },
                ),
                _DashboardTile(
                  icon: Icons.storefront_rounded,
                  title: 'Toko',
                  subtitle: 'Nama, alamat, pajak',
                  tone: _Tone.orange,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Toko: nanti kita bikin')),
                    );
                  },
                ),
                _DashboardTile(
                  icon: Icons.settings_rounded,
                  title: 'Pengaturan',
                  subtitle: 'Printer, metode bayar',
                  tone: _Tone.gray,
                  onTap: () {
                   Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PengaturanTokoScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderBackground({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primaryContainer],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _Blob(size: 220, color: Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _Blob(size: 260, color: Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900;

    final items = const [
      _SummaryItem(
        title: 'Pendapatan Hari Ini',
        value: 'Rp 0',
        icon: Icons.payments_rounded,
        tone: _Tone.green,
      ),
      _SummaryItem(
        title: 'Transaksi Hari Ini',
        value: '0',
        icon: Icons.receipt_long_rounded,
        tone: _Tone.blue,
      ),
      _SummaryItem(
        title: 'Produk Aktif',
        value: '0',
        icon: Icons.inventory_2_rounded,
        tone: _Tone.indigo,
      ),
    ];

    if (isWide) {
      return Row(
        children:
            items
                .map(
                  (e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: e,
                    ),
                  ),
                )
                .toList()
              ..removeLast(),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _Tone tone;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = _toneColor(tone, cs);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withOpacity(0.18), base.withOpacity(0.08)],
        ),
        border: Border.all(color: base.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: base.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: base),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final _Tone tone;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = _toneColor(tone, cs);

    return Material(
      color: cs.surface,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          base.withOpacity(0.22),
                          base.withOpacity(0.12),
                        ],
                      ),
                      border: Border.all(color: base.withOpacity(0.20)),
                    ),
                    child: Icon(icon, color: base),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: cs.onSurface.withOpacity(0.35),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Tone { blue, indigo, purple, teal, orange, gray, green }

Color _toneColor(_Tone tone, ColorScheme cs) {
  switch (tone) {
    case _Tone.blue:
      return Colors.blue.shade700;
    case _Tone.indigo:
      return Colors.indigo.shade700;
    case _Tone.purple:
      return Colors.purple.shade700;
    case _Tone.teal:
      return Colors.teal.shade700;
    case _Tone.orange:
      return Colors.orange.shade800;
    case _Tone.green:
      return Colors.green.shade700;
    case _Tone.gray:
      return cs.primary;
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
