// Download de arquivos e abertura de abas: implementação web com fallback para testes.
export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
