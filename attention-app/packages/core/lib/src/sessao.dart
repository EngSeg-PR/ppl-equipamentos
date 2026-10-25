import 'dart:convert';

import 'grade.dart';
import 'metricas.dart' show calcularMetricas;
import 'modelos.dart';
import 'reacao.dart';
import 'validacao_toques.dart';

class RespostaQuestionario {
  const RespostaQuestionario({
    required this.perguntaId,
    required this.resposta,
  });

  final String perguntaId;

  /// Inclui o valor 'prefiro_nao_responder'.
  final String resposta;

  Map<String, dynamic> toJson() => {
    'pergunta_id': perguntaId,
    'resposta': resposta,
  };
}

/// Sessão pronta para ser gravada localmente e enviada a `sync_sessao`.
/// O formato de [toPayload] é o contrato descrito em supabase/README.md.
class SessaoTeste {
  const SessaoTeste({
    required this.id,
    required this.condutorId,
    required this.momento,
    required this.iniciadoEm,
    required this.finalizadoEm,
    required this.status,
    required this.duracaoMs,
    required this.grade,
    required this.metricas,
    required this.classificacao,
    required this.limiarId,
    required this.textosId,
    required this.appVersao,
    required this.toques,
    this.questionarioId,
    this.fotoPath,
    this.reacao = const [],
    this.respostas = const [],
  });

  final String id;
  final String condutorId;
  final Momento momento;
  final DateTime iniciadoEm;
  final DateTime finalizadoEm;
  final StatusSessao status;
  final int duracaoMs;
  final List<int> grade;
  final Metricas metricas;
  final Faixa classificacao;
  final String limiarId;
  final String? questionarioId;
  final String textosId;
  final String appVersao;

  /// Formato "<empresa_id>/<arquivo>"; o servidor rejeita caminhos de outra pasta.
  final String? fotoPath;
  final List<ToqueEvento> toques;
  final List<EventoReacao> reacao;
  final List<RespostaQuestionario> respostas;

  /// Lança [FormatException] se os eventos, o status e as métricas divergirem.
  /// Vínculos e permissões da empresa são verificados pelo servidor.
  void validar() {
    if (!gradeValida(grade)) {
      throw const FormatException(
        'grade inválida (precisa ser permutação de 1..n)',
      );
    }
    if (toques.length > 2000 || reacao.length > 500 || respostas.length > 100) {
      throw const FormatException(
        'quantidade de eventos excede o contrato do servidor',
      );
    }

    try {
      final acertos = validarToques(
        toques: toques,
        n: grade.length,
        duracaoMs: duracaoMs,
      );
      final completa = acertos == grade.length;
      if ((status == StatusSessao.completa) != completa ||
          (completa && duracaoMs != toques.last.tMs)) {
        throw const FormatException('status ou duração diverge dos toques');
      }
      final calculadas = metricasDe(
        toques: toques,
        n: grade.length,
        duracaoMs: duracaoMs,
        reacao: reacao,
      );
      for (final valor in [
        metricas.mediaIntervaloMs,
        metricas.dpIntervaloMs,
        metricas.reacao?.mediaMs,
        metricas.reacao?.medianaMs,
      ]) {
        if (valor != null && !valor.isFinite) {
          throw const FormatException(
            'métricas precisam conter valores finitos',
          );
        }
      }
      if (jsonEncode(metricas.toJson()) != jsonEncode(calculadas.toJson())) {
        throw const FormatException(
          'métricas divergem dos eventos registrados',
        );
      }
    } on ArgumentError catch (erro) {
      throw FormatException('eventos inválidos: ${erro.message}');
    }

    if (respostas.isNotEmpty && questionarioId == null) {
      throw const FormatException(
        'respostas exigem uma versão do questionário',
      );
    }
    final vistos = <String>{};
    for (final r in respostas) {
      if (r.perguntaId.trim().isEmpty || r.resposta.trim().isEmpty) {
        throw const FormatException('pergunta e resposta não podem ser vazias');
      }
      if (!vistos.add(r.perguntaId)) {
        throw FormatException('pergunta repetida: ${r.perguntaId}');
      }
    }
  }

  Map<String, dynamic> toPayload() {
    validar();
    return {
      'sessao': {
        'id': id,
        'condutor_id': condutorId,
        'momento': momento.name,
        'iniciado_em': iniciadoEm.toUtc().toIso8601String(),
        'finalizado_em': finalizadoEm.toUtc().toIso8601String(),
        'status': status.name,
        'duracao_ms': duracaoMs,
        'grade': List<int>.of(grade),
        'metricas': metricas.toJson(),
        'classificacao': classificacao.name,
        'limiar_id': limiarId,
        if (questionarioId != null) 'questionario_id': questionarioId,
        'textos_id': textosId,
        'app_versao': appVersao,
        if (fotoPath != null) 'foto_path': fotoPath,
      },
      'toques': [for (final t in toques) t.toJson()],
      'reacao': [for (final e in reacao) e.toJson()],
      'respostas': [for (final r in respostas) r.toJson()],
    };
  }

  /// Atalho para montar as métricas a partir dos toques (usado nos testes e no app).
  static Metricas metricasDe({
    required List<ToqueEvento> toques,
    required int n,
    required int duracaoMs,
    List<EventoReacao>? reacao,
  }) {
    return calcularMetricas(
      toques: toques,
      n: n,
      duracaoMs: duracaoMs,
      reacao: (reacao == null || reacao.isEmpty)
          ? null
          : calcularMetricasReacao(reacao),
    );
  }
}
