import 'package:flutter/material.dart';
import 'auth_store.dart';

class ManageKasirScreen extends StatefulWidget {
  const ManageKasirScreen({super.key});

  @override
  State<ManageKasirScreen> createState() => _ManageKasirScreenState();
}

class _ManageKasirScreenState extends State<ManageKasirScreen> {
  final userCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    userCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  void create() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final u = userCtrl.text.trim();
    final p = pinCtrl.text.trim();

    AuthStore.createKasir(username: u, pin: p);

    userCtrl.clear();
    pinCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akun kasir berhasil dibuat ✅')),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kasirs = AuthStore.users.where((u) => u.role == 'kasir').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kasir'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _HeaderCard(
                      title: 'Manajemen Kasir',
                      subtitle: 'Buat akun kasir baru dan atur status aktif/nonaktif.',
                      icon: Icons.badge_rounded,
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Buat Akun Kasir',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: userCtrl,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Username kasir',
                                  hintText: 'Contoh: kasir01',
                                  prefixIcon: const Icon(Icons.person_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Username wajib diisi';
                                  if (s.length < 3) return 'Username terlalu pendek';
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) {
                                    return 'Hanya huruf/angka/underscore';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: pinCtrl,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'PIN kasir',
                                  hintText: '4-6 digit',
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'PIN wajib diisi';
                                  if (!RegExp(r'^\d+$').hasMatch(s)) return 'PIN harus angka';
                                  if (s.length < 4) return 'Minimal 4 digit';
                                  if (s.length > 6) return 'Maksimal 6 digit';
                                  return null;
                                },
                                onFieldSubmitted: (_) => create(),
                              ),
                              const SizedBox(height: 14),

                              SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: create,
                                  icon: const Icon(Icons.person_add_alt_1_rounded),
                                  label: const Text('Buat Akun Kasir'),
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
                          'Daftar Kasir',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        Chip(
                          avatar: const Icon(Icons.groups_rounded, size: 18),
                          label: Text('${kasirs.length} akun'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            if (kasirs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyState(
                    title: 'Belum ada kasir',
                    subtitle: 'Buat akun kasir pertama kamu dari form di atas.',
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
                      side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: kasirs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final k = kasirs[i];
                        final active = k.active;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: active
                                ? cs.primary.withOpacity(0.15)
                                : cs.error.withOpacity(0.12),
                            child: Icon(
                              active ? Icons.verified_rounded : Icons.block_rounded,
                              color: active ? cs.primary : cs.error,
                            ),
                          ),
                          title: Text(
                            k.username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(active ? 'Aktif' : 'Nonaktif'),
                          trailing: Switch.adaptive(
                            value: active,
                            onChanged: (_) {
                              AuthStore.toggleActive(k.username);
                              setState(() {});
                            },
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
          colors: [
            color.withOpacity(0.16),
            color.withOpacity(0.06),
          ],
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
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
