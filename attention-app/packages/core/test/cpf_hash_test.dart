import 'dart:convert';

import 'package:test/test.dart';
import 'package:triagem_core/triagem_core.dart';

void main() {
  // Segredo de teste: bytes 0..31. Valor esperado calculado com HMAC-SHA256 independente
  // (Python: hmac.new(bytes(range(32)), b"11144477735", sha256).hexdigest()).
  final segredo = List<int>.generate(32, (i) => i);
  const esperado =
      'f0a16690b765f29e2d988418d23490eeadf8a08ddbef1ce191c769444b7ad72b';

  test('hash do CPF só com dígitos', () {
    expect(hashCpf('11144477735', segredo), esperado);
  });

  test('CPF formatado gera o mesmo hash', () {
    expect(hashCpf('111.444.777-35', segredo), esperado);
  });

  test('segredo diferente gera hash diferente', () {
    final outro = List<int>.generate(32, (i) => 31 - i);
    expect(hashCpf('11144477735', outro), isNot(esperado));
  });

  test('somenteDigitos e validação de formato', () {
    expect(somenteDigitos('111.444.777-35'), '11144477735');
    expect(cpfTemFormatoValido('111.444.777-35'), isTrue);
    expect(cpfTemFormatoValido('123'), isFalse);
  });

  test(
    'decodificarSegredo faz o caminho inverso do base64 entregue pelo servidor',
    () {
      expect(decodificarSegredo(base64Encode(segredo)), segredo);
    },
  );

  test('não gera identificador com CPF incompleto ou segredo ausente', () {
    expect(() => hashCpf('123', segredo), throwsArgumentError);
    expect(() => hashCpf('11144477735', const []), throwsArgumentError);
  });
}
