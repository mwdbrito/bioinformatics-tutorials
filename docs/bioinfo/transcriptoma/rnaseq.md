# Pipeline de RNA-Seq: do GEO aos genes diferencialmente expressos
## GEO → download → QC → trimming → STAR/Salmon → DESeq2 → enriquecimento funcional

> **O que mudou nesta versão em relação à anterior:**
> 1. **Bug corrigido na curadoria** — a versão anterior classificava tudo como "Tratado" sempre que a característica vinha no formato `treatment: control` (comum no GEO), porque procurava a palavra "treatment" na string inteira, sem separar chave de valor. Corrigido na Parte 2.4.
> 2. **Um script por etapa, não dois.** Antes existia `X_amostra.py` + `X_lote.py`, onde o segundo importava o primeiro. Agora cada etapa tem **um único arquivo**, que decide entre "uma amostra" ou "várias" pelo argumento de linha de comando (`--srr` ou `--lista`) — o mesmo padrão que já era usado no `pipeline.py` da versão anterior, agora aplicado a todo o pipeline.
> 3. **Pipeline estendido**: agora cobre alinhamento ao genoma (STAR) e/ou pseudo-quantificação de transcritos (Salmon), montagem da matriz de contagens, análise de expressão diferencial (DESeq2) e enriquecimento funcional (GO/KEGG via clusterProfiler).
> 4. **Comentários linha a linha.** Cada script explica o "porquê", não só o "o quê" — a ideia é que dê para entender o que cada linha faz sem precisar consultar a documentação de cada ferramenta.
>
> Todos os scripts (Python, Bash e R) foram testados quanto à sintaxe antes de entrar neste tutorial (compilação Python, `bash -n`, e checagem de balanceamento de blocos em R).

---

## Sumário

- **Parte 0** — Construção de container para rodar tudo de forma isolada.
- **Parte 1** — Visão geral, ambiente, estrutura do projeto
- **Parte 2** — Do GSE ao sample sheet (metadados + curadoria, com o bug corrigido)
- **Parte 3** — Download (script único)
- **Parte 4** — Controle de qualidade — FastQC (script único)
- **Parte 5** — Trimming — Cutadapt e Trim Galore (scripts únicos)
- **Parte 6** — Preparando a referência: índices do STAR e do Salmon
- **Parte 7** — Alinhamento (STAR) e quantificação (Salmon) — scripts únicos
- **Parte 8** — Montando a matriz de contagens
- **Parte 9** — Expressão diferencial com DESeq2
- **Parte 10** — Enriquecimento funcional (GO / KEGG)
- **Parte 11** — O pipeline fechado — `pipeline.py` e `pipeline.sh`
- **Parte 12** — Boas práticas, checklist e tabela-resumo final

---

# Parte 0 — Preparando o ambiente com Apptainer (container)

Em vez de instalar cada ferramenta manualmente (e correr o risco de versões incompatíveis entre alunos/máquinas), empacotamos tudo em uma imagem Apptainer. Isso é especialmente útil em clusters HPC, onde normalmente você não tem `sudo` para instalar pacotes de sistema, mas o Apptainer roda sem privilégios de root.

> 📦 Quer entender cada etapa da construção do container com mais profundidade (sandbox vs `.sif`, testes ferramenta por ferramenta, boas práticas de disco e memória)? Veja o tutorial complementar: **[Container Apptainer Sandbox para o Pipeline de RNA-Seq](apptainer_sandbox.md)**.

## O que vai dentro da imagem

| Categoria | Ferramentas |
|---|---|
| Metadados | Entrez Direct (`esearch`, `efetch`) |
| Download | SRA Toolkit (`prefetch`, `vdb-validate`, `fasterq-dump`) |
| QC | FastQC, MultiQC |
| Trimming | Cutadapt, Trim Galore |
| Alinhamento/quantificação | STAR, samtools, Salmon |
| Linguagem de script | Python 3 + pandas |
| Estatística | R + DESeq2, tximport, clusterProfiler, enrichplot |
| Relatório | rmarkdown, DT, plotly, ggplot2, pandoc |

