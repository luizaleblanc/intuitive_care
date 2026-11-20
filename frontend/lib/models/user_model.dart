/// Preferências do usuário persistidas na API (seção 9 · Preferencias).
class PreferenciasModel {
  final String idioma;
  final String formatoData;
  final String formatoExportacao;
  final String? ufPadrao;
  final int trimestrePadrao;
  final String tema;
  final bool resumoSemanal;
  final bool alertaNovosDados;

  /// Layout salvo da tela Explorar (lista de {tipo, metrica}); null = padrão.
  final List<Map<String, dynamic>>? graficosExplorar;

  const PreferenciasModel({
    this.idioma = 'pt-BR',
    this.formatoData = 'DD/MM/AAAA',
    this.formatoExportacao = 'CSV',
    this.ufPadrao,
    this.trimestrePadrao = 4,
    this.tema = 'claro',
    this.resumoSemanal = true,
    this.alertaNovosDados = true,
    this.graficosExplorar,
  });

  factory PreferenciasModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PreferenciasModel();
    return PreferenciasModel(
      idioma: (json['idioma'] ?? 'pt-BR').toString(),
      formatoData: (json['formato_data'] ?? 'DD/MM/AAAA').toString(),
      formatoExportacao: (json['formato_exportacao'] ?? 'CSV').toString(),
      ufPadrao: (json['uf_padrao'] as String?)?.isEmpty == true ? null : json['uf_padrao'] as String?,
      trimestrePadrao: (json['trimestre_padrao'] as num?)?.toInt() ?? 4,
      tema: (json['tema'] ?? 'claro').toString() == 'escuro' ? 'escuro' : 'claro',
      resumoSemanal: json['resumo_semanal'] != false,
      alertaNovosDados: json['alerta_novos_dados'] != false,
      graficosExplorar: json['graficos_explorar'] is List
          ? [for (final g in json['graficos_explorar'] as List) if (g is Map) Map<String, dynamic>.from(g)]
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'idioma': idioma,
        'formato_data': formatoData,
        'formato_exportacao': formatoExportacao,
        'uf_padrao': ufPadrao,
        'trimestre_padrao': trimestrePadrao,
        'tema': tema,
        'resumo_semanal': resumoSemanal,
        'alerta_novos_dados': alertaNovosDados,
        if (graficosExplorar != null) 'graficos_explorar': graficosExplorar,
      };

  PreferenciasModel copyWith({
    String? idioma,
    String? formatoData,
    String? formatoExportacao,
    String? Function()? ufPadrao,
    int? trimestrePadrao,
    String? tema,
    bool? resumoSemanal,
    bool? alertaNovosDados,
  }) =>
      PreferenciasModel(
        idioma: idioma ?? this.idioma,
        formatoData: formatoData ?? this.formatoData,
        formatoExportacao: formatoExportacao ?? this.formatoExportacao,
        ufPadrao: ufPadrao != null ? ufPadrao() : this.ufPadrao,
        trimestrePadrao: trimestrePadrao ?? this.trimestrePadrao,
        tema: tema ?? this.tema,
        resumoSemanal: resumoSemanal ?? this.resumoSemanal,
        alertaNovosDados: alertaNovosDados ?? this.alertaNovosDados,
        graficosExplorar: graficosExplorar,
      );
}

/// Modelo de domínio que representa o usuário autenticado no sistema.
class UserModel {
  final int? id;
  final String nome;
  final String email;
  final String perfil;
  final bool ativo;
  final String? cargo;
  final String? telefone;
  final String? dataNascimento;
  final String? foto;
  final DateTime? membroDesde;
  final DateTime? ultimoAcesso;
  final PreferenciasModel preferencias;

  /// Códigos de permissão definidos em backend/models/permissoes.py.
  final List<String> permissoes;

  const UserModel({
    this.id,
    required this.nome,
    required this.email,
    this.perfil = 'COLABORADOR',
    this.ativo = true,
    this.cargo,
    this.telefone,
    this.dataNascimento,
    this.foto,
    this.membroDesde,
    this.ultimoAcesso,
    this.preferencias = const PreferenciasModel(),
    this.permissoes = const [],
  });

  bool get isAdmin => perfil == 'ADMIN';

  bool pode(String permissao) => permissoes.contains(permissao);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? data(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return UserModel(
      id: (json['id'] as num?)?.toInt(),
      nome: (json['nome'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      perfil: (json['perfil'] ?? 'COLABORADOR').toString(),
      ativo: json['ativo'] == null ? true : json['ativo'] == true || json['ativo'] == 1,
      cargo: json['cargo']?.toString(),
      telefone: json['telefone']?.toString(),
      dataNascimento: json['data_nascimento']?.toString(),
      foto: json['foto']?.toString(),
      membroDesde: data(json['membro_desde'] ?? json['criado_em']),
      ultimoAcesso: data(json['ultimo_acesso']),
      preferencias: PreferenciasModel.fromJson(
        json['preferencias'] is Map ? Map<String, dynamic>.from(json['preferencias'] as Map) : null,
      ),
      permissoes: json['permissoes'] is List
          ? (json['permissoes'] as List).map((p) => p.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil,
        'ativo': ativo,
        'cargo': cargo,
        'telefone': telefone,
        'data_nascimento': dataNascimento,
        'foto': foto,
        'preferencias': preferencias.toJson(),
      };
}
