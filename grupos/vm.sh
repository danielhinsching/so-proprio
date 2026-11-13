#!/usr/bin/env bash
# VirtualBox pelo repositório oficial da Oracle (não está no Debian estável).
set -euo pipefail

KEYRING=/etc/apt/keyrings/oracle-virtualbox.gpg
LIST=/etc/apt/sources.list.d/virtualbox.list

if command -v VBoxManage >/dev/null 2>&1; then
  echo "VirtualBox: já instalado."
  exit 0
fi

# shellcheck source=/dev/null
. /etc/os-release
echo "VirtualBox: adicionando o repositório da Oracle para '${VERSION_CODENAME}'."
sudo install -d -m 0755 /etc/apt/keyrings
tmp="$(mktemp)"
curl -fsSL -o "$tmp" https://www.virtualbox.org/download/oracle_vbox_2016.asc
gpg --dearmor < "$tmp" | sudo tee "$KEYRING" >/dev/null
rm -f "$tmp"
echo "deb [arch=amd64 signed-by=$KEYRING] https://download.virtualbox.org/virtualbox/debian ${VERSION_CODENAME} contrib" | sudo tee "$LIST" >/dev/null
sudo apt-get update

PKG="$(apt-cache search --names-only '^virtualbox-[0-9]+\.[0-9]+$' | cut -d' ' -f1 | sort -V | tail -1)"
if [ -z "$PKG" ]; then
  echo "ERRO: nenhum pacote virtualbox-X.Y encontrado no repositório da Oracle." >&2
  exit 1
fi
echo "VirtualBox: instalando $PKG."
sudo apt-get install -y "$PKG"
sudo usermod -aG vboxusers "$USER"
echo "Faça logout e login para usar o VirtualBox (grupo vboxusers)."
echo "Se o Secure Boot estiver ativo, os módulos precisam ser assinados ou o Secure Boot desativado."
