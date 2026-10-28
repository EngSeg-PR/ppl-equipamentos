import 'models.dart';

/// Acesso pessoal independente das permissões de gestão já existentes.
abstract interface class AcessoColaborador {
  Future<List<Map<String, dynamic>>> empresasDisponiveis();
  Future<List<Map<String, dynamic>>> colaboradoresDaEmpresa(String empresaId);
  Future<void> entrarColaborador(
    String empresaId,
    String colaboradorId,
    String matricula,
  );
  Future<PaginaHistoricoPessoal> historicoPessoal(
    ContextoAtencao contexto, {
    int offset = 0,
  });
}

class PaginaHistoricoPessoal {
  const PaginaHistoricoPessoal(this.registros, this.proximoOffset);
  final List<AvaliacaoLocal> registros;
  final int? proximoOffset;
}
