import 'dart:math';

/// Gera uma permutação de 1..n (Fisher-Yates). Sem [random], usa [Random.secure].
/// Cada aplicação do teste deve gerar uma grade nova.
List<int> gerarGrade({int n = 36, Random? random}) {
  if (n < 4 || n > 99) {
    throw ArgumentError.value(n, 'n', 'deve estar entre 4 e 99');
  }
  final rng = random ?? Random.secure();
  final lista = List<int>.generate(n, (i) => i + 1);
  for (var i = n - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = lista[i];
    lista[i] = lista[j];
    lista[j] = tmp;
  }
  return lista;
}

/// Mesma regra que o servidor aplica em `sync_sessao`: permutação de 1..n, 4 <= n <= 99.
bool gradeValida(List<int> grade) {
  final n = grade.length;
  if (n < 4 || n > 99) return false;
  final vistos = <int>{};
  for (final v in grade) {
    if (v < 1 || v > n || !vistos.add(v)) return false;
  }
  return true;
}
