---
title: "RNA-Seq de célula única"
description: "Transcriptômica de célula única (scRNA-seq): por que medir célula por célula revela a heterogeneidade que o RNA-Seq bulk não enxerga."
serie: "Como medimos o transcriptoma"
parte: 2
de: 3
tags:
  - Postagem
  - Single-cell
  - Transcriptômica
  - scRNA-seq
---

# 🔬 Transcriptômica de Célula Única (scRNA-seq)

> **Por que medir célula por célula, em vez de uma amostra inteira em bloco, revelou heterogeneidade que a transcriptômica bulk simplesmente não conseguia enxergar.**

!!! tip "Para quem tem pressa"
    O [RNA-Seq bulk](rna-seq-bulk.md) mede uma média do RNA de todas as células de uma amostra misturadas. A transcriptômica de célula única (scRNA-seq) isola e sequencia o RNA de cada célula **individualmente**, produzindo uma matriz de contagens célula × gene em vez de apenas amostra × gene. O preço é técnico (mais complexo, mais caro por célula, dados mais esparsos) — o ganho é enxergar subpopulações, estados celulares raros e heterogeneidade que uma média sempre esconderia.

Este é o segundo de três textos desta série sobre como medimos o transcriptoma. O [primeiro](rna-seq-bulk.md) cobriu o RNA-Seq bulk; o [terceiro](transcriptomica-espacial.md) cobre a transcriptômica espacial, que resolve a limitação que fica faltando mesmo depois deste texto — a posição original de cada célula no tecido.

## Sumário

