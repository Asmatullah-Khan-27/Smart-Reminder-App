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

/// Abstract Store Billing Provider so Google Play Billing (`in_app_purchase` /
/// BillingClient v7) and Amazon Appstore IAP (`Appstore SDK`) can be wired
/// independently per store build flavor.
abstract class StoreBillingProvider {
  StoreBillingVendor get vendor;

  Future<bool> isStoreAvailable();

  Future<List<StoreProductDescriptor>> querySubscriptionProducts();

  Future<BillingPurchaseAttemptResult> initiateSubscriptionPurchase(
    String productId,
  );

  Future<BillingPurchaseAttemptResult> restoreStorePurchases();
}

/// Documented integration point for Google Play Billing.
/// Does NOT fabricate successful purchases when Play Store billing credentials
/// and a signed Play Store track are not connected.
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
        displayPrice: '\$2.99 / month (Play Console SKU)',
        storeVendor: StoreBillingVendor.googlePlay,
      ),
      StoreProductDescriptor(
        productId: yearlySku,
        title: 'Smart Reminder Pro — Annual',
        billingPeriodLabel: 'Annual Subscription',
        displayPrice: '\$19.99 / year (Play Console SKU)',
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
          'Google Play Billing is not connected to a live Play Console merchant account in this build. '
          'Configure SKU "$productId" in Google Play Console and sign with your upload keystore to enable live transactions.',
    );
  }

  @override
  Future<BillingPurchaseAttemptResult> restoreStorePurchases() async {
    return const BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'BILLING_SERVICE_UNCONFIGURED',
      userMessage:
          'Google Play Billing client is not connected to a signed Play Store session. No remote purchases were restored.',
    );
  }
}

/// Documented integration point for Amazon Appstore In-App Purchasing (IAP v2/v3).
class AmazonAppstoreBillingProvider implements StoreBillingProvider {
  static const String monthlySku = 'amzn_smart_reminder_pro_monthly';
  static const String yearlySku = 'amzn_smart_reminder_pro_annual';

  @override
  StoreBillingVendor get vendor => StoreBillingVendor.amazonAppstore;

  @override
  Future<bool> isStoreAvailable() async {
    return false;
  }

  @override
  Future<List<StoreProductDescriptor>> querySubscriptionProducts() async {
    return const <StoreProductDescriptor>[
      StoreProductDescriptor(
        productId: monthlySku,
        title: 'Smart Reminder Pro — Monthly (Amazon)',
        billingPeriodLabel: 'Monthly Subscription',
        displayPrice: '\$2.99 / month (Amazon IAP SKU)',
        storeVendor: StoreBillingVendor.amazonAppstore,
      ),
      StoreProductDescriptor(
        productId: yearlySku,
        title: 'Smart Reminder Pro — Annual (Amazon)',
        billingPeriodLabel: 'Annual Subscription',
        displayPrice: '\$19.99 / year (Amazon IAP SKU)',
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
      statusCode: 'AMAZON_IAP_UNCONFIGURED',
      userMessage:
          'Amazon Appstore PurchasingService is not active in this environment. '
          'Configure SKU "$productId" in Amazon Developer Console or install Amazon App Tester for sandbox verification.',
    );
  }

  @override
  Future<BillingPurchaseAttemptResult> restoreStorePurchases() async {
    return const BillingPurchaseAttemptResult(
      completed: false,
      statusCode: 'AMAZON_IAP_UNCONFIGURED',
      userMessage:
          'Amazon Appstore client is not connected. No Amazon IAP entitlements were restored.',
    );
  }
}

class EntitlementBillingService {
  final SettingsRepository settingsRepository;
  final Map<StoreBillingVendor, StoreBillingProvider> _providers;

  EntitlementBillingService({
    required this.settingsRepository,
    Map<StoreBillingVendor, StoreBillingProvider>? providers,
  }) : _providers = providers ??
            <StoreBillingVendor, StoreBillingProvider>{
              StoreBillingVendor.googlePlay: GooglePlayBillingProvider(),
              StoreBillingVendor.amazonAppstore: AmazonAppstoreBillingProvider(),
            };

  StoreBillingProvider providerFor(StoreBillingVendor vendor) {
    return _providers[vendor] ?? _providers[StoreBillingVendor.googlePlay]!;
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

  /// Explicitly labeled Developer/QA Local Override so engineers and testers
  /// can verify both Free and Premium gated flows offline without fabricating
  /// a store purchase receipt.
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
}
