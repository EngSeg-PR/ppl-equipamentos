import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:triagem_core/triagem_core.dart';

import 'features/ensaio/ensaio_controller.dart';
import 'brand.dart';

const _azul = azulMarca;
const _turquesa = azulMarca;
const _fundo = fundoMarca;

class TriagemApp extends StatelessWidget {
  const TriagemApp({super.key, this.controller, this.inicio});

  final EnsaioController? controller;
  final Widget? inicio;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Avaliações de atenção · PRS. REIS',
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _turquesa,
            primary: _turquesa,
          ),
          scaffoldBackgroundColor: _fundo,
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 38,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: _azul,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: _azul,
            ),
            titleLarge: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: _azul,
            ),
            bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: _azul),
            bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: _azul),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(18),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: inicio ?? _EnsaioHome(controller: controller),
      );
}

class _EnsaioHome extends StatefulWidget {
  const _EnsaioHome({this.controller});
  final EnsaioController? controller;

  @override
  State<_EnsaioHome> createState() => _EnsaioHomeState();
}

class _EnsaioHomeState extends State<_EnsaioHome> with WidgetsBindingObserver {
  late final EnsaioController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? EnsaioController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller.interromper('O aplicativo saiu de foco durante o ensaio');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => PopScope(
          canPop: _controller.etapa == EtapaEnsaio.inicio,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_controller.etapa == EtapaEnsaio.teste ||
                _controller.etapa == EtapaEnsaio.treino) {
              _controller.interromper();
            } else {
              _controller.apagarEReiniciar();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: _azul,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 78,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRS. REIS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 20,
                    ),
                  ),
                  Text('Triagem de atenção', style: TextStyle(fontSize: 13)),
                ],
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Chip(
                    avatar: Icon(Icons.science_outlined, size: 18),
                    label: Text('Ensaio interno'),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: switch (_controller.etapa) {
                EtapaEnsaio.inicio => _Welcome(controller: _controller),
                EtapaEnsaio.identificacao => _Identification(
                    controller: _controller,
                  ),
                EtapaEnsaio.treino => _Sequence(
                    controller: _controller,
                    treino: true,
                  ),
                EtapaEnsaio.pronto => _Ready(controller: _controller),
                EtapaEnsaio.teste => _Sequence(
                    controller: _controller,
                    treino: false,
                  ),
                EtapaEnsaio.resultado => _Results(controller: _controller),
              },
            ),
          ),
        ),
      );
}

class _Page extends StatelessWidget {
  const _Page({required this.children, this.maxWidth = 880});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _Panel(
        color: const Color(0xFFE5EFF1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _turquesa),
            const SizedBox(width: 14),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.controller});
  final EnsaioController controller;

  @override
  Widget build(BuildContext context) => _Page(
        children: [
          _Panel(
            color: _azul,
            child: _WelcomeHero(controller: controller),
          ),
          const SizedBox(height: 20),
          const _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Instruction(
                  number: '01',
                  title: 'Prepare-se',
                  text: 'Use um código anônimo e escolha o momento da jornada.',
                ),
                SizedBox(height: 20),
                _Instruction(
                  number: '02',
                  title: 'Pratique',
                  text:
                      'Experimente uma grade de nove números, sem guardar o treino.',
                ),
                SizedBox(height: 20),
                _Instruction(
                  number: '03',
                  title: 'Faça a sequência',
                  text: 'Toque de 1 a 36 em ordem, em até três minutos.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Notice(
            'Demonstração local para voluntários. Os dados ficam só na memória e desaparecem ao fechar. Nenhum dado é enviado. Este ensaio não define aptidão para conduzir.',
          ),
        ],
      );
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.controller});
  final EnsaioController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final marca = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/logo_prs_reis_3x4.png',
              width: 132,
              height: 176,
              fit: BoxFit.contain,
              semanticLabel: 'PRS. REIS Consultoria e Assessoria Técnica',
            ),
          );
          final conteudo = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 54,
                color: Color(0xFF83D9D9),
              ),
              const SizedBox(height: 24),
              Text(
                'Um passo de cada vez.\nDo 1 ao 36.',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 18),
              const Text(
                'Conheça o fluxo de atenção em um ensaio interno, com treino antes de começar.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: Color(0xFFD9E9F0),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('comecar'),
                onPressed: controller.abrirIdentificacao,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _azul,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Começar ensaio'),
              ),
            ],
          );
          if (constraints.maxWidth >= 640) {
            return Row(
              children: [
                Expanded(child: conteudo),
                const SizedBox(width: 36),
                marca,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [conteudo, const SizedBox(height: 24), marca],
          );
        },
      );
}

