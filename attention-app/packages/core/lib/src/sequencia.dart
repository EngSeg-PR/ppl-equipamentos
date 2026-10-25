import 'grade.dart';
import 'metricas.dart';
import 'modelos.dart';

class ResultadoSequencia {
  const ResultadoSequencia({
    required this.status,
    required this.duracaoMs,
    required this.toques,
    required this.metricas,
  });

  final StatusSessao status;
  final int duracaoMs;
  final List<ToqueEvento> toques;
  final Metricas metricas;
}

/// Máquina de estados do teste de sequência. Não conhece relógio: a interface
/// informa o instante de cada toque (ms desde a exibição da grade, Stopwatch).
class SequenciaEngine {
  SequenciaEngine({required List<int> grade, this.tempoMaximoMs = 180000})
    : grade = List.unmodifiable(grade) {
    if (!gradeValida(grade)) {
      throw ArgumentError.value(
        grade,
        'grade',
        'precisa ser permutação de 1..n (4 <= n <= 99)',
      );
    }
    if (tempoMaximoMs <= 0) {
      throw ArgumentError.value(
        tempoMaximoMs,
        'tempoMaximoMs',
        'deve ser positivo',
      );
    }
  }

  final List<int> grade;
  final int tempoMaximoMs;

  final List<ToqueEvento> _toques = [];
  int _esperado = 1;
  int _ultimoInstanteMs = 0;
  ResultadoSequencia? _resultado;

  int get n => grade.length;

  /// Próximo número que o condutor deve tocar.
  int get esperado => _esperado;

  bool get concluida => _esperado > n;
  bool get fechada => _resultado != null;
  List<ToqueEvento> get toques => List.unmodifiable(_toques);

  bool tempoEsgotado(int tMs) => tMs >= tempoMaximoMs;

  /// Registra um toque e devolve o evento; devolve null se o toque deve ser
  /// ignorado (teste já concluído/fechado ou tempo esgotado).
  ToqueEvento? registrarToque(int numero, int tMs) {
    if (fechada || concluida) return null;
    if (!grade.contains(numero)) {
      throw ArgumentError.value(numero, 'numero', 'não está na grade');
    }
    _validarInstante(tMs);
    _ultimoInstanteMs = tMs;
    if (tempoEsgotado(tMs)) return null;

    final evento = ToqueEvento(
      seq: _toques.length + 1,
      tMs: tMs,
      tocado: numero,
      esperado: _esperado,
    );
    _toques.add(evento);
    if (evento.acerto) _esperado++;
    return evento;
  }

  /// Fecha a sessão (ao concluir ou quando o tempo acabar) e calcula o resultado.
  /// Duração: instante do último acerto se concluída; senão o tempo informado,
  /// limitado ao tempo máximo.
  ResultadoSequencia fechar(int tMs) {
    final anterior = _resultado;
    if (anterior != null) return anterior;
    _validarInstante(tMs);
    final completa = concluida;
    final duracao = completa
        ? _toques.last.tMs
        : (tMs < tempoMaximoMs ? tMs : tempoMaximoMs);
    final toques = List<ToqueEvento>.unmodifiable(_toques);
    return _resultado = ResultadoSequencia(
      status: completa ? StatusSessao.completa : StatusSessao.incompleta,
      duracaoMs: duracao,
      toques: toques,
      metricas: calcularMetricas(toques: toques, n: n, duracaoMs: duracao),
    );
  }

  void _validarInstante(int tMs) {
    if (tMs < _ultimoInstanteMs) {
      throw ArgumentError.value(
        tMs,
        'tMs',
        'deve ser não negativo e manter a ordem do relógio monotônico',
      );
    }
  }
}
