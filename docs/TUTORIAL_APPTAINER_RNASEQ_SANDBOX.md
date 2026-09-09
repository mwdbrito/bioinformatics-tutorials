# Tutorial — Criando um container Apptainer Sandbox para o pipeline completo de RNA-Seq

Este tutorial cria um ambiente **Apptainer Sandbox** preparado especificamente para o tutorial:

**GEO → metadados → SRA/SRR → download → FastQC → trimming → STAR/Salmon → matriz de contagens → DESeq2 → GO/KEGG**

O ambiente foi desenhado para executar os scripts Python, Bash e R do tutorial sem depender das instalações de bioinformática existentes no sistema hospedeiro.

> **Importante:** o container guarda as ferramentas e bibliotecas. Os FASTQ, índices de referência, matrizes e resultados devem permanecer **fora** do container, em um diretório de projeto montado com `--bind`.

---

## 1. O que será instalado

O sandbox contém:

| Categoria | Ferramentas |
|---|---|
| Metadados GEO/SRA | Entrez Direct (`esearch`, `efetch`, `xtract`) |
| Download SRA | SRA Toolkit (`prefetch`, `vdb-validate`, `fasterq-dump`) |
| QC | FastQC, MultiQC |
| Trimming | Cutadapt, Trim Galore |
| Alinhamento | STAR |
| BAM | samtools |
| Quantificação | Salmon |
| Python | Python 3.11, pandas, numpy, requests |
| R | R base |
| Bioconductor | DESeq2, tximport, clusterProfiler, enrichplot |
| Anotação | org.Hs.eg.db e org.At.tair.db |
| Compressão | gzip/pigz |

Isso corresponde às ferramentas usadas no fluxo descrito no tutorial de RNA-Seq, que inclui metadados GEO, SRA, QC, trimming, STAR/Salmon, DESeq2 e enriquecimento funcional. 

---

# 2. Por que usar Sandbox?

Um container Sandbox é uma **pasta que funciona como o sistema de arquivos do container**.

Isso é particularmente útil durante a construção e depuração porque:

```text
rnaseq_sandbox/
├── bin/
├── etc/
├── opt/
├── usr/
└── ...
```

Você pode testar o ambiente antes de transformá-lo em um `.sif`.

O Apptainer permite construir um sandbox diretamente com:

```bash
apptainer build --sandbox rnaseq_sandbox rnaseq.def
```

A documentação oficial descreve `--sandbox` justamente como a opção para produzir um container em formato de diretório em vez do formato SIF.

---

# 3. Arquivos deste projeto

Coloque estes arquivos juntos:

```text
apptainer_rnaseq_sandbox/
├── rnaseq.def
├── build_sandbox.sh
├── check_container.sh
└── shell_rnaseq.sh
```

## Função de cada arquivo

### `rnaseq.def`

É a receita do container.

Define:

- sistema operacional;
- ferramentas;
- Python;
- R;
- pacotes Bioconductor;
- variáveis de ambiente;
- teste automático.

### `build_sandbox.sh`

Cria o sandbox usando:

```bash
sudo apptainer build --sandbox rnaseq_sandbox rnaseq.def
```

e executa o teste automático.

### `check_container.sh`

Verifica se todas as ferramentas estão funcionando.

### `shell_rnaseq.sh`

Abre um shell dentro do container com o diretório atual montado como `/workspace`.

---

# 4. Pré-requisitos no Linux

Primeiro confirme que o Apptainer está instalado:

```bash
apptainer --version
```

Se aparecer algo semelhante a:

```text
apptainer version 1.x.x
```

está pronto.

Também confira:

```bash
uname -m
```

O `rnaseq.def` fornecido neste projeto foi preparado para Linux **x86_64/amd64**.

---

# 5. Criar o projeto do container

```bash
mkdir -p ~/rnaseq_container
cd ~/rnaseq_container
```

Coloque dentro dele:

