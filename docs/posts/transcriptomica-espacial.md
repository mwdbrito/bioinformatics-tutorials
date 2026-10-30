---
title: "Transcriptômica espacial"
description: "Transcriptômica espacial: como medir a expressão gênica preservando a posição de cada célula no tecido, e quando escolher métodos por imagem ou por sequenciamento."
serie: "Como medimos o transcriptoma"
parte: 3
de: 3
tags:
  - Postagem
  - Transcriptômica Espacial
  - Transcriptômica
  - Single-cell
---

# 🗺️ Transcriptômica Espacial

> **A pergunta que sobra depois de resolver "quais tipos celulares existem": onde, exatamente, cada um está no tecido — e por que isso importa biologicamente.**

!!! tip "Para quem tem pressa"
    A [transcriptômica de célula única](rna-seq-celula-unica.md) revela quais tipos celulares e estados existem em uma amostra — mas exige dissociar o tecido em uma suspensão de células soltas antes de sequenciar, destruindo de forma irreversível a informação de onde cada célula estava originalmente. A transcriptômica espacial mede a expressão gênica **preservando essa coordenada** — por meio de imagem (alta resolução, número limitado de genes) ou de sequenciamento em grade (todo o transcriptoma, resolução menor). A escolha entre as duas famílias depende diretamente da pergunta biológica.

Este é o terceiro texto de uma série sobre como medimos o transcriptoma. Os anteriores cobriram o [RNA-Seq bulk](rna-seq-bulk.md) e a [transcriptômica de célula única](rna-seq-celula-unica.md).

## Sumário

