import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/ads_service.dart';
import 'core/game_audio.dart';
import 'core/theme.dart';
import 'data/player_state.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable runtime fetching via HTTP to prevent startup white screen lag / network stalls
  GoogleFonts.config.allowRuntimeFetching = false;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const BloopPopApp());
}

class BloopPopApp extends StatefulWidget {
  const BloopPopApp({super.key});

  @override
  State<BloopPopApp> createState() => _BloopPopAppState();
}

class _BloopPopAppState extends State<BloopPopApp> with WidgetsBindingObserver {
  late final PlayerState _player;

  @override
  void initState() {
    super.initState();
    _player = PlayerState();
    WidgetsBinding.instance.addObserver(this);
    _player.addListener(_syncAudioSettings);
    unawaited(_initializeAudio());
    // Prompt ATT when app opens on iOS, then initialize Unity Ads legally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UnityAdsService.instance.init();
    });
  }

  Future<void> _initializeAudio() async {
    await _player.ready;
    if (!mounted) return;
    await GameAudio.instance.initialize(
      soundEnabled: _player.sound,
      musicEnabled: _player.music,
      hapticsEnabled: _player.haptics,
    );
  }

  void _syncAudioSettings() {
    GameAudio.instance.updateSettings(
      soundEnabled: _player.sound,
      musicEnabled: _player.music,
      hapticsEnabled: _player.haptics,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    GameAudio.instance.setAppActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.removeListener(_syncAudioSettings);
    _player.dispose();
    unawaited(GameAudio.instance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BloopPop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameColors.bgDarkPlayfield,
        fontFamily: 'Fredoka',
      ),
      home: HomeScreen(player: _player),
    );
  }
}
