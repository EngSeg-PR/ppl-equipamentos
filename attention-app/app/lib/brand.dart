import 'package:flutter/material.dart';

const azulMarca = Color(0xFF10376D);
const fundoMarca = Color(0xFFF3F6FA);

/// Exibe a arte original sem recortar, distorcer ou sobrepor textos.
class LogoPrs extends StatelessWidget {
  const LogoPrs({super.key, this.horizontal = false, this.height = 100});
  final bool horizontal;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    horizontal
        ? 'assets/logo_prs_reis_horizontal.png'
        : 'assets/logo_prs_reis_3x4.png',
    height: height,
    fit: BoxFit.contain,
    semanticLabel: 'PRS. REIS — Consultoria e Gestão em Segurança do Trabalho',
  );
}

class CabecalhoPrs extends StatelessWidget {
  const CabecalhoPrs({super.key, this.sair, this.conectado = false});
  final VoidCallback? sair;
  final bool conectado;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFDDE6F0))),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Row(
            children: [
              const SizedBox(width: 46, child: LogoPrs(height: 62)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRS. REIS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: azulMarca,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Avaliações de atenção',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (conectado)
                IconButton(
                  tooltip: 'Sair da conta sem apagar o histórico',
                  onPressed: sair,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String dataHoraLocal(DateTime value) {
  final d = value.toLocal();
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
}
