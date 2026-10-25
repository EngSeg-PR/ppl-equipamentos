import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

void main() {
  final grade = [3, 1, 4, 2];

  test('fluxo completo com um erro', () {
    final e = SequenciaEngine(grade: grade, tempoMaximoMs: 10000);
    expect(e.esperado, 1);
    expect(e.registrarToque(1, 500)!.acerto, isTrue);

    final erro = e.registrarToque(3, 900)!; // esperado era 2
    expect(erro.acerto, isFalse);
    expect(erro.esperado, 2);
    expect(e.esperado, 2); // erro não avança a sequência

    e.registrarToque(2, 1200);
    e.registrarToque(3, 1500);
    expect(e.concluida, isFalse);
    e.registrarToque(4, 2000);
    expect(e.concluida, isTrue);

    final r = e.fechar(2500);
    expect(r.status, StatusSessao.completa);
    expect(r.duracaoMs, 2000); // instante do último acerto
    expect(r.metricas.erros, 1);
    expect(r.toques.map((t) => t.seq), [1, 2, 3, 4, 5]);
  });

  test('toques após a conclusão são ignorados', () {
    final e = SequenciaEngine(grade: grade);
    for (var i = 1; i <= 4; i++) {
      e.registrarToque(i, i * 100);
    }
    expect(e.concluida, isTrue);
    expect(e.registrarToque(1, 900), isNull);
    expect(e.toques.length, 4);
  });

  test('toque com tempo esgotado é ignorado e fechar limita a duração', () {
    final e = SequenciaEngine(grade: grade, tempoMaximoMs: 1000);
    expect(e.registrarToque(1, 400), isNotNull);
    expect(e.tempoEsgotado(1000), isTrue);
    expect(e.registrarToque(2, 1000), isNull);

    final r = e.fechar(5000);
    expect(r.status, StatusSessao.incompleta);
    expect(r.duracaoMs, 1000);
    expect(r.toques.length, 1);
  });

  test('fechar antes do limite devolve o tempo informado', () {
    final e = SequenciaEngine(grade: grade, tempoMaximoMs: 10000);
    e.registrarToque(1, 300);
    final r = e.fechar(700);
    expect(r.status, StatusSessao.incompleta);
    expect(r.duracaoMs, 700);
  });

  test('depois de fechada, ignora novos toques', () {
    final e = SequenciaEngine(grade: grade);
    e.registrarToque(1, 100);
    e.fechar(200);
    expect(e.fechada, isTrue);
    expect(e.registrarToque(2, 250), isNull);
  });

  test('número fora da grade lança erro', () {
    final e = SequenciaEngine(grade: grade);
    expect(() => e.registrarToque(9, 10), throwsArgumentError);
  });

  test('grade inválida ou tempo inválido lançam erro no construtor', () {
    expect(() => SequenciaEngine(grade: [1, 1, 2, 3]), throwsArgumentError);
    expect(
      () => SequenciaEngine(grade: grade, tempoMaximoMs: 0),
      throwsArgumentError,
    );
  });

  test('não aceita relógio negativo ou regressão entre eventos', () {
    final e = SequenciaEngine(grade: grade);
    expect(() => e.registrarToque(1, -1), throwsArgumentError);
    e.registrarToque(1, 100);
    expect(() => e.registrarToque(2, 99), throwsArgumentError);
    expect(e.toques.length, 1);
    // Dois eventos podem ter o mesmo instante na resolução em milissegundos.
    expect(e.registrarToque(2, 100), isNotNull);
    expect(() => e.fechar(99), throwsArgumentError);
    expect(e.fechada, isFalse);
  });

  test('fechamento repetido preserva a duração e o resultado original', () {
    final e = SequenciaEngine(grade: grade);
    e.registrarToque(1, 100);
    final primeiro = e.fechar(200);
    expect(identical(e.fechar(900), primeiro), isTrue);
    expect(e.fechar(900).duracaoMs, 200);
    expect(() => primeiro.toques.clear(), throwsUnsupportedError);
    expect(() => primeiro.metricas.quartisMs.clear(), throwsUnsupportedError);
  });

  test('após detectar tempo esgotado não aceita um instante anterior', () {
    final e = SequenciaEngine(grade: grade, tempoMaximoMs: 1000);
    e.registrarToque(1, 200);
    expect(e.registrarToque(2, 1000), isNull);
    expect(() => e.registrarToque(2, 900), throwsArgumentError);
    expect(e.fechar(1000).duracaoMs, 1000);
  });
}
