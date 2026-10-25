import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'local_store.dart';

Future<ChaveValorDuravel> abrirDados(CofreChaves cofre) async {
  const alias = 'prs_attention_v2_sqlcipher';
  final directory = await getDatabasesPath();
  final file = path.join(directory, 'prs_attention_v2.db');
  var password = await cofre.ler(alias);
  if (password == null) {
    if (await databaseExists(file)) {
      throw StateError(
          'Chave do banco local indisponível. O histórico foi preservado.');
    }
    password = chaveAleatoria();
    await cofre.gravar(alias, password);
  }
  final database = await openDatabase(file, password: password, version: 1,
      onCreate: (db, _) async {
    await db.execute(
        'CREATE TABLE documents (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
  });
  return _SqlCipherDados(database);
}

class _SqlCipherDados implements ChaveValorDuravel {
  _SqlCipherDados(this.database);
  final Database database;
  @override
  Future<String?> ler(String key) async {
    final rows = await database.query('documents',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  @override
  Future<void> gravar(String key, String value) async {
    await database.transaction((tx) async {
      await tx.insert('documents', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<String>> chaves(String prefix) async {
    final rows = await database.query('documents',
        columns: ['key'], where: 'key LIKE ?', whereArgs: ['$prefix%']);
    return rows.map((r) => r['key'] as String).toList();
  }
}
