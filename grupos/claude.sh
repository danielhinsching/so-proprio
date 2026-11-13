#!/usr/bin/env bash
# Claude Code no terminal, pelo instalador nativo oficial da Anthropic.
# Documentação: https://code.claude.com/docs/en/setup
set -euo pipefail

DOC_URL="https://code.claude.com/docs/en/setup"
INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"

if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code: já instalado."
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "ERRO: rode como seu usuário, não como root (o Claude Code instala em ~/.local)." >&2
  exit 1
fi

echo "Claude Code: confira o método atual em $DOC_URL"
echo "Comando que será executado: $INSTALL_CMD"
bash -c "$INSTALL_CMD"
echo "Abra um novo terminal e rode: claude"
