#!/usr/bin/env bats
# Grupos visual, navegador (Firefox), base (rede) e ajustes novos do tuning.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export ROOT_PREFIX="$TMP/root"
  mkdir -p "$ROOT_PREFIX/etc"
  export SO_PROPRIO_TEMA=claro   # os testes partem do claro; o padrão real é escuro (testado à parte)
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
  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
    <font place="ActiveWindow">
      <name>sans</name>
      <size>8</size>
      <weight>Bold</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>sans</name>
      <size>8</size>
      <weight>Bold</weight>
      <slant>normal</slant>
    </font>
    <font place="MenuItem">
      <name>sans</name>
      <size>8</size>
      <weight>Normal</weight>
      <slant>normal</slant>
    </font>
  </theme>
  <desktops><number>4</number><firstdesk>1</firstdesk></desktops>
  <keyboard>
    <keybind key="A-F4"><action name="Close"/></keybind>
    <keybind key="Print">
      <action name="Execute">
        <command>scrot</command>
      </action>
    </keybind>
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

@test "visual.sh cria um painel só: a barra de status em cima (a dock é o so-proprio-dock)" {
  run_visual
  c="$(panel_conf)"
  grep -qx 'panels=panel1' "$c"
  grep -q '^position=Top' "$c"
  ! grep -q '^position=Bottom' "$c"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'width-percent=true'
}

@test "o painel não tem botão de áreas de trabalho" {
  run_visual
  ! grep -qi 'desktopswitch' "$(panel_conf)"
}

