#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export XDG_STATE_HOME="$TMP/state"
  export GRUPOS_DIR="$TMP/grupos"
  mkdir -p "$GRUPOS_DIR"
  export SO_PROPRIO_ALLOW_ROOT=1
}

teardown() { rm -rf "$TMP"; }

@test "sem argumentos lista os grupos" {
  touch "$GRUPOS_DIR/a.txt" "$GRUPOS_DIR/b.sh" "$GRUPOS_DIR/a.sh"
  run "$REPO/add"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -cx '  a')" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -cx '  b')" -eq 1 ]
}

@test "grupo desconhecido falha com a lista de válidos" {
  touch "$GRUPOS_DIR/base.txt"
  run "$REPO/add" xyz
  [ "$status" -eq 2 ]
  [[ "$output" == *xyz* ]]
  [[ "$output" == *base* ]]
}

@test "grupo vazio ou só espaços falha" {
  touch "$GRUPOS_DIR/base.txt"
  run "$REPO/add" ""
  [ "$status" -eq 2 ]
  run "$REPO/add" "   "
  [ "$status" -eq 2 ]
}

# --- Task 2: instalação de grupos ---

fake_cmds() {
  # $1 = lista de pacotes "instalados" (separados por espaço)
  BIN="$TMP/bin"; mkdir -p "$BIN"
  printf '%s\n' $1 > "$TMP/instalados"
  cat > "$BIN/dpkg-query" <<'Q'
#!/usr/bin/env bash
pkg="${@: -1}"
if grep -qx "$pkg" "$FAKE_INSTALADOS"; then echo "install ok installed"; else exit 1; fi
Q
  cat > "$BIN/apt" <<'A'
#!/usr/bin/env bash
echo "apt $*" >> "$FAKE_APT_LOG"
exit "${FAKE_APT_EXIT:-0}"
A
  chmod +x "$BIN"/*
  export FAKE_INSTALADOS="$TMP/instalados" FAKE_APT_LOG="$TMP/apt.log"
  export DPKG_QUERY_CMD="$BIN/dpkg-query" APT_CMD="$BIN/apt"
}

@test "read_packages ignora comentários, linhas em branco e espaços" {
  source "$REPO/lib/add-lib.sh"
  printf '  git  \n# comentário\n\ncurl # fim\n' > "$TMP/x.txt"
  run read_packages "$TMP/x.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'git\ncurl')" ]
}

@test "segunda execução não instala nada" {
  printf 'git\ncurl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds "git curl"
  run "$REPO/add" --yes base
  [ "$status" -eq 0 ]
  [[ "$output" == *"nada a instalar"* ]]
  [ ! -e "$FAKE_APT_LOG" ]
}

@test "--dry-run não chama o apt e lista os faltantes" {
  printf 'git\ncurl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds "git"
  run "$REPO/add" --dry-run base
  [ "$status" -eq 0 ]
  [[ "$output" == *curl* ]]
  [ ! -e "$FAKE_APT_LOG" ]
}

@test "instala só os faltantes" {
  printf 'git\ncurl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds "git"
  run "$REPO/add" --yes base
  [ "$status" -eq 0 ]
  grep -q 'install -y curl' "$FAKE_APT_LOG"
  ! grep -q ' git' "$FAKE_APT_LOG"
}

@test "pacote inexistente falha nomeando o pacote" {
  printf 'pacote-que-nao-existe\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds ""
  export FAKE_APT_EXIT=100
  run "$REPO/add" --yes base
  [ "$status" -ne 0 ]
  [[ "$output" == *pacote-que-nao-existe* ]]
  [[ "$output" != *"concluído"* ]]
}

@test "grupo com .sh executa o script depois dos pacotes" {
  printf 'git\n' > "$GRUPOS_DIR/dev.txt"
  printf '#!/usr/bin/env bash\necho script >> "$FAKE_APT_LOG"\n' > "$GRUPOS_DIR/dev.sh"
  fake_cmds ""
  run "$REPO/add" --yes dev
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$FAKE_APT_LOG")" = "apt install -y git" ]
  [ "$(tail -1 "$FAKE_APT_LOG")" = "script" ]
  grep -q 'dev' "$XDG_STATE_HOME/so-proprio/add.log"
}

@test "sem --yes e sem confirmação não instala" {
  printf 'curl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds ""
  run bash -c "echo n | '$REPO/add' base"
  [ "$status" -ne 0 ]
  [ ! -e "$FAKE_APT_LOG" ]
}

# --- Task 3: grupos reais ---

@test "todo nome em grupos/*.txt é um nome de pacote válido" {
  source "$REPO/lib/add-lib.sh"
  local f n count=0
  for f in "$REPO"/grupos/*.txt; do
    while IFS= read -r n; do
      [[ "$n" =~ ^[a-z0-9][a-z0-9+.-]+$ ]] || { echo "inválido em $f: '$n'"; return 1; }
      count=$((count + 1))
    done < <(read_packages "$f")
  done
  [ "$count" -gt 0 ]
}

@test "existem os grupos base, desktop, dev, navegador, vm e claude" {
  run env -u GRUPOS_DIR "$REPO/add"
  for g in base desktop dev navegador vm claude; do
    printf '%s\n' "$output" | grep -qx "  $g"
  done
}

@test "todos os .sh de grupos passam no shellcheck" {
  shellcheck "$REPO"/grupos/*.sh
}

# --- Task 5: atalho tuning ---

@test "add sem argumentos lista tuning" {
  run env -u GRUPOS_DIR "$REPO/add"
  printf '%s\n' "$output" | grep -qx '  tuning'
}

@test "add tuning chama tuning/apply.sh e respeita --dry-run" {
  mkdir -p "$TMP/root/etc"
  printf 'UUID=a / ext4 defaults 0 1\n' > "$TMP/root/etc/fstab"
  run env ROOT_PREFIX="$TMP/root" "$REPO/add" --dry-run tuning
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ajustes de HD"* ]]
  [[ "$output" == *"dry-run"* ]]
  [ ! -e "$TMP/root/etc/fstab.so-proprio.bak" ]
}

# --- Correções da revisão final ---

@test "atualiza a lista de pacotes antes de instalar" {
  printf 'curl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds ""
  run "$REPO/add" --yes base
  [ "$status" -eq 0 ]
  [ "$(head -1 "$FAKE_APT_LOG")" = "apt update" ]
  [ "$(sed -n 2p "$FAKE_APT_LOG")" = "apt install -y curl" ]
}

@test "recusa rodar como root, exceto tuning" {
  printf 'curl\n' > "$GRUPOS_DIR/base.txt"
  fake_cmds ""
  unset SO_PROPRIO_ALLOW_ROOT
  run env SO_PROPRIO_UID=0 "$REPO/add" --yes base
  [ "$status" -eq 1 ]
  [[ "$output" == *root* ]]
  [ ! -e "$FAKE_APT_LOG" ]
  mkdir -p "$TMP/root/etc"; printf 'UUID=a / ext4 defaults 0 1\n' > "$TMP/root/etc/fstab"
  run env SO_PROPRIO_UID=0 ROOT_PREFIX="$TMP/root" "$REPO/add" --dry-run tuning
  [ "$status" -eq 0 ]
}

@test "claude.sh falha se o download falhar" {
  mkdir -p "$TMP/bin" "$TMP/home"
  printf '#!/bin/sh\necho "curl: (22) 403" >&2\nexit 22\n' > "$TMP/bin/curl"
  chmod +x "$TMP/bin/curl"
  run env -i HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" SO_PROPRIO_UID=1000 bash "$REPO/grupos/claude.sh"
  [ "$status" -ne 0 ]
  [[ "$output" != *"Abra um novo terminal"* ]]
}

@test "dev.sh usa o keyring e o formato que o pacote code espera" {
  grep -q '/usr/share/keyrings/microsoft.gpg' "$REPO/grupos/dev.sh"
  grep -q 'vscode.sources' "$REPO/grupos/dev.sh"
  ! grep -q '/etc/apt/keyrings/packages.microsoft.gpg' "$REPO/grupos/dev.sh"
}

# --- desktop.sh: Openbox já escolhido ---

@test "desktop.sh configura o Openbox sem sobrescrever escolha existente" {
  mkdir -p "$TMP/home"
  HOME="$TMP/home" bash "$REPO/grupos/desktop.sh"
  grep -qx 'window_manager=openbox' "$TMP/home/.config/lxqt/session.conf"
  grep -qx '\[General\]' "$TMP/home/.config/lxqt/session.conf"
  printf '[General]\nwindow_manager=xfwm4\n' > "$TMP/home/.config/lxqt/session.conf"
  HOME="$TMP/home" bash "$REPO/grupos/desktop.sh"
  grep -qx 'window_manager=xfwm4' "$TMP/home/.config/lxqt/session.conf"
}

@test "dev.sh já instala o Node LTS pelo fnm" {
  mkdir -p "$TMP/home" "$TMP/bin"
  printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/code"
  printf '#!/bin/sh\necho "fnm $*" >> "%s"\n' "$TMP/fnm.log" > "$TMP/bin/fnm"
  chmod +x "$TMP/bin/code" "$TMP/bin/fnm"
  run env HOME="$TMP/home" PATH="$TMP/bin:$PATH" bash "$REPO/grupos/dev.sh"
  [ "$status" -eq 0 ]
  grep -q '^fnm install --lts' "$TMP/fnm.log"
  grep -q '^fnm default lts-latest' "$TMP/fnm.log"
}
