#!/usr/bin/env bash
# VS Code (repositório oficial da Microsoft) e fnm (gerenciador de versões do Node.js).
set -euo pipefail

KEYRING=/etc/apt/keyrings/packages.microsoft.gpg
LIST=/etc/apt/sources.list.d/vscode.list

if command -v code >/dev/null 2>&1; then
  echo "VS Code: já instalado."
else
  echo "VS Code: adicionando o repositório da Microsoft e instalando o pacote 'code'."
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$KEYRING" >/dev/null
  echo "deb [arch=amd64 signed-by=$KEYRING] https://packages.microsoft.com/repos/code stable main" | sudo tee "$LIST" >/dev/null
  sudo apt-get update
  sudo apt-get install -y code
fi

if command -v fnm >/dev/null 2>&1 || [ -x "$HOME/.local/share/fnm/fnm" ]; then
  echo "fnm: já instalado."
else
  echo "fnm: instalando (https://github.com/Schniz/fnm)."
  curl -fsSL https://fnm.vercel.app/install | bash
  echo "Abra um novo terminal e rode: fnm install --lts"
fi
