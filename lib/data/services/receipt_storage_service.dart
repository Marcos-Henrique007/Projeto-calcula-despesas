import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Copies picked receipts into app-owned storage so they survive picker cache
/// cleanup and remain available while the device is offline.
class ReceiptStorageService {
  ReceiptStorageService({this._uuid = const Uuid()});

  final Uuid _uuid;

  Future<String> saveReceipt(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('A imagem selecionada não está mais disponível.');
    }
    final root = Directory(p.join(await getDatabasesPath(), 'receipts'));
    await root.create(recursive: true);
    final extension = p.extension(sourcePath);
    final destination = File(p.join(root.path, '${_uuid.v4()}$extension'));
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> deleteReceipt(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
