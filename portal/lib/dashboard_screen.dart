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
          duration: const Duration(milliseconds: 300),
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
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscription Plan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Current plan: $current', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 20,
                runSpacing: 20,
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
                          SnackBar(content: Text('Switched to $plan plan')));
                      }
                      
                      // Navigate to billing information if selecting a paid plan but info is missing
                      final hasBilling = (data['billing_name'] as String? ?? '').isNotEmpty && 
                                       (data['billing_email'] as String? ?? '').isNotEmpty;
                      if (plan != 'Free' && !hasBilling) {
                        onTabChange(1); // Billing tab index
                      }
                    },
                  );
                }).toList(),
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
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _BillingSection(uid: uid, data: data),
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
            Text('Billing Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!_editing)
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                onPressed: () => setState(() => _editing = true),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_editing) ...[
          _field(_nameCtrl, 'Full Name / Company'),
          _field(_emailCtrl, 'Billing Email', type: TextInputType.emailAddress),
          _field(_addressCtrl, 'Address'),
          Row(children: [
            Expanded(child: _field(_cityCtrl, 'City')),
            const SizedBox(width: 12),
            Expanded(child: _field(_countryCtrl, 'Country')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
          ]),
        ] else if (_nameCtrl.text.isEmpty && _emailCtrl.text.isEmpty &&
            _addressCtrl.text.isEmpty && _cityCtrl.text.isEmpty && _countryCtrl.text.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No billing information yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Add your details for invoicing and receipts.', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.35))),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Add Billing Info'),
                ),
              ],
            ),
          ),
        ] else ...[
          _infoRow('Name', _nameCtrl.text.isEmpty ? '—' : _nameCtrl.text, cs),
          _infoRow('Email', _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text, cs),
          _infoRow('Address', _addressCtrl.text.isEmpty ? '—' : _addressCtrl.text, cs),
          _infoRow('City', _cityCtrl.text.isEmpty ? '—' : _cityCtrl.text, cs),
          _infoRow('Country', _countryCtrl.text.isEmpty ? '—' : _countryCtrl.text, cs),
        ],
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    ),
  );

  Widget _infoRow(String label, String value, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13))),
      const SizedBox(width: 12),
      Text(value, style: const TextStyle(fontSize: 13)),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String plan;
  final bool selected;
  final VoidCallback onSelect;
  const _PlanCard({required this.plan, required this.selected, required this.onSelect});

  static const _prices = {'Free': '\$0', 'Pro': '\$19', 'Ultra': '\$79'};
  static const _descs = {
    'Free': 'Basic forging, community templates, local previews.',
    'Pro': 'Higher quota, priority generation, saved history.',
    'Ultra': 'Largest quota, advanced models, team controls.',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.4) : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_prices[plan]!, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_descs[plan]!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selected ? null : onSelect,
              child: Text(selected ? 'Current Plan' : 'Select'),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Model', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Choose the model used for app generation.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 32),
              ..._models.map((model) {
                final selected = model == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
                    ),
                    tileColor: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
                    leading: Icon(Icons.smart_toy_outlined, color: selected ? cs.primary : null),
                    title: Text(model, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                    trailing: selected ? Icon(Icons.check_circle, color: cs.primary) : null,
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('users').doc(uid).set(
                        {'model': model}, SetOptions(merge: true));
                    },
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
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
            child: const Text('Delete'),
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
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  (widget.user.displayName?.isNotEmpty == true ? widget.user.displayName![0] : widget.user.email![0]).toUpperCase(),
                  style: TextStyle(fontSize: 28, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.user.email,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.delete_forever, color: cs.error),
                  label: Text('Delete Account', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: cs.error)),
                  onPressed: _deleteAccount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
