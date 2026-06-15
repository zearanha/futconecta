import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../../repositories/favorites_repository.dart';
import '../../repositories/player_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/player_card.dart';
import '../chat/chat_screen.dart';
import '../perfil/perfil_jogador_screen.dart';

class BuscaJogadoresScreen extends StatefulWidget {
  const BuscaJogadoresScreen({super.key});

  @override
  State<BuscaJogadoresScreen> createState() => _BuscaJogadoresScreenState();
}

class _BuscaJogadoresScreenState extends State<BuscaJogadoresScreen> {
  final _repository = PlayerRepository();
  final _favoritesRepository = FavoritesRepository();
  final _queryController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _idadeMinController = TextEditingController();
  final _idadeMaxController = TextEditingController();
  final _alturaController = TextEditingController();
  String? _posicao;
  String? _peDominante;

  static const _posicoes = [
    'Goleiro',
    'Zagueiro',
    'Lateral',
    'Volante',
    'Meio-Campo',
    'Atacante',
  ];
  static const _pes = ['Direito', 'Esquerdo', 'Ambos'];

  PlayerFilters get _filters => PlayerFilters(
    query: _queryController.text,
    posicao: _posicao,
    idadeMin: int.tryParse(_idadeMinController.text),
    idadeMax: int.tryParse(_idadeMaxController.text),
    cidade: _cidadeController.text.trim().isEmpty
        ? null
        : _cidadeController.text.trim(),
    estado: _estadoController.text.trim().isEmpty
        ? null
        : _estadoController.text.trim().toUpperCase(),
    alturaMin: double.tryParse(_alturaController.text.replaceAll(',', '.')),
    peDominante: _peDominante,
  );

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _cidadeController.clear();
      _estadoController.clear();
      _idadeMinController.clear();
      _idadeMaxController.clear();
      _alturaController.clear();
      _posicao = null;
      _peDominante = null;
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _idadeMinController.dispose();
    _idadeMaxController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca avancada'),
        actions: [
          IconButton(
            tooltip: 'Limpar filtros',
            icon: const Icon(Icons.refresh),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SearchPanel(
            queryController: _queryController,
            cidadeController: _cidadeController,
            estadoController: _estadoController,
            idadeMinController: _idadeMinController,
            idadeMaxController: _idadeMaxController,
            alturaController: _alturaController,
            posicao: _posicao,
            peDominante: _peDominante,
            posicoes: _posicoes,
            pes: _pes,
            onChanged: () => setState(() {}),
            onPosicaoChanged: (value) => setState(() => _posicao = value),
            onPeChanged: (value) => setState(() => _peDominante = value),
          ),
          const SizedBox(height: 18),
          StreamBuilder<List<Player>>(
            stream: _repository.watchPlayers(filters: _filters),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final players = snapshot.data!;
              return StreamBuilder<Set<String>>(
                stream: currentUserId == null
                    ? Stream.value(<String>{})
                    : _favoritesRepository.watchFavoritePlayerIds(
                        currentUserId,
                      ),
                builder: (context, favoritesSnapshot) {
                  final favorites = favoritesSnapshot.data ?? <String>{};
                  if (players.isEmpty) {
                    return const _NoResults();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResultsHeader(count: players.length),
                      const SizedBox(height: 10),
                      ...players.map((player) {
                        final isFavorite = favorites.contains(player.id);
                        return PlayerCard(
                          player: player,
                          isFavorite: isFavorite,
                          onMessage: currentUserId == null
                              ? null
                              : () => _openChatOrExplain(
                                  context: context,
                                  player: player,
                                  isFavorite: isFavorite,
                                ),
                          onFavorite: currentUserId == null
                              ? null
                              : () => _favoritesRepository.toggleFavorite(
                                  clubId: currentUserId,
                                  playerId: player.id,
                                  isFavorite: isFavorite,
                                ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PerfilJogadorScreen(playerId: player.id),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openChatOrExplain({
    required BuildContext context,
    required Player player,
    required bool isFavorite,
  }) {
    if (!isFavorite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione o jogador aos observados antes de conversar.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: player.userId,
          receiverName: player.nome.isEmpty ? 'Jogador' : player.nome,
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.queryController,
    required this.cidadeController,
    required this.estadoController,
    required this.idadeMinController,
    required this.idadeMaxController,
    required this.alturaController,
    required this.posicao,
    required this.peDominante,
    required this.posicoes,
    required this.pes,
    required this.onChanged,
    required this.onPosicaoChanged,
    required this.onPeChanged,
  });

  final TextEditingController queryController;
  final TextEditingController cidadeController;
  final TextEditingController estadoController;
  final TextEditingController idadeMinController;
  final TextEditingController idadeMaxController;
  final TextEditingController alturaController;
  final String? posicao;
  final String? peDominante;
  final List<String> posicoes;
  final List<String> pes;
  final VoidCallback onChanged;
  final ValueChanged<String?> onPosicaoChanged;
  final ValueChanged<String?> onPeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.scoutLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.manage_search, color: AppColors.scout),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Critérios de prospecção',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Combine posição, localização e perfil físico para reduzir a lista.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: queryController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: 'Nome, cidade, clube ou posicao',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DropFilter(
                label: 'Posicao',
                value: posicao,
                values: posicoes,
                onChanged: onPosicaoChanged,
              ),
              _DropFilter(
                label: 'Pe dominante',
                value: peDominante,
                values: pes,
                onChanged: onPeChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallField(idadeMinController, 'Idade min', onChanged),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallField(idadeMaxController, 'Idade max', onChanged),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallField(alturaController, 'Altura min', onChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallField(cidadeController, 'Cidade', onChanged),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: _SmallField(estadoController, 'UF', onChanged),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField(this.controller, this.label, this.onChanged);

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Resultados',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$count atletas',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'Nenhum jogador encontrado com esses filtros.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('Todos')),
          ...values.map(
            (item) => DropdownMenuItem(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
