#!/usr/bin/env bash
# Visual do desktop: tema escuro, painel (dock central + barra de status),
# uma única área de trabalho e atalhos de teclado no Openbox.
# Não sobrescreve o que você já editou: o painel só é regerado se faltar a marca
# so_proprio=1 (ou com SO_PROPRIO_VISUAL_FORCE=1); o rc.xml do Openbox só ganha o que falta.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/ini.sh
source "$REPO_DIR/lib/ini.sh"

LXQT_DIR="$HOME/.config/lxqt"
PANEL="$LXQT_DIR/panel.conf"

# --- Tema do LXQt ---
ini_set "$LXQT_DIR/lxqt.conf" General theme dark
ini_set "$LXQT_DIR/lxqt.conf" General icon_theme breeze-dark
ini_set "$LXQT_DIR/lxqt.conf" General style Fusion
echo "LXQt: tema escuro."

# --- Painel ---
if [ -f "$PANEL" ] && grep -qx 'so_proprio=1' "$PANEL" && [ "${SO_PROPRIO_VISUAL_FORCE:-0}" != "1" ]; then
  echo "Painel: já configurado pelo so-proprio, mantido (SO_PROPRIO_VISUAL_FORCE=1 para regerar)."
else
  mkdir -p "$LXQT_DIR"
  if [ -f "$PANEL" ] && [ ! -e "$PANEL.so-proprio.bak" ]; then
    cp -p "$PANEL" "$PANEL.so-proprio.bak"
  fi
  cat > "$PANEL" <<'CONF'
[General]
__userfile__=true
panels=panel1, panel2
so_proprio=1

[panel1]
alignment=0
animation-duration=0
desktop=0
hidable=false
hide-on-overlap=false
iconSize=24
lineCount=1
lockPanel=false
opacity=100
panelSize=40
plugins=mainmenu, quicklaunch, taskbar
position=Bottom
reserve-space=true
show-delay=0
visible-margin=true
width=60
width-percent=true

[panel2]
alignment=-1
animation-duration=0
desktop=0
hidable=false
hide-on-overlap=false
iconSize=20
lineCount=1
lockPanel=false
opacity=100
panelSize=28
plugins=statusnotifier, tray, volume, worldclock
position=Top
reserve-space=true
show-delay=0
visible-margin=false
width=100
width-percent=true

[mainmenu]
alignment=Left
showText=false
type=mainmenu

[quicklaunch]
alignment=Left
apps\1\desktop=/usr/share/applications/firefox-esr.desktop
apps\2\desktop=/usr/share/applications/code.desktop
apps\3\desktop=/usr/share/applications/qterminal.desktop
apps\4\desktop=/usr/share/applications/pcmanfm-qt.desktop
apps\size=4
type=quicklaunch

[taskbar]
alignment=Left
buttonStyle=Icon
showOnlyCurrentDesktopTasks=false
type=taskbar

[statusnotifier]
alignment=Right
type=statusnotifier

[tray]
alignment=Right
type=tray

[volume]
alignment=Right
audioEngine=PulseAudio
mixerCommand=pavucontrol-qt
type=volume

[worldclock]
alignment=Right
type=worldclock
CONF
  echo "Painel: dock central embaixo (menu, apps, janelas) e barra em cima (rede, Bluetooth, bateria, volume, hora)."
  echo "Faça logout e login para o painel novo aparecer."
fi

# --- Openbox: uma área de trabalho e atalhos ---
RC="$HOME/.config/openbox/rc.xml"
DEFAULT_RC="${OPENBOX_DEFAULT_RC:-/etc/xdg/openbox/rc.xml}"
THEMES_DIR="${SO_PROPRIO_THEMES_DIR:-/usr/share/themes}"
if [ ! -f "$RC" ]; then
  if [ -f "$DEFAULT_RC" ]; then
    mkdir -p "$(dirname "$RC")"
    cp "$DEFAULT_RC" "$RC"
  else
    echo "Aviso: $DEFAULT_RC não existe (openbox instalado?); atalhos não configurados." >&2
  fi
fi
if [ -f "$RC" ]; then
  sed -i '/<desktops>/,/<\/desktops>/ s|<number>[0-9]*</number>|<number>1</number>|' "$RC"
  if [ -d "$THEMES_DIR/Onyx/openbox-3" ]; then
    sed -i '/<theme>/,/<\/theme>/ s|<name>Clearlooks</name>|<name>Onyx</name>|' "$RC"
  fi
  add_key() { # <tecla> <comando>
    grep -q "key=\"$1\"" "$RC" && return 0
    sed -i "s|</keyboard>|  <keybind key=\"$1\"><action name=\"Execute\"><command>$2</command></action></keybind>\n</keyboard>|" "$RC"
  }
  add_key C-A-t qterminal
  add_key C-A-f firefox-esr
  add_key C-A-c code
  openbox --reconfigure 2>/dev/null || true
  echo "Openbox: 1 área de trabalho; Ctrl+Alt+T terminal, Ctrl+Alt+F Firefox, Ctrl+Alt+C VS Code."
fi

# --- Bluetooth: o tuning antigo o desativava; religa para o ícone funcionar ---
read -ra SC <<< "${SYSTEMCTL:-sudo systemctl}"
if "${SC[@]}" list-unit-files bluetooth.service --no-legend 2>/dev/null | grep -q '^bluetooth\.service'; then
  "${SC[@]}" enable --now bluetooth.service
  echo "Bluetooth: serviço ligado."
fi
