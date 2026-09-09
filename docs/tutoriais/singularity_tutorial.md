# Guia Prático e Avançado de Apptainer (Singularity) para Bioinformática

> **Objetivo:** aprender, do zero, a instalar, configurar, criar, modificar, testar e utilizar containers Apptainer em Linux, WSL ou servidores de pesquisa, com foco em bioinformática e reprodutibilidade.
>
> **Documentação oficial:** https://apptainer.org/docs/user/latest/

---

## Sumário

1. [Antes de começar: o que é o Apptainer?](#1-antes-de-comecar-o-que-e-o-apptainer)
2. [Os conceitos fundamentais](#2-os-conceitos-fundamentais)
3. [Instalação e primeiros testes](#3-instalacao-e-primeiros-testes)
4. [Cache e espaço em disco](#4-cache-e-espaco-em-disco)
5. [A receita `.def`: descrevendo o ambiente](#5-a-receita-def-descrevendo-o-ambiente)
6. [Construindo o primeiro container](#6-construindo-o-primeiro-container)
7. [Sandbox: desenvolvendo o container aos poucos](#7-sandbox-desenvolvendo-o-container-aos-poucos)
8. [Convertendo o sandbox em `.sif`](#8-convertendo-o-sandbox-em-sif)
9. [Usando o container: `exec`, `shell` e `run`](#9-usando-o-container-exec-shell-e-run)
10. [O conceito fundamental de `--bind`](#10-o-conceito-fundamental-de-bind)
11. [Exemplos práticos em bioinformática](#11-exemplos-praticos-em-bioinformatica)
12. [Como organizar um projeto](#12-como-organizar-um-projeto)
13. [Reprodutibilidade e boas práticas](#13-reprodutibilidade-e-boas-praticas)
14. [Problemas comuns e como diagnosticar](#14-problemas-comuns-e-como-diagnosticar)
15. [Fluxo de trabalho recomendado](#15-fluxo-de-trabalho-recomendado)
16. [Comandos essenciais](#16-comandos-essenciais)

---

# 1. Antes de começar: o que é o Apptainer?

O **Apptainer** é uma tecnologia de containers muito utilizada em ambientes científicos e de pesquisa.

Você provavelmente também encontrará o nome **Singularity** em tutoriais antigos, scripts e servidores. O projeto Singularity foi continuado sob o nome Apptainer, portanto muitos conceitos e comandos são semelhantes.

A ideia principal é simples:

> **O container guarda o ambiente computacional; o servidor continua guardando seus dados, scripts e resultados.**

Isso é especialmente útil em bioinformática porque uma análise pode depender de muitas ferramentas e versões específicas:

```text
R
Python
FastQC
Cutadapt
Trim Galore
MultiQC
Salmon
Samtools
bibliotecas Python
pacotes R
etc.
```

Instalar tudo diretamente no sistema operacional pode causar conflitos. Com Apptainer, podemos colocar esse ambiente dentro de uma imagem.

O modelo mental é:

```text
                    SEU PROJETO
                         │
             ┌───────────┼───────────┐
             │           │           │
             ▼           ▼           ▼
           dados       scripts    resultados
             │
             │ --bind
             ▼
      ┌─────────────────────┐
      │      CONTAINER      │
      │                     │
      │ R                   │
      │ Python              │
      │ FastQC              │
      │ Salmon              │
      │ MultiQC             │
      │ bibliotecas         │
      └─────────────────────┘
```

---

# 2. Os conceitos fundamentais

Antes de criar qualquer container, vale entender a diferença entre **imagem**, **container**, **`.def`** e **sandbox**.

## 2.1 Imagem `.sif`

O formato mais comum para distribuir e utilizar containers Apptainer é o:

```text
.sif
```

Por exemplo:

```text
transcriptoma.sif
```

Uma imagem SIF contém o ambiente necessário para executar determinado conjunto de ferramentas.

Podemos pensar:

```text
transcriptoma.sif
│
├── sistema base
├── R
├── Python
├── FastQC
├── Salmon
├── MultiQC
└── bibliotecas
```

O SIF é excelente para a **versão final e estável** do ambiente.

---

## 2.2 Arquivo `.def`

O arquivo `.def` é a **receita** utilizada para construir o container.

Por exemplo:

```text
transcriptoma.def
```

Ele descreve coisas como:

- qual sistema operacional será utilizado como base;
- quais programas serão instalados;
- quais bibliotecas serão instaladas;
- variáveis de ambiente;
- arquivos que devem ser incluídos;
- testes que devem ser executados.

A relação é:

```text
transcriptoma.def
        │
        │ build
        ▼
transcriptoma.sif
```

Portanto:

> **`.def` = receita; `.sif` = imagem pronta.**

---

## 2.3 Sandbox

O **sandbox** é uma imagem em formato de diretório.

Em vez de:

```text
transcriptoma.sif
```

você terá algo parecido com:

```text
transcriptoma/
├── bin/
├── etc/
├── usr/
├── var/
└── ...
```

A grande vantagem do sandbox é que ele pode ser utilizado como um ambiente **gravável** durante o desenvolvimento.

Isso é particularmente importante para quem está aprendendo.

### Quando usar SIF?

Use SIF quando:

- o ambiente já está pronto;
- você quer uma imagem estável;
- pretende executar um pipeline;
- pretende compartilhar a imagem;
- quer congelar uma versão do ambiente.

### Quando usar sandbox?

Use sandbox quando:

- ainda está descobrindo quais ferramentas precisa;
- está testando instalações;
- está desenvolvendo o container;
- quer entrar no ambiente e modificar alguma coisa;
- ainda não sabe exatamente como ficará o ambiente final.

Uma estratégia muito prática é:

```text
DESENVOLVIMENTO

sandbox/
   │
   ├── instalar
   ├── testar
   ├── corrigir
   └── testar novamente
            │
            ▼
       ambiente pronto
            │
            ▼
          .sif
            │
            ▼
        PRODUÇÃO
```

> **Importante:** o sandbox é excelente para desenvolvimento, mas não deve substituir a receita `.def`. Tudo que você descobrir manualmente durante o desenvolvimento deve, posteriormente, ser colocado no `.def`, para que o ambiente final possa ser reconstruído.

---

## 2.4 O container não é uma máquina virtual

Uma máquina virtual normalmente possui um sistema operacional convidado completo.

O Apptainer trabalha de maneira muito mais integrada ao sistema Linux hospedeiro.

A ideia é:

```text
Sistema Linux
     │
     └── Apptainer
           │
           └── container
                 │
                 └── ferramentas
```

Isso permite utilizar o mesmo ambiente computacional sem precisar instalar todas as ferramentas diretamente no sistema hospedeiro.

---

# 3. Instalação e primeiros testes

## 3.1 Verifique se já está instalado

Antes de instalar qualquer coisa:

```bash
apptainer --version
```

Se aparecer algo semelhante a:

```text
apptainer version 1.x.x
```

ele já está instalado.

Também pode verificar onde está o executável:

```bash
which apptainer
```

---

## 3.2 Instalação no Ubuntu/Debian

Em um computador ou WSL onde você possui `sudo`, uma possibilidade é utilizar o repositório oficial disponibilizado para Ubuntu.

Atualize os pacotes:

```bash
sudo apt update
```

Instale os utilitários necessários:

```bash
sudo apt install -y software-properties-common
```

Adicione o PPA:

```bash
sudo add-apt-repository -y ppa:apptainer/ppa
```

Atualize novamente:

```bash
sudo apt update
```

Instale:

```bash
sudo apt install -y apptainer
```

Verifique:

```bash
apptainer --version
```

> Em um servidor institucional, é comum que você não tenha `sudo`. Nesse caso, não tente contornar as políticas do servidor. Primeiro verifique se o Apptainer já está instalado ou peça ao administrador para disponibilizá-lo.

---

## 3.3 Verifique os recursos disponíveis

Depois da instalação:

```bash
apptainer help
```

Você também pode consultar:

```bash
apptainer build --help
```

e:

```bash
apptainer exec --help
```

---

## 3.4 Faça um teste simples

Para verificar se o Apptainer consegue baixar e executar uma imagem:

```bash
apptainer exec docker://alpine cat /etc/os-release
```

Se funcionar, você verá informações sobre o sistema Alpine utilizado pela imagem.

Esse teste é útil porque verifica simultaneamente:

- Apptainer;
- acesso à imagem;
- execução do container;
- funcionamento básico do ambiente.

---

# 4. Cache e espaço em disco

Esta é uma das partes mais importantes quando se trabalha com Apptainer em servidores.

Durante downloads e builds, o Apptainer pode utilizar um cache, normalmente relacionado a:

```text
~/.apptainer/cache
```

Em um servidor, isso pode ser um problema se sua `/home` tiver pouco espaço.

Imagine:

```text
/home
└── seu_usuario
    └── .apptainer
        └── cache
```

e sua home possuir uma cota de apenas alguns GB.

Uma imagem ou um processo de construção pode ocupar espaço suficiente para atingir essa cota.

---

## 4.1 Verifique o espaço disponível

Execute:

```bash
df -h
```

Para verificar o tamanho utilizado na sua home:

```bash
du -sh ~
```

E, se existir:

```bash
du -sh ~/.apptainer
```

Também é útil verificar inodes:

```bash
df -i
```

---

## 4.2 Criando um cache em outro disco

Suponha que você tenha acesso a:

```text
/mnt/dados_lab
```

Crie seu cache:

```bash
mkdir -p /mnt/dados_lab/$USER/apptainer_cache
```

Configure temporariamente:

```bash
export APPTAINER_CACHEDIR=/mnt/dados_lab/$USER/apptainer_cache
```

Verifique:

```bash
echo $APPTAINER_CACHEDIR
```

Deverá aparecer algo como:

```text
/mnt/dados_lab/seu_usuario/apptainer_cache
```

---

## 4.3 Tornando a configuração permanente

Abra:

```bash
nano ~/.bashrc
```

Adicione:

```bash
export APPTAINER_CACHEDIR=/mnt/dados_lab/$USER/apptainer_cache
```

Salve e execute:

```bash
source ~/.bashrc
```

Confira:

```bash
echo $APPTAINER_CACHEDIR
```

---

## 4.4 Diretório temporário

O cache não é a única utilização de espaço durante um build.

Operações de construção também podem utilizar um diretório temporário.

Verifique:

```bash
echo $TMPDIR
```

e:

```bash
df -h /tmp
```

Se necessário, crie um diretório específico:

```bash
mkdir -p /mnt/dados_lab/$USER/apptainer_tmp
```

Configure:

```bash
export APPTAINER_TMPDIR=/mnt/dados_lab/$USER/apptainer_tmp
```

Se quiser tornar permanente, coloque também essa variável no `~/.bashrc`:

```bash
export APPTAINER_CACHEDIR=/mnt/dados_lab/$USER/apptainer_cache
export APPTAINER_TMPDIR=/mnt/dados_lab/$USER/apptainer_tmp
```

---

## 4.5 Limpando o cache

Veja o cache:

```bash
apptainer cache list
```

Para limpar:

```bash
apptainer cache clean
```

Antes de limpar, se quiser visualizar o que seria removido:

```bash
apptainer cache clean --dry-run
```

---

# 5. A receita `.def`: descrevendo o ambiente

A forma mais reprodutível de criar um container é utilizar um arquivo de definição.

Crie uma pasta:

```bash
mkdir -p ~/apptainer
cd ~/apptainer
```

Crie:

```bash
nano transcriptoma.def
```

Um arquivo `.def` possui diversas seções possíveis.

As mais importantes para começar são:

```text
Bootstrap:
From:

%post

%environment

%runscript

%test

%labels
```

Não é necessário utilizar todas em todos os projetos.

---

## 5.1 `Bootstrap` e `From`

Exemplo:

```text
Bootstrap: docker
From: ubuntu:22.04
```

Isso indica que o ambiente será construído a partir de uma imagem Ubuntu 22.04 disponível no ecossistema Docker/OCI.

Prefira versões específicas:

```text
From: ubuntu:22.04
```

em vez de:

```text
From: ubuntu:latest
```

quando a reprodutibilidade for importante.

---

## 5.2 `%post`

É nessa seção que instalamos os programas.

Exemplo:

```text
%post
    apt-get update
    apt-get install -y python3
```

Pense em `%post` como:

> "O que preciso fazer enquanto estou construindo o ambiente?"

---

## 5.3 `%environment`

Define variáveis de ambiente disponíveis durante a execução.

Exemplo:

```text
%environment
    export LC_ALL=C
    export PATH=/usr/local/bin:$PATH
```

---

## 5.4 `%runscript`

Define o comportamento de:

```bash
apptainer run imagem.sif
```

Por exemplo:

```text
%runscript
    echo "Container de Transcriptômica"
```

---

## 5.5 `%test`

É uma seção muito útil para verificar se o ambiente foi construído corretamente.

Exemplo:

```text
%test
    python3 --version
    R --version
    fastqc --version
    salmon --version
```

Depois:

```bash
apptainer test imagem.sif
```

---

## 5.6 `%labels`

Permite registrar informações sobre o ambiente:

```text
%labels
    Author "Seu Nome"
    Project "RNA-Seq"
    Version "1.0"
```

Depois podemos consultar essas informações com:

```bash
apptainer inspect --labels imagem.sif
```

---

# 6. Construindo o primeiro container

Vamos usar como exemplo um ambiente para transcriptômica.

Um `.def` inicial poderia ser:

```text
Bootstrap: docker
From: ubuntu:22.04

%labels
    Author "Seu Nome"
    Project "RNA-Seq"
    Version "1.0"

%post
    export DEBIAN_FRONTEND=noninteractive

    apt-get update

    apt-get install -y \
        wget \
        curl \
        ca-certificates \
        git \
        unzip \
        tar \
        gzip \
        bzip2 \
        python3 \
        python3-pip \
        python3-venv \
        r-base \
        fastqc \
        cutadapt \
        salmon

    python3 -m pip install --no-cache-dir multiqc

    curl -L \
        https://github.com/FelixKrueger/TrimGalore/archive/refs/tags/0.6.10.tar.gz \
        -o /tmp/trim_galore.tar.gz

    tar -xzf /tmp/trim_galore.tar.gz -C /tmp

    cp /tmp/TrimGalore-0.6.10/trim_galore \
        /usr/local/bin/trim_galore

    chmod +x /usr/local/bin/trim_galore

    rm -rf \
        /tmp/trim_galore.tar.gz \
        /tmp/TrimGalore-0.6.10

    apt-get clean
    rm -rf /var/lib/apt/lists/*

%environment
    export LC_ALL=C
    export PATH=/usr/local/bin:$PATH

%runscript
    echo "=========================================="
    echo " Container de Transcriptômica"
    echo "=========================================="
    echo
    echo "Ferramentas principais:"
    echo "  R"
    echo "  Python"
    echo "  FastQC"
    echo "  Cutadapt"
    echo "  Trim Galore"
    echo "  MultiQC"
    echo "  Salmon"

%test
    echo "Testando ferramentas..."

    python3 --version
    R --version
    fastqc --version
    cutadapt --version
    trim_galore --version
    salmon --version
    multiqc --version

    echo "Testes concluídos."
```

> O objetivo desse exemplo é ensinar a estrutura de um container. Em um projeto real, é importante também fixar versões das ferramentas e, quando necessário, utilizar fontes oficiais ou repositórios apropriados para cada software.

---

# 7. Sandbox: desenvolvendo o container aos poucos

Esta é uma parte importante para quem está começando.

Você pode chegar a uma situação em que ainda não sabe exatamente o que precisa instalar.

Por exemplo:

```text
"Preciso de R."

Depois:

"Também preciso de Python."

Depois:

"Agora descobri que preciso de samtools."

Depois:

"Esse pacote R também é necessário."

Nesse cenário, tentar construir imediatamente uma SIF perfeita pode ser trabalhoso.

O **sandbox** é muito útil para esse estágio.

---

## 7.1 Construindo um sandbox

A partir de um `.def`:

```bash
apptainer build --fakeroot --sandbox transcriptoma_sandbox/ transcriptoma.def
```

Você terá:

```text
transcriptoma_sandbox/
```

em vez de:

```text
transcriptoma.sif
```

---

## 7.2 Entrando no sandbox

Use:

```bash
apptainer shell --writable transcriptoma_sandbox/
```

O `--writable` permite modificar o sandbox durante essa sessão.

Você pode testar:

```bash
python3 --version
```

```bash
R --version
```

```bash
fastqc --version
```

---

## 7.3 Instalando algo manualmente no sandbox

Por exemplo, dentro do sandbox:

```bash
apt-get update
```

e:

```bash
apt-get install -y samtools
```

Depois:

```bash
samtools --version
```

Agora você possui um sandbox modificado.

### Mas atenção!

Isso **não significa que você terminou o trabalho**.

Se você simplesmente modificar o sandbox manualmente e depois guardar apenas o `.sif`, você pode perder a rastreabilidade de como aquele ambiente foi construído.

O fluxo correto é:

```text
sandbox
   │
   │ experimentar
   │
   ├── instalar
   ├── testar
   ├── corrigir
   └── descobrir dependências
            │
            ▼
      atualizar .def
            │
            ▼
      reconstruir ambiente
            │
            ▼
           .sif
```

O sandbox é um excelente **laboratório de desenvolvimento**.

O `.def` continua sendo a **receita oficial**.

---

# 8. Convertendo o sandbox em SIF

Depois que o sandbox estiver funcionando, você pode convertê-lo em uma imagem SIF.

Suponha:

```text
transcriptoma_sandbox/
```

Execute:

```bash
apptainer build transcriptoma.sif transcriptoma_sandbox/
```

O resultado será:

```text
transcriptoma.sif
```

A estrutura passa a ser:

```text
transcriptoma.def
transcriptoma_sandbox/
transcriptoma.sif
```

---

## 8.1 Teste a SIF

Primeiro:

```bash
apptainer test transcriptoma.sif
```

Depois:

```bash
apptainer exec transcriptoma.sif python3 --version
```

E:

```bash
apptainer exec transcriptoma.sif samtools --version
```

---

## 8.2 Uma observação importante sobre sandbox → SIF

A conversão:

```bash
apptainer build transcriptoma.sif transcriptoma_sandbox/
```

preserva o estado do sandbox naquele momento.

Porém, para um projeto científico reprodutível, você não deve depender apenas dessa conversão.

O ideal é que as modificações descobertas durante o desenvolvimento sejam incorporadas ao:

```text
transcriptoma.def
```

e que a SIF final seja reconstruída a partir da receita.

Assim:

```text
             DESENVOLVIMENTO

        transcriptoma_sandbox/
                 │
          descobrir o que
             é necessário
                 │
                 ▼
        transcriptoma.def
                 │
                 │ build
                 ▼
          transcriptoma.sif
                 │
                 ▼
             PRODUÇÃO
```

Esse é um dos pontos mais importantes para manter a reprodutibilidade.

---

# 9. Usando o container: `exec`, `shell` e `run`

Depois de criar a imagem, existem três comandos especialmente importantes.

---

## 9.1 `exec`: execute um comando específico

Estrutura:

```bash
apptainer exec imagem.sif comando
```

Exemplo:

```bash
apptainer exec transcriptoma.sif python3 --version
```

Outro:

```bash
apptainer exec transcriptoma.sif fastqc --version
```

Para pipelines, este será provavelmente o comando que você mais utilizará.

---

## 9.2 `shell`: entre no ambiente

Execute:

```bash
apptainer shell transcriptoma.sif
```

Você poderá executar:

```bash
python3 --version
```

```bash
R --version
```

```bash
fastqc --version
```

Quando terminar:

```bash
exit
```

O `shell` é especialmente útil para:

- aprender;
- explorar;
- descobrir caminhos;
- verificar instalações;
- diagnosticar problemas.

---

## 9.3 `run`: execute o `%runscript`

Se seu `.def` possui:

```text
%runscript
    echo "Container de Transcriptômica"
```

então:

```bash
apptainer run transcriptoma.sif
```

executará esse trecho.

---

## 9.4 Resumindo

| Comando | Uso |
|---|---|
| `exec` | Executar um programa específico |
| `shell` | Entrar no ambiente |
| `run` | Executar o `%runscript` |
| `build` | Criar/converter uma imagem |
| `pull` | Baixar uma imagem |
| `inspect` | Ver informações da imagem |
| `test` | Executar `%test` |

---

# 10. O conceito fundamental de `--bind`

Agora chegamos ao conceito mais importante para utilizar containers em bioinformática.

O container contém as ferramentas.

Seus dados permanecem no servidor.

Por exemplo:

```text
/mnt/projeto_rnaseq/
├── dados/
├── scripts/
└── resultados/
```

Você pode montar essa pasta no container:

```bash
--bind /mnt/projeto_rnaseq:/projeto
```

Isso cria:

```text
HOST                         CONTAINER

/mnt/projeto_rnaseq   →      /projeto
```

Assim, dentro do container:

```text
/projeto
```

representa:

```text
/mnt/projeto_rnaseq
```

no servidor.

---

## 10.1 O dado não foi copiado

Isso é importante.

Quando você faz:

```bash
--bind /mnt/projeto:/projeto
```

você não está simplesmente copiando os arquivos para dentro da imagem.

Você está tornando aquela pasta disponível ao container através de um bind mount.

Assim:

```text
HOST
/mnt/projeto
     │
     │ bind
     ▼
CONTAINER
/projeto
```

---

## 10.2 Exemplo

Suponha:

```text
/mnt/projeto_rnaseq/dados/amostra_01.fastq.gz
```

Execute:

```bash
apptainer exec \
    --bind /mnt/projeto_rnaseq:/projeto \
    transcriptoma.sif \
    ls -lh /projeto/dados
```

Você verá os arquivos existentes no host.

---

## 10.3 Bind somente leitura

Para dados brutos, uma excelente prática é utilizar:

```bash
:ro
```

Por exemplo:

```bash
--bind /mnt/projeto_rnaseq/dados:/dados:ro
```

`ro` significa:

```text
read-only
```

Assim, o programa poderá ler os FASTQ, mas não deverá modificá-los através desse mount.

---

## 10.4 Separando entrada e saída

Uma estrutura muito útil é:

```text
/projeto
├── dados/
├── resultados/
└── scripts/
```

E:

```bash
apptainer exec \
    --bind /mnt/projeto/dados:/dados:ro \
    --bind /mnt/projeto/resultados:/resultados \
    --bind /mnt/projeto/scripts:/scripts:ro \
    transcriptoma.sif \
    programa ...
```

Nesse modelo:

```text
dados       → leitura
scripts     → leitura
resultados  → leitura/escrita
```

Isso ajuda a proteger os arquivos de entrada.

---

# 11. Exemplos práticos em bioinformática

## 11.1 FastQC

Suponha:

```text
/mnt/projeto/dados/amostra_01.fastq.gz
/mnt/projeto/resultados/
```

Execute:

```bash
apptainer exec \
    --bind /mnt/projeto/dados:/dados:ro \
    --bind /mnt/projeto/resultados:/resultados \
    transcriptoma.sif \
    fastqc \
        /dados/amostra_01.fastq.gz \
        -o /resultados
```

O FastQC está dentro do container.

O FASTQ está fora.

O resultado é salvo fora.

---

## 11.2 Python

Suponha:

```text
/mnt/projeto/scripts/pca.py
/mnt/projeto/resultados/tpm.csv
```

Execute:

```bash
apptainer exec \
    --bind /mnt/projeto:/projeto \
    transcriptoma.sif \
    python3 \
        /projeto/scripts/pca.py \
        --matriz /projeto/resultados/tpm.csv
```

---

## 11.3 R

Execute um script:

```bash
apptainer exec \
    --bind /mnt/projeto:/projeto \
    transcriptoma.sif \
    Rscript \
        /projeto/scripts/analise.R
```

---

## 11.4 MultiQC

Depois de gerar diversos relatórios:

```bash
apptainer exec \
    --bind /mnt/projeto:/projeto \
    transcriptoma.sif \
    multiqc \
        /projeto/resultados \
        -o /projeto/resultados/multiqc
```

---

## 11.5 Salmon

Exemplo:

```bash
apptainer exec \
    --bind /mnt/projeto:/projeto \
    transcriptoma.sif \
    salmon quant \
        -i /projeto/reference/salmon_index \
        -l A \
        -1 /projeto/dados/sample_R1.fastq.gz \
        -2 /projeto/dados/sample_R2.fastq.gz \
        -o /projeto/resultados/sample
```

---

# 12. Como organizar um projeto

Uma estrutura recomendada é:

```text
meu_projeto/
│
├── container/
│   ├── transcriptoma.def
│   ├── transcriptoma.sif
│   └── README.md
│
├── data/
│   ├── raw/
│   ├── processed/
│   └── metadata/
│
├── reference/
│   ├── genome/
│   ├── annotation/
│   └── indexes/
│
├── scripts/
│   ├── 01_qc.sh
│   ├── 02_trim.sh
│   ├── 03_quantification.sh
│   └── 04_analysis.R
│
├── results/
│   ├── qc/
│   ├── trimmed/
│   ├── quantification/
│   ├── statistics/
│   └── figures/
│
└── logs/
```

---

## 12.1 O que fica dentro do container?

Normalmente:

```text
R
Python
FastQC
Cutadapt
Trim Galore
Salmon
MultiQC
bibliotecas
dependências
```

## 12.2 O que fica fora?

Normalmente:

```text
FASTQ
BAM
VCF
matrizes
metadata
resultados
scripts em desenvolvimento
```

Essa separação facilita manutenção e reprodução.

---

# 13. Reprodutibilidade e boas práticas

## 13.1 Não dependa apenas da SIF

É tentador pensar:

```text
"Tenho o .sif, então está tudo reproduzível."
```

O SIF é muito importante, mas registre também:

- arquivo `.def`;
- versões das ferramentas;
- scripts;
- parâmetros;
- origem da imagem;
- hash da SIF.

---

## 13.2 Versione o `.def`

Se utilizar Git, uma estrutura simples pode ser:

```text
container/
├── transcriptoma.def
├── transcriptoma.sif
├── README.md
└── versions.txt
```

O `.def` é particularmente importante porque permite reconstruir o ambiente.

---

## 13.3 Registre as versões

Por exemplo:

```bash
apptainer exec transcriptoma.sif python3 --version
```

```bash
apptainer exec transcriptoma.sif R --version
```

```bash
apptainer exec transcriptoma.sif fastqc --version
```

```bash
apptainer exec transcriptoma.sif salmon --version
```

---

## 13.4 Inspecione a imagem

```bash
apptainer inspect transcriptoma.sif
```

Labels:

```bash
apptainer inspect --labels transcriptoma.sif
```

---

## 13.5 Gere um hash

```bash
sha256sum transcriptoma.sif
```

Você pode guardar o resultado em:

```text
environment.txt
```

Exemplo:

```text
Container: transcriptoma.sif
SHA256: [hash]
Definition: transcriptoma.def
Project: RNA-Seq
```

Isso permite verificar posteriormente se a SIF utilizada continua sendo exatamente a mesma.

---

# 14. Problemas comuns e como diagnosticar

## 14.1 `No such file or directory`

Primeiro teste no host:

```bash
ls -lh /mnt/projeto/dados/amostra.fastq.gz
```

Depois dentro do container:

```bash
apptainer exec \
    --bind /mnt/projeto/dados:/dados \
    transcriptoma.sif \
    ls -lh /dados
```

Se o arquivo não aparece dentro do container, provavelmente o problema está no caminho ou no `--bind`.

---

## 14.2 `Permission denied`

Verifique:

```bash
id
```

Depois:

```bash
ls -ld /mnt/projeto
```

e:

```bash
ls -l /mnt/projeto
```

O container não concede automaticamente permissões que seu usuário não possui no host.

---

## 14.3 `No space left on device`

Verifique:

```bash
df -h
```

Depois:

```bash
df -h /tmp
```

e:

```bash
df -i
```

Também:

```bash
du -sh ~/.apptainer
```

e:

```bash
echo $APPTAINER_CACHEDIR
echo $APPTAINER_TMPDIR
```

As causas mais comuns são:

```text
/home cheia
/tmp cheio
cache cheio
disco de dados cheio
cota atingida
inodes esgotados
```

---

## 14.4 `fakeroot` não funciona

O `--fakeroot` depende de recursos disponíveis no sistema hospedeiro.

Se:

```bash
apptainer build --fakeroot ambiente.sif ambiente.def
```

falhar, verifique a mensagem de erro.

Em um servidor institucional, pode ser necessário que o administrador configure:

```text
user namespaces
subuid
subgid
fakeroot
```

Não tente alterar configurações administrativas do servidor sem autorização.

---

## 14.5 O programa funciona no host, mas não no container

Se:

```bash
fastqc --version
```

funciona, mas:

```bash
apptainer exec ambiente.sif fastqc --version
```

não funciona, isso significa simplesmente que o FastQC não está disponível dentro da imagem.

Isso é esperado.

O objetivo do container é justamente definir explicitamente o ambiente utilizado.

---

# 15. Fluxo de trabalho recomendado

Para quem está começando, recomendo separar o trabalho em duas fases.

## Fase 1 — Desenvolvimento

Quando ainda não sabe exatamente como será o ambiente:

```text
                 .def
                  │
                  ▼
              sandbox
                  │
          ┌───────┼────────┐
          │       │        │
       instalar testar   corrigir
          │       │        │
          └───────┴────────┘
                  │
                  ▼
          atualizar .def
                  │
                  ▼
              reconstruir
```

O sandbox funciona como um laboratório onde você pode experimentar.

---

## Fase 2 — Produção

Quando o ambiente estiver definido:

```text
              arquivo.def
                   │
                   │ build
                   ▼
             ambiente.sif
                   │
                   ▼
        apptainer exec + --bind
                   │
                   ▼
                 dados
                   │
                   ▼
              resultados
```

A SIF passa a ser a versão estável utilizada nas análises.

---

# 16. Comandos essenciais

| Objetivo | Comando |
|---|---|
| Ver versão | `apptainer --version` |
| Ajuda | `apptainer help` |
| Baixar imagem | `apptainer pull imagem.sif docker://ubuntu:22.04` |
| Construir SIF a partir de `.def` | `apptainer build --fakeroot imagem.sif ambiente.def` |
| Construir sandbox | `apptainer build --fakeroot --sandbox ambiente/ ambiente.def` |
| Entrar no sandbox gravável | `apptainer shell --writable ambiente/` |
| Converter sandbox em SIF | `apptainer build ambiente.sif ambiente/` |
| Executar comando | `apptainer exec imagem.sif comando` |
| Entrar na SIF | `apptainer shell imagem.sif` |
| Executar `%runscript` | `apptainer run imagem.sif` |
| Executar `%test` | `apptainer test imagem.sif` |
| Inspecionar imagem | `apptainer inspect imagem.sif` |
| Ver labels | `apptainer inspect --labels imagem.sif` |
| Listar cache | `apptainer cache list` |
| Limpar cache | `apptainer cache clean` |
| Calcular hash | `sha256sum imagem.sif` |

---

# 17. O que você realmente precisa memorizar

No começo, não tente decorar todos os comandos.

Concentre-se nestes conceitos:

### 1. `.def`

É a receita:

```text
ambiente.def
```

### 2. Sandbox

É o ambiente de desenvolvimento:

```text
ambiente/
```

Ele é útil quando você ainda está descobrindo o que precisa instalar.

### 3. `.sif`

É a versão consolidada:

```text
ambiente.sif
```

### 4. `build`

Cria ou converte uma imagem:

```bash
apptainer build ...
```

### 5. `exec`

Executa um programa:

```bash
apptainer exec ambiente.sif programa
```

### 6. `shell`

Entra no ambiente:

```bash
apptainer shell ambiente.sif
```

### 7. `--bind`

Conecta os dados do servidor ao container:

```bash
--bind /caminho/host:/caminho/container
```

---

# 18. O modelo mental definitivo

Se você guardar apenas uma coisa deste tutorial, guarde isto:

```text
                 RECEITA
              transcriptoma.def
                     │
                     │ build
                     ▼
              DESENVOLVIMENTO
             transcriptoma_sandbox/
                     │
              testar/modificar
                     │
                     ▼
                .def atualizado
                     │
                     │ build
                     ▼
                PRODUÇÃO
              transcriptoma.sif
                     │
                     │ exec
                     │
              +      │
                     │
               --bind
                     │
                     ▼
            DADOS DO PROJETO
                     │
                     ▼
               PROCESSAMENTO
                     │
                     ▼
                RESULTADOS
```

Em outras palavras:

> **`.def` descreve o ambiente.**
>
> **Sandbox permite desenvolver e experimentar.**
>
> **`.sif` representa o ambiente final.**
>
> **`--bind` conecta o container aos seus dados.**
>
> **`exec` executa as ferramentas dentro desse ambiente.**

Essa separação é o que torna o Apptainer especialmente interessante para projetos de bioinformática: você consegue manter o sistema operacional do servidor relativamente limpo, controlar as versões das ferramentas e transportar o mesmo ambiente computacional para diferentes máquinas.

---

## Referências

- Documentação oficial do Apptainer: https://apptainer.org/docs/user/latest/
- Definition Files: https://apptainer.org/docs/user/latest/definition_files.html
- Building Containers: https://apptainer.org/docs/user/latest/build_a_container.html
- Fakeroot: https://apptainer.org/docs/user/latest/fakeroot.html
- Environment and Cache: https://apptainer.org/docs/user/latest/build_env.html