class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _fundo,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: const TextStyle(
                  color: _turquesa, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      );
}

class _Identification extends StatefulWidget {
  const _Identification({required this.controller});
  final EnsaioController controller;

  @override
  State<_Identification> createState() => _IdentificationState();
}

class _IdentificationState extends State<_Identification> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _codigo;
  late Momento _momento;
  bool _ciencia = false;

  @override
  void initState() {
    super.initState();
    _codigo = TextEditingController(text: widget.controller.participante);
    _momento = widget.controller.momento;
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!_form.currentState!.validate()) return;
    widget.controller.iniciarTreino(_codigo.text, _momento, ciencia: _ciencia);
  }

  @override
  Widget build(BuildContext context) => _Page(
        maxWidth: 720,
        children: [
          Text(
            'Antes de começar',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Escolha um lugar tranquilo e apoie o tablet em uma superfície estável.',
          ),
          const SizedBox(height: 24),
          _Panel(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('codigo-participante'),
                    controller: _codigo,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 15,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código anônimo do participante',
                      hintText: 'Exemplo: ENSAIO-01',
                      helperText:
                          'Use 2 a 8 letras, hífen e 2 a 6 números. Sem nome ou CPF.',
                      helperMaxLines: 3,
                      errorMaxLines: 2,
                    ),
                    validator: (value) => RegExp(r'^[A-Z]{2,8}-[0-9]{2,6}$')
                            .hasMatch((value ?? '').trim().toUpperCase())
                        ? null
                        : 'Informe um código como ENSAIO-01.',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Momento da jornada',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Início da jornada'),
                        selected: _momento == Momento.inicio,
                        onSelected: (_) =>
                            setState(() => _momento = Momento.inicio),
                      ),
                      ChoiceChip(
                        label: const Text('Durante a jornada'),
                        selected: _momento == Momento.durante,
                        onSelected: (_) =>
                            setState(() => _momento = Momento.durante),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    key: const Key('ciencia'),
                    value: _ciencia,
                    onChanged: (value) =>
                        setState(() => _ciencia = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Entendi que participo de uma demonstração interna voluntária.',
                    ),
                    subtitle: const Text(
                      'Posso interromper a qualquer momento. O resultado não é uma avaliação de aptidão.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('ir-treino'),
                    onPressed: _ciencia ? _continuar : null,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Ir para o treino'),
                  ),
                  TextButton(
                    onPressed: widget.controller.apagarEReiniciar,
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _Notice(
            'Apenas código anônimo. Não há cadastro, foto, questionário de saúde ou conexão com a empresa nesta demonstração.',
            icon: Icons.lock_outline,
          ),
        ],
      );
}

class _Ready extends StatelessWidget {
  const _Ready({required this.controller});
  final EnsaioController controller;

