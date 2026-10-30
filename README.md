# MwInSilico

Postagens, tutoriais e scripts de bioinformática em português.

**Site:** <https://mwdbrito.github.io/bioinformatics-tutorials/> · **Instagram:** [@MWInSilico](https://www.instagram.com/mwinsilico/)

## Estrutura

```
docs/
├── index.md            # Home
├── posts/              # versões completas das postagens do Instagram
├── scripts/            # vitrine dos repositórios de código
├── tutoriais/          # rascunhos — só aparecem no "mkdocs serve" (draft_docs)
├── glossario.md        # glossário completo
├── includes/glossario.md  # siglas com tooltip, aplicadas em todas as páginas
└── assets/             # logo, figuras e extra.css
overrides/              # templates: cabeçalho/rodapé dos posts e página 404
mkdocs.yml              # configuração e menu do site
```

## Rodando localmente

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve        # http://127.0.0.1:8000 (inclui os rascunhos de tutoriais/)
```

## Publicação

Todo `git push` na branch `main` dispara o GitHub Actions (`.github/workflows/deploy.yml`), que roda `mkdocs gh-deploy --strict` e atualiza a branch `gh-pages`. Não é preciso publicar manualmente.

## Novo post

1. Crie `docs/posts/nome-do-post.md` com o frontmatter:

   ```yaml
   ---
   title: "Título curto (aparece no menu)"
   description: "Uma frase para o Google e para as prévias de link."
   serie: "Nome da série"
   parte: 1
   de: 3
   tags:
     - Postagem
     - Tema
   ---
   ```

2. Adicione o arquivo ao `nav` do `mkdocs.yml` e um cartão em `docs/posts/index.md`.
3. Siglas novas vão em `docs/includes/glossario.md` (tooltip) e em `docs/glossario.md`.

## Publicar um tutorial

Os tutoriais em `docs/tutoriais/` estão ocultos enquanto são revisados. Para publicar um: tire-o de `draft_docs`, adicione-o ao `nav` e remova o redirecionamento da URL antiga em `plugins > redirects`.

## Licença

Conteúdo livre: os textos e as figuras estão sob [CC BY 4.0](LICENSE-CONTEUDO.md) e o código sob [MIT](LICENSE). Pode usar, adaptar e compartilhar à vontade, só cite a fonte.
