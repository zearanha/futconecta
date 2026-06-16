import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../repositories/chat_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../feed/chat_lista_screen.dart';
import '../feed/feed_olheiro_screen.dart';
import '../feed/feed_screen.dart';
import '../favoritos/favoritos_screen.dart';
import '../perfil/perfil_jogador_screen.dart';
import '../ranking/ranking_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 0;
  int? _lastUnreadCount;
  final _chatRepository = ChatRepository();
  late final Future<AppUser?> _userFuture = AuthService().getCurrentAppUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _HomeLoadError(error: snapshot.error);
        }

        final user = snapshot.data;
        if (user == null) {
          return const _HomeLoadError(
            error: 'Perfil de usuario nao encontrado.',
          );
        }
        final isScout = user.tipoUsuario == UserType.clubeTreinadorOlheiro;
        final telas = isScout
            ? const [
                FeedOlheiroScreen(),
                RankingScreen(),
                FavoritosScreen(),
                ChatListaScreen(),
                SettingsScreen(),
              ]
            : const [
                FeedScreen(),
                PerfilJogadorScreen(),
                RankingScreen(),
                ChatListaScreen(),
                SettingsScreen(),
              ];
        final selectedIndex = _indiceAtual.clamp(0, telas.length - 1);
        return StreamBuilder<int>(
          stream: _chatRepository.watchUnreadCount(user.id),
          builder: (context, unreadSnapshot) {
            final chatUnreadCount = unreadSnapshot.data ?? 0;
            final items = _navItems(
              isScout: isScout,
              chatUnreadCount: chatUnreadCount,
            );
            final chatIndex = items.indexWhere((item) => item.label == 'Chat');
            _maybeNotifyUnread(context, chatUnreadCount, chatIndex);

            return Scaffold(
              body: IndexedStack(index: selectedIndex, children: telas),
              bottomNavigationBar: _FutConectaBottomNav(
                selectedIndex: selectedIndex,
                items: items,
                onSelected: (index) => setState(() {
                  _indiceAtual = index;
                }),
              ),
            );
          },
        );
      },
    );
  }

  List<_BottomNavItem> _navItems({
    required bool isScout,
    required int chatUnreadCount,
  }) {
    if (isScout) {
      return [
        const _BottomNavItem(
          icon: Icons.dynamic_feed_outlined,
          selectedIcon: Icons.dynamic_feed_rounded,
          label: 'Feed',
        ),
        const _BottomNavItem(
          icon: Icons.leaderboard_outlined,
          selectedIcon: Icons.leaderboard_rounded,
          label: 'Ranking',
        ),
        const _BottomNavItem(
          icon: Icons.favorite_border_rounded,
          selectedIcon: Icons.favorite_rounded,
          label: 'Observados',
        ),
        _BottomNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Chat',
          badgeCount: chatUnreadCount,
        ),
        const _BottomNavItem(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Conta',
        ),
      ];
    }

    return [
      const _BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
      const _BottomNavItem(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Perfil',
      ),
      const _BottomNavItem(
        icon: Icons.leaderboard_outlined,
        selectedIcon: Icons.leaderboard_rounded,
        label: 'Ranking',
      ),
      _BottomNavItem(
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        label: 'Chat',
        badgeCount: chatUnreadCount,
      ),
      const _BottomNavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Conta',
      ),
    ];
  }

  void _maybeNotifyUnread(
    BuildContext context,
    int unreadCount,
    int chatIndex,
  ) {
    final previousUnreadCount = _lastUnreadCount;
    _lastUnreadCount = unreadCount;

    if (previousUnreadCount == null ||
        unreadCount <= previousUnreadCount ||
        _indiceAtual == chatIndex ||
        chatIndex < 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _indiceAtual == chatIndex) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nova mensagem no chat.'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () => setState(() {
              _indiceAtual = chatIndex;
            }),
          ),
        ),
      );
    });
  }
}

class _FutConectaBottomNav extends StatelessWidget {
  const _FutConectaBottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_BottomNavItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottomPadding),
      child: SizedBox(
        height: 76,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final itemWidth = width / items.length;
            final selectedCenter = itemWidth * (selectedIndex + 0.5);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _NotchedNavBarPainter(
                      selectedCenter: selectedCenter,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                    ),
                    child: SizedBox(
                      height: 58,
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: _BottomNavButton(
                                item: items[index],
                                selected: selectedIndex == index,
                                onTap: () => onSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: selectedCenter - 31,
                  bottom: 26,
                  child: _SelectedNavButton(
                    item: items[selectedIndex],
                    onTap: () => onSelected(selectedIndex),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotchedNavBarPainter extends CustomPainter {
  const _NotchedNavBarPainter({
    required this.selectedCenter,
    required this.backgroundColor,
  });

  final double selectedCenter;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 4, size.width - 4, size.height - 4),
      const Radius.circular(9),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    final barPaint = Paint()..color = const Color(0xFF050706);
    final barRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );
    canvas.drawRRect(barRect, barPaint);

    final cutoutPaint = Paint()
      ..color = backgroundColor
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(Offset(selectedCenter, 0), 34, cutoutPaint);

    final repairPaint = Paint()..color = const Color(0xFF050706);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 20, size.width, size.height - 20),
        const Radius.circular(9),
      ),
      repairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedNavBarPainter oldDelegate) {
    return oldDelegate.selectedCenter != selectedCenter ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 58,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 0 : 1,
                child: _NavIconWithBadge(
                  icon: item.icon,
                  badgeCount: item.badgeCount,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedNavButton extends StatelessWidget {
  const _SelectedNavButton({required this.item, required this.onTap});

  final _BottomNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(7),
        child: Material(
          color: const Color(0xFF050706),
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.24),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: _NavIconWithBadge(
                icon: item.selectedIcon,
                badgeCount: item.badgeCount,
                color: AppColors.accent,
                size: 25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({
    required this.icon,
    required this.badgeCount,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final int badgeCount;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: size),
        if (badgeCount > 0)
          Positioned(
            right: -10,
            top: -10,
            child: _NavBadge(count: badgeCount),
          ),
      ],
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF050706), width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
    this.badgeCount = 0,
  }) : selectedIcon = selectedIcon ?? icon;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
}

class _HomeLoadError extends StatelessWidget {
  const _HomeLoadError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 46,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nao foi possivel carregar sua conta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService().signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sair e tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
