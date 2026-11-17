#!/usr/bin/env bats
# Testes da dock própria (so-proprio-dock): lógica pura + janela de verdade em tela virtual.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DOCK="$REPO/bin/so-proprio-dock"
  PY=""
  for p in /usr/bin/python3.12 /usr/bin/python3 python3; do
    if "$p" -c "import PyQt5.QtWidgets" 2>/dev/null; then PY="$p"; break; fi
  done
}

logica() { # <expressão python>: roda com o módulo carregado como "dock"
  python3 -I - "$DOCK" "$1" <<'PY'
import sys, importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader("dock", sys.argv[1])
s = importlib.util.spec_from_loader("dock", l); m = importlib.util.module_from_spec(s); l.exec_module(m)
print(eval(sys.argv[2], {"dock": m}))
PY
}

@test "sem nenhum app aberto, a dock só tem o botão do menu (largura mínima)" {
  [ "$(logica 'dock.largura(0)')" = "$(logica 'dock.PAD*2 + dock.BOTAO')" ]
}

@test "a largura cresce um botão (mais o espaço) por app aberto" {
  [ "$(logica 'dock.largura(3) - dock.largura(2)')" = "$(logica 'dock.BOTAO + dock.ESPACO')" ]
}

@test "lista de janelas: ignora janelas fixas (-1), o painel de fundo e a própria dock" {
  saida='0x01 0  firefox-esr.firefox-esr  fusca Inicio — Firefox
0x02 -1 lxqt-panel.lxqt-panel  fusca lxqt-panel
0x03 0  so-proprio-painel.So-proprio-painel fusca Painel
0x04 0  so-proprio-dock.so-proprio-dock fusca dock
0x05 1  qterminal.qterminal fusca daniel@fusca: ~
0x06 0  Navigator.firefox-esr fusca Google — Firefox'
  r="$(python3 -I - "$DOCK" "$saida" <<'PY'
import sys, importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader("dock", sys.argv[1])
s = importlib.util.spec_from_loader("dock", l); m = importlib.util.module_from_spec(s); l.exec_module(m)
print([(i, c) for i, c, _t in m.janelas(sys.argv[2])])
PY
)"
  [ "$r" = "[('0x01', 'firefox-esr'), ('0x05', 'qterminal'), ('0x06', 'firefox-esr')]" ]
}

@test "ícone por classe: Firefox, VS Code, terminal e arquivos têm nome de ícone do tema" {
  [ "$(logica 'dock.nome_icone("firefox-esr")')" = "firefox-esr" ]
  [ "$(logica 'dock.nome_icone("Code")')" = "vscode" ]
  [ "$(logica 'dock.nome_icone("qterminal")')" = "utilities-terminal" ]
  [ "$(logica 'dock.nome_icone("pcmanfm-qt")')" = "system-file-manager" ]
  [ "$(logica 'dock.nome_icone("algo-novo")')" = "algo-novo" ]
}

@test "dock: abre a janela de verdade (tela virtual) e fecha sem erro" {
  [ -n "$PY" ] || skip "sem python com PyQt5"
  command -v xvfb-run >/dev/null || skip "sem xvfb-run"
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR"; chmod 700 "$XDG_RUNTIME_DIR"
  run xvfb-run -a "$PY" "$DOCK" --teste-gui
  [ "$status" -eq 0 ]
  [ "$output" = "dock ok" ]
}

@test "ícone vem do .desktop do app (StartupWMClass ou nome do executável), com o tema de ícones do usuário" {
  mkdir -p "$BATS_TEST_TMPDIR/apps"
  printf '[Desktop Entry]\nName=Firefox\nExec=firefox-esr %%u\nIcon=firefox-esr\nStartupWMClass=firefox-esr\n' > "$BATS_TEST_TMPDIR/apps/firefox-esr.desktop"
  printf '[Desktop Entry]\nName=QTerminal\nExec=qterminal\nIcon=qterminal\n' > "$BATS_TEST_TMPDIR/apps/qterminal.desktop"
  [ "$(SO_PROPRIO_APPS_DIR="$BATS_TEST_TMPDIR/apps" logica 'dock.icone_do_desktop("firefox-esr")')" = "firefox-esr" ]
  [ "$(SO_PROPRIO_APPS_DIR="$BATS_TEST_TMPDIR/apps" logica 'dock.icone_do_desktop("QTerminal")')" = "qterminal" ]
  [ "$(SO_PROPRIO_APPS_DIR="$BATS_TEST_TMPDIR/apps" logica 'dock.icone_do_desktop("nada")')" = "None" ]
  mkdir -p "$BATS_TEST_TMPDIR/h/.config/lxqt"; printf '[General]\nicon_theme=Papirus-Dark\n' > "$BATS_TEST_TMPDIR/h/.config/lxqt/lxqt.conf"
  [ "$(HOME="$BATS_TEST_TMPDIR/h" logica 'dock.tema_de_icones()')" = "Papirus-Dark" ]
}

@test "a dock fica escondida por completo (faixa transparente) e aparece por cima ao encostar o mouse, sem reservar espaço" {
  [ "$(logica 'dock.FAIXA')" -le 3 ]
  grep -q '"add,above,sticky"' "$DOCK"
  grep -q '0,0,0,0,0,0,0,0,0,0,0,0' "$DOCK"
  [ -n "$PY" ] || skip "sem python com PyQt5"
  command -v xvfb-run >/dev/null || skip "sem xvfb-run"
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR"; chmod 700 "$XDG_RUNTIME_DIR"
  run xvfb-run -a "$PY" "$DOCK" --teste-esconder
  [ "$status" -eq 0 ]
  [ "$output" = "esconder ok" ]
}
