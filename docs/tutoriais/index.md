# Tutoriais (rascunhos)

!!! warning "Visível só localmente"
    Esta pasta está em `draft_docs` no `mkdocs.yml`: as páginas aparecem no `mkdocs serve`, mas **não** são publicadas pelo `mkdocs build` / `mkdocs gh-deploy`.

    Para publicar um tutorial: remova-o de `draft_docs` (ou mova-o para fora de `tutoriais/`), adicione-o ao `nav` e tire o redirecionamento correspondente em `plugins > redirects`.

| Tutorial | Arquivo | O que falta revisar |
|---|---|---|
| [Pipeline de RNA-Seq](pipeline-rnaseq.md) | `pipeline-rnaseq.md` | trocar o changelog do topo por objetivo/pré-requisitos; usar `##` nas Partes (hoje são `#`); levar os scripts para arquivos em `scripts/` |
| [Container do pipeline](container-rnaseq.md) | `container-rnaseq.md` | hierarquia de títulos; separar do guia geral de Apptainer |
| [DESeq2 e a estatística](deseq2-estatistica.md) | `deseq2-estatistica.md` | revisão final |
| [Exploração do TCGA/GDC](exploracao-tcga.md) | `exploracao-tcga.md` | a primeira linha não é título (`#`); seções com `" # "` (espaço antes) |
| [Apptainer — guia geral](apptainer.md) | `apptainer.md` | hierarquia de títulos |
| [MkDocs e GitHub Pages](mkdocs-github-pages.md) | `mkdocs-github-pages.md` | hierarquia de títulos; imagem `img/arquitetura.png` inexistente |
