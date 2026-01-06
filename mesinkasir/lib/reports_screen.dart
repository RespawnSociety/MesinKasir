import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  late final List<FinanceTxn> _allTxns = _mockTxns();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txns = _allTxns.where((t) => _inRange(t.at, _range)).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final summary = FinanceSummary.from(txns);

    final perDay = _groupByDay(txns);
    final dayKeys = perDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: cs.primary,
            titleSpacing: 16,
            title: const Text('Laporan Keuangan'),
            actions: [
              IconButton(
                tooltip: 'Pilih tanggal',
                icon: const Icon(Icons.date_range_rounded),
                onPressed: () => _pickRange(context),
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                title: 'Ringkasan Keuangan',
                subtitle: _rangeLabel(_range),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _KpiGrid(summary: summary),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Ikhtisar',
                  subtitle:
                      'Pendapatan vs Pengeluaran, lalu Penghasilan Pemilik',
                ),
                const SizedBox(height: 12),
                _BreakdownCard(summary: summary),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Per Hari',
                  subtitle: 'Ringkasan harian dalam rentang yang dipilih',
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: dayKeys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final day = dayKeys[i];
                final list = perDay[day]!;
                final s = FinanceSummary.from(list);
                return _DayTile(
                  day: day,
                  summary: s,
                  onTap: () => _openDay(context, day, list),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionTitle(
                  title: 'Transaksi',
                  subtitle: 'Data transaksi di rentang ini',
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: txns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = txns[i];
                return _TxnTile(txn: t);
              },
            ),
          ),
          if (txns.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Belum ada transaksi pada periode ini.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      helpText: 'Pilih rentang laporan',
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  void _openDay(BuildContext context, DateTime day, List<FinanceTxn> txns) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayReportScreen(day: day, txns: txns),
      ),
    );
  }
}

class DayReportScreen extends StatelessWidget {
  final DateTime day;
  final List<FinanceTxn> txns;

  const DayReportScreen({super.key, required this.day, required this.txns});

