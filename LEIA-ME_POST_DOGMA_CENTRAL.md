# O que mudou no post "O Dogma Central da Biologia"

## Conteúdo
- Texto revisado e ampliado (~2.400 palavras, antes ~1.400), mantendo a voz e a estrutura
  originais, mas com mais profundidade em cada seção.
- **13 referências reais e verificadas** (antes eram 7) — todas conferidas por DOI:
  artigos originais de Crick (1970), Temin & Mizutani (1970) e Baltimore (1970) sobre a
  transcriptase reversa, Cech & Steitz (2014) sobre a revolução dos RNAs não codificantes,
  Bartel (2018) sobre microRNAs, Chang & Qi (2023) sobre edição de epigenoma guiada por RNA,
  Nurk et al. (2022) sobre o genoma humano completo (T2T), Wang/Gerstein/Snyder (2009) e
  Conesa et al. (2016) sobre RNA-seq, Hasin/Seldin/Lusis (2017) sobre multiômica,
  Aebersold & Mann (2016) sobre proteômica, Mudge et al. (2025) sobre o GENCODE — e o
  livro-texto *Molecular Biology of the Cell* (Alberts et al., 7ª ed., 2022) como leitura
  de base. Corrigi também um DOI errado do GENCODE que estava no arquivo original.
- Duas seções novas: um **glossário rápido de RNAs não codificantes** e um **quiz de
  5 perguntas** (clique para revelar a resposta) em "Teste seus conhecimentos".
- 4 caixas de destaque (`tip`/`info`) para pontos-chave e leitura recomendada.
- Link interno para o [tutorial completo de RNA-Seq](docs/bioinfo/transcriptoma/rnaseq.md).

## Imagens
As 5 imagens do post original (`images/3-3.jpg` a `7-7.jpg`) **não existiam no repositório**
enviado — eram links quebrados. Como não recebi os arquivos originais, criei 6 diagramas
novos, originais e vetoriais (SVG, leves e nítidos em qualquer tela), na paleta
teal/cyan do próprio site:
- `central-dogma-expandido.svg` — transferências gerais x especiais de informação
- `escala-dados-genomicos.svg` — do genoma completo a um único gene
- `pipeline-bioinformatica.svg` — fluxo de análise de RNA-seq
- `camadas-omicas.svg` — genômica → epigenômica → transcriptômica → proteômica → metabolômica
- `proteomica-rede.svg` — rede de interação proteica + espectrometria de massas
- `bioinformatica-ponte.svg` — Bioinformática como ponte entre dado e conhecimento

A imagem `post2_1.jpg` (fluxo clássico DNA→RNA→proteína) já existia e foi mantida.

## Dois bugs de configuração corrigidos no `mkdocs.yml`
O post original já continha citações no formato `[^1]` e uma imagem centralizada com
`<center>![...]</center>`, mas **nenhum dos dois funcionava** no site publicado, porque
faltavam extensões do MkDocs:
- `footnotes` — sem ela, `[^1]` aparecia como texto literal "[^1]" em vez de nota de
  rodapé clicável.
- `md_in_html` — sem ela, uma imagem markdown dentro de `<center>...</center>` não era
  convertida em `<img>` e aparecia como texto cru na página.

Ambas foram adicionadas. Validei tudo com `mkdocs build --strict`: build limpo, sem
nenhum aviso, notas de rodapé e imagem central funcionando corretamente.

## Instagram
Preparei uma legenda pronta para postar junto com o link do artigo — está na minha
resposta no chat, não neste arquivo (não faz sentido versionar isso no repositório).
