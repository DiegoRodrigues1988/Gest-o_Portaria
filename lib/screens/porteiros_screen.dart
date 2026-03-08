import 'package:flutter/material.dart';

import '../database_helper.dart';

class PorteirosScreen extends StatefulWidget {
  static const routeName = '/porteiros';

  const PorteirosScreen({super.key});

  @override
  State<PorteirosScreen> createState() => _PorteirosScreenState();
}

class _PorteirosScreenState extends State<PorteirosScreen> {
  late Future<List<Porteiro>> _futurePorteiros;

  @override
  void initState() {
    super.initState();
    _loadPorteiros();
  }

  void _loadPorteiros() {
    _futurePorteiros = DatabaseHelper.instance.getAllPorteiros();
  }

  Future<void> _showAddPorteiroDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final periodoCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AlertDialog(
              title: const Text('Novo Porteiro'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Informe o nome'
                              : null,
                    ),
                    TextFormField(
                      controller: senhaCtrl,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Informe a senha'
                          : null,
                    ),
                    TextFormField(
                      controller: periodoCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Período (manhã/tarde/noite)'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
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

                    await DatabaseHelper.instance.insertPorteiro(
                      Porteiro(
                        nome: nomeCtrl.text.trim(),
                        senha: senhaCtrl.text,
                        periodo: periodoCtrl.text.trim(),
                      ),
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();

                    setState(() {
                      _loadPorteiros();
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Porteiro cadastrado com sucesso.')),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Porteiro'),
          content: const Text('Tem certeza que deseja excluir este porteiro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await DatabaseHelper.instance.deletePorteiro(id);
      setState(() {
        _loadPorteiros();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Porteiro excluído.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Porteiros'),
      ),
      body: FutureBuilder<List<Porteiro>>(
        future: _futurePorteiros,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final porteiros = snapshot.data ?? [];

          if (porteiros.isEmpty) {
            return const Center(child: Text('Nenhum porteiro cadastrado.'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: porteiros.length,
                itemBuilder: (context, index) {
                  final porteiro = porteiros[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(porteiro.nome),
                      subtitle: Text('Período: ${porteiro.periodo}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Excluir',
                        onPressed: () => _confirmDelete(porteiro.id!),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPorteiroDialog,
        child: const Icon(Icons.add),
        tooltip: 'Adicionar porteiro',
      ),
    );
  }
}
