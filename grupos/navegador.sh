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

put "$ROOT/usr/lib/firefox-esr/defaults/pref/so-proprio.js" <<'PREFS'
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
echo "Firefox: políticas e preferências gravadas. Abra about:policies para conferir."
