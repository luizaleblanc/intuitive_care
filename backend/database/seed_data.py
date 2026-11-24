"""Dados iniciais de demonstração (usuários, operadoras e despesas) para ambientes locais/teste."""

USUARIOS_DEMONSTRACAO = [
    {
        "nome": "Luiza Leblanc",
        "email": "admin@intuitivecare.com.br",
        "senha": "Admin@2025",
        "perfil": "ADMIN",
        "cargo": "Analista de Dados ANS",
    },
    {
        "nome": "Colaborador Intuitive Care",
        "email": "colaborador@intuitivecare.com.br",
        "senha": "Colaborador@2025",
        "perfil": "COLABORADOR",
        "cargo": "Analista de Negócios",
    },
]

SEED_OPERADORAS = [
    ("326305", "00011122000183", "AMIL ASSISTENCIA MEDICA INTERNACIONAL S.A.", "AMIL SAUDE", "Medicina de Grupo", "Av. Brigadeiro Faria Lima", "1800", "10o Andar", "Jardim Paulistano", "São Paulo", "SP", "01451001", "(11) 3004-1000", "contato@amil.demo.br", "Carlos Eduardo Mendes", "Diretor Executivo"),
    ("368253", "11222333000181", "HAPVIDA ASSISTENCIA MEDICA S.A.", "HAPVIDA", "Medicina de Grupo", "Av. Heráclito Graça", "406", "Bloco A", "Centro", "Fortaleza", "CE", "60140060", "(85) 3200-4000", "atendimento@hapvida.demo.br", "Mariana Silva Costa", "Diretora Financeira"),
    ("302147", "22333444000181", "BRADESCO SAUDE S.A.", "BRADESCO SAUDE", "Seguradora Especializada em Saúde", "Rua Barão de Itapagipe", "225", "Torre Sul", "Rio Comprido", "Rio de Janeiro", "RJ", "20261005", "(21) 4004-2700", "relacionamento@bradescosaude.demo.br", "Roberto Almeida Prado", "Diretor de Operações"),
    ("359017", "33444555000181", "UNIMED JOAO PESSOA COOPERATIVA DE TRABALHO MEDICO", "UNIMED JP", "Cooperativa Médica", "Av. Marechal Deodoro da Fonseca", "420", "Ed. Sede", "Torre", "João Pessoa", "PB", "58040140", "(83) 2106-0500", "ouvidoria@unimedjp.demo.br", "Fernanda Oliveira Nóbrega", "Diretora Presidente"),
    ("343889", "44555666000181", "UNIMED BELO HORIZONTE COOPERATIVA DE TRABALHO MEDICO", "UNIMED BH", "Cooperativa Médica", "Av. Francisco Sales", "1483", "Sede Administrativa", "Santa Efigênia", "Belo Horizonte", "MG", "30150221", "(31) 3229-6000", "gestao@unimedbh.demo.br", "Henrique Ferreira Gomes", "Diretor Técnico"),
    ("319996", "55666777000181", "SUL AMERICA COMPANHIA DE SEGURO SAUDE", "SULAMERICA SAUDE", "Seguradora Especializada em Saúde", "Rua Beatriz Larragoiti Lucas", "121", "Ala Leste", "Cidade Nova", "Rio de Janeiro", "RJ", "20211903", "(21) 3003-8000", "canal@sulamerica.demo.br", "Patrícia Campos Rocha", "Vice-Presidente"),
    ("352501", "66777888000181", "UNIMED CURITIBA SOCIEDADE COOPERATIVA DE MEDICOS", "UNIMED CURITIBA", "Cooperativa Médica", "Av. Affonso Penna", "297", "Andar 4", "Tarumã", "Curitiba", "PR", "82530280", "(41) 3019-2000", "compliance@unimedcuritiba.demo.br", "Lucas Tavares Ribeiro", "Diretor Administrativo"),
    ("339679", "77888999000181", "NOTRE DAME INTERMEDICA SAUDE S.A.", "GNDI", "Medicina de Grupo", "Av. Paulista", "867", "Conj. 12", "Bela Vista", "São Paulo", "SP", "01311100", "(11) 3155-2000", "ans@gndi.demo.br", "Juliana Martins Vieira", "Diretora Regulatória"),
]

SEED_DESPESAS = [
    ("326305", 2024, 3, 185420310.45, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 3T2024"),
    ("326305", 2024, 4, 198310500.20, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 4T2024"),
    ("326305", 2025, 1, 204150980.00, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 1T2025"),
    ("368253", 2024, 3, 112450890.10, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 3T2024"),
    ("368253", 2024, 4, 121980430.75, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 4T2024"),
    ("368253", 2025, 1, 129540120.30, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 1T2025"),
    ("302147", 2024, 3, 245890100.00, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 3T2024"),
    ("302147", 2024, 4, 261420300.50, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 4T2024"),
    ("302147", 2025, 1, 272100850.90, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 1T2025"),
    ("359017", 2024, 3, 28450120.40, "Despesa Assistencial", "Internações e exames complementares PB 3T2024"),
    ("359017", 2024, 4, 31200450.80, "Despesa Assistencial", "Internações e exames complementares PB 4T2024"),
    ("359017", 2025, 1, 33890710.15, "Despesa Assistencial", "Internações e exames complementares PB 1T2025"),
    ("343889", 2024, 3, 94500210.00, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 3T2024"),
    ("343889", 2024, 4, 98750600.25, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 4T2024"),
    ("343889", 2025, 1, 103420900.60, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 1T2025"),
    ("319996", 2024, 3, 154320800.00, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 3T2024"),
    ("319996", 2024, 4, 162180400.35, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 4T2024"),
    ("319996", 2025, 1, 169450220.80, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 1T2025"),
    ("352501", 2024, 3, 62310450.00, "Despesa Assistencial", "Custos assistenciais cooperados PR 3T2024"),
    ("352501", 2024, 4, 66840910.45, "Despesa Assistencial", "Custos assistenciais cooperados PR 4T2024"),
    ("352501", 2025, 1, 70120300.10, "Despesa Assistencial", "Custos assistenciais cooperados PR 1T2025"),
    ("339679", 2024, 3, 173200500.00, "Despesa Assistencial", "Rede assistencial integrada SP 3T2024"),
    ("339679", 2024, 4, 181900750.25, "Despesa Assistencial", "Rede assistencial integrada SP 4T2024"),
    ("339679", 2025, 1, 190450320.70, "Despesa Assistencial", "Rede assistencial integrada SP 1T2025"),
]
