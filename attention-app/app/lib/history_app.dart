import 'dart:async';

import 'brand.dart';
import 'employee_entry.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:triagem_core/triagem_core.dart';

import 'data/local_store.dart';
import 'data/models.dart';
import 'data/portal_api.dart';
import 'features/history/history_controller.dart';

const _navy = azulMarca;

class InicioHistorico extends StatefulWidget {
  const InicioHistorico({super.key, this.controller});
  final HistoricoController? controller;
  @override
  State<InicioHistorico> createState() => _InicioHistoricoState();
}

class _InicioHistoricoState extends State<InicioHistorico>
    with WidgetsBindingObserver {
  HistoricoController? _controller;
  late Future<void> _inicio;
  StreamSubscription<List<ConnectivityResult>>? _conectividade;
  Future<void> _abrir() async {
    final repo = widget.controller == null
        ? await RepositorioHistorico.abrir()
        : null;
    _controller =
        widget.controller ??
        HistoricoController(repositorio: repo!, portal: ApiPortal(repo.cofre));
    await _controller!.iniciar();
    if (widget.controller == null) {
      _conectividade = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((r) => r != ConnectivityResult.none) &&
            _controller?.contexto != null) {
          unawaited(_controller!.sincronizar());
        }
      }, onError: (Object _) {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicio = _abrir();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.interromper();
    } else if (_controller?.contexto != null) {
      unawaited(_controller!.sincronizar());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conectividade?.cancel();
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _inicio,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: _Pagina(
            children: [
              const Text('Não foi possível abrir o armazenamento protegido.'),
              Text('${snapshot.error}'),
              const Text(
                'O histórico existente não foi apagado. Preserve este aparelho.',
              ),
              FilledButton(
                onPressed: () => setState(() => _inicio = _abrir()),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final c = _controller!;
      return AnimatedBuilder(
        animation: c,
        builder: (context, _) => PopScope(
          canPop: !c.emAvaliacao,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) c.interromper();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  CabecalhoPrs(
                    conectado: c.contexto != null,
                    sair: c.emAvaliacao || c.ocupado || c.sincronizando
                        ? null
                        : c.sair,
                  ),
                  Expanded(
                    child: c.contexto == null
                        ? _Login(c: c)
                        : Column(
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * .2,
                                ),
                                child: SingleChildScrollView(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    color: const Color(0xFFEAF1F9),
                                    child: Text(
                                      '${c.contexto!.nomeEmpresa} · ${c.contexto!.nomeUsuario}${c.offline ? ' · Cadastro em cache' : ''}',
                                      softWrap: true,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: switch (c.tela) {
                                  TelaHistorico.inicio => _Cadastro(
                                    key: ValueKey(c.contexto!.escopo),
                                    c: c,
                                  ),
                                  TelaHistorico.treino => _Sequencia(
                                    key: const ValueKey('treino'),
                                    c: c,
                                    treino: true,
                                  ),
                                  TelaHistorico.pronto => _Pagina(
                                    children: [
                                      Text(
                                        'Treino concluído',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                      const Text(
                                        'Toque de 1 a 36, em ordem crescente, em até três minutos. A avaliação será registrada no histórico. Um toque fora de ordem conta como erro e a sequência não avança.',
                                      ),
                                      const Text(
                                        'Se o aplicativo sair de foco, a avaliação será encerrada como incompleta. O trecho salvo poderá ser recuperado.',
                                      ),
                                      FilledButton.icon(
                                        key: const Key('iniciar-avaliacao'),
                                        onPressed: c.preparar,
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Iniciar avaliação'),
                                      ),
                                      if (c.erro != null)
                                        _Mensagem(c.erro!, erro: true),
                                      TextButton(
                                        onPressed: c.voltar,
                                        child: const Text('Voltar'),
                                      ),
                                    ],
                                  ),
                                  TelaHistorico.preparando => const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          'Preparando o registro protegido…',
                                        ),
                                      ],
                                    ),
                                  ),
                                  TelaHistorico.teste => _Sequencia(
                                    key: const ValueKey('teste'),
                                    c: c,
                                    treino: false,
                                  ),
                                  TelaHistorico.salvando => _Pagina(
                                    children: [
                                      Text(
                                        'Preservando a avaliação',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                      const Text(
                                        'Aguarde a confirmação antes de sair desta tela.',
                                      ),
                                      if (c.ocupado)
                                        const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      if (c.erro != null) ...[
                                        _Mensagem(c.erro!, erro: true),
                                        FilledButton(
                                          onPressed: c.ocupado
                                              ? null
                                              : c.tentarSalvar,
                                          child: const Text(
                                            'Tentar salvar novamente',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  TelaHistorico.resultado => _Pagina(
                                    children: [
                                      if (c.atual != null)
                                        DetalheLocal(item: c.atual!),
                                      const _Mensagem(
                                        'Avaliação preservada no aparelho. Voltar ao início mantém o histórico.',
                                      ),
                                      FilledButton(
                                        onPressed: c.abrirHistorico,
                                        child: const Text(
                                          'Consultar histórico',
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: c.voltar,
                                        child: const Text('Nova avaliação'),
                                      ),
                                    ],
                                  ),
                                  TelaHistorico.historico => _Historico(c: c),
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Pagina extends StatelessWidget {
  const _Pagina({required this.children, this.maxWidth = 820});
  final double maxWidth;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 18), child: child),
          ],
        ),
      ),
    ),
  );
}

class _Mensagem extends StatelessWidget {
  const _Mensagem(this.texto, {this.erro = false});
  final String texto;
  final bool erro;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: erro ? const Color(0xFFFFE9E5) : const Color(0xFFE5EFF1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto),
    ),
  );
}

class _Login extends StatefulWidget {
  const _Login({required this.c});
  final HistoricoController c;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  bool _gestao = false;
  final _email = TextEditingController(), _senha = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (widget.c.ocupado || !_form.currentState!.validate()) return;
    final senha = _senha.text;
    _senha.clear();
    await widget.c.entrar(_email.text.trim(), senha);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final amplo = box.maxWidth >= 920;
      final marca = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: LogoPrs(horizontal: amplo, height: amplo ? 220 : 180),
          ),
          const SizedBox(height: 22),
          Text(
            'Atenção em cada jornada',
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontSize: amplo ? 38 : 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Avalie sua atenção e acompanhe seu histórico na PRS. REIS.',
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 24),
          const _Mensagem(
            'Cada avaliação fica salva no aparelho. O envio à plataforma é confirmado no histórico. O treino não gera registro.',
          ),
        ],
      );
      final acessoGestao = Container(
        padding: EdgeInsets.all(amplo ? 32 : 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDDE6F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, color: azulMarca, size: 28),
            const SizedBox(height: 16),
            Text(
              'Acesse sua conta',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Use seu acesso de gestão PRS. REIS para preparar o aparelho e selecionar o colaborador.',
            ),
            const SizedBox(height: 28),
            AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail da gestão',
                      ),
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : 'Informe o e-mail.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('login-senha'),
                      controller: _senha,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: const InputDecoration(labelText: 'Senha'),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Informe a senha.' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login-entrar'),
                      onPressed: widget.c.ocupado ? null : _entrar,
                      child: Text(
                        widget.c.ocupado ? 'Preparando acesso…' : 'Entrar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.c.erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _Mensagem(widget.c.erro!, erro: true),
              ),
            const SizedBox(height: 20),
            const Text(
              'Sua senha não é guardada no aparelho.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
      final acesso = !_gestao && widget.c.aceitaColaborador
          ? EntradaColaborador(
              controller: widget.c,
              abrirGestao: () => setState(() => _gestao = true),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                acessoGestao,
                if (widget.c.aceitaColaborador)
                  TextButton(
                    onPressed: widget.c.ocupado
                        ? null
                        : () => setState(() => _gestao = false),
                    child: const Text('Voltar ao acesso do colaborador'),
                  ),
              ],
            );
      return _Pagina(
        maxWidth: 1160,
        children: [
          const SizedBox(height: 10),
          if (amplo)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: marca),
                const SizedBox(width: 56),
                Expanded(flex: 5, child: acesso),
              ],
            )
          else ...[
            marca,
            acesso,
          ],
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Uso interno de acompanhamento. Os resultados não definem aptidão para conduzir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      );
    },
  );
}

