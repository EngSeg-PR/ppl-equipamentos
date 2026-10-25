import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

ToqueEvento t(int seq, int ms, int tocado, int esperado) =>
    ToqueEvento(seq: seq, tMs: ms, tocado: tocado, esperado: esperado);

void main() {
  // Caso calculado à mão e conferido por uma implementação independente (Python):
  // n = 8, 10 toques, 2 erros (seq 3 e 6).
  // Instantes dos acertos dos números 1..8: 1000, 1800, 3200, 4000, 5500, 6100, 7000, 7800
  // Intervalos entre acertos: 800, 1400, 800, 1500, 600, 900, 800
  //   média = 6800 / 7 = 971,4286 ; desvio-padrão populacional = 314,9344
  // Quartos (bordas 0,2,4,6,8): 1800, 2200, 2100, 1700 (soma = 7800)
  final completa = [
    t(1, 1000, 1, 1),
    t(2, 1800, 2, 2),
    t(3, 2500, 5, 3), // erro
    t(4, 3200, 3, 3),
    t(5, 4000, 4, 4),
    t(6, 4600, 6, 5), // erro
    t(7, 5500, 5, 5),
    t(8, 6100, 6, 6),
    t(9, 7000, 7, 7),
    t(10, 7800, 8, 8),
  ];

  test('sessão completa: métricas batem com o cálculo manual', () {
    final m = calcularMetricas(toques: completa, n: 8, duracaoMs: 7800);
    expect(m.tempoTotalMs, 7800);
    expect(m.tempoPrimeiroToqueMs, 1000);
    expect(m.erros, 2);
    expect(m.mediaIntervaloMs, closeTo(971.4286, 0.001));
    expect(m.dpIntervaloMs, closeTo(314.9344, 0.001));
    expect(m.quartisMs, [1800, 2200, 2100, 1700]);
    expect(m.quartisMs.whereType<int>().reduce((a, b) => a + b), 7800);
  });

  test('sessão incompleta: quartos não concluídos ficam nulos', () {
    // só os 7 primeiros toques: acertos dos números 1..5
    final m = calcularMetricas(
      toques: completa.take(7).toList(),
      n: 8,
      duracaoMs: 6000,
    );
    expect(m.erros, 2);
    expect(m.mediaIntervaloMs, closeTo(1125, 0.001));
    expect(m.dpIntervaloMs, closeTo(326.9174, 0.01));
    expect(m.quartisMs, [1800, 2200, null, null]);
  });

  test('sem toques: tudo nulo e zero erros', () {
    final m = calcularMetricas(toques: const [], n: 8, duracaoMs: 180000);
    expect(m.tempoPrimeiroToqueMs, isNull);
    expect(m.erros, 0);
    expect(m.mediaIntervaloMs, isNull);
    expect(m.dpIntervaloMs, isNull);
    expect(m.quartisMs, [null, null, null, null]);
  });

  test('um único acerto: sem intervalo, logo média e desvio nulos', () {
    final m = calcularMetricas(toques: [t(1, 900, 1, 1)], n: 8, duracaoMs: 900);
    expect(m.mediaIntervaloMs, isNull);
    expect(m.dpIntervaloMs, isNull);
  });

  test('grade 6x6 perfeita: quartos de 9 números', () {
    final toques = [for (var i = 1; i <= 36; i++) t(i, i * 1000, i, i)];
    final m = calcularMetricas(toques: toques, n: 36, duracaoMs: 36000);
    expect(m.quartisMs, [9000, 9000, 9000, 9000]);
    expect(m.mediaIntervaloMs, closeTo(1000, 1e-9));
    expect(m.dpIntervaloMs, closeTo(0, 1e-9));
  });

  test('toJson usa as chaves do contrato e arredonda para 1 casa', () {
    final json = calcularMetricas(
      toques: completa,
      n: 8,
      duracaoMs: 7800,
    ).toJson();
    expect(
      json.keys,
      containsAll([
        'tempo_total_ms',
        'tempo_primeiro_toque_ms',
        'erros',
        'media_intervalo_ms',
        'dp_intervalo_ms',
        'quartis_ms',
      ]),
    );
    expect(json.containsKey('reacao'), isFalse);
    expect(json['media_intervalo_ms'], 971.4);
    expect(json['dp_intervalo_ms'], 314.9);
  });

  test('n menor que 4 lança erro', () {
    expect(
      () => calcularMetricas(toques: const [], n: 3, duracaoMs: 0),
      throwsArgumentError,
    );
  });

  test('não calcula métricas com tempos ou sequência inconsistentes', () {
    expect(
      () => calcularMetricas(toques: const [], n: 100, duracaoMs: 0),
      throwsArgumentError,
    );
    expect(
      () => calcularMetricas(toques: const [], n: 4, duracaoMs: -1),
      throwsArgumentError,
    );
    for (final eventos in [
      [t(1, -1, 1, 1)],
      [t(1, 200, 1, 1), t(2, 100, 2, 2)],
      [t(1, 1100, 1, 1)],
      [t(1, 100, 2, 2)],
      [t(1, 100, 5, 1)],
      [t(2, 100, 1, 1)],
      [t(1, 100, 1, 1), t(2, 200, 1, 1)],
    ]) {
      expect(
        () => calcularMetricas(toques: eventos, n: 4, duracaoMs: 1000),
        throwsArgumentError,
      );
    }
  });

  group('módulo de reação', () {
    test('média, mediana, omissões e antecipações', () {
      final eventos = [
        const EventoReacao(seq: 1, estimuloMs: 3000, respostaMs: 300),
        const EventoReacao(seq: 2, estimuloMs: 7000, respostaMs: 500),
        const EventoReacao(seq: 3, estimuloMs: 11000, respostaMs: 400),
        const EventoReacao(seq: 4, estimuloMs: 15000, respostaMs: 600),
        const EventoReacao(seq: 5, estimuloMs: 19000, omissao: true),
        const EventoReacao(
          seq: 6,
          estimuloMs: 23000,
          respostaMs: 50,
          antecipado: true,
        ),
      ];
      final r = calcularMetricasReacao(eventos);
      expect(r.mediaMs, 450);
      expect(r.medianaMs, 450);
      expect(r.omissoes, 1);
      expect(r.antecipacoes, 1);
    });

    test('mediana com quantidade ímpar', () {
      final r = calcularMetricasReacao([
        const EventoReacao(seq: 1, estimuloMs: 1, respostaMs: 100),
        const EventoReacao(seq: 2, estimuloMs: 2, respostaMs: 300),
        const EventoReacao(seq: 3, estimuloMs: 3, respostaMs: 200),
      ]);
      expect(r.medianaMs, 200);
    });

    test('sem reação válida: média e mediana nulas', () {
      final r = calcularMetricasReacao([
        const EventoReacao(seq: 1, estimuloMs: 1, omissao: true),
      ]);
      expect(r.mediaMs, isNull);
      expect(r.medianaMs, isNull);
      expect(r.omissoes, 1);
    });

    test('rejeita reação negativa e omissão com resposta', () {
      for (final evento in [
        const EventoReacao(seq: 1, estimuloMs: -1, respostaMs: 100),
        const EventoReacao(seq: 1, estimuloMs: 1, respostaMs: -1),
        const EventoReacao(
          seq: 1,
          estimuloMs: 1,
          respostaMs: 100,
          omissao: true,
        ),
        const EventoReacao(
          seq: 1,
          estimuloMs: 1,
          omissao: true,
          antecipado: true,
        ),
      ]) {
        expect(() => calcularMetricasReacao([evento]), throwsArgumentError);
      }
    });
  });
}
