import 'package:flutter_test/flutter_test.dart';
import 'package:triagem_atencao_app/features/ensaio/ensaio_controller.dart';
import 'package:triagem_core/triagem_core.dart';

class RelogioFalso implements RelogioEnsaio {
  int agora = 0;
  @override
  int get milissegundos => agora;
  @override
  void iniciar() => agora = 0;
  @override
  void parar() {}
}

EnsaioController criarController(RelogioFalso relogio) => EnsaioController(
      relogio: relogio,
      criarGrade: (n) => List.generate(n, (i) => n - i),
    );

void irAteTeste(EnsaioController controller) {
  controller.abrirIdentificacao();
  expect(
    controller.iniciarTreino('ENSAIO-01', Momento.inicio, ciencia: true),
    isTrue,
  );
  for (var n = 1; n <= 9; n++) {
    controller.tocar(n);
  }
  expect(controller.etapa, EtapaEnsaio.pronto);
  controller.prepararTeste();
  controller.iniciarCronometro();
}

void main() {
  test('exige ciência e recusa nome ou CPF antes do treino', () {
    final controller = criarController(RelogioFalso());
    addTearDown(controller.dispose);
    controller.abrirIdentificacao();
    expect(
      controller.iniciarTreino('ENSAIO-01', Momento.inicio, ciencia: false),
      isFalse,
    );
    expect(
      controller.iniciarTreino('12345678901', Momento.inicio, ciencia: true),
      isFalse,
    );
    expect(
      controller.iniciarTreino('Nome Completo', Momento.inicio, ciencia: true),
      isFalse,
    );
    expect(controller.participante, isEmpty);
    expect(controller.etapa, EtapaEnsaio.identificacao);
  });

  test(
    'descarta erros do treino, encerra uma única vez e apaga ao reiniciar',
    () {
      final clock = RelogioFalso();
      final controller = criarController(clock);
      addTearDown(controller.dispose);
      controller.abrirIdentificacao();
      controller.iniciarTreino('ENSAIO-01', Momento.durante, ciencia: true);
      controller.tocar(8);
      for (var n = 1; n <= 9; n++) {
        clock.agora += 100;
        controller.tocar(n);
      }
      expect(controller.resultado, isNull);
      controller.prepararTeste();
      controller.tocar(1);
      expect(
        controller.acertos,
        0,
        reason: 'toque antes da primeira renderização é ignorado',
      );
      controller.iniciarCronometro();
      for (var n = 1; n <= 36; n++) {
        clock.agora += 200;
        controller.tocar(n);
      }
      expect(controller.resultado!.status, StatusSessao.completa);
      expect(controller.resultado!.metricas.erros, 0);
      expect(controller.resultado!.toques.length, 36);
      expect(controller.resultado!.duracaoMs, 7200);
      final resultado = controller.resultado;
      controller.interromper();
      controller.tocar(1);
      expect(identical(resultado, controller.resultado), isTrue);
      controller.apagarEReiniciar();
      expect(controller.participante, isEmpty);
      expect(controller.resultado, isNull);
      expect(controller.grade, isEmpty);
      expect(controller.etapa, EtapaEnsaio.inicio);
    },
  );

  test('fecha incompleta no limite e não aceita toque atrasado', () {
    final clock = RelogioFalso();
    final controller = criarController(clock);
    addTearDown(controller.dispose);
    irAteTeste(controller);
    clock.agora = 1000;
    controller.tocar(1);
    clock.agora = EnsaioController.tempoMaximoMs;
    controller.tocar(2);
    expect(controller.etapa, EtapaEnsaio.resultado);
    expect(controller.resultado!.status, StatusSessao.incompleta);
    expect(controller.resultado!.duracaoMs, EnsaioController.tempoMaximoMs);
    expect(controller.resultado!.toques.length, 1);
    expect(controller.motivoInterrupcao, 'Tempo máximo atingido');
  });

  test('interrupção mantém métricas parciais e impede retomada', () {
    final clock = RelogioFalso();
    final controller = criarController(clock);
    addTearDown(controller.dispose);
    irAteTeste(controller);
    clock.agora = 1200;
    controller.tocar(1);
    clock.agora = 2400;
    controller.interromper('Aplicativo saiu de foco');
    expect(controller.resultado!.duracaoMs, 2400);
    expect(controller.resultado!.status, StatusSessao.incompleta);
    controller.iniciarCronometro();
    controller.tocar(2);
    expect(controller.resultado!.toques.length, 1);
  });

  test('interrupção antes da primeira grade não usa tempo do treino', () {
    final clock = RelogioFalso();
    final controller = criarController(clock);
    addTearDown(controller.dispose);
    controller.abrirIdentificacao();
    controller.iniciarTreino('ENSAIO-02', Momento.inicio, ciencia: true);
    for (var n = 1; n <= 9; n++) {
      clock.agora += 100;
      controller.tocar(n);
    }
    controller.prepararTeste();
    controller.interromper();
    expect(controller.resultado!.duracaoMs, 0);
  });
}
