import 'package:flutter/material.dart';
import 'reminder.dart';

enum ThemePreferenceMode {
  system,
  light,
  dark,
  scheduled;

  String get label {
    switch (this) {
      case ThemePreferenceMode.system:
        return 'System Default';
      case ThemePreferenceMode.light:
        return 'Light Mode';
      case ThemePreferenceMode.dark:
        return 'Dark Glass Mode';
      case ThemePreferenceMode.scheduled:
        return 'Automatic Day/Night Schedule';
    }
  }
}

enum GlassThemeAccentPreset {
  royalNebula,
  cyberCyan,
  amethystGlow,
  emeraldAurora;

  String get label {
    switch (this) {
      case GlassThemeAccentPreset.royalNebula:
        return 'Royal Nebula (Navy & Indigo)';
      case GlassThemeAccentPreset.cyberCyan:
        return 'Cyber Sapphire (Blue & Cyan)';
      case GlassThemeAccentPreset.amethystGlow:
        return 'Amethyst Luxe (Purple & Violet)';
      case GlassThemeAccentPreset.emeraldAurora:
        return 'Aurora Borealis (Deep Teal & Emerald)';
    }
  }

  bool get isPremiumPreset => this != GlassThemeAccentPreset.royalNebula;
}

class ThemeSettings {
  final ThemePreferenceMode mode;
  final int dayStartHour; // 0..23
  final int dayStartMinute; // 0..59
  final int nightStartHour; // 0..23
  final int nightStartMinute; // 0..59
  final GlassThemeAccentPreset accentPreset;
  final double glassBlurSigma;

  const ThemeSettings({
    this.mode = ThemePreferenceMode.dark,
    this.dayStartHour = 7,
    this.dayStartMinute = 0,
    this.nightStartHour = 19,
    this.nightStartMinute = 30,
    this.accentPreset = GlassThemeAccentPreset.royalNebula,
    this.glassBlurSigma = 14.0,
  });

  /// Evaluates whether [now] falls within the configured Daytime window.
  /// Properly handles schedules where Daytime or Nighttime crosses midnight!
  bool isDaytimeAt(DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;
    final dayStart = dayStartHour * 60 + dayStartMinute;
    final nightStart = nightStartHour * 60 + nightStartMinute;

    if (dayStart == nightStart) {
      return false; // Equal boundaries default to dark
    }
    if (dayStart < nightStart) {
      // Standard schedule (e.g. Day 07:00 -> Night 19:30, or Day 06:00 -> Night 00:30 is handled below)
      return nowMinutes >= dayStart && nowMinutes < nightStart;
    } else {
      // Daytime crosses midnight (e.g. Day starts 20:00 and Night starts 06:00,
      // or Day starts 08:00 and Night starts 01:00 where nightStart < dayStart)
      return nowMinutes >= dayStart || nowMinutes < nightStart;
    }
  }

  ThemeMode resolveThemeMode(DateTime now) {
    switch (mode) {
      case ThemePreferenceMode.system:
        return ThemeMode.system;
      case ThemePreferenceMode.light:
        return ThemeMode.light;
      case ThemePreferenceMode.dark:
        return ThemeMode.dark;
      case ThemePreferenceMode.scheduled:
        return isDaytimeAt(now) ? ThemeMode.light : ThemeMode.dark;
    }
  }

