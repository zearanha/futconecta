import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/player.dart';
import '../../repositories/player_repository.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/section_title.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key, this.playerId});

  final String? playerId;

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _repository = PlayerRepository();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _nome = TextEditingController();
  final _idade = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController();
  final _telefone = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  final _clubeAtual = TextEditingController();
  final _bio = TextEditingController();
  final _jogos = TextEditingController();
  final _gols = TextEditingController();
  final _assistencias = TextEditingController();
  final _amarelos = TextEditingController();
  final _vermelhos = TextEditingController();

  String? _posicaoPrincipal;
  String? _posicaoSecundaria;
  String? _peDominante;
  String _fotoUrl = '';
  XFile? _foto;
  Uint8List? _fotoPreviewBytes;
  bool _loaded = false;
  bool _saving = false;
  bool _uploadingVideo = false;

  static const _posicoes = [
    'Goleiro',
    'Zagueiro',
    'Lateral',
    'Volante',
    'Meio-Campo',
    'Atacante',
  ];
  static const _pes = ['Direito', 'Esquerdo', 'Ambos'];

  String? get _playerId =>
      widget.playerId ?? FirebaseAuth.instance.currentUser?.uid;

  Future<void> _load() async {
    if (_loaded) return;

    final playerId = _playerId;
    if (playerId == null) {
      _loaded = true;
      return;
    }

    final player = await _repository.getPlayer(playerId);
    if (player == null) {
      _loaded = true;
      return;
    }

    _nome.text = player.nome;
    _idade.text = player.idade == 0 ? '' : '${player.idade}';
    _cidade.text = player.cidade;
    _estado.text = player.estado;
    _telefone.text = player.telefone;
    _altura.text = player.altura == 0 ? '' : '${player.altura}';
    _peso.text = player.peso == 0 ? '' : '${player.peso}';
    _clubeAtual.text = player.clubeAtual;
    _bio.text = player.biografia;
    _jogos.text = '${player.stats.jogos}';
    _gols.text = '${player.stats.gols}';
    _assistencias.text = '${player.stats.assistencias}';
    _amarelos.text = '${player.stats.cartoesAmarelos}';
    _vermelhos.text = '${player.stats.cartoesVermelhos}';
    _posicaoPrincipal = _validOption(_posicoes, player.posicaoPrincipal);
    _posicaoSecundaria = _validOption(_posicoes, player.posicaoSecundaria);
    _peDominante = _validOption(_pes, player.peDominante);
    _fotoUrl = player.fotoUrl;
    _loaded = true;
  }

  String? _validOption(List<String> options, String value) {
    return options.contains(value) ? value : null;
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) {
        _showMessage('Nenhuma imagem selecionada.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = image;
        _fotoPreviewBytes = bytes;
      });
      _showMessage('Foto selecionada. Toque em Salvar perfil para enviar.');
    } catch (error) {
      _showMessage('Nao foi possivel selecionar a foto: $error');
    }
  }

  Future<void> _pickVideo() async {
    final playerId = _playerId;
    if (playerId == null) {
      _showMessage('Faca login para enviar videos.');
      return;
    }
    if (_uploadingVideo) return;

    try {
      setState(() => _uploadingVideo = true);
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        _showMessage('Nenhum video selecionado.');
        return;
      }

      final url = await _storage.uploadPlayerVideo(playerId, video);
      await _repository.addVideo(
        playerId: playerId,
        videoUrl: url,
        titulo: 'Video de desempenho',
      );

      _showMessage('Video enviado com sucesso.');
    } catch (error) {
      _showMessage('Nao foi possivel enviar o video: $error');
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  Future<void> _save() async {
    final playerId = _playerId;
    if (playerId == null) {
      _showMessage('Faca login para salvar o perfil.');
      return;
    }

    setState(() => _saving = true);
    try {
      var photoUrl = _fotoUrl;
      if (_foto != null) {
        photoUrl = await _storage.uploadProfilePhoto(playerId, _foto!);
      }

      final existing =
          await _repository.getPlayer(playerId) ?? Player.empty(playerId);
      final player = Player(
        id: playerId,
        userId: existing.userId,
        nome: _nome.text.trim(),
        idade: int.tryParse(_idade.text) ?? 0,
        cidade: _cidade.text.trim(),
        estado: _estado.text.trim().toUpperCase(),
        altura: double.tryParse(_altura.text.replaceAll(',', '.')) ?? 0,
        peso: double.tryParse(_peso.text.replaceAll(',', '.')) ?? 0,
        posicaoPrincipal: _posicaoPrincipal ?? '',
        posicaoSecundaria: _posicaoSecundaria ?? '',
        peDominante: _peDominante ?? '',
        clubeAtual: _clubeAtual.text.trim(),
        biografia: _bio.text.trim(),
        fotoUrl: photoUrl,
        telefone: _telefone.text.trim(),
        stats: PlayerStats(
          jogos: int.tryParse(_jogos.text) ?? 0,
          gols: int.tryParse(_gols.text) ?? 0,
          assistencias: int.tryParse(_assistencias.text) ?? 0,
          cartoesAmarelos: int.tryParse(_amarelos.text) ?? 0,
          cartoesVermelhos: int.tryParse(_vermelhos.text) ?? 0,
        ),
        mediaAvaliacoes: existing.mediaAvaliacoes,
        totalAvaliacoes: existing.totalAvaliacoes,
      );

      await _repository.savePlayer(player);
      if (!mounted) return;
      _showMessage('Perfil salvo com sucesso.');
      Navigator.pop(context);
    } catch (error) {
      _showMessage('Nao foi possivel salvar o perfil: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final controller in [
      _nome,
      _idade,
      _cidade,
      _estado,
      _telefone,
      _altura,
      _peso,
      _clubeAtual,
      _bio,
      _jogos,
      _gols,
      _assistencias,
      _amarelos,
      _vermelhos,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (context, snapshot) {
        if (!_loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Editar perfil')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: _ProfilePhotoPicker(
                  photoUrl: _fotoUrl,
                  previewBytes: _fotoPreviewBytes,
                  saving: _saving,
                  onTap: _saving ? null : _pickPhoto,
                ),
              ),
              const SectionTitle('Informacoes basicas'),
              AppTextField(
                controller: _nome,
                label: 'Nome',
                icon: Icons.person,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: _idade, label: 'Idade'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _telefone,
                      label: 'WhatsApp',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: _cidade, label: 'Cidade'),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: AppTextField(controller: _estado, label: 'Estado'),
                  ),
                ],
              ),
              const SectionTitle('Caracteristicas fisicas'),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: _altura, label: 'Altura'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(controller: _peso, label: 'Peso'),
                  ),
                ],
              ),
              const SectionTitle('Futebol'),
              _dropdown('Posicao principal', _posicaoPrincipal, _posicoes, (v) {
                setState(() => _posicaoPrincipal = v);
              }),
              const SizedBox(height: 10),
              _dropdown('Posicao secundaria', _posicaoSecundaria, _posicoes, (
                v,
              ) {
                setState(() => _posicaoSecundaria = v);
              }),
              const SizedBox(height: 10),
              _dropdown('Pe dominante', _peDominante, _pes, (v) {
                setState(() => _peDominante = v);
              }),
              const SizedBox(height: 10),
              AppTextField(controller: _clubeAtual, label: 'Clube atual'),
              const SectionTitle('Estatisticas'),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: _jogos, label: 'Jogos'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(controller: _gols, label: 'Gols'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      controller: _assistencias,
                      label: 'Assist.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _amarelos,
                      label: 'Amarelos',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      controller: _vermelhos,
                      label: 'Vermelhos',
                    ),
                  ),
                ],
              ),
              const SectionTitle('Biografia'),
              AppTextField(
                controller: _bio,
                label: 'Apresentacao',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _uploadingVideo ? null : _pickVideo,
                icon: _uploadingVideo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_outlined),
                label: Text(
                  _uploadingVideo
                      ? 'Enviando video...'
                      : 'Adicionar video de desempenho',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Salvar perfil'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ProfilePhotoPicker extends StatelessWidget {
  const _ProfilePhotoPicker({
    required this.photoUrl,
    required this.previewBytes,
    required this.saving,
    required this.onTap,
  });

  final String photoUrl;
  final Uint8List? previewBytes;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = previewBytes != null
        ? MemoryImage(previewBytes!)
        : (photoUrl.isEmpty ? null : NetworkImage(photoUrl));

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: image,
                  child: image == null
                      ? const Icon(
                          Icons.person,
                          size: 46,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                if (saving)
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                Positioned(
                  right: 2,
                  bottom: 6,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.image_outlined, size: 18),
          label: const Text('Alterar foto'),
        ),
      ],
    );
  }
}
