import 'dart:math';

import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

void main() {
  test(
      'microssegundos preservados; antecipação e decil não se confundem com percentil',
      () {
    final p = List.generate(4, (_) => {'kind': 'go', 'waitMs': 800});
    final tr = List.generate(
        4,
        (i) => {
              'seq': i + 1,
              'shownMs': 800 + i * 2000,
              'shownUs': 800123 + i * 2000000,
              'closedMs': 1801 + i * 2000
            });
    final r = List.generate(
        4,
        (i) => {
              'seq': i + 1,
              'tMs': 800 + i * 2000 + [50, 600, 200, 900][i],
              'tUs': 800123 + i * 2000000 + [50000, 600000, 200333, 900000][i],
              'source': 'pointer'
            });
    final m = metricasVisuais(p, tr, r, 7801);
    expect(m['antecipacoes'], 1);
    expect(m['respostas_validas'], 3);
    expect(m['lapsos'], 2);
    expect(m['rapidos10_media_ms'], 200.3);
    expect(m['lentos10_media_ms'], 900);
    expect(m['mediana_reacao_ms'], 600);
    expect(m['declinio_ms'], isNull);
  });
  test('plano auditável, treino separado e orçamento de tempo', () {
    for (var seed = 0; seed < 100; seed++) {
      final p = planoVisual(random: Random(seed));
      expect(p.length, 30);
      expect(p.where((s) => s['kind'] == 'nogo').length, 6);
      expect(
        p.every(
          (s) => (s['waitMs'] as int) >= 800 && (s['waitMs'] as int) <= 1600,
        ),
        isTrue,
      );
      expect(p, planoVisual(random: Random(seed)));
    }
    expect(planoVisual(treino: true).map((s) => s['kind']), [
      'go',
      'nogo',
    ]);
    // 30 ensaios + 2 de treino + 6 segundos de demonstração ativa.
    expect(32 * (1600 + 1000 + 200) + 6000, lessThan(120000));
  });
  test('início medido no quadro, atraso não fabrica estímulos', () {
    final e = VisualEngine([
      {'kind': 'go', 'waitMs': 800},
      {'kind': 'nogo', 'waitMs': 800},
    ]);
    e.avancar(900);
    expect(e.fase, FaseVisual.apresentar);
    expect(e.ensaios, isEmpty);
    e.responder(910, 'pointer');
    e.apresentado(950);
    e.responder(1150, 'pointer');
    e.responder(1200, 'keyboard');
    e.avancar(1950);
    e.avancar(2950);
    e.apresentado(3100);
    e.responder(3300, 'keyboard');
    e.avancar(4100);
    expect(e.completa, isTrue);
    final m = metricasVisuais(e.plano, e.ensaios, e.respostas, 4100);
    expect(m['respostas_validas'], 1);
    expect(m['media_reacao_ms'], 200);
    expect(m['toques_extras'], 1);
    expect(m['comissoes'], 1);
    expect(m['fora_estimulo'], 1);
    expect(m['maior_atraso_ms'], 150);
    expect(() => e.avancar(4000), throwsArgumentError);
  });
  test(
      'janela semiaberta; omissão somente após fechamento, sem antecipação inventada',
      () {
    final e = VisualEngine([
      {'kind': 'go', 'waitMs': 800},
    ]);
    e.avancar(800);
    e.apresentado(800);
    expect(
      metricasVisuais(e.plano, e.ensaios, e.respostas, 1000)['omissoes'],
      0,
    );
    e.avancar(1800);
    e.responder(1800, 'pointer');
    final m = metricasVisuais(e.plano, e.ensaios, e.respostas, 1800);
    expect(m['omissoes'], 1);
    expect(m['respostas_validas'], 0);
    expect(m['media_reacao_ms'], isNull);
  });
  test('percentis interpolados e DP populacional', () {
    final p = List.generate(4, (_) => {'kind': 'go', 'waitMs': 800});
    final tr = List.generate(
      4,
      (i) => {
        'seq': i + 1,
        'shownMs': 800 + i * 2000,
        'closedMs': 1800 + i * 2000,
      },
    );
    final r = List.generate(
      4,
      (i) => {'seq': i + 1, 'tMs': 900 + i * 2100, 'source': 'pointer'},
    );
    final m = metricasVisuais(p, tr, r, 7800);
    expect(m['mediana_reacao_ms'], 250);
    expect(m['media_reacao_ms'], 250);
    expect(m['p10_reacao_ms'], 130);
    expect(m['p90_reacao_ms'], 370);
    expect(m['dp_reacao_ms'], 111.8);
  });
}
