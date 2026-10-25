import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagem_atencao_app/data/portal_api.dart';
import 'history_test.dart' show ChavesTeste, uid, cid;

Map<String, dynamic> session([int expiry = 3600]) => {
      'access_token': 'TOKEN-TESTE',
      'refresh_token': 'REFRESH-TESTE',
      'expires_in': expiry,
      'user': {'id': uid}
    };
Map<String, dynamic> contextData() => {
      'moduleVersion': 51,
      'principal': {'id': uid, 'name': 'OPERADOR DE TESTE'},
      'company': {'id': cid, 'name': 'EMPRESA DE TESTE'},
      'companies': [
        {'id': cid, 'name': 'EMPRESA DE TESTE'}
      ],
      'employees': [],
      'scopes': null
    };
http.Response jsonResponse(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});

class ChavesAtrasadas extends ChavesTeste {
  final iniciou = Completer<void>(), liberar = Completer<void>();
  @override
  Future<void> gravar(String key, String value) async {
    if (key == 'prs_attention_v2_auth') {
      iniciou.complete();
      await liberar.future;
    }
    await super.gravar(key, value);
  }
}

void main() {
  test('senha não é persistida e logout remove a sessão protegida', () async {
    final cofre = ChavesTeste();
    final api = ApiPortal(cofre,
        url: 'https://test.invalid',
        publicKey: 'PUBLIC-TEST',
        client: MockClient((request) async => jsonResponse(session())));
    await api.entrar('teste@invalid', 'SENHA-QUE-NAO-PODE-SER-GUARDADA');
    expect(api.usuarioId, uid);
    expect(
        cofre.values.values.join().contains('SENHA-QUE-NAO-PODE-SER-GUARDADA'),
        isFalse);
    await api.sair();
    expect(api.usuarioId, isNull);
    expect(cofre.values, isEmpty);
  });
  test('logout durante gravação não restaura um token atrasado', () async {
    final cofre = ChavesAtrasadas();
    final api = ApiPortal(cofre,
        url: 'https://test.invalid',
        publicKey: 'PUBLIC-TEST',
        client: MockClient((r) async => jsonResponse(session())));
    final entry = api.entrar('teste@invalid', 'apenas-teste');
    final failed = expectLater(entry, throwsA(isA<ErroPortal>()));
    await cofre.iniciou.future;
    final exiting = api.sair();
    cofre.liberar.complete();
    await failed;
    await exiting;
    expect(api.usuarioId, isNull);
    expect(cofre.values, isEmpty);
  });
  test('resposta de contexto atrasada é rejeitada após sair da conta',
      () async {
    final loading = Completer<void>(), reply = Completer<http.Response>();
    final api = ApiPortal(ChavesTeste(),
        url: 'https://test.invalid',
        publicKey: 'PUBLIC-TEST', client: MockClient((r) async {
      if (r.url.path.startsWith('/auth/')) {
        return jsonResponse(session());
      }
      loading.complete();
      return reply.future;
    }));
    await api.entrar('teste@invalid', 'teste');
    final read = api.contexto();
    final failed = expectLater(read, throwsA(isA<ErroPortal>()));
    await loading.future;
    await api.sair();
    reply.complete(jsonResponse(contextData()));
    await failed;
    expect(api.usuarioId, isNull);
  });
  test('renovação de token é única para chamadas simultâneas', () async {
    var refreshes = 0;
    final tokens = <String?>[];
    final api = ApiPortal(ChavesTeste(),
        url: 'https://test.invalid',
        publicKey: 'PUBLIC-TEST', client: MockClient((r) async {
      if (r.url.queryParameters['grant_type'] == 'password') {
        return jsonResponse(session(0));
      }
      if (r.url.queryParameters['grant_type'] == 'refresh_token') {
        refreshes++;
        await Future<void>.delayed(Duration.zero);
        return jsonResponse({...session(), 'access_token': 'TOKEN-RENOVADO'});
      }
      tokens.add(r.headers['Authorization']);
      return jsonResponse(contextData());
    }));
    await api.entrar('teste@invalid', 'teste');
    await Future.wait([api.contexto(), api.contexto()]);
    expect(refreshes, 1);
    expect(tokens, ['Bearer TOKEN-RENOVADO', 'Bearer TOKEN-RENOVADO']);
  });
}