class _Cadastro extends StatefulWidget {
  const _Cadastro({super.key, required this.c});
  final HistoricoController c;
  @override
  State<_Cadastro> createState() => _CadastroState();
}

class _CadastroState extends State<_Cadastro> {
  String? employee;
  int? scope;
  Momento momento = Momento.inicio;
  final unit = TextEditingController(), team = TextEditingController();
  @override
  void dispose() {
    unit.dispose();
    team.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, ctx = widget.c.contexto!;
    if (ctx.acessoPessoal) employee = ctx.usuarioId;
    return _Pagina(
      children: [
        Text(
          'Nova avaliação',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (ctx.empresas.length > 1)
          DropdownButtonFormField<String>(
            initialValue: ctx.empresaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Empresa deste aparelho',
            ),
            items: [
              for (final e in ctx.empresas)
                DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text(
                    e['name'] as String,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: c.ocupado || c.sincronizando
                ? null
                : (id) {
                    if (id != null) unawaited(c.trocarEmpresa(id));
                  },
          ),
        if (ctx.acessoPessoal)
          TextFormField(
            key: const Key('colaborador-pessoal'),
            initialValue: ctx.nomeUsuario,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Colaborador'),
          )
        else
          DropdownButtonFormField<String>(
            key: const Key('colaborador'),
            initialValue: employee,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Colaborador cadastrado',
            ),
            items: [
              for (final e in ctx.colaboradores)
                DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text(
                    '${e['name']} · ${e['employee_number']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() => employee = id),
          ),
        if (ctx.colaboradores.isEmpty)
          const _Mensagem(
            'Não há colaboradores ativos disponíveis. Atualize o cadastro pela plataforma.',
          ),
        if (ctx.escopos != null)
          DropdownButtonFormField<int>(
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Unidade e equipe autorizadas',
            ),
            items: [
              for (var i = 0; i < ctx.escopos!.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${ctx.escopos![i]['unit']} / ${ctx.escopos![i]['team']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => scope = v),
          )
        else ...[
          TextField(
            key: const Key('unidade'),
            controller: unit,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Unidade da avaliação',
            ),
          ),
          TextField(
            key: const Key('equipe'),
            controller: team,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Equipe da avaliação'),
          ),
        ],
        const Text(
          'O local informado identifica esta avaliação; não altera a lotação do colaborador.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Início da jornada'),
              selected: momento == Momento.inicio,
              onSelected: (_) => setState(() => momento = Momento.inicio),
            ),
            ChoiceChip(
              label: const Text('Durante a jornada'),
              selected: momento == Momento.durante,
              onSelected: (_) => setState(() => momento = Momento.durante),
            ),
          ],
        ),
        FilledButton.icon(
          key: const Key('praticar'),
          onPressed: c.ocupado || employee == null
              ? null
              : () {
                  final selected = scope == null ? null : ctx.escopos?[scope!];
                  c.praticar(
                    employee!,
                    selected?['unit'] as String? ?? unit.text,
                    selected?['team'] as String? ?? team.text,
                    momento,
                  );
                },
          icon: const Icon(Icons.school_outlined),
          label: const Text('Praticar antes da avaliação'),
        ),
        if (c.erro != null) _Mensagem(c.erro!, erro: true),
        if (c.aviso != null) _Mensagem(c.aviso!),
        OutlinedButton.icon(
          key: const Key('abrir-historico'),
          onPressed: c.abrirHistorico,
          icon: const Icon(Icons.history),
          label: Text(
            ctx.acessoPessoal
                ? 'Meu histórico (${c.registros.length})'
                : 'Histórico neste aparelho (${c.registros.length})',
          ),
        ),
        const _Mensagem(
          'Ambiente de teste interno. Os resultados registram tempo e sequência de toques, sem diagnóstico ou liberação para condução.',
        ),
      ],
    );
  }
}

