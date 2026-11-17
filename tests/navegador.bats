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

mkperfil() { # cria um perfil antigo, "sujo", com sessão salva e cache
  export HOME="$TMP/home"
  P="$HOME/.mozilla/firefox/abc123.default-esr"
  mkdir -p "$P/sessionstore-backups" "$HOME/.cache/mozilla/firefox/abc123.default-esr/cache2/entries"
  echo 'user_pref("browser.startup.page", 3);' > "$P/prefs.js"
  echo x > "$P/sessionstore.jsonlz4"
  echo x > "$P/sessionstore-backups/recovery.jsonlz4"
  echo x > "$P/sessionstore-backups/previous.jsonlz4"
  echo x > "$HOME/.cache/mozilla/firefox/abc123.default-esr/cache2/entries/AAAA"
}

@test "Firefox abre limpo: página em branco e sem restaurar abas da última vez (política)" {
  bash "$REPO/grupos/navegador.sh"
  for d in firefox-esr firefox; do
    f="$ROOT_PREFIX/etc/$d/policies/policies.json"
    python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["policies"]; h=p["Homepage"]; assert h["URL"]=="about:blank" and h["StartPage"]=="none"; assert p["NoDefaultBookmarks"] is True' "$f"
  done
}

@test "preferências de inicialização enxuta: sem restaurar sessão, sem tela inicial pesada, sem sondas de rede" {
  bash "$REPO/grupos/navegador.sh"
  f="$ROOT_PREFIX/usr/lib/firefox-esr/defaults/pref/so-proprio.js"
  for linha in \
    'pref("browser.startup.page", 0);' \
    'pref("browser.startup.homepage", "about:blank");' \
    'pref("browser.sessionstore.resume_from_crash", false);' \
    'pref("browser.sessionstore.max_tabs_undo", 0);' \
    'pref("browser.sessionstore.max_windows_undo", 0);' \
    'pref("browser.newtabpage.enabled", false);' \
    'pref("network.captive-portal-service.enabled", false);' \
    'pref("browser.safebrowsing.downloads.remote.enabled", false);'; do
    grep -qxF "$linha" "$f"
  done
}

@test "perfil existente: user.js força o modo limpo (prefs.js antigo não ganha mais)" {
  mkperfil
  bash "$REPO/grupos/navegador.sh"
  u="$HOME/.mozilla/firefox/abc123.default-esr/user.js"
  grep -qxF 'user_pref("browser.startup.page", 0);' "$u"
  grep -qxF 'user_pref("browser.sessionstore.resume_from_crash", false);' "$u"
}

@test "perfil existente: sessão salva e cache em disco são apagados" {
  mkperfil
  bash "$REPO/grupos/navegador.sh"
  P="$HOME/.mozilla/firefox/abc123.default-esr"
  [ ! -e "$P/sessionstore.jsonlz4" ]
  [ ! -e "$P/sessionstore-backups/recovery.jsonlz4" ]
  [ ! -e "$P/sessionstore-backups/previous.jsonlz4" ]
  [ ! -e "$HOME/.cache/mozilla/firefox/abc123.default-esr/cache2" ]
  [ -f "$P/prefs.js" ]   # favoritos, senhas e extensões ficam intactos
}

@test "com o Firefox aberto, a limpeza do perfil é pulada (não mexe em perfil em uso)" {
  mkperfil
  touch "$HOME/.mozilla/firefox/abc123.default-esr/lock"
  SO_PROPRIO_FIREFOX_ABERTO=1 bash "$REPO/grupos/navegador.sh"
  [ -e "$HOME/.mozilla/firefox/abc123.default-esr/sessionstore.jsonlz4" ]
  [ -f "$HOME/.mozilla/firefox/abc123.default-esr/user.js" ]
}

@test "sem perfil nenhum, o grupo roda normalmente" {
  export HOME="$TMP/vazio"; mkdir -p "$HOME"
  run bash "$REPO/grupos/navegador.sh"
  [ "$status" -eq 0 ]
}
