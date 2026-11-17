/// Modelo de domínio que representa um lançamento de despesa assistencial.
class DespesaModel {
  final int? id;
  final String regAns;
  final int ano;
  final int trimestre;
  final double valorDespesa;
  final String categoria;
  final String? descricao;
  final String? razaoSocial;
  final String? uf;
  final String? faixaPorte;

  const DespesaModel({
    this.id,
    required this.regAns,
    required this.ano,
    required this.trimestre,
    required this.valorDespesa,
    this.categoria = 'Despesa Assistencial',
    this.descricao,
    this.razaoSocial,
    this.uf,
    this.faixaPorte,
  });

  factory DespesaModel.fromJson(Map<String, dynamic> json) {
    return DespesaModel(
      id: json['id'] as int?,
      regAns: (json['reg_ans'] ?? json['registro_ans'] ?? '').toString(),
      ano: (json['ano'] as num?)?.toInt() ?? 0,
      trimestre: (json['trimestre'] as num?)?.toInt() ?? 1,
      valorDespesa: (json['valor_despesa'] as num?)?.toDouble() ?? 0.0,
      categoria: (json['categoria'] ?? 'Despesa Assistencial').toString(),
      descricao: json['descricao']?.toString(),
      razaoSocial: json['razao_social']?.toString(),
      uf: json['uf']?.toString(),
      faixaPorte: json['faixa_porte']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'reg_ans': regAns,
      'ano': ano,
      'trimestre': trimestre,
      'valor_despesa': valorDespesa,
      'categoria': categoria,
      'descricao': descricao,
    };
  }
}
