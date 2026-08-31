/* ============================================================
   PIPELINE DE TRATAMENTO DE DADOS - CNES / SIHSUS / IBGE (SP)
   Registro de todo o código Oracle SQL utilizado no projeto
   HospiData SUS - Grupo 54
   ============================================================ */


/* ------------------------------------------------------------
   0) ORIGEM DOS DADOS: credencial + tabelas externas
   Carga inicial das bases brutas a partir do Object Storage
   (bucket-datasus), via DBMS_CLOUD. Esta etapa cria as tabelas
   de staging (STG_*) que alimentam todo o restante do pipeline.
------------------------------------------------------------ */

-- Credencial de acesso ao Object Storage (NUNCA versionar com valores
-- reais — usar sempre placeholders como abaixo neste repositório)
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'ETL_DATASUS_CRED',
    username        => 'email_real_que_voce_usa_para_logar_no_oracle_cloud',
    password        => 'seu_auth_token_gerado'
  );
END;
/

-- Tabela externa: municípios do IBGE (nome + população), escopo SP
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'STG_IBGE',
    credential_name => 'ETL_DATASUS_CRED',
    file_uri_list   => 'https://objectstorage.sa-saopaulo-1.oraclecloud.com/n/grhnaqx1yypa/b/bucket-datasus/o/auxiliar/municipios.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE '1', 'delimiter' VALUE ','),
    column_list     => 'codigo_municipio VARCHAR2(10), nome_municipio VARCHAR2(100), populacao VARCHAR2(20)'
  );
END;
/

-- Tabela externa: estabelecimentos de saúde (CNES), formato CSV original
-- (posteriormente substituída pela versão JSON tratada — ver Etapa 3)
-- Estrutura original recuperada via:
--   SELECT DBMS_METADATA.GET_DDL('TABLE', 'STG_CNES') FROM DUAL;
-- Tabela ORACLE_LOADER externa lendo:
-- .../bucket-datasus/o/cnes_hospitais_sp.csv

-- Tabela externa: internações hospitalares (SIHSUS), base bruta do DataSUS
DROP TABLE STG_SIHSUS PURGE;

BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'STG_SIHSUS',
    credential_name => 'ETL_DATASUS_CRED',
    file_uri_list   => 'https://objectstorage.sa-saopaulo-1.oraclecloud.com/n/grhnaqx1yypa/b/bucket-datasus/o/datasus/RDSP2201.csv',
    format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE '1', 'delimiter' VALUE ','),
    column_list     => 'UF_ZI VARCHAR2(10), ANO_CMPT VARCHAR2(10), MES_CMPT VARCHAR2(10), ESPEC VARCHAR2(10),
