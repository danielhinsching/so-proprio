#!/usr/bin/env bash
# Deixa o Openbox como gerenciador de janelas do LXQt, para o primeiro login
# não perguntar. Não sobrescreve uma escolha que o usuário já tenha feito.
set -euo pipefail

CONF="$HOME/.config/lxqt/session.conf"

if [ -f "$CONF" ] && grep -q '^window_manager=' "$CONF"; then
  echo "LXQt: gerenciador de janelas já escolhido ($(grep '^window_manager=' "$CONF" | cut -d= -f2))."
  exit 0
fi

mkdir -p "$(dirname "$CONF")"
if [ -f "$CONF" ] && grep -q '^\[General\]' "$CONF"; then
  sed -i '/^\[General\]/a window_manager=openbox' "$CONF"
else
  printf '[General]\nwindow_manager=openbox\n' >> "$CONF"
fi
echo "LXQt: Openbox definido como gerenciador de janelas."
