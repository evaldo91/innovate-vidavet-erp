-- ==========================================================
-- PROJETO: CORE ERP VETERINÁRIO
-- CLIENTE: INNOVATE / VIDAVET
-- BANCO DE DADOS: POSTGRESQL v15+
-- AUTOR: EVALDO91
-- VERSÃO: 9.4 (FINAL SCHEMA)
-- ==========================================================

-- 1. CRIAÇÃO DOS TIPOS ENUMERADOS (ENUMS)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sexo_animal') THEN
        CREATE TYPE sexo_animal AS ENUM ('M', 'F', 'I');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'atendimento_status') THEN
        CREATE TYPE atendimento_status AS ENUM ('agendado', 'realizado', 'cancelado');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'atendimento_tipo') THEN
        CREATE TYPE atendimento_tipo AS ENUM ('consulta', 'emergencia', 'retorno', 'cirurgia', 'visita_campo');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_item_estoque') THEN
        CREATE TYPE tipo_item_estoque AS ENUM ('produto', 'consumivel', 'kit');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_pedido_compra') THEN
        CREATE TYPE status_pedido_compra AS ENUM ('rascunho', 'enviado', 'recebido_parcial', 'recebido_total', 'cancelado');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fatura_status') THEN
        CREATE TYPE fatura_status AS ENUM ('aberta', 'fechada', 'paga', 'cancelada');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_movimentacao') THEN
        CREATE TYPE tipo_movimentacao AS ENUM ('entrada_compra', 'saida_venda', 'saida_procedimento', 'ajuste_perda', 'ajuste_ganho');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'nf_tipo') THEN
        CREATE TYPE nf_tipo AS ENUM ('entrada_nfe', 'saida_nfe', 'saida_nfse');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'nf_status') THEN
        CREATE TYPE nf_status AS ENUM ('digitacao', 'autorizada', 'cancelada', 'erro_sefaz');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'financeiro_status') THEN
        CREATE TYPE financeiro_status AS ENUM ('pendente', 'pago', 'atrasado', 'cancelado', 'parcial');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_pagamento') THEN
        CREATE TYPE tipo_pagamento AS ENUM ('boleto', 'cartao_credito', 'cartao_debito', 'pix', 'dinheiro', 'transferencia');
    END IF;
END $$;

