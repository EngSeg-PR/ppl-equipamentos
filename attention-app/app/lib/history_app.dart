import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:triagem_core/triagem_core.dart';
import 'data/local_store.dart';
import 'data/models.dart';
import 'data/portal_api.dart';
import 'features/history/history_controller.dart';

const _navy = Color(0xFF142D45);

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
    final repo =
        widget.controller == null ? await RepositorioHistorico.abrir() : null;
    _controller = widget.controller ??
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
              body: _Pagina(children: [
            const Text('Não foi possível abrir o armazenamento protegido.'),
            Text('${snapshot.error}'),
            const Text(
                'O histórico existente não foi apagado. Preserve este aparelho.'),
            FilledButton(
                onPressed: () => setState(() => _inicio = _abrir()),
                child: const Text('Tentar novamente'))
          ]));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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
                    appBar: AppBar(
                        title: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRS. REIS',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2)),
                              Text('Avaliações de atenção',
                                  style: TextStyle(fontSize: 13))
                            ]),
                        backgroundColor: Colors.white,
                        actions: [
                          if (c.contexto != null)
                            IconButton(
                                tooltip: 'Sair da conta sem apagar o histórico',
                                onPressed: c.emAvaliacao ||
                                        c.ocupado ||
                                        c.sincronizando
                                    ? null
                                    : c.sair,
                                icon: const Icon(Icons.logout))
                        ]),
                    body: SafeArea(
                        child: c.contexto == null
                            ? _Login(c: c)
                            : Column(children: [
                                Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    color: const Color(0xFFE5EFF1),
                                    child: Text(
                                        '${c.contexto!.nomeEmpresa} · ${c.contexto!.nomeUsuario}${c.offline ? ' · Cadastro em cache' : ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)),
                                Expanded(
                                    child: switch (c.tela) {
                                  TelaHistorico.inicio => _Cadastro(
                                      key: ValueKey(c.contexto!.escopo), c: c),
                                  TelaHistorico.treino => _Sequencia(
                                      key: const ValueKey('treino'),
                                      c: c,
                                      treino: true),
                                  TelaHistorico.pronto => _Pagina(children: [
                                      Text('Treino concluído',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      const Text(
                                          'Toque de 1 a 36, em ordem crescente, em até três minutos. A avaliação será registrada no histórico. Um toque fora de ordem conta como erro e a sequência não avança.'),
                                      const Text(
                                          'Se o aplicativo sair de foco, a avaliação será encerrada como incompleta. O trecho salvo poderá ser recuperado.'),
                                      FilledButton.icon(
                                          key: const Key('iniciar-avaliacao'),
                                          onPressed: c.preparar,
                                          icon: const Icon(Icons.play_arrow),
                                          label:
                                              const Text('Iniciar avaliação')),
                                      if (c.erro != null)
                                        _Mensagem(c.erro!, erro: true),
                                      TextButton(
                                          onPressed: c.voltar,
                                          child: const Text('Voltar'))
                                    ]),
                                  TelaHistorico.preparando => const Center(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text(
                                              'Preparando o registro protegido…')
                                        ])),
                                  TelaHistorico.teste => _Sequencia(
                                      key: const ValueKey('teste'),
                                      c: c,
                                      treino: false),
                                  TelaHistorico.salvando => _Pagina(children: [
                                      Text('Preservando a avaliação',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      const Text(
                                          'Aguarde a confirmação antes de sair desta tela.'),
                                      if (c.ocupado)
                                        const Center(
                                            child: CircularProgressIndicator()),
                                      if (c.erro != null) ...[
                                        _Mensagem(c.erro!, erro: true),
                                        FilledButton(
                                            onPressed: c.ocupado
                                                ? null
                                                : c.tentarSalvar,
                                            child: const Text(
                                                'Tentar salvar novamente'))
                                      ]
                                    ]),
                                  TelaHistorico.resultado => _Pagina(children: [
                                      if (c.atual != null)
                                        DetalheLocal(item: c.atual!),
                                      const _Mensagem(
                                          'Avaliação preservada no aparelho. Voltar ao início mantém o histórico.'),
                                      FilledButton(
                                          onPressed: c.abrirHistorico,
                                          child: const Text(
                                              'Consultar histórico')),
                                      OutlinedButton(
                                          onPressed: c.voltar,
                                          child: const Text('Nova avaliação'))
                                    ]),
                                  TelaHistorico.historico => _Historico(c: c),
                                }),
                              ])),
                  ),
                ));
      });
}

class _Pagina extends StatelessWidget {
  const _Pagina({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in children)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: child)
                  ]))));
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
              borderRadius: BorderRadius.circular(12)),
          child: Text(texto)));
}

