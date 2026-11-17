/// Modelo de domínio que representa uma operadora de saúde registrada na ANS.
class OperadoraModel {
  final String registroAns;
  final String cnpj;
  final String razaoSocial;
  final String uf;
  final String? nomeFantasia;
  final String? modalidade;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? cep;
  final String? telefone;
  final String? email;
  final String? representante;
  final String? cargoRepresentante;
  final double totalDespesas;

  const OperadoraModel({
    required this.registroAns,
    required this.cnpj,
    required this.razaoSocial,
    required this.uf,
    this.nomeFantasia,
    this.modalidade,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.cep,
    this.telefone,
    this.email,
    this.representante,
    this.cargoRepresentante,
    this.totalDespesas = 0,
  });

  factory OperadoraModel.fromJson(Map<String, dynamic> json) {
    return OperadoraModel(
      registroAns: (json['registro_ans'] ?? json['reg_ans'] ?? '').toString(),
      cnpj: (json['cnpj'] ?? '').toString(),
      razaoSocial: (json['razao_social'] ?? '').toString(),
      uf: (json['uf'] ?? '').toString(),
      nomeFantasia: json['nome_fantasia']?.toString(),
      modalidade: json['modalidade']?.toString(),
      logradouro: json['logradouro']?.toString(),
      numero: json['numero']?.toString(),
      complemento: json['complemento']?.toString(),
      bairro: json['bairro']?.toString(),
      cidade: json['cidade']?.toString(),
      cep: json['cep']?.toString(),
      telefone: json['telefone']?.toString(),
      email: json['email']?.toString(),
      representante: json['representante']?.toString(),
      cargoRepresentante: json['cargo_representante']?.toString(),
      totalDespesas: (json['total_despesas'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registro_ans': registroAns,
      'cnpj': cnpj,
      'razao_social': razaoSocial,
      'uf': uf,
      'nome_fantasia': nomeFantasia,
      'modalidade': modalidade,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'cep': cep,
      'telefone': telefone,
      'email': email,
      'representante': representante,
      'cargo_representante': cargoRepresentante,
    };
  }
}
