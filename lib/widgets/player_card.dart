import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/app_theme.dart';

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    required this.onTap,
    this.onFavorite,
    this.onMessage,
    this.isFavorite = false,
    this.rank,
  });

  final Player player;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onMessage;
  final bool isFavorite;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppDecorations.card(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.scout.withValues(alpha: 0.16),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: player.fotoUrl.isEmpty
                            ? null
                            : NetworkImage(player.fotoUrl),
                        child: player.fotoUrl.isEmpty
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    if (rank != null)
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.gold,
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.nome.isEmpty ? 'Atleta sem nome' : player.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${player.posicaoPrincipal.isEmpty ? 'Posicao nao informada' : player.posicaoPrincipal} - ${player.idade} anos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            text: '${player.cidade}/${player.estado}',
                          ),
                          _InfoChip(
                            icon: Icons.sports_soccer,
                            text: '${player.stats.gols} gols',
                          ),
                          _InfoChip(
                            icon: Icons.star,
                            text: player.mediaAvaliacoes.toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMessage != null)
                      _CardActionButton(
                        tooltip: 'Enviar mensagem',
                        icon: Icons.chat_bubble_outline,
                        color: AppColors.scout,
                        onPressed: onMessage,
                      ),
                    if (onFavorite != null)
                      _CardActionButton(
                        tooltip: isFavorite ? 'Remover favorito' : 'Favoritar',
                        icon: isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite ? Colors.redAccent : AppColors.muted,
                        onPressed: onFavorite,
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

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
