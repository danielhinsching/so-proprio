#!/usr/bin/env bash
# Deixa o Openbox como gerenciador de janelas do LXQt, para o primeiro login
# não perguntar. Não sobrescreve uma escolha que o usuário já tenha feito.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$HOME/.config/lxqt/session.conf"

if [ -f "$CONF" ] && grep -q '^window_manager=' "$CONF"; then
  echo "LXQt: gerenciador de janelas já escolhido ($(grep '^window_manager=' "$CONF" | cut -d= -f2))."
else
  mkdir -p "$(dirname "$CONF")"
  if [ -f "$CONF" ] && grep -q '^\[General\]' "$CONF"; then
    sed -i '/^\[General\]/a window_manager=openbox' "$CONF"
  else
    printf '[General]\nwindow_manager=openbox\n' >> "$CONF"
  fi
  echo "LXQt: Openbox definido como gerenciador de janelas."
fi

# Conky: free -h e systemd-analyze no fundo da tela (canto superior direito).
CONKY_CONF="$HOME/.config/conky/conky.conf"
if [ -f "$CONKY_CONF" ]; then
  echo "Conky: config já existe, mantida."
else
  mkdir -p "$(dirname "$CONKY_CONF")"
  cp "$REPO_DIR/dotfiles/conky/conky.conf" "$CONKY_CONF"
  echo "Conky: config criada em $CONKY_CONF."
fi

AUTOSTART="$HOME/.config/autostart/conky-so-proprio.desktop"
if [ ! -f "$AUTOSTART" ]; then
  mkdir -p "$(dirname "$AUTOSTART")"
  cat > "$AUTOSTART" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Conky (so-proprio)
Comment=Memória e tempo de boot no fundo da tela
Exec=sh -c "sleep 5; exec conky"
DESKTOP
  echo "Conky: inicia sozinho no login."
fi