class _Login extends StatefulWidget {
  const _Login({required this.c});
  final HistoricoController c;
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _email = TextEditingController(), _senha = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Pagina(children: [
        Text('Avaliações com histórico',
            style: Theme.of(context).textTheme.headlineLarge),
        const Text(
            'Entre com a conta de gestão PRS. REIS para preparar o aparelho. O condutor será selecionado pelo cadastro da empresa.'),
        const _Mensagem(
            'Cada avaliação é salva no aparelho e enviada à plataforma quando houver confirmação de conexão. Treino não gera registro. Os valores observados não definem aptidão para conduzir.'),
        Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                      key: const Key('login-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration:
                          const InputDecoration(labelText: 'E-mail da gestão'),
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : 'Informe o e-mail.'),
                  const SizedBox(height: 18),
                  TextFormField(
                      key: const Key('login-senha'),
                      controller: _senha,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Informe a senha.' : null),
                  const SizedBox(height: 18),
                  FilledButton(
                      key: const Key('login-entrar'),
                      onPressed: widget.c.ocupado
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              final senha = _senha.text;
                              _senha.clear();
                              await widget.c.entrar(_email.text, senha);
                            },
                      child: Text(
                          widget.c.ocupado ? 'Preparando acesso…' : 'Entrar')),
                ])),
        if (widget.c.erro != null) _Mensagem(widget.c.erro!, erro: true),
        const Text(
            'A senha não é guardada. A sessão e as chaves de proteção ficam no armazenamento protegido do aparelho.'),
      ]);
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
    return _Pagina(children: [
      Text('Nova avaliação', style: Theme.of(context).textTheme.headlineMedium),
      if (ctx.empresas.length > 1)
        DropdownButtonFormField<String>(
            initialValue: ctx.empresaId,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Empresa deste aparelho'),
            items: [
              for (final e in ctx.empresas)
                DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(e['name'] as String,
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: c.ocupado || c.sincronizando
                ? null
                : (id) {
                    if (id != null) unawaited(c.trocarEmpresa(id));
                  }),
      DropdownButtonFormField<String>(
          key: const Key('colaborador'),
          initialValue: employee,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Colaborador cadastrado'),
          items: [
            for (final e in ctx.colaboradores)
              DropdownMenuItem(
                  value: e['id'] as String,
                  child: Text('${e['name']} · ${e['employee_number']}',
                      overflow: TextOverflow.ellipsis))
          ],
          onChanged: (id) => setState(() => employee = id)),
      if (ctx.colaboradores.isEmpty)
        const _Mensagem(
            'Não há colaboradores ativos disponíveis. Atualize o cadastro pela plataforma.'),
      if (ctx.escopos != null)
        DropdownButtonFormField<int>(
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Unidade e equipe autorizadas'),
            items: [
              for (var i = 0; i < ctx.escopos!.length; i++)
                DropdownMenuItem(
                    value: i,
                    child: Text(
                        '${ctx.escopos![i]['unit']} / ${ctx.escopos![i]['team']}',
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: (v) => setState(() => scope = v))
      else ...[
        TextField(
            key: const Key('unidade'),
            controller: unit,
            maxLength: 160,
            decoration:
                const InputDecoration(labelText: 'Unidade da avaliação')),
        TextField(
            key: const Key('equipe'),
            controller: team,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Equipe da avaliação'))
      ],
      const Text(
          'O local informado identifica esta avaliação; não altera a lotação do colaborador.'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        ChoiceChip(
            label: const Text('Início da jornada'),
            selected: momento == Momento.inicio,
            onSelected: (_) => setState(() => momento = Momento.inicio)),
        ChoiceChip(
            label: const Text('Durante a jornada'),
            selected: momento == Momento.durante,
            onSelected: (_) => setState(() => momento = Momento.durante))
      ]),
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
                      momento);
                },
          icon: const Icon(Icons.school_outlined),
          label: const Text('Praticar antes da avaliação')),
      if (c.erro != null) _Mensagem(c.erro!, erro: true),
      if (c.aviso != null) _Mensagem(c.aviso!),
      OutlinedButton.icon(
          key: const Key('abrir-historico'),
          onPressed: c.abrirHistorico,
          icon: const Icon(Icons.history),
          label: Text('Histórico neste aparelho (${c.registros.length})')),
      const _Mensagem(
          'Ambiente de teste interno. Os resultados registram tempo e sequência de toques, sem diagnóstico ou liberação para condução.'),
    ]);
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
        builder: (context, viewport) => _Pagina(children: [
              Text(widget.treino ? 'Treino livre' : 'Avaliação em andamento',
                  style: Theme.of(context).textTheme.headlineMedium),
              Row(children: [
                Expanded(
                    child: Semantics(
                        liveRegion: true,
                        child: Text('Próximo número: ${c.proximo}',
                            style: Theme.of(context).textTheme.titleLarge))),
                if (!widget.treino)
                  Text(
                      '${c.segundosRestantes ~/ 60}:${(c.segundosRestantes % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold))
              ]),
              Text(widget.treino
                  ? 'Toque de 1 a 9, em ordem. O treino é descartado.'
                  : '${c.acertos}/36 alvos · cada toque é registrado no aparelho.'),
              LayoutBuilder(builder: (context, box) {
                final columns = widget.treino ? 3 : 6;
                final minimum = columns * 48.0 + (columns - 1) * 8;
                final available =
                    (viewport.maxHeight - 280).clamp(minimum, 620.0);
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
                                  for (final n in c.grade)
                                    _Numero(n: n, tocar: c.tocar)
                                ]))));
              }),
              OutlinedButton(
                  onPressed: c.interromper,
                  child: Text(widget.treino
                      ? 'Sair do treino'
                      : 'Interromper e salvar avaliação')),
            ]));
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.n, required this.tocar});
  final int n;
  final ValueChanged<int> tocar;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: 'Número $n',
      onTap: () => tocar(n),
      excludeSemantics: true,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent()
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            tocar(n);
            return null;
          })
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
                    border: Border.all(color: const Color(0xFFB6C6D2)),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$n',
                    style: const TextStyle(
                        color: _navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)))),
      ));
}