-- 2. TABELAS DE CADASTRO (NÚCLEO)
CREATE TABLE responsaveis_clientes (
    id_responsavel SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cpf_cnpj VARCHAR(18) UNIQUE NOT NULL,
    celular_whatsapp VARCHAR(20) NOT NULL,
    email VARCHAR(100),
    faturamento_mensal BOOLEAN DEFAULT FALSE,
    status BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE clinicas (
    id_clinica SERIAL PRIMARY KEY,
    nome_fantasia VARCHAR(100) NOT NULL,
    cnpj VARCHAR(18) UNIQUE,
    telefone VARCHAR(20),
    email VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE fazendas_propriedades (
    id_fazenda SERIAL PRIMARY KEY,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    nome_propriedade VARCHAR(100) NOT NULL,
    cpf_cnpj VARCHAR(18),
    inscricao_estadual VARCHAR(50),
    telefone VARCHAR(20),
    usa_endereco_responsavel BOOLEAN DEFAULT FALSE,
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE tecnicos_veterinarios (
    id_tecnico SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    registro_crmv VARCHAR(50) UNIQUE,
    celular_whatsapp VARCHAR(20),
    email VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE fornecedores (
    id_fornecedor SERIAL PRIMARY KEY,
    razao_social VARCHAR(150) NOT NULL,
    cnpj VARCHAR(18) UNIQUE,
    telefone_vendas VARCHAR(20),
    email VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE
);

-- 3. ENDEREÇOS (ARCO EXCLUSIVO)
CREATE TABLE enderecos (
    id_endereco SERIAL PRIMARY KEY,
    cep VARCHAR(10),
    logradouro VARCHAR(150) NOT NULL,
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100) NOT NULL,
    estado VARCHAR(2) NOT NULL,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    id_clinica INTEGER REFERENCES clinicas(id_clinica),
    id_fazenda INTEGER REFERENCES fazendas_propriedades(id_fazenda),
    id_tecnico INTEGER REFERENCES tecnicos_veterinarios(id_tecnico),
    id_fornecedor INTEGER REFERENCES fornecedores(id_fornecedor)
);

-- 4. ESTOQUE E KITS
CREATE TABLE itens_estoque (
    id_item SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    sku VARCHAR(50) UNIQUE,
    tipo tipo_item_estoque NOT NULL,
    unidade_estoque VARCHAR(10) NOT NULL,
    preco_custo_medio DECIMAL(10,2) DEFAULT 0,
    preco_venda DECIMAL(10,2) NOT NULL,
    saldo_atual DECIMAL(10,2) DEFAULT 0,
    estoque_minimo DECIMAL(10,2) DEFAULT 0,
    ponto_pedido DECIMAL(10,2) DEFAULT 0,
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE kits_composicao (
    id_kit_item SERIAL PRIMARY KEY,
    id_kit_pai INTEGER REFERENCES itens_estoque(id_item),
    id_item_filho INTEGER REFERENCES itens_estoque(id_item),
    quantidade DECIMAL(10,2) NOT NULL
);

-- 5. COMPRAS
CREATE TABLE pedidos_compra (
    id_pedido SERIAL PRIMARY KEY,
    id_fornecedor INTEGER REFERENCES fornecedores(id_fornecedor),
    status status_pedido_compra DEFAULT 'rascunho',
    data_pedido DATE DEFAULT CURRENT_DATE
);

CREATE TABLE pedidos_compra_itens (
    id_item_pedido SERIAL PRIMARY KEY,
    id_pedido INTEGER REFERENCES pedidos_compra(id_pedido),
    id_item INTEGER REFERENCES itens_estoque(id_item),
    quantidade_comprada DECIMAL(10,2) NOT NULL,
    fator_conversao DECIMAL(10,2) DEFAULT 1,
    preco_custo_un_compra DECIMAL(10,2) NOT NULL
);

-- 6. OPERAÇÃO CLÍNICA
CREATE TABLE animais (
    id_animal SERIAL PRIMARY KEY,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    id_clinica INTEGER REFERENCES clinicas(id_clinica),
    id_fazenda INTEGER REFERENCES fazendas_propriedades(id_fazenda),
    nome_identificacao VARCHAR(100) NOT NULL,
    sexo sexo_animal,
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE atendimentos (
    id_atendimento SERIAL PRIMARY KEY,
    id_animal INTEGER REFERENCES animais(id_animal),
    id_tecnico INTEGER REFERENCES tecnicos_veterinarios(id_tecnico),
    id_clinica INTEGER REFERENCES clinicas(id_clinica),
    id_fazenda INTEGER REFERENCES fazendas_propriedades(id_fazenda),
    data_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_atendimento atendimento_tipo NOT NULL,
    status atendimento_status DEFAULT 'realizado'
);

CREATE TABLE catalogo_procedimentos_exames (
    id_catalogo SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    valor_servico DECIMAL(10,2) NOT NULL
);

CREATE TABLE ficha_tecnica_procedimento (
    id_ficha SERIAL PRIMARY KEY,
    id_procedimento INTEGER REFERENCES catalogo_procedimentos_exames(id_catalogo),
    id_item_insumo INTEGER REFERENCES itens_estoque(id_item),
    quantidade DECIMAL(10,2) NOT NULL
);

CREATE TABLE procedimentos_realizados (
    id_realizado SERIAL PRIMARY KEY,
    id_atendimento INTEGER REFERENCES atendimentos(id_atendimento),
    id_procedimento INTEGER REFERENCES catalogo_procedimentos_exames(id_catalogo),
    id_tecnico_resp INTEGER REFERENCES tecnicos_veterinarios(id_tecnico)
);

-- 7. FATURAMENTO E FISCAL
CREATE TABLE faturas_mensais (
    id_fatura SERIAL PRIMARY KEY,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    mes_referencia INTEGER,
    ano_referencia INTEGER,
    status fatura_status DEFAULT 'aberta',
    valor_total DECIMAL(10,2) DEFAULT 0,
    data_fechamento TIMESTAMP
);

CREATE TABLE faturas_itens (
    id_fatura_item SERIAL PRIMARY KEY,
    id_fatura INTEGER REFERENCES faturas_mensais(id_fatura),
    id_item_estoque INTEGER REFERENCES itens_estoque(id_item),
    id_servico INTEGER REFERENCES catalogo_procedimentos_exames(id_catalogo),
    quantidade DECIMAL(10,2) NOT NULL,
    valor_unitario DECIMAL(10,2) NOT NULL,
    valor_subtotal DECIMAL(10,2) NOT NULL,
    id_atendimento INTEGER REFERENCES atendimentos(id_atendimento),
    data_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notas_fiscais (
    id_nf SERIAL PRIMARY KEY,
    id_fatura INTEGER REFERENCES faturas_mensais(id_fatura),
    tipo nf_tipo NOT NULL,
    numero_nf VARCHAR(20),
    chave_acesso VARCHAR(44) UNIQUE,
    status nf_status DEFAULT 'digitacao',
    valor_total DECIMAL(10,2) NOT NULL,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    id_fornecedor INTEGER REFERENCES fornecedores(id_fornecedor),
    data_emissao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notas_fiscais_itens (
    id_nf_item SERIAL PRIMARY KEY,
    id_nf INTEGER REFERENCES notas_fiscais(id_nf),
    id_item_estoque INTEGER REFERENCES itens_estoque(id_item),
    id_servico INTEGER REFERENCES catalogo_procedimentos_exames(id_catalogo),
    quantidade DECIMAL(10,2) NOT NULL,
    valor_unitario DECIMAL(10,2) NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL
);

-- 8. MOVIMENTAÇÃO DE ESTOQUE E FINANCEIRO
CREATE TABLE estoque_movimentacao (
    id_movimentacao SERIAL PRIMARY KEY,
    id_item INTEGER REFERENCES itens_estoque(id_item),
    tipo tipo_movimentacao NOT NULL,
    quantidade DECIMAL(10,2) NOT NULL,
    custo_unitario_snap DECIMAL(10,2),
    id_nf INTEGER REFERENCES notas_fiscais(id_nf),
    id_atendimento INTEGER REFERENCES atendimentos(id_atendimento),
    data_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contas_a_receber (
    id_receber SERIAL PRIMARY KEY,
    id_responsavel INTEGER REFERENCES responsaveis_clientes(id_responsavel),
    id_nf INTEGER REFERENCES notas_fiscais(id_nf),
    id_fatura INTEGER REFERENCES faturas_mensais(id_fatura),
    valor_total DECIMAL(10,2) NOT NULL,
    valor_pago DECIMAL(10,2) DEFAULT 0,
    data_vencimento DATE NOT NULL,
    data_recebimento DATE,
    status financeiro_status DEFAULT 'pendente',
    forma_pagamento tipo_pagamento,
    observacao VARCHAR(255)
);

CREATE TABLE contas_a_pagar (
    id_pagar SERIAL PRIMARY KEY,
    id_fornecedor INTEGER REFERENCES fornecedores(id_fornecedor),
    id_pedido_compra INTEGER REFERENCES pedidos_compra(id_pedido),
    id_nf_entrada INTEGER REFERENCES notas_fiscais(id_nf),
    descricao VARCHAR(150) NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL,
    valor_pago DECIMAL(10,2) DEFAULT 0,
    data_vencimento DATE NOT NULL,
    data_pagamento DATE,
    status financeiro_status DEFAULT 'pendente',
    forma_pagamento tipo_pagamento,
    categoria VARCHAR(50)
);

-- 9. ÍNDICES PARA PERFORMANCE
CREATE INDEX idx_animal_responsavel ON animais(id_responsavel);
CREATE INDEX idx_atendimento_data ON atendimentos(data_hora);
CREATE INDEX idx_estoque_sku ON itens_estoque(sku);
CREATE INDEX idx_financeiro_vencimento_receber ON contas_a_receber(data_vencimento);
CREATE INDEX idx_financeiro_vencimento_pagar ON contas_a_pagar(data_vencimento);