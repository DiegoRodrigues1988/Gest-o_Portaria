import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/portaria_background.dart';

enum ReportType { all, txt, pdf }

class RelatorioScreen extends StatefulWidget {
  static const routeName = '/relatorio';

  const RelatorioScreen({super.key});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  String? _lastSavedTxt;
  String? _lastSavedPdf;
  List<FileSystemEntity> _savedReports = [];
  ReportType _filter = ReportType.all;

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  Future<Directory> _getReportsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(path.join(dir.path, 'relatorios_portaria'));
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  Future<void> _loadSavedReports() async {
    final reportsDir = await _getReportsDirectory();
    final files = reportsDir.listSync().whereType<File>().where((f) {
      final ext = path.extension(f.path).toLowerCase();
      return ext == '.txt' || ext == '.pdf';
    }).toList();

    files.sort((a, b) {
      final aModified = a.statSync().modified;
      final bModified = b.statSync().modified;
      return bModified.compareTo(aModified);
    });

    if (mounted) {
      setState(() => _savedReports = files);
    }
  }

  List<FileSystemEntity> get _filteredReports {
    if (_filter == ReportType.all) return _savedReports;
    final ext = _filter == ReportType.txt ? '.txt' : '.pdf';
    return _savedReports
        .where((f) => path.extension(f.path).toLowerCase() == ext)
        .toList();
  }

  void _setFilter(ReportType filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  Future<void> _deleteAllReports() async {
    final reportsDir = await _getReportsDirectory();
    for (final file in reportsDir.listSync().whereType<File>()) {
      final ext = path.extension(file.path).toLowerCase();
      if (ext == '.txt' || ext == '.pdf') {
        await file.delete();
      }
    }
    await _loadSavedReports();
  }

  String _formatDateTime(DateTime dateTime) {
    final twoDigits = (int n) => n.toString().padLeft(2, '0');
    final day = twoDigits(dateTime.day);
    final month = twoDigits(dateTime.month);
    final year = dateTime.year.toString();
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _deleteReport(File file) async {
    if (await file.exists()) {
      await file.delete();
      await _loadSavedReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Arquivo excluído: ${path.basename(file.path)}')),
        );
      }
    }
  }

  Future<void> _openFile(String filePath) async {
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
      );
    }
  }

  Future<String> _saveTxtToDisk(String content) async {
    final dir = await _getReportsDirectory();
    final file = File(path.join(
      dir.path,
      'relatorio_portaria_${DateTime.now().millisecondsSinceEpoch}.txt',
    ));
    await file.writeAsString(content);

    _lastSavedTxt = file.path;
    await _loadSavedReports();
    return file.path;
  }

  Future<void> _saveTxt() async {
    setState(() => _saving = true);
    try {
      final content = _controller.text.trim();
      if (content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Digite algo para salvar.')),
          );
        }
        return;
      }

      final filePath = await _saveTxtToDisk(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Relatório salvo em: $filePath')),
        );
      }

      // Tenta abrir o arquivo salvo (útil em Windows/desktop)
      await _openFile(filePath);
    } catch (e, st) {
      debugPrint('Erro ao salvar relatório: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar relatório: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _saving = true);
    try {
      final content = _controller.text.trim();
      if (content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Digite algo para exportar.')),
          );
        }
        return;
      }

      // Certifica-se de que o relatório também foi salvo em TXT para o usuário.
      final txtFilePath = await _saveTxtToDisk(content);

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Relatório de Portaria',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Arquivo de texto salvo: ${path.basename(txtFilePath)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.SizedBox(height: 12),
                pw.Text(content),
              ],
            ),
          ),
        ),
      );

      final bytes = await pdf.save();

      final dir = await _getReportsDirectory();
      final file = File(path.join(
        dir.path,
        'relatorio_portaria_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ));
      await file.writeAsBytes(bytes);

      _lastSavedPdf = file.path;
      await _loadSavedReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF salvo em: ${file.path}')),
        );
      }

      // Tenta abrir o arquivo salvo (útil em Windows/desktop)
      await _openFile(file.path);

      // Fallback para dispositivos móveis (compartilhar)
      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'relatorio_portaria_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
    } catch (e, st) {
      debugPrint('Erro ao exportar relatório: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar relatório: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório do Porteiro'),
      ),
      body: Stack(
        children: [
          const PortariaBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: 'Escreva o relatório aqui...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveTxt,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar TXT'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exportar PDF'),
                      ),
                    ),
                  ],
                ),
                if (_lastSavedTxt != null || _lastSavedPdf != null)
                  const SizedBox(height: 12),
                if (_lastSavedTxt != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Último TXT: ${path.basename(_lastSavedTxt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openFile(_lastSavedTxt!),
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                if (_lastSavedPdf != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Último PDF: ${path.basename(_lastSavedPdf!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openFile(_lastSavedPdf!),
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_savedReports.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _filter == ReportType.all,
                              onSelected: (_) => _setFilter(ReportType.all),
                            ),
                            ChoiceChip(
                              label: const Text('TXT'),
                              selected: _filter == ReportType.txt,
                              onSelected: (_) => _setFilter(ReportType.txt),
                            ),
                            ChoiceChip(
                              label: const Text('PDF'),
                              selected: _filter == ReportType.pdf,
                              onSelected: (_) => _setFilter(ReportType.pdf),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title:
                                    const Text('Excluir todos os relatórios'),
                                content: const Text(
                                    'Tem certeza que deseja excluir todos os relatórios?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Excluir tudo'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmed == true) {
                            await _deleteAllReports();
                          }
                        },
                        child: const Text('Excluir todos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Relatórios salvos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      itemCount: _filteredReports.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final file = _filteredReports[index];
                        final name = path.basename(file.path);
                        final modified = file.statSync().modified;
                        final formattedDate = _formatDateTime(modified);
                        final isPdf =
                            path.extension(file.path).toLowerCase() == '.pdf';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.description,
                            size: 20,
                            color: isPdf ? Colors.redAccent : Colors.blueGrey,
                          ),
                          title: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _openFile(file.path),
                                child: const Text('Abrir'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Excluir arquivo',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Excluir arquivo'),
                                        content: Text('Deseja excluir $name?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Excluir'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (confirmed == true) {
                                    await _deleteReport(File(file.path));
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final dir = await _getReportsDirectory();
                    await _openFile(dir.path);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir pasta de relatórios'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