```text
rnaseq.def
build_sandbox.sh
check_container.sh
shell_rnaseq.sh
```

Depois:

```bash
chmod +x *.sh
```

---

# 6. Construir o Sandbox

Execute:

```bash
./build_sandbox.sh
```

Internamente será executado:

```bash
sudo apptainer build --sandbox rnaseq_sandbox rnaseq.def
```

A construção pode demorar porque vários programas e pacotes R/Bioconductor serão instalados.

Ao final deverá existir:

```text
rnaseq_sandbox/
```

Confira:

```bash
ls -lah
```

---

# 7. Testar o container

Primeiro:

```bash
sudo apptainer test rnaseq_sandbox
```

Depois:

```bash
./check_container.sh
```

Você deverá obter uma saída contendo algo semelhante a:

```text
=== RNA-Seq Apptainer environment ===
Python:   Python 3.11.x
R:        R version ...
STAR:     ...
Salmon:   salmon ...
samtools: samtools ...
FastQC:   ...
MultiQC:  ...
Cutadapt: ...
TrimGalore: ...
SRA:      ...
Python packages: pandas/numpy/requests OK
R/Bioconductor packages: OK
====================================
```

---

# 8. Verificar individualmente as ferramentas

Entre no container:

```bash
apptainer exec rnaseq_sandbox bash
```

Agora:

```bash
which esearch
which efetch
which xtract

which prefetch
which vdb-validate
which fasterq-dump

which fastqc
which multiqc

which cutadapt
which trim_galore

which STAR
which samtools
which salmon

which python3
which Rscript
```

Todos devem retornar um caminho.

Por exemplo:

```text
/opt/micromamba/envs/rnaseq/bin/STAR
```

Saia:

```bash
exit
```

---

# 9. Testar Python

Execute:

```bash
apptainer exec rnaseq_sandbox \
    python3 -c "import pandas, numpy, requests; print('Python OK')"
```

Também:

```bash
apptainer exec rnaseq_sandbox \
    python3 -c "import pandas as pd; print(pd.__version__)"
```

---

# 10. Testar R e Bioconductor

Execute:

```bash
apptainer exec rnaseq_sandbox \
    Rscript -e 'library(DESeq2); library(tximport); library(clusterProfiler); library(enrichplot); cat("R OK\n")'
```

Para verificar as anotações incluídas:

```bash
apptainer exec rnaseq_sandbox \
    Rscript -e 'library(org.Hs.eg.db); library(org.At.tair.db); cat("OrgDb OK\n")'
```

O tutorial usa `DESeq2`, `tximport`, `clusterProfiler`, `enrichplot` e um `OrgDb` específico do organismo.

---

# 11. Testar Entrez Direct

O script de metadados GEO usa:

```text
efetch
```

para obter informações do SRA a partir dos SRX.

Teste:

```bash
apptainer exec rnaseq_sandbox esearch -db sra -query SRX000000
```

Um resultado vazio ou uma mensagem relacionada ao identificador pode ser esperado para um SRX inexistente; o objetivo aqui é confirmar que o executável está disponível.

Teste os executáveis:

```bash
apptainer exec rnaseq_sandbox which esearch efetch xtract
```

---

# 12. Testar SRA Toolkit

Verifique:

```bash
apptainer exec rnaseq_sandbox prefetch --version
```

```bash
apptainer exec rnaseq_sandbox fasterq-dump --version
```

```bash
apptainer exec rnaseq_sandbox vdb-validate --version
```

O tutorial usa exatamente a sequência:

```text
prefetch
   ↓
vdb-validate
   ↓
fasterq-dump
   ↓
FASTQ
```

---

# 13. Testar FastQC e MultiQC

```bash
apptainer exec rnaseq_sandbox fastqc --version
```

```bash
apptainer exec rnaseq_sandbox multiqc --version
```

---

# 14. Testar trimming

Cutadapt:

