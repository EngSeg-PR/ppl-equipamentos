import 'dart:js_interop';

@JS('navigator.userAgentData')
external _ClientHints? get _clientHints;

extension type _ClientHints._(JSObject _) implements JSObject {
  external JSPromise<_ModelInfo> getHighEntropyValues(JSArray<JSString> hints);
}

extension type _ModelInfo._(JSObject _) implements JSObject {
  external String? get model;
}

/// Pede somente o modelo, quando o navegador o disponibiliza. Sem UA completo,
/// número de série, identificador do aparelho ou inferência pela resolução.
Future<String?> modeloDisponivel() async {
  try {
    final api = _clientHints;
    if (api == null) return null;
    final info = await api
        .getHighEntropyValues(['model'.toJS].toJS)
        .toDart
        .timeout(const Duration(milliseconds: 250));
    final modelo = info.model?.trim();
    return modelo == null || modelo.isEmpty || modelo.length > 160
        ? null
        : modelo;
  } catch (_) {
    return null;
  }
}
