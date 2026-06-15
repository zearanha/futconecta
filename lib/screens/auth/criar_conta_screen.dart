import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import 'home_screen.dart';
import '../perfil/editar_perfil_screen.dart';

class CriarContaScreen extends StatefulWidget {
  const CriarContaScreen({super.key});

  @override
  State<CriarContaScreen> createState() => _CriarContaScreenState();
}

class _CriarContaScreenState extends State<CriarContaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  UserType _tipoSelecionado = UserType.jogador;
  bool _isLoading = false;
  bool _hidePassword = true;

  Future<void> _criarConta() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);
    try {
      final user = await _authService.createAccount(
        nome: _nomeController.text,
        email: _emailController.text,
        senha: _senhaController.text,
        cidade: _cidadeController.text,
        estado: _estadoController.text,
        tipoUsuario: _tipoSelecionado,
      );
      if (!mounted) return;
      if (user.tipoUsuario == UserType.jogador) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditarPerfilScreen(playerId: user.id),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'Este e-mail ja esta cadastrado.',
        'invalid-email' => 'Informe um e-mail valido.',
        'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
        _ => 'Nao foi possivel criar sua conta.',
      };
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const _SignupHeader(),
                const SizedBox(height: 18),
                _AccountTypeSelector(
                  selected: _tipoSelecionado,
                  onChanged: (value) => setState(() {
                    _tipoSelecionado = value;
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dados da conta',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tipoSelecionado == UserType.jogador
                              ? 'Esses dados criam seu acesso. Depois voce completa o perfil esportivo.'
                              : 'Esses dados identificam seu acesso como clube, treinador ou olheiro.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _nomeController,
                          label: _tipoSelecionado == UserType.jogador
                              ? 'Nome do jogador'
                              : 'Nome do responsavel ou instituicao',
                          icon: Icons.person,
                          textInputAction: TextInputAction.next,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _emailController,
                          label: 'E-mail',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _senhaController,
                          label: 'Senha',
                          icon: Icons.lock_outline,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          validator: _passwordValidator,
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: () => setState(() {
                              _hidePassword = !_hidePassword;
                            }),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 520;
                            final city = AppTextField(
                              controller: _cidadeController,
                              label: 'Cidade',
                              icon: Icons.location_city,
                              textInputAction: TextInputAction.next,
                              validator: _requiredValidator,
                            );
                            final state = AppTextField(
                              controller: _estadoController,
                              label: 'UF',
                              icon: Icons.map_outlined,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              validator: _stateValidator,
                              onFieldSubmitted: (_) {
                                if (!_isLoading) _criarConta();
                              },
                            );
                            if (compact) {
                              return Column(
                                children: [
                                  city,
                                  const SizedBox(height: 12),
                                  state,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: city),
                                const SizedBox(width: 12),
                                SizedBox(width: 150, child: state),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _NextStepNotice(type: _tipoSelecionado),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _criarConta,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _tipoSelecionado == UserType.jogador
                                ? 'Criar conta de jogador'
                                : 'Criar conta de olheiro',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Campo obrigatorio.';
    return null;
  }

  String? _emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Campo obrigatorio.';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Informe um e-mail valido.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Campo obrigatorio.';
    if (text.length < 6) return 'Use pelo menos 6 caracteres.';
    return null;
  }

  String? _stateValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Campo obrigatorio.';
    if (text.length != 2) return 'Use a sigla com 2 letras.';
    return null;
  }
}

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_soccer,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entre para o FutConecta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Crie seu acesso e conecte talentos, clubes e oportunidades.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({required this.selected, required this.onChanged});

  final UserType selected;
  final ValueChanged<UserType> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final cards = [
          _AccountTypeCard(
            selected: selected == UserType.jogador,
            icon: Icons.sports_soccer,
            title: 'Jogador',
            description:
                'Monte seu perfil, publique no feed e seja encontrado.',
            onTap: () => onChanged(UserType.jogador),
          ),
          _AccountTypeCard(
            selected: selected == UserType.clubeTreinadorOlheiro,
            icon: Icons.manage_search,
            title: 'Clube/Olheiro',
            description: 'Descubra atletas, acompanhe favoritos e converse.',
            onTap: () => onChanged(UserType.clubeTreinadorOlheiro),
          ),
        ];
        if (compact) {
          return Column(
            children: [cards[0], const SizedBox(height: 10), cards[1]],
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStepNotice extends StatelessWidget {
  const _NextStepNotice({required this.type});

  final UserType type;

  @override
  Widget build(BuildContext context) {
    final isPlayer = type == UserType.jogador;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isPlayer ? Icons.edit_note : Icons.dashboard_customize_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPlayer
                  ? 'Proximo passo: preencher posicao, estatisticas e biografia.'
                  : 'Proximo passo: acessar o feed e procurar jogadores.',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
