import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:triagem_core/triagem_core.dart';

enum EtapaEnsaio { inicio, identificacao, treino, pronto, teste, resultado }

/// Relógio monotônico injetável, para verificar timeout sem esperar três minutos.
abstract interface class RelogioEnsaio {
  int get milissegundos;
  void iniciar();
  void parar();
}

class RelogioStopwatch implements RelogioEnsaio {
  final Stopwatch _relogio = Stopwatch();

  @override
  int get milissegundos => _relogio.elapsedMilliseconds;

  @override
  void iniciar() => _relogio
    ..reset()
    ..start();

  @override
  void parar() => _relogio.stop();
}

/// Estado transitório: nada é persistido ou preparado para envio ao servidor.
class EnsaioController extends ChangeNotifier {
  EnsaioController({
    RelogioEnsaio? relogio,
    List<int> Function(int)? criarGrade,
  })  : _relogio = relogio ?? RelogioStopwatch(),
        _criarGrade = criarGrade ?? ((n) => gerarGrade(n: n));

  static const tempoMaximoMs = 180000;
  final RelogioEnsaio _relogio;
  final List<int> Function(int) _criarGrade;
  Timer? _timer;
  SequenciaEngine? _engine;
  EtapaEnsaio etapa = EtapaEnsaio.inicio;
  String participante = '';
  Momento momento = Momento.inicio;
  ResultadoSequencia? resultado;
  String? motivoInterrupcao;
  bool relogioIniciado = false;
  bool ultimoToqueIncorreto = false;

  List<int> get grade => _engine?.grade ?? const [];
  int get proximo => _engine?.esperado ?? 1;
  int get tempoDecorridoMs => relogioIniciado
      ? _relogio.milissegundos.clamp(0, tempoMaximoMs).toInt()
      : 0;
  int get segundosRestantes =>
      ((tempoMaximoMs - tempoDecorridoMs) / 1000).ceil();
  int get acertos => (proximo - 1).clamp(0, grade.length).toInt();

  void abrirIdentificacao() {
    if (etapa != EtapaEnsaio.inicio) return;
    etapa = EtapaEnsaio.identificacao;
    notifyListeners();
  }

  bool iniciarTreino(String codigo, Momento jornada, {required bool ciencia}) {
    if (etapa != EtapaEnsaio.identificacao || !ciencia) return false;
    final normalizado = codigo.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2,8}-[0-9]{2,6}$').hasMatch(normalizado)) return false;
    participante = normalizado;
    momento = jornada;
    etapa = EtapaEnsaio.treino;
    _engine = SequenciaEngine(grade: _criarGrade(9), tempoMaximoMs: 3600000);
    ultimoToqueIncorreto = false;
    _relogio.iniciar();
    notifyListeners();
    return true;
  }

  void prepararTeste() {
    if (etapa != EtapaEnsaio.pronto) return;
    _engine = SequenciaEngine(
      grade: _criarGrade(36),
      tempoMaximoMs: tempoMaximoMs,
    );
    resultado = null;
    motivoInterrupcao = null;
    ultimoToqueIncorreto = false;
    relogioIniciado = false;
    etapa = EtapaEnsaio.teste;
    notifyListeners();
  }

  /// Chamado após a primeira grade ser desenhada, nunca ao pressionar Iniciar.
  void iniciarCronometro() {
    if (etapa != EtapaEnsaio.teste || relogioIniciado) return;
    _relogio.iniciar();
    relogioIniciado = true;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => atualizarTempo(),
    );
    notifyListeners();
  }

  void atualizarTempo() {
    if (etapa != EtapaEnsaio.teste || !relogioIniciado) return;
    if (_engine!.tempoEsgotado(_relogio.milissegundos)) {
      _finalizar('Tempo máximo atingido');
    } else {
      notifyListeners();
    }
  }

  void tocar(int numero) {
    if (etapa != EtapaEnsaio.treino && etapa != EtapaEnsaio.teste) return;
    if (etapa == EtapaEnsaio.teste && !relogioIniciado) return;
    if (etapa == EtapaEnsaio.teste &&
        _engine!.tempoEsgotado(_relogio.milissegundos)) {
      _finalizar('Tempo máximo atingido');
      return;
    }
    final evento = _engine!.registrarToque(numero, _relogio.milissegundos);
    if (evento == null) return;
    ultimoToqueIncorreto = !evento.acerto;
    if (_engine!.concluida) {
      if (etapa == EtapaEnsaio.treino) {
        // O treino é descartado; não participa das métricas do ensaio.
        _relogio.parar();
        _engine = null;
        etapa = EtapaEnsaio.pronto;
        notifyListeners();
      } else {
        _finalizar(null);
      }
      return;
    }
    notifyListeners();
  }

  void interromper([String motivo = 'Ensaio interrompido pelo participante']) {
    if (etapa == EtapaEnsaio.teste) {
      _finalizar(motivo);
    } else if (etapa == EtapaEnsaio.treino) {
      _relogio.parar();
      _engine = null;
      etapa = EtapaEnsaio.identificacao;
      notifyListeners();
    }
  }

  void _finalizar(String? motivo) {
    if (etapa != EtapaEnsaio.teste) return;
    _timer?.cancel();
    _timer = null;
    _relogio.parar();
    resultado = _engine!.fechar(relogioIniciado ? _relogio.milissegundos : 0);
    motivoInterrupcao = motivo;
    etapa = EtapaEnsaio.resultado;
    notifyListeners();
  }

  void apagarEReiniciar() {
    _timer?.cancel();
    _timer = null;
    _relogio.parar();
    _engine = null;
    participante = '';
    momento = Momento.inicio;
    resultado = null;
    motivoInterrupcao = null;
    relogioIniciado = false;
    ultimoToqueIncorreto = false;
    etapa = EtapaEnsaio.inicio;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _relogio.parar();
    super.dispose();
  }
}
