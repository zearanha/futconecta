import 'package:cloud_firestore/cloud_firestore.dart';

enum FavoriteStatus { interessado, emAnalise, contatoFeito, aprovado }

extension FavoriteStatusX on FavoriteStatus {
  String get label {
    switch (this) {
      case FavoriteStatus.interessado:
        return 'Interessado';
      case FavoriteStatus.emAnalise:
        return 'Em analise';
      case FavoriteStatus.contatoFeito:
        return 'Contato feito';
      case FavoriteStatus.aprovado:
        return 'Aprovado';
    }
  }

  String get value {
    switch (this) {
      case FavoriteStatus.interessado:
        return 'interessado';
      case FavoriteStatus.emAnalise:
        return 'em_analise';
      case FavoriteStatus.contatoFeito:
        return 'contato_feito';
      case FavoriteStatus.aprovado:
        return 'aprovado';
    }
  }

  static FavoriteStatus fromValue(String? value) {
    switch (value) {
      case 'em_analise':
        return FavoriteStatus.emAnalise;
      case 'contato_feito':
        return FavoriteStatus.contatoFeito;
      case 'aprovado':
        return FavoriteStatus.aprovado;
      default:
        return FavoriteStatus.interessado;
    }
  }
}

class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.clubId,
    required this.playerId,
    required this.status,
  });

  final String id;
  final String clubId;
  final String playerId;
  final FavoriteStatus status;

  factory FavoriteEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FavoriteEntry(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      playerId: data['playerId'] ?? '',
      status: FavoriteStatusX.fromValue(data['status']),
    );
  }
}

class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _favoriteId(String clubId, String playerId) => '${clubId}_$playerId';

  Stream<List<FavoriteEntry>> watchFavorites(String clubId) {
    return _firestore
        .collection('favorites')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs.map(FavoriteEntry.fromDoc).toList();
          entries.sort((a, b) => a.status.index.compareTo(b.status.index));
          return entries;
        });
  }

  Stream<Set<String>> watchFavoritePlayerIds(String clubId) {
    return watchFavorites(
      clubId,
    ).map((entries) => entries.map((entry) => entry.playerId).toSet());
  }

  Stream<bool> watchIsFavorite({
    required String clubId,
    required String playerId,
  }) {
    return _firestore
        .collection('favorites')
        .doc(_favoriteId(clubId, playerId))
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<bool> isFavorite({
    required String clubId,
    required String playerId,
  }) async {
    final doc = await _firestore
        .collection('favorites')
        .doc(_favoriteId(clubId, playerId))
        .get();
    return doc.exists;
  }

  Future<void> toggleFavorite({
    required String clubId,
    required String playerId,
    required bool isFavorite,
  }) async {
    final doc = _firestore
        .collection('favorites')
        .doc(_favoriteId(clubId, playerId));
    if (isFavorite) {
      await doc.delete();
      return;
    }
    await doc.set({
      'id': doc.id,
      'clubId': clubId,
      'playerId': playerId,
      'status': FavoriteStatus.interessado.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus({
    required String clubId,
    required String playerId,
    required FavoriteStatus status,
  }) async {
    final id = _favoriteId(clubId, playerId);
    await _firestore.collection('favorites').doc(id).set({
      'id': id,
      'clubId': clubId,
      'playerId': playerId,
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<FavoriteStatus, int>> watchStatusCount(String clubId) {
    return watchFavorites(clubId).map((entries) {
      final count = {for (final status in FavoriteStatus.values) status: 0};
      for (final entry in entries) {
        count[entry.status] = (count[entry.status] ?? 0) + 1;
      }
      return count;
    });
  }
}
