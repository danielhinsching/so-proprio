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
0x05 1  qterminal.qterminal fusca daniel@fusca: ~'
  r="$(python3 -I - "$DOCK" "$saida" <<'PY'
import sys, importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader("dock", sys.argv[1])
s = importlib.util.spec_from_loader("dock", l); m = importlib.util.module_from_spec(s); l.exec_module(m)
print([(i, c) for i, c, _t in m.janelas(sys.argv[2])])
PY
)"
  [ "$r" = "[('0x01', 'firefox-esr'), ('0x05', 'qterminal')]" ]
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
