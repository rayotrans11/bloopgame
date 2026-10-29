import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class UnityAdsService {
  UnityAdsService._();
  static final UnityAdsService instance = UnityAdsService._();

  // Unity Game IDs
  static const String iosGameId = '6215058';
  static const String androidGameId = '6215059';

  // Placements for iOS
  static const String iosInterstitialPlacementId = 'inter';
  static const String iosRewardedPlacementId = 'reward';

  // Placements for Android
  static const String androidInterstitialPlacementId = 'interandroid';
  static const String androidRewardedPlacementId = 'rewardandroid';

  /// Active Game ID based on platform
  String get gameId => (!kIsWeb && Platform.isAndroid) ? androidGameId : iosGameId;

  /// Active Interstitial Ad unit placement ID based on platform
  String get interstitialPlacementId =>
      (!kIsWeb && Platform.isAndroid) ? androidInterstitialPlacementId : iosInterstitialPlacementId;

  /// Active Rewarded Ad unit placement ID based on platform
  String get rewardedPlacementId =>
      (!kIsWeb && Platform.isAndroid) ? androidRewardedPlacementId : iosRewardedPlacementId;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Interstitial click counter: after 6 menu button clicks show interstitial
  int _menuClickCount = 0;
  static const int clicksPerInterstitial = 6;

  /// Check if running on iOS / Android supported mobile platform
  bool get isMobilePlatform => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Requests App Tracking Transparency on iOS and initializes Unity Ads legally
  Future<void> init() async {
    if (!isMobilePlatform) {
      debugPrint('[UnityAds] Non-mobile platform detected. Ads mock mode active.');
      _isInitialized = true;
      return;
    }

    try {
      // 1. Apple App Tracking Transparency (ATT) Flow
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        debugPrint('[ATT] Current Tracking Status: $status');

        if (status == TrackingStatus.notDetermined) {
          // Request user consent for tracking
          final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();
          debugPrint('[ATT] Requested Tracking Status: $newStatus');
        }

        final uuid = await AppTrackingTransparency.getAdvertisingIdentifier();
        debugPrint('[ATT] Advertising ID (IDFA): $uuid');
      }

      // 2. Initialize Unity Ads with platform-specific Game ID
      final activeGameId = gameId;
      await UnityAds.init(
        gameId: activeGameId,
        testMode: false,
        onComplete: () {
          _isInitialized = true;
          debugPrint('[UnityAds] Initialization complete on gameId $activeGameId');
          _preloadAds();
        },
        onFailed: (error, message) {
          _isInitialized = false;
          debugPrint('[UnityAds] Initialization failed: $error - $message');
        },
      );
    } catch (e, stack) {
      debugPrint('[UnityAds] Error during initialization: $e\n$stack');
      _isInitialized = true; // allow app flow to continue gracefully
    }
  }

  void _preloadAds() {
    if (!isMobilePlatform) return;
    try {
      UnityAds.load(
        placementId: interstitialPlacementId,
        onComplete: (id) => debugPrint('[UnityAds] Preloaded interstitial $id'),
        onFailed: (id, err, msg) => debugPrint('[UnityAds] Failed to preload interstitial: $msg'),
      );
      UnityAds.load(
        placementId: rewardedPlacementId,
        onComplete: (id) => debugPrint('[UnityAds] Preloaded rewarded $id'),
        onFailed: (id, err, msg) => debugPrint('[UnityAds] Failed to preload rewarded: $msg'),
      );
    } catch (e) {
      debugPrint('[UnityAds] Preload error: $e');
    }
  }

  /// Increments menu button click count and triggers interstitial ad every 6 clicks
  void recordMenuClick() {
    _menuClickCount++;
    debugPrint('[UnityAds] Menu click recorded: $_menuClickCount / $clicksPerInterstitial');

    if (_menuClickCount >= clicksPerInterstitial) {
      _menuClickCount = 0;
      showInterstitialAd();
    }
  }

  /// Shows Interstitial ad (iOS placement: 'inter')
  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (!isMobilePlatform) {
      debugPrint('[UnityAds Mock] Interstitial displayed & closed.');
      onDismissed?.call();
      return;
    }

    try {
      UnityAds.showVideoAd(
        placementId: interstitialPlacementId,
        onStart: (id) => debugPrint('[UnityAds] Interstitial started: $id'),
        onClick: (id) => debugPrint('[UnityAds] Interstitial clicked: $id'),
        onSkipped: (id) {
          debugPrint('[UnityAds] Interstitial skipped: $id');
          _preloadAds();
          onDismissed?.call();
        },
        onComplete: (id) {
          debugPrint('[UnityAds] Interstitial completed: $id');
          _preloadAds();
          onDismissed?.call();
        },
        onFailed: (id, err, msg) {
          debugPrint('[UnityAds] Interstitial failed: $msg');
          _preloadAds();
          onDismissed?.call();
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] Show interstitial error: $e');
      onDismissed?.call();
    }
  }

  /// Shows Rewarded ad (iOS placement: 'reward')
  /// Calls onRewardGranted if user watches video and earns the reward.
  void showRewardedAd({
    required VoidCallback onRewardGranted,
    VoidCallback? onFailedOrDismissed,
  }) {
    if (!isMobilePlatform) {
      debugPrint('[UnityAds Mock] Rewarded ad watched. Granting reward.');
      onRewardGranted();
      return;
    }

    try {
      UnityAds.showVideoAd(
        placementId: rewardedPlacementId,
        onStart: (id) => debugPrint('[UnityAds] Rewarded ad started: $id'),
        onClick: (id) => debugPrint('[UnityAds] Rewarded ad clicked: $id'),
        onSkipped: (id) {
          debugPrint('[UnityAds] Rewarded ad skipped without reward: $id');
          _preloadAds();
          onFailedOrDismissed?.call();
        },
        onComplete: (id) {
          debugPrint('[UnityAds] Rewarded ad completed. Reward granted for placement: $id');
          _preloadAds();
          onRewardGranted();
        },
        onFailed: (id, err, msg) {
          debugPrint('[UnityAds] Rewarded ad failed: $msg');
          _preloadAds();
          // In case ad fails to load or no fill, give graceful callback
          onFailedOrDismissed?.call();
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] Show rewarded error: $e');
      onFailedOrDismissed?.call();
    }
  }
}
