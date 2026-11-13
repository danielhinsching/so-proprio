#!/usr/bin/env bats
# Grupos visual, navegador (Firefox), base (rede) e ajustes novos do tuning.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export ROOT_PREFIX="$TMP/root"
  mkdir -p "$ROOT_PREFIX/etc"
  # systemctl falso: registra a chamada e finge que a unidade existe
  cat > "$TMP/systemctl" <<'S'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_SC_LOG"
if [ "$1" = "list-unit-files" ]; then echo "$2 enabled"; fi
exit 0
S
  chmod +x "$TMP/systemctl"
  export FAKE_SC_LOG="$TMP/sc.log" SYSTEMCTL="$TMP/systemctl"
  # rc.xml padrão do Openbox (resumo do original do Debian)
  mkdir -p "$TMP/xdg/openbox"
  cat > "$TMP/xdg/openbox/rc.xml" <<'X'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout></theme>
  <desktops><number>4</number><firstdesk>1</firstdesk></desktops>
  <keyboard>
    <keybind key="A-F4"><action name="Close"/></keybind>
  </keyboard>
</openbox_config>
X
  export OPENBOX_DEFAULT_RC="$TMP/xdg/openbox/rc.xml"
  export SO_PROPRIO_LXQT_THEMES_DIR="$TMP/lxqt-themes"
  for t in light dark; do
    mkdir -p "$SO_PROPRIO_LXQT_THEMES_DIR/$t"
    echo "/* tema $t */" > "$SO_PROPRIO_LXQT_THEMES_DIR/$t/lxqt-panel.qss"
    echo "[General]" > "$SO_PROPRIO_LXQT_THEMES_DIR/$t/lxqt-theme.conf"
  done
}

teardown() { rm -rf "$TMP"; }

run_visual() { bash "$REPO/grupos/visual.sh"; }
panel_conf() { echo "$HOME/.config/lxqt/panel.conf"; }

# --- painel ---

@test "visual.sh cria dois painéis: dock central embaixo e barra de status em cima" {
  run_visual
  c="$(panel_conf)"
  grep -qx 'panels=panel1, panel2' "$c" || grep -qx 'panels=panel1,panel2' "$c"
  grep -q '^position=Bottom' "$c"
  grep -q '^position=Top' "$c"
  # a dock é centralizada e não ocupa a largura toda
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'alignment=0'
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'width-percent=true'
}

@test "o painel não tem botão de áreas de trabalho" {
  run_visual
  ! grep -qi 'desktopswitch' "$(panel_conf)"
}

@test "o painel tem menu, atalhos de apps, janelas, bandeja, volume e relógio" {
  run_visual
  c="$(panel_conf)"
  for t in mainmenu quicklaunch taskbar statusnotifier tray volume worldclock; do
    grep -qx "type=$t" "$c" || { echo "falta $t"; return 1; }
  done
  grep -q 'firefox-esr.desktop' "$c"
  grep -q 'code.desktop' "$c"
  grep -q 'qterminal.desktop' "$c"
}

@test "visual.sh guarda backup do painel existente e não sobrescreve depois" {
  mkdir -p "$HOME/.config/lxqt"
  echo '[General]' > "$HOME/.config/lxqt/panel.conf"
  echo 'original=1' >> "$HOME/.config/lxqt/panel.conf"
  run_visual
  grep -qx 'original=1' "$HOME/.config/lxqt/panel.conf.so-proprio.bak"
  ! grep -qx 'original=1' "$(panel_conf)"
  echo 'minha_edicao=1' >> "$(panel_conf)"
  run_visual
  grep -qx 'minha_edicao=1' "$(panel_conf)"
}

@test "SO_PROPRIO_VISUAL_FORCE=1 regera o painel" {
  run_visual
  echo 'minha_edicao=1' >> "$(panel_conf)"
  SO_PROPRIO_VISUAL_FORCE=1 run_visual
  ! grep -qx 'minha_edicao=1' "$(panel_conf)"
}

# --- Openbox: atalhos e uma área de trabalho ---

