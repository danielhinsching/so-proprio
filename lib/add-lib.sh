#!/usr/bin/env bash
# Funções do comando ./add. Carregado com `source`; não executar diretamente.

# list_groups <dir>: um grupo por linha, ordenado e sem duplicatas.
list_groups() {
  local dir="$1" f name
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.txt "$dir"/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    printf '%s\n' "${name%.*}"
  done | sort -u
}

# is_group <dir> <nome>: verdadeiro se existe <nome>.txt ou <nome>.sh.
is_group() {
  local dir="$1" name="$2"
  [[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || return 1
  [ -e "$dir/$name.txt" ] || [ -e "$dir/$name.sh" ]
}
