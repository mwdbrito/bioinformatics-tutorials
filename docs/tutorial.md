# Pipeline de Pré-processamento de RNA-Seq
## Do GEO aos FASTQ limpos — com Bash e Python, para uma amostra e para várias

> **Objetivo:** sair de um projeto GEO (`GSE...`), identificar amostras e condições biológicas, relacioná-las aos `SRR`, baixar os dados, fazer controle de qualidade, remover adaptadores/bases de baixa qualidade e chegar a FASTQ prontos para alinhamento/quantificação.
>
> **O que mudou nesta versão:** para cada etapa automatizável (download, FastQC, trimming) agora existem **quatro variantes**: Bash para uma amostra, Python para uma amostra, Bash para várias amostras e Python para várias amostras. O pipeline final também aceita tanto `--srr UMA_AMOSTRA` quanto um sample sheet inteiro. A Parte 8.4 traz uma tabela-resumo com todos os comandos lado a lado.

Pensado para aulas práticas de Bioinformática. Cada etapa segue a mesma lógica: o que fazemos biologicamente → comando único → explicação → várias amostras em Bash → várias amostras em Python → cuidados comuns.

---

## Sumário

- **Parte 1** — Visão geral, identificadores GEO/SRA, preparação do ambiente
- **Parte 2** — Do GSE ao sample sheet (metadados, curadoria)
- **Parte 3** — Download (prefetch + fasterq-dump)
- **Parte 4** — Controle de qualidade (FastQC)
- **Parte 5** — Trimming (Cutadapt e Trim Galore)
- **Parte 6** — QC final e MultiQC
- **Parte 7** — Automatizando tudo em um único pipeline
- **Parte 8** — Boas práticas, checklist e tabela-resumo

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
FASTQ bruto ── FastQC ──┐
  │                      │
  ▼                      │
Trimming (Cutadapt / Trim Galore)
  │
  ▼
FASTQ limpo ── FastQC pós-trimming
  │
  ▼
Alinhamento / quantificação (fora do escopo deste tutorial)
```

**GEO, SRA, GSM, SRX e SRR não são a mesma coisa.**

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

> **Cuidado:** uma amostra `GSM` pode ter mais de um `SRR` — por exemplo, quando a mesma biblioteca foi sequenciada em mais de uma corrida. Nesse caso, os SRR extras são provavelmente **runs técnicos**, não réplicas biológicas. Por isso o sample sheet deve ser pensado como uma tabela de *runs*, não de GSMs.

```text
GSM10001    Controle    SRX20001    SRR30001
GSM10002    Controle    SRX20002    SRR30002
GSM10004    Tratado     SRX20004    SRR30004   ← mesma biblioteca
GSM10004    Tratado     SRX20004    SRR30005   ← run técnico extra
```

## 1.3 Preparando o ambiente

Testado em Linux/Ubuntu, WSL2, servidores Linux, containers Apptainer/Singularity e ambientes Conda/Mamba.

Ferramentas usadas: `Entrez Direct` (`esearch`, `efetch`, `xtract`), `SRA Toolkit` (`prefetch`, `vdb-validate`, `fasterq-dump`), `FastQC`, `Cutadapt`, `Trim Galore`, Python 3 + Pandas. Opcional: `MultiQC`, `pigz`.

Verificação rápida:

```bash
which esearch efetch xtract prefetch fasterq-dump fastqc cutadapt trim_galore
python3 --version
python3 -c "import pandas" && echo "pandas OK"
```

Se uma ferramenta não aparecer, ela não está no `PATH`.

## 1.4 Estrutura do projeto

```text
projeto_rnaseq/
├── metadados/     GSE_family.soft.gz, sample_sheet.csv, lista_srr.txt
├── sra/           objetos SRA baixados pelo prefetch
├── dados_brutos/  FASTQ bruto (SRRxxxx_1.fastq.gz / _2.fastq.gz)
├── dados_limpos/  FASTQ pós-trimming
├── qc_bruto/      relatórios FastQC do dado bruto
├── qc_limpo/      relatórios FastQC pós-trimming
├── logs/
└── scripts/
```

```bash
mkdir -p projeto_rnaseq/{metadados,sra,dados_brutos,dados_limpos,qc_bruto,qc_limpo,logs,scripts}
cd projeto_rnaseq
```

`mkdir -p` cria os diretórios sem reclamar se já existirem; `{a,b,c}` é expansão de chaves do Bash — equivale a rodar `mkdir -p` uma vez para cada pasta.

> Não jogue todos os arquivos em uma única pasta: um projeto de RNA-Seq real pode gerar centenas de arquivos rapidamente.

---

# Parte 2 — Do GSE ao sample sheet

## 2.1 Por que não sair direto para os SRR

Um erro comum é ensinar `GSE → SRR → download` direto. Isso resolve o problema computacional, mas cria um problema biológico: depois de baixar `SRR1234567`, como saber se é Controle ou Tratado? Por isso construímos um **sample sheet** que preserva GSM, título, características e condição junto com o SRR.

Também evite usar só:

```bash
esearch -db sra -query "GSE123456" | efetch -format runinfo
```

Esse comando é ótimo para obter rapidamente uma lista de SRR, mas **não é a fonte confiável da descrição biológica original do GSM** — essa vive nos metadados próprios do GEO (formato SOFT). Use-o quando só precisar de uma lista de runs; use o SOFT quando precisar saber "qual é controle e qual é tratamento".

## 2.2 Baixando os metadados (SOFT) do GEO

O NCBI organiza os arquivos por prefixo de milhar do acesso. Para `GSE123456`, o caminho é `GSE123nnn/GSE123456/`. Calculando isso em Bash:

```bash
GSE="GSE123456"
PREFIXO="${GSE:0:${#GSE}-3}nnn"

wget -O metadados/${GSE}_family.soft.gz \
  "https://ftp.ncbi.nlm.nih.gov/geo/series/${PREFIXO}/${GSE}/soft/${GSE}_family.soft.gz"
