/// Um estímulo do módulo opcional de tempo de reação.
class EventoReacao {
  const EventoReacao({
    required this.seq,
    required this.estimuloMs,
    this.respostaMs,
    this.antecipado = false,
    this.omissao = false,
  });

  final int seq;

  /// Instante do estímulo desde o início do módulo (relógio monotônico).
  final int estimuloMs;

  /// Tempo de reação; nulo em omissão.
  final int? respostaMs;
  final bool antecipado;
  final bool omissao;

  /// Reação válida: houve resposta, não foi antecipada e não é omissão.
  bool get valido => respostaMs != null && !antecipado && !omissao;

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'estimulo_ms': estimuloMs,
    if (respostaMs != null) 'resposta_ms': respostaMs,
    'antecipado': antecipado,
    'omissao': omissao,
  };
}

class MetricasReacao {
  const MetricasReacao({
    required this.mediaMs,
    required this.medianaMs,
    required this.omissoes,
    required this.antecipacoes,
  });

  /// Nulos quando não há nenhuma reação válida.
  final double? mediaMs;
  final double? medianaMs;
  final int omissoes;
  final int antecipacoes;

  Map<String, dynamic> toJson() => {
    'media_ms': mediaMs,
    'mediana_ms': medianaMs,
    'omissoes': omissoes,
    'antecipacoes': antecipacoes,
  };
}

MetricasReacao calcularMetricasReacao(List<EventoReacao> eventos) {
  var estimuloAnterior = 0;
  for (var i = 0; i < eventos.length; i++) {
    final evento = eventos[i];
    if (evento.seq != i + 1 || evento.estimuloMs < estimuloAnterior) {
      throw ArgumentError('estímulos de reação fora de ordem');
    }
    if ((evento.respostaMs != null && evento.respostaMs! < 0) ||
        (evento.omissao && (evento.respostaMs != null || evento.antecipado))) {
      throw ArgumentError('resposta de reação inconsistente');
    }
    estimuloAnterior = evento.estimuloMs;
  }

  final validos = [
    for (final e in eventos)
      if (e.valido) e.respostaMs!,
  ]..sort();

  double? media;
  double? mediana;
  if (validos.isNotEmpty) {
    media = validos.reduce((a, b) => a + b) / validos.length;
    final meio = validos.length ~/ 2;
    mediana = validos.length.isOdd
        ? validos[meio].toDouble()
        : (validos[meio - 1] + validos[meio]) / 2;
  }

  return MetricasReacao(
    mediaMs: media,
    medianaMs: mediana,
    omissoes: eventos.where((e) => e.omissao).length,
    antecipacoes: eventos.where((e) => e.antecipado).length,
  );
}
