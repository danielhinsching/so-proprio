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
  <theme><name>Clearlooks</name></theme>
  <desktops><number>4</number><firstdesk>1</firstdesk></desktops>
  <keyboard>
    <keybind key="A-F4"><action name="Close"/></keybind>
  </keyboard>
</openbox_config>
X
  export OPENBOX_DEFAULT_RC="$TMP/xdg/openbox/rc.xml"
  export SO_PROPRIO_THEMES_DIR="$TMP/themes"
  mkdir -p "$SO_PROPRIO_THEMES_DIR/Onyx/openbox-3"
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

@test "visual.sh usa o tema escuro do Openbox quando ele existe" {
  run_visual
  grep -q '<name>Onyx</name>' "$HOME/.config/openbox/rc.xml"
}

@test "visual.sh mantém o rc.xml que o usuário já tinha, só acrescentando o que falta" {
  mkdir -p "$HOME/.config/openbox"
  sed 's/Clearlooks/MeuTema/' "$OPENBOX_DEFAULT_RC" > "$HOME/.config/openbox/rc.xml"
  run_visual
  grep -q '<name>MeuTema</name>' "$HOME/.config/openbox/rc.xml"
  grep -q 'key="C-A-f"' "$HOME/.config/openbox/rc.xml"
}

@test "visual.sh escolhe o tema escuro do LXQt" {
  run_visual
  awk '/^\[General\]/{p=1;next} /^\[/{p=0} p' "$HOME/.config/lxqt/lxqt.conf" | grep -qx 'theme=dark'
}

@test "visual.sh religa o Bluetooth, que o tuning antigo desativava" {
  run_visual
  grep -q 'enable --now bluetooth.service' "$FAKE_SC_LOG"
}

@test "visual.txt traz rede, Bluetooth, volume e o mixer" {
  source "$REPO/lib/add-lib.sh"
  for p in nm-tray blueman bluez pipewire-audio pavucontrol-qt; do
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
