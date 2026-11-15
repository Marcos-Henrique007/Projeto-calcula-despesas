import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/session_view_model.dart';
import '../widgets/theme_mode_button.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegistration = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionViewModel>();
    final success = _isRegistration
        ? await session.register(_name.text, _email.text, _password.text)
        : await session.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signInWithGoogle() async {
    final success = await context.read<SessionViewModel>().signInWithGoogle();
    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  Future<void> _recoverPassword() async {
    final email = TextEditingController(text: _email.text);
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: _validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      final sent =
          await context.read<SessionViewModel>().sendPasswordReset(email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Se a conta existir, enviaremos um link para redefinir a senha.'
              : context.read<SessionViewModel>().errorMessage ??
                  'Não foi possível enviar o link.'),
        ),
      );
    }
    email.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conta DividiTrip'),
        actions: const [ThemeModeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF065F46)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.travel_explore,
                              size: 44, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            _isRegistration
                                ? 'Crie sua conta'
                                : 'Entre na sua conta',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRegistration
                                ? 'Organize viagens e compartilhe despesas com seu grupo.'
                                : 'Acesse seus grupos e continue de onde parou.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFD1FAE5)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isRegistration) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Informe seu nome.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) {
                        if ((value?.length ?? 0) < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    if (!_isRegistration)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recoverPassword,
                          child: const Text('Esqueci minha senha'),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    if (session.errorMessage != null) ...[
                      Text(
                        session.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: session.isBusy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: session.isBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isRegistration ? 'Criar conta' : 'Entrar'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou continue com'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: session.isBusy ? null : _signInWithGoogle,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFF4285F4),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      label: const Text('Continuar com Google'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Continuar como visitante'),
                    ),
                    TextButton(
                      onPressed: session.isBusy
                          ? null
                          : () => setState(
                              () => _isRegistration = !_isRegistration),
                      child: Text(_isRegistration
                          ? 'Já tenho conta'
                          : 'Criar conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
