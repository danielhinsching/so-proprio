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

# read_packages <arquivo>: um pacote por linha, sem comentários, linhas em branco ou espaços.
read_packages() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && printf '%s\n' "$line"
  done < "$1"
}

# filter_missing: lê pacotes no stdin e imprime os que NÃO estão instalados.
filter_missing() {
  local pkg cmd="${DPKG_QUERY_CMD:-dpkg-query}"
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    # shellcheck disable=SC2016  # ${Status} é formato do dpkg-query
    if ! "$cmd" -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
      printf '%s\n' "$pkg"
    fi
  done
}

log_event() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/so-proprio"
  mkdir -p "$dir"
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$dir/add.log"
}

confirm() {
  [ "${ASSUME_YES:-0}" -eq 1 ] && return 0
  local answer
  printf '%s [s/N] ' "$1"
  read -r answer || return 1
  [[ "$answer" =~ ^[sSyY]$ ]]
}

# run_group <nome>: instala os pacotes faltantes do grupo e depois roda <nome>.sh, se houver.
run_group() {
  local name="$1" dir="${GRUPOS_DIR:?}" txt sh missing=()
  txt="$dir/$name.txt"; sh="$dir/$name.sh"
  local -a apt_cmd
  read -ra apt_cmd <<< "${APT_CMD:-sudo apt-get}"

  if [ -e "$txt" ]; then
    mapfile -t missing < <(read_packages "$txt" | filter_missing)
  fi

  echo "== Grupo: $name"
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "Pacotes: nada a instalar."
  else
    echo "Pacotes a instalar: ${missing[*]}"
  fi
  [ -e "$sh" ] && echo "Depois: executar grupos/$name.sh"

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    echo "(dry-run: nada foi alterado)"
    return 0
  fi

  if [ "${#missing[@]}" -gt 0 ] || [ -e "$sh" ]; then
    confirm "Continuar?" || { echo "Cancelado."; return 1; }
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    if ! "${apt_cmd[@]}" update; then
      echo "ERRO: falha ao atualizar a lista de pacotes (apt update). Confira a rede." >&2
      log_event "$name falhou (apt update)"
      return 1
    fi
    if ! "${apt_cmd[@]}" install -y "${missing[@]}"; then
      echo "ERRO: falha ao instalar: ${missing[*]}" >&2
      log_event "$name falhou (pacotes: ${missing[*]})"
      return 1
    fi
  fi

  if [ -e "$sh" ]; then
    if ! bash "$sh"; then
      echo "ERRO: grupos/$name.sh falhou" >&2
      log_event "$name falhou (script)"
      return 1
    fi
  fi

  log_event "$name ok (pacotes: ${missing[*]:-nenhum})"
  echo "Grupo $name concluído."
}
