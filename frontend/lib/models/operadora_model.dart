/// Modelo de domínio que representa uma operadora de saúde registrada na ANS.
class OperadoraModel {
  final String registroAns;
  final String cnpj;
  final String razaoSocial;
  final String uf;
  final String? nomeFantasia;
  final String? modalidade;
  final String? cidade;
  final String? telefone;
  final String? email;
  final String status;
  final int beneficiarios;

  /// Despesa assistencial (conta 41) do trimestre mais recente, em reais.
  final double? despesaTrimestre;
  final String? dataDescredenciamento;

  const OperadoraModel({
    required this.registroAns,
    required this.cnpj,
    required this.razaoSocial,
    required this.uf,
    this.nomeFantasia,
    this.modalidade,
    this.cidade,
    this.telefone,
    this.email,
    this.status = 'Ativa',
    this.beneficiarios = 0,
    this.despesaTrimestre,
    this.dataDescredenciamento,
  });

  /// Nome de exibição: nome fantasia quando houver, senão a razão social.
  String get nomeExibicao =>
      (nomeFantasia != null && nomeFantasia!.trim().isNotEmpty) ? nomeFantasia!.trim() : razaoSocial;

  bool get isInativa => status == 'Inativa';

  factory OperadoraModel.fromJson(Map<String, dynamic> json) => OperadoraModel(
        registroAns: (json['registro_ans'] ?? json['reg_ans'] ?? '').toString(),
        cnpj: (json['cnpj'] ?? '').toString(),
        razaoSocial: (json['razao_social'] ?? '').toString(),
        uf: (json['uf'] ?? '').toString(),
        nomeFantasia: json['nome_fantasia']?.toString(),
        modalidade: json['modalidade']?.toString(),
        cidade: json['cidade']?.toString(),
        telefone: json['telefone']?.toString(),
        email: json['email']?.toString(),
        status: (json['status'] ?? 'Ativa').toString(),
        beneficiarios: (json['beneficiarios'] as num?)?.toInt() ?? 0,
        despesaTrimestre: (json['despesa_trimestre'] as num?)?.toDouble(),
        dataDescredenciamento: json['data_descredenciamento']?.toString(),
      );

  /// Corpo de criação/edição aceito pela API.
  Map<String, dynamic> toJson() => {
        'registro_ans': registroAns,
        'cnpj': cnpj,
        'razao_social': razaoSocial,
        'nome_fantasia': nomeFantasia,
        'modalidade': modalidade,
        'uf': uf,
        'beneficiarios': beneficiarios,
      };

  OperadoraModel copyWith({
    String? cnpj,
    String? razaoSocial,
    String? nomeFantasia,
    String? modalidade,
    String? uf,
    String? status,
    int? beneficiarios,
  }) =>
      OperadoraModel(
        registroAns: registroAns,
        cnpj: cnpj ?? this.cnpj,
        razaoSocial: razaoSocial ?? this.razaoSocial,
        uf: uf ?? this.uf,
        nomeFantasia: nomeFantasia ?? this.nomeFantasia,
        modalidade: modalidade ?? this.modalidade,
        cidade: cidade,
        telefone: telefone,
        email: email,
        status: status ?? this.status,
        beneficiarios: beneficiarios ?? this.beneficiarios,
        despesaTrimestre: despesaTrimestre,
        dataDescredenciamento: dataDescredenciamento,
      );
}

/// Cards de resumo e listas de filtros da tela de operadoras.
class OperadorasResumo {
  final int ativas;
  final int emAnalise;
  final int inativadas12m;
  final int beneficiarios;
  final List<String> modalidades;
  final List<String> ufs;

  const OperadorasResumo({
    this.ativas = 0,
    this.emAnalise = 0,
    this.inativadas12m = 0,
    this.beneficiarios = 0,
    this.modalidades = const [],
    this.ufs = const [],
  });

  factory OperadorasResumo.fromJson(Map<String, dynamic> json) => OperadorasResumo(
        ativas: (json['ativas'] as num?)?.toInt() ?? 0,
        emAnalise: (json['em_analise'] as num?)?.toInt() ?? 0,
        inativadas12m: (json['inativadas_12m'] as num?)?.toInt() ?? 0,
        beneficiarios: (json['beneficiarios'] as num?)?.toInt() ?? 0,
        modalidades: List<String>.from(json['modalidades'] as List? ?? const []),
        ufs: List<String>.from(json['ufs'] as List? ?? const []),
      );
}