```

Para outro GSE, troque a variável `GSE` — o prefixo é calculado automaticamente. O script Python da seção 2.4 já faz isso por conta própria; o comando acima serve para quando você quiser inspecionar o SOFT manualmente antes de automatizar.

## 2.3 Estrutura do formato SOFT

```bash
zcat metadados/GSE123456_family.soft.gz | head -n 40
```

Você verá blocos como:

```text
^SAMPLE = GSM1234567
!Sample_title = Arabidopsis wild-type control
!Sample_source_name_ch1 = leaf
!Sample_organism_ch1 = Arabidopsis thaliana
!Sample_characteristics_ch1 = genotype: wild type
!Sample_characteristics_ch1 = treatment: control
!Sample_relation = SRA: https://www.ncbi.nlm.nih.gov/sra?term=SRX123456
```

`^` inicia uma entidade (ex.: `^SAMPLE = GSM...`), `!` marca um atributo dessa entidade, `#` indica descrições de colunas de tabela. Um `grep '^!Sample_title ='` isolado funciona para inspeção rápida, mas perde a associação entre título e GSM — por isso escrevemos um parser (seção 2.4) em vez de encadear `grep`/`sed`.

## 2.4 Script: obtendo o sample sheet a partir do GEO

Separamos responsabilidades: **Bash** é ótimo para arquivos, diretórios e execução de programas; **Python** é ótimo para tabelas, regras de curadoria e validação. O script abaixo aceita **um ou vários GSE de uma vez** — útil quando você está combinando mais de um experimento no mesmo sample sheet.

`scripts/01_geo_to_sample_sheet.py`:

```python
#!/usr/bin/env python3
"""
Extrai metadados do GEO (arquivo SOFT) e monta um sample sheet com uma
linha por SRR (run de sequenciamento).

Uso -- um único GSE:
    python3 scripts/01_geo_to_sample_sheet.py GSE123456

Uso -- vários GSE de uma vez (ex.: combinando dois experimentos):
    python3 scripts/01_geo_to_sample_sheet.py GSE123456 GSE987654 \
        --output metadados/sample_sheet.csv
"""

import argparse
import csv
import gzip
import re
import subprocess
import sys
from pathlib import Path


def geo_prefix(gse):
    """Converte GSE123456 em GSE123nnn."""
    return gse[:-3] + "nnn"


def download_soft(gse, output):
    """Baixa o arquivo Series Family SOFT do GEO para um GSE."""
    prefix = geo_prefix(gse)
    url = (
        f"https://ftp.ncbi.nlm.nih.gov/geo/series/"
        f"{prefix}/{gse}/soft/{gse}_family.soft.gz"
    )
    print(f"[INFO] Download do SOFT de {gse}:\n{url}")
    subprocess.run(["wget", "-O", str(output), url], check=True)


def parse_soft(soft_file):
    """
    Lê os blocos ^SAMPLE do SOFT e extrai GSM, título, características
    e a relação com o SRA (SRX).
    """
    samples = []
    current = None
    opener = gzip.open if str(soft_file).endswith(".gz") else open

    with opener(soft_file, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")

            if line.startswith("^SAMPLE = "):
                if current is not None:
                    samples.append(current)
                gsm = line.split("=", 1)[1].strip()
                current = {"GSM": gsm, "Title": "", "Characteristics": [], "SRX": []}
                continue

            if current is None:
                continue

            if line.startswith("!Sample_title = "):
                current["Title"] = line.split("=", 1)[1].strip()
            elif line.startswith("!Sample_characteristics"):
                current["Characteristics"].append(line.split("=", 1)[1].strip())
            elif line.startswith("!Sample_relation = "):
                value = line.split("=", 1)[1].strip()
                if value.startswith("SRA:"):
                    match = re.search(r"(SRX\d+)", value)
                    if match:
                        current["SRX"].append(match.group(1))

        if current is not None:
            samples.append(current)

    return samples


def runinfo_from_srx(srx_list):
    """Usa Entrez Direct (efetch) para descobrir os SRR associados aos SRX."""
    if not srx_list:
        return []

    ids = ",".join(sorted(set(srx_list)))
    result = subprocess.run(
        ["efetch", "-db", "sra", "-id", ids, "-format", "runinfo"],
        capture_output=True, text=True, check=True,
    )

    lines = result.stdout.strip().splitlines()
    if len(lines) < 2:
        return []

    return list(csv.DictReader(lines))


def montar_linhas(samples, gse):
    """Constrói as linhas (uma por SRR) para um único GSE já processado."""
    all_srx = [srx for s in samples for srx in s["SRX"]]
    print(f"[INFO] {gse}: {len(set(all_srx))} SRX encontrados.")

    runinfo = runinfo_from_srx(all_srx)

    srx_to_runs = {}
    for row in runinfo:
        srx = row.get("Experiment", "").strip()
        srr = row.get("Run", "").strip()
        if srx and srr:
            srx_to_runs.setdefault(srx, []).append(row)

    linhas = []
    for sample in samples:
        characteristics = " | ".join(sample["Characteristics"])
        for srx in sample["SRX"]:
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
    """Garante o SOFT em disco (baixando se necessário) e retorna as linhas do sample sheet."""
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

Executando:

```bash
# um GSE
python3 scripts/01_geo_to_sample_sheet.py GSE123456

# vários GSE combinados num único sample sheet
python3 scripts/01_geo_to_sample_sheet.py GSE123456 GSE987654
```

Resultado esperado (`metadados/sample_sheet.csv`):

```text
GSE,GSM,SRX,SRR,Title,Characteristics,Layout,Platform,Model,ScientificName
GSE123456,GSM10001,SRX20001,SRR30001,WT control,genotype: WT | treatment: control,PAIRED,ILLUMINA,NovaSeq 6000,Arabidopsis thaliana
GSE123456,GSM10002,SRX20002,SRR30002,WT control,genotype: WT | treatment: control,PAIRED,ILLUMINA,NovaSeq 6000,Arabidopsis thaliana
GSE123456,GSM10003,SRX20003,SRR30003,Mannitol treatment,treatment: 250 mM mannitol,PAIRED,ILLUMINA,NovaSeq 6000,Arabidopsis thaliana
```

## 2.5 Curadoria da condição biológica

O arquivo acima preserva a informação original — de propósito. Transformar `treatment: 250 mM mannitol` em `Tratado` é uma decisão do pesquisador, não algo que devemos automatizar cegamente sem checar o desenho experimental no GEO.

`scripts/02_curar_sample_sheet.py` (ajuste os padrões de texto para o seu experimento):

```python
import pandas as pd

df = pd.read_csv("metadados/sample_sheet.csv")

print("\nAmostras encontradas:")
print(df[["GSM", "SRR", "Title", "Characteristics"]].to_string(index=False))

# IMPORTANTE: os padrões abaixo são só um exemplo didático.
# Confira sempre o desenho experimental original no GEO antes de rotular.
df["Condicao"] = ""
df.loc[
    df["Characteristics"].str.contains("control|untreated|wild.type control", case=False, na=False),
    "Condicao",
] = "Controle"
df.loc[
    df["Characteristics"].str.contains("mannitol|treated|treatment", case=False, na=False),
    "Condicao",
] = "Tratado"

