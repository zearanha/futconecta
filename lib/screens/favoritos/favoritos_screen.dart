import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/favorites_repository.dart';
import '../../repositories/player_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_card.dart';
import '../perfil/perfil_jogador_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  FavoriteStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final favoritesRepository = FavoritesRepository();
    final playerRepository = PlayerRepository();

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Entre para ver jogadores observados.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Observados')),
      body: StreamBuilder<List<FavoriteEntry>>(
        stream: favoritesRepository.watchFavorites(userId),
        builder: (context, favSnapshot) {
          final entries = favSnapshot.data ?? const <FavoriteEntry>[];
          if (!favSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entries.isEmpty) {
            return const _EmptyWatchlist();
          }

          final ids = entries.map((entry) => entry.playerId).toSet();
          final statusByPlayer = {
            for (final entry in entries) entry.playerId: entry.status,
          };

          return StreamBuilder(
            stream: playerRepository.watchPlayers(),
            builder: (context, playerSnapshot) {
              if (!playerSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final players = playerSnapshot.data!
                  .where((player) => ids.contains(player.id))
                  .where(
                    (player) =>
                        _statusFilter == null ||
                        statusByPlayer[player.id] == _statusFilter,
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _PipelineHeader(entries: entries),
                  const SizedBox(height: 14),
                  _StatusFilter(
                    selected: _statusFilter,
                    entries: entries,
                    onChanged: (value) => setState(() {
                      _statusFilter = value;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (players.isEmpty)
                    const _NoStatusResults()
                  else
                    ...players.map((player) {
                      final status =
                          statusByPlayer[player.id] ??
                          FavoriteStatus.interessado;
                      return _ObservedPlayerTile(
                        status: status,
                        child: PlayerCard(
                          player: player,
                          isFavorite: true,
                          onFavorite: () => favoritesRepository.toggleFavorite(
                            clubId: userId,
                            playerId: player.id,
                            isFavorite: true,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PerfilJogadorScreen(playerId: player.id),
                            ),
                          ),
                        ),
                        onStatusChanged: (value) {
                          if (value == null) return;
                          favoritesRepository.updateStatus(
                            clubId: userId,
                            playerId: player.id,
                            status: value,
                          );
                        },
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PipelineHeader extends StatelessWidget {
  const _PipelineHeader({required this.entries});

  final List<FavoriteEntry> entries;

  @override
  Widget build(BuildContext context) {
    int count(FavoriteStatus status) {
      return entries.where((entry) => entry.status == status).length;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Funil de observacao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Organize atletas por etapa e acompanhe quem merece contato.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatusMetric(
                  label: 'Interesse',
                  value: '${count(FavoriteStatus.interessado)}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusMetric(
                  label: 'Analise',
                  value: '${count(FavoriteStatus.emAnalise)}',
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusMetric(
                  label: 'Contato',
                  value: '${count(FavoriteStatus.contatoFeito)}',
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusMetric(
                  label: 'Aprovados',
                  value: '${count(FavoriteStatus.aprovado)}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selected,
    required this.entries,
    required this.onChanged,
  });

  final FavoriteStatus? selected;
  final List<FavoriteEntry> entries;
  final ValueChanged<FavoriteStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    int count(FavoriteStatus status) {
      return entries.where((entry) => entry.status == status).length;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Todos (${entries.length})'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          ...FavoriteStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${status.label} (${count(status)})'),
                selected: selected == status,
                onSelected: (_) => onChanged(status),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ObservedPlayerTile extends StatelessWidget {
  const _ObservedPlayerTile({
    required this.child,
    required this.status,
    required this.onStatusChanged,
  });

  final Widget child;
  final FavoriteStatus status;
  final ValueChanged<FavoriteStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Etapa',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              DropdownButton<FavoriteStatus>(
                value: status,
                underline: const SizedBox.shrink(),
                items: FavoriteStatus.values.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item.label));
                }).toList(),
                onChanged: onStatusChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 54, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'Nenhum jogador em observacao ainda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Favorite atletas na Central do olheiro para montar seu funil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoStatusResults extends StatelessWidget {
  const _NoStatusResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 56),
      child: Center(child: Text('Nenhum jogador nesta etapa.')),
    );
  }
}