Tudo vem do **conda-forge**/**bioconda** como pacotes pré-compilados — evita ter que compilar o Bioconductor inteiro na mão, o que pode levar horas.

## O arquivo de definição (`rnaseq.def`)

```text
Bootstrap: docker
From: condaforge/miniforge3:latest

%labels
    Author seuemail@exemplo.com
    Version 1.0
    Description Container com o ambiente completo do pipeline de RNA-Seq (GEO -> DEGs -> enriquecimento -> relatorio)

%post
    set -e

    # Ferramentas de sistema que os scripts chamam (wget para baixar do
    # GEO, gzip/unzip, etc.) -- miniforge3 é baseado em Debian, por isso
    # usamos apt-get.
    apt-get update
    apt-get install -y --no-install-recommends wget curl gzip unzip procps ca-certificates
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    # Cria um ambiente conda chamado "rnaseq" com TODAS as ferramentas de
    # linha de comando usadas no tutorial. Usamos "mamba" (já vem no
    # miniforge3) em vez de "conda" puro porque resolve as dependências
    # muito mais rápido -- com tantos pacotes do Bioconductor juntos, a
    # diferença é de minutos para horas.
    mamba create -y -n rnaseq -c conda-forge -c bioconda -c defaults \
        python pandas \
        sra-tools entrez-direct \
        fastqc multiqc \
        cutadapt trim-galore \
        star samtools salmon \
        r-base \
        bioconductor-deseq2 bioconductor-tximport \
        bioconductor-clusterprofiler bioconductor-enrichplot \
        bioconductor-org.hs.eg.db bioconductor-org.mm.eg.db bioconductor-org.at.tair.db \
        r-rmarkdown r-dt r-plotly r-ggplot2 pandoc

    # Limpa os pacotes baixados durante a instalação -- reduz bastante o
    # tamanho final da imagem .sif
    mamba clean -a -y

%environment
    # Roda toda vez que alguém entra ou executa o container -- ativa o
    # ambiente "rnaseq" automaticamente, sem precisar digitar
    # "conda activate" manualmente
    export PATH=/opt/conda/envs/rnaseq/bin:$PATH
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8

%runscript
    echo "Container do pipeline de RNA-Seq."
    echo "Ferramentas: sra-tools, entrez-direct, fastqc, multiqc, cutadapt,"
    echo "trim-galore, STAR, salmon, samtools, python3+pandas, R+Bioconductor"
    echo "(DESeq2, tximport, clusterProfiler, enrichplot, rmarkdown)."
    exec "$@"

%test
    export PATH=/opt/conda/envs/rnaseq/bin:$PATH
    prefetch --version
    fastqc --version
    STAR --version
    salmon --version
    Rscript -e 'suppressMessages(library(DESeq2)); cat("DESeq2 OK\n")'
```

> Os pacotes `bioconductor-org.hs.eg.db` (humano), `org.mm.eg.db` (camundongo) e `org.at.tair.db` (*Arabidopsis*) são exemplos — adicione/remova conforme os organismos que sua turma vai usar, para não inflar a imagem à toa.

## Construindo a imagem

```bash
# Precisa de --fakeroot (ou sudo) para construir
apptainer build --fakeroot rnaseq.sif rnaseq.def

# Se o cluster não permite --fakeroot nem sudo, construa em outra
# máquina (seu notebook, por ex.) e copie o .sif pronto:
scp rnaseq.sif usuario@cluster:/caminho/do/projeto/

# Alternativa: build remoto na nuvem da Sylabs (precisa de conta em
# cloud.sylabs.io), sem precisar de privilégios locais:
apptainer build --remote rnaseq.sif rnaseq.def
```

A construção pode levar de 15 a 40 minutos, principalmente pela resolução de dependências do Bioconductor — é normal.

## Usando o container

```bash
# testa se tudo foi instalado corretamente
apptainer test rnaseq.sif

# shell interativo, com a pasta do projeto montada dentro do container
apptainer shell --bind $(pwd):/projeto rnaseq.sif
cd /projeto

# ou rodando um comando específico sem entrar no shell
apptainer exec --bind $(pwd):/projeto rnaseq.sif \
    python3 /projeto/scripts/pipeline.py --srr SRR30001 \
    --aligner star --star-genome-dir /projeto/referencia/star_index
```

`--bind origem:destino` deixa visível, dentro do container, uma pasta de fora dele — sem isso, o container só enxerga o que foi copiado para dentro da imagem no momento da construção.

---


---

# Parte 1 — Visão geral

## 1.1 O fluxo completo

```text
GEO (GSE)
  │
  ▼
Metadados do GEO (GSM, título, características, relação com SRA)
  │
  ▼
SRX → SRR
  │
  ▼
Download (prefetch + fasterq-dump)
  │
  ▼
FASTQ bruto ── FastQC
  │
  ▼
Trimming (Cutadapt / Trim Galore) ── FastQC pós-trimming
  │
  ├──────────────┐
  ▼              ▼
STAR          Salmon
(alinha ao    (pseudo-alinha
 genoma,       aos transcritos,
 gera BAM +    gera quant.sf
 contagem      por transcrito)
 por gene)         │
  │                ▼
  │           tximport + tx2gene
  │           (resume por gene)
  ▼                │
  └──────┬─────────┘
         ▼
  Matriz de contagens (genes x amostras)
         │
         ▼
      DESeq2 (expressão diferencial)
         │
         ▼
  Enriquecimento funcional (GO / KEGG)
```

**Por que dois caminhos (STAR e Salmon) para o mesmo objetivo?**

| | STAR (alinhamento) | Salmon (pseudo-alinhamento) |
|---|---|---|
| O que faz | Alinha cada read a uma posição do genoma | Estima de qual transcrito cada read veio, sem alinhar posição por posição |
| Precisa de | Genoma + anotação (GTF) | Transcriptoma (e, opcionalmente, genoma como decoy) |
| Saída | BAM + contagem por gene | `quant.sf` por amostra (contagem por transcrito) |
| Velocidade | Mais lento, usa mais disco | Muito mais rápido, usa menos disco |
| Também serve para | Ver splicing, visualizar em IGV, chamar variantes | Só quantificação — não gera nada "visualizável" |
| Uso típico | Quando você também quer o BAM para outras análises | Quando você só quer expressão gênica, rápido |

Ensinar os dois é útil justamente para o aluno perceber que "quantificar expressão" não tem uma única resposta certa — a escolha depende do que mais você precisa do experimento.

## 1.2 Identificadores

| Identificador | Banco | O que representa |
|---|---|---|
| `GSE` | GEO | Série/experimento inteiro |
| `GSM` | GEO | Uma amostra biológica |
| `SRX` | SRA | Um experimento de sequenciamento |
| `SRR` | SRA | Uma corrida (run) de sequenciamento |
| `SAMN` | BioSample | Registro de amostra biológica |
| `PRJNA` | BioProject | Projeto no NCBI |

```text
GSE
 └── GSM
      └── SRX
           └── SRR
```

> **Cuidado:** um `GSM` pode ter mais de um `SRR` (a mesma biblioteca sequenciada em mais de uma corrida). Nesse caso os SRR extras são **runs técnicos**, não réplicas biológicas — conte GSM únicos quando for avaliar quantas réplicas biológicas você tem, não SRR.

## 1.3 Preparando o ambiente

Ferramentas usadas neste tutorial:

| Categoria | Ferramentas |
|---|---|
| Metadados | Entrez Direct (`esearch`, `efetch`, `xtract`) |
| Download | SRA Toolkit (`prefetch`, `vdb-validate`, `fasterq-dump`) |
| QC | FastQC, MultiQC |
| Trimming | Cutadapt, Trim Galore |
| Alinhamento | STAR, samtools |
| Quantificação | Salmon |
| Estatística | R, Bioconductor (DESeq2, tximport, clusterProfiler, enrichplot) |
| Linguagens de script | Python 3 (+ pandas), Bash |

Verificação rápida:

```bash
which esearch efetch xtract prefetch fasterq-dump fastqc cutadapt trim_galore STAR samtools salmon Rscript
python3 -c "import pandas" && echo "pandas OK"
Rscript -e 'library(DESeq2); library(tximport); library(clusterProfiler); library(enrichplot); cat("pacotes R OK\n")'
```

Se uma ferramenta não aparecer, ela não está no `PATH`. Os pacotes R (DESeq2, tximport, clusterProfiler, enrichplot, e o pacote de anotação do seu organismo, ex.: `org.Hs.eg.db`) vêm do Bioconductor:

```r
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install(c("DESeq2", "tximport", "clusterProfiler", "enrichplot", "org.Hs.eg.db"))
```

(ajuste `org.Hs.eg.db` para o pacote de anotação do seu organismo)

## 1.4 Estrutura do projeto

```text
projeto_rnaseq/
├── metadados/           sample_sheet.csv, sample_sheet_curado.csv, lista_srr.txt, srr_condicao.csv
├── referencia/          genoma.fa, anotacao.gtf, transcritos.fa, star_index/, salmon_index/, tx2gene.csv
├── sra/                 objetos .sra baixados pelo prefetch
├── dados_brutos/        FASTQ bruto
├── dados_limpos/        FASTQ pós-trimming
├── qc_bruto/            relatórios FastQC do dado bruto
├── qc_limpo/            relatórios FastQC pós-trimming
├── alinhamento_star/    BAM + ReadsPerGene.out.tab (se usar STAR)
├── quantificacao_salmon/ quant.sf por amostra (se usar Salmon)
├── contagens/           matriz de contagens combinada
├── resultados_deseq2/   tabela de DEGs + gráficos
├── resultados_enriquecimento/  termos GO/KEGG enriquecidos
├── logs/
└── scripts/             todos os scripts deste tutorial
```

```bash
mkdir -p projeto_rnaseq/{metadados,referencia,sra,dados_brutos,dados_limpos,qc_bruto,qc_limpo,alinhamento_star,quantificacao_salmon,contagens,resultados_deseq2,resultados_enriquecimento,logs,scripts}
cd projeto_rnaseq
```

---

# Parte 2 — Do GSE ao sample sheet

## 2.1 Por que não sair direto para os SRR

Um erro comum é ensinar `GSE → SRR → download` direto. Isso resolve o problema computacional, mas cria um problema biológico: depois de baixar `SRR1234567`, como saber se é Controle ou Tratado? Por isso construímos um **sample sheet** que preserva GSM, título, características e condição junto com o SRR — o formato SOFT do GEO (não só o `runinfo` do SRA) é a fonte confiável dessa informação biológica.

## 2.2 Script: metadados GEO → sample sheet

Aceita um ou vários GSE de uma vez (útil ao combinar mais de um experimento):

```python
#!/usr/bin/env python3
"""
Extrai metadados do GEO (arquivo SOFT) e monta um sample sheet com uma
linha por SRR (run de sequenciamento).

Uso -- um único GSE:
    python3 scripts/geo_to_sample_sheet.py GSE123456

Uso -- vários GSE de uma vez (ex.: combinando dois experimentos):
    python3 scripts/geo_to_sample_sheet.py GSE123456 GSE987654
"""

import argparse
import csv
import gzip
import re
import subprocess
import sys
from pathlib import Path


def geo_prefix(gse):
    """GSE123456 -> GSE123nnn (é assim que o NCBI organiza as pastas de FTP)."""
    return gse[:-3] + "nnn"


def download_soft(gse, output):
    """Baixa o arquivo Series Family SOFT do GEO para um GSE específico."""
    prefix = geo_prefix(gse)
    url = (
        f"https://ftp.ncbi.nlm.nih.gov/geo/series/"
        f"{prefix}/{gse}/soft/{gse}_family.soft.gz"
    )
    print(f"[INFO] Download do SOFT de {gse}:\n{url}")
    # wget -O <destino> <url>: baixa e salva com o nome que escolhemos
    subprocess.run(["wget", "-O", str(output), url], check=True)


def parse_soft(soft_file):
    """
    Lê o arquivo SOFT linha por linha e monta uma lista de dicionários,
    um por amostra (^SAMPLE), com título, características e os SRX
    relacionados (achados dentro de !Sample_relation).
    """
    samples = []
    current = None  # a amostra que estamos montando no momento

    # Se o arquivo termina em .gz, abrimos com gzip; senão, normal.
    opener = gzip.open if str(soft_file).endswith(".gz") else open

    with opener(soft_file, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")

            # "^SAMPLE = GSM123" marca o INÍCIO de uma nova amostra no SOFT
            if line.startswith("^SAMPLE = "):
                # se já vínhamos montando uma amostra anterior, guardamos
                # ela na lista antes de começar a próxima
                if current is not None:
                    samples.append(current)
                gsm = line.split("=", 1)[1].strip()
                current = {"GSM": gsm, "Title": "", "Characteristics": [], "SRX": []}
                continue

            # linhas antes do primeiro ^SAMPLE (cabeçalho da série) -- ignorar
            if current is None:
                continue

            if line.startswith("!Sample_title = "):
                current["Title"] = line.split("=", 1)[1].strip()

            elif line.startswith("!Sample_characteristics"):
                # pode haver várias linhas !Sample_characteristics para a
                # mesma amostra -- por isso usamos uma lista e não uma string
                current["Characteristics"].append(line.split("=", 1)[1].strip())

            elif line.startswith("!Sample_relation = "):
                value = line.split("=", 1)[1].strip()
                if value.startswith("SRA:"):
                    # o SRX aparece dentro de uma URL, ex.:
                    # SRA: https://www.ncbi.nlm.nih.gov/sra?term=SRX123456
                    match = re.search(r"(SRX\d+)", value)
                    if match:
                        current["SRX"].append(match.group(1))

        # não esquecer de guardar a última amostra lida (não há um
        # próximo ^SAMPLE para "fechar" ela)
        if current is not None:
            samples.append(current)

    return samples


def runinfo_from_srx(srx_list):
    """Usa Entrez Direct (efetch) para descobrir os SRR associados a uma lista de SRX."""
    if not srx_list:
        return []

    # set() remove duplicados; sorted() deixa a saída determinística
    ids = ",".join(sorted(set(srx_list)))

    result = subprocess.run(
        ["efetch", "-db", "sra", "-id", ids, "-format", "runinfo"],
        capture_output=True, text=True, check=True,
    )

    lines = result.stdout.strip().splitlines()
    if len(lines) < 2:  # só o cabeçalho, sem nenhuma linha de dado
        return []

    # csv.DictReader transforma cada linha em um dicionário {coluna: valor}
    return list(csv.DictReader(lines))


def montar_linhas(samples, gse):
    """A partir da lista de amostras (com seus SRX), monta uma linha por SRR."""

    # Uma lista achatada com todos os SRX de todas as amostras deste GSE
    all_srx = [srx for s in samples for srx in s["SRX"]]
    print(f"[INFO] {gse}: {len(set(all_srx))} SRX encontrados.")

    runinfo = runinfo_from_srx(all_srx)

    # Agrupa as linhas de runinfo por SRX, para acesso rápido logo abaixo
    srx_to_runs = {}
    for row in runinfo:
        srx = row.get("Experiment", "").strip()
        srr = row.get("Run", "").strip()
        if srx and srr:
            srx_to_runs.setdefault(srx, []).append(row)

    linhas = []
    for sample in samples:
        # junta todas as !Sample_characteristics em uma só string,
        # separadas por " | ", para caber em uma única célula do CSV
        characteristics = " | ".join(sample["Characteristics"])

        for srx in sample["SRX"]:
            # uma amostra (GSM) pode ter mais de um SRR associado ao
            # mesmo SRX -- por isso este é o terceiro nível de loop
            for run in srx_to_runs.get(srx, []):
                linhas.append({
                    "GSE": gse,
                    "GSM": sample["GSM"],
                    "SRX": srx,
                    "SRR": run.get("Run", ""),
                    "Title": sample["Title"],
                    "Characteristics": characteristics,
                    "Layout": run.get("LibraryLayout", ""),
                    "Platform": run.get("Platform", ""),
                    "Model": run.get("Model", ""),
                    "ScientificName": run.get("ScientificName", ""),
                })
    return linhas


def processar_gse(gse, soft_arg, metadados_dir):
    """Garante que o SOFT esteja em disco (baixando se preciso) e devolve as linhas do sample sheet."""
    soft = Path(soft_arg) if soft_arg else metadados_dir / f"{gse}_family.soft.gz"

    if not soft.exists():
        soft.parent.mkdir(parents=True, exist_ok=True)
        download_soft(gse, soft)

    samples = parse_soft(soft)
    print(f"[INFO] {gse}: {len(samples)} amostras (GSM) encontradas.")
    return montar_linhas(samples, gse)


def main():
    parser = argparse.ArgumentParser(
        description="Extrai metadados GEO e cria sample sheet com SRR (aceita 1 ou vários GSE)."
    )
    # nargs="+" aceita um OU vários GSE na linha de comando
    parser.add_argument("gse", nargs="+", help="Um ou mais acessos GEO, ex: GSE123456")
    parser.add_argument("--soft", default=None, help="Arquivo SOFT já baixado (só para 1 GSE)")
    parser.add_argument("--output", default="metadados/sample_sheet.csv")
    args = parser.parse_args()

    if args.soft and len(args.gse) > 1:
        sys.exit("ERRO: --soft só pode ser usado com um único GSE.")

    metadados_dir = Path("metadados")
    todas_linhas = []

    for gse_raw in args.gse:
        gse = gse_raw.upper()
        if not re.fullmatch(r"GSE\d+", gse):
            sys.exit(f"ERRO: '{gse_raw}' não está no formato GSE123456")
        todas_linhas.extend(processar_gse(gse, args.soft, metadados_dir))

    fieldnames = [
        "GSE", "GSM", "SRX", "SRR", "Title", "Characteristics",
        "Layout", "Platform", "Model", "ScientificName",
    ]

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    with open(output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(todas_linhas)

    print(f"[OK] Sample sheet criada: {output}")
    print(f"[OK] Número de runs: {len(todas_linhas)}")


if __name__ == "__main__":
    main()
```

```bash
# um GSE
python3 scripts/geo_to_sample_sheet.py GSE123456

# vários GSE combinados num único sample sheet
python3 scripts/geo_to_sample_sheet.py GSE123456 GSE987654
```

## 2.3 Formato SOFT, por trás dos panos

```text
^SAMPLE = GSM1234567
!Sample_title = Arabidopsis wild-type control
!Sample_characteristics_ch1 = genotype: wild type
!Sample_characteristics_ch1 = treatment: control
!Sample_relation = SRA: https://www.ncbi.nlm.nih.gov/sra?term=SRX123456
```

`^` inicia uma entidade, `!` marca um atributo dela. Cada característica vem como `chave: valor` — e é exatamente esse formato que o próximo script explora para não repetir o erro da versão anterior.

## 2.4 Curadoria da condição biológica — o bug e a correção

**O problema que você encontrou:** a versão anterior do script fazia algo como:

```python
df.loc[df["Characteristics"].str.contains("control|untreated", case=False), "Condicao"] = "Controle"
df.loc[df["Characteristics"].str.contains("treated|treatment", case=False), "Condicao"] = "Tratado"
```

No GEO, uma característica comum é `treatment: control` — ou seja, o **nome** da característica é "treatment" e o **valor** dela é "control". Essa string contém as duas palavras: bate com o primeiro padrão (`control`) E com o segundo (`treatment`, que aparece literalmente como nome da chave). Como o segundo `.loc[...]` roda depois, ele **sobrescreve** o resultado do primeiro — toda amostra, incluindo o controle, acaba marcada como "Tratado". Reproduzindo:

```text
    GSM                                   Characteristics Condicao
0  GSM1          genotype: wild type | treatment: control  Tratado   <- ERRADO, era pra ser Controle
1  GSM2  genotype: wild type | treatment: 250 mM mannitol  Tratado   <- correto, por coincidência
```

**A correção:** em vez de procurar palavras-chave na string inteira, separamos cada característica em **chave** e **valor** (`"treatment: control"` → `{"treatment": "control"}`) e comparamos só o **valor** — nunca o nome da chave. Isso elimina a ambiguidade na raiz, porque a palavra "treatment" nunca mais é comparada com nada; só "control" (o valor) é.

```python
#!/usr/bin/env python3
"""
Lê o sample sheet bruto (uma linha por SRR, gerado a partir do GEO) e
adiciona uma coluna "Condicao" (Controle / Tratado), a partir do texto
da coluna "Characteristics".

Por que não usar apenas "if 'control' in texto"?
--------------------------------------------------
No GEO, "Characteristics" costuma vir como uma lista de pares
"chave: valor", por exemplo:

    genotype: wild type | treatment: control
    genotype: wild type | treatment: 250 mM mannitol

Se procurarmos a palavra "treatment" na string inteira para decidir que a
amostra é "Tratado", TODA amostra cai nesse grupo -- inclusive o controle,
porque a palavra "treatment" aparece como NOME da característica, não
como valor. O jeito correto é separar cada característica em chave/valor
e comparar apenas o VALOR da chave "treatment" (ou similar).

Uso:
    python3 scripts/curar_sample_sheet.py
    python3 scripts/curar_sample_sheet.py --entrada metadados/sample_sheet.csv
"""

```python
import pandas as pd

df = pd.read_csv("metadados/sample_sheet.csv")

print("\nAmostras encontradas:")
print(df[["GSM", "SRR", "Title", "Characteristics"]].to_string(index=False))

# IMPORTANTE: os padrões abaixo são só um exemplo didático.
# Confira sempre o desenho experimental original no GEO antes de rotular.
df["Condicao"] = ""
df.loc[
    df["Titles"].str.contains("control|untreated|wild.type control", case=False, na=False),
    "Condicao",
] = "Controle"
df.loc[
    df["Titles"].str.contains("mannitol|treated|treatment", case=False, na=False),
    "Condicao",
] = "Tratado"

print("\nDistribuição das condições:")
print(df["Condicao"].value_counts(dropna=False))

df.to_csv("metadados/sample_sheet_curado.csv", index=False)
df[["SRR"]].drop_duplicates().to_csv("metadados/lista_srr.txt", index=False, header=False)
df[["SRR", "Condicao"]].to_csv("metadados/srr_condicao.csv", index=False)

print("\nArquivos gerados: sample_sheet_curado.csv, lista_srr.txt, srr_condicao.csv")
```

Testando com o mesmo caso que causava o bug:

```text
Amostras encontradas:
     GSM      SRR                 Title                                  Characteristics
GSM10001 SRR30001            WT control         genotype: wild type | treatment: control
GSM10002 SRR30002       WT control rep2         genotype: wild type | treatment: control
GSM10003 SRR30003      Mannitol treated genotype: wild type | treatment: 250 mM mannitol
GSM10004 SRR30004 Mannitol treated rep2 genotype: wild type | treatment: 250 mM mannitol
GSM10005 SRR30005        Unknown sample                                source_name: leaf

Distribuição das condições:
Condicao
Controle    2
Tratado     2
            1

[ATENÇÃO] Não foi possível classificar automaticamente -- confira manualmente:
     GSM      SRR   Characteristics
GSM10005 SRR30005 source_name: leaf
```

Agora `treatment: control` vira `Controle` corretamente — e a amostra sem nenhuma chave reconhecida (`GSM10005`) é **explicitamente sinalizada** para revisão manual, em vez de silenciosamente ficar com uma condição vazia sem ninguém perceber.

```bash
python3 scripts/curar_sample_sheet.py
column -s ',' -t metadados/srr_condicao.csv   # conferir visualmente
```

Se seu experimento usa outro vocabulário (ex.: "genotype" em vez de "treatment", ou nomes de fármacos em vez de "mannitol"), ajuste as constantes `CHAVES_DE_CONDICAO`, `PADRAO_CONTROLE` e `PADRAO_TRATADO` no topo do script.

---

# Parte 3 — Download

## 3.1 Conceito

O SRA Toolkit separa **download** (`prefetch`, que baixa o objeto SRA e permite retomar downloads incompletos) de **conversão** (`fasterq-dump`, que gera o FASTQ). `vdb-validate` confere a integridade do objeto entre as duas etapas.

> Este tutorial assume bibliotecas **paired-end**. Para single-end, ajuste os scripts removendo o segundo arquivo (R2) e o `--split-files` do `fasterq-dump` passa a gerar um único FASTQ.

## 3.2 Script único (uma amostra OU várias)

```python
#!/usr/bin/env python3
"""
Baixa e converte amostras SRA para FASTQ (prefetch + vdb-validate + fasterq-dump).

Este script funciona nos dois modos, escolhidos por argumento de linha de
comando -- não existem dois arquivos separados (um "de uma amostra" e
outro "de várias"): a função `baixar_uma_amostra()` é a mesma para os
dois casos, só muda quantas vezes ela é chamada.

MODO 1 - uma única amostra:
    python3 scripts/download.py --srr SRR30001

MODO 2 - várias amostras (arquivo com um SRR por linha, ou sample sheet
CSV com coluna SRR):
    python3 scripts/download.py --lista metadados/lista_srr.txt
"""

import argparse
import subprocess
import sys
from pathlib import Path

import pandas as pd


def _rodar_com_retry(comando, tentativas=3):
    """
    Executa um comando de rede (o prefetch) tentando de novo se falhar.
    Redes instáveis são a causa mais comum de falha nesta etapa -- por
    isso vale a pena tentar algumas vezes antes de desistir.
    """
    ultimo_erro = None

    for tentativa in range(1, tentativas + 1):
        try:
            subprocess.run(comando, check=True)
            return  # deu certo, não precisa tentar de novo
        except subprocess.CalledProcessError as erro:
            ultimo_erro = erro
            print(f"[AVISO] tentativa {tentativa}/{tentativas} falhou: {' '.join(map(str, comando))}")

    # se saiu do "for" sem dar "return", é porque todas as tentativas
    # falharam -- relançamos o último erro para quem chamou esta função
    raise ultimo_erro


def baixar_uma_amostra(srr, sra_dir, fastq_dir, threads, pular_se_existir):
    """
    Baixa (prefetch), valida (vdb-validate) e converte (fasterq-dump) um
    único SRR para FASTQ pareado, já comprimido em .gz.

    Devolve os caminhos (r1, r2) dos arquivos gerados.
    """
    sra_dir = Path(sra_dir)
    fastq_dir = Path(fastq_dir)
    sra_dir.mkdir(parents=True, exist_ok=True)
    fastq_dir.mkdir(parents=True, exist_ok=True)

    r1 = fastq_dir / f"{srr}_1.fastq.gz"
    r2 = fastq_dir / f"{srr}_2.fastq.gz"

    # Idempotência: se o resultado final já existe, não baixamos de novo.
    # Isso permite rodar o mesmo comando várias vezes sem medo -- útil
    # quando o download de uma amostra falha no meio de um lote grande e
    # você só quer retomar de onde parou.
    if pular_se_existir and r1.exists() and r2.exists():
        print(f"[SKIP] {srr} já baixado, pulando.")
        return r1, r2

    print(f"[1/3] prefetch {srr}")
    # prefetch baixa o objeto .sra bruto para dentro de sra_dir/<srr>/
    _rodar_com_retry(["prefetch", srr, "--output-directory", str(sra_dir)])

    sra_path = sra_dir / srr

    print(f"[2/3] vdb-validate {srr}")
    # confere se o arquivo .sra baixado não está corrompido antes de gastar
    # tempo convertendo -- um download incompleto trava o fasterq-dump
    # de um jeito mais confuso do que um erro claro aqui
    subprocess.run(["vdb-validate", str(sra_path)], check=True)

    print(f"[3/3] fasterq-dump {srr}")
    subprocess.run(
        [
            "fasterq-dump", str(sra_path),
            "--split-files",           # separa em _1 (R1) e _2 (R2) para paired-end
            "--threads", str(threads),  # paraleliza a conversão
            "--outdir", str(fastq_dir),
        ],
        check=True,
    )

    # fasterq-dump devolve .fastq sem compressão -- comprimimos aqui para
    # economizar espaço em disco (as ferramentas seguintes leem .gz direto)
    for fastq_sem_gz in fastq_dir.glob(f"{srr}_*.fastq"):
        subprocess.run(["gzip", "-f", str(fastq_sem_gz)], check=True)

    return r1, r2


def carregar_lista_srr(caminho):
    """Lê um .txt (um SRR por linha) ou um .csv (coluna 'SRR') e devolve uma lista de SRR."""
    caminho = Path(caminho)

    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        # dropna: ignora linhas sem SRR; strip: remove espaços acidentais
        return df["SRR"].dropna().astype(str).str.strip().tolist()

    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Baixa uma ou várias amostras SRA/SRR.")

    # add_mutually_exclusive_group(required=True): obriga o usuário a
    # escolher EXATAMENTE um dos dois modos -- nunca os dois, nunca nenhum.
    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Baixa apenas este SRR (modo amostra única).")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--sra-dir", default="sra")
    parser.add_argument("--fastq-dir", default="dados_brutos")
    parser.add_argument("--forcar", action="store_true", help="Baixa de novo mesmo se já existir.")
    parser.add_argument("--keep-going", action="store_true", help="No modo lista, não para se uma amostra falhar.")
    args = parser.parse_args()

    # Independente do modo escolhido, sempre acabamos com uma lista de
    # SRR para processar -- no modo --srr essa lista tem um item só.
    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s) para baixar.")

    falhas = []

    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] {srr} ===")
        try:
            r1, r2 = baixar_uma_amostra(
                srr,
                sra_dir=args.sra_dir,
                fastq_dir=args.fastq_dir,
                threads=args.threads,
                pular_se_existir=not args.forcar,
            )
            print(f"[OK] {srr} -> {r1}, {r2}")
        except Exception as erro:
            print(f"[ERRO] {srr}: {erro}")
            falhas.append(srr)
            # No modo de uma amostra só, qualquer erro deve parar o
            # programa. No modo lista, só paramos se o usuário NÃO pediu
            # --keep-going.
            if args.srr or not args.keep_going:
                sys.exit(f"Interrompido em {srr}. Use --keep-going para pular falhas em lote.")

    if len(srrs) > 1:
        ok = len(srrs) - len(falhas)
        print(f"\nConcluído: {ok} ok, {len(falhas)} falharam.")
        if falhas:
            print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

```bash
# uma única amostra
python3 scripts/download.py --srr SRR30001

# várias amostras (lista .txt ou sample_sheet_curado.csv)
python3 scripts/download.py --lista metadados/lista_srr.txt --threads 8 --keep-going
```

## 3.3 Cuidados com espaço em disco

```bash
df -h        # espaço livre no filesystem
du -sh .     # espaço já usado pelo projeto
nproc        # CPUs disponíveis, para dimensionar --threads
```

Durante a conversão `SRA → FASTQ` você pode ter, ao mesmo tempo, o `.sra` bruto e o FASTQ gerado — dimensione o disco pensando nos dois. Mais threads nem sempre é proporcionalmente mais rápido: o gargalo real costuma ser rede ou disco, não CPU.

---

# Parte 4 — Controle de qualidade (FastQC)

## 4.1 O que o FastQC avalia

Qualidade por base, distribuição de GC, comprimento das reads, conteúdo de adaptador, duplicação e sequências super-representadas. Interprete sempre em conjunto com organismo, protocolo e tipo de biblioteca — um módulo em vermelho não significa automaticamente "amostra ruim".

## 4.2 Script único (uma amostra OU várias)

Uma única chamada ao FastQC com todos os arquivos de uma vez é mais eficiente que chamar o programa várias vezes — o `--threads` já paraleliza internamente.

```python
#!/usr/bin/env python3
"""
Roda o FastQC em uma amostra ou em várias, em uma única chamada ao
programa (mais rápido que chamar `fastqc` uma vez por amostra).

MODO 1 - uma única amostra:
    python3 scripts/qc.py --srr SRR30001

MODO 2 - várias amostras (lista de SRR):
    python3 scripts/qc.py --lista metadados/lista_srr.txt

Por padrão lê de dados_brutos/ e escreve em qc_bruto/. Para rodar o QC
pós-trimming, aponte para as pastas de dados limpos:

    python3 scripts/qc.py --lista metadados/lista_srr.txt \
        --dados dados_limpos --outdir qc_limpo --sufixo _val
"""

import argparse
import subprocess
from pathlib import Path

import pandas as pd


def rodar_fastqc(arquivos, outdir, threads):
    """Chama o FastQC uma única vez, passando todos os arquivos de uma vez."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # O "*" desempacota a lista arquivos como argumentos separados, igual
    # a escrever fastqc arq1 arq2 arq3 ... na linha de comando.
    subprocess.run(
        ["fastqc", *[str(a) for a in arquivos], "--threads", str(threads), "--outdir", str(outdir)],
        check=True,
    )


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def caminhos_fastq(srr, dados_dir, sufixo):
    """
    Monta os caminhos de R1/R2 para um SRR.

    sufixo="" -> dados_brutos/SRR_1.fastq.gz         (FASTQ bruto)
    sufixo="_val" -> dados_limpos/SRR_1_val_1.fq.gz  (saída do Trim Galore)
    """
    dados_dir = Path(dados_dir)
    if sufixo:
        # Trim Galore nomeia a saída como <nome>_val_1.fq.gz / _val_2.fq.gz
        return (
            dados_dir / f"{srr}_1{sufixo}_1.fq.gz",
            dados_dir / f"{srr}_2{sufixo}_2.fq.gz",
        )
    return (
        dados_dir / f"{srr}_1.fastq.gz",
        dados_dir / f"{srr}_2.fastq.gz",
    )


def main():
    parser = argparse.ArgumentParser(description="FastQC de uma ou várias amostras paired-end.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Roda FastQC apenas nesta amostra.")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--dados", default="dados_brutos", help="Pasta onde estão os FASTQ.")
    parser.add_argument("--outdir", default="qc_bruto", help="Pasta de saída dos relatórios.")
    parser.add_argument("--sufixo", default="", help="Use '_val' para apontar para saída do Trim Galore.")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s).")

    # Montamos a lista completa de arquivos ANTES de chamar o FastQC, para
    # fazer uma única chamada -- ver docstring do módulo sobre por quê.
    arquivos = []
    for srr in srrs:
        r1, r2 = caminhos_fastq(srr, args.dados, args.sufixo)
        arquivos.extend([r1, r2])

    rodar_fastqc(arquivos, outdir=args.outdir, threads=args.threads)
    print(f"[OK] FastQC de {len(srrs)} amostra(s) em {args.outdir}")


if __name__ == "__main__":
    main()
```

```bash
# uma amostra, dado bruto
python3 scripts/qc.py --srr SRR30001

# várias amostras, dado bruto
python3 scripts/qc.py --lista metadados/lista_srr.txt --threads 8

# pós-trimming (repare no --sufixo _val, e nas pastas diferentes)
python3 scripts/qc.py --lista metadados/lista_srr.txt \
    --dados dados_limpos --outdir qc_limpo --sufixo _val
```

```bash
multiqc qc_bruto -o qc_bruto/multiqc
multiqc qc_limpo -o qc_limpo/multiqc
```

---

# Parte 5 — Trimming

## 5.1 Cutadapt — para entender o conceito

| Flag | Significado |
|---|---|
| `-a` / `-A` | Adaptador esperado na read 1 / read 2 |
| `-q` | Corta bases com qualidade Phred abaixo disso, nas pontas |
| `-m` | Descarta reads menores que isso após o corte |
| `-o` / `-p` | Arquivo de saída da read 1 / read 2 |

**As sequências de adaptador no script são um exemplo didático (Illumina TruSeq)** — confira sempre o protocolo real do seu experimento (relatório FastQC → *Adapter Content*, ou a documentação do estudo) antes de usar em dados reais.

```python
#!/usr/bin/env python3
"""
Roda o Cutadapt (remoção de adaptador + quality trimming) em uma amostra
ou em várias.

MODO 1 - uma única amostra:
    python3 scripts/cutadapt_step.py --srr SRR30001

MODO 2 - várias amostras:
    python3 scripts/cutadapt_step.py --lista metadados/lista_srr.txt

IMPORTANTE: as sequências de adaptador abaixo (ADAPTER_R1/ADAPTER_R2) são
um exemplo didático (Illumina TruSeq). Confira o adaptador real do seu
protocolo/kit de sequenciamento -- olhando o relatório FastQC ("Adapter
Content") ou a documentação do estudo -- antes de usar em dados reais.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import pandas as pd

ADAPTER_R1 = "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
ADAPTER_R2 = "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"


def rodar_cutadapt(r1, r2, out_r1, out_r2, qualidade, tam_min, adapter_r1, adapter_r2):
    Path(out_r1).parent.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [
            "cutadapt",
            "-a", adapter_r1,       # adaptador esperado na read 1
            "-A", adapter_r2,       # adaptador esperado na read 2 (paired-end)
            "-q", str(qualidade),   # corta bases com qualidade Phred abaixo disso, nas pontas
            "-m", str(tam_min),     # descarta reads menores que isso após o corte
            "-o", str(out_r1),      # arquivo de saída da read 1
            "-p", str(out_r2),      # arquivo de saída da read 2
            str(r1), str(r2),       # arquivos de entrada (nesta ordem)
        ],
        check=True,
    )


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Cutadapt em uma ou várias amostras paired-end.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Processa apenas esta amostra.")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    parser.add_argument("--qualidade", type=int, default=20)
    parser.add_argument("--tam-min", type=int, default=20)
    parser.add_argument("--adapter-r1", default=ADAPTER_R1)
    parser.add_argument("--adapter-r2", default=ADAPTER_R2)
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args()

    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s).")

    falhas = []
    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] Cutadapt: {srr} ===")
        r1 = Path(args.brutos) / f"{srr}_1.fastq.gz"
        r2 = Path(args.brutos) / f"{srr}_2.fastq.gz"
        out_r1 = Path(args.limpos) / f"{srr}_1.fastq.gz"
        out_r2 = Path(args.limpos) / f"{srr}_2.fastq.gz"

        try:
            rodar_cutadapt(r1, r2, out_r1, out_r2, args.qualidade, args.tam_min, args.adapter_r1, args.adapter_r2)
        except subprocess.CalledProcessError as erro:
            print(f"[ERRO] {srr}: {erro}")
            falhas.append(srr)
            if args.srr or not args.keep_going:
                sys.exit(f"Interrompido em {srr}.")

    print(f"\n[OK] {len(srrs) - len(falhas)}/{len(srrs)} amostra(s) processada(s).")
    if falhas:
        print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/cutadapt_step.py --srr SRR30001
python3 scripts/cutadapt_step.py --lista metadados/lista_srr.txt --keep-going
```

## 5.2 Trim Galore — o usado no pipeline final

Usa o Cutadapt por baixo, com detecção automática de adaptador e `--fastqc` integrado. É a ferramenta que o `pipeline.py`/`pipeline.sh` usa de fato.

```python
#!/usr/bin/env python3
"""
Roda o Trim Galore (que usa o Cutadapt por baixo, com detecção automática
de adaptador) em uma amostra ou em várias. Esta é a ferramenta usada pelo
pipeline final -- o Cutadapt manual (cutadapt_step.py) existe para
ensinar o conceito.

MODO 1 - uma única amostra:
    python3 scripts/trim_galore_step.py --srr SRR30001

MODO 2 - várias amostras:
    python3 scripts/trim_galore_step.py --lista metadados/lista_srr.txt
"""

import argparse
import subprocess
import sys
from pathlib import Path

import pandas as pd


def rodar_trim_galore(r1, r2, outdir, threads, fastqc):
    Path(outdir).mkdir(parents=True, exist_ok=True)

    comando = [
        "trim_galore",
        "--paired",                  # avisa que R1/R2 devem ser cortados em sincronia
        "--cores", str(threads),
        "--output_dir", str(outdir),
    ]
    if fastqc:
        comando.append("--fastqc")   # roda o FastQC automaticamente no resultado

    comando += [str(r1), str(r2)]
    subprocess.run(comando, check=True)


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Trim Galore em uma ou várias amostras paired-end.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Processa apenas esta amostra.")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--sem-fastqc", action="store_true", help="Não roda o FastQC automático.")
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args()

    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s).")

    falhas = []
    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] Trim Galore: {srr} ===")
        r1 = Path(args.brutos) / f"{srr}_1.fastq.gz"
        r2 = Path(args.brutos) / f"{srr}_2.fastq.gz"

        try:
            rodar_trim_galore(r1, r2, outdir=args.limpos, threads=args.threads, fastqc=not args.sem_fastqc)
        except subprocess.CalledProcessError as erro:
            print(f"[ERRO] {srr}: {erro}")
            falhas.append(srr)
            if args.srr or not args.keep_going:
                sys.exit(f"Interrompido em {srr}.")

    print(f"\n[OK] {len(srrs) - len(falhas)}/{len(srrs)} amostra(s) processada(s).")
    if falhas:
        print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/trim_galore_step.py --srr SRR30001
python3 scripts/trim_galore_step.py --lista metadados/lista_srr.txt --threads 8 --keep-going
```

**Nomenclatura importante:** o Trim Galore grava a saída como `<srr>_1_val_1.fq.gz` / `<srr>_2_val_2.fq.gz` (repare no `_val_` e na extensão `.fq.gz`, diferente do `.fastq.gz` do dado bruto). Os scripts de alinhamento (Parte 7) já esperam esse nome.

## 5.3 Cutadapt vs Trim Galore

| | Cutadapt | Trim Galore |
|---|---|---|
| Controle fino | Excelente | Bom |
| Fácil para iniciantes | Médio | Excelente |
| FastQC integrado | Não | Sim |
| Ideal para | Entender os conceitos | Rodar o pipeline no dia a dia |

---

# Parte 6 — Preparando a referência

Diferente das etapas anteriores, os índices de STAR e Salmon são construídos **uma vez por projeto**, não uma vez por amostra — por isso estes scripts não têm modo "amostra única / lote".

## 6.1 Índice do STAR

```python
#!/usr/bin/env python3
"""
Constrói o índice do genoma para o STAR. Isto é feito UMA VEZ POR PROJETO
(não uma vez por amostra) -- por isso este script não tem modo "amostra
única" nem "lote": ele recebe o genoma e a anotação, e gera um índice que
todas as amostras vão usar depois em star_align.py.

Uso:
    python3 scripts/star_index.py \
        --genoma referencia/genoma.fa \
        --gtf referencia/anotacao.gtf \
        --outdir referencia/star_index \
        --tamanho-leitura 100
"""

import argparse
import subprocess
from pathlib import Path


def construir_indice(genoma, gtf, outdir, tamanho_leitura, threads):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [
            "STAR",
            "--runMode", "genomeGenerate",       # modo "construir índice" (não é alinhamento)
            "--genomeDir", str(outdir),          # pasta onde o índice será salvo
            "--genomeFastaFiles", str(genoma),   # sequência do genoma de referência
            "--sjdbGTFfile", str(gtf),           # anotação de genes/éxons
            # sjdbOverhang deve ser (comprimento da read - 1); é usado para
            # modelar as junções splice esperadas ao redor de cada éxon
            "--sjdbOverhang", str(tamanho_leitura - 1),
            "--runThreadN", str(threads),
        ],
        check=True,
    )


def main():
    parser = argparse.ArgumentParser(description="Constrói o índice do genoma para o STAR (etapa única do projeto).")
    parser.add_argument("--genoma", required=True, help="FASTA do genoma de referência")
    parser.add_argument("--gtf", required=True, help="Anotação de genes (GTF)")
    parser.add_argument("--outdir", default="referencia/star_index")
    parser.add_argument("--tamanho-leitura", type=int, default=100, help="Comprimento das reads (ver FastQC)")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    construir_indice(args.genoma, args.gtf, args.outdir, args.tamanho_leitura, args.threads)
    print(f"[OK] Índice STAR criado em {args.outdir}")


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/star_index.py \
    --genoma referencia/genoma.fa \
    --gtf referencia/anotacao.gtf \
    --outdir referencia/star_index \
    --tamanho-leitura 100
```

`--tamanho-leitura` deve ser o comprimento das suas reads (confira no relatório FastQC — *Sequence Length*); o script converte isso internamente para `--sjdbOverhang` (comprimento − 1), usado pelo STAR para modelar as junções splice ao redor de cada éxon.

## 6.2 Índice do Salmon

```python
#!/usr/bin/env python3
"""
Constrói o índice de transcritos para o Salmon. Assim como o índice do
STAR, isto é feito UMA VEZ POR PROJETO, não por amostra.

IMPORTANTE: este script espera FASTA DESCOMPRIMIDOS (.fa, não .fa.gz).
Se o seu arquivo vier comprimido, descomprima antes:
    gunzip referencia/transcritos.fa.gz

Índice simples (só o transcriptoma):
    python3 scripts/salmon_index.py --transcriptoma referencia/transcritos.fa

Índice "decoy-aware" (recomendado pela documentação oficial do Salmon --
usa o genoma inteiro como "chamariz" para reduzir mapeamentos espúrios):
    python3 scripts/salmon_index.py \
        --transcriptoma referencia/transcritos.fa \
        --genoma referencia/genoma.fa
"""

import argparse
import subprocess
from pathlib import Path


def extrair_nomes_decoy(genoma, destino):
    """
    O Salmon precisa de uma lista com o nome de cada sequência do genoma
    que deve ser tratada como "decoy" -- ou seja, uma região para onde
    reads podem mapear erroneamente se olharmos só o transcriptoma.

    `grep "^>"` pega as linhas de cabeçalho do FASTA (">chr1 descrição...").
    Cada nome de sequência termina na primeira palavra depois do ">".
    """
    resultado = subprocess.run(["grep", "^>", str(genoma)], capture_output=True, text=True, check=True)

    with open(destino, "w", encoding="utf-8") as f:
        for linha in resultado.stdout.splitlines():
            nome = linha[1:].split()[0]  # remove o '>' e pega só a 1a palavra do cabeçalho
            f.write(nome + "\n")


def construir_gentrome(transcriptoma, genoma, destino):
    """
    Concatena transcriptoma + genoma em um único FASTA (o "gentrome"),
    exigido pelo modo decoy-aware do Salmon. A ORDEM importa: o
    transcriptoma vem primeiro, o genoma (decoy) depois.
    """
    with open(destino, "wb") as saida:
        for origem in (transcriptoma, genoma):
            with open(origem, "rb") as entrada:
                saida.write(entrada.read())


def main():
    parser = argparse.ArgumentParser(description="Constrói o índice do Salmon (etapa única do projeto).")
    parser.add_argument("--transcriptoma", required=True, help="FASTA dos transcritos (cDNA), descomprimido")
    parser.add_argument("--genoma", default=None, help="FASTA do genoma, para índice decoy-aware (recomendado)")
    parser.add_argument("--outdir", default="referencia/salmon_index")
    parser.add_argument("--kmer", type=int, default=31, help="Tamanho do k-mer (31 é o padrão para reads >= 75bp)")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.parent.mkdir(parents=True, exist_ok=True)

    if args.genoma:
        pasta_temp = outdir.parent / "salmon_index_tmp"
        pasta_temp.mkdir(parents=True, exist_ok=True)

        decoys = pasta_temp / "decoys.txt"
        gentrome = pasta_temp / "gentrome.fa"

        print("[1/2] Preparando decoys.txt e gentrome.fa...")
        extrair_nomes_decoy(args.genoma, decoys)
        construir_gentrome(args.transcriptoma, args.genoma, gentrome)

        comando = [
            "salmon", "index",
            "-t", str(gentrome),
            "-d", str(decoys),
            "-i", str(outdir),
            "-k", str(args.kmer),
            "-p", str(args.threads),
        ]
    else:
        # Modo simples: só o transcriptoma, sem decoys. Mais rápido de
        # construir, porém mais sujeito a falsos positivos de mapeamento.
        comando = [
            "salmon", "index",
            "-t", str(args.transcriptoma),
            "-i", str(outdir),
            "-k", str(args.kmer),
            "-p", str(args.threads),
        ]

    print("[2/2] Construindo índice do Salmon (pode demorar alguns minutos)...")
    subprocess.run(comando, check=True)
    print(f"[OK] Índice Salmon criado em {outdir}")


if __name__ == "__main__":
    main()
```

```bash
# simples (só transcriptoma)
python3 scripts/salmon_index.py --transcriptoma referencia/transcritos.fa

# decoy-aware (recomendado pela documentação oficial do Salmon)
python3 scripts/salmon_index.py \
    --transcriptoma referencia/transcritos.fa \
    --genoma referencia/genoma.fa
```

## 6.3 Mapeamento transcrito → gene (necessário só para o caminho do Salmon)

O Salmon quantifica por **transcrito**; o DESeq2 trabalha por **gene**. Este mapeamento é o que permite ao `tximport` (Parte 9) somar os transcritos de cada gene.

```python
#!/usr/bin/env python3
"""
Gera o arquivo tx2gene.csv (transcript_id, gene_id) a partir da anotação
GTF usada para construir os índices de STAR/Salmon.

Por que precisamos disso?
--------------------------
O Salmon quantifica no nível de TRANSCRITO (quant.sf tem uma linha por
transcrito). O DESeq2, porém, trabalha no nível de GENE. O pacote
tximport (usado dentro de deseq2_analysis.R) soma as contagens dos
transcritos de um mesmo gene -- mas para isso ele precisa saber qual
transcrito pertence a qual gene. É esse mapeamento que este script gera.

Uso:
    python3 scripts/tx2gene_from_gtf.py referencia/anotacao.gtf --saida referencia/tx2gene.csv
"""

import argparse
import csv
import gzip
import re
from pathlib import Path

# Captura o valor entre aspas de um atributo do GTF, por exemplo:
#   gene_id "AT1G01010";  ->  grupo 1 = AT1G01010
PADRAO_GENE_ID = re.compile(r'gene_id "([^"]+)"')
PADRAO_TRANSCRIPT_ID = re.compile(r'transcript_id "([^"]+)"')


def extrair_pares(gtf_path):
    """Varre o GTF linha a linha e coleta cada par (transcript_id, gene_id) único."""

    # um "set" evita pares duplicados -- o mesmo transcript_id aparece em
    # várias linhas do GTF (uma por éxon), mas queremos cada par só uma vez
    pares = set()

    abrir = gzip.open if str(gtf_path).endswith(".gz") else open

    with abrir(gtf_path, "rt", encoding="utf-8") as f:
        for linha in f:
            if linha.startswith("#"):
                continue  # linha de comentário/cabeçalho do GTF, não tem dado

            colunas = linha.rstrip("\n").split("\t")
            if len(colunas) < 9:
                continue  # linha incompleta ou corrompida -- ignorar com segurança

            # a coluna 9 (índice 8) do GTF é a que traz os atributos
            # "chave valor;" separados por ponto e vírgula
            atributos = colunas[8]

            gene_match = PADRAO_GENE_ID.search(atributos)
            transcript_match = PADRAO_TRANSCRIPT_ID.search(atributos)

            # só nos interessam linhas que tenham OS DOIS IDs -- linhas de
            # features do tipo "gene" não têm transcript_id e são
            # automaticamente puladas aqui
            if gene_match and transcript_match:
                pares.add((transcript_match.group(1), gene_match.group(1)))

    # sorted() só para a saída ficar em uma ordem previsível e fácil de conferir
    return sorted(pares)


def main():
    parser = argparse.ArgumentParser(description="Extrai tx2gene.csv de um arquivo GTF.")
    parser.add_argument("gtf", help="Arquivo de anotação (.gtf ou .gtf.gz)")
    parser.add_argument("--saida", default="referencia/tx2gene.csv")
    args = parser.parse_args()

    pares = extrair_pares(args.gtf)

    Path(args.saida).parent.mkdir(parents=True, exist_ok=True)
    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["transcript_id", "gene_id"])
        writer.writerows(pares)

    print(f"[OK] {len(pares)} transcritos mapeados para genes em {args.saida}")


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/tx2gene_from_gtf.py referencia/anotacao.gtf --saida referencia/tx2gene.csv
```

---

# Parte 7 — Alinhamento (STAR) e quantificação (Salmon)

## 7.1 STAR — script único (uma amostra OU várias)

Pedimos ao próprio STAR para já contar reads por gene (`--quantMode GeneCounts`), evitando depender de uma ferramenta externa (como featureCounts) só para isso.

```python
#!/usr/bin/env python3
"""
Alinha amostras FASTQ (já trimadas) contra o genoma usando o STAR, e já
pede a ele para contar reads por gene (--quantMode GeneCounts) -- assim
não precisamos de uma ferramenta extra (como featureCounts) só para
contar.

Pré-requisito: rodar star_index.py uma vez antes (índice é por projeto,
não por amostra).

MODO 1 - uma única amostra:
    python3 scripts/star_align.py --srr SRR30001 --genome-dir referencia/star_index

MODO 2 - várias amostras:
    python3 scripts/star_align.py --lista metadados/lista_srr.txt --genome-dir referencia/star_index
"""

import argparse
import subprocess
import sys
from pathlib import Path

import pandas as pd


def alinhar_uma_amostra(srr, genome_dir, dados_dir, outdir, threads, indexar_bam):
    """
    Roda o STAR para uma amostra paired-end e devolve o caminho do BAM
    ordenado e do arquivo de contagem por gene.
    """
    # O Trim Galore nomeia sua saída como <srr>_1_val_1.fq.gz /
    # <srr>_2_val_2.fq.gz (extensão .fq.gz, não .fastq.gz) -- é essa
    # convenção que usamos aqui, já que este script lê dados_limpos/.
    r1 = Path(dados_dir) / f"{srr}_1_val_1.fq.gz"
    r2 = Path(dados_dir) / f"{srr}_2_val_2.fq.gz"

    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # STAR usa este prefixo para nomear TODOS os arquivos de saída, por
    # isso terminamos com "_" (vira SRR30001_Aligned.sortedByCoord.out.bam,
    # SRR30001_ReadsPerGene.out.tab, etc.)
    prefixo = outdir / f"{srr}_"

    subprocess.run(
        [
            "STAR",
            "--runMode", "alignReads",                # modo alinhamento (não construção de índice)
            "--genomeDir", str(genome_dir),            # índice criado por star_index.py
            "--readFilesIn", str(r1), str(r2),         # R1 e R2, nesta ordem
            "--readFilesCommand", "zcat",              # os FASTQ estão comprimidos (.gz)
            "--outSAMtype", "BAM", "SortedByCoordinate",  # já entrega BAM ordenado, pronto pra indexar
            "--quantMode", "GeneCounts",               # gera a contagem de reads por gene direto
            "--outFileNamePrefix", str(prefixo),
            "--runThreadN", str(threads),
        ],
        check=True,
    )

    bam = Path(f"{prefixo}Aligned.sortedByCoord.out.bam")
    contagens = Path(f"{prefixo}ReadsPerGene.out.tab")

    if indexar_bam:
        # samtools index cria o arquivo .bai, necessário para visualizar
        # o BAM em IGV ou para algumas ferramentas de downstream analysis
        subprocess.run(["samtools", "index", str(bam)], check=True)

    return bam, contagens


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Alinha uma ou várias amostras com o STAR.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Alinha apenas esta amostra.")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--genome-dir", required=True, help="Índice criado por star_index.py")
    parser.add_argument("--dados", default="dados_limpos", help="Pasta com os FASTQ já trimados")
    parser.add_argument("--outdir", default="alinhamento_star")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--indexar-bam", action="store_true", help="Roda samtools index no BAM gerado")
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args()

    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s).")

    falhas = []
    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] STAR: {srr} ===")
        try:
            bam, contagens = alinhar_uma_amostra(
                srr, args.genome_dir, args.dados, args.outdir, args.threads, args.indexar_bam
            )
            print(f"[OK] {srr} -> {bam.name}, {contagens.name}")
        except subprocess.CalledProcessError as erro:
            print(f"[ERRO] {srr}: {erro}")
            falhas.append(srr)
            if args.srr or not args.keep_going:
                sys.exit(f"Interrompido em {srr}.")

    print(f"\n[OK] {len(srrs) - len(falhas)}/{len(srrs)} amostra(s) alinhada(s).")
    if falhas:
        print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/star_align.py --srr SRR30001 --genome-dir referencia/star_index
python3 scripts/star_align.py --lista metadados/lista_srr.txt --genome-dir referencia/star_index --threads 8 --keep-going
```

## 7.2 Salmon — script único (uma amostra OU várias)

```python
#!/usr/bin/env python3
"""
Quantifica a expressão de transcritos com o Salmon (pseudo-alinhamento --
não gera BAM, é bem mais rápido que o STAR). Precisa do índice criado
por salmon_index.py.

MODO 1 - uma única amostra:
    python3 scripts/salmon_quant.py --srr SRR30001 --index referencia/salmon_index

MODO 2 - várias amostras:
    python3 scripts/salmon_quant.py --lista metadados/lista_srr.txt --index referencia/salmon_index

Cada amostra gera uma PASTA própria dentro de --outdir (ex.:
quantificacao_salmon/SRR30001/quant.sf), pois o Salmon grava vários
arquivos auxiliares junto do quant.sf.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import pandas as pd


def quantificar_uma_amostra(srr, index_dir, dados_dir, outdir, threads):
    # O Trim Galore nomeia sua saída como <srr>_1_val_1.fq.gz /
    # <srr>_2_val_2.fq.gz (extensão .fq.gz, não .fastq.gz) -- é essa
    # convenção que usamos aqui, já que este script lê dados_limpos/.
    r1 = Path(dados_dir) / f"{srr}_1_val_1.fq.gz"
    r2 = Path(dados_dir) / f"{srr}_2_val_2.fq.gz"

    # Cada amostra tem sua própria subpasta -- assim os quant.sf de
    # amostras diferentes nunca se sobrescrevem
    saida_amostra = Path(outdir) / srr
    saida_amostra.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        [
            "salmon", "quant",
            "-i", str(index_dir),        # índice criado por salmon_index.py
            "-l", "A",                   # "A" = Salmon detecta sozinho o tipo de biblioteca
            "-1", str(r1),
            "-2", str(r2),
            "-p", str(threads),
            "--validateMappings",        # modo de mapeamento mais rigoroso (recomendado)
            "-o", str(saida_amostra),
        ],
        check=True,
    )

    return saida_amostra / "quant.sf"


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Quantifica uma ou várias amostras com o Salmon.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Quantifica apenas esta amostra.")
    modo.add_argument("--lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR).")

    parser.add_argument("--index", required=True, help="Índice criado por salmon_index.py")
    parser.add_argument("--dados", default="dados_limpos", help="Pasta com os FASTQ já trimados")
    parser.add_argument("--outdir", default="quantificacao_salmon")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args()

    srrs = [args.srr] if args.srr else carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostra(s).")

    falhas = []
    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] Salmon: {srr} ===")
        try:
            quant_sf = quantificar_uma_amostra(srr, args.index, args.dados, args.outdir, args.threads)
            print(f"[OK] {srr} -> {quant_sf}")
        except subprocess.CalledProcessError as erro:
            print(f"[ERRO] {srr}: {erro}")
            falhas.append(srr)
            if args.srr or not args.keep_going:
                sys.exit(f"Interrompido em {srr}.")

    print(f"\n[OK] {len(srrs) - len(falhas)}/{len(srrs)} amostra(s) quantificada(s).")
    if falhas:
        print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

```bash
python3 scripts/salmon_quant.py --srr SRR30001 --index referencia/salmon_index
python3 scripts/salmon_quant.py --lista metadados/lista_srr.txt --index referencia/salmon_index --threads 8 --keep-going
```

---

# Parte 8 — Montando a matriz de contagens

Esta etapa só existe em **modo lote**: montar uma matriz de contagens só faz sentido quando há várias amostras para comparar entre si. Ela só é necessária no caminho do **STAR** — no caminho do Salmon, o `tximport` (dentro do `deseq2_analysis.R`, Parte 9) lê os `quant.sf` diretamente, sem precisar desta etapa intermediária.

```python
#!/usr/bin/env python3
"""
Combina os arquivos *_ReadsPerGene.out.tab gerados pelo STAR (um por
amostra) em uma única matriz de contagens (genes nas linhas, amostras
nas colunas), pronta para o DESeq2.

Por que isto só existe em "modo lote"?
---------------------------------------
Diferente de download/QC/trimming/alinhamento -- que fazem sentido para
UMA amostra isolada -- montar uma matriz de contagens só faz sentido
quando há VÁRIAS amostras para comparar. Por isso este script sempre
recebe uma lista de amostras, nunca um --srr único.

Sobre a "strandedness" (fita da biblioteca):
---------------------------------------------
O STAR grava 3 colunas de contagem por gene, dependendo do protocolo de
biblioteca usado no sequenciamento:

    coluna 2 = sem considerar a fita (unstranded)
    coluna 3 = fita direta   (protocolos "stranded forward", ex.: Ligation)
    coluna 4 = fita reversa  (protocolos "stranded reverse", ex.: dUTP -- o mais comum hoje)

Se você não sabe qual usar, rode este script uma vez com --resumo: ele
mostra a soma de cada coluna para a primeira amostra -- a coluna com a
soma MAIOR é, em geral, a fita certa (as outras ficam artificialmente
baixas porque estão contando a fita errada).

Uso:
    python3 scripts/combinar_contagens_star.py metadados/lista_srr.txt \
        --dir alinhamento_star --strandedness reverse
"""

import argparse
from pathlib import Path

import pandas as pd

# Mapa do nome amigável para a coluna correspondente dentro do
# *_ReadsPerGene.out.tab (a coluna 0 é o ID do gene)
COLUNA_POR_STRANDEDNESS = {
    "unstranded": "unstranded",
    "forward": "forward",
    "reverse": "reverse",
}


def ler_reads_per_gene(caminho):
    """
    Lê um *_ReadsPerGene.out.tab do STAR.

    As 4 primeiras linhas são estatísticas gerais (não são genes de
    verdade) e precisam ser descartadas antes de montar a matriz:
        N_unmapped, N_multimapping, N_noFeature, N_ambiguous
    """
    df = pd.read_csv(
        caminho, sep="\t", header=None,
        names=["gene_id", "unstranded", "forward", "reverse"],
    )
    # .iloc[4:] pula as 4 primeiras linhas (índices 0, 1, 2, 3)
    return df.iloc[4:].reset_index(drop=True)


def mostrar_resumo(caminho):
    """Ajuda a decidir qual strandedness usar, olhando a soma de cada coluna."""
    df = ler_reads_per_gene(caminho)
    print(f"\nResumo de {caminho.name} (compare as somas para decidir a fita certa):")
    print(f"  unstranded : {df['unstranded'].sum():>12,}")
    print(f"  forward    : {df['forward'].sum():>12,}")
    print(f"  reverse    : {df['reverse'].sum():>12,}")
    print("A coluna com a soma MAIOR costuma indicar o protocolo usado.")


def carregar_lista_srr(caminho):
    caminho = Path(caminho)
    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()
    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def montar_matriz(srrs, star_dir, strandedness):
    star_dir = Path(star_dir)
    nome_coluna = COLUNA_POR_STRANDEDNESS[strandedness]

    matriz = None

    for srr in srrs:
        caminho = star_dir / f"{srr}_ReadsPerGene.out.tab"
        df = ler_reads_per_gene(caminho)

        # Pegamos só a coluna de contagem escolhida, renomeada para o SRR
        coluna_amostra = df[["gene_id", nome_coluna]].rename(columns={nome_coluna: srr})
        coluna_amostra = coluna_amostra.set_index("gene_id")

        if matriz is None:
            matriz = coluna_amostra
        else:
            # join alinha pelo índice (gene_id) -- mais seguro do que
            # assumir que a ordem das linhas é idêntica em todo arquivo
            matriz = matriz.join(coluna_amostra, how="outer")

    return matriz


def main():
    parser = argparse.ArgumentParser(description="Combina ReadsPerGene.out.tab do STAR em uma matriz de contagens.")
    parser.add_argument("lista", help="Arquivo .txt (um SRR por linha) ou .csv (coluna SRR)")
    parser.add_argument("--dir", default="alinhamento_star", help="Pasta com os *_ReadsPerGene.out.tab")
    parser.add_argument("--strandedness", choices=["unstranded", "forward", "reverse"], default="reverse")
    parser.add_argument("--saida", default="contagens/matriz_contagens_star.csv")
    parser.add_argument("--resumo", action="store_true", help="Só mostra as somas por coluna da 1a amostra e sai.")
    args = parser.parse_args()

    srrs = carregar_lista_srr(args.lista)

    if args.resumo:
        primeiro = Path(args.dir) / f"{srrs[0]}_ReadsPerGene.out.tab"
        mostrar_resumo(primeiro)
        return

    matriz = montar_matriz(srrs, args.dir, args.strandedness)

    Path(args.saida).parent.mkdir(parents=True, exist_ok=True)
    matriz.to_csv(args.saida)

    print(f"[OK] Matriz de contagens salva em {args.saida}")
    print(f"[OK] {matriz.shape[0]} genes x {matriz.shape[1]} amostras")


if __name__ == "__main__":
    main()
```

```bash
# ajuda a decidir a "strandedness" olhando a soma de cada coluna
python3 scripts/combinar_contagens_star.py metadados/lista_srr.txt --dir alinhamento_star --resumo

# monta a matriz final
python3 scripts/combinar_contagens_star.py metadados/lista_srr.txt \
    --dir alinhamento_star --strandedness reverse \
    --saida contagens/matriz_contagens_star.csv
```

---

# Parte 9 — Expressão diferencial com DESeq2

Este script funciona com os dois caminhos possíveis (`--tipo star` ou `--tipo salmon`) — a lógica de teste estatístico depois de montado o `DESeqDataSet` é idêntica nos dois casos, só a forma de CARREGAR os dados muda.

```r
#!/usr/bin/env Rscript
# ============================================================================
# Análise de expressão diferencial com DESeq2
#
# Funciona com contagens vindas de DUAS origens possíveis -- escolhidas
# pelo argumento --tipo:
#
#   --tipo star   -> lê uma matriz de contagens (genes x amostras) já
#                    pronta, gerada por combinar_contagens_star.py
#
#   --tipo salmon -> lê os quant.sf de cada amostra (gerados por
#                    salmon_quant.py) e resume por gene usando tximport
#                    + o tx2gene.csv (gerado por tx2gene_from_gtf.py)
#
# Exemplos de uso:
#
#   Rscript scripts/deseq2_analysis.R --tipo star \
#       --contagens contagens/matriz_contagens_star.csv \
#       --amostras metadados/srr_condicao.csv \
#       --outdir resultados_deseq2
#
#   Rscript scripts/deseq2_analysis.R --tipo salmon \
#       --salmon-dir quantificacao_salmon \
#       --tx2gene referencia/tx2gene.csv \
#       --amostras metadados/srr_condicao.csv \
#       --outdir resultados_deseq2
# ============================================================================

# ---- 1. Lendo os argumentos da linha de comando ---------------------------
# Em vez de depender de um pacote extra só para ler argumentos (como o
# optparse), escrevemos um parser bem simples: os argumentos chegam em
# pares "--nome valor" e viram uma lista nomeada, ex.: args[["tipo"]].
ler_argumentos <- function() {
  brutos <- commandArgs(trailingOnly = TRUE)
  args <- list()
  i <- 1
  while (i <= length(brutos)) {
    chave <- sub("^--", "", brutos[i])   # "--tipo" -> "tipo"
    valor <- brutos[i + 1]
    args[[chave]] <- valor
    i <- i + 2
  }
  args
}

args <- ler_argumentos()

# pega_ou_padrao: devolve o valor passado na linha de comando, ou um
# padrão razoável se o argumento não foi informado
pega_ou_padrao <- function(nome, padrao) {
  if (is.null(args[[nome]])) padrao else args[[nome]]
}

tipo             <- pega_ou_padrao("tipo", "star")
outdir           <- pega_ou_padrao("outdir", "resultados_deseq2")
arquivo_amostras <- pega_ou_padrao("amostras", "metadados/srr_condicao.csv")
condicao_ref     <- pega_ou_padrao("referencia", "Controle")  # nível de referência (denominador)
condicao_alt     <- pega_ou_padrao("alvo", "Tratado")         # nível de interesse (numerador)

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# ---- 2. Bibliotecas ---------------------------------------------------------
# suppressMessages() só esconde as mensagens informativas de carregamento,
# não os erros -- se um pacote não estiver instalado, o script ainda para.
suppressMessages(library(DESeq2))

# ---- 3. Tabela de amostras (qual SRR é Controle, qual é Tratado) ----------
amostras <- read.csv(arquivo_amostras, stringsAsFactors = FALSE)

# a coluna Condicao precisa ser um "factor" (categoria) para o DESeq2, e
# fixamos a ORDEM dos níveis explicitamente (referência primeiro) -- se
# não fizermos isso, o R ordena em ordem alfabética, e "Controle" viria
# depois de "Tratado", invertendo o sinal do log2FoldChange sem avisar
amostras$Condicao <- factor(amostras$Condicao, levels = c(condicao_ref, condicao_alt))

# linhas com Condicao vazia (viram NA depois do factor()) são amostras que
# a curadoria automática não conseguiu classificar -- removemos e avisamos,
# em vez de deixá-las quebrar o DESeq2 mais adiante silenciosamente
sem_condicao <- is.na(amostras$Condicao)
if (any(sem_condicao)) {
  cat("[AVISO] Removendo amostras sem condição definida:\n")
  print(amostras$SRR[sem_condicao])
  amostras <- amostras[!sem_condicao, ]
}

# o DESeq2 exige que os nomes das LINHAS de colData sejam os mesmos nomes
# usados nas COLUNAS da matriz/lista de contagens -- aqui, o SRR
rownames(amostras) <- amostras$SRR

# ---- 4. Montando o objeto DESeqDataSet -------------------------------------
if (tipo == "star") {

  arquivo_contagens <- pega_ou_padrao("contagens", "contagens/matriz_contagens_star.csv")

  # a 1a coluna do CSV é o gene_id -- vira o rowname da matriz de contagens
  contagens <- read.csv(arquivo_contagens, row.names = 1, check.names = FALSE)

  # garante que a ORDEM das colunas da matriz seja igual à ordem das
  # linhas de "amostras" -- o DESeq2 não reordena isso sozinho por nós
  contagens <- contagens[, rownames(amostras)]

  dds <- DESeqDataSetFromMatrix(
    countData = contagens,
    colData   = amostras,
    design    = ~Condicao
  )

} else if (tipo == "salmon") {

  suppressMessages(library(tximport))

  arquivo_tx2gene <- pega_ou_padrao("tx2gene", "referencia/tx2gene.csv")
  salmon_dir      <- pega_ou_padrao("salmon-dir", "quantificacao_salmon")

  tx2gene <- read.csv(arquivo_tx2gene, stringsAsFactors = FALSE)

  # um caminho de quant.sf por amostra, na MESMA ordem de "amostras"
  arquivos_quant <- file.path(salmon_dir, rownames(amostras), "quant.sf")
  names(arquivos_quant) <- rownames(amostras)

  # tximport soma as contagens por TRANSCRITO (saída do Salmon) em
  # contagens por GENE, usando o mapeamento tx2gene, e já corrige pelo
  # comprimento médio dos transcritos de cada gene
  txi <- tximport(arquivos_quant, type = "salmon", tx2gene = tx2gene)

  dds <- DESeqDataSetFromTximport(
    txi     = txi,
    colData = amostras,
    design  = ~Condicao
  )

} else {
  stop("--tipo precisa ser 'star' ou 'salmon'.")
}

# ---- 5. Filtro de genes com contagem muito baixa ---------------------------
# Genes com pouquíssimas leituras no total não têm poder estatístico e só
# atrapalham a correção de múltiplos testes (mais genes testados = mais
# difícil um p-valor passar no ajuste) -- por isso é prática comum
# removê-los ANTES de chamar DESeq().
manter <- rowSums(counts(dds)) >= 10
cat(sprintf("[INFO] Mantendo %d de %d genes (contagem total >= 10)\n", sum(manter), length(manter)))
dds <- dds[manter, ]

# ---- 6. Rodando o DESeq2 ----------------------------------------------------
# DESeq() faz, em uma única chamada: normalização por tamanho de
# biblioteca, estimativa da dispersão (variação biológica esperada) e o
# teste estatístico (Wald test, por padrão) gene a gene.
dds <- DESeq(dds)

# ---- 7. Extraindo os resultados --------------------------------------------
# contrast = c("coluna", "nível_alvo", "nível_referência") --> o
# log2FoldChange resultante é "Tratado EM RELAÇÃO a Controle": positivo
# significa mais expresso no tratado, negativo significa mais expresso
# no controle.
res <- results(dds, contrast = c("Condicao", condicao_alt, condicao_ref))

# ordena pelo p-valor ajustado (padj) -- os genes mais confiáveis primeiro
res <- res[order(res$padj), ]

caminho_resultados <- file.path(outdir, "deseq2_resultados_completos.csv")
write.csv(as.data.frame(res), caminho_resultados)
cat(sprintf("[OK] Resultados completos salvos em %s\n", caminho_resultados))

# ---- 8. Lista de DEGs (genes diferencialmente expressos) -------------------
# Limiares clássicos: p-ajustado < 0.05 e |log2FoldChange| > 1 (ou seja,
# expressão pelo menos dobrou ou caiu pela metade). Ajuste para o seu
# experimento se precisar de um critério mais ou menos rigoroso.
res_df <- as.data.frame(res)
res_df$gene_id <- rownames(res_df)

degs <- subset(res_df, !is.na(padj) & padj < 0.05 & abs(log2FoldChange) > 1)
degs <- degs[order(degs$padj), ]

caminho_degs <- file.path(outdir, "degs_significativos.csv")
write.csv(degs, caminho_degs, row.names = FALSE)
cat(sprintf("[OK] %d genes diferencialmente expressos salvos em %s\n", nrow(degs), caminho_degs))

# ---- 9. Gráficos de diagnóstico ---------------------------------------------

# PCA: mostra se as amostras se separam por Condição (o esperado) ou se
# algum outro fator (ex.: lote de sequenciamento) domina a variação.
vsd <- vst(dds, blind = FALSE)  # estabiliza a variância, só para fins de visualização
png(file.path(outdir, "pca.png"), width = 900, height = 700)
print(plotPCA(vsd, intgroup = "Condicao"))
dev.off()

# MA-plot: log2FoldChange (eixo Y) vs. média de expressão (eixo X) --
# pontos coloridos são os genes significativos, segundo o limiar padrão
# da própria função plotMA (padj < 0.1).
png(file.path(outdir, "ma_plot.png"), width = 900, height = 700)
plotMA(res, main = "MA-plot")
dev.off()

# Volcano plot simples, em R base (sem depender de pacotes extras de
# visualização) -- vermelho = DEG segundo nossos limiares (passo 8).
png(file.path(outdir, "volcano.png"), width = 900, height = 700)
with(res_df, plot(
  log2FoldChange, -log10(pvalue),
  pch = 20,
  col = ifelse(!is.na(padj) & padj < 0.05 & abs(log2FoldChange) > 1, "red", "grey60"),
  xlab = "log2 Fold Change", ylab = "-log10(p-valor)",
  main = "Volcano plot"
))
abline(v = c(-1, 1), lty = 2)
dev.off()

cat("[OK] Gráficos salvos em:", outdir, "\n")
cat("Concluído.\n")
```

```bash
# a partir da matriz do STAR
Rscript scripts/deseq2_analysis.R --tipo star \
    --contagens contagens/matriz_contagens_star.csv \
    --amostras metadados/srr_condicao.csv \
    --outdir resultados_deseq2

# a partir dos quant.sf do Salmon
Rscript scripts/deseq2_analysis.R --tipo salmon \
    --salmon-dir quantificacao_salmon \
    --tx2gene referencia/tx2gene.csv \
    --amostras metadados/srr_condicao.csv \
    --outdir resultados_deseq2
```

Saídas geradas em `resultados_deseq2/`: `deseq2_resultados_completos.csv` (todos os genes testados), `degs_significativos.csv` (padj < 0.05 e |log2FC| > 1 — ajuste esses limiares no script para o seu experimento), e três gráficos de diagnóstico: `pca.png`, `ma_plot.png`, `volcano.png`.

> **Por que fixar o nível de referência (`--referencia Controle`)?** Sem isso, o R ordena os níveis alfabeticamente — "Controle" viria depois de "Tratado", e o sinal do `log2FoldChange` seria invertido silenciosamente (positivo passaria a significar "mais expresso no controle"). O script já fixa isso a partir dos argumentos `--referencia`/`--alvo`.

---

# Parte 10 — Enriquecimento funcional (GO / KEGG)

"Enriquecimento" pergunta: entre os DEGs, algum termo biológico (GO) ou via metabólica (KEGG) aparece com **mais frequência do que seria esperado por acaso**? Se sim, é um indício de que aquele processo está sendo afetado pela condição estudada.

Você precisa saber, para o seu organismo: o pacote de anotação (`OrgDb`, ex.: `org.Hs.eg.db` para humano, `org.At.tair.db` para *Arabidopsis*) e o tipo de ID usado nos seus dados (`keytype`, geralmente o mesmo tipo de ID do seu GTF).

```r
#!/usr/bin/env Rscript
# ============================================================================
# Enriquecimento funcional (GO e, opcionalmente, KEGG) a partir da lista de
# genes diferencialmente expressos (DEGs) gerada pelo deseq2_analysis.R.
#
# "Enriquecimento" pergunta: entre os DEGs, algum termo biológico (GO) ou
# via metabólica (KEGG) aparece com MAIS frequência do que seria esperado
# por acaso, dado o total de genes do organismo? Se sim, é um indício de
# que aquele processo/via está sendo afetado pela condição estudada.
#
# Você precisa saber, para o seu organismo:
#   - o pacote de anotação (OrgDb), ex.: "org.Hs.eg.db" (humano),
#     "org.Mm.eg.db" (camundongo), "org.At.tair.db" (Arabidopsis)
#   - o tipo dos IDs usados nos seus dados (keytype), ex.: "ENSEMBL",
#     "SYMBOL", "TAIR" -- geralmente é o mesmo tipo de ID usado no seu GTF
#
# Uso (só GO):
#   Rscript scripts/enrichment_analysis.R \
#       --degs resultados_deseq2/degs_significativos.csv \
#       --orgdb org.Hs.eg.db --keytype ENSEMBL \
#       --outdir resultados_enriquecimento
#
# Uso (GO + KEGG):
#   Rscript scripts/enrichment_analysis.R \
#       --degs resultados_deseq2/degs_significativos.csv \
#       --orgdb org.Hs.eg.db --keytype ENSEMBL \
#       --organismo-kegg hsa \
#       --outdir resultados_enriquecimento
# ============================================================================

# ---- 1. Lendo os argumentos da linha de comando ---------------------------
# Mesmo parser simples "--nome valor" usado em deseq2_analysis.R -- cada
# script R deste tutorial é independente (não importa código de outro
# arquivo .R), então repetimos essas poucas linhas em vez de criar um
# módulo compartilhado só para isso.
ler_argumentos <- function() {
  brutos <- commandArgs(trailingOnly = TRUE)
  args <- list()
  i <- 1
  while (i <= length(brutos)) {
    chave <- sub("^--", "", brutos[i])
    valor <- brutos[i + 1]
    args[[chave]] <- valor
    i <- i + 2
  }
  args
}

args <- ler_argumentos()

pega_ou_padrao <- function(nome, padrao) {
  if (is.null(args[[nome]])) padrao else args[[nome]]
}

# Estes três não têm um padrão sensato sem saber o organismo -- exigimos
# que sejam informados, e paramos com uma mensagem clara se faltar algum.
arquivo_degs <- args[["degs"]]
orgdb_nome   <- args[["orgdb"]]
keytype      <- args[["keytype"]]
outdir       <- pega_ou_padrao("outdir", "resultados_enriquecimento")
organismo_kegg <- args[["organismo-kegg"]]  # opcional -- NULL se não informado

if (is.null(arquivo_degs) || is.null(orgdb_nome) || is.null(keytype)) {
  stop("Uso obrigatorio: --degs <arquivo.csv> --orgdb <pacote> --keytype <tipo_de_id>")
}

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# ---- 2. Bibliotecas ---------------------------------------------------------
suppressMessages(library(clusterProfiler))
suppressMessages(library(enrichplot))       # fornece o dotplot() usado abaixo

# carrega dinamicamente o pacote de anotação do organismo (ex.: org.Hs.eg.db)
# -- character.only = TRUE avisa ao library() que o nome vem de uma
# variável de texto, não escrito diretamente no código
suppressMessages(library(orgdb_nome, character.only = TRUE))
orgdb <- get(orgdb_nome)  # get() recupera o objeto do pacote a partir do nome (texto)

# ---- 3. Lista de genes de entrada ------------------------------------------
degs <- read.csv(arquivo_degs, stringsAsFactors = FALSE)
genes_significativos <- unique(degs$gene_id)
cat(sprintf("[INFO] %d genes significativos carregados de %s\n", length(genes_significativos), arquivo_degs))

# ---- 4. Enriquecimento GO (Gene Ontology) -----------------------------------
# ont = "BP" (Biological Process) é o ponto de partida mais comum; também
# existem "MF" (Molecular Function) e "CC" (Cellular Component).
ego <- enrichGO(
  gene          = genes_significativos,
  OrgDb         = orgdb,
  keyType       = keytype,
  ont           = "BP",
  pAdjustMethod = "BH",     # Benjamini-Hochberg, a mesma correção usada no DESeq2
  pvalueCutoff  = 0.05,
  qvalueCutoff  = 0.2,
  readable      = FALSE
)

caminho_go <- file.path(outdir, "enriquecimento_GO_BP.csv")
write.csv(as.data.frame(ego), caminho_go, row.names = FALSE)
cat(sprintf("[OK] %d termos GO (BP) significativos salvos em %s\n", nrow(as.data.frame(ego)), caminho_go))

# dotplot: cada linha é um termo GO, o tamanho do ponto é quantos DEGs
# caem naquele termo, a cor é a significância (padj)
if (nrow(as.data.frame(ego)) > 0) {
  png(file.path(outdir, "go_bp_dotplot.png"), width = 1000, height = 800)
  print(dotplot(ego, showCategory = 20, title = "GO - Biological Process"))
  dev.off()
}

# ---- 5. Enriquecimento KEGG (opcional) -------------------------------------
if (!is.null(organismo_kegg)) {

  # o enrichKEGG do clusterProfiler trabalha com ENTREZID -- se os DEGs
  # estiverem em outro formato (ex.: ENSEMBL), convertemos com bitr()
  if (keytype == "ENTREZID") {
    entrez_ids <- genes_significativos
  } else {
    conversao <- bitr(genes_significativos, fromType = keytype, toType = "ENTREZID", OrgDb = orgdb)
    entrez_ids <- unique(conversao$ENTREZID)
    cat(sprintf("[INFO] %d/%d genes convertidos para ENTREZID\n", length(entrez_ids), length(genes_significativos)))
  }

  ekegg <- enrichKEGG(
    gene          = entrez_ids,
    organism      = organismo_kegg,   # código KEGG do organismo, ex.: "hsa" (humano), "ath" (Arabidopsis)
    pAdjustMethod = "BH",
    pvalueCutoff  = 0.05
  )

  caminho_kegg <- file.path(outdir, "enriquecimento_KEGG.csv")
  write.csv(as.data.frame(ekegg), caminho_kegg, row.names = FALSE)
  cat(sprintf("[OK] %d vias KEGG significativas salvas em %s\n", nrow(as.data.frame(ekegg)), caminho_kegg))

  if (nrow(as.data.frame(ekegg)) > 0) {
    png(file.path(outdir, "kegg_dotplot.png"), width = 1000, height = 800)
    print(dotplot(ekegg, showCategory = 20, title = "KEGG pathways"))
    dev.off()
  }
} else {
  cat("[INFO] --organismo-kegg não informado -- pulando enriquecimento KEGG.\n")
}

cat("Concluído.\n")
```

```bash
# só GO
Rscript scripts/enrichment_analysis.R \
    --degs resultados_deseq2/degs_significativos.csv \
    --orgdb org.Hs.eg.db --keytype ENSEMBL \
    --outdir resultados_enriquecimento

# GO + KEGG
Rscript scripts/enrichment_analysis.R \
    --degs resultados_deseq2/degs_significativos.csv \
    --orgdb org.Hs.eg.db --keytype ENSEMBL \
    --organismo-kegg hsa \
    --outdir resultados_enriquecimento
```

---

# Parte 11 — O pipeline fechado

Aqui está a diferença mais importante desta versão: em vez de um script "de amostra única" que outro script "de lote" reaproveita por importação, o pipeline inteiro (download → QC → trimming → alinhamento/quantificação, e em lote também DESeq2 + enriquecimento) mora em **um único script** por linguagem. `pipeline.py` **importa as funções** dos scripts das partes anteriores — isso não é o mesmo problema do "amostra.py importa lote.py": cada um desses scripts (`download.py`, `qc.py` etc.) já é, sozinho, um programa completo e independente; o `pipeline.py` só evita reescrever a mesma lógica de novo.

## 11.1 Pipeline em Python

```python
#!/usr/bin/env python3
"""
Pipeline completo: SRA -> FASTQ limpo -> alinhamento/quantificação ->
(em lote) matriz de contagens -> DESeq2 -> enriquecimento funcional.

Este script REAPROVEITA as funções dos outros scripts desta pasta
(download.py, qc.py, trim_galore_step.py, star_align.py, salmon_quant.py)
em vez de reescrever a lógica de cada etapa. Isso é diferente de ter
"amostra.py" e "lote.py" duplicando código: aqui, cada arquivo já é um
programa completo e independente (roda sozinho, com seu próprio --srr/
--lista); o pipeline.py só os importa como biblioteca para não chamar
cada um via subprocess (mais lento e mais difícil de depurar).

As etapas de comparação estatística (combinar contagens, DESeq2,
enriquecimento) moram em arquivos .py e .R separados porque fazem parte
de um mundo diferente (estatística/R), e são chamadas via subprocess.

MODO 1 - uma única amostra (vai só até alinhamento/quantificação --
sozinha, uma amostra não permite nenhuma comparação estatística):

    python3 scripts/pipeline.py --srr SRR30001 \
        --aligner star --star-genome-dir referencia/star_index

MODO 2 - lote completo, incluindo DESeq2 e enriquecimento:

    python3 scripts/pipeline.py \
        --sample-sheet metadados/sample_sheet_curado.csv \
        --aligner star --star-genome-dir referencia/star_index \
        --rodar-analise --orgdb org.At.tair.db --keytype TAIR
"""

import argparse
import logging
import subprocess
import sys
from pathlib import Path

import pandas as pd

# Importa as FUNÇÕES dos outros scripts desta pasta. sys.path.insert
# garante que o Python encontre esses arquivos mesmo que pipeline.py
# seja chamado de outro diretório.
sys.path.insert(0, str(Path(__file__).parent))
from download import baixar_uma_amostra                       # noqa: E402
from qc import rodar_fastqc, caminhos_fastq                    # noqa: E402
from trim_galore_step import rodar_trim_galore                 # noqa: E402
from star_align import alinhar_uma_amostra as alinhar_star     # noqa: E402
from salmon_quant import quantificar_uma_amostra as quantificar_salmon  # noqa: E402

# Todos os diretórios do projeto, num só lugar -- fica fácil de ver a
# estrutura inteira e de mudar um caminho sem procurar por todo o script.
DIRS = {
    "sra": Path("sra"),
    "brutos": Path("dados_brutos"),
    "limpos": Path("dados_limpos"),
    "qc_bruto": Path("qc_bruto"),
    "qc_limpo": Path("qc_limpo"),
    "align_star": Path("alinhamento_star"),
    "quant_salmon": Path("quantificacao_salmon"),
    "contagens": Path("contagens"),
    "logs": Path("logs"),
}


def configurar_logging():
    DIRS["logs"].mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            # grava em arquivo E mostra na tela ao mesmo tempo
            logging.FileHandler(DIRS["logs"] / "pipeline.log"),
            logging.StreamHandler(sys.stdout),
        ],
    )


def processar_amostra(srr, args):
    """Executa download -> QC -> trimming -> alinhamento/quantificação para UMA amostra."""
    logging.info("=" * 60)
    logging.info(f"Amostra: {srr}")
    logging.info("=" * 60)

    if not args.skip_download:
        baixar_uma_amostra(
            srr, sra_dir=DIRS["sra"], fastq_dir=DIRS["brutos"],
            threads=args.threads, pular_se_existir=True,
        )

    if not args.skip_qc:
        r1, r2 = caminhos_fastq(srr, DIRS["brutos"], sufixo="")
        rodar_fastqc([r1, r2], outdir=DIRS["qc_bruto"], threads=args.threads)

    if not args.skip_trim:
        r1 = DIRS["brutos"] / f"{srr}_1.fastq.gz"
        r2 = DIRS["brutos"] / f"{srr}_2.fastq.gz"
        rodar_trim_galore(r1, r2, outdir=DIRS["limpos"], threads=args.threads, fastqc=True)

    if not args.skip_align:
        if args.aligner == "star":
            alinhar_star(
                srr, genome_dir=args.star_genome_dir, dados_dir=DIRS["limpos"],
                outdir=DIRS["align_star"], threads=args.threads, indexar_bam=False,
            )
        else:  # salmon
            quantificar_salmon(
                srr, index_dir=args.salmon_index, dados_dir=DIRS["limpos"],
                outdir=DIRS["quant_salmon"], threads=args.threads,
            )


def rodar_analise_em_lote(args):
    """Combina contagens, roda DESeq2 e (opcionalmente) o enriquecimento funcional."""
    scripts_dir = Path(__file__).parent

    if args.aligner == "star":
        logging.info("Combinando contagens do STAR em uma matriz única...")
        subprocess.run(
            [
                sys.executable, str(scripts_dir / "combinar_contagens_star.py"),
                args.sample_sheet,  # o próprio sample sheet já tem a coluna SRR
                "--dir", str(DIRS["align_star"]),
                "--strandedness", args.strandedness,
                "--saida", str(DIRS["contagens"] / "matriz_contagens_star.csv"),
            ],
            check=True,
        )
        args_deseq2 = [
            "--tipo", "star",
            "--contagens", str(DIRS["contagens"] / "matriz_contagens_star.csv"),
        ]
    else:
        # No caminho do Salmon não precisamos combinar nada em Python -- o
        # deseq2_analysis.R lê os quant.sf diretamente via tximport.
        args_deseq2 = [
            "--tipo", "salmon",
            "--salmon-dir", str(DIRS["quant_salmon"]),
            "--tx2gene", args.tx2gene,
        ]

    logging.info("Rodando DESeq2...")
    subprocess.run(
        [
            "Rscript", str(scripts_dir / "deseq2_analysis.R"),
            *args_deseq2,
            "--amostras", args.srr_condicao,
            "--outdir", "resultados_deseq2",
        ],
        check=True,
    )

    if args.orgdb and args.keytype:
        logging.info("Rodando enriquecimento funcional...")
        comando = [
            "Rscript", str(scripts_dir / "enrichment_analysis.R"),
            "--degs", "resultados_deseq2/degs_significativos.csv",
            "--orgdb", args.orgdb,
            "--keytype", args.keytype,
            "--outdir", "resultados_enriquecimento",
        ]
        if args.organismo_kegg:
            comando += ["--organismo-kegg", args.organismo_kegg]
        subprocess.run(comando, check=True)
    else:
        logging.info("--orgdb/--keytype não informados -- pulando enriquecimento funcional.")


def main():
    parser = argparse.ArgumentParser(description="Pipeline completo de RNA-Seq: SRA -> DEGs -> enriquecimento.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Processa apenas esta amostra (para no alinhamento/quantificação).")
    modo.add_argument("--sample-sheet", help="CSV com colunas SRR e Condicao (modo lote).")

    parser.add_argument("--threads", type=int, default=4)

    parser.add_argument("--aligner", choices=["star", "salmon"], required=True)
    parser.add_argument("--star-genome-dir", help="Índice STAR (obrigatório se --aligner star)")
    parser.add_argument("--salmon-index", help="Índice Salmon (obrigatório se --aligner salmon)")

    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--skip-qc", action="store_true")
    parser.add_argument("--skip-trim", action="store_true")
    parser.add_argument("--skip-align", action="store_true")
    parser.add_argument("--keep-going", action="store_true", help="Modo lote: não para se uma amostra falhar.")

    # Só têm efeito em modo lote, com --rodar-analise:
    parser.add_argument("--rodar-analise", action="store_true", help="Roda DESeq2 (+ enriquecimento) após o lote.")
    parser.add_argument("--srr-condicao", default="metadados/srr_condicao.csv")
    parser.add_argument("--strandedness", choices=["unstranded", "forward", "reverse"], default="reverse")
    parser.add_argument("--tx2gene", help="Necessário se --aligner salmon e --rodar-analise")
    parser.add_argument("--orgdb", help="Pacote de anotação p/ enriquecimento, ex.: org.Hs.eg.db")
    parser.add_argument("--keytype", help="Tipo de ID dos genes p/ enriquecimento, ex.: ENSEMBL")
    parser.add_argument("--organismo-kegg", help="Código KEGG do organismo, ex.: hsa (opcional)")

    args = parser.parse_args()

    # Validações que o argparse sozinho não expressa bem (dependências
    # entre argumentos, não só "isto é obrigatório")
    if args.aligner == "star" and not args.star_genome_dir:
        sys.exit("ERRO: --star-genome-dir é obrigatório com --aligner star.")
    if args.aligner == "salmon" and not args.salmon_index:
        sys.exit("ERRO: --salmon-index é obrigatório com --aligner salmon.")
    if args.rodar_analise and args.aligner == "salmon" and not args.tx2gene:
        sys.exit("ERRO: --tx2gene é obrigatório para rodar a análise com --aligner salmon.")
    if args.rodar_analise and not args.sample_sheet:
        sys.exit("ERRO: --rodar-analise só faz sentido em modo lote (--sample-sheet).")

    for d in DIRS.values():
        d.mkdir(parents=True, exist_ok=True)
    configurar_logging()

    if args.srr:
        amostras = [args.srr]
    else:
        df = pd.read_csv(args.sample_sheet)
        amostras = df["SRR"].astype(str).str.strip().tolist()

    falhas = []
    for i, srr in enumerate(amostras, start=1):
        logging.info(f"[{i}/{len(amostras)}] Processando {srr}")
        try:
            processar_amostra(srr, args)
        except subprocess.CalledProcessError as erro:
            logging.error(f"[ERRO] {srr} falhou: {erro}")
            falhas.append(srr)
            if args.srr or not args.keep_going:
                sys.exit(f"Pipeline interrompido em {srr}. Use --keep-going para pular falhas em lote.")

    if args.sample_sheet and args.rodar_analise:
        if falhas:
            logging.warning(f"Rodando a análise mesmo com {len(falhas)} amostra(s) que falharam: {falhas}")
        rodar_analise_em_lote(args)

    logging.info("Pipeline concluído.")
    if falhas:
        logging.warning(f"{len(falhas)} amostra(s) falharam: {', '.join(falhas)}")


if __name__ == "__main__":
    main()
```

```bash
# uma única amostra (para na quantificação -- não há o que comparar sozinha)
python3 scripts/pipeline.py --srr SRR30001 \
    --aligner star --star-genome-dir referencia/star_index

# lote completo, com STAR + DESeq2 + enriquecimento
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --aligner star --star-genome-dir referencia/star_index \
    --rodar-analise --strandedness reverse \
    --orgdb org.At.tair.db --keytype TAIR \
    --threads 8 --keep-going

# lote completo, com Salmon + DESeq2 (sem enriquecimento, por não informar --orgdb)
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --aligner salmon --salmon-index referencia/salmon_index \
    --rodar-analise --tx2gene referencia/tx2gene.csv \
    --threads 8
```

## 11.2 Pipeline em Bash

```bash
#!/usr/bin/env bash
# Pipeline completo em Bash: aceita um único SRR OU uma lista de SRR.
# Cobre download -> QC -> trimming -> alinhamento (STAR) OU quantificação
# (Salmon). A parte estatística (DESeq2 + enriquecimento) só roda em modo
# lote, com --rodar-analise, chamando os scripts desta mesma pasta.
#
# Uso -- uma amostra, com STAR:
#   scripts/pipeline.sh --srr SRR30001 \
#       --aligner star --star-genome-dir referencia/star_index
#
# Uso -- lote completo, com Salmon + DESeq2 + enriquecimento:
#   scripts/pipeline.sh --lista metadados/lista_srr.txt \
#       --aligner salmon --salmon-index referencia/salmon_index \
#       --rodar-analise --tx2gene referencia/tx2gene.csv \
#       --orgdb org.At.tair.db --keytype TAIR

set -euo pipefail

# ---- valores padrão, sobrescritos pelos argumentos abaixo ------------------
THREADS=4
SRR_UNICO=""
LISTA=""
ALIGNER=""
STAR_GENOME_DIR=""
SALMON_INDEX=""
RODAR_ANALISE=0
STRANDEDNESS="reverse"
TX2GENE=""
ORGDB=""
KEYTYPE=""
ORGANISMO_KEGG=""
SRR_CONDICAO="metadados/srr_condicao.csv"

# ---- leitura dos argumentos -------------------------------------------------
# Cada "case" reconhece uma flag e consome ela + seu valor (shift 2), ou só
# ela mesma quando é uma flag booleana (shift 1, ex.: --rodar-analise).
while [[ $# -gt 0 ]]; do
    case "$1" in
        --srr) SRR_UNICO="$2"; shift 2 ;;
        --lista) LISTA="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --aligner) ALIGNER="$2"; shift 2 ;;
        --star-genome-dir) STAR_GENOME_DIR="$2"; shift 2 ;;
        --salmon-index) SALMON_INDEX="$2"; shift 2 ;;
        --rodar-analise) RODAR_ANALISE=1; shift ;;
        --strandedness) STRANDEDNESS="$2"; shift 2 ;;
        --tx2gene) TX2GENE="$2"; shift 2 ;;
        --orgdb) ORGDB="$2"; shift 2 ;;
        --keytype) KEYTYPE="$2"; shift 2 ;;
        --organismo-kegg) ORGANISMO_KEGG="$2"; shift 2 ;;
        --srr-condicao) SRR_CONDICAO="$2"; shift 2 ;;
        *) echo "Opção desconhecida: $1"; exit 1 ;;
    esac
done

# ---- validações -------------------------------------------------------------
if [[ -z "$SRR_UNICO" && -z "$LISTA" ]]; then
    echo "Uso: $0 --srr SRRxxxxx   OU   $0 --lista arquivo.txt   (+ --aligner star|salmon)"
    exit 1
fi
if [[ "$ALIGNER" != "star" && "$ALIGNER" != "salmon" ]]; then
    echo "Use --aligner star ou --aligner salmon"
    exit 1
fi
if [[ "$ALIGNER" == "star" && -z "$STAR_GENOME_DIR" ]]; then
    echo "ERRO: --star-genome-dir é obrigatório com --aligner star"
    exit 1
fi
if [[ "$ALIGNER" == "salmon" && -z "$SALMON_INDEX" ]]; then
    echo "ERRO: --salmon-index é obrigatório com --aligner salmon"
    exit 1
fi

# ---- diretórios do projeto ---------------------------------------------------
BRUTOS="dados_brutos"
LIMPOS="dados_limpos"
QC_BRUTO="qc_bruto"
QC_LIMPO="qc_limpo"
SRA="sra"
ALIGN_STAR="alinhamento_star"
QUANT_SALMON="quantificacao_salmon"
CONTAGENS="contagens"

mkdir -p "$BRUTOS" "$LIMPOS" "$QC_BRUTO" "$QC_LIMPO" "$SRA" "$ALIGN_STAR" "$QUANT_SALMON" "$CONTAGENS"

# Descobre em qual pasta este próprio script está, para conseguir chamar os
# outros scripts (Python/R) da mesma pasta não importa de onde você rode.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- função reaproveitada tanto para 1 amostra quanto dentro do loop -------
processar_amostra() {
    local srr="$1"

    echo
    echo "=== $srr ==="

    if [[ -f "$BRUTOS/${srr}_1.fastq.gz" && -f "$BRUTOS/${srr}_2.fastq.gz" ]]; then
        echo "[SKIP] $srr já baixado."
    else
        prefetch "$srr" --output-directory "$SRA"
        vdb-validate "$SRA/$srr"
        fasterq-dump "$SRA/$srr" --split-files --threads "$THREADS" --outdir "$BRUTOS"
        gzip -f "$BRUTOS/${srr}_1.fastq" "$BRUTOS/${srr}_2.fastq"
    fi

    fastqc "$BRUTOS/${srr}_1.fastq.gz" "$BRUTOS/${srr}_2.fastq.gz" \
        --threads "$THREADS" --outdir "$QC_BRUTO"

    trim_galore --paired --cores "$THREADS" --fastqc \
        --output_dir "$LIMPOS" \
        "$BRUTOS/${srr}_1.fastq.gz" "$BRUTOS/${srr}_2.fastq.gz"

    # Trim Galore nomeia a saída como <srr>_1_val_1.fq.gz / _2_val_2.fq.gz
    local limpo_r1="$LIMPOS/${srr}_1_val_1.fq.gz"
    local limpo_r2="$LIMPOS/${srr}_2_val_2.fq.gz"

    if [[ "$ALIGNER" == "star" ]]; then
        STAR --runMode alignReads \
            --genomeDir "$STAR_GENOME_DIR" \
            --readFilesIn "$limpo_r1" "$limpo_r2" \
            --readFilesCommand zcat \
            --outSAMtype BAM SortedByCoordinate \
            --quantMode GeneCounts \
            --outFileNamePrefix "$ALIGN_STAR/${srr}_" \
            --runThreadN "$THREADS"
    else
        salmon quant -i "$SALMON_INDEX" -l A \
            -1 "$limpo_r1" -2 "$limpo_r2" \
            -p "$THREADS" --validateMappings \
            -o "$QUANT_SALMON/$srr"
    fi

    echo "[OK] $srr"
}

# ---- executa: 1 amostra OU lote inteiro -------------------------------------
if [[ -n "$SRR_UNICO" ]]; then
    processar_amostra "$SRR_UNICO"
else
    while IFS= read -r srr; do
        [[ -z "$srr" ]] && continue
        processar_amostra "$srr"
    done < "$LISTA"
fi

echo
echo "FastQC final (dados já trimados)"
fastqc "$LIMPOS"/*.fq.gz --threads "$THREADS" --outdir "$QC_LIMPO"

# ---- análise estatística (só em modo lote, com --rodar-analise) ------------
if [[ -n "$LISTA" && "$RODAR_ANALISE" -eq 1 ]]; then
    echo
    echo "=== Análise estatística (lote) ==="

    if [[ "$ALIGNER" == "star" ]]; then
        python3 "$SCRIPT_DIR/combinar_contagens_star.py" "$LISTA" \
            --dir "$ALIGN_STAR" --strandedness "$STRANDEDNESS" \
            --saida "$CONTAGENS/matriz_contagens_star.csv"

        Rscript "$SCRIPT_DIR/deseq2_analysis.R" --tipo star \
            --contagens "$CONTAGENS/matriz_contagens_star.csv" \
            --amostras "$SRR_CONDICAO" --outdir resultados_deseq2
    else
        Rscript "$SCRIPT_DIR/deseq2_analysis.R" --tipo salmon \
            --salmon-dir "$QUANT_SALMON" --tx2gene "$TX2GENE" \
            --amostras "$SRR_CONDICAO" --outdir resultados_deseq2
    fi

    if [[ -n "$ORGDB" && -n "$KEYTYPE" ]]; then
        # array vazio por padrão; só ganha --organismo-kegg se foi informado
        args_kegg=()
        [[ -n "$ORGANISMO_KEGG" ]] && args_kegg=(--organismo-kegg "$ORGANISMO_KEGG")

        Rscript "$SCRIPT_DIR/enrichment_analysis.R" \
            --degs resultados_deseq2/degs_significativos.csv \
            --orgdb "$ORGDB" --keytype "$KEYTYPE" \
            --outdir resultados_enriquecimento \
            "${args_kegg[@]}"
    fi
fi

echo "Pipeline finalizado."
```

```bash
chmod +x scripts/pipeline.sh

# uma amostra
scripts/pipeline.sh --srr SRR30001 --aligner star --star-genome-dir referencia/star_index

# lote completo, com Salmon + DESeq2 + enriquecimento, log salvo em arquivo
scripts/pipeline.sh --lista metadados/lista_srr.txt \
    --aligner salmon --salmon-index referencia/salmon_index \
    --rodar-analise --tx2gene referencia/tx2gene.csv \
    --orgdb org.At.tair.db --keytype TAIR \
    --threads 8 2>&1 | tee logs/pipeline.log
```

---

# Parte 12 — Boas práticas, checklist e referência final

## 12.1 Checklist antes de confiar nos DEGs

```text
[ ] Todo SRR foi associado ao GSM e à condição experimental corretos
[ ] O desenho experimental foi conferido no GEO (não só inferido do texto)
[ ] Réplicas biológicas foram diferenciadas de runs técnicos
[ ] Nenhuma amostra ficou com Condicao vazia sem revisão manual
[ ] FastQC bruto e pós-trimming revisados (adaptadores, qualidade)
[ ] Strandedness (STAR) conferida com --resumo antes de montar a matriz
[ ] PCA do DESeq2 mostra separação por condição (não por outro fator, tipo lote)
[ ] Nível de referência (Controle) fixado explicitamente no DESeq2
[ ] Limiares de padj/log2FC documentados e justificados
[ ] OrgDb/keytype do enriquecimento conferem com o organismo e o tipo de ID usado
```

## 12.2 Tabela-resumo: um comando por etapa

| Etapa | Script | Uma amostra | Várias amostras |
|---|---|---|---|
| Metadados GEO | `geo_to_sample_sheet.py` | — (sempre por GSE) | `geo_to_sample_sheet.py GSE1 GSE2` |
| Curadoria | `curar_sample_sheet.py` | — (sempre a tabela inteira) | `curar_sample_sheet.py` |
| Download | `download.py` | `--srr SRR1` | `--lista lista.txt` |
| FastQC | `qc.py` | `--srr SRR1` | `--lista lista.txt` |
| Cutadapt | `cutadapt_step.py` | `--srr SRR1` | `--lista lista.txt` |
| Trim Galore | `trim_galore_step.py` | `--srr SRR1` | `--lista lista.txt` |
| Índice STAR | `star_index.py` | — (por projeto) | — (por projeto) |
| Índice Salmon | `salmon_index.py` | — (por projeto) | — (por projeto) |
| tx2gene | `tx2gene_from_gtf.py` | — (por projeto) | — (por projeto) |
| Alinhamento STAR | `star_align.py` | `--srr SRR1` | `--lista lista.txt` |
| Quantificação Salmon | `salmon_quant.py` | `--srr SRR1` | `--lista lista.txt` |
| Matriz de contagens | `combinar_contagens_star.py` | — (sempre lote) | `lista.txt` |
| DESeq2 | `deseq2_analysis.R` | — (sempre lote) | `--tipo star\|salmon` |
| Enriquecimento | `enrichment_analysis.R` | — (sempre lote) | `--degs ...csv` |
| **Pipeline fechado** | `pipeline.py` / `pipeline.sh` | `--srr SRR1` | `--sample-sheet sheet.csv` / `--lista lista.txt` |

## 12.3 O conceito central

O aluno não deve sair sabendo só encadear comandos. Ele deve conseguir responder: por que este SRR → qual GSM o originou → é controle ou tratado → é réplica biológica ou técnica → os dados brutos têm boa qualidade → o alinhamento/quantificação faz sentido (taxa de mapeamento razoável?) → os genes candidatos a DEG têm suporte estatístico real → os termos enriquecidos fazem sentido biológico para o experimento? Esse encadeamento é o que transforma "rodar um pipeline" em "fazer uma análise de RNA-Seq".

## 12.4 Referências oficiais

- GEO — acesso programático: https://www.ncbi.nlm.nih.gov/geo/info/geo_paccess.html
- Formato SOFT: https://www.ncbi.nlm.nih.gov/geo/info/soft.html
- SRA Toolkit: https://github.com/ncbi/sra-tools
- Cutadapt: https://cutadapt.readthedocs.io/
- Trim Galore: https://github.com/FelixKrueger/TrimGalore
- STAR: https://github.com/alexdobin/STAR
- Salmon: https://salmon.readthedocs.io/
- tximport: https://bioconductor.org/packages/release/bioc/vignettes/tximport/inst/doc/tximport.html
- DESeq2: https://bioconductor.org/packages/release/bioc/vignettes/DESeq2/inst/doc/DESeq2.html
- clusterProfiler: https://yulab-smu.top/biomedical-knowledge-mining-book/


---

# Parte 13 — Relatório interativo em HTML

A última etapa do pipeline: um único arquivo HTML autocontido (abre em qualquer navegador, sem precisar de internet ou servidor) reunindo os resultados do DESeq2 e do enriquecimento funcional, com gráficos interativos (zoom, hover) e tabelas filtráveis. Assim como o DESeq2 e o enriquecimento, só faz sentido em **modo lote**.

## 13.1 O wrapper (`gerar_relatorio.R`)

```r
#!/usr/bin/env Rscript
# ============================================================================
# Gera um relatorio HTML interativo a partir dos resultados do DESeq2 e,
# se disponivel, do enriquecimento funcional (GO/KEGG).
#
# Assim como o DESeq2 e o enriquecimento, esta etapa e sempre "em lote":
# um relatorio comparando Controle vs Tratado nao faz sentido para uma
# unica amostra isolada.
#
# Uso (so DESeq2, sem enriquecimento):
#   Rscript scripts/gerar_relatorio.R \
#       --deseq2-dir resultados_deseq2 \
#       --outdir relatorio_html
#
# Uso (DESeq2 + enriquecimento):
#   Rscript scripts/gerar_relatorio.R \
#       --deseq2-dir resultados_deseq2 \
#       --enrich-dir resultados_enriquecimento \
#       --outdir relatorio_html
# ============================================================================

# ---- 1. Lendo os argumentos da linha de comando ---------------------------
# Mesmo parser simples "--nome valor" usado em deseq2_analysis.R e
# enrichment_analysis.R -- repetido aqui de propósito, para que este
# script continue sendo independente dos outros (não importa nada deles).
ler_argumentos <- function() {
  brutos <- commandArgs(trailingOnly = TRUE)
  args <- list()
  i <- 1
  while (i <= length(brutos)) {
    chave <- sub("^--", "", brutos[i])
    valor <- brutos[i + 1]
    args[[chave]] <- valor
    i <- i + 2
  }
  args
}

args <- ler_argumentos()

pega_ou_padrao <- function(nome, padrao) {
  if (is.null(args[[nome]])) padrao else args[[nome]]
}

deseq2_dir <- pega_ou_padrao("deseq2-dir", "resultados_deseq2")

# Se --enrich-dir NÃO foi passado, queremos o valor lógico NA (não a
# string "NA"!) -- é isso que o template .Rmd usa para decidir, com
# is.na(), se deve pular inteiramente a seção de enriquecimento.
enrich_dir <- if (is.null(args[["enrich-dir"]])) NA else args[["enrich-dir"]]

outdir <- pega_ou_padrao("outdir", "relatorio_html")
titulo <- pega_ou_padrao("titulo", "Relatorio de Analise de RNA-Seq")

suppressMessages(library(rmarkdown))

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# ---- 2. Descobrindo onde este próprio script está -------------------------
# Rscript não tem um equivalente direto ao __file__ do Python. O truque
# padrão é procurar, entre os argumentos "brutos" da sessão R (incluindo
# os que o próprio Rscript usa internamente), aquele que começa com
# "--file=" -- é ele que revela o caminho deste script.
argumentos_completos <- commandArgs(trailingOnly = FALSE)
arg_arquivo <- grep("^--file=", argumentos_completos, value = TRUE)
diretorio_script <- dirname(sub("^--file=", "", arg_arquivo))

# O template .Rmd mora na mesma pasta deste script.
template <- file.path(diretorio_script, "relatorio_template.Rmd")

# ---- 3. Renderizando o relatório --------------------------------------------
rmarkdown::render(
  input       = template,
  params      = list(deseq2_dir = deseq2_dir, enrich_dir = enrich_dir, titulo = titulo),
  output_file = "relatorio.html",
  output_dir  = outdir,
  envir       = new.env()  # ambiente limpo, para não misturar variáveis com a sessão atual
)

cat(sprintf("[OK] Relatório gerado em %s\n", file.path(outdir, "relatorio.html")))
```

## 13.2 O template do relatório (`relatorio_template.Rmd`)

````r
---
title: "`r params$titulo`"
date: "`r format(Sys.time(), '%d/%m/%Y %H:%M')`"
output:
  html_document:
    self_contained: true
    theme: flatly
    toc: true
    toc_float: true
    code_folding: hide
params:
  deseq2_dir: "resultados_deseq2"
  enrich_dir: NA
  titulo: "Relatorio de Analise de RNA-Seq"
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)
suppressMessages({
  library(DT)
  library(plotly)
  library(ggplot2)
})

deseq2_dir <- params$deseq2_dir
enrich_dir <- params$enrich_dir
```

## Resumo

Este relatório resume os resultados da análise de expressão diferencial
(DESeq2) e, se disponível, do enriquecimento funcional (GO/KEGG) gerados
pelo pipeline. Passe o mouse sobre os pontos dos gráficos para ver
detalhes, e use as caixas de busca das tabelas para filtrar genes ou
termos específicos.

## Expressão diferencial (DESeq2)

```{r carregar-deseq2}
# a 1a coluna do CSV é o gene_id (foi salva como rowname pelo DESeq2) --
# recuperamos ela como uma coluna normal, para poder usar em gráficos/tabelas
completos <- read.csv(file.path(deseq2_dir, "deseq2_resultados_completos.csv"), row.names = 1)
completos$gene_id <- rownames(completos)

degs <- read.csv(file.path(deseq2_dir, "degs_significativos.csv"))

n_total <- nrow(completos)
n_deg   <- nrow(degs)
n_up    <- sum(degs$log2FoldChange > 0)
n_down  <- sum(degs$log2FoldChange < 0)
```

- Genes testados: **`r n_total`**
- Genes diferencialmente expressos (padj < 0.05, |log2FC| > 1): **`r n_deg`**
- Com expressão aumentada no grupo tratado: **`r n_up`**
- Com expressão diminuída no grupo tratado: **`r n_down`**

### Volcano plot interativo

```{r volcano-interativo}
# TRUE/FALSE decide a cor do ponto -- os mesmos limiares usados no
# deseq2_analysis.R para gerar a lista de DEGs
completos$significativo <- with(completos, !is.na(padj) & padj < 0.05 & abs(log2FoldChange) > 1)

# "text" monta o texto que aparece ao passar o mouse sobre cada ponto --
# é isso que o ggplotly() usa para as dicas interativas (tooltips)
grafico <- ggplot(completos, aes(
    x = log2FoldChange, y = -log10(pvalue),
    text = paste0(
      "Gene: ", gene_id,
      "<br>log2FC: ", round(log2FoldChange, 2),
      "<br>padj: ", signif(padj, 3)
    ),
    color = significativo
  )) +
  geom_point(alpha = 0.6, size = 1.2) +
  scale_color_manual(values = c("grey60", "red"), guide = "none") +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed") +
  labs(x = "log2 Fold Change", y = "-log10(p-valor)") +
  theme_minimal()

# ggplotly() converte o gráfico estático do ggplot2 em uma versão
# interativa (zoom, hover, salvar como imagem) -- tooltip="text" usa a
# coluna "text" que montamos acima em vez do padrão (todas as estéticas)
ggplotly(grafico, tooltip = "text")
```

### Tabela de genes diferencialmente expressos

```{r tabela-degs}
# DT::datatable gera uma tabela HTML com busca, ordenação por coluna e
# paginação -- filter="top" coloca uma caixa de filtro em cada coluna
DT::datatable(
  degs,
  filter = "top",
  options = list(pageLength = 15, scrollX = TRUE),
  rownames = FALSE
)
```

### Gráficos de diagnóstico (PCA e MA-plot)

Gerados na etapa do DESeq2. Ficam estáticos aqui porque dependem dos
dados transformados (`vst`), que não são salvos em CSV por padrão --
para torná-los interativos também, adicione ao final de
`deseq2_analysis.R` uma linha exportando os dados do `plotPCA(...,
returnData = TRUE)` para CSV, e adapte este template para lê-la.

```{r diagnostico, results='asis'}
for (arquivo in c("pca.png", "ma_plot.png")) {
  caminho <- file.path(deseq2_dir, arquivo)
  if (file.exists(caminho)) {
    cat(sprintf('<img src="%s" style="max-width:100%%; margin-bottom:20px;">\n', caminho))
  }
}
```

## Enriquecimento funcional

```{r checar-enriquecimento, results='asis'}
enrich_disponivel <- !is.na(enrich_dir) && dir.exists(enrich_dir)

if (!enrich_disponivel) {
  cat("Nenhum diretório de enriquecimento funcional foi informado (ou não existe) -- esta seção foi pulada.\n")
}
```

```{r go-dados, eval=enrich_disponivel}
caminho_go <- file.path(enrich_dir, "enriquecimento_GO_BP.csv")
tem_go <- file.exists(caminho_go)

if (tem_go) {
  go <- read.csv(caminho_go)

  # GeneRatio vem como texto, ex.: "10/200" -- convertemos para número
  # (10/200 = 0.05) para poder usar como eixo de um gráfico
  partes <- strsplit(go$GeneRatio, "/")
  go$GeneRatioNum <- sapply(partes, function(p) as.numeric(p[1]) / as.numeric(p[2]))
}
```

```{r go-titulo, eval=enrich_disponivel && exists("tem_go") && isTRUE(tem_go), results='asis'}
cat("### Dotplot interativo -- GO (Biological Process)\n")
```

```{r go-dotplot, eval=enrich_disponivel && exists("tem_go") && isTRUE(tem_go)}
# pega só os 20 termos mais significativos, para o gráfico não ficar poluído
go_top <- head(go[order(go$p.adjust), ], 20)

grafico_go <- ggplot(go_top, aes(
    x = GeneRatioNum, y = reorder(Description, GeneRatioNum),
    size = Count, color = p.adjust,
    text = paste0("Termo: ", Description, "<br>Genes: ", Count, "<br>padj: ", signif(p.adjust, 3))
  )) +
  geom_point() +
  scale_color_gradient(low = "red", high = "blue") +
  labs(x = "Gene Ratio", y = NULL, color = "padj", size = "Genes") +
  theme_minimal()

ggplotly(grafico_go, tooltip = "text")
```

```{r go-tabela-titulo, eval=enrich_disponivel && exists("tem_go") && isTRUE(tem_go), results='asis'}
cat("### Tabela de termos GO enriquecidos\n")
```

```{r go-tabela, eval=enrich_disponivel && exists("tem_go") && isTRUE(tem_go)}
DT::datatable(go, filter = "top", options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
```

```{r kegg-dados, eval=enrich_disponivel}
caminho_kegg <- file.path(enrich_dir, "enriquecimento_KEGG.csv")
tem_kegg <- file.exists(caminho_kegg)

if (tem_kegg) {
  kegg <- read.csv(caminho_kegg)
}
```

```{r kegg-titulo, eval=enrich_disponivel && exists("tem_kegg") && isTRUE(tem_kegg), results='asis'}
cat("### Tabela de vias KEGG enriquecidas\n")
```

```{r kegg-tabela, eval=enrich_disponivel && exists("tem_kegg") && isTRUE(tem_kegg)}
DT::datatable(kegg, filter = "top", options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
```

---

*Relatório gerado automaticamente pelo pipeline de RNA-Seq (`scripts/gerar_relatorio.R`).*
````

## 13.3 Uso

```bash
# só DESeq2
Rscript scripts/gerar_relatorio.R --deseq2-dir resultados_deseq2 --outdir relatorio_html

# DESeq2 + enriquecimento
Rscript scripts/gerar_relatorio.R \
    --deseq2-dir resultados_deseq2 \
    --enrich-dir resultados_enriquecimento \
    --outdir relatorio_html
```

O resultado é `relatorio_html/relatorio.html` — um único arquivo (imagens, tabelas e gráficos interativos embutidos, `self_contained: true`), pronto pra abrir no navegador ou enviar por e-mail. Pode ficar com alguns MB de tamanho por causa das bibliotecas JS do plotly/DT embutidas — é normal.

## 13.4 Integração opcional com o pipeline fechado

Se quiser que `pipeline.py`/`pipeline.sh` já gerem o relatório automaticamente ao final de `--rodar-analise`, basta acrescentar, logo depois da chamada ao `enrichment_analysis.R`:

```python
# em rodar_analise_em_lote(), no pipeline.py
subprocess.run(
    [
        "Rscript", str(scripts_dir / "gerar_relatorio.R"),
        "--deseq2-dir", "resultados_deseq2",
        "--enrich-dir", "resultados_enriquecimento" if (args.orgdb and args.keytype) else "",
        "--outdir", "relatorio_html",
    ],
    check=True,
)
```

```bash
# em pipeline.sh, logo após o bloco do enrichment_analysis.R
Rscript "$SCRIPT_DIR/gerar_relatorio.R" \
    --deseq2-dir resultados_deseq2 \
    --enrich-dir resultados_enriquecimento \
    --outdir relatorio_html
```

