import 'package:flutter/material.dart';

import '../database_helper.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;
  bool _hasPorteiroCadastrado = true;

  @override
  void initState() {
    super.initState();
    _checkPorteiroExists();
  }

  Future<void> _checkPorteiroExists() async {
    final has = await DatabaseHelper.instance.hasAnyPorteiro();
    setState(() {
      _hasPorteiroCadastrado = has;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nome = _nomeController.text.trim();
    final senha = _senhaController.text;

    final user =
        await DatabaseHelper.instance.getPorteiroByNameAndSenha(nome, senha);

    setState(() => _isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome ou senha inválidos.')),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context)
        .pushReplacementNamed(DashboardScreen.routeName, arguments: user);
  }

  Future<void> _showCadastroPorteiroDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final senhaController = TextEditingController();
    final periodoController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cadastrar Porteiro'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o nome'
                      : null,
                ),
                TextFormField(
                  controller: senhaController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Informe a senha'
                      : null,
                ),
                TextFormField(
                  controller: periodoController,
                  decoration: const InputDecoration(
                      labelText: 'Período (manhã/tarde/noite)'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Informe o período'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  await DatabaseHelper.instance.insertPorteiro(
                    Porteiro(
                      nome: nomeController.text.trim(),
                      senha: senhaController.text,
                      periodo: periodoController.text.trim(),
                    ),
                  );

                  if (!mounted) return;
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Porteiro cadastrado com sucesso.')),
                  );

                  _checkPorteiroExists();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erro ao cadastrar: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Text(
                  'Gestão de Portaria',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nomeController,
                            decoration:
                                const InputDecoration(labelText: 'Nome'),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Informe o nome'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senhaController,
                            decoration:
                                const InputDecoration(labelText: 'Senha'),
                            obscureText: true,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Informe a senha'
                                    : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Entrar'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showCadastroPorteiroDialog,
                            child: const Text('Cadastrar porteiro'),
                          ),
                          if (!_hasPorteiroCadastrado)
                            TextButton(
                              onPressed: _showCadastroPorteiroDialog,
                              child: const Text('Primeiro Acesso'),
                            ),
                        ],
                      ),
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
}
