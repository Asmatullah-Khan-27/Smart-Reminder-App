import '../data/repositories/settings_repository.dart';
import '../domain/models/app_settings.dart';

class AdPlacementStatus {
  final bool visible;
  final String networkLabel;
  final String unitIdentifier;
  final String statusReason;

  const AdPlacementStatus({
    required this.visible,
    required this.networkLabel,
    required this.unitIdentifier,
    required this.statusReason,
  });
}

class AdvertisingService {
  final SettingsRepository settingsRepository;

  bool _isAlarmCurrentlyRinging = false;
  bool _isSchedulingOrDismissingAlarm = false;

  AdvertisingService({required this.settingsRepository});

  bool get isAlarmCurrentlyRinging => _isAlarmCurrentlyRinging;

  void setAlarmRingingState(bool isRinging) {
    _isAlarmCurrentlyRinging = isRinging;
  }

  void setCriticalAlarmOperationInProgress(bool inProgress) {
    _isSchedulingOrDismissingAlarm = inProgress;
  }

  AdPlacementStatus resolveBannerStatus({
    required AdvertisingConfiguration config,
    required bool isPremiumActive,
  }) {
    if (isPremiumActive) {
      return const AdPlacementStatus(
        visible: false,
        networkLabel: 'Ad-Free Premium',
        unitIdentifier: 'none',
        statusReason: 'Ads removed by active Premium entitlement.',
      );
    }
    if (_isAlarmCurrentlyRinging) {
      return const AdPlacementStatus(
        visible: false,
        networkLabel: 'Suppressed (Alarm Active)',
        unitIdentifier: 'none',
        statusReason: 'Ads are strictly suppressed while an alarm is ringing.',
      );
    }
    if (!config.shouldShowBanner(
      isPremiumActive: isPremiumActive,
      isAlarmRinging: _isAlarmCurrentlyRinging,
    )) {
      return const AdPlacementStatus(
        visible: false,
        networkLabel: 'Disabled',
        unitIdentifier: 'none',
        statusReason: 'Banner placement disabled in settings.',
      );
    }

    final unitId = config.provider == AdNetworkProvider.amazonAds
        ? AdvertisingConfiguration.amazonTestSlotId
        : AdvertisingConfiguration.admobAndroidTestBannerUnitId;

    return AdPlacementStatus(
      visible: true,
      networkLabel: config.provider.label,
      unitIdentifier: unitId,
      statusReason: config.userConsentGranted && config.personalizedAds
          ? 'Test Mode Banner (Personalized Consent Granted)'
          : 'Test Mode Banner (Non-Personalized / contextual)',
    );
  }

  /// Evaluates whether an interstitial placement is allowed right now.
  /// Never blocks alarm scheduling, dismissal, or snooze.
  bool isInterstitialEligible({
    required AdvertisingConfiguration config,
    required bool isPremiumActive,
  }) {
    return config.canShowInterstitial(
      isPremiumActive: isPremiumActive,
      isAlarmRinging: _isAlarmCurrentlyRinging,
      isSchedulingOrDismissingAlarm: _isSchedulingOrDismissingAlarm,
    );
  }

  Future<AdvertisingConfiguration> updateConfiguration(
    AdvertisingConfiguration config,
  ) async {
    await settingsRepository.saveAdvertisingConfig(config);
    return config;
  }
}
