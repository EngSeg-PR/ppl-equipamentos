# Aplicativo de avaliações — fontes canônicas

Esta pasta preserva as fontes Flutter e o núcleo Dart que geram o aplicativo publicado em `../triagem/`. Alterações futuras devem ser feitas aqui, mantendo código, testes e distribuição juntos no histórico Git da plataforma.

Versão verificada: Flutter3.47.8/Dart3.13.7. O projeto usa `app/` e `packages/core/`; a dependência local permanece relativa. Os lockfiles estão versionados. Não há senhas, tokens administrativos, banco operacional ou registros de exemplo no pacote do aplicativo.

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
cd ../..
node tools/preparar-triagem-web.cjs
```

O empacotador configura a rota do site existente e atualiza o precache estático. Não modifica o banco nem cria avaliações. Para Android, o projeto está em `app/android`; o APK e o comportamento do plugin nativo ainda precisam de compilação/homologação no tablet.

Os cenários sintéticos ficam somente nos testes. O aplicativo usa os colaboradores reais retornados pela sessão autorizada e grava os registros localmente antes do envio.

Os SDKs, caches, dados de teste descartáveis e builds intermediários não entram no Git. O JavaScript publicado é a compilação convencional; o modo WebAssembly não foi homologado nesta entrega.
