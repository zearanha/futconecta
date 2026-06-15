import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../repositories/chat_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  final String receiverId;
  final String receiverName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = ChatRepository();
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  late final Future<AppUser?> _currentAppUser = AuthService()
      .getCurrentAppUser();
  bool _sending = false;
  bool _searching = false;

  Future<void> _send(AppUser? appUser) async {
    final text = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await _repository.sendMessage(
        senderId: user.uid,
        receiverId: widget.receiverId,
        senderName: appUser?.nome ?? user.email ?? 'Usuario',
        receiverName: widget.receiverName,
        text: text,
      );
    } catch (error) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel enviar: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setBlocked({
    required String currentUserId,
    required bool blocked,
  }) async {
    try {
      if (blocked) {
        await _repository.blockConversation(
          currentUserId: currentUserId,
          receiverId: widget.receiverId,
        );
      } else {
        await _repository.unblockConversation(
          currentUserId: currentUserId,
          receiverId: widget.receiverId,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel atualizar o bloqueio: $error'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Entre para conversar.')));
    }

    return FutureBuilder<AppUser?>(
      future: _currentAppUser,
      builder: (context, userSnapshot) {
        return StreamBuilder<ChatConversation?>(
          stream: _repository.watchConversation(
            currentUserId: user.uid,
            receiverId: widget.receiverId,
          ),
          builder: (context, conversationSnapshot) {
            final conversation = conversationSnapshot.data;
            final blockedByMe = conversation?.blockedByUser(user.uid) ?? false;
            final blockedByOther =
                conversation != null &&
                conversation.blockedBy.isNotEmpty &&
                !blockedByMe;

            return FutureBuilder<bool>(
              future: _repository.canStartConversation(
                currentUserId: user.uid,
                receiverId: widget.receiverId,
              ),
              builder: (context, permissionSnapshot) {
                final allowed = permissionSnapshot.data ?? false;
                final canSend = allowed && !blockedByMe && !blockedByOther;

                return Scaffold(
                  appBar: AppBar(
                    title: Text(widget.receiverName),
                    actions: [
                      IconButton(
                        tooltip: _searching
                            ? 'Fechar pesquisa'
                            : 'Pesquisar mensagens',
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _searchController.clear();
                        }),
                        icon: Icon(_searching ? Icons.close : Icons.search),
                      ),
                      if (conversation != null)
                        PopupMenuButton<_ChatAction>(
                          onSelected: (action) {
                            switch (action) {
                              case _ChatAction.block:
                                _setBlocked(
                                  currentUserId: user.uid,
                                  blocked: true,
                                );
                              case _ChatAction.unblock:
                                _setBlocked(
                                  currentUserId: user.uid,
                                  blocked: false,
                                );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: blockedByMe
                                  ? _ChatAction.unblock
                                  : _ChatAction.block,
                              child: Row(
                                children: [
                                  Icon(
                                    blockedByMe
                                        ? Icons.lock_open_outlined
                                        : Icons.block,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    blockedByMe
                                        ? 'Desbloquear contato'
                                        : 'Bloquear contato',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  body: Column(
                    children: [
                      if (_searching)
                        _MessageSearchBar(
                          controller: _searchController,
                          onChanged: () => setState(() {}),
                          onClear: () => setState(() {
                            _searchController.clear();
                          }),
                        ),
                      if (!canSend)
                        _ChatNotice(
                          message: _noticeFor(
                            allowed: allowed,
                            blockedByMe: blockedByMe,
                            blockedByOther: blockedByOther,
                          ),
                        ),
                      Expanded(
                        child: StreamBuilder<List<ChatMessage>>(
                          stream: _repository.watchMessages(
                            currentUserId: user.uid,
                            receiverId: widget.receiverId,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return _ChatError(error: snapshot.error);
                            }
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final messages =
                                snapshot.data ?? const <ChatMessage>[];
                            if (messages.isEmpty) {
                              return const _EmptyChat();
                            }
                            final query = _searchController.text
                                .trim()
                                .toLowerCase();
                            final visibleMessages = query.isEmpty
                                ? messages
                                : messages.where((message) {
                                    return message.text.toLowerCase().contains(
                                      query,
                                    );
                                  }).toList();

                            if (visibleMessages.isEmpty) {
                              return _NoMessageResults(query: query);
                            }

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: visibleMessages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    visibleMessages[visibleMessages.length -
                                        1 -
                                        index];
                                final mine = message.senderId == user.uid;
                                return _MessageBubble(
                                  message: message,
                                  mine: mine,
                                  highlight: query,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  enabled: canSend,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) {
                                    if (canSend) _send(userSnapshot.data);
                                  },
                                  decoration: InputDecoration(
                                    hintText: canSend
                                        ? 'Mensagem'
                                        : 'Envio indisponivel',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Enviar',
                                onPressed: _sending || !canSend
                                    ? null
                                    : () => _send(userSnapshot.data),
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _noticeFor({
    required bool allowed,
    required bool blockedByMe,
    required bool blockedByOther,
  }) {
    if (blockedByMe) {
      return 'Voce bloqueou este contato. Desbloqueie para enviar mensagens.';
    }
    if (blockedByOther) {
      return 'Este contato bloqueou a conversa.';
    }
    if (!allowed) {
      return 'Para iniciar conversa, adicione o jogador aos observados.';
    }
    return 'Envio indisponivel no momento.';
  }
}

enum _ChatAction { block, unblock }

class _MessageSearchBar extends StatelessWidget {
  const _MessageSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.card(color: AppColors.surface),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: 'Pesquisar mensagens antigas',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _NoMessageResults extends StatelessWidget {
  const _NoMessageResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 52, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma mensagem encontrada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Nao encontramos "$query" nesta conversa.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.highlight = '',
  });

  final ChatMessage message;
  final bool mine;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: _HighlightedMessageText(
          text: message.text,
          highlight: highlight,
          mine: mine,
        ),
      ),
    );
  }
}

class _HighlightedMessageText extends StatelessWidget {
  const _HighlightedMessageText({
    required this.text,
    required this.highlight,
    required this.mine,
  });

  final String text;
  final String highlight;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final baseColor = mine ? Colors.white : AppColors.text;
    final query = highlight.trim().toLowerCase();
    if (query.isEmpty) {
      return Text(text, style: TextStyle(color: baseColor));
    }

    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    var index = lowerText.indexOf(query);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      final end = index + query.length;
      spans.add(
        TextSpan(
          text: text.substring(index, end),
          style: TextStyle(
            color: mine ? AppColors.text : AppColors.primaryDark,
            backgroundColor: AppColors.gold.withValues(alpha: 0.75),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = end;
      index = lowerText.indexOf(query, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.3),
        children: spans,
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 54, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'Envie a primeira mensagem.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'A conversa ficara salva no Firebase assim que a mensagem for enviada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nao foi possivel carregar a conversa.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