CGC_HOSP VARCHAR2(30), N_AIH VARCHAR2(30), IDENT VARCHAR2(10), CEP VARCHAR2(20), MUNIC_RES VARCHAR2(10),
NASC VARCHAR2(20), SEXO VARCHAR2(5), UTI_MES_IN VARCHAR2(10), UTI_MES_AN VARCHAR2(10), UTI_MES_AL VARCHAR2(10),
UTI_MES_TO VARCHAR2(10), MARCA_UTI VARCHAR2(10), UTI_INT_IN VARCHAR2(10), UTI_INT_AN VARCHAR2(10),
UTI_INT_AL VARCHAR2(10), UTI_INT_TO VARCHAR2(10), DIAR_ACOM VARCHAR2(10), QT_DIARIAS VARCHAR2(10),
PROC_SOLIC VARCHAR2(20), PROC_REA VARCHAR2(20), VAL_SH VARCHAR2(20), VAL_SP VARCHAR2(20), VAL_SADT VARCHAR2(20),
VAL_RN VARCHAR2(20), VAL_ACOMP VARCHAR2(20), VAL_ORTP VARCHAR2(20), VAL_SANGUE VARCHAR2(20),
VAL_SADTSR VARCHAR2(20), VAL_TRANSP VARCHAR2(20), VAL_OBSANG VARCHAR2(20), VAL_PED1AC VARCHAR2(20),
VAL_TOT VARCHAR2(20), VAL_UTI VARCHAR2(20), US_TOT VARCHAR2(20), DT_INTER VARCHAR2(20), DT_SAIDA VARCHAR2(20),
DIAG_PRINC VARCHAR2(20), DIAG_SECUN VARCHAR2(20), COBRANCA VARCHAR2(10), NATUREZA VARCHAR2(10),
NAT_JUR VARCHAR2(10), GESTAO VARCHAR2(10), RUBRICA VARCHAR2(10), IND_VDRL VARCHAR2(10), MUNIC_MOV VARCHAR2(10),
COD_IDADE VARCHAR2(10), IDADE VARCHAR2(10), DIAS_PERM VARCHAR2(10), MORTE VARCHAR2(10), NACIONAL VARCHAR2(10),
NUM_PROC VARCHAR2(20), CAR_INT VARCHAR2(10), TOT_PT_SP VARCHAR2(20), CPF_AUT VARCHAR2(20), HOMONIMO VARCHAR2(10),
NUM_FILHOS VARCHAR2(10), INSTRU VARCHAR2(10), CID_NOTIF VARCHAR2(20), CONTRACEP1 VARCHAR2(10),
CONTRACEP2 VARCHAR2(10), GESTRISCO VARCHAR2(10), INSC_PN VARCHAR2(20), SEQ_AIH5 VARCHAR2(20), CBOR VARCHAR2(20),
CNAER VARCHAR2(20), VINCPREV VARCHAR2(10), GESTOR_COD VARCHAR2(20), GESTOR_TP VARCHAR2(10),
GESTOR_CPF VARCHAR2(20), GESTOR_DT VARCHAR2(20), CNES VARCHAR2(20), CNPJ_MANT VARCHAR2(30),
INFEHOSP VARCHAR2(10), CID_ASSO VARCHAR2(20), CID_MORTE VARCHAR2(20), COMPLEX VARCHAR2(10),
FINANC VARCHAR2(10), FAEC_TP VARCHAR2(10), REGCT VARCHAR2(10), RACA_COR VARCHAR2(10), ETNIA VARCHAR2(20),
SEQUENCIA VARCHAR2(20), REMESSA VARCHAR2(50), AUD_JUST VARCHAR2(50), SIS_JUST VARCHAR2(50),
VAL_SH_FED VARCHAR2(20), VAL_SP_FED VARCHAR2(20), VAL_SH_GES VARCHAR2(20), VAL_SP_GES VARCHAR2(20),
VAL_UCI VARCHAR2(20), MARCA_UCI VARCHAR2(10), DIAGSEC1 VARCHAR2(20), DIAGSEC2 VARCHAR2(20),
DIAGSEC3 VARCHAR2(20), DIAGSEC4 VARCHAR2(20), DIAGSEC5 VARCHAR2(20), DIAGSEC6 VARCHAR2(20),
DIAGSEC7 VARCHAR2(20), DIAGSEC8 VARCHAR2(20), DIAGSEC9 VARCHAR2(20), TPDISEC1 VARCHAR2(20),
TPDISEC2 VARCHAR2(20), TPDISEC3 VARCHAR2(20), TPDISEC4 VARCHAR2(20), TPDISEC5 VARCHAR2(20),
TPDISEC6 VARCHAR2(20), TPDISEC7 VARCHAR2(20), TPDISEC8 VARCHAR2(20), TPDISEC9 VARCHAR2(20)'
  );
END;
/

-- Primeira versão do tratamento do CNES (contagem simples por município).
-- Correta na lógica, mas dependia da STG_CNES original, cuja extração
-- continha um filtro incorreto (ver diagnóstico na Etapa 1) — nenhum
-- estabelecimento do tipo hospital estava presente na amostra.
DROP TABLE CNES_TRATADO PURGE;

CREATE TABLE CNES_TRATADO AS
SELECT
    c.codigo_municipio                                              AS cod_municipio,
    COUNT(*)                                                        AS qtd_estabelecimentos,
    SUM(CASE WHEN c.estabelecimento_possui_atendimento_hospitalar = '1'
             THEN 1 ELSE 0 END)                                     AS qtd_estab_hospitalares
