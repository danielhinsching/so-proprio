#!/usr/bin/env bash
# VS Code (repositório oficial da Microsoft) e fnm (gerenciador de versões do Node.js).
set -euo pipefail

# Mesmo caminho de chave e formato que o próprio pacote 'code' usa,
# para não gerar "Conflicting values set for option Signed-By".
KEYRING=/usr/share/keyrings/microsoft.gpg
SOURCES=/etc/apt/sources.list.d/vscode.sources

if command -v code >/dev/null 2>&1; then
  echo "VS Code: já instalado."
else
  echo "VS Code: adicionando o repositório da Microsoft e instalando o pacote 'code'."
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" https://packages.microsoft.com/keys/microsoft.asc
  gpg --dearmor < "$tmp" | sudo tee "$KEYRING" >/dev/null
  rm -f "$tmp"
  sudo tee "$SOURCES" >/dev/null <<SRC
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: $KEYRING
SRC
  sudo apt-get update
  sudo apt-get install -y code
fi

if command -v fnm >/dev/null 2>&1 || [ -x "$HOME/.local/share/fnm/fnm" ]; then
  echo "fnm: já instalado."
else
  echo "fnm: instalando (https://github.com/Schniz/fnm)."
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" https://fnm.vercel.app/install
  bash "$tmp"
  rm -f "$tmp"
  echo "Abra um novo terminal e rode: fnm install --lts"
fi
