/// Regra de senha, igual à de `validate_password` no backend.
const regraSenha = 'Mínimo de 8 caracteres, com letra maiúscula, número e símbolo.';
const maxPontosSenha = 4;

int pontosSenha(String senha) => [
      senha.length >= 8,
      senha.contains(RegExp(r'[A-Z]')),
      senha.contains(RegExp(r'\d')),
      senha.contains(RegExp(r'[^A-Za-z0-9]')),
    ].where((ok) => ok).length;

bool senhaValida(String senha) => pontosSenha(senha) == maxPontosSenha;

bool emailValido(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
