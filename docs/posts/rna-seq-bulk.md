---
title: "RNA-Seq bulk"
description: "Como o RNA-Seq bulk mede a expressão gênica: preparo de biblioteca, sequenciamento por síntese, alinhamento e o que essa média do transcriptoma esconde."
serie: "Como medimos o transcriptoma"
parte: 1
de: 3
tags:
  - Postagem
  - RNA-Seq
  - Transcriptômica
  - Illumina
  - NGS
---

# 🧬 RNA-Seq (Bulk): a Fotografia Média do Transcriptoma

> **Como o método de sequenciamento mais usado em transcriptômica mede a expressão gênica — e o que essa "fotografia média" mostra, e esconde.**

!!! tip "Para quem tem pressa"
    "Bulk" RNA-Seq sequencia o RNA extraído de uma amostra inteira — milhares a milhões de células misturadas — e devolve **uma média** da expressão de cada gene naquela mistura. É o método mais barato, mais maduro e mais usado em transcriptômica, mas essa média esconde qualquer diferença entre os tipos celulares presentes na amostra. Este texto cobre a teoria: o que a biblioteca de sequenciamento captura (e o que não captura), como as leituras voltam a fazer sentido biológico depois de alinhadas, e onde o bulk RNA-Seq começa a mostrar seus limites.

Este é o primeiro de três textos sobre como medimos o transcriptoma — os outros dois cobrem [transcriptômica de célula única](rna-seq-celula-unica.md) e [transcriptômica espacial](transcriptomica-espacial.md), cada um resolvendo uma limitação do anterior.

## Sumário