  ThemeSettings copyWith({
    ThemePreferenceMode? mode,
    int? dayStartHour,
    int? dayStartMinute,
    int? nightStartHour,
    int? nightStartMinute,
    GlassThemeAccentPreset? accentPreset,
    double? glassBlurSigma,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      dayStartHour: (dayStartHour ?? this.dayStartHour).clamp(0, 23),
      dayStartMinute: (dayStartMinute ?? this.dayStartMinute).clamp(0, 59),
      nightStartHour: (nightStartHour ?? this.nightStartHour).clamp(0, 23),
      nightStartMinute:
          (nightStartMinute ?? this.nightStartMinute).clamp(0, 59),
      accentPreset: accentPreset ?? this.accentPreset,
      glassBlurSigma: (glassBlurSigma ?? this.glassBlurSigma).clamp(4.0, 28.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mode': mode.name,
      'dayStartHour': dayStartHour,
      'dayStartMinute': dayStartMinute,
      'nightStartHour': nightStartHour,
      'nightStartMinute': nightStartMinute,
      'accentPreset': accentPreset.name,
      'glassBlurSigma': glassBlurSigma,
    };
  }

  factory ThemeSettings.fromMap(Map<String, dynamic> map) {
    final modeName = map['mode'] as String? ?? 'dark';
    final presetName = map['accentPreset'] as String? ?? 'royalNebula';
    return ThemeSettings(
      mode: ThemePreferenceMode.values.firstWhere(
        (e) => e.name == modeName,
        orElse: () => ThemePreferenceMode.dark,
      ),
      dayStartHour: ((map['dayStartHour'] as num?)?.toInt() ?? 7).clamp(0, 23),
      dayStartMinute:
          ((map['dayStartMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      nightStartHour:
          ((map['nightStartHour'] as num?)?.toInt() ?? 19).clamp(0, 23),
      nightStartMinute:
          ((map['nightStartMinute'] as num?)?.toInt() ?? 30).clamp(0, 59),
      accentPreset: GlassThemeAccentPreset.values.firstWhere(
        (e) => e.name == presetName,
        orElse: () => GlassThemeAccentPreset.royalNebula,
      ),
      glassBlurSigma:
          ((map['glassBlurSigma'] as num?)?.toDouble() ?? 14.0).clamp(4.0, 28.0),
    );
  }
}

class SpeechSettings {
  final String defaultLanguage;
  final double defaultSpeechRate;
  final double defaultSpeechPitch;
  final String voiceInputLocale;
  final bool speakRemindersOnTrigger;
  final bool respectAudioFocus;
  final int repeatCountOnAlarm;

  const SpeechSettings({
    this.defaultLanguage = 'ur-PK',
    this.defaultSpeechRate = 0.5,
    this.defaultSpeechPitch = 1.0,
    this.voiceInputLocale = 'en_US',
    this.speakRemindersOnTrigger = true,
    this.respectAudioFocus = true,
    this.repeatCountOnAlarm = 3,
  });

  SpeechSettings copyWith({
    String? defaultLanguage,
    double? defaultSpeechRate,
    double? defaultSpeechPitch,
    String? voiceInputLocale,
    bool? speakRemindersOnTrigger,
    bool? respectAudioFocus,
    int? repeatCountOnAlarm,
  }) {
    return SpeechSettings(
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultSpeechRate:
          (defaultSpeechRate ?? this.defaultSpeechRate).clamp(0.1, 2.0),
      defaultSpeechPitch:
          (defaultSpeechPitch ?? this.defaultSpeechPitch).clamp(0.5, 2.0),
      voiceInputLocale: voiceInputLocale ?? this.voiceInputLocale,
      speakRemindersOnTrigger:
          speakRemindersOnTrigger ?? this.speakRemindersOnTrigger,
      respectAudioFocus: respectAudioFocus ?? this.respectAudioFocus,
      repeatCountOnAlarm:
          (repeatCountOnAlarm ?? this.repeatCountOnAlarm).clamp(1, 10),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'defaultLanguage': defaultLanguage,
      'defaultSpeechRate': defaultSpeechRate,
      'defaultSpeechPitch': defaultSpeechPitch,
      'voiceInputLocale': voiceInputLocale,
      'speakRemindersOnTrigger': speakRemindersOnTrigger,
      'respectAudioFocus': respectAudioFocus,
      'repeatCountOnAlarm': repeatCountOnAlarm,
    };
  }

  factory SpeechSettings.fromMap(Map<String, dynamic> map) {
    return SpeechSettings(
      defaultLanguage: (map['defaultLanguage'] as String?) ?? 'ur-PK',
      defaultSpeechRate:
          ((map['defaultSpeechRate'] as num?)?.toDouble() ?? 0.5).clamp(0.1, 2.0),
      defaultSpeechPitch:
          ((map['defaultSpeechPitch'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.5, 2.0),
      voiceInputLocale: (map['voiceInputLocale'] as String?) ?? 'en_US',
      speakRemindersOnTrigger: map['speakRemindersOnTrigger'] == null
          ? true
          : (map['speakRemindersOnTrigger'] == true ||
              map['speakRemindersOnTrigger'] == 1),
      respectAudioFocus: map['respectAudioFocus'] == null
          ? true
          : (map['respectAudioFocus'] == true || map['respectAudioFocus'] == 1),
      repeatCountOnAlarm:
          ((map['repeatCountOnAlarm'] as num?)?.toInt() ?? 3).clamp(1, 10),
    );
  }
}

class UserPreferences {
  final int defaultSnoozeMinutes;
  final String defaultCategoryId;
  final ReminderPriority defaultPriority;
  final bool confirmBeforeDelete;
  final bool use24HourFormat;
  final bool autoSyncHomeWidget;

  const UserPreferences({
    this.defaultSnoozeMinutes = 10,
    this.defaultCategoryId = 'personal',
    this.defaultPriority = ReminderPriority.medium,
    this.confirmBeforeDelete = true,
    this.use24HourFormat = false,
    this.autoSyncHomeWidget = true,
  });

  UserPreferences copyWith({
    int? defaultSnoozeMinutes,
    String? defaultCategoryId,
    ReminderPriority? defaultPriority,
    bool? confirmBeforeDelete,
    bool? use24HourFormat,
    bool? autoSyncHomeWidget,
  }) {
    return UserPreferences(
      defaultSnoozeMinutes:
          (defaultSnoozeMinutes ?? this.defaultSnoozeMinutes).clamp(1, 1440),
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      autoSyncHomeWidget: autoSyncHomeWidget ?? this.autoSyncHomeWidget,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'defaultSnoozeMinutes': defaultSnoozeMinutes,
      'defaultCategoryId': defaultCategoryId,
      'defaultPriority': defaultPriority.name,
      'confirmBeforeDelete': confirmBeforeDelete,
      'use24HourFormat': use24HourFormat,
      'autoSyncHomeWidget': autoSyncHomeWidget,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      defaultSnoozeMinutes:
          ((map['defaultSnoozeMinutes'] as num?)?.toInt() ?? 10).clamp(1, 1440),
      defaultCategoryId: (map['defaultCategoryId'] as String?) ?? 'personal',
      defaultPriority:
          ReminderPriority.fromString(map['defaultPriority'] as String?),
      confirmBeforeDelete: map['confirmBeforeDelete'] == null
          ? true
          : (map['confirmBeforeDelete'] == true ||
              map['confirmBeforeDelete'] == 1),
      use24HourFormat:
          map['use24HourFormat'] == true || map['use24HourFormat'] == 1,
      autoSyncHomeWidget: map['autoSyncHomeWidget'] == null
          ? true
          : (map['autoSyncHomeWidget'] == true ||
              map['autoSyncHomeWidget'] == 1),
    );
  }
}

enum PremiumFeature {
  customSpokenAlarms,
  advancedRecurrence,
  voiceInput,
  advancedThemes,
  homeScreenWidget,
  adFree,
  backupAndRestore;

  String get title {
    switch (this) {
      case PremiumFeature.customSpokenAlarms:
        return 'Custom Spoken Voice Alarms (TTS)';
      case PremiumFeature.advancedRecurrence:
        return 'Advanced Recurrence Engine';
      case PremiumFeature.voiceInput:
        return 'Speech-to-Text Voice Input';
      case PremiumFeature.advancedThemes:
        return 'Advanced Themes & Auto Day/Night Schedule';
      case PremiumFeature.homeScreenWidget:
        return 'Native Android Home-Screen Widget';
      case PremiumFeature.adFree:
        return '100% Ad-Free Experience';
      case PremiumFeature.backupAndRestore:
        return 'Local Encrypted/Versioned Backup & Restore';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.customSpokenAlarms:
        return 'Write custom wake-up messages in Roman Urdu, Hindi, English, or Arabic spoken aloud when your alarm fires.';
      case PremiumFeature.advancedRecurrence:
        return 'Schedule reminders and alarms on selected weekdays, monthly dates, and custom intervals.';
      case PremiumFeature.voiceInput:
        return 'Dictate reminder titles and notes hands-free using microphone speech recognition.';
      case PremiumFeature.advancedThemes:
        return 'Unlock Cyber Sapphire, Amethyst Luxe, Aurora themes, and automatic Day/Night time scheduling.';
      case PremiumFeature.homeScreenWidget:
        return 'Pin upcoming reminders and quick-add shortcuts directly to your Android home screen.';
      case PremiumFeature.adFree:
        return 'Remove all banner and interstitial ad placements across the application.';
      case PremiumFeature.backupAndRestore:
        return 'Export and restore all reminders, alarms, categories, and preferences as versioned JSON bundles.';
    }
  }
}

enum StoreBillingVendor {
  none,
  googlePlay,
  amazonAppstore,
  qaSandboxOverride;

  String get label {
    switch (this) {
      case StoreBillingVendor.none:
        return 'Not Subscribed (Free Tier)';
      case StoreBillingVendor.googlePlay:
        return 'Google Play Billing';
      case StoreBillingVendor.amazonAppstore:
        return 'Amazon Appstore IAP';
      case StoreBillingVendor.qaSandboxOverride:
        return 'Developer / QA Local Entitlement Override';
    }
  }
}

class PremiumEntitlement {
  final bool isPremium;
  final StoreBillingVendor vendor;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime updatedAt;

  const PremiumEntitlement({
    this.isPremium = false,
    this.vendor = StoreBillingVendor.none,
    this.productId,
    this.expiresAt,
    required this.updatedAt,
  });

  bool isActiveAt(DateTime now) {
    if (!isPremium) return false;
    if (expiresAt != null && expiresAt!.isBefore(now)) {
      return false;
    }
    return true;
  }

  bool canUseFeature(PremiumFeature feature, {DateTime? now}) {
    return isActiveAt(now ?? DateTime.now());
  }

  PremiumEntitlement copyWith({
    bool? isPremium,
    StoreBillingVendor? vendor,
    String? productId,
    DateTime? expiresAt,
    bool clearExpiry = false,
    DateTime? updatedAt,
  }) {
    return PremiumEntitlement(
      isPremium: isPremium ?? this.isPremium,
      vendor: vendor ?? this.vendor,
      productId: productId ?? this.productId,
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isPremium': isPremium,
      'vendor': vendor.name,
      'productId': productId,
      'expiresAt': expiresAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PremiumEntitlement.fromMap(Map<String, dynamic> map) {
    final vendorName = map['vendor'] as String? ?? 'none';
    final expStr = map['expiresAt'] as String?;
    final updStr = map['updatedAt'] as String?;
    return PremiumEntitlement(
      isPremium: map['isPremium'] == true || map['isPremium'] == 1,
      vendor: StoreBillingVendor.values.firstWhere(
        (e) => e.name == vendorName,
        orElse: () => StoreBillingVendor.none,
      ),
      productId: map['productId'] as String?,
      expiresAt: expStr != null ? DateTime.tryParse(expStr) : null,
      updatedAt:
          updStr != null ? (DateTime.tryParse(updStr) ?? DateTime.now()) : DateTime.now(),
    );
  }
}

enum AdNetworkProvider {
  googleAdMob,
  amazonAds,
  disabled;

  String get label {
    switch (this) {
      case AdNetworkProvider.googleAdMob:
        return 'Google AdMob (Test Mode)';
      case AdNetworkProvider.amazonAds:
        return 'Amazon Publisher Services (Test Mode)';
      case AdNetworkProvider.disabled:
        return 'Disabled';
    }
  }
}

class AdvertisingConfiguration {
  final AdNetworkProvider provider;
  final bool testMode;
  final bool userConsentGranted;
  final bool personalizedAds;
  final bool bannerEnabled;
  final bool interstitialEnabled;

  // Official Google AdMob documented public sample/test unit IDs (never production IDs)
  static const String admobAndroidTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String admobAndroidTestInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String amazonTestSlotId = 'amazon-aps-test-slot-320x50';

  const AdvertisingConfiguration({
    this.provider = AdNetworkProvider.googleAdMob,
    this.testMode = true,
    this.userConsentGranted = false,
    this.personalizedAds = false,
    this.bannerEnabled = true,
    this.interstitialEnabled = true,
  });

  /// Determines if a banner can be shown given the user's premium status and active alarm state.
  bool shouldShowBanner({
    required bool isPremiumActive,
    required bool isAlarmRinging,
  }) {
    if (isPremiumActive) return false;
    if (isAlarmRinging) return false;
    if (provider == AdNetworkProvider.disabled) return false;
    return bannerEnabled;
  }

  /// Determines if an interstitial is eligible.
  /// CRITICAL SAFETY RULE: Never display an interstitial while an alarm is ringing,
  /// during alarm dismissal/snooze, or while scheduling an alarm.
  bool canShowInterstitial({
    required bool isPremiumActive,
    required bool isAlarmRinging,
    required bool isSchedulingOrDismissingAlarm,
  }) {
    if (isPremiumActive) return false;
    if (isAlarmRinging || isSchedulingOrDismissingAlarm) return false;
    if (provider == AdNetworkProvider.disabled) return false;
    return interstitialEnabled;
  }

  AdvertisingConfiguration copyWith({
    AdNetworkProvider? provider,
    bool? testMode,
    bool? userConsentGranted,
    bool? personalizedAds,
    bool? bannerEnabled,
    bool? interstitialEnabled,
  }) {
    return AdvertisingConfiguration(
      provider: provider ?? this.provider,
      testMode: testMode ?? true, // Always enforce safe test mode until release config
      userConsentGranted: userConsentGranted ?? this.userConsentGranted,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'provider': provider.name,
      'testMode': testMode,
      'userConsentGranted': userConsentGranted,
      'personalizedAds': personalizedAds,
      'bannerEnabled': bannerEnabled,
      'interstitialEnabled': interstitialEnabled,
    };
  }

  factory AdvertisingConfiguration.fromMap(Map<String, dynamic> map) {
    final provName = map['provider'] as String? ?? 'googleAdMob';
    return AdvertisingConfiguration(
      provider: AdNetworkProvider.values.firstWhere(
        (e) => e.name == provName,
        orElse: () => AdNetworkProvider.googleAdMob,
      ),
      testMode: map['testMode'] == null
          ? true
          : (map['testMode'] == true || map['testMode'] == 1),
      userConsentGranted:
          map['userConsentGranted'] == true || map['userConsentGranted'] == 1,
      personalizedAds:
          map['personalizedAds'] == true || map['personalizedAds'] == 1,
      bannerEnabled: map['bannerEnabled'] == null
          ? true
          : (map['bannerEnabled'] == true || map['bannerEnabled'] == 1),
      interstitialEnabled: map['interstitialEnabled'] == null
          ? true
          : (map['interstitialEnabled'] == true ||
              map['interstitialEnabled'] == 1),
    );
  }
}
