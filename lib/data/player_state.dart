import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerState extends ChangeNotifier {
  static const int maxHearts = 10;
  static const int heartRegenSeconds = 20 * 60; // 20 minutes

  String name = 'HAMID RITAB';
  double cash = 0.0;
  int gems = 45;
  int hearts = 10;
  int lastHeartTs = DateTime.now().millisecondsSinceEpoch;
  int level = 1;
  int chestProgress = 0; // 0 to 50
  String ballSkin = 'yellow';
  List<String> ownedSkins = ['yellow', 'basketball', 'tricolor', 'star', 'star_burst'];
  
  Map<String, int> powerups = {
    'smash': 2,
    'balls': 3,
    'rowBlast': 2,
    'fire': 1,
    'stone': 2,
  };

  bool vip = false;
  bool sound = true;
  bool music = true;
  bool haptics = true;

  Timer? _regenTimer;

  PlayerState() {
    _init();
  }

  Future<void> _init() async {
    await load();
    _startRegenLoop();
  }

  void _startRegenLoop() {
    _regenTimer?.cancel();
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkHeartRegen();
    });
  }

  void _checkHeartRegen() {
    if (hearts >= maxHearts) {
      lastHeartTs = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - lastHeartTs) ~/ 1000;
    if (elapsed >= heartRegenSeconds) {
      final gained = elapsed ~/ heartRegenSeconds;
      hearts = math.min(maxHearts, hearts + gained);
      lastHeartTs = now - ((elapsed % heartRegenSeconds) * 1000);
      save();
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Duration get timeUntilNextHeart {
    if (hearts >= maxHearts) return Duration.zero;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - lastHeartTs) ~/ 1000;
    final remaining = heartRegenSeconds - (elapsed % heartRegenSeconds);
    return Duration(seconds: math.max(0, remaining));
  }

  bool canPlay() => hearts > 0;

  bool consumeHeartForGame() {
    if (hearts <= 0) return false;
    hearts--;
    if (hearts == maxHearts - 1) {
      lastHeartTs = DateTime.now().millisecondsSinceEpoch;
    }
    save();
    notifyListeners();
    return true;
  }

  void addHearts(int count) {
    hearts = math.min(maxHearts, hearts + count);
    save();
    notifyListeners();
  }

  void refillHearts() {
    hearts = maxHearts;
    save();
    notifyListeners();
  }

  void addCash(num amount) {
    cash = double.parse((cash + amount.toDouble()).toStringAsFixed(2));
    save();
    notifyListeners();
  }

  void addGems(int amount) {
    gems += amount;
    save();
    notifyListeners();
  }

  void addChestProgress(int amount) {
    chestProgress = math.min(50, chestProgress + amount);
    save();
    notifyListeners();
  }

  void claimChest() {
    chestProgress = 0;
    cash += 500;
    gems += 15;
    powerups['smash'] = (powerups['smash'] ?? 0) + 1;
    save();
    notifyListeners();
  }

  void completeLevel(int levelJustCompleted, [num earnedCash = 0.04]) {
    if (levelJustCompleted >= level) {
      level = levelJustCompleted + 1;
    }
    addCash(earnedCash);
    addChestProgress(5);
    save();
    notifyListeners();
  }

  bool usePowerup(String id) {
    final count = powerups[id] ?? 0;
    if (count > 0) {
      powerups[id] = count - 1;
      save();
      notifyListeners();
      return true;
    }
    return false;
  }

  void addPowerup(String id, int count) {
    powerups[id] = (powerups[id] ?? 0) + count;
    save();
    notifyListeners();
  }

  void setSkin(String skin) {
    ballSkin = skin;
    save();
    notifyListeners();
  }

  void toggleSound() {
    sound = !sound;
    save();
    notifyListeners();
  }

  void toggleMusic() {
    music = !music;
    save();
    notifyListeners();
  }

  void toggleHaptics() {
    haptics = !haptics;
    save();
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'name': name,
        'cash': cash,
        'gems': gems,
        'hearts': hearts,
        'lastHeartTs': lastHeartTs,
        'level': level,
        'chestProgress': chestProgress,
        'ballSkin': ballSkin,
        'ownedSkins': ownedSkins,
        'powerups': powerups,
        'vip': vip,
        'sound': sound,
        'music': music,
        'haptics': haptics,
      };
      await prefs.setString('player_v1', jsonEncode(map));
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('player_v1');
      if (raw != null) {
        final Map<String, dynamic> map = jsonDecode(raw);
        name = map['name'] ?? name;
        cash = (map['cash'] is num) ? (map['cash'] as num).toDouble() : cash;
        gems = map['gems'] ?? gems;
        hearts = map['hearts'] ?? hearts;
        lastHeartTs = map['lastHeartTs'] ?? lastHeartTs;
        level = map['level'] ?? level;
        chestProgress = map['chestProgress'] ?? chestProgress;
        ballSkin = (map['ballSkin'] == null || map['ballSkin'] == 'white') ? 'yellow' : map['ballSkin'];
        ownedSkins = List<String>.from(map['ownedSkins'] ?? ownedSkins);
        if (map['powerups'] != null) {
          powerups = Map<String, int>.from(map['powerups']);
        }
        vip = map['vip'] ?? vip;
        sound = map['sound'] ?? sound;
        music = map['music'] ?? music;
        haptics = map['haptics'] ?? haptics;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }
}