1. [O que "bulk" quer dizer](#o-que-bulk-quer-dizer)
2. [Do RNA ao FASTQ: preparo de biblioteca](#do-rna-ao-fastq-preparo-de-biblioteca)
3. [A química por trás da leitura: sequenciamento por síntese](#a-quimica-por-tras-da-leitura-sequenciamento-por-sintese)
4. [Do FASTQ de volta ao genoma: o desafio do splicing](#do-fastq-de-volta-ao-genoma-o-desafio-do-splicing)
5. [O que se obtém no final](#o-que-se-obtem-no-final)
6. [Onde o bulk mostra seus limites](#onde-o-bulk-mostra-seus-limites)
7. [Teste seus conhecimentos](#teste-seus-conhecimentos)
8. [Referências](#referencias)

---

## O que "bulk" quer dizer

Toda célula de um organismo multicelular carrega, em princípio, o mesmo DNA — mas não usa o mesmo conjunto de genes ao mesmo tempo. Um neurônio e uma célula de fígado têm o mesmo genoma e transcriptomas radicalmente diferentes. O **RNA-Seq** mede exatamente isso: não a sequência do DNA, mas quais genes estão sendo ativamente transcritos, e em que quantidade, em um dado momento.

"Bulk" (em bloco) descreve *como* a amostra é preparada: extrai-se o RNA de uma amostra inteira — um pedaço de tecido, um poço de cultura celular, uma gota de sangue — sem separar os tipos celulares presentes. O sequenciador não sabe, e não pode saber, de qual célula individual veio cada molécula de RNA. O resultado é uma **média**, ponderada pela proporção de cada tipo celular na amostra original.

Essa é a abordagem dominante em transcriptômica desde meados dos anos 2000[^1] — mais barata e tecnicamente mais simples do que as alternativas mais recentes que veremos nos próximos dois textos, e ainda hoje a escolha certa para a maioria das perguntas biológicas que não exigem resolução por célula.

---

## Do RNA ao FASTQ: preparo de biblioteca

Antes de qualquer sequenciamento, é preciso transformar o RNA extraído em uma "biblioteca" — fragmentos de tamanho adequado, convertidos para DNA complementar (cDNA), com adaptadores que o sequenciador reconhece. Uma decisão feita nessa etapa determina, sozinha, boa parte do que a análise final vai conseguir enxergar: **como selecionar qual RNA entra na biblioteca**.

O RNA total de uma célula é dominado por RNA ribossômico (rRNA) — cerca de 80% de toda a massa de RNA — que raramente é o alvo biológico de interesse. Existem duas estratégias principais para lidar com isso:

<div class="mw-widget" id="libprep-widget">
<style>
#libprep-widget { border: 1px solid var(--md-default-fg-color--lightest); border-radius: 10px; padding: 20px; margin: 1.5rem 0; background: var(--md-default-bg-color); }
#libprep-widget h4 { margin-top:0; margin-bottom:4px; font-size:1.05rem; }
#libprep-widget .lp-sub { color: var(--md-default-fg-color--light); font-size:0.85rem; margin-bottom:14px; }
#libprep-widget .lp-tabs { display:flex; gap:8px; margin-bottom:14px; }
#libprep-widget .lp-tab { padding:7px 16px; border-radius:20px; border:1.5px solid var(--md-default-fg-color--lightest); cursor:pointer; font-size:0.85rem; font-weight:600; background:transparent; color:var(--md-default-fg-color); }
#libprep-widget .lp-tab.active { background:#00695c; border-color:#00695c; color:#fff; }
#libprep-widget svg { width:100%; height:auto; display:block; }
#libprep-widget .lp-note { font-size:0.82rem; color:var(--md-default-fg-color--light); margin-top:10px; min-height:3em; }
</style>
<h4>&#129514; Preparo de biblioteca: o que cada método captura</h4>
<div class="lp-sub">O mesmo conjunto de RNAs de uma célula, visto por duas estratégias de preparo diferentes.</div>
<div class="lp-tabs">
  <button class="lp-tab active" data-t="polya">Seleção por poli-A</button>
  <button class="lp-tab" data-t="ribo">Depleção de rRNA</button>
</div>
<svg id="lp-svg" viewBox="0 0 760 300" xmlns="http://www.w3.org/2000/svg"></svg>
<div class="lp-note" id="lp-note"></div>
<script>
(function(){
  var svg = document.getElementById('lp-svg');
  var note = document.getElementById('lp-note');
  var tabs = document.querySelectorAll('#libprep-widget .lp-tab');
  var current = 'polya';

  var rnas = [
    {name:'mRNA (poliadenilado)', x:70,  polya:true,  ribo:true},
    {name:'rRNA (muito abundante)', x:240, polya:false, ribo:false},
    {name:'lncRNA (não poliadenilado)', x:410, polya:false, ribo:true},
    {name:'pré-mRNA / intrônico', x:580, polya:false, ribo:true},
  ];

  var notes = {
    polya: 'A seleção por poli-A captura apenas transcritos com cauda poli-A (majoritariamente mRNA maduro) — simples e eficiente para estudar genes codificantes, mas perde RNAs não poliadenilados e tem viés de cobertura na extremidade 3\u2019 em transcritos longos.',
    ribo: 'A depleção de rRNA remove só o rRNA (que é ~80% do RNA total de uma célula) e mantém todo o resto — captura mRNA, lncRNAs, RNA intrônico e transcritos não poliadenilados, com cobertura mais uniforme, ao custo de precisar de mais profundidade de sequenciamento.'
  };

  function svgEl(tag, attrs){
    var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (var k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  }

  function render(){
    svg.innerHTML = '';
    svg.appendChild(svgEl('rect', {x:0,y:0,width:760,height:300, fill:'#fafafa', rx:8}));
    rnas.forEach(function(r){
      var captured = current === 'polya' ? r.polya : r.ribo;
      var color = captured ? '#00897b' : '#cfd8dc';
      svg.appendChild(svgEl('rect', {x:r.x, y:90, width:130, height:36, rx:18, fill:color}));
      var lines = r.name.split(' ');
      var mid = Math.ceil(lines.length/2);
      var l1 = lines.slice(0,mid).join(' '), l2 = lines.slice(mid).join(' ');
      var t1 = svgEl('text', {x:r.x+65, y:145, 'font-size':11, 'text-anchor':'middle', fill:'#333'});
      t1.textContent = l1;
      svg.appendChild(t1);
      if (l2){
        var t2 = svgEl('text', {x:r.x+65, y:160, 'font-size':11, 'text-anchor':'middle', fill:'#333'});
        t2.textContent = l2;
        svg.appendChild(t2);
      }
      var status = svgEl('text', {x:r.x+65, y:113, 'font-size':12, 'text-anchor':'middle', fill:'#fff', 'font-weight':'700'});
      status.textContent = captured ? '\u2713 capturado' : '\u2717 perdido';
      svg.appendChild(status);
    });
    var title = svgEl('text', {x:380, y:40, 'font-size':14, 'text-anchor':'middle', fill:'#333', 'font-weight':'700'});
    title.textContent = current === 'polya' ? 'Biblioteca por seleção de poli-A' : 'Biblioteca por depleção de rRNA';
    svg.appendChild(title);
    note.textContent = notes[current];
  }

  for (var i=0;i<tabs.length;i++){
    (function(tab){
      tab.addEventListener('click', function(){
        for (var j=0;j<tabs.length;j++){ tabs[j].classList.remove('active'); }
        tab.classList.add('active');
        current = tab.getAttribute('data-t');
        render();
      });
    })(tabs[i]);
  }
  render();
})();
</script>
</div>


!!! info "Qual escolher?"
    A seleção por poli-A é suficiente e mais barata quando o interesse está em genes codificantes de proteína bem preservados. A depleção de rRNA é preferível para RNA de qualidade degradada (comum em amostras de arquivo, fixadas em formalina), para estudar RNAs não-codificantes, ou quando a cobertura uniforme ao longo do transcrito importa — como para estudar isoformas e splicing alternativo. Comparações diretas mostram que a depleção de rRNA detecta consistentemente mais transcritos longos e mais eventos de splicing alternativo do que a seleção por poli-A, ao custo de precisar de mais profundidade de sequenciamento para compensar o RNA intrônico e não-codificante que também é capturado[^2][^3].

---

## A química por trás da leitura: sequenciamento por síntese

A tecnologia que domina o mercado de sequenciamento hoje — incluindo a maior parte do RNA-Seq bulk publicado — é a da Illumina, baseada em **sequenciamento por síntese com terminadores reversíveis**[^4]. Em resumo:

1. Os fragmentos de cDNA, com adaptadores nas pontas, são espalhados sobre uma superfície de vidro (*flow cell*) coberta de sequências complementares aos adaptadores.
2. Cada fragmento é amplificado no local por PCR em ponte (*bridge amplification*), formando um pequeno agrupamento (*cluster*) de milhares de cópias idênticas — necessário porque uma única molécula não emite sinal óptico suficiente para ser detectada.
3. A cada ciclo, todos os clusters da *flow cell* incorporam simultaneamente uma única base marcada com um corante fluorescente e um terminador reversível (que impede a incorporação de mais de uma base por ciclo). Uma câmera fotografa a *flow cell* inteira, registrando a cor emitida por cada cluster.
4. O terminador é quimicamente removido, liberando a extremidade para o próximo ciclo — repetindo-se dezenas a centenas de vezes, uma base por vez, em todos os clusters ao mesmo tempo.

É esse paralelismo — milhões de clusters lidos simultaneamente, ciclo a ciclo — que caracteriza o sequenciamento de nova geração como um todo, tema do [post anterior desta série](sequenciamento-de-dna.md#a-revolucao-do-ngs-2a-geracao).

---

## Do FASTQ de volta ao genoma: o desafio do splicing

O sequenciador devolve milhões de curtas sequências de texto (as *reads*, tipicamente 50–150 pares de bases, em um arquivo FASTQ) — sem nenhuma informação sobre de qual gene ou posição do genoma cada uma veio. Descobrir isso é o trabalho do **alinhamento**.

Para DNA, alinhar é relativamente direto: procurar, no genoma de referência, a posição cuja sequência mais se parece com a *read*. Para RNA-Seq, há uma complicação: o RNA maduro que foi sequenciado já teve os **íntrons removidos** pelo *splicing* — então uma *read* pode vir de um trecho que, no genoma, está dividido em dois pedaços distantes (dois éxons separados por um íntron), mas que no RNA maduro são adjacentes.

<div class="mw-widget" id="splice-widget">
<style>
#splice-widget { border: 1px solid var(--md-default-fg-color--lightest); border-radius: 10px; padding: 20px; margin: 1.5rem 0; background: var(--md-default-bg-color); }
#splice-widget h4 { margin-top:0; margin-bottom:4px; font-size:1.05rem; }
#splice-widget .sp-sub { color: var(--md-default-fg-color--light); font-size:0.85rem; margin-bottom:14px; }
#splice-widget .sp-btn { padding:7px 16px; border-radius:20px; border:1.5px solid #00695c; cursor:pointer; font-size:0.85rem; font-weight:600; background:#00695c; color:#fff; margin-bottom:14px; }
#splice-widget svg { width:100%; height:auto; display:block; }
#splice-widget .sp-note { font-size:0.82rem; color:var(--md-default-fg-color--light); margin-top:10px; }
</style>
<h4>&#129516; Por que alinhar RNA-Seq precisa "saber" sobre splicing</h4>
<div class="sp-sub">Clique no botão para ver uma read atravessando uma junção éxon-éxon sendo alinhada de volta ao genoma.</div>
<button class="sp-btn" id="sp-btn">Mostrar o alinhamento</button>
<svg id="sp-svg" viewBox="0 0 760 260" xmlns="http://www.w3.org/2000/svg"></svg>
<div class="sp-note">Uma read de RNA-Seq vem do RNA maduro (íntrons já removidos) — se ela cair sobre uma junção éxon-éxon, suas duas metades estão distantes no genoma, mas adjacentes no transcrito. Alinhadores "cientes de splicing", como o STAR, resolvem isso permitindo que a read se divida (split) e alinhe em dois lugares diferentes do genoma ao mesmo tempo.</div>
<script>
(function(){
  var svg = document.getElementById('sp-svg');
  var btn = document.getElementById('sp-btn');
  var shown = false;

  function svgEl(tag, attrs){
    var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (var k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  }

  function render(){
    svg.innerHTML = '';
    svg.appendChild(svgEl('rect', {x:0,y:0,width:760,height:260, fill:'#fafafa', rx:8}));

    // genome track with exons and intron
    var gy = 60;
    svg.appendChild(svgEl('line', {x1:60,y1:gy,x2:700,y2:gy, stroke:'#9e9e9e','stroke-width':3}));
    svg.appendChild(svgEl('rect', {x:60,y:gy-10,width:160,height:20, fill:'#00897b', rx:4}));
    svg.appendChild(svgEl('text', {x:140,y:gy-16,'font-size':11,'text-anchor':'middle',fill:'#333'})).textContent='Éxon 1';
    svg.appendChild(svgEl('rect', {x:540,y:gy-10,width:160,height:20, fill:'#00897b', rx:4}));
    svg.appendChild(svgEl('text', {x:620,y:gy-16,'font-size':11,'text-anchor':'middle',fill:'#333'})).textContent='Éxon 2';
    svg.appendChild(svgEl('text', {x:380,y:gy-16,'font-size':11,'text-anchor':'middle',fill:'#757575'})).textContent='Íntron (removido no RNA maduro)';
    svg.appendChild(svgEl('text', {x:30,y:gy+4,'font-size':11,'text-anchor':'start',fill:'#333'})).textContent='DNA';

    // mature RNA track
    var ry = 140;
    svg.appendChild(svgEl('rect', {x:250,y:ry-10,width:80,height:20, fill:'#0097a7', rx:4}));
    svg.appendChild(svgEl('rect', {x:330,y:ry-10,width:80,height:20, fill:'#26a69a', rx:4}));
    svg.appendChild(svgEl('text', {x:30,y:ry+4,'font-size':11,'text-anchor':'start',fill:'#333'})).textContent='RNA maduro';
    svg.appendChild(svgEl('text', {x:410,y:ry+30,'font-size':10,'text-anchor':'middle',fill:'#757575','font-style':'italic'})).textContent='éxons agora adjacentes';

    if (shown){
      // the read spanning the junction
      var readX = 270, readW = 80;
      svg.appendChild(svgEl('rect', {x:readX,y:ry-10,width:readW,height:20, fill:'none', stroke:'#e53935','stroke-width':2.5, rx:4}));
      svg.appendChild(svgEl('text', {x:readX+readW/2,y:ry-16,'font-size':10,'text-anchor':'middle',fill:'#e53935','font-weight':'700'})).textContent='read (atravessa a junção)';

      // split alignment arrows down to genome
      svg.appendChild(svgEl('line', {x1:readX+15,y1:ry-12,x2:180,y2:gy+12, stroke:'#e53935','stroke-width':1.8,'stroke-dasharray':'4,3'}));
      svg.appendChild(svgEl('line', {x1:readX+readW-15,y1:ry-12,x2:580,y2:gy+12, stroke:'#e53935','stroke-width':1.8,'stroke-dasharray':'4,3'}));
      svg.appendChild(svgEl('text', {x:380,y:200,'font-size':11,'text-anchor':'middle',fill:'#e53935','font-weight':'600'})).textContent='alinhamento dividido (split) — as duas metades mapeiam em lugares distantes do genoma';
    }
  }

  btn.addEventListener('click', function(){ shown = !shown; btn.textContent = shown ? 'Ocultar o alinhamento' : 'Mostrar o alinhamento'; render(); });
  render();
})();
</script>
</div>


Alinhadores "cientes de splicing" — como o STAR, hoje um dos mais usados para esse propósito[^5] — resolvem isso permitindo que uma única *read* se divida (*split*) e alinhe simultaneamente em duas posições distantes do genoma, desde que essa divisão coincida com os limites conhecidos (ou detectáveis) de um éxon. Uma alternativa mais recente e mais rápida, usada no tutorial de RNA-Seq deste site (em preparação), é a **pseudo-alinhamento** (Salmon), que evita alinhar posição por posição e estima diretamente de qual transcrito cada *read* provavelmente veio[^6].

---

## O que se obtém no final

Depois do alinhamento (ou pseudo-alinhamento) e da contagem de quantas *reads* caem sobre cada gene, o resultado é uma **matriz de contagens**: uma linha por gene, uma coluna por amostra. É esse arquivo — não o FASTQ bruto — que alimenta a análise estatística de expressão diferencial, que será coberta em detalhe nos tutoriais de pipeline de RNA-Seq e de estatística do DESeq2 deste site (em preparação).

Vale notar que o RNA-Seq bulk não mede só mRNA de genes codificantes de proteína — dependendo do preparo de biblioteca (seção acima), ele também captura RNAs não-codificantes de diferentes classes, cada um com uma função distinta na célula[^7]:

| Tipo de RNA | Função principal |
|---|---|
| mRNA | Codifica proteínas |
| rRNA, tRNA | Maquinaria de tradução |
| miRNA | Regulação gênica pós-transcricional |
| lncRNA | Regulação da transcrição e da cromatina |
| circRNA | Regulação gênica; função varia com a localização |
| snRNA, snoRNA | Processamento e modificação de outros RNAs |

---

## Onde o bulk mostra seus limites

A média que o bulk RNA-Seq produz é, ao mesmo tempo, sua maior força (simplicidade, custo, décadas de ferramentas maduras) e sua limitação mais fundamental: **ela existe apenas porque a identidade individual de cada célula foi apagada** no momento em que o RNA de todas elas foi misturado antes do sequenciamento.

Isso importa quando a pergunta biológica é sobre heterogeneidade — quando amostras diferentes contêm proporções diferentes de tipos celulares (um tumor com mais ou menos infiltração imune, por exemplo), o bulk RNA-Seq não consegue distinguir "o mesmo tipo de célula mudou de comportamento" de "a proporção dos tipos celulares na amostra mudou". As duas situações produzem o mesmo tipo de resultado: um gene que parece diferencialmente expresso.

É exatamente esse problema que a **transcriptômica de célula única** foi desenhada para resolver — tema do próximo texto desta série.

---

## Teste seus conhecimentos

??? question "1. Por que a maioria dos protocolos de RNA-Seq remove o rRNA antes de sequenciar, de um jeito ou de outro?"
    Porque o rRNA responde por cerca de 80% de todo o RNA de uma célula, mas raramente é o alvo biológico de interesse. Sem removê-lo (seja selecionando poli-A, que naturalmente o exclui, seja depletando-o diretamente), a maior parte da capacidade de sequenciamento seria gasta lendo rRNA em vez dos transcritos que interessam.

??? question "2. Uma pesquisadora quer estudar splicing alternativo em RNA de uma amostra de biópsia de arquivo (FFPE), potencialmente degradada. Poli-A ou depleção de rRNA?"
    Depleção de rRNA. RNA degradado frequentemente perde a cauda poli-A, o que faria a seleção por poli-A capturar muito pouco material. Além disso, estudar splicing alternativo exige cobertura ao longo de todo o transcrito, não concentrada na extremidade 3', que é exatamente o viés que a depleção de rRNA evita.

??? question "3. O que significa uma read de RNA-Seq alinhar de forma 'dividida' (split) ao genoma?"
    Significa que a read atravessa uma junção éxon-éxon: no RNA maduro sequenciado, os íntrons já foram removidos, então dois éxons que no genoma estão separados por um íntron aparecem adjacentes na read. Um alinhador ciente de splicing reconhece isso e mapeia as duas metades da read em suas posições reais e distantes no genoma.

??? question "4. Por que o bulk RNA-Seq não consegue distinguir 'o mesmo tipo de célula mudou de comportamento' de 'a proporção de tipos celulares mudou'?"
    Porque o bulk mede uma média do RNA de todas as células misturadas, ponderada pela proporção de cada tipo celular presente — sem preservar a identidade de origem de cada molécula. As duas situações (mudança de comportamento vs. mudança de proporção) podem produzir exatamente o mesmo padrão de expressão diferencial na média, tornando-as indistinguíveis sem informação por célula.

---

## Referências

[^1]: Wang Z, Gerstein M, Snyder M. RNA-Seq: a revolutionary tool for transcriptomics. *Nature Reviews Genetics*. 2009;10:57–63. doi: [10.1038/nrg2484](https://doi.org/10.1038/nrg2484).

[^2]: Zhao S, Zhang Y, Gamini R, Zhang B, von Schack D. Evaluation of two main RNA-seq approaches for gene quantification in clinical RNA sequencing: polyA+ selection versus rRNA depletion. *Scientific Reports*. 2018;8:4781. doi: [10.1038/s41598-018-23226-4](https://doi.org/10.1038/s41598-018-23226-4).

[^3]: Gayathri SN, Lillback V, Udd B, Hackman P, Savarese M, Oghabian A. Poly(A)+ selection limits detection of long and alternatively spliced transcripts compared with rRNA depletion in RNA-Sequencing. *BMC Genomics*. 2026;27:591. doi: [10.1186/s12864-026-12944-z](https://doi.org/10.1186/s12864-026-12944-z).

[^4]: Bentley DR, Balasubramanian S, Swerdlow HP, et al. Accurate whole human genome sequencing using reversible terminator chemistry. *Nature*. 2008;456(7218):53–59. doi: [10.1038/nature07517](https://doi.org/10.1038/nature07517).

[^5]: Dobin A, Davis CA, Schlesinger F, et al. STAR: ultrafast universal RNA-seq aligner. *Bioinformatics*. 2013;29(1):15–21. doi: [10.1093/bioinformatics/bts635](https://doi.org/10.1093/bioinformatics/bts635).

[^6]: Patro R, Duggal G, Love MI, Irizarry RA, Kingsford C. Salmon provides fast and bias-aware quantification of transcript expression. *Nature Methods*. 2017;14(4):417–419. doi: [10.1038/nmeth.4197](https://doi.org/10.1038/nmeth.4197).

[^7]: Gallardo-Dodd CJ, Kutter C. The regulatory landscape of interacting RNA and protein pools in cellular homeostasis and cancer. *Human Genomics*. 2024;18(1):109. doi: [10.1186/s40246-024-00678-6](https://doi.org/10.1186/s40246-024-00678-6).
