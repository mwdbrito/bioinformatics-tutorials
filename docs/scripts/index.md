---
title: Scripts
description: Repositório de scripts de bioinformática do MwInSilico — código em Bash, Python e R, aberto no GitHub.
---

# Scripts

Este site também funciona como **repositório de código**: os scripts que uso nas análises e nos tutoriais ficam versionados no GitHub, abertos para qualquer pessoa ler, baixar e adaptar.

## Repositórios

<div class="mw-card-grid" markdown>

<div class="mw-card" markdown>
<span class="mw-card-icon">:fontawesome-brands-github:</span>
<div class="mw-card-kicker">mwdbrito / bioinformatics-tutorials</div>
<div class="mw-card-title">Código-fonte do MwInSilico</div>
<div class="mw-card-body">Os textos, as figuras e a configuração deste site (MkDocs + Material). Encontrou um erro? Use o ícone de lápis no topo de qualquer página para sugerir uma correção.</div>
[Abrir no GitHub :octicons-arrow-right-24:](https://github.com/mwdbrito/bioinformatics-tutorials){ .mw-card-link }
</div>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-card-icon">:material-dna:</span>
<span class="mw-pill mw-pill--muted">em preparação</span>
<div class="mw-card-title" style="margin-top:.6rem">Pipeline de RNA-Seq</div>
<div class="mw-card-body">Scripts em Python, Bash e R do GEO aos genes diferencialmente expressos (download, FastQC, Trim Galore, STAR/Salmon, DESeq2 e clusterProfiler), com container Apptainer.</div>
</div>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-card-icon">:material-database-search:</span>
<span class="mw-pill mw-pill--muted">em preparação</span>
<div class="mw-card-title" style="margin-top:.6rem">Exploração do TCGA/GDC</div>
<div class="mw-card-body">Protocolo em R com TCGAbiolinks para inventariar casos, amostras, arquivos e metadados clínicos de um projeto TCGA.</div>
</div>

</div>

## Como usar

```bash
# baixe o repositório
git clone https://github.com/mwdbrito/bioinformatics-tutorials.git
cd bioinformatics-tutorials
```

!!! info "Reprodutibilidade"
    Sempre que possível, os scripts vêm acompanhados de um container (Apptainer/Singularity) com as versões exatas das ferramentas, para que a análise rode da mesma forma no seu notebook ou num cluster HPC.

!!! question "Dúvidas ou sugestões?"
    Abra uma [issue no GitHub](https://github.com/mwdbrito/bioinformatics-tutorials/issues) ou mande uma mensagem no Instagram [@MWInSilico](https://www.instagram.com/mwinsilico/).

<!--
  Para adicionar um novo repositório, copie o bloco abaixo para dentro da grade acima:

<div class="mw-card" markdown>
<span class="mw-card-icon">:fontawesome-brands-github:</span>
<div class="mw-card-kicker">mwdbrito / NOME-DO-REPO</div>
<div class="mw-card-title">Título curto</div>
<div class="mw-card-body">O que o repositório faz, em uma ou duas frases. Linguagens: R, Python.</div>
[Abrir no GitHub :octicons-arrow-right-24:](https://github.com/mwdbrito/NOME-DO-REPO){ .mw-card-link }
</div>
-->
