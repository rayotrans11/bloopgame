import 'package:flutter/material.dart';
import '../../core/progression_service.dart';
import '../../data/player_state.dart';

class CosmeticShopModal extends StatefulWidget {
  final PlayerState player;

  const CosmeticShopModal({super.key, required this.player});

  static void show(BuildContext context, PlayerState player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CosmeticShopModal(player: player),
    );
  }

  @override
  State<CosmeticShopModal> createState() => _CosmeticShopModalState();
}

class _CosmeticShopModalState extends State<CosmeticShopModal> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.player, ProgressionService.instance]),
      builder: (context, _) {
        final prog = ProgressionService.instance;

        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C103C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: const Color(0xFF4D3BC6), width: 3),
          ),
          child: Column(
            children: [
              // Header: Shop Title + Gems Balance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GEM SHOP',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1545),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.player.gems}',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tabs: Skins & Themes
              TabBar(
                controller: _tabCtrl,
                indicatorColor: const Color(0xFFFFD600),
                labelColor: const Color(0xFFFFD600),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'BLOCK SKINS'),
                  Tab(text: 'BOARD THEMES'),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildSkinsGrid(prog),
                    _buildThemesGrid(prog),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkinsGrid(ProgressionService prog) {
    final skins = [
      {'id': 'candy', 'name': 'Candy (Default)', 'price': 0},
      {'id': 'jelly', 'name': 'Jelly Gloss', 'price': 40},
      {'id': 'gem', 'name': 'Precious Gem', 'price': 60},
      {'id': 'bubble', 'name': 'Bubble Soft', 'price': 80},
      {'id': 'pixel', 'name': '8-Bit Pixel', 'price': 100},
    ];

    return ListView.builder(
      itemCount: skins.length,
      itemBuilder: (context, i) {
        final item = skins[i];
        final id = item['id'] as String;
        final name = item['name'] as String;
        final price = item['price'] as int;
        final isOwned = prog.ownedSkins.contains(id);
        final isEquipped = prog.equippedSkin == id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161A4E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEquipped ? const Color(0xFF00E676) : const Color(0xFF333A8A),
              width: isEquipped ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(fontFamily: 'Fredoka', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              if (isEquipped)
                const Text('EQUIPPED', style: TextStyle(fontFamily: 'Fredoka', color: Color(0xFF00E676), fontWeight: FontWeight.bold))
              else if (isOwned)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  onPressed: () => prog.equipSkin(id),
                  child: const Text('EQUIP'),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00)),
                  onPressed: () {
                    final bought = prog.buySkin(
                      id,
                      price,
                      spendGems: (amt) {
                        if (widget.player.gems >= amt) {
                          widget.player.gems -= amt;
                          widget.player.save();
                          return true;
                        }
                        return false;
                      },
                    );
                    if (!bought) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not enough gems!'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text('$price 💎'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemesGrid(ProgressionService prog) {
    final themes = [
      {'id': 'neon_night', 'name': 'Neon Night (Default)', 'price': 0},
      {'id': 'sunset', 'name': 'Sunset Glow', 'price': 50},
      {'id': 'ocean', 'name': 'Deep Ocean', 'price': 75},
      {'id': 'candy_land', 'name': 'Candy Land', 'price': 90},
    ];

    return ListView.builder(
      itemCount: themes.length,
      itemBuilder: (context, i) {
        final item = themes[i];
        final id = item['id'] as String;
        final name = item['name'] as String;
        final price = item['price'] as int;
        final isOwned = prog.ownedThemes.contains(id);
        final isEquipped = prog.equippedTheme == id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161A4E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEquipped ? const Color(0xFF00E676) : const Color(0xFF333A8A),
              width: isEquipped ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(fontFamily: 'Fredoka', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              if (isEquipped)
                const Text('EQUIPPED', style: TextStyle(fontFamily: 'Fredoka', color: Color(0xFF00E676), fontWeight: FontWeight.bold))
              else if (isOwned)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  onPressed: () => prog.equipTheme(id),
                  child: const Text('EQUIP'),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00)),
                  onPressed: () {
                    final bought = prog.buyTheme(
                      id,
                      price,
                      spendGems: (amt) {
                        if (widget.player.gems >= amt) {
                          widget.player.gems -= amt;
                          widget.player.save();
                          return true;
                        }
                        return false;
                      },
                    );
                    if (!bought) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not enough gems!'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text('$price 💎'),
                ),
            ],
          ),
        );
      },
    );
  }
}
