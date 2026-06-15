import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/feed_post.dart';

class FeedRepository {
  FeedRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<FeedPost>> watchFeed({int limit = 50}) {
    return _firestore
        .collection('feedPosts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(FeedPost.fromDoc).toList());
  }

  Stream<bool> watchLikedByUser({
    required String postId,
    required String userId,
  }) {
    return _firestore
        .collection('feedPosts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<FeedComment>> watchComments(String postId) {
    return _firestore
        .collection('feedPosts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(FeedComment.fromDoc).toList());
  }

  Future<void> createPost({
    required AppUser author,
    required FeedPostType type,
    required String content,
    String imageUrl = '',
  }) async {
    final text = content.trim();
    final image = imageUrl.trim();
    if (text.isEmpty && image.isEmpty) return;

    final doc = _firestore.collection('feedPosts').doc();
    await doc.set({
      'id': doc.id,
      'authorId': author.id,
      'authorName': author.nome,
      'authorType': author.tipoUsuario.value,
      'authorCity': author.cidade,
      'authorState': author.estado,
      'type': type.value,
      'content': text,
      'imageUrl': image,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final postRef = _firestore.collection('feedPosts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final post = await transaction.get(postRef);
      if (!post.exists) return;

      final like = await transaction.get(likeRef);
      final currentCount = (post.data()?['likeCount'] as num?)?.toInt() ?? 0;

      if (isLiked) {
        if (!like.exists) return;
        transaction.delete(likeRef);
        transaction.update(postRef, {
          'likeCount': currentCount > 0 ? currentCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (like.exists) return;
      transaction.set(likeRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {
        'likeCount': currentCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addComment({
    required String postId,
    required AppUser author,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final postRef = _firestore.collection('feedPosts').doc(postId);
    final commentRef = postRef.collection('comments').doc();

    final batch = _firestore.batch()
      ..set(commentRef, {
        'id': commentRef.id,
        'authorId': author.id,
        'authorName': author.nome,
        'authorType': author.tipoUsuario.value,
        'text': trimmedText,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(postRef, {
        'commentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    await batch.commit();
  }
}