@test "visual.sh cria os atalhos Ctrl+Alt+T/F/C no Openbox" {
  run_visual
  rc="$HOME/.config/openbox/rc.xml"
  grep -q 'key="C-A-t"' "$rc"; grep -q '<command>qterminal</command>' "$rc"
  grep -q 'key="C-A-f"' "$rc"; grep -q '<command>firefox-esr</command>' "$rc"
  grep -q 'key="C-A-c"' "$rc"; grep -q '<command>code</command>' "$rc"
  xmllint --noout "$rc"
}

@test "o Openbox fica com uma única área de trabalho" {
  run_visual
  grep -q '<number>1</number>' "$HOME/.config/openbox/rc.xml"
  ! grep -q '<number>4</number>' "$HOME/.config/openbox/rc.xml"
}

@test "rodar visual.sh duas vezes não duplica atalhos" {
  run_visual; run_visual
  [ "$(grep -c 'key="C-A-f"' "$HOME/.config/openbox/rc.xml")" -eq 1 ]
  [ "$(grep -c 'key="C-A-t"' "$HOME/.config/openbox/rc.xml")" -eq 1 ]
}

@test "visual.sh usa o tema limpo SoProprio no Openbox, com botões à direita e sem o de áreas de trabalho" {
  run_visual
  rc="$HOME/.config/openbox/rc.xml"
  grep -q '<name>SoProprio</name>' "$rc"
  grep -q '<titleLayout>LIMC</titleLayout>' "$rc"
  t="$HOME/.themes/SoProprio/openbox-3"
  [ -f "$t/themerc" ]
  for b in close iconify max max_toggled; do [ -f "$t/$b.xbm" ] || { echo "falta $b.xbm"; return 1; }; done
  grep -q '^window.active.title.bg.color: #f5f5f7' "$t/themerc"
  grep -q '^menu.items.active.bg.color: #0a84ff' "$t/themerc"
}

@test "o tema SoProprio do Openbox também troca o Onyx de uma execução anterior" {
  mkdir -p "$HOME/.config/openbox"
  sed 's/Clearlooks/Onyx/' "$OPENBOX_DEFAULT_RC" > "$HOME/.config/openbox/rc.xml"
  run_visual
  grep -q '<name>SoProprio</name>' "$HOME/.config/openbox/rc.xml"
}

@test "SO_PROPRIO_TEMA=escuro usa a paleta escura em tudo" {
  SO_PROPRIO_TEMA=escuro run_visual
  grep -q '^window.active.title.bg.color: #1c1c1e' "$HOME/.themes/SoProprio/openbox-3/themerc"
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=so-proprio-escuro'
  grep -qx 'icon_theme=Papirus-Dark' "$HOME/.config/lxqt/lxqt.conf"
  grep -qx 'gtk-application-prefer-dark-theme=true' "$HOME/.config/gtk-3.0/settings.ini"
  cmp -s "$HOME/.local/share/so-proprio/wallpaper.png" "$REPO/dotfiles/wallpaper/escuro.png"
}

@test "visual.sh mantém o rc.xml que o usuário já tinha, só acrescentando o que falta" {
  mkdir -p "$HOME/.config/openbox"
  sed 's/Clearlooks/MeuTema/' "$OPENBOX_DEFAULT_RC" > "$HOME/.config/openbox/rc.xml"
  run_visual
  grep -q '<name>MeuTema</name>' "$HOME/.config/openbox/rc.xml"
  grep -q 'key="C-A-f"' "$HOME/.config/openbox/rc.xml"
}

@test "visual.sh usa por padrão o tema claro do LXQt, ícones Papirus e a fonte Inter" {
  run_visual
  c="$HOME/.config/lxqt/lxqt.conf"
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'theme=so-proprio-claro'
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'icon_theme=Papirus'
  awk '/^\[Qt\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'style=Fusion'
  awk '/^\[Qt\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -q '^font=.*Inter'
}

@test "visual.sh configura os apps GTK (Firefox, Blueman) com a mesma fonte e ícones" {
  run_visual
  g="$HOME/.config/gtk-3.0/settings.ini"
  grep -qx 'gtk-font-name=Inter 10' "$g"
  grep -qx 'gtk-icon-theme-name=Papirus' "$g"
  grep -qx 'gtk-application-prefer-dark-theme=false' "$g"
}