class _Sequencia extends StatefulWidget {
  const _Sequencia({super.key, required this.c, required this.treino});
  final HistoricoController c;
  final bool treino;
  @override
  State<_Sequencia> createState() => _SequenciaState();
}

class _SequenciaState extends State<_Sequencia> {
  @override
  void initState() {
    super.initState();
    if (!widget.treino) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.c.iniciarCronometro();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return LayoutBuilder(
      builder: (context, viewport) => _Pagina(
        children: [
          Text(
            widget.treino ? 'Treino livre' : 'Avaliação em andamento',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  'Próximo número: ${c.proximo}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!widget.treino)
                Text(
                  '${c.segundosRestantes ~/ 60}:${(c.segundosRestantes % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          Text(
            widget.treino
                ? 'Toque de 1 a 9, em ordem. O treino é descartado.'
                : '${c.acertos}/36 alvos · cada toque é registrado no aparelho.',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final columns = widget.treino ? 3 : 6;
              final cell = MediaQuery.textScalerOf(context)
                  .scale(26)
                  .clamp(48.0, double.infinity);
              final minimum = columns * cell + (columns - 1) * 8;
              final available = (viewport.maxHeight - 280).clamp(
                minimum,
                620.0,
              );
              final width = box.maxWidth.clamp(minimum, available).toDouble();
              return Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        for (final n in c.grade) _Numero(n: n, tocar: c.tocar),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          OutlinedButton(
            onPressed: c.interromper,
            child: Text(
              widget.treino
                  ? 'Sair do treino'
                  : 'Interromper e salvar avaliação',
            ),
          ),
        ],
      ),
    );
  }
}

class _Numero extends StatefulWidget {
  const _Numero({required this.n, required this.tocar});
  final int n;
  final ValueChanged<int> tocar;
  @override
  State<_Numero> createState() => _NumeroState();
}

class _NumeroState extends State<_Numero> {
  bool _foco = false;
  int get n => widget.n;
  void tocar(int value) => widget.tocar(value);
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Número $n',
    onTap: () => tocar(n),
    excludeSemantics: true,
    child: FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _foco = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            tocar(n);
            return null;
          },
        ),
      },
      child: Listener(
        key: Key('alvo-$n'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if ((event.buttons & 1) != 0) tocar(n);
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _foco ? azulMarca : const Color(0xFFB6C6D2),
              width: _foco ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: _navy,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Historico extends StatelessWidget {
  const _Historico({required this.c});
  final HistoricoController c;
  @override
  Widget build(BuildContext context) => _Pagina(
    children: [
      Text(
        c.contexto?.acessoPessoal == true
            ? 'Meu histórico'
            : 'Histórico neste aparelho',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text(
        'Avaliações completas e incompletas são preservadas. Somente registros com envio confirmado aparecem no histórico central PRS. REIS.',
      ),
      FilledButton.icon(
        key: const Key('sincronizar'),
        onPressed: c.sincronizando ? null : () => c.sincronizar(manual: true),
        icon: const Icon(Icons.sync),
        label: Text(
          c.sincronizando
              ? 'Confirmando envios…'
              : c.contexto?.acessoPessoal == true
              ? 'Atualizar histórico e enviar pendentes'
              : 'Sincronizar pendentes',
        ),
      ),
      if (c.erro != null) _Mensagem(c.erro!, erro: true),
      if (c.aviso != null) _Mensagem(c.aviso!),
      if (c.carregandoHistorico)
        const Center(child: CircularProgressIndicator()),
      if (c.registros.isEmpty && !c.carregandoHistorico)
        Text(
          c.contexto?.acessoPessoal == true
              ? 'Nenhuma avaliação disponível no seu histórico.'
              : 'Nenhuma avaliação salva neste acesso e aparelho.',
        ),
      for (final item in c.registros)
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDDE6F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 760,
                    maxHeight: MediaQuery.sizeOf(context).height * .88,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Fechar'),
                        ),
                      ),
                      Flexible(
                        child: _Pagina(children: [DetalheLocal(item: item)]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.nome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('Matrícula: ${item.matricula}'),
                  Text(dataHoraLocal(item.inicio)),
                  const SizedBox(height: 12),
                  Text(
                    '${item.status == 'completa' ? 'Completa' : 'Incompleta'} · ${rotuloEnvio(item.envio)}',
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ver detalhes',
                          style: TextStyle(
                            color: azulMarca,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: azulMarca),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      if (c.proximoOffsetHistorico != null)
        OutlinedButton(
          onPressed: c.carregandoHistorico
              ? null
              : () => c.carregarHistoricoPessoal(mais: true),
          child: const Text('Carregar avaliações anteriores'),
        ),
      OutlinedButton(
        onPressed: c.voltar,
        child: const Text('Voltar ao início'),
      ),
    ],
  );
}

class DetalheLocal extends StatelessWidget {
  const DetalheLocal({super.key, required this.item});
  final AvaliacaoLocal item;
  String _tempo(Object? ms) =>
      ms is num ? '${(ms / 1000).toStringAsFixed(2)} s' : '—';
  @override
  Widget build(BuildContext context) {
    final m = item.metricas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.status == 'completa'
              ? 'Avaliação completa'
              : 'Avaliação incompleta',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 14),
        Text('${item.nome} · ${item.matricula}'),
        Text(
          '${item.json['companyName']} · ${item.json['unit']} / ${item.json['team']}',
        ),
        Text('Início: ${dataHoraLocal(item.inicio)} (horário do aparelho)'),
        const SizedBox(height: 16),
        _Mensagem(rotuloEnvio(item.envio)),
        if (item.erro != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(item.erro!),
          ),
        if (item.json['interruption'] != null)
          Text('${item.json['interruption']}'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [
              for (final entry in <String, String>{
                'Tempo total': _tempo(m['tempo_total_ms']),
                'Primeiro toque': _tempo(m['tempo_primeiro_toque_ms']),
                'Erros de sequência': '${m['erros']}',
                'Intervalo médio': _tempo(m['media_intervalo_ms']),
                'Desvio dos intervalos': _tempo(m['dp_intervalo_ms']),
              }.entries)
                SizedBox(
                  width: box.maxWidth < 404
                      ? box.maxWidth
                      : (box.maxWidth - 24) / 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key),
                      Text(
                        entry.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Tempo por bloco de nove números'),
        Wrap(
          spacing: 20,
          children: [
            for (var i = 0; i < 4; i++)
              Text(
                '${i * 9 + 1}–${(i + 1) * 9}: ${_tempo((m['quartis_ms'] as List)[i])}',
              ),
          ],
        ),
        const SizedBox(height: 20),
        SelectableText('ID: ${item.id}', style: const TextStyle(fontSize: 12)),
        const Text(
          'Valores observados, sem classificação de aptidão. Protocolo sequencia-v1.',
        ),
      ],
    );
  }
}
