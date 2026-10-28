import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_store.dart';
import 'models.dart';
import 'employee_access.dart';

class ErroPortal implements Exception {
  const ErroPortal(this.mensagem, this.status);
  final String mensagem;
  final int status;
  bool get permanente => [400, 403, 404, 409, 413, 422].contains(status);
  @override
  String toString() => mensagem;
}

abstract interface class ServicoPortal {
  String? get usuarioId;
  Future<bool> restaurar();
  Future<void> entrar(String email, String senha);
  Future<void> sair();
  Future<ContextoAtencao> contexto([String? empresaId]);
  Future<Map<String, dynamic>> enviar(AvaliacaoLocal avaliacao);
}

/// Configuração pública conferida contra cloud-config.js do PRS.REIS/SSMA.
/// Só faz chamadas após a entrada do operador; nenhum segredo administrativo.
class ApiPortal implements ServicoPortal, AcessoColaborador {
  ApiPortal(this.cofre, {http.Client? client, String? url, String? publicKey})
    : _client = client ?? http.Client(),
      url =
          url ??
          const String.fromEnvironment(
            'SUPABASE_URL',
            defaultValue: 'https://hqyyrylamokgxbkwzbix.supabase.co',
          ),
      publicKey =
          publicKey ??
          const String.fromEnvironment(
            'SUPABASE_PUBLIC_KEY',
            defaultValue: 'sb_publishable_mBbuhiY9GWmTLkxF1IwtLQ_l3T0sJfw',
          );
  final CofreChaves cofre;
  final http.Client _client;
  final String url;
  final String publicKey;
  Map<String, dynamic>? _sessao;
  Future<void>? _renovacao;
  int _epoch = 0;
  Future<void> _persistencia = Future.value();
  static const _alias = 'prs_attention_v2_auth';
  Future<void> _persistir(Future<void> Function() operation) {
    final next = _persistencia.then((_) => operation());
    _persistencia = next.catchError((Object _) {});
    return next;
  }

