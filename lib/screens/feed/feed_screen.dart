import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/feed_post.dart';
import '../../repositories/feed_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _repository = FeedRepository();
  final _authService = AuthService();
  late final Future<AppUser?> _userFuture = _authService.getCurrentAppUser();

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('Entre para ver o feed.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              !userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: Text('Perfil de usuario indisponivel.'));
          }

          return StreamBuilder<List<FeedPost>>(
            stream: _repository.watchFeed(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _FeedError(error: snapshot.error);
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snapshot.data ?? const <FeedPost>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _Composer(
                    user: user,
                    onSubmit: (type, content) => _repository.createPost(
                      author: user,
                      type: type,
                      content: content,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (posts.isEmpty)
                    const _EmptyFeed()
                  else
                    ...posts.map(
                      (post) => _FeedPostCard(
                        post: post,
                        currentUser: user,
                        currentUserId: firebaseUser.uid,
                        repository: _repository,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.user, required this.onSubmit});

  final AppUser user;
  final Future<void> Function(FeedPostType type, String content) onSubmit;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  late FeedPostType _type = widget.user.tipoUsuario == UserType.jogador
      ? FeedPostType.update
      : FeedPostType.opportunity;
  bool _posting = false;

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      await widget.onSubmit(_type, content);
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel publicar: $error')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScout = widget.user.tipoUsuario == UserType.clubeTreinadorOlheiro;
    final types = isScout
        ? const [FeedPostType.opportunity, FeedPostType.highlight]
        : const [FeedPostType.update, FeedPostType.highlight];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: widget.user.nome, type: widget.user.tipoUsuario),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: isScout
                        ? 'Divulgue uma oportunidade ou observacao...'
                        : 'Compartilhe um treino, jogo ou conquista...',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: types.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(_iconFor(type), size: 16),
                          label: Text(type.label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _posting ? null : _submit,
                icon: _posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Publicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.currentUser,
    required this.currentUserId,
    required this.repository,
  });

  final FeedPost post;
  final AppUser currentUser;
  final String currentUserId;
  final FeedRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Avatar(name: post.authorName, type: post.authorType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName.isEmpty
                            ? 'Usuario FutConecta'
                            : post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _subtitleFor(post),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: post.type),
              ],
            ),
          ),
          _PostVisual(type: post.type),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: const TextStyle(
                    color: AppColors.text,
                    height: 1.35,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<bool>(
                  stream: repository.watchLikedByUser(
                    postId: post.id,
                    userId: currentUserId,
                  ),
                  builder: (context, snapshot) {
                    final liked = snapshot.data ?? false;
                    return Row(
                      children: [
                        IconButton(
                          tooltip: liked ? 'Remover curtida' : 'Curtir',
                          onPressed: () => repository.toggleLike(
                            postId: post.id,
                            userId: currentUserId,
                            isLiked: liked,
                          ),
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.redAccent : AppColors.text,
                          ),
                        ),
                        Text(
                          '${post.likeCount}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => _openComments(context),
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          label: Text('${post.commentCount}'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _CommentsSheet(
          post: post,
          currentUser: currentUser,
          repository: repository,
        );
      },
    );
  }

  String _subtitleFor(FeedPost post) {
    final location = post.location;
    final role = post.authorType.label;
    if (location.isEmpty) return role;
    return '$role - $location';
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.post,
    required this.currentUser,
    required this.repository,
  });

  final FeedPost post;
  final AppUser currentUser;
  final FeedRepository repository;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await widget.repository.addComment(
        postId: widget.post.id,
        author: widget.currentUser,
        text: text,
      );
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel comentar: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comentarios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<FeedComment>>(
                stream: widget.repository.watchComments(widget.post.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Nao foi possivel carregar comentarios.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data!;
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('Seja o primeiro a comentar.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Avatar(
                            name: comment.authorName,
                            type: comment.authorType,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.authorName.isEmpty
                                        ? 'Usuario'
                                        : comment.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment.text),
                                ],
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escreva um comentario',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Comentar',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.type});

  final String name;
  final UserType type;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 22,
      backgroundColor: type == UserType.jogador
          ? AppColors.primaryLight
          : const Color(0xFFEFF6FF),
      child: Text(
        initial,
        style: TextStyle(
          color: type == UserType.jogador
              ? AppColors.primary
              : const Color(0xFF1D4ED8),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final FeedPostType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _colorFor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(type), color: _colorFor(type), size: 14),
          const SizedBox(width: 5),
          Text(
            type.label,
            style: TextStyle(
              color: _colorFor(type),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostVisual extends StatelessWidget {
  const _PostVisual({required this.type});

  final FeedPostType type;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: CustomPaint(
        painter: _PostVisualPainter(color: _colorFor(type)),
        child: Center(
          child: Icon(_iconFor(type), color: Colors.white, size: 58),
        ),
      ),
    );
  }
}

class _PostVisualPainter extends CustomPainter {
  const _PostVisualPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, AppColors.primary],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.12,
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.18,
          size.width * 0.84,
          size.height * 0.64,
        ),
        const Radius.circular(14),
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PostVisualPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 56),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.dynamic_feed_outlined, size: 54, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'O feed ainda esta vazio.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Publique a primeira atualizacao da comunidade.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nao foi possivel carregar o feed.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}

IconData _iconFor(FeedPostType type) {
  switch (type) {
    case FeedPostType.update:
      return Icons.sports_soccer;
    case FeedPostType.opportunity:
      return Icons.campaign_outlined;
    case FeedPostType.highlight:
      return Icons.star_outline;
  }
}

Color _colorFor(FeedPostType type) {
  switch (type) {
    case FeedPostType.update:
      return AppColors.primary;
    case FeedPostType.opportunity:
      return const Color(0xFF2563EB);
    case FeedPostType.highlight:
      return const Color(0xFFB45309);
  }
}
