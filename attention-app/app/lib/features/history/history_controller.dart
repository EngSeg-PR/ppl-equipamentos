import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:triagem_core/triagem_core.dart';

import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../data/portal_api.dart';
import '../../data/employee_access.dart';
import '../ensaio/ensaio_controller.dart'
    show RelogioEnsaio, RelogioStopwatch, RelogioPreciso;

enum TelaHistorico {
  inicio,
  demonstracao,
  treino,
  pronto,
  preparando,
  teste,
  salvando,
  resultado,
  historico,
}

class HistoricoController extends ChangeNotifier {
  HistoricoController({
    required this.repositorio,
    required this.portal,
    RelogioEnsaio? relogio,
    List<int> Function(int)? criarGrade,
    this.sincronizacaoAutomatica = true,
    this.usarVisual = true,
  }) : relogio = relogio ?? RelogioStopwatch(),
       criarGrade = criarGrade ?? ((n) => gerarGrade(n: n));
  final RepositorioHistorico repositorio;
  final ServicoPortal portal;
  final RelogioEnsaio relogio;
  final List<int> Function(int) criarGrade;
  final bool sincronizacaoAutomatica;
  final bool usarVisual;
  VisualEngine? visual;
  String? feedbackTreino;
  bool _interrompidoAoPreparar = false;
  ContextoAtencao? contexto;
  List<AvaliacaoLocal> registros = [];
  bool carregandoHistorico = false;
  int? proximoOffsetHistorico;
  bool get aceitaColaborador => portal is AcessoColaborador;
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
  Timer? _timer, _retry, _limiteAplicacao;
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
    TelaHistorico.salvando,
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

