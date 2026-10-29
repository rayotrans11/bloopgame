import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/ads_service.dart';
import 'core/theme.dart';
import 'data/player_state.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _BloopPopAppState extends State<BloopPopApp> {
  late final PlayerState _player;

  @override
  void initState() {
    super.initState();
    _player = PlayerState();
    // Prompt ATT when app opens on iOS, then initialize Unity Ads legally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UnityAdsService.instance.init();
    });
  }

  @override
  void dispose() {
    _player.dispose();
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
        fontFamily: GoogleFonts.fredoka().fontFamily,
        textTheme: GoogleFonts.fredokaTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: ResponsiveGameContainer(
        child: HomeScreen(player: _player),
      ),
    );
  }
}

/// Keeps the exact mobile arcade aspect ratio on desktop, web, or tablets,
/// while taking full screen on actual phones.
class ResponsiveGameContainer extends StatelessWidget {
  final Widget child;

  const ResponsiveGameContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 520) {
          final targetH = constraints.maxHeight;
          final targetW = (targetH * (9 / 19.5)).clamp(340.0, 480.0);
          return Container(
            color: const Color(0xFF090A1E),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: targetW,
                  height: targetH,
                  decoration: BoxDecoration(
                    color: GameColors.bgPlayfield,
                    border: Border.all(color: GameColors.pillBorder.withValues(alpha: 0.5), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
