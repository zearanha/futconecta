import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/player.dart';
import '../../repositories/favorites_repository.dart';
import '../../repositories/player_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../perfil/perfil_jogador_screen.dart';
import '../search/busca_jogadores_screen.dart';

class _ScoutPalette {
  static const bgTop = Color(0xFF101820);
  static const bgBottom = Color(0xFF121F1B);
  static const panel = Color(0xFF17251F);
  static const panelSoft = Color(0xFF1B2D26);
  static const avatar = Color(0xFF22362E);
  static const border = Color(0xFF2C443A);
  static const accent = Color(0xFF24C96F);
  static const muted = Color(0xFFA9B8AE);
}

class FeedOlheiroScreen extends StatelessWidget {
  const FeedOlheiroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerRepository = PlayerRepository();
    final favoritesRepository = FavoritesRepository();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _ScoutPalette.bgTop,
      appBar: AppBar(
        title: const Text('Descobrir'),
        backgroundColor: _ScoutPalette.bgTop,
        foregroundColor: Colors.white,
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ScoutPalette.bgTop, _ScoutPalette.bgBottom],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _ScoutHeader(
            user: user,
            players: players,
            favoritesCount: favorites.length,
          ),
          const SizedBox(height: 18),
          _QuickActions(
            onSearch: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BuscaJogadoresScreen()),
            ),
          ),
          const SizedBox(height: 22),
          if (players.isEmpty)
            const _EmptyState()
          else ...[
            _TalentHighlights(players: featured),
            const SizedBox(height: 20),
            _PipelineOverview(
              players: players,
              favoritesCount: favorites.length,
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'TALENTOS EM ALTA',
              action: 'VER TODOS',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuscaJogadoresScreen()),
              ),
            ),
            const SizedBox(height: 12),
            ...prioritized.map((player) {
              final isFavorite = favorites.contains(player.id);
              return _ScoutPlayerTile(
                player: player,
                isFavorite: isFavorite,
                onMessage: currentUserId == null
                    ? null
                    : () => _openChatOrExplain(
                        context: context,
                        player: player,
                        isFavorite: isFavorite,
                      ),
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
      ),
    );
  }

  void _openChatOrExplain({
    required BuildContext context,
    required Player player,
    required bool isFavorite,
  }) {
    if (!isFavorite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione o jogador aos observados antes de conversar.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: player.userId,
          receiverName: player.nome.isEmpty ? 'Jogador' : player.nome,
        ),
      ),
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
        gradient: AppDecorations.heroGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 34, color: _ScoutPalette.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EM ASCENSAO',
                style: TextStyle(
                  color: _ScoutPalette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(foregroundColor: _ScoutPalette.accent),
          child: Text(
            '$action >',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoutPlayerTile extends StatelessWidget {
  const _ScoutPlayerTile({
    required this.player,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onMessage,
  });

  final Player player;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final position = player.posicaoPrincipal.isEmpty
        ? 'N/D'
        : player.posicaoPrincipal.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _ScoutPalette.panel,
        border: Border.all(color: _ScoutPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _ScoutPalette.avatar,
                  backgroundImage: player.fotoUrl.isEmpty
                      ? null
                      : NetworkImage(player.fotoUrl),
                  child: player.fotoUrl.isEmpty
                      ? const Icon(Icons.person, color: _ScoutPalette.accent)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              player.nome.isEmpty
                                  ? 'ATLETA SEM NOME'
                                  : player.nome.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            position.length > 3
                                ? position.substring(0, 3)
                                : position,
                            style: const TextStyle(
                              color: _ScoutPalette.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _ScoutStat(label: 'IDADE', value: '${player.idade}'),
                          _ScoutStat(
                            label: 'NOTA',
                            value: player.mediaAvaliacoes.toStringAsFixed(1),
                          ),
                          _ScoutStat(
                            label: 'GOLS',
                            value: '${player.stats.gols}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _SquareAction(
                      tooltip: isFavorite
                          ? 'Remover observado'
                          : 'Adicionar observado',
                      icon: isFavorite ? Icons.favorite : Icons.add,
                      onTap: onFavorite,
                    ),
                    const SizedBox(height: 8),
                    _SquareAction(
                      tooltip: 'Enviar mensagem',
                      icon: Icons.chat_bubble_outline,
                      onTap: onMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoutStat extends StatelessWidget {
  const _ScoutStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF789986),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _ScoutPalette.panelSoft,
            border: Border.all(color: _ScoutPalette.border),
          ),
          child: Icon(icon, color: _ScoutPalette.accent, size: 20),
        ),
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
            style: OutlinedButton.styleFrom(
              foregroundColor: _ScoutPalette.accent,
              side: const BorderSide(color: _ScoutPalette.border),
              backgroundColor: _ScoutPalette.panelSoft,
            ),
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Filtrar atletas'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ScoutPalette.accent,
              foregroundColor: _ScoutPalette.bgTop,
            ),
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
            color: Colors.white,
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
          color: _ScoutPalette.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _ScoutPalette.border),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _ScoutPalette.accent,
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: _ScoutPalette.bgTop,
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
                color: _ScoutPalette.accent,
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
        color: _ScoutPalette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScoutPalette.border),
      ),
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Perfis completos',
            value: '$completeProfiles de ${players.length}',
          ),
          const Divider(height: 20, color: _ScoutPalette.border),
          _InsightRow(
            icon: Icons.trending_up,
            label: 'Com participacao ofensiva',
            value: '$offensivePlayers atletas',
          ),
          const Divider(height: 20, color: _ScoutPalette.border),
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
            color: _ScoutPalette.panelSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _ScoutPalette.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _ScoutPalette.accent,
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
        Icon(icon, color: _ScoutPalette.muted, size: 15),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: _ScoutPalette.muted, fontSize: 12),
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
        color: _ScoutPalette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScoutPalette.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.sports_soccer, size: 48, color: _ScoutPalette.accent),
          SizedBox(height: 12),
          Text(
            'Nenhum jogador cadastrado ainda.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Quando atletas criarem seus perfis, eles aparecerao aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ScoutPalette.muted),
          ),
        ],
      ),
    );
  }
}
