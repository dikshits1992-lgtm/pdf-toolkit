import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

void main() => runApp(const PdfToolkitApp());

class PdfToolkitApp extends StatelessWidget {
  const PdfToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Toolkit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const ImageToPdfScreen(),
    );
  }
}

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _images = [];
  bool _busy = false;

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _makePdf() async {
    if (_images.isEmpty) return;
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      for (final f in _images) {
        final image = pw.MemoryImage(await f.readAsBytes());
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final dir = await getTemporaryDirectory();
      final name = 'images_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(file.path)], text: 'My PDF');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF')),
      body: _images.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tap "Add images" to pick photos.\nThey become pages of one PDF.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _images.removeAt(oldIndex);
                  _images.insert(newIndex, item);
                });
              },
              itemBuilder: (_, i) => ListTile(
                key: ObjectKey(_images[i]),
                leading: Image.file(_images[i],
                    width: 48, height: 48, fit: BoxFit.cover),
                title: Text('Page ${i + 1}'),
                subtitle: const Text('Hold and drag to reorder'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _images.removeAt(i)),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add images'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_busy || _images.isEmpty) ? null : _makePdf,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('Create PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