```bash
apptainer exec rnaseq_sandbox cutadapt --version
```

Trim Galore:

```bash
apptainer exec rnaseq_sandbox trim_galore --version
```

O tutorial apresenta Cutadapt para explicar o conceito e usa Trim Galore no pipeline final.

---

# 15. Testar STAR

```bash
apptainer exec rnaseq_sandbox STAR --version
```

O índice do STAR **não deve ser criado dentro do container**.

Ele deve ficar no projeto:

```text
projeto_rnaseq/
└── referencia/
    └── star_index/
```

Isso é importante porque índices de referência podem ocupar muitos GB.

---

# 16. Testar Salmon

```bash
apptainer exec rnaseq_sandbox salmon --version
```

Assim como o STAR, o índice do Salmon deve ficar fora do container:

```text
projeto_rnaseq/
└── referencia/
    └── salmon_index/
```

---

# 17. Estrutura recomendada

A melhor organização é separar:

### Container

```text
rnaseq_container/
└── rnaseq_sandbox/
```

### Projeto de análise

```text
projeto_rnaseq/
├── metadados/
├── referencia/
├── sra/
├── dados_brutos/
├── dados_limpos/
├── qc_bruto/
├── qc_limpo/
├── alinhamento_star/
├── quantificacao_salmon/
├── contagens/
├── resultados_deseq2/
├── resultados_enriquecimento/
├── logs/
└── scripts/
```

Essa estrutura é a mesma lógica usada no tutorial original.

---

# 18. Montar o projeto dentro do container

Suponha:

```text
/home/usuario/projeto_rnaseq
```

Entre no container com:

```bash
apptainer exec \
    --bind /home/usuario/projeto_rnaseq:/workspace \
    --pwd /workspace \
    rnaseq_sandbox \
    bash
```

Agora:

```bash
pwd
```

deve mostrar:

```text
/workspace
```

E:

```bash
ls
```

deve mostrar:

```text
metadados
referencia
sra
dados_brutos
dados_limpos
...
```

---

# 19. Forma mais simples: usar o script `shell_rnaseq.sh`

Se você estiver dentro do diretório do projeto:

```bash
cd /home/usuario/projeto_rnaseq
```

e o sandbox estiver acessível como:

```text
/home/usuario/rnaseq_container/rnaseq_sandbox
```

você pode definir:

```bash
export RNASEQ_CONTAINER=/home/usuario/rnaseq_container/rnaseq_sandbox
```

e executar:

```bash
/home/usuario/rnaseq_container/shell_rnaseq.sh
```

O diretório do projeto aparecerá dentro do container como:

```text
/workspace
```

---

# 20. Rodando o tutorial dentro do container

Dentro do container:

```bash
cd /workspace
```

Os scripts do tutorial podem ser executados normalmente.

Por exemplo:

```bash
python3 scripts/geo_to_sample_sheet.py GSE123456
```

Curadoria:

```bash
python3 scripts/curar_sample_sheet.py
```

Download:

```bash
python3 scripts/download.py \
    --lista metadados/lista_srr.txt \
    --threads 8 \
    --keep-going
```

FastQC:

```bash
python3 scripts/qc.py \
    --lista metadados/lista_srr.txt \
    --threads 8
```

Trim Galore:

```bash
python3 scripts/trim_galore_step.py \
    --lista metadados/lista_srr.txt \
    --threads 8 \
    --keep-going
```

---

# 21. Executar o pipeline completo

O tutorial possui um pipeline fechado que aceita STAR ou Salmon.

Por exemplo, com STAR:

```bash
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --aligner star \
    --star-genome-dir referencia/star_index \
    --rodar-analise \
    --strandedness reverse \
    --orgdb org.Hs.eg.db \
    --keytype ENSEMBL \
    --threads 8 \
    --keep-going
```

Com Salmon:

```bash
python3 scripts/pipeline.py \
    --sample-sheet metadados/sample_sheet_curado.csv \
    --aligner salmon \
    --salmon-index referencia/salmon_index \
    --rodar-analise \
    --tx2gene referencia/tx2gene.csv \
    --threads 8
```

O tutorial prevê explicitamente os modos `--aligner star` e `--aligner salmon`, e a análise em lote chama DESeq2 e, opcionalmente, o enriquecimento funcional.

---

# 22. O que NÃO deve ser colocado dentro do container

Não coloque:

```text
FASTQ
BAM
SRA
genoma.fa
anotacao.gtf
transcritos.fa
STAR index
Salmon index
matrizes
resultados
```

dentro do sandbox.

Em vez disso:

```text
HOST
│
├── rnaseq_sandbox/
│
└── projeto_rnaseq/
    ├── dados_brutos/
    ├── dados_limpos/
    ├── referencia/
    └── resultados/
```

O container fornece o software.

O projeto fornece os dados.

---

# 23. Por que separar software e dados?

Imagine que você tenha:

```text
10 projetos
```

e um único ambiente:

```text
rnaseq_sandbox/
```

Você pode montar cada projeto:

```bash
apptainer exec --bind projeto1:/workspace rnaseq_sandbox ...
```

```bash
apptainer exec --bind projeto2:/workspace rnaseq_sandbox ...
```

```bash
apptainer exec --bind projeto3:/workspace rnaseq_sandbox ...
```

Assim:

```text
                  ┌── projeto1
                  │
rnaseq_sandbox ───┼── projeto2
                  │
                  ├── projeto3
                  │
                  └── projeto4
```

Isso facilita muito a manutenção.

---

# 24. `--cleanenv`: por que usar?

Recomendo executar os scripts assim:

```bash
apptainer exec \
    --cleanenv \
    --bind "$PWD:/workspace" \
    --pwd /workspace \
    rnaseq_sandbox \
    python3 scripts/...
```

`--cleanenv` reduz a interferência de variáveis do ambiente hospedeiro.

Isso é especialmente útil para evitar que:

```text
PATH
R
PYTHON
LD_LIBRARY_PATH
CONDA
```

do sistema hospedeiro interfiram no ambiente do container.

---

# 25. Atenção ao espaço em disco

RNA-Seq ocupa muito espaço.

Durante:

```text
SRA
 ↓
FASTQ
 ↓
FASTQ trimado
 ↓
BAM
```

podem existir simultaneamente vários arquivos grandes.

Antes de iniciar:

```bash
df -h
```

E:

```bash
df -i
```

Durante a análise:

```bash
du -sh .
```

O tutorial original também recomenda verificar espaço e CPUs antes do download/conversão.

---

# 26. Atenção especial ao `fasterq-dump`

O fluxo:

```text
.sra
 ↓
fasterq-dump
 ↓
.fastq
 ↓
gzip
```

pode precisar de bastante espaço temporário.

Portanto:

```bash
df -h
```

deve ser executado **antes** de iniciar um lote grande.

---

# 27. STAR: atenção à memória RAM

O problema mais provável em máquinas pequenas não será o container.

Será o índice do STAR.

Por isso:

```text
Container
   ≠
STAR index
```

O índice depende do genoma utilizado e pode exigir dezenas de GB de RAM durante a construção.

Faça:

```bash
free -h
```

antes de construir o índice.

---

# 28. Criar os índices fora do container

Por exemplo:

```bash
apptainer exec \
    --cleanenv \
    --bind "$PWD:/workspace" \
    --pwd /workspace \
    rnaseq_sandbox \
    python3 scripts/star_index.py \
        --genoma referencia/genoma.fa \
        --gtf referencia/anotacao.gtf \
        --outdir referencia/star_index \
        --tamanho-leitura 100 \
        --threads 16
```

Salmon:

