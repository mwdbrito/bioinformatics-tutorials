# Guia Prático: Como Criar, Publicar e Atualizar um Site de Documentação com MkDocs e GitHub Pages

> **Objetivo:** criar um site de documentação profissional usando **MkDocs + Material for MkDocs**, armazenar os arquivos no GitHub e publicar gratuitamente usando **GitHub Pages**.

---

# 1. O que é o MkDocs?

O **MkDocs** é um gerador de sites estáticos voltado principalmente para documentação.

A ideia é simples:

```text
Arquivos Markdown (.md)
          │
          ▼
        MkDocs
          │
          ▼
     HTML + CSS + JS
          │
          ▼
     Site de documentação
```

Você escreve seus conteúdos em arquivos Markdown (`.md`) e o MkDocs transforma esses arquivos em um site navegável.

Quando combinado com o tema **Material for MkDocs**, o site pode ter recursos como:

- menu lateral;
- busca;
- navegação entre páginas;
- modo claro/escuro;
- botão para copiar códigos;
- caixas de alerta;
- tabelas;
- destaque de sintaxe para códigos;
- responsividade para celular;
- navegação entre seções.

O resultado é uma estrutura muito adequada para:

- tutoriais;
- documentação de projetos;
- protocolos;
- guias de bioinformática;
- documentação de scripts;
- manuais internos;
- documentação de APIs;
- materiais suplementares de projetos científicos.

---

# 2. Instalação

## 2.1. Instalar o MkDocs Material

No terminal, utilize:

```bash
pip install mkdocs-material
```

Para verificar se a instalação funcionou:

```bash
mkdocs --version
```

Uma saída possível será:

```text
mkdocs, version 1.x.x
```

> **Observação:** a versão exibida pode ser diferente.

---

# 3. Criando o Projeto

Para criar um novo site:

```bash
mkdocs new meus-tutoriais
```

Depois, entre no diretório:

```bash
cd meus-tutoriais
```

A estrutura criada será semelhante a:

```text
meus-tutoriais/
├── docs/
│   └── index.md
└── mkdocs.yml
```

## 3.1. O que significa cada arquivo?

### `mkdocs.yml`

É o **arquivo principal de configuração** do site.

Nele você pode definir:

- nome do site;
- URL;
- tema;
- menu de navegação;
- plugins;
- extensões Markdown;
- cores;
- recursos adicionais.

### `docs/`

É a pasta que contém o conteúdo da documentação.

Por exemplo:

```text
docs/
├── index.md
├── apptainer.md
├── linux.md
├── python.md
└── rnaseq.md
```

Cada arquivo `.md` pode se transformar em uma página do site.

---

# 4. Configurando o Tema Material

Um `mkdocs.yml` básico pode ser:

```yaml
site_name: Meus Tutoriais

theme:
  name: material
```

Com isso, o MkDocs utilizará o tema Material.

Uma configuração um pouco mais completa:

```yaml
site_name: Meus Tutoriais

theme:
  name: material
  language: pt-BR

nav:
  - Início: index.md
  - Linux: linux.md
  - Apptainer: apptainer.md
  - Python: python.md
  - RNA-Seq: rnaseq.md
```

Nesse exemplo, o menu do site será:

```text
Início
Linux
Apptainer
Python
RNA-Seq
```

---

# 5. Escrevendo a Documentação

Os textos ficam dentro da pasta:

```text
docs/
```

Por exemplo:

```text
docs/
├── index.md
├── linux.md
└── apptainer.md
```

O arquivo `apptainer.md` pode conter:

```markdown
# Guia de Apptainer

O Apptainer é uma plataforma de contêineres utilizada em
ambientes de computação científica.

## Instalação

```bash
sudo apt update
sudo apt install -y apptainer
```
```

---

# 6. Configurando o Menu de Navegação

Para organizar as páginas, utilize a seção `nav:` no `mkdocs.yml`.

Exemplo:

```yaml
nav:
  - Início: index.md
  - Linux:
      - Introdução: linux.md
      - Comandos básicos: linux-comandos.md
  - Apptainer:
      - Introdução: apptainer.md
      - Instalação: apptainer-instalacao.md
      - Uso: apptainer-uso.md
```

Isso cria uma estrutura hierárquica no menu.

Visualmente:

```text
Início

Linux
├── Introdução
└── Comandos básicos

Apptainer
├── Introdução
├── Instalação
└── Uso
```

> **Importante:** se você criar um arquivo `.md` e não adicioná-lo ao `nav:`, ele pode não aparecer no menu principal.

