#!/usr/bin/env bash
# Entrega a rede ao NetworkManager: o instalador do Debian deixa a placa configurada em
# /etc/network/interfaces (ifupdown), e as duas coisas brigam. Comenta essas linhas,
# guardando o original uma única vez, e reinicia o NetworkManager.
set -euo pipefail

ROOT="${ROOT_PREFIX:-}"
F="$ROOT/etc/network/interfaces"
SUDO=()
if [ -n "${SO_PROPRIO_SUDO:-}" ]; then
  read -ra SUDO <<< "$SO_PROPRIO_SUDO"   # gancho de teste
elif [ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ]; then
  SUDO=(sudo)
fi

if [ ! -f "$F" ]; then
  echo "Rede: $F não existe, nada a ajustar."
  exit 0
fi

# O arquivo costuma ser só do root (guarda a senha do Wi-Fi): ler com sudo, e parar se falhar.
CONTENT="$("${SUDO[@]}" cat "$F")" || { echo "ERRO: não consegui ler $F" >&2; exit 1; }
if ! printf '%s\n' "$CONTENT" | grep -v '^[[:space:]]*#' | grep -q '[^[:space:]]'; then
  echo "Rede: $F já está comentado, mantido."
  exit 0
fi

[ -e "$F.so-proprio.bak" ] || "${SUDO[@]}" cp -p "$F" "$F.so-proprio.bak"
tmp="$(mktemp)"
printf '%s\n' "$CONTENT" | awk '/^[[:space:]]*#/ || /^[[:space:]]*$/ { print; next } { print "# " $0 }' > "$tmp"
"${SUDO[@]}" install -m 0644 "$tmp" "$F"
rm -f "$tmp"

read -ra SC <<< "${SYSTEMCTL:-sudo systemctl}"
"${SC[@]}" restart NetworkManager
echo "Rede: /etc/network/interfaces comentado (original em interfaces.so-proprio.bak)."
echo "A conexão pode ter caído: rode 'sudo nmtui' e ative o Wi-Fi."