@test "a barra tem bandeja, rede, volume e relógio, sem menu nem atalhos (isso é da dock)" {
  run_visual
  c="$(panel_conf)"
  for t in statusnotifier tray volume worldclock; do
    grep -qx "type=$t" "$c" || { echo "falta $t"; return 1; }
  done
  ! grep -qE '^type=(mainmenu|quicklaunch|taskbar)' "$c"
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

@test "sem nada configurado, o tema padrão é o escuro" {
  unset SO_PROPRIO_TEMA
  run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=so-proprio-escuro'
  grep -q '^window.active.title.bg.color: #1c1c1e' "$HOME/.themes/SoProprio/openbox-3/themerc"
}

@test "o tema escolhido é lembrado: rodar ./add visual de novo não volta ao claro" {
  SO_PROPRIO_TEMA=claro run_visual
  unset SO_PROPRIO_TEMA
  run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=so-proprio-claro'
  SO_PROPRIO_TEMA=escuro run_visual
  unset SO_PROPRIO_TEMA
  run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=so-proprio-escuro'
}

@test "SO_PROPRIO_TEMA=escuro usa a paleta escura em tudo" {
  SO_PROPRIO_TEMA=escuro SO_PROPRIO_FUNDO=tema run_visual
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

@test "o fundo da área de trabalho e do login é preto por padrão" {
  run_visual
  cmp "$HOME/.local/share/so-proprio/wallpaper.png" "$REPO/dotfiles/wallpaper/preto.png"
  cmp "$ROOT_PREFIX/usr/share/backgrounds/so-proprio-fundo.png" "$REPO/dotfiles/wallpaper/preto.png"
}

@test "SO_PROPRIO_FUNDO=tema volta ao degradê do tema" {
  SO_PROPRIO_FUNDO=tema run_visual
  cmp "$HOME/.local/share/so-proprio/wallpaper.png" "$REPO/dotfiles/wallpaper/claro.png"
}

@test "os papéis de parede do repo são PNG" {
  for f in claro escuro preto; do
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
  grep -qx 'theme=light' "$f"; grep -qx 'style=Fusion' "$f"
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

@test "a barra de cima não se esconde e reserva espaço" {
  run_visual
  c="$(panel_conf)"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'hidable=false'
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'reserve-space=true'
}

@test "um painel da versão antiga (so_proprio=1) é regerado com a versão nova" {
  mkdir -p "$HOME/.config/lxqt"
  printf '[General]\nso_proprio=1\n[panel1]\nhidable=true\nposition=Bottom\n' > "$(panel_conf)"
  run_visual
  grep -qx 'so_proprio=7' "$(panel_conf)"
  ! grep -q '^position=Bottom' "$(panel_conf)"
}

@test "o asterisco do menu fica instalado como PNG no tema hicolor e para a dock" {
  run_visual
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
  grep -q 'key="S-Print"' "$rc"
  grep -q '<keybind key="C-A-p"><action name="Execute"><command>screengrab -r</command>' "$rc"
  grep -q 'key="A-Print"' "$rc"
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

@test "tela de login: escura, sem foto de perfil e sem botões Entrar/Cancelar" {
  run_visual
  c="$ROOT_PREFIX/etc/lightdm/lightdm-gtk-greeter.conf"
  grep -qx 'hide-user-image=true' "$c"
  grep -qx 'user-background=false' "$c"
  grep -qx 'background=/usr/share/backgrounds/so-proprio-fundo.png' "$c"
  [ -f "$ROOT_PREFIX/usr/share/backgrounds/so-proprio-fundo.png" ]
  g="$ROOT_PREFIX/var/lib/lightdm/.config/gtk-3.0"
  grep -qx 'gtk-application-prefer-dark-theme=true' "$g/settings.ini"
  grep -q '#login_window button' "$g/gtk.css"
  grep -q '#user_image' "$g/gtk.css"
}

@test "rodar o visual de novo não duplica a configuração da tela de login" {
  run_visual
  run_visual
  [ "$(grep -c '^hide-user-image=' "$ROOT_PREFIX/etc/lightdm/lightdm-gtk-greeter.conf")" -eq 1 ]
}

@test "o Print padrão do Openbox (scrot) é trocado pelo screengrab, sem duplicar" {
  run_visual
  run_visual
  rc="$HOME/.config/openbox/rc.xml"
  ! grep -q 'scrot' "$rc"
  [ "$(grep -c 'key="Print"' "$rc")" -eq 1 ]
  grep -q '<keybind key="Print"><action name="Execute"><command>screengrab -r</command>' "$rc"
}

@test "botões da janela estilo Mac: vermelho, amarelo e verde à esquerda" {
  run_visual
  t="$HOME/.themes/SoProprio/openbox-3/themerc"
  grep -qx 'window.active.button.close.unpressed.image.color: #ff5f57' "$t"
  grep -qx 'window.active.button.iconify.unpressed.image.color: #febc2e' "$t"
  grep -qx 'window.active.button.max.unpressed.image.color: #28c840' "$t"
  grep -qx 'window.active.button.close.hover.bg: flat solid' "$t"
  # janela maximizada usa os estados toggled.*: o verde tem de continuar verde
  grep -qx 'window.active.button.max.toggled.unpressed.image.color: #28c840' "$t"
  grep -qx 'window.active.button.max.toggled.hover.image.color: #28c840' "$t"
  grep -qx 'window.active.button.max.toggled.pressed.image.color: #28c840' "$t"
  grep -qx 'window.inactive.button.max.toggled.unpressed.image.color: #c7c7cc' "$t"
}

@test "dock: o picom dá os cantos transparentes e não sobra regra de dock no QSS do LXQt" {
  run_visual
  q="$HOME/.local/share/lxqt/themes/so-proprio-claro/lxqt-panel.qss"
  ! grep -q 'position="Bottom"' "$q"
  grep -qx 'backend = "xrender";' "$HOME/.config/picom/picom.conf"
  grep -q '^Exec=.*picom' "$HOME/.config/autostart/so-proprio-picom.desktop"
}

@test "o usuário entra no grupo video para as teclas de brilho funcionarem" {
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/usermod.log"\n' "$TMP" > "$TMP/usermod-stub"
  chmod +x "$TMP/usermod-stub"
  SO_PROPRIO_USERMOD="$TMP/usermod-stub" SO_PROPRIO_GRUPOS_USUARIO="daniel sudo" run_visual
  grep -q -- '-aG video' "$TMP/usermod.log"
}

@test "o visual reaplica as regras udev do backlight na hora (sem reiniciar)" {
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/udevadm.log"\n' "$TMP" > "$TMP/udevadm-stub"
  chmod +x "$TMP/udevadm-stub"
  SO_PROPRIO_UDEVADM="$TMP/udevadm-stub" run_visual
  grep -q -- 'trigger --subsystem-match=backlight --action=add' "$TMP/udevadm.log"
}

@test "regra udev própria dá ao grupo video escrita no brilho (sem depender da do pacote)" {
  run_visual
  r="$ROOT_PREFIX/etc/udev/rules.d/90-so-proprio-backlight.rules"
  grep -q 'SUBSYSTEM=="backlight"' "$r"
  grep -q 'chgrp video /sys/class/backlight/%k/brightness' "$r"
  grep -q 'chmod g+w /sys/class/backlight/%k/brightness' "$r"
}

@test "quem já está no grupo video não é alterado" {
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/usermod.log"\n' "$TMP" > "$TMP/usermod-stub"
  chmod +x "$TMP/usermod-stub"
  SO_PROPRIO_USERMOD="$TMP/usermod-stub" SO_PROPRIO_GRUPOS_USUARIO="daniel video" run_visual
  [ ! -e "$TMP/usermod.log" ]
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
  for p in brightnessctl cbatticon screengrab light-locker picom; do
    read_packages "$REPO/grupos/visual.txt" | grep -qx "$p" || { echo "falta $p"; return 1; }
  done
}

@test "o ícone do menu (asterisco nofio) existe no repo como PNG, claro e escuro" {
  for m in claro escuro; do
    [ "$(head -c 8 "$REPO/dotfiles/icons/so-proprio-menu-$m.png" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
  done
}

@test "o tema escuro usa o asterisco branco e o claro, o grafite" {
  SO_PROPRIO_TEMA=escuro run_visual
  i="$HOME/.local/share/icons/hicolor/64x64/apps/so-proprio-menu.png"
  cmp "$i" "$REPO/dotfiles/icons/so-proprio-menu-escuro.png"
  run_visual
  cmp "$i" "$REPO/dotfiles/icons/so-proprio-menu-claro.png"
}

@test "o nome da janela some da barra de título (texto na cor do fundo)" {
  run_visual
  t="$HOME/.themes/SoProprio/openbox-3/themerc"
  grep -qx 'window.active.label.text.color: #f5f5f7' "$t"
  grep -qx 'window.inactive.label.text.color: #ececec' "$t"
}

@test "a barra de cima fica reta e colada na borda" {
  run_visual
  q="$HOME/.local/share/lxqt/themes/so-proprio-claro/lxqt-panel.qss"
  ! grep -q '^LXQtPanel #BackgroundWidget' "$q"
  awk '/^LXQtPanel\[position="Top"\] #BackgroundWidget \{/{p=1;next} /^\}/{p=0} p' "$q" | grep -q 'border-radius: 0px'
}

@test "a barra de título tem altura para a bolinha inteira (fonte 12 no Openbox, sem cortar)" {
  run_visual
  run_visual
  rc="$HOME/.config/openbox/rc.xml"
  for p in ActiveWindow InactiveWindow; do
    b="$(awk -v p="$p" '$0 ~ "<font place=\"" p "\">"{f=1} f{print} f&&/<\/font>/{exit}' "$rc")"
    echo "$b" | grep -q '<name>Inter</name>'
    echo "$b" | grep -q '<size>12</size>'
    echo "$b" | grep -q '<weight>Normal</weight>'
  done
  # outras fontes (menu) não são mexidas
  awk '/<font place="MenuItem">/{f=1} f{print} f&&/<\/font>/{exit}' "$rc" | grep -q '<name>sans</name>'
  grep -qx 'padding.height: 4' "$HOME/.themes/SoProprio/openbox-3/themerc"
}

@test "as bolinhas dos botões são 14x14 e redondas" {
  for b in close iconify max max_toggled; do
    grep -q '#define .*_width 14' "$REPO/dotfiles/openbox/$b.xbm"
  done
}

# --- terceira rodada: ícones sem moldura ---

@test "a barra de cima é pequena, com ícones pequenos" {
  run_visual
  c="$(panel_conf)"
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'panelSize=26'
  awk '/^\[panel1\]/{p=1;next} /^\[/{p=0} p' "$c" | grep -qx 'iconSize=16'
  grep -qx 'so_proprio=7' "$c"
}

@test "o tema próprio do LXQt é cópia do base e tira a moldura dos botões do painel" {
  run_visual
  d="$HOME/.local/share/lxqt/themes/so-proprio-claro"
  grep -q '/\* tema light \*/' "$d/lxqt-panel.qss"
  grep -q 'QToolButton' "$d/lxqt-panel.qss"
  grep -q 'border: none' "$d/lxqt-panel.qss"
  [ -f "$d/lxqt-theme.conf" ]
}

@test "os cards dos apps abertos (LXQtTaskButton) ficam sem padding" {
  run_visual
  d="$HOME/.local/share/lxqt/themes/so-proprio-claro"
  awk '/^LXQtTaskButton \{/{p=1;next} /^\}/{p=0} p' "$d/lxqt-panel.qss" | grep -q 'padding: 0px'
  awk '/^LXQtTaskButton \{/{p=1;next} /^\}/{p=0} p' "$d/lxqt-panel.qss" | grep -q 'margin: 0px'
}

@test "sem o tema base do sistema, usa o tema light/dark original" {
  SO_PROPRIO_LXQT_THEMES_DIR="$TMP/nao-existe" run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=light'
}

@test "rodar de novo não duplica o ajuste do tema próprio" {
  run_visual; run_visual
  [ "$(grep -c 'so-proprio: sem moldura' "$HOME/.local/share/lxqt/themes/so-proprio-claro/lxqt-panel.qss")" -eq 1 ]
}

# --- painel do PC e área de trabalho limpa ---

painel_python() { # um python que tenha tkinter (o do sistema); vazio se nenhum
  for py in python3 python3.13 python3.12 python3.11; do
    "$py" -c 'import tkinter' 2>/dev/null && { echo "$py"; return; }
  done
}

@test "a área de trabalho fica sem ícones: HideItems=true e DesktopShortcuts vazio" {
  run_visual
  s="$HOME/.config/pcmanfm-qt/lxqt/settings.conf"
  awk '/^\[Desktop\]/{p=1;next} /^\[/{p=0} p' "$s" | grep -qx 'HideItems=true'
  awk '/^\[Desktop\]/{p=1;next} /^\[/{p=0} p' "$s" | grep -qx 'DesktopShortcuts='
  ! grep -qi 'trash' "$s"
}

@test "o gerenciador da área de trabalho é encerrado antes de editar o settings.conf e religado depois" {
  printf '#!/usr/bin/env bash\necho "pcmanfm $@" >> "%s/pcmanfm.log"\n' "$TMP" > "$TMP/pcmanfm-stub"
  printf '#!/usr/bin/env bash\necho "pkill $@" >> "%s/pcmanfm.log"\n' "$TMP" > "$TMP/pkill-stub"
  chmod +x "$TMP/pcmanfm-stub" "$TMP/pkill-stub"
  SO_PROPRIO_PCMANFM="$TMP/pcmanfm-stub" SO_PROPRIO_PKILL="$TMP/pkill-stub" SO_PROPRIO_PCMANFM_RODANDO=1 run_visual
  [ "$(sed -n 1p "$TMP/pcmanfm.log")" = "pkill -f pcmanfm-qt --desktop" ]
  [ "$(sed -n 2p "$TMP/pcmanfm.log")" = "pcmanfm --desktop --profile=lxqt" ]
}

@test "sem o gerenciador da área de trabalho rodando, ele não é mexido" {
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/pcmanfm.log"\n' "$TMP" > "$TMP/pcmanfm-stub"
  chmod +x "$TMP/pcmanfm-stub"
  SO_PROPRIO_PCMANFM="$TMP/pcmanfm-stub" SO_PROPRIO_PCMANFM_RODANDO=0 run_visual
  [ ! -e "$TMP/pcmanfm.log" ]
}

@test "painel do PC: --resumo mostra RAM, swap, disco, CPU e o free -h, sem precisar de tela" {
  run python3 "$REPO/bin/so-proprio-painel" --resumo
  [ "$status" -eq 0 ]
  echo "$output" | grep -Eq '^RAM: [0-9.]+ GiB de [0-9.]+ GiB \([0-9]+%\)'
  echo "$output" | grep -Eq '^Swap: '
  echo "$output" | grep -Eq '^Disco /: [0-9.]+ GiB de [0-9.]+ GiB \([0-9]+%\)'
  echo "$output" | grep -Eq '^CPU: [0-9]+%'
  echo "$output" | grep -Eq '^Mem:'
}

@test "painel do PC: abre a janela de verdade (tela virtual) e fecha sem erro" {
  py="$(painel_python)"
  [ -n "$py" ] || skip "sem python com tkinter"
  command -v xvfb-run >/dev/null || skip "sem xvfb-run"
  run xvfb-run -a "$py" "$REPO/bin/so-proprio-painel" --teste-gui
  [ "$status" -eq 0 ]
  [ "$output" = "gui ok" ]
  run xvfb-run -a "$py" "$REPO/bin/so-proprio-painel" --teste-gui --fundo
  [ "$status" -eq 0 ]
  [ "$output" = "gui ok" ]
}

@test "o painel do PC fica fixo no fundo da área de trabalho (autostart em modo --fundo), sem app, atalho nem item na dock" {
  run_visual
  b="$HOME/.local/bin/so-proprio-painel"
  [ -x "$b" ]
  cmp "$b" "$REPO/bin/so-proprio-painel"
  a="$HOME/.config/autostart/so-proprio-fundo.desktop"
  grep -qx "Exec=sh -c \"sleep 6; exec $b --fundo\"" "$a"
  [ ! -e "$HOME/.local/share/applications/so-proprio-painel.desktop" ]
  ! grep -q 'key="C-A-m"' "$HOME/.config/openbox/rc.xml"
  ! grep -q 'so-proprio-painel' "$(panel_conf)"
}

@test "a dock do rodapé é a so-proprio-dock: autostart, e o painel do LXQt fica só com a barra de cima" {
  run_visual
  b="$HOME/.local/bin/so-proprio-dock"
  [ -x "$b" ]
  cmp "$b" "$REPO/bin/so-proprio-dock"
  grep -qx "Exec=sh -c \"sleep 3; exec $b\"" "$HOME/.config/autostart/so-proprio-dock.desktop"
  grep -qx 'panels=panel1' "$(panel_conf)"
  ! grep -qE '^position=Bottom|^plugins=.*(mainmenu|quicklaunch)|^\[(mainmenu|quicklaunch)\]' "$(panel_conf)"
  grep -qx 'plugins=statusnotifier, tray, volume, worldclock' "$(panel_conf)"
}

@test "o menu da dock usa o asterisco do nofio (PNG do tema) e o grupo instala PyQt5, wmctrl e xdotool" {
  run_visual
  [ -f "$HOME/.local/share/so-proprio/icones/menu.png" ]
  for pkg in python3-pyqt5 wmctrl xdotool; do grep -q "^$pkg" "$REPO/grupos/visual.txt"; done
}

@test "o painel de fundo substitui o Conky: autostart removido e lembrado para o ./add desktop" {
  mkdir -p "$HOME/.config/autostart"
  echo "[Desktop Entry]" > "$HOME/.config/autostart/conky-so-proprio.desktop"
  run_visual
  [ ! -e "$HOME/.config/autostart/conky-so-proprio.desktop" ]
  [ -e "$HOME/.config/so-proprio/sem-conky" ]
  grep -q 'sem-conky' "$REPO/grupos/desktop.sh"
}

@test "os ícones dos 4 apps do painel viram PNG (Papirus -> rsvg-convert)" {
  command -v rsvg-convert >/dev/null || skip "sem rsvg-convert"
  src="$TMP/papirus/64x64/apps"
  mkdir -p "$src"
  for n in firefox-esr vscode utilities-terminal system-file-manager; do
    printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="#0a84ff"/></svg>' > "$src/$n.svg"
  done
  SO_PROPRIO_ICONES_SRC="$TMP/papirus/64x64/apps" run_visual
  for i in firefox code terminal arquivos; do
    f="$HOME/.local/share/so-proprio/icones/$i.png"
    [ "$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]
  done
}

@test "python3-tk e librsvg2-bin estão nos pacotes do grupo visual" {
  grep -q '^python3-tk' "$REPO/grupos/visual.txt"
  grep -q '^librsvg2-bin' "$REPO/grupos/visual.txt"
}

@test "painel de fundo de verdade: tipo desktop sem moldura, abaixo dos apps (inclusive o navegador), fora da dock e instância única" {
  command -v xvfb-run >/dev/null && command -v openbox >/dev/null && command -v xdotool >/dev/null && command -v wmctrl >/dev/null && command -v xterm >/dev/null || skip "sem xvfb/openbox/xdotool/wmctrl/xterm"
  py=/usr/bin/python3; for c in /usr/bin/python3.12 /usr/bin/python3 python3; do "$c" -c 'import tkinter' 2>/dev/null && { py="$c"; break; }; done
  export XDG_RUNTIME_DIR="$TMP/xr"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
  cat > "$TMP/cena.sh" <<SH
openbox >/dev/null 2>&1 &
sleep 1
"$py" "$REPO/bin/so-proprio-painel" --fundo >/dev/null 2>&1 &
sleep 1
"$py" "$REPO/bin/so-proprio-painel" --fundo >/dev/null 2>&1 &
sleep 3
xterm -geometry 100x40+300+80 >/dev/null 2>&1 &
sleep 2
echo "janelas=\$(xdotool search --class so-proprio-painel | wc -l)"
id=\$(xdotool search --class so-proprio-painel | head -1)
xprop -id \$id _NET_WM_WINDOW_TYPE | sed 's/^/tipo: /'
xprop -id \$id _NET_FRAME_EXTENTS | sed 's/^/moldura: /'
echo "fixa=\$(wmctrl -lx | grep -c 'so-proprio-painel.* -1\\|^[^ ]* *-1 so-proprio-painel')"
topo=\$(xwininfo -root -tree | grep -nE '"xterm"|"Painel do PC"' | sed 's/.*"\\(xterm\\|Painel do PC\\)".*/\\1/' | head -1)
echo "mais_acima=\$topo"
SH
  run timeout 60 xvfb-run -a bash "$TMP/cena.sh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'janelas=1'
  echo "$output" | grep -q '_NET_WM_WINDOW_TYPE_DESKTOP'
  echo "$output" | grep -qx 'moldura: _NET_FRAME_EXTENTS(CARDINAL) = 0, 0, 0, 0'
  echo "$output" | grep -qx 'mais_acima=xterm'
}
