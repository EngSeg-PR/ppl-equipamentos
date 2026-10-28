import 'package:flutter/material.dart';

import 'data/models.dart';

String rotuloClassificacao(Object? raw) {
  if (raw is! Map) return 'Aguardando análise central';
  return raw['level'] as String? ??
      switch (raw['state']) {
        'base_em_formacao' => 'Base em formação',
        'referencia_insuficiente' => 'Referência insuficiente',
        'qualidade_insuficiente' => 'Qualidade técnica insuficiente',
        _ => 'Aguardando análise central',
      };
}

class ResultadoClassificado extends StatelessWidget {
  const ResultadoClassificado({super.key, required this.metricas});
  final Map<String, dynamic> metricas;
  @override
  Widget build(BuildContext context) {
    final raw = metricas['classification'];
    final c = raw is Map ? objeto(raw) : <String, dynamic>{};
    final estado = c['state'];
    final nivel = c['level'] as String?;
    final titulo = rotuloClassificacao(raw);
    final cor = switch (nivel) {
      'Normal' => const Color(0xFF21634B),
      'Limítrofe' => const Color(0xFF825700),
      'Alterado' || 'Significativamente Alterado' => const Color(0xFFA62B2B),
      _ => const Color(0xFF24476B),
    };
    final regras = c['config'] is Map
        ? objeto(c['config'])
        : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .06),
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Classificação experimental',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              nivel == 'Normal'
                  ? Icons.check_circle_outline
                  : nivel == 'Limítrofe'
                  ? Icons.warning_amber_rounded
                  : nivel == 'Alterado' ||
                        nivel == 'Significativamente Alterado'
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: cor,
              size: 32,
            ),
          ),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cor),
          ),
          if (estado == 'nao_interpretavel')
            const Text(
              'Avaliação não interpretável. O rótulo refere-se ao teste; não presume intenção ou culpa.',
            ),
          const SizedBox(height: 10),
          Text(
            c['guidance'] as String? ?? 'A avaliação está salva. A comparação será calculada pelo servidor quando o envio for confirmado.',
          ),
          if (c['reasons'] is List)
            for (final razao in c['reasons'] as List)
              if (razao != c['guidance'])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('• $razao'),
                ),
          const SizedBox(height: 10),
          const Text(
            'Parâmetros em validação. Não é diagnóstico nem liberação para o trabalho.',
          ),
          if (c.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Como foi calculado'),
              children: [
                const Text(
                  'Os pontos de corte precisam de validação pela equipe de saúde/estatística. A classificação não estima a probabilidade de acidente.',
                ),
                if (c['recurrence'] is Map)
                  Text(
                    'Recorrência preventiva: ${c['recurrence']['count']} resultado(s) fora de Normal em ${c['recurrence']['observed']} observado(s); critério ${c['recurrence']['minimum']} na janela de ${c['recurrence']['window']}. Não altera o nível automaticamente.',
                  ),
                Text(
                  'Regra ${c['ruleVersion']} · ${c['formulaVersion']}. z = (valor atual − média de referência) / desvio-padrão populacional da referência. Considera-se a piora positiva e o maior z entre os parâmetros e as duas bases.',
                ),
                if (regras.isNotEmpty)
                  Text(
                    'Normal: z ≤ ${regras['z1']}; Limítrofe: até ${regras['z2']}; Alterado: até ${regras['z3']}; Significativamente Alterado: acima de ${regras['z3']}. Os percentuais de Gauss não são metas ou quotas de classificação.',
                  ),
                if (c['individualCount'] != null)
                  Text(
                    'Base individual: ${c['individualCount']} / ${regras['individualMinimum']}. Base populacional: ${c['populationCount']} / ${regras['populationMinimum']}, com ${c['populationPeople']} pessoas. Habituação: primeiros ${regras['habituation']} testes elegíveis excluídos da referência. O teste atual e a sequência numérica não entram nas bases.',
                  ),
                if (c['scores'] is List)
                  for (final rawScore in c['scores'] as List)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(_score(objeto(rawScore))),
                    ),
              ],
            ),
        ],
      ),
    );
  }

  String _score(Map<String, dynamic> s) {
    const nomes = {
      'mediana_reacao_ms': 'Reação mediana',
      'lentos10_media_ms': 'Média dos 10% mais lentos',
      'dp_reacao_ms': 'Desvio dos tempos',
      'lapsos': 'Lapsos',
      'omissoes': 'Omissões',
      'antecipacoes': 'Antecipações',
      'comissoes': 'Comissões',
      'declinio_ms': 'Declínio entre o último e o primeiro quarto',
    };
    return '${s['reference']} · ${nomes[s['parameter']] ?? s['parameter']}: valor ${s['value'] ?? '—'}, média ${s['mean'] ?? '—'}, DP ${s['sd'] ?? '—'}, z ${s['z'] ?? 'não comparável'}, amostra ${s['sampleCount'] ?? '—'}.';
  }
}
