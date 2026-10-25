import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:triagem_core/triagem_core.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../data/portal_api.dart';
import '../ensaio/ensaio_controller.dart' show RelogioEnsaio, RelogioStopwatch;

enum TelaHistorico {
  inicio,
  treino,
  pronto,
  preparando,
  teste,
  salvando,
  resultado,
  historico
}

class HistoricoController extends ChangeNotifier {
  HistoricoController(
      {required this.repositorio,
      required this.portal,
      RelogioEnsaio? relogio,
      List<int> Function(int)? criarGrade,
      this.sincronizacaoAutomatica = true})
      : relogio = relogio ?? RelogioStopwatch(),
        criarGrade = criarGrade ?? ((n) => gerarGrade(n: n));
  final RepositorioHistorico repositorio;
  final ServicoPortal portal;
  final RelogioEnsaio relogio;
  final List<int> Function(int) criarGrade;
  final bool sincronizacaoAutomatica;
  ContextoAtencao? contexto;
  List<AvaliacaoLocal> registros = [];
  AvaliacaoLocal? atual;
  Map<String, dynamic>? colaborador;
  String unidade = '', equipe = '';
  Momento momento = Momento.inicio;
  TelaHistorico tela = TelaHistorico.inicio;
  String? erro, aviso;
  bool ocupado = false,
      offline = false,
      sincronizando = false,
      cronometroIniciado = false,
      salvo = false;
  SequenciaEngine? _engine;
  Timer? _timer, _retry;
  Future<void> _escritas = Future.value();
  bool _vivo = true;
  int _epoch = 0;
  final Map<String, DateTime> _retentarEm = {};
  final Map<String, int> _tentativas = {};
  void _avisar() {
    if (_vivo) notifyListeners();
  }

  bool get emAvaliacao => [
        TelaHistorico.preparando,
        TelaHistorico.teste,
        TelaHistorico.salvando
      ].contains(tela);
  List<int> get grade => _engine?.grade ?? const [];
  int get proximo => _engine?.esperado ?? 1;
  int get acertos => (proximo - 1).clamp(0, grade.length).toInt();
  int get segundosRestantes =>
      ((180000 - relogio.milissegundos.clamp(0, 180000)) / 1000).ceil();

