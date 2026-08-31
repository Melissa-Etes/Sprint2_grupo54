# HospiData SUS — Grupo 54

Projeto de Sprint 2 com o objetivo de analisar padrões de sobrecarga hospitalar nos municípios do estado de São Paulo, cruzando dados de internações (SIHSUS), estabelecimentos de saúde (CNES) e população (IBGE), com processamento em Oracle Cloud (Autonomous Database) e Python (clusterização K-Means com PCA).

## Fontes de dados

- **SIHSUS** — Sistema de Informações Hospitalares do SUS (DataSUS): registros de internações hospitalares.
- **CNES** — Cadastro Nacional de Estabelecimentos de Saúde: quantidade de estabelecimentos por município.
- **IBGE** — população e nomes oficiais dos municípios de São Paulo.

Os dados brutos foram carregados em uma Autonomous Database Oracle a partir de um bucket na Object Storage (OCI), tratados via SQL e exportados para consolidação e clusterização em Python.

## Estrutura do repositório

```
├── etl/
│   └── pipeline_cnes_internacoes.sql   # Script SQL completo: origem dos dados, tratamento e carga
├── notebooks/
│   └── EC_Sprint2_HospiDataSUS_Clusterizacao_Grupo54.ipynb   # Clusterização (K-Means + PCA) em Python
├── data/
│   └── dados_tratados_datasus.csv      # Base tratada usada como entrada da clusterização
├── docs/
│   └── HospiDataSUS_Insights_Regras_Grupo54.pdf   # Documentação das regras de tratamento e principais insights
└── README.md
```

## Pipeline (resumo)

1. **Origem** — criação de credencial e tabelas externas no Oracle, lendo os arquivos CSV/JSON diretamente do bucket da Object Storage (SIHSUS, CNES, IBGE).
2. **Tratamento (SQL)** — limpeza, junção das bases por município (filtrando UF = SP) e tratamento de nulos, gerando a tabela `INTERNACOES_TRATADO`.
3. **Clusterização (Python)** — padronização das variáveis, redução de dimensionalidade (PCA) e agrupamento dos municípios em 3 clusters (K-Means), com identificação de outliers.
4. **Resultados** — perfil de cada cluster (mortalidade, permanência média, estabelecimentos, razão observado/esperado) documentado em `docs/`.

## Como reproduzir

1. Execute o script em `etl/pipeline_cnes_internacoes.sql` em um Autonomous Database Oracle (ajustando as credenciais de acesso ao bucket).
2. Exporte a base tratada e utilize-a como entrada do notebook em `notebooks/`.
3. Rode o notebook para gerar os clusters e os gráficos.

## Observações

- As credenciais utilizadas no script SQL são apenas placeholders — nunca comitar usuário/senha reais neste repositório.
- Detalhes completos das regras de tratamento, limitações conhecidas da base CNES e análise de outliers estão em `docs/HospiDataSUS_Insights_Regras_Grupo54.pdf`.
