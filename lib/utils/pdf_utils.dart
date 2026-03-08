import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database_helper.dart';

class PdfUtils {
  static Future<Uint8List> generateEncomendasPdf() async {
    final records = await DatabaseHelper.instance.getEncomendasWithMorador();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Relatório de Encomendas',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 12),
            ...records.map((row) {
              final descricao = row['descricao'] ?? '';
              final nome = row['morador_nome'] ?? '';
              final apto = row['morador_apartamento'] ?? '';
              final entrada = row['data_entrada'] as String? ?? '';
              final saida = row['data_saida'] as String? ?? '';
              final status = row['status'] ?? '';
              final retiradoPor = row['retirado_por'] ?? '';
              final fotoPath = row['foto_path'] as String?;

              pw.Widget imageWidget = pw.Container(
                width: 60,
                height: 60,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  color: PdfColors.grey200,
                ),
                child: pw.Center(
                  child: pw.Text('Sem foto', style: pw.TextStyle(fontSize: 8)),
                ),
              );

              if (fotoPath != null && fotoPath.isNotEmpty) {
                try {
                  final bytes = File(fotoPath).readAsBytesSync();
                  final image = pw.MemoryImage(bytes);
                  imageWidget = pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey600)),
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  );
                } catch (_) {
                  // ignore if image not found
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      imageWidget,
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Descrição: $descricao',
                                style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Morador: $nome ($apto)',
                                style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Entrada: $entrada',
                                style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Saída: $saida',
                                style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Status: $status',
                                style: pw.TextStyle(fontSize: 10)),
                            if (retiradoPor.isNotEmpty)
                              pw.Text('Retirado por: $retiradoPor',
                                  style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(),
                ],
              );
            }).toList(),
            pw.SizedBox(height: 20),
            pw.Text('Total de encomendas: ${records.length}',
                style: pw.TextStyle(fontSize: 12)),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<Directory> _getSaveDirectory() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final documentsDir = Directory(path.join(userProfile, 'Documents'));
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }
        return documentsDir;
      }
    }

    return await getApplicationDocumentsDirectory();
  }

  static Future<String> savePdfToFile(Uint8List bytes,
      {String? fileName}) async {
    final directory = await _getSaveDirectory();
    final name = fileName ??
        'relatorio_encomendas_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path.join(directory.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> sharePdfReport(BuildContext context) async {
    final bytes = await generateEncomendasPdf();
    final filePath = await savePdfToFile(bytes);

    await Printing.sharePdf(
        bytes: bytes, filename: filePath.split(Platform.pathSeparator).last);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF salvo em: $filePath')),
      );
    }
  }
}
