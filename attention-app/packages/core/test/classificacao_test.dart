import 'dart:convert';

import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

Metricas m(int duracaoMs, int erros) => Metricas(
  tempoTotalMs: duracaoMs,
  tempoPrimeiroToqueMs: 500,
  erros: erros,
  mediaIntervaloMs: null,
  dpIntervaloMs: null,
  quartisMs: const [null, null, null, null],
);

// Tipos explícitos (<String, dynamic>) para que os testes possam alterar os mapas
// internos em tempo de execução sem esbarrar em tipos genéricos inferidos.
Map<String, dynamic> parametros() => <String, dynamic>{
  'regra': 'pior_indicador',
  'incompleta': 'vermelho',
  'sequencia': <String, dynamic>{
    'duracao_ms': <String, dynamic>{'verde_ate': 90000, 'amarelo_ate': 150000},
    'erros': <String, dynamic>{'verde_ate': 5, 'amarelo_ate': 12},
  },
};

Faixa c(Metricas metricas, {bool completa = true, Map<String, dynamic>? p}) =>
    classificar(
      metricas: metricas,
      completa: completa,
      parametros: p ?? parametros(),
    );

void main() {
  group('classificar', () {
    test('verde quando todos os indicadores estão dentro do verde', () {
      expect(c(m(80000, 3)), Faixa.verde);
    });

    test('amarelo quando o pior indicador é amarelo', () {
      expect(c(m(100000, 3)), Faixa.amarelo);
      expect(c(m(80000, 8)), Faixa.amarelo);
    });

    test(
      'vermelho quando algum indicador estoura o amarelo (regra do pior)',
      () {
        expect(c(m(80000, 13)), Faixa.vermelho);
        expect(c(m(160000, 0)), Faixa.vermelho);
        expect(c(m(100000, 13)), Faixa.vermelho);
      },
    );

    test('limites são inclusivos (<=)', () {
      expect(c(m(90000, 5)), Faixa.verde);
      expect(c(m(90001, 5)), Faixa.amarelo);
      expect(c(m(150000, 12)), Faixa.amarelo);
      expect(c(m(150001, 12)), Faixa.vermelho);
    });

    test(
      'sessão incompleta segue a faixa configurada, mesmo com bom desempenho',
      () {
        expect(c(m(1000, 0), completa: false), Faixa.vermelho);
        final p = parametros()..['incompleta'] = 'amarelo';
        expect(c(m(1000, 0), completa: false, p: p), Faixa.amarelo);
      },
    );

    test('sem a chave "incompleta", o padrão é vermelho', () {
      final p = parametros()..remove('incompleta');
      expect(c(m(1000, 0), completa: false, p: p), Faixa.vermelho);
    });

    test(
      'funciona com parâmetros vindos de jsonDecode (inteiros e decimais)',
      () {
        final p = jsonDecode('''
        {"regra": "pior_indicador", "incompleta": "vermelho",
         "sequencia": {"duracao_ms": {"verde_ate": 90000.5, "amarelo_ate": 150000},
                       "erros": {"verde_ate": 5, "amarelo_ate": 12}}}
      ''') as Map<String, dynamic>;
        expect(c(m(90000, 5), p: p), Faixa.verde);
      },
    );
  });

  group('configuração malformada', () {
    test('sem o objeto sequencia', () {
      final p = parametros()..remove('sequencia');
      expect(() => c(m(1, 0), p: p), throwsFormatException);
    });

    test('limite não numérico', () {
      final p = parametros();
      (p['sequencia'] as Map)['erros'] = {
        'verde_ate': 'cinco',
        'amarelo_ate': 12,
      };
      expect(() => c(m(1, 0), p: p), throwsFormatException);
    });

    test('verde_ate maior que amarelo_ate', () {
      final p = parametros();
      (p['sequencia'] as Map)['erros'] = {'verde_ate': 20, 'amarelo_ate': 12};
      expect(() => c(m(1, 0), p: p), throwsFormatException);
    });

    test('regra desconhecida', () {
      final p = parametros()..['regra'] = 'media_ponderada';
      expect(() => c(m(1, 0), p: p), throwsFormatException);
    });

    test('faixa inválida em incompleta', () {
      final p = parametros()..['incompleta'] = 'roxo';
      expect(() => c(m(1, 0), completa: false, p: p), throwsFormatException);
    });

    test('configuração ruim é detectada mesmo em sessão incompleta', () {
      final p = parametros()..remove('sequencia');
      expect(() => c(m(1, 0), completa: false, p: p), throwsFormatException);
    });

    test('limiares não finitos ou negativos não geram uma classificação', () {
      for (final limites in [
        [double.nan, 12],
        [double.infinity, 12],
        [-1, 12],
        [5, double.infinity],
        [5, double.nan],
      ]) {
        final p = parametros();
        (p['sequencia'] as Map)['erros'] = {
          'verde_ate': limites[0],
          'amarelo_ate': limites[1],
        };
        expect(() => c(m(1, 0), p: p), throwsFormatException);
      }
    });

    test('métricas negativas não geram uma classificação verde', () {
      expect(() => c(m(-1, 0)), throwsArgumentError);
      expect(() => c(m(1, -1)), throwsArgumentError);
    });
  });
}
