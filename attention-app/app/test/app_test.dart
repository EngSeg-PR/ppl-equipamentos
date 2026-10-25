import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagem_atencao_app/app.dart';
import 'package:triagem_atencao_app/features/ensaio/ensaio_controller.dart';
import 'package:triagem_core/triagem_core.dart';

void main() {
  testWidgets(
    'fluxo de treino, sequência, métricas e reinício sem dados anteriores',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = EnsaioController(
        criarGrade: (n) => List.generate(n, (i) => n - i),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(TriagemApp(controller: controller));
      expect(find.textContaining('Nenhum dado é enviado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('comecar')));
      await tester.pumpAndSettle();
      final treinoButton = tester.widget<FilledButton>(
        find.byKey(const Key('ir-treino')),
      );
      expect(treinoButton.onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('codigo-participante')),
        'ENSAIO-03',
      );
      await tester.tap(find.byKey(const Key('ciencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ir-treino')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grade-treino')), findsOneWidget);
      for (var n = 1; n <= 9; n++) {
        await tester.tap(find.byKey(Key('numero-$n')));
        await tester.pump();
      }
      expect(find.text('Treino concluído'), findsOneWidget);
      await tester.tap(find.byKey(const Key('iniciar-teste')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('grade-teste')), findsOneWidget);
      for (var n = 1; n <= 36; n++) {
        await tester.tap(find.byKey(Key('numero-$n')));
        await tester.pump();
      }
      expect(find.text('Sequência concluída'), findsOneWidget);
      expect(find.text('Métricas deste ensaio'), findsOneWidget);
      expect(controller.resultado!.toques.length, 36);
      await tester.ensureVisible(find.byKey(const Key('encerrar')));
      await tester.tap(find.byKey(const Key('encerrar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('comecar')), findsOneWidget);
      expect(controller.participante, isEmpty);
      expect(controller.resultado, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sair de foco encerra a sessão e voltar não retoma a grade', (
    tester,
  ) async {
    final controller = EnsaioController(
      criarGrade: (n) => List.generate(n, (i) => i + 1),
    );
    addTearDown(controller.dispose);
    controller.abrirIdentificacao();
    controller.iniciarTreino('ENSAIO-04', Momento.inicio, ciencia: true);
    for (var n = 1; n <= 9; n++) {
      controller.tocar(n);
    }
    controller.prepararTeste();
    await tester.pumpWidget(TriagemApp(controller: controller));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Sessão incompleta'), findsOneWidget);
    expect(controller.resultado!.status, StatusSessao.incompleta);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('grade-teste')), findsNothing);
    expect(find.text('Sessão incompleta'), findsOneWidget);
  });

  testWidgets('apresentação cabe em tela estreita sem estouro horizontal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TriagemApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comecar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
