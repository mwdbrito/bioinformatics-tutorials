Protocolo de Análise Exploratória do TCGA/GDC com TCGAbiolinks

> **Criado por:** `Márcio Wilson`
>
> **Atualizado em:** `19/08/2026`
>
> **Objetivo:** realizar uma caracterização sistemática de um projeto TCGA antes do download e da análise dos dados moleculares, documentando casos, amostras, aliquots, arquivos, categorias de dados, tipos de ensaio, acesso aberto/controlado, metadados clínicos, tratamentos, estágio, características demográficas e disponibilidade por modalidade.

---

## 1. Visão geral

O **The Cancer Genome Atlas (TCGA)** é um conjunto de estudos de câncer integrado ao **National Cancer Institute Genomic Data Commons (GDC)**. Atualmente, o GDC distribui dados genômicos, clínicos e de biospecímenes em um modelo de dados padronizado e disponibiliza mecanismos de busca, consulta programática, visualização e download. O GDC também separa arquivos em **open access** e **controlled access**; arquivos controlados exigem autorização apropriada, normalmente via dbGaP. [GDC Data Introduction](https://docs.gdc.cancer.gov/Data/Introduction/), [GDC Data Access Policy](https://docs.gdc.cancer.gov/Encyclopedia/pages/Data_Access_Policy/), [GDC Controlled Access](https://docs.gdc.cancer.gov/Encyclopedia/pages/Controlled_Access/)

Este protocolo **não tem como objetivo começar pela expressão gênica, mutações, CNV ou metilação**. A primeira pergunta é:

> **O que existe no projeto, em que quantidade, para quais pacientes/amostras, em quais modalidades, com quais metadados e com qual nível de acesso?**

A partir desse inventário é possível decidir, de maneira fundamentada, quais dados realmente precisam ser baixados para a pesquisa.

### 1.1 O que este protocolo responde

Ao final da exploração, o pesquisador deverá ser capaz de responder:

| Pergunta | Exemplo de resposta esperada |
|---|---|
| Qual projeto foi consultado? | `TCGA-PRAD` |
| Quantos casos/pacientes existem? | número de cases no GDC |
| Quantas amostras existem? | número de samples associados aos casos |
| Quantos aliquots existem? | número de aliquots, quando disponíveis no biospecimen |
| Quais tipos de tecido estão presentes? | Primary Tumor, Solid Tissue Normal, Metastatic etc. |
| Quais modalidades existem? | Transcriptome Profiling, DNA Methylation, Simple Nucleotide Variation etc. |
| Quantos arquivos existem? | contagem de arquivos retornados/registrados |
| Qual a distribuição de acesso? | open vs controlled |
| Quais tecnologias/estratégias foram usadas? | RNA-Seq, miRNA-Seq, WGS, WXS etc. |
| Quais dados clínicos existem? | diagnoses, demographics, exposures, follow-ups, treatments etc. |
| Há informações de tratamento? | drug/radiation quando existentes nos dados clínicos/XML |
| Há dados de estágio? | clinical/stage-related fields, conforme disponibilidade |
| Quantos pacientes têm determinado metadado? | contagens de não-missing por variável |
| Há desequilíbrio entre grupos? | por exemplo, tumor vs normal |
| Quais dados são imediatamente utilizáveis? | open access |
| Quais dados podem exigir autorização? | controlled access |
| Quais modalidades têm maior volume? | tabela de arquivos por categoria/tipo |
| Quais limitações precisam ser registradas? | missingness, categorias raras, ausência de normal etc. |

---

## 2. Conceitos fundamentais antes de começar

Um erro comum em análises exploratórias do TCGA é usar **paciente, amostra e arquivo como sinônimos**. Eles são entidades diferentes.

### 2.1 Case

No contexto do GDC, um **case** representa uma unidade de estudo/paciente cadastrada no projeto. Um caso pode estar associado a várias amostras e vários arquivos.

### 2.2 Sample

Uma **sample** representa um espécime biológico coletado do caso. Um mesmo paciente pode contribuir com mais de uma amostra.

### 2.3 Portion, analyte e aliquot

O GDC mantém uma hierarquia de biospecímenes que pode incluir:

```text
Case
└── Sample
    └── Portion
        └── Analyte
            └── Aliquot
                └── Arquivo(s) molecular(es)
```

Nem todo projeto/arquivo terá todos os níveis representados da mesma forma. O GDC documenta essa estrutura no seu modelo de dados e na documentação de biospecímenes. [GDC Biospecimen Data](https://docs.gdc.cancer.gov/Encyclopedia/pages/Biospecimen_Data/)

### 2.4 File

Um **file** é um objeto de dados hospedado pelo GDC. Um único caso pode possuir muitos arquivos, pois diferentes modalidades e pipelines geram diferentes objetos.

Portanto:

```text
Número de cases   != número de samples != número de aliquots != número de files
```

Essa distinção deve aparecer explicitamente no relatório final.

---

## 3. Modelo geral do protocolo

O protocolo é organizado em oito camadas:

```text
1. Ambiente
   ↓
2. Identificação do projeto
   ↓
3. Inventário geral de arquivos
   ↓
4. Inventário de biospecímenes
   ↓
5. Inventário clínico
   ↓
6. Avaliação de acesso e disponibilidade
   ↓
7. Auditoria de qualidade dos metadados
   ↓
8. Relatório final + decisão sobre o download
```

A principal vantagem é que **as primeiras etapas consultam metadados e estruturas do GDC sem exigir o download das matrizes moleculares completas**.

---

# 4. Ambiente computacional

## 4.1 Requisitos

Recomenda-se:

- Linux, Windows ou macOS;
- R atualizado e compatível com a versão vigente do Bioconductor;
- RStudio ou VS Code com extensão para R, opcional;
- conexão com a internet;
- espaço em disco para os relatórios e, posteriormente, para os dados que forem efetivamente baixados.

O GDC possui API própria para pesquisa e recuperação de dados; o TCGAbiolinks funciona como uma camada programática especializada no ecossistema R/Bioconductor. A documentação do pacote descreve funções como `GDCquery()`, `getResults()`, `getGDCprojects()`, `getProjectSummary()`, `getSampleFilesSummary()` e `GDCquery_clinic()`. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf), [GDC API User Guide](https://docs.gdc.cancer.gov/API/PDF/API_UG.pdf)

---

## 5. Instalação do R e Bioconductor

### 5.1 Verificar o R

Execute:

```r
R.version.string
version
```

Também registre a versão do Bioconductor:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

BiocManager::version()
```

### 5.2 Instalar os pacotes

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

BiocManager::install("TCGAbiolinks")

install.packages(c(
  "dplyr",
  "tidyr",
  "ggplot2",
  "readr",
  "stringr",
  "purrr",
  "writexl",
  "knitr",
  "rmarkdown",
  "DT"
))
```

> **Boas práticas:** não fixe manualmente uma versão antiga do TCGAbiolinks apenas porque um tutorial antigo usa argumentos diferentes. Consulte a documentação da sua versão instalada antes de reproduzir consultas legadas.

### 5.3 Carregamento

```r
library(TCGAbiolinks)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(stringr)
library(purrr)
library(writexl)
library(knitr)
```

### 5.4 Testar a API do GDC

```r
getGDCInfo()
```

A função `getGDCInfo()` consulta o status do servidor GDC pela API. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

---

# 6. Definição do projeto e princípio "explorar antes de selecionar"

O protocolo foi projetado para que o pesquisador **não precise adivinhar os valores dos argumentos** usados nas consultas. Antes de preencher qualquer parâmetro, primeiro devemos descobrir quais opções estão disponíveis no GDC para o projeto escolhido.

A regra geral será:

```text
DESCUBRIR opções → CONTAR disponibilidade → ESCOLHER → VALIDAR → CONSULTAR
```

Isso é especialmente importante para:

- `project`;
- `data.category`;
- `data.type`;
- `workflow.type`;
- `access`;
- `platform`;
- `experimental.strategy`;
- `sample.type`;
- `data.format`;
- `barcode`;
- tipos de informação clínica.

> **Importante:** listas encontradas em tutoriais antigos não devem ser tratadas como listas fixas. A disponibilidade pode variar entre projetos, modalidades e versões do GDC/TCGAbiolinks. A documentação atual do `GDCquery()` recomenda `project`, `data.category`, `data.type` e `workflow.type` como filtros principais e documenta filtros adicionais como `access`, `platform`, `barcode`, `data.format`, `experimental.strategy` e `sample.type`. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

## 6.1 Funções auxiliares para explorar opções

Adicione estas funções ao início do seu script. Elas serão reutilizadas ao longo de todo o protocolo.

```r
# Mostra opções únicas e quantidades
explorar_opcoes <- function(df, coluna) {

  if (!coluna %in% colnames(df)) {
    stop(
      paste0(
        "A coluna '", coluna, "' não existe.\n",
        "Use colnames() para verificar as colunas disponíveis."
      )
    )
  }

  df %>%
    count(.data[[coluna]], sort = TRUE, name = "n") %>%
    rename(opcao = 1)
}

# Mostra opções numeradas para facilitar a escolha manual
escolher_opcao <- function(df, coluna, titulo = NULL) {

  if (!coluna %in% colnames(df)) {
    stop(paste0("Coluna não encontrada: ", coluna))
  }

  opcoes <- df %>%
    distinct(.data[[coluna]]) %>%
    filter(!is.na(.data[[coluna]])) %>%
    arrange(.data[[coluna]]) %>%
    pull(.data[[coluna]])

  if (!is.null(titulo)) {
    cat("\n", titulo, "\n", sep = "")
  }

  tabela <- data.frame(
    indice = seq_along(opcoes),
    opcao = opcoes
  )

  print(tabela, row.names = FALSE)

  escolha <- as.integer(
    readline("Digite o número da opção desejada: ")
  )

  if (is.na(escolha) || escolha < 1 || escolha > length(opcoes)) {
    stop("Opção inválida.")
  }

  opcoes[escolha]
}
```

A primeira função é útil quando queremos apenas uma tabela:

```r
explorar_opcoes(resultados, "sample_type")
```

A segunda pode transformar a exploração em uma seleção guiada:

```r
sample_type_alvo <- escolher_opcao(
  resultados_exp,
  "sample_type",
  "Tipos de amostra disponíveis"
)
```

## 6.2 Mapa rápido: qual ferramenta usar para descobrir cada opção?

| O que preciso escolher | Como descobrir primeiro | Resultado esperado |
|---|---|---|
| Projeto | `getGDCprojects()` | Lista de `TCGA-*` e outros projetos GDC |
| Categoria | `getSampleFilesSummary()` | Categorias presentes no projeto |
| Tipo de dado | `GDCquery()` + `getResults()` | `data_type` disponíveis |
| Workflow | `getResults()` | `workflow_type` disponíveis |
| Acesso | `getResults()` / `count(access)` | `open` e/ou `controlled` |
| Tipo de amostra | `getResults()` / `count(sample_type)` | Tumor, normal, metástase etc. |
| Estratégia | `getResults()` / `count(experimental_strategy)` | RNA-Seq, WXS etc. |
| Plataforma | `getResults()` / `count(platform)` | Plataformas reais da consulta |
| Formato | `getResults()` / `count(data_format)` | Formatos de arquivo |
| Barcode | `getResults()` | Barcodes reais retornados pelo GDC |
| Variáveis clínicas | `colnames()` + `grep()` | Campos clínicos realmente presentes |
| Valores clínicos | `explorar_opcoes()` | Categorias/níveis daquela variável |

## 6.2 Primeiro nível: descobrir os projetos

Antes de definir:

```r
projeto_alvo <- "TCGA-BRCA"
```

consulte primeiro a lista atual:

```r
projetos_gdc <- getGDCprojects()

projetos_tcga <- projetos_gdc %>%
  filter(str_detect(project_id, "^TCGA-")) %>%
  select(project_id, name, primary_site, disease_type) %>%
  arrange(project_id)

View(projetos_tcga)
```

Você poderá encontrar projetos como:

```text
TCGA-BRCA
TCGA-COAD
TCGA-READ
TCGA-PRAD
TCGA-LUAD
TCGA-HNSC
TCGA-KIRC
TCGA-STAD
...
```

A lista acima é apenas ilustrativa. **A lista real deve sempre ser obtida pela API.**

### Procurar projetos por órgão, doença ou palavra-chave

```r
projetos_tcga %>%
  filter(
    str_detect(
      str_to_lower(
        paste(name, primary_site, disease_type)
      ),
      "prostate"
    )
  )
```

Exemplos de outras buscas:

```r
# Mama
projetos_tcga %>%
  filter(str_detect(str_to_lower(paste(name, primary_site, disease_type)), "breast"))

# Cólon
projetos_tcga %>%
  filter(str_detect(str_to_lower(paste(name, primary_site, disease_type)), "colon"))

# Pulmão
projetos_tcga %>%
  filter(str_detect(str_to_lower(paste(name, primary_site, disease_type)), "lung"))
```

Depois de escolher: 

```r
projeto_alvo <- "TCGA-PRAD"
```

Valide antes de prosseguir:

```r
if (!projeto_alvo %in% projetos_gdc$project_id) {
  stop(paste0("Projeto não encontrado: ", projeto_alvo))
}

message("Projeto válido: ", projeto_alvo)
```

## 6.3 Segundo nível: descobrir as categorias disponíveis no projeto

Depois de escolher o projeto, **não assuma que ele possui RNA-seq, metilação, CNV, SNV etc.**

Faça primeiro:

```r
arquivos_resumo <- getSampleFilesSummary(projeto_alvo)

View(arquivos_resumo)
colnames(arquivos_resumo)
```

A função resume a disponibilidade de arquivos do projeto por dimensões como categoria, tipo, estratégia e plataforma. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

Quando a coluna estiver disponível no retorno, use:

```r
explorar_opcoes(arquivos_resumo, "data_category")
```

Se a versão instalada retornar nomes diferentes, descubra-os com:

```r
colnames(arquivos_resumo)
```

e então use a coluna correspondente.

### Uma visão visual

```r
DT::datatable(
  arquivos_resumo,
  filter = "top",
  options = list(
    pageLength = 10,
    scrollX = TRUE
  )
)
```

Assim, antes de escrever `data.category = "..."`, você terá uma visão das possibilidades reais daquele projeto.

## 6.4 Terceiro nível: descobrir `data.type`

Depois de selecionar uma categoria, consulte os resultados dessa categoria antes de fixar o tipo de dado.

Exemplo:

```r
categoria_alvo <- "Transcriptome Profiling"

query_categoria <- GDCquery(
  project = projeto_alvo,
  data.category = categoria_alvo
)

resultados_categoria <- getResults(query_categoria)
```

Agora examine as possibilidades:

```r
colnames(resultados_categoria)
```

Se houver `data_type`:

```r
explorar_opcoes(
  resultados_categoria,
  "data_type"
)
```

Só depois escolha, por exemplo:

```r
tipo_dado_alvo <- "Gene Expression Quantification"
```

> O nome exato dos tipos disponíveis deve ser obtido da consulta. Não copie uma lista de `data.type` de outro projeto sem validar.

## 6.5 Quarto nível: descobrir `workflow.type`

Quando aplicável, descubra os workflows disponíveis: 

```r
explorar_opcoes(
  resultados_categoria,
  "workflow_type"
)
```

ou, dependendo da versão/retorno:

```r
explorar_opcoes(
  resultados_categoria,
  "workflow.type"
)
```

Depois selecione:

```r
workflow_alvo <- "STAR - Counts"
```

> O exemplo acima é apenas ilustrativo. O workflow deve ser escolhido dentre os valores efetivamente retornados pela consulta.

## 6.6 Quinto nível: descobrir acesso (`open` / `controlled`)

Antes de definir:

```r
access = "open"
```

verifique o que existe:

```r
explorar_opcoes(resultados_categoria, "access")
```

A documentação atual do `GDCquery()` especifica `controlled` e `open` como valores possíveis para `access`. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

## 6.7 Sexto nível: descobrir tipos de amostra

Antes de escrever:

```r
sample.type = "Primary Tumor"
```

consulte:

```r
explorar_opcoes(
  resultados_categoria,
  "sample_type"
)
```

Você poderá encontrar, por exemplo:

```text
Primary Tumor
Solid Tissue Normal
Metastatic
Recurrent Tumor
...
```

A lista real depende do projeto e da consulta.

## 6.8 Sétimo nível: descobrir `experimental.strategy`

```r
explorar_opcoes(
  resultados_categoria,
  "experimental_strategy"
)
```

Somente depois escolha a estratégia, por exemplo:

```r
estrategia_alvo <- "RNA-Seq"
```

## 6.9 Oitavo nível: descobrir `platform`

```r
explorar_opcoes(
  resultados_categoria,
  "platform"
)
```

Depois:

```r
plataforma_alvo <- "IlluminaHiSeq_RNASeq"
```

Novamente, o valor é apenas um exemplo. Use somente valores retornados para o conjunto consultado.

## 6.10 Nono nível: descobrir `data.format`

```r
explorar_opcoes(
  resultados_categoria,
  "data_format"
)
```

ou:

```r
explorar_opcoes(
  resultados_categoria,
  "data.format"
)
```

Isso permite verificar quais formatos de arquivo estão realmente presentes antes de filtrá-los.

## 6.11 Montar a consulta somente depois de selecionar as opções

Depois de explorar as opções, a consulta deixa de depender de valores escritos diretamente no código:

```r
query_exp <- GDCquery(
  project = projeto_alvo,
  data.category = categoria_alvo,
  data.type = tipo_dado_alvo
)
```

Se você também quiser restringir por estratégia, acesso, plataforma ou tipo de amostra, faça isso **somente depois de verificar que esses valores existem**:

```r
query_exp_filtrada <- GDCquery(
  project = projeto_alvo,
  data.category = categoria_alvo,
  data.type = tipo_dado_alvo,
  access = acesso_alvo,
  experimental.strategy = estrategia_alvo,
  platform = plataforma_alvo,
  sample.type = sample_type_alvo
)
```

Nem todos os filtros precisam ser usados simultaneamente. Quanto mais filtros você acrescentar, mais específica será a consulta.

> **Boa prática:** construa primeiro uma consulta ampla, inspecione `getResults()`, e só depois acrescente filtros. Isso reduz o risco de obter zero arquivos por ter escolhido um filtro incompatível.

## 6.12 Décimo primeiro nível: descobrir barcodes/amostras

Em vez de digitar um barcode manualmente, primeiro consulte os resultados:

```r
grep(
  "barcode|submitter_id",
  colnames(resultados_categoria),
  ignore.case = TRUE,
  value = TRUE
)
```

Depois, por exemplo:

```r
head(resultados_categoria$barcode)
```

Para selecionar uma amostra real retornada pelo GDC:

```r
barcode_alvo <- resultados_categoria$barcode[1]
```

## 6.13 Explorador genérico para qualquer coluna

Quando uma nova etapa do protocolo pedir um parâmetro que não foi previsto, use:

```r
colnames(resultados_categoria)
```

Depois:

```r
explorar_opcoes(
  resultados_categoria,
  "NOME_DA_COLUNA"
)
```

Esse mecanismo transforma o protocolo em uma ferramenta de descoberta: **se o GDC retornar a dimensão, você consegue inspecioná-la antes de usá-la como filtro.**


# 7. Etapa 1 — listar projetos disponíveis

A função `getGDCprojects()` recupera os projetos disponíveis no GDC por meio da API de projetos. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

```r
projetos_gdc <- getGDCprojects()

dim(projetos_gdc)
head(projetos_gdc)
colnames(projetos_gdc)
```

### 7.1 Filtrar apenas TCGA

```r
projetos_tcga <- projetos_gdc %>%
  filter(str_detect(project_id, "^TCGA-"))

projetos_tcga
```

### 7.2 Localizar um projeto específico

```r
projetos_gdc %>%
  filter(.data$project_id == projeto_alvo)
```

Para evitar conflito entre nomes, em scripts reutilizáveis pode ser melhor chamar a variável de seleção `projeto_alvo`:

```r
projeto_alvo <- "TCGA-BRCA"

projetos_gdc %>%
  filter(.data$project_id == projeto_alvo)
```

---

# 8. Etapa 2 — resumo geral do projeto

O TCGAbiolinks disponibiliza `getProjectSummary()` para consultar um resumo do projeto. A função consulta informações do projeto sem que seja necessário baixar a matriz molecular completa. [Documentação TCGAbiolinks](https://rdrr.io/bioc/TCGAbiolinks/man/getProjectSummary.html)

```r
resumo_projeto <- getProjectSummary(projeto_alvo)

str(resumo_projeto, max.level = 2)
```

Como a estrutura do retorno pode ser mais rica do que algumas tabelas simples de console, uma boa prática é inspeccionar explicitamente:

```r
names(resumo_projeto)
```

Quando houver componentes tabulares:

```r
lapply(resumo_projeto, class)
```

> **Por que inspecionar a estrutura?** APIs e versões de pacotes podem mudar nomes e estruturas de campos. Evite construir um relatório que dependa cegamente de um único campo sem primeiro verificar o objeto retornado.

---

# 9. Etapa 3 — inventário de arquivos por modalidade

Para análise exploratória, esta é uma das funções mais úteis:

```r
arquivos_resumo <- getSampleFilesSummary(projeto_alvo)

head(arquivos_resumo)
str(arquivos_resumo)
colnames(arquivos_resumo)
```

A função foi criada para resumir o número de arquivos por combinações de categoria/tipo/estratégia/plataforma, de forma semelhante à exploração de arquivos do portal GDC. Também aceita filtro por `open` ou `controlled` em versões que suportam esse argumento. [TCGAbiolinks — getSampleFilesSummary](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

### 9.1 Resumo por acesso

```r
arquivos_open <- getSampleFilesSummary(
  projeto_alvo,
  files.access = "open"
)

arquivos_controlled <- getSampleFilesSummary(
  projeto_alvo,
  files.access = "controlled"
)
```

Isso permite separar a disponibilidade de arquivos sem partir imediatamente para downloads.

---

# 10. Etapa 4 — consulta detalhada de arquivos com `GDCquery()`

!!! tip "Explore antes de preencher"
    Antes de definir `data.category`, `data.type`, `workflow.type`, `access`, `platform`, `experimental.strategy` ou `sample.type`, volte à Seção 6 e descubra os valores disponíveis para o projeto/consulta. Os valores usados nos exemplos abaixo são **modelos**, não uma lista fixa de opções.

`GDCquery()` consulta os arquivos do GDC e pode pesquisar tanto dados open quanto controlled. A documentação recomenda usar principalmente `project`, `data.category`, `data.type` e, quando necessário, `workflow.type`, além de filtros como `access`, `sample.type`, `experimental.strategy` e `platform`. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

## 10.1 Exemplo: expressão gênica

```r
query_exp <- GDCquery(
  project = projeto_alvo,
  data.category = categoria_alvo,
  data.type = tipo_dado_alvo
)
```

Recuperar a tabela de resultados:

```r
resultados_exp <- getResults(query_exp)

dim(resultados_exp)
colnames(resultados_exp)
head(resultados_exp)
```

`getResults()` transforma o objeto de consulta em uma tabela que pode ser utilizada para auditoria de metadados. [Manual TCGAbiolinks](https://www.bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

## 10.2 Quantidade de arquivos por acesso

Primeiro verifique se a coluna existe:

```r
"access" %in% colnames(resultados_exp)
```

Depois:

```r
table(resultados_exp$access, useNA = "ifany")
```

Ou:

```r
resultados_exp %>%
  count(access, sort = TRUE)
```

## 10.3 Tipos de amostras

```r
resultados_exp %>%
  count(sample_type, sort = TRUE)
```

Isso é particularmente importante em estudos tumorais porque um projeto pode conter **Primary Tumor**, **Solid Tissue Normal**, **Metastatic** e outros tipos.

## 10.4 Estratégias experimentais

```r
resultados_exp %>%
  count(experimental_strategy, sort = TRUE)
```

## 10.5 Plataformas

```r
resultados_exp %>%
  count(platform, sort = TRUE)
```

## 10.6 Data category e data type

```r
resultados_exp %>%
  count(data_category, data_type, sort = TRUE)
```

---

# 11. Etapa 5 — inventário amplo de categorias de dados

Uma análise exploratória profissional não deve começar supondo que o projeto possui apenas RNA-seq.

Você deve procurar, pelo menos, as seguintes categorias quando existirem:

| Categoria | Exemplos de interesse |
|---|---|
| Clinical | diagnoses, follow-ups, demographics, exposures, tratamentos |
| Biospecimen | samples, portions, analytes, aliquots |
| Transcriptome Profiling | RNA-seq, expressão gênica, miRNA |
| DNA Methylation | arrays/assays de metilação |
| Copy Number Variation | segmentos, CNV derivados |
| Simple Nucleotide Variation | MAF/variant data |
| Structural Variation | rearranjos/variantes estruturais, quando disponíveis |
| Proteome Profiling | proteômica, quando disponível |
| Genomic Profiling | dados/processamentos específicos do projeto |
| Slide Image / Histopathology | imagens, quando presentes |

> A lista exata deve ser derivada do que o GDC retornar. **Não assuma que todas as categorias estarão presentes em todos os projetos.**

## 11.1 Descobrir categorias a partir dos resultados

Para um inventário direcionado:

```r
query_amplo <- GDCquery(
  project = projeto_alvo,
  data.category = categoria_alvo
)
```

Para estudos práticos, entretanto, o mais robusto é combinar `getSampleFilesSummary()` para obter a visão de alto nível e `GDCquery()` para aprofundar nas modalidades que interessam.

---

# 12. Etapa 6 — dados clínicos

Antes de executar `GDCquery_clinic()`, há dois tipos principais de consulta usados neste protocolo:

```r
tipos_clinicos <- data.frame(
  tipo = c("clinical", "biospecimen"),
  finalidade = c(
    "Dados clínicos e entidades clínicas associadas",
    "Informações de biospecímenes"
  )
)

tipos_clinicos
```

Para a consulta clínica:

```r
tipo_clinico <- "clinical"
```

E para biospecímenes:

```r
tipo_biospecimen <- "biospecimen"
```

A documentação atual do TCGAbiolinks documenta `GDCquery_clinic()` com esses tipos de consulta. [Manual TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

A função `GDCquery_clinic()` recupera os dados clínicos indexados disponibilizados pelo GDC e aceita `type = "clinical"` ou `type = "biospecimen"`. A implementação atual do pacote também expande, na consulta clínica, entidades relacionadas a diagnósticos, seguimentos, tratamentos, anotações, histórico familiar, demografia e exposições. [TCGAbiolinks — GDCquery_clinic](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf), [código-fonte atual](https://github.com/BioinformaticsFMRP/TCGAbiolinks/blob/master/R/clinical.R)

## 12.1 Carregar o conjunto clínico

```r
clinico <- GDCquery_clinic(
  project = projeto_alvo,
  type = "clinical"
)

str(clinico)
dim(clinico)
colnames(clinico)
```

### 12.2 Quantos registros clínicos existem?

```r
nrow(clinico)
```

> **Atenção:** o número de linhas de uma tabela clínica não deve ser automaticamente interpretado como o número de pacientes sem verificar qual entidade/identificador representa cada linha.

Procure os identificadores:

```r
clinico %>%
  select(any_of(c("submitter_id", "case_id", "patient_id"))) %>%
  head()
```

### 12.3 Identificar o número de cases

```r
if ("case_id" %in% colnames(clinico)) {
  n_distinct(clinico$case_id)
}
```

Se o objeto usar outro identificador, adapte para a coluna correspondente.

---

# 13. Etapa 7 — dados de biospecímenes

Essa etapa é fundamental quando a pergunta envolve **paciente vs amostra vs tipo de tecido**.

```r
biospecimen <- GDCquery_clinic(
  project = projeto_alvo,
  type = "biospecimen"
)

str(biospecimen)
dim(biospecimen)
colnames(biospecimen)
```

A documentação do GDC descreve os dados de biospecímenes como informação sobre coleta, processamento e subdivisão das amostras, incluindo entidades como sample, portion, analyte e aliquot. [GDC Biospecimen Data](https://docs.gdc.cancer.gov/Encyclopedia/pages/Biospecimen_Data/)

### 13.1 Quantidade de amostras

Procure primeiro colunas candidatas:

```r
grep("sample", colnames(biospecimen), ignore.case = TRUE, value = TRUE)
```

Depois identifique uma coluna de ID de sample apropriada e use:

```r
n_distinct(biospecimen$sample_submitter_id)
```

> O nome exato da coluna pode variar conforme a estrutura devolvida. Sempre confirme com `colnames()` antes.

### 13.2 Tipos de amostra

```r
grep("sample_type|tissue_type|tumor_descriptor|specimen", 
     colnames(biospecimen),
     ignore.case = TRUE,
     value = TRUE)
```

Se existir `sample_type`:

```r
biospecimen %>%
  count(sample_type, sort = TRUE)
```

Se existir `tissue_type`:

```r
biospecimen %>%
  count(tissue_type, sort = TRUE)
```

Se existir `tumor_descriptor`:

```r
biospecimen %>%
  count(tumor_descriptor, sort = TRUE)
```

---

# 14. Etapa 8 — relacionar paciente, amostra e tecido

Uma das tabelas mais importantes do relatório final deve representar a hierarquia:

```text
case
  └── sample
        ├── sample type
        ├── tissue type
        ├── tumor descriptor
        └── aliquot(s)
```

Ao trabalhar com resultados de uma `GDCquery`, utilize os campos associados à amostra presentes em `getResults(query)` para construir uma tabela de auditoria.

Exemplo:

```r
colunas_interesse <- c(
  "cases",
  "sample_type",
  "tissue_type",
  "tumor_descriptor",
  "access",
  "data_category",
  "data_type",
  "experimental_strategy",
  "workflow_type",
  "platform"
)

resultados_exp %>%
  select(any_of(colunas_interesse)) %>%
  head()
```

Quando uma coluna não existir, `any_of()` evita que o script falhe apenas por uma diferença de estrutura.

---

# 15. Etapa 9 — acesso aberto versus controlado

O GDC classifica os dados em **open access** e **controlled access**. Dados controlados podem incluir dados de sequência bruta, como BAM/FASTQ, além de determinados VCFs/MAFs protegidos. A solicitação de dados controlados é realizada através do mecanismo de autorização do dbGaP e da autenticação apropriada. [GDC Controlled Access](https://docs.gdc.cancer.gov/Encyclopedia/pages/Controlled_Access/), [Data Security](https://docs.gdc.cancer.gov/Data/Data_Security/Data_Security/)

### 15.1 Regra importante

Não escreva no protocolo:

> "Todo RNA-seq é aberto".

A forma correta é:

> "O nível de acesso deve ser determinado a partir do campo `access` retornado pelo GDC para os arquivos/consultas relevantes."

Isso evita generalizações incorretas.

### 15.2 Tabela de acesso

```r
tabela_acesso <- resultados_exp %>%
  count(access, sort = TRUE) %>%
  mutate(
    percentual = 100 * n / sum(n)
  )

tabela_acesso
```

---

# 16. Etapa 10 — tratamentos

### Antes de analisar tratamentos: descobrir as variáveis disponíveis

Não presuma que uma coluna específica exista. Primeiro localize as colunas relacionadas a tratamento:

```r
colunas_tratamento <- grep(
  "treatment|drug|therapy|radiation|pharmaceutical|regimen|protocol",
  colnames(clinico),
  ignore.case = TRUE,
  value = TRUE
)

colunas_tratamento
```

Para cada coluna relevante, examine os valores reais:

```r
explorar_opcoes(clinico, colunas_tratamento[1])
```


Os dados clínicos do GDC podem conter informações relacionadas a tratamentos. No fluxo moderno do TCGAbiolinks, `GDCquery_clinic(type = "clinical")` consulta a informação clínica indexada com entidades relacionadas, incluindo tratamentos dentro do modelo clínico. [Código-fonte TCGAbiolinks](https://github.com/BioinformaticsFMRP/TCGAbiolinks/blob/master/R/clinical.R)

Comece pesquisando as colunas disponíveis:

```r
grep(
  "treatment|drug|therapy|radiation|pharmaceutical|regimen|protocol",
  colnames(clinico),
  ignore.case = TRUE,
  value = TRUE
)
```

Depois examine as variáveis relevantes:

```r
summary(clinico)
```

Para uma coluna específica:

```r
if ("treatment_type" %in% colnames(clinico)) {
  clinico %>% count(treatment_type, sort = TRUE)
}
```

> **Importante:** os campos clínicos disponíveis podem variar entre projetos. A ausência de uma coluna não significa necessariamente ausência absoluta de informação no GDC; significa que aquela variável não está disponível naquele objeto/endpoint no formato esperado.

---

# 17. Etapa 11 — estágio tumoral

O estágio é um dos metadados mais importantes para estudos oncológicos.

Primeiro identifique possíveis colunas:

```r
grep(
  "stage|ajcc|clinical_stage|pathologic_stage",
  colnames(clinico),
  ignore.case = TRUE,
  value = TRUE
)
```

Exemplo:

```r
if ("tumor_stage" %in% colnames(clinico)) {
  tabela_estagio <- clinico %>%
    count(tumor_stage, sort = TRUE)

  tabela_estagio
}
```

Também é recomendável calcular a quantidade de valores ausentes:

```r
if ("tumor_stage" %in% colnames(clinico)) {
  clinico %>%
    summarise(
      total = n(),
      missing = sum(is.na(tumor_stage) | tumor_stage == ""),
      preenchido = total - missing,
      percentual_preenchido = 100 * preenchido / total
    )
}
```

---

# 18. Etapa 12 — dados demográficos

Algumas variáveis frequentemente exploradas incluem sexo/gênero, raça, etnia e idade, quando disponíveis.

Primeiro:

```r
grep(
  "gender|sex|race|ethnicity|age",
  colnames(clinico),
  ignore.case = TRUE,
  value = TRUE
)
```

Depois:

```r
if ("gender" %in% colnames(clinico)) {
  clinico %>% count(gender, sort = TRUE)
}

if ("race" %in% colnames(clinico)) {
  clinico %>% count(race, sort = TRUE)
}

if ("ethnicity" %in% colnames(clinico)) {
  clinico %>% count(ethnicity, sort = TRUE)
}
```

---

# 19. Etapa 13 — status vital e sobrevida potencial

A exploração inicial pode registrar quantos casos têm informação de status vital:

```r
if ("vital_status" %in% colnames(clinico)) {
  clinico %>%
    count(vital_status, sort = TRUE)
}
```

Se houver tempo de follow-up ou data de morte, registre a disponibilidade:

```r
grep(
  "death|follow|days_to|survival",
  colnames(clinico),
  ignore.case = TRUE,
  value = TRUE
)
```

> **Neste protocolo, não é necessário executar Kaplan-Meier.** A finalidade aqui é documentar se a informação necessária para futuras análises está disponível.

---

# 20. Etapa 14 — qualidade e completude dos metadados

Uma análise exploratória profissional precisa medir **missingness**.

## 20.1 Percentual de valores ausentes

```r
missing_summary <- tibble(
  variable = colnames(clinico),
  total = nrow(clinico),
  missing = map_int(
    clinico,
    ~ sum(is.na(.x) | (is.character(.x) & .x == ""))
  ),
  complete = total - missing,
  complete_percent = 100 * complete / total
) %>%
  arrange(complete_percent)

missing_summary
```

Isso cria uma tabela útil para responder:

- quais variáveis são mais completas;
- quais possuem muita informação ausente;
- quais variáveis são inadequadas para estratificação;
- quais covariáveis podem gerar perda substancial de casos.

---

# 21. Etapa 15 — disponibilidade de tumor e normal

Para estudos de expressão, este é um dos pontos mais relevantes.

Supondo que você tenha uma consulta molecular:

```r
resultados_exp %>%
  count(sample_type, sort = TRUE)
```

Também é útil calcular o percentual:

```r
resultado_amostras <- resultados_exp %>%
  count(sample_type, sort = TRUE) %>%
  mutate(percentual = 100 * n / sum(n))

resultado_amostras
```

Para um estudo tumor-vs-normal, registre explicitamente:

```text
Número de amostras de tumor
Número de amostras normais
Número de pacientes com tumor
Número de pacientes com normal
Número de pacientes pareados tumor-normal
```

O último item **não deve ser inferido apenas pela soma dos grupos**. Ele exige uma ligação por identificador de caso/paciente.

---

# 22. Etapa 16 — identificar possíveis pares tumor-normal

Uma estratégia geral é extrair o identificador do caso/participante a partir dos barcodes TCGA quando apropriado ou utilizar `case_id`/identificadores equivalentes disponibilizados pelo GDC.

Exemplo conceitual com barcode TCGA:

```r
resultados_exp <- resultados_exp %>%
  mutate(
    participant_id = str_extract(cases, "TCGA-[A-Z0-9]{2}-[A-Z0-9]{4}")
  )
```

Depois:

```r
pares <- resultados_exp %>%
  filter(sample_type %in% c("Primary Tumor", "Solid Tissue Normal")) %>%
  distinct(participant_id, sample_type) %>%
  count(participant_id) %>%
  filter(n >= 2)

nrow(pares)
```

> Esse exemplo é ilustrativo. Como os campos de `cases` podem conter IDs ou estruturas diferentes dependendo do retorno, valide a coluna e a estratégia de extração antes de usá-la em um estudo formal.

---

# 23. Etapa 17 — quantidade de arquivos por categoria e tipo

```r
if (all(c("data_category", "data_type") %in% colnames(resultados_exp))) {
  tabela_modalidades <- resultados_exp %>%
    count(data_category, data_type, sort = TRUE)

  tabela_modalidades
}
```

Uma versão mais completa:

```r
colunas_modalidade <- intersect(
  c(
    "data_category",
    "data_type",
    "experimental_strategy",
    "workflow_type",
    "platform",
    "access",
    "sample_type"
  ),
  colnames(resultados_exp)
)

tabela_modalidades <- resultados_exp %>%
  count(across(all_of(colunas_modalidade)), sort = TRUE)
```

Essa tabela é candidata direta para entrar no relatório final.

---

# 24. Etapa 18 — tamanho dos arquivos

Quando `file_size` estiver disponível:

```r
if ("file_size" %in% colnames(resultados_exp)) {
  resultados_exp %>%
    summarise(
      arquivos = n(),
      bytes = sum(as.numeric(file_size), na.rm = TRUE),
      GB = bytes / 1024^3,
      TB = bytes / 1024^4
    )
}
```

Também é interessante comparar open vs controlled:

```r
if (all(c("file_size", "access") %in% colnames(resultados_exp))) {
  resultados_exp %>%
    group_by(access) %>%
    summarise(
      arquivos = n(),
      GB = sum(as.numeric(file_size), na.rm = TRUE) / 1024^3,
      .groups = "drop"
    )
}
```

> **Importante:** o tamanho total é uma estimativa dos arquivos retornados pela consulta, não do tamanho de todos os arquivos existentes no universo GDC.

---

# 25. Etapa 19 — distribuição por centro/plataforma/estratégia

Quando presentes, avalie:

```r
grep(
  "center|platform|strategy|workflow|instrument",
  colnames(resultados_exp),
  ignore.case = TRUE,
  value = TRUE
)
```

E gere as tabelas correspondentes:

```r
resultados_exp %>% count(platform, sort = TRUE)
resultados_exp %>% count(experimental_strategy, sort = TRUE)
resultados_exp %>% count(workflow_type, sort = TRUE)
```

Isso permite identificar heterogeneidade técnica antes da análise molecular.

---

# 26. Etapa 20 — exportar tabelas profissionais

Não limite o relatório a `print()` no console.

Crie um diretório:

```r
dir.create("tcga_exploracao", showWarnings = FALSE)
dir.create("tcga_exploracao/tabelas", showWarnings = FALSE)
dir.create("tcga_exploracao/graficos", showWarnings = FALSE)
dir.create("tcga_exploracao/objetos", showWarnings = FALSE)
```

Exportar:

```r
write_csv(projetos_gdc, "tcga_exploracao/tabelas/projetos_gdc.csv")
write_csv(clinico, "tcga_exploracao/tabelas/dados_clinicos.csv")
write_csv(biospecimen, "tcga_exploracao/tabelas/biospecimen.csv")
write_csv(missing_summary, "tcga_exploracao/tabelas/missingness_clinico.csv")
write_csv(arquivos_resumo, "tcga_exploracao/tabelas/resumo_arquivos.csv")
```

Para resultados moleculares:

```r
write_csv(resultados_exp, "tcga_exploracao/tabelas/resultado_query_expressao.csv")
```

---

# 27. Etapa 21 — gerar uma planilha XLSX consolidada

Para entregar ao pesquisador um arquivo profissional:

```r
write_xlsx(
  list(
    Clinical = clinico,
    Biospecimen = biospecimen,
    Missingness = missing_summary,
    FileSummary = arquivos_resumo,
    ExpressionQuery = resultados_exp
  ),
  path = "tcga_exploracao/TCGA_exploracao_resumo.xlsx"
)
```

O resultado é um workbook com várias abas, adequado para auditoria manual, reuniões de projeto e documentação do desenho da coorte.

---

# 28. Etapa 22 — gráficos exploratórios

## 28.1 Amostras por tipo

```r
grafico_amostras <- resultados_exp %>%
  count(sample_type, sort = TRUE) %>%
  ggplot(aes(x = reorder(sample_type, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(
    title = paste("Amostras por tipo —", projeto_alvo),
    x = "Tipo de amostra",
    y = "Número de registros"
  ) +
  theme_minimal()

ggsave(
  "tcga_exploracao/graficos/amostras_por_tipo.png",
  grafico_amostras,
  width = 9,
  height = 6,
  dpi = 300
)
```

## 28.2 Arquivos por acesso

```r
if ("access" %in% colnames(resultados_exp)) {
  grafico_acesso <- resultados_exp %>%
    count(access) %>%
    ggplot(aes(x = access, y = n)) +
    geom_col() +
    labs(
      title = paste("Acesso aos arquivos —", projeto_alvo),
      x = "Acesso",
      y = "Número de arquivos"
    ) +
    theme_minimal()

  ggsave(
    "tcga_exploracao/graficos/arquivos_por_acesso.png",
    grafico_acesso,
    width = 7,
    height = 5,
    dpi = 300
  )
}
```

---

# 29. Etapa 23 — matriz de perguntas e respostas

Um relatório profissional deve conter uma tabela executiva como esta:

| Indicador | Resultado | Fonte | Observação |
|---|---:|---|---|
| Project ID | `TCGA-XXX` | GDC project | Identificador do estudo |
| Cases | N | GDC clinical/API | Pacientes/cases cadastrados |
| Samples | N | Biospecimen | Amostras biológicas |
| Aliquots | N | Biospecimen | Quando disponível |
| Arquivos | N | GDC query | Total da consulta |
| Open files | N | `access` | Acesso aberto |
| Controlled files | N | `access` | Acesso controlado |
| Tumor samples | N | Sample metadata | Tipos definidos pelo GDC |
| Normal samples | N | Sample metadata | Tipos definidos pelo GDC |
| Clinical records | N | Clinical | Registros retornados |
| Tratamento | Sim/Não/Parcial | Clinical | Depende dos campos disponíveis |
| Stage | Sim/Não/Parcial | Clinical | Depende da completude |
| Survival fields | Sim/Não/Parcial | Clinical | Disponibilidade de variáveis |
| RNA-seq | Sim/Não | File query | Verificar estratégia/workflow |
| DNA methylation | Sim/Não | File summary | Verificar categoria |
| CNV | Sim/Não | File summary | Verificar categoria |
| SNV/Mutation | Sim/Não | File summary | Verificar categoria |

A coluna **Observação** é importante porque evita que um número seja interpretado fora de contexto.

---

# 30. Checklist de exploração antes de cada consulta

Antes de executar qualquer consulta, responda às perguntas abaixo.

- [ ] Quais projetos existem?
- [ ] Qual projeto será analisado?
- [ ] O projeto escolhido foi validado contra `getGDCprojects()`?
- [ ] Quais categorias de dados existem nesse projeto?
- [ ] Qual categoria será analisada?
- [ ] Quais `data.type` existem nessa categoria?
- [ ] Quais `workflow.type` existem?
- [ ] Quais níveis de `access` existem?
- [ ] Quais `sample.type` existem?
- [ ] Quais `experimental.strategy` existem?
- [ ] Quais `platform` existem?
- [ ] Quais `data.format` existem?
- [ ] Quantos arquivos/registros correspondem a cada opção?
- [ ] Existem dados open e controlled?
- [ ] Os tipos de amostra necessários para a pergunta biológica estão disponíveis?
- [ ] Os resultados da consulta foram auditados antes de qualquer download?

Esse checklist é deliberadamente colocado antes do pipeline final: o objetivo é impedir que o script seja executado com filtros copiados de outro projeto sem verificar sua disponibilidade.

---

# 31. Pipeline reutilizável completo

A seguir está um esqueleto que pode ser adaptado para diversos projetos. O princípio é manter as consultas separadas das análises.

```r
# ============================================================
# TCGA/GDC — PROTOCOLO DE ANÁLISE EXPLORATÓRIA
# ============================================================

# ---------------------------
# 1. Configuração
# ---------------------------
project_id <- "TCGA-BRCA"
output_dir <- "tcga_exploracao"

# Defina estes valores somente depois de explorar as opções disponíveis
categoria_alvo <- "Transcriptome Profiling"
tipo_dado_alvo <- "Gene Expression Quantification"

# ---------------------------
# 2. Pacotes
# ---------------------------
packages <- c(
  "TCGAbiolinks",
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "purrr",
  "ggplot2",
  "writexl"
)

for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf(
        "Pacote '%s' não instalado. Instale-o antes de executar o protocolo.",
        pkg
      )
    )
  }
}

suppressPackageStartupMessages({
  library(TCGAbiolinks)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(purrr)
  library(ggplot2)
  library(writexl)
})

# ---------------------------
# 3. Diretórios
# ---------------------------
dir.create(output_dir, showWarnings = FALSE)
dir.create(file.path(output_dir, "tabelas"), showWarnings = FALSE)
dir.create(file.path(output_dir, "graficos"), showWarnings = FALSE)
dir.create(file.path(output_dir, "objetos"), showWarnings = FALSE)

# ---------------------------
# 4. Teste da API
# ---------------------------
message("Testando disponibilidade do GDC...")
print(getGDCInfo())

# ---------------------------
# 5. Projetos
# ---------------------------
message("Consultando projetos...")
projetos <- getGDCprojects()

if (!project_id %in% projetos$project_id) {
  stop(
    paste0(
      "Projeto não encontrado: ", project_id,
      "\nUse getGDCprojects() para verificar o identificador."
    )
  )
}

projeto_info <- projetos %>%
  filter(.data$project_id == project_id)

# ---------------------------
# 6. Resumo do projeto
# ---------------------------
message("Consultando resumo do projeto...")
resumo_projeto <- getProjectSummary(project_id)

# ---------------------------
# 7. Sumário de arquivos
# ---------------------------
message("Consultando resumo de arquivos...")
file_summary <- getSampleFilesSummary(project_id)

# ---------------------------
# 8. Clinical
# ---------------------------
message("Consultando dados clínicos...")
clinical <- GDCquery_clinic(
  project = project_id,
  type = "clinical"
)

# ---------------------------
# 9. Biospecimen
# ---------------------------
message("Consultando dados de biospecímenes...")
biospecimen <- GDCquery_clinic(
  project = project_id,
  type = "biospecimen"
)

# ---------------------------
# 10. Consulta molecular exemplo
# ---------------------------
message("Consultando Transcriptome Profiling...")
query_rna <- GDCquery(
  project = project_id,
  data.category = "Transcriptome Profiling",
  data.type = "Gene Expression Quantification"
)

rna_results <- getResults(query_rna)

# ---------------------------
# 11. Tabelas básicas
# ---------------------------
if ("access" %in% colnames(rna_results)) {
  access_summary <- rna_results %>%
    count(access, sort = TRUE) %>%
    mutate(percent = 100 * n / sum(n))
} else {
  access_summary <- tibble(
    access = character(),
    n = integer(),
    percent = numeric()
  )
}

if ("sample_type" %in% colnames(rna_results)) {
  sample_summary <- rna_results %>%
    count(sample_type, sort = TRUE) %>%
    mutate(percent = 100 * n / sum(n))
} else {
  sample_summary <- tibble(
    sample_type = character(),
    n = integer(),
    percent = numeric()
  )
}

modalities <- rna_results %>%
  count(
    across(
      any_of(c(
        "data_category",
        "data_type",
        "experimental_strategy",
        "workflow_type",
        "platform",
        "access"
      ))
    ),
    sort = TRUE
  )

missingness <- tibble(
  variable = names(clinical),
  total = nrow(clinical),
  missing = map_int(
    clinical,
    ~ sum(is.na(.x) | (is.character(.x) & .x == ""))
  )
) %>%
  mutate(
    complete = total - missing,
    complete_percent = ifelse(total > 0, 100 * complete / total, NA_real_)
  ) %>%
  arrange(complete_percent)

# ---------------------------
# 12. Exportação CSV
# ---------------------------
write_csv(
  projetos,
  file.path(output_dir, "tabelas", "projetos_gdc.csv")
)

write_csv(
  projeto_info,
  file.path(output_dir, "tabelas", "projeto_selecionado.csv")
)

write_csv(
  file_summary,
  file.path(output_dir, "tabelas", "resumo_arquivos.csv")
)

write_csv(
  clinical,
  file.path(output_dir, "tabelas", "clinical.csv")
)

write_csv(
  biospecimen,
  file.path(output_dir, "tabelas", "biospecimen.csv")
)

write_csv(
  rna_results,
  file.path(output_dir, "tabelas", "rna_query_results.csv")
)

write_csv(
  access_summary,
  file.path(output_dir, "tabelas", "rna_access_summary.csv")
)

write_csv(
  sample_summary,
  file.path(output_dir, "tabelas", "rna_sample_summary.csv")
)

write_csv(
  modalities,
  file.path(output_dir, "tabelas", "rna_modalities.csv")
)

write_csv(
  missingness,
  file.path(output_dir, "tabelas", "clinical_missingness.csv")
)

# ---------------------------
# 13. Exportação XLSX
# ---------------------------
write_xlsx(
  list(
    Project = projeto_info,
    FileSummary = file_summary,
    Clinical = clinical,
    Biospecimen = biospecimen,
    RNA_Access = access_summary,
    RNA_Samples = sample_summary,
    RNA_Modalities = modalities,
    Clinical_Missingness = missingness
  ),
  path = file.path(
    output_dir,
    paste0(project_id, "_exploracao.xlsx")
  )
)

# ---------------------------
# 14. Gráficos
# ---------------------------
if (nrow(sample_summary) > 0) {
  p_sample <- ggplot(
    sample_summary,
    aes(x = reorder(sample_type, n), y = n)
  ) +
    geom_col() +
    coord_flip() +
    labs(
      title = paste("Amostras por tipo —", project_id),
      x = "Tipo de amostra",
      y = "N"
    ) +
    theme_minimal()

  ggsave(
    file.path(
      output_dir,
      "graficos",
      "amostras_por_tipo.png"
    ),
    p_sample,
    width = 9,
    height = 6,
    dpi = 300
  )
}

if (nrow(access_summary) > 0) {
  p_access <- ggplot(
    access_summary,
    aes(x = access, y = n)
  ) +
    geom_col() +
    labs(
      title = paste("Acesso aos arquivos —", project_id),
      x = "Acesso",
      y = "N"
    ) +
    theme_minimal()

  ggsave(
    file.path(
      output_dir,
      "graficos",
      "acesso_arquivos.png"
    ),
    p_access,
    width = 7,
    height = 5,
    dpi = 300
  )
}

# ---------------------------
# 15. Salvar objetos R
# ---------------------------
saveRDS(
  list(
    project_id = project_id,
    projetos = projetos,
    projeto_info = projeto_info,
    resumo_projeto = resumo_projeto,
    file_summary = file_summary,
    clinical = clinical,
    biospecimen = biospecimen,
    query_rna = query_rna,
    rna_results = rna_results,
    access_summary = access_summary,
    sample_summary = sample_summary,
    modalities = modalities,
    missingness = missingness
  ),
  file.path(
    output_dir,
    "objetos",
    paste0(project_id, "_exploracao.rds")
  )
)

message("Exploração concluída: ", output_dir)
```

---

# 31. Problema importante no script acima: escopo e nomes de variáveis

Ao transformar esse exemplo em um pipeline institucional, prefira **não utilizar o mesmo nome para a variável que contém o `project_id` e a coluna `project_id`**.

Em um código robusto, use:

```r
projeto_alvo <- "TCGA-BRCA"

projeto_info <- projetos %>%
  filter(.data$project_id == projeto_alvo)
```

Esse pequeno cuidado evita ambiguidades no `dplyr`.

---

# 32. Versão recomendada do bloco principal

Use esta forma como base do seu pipeline final:

```r
projeto_alvo <- "TCGA-BRCA"

projetos <- getGDCprojects()

if (!projeto_alvo %in% projetos$project_id) {
  stop("Projeto não encontrado no GDC: ", projeto_alvo)
}

projeto_info <- projetos %>%
  filter(.data$project_id == projeto_alvo)

resumo_projeto <- getProjectSummary(projeto_alvo)

resumo_arquivos <- getSampleFilesSummary(projeto_alvo)

clinical <- GDCquery_clinic(
  project = projeto_alvo,
  type = "clinical"
)

biospecimen <- GDCquery_clinic(
  project = projeto_alvo,
  type = "biospecimen"
)
```

---

# 33. Etapa 24 — consulta de modalidades específicas

Depois do inventário inicial, as modalidades relevantes podem ser consultadas individualmente.

## 33.1 RNA-seq / expressão

```r
query_rna <- GDCquery(
  project = projeto_alvo,
  data.category = "Transcriptome Profiling",
  data.type = "Gene Expression Quantification"
)
```

## 33.2 miRNA

A disponibilidade exata depende da estrutura atual do projeto/GDC. Sempre use o inventário de arquivos para confirmar o `data.type` antes da consulta final.

Exemplo de exploração:

```r
query_preview <- GDCquery(
  project = projeto_alvo,
  data.category = "Transcriptome Profiling"
)

preview <- getResults(query_preview)

preview %>%
  count(data_type, sort = TRUE)
```

## 33.3 Mutações / SNV

Primeiro descubra os tipos realmente presentes:

```r
preview %>%
  count(data_category, data_type, sort = TRUE)
```

Depois filtre exatamente o tipo retornado pelo GDC.

## 33.4 CNV

```r
preview %>%
  count(data_category, data_type, sort = TRUE)
```

O princípio é sempre:

```text
inventariar → descobrir o tipo exato → consultar → contar → exportar
```

Isso é mais robusto do que copiar uma query antiga de outro projeto.

---

# 34. Etapa 25 — não baixar dados ainda

Durante a exploração, **não execute automaticamente**:

```r
GDCdownload(query)
```

nem:

```r
GDCprepare(query)
```

Essas funções pertencem à etapa posterior, na qual você já definiu a coorte e os dados necessários.

A exploração deve ocorrer majoritariamente sobre:

- listas de projetos;
- metadados;
- resultados de consultas;
- clinical;
- biospecimen;
- resumo de arquivos;
- distribuição de acesso;
- amostras e tipos de amostras.

O GDC também disponibiliza manifests e mecanismos de download para volumes maiores; o download de dados controlados requer autenticação apropriada. [GDC Downloading Files](https://docs.gdc.cancer.gov/API/Users_Guide/Downloading_Files/), [GDC API Authentication](https://docs.gdc.cancer.gov/API/Users_Guide/Getting_Started/)

---

# 35. Quando partir para o download

O download deve ser uma consequência do inventário.

Exemplo conceitual:

```text
Exploração
    ↓
Existe RNA-seq?
    ↓ sim
Quais workflows?
    ↓
Qual acesso?
    ↓
Quais sample types?
    ↓
Há tumor e normal?
    ↓
Há metadado clínico adequado?
    ↓
Quantidade final de amostras definida
    ↓
Query restrita
    ↓
GDCdownload()
    ↓
GDCprepare()
```

Isso evita baixar dezenas ou centenas de gigabytes antes de saber se a coorte atende ao objetivo científico.

---

# 36. Protocolo de controle de qualidade antes do download

Preencha esta checklist para cada projeto:

- [ ] O `project_id` foi validado no GDC?
- [ ] O número de cases foi registrado?
- [ ] O número de samples foi registrado?
- [ ] O número de aliquots foi registrado quando disponível?
- [ ] Os tipos de amostras foram listados?
- [ ] Tumor e normal foram contabilizados separadamente?
- [ ] O número de casos únicos foi diferenciado do número de arquivos?
- [ ] A lista de categorias de dados foi registrada?
- [ ] Os `data.type` relevantes foram identificados?
- [ ] As estratégias experimentais foram registradas?
- [ ] Os workflows relevantes foram registrados?
- [ ] Open e controlled foram separados?
- [ ] O tamanho estimado dos arquivos foi registrado quando disponível?
- [ ] Os dados clínicos foram consultados?
- [ ] Os dados de biospecímenes foram consultados?
- [ ] A disponibilidade de estágio foi verificada?
- [ ] A disponibilidade de tratamento foi verificada?
- [ ] O status vital foi verificado?
- [ ] A completude das principais variáveis clínicas foi calculada?
- [ ] Foram identificados campos críticos com muitos valores ausentes?
- [ ] A disponibilidade de tumor/normal foi confirmada?
- [ ] A coorte final foi definida antes do download?

---

# 37. Estrutura recomendada do relatório final

O relatório produzido para cada projeto pode seguir exatamente esta ordem:

## 37.1 Resumo executivo

- Projeto
- Data da consulta
- Versão do R
- Versão do Bioconductor
- Versão do TCGAbiolinks
- Número de cases
- Número de samples
- Número de aliquots
- Número de arquivos
- Open vs controlled

## 37.2 Perfil clínico

- sexo/gênero;
- raça;
- etnia;
- idade;
- diagnóstico;
- estágio;
- tratamento;
- exposição;
- follow-up;
- vital status.

## 37.3 Perfil biospecimen

- sample type;
- tissue type;
- tumor descriptor;
- specimen type;
- preservation method;
- portion;
- analyte;
- aliquot.

## 37.4 Perfil molecular

- data category;
- data type;
- experimental strategy;
- platform;
- workflow;
- access;
- file count;
- file size.

## 37.5 Auditoria de completude

- missingness clínico;
- variáveis ausentes;
- grupos muito pequenos;
- possíveis limitações de pareamento.

## 37.6 Decisão de cohort

Documente:

```text
Incluídos:
  - sample types X/Y
  - workflow Z
  - access open
  - n = ...

Excluídos:
  - tipo de amostra ...
  - workflow ...
  - dados controlled ...
  - amostras sem metadata crítica ...
```

Essa seção é especialmente útil para garantir rastreabilidade.

---

# 38. Estrutura de pastas recomendada

Para projetos de pesquisa diferentes, mantenha uma estrutura padronizada:

```text
tcga/
├── exploracao/
│   ├── scripts/
│   │   ├── 01_inventario_projeto.R
│   │   ├── 02_clinical_biospecimen.R
│   │   ├── 03_molecular_queries.R
│   │   └── 04_relatorio.R
│   ├── resultados/
│   │   ├── tabelas/
│   │   ├── graficos/
│   │   └── objetos/
│   └── relatorio/
│       └── TCGA-XXX_exploracao.html
│
└── dados/
    └── TCGA-XXX/
        ├── manifestos/
        ├── raw/
        └── processed/
```

---

# 39. Como transformar o protocolo em ferramenta reutilizável

A melhor evolução do protocolo é transformar o código em uma função.

Exemplo de assinatura:

```r
explorar_tcga <- function(
  projeto,
  output_dir = paste0("exploracao_", projeto)
) {

  # consultas
  # tabelas
  # gráficos
  # exportações

  invisible(TRUE)
}
```

Depois:

```r
explorar_tcga("TCGA-BRCA")
explorar_tcga("TCGA-PRAD")
explorar_tcga("TCGA-COAD")
explorar_tcga("TCGA-READ")
```

Isso transforma o protocolo em um componente reaproveitável para diferentes estudos.

---

# 40. Extensão recomendada — tabela mestre de disponibilidade

Uma tabela mestre pode utilizar a estrutura:

| Projeto | Data category | Data type | Strategy | Workflow | Platform | Access | Files | Samples |
|---|---|---|---|---|---|---|---:|---:|
| TCGA-XXX | Transcriptome Profiling | Gene Expression Quantification | RNA-Seq | STAR - Counts | Illumina | open | ... | ... |

Essa tabela permite comparar projetos diferentes sem misturar as unidades de análise.

---

# 41. Extensão recomendada — comparação entre vários projetos

A mesma arquitetura pode ser aplicada a vários projetos.

```r
projetos_alvo <- c(
  "TCGA-COAD",
  "TCGA-READ",
  "TCGA-PRAD",
  "TCGA-BRCA"
)
```

Uma estratégia segura é executar uma função por projeto e depois concatenar apenas tabelas homogêneas:

```r
resumos <- map_dfr(
  projetos_alvo,
  function(p) {
    x <- getSampleFilesSummary(p)
    x$project_id <- p
    x
  }
)
```

A partir disso, você pode gerar uma matriz de disponibilidade:

```r
resumos %>%
  count(project_id, data_category, data_type)
```

---

# 42. O que este protocolo NÃO faz

Este protocolo não substitui:

- controle de qualidade de FASTQ/BAM;
- avaliação de alinhamento;
- normalização de expressão;
- filtragem de genes;
- análise de expressão diferencial;
- análise de variantes;
- análise de CNV;
- análise de metilação;
- análise de sobrevida propriamente dita;
- modelagem estatística.

Ele é a **camada de descoberta, auditoria e planejamento** que deve anteceder essas análises.

---

# 43. Interpretação dos principais números

Ao escrever o relatório, mantenha estas regras:

### Não confundir arquivos com pacientes

```text
1000 files ≠ 1000 patients
```

### Não confundir samples com cases

```text
500 samples ≠ 500 patients necessariamente
```

### Não inferir acesso pelo tipo do dado

```text
"RNA-seq" não é sinônimo automático de "open"
```

O campo de acesso deve ser consultado diretamente.

### Não assumir ausência de informação pela falta de uma variável

Uma coluna ausente em um objeto não prova que a informação não existe em nenhuma camada do GDC.

### Não interpretar missingness como exclusão automática

Um campo com 30% de missing não deve ser simplesmente descartado sem avaliar se esses 30% pertencem a um subgrupo importante.

---

# 44. Boas práticas de reprodutibilidade

Registre em cada execução:

```r
sessionInfo()
```

Também salve:

```r
sink("tcga_exploracao/sessionInfo.txt")
sessionInfo()
sink()
```

Recomenda-se também registrar a data:

```r
Sys.time()
```

E o projeto:

```r
project_id
```

Isso é importante porque o GDC fornece a versão mais recente dos dados por padrão; arquivos podem ser atualizados, substituídos ou removidos conforme o processo de curadoria e manutenção do GDC. [GDC Latest Data](https://docs.gdc.cancer.gov/Encyclopedia/pages/Latest_Data/)

---

# 45. Geração de relatório HTML

Uma etapa profissional é converter o protocolo em um relatório HTML executável.

Crie:

```text
TCGA_exploracao.Rmd
```

Estrutura mínima:

```yaml
---
title: "Análise Exploratória do TCGA"
author: "Seu Nome / Laboratório"
date: "`r Sys.Date()`"
output:
  html_document:
    toc: true
    toc_float: true
    number_sections: true
---
```

No corpo, insira os mesmos blocos R utilizados na exploração.

Renderize com:

```r
rmarkdown::render("TCGA_exploracao.Rmd")
```

O produto final pode ser um relatório HTML contendo:

- tabelas;
- gráficos;
- parâmetros;
- versões de software;
- número de amostras;
- dados clínicos;
- disponibilidade molecular;
- limitações.

---

# 46. Modelo de conclusão para cada projeto

O relatório pode terminar com um texto estruturado como:

> **Conclusão da exploração:** o projeto `TCGA-XXX` apresenta `N` cases e `M` amostras identificadas nas camadas consultadas. Foram encontradas as categorias de dados `...`, com `N` arquivos open e `M` arquivos controlled na consulta avaliada. A distribuição de amostras foi `...`. Os dados clínicos apresentaram disponibilidade para `...`, enquanto as variáveis `...` apresentaram maior proporção de valores ausentes. Para o objetivo `...`, a coorte potencialmente elegível compreende `...` amostras/pacientes. Antes do download definitivo, recomenda-se restringir a consulta por `sample.type`, `workflow.type`, `access` e demais critérios do desenho experimental.

Esse texto deve ser **gerado a partir dos números reais**, e não copiado literalmente entre projetos.

---

# 47. Referências e documentação oficial

## GDC

- [GDC Documentation](https://docs.gdc.cancer.gov/)
- [GDC Data Introduction](https://docs.gdc.cancer.gov/Data/Introduction/)
- [GDC Data Portal](https://portal.gdc.cancer.gov/)
- [GDC API User Guide](https://docs.gdc.cancer.gov/API/PDF/API_UG.pdf)
- [GDC API Getting Started](https://docs.gdc.cancer.gov/API/Users_Guide/Getting_Started/)
- [GDC Downloading Files](https://docs.gdc.cancer.gov/API/Users_Guide/Downloading_Files/)
- [GDC Data Access Policy](https://docs.gdc.cancer.gov/Encyclopedia/pages/Data_Access_Policy/)
- [GDC Controlled Access](https://docs.gdc.cancer.gov/Encyclopedia/pages/Controlled_Access/)
- [GDC Biospecimen Data](https://docs.gdc.cancer.gov/Encyclopedia/pages/Biospecimen_Data/)
- [GDC Data Dictionary](https://docs.gdc.cancer.gov/Data_Dictionary/)
- [GDC Latest Data](https://docs.gdc.cancer.gov/Encyclopedia/pages/Latest_Data/)

## TCGAbiolinks

- [TCGAbiolinks no Bioconductor](https://bioconductor.org/packages/release/bioc/html/TCGAbiolinks.html)
- [Manual do TCGAbiolinks](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)
- [Vignette — Searching GDC database](https://bioconductor.unipi.it/packages/release/bioc/vignettes/TCGAbiolinks/inst/doc/query.html)
- [GDCquery](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)
- [GDCquery_clinic](https://rdrr.io/bioc/TCGAbiolinks/man/GDCquery_clinic.html)
- [getGDCprojects](https://rdrr.io/bioc/TCGAbiolinks/man/getGDCprojects.html)
- [getProjectSummary](https://rdrr.io/bioc/TCGAbiolinks/man/getProjectSummary.html)
- [getSampleFilesSummary](https://bioconductor.org/packages/release/bioc/manuals/TCGAbiolinks/man/TCGAbiolinks.pdf)

## Referência clássica

Colaprico A, Silva TC, Olsen C, Garofano L, Cava C, Garolini D, Sabedot TS, Malta TM, Pagnotta SM, Castiglioni I, Ceccarelli M, Bontempi G. **TCGAbiolinks: an R/Bioconductor package for integrative analysis of TCGA data.** *Nucleic Acids Research*. 2016;44(8):e71.

---

# 48. Sugestão de organização no seu MkDocs

Recomendo criar a hierarquia:

```yaml
nav:
  - Bioinformática:
      - Bancos de Dados Públicos:
          - "Exploração do TCGA/GDC": bioinfo/bancos/exploracao_tcga.md
```

Se futuramente você transformar isso em uma coleção, uma estrutura consistente seria:

```yaml
nav:
  - Bioinformática:
      - Bancos de Dados Públicos:
          - "Exploração do TCGA/GDC": bioinfo/bancos/exploracao_tcga.md
          - "Exploração do GEO": bioinfo/bancos/exploracao_geo.md
          - "Exploração do SRA": bioinfo/bancos/exploracao_sra.md
          - "Exploração do GTEx": bioinfo/bancos/exploracao_gtex.md
          - "Exploração do UCSC Xena": bioinfo/bancos/exploracao_xena.md
```

Isso cria uma seção de **protocolos de exploração de bancos públicos**, independente da etapa posterior de análise.

---

# 49. Resultado esperado do protocolo

A saída de uma execução completa deve ser algo próximo de:

```text
tcga_exploracao/
├── tabelas/
│   ├── projetos_gdc.csv
│   ├── projeto_selecionado.csv
│   ├── resumo_arquivos.csv
│   ├── clinical.csv
│   ├── biospecimen.csv
│   ├── rna_query_results.csv
│   ├── rna_access_summary.csv
│   ├── rna_sample_summary.csv
│   ├── rna_modalities.csv
│   └── clinical_missingness.csv
│
├── graficos/
│   ├── amostras_por_tipo.png
│   └── acesso_arquivos.png
│
├── objetos/
│   └── TCGA-XXX_exploracao.rds
│
└── TCGA-XXX_exploracao.xlsx
```

Esse conjunto de arquivos permite que outro pesquisador:

1. revise as tabelas;
2. abra os dados no Excel/LibreOffice;
3. reproduza as consultas;
4. inspecione os objetos R;
5. identifique as variáveis clínicas disponíveis;
6. avalie a quantidade de dados antes do download;
7. documente a seleção da coorte;
8. reaplique o procedimento a outro projeto.

---

# 50. Resumo operacional

O protocolo completo pode ser condensado em:

```text
IDENTIFICAR
→ verificar projeto e documentação

INVENTARIAR
→ cases
→ samples
→ aliquots
→ files
→ categorias
→ data types
→ workflows
→ plataformas

CLASSIFICAR
→ tumor / normal / metastático / outros
→ open / controlled

CARACTERIZAR
→ clinical
→ biospecimen
→ tratamento
→ estágio
→ demografia
→ follow-up
→ vital status

AUDITAR
→ missingness
→ equilíbrio entre grupos
→ disponibilidade por modalidade
→ volume de arquivos

DOCUMENTAR
→ tabelas CSV/XLSX
→ gráficos
→ sessionInfo
→ parâmetros
→ limitações

SOMENTE ENTÃO
→ desenhar a query final
→ baixar os dados
→ iniciar a análise molecular
```

O princípio central é simples: **primeiro conhecer o dataset; depois definir a coorte; somente então baixar e analisar os dados.**

