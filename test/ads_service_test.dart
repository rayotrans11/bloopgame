import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/core/ads_service.dart';

void main() {
  test('UnityAdsService counts 6 menu clicks and triggers interstitial ad', () {
    final ads = UnityAdsService.instance;

    // Simulate menu clicks
    for (int i = 0; i < 5; i++) {
      ads.recordMenuClick();
    }

    // 6th click should trigger interstitial ad
    ads.recordMenuClick();

    expect(UnityAdsService.iosGameId, equals('6215058'));
    expect(UnityAdsService.androidGameId, equals('6215059'));
    expect(UnityAdsService.iosInterstitialPlacementId, equals('inter'));
    expect(UnityAdsService.iosRewardedPlacementId, equals('reward'));
    expect(UnityAdsService.androidInterstitialPlacementId, equals('interandroid'));
    expect(UnityAdsService.androidRewardedPlacementId, equals('rewardandroid'));

    // Verify rewarded ad callback works
    bool rewarded = false;
    ads.showRewardedAd(
      onRewardGranted: () {
        rewarded = true;
      },
    );
    expect(rewarded, isTrue);
  });
}

