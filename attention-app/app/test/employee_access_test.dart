import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagem_atencao_app/app.dart';
import 'package:triagem_atencao_app/history_app.dart';
import 'package:triagem_atencao_app/data/employee_access.dart';
import 'package:triagem_atencao_app/data/models.dart';
import 'package:triagem_atencao_app/data/portal_api.dart';
import 'package:triagem_atencao_app/features/history/history_controller.dart';

import 'history_test.dart' as f;

const outraEmpresa = '22222222-2222-4222-8222-222222222222';

class PortalPessoalTeste extends f.PortalTeste implements AcessoColaborador {
  String empresa = f.cid;
  List<AvaliacaoLocal> centrais = [];
  Completer<PaginaHistoricoPessoal>? resposta;
  @override
  Future<List<Map<String, dynamic>>> empresasDisponiveis() async => [
    {'id': f.cid, 'name': 'EMPRESA DE TESTE'},
    {'id': outraEmpresa, 'name': 'OUTRA EMPRESA DE TESTE'},
  ];
  @override
  Future<List<Map<String, dynamic>>> colaboradoresDaEmpresa(
    String empresaId,
  ) async => [
    {
      'id': f.eid,
      'name': empresaId == f.cid
          ? 'PESSOA DE TESTE'
          : 'PESSOA DE OUTRA EMPRESA',
    },
  ];
  @override
  Future<void> entrarColaborador(
    String empresaId,
    String colaboradorId,
    String matricula,
  ) async {
    if (matricula != '0001') {
      throw const ErroPortal('Confira a matrícula.', 401);
    }
    empresa = empresaId;
    user = colaboradorId;
  }

  @override
  Future<ContextoAtencao> contexto([String? empresaId]) async =>
      ContextoAtencao({
        'principal': {
          'id': user,
          'name': 'PESSOA DE TESTE',
          'role': 'employee',
        },
        'company': {'id': empresa, 'name': 'EMPRESA DE TESTE'},
        'companies': [
          {'id': empresa, 'name': 'EMPRESA DE TESTE'},
        ],
        'employees': [
          {
            'id': f.eid,
            'name': 'PESSOA DE TESTE',
            'employee_number': '0001',
            'job_title': 'CONDUTOR',
          },
        ],
        'scopes': null,
      });
  @override
  Future<PaginaHistoricoPessoal> historicoPessoal(
    ContextoAtencao contexto, {
    int offset = 0,
  }) async => resposta == null
      ? PaginaHistoricoPessoal(centrais, null)
      : resposta!.future;
}

HistoricoController pessoal(f.Fixture fixture, PortalPessoalTeste portal) =>
    HistoricoController(
      usarVisual: false,
      repositorio: fixture.repo,
      portal: portal,
      relogio: fixture.clock,
      criarGrade: (n) => List.generate(n, (i) => i + 1),
      sincronizacaoAutomatica: false,
    );

