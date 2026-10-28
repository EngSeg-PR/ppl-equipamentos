import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:triagem_core/triagem_core.dart';

import 'brand.dart';
import 'device_model.dart';
import 'features/history/history_controller.dart';

class MedicaoTela {
  static int? _anterior;
  static final _intervalos = <int>[];
  static void quadro(int us) {
    if (_anterior == us) return;
    final d = us - (_anterior ?? us);
    _anterior = us;
    if (d >= 1000 && d <= 100000) {
      _intervalos.add(d);
      if (_intervalos.length > 120) _intervalos.removeAt(0);
    }
  }

  static double? get hz {
    if (_intervalos.length < 30) return null;
    final s = [..._intervalos]..sort();
    return (10000000 / s[s.length ~/ 2]).round() / 10;
  }
}

/// O círculo é estável para responder e oscila suavemente para aguardar.
/// A cor e o conteúdo escrito não codificam o tipo do estímulo.
class CirculoVisual extends StatefulWidget {
  const CirculoVisual({super.key, required this.mover, this.visivel = true});
  final bool mover, visivel;
  @override
  State<CirculoVisual> createState() => _CirculoVisualState();
}

class _CirculoVisualState extends State<CirculoVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController animacao = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    animationBehavior: AnimationBehavior.preserve,
  )..repeat();
  @override
  void dispose() {
    animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    width: 220,
    child: widget.visivel
        ? AnimatedBuilder(
            animation: animacao,
            builder: (context, _) {
              MedicaoTela.quadro(
                SchedulerBinding
                    .instance
                    .currentSystemFrameTimeStamp
                    .inMicroseconds,
              );
              return Center(
                child: Transform.translate(
                  offset: Offset(
                    widget.mover ? 30 * sin(animacao.value * pi * 2) : 0,
                    0,
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: azulMarca,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          )
        : null,
  );
}

class TesteVisual extends StatefulWidget {
  const TesteVisual({super.key, required this.c, required this.treino});
  final HistoricoController c;
  final bool treino;
  @override
  State<TesteVisual> createState() => _TesteVisualState();
}

class _TesteVisualState extends State<TesteVisual> {
  final foco = FocusNode();
  final _area = GlobalKey();
  final _ponteiros = <int>{};
  int? _quadroPendente;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_area.currentContext != null) {
        await Scrollable.ensureVisible(_area.currentContext!, alignment: .1);
      }
      if (!mounted) return;
      foco.requestFocus();
      if (!widget.treino) {
        final modelo = await modeloDisponivel();
        if (!mounted) return;
        final tamanho = MediaQuery.sizeOf(context);
        widget.c.iniciarCronometro({
          'runtime': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'width': tamanho.width.round(),
          'height': tamanho.height.round(),
          'pixelRatio': MediaQuery.devicePixelRatioOf(context),
          'deviceModel': modelo ?? 'Não informado pelo navegador/dispositivo',
          'refreshRateHz': MedicaoTela.hz,
        });
      }
    });
  }

  @override
  void dispose() {
    foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, e = c.visual!;
    final visivel = [FaseVisual.apresentar, FaseVisual.sinal].contains(e.fase);
    if (e.fase == FaseVisual.apresentar && _quadroPendente != e.indice) {
      _quadroPendente = e.indice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.apresentarVisual();
      });
    }
    return Focus(
      focusNode: foco,
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      onKeyEvent: (node, event) {
        if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
        if ([
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.enter,
        ].contains(event.logicalKey)) {
          if (event is KeyDownEvent) c.responderVisual('keyboard');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.treino
                      ? 'Treino sem pontuação'
                      : 'Avaliação visual em andamento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parado: toque. Em movimento: aguarde. Você pode tocar em qualquer ponto da área abaixo ou usar a barra de espaço.',
                ),
                const SizedBox(height: 16),
                Semantics(
                  key: _area,
                  label: visivel
                      ? (e.mover ? 'Círculo em movimento' : 'Círculo parado')
                      : 'Aguarde o círculo',
                  button: true,
                  onTap: () => c.responderVisual('pointer'),
                  child: ExcludeSemantics(
                    child: Listener(
                      onPointerDown: (event) {
                        _ponteiros.add(event.pointer);
                        if (_ponteiros.length > 1) c.anotarMultitoque();
                        if (event.buttons == 1) {
                          foco.requestFocus();
                          c.responderVisual('pointer');
                        }
                      },
                      onPointerUp: (event) => _ponteiros.remove(event.pointer),
                      onPointerCancel: (event) =>
                          _ponteiros.remove(event.pointer),
                      child: Container(
                        key: const Key('area-resposta-visual'),
                        constraints: const BoxConstraints(minHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: foco.hasFocus
                                ? azulMarca
                                : const Color(0xFFB5C5D9),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Align(
                          alignment: Alignment(
                            [-.45, 0.0, .45][(e.plano[e.indice.clamp(
                                      0,
                                      e.plano.length - 1,
                                    )]['position']
                                    as int?) ??
                                1],
                            0,
                          ),
                          child: CirculoVisual(
                            mover: visivel && e.mover,
                            visivel: visivel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.treino)
                  Text(
                    c.feedbackTreino ?? 'Experimente: responda somente ao círculo parado. Aguarde o fechamento de cada apresentação.',
                  ),
                if (!widget.treino)
                  const Text(
                    'Mantenha esta tela aberta até o final. A avaliação dura aproximadamente um minuto.',
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: c.interromper,
                  child: Text(
                    widget.treino
                        ? 'Voltar às instruções'
                        : 'Interromper e preservar avaliação',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