---

# 7. Testando o Site Localmente

Antes de publicar, é altamente recomendável testar o site no próprio computador.

Dentro da pasta do projeto:

```bash
mkdocs serve
```

O terminal mostrará algo semelhante a:

```text
Serving on http://127.0.0.1:8000/
```

Abra no navegador:

```text
http://127.0.0.1:8000
```

Enquanto o servidor estiver rodando, o MkDocs monitora os arquivos.

Assim, quando você alterar um `.md` e salvar:

```text
editar arquivo
      │
      ▼
    salvar
      │
      ▼
MkDocs detecta alteração
      │
      ▼
site é atualizado
```

Isso torna o processo de criação da documentação muito mais rápido.

Para parar o servidor:

```text
Ctrl + C
```

---

# 8. Criando o Repositório no GitHub

Para publicar o site, primeiro precisamos armazenar o projeto em um repositório do GitHub.

## Etapa A — Criar o repositório

1. Acesse o [GitHub](https://github.com/) e faça login.
2. Clique no botão **`+`** no canto superior direito.
3. Selecione **New repository**.
4. Em **Repository name**, escolha um nome, por exemplo:

```text
tutoriais-scripts
```

5. Escolha a visibilidade desejada de acordo com a configuração de Pages disponível na sua conta.
6. Para facilitar o primeiro `push`, deixe o repositório inicializado sem arquivos adicionais, como README, `.gitignore` ou licença.
7. Clique em **Create repository**.

O GitHub mostrará a URL do repositório, por exemplo:

```text
https://github.com/SEU_USUARIO/tutoriais-scripts.git
```

> **Dica:** copie essa URL, pois ela será utilizada no próximo passo.

---

# 9. Conectando o Projeto Local ao GitHub

Abra o terminal dentro da pasta do projeto:

```bash
cd meus-tutoriais
```

## 9.1. Inicialize o Git

```bash
git init
```

Isso transforma a pasta em um repositório Git local.

---

## 9.2. Adicione os arquivos

```bash
git add .
```

O `.` significa que todos os arquivos do diretório serão adicionados.

---

## 9.3. Crie o primeiro commit

```bash
git commit -m "Primeiro site de documentação"
```

Um **commit** é uma espécie de fotografia do estado dos arquivos naquele momento.

---

## 9.4. Defina a branch principal

```bash
git branch -M main
```

---

## 9.5. Conecte ao GitHub

Substitua a URL abaixo pela URL do seu repositório:

```bash
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git
```

---

## 9.6. Envie os arquivos

```bash
git push -u origin main
```

Agora os arquivos do projeto estarão armazenados no GitHub.

---

# 10. Publicando o Site pela Primeira Vez

Até agora, o GitHub possui os **arquivos-fonte** do projeto:

```text
.md
mkdocs.yml
imagens
outros arquivos
```

Eles ainda não são o site publicado.

Para gerar e publicar o site:

```bash
mkdocs gh-deploy
```

Esse comando realiza automaticamente várias etapas:

```text
Arquivos Markdown
       │
       ▼
     MkDocs
       │
       ▼
HTML / CSS / JavaScript
       │
       ▼
branch gh-pages
       │
       ▼
GitHub Pages
       │
       ▼
Site online
```

O comando normalmente cria ou atualiza uma branch chamada:

```text
gh-pages
```

Essa branch contém a versão compilada do site.

---

# 11. Onde o Site Ficará Disponível?

Normalmente, o endereço terá este formato:

```text
https://SEU_USUARIO.github.io/NOME_DO_REPOSITORIO/
```

Por exemplo:

```text
https://marcioexemplo.github.io/tutoriais-scripts/
```

> **Observação:** na primeira publicação, pode levar alguns instantes para o GitHub Pages disponibilizar o site.

---

# 12. Como Atualizar o Site Depois de Publicado?

Esta é uma das partes mais importantes.

Depois que o site já estiver publicado, você **não precisa recriar o projeto**.

O fluxo passa a ser muito simples:

```text
Editar documentação
        │
        ▼
Testar localmente
        │
        ▼
git add .
        │
        ▼
git commit
        │
        ▼
git push
        │
        ▼
mkdocs gh-deploy
        │
        ▼
Site atualizado
```

---

# 13. Atualizando uma Página Existente

Imagine que você queira alterar:

```text
docs/apptainer.md
```

Abra o arquivo e faça as alterações.

Depois, teste localmente:

```bash
mkdocs serve
```

Acesse:

```text
http://127.0.0.1:8000
```

Confira se tudo está correto.

Quando estiver satisfeito, pare o servidor com:

```text
Ctrl + C
```

---

# 14. Salvando as Alterações no Git

Depois de editar o arquivo, verifique o que mudou:

```bash
git status
```

Você poderá ver algo semelhante a:

```text
modified:   docs/apptainer.md
```

Agora adicione as alterações:

```bash
git add .
```

Crie um commit:

```bash
git commit -m "Atualiza documentação do Apptainer"
```

E envie para o GitHub:

```bash
git push
```

Nesse momento, a versão-fonte da documentação já estará atualizada no GitHub.

---

# 15. Atualizando o Site Publicado

Agora execute:

```bash
mkdocs gh-deploy
```

O MkDocs irá:

1. ler os arquivos atuais;
2. gerar novamente o site;
3. atualizar a branch `gh-pages`;
4. enviar a nova versão para o GitHub Pages.

Depois de alguns instantes, o site estará atualizado.

---

# 16. Fluxo Completo de Atualização

Na prática, o processo diário pode ser:

```bash
# 1. Editar os arquivos em docs/

# 2. Testar localmente
mkdocs serve

# 3. Verificar o que mudou
git status

# 4. Adicionar as alterações
git add .

# 5. Criar um commit
git commit -m "Atualiza documentação"

# 6. Enviar o código-fonte ao GitHub
git push

# 7. Gerar e publicar o site
mkdocs gh-deploy
```

> **Importante:** `git push` e `mkdocs gh-deploy` têm funções diferentes. O primeiro atualiza o **código-fonte do projeto** na branch `main`; o segundo gera e publica a **versão do site** na branch usada pelo GitHub Pages.

---

# 17. E se eu Apenas Quiser Corrigir um Erro de Digitação?

O processo é o mesmo.

Por exemplo:

```text
1. Corrigir o arquivo .md
2. Salvar
3. Testar com mkdocs serve
4. git add .
5. git commit
6. git push
7. mkdocs gh-deploy
```

Não é necessário:

- criar outro repositório;
- instalar MkDocs novamente;
- recriar o projeto;
- configurar o GitHub Pages novamente.

---

# 18. Adicionando uma Nova Página

Suponha que você queira criar:

```text
docs/docker.md
```

Crie o arquivo:

```markdown
# Docker

Aqui ficará a documentação sobre Docker.
```

Depois, adicione-o ao `nav:`:

```yaml
nav:
  - Início: index.md
  - Linux: linux.md
  - Apptainer: apptainer.md
  - Docker: docker.md
```

Teste:

```bash
mkdocs serve
```

Depois publique:

```bash
git add .
git commit -m "Adiciona documentação sobre Docker"
git push
mkdocs gh-deploy
```

---

# 19. Adicionando Imagens

Você também pode utilizar imagens na documentação.

Por exemplo:

```text
docs/
├── index.md
├── apptainer.md
└── img/
    └── arquitetura.png
```

Dentro do Markdown:

```markdown
![Arquitetura do ambiente](img/arquitetura.png)
```

O MkDocs incorporará a imagem no site.

> **Boa prática:** mantenha imagens relacionadas à documentação dentro de uma estrutura organizada, como `docs/img/`.

---

# 20. Estrutura Recomendada do Projeto

Uma organização mais completa pode ser:

```text
meus-tutoriais/
│
├── docs/
│   ├── index.md
│   │
│   ├── linux/
│   │   ├── introducao.md
│   │   └── comandos.md
│   │
│   ├── apptainer/
│   │   ├── introducao.md
│   │   ├── instalacao.md
│   │   └── uso.md
│   │
│   ├── python/
│   │   └── introducao.md
│   │
│   └── img/
│       └── arquitetura.png
│
├── mkdocs.yml
└── README.md
```

Essa organização facilita bastante a manutenção quando a documentação começa a crescer.

---

# 21. Um `mkdocs.yml` Mais Completo

Uma configuração inicial interessante para documentação técnica é:

```yaml
site_name: Meus Tutoriais
site_description: Documentação e tutoriais de bioinformática

theme:
  name: material
  language: pt-BR

nav:
  - Início: index.md
  - Linux:
      - Introdução: linux/introducao.md
      - Comandos: linux/comandos.md
  - Apptainer:
      - Introdução: apptainer/introducao.md
      - Instalação: apptainer/instalacao.md
      - Uso: apptainer/uso.md
  - Python:
      - Introdução: python/introducao.md
```

---

# 22. Comandos Essenciais

| Objetivo | Comando |
|---|---|
| Criar projeto | `mkdocs new projeto` |
| Testar localmente | `mkdocs serve` |
| Construir site | `mkdocs build` |
| Inicializar Git | `git init` |
| Ver alterações | `git status` |
| Adicionar arquivos | `git add .` |
| Criar commit | `git commit -m "mensagem"` |
| Enviar para GitHub | `git push` |
| Publicar no Pages | `mkdocs gh-deploy` |

---

# 23. O que Cada Comando Faz?

É importante entender que Git e MkDocs possuem funções diferentes.

### `git add`

Seleciona os arquivos que serão incluídos no próximo commit.

### `git commit`

Cria uma versão registrada das alterações.

### `git push`

Envia os commits para o GitHub.

### `mkdocs serve`

Cria um servidor local temporário para visualizar a documentação.

### `mkdocs build`

Gera a versão estática do site localmente.

### `mkdocs gh-deploy`

Gera o site e publica a versão compilada no GitHub Pages.

---

# 24. Fluxo Conceitual

Existem, na prática, **duas versões do projeto**:

```text
                  PROJETO
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
       Branch main          Branch gh-pages
          │                     │
          │                     │
          ▼                     ▼
   Arquivos-fonte          Site compilado
   .md                     HTML
   mkdocs.yml              CSS
   imagens                 JavaScript
          │                     │
          │                     │
          ▼                     ▼
      GitHub              GitHub Pages
```

A `main` guarda o material que você edita.

A `gh-pages` guarda a versão que o GitHub Pages disponibiliza como site.

O comando:

```bash
mkdocs gh-deploy
```

faz a ponte entre essas duas partes.

---

# 25. Checklist para Publicar pela Primeira Vez

- [ ] Instalar `mkdocs-material`
- [ ] Criar o projeto com `mkdocs new`
- [ ] Criar os arquivos `.md`
- [ ] Configurar o `mkdocs.yml`
- [ ] Organizar o `nav:`
- [ ] Testar com `mkdocs serve`
- [ ] Criar um repositório no GitHub
- [ ] Inicializar o Git com `git init`
- [ ] Executar `git add .`
- [ ] Criar o primeiro `git commit`
- [ ] Configurar a branch `main`
- [ ] Adicionar o `remote`
- [ ] Executar `git push`
- [ ] Publicar com `mkdocs gh-deploy`
- [ ] Acessar a URL do GitHub Pages

---

# 26. Checklist para Atualizar o Site

Sempre que precisar atualizar uma documentação já publicada:

- [ ] Editar ou criar arquivos dentro de `docs/`
- [ ] Atualizar o `nav:` se necessário
- [ ] Testar com `mkdocs serve`
- [ ] Executar `git status`
- [ ] Executar `git add .`
- [ ] Criar um `git commit`
- [ ] Executar `git push`
- [ ] Executar `mkdocs gh-deploy`
- [ ] Atualizar o navegador e conferir o site

---

# 27. Fluxo Mais Simples para o Dia a Dia

Depois que tudo estiver configurado, o processo fica praticamente assim:

```text
┌─────────────────────┐
│ Editar arquivo .md  │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│   mkdocs serve      │
│  Testar localmente  │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│      git add .      │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│     git commit      │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│      git push       │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ mkdocs gh-deploy    │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│    Site atualizado  │
└─────────────────────┘
```

---

# 28. Resumo Final

O funcionamento pode ser resumido em três conceitos:

### MkDocs

Transforma:

```text
Markdown → Site
```

### Git

Controla e armazena as versões dos arquivos:

```text
Arquivos locais → Git → GitHub
```

### GitHub Pages

Hospeda o site:

```text
Site compilado → GitHub Pages → Internet
```

Portanto, o fluxo completo é:

```text
Você escreve
     │
     ▼
   .md
     │
     ▼
  MkDocs
     │
     ▼
 Site HTML
     │
     ▼
GitHub Pages
     │
     ▼
Site online
```

E, para uma atualização:

```text
Editar .md
    ↓
Testar
    ↓
git add .
    ↓
git commit
    ↓
git push
    ↓
mkdocs gh-deploy
    ↓
Site atualizado
```

> **Regra prática para lembrar:**  
> **`git push` salva seu projeto no GitHub.**  
> **`mkdocs gh-deploy` publica a documentação no GitHub Pages.**

---

# 29. Referências Oficiais

- MkDocs: https://www.mkdocs.org/
- Material for MkDocs: https://squidfunk.github.io/mkdocs-material/
- GitHub Pages: https://pages.github.com/
- GitHub: https://github.com/