1. [O que se perde ao dissociar um tecido](#o-que-se-perde-ao-dissociar-um-tecido)
2. [Duas famílias de tecnologias](#duas-familias-de-tecnologias)
3. [O problema do "spot" com várias células](#o-problema-do-spot-com-varias-celulas)
4. [Comparando as principais plataformas](#comparando-as-principais-plataformas)
5. [Aplicações](#aplicacoes)
6. [Teste seus conhecimentos](#teste-seus-conhecimentos)
7. [Referências](#referencias)

---

## O que se perde ao dissociar um tecido

<div class="mw-widget" id="spt-widget">
<style>
#spt-widget { border: 1px solid var(--md-default-fg-color--lightest); border-radius: 10px; padding: 20px; margin: 1.5rem 0; background: var(--md-default-bg-color); }
#spt-widget h4 { margin-top:0; margin-bottom:4px; font-size:1.05rem; }
#spt-widget .spt-sub { color: var(--md-default-fg-color--light); font-size:0.85rem; margin-bottom:14px; }
#spt-widget .spt-tabs { display:flex; gap:8px; margin-bottom:14px; }
#spt-widget .spt-tab { padding:7px 16px; border-radius:20px; border:1.5px solid var(--md-default-fg-color--lightest); cursor:pointer; font-size:0.85rem; font-weight:600; background:transparent; color:var(--md-default-fg-color); }
#spt-widget .spt-tab.active { background:#00695c; border-color:#00695c; color:#fff; }
#spt-widget svg { width:100%; height:auto; display:block; }
#spt-widget .spt-note { font-size:0.82rem; color:var(--md-default-fg-color--light); margin-top:10px; min-height:3.2em; }
</style>
<h4>&#128205; O que se perde ao dissociar um tecido</h4>
<div class="spt-sub">O mesmo corte de tecido (ex.: uma borda de tumor), com três tipos celulares organizados em zonas.</div>
<div class="spt-tabs">
  <button class="spt-tab active" data-t="tissue">Tecido intacto (espacial)</button>
  <button class="spt-tab" data-t="dissoc">Após dissociação (scRNA-seq)</button>
</div>
<svg id="spt-svg" viewBox="0 0 760 320" xmlns="http://www.w3.org/2000/svg"></svg>
<div class="spt-note" id="spt-note"></div>
<script>
(function(){
  var svg = document.getElementById('spt-svg');
  var note = document.getElementById('spt-note');
  var tabs = document.querySelectorAll('#spt-widget .spt-tab');
  var current = 'tissue';

  var notes = {
    tissue: 'Em transcriptômica espacial, cada célula (ou spot) mantém sua coordenada de origem no tecido. Fica visível, por exemplo, que as células imunes se concentram na borda do tumor, não espalhadas de forma aleatória — uma informação biológica que só existe enquanto a posição é preservada.',
    dissoc: 'Para fazer scRNA-seq "tradicional", o tecido precisa ser dissociado em uma suspensão de células individuais antes do sequenciamento. As mesmas células ainda são medidas uma a uma — mas a informação de onde cada uma estava no tecido original é perdida de forma irreversível nesse processo.'
  };

  function svgEl(tag, attrs){
    var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (var k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  }

  // fixed cell positions for "tissue" view: immune cells clustered at the border (left edge),
  // tumor cells filling the core, stromal cells scattered at the right edge
  var _seed = 7;
  function seededRand(){ _seed = (_seed*9301+49297)%233280; return _seed/233280; }
  var cells = [];
  (function(){
    // tumor core
    for (var i=0;i<28;i++){
      cells.push({x: 260+seededRand()*300, y: 60+seededRand()*200, type:'tumor'});
    }
    // immune border (left band)
    for (var i=0;i<14;i++){
      cells.push({x: 150+seededRand()*70, y: 50+seededRand()*220, type:'imune'});
    }
    // stromal (right band)
    for (var i=0;i<10;i++){
      cells.push({x: 590+seededRand()*80, y: 60+seededRand()*200, type:'estroma'});
    }
  })();
  var colors = {tumor:'#e57373', imune:'#4fc3f7', estroma:'#aed581'};

  // shuffled random positions for "dissociated" view (same cells, no spatial pattern)
  var shuffled = cells.map(function(c){ return c; });
  function seedShuffle(arr){
    var out = arr.slice();
    var seed = 42;
    function rnd(){ seed = (seed*9301+49297)%233280; return seed/233280; }
    for (var i=out.length-1;i>0;i--){
      var j = Math.floor(rnd()*(i+1));
      var tmp = out[i]; out[i]=out[j]; out[j]=tmp;
    }
    return out;
  }
  var order = seedShuffle(cells);

  function render(){
    svg.innerHTML = '';
    svg.appendChild(svgEl('rect', {x:0,y:0,width:760,height:320, fill:'#fafafa', rx:8}));

    if (current === 'tissue'){
      svg.appendChild(svgEl('rect', {x:130,y:30,width:520,height:260, fill:'none', stroke:'#bdbdbd','stroke-width':1.5,'stroke-dasharray':'5,4'}));
      svg.appendChild(svgEl('text', {x:390,y:22,'font-size':11,'text-anchor':'middle',fill:'#757575'})).textContent='corte de tecido';
      cells.forEach(function(c){
        svg.appendChild(svgEl('circle', {cx:c.x, cy:c.y, r:7, fill:colors[c.type], opacity:0.85}));
      });
    } else {
      // grid layout, random order -> spatial info destroyed
      var cols = 13, gap = 42, x0 = 160, y0 = 55;
      order.forEach(function(c, i){
        var col = i % cols, row = Math.floor(i/cols);
        svg.appendChild(svgEl('circle', {cx:x0+col*gap, cy:y0+row*gap, r:7, fill:colors[c.type], opacity:0.85}));
      });
      svg.appendChild(svgEl('text', {x:390,y:270,'font-size':11,'text-anchor':'middle',fill:'#757575','font-style':'italic'})).textContent='mesmas células, ordem/posição original perdida';
    }

    var ly = 300;
    var types = [['tumor','Tumoral'],['imune','Imune'],['estroma','Estromal']];
    types.forEach(function(t, i){
      var lx = 260 + i*160;
      svg.appendChild(svgEl('circle', {cx:lx, cy:ly, r:7, fill:colors[t[0]]}));
      svg.appendChild(svgEl('text', {x:lx+13, y:ly+4, 'font-size':11.5, 'text-anchor':'start', fill:'#333'})).textContent=t[1];
    });
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


Muitas perguntas biológicas são inseparáveis de posição: onde, na margem de um tumor, as células imunes se concentram; como a expressão gênica muda ao longo do eixo de uma vilosidade intestinal; quais células vizinhas se comunicam fisicamente no córtex cerebral. Depois que um tecido é dissociado em uma suspensão de células soltas, nenhuma quantidade de análise computacional recupera essa informação — ela precisa ser preservada no momento da medição, não reconstruída depois.

A ideia de medir expressão gênica preservando a posição não é nova (técnicas de hibridização *in situ* existem há décadas, mas historicamente limitadas a um punhado de genes por vez); o que mudou na última década foi a escala — de alguns genes para o transcriptoma inteiro, sem perder a coordenada espacial[^1].

---

## Duas famílias de tecnologias

As dezenas de métodos de transcriptômica espacial publicados na última década se organizam, na prática, em duas grandes famílias[^4][^5]:

### Baseadas em imagem (hibridização *in situ*)

Sondas fluorescentes se ligam diretamente a moléculas de RNA específicas dentro da célula intacta, ainda no tecido; múltiplas rodadas de hibridização, imageamento e remoção das sondas permitem distinguir dezenas a milhares de genes diferentes pelo padrão de cores ao longo dos ciclos (código de barras combinatório). Exemplos: **MERFISH**[^2], **seqFISH**. A resolução é subcelular — dá para saber não só em qual célula um transcrito está, mas em qual região dela — mas o número de genes que se consegue medir por experimento é limitado (de dezenas a poucos milhares), porque cada gene extra exige mais rodadas de imageamento.

### Baseadas em sequenciamento (captura posicional)

Uma superfície é coberta por milhares de posições conhecidas (*spots*), cada uma com oligonucleotídeos que carregam um **código de barras espacial exclusivo daquela posição** — o mesmo princípio dos códigos de barras de célula em scRNA-seq, mas identificando um local no tecido, não uma célula. O tecido é colocado sobre a superfície, o RNA de cada posição é capturado pelos oligonucleotídeos ali presentes, e sequenciado em bloco — depois, o código de barras espacial permite reconstruir de qual posição cada leitura veio. Exemplos: a plataforma **Visium**, herdeira direta do método original de "espacial transcriptomics" publicado em 2016[^1], e o **Slide-seq**, que usa esferas com código de barras em vez de uma grade impressa, para maior resolução[^3]. Captura o transcriptoma inteiro (não um painel limitado de genes), mas cada posição, no desenho clássico, cobre uma área maior do que uma única célula.

!!! info "A linha entre as duas famílias está ficando mais tênue"
    Gerações mais recentes de cada abordagem vêm fechando essas diferenças históricas: plataformas de sequenciamento com posições cada vez menores (como o Stereo-seq e o Visium HD) já se aproximam de resolução subcelular, enquanto plataformas baseadas em imagem (como o Xenium) ampliam continuamente o número de genes mensuráveis por experimento.

---

## O problema do "spot" com várias células

No desenho clássico das plataformas baseadas em sequenciamento, cada posição capturada (*spot*) costuma ser maior do que uma única célula — o que significa que a leitura daquele spot é, na prática, uma **pequena mistura** do RNA de várias células vizinhas, não de uma célula isolada. É essencialmente o mesmo problema do RNA-Seq bulk (uma média mascarando identidades individuais), só que em escala muito menor — poucas células por spot, em vez de milhões por amostra.

A solução mais comum é computacional: usar um conjunto de referência de transcriptômica de célula única do mesmo tipo de tecido (o texto anterior desta série) para estimar, por **deconvolução**, qual proporção de cada tipo celular provavelmente compõe cada spot — combinando o melhor dos dois métodos em vez de escolher um só.

---

## Comparando as principais plataformas

| Característica | Baseada em imagem (MERFISH, seqFISH) | Baseada em sequenciamento (Visium, Slide-seq) |
|---|---|---|
| Cobertura de genes | Painel limitado (dezenas a milhares) | Transcriptoma completo |
| Resolução espacial | Subcelular | Depende da plataforma — de várias células a quase subcelular nas gerações mais novas |
| Necessita gene-alvo pré-definido? | Sim — só mede o que está no painel | Não — captura tudo que está presente |
| Uso típico | Estudar um conjunto conhecido de genes com máxima resolução | Descoberta aberta, sem hipótese prévia sobre quais genes importam |

---

## Aplicações

- **Microambiente tumoral**: mapear como células imunes, vasos sanguíneos e células tumorais se organizam espacialmente umas em relação às outras — informação central para entender por que alguns tumores respondem a imunoterapia e outros não.
- **Atlas de tecidos com contexto espacial**: expandir os atlas celulares (mencionados no texto anterior) com a informação de onde cada tipo celular efetivamente se localiza dentro do órgão.
- **Biologia do desenvolvimento**: acompanhar como a expressão gênica se organiza espacialmente ao longo de um embrião em formação, algo impossível de reconstruir a partir de uma suspensão dissociada de células.

---

## Teste seus conhecimentos

??? question "1. Qual é a limitação fundamental que a transcriptômica espacial resolve, e que nem o bulk nem o scRNA-seq resolvem sozinhos?"
    A preservação da posição original de cada célula (ou região) dentro do tecido. Tanto o bulk quanto o scRNA-seq exigem, em algum grau, misturar ou dissociar a amostra antes de medir — destruindo essa informação espacial de forma irreversível.

??? question "2. Por que uma plataforma baseada em imagem, como o MERFISH, normalmente mede um número limitado de genes, enquanto uma baseada em sequenciamento captura o transcriptoma inteiro?"
    Porque cada gene extra em uma plataforma de imagem exige rodadas adicionais de hibridização e imageamento com sondas específicas para aquele gene — um custo que cresce com o número de genes. Plataformas baseadas em sequenciamento capturam todo RNA presente em cada posição indiscriminadamente, sem precisar de uma sonda desenhada para cada gene com antecedência.

??? question "3. O que significa dizer que um spot em uma plataforma como o Visium clássico precisa de 'deconvolução'?"
    Significa que aquele spot capturou uma mistura do RNA de várias células vizinhas ao mesmo tempo (porque a área do spot é maior que uma célula única) — deconvolução é o processo computacional de estimar, usando uma referência de célula única do mesmo tecido, qual proporção de cada tipo celular provavelmente compõe o sinal misturado daquele spot.

---

## Referências

[^1]: Ståhl PL, Salmén F, Vickovic S, et al. Visualization and analysis of gene expression in tissue sections by spatial transcriptomics. *Science*. 2016;353(6294):78–82. doi: [10.1126/science.aaf2403](https://doi.org/10.1126/science.aaf2403).

[^2]: Chen KH, Boettiger AN, Moffitt JR, Wang S, Zhuang X. Spatially resolved, highly multiplexed RNA profiling in single cells. *Science*. 2015;348(6233):aaa6090. doi: [10.1126/science.aaa6090](https://doi.org/10.1126/science.aaa6090).

[^3]: Rodriques SG, Stickels RR, Goeva A, et al. Slide-seq: A scalable technology for measuring genome-wide expression at high spatial resolution. *Science*. 2019;363(6434):1463–1467. doi: [10.1126/science.aaw1219](https://doi.org/10.1126/science.aaw1219).

[^4]: Moses L, Pachter L. Museum of spatial transcriptomics. *Nature Methods*. 2022;19(5):534–546. doi: [10.1038/s41592-022-01409-2](https://doi.org/10.1038/s41592-022-01409-2).

[^5]: Rao A, Barkley D, França GS, Yanai I. Exploring tissue architecture using spatial transcriptomics. *Nature*. 2021;596(7871):211–220. doi: [10.1038/s41586-021-03634-9](https://doi.org/10.1038/s41586-021-03634-9).
