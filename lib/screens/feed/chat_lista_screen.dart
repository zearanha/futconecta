import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/chat_repository.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';

class ChatListaScreen extends StatelessWidget {
  const ChatListaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final repository = ChatRepository();
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Entre para ver mensagens.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: StreamBuilder<List<ChatConversation>>(
        stream: repository.watchConversations(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ChatError(error: snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data ?? const <ChatConversation>[];
          if (conversations.isEmpty) {
            return const _EmptyConversations();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherId = conversation.otherUserId(user.uid);
              final otherName = conversation.otherUserName(user.uid);
              return _ConversationTile(
                conversation: conversation,
                currentUserId: user.uid,
                otherName: otherName,
                onTap: otherId.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: otherId,
                            receiverName: otherName,
                          ),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.otherName,
    required this.onTap,
  });

  final ChatConversation conversation;
  final String currentUserId;
  final String otherName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mine = conversation.lastSenderId == currentUserId;
    final blocked = conversation.blockedBy.isNotEmpty;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      blocked
                          ? 'Conversa bloqueada'
                          : '${mine ? 'Voce: ' : ''}${conversation.lastMessage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: blocked ? Colors.redAccent : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                blocked ? Icons.block : Icons.chevron_right,
                color: blocked ? Colors.redAccent : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 54, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'Nenhuma conversa ainda.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              'Abra o perfil de um jogador e toque em Chat interno para iniciar.',
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
          'Nao foi possivel carregar as mensagens.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
