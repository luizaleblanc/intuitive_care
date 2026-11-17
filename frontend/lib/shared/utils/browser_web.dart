import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Download no navegador (Flutter Web).
void baixarArquivo(Uint8List bytes, String nome, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = nome;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Abre uma URL em nova aba (ex.: página do Design System).
void abrirNovaAba(String url) => web.window.open(url, '_blank');
