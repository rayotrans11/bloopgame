import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelProgress {
  final int levelId;
  final int stars; // 0..3
  final int bestScore;
  final bool completed;

  const LevelProgress({
    required this.levelId,
    required this.stars,
    required this.bestScore,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'stars': stars,
        'bestScore': bestScore,
        'completed': completed,
      };

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
        levelId: json['levelId'] as int,
        stars: json['stars'] as int? ?? 0,
        bestScore: json['bestScore'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
      );
}

class DailyRewardState {
  final DateTime lastClaimUtc;
  final int streakDay; // 1..7

  const DailyRewardState({
    required this.lastClaimUtc,
    required this.streakDay,
  });

  Map<String, dynamic> toJson() => {
        'lastClaimUtc': lastClaimUtc.toIso8601String(),
        'streakDay': streakDay,
      };

  factory DailyRewardState.fromJson(Map<String, dynamic> json) => DailyRewardState(
        lastClaimUtc: DateTime.tryParse(json['lastClaimUtc'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        streakDay: json['streakDay'] as int? ?? 0,
      );
}

class ProgressionService extends ChangeNotifier {
  ProgressionService._();
  static final ProgressionService instance = ProgressionService._();

  Map<int, LevelProgress> _progress = {};
  int _highestUnlockedLevel = 1;
  DailyRewardState _dailyReward = DailyRewardState(
    lastClaimUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    streakDay: 0,
  );

  bool _colorblindMode = false;
  String _equippedSkin = 'candy'; // candy, jelly, gem, bubble, pixel
  String _equippedTheme = 'neon_night'; // neon_night, sunset, ocean, candy_land
  List<String> _ownedSkins = ['candy'];
  List<String> _ownedThemes = ['neon_night'];

  int _dailyChallengeHighScore = 0;
  int _dailyChallengeStreak = 0;
  String _lastDailyChallengeDate = '';

  bool get colorblindMode => _colorblindMode;
  int get highestUnlockedLevel => _highestUnlockedLevel;
  Map<int, LevelProgress> get progress => _progress;
  DailyRewardState get dailyReward => _dailyReward;
  String get equippedSkin => _equippedSkin;
  String get equippedTheme => _equippedTheme;
  List<String> get ownedSkins => _ownedSkins;
  List<String> get ownedThemes => _ownedThemes;
  int get dailyChallengeHighScore => _dailyChallengeHighScore;
  int get dailyChallengeStreak => _dailyChallengeStreak;
  String get lastDailyChallengeDate => _lastDailyChallengeDate;

  int get totalStars => _progress.values.fold(0, (sum, p) => sum + p.stars);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _colorblindMode = prefs.getBool('prog_colorblind') ?? false;
      _highestUnlockedLevel = prefs.getInt('prog_highest_unlocked') ?? 1;

      final rawProg = prefs.getString('prog_levels');
      if (rawProg != null) {
        final decoded = jsonDecode(rawProg) as Map<String, dynamic>;
        _progress = decoded.map((k, v) =>
            MapEntry(int.parse(k), LevelProgress.fromJson(v as Map<String, dynamic>)));
      }

      final rawDaily = prefs.getString('prog_daily_reward');
      if (rawDaily != null) {
        _dailyReward = DailyRewardState.fromJson(jsonDecode(rawDaily) as Map<String, dynamic>);
      }

      _equippedSkin = prefs.getString('prog_skin') ?? 'candy';
      _equippedTheme = prefs.getString('prog_theme') ?? 'neon_night';
      _ownedSkins = prefs.getStringList('prog_owned_skins') ?? ['candy'];
      _ownedThemes = prefs.getStringList('prog_owned_themes') ?? ['neon_night'];

      _dailyChallengeHighScore = prefs.getInt('prog_dc_score') ?? 0;
      _dailyChallengeStreak = prefs.getInt('prog_dc_streak') ?? 0;
      _lastDailyChallengeDate = prefs.getString('prog_dc_date') ?? '';

      notifyListeners();
    } catch (_) {}
  }

  void toggleColorblindMode([bool? enabled]) {
    _colorblindMode = enabled ?? !_colorblindMode;
    _saveKey('prog_colorblind', _colorblindMode);
    notifyListeners();
  }

  LevelProgress getLevelProgress(int levelId) {
    return _progress[levelId] ??
        LevelProgress(levelId: levelId, stars: 0, bestScore: 0, completed: false);
  }

  /// Records level completion, computes new stars, returns bonus gems earned
  int recordLevelCompletion({
    required int levelId,
    required int movesLeft,
    required int maxMoves,
    required int score,
  }) {
    // Star Calculation (Section 1.2):
    // 3 stars: >= 50% moves left
    // 2 stars: >= 25% moves left
    // 1 star: reached goal
    int starsEarned = 1;
    if (movesLeft >= (maxMoves * 0.50).ceil()) {
      starsEarned = 3;
    } else if (movesLeft >= (maxMoves * 0.25).ceil()) {
      starsEarned = 2;
    }

    final prev = getLevelProgress(levelId);
    final bestStars = starsEarned > prev.stars ? starsEarned : prev.stars;
    final bestScore = score > prev.bestScore ? score : prev.bestScore;

    // Bonus Gems: 5 gems per new star achieved on this level
    final newStars = bestStars - prev.stars;
    final bonusGems = (newStars > 0 ? newStars * 5 : 0) + 10; // 10 base + 5 per new star

    _progress[levelId] = LevelProgress(
      levelId: levelId,
      stars: bestStars,
      bestScore: bestScore,
      completed: true,
    );

    if (levelId >= _highestUnlockedLevel) {
      _highestUnlockedLevel = levelId + 1;
      _saveKey('prog_highest_unlocked', _highestUnlockedLevel);
    }

    _saveProgress();
    notifyListeners();
    return bonusGems;
  }

  bool canClaimDailyReward() {
    final now = DateTime.now().toUtc();
    final last = _dailyReward.lastClaimUtc;
    final nowDay = DateTime.utc(now.year, now.month, now.day);
    final lastDay = DateTime.utc(last.year, last.month, last.day);
    return nowDay.difference(lastDay).inDays >= 1;
  }

  int claimDailyReward() {
    final now = DateTime.now().toUtc();
    final last = _dailyReward.lastClaimUtc;
    final nowDay = DateTime.utc(now.year, now.month, now.day);
    final lastDay = DateTime.utc(last.year, last.month, last.day);
    final diffDays = nowDay.difference(lastDay).inDays;

    int newStreak;
    if (diffDays == 1) {
      newStreak = (_dailyReward.streakDay % 7) + 1;
    } else if (diffDays > 1) {
      newStreak = 1; // reset streak if missed
    } else {
      return 0; // already claimed today
    }

    // Days 1..7 reward table: 10, 15, 20, 25, 30, 40, 60 gems
    const rewards = [10, 15, 20, 25, 30, 40, 60];
    final gemsReward = rewards[(newStreak - 1).clamp(0, 6)];

    _dailyReward = DailyRewardState(lastClaimUtc: now, streakDay: newStreak);
    _saveKey('prog_daily_reward', jsonEncode(_dailyReward.toJson()));
    notifyListeners();
    return gemsReward;
  }

  void equipSkin(String skinId) {
    if (_ownedSkins.contains(skinId)) {
      _equippedSkin = skinId;
      _saveKey('prog_skin', skinId);
      notifyListeners();
    }
  }

  void equipTheme(String themeId) {
    if (_ownedThemes.contains(themeId)) {
      _equippedTheme = themeId;
      _saveKey('prog_theme', themeId);
      notifyListeners();
    }
  }

  bool buySkin(String skinId, int price, {required bool Function(int) spendGems}) {
    if (_ownedSkins.contains(skinId)) return true;
    if (spendGems(price)) {
      _ownedSkins.add(skinId);
      _equippedSkin = skinId;
      _saveKey('prog_owned_skins', _ownedSkins);
      _saveKey('prog_skin', skinId);
      notifyListeners();
      return true;
    }
    return false;
  }

  bool buyTheme(String themeId, int price, {required bool Function(int) spendGems}) {
    if (_ownedThemes.contains(themeId)) return true;
    if (spendGems(price)) {
      _ownedThemes.add(themeId);
      _equippedTheme = themeId;
      _saveKey('prog_owned_themes', _ownedThemes);
      _saveKey('prog_theme', themeId);
      notifyListeners();
      return true;
    }
    return false;
  }

  void recordDailyChallengeResult(String todayKey, int score) {
    if (_lastDailyChallengeDate != todayKey) {
      _lastDailyChallengeDate = todayKey;
      _dailyChallengeStreak++;
      _saveKey('prog_dc_date', todayKey);
      _saveKey('prog_dc_streak', _dailyChallengeStreak);
    }
    if (score > _dailyChallengeHighScore) {
      _dailyChallengeHighScore = score;
      _saveKey('prog_dc_score', score);
    }
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final enc = _progress.map((k, v) => MapEntry(k.toString(), v.toJson()));
    _saveKey('prog_levels', jsonEncode(enc));
  }

  Future<void> _saveKey(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is List<String>) await prefs.setStringList(key, value);
  }
}