class _Historico extends StatelessWidget {
  const _Historico({required this.c});
  final HistoricoController c;
  @override
  Widget build(BuildContext context) => _Pagina(children: [
        Text('Histórico neste aparelho',
            style: Theme.of(context).textTheme.headlineMedium),
        const Text(
            'Avaliações completas e incompletas são preservadas. Somente registros com envio confirmado aparecem no histórico central PRS. REIS.'),
        FilledButton.icon(
            key: const Key('sincronizar'),
            onPressed:
                c.sincronizando ? null : () => c.sincronizar(manual: true),
            icon: const Icon(Icons.sync),
            label: Text(c.sincronizando
                ? 'Confirmando envios…'
                : 'Sincronizar pendentes')),
        if (c.erro != null) _Mensagem(c.erro!, erro: true),
        if (c.aviso != null) _Mensagem(c.aviso!),
        if (c.registros.isEmpty)
          const Text('Nenhuma avaliação salva neste acesso e aparelho.'),
        for (final item in c.registros)
          Card(
              child: ListTile(
                  isThreeLine: true,
                  title: Text('${item.nome} · ${item.matricula}'),
                  subtitle: Text(
                      '${item.inicio.toLocal()}\n${item.status == 'completa' ? 'Completa' : 'Incompleta'} · ${rotuloEnvio(item.envio)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: _Pagina(children: [
                                DetalheLocal(item: item),
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Fechar'))
                              ])))))),
        OutlinedButton(
            onPressed: c.voltar, child: const Text('Voltar ao início')),
      ]);
}

class DetalheLocal extends StatelessWidget {
  const DetalheLocal({super.key, required this.item});
  final AvaliacaoLocal item;
  String _tempo(Object? ms) =>
      ms is num ? '${(ms / 1000).toStringAsFixed(2)} s' : '—';
  @override
  Widget build(BuildContext context) {
    final m = item.metricas;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          item.status == 'completa'
              ? 'Avaliação completa'
              : 'Avaliação incompleta',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 14),
      Text('${item.nome} · ${item.matricula}'),
      Text(
          '${item.json['companyName']} · ${item.json['unit']} / ${item.json['team']}'),
      Text('Início: ${item.inicio.toLocal()}'),
      const SizedBox(height: 16),
      _Mensagem(rotuloEnvio(item.envio)),
      if (item.erro != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(item.erro!)),
      if (item.json['interruption'] != null)
        Text('${item.json['interruption']}'),
      const SizedBox(height: 16),
      Wrap(spacing: 24, runSpacing: 20, children: [
        for (final entry in <String, String>{
          'Tempo total': _tempo(m['tempo_total_ms']),
          'Primeiro toque': _tempo(m['tempo_primeiro_toque_ms']),
          'Erros de sequência': '${m['erros']}',
          'Intervalo médio': _tempo(m['media_intervalo_ms']),
          'Desvio dos intervalos': _tempo(m['dp_intervalo_ms'])
        }.entries)
          SizedBox(
              width: 190,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key),
                    Text(entry.value,
                        style: Theme.of(context).textTheme.titleLarge)
                  ])),
      ]),
      const SizedBox(height: 20),
      const Text('Tempo por bloco de nove números'),
      Wrap(spacing: 20, children: [
        for (var i = 0; i < 4; i++)
          Text(
              '${i * 9 + 1}–${(i + 1) * 9}: ${_tempo((m['quartis_ms'] as List)[i])}')
      ]),
      const SizedBox(height: 20),
      SelectableText('ID: ${item.id}', style: const TextStyle(fontSize: 12)),
      const Text(
          'Aplicativo 0.2.0 · Protocolo sequencia-v1. Valores observados, sem classificação de aptidão.'),
    ]);
  }
}
