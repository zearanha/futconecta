import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/player.dart';
import '../../repositories/player_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_title.dart';
import '../chat/chat_screen.dart';
import 'editar_perfil_screen.dart';

class PerfilJogadorScreen extends StatelessWidget {
  const PerfilJogadorScreen({super.key, this.playerId});

  final String? playerId;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final id = playerId ?? currentUser?.uid;
    final repository = PlayerRepository();

    if (id == null) {
      return const Scaffold(body: Center(child: Text('Perfil indisponivel.')));
    }

    return StreamBuilder<Player?>(
      stream: repository.watchPlayer(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Perfil')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nao foi possivel carregar o perfil.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final player = snapshot.data;
        if (player == null) {
          final isOwner = currentUser?.uid == id;
          return Scaffold(
            appBar: AppBar(title: const Text('Perfil')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_search_outlined,
                      size: 56,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isOwner
                          ? 'Seu perfil de jogador ainda nao foi criado.'
                          : 'Perfil nao encontrado.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Preencha seus dados para aparecer no feed, ranking e buscas dos clubes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditarPerfilScreen(playerId: id),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Criar perfil'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        final isOwner = currentUser?.uid == player.userId;
        return Scaffold(
          appBar: AppBar(
            title: Text(isOwner ? 'Meu perfil' : 'Perfil do jogador'),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'Editar perfil',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarPerfilScreen(playerId: player.id),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(player: player),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          currentUser == null || currentUser.uid == player.userId
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  receiverId: player.userId,
                                  receiverName: player.nome,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat interno'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'WhatsApp',
                    onPressed: player.telefone.isEmpty
                        ? null
                        : () => launchUrl(
                            Uri.parse('https://wa.me/${player.telefone}'),
                          ),
                    icon: const Icon(Icons.phone),
                  ),
                ],
              ),
              const SectionTitle('Informacoes basicas'),
              _InfoGrid(player: player),
              const SectionTitle('Estatisticas'),
              _StatsGrid(stats: player.stats),
              const SectionTitle('Biografia'),
              Text(
                player.biografia.isEmpty
                    ? 'O jogador ainda nao escreveu uma apresentacao.'
                    : player.biografia,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              _VideosSection(playerId: player.id, repository: repository),
              _ReviewsSection(player: player, repository: repository),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: player.fotoUrl.isEmpty
                ? null
                : NetworkImage(player.fotoUrl),
            child: player.fotoUrl.isEmpty
                ? const Icon(Icons.person, size: 42, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nome.isEmpty ? 'Atleta sem nome' : player.nome,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${player.posicaoPrincipal} - ${player.idade} anos',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${player.mediaAvaliacoes.toStringAsFixed(1)} (${player.totalAvaliacoes})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final items = {
      'Cidade': '${player.cidade}/${player.estado}',
      'Altura': '${player.altura.toStringAsFixed(2)} m',
      'Peso': '${player.peso.toStringAsFixed(0)} kg',
      'Pe dominante': player.peDominante,
      'Secundaria': player.posicaoSecundaria,
      'Clube atual': player.clubeAtual,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.entries.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 42) / 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  item.value.isEmpty ? '-' : item.value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final items = {
      'Jogos': stats.jogos,
      'Gols': stats.gols,
      'Assist.': stats.assistencias,
      'Amarelos': stats.cartoesAmarelos,
      'Vermelhos': stats.cartoesVermelhos,
    };
    return Row(
      children: items.entries.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  '${item.value}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(item.key, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({required this.playerId, required this.repository});

  final String playerId;
  final PlayerRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Videos'),
        StreamBuilder(
          stream: repository.watchVideos(playerId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final videos = snapshot.data!;
            if (videos.isEmpty) {
              return const Text('Nenhum video enviado ainda.');
            }
            return SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: videos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VideoPlayerScreen(videoUrl: video.videoUrl),
                      ),
                    ),
                    child: Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.player, required this.repository});

  final Player player;
  final PlayerRepository repository;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final _comentarioController = TextEditingController();
  int _nota = 5;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canReview =
        currentUser != null && currentUser.uid != widget.player.userId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Avaliacoes'),
        if (canReview)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      onPressed: () => setState(() => _nota = value),
                      icon: Icon(
                        value <= _nota ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: _comentarioController,
                  decoration: const InputDecoration(labelText: 'Comentario'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final appUser = await AuthService().getCurrentAppUser();
                    await widget.repository.addReview(
                      playerId: widget.player.id,
                      avaliadorId: currentUser.uid,
                      avaliadorNome: appUser?.nome ?? 'Avaliador',
                      nota: _nota,
                      comentario: _comentarioController.text,
                    );
                    _comentarioController.clear();
                  },
                  child: const Text('Enviar avaliacao'),
                ),
              ],
            ),
          ),
        StreamBuilder(
          stream: widget.repository.watchReviews(widget.player.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final reviews = snapshot.data!;
            if (reviews.isEmpty) return const Text('Ainda nao ha avaliacoes.');
            return Column(
              children: reviews.map((review) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${review.nota}')),
                  title: Text(review.avaliadorNome),
                  subtitle: Text(review.comentario),
                  trailing: const Icon(Icons.star, color: Colors.amber),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
