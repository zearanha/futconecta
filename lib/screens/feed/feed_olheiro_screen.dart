import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/player.dart';
import '../../repositories/favorites_repository.dart';
import '../../repositories/player_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_card.dart';
import '../perfil/perfil_jogador_screen.dart';
import '../search/busca_jogadores_screen.dart';

class FeedOlheiroScreen extends StatelessWidget {
  const FeedOlheiroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerRepository = PlayerRepository();
    final favoritesRepository = FavoritesRepository();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central do olheiro'),
        actions: [
          IconButton(
            tooltip: 'Busca avancada',
            icon: const Icon(Icons.tune),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: FutureBuilder<AppUser?>(
        future: AuthService().getCurrentAppUser(),
        builder: (context, userSnapshot) {
          return StreamBuilder<List<Player>>(
            stream: playerRepository.watchPlayers(),
            builder: (context, playersSnapshot) {
              if (!playersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final players = playersSnapshot.data!;
              return StreamBuilder<Set<String>>(
                stream: currentUserId == null
                    ? Stream.value(<String>{})
                    : favoritesRepository.watchFavoritePlayerIds(currentUserId),
                builder: (context, favoritesSnapshot) {
                  final favorites = favoritesSnapshot.data ?? <String>{};
                  return _ScoutDashboard(
                    user: userSnapshot.data,
                    players: players,
                    favorites: favorites,
                    favoritesRepository: favoritesRepository,
                    currentUserId: currentUserId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuscaJogadoresScreen()),
    );
  }
}

class _ScoutDashboard extends StatelessWidget {
  const _ScoutDashboard({
    required this.user,
    required this.players,
    required this.favorites,
    required this.favoritesRepository,
    required this.currentUserId,
  });

  final AppUser? user;
  final List<Player> players;
  final Set<String> favorites;
  final FavoritesRepository favoritesRepository;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final prioritized = [...players]
      ..sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    final featured = prioritized.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _ScoutHeader(
          user: user,
          players: players,
          favoritesCount: favorites.length,
        ),
        const SizedBox(height: 12),
        _QuickActions(
          onSearch: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuscaJogadoresScreen()),
          ),
        ),
        const SizedBox(height: 18),
        if (players.isEmpty)
          const _EmptyState()
        else ...[
          _TalentHighlights(players: featured),
          const SizedBox(height: 18),
          _PipelineOverview(players: players, favoritesCount: favorites.length),
          const SizedBox(height: 18),
          const Text(
            'Talentos para observar',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...prioritized.map((player) {
            final isFavorite = favorites.contains(player.id);
            return PlayerCard(
              player: player,
              isFavorite: isFavorite,
              onFavorite: currentUserId == null
                  ? null
                  : () => favoritesRepository.toggleFavorite(
                      clubId: currentUserId!,
                      playerId: player.id,
                      isFavorite: isFavorite,
                    ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilJogadorScreen(playerId: player.id),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _ScoutHeader extends StatelessWidget {
  const _ScoutHeader({
    required this.user,
    required this.players,
    required this.favoritesCount,
  });

  final AppUser? user;
  final List<Player> players;
  final int favoritesCount;

  @override
  Widget build(BuildContext context) {
    final topRated = players
        .where((player) => player.mediaAvaliacoes >= 4)
        .length;
    final youngTalents = players.where((player) {
      return player.idade > 0 && player.idade <= 20;
    }).length;
    final greetingName = (user?.nome ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.manage_search, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingName.isEmpty
                          ? 'Painel de prospeccao'
                          : 'Ola, $greetingName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Acompanhe indicadores e encontre atletas com potencial.',
                      maxLines: 2,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(label: 'Base', value: '${players.length}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderMetric(
                  label: 'Observados',
                  value: '$favoritesCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderMetric(label: 'Nota 4+', value: '$topRated'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderMetric(label: 'Sub-20', value: '$youngTalents'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Filtrar atletas'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            label: const Text('Buscar agora'),
          ),
        ),
      ],
    );
  }
}

class _TalentHighlights extends StatelessWidget {
  const _TalentHighlights({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Destaques da base',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: players.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final player = players[index];
              return _HighlightCard(player: player, rank: index + 1);
            },
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.player, required this.rank});

  final Player player;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PerfilJogadorScreen(playerId: player.id),
        ),
      ),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: player.fotoUrl.isEmpty
                      ? null
                      : NetworkImage(player.fotoUrl),
                  child: player.fotoUrl.isEmpty
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    player.nome.isEmpty ? 'Atleta sem nome' : player.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              player.posicaoPrincipal.isEmpty
                  ? 'Posicao nao informada'
                  : player.posicaoPrincipal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SmallStat(
                  icon: Icons.star,
                  text: player.mediaAvaliacoes.toStringAsFixed(1),
                ),
                const SizedBox(width: 8),
                _SmallStat(
                  icon: Icons.sports_soccer,
                  text: '${player.stats.gols} gols',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineOverview extends StatelessWidget {
  const _PipelineOverview({
    required this.players,
    required this.favoritesCount,
  });

  final List<Player> players;
  final int favoritesCount;

  @override
  Widget build(BuildContext context) {
    final completeProfiles = players.where((player) {
      return player.nome.isNotEmpty &&
          player.posicaoPrincipal.isNotEmpty &&
          player.cidade.isNotEmpty &&
          player.stats.jogos > 0;
    }).length;
    final offensivePlayers = players.where((player) {
      return player.stats.gols > 0 || player.stats.assistencias > 0;
    }).length;
    final conversion = players.isEmpty
        ? 0
        : ((favoritesCount / players.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Perfis completos',
            value: '$completeProfiles de ${players.length}',
          ),
          const Divider(height: 20),
          _InsightRow(
            icon: Icons.trending_up,
            label: 'Com participacao ofensiva',
            value: '$offensivePlayers atletas',
          ),
          const Divider(height: 20),
          _InsightRow(
            icon: Icons.bookmark_added_outlined,
            label: 'Taxa em observacao',
            value: '$conversion%',
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.muted, size: 15),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.sports_soccer, size: 48, color: AppColors.muted),
          SizedBox(height: 12),
          Text(
            'Nenhum jogador cadastrado ainda.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Quando atletas criarem seus perfis, eles aparecerao aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