print("\nDistribuição das condições:")
print(df["Condicao"].value_counts(dropna=False))

df.to_csv("metadados/sample_sheet_curado.csv", index=False)
df[["SRR"]].drop_duplicates().to_csv("metadados/lista_srr.txt", index=False, header=False)
df[["SRR", "Condicao"]].to_csv("metadados/srr_condicao.csv", index=False)

print("\nArquivos gerados: sample_sheet_curado.csv, lista_srr.txt, srr_condicao.csv")
```

Se preferir curar manualmente (planilhas pequenas), basta editar a coluna `Condicao` do CSV em qualquer editor e pular este script.

> **`header=False` no `lista_srr.txt` importa:** se o cabeçalho `SRR` ficasse na primeira linha, um loop `while read` tentaria baixar um "run" chamado `SRR`. Se você já tem um CSV simples sem aspas internas, `cut -d ',' -f 1 tabela.csv | tail -n +2` também funciona — mas `cut` não é um parser CSV completo (quebra com vírgulas dentro de aspas), então para dados reais prefira Pandas.

## 2.6 Validando o sample sheet antes de prosseguir

```bash
python3 - <<'PY'
import pandas as pd

df = pd.read_csv("metadados/sample_sheet_curado.csv")

print("Linhas:", len(df))
print("\nCondições:")
print(df["Condicao"].value_counts())
print("\nSRR duplicados:")
print(df[df["SRR"].duplicated(keep=False)][["GSM", "SRX", "SRR", "Condicao"]])
print("\nValores ausentes:")
print(df.isna().sum())
print("\nAmostras biológicas por condição (GSM únicos, não SRR):")
print(df.groupby("Condicao")["GSM"].nunique())
PY
```

O último `print` é o mais importante: conte **GSM únicos**, não linhas de `SRR`. Se um GSM tiver dois SRR (runs técnicos da mesma biblioteca), contar SRR infla artificialmente o número de réplicas biológicas — o que compromete qualquer análise estatística posterior (ex.: DESeq2).

---

# Parte 3 — Download (SRA Toolkit)

## 3.1 Conceito

O SRA Toolkit separa **download** (`prefetch`, que baixa o objeto SRA e permite retomar downloads incompletos) de **conversão** (`fasterq-dump`, que gera o FASTQ). `vdb-validate` confere a integridade do objeto entre as duas etapas.

> Este tutorial assume bibliotecas **paired-end** (`Layout = PAIRED` na sample sheet). Para single-end, remova `-A`/`-p` (Cutadapt) e o segundo arquivo dos comandos — `fasterq-dump --split-files` gerará só um FASTQ nesse caso.

## 3.2 Amostra única — Bash

```bash
prefetch SRR30001

fasterq-dump SRR30001 \
    --split-files \
    --threads 4 \
    --outdir dados_brutos

gzip dados_brutos/SRR30001_*.fastq   # fasterq-dump não comprime sozinho
```

`--split-files` separa paired-end em `_1`/`_2`; `--threads`/`-e` controla paralelismo; `--outdir`/`-O` define o destino.

## 3.3 Amostra única — Python

`scripts/baixar_amostra.py`:

```python
#!/usr/bin/env python3
"""
Baixa e converte uma única amostra SRA para FASTQ.

Uso:
    python3 scripts/baixar_amostra.py SRR30001
    python3 scripts/baixar_amostra.py SRR30001 --threads 8
"""

import argparse
import subprocess
from pathlib import Path


def _run_com_retry(cmd, tentativas=3):
    """Executa um comando de rede (prefetch) com algumas tentativas."""
    ultimo_erro = None
    for tentativa in range(1, tentativas + 1):
        try:
            subprocess.run(cmd, check=True)
            return
        except subprocess.CalledProcessError as e:
            ultimo_erro = e
            print(f"[AVISO] tentativa {tentativa}/{tentativas} falhou: {' '.join(map(str, cmd))}")
    raise ultimo_erro


def baixar_srr(srr, sra_dir="sra", fastq_dir="dados_brutos", threads=4, pular_se_existir=True):
    """
    Baixa (prefetch), valida (vdb-validate) e converte (fasterq-dump)
    um único SRR para FASTQ pareado, já comprimido.

    Retorna (caminho_r1, caminho_r2).
    """
    sra_dir = Path(sra_dir)
    fastq_dir = Path(fastq_dir)
    sra_dir.mkdir(parents=True, exist_ok=True)
    fastq_dir.mkdir(parents=True, exist_ok=True)

    r1 = fastq_dir / f"{srr}_1.fastq.gz"
    r2 = fastq_dir / f"{srr}_2.fastq.gz"

    if pular_se_existir and r1.exists() and r2.exists():
        print(f"[SKIP] {srr} já baixado, pulando.")
        return r1, r2

    print(f"[1/3] prefetch {srr}")
    _run_com_retry(["prefetch", srr, "--output-directory", str(sra_dir)])

    sra_path = sra_dir / srr

    print(f"[2/3] vdb-validate {srr}")
    subprocess.run(["vdb-validate", str(sra_path)], check=True)

    print(f"[3/3] fasterq-dump {srr}")
    subprocess.run(
        [
            "fasterq-dump", str(sra_path),
            "--split-files", "--threads", str(threads),
            "--outdir", str(fastq_dir),
        ],
        check=True,
    )

    for fq in fastq_dir.glob(f"{srr}_*.fastq"):
        subprocess.run(["gzip", "-f", str(fq)], check=True)

    return r1, r2


def main():
    parser = argparse.ArgumentParser(description="Baixa uma única amostra SRA/SRR.")
    parser.add_argument("srr", help="Accession do run, ex: SRR30001")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--sra-dir", default="sra")
    parser.add_argument("--fastq-dir", default="dados_brutos")
    parser.add_argument("--forcar", action="store_true", help="Baixa de novo mesmo se já existir.")
    args = parser.parse_args()

    r1, r2 = baixar_srr(
        args.srr,
        sra_dir=args.sra_dir,
        fastq_dir=args.fastq_dir,
        threads=args.threads,
        pular_se_existir=not args.forcar,
    )
    print(f"[OK] {args.srr} -> {r1}, {r2}")


if __name__ == "__main__":
    main()
```

Note dois pontos que o Bash puro não dá de graça: **retry automático** no `prefetch` (rede é a parte mais instável do processo) e **pular download se o FASTQ já existir** (`pular_se_existir`), o que torna o script seguro para rodar de novo depois de uma interrupção.

## 3.4 Várias amostras — Bash

`scripts/02_download.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