  Future<void> iniciar() async {
    ocupado = true;
    erro = null;
    _avisar();
    try {
      if (await portal.restaurar()) await _carregarContexto();
    } catch (e) {
      erro = e.toString();
    } finally {
      ocupado = false;
      _avisar();
    }
    if (sincronizacaoAutomatica) {
      _retry ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (contexto != null) unawaited(sincronizar());
      });
      if (contexto != null) unawaited(sincronizar());
    }
  }

  Future<void> entrar(String email, String senha) async {
    if (ocupado) return;
    ocupado = true;
    erro = null;
    ++_epoch;
    _avisar();
    try {
      await portal.entrar(email, senha);
      await _carregarContexto();
    } catch (e) {
      erro = e.toString();
      contexto = null;
      registros = [];
      await portal.sair();
    } finally {
      ocupado = false;
      _avisar();
    }
    if (sincronizacaoAutomatica && contexto != null) unawaited(sincronizar());
  }

  Future<void> _carregarContexto([String? empresa]) async {
    final epoch = _epoch;
    final uid = portal.usuarioId;
    if (uid == null) throw const ErroPortal('Entre com sua conta.', 401);
    final last =
        empresa ?? await repositorio.cofre.ler('prs_attention_company_$uid');
    ContextoAtencao loaded;
    try {
      loaded = await portal.contexto(last);
      offline = false;
    } on ErroPortal catch (e) {
      if ((e.status != 0 && e.status < 500) || last == null) rethrow;
      final cached = await repositorio.lerContexto('$uid/$last');
      if (cached == null) rethrow;
      loaded = cached;
      offline = true;
    }
    if (epoch != _epoch || loaded.usuarioId != uid) {
      throw const ErroPortal('Sessão alterada.', 401);
    }
    if (!offline) await repositorio.salvarContexto(loaded);
    await repositorio.cofre
        .gravar('prs_attention_company_$uid', loaded.empresaId);
    final saved = await repositorio.listar(loaded.escopo);
    for (final item in saved.where((a) => a.emAndamento)) {
      await repositorio.salvar(item.recuperarInterrompida());
    }
    if (epoch != _epoch) return;
    contexto = loaded;
    registros = await repositorio.listar(loaded.escopo);
    tela = TelaHistorico.inicio;
    colaborador = null;
    aviso = offline
        ? 'Modo offline: cadastro do último acesso. O servidor ainda precisa confirmar os envios.'
        : null;
  }

  Future<void> trocarEmpresa(String id) async {
    if (emAvaliacao || ocupado || sincronizando) return;
    ocupado = true;
    erro = null;
    ++_epoch;
    _avisar();
    try {
      await _carregarContexto(id);
    } catch (e) {
      erro = e.toString();
    } finally {
      ocupado = false;
      _avisar();
    }
  }

  Future<void> sair() async {
    if (emAvaliacao || ocupado || sincronizando) return;
    ++_epoch;
    contexto = null;
    registros = [];
    atual = null;
    colaborador = null;
    erro = null;
    aviso = null;
    tela = TelaHistorico.inicio;
    await portal.sair();
    _avisar();
  }

  bool praticar(String employeeId, String unit, String team, Momento jornada) {
    final ctx = contexto;
    if (ctx == null || ocupado || emAvaliacao) return false;
    final people = ctx.colaboradores.where((e) => e['id'] == employeeId);
    if (people.isEmpty || unit.trim().isEmpty || team.trim().isEmpty) {
      erro = 'Selecione colaborador, unidade e equipe.';
      _avisar();
      return false;
    }
    if (ctx.escopos != null &&
        !ctx.escopos!.any((s) => s['unit'] == unit && s['team'] == team)) {
      erro = 'Unidade e equipe fora deste acesso.';
      _avisar();
      return false;
    }
    colaborador = people.single;
    unidade = unit.trim();
    equipe = team.trim();
    momento = jornada;
    _engine = SequenciaEngine(grade: criarGrade(9), tempoMaximoMs: 3600000);
    relogio.iniciar();
    atual = null;
    salvo = false;
    erro = null;
    tela = TelaHistorico.treino;
    _avisar();
    return true;
  }

  Future<void> _gravar(AvaliacaoLocal item) {
    final next = _escritas.then((_) => repositorio.salvar(item));
    _escritas = next.catchError((Object _) {});
    return next;
  }

  Future<void> preparar() async {
    if (tela != TelaHistorico.pronto ||
        contexto == null ||
        colaborador == null) {
      return;
    }
    tela = TelaHistorico.preparando;
    erro = null;
    _avisar();
    final now = DateTime.now().toUtc();
    _engine = SequenciaEngine(grade: criarGrade(36));
    cronometroIniciado = false;
    atual = AvaliacaoLocal({
      'id': novoId(),
      'userId': contexto!.usuarioId,
      'companyId': contexto!.empresaId,
      'companyName': contexto!.nomeEmpresa,
      'employeeId': colaborador!['id'],
      'employeeSnapshot': {...colaborador!},
      'unit': unidade,
      'team': equipe,
      'moment': momento.name,
      'startedAt': now.toIso8601String(),
      'checkpointAt': now.toIso8601String(),
      'finishedAt': null,
      'status': 'em_andamento',
      'durationMs': 0,
      'grid': [...grade],
      'touches': <Map<String, dynamic>>[],
      'metrics': AvaliacaoLocal.metricasDe([], grade, 0),
      'protocolVersion': 'sequencia-v1',
      'appVersion': '0.2.0',
      'syncState': SituacaoEnvio.pendente.name,
    });
    try {
      await _gravar(atual!);
      tela = TelaHistorico.teste;
    } catch (e) {
      erro = 'Não foi possível iniciar com gravação segura: $e';
      tela = TelaHistorico.pronto;
      atual = null;
    }
    _avisar();
  }

  void iniciarCronometro() {
    if (tela != TelaHistorico.teste || cronometroIniciado) return;
    relogio.iniciar();
    cronometroIniciado = true;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (relogio.milissegundos >= 180000) {
        unawaited(concluir('Tempo máximo atingido'));
      } else {
        _avisar();
      }
    });
    _avisar();
  }

  AvaliacaoLocal _checkpoint([String? status, int? duration]) {
    final elapsed = duration ?? relogio.milissegundos.clamp(0, 180000).toInt();
    final item = atual!;
    return item.alterar({
      'durationMs': elapsed,
      'checkpointAt':
          item.inicio.add(Duration(milliseconds: elapsed)).toIso8601String(),
      'touches': [
        for (final t in _engine!.toques)
          {
            'seq': t.seq,
            'tMs': t.tMs,
            'touched': t.tocado,
            'expected': t.esperado,
            'correct': t.acerto
          }
      ],
      'metrics': AvaliacaoLocal.metricasDe(_engine!.toques, grade, elapsed),
      if (status != null) 'status': status,
    });
  }

  void tocar(int numero) {
    if (tela == TelaHistorico.treino) {
      _engine!.registrarToque(numero, relogio.milissegundos);
      if (_engine!.concluida) {
        relogio.parar();
        _engine = null;
        tela = TelaHistorico.pronto;
      }
      _avisar();
      return;
    }
    if (tela != TelaHistorico.teste || !cronometroIniciado) return;
    if (relogio.milissegundos >= 180000) {
      unawaited(concluir('Tempo máximo atingido'));
      return;
    }
    _engine!.registrarToque(numero, relogio.milissegundos);
    atual = _checkpoint();
    unawaited(_gravar(atual!).catchError((Object e) {
      erro =
          'Falha ao salvar um toque. O trecho disponível será preservado: $e';
      if (tela == TelaHistorico.teste) {
        unawaited(concluir('Interrupção por falha de armazenamento'));
      }
      _avisar();
    }));
    if (_engine!.concluida) {
      unawaited(concluir());
    } else if (_engine!.toques.length >= 2000) {
      unawaited(concluir('Limite de toques do protocolo atingido'));
    }
    _avisar();
  }

  Future<void> concluir([String? motivo]) async {
    if (tela != TelaHistorico.teste) return;
    _timer?.cancel();
    relogio.parar();
    final result =
        _engine!.fechar(cronometroIniciado ? relogio.milissegundos : 0);
    atual = _checkpoint(result.status.name, result.duracaoMs);
    atual = atual!.alterar(
        {'finishedAt': atual!.json['checkpointAt'], 'interruption': motivo});
    tela = TelaHistorico.salvando;
    _avisar();
    await tentarSalvar();
  }

  Future<void> tentarSalvar() async {
    if (tela != TelaHistorico.salvando || ocupado || atual == null) return;
    ocupado = true;
    erro = null;
    _avisar();
    try {
      await _gravar(atual!);
      salvo = true;
      erro = null;
      registros = await repositorio.listar(atual!.escopo);
      tela = TelaHistorico.resultado;
    } catch (e) {
      erro =
          'O salvamento ainda não foi confirmado. Mantenha esta tela aberta e tente novamente. $e';
    } finally {
      ocupado = false;
      _avisar();
    }
    if (salvo && sincronizacaoAutomatica) unawaited(sincronizar());
  }

  void interromper() {
    if (tela == TelaHistorico.teste) {
      unawaited(concluir('Avaliação interrompida'));
    } else if (tela == TelaHistorico.treino) {
      relogio.parar();
      _engine = null;
      tela = TelaHistorico.inicio;
      _avisar();
    }
  }

  void abrirHistorico() {
    if (emAvaliacao) return;
    tela = TelaHistorico.historico;
    _avisar();
  }

  void voltar() {
    if (emAvaliacao || (atual != null && !salvo)) return;
    atual = null;
    _engine = null;
    tela = TelaHistorico.inicio;
    erro = null;
    _avisar();
  }

  Future<void> sincronizar({bool manual = false}) async {
    final ctx = contexto;
    if (ctx == null || sincronizando) return;
    final epoch = _epoch;
    sincronizando = true;
    _avisar();
    try {
      for (final original in await repositorio.listar(ctx.escopo)) {
        if (epoch != _epoch || portal.usuarioId != ctx.usuarioId) break;
        if (original.emAndamento || original.envio != SituacaoEnvio.pendente) {
          continue;
        }
        if (!manual &&
            (_retentarEm[original.id]?.isAfter(DateTime.now()) ?? false)) {
          continue;
        }
        AvaliacaoLocal updated;
        try {
          final response = await portal.enviar(original);
          if (epoch != _epoch) break;
          if (!['ok', 'duplicada'].contains(response['status']) ||
              response['id'] != original.id ||
              (response['moduleVersion'] as num? ?? 0) < 51) {
            throw const ErroPortal(
                'O servidor não confirmou a avaliação correta.', 503);
          }
          updated = original.alterar({
            'syncState': SituacaoEnvio.sincronizado.name,
            'syncError': null,
            'receivedAt': response['received_at']
          });
          _tentativas.remove(original.id);
          _retentarEm.remove(original.id);
        } on ErroPortal catch (e) {
          if (epoch != _epoch) break;
          updated = original.alterar({
            'syncState': (e.permanente
                    ? SituacaoEnvio.falhaPermanente
                    : SituacaoEnvio.pendente)
                .name,
            'syncError': e.mensagem
          });
          final count = (_tentativas[original.id] ?? 0) + 1;
          _tentativas[original.id] = count;
          _retentarEm[original.id] = DateTime.now().add(
              Duration(seconds: min(900, 10 * pow(2, min(count, 6)).toInt())));
        }
        await _gravar(updated);
        if (atual?.id == updated.id) atual = updated;
      }
      if (epoch == _epoch) {
        registros = await repositorio.listar(ctx.escopo);
        aviso =
            'Consulta de envios concluída. Confira a situação de cada avaliação.';
      }
    } catch (e) {
      if (epoch == _epoch) erro = 'Não foi possível confirmar os envios: $e';
    } finally {
      sincronizando = false;
      _avisar();
    }
  }

  @override
  void dispose() {
    _vivo = false;
    _timer?.cancel();
    _retry?.cancel();
    relogio.parar();
    super.dispose();
  }
}
