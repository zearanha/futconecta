import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

enum FeedPostType { update, opportunity, highlight }

extension FeedPostTypeX on FeedPostType {
  String get label {
    switch (this) {
      case FeedPostType.update:
        return 'Atualizacao';
      case FeedPostType.opportunity:
        return 'Oportunidade';
      case FeedPostType.highlight:
        return 'Destaque';
    }
  }

  String get value {
    switch (this) {
      case FeedPostType.update:
        return 'update';
      case FeedPostType.opportunity:
        return 'opportunity';
      case FeedPostType.highlight:
        return 'highlight';
    }
  }

  static FeedPostType fromValue(String? value) {
    switch (value) {
      case 'opportunity':
        return FeedPostType.opportunity;
      case 'highlight':
        return FeedPostType.highlight;
      default:
        return FeedPostType.update;
    }
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorType,
    required this.authorCity,
    required this.authorState,
    required this.type,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final UserType authorType;
  final String authorCity;
  final String authorState;
  final FeedPostType type;
  final String content;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;

  factory FeedPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FeedPost(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorType: UserTypeX.fromValue(data['authorType']),
      authorCity: data['authorCity'] ?? '',
      authorState: data['authorState'] ?? '',
      type: FeedPostTypeX.fromValue(data['type']),
      content: data['content'] ?? '',
      likeCount: _toInt(data['likeCount']),
      commentCount: _toInt(data['commentCount']),
      createdAt: _toDate(data['createdAt']),
    );
  }

  String get location {
    if (authorCity.isEmpty && authorState.isEmpty) return '';
    if (authorState.isEmpty) return authorCity;
    if (authorCity.isEmpty) return authorState;
    return '$authorCity/$authorState';
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorType,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final UserType authorType;
  final String text;
  final DateTime? createdAt;

  factory FeedComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FeedComment(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorType: UserTypeX.fromValue(data['authorType']),
      text: data['text'] ?? '',
      createdAt: _toDate(data['createdAt']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