LISTA="metadados/lista_srr.txt"
OUTDIR="dados_brutos"
SRA_DIR="sra"
THREADS=4

mkdir -p "$OUTDIR" "$SRA_DIR"

while IFS= read -r srr; do
    [[ -z "$srr" ]] && continue

    echo
    echo "=========================================="
    echo "Processando: $srr"
    echo "=========================================="

    if [[ -f "$OUTDIR/${srr}_1.fastq.gz" && -f "$OUTDIR/${srr}_2.fastq.gz" ]]; then
        echo "[SKIP] $srr já baixado."
        continue
    fi

    echo "[1/3] Prefetch"
    prefetch "$srr" --output-directory "$SRA_DIR"

    echo "[2/3] Validação"
    vdb-validate "$SRA_DIR/$srr"

    echo "[3/3] Conversão para FASTQ"
    fasterq-dump "$SRA_DIR/$srr" --split-files --threads "$THREADS" --outdir "$OUTDIR"
    gzip -f "$OUTDIR/${srr}_1.fastq" "$OUTDIR/${srr}_2.fastq"

    echo "[OK] $srr concluído"
done < "$LISTA"

echo
echo "Download finalizado."
```

```bash
chmod +x scripts/02_download.sh
scripts/02_download.sh
```

Preferimos `while IFS= read -r srr; do ... done < arquivo.txt` a `for srr in $(cat arquivo.txt)`: o `while read` lida corretamente com espaços/linhas especiais e é mais robusto para um curso.

Por padrão o `set -euo pipefail` interrompe tudo na primeira falha — ótimo para depurar, ruim para um lote grande de 50 amostras onde uma falha de rede não deveria derrubar as outras 49. Se quiser continuar mesmo com falhas, troque o corpo do loop por:

```bash
    if ! (prefetch "$srr" --output-directory "$SRA_DIR" \
          && vdb-validate "$SRA_DIR/$srr" \
          && fasterq-dump "$SRA_DIR/$srr" --split-files --threads "$THREADS" --outdir "$OUTDIR"); then
        echo "[ERRO] $srr falhou, pulando para a próxima." >&2
        continue
    fi
```

## 3.5 Várias amostras — Python

`scripts/baixar_lote.py` — reaproveita `baixar_srr()` em vez de duplicar a lógica:

```python
#!/usr/bin/env python3
"""
Baixa várias amostras a partir de uma lista de SRR (uma por linha)
ou de um sample sheet CSV com coluna 'SRR'.

Uso:
    python3 scripts/baixar_lote.py metadados/lista_srr.txt
    python3 scripts/baixar_lote.py metadados/sample_sheet_curado.csv --threads 8
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from baixar_amostra import baixar_srr  # noqa: E402


def carregar_lista_srr(caminho):
    caminho = Path(caminho)

    if caminho.suffix.lower() == ".csv":
        df = pd.read_csv(caminho)
        return df["SRR"].dropna().astype(str).str.strip().tolist()

    with open(caminho, encoding="utf-8") as f:
        return [linha.strip() for linha in f if linha.strip()]


def main():
    parser = argparse.ArgumentParser(description="Baixa várias amostras SRA/SRR.")
    parser.add_argument("lista", help="lista_srr.txt (uma por linha) ou sample_sheet.csv (coluna SRR)")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--keep-going", action="store_true", help="Não interrompe se uma amostra falhar.")
    args = parser.parse_args()

    srrs = carregar_lista_srr(args.lista)
    print(f"[INFO] {len(srrs)} amostras encontradas.")

    falhas = []
    for i, srr in enumerate(srrs, start=1):
        print(f"\n=== [{i}/{len(srrs)}] {srr} ===")
        try:
            baixar_srr(srr, threads=args.threads)
        except Exception as e:
            print(f"[ERRO] {srr}: {e}")
            falhas.append(srr)
            if not args.keep_going:
                sys.exit(f"Interrompido em {srr}. Use --keep-going para pular falhas.")

    ok = len(srrs) - len(falhas)
    print(f"\nConcluído: {ok} ok, {len(falhas)} falharam.")
    if falhas:
        print("Falharam:", ", ".join(falhas))


if __name__ == "__main__":
    main()
```

A vantagem sobre o loop Bash: o mesmo script aceita tanto `lista_srr.txt` quanto o `sample_sheet_curado.csv` diretamente (detecta pela extensão), e o `--keep-going` dá controle explícito sobre parar ou continuar em caso de erro — sem precisar reescrever a estrutura do loop.

## 3.6 Cuidados com espaço em disco

Durante `SRA → FASTQ` você pode ter simultaneamente o arquivo `.sra`, o FASTQ temporário e o FASTQ final — `fasterq-dump` usa bastante espaço temporário. Antes de rodar um lote grande:

```bash
df -h        # espaço livre no filesystem
du -sh .     # espaço já usado pelo projeto
nproc        # quantos CPUs existem, para dimensionar --threads
```

Mais threads não é sempre proporcionalmente mais rápido — o gargalo real costuma ser disco, rede ou I/O, não CPU.

Se `pigz` estiver disponível, `pigz -p 4 dados_brutos/*.fastq` comprime em paralelo, mais rápido que `gzip` puro.

---

# Parte 4 — Controle de qualidade (FastQC)

## 4.1 O que o FastQC avalia

Qualidade por base e por sequência, distribuição de GC, comprimento das reads, conteúdo de bases, duplicação, sequências super-representadas e possíveis adaptadores. Gera `*_fastqc.html` e `*_fastqc.zip`.

## 4.2 Amostra única — Bash

```bash
fastqc \
    dados_brutos/SRR30001_1.fastq.gz \
    dados_brutos/SRR30001_2.fastq.gz \
    --threads 4 \
    --outdir qc_bruto
```

## 4.3 Amostra única — Python

`scripts/fastqc_amostra.py`:

```python
#!/usr/bin/env python3
"""FastQC para uma amostra paired-end (R1 + R2)."""

import argparse
import subprocess
from pathlib import Path


def rodar_fastqc(arquivos, outdir="qc_bruto", threads=4):
    """Roda o FastQC em uma lista de arquivos FASTQ, em uma única chamada."""
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["fastqc", *[str(a) for a in arquivos], "--threads", str(threads), "--outdir", str(outdir)],
        check=True,
    )


def main():
    parser = argparse.ArgumentParser(description="FastQC de uma amostra paired-end.")
    parser.add_argument("srr")
    parser.add_argument("--dados", default="dados_brutos")
    parser.add_argument("--outdir", default="qc_bruto")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    r1 = Path(args.dados) / f"{args.srr}_1.fastq.gz"
    r2 = Path(args.dados) / f"{args.srr}_2.fastq.gz"
    rodar_fastqc([r1, r2], outdir=args.outdir, threads=args.threads)
    print(f"[OK] FastQC de {args.srr} em {args.outdir}")


if __name__ == "__main__":
    main()
```

## 4.4 Várias amostras — Bash

A forma mais simples e mais eficiente é **uma única chamada com glob**, não um loop chamando `fastqc` várias vezes:

```bash
fastqc dados_brutos/*.fastq.gz --threads 8 --outdir qc_bruto
```

O FastQC já paraleliza internamente com `--threads`. Se precisar processar só as amostras de uma lista específica (não todo o diretório):

```bash
mapfile -t arquivos < <(while read -r srr; do
    echo "dados_brutos/${srr}_1.fastq.gz"
    echo "dados_brutos/${srr}_2.fastq.gz"
done < metadados/lista_srr.txt)

fastqc "${arquivos[@]}" --threads 8 --outdir qc_bruto
```

## 4.5 Várias amostras — Python

`scripts/fastqc_lote.py` — reaproveita `rodar_fastqc()` e junta tudo em uma única chamada, pelo mesmo motivo do item 4.4:

```python
#!/usr/bin/env python3
"""
FastQC para várias amostras de uma só vez.

