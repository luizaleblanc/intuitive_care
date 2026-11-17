/// Modelo de domínio que representa o usuário autenticado no sistema.
class UserModel {
  final int? id;
  final String nome;
  final String email;
  final String perfil;
  final bool ativo;
  final String? criadoEm;

  const UserModel({
    this.id,
    required this.nome,
    required this.email,
    this.perfil = 'ANALISTA',
    this.ativo = true,
    this.criadoEm,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      nome: (json['nome'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      perfil: (json['perfil'] ?? 'ANALISTA').toString(),
      ativo: json['ativo'] == null ? true : json['ativo'] == true || json['ativo'] == 1,
      criadoEm: json['criado_em']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'ativo': ativo,
      'criado_em': criadoEm,
    };
  }
}
