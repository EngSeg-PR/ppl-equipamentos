import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagem_atencao_app/app.dart';
import 'package:triagem_atencao_app/brand.dart';
import 'package:triagem_atencao_app/history_app.dart';
import 'package:triagem_atencao_app/data/models.dart';
import 'package:triagem_atencao_app/features/history/history_controller.dart';
import 'package:triagem_core/triagem_core.dart';

import 'history_test.dart' as fixture;

// Exclusivamente em memória. Nenhum acesso à plataforma ou dado de produção.
class PortalLongo extends fixture.PortalTeste {
  @override
  Future<ContextoAtencao> contexto([String? empresaId]) async {
    final json = (await super.contexto(empresaId)).json;
    final nome = List.filled(5, 'NOME EXTENSO APENAS PARA TESTE').join(' ');
    json['principal'] = {'id': user, 'name': nome};
    json['company'] = {'id': fixture.cid, 'name': nome};
    json['employees'] = [
      {'id': fixture.eid, 'name': nome, 'employee_number': 'QA-1'},
    ];
    return ContextoAtencao(json);
  }
}

void main() {
  test('datas usam o formato brasileiro', () {
    expect(dataHoraLocal(DateTime(2026, 10, 25, 8, 5)), '25/10/2026 às 08:05');
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(844, 390),
  ]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets(
        'layout ${size.width}x${size.height}, fonte $escala: login, teclado, cadastro, grade e detalhes',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = escala;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final f = fixture.Fixture(), portal = PortalLongo();
          final c = HistoricoController(
            usarVisual: false,
            repositorio: f.repo,
            portal: portal,
            relogio: f.clock,
            criarGrade: (n) => List.generate(n, (i) => i + 1),
            sincronizacaoAutomatica: false,
          );
          addTearDown(c.dispose);
          await tester.pumpWidget(
            TriagemApp(inicio: InicioHistorico(controller: c)),
          );
          await tester.pumpAndSettle();
          expect(find.byType(LogoPrs), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = FakeViewPadding(bottom: size.height * .35);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const Key('login-senha')));
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.runAsync(
            () => c.entrar('layout@teste.invalid', 'somente teste'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Nova avaliação'), findsOneWidget);
          expect(tester.takeException(), isNull);
          c.praticar(
            fixture.eid,
            'UNIDADE DE TESTE',
            'EQUIPE DE TESTE',
            Momento.inicio,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (var n = 1; n <= 9; n++) {
            c.tocar(n);
          }
          await tester.runAsync(c.preparar);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() => fixture.finalizar(c, f.clock));
          await tester.pumpAndSettle();
          expect(find.text('Avaliação completa'), findsOneWidget);
          expect(tester.takeException(), isNull);
          c.abrirHistorico();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Ver detalhes'));
          await tester.tap(find.text('Ver detalhes'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Fechar'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        },
      );
    }
  }
}
