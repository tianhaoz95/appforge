import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart' show MyApp;

const _plans = ['Free', 'Pro', 'Ultra'];
const _models = [
  'gemini-3.1-flash-lite-preview',
  'gemini-2.0-flash',
  'gemini-2.5-pro',
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  bool? _isMinimized;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    _isMinimized ??= isMobile;

    final minimized = _isMinimized!;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/brand/logo.png', height: 32),
          const SizedBox(width: 10),
          const Text('MicroForge Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () {
              final app = MyApp.of(context);
              if (app == null) return;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              app.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          navigationRailTheme: const NavigationRailThemeData(
            elevation: 0,
            indicatorShape: StadiumBorder(),
          ),
          dividerTheme: const DividerThemeData(color: Colors.transparent),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: NavigationRail(
                    extended: !minimized,
                    minExtendedWidth: 160,
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    useIndicator: true,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.credit_card_outlined),
                        label: Text('Plan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        label: Text('Billing'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.smart_toy_outlined),
                        label: Text('Model'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        label: Text('Profile'),
                      ),
                    ],
                    trailing: Expanded(
                      child: Align(
                        alignment: minimized ? Alignment.bottomCenter : Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 20, left: minimized ? 0 : 16),
                          child: IconButton(
                            icon: Icon(minimized ? Icons.chevron_right : Icons.chevron_left),
                            onPressed: () => setState(() => _isMinimized = !minimized),
                            tooltip: minimized ? 'Expand' : 'Minimize',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isMobile)
                  Expanded(
                    child: _buildMainContent(user),
                  ),
              ],
            ),
            if (isMobile)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: minimized ? 72 : 160,
                top: 0,
                bottom: 0,
                width: size.width - 72,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: _buildMainContent(user),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: anim.drive(Tween(begin: const Offset(0.02, 0), end: Offset.zero)),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _buildTab(context, _tab, data, user),
          ),
        );
      },
    );
  }

  Widget _buildTab(BuildContext context, int index, Map<String, dynamic> data, User user) {
    switch (index) {
      case 0:
        return _PlanTab(data: data, uid: user.uid, onTabChange: (i) => setState(() => _tab = i));
      case 1:
        return _BillingTab(data: data, uid: user.uid);
      case 2:
        return _ModelTab(data: data, uid: user.uid);
      case 3:
        return _ProfileTab(user: user, data: data);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PlanTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  final ValueChanged<int> onTabChange;
  const _PlanTab({required this.data, required this.uid, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final current = data['plan'] as String? ?? 'Free';
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.stars_rounded, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subscription Plan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Choose the plan that fits your forging needs.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Center(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: _plans.map((plan) {
                    final selected = plan == current;
                    return _PlanCard(
                      plan: plan,
                      selected: selected,
                      onSelect: () async {
                        await FirebaseFirestore.instance.collection('users').doc(uid).set(
                          {'plan': plan}, SetOptions(merge: true));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Switched to $plan plan'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ));
                        }
                        
                        final hasBilling = (data['billing_name'] as String? ?? '').isNotEmpty && 
                                         (data['billing_email'] as String? ?? '').isNotEmpty;
                        if (plan != 'Free' && !hasBilling) {
                          onTabChange(1);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillingTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  const _BillingTab({required this.data, required this.uid});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _BillingSection(uid: uid, data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingSection extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _BillingSection({required this.uid, required this.data});

  @override
  State<_BillingSection> createState() => _BillingSectionState();
}

class _BillingSectionState extends State<_BillingSection> {
  bool _editing = false;
  bool _saving = false;
  late final _nameCtrl = TextEditingController(text: widget.data['billing_name'] as String? ?? '');
  late final _emailCtrl = TextEditingController(text: widget.data['billing_email'] as String? ?? '');
  late final _addressCtrl = TextEditingController(text: widget.data['billing_address'] as String? ?? '');
  late final _cityCtrl = TextEditingController(text: widget.data['billing_city'] as String? ?? '');
  late final _countryCtrl = TextEditingController(text: widget.data['billing_country'] as String? ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _addressCtrl.dispose();
    _cityCtrl.dispose(); _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
      'billing_name': _nameCtrl.text.trim(),
      'billing_email': _emailCtrl.text.trim(),
      'billing_address': _addressCtrl.text.trim(),
      'billing_city': _cityCtrl.text.trim(),
      'billing_country': _countryCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_rounded, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Text('Billing Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!_editing)
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                onPressed: () => setState(() => _editing = true),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (_editing) ...[
          _field(_nameCtrl, 'Full Name / Company', Icons.business_rounded),
          _field(_emailCtrl, 'Billing Email', Icons.email_outlined, type: TextInputType.emailAddress),
          _field(_addressCtrl, 'Address', Icons.location_on_outlined),
          Row(children: [
            Expanded(child: _field(_cityCtrl, 'City', Icons.location_city_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _field(_countryCtrl, 'Country', Icons.public_rounded)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Information'),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
          ]),
        ] else if (_nameCtrl.text.isEmpty && _emailCtrl.text.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.add_card_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('No billing information', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Add details for invoices and tax compliance.', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4))),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Add Billing Info'),
                ),
              ],
            ),
          ),
        ] else ...[
          _infoRow(Icons.person_outline, 'Name', _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text, cs),
          const Divider(height: 32),
          _infoRow(Icons.email_outlined, 'Email', _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text, cs),
          const Divider(height: 32),
          _infoRow(Icons.location_on_outlined, 'Address', _addressCtrl.text.isEmpty ? '—' : _addressCtrl.text, cs),
          const Divider(height: 32),
          _infoRow(Icons.location_city_rounded, 'City', _cityCtrl.text.isEmpty ? '—' : _cityCtrl.text, cs),
          const Divider(height: 32),
          _infoRow(Icons.public_rounded, 'Country', _countryCtrl.text.isEmpty ? '—' : _countryCtrl.text, cs),
        ],
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    ),
  );

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) => Row(
    children: [
      Icon(icon, size: 20, color: cs.primary),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}

class _PlanCard extends StatelessWidget {
  final String plan;
  final bool selected;
  final VoidCallback onSelect;
  const _PlanCard({required this.plan, required this.selected, required this.onSelect});

  static const _prices = {'Free': '\$0', 'Pro': '\$19', 'Ultra': '\$79'};
  static const _descs = {
    'Free': 'Perfect for exploring micro-app forging and community templates.',
    'Pro': 'For creators who need higher quotas and priority generation.',
    'Ultra': 'Enterprise-grade power with custom models and team tools.',
  };
  static const _features = {
    'Free': ['5 apps/day', 'Standard AI', 'Public links'],
    'Pro': ['Unlimited apps', 'Fast generation', 'Private history'],
    'Ultra': ['Team workspaces', 'Custom models', 'API access'],
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 8 : 0,
      shadowColor: selected ? cs.primary.withValues(alpha: 0.3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('CURRENT PLAN', style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            Text(plan, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_prices[plan]!, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.primary)),
                Text('/mo', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 20),
            Text(_descs[plan]!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), height: 1.5, fontSize: 13)),
            const Divider(height: 48),
            ...(_features[plan]!.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                  Text(f, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected ? null : onSelect,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(selected ? 'Active' : 'Select $plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  const _ModelTab({required this.data, required this.uid});

  @override
  Widget build(BuildContext context) {
    final current = data['model'] as String? ?? _models.first;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.psychology_rounded, color: cs.onTertiaryContainer),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Intelligence', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Configure the brain behind your forged apps.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              ..._models.map((model) {
                final selected = model == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: selected ? 4 : 0,
                    shadowColor: cs.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
                    ),
                    color: selected ? cs.primaryContainer.withValues(alpha: 0.1) : cs.surface,
                    child: InkWell(
                      onTap: () async {
                        await FirebaseFirestore.instance.collection('users').doc(uid).set(
                          {'model': model}, SetOptions(merge: true));
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: selected ? cs.primary : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                model.contains('pro') ? Icons.auto_awesome_rounded : Icons.bolt_rounded,
                                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 17, 
                                      color: selected ? cs.primary : null,
                                      letterSpacing: -0.5,
                                    )
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    model.contains('flash') 
                                      ? 'Flash series: High speed, low latency, great for most tasks.' 
                                      : 'Pro series: Maximum intelligence for complex reasoning.',
                                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (selected)
                              Icon(Icons.check_circle_rounded, color: cs.primary, size: 28)
                            else
                              Icon(Icons.radio_button_unchecked_rounded, color: cs.outlineVariant, size: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final User user;
  final Map<String, dynamic> data;
  const _ProfileTab({required this.user, required this.data});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final _nameCtrl = TextEditingController(text: widget.user.displayName ?? '');
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.user.updateDisplayName(_nameCtrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will permanently delete your account and all data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).delete();
      await widget.user.delete();
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          (widget.user.displayName?.isNotEmpty == true ? widget.user.displayName![0] : widget.user.email![0]).toUpperCase(),
                          style: TextStyle(fontSize: 36, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: widget.user.email,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Profile Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_forever_rounded, color: cs.error),
                      label: Text('Delete Account', style: TextStyle(color: cs.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _deleteAccount,
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

