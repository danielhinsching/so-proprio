#!/usr/bin/env bash
# Firefox ESR enxuto: sem telemetria, com uBlock Origin e preferências para HD mecânico.
# Políticas: /etc/firefox-esr/policies e /etc/firefox/policies (o Debian lê um ou outro,
# conforme a versão). Preferências: defaults/pref do Firefox (dá para mudar em about:config).
# Conferir depois: about:policies no Firefox.
set -euo pipefail

ROOT="${ROOT_PREFIX:-}"
SUDO=()
if [ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ]; then SUDO=(sudo); fi

put() { # <destino>: grava o stdin (cria diretórios, modo 0644)
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  "${SUDO[@]}" install -D -m 0644 "$tmp" "$1"
  rm -f "$tmp"
}

POLICIES='{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DontCheckDefaultBrowser": true,
    "DisableProfileImport": true,
    "DisplayBookmarksToolbar": "never",
    "NoDefaultBookmarks": true,
    "Homepage": { "URL": "about:blank", "StartPage": "none" },
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "FirefoxHome": {
      "Pocket": false,
      "SponsoredPocket": false,
      "SponsoredTopSites": false,
      "Snippets": false
    },
    "UserMessaging": {
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "SkipOnboarding": true,
      "MoreFromMozilla": false
    },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      }
    }
  }
}'
for d in firefox-esr firefox; do
  printf '%s\n' "$POLICIES" | put "$ROOT/etc/$d/policies/policies.json"
done

# Modo limpo: abre em branco, nunca restaura abas, não sonda a rede na partida.
# Fonte única: vira pref() nos padrões e user_pref() em cada perfil (user.js ganha do prefs.js antigo).
LIMPO=(
  'browser.startup.page|0'
  'browser.startup.homepage|"about:blank"'
  'browser.sessionstore.resume_from_crash|false'
  'browser.sessionstore.max_tabs_undo|0'
  'browser.sessionstore.max_windows_undo|0'
  'browser.newtabpage.enabled|false'
  'browser.discovery.enabled|false'
  'network.captive-portal-service.enabled|false'
  'browser.safebrowsing.downloads.remote.enabled|false'
  'datareporting.healthreport.uploadEnabled|false'
  'app.update.auto|false'
)
limpo_como() { # <pref|user_pref>
  local item
  for item in "${LIMPO[@]}"; do printf '%s("%s", %s);\n' "$1" "${item%%|*}" "${item#*|}"; done
}

{
  cat <<'PREFS'
// so-proprio: preferências de baixo consumo para HD mecânico.
// Valem como padrão; mudar em about:config continua funcionando.
// Cache em memória em vez de disco: o HD não segura o navegador.
pref("browser.cache.disk.enable", false);
pref("browser.cache.memory.enable", true);
pref("browser.cache.memory.capacity", 262144);
// Salvar a sessão a cada 60 s em vez de 15 s: menos escrita no HD.
pref("browser.sessionstore.interval", 60000);
// Menos processos de conteúdo (o padrão é 8): economiza RAM.
pref("dom.ipc.processCount", 3);
// Descarregar abas antigas quando a memória apertar.
pref("browser.tabs.unloadOnLowMemory", true);
// Sem pré-carregamento de páginas e DNS.
pref("network.prefetch-next", false);
pref("network.dns.disablePrefetch", true);
pref("network.predictor.enabled", false);
// Decodificação de vídeo pela GPU (Radeon Vega), com mesa-va-drivers.
pref("media.ffmpeg.vaapi.enabled", true);
PREFS
  echo "// Modo limpo (abertura rápida, sem restaurar abas)."
  limpo_como pref
} | put "$ROOT/usr/lib/firefox-esr/defaults/pref/so-proprio.js"

# Perfis que já existem: user.js (sticky) + apaga sessão salva e cache em disco.
# Com o Firefox aberto, só o user.js é gravado (não se mexe em perfil em uso).
ABERTO="${SO_PROPRIO_FIREFOX_ABERTO:-}"
if [ -z "$ABERTO" ]; then
  if pgrep -x firefox-esr >/dev/null 2>&1 || pgrep -x firefox >/dev/null 2>&1; then ABERTO=1; else ABERTO=0; fi
fi
LIMPOS=0
for perfil in "$HOME"/.mozilla/firefox/*.*/; do
  [ -f "${perfil}prefs.js" ] || continue
  { echo "// so-proprio: modo limpo"; limpo_como user_pref; } > "${perfil}user.js"
  if [ "$ABERTO" = 0 ]; then
    rm -f "${perfil}"sessionstore.jsonlz4 "${perfil}"sessionstore-backups/*.jsonlz4* 2>/dev/null || true
    rm -rf "$HOME/.cache/mozilla/firefox/$(basename "$perfil")/cache2" "${perfil}startupCache" 2>/dev/null || true
    LIMPOS=$((LIMPOS + 1))
  fi
done
echo "Firefox: políticas e preferências gravadas ($LIMPOS perfil(is) limpo(s)). Abra about:policies para conferir."
