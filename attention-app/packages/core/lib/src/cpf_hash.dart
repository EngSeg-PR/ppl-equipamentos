import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Mantém só os dígitos ("111.444.777-35" -> "11144477735").
String somenteDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

bool cpfTemFormatoValido(String texto) => somenteDigitos(texto).length == 11;

/// Decodifica o segredo da empresa entregue no pareamento (base64).
List<int> decodificarSegredo(String segredoBase64) =>
    base64Decode(segredoBase64);

/// HMAC-SHA256 (hex minúsculo) dos 11 dígitos, usando o segredo da empresa.
/// É a MESMA conta feita no servidor por `hash_cpf`:
/// encode(hmac(convert_to(digitos, 'UTF8'), segredo, 'sha256'), 'hex').
String hashCpf(String cpf, List<int> segredo) {
  final digitos = somenteDigitos(cpf);
  if (digitos.length != 11) {
    throw ArgumentError('CPF precisa conter 11 dígitos');
  }
  if (segredo.isEmpty) {
    throw ArgumentError('segredo da empresa não pode ser vazio');
  }
  return Hmac(sha256, segredo).convert(utf8.encode(digitos)).toString();
}