void main() {
  test('sessão pessoal vencida não autoriza fallback offline', () async {
    final cofre = f.ChavesTeste();
    await cofre.gravar(
      'prs_attention_v2_auth',
      jsonEncode({
        'kind': 'employee',
        'access_token': 'TOKEN-VENCIDO-TESTE',
        'expires_at': DateTime.now().millisecondsSinceEpoch - 1000,
        'user': {'id': f.eid},
      }),
    );
    final api = ApiPortal(
      cofre,
      url: 'https://teste.invalid',
      client: MockClient(
        (r) async =>
            throw StateError('Não deve tentar renovar a sessão vencida'),
      ),
    );
    expect(await api.restaurar(), true);
    await expectLater(
      api.contexto(f.cid),
      throwsA(isA<ErroPortal>().having((e) => e.status, 'status', 401)),
    );
  });
  test(
    'resposta central com outra identidade é recusada pelo cliente',
    () async {
      final api = ApiPortal(
        f.ChavesTeste(),
        url: 'https://teste.invalid',
        client: MockClient((r) async {
          final body = objeto(jsonDecode(r.body));
          return http.Response(
            jsonEncode(
              body['action'] == 'executor-login'
                  ? {
                      'executorToken': 'TOKEN-TESTE',
                      'expiresAt': DateTime.now()
                          .add(const Duration(hours: 12))
                          .toUtc()
                          .toIso8601String(),
                      'company': {'id': f.cid},
                      'employee': {'id': f.eid},
                    }
                  : {
                      'rows': [
                        {
                          'company_id': f.cid,
                          'employee_id': f.uid,
                          'payload': {},
                        },
                      ],
                    },
            ),
            200,
          );
        }),
      );
      await api.entrarColaborador(f.cid, f.eid, 'somente teste');
      final contexto = ContextoAtencao({
        'principal': {'id': f.eid, 'role': 'employee'},
        'company': {'id': f.cid, 'name': 'TESTE'},
        'companies': [],
        'employees': [],
        'scopes': null,
      });
      await expectLater(
        api.historicoPessoal(contexto),
        throwsA(isA<ErroPortal>().having((e) => e.status, 'status', 403)),
      );
    },
  );
  test(
    'sessão pessoal não armazena matrícula e não usa renovação da gestão',
    () async {
      final cofre = f.ChavesTeste();
      final acoes = <String>[];
      final api = ApiPortal(
        cofre,
        url: 'https://teste.invalid',
        publicKey: 'PUBLIC',
        client: MockClient((r) async {
          final body = objeto(jsonDecode(r.body));
          acoes.add(body['action'] as String);
          if (body['action'] == 'executor-login') {
            expect(body['password'], 'SENHA-SOMENTE-NO-TESTE');
            return http.Response(
              jsonEncode({
                'executorToken': 'SESSAO-PESSOAL-TESTE',
                'expiresAt': DateTime.now()
                    .add(const Duration(hours: 12))
                    .toUtc()
                    .toIso8601String(),
                'company': {'id': f.cid},
                'employee': {'id': f.eid},
              }),
              200,
            );
          }
          expect(r.headers['x-ppl-executor'], 'SESSAO-PESSOAL-TESTE');
          return http.Response(jsonEncode({'error': 'Sessão expirada'}), 401);
        }),
      );
      await api.entrarColaborador(f.cid, f.eid, 'SENHA-SOMENTE-NO-TESTE');
      expect(
        cofre.values.values.join().contains('SENHA-SOMENTE-NO-TESTE'),
        false,
      );
      expect(await api.restaurar(), true);
      await expectLater(api.contexto(f.cid), throwsA(isA<ErroPortal>()));
      expect(acoes, ['executor-login', 'attention-employee-context']);
      await api.sair();
      expect(cofre.values, isEmpty);
    },
  );
  test('histórico pessoal recupera registro central e conserva histórico antigo da gestão', () async {
    final fixture = f.Fixture(), gestor = fixture.controller();
    addTearDown(gestor.dispose);
    await f.pronto(gestor);
    await f.finalizar(gestor, fixture.clock);
    final antigo = gestor.atual!;
    final portal = PortalPessoalTeste()
      ..centrais = [
        antigo.alterar({'userId': f.eid, 'syncState': 'sincronizado'}),
      ];
    final c = pessoal(fixture, portal);
    addTearDown(c.dispose);
    await c.entrarColaborador(f.cid, f.eid, '0001');
    expect(c.registros, isEmpty);
    await c.carregarHistoricoPessoal();
    expect(c.registros.single.id, antigo.id);
    expect(
      (await fixture.repo.listar('${f.uid}/${f.cid}')).single.envio,
      SituacaoEnvio.pendente,
    );
    // Não trocar uma cópia pendente por uma resposta do servidor.
    await fixture.repo.salvar(
      c.registros.single.alterar({
        'syncState': 'pendente',
        'syncError': 'teste pendente',
      }),
    );
    await c.carregarHistoricoPessoal();
    expect(c.registros.single.envio, SituacaoEnvio.pendente);
    expect(c.registros.single.erro, 'teste pendente');
  });
  test('resposta de outra identidade e resposta após logout não entram no histórico', () async {
    final fixture = f.Fixture(), gestor = fixture.controller();
    addTearDown(gestor.dispose);
    await f.pronto(gestor);
    await f.finalizar(gestor, fixture.clock);
    final portal = PortalPessoalTeste()..centrais = [gestor.atual!];
    final c = pessoal(fixture, portal);
    addTearDown(c.dispose);
    await c.entrarColaborador(f.cid, f.eid, '0001');
    await c.carregarHistoricoPessoal();
    expect(c.registros, isEmpty);
    portal.resposta = Completer<PaginaHistoricoPessoal>();
    final consulta = c.carregarHistoricoPessoal();
    await c.sair();
    portal.resposta!.complete(
      PaginaHistoricoPessoal([
        gestor.atual!.alterar({'userId': f.eid}),
      ], null),
    );
    await consulta;
    expect(c.contexto, isNull);
    expect(c.registros, isEmpty);
    expect(await fixture.repo.listar('${f.eid}/${f.cid}'), isEmpty);
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'entrada pessoal $width: empresa, troca de colaborador, matrícula e histórico',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = width == 320
            ? 1.8
            : 1;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = f.Fixture(),
            portal = PortalPessoalTeste(),
            c = pessoal(fixture, portal);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          TriagemApp(inicio: InicioHistorico(controller: c)),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('entrada-empresa')));
        await tester.tap(find.byKey(const Key('entrada-empresa')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EMPRESA DE TESTE').last);
        await tester.pumpAndSettle();
        final seletor = find.byKey(
          const ValueKey('entrada-colaborador-${f.cid}'),
        );
        await tester.ensureVisible(seletor);
        await tester.tap(seletor);
        await tester.pumpAndSettle();
        await tester.tap(find.text('PESSOA DE TESTE').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('entrada-matricula')),
          '0001',
        );
        await tester.ensureVisible(find.byKey(const Key('entrada-entrar')));
        await tester.tap(find.byKey(const Key('entrada-entrar')));
        await tester.pumpAndSettle();
        expect(find.text('Nova avaliação'), findsOneWidget);
        expect(find.byKey(const Key('colaborador')), findsNothing);
        expect(find.byKey(const Key('colaborador-pessoal')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('abrir-historico')));
        await tester.tap(find.byKey(const Key('abrir-historico')));
        await tester.pumpAndSettle();
        expect(find.text('Meu histórico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
