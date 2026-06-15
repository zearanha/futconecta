import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.lastMessage,
    required this.lastSenderId,
    required this.blockedBy,
    required this.updatedAt,
  });

  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String lastMessage;
  final String lastSenderId;
  final List<String> blockedBy;
  final DateTime? updatedAt;

  factory ChatConversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
    return ChatConversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: names.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      lastMessage: data['lastMessage'] ?? '',
      lastSenderId: data['lastSenderId'] ?? '',
      blockedBy: List<String>.from(data['blockedBy'] ?? []),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  bool isBlockedFor(String userId) {
    return blockedBy.isNotEmpty;
  }

  bool blockedByUser(String userId) {
    return blockedBy.contains(userId);
  }

  String otherUserId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String otherUserName(String currentUserId) {
    final otherId = otherUserId(currentUserId);
    final name = participantNames[otherId] ?? '';
    return name.isEmpty ? 'Contato' : name;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime? sentAt;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? data['texto'] ?? '',
      sentAt: _toDate(data['sentAt'] ?? data['data']),
    );
  }
}

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<ChatMessage>> watchMessages({
    required String currentUserId,
    required String receiverId,
  }) {
    final chatId = conversationId(currentUserId, receiverId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Stream<ChatConversation?> watchConversation({
    required String currentUserId,
    required String receiverId,
  }) {
    final chatId = conversationId(currentUserId, receiverId);
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatConversation.fromDoc(doc);
    });
  }

  Future<ChatConversation?> getConversation({
    required String currentUserId,
    required String receiverId,
  }) async {
    final chatId = conversationId(currentUserId, receiverId);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) return null;
    return ChatConversation.fromDoc(doc);
  }

  Future<bool> canStartConversation({
    required String currentUserId,
    required String receiverId,
  }) async {
    final existing = await getConversation(
      currentUserId: currentUserId,
      receiverId: receiverId,
    );
    if (existing != null) return !existing.isBlockedFor(currentUserId);

    final favoriteId = '${currentUserId}_$receiverId';
    final favoriteDoc = await _firestore
        .collection('favorites')
        .doc(favoriteId)
        .get();
    return favoriteDoc.exists;
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String receiverName,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final chatId = conversationId(senderId, receiverId);
    final participantIds = [senderId, receiverId]..sort();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      if (chatSnapshot.exists) {
        final conversation = ChatConversation.fromDoc(chatSnapshot);
        if (conversation.blockedBy.isNotEmpty) {
          throw StateError('Conversa bloqueada.');
        }
      } else {
        final favoriteDoc = await transaction.get(
          _firestore.collection('favorites').doc('${senderId}_$receiverId'),
        );
        if (!favoriteDoc.exists) {
          throw StateError(
            'Adicione o jogador aos observados antes de enviar mensagem.',
          );
        }
      }

      final chatData = <String, dynamic>{
        'id': chatId,
        'participantIds': participantIds,
        'participantNames': {
          senderId: senderName.trim().isEmpty ? 'Usuario' : senderName.trim(),
          receiverId: receiverName.trim().isEmpty
              ? 'Contato'
              : receiverName.trim(),
        },
        'lastMessage': trimmedText,
        'lastSenderId': senderId,
        'updatedAt': now,
      };
      if (!chatSnapshot.exists ||
          !(chatSnapshot.data()?.containsKey('blockedBy') ?? false)) {
        chatData['blockedBy'] = const <String>[];
      }
      transaction.set(chatRef, chatData, SetOptions(merge: true));

      transaction.set(messageRef, {
        'id': messageRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': trimmedText,
        'sentAt': now,
      });
    });
  }

  Future<void> blockConversation({
    required String currentUserId,
    required String receiverId,
  }) async {
    final chatId = conversationId(currentUserId, receiverId);
    await _firestore.collection('chats').doc(chatId).set({
      'blockedBy': FieldValue.arrayUnion([currentUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockConversation({
    required String currentUserId,
    required String receiverId,
  }) async {
    final chatId = conversationId(currentUserId, receiverId);
    await _firestore.collection('chats').doc(chatId).set({
      'blockedBy': FieldValue.arrayRemove([currentUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ChatConversation>> watchConversations(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(ChatConversation.fromDoc)
              .toList();
          conversations.sort((a, b) {
            final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return conversations;
        });
  }
}

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
