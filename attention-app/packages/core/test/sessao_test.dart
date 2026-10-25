import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

const _parametros = {
  'regra': 'pior_indicador',
  'incompleta': 'vermelho',
  'sequencia': {
    'duracao_ms': {'verde_ate': 90000, 'amarelo_ate': 150000},
    'erros': {'verde_ate': 5, 'amarelo_ate': 12},
  },
};

SessaoTeste montar({
  List<int>? grade,
  List<ToqueEvento>? toques,
  List<RespostaQuestionario> respostas = const [],
  String? fotoPath,
  String? questionarioId,
  StatusSessao? status,
  int? duracaoMs,
  Metricas? metricas,
}) {
  final g = grade ?? [3, 1, 4, 2];
  final engine = SequenciaEngine(grade: g);
  engine.registrarToque(1, 500);
  engine.registrarToque(3, 900); // erro
  engine.registrarToque(2, 1200);
  engine.registrarToque(3, 1500);
  engine.registrarToque(4, 2000);
  final r = engine.fechar(2500);
  final metricasSessao = metricas ?? r.metricas;
  return SessaoTeste(
    id: '5e550000-0000-0000-0000-000000000001',
    condutorId: 'c1000000-0000-0000-0000-000000000001',
    momento: Momento.inicio,
    iniciadoEm: DateTime.utc(2026, 10, 24, 12, 0, 0),
    finalizadoEm: DateTime.utc(2026, 10, 24, 12, 0, 3),
    status: status ?? r.status,
    duracaoMs: duracaoMs ?? r.duracaoMs,
    grade: g,
    metricas: metricasSessao,
    classificacao: classificar(
      metricas: metricasSessao,
      completa: r.status == StatusSessao.completa,
      parametros: Map<String, dynamic>.from(_parametros),
    ),
    limiarId: 'l1',
    textosId: 't1',
    appVersao: '0.1.0',
    toques: toques ?? r.toques,
    respostas: respostas,
    fotoPath: fotoPath,
    questionarioId: questionarioId,
  );
}

void main() {
  test('payload segue o contrato de sync_sessao', () {
    final p = montar(
      respostas: const [
        RespostaQuestionario(perguntaId: 'sono', resposta: '7h_a_8h'),
      ],
      questionarioId: 'q1',
    ).toPayload();

    expect(p.keys, containsAll(['sessao', 'toques', 'reacao', 'respostas']));

    final s = p['sessao'] as Map<String, dynamic>;
    expect(
      s.keys,
      containsAll([
        'id',
        'condutor_id',
        'momento',
        'iniciado_em',
        'finalizado_em',
        'status',
        'duracao_ms',
        'grade',
        'metricas',
        'classificacao',
        'limiar_id',
        'textos_id',
        'app_versao',
      ]),
    );
    expect(s['momento'], 'inicio');
    expect(s['status'], 'completa');
    expect(s['classificacao'], 'verde');
    expect(s['grade'], [3, 1, 4, 2]);
    expect(s['questionario_id'], 'q1');
    expect(s['iniciado_em'], endsWith('Z'));
    expect(s.containsKey('foto_path'), isFalse);

    final toques = p['toques'] as List;
    expect(toques.length, 5);
    expect(
      (toques.first as Map).keys,
      containsAll(['seq', 't_ms', 'tocado', 'esperado', 'acerto']),
    );
    expect((toques[1] as Map)['acerto'], isFalse);
    expect(p['respostas'], [
      {'pergunta_id': 'sono', 'resposta': '7h_a_8h'},
    ]);
  });

  test('foto_path e questionario_id só aparecem quando informados', () {
    final s =
        montar(fotoPath: 'e1/abc.jpg').toPayload()['sessao']
            as Map<String, dynamic>;
    expect(s['foto_path'], 'e1/abc.jpg');
    expect(s.containsKey('questionario_id'), isFalse);
  });

  test('grade inválida impede a geração do payload', () {
    expect(() => montar(grade: [1, 1, 3, 4]).toPayload(), throwsA(anything));
  });

  test('toques fora de ordem impedem a geração do payload', () {
    final embaralhados = [
      const ToqueEvento(seq: 2, tMs: 10, tocado: 1, esperado: 1),
      const ToqueEvento(seq: 1, tMs: 20, tocado: 2, esperado: 2),
    ];
    expect(
      () => montar(toques: embaralhados).toPayload(),
      throwsFormatException,
    );
  });

  test('pergunta repetida impede a geração do payload', () {
    final s = montar(
      questionarioId: 'q1',
      respostas: const [
        RespostaQuestionario(perguntaId: 'sono', resposta: 'a'),
        RespostaQuestionario(perguntaId: 'sono', resposta: 'b'),
      ],
    );
    expect(s.toPayload, throwsFormatException);
  });

  test('status e duração precisam corresponder aos eventos registrados', () {
    expect(
      montar(status: StatusSessao.incompleta).toPayload,
      throwsFormatException,
    );
    expect(montar(toques: const []).toPayload, throwsFormatException);
    expect(montar(duracaoMs: 1900).toPayload, throwsFormatException);
    expect(montar(duracaoMs: 2100).toPayload, throwsFormatException);
  });

  test('métricas divergentes não são enviadas ao servidor', () {
    final sessao = montar(
      metricas: const Metricas(
        tempoTotalMs: 2000,
        tempoPrimeiroToqueMs: 500,
        erros: 0, // Os eventos registraram um erro.
        mediaIntervaloMs: 500,
        dpIntervaloMs: 0,
        quartisMs: [500, 700, 300, 500],
      ),
    );
    expect(sessao.toPayload, throwsFormatException);
  });

  test('respostas só são enviadas com a versão do questionário', () {
    final sessao = montar(
      respostas: const [
        RespostaQuestionario(
          perguntaId: 'sono',
          resposta: 'prefiro_nao_responder',
        ),
      ],
    );
    expect(sessao.toPayload, throwsFormatException);
  });

  test('alterar o payload não modifica as evidências da sessão', () {
    final sessao = montar();
    final payload = sessao.toPayload();
    final s = payload['sessao'] as Map<String, dynamic>;
    (s['grade'] as List)[0] = 99;
    ((s['metricas'] as Map)['quartis_ms'] as List)[0] = 999999;
    expect(sessao.grade, [3, 1, 4, 2]);
    expect(sessao.metricas.quartisMs.first, 500);
    expect(sessao.toPayload, returnsNormally);
  });
}
