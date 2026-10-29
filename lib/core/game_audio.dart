import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum GameSound { uiTap, launch, blockHit, blockPop, orb, powerUp, win, lose }

enum GameHaptic { selection, light, medium, success, error }

/// Shared audio and haptic feedback for the game. The player's saved settings
/// are applied here so every screen uses the same switches.
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final List<AudioPlayer> _effectPlayers = List.generate(
    4,
    (_) => AudioPlayer(),
  );

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _hapticsEnabled = true;
  bool _configured = false;
  bool _musicLoaded = false;
  bool _appActive = true;
  int _nextEffectPlayer = 0;
  Future<void> _musicQueue = Future<void>.value();
  DateTime _lastBlockHit = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBlockPop = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize({
    required bool soundEnabled,
    required bool musicEnabled,
    required bool hapticsEnabled,
  }) async {
    _soundEnabled = soundEnabled;
    _musicEnabled = musicEnabled;
    _hapticsEnabled = hapticsEnabled;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _configured = true;
    _queueMusicSync();
  }

  void updateSettings({
    required bool soundEnabled,
    required bool musicEnabled,
    required bool hapticsEnabled,
  }) {
    _soundEnabled = soundEnabled;
    _hapticsEnabled = hapticsEnabled;
    if (_musicEnabled != musicEnabled) {
      _musicEnabled = musicEnabled;
      if (_configured) _queueMusicSync();
    }
  }

  void setAppActive(bool active) {
    if (_appActive == active) return;
    _appActive = active;
    if (_configured) _queueMusicSync();
  }

  void play(GameSound sound) {
    if (!_soundEnabled) return;

    final now = DateTime.now();
    if (sound == GameSound.blockHit) {
      if (now.difference(_lastBlockHit) < const Duration(milliseconds: 55)) {
        return;
      }
      _lastBlockHit = now;
    } else if (sound == GameSound.blockPop) {
      if (now.difference(_lastBlockPop) < const Duration(milliseconds: 90)) {
        return;
      }
      _lastBlockPop = now;
    }

    final (asset, volume) = switch (sound) {
      GameSound.uiTap => ('audio/sfx/ui_click.wav', 0.32),
      GameSound.launch => ('audio/sfx/ui_click.wav', 0.24),
      GameSound.blockHit => ('audio/sfx/block_hit.wav', 0.42),
      GameSound.blockPop => ('audio/sfx/block_pop.wav', 0.4),
      GameSound.orb => ('audio/sfx/orb_collect.wav', 0.48),
      GameSound.powerUp => ('audio/sfx/block_pop.wav', 0.38),
      GameSound.win => ('audio/sfx/level_complete.wav', 0.55),
      GameSound.lose => ('audio/sfx/error.wav', 0.42),
    };

    final player = _effectPlayers[_nextEffectPlayer++ % _effectPlayers.length];
    unawaited(_playEffect(player, asset, volume));
  }

  Future<void> _playEffect(
    AudioPlayer player,
    String asset,
    double volume,
  ) async {
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Audio is optional; playback failures must not interrupt gameplay.
    }
  }

  void haptic(GameHaptic type) {
    if (!_hapticsEnabled) return;
    final now = DateTime.now();
    if ((type == GameHaptic.light ||
            type == GameHaptic.medium ||
            type == GameHaptic.selection) &&
        now.difference(_lastHaptic) < const Duration(milliseconds: 65)) {
      return;
    }
    _lastHaptic = now;
    final Future<void> feedback = switch (type) {
      GameHaptic.selection => HapticFeedback.selectionClick(),
      GameHaptic.light => HapticFeedback.lightImpact(),
      GameHaptic.medium => HapticFeedback.mediumImpact(),
      GameHaptic.success => HapticFeedback.heavyImpact(),
      GameHaptic.error => HapticFeedback.vibrate(),
    };
    unawaited(feedback.catchError((_) {}));
  }

  void _queueMusicSync() {
    _musicQueue = _musicQueue.catchError((_) {}).then((_) async {
      try {
        if (!_musicEnabled || !_appActive) {
          if (_musicLoaded) {
            if (_musicEnabled) {
              await _musicPlayer.pause();
            } else {
              await _musicPlayer.stop();
              _musicLoaded = false;
            }
          }
          return;
        }

        if (_musicLoaded) {
          await _musicPlayer.resume();
        } else {
          await _musicPlayer.play(
            AssetSource('audio/music/menu_loop.wav'),
            volume: 0.2,
          );
          _musicLoaded = true;
        }
      } catch (_) {
        // Audio is optional; playback failures must not interrupt gameplay.
      }
    });
  }

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    for (final player in _effectPlayers) {
      await player.dispose();
    }
  }
}
