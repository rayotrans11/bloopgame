import 'package:flutter/material.dart';
import '../../core/progression_service.dart';
import '../widgets/hud_pills.dart';

class DailyRewardModal extends StatelessWidget {
  final VoidCallback onClaim;
  final int rewardGems;

  const DailyRewardModal({
    super.key,
    required this.onClaim,
    required this.rewardGems,
  });

  static void show(BuildContext context, int rewardGems, VoidCallback onClaim) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyRewardModal(rewardGems: rewardGems, onClaim: onClaim),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prog = ProgressionService.instance;
    final curStreak = prog.dailyReward.streakDay;

    const daysGems = [10, 15, 20, 25, 30, 40, 60];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0C103C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFD600), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DAILY LOGIN REWARD',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD600),
              ),
            ),
            const SizedBox(height: 14),

            // 7 Days Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isCurrent = dayNum == curStreak + 1;
                final isClaimed = dayNum <= curStreak;

                return Container(
                  width: 65,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFFFF6D00)
                        : (isClaimed ? const Color(0xFF1B5E20) : const Color(0xFF1E215C)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? Colors.white : Colors.white24,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('Day $dayNum', style: const TextStyle(fontFamily: 'Fredoka', fontSize: 11, color: Colors.white70)),
                      const SizedBox(height: 4),
                      const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 20),
                      Text('+${daysGems[i]}', style: const TextStyle(fontFamily: 'Fredoka', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            GameButton3D(
              text: 'CLAIM +$rewardGems 💎',
              width: 200,
              height: 52,
              fontSize: 18,
              surfaceColor: const Color(0xFF00E676),
              shadowColor: const Color(0xFF00A344),
              onTap: onClaim,
            ),
          ],
        ),
      ),
    );
  }
}
