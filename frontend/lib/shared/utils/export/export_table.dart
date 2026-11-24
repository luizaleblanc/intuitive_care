/// Tabela genérica para exportação (relatórios, listas e fichas).
class ExportTable {
  final String titulo;
  final String? subtitulo;
  final List<String> colunas;
  final List<List<String>> linhas;

  const ExportTable({
    required this.titulo,
    this.subtitulo,
    required this.colunas,
    required this.linhas,
  });
}