  @override
  Widget build(BuildContext context) => _Page(
        maxWidth: 720,
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt, color: _turquesa, size: 52),
                const SizedBox(height: 20),
                Text(
                  'Treino concluído',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Agora a grade terá 36 números. Toque em cada um em ordem crescente, começando pelo 1.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Você terá até três minutos. Um toque fora da ordem conta como erro e a sequência continua no mesmo número.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'O tempo começa quando a grade aparecer. Se o aplicativo sair de foco, a sessão será encerrada como incompleta.',
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('iniciar-teste'),
                  onPressed: controller.prepararTeste,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar sequência'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.apagarEReiniciar,
                  child: const Text('Encerrar demonstração'),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Sequence extends StatefulWidget {
  const _Sequence({required this.controller, required this.treino});
  final EnsaioController controller;
  final bool treino;

  @override
  State<_Sequence> createState() => _SequenceState();
}

class _SequenceState extends State<_Sequence> {
  @override
  void initState() {
    super.initState();
    if (!widget.treino) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.iniciarCronometro();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final segundos = controller.segundosRestantes;
    final tempo =
        '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
    return LayoutBuilder(
      builder: (context, viewport) => _Page(
        maxWidth: 700,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.treino ? 'Vamos praticar' : 'Sequência de atenção',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.treino
                          ? 'Treino livre · seus toques não serão guardados'
                          : 'Toque nos números em ordem crescente.',
                    ),
                  ],
                ),
              ),
              if (!widget.treino)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Semantics(
                    label: 'Tempo restante: $segundos segundos',
                    child: Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(
                        tempo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _Panel(
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Próximo número: ${controller.proximo}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                Text(
                  '${controller.acertos}/${controller.grade.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.treino)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                controller.ultimoToqueIncorreto
                    ? 'Esse número está fora da ordem. Procure o ${controller.proximo}.'
                    : 'Encontre o número indicado e toque uma vez.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final colunas = widget.treino ? 3 : 6;
              final minimo = colunas * 48.0 + (colunas - 1) * 8;
              final maximo = (viewport.maxHeight - (widget.treino ? 350 : 310))
                  .clamp(minimo, 620.0);
              final largura =
                  constraints.maxWidth.clamp(minimo, maximo).toDouble();
              return Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: largura,
                    child: GridView.builder(
                      key: Key(widget.treino ? 'grade-treino' : 'grade-teste'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.grade.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: colunas,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) => _NumberCell(
                        numero: controller.grade[index],
                        onPressed: controller.tocar,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => controller.interromper(),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(
              widget.treino ? 'Sair do treino' : 'Interromper ensaio',
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberCell extends StatefulWidget {
  const _NumberCell({required this.numero, required this.onPressed});
  final int numero;
  final ValueChanged<int> onPressed;

  @override
  State<_NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<_NumberCell> {
  bool _focoVisivel = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Número ${widget.numero}',
        onTap: () => widget.onPressed(widget.numero),
        excludeSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focoVisivel = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed(widget.numero);
                return null;
              },
            ),
          },
          child: Listener(
            key: Key('numero-${widget.numero}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => widget.onPressed(widget.numero),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _focoVisivel ? _turquesa : const Color(0xFFCCD8E2),
                  width: _focoVisivel ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${widget.numero}',
                  style: const TextStyle(
                    fontSize: 27,
                    color: _azul,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _Results extends StatelessWidget {
  const _Results({required this.controller});
  final EnsaioController controller;

  String _tempo(num? ms) =>
      ms == null ? '—' : '${(ms / 1000).toStringAsFixed(2)} s';

  @override
  Widget build(BuildContext context) {
    final resultado = controller.resultado!;
    final metricas = resultado.metricas;
    final completa = resultado.status == StatusSessao.completa;
    return _Page(
      children: [
        Text(
          completa ? 'Sequência concluída' : 'Sessão incompleta',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.participante} · ${controller.momento == Momento.inicio ? 'Início da jornada' : 'Durante a jornada'}',
        ),
        if (controller.motivoInterrupcao != null) ...[
          const SizedBox(height: 10),
          Text(controller.motivoInterrupcao!),
        ],
        const SizedBox(height: 24),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Métricas deste ensaio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Valores observados nesta sessão. Sem classificação de aptidão.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 30,
                runSpacing: 24,
                children: [
                  _Metric(
                    label: 'Tempo total',
                    value: _tempo(metricas.tempoTotalMs),
                  ),
                  _Metric(
                    label: 'Primeiro toque',
                    value: _tempo(metricas.tempoPrimeiroToqueMs),
                  ),
                  _Metric(
                    label: 'Toques fora da ordem',
                    value: '${metricas.erros}',
                  ),
                  _Metric(
                    label: 'Números concluídos',
                    value: '${controller.acertos}/36',
                  ),
                  _Metric(
                    label: 'Intervalo médio entre acertos',
                    value: _tempo(metricas.mediaIntervaloMs),
                  ),
                  _Metric(
                    label: 'Desvio-padrão dos intervalos',
                    value: _tempo(metricas.dpIntervaloMs),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Tempo por bloco de nove números',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 28,
                runSpacing: 18,
                children: [
                  for (var i = 0; i < metricas.quartisMs.length; i++)
                    _Metric(
                      label: '${i * 9 + 1} a ${(i + 1) * 9}',
                      value: _tempo(metricas.quartisMs[i]),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '— indica que não há dados suficientes ou que o bloco não foi concluído.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Notice(
          'Resultado temporário, apenas nesta tela. Nada foi salvo ou enviado. Ao encerrar, o código e todas as métricas desta sessão serão apagados.',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('encerrar'),
          onPressed: controller.apagarEReiniciar,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Apagar sessão e voltar ao início'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      );
}
