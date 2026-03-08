import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database_helper.dart';
import '../utils/pdf_utils.dart';

class EncomendasScreen extends StatefulWidget {
  static const routeName = '/encomendas';

  final Porteiro? porteiro;

  const EncomendasScreen({super.key, this.porteiro});

  @override
  State<EncomendasScreen> createState() => _EncomendasScreenState();
}

class _EncomendasScreenState extends State<EncomendasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _encomendas = [];
  List<Map<String, dynamic>> _filteredEncomendas = [];
  List<Morador> _moradores = [];
  String _searchTerm = '';

  // Fields used only on Windows to show webcam preview.
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final encomendas = await DatabaseHelper.instance.getEncomendasWithMorador();
    final moradores = await DatabaseHelper.instance.getAllMoradores();
    setState(() {
      _encomendas = encomendas;
      _filteredEncomendas = _applyFilter(encomendas, _searchTerm);
      _moradores = moradores;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> list, String search) {
    if (search.isEmpty) return list;

    final lower = search.toLowerCase();
    return list.where((row) {
      final nome = (row['morador_nome'] as String?) ?? '';
      final apto = (row['morador_apartamento'] as String?) ?? '';
      return nome.toLowerCase().contains(lower) ||
          apto.toLowerCase().contains(lower);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value;
      _filteredEncomendas = _applyFilter(_encomendas, value);
    });
  }

  Future<String?> _capturePhoto() async {
    if (Platform.isWindows) {
      return _capturePhotoWindows();
    }
    return _capturePhotoMobile();
  }

  Future<String?> _capturePhotoMobile() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(path.join(dir.path, 'encomendas'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final newPath = path.join(
        targetDir.path,
        'encomenda_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await File(picked.path).copy(newPath);
      return newPath;
    } catch (e, st) {
      debugPrint('Erro ao abrir câmera (mobile): $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a câmera: $e')),
        );
      }
      return null;
    }
  }

  Future<String?> _capturePhotoWindows() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        throw StateError('Nenhuma câmera encontrada.');
      }

      _cameraController?.dispose();
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();

      String? savedPath;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Tirar foto'),
            content: SizedBox(
              height: 300,
              child: _cameraController != null &&
                      _cameraController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_cameraController == null ||
                      !_cameraController!.value.isInitialized) return;

                  final xfile = await _cameraController!.takePicture();
                  final dir = await getApplicationDocumentsDirectory();
                  final targetDir =
                      Directory(path.join(dir.path, 'encomendas'));
                  if (!await targetDir.exists()) {
                    await targetDir.create(recursive: true);
                  }

                  final newPath = path.join(
                    targetDir.path,
                    'encomenda_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  );
                  await File(xfile.path).copy(newPath);
                  savedPath = newPath;
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Capturar'),
              ),
            ],
          );
        },
      );

      await _cameraController?.dispose();
      _cameraController = null;

      return savedPath;
    } catch (e, st) {
      debugPrint('Erro ao abrir câmera (Windows): $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a câmera: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _addEncomenda() async {
    final formKey = GlobalKey<FormState>();
    final descricaoCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    Morador? selectedMorador = _moradores.isNotEmpty ? _moradores.first : null;
    String? photoPath;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AlertDialog(
                  title: const Text('Nova Encomenda'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: descricaoCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Descrição'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Informe a descrição'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codigoCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Código'),
                        ),
                        const SizedBox(height: 12),
                        if (_moradores.isEmpty)
                          const Text(
                              'Cadastre um morador antes de registrar uma encomenda.')
                        else
                          DropdownButtonFormField<Morador>(
                            value: selectedMorador,
                            decoration:
                                const InputDecoration(labelText: 'Morador'),
                            items: _moradores
                                .map(
                                  (m) => DropdownMenuItem<Morador>(
                                    value: m,
                                    child: Text('${m.nome} (${m.apartamento})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => selectedMorador = value,
                            validator: (value) =>
                                value == null ? 'Selecione um morador' : null,
                          ),
                        const SizedBox(height: 12),
                        if (photoPath != null)
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showPhotoPreview(photoPath!),
                                child: Image.file(
                                  File(photoPath!),
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await _capturePhoto();
                            if (result != null) {
                              setDialogState(() => photoPath = result);
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tirar foto'),
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
                        final selected = selectedMorador;
                        if (selected == null) return;

                        final moradorId = selected.id;
                        if (moradorId == null) return;

                        final now = DateTime.now().toIso8601String();
                        final codigo = codigoCtrl.text.trim();

                        await DatabaseHelper.instance.insertEncomenda(
                          Encomenda(
                            descricao: descricaoCtrl.text.trim(),
                            codigo: codigo.isEmpty ? null : codigo,
                            idMorador: moradorId,
                            dataEntrada: now,
                            status: 'pendente',
                            fotoPath: photoPath,
                          ),
                        );

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Encomenda registrada.')),
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
      },
    );
  }

  Future<void> _showPhotoPreview(String photoPath) async {
    if (!File(photoPath).existsSync()) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.8;
        final maxWidth = MediaQuery.of(context).size.width * 0.9;

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Foto da encomenda',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight,
                                maxWidth: constraints.maxWidth),
                            child: Image.file(
                              File(photoPath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsEntregue(int id) async {
    final saida = DateTime.now().toIso8601String();
    await DatabaseHelper.instance.markEncomendaAsEntregue(
      id,
      saida,
      retiradoPor: widget.porteiro?.nome,
    );
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Encomenda marcada como entregue.')),
    );
  }

  Future<void> _confirmDeleteEncomenda(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Encomenda'),
          content: const Text('Tem certeza que deseja excluir esta encomenda?'),
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
      await DatabaseHelper.instance.deleteEncomenda(id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encomenda excluída.')),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Limpar tudo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Digite a senha do porteiro para confirmar a exclusão de todas as encomendas.'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final entered = passwordController.text;
                final expected = widget.porteiro?.senha;
                if (expected != null && entered == expected) {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Senha incorreta.')),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.clearEncomendas();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas as encomendas foram excluídas.')),
      );
    }
  }

  Future<void> _openWhatsapp(
      String? rawNumber, String nome, String apto) async {
    final onlyNumbers = (rawNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de WhatsApp inválido.')),
      );
      return;
    }

    final message = Uri.encodeComponent(
        'Olá $nome do apto $apto, você tem uma nova encomenda na portaria!');
    final uri = Uri.parse('https://wa.me/$onlyNumbers?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encomendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar relatório',
            onPressed: () async {
              await PdfUtils.sharePdfReport(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpar tudo',
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome ou apartamento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _encomendas.isEmpty
                      ? const Center(
                          child: Text('Nenhuma encomenda registrada.'))
                      : _filteredEncomendas.isEmpty
                          ? const Center(
                              child: Text('Nenhuma encomenda encontrada.'))
                          : Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 900),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filteredEncomendas.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredEncomendas[index];
                                    final status =
                                        (item['status'] as String?) ?? '';
                                    final nome =
                                        (item['morador_nome'] as String?) ?? '';
                                    final apto = (item['morador_apartamento']
                                            as String?) ??
                                        '';
                                    final whatsapp =
                                        (item['morador_whatsapp'] as String?) ??
                                            '';
                                    final id = (item['id'] as int?) ?? 0;
                                    final codigo =
                                        (item['codigo'] as String?) ?? '';
                                    final fotoPath =
                                        (item['foto_path'] as String?) ?? '';
                                    final retiradoPor =
                                        (item['retirado_por'] as String?) ?? '';
                                    final dataSaida =
                                        (item['data_saida'] as String?) ?? '';

                                    Widget? leading;
                                    if (fotoPath.isNotEmpty &&
                                        File(fotoPath).existsSync()) {
                                      leading = GestureDetector(
                                        onTap: () =>
                                            _showPhotoPreview(fotoPath),
                                        child: CircleAvatar(
                                          backgroundImage:
                                              FileImage(File(fotoPath)),
                                          radius: 26,
                                        ),
                                      );
                                    }

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: ListTile(
                                        leading: leading,
                                        title: Text(item['descricao'] ?? ''),
                                        subtitle: Text(
                                          '${codigo.isNotEmpty ? 'Código: $codigo\n' : ''}Morador: $nome ($apto)\nentrada: ${item['data_entrada'] ?? ''}\nstatus: $status' +
                                              (status == 'entregue'
                                                  ? '\nretirado por: $retiradoPor\nsaida: $dataSaida'
                                                  : ''),
                                        ),
                                        isThreeLine: true,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (status == 'pendente')
                                              IconButton(
                                                icon: const Icon(Icons.chat,
                                                    color: Colors.green),
                                                tooltip: 'Avisar no WhatsApp',
                                                onPressed: () => _openWhatsapp(
                                                    whatsapp, nome, apto),
                                              ),
                                            if (status == 'pendente')
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.blue),
                                                tooltip: 'Dar baixa',
                                                onPressed: () =>
                                                    _markAsEntregue(id),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              tooltip: 'Excluir',
                                              onPressed: () =>
                                                  _confirmDeleteEncomenda(id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moradores.isEmpty ? null : _addEncomenda,
        child: const Icon(Icons.add),
        tooltip: _moradores.isEmpty
            ? 'Cadastre um morador primeiro'
            : 'Nova encomenda',
      ),
    );
  }
}
