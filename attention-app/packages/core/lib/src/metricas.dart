import 'dart:math';

import 'modelos.dart';
import 'reacao.dart';
import 'validacao_toques.dart';

/// Calcula as métricas da sequência 1..[n].
///
/// Definições (fixas, para evitar ambiguidade):
/// * erro: toque diferente do esperado (a sequência não avança);
/// * intervalo: tempo entre dois acertos consecutivos;
/// * quartos: blocos de números com bordas ceil(i * n / 4); o tempo de um bloco é
///   o instante do acerto do último número do bloco menos o do bloco anterior
///   (0 para o primeiro). Bloco não concluído = null.
Metricas calcularMetricas({
  required List<ToqueEvento> toques,
  required int n,
  required int duracaoMs,
  MetricasReacao? reacao,
}) {
  validarToques(toques: toques, n: n, duracaoMs: duracaoMs);

  final acertos = toques.where((t) => t.acerto).toList();
  final erros = toques.length - acertos.length;
  final primeiro = toques.isEmpty ? null : toques.first.tMs;

  final intervalos = <int>[
    for (var i = 1; i < acertos.length; i++)
      acertos[i].tMs - acertos[i - 1].tMs,
  ];

  double? media;
  double? dp;
  if (intervalos.isNotEmpty) {
    final m = intervalos.reduce((a, b) => a + b) / intervalos.length;
    final soma = intervalos.fold<double>(
      0,
      (acc, x) => acc + (x - m) * (x - m),
    );
    media = m;
    dp = sqrt(soma / intervalos.length);
  }

  final tempoDoNumero = <int, int>{for (final a in acertos) a.esperado: a.tMs};
  final bordas = [for (var i = 0; i <= 4; i++) (i * n / 4).ceil()];
  final quartis = <int?>[];
  for (var i = 0; i < 4; i++) {
    final fim = tempoDoNumero[bordas[i + 1]];
    final ini = bordas[i] == 0 ? 0 : tempoDoNumero[bordas[i]];
    quartis.add((fim == null || ini == null) ? null : fim - ini);
  }

  return Metricas(
    tempoTotalMs: duracaoMs,
    tempoPrimeiroToqueMs: primeiro,
    erros: erros,
    mediaIntervaloMs: media,
    dpIntervaloMs: dp,
    quartisMs: List.unmodifiable(quartis),
    reacao: reacao,
  );
}
