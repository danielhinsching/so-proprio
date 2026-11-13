#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export XDG_STATE_HOME="$TMP/state"
  export GRUPOS_DIR="$TMP/grupos"
  mkdir -p "$GRUPOS_DIR"
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
