#!/usr/bin/env bash
# Visual do desktop: tema escuro, painel (dock central + barra de status),
# uma única área de trabalho e atalhos de teclado no Openbox.
# Não sobrescreve o que você já editou: o painel só é regerado se faltar a marca
# so_proprio=2 (ou com SO_PROPRIO_VISUAL_FORCE=1); o rc.xml do Openbox só ganha o que falta.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/ini.sh
source "$REPO_DIR/lib/ini.sh"

LXQT_DIR="$HOME/.config/lxqt"
PANEL="$LXQT_DIR/panel.conf"

# --- Aparência: claro (padrão) ou escuro, com SO_PROPRIO_TEMA=escuro ---
if [ "${SO_PROPRIO_TEMA:-claro}" = "escuro" ]; then
  MODE=escuro; LXQT_THEME=dark; ICONS=Papirus-Dark; PREFER_DARK=true
  BG='#1c1c1e'; BG_INACTIVE='#2c2c2e'; TEXT='#f5f5f7'; SUBTLE='#8e8e93'
  BORDER='#3a3a3c'; HOVER='#3a3a3c'; PRESSED='#48484a'; MENU='#2c2c2e'
else
  MODE=claro; LXQT_THEME=light; ICONS=Papirus; PREFER_DARK=false
  BG='#f5f5f7'; BG_INACTIVE='#ececec'; TEXT='#1d1d1f'; SUBTLE='#8e8e93'
  BORDER='#d2d2d7'; HOVER='#e5e5ea'; PRESSED='#d1d1d6'; MENU='#ffffff'
fi
ACCENT='#0a84ff'

ini_set "$LXQT_DIR/lxqt.conf" General theme "$LXQT_THEME"
ini_set "$LXQT_DIR/lxqt.conf" General icon_theme "$ICONS"
ini_set "$LXQT_DIR/lxqt.conf" Qt style Fusion
ini_set "$LXQT_DIR/lxqt.conf" Qt font '"Inter,10,-1,5,50,0,0,0,0,0"'
ini_set "$HOME/.config/gtk-3.0/settings.ini" Settings gtk-font-name 'Inter 10'
ini_set "$HOME/.config/gtk-3.0/settings.ini" Settings gtk-icon-theme-name "$ICONS"
ini_set "$HOME/.config/gtk-3.0/settings.ini" Settings gtk-application-prefer-dark-theme "$PREFER_DARK"

WALL="$HOME/.local/share/so-proprio/wallpaper.png"
mkdir -p "$(dirname "$WALL")"
cp "$REPO_DIR/dotfiles/wallpaper/$MODE.png" "$WALL"
ini_set "$HOME/.config/pcmanfm-qt/lxqt/settings.conf" Desktop Wallpaper "$WALL"
ini_set "$HOME/.config/pcmanfm-qt/lxqt/settings.conf" Desktop WallpaperMode zoom
echo "Aparência: tema $MODE, ícones $ICONS, fonte Inter, papel de parede novo."

# --- Tema das janelas do Openbox (SoProprio): plano, sem bordas pesadas ---
OB_THEME="$HOME/.themes/SoProprio/openbox-3"
mkdir -p "$OB_THEME"
{
  cat <<THEME
border.width: 1
padding.width: 10
padding.height: 8
window.handle.width: 0
window.client.padding.width: 0
menu.overlap: 0
window.label.text.justify: center
window.active.border.color: $BORDER
window.inactive.border.color: $BORDER
window.active.title.separator.color: $BG
window.inactive.title.separator.color: $BG_INACTIVE
window.active.title.bg: flat solid
window.active.title.bg.color: $BG
window.inactive.title.bg: flat solid
window.inactive.title.bg.color: $BG_INACTIVE
window.active.label.bg: parentrelative
window.inactive.label.bg: parentrelative
window.active.label.text.color: $TEXT
window.inactive.label.text.color: $SUBTLE
window.active.handle.bg: flat solid
window.active.handle.bg.color: $BG
window.inactive.handle.bg: flat solid
window.inactive.handle.bg.color: $BG_INACTIVE
window.active.grip.bg: flat solid
window.active.grip.bg.color: $BG
window.inactive.grip.bg: flat solid
window.inactive.grip.bg.color: $BG_INACTIVE
menu.border.width: 1
menu.border.color: $BORDER
menu.separator.color: $BORDER
menu.separator.width: 1
menu.separator.padding.width: 6
menu.separator.padding.height: 3
menu.title.bg: flat solid
menu.title.bg.color: $BG
menu.title.text.color: $SUBTLE
menu.title.text.justify: left
menu.items.bg: flat solid
menu.items.bg.color: $MENU
menu.items.text.color: $TEXT
menu.items.disabled.text.color: $SUBTLE
menu.items.active.bg: flat solid
menu.items.active.bg.color: $ACCENT
menu.items.active.text.color: #ffffff
menu.items.active.disabled.text.color: #ffffff
osd.border.width: 1
osd.border.color: $BORDER
osd.bg: flat solid
osd.bg.color: $MENU
osd.label.bg: parentrelative
osd.label.text.color: $TEXT
osd.hilight.bg: flat solid
osd.hilight.bg.color: $ACCENT
osd.unhilight.bg: flat solid
osd.unhilight.bg.color: $HOVER
THEME
  for win in active inactive; do
    bgc="$BG"; [ "$win" = inactive ] && bgc="$BG_INACTIVE"
    img="$TEXT"; [ "$win" = inactive ] && img="$SUBTLE"
    for st in unpressed pressed hover disabled toggled; do
      c="$bgc"; ic="$img"
      [ "$st" = hover ] && { c="$HOVER"; ic="$TEXT"; }
      [ "$st" = pressed ] && { c="$PRESSED"; ic="$TEXT"; }
      [ "$st" = disabled ] && ic="$SUBTLE"
      printf 'window.%s.button.%s.bg: flat solid\n' "$win" "$st"
      printf 'window.%s.button.%s.bg.color: %s\n' "$win" "$st" "$c"
      printf 'window.%s.button.%s.image.color: %s\n' "$win" "$st" "$ic"
    done
  done
} > "$OB_THEME/themerc"
for f in close iconify max max_toggled desk desk_toggled shade shade_toggled; do
  cp "$REPO_DIR/dotfiles/openbox/$f.xbm" "$OB_THEME/$f.xbm"