Em vez de chamar `fastqc` uma vez por amostra (mais lento, reabre o programa
a cada chamada), juntamos todos os arquivos em uma única chamada e deixamos
o --threads paralelizar internamente.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from fastqc_amostra import rodar_fastqc  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="FastQC em lote.")
    parser.add_argument("lista", help="Arquivo com um SRR por linha")
    parser.add_argument("--dados", default="dados_brutos")
    parser.add_argument("--outdir", default="qc_bruto")
    parser.add_argument("--threads", type=int, default=8)
    args = parser.parse_args()

    with open(args.lista, encoding="utf-8") as f:
        srrs = [linha.strip() for linha in f if linha.strip()]

    arquivos = []
    for srr in srrs:
        arquivos.append(Path(args.dados) / f"{srr}_1.fastq.gz")
        arquivos.append(Path(args.dados) / f"{srr}_2.fastq.gz")

    rodar_fastqc(arquivos, outdir=args.outdir, threads=args.threads)
    print(f"[OK] FastQC de {len(srrs)} amostras em {args.outdir}")


if __name__ == "__main__":
    main()
```

## 4.6 Como interpretar o relatório

Não ensine o aluno a só procurar `PASS`/`FAIL`. O FastQC é uma ferramenta de diagnóstico: um módulo em vermelho não significa automaticamente "a amostra está ruim" — conteúdo de GC, duplicação e conteúdo de bases podem ter padrões esperados dependendo do organismo e do tipo de biblioteca. Interprete sempre `FastQC + tipo de biblioteca + organismo + protocolo + desenho experimental` em conjunto.

No relatório bruto, olhe principalmente: *Per base sequence quality* (qualidade cai muito nas pontas?), *Adapter content* (há evidência de adaptador?), *Sequence length* (compatível com o protocolo?), *GC content* (plausível para o organismo?) e *Overrepresented sequences*. Depois do trimming, espera-se adaptadores e bases ruins em queda — mas trimming excessivo também destrói informação, então "quanto mais trimming, melhor" é um mito a evitar.

---

# Parte 5 — Trimming (Cutadapt e Trim Galore)

## 5.1 Cutadapt — conceito e parâmetros

| Flag | Significado |
|---|---|
| `-a SEQ` | Adaptador da read 1 |
| `-A SEQ` | Adaptador da read 2 (paired-end) |
| `-q 20` | Quality trimming em Phred 20 (remove bases ruins nas pontas) |
| `-m 20` | Descarta reads menores que 20 bases após o corte |
| `-o arquivo` | Saída da read 1 |
| `-p arquivo` | Saída da read 2 |

## 5.2 Cutadapt — amostra única — Bash

```bash
cutadapt \
    -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
    -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
    -q 20 -m 20 \
    -o dados_limpos/SRR30001_1.fastq.gz \
    -p dados_limpos/SRR30001_2.fastq.gz \
    dados_brutos/SRR30001_1.fastq.gz \
    dados_brutos/SRR30001_2.fastq.gz
```

## 5.3 Cutadapt — amostra única — Python

`scripts/cutadapt_amostra.py`:

```python
#!/usr/bin/env python3
"""Cutadapt para uma amostra paired-end."""

import argparse
import subprocess
from pathlib import Path

# Sequências de exemplo (Illumina TruSeq). Confira o adaptador real do seu
# protocolo/kit antes de usar em dados reais -- ver seção 5.5.
ADAPTER_R1 = "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
ADAPTER_R2 = "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"


def rodar_cutadapt(r1, r2, out_r1, out_r2, qualidade=20, tam_min=20,
                    adapter_r1=ADAPTER_R1, adapter_r2=ADAPTER_R2):
    Path(out_r1).parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "cutadapt",
            "-a", adapter_r1, "-A", adapter_r2,
            "-q", str(qualidade), "-m", str(tam_min),
            "-o", str(out_r1), "-p", str(out_r2),
            str(r1), str(r2),
        ],
        check=True,
    )


def main():
    parser = argparse.ArgumentParser(description="Cutadapt para uma amostra paired-end.")
    parser.add_argument("srr")
    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    parser.add_argument("--qualidade", type=int, default=20)
    parser.add_argument("--tam-min", type=int, default=20)
    args = parser.parse_args()

    r1 = Path(args.brutos) / f"{args.srr}_1.fastq.gz"
    r2 = Path(args.brutos) / f"{args.srr}_2.fastq.gz"
    out_r1 = Path(args.limpos) / f"{args.srr}_1.fastq.gz"
    out_r2 = Path(args.limpos) / f"{args.srr}_2.fastq.gz"

    rodar_cutadapt(r1, r2, out_r1, out_r2, qualidade=args.qualidade, tam_min=args.tam_min)
    print(f"[OK] Cutadapt de {args.srr} em {args.limpos}")


if __name__ == "__main__":
    main()
```

## 5.4 Cutadapt — várias amostras — Bash e Python

Bash:

```bash
while read -r srr; do
    echo "Cutadapt: $srr"
    cutadapt \
        -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
        -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
        -q 20 -m 20 \
        -o dados_limpos/${srr}_1.fastq.gz \
        -p dados_limpos/${srr}_2.fastq.gz \
        dados_brutos/${srr}_1.fastq.gz \
        dados_brutos/${srr}_2.fastq.gz
