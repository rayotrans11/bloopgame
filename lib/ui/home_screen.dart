import 'package:flutter/material.dart';
import '../../core/ads_service.dart';
import '../../core/theme.dart';
import '../../data/player_state.dart';
import '../../game/game_screen.dart';
import 'widgets/game_icons.dart';
import 'widgets/hud_pills.dart';
import 'widgets/logo.dart';
import 'widgets/popups.dart';

class HomeScreen extends StatefulWidget {
  final PlayerState player;

  const HomeScreen({super.key, required this.player});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _transitionCtrl;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _uiFadeAnimation;
  late final Animation<double> _flashAnimation;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // BloopPop logo zooms in rapidly (1.0 -> 2.6x)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: Curves.easeInQuad),
    );

    // BloopPop logo fades out as it zooms toward the camera
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
    );

    // Other UI elements fade away fast to focus on the zooming logo
    _uiFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );

    // Screen light flash
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.45).animate(
      CurvedAnimation(parent: _transitionCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _transitionCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_isTransitioning) return;

    if (!widget.player.canPlay()) {
      Popups.showOutOfHearts(context, widget.player);
      return;
    }

    widget.player.consumeHeartForGame();

    setState(() {
      _isTransitioning = true;
    });

    // Run the fast logo zoom-in and fade transition!
    await _transitionCtrl.forward();

    if (!mounted) return;

    // Fast seamless push to GameScreen
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: GameScreen(
            levelId: widget.player.level,
            player: widget.player,
          ),
        ),
      ),
    );

    // Reset when returning to Home
    if (mounted) {
      _transitionCtrl.reset();
      setState(() {
        _isTransitioning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.bgPlayfield,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E216B),
              Color(0xFF13154A),
              Color(0xFF0D0F35),
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.player,
            builder: (context, _) {
              return AnimatedBuilder(
                animation: _transitionCtrl,
                builder: (context, child) {
                  final uiOpacity = _isTransitioning ? _uiFadeAnimation.value : 1.0;
                  final logoScale = _isTransitioning ? _scaleAnimation.value : 1.05;
                  final logoOpacity = _isTransitioning ? _fadeAnimation.value : 1.0;

                  return Stack(
                    children: [
                      // Main Content Column
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),

                            // 1. Top HUD Row
                            Opacity(
                              opacity: uiOpacity.clamp(0.0, 1.0),
                              child: HudRow(
                                player: widget.player,
                                onAddGems: () {
                                  UnityAdsService.instance.recordMenuClick();
                                  Popups.showDailyCheckIn(context, widget.player);
                                },
                                onAddHearts: () {
                                  UnityAdsService.instance.recordMenuClick();
                                  Popups.showOutOfHearts(context, widget.player);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Profile Row: Selected App Icon + Just Level + Skin Button
                            Opacity(
                              opacity: uiOpacity.clamp(0.0, 1.0),
                              child: _buildProfileAndSkinRow(context),
                            ),

                            const Spacer(flex: 3),

                            // 3. BloopPop Animated Logo with Zoom & Fade Transition
                            Transform.scale(
                              scale: logoScale,
                              child: Opacity(
                                opacity: logoOpacity.clamp(0.0, 1.0),
                                child: const BloopPopLogo(scale: 1.05),
                              ),
                            ),

                            const Spacer(flex: 3),

                            // 4. Large 3D START Button
                            Opacity(
                              opacity: uiOpacity.clamp(0.0, 1.0),
                              child: GameButton3D(
                                text: 'START',
                                width: 255,
                                height: 72,
                                fontSize: 34,
                                pulsing: !_isTransitioning,
                                surfaceColor: GameColors.startBlue,
                                shadowColor: GameColors.startBlueDark,
                                onTap: _startGame,
                              ),
                            ),

                            const Spacer(flex: 4),
                          ],
                        ),
                      ),

                      // Floating Side Button: Challenge Trophy only
                      Positioned(
                        right: 16,
                        bottom: 120,
                        child: Opacity(
                          opacity: uiOpacity.clamp(0.0, 1.0),
                          child: GestureDetector(
                            onTap: () {
                              UnityAdsService.instance.recordMenuClick();
                              Popups.showFeatureSheet(
                                context,
                                'DAILY CHALLENGE',
                                'trophy',
                                'Level ${widget.player.level} Challenge!\nPop blocks with perfect precision to earn bonus Gems and exclusive skins!',
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CustomPaint(painter: GameIconPainter(type: 'trophy')),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Challenge',
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 3),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Fast camera zoom flash overlay
                      if (_isTransitioning)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.white.withValues(alpha: _flashAnimation.value),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAndSkinRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Level Card with the selected App Icon
        GestureDetector(
          onTap: () {
            UnityAdsService.instance.recordMenuClick();
            Popups.showSettings(context, widget.player);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: GameColors.pillFill.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GameColors.pillBorder.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected App Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7.5),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.videogame_asset_rounded, color: Colors.yellowAccent, size: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Just the Level (No user name)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GameColors.levelPill,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: GameColors.levelPillDark,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Text(
                    'LEVEL ${widget.player.level}',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Settings and Skin action buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Settings Button (styled like Home button)
            GestureDetector(
              onTap: () {
                UnityAdsService.instance.recordMenuClick();
                Popups.showSettings(context, widget.player);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C4CB2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8A7AE6), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.settings, color: Colors.white, size: 21),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Skin Button
            GestureDetector(
              onTap: () {
                UnityAdsService.instance.recordMenuClick();
                Popups.showSkins(context, widget.player);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C4CB2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8A7AE6), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: GameIconPainter(type: 'skin_swirl')),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Skin',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
