import 'package:flutter/material.dart';

import '../database_helper.dart';

class MoradoresScreen extends StatefulWidget {
  static const routeName = '/moradores';

  const MoradoresScreen({super.key});

  @override
  State<MoradoresScreen> createState() => _MoradoresScreenState();
}

class _MoradoresScreenState extends State<MoradoresScreen> {
  late Future<List<Morador>> _futureMoradores;

  @override
  void initState() {
    super.initState();
    _loadMoradores();
  }

  void _loadMoradores() {
    _futureMoradores = DatabaseHelper.instance.getAllMoradores();
  }

  Future<void> _showAddMoradorDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final aptoCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AlertDialog(
              title: const Text('Novo Morador'),
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
                      controller: aptoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Apartamento'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Informe o apartamento'
                              : null,
                    ),
                    TextFormField(
                      controller: whatsappCtrl,
                      decoration: const InputDecoration(
                          labelText: 'WhatsApp (com DDD)'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Informe o WhatsApp'
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

                    await DatabaseHelper.instance.insertMorador(
                      Morador(
                        nome: nomeCtrl.text.trim(),
                        apartamento: aptoCtrl.text.trim(),
                        whatsapp: whatsappCtrl.text.trim(),
                      ),
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();

                    setState(() {
                      _loadMoradores();
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Morador cadastrado com sucesso.')),
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
          title: const Text('Excluir Morador'),
          content: const Text('Tem certeza que deseja excluir este morador?'),
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
      await DatabaseHelper.instance.deleteMorador(id);
      setState(() {
        _loadMoradores();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Morador excluído.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moradores'),
      ),
      body: FutureBuilder<List<Morador>>(
        future: _futureMoradores,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final moradores = snapshot.data ?? [];

          if (moradores.isEmpty) {
            return const Center(child: Text('Nenhum morador cadastrado.'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: moradores.length,
                itemBuilder: (context, index) {
                  final morador = moradores[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(morador.nome),
                      subtitle: Text(
                          'Apto: ${morador.apartamento}\nWhatsApp: ${morador.whatsapp}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Excluir',
                        onPressed: () => _confirmDelete(morador.id!),
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
        onPressed: _showAddMoradorDialog,
        child: const Icon(Icons.add),
        tooltip: 'Adicionar morador',
      ),
    );
  }
}