  @override
  String? get usuarioId =>
      _sessao == null ? null : objeto(_sessao!['user'])['id'] as String?;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, [
    String? token,
    bool pessoal = false,
  ]) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$url/$path'),
            headers: {
              'apikey': publicKey,
              'Content-Type': 'application/json',
              if (token != null && !pessoal) 'Authorization': 'Bearer $token',
              if (token != null && pessoal) 'X-PPL-Executor': token,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
    } on Object {
      throw const ErroPortal(
        'Sem confirmação de conexão. Os registros locais foram preservados.',
        0,
      );
    }
    Map<String, dynamic> data;
    try {
      data = objeto(jsonDecode(response.body));
    } on Object {
      throw ErroPortal(
        'Resposta inválida do servidor. Preserve os registros e tente novamente.',
        response.statusCode >= 500 ? response.statusCode : 503,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ErroPortal(
        (data['error'] ??
                data['msg'] ??
                data['error_description'] ??
                'Não foi possível confirmar a operação.')
            .toString(),
        response.statusCode,
      );
    }
    return data;
  }

  Future<void> _guardar(Map<String, dynamic> data, int epoch) async {
    if (epoch != _epoch) {
      throw const ErroPortal('Sessão alterada. Entre novamente.', 401);
    }
    final user = objeto(data['user']);
    if (user['id'] is! String ||
        data['access_token'] is! String ||
        (data['kind'] != 'employee' && data['refresh_token'] is! String)) {
      throw const ErroPortal('A autenticação retornou dados incompletos.', 503);
    }
    final session = {
      ...data,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch +
          ((data['expires_in'] as num?)?.toInt() ?? 3600) * 1000,
    };
    await _persistir(() async {
      if (epoch != _epoch) throw const ErroPortal('Sessão alterada.', 401);
      await cofre.gravar(_alias, jsonEncode(session));
    });
    if (epoch != _epoch) throw const ErroPortal('Sessão alterada.', 401);
    _sessao = session;
  }

  @override
  Future<bool> restaurar() async {
    final raw = await cofre.ler(_alias);
    if (raw == null) return false;
    final data = objeto(jsonDecode(raw));
    if (objeto(data['user'])['id'] is! String ||
        (data['kind'] != 'employee' && data['refresh_token'] is! String)) {
      throw const FormatException('Sessão local inválida.');
    }
    _sessao = data;
    return true;
  }

  @override
  Future<void> entrar(String email, String senha) async {
    final epoch = ++_epoch;
    _sessao = null;
    await _guardar(
      await _post('auth/v1/token?grant_type=password', {
        'email': email.trim(),
        'password': senha,
      }),
      epoch,
    );
  }

  Future<String> _token() async {
    if (_sessao == null) {
      throw const ErroPortal('Entre com sua conta de gestão.', 401);
    }
    if (_sessao!['kind'] == 'employee') {
      if (DateTime.now().millisecondsSinceEpoch >=
          (_sessao!['expires_at'] as num)) {
        throw const ErroPortal(
          'Sessão expirada. Entre novamente com sua matrícula.',
          401,
        );
      }
      return _sessao!['access_token'] as String;
    }
    final epoch = _epoch;
    if (DateTime.now().millisecondsSinceEpoch >=
        (_sessao!['expires_at'] as num).toInt() - 60000) {
      _renovacao ??= () async {
        final previous = _sessao!;
        final data = await _post('auth/v1/token?grant_type=refresh_token', {
          'refresh_token': previous['refresh_token'],
        });
        await _guardar({
          ...data,
          'user': data['user'] ?? previous['user'],
        }, epoch);
      }().whenComplete(() => _renovacao = null);
      await _renovacao;
    }
    if (epoch != _epoch || _sessao == null) {
      throw const ErroPortal('Sessão encerrada.', 401);
    }
    return _sessao!['access_token'] as String;
  }

  Future<Map<String, dynamic>> chamar(
    String action,
    Map<String, dynamic> body,
  ) async {
    final epoch = _epoch;
    final data = await _post(
      'functions/v1/ppl-api-',
      {'action': action, ...body},
      await _token(),
      _sessao?['kind'] == 'employee',
    );
    if (epoch != _epoch) throw const ErroPortal('Sessão encerrada.', 401);
    return data;
  }

  @override
  Future<ContextoAtencao> contexto([String? empresaId]) async {
    final data = await chamar(
      _sessao?['kind'] == 'employee'
          ? 'attention-employee-context'
          : 'attention-context',
      {if (empresaId != null) 'companyId': empresaId},
    );
    if ((data['moduleVersion'] as num? ?? 0) < 51) {
      throw const ErroPortal(
        'O histórico de avaliações ainda precisa ser ativado no servidor PRS. REIS.',
        503,
      );
    }
    final context = ContextoAtencao(data);
    if (context.usuarioId != usuarioId) {
      throw const ErroPortal(
        'A identidade retornada não corresponde à sessão.',
        403,
      );
    }
    return context;
  }

  @override
  Future<Map<String, dynamic>> enviar(AvaliacaoLocal avaliacao) => chamar(
    _sessao?['kind'] == 'employee'
        ? 'attention-employee-submit'
        : 'attention-submit',
    {'companyId': avaliacao.empresaId, 'assessment': avaliacao.paraServidor()},
  );

  Future<Map<String, dynamic>> _publico(
    String action,
    Map<String, dynamic> dados,
  ) => _post('functions/v1/ppl-api-', {'action': action, ...dados});

  @override
  Future<List<Map<String, dynamic>>> empresasDisponiveis() async {
    final data = await _publico('companies', {});
    return (data['rows'] as List)
        .map(objeto)
        .where((e) => e['status'] == 'ready')
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> colaboradoresDaEmpresa(
    String empresaId,
  ) async {
    final data = await _publico('executor-directory', {'companyId': empresaId});
    if (objeto(data['company'])['id'] != empresaId) {
      throw const ErroPortal(
        'Empresa diferente da seleção. Tente novamente.',
        503,
      );
    }
    return (data['employees'] as List).map(objeto).toList();
  }

  @override
  Future<void> entrarColaborador(
    String empresaId,
    String colaboradorId,
    String matricula,
  ) async {
    final epoch = ++_epoch;
    _sessao = null;
    final data = await _publico('executor-login', {
      'companyId': empresaId,
      'employeeId': colaboradorId,
      'password': matricula,
    });
    if (objeto(data['employee'])['id'] != colaboradorId ||
        objeto(data['company'])['id'] != empresaId ||
        data['executorToken'] is! String) {
      throw const ErroPortal('Identidade diferente da seleção.', 503);
    }
    final validade = DateTime.parse(data['expiresAt'] as String)
        .difference(DateTime.now())
        .inSeconds;
    if (validade <= 0) {
      throw const ErroPortal('Sessão expirada. Entre novamente.', 401);
    }
    await _guardar({
      'kind': 'employee',
      'access_token': data['executorToken'],
      'expires_in': validade,
      'company_id': empresaId,
      'user': {'id': colaboradorId},
    }, epoch);
  }

  @override
  Future<PaginaHistoricoPessoal> historicoPessoal(
    ContextoAtencao contexto, {
    int offset = 0,
  }) async {
    if (!contexto.acessoPessoal || contexto.usuarioId != usuarioId) {
      throw const ErroPortal('Histórico restrito ao próprio colaborador.', 403);
    }
    final data = await chamar('attention-employee-history', {
      'companyId': contexto.empresaId,
      'includeVisual': true,
      'offset': offset,
    });
    final registros = <AvaliacaoLocal>[];
    for (final raw in data['rows'] as List) {
      final row = objeto(raw), payload = objeto(row['payload']);
      if (row['company_id'] != contexto.empresaId ||
          row['employee_id'] != usuarioId) {
        throw const ErroPortal('Histórico fora do seu acesso.', 403);
      }
      registros.add(
        AvaliacaoLocal({
          'id': row['id'],
          'userId': contexto.usuarioId,
          'companyId': row['company_id'],
          'companyName': contexto.nomeEmpresa,
          'employeeId': row['employee_id'],
          'employeeSnapshot': row['employee_snapshot'],
          'unit': row['unit'],
          'team': row['team'],
          'moment': row['moment'],
          'startedAt': row['started_at'],
          'finishedAt': row['finished_at'],
          'status': row['status'],
          'durationMs': row['duration_ms'],
          'metrics': row['metrics'],
          'grid': payload['grid'],
          'touches': payload['touches'],
          for (final key in [
            'schedule',
            'trials',
            'responses',
            'interruption',
            'technical',
          ])
            key: payload[key],
          'protocolVersion': row['protocol_version'],
          'appVersion': row['app_version'],
          'syncState': SituacaoEnvio.sincronizado.name,
          'receivedAt': row['received_at'],
        }),
      );
    }
    return PaginaHistoricoPessoal(
      registros,
      (data['nextOffset'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> sair() async {
    final anterior = _sessao;
    ++_epoch;
    _sessao = null;
    await _persistir(() => cofre.apagar(_alias));
    if (anterior?['kind'] == 'employee') {
      unawaited(
        _post(
          'functions/v1/ppl-api-',
          {'action': 'executor-logout', 'companyId': anterior!['company_id']},
          anterior['access_token'] as String,
          true,
        ).catchError((Object _) => <String, dynamic>{}),
      );
    }
  }
}