  Future<void> entrarColaborador(
    String empresaId,
    String colaboradorId,
    String matricula,
  ) async {
    if (ocupado || portal is! AcessoColaborador) return;
    ocupado = true;
    erro = null;
    ++_epoch;
    _avisar();
    try {
      await (portal as AcessoColaborador).entrarColaborador(
        empresaId,
        colaboradorId,
        matricula,
      );
      await _carregarContexto(empresaId);
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

  Future<void> carregarHistoricoPessoal({bool mais = false}) async {
    final ctx = contexto;
    if (ctx == null ||
        !ctx.acessoPessoal ||
        portal is! AcessoColaborador ||
        carregandoHistorico ||
        (mais && proximoOffsetHistorico == null)) {
      return;
    }
    final epoch = _epoch, offset = mais ? proximoOffsetHistorico! : 0;
    carregandoHistorico = true;
    _avisar();
    try {
      final pagina = await (portal as AcessoColaborador).historicoPessoal(
        ctx,
        offset: offset,
      );
      if (epoch != _epoch || contexto?.escopo != ctx.escopo) return;
      final existentes = {
        for (final item in await repositorio.listar(ctx.escopo)) item.id: item,
      };
      for (final item in pagina.registros) {
        if (epoch != _epoch) return;
        if (item.escopo != ctx.escopo ||
            item.json['employeeId'] != ctx.usuarioId) {
          throw const ErroPortal('Histórico fora do seu acesso.', 403);
        }
        // Cópias locais e envios pendentes nunca são substituídos pela consulta.
        if (!existentes.containsKey(item.id)) await _gravar(item);
      }
      if (epoch != _epoch) return;
      proximoOffsetHistorico = pagina.proximoOffset;
      registros = await repositorio.listar(ctx.escopo);
      if (epoch == _epoch) aviso = 'Histórico pessoal atualizado. Confira a situação de envio de cada avaliação.';
    } catch (e) {
      if (epoch == _epoch) {
        aviso =
            'Não foi possível consultar o histórico central. As cópias locais foram preservadas. $e';
      }
    } finally {
      if (epoch == _epoch) {
        carregandoHistorico = false;
        _avisar();
      }
    }
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
    await repositorio.cofre.gravar(
      'prs_attention_company_$uid',
      loaded.empresaId,
    );
    final saved = await repositorio.listar(loaded.escopo);
    for (final item in saved.where((a) => a.emAndamento)) {
      await repositorio.salvar(item.recuperarInterrompida());
    }
    if (epoch != _epoch) return;
    proximoOffsetHistorico = null;
    carregandoHistorico = false;
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
    _timer?.cancel();
    _limiteAplicacao?.cancel();
    ++_epoch;
    contexto = null;
    proximoOffsetHistorico = null;
    carregandoHistorico = false;
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
    if (usarVisual) {
      visual = VisualEngine(planoVisual(treino: true));
      feedbackTreino = null;
      relogio.iniciar();
      atual = null;
      salvo = false;
      erro = null;
      tela = TelaHistorico.demonstracao;
      _limiteAplicacao?.cancel();
      _limiteAplicacao = Timer(const Duration(seconds: 114), () {
        if (tela == TelaHistorico.teste) {
          unawaited(concluir('Tempo total da aplicação atingido'));
        } else if (tela == TelaHistorico.preparando) {
          _interrompidoAoPreparar = true;
        } else if ([
          TelaHistorico.demonstracao,
          TelaHistorico.treino,
          TelaHistorico.pronto,
        ].contains(tela)) {
          _timer?.cancel();
          relogio.parar();
          tela = TelaHistorico.inicio;
          aviso = 'Tempo de preparação esgotado. Reveja as instruções e recomece quando estiver pronto.';
          _avisar();
        }
      });
      _iniciarVisual();
      _avisar();
      return true;
    }
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
    _interrompidoAoPreparar = false;
    erro = null;
    _avisar();
    final now = DateTime.now().toUtc();
    if (usarVisual) {
      visual = VisualEngine(planoVisual());
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
        'schedule': visual!.plano,
        'trials': [],
        'responses': [],
        'technical': <String, dynamic>{},
        'interruption': null,
        'metrics': metricasVisuais(visual!.plano, [], [], 0),
        'protocolVersion': protocoloVisual,
        'appVersion': '0.3.0',
        'syncState': SituacaoEnvio.pendente.name,
      });
      try {
        await _gravar(atual!);
        tela = TelaHistorico.teste;
        if (_interrompidoAoPreparar) {
          await concluir('Aplicativo saiu de foco durante a preparação');
        }
      } catch (e) {
        erro = 'Não foi possível iniciar com gravação segura: $e';
        tela = TelaHistorico.pronto;
        atual = null;
      }
      _avisar();
      return;
    }
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

  void iniciarCronometro([Map<String, dynamic>? ambiente]) {
    if (tela != TelaHistorico.teste || cronometroIniciado) return;
    relogio.iniciar();
    cronometroIniciado = true;
    if (usarVisual) {
      final now = DateTime.now().toUtc().toIso8601String();
      atual = atual!.alterar({
        'startedAt': now,
        'checkpointAt': now,
        'technical': ambiente ?? <String, dynamic>{},
      });
      _preservarVisual();
      _iniciarVisual();
      return;
    }
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
      'checkpointAt': item.inicio
          .add(Duration(milliseconds: elapsed))
          .toIso8601String(),
      'touches': [
        for (final t in _engine!.toques)
          {
            'seq': t.seq,
            'tMs': t.tMs,
            'touched': t.tocado,
            'expected': t.esperado,
            'correct': t.acerto,
          },
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
    unawaited(
      _gravar(atual!).catchError((Object e) {
        erro =
            'Falha ao salvar um toque. O trecho disponível será preservado: $e';
        if (tela == TelaHistorico.teste) {
          unawaited(concluir('Interrupção por falha de armazenamento'));
        }
        _avisar();
      }),
    );
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
    _limiteAplicacao?.cancel();
    relogio.parar();
    if (usarVisual) {
      atual = _checkpointVisual().alterar({
        'status': visual!.completa ? 'completa' : 'incompleta',
        'interruption': motivo,
      });
      atual = atual!.alterar({'finishedAt': atual!.json['checkpointAt']});
      tela = TelaHistorico.salvando;
      _avisar();
      await tentarSalvar();
      return;
    }
    final result = _engine!.fechar(
      cronometroIniciado ? relogio.milissegundos : 0,
    );
    atual = _checkpoint(result.status.name, result.duracaoMs);
    atual = atual!.alterar({
      'finishedAt': atual!.json['checkpointAt'],
      'interruption': motivo,
    });
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
    if (tela == TelaHistorico.preparando) {
      _interrompidoAoPreparar = true;
      return;
    }
    if (tela == TelaHistorico.teste) {
      unawaited(concluir('Avaliação interrompida'));
    } else if ([
      TelaHistorico.demonstracao,
      TelaHistorico.treino,
    ].contains(tela)) {
      _timer?.cancel();
      _limiteAplicacao?.cancel();
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
    unawaited(carregarHistoricoPessoal());
  }

  void voltar() {
    if (emAvaliacao || (atual != null && !salvo)) return;
    atual = null;
    _engine = null;
    visual = null;
    _timer?.cancel();
    _limiteAplicacao?.cancel();
    relogio.parar();
    tela = TelaHistorico.inicio;
    erro = null;
    _avisar();
  }

  void _iniciarVisual() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => atualizarVisual(),
    );
  }

  // O relógio não depende do número de callbacks do navegador.
  void atualizarVisual() {
    if (usarVisual && tela == TelaHistorico.demonstracao) {
      if (relogio.milissegundos >= 6000) {
        tela = TelaHistorico.treino;
        relogio.iniciar();
        _avisar();
      }
      return;
    }
    if (!usarVisual ||
        visual == null ||
        ![TelaHistorico.treino, TelaHistorico.teste].contains(tela)) {
      return;
    }
    final ms = relogio.milissegundos;
    if (ms >= limiteVisualMs) {
      if (tela == TelaHistorico.teste) {
        unawaited(concluir('Limite de duração atingido'));
      } else {
        interromper();
      }
      return;
    }
    final antes = visual!.fase;
    visual!.avancar(ms);
    if (antes != visual!.fase && visual!.ensaios.isNotEmpty) {
      if (tela == TelaHistorico.teste) {
        _preservarVisual();
      } else if (antes == FaseVisual.sinal) {
        final m = metricasVisuais(
          visual!.plano,
          visual!.ensaios,
          visual!.respostas,
          ms,
        );
        feedbackTreino =
            'Treino: ${m['respostas_validas']} respostas ao círculo parado; ${m['omissoes']} sem resposta; ${m['comissoes']} toques no círculo em movimento.';
      }
    }
    if (visual!.completa) {
      _timer?.cancel();
      if (tela == TelaHistorico.teste) {
        unawaited(concluir());
      } else {
        relogio.parar();
        tela = TelaHistorico.pronto;
      }
    }
    if (antes != visual!.fase) _avisar();
  }

  void apresentarVisual() {
    if (visual?.fase != FaseVisual.apresentar ||
        ![TelaHistorico.treino, TelaHistorico.teste].contains(tela)) {
      return;
    }
    final us = relogio is RelogioPreciso
        ? (relogio as RelogioPreciso).microssegundos
        : relogio.milissegundos * 1000;
    visual!.apresentado(us ~/ 1000, us);
    if (tela == TelaHistorico.teste) _preservarVisual();
    _avisar();
  }

  void responderVisual(String origem) {
    if (!usarVisual ||
        visual == null ||
        ![TelaHistorico.treino, TelaHistorico.teste].contains(tela) ||
        (tela == TelaHistorico.teste && !cronometroIniciado)) {
      return;
    }
    if (relogio.milissegundos >= limiteVisualMs) {
      atualizarVisual();
      return;
    }
    final us = relogio is RelogioPreciso
        ? (relogio as RelogioPreciso).microssegundos
        : relogio.milissegundos * 1000;
    visual!.responder(us ~/ 1000, origem, us);
    if (tela == TelaHistorico.teste) _preservarVisual();
    if (visual!.respostas.length >= 500 && tela == TelaHistorico.teste) {
      unawaited(concluir('Limite de entradas atingido'));
    }
  }

  void anotarMultitoque() {
    if (atual == null || tela != TelaHistorico.teste) return;
    atual = atual!.alterar({
      'technical': {...objeto(atual!.json['technical']), 'multitouch': true},
    });
    _preservarVisual();
  }

  AvaliacaoLocal _checkpointVisual() {
    final ms = !cronometroIniciado
        ? 0
        : visual!.completa
        ? visual!.ensaios.last['closedMs'] as int
        : relogio.milissegundos.clamp(0, limiteVisualMs).toInt();
    return atual!.alterar({
      'durationMs': ms,
      'checkpointAt': atual!.inicio
          .add(Duration(milliseconds: ms))
          .toIso8601String(),
      'trials': [
        for (final e in visual!.ensaios) {...e},
      ],
      'responses': [
        for (final e in visual!.respostas) {...e},
      ],
      'metrics': metricasVisuais(
        visual!.plano,
        visual!.ensaios,
        visual!.respostas,
        ms,
      ),
    });
  }

  void _preservarVisual() {
    atual = _checkpointVisual();
    unawaited(
      _gravar(atual!).catchError((Object e) {
        erro = 'Falha de gravação; mantenha esta tela aberta. $e';
        if (tela == TelaHistorico.teste) {
          unawaited(concluir('Interrupção por falha de armazenamento'));
        }
        _avisar();
      }),
    );
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
              (response['moduleVersion'] as num? ?? 0) <
                  (original.visual ? 57 : 51)) {
            throw const ErroPortal(
              'O servidor não confirmou a avaliação correta.',
              503,
            );
          }
          updated = original.alterar({
            'syncState': SituacaoEnvio.sincronizado.name,
            'syncError': null,
            'receivedAt': response['received_at'],
            if (original.visual &&
                response['assessment'] is Map &&
                response['assessment']['id'] == original.id &&
                response['assessment']['company_id'] == original.empresaId &&
                response['assessment']['employee_id'] ==
                    original.json['employeeId'])
              'metrics': response['assessment']['metrics'],
          });
          _tentativas.remove(original.id);
          _retentarEm.remove(original.id);
        } on ErroPortal catch (e) {
          if (epoch != _epoch) break;
          updated = original.alterar({
            'syncState':
                (e.permanente
                        ? SituacaoEnvio.falhaPermanente
                        : SituacaoEnvio.pendente)
                    .name,
            'syncError': e.mensagem,
          });
          final count = (_tentativas[original.id] ?? 0) + 1;
          _tentativas[original.id] = count;
          _retentarEm[original.id] = DateTime.now().add(
            Duration(seconds: min(900, 10 * pow(2, min(count, 6)).toInt())),
          );
        }
        await _gravar(updated);
        if (atual?.id == updated.id) atual = updated;
      }
      if (epoch == _epoch) {
        registros = await repositorio.listar(ctx.escopo);
        aviso = 'Consulta de envios concluída. Confira a situação de cada avaliação.';
        if (ctx.acessoPessoal) await carregarHistoricoPessoal();
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
    _limiteAplicacao?.cancel();
    relogio.parar();
    super.dispose();
  }
}
