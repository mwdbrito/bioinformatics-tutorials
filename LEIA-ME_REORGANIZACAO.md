# O que foi reorganizado neste pacote

Este zip contém apenas `docs/`, `mkdocs.yml` e `.gitignore` — para você copiar
por cima da sua pasta local do repositório `bioinformatics-tutorials` e
revisar o `git diff` antes de commitar. Não inclui `.git/` nem `site/`.

## Corrigido
- **Bug de caminho no menu**: `mkdocs.yml` apontava para `bioinfo/plots/graficos_r.md`
  (plural), mas o arquivo real está em `bioinfo/plot/graficos_r.md` (singular).
  Corrigido para o caminho real.
- **Duas páginas do pipeline de RNA-Seq estavam invisíveis**: `tutorial_rnaseq_completo.md`
  (a versão completa e atual, com bug de curadoria corrigido e pipeline
  estendido) e `TUTORIAL_APPTAINER_RNASEQ_SANDBOX.md` existiam no repositório
  mas não apareciam em nenhum lugar do menu. Movi o conteúdo do primeiro para
  `bioinfo/transcriptoma/rnaseq.md` (o slot que já existia no menu, mas estava
  vazio) e o segundo para `bioinfo/transcriptoma/apptainer_sandbox.md`, com
  entrada própria no menu.
- **Versão antiga do tutorial removida**: `tutorial.md` era uma versão anterior
  e parcial (só até FASTQ limpos, sem o bug de curadoria corrigido) do mesmo
  tutorial que hoje está em `rnaseq.md`. Como o conteúdo dela já está
  totalmente coberto (e corrigido) na versão completa, removi do `docs/` para
  não ter duas versões conflitantes publicadas ao mesmo tempo. Ela continua
  recuperável no histórico do git (`git log --all --full-history -- docs/tutorial.md`).
- **Arquivos-fantasma do Windows**: três arquivos `...#Uf03aZone.Identifier`
  (metadado que o Windows cria ao baixar algo da internet) tinham vazado para
  dentro de `docs/assets/` e `docs/`. Removidos.
- **Sumário do `singularity_tutorial.md` com links quebrados**: os 16 links do
  índice apontavam para anchors com acentos (`#1-antes-de-começar...`), mas o
  MkDocs gera anchors sem acento (`#1-antes-de-comecar...`). Corrigi os 16
  links para o anchor real gerado.
- **Página inicial não linkava para o conteúdo principal**: a "Navegação
  Rápida" do `index.md` só linkava para os tutoriais de ferramentas
  (Singularity, MkDocs). Adicionei links para o Pipeline de RNA-Seq e a
  Exploração do TCGA.
- **Título genérico no menu**: "post1" virou "O Dogma Central da Biologia".
- **Faltava `.gitignore`**: como o repositório já usa `mkdocs gh-deploy` (branch
  `gh-pages`) para publicar, a pasta `site/` não precisa ser versionada na
  `main` — hoje ela está sendo commitada e ganha 3,6 MB de build gerado a cada
  atualização. Criei um `.gitignore` ignorando `site/` e os arquivos
  `Zone.Identifier`.

## Preciso da sua ação (não consegui resolver por conta própria)
1. **5 imagens ausentes em `post1_dogma_central.md`**: o post referencia
   `images/3-3.jpg`, `4-4.jpg`, `5-5.jpg`, `6-6.jpg` e `7-7.jpg`, mas essa pasta
   `images/` não existe no repositório (só existe `assets/`, com apenas 1 imagem
   usada). Você precisa adicionar essas 5 imagens em `docs/images/` (ou
   atualizar os links se elas tiverem outro nome/local).
2. **`projeto_rnaseq_scripts.zip` está ausente**: só sobrou o metadado
   `Zone.Identifier` dele no zip enviado — o zip de verdade com os scripts do
   projeto não veio. Se ele deveria estar disponível para download no site,
   precisa ser readicionado.
3. **Duas páginas ficaram como placeholder** (`bioinfo/analise/introducao.md`
   e `bioinfo/plot/graficos_r.md`): estavam vazias no repositório original e eu
   não tinha conteúdo de origem para preenchê-las — deixei um aviso "🚧 em
   construção" em vez de deixá-las em branco. Quando tiver o conteúdo, é só
   substituir.

## Depois de aplicar
```bash
# depois de copiar docs/, mkdocs.yml e .gitignore por cima do seu repositório local:
git add -A
git status            # confira o que vai ser removido/adicionado
git rm -r --cached site   # se o site/ já estava versionado, tira ele do controle de versão
git commit -m "Reorganiza nav, corrige caminhos e remove páginas órfãs/duplicadas"
git push
mkdocs gh-deploy      # publica o build novo na gh-pages
```
