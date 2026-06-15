import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracoes')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Firebase integrado'),
            subtitle: Text('Auth, Firestore e Storage configurados no app.'),
          ),
          const ListTile(
            leading: Icon(Icons.dataset_outlined),
            title: Text('Colecoes'),
            subtitle: Text(
              'users, players, feedPosts, videos, favorites, reviews e chats.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sair'),
            onTap: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
