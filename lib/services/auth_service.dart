import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return _getOrRepairAppUser(credential.user!);
  }

  Future<AppUser> createAccount({
    required String nome,
    required String email,
    required String senha,
    required String cidade,
    required String estado,
    required UserType tipoUsuario,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha.trim(),
    );
    final uid = credential.user!.uid;
    final user = AppUser(
      id: uid,
      tipoUsuario: tipoUsuario,
      nome: nome.trim(),
      email: email.trim(),
      cidade: cidade.trim(),
      estado: estado.trim().toUpperCase(),
    );

    await _firestore.collection('users').doc(uid).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (tipoUsuario == UserType.jogador) {
      await _firestore.collection('players').doc(uid).set({
        'id': uid,
        'userId': uid,
        'nome': user.nome,
        'cidade': user.cidade,
        'estado': user.estado,
        'mediaAvaliacoes': 0,
        'totalAvaliacoes': 0,
        'estatisticas': {
          'jogosDisputados': 0,
          'gols': 0,
          'assistencias': 0,
          'cartoesAmarelos': 0,
          'cartoesVermelhos': 0,
        },
        'search': '${user.nome} ${user.cidade} ${user.estado}'.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return user;
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getOrRepairAppUser(user);
  }

  Future<AppUser> _getOrRepairAppUser(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) return AppUser.fromDoc(doc);

    final playerDoc = await _firestore
        .collection('players')
        .doc(user.uid)
        .get();
    final playerData = playerDoc.data();
    final repairedUser = AppUser(
      id: user.uid,
      tipoUsuario: playerDoc.exists
          ? UserType.jogador
          : UserType.clubeTreinadorOlheiro,
      nome:
          playerData?['nome'] ??
          user.displayName ??
          user.email?.split('@').first ??
          'Usuario',
      email: user.email ?? '',
      cidade: playerData?['cidade'] ?? '',
      estado: playerData?['estado'] ?? '',
    );

    await _firestore.collection('users').doc(user.uid).set({
      ...repairedUser.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'repairedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return repairedUser;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
