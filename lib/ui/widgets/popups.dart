import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ads_service.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/game_audio.dart';
import '../../data/player_state.dart';
import 'game_icons.dart';
import 'hud_pills.dart';

class GameDialogWrapper extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const GameDialogWrapper({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GameColors.bgHud,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GameColors.pillBorder, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              content,
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: actions.map((a) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: a)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Popups {
  static void showDailyCheckIn(BuildContext context, PlayerState player) {
    showDialog(
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: 'DAILY CHECK-IN',
        content: Column(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CustomPaint(painter: GameIconPainter(type: 'gem')),
            ),
            const SizedBox(height: 14),
            const Text(
              'Claim your daily reward to get extra gems for power-ups and skins!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: GameColors.pillFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.yellowAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '+15 GEMS',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyanAccent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: () {
              player.addGems(15);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Claimed +15 Gems from Daily Check-in!'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
            child: const OutlinedButtonText('CLAIM (+15 💎)', fontSize: 16),
          ),
        ],
      ),
    );
  }

  static void showOutOfHearts(BuildContext context, PlayerState player) {
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: player,
        builder: (ctx, _) => GameDialogWrapper(
          title: 'OUT OF HEARTS',
          content: Column(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CustomPaint(painter: GameIconPainter(type: 'heart')),
              ),
              const SizedBox(height: 12),
              Text(
                'Next heart in ${GameFormat.timer(player.timeUntilNextHeart)}',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  color: Color(0xFFFF8A80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Watch a video ad or spend gems to get hearts immediately!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Fredoka', color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.movie, color: Colors.white),
              label: const OutlinedButtonText('+1 Free (Ad)', fontSize: 14),
              onPressed: () {
                UnityAdsService.instance.showRewardedAd(
                  onRewardGranted: () {
                    player.addHearts(1);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Received +1 Heart!'), backgroundColor: Color(0xFF2E7D32)),
                    );
                  },
                  onFailedOrDismissed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Watch the full ad to earn +1 Heart.'), backgroundColor: Colors.orange),
                    );
                  },
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.plusBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.diamond, color: Colors.white),
              label: const OutlinedButtonText('Refill (10 💎)', fontSize: 14),
              onPressed: () {
                if (player.gems >= 10) {
                  player.gems -= 10;
                  player.refillHearts();
                  Navigator.of(ctx).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough gems!'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showWin(BuildContext context, int level, num cashEarned, VoidCallback onNext, {PlayerState? player}) {
    final cashStr = cashEarned is double || cashEarned.toDouble() != cashEarned.toInt().toDouble()
        ? '\$${cashEarned.toStringAsFixed(2)}'
        : '\$$cashEarned';

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: 'LEVEL $level COMPLETE!',
        content: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(painter: GameIconPainter(type: 'trophy')),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: GameColors.pillFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GameColors.pillBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomPaint(painter: GameIconPainter(type: 'cash')),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$cashStr',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF69F0AE),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Chest +5', style: TextStyle(fontFamily: 'Fredoka', color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              UnityAdsService.instance.showRewardedAd(
                onRewardGranted: () {
                  player?.addCash(cashEarned); // Give 2x bonus cash reward
                  Navigator.of(ctx).pop();
                  onNext();
                },
                onFailedOrDismissed: () {
                  Navigator.of(ctx).pop();
                  onNext();
                },
              );
            },
            child: const OutlinedButtonText('2x Cash (Ad)', fontSize: 14),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.startBlue,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onNext();
            },
            child: const OutlinedButtonText('NEXT', fontSize: 16),
          ),
        ],
      ),
    );
  }

  static void showLose(BuildContext context, VoidCallback onRetry, VoidCallback onHome) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: 'OUT OF SPACE!',
        content: const Column(
          children: [
            Icon(Icons.sentiment_very_dissatisfied, size: 70, color: Colors.orangeAccent),
            SizedBox(height: 12),
            Text(
              'Blocks reached the floor line!',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF455A64),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onHome();
            },
            child: const OutlinedButtonText('HOME', fontSize: 14),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onRetry();
            },
            child: const OutlinedButtonText('RETRY (-1 ❤️)', fontSize: 14),
          ),
        ],
      ),
    );
  }

  static void showMysteryChest(BuildContext context, PlayerState player) {
    if (player.chestProgress < 50) {
      showDialog(
        context: context,
        builder: (ctx) => GameDialogWrapper(
          title: 'MYSTERY CHEST',
          content: Column(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CustomPaint(painter: GameIconPainter(type: 'mystery_box')),
              ),
              const SizedBox(height: 12),
              Text(
                'Progress: ${player.chestProgress}/50',
                style: const TextStyle(fontFamily: 'Fredoka', fontSize: 18, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Destroy blocks and complete levels to unlock rare rewards and power-ups!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Fredoka', color: Colors.white70),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.startBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const OutlinedButtonText('OK', fontSize: 15),
            ),
          ],
        ),
      );
      return;
    }

    // Chest ready to claim!
    showDialog(
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: 'CHEST UNLOCKED!',
        content: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(painter: GameIconPainter(type: 'mystery_box')),
            ),
            const SizedBox(height: 14),
            const Text(
              'You found:\n• \$500 Cash\n• 15 Gems\n• +1 Smash Power-up!',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Fredoka', fontSize: 16, color: Colors.yellowAccent, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              player.claimChest();
              Navigator.of(ctx).pop();
            },
            child: const OutlinedButtonText('CLAIM ALL', fontSize: 16),
          ),
        ],
      ),
    );
  }

  static void showSkins(BuildContext context, PlayerState player) {
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: player,
        builder: (ctx, _) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Modal Body
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C103C),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF4D3BC6), width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // List of 5 skins from the screenshot
                    _skinRow(ctx, player, 'yellow', 'Yellow Ball'),
                    const SizedBox(height: 10),
                    _skinRow(ctx, player, 'basketball', 'Basketball'),
                    const SizedBox(height: 10),
                    _skinRow(ctx, player, 'tricolor', 'Tri-Color Ball'),
                    const SizedBox(height: 10),
                    _skinRow(ctx, player, 'star', 'Star'),
                    const SizedBox(height: 10),
                    _skinRow(ctx, player, 'star_burst', 'Star Burst'),
                  ],
                ),
              ),

              // Top Centered "Skin" Header Pill
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3FC7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF7A6DF0), width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 4),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const OutlinedButtonText('Skin', fontSize: 18, strokeWidth: 3.8),
                  ),
                ),
              ),

              // Top-Right Red Circular "X" Close Button
              Positioned(
                top: -10,
                right: -6,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _skinRow(BuildContext context, PlayerState player, String id, String title) {
    final isEquipped = player.ballSkin == id;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (id == 'yellow' || isEquipped) {
          player.setSkin(id);
        } else {
          // Rewarded Ad to unlock / equip skin
          UnityAdsService.instance.showRewardedAd(
            onRewardGranted: () {
              player.setSkin(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unlocked and equipped $title!'),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              );
            },
            onFailedOrDismissed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Watch the full ad to use this skin.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF080B2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEquipped ? const Color(0xFF3F51B5) : const Color(0xFF1B2358),
            width: 1.8,
          ),
        ),
        child: Row(
          children: [
            // 46x46 Ball Preview
            SizedBox(
              width: 46,
              height: 46,
              child: CustomPaint(
                painter: _SkinPreviewPainter(skin: id),
              ),
            ),
            const SizedBox(width: 14),

            // Skin Name
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            // Status Button / Checkmark
            if (isEquipped)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.0),
                  boxShadow: [
                    BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.4), blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 24),
              )
            else if (id == 'yellow')
              // Free default skin - no ads needed
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF81D4FA), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF0277BD),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    SizedBox(width: 5),
                    OutlinedButtonText('Use', fontSize: 14.5, strokeWidth: 3.2),
                  ],
                ),
              )
            else
              // Ad-supported or special unlockable skins
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF54B819),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF8CEB4E), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF33700C),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Blue clapperboard movie icon for video ad unlock
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.movie, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const OutlinedButtonText('Use', fontSize: 14.5, strokeWidth: 3.2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void showSettings(BuildContext context, PlayerState player) {
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: player,
        builder: (ctx, _) => GameDialogWrapper(
          title: 'SETTINGS',
          content: Column(
            children: [
              SwitchListTile(
                title: const Text('Sound FX', style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontWeight: FontWeight.bold)),
                value: player.sound,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: (_) {
                  player.toggleSound();
                  GameAudio.instance.play(GameSound.uiTap);
                  GameAudio.instance.haptic(GameHaptic.selection);
                },
              ),
              SwitchListTile(
                title: const Text('Music', style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontWeight: FontWeight.bold)),
                value: player.music,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: (_) {
                  player.toggleMusic();
                  GameAudio.instance.play(GameSound.uiTap);
                  GameAudio.instance.haptic(GameHaptic.selection);
                },
              ),
              SwitchListTile(
                title: const Text('Haptics', style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontWeight: FontWeight.bold)),
                value: player.haptics,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: (_) {
                  player.toggleHaptics();
                  if (player.haptics) {
                    GameAudio.instance.haptic(GameHaptic.selection);
                  }
                },
              ),
              const SizedBox(height: 8),
              // Privacy Policy Link
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final uri = Uri.parse('https://rayostudio.blogspot.com/p/privacy-policy.html');
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    // Fallback
                    await launchUrl(uri);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: GameColors.pillFill.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GameColors.pillBorder.withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: Color(0xFF00E5FF), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(Icons.open_in_new, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.startBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const OutlinedButtonText('CLOSE', fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  static void showFeatureSheet(BuildContext context, String title, String iconType, String description) {
    showDialog(
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: title,
        content: Column(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CustomPaint(painter: GameIconPainter(type: iconType)),
            ),
            const SizedBox(height: 14),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.startBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const OutlinedButtonText('CLOSE', fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _SkinPreviewPainter extends CustomPainter {
  final String skin;

  _SkinPreviewPainter({required this.skin});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    switch (skin) {
      case 'basketball':
        // Orange basketball
        final bg = Paint()..color = const Color(0xFFFF6D00);
        canvas.drawCircle(c, r, bg);

        final seam = Paint()
          ..color = const Color(0xFF1E1E1E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawLine(c - Offset(0, r), c + Offset(0, r), seam);
        canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), seam);
        canvas.drawArc(Rect.fromCircle(center: c - Offset(r * 0.85, 0), radius: r * 0.75), -math.pi * 0.45, math.pi * 0.9, false, seam);
        canvas.drawArc(Rect.fromCircle(center: c + Offset(r * 0.85, 0), radius: r * 0.75), math.pi * 0.55, math.pi * 0.9, false, seam);
        break;

      case 'tricolor':
        // Swirl tri-color: cyan, magenta, yellow
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawArc(rect, -math.pi * 0.5, math.pi * 2 / 3, true, Paint()..color = const Color(0xFF00E5FF));
        canvas.drawArc(rect, -math.pi * 0.5 + math.pi * 2 / 3, math.pi * 2 / 3, true, Paint()..color = const Color(0xFFFF2D8D));
        canvas.drawArc(rect, -math.pi * 0.5 + math.pi * 4 / 3, math.pi * 2 / 3, true, Paint()..color = const Color(0xFFFFD600));
        break;

      case 'star':
        // Deep blue ball with white curved stripes
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1976D2));
        final strPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8;
        canvas.drawArc(Rect.fromCenter(center: c + Offset(0, -r * 0.45), width: r * 1.6, height: r * 0.7), math.pi * 0.15, math.pi * 0.7, false, strPaint);
        canvas.drawArc(Rect.fromCenter(center: c, width: r * 1.9, height: r * 0.75), math.pi * 0.1, math.pi * 0.8, false, strPaint);
        canvas.drawArc(Rect.fromCenter(center: c + Offset(0, r * 0.45), width: r * 1.6, height: r * 0.7), math.pi * 0.15, math.pi * 0.7, false, strPaint);
        break;

      case 'star_burst':
        // Golden yellow ball with purple stars
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFB300));
        final starP = Paint()..color = const Color(0xFF7B1FA2);
        _drawMiniStar(canvas, c + Offset(-r * 0.35, -r * 0.3), 6.5, starP);
        _drawMiniStar(canvas, c + Offset(r * 0.38, -r * 0.2), 5.5, starP);
        _drawMiniStar(canvas, c + Offset(-r * 0.1, r * 0.4), 6.8, starP);
        _drawMiniStar(canvas, c + Offset(r * 0.42, r * 0.35), 5.0, starP);
        break;

      case 'yellow':
      default:
        // Default bright golden yellow ball
        final shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: const [Color(0xFFFFF59D), Color(0xFFFFC107), Color(0xFFFF8F00)],
        ).createShader(Rect.fromCircle(center: c, radius: r));
        canvas.drawCircle(c, r, Paint()..shader = shader);
        break;
    }

    // Top-left Specular 3D Gloss Highlight Arc
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.72),
      math.pi * 1.05,
      math.pi * 0.45,
      false,
      hlPaint,
    );
  }

  void _drawMiniStar(Canvas canvas, Offset ctr, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SkinPreviewPainter oldDelegate) => oldDelegate.skin != skin;
}
