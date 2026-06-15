import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../feed/chat_lista_screen.dart';
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
                FeedScreen(),
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
        final destinations = isScout
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  label: 'Ranking',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  label: 'Observados',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Config',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Perfil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined),
                  label: 'Ranking',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Config',
                ),
              ];

        final selectedIndex = _indiceAtual.clamp(0, telas.length - 1);
        return Scaffold(
          body: IndexedStack(index: selectedIndex, children: telas),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primaryLight,
            onDestinationSelected: (index) => setState(() {
              _indiceAtual = index;
            }),
            destinations: destinations,
          ),
        );
      },
    );
  }
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
