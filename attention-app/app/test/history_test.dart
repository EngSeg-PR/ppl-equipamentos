import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagem_atencao_app/app.dart';
import 'package:triagem_atencao_app/history_app.dart';
import 'package:triagem_atencao_app/data/local_store.dart';
import 'package:triagem_atencao_app/data/models.dart';
import 'package:triagem_atencao_app/data/portal_api.dart';
import 'package:triagem_atencao_app/features/history/history_controller.dart';
import 'package:triagem_atencao_app/features/ensaio/ensaio_controller.dart'
    show RelogioEnsaio;
import 'package:triagem_core/triagem_core.dart';

class ChavesTeste implements CofreChaves {
  final values = <String, String>{};
  @override
  Future<String?> ler(String key) async => values[key];
  @override
  Future<void> gravar(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    values[key] = value;
  }

  @override
  Future<void> apagar(String key) async {
    values.remove(key);
  }
}

class DadosTeste implements ChaveValorDuravel {
  final values = <String, String>{};
  bool falhar = false;
  @override
  Future<String?> ler(String key) async => values[key];
  @override
  Future<void> gravar(String key, String value) async {
    if (falhar) throw StateError('quota de teste');
    values[key] = value;
  }

  @override
  Future<List<String>> chaves(String prefix) async =>
      values.keys.where((k) => k.startsWith(prefix)).toList();
}

class Clock implements RelogioEnsaio {
  int now = 0;
  @override
  int get milissegundos => now;
  @override
  void iniciar() {
    now = 0;
  }

  @override
  void parar() {}
}

const uid = '44444444-4444-4444-8444-444444444444',
    cid = '11111111-1111-4111-8111-111111111111',
    eid = '33333333-3333-4333-8333-333333333333';

class PortalTeste implements ServicoPortal {
  String? user;
  ErroPortal? falha;
  int envios = 0;
  final recebidos = <String, Map<String, dynamic>>{};
  @override
  String? get usuarioId => user;
  @override
  Future<bool> restaurar() async => user != null;
  @override
  Future<void> entrar(String email, String senha) async {
    user = email == 'outro@teste.invalid'
        ? '77777777-7777-4777-8777-777777777777'
        : uid;
  }

  @override
  Future<void> sair() async {
    user = null;
  }

  @override
  Future<ContextoAtencao> contexto([String? empresaId]) async =>
      ContextoAtencao({
        'principal': {'id': user, 'name': 'OPERADOR DE TESTE'},
        'company': {'id': cid, 'name': 'EMPRESA DE TESTE'},
        'companies': [
          {'id': cid, 'name': 'EMPRESA DE TESTE'}
        ],
        'employees': [
          {
            'id': eid,
            'name': 'PESSOA DE TESTE',
            'employee_number': 'QA-1',
            'job_title': 'CONDUTOR'
          }
        ],
        'scopes': null
      });
  @override
  Future<Map<String, dynamic>> enviar(AvaliacaoLocal a) async {
    envios++;
    if (falha != null) throw falha!;
    final payload = a.paraServidor(), old = recebidos[a.id];
    if (old != null && jsonEncode(old) != jsonEncode(payload)) {
      throw const ErroPortal('Conflito', 409);
    }
    recebidos[a.id] = payload;
    return {
      'status': old == null ? 'ok' : 'duplicada',
      'id': a.id,
      'moduleVersion': a.visual ? 57 : 51,
      'received_at': '2026-10-25T12:00:00Z'
    };
  }
}

class Fixture {
  final cofre = ChavesTeste(),
      dados = DadosTeste(),
      portal = PortalTeste(),
      clock = Clock();
  late final repo = RepositorioHistorico(cofre: cofre, dados: dados);
  HistoricoController controller() => HistoricoController(
      usarVisual: false,
      repositorio: repo,
      portal: portal,
      relogio: clock,
      criarGrade: (n) => List.generate(n, (i) => i + 1),
      sincronizacaoAutomatica: false);
}

Future<void> pronto(HistoricoController c) async {
  await c.entrar('operador@teste.invalid', 'SENHA APENAS NO TESTE');
  expect(c.praticar(eid, 'PORTO', 'MECÂNICA', Momento.inicio), isTrue);
  for (var n = 1; n <= 9; n++) {
    c.tocar(n);
  }
  expect(c.tela, TelaHistorico.pronto);
  await c.preparar();
  expect(c.tela, TelaHistorico.teste);
  c.iniciarCronometro();
}

