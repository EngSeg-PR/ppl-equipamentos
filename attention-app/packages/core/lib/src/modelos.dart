import 'reacao.dart';

/// Faixa do semáforo. A ordem importa: quanto maior o índice, pior.
enum Faixa { verde, amarelo, vermelho }

enum StatusSessao { completa, incompleta }

enum Momento { inicio, durante }

/// Um toque na grade. O acerto é derivado: tocado == esperado.
class ToqueEvento {
  const ToqueEvento({
    required this.seq,
    required this.tMs,
    required this.tocado,
    required this.esperado,
  });

  /// Ordem do toque na sessão, começando em 1 (erros também contam).
  final int seq;

  /// Milissegundos desde a exibição da grade (relógio monotônico).
  final int tMs;
  final int tocado;
  final int esperado;

  bool get acerto => tocado == esperado;

  Map<String, dynamic> toJson() => {
    'seq': seq,
    't_ms': tMs,
    'tocado': tocado,
    'esperado': esperado,
    'acerto': acerto,
  };
}

double? _umaCasa(double? v) => v == null ? null : (v * 10).round() / 10;

/// Métricas de uma sessão (contrato com o campo `sessao.metricas` do servidor).
class Metricas {
  const Metricas({
    required this.tempoTotalMs,
    required this.tempoPrimeiroToqueMs,
    required this.erros,
    required this.mediaIntervaloMs,
    required this.dpIntervaloMs,
    required this.quartisMs,
    this.reacao,
  });

  final int tempoTotalMs;
  final int? tempoPrimeiroToqueMs;
  final int erros;

  /// Média dos intervalos entre acertos consecutivos. Nulo com menos de 2 acertos.
  final double? mediaIntervaloMs;

  /// Desvio-padrão populacional desses intervalos.
  final double? dpIntervaloMs;

  /// Tempo gasto em cada quarto da sequência; nulo para quartos não concluídos.
  final List<int?> quartisMs;
  final MetricasReacao? reacao;

  Map<String, dynamic> toJson() => {
    'tempo_total_ms': tempoTotalMs,
    'tempo_primeiro_toque_ms': tempoPrimeiroToqueMs,
    'erros': erros,
    'media_intervalo_ms': _umaCasa(mediaIntervaloMs),
    'dp_intervalo_ms': _umaCasa(dpIntervaloMs),
    'quartis_ms': List<int?>.of(quartisMs),
    if (reacao != null) 'reacao': reacao!.toJson(),
  };
}
