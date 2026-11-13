#!/usr/bin/env bash
# Edição de arquivos .ini (formato do LXQt/Qt). Carregado com `source`.

# ini_set <arquivo> <seção> <chave> <valor>: define chave=valor dentro de [seção].
# Cria arquivo e seção se faltarem; atualiza a chave se já existir; não duplica.
ini_set() {
  local file="$1" section="$2" key="$3" value="$4" tmp
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp "$file.XXXXXX")" || return 1
  awk -v s="$section" -v k="$key" -v v="$value" '
    function flush() { if (insec && !done) { print k "=" v; done = 1 } }
    /^\[.*\]$/ { flush(); insec = ($0 == "[" s "]"); if (insec) seen = 1; print; next }
    insec && index($0, k "=") == 1 { if (!done) { print k "=" v; done = 1 } next }
    { print }
    END { flush(); if (!seen) { if (NR > 0) print ""; print "[" s "]"; print k "=" v } }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod --reference="$file" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$file"
}
