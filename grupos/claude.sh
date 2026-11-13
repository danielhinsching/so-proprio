#!/usr/bin/env bash
# Claude Code no terminal, pelo instalador nativo oficial da Anthropic.
# Documentação: https://code.claude.com/docs/en/setup
set -euo pipefail

DOC_URL="https://code.claude.com/docs/en/setup"
INSTALL_URL="https://claude.ai/install.sh"

if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code: já instalado."
  exit 0
fi

if [ "${SO_PROPRIO_UID:-$(id -u)}" -eq 0 ]; then
  echo "ERRO: rode como seu usuário, não como root (o Claude Code instala em ~/.local)." >&2
  exit 1
fi

echo "Claude Code: confira o método atual em $DOC_URL"
echo "Comando que será executado: curl -fsSL $INSTALL_URL | bash"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if ! curl -fsSL -o "$tmp" "$INSTALL_URL"; then
  echo "ERRO: não foi possível baixar o instalador ($INSTALL_URL). Confira a rede." >&2
  exit 1
fi
bash "$tmp"
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "ERRO: o instalador terminou, mas o comando 'claude' não foi encontrado." >&2
  exit 1
fi
echo "Abra um novo terminal e rode: claude"
