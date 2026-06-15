import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player.dart';
import '../models/player_video.dart';
import '../models/review.dart';

class PlayerFilters {
  const PlayerFilters({
    this.query = '',
    this.posicao,
    this.idadeMin,
    this.idadeMax,
    this.cidade,
    this.estado,
    this.alturaMin,
    this.peDominante,
  });

  final String query;
  final String? posicao;
  final int? idadeMin;
  final int? idadeMax;
  final String? cidade;
  final String? estado;
  final double? alturaMin;
  final String? peDominante;
}

class PlayerRepository {
  PlayerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Player>> watchPlayers({
    PlayerFilters filters = const PlayerFilters(),
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('players');

    if ((filters.posicao ?? '').isNotEmpty) {
      query = query.where('posicaoPrincipal', isEqualTo: filters.posicao);
    }
    if (filters.idadeMin != null) {
      query = query.where('idade', isGreaterThanOrEqualTo: filters.idadeMin);
    }
    if (filters.idadeMax != null) {
      query = query.where('idade', isLessThanOrEqualTo: filters.idadeMax);
    }
    if ((filters.cidade ?? '').isNotEmpty) {
      query = query.where('cidade', isEqualTo: filters.cidade);
    }
    if ((filters.estado ?? '').isNotEmpty) {
      query = query.where('estado', isEqualTo: filters.estado);
    }
    if (filters.alturaMin != null) {
      query = query.where('altura', isGreaterThanOrEqualTo: filters.alturaMin);
    }
    if ((filters.peDominante ?? '').isNotEmpty) {
      query = query.where('peDominante', isEqualTo: filters.peDominante);
    }

    return query.snapshots().map((snapshot) {
      final players = snapshot.docs.map(Player.fromDoc).where((player) {
        final term = filters.query.trim().toLowerCase();
        if (term.isEmpty) return true;
        return player.nome.toLowerCase().contains(term) ||
            player.cidade.toLowerCase().contains(term) ||
            player.estado.toLowerCase().contains(term) ||
            player.posicaoPrincipal.toLowerCase().contains(term) ||
            player.clubeAtual.toLowerCase().contains(term);
      }).toList();
      players.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
      return players;
    });
  }

  Stream<Player?> watchPlayer(String playerId) {
    return _firestore.collection('players').doc(playerId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return Player.fromDoc(doc);
    });
  }

  Future<Player?> getPlayer(String playerId) async {
    final doc = await _firestore.collection('players').doc(playerId).get();
    if (!doc.exists) return null;
    return Player.fromDoc(doc);
  }

  Future<void> savePlayer(Player player) async {
    await _firestore
        .collection('players')
        .doc(player.id)
        .set(player.toMap(), SetOptions(merge: true));
  }

  Stream<List<PlayerVideo>> watchVideos(String playerId) {
    return _firestore
        .collection('videos')
        .where('playerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PlayerVideo.fromDoc).toList());
  }

  Future<void> addVideo({
    required String playerId,
    required String videoUrl,
    required String titulo,
  }) async {
    await _firestore.collection('videos').add({
      'playerId': playerId,
      'videoUrl': videoUrl,
      'titulo': titulo,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteVideo({
    required String playerId,
    required String videoId,
  }) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final video = await videoRef.get();
    if (!video.exists) return;
    if (video.data()?['playerId'] != playerId) {
      throw StateError('Este video nao pertence ao jogador informado.');
    }
    await videoRef.delete();
  }

  Stream<List<PlayerReview>> watchReviews(String playerId) {
    return _firestore
        .collection('reviews')
        .where('playerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PlayerReview.fromDoc).toList());
  }

  Future<void> addReview({
    required String playerId,
    required String avaliadorId,
    required String avaliadorNome,
    required int nota,
    required String comentario,
  }) async {
    await _firestore.collection('reviews').add({
      'playerId': playerId,
      'avaliadorId': avaliadorId,
      'avaliadorNome': avaliadorNome,
      'nota': nota,
      'comentario': comentario,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final reviews = await _firestore
        .collection('reviews')
        .where('playerId', isEqualTo: playerId)
        .get();
    final total = reviews.docs.length;
    final sum = reviews.docs.fold<int>(
      0,
      (value, doc) => value + ((doc.data()['nota'] as num?)?.toInt() ?? 0),
    );

    await _firestore.collection('players').doc(playerId).set({
      'mediaAvaliacoes': total == 0 ? 0 : sum / total,
      'totalAvaliacoes': total,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Player>> watchRanking() {
    return watchPlayers().map((players) => players.take(10).toList());
  }

  Stream<Player?> watchFeaturedPlayer() {
    return watchPlayers().map((players) {
      if (players.isEmpty) return null;
      return players.first;
    });
  }
}