done

# --- Ícone do botão do menu (grade de apps) ---
ICON_DIR="$HOME/.local/share/icons/hicolor/64x64/apps"
mkdir -p "$ICON_DIR"
cp "$REPO_DIR/dotfiles/icons/so-proprio-menu.png" "$ICON_DIR/so-proprio-menu.png"

# --- Bateria: cbatticon usa os ícones do tema; o do LXQt é um gráfico de pizza ---
ini_set "$LXQT_DIR/lxqt-powermanagement.conf" General showIcon false
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/so-proprio-bateria.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Bateria (so-proprio)
Exec=cbatticon -u 30
DESKTOP

# --- Pré-carga: VS Code e Firefox lidos para a memória logo depois do login ---
# No HD, a primeira abertura é o que demora; com 9 GB de RAM sobrando, o cache de disco guarda os dois.
cat > "$HOME/.config/autostart/so-proprio-precarga.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Pré-carga do VS Code e do Firefox (so-proprio)
Exec=sh -c "sleep 20; exec ionice -c3 nice -n19 sh -c 'find /usr/share/code /usr/lib/firefox-esr -type f -size +64k -exec cat {} + >/dev/null 2>&1'"
DESKTOP

# --- Touchpad: rolagem invertida (natural, como no macOS) e toque para clicar ---
# Vale a partir do próximo login (o Xorg lê esse arquivo ao iniciar).
ROOT="${ROOT_PREFIX:-}"
SUDO=()
if [ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ]; then SUDO=(sudo); fi
TP_TMP="$(mktemp)"
cat > "$TP_TMP" <<'XORG'
Section "InputClass"
    Identifier "so-proprio touchpad"
    MatchIsTouchpad "on"
    MatchDriver "libinput"
    Option "NaturalScrolling" "true"
    Option "Tapping" "on"
    Option "DisableWhileTyping" "on"
    Option "ClickMethod" "clickfinger"
EndSection
XORG
"${SUDO[@]}" install -D -m 0644 "$TP_TMP" "$ROOT/etc/X11/xorg.conf.d/40-so-proprio-touchpad.conf"
rm -f "$TP_TMP"
echo "Touchpad: rolagem invertida e toque para clicar (vale no próximo login)."

# --- Painel ---
if [ -f "$PANEL" ] && grep -qx 'so_proprio=2' "$PANEL" && [ "${SO_PROPRIO_VISUAL_FORCE:-0}" != "1" ]; then
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
so_proprio=2

[panel1]
alignment=0
animation-duration=0
desktop=0
hidable=true
hide-on-overlap=false
iconSize=24
lineCount=1
lockPanel=false
opacity=100
panelSize=40
plugins=mainmenu, quicklaunch, taskbar
position=Bottom
reserve-space=false
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
icon=so-proprio-menu
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
  sed -i -E '/<theme>/,/<\/theme>/ { s#<name>(Clearlooks|Onyx|SoProprio)</name>#<name>SoProprio</name>#; s#<titleLayout>[A-Z]*</titleLayout>#<titleLayout>LIMC</titleLayout># }' "$RC"
  add_key() { # <tecla> <comando>
    grep -q "key=\"$1\"" "$RC" && return 0
    sed -i "s|</keyboard>|  <keybind key=\"$1\"><action name=\"Execute\"><command>$2</command></action></keybind>\n</keyboard>|" "$RC"
  }
  add_key C-A-t qterminal
  add_key C-A-f firefox-esr
  add_key C-A-c code
  add_key W-l light-locker-command\ -l
  add_key Print screengrab\ -r
  add_key XF86MonBrightnessUp brightnessctl\ set\ +5%
  add_key XF86MonBrightnessDown brightnessctl\ set\ 5%-
  add_key XF86AudioRaiseVolume wpctl\ set-volume\ -l\ 1.0\ @DEFAULT_AUDIO_SINK@\ 5%+
  add_key XF86AudioLowerVolume wpctl\ set-volume\ @DEFAULT_AUDIO_SINK@\ 5%-
  add_key XF86AudioMute wpctl\ set-mute\ @DEFAULT_AUDIO_SINK@\ toggle
  openbox --reconfigure 2>/dev/null || true
  echo "Openbox: tema SoProprio, 1 área de trabalho; Ctrl+Alt+T terminal, Ctrl+Alt+F Firefox, Ctrl+Alt+C VS Code, Super+L bloqueia, Print captura a tela, teclas de brilho e volume."
fi

# --- Bluetooth: o tuning antigo o desativava; religa para o ícone funcionar ---
read -ra SC <<< "${SYSTEMCTL:-sudo systemctl}"
if "${SC[@]}" list-unit-files bluetooth.service --no-legend 2>/dev/null | grep -q '^bluetooth\.service'; then
  "${SC[@]}" enable --now bluetooth.service
  echo "Bluetooth: serviço ligado."
fi
