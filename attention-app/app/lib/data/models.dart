import 'dart:math';

import 'package:triagem_core/triagem_core.dart';

String novoId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Map<String, dynamic> objeto(Object? value) {
  if (value is! Map) throw const FormatException('Resposta de dados inválida.');
  return Map<String, dynamic>.from(value);
}

class ContextoAtencao {
  ContextoAtencao(this.json) {
    if (empresaId.isEmpty || usuarioId.isEmpty) {
      throw const FormatException('Contexto sem identificação.');
    }
  }
  final Map<String, dynamic> json;
  String get usuarioId => objeto(json['principal'])['id'] as String;
  String get nomeUsuario => objeto(json['principal'])['name'] as String? ?? '';
  String get empresaId => objeto(json['company'])['id'] as String;
  String get nomeEmpresa => objeto(json['company'])['name'] as String;
  List<Map<String, dynamic>> get empresas =>
      (json['companies'] as List).map(objeto).toList();
  List<Map<String, dynamic>> get colaboradores =>
      (json['employees'] as List).map(objeto).toList();
  List<Map<String, dynamic>>? get escopos => json['scopes'] == null
      ? null
      : (json['scopes'] as List).map(objeto).toList();
  String get escopo => '$usuarioId/$empresaId';
}

enum SituacaoEnvio { pendente, sincronizado, falhaPermanente }

class AvaliacaoLocal {
  AvaliacaoLocal(Map<String, dynamic> dados) : json = Map.unmodifiable(dados);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get usuarioId => json['userId'] as String;
  String get empresaId => json['companyId'] as String;
  String get escopo => '$usuarioId/$empresaId';
  String get status => json['status'] as String;
  bool get emAndamento => status == 'em_andamento';
  String get nome => objeto(json['employeeSnapshot'])['name'] as String;
  String get matricula =>
      objeto(json['employeeSnapshot'])['employee_number'] as String? ?? '';
  DateTime get inicio => DateTime.parse(json['startedAt'] as String);
  int get duracaoMs => json['durationMs'] as int;
  List<int> get grade => (json['grid'] as List).cast<int>();
  List<ToqueEvento> get toques => (json['touches'] as List).map((e) {
        final t = objeto(e);
        return ToqueEvento(
            seq: t['seq'] as int,
            tMs: t['tMs'] as int,
            tocado: t['touched'] as int,
            esperado: t['expected'] as int);
      }).toList();
  SituacaoEnvio get envio =>
      SituacaoEnvio.values.byName(json['syncState'] as String? ?? 'pendente');
  String? get erro => json['syncError'] as String?;
  Map<String, dynamic> get metricas => objeto(json['metrics']);
  AvaliacaoLocal alterar(Map<String, dynamic> mudancas) =>
      AvaliacaoLocal({...json, ...mudancas});

  Map<String, dynamic> paraServidor() {
    if (emAndamento) {
      throw StateError('Avaliação em andamento não pode ser enviada.');
    }
    return {
      for (final key in [
        'id',
        'employeeId',
        'unit',
        'team',
        'moment',
        'startedAt',
        'finishedAt',
        'status',
        'durationMs',
        'grid',
        'touches',
        'protocolVersion',
        'appVersion'
      ])
        key: json[key]
    };
  }

  static Map<String, dynamic> metricasDe(
          List<ToqueEvento> toques, List<int> grade, int duracaoMs) =>
      SessaoTeste.metricasDe(
              toques: toques, n: grade.length, duracaoMs: duracaoMs)
          .toJson();

  AvaliacaoLocal recuperarInterrompida() => alterar({
        'status': toques.where((t) => t.acerto).length == grade.length
            ? 'completa'
            : 'incompleta',
        'finishedAt': json['checkpointAt'],
        'interruption':
            'Aplicativo encerrado durante a avaliação; recuperada do último salvamento.',
        'metrics': metricasDe(toques, grade, duracaoMs),
        'syncState': SituacaoEnvio.pendente.name,
      });
}

String rotuloEnvio(SituacaoEnvio envio) => switch (envio) {
      SituacaoEnvio.pendente => 'Salvo no aparelho · envio pendente',
      SituacaoEnvio.sincronizado => 'Sincronizado com PRS. REIS',
      SituacaoEnvio.falhaPermanente => 'Falha permanente · requer revisão',
    };