@test "visual.sh instala o papel de parede limpo e aponta o PCManFM-Qt para ele" {
  run_visual
  w="$HOME/.local/share/so-proprio/wallpaper.png"
  [ -s "$w" ]
  s="$HOME/.config/pcmanfm-qt/lxqt/settings.conf"
  grep -qx "Wallpaper=$w" "$s"
  grep -qx 'WallpaperMode=zoom' "$s"
}

@test "os papéis de parede do repo são PNG" {
  for f in claro escuro; do
    [ "$(head -c 8 "$REPO/dotfiles/wallpaper/$f.png" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
  done
}

@test "visual.sh religa o Bluetooth, que o tuning antigo desativava" {
  run_visual
  grep -q 'enable --now bluetooth.service' "$FAKE_SC_LOG"
}

@test "visual.txt traz rede, Bluetooth, volume e o mixer" {
  source "$REPO/lib/add-lib.sh"
  for p in nm-tray blueman bluez pipewire-audio pavucontrol-qt papirus-icon-theme fonts-inter; do
    read_packages "$REPO/grupos/visual.txt" | grep -qx "$p" || { echo "falta $p"; return 1; }
  done
}

# --- Firefox ---

@test "navegador.sh grava as políticas do Firefox nos dois caminhos do Debian, em JSON válido" {
  bash "$REPO/grupos/navegador.sh"
  for d in firefox-esr firefox; do
    f="$ROOT_PREFIX/etc/$d/policies/policies.json"
    [ -f "$f" ]
    python3 -m json.tool "$f" >/dev/null
    grep -q 'DisableTelemetry' "$f"
    grep -q 'uBlock0@raymondhill.net' "$f"
  done
}

@test "navegador.sh grava as preferências de baixo consumo" {
  bash "$REPO/grupos/navegador.sh"
  f="$ROOT_PREFIX/usr/lib/firefox-esr/defaults/pref/so-proprio.js"
  grep -q 'pref("browser.cache.disk.enable", false);' "$f"
  grep -q 'pref("dom.ipc.processCount", 3);' "$f"
  grep -q 'pref("browser.sessionstore.interval", 60000);' "$f"
}

@test "navegador.sh é idempotente" {
  bash "$REPO/grupos/navegador.sh"
  cp "$ROOT_PREFIX/usr/lib/firefox-esr/defaults/pref/so-proprio.js" "$TMP/antes"
  bash "$REPO/grupos/navegador.sh"
  cmp "$ROOT_PREFIX/usr/lib/firefox-esr/defaults/pref/so-proprio.js" "$TMP/antes"
}

@test "navegador.txt inclui o decodificador de vídeo da GPU" {
  source "$REPO/lib/add-lib.sh"
  read_packages "$REPO/grupos/navegador.txt" | grep -qx mesa-va-drivers
}

# --- base: rede entregue ao NetworkManager ---

write_interfaces() {
  mkdir -p "$ROOT_PREFIX/etc/network"
  cat > "$ROOT_PREFIX/etc/network/interfaces" <<'I'
# This file describes the network interfaces available on your system
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug wlp3s0
iface wlp3s0 inet dhcp
	wpa-ssid celular
	wpa-psk segredo
I
}

@test "base.sh comenta o /etc/network/interfaces, com backup, e reinicia o NetworkManager" {
  write_interfaces
  bash "$REPO/grupos/base.sh"
  f="$ROOT_PREFIX/etc/network/interfaces"
  [ -f "$f.so-proprio.bak" ]
  grep -q '^wpa-ssid\|^[[:space:]]*wpa-ssid' "$f.so-proprio.bak"
  # nenhuma linha ativa sobrou
  ! grep -v '^[[:space:]]*#' "$f" | grep -q '[^[:space:]]'
  grep -q 'restart NetworkManager' "$FAKE_SC_LOG"
}

@test "base.sh duas vezes não mexe de novo nem sobrescreve o backup" {
  write_interfaces
  bash "$REPO/grupos/base.sh"
  cp "$ROOT_PREFIX/etc/network/interfaces" "$TMP/depois1"
  : > "$FAKE_SC_LOG"
  bash "$REPO/grupos/base.sh"
  cmp "$ROOT_PREFIX/etc/network/interfaces" "$TMP/depois1"
  grep -q 'wpa-ssid' "$ROOT_PREFIX/etc/network/interfaces.so-proprio.bak"
  ! grep -q restart "$FAKE_SC_LOG"
}

@test "base.sh sem /etc/network/interfaces não falha" {
  run bash "$REPO/grupos/base.sh"
  [ "$status" -eq 0 ]
}

# --- tuning: GRUB e Bluetooth ---

@test "tuning grava GRUB_TIMEOUT=1 sem duplicar" {
  source "$REPO/tuning/lib.sh"
  mkdir -p "$ROOT_PREFIX/etc/default"
  printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX=""\n' > "$ROOT_PREFIX/etc/default/grub"
  set_grub_timeout "$ROOT_PREFIX"; set_grub_timeout "$ROOT_PREFIX"
  [ "$(grep -c '^GRUB_TIMEOUT=' "$ROOT_PREFIX/etc/default/grub")" -eq 1 ]
  grep -qx 'GRUB_TIMEOUT=1' "$ROOT_PREFIX/etc/default/grub"
  grep -qx 'GRUB_DEFAULT=0' "$ROOT_PREFIX/etc/default/grub"
}

@test "tuning/apply.sh não lista o Bluetooth entre os serviços desativados" {
  run "$REPO/tuning/apply.sh" --dry-run
  [[ "$output" != *bluetooth* ]]
  [[ "$output" == *GRUB_TIMEOUT* ]]
}

# --- ini helper ---

@test "ini_set cria arquivo, seção e chave, e atualiza sem duplicar" {
  source "$REPO/lib/ini.sh"
  f="$TMP/x.conf"
  ini_set "$f" General theme dark
  ini_set "$f" General style Fusion
  ini_set "$f" General theme light
  ini_set "$f" Outra a b
  [ "$(grep -c '^theme=' "$f")" -eq 1 ]
  grep -qx 'theme=so-proprio-claro' "$f"; grep -qx 'style=Fusion' "$f"
  awk '/^\[Outra\]/{p=1;next} /^\[/{p=0} p' "$f" | grep -qx 'a=b'
}

@test "base.sh lê o /etc/network/interfaces com sudo (o arquivo costuma ser só do root)" {
  write_interfaces
  cat > "$TMP/fakesudo" <<'S'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_SUDO_LOG"
exec "$@"
S
  chmod +x "$TMP/fakesudo"
  export FAKE_SUDO_LOG="$TMP/sudo.log" SO_PROPRIO_SUDO="$TMP/fakesudo"
  bash "$REPO/grupos/base.sh"
  grep -q 'cat .*/etc/network/interfaces' "$FAKE_SUDO_LOG"
  ! grep -v '^[[:space:]]*#' "$ROOT_PREFIX/etc/network/interfaces" | grep -q '[^[:space:]]'
}

@test "base.sh falha em voz alta se não conseguir ler o arquivo" {
  write_interfaces
  printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/badsudo"; chmod +x "$TMP/badsudo"
  SO_PROPRIO_SUDO="$TMP/badsudo" run bash "$REPO/grupos/base.sh"
  [ "$status" -ne 0 ]
}

# --- segunda rodada de ajustes do visual ---

@test "a dock de baixo se esconde sozinha e a barra de cima não" {
  run_visual
  c="$(panel_conf)"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'hidable=true'
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'reserve-space=false'
  awk '/^\[panel2\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'hidable=false'
}

@test "um painel da versão antiga (so_proprio=1) é regerado com a versão nova" {
  mkdir -p "$HOME/.config/lxqt"
  printf '[General]\nso_proprio=1\n[panel1]\nhidable=false\n' > "$(panel_conf)"
  run_visual
  grep -qx 'so_proprio=3' "$(panel_conf)"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$(panel_conf)" | grep -qx 'hidable=true'
}

@test "o botão do menu usa um ícone próprio, instalado no tema hicolor" {
  run_visual
  grep -qx 'icon=so-proprio-menu' "$(panel_conf)"
  i="$HOME/.local/share/icons/hicolor/64x64/apps/so-proprio-menu.png"
  [ "$(head -c 8 "$i" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
}

@test "a bateria usa o cbatticon e o ícone de pizza do LXQt é desligado" {
  run_visual
  grep -qx 'showIcon=false' "$HOME/.config/lxqt/lxqt-powermanagement.conf"
  grep -q '^Exec=cbatticon' "$HOME/.config/autostart/so-proprio-bateria.desktop"
}

@test "teclas de brilho, volume, Print e bloqueio de tela estão no Openbox" {
  run_visual
  rc="$HOME/.config/openbox/rc.xml"
  for k in XF86MonBrightnessUp XF86MonBrightnessDown XF86AudioRaiseVolume XF86AudioLowerVolume XF86AudioMute Print W-l; do
    grep -q "key=\"$k\"" "$rc" || { echo "falta $k"; return 1; }
  done
  grep -q '<command>brightnessctl set +5%</command>' "$rc"
  grep -q '<command>brightnessctl set 5%-</command>' "$rc"
  grep -q '<command>screengrab -r</command>' "$rc"
  grep -q '<command>light-locker-command -l</command>' "$rc"
  xmllint --noout "$rc"
}

@test "o touchpad usa rolagem invertida (natural) e toque para clicar" {
  run_visual
  f="$ROOT_PREFIX/etc/X11/xorg.conf.d/40-so-proprio-touchpad.conf"
  grep -q 'Option "NaturalScrolling" "true"' "$f"
  grep -q 'Option "Tapping" "on"' "$f"
  grep -q 'MatchIsTouchpad "on"' "$f"
}

@test "o VS Code e o Firefox são pré-carregados em segundo plano depois do login" {
  run_visual
  a="$HOME/.config/autostart/so-proprio-precarga.desktop"
  grep -q '^Exec=.*ionice -c3' "$a"
  grep -q '/usr/share/code' "$a"
  grep -q '/usr/lib/firefox-esr' "$a"
}

@test "visual.txt traz brilho, bateria, captura de tela e bloqueio" {
  source "$REPO/lib/add-lib.sh"
  for p in brightnessctl cbatticon screengrab light-locker; do
    read_packages "$REPO/grupos/visual.txt" | grep -qx "$p" || { echo "falta $p"; return 1; }
  done
}

@test "o ícone do menu existe no repo como PNG" {
  [ "$(head -c 8 "$REPO/dotfiles/icons/so-proprio-menu.png" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
}

# --- terceira rodada: ícones sem moldura ---

@test "os painéis são menores, com ícones menores" {
  run_visual
  c="$(panel_conf)"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'panelSize=36'
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'iconSize=20'
  awk '/^\[panel2\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'panelSize=26'
  awk '/^\[panel2\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'iconSize=16'
  grep -qx 'so_proprio=3' "$c"
}

@test "o tema próprio do LXQt é cópia do base e tira a moldura dos botões do painel" {
  run_visual
  d="$HOME/.local/share/lxqt/themes/so-proprio-claro"
  grep -q '/\* tema light \*/' "$d/lxqt-panel.qss"
  grep -q 'QToolButton' "$d/lxqt-panel.qss"
  grep -q 'border: none' "$d/lxqt-panel.qss"
  [ -f "$d/lxqt-theme.conf" ]
}

@test "sem o tema base do sistema, usa o tema light/dark original" {
  SO_PROPRIO_LXQT_THEMES_DIR="$TMP/nao-existe" run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=light'
}

@test "rodar de novo não duplica o ajuste do tema próprio" {
  run_visual; run_visual
  [ "$(grep -c 'so-proprio: sem moldura' "$HOME/.local/share/lxqt/themes/so-proprio-claro/lxqt-panel.qss")" -eq 1 ]
}