  @override
  Widget build(BuildContext context) {
    final summary = FinanceSummary.from(txns);
    final dateText = DateFormat('EEE, dd MMM yyyy', 'id_ID').format(day);

    return Scaffold(
      appBar: AppBar(titleSpacing: 16, title: const Text('Laporan Keuangan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KpiGrid(summary: summary),
          const SizedBox(height: 16),
          _BreakdownCard(summary: summary),
          const SizedBox(height: 16),
          Text(
            'Transaksi',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...txns.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TxnTile(txn: t),
            ),
          ),
          if (txns.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Tidak ada transaksi pada hari ini.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinanceSummary {
  final int salesCount;
  final int expenseCount;
  final int ownerCount;

  final int revenue;
  final int expenses;
  final int ownerDraw;

  final int grossProfit;
  final int netProfit;

  const FinanceSummary({
    required this.salesCount,
    required this.expenseCount,
    required this.ownerCount,
    required this.revenue,
    required this.expenses,
    required this.ownerDraw,
    required this.grossProfit,
    required this.netProfit,
  });

  static FinanceSummary from(List<FinanceTxn> txns) {
    int revenue = 0;
    int expenses = 0;
    int ownerDraw = 0;
    int salesCount = 0;
    int expenseCount = 0;
    int ownerCount = 0;

    for (final t in txns) {
      switch (t.type) {
        case FinanceType.sale:
          revenue += t.amount;
          salesCount++;
          break;
        case FinanceType.expense:
          expenses += t.amount;
          expenseCount++;
          break;
        case FinanceType.ownerDraw:
          ownerDraw += t.amount;
          ownerCount++;
          break;
      }
    }

    final grossProfit = revenue - expenses;
    final netProfit = grossProfit - ownerDraw;

    return FinanceSummary(
      salesCount: salesCount,
      expenseCount: expenseCount,
      ownerCount: ownerCount,
      revenue: revenue,
      expenses: expenses,
      ownerDraw: ownerDraw,
      grossProfit: grossProfit,
      netProfit: netProfit,
    );
  }
}

enum FinanceType { sale, expense, ownerDraw }

class FinanceTxn {
  final String id;
  final DateTime at;
  final FinanceType type;
  final int amount;
  final String title;
  final String? note;

  const FinanceTxn({
    required this.id,
    required this.at,
    required this.type,
    required this.amount,
    required this.title,
    this.note,
  });
}

class _KpiGrid extends StatelessWidget {
  final FinanceSummary summary;
  const _KpiGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 900 ? 4 : (w >= 620 ? 3 : 2);

        final items = [
          _KpiCard(
            label: 'Pendapatan',
            value: rupiah(summary.revenue),
            icon: Icons.trending_up_rounded,
            color: Colors.green.shade700,
          ),
          _KpiCard(
            label: 'Pengeluaran',
            value: rupiah(summary.expenses),
            icon: Icons.trending_down_rounded,
            color: Colors.red.shade700,
          ),
          _KpiCard(
            label: 'Penghasilan Pemilik',
            value: rupiah(summary.ownerDraw),
            icon: Icons.wallet_rounded,
            color: Colors.blue.shade700,
          ),
          _KpiCard(
            label: 'Laba Bersih',
            value: rupiah(summary.netProfit),
            icon: Icons.savings_rounded,
            color: summary.netProfit >= 0 ? Colors.teal.shade700 : cs.error,
          ),
        ];

        return GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: w >= 620 ? 1.55 : 1.35,
          children: items,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withOpacity(0.16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final FinanceSummary summary;
  const _BreakdownCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final revenue = summary.revenue.toDouble();
    final expenses = summary.expenses.toDouble();
    final owner = summary.ownerDraw.toDouble();
    final total = (revenue + expenses + owner);
    final r = total == 0 ? 0.0 : revenue / total;
    final e = total == 0 ? 0.0 : expenses / total;
    final o = total == 0 ? 0.0 : owner / total;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        color: cs.surface,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perhitungan',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _Line(
            label: 'Pendapatan (Sales)',
            value: rupiah(summary.revenue),
            color: Colors.green.shade700,
            trailing: '${summary.salesCount} trx',
          ),
          const SizedBox(height: 8),
          _Line(
            label: 'Pengeluaran (Operasional)',
            value: rupiah(summary.expenses),
            color: Colors.red.shade700,
            trailing: '${summary.expenseCount} item',
          ),
          const SizedBox(height: 8),
          _Line(
            label: 'Penghasilan Pemilik (Owner Draw)',
            value: rupiah(summary.ownerDraw),
            color: Colors.blue.shade700,
            trailing: '${summary.ownerCount} item',
          ),
          const SizedBox(height: 12),
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: cs.surfaceContainerHighest.withOpacity(0.7),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  flex: (r * 1000).round(),
                  child: Container(
                    color: Colors.green.shade700.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  flex: (e * 1000).round(),
                  child: Container(color: Colors.red.shade700.withOpacity(0.7)),
                ),
                Expanded(
                  flex: (o * 1000).round(),
                  child: Container(
                    color: Colors.blue.shade700.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Line(
            label: 'Laba Kotor (Pendapatan - Pengeluaran)',
            value: rupiah(summary.grossProfit),
            color: Colors.teal.shade700,
          ),
          const SizedBox(height: 8),
          _Line(
            label: 'Laba Bersih (Laba Kotor - Penghasilan Pemilik)',
            value: rupiah(summary.netProfit),
            color: summary.netProfit >= 0 ? Colors.teal.shade700 : cs.error,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? trailing;

  const _Line({
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
        const SizedBox(width: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime day;
  final FinanceSummary summary;
  final VoidCallback onTap;

  const _DayTile({
    required this.day,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateText = DateFormat('EEE, dd MMM yyyy', 'id_ID').format(day);

    return Material(
      color: cs.surface,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Mini(
                      label: 'Pendapatan',
                      value: rupiah(summary.revenue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Mini(
                      label: 'Pengeluaran',
                      value: rupiah(summary.expenses),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Mini(
                      label: 'Penghasilan Pemilik',
                      value: rupiah(summary.ownerDraw),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Mini(
                      label: 'Laba Bersih',
                      value: rupiah(summary.netProfit),
                      valueColor: summary.netProfit >= 0
                          ? Colors.teal.shade800
                          : cs.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Mini({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.55),
        ),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final FinanceTxn txn;
  const _TxnTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    late final Color color;
    late final IconData icon;
    late final String typeText;

    switch (txn.type) {
      case FinanceType.sale:
        color = Colors.green.shade700;
        icon = Icons.trending_up_rounded;
        typeText = 'Pendapatan';
        break;
      case FinanceType.expense:
        color = Colors.red.shade700;
        icon = Icons.trending_down_rounded;
        typeText = 'Pengeluaran';
        break;
      case FinanceType.ownerDraw:
        color = Colors.blue.shade700;
        icon = Icons.wallet_rounded;
        typeText = 'Penghasilan Pemilik';
        break;
    }

    final dateText = DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(txn.at);

    return Material(
      color: cs.surface,
      elevation: 1.2,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withOpacity(0.16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$typeText • $dateText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  if ((txn.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      txn.note!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              rupiah(txn.amount),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
          ],
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

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

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
                    Icons.bar_chart_rounded,
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

bool _inRange(DateTime dt, DateTimeRange r) {
  final s = DateTime(r.start.year, r.start.month, r.start.day);
  final e = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);
  return !dt.isBefore(s) && !dt.isAfter(e);
}

String _rangeLabel(DateTimeRange r) {
  final f = DateFormat('dd MMM yyyy', 'id_ID');
  return '${f.format(r.start)} - ${f.format(r.end)}';
}

String rupiah(int v) {
  final f = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return f.format(v);
}

Map<DateTime, List<FinanceTxn>> _groupByDay(List<FinanceTxn> txns) {
  final map = <DateTime, List<FinanceTxn>>{};
  for (final t in txns) {
    final key = DateTime(t.at.year, t.at.month, t.at.day);
    map.putIfAbsent(key, () => []);
    map[key]!.add(t);
  }
  return map;
}

List<FinanceTxn> _mockTxns() {
  final now = DateTime.now();
  DateTime d(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysAgo))
          .add(Duration(hours: hour, minutes: minute));

  return [
    FinanceTxn(
      id: 'S1',
      at: d(0, 9, 12),
      type: FinanceType.sale,
      amount: 350000,
      title: 'Penjualan',
      note: 'Tunai',
    ),
    FinanceTxn(
      id: 'S2',
      at: d(0, 12, 30),
      type: FinanceType.sale,
      amount: 540000,
      title: 'Penjualan',
      note: 'QRIS',
    ),
    FinanceTxn(
      id: 'E1',
      at: d(0, 14, 15),
      type: FinanceType.expense,
      amount: 120000,
      title: 'Beli plastik & kemasan',
      note: 'Operasional',
    ),
    FinanceTxn(
      id: 'O1',
      at: d(0, 18, 5),
      type: FinanceType.ownerDraw,
      amount: 200000,
      title: 'Ambil kas pemilik',
      note: 'Penghasilan pemilik',
    ),
    FinanceTxn(
      id: 'S3',
      at: d(1, 10, 5),
      type: FinanceType.sale,
      amount: 420000,
      title: 'Penjualan',
      note: 'Tunai',
    ),
    FinanceTxn(
      id: 'E2',
      at: d(1, 13, 40),
      type: FinanceType.expense,
      amount: 80000,
      title: 'Parkir & bensin',
      note: 'Operasional',
    ),
    FinanceTxn(
      id: 'S4',
      at: d(2, 11, 20),
      type: FinanceType.sale,
      amount: 610000,
      title: 'Penjualan',
      note: 'Transfer',
    ),
    FinanceTxn(
      id: 'E3',
      at: d(2, 16, 10),
      type: FinanceType.expense,
      amount: 250000,
      title: 'Belanja bahan',
      note: 'Operasional',
    ),
    FinanceTxn(
      id: 'O2',
      at: d(3, 17, 0),
      type: FinanceType.ownerDraw,
      amount: 150000,
      title: 'Ambil kas pemilik',
      note: 'Penghasilan pemilik',
    ),
    FinanceTxn(
      id: 'S5',
      at: d(4, 9, 45),
      type: FinanceType.sale,
      amount: 280000,
      title: 'Penjualan',
      note: 'Tunai',
    ),
    FinanceTxn(
      id: 'E4',
      at: d(4, 15, 25),
      type: FinanceType.expense,
      amount: 60000,
      title: 'Kopi & air galon',
      note: 'Operasional',
    ),
  ];
}
