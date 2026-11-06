---
title: Glossário
description: Glossário de bioinformática em português — siglas e termos de sequenciamento, transcriptômica e biologia molecular usados nas postagens do MwInSilico.
---

# Glossário

Os termos técnicos que aparecem nas postagens, em ordem alfabética. Nos textos, as siglas sublinhadas mostram uma versão curta destas definições quando você passa o mouse (ou toca) sobre elas.

## A–C

Alinhamento
:   Etapa em que cada leitura (*read*) é posicionada no genoma ou transcriptoma de referência, encontrando a região de onde ela provavelmente veio. Exemplos de ferramentas: STAR, HISAT2, BWA.

Biblioteca (de sequenciamento)
:   O conjunto de fragmentos de DNA (ou cDNA) preparados para entrar no sequenciador: fragmentados no tamanho certo e ligados a adaptadores que o equipamento reconhece.

Bulk
:   Medida feita sobre uma amostra inteira, com milhares a milhões de células misturadas. O resultado é a média da expressão dessas células.

cDNA
:   DNA complementar. É a cópia em DNA de uma molécula de RNA, sintetizada pela transcriptase reversa. Quase todo protocolo de RNA-Seq converte o RNA em cDNA antes de sequenciar.

Cobertura
:   Quantas leituras, em média, cobrem cada posição do genoma ou de um transcrito. Uma cobertura de 30× significa que cada base foi lida, em média, 30 vezes.

Código de barras (*barcode*)
:   Sequência curta adicionada às moléculas para identificar de qual amostra, ou de qual célula (no scRNA-seq), cada leitura veio.

CRISPR
:   Sistema de edição de genomas guiado por RNA, derivado de um mecanismo de defesa de bactérias contra vírus.

## D–L

DESeq2
:   Pacote R/Bioconductor de análise de expressão diferencial. Modela as contagens com uma distribuição binomial negativa e normaliza as amostras pela mediana das razões.

Dogma Central
:   Princípio formulado por Francis Crick (1958, revisado em 1970) que descreve as transferências possíveis de informação sequencial entre DNA, RNA e proteínas.

Expressão diferencial
:   Análise estatística que identifica genes cuja expressão muda de forma significativa entre condições (por exemplo, tumor vs. tecido normal).

FASTQ
:   Formato de texto que guarda as leituras de sequenciamento. Cada leitura ocupa quatro linhas: identificador, sequência, separador e a qualidade (escore Phred) de cada base.

FISH
:   *Fluorescence In Situ Hybridization*. Sondas fluorescentes que se ligam a sequências específicas de RNA ou DNA, permitindo vê-las ao microscópio dentro da célula ou do tecido. É a base de métodos espaciais como MERFISH e seqFISH.

GENCODE
:   Projeto que mantém a anotação de referência de genes e transcritos humanos e de camundongo.

Leitura (*read*)
:   Cada sequência produzida pelo sequenciador a partir de um fragmento da biblioteca. As leituras curtas (Illumina) têm de 50 a 300 bases; as longas (PacBio, Nanopore) podem ter dezenas de milhares.

lncRNA
:   RNA longo não codificante, com mais de 200 nucleotídeos. Não é traduzido em proteína, mas pode regular a expressão de outros genes.

## M–R

Matriz de contagens
:   Tabela com uma linha por gene e uma coluna por amostra (ou por célula, no scRNA-seq), em que cada valor é o número de leituras atribuídas àquele gene. É a entrada da análise estatística.

miRNA
:   microRNA. RNA pequeno, de cerca de 22 nucleotídeos, que se liga a mRNAs-alvo e reduz sua tradução ou estabilidade.

mRNA
:   RNA mensageiro. Leva a informação de um gene codificante até o ribossomo, onde é traduzido em proteína. Em eucariotos, o mRNA maduro tem uma cauda poli-A.

NGS
:   *Next-Generation Sequencing*. Tecnologias de sequenciamento massivamente paralelo, que leem milhões de fragmentos ao mesmo tempo. A Illumina é o exemplo mais comum.

PCA
:   Análise de Componentes Principais. Reduz dados com milhares de variáveis (genes) a poucos eixos que concentram a maior parte da variação. É muito usada para ver como as amostras se agrupam.

PCR
:   Reação em Cadeia da Polimerase. Amplifica exponencialmente um trecho específico de DNA e é usada no preparo de quase todas as bibliotecas de sequenciamento.

Poli-A (seleção por)
:   Estratégia de preparo de biblioteca que captura apenas RNAs com cauda poli-A, principalmente mRNAs maduros.

Pseudo-alinhamento
:   Estratégia (usada por Salmon e kallisto) que estima de qual transcrito cada leitura veio sem calcular a posição exata, base a base. É muito mais rápida que o alinhamento completo.

Read
:   Veja **Leitura**.

rRNA
:   RNA ribossômico. Faz parte da estrutura dos ribossomos e corresponde a cerca de 80% do RNA total de uma célula. Por isso costuma ser removido (depleção) antes do RNA-Seq.

RNA-Seq
:   Sequenciamento do RNA (convertido em cDNA) de uma amostra para medir quais genes estão sendo expressos e em que quantidade.

## S–Z

scRNA-seq
:   *Single-cell RNA sequencing*. RNA-Seq feito célula por célula, que gera uma matriz célula × gene e revela subpopulações e estados celulares.

SMRT
:   *Single Molecule, Real-Time*. Tecnologia da PacBio que observa, em tempo real, uma polimerase incorporando nucleotídeos em uma única molécula de DNA. O modo HiFi produz leituras longas e muito precisas.

Splicing
:   Remoção dos íntrons e união dos éxons de um pré-mRNA. Por causa dele, uma leitura de RNA-Seq pode cobrir dois éxons distantes no genoma, e por isso são necessários alinhadores "cientes de splicing", como o STAR.

STAR
:   *Spliced Transcripts Alignment to a Reference*. Alinhador de RNA-Seq rápido e ciente de splicing.

Transcriptoma
:   Conjunto de todos os RNAs presentes em uma célula, tecido ou amostra em um dado momento.

Transcriptômica espacial
:   Métodos que medem a expressão gênica preservando a posição de cada medida no tecido, por imagem (como MERFISH) ou por sequenciamento em grade (como o Visium).

UMI
:   *Unique Molecular Identifier*. Código de barras aleatório adicionado a cada molécula antes da amplificação. Permite contar as moléculas originais e descartar as cópias geradas por PCR.

WSL
:   *Windows Subsystem for Linux*. Recurso do Windows que roda um Linux, como o Ubuntu, sem precisar de outro computador. É o caminho mais simples para usar o terminal Linux no Windows.
