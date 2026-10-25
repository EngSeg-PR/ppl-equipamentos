import 'dart:math';

import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

void main() {
  group('gerarGrade', () {
    test('gera uma permutação de 1..36 por padrão', () {
      final g = gerarGrade(random: Random(1));
      expect(g.length, 36);
      expect(g.toSet(), {for (var i = 1; i <= 36; i++) i});
      expect(gradeValida(g), isTrue);
    });

    test('duas aplicações seguidas não repetem a mesma ordem', () {
      final rng = Random(7);
      final a = gerarGrade(random: rng);
      final b = gerarGrade(random: rng);
      expect(a, isNot(equals(b)));
    });

    test('embaralha de verdade: o número 1 cai em todas as posições com frequência parecida', () {
      final rng = Random(42);
      const rodadas = 20000;
      final contagem = List<int>.filled(36, 0);
      for (var i = 0; i < rodadas; i++) {
        contagem[gerarGrade(random: rng).indexOf(1)]++;
      }
      const esperado = rodadas / 36; // ~555,6; desvio-padrão ~23
      for (final c in contagem) {
        expect(c, inInclusiveRange(esperado - 125, esperado + 125));
      }
    });

    test('sem Random informado usa o modo seguro e continua válido', () {
      expect(gradeValida(gerarGrade()), isTrue);
    });

    test('aceita outros tamanhos dentro de 4..99', () {
      expect(gerarGrade(n: 4, random: Random(1)).length, 4);
      expect(gerarGrade(n: 99, random: Random(1)).length, 99);
    });

    test('rejeita tamanho fora do intervalo', () {
      expect(() => gerarGrade(n: 3), throwsArgumentError);
      expect(() => gerarGrade(n: 100), throwsArgumentError);
    });
  });

  group('gradeValida', () {
    test('aceita permutação', () => expect(gradeValida([3, 1, 4, 2]), isTrue));
    test(
      'rejeita duplicados',
      () => expect(gradeValida([1, 1, 3, 4]), isFalse),
    );
    test(
      'rejeita número fora de 1..n',
      () => expect(gradeValida([1, 2, 3, 5]), isFalse),
    );
    test(
      'rejeita menos de 4 posições',
      () => expect(gradeValida([1, 2, 3]), isFalse),
    );
    test('rejeita mais de 99 posições', () {
      expect(gradeValida(List<int>.generate(100, (i) => i + 1)), isFalse);
    });
  });
}