FROM STG_CNES c
GROUP BY c.codigo_municipio;

-- Primeira versão da tabela final (antes da correção da fonte CNES)
DROP TABLE INTERNACOES_TRATADO PURGE;

CREATE TABLE INTERNACOES_TRATADO AS
SELECT
    s.MUNIC_RES                                                     AS cod_municipio,
    i.nome_municipio                                                AS municipio,
    COUNT(*)                                                        AS qtd_internacoes,
    ROUND(AVG(TO_NUMBER(s.DIAS_PERM)), 2)                           AS permanencia_media,
    ROUND(SUM(CASE WHEN s.MORTE = '1' THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 2)                                      AS taxa_mortalidade_pct,
    ROUND(AVG(TO_NUMBER(s.VAL_TOT)), 2)                             AS valor_medio_internacao,
    NVL(c.qtd_estab_hospitalares, 0)                                AS qtd_estab_hospitalares,
    TO_NUMBER(i.populacao)                                          AS populacao,
    ROUND(COUNT(*) / NULLIF(TO_NUMBER(i.populacao), 0) * 1000, 2)   AS internacoes_por_mil_hab
FROM STG_SIHSUS s
LEFT JOIN CNES_TRATADO c ON s.MUNIC_RES = c.cod_municipio
LEFT JOIN STG_IBGE i     ON s.MUNIC_RES = i.codigo_municipio
GROUP BY s.MUNIC_RES, i.nome_municipio, c.qtd_estab_hospitalares, i.populacao;

-- Conferência (nesta primeira rodada, MUNICIPIO/POPULACAO vieram nulos
-- e QTD_ESTAB_HOSPITALARES sempre 0 — ver diagnóstico completo abaixo)
SELECT * FROM INTERNACOES_TRATADO ORDER BY internacoes_por_mil_hab DESC FETCH FIRST 20 ROWS ONLY;


/* ------------------------------------------------------------
   1) DIAGNÓSTICO
   Verificar por que QTD_ESTAB_HOSPITALARES estava sempre 0 em
   MUNICIPIOS_CLUSTERIZADOS (tabela anterior, já existente)
------------------------------------------------------------ */

SELECT * FROM MUNICIPIOS_CLUSTERIZADOS
WHERE QTD_ESTAB_HOSPITALARES IS NOT NULL;

-- Veio 0 linhas -> checar se é NULL ou 0
SELECT
  COUNT(*) AS total_linhas,
  COUNT(QTD_ESTAB_HOSPITALARES) AS qtd_nao_nulos,
  SUM(CASE WHEN QTD_ESTAB_HOSPITALARES IS NULL THEN 1 ELSE 0 END) AS qtd_nulos,
  SUM(CASE WHEN QTD_ESTAB_HOSPITALARES = 0 THEN 1 ELSE 0 END) AS qtd_iguais_a_zero,
  MIN(QTD_ESTAB_HOSPITALARES) AS minimo,
  MAX(QTD_ESTAB_HOSPITALARES) AS maximo
FROM MUNICIPIOS_CLUSTERIZADOS;

-- Conclusão: coluna 100% preenchida com 0 (não é NULL) -> problema é na extração/fonte


/* ------------------------------------------------------------
   2) INVESTIGAÇÃO DA FONTE (CNES_TRATADO / STG_CNES)
------------------------------------------------------------ */

-- Estrutura das tabelas candidatas
SELECT column_name, data_type FROM user_tab_columns WHERE table_name = 'CNES_TRATADO' ORDER BY column_id;
SELECT column_name, data_type FROM user_tab_columns WHERE table_name = 'STG_CNES' ORDER BY column_id;

-- Checagem de valores reais em CNES_TRATADO (estava tudo zerado, só 10 linhas)
SELECT
  COUNT(*) AS total_linhas,
  SUM(CASE WHEN QTD_ESTAB_HOSPITALARES = 0 THEN 1 ELSE 0 END) AS qtd_zeros,
  SUM(CASE WHEN QTD_ESTAB_HOSPITALARES IS NULL THEN 1 ELSE 0 END) AS qtd_nulos,
  MIN(QTD_ESTAB_HOSPITALARES) AS minimo,
  MAX(QTD_ESTAB_HOSPITALARES) AS maximo,
  AVG(QTD_ESTAB_HOSPITALARES) AS media
FROM CNES_TRATADO;

-- Checagem em STG_CNES (tabela bruta, 1 linha por estabelecimento)
SELECT
  COUNT(*) AS total_linhas,
  COUNT(DISTINCT COD_MUNICIPIO) AS municipios_distintos
FROM STG_CNES;

SELECT ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR, COUNT(*) AS qtd
FROM STG_CNES
GROUP BY ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR;

SELECT CODIGO_TIPO_UNIDADE, COUNT(*) AS qtd
FROM STG_CNES
GROUP BY CODIGO_TIPO_UNIDADE;

-- Ver a definição (DDL) real da tabela externa, pra achar a origem do dado
SELECT DBMS_METADATA.GET_DDL('TABLE', 'STG_CNES') FROM DUAL;
-- -> revelou que STG_CNES é tabela externa lendo um CSV do Object Storage,
--    cujo conteúdo não contém nenhum estabelecimento do tipo hospital
--    (códigos CNES 05/07) — apenas consultórios, clínicas e policlínica.


/* ------------------------------------------------------------
   3) MIGRAÇÃO DA FONTE PARA JSON (mesma amostra, formato JSON)
------------------------------------------------------------ */

-- Tabela de staging pra receber o JSON bruto (CLOB)
CREATE TABLE STG_CNES_JSON_RAW (DOC CLOB);

-- Download do arquivo JSON do Object Storage e insert na staging
DECLARE
  l_blob        BLOB;
  l_clob        CLOB;
  l_dest_offset INTEGER := 1;
  l_src_offset  INTEGER := 1;
  l_lang_ctx    INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
  l_warning     INTEGER;
BEGIN
  l_blob := DBMS_CLOUD.GET_OBJECT(
    credential_name => 'ETL_DATASUS_CRED',
    object_uri      => 'https://objectstorage.sa-saopaulo-1.oraclecloud.com/n/grhnaqx1yypa/b/bucket-datasus/o/cnes%2Fcnes_hospitais_sp.json'
  );

  DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
  DBMS_LOB.CONVERTTOCLOB(
    dest_lob     => l_clob,
    src_blob     => l_blob,
    amount       => DBMS_LOB.LOBMAXSIZE,
    dest_offset  => l_dest_offset,
    src_offset   => l_src_offset,
    blob_csid    => DBMS_LOB.DEFAULT_CSID,
    lang_context => l_lang_ctx,
    warning      => l_warning
  );

  INSERT INTO STG_CNES_JSON_RAW (DOC) VALUES (l_clob);
  COMMIT;
END;
/

-- Conferir conteúdo baixado
SELECT DBMS_LOB.SUBSTR(DOC, 500, 1) FROM STG_CNES_JSON_RAW;

-- Caso precise recarregar com outro arquivo/bucket:
-- TRUNCATE TABLE STG_CNES_JSON_RAW;
-- (repetir o bloco DECLARE...END acima com a URL correta)


/* ------------------------------------------------------------
   4) VIEW QUE ABRE O JSON EM COLUNAS (JSON_TABLE)
------------------------------------------------------------ */

CREATE OR REPLACE VIEW STG_CNES_JSON AS
SELECT
  jt.CODIGO_CNES,
  jt.NUMERO_CNPJ_ENTIDADE,
  jt.NOME_RAZAO_SOCIAL,
  jt.NOME_FANTASIA,
  jt.CODIGO_TIPO_UNIDADE,
  jt.CODIGO_UF,
  jt.CODIGO_MUNICIPIO,
  jt.ESTABELECIMENTO_POSSUI_CENTRO_CIRURGICO,
  jt.ESTABELECIMENTO_POSSUI_CENTRO_OBSTETRICO,
  jt.ESTABELECIMENTO_POSSUI_CENTRO_NEONATAL,
  jt.ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR,
  jt.ESTABELECIMENTO_POSSUI_SERVICO_APOIO,
  jt.ESTABELECIMENTO_POSSUI_ATENDIMENTO_AMBULATORIAL,
  jt.DATA_ATUALIZACAO
FROM STG_CNES_JSON_RAW src,
  JSON_TABLE(src.DOC, '$.estabelecimentos[*]'
    COLUMNS (
      CODIGO_CNES                                     VARCHAR2(20) PATH '$.codigo_cnes',
      NUMERO_CNPJ_ENTIDADE                            VARCHAR2(30) PATH '$.numero_cnpj_entidade',
      NOME_RAZAO_SOCIAL                               VARCHAR2(200) PATH '$.nome_razao_social',
      NOME_FANTASIA                                   VARCHAR2(200) PATH '$.nome_fantasia',
      CODIGO_TIPO_UNIDADE                             VARCHAR2(10) PATH '$.codigo_tipo_unidade',
      CODIGO_UF                                       VARCHAR2(10) PATH '$.codigo_uf',
      CODIGO_MUNICIPIO                                VARCHAR2(10) PATH '$.codigo_municipio',
      ESTABELECIMENTO_POSSUI_CENTRO_CIRURGICO         VARCHAR2(5) PATH '$.estabelecimento_possui_centro_cirurgico',
      ESTABELECIMENTO_POSSUI_CENTRO_OBSTETRICO        VARCHAR2(5) PATH '$.estabelecimento_possui_centro_obstetrico',
      ESTABELECIMENTO_POSSUI_CENTRO_NEONATAL          VARCHAR2(5) PATH '$.estabelecimento_possui_centro_neonatal',
      ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR   VARCHAR2(5) PATH '$.estabelecimento_possui_atendimento_hospitalar',
      ESTABELECIMENTO_POSSUI_SERVICO_APOIO            VARCHAR2(5) PATH '$.estabelecimento_possui_servico_apoio',
      ESTABELECIMENTO_POSSUI_ATENDIMENTO_AMBULATORIAL VARCHAR2(5) PATH '$.estabelecimento_possui_atendimento_ambulatorial',
      DATA_ATUALIZACAO                                VARCHAR2(20) PATH '$.data_atualizacao'
    )
  ) jt;

-- Conferência
SELECT * FROM STG_CNES_JSON;
SELECT CODIGO_TIPO_UNIDADE, ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR, COUNT(*) AS qtd
FROM STG_CNES_JSON
GROUP BY CODIGO_TIPO_UNIDADE, ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR
ORDER BY CODIGO_TIPO_UNIDADE;
-- -> confirma: mesmo conteúdo do CSV original, sem estabelecimentos
--    do tipo hospital nesta amostra (limitação de dados documentada
--    no PDF de insights entregue ao grupo)


/* ------------------------------------------------------------
   5) RECRIAÇÃO DA CNES_TRATADO (agregada por município)
------------------------------------------------------------ */

DROP TABLE CNES_TRATADO;

CREATE TABLE CNES_TRATADO AS
SELECT
  CODIGO_MUNICIPIO AS COD_MUNICIPIO,
  COUNT(*) AS QTD_ESTABELECIMENTOS,
  SUM(
    CASE
      WHEN ESTABELECIMENTO_POSSUI_ATENDIMENTO_HOSPITALAR = '1' THEN 1
      ELSE 0
    END
  ) AS QTD_ESTAB_HOSPITALARES
FROM STG_CNES_JSON
WHERE CODIGO_MUNICIPIO IS NOT NULL
GROUP BY CODIGO_MUNICIPIO;

SELECT * FROM CNES_TRATADO ORDER BY COD_MUNICIPIO;


/* ------------------------------------------------------------
   6) TABELA FINAL: INTERNACOES_TRATADO
   Cruza SIHSUS (internações) + CNES_TRATADO (estab. hospitalares)
   + IBGE (nome do município e população), restrito a SP
------------------------------------------------------------ */

DROP TABLE INTERNACOES_TRATADO PURGE;

CREATE TABLE INTERNACOES_TRATADO AS
SELECT
    s.MUNIC_RES                                                     AS cod_municipio,
    i.nome_municipio                                                AS municipio,
    COUNT(*)                                                        AS qtd_internacoes,
    ROUND(AVG(TO_NUMBER(s.DIAS_PERM)), 2)                           AS permanencia_media,
    ROUND(SUM(CASE WHEN s.MORTE = '1' THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 2)                                      AS taxa_mortalidade_pct,
    ROUND(AVG(TO_NUMBER(s.VAL_TOT)), 2)                             AS valor_medio_internacao,
    NVL(c.qtd_estab_hospitalares, 0)                                AS qtd_estab_hospitalares,
    TO_NUMBER(i.populacao)                                          AS populacao,
    ROUND(COUNT(*) / NULLIF(TO_NUMBER(i.populacao), 0) * 1000, 2)   AS internacoes_por_mil_hab
FROM STG_SIHSUS s
LEFT JOIN CNES_TRATADO c ON s.MUNIC_RES = SUBSTR(c.cod_municipio, 1, 6)
LEFT JOIN STG_IBGE i     ON s.MUNIC_RES = SUBSTR(i.codigo_municipio, 1, 6)
WHERE SUBSTR(s.MUNIC_RES, 1, 2) = '35'   -- restringe ao escopo de SP, batendo com STG_IBGE
GROUP BY s.MUNIC_RES, i.nome_municipio, c.qtd_estab_hospitalares, i.populacao;

-- Conferência: Top 20 municípios por internações por mil habitantes
SELECT * FROM INTERNACOES_TRATADO
ORDER BY internacoes_por_mil_hab DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY;

-- Checagem de sanidade: quantos municípios ficaram sem população/nome (join IBGE falhou)
SELECT COUNT(DISTINCT s.MUNIC_RES) AS municipios_sem_populacao
FROM STG_SIHSUS s
LEFT JOIN STG_IBGE i ON s.MUNIC_RES = SUBSTR(i.codigo_municipio, 1, 6)
WHERE i.populacao IS NULL;


/* ------------------------------------------------------------
   7) CLUSTERIZAÇÃO (Python) E RETORNO AO ORACLE
   A INTERNACOES_TRATADO foi exportada, tratada e clusterizada
   em notebook Python (StandardScaler + PCA + KMeans, k=3 —
   ver notebooks/EC_Sprint2_HospiDataSUS_Clusterizacao_Grupo54.ipynb),
   e o resultado (internacoes_com_clusters.csv) foi importado de
   volta ao Oracle como INTERNACOES_CLUSTERS via Data Load.
------------------------------------------------------------ */

-- 'CLUSTER' é palavra reservada no Oracle: renomear a coluna
-- importada para evitar erro ORA-00904/ORA-00936
ALTER TABLE INTERNACOES_CLUSTERS RENAME COLUMN "cluster" TO GRUPO_CLUSTER;

-- Conferência
SELECT * FROM INTERNACOES_CLUSTERS FETCH FIRST 10 ROWS ONLY;

-- Perfil médio por cluster (usado nos gráficos e no PDF de insights)
SELECT
  GRUPO_CLUSTER,
  COUNT(*) AS qtd_municipios,
  ROUND(AVG(TAXA_MORTALIDADE_PCT), 2) AS mortalidade_media,
  ROUND(AVG(PERMANENCIA_MEDIA), 2) AS permanencia_media,
  ROUND(AVG(QTD_ESTAB_HOSPITALARES), 2) AS estab_media,
  ROUND(AVG(RAZAO_OBS_ESPERADO), 2) AS razao_media
FROM INTERNACOES_CLUSTERS
GROUP BY GRUPO_CLUSTER
ORDER BY GRUPO_CLUSTER;