done < metadados/lista_srr.txt
```

Python — `scripts/cutadapt_lote.py`, reaproveitando `rodar_cutadapt()`:

```python
#!/usr/bin/env python3
"""Cutadapt para várias amostras, reaproveitando rodar_cutadapt()."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from cutadapt_amostra import rodar_cutadapt  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="Cutadapt em lote.")
    parser.add_argument("lista", help="Arquivo com um SRR por linha")
    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    args = parser.parse_args()

    with open(args.lista, encoding="utf-8") as f:
        srrs = [linha.strip() for linha in f if linha.strip()]

    for srr in srrs:
        print(f"Cutadapt: {srr}")
        r1 = Path(args.brutos) / f"{srr}_1.fastq.gz"
        r2 = Path(args.brutos) / f"{srr}_2.fastq.gz"
        out_r1 = Path(args.limpos) / f"{srr}_1.fastq.gz"
        out_r2 = Path(args.limpos) / f"{srr}_2.fastq.gz"
        rodar_cutadapt(r1, r2, out_r1, out_r2)

    print(f"[OK] {len(srrs)} amostras processadas.")


if __name__ == "__main__":
    main()
```

## 5.5 Cuidado: adaptador não é universal

Nunca ensine "use sempre esta sequência". O adaptador depende da plataforma, do kit e do protocolo — verifique a documentação do estudo, o relatório FastQC (*Adapter content*) e a possibilidade de múltiplos adaptadores antes de rodar em dados reais. As sequências usadas acima são um exemplo didático comum da Illumina, não uma receita universal.

## 5.6 Trim Galore — conceito

O Trim Galore automatiza várias tarefas de trimming usando o Cutadapt por baixo. `--paired` sincroniza R1/R2; `--cores` paraleliza; `--fastqc` roda o FastQC automaticamente após o corte. Rode `trim_galore --help` e `trim_galore --version` sempre que possível — opções mudam entre versões.

## 5.7 Trim Galore — amostra única — Bash

```bash
trim_galore \
    --paired \
    --cores 4 \
    --fastqc \
    --output_dir dados_limpos \
    dados_brutos/SRR30001_1.fastq.gz \
    dados_brutos/SRR30001_2.fastq.gz
```

## 5.8 Trim Galore — amostra única — Python

`scripts/trim_galore_amostra.py`:

```python
#!/usr/bin/env python3
"""Trim Galore para uma amostra paired-end."""

import argparse
import subprocess
from pathlib import Path


def rodar_trim_galore(r1, r2, outdir="dados_limpos", threads=4, fastqc=True):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    cmd = ["trim_galore", "--paired", "--cores", str(threads), "--output_dir", str(outdir)]
    if fastqc:
        cmd.append("--fastqc")
    cmd += [str(r1), str(r2)]

    subprocess.run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser(description="Trim Galore para uma amostra paired-end.")
    parser.add_argument("srr")
    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    r1 = Path(args.brutos) / f"{args.srr}_1.fastq.gz"
    r2 = Path(args.brutos) / f"{args.srr}_2.fastq.gz"

    rodar_trim_galore(r1, r2, outdir=args.limpos, threads=args.threads)
    print(f"[OK] Trim Galore de {args.srr} em {args.limpos}")


if __name__ == "__main__":
    main()
```

## 5.9 Trim Galore — várias amostras — Bash e Python

Bash:

```bash
while read -r srr; do
    echo "Trimming: $srr"
    trim_galore \
        --paired --cores 4 --fastqc \
        --output_dir dados_limpos \
        dados_brutos/${srr}_1.fastq.gz \
        dados_brutos/${srr}_2.fastq.gz
done < metadados/lista_srr.txt
```

Python — `scripts/trim_galore_lote.py`:

```python
#!/usr/bin/env python3
"""Trim Galore para várias amostras, reaproveitando rodar_trim_galore()."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from trim_galore_amostra import rodar_trim_galore  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="Trim Galore em lote.")
    parser.add_argument("lista", help="Arquivo com um SRR por linha")
    parser.add_argument("--brutos", default="dados_brutos")
    parser.add_argument("--limpos", default="dados_limpos")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    with open(args.lista, encoding="utf-8") as f:
        srrs = [linha.strip() for linha in f if linha.strip()]

    for srr in srrs:
        print(f"Trim Galore: {srr}")
        r1 = Path(args.brutos) / f"{srr}_1.fastq.gz"
        r2 = Path(args.brutos) / f"{srr}_2.fastq.gz"
        rodar_trim_galore(r1, r2, outdir=args.limpos, threads=args.threads)

    print(f"[OK] {len(srrs)} amostras processadas.")


if __name__ == "__main__":
    main()
```

## 5.10 Cutadapt vs Trim Galore

| Característica | Cutadapt | Trim Galore |
|---|---|---|
| Controle fino | Excelente | Bom |
| Fácil para iniciantes | Médio | Excelente |
| Usa Cutadapt por baixo | — | Sim |
| FastQC integrado | Não | Sim (`--fastqc`) |
| Ideal para | Entender os conceitos | Rodar o pipeline no dia a dia |

Ensine Cutadapt primeiro (para entender adaptador, quality trimming, minimum length); depois mostre que `trim_galore --paired` automatiza exatamente isso.

---

# Parte 6 — QC final e MultiQC

## 6.1 FastQC pós-trimming

Reaproveita a mesma função `rodar_fastqc()` da Parte 4 — só muda o diretório de entrada/saída.

```bash
# uma amostra
fastqc dados_limpos/SRR30001_1_val_1.fq.gz dados_limpos/SRR30001_2_val_2.fq.gz \
    --threads 4 --outdir qc_limpo

