import 'dart:math';

/// Protocolo técnico original. Estes parâmetros não são limites clínicos.
const protocoloVisual = 'visual-v1';
const janelaVisualMs = 1000;
const pausaVisualMs = 200;
const limiteVisualMs = 90000;
const totalVisual = 30;
const limiarAntecipacaoMs = 100;
const limiarLapsoMs = 500;

List<Map<String, dynamic>> planoVisual({Random? random, bool treino = false}) {
  final r = random ?? Random.secure();
  final tipos = treino
      ? ['go', 'nogo']
      : [...List.filled(24, 'go'), ...List.filled(6, 'nogo')];
  if (!treino) tipos.shuffle(r);
  return [
    for (final tipo in tipos)
      {'kind': tipo, 'waitMs': 800 + r.nextInt(801), 'position': r.nextInt(3)},
  ];
}

enum FaseVisual { espera, apresentar, sinal, pausa, fim }

class VisualEngine {
  VisualEngine(this.plano);
  final List<Map<String, dynamic>> plano;
  final List<Map<String, dynamic>> ensaios = [];
  final List<Map<String, dynamic>> respostas = [];
  FaseVisual fase = FaseVisual.espera;
  int indice = 0, _inicioEspera = 0, _fimSinal = 0, _ultimo = 0;
  bool get mover => plano[indice]['kind'] == 'nogo';
  int get prazo => _inicioEspera + (plano[indice]['waitMs'] as int);
  bool get completa => indice == plano.length;

  void avancar(int ms) {
    if (ms < _ultimo) throw ArgumentError('Relógio fora de ordem');
    _ultimo = ms;
    if (fase == FaseVisual.fim) return;
    if (fase == FaseVisual.espera && ms >= prazo) {
      fase = FaseVisual.apresentar;
    } else if (fase == FaseVisual.sinal &&
        ms >=
            ((ensaios.last['shownUs'] as int) / 1000 + janelaVisualMs).ceil()) {
      ensaios.last['closedMs'] = ms;
      _fimSinal = ms;
      indice++;
      fase = completa ? FaseVisual.fim : FaseVisual.pausa;
    } else if (fase == FaseVisual.pausa && ms >= _fimSinal + pausaVisualMs) {
      // O próximo prazo parte do fechamento real, sem fabricar quadros perdidos.
      _inicioEspera = _fimSinal + pausaVisualMs;
      fase = ms >= prazo ? FaseVisual.apresentar : FaseVisual.espera;
    }
  }

  /// Chamado somente depois que o widget do círculo foi apresentado em quadro.
  void apresentado(int ms, [int? us]) {
    avancar(ms);
    if (fase != FaseVisual.apresentar) return;
    ensaios.add({
      'seq': indice + 1,
      'shownMs': ms,
      'shownUs': us ?? ms * 1000,
      'closedMs': null
    });
    fase = FaseVisual.sinal;
  }

  void responder(int ms, String origem, [int? us]) {
    avancar(ms);
    if (fase == FaseVisual.fim || respostas.length >= 500) return;
    if (!['pointer', 'keyboard'].contains(origem))
      throw ArgumentError('Entrada');
    respostas.add({
      'seq': respostas.length + 1,
      'tMs': ms,
      'tUs': us ?? ms * 1000,
      'source': origem
    });
  }
}

/// Percentil interpolado: posição (n-1)*p. DP populacional, sem corte clínico.
Map<String, dynamic> metricasVisuais(
  List<Map<String, dynamic>> plano,
  List<Map<String, dynamic>> ensaios,
  List<Map<String, dynamic>> respostas,
  int duracao,
) {
  final tempos = <double>[];
  final quartos = List.generate(4, (_) => <double>[]);
  var omissoes = 0,
      comissoes = 0,
      extras = 0,
      dentro = 0,
      atraso = 0,
      antecipacoes = 0;
  for (var i = 0; i < ensaios.length; i++) {
    final e = ensaios[i], inicio = e['shownMs'] as int;
    final toques = respostas
        .where(
          (r) =>
              (r['tUs'] ?? (r['tMs'] as int) * 1000) >=
                  (e['shownUs'] ?? inicio * 1000) &&
              (r['tUs'] ?? (r['tMs'] as int) * 1000) <
                  (e['shownUs'] ?? inicio * 1000) + janelaVisualMs * 1000,
        )
        .toList();
    dentro += toques.length;
    extras += max(0, toques.length - 1);
    final devido =
        (i == 0 ? 0 : (ensaios[i - 1]['closedMs'] as int) + pausaVisualMs) +
            (plano[i]['waitMs'] as int);
    atraso = max(atraso, inicio - devido);
    if (e['closedMs'] != null)
      atraso = max(atraso, (e['closedMs'] as int) - inicio - janelaVisualMs);
    if (plano[i]['kind'] == 'go') {
      if (toques.isNotEmpty) {
        final t = (((toques.first['tUs'] ?? (toques.first['tMs'] as int) * 1000)
                    as num) -
                ((e['shownUs'] ?? inicio * 1000) as num)) /
            1000;
        if (t < limiarAntecipacaoMs) {
          antecipacoes++;
        } else {
          tempos.add(t);
          quartos[min(3, (i * 4 ~/ plano.length))].add(t);
        }
      } else if (e['closedMs'] != null) {
        omissoes++;
      }
    } else if (toques.isNotEmpty) {
      comissoes++;
    }
  }
  double? media(List<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  double? arred(double? v) => v == null ? null : (v * 10).round() / 10;
  final mediaMs = media(tempos);
  final ordenados = [...tempos]..sort();
  final decimo = max(1, (ordenados.length * .1).ceil());
  double? percentil(double p) {
    if (ordenados.isEmpty) return null;
    final pos = (ordenados.length - 1) * p, inferior = pos.floor();
    return ordenados[inferior] +
        (ordenados[pos.ceil()] - ordenados[inferior]) * (pos - inferior);
  }

  return {
    'tempo_total_ms': duracao,
    'previstos': plano.length,
    'apresentados': ensaios.length,
    'encerrados': ensaios.where((e) => e['closedMs'] != null).length,
    'respostas_validas': tempos.length,
    'omissoes': omissoes,
    'comissoes': comissoes,
    'fora_estimulo': respostas.length - dentro,
    'toques_extras': extras,
    'antecipacoes': antecipacoes + respostas.length - dentro,
    'lapsos': tempos.where((t) => t > limiarLapsoMs).length,
    'media_reacao_ms': arred(mediaMs),
    'mediana_reacao_ms': arred(percentil(.5)),
    'dp_reacao_ms': arred(
      mediaMs == null
          ? null
          : sqrt(
              tempos.fold<double>(0, (s, t) => s + pow(t - mediaMs, 2)) /
                  tempos.length,
            ),
    ),
    'p10_reacao_ms': arred(percentil(.1)),
    'p90_reacao_ms': arred(percentil(.9)),
    'rapidos10_media_ms': arred(media(ordenados.take(decimo).toList())),
    'lentos10_media_ms': arred(media(ordenados.reversed.take(decimo).toList())),
    'declinio_ms': quartos.first.isEmpty || quartos.last.isEmpty
        ? null
        : arred(media(quartos.last)! - media(quartos.first)!),
    'quartos_media_ms': [for (final q in quartos) arred(media(q))],
    'maior_atraso_ms': atraso,
  };
}
