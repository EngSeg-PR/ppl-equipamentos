import 'package:flutter/material.dart';

import 'brand.dart';
import 'data/employee_access.dart';
import 'features/history/history_controller.dart';

class EntradaColaborador extends StatefulWidget {
  const EntradaColaborador({
    super.key,
    required this.controller,
    required this.abrirGestao,
  });
  final HistoricoController controller;
  final VoidCallback abrirGestao;
  @override
  State<EntradaColaborador> createState() => _EntradaColaboradorState();
}

class _EntradaColaboradorState extends State<EntradaColaborador> {
  late Future<List<Map<String, dynamic>>> _empresas;
  Future<List<Map<String, dynamic>>>? _colaboradores;
  final _matricula = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _empresa, _colaborador;
  AcessoColaborador get _portal =>
      widget.controller.portal as AcessoColaborador;

  @override
  void initState() {
    super.initState();
    _empresas = _portal.empresasDisponiveis();
  }

  @override
  void dispose() {
    _matricula.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (widget.controller.ocupado || !_form.currentState!.validate()) return;
    final senha = _matricula.text.trim();
    _matricula.clear();
    await widget.controller.entrarColaborador(_empresa!, _colaborador!, senha);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 22 : 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDDE6F0)),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.badge_outlined, color: azulMarca, size: 30),
          const SizedBox(height: 16),
          Text(
            'Acesso do colaborador',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecione sua empresa e seu nome. Use sua matrícula como senha.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Realize sua avaliação visual de atenção e consulte seu histórico pessoal.',
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _empresas,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _FalhaEntrada(
                  mensagem: 'Não foi possível carregar as empresas.',
                  tentar: () =>
                      setState(() => _empresas = _portal.empresasDisponiveis()),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Text(
                  'Nenhuma empresa está disponível para avaliação. Consulte a gestão.',
                );
              }
              return DropdownButtonFormField<String>(
                key: const Key('entrada-empresa'),
                initialValue: _empresa,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Empresa'),
                items: [
                  for (final e in snapshot.data!)
                    DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text(
                        e['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (value) =>
                    value == null ? 'Selecione sua empresa.' : null,
                onChanged: widget.controller.ocupado
                    ? null
                    : (value) {
                        _matricula.clear();
                        setState(() {
                          _empresa = value;
                          _colaborador = null;
                          _colaboradores = value == null
                              ? null
                              : _portal.colaboradoresDaEmpresa(value);
                        });
                      },
              );
            },
          ),
          if (_empresa != null) ...[
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_empresa),
              future: _colaboradores,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _FalhaEntrada(
                    mensagem: 'Não foi possível carregar os colaboradores desta empresa.',
                    tentar: () => setState(
                      () => _colaboradores = _portal.colaboradoresDaEmpresa(
                        _empresa!,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return const Text(
                    'Não há colaboradores ativos nesta empresa. Consulte a gestão para conferir o cadastro existente.',
                  );
                }
                return DropdownButtonFormField<String>(
                  key: ValueKey('entrada-colaborador-$_empresa'),
                  initialValue: _colaborador,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Colaborador'),
                  items: [
                    for (final e in snapshot.data!)
                      DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(
                          e['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Selecione seu nome.' : null,
                  onChanged: widget.controller.ocupado
                      ? null
                      : (value) {
                          _matricula.clear();
                          setState(() => _colaborador = value);
                        },
                );
              },
            ),
          ],
          if (_colaborador != null) ...[
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('entrada-matricula'),
              controller: _matricula,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Matrícula (senha)'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Informe sua matrícula.'
                  : null,
              onFieldSubmitted: (_) => _entrar(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('entrada-entrar'),
              onPressed: widget.controller.ocupado ? null : _entrar,
              child: Text(
                widget.controller.ocupado ? 'Conferindo acesso…' : 'Entrar',
              ),
            ),
          ],
          if (widget.controller.erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  widget.controller.erro!,
                  style: const TextStyle(color: Color(0xFF9C2323)),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Seu acesso permite realizar avaliações e consultar somente o seu histórico.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.controller.ocupado ? null : widget.abrirGestao,
            child: const Text('Acesso da gestão'),
          ),
        ],
      ),
    ),
  );
}

class _FalhaEntrada extends StatelessWidget {
  const _FalhaEntrada({required this.mensagem, required this.tentar});
  final String mensagem;
  final VoidCallback tentar;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(mensagem),
      TextButton(onPressed: tentar, child: const Text('Tentar novamente')),
    ],
  );
}
