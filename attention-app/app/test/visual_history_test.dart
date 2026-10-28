import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagem_atencao_app/app.dart';
import 'package:triagem_atencao_app/data/models.dart';
import 'package:triagem_atencao_app/features/history/history_controller.dart';
import 'package:triagem_atencao_app/visual_test.dart';
import 'package:triagem_core/triagem_core.dart';

import 'history_test.dart' as f;

HistoricoController controller(f.Fixture x) => HistoricoController(
  repositorio: x.repo,
  portal: x.portal,
  relogio: x.clock,
  sincronizacaoAutomatica: false,
);
Future<void> drenar() async {
  for (var i = 0; i < 80; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void avancarEnsaio(
  HistoricoController c,
  f.Clock clock, {
  bool responder = true,
}) {
  final e = c.visual!;
  if (e.fase == FaseVisual.pausa) {
    clock.now += 200;
    c.atualizarVisual();
  }
  clock.now = e.prazo;
  c.atualizarVisual();
  c.apresentarVisual();
  clock.now += 200;
  if (responder && !e.mover) c.responderVisual('pointer');
  clock.now += 800;
  c.atualizarVisual();
}

Future<void> preparar(HistoricoController c, f.Fixture x) async {
  await c.entrar('operador@teste.invalid', 'APENAS TESTE');
  c.praticar(f.eid, 'PORTO', 'MECÂNICA', Momento.inicio);
  x.clock.now = 6000;
  c.atualizarVisual();
  for (var i = 0; i < 2; i++) {
    avancarEnsaio(c, x.clock);
  }
  expect(c.tela, TelaHistorico.pronto);
  expect(await x.repo.listar(c.contexto!.escopo), isEmpty);
  await c.preparar();
  c.iniciarCronometro();
}

void main() {
  test('treino separado, 30 apresentações, histórico cifrado e reenvio idempotente', () async {
    final x = f.Fixture(), c = controller(x);
    addTearDown(c.dispose);
    await preparar(c, x);
    for (var i = 0; i < 30; i++) {
      avancarEnsaio(c, x.clock);
    }
    await drenar();
    expect(c.tela, TelaHistorico.resultado);
    expect(c.salvo, isTrue);
    expect(c.atual!.visual, isTrue);
    expect(c.atual!.metricas['respostas_validas'], 24);
    expect(c.atual!.metricas['omissoes'], 0);
    expect(c.atual!.metricas['mediana_reacao_ms'], 200);
    expect(c.atual!.json['trials'], hasLength(30));
    expect(c.atual!.duracaoMs, lessThan(84000));
    expect(c.atual!.paraServidor().containsKey('grid'), isFalse);
    expect(x.dados.values.values.join(), isNot(contains('PESSOA DE TESTE')));
    await c.sincronizar(manual: true);
    await c.sincronizar(manual: true);
    expect(c.atual!.envio, SituacaoEnvio.sincronizado);
    expect(x.portal.recebidos.length, 1);
  });
  test('reabertura conserva estímulo e resposta; não transforma trecho em teste completo', () async {
    final x = f.Fixture(), c = controller(x);
    await preparar(c, x);
    avancarEnsaio(c, x.clock);
    await drenar();
    c.dispose();
    final outro = controller(x);
    addTearDown(outro.dispose);
    await outro.iniciar();
    expect(outro.registros, hasLength(1));
    final r = outro.registros.single;
    expect(r.status, 'incompleta');
    expect(r.json['trials'], hasLength(1));
    expect(r.metricas['apresentados'], 1);
    expect(r.paraServidor()['interruption'], contains('recuperada'));
  });
  test('perda de foco e prazo preservam o trecho; não inventam omissão no sinal aberto', () async {
    final x = f.Fixture(), c = controller(x);
    addTearDown(c.dispose);
    await preparar(c, x);
    x.clock.now = c.visual!.prazo;
    c.atualizarVisual();
    c.apresentarVisual();
    x.clock.now += 100;
    c.interromper();
    await drenar();
    expect(c.atual!.status, 'incompleta');
    expect(c.atual!.metricas['omissoes'], 0);
    c.voltar();
    c.praticar(f.eid, 'PORTO', 'MECÂNICA', Momento.inicio);
    x.clock.now = 6000;
    c.atualizarVisual();
    for (var i = 0; i < 2; i++) {
      avancarEnsaio(c, x.clock);
    }
    await c.preparar();
    c.iniciarCronometro();
    x.clock.now = 90000;
    c.atualizarVisual();
    await drenar();
    expect(c.atual!.status, 'incompleta');
    expect(c.atual!.duracaoMs, 90000);
    expect(c.atual!.metricas['apresentados'], 0);
  });
  test('falha final mantém tela de preservação até gravar', () async {
    final x = f.Fixture(), c = controller(x);
    addTearDown(c.dispose);
    await preparar(c, x);
    x.dados.falhar = true;
    c.interromper();
    await drenar();
    expect(c.tela, TelaHistorico.salvando);
    expect(c.salvo, isFalse);
    x.dados.falhar = false;
    await c.tentarSalvar();
    expect(c.tela, TelaHistorico.resultado);
  });
  for (final tamanho in [
    const Size(390, 844),
    const Size(1440, 900),
    const Size(320, 568),
  ]) {
    testWidgets(
      'visual sem sobreposição em $tamanho com texto ampliado e teclado',
      (tester) async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final x = f.Fixture(), c = controller(x);
        addTearDown(c.dispose);
        await tester.runAsync(
          () => c.entrar('operador@teste.invalid', 'TESTE'),
        );
        c.praticar(f.eid, 'PORTO', 'MECÂNICA', Momento.inicio);
        x.clock.now = 6000;
        c.atualizarVisual();
        await tester.pumpWidget(
          TriagemApp(
            inicio: Scaffold(
              body: AnimatedBuilder(
                animation: c,
                builder: (context, _) => c.tela == TelaHistorico.treino
                    ? TesteVisual(c: c, treino: true)
                    : const Text('Fim do treino'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        // Inicialização do shell restaura contexto; iniciar treino após o carregamento.
        c.praticar(f.eid, 'PORTO', 'MECÂNICA', Momento.inicio);
        x.clock.now = 6000;
        c.atualizarVisual();
        await tester.pump();
        await tester.pump();
        expect(find.byType(TesteVisual), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        expect(c.visual!.respostas, hasLength(1));
        c.interromper();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