# várias amostras
fastqc dados_limpos/*.fq.gz --threads 8 --outdir qc_limpo
```

```bash
python3 scripts/fastqc_amostra.py SRR30001 --dados dados_limpos --outdir qc_limpo
python3 scripts/fastqc_lote.py metadados/lista_srr.txt --dados dados_limpos --outdir qc_limpo
```

## 6.2 MultiQC

```bash
multiqc qc_bruto -o qc_bruto/multiqc
multiqc qc_limpo -o qc_limpo/multiqc
```

Em vez de abrir 20 HTMLs individuais, o aluno abre um único relatório consolidado.

---

# Parte 7 — Automatizando tudo em um único pipeline

## 7.1 Pipeline em Python — amostra única OU lote

`scripts/pipeline.py` funciona nos dois modos: `--srr` para uma amostra isolada, `--sample-sheet` para o CSV inteiro. Reaproveita a mesma lógica de download/QC/trimming das partes anteriores, agora com log estruturado (`logging`), pular download se já existir, e `--keep-going` para lotes grandes.

```python
#!/usr/bin/env python3
"""
Pipeline completo de pré-processamento de RNA-Seq: SRA -> FASTQ limpo.

Funciona em dois modos:

  1) Uma única amostra:
        python3 pipeline.py --srr SRR30001 --condicao Controle

  2) Várias amostras via sample sheet (colunas obrigatórias: SRR, Condicao):
        python3 pipeline.py --sample-sheet metadados/sample_sheet_curado.csv
"""

import argparse
import logging
import subprocess
import sys
from pathlib import Path

import pandas as pd

DIRS = {
    "sra": Path("sra"),
    "brutos": Path("dados_brutos"),
    "limpos": Path("dados_limpos"),
    "qc_bruto": Path("qc_bruto"),
    "qc_limpo": Path("qc_limpo"),
    "logs": Path("logs"),
}


def configurar_logging():
    DIRS["logs"].mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(DIRS["logs"] / "pipeline.log"),
            logging.StreamHandler(sys.stdout),
        ],
    )


def run_cmd(cmd):
    logging.info("$ " + " ".join(map(str, cmd)))
    subprocess.run(cmd, check=True)


def processar_amostra(srr, condicao, threads, pular_download, pular_qc, pular_trim, pular_se_existir):
    logging.info("=" * 60)
    logging.info(f"SRR: {srr} | Condição: {condicao}")
    logging.info("=" * 60)

    fq1 = DIRS["brutos"] / f"{srr}_1.fastq.gz"
    fq2 = DIRS["brutos"] / f"{srr}_2.fastq.gz"

    if not pular_download:
        if pular_se_existir and fq1.exists() and fq2.exists():
            logging.info(f"[SKIP] {srr} já baixado.")
        else:
            run_cmd(["prefetch", srr, "--output-directory", str(DIRS["sra"])])
            run_cmd(["vdb-validate", str(DIRS["sra"] / srr)])
            run_cmd([
                "fasterq-dump", str(DIRS["sra"] / srr),
                "--split-files", "--threads", str(threads),
                "--outdir", str(DIRS["brutos"]),
            ])
            for fq in DIRS["brutos"].glob(f"{srr}_*.fastq"):
                run_cmd(["gzip", "-f", str(fq)])

    if not pular_qc:
        run_cmd([
            "fastqc", str(fq1), str(fq2),
            "--threads", str(threads), "--outdir", str(DIRS["qc_bruto"]),
        ])

    if not pular_trim:
        run_cmd([
            "trim_galore", "--paired", "--cores", str(threads), "--fastqc",
            "--output_dir", str(DIRS["limpos"]), str(fq1), str(fq2),
        ])


def main():
    parser = argparse.ArgumentParser(description="Pipeline RNA-Seq: SRA -> FASTQ limpo.")

    modo = parser.add_mutually_exclusive_group(required=True)
    modo.add_argument("--srr", help="Processa apenas este SRR (modo amostra única).")
    modo.add_argument("--sample-sheet", help="CSV com colunas SRR e Condicao (modo lote).")

    parser.add_argument("--condicao", default="NA", help="Usado apenas com --srr.")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--skip-qc", action="store_true")
    parser.add_argument("--skip-trim", action="store_true")
    parser.add_argument(
        "--no-skip-existing", action="store_true",
        help="Força novo download mesmo se o FASTQ já existir.",
    )
    parser.add_argument(
        "--keep-going", action="store_true",
        help="Em modo lote, continua para a próxima amostra se uma falhar.",
    )

    args = parser.parse_args()

    for d in DIRS.values():
        d.mkdir(parents=True, exist_ok=True)

    configurar_logging()

    if args.srr:
        amostras = [(args.srr, args.condicao)]
    else:
        df = pd.read_csv(args.sample_sheet)
        faltando = {"SRR", "Condicao"} - set(df.columns)
        if faltando:
            sys.exit(f"ERRO: colunas ausentes no sample sheet: {faltando}")
        amostras = list(
            zip(df["SRR"].astype(str).str.strip(), df["Condicao"].astype(str).str.strip())
        )

    falhas = []

    for srr, condicao in amostras:
        try:
            processar_amostra(
                srr, condicao, args.threads,
                args.skip_download, args.skip_qc, args.skip_trim,
                pular_se_existir=not args.no_skip_existing,
            )
        except subprocess.CalledProcessError as e:
            logging.error(f"[ERRO] {srr} falhou: {e}")
            falhas.append(srr)
            if not args.keep_going:
                sys.exit(f"Pipeline interrompido em {srr}. Use --keep-going para pular falhas.")

    if not args.skip_qc:
        limpos = list(DIRS["limpos"].glob("*_val_*.fq.gz"))
        if limpos:
            run_cmd([
                "fastqc", *map(str, limpos),
                "--threads", str(args.threads), "--outdir", str(DIRS["qc_limpo"]),
            ])

    logging.info("Pipeline concluído.")
    if falhas:
        logging.warning(f"{len(falhas)} amostra(s) falharam: {', '.join(falhas)}")


if __name__ == "__main__":
    main()
```

Uso:

```bash
# uma única amostra
python3 scripts/pipeline.py --srr SRR30001 --condicao Controle --threads 8

# lote inteiro, continuando mesmo se alguma amostra falhar
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --threads 8 --keep-going

# reprocessar só o trimming, pulando download e QC bruto
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --skip-download --skip-qc
```

## 7.2 Pipeline em Bash — amostra única OU lote

`scripts/pipeline.sh` espelha a mesma ideia em Bash puro, usando uma função `processar_amostra()` reaproveitada tanto para uma amostra quanto para o loop:

```bash
#!/usr/bin/env bash
# Uso:
#   scripts/pipeline.sh --srr SRR30001
#   scripts/pipeline.sh --lista metadados/lista_srr.txt --threads 8

set -euo pipefail

THREADS=4
SRR_UNICO=""
LISTA=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --srr) SRR_UNICO="$2"; shift 2 ;;
        --lista) LISTA="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        *) echo "Opção desconhecida: $1"; exit 1 ;;
    esac
done

if [[ -z "$SRR_UNICO" && -z "$LISTA" ]]; then
    echo "Uso: $0 --srr SRRxxxxx   OU   $0 --lista arquivo.txt"
    exit 1
fi

BRUTOS="dados_brutos"
LIMPOS="dados_limpos"
QC_BRUTO="qc_bruto"
QC_LIMPO="qc_limpo"
SRA="sra"

mkdir -p "$BRUTOS" "$LIMPOS" "$QC_BRUTO" "$QC_LIMPO" "$SRA"

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

    echo "[OK] $srr"
}

if [[ -n "$SRR_UNICO" ]]; then
    processar_amostra "$SRR_UNICO"
else
    while IFS= read -r srr; do
        [[ -z "$srr" ]] && continue
        processar_amostra "$srr"
    done < "$LISTA"
fi

echo
echo "FastQC final"
fastqc "$LIMPOS"/*.fq.gz --threads "$THREADS" --outdir "$QC_LIMPO"
echo "Pipeline finalizado."
```

```bash
chmod +x scripts/pipeline.sh

# uma amostra
scripts/pipeline.sh --srr SRR30001

# lote, com log salvo em arquivo
scripts/pipeline.sh --lista metadados/lista_srr.txt --threads 8 2>&1 | tee logs/pipeline.log
```

`2>&1 | tee logs/pipeline.log` junta erro e saída padrão e grava em arquivo enquanto ainda mostra na tela.

---

# Parte 8 — Boas práticas e referência final

## 8.1 Checklist antes do alinhamento

```text
[ ] Todas as amostras foram identificadas e têm condição experimental
[ ] Todo SRR foi associado ao GSM correto
[ ] O desenho experimental foi conferido no GEO (não só inferido do texto)
[ ] Réplicas biológicas foram diferenciadas de runs técnicos
[ ] Download terminou sem erros / SRA validado quando aplicável
[ ] FASTQ R1/R2 presentes; FastQC bruto executado; adaptadores avaliados
[ ] Trimming realizado; FastQC pós-trimming executado
[ ] Sample sheet e logs preservados
```

## 8.2 Estrutura final esperada

```text
projeto_rnaseq/
├── metadados/
│   ├── GSE123456_family.soft.gz
│   ├── sample_sheet.csv
│   ├── sample_sheet_curado.csv
│   ├── srr_condicao.csv
│   └── lista_srr.txt
├── sra/
├── dados_brutos/
├── dados_limpos/
├── qc_bruto/          (+ multiqc/)
├── qc_limpo/          (+ multiqc/)
├── logs/
└── scripts/
    ├── 01_geo_to_sample_sheet.py
    ├── 02_curar_sample_sheet.py
    ├── 02_download.sh
    ├── baixar_amostra.py       baixar_lote.py
    ├── fastqc_amostra.py       fastqc_lote.py
    ├── cutadapt_amostra.py     cutadapt_lote.py
    ├── trim_galore_amostra.py  trim_galore_lote.py
    ├── pipeline.py
    └── pipeline.sh
```

## 8.3 Fluxo resumido (receita rápida)

```bash
mkdir -p projeto_rnaseq/{metadados,sra,dados_brutos,dados_limpos,qc_bruto,qc_limpo,logs,scripts}
cd projeto_rnaseq

python3 scripts/01_geo_to_sample_sheet.py GSE123456
python3 scripts/02_curar_sample_sheet.py
column -s ',' -t metadados/srr_condicao.csv          # conferir

python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --threads 8 --keep-going

multiqc qc_bruto -o qc_bruto/multiqc
multiqc qc_limpo -o qc_limpo/multiqc
```

> **Regra de ouro:** primeiro preserve a informação biológica, depois automatize o processamento. O `SRR` diz ao computador qual arquivo baixar; o `GSM`/metadado GEO é o que diz ao pesquisador o que aquela amostra representa biologicamente.

## 8.4 Tabela-resumo: comando por etapa

| Etapa | Bash — 1 amostra | Python — 1 amostra | Bash — lote | Python — lote |
|---|---|---|---|---|
| Download | `prefetch` + `fasterq-dump` (§3.2) | `baixar_amostra.py SRR` (§3.3) | `02_download.sh` (§3.4) | `baixar_lote.py lista.txt` (§3.5) |
| FastQC bruto | `fastqc R1 R2 ...` (§4.2) | `fastqc_amostra.py SRR` (§4.3) | `fastqc *.fastq.gz` (§4.4) | `fastqc_lote.py lista.txt` (§4.5) |
| Trim — Cutadapt | `cutadapt ...` (§5.2) | `cutadapt_amostra.py SRR` (§5.3) | loop `while read` (§5.4) | `cutadapt_lote.py lista.txt` (§5.4) |
| Trim — Trim Galore | `trim_galore --paired ...` (§5.7) | `trim_galore_amostra.py SRR` (§5.8) | loop `while read` (§5.9) | `trim_galore_lote.py lista.txt` (§5.9) |
| FastQC pós-trim | `fastqc *_val_*.fq.gz` (§6.1) | reaproveita `fastqc_amostra.py` | idem | reaproveita `fastqc_lote.py` |
| Pipeline completo | `pipeline.sh --srr SRR` (§7.2) | `pipeline.py --srr SRR` (§7.1) | `pipeline.sh --lista lista.txt` (§7.2) | `pipeline.py --sample-sheet sheet.csv` (§7.1) |

## 8.5 O conceito central da aula

O aluno não deve sair sabendo só digitar `fasterq-dump`. Ele deve conseguir responder: por que estou baixando este SRR → qual GSM o originou → qual é a condição → é controle ou tratamento → é réplica biológica ou técnica → o FASTQ está íntegro → a qualidade é adequada → preciso de trimming → o trimming melhorou os dados? Esse encadeamento é o que transforma "rodar comandos" em "fazer uma análise de RNA-Seq".

## 8.6 Referências oficiais

- GEO — acesso programático: https://www.ncbi.nlm.nih.gov/geo/info/geo_paccess.html
- GEO — download: https://www.ncbi.nlm.nih.gov/geo/info/download.html
- Formato SOFT: https://www.ncbi.nlm.nih.gov/geo/info/soft.html
- SRA Download: https://www.ncbi.nlm.nih.gov/sra/docs/sradownload/
- SRA Toolkit: https://github.com/ncbi/sra-tools
- `prefetch` + `fasterq-dump`: https://github.com/ncbi/sra-tools/wiki/08.-prefetch-and-fasterq-dump
- `fasterq-dump`: https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump
- Cutadapt: https://cutadapt.readthedocs.io/
- Trim Galore: https://github.com/FelixKrueger/TrimGalore