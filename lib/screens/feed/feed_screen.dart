import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../models/feed_post.dart';
import '../../repositories/feed_repository.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class _FeedPalette {
  static const bgTop = Color(0xFF101820);
  static const bgBottom = Color(0xFF121F1B);
  static const panel = Color(0xFF17251F);
  static const panelSoft = Color(0xFF1B2D26);
  static const field = Color(0xFF0F1A17);
  static const border = Color(0xFF2C443A);
  static const accent = Color(0xFF24C96F);
  static const muted = Color(0xFFA9B8AE);
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _repository = FeedRepository();
  final _authService = AuthService();
  late final Future<AppUser?> _userFuture = _authService.getCurrentAppUser();
  FeedPostType? _selectedType;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('Entre para ver o feed.')),
      );
    }

    return Scaffold(
      backgroundColor: _FeedPalette.bgTop,
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: _FeedPalette.bgTop,
        foregroundColor: Colors.white,
      ),
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
              var visiblePosts = _selectedType == null
                  ? posts
                  : posts.where((post) => post.type == _selectedType).toList();
              if (_onlyMine) {
                visiblePosts = visiblePosts
                    .where((post) => post.authorId == firebaseUser.uid)
                    .toList();
              }

              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_FeedPalette.bgTop, _FeedPalette.bgBottom],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _FeedHero(user: user, postsCount: posts.length),
                    const SizedBox(height: 14),
                    _FeedTypeFilter(
                      selectedType: _selectedType,
                      onlyMine: _onlyMine,
                      onChanged: (type) => setState(() {
                        _selectedType = type;
                      }),
                      onMineChanged: (value) => setState(() {
                        _onlyMine = value;
                      }),
                    ),
                    const SizedBox(height: 14),
                    _Composer(
                      user: user,
                      onSubmit: (type, content, imageUrl) =>
                          _repository.createPost(
                            author: user,
                            type: type,
                            content: content,
                            imageUrl: imageUrl,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (visiblePosts.isEmpty)
                      _EmptyFeed(filtered: posts.isNotEmpty)
                    else
                      ...visiblePosts.map(
                        (post) => _FeedPostCard(
                          post: post,
                          currentUser: user,
                          currentUserId: firebaseUser.uid,
                          repository: _repository,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedHero extends StatelessWidget {
  const _FeedHero({required this.user, required this.postsCount});

  final AppUser user;
  final int postsCount;

  @override
  Widget build(BuildContext context) {
    final isScout = user.tipoUsuario == UserType.clubeTreinadorOlheiro;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _FeedPalette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _FeedPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
              ),
              _FeedSignal(icon: Icons.notifications_none, value: '$postsCount'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isScout
                ? 'Oportunidades, destaques e movimentacoes da comunidade.'
                : 'Mostre evolucao, treinos e conquistas para quem observa.',
            style: const TextStyle(
              color: Color(0xFF9DB9A8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedSignal extends StatelessWidget {
  const _FeedSignal({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _FeedPalette.accent, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTypeFilter extends StatelessWidget {
  const _FeedTypeFilter({
    required this.selectedType,
    required this.onlyMine,
    required this.onChanged,
    required this.onMineChanged,
  });

  final FeedPostType? selectedType;
  final bool onlyMine;
  final ValueChanged<FeedPostType?> onChanged;
  final ValueChanged<bool> onMineChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, FeedPostType? type})>[
      (label: 'TODOS', type: null),
      (label: 'TREINOS', type: FeedPostType.update),
      (label: 'VAGAS', type: FeedPostType.opportunity),
      (label: 'HIGHLIGHTS', type: FeedPostType.highlight),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(2),
              onTap: () => onMineChanged(!onlyMine),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: onlyMine
                      ? _FeedPalette.accent
                      : _FeedPalette.panelSoft,
                  border: Border.all(
                    color: onlyMine ? _FeedPalette.accent : _FeedPalette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_pin_circle_outlined,
                      size: 15,
                      color: onlyMine ? _FeedPalette.bgTop : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MEUS',
                      style: TextStyle(
                        color: onlyMine ? _FeedPalette.bgTop : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...filters.map((filter) {
            final selected = selectedType == filter.type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(2),
                onTap: () => onChanged(filter.type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? _FeedPalette.accent
                        : _FeedPalette.panelSoft,
                    border: Border.all(
                      color: selected
                          ? _FeedPalette.accent
                          : _FeedPalette.border,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      color: selected ? _FeedPalette.bgTop : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.user, required this.onSubmit});

  final AppUser user;
  final Future<void> Function(
    FeedPostType type,
    String content,
    String imageUrl,
  )
  onSubmit;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _storageService = StorageService();
  late FeedPostType _type = widget.user.tipoUsuario == UserType.jogador
      ? FeedPostType.update
      : FeedPostType.opportunity;
  XFile? _image;
  Uint8List? _imagePreviewBytes;
  bool _posting = false;

  Future<void> _pickImage() async {
    if (_posting) return;

    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (selected == null) return;

    final bytes = await selected.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = selected;
      _imagePreviewBytes = bytes;
    });
  }

  void _removeImage() {
    if (_posting) return;
    setState(() {
      _image = null;
      _imagePreviewBytes = null;
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if ((content.isEmpty && _image == null) || _posting) return;

    setState(() => _posting = true);
    try {
      final imageUrl = _image == null
          ? ''
          : await _storageService.uploadFeedImage(widget.user.id, _image!);
      await widget
          .onSubmit(_type, content, imageUrl)
          .timeout(const Duration(seconds: 20));
      _controller.clear();
      _image = null;
      _imagePreviewBytes = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_publicationErrorMessage(error))));
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
        color: _FeedPalette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _FeedPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PUBLICAR NO FEED',
            style: TextStyle(
              color: _FeedPalette.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _FeedPalette.field,
                    hintStyle: const TextStyle(color: _FeedPalette.muted),
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
                          selectedColor: _FeedPalette.accent,
                          backgroundColor: _FeedPalette.panelSoft,
                          labelStyle: TextStyle(
                            color: _type == type
                                ? _FeedPalette.bgTop
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Adicionar foto',
                onPressed: _posting ? null : _pickImage,
                style: IconButton.styleFrom(
                  foregroundColor: _FeedPalette.accent,
                  side: const BorderSide(color: _FeedPalette.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _posting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _FeedPalette.accent,
                  foregroundColor: _FeedPalette.bgTop,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
          if (_imagePreviewBytes != null) ...[
            const SizedBox(height: 12),
            _ComposerImagePreview(
              bytes: _imagePreviewBytes!,
              onRemove: _removeImage,
            ),
          ],
        ],
      ),
    );
  }

  String _publicationErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return 'Sem permissao para enviar a imagem. Publique as regras do Storage/Firebase.';
      }
      if (error.code == 'canceled') {
        return 'Upload cancelado antes de concluir.';
      }
      return 'Erro do Firebase (${error.code}): ${error.message ?? error}';
    }
    if (error is TimeoutException) {
      return error.message ?? 'Tempo esgotado ao publicar.';
    }
    return 'Nao foi possivel publicar: $error';
  }
}

class _ComposerImagePreview extends StatelessWidget {
  const _ComposerImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: 'Remover foto',
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.64),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _FeedPalette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _FeedPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        _subtitleFor(post),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedPalette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: post.type),
              ],
            ),
          ),
          _PostMedia(post: post),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.content.trim().isNotEmpty) ...[
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: Color(0xFFE6F4EE),
                      height: 1.35,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                            color: liked
                                ? Colors.redAccent
                                : _FeedPalette.muted,
                          ),
                        ),
                        Text(
                          '${post.likeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => _openComments(context),
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          label: Text('${post.commentCount}'),
                          style: TextButton.styleFrom(
                            foregroundColor: _FeedPalette.muted,
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
          ? _FeedPalette.accent
          : const Color(0xFF1F6FEB),
      child: Text(
        initial,
        style: const TextStyle(
          color: _FeedPalette.bgTop,
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
        color: _colorFor(type),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(type), color: _FeedPalette.bgTop, size: 14),
          const SizedBox(width: 5),
          Text(
            type.label,
            style: const TextStyle(
              color: _FeedPalette.bgTop,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    if (post.imageUrl.isEmpty) {
      return _PostVisual(type: post.type);
    }

    return AspectRatio(
      aspectRatio: 1.2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _PostVisual(type: post.type);
            },
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black.withValues(alpha: 0.64),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconFor(post.type),
                    color: _FeedPalette.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.type == FeedPostType.highlight
                        ? 'HIGHLIGHT'
                        : post.type.label.toUpperCase(),
                    style: const TextStyle(
                      color: _FeedPalette.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
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
        child: Stack(
          children: [
            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                color: Colors.black.withValues(alpha: 0.56),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(type), color: _FeedPalette.accent, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'HIGHLIGHT 0:42',
                      style: TextStyle(
                        color: _FeedPalette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Icon(
                _iconFor(type),
                color: Colors.white.withValues(alpha: 0.92),
                size: 58,
              ),
            ),
          ],
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
        colors: [_FeedPalette.panelSoft, _FeedPalette.field, color],
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
  const _EmptyFeed({this.filtered = false});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.dynamic_feed_outlined,
              size: 54,
              color: _FeedPalette.accent,
            ),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'Nenhum post nesse filtro.'
                  : 'O feed ainda esta vazio.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Escolha outra categoria para ver mais movimentacoes.'
                  : 'Publique a primeira atualizacao da comunidade.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _FeedPalette.muted),
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
