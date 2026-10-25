import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'store_platform_stub.dart'
    if (dart.library.io) 'store_platform_native.dart'
    if (dart.library.js_interop) 'store_platform_web.dart' as platform;
import 'models.dart';

abstract interface class CofreChaves {
  Future<String?> ler(String key);
  Future<void> gravar(String key, String value);
  Future<void> apagar(String key);
}

class CofreSeguro implements CofreChaves {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> ler(String key) => _storage.read(key: key);
  @override
  Future<void> gravar(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> apagar(String key) => _storage.delete(key: key);
}

abstract interface class ChaveValorDuravel {
  Future<String?> ler(String key);
  Future<void> gravar(String key, String value);
  Future<List<String>> chaves(String prefix);
}

String chaveAleatoria() =>
    base64Encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));

class RepositorioHistorico {
  RepositorioHistorico({required this.cofre, required this.dados});
  final CofreChaves cofre;
  final ChaveValorDuravel dados;
  final _aes = AesGcm.with256bits();
  final Map<String, SecretKey> _chaves = {};
  final Map<String, Future<SecretKey>> _carregandoChaves = {};

  static Future<RepositorioHistorico> abrir() async {
    final cofre = CofreSeguro();
    final dados = await platform.abrirDados(cofre);
    return RepositorioHistorico(cofre: cofre, dados: dados);
  }

  String _namespace(String escopo) =>
      sha256.convert(utf8.encode(escopo)).toString();
  Future<SecretKey> _chave(String escopo) {
    final nome = _namespace(escopo);
    if (_chaves[nome] != null) return Future.value(_chaves[nome]!);
    return _carregandoChaves.putIfAbsent(
        nome,
        () => _abrirChave(escopo).whenComplete(() {
              _carregandoChaves.remove(nome);
            }));
  }

  Future<SecretKey> _abrirChave(String escopo) async {
    final nome = _namespace(escopo);
    if (_chaves[nome] != null) return _chaves[nome]!;
    final alias = 'prs_attention_v2_key_$nome';
    var encoded = await cofre.ler(alias);
    if (encoded == null) {
      // Sem chave de um histórico existente, falha fechada: não substitui a chave.
      if ((await dados.chaves('attention/$nome/')).isNotEmpty) {
        throw StateError(
            'Chave do histórico indisponível. Preserve o aparelho e solicite recuperação.');
      }
      encoded = chaveAleatoria();
      await cofre.gravar(alias, encoded);
    }
    final key = SecretKey(base64Decode(encoded));
    _chaves[nome] = key;
    return key;
  }

  Future<void> _gravar(
      String escopo, String tipo, Map<String, dynamic> document) async {
    final nome = 'attention/${_namespace(escopo)}/$tipo';
    final key = await _chave(escopo);
    final secret = await _aes.encrypt(utf8.encode(jsonEncode(document)),
        secretKey: key, aad: utf8.encode(nome));
    await dados.gravar(
        nome,
        jsonEncode({
          'v': 1,
          'nonce': base64Encode(secret.nonce),
          'cipher': base64Encode(secret.cipherText),
          'mac': base64Encode(secret.mac.bytes)
        }));
  }

  Future<Map<String, dynamic>?> _ler(String escopo, String tipo) async {
    final nome = 'attention/${_namespace(escopo)}/$tipo';
    final raw = await dados.ler(nome);
    if (raw == null) return null;
    final envelope = objeto(jsonDecode(raw));
    if (envelope['v'] != 1) {
      throw const FormatException('Versão de histórico não reconhecida.');
    }
    final secret = SecretBox(base64Decode(envelope['cipher'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)));
    final plain = await _aes.decrypt(secret,
        secretKey: await _chave(escopo), aad: utf8.encode(nome));
    return objeto(jsonDecode(utf8.decode(plain)));
  }

  Future<void> salvar(AvaliacaoLocal avaliacao) =>
      _gravar(avaliacao.escopo, 'record/${avaliacao.id}', avaliacao.json);
  Future<List<AvaliacaoLocal>> listar(String escopo) async {
    final prefix = 'attention/${_namespace(escopo)}/record/';
    final registros = <AvaliacaoLocal>[];
    for (final key in await dados.chaves(prefix)) {
      final document =
          await _ler(escopo, 'record/${key.substring(prefix.length)}');
      if (document == null) {
        throw StateError('Registro local ausente durante a leitura.');
      }
      final item = AvaliacaoLocal(document);
      if (item.escopo != escopo) {
        throw StateError('Escopo local inconsistente.');
      }
      registros.add(item);
    }
    registros.sort((a, b) => b.inicio.compareTo(a.inicio));
    return registros;
  }

  Future<void> salvarContexto(ContextoAtencao contexto) => _gravar(
      contexto.escopo,
      'context',
      {...contexto.json, 'cachedAt': DateTime.now().toUtc().toIso8601String()});
  Future<ContextoAtencao?> lerContexto(String escopo) async {
    final json = await _ler(escopo, 'context');
    return json == null ? null : ContextoAtencao(json);
  }
}
