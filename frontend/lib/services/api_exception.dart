/// Exceção padronizada para erros HTTP/JSON retornados pela API Flask.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

const mensagemSemConexao = 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
const mensagemTempoEsgotado = 'O servidor demorou para responder. Tente novamente em instantes.';
const mensagemServidorIndisponivel =
    'O serviço está indisponível no momento. Tente novamente em alguns minutos.';

/// Texto mostrado ao usuário quando a resposta não traz uma mensagem da API.
String mensagemPorStatus(int status) {
  if (status == 400 || status == 422) return 'Alguns dados não foram aceitos. Revise as informações e tente de novo.';
  if (status == 401) return 'Sua sessão expirou. Entre novamente.';
  if (status == 403) return 'Você não tem permissão para esta ação.';
  if (status == 404) return mensagemServidorIndisponivel;
  if (status == 429) return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos.';
  if (status >= 500) return 'Ocorreu um erro no servidor. Tente novamente em instantes.';
  return 'Não foi possível concluir a ação. Tente novamente.';
}
