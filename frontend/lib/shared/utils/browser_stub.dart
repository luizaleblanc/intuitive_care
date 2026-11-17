import 'dart:typed_data';

/// Fora do navegador (testes/VM) não há download nem abas: no-op.
void baixarArquivo(Uint8List bytes, String nome, String mime) {}

void abrirNovaAba(String url) {}
