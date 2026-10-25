import 'package:web/web.dart' as web;

import 'local_store.dart';

Future<ChaveValorDuravel> abrirDados(CofreChaves cofre) async => _WebDados();

class _WebDados implements ChaveValorDuravel {
  @override
  Future<String?> ler(String key) async => web.window.localStorage.getItem(key);
  @override
  Future<void> gravar(String key, String value) async {
    // setItem é atômico por documento; quota/permissão lança e bloqueia o fluxo.
    web.window.localStorage.setItem(key, value);
    if (web.window.localStorage.getItem(key) != value) {
      throw StateError('O navegador não confirmou o salvamento.');
    }
  }

  @override
  Future<List<String>> chaves(String prefix) async {
    final storage = web.window.localStorage;
    final keys = <String>[];
    for (var i = 0; i < storage.length; i++) {
      final key = storage.key(i);
      if (key != null && key.startsWith(prefix)) keys.add(key);
    }
    return keys;
  }
}
