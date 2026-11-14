#!/usr/bin/env bats
# Testes do grupo navegador (políticas do Firefox), sem tocar no sistema.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export ROOT_PREFIX="$TMP/root"
}

teardown() { rm -rf "$TMP"; }

@test "Firefox sem botão de importar favoritos e sem barra de favoritos vazia" {
  bash "$REPO/grupos/navegador.sh"
  for d in firefox-esr firefox; do
    f="$ROOT_PREFIX/etc/$d/policies/policies.json"
    python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["policies"]; assert p["DisableProfileImport"] is True; assert p["DisplayBookmarksToolbar"]=="never"' "$f"
  done
}
