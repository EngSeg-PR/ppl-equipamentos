import 'modelos.dart';

/// Classifica as métricas com os limiares da configuração ativa
/// (campo `parametros` de `limiares_classificacao`). Nada é fixo no código.
///
/// Formato esperado:
/// ```json
/// { "regra": "pior_indicador", "incompleta": "vermelho",
///   "sequencia": { "duracao_ms": {"verde_ate": 90000, "amarelo_ate": 150000},
///                  "erros":      {"verde_ate": 5,     "amarelo_ate": 12} } }
/// ```
/// Valor <= verde_ate => verde; <= amarelo_ate => amarelo; acima => vermelho.
/// Lança [FormatException] se a configuração estiver malformada.
Faixa classificar({
  required Metricas metricas,
  required bool completa,
  required Map<String, dynamic> parametros,
}) {
  if (metricas.tempoTotalMs < 0 || metricas.erros < 0) {
    throw ArgumentError(
      'duração e quantidade de erros não podem ser negativas',
    );
  }
  final regra = parametros['regra'] ?? 'pior_indicador';
  if (regra != 'pior_indicador') {
    throw FormatException('regra de classificação não suportada: $regra');
  }

  final sequencia = parametros['sequencia'];
  if (sequencia is! Map) {
    throw const FormatException("limiares: falta o objeto 'sequencia'");
  }
  final duracao = _limites(sequencia['duracao_ms'], 'sequencia.duracao_ms');
  final erros = _limites(sequencia['erros'], 'sequencia.erros');
  final incompleta = _faixaDeTexto(parametros['incompleta'] ?? 'vermelho');

  if (!completa) return incompleta;

  final porDuracao = _faixaPorLimites(metricas.tempoTotalMs, duracao);
  final porErros = _faixaPorLimites(metricas.erros, erros);
  return porDuracao.index >= porErros.index ? porDuracao : porErros;
}

class _Limites {
  const _Limites(this.verdeAte, this.amareloAte);
  final num verdeAte;
  final num amareloAte;
}

_Limites _limites(Object? bruto, String nome) {
  if (bruto is! Map) {
    throw FormatException("limiares: falta '$nome'");
  }
  final verde = bruto['verde_ate'];
  final amarelo = bruto['amarelo_ate'];
  if (verde is! num || amarelo is! num) {
    throw FormatException(
      "limiares: '$nome' precisa de verde_ate e amarelo_ate numéricos",
    );
  }
  if (!verde.isFinite || !amarelo.isFinite || verde < 0 || amarelo < 0) {
    throw FormatException(
      "limiares: '$nome' precisa de valores finitos não negativos",
    );
  }
  if (verde > amarelo) {
    throw FormatException(
      "limiares: '$nome' tem verde_ate maior que amarelo_ate",
    );
  }
  return _Limites(verde, amarelo);
}

Faixa _faixaPorLimites(num valor, _Limites l) {
  if (valor <= l.verdeAte) return Faixa.verde;
  if (valor <= l.amareloAte) return Faixa.amarelo;
  return Faixa.vermelho;
}

Faixa _faixaDeTexto(Object? texto) {
  for (final f in Faixa.values) {
    if (f.name == texto) return f;
  }
  throw FormatException("limiares: faixa inválida em 'incompleta': $texto");
}
