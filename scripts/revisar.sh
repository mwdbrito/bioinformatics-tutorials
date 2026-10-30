#!/usr/bin/env bash
# Gera a versão de revisão do site (com rascunhos) em revisao/site/
# e mostra o caminho para abrir no navegador do Windows.
set -euo pipefail
cd "$(dirname "$0")/.."
DISABLE_MKDOCS_2_WARNING=true mkdocs build -q -f mkdocs.revisao.yml
echo "Revisão gerada. Abra no navegador:"
for f in revisao/site/rascunhos/*.html; do
  [ -e "$f" ] || continue
  echo "  $(wslpath -w "$PWD/$f" 2>/dev/null || echo "$PWD/$f")"
done
