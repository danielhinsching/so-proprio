#!/usr/bin/env bash
# Entrega a rede ao NetworkManager: o instalador do Debian deixa a placa configurada em
# /etc/network/interfaces (ifupdown), e as duas coisas brigam. Comenta essas linhas,
# guardando o original uma única vez, e reinicia o NetworkManager.
set -euo pipefail

ROOT="${ROOT_PREFIX:-}"
F="$ROOT/etc/network/interfaces"
SUDO=()
if [ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ]; then SUDO=(sudo); fi

if [ ! -f "$F" ]; then
  echo "Rede: $F não existe, nada a ajustar."
  exit 0
fi

if ! grep -v '^[[:space:]]*#' "$F" | grep -q '[^[:space:]]'; then
  echo "Rede: $F já está comentado, mantido."
  exit 0
fi

[ -e "$F.so-proprio.bak" ] || "${SUDO[@]}" cp -p "$F" "$F.so-proprio.bak"
tmp="$(mktemp)"
awk '/^[[:space:]]*#/ || /^[[:space:]]*$/ { print; next } { print "# " $0 }' "$F" > "$tmp"
"${SUDO[@]}" install -m 0644 "$tmp" "$F"
rm -f "$tmp"

read -ra SC <<< "${SYSTEMCTL:-sudo systemctl}"
"${SC[@]}" restart NetworkManager
echo "Rede: /etc/network/interfaces comentado (original em interfaces.so-proprio.bak)."
echo "A conexão pode ter caído: rode 'sudo nmtui' e ative o Wi-Fi."