```bash
apptainer exec \
    --cleanenv \
    --bind "$PWD:/workspace" \
    --pwd /workspace \
    rnaseq_sandbox \
    python3 scripts/salmon_index.py \
        --transcriptoma referencia/transcritos.fa \
        --genoma referencia/genoma.fa \
        --outdir referencia/salmon_index \
        --threads 16
```

---

# 29. `tx2gene`

O tutorial também gera:

```text
referencia/tx2gene.csv
```

a partir do GTF.

Execute:

```bash
apptainer exec \
    --cleanenv \
    --bind "$PWD:/workspace" \
    --pwd /workspace \
    rnaseq_sandbox \
    python3 scripts/tx2gene_from_gtf.py \
        referencia/anotacao.gtf \
        --saida referencia/tx2gene.csv
```

---

# 30. Controle de qualidade do container

Antes de começar uma análise real, execute:

```bash
./check_container.sh
```

Depois:

```bash
apptainer exec rnaseq_sandbox rnaseq-env-info
```

E:

```bash
apptainer exec rnaseq_sandbox Rscript \
    -e 'library(DESeq2); library(tximport); library(clusterProfiler); library(enrichplot); cat("OK\n")'
```

Se tudo passar, o ambiente computacional está pronto.

---

# 31. Teste mínimo recomendado

Não comece imediatamente com centenas de SRRs.

Faça primeiro:

```text
1 SRR
 ↓
FASTQ
 ↓
FastQC
 ↓
Trim Galore
 ↓
FastQC
 ↓
STAR/Salmon
```

Depois confirme:

```text
FASTQ existe
QC existe
FASTQ trimado existe
relatório QC existe
BAM ou quant.sf existe
```

Só então execute:

```text
lote completo
 ↓
matriz
 ↓
DESeq2
 ↓
GO/KEGG
```

---

# 32. Uma observação importante sobre o desenho experimental

O container garante que as ferramentas estejam disponíveis.

Ele **não garante que a análise biológica esteja correta**.

Antes do DESeq2, confira:

```text
SRR
 ↓
GSM
 ↓
condição
 ↓
réplica biológica
```

O tutorial enfatiza que SRRs adicionais associados à mesma amostra podem ser runs técnicos e não réplicas biológicas.

Também confira:

```text
Controle
Tratado
```

e nunca deixe uma condição sem revisão manual.

---

# 33. Strandedness

Para STAR, o tutorial possui:

```text
unstranded
forward
reverse
```

e usa `reverse` como padrão.

Não assuma que `reverse` é correto para qualquer experimento.

Confira a biblioteca do estudo antes de produzir a matriz final.

---

# 34. Enriquecimento funcional

Para humano:

```bash
--orgdb org.Hs.eg.db
--keytype ENSEMBL
```

Para Arabidopsis:

```bash
--orgdb org.At.tair.db
--keytype TAIR
```

O `OrgDb` e o `keytype` precisam corresponder ao organismo e aos identificadores presentes nos seus resultados.

O container inclui os dois pacotes acima para tornar o ambiente imediatamente utilizável nesses exemplos.

Para outro organismo, provavelmente será necessário instalar o respectivo pacote `OrgDb` no ambiente.

---

# 35. Se quiser modificar o container

Como este é um Sandbox, você pode reconstruí-lo facilmente.

Edite:

```bash
nano rnaseq.def
```

Por exemplo, para adicionar um pacote Conda:

```text
biopython
```

adicione-o à lista:

```text
python=3.11
pandas
numpy
biopython
```

Depois remova o sandbox antigo:

```bash
sudo rm -rf rnaseq_sandbox
```

e reconstrua:

```bash
./build_sandbox.sh
```

---

# 36. Converter o Sandbox para SIF

Depois de testar tudo, você pode transformar o Sandbox em um arquivo imutável:

```bash
sudo apptainer build rnaseq.sif rnaseq_sandbox
```

Agora terá:

```text
rnaseq_sandbox/
rnaseq.sif
```

O `.sif` é conveniente para distribuição e uso rotineiro.