1. [O problema que o bulk deixa sem resposta](#o-problema-que-o-bulk-deixa-sem-resposta)
2. [Como se isola e sequencia célula por célula](#como-se-isola-e-sequencia-celula-por-celula)
3. [UMIs: por que contar leituras não basta](#umis-por-que-contar-leituras-nao-basta)
4. [Desafios técnicos específicos do scRNA-seq](#desafios-tecnicos-especificos-do-scrna-seq)
5. [Da matriz de contagens à biologia: visão geral do pipeline](#da-matriz-de-contagens-a-biologia-visao-geral-do-pipeline)
6. [Aplicações](#aplicacoes)
7. [Teste seus conhecimentos](#teste-seus-conhecimentos)
8. [Referências](#referencias)

---

## O problema que o bulk deixa sem resposta

Mexa nas duas abas abaixo — a mesma amostra (um tumor com três tipos celulares misturados), medida das duas formas:

<div class="mw-widget" id="bsc-widget">
<style>
#bsc-widget { border: 1px solid var(--md-default-fg-color--lightest); border-radius: 10px; padding: 20px; margin: 1.5rem 0; background: var(--md-default-bg-color); }
#bsc-widget h4 { margin-top:0; margin-bottom:4px; font-size:1.05rem; }
#bsc-widget .bsc-sub { color: var(--md-default-fg-color--light); font-size:0.85rem; margin-bottom:14px; }
#bsc-widget .bsc-tabs { display:flex; gap:8px; margin-bottom:14px; }
#bsc-widget .bsc-tab { padding:7px 16px; border-radius:20px; border:1.5px solid var(--md-default-fg-color--lightest); cursor:pointer; font-size:0.85rem; font-weight:600; background:transparent; color:var(--md-default-fg-color); }
#bsc-widget .bsc-tab.active { background:#00695c; border-color:#00695c; color:#fff; }
#bsc-widget svg { width:100%; height:auto; display:block; }
#bsc-widget .bsc-note { font-size:0.82rem; color:var(--md-default-fg-color--light); margin-top:10px; min-height:3.2em; }
</style>
<h4>&#128300; A mesma amostra, bulk x célula única</h4>
<div class="bsc-sub">Um tumor com três tipos celulares misturados, medido das duas formas.</div>
<div class="bsc-tabs">
  <button class="bsc-tab active" data-t="bulk">Bulk RNA-Seq</button>
  <button class="bsc-tab" data-t="sc">Célula única</button>
</div>
<svg id="bsc-svg" viewBox="0 0 760 300" xmlns="http://www.w3.org/2000/svg"></svg>
<div class="bsc-note" id="bsc-note"></div>
<script>
(function(){
  var svg = document.getElementById('bsc-svg');
  var note = document.getElementById('bsc-note');
  var tabs = document.querySelectorAll('#bsc-widget .bsc-tab');
  var current = 'bulk';

  var cellTypes = [
    {name:'Tumoral', color:'#e57373', gene:0.8, n:14},
    {name:'Imune',   color:'#4fc3f7', gene:0.2, n:5},
    {name:'Estromal',color:'#aed581', gene:0.1, n:5},
  ];

  var notes = {
    bulk: 'O bulk RNA-Seq mistura o RNA de todas as células antes de sequenciar — o resultado é uma média ponderada pela proporção de cada tipo celular na amostra. Se a maioria das células for tumoral, o sinal do tipo imune (que pode ser exatamente o que importa clinicamente) fica diluído e pode passar despercebido.',
    sc: 'A transcriptômica de célula única preserva a identidade de cada célula individualmente. Fica visível que a amostra não é homogênea — e é possível medir a expressão gênica separadamente em cada subpopulação, revelando sinais que a média do bulk esconderia completamente.'
  };

  function svgEl(tag, attrs){
    var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (var k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  }

  function render(){
    svg.innerHTML = '';
    svg.appendChild(svgEl('rect', {x:0,y:0,width:760,height:300, fill:'#fafafa', rx:8}));

    if (current === 'sc'){
      // grid of individual cells, colored by type
      var cells = [];
      cellTypes.forEach(function(ct){
        for (var i=0;i<ct.n;i++) cells.push(ct);
      });
      var cols = 8, cell_r = 16, gap = 40;
      var x0 = 120, y0 = 60;
      cells.forEach(function(ct, i){
        var col = i % cols, row = Math.floor(i/cols);
        var cx = x0 + col*gap, cy = y0 + row*gap;
        svg.appendChild(svgEl('circle', {cx:cx, cy:cy, r:cell_r, fill:ct.color, opacity:0.85, stroke:'#fff', 'stroke-width':1.5}));
      });
      var ly = y0 + 4*gap + 10;
      var legendY2 = ly + 26;
      cellTypes.forEach(function(ct, i){
        var lx = 90;
        var ly2 = legendY2 + i*22;
        svg.appendChild(svgEl('circle', {cx:lx, cy:ly2, r:7, fill:ct.color}));
        var t = svgEl('text', {x:lx+14, y:ly2+4, 'font-size':12, 'text-anchor':'start', fill:'#333'});
        t.textContent = ct.name + ' — medido separadamente';
        svg.appendChild(t);
      });
    } else {
      // single blended bar representing bulk average
      var total = cellTypes.reduce(function(s,ct){return s+ct.n;},0);
      var x = 100, barY = 120, barH = 60, barW = 560;
      cellTypes.forEach(function(ct){
        var w = barW * (ct.n/total);
        svg.appendChild(svgEl('rect', {x:x, y:barY, width:w, height:barH, fill:ct.color, opacity:0.85}));
        x += w;
      });
      svg.appendChild(svgEl('text', {x:380, y:100, 'font-size':13, 'text-anchor':'middle', fill:'#333', 'font-weight':'700'})).textContent = 'sinal médio combinado (uma única medida por gene)';
      svg.appendChild(svgEl('text', {x:380, y:205, 'font-size':12, 'text-anchor':'middle', fill:'#757575', 'font-style':'italic'})).textContent = 'a proporção de cada tipo pesa no resultado, mas não é possível separá-los depois';
    }
  }

  for (var i=0;i<tabs.length;i++){
    (function(tab){
      tab.addEventListener('click', function(){
        for (var j=0;j<tabs.length;j++){ tabs[j].classList.remove('active'); }
        tab.classList.add('active');
        current = tab.getAttribute('data-t');
        note.textContent = notes[current];
        render();
      });
    })(tabs[i]);
  }
  note.textContent = notes[current];
  render();
})();
</script>
</div>


O primeiro experimento de transcriptômica de célula única foi publicado em 2009 — sequenciando o transcriptoma de um único blastômero de camundongo[^1]. Mas o método só se tornou prático em escala (centenas a milhares de células por experimento, a um custo viável) a partir de 2015, com o surgimento de abordagens baseadas em microgotas[^2][^3] — o assunto da próxima seção.

---

## Como se isola e sequencia célula por célula

Existem duas famílias principais de métodos para capturar células individualmente antes do sequenciamento:

**Métodos baseados em placa** (ex.: Smart-seq2/Smart-seq3): cada célula é depositada, uma por poço, em uma placa de múltiplos poços — geralmente por citometria de fluxo (FACS) ou manualmente sob microscópio. Permitem sequenciar o transcrito **completo**, de ponta a ponta (não só uma extremidade), o que é valioso para estudar isoformas e splicing em nível de célula única. Em compensação, o throughput é baixo — tipicamente centenas de células por experimento — e o custo por célula é alto[^4].

**Métodos baseados em microgotas** (ex.: Drop-seq, e comercialmente a plataforma 10x Genomics Chromium): cada célula é encapsulada, junto com uma micropartícula (*bead*) coberta de milhões de cópias de um adaptador com um **código de barras exclusivo daquela microgota**, dentro de uma microgota de óleo em um chip microfluídico[^2][^3]. Todo o RNA capturado dentro da mesma gota recebe o mesmo código de barras, permitindo sequenciar dezenas de milhares de células em paralelo, no mesmo tubo, e depois separar computacionalmente qual leitura veio de qual célula. O throughput é ordens de magnitude maior, mas apenas uma extremidade do transcrito é normalmente capturada.

!!! info "O código de barras não é a única etiqueta"
    Além do código de barras que identifica a célula (ou gota) de origem, cada molécula de RNA capturado recebe também um segundo código — o UMI, tema da próxima seção — que identifica a molécula individual, não a célula.

---

## UMIs: por que contar leituras não basta

Antes do sequenciamento, o RNA capturado passa por uma etapa de amplificação por PCR — necessária porque a quantidade de material de uma única célula é minúscula demais para o sequenciador detectar diretamente. O problema é que o PCR não amplifica todas as moléculas com a mesma eficiência: algumas moléculas originais acabam gerando muito mais cópias do que outras, por puro acaso da reação química, não por serem mais abundantes na célula.

Os **UMIs** (*unique molecular identifiers* — identificadores moleculares únicos) resolvem isso: antes da amplificação, cada molécula individual de RNA recebe uma etiqueta molecular curta e (praticamente) aleatória[^5]. Depois do sequenciamento, todas as leituras que compartilham o mesmo UMI, o mesmo código de barras de célula e o mesmo gene são colapsadas em **uma única contagem** — não importa se aquela molécula original gerou 3 cópias ou 300 no PCR. O resultado é uma contagem de moléculas originais, não de leituras de sequenciamento, o que corrige diretamente o viés de amplificação.

---

## Desafios técnicos específicos do scRNA-seq

Comparado ao bulk, o scRNA-seq tem problemas técnicos próprios que a análise downstream precisa levar em conta:

- **Dropout**: um gene verdadeiramente expresso pode aparecer com contagem zero em uma célula, simplesmente porque a quantidade de RNA de partida por célula é tão pequena que a molécula não foi capturada por acaso — não porque o gene estava realmente inativo. Isso torna os dados de célula única muito mais esparsos (cheios de zeros) do que os de bulk.
- **Doublets**: ocasionalmente, duas células são capturadas na mesma gota ou poço e acabam sendo sequenciadas como se fossem uma célula só, com um perfil de expressão que é uma mistura das duas — um artefato técnico que ferramentas de análise precisam identificar e remover.
- **RNA ambiente**: RNA livre no meio da suspensão celular (de células que se romperam durante a dissociação do tecido) pode ser capturado junto com uma célula intacta, contaminando seu perfil com um "ruído de fundo" que reflete a composição média da amostra, não daquela célula específica.

---

## Da matriz de contagens à biologia: visão geral do pipeline

Depois do sequenciamento, o resultado bruto é uma matriz de contagens **célula × gene** — potencialmente dezenas de milhares de células por milhares de genes. Em linhas muito gerais (sem entrar em código — isso fica para um tutorial prático futuro), o caminho típico até um resultado biológico interpretável passa por[^6]:

```text
Matriz bruta (célula × gene)
    ↓
Controle de qualidade (remover células com poucas contagens, muitos genes mitocondriais — sinal de célula morrendo — ou contagens suspeitas de doublet)
    ↓
Normalização (corrigir diferenças de profundidade de captura entre células)
    ↓
Redução de dimensionalidade (PCA, depois UMAP ou t-SNE para visualização em 2D)
    ↓
Clustering (agrupar células com perfis de expressão parecidos)
    ↓
Anotação dos clusters (identificar que tipo celular cada cluster representa, por marcadores conhecidos)
    ↓
Análises downstream: genes marcadores por cluster, trajetórias de diferenciação, comparação entre condições
```

As duas ferramentas mais usadas para esse pipeline são o **Scanpy** (Python) e o **Seurat** (R) — ambos implementam essencialmente essa mesma sequência conceitual de etapas, com escolhas de algoritmo ligeiramente diferentes em cada uma.

---

## Aplicações

- **Atlas celulares**: mapear sistematicamente todos os tipos e subtipos celulares presentes em um tecido ou órgão — como o Human Cell Atlas, um esforço internacional em andamento para catalogar todo tipo de célula do corpo humano.
- **Heterogeneidade tumoral**: identificar subpopulações raras dentro de um tumor (por exemplo, células resistentes a um tratamento que uma amostra bulk mostraria apenas como uma pequena mudança na média, se é que mostraria algo).
- **Trajetórias de diferenciação**: ordenar computacionalmente células capturadas em um único momento ao longo de um caminho de diferenciação inferido, revelando estados intermediários entre um tipo celular precursor e um maduro.

---

## Teste seus conhecimentos

??? question "1. Qual é a principal vantagem dos métodos baseados em microgotas sobre os baseados em placa?"
    Throughput: métodos baseados em microgotas (como o 10x Genomics) conseguem processar dezenas de milhares de células em paralelo, no mesmo experimento, contra tipicamente algumas centenas em métodos baseados em placa. A troca é que geralmente capturam só uma extremidade do transcrito, em vez da sequência completa.

??? question "2. Por que um UMI é diferente do código de barras de célula?"
    O código de barras de célula identifica de qual célula (ou gota) veio a leitura — todo o RNA capturado na mesma gota recebe o mesmo código. O UMI identifica uma molécula de RNA individual, antes da amplificação por PCR — permitindo colapsar múltiplas cópias PCR da mesma molécula original em uma única contagem, corrigindo o viés de amplificação.

??? question "3. Uma célula mostra contagem zero para um gene que se sabe, por outros métodos, estar ativo nela. Isso prova que o scRNA-seq errou?"
    Não necessariamente — é provavelmente um caso de dropout: a quantidade de RNA de partida por célula é tão pequena que a molécula específica daquele gene pode simplesmente não ter sido capturada por acaso, mesmo que o gene estivesse realmente ativo. É por isso que os dados de célula única são caracteristicamente esparsos, com muitos zeros técnicos misturados aos zeros biológicos reais.

??? question "4. Por que a normalização em scRNA-seq é especialmente importante antes de comparar células?"
    Porque a profundidade de captura (quantas moléculas de RNA foram efetivamente sequenciadas) varia bastante de célula para célula, por razões puramente técnicas — tamanho da célula, eficiência de lise, captura na gota. Sem normalizar por isso, uma célula com maior profundidade de captura pareceria ter "mais expressão" de quase todo gene, mesmo sem nenhuma diferença biológica real.

---

## Referências

[^1]: Tang F, Barbacioru C, Wang Y, et al. mRNA-Seq whole-transcriptome analysis of a single cell. *Nature Methods*. 2009;6(5):377–382. doi: [10.1038/nmeth.1315](https://doi.org/10.1038/nmeth.1315).

[^2]: Macosko EZ, Basu A, Satija R, et al. Highly Parallel Genome-wide Expression Profiling of Individual Cells Using Nanoliter Droplets. *Cell*. 2015;161(5):1202–1214. doi: [10.1016/j.cell.2015.05.002](https://doi.org/10.1016/j.cell.2015.05.002).

[^3]: Zheng GXY, Terry JM, Belgrader P, et al. Massively parallel digital transcriptional profiling of single cells. *Nature Communications*. 2017;8:14049. doi: [10.1038/ncomms14049](https://doi.org/10.1038/ncomms14049).

[^4]: Picelli S, Faridani OR, Björklund AK, Winberg G, Sagasser S, Sandberg R. Full-length RNA-seq from single cells using Smart-seq2. *Nature Protocols*. 2014;9(1):171–181. doi: [10.1038/nprot.2014.006](https://doi.org/10.1038/nprot.2014.006).

[^5]: Islam S, Zeisel A, Joost S, et al. Quantitative single-cell RNA-seq with unique molecular identifiers. *Nature Methods*. 2014;11(2):163–166. doi: [10.1038/nmeth.2772](https://doi.org/10.1038/nmeth.2772).

[^6]: Luecken MD, Theis FJ. Current best practices in single-cell RNA-seq analysis: a tutorial. *Molecular Systems Biology*. 2019;15(6):e8746. doi: [10.15252/msb.20188746](https://doi.org/10.15252/msb.20188746).
