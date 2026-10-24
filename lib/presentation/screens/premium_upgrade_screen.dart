import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';
import '../../platform/entitlement_billing_service.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final AppController controller;

  const PremiumUpgradeScreen({super.key, required this.controller});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  StoreBillingVendor _selectedStore = StoreBillingVendor.googlePlay;
  List<StoreProductDescriptor> _products = const <StoreProductDescriptor>[];
  String? _storeStatusBanner;

  @override
  void initState() {
    super.initState();
    _loadStoreProducts();
  }

  Future<void> _loadStoreProducts() async {
    final provider = widget.controller.entitlementService.providerFor(
      _selectedStore,
    );
    final items = await provider.querySubscriptionProducts();
    if (mounted) {
      setState(() => _products = items);
    }
  }

  Future<void> _attemptStorePurchase(String productId) async {
    final provider = widget.controller.entitlementService.providerFor(
      _selectedStore,
    );
    final result = await provider.initiateSubscriptionPurchase(productId);
    if (mounted) {
      setState(() => _storeStatusBanner = result.userMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.userMessage)),
      );
    }
  }

  Future<void> _attemptRestorePurchases() async {
    final provider = widget.controller.entitlementService.providerFor(
      _selectedStore,
    );
    final result = await provider.restoreStorePurchases();
    if (mounted) {
      setState(() => _storeStatusBanner = result.userMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.userMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final isPremium = widget.controller.isPremiumActive;
        final entitlement = widget.controller.entitlement;

        return GlassScaffold(
          themeSettings: widget.controller.themeSettings,
          appBar: AppBar(
            title: const Text('Smart Reminder Pro & Entitlements'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Hero Status Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        TierStatusBadge(isPremium: isPremium),
                        const Spacer(),
                        Text(
                          entitlement.vendor.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isPremium
                          ? 'All Premium Capabilities Unlocked'
                          : 'Upgrade to Smart Reminder & Voice Alarm Pro',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unlock Custom Spoken Voice Alarms (TTS), Advanced Recurrence Rules, Speech-to-Text Dictation, Home-Screen Widget, Auto Day/Night Themes, Local Backup/Restore, and an Ad-Free Experience.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Developer / QA Sandbox Entitlement Switch (Transparent & Non-Fake)
              GlassCard(
                borderColor: Colors.amber.withValues(alpha: 0.55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.science_outlined,
                          color: Colors.amber,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Developer / QA Entitlement Sandbox Override',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Live store purchases are never faked. Use this explicit QA Sandbox toggle to inspect and verify both Free-tier gating and Pro-tier features locally.',
                      style: TextStyle(fontSize: 12),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Local Pro Entitlement (QA Sandbox)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        isPremium
                            ? 'Active: All 7 Pro features unlocked for testing'
                            : 'Inactive: Standard Free tier restrictions enforced',
                      ),
                      value: isPremium,
                      onChanged: (bool val) {
                        widget.controller.setQaSandboxEntitlement(enabled: val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Store Billing Integration Point (Google Play Billing vs Amazon Appstore IAP)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Store Billing Provider Integration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<StoreBillingVendor>(
                      segments: const <ButtonSegment<StoreBillingVendor>>[
                        ButtonSegment<StoreBillingVendor>(
                          value: StoreBillingVendor.googlePlay,
                          icon: Icon(Icons.shop_two_outlined),
                          label: Text('Google Play Billing'),
                        ),
                        ButtonSegment<StoreBillingVendor>(
                          value: StoreBillingVendor.amazonAppstore,
                          icon: Icon(Icons.shopping_cart_outlined),
                          label: Text('Amazon Appstore IAP'),
                        ),
                      ],
                      selected: <StoreBillingVendor>{_selectedStore},
                      onSelectionChanged: (Set<StoreBillingVendor> s) {
                        setState(() {
                          _selectedStore = s.first;
                          _storeStatusBanner = null;
                        });
                        _loadStoreProducts();
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._products.map((sku) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    sku.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${sku.displayPrice} • SKU: ${sku.productId}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () =>
                                  _attemptStorePurchase(sku.productId),
                              child: const Text('Subscribe'),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _attemptRestorePurchases,
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Restore Store Purchases'),
                      ),
                    ),
                    if (_storeStatusBanner != null) ...<Widget>[
                      const Divider(),
                      Text(
                        _storeStatusBanner!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Free vs Pro Feature Comparison
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Included in Free Tier',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _FeatureBullet(
                      title: 'Basic Reminders & SQLite Persistence',
                      subtitle: 'Create, complete, snooze, search, and filter reminders offline',
                      unlocked: true,
                    ),
                    const _FeatureBullet(
                      title: 'One-Time Native Alarms & Basic Ringtones',
                      subtitle: 'Schedule exact Android AlarmManager wake-ups with preset tones',
                      unlocked: true,
                    ),
                    const _FeatureBullet(
                      title: 'Standard & Custom Categories',
                      subtitle: 'Personal, Work, Study, Health, Shopping, Other + safe reassignment',
                      unlocked: true,
                    ),
                    const _FeatureBullet(
                      title: 'Light, Dark & System Default Themes',
                      subtitle: 'Royal Nebula glassmorphism theme in Light or Dark mode',
                      unlocked: true,
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Premium Pro Features',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...PremiumFeature.values.map((feature) {
                      return _FeatureBullet(
                        title: feature.title,
                        subtitle: feature.description,
                        unlocked: isPremium,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool unlocked;

  const _FeatureBullet({
    required this.title,
    required this.subtitle,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 19,
            color: unlocked ? const Color(0xFF10B981) : Colors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
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
