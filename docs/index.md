---
title: Início
description: MwInSilico — postagens, tutoriais e scripts de bioinformática em português, do dado bruto ao conhecimento biológico.
hide:
  - navigation
  - toc
---

<div class="mw-hero" markdown>

<div markdown>

<div class="mw-hero-brand" markdown>
![Logo MwInSilico](assets/logo.png)
<span class="mw-eyebrow">Bioinformática em português</span>
</div>

<h1>Do dado bruto ao <span class="mw-accent">conhecimento biológico</span></h1>

<p class="mw-hero-lead">Olá! Sou o <strong>Márcio</strong>, pesquisador de bioinformática. Aqui ficam, em versão completa e com referências, as postagens do <strong>@MWInSilico</strong>, junto com os meus scripts e tutoriais de análise de dados ômicos.</p>

[Começar a ler :octicons-arrow-right-24:](posts/index.md){ .md-button .md-button--primary }
[:fontawesome-brands-instagram: Seguir @MWInSilico](https://www.instagram.com/mwinsilico/){ .md-button target="_blank" rel="noopener" }

</div>

<div class="mw-terminal" aria-hidden="true">
<div class="mw-terminal-bar"><span></span><span></span><span></span></div>
<pre><span class="p">$</span> <span class="k">ls</span> mwinsilico/
<span class="p">posts/</span>      <span class="c"># textos completos do Instagram</span>
<span class="p">scripts/</span>    <span class="c"># código aberto no GitHub</span>
<span class="p">tutoriais/</span>  <span class="c"># em preparação</span>

<span class="p">$</span> <span class="k">grep</span> -c "Postagem" posts/*.md
<span class="c">5 textos · 2 séries · com referências</span>

<span class="mw-dna"><span>ATGGCGTACGTTAGCCTAGGATCCGAATTCGCTAGCAAGCTTGCGGCCGCTCTAGAACTAGTGGATCCATGGCGTACGTTAGCCTAGGATCCGAATTCGCTAGCAAGCTTGCGGCCGCTCTAGAACTAGTGGATCC</span></span></pre>
</div>

</div>

<h2 class="mw-section-title">Comece por uma série</h2>
<p class="mw-section-sub">Os textos foram escritos para serem lidos em sequência — cada um parte de onde o anterior parou.</p>

<div class="mw-series-grid" markdown>

<div class="mw-series" markdown>
<span class="mw-eyebrow">Série 1</span>

### :material-dna: Fundamentos

Os conceitos que sustentam qualquer análise em bioinformática.

<ol class="mw-steps" markdown>
<li markdown>[O Dogma Central evoluiu](posts/dogma-central.md)<span>DNA → RNA → proteína, e tudo o que a biologia descobriu depois.</span></li>
<li markdown>[Sequenciamento de DNA](posts/sequenciamento-de-dna.md)<span>De Sanger ao Nanopore: como aprendemos a ler o genoma.</span></li>
</ol>
</div>

<div class="mw-series" markdown>
<span class="mw-eyebrow">Série 2</span>

### :material-chart-scatter-plot: Como medimos o transcriptoma

Três tecnologias, cada uma resolvendo um limite da anterior.

<ol class="mw-steps" markdown>
<li markdown>[RNA-Seq bulk](posts/rna-seq-bulk.md)<span>A fotografia média da expressão gênica.</span></li>
<li markdown>[RNA-Seq de célula única](posts/rna-seq-celula-unica.md)<span>A heterogeneidade que a média esconde.</span></li>
<li markdown>[Transcriptômica espacial](posts/transcriptomica-espacial.md)<span>Onde, no tecido, cada célula estava.</span></li>
</ol>
</div>

</div>

<h2 class="mw-section-title">O que você encontra aqui</h2>
<p class="mw-section-sub">Três formatos, um mesmo objetivo: entender a biologia por trás dos dados.</p>

<div class="mw-card-grid" markdown>

<div class="mw-card" markdown>
<span class="mw-card-icon">:material-post-outline:</span>
<div class="mw-card-title">Postagens</div>
<div class="mw-card-body">A versão completa do que é publicado no Instagram: explicações, figuras e widgets interativos, com referências.</div>
[Ler postagens :octicons-arrow-right-24:](posts/index.md){ .mw-card-link }
</div>

<div class="mw-card" markdown>
<span class="mw-card-icon">:material-code-braces:</span>
<div class="mw-card-title">Scripts</div>
<div class="mw-card-body">Código em Bash, Python e R, versionado no GitHub e pronto para reutilizar nas suas análises.</div>
[Ver scripts :octicons-arrow-right-24:](scripts/index.md){ .mw-card-link }
</div>

<div class="mw-card" markdown>
<span class="mw-card-icon">:material-book-search-outline:</span>
<div class="mw-card-title">Glossário</div>
<div class="mw-card-body">As siglas e os termos técnicos dos textos, explicados. Passe o mouse sobre uma sigla sublinhada para ver a definição.</div>
[Abrir glossário :octicons-arrow-right-24:](glossario.md){ .mw-card-link }
</div>

</div>

<h2 class="mw-section-title">Em preparação</h2>
<p class="mw-section-sub">Tutoriais práticos, passo a passo, que estão sendo revisados antes de entrar no site.</p>

<div class="mw-card-grid" markdown>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-pill mw-pill--muted">em revisão</span>
<div class="mw-card-title" style="margin-top:.6rem">Pipeline de RNA-Seq</div>
<div class="mw-card-body">Do GEO aos genes diferencialmente expressos: QC, trimming, STAR/Salmon, DESeq2 e enriquecimento funcional.</div>
</div>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-pill mw-pill--muted">em revisão</span>
<div class="mw-card-title" style="margin-top:.6rem">A estatística do DESeq2</div>
<div class="mw-card-body">Normalização, dispersão, encolhimento e teste de Wald, explicados do zero.</div>
</div>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-pill mw-pill--muted">em revisão</span>
<div class="mw-card-title" style="margin-top:.6rem">Explorando o TCGA/GDC</div>
<div class="mw-card-body">Inventário de casos, amostras e modalidades de um projeto de câncer antes de baixar qualquer dado.</div>
</div>

<div class="mw-card mw-card--soon" markdown>
<span class="mw-pill mw-pill--muted">em revisão</span>
<div class="mw-card-title" style="margin-top:.6rem">Containers com Apptainer</div>
<div class="mw-card-body">Ambientes reprodutíveis para rodar pipelines em qualquer máquina ou cluster HPC.</div>
</div>

</div>

<div class="mw-cta" markdown>
<div markdown>
<h3>Acompanhe no Instagram</h3>
<p>Novos posts saem primeiro no @MWInSilico e chegam aqui em versão completa.</p>
</div>
[:fontawesome-brands-instagram: @MWInSilico](https://www.instagram.com/mwinsilico/){ .md-button target="_blank" rel="noopener" }
</div>
