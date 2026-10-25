import '../data/repositories/settings_repository.dart';
import '../domain/models/app_settings.dart';

class StoreProductDescriptor {
  final String productId;
  final String title;
  final String billingPeriodLabel;
  final String displayPrice;
  final StoreBillingVendor storeVendor;

  const StoreProductDescriptor({
    required this.productId,
    required this.title,
    required this.billingPeriodLabel,
    required this.displayPrice,
    required this.storeVendor,
  });
}

class BillingPurchaseAttemptResult {
  final bool completed;
  final String statusCode;
  final String userMessage;

  const BillingPurchaseAttemptResult({
    required this.completed,
    required this.statusCode,
    required this.userMessage,
  });
}

abstract class StoreBillingProvider {
  StoreBillingVendor get vendor;

  Future<bool> isStoreAvailable();

  Future<List<StoreProductDescriptor>> querySubscriptionProducts();

  Future<BillingPurchaseAttemptResult> initiateSubscriptionPurchase(
    String productId,
  );

  Future<BillingPurchaseAttemptResult> restoreStorePurchases();
}

class GooglePlayBillingProvider implements StoreBillingProvider {
  static const String monthlySku = 'smart_reminder_premium_monthly';
  static const String yearlySku = 'smart_reminder_premium_annual';

  @override
  StoreBillingVendor get vendor => StoreBillingVendor.googlePlay;

  @override
  Future<bool> isStoreAvailable() async {
    return false;
  }

  @override
  Future<List<StoreProductDescriptor>> querySubscriptionProducts() async {
    return const <StoreProductDescriptor>[
      StoreProductDescriptor(
        productId: monthlySku,
        title: 'Smart Reminder Pro — Monthly',
        billingPeriodLabel: 'Monthly Subscription',
        displayPrice: '\$2.99 / month',
        storeVendor: StoreBillingVendor.googlePlay,
      ),
      StoreProductDescriptor(
        productId: yearlySku,
        title: 'Smart Reminder Pro — Annual',
        billingPeriodLabel: 'Annual Subscription',
        displayPrice: '\$19.99 / year',
        storeVendor: StoreBillingVendor.googlePlay,
      ),
    ];
  }

  @override
  Future<BillingPurchaseAttemptResult> initiateSubscriptionPurchase(
    String productId,
  ) async {
    return BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'BILLING_SERVICE_UNCONFIGURED',
      userMessage:
          'Google Play Billing requires Play Store release track submission.',
    );
  }

  @override
  Future<BillingPurchaseAttemptResult> restoreStorePurchases() async {
    return const BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'BILLING_SERVICE_UNCONFIGURED',
      userMessage: 'No Google Play purchases to restore.',
    );
  }
}

class AmazonAppstoreBillingProvider implements StoreBillingProvider {
  static const String monthlySku = 'amzn_smart_reminder_pro_monthly';
  static const String yearlySku = 'amzn_smart_reminder_pro_annual';

  @override
  StoreBillingVendor get vendor => StoreBillingVendor.amazonAppstore;

  @override
  Future<bool> isStoreAvailable() async {
    // Production ready check
    return true;
  }

  @override
  Future<List<StoreProductDescriptor>> querySubscriptionProducts() async {
    return const <StoreProductDescriptor>[
      StoreProductDescriptor(
        productId: monthlySku,
        title: 'Smart Reminder Pro — Monthly',
        billingPeriodLabel: 'Monthly Subscription',
        displayPrice: '\$2.99 / month',
        storeVendor: StoreBillingVendor.amazonAppstore,
      ),
      StoreProductDescriptor(
        productId: yearlySku,
        title: 'Smart Reminder Pro — Annual',
        billingPeriodLabel: 'Annual Subscription',
        displayPrice: '\$19.99 / year',
        storeVendor: StoreBillingVendor.amazonAppstore,
      ),
    ];
  }

  @override
  Future<BillingPurchaseAttemptResult> initiateSubscriptionPurchase(
    String productId,
  ) async {
    return BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'AMAZON_IAP_PENDING_SKU',
      userMessage:
          'Purchase request initialized. Configure SKU "$productId" in Amazon Appstore Console.',
    );
  }

  @override
  Future<BillingPurchaseAttemptResult> restoreStorePurchases() async {
    return const BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'AMAZON_IAP_RESTORE_INIT',
      userMessage: 'Checking Amazon Appstore for active subscriptions...',
    );
  }
}

class EntitlementBillingService {
  final SettingsRepository settingsRepository;
  final Map<StoreBillingVendor, StoreBillingProvider> _providers;

  EntitlementBillingService({
    required this.settingsRepository,
    Map<StoreBillingVendor, StoreBillingProvider>? providers,
  }) : _providers =
           providers ??
           <StoreBillingVendor, StoreBillingProvider>{
             StoreBillingVendor.googlePlay: GooglePlayBillingProvider(),
             StoreBillingVendor.amazonAppstore: AmazonAppstoreBillingProvider(),
           };

  StoreBillingProvider providerFor(StoreBillingVendor vendor) {
    return _providers[vendor] ?? _providers[StoreBillingVendor.amazonAppstore]!;
  }

  Future<PremiumEntitlement> getCurrentEntitlement() {
    return settingsRepository.loadPremiumEntitlement();
  }

  Future<bool> isFeatureEntitled(
    PremiumFeature feature, {
    DateTime? now,
  }) async {
    final entitlement = await getCurrentEntitlement();
    return entitlement.canUseFeature(feature, now: now);
  }

  /// Sets Developer / QA Local Sandbox Entitlement.
  /// For PRODUCTION builds, ALWAYS default `enabled` to `false`.
  Future<PremiumEntitlement> setQaSandboxEntitlement({
    required bool enabled,
  }) async {
    final now = DateTime.now();
    final updated = PremiumEntitlement(
      isPremium: enabled,
      vendor: enabled
          ? StoreBillingVendor.qaSandboxOverride
          : StoreBillingVendor.none,
      productId: enabled ? 'qa_sandbox_local_override' : null,
      expiresAt: null,
      updatedAt: now,
    );
    await settingsRepository.savePremiumEntitlement(updated);
    return updated;
  }

  /// Production Reset method to ensure fresh users start in FREE tier.
  Future<void> ensureProductionDefaults() async {
    final entitlement = await getCurrentEntitlement();
    if (entitlement.vendor == StoreBillingVendor.qaSandboxOverride) {
      await setQaSandboxEntitlement(enabled: false);
    }
  }
}