Future<void> finalizar(HistoricoController c, Clock clock) async {
  for (var n = 1; n <= 36; n++) {
    clock.now = n * 100;
    c.tocar(n);
  }
  for (var i = 0; i < 100 && c.tela != TelaHistorico.resultado; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(c.tela, TelaHistorico.resultado);
}

void main() {
  test('histórico cifrado restaura após reinício e preserva avaliação sem rede',
      () async {
    final f = Fixture(), c = f.controller();
    addTearDown(c.dispose);
    await pronto(c);
    await finalizar(c, f.clock);
    expect(c.atual!.envio, SituacaoEnvio.pendente);
    expect(c.registros.length, 1);
    expect(f.dados.values.values.any((v) => v.contains('PESSOA DE TESTE')),
        isFalse);
    final freshRepo = RepositorioHistorico(cofre: f.cofre, dados: f.dados);
    final records = await freshRepo.listar('$uid/$cid');
    expect(records.single.toques.length, 36);
    expect(records.single.status, 'completa');
    f.portal.falha = const ErroPortal('offline', 0);
    await c.sincronizar(manual: true);
    expect(c.registros.single.envio, SituacaoEnvio.pendente);
    expect(c.registros.single.id, records.single.id);
    f.portal.falha = null;
    await c.sincronizar(manual: true);
    expect(c.registros.single.envio, SituacaoEnvio.sincronizado);
    expect(f.portal.recebidos.length, 1);
    await c.sair();
    expect(c.registros, isEmpty);
    await c.entrar('outro@teste.invalid', 'teste');
    expect(c.registros, isEmpty);
    await c.sair();
    await c.entrar('operador@teste.invalid', 'teste');
    expect(c.registros.length, 1);
  });
  test('recupera avaliação interrompida do último checkpoint sem duplicar',
      () async {
    final f = Fixture(), c = f.controller();
    await pronto(c);
    f.clock.now = 1200;
    c.tocar(1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final id = c.atual!.id;
    c.dispose();
    final next = f.controller();
    addTearDown(next.dispose);
    await next.iniciar();
    expect(next.registros.single.id, id);
    expect(next.registros.single.status, 'incompleta');
    expect(next.registros.single.toques.length, 1);
    await next.sincronizar(manual: true);
    expect(f.portal.recebidos[id]!['status'], 'incompleta');
  });
  test(
      'falha de gravação final bloqueia descarte e permite recuperar o mesmo ID',
      () async {
    final f = Fixture(), c = f.controller();
    addTearDown(c.dispose);
    await pronto(c);
    f.clock.now = 2000;
    f.dados.falhar = true;
    await c.concluir('Interrompida no teste');
    final id = c.atual!.id;
    expect(c.tela, TelaHistorico.salvando);
    expect(c.salvo, isFalse);
    c.voltar();
    expect(c.tela, TelaHistorico.salvando);
    f.dados.falhar = false;
    await c.tentarSalvar();
    expect(c.tela, TelaHistorico.resultado);
    expect(c.registros.single.id, id);
  });
  test('rejeição permanente fica no histórico e não entra em retry automático',
      () async {
    final f = Fixture(), c = f.controller();
    addTearDown(c.dispose);
    await pronto(c);
    await finalizar(c, f.clock);
    f.portal.falha = const ErroPortal('Acesso revogado', 403);
    await c.sincronizar(manual: true);
    expect(c.registros.single.envio, SituacaoEnvio.falhaPermanente);
    final count = f.portal.envios;
    await c.sincronizar(manual: true);
    expect(f.portal.envios, count);
    expect((await f.repo.listar('$uid/$cid')).length, 1);
  });
  test('chave ausente ou dado adulterado não vira histórico vazio', () async {
    final f = Fixture(), c = f.controller();
    addTearDown(c.dispose);
    await pronto(c);
    await finalizar(c, f.clock);
    await expectLater(
        RepositorioHistorico(cofre: ChavesTeste(), dados: f.dados)
            .listar('$uid/$cid'),
        throwsStateError);
    final key = f.dados.values.keys.firstWhere((k) => k.contains('/record/'));
    final envelope = objeto(jsonDecode(f.dados.values[key]!));
    final cipher = base64Decode(envelope['cipher'] as String);
    cipher[0] ^= 1;
    envelope['cipher'] = base64Encode(cipher);
    f.dados.values[key] = jsonEncode(envelope);
    await expectLater(
        RepositorioHistorico(cofre: f.cofre, dados: f.dados)
            .listar('$uid/$cid'),
        throwsA(anything));
  });
  test('criação concorrente usa uma única chave para todos os documentos',
      () async {
    final f = Fixture();
    f.portal.user = uid;
    final ctx = await f.portal.contexto();
    await Future.wait([f.repo.salvarContexto(ctx), f.repo.salvarContexto(ctx)]);
    expect(
        (await RepositorioHistorico(cofre: f.cofre, dados: f.dados)
                .lerContexto(ctx.escopo))!
            .empresaId,
        cid);
    expect(f.cofre.values.keys.where((k) => k.contains('_key_')).length, 1);
  });
  testWidgets('login, histórico vazio e tela móvel sem dados de outra conta',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture(), c = f.controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(TriagemApp(inicio: InicioHistorico(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Acesse sua conta'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('login-email')), 'operador@teste.invalid');
    await tester.enterText(find.byKey(const Key('login-senha')), 'teste');
    await tester.ensureVisible(find.byKey(const Key('login-entrar')));
    await tester.tap(find.byKey(const Key('login-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Nova avaliação'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('abrir-historico')));
    await tester.tap(find.byKey(const Key('abrir-historico')));
    await tester.pumpAndSettle();
    expect(find.text('Histórico neste aparelho'), findsOneWidget);
    expect(find.text('Nenhuma avaliação salva neste acesso e aparelho.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
