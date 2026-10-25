import 'modelos.dart';

/// Valida a sequência registrada e devolve a quantidade de acertos.
/// Instantes iguais são possíveis na resolução em milissegundos; regressões não.
int validarToques({
  required List<ToqueEvento> toques,
  required int n,
  required int duracaoMs,
}) {
  if (n < 4 || n > 99) {
    throw ArgumentError.value(n, 'n', 'deve estar entre 4 e 99');
  }
  if (duracaoMs < 0) {
    throw ArgumentError.value(duracaoMs, 'duracaoMs', 'não pode ser negativa');
  }

  var esperado = 1;
  var anteriorMs = 0;
  for (var i = 0; i < toques.length; i++) {
    final toque = toques[i];
    if (toque.seq != i + 1) {
      throw ArgumentError('toques fora de ordem: esperado seq ${i + 1}');
    }
    if (toque.tMs < anteriorMs || toque.tMs > duracaoMs) {
      throw ArgumentError('instante do toque inválido ou fora da duração');
    }
    if (esperado > n || toque.esperado != esperado) {
      throw ArgumentError('sequência esperada do toque inconsistente');
    }
    if (toque.tocado < 1 || toque.tocado > n) {
      throw ArgumentError('número tocado fora da grade');
    }
    anteriorMs = toque.tMs;
    if (toque.acerto) esperado++;
  }
  return esperado - 1;
}