Teste:

```bash
apptainer exec rnaseq.sif rnaseq-env-info
```

---

# 37. Sandbox vs SIF

| Característica | Sandbox | SIF |
|---|---:|---:|
| É uma pasta | Sim | Não |
| É um arquivo único | Não | Sim |
| Fácil de modificar | Excelente | Não |
| Bom para desenvolvimento | Excelente | Bom |
| Bom para distribuição | Bom | Excelente |
| Recomendado para produção | Menos | Sim |

A estratégia recomendada para este projeto é:

```text
rnaseq.def
     │
     ▼
Sandbox
     │
     ├── testes
     ├── ajustes
     └── validação
           │
           ▼
        rnaseq.sif
```

---

# 38. Fluxo final recomendado

```text
                 rnaseq.def
                     │
                     ▼
             apptainer build
                     │
                     ▼
              rnaseq_sandbox
                     │
             ┌───────┴───────┐
             ▼               ▼
       check_container    testes reais
             │               │
             └───────┬───────┘
                     ▼
              análise validada
                     │
                     ▼
                rnaseq.sif
```

E os dados ficam separados:

```text
                 SOFTWARE
                    │
              rnaseq.sif
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
    projeto 1   projeto 2   projeto 3
        │           │           │
      FASTQ       FASTQ       FASTQ
      BAM         BAM         BAM
      DEGs        DEGs        DEGs
```

---

# 39. Checklist final

Antes de usar o container em uma análise real:

```text
[ ] apptainer --version funciona
[ ] rnaseq.def está salvo
[ ] sandbox foi construído
[ ] apptainer test passou
[ ] Python funciona
[ ] pandas funciona
[ ] Entrez Direct funciona
[ ] SRA Toolkit funciona
[ ] FastQC funciona
[ ] MultiQC funciona
[ ] Cutadapt funciona
[ ] Trim Galore funciona
[ ] STAR funciona
[ ] samtools funciona
[ ] Salmon funciona
[ ] R funciona
[ ] DESeq2 funciona
[ ] tximport funciona
[ ] clusterProfiler funciona
[ ] enrichplot funciona
[ ] OrgDb necessário está instalado
[ ] projeto está fora do container
[ ] referências estão fora do container
[ ] espaço em disco foi conferido
[ ] RAM foi conferida
[ ] teste com 1 SRR foi realizado
[ ] teste com lote pequeno foi realizado
```

---

# 40. Comando que você provavelmente mais usará

Depois de tudo pronto:

```bash
apptainer exec \
    --cleanenv \
    --bind "$PWD:/workspace" \
    --pwd /workspace \
    /caminho/para/rnaseq_sandbox \
    python3 scripts/pipeline.py \
        --sample-sheet metadados/sample_sheet_curado.csv \
        --aligner salmon \
        --salmon-index referencia/salmon_index \
        --rodar-analise \
        --tx2gene referencia/tx2gene.csv \
        --threads 8
```

Ou simplesmente abra o ambiente:

```bash
/caminho/para/shell_rnaseq.sh
```

e trabalhe normalmente dentro de:

```text
/workspace
```

---

## Relação com o tutorial original

Este container foi planejado a partir das etapas e comandos do tutorial fornecido: o fluxo começa em GEO/SRA, passa por download, FastQC, trimming e segue por STAR ou Salmon até matriz de contagens, DESeq2 e enriquecimento funcional. fileciteturn1file0L16-L29

Os scripts finais do tutorial também usam explicitamente `STAR`, `Salmon`, `DESeq2`, `tximport`, `clusterProfiler` e `enrichplot`, além de `OrgDb` específico do organismo. fileciteturn2file0L14-L51

A separação entre software no container e dados/referências no projeto é especialmente adequada aqui porque o tutorial cria diretórios próprios para FASTQ, QC, alinhamento, quantificação, referências, contagens e resultados. fileciteturn1file0L143-L157
